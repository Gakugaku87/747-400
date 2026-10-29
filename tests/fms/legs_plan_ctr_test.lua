-- Run from the repository root with LuaJIT: luajit tests/fms/legs_plan_ctr_test.lua
-- The LEGS pages' PLAN centre (6-1/6-2; notes/ATA-34-61-FMC.md §42; FCOM
-- p.1333 items 9-10, p.1039; FMSPG p.124) in the FMS module as XTLua runs
-- it (tests/lib/xtlua.lua): with the CDU's side ND in PLN, <CTR> beside the
-- waypoint PLAN is centred on and STEP> at 6R for ACTIVATE (MAP CTR small at
-- the separator's end), the other CDU as it was; STEP, NEXT and PREV PAGE
-- and the LEGS key move the centre; a direct-to's INTC CRS stays; the
-- centre through a modification and the active waypoint's sequencing; and
-- X-Plane's displayed waypoint (the FMS bridge's laminar/B747/fms/xp/
-- displayed, from 1) the centre's row in the plan. The test plays X-Plane
-- and the plugin.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("legs_plan_ctr")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["xtlua/fms"] = "string",
    ["laminar/B747/fms/xp/plan"] = "string", ["laminar/B747/fms/xp/current"] = "number",
    ["laminar/B747/fms/xp/displayed"] = "number", ["laminar/B747/fms/xp/bridge"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:set("laminar/B747/fms/xp/bridge", 1)
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
local CAPT, FO = "laminar/B747/nd/mode/capt/sel_dial_pos", "laminar/B747/nd/mode/fo/sel_dial_pos"
local MAP, PLN = 2, 3
rt:set(CAPT, MAP)
rt:set(FO, MAP)
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
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function ctr(name) return lr(name .. string.rep(" ", 8 - #name) .. "<CTR>", "") end
local function mode(dref, v) rt:set(dref, v) frames(0.3) end
local DISP = "laminar/B747/fms/xp/displayed"
local function shown() return rt:get(DISP) or 0 end
local CUR = "laminar/B747/autopilot/ap_monitor/fmscurrentIndex"
local XCUR = "laminar/B747/fms/xp/current"
local function loaded() frames(1.2) end
local function bridged() return rt:get("laminar/B747/fms/xp/plan") or "" end
local function plan() return (bridged():gsub("^CURRENT %d+\n", "")) end
local function rows()
    local out = {}
    for ident in plan():gmatch("\n%d+ (%S+) ") do out[#out + 1] = ident end
    return table.concat(out, " ")
end
-- X-Plane after the plugin's load: xtlua/fms with entry `active` current
local function xplane(active)
    local out, k = {}, 0
    for t, ident, alt, lat, lon in plan():gmatch("\n(%d+) (%S+) %S+ (%S+) (%S+) (%S+)") do
        k = k + 1
        out[k] = string.format('[0,%d,0,0,%s,%s,"%s","%s",%s,%s]', t == "1" and 1 or 2048, lat, lon, ident, ident,
            alt, tostring(k == active))
    end
    rt:set("xtlua/fms", "[" .. table.concat(out, ",") .. "]")
    rt:set(XCUR, active)
    frames(0.2)
end

-- the route: ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL, then on LEGS DELTA,
-- N37E141 and ZZD: two pages
key("L", "func_key/fpln")
enter("L", "ZZAA", "L1")
enter("L", "ZZBB", "R1")
enter("L", "16R", "L2")
key("L", "func_key/next_pg")
enter("L", "ALPHA", "R1")
key("L", "ls_key/L1")             -- SELECT DESIRED WPT: the nearer ALPHA
enter("L", "Z1", "L2")
enter("L", "CHARL", "R2")
key("L", "func_key/legs")
enter("L", "DELTA", "L4")
enter("L", "N3700.0E14100.0", "L5")
key("L", "func_key/next_pg")
enter("L", "ZZD", "L1")
key("L", "func_key/prev_pg")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO CHARL DELTA N37E141 ZZD ZZBB", "the plan: leg i the row i + 2")
xplane(1)

-- no ND in PLN: the page as before, X-Plane's displayed waypoint left alone
T.equal(line("L", 3), lr("ALPHA", ""), "MAP: no <CTR>")
T.equal(line("L", 13), lr("<RTE 2 LEGS", "ACTIVATE>"), "MAP: ACTIVATE> (FCOM p.1332; FMSPG p.124)")
T.equal(small("L", 12), string.rep(" ", 24), "no MAP CTR")
T.equal(shown(), 0, "X-Plane's displayed waypoint not written")

-- the F/O's ND in PLN with no LEGS page up: the active route's first
-- waypoint the centre (estimate)
mode(FO, PLN)
T.equal(shown(), 3, "F/O's PLN, the right CDU on its MENU: ALPHA (row 3) X-Plane's displayed waypoint")
mode(FO, MAP)

-- the captain's ND to PLN with the left CDU on LEGS page 1
key("L", "func_key/next_pg")
mode(CAPT, PLN)
T.equal(line("L", 3), ctr("ZZD"), "PLN selected on page 2: its first waypoint ZZD <CTR> (estimate): " .. line("L", 3))
T.equal(shown(), 8, "ZZD's row 8 displayed")
key("L", "func_key/prev_pg")
T.equal(line("L", 3), ctr("ALPHA"), "PREV PAGE: page 1's first waypoint ALPHA <CTR> (FMSPG p.124; FCOM p.1330's figure: <CTR> at the 9th place)")
T.equal(line("L", 13), lr("<RTE 2 LEGS", "STEP>"), "STEP> for ACTIVATE (FCOM p.1333 item 10): " .. line("L", 13))
T.equal(line("L", 12), "-----------------       ", "the separator to the 17th place")
T.equal(small("L", 12), "                 MAP CTR", "MAP CTR small at its end (FCOM p.1330's figure)")
T.equal(shown(), 3, "ALPHA's row 3 displayed")
key("R", "func_key/legs")
T.equal(line("R", 3), lr("ALPHA", ""), "the right CDU (the F/O's ND in MAP): no <CTR>")
T.equal(line("R", 13), lr("<RTE 2 LEGS", "ACTIVATE>"), "and ACTIVATE>")

-- STEP: the next waypoint, the page following it
key("L", "ls_key/R6")
T.equal(line("L", 3), lr("ALPHA", ""), "STEP: <CTR> off ALPHA")
T.equal(line("L", 5), ctr("BRAVO"), "onto BRAVO (FCOM p.1333 item 10)")
T.equal(shown(), 4, "BRAVO's row 4 displayed: the ND recentres")
T.check(line("L", 1):find("^%s+RTE 1 LEGS%s+$"), "the route not activated by 6R: " .. line("L", 1))
T.equal(line("R", 13), lr("<RTE 2 LEGS", "ACTIVATE>"), "the right CDU's ACTIVATE> as it was")
key("L", "ls_key/R6")
key("L", "ls_key/R6")
key("L", "ls_key/R6")
T.equal(line("L", 11), ctr("N37E141"), "STEP three times: N37E141")
T.equal(shown(), 7, "row 7")
key("L", "ls_key/R6")
T.equal(small("L", 1), "                    2/2 ", "STEP past the page's last: page 2 follows (estimate)")
T.equal(line("L", 3), ctr("ZZD"), "ZZD")
T.equal(shown(), 8, "row 8")
key("L", "ls_key/R6")
T.equal(line("L", 3), ctr("ZZD"), "STEP on the last waypoint: no change (estimate)")
T.equal(shown(), 8, "row 8 still")

-- NEXT PAGE and the LEGS key: the page's first waypoint (FMSPG p.124)
key("L", "func_key/next_pg")
T.equal(small("L", 1), "                    1/2 ", "NEXT on the last page: page 1")
T.equal(line("L", 3), ctr("ALPHA"), "its first waypoint ALPHA")
T.equal(shown(), 3, "row 3")
key("L", "func_key/next_pg")
key("L", "func_key/legs")
T.equal(small("L", 1), "                    1/2 ", "the LEGS key: page 1")
T.equal(line("L", 3), ctr("ALPHA"), "ALPHA the centre")

-- the constraints with <CTR>
enter("L", "250/10000A", "R2")
key("L", "ls_key/R6")
T.equal(line("L", 5), "BRAVO   <CTR> 250/10000A", "<CTR> with BRAVO's constraint (FMSPG p.124's figure: \"VECTORS <CTR> 150/  530A\")")
enter("L", "220A240B", "R3")
key("L", "ls_key/R6")
T.equal(line("L", 7), "CHARL      /FL220AFL240B", "a block's constraint leaves no room: no <CTR> (estimate)")
loaded()
T.equal(shown(), 5, "CHARL's row 5 displayed once the new plan is loaded")

-- the F/O's ND in PLN too: one centre for both (X-Plane's FMS shows one
-- entry: a difference)
mode(FO, PLN)
T.equal(line("R", 3), ctr("ALPHA"), "the F/O's PLN with the right CDU on LEGS page 1: its first waypoint ALPHA (estimate)")
T.equal(line("L", 3), ctr("ALPHA"), "the left CDU's <CTR> with it")
T.equal(line("R", 13), lr("<RTE 2 LEGS", "STEP>"), "STEP> on the right CDU")
key("R", "ls_key/R6")
T.equal(line("R", 5), "BRAVO   <CTR> 250/10000A", "the right CDU's STEP: BRAVO")
T.equal(line("L", 5), "BRAVO   <CTR> 250/10000A", "the left CDU's <CTR> with it")
T.equal(shown(), 4, "row 4")
mode(CAPT, MAP)
T.equal(line("L", 5), "BRAVO         250/10000A", "the captain's ND in MAP: no <CTR> on the left CDU")
T.equal(line("L", 13), lr("<RTE 2 LEGS", "ACTIVATE>"), "ACTIVATE> again")
T.equal(small("L", 12), string.rep(" ", 24), "no MAP CTR")
T.equal(line("R", 5), "BRAVO   <CTR> 250/10000A", "the right CDU's as it was")
mode(FO, MAP)

-- airborne: the activation from the right CDU while the captain's ND is in
-- PLN (6R as each CDU shows it)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(CUR, 2)
mode(CAPT, PLN)
T.equal(line("L", 3), ctr("ALPHA"), "PLN again on page 1: ALPHA")
T.equal(line("L", 13), lr("<RTE 2 LEGS", "STEP>"), "the left CDU: STEP>")
key("R", "ls_key/R6")
key("R", "key/execute")
T.check(line("R", 1):find("ACT RTE 1 LEGS"), "the right CDU's ACTIVATE and EXEC: " .. line("R", 1))
T.equal(rt:get(XCUR), 3, "the plugin's current waypoint ALPHA")
xplane(3)
T.equal(line("L", 13), lr("<RTE 2 LEGS", "STEP>"), "the active route: STEP> for RTE DATA (FCOM p.1333 item 10)")
key("L", "ls_key/R6")
key("L", "ls_key/R6")
key("L", "ls_key/R6")
T.equal(line("L", 9), ctr("DELTA"), "STEP three times: DELTA")
T.equal(shown(), 6, "row 6")

-- DIRECT TO CHARL: INTC CRS stays at 6R, the centre in the modification
enter("L", "CHARL", "L1")
T.check(line("L", 1):find("MOD RTE 1 LEGS"), "MOD RTE 1 LEGS: " .. line("L", 1))
T.check(line("L", 13):find("^<ERASE.*`>$"), "INTC CRS with the route's course at 6R (estimate: before STEP): " .. line("L", 13))
T.equal(small("L", 12), "                INTC CRS", "INTC CRS small")
T.equal(line("L", 5), ctr("DELTA"), "DELTA in the modification, the second leg: <CTR>")
T.equal(shown(), 6, "X-Plane's plan the active route's: DELTA's row 6 still")
key("L", "ls_key/L6")
T.check(line("L", 1):find("ACT RTE 1 LEGS"), "ERASE: " .. line("L", 1))
T.equal(line("L", 9), ctr("DELTA"), "DELTA in the active route again")

-- the centre on the active waypoint, sequenced (step 6c): the next one
-- (estimate)
key("L", "func_key/legs")
T.equal(line("L", 3), ctr("ALPHA"), "the LEGS key: ALPHA, the active waypoint")
T.equal(shown(), 3, "row 3")
rt:set("sim/flightmodel/position/latitude", 35.5333)
rt:set("sim/flightmodel/position/longitude", 140.5)
rt:set("sim/flightmodel2/position/groundspeed", 128.6)
rt:set("sim/flightmodel/position/true_airspeed", 128.6)
frames(0.3)
T.equal(line("L", 3), "BRAVO   <CTR> 250/10000A", "ALPHA passed: BRAVO the active waypoint and the centre")
T.equal(shown(), 4, "the plan as it was (the passed legs stay): BRAVO's row 4")

T.done()
