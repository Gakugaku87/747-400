-- Run from the repository root with LuaJIT: luajit tests/fms/rte_pages_test.lua
-- RTE 1 on the FMC's route (6-1/6-2 step 5b; notes/ATA-34-61-FMC.md §18)
-- in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic navigation data in tests/fms/data/navdb: page 1's ORIGIN,
-- DEST and RUNWAY (FCOM p.1288-1289), the next pages' VIA and TO (FCOM
-- p.1296-1298), SELECT DESIRED WPT (FCOM p.1335), ACTIVATE and EXEC, MOD
-- and ERASE (FCOM p.1238, p.1290), the FMC's data for the other modules and
-- X-Plane's FMS fed from the route (xtlua/loadtoFMS).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("rte_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

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
local function fmsdata(k) return (rt:get("laminar/B747/fms/data"):match('"' .. k .. '":"([^"]*)"') or ""):gsub("%s+$", "") end
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

-- page 1
key("L", "func_key/fpln")
T.equal(onces("FMS/fpln"), 0, "the RTE key: the FMC's page, no X-Plane key (before: X-Plane's RTE page under it)")
T.check(line("L", 1):find("^%s+RTE 1%s+$"), "an inactive route: RTE 1 (FCOM p.1287): " .. line("L", 1))
T.equal(small("L", 1), "                    1/2 ", "page 1/2")
T.equal(line("L", 3), "****                ****", "ORIGIN and DEST boxes")
T.check(line("L", 13):find("ACTIVATE>$"), "ACTIVATE> (FCOM p.1290)")
enter("L", "ZZXX", "L1")
T.equal(pad("L"), "NOT IN DATA BASE", "ORIGIN ZZXX: NOT IN DATA BASE (FCOM p.1288)")
clear("L")
enter("L", "ZZAA", "L1")
T.equal(line("L", 3), "ZZAA                ****", "ORIGIN ZZAA")
T.equal(fmsdata("fltdep"), "ZZAA", "the FMC's data for the other modules")
T.equal(fmsdata("transalt"), "14000", "TRANS ALT from the origin (FCOM p.1329)")
T.equal(xpfms(), "", "no destination yet: nothing for X-Plane's FMS (it would show an error for a plan without one)")
enter("L", "ZZBB", "R1")
T.equal(line("L", 3), "ZZAA                ZZBB", "DEST ZZBB")
T.equal(fmsdata("fltdst"), "ZZBB", "fltdst")
T.check(xpfms():find("ADEP ZZAA") and xpfms():find("ADES ZZBB"), "with the destination X-Plane's FMS is fed from the route")
enter("L", "99", "L2")
T.equal(pad("L"), "NOT IN DATA BASE", "RUNWAY 99: not ZZAA's (FCOM p.1289)")
clear("L")
enter("L", "16R", "L2")
T.check(line("L", 5):find("^RW16R"), "RUNWAY RW16R: " .. line("L", 5))
T.equal(fmsdata("runway"), "RW16R", "the runway's data")
key("L", "ls_key/L1")
T.equal(pad("L"), "ZZAA", "ORIGIN with an empty scratchpad: copied into it (FMSPG p.82)")
clear("L")

-- page 2: VIA and TO
key("L", "func_key/next_pg")
T.equal(small("L", 1), "                    2/2 ", "page 2/2")
T.equal(small("L", 2), " VIA                  TO", "the titles")
T.equal(line("L", 3), "-----              -----", "dashes after the end (FCOM p.1297-1298)")
enter("L", "ZZD", "R2")
T.equal(pad("L"), "INVALID ENTRY", "TO on a line after the dashes: INVALID ENTRY")
clear("L")
enter("L", "ALPHA", "R1")
T.check(line("L", 1):find("SELECT DESIRED WPT"), "ALPHA in two places: SELECT DESIRED WPT (FCOM p.1335): " .. line("L", 1))
T.check(small("L", 2):find("ALPHA"), "the first: " .. small("L", 2))
T.check(line("L", 3):find("N35`30%.0 E140`30%.0"), "the nearer one first (ZZ, near the origin): " .. line("L", 3))
T.check(line("L", 5):find("N10`30%.0"), "then the other: " .. line("L", 5))
key("L", "ls_key/L1")
T.check(line("L", 1):find("RTE 1"), "the selection back to the RTE page: " .. line("L", 1))
T.equal(line("L", 3), "DIRECT             ALPHA", "DIRECT ALPHA (FCOM p.1297)")
T.equal(line("L", 5), "-----              -----", "the dashes")
enter("L", "Z1", "L2")
T.equal(line("L", 5), "Z1                 *****", "VIA Z1: boxes for its TO")
enter("L", "CHARL", "R2")
T.equal(line("L", 5), "Z1                 CHARL", "Z1 to CHARL")
key("L", "ls_key/L2")
T.equal(pad("L"), "Z1", "an airway copied into the scratchpad (FMSPG p.82)")
clear("L")
T.check(xpfms():find("\n11 BRAVO Z1 "), "X-Plane's FMS: Z1's points")
T.check(xpfms():find("\n1 ZZBB ADES "), "and the destination")

-- ACTIVATE and EXEC, MOD and ERASE
key("L", "ls_key/R6")
T.check(line("L", 1):find("^%s+RTE 1%s+$"), "ACTIVATE: not active until EXEC")
T.check(line("L", 13):find("ACTIVATE>$"), "the ACTIVATE prompt until EXEC (FCOM p.1290)")
key("L", "key/execute")
T.check(line("L", 1):find("ACT RTE 1"), "EXEC: ACT RTE 1 (FCOM p.1290): " .. line("L", 1))
T.check(line("L", 13):find("PERF INIT>$"), "6R PERF INIT> while the performance data are incomplete (FCOM p.1290)")
enter("L", "DELTA", "R3")
T.check(line("L", 1):find("MOD RTE 1"), "a change on the active route: MOD RTE 1 (FCOM p.1238): " .. line("L", 1))
T.check(line("L", 13):find("^<ERASE"), "6L ERASE")
T.check(not xpfms():find("DELTA"), "X-Plane's FMS keeps the active route until EXEC")
key("L", "ls_key/L6")
T.check(line("L", 1):find("ACT RTE 1"), "ERASE: the active route back")
T.equal(line("L", 7), "-----              -----", "without DELTA")
enter("L", "DELTA", "R3")
key("L", "key/execute")
T.check(line("L", 1):find("ACT RTE 1"), "EXEC the modification")
T.equal(line("L", 7), "DIRECT             DELTA", "DIRECT DELTA")
T.check(xpfms():find("\n11 DELTA DRCT "), "X-Plane's FMS: the active route with DELTA")
key("R", "func_key/fpln")
key("R", "func_key/next_pg")
T.equal(line("R", 7), "DIRECT             DELTA", "the right CDU shows the same route")

-- 6R after the activation: PERF INIT, then TAKEOFF (FCOM p.1290)
key("L", "ls_key/R6")
T.check(line("L", 1):find("PERF INIT"), "PERF INIT>: the PERF INIT page: " .. line("L", 1))
enter("L", "220", "L3")
enter("L", "12.5", "L4")
enter("L", "120", "L5")
enter("L", "FL370", "R1")
rt:set("laminar/B747/irs/set_pos", 0)
key("L", "func_key/fpln")
T.check(line("L", 13):find("TAKEOFF>$"), "the performance data complete: 6R TAKEOFF>: " .. line("L", 13))
key("L", "ls_key/R6")
T.check(line("L", 1):find("TAKEOFF REF"), "TAKEOFF>: TAKEOFF REF: " .. line("L", 1))
T.check(line("L", 13):find("THRUST LIM>$"), "the route activated and PERF INIT complete: PRE-FLT done: " .. line("L", 13))
T.check(line("L", 11):find("RW16R %-%-00M"), "POS SHIFT: RTE 1's runway (FCOM p.1321): " .. line("L", 11))
-- a prompt to RTE (FMC COMM's L1) presses no X-Plane key either
key("L", "func_key/hold")
key("L", "ls_key/L1")
T.check(line("L", 1):find("RTE 1"), "FMC COMM's L1: the RTE page: " .. line("L", 1))
T.equal(onces("FMS/fpln"), 0, "no X-Plane RTE key (before: pressed with the prompt)")

-- OFFSET in the air (step 7d; FCOM p.1298; FMSPG p.155-156)
local st = rt.modules[1].ns.B747_fmc_route
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(0.5)
key("L", "func_key/fpln")
T.check(line("L", 8) == string.rep("-", 24) and line("L", 12) == string.rep(" ", 24), "in the air on page 1: the dashes at line 8 (FCOM p.1293's figure: step 7e4), none over 6L, and")
T.equal(small("L", 12), "                  OFFSET", "OFFSET at 6R (FCOM p.1298)")
T.check(line("L", 13):find("%-%-%-$"), "no offset: dashes: " .. line("L", 13))
enter("L", "R20", "R6")
T.check(line("L", 1):find("MOD RTE 1") and line("L", 13):find("R20$"), "R20: MOD RTE 1: " .. line("L", 13))
key("L", "key/execute")
T.check(line("L", 1):find("ACT RTE 1") and st.rte.offset == 20, "EXEC: the offset active")
key("L", "func_key/next_pg")
T.check(line("L", 13):find("R20$") and small("L", 12):find("OFFSET$") and line("L", 12) == "------------------      ", "on the next page too, at the dashes' end (FCOM p.1298's figure)")
enter("L", "X5", "R6")
T.equal(pad("L"), "INVALID ENTRY", "X5: INVALID ENTRY")
clear("L")
enter("L", "L0", "R6")
key("L", "key/execute")
T.check(line("L", 13):find("%-%-%-$") and st.rte.offset == nil, "L0: cancelled (FMSPG p.156)")
key("L", "key/del")
key("L", "ls_key/R6")
T.equal(pad("L"), "INVALID DELETE", "DELETE with none: INVALID DELETE")
clear("L")
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.5)
key("L", "func_key/prev_pg")
T.check(line("L", 13):find("THRUST LIM>$") or line("L", 13):find("TAKEOFF>$") or not line("L", 13):find("%-%-%-$"),
    "on the ground: no OFFSET: " .. line("L", 13))

T.done()
