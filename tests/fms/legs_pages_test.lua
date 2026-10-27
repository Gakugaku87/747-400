-- Run from the repository root with LuaJIT: luajit tests/fms/legs_pages_test.lua
-- RTE 1 LEGS on the FMC's route (6-1/6-2 step 5c; notes/ATA-34-61-FMC.md
-- §18) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic navigation data in tests/fms/data/navdb: the waypoints with
-- their magnetic courses and distances, the constraints entered and
-- deleted (FCOM p.1330-1332; FMSPG p.125-128), a waypoint inserted with a
-- ROUTE DISCONTINUITY and the discontinuity closed (FMSPG p.91), DELETE,
-- ACTIVATE and EXEC, DIRECT TO and INTC CRS (FMSPG p.141-144).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("legs_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
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

local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k, held)
    rt:command(K .. k, held)
    frames(0.3)
end
local function type_in(text)
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(text, lsk) type_in(text) key("ls_key/" .. lsk) end
local function clear() key("key/clear") key("key/clear", 1.2) end
-- the plan X-Plane gets: loaded once the route has stayed the same a second
local function xpfms() frames(1.2) return rt:get("xtlua/loadtoFMS") or "" end
-- X-Plane CDU key presses (its commands end with FMS/<key>)
local function onces(suffix)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.phase == "once" and tostring(e.name):find(suffix .. "$") then n = n + 1 end
    end
    return n
end

-- a route on the RTE pages: ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("Z1", "L2")
enter("CHARL", "R2")
T.equal(line(5), "Z1                 CHARL", "the route: DIRECT ALPHA, Z1 CHARL")

-- the LEGS page
local before = onces("FMS/legs")
key("func_key/legs")
T.equal(onces("FMS/legs") - before, 0, "the LEGS key: the FMC's page, no X-Plane key (before: X-Plane's LEGS page under it)")
T.check(line(1):find("^%s+RTE 1 LEGS%s+$"), "an inactive route: RTE 1 LEGS (FCOM p.1331): " .. line(1))
T.equal(small(1), "                    1/1 ", "page 1/1")
T.equal(line(3), "ALPHA                   ", "ALPHA")
T.equal(line(5), "BRAVO                   ", "Z1's BRAVO")
T.equal(line(7), "CHARL                   ", "CHARL")
T.equal(line(9), "-----                   ", "dashes after the end (FCOM p.1331)")
-- the courses: magnetic, the nearest VOR's variation (ZZV: 7 degrees west)
local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local rw = N.cifp(db, "ZZAA").runways.RW16R
local c, d = R.course(rw.lat, rw.lon, 35.5, 140.5)
local want = string.format(" %03d`   %6s", math.floor((c + 7) % 360 + 0.5), string.format("%dNM", math.floor(d + 0.5)))
T.equal(small(2), want .. string.rep(" ", 10), "ALPHA's course (magnetic: true + 7) and distance from RW16R (FCOM p.1331-1332)")
T.equal(small(4), " 007`     30NM          ", "BRAVO: north along 140.5 E, magnetic 007, 30 NM, the 14th place its last (step 7e2)")
T.check(line(13):find("ACTIVATE>$"), "ACTIVATE> (FCOM p.1332)")

-- constraints
enter("250/10000A", "R2")
T.equal(line(5), "BRAVO         250/10000A", "250/10000A at BRAVO (FCOM p.1332)")
enter("250/", "R3")
T.equal(pad(), "INVALID ENTRY", "a speed alone without an altitude constraint (FMSPG p.127)")
clear()
enter("250", "R3")
T.equal(line(7), "CHARL" .. string.rep(" ", 13) .. "/FL250", "250 without a slash: FL250 (FCOM p.1332: XXX)")
enter("240/", "R3")
T.equal(line(7), "CHARL          240/FL250", "a speed alone over the altitude constraint")
enter("220A240B", "R3")
T.equal(line(7), "CHARL      /FL220AFL240B", "a block at CHARL, the old speed dropped (FMSPG p.128)")
key("ls_key/R2")
T.equal(pad(), "250/10000A", "a constraint copied into the scratchpad")
clear()
key("key/del")
key("ls_key/R2")
T.equal(line(5), "BRAVO                   ", "DELETE: the speed and the altitude gone (FMSPG p.128)")
key("key/del")
key("ls_key/R2")
T.equal(pad(), "INVALID DELETE", "DELETE where there is none")
clear()

-- a waypoint inserted, the discontinuity closed, DELETE
enter("ZZD", "L3")
T.equal(line(7), "ZZD                     ", "ZZD over CHARL: inserted")
T.equal(line(9), "*****                   ", "a ROUTE DISCONTINUITY after it: boxes (FMSPG p.91)")
T.equal(small(8), " THEN                   ", "THEN over the boxes (FCOM p.1333)")
T.equal(small(10), "-- ROUTE DISCONTINUITY -", "the title over the waypoint after it")
T.equal(line(11), "CHARL      /FL220AFL240B", "CHARL with its constraint")
enter("CHARL", "L4")
T.equal(line(9), "CHARL      /FL220AFL240B", "CHARL over the boxes: the discontinuity closed")
key("key/del")
key("ls_key/L3")
T.equal(line(7), "CHARL      /FL220AFL240B", "DELETE ZZD: BRAVO to CHARL (estimate)")
key("func_key/fpln")
key("func_key/next_pg")
T.equal(line(5), "Z1                 BRAVO", "the RTE page follows: Z1 to BRAVO")
T.equal(line(7), "DIRECT             CHARL", "DIRECT CHARL")
key("func_key/legs")

-- ACTIVATE, EXEC, DIRECT TO and INTC CRS
key("ls_key/R6")
key("key/execute")
T.check(line(1):find("ACT RTE 1 LEGS"), "ACT RTE 1 LEGS: " .. line(1))
enter("CHARL", "L1")
T.check(line(1):find("MOD RTE 1 LEGS"), "DIRECT TO CHARL: MOD RTE 1 LEGS (FMSPG p.142): " .. line(1))
T.check(rt:get("laminar/B747/fms/exec_light_pilot") == 1 and rt:get("laminar/B747/fms/exec_light_copilot") == 1,
    "the EXEC lights on with a modification (FCOM p.1238)")
T.equal(line(3), "CHARL      /FL220AFL240B", "CHARL the active waypoint")
T.check(line(13):find("^<ERASE"), "ERASE at 6L")
T.equal(small(12), "                INTC CRS", "INTC CRS (FMSPG p.144)")
T.check(line(13):find("007`>$"), "the route's course into CHARL with its caret: " .. line(13))
key("ls_key/R6")
T.check(small(2):find("^ 007`"), "INTC CRS 007: the course into CHARL: " .. small(2))
enter("090", "R6")
T.check(small(2):find("^ 090`"), "INTC CRS 090: " .. small(2))
T.check(not xpfms():find("NUMENR 4"), "X-Plane's FMS keeps the active route until EXEC")
key("key/execute")
T.check(line(1):find("ACT RTE 1 LEGS"), "EXEC: " .. line(1))
T.check(rt:get("laminar/B747/fms/exec_light_pilot") == 0 and rt:get("laminar/B747/fms/exec_light_copilot") == 0,
    "and off after the EXEC")
T.check(xpfms():find("NUMENR 5\n1 ZZAA ADEP[^\n]*\n28 RW16R DRCT [^\n]*\n28 DTOPOS DRCT [^\n]*\n11 CHARL DRCT "),
    "X-Plane's FMS: ZZAA, its runway, the direct-to's start DTOPOS (step 5e), CHARL, ZZBB")
T.check(xpfms():find("\n11 CHARL DRCT "), "CHARL direct")

-- ABEAM PTS (step 7e2; FCOM p.1333-1334; FMSPG p.136-139): DELTA after
-- CHARL, DIRECT TO DELTA from the airplane at 35 N 140 E
enter("DELTA", "L2")
key("key/execute")
enter("DELTA", "L1")
T.check(line(1):find("MOD RTE 1 LEGS"), "DIRECT TO DELTA: " .. line(1))
T.equal(line(8), string.rep(" ", 14) .. "----------", "dashes over 4R (FCOM p.1333)")
T.equal(line(9), string.rep(" ", 14) .. "ABEAM PTS>", "ABEAM PTS> at 4R")
T.equal(small(12), "                INTC CRS", "with INTC CRS")
key("ls_key/R4")
T.equal(line(3):sub(1, 5), "CHA01", "CHARL's abeam point CHA01 the active waypoint (FMSPG p.136)")
T.equal(line(5):sub(1, 5), "DELTA", "then DELTA")
T.equal(small(8), string.rep(" ", 15) .. "ABEAM PTS", "ABEAM PTS (FMSPG p.138)")
T.equal(line(9), string.rep(" ", 14) .. "  SELECTED", "SELECTED")
T.check(small(12) == string.rep(" ", 24) and not line(13):find("`"), "no INTC CRS (FMSPG p.139's figure)")
T.check(line(13):find("^<ERASE"), "ERASE")
key("key/execute")
T.check(line(1):find("ACT RTE 1 LEGS") and line(3):find("^CHA01"), "EXEC: CHA01 active")
T.equal(line(9), string.rep(" ", 24), "the prompt gone")
T.check(xpfms():find("\n28 DTOPOS DRCT [^\n]*\n28 CHA01 DRCT [^\n]*\n11 DELTA DRCT "), "X-Plane's FMS: DTOPOS, CHA01, DELTA")
enter("DELTA", "L1")
enter("FL200", "R1")
T.check(not line(9):find("ABEAM"), "another change: the prompt gone (FCOM p.1334): " .. line(9))
key("ls_key/L6")

-- the waypoints the crew defines (step 7e3a; FCOM p.1245, p.1249-1250)
enter("N3700.0E14100.0", "L3")
T.equal(line(7), "N37E141                 ", "N3700.0E14100.0 after DELTA: N37E141")
enter("ALPHA097/10", "L4")
T.check(line(1):find("SELECT DESIRED WPT"), "ALPHA097/10: two ALPHAs: SELECT DESIRED WPT for the place")
key("ls_key/L1")
frames(0.6)
T.equal(line(9), "ALP02                   ", "the nearer: ALP02 (CHA01 has 01)")
enter("ALP02", "L5")
T.equal(pad(), "", "ALP02 by its name")
T.equal(line(11), "ALP02                   ", "the same point again")
enter("XYZQQ090/10", "L5")
T.equal(pad(), "NOT IN DATA BASE", "a place not in the data: NOT IN DATA BASE")
clear()
enter("ALPHA097/BRAVO007", "L5")
key("ls_key/L1")
frames(0.6)
T.equal(pad(), "INVALID ENTRY", "radials that do not meet: INVALID ENTRY")
clear()
key("ls_key/L6")

T.done()
