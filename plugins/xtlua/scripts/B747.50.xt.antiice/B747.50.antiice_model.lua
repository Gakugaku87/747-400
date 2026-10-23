-- 747-400 ice and rain protection without X-Plane: the nacelle anti-ice
-- valves (NAI), the wing anti-ice valves (WAI), the windshield heat, the
-- probe heat, the ice detectors, the wipers' speed, and the EICAS messages
-- and P5 lights of the system. Logic and sources: docs/overhaul/notes/
-- ATA-30.md §2-§4 (FCOM 3.10-3.30 p.625-635; ATA30_32_35_36 30-11, 30-21,
-- 30-31, 30-41, 30-81; LH36 30-10, 30-80).
--
--   local I = B747_antiice_model          -- in XTLua, after dofile
--   local I = dofile(".../B747.50.antiice_model.lua")   -- in the tests
--   local s = I.new()
--   local inp = I.inputs()                -- fill it every frame
--   local out = I.update(s, inp, dt)      -- the same table every frame

local M = setmetatable({}, {})
B747_antiice_model = M

M.NAI_ALERT_S = 3.5         -- NAI VALVE n: the valve not where commanded, the engine running
                            -- (ATA30_32_35_36 p.206)
M.WAI_ALERT_S = 5           -- WAI VALVE LEFT, RIGHT (ATA30_32_35_36 p.184)
M.WINDOW_RESET_S = 10       -- WINDOW HEAT off 10 s, then ON, resets a controller fault (FCOM p.633)
M.DETECTOR_ALERT_S = 2      -- >ICE DETECTORS: either detector failed (ATA30_32_35_36 p.164)
M.DETECTOR_STATUS_S = 12    -- STATUS ICE DETECTOR L, R
M.HEAT_TAT_S = 15           -- HEAT L, R TAT (ATA30_32_35_36 p.228)
M.ANTI_ICE_TAT_C = 12       -- >ANTI-ICE: anti-ice on above TAT 12°C without ice detected (FCOM p.635)
-- the heated probes in the order of their EICAS messages' slots
-- (B747.87.xt.warning.lua): pitot-static and AOA heated with any engine
-- running, TAT in flight (FCOM p.634; ATA30_32_35_36 p.216-232)
M.PROBES = {"P/S CAPT", "P/S F/O", "P/S L AUX", "P/S R AUX", "L AOA", "R AOA", "L TAT", "R TAT"}
M.PROBE_IN_FLIGHT = {false, false, false, false, false, false, true, true}
-- X-Plane's wiper speed for OFF, LO, HI: 50 and 100 % of the acf's 2
-- cycles a second (the real LO 160 and HI 250 a minute are faster:
-- ATA30_32_35_36 p.264; the acf is not changed)
M.WIPER_SPEED = {[0] = 0, 2, 3}
-- estimates (no value in the sources)
M.NAI_MIN_PSI = 12          -- the NAI valve opens with bleed air (pneumatic: FCOM p.625)
M.NAI_TRAVEL_S = 1          -- the NAI valve
M.WAI_TRAVEL_S = 2.5        -- the WAI valves' motors: less than 3 s (LH36 p.126)
M.PROBE_BUS = {1, 2, 1, 2, 1, 2, 1, 2}  -- 115V AC: the left probes bus 1, the right ones bus 2
M.WINDOW_BUS = {1, 2}       -- the windshields' 115V AC and 28V DC buses
M.WIPER_BUS = {1, 2}        -- the wipers' 28V DC buses

local function four(v) return {v, v, v, v} end
local function eight(v) return {v, v, v, v, v, v, v, v} end

function M.inputs()
    return {
        nai_on = four(false),           -- NACELLE ANTI-ICE switches 1-4
        wai_on = false,                 -- WING ANTI-ICE switch
        window_on = {false, false},     -- WINDOW HEAT L, R
        wiper = {0, 0},                 -- WIPER L, R: 0 OFF, 1 LO, 2 HI
        nai_psi = four(0),              -- each engine's bleed air to its NAI valve (the PRV side)
        engine_running = four(false),
        on_ground = true,               -- the air/ground relay
        tat_c = 15,
        icing = false,                  -- ice on the detectors (X-Plane's ice detection)
        ac = four(true),                -- AC bus 1-4
        dc = four(true),                -- DC bus 1-4
        nai_failed = four(false),       -- failure: an NAI valve (cowl overheat: closed, latched)
        wai_failed = {false, false},    -- failure: a WAI valve (stays where it is)
        window_failed = {false, false}, -- failure: a windshield's heat
        probe_failed = eight(false),    -- failure: a probe's heater (M.PROBES)
        detector_failed = {false, false},   -- failure: ice detector L, R
    }
end

function M.new()
    local s = {first = true, nai = four(0), nai_latch = four(false), nai_t = four(0),
        wai = {0, 0}, wai_t = {0, 0}, win_fault = {false, false}, win_off_t = {0, 0},
        tat_t = {0, 0}, det_t = {0, 0}, saw_ice = false}
    s.out = {nai_valve = four(0), nai_light = four(false), nai_alert = four(false),
        wai_valve = {0, 0}, wai_light = false, wai_alert = {false, false},
        window_heat = {false, false}, window_inop = {false, false}, window_alert = {false, false},
        side_window_heat = false, probe_heat = eight(false), probe_alert = eight(false),
        detector_on = false, detecting = false, icing_alert = false, no_icing_alert = false,
        anti_ice_alert = false, detectors_alert = false, detector_status = {false, false},
        wiper_speed = {0, 0}}
    return s
end

local function travel(pos, target, seconds, dt)
    local step = dt / seconds
    if pos < target then return math.min(target, pos + step) end
    return math.max(target, pos - step)
end

function M.update(s, inp, dt)
    local out = s.out

    -- NAI (FCOM p.625, p.631; ATA30_32_35_36 p.198-206): the switch's
    -- solenoid (28V DC: estimate, the engine's bus) lets the bleed air open
    -- the valve; an overheat closes it latched until the switch goes off
    -- (estimate: the sources say the switch off briefly). VALVE light: the
    -- valve not where the switch is; NAI VALVE n after 3.5 s with the
    -- engine running
    for n = 1, 4 do
        if inp.nai_failed[n] then s.nai_latch[n] = true end
        if not inp.nai_on[n] and not inp.nai_failed[n] then s.nai_latch[n] = false end
        local cmd = inp.nai_on[n] and inp.dc[n] and not s.nai_latch[n]
        local target = (cmd and inp.nai_psi[n] >= M.NAI_MIN_PSI) and 1 or 0
        if s.first then s.nai[n] = target else s.nai[n] = travel(s.nai[n], target, M.NAI_TRAVEL_S, dt) end
        out.nai_valve[n] = s.nai[n]
        local disagree = (inp.nai_on[n] and s.nai[n] < 1) or (not inp.nai_on[n] and s.nai[n] > 0)
        out.nai_light[n] = disagree
        if disagree and inp.engine_running[n] then s.nai_t[n] = s.nai_t[n] + dt else s.nai_t[n] = 0 end
        out.nai_alert[n] = s.nai_t[n] >= M.NAI_ALERT_S
    end

    -- WAI (FCOM p.625-626, p.633; LH36 p.112-126; ATA30_32_35_36 p.176-184):
    -- the switch in the air (the air/ground relay) and DC bus 2 command both
    -- valves; their motors (AC bus 2) move them whatever the duct pressure.
    -- VALVE light: either valve not where commanded (the circuit compares
    -- the command: on the ground with the switch ON it stays out, estimate);
    -- WAI VALVE LEFT, RIGHT after 5 s
    local wai_cmd = inp.wai_on and not inp.on_ground and inp.dc[2]
    local wai_target = wai_cmd and 1 or 0
    out.wai_light = false
    for w = 1, 2 do
        if s.first then s.wai[w] = wai_target
        elseif inp.ac[2] and not inp.wai_failed[w] then s.wai[w] = travel(s.wai[w], wai_target, M.WAI_TRAVEL_S, dt) end
        out.wai_valve[w] = s.wai[w]
        local disagree = (wai_cmd and s.wai[w] < 1) or (not wai_cmd and s.wai[w] > 0)
        if disagree then out.wai_light = true end
        if disagree then s.wai_t[w] = s.wai_t[w] + dt else s.wai_t[w] = 0 end
        out.wai_alert[w] = s.wai_t[w] >= M.WAI_ALERT_S
    end

    -- windshield heat (FCOM p.628, p.633, p.635; ATA30_32_35_36 p.246-250):
    -- a fault latches the power off until the switch is off 10 s and ON
    -- again; INOP and HEAT WINDOW L, R while the windshield has no power,
    -- with the switch off too (FCOM: power removed). The side windows heat
    -- with AC power
    for w = 1, 2 do
        local bus = M.WINDOW_BUS[w]
        local powered = inp.ac[bus] and inp.dc[bus]
        if inp.window_failed[w] and inp.window_on[w] and powered then s.win_fault[w] = true end
        if inp.window_on[w] then
            if s.win_off_t[w] >= M.WINDOW_RESET_S and not inp.window_failed[w] then s.win_fault[w] = false end
            s.win_off_t[w] = 0
        else
            s.win_off_t[w] = s.win_off_t[w] + dt
        end
        local heat = inp.window_on[w] and powered and not s.win_fault[w]
        out.window_heat[w] = heat
        out.window_inop[w] = not heat
        out.window_alert[w] = not heat
    end
    out.side_window_heat = inp.ac[1] or inp.ac[2] or inp.ac[3] or inp.ac[4]

    -- probe heat (FCOM p.634-635; ATA30_32_35_36 p.216-234): HEAT ... while
    -- a probe should be heated and has no current (a failure or no power);
    -- HEAT L, R TAT after 15 s
    local any_engine = inp.engine_running[1] or inp.engine_running[2] or inp.engine_running[3]
        or inp.engine_running[4]
    for p = 1, 8 do
        local cmd
        if M.PROBE_IN_FLIGHT[p] then cmd = not inp.on_ground else cmd = any_engine end
        local heat = cmd and inp.ac[M.PROBE_BUS[p]] and not inp.probe_failed[p]
        out.probe_heat[p] = heat
        local alert = cmd and not heat
        if M.PROBE_IN_FLIGHT[p] then
            local t = p - 6
            if alert then s.tat_t[t] = s.tat_t[t] + dt else s.tat_t[t] = 0 end
            alert = s.tat_t[t] >= M.HEAT_TAT_S
        end
        out.probe_alert[p] = alert
    end

    -- the ice detectors (FCOM p.631, p.635; LH36 p.106; ATA30_32_35_36
    -- p.158-164): L on AC bus 1, R on AC bus 3, in flight only. >ICING
    -- while they detect ice; >NO ICING once they no longer do, while anti-ice
    -- is still on, until the next landing (estimate: FCOM says "ice no
    -- longer detected"); >ANTI-ICE with anti-ice on above TAT 12°C and no ice
    -- detected; >ICE DETECTORS after 2 s with either failed or without power
    local det_ok = {inp.ac[1] and not inp.detector_failed[1], inp.ac[3] and not inp.detector_failed[2]}
    out.detector_on = det_ok[1] or det_ok[2]
    local detecting = not inp.on_ground and out.detector_on and inp.icing
    out.detecting = detecting
    if inp.on_ground then s.saw_ice = false elseif detecting then s.saw_ice = true end
    local anti_ice = inp.wai_on or inp.nai_on[1] or inp.nai_on[2] or inp.nai_on[3] or inp.nai_on[4]
    out.icing_alert = detecting
    out.no_icing_alert = s.saw_ice and not detecting and anti_ice
    out.anti_ice_alert = anti_ice and inp.tat_c > M.ANTI_ICE_TAT_C and not detecting
    for d = 1, 2 do
        if det_ok[d] then s.det_t[d] = 0 else s.det_t[d] = s.det_t[d] + dt end
        out.detector_status[d] = s.det_t[d] >= M.DETECTOR_STATUS_S
    end
    out.detectors_alert = s.det_t[1] >= M.DETECTOR_ALERT_S or s.det_t[2] >= M.DETECTOR_ALERT_S

    -- the wipers (FCOM p.628, p.633; ATA30_32_35_36 p.264-272): 28V DC
    for w = 1, 2 do
        out.wiper_speed[w] = inp.dc[M.WIPER_BUS[w]] and M.WIPER_SPEED[inp.wiper[w]] or 0
    end

    s.first = false
    return out
end

return M
