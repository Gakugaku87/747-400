-- Run from the repository root with LuaJIT: luajit tests/fms/flight_complete_test.lua
-- Flight completion (6-1/6-2 step 10d; notes/ATA-34-61-FMC.md §89; FCOM
-- p.1236, p.1290, p.1307, p.1356-1357, p.1369; FMSPG p.78, p.97; ATA34_2
-- p.540) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), at the
-- synthetic ZZAA: the route, PERF INIT, FLT NO, the takeoff flaps, REF NAV
-- DATA's inhibit, GPS NAV and an RNP entry kept on the ground before a
-- flight and while an engine runs after it; thirty seconds after all four
-- stop, cleared.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("flight_complete")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:set("laminar/B747/gps/valid", 0, 1)
rt:set("laminar/B747/gps/valid", 1, 1)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function seconds(n) for _ = 1, n do rt:frame(1) end end
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function data(k) return (rt:get("laminar/B747/fms/data"):match('"' .. k .. '":"([^"]*)"') or ""):gsub("%s+$", "") end
local INOP = "laminar/B747/engines/inop"
local function engines(stopped) for i = 0, 3 do rt:set(INOP, i, stopped and 1 or 0) end end
engines(false)

-- the preflight: PERF INIT (ZFW 220, cost index 100, CRZ ALT FL350), the
-- route ZZAA to ZZAA with FLT NO, ACTIVATE and EXEC; takeoff flaps 10; REF
-- NAV DATA's NAVAID INHIBIT ZZD; GPS NAV inhibited, RNP 0.30
key("func_key/index")
enter("220", "L3")
enter("100", "L5")
enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
enter("TEST123", "R2")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1.2)
rt:set("laminar/B747/airspeed/flapsRef", 10)
fms.ns.B747_fmc_nav_inhibits().navaid[1] = {ident = "ZZD", lat = 35.3, lon = 140.3, kind = "DME"}
local np = fms.ns.B747_fms_navperf()
np.gps_inhibit, np.rnp_man = true, 0.3
T.check(fms.ns.B747_fmc_route.active and fms.ns.B747_fmc_route.rte.dest.ident == "ZZAA", "the route active")
T.check(data("fltno") == "TEST123" and data("costindex") == "100" and data("crzalt") == "FL350",
    "FLT NO, COST INDEX, CRZ ALT entered: " .. data("fltno") .. " " .. data("costindex") .. " " .. data("crzalt"))
-- (2026-11-24, review CDU-2 = PERF-3) the crew's ZFW 220, CRZ CG 25.5 and
-- TAKEOFF REF's CG 22 with its trim (the green band's selection)
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function perf_page() key("func_key/index") key("ls_key/L6") key("ls_key/L3") end
local function takeoff_page() key("func_key/index") key("ls_key/L6") key("ls_key/L5") end
local ETRIM = "laminar/B747/fmc/elevator_trim"
perf_page()
enter("220", "L3")
enter("25.5", "R4")
T.check(line(9):find("25%.5%%") ~= nil, "CRZ CG 25.5 large: " .. line(9))
takeoff_page()
enter("22", "R4")
clear()
T.check(line(9):find("22%%") ~= nil and small(9):sub(17, 20):find("%d%.%d") ~= nil, "CG 22 large, its trim small: " .. line(9) .. "|" .. small(9))
T.check(rt:get(ETRIM) > 0, "the FMC's trim for the green band: " .. rt:get(ETRIM))
key("func_key/fpln")             -- RTE 1 again (the last block enters its origin)

-- on the ground before a flight: the engines stopped clear nothing
engines(true)
seconds(40)
T.check(fms.ns.B747_fmc_route.active and data("fltno") == "TEST123", "no flight yet: nothing cleared")

-- a flight, the landing; an engine running keeps it all
engines(false)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
seconds(5)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
seconds(5)
rt:set(INOP, 0, 1)
rt:set(INOP, 1, 1)
rt:set(INOP, 2, 1)
seconds(40)
T.check(fms.ns.B747_fmc_route.active and data("fltno") == "TEST123", "engine 4 running: not complete")

-- all four stopped: 29 s nothing, 31 s flight complete
rt:set(INOP, 3, 1)
seconds(29)
T.check(fms.ns.B747_fmc_route.active, "29 s after the shutdown: not yet")
seconds(2)
local st = fms.ns.B747_fmc_route
T.check(not st.active and st.rte.dest == nil and st.rte.origin == nil and #st.rte.legs == 0, "thirty seconds on: the active route cleared (FMSPG p.78)")
T.equal(data("fltno"), "--------", "FLT NO blank (FCOM p.1290)")
T.equal(data("costindex"), "****", "COST INDEX boxes (FCOM p.1307)")
T.equal(data("crzalt"), "*****", "CRZ ALT boxes (FMSPG p.97)")
T.equal(data("zfw"), "***.*", "ZFW boxes")
T.equal(rt:get("laminar/B747/airspeed/flapsRef"), 0, "the takeoff flaps gone (ATA34_2 p.540)")
local inh = fms.ns.B747_fmc_nav_inhibits()
T.check(inh.navaid[1] == nil and not inh.vordme, "REF NAV DATA's inhibits blank (FCOM p.1356-1357)")
T.check(not np.gps_inhibit and np.rnp_man == nil, "GPS NAV enabled again (FCOM p.1369), the RNP entry gone (estimate)")
-- (2026-11-24, stage 4 review FMC-2) CRZ ALT's value too (VNAV's and the
-- pressurization's laminar/B747/autopilot/dist/cruise_alt): the next
-- flight's same CRZ ALT shows (before: boxes, its value unchanged)
T.equal(rt:get("laminar/B747/autopilot/dist/cruise_alt"), 0, "CRZ ALT's value cleared (before: 35000)")
key("func_key/index")
T.check(line(1):find("PERF INIT"), "PERF INIT: " .. line(1))
enter("350", "R1")
frames(0.2)
T.equal(data("crzalt"), "FL350", "the same CRZ ALT entered again: FL350 (before: boxes)")
T.equal(rt:get("laminar/B747/autopilot/dist/cruise_alt"), 35000, "its value 35000")
key("func_key/fpln")

-- once: the next shutdown without a flight clears nothing again
enter("ZZAA", "L1")
seconds(40)
T.equal(fms.ns.B747_fmc_route.rte.origin and fms.ns.B747_fmc_route.rte.origin.ident, "ZZAA", "a new route's origin stays (no flight since)")

-- (2026-11-24, review CDU-2 = PERF-3) after the completion with the crew's
-- CG: TAKEOFF REF shown with CG dashes and no trim (FCOM p.1320 (11.40.44):
-- "Initially displays dashes"; ATA34_2 p.540: removed at flight
-- completion), PERF INIT's CRZ CG the default 20.0 small (FCOM p.1311
-- (11.40.35)), the FMC's trim 0 (the green band's selection not the flight
-- before's). Before, TAKEOFF REF's 13 lines blank (string.format of nil)
-- until a new CG, CRZ CG 20.0 large, the trim kept
T.equal(rt:get(ETRIM), 0, "the FMC's trim gone")
takeoff_page()
T.check(line(1):find("TAKEOFF REF") ~= nil, "TAKEOFF REF shown: " .. line(1))
T.check(small(9):find("%-%-%%") ~= nil and not line(9):find("%%") and not small(9):sub(17, 20):find("%d%.%d"),
    "CG dashes, no trim: " .. line(9) .. "|" .. small(9))
perf_page()
T.check(small(9):find("20%.0%%") ~= nil and not line(9):find("20%.0"), "CRZ CG 20.0 small: " .. line(9) .. "|" .. small(9))
-- the next flight: a ZFW keeps the dashes; a CG brings its trim
enter("230", "L3")
takeoff_page()
T.check(line(1):find("TAKEOFF REF") ~= nil and small(9):find("%-%-%%") ~= nil, "the next ZFW: TAKEOFF REF with CG dashes: "
    .. line(1) .. "|" .. small(9))
enter("24", "R4")
clear()
T.check(line(9):find("24%%") ~= nil and small(9):sub(17, 20):find("%d%.%d") ~= nil and rt:get(ETRIM) > 0,
    "a new CG 24: large, its trim: " .. line(9) .. "|" .. small(9))
T.done()
