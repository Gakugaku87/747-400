-- Run from the repository root with LuaJIT: luajit tests/fms/navrad_pages_test.lua
-- NAV RADIO's VOR and ADF lines and the FMC's VOR tuning (6-1/6-2 step
-- 10b; notes/ATA-34-61-FMC.md §87; FCOM p.1303-1304; FMSPG p.206-207) in
-- the FMS module as XTLua runs it (tests/lib/xtlua.lua), near the
-- synthetic ZZAA: A with no route (the DME-DME pair's stations), P (the
-- SID ZULU1 from 16R: ZZV) and A on an active route, manual identifiers,
-- frequencies and courses (M, CRS dashes and the course, DELETE back),
-- RADIAL, the ADFs (BFO, ANT, DELETE), the tuning modes' letters.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("navrad_pages")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
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
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
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
local function delete(lsk) clear() rt:command(K .. "key/del") frames(0.1) key("ls_key/" .. lsk) end
local function pad() return (line(14):gsub("%s+$", "")) end
local FREQ = "sim/cockpit2/radios/actuators/nav_frequency_hz"
local OBS = "sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot"
local MODES = "laminar/B747/radio/tuningmodes"
local function freq(i) return rt:get(FREQ, i) end

-- no route: A, the DME-DME pair's stations (ZZV and ZZD lie in line; ZZW
-- 107 degrees off them)
frames(1.2)
key("func_key/navrad")
T.check(line(1):find("NAV RADIO", 1, true) ~= nil, "NAV RADIO")
T.equal(small(2), " VOR L             VOR R", "the titles")
T.check(small(3):sub(7, 7) == "A" and small(3):sub(18, 18) == "A", "A small on both (FCOM p.1303): " .. small(3))
local pairSt = {[11500] = "ZZV", [11450] = "ZZW", [11300] = "ZZD"}
T.check(pairSt[freq(2)] and pairSt[freq(3)] and freq(2) ~= freq(3) and (freq(2) == 11450 or freq(3) == 11450),
    "VOR L and R on the pair, ZZW one of them: " .. freq(2) .. " " .. freq(3))
T.check(line(3):find("^1%d%d%.%d%d Z") ~= nil, "VOR L: its frequency and identifier: " .. line(3))
T.check(line(5):find("^   ") ~= nil and line(5):find("   $") ~= nil, "CRS blank while the FMC tunes")
T.equal(rt:get(MODES):sub(2, 3), "AA", "the tuning modes: A, A")

-- the active route from 16R on ZULU1 (its first leg's navaid ZZV): P
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/clb")              -- DEP/ARR INDEX
key("ls_key/L1")                 -- ZZAA DEPARTURES
key("ls_key/L1")                 -- ZULU1
key("ls_key/R1")                 -- 16R
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1.2)
T.check(fms.ns.B747_fmc_route.active, "the route active")
key("func_key/navrad")
T.check(small(3):sub(7, 7) == "P" and freq(2) == 11500 and line(3):find("^115%.00 ZZV") ~= nil, "VOR L: P ZZV, the SID's navaid: " .. line(3) .. "|" .. small(3))
T.check(small(3):sub(18, 18) == "A" and freq(3) ~= 11500, "VOR R: A another station: " .. small(3))
T.equal(rt:get(MODES):sub(2, 3), "PA", "the tuning modes: P, A")

-- manual (FCOM p.1304): an identifier, a frequency with a course, DELETE
enter("ZZD", "R1")
T.check(small(3):sub(18, 18) == "M" and freq(3) == 11300 and line(3):find("ZZD 113%.00$") ~= nil, "ZZD on VOR R: M, 113.00: " .. line(3))
T.check(line(5):find("%-%-%-$") ~= nil, "CRS R dashes")
enter("45", "R2")
T.check(line(5):find("045$") ~= nil and rt:get(OBS, 3) == 45, "045: the course, the receiver's course: " .. line(5))
enter("113.00/090", "L1")
T.check(small(3):sub(7, 7) == "M" and freq(2) == 11300 and line(5):find("^090") ~= nil and rt:get(OBS, 2) == 90,
    "113.00/090 on VOR L: M and its course: " .. line(5))
enter("ZZX", "L1")
T.equal(pad(), "NOT IN DATA BASE", "ZZX: NOT IN DATA BASE")
clear()
enter("ZA", "L1")
T.equal(pad(), "INVALID ENTRY", "the NDB ZA: INVALID ENTRY")
clear()
enter("1", "L2")
T.check(line(5):find("^001") ~= nil, "a course on VOR L's manual frequency")
delete("L1")
frames(1.2)
T.check(small(3):sub(7, 7) == "P" and freq(2) == 11500 and line(5):find("^   ") ~= nil, "DELETE: P ZZV again, its course gone (FMSPG p.207)")
enter("100", "L2")
T.equal(pad(), "INVALID ENTRY", "a course while the FMC tunes: INVALID ENTRY")
clear()
T.equal(rt:get(MODES):sub(2, 3), "PM", "the tuning modes: P, M")

-- RADIAL: the received VOR's, from the station (the bearing to it + 180)
rt:set("sim/cockpit2/radios/indicators/nav_display_horizontal", 2, 1)
rt:set("sim/cockpit2/radios/indicators/nav_bearing_deg_mag", 2, 82)
frames(0.3)
T.equal(line(5):sub(9, 11), "262", "RADIAL L 262: " .. line(5))

-- ADF (FCOM p.1304)
enter("350", "L3")
T.check(line(7):find("^350%.0") ~= nil and rt:get("sim/cockpit2/radios/actuators/adf1_frequency_hz") == 350, "350 on ADF L: " .. line(7))
enter("1304.5B", "R3")
T.check(line(7):find("1304%.5   $") ~= nil and small(7):find("BFO$") ~= nil, "1304.5 BFO on ADF R: " .. line(7) .. "|" .. small(7))
T.equal(rt:get("sim/cockpit2/radios/actuators/adf2_frequency_hz"), 1304, "the radio on 1304")
enter("A", "L3")
T.check(small(7):find("^     ANT") ~= nil and rt:get(MODES):sub(4, 5) == "AB", "A: ANT, the modes' ADF letters A, B: " .. small(7))
delete("L3")
T.check(rt:get(MODES):sub(4, 4) == "M" and not small(7):find("ANT", 1, true), "DELETE: ADF")
delete("L3")
T.equal(pad(), "INVALID DELETE", "DELETE in ADF: INVALID DELETE")
clear()
T.done()
