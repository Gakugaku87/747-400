-- Run from the repository root with LuaJIT: luajit tests/lighting/lighting_module_test.lua
-- The lighting module as XTLua runs it (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("lighting_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:callout("flight_start")
rt:frame(1 / 30)

-- the generic light 63 powers the display brightness; X-Plane sets it back to
-- 0 when a new flight starts without reloading the aircraft
local LIGHT_POWER = "sim/cockpit2/switches/generic_lights_switch"
T.equal(rt:get(LIGHT_POWER, 63), 1, "flight start: generic light 63 on")
rt:set(LIGHT_POWER, 63, 0)
rt:frame(1 / 30)
T.equal(rt:get(LIGHT_POWER, 63), 1, "new flight without reload: generic light 63 back on")

-- the fuel panel lights come from the fuel model (laminar/B747/fuel/light/*):
-- each to its annunciator (brightness 0.8 with IND LTS BRT and bus power)
rt:set("sim/flightmodel2/lights/generic_lights_brightness_ratio", 63, 1)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
local ANNUN = "laminar/B747/annunciator/brightness_ratio"
local PRESS = "laminar/B747/fuel/light/pump_press"
local function only(name, i)
    for k = 0, 15 do rt:set(PRESS, k, 0) end
    for k = 0, 3 do rt:set("laminar/B747/fuel/light/xfeed_valve", k, 0) end
    for k = 0, 1 do rt:set("laminar/B747/fuel/light/nozzle_valve", k, 0) end
    rt:set(name, i, 1)
    rt:frame(1 / 30)
end
-- light index of the model (B747_fuel_model.PUMPS order) -> annunciator
local PRESS_ANNUN = {[0] = 48, 52, 49, 53, 50, 54, 51, 55, 56, 58, 57, 59, 44, 45, 46, 47}
for i = 0, 15 do
    only(PRESS, i)
    T.near(rt:get(ANNUN, PRESS_ANNUN[i]), 0.8, 0.01, "fuel PRESS light " .. i .. " -> annunciator " .. PRESS_ANNUN[i])
    T.near(rt:get(ANNUN, 40), 0, 0.01, "fuel PRESS light " .. i .. ": X FEED 1 VALVE off")
end
only("laminar/B747/fuel/light/xfeed_valve", 2)
T.near(rt:get(ANNUN, 42), 0.8, 0.01, "X FEED 3 VALVE light -> annunciator 42")
only("laminar/B747/fuel/light/nozzle_valve", 1)
T.near(rt:get(ANNUN, 39), 0.8, 0.01, "NOZZLE R VALVE light -> annunciator 39")
T.near(rt:get(ANNUN, 38), 0, 0.01, "NOZZLE L VALVE light off")

-- the anti-ice lights come from the anti-ice model (laminar/B747/antiice/light/*)
local ICE = "laminar/B747/antiice/light/"
local function ice_only(name, i)
    for k = 0, 3 do rt:set(ICE .. "nai_valve", k, 0) end
    rt:set(ICE .. "wai_valve", 0)
    for k = 0, 1 do rt:set(ICE .. "window_inop", k, 0) end
    if i then rt:set(ICE .. name, i, 1) else rt:set(ICE .. name, 1) end
    rt:frame(1 / 30)
end
for i = 0, 3 do
    ice_only("nai_valve", i)
    T.near(rt:get(ANNUN, 60 + i), 0.8, 0.01, "NAI " .. (i + 1) .. " VALVE light -> annunciator " .. (60 + i))
    T.near(rt:get(ANNUN, 64), 0, 0.01, "NAI " .. (i + 1) .. " VALVE light: WAI VALVE off")
end
ice_only("wai_valve")
T.near(rt:get(ANNUN, 64), 0.8, 0.01, "WAI VALVE light -> annunciator 64")
ice_only("window_inop", 0)
T.near(rt:get(ANNUN, 65), 0.8, 0.01, "WINDOW HEAT INOP L -> annunciator 65")
T.near(rt:get(ANNUN, 66), 0, 0.01, "WINDOW HEAT INOP R off")
ice_only("window_inop", 1)
T.near(rt:get(ANNUN, 66), 0.8, 0.01, "WINDOW HEAT INOP R -> annunciator 66")
T.near(rt:get(ANNUN, 60), 0, 0.01, "WINDOW HEAT INOP R: NAI 1 VALVE off")


-- the flight control shutoff valves' VALVE CLOSED lights (4-1 step 4): lit
-- while the valve is not fully open (the hydraulics module moves them);
-- WING 1-4 -> annunciators 80-83, TAIL 1-4 -> 84-87 (always out before)
local HP = "laminar/B747/flt_ctrls/hyd_power/"
local function valve_only(group, i, travel)
    for k = 0, 3 do
        rt:set(HP .. "wing_valve_shut", k, 0)
        rt:set(HP .. "tail_valve_shut", k, 0)
    end
    if group then rt:set(HP .. group .. "_valve_shut", i, travel) end
    rt:frame(1 / 30)
end
valve_only()
for i = 80, 87 do T.near(rt:get(ANNUN, i), 0, 0.01, "valves open: VALVE CLOSED light " .. i .. " out") end
valve_only("wing", 0, 0.3)
T.near(rt:get(ANNUN, 80), 0.8, 0.01, "WING 1 valve on its way: VALVE CLOSED (not fully open)")
T.near(rt:get(ANNUN, 81), 0, 0.01, "WING 2 open: out")
valve_only("tail", 3, 1)
T.near(rt:get(ANNUN, 87), 0.8, 0.01, "TAIL 4 valve shut -> annunciator 87")
T.near(rt:get(ANNUN, 83), 0, 0.01, "WING 4 open: out")
valve_only()
-- the MCP's HDG HOLD light (6-3 step 1b): HDG HOLD or ATT in the FMA's roll
-- (ATA22 p.266: ATT lights it too), not HDG SEL or LNAV (the old one went by
-- X-Plane's heading hold)
local ROLL = "laminar/B747/autopilot/FMA/active_roll_mode"
for _, c in ipairs({{7, true, "HDG HOLD"}, {5, true, "ATT"}, {6, false, "HDG SEL"}, {2, false, "LNAV"}}) do
    rt:set(ROLL, c[1])
    rt:frame(1 / 30)
    T.check((rt:get(ANNUN, 262) > 0.01) == c[2], "the HDG HOLD light with " .. c[3] .. (c[2] and ": on" or ": out"))
end
rt:set(ROLL, 0)
rt:frame(1 / 30)
-- the MCP's pitch lights (6-3 step 1c; FCOM p.645-650): V/S, ALT HOLD and
-- FLCH their mode active, VNAV armed or active. VNAV's arm leaves the
-- active mode's light (the old lights put V/S and ALT HOLD out), VNAV
-- engaged puts them out (the old VNAV sets the old law's flags for its
-- sub-modes), the old G/S too
local APS = "laminar/B747/autopilot/"
local function pitch_lights(vs, alt, fma, vnav, gs)
    rt:set(APS .. "vvi_status", vs)
    rt:set(APS .. "altitude_hold_status", alt)
    rt:set(APS .. "FMA/active_pitch_mode", fma)
    rt:set(APS .. "vnav_state", vnav)
    rt:set(APS .. "glideslope_status", gs or 0)
    rt:frame(1 / 30)
    local function on(i) return rt:get(ANNUN, i) > 0.01 end
    return {vs = on(263), alt = on(264), flch = on(261), vnav = on(260)}
end
local l = pitch_lights(2, 0, 7, 1)
T.check(l.vs and not l.alt and l.vnav, "V/S with VNAV armed: the V/S and VNAV lights (the old V/S light went out)")
l = pitch_lights(0, 2, 9, 1)
T.check(l.alt and not l.vs and l.vnav, "ALT with VNAV armed: ALT HOLD and VNAV (the old ALT HOLD light went out)")
l = pitch_lights(0, 0, 8, 1)
T.check(l.flch and l.vnav, "FLCH SPD with VNAV armed: FLCH and VNAV")
l = pitch_lights(2, 0, 6, 2)
T.check(not l.vs and not l.alt and not l.flch and l.vnav, "VNAV PTH (the old VNAV's V/S flag): VNAV only")
l = pitch_lights(0, 2, 5, 3)
T.check(not l.alt and l.vnav, "VNAV ALT (its ALT flag): VNAV only")
l = pitch_lights(0, 2, 2, 0, 2)
T.check(not l.alt and not l.vs and not l.vnav, "the old G/S captured (a stale ALT flag): out")
l = pitch_lights(0, 0, 0, 0)
T.check(not l.vs and not l.alt and not l.flch and not l.vnav, "no pitch mode: all out")

-- (7-2b) the exterior lights by the light model (notes/ATA-33.md §12): the
-- switches (position 0 on; the beacon's LWR 1 and BOTH -1), the AC buses,
-- the ground service bus, the PSEU's ground and the gear lever
local SW = "laminar/B747/toggle_switch/position"
local BUS = "laminar/B747/electrical/bus/"
local PSEU_GND = "laminar/B747/gear/air_ground/pri_gnd"
local LEVER = "laminar/B747/actuator/gear_handle"
local LAND = "sim/cockpit2/switches/landing_lights_switch"
local GEN = "sim/cockpit2/switches/generic_lights_switch"
local TAXI = "sim/cockpit2/switches/taxi_light_on"
local NAV = "sim/cockpit2/switches/navigation_lights_on"
local function power(ac, gsb)
    for i = 0, 3 do rt:set(BUS .. "ac", i, ac and 1 or 0) end
    rt:set(BUS .. "gnd_svc", gsb and 1 or 0)
end
-- positions [1]-[12] as given, the rest off (the beacon's OFF is 0)
local function switches(p)
    for i = 1, 12 do rt:set(SW, i, p[i] or (i == 8 and 0 or 1)) end
    rt:frame(1 / 30)
end
power(true, true)
rt:set(PSEU_GND, 1)
rt:set(LEVER, 0)
-- each LANDING switch its light (§3.2): OBL [1], OBR [2], IBL [3], IBR [4]
for sw, xp in pairs({[1] = 0, [2] = 3, [3] = 1, [4] = 2}) do
    switches({[sw] = 0})
    for k = 0, 3 do
        T.near(rt:get(LAND, k), k == xp and 1 or 0, 1e-6, "LANDING switch " .. sw .. " alone: X-Plane landing light " .. k)
    end
end
switches({[5] = 0, [7] = 0, [12] = 0})
T.check(rt:get(GEN, 0) == 1 and rt:get(GEN, 1) == 0, "RWY TURNOFF L on, R off: generic lights 0 and 1")
T.equal(rt:get(TAXI), 1, "TAXI on the ground")
T.check(rt:get(GEN, 2) == 0 and rt:get(GEN, 3) == 1, "WING off, LOGO on: generic lights 2 and 3")
for _, c in ipairs({{-1, 1, "BOTH"}, {0, 0, "OFF"}, {1, 1, "LWR"}}) do
    switches({[8] = c[1]})
    T.equal(rt:get("sim/cockpit/electrical/beacon_lights_on"), c[2], "BEACON " .. c[3])
end
-- the gear lever UP: the INBD switch ON dims its side to 70 % (ATA33 p.328,
-- p.330; before, all four at 50 %)
rt:set(LEVER, 2)
switches({[1] = 0, [2] = 0, [3] = 0})
T.near(rt:get(LAND, 0), 0.7, 1e-6, "lever UP, INBD L on: OUTBD L at 70 %")
T.near(rt:get(LAND, 1), 0.7, 1e-6, "lever UP: INBD L at 70 %")
T.near(rt:get(LAND, 3), 1, 1e-6, "lever UP, INBD R off: OUTBD R bright")
rt:set(LEVER, 0)
-- in the air (the PSEU, before X-Plane's onground_any): no turnoff, no taxi
rt:set(PSEU_GND, 0)
switches({[5] = 0, [6] = 0, [7] = 0, [9] = 0})
T.check(rt:get(GEN, 0) == 0 and rt:get(GEN, 1) == 0 and rt:get(TAXI) == 0, "in the air: the turnoff and taxi lights out")
T.equal(rt:get(NAV), 1, "in the air: NAV on")
rt:set(PSEU_GND, 1)
-- the power (before, none: on with the batteries alone)
power(true, false)
switches({[1] = 0, [9] = 0})
T.equal(rt:get(NAV), 0, "no ground service bus: NAV out")
T.near(rt:get(LAND, 0), 1, 1e-6, "no ground service bus: OUTBD L on (AC bus 3)")
power(false, false)
rt:frame(1 / 30)
T.near(rt:get(LAND, 0), 0, 1e-6, "no AC buses: OUTBD L out")
power(true, true)

-- (7-2a, LIGHT-04) the STROBE switch the way NAV's is: position 0 on, 1 off
-- (cold and dark puts [1]-[12] at 1: the strobes were on)
for _, p in ipairs({0, 1}) do
    rt:set(SW, 9, p)
    rt:set(SW, 10, p)
    rt:frame(1 / 30)
    T.equal(rt:get("sim/cockpit2/switches/strobe_lights_on"), 1 - p, "STROBE at " .. p)
    T.equal(rt:get("sim/cockpit2/switches/strobe_lights_on"), rt:get(NAV),
        "STROBE and NAV both at " .. p .. ": the strobes as the nav lights")
end
-- (7-2a, LIGHT-08, LIGHT-05) no full garbage collection in the frame; the
-- electrical init script writes the strobes no more
local function source(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end
T.check(not source("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua"):find('collectgarbage%("collect"%)'),
    "the lighting module: no collectgarbage(\"collect\")")
T.check(not source("plugins/xtlua/init/scripts/B747.03.electrical/B747.03.electrical.lua"):find("strobe_lights_on", 1, true),
    "the electrical init script: no strobe writes")
T.done()
