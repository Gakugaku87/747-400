-- 747-400 fire protection without X-Plane (3-4): the engine fire and
-- overheat, APU fire and lower cargo smoke detectors (dual loops: AFOLTS),
-- the wheel well fire and wing leading edge overheat (BLD DUCT LEAK) loops,
-- the lavatory and crew rest smoke, the engine and APU fire switches, the
-- engine, APU and cargo extinguisher bottles and their discharge, the
-- FIRE/OVHT TEST, the squib test, and the EICAS messages and lights of
-- these. Logic and sources: docs/overhaul/notes/ATA-26.md §2-§4 (FCOM
-- 8.10-8.30 p.905-923; ATA26_28 26-11 to 26-27).
--
--   local F = B747_fire_model            -- in XTLua, after dofile
--   local F = dofile(".../B747.35.fire_model.lua")   -- in the tests
--   local s = F.new()
--   local inp = F.inputs()               -- fill it every frame
--   local out = F.update(s, inp, dt)     -- the same table every frame

local M = setmetatable({}, {})
B747_fire_model = M

-- the dual loop detection zones: ENG 1-4 FIRE, ENG 1-4 OVHT, APU, CARGO 1-4
-- (forward 1, 2; aft 3, bulk 4)
M.ZONES = 13
M.ENG_FIRE, M.ENG_OVHT, M.APU, M.CARGO = 0, 4, 9, 9   -- zone = M.ENG_FIRE + n, ..., M.CARGO + k
-- the bottles: L ENG A, L ENG B, R ENG A, R ENG B (left wing: engines 1, 2),
-- APU, CARGO A, B, C, D
M.BOTTLES = 9
M.APU_BTL, M.CGO_A = 5, 6           -- cargo bottle A, B, C, D = M.CGO_A + 0..3
-- the outlets of the squibs: engines 1-4, the APU, the forward and aft cargo compartments
M.OUT_APU, M.OUT_FWD, M.OUT_AFT = 5, 6, 7
-- the rotation of each engine fire switch towards its bottle A: engines 1
-- and 3 counterclockwise (-1), 2 and 4 clockwise (ATA26_28 p.70, p.72)
M.A_DIR = {-1, 1, -1, 1}

M.TEST_S = 5                -- >TEST IN PROG, then >FIRE TEST PASS/FAIL (FCOM p.919; ATA26_28 p.30)
M.STATUS_S = 20             -- the loop, CARGO DET and FIRE/OVHT SYS status (ATA26_28 p.34, p.46, p.164)
M.STATUS_LONG_S = 60        -- CARGO DET AIR, BLD DUCT LEAK status (ATA26_28 p.164, p.286)
M.APU_DISCH_S = 10          -- the APU bottle discharges by itself on the ground (ATA26_28 p.124)
M.APU_DISCH_N1 = 95         -- once the APU is below 95 %
M.BTL_PSI = 600             -- engine and APU bottles: 600 psig at 21°C (ATA26_28 p.60-76, p.116)
M.BTL_LOW_PSI = 225         -- their pressure switches: BTL DISCH, >BTL LO (ATA26_28 p.62-78, p.130)
M.CGO_PSI = 360             -- cargo bottles: 360 psig at 21°C (ATA26_28 p.170-180)
M.CGO_LOW_PSI = 300         -- their pressure switches (ATA26_28 p.178)
M.CGO_DELAY_S = 1800        -- bottles C, D 30 min after A, B in flight, or at touchdown (ATA26_28 p.184-187)
M.CGO_METER_S = 7200        -- C, D flow through their regulator for about 2 hours (ATA26_28 p.170, p.180)
M.CGO_DET_ENGINES = 2       -- >CARGO DET AIR needs two engines running (ATA26_28 p.142-145)
-- estimates (no value in the sources)
M.DISCH_S = 1.5             -- a squib empties its bottle in 1.5 s (the cargo bottles A and B
                            -- "instantly": ATA26_28 p.170)

local function four(v) return {v, v, v, v} end
local function list(n, v)
    local t = {}
    for i = 1, n do t[i] = v end
    return t
end

function M.inputs()
    return {
        eng_fire_heat = four(false),    -- fire in an engine nacelle (X-Plane's engine fire)
        eng_ovht_heat = four(false),    -- overheat in an engine nacelle (failure input)
        apu_fire_heat = false,          -- fire in the APU compartment (X-Plane's APU fire)
        cargo_smoke = four(false),      -- smoke in cargo zone 1-4 (failure input)
        cargo_airflow = true,           -- the venturi draws air through the cargo detectors
        engines_running = 4,
        wheel_well_heat = false,        -- fire in a main wheel well (failure input)
        duct_leak = {false, false, false},  -- a bleed duct leak L, C, R (failure input)
        lav_smoke = false,              -- smoke in a lavatory (failure input)
        rest_smoke = false,             -- smoke in the door 5 crew rest (failure input)
        loop_failed_a = list(M.ZONES, false),   -- failure: a zone's loop A (M.ZONES order)
        loop_failed_b = list(M.ZONES, false),
        det_power = true,               -- the detection cards: APU battery bus (FCOM p.820)
        wheel_well_power = true,        -- its card: AC bus 2 (ATA26_28 p.273)
        duct_power = true,              -- the leading edge loops: DC bus 2 or the battery bus (ATA26_28 p.285)
        hot_bat = true,                 -- the switches' unlock solenoids and the squibs: main hot
                                        -- battery bus (FCOM p.820)
        fuel_cutoff = four(false),      -- FUEL CONTROL n in CUTOFF (unlocks fire switch n)
        test = false,                   -- FIRE/OVHT TEST held
        squib_test = {false, false},    -- SQUIB TEST 1, 2 held
        on_ground = true,
        apu_n1 = 0,
        cargo_arm = {false, false},     -- CARGO FIRE ARM FWD, AFT
        cargo_disch = false,            -- CARGO FIRE DISCH held
        -- the switches' commands, one frame each
        eng_toggle = four(false),       -- the fire switch pulled out, or pushed back in
        eng_override = four(false),     -- Fire Override pushed and the switch pulled
        eng_rotate = four(0),           -- rotated one step: -1 counterclockwise, 1 clockwise
        apu_toggle = false,
        apu_override = false,
        apu_rotate = 0,
    }
end

local function full(b)
    if b >= M.CGO_A then return M.CGO_PSI end
    return M.BTL_PSI
end
local function low(b)
    if b >= M.CGO_A then return M.CGO_LOW_PSI end
    return M.BTL_LOW_PSI
end

function M.new()
    local s = {pulled = four(false), rot = four(0), apu_pulled = false, apu_rot = 0,
        btl = {}, squib = {}, disch_t = list(M.BOTTLES, 0), disch_s = list(M.BOTTLES, M.DISCH_S),
        disch_into = list(M.BOTTLES, 0), test_t = 0,
        lp_t = {a = list(M.ZONES, 0), b = list(M.ZONES, 0)}, power_off_t = 0, apu_disch_t = 0,
        cargo_cfg = list(4, "dual"), det_power_was = false, cargo_latch = 0, cargo_t = 0,
        cargo_cd_fired = false, cargo_disch_was = false, cgo_det_t = {0, 0}, cgo_air_t = 0,
        duct_t = {0, 0}}
    for b = 1, M.BOTTLES do
        s.btl[b] = full(b)
        s.squib[b] = {}
    end
    s.out = {alarm = list(M.ZONES, false), fire = list(M.ZONES, false),
        det_failed = list(M.ZONES, false), lp_a = list(M.ZONES, false), lp_b = list(M.ZONES, false),
        eng_light = four(false), apu_light = false, cargo_light = {false, false},
        unlocked = four(false), pulled = four(false), rot = four(0),
        apu_unlocked = false, apu_pulled = false, apu_rot = 0,
        btl_psi = list(M.BOTTLES, 0), btl_low = list(M.BOTTLES, false), extinguish = four(false),
        apu_extinguish = false, cargo_agent = {false, false}, apu_shutdown = false, apu_horn = false,
        cargo_fire = {false, false}, cargo_disch_light = false, cgo_btl_disch = false,
        cargo_det_air = false, cargo_det_air_status = false, cargo_det_status = {false, false},
        wheel_well_fire = false, duct_leak = {false, false, false}, duct_leak_status = {false, false},
        lav_smoke = false, rest_smoke = false, squib_light = list(9, false),
        test_in_prog = false, test_pass = false, test_fail = false, sys_power = false}
    for b = 1, M.BOTTLES do s.out.btl_psi[b] = s.btl[b] end
    return s
end

-- a bottle's squib for one outlet: fires once; a bottle with agent left
-- empties into that outlet (in seconds, s: C and D through their regulator)
local function fire_squib(s, b, outlet, seconds)
    if s.squib[b][outlet] then return end
    s.squib[b][outlet] = true
    if s.btl[b] > low(b) and s.disch_t[b] == 0 then
        s.disch_t[b] = seconds or M.DISCH_S
        s.disch_s[b] = seconds or M.DISCH_S
        s.disch_into[b] = outlet
    end
end

local function heat_of(inp, z)
    if z <= M.ENG_OVHT then return inp.eng_fire_heat[z - M.ENG_FIRE] end
    if z < M.APU then return inp.eng_ovht_heat[z - M.ENG_OVHT] end
    if z == M.APU then return inp.apu_fire_heat end
    -- cargo smoke reaches the detectors only with the venturi's airflow (estimate)
    return inp.cargo_smoke[z - M.CARGO] and inp.cargo_airflow
end

-- a detector's output from its loops' alarms a, b: the APU detector with
-- either loop; the engine detectors with both, or with the one loop left
-- working; the cargo detectors as configured at power-up or the last test
local function decide(s, z, ok_a, ok_b, a, b)
    if z == M.APU then return a or b end
    local cfg
    if z > M.CARGO then
        cfg = s.cargo_cfg[z - M.CARGO]
    elseif ok_a and ok_b then cfg = "dual"
    elseif ok_a then cfg = "a"
    elseif ok_b then cfg = "b"
    else cfg = "none" end
    if cfg == "dual" then return a and b end
    if cfg == "a" then return a end
    if cfg == "b" then return b end
    return false
end

-- a STATUS timer: counting while bad, else back to 0
local function timer(t, bad, dt)
    if bad then return t + dt end
    return 0
end

-- the cargo detectors reconfigure at power-up and after a manual test
-- (FCOM p.919; ATA26_28 p.154, p.162)
local function configure_cargo(s, inp)
    for k = 1, 4 do
        local z = M.CARGO + k
        local ok_a = inp.det_power and not inp.loop_failed_a[z]
        local ok_b = inp.det_power and not inp.loop_failed_b[z]
        if ok_a and ok_b then s.cargo_cfg[k] = "dual"
        elseif ok_a then s.cargo_cfg[k] = "a"
        elseif ok_b then s.cargo_cfg[k] = "b"
        else s.cargo_cfg[k] = "none" end
    end
end

function M.update(s, inp, dt)
    local out = s.out
    local test = inp.test

    if inp.det_power and not s.det_power_was then configure_cargo(s, inp) end
    s.det_power_was = inp.det_power

    -- the dual loop detectors (FCOM p.914, p.919; ATA26_28 p.20, p.25-46,
    -- p.88-102, p.140-162). "alarm" counts the test, "fire" not
    local all_ok = inp.det_power
    for z = 1, M.ZONES do
        local ok_a = inp.det_power and not inp.loop_failed_a[z]
        local ok_b = inp.det_power and not inp.loop_failed_b[z]
        local heat = heat_of(inp, z)
        out.alarm[z] = decide(s, z, ok_a, ok_b, ok_a and (heat or test), ok_b and (heat or test))
        out.fire[z] = decide(s, z, ok_a, ok_b, ok_a and heat, ok_b and heat)
        out.det_failed[z] = inp.det_power and inp.loop_failed_a[z] and inp.loop_failed_b[z]
        if not (ok_a and ok_b) then all_ok = false end
        -- STATUS ... LP A, B: that loop in alarm or failed, 20 s
        s.lp_t.a[z] = timer(s.lp_t.a[z], inp.det_power and (not ok_a or heat), dt)
        s.lp_t.b[z] = timer(s.lp_t.b[z], inp.det_power and (not ok_b or heat), dt)
        out.lp_a[z] = s.lp_t.a[z] >= M.STATUS_S
        out.lp_b[z] = s.lp_t.b[z] >= M.STATUS_S
    end
    -- STATUS FIRE/OVHT SYS: no power for the detection, 20 s
    s.power_off_t = timer(s.power_off_t, not inp.det_power, dt)
    out.sys_power = s.power_off_t >= M.STATUS_S

    -- the lower cargo compartments (FCOM p.914, p.921; ATA26_28 p.140-164):
    -- FIRE CARGO FWD (zones 1, 2) and AFT (3, 4); CARGO DET FWD, AFT with
    -- both loops of a zone failed (20 s); >CARGO DET AIR without the
    -- venturi's airflow, two engines running (60 s for the status)
    for c = 1, 2 do
        local z1, z2 = M.CARGO + 2 * c - 1, M.CARGO + 2 * c
        out.cargo_fire[c] = out.fire[z1] or out.fire[z2]
        out.cargo_light[c] = out.alarm[z1] or out.alarm[z2]
        s.cgo_det_t[c] = timer(s.cgo_det_t[c], out.det_failed[z1] or out.det_failed[z2], dt)
        out.cargo_det_status[c] = s.cgo_det_t[c] >= M.STATUS_S
    end
    out.cargo_det_air = not inp.cargo_airflow and inp.engines_running >= M.CGO_DET_ENGINES
    s.cgo_air_t = timer(s.cgo_air_t, out.cargo_det_air, dt)
    out.cargo_det_air_status = s.cgo_air_t >= M.STATUS_LONG_S

    -- the wheel well loop (AC bus 2) and the leading edge overheat switches
    -- (ATA26_28 p.270-274, p.280-286; FCOM p.613, p.619, p.922)
    local ww_alarm = inp.wheel_well_power and (inp.wheel_well_heat or test)
    out.wheel_well_fire = inp.wheel_well_power and inp.wheel_well_heat
    if not inp.wheel_well_power then all_ok = false end
    for d = 1, 3 do out.duct_leak[d] = inp.duct_power and inp.duct_leak[d] end
    if not inp.duct_power then all_ok = false end
    s.duct_t[1] = timer(s.duct_t[1], out.duct_leak[1], dt)
    s.duct_t[2] = timer(s.duct_t[2], out.duct_leak[3], dt)
    out.duct_leak_status[1] = s.duct_t[1] >= M.STATUS_LONG_S     -- L
    out.duct_leak_status[2] = s.duct_t[2] >= M.STATUS_LONG_S     -- R
    -- the lavatory and crew rest smoke detectors (FCOM p.923; ATA26_28 p.290-320)
    out.lav_smoke = inp.lav_smoke
    out.rest_smoke = inp.rest_smoke

    -- FIRE/OVHT TEST (FCOM p.910, p.919-920; ATA26_28 p.30, p.42, p.272,
    -- p.284): TEST IN PROG, after 5 s FIRE TEST PASS when every loop
    -- answered, else FAIL; all clear when released. The cargo detectors
    -- reconfigure when it completes
    local was_done = s.test_t >= M.TEST_S
    s.test_t = timer(s.test_t, test, dt)
    local done = s.test_t >= M.TEST_S
    if done and not was_done then configure_cargo(s, inp) end
    out.test_in_prog = test and not done
    out.test_pass = test and done and all_ok and ww_alarm
    out.test_fail = test and done and not (all_ok and ww_alarm)

    -- the fire warning lights: the fire switches (and the FUEL CONTROL
    -- lights, which the 3D wires to X-Plane), APU, CARGO FWD and AFT
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
        if s.apu_rot ~= 0 and s.apu_rot ~= before and inp.hot_bat then fire_squib(s, M.APU_BTL, M.OUT_APU) end
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
        if s.apu_disch_t >= M.APU_DISCH_S and inp.hot_bat then fire_squib(s, M.APU_BTL, M.OUT_APU) end
    else
        s.apu_disch_t = 0
    end
    out.apu_horn = inp.on_ground and out.alarm[M.APU] and not s.apu_pulled

    -- the cargo discharge (FCOM p.908, p.917; ATA26_28 p.184-187): DISCH
    -- fires A and B into the armed compartments at once; with one
    -- compartment armed it locks in, and C and D follow 30 min later in
    -- flight, at touchdown, or at once on the ground (two compartments
    -- armed: no lock-in, estimate from the circuit drawing)
    local pushed = inp.cargo_disch and not s.cargo_disch_was
    s.cargo_disch_was = inp.cargo_disch
    out.cargo_agent[1], out.cargo_agent[2] = false, false   -- agent into a compartment, this frame
    if pushed and inp.hot_bat then
        local a, b = M.CGO_A, M.CGO_A + 1
        local agent = s.btl[a] > low(a) or s.btl[b] > low(b) or s.disch_t[a] > 0 or s.disch_t[b] > 0
        local armed = 0
        for c = 1, 2 do
            if inp.cargo_arm[c] then
                armed = armed + 1
                local outlet = M.OUT_FWD + c - 1
                fire_squib(s, a, outlet)
                fire_squib(s, b, outlet)
                out.cargo_agent[c] = agent
            end
        end
        if armed == 1 and s.cargo_latch == 0 then
            s.cargo_latch = inp.cargo_arm[1] and 1 or 2
            s.cargo_t = 0
        end
    end
    if s.cargo_latch > 0 and not s.cargo_cd_fired then
        s.cargo_t = s.cargo_t + dt
        if (inp.on_ground or s.cargo_t >= M.CGO_DELAY_S) and inp.hot_bat then
            local outlet = M.OUT_FWD + s.cargo_latch - 1
            fire_squib(s, M.CGO_A + 2, outlet, M.CGO_METER_S)
            fire_squib(s, M.CGO_A + 3, outlet, M.CGO_METER_S)
            s.cargo_cd_fired = true
        end
    end

    -- the bottles: a squib empties its bottle into its outlet (X-Plane's
    -- extinguisher while the agent flows); BTL DISCH and the low messages
    -- at the pressure switches
    for n = 1, 4 do out.extinguish[n] = false end
    out.apu_extinguish = false
    for b = 1, M.BOTTLES do
        if s.disch_t[b] > 0 then
            local step = math.min(s.disch_t[b], dt)
            s.btl[b] = math.max(0, s.btl[b] - full(b) * step / s.disch_s[b])
            s.disch_t[b] = s.disch_t[b] - step
            if s.disch_t[b] <= 0 then
                s.disch_t[b] = 0
                s.btl[b] = 0
            end
            local into = s.disch_into[b]
            if into >= 1 and into <= 4 then out.extinguish[into] = true
            elseif into == M.OUT_APU then out.apu_extinguish = true end
        end
        out.btl_psi[b] = s.btl[b]
        out.btl_low[b] = s.btl[b] <= low(b)
    end
    -- CARGO FIRE DISCH light: bottle A or B discharged; >CGO BTL DISCH: on
    -- the ground any cargo bottle low, in flight A and B discharged (FCOM
    -- p.908, p.921; ATA26_28 p.178, p.192-193)
    local a_low, b_low = out.btl_low[M.CGO_A], out.btl_low[M.CGO_A + 1]
    out.cargo_disch_light = a_low or b_low
    if inp.on_ground then
        out.cgo_btl_disch = a_low or b_low or out.btl_low[M.CGO_A + 2] or out.btl_low[M.CGO_A + 3]
    else
        out.cgo_btl_disch = a_low and b_low
    end

    -- the squib test (FCOM p.187-188; ATA26_28 p.80-82, p.132-134,
    -- p.196-198): TEST 1 through the bottles A (cargo: forward squibs), TEST
    -- 2 through the bottles B (cargo: aft squibs); a fired squib stays dark;
    -- cargo A and B are not tested with a cargo compartment armed
    local t1, t2 = inp.squib_test[1], inp.squib_test[2]
    local armed_any = inp.cargo_arm[1] or inp.cargo_arm[2]
    for n = 1, 4 do
        local a = n <= 2 and 1 or 3
        out.squib_light[n] = inp.hot_bat and ((t1 and not s.squib[a][n]) or (t2 and not s.squib[a + 1][n]))
    end
    out.squib_light[5] = inp.hot_bat and (t1 or t2) and not s.squib[M.APU_BTL][M.OUT_APU]
    for k = 0, 3 do
        local b = M.CGO_A + k
        local lit = inp.hot_bat and ((t1 and not s.squib[b][M.OUT_FWD]) or (t2 and not s.squib[b][M.OUT_AFT]))
        if k <= 1 and armed_any then lit = false end
        out.squib_light[6 + k] = lit
    end
    return out
end

return M
