-- Run from the repository root with LuaJIT: luajit tests/fms/atc_load_pages_test.lua
-- An ATC uplink's LOAD, stage A (2026-11-20, GAP N19-ATC-03; notes/
-- ATA-34-61-FMC.md §175.5) in the FMS module as XTLua runs it, AutoATC
-- mocked and logged on, a P&W airplane (RTA) with the sim's FMC DATALINK
-- ON, in the air on the synthetic route ZZAA DIRECT ALPHA, Z1 BRAVO CHARL,
-- DIRECT DELTA, ZZBB:
--  - XXXXZ ATC UPLINK's 4R LOAD> on the last page beside STANDBY (FCOM
--    p.760's figure; FMSPG p.290) for a loadable element; none for others;
--  - LOAD: the active route's modification (MOD RTE 1 LEGS, the EXEC
--    light), the page as it is; no LOAD> while a modification exists (RTE 1
--    or RTE 2), again after EXEC; DIRECT TO's route, CROSS's constraint,
--    the offset, RTA PROGRESS's modification;
--  - UNABLE TO LOAD CLEARANCE and PARTIAL CLEARANCE LOADED (FCOM
--    p.1433-1434);
--  - REJECT selected: no LOAD> (FMSPG p.290); the 570 (no RTA): an RTA
--    clearance not loadable.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("atc_load_pages")

local xtlua = dofile("tests/lib/xtlua.lua")
local types = {["xtlua/loadtoFMS"] = "string", ["autoatc/acars/in"] = "string", ["autoatc/acars/out"] = "string",
    ["autoatc/cdu"] = "string", ["autoatc/networking/url"] = "string", ["autoatc/networking/data"] = "string",
    ["autoatc/networking/urlstatus"] = "number", ["autoatc/acars/online"] = "number", ["autoatc/hasMobile"] = "number",
    ["autoatc/com_power"] = "number", ["autoatc/com_frequency_override"] = "number",
    ["autoatc/com_frequency_hz_833"] = "number", ["autoatc/com_standby_frequency_hz_833"] = "number",
    ["autoatc/comChannel"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"fmc_datalink":"ON"},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/aircraft/view/acf_tailnum", "N747BO")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/clock_timer/zulu_time_hours", 16)
rt:set("sim/cockpit2/clock_timer/zulu_time_minutes", 30)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do rt:command(K .. (ch == " " and "key/space" or "alphanum_key/" .. ch)) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local EXEC_LIGHT = "laminar/B747/fms/exec_light_pilot"
local ns = fms.ns
local msgs = ns.acarsSystem.messages
local nid = 100
local function uplink(text)
    nid = nid + 1
    msgs[#msgs.values + 1] = {type = "cpdlc", title = string.sub(text, 1, 19), msg = text, read = false,
        time = "16:30", srcID = nid, messageID = nid, REPLIED = false}
    frames(0.3)
    return #msgs.values
end
local STANDBY = string.format("%-24s", "<STANDBY")
local BLANK24 = string.rep(" ", 24)
local STANDBY_LOAD = "<STANDBY           LOAD>"
-- ACCEPT and SEND on the uplink's last page, then its acknowledgement (the
-- provider's 15 s): the uplink ACCEPTED, no longer pending (the ATC key
-- then shows the next one alone)
local function accept()
    key("ls_key/R5")
    key("ls_key/R5")
    frames(16)
end

-- the active route ZZAA DIRECT ALPHA, Z1 BRAVO CHARL, DIRECT DELTA, ZZBB
-- (the route model, as the RTE pages make it), CRZ ALT FL350, in the air
local R, st = ns.B747_route_model, ns.B747_fmc_route
local function fix(ident) return R.candidates(st, ident, 35.5, 140.5)[1] end
local function idents()
    local out = {}
    for _, l in ipairs(R.shown(st).legs) do out[#out + 1] = l.fix and l.fix.ident or (l.pending and "[]" or "DISC") end
    return table.concat(out, " ")
end
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("CHARL"))
R.add_to(st, fix("DELTA"))
R.activate(st)
R.exec(st)
ns.B747_fmc_route_changed()
ns.setFMSData("crzalt", "FL350")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/flightmodel/position/latitude", 35.4)
rt:set("sim/flightmodel/position/longitude", 140.4)
frames(1)
T.check(st.active and idents() == "ALPHA BRAVO CHARL DELTA", "the active route: " .. idents())

-- logged on to KZAK (AutoATC mocked)
rt:set("autoatc/acars/online", 1)
frames(0.3)
key("func_key/crz")
T.check(page("ATC LOGON/STATUS"), "P&W with FMC DATALINK ON: the ATC pages: " .. line(1))
enter("TBC123", "L2")
enter("KZAK", "L1")
key("ls_key/R1")
msgs[#msgs.values + 1] = {type = "cpdlc", title = "LOGON ACCEPTED", msg = "KZAK", read = true, time = "16:20", messageID = 99}
frames(0.3)
clear()
T.check(ns.B747_fms_atc_logon().comm, "logged on to KZAK")
frames(16)

-- not loadable: no LOAD>
uplink("CLIMB TO AND MAINTAIN FL350")
key("func_key/crz")
T.check(page("1630Z ATC UPLINK"), "ATC: its uplink: " .. line(1))
T.equal(line(9), STANDBY, "CLIMB TO: no LOAD>")
accept()
uplink("WHEN ABLE PROCEED DIRECT TO CHARL")
key("func_key/crz")
T.equal(line(9), STANDBY, "UM75 WHEN ABLE: no LOAD> (not loadable on the 747-400: CPDLC p.203)")
accept()
uplink("CROSS CHARL AT OR ABOVE FL250")
key("func_key/crz")
T.equal(line(9), STANDBY, "UM47 AT OR ABOVE: no LOAD>")
accept()
T.equal(line(3), "                ACCEPTED", "the uplinks before answered")

-- UM74: LOAD> on 4R beside STANDBY; LOAD makes the route's modification
local d1 = uplink("PROCEED DIRECT TO CHARL")
key("func_key/crz")
T.check(page("ATC UPLINK"), "the DIRECT TO's uplink")
T.equal(line(9), STANDBY_LOAD, "4R LOAD> beside 4L STANDBY (FCOM p.760's figure)")
T.equal(rt:get(EXEC_LIGHT), 0, "no EXEC light yet")
key("ls_key/R4")
T.check(page("ATC UPLINK"), "LOAD: the page as it is (estimate): " .. line(1))
T.equal(pad(), "", "all loaded: no message")
T.check(st.mod ~= nil, "the active route's modification")
T.equal(idents(), "CHARL DELTA", "DIRECT TO CHARL: ALPHA and BRAVO collapsed (CPDLC p.203)")
T.equal(rt:get(EXEC_LIGHT), 1, "the EXEC light")
T.equal(line(9), STANDBY, "a route modification: no LOAD> (FMSPG p.290)")
key("func_key/legs")
T.check(page("MOD RTE 1 LEGS"), "MOD RTE 1 LEGS: " .. line(1))
T.check(line(3):find("^CHARL"), "CHARL the first: " .. line(3))
key("key/execute")
T.check(page("ACT RTE 1 LEGS") and st.mod == nil, "EXEC: ACT RTE 1 LEGS: " .. line(1))
T.equal(st.rte.legs[1].fix.ident, "CHARL", "the active route direct to CHARL")
T.equal(rt:get(EXEC_LIGHT), 0, "the EXEC light off")
key("func_key/crz")
T.equal(ns.acarsSystem.getCurrentMessage("fmsL"), d1, "ATC: the DIRECT TO's uplink (the one pending)")
T.equal(line(9), STANDBY_LOAD, "no modification: LOAD> again (it can be selected more than once: FMSPG p.290)")

-- a crew's modification: no LOAD>; ERASE: LOAD> again
key("func_key/legs")
enter("ZZD", "L2")
T.check(st.mod ~= nil, "the crew's modification (ZZD on LEGS)")
key("func_key/crz")
T.equal(line(9), STANDBY, "the crew's modification: no LOAD>")
key("func_key/legs")
key("ls_key/L6")
T.check(st.mod == nil, "ERASE")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "LOAD> again")

-- REJECT selected: LOAD> blanked (FMSPG p.290)
key("ls_key/L5")
T.check(page("REJECT DUE TO"), "REJECT: REJECT DUE TO: " .. line(1))
key("ls_key/L6")
T.check(page("ATC UPLINK"), "<UPLINK")
T.equal(line(9), STANDBY, "REJECT selected: no LOAD>")
key("ls_key/L5")
key("ls_key/R6")
T.check(page("VERIFY RESPONSE") and line(3):find("^UNABLE"), "VERIFY RESPONSE UNABLE: " .. line(3))
key("ls_key/R5")
frames(16)
T.equal(line(3), "                REJECTED", "REJECTED")
T.equal(line(9), BLANK24, "REJECTED: no LOAD> (no STANDBY either)")

-- UM46
uplink("CROSS DELTA AT FL250")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "CROSS DELTA AT FL250: LOAD>")
key("ls_key/R4")
T.equal(pad(), "", "loaded")
local dl = R.shown(st).legs[2]
T.check(dl.fix.ident == "DELTA" and dl.alt == 25000 and dl.akind == "", "DELTA's AT constraint FL250")
key("func_key/legs")
T.check(line(5):find("FL250"), "on RTE LEGS: " .. line(5))
key("key/execute")
T.equal(st.rte.legs[2].alt, 25000, "EXEC: active")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "after EXEC: LOAD> again")
accept()
T.equal(line(3), "                ACCEPTED", "WILCO sent: ACCEPTED")
T.equal(line(9), string.rep(" ", 19) .. "LOAD>", "ACCEPTED: LOAD> without STANDBY (it can be selected more than once)")

-- UM51-53: RTA PROGRESS's modification
uplink("CROSS DELTA AT OR BEFORE 1740Z")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "CROSS DELTA AT OR BEFORE 1740Z: LOAD> (P&W: RTA)")
key("ls_key/R4")
local rs = ns.B747_fms_rta()
T.check(rs.mod and rs.mod.fix == "DELTA" and rs.mod.time == 1060 and rs.mod.suffix == "B", "RTA PROGRESS: DELTA 1740.0B")
T.equal(rt:get(EXEC_LIGHT), 1, "the EXEC light (RTA's modification)")
T.equal(line(9), STANDBY_LOAD, "no route modification: LOAD> still")
key("func_key/prog")
key("func_key/prev_pg")
T.check(page("MOD RTA PROGRESS") and line(3):find("^DELTA") and line(3):find("1740%.0zB$"), "MOD RTA PROGRESS DELTA 1740.0zB: " .. line(3))
key("key/execute")
T.check(rs.active and rs.active.fix == "DELTA" and rs.mod == nil, "EXEC: the RTA active")
key("func_key/crz")
accept()

-- UM64
uplink("OFFSET 20NM RIGHT OF ROUTE")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "OFFSET 20NM RIGHT: LOAD>")
key("ls_key/R4")
T.equal(R.shown(st).offset, 20, "the offset R20 in the modification")
key("func_key/fpln")
T.check(page("MOD RTE 1") and line(13):find("R20$"), "RTE 1: MOD and R20: " .. line(13))
key("key/execute")
T.equal(st.rte.offset, 20, "EXEC: the offset active")
key("func_key/crz")
accept()

-- UNABLE TO LOAD CLEARANCE: a position not in the data; nothing changed
uplink("PROCEED DIRECT TO NOFIX")
key("func_key/crz")
T.equal(line(9), STANDBY_LOAD, "LOAD> (the FMC finds out at LOAD: FMSPG p.293)")
key("ls_key/R4")
T.equal(pad(), "UNABLE TO LOAD CLEARANCE", "UNABLE TO LOAD CLEARANCE (FCOM p.1434)")
T.check(st.mod == nil, "no modification")
clear()
accept()

-- PARTIAL CLEARANCE LOADED: DIRECT TO loaded, CROSS at a fix not in the
-- route not
uplink("PROCEED DIRECT TO DELTA/CROSS ZZD AT FL250")
key("func_key/crz")
key("ls_key/R4")
T.equal(pad(), "PARTIAL CLEARANCE LOADED", "PARTIAL CLEARANCE LOADED (FCOM p.1433)")
T.check(st.mod ~= nil and idents() == "DELTA", "DIRECT TO DELTA loaded: " .. idents())
clear()
key("func_key/legs")
key("ls_key/L6")
T.check(st.mod == nil, "ERASE")
key("func_key/crz")
accept()

-- a multi-page uplink: LOAD> on the last page only
local long = "PROCEED DIRECT TO DELTA " .. string.rep("/REPORT REACHING FL350 ", 5) .. "/WHEN READY CLIMB TO FL370 "
    .. string.rep("/EXPECT FURTHER CLEARANCE AT 1800Z ", 2)
uplink(long)
key("func_key/crz")
local np = ns.B747_atc_uplink_model.pages(ns.B747_atc_uplink_model.wrap(long, 24))
T.check(np >= 2, "more than one page: " .. np)
T.check(not line(9):find("LOAD>"), "page 1: no LOAD>: " .. line(9))
for _ = 2, np do key("func_key/next_pg") end
T.equal(line(9), STANDBY_LOAD, "the last page: LOAD>")

-- the 570 (no RTA: FCOM p.1375): an RTA clearance no LOAD>
rt:set("laminar/B747/engines/type", 1)
frames(0.3)
uplink("CROSS DELTA AT 1800Z")
key("func_key/crz")
T.equal(line(9), STANDBY, "the 570: CROSS AT a time not loadable")

T.done()
