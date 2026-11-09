-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_auto_module_test.lua
-- The sim's option "Auto fuel management" (2026-11-09 the user; notes/
-- ATA-28.md §13) in the fuel module as XTLua runs it, with the manipulators
-- module (the switches' commands and positions): the FMS bridge's option
-- read (a frame late, as XTLua reads another plugin's dataref), the
-- model's messages, and the switches pushed through their own commands,
-- which X-Plane hands to the manipulators' handlers (here the test does).
-- In cruise at 1 kg/s an engine, from 2,000 kg in the CWT, 600 kg in the
-- stabilizer tank and main 2 and 3 300 kg over 1 and 4:
-- FUEL PMP STB, both STAB ON; the tank empty, FUEL PRES STB, both OFF;
-- FUEL LOW CTR at 1,300 kg, both CTR OFF; FUEL TANK/ENG, the overrides 2
-- and 3 and crossfeeds 1 and 4 OFF (FCOM p.133-136). The behaviour itself
-- is tested in fuel_auto_model_test.lua.
local T = dofile("tests/lib/check.lua")("fuel_auto_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local OPT = "laminar/B747/options/auto_fuel_mgmt"
local FUEL = "sim/flightmodel/weight/m_fuel"
local SWITCH = "laminar/B747/button_switch/position"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local RATIO = {0.3, 0.078, 0.22, 0.22, 0.078, 0.023, 0.023, 0.058}   -- both acfs, from index 0
local rt = xtlua.new{types = {[OPT] = "number"}, lagged = {OPT}}
rt:load("plugins/xtlua/scripts/B747.25.xt.fuel/B747.25.xt.fuel.lua")
rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
rt:set("sim/aircraft/weight/acf_m_fuel_tot", 173069.12)
for i, r in ipairs(RATIO) do rt:set("sim/aircraft/overflow/acf_tank_rat", i - 1, r) end
for i, kg in ipairs({2000, 10000, 10300, 10300, 10000, 0, 0, 600}) do rt:set(FUEL, i - 1, kg) end
for n = 0, 3 do
    for _, bus in ipairs({"ac", "dc", "utility"}) do rt:set("laminar/B747/electrical/bus/" .. bus, n, 1) end
end
for _, bus in ipairs({"bat_main", "hot_bat_main", "gnd_svc", "bat_apu"}) do
    rt:set("laminar/B747/electrical/bus/" .. bus, 1)
end
-- in the air with the engines running: the manipulators' engines running
-- start sets the fuel switches (main, override, CTR and STAB pumps,
-- crossfeeds 1 and 4 ON); the cruise's pitch, the flap lever UP
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/position/theta", 2.5)
rt:set("laminar/B747/cablecontrols/flap_ratio", 0)
for n = 0, 3 do
    rt:set("laminar/B747/engines/fuel_valve_pos", n, 1)
    rt:set("sim/flightmodel/engine/ENGN_running", n, 1)
    rt:set("sim/cockpit2/engine/indicators/fuel_flow_kg_sec", n, 1.0)
end
rt:callout("flight_start")

-- X-Plane runs a command's handlers (the manipulators': begin, then end);
-- here every "once" a module sends, each frame. The fuel module's pushes
-- are noted
local DT = 0.1
local seen, pushed = 0, {}
local function frames(seconds)
    for _ = 1, math.floor(seconds / DT + 0.5) do
        rt:frame(DT)
        while seen < #rt.command_log do
            seen = seen + 1
            local c = rt.command_log[seen]
            if c.phase == "once" and rt.commands[c.name] then
                rt:command(c.name)
                if c.module == "B747.25.xt.fuel.lua" then
                    pushed[#pushed + 1] = c.name:match("button_switch/fuel_(.*)$") or c.name
                end
            end
        end
    end
end
local function sw(i) return rt:get(SWITCH, i) > 0.5 end
local function push(name) rt:command("laminar/B747/button_switch/fuel_" .. name) end
local function names(from)
    local out = {}
    for i = from or 1, #pushed do out[#out + 1] = pushed[i] end
    return table.concat(out, ",")
end

frames(3)
T.check(sw(52) and sw(53) and sw(54) and sw(55), "the engines running start in the air: CTR and STAB ON")
T.check(sw(48) and sw(51) and sw(64) and sw(67), "crossfeeds 1 and 4 and the overrides ON")
-- the crew's: crossfeeds 2 and 3 ON, the STAB pumps OFF (before the cruise's
-- FUEL PMP STB, as after the before start procedure: FCOM p.119)
if not sw(49) then push("xfeed_vlv_2") end
if not sw(50) then push("xfeed_vlv_3") end
push("stab_tnk_pump_L")
push("stab_tnk_pump_R")
frames(1)
T.check(sw(49) and sw(50) and not sw(54) and not sw(55), "crossfeeds 2 and 3 ON, STAB OFF")
T.equal(rt:get(ADVISORY, 159), 1, ">FUEL PMP STB L (600 kg in cruise, switch OFF)")

-- the option off: nothing
frames(30)
T.equal(#pushed, 0, "the option off: no switch pushed")
T.check(not sw(54), "STAB L still OFF")

-- on: FUEL PMP STB, both STAB pumps ON after 5 s
rt:set(OPT, 1)
frames(5.5)
T.equal(names(), "stab_tnk_pump_L", "the option on: STAB L at the message's 5 s")
frames(2)
T.equal(names(), "stab_tnk_pump_L,stab_tnk_pump_R", "then STAB R")
T.check(sw(54) and sw(55), "both STAB pumps ON (the switches)")
T.equal(rt:get("laminar/B747/fuel/stab_tank/xfr_jett_pump_L_on"), 1, "the STAB L pump runs")
T.equal(rt:get(ADVISORY, 159), 0, "no >FUEL PMP STB L")
-- the stabilizer tank into the CWT (4.5 t/h a pump), empty in about 4 min
frames(250)
T.equal(rt:get(FUEL, 7), 0, "the stabilizer tank empty")
frames(10)
T.equal(names(3), "stab_tnk_pump_L,stab_tnk_pump_R", "FUEL PRES STB: both STAB pumps OFF")
T.check(not sw(54) and not sw(55), "both STAB OFF")
T.equal(rt:get(ADVISORY, 67), 0, "no FUEL PRES STB L left")

-- the CWT down to 1,300 kg in cruise: FUEL LOW CTR, both CTR OFF
local function until_pushes(n, limit)
    local t = 0
    while #pushed < n and t < limit do frames(1) t = t + 1 end
end
until_pushes(6, 200)
T.equal(names(5), "ctr_wing_tnk_pump_L,ctr_wing_tnk_pump_R", "FUEL LOW CTR: both CTR pumps OFF")
T.check(rt:get(FUEL, 0) <= 1300 and rt:get(FUEL, 0) > 1250, "at the cruise's 1,300 kg: " .. rt:get(FUEL, 0))
frames(2)
T.check(not sw(52) and not sw(53), "both CTR OFF")
T.equal(rt:get("laminar/B747/fuel/main2_tank/ovrd_jett_pump_fwd_on"), 1, "override 2 FWD runs (both CTR switches OFF: FCOM p.1467)")
T.equal(rt:get("laminar/B747/CAS/caution_status", 69), 0, "no FUEL PRESS CTR L")

-- main 2 and 3 down to main 1 and 4: FUEL TANK/ENG, the overrides 2 and 3
-- and crossfeeds 1 and 4 OFF
until_pushes(12, 300)
T.equal(names(7), "overd_pump_fwd_2,overd_pump_fwd_3,overd_pump_aft_2,overd_pump_aft_3,xfeed_vlv_1,xfeed_vlv_4",
    "FUEL TANK/ENG: the overrides 2 and 3, then crossfeeds 1 and 4 OFF (FCOM p.134)")
frames(6)
T.check(not (sw(64) or sw(65) or sw(66) or sw(67) or sw(48) or sw(51)), "the six switches OFF")
T.equal(rt:get(ADVISORY, 171), 0, "no >FUEL TANK/ENG (crossfeeds 1 and 4 closed)")
T.equal(rt:get("laminar/B747/fuel/engine1_status"), 1, "engine 1 from main 1 (the synoptic)")
local m1 = rt:get(FUEL, 1)
frames(10)
T.near(m1 - rt:get(FUEL, 1), 10, 0.5, "main 1 feeds engine 1 (1 kg/s)")

-- the pilot opens crossfeed 1 (balancing, FCOM SP.12.1): left alone
push("xfeed_vlv_1")
frames(30)
T.check(sw(48), "the pilot's crossfeed 1 stays ON")
T.equal(#pushed, 12, "nothing pushed")
T.equal(rt:get(ADVISORY, 171), 1, ">FUEL TANK/ENG shown again (crossfeed 1 open): the pilot's")

-- the option off on the CDU or the menu, the flight goes on: nothing
rt:set(OPT, 0)
push("ctr_wing_tnk_pump_L")
frames(30)
T.equal(#pushed, 12, "the option off: nothing")

T.done()
