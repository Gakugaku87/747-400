-- 747-400 fire protection without X-Plane (3-4, step 1): the engine fire
-- and overheat detectors and the APU fire detector (dual loops: AFOLTS),
-- the engine and APU fire switches, the engine and APU extinguisher
-- bottles, the FIRE/OVHT TEST, and the EICAS messages and lights of these.
-- Logic and sources: docs/overhaul/notes/ATA-26.md §2-§4 (FCOM 8.10-8.30
-- p.905-923; ATA26_28 26-11, 26-15, 26-21, 26-22).
--
--   local F = B747_fire_model            -- in XTLua, after dofile
--   local F = dofile(".../B747.35.fire_model.lua")   -- in the tests
--   local s = F.new()
--   local inp = F.inputs()               -- fill it every frame
--   local out = F.update(s, inp, dt)     -- the same table every frame

local M = setmetatable({}, {})
B747_fire_model = M

-- the detection zones: ENG 1-4 FIRE, ENG 1-4 OVHT, APU
M.ZONES = 9
M.ENG_FIRE, M.ENG_OVHT, M.APU = 0, 4, 9     -- zone = M.ENG_FIRE + n, M.ENG_OVHT + n, M.APU
-- the bottles: L ENG A, L ENG B, R ENG A, R ENG B (left wing: engines 1, 2), APU
M.BOTTLES = 5
M.APU_BTL = 5
-- the rotation of each engine fire switch towards its bottle A: engines 1
-- and 3 counterclockwise (-1), 2 and 4 clockwise (ATA26_28 p.70, p.72)
M.A_DIR = {-1, 1, -1, 1}

M.TEST_S = 5                -- >TEST IN PROG, then >FIRE TEST PASS/FAIL (FCOM p.919; ATA26_28 p.30)
M.STATUS_S = 20             -- the loop and FIRE/OVHT SYS status messages (ATA26_28 p.34, p.46, p.102)
M.APU_DISCH_S = 10          -- the APU bottle discharges by itself on the ground (ATA26_28 p.124)
M.APU_DISCH_N1 = 95         -- once the APU is below 95 %
M.BTL_PSI = 600             -- engine and APU bottles: 600 psig at 21°C (ATA26_28 p.60-76, p.116)
M.BTL_LOW_PSI = 225         -- their pressure switches: BTL DISCH, >BTL LO (ATA26_28 p.62-78, p.130)
-- estimates (no value in the sources)
M.DISCH_S = 1.5             -- a squib empties its bottle in 1.5 s (the cargo bottles A and B
                            -- "instantly": ATA26_28 p.170)

local function four(v) return {v, v, v, v} end
local function zones(v)
    local t = {}
    for z = 1, M.ZONES do t[z] = v end
    return t
end
local function bottles(v)
    local t = {}
    for b = 1, M.BOTTLES do t[b] = v end
    return t
end

function M.inputs()
    return {
        eng_fire_heat = four(false),    -- fire in an engine nacelle (X-Plane's engine fire)
        eng_ovht_heat = four(false),    -- overheat in an engine nacelle (failure input)
        apu_fire_heat = false,          -- fire in the APU compartment (X-Plane's APU fire)
        loop_failed_a = zones(false),   -- failure: a zone's loop A (M.ZONES order)
        loop_failed_b = zones(false),
        det_power = true,               -- the detection cards: APU battery bus (FCOM p.820)
        hot_bat = true,                 -- the switches' unlock solenoids and the squibs: main hot
                                        -- battery bus (FCOM p.820)
        fuel_cutoff = four(false),      -- FUEL CONTROL n in CUTOFF (unlocks fire switch n)
        test = false,                   -- FIRE/OVHT TEST held
        on_ground = true,
        apu_n1 = 0,
        -- the switches' commands, one frame each
        eng_toggle = four(false),       -- the fire switch pulled out, or pushed back in
        eng_override = four(false),     -- Fire Override pushed and the switch pulled
        eng_rotate = four(0),           -- rotated one step: -1 counterclockwise, 1 clockwise
        apu_toggle = false,
        apu_override = false,
        apu_rotate = 0,
    }
end

function M.new()
    local s = {pulled = four(false), rot = four(0), apu_pulled = false, apu_rot = 0,
        btl = bottles(M.BTL_PSI), squib = {}, disch_t = bottles(0), disch_into = bottles(0),
        test_t = 0, lp_t = {a = zones(0), b = zones(0)}, power_off_t = 0, apu_disch_t = 0}
    for b = 1, M.BOTTLES do s.squib[b] = {} end
    s.out = {alarm = zones(false), fire = zones(false), det_failed = zones(false),
        lp_a = zones(false), lp_b = zones(false), eng_light = four(false), apu_light = false,
        unlocked = four(false), pulled = four(false), rot = four(0),
        apu_unlocked = false, apu_pulled = false, apu_rot = 0,
        btl_psi = bottles(M.BTL_PSI), btl_low = bottles(false), extinguish = four(false),
        apu_extinguish = false, apu_shutdown = false, apu_horn = false,
        test_in_prog = false, test_pass = false, test_fail = false, sys_power = false}
    return s
end

-- a bottle's squib for one outlet (an engine, or the APU): fires once, and
-- empties the bottle if it still holds agent
local function fire_squib(s, b, outlet)
    if s.squib[b][outlet] then return end
    s.squib[b][outlet] = true
    if s.btl[b] > M.BTL_LOW_PSI and s.disch_t[b] == 0 then
        s.disch_t[b] = M.DISCH_S
        s.disch_into[b] = outlet
    end
end

local function heat_of(inp, z)
    if z <= M.ENG_OVHT then return inp.eng_fire_heat[z - M.ENG_FIRE] end
    if z <= M.APU - 1 then return inp.eng_ovht_heat[z - M.ENG_OVHT] end
    return inp.apu_fire_heat
end

-- a detector's output from its loops' alarms a, b: the APU detector with
-- either loop; the others with both, or with the one loop left working
local function decide(z, ok_a, ok_b, a, b)
    if z == M.APU then return a or b end
    if ok_a and ok_b then return a and b end
    if ok_a then return a end
    if ok_b then return b end
    return false
end

-- a loop's STATUS timer: the loop in alarm or failed (not the test)
local function lp_time(t, bad, dt)
    if bad then return t + dt end
    return 0
end

function M.update(s, inp, dt)
    local out = s.out

    -- the detectors (FCOM p.914, p.919; ATA26_28 p.20, p.25-46, p.88-102):
    -- both loops of an engine detector must alarm; with one loop failed the
    -- other alone (the engine loops are monitored all the time); the APU
    -- detector alarms with either loop. "alarm" counts the test, "fire" not
    local all_ok = inp.det_power
    local test = inp.test
    for z = 1, M.ZONES do
        local ok_a = inp.det_power and not inp.loop_failed_a[z]
        local ok_b = inp.det_power and not inp.loop_failed_b[z]
        local heat = heat_of(inp, z)
        out.alarm[z] = decide(z, ok_a, ok_b, ok_a and (heat or test), ok_b and (heat or test))
        out.fire[z] = decide(z, ok_a, ok_b, ok_a and heat, ok_b and heat)
        out.det_failed[z] = inp.det_power and inp.loop_failed_a[z] and inp.loop_failed_b[z]
        if not (ok_a and ok_b) then all_ok = false end
        -- STATUS ... LP A, B: that loop in alarm or failed, 20 s
        s.lp_t.a[z] = lp_time(s.lp_t.a[z], inp.det_power and (not ok_a or heat), dt)
        s.lp_t.b[z] = lp_time(s.lp_t.b[z], inp.det_power and (not ok_b or heat), dt)
        out.lp_a[z] = s.lp_t.a[z] >= M.STATUS_S
        out.lp_b[z] = s.lp_t.b[z] >= M.STATUS_S
    end
    -- STATUS FIRE/OVHT SYS: no power for the detection, 20 s
    if inp.det_power then s.power_off_t = 0 else s.power_off_t = s.power_off_t + dt end
    out.sys_power = s.power_off_t >= M.STATUS_S

    -- FIRE/OVHT TEST (FCOM p.910, p.919; ATA26_28 p.30, p.42): TEST IN PROG,
    -- after 5 s FIRE TEST PASS when every loop answered, else FAIL; all
    -- clear when released
    if inp.test then s.test_t = s.test_t + dt else s.test_t = 0 end
    local done = s.test_t >= M.TEST_S
    out.test_in_prog = inp.test and not done
    out.test_pass = inp.test and done and all_ok
    out.test_fail = inp.test and done and not all_ok

    -- the fire warning lights: the fire switches (and the FUEL CONTROL
    -- lights, which the 3D wires to X-Plane) while the fire signal lasts
    for n = 1, 4 do out.eng_light[n] = out.alarm[M.ENG_FIRE + n] end
    out.apu_light = out.alarm[M.APU]

    -- the engine fire switches (FCOM p.905-906, p.916; ATA26_28 p.48-51):
    -- locked in until a fire warning (or the test), CUTOFF, with the main
    -- hot battery bus for the solenoid, or the Fire Override; out arms the
    -- wing's bottles; rotated to A or B fires that bottle's squib
    for n = 1, 4 do
        out.unlocked[n] = inp.hot_bat and (out.alarm[M.ENG_FIRE + n] or inp.fuel_cutoff[n])
        if inp.eng_override[n] and not s.pulled[n] then
            s.pulled[n] = true
        elseif inp.eng_toggle[n] then
            if not s.pulled[n] then
                if out.unlocked[n] then s.pulled[n] = true end
            elseif s.rot[n] == 0 then
                s.pulled[n] = false
            end
        end
        if s.pulled[n] and inp.eng_rotate[n] ~= 0 then
            local before = s.rot[n]
            s.rot[n] = math.max(-1, math.min(1, s.rot[n] + inp.eng_rotate[n]))
            if s.rot[n] ~= 0 and s.rot[n] ~= before and inp.hot_bat then
                local a = n <= 2 and 1 or 3
                local b = (s.rot[n] == M.A_DIR[n]) and a or a + 1
                fire_squib(s, b, n)
            end
        end
        out.pulled[n] = s.pulled[n]
        out.rot[n] = s.rot[n]
    end

    -- the APU fire switch (FCOM p.906-907, p.916; ATA26_28 p.104-110,
    -- p.124): unlocked by an APU fire warning (or the test) or the
    -- override; rotated either way, it discharges the APU bottle
    out.apu_unlocked = inp.hot_bat and out.alarm[M.APU]
    if inp.apu_override and not s.apu_pulled then
        s.apu_pulled = true
    elseif inp.apu_toggle then
        if not s.apu_pulled then
            if out.apu_unlocked then s.apu_pulled = true end
        elseif s.apu_rot == 0 then
            s.apu_pulled = false
        end
    end
    if s.apu_pulled and inp.apu_rotate ~= 0 then
        local before = s.apu_rot
        s.apu_rot = math.max(-1, math.min(1, s.apu_rot + inp.apu_rotate))
        if s.apu_rot ~= 0 and s.apu_rot ~= before and inp.hot_bat then fire_squib(s, M.APU_BTL, 5) end
    end
    out.apu_pulled = s.apu_pulled
    out.apu_rot = s.apu_rot

    -- the APU: an APU fire shuts it down (not the test); out of the switch
    -- too. On the ground the bottle discharges by itself after 10 s of fire
    -- with the APU below 95 % (FCOM p.897, p.907, p.914; ATA26_28 p.93-94,
    -- p.124). The horn: an APU fire (or the test) on the ground until the
    -- switch is pulled (FCOM p.913; ATA26_28 p.108-111)
    local apu_fire = out.fire[M.APU]
    out.apu_shutdown = apu_fire or s.apu_pulled
    if apu_fire and inp.on_ground and inp.apu_n1 < M.APU_DISCH_N1 then
        s.apu_disch_t = s.apu_disch_t + dt
        if s.apu_disch_t >= M.APU_DISCH_S and inp.hot_bat then fire_squib(s, M.APU_BTL, 5) end
    else
        s.apu_disch_t = 0
    end
    out.apu_horn = inp.on_ground and out.alarm[M.APU] and not s.apu_pulled

    -- the bottles: a squib empties its bottle into its outlet (X-Plane's
    -- extinguisher while the agent flows); BTL DISCH and >BTL LO at 225 psi
    for n = 1, 4 do out.extinguish[n] = false end
    out.apu_extinguish = false
    for b = 1, M.BOTTLES do
        if s.disch_t[b] > 0 then
            local step = math.min(s.disch_t[b], dt)
            s.btl[b] = math.max(0, s.btl[b] - M.BTL_PSI * step / M.DISCH_S)
            s.disch_t[b] = s.disch_t[b] - step
            if s.disch_t[b] <= 0 then
                s.disch_t[b] = 0
                s.btl[b] = 0
            end
            local into = s.disch_into[b]
            if into >= 1 and into <= 4 then out.extinguish[into] = true else out.apu_extinguish = true end
        end
        out.btl_psi[b] = s.btl[b]
        out.btl_low[b] = s.btl[b] <= M.BTL_LOW_PSI
    end
    return out
end

-- a new flight (and the AI's cold & dark): full bottles, the switches in
function M.reset_switches(s)
    for n = 1, 4 do s.pulled[n], s.rot[n] = false, 0 end
    s.apu_pulled, s.apu_rot = false, 0
end

return M
