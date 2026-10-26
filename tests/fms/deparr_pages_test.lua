-- Run from the repository root with LuaJIT: luajit tests/fms/deparr_pages_test.lua
-- DEP/ARR INDEX, DEPARTURES and ARRIVALS on the FMC's route (6-1/6-2 step
-- 5d; notes/ATA-34-61-FMC.md §18) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), on the synthetic CIFP of ZZAA (the origin and the
-- destination here): the lists, a selection's <SEL> with the others gone,
-- the transitions, the route's legs from the procedures, <ACT> after EXEC,
-- the DEP ARR key's page (FCOM p.1299-1302, p.1400-1405).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("deparr_pages")
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

local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do rt:command(K .. "alphanum_key/" .. ch) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
-- the plan X-Plane gets: loaded once the route has stayed the same a second
local function xpfms() frames(1.2) return rt:get("xtlua/loadtoFMS") or "" end

-- a route: ZZAA to ZZAA (the synthetic data's procedures), DIRECT ALPHA,
-- DIRECT DELTA
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("DELTA", "R2")

-- the DEP ARR key without an active route: the INDEX (FCOM p.1299)
key("func_key/clb")
T.check(line(1):find("DEP/ARR INDEX"), "DEP/ARR INDEX: " .. line(1))
T.check(line(3):find("^<DEP    ZZAA"), "the origin's DEP: " .. line(3))
T.check(line(5):find("ZZAA") and line(5):find("ARR>$"), "the destination's ARR: " .. line(5))

-- DEPARTURES (FCOM p.1301-1302)
key("ls_key/L1")
T.check(line(1):find("ZZAA DEPARTURES"), "ZZAA DEPARTURES: " .. line(1))
T.equal(small(2), " SIDS    RTE 1   RUNWAYS", "the titles")
T.equal(line(3), "ZULU1                16R", "the SID, the runways")
T.equal(line(5), "                     34L", "")
key("ls_key/L1")
T.equal(line(3), "ZULU1<SEL>           16R", "ZULU1 selected: <SEL>")
T.check(small(4):find("^ TRANS"), "its transitions' title over the first one (FCOM p.1403): " .. small(4))
T.equal(line(5), "ALPHA                34L", "its transition ALPHA")
T.check(line(13):find("^<INDEX"), "an inactive route changes itself: INDEX at 6L (ERASE on a modification: FCOM p.1302)")
key("ls_key/R2")
T.equal(line(3), "ZULU1<SEL>      <SEL>34L", "the runway 34L: <SEL>, the others gone")
key("ls_key/L2")
T.equal(line(5), "ALPHA<SEL>              ", "the transition ALPHA")
key("ls_key/R6")
T.check(line(1):find("RTE 1"), "ROUTE>: the RTE page")
key("func_key/next_pg")
T.equal(line(3), "ZULU1.ALPHA        ALPHA", "the RTE page: ZULU1.ALPHA (FCOM p.1297)")
T.equal(line(5), "DIRECT             DELTA", "then DIRECT DELTA")
key("func_key/legs")
T.equal(line(3), "(600)              /600A", "LEGS: the heading to 600 ft (FCOM p.1249), its altitude")
T.check(small(2):find("^ 337` HDG"), "its heading 337 (FCOM p.1249: 180` HDG): " .. small(2))
T.equal(line(5), "(INTC)                  ", "the intercept")
T.equal(line(7), "ZZV            230/3000A", "ZZV at or above 3000, 230 kt (the SID's constraint)")
T.check(xpfms():find("DEPRWY RW34L") and xpfms():find("\n28 %(600%) DRCT 0%.000000 [^\n]*\n28 %(INTC%) DRCT 0%.000000 [^\n]*\n3 ZZV DRCT "),
    "X-Plane's flight plan: the runway, (600) and (INTC) where predicted (the ND's line: step 6d), ZZV")

-- ACTIVATE and EXEC; the DEP ARR key on the ground: DEPARTURES with <ACT>
key("func_key/fpln")
key("ls_key/R6")
key("key/execute")
key("func_key/clb")
T.check(line(1):find("ZZAA DEPARTURES"), "the DEP ARR key on the ground with an active route: DEPARTURES")
T.equal(line(3), "ZULU1<ACT>           16R", "all the options again, ZULU1 <ACT> (FCOM p.1302)")
T.equal(line(5), "                <ACT>34L", "34L <ACT>")

-- ARRIVALS (FCOM p.1401-1404)
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")
T.check(line(1):find("ZZAA ARRIVALS"), "ZZAA ARRIVALS: " .. line(1))
T.equal(small(2), " STARS   RTE 1  APPROACH", "the titles")
T.equal(line(3), "ALPHA1            ILS16R", "the STAR, the approach (I16R shown ILS16R)")
key("ls_key/L1")
T.equal(line(3), "ALPHA1<SEL>       ILS16R", "ALPHA1: <SEL>")
T.check(line(13):find("^<ERASE"), "a modification on the active route: ERASE")
key("ls_key/L2")
T.equal(line(5), "DELTA<SEL>              ", "its transition DELTA")
key("ls_key/R1")
T.equal(line(3), "ALPHA1<SEL>  <SEL>ILS16R", "ILS16R: <SEL>")
T.check(small(4):find("TRANS $"), "the approach's transitions' title: " .. small(4))
T.equal(line(5), "DELTA<SEL>           ZZV", "its transition ZZV")
key("ls_key/R2")
T.equal(line(5), "DELTA<SEL>      <SEL>ZZV", "ZZV selected")
key("key/execute")
key("func_key/legs")
key("func_key/next_pg")
T.check(line(1):find("ACT RTE 1 LEGS"), "executed: " .. line(1))
T.check(xpfms():find("DESRWY RW16R") and xpfms():find("\n28 RW16R DRCT "), "X-Plane's flight plan: the landing runway")
rt:set("sim/flightmodel/failures/onground_any", 0)
key("func_key/clb")
T.check(line(1):find("ZZAA ARRIVALS"), "the DEP ARR key in the air: ARRIVALS")
T.equal(line(3), "ALPHA1<ACT>  <ACT>ILS16R", "<ACT>")

T.done()
