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

-- engines running: the CWT feeds all four through the open crossfeeds
engines_run(rt, 0.6)
frames(rt, 6)
for n = 0, 3 do T.equal(rt:get(HAS_FUEL, n), 1, "running: engine " .. (n + 1) .. " has fuel") end
T.equal(rt:get("laminar/B747/fuel/spar_vlv2_pos"), 1, "running: spar valve 2 open")
T.equal(rt:get("laminar/B747/fuel/engine1_status"), 2, "running: engine 1 fed through the manifold (synoptic)")
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

-- the fire switch closes the spar valve (ATA26_28 p.466)
rt:set("laminar/B747/fire/engine02/ext_switch/pos_arm", 1)
frames(rt, 6)
T.equal(rt:get("laminar/B747/fuel/spar_vlv2_pos"), 0, "fire switch 2: spar valve closed")
T.equal(rt:get(HAS_FUEL, 1), 0, "fire switch 2: no fuel to engine 2")
T.equal(rt:get("laminar/B747/fuel/engine2_status"), 0, "fire switch 2: no flow to engine 2 on the synoptic")

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

T.done()
