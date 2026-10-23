-- Run from the repository root with LuaJIT: luajit tests/antiice/antiice_model_test.lua
-- The ice and rain protection model (plugins/xtlua/scripts/B747.50.xt.antiice/B747.50.antiice_model.lua)
-- against FCOM 3.10-3.30 and ATA30_32_35_36 30-xx: the NAI valves and their
-- light and message, the WAI valves in the air only, the windshield heat
-- and its reset, the probe heat, the ice detectors and their messages, and
-- the wipers.
local T = dofile("tests/lib/check.lua")("antiice_model")
local M = dofile("plugins/xtlua/scripts/B747.50.xt.antiice/B747.50.antiice_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
-- engines running on the ground, power on
local function running()
    local s, inp = M.new(), M.inputs()
    for n = 1, 4 do inp.engine_running[n], inp.nai_psi[n] = true, 40 end
    return s, inp
end

-- NAI: the switch and bleed air open the valve; the VALVE light while it
-- disagrees with the switch; NAI VALVE n after 3.5 s with the engine running
-- (FCOM p.625, p.635; ATA30_32_35_36 p.206)
do
    local s, inp = running()
    local out = run(s, inp, 1)
    T.check(out.nai_valve[1] == 0 and not out.nai_light[1], "NAI off: valve closed, no light")
    inp.nai_on[1] = true
    out = run(s, inp, 0.3)
    T.check(out.nai_light[1] and out.nai_valve[1] > 0 and out.nai_valve[1] < 1, "NAI 1 ON: valve moving, VALVE light")
    out = run(s, inp, 1)
    T.check(out.nai_valve[1] == 1 and not out.nai_light[1], "NAI 1 ON: valve open, light out")
    -- no bleed air: the valve cannot open
    inp.nai_on[2], inp.nai_psi[2] = true, 0
    out = run(s, inp, 3)
    T.check(out.nai_valve[2] == 0 and out.nai_light[2], "NAI 2 ON without bleed air: closed, VALVE light")
    T.check(not out.nai_alert[2], "3 s: no NAI VALVE 2 yet")
    out = run(s, inp, 1)
    T.check(out.nai_alert[2], "3.5 s: NAI VALVE 2 (ATA30_32_35_36 p.206)")
    inp.engine_running[2] = false
    out = run(s, inp, 0.1)
    T.check(not out.nai_alert[2] and out.nai_light[2], "engine 2 stopped: no NAI VALVE 2, the light stays")
    -- a failure: closed and latched until the switch goes off
    inp.nai_psi[2], inp.engine_running[2], inp.nai_failed[1] = 40, true, true
    out = run(s, inp, 2)
    T.check(out.nai_valve[1] == 0 and out.nai_light[1], "NAI 1 failed: closed, VALVE light")
    inp.nai_failed[1] = false
    out = run(s, inp, 2)
    T.check(out.nai_valve[1] == 0, "the failure gone: still closed (latched)")
    inp.nai_on[1] = false
    run(s, inp, 0.5)
    inp.nai_on[1] = true
    out = run(s, inp, 2)
    T.check(out.nai_valve[1] == 1, "switch off and ON: open again")
    -- no DC: no command
    inp.dc[3], inp.nai_on[3] = false, true
    out = run(s, inp, 2)
    T.check(out.nai_valve[3] == 0, "NAI 3 without its DC bus: closed (estimate: the bus)")
end

-- WAI: in the air only, whatever the duct pressure; the VALVE light compares
-- the command; WAI VALVE after 5 s (FCOM p.625-626; LH36 p.120-126;
-- ATA30_32_35_36 p.184)
do
    local s, inp = running()
    inp.wai_on = true
    local out = run(s, inp, 5)
    T.check(out.wai_valve[1] == 0 and out.wai_valve[2] == 0, "WAI ON on the ground: inhibited")
    T.check(not out.wai_light, "on the ground: no VALVE light (estimate: the command is closed)")
    inp.on_ground = false
    out = run(s, inp, 1)
    T.check(out.wai_light and out.wai_valve[1] > 0 and out.wai_valve[1] < 1, "in the air: valves moving, VALVE light")
    out = run(s, inp, 2)
    T.check(out.wai_valve[1] == 1 and out.wai_valve[2] == 1 and not out.wai_light, "valves open within 3 s, light out")
    inp.wai_failed[2], inp.wai_on = true, false
    out = run(s, inp, 4)
    T.check(out.wai_valve[1] == 0 and out.wai_valve[2] == 1 and out.wai_light, "right valve stuck open: VALVE light")
    T.check(not out.wai_alert[2], "4 s: no WAI VALVE RIGHT yet")
    out = run(s, inp, 1.5)
    T.check(out.wai_alert[2] and not out.wai_alert[1], "5 s: WAI VALVE RIGHT")
    -- no AC bus 2: the motors stop where they are
    s, inp = running()
    inp.on_ground = false
    run(s, inp, 1)
    inp.wai_on, inp.ac[2] = true, false
    out = run(s, inp, 3)
    T.check(out.wai_valve[1] == 0 and out.wai_light, "WAI without AC bus 2: the valves do not move")
end

-- windshield heat: INOP and HEAT WINDOW without power, the switch off
-- included; a fault latches until off 10 s and ON (FCOM p.628, p.633, p.635)
do
    local s, inp = running()
    local out = run(s, inp, 1)
    T.check(out.window_inop[1] and out.window_alert[1], "WINDOW HEAT off: INOP, HEAT WINDOW L (power removed)")
    inp.window_on = {true, true}
    out = run(s, inp, 1)
    T.check(out.window_heat[1] and out.window_heat[2] and not out.window_inop[1] and not out.window_alert[2],
        "WINDOW HEAT ON: heated, no INOP")
    inp.window_failed[1] = true
    out = run(s, inp, 1)
    T.check(not out.window_heat[1] and out.window_inop[1] and out.window_alert[1], "fault: INOP, HEAT WINDOW L")
    inp.window_failed[1] = false
    out = run(s, inp, 1)
    T.check(out.window_inop[1], "the fault gone: latched")
    inp.window_on[1] = false
    run(s, inp, 5)
    inp.window_on[1] = true
    out = run(s, inp, 1)
    T.check(out.window_inop[1], "off 5 s and ON: still latched")
    inp.window_on[1] = false
    run(s, inp, 10.5)
    inp.window_on[1] = true
    out = run(s, inp, 1)
    T.check(out.window_heat[1] and not out.window_inop[1], "off 10 s and ON: reset (FCOM p.633)")
    inp.ac[2] = false
    out = run(s, inp, 1)
    T.check(out.window_inop[2] and not out.window_heat[2], "R windshield without its AC bus: INOP")
    T.check(out.side_window_heat, "side windows heated with any AC")
end

-- probe heat: pitot-static and AOA with any engine running, TAT in flight;
-- HEAT ... with a failure or no power while heated (FCOM p.634-635)
do
    local s, inp = M.new(), M.inputs()
    local out = run(s, inp, 1)
    T.check(not out.probe_heat[1] and not out.probe_alert[1], "engines off on the ground: no heat, no message")
    inp.engine_running[3] = true
    out = run(s, inp, 1)
    T.check(out.probe_heat[1] and out.probe_heat[5] and not out.probe_heat[7], "an engine running: pitot-static and AOA heat, not TAT")
    inp.on_ground = false
    out = run(s, inp, 1)
    T.check(out.probe_heat[7] and out.probe_heat[8], "in flight: TAT heat")
    inp.probe_failed[2], inp.probe_failed[7] = true, true
    out = run(s, inp, 1)
    T.check(out.probe_alert[2], "P/S F/O heater failed: HEAT P/S F/O")
    T.check(not out.probe_alert[7], "L TAT failed 1 s: not yet")
    out = run(s, inp, 15)
    T.check(out.probe_alert[7], "L TAT failed 15 s: HEAT L TAT (ATA30_32_35_36 p.228)")
    inp.ac[2] = false
    out = run(s, inp, 1)
    T.check(out.probe_alert[6], "R AOA without its AC bus: HEAT R AOA (estimate: the bus)")
end

-- ice detection: in flight; >ICING, >NO ICING with anti-ice still on,
-- >ANTI-ICE above TAT 12°C, >ICE DETECTORS (FCOM p.635; ATA30_32_35_36 p.164)
do
    local s, inp = running()
    inp.icing = true
    local out = run(s, inp, 1)
    T.check(not out.icing_alert and not out.detecting, "ice on the ground: not detected (flight only)")
    inp.on_ground = false
    out = run(s, inp, 1)
    T.check(out.icing_alert, "in flight: >ICING")
    inp.nai_on = {true, true, true, true}
    inp.icing = false
    out = run(s, inp, 1)
    T.check(not out.icing_alert and out.no_icing_alert, "ice gone, anti-ice on: >NO ICING")
    inp.nai_on = {false, false, false, false}
    out = run(s, inp, 1)
    T.check(not out.no_icing_alert, "anti-ice off: no >NO ICING (estimate)")
    inp.nai_on[1], inp.tat_c = true, 15
    out = run(s, inp, 1)
    T.check(out.anti_ice_alert, "anti-ice on, TAT 15: >ANTI-ICE")
    inp.icing = true
    out = run(s, inp, 1)
    T.check(not out.anti_ice_alert, "ice detected: no >ANTI-ICE")
    inp.on_ground = true
    out = run(s, inp, 1)
    inp.on_ground, inp.icing = false, false
    out = run(s, inp, 1)
    T.check(not out.no_icing_alert, "after a landing: no >NO ICING from the last flight")
    inp.detector_failed[2] = true
    out = run(s, inp, 1.5)
    T.check(not out.detectors_alert, "detector R failed 1.5 s: not yet")
    out = run(s, inp, 1)
    T.check(out.detectors_alert and not out.detector_status[2], "2 s: >ICE DETECTORS")
    out = run(s, inp, 10)
    T.check(out.detector_status[2] and not out.detector_status[1], "12 s: STATUS ICE DETECTOR R")
    T.check(out.detector_on, "the left detector still works")
end

-- the wipers: LO and HI at 50 and 100 % of X-Plane's speed, 28V DC
do
    local s, inp = running()
    inp.wiper = {1, 2}
    local out = run(s, inp, 0.1)
    T.check(out.wiper_speed[1] == 2 and out.wiper_speed[2] == 3, "LO 2, HI 3")
    inp.dc[1] = false
    out = run(s, inp, 0.1)
    T.equal(out.wiper_speed[1], 0, "L wiper without its DC bus: parked")
end

T.done()
