-- 747-400 engine start, ignition and engine fuel valves without X-Plane: for
-- each engine the start sequence (manual, and the EEC autostart with its
-- light-off, hot and hung start checks, retries and aborts), the start
-- valve command and the START switch cutout, the igniters (the conditions,
-- the AUTO and STBY IGNITION selectors and their power) and the engine fuel
-- valve, plus the EICAS messages of these. Logic and sources:
-- docs/overhaul/notes/ATA-70-80.md §3-4 (FCOM 7.13, 7.20, 7.40 p.859-902;
-- ATA70_80 for the CF6; airplane 109 PW4056 and 570 CF6-80C2).
--
--   local S = B747_engine_start_model
--   local s = S.new()
--   local inp = S.inputs()                 -- fill it every frame
--   local out = S.update(s, inp, dt)       -- the same table every frame

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
-- (a bare table would be copied there before the functions are added)
local M = setmetatable({}, {})
B747_engine_start_model = M

-- the start phases of one engine
M.OFF = "off"               -- no start (stopped, or running after a start)
M.MOTOR = "motor"           -- starter turning, no fuel yet
M.LIGHT = "light"           -- fuel and ignition on, waiting for the light-off
M.ACCEL = "accel"           -- burning, accelerating to idle
M.DRY = "dry"               -- autostart: fuel off, motoring before a retry or after an abort
M.ABORTED = "aborted"       -- autostart gave up on the ground; held until CUTOFF

-- values from the sources
M.CUTOUT_N2 = 50                    -- START switch released, start valve closes (FCOM p.862, p.879)
M.FUEL_ON_N2 = {GE = 15, PW = 20}   -- autostart fuel on (CF6: ATA70_80 p.564-565; PW: estimate)
M.LIGHT_OFF_S = {GE = {20, 15, 15}, PW = {20, 20}}   -- light-off window per attempt (ATA70_80 p.564; FCOM p.185)
M.ATTEMPTS = {GE = 3, PW = 2}       -- ground attempts before the abort (FCOM p.880-881)
M.DRY_MOTOR_S = 30                  -- motoring after a failed light-off or an abort (FCOM p.880-881)
M.FUEL_CUT_S = 6                    -- fuel off before it goes back on after a hot or hung start (ATA70_80 p.566-569)
M.START_LIMIT = {GE = 750, PW = 535}   -- EGT start limit, °C (CF6: ATA70_80 p.395; PW: the previous code, no source)
M.TAKEOFF_LIMIT = {GE = 960, PW = 654} -- EGT takeoff limit (CF6: ATA70_80 p.395; PW: the previous code)
M.HUNG_RATE = 0.15                  -- %N2/s: below this for HUNG_S the start hangs (CF6 windmill: ATA70_80 p.568)
M.HUNG_S = 15
M.STARTER_CUTOUT_N2, M.STARTER_CUTOUT_S = 54, 5   -- valve still open (ATA70_80 p.558-559)
M.START_VLV_S = 8                   -- start valve disagreement (ATA70_80 p.558-559)
M.FUEL_VLV_S = 5                    -- engine fuel or spar valve disagreement (ATA70_80 p.168-169)
M.FAIL_N2 = 52                      -- ENG FAIL below this in the air with fuel on (ATA70_80 p.230)
-- estimates (no values in the sources)
M.HOT_MARGIN = 25                   -- °C under the limit counted as a hot start coming
M.IDLE_RATE, M.IDLE_S = 0.15, 5     -- start complete: N2 above IDLE_MIN_N2 and settled this long
M.IDLE_MIN_N2 = 55
M.STARTER_MAX_N2 = 60               -- X-Plane's starter is let go above this even if air still turns it

-- the AUTO IGNITION selector (laminar/B747/electrical/auto_ignit/sel_dial_pos)
-- 0 = 1, 1 = BOTH, 2 = 2; GE has SINGLE and BOTH (FCOM p.861-864): 0 and 2
-- are SINGLE there. STBY IGNITION: 0 = 1, 1 = NORM, 2 = 2.
M.AUTO_1, M.AUTO_BOTH, M.AUTO_2 = 0, 1, 2
M.STBY_1, M.STBY_NORM, M.STBY_2 = 0, 1, 2

local function four(v) return {v, v, v, v} end

function M.inputs()
    return {
        type = "PW",                        -- "PW" (also RR, PLAN.md §5) or "GE"
        autostart_installed = true,         -- 109 and 570; not 405 (FCOM p.861)
        autostart = true,                   -- AUTOSTART switch ON
        start_sw = four(false),             -- START switch pulled
        fuel_control = four(false),         -- RUN
        fire_out = four(false),             -- engine fire switch pulled
        n2 = four(0), egt = four(0),        -- %, °C (as the EICAS shows them)
        burning = four(false),              -- the engine burns fuel
        start_valve = four(false),          -- the start valve is open (bleed model)
        spar_valve = four(0),               -- spar valve position (fuel model)
        nai = four(false),                  -- nacelle anti-ice ON
        con = false,                        -- CON IGNITION ON
        auto_sel = M.AUTO_BOTH, stby_sel = M.STBY_NORM,
        flaps_out = false,                  -- TE flaps out of UP
        on_ground = true,
        ac1 = false, ac3 = false, ac_stby = false,   -- igniter power (ATA70_80 p.252-265)
        main_bat = false,                   -- engine fuel valve (ATA70_80 p.235)
        apu_bat = false,                    -- START switch hold-in solenoid (ATA70_80 p.554)
    }
end

local function new_engine()
    return {phase = M.OFF, t = 0, dry_s = 0, attempt = 0, starts = 0, air_start = false,
        n2_last = 0, slow_t = 0, settle_t = 0, aborted = false,
        hpsov = 0, metering = false, sv_t = 0, fv_t = 0, cut_t = 0, was_running = false}
end

function M.new()
    local s = {eng = {new_engine(), new_engine(), new_engine(), new_engine()}}
    s.out = {
        eng = {{}, {}, {}, {}},
        msg = {start_vlv = four(false), starter_cutout = four(false), fuel_vlv = four(false),
            autostart = four(false), fail = four(false), shutdown = four(false)},
    }
    return s
end

-- a new flight: the engine fuel valves where FUEL CONTROL puts them, the
-- engines that burn fuel counted as running, no start in progress
function M.settle(s, inp)
    for n = 1, 4 do
        local e = s.eng[n]
        e.hpsov = (inp.fuel_control[n] and not inp.fire_out[n]) and 1 or 0
        e.was_running = inp.burning[n]
        e.phase, e.t, e.attempt, e.aborted, e.settle_t = M.OFF, 0, 0, false, 0
        e.n2_last = inp.n2[n]
        e.sv_t, e.fv_t, e.cut_t = 0, 0, 0
    end
end

-- which igniters the selectors pick for a start, a flameout or the
-- conditions (FCOM p.863-864, p.882-883)
local function pick(inp, e, both)
    if both or inp.auto_sel == M.AUTO_BOTH then return true, true end
    if inp.type == "GE" then                   -- SINGLE: alternate every two ground starts
        local first = math.floor(e.starts / 2) % 2 == 0
        return first, not first
    end
    if inp.autostart_installed and inp.autostart then   -- 109: alternate the ground starts
        local first = e.starts % 2 == 0
        return first, not first
    end
    return inp.auto_sel == M.AUTO_1, inp.auto_sel == M.AUTO_2
end

function M.update(s, inp, dt)
    local out, msg = s.out, s.out.msg
    local ge = inp.type == "GE"
    local kind = ge and "GE" or "PW"
    local auto = inp.autostart_installed and inp.autostart
    local any_ign_fault = false
    for n = 1, 4 do
        local e, o = s.eng[n], out.eng[n]
        local run = inp.fuel_control[n] and not inp.fire_out[n]
        local n2, egt = inp.n2[n], inp.egt[n]
        local rate = dt > 0 and (n2 - e.n2_last) / dt or 0
        e.n2_last = n2
        e.t = e.t + dt
        local function go(phase, dry_s) e.phase, e.t, e.slow_t, e.dry_s = phase, 0, 0, dry_s or 0 end

        -- ======== the start sequence
        if not run then
            -- CUTOFF (or the fire switch) ends any start and clears the abort
            if e.phase ~= M.OFF then go(M.OFF) end
            e.attempt, e.aborted = 0, false
        elseif e.phase == M.OFF then
            -- a start begins with the START switch pulled and RUN below the cutout
            if inp.start_sw[n] and n2 < M.CUTOUT_N2 and not inp.burning[n] then
                e.air_start = not inp.on_ground
                e.attempt = 1
                e.starts = e.starts + (e.air_start and 0 or 1)
                go(auto and M.MOTOR or M.LIGHT)
            end
        end
        if e.phase ~= M.OFF and e.phase ~= M.ABORTED then
            if auto then
                -- the EEC autostart (FCOM p.879-881, ATA70_80 p.561-569)
                local hot = egt >= M.START_LIMIT[kind] - M.HOT_MARGIN
                local over = egt >= M.TAKEOFF_LIMIT[kind]
                if inp.burning[n] and rate < M.HUNG_RATE and n2 < M.IDLE_MIN_N2 then
                    e.slow_t = e.slow_t + dt
                else e.slow_t = 0 end
                local hung = e.slow_t >= M.HUNG_S
                local before_cutout = n2 < M.CUTOUT_N2
                -- a retry (with 30 s of motoring first, or the fuel put back at
                -- once) or, after the last try, the abort: GE motors 30 s before
                -- closing the valves, 109 does not motor (FCOM p.880-881)
                local function retry_or_abort(motor_first)
                    if e.attempt >= M.ATTEMPTS[kind] then
                        e.aborted = true
                        if ge then go(M.DRY, M.DRY_MOTOR_S) else go(M.ABORTED) end
                    else
                        e.attempt = e.attempt + 1
                        go(M.DRY, motor_first and M.DRY_MOTOR_S or M.FUEL_CUT_S)
                    end
                end
                if e.phase == M.MOTOR then
                    if n2 >= M.FUEL_ON_N2[kind] then go(M.LIGHT) end
                elseif e.phase == M.LIGHT then
                    if inp.burning[n] then go(M.ACCEL)
                    elseif e.t >= (M.LIGHT_OFF_S[kind][e.attempt] or 15) and not e.air_start then
                        -- no light-off: fuel and ignition off, 30 s motoring, retry
                        -- with both igniters (GE 3 tries, 109 2)
                        retry_or_abort(true)
                    end
                elseif e.phase == M.ACCEL then
                    if e.air_start then
                        -- in the air: fuel cut and put back on a hung start or a
                        -- hot start; no abort (FCOM p.881)
                        if hung or (ge and over) or (not ge and hot) then go(M.DRY, M.FUEL_CUT_S) end
                    elseif before_cutout and (hot or hung) then
                        if ge then
                            -- GE: cut the fuel, adjust the schedule and put it back
                            retry_or_abort(false)
                        elseif hot then
                            retry_or_abort(true)          -- 109: hot start, 30 s motoring and retry
                        else
                            e.aborted = true              -- 109: a hung start aborts at once
                            go(M.ABORTED)
                        end
                    elseif not before_cutout and (hot or hung) then
                        e.aborted = true                  -- after the cutout: abort, no motoring
                        go(M.ABORTED)
                    end
                elseif e.phase == M.DRY then
                    if e.t >= e.dry_s then
                        if e.aborted then go(M.ABORTED) else go(M.LIGHT) end
                    end
                end
            else
                -- manual: fuel with RUN, the crew watches (FCOM p.882, p.184-186)
                if e.phase == M.MOTOR or e.phase == M.DRY then go(M.LIGHT) end
                if e.phase == M.LIGHT and inp.burning[n] then go(M.ACCEL) end
            end
            -- the start ends at a settled idle (estimate)
            if e.phase == M.ACCEL and n2 >= M.IDLE_MIN_N2 and math.abs(rate) < M.IDLE_RATE then
                e.settle_t = e.settle_t + dt
                if e.settle_t >= M.IDLE_S then go(M.OFF) end
            else e.settle_t = 0 end
        end

        -- ======== start valve command, START switch and X-Plane's starter
        local starting = e.phase == M.MOTOR or e.phase == M.LIGHT or e.phase == M.ACCEL or e.phase == M.DRY
        if auto then
            -- the START switch arms; the EEC opens the valve once RUN (FCOM p.862, p.879)
            o.start_cmd = inp.start_sw[n] and run and starting and n2 < M.CUTOUT_N2
        else
            o.start_cmd = inp.start_sw[n] and n2 < M.CUTOUT_N2
        end
        -- the hold-in solenoid lets the switch go at 50 % N2, without its
        -- power, and at the end of an autostart abort (ATA70_80 p.554, FCOM p.880)
        o.release_start_sw = inp.start_sw[n] and (n2 >= M.CUTOUT_N2 or not inp.apu_bat
            or (auto and e.phase == M.ABORTED))
        o.starter = inp.start_valve[n] and n2 < M.STARTER_MAX_N2

        -- ======== engine fuel valve: the HPSOV with RUN and the fire switch in
        -- (main battery bus; latching, holds without power), the fuel metering
        -- by the EEC in an autostart (FCOM p.860, p.886; ATA70_80 p.165-169)
        if inp.main_bat then e.hpsov = run and 1 or 0 end
        if auto and starting then
            e.metering = e.phase == M.LIGHT or e.phase == M.ACCEL
        elseif auto and e.phase == M.ABORTED then
            e.metering = false
        else
            e.metering = run
        end
        o.fuel_valve = e.hpsov
        o.fuel = e.hpsov > 0.5 and e.metering

        -- ======== igniters (FCOM p.862-864, p.882-883; ATA70_80 p.252-271)
        local burning_before = e.was_running
        e.was_running = inp.burning[n] or (e.was_running and n2 >= M.FAIL_N2)
        local flameout = not inp.on_ground and run and burning_before and not inp.burning[n]
        local want, both = false, false
        if starting then
            -- the start ignition ends at the cutout, with the START switch (FCOM p.879)
            if auto then want = (e.phase == M.LIGHT or e.phase == M.ACCEL) and n2 < M.CUTOUT_N2
            else want = n2 < M.CUTOUT_N2 end
            both = e.air_start or (auto and e.attempt > 1)
        end
        if inp.con or inp.flaps_out or inp.nai[n] then want = true end
        if flameout and (ge or auto) then want, both = true, true end   -- auto-relight (109: autostart ON)
        local w1, w2 = false, false
        if want then w1, w2 = pick(inp, e, both) end
        -- power: igniter 1 on AC bus 1, 2 on AC bus 3; the standby bus feeds
        -- the selected one continuously, or with NORM takes over without AC
        -- (GE both, PW igniter 1)
        local p1, p2 = inp.ac1, inp.ac3
        if inp.ac_stby then
            if inp.stby_sel == M.STBY_1 then w1, p1 = true, true
            elseif inp.stby_sel == M.STBY_2 then w2, p2 = true, true
            else
                if not inp.ac1 then p1 = true end
                if not inp.ac3 and ge then p2 = true end
            end
        end
        o.igniter1 = run and w1 and p1
        o.igniter2 = run and w2 and p2
        o.ignition = o.igniter1 or o.igniter2
        -- ENG IGNITION: CON (PW also TE flaps out of UP) and no igniter firing (FCOM p.900)
        local should = inp.con or (not ge and inp.flaps_out)
        if run and should and not o.ignition then any_ign_fault = true end

        -- ======== messages
        local sv_open = inp.start_valve[n]
        if o.start_cmd ~= sv_open then e.sv_t = e.sv_t + dt else e.sv_t = 0 end
        msg.start_vlv[n] = e.sv_t >= M.START_VLV_S
        if sv_open and n2 > M.STARTER_CUTOUT_N2 then e.cut_t = e.cut_t + dt else e.cut_t = 0 end
        msg.starter_cutout[n] = e.cut_t >= M.STARTER_CUTOUT_S
        local fv_wrong = (e.hpsov > 0.5) ~= run or (inp.spar_valve[n] > 0.5) ~= run
        if fv_wrong then e.fv_t = e.fv_t + dt else e.fv_t = 0 end
        msg.fuel_vlv[n] = e.fv_t >= M.FUEL_VLV_S
        -- ENG AUTOSTART: the ground autostart gave up, or (autostart OFF) RUN
        -- below the fuel-on speed (109, 570; FCOM p.899)
        msg.autostart[n] = inp.autostart_installed and inp.on_ground and (e.aborted
            or (not inp.autostart and run and not inp.burning[n] and n2 < M.FUEL_ON_N2[kind]))
        -- ENG FAIL: failure or flameout, fuel on, inhibited on the ground
        -- (FCOM p.899; CF6 N2 < 52 %: ATA70_80 p.230). >ENG SHUTDOWN: fire
        -- switch pulled or CUTOFF (FCOM p.902; on the ground not shown: estimate)
        msg.fail[n] = not inp.on_ground and run and n2 < M.FAIL_N2
        msg.shutdown[n] = not inp.on_ground and (inp.fire_out[n] or not inp.fuel_control[n])
        -- (the FMC's step 9h3) the engine inoperative, failed, flamed out or
        -- shut down, for the FMC, the AFDS and the A/T: below the ENG FAIL
        -- speed, also on the ground (estimate: their sources give no speed)
        o.inop = n2 < M.FAIL_N2
        o.phase = e.phase
        o.attempt = e.attempt
    end
    msg.autostart_off = inp.autostart_installed and not inp.autostart
    msg.eng_ignition = any_ign_fault
    msg.con_memo = inp.con and not any_ign_fault
    msg.stby_memo = inp.stby_sel ~= M.STBY_NORM
    return out
end

return M
