-- Run from the repository root with LuaJIT: luajit tests/engines/engine_start_module_test.lua
-- The engine start in the engine module as XTLua runs it (tests/lib/xtlua.lua):
-- the START, FUEL CONTROL, AUTOSTART and CON switches, the buses and X-Plane's
-- N2 and light-off in; the start valve commands, X-Plane's starters,
-- igniters and mixture, the engine fuel valves, the START switch release and
-- the EICAS slots out, through the glue (B747.40.xt.engine_start.lua). The
-- model's behaviour is tested in engine_start_model_test.lua; this checks
-- the wiring. A stand-in for the bleed air opens the start valve as
-- commanded and a stand-in X-Plane engine turns while the starter is held.
local T = dofile("tests/lib/check.lua")("engine_start_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engines.lua")
rt:set("sim/operation/prefs/startup_running", 0)
-- the aircraft configuration lets after_physics run (spool time, fuel-on indicator)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
rt:callout("flight_start")

local N2 = "sim/flightmodel/engine/ENGN_N2_"
local BURNING = "sim/flightmodel2/engines/engine_is_burning_fuel"
local CMD = "laminar/B747/engines/start_valve_cmd"
local VALVE = "laminar/B747/air/engine1/bleed_start_valve_pos"
for n = 0, 3 do rt:set("laminar/B747/electrical/bus/ac", n, 1) end
for _, bus in ipairs({"stby_main", "bat_main", "bat_apu"}) do rt:set("laminar/B747/electrical/bus/" .. bus, 1) end
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("laminar/B747/electrical/stby_ignit/sel_dial_pos", 1)    -- NORM
rt:set("laminar/B747/electrical/auto_ignit/sel_dial_pos", 1)    -- BOTH

local function starter_held()
    local held = false
    for _, c in ipairs(rt.command_log) do
        if c.name == "sim/starters/engage_starter_1" then held = (c.phase == "start") end
    end
    return held
end
local function released()
    for _, c in ipairs(rt.command_log) do
        if c.name == "laminar/B747/toggle_switch/engine_start1_off" then return true end
    end
    return false
end
-- one second of frames with the stand-ins
local function seconds(s)
    for _ = 1, math.floor(s * 30 + 0.5) do
        rt:frame(1 / 30)
        rt:set(VALVE, rt:get(CMD, 0))
        local n2 = rt:get(N2, 0)
        local fuel = rt:get("sim/cockpit2/engine/actuators/mixture_ratio", 0) > 0.5
        local ign = rt:get("sim/cockpit2/engine/actuators/igniter_on", 0) == 1
        if fuel and ign and n2 > 10 then rt:set(BURNING, 0, 1) end
        if not fuel then rt:set(BURNING, 0, 0) end
        if rt:get(BURNING, 0) == 1 then n2 = math.min(68, n2 + 1.0 / 30)
        elseif starter_held() then n2 = math.min(30, n2 + 0.85 / 30) end
        rt:set(N2, 0, n2)
    end
end

-- settle after the flight start
seconds(3)
T.equal(rt:get("sim/cockpit2/engine/actuators/auto_ignite_on", 0), 0, "X-Plane's auto-ignite off: the model decides")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 304), 1, "AUTOSTART OFF at the start: >AUTOSTART OFF")
local SPOOL = "sim/aircraft/engine/acf_spooltime_turbine"
T.equal(rt:get(SPOOL), 5, "no start: X-Plane spool time 5 s (the EEC thrust control's)")
-- the fuel-on indicator: CUTOFF, not with the fire switch pulled (ATA70_80 p.346)
local FUEL_ON = "laminar/B747/engines/fuel_on_indicator_status"
rt:set("laminar/B747/fire/engine02/ext_switch/pos_arm", 1)
seconds(0.2)
T.equal(rt:get(FUEL_ON, 0), 1, "CUTOFF: fuel-on indicator")
T.equal(rt:get(FUEL_ON, 1), 0, "CUTOFF with fire switch 2 pulled: no fuel-on indicator")
rt:set("laminar/B747/fire/engine02/ext_switch/pos_arm", 0)
-- (the FMC's step 9h3) the engines inoperative (N2 under 52 %) for the
-- FMC, the AFDS and the A/T
local INOP = "laminar/B747/engines/inop"
T.equal(rt:get(INOP, 0), 1, "not started: engine 1 inoperative")

-- autostart: AUTOSTART ON, START 1, FUEL CONTROL 1 RUN
rt:set("laminar/B747/button_switch/position", 45, 1)
rt:set("laminar/B747/toggle_switch/position", 16, 1)
seconds(1)
T.equal(rt:get(CMD, 0), 0, "autostart: START alone does not open the start valve")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 304), 0, "AUTOSTART ON: no >AUTOSTART OFF")
rt:set("laminar/B747/fuel/fuel_control/toggle_sw_pos", 0, 1)   -- (the fuel module animates it; not loaded here)
seconds(2)
T.equal(rt:get(CMD, 0), 1, "autostart: RUN opens the start valve")
T.check(starter_held(), "autostart: X-Plane's starter held")
T.equal(rt:get(SPOOL), 26, "starting on the ground: X-Plane spool time 26 s (ENG-35)")
T.equal(rt:get("sim/cockpit2/engine/actuators/mixture_ratio", 0), 0, "autostart: no fuel while motoring")
seconds(25)                                           -- past 20 % N2 (PW: engines/type 0)
T.equal(rt:get("sim/cockpit2/engine/actuators/mixture_ratio", 0), 1, "autostart: fuel on")
T.equal(rt:get("laminar/B747/engines/fuel_valve_pos", 0), 1, "autostart: engine fuel valve (the fuel glue reads it)")
seconds(40)
T.check(released(), "autostart: the START switch released at 50 % N2 (command logged)")
seconds(1)
T.check(not starter_held(), "autostart: starter let go after the cutout")
seconds(40)                                           -- the start ends at a settled idle
T.equal(rt:get("laminar/B747/CAS/caution_status", 61), 0, "no STARTER CUTOUT 1")
T.equal(rt:get("laminar/B747/CAS/caution_status", 19), 0, "no ENG 1 AUTOSTART")
T.equal(rt:get(SPOOL), 5, "start over: spool time back to 5 s")
T.equal(rt:get(FUEL_ON, 0), 0, "RUN: no fuel-on indicator")
T.equal(rt:get(INOP, 0), 0, "at idle: engine 1 not inoperative")
T.equal(rt:get(INOP, 1), 1, "engine 2 not started: inoperative")

-- a manual start motors at CUTOFF: spool time 26 s from the START switch (ENG-35)
rt:set("laminar/B747/button_switch/position", 45, 0)        -- AUTOSTART OFF
rt:set("laminar/B747/toggle_switch/position", 17, 1)         -- START 2
seconds(0.2)
T.equal(rt:get(CMD, 1), 1, "manual start: START 2 opens start valve 2")
T.equal(rt:get(SPOOL), 26, "manual motoring at CUTOFF: spool time 26 s")
rt:set("laminar/B747/toggle_switch/position", 17, 0)
seconds(0.2)
T.equal(rt:get(SPOOL), 5, "START 2 in again: spool time 5 s")
rt:set("laminar/B747/button_switch/position", 45, 1)

-- CON IGNITION ON: igniters and the memo
rt:set("laminar/B747/button_switch/position", 44, 1)
seconds(1)
T.equal(rt:get("sim/cockpit2/engine/actuators/igniter_on", 0), 1, "CON ON: X-Plane's igniter 1 on")
T.equal(rt:get("laminar/B747/CAS/memo_status", 8), 1, "CON ON: CON IGNITION ON memo")
rt:set("laminar/B747/button_switch/position", 44, 0)
seconds(1)
T.equal(rt:get("sim/cockpit2/engine/actuators/igniter_on", 0), 0, "CON OFF: igniter off")

-- in the air with FUEL CONTROL 2 CUTOFF: >ENG 2 SHUTDOWN; engine 1 at 40 %: ENG 1 FAIL
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(N2, 0, 40)
rt:set(BURNING, 0, 1)
seconds(0.2)
T.equal(rt:get("laminar/B747/CAS/caution_status", 24), 1, "air, CUTOFF 2: >ENG 2 SHUTDOWN")
T.equal(rt:get("laminar/B747/CAS/warning_status", 28), 1, "air, N2 40 % with RUN: ENG 1 FAIL (caution level)")

T.done()
