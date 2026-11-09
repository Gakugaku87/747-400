-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_module_test.lua
-- The fuel module as XTLua runs it (tests/lib/xtlua.lua): the switches, the
-- buses, air/ground and X-Plane's tanks and engines in; m_fuel, the engines'
-- fuel supply, the pump and valve datarefs, the synoptic status codes, the
-- overhead lights, the totaliser and the EICAS slots out, through the glue
-- (B747_fuel_system in B747.25.xt.fuel.lua). The model's behaviour itself is
-- tested in fuel_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("fuel_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local FUEL = "sim/flightmodel/weight/m_fuel"
local HAS_FUEL = "sim/flightmodel2/engines/has_fuel_flow_before_mixture"
local SWITCH = "laminar/B747/button_switch/position"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local PRESS = "laminar/B747/fuel/light/pump_press"
local SYN_PUMP, SYN_MAIN, SYN_SUCTION = "laminar/B747/fuel/synoptic/pump", "laminar/B747/fuel/synoptic/main_amber", "laminar/B747/fuel/synoptic/suction"
local RATIO = {0.3, 0.078, 0.22, 0.22, 0.078, 0.023, 0.023, 0.058}   -- both acfs, from index 0

-- powered on the ground, the tanks as given (X-Plane index 0-7)
local function aircraft(tanks, startup_running)
    local rt = xtlua.new()
    rt:load("plugins/xtlua/scripts/B747.25.xt.fuel/B747.25.xt.fuel.lua")
    rt:set("sim/aircraft/weight/acf_m_fuel_tot", 173069.12)
    for i, r in ipairs(RATIO) do rt:set("sim/aircraft/overflow/acf_tank_rat", i - 1, r) end
    for i, kg in ipairs(tanks) do rt:set(FUEL, i - 1, kg) end
    for n = 0, 3 do
        for _, bus in ipairs({"ac", "dc", "utility"}) do rt:set("laminar/B747/electrical/bus/" .. bus, n, 1) end
    end
    for _, bus in ipairs({"bat_main", "hot_bat_main", "gnd_svc", "bat_apu"}) do
        rt:set("laminar/B747/electrical/bus/" .. bus, 1)
    end
    for x = 48, 51 do rt:set(SWITCH, x, 1) end                      -- X FEED ON
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set("sim/operation/prefs/startup_running", startup_running or 0)
    rt:callout("flight_start")
    return rt
end
local function frames(rt, seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function total(rt)
    local kg = 0
    for i = 0, 7 do kg = kg + rt:get(FUEL, i) end
    return kg
end
local function engines_run(rt, ff)
    for n = 0, 3 do
        rt:set("laminar/B747/fuel/switch_target", n, 1)            -- FUEL CONTROL RUN
        rt:set("laminar/B747/engines/fuel_valve_pos", n, 1)
        rt:set("sim/flightmodel/engine/ENGN_running", n, 1)
        rt:set("sim/cockpit2/engine/indicators/fuel_flow_kg_sec", n, ff)
    end
end
local MAIN_SWITCHES = {56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67}

-- settling after the flight start: X-Plane's quantities are kept, then the
-- previous code's fixed loading above 100 t sends the rest to the refuelling
do
    local rt = aircraft({40000, 12000, 36000, 36000, 12000, 3900, 3900, 0})
    frames(rt, 1)
    T.near(total(rt), 143800, 1, "settling: X-Plane's quantities kept")
    frames(rt, 1.5)
    T.near(rt:get(FUEL, 2), 33793, 1, "initial loading: main 2 (the previous code's fixed loading)")
    T.equal(rt:get(FUEL, 0), 0, "initial loading: the CWT empty")
    T.near(rt:get("laminar/B747/fuel/refuel"), 143800 - 98572, 1, "initial loading: the rest to the refuelling, none lost")
    -- the refuelling (after 10 s, 10 kg per tank per frame) puts it back,
    -- mains and reserves first; what overflows a full tank is lost, as before
    frames(rt, 20)
    T.near(rt:get(FUEL, 1), 0.078 * 173069.12, 1, "refuelling: main 1 full at the acf's capacity")
    T.near(rt:get(FUEL, 2), 0.220 * 173069.12, 1, "refuelling: main 2 full")
    frames(rt, 140)
    T.check(rt:get("laminar/B747/fuel/refuel") <= 0, "refuelling: done")
    T.near(total(rt), 143800, 150, "refuelling: the total back")
end

-- below 100 t: preflight with the pump switches OFF (FCOM p.1465)
local rt = aircraft({20000, 11000, 25000, 25000, 11000, 3000, 3000, 0})
frames(rt, 3)
T.near(total(rt), 98000, 1, "below 100 t: the loading as given")
T.equal(rt:get(PRESS, 0), 1, "preflight: MAIN 1 FWD PRESS light")
T.equal(rt:get(PRESS, 7), 1, "preflight: MAIN 4 AFT PRESS light")
T.equal(rt:get(PRESS, 12), 0, "preflight: no CTR L PRESS light with the switch OFF")
T.equal(rt:get(ADVISORY, 165), 1, "preflight: FUEL PUMP 1 FWD")
T.equal(rt:get(ADVISORY, 153), 1, "preflight: >FUEL OVD CTR L (CWT 20 t, switch OFF)")
T.equal(rt:get(ADVISORY, 157), 1, "preflight: FUEL OVRD 2 FWD (switch OFF before tank to engine)")
T.equal(rt:get("laminar/B747/fuel/main1_tank/main_pump_fwd_on"), 0, "preflight: main 1 FWD pump off")
T.equal(rt:get("laminar/B747/fuel/gen/xfeed_vlv1_status"), 1, "preflight: crossfeed 1 open (synoptic)")
T.equal(rt:get("laminar/B747/fuel/engine1/xfeed_vlv_pos"), 1, "preflight: crossfeed 1 valve open")
T.equal(rt:get(SYN_PUMP, 0), 0, "preflight: MAIN 1 FWD white on the synoptic")
T.equal(rt:get(SYN_MAIN, 0), 0, "preflight: main 1 white on the synoptic")

-- before start: main, override and CTR pumps ON (NP p.119)
for _, x in ipairs(MAIN_SWITCHES) do rt:set(SWITCH, x, 1) end
rt:set(SWITCH, 52, 1)
rt:set(SWITCH, 53, 1)
frames(rt, 1)
T.equal(rt:get("laminar/B747/fuel/main1_tank/main_pump_fwd_on"), 1, "pumps ON: main 1 FWD pump runs")
T.equal(rt:get("laminar/B747/fuel/center_tank/ovrd_jett_pump_L_on"), 1, "pumps ON: CTR L pump runs")
T.equal(rt:get("laminar/B747/fuel/main2_tank/ovrd_jett_pump_fwd_on"), 0,
    "pumps ON: override 2 FWD held off by both CWT pumps (FCOM p.1467)")
T.equal(rt:get(PRESS, 0), 0, "pumps ON: MAIN 1 FWD PRESS light off")
T.equal(rt:get(ADVISORY, 165), 0, "pumps ON: no FUEL PUMP 1 FWD")
T.equal(rt:get(ADVISORY, 153), 0, "pumps ON: no >FUEL OVD CTR L")
T.equal(rt:get(SYN_PUMP, 0), 2, "pumps ON: MAIN 1 FWD green on the synoptic")
T.equal(rt:get(SYN_PUMP, 8), 1, "pumps ON: OVRD 2 FWD cyan on the synoptic (armed)")
T.equal(rt:get(SYN_PUMP, 12), 2, "pumps ON: CTR L green on the synoptic")

-- engines running: the CWT feeds all four through the open crossfeeds
engines_run(rt, 0.6)
frames(rt, 6)
for n = 0, 3 do T.equal(rt:get(HAS_FUEL, n), 1, "running: engine " .. (n + 1) .. " has fuel") end
T.equal(rt:get("laminar/B747/fuel/spar_vlv2_pos"), 1, "running: spar valve 2 open")
T.equal(rt:get("laminar/B747/fuel/engine1_status"), 2, "running: engine 1 fed through the manifold (synoptic)")
-- (2026-11-09) the manifold's flow from the model (fuel_model_test has its
-- cases: mains through open crossfeeds too)
T.equal(rt:get("laminar/B747/fuel/gen_XFmfld_status"), 1, "running: the crossfeed manifold's flow on the synoptic")
local ctr0, used0, all0 = rt:get(FUEL, 0), rt:get("laminar/B747/fuel/totaliser", 0), rt:get("laminar/B747/fuel/totaliser", 4)
frames(rt, 60)
T.near(ctr0 - rt:get(FUEL, 0), 4 * 0.6 * 60, 2, "running: the CWT gives 2.4 kg/s")
T.near(rt:get(FUEL, 1), 11000, 0.5, "running: main 1 unused")
T.near(rt:get("laminar/B747/fuel/totaliser", 0) - used0, 36, 0.5, "totaliser: engine 1")
T.near(rt:get("laminar/B747/fuel/totaliser", 4) - all0, 144, 1, "totaliser: FUEL USED, the four engines")
T.equal(rt:get(CAUTION, 32), 0, "running: no FUEL PRESS ENG 1")

-- the weight dialog: a tank changed outside is taken over, not written back
rt:set(FUEL, 4, 9000)
frames(rt, 1)
T.near(rt:get(FUEL, 4), 9000, 0.5, "outside change: main 4 at 9,000 kg kept")
T.equal(rt:get(SYN_MAIN, 0), 1, "main 1 2,000 kg above main 4: main 1 amber on the synoptic (imbalance)")
T.equal(rt:get(SYN_MAIN, 3), 1, "main 4 amber on the synoptic (imbalance)")
T.equal(rt:get(SYN_MAIN, 1), 0, "main 2 white on the synoptic")

-- suction feed: main 1 pumps OFF and crossfeed 1 closed (FCOM p.1455)
rt:set(SWITCH, 56, 0)
rt:set(SWITCH, 60, 0)
rt:set(SWITCH, 48, 0)
frames(rt, 1)
T.equal(rt:get("laminar/B747/fuel/light/xfeed_valve", 0), 1, "crossfeed 1 moving: VALVE light")
T.equal(rt:get("laminar/B747/fuel/gen/xfeed_vlv1_status"), 2, "crossfeed 1 closing (synoptic)")
frames(rt, 5)
T.equal(rt:get("laminar/B747/fuel/light/xfeed_valve", 0), 0, "crossfeed 1 closed: VALVE light off")
T.equal(rt:get(CAUTION, 32), 1, "suction feed: FUEL PRESS ENG 1")
T.equal(rt:get(HAS_FUEL, 0), 1, "suction feed: engine 1 still has fuel")
T.equal(rt:get("laminar/B747/fuel/engine1_status"), 1, "suction feed: engine 1 from its own tank (synoptic)")
T.equal(rt:get(ADVISORY, 165), 0, "suction feed: FUEL PUMP 1 FWD inhibited by FUEL PRESS ENG 1")
T.equal(rt:get(SYN_SUCTION, 0), 1, "suction feed: engine 1 amber on the synoptic")
T.equal(rt:get(SYN_SUCTION, 2), 0, "engine 3 not in suction feed")

-- the fire switch closes the spar valve (ATA26_28 p.466)
rt:set("laminar/B747/fire/engine02/ext_switch/pos_arm", 1)
frames(rt, 6)
T.equal(rt:get("laminar/B747/fuel/spar_vlv2_pos"), 0, "fire switch 2: spar valve closed")
T.equal(rt:get(HAS_FUEL, 1), 0, "fire switch 2: no fuel to engine 2")
T.equal(rt:get("laminar/B747/fuel/engine2_status"), 0, "fire switch 2: no flow to engine 2 on the synoptic")

-- (2026-11-09's audit) a NOZZLE switch ON with the selector OFF (no
-- jettison): its valve opens (FCOM p.1441) but the jettison synoptic's
-- pumps and manifold stay without flow (before, from the motors and the
-- nozzle valve: the CTR pumps' and the whole manifold's flow shown)
rt:set(SWITCH, 46, 1)
frames(rt, 6)
T.equal(rt:get("laminar/B747/fuel/jett_vlv_status"), 1, "NOZZLE L ON, selector OFF: its valve open")
T.equal(rt:get(SYN_PUMP, 12), 2, "... CTR L green (feeding the engines)")
T.equal(rt:get("laminar/B747/fuel/jett/OJctrL_status"), 0, "... no jettison: CTR L without the jettison's flow")
T.equal(rt:get("laminar/B747/fuel/jett/mfldL2_status"), 0, "... the jettison manifold without flow")
T.equal(rt:get("laminar/B747/fuel/jett/mXmfld_status"), 0, "... its cross manifold without flow")
rt:set(SWITCH, 46, 0)
frames(rt, 6)

-- jettison: selector A, both nozzles ON (FCOM p.1468)
rt:set("laminar/B747/fuel/fuel_jettison/sel_dial_pos", 1)
rt:set(SWITCH, 46, 1)
rt:set(SWITCH, 47, 1)
frames(rt, 1)
T.equal(rt:get("laminar/B747/fuel/light/nozzle_valve", 0), 1, "nozzle L moving: VALVE light")
frames(rt, 5)
T.equal(rt:get("laminar/B747/fuel/jett_vlv_status"), 1, "jettison: nozzle valves open (synoptic)")
T.check(rt:get("laminar/B747/fuel/jettison_time") > 0, "jettison: time shown")
T.equal(rt:get(ADVISORY, 235), 1, "jettison: >JETT NOZ ON")
T.equal(rt:get("laminar/B747/fuel/center_tank/jett_vlv_L_pos"), 1, "jettison: CWT jettison valve open")
T.equal(rt:get("laminar/B747/fuel/light/nozzle_valve", 0), 0, "nozzle L open: VALVE light off")
T.equal(rt:get(SYN_PUMP, 12), 5, "jettison: CTR L magenta with flow on the synoptic")
T.equal(rt:get("laminar/B747/fuel/jett/OJctrL_status"), 1, "jettison: CTR L in the jettison's flow (the jettison synoptic)")
T.equal(rt:get("laminar/B747/fuel/jett/mXmfld_status"), 1, "jettison: its cross manifold with flow")
T.equal(rt:get("laminar/B747/fuel/fuel_to_remain/state"), 0, "jettison: fuel to remain magenta")

-- the APU: fuel valve open, main 2 AFT runs on the ground service bus (FCOM p.1465)
rt:set("sim/cockpit2/electrical/APU_starter_switch", 2)
frames(rt, 6)
T.equal(rt:get("laminar/B747/fuel/main2_tank/apu_vlv_pos"), 1, "APU: fuel valve open")
T.equal(rt:get("laminar/B747/fuel/main2_tank/apu_dc_pump_on"), 0, "APU: no DC pump while main 2 AFT runs")
T.equal(rt:get(ADVISORY, 15), 0, "APU: no APU FUEL")

-- a replay: X-Plane's quantities are taken, nothing is written
rt:set("sim/time/is_in_replay", 1)
rt:set(FUEL, 3, 12345)
frames(rt, 1)
T.equal(rt:get(FUEL, 3), 12345, "replay: X-Plane's quantity kept")
rt:set("sim/time/is_in_replay", 0)

-- engines running at the start (air start): the engines keep their fuel
-- while the fuel system settles, whatever the switches
do
    local rt2 = aircraft({0, 9000, 20000, 20000, 9000, 3000, 3000, 0}, 1)
    for n = 0, 3 do rt2:set("sim/flightmodel/engine/ENGN_running", n, 1) end
    frames(rt2, 0.5)
    for n = 0, 3 do T.equal(rt2:get(HAS_FUEL, n), 1, "air start: engine " .. (n + 1) .. " has fuel while settling") end
    T.equal(rt2:get(CAUTION, 32), 0, "air start: no message while settling")
    T.equal(rt2:get("laminar/B747/fuel/fuel_control/toggle_sw_pos", 0), 1, "air start: FUEL CONTROL RUN")
end

-- (2026-11-02) the settling in X-Plane's time: XTLua's frames run on while
-- X-Plane still loads the flight (its clock still), and X-Plane's own fuel
-- system feeds the engines until 2 s of X-Plane's time, then this module's
-- (the override: set at the load before, the engines of an engines-running
-- start had no fuel at its start and flamed out)
do
    local OVERRIDE = "sim/operation/override/override_fuel_system"
    local rt4 = aircraft({0, 9000, 20000, 20000, 9000, 3000, 3000, 0}, 1)
    engines_run(rt4, 1)
    rt4:callout("aircraft_load")                -- as XTLua: the load, then the flight's start
    rt4:callout("flight_start")
    local t0 = rt4.time
    for _ = 1, 90 do rt4.time = t0 rt4:frame(1 / 30) end
    T.equal(rt4:get(OVERRIDE), 0, "3 s of XTLua's frames with X-Plane loading (its clock still): X-Plane's own fuel system")
    frames(rt4, 1.5)
    T.equal(rt4:get(OVERRIDE), 0, "1.5 s of X-Plane's time: still settling")
    frames(rt4, 0.7)
    T.equal(rt4:get(OVERRIDE), 1, "2 s of X-Plane's time: this module's (the override)")
    for n = 0, 3 do T.equal(rt4:get(HAS_FUEL, n), 1, "then engine " .. (n + 1) .. " fed by the module") end
    rt4:callout("flight_start")
    T.equal(rt4:get(OVERRIDE), 0, "a new flight: X-Plane's own again while it settles")
end

-- the FUEL CONTROL switches bring up the secondary engine display only when
-- moved to CUTOFF in flight (FCOM p.843, p.872; ENG-23)
do
    local rt3 = aircraft({20000, 9000, 20000, 20000, 9000, 3000, 3000, 0}, 1)
    local SYN = "laminar/B747/dsp/synoptic_display"
    local CONTROL = "laminar/B747/fuel/fuel_control_1/toggle_switch"
    frames(rt3, 0.5)
    rt3:set(SYN, 0)
    rt3:set("laminar/B747/gear/air_ground/pri_air", 0)
    rt3:command(CONTROL)                                    -- RUN to CUTOFF on the ground
    frames(rt3, 0.5)
    T.equal(rt3:get("laminar/B747/fuel/switch_target", 0), 0, "FUEL CONTROL 1 to CUTOFF")
    T.equal(rt3:get(SYN), 0, "on the ground: no secondary engine display")
    rt3:set("laminar/B747/gear/air_ground/pri_air", 1)
    rt3:command(CONTROL)                                    -- CUTOFF to RUN in flight
    frames(rt3, 0.5)
    T.equal(rt3:get(SYN), 0, "in flight, to RUN: no secondary engine display")
    rt3:command(CONTROL)                                    -- RUN to CUTOFF in flight
    frames(rt3, 0.5)
    T.equal(rt3:get(SYN), 1, "in flight, to CUTOFF: the secondary engine display")
end

-- the weights in pounds (simconfig): the fuel to remain in pounds x 1000 on
-- the primary EICAS, the synoptic's low main tank at 2,000 lb (FCOM p.1448, 570)
do
    local rt5 = aircraft({20000, 905, 25000, 25000, 905, 3000, 3000, 0})
    rt5:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"LBS","kgs_to_lbs":2.20462,"auto_fuel_mgmt":"NO"}}')
    rt5:set("laminar/B747/newsimconfig", 1)
    frames(rt5, 3)
    T.near(rt5:get("laminar/B747/fuel/fuel_to_remain/display"), rt5:get("laminar/B747/fuel/fuel_to_remain/rheostat") * 2.20462,
        0.001, "LBS: fuel to remain in pounds x 1000")
    T.equal(rt5:get(SYN_MAIN, 0), 1, "LBS: main 1 at 905 kg amber on the synoptic (under 2,000 lb)")
    rt5:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"auto_fuel_mgmt":"NO"}}')
    rt5:set("laminar/B747/newsimconfig", 1)
    frames(rt5, 1)
    T.near(rt5:get("laminar/B747/fuel/fuel_to_remain/display"), rt5:get("laminar/B747/fuel/fuel_to_remain/rheostat"),
        0.001, "KGS: fuel to remain in kilograms x 1000")
    T.equal(rt5:get(SYN_MAIN, 0), 0, "KGS: main 1 at 905 kg white on the synoptic (900 kg)")
end

-- (2026-11-04) the failures through their datarefs (notes/ATA-28.md §11):
-- pump 1 FWD (index 0 of the model's PUMPS) with its switch ON: the PRESS
-- light; FJCC A: >FUEL JETT A (advisory 151); the temperature sensor:
-- FUEL TEMP SYS (173); X FEED 1 stuck (valve index 0) with its switch OFF:
-- still open
do
    local rt6 = aircraft({0, 10000, 20000, 20000, 10000, 0, 0, 0})
    for _, x in ipairs(MAIN_SWITCHES) do rt6:set(SWITCH, x, 1) end
    frames(rt6, 3)
    T.equal(rt6:get(PRESS, 0), 0, "(main 1 FWD ON: no PRESS light)")
    local FAIL = "laminar/B747/fuel/fail/"
    rt6:set(FAIL .. "pump", 0, 1)
    rt6:set(FAIL .. "fjcc", 0, 1)
    rt6:set(FAIL .. "temp", 1)
    rt6:set(FAIL .. "valve", 0, 1)
    rt6:set(SWITCH, 48, 0)                                          -- X FEED 1 OFF
    frames(rt6, 2)
    T.equal(rt6:get(PRESS, 0), 1, "pump 1 FWD failed: its PRESS light")
    T.equal(rt6:get(ADVISORY, 151), 1, "FJCC A failed: >FUEL JETT A")
    T.equal(rt6:get(ADVISORY, 152), 0, "no >FUEL JETT B")
    T.equal(rt6:get(ADVISORY, 173), 1, "the temperature sensor: FUEL TEMP SYS")
    T.equal(rt6:get("laminar/B747/fuel/light/xfeed_valve", 0), 1, "X FEED 1 stuck open with its switch OFF: its VALVE light")
end

-- (2026-11-06) the burn on X-Plane's clock, not on XTLua's frames. XTLua's
-- SIM_PERIOD summed to about 94.5 % of the time flown (the perf kit: the
-- tanks went down 5.5 % less than the fuel flow), and it neither stops in a
-- pause nor runs faster with time acceleration; X-Plane's
-- total_running_time_sec does both (checked in X-Plane on 11-06)
do
    local rt7 = aircraft({20000, 11000, 25000, 25000, 11000, 3000, 3000, 0})
    for _, x in ipairs(MAIN_SWITCHES) do rt7:set(SWITCH, x, 1) end
    rt7:set(SWITCH, 52, 1)
    rt7:set(SWITCH, 53, 1)
    frames(rt7, 3)
    engines_run(rt7, 1)
    frames(rt7, 2)
    -- n of XTLua's frames (SIM_PERIOD 1/30 each), X-Plane's clock moving by
    -- clock a frame (frame() adds 1/30 to it)
    local function step(n, clock)
        for _ = 1, n do
            rt7.time = rt7.time + clock - 1 / 30
            rt7:frame(1 / 30)
        end
    end
    local function used() return rt7:get("laminar/B747/fuel/totaliser", 4) end
    local function ctr() return rt7:get(FUEL, 0) end
    local u0, c0 = used(), ctr()
    step(150, 2 / 30)       -- XTLua on every other frame: 5 s of SIM_PERIOD, 10 s of X-Plane's
    T.near(used() - u0, 40, 0.5, "frames missed: FUEL USED over X-Plane's 10 s (before: 20 kg over SIM_PERIOD's 5 s)")
    T.near(c0 - ctr(), 40, 1, "frames missed: the CWT down by the same")
    u0, c0 = used(), ctr()
    step(90, 0)             -- paused: X-Plane's clock still
    T.near(used() - u0, 0, 0.01, "paused: no burn (before: 12 kg)")
    T.near(c0 - ctr(), 0, 0.01, "paused: the CWT the same")
    u0, c0 = used(), ctr()
    step(75, 4 / 30)        -- 4 x time acceleration: 10 s of X-Plane's time
    T.near(used() - u0, 40, 0.5, "4 x: FUEL USED over X-Plane's 10 s (before: 10 kg)")
    T.near(c0 - ctr(), 40, 1, "4 x: the CWT down by the same")
end

-- (2026-11-09's audit) the override/jettison pumps' flow bars with
-- pressure: main 2 under its standpipe, OVRD 2 run without pressure:
-- amber on the synoptic and no flow bar (before, from the motor: the flow
-- bar over the amber pump); main 3 above it: its flow bar
do
    local rtO = aircraft({0, 11000, 2500, 25000, 11000, 0, 0, 0})
    for _, x in ipairs(MAIN_SWITCHES) do rtO:set(SWITCH, x, 1) end
    frames(rtO, 3)
    local s8, s10 = rtO:get(SYN_PUMP, 8), rtO:get(SYN_PUMP, 10)
    T.equal(s8, 3, "main 2 at 2,500 kg: OVRD 2 FWD amber (run, pressure low): " .. tostring(s8))
    T.equal(rtO:get("laminar/B747/fuel/oj_pump2_status"), 0, "... no OVRD 2 flow bar")
    T.check(s10 == 2 and rtO:get("laminar/B747/fuel/oj_pump3_status") == 1,
        "main 3 at 25 t: OVRD 3 FWD green and its flow bar: " .. tostring(s10) .. "/" .. tostring(rtO:get("laminar/B747/fuel/oj_pump3_status")))
end

-- (2026-11-09) the fuel temperature's display (FCOM p.1445: degrees
-- Celsius): whole degrees in the dataref, the panel's sign from it: a value
-- rounding to 0 without one (before, -0.35 showed "-0c": the user's
-- EDDF-OMDB flight); FUEL TEMP LOW's -37 from the kept value
do
    for _, c in ipairs({{-0.35, 0}, {-0.6, -1}, {12.4, 12}, {-37.2, -37}}) do
        local rtT = aircraft({20000, 11000, 25000, 25000, 11000, 3000, 3000, 0})
        rtT:set("sim/cockpit2/temperature/outside_air_LE_temp_degc", c[1])
        frames(rtT, 2)
        T.equal(rtT:get("laminar/B747/fuel/temperature"), c[2], string.format("fuel temperature %.2f C shown as %d", c[1], c[2]))
    end
end

T.done()
