-- Run from the repository root with LuaJIT: luajit tests/fms/pos_ref_pages_test.lua
-- POS REF 2/3 and 3/3 and the FMC's position updating (6-1/6-2 step 10a;
-- notes/ATA-34-61-FMC.md §86; FCOM p.1240-1245, p.1367-1370, p.1430,
-- p.1435-1436, p.1150) in the FMS module as XTLua runs it (tests/lib/
-- xtlua.lua), near the synthetic ZZAA: GPS L and the DME-DME pair, RNP/
-- ACTUAL, an RNP's entry (VERIFY RNP ENTRY, DELETE), GPS NAV INHIBIT>
-- (RADIO, DD on the ND), BRG/DIST>, PURGE and CONFIRM, 3/3, the ND's update
-- lines, INIT/REF INDEX's <POS in the air, UNABLE RNP (advisory) and VERIFY
-- RNP over the ocean, NAVAID INHIBIT leaving a DME out; LOC updating on ZZAA's ILS16R
-- (LOC-DD, LOC-GPS L, LOCGPS).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("pos_ref_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["sim/cockpit2/radios/indicators/nav1_nav_id"] = "string"}
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
-- the IRUs navigating at 35N 140E (their small errors), both GPSs valid
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35 + 0.0005 * (i - 1))
    rt:set("laminar/B747/irs/lon", i, 140 + 0.0004 * (i - 1))
    rt:set("laminar/B747/irs/gs", i, 0)
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
-- INIT/REF INDEX: the INIT REF key, then <INDEX on the page it shows
local function to_index()
    key("func_key/index")
    if not line(1):find("INDEX", 1, true) then key("ls_key/L6") end
end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local GPS_LINE, IRS_LINE = "laminar/B747/irs/gps_display_line", "laminar/B747/irs/irs_display_line"
local function advisory() return rt:get("laminar/B747/CAS/advisory_status", 295) end
local function caution() return rt:get("laminar/B747/CAS/caution_status", 66) end

-- the ND's update lines (FCOM p.1150)
T.equal(rt:get(GPS_LINE), "GPS", "the ND: GPS")
T.equal(rt:get(IRS_LINE), "IRS (3)", "the ND: IRS (3)")

-- INIT/REF INDEX's <POS on the ground: POS INIT 1/3, NEXT: POS REF 2/3
to_index()
key("ls_key/L2")
T.check(line(1):find("POS INIT", 1, true) ~= nil, "<POS on the ground: POS INIT")
key("func_key/next_pg")
T.check(line(1):find("POS REF", 1, true) ~= nil and small(1):find("2/3", 1, true) ~= nil, "NEXT: POS REF 2/3")
T.check(small(2):find("^ FMC POS %(GPS L%) +GS$") ~= nil, "1L FMC POS (GPS L) and GS (FCOM p.1367): " .. small(2))
T.check(line(3):find("^N35`00%.0 E140`00%.0   0  $") ~= nil and small(3):find("KT$") ~= nil, "the FMC position, 0 KT: " .. line(3))
T.check(small(4):find("^ IRS%(3%)") ~= nil, "2L IRS(3)")
T.check(line(5):find("^N35`00%.0 E140`00%.0") ~= nil, "the mixed IRS position: " .. line(5))
T.check(small(6):find("^ RNP/ACTUAL +DME%-DME$") ~= nil, "RNP/ACTUAL, DME-DME (FCOM p.1244): " .. small(6))
T.check(line(7):find("^    /0%.05") ~= nil and small(7):find("^1%.00     NM") ~= nil, "the takeoff RNP 1.00 small, /0.05 large, NM small: " .. line(7) .. "|" .. small(7))
T.check(line(7):find("ZZW", 1, true) ~= nil, "the pair has ZZW (ZZV and ZZD lie in line): " .. line(7))
T.equal(small(10), "---------------- GPS NAV", "the dashes and GPS NAV")
T.check(line(11):find("^<PURGE +INHIBIT>$") ~= nil, "<PURGE, INHIBIT>")
T.check(line(13):find("^<INDEX +BRG/DIST>$") ~= nil, "<INDEX, BRG/DIST>")

-- the RNP's entries (FCOM p.1368, p.1436)
enter("0.5", "L3")
T.check(line(7):find("^0%.50/0%.05") ~= nil and small(7):find("^     ") ~= nil, "0.5: RNP 0.50 large: " .. line(7))
enter("3", "L3")
T.equal(pad(), "VERIFY RNP ENTRY", "3 over the default 1.00: VERIFY RNP ENTRY")
T.check(line(7):find("^3%.00/") ~= nil, "accepted: 3.00")
enter("100", "L3")
T.equal(pad(), "INVALID ENTRY", "100: INVALID ENTRY")
delete("L3")
T.check(small(7):find("^1%.00") ~= nil and line(7):find("^    /") ~= nil, "DELETE: the default 1.00 small")
delete("L3")
T.equal(pad(), "INVALID DELETE", "DELETE of the default: INVALID DELETE")
clear()

-- GPS NAV (FCOM p.1369): RADIO with DME-DME, DD on the ND
key("ls_key/R5")
frames(1.2)
T.check(line(11):find("ENABLE>$") ~= nil, "INHIBIT>: ENABLE>")
T.check(small(2):find("^ FMC POS %(RADIO%)") ~= nil, "FMC POS (RADIO)")
T.equal(rt:get(GPS_LINE), "DD", "the ND: DD")
key("func_key/next_pg")
T.check(small(1):find("3/3", 1, true) ~= nil, "POS REF 3/3")
T.check(small(2):find("^ IRS L +GS$") ~= nil and line(3):find("^N35`00%.0") ~= nil, "IRS L and its position")
T.check(small(6):find("^ IRS R") ~= nil and line(7):find("^N35`00%.0") ~= nil, "IRS R")
T.check(small(8):find("^ GPS L") ~= nil and trim(line(9)) == "", "GPS L blank while inhibited (FCOM p.1370)")
key("func_key/prev_pg")
key("ls_key/R5")
frames(1.2)
T.check(line(11):find("INHIBIT>$") ~= nil and small(2):find("%(GPS L%)") ~= nil, "ENABLE>: GPS L again")
T.equal(rt:get(GPS_LINE), "GPS", "the ND: GPS again")

-- BRG/DIST> (FCOM p.1369): the IRS line from the FMC position
key("ls_key/R6")
T.check(line(13):find("LAT/LON>$") ~= nil, "BRG/DIST>: LAT/LON>")
T.check(line(5):find("^%d%d%d`/0%.0") ~= nil and small(5):find("NM", 1, true) ~= nil, "IRS(3) as bearing/distance: " .. line(5))
key("func_key/next_pg")
T.check(line(3):find("^%d%d%d`/0%.0") ~= nil, "3/3 too: " .. line(3))
to_index()
frames(1.2)
key("ls_key/L2")
key("func_key/next_pg")
T.check(line(13):find("BRG/DIST>$") ~= nil and line(5):find("^N35") ~= nil, "after leaving the pages: LAT/LON again")

-- PURGE and CONFIRM (FCOM p.1368)
key("ls_key/L5")
T.check(line(11):find("^<CONFIRM") ~= nil and small(10):find("^PURGE +GPS NAV$") ~= nil, "<PURGE: PURGE, <CONFIRM")
T.check(small(2):find("^ FMC POS +GS$") ~= nil, "the mixed IRS position on the FMC POS line")
key("ls_key/L5")
frames(1.2)
T.check(line(11):find("^<PURGE") ~= nil, "CONFIRM: <PURGE again")
T.check(small(2):find("%(INERTIAL%)") ~= nil and rt:get(GPS_LINE) == "", "the IRS position, no updating for a while: INERTIAL, the ND's line blank")
frames(11)
T.check(small(2):find("%(GPS L%)") ~= nil, "10 s later GPS L again")

-- NAVAID INHIBIT (FCOM p.1356): ZZW out, no DME-DME pair left (ZZV and ZZD in line)
to_index()
key("ls_key/R1")                 -- NAV DATA>
enter("ZZW", "L4")
frames(11)
to_index()
key("ls_key/L2")
key("func_key/next_pg")
T.check(small(6):find("NAV STA$") ~= nil and trim(line(7):sub(13)) == "", "ZZW inhibited: NAV STA, blank: " .. small(6))

-- in the air over the ocean: INIT/REF INDEX's <POS to POS REF 2/3; IRS
-- only, UNABLE RNP (advisory); VERIFY RNP
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/position/latitude", 20)
rt:set("sim/flightmodel/position/longitude", 160)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
for i = 0, 2 do
    rt:set("laminar/B747/irs/lat", i, 20)
    rt:set("laminar/B747/irs/lon", i, 160)
end
frames(11)
to_index()
key("ls_key/L2")
T.check(line(1):find("POS REF", 1, true) ~= nil and small(1):find("2/3", 1, true) ~= nil, "<POS in the air: POS REF 2/3 (FCOM p.1367)")
T.check(small(7):find("^12%.00") ~= nil, "no navaid within 200 nm: oceanic/remote 12.00")
key("ls_key/R5")
enter(".04", "L3")
T.equal(pad(), "VERIFY RNP ENTRY", "0.04 under the ANP 0.05: VERIFY RNP ENTRY")
clear()
frames(1.2)
T.check(small(2):find("%(INERTIAL%)") ~= nil, "IRS only")
T.equal(advisory(), 1, "UNABLE RNP: the advisory (FCOM p.1430)")
T.equal(caution(), 0, "not the caution outside the approach")
enter("15", "L3")
frames(1.2)
T.equal(advisory(), 0, "RNP 15: no UNABLE RNP")
rt:set("sim/flightmodel/position/latitude", 35.5)
rt:set("sim/flightmodel/position/longitude", 140.5)
frames(11)
T.check(small(7):find("^     ") ~= nil and line(7):find("^15%.00") ~= nil, "the entry 15.00 still")
T.equal(rt:get("laminar/B747/fms/notification", 52), 1, "domestic (2.00) under the entry: VERIFY RNP (FCOM p.1435)")
delete("L3")
frames(1.2)
T.equal(rt:get("laminar/B747/fms/notification", 52), 0, "DELETE: VERIFY RNP gone")

-- LOC updating (FCOM p.1241): the route ZZAA to ZZAA with ILS16R active;
-- 10 nm out on IZA's course (150 true) at 3,000 ft, ILS L receiving IZA
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
key("func_key/clb")              -- in the air: ZZAA ARRIVALS
key("ls_key/R1")                 -- ILS16R
key("key/execute")
T.equal(fms.ns.B747_fmc_route.rte.appr and fms.ns.B747_fmc_route.rte.appr.rwy, "RW16R", "the active route's approach to RW16R")
rt:set("sim/flightmodel/position/latitude", 35.154)
rt:set("sim/flightmodel/position/longitude", 139.908)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 3000)
rt:set("sim/flightmodel/position/hpath", 150)
rt:set("sim/cockpit2/radios/indicators/nav_display_horizontal", 0, 1)
rt:set("sim/cockpit2/radios/indicators/nav1_nav_id", "IZA")
frames(11)
to_index()
key("ls_key/L2")
T.check(small(2):find("%(LOC%-DD%)") ~= nil and rt:get(GPS_LINE) == "LOC DD", "GPS inhibited: LOC-DD, the ND's LOC DD: " .. small(2))
key("ls_key/R5")
frames(1.2)
T.check(small(2):find("%(LOC%-GPS L%)") ~= nil and rt:get(GPS_LINE) == "LOCGPS", "GPS: LOC-GPS L, the ND's LOCGPS: " .. small(2))
rt:set("sim/flightmodel/position/hpath", 210)
frames(1.2)
T.check(small(2):find("%(GPS L%)") ~= nil, "tracking 60 degrees off the course: GPS L alone")
rt:set("sim/flightmodel/position/hpath", 150)
rt:set("sim/cockpit2/radios/indicators/nav1_nav_id", "ZZV")
frames(1.2)
T.check(small(2):find("%(GPS L%)") ~= nil, "ILS L on another station: no LOC updating")
T.done()
