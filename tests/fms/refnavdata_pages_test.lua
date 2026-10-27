-- Run from the repository root with LuaJIT: luajit tests/fms/refnavdata_pages_test.lua
-- REF NAV DATA (6-1/6-2 step 7e; notes/ATA-34-61-FMC.md §36) in the FMS
-- module as XTLua runs it (tests/lib/xtlua.lua), on the synthetic
-- navigation data in tests/fms/data/navdb: NAV DATA> on the INIT/REF INDEX
-- (FCOM p.1281); IDENT: a navaid of each kind, a waypoint, an airport, a
-- runway of the destination, SELECT DESIRED WPT, NOT IN DATA BASE, no
-- DELETE, dashes when the page is selected again (FCOM p.1355-1356;
-- FMSPG p.170-176; ATA34_2 p.547-548); NAVAID INHIBIT, VOR ONLY INHIBIT
-- and VOR/DME NAV (FCOM p.1356-1357; FMSPG p.172-174), the same on both
-- CDUs.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("refnavdata_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")

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
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
             R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function small(c, n) return rt:get(string.format("%sLine%02d_S", CDU[c].lines, n)) end
local function pad(c) return (line(c, 14):gsub("%s+$", "")) end
local function key(c, k, held)
    rt:command(CDU[c].keys .. k, held)
    frames(0.3)
end
local function type_in(c, text)
    for ch in text:gmatch(".") do
        rt:command(CDU[c].keys .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(c, text, lsk) type_in(c, text) key(c, "ls_key/" .. lsk) end
local function clear(c) key(c, "key/clear") key(c, "key/clear", 1.2) end
local function onces(suffix)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.phase == "once" and tostring(e.name):find(suffix .. "$") then n = n + 1 end
    end
    return n
end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local BLANK = string.rep(" ", 24)
-- the INIT/REF INDEX's NAV DATA> (INIT REF on the ground: PERF INIT, its <INDEX)
local function nav_data(c)
    key(c, "func_key/index")
    key(c, "ls_key/L6")
    key(c, "ls_key/R1")
    frames(0.6)
end

-- the page (FCOM p.1355's figure)
key("L", "func_key/index")
key("L", "ls_key/L6")
T.check(line("L", 1):find("INIT/REF INDEX") and line("L", 3):find("NAV DATA>$"), "the INIT/REF INDEX's NAV DATA> (FCOM p.1281)")
local x0 = onces("FMS/index")
key("L", "ls_key/R1")
frames(0.6)
T.equal(line("L", 1), "      REF NAV DATA      ", "NAV DATA>: REF NAV DATA (FCOM p.1355)")
T.equal(onces("FMS/index"), x0, "the FMC's page: no X-Plane INDEX key (before: X-Plane's DATABASE page)")
T.equal(small("L", 2), " IDENT                  ", "IDENT")
T.equal(line("L", 3), "-----                   ", "its dashes (FCOM p.1355)")
T.equal(small("L", 4) .. line("L", 5) .. small("L", 6) .. line("L", 7), BLANK:rep(4), "nothing else before an entry (estimate)")
T.equal(small("L", 8), "     NAVAID INHIBIT     ", "NAVAID INHIBIT")
T.equal(line("L", 9), "----                ----", "its dashes")
T.equal(small("L", 10), "    VOR ONLY INHIBIT    ", "VOR ONLY INHIBIT")
T.equal(line("L", 11), "----                ----", "its dashes")
T.equal(line("L", 12), "-------------           ", "the dashes and")
T.equal(small("L", 12), "             VOR/DME NAV", "VOR/DME NAV (FMSPG p.171)")
T.equal(line("L", 13), "<INDEX          INHIBIT>", "<INDEX and INHIBIT>")

-- IDENT: a DME alone, ZZD (113.00, 200 ft, at 35.3 N 140.3 E)
enter("L", "ZZD", "L1")
T.equal(line("L", 3), lr("ZZD", "113.00"), "ZZD: its frequency (FCOM p.1356)")
T.equal(small("L", 2), lr(" IDENT", "FREQ"), "the FREQ header")
T.equal(line("L", 5), lr("N35`18.0", "E140`18.0"), "LATITUDE and LONGITUDE (to the tenth of a minute)")
T.equal(small("L", 4), " LATITUDE      LONGITUDE", "their headers")
T.equal(line("L", 7), lr("W7", "200  "), "MAG VAR there (the nearest VOR's, 7 W: estimate), ELEVATION")
T.equal(small("L", 6), lr(" MAG VAR", "ELEVATION"), "the MAG VAR and ELEVATION headers")
T.equal(small("L", 7), lr("", "FT"), "FT in small font (FCOM p.1355)")
T.equal(pad("L"), "", "the scratchpad emptied")

-- an identifier of two VORs, ZZV: SELECT DESIRED WPT, the nearest first
-- (FCOM p.1335; FMSPG p.175-176)
enter("L", "ZZV", "L1")
T.check(line("L", 1):find("SELECT DESIRED WPT"), "ZZV: SELECT DESIRED WPT: " .. line("L", 1))
T.check(line("L", 3):find("N35`12.0 E140`12.0"), "the nearer first (ZZ): " .. line("L", 3))
key("L", "ls_key/L1")
frames(0.6)
T.equal(line("L", 1), "      REF NAV DATA      ", "back to REF NAV DATA")
T.equal(line("L", 3), lr("ZZV", "115.00"), "ZZV, the nearer: 115.00")
T.equal(line("L", 7), lr("W7", "100  "), "its own variation, 7 W, and 100 ft")
T.equal(pad("L"), "", "the scratchpad emptied")

-- an NDB, a localizer, a waypoint, an airport
enter("L", "ZA", "L1")
T.equal(line("L", 3), lr("ZA", "350"), "ZA, an NDB: 350 (kHz: estimate)")
T.equal(line("L", 7), lr("W7", "0  "), "its variation there and elevation")
enter("L", "IZA", "L1")
T.equal(line("L", 3), lr("IZA", "109.50"), "IZA, a localizer: 109.50")
T.equal(line("L", 7), lr("W7", "100  "), "MAG VAR and ELEVATION")
enter("L", "BRAVO", "L1")
T.equal(line("L", 3), lr("BRAVO", ""), "BRAVO, a waypoint: no FREQ")
T.equal(small("L", 2), lr(" IDENT", ""), "nor its header")
T.equal(line("L", 5), lr("N36`00.0", "E140`30.0"), "its position")
T.equal(line("L", 7) .. small("L", 6) .. small("L", 7), BLANK:rep(3), "no MAG VAR or ELEVATION, nor their headers (FMSPG p.172)")
enter("L", "ZZAA", "L1")
T.equal(line("L", 3), lr("ZZAA", ""), "ZZAA, an airport")
T.equal(line("L", 5), lr("N35`00.0", "E140`00.0"), "its reference point")
T.equal(line("L", 7), lr("", "100  "), "its elevation, no MAG VAR (FMSPG p.172)")
T.equal(small("L", 6), lr("", "ELEVATION"), "ELEVATION only")

-- a runway: of the destination only (FMSPG p.171; ATA34_2 p.547)
enter("L", "RW16R", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "RW16R without a destination: NOT IN DATA BASE")
clear("L")
key("L", "func_key/fpln")
enter("L", "ZZBB", "L1")
enter("L", "ZZAA", "R1")
nav_data("L")
T.equal(line("L", 3), "-----                   ", "NAV DATA> again: the IDENT's dashes (FCOM p.1355)")
enter("L", "RW16R", "L1")
local len = math.floor(N.runway_length(fms.ns.B747_fmc_route.N.cifp(fms.ns.B747_fmc_route.db, "ZZAA"), "RW16R") + 0.5)
T.equal(line("L", 3), lr("RW16R", ""), "RW16R of the destination ZZAA")
T.equal(line("L", 5), lr("N35`00.6", "E140`00.3"), "its threshold")
T.equal(line("L", 7), lr(len .. "  ", "100  "), "LENGTH (" .. len .. " ft from the thresholds: estimate) and ELEVATION")
T.equal(small("L", 6), lr(" LENGTH", "ELEVATION"), "the LENGTH header (FCOM p.1356)")
T.equal(small("L", 7), lr(string.rep(" ", #tostring(len)) .. "FT", "FT"), "both in feet, FT small (estimate)")
enter("L", "RW09", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "RW09, the origin's: NOT IN DATA BASE")
clear("L")
enter("L", "QQQQ", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "an identifier not in the data: NOT IN DATA BASE")
clear("L")
enter("L", "N35E140", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "anything else: NOT IN DATA BASE (ATA34_2 p.547)")
clear("L")
key("L", "key/del")
key("L", "ls_key/L1")
T.equal(pad("L"), "INVALID DELETE", "DELETE: not permitted (FMSPG p.171)")
clear("L")
T.equal(line("L", 3), lr("RW16R", ""), "RW16R kept")

-- NAVAID INHIBIT: VORs and DMEs (FCOM p.1356; FMSPG p.172)
local inh = fms.ns.B747_fmc_nav_inhibits()
enter("L", "ZZD", "L4")
T.equal(line("L", 9), lr("ZZD", "----"), "4L: ZZD, a DME")
enter("L", "ZA", "R4")
T.equal(pad("L"), "INVALID ENTRY", "an NDB: INVALID ENTRY (estimate)")
clear("L")
enter("L", "QQQ", "R4")
T.equal(pad("L"), "NOT IN DATA BASE", "not in the data: NOT IN DATA BASE")
clear("L")
enter("L", "ZZV", "R4")
T.check(line("L", 1):find("SELECT DESIRED WPT"), "ZZV, two VORs: SELECT DESIRED WPT")
key("L", "ls_key/L2")
frames(0.6)
T.equal(line("L", 9), lr("ZZD", "ZZV"), "4R: ZZV")
T.check(inh.navaid[1].ident == "ZZD" and inh.navaid[1].kind == "DME" and inh.navaid[2].region == "YY",
    "the FMCs' inhibits: ZZD, and the farther ZZV (YY) chosen")
enter("L", "ZZV", "L4")
key("L", "ls_key/L1")
frames(0.6)
T.check(line("L", 9) == lr("ZZV", "ZZV") and inh.navaid[1].region == "ZZ", "4L overwritten: ZZD back in use (FMSPG p.172)")
key("L", "key/del")
key("L", "ls_key/L4")
T.equal(line("L", 9), lr("----", "ZZV"), "DELETE: the inhibit removed (FCOM p.1356)")
T.equal(inh.navaid[1], nil, "gone from the inhibits")
key("L", "key/del")
key("L", "ls_key/L4")
T.equal(pad("L"), "INVALID DELETE", "DELETE on dashes: INVALID DELETE (estimate)")
clear("L")

-- VOR ONLY INHIBIT: VORs (FCOM p.1356; FMSPG p.173)
enter("L", "ZZD", "L5")
T.equal(pad("L"), "INVALID ENTRY", "a DME: INVALID ENTRY")
clear("L")
enter("L", "ZZV", "L5")
key("L", "ls_key/L1")
frames(0.6)
T.equal(line("L", 11), lr("ZZV", "----"), "5L: ZZV")

-- VOR/DME NAV (FCOM p.1357; FMSPG p.173-174)
key("L", "ls_key/R6")
T.equal(line("L", 13), "<INDEX           ENABLE>", "INHIBIT>: VOR/DME updating inhibited, ENABLE>")
T.equal(small("L", 11), "ALL                  ALL", "ALL in small font in 5L and 5R")
T.equal(line("L", 11), BLANK, "over the VOR ONLY entries")
T.check(inh.vordme and inh.vor[1] == nil, "the FMCs': VOR/DME inhibited, the VOR ONLY entries gone")
enter("L", "ZZV", "R5")
T.equal(pad("L"), "INVALID ENTRY", "VOR ONLY entries while ALL: INVALID ENTRY (estimate)")
clear("L")

-- the other CDU: the same inhibits (both FMCs'), its own IDENT
nav_data("R")
T.equal(line("R", 1), "      REF NAV DATA      ", "the right CDU's REF NAV DATA")
T.equal(line("R", 3), "-----                   ", "its own IDENT: dashes")
T.equal(line("R", 9), lr("----", "ZZV"), "the same NAVAID INHIBIT")
T.check(small("R", 11) == "ALL                  ALL" and line("R", 13):find("ENABLE>$"), "the same VOR/DME NAV")
key("R", "ls_key/R6")
T.equal(line("R", 13), "<INDEX          INHIBIT>", "ENABLE>: back to INHIBIT>")
T.equal(line("R", 11), "----                ----", "5L and 5R dashes (FMSPG p.174)")
T.check(not inh.vordme, "VOR/DME updating enabled")
frames(0.3)
T.equal(line("L", 11), "----                ----", "on the left CDU too")
T.equal(line("L", 3), lr("RW16R", ""), "the left CDU's IDENT kept")
key("L", "ls_key/L6")
T.check(line("L", 1):find("INIT/REF INDEX"), "<INDEX: the INIT/REF INDEX")

T.done()
