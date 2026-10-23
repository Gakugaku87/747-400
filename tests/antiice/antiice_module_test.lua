-- Run from the repository root with LuaJIT: luajit tests/antiice/antiice_module_test.lua
-- The anti-ice module as XTLua runs it (tests/lib/xtlua.lua): the P5
-- anti-ice, window heat and wiper controls, the engines' bleed air, the
-- air/ground relay, TAT, X-Plane's ice detection and failures and the buses
-- in; the NAI and WAI valves, the P5 lights, X-Plane's heat, ice detection
-- and wipers, and the EICAS slots out. The model's behaviour is tested in
-- antiice_model_test.lua; this checks the wiring and the names
-- (docs/overhaul/notes/ATA-30.md §6).
local T = dofile("tests/lib/check.lua")("antiice_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.50.xt.antiice/B747.50.xt.antiice.lua")
rt:set("sim/version/xplane_internal_version", 120400)
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local SW = "laminar/B747/button_switch/position"
local ICE = "laminar/B747/antiice/"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local XICE = "sim/cockpit2/ice/"
local FAIL = "sim/operation/failures/"
local WIPER = "sim/cockpit2/switches/wiper_speed_switch"
local function bleed(n, psi) rt:set("laminar/B747/air/engine" .. n .. "/bleed_air_psi", psi) end

-- power, on the ground, engines stopped, TAT 5°C, every switch off
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/y_agl", 2)
rt:set("sim/weather/aircraft/temperature_leadingedge_deg_c", 5)
frames(4)
for n = 0, 3 do
    T.equal(get(ICE .. "nacelle/valve_pos", n), 0, "NAI " .. (n + 1) .. " off: valve closed")
    T.equal(get(ICE .. "light/nai_valve", n), 0, "NAI " .. (n + 1) .. " off: VALVE light out")
end
for w = 0, 1 do
    T.equal(get(ICE .. "light/window_inop", w), 1, "WINDOW HEAT " .. w .. " off: INOP light (FCOM p.633)")
    T.equal(get(ADVISORY, 194 + w), 1, "WINDOW HEAT " .. w .. " off: HEAT WINDOW message")
    T.equal(get(XICE .. "ice_window_heat_on_window", w), 0, "WINDOW HEAT " .. w .. " off: X-Plane's windshield heat off")
end
T.equal(get(XICE .. "ice_window_heat_on_window", 2), 1, "AC power: X-Plane's left side window heated")
T.equal(get(XICE .. "ice_window_heat_on_window", 3), 1, "AC power: X-Plane's right side window heated")
T.equal(get(XICE .. "ice_pitot_heat_on_pilot"), 0, "engines stopped: probes not heated")
T.equal(get(ADVISORY, 188), 0, "engines stopped: no HEAT P/S CAPT")
T.equal(get(XICE .. "ice_detect_on"), 1, "detectors powered: X-Plane's ice detection on")
T.equal(get(ADVISORY, 222), 0, "detectors powered: no >ICE DETECTORS")

-- NAI 1-4 ON without bleed air: the valves stay closed, the VALVE lights on;
-- no NAI VALVE message with the engines stopped
for n = 0, 3 do rt:set(SW, 68 + n, 1) end
frames(5)
for n = 0, 3 do
    T.equal(get(ICE .. "nacelle/valve_pos", n), 0, "NAI " .. (n + 1) .. " ON, no bleed air: valve closed")
    T.equal(get(ICE .. "light/nai_valve", n), 1, "NAI " .. (n + 1) .. " ON, no bleed air: VALVE light")
    T.equal(get(ADVISORY, 242 + n), 0, "NAI " .. (n + 1) .. ": no NAI VALVE message with the engine stopped")
    T.equal(get(XICE .. "ice_inlet_heat_on_per_engine", n), 0, "NAI " .. (n + 1) .. ": X-Plane's inlet heat off")
end
-- bleed air: the valves open, the lights go out, X-Plane's inlet heat on
for n = 1, 4 do bleed(n, 30) end
frames(2)
for n = 0, 3 do
    T.equal(get(ICE .. "nacelle/valve_pos", n), 1, "NAI " .. (n + 1) .. " with bleed air: valve open")
    T.equal(get(ICE .. "light/nai_valve", n), 0, "NAI " .. (n + 1) .. " valve open: VALVE light out")
    T.equal(get(XICE .. "ice_inlet_heat_on_per_engine", n), 1, "NAI " .. (n + 1) .. ": X-Plane's inlet heat on")
end

-- the engines running; engine 2 loses its bleed air: NAI VALVE 2 after 3.5 s
for n = 0, 3 do rt:set("sim/flightmodel/engine/ENGN_running", n, 1) end
bleed(2, 0)
frames(3)
T.equal(get(ICE .. "light/nai_valve", 1), 1, "NAI 2 ON, bleed air lost: VALVE light")
T.equal(get(ADVISORY, 243), 0, "NAI VALVE 2: not before 3.5 s")
frames(1)
T.equal(get(ADVISORY, 243), 1, "NAI VALVE 2 after 3.5 s with the engine running (ATA30_32_35_36 p.206)")
T.equal(get(ADVISORY, 242), 0, "NAI 1 open: no NAI VALVE 1")
bleed(2, 30)
frames(2)
T.equal(get(ADVISORY, 243), 0, "bleed air back: NAI VALVE 2 cleared")
-- X-Plane's inlet heat 3 failure: the valve closes, latched until the switch goes off
rt:set(FAIL .. "rel_ice_inlet_heat3", 6)
frames(5)
T.equal(get(ICE .. "nacelle/valve_pos", 2), 0, "inlet heat 3 failed: NAI 3 valve closed")
T.equal(get(ADVISORY, 244), 1, "inlet heat 3 failed: NAI VALVE 3")
rt:set(FAIL .. "rel_ice_inlet_heat3", 0)
frames(2)
T.equal(get(ICE .. "nacelle/valve_pos", 2), 0, "failure gone: NAI 3 still closed (latched)")
rt:set(SW, 70, 0)
frames(0.5)
rt:set(SW, 70, 1)
frames(2)
T.equal(get(ICE .. "nacelle/valve_pos", 2), 1, "NAI 3 off and ON: the valve opens again")
T.equal(get(ADVISORY, 244), 0, "NAI 3 open: NAI VALVE 3 cleared")

-- the probes with the engines running, on the ground: pitot-static and AOA
-- heated, TAT not (FCOM p.634)
for _, name in ipairs({"ice_pitot_heat_on_pilot", "ice_static_heat_on_pilot", "ice_pitot_heat_on_copilot",
        "ice_static_heat_on_copilot", "ice_pitot_heat_on_standby", "ice_static_heat_on_standby",
        "ice_AOA_heat_on", "ice_AOA_heat_on_copilot"}) do
    T.equal(get(XICE .. name), 1, "engines running: X-Plane's " .. name)
end
T.equal(get(XICE .. "ice_TAT_heat_on"), 0, "on the ground: L TAT not heated")
T.equal(get(XICE .. "ice_TAT_heat_on_copilot"), 0, "on the ground: R TAT not heated")
-- X-Plane's probe heat failures to the HEAT messages
local PROBE_FAILURES = {
    {"rel_ice_pitot_heat1", 188, "HEAT P/S CAPT"}, {"rel_ice_static_heat", 188, "HEAT P/S CAPT"},
    {"rel_ice_pitot_heat2", 189, "HEAT P/S F/O"}, {"rel_ice_static_heat2", 189, "HEAT P/S F/O"},
    {"rel_ice_pitot_heat_stby", 190, "HEAT P/S L AUX"}, {"rel_ice_static_heat_stby", 191, "HEAT P/S R AUX"},
    {"rel_ice_AOA_heat", 186, "HEAT L AOA"}, {"rel_ice_AOA_heat2", 192, "HEAT R AOA"},
}
for _, f in ipairs(PROBE_FAILURES) do
    rt:set(FAIL .. f[1], 6)
    frames(0.1)
    T.equal(get(ADVISORY, f[2]), 1, f[1] .. " failed: " .. f[3])
    local others = 0
    for slot = 186, 193 do if slot ~= f[2] then others = others + get(ADVISORY, slot) end end
    T.equal(others, 0, f[1] .. " failed: no other HEAT message")
    rt:set(FAIL .. f[1], 0)
    frames(0.1)
    T.equal(get(ADVISORY, f[2]), 0, f[1] .. " back: " .. f[3] .. " cleared")
end
rt:set(FAIL .. "rel_ice_pitot_heat1", 6)
frames(0.1)
T.equal(get(XICE .. "ice_pitot_heat_on_pilot"), 0, "pitot heat 1 failed: X-Plane's pilot pitot heat off")
rt:set(FAIL .. "rel_ice_pitot_heat1", 0)

-- WINDOW HEAT L, R ON: X-Plane's windshield heat on, the INOP lights and messages out
rt:set(SW, 73, 1)
rt:set(SW, 74, 1)
frames(0.5)
for w = 0, 1 do
    T.equal(get(XICE .. "ice_window_heat_on_window", w), 1, "WINDOW HEAT " .. w .. " ON: X-Plane's windshield heat")
    T.equal(get(ICE .. "light/window_inop", w), 0, "WINDOW HEAT " .. w .. " ON: INOP light out")
    T.equal(get(ADVISORY, 194 + w), 0, "WINDOW HEAT " .. w .. " ON: no HEAT WINDOW message")
end
-- the left windshield's heat fails: INOP L and HEAT WINDOW L, latched
rt:set(FAIL .. "rel_ice_window_heat", 6)
frames(0.5)
T.equal(get(ICE .. "light/window_inop", 0), 1, "left windshield heat failed: INOP L")
T.equal(get(ADVISORY, 194), 1, "left windshield heat failed: HEAT WINDOW L")
T.equal(get(XICE .. "ice_window_heat_on_window", 0), 0, "left windshield heat failed: X-Plane's heat off")
T.equal(get(ICE .. "light/window_inop", 1), 0, "left windshield heat failed: INOP R out")
rt:set(FAIL .. "rel_ice_window_heat", 0)
frames(0.5)
T.equal(get(ICE .. "light/window_inop", 0), 1, "failure gone: INOP L until the switch is reset")
rt:set(SW, 73, 0)
frames(11)
rt:set(SW, 73, 1)
frames(0.5)
T.equal(get(ICE .. "light/window_inop", 0), 0, "WINDOW HEAT L off 10 s, then ON: reset (FCOM p.633)")
rt:set(FAIL .. "rel_ice_window_heat_cop", 6)
frames(0.5)
T.equal(get(ADVISORY, 195), 1, "right windshield heat failed: HEAT WINDOW R")
rt:set(FAIL .. "rel_ice_window_heat_cop", 0)
rt:set(SW, 74, 0)
frames(11)
rt:set(SW, 74, 1)
frames(0.5)

-- WING ANTI-ICE ON on the ground: the valves stay closed, the light out
rt:set(SW, 72, 1)
frames(4)
T.equal(get(ICE .. "wing/valve_pos", 0), 0, "WAI ON on the ground: left valve closed")
T.equal(get(ICE .. "wing/valve_pos", 1), 0, "WAI ON on the ground: right valve closed")
T.equal(get(ICE .. "light/wai_valve"), 0, "WAI ON on the ground: VALVE light out")
T.equal(get(XICE .. "ice_surfce_heat_left_on"), 0, "WAI ON on the ground: X-Plane's left wing heat off")

-- in the air: the WAI valves open (X-Plane's wing heat), the TAT probes heated
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/flightmodel/position/y_agl", 3000)
frames(1)
T.equal(get(ICE .. "light/wai_valve"), 1, "in the air: valves travelling, VALVE light")
frames(3)
for w = 0, 1 do T.equal(get(ICE .. "wing/valve_pos", w), 1, "in the air: WAI valve " .. w .. " open") end
T.equal(get(ICE .. "light/wai_valve"), 0, "WAI valves open: VALVE light out")
T.equal(get(XICE .. "ice_surfce_heat_left_on"), 1, "WAI: X-Plane's left wing heat")
T.equal(get(XICE .. "ice_surfce_heat_right_on"), 1, "WAI: X-Plane's right wing heat")
T.equal(get(XICE .. "ice_TAT_heat_on"), 1, "in the air: L TAT heated")
T.equal(get(XICE .. "ice_TAT_heat_on_copilot"), 1, "in the air: R TAT heated")
-- X-Plane's left surface heat failure: the left valve stays open after WAI off
rt:set(FAIL .. "rel_ice_surf_heat", 6)
rt:set(SW, 72, 0)
frames(6)
T.equal(get(ICE .. "wing/valve_pos", 0), 1, "left WAI valve failed: stays open")
T.equal(get(ICE .. "wing/valve_pos", 1), 0, "WAI off: right valve closed")
T.equal(get(ADVISORY, 296), 1, "left valve open, WAI off: WAI VALVE LEFT after 5 s")
T.equal(get(ADVISORY, 297), 0, "right valve closed: no WAI VALVE RIGHT")
T.equal(get(XICE .. "ice_surfce_heat_left_on"), 1, "left valve open: X-Plane's left wing still heated")
rt:set(FAIL .. "rel_ice_surf_heat", 0)
frames(4)
T.equal(get(ADVISORY, 296), 0, "failure gone: the valve closes, WAI VALVE LEFT cleared")
-- the TAT probe heat fails in flight: HEAT L TAT after 15 s
rt:set(FAIL .. "rel_ice_TAT_heat", 6)
frames(14)
T.equal(get(ADVISORY, 187), 0, "HEAT L TAT: not before 15 s")
frames(2)
T.equal(get(ADVISORY, 187), 1, "HEAT L TAT after 15 s (ATA30_32_35_36 p.228)")
rt:set(FAIL .. "rel_ice_TAT_heat", 0)
frames(0.1)
T.equal(get(ADVISORY, 187), 0, "TAT heat back: HEAT L TAT cleared")

-- ice on the detectors: >ICING; gone with NAI still on: >NO ICING
rt:set("sim/cockpit2/annunciators/ice", 1)
frames(0.1)
T.equal(get(CAUTION, 45), 1, "ice detected in flight: >ICING")
rt:set("sim/cockpit2/annunciators/ice", 0)
frames(0.1)
T.equal(get(CAUTION, 45), 0, "no ice: >ICING cleared")
T.equal(get(ADVISORY, 247), 1, "no ice, NAI still on: >NO ICING")
-- >ANTI-ICE: anti-ice on above TAT 12°C without ice detected (FCOM p.635)
rt:set("sim/weather/aircraft/temperature_leadingedge_deg_c", 15)
frames(0.1)
T.equal(get(ADVISORY, 7), 1, "NAI on, TAT 15°C: >ANTI-ICE")
for n = 0, 3 do rt:set(SW, 68 + n, 0) end
frames(2)
T.equal(get(ADVISORY, 7), 0, "anti-ice off: >ANTI-ICE cleared")
T.equal(get(ADVISORY, 247), 0, "anti-ice off: >NO ICING cleared")
-- X-Plane's ice detector failure: both detectors
rt:set(FAIL .. "rel_ice_detect", 6)
frames(1)
T.equal(get(XICE .. "ice_detect_on"), 0, "detectors failed: X-Plane's ice detection off")
T.equal(get(ADVISORY, 222), 0, ">ICE DETECTORS: not before 2 s")
frames(2)
T.equal(get(ADVISORY, 222), 1, ">ICE DETECTORS after 2 s (ATA30_32_35_36 p.164)")
T.equal(get(STATUS, 37), 0, "STATUS ICE DETECTOR L: not before 12 s")
frames(10)
T.equal(get(STATUS, 37), 1, "STATUS ICE DETECTOR L after 12 s")
T.equal(get(STATUS, 38), 1, "STATUS ICE DETECTOR R after 12 s")
rt:set(FAIL .. "rel_ice_detect", 0)
frames(0.1)
T.equal(get(ADVISORY, 222), 0, "detectors back: >ICE DETECTORS cleared")
T.equal(get(STATUS, 37), 0, "detectors back: STATUS ICE DETECTOR L cleared")
T.equal(get(XICE .. "ice_detect_on"), 1, "detectors back: X-Plane's ice detection on")

-- the wiper selectors: LO and HI to X-Plane's 50 and 100 %, each side
local L_UP, R_UP = ICE .. "wndshlsd_wiper_L/sel_dial_up", ICE .. "wndshlsd_wiper_R/sel_dial_up"
rt:command(L_UP)
frames(0.1)
T.equal(get(ICE .. "wndshlsd_wiper_L/sel_dial_pos"), 1, "WIPER L up: LO")
T.equal(get(WIPER, 0), 2, "WIPER L LO: X-Plane's left wiper 50 %")
T.equal(get(WIPER, 1), 0, "WIPER R OFF: X-Plane's right wiper parked")
rt:command(L_UP)
rt:command(L_UP)
frames(0.1)
T.equal(get(ICE .. "wndshlsd_wiper_L/sel_dial_pos"), 2, "WIPER L: stops at HI")
T.equal(get(WIPER, 0), 3, "WIPER L HI: X-Plane's left wiper 100 %")
rt:command(R_UP)
frames(0.1)
T.equal(get(WIPER, 1), 2, "WIPER R LO: X-Plane's right wiper 50 %")
rt:command(ICE .. "wndshlsd_wiper_L/sel_dial_dn")
frames(0.1)
T.equal(get(WIPER, 0), 2, "WIPER L down: LO")
rt:set("laminar/B747/electrical/bus/dc", 0, 0)
frames(0.1)
T.equal(get(WIPER, 0), 0, "DC bus 1 off: the left wiper stops")
T.equal(get(WIPER, 1), 2, "DC bus 1 off: the right wiper runs")
rt:set("laminar/B747/electrical/bus/dc", 0, 1)
rt:set("sim/version/xplane_internal_version", 110000)
rt:command(L_UP)
frames(0.1)
T.equal(get("sim/cockpit2/switches/wiper_speed"), 3, "X-Plane 11: one wiper speed, the faster side")
rt:set("sim/version/xplane_internal_version", 120400)

-- the AI's cold & dark (init_CD 1): the wipers off
rt:set("laminar/B747/ice/init_CD", 1)
frames(0.1)
T.equal(get("laminar/B747/ice/init_CD"), 2, "init_CD 1: done (2)")
T.equal(get(ICE .. "wndshlsd_wiper_L/sel_dial_pos"), 0, "init_CD: WIPER L OFF")
T.equal(get(WIPER, 0), 0, "init_CD: X-Plane's left wiper parked")

-- debug/antiice stops the module
rt:set("laminar/B747/debug/antiice", 1)
rt:set(SW, 73, 0)
frames(0.5)
T.equal(get(ICE .. "light/window_inop", 0), 0, "debug/antiice: the module stops")
rt:set("laminar/B747/debug/antiice", 0)
frames(0.5)
T.equal(get(ICE .. "light/window_inop", 0), 1, "debug/antiice 0: the module runs again")

-- every X-Plane dataref the module wrote is writable (DataRefs.txt)
local writable = {}
local file = assert(io.open(xtlua.xplane_root .. "/Resources/plugins/DataRefs.txt", "rb"))
for line in file:lines() do
    local name, w = line:match("^(%S+)\t%S+\t(%S+)")
    if name then writable[name] = w == "y" end
end
file:close()
for name in pairs(rt.written) do
    if name:sub(1, 4) == "sim/" then T.check(writable[name], "the module writes a read-only X-Plane dataref: " .. name) end
end

T.done()
