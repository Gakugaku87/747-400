-- Run from the repository root with LuaJIT: luajit tests/fms/rte2_pages_test.lua
-- RTE 2 and RTE COPY (6-1/6-2 step 7e4; notes/ATA-34-61-FMC.md §40) in the
-- FMS module as XTLua runs it (tests/lib/xtlua.lua), on the synthetic
-- navigation data in tests/fms/data/navdb: <RTE 2 and <RTE 1 on the RTE
-- pages (FCOM p.1289, p.1296), RTE 2's own entries, <RTE 2 LEGS (FCOM
-- p.1330), RTE COPY on the active route's page 1 (FCOM p.1289) and on the
-- DIRECT TO modification (FCOM p.1334; FMSPG p.134-136), RTE 2 activated
-- (FCOM p.1290): the active route then, X-Plane's flight plan from it, the
-- RTE and LEGS keys to it; RTE 2's place/bearing/distance numbers 51-99
-- (FCOM p.1250); the DEP/ARR INDEX's RTE 2 lines (FCOM p.1299-1300).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("rte2_pages")
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
local function xpfms() frames(1.2) return rt:get("xtlua/loadtoFMS") or "" end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function idents(st)
    local out = {}
    for _, l in ipairs(st.rte.legs) do out[#out + 1] = l.fix and l.fix.ident or "DISC" end
    return table.concat(out, " ")
end
local function route(n) return fms.ns.B747_fmc_route_num(n) end

-- RTE 1, inactive: ZZAA RW16R, ALPHA, Z1 to CHARL, ZZBB
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
T.equal(line(8), string.rep("-", 24), "page 1: the dashes at line 8 (FCOM p.1293's figure)")
T.equal(line(13), lr("<RTE 2", "ACTIVATE>"), "<RTE 2 and ACTIVATE> (FCOM p.1289)")
T.equal(line(11), string.rep(" ", 24), "no RTE COPY on the inactive route (FCOM p.1289: active or modified)")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("Z1", "L2")
enter("CHARL", "R2")
T.equal(line(12), string.rep("-", 24), "page 2: the dashes over 6L (FCOM p.1296's figure)")
T.equal(line(13), lr("<RTE 2", "ACTIVATE>"), "and <RTE 2")

-- RTE 2: its own pages and entries
key("ls_key/L6")
T.check(line(1):find("^%s+RTE 2%s+$"), "<RTE 2: RTE 2 (FCOM p.1289): " .. line(1))
T.equal(line(3), "****                ****", "its ORIGIN and DEST boxes")
T.equal(line(13), lr("<RTE 1", "ACTIVATE>"), "<RTE 1 and ACTIVATE>")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("func_key/next_pg")
enter("DELTA", "R1")
T.equal(line(3), lr("DIRECT", "DELTA"), "RTE 2: DIRECT DELTA")
T.check(idents(route(2)) == "DELTA" and idents(route(1)) == "ALPHA BRAVO CHARL", "RTE 1 as it was")
key("func_key/legs")
T.check(line(1):find("^%s+RTE 1 LEGS%s+$"), "the LEGS key: RTE 1 LEGS, none active: " .. line(1))
T.equal(line(13), lr("<RTE 2 LEGS", "ACTIVATE>"), "<RTE 2 LEGS (FCOM p.1330's figure)")
key("ls_key/L6")
T.check(line(1):find("RTE 2 LEGS") and line(3):find("^DELTA"), "RTE 2 LEGS: DELTA")
T.equal(line(13), lr("<RTE 1 LEGS", "ACTIVATE>"), "<RTE 1 LEGS")
key("ls_key/L6")

-- RTE 1 activated; RTE COPY on its page 1 (FCOM p.1289)
key("ls_key/R6")
key("key/execute")
T.check(route(1).active and fms.ns.B747_fmc_route.num == 1, "RTE 1 active")
key("func_key/fpln")
T.check(line(1):find("ACT RTE 1"), "the RTE key: ACT RTE 1")
T.equal(line(11), "<RTE COPY               ", "<RTE COPY at 5L (FCOM p.1289)")
key("ls_key/L5")
T.equal(line(11), "COMPLETE                ", "COMPLETE")
T.equal(small(10), " RTE COPY               ", "under RTE COPY (estimate)")
T.equal(idents(route(2)), "ALPHA BRAVO CHARL", "RTE 2 a copy of the active route, DELTA gone (FMSPG p.134)")
T.check(not route(2).active and route(2).rte.origin.ident == "ZZAA", "inactive, with its origin")

-- RTE 2 changed on its own and activated (FCOM p.1290)
key("ls_key/L6")
T.check(line(1):find("^%s+RTE 2%s+$"), "RTE 2: no MOD on the inactive route: " .. line(1))
key("func_key/next_pg")
enter("DELTA", "R3")
T.check(idents(route(2)) == "ALPHA BRAVO CHARL DELTA" and idents(route(1)) == "ALPHA BRAVO CHARL", "DELTA on RTE 2 alone")
key("ls_key/R6")
T.check(rt:get("laminar/B747/fms/exec_light_pilot") == 1, "ACTIVATE: the EXEC light (FCOM p.1238)")
key("key/execute")
T.check(fms.ns.B747_fmc_route.num == 2 and fms.ns.B747_fmc_route.active and not route(1).active,
    "EXEC: RTE 2 the active route, RTE 1 inactive")
T.check(line(1):find("ACT RTE 2"), "ACT RTE 2: " .. line(1))
T.check(rt:get("laminar/B747/fms/exec_light_pilot") == 0, "the EXEC light off")
T.check(xpfms():find("\n11 DELTA DRCT "), "X-Plane's flight plan: RTE 2's, with DELTA")
key("ls_key/L6")
T.check(line(1):find("^%s+RTE 1%s+$") and line(13):find("ACTIVATE>$"), "RTE 1 inactive: ACTIVATE>")
key("func_key/fpln")
T.check(line(1):find("ACT RTE 2"), "the RTE key: the active route's pages (FCOM p.1287)")
key("func_key/legs")
T.check(line(1):find("ACT RTE 2 LEGS"), "the LEGS key: ACT RTE 2 LEGS")

-- the DIRECT TO modification's RTE COPY> (FCOM p.1334; FMSPG p.135-136)
enter("CHARL", "L1")
T.check(line(1):find("MOD RTE 2 LEGS"), "DIRECT TO CHARL: MOD RTE 2 LEGS")
T.equal(line(11), string.rep(" ", 15) .. "RTE COPY>", "RTE COPY> at 5R")
T.check(line(9):find("ABEAM PTS>$"), "with ABEAM PTS>")
key("ls_key/R5")
T.equal(line(11), string.rep(" ", 16) .. "COMPLETE", "COMPLETE (FMSPG p.136's figure)")
T.equal(small(10):sub(17), "RTE COPY", "under RTE COPY")
T.equal(idents(route(1)), "ALPHA BRAVO CHARL DELTA", "RTE 1 a copy of the active route unmodified (FCOM p.1334)")
T.check(line(9):find("ABEAM PTS>$"), "ABEAM PTS> still offered")
key("ls_key/L6")

-- RTE 2's place/bearing/distance waypoints 51-99 (FCOM p.1250)
enter("ALPHA097/10", "L5")
key("ls_key/L1")
frames(0.6)
T.check(line(11):find("^ALP51"), "ALPHA097/10 on RTE 2: ALP51: " .. line(11))
key("ls_key/L6")

-- the DEP/ARR INDEX's RTE 2 lines (FCOM p.1299-1300)
key("func_key/clb")
T.check(line(1):find("DEPARTURES"), "DEP ARR on the ground: the active route's DEPARTURES: " .. line(1))
T.equal(small(2), " SIDS    RTE 2   RUNWAYS", "RTE 2's")
key("ls_key/L6")
T.equal(small(2), "          RTE 1         ", "the INDEX: RTE 1, inactive")
T.equal(small(6), "          RTE 2 (ACT)   ", "RTE 2 (ACT)")
T.equal(line(7), lr("<DEP    ZZAA", ""), "RTE 2's DEP")
T.equal(line(9), lr("        ZZBB", "ARR>"), "and ARR")
key("ls_key/R2")
T.equal(small(2), " STARS   RTE 1  APPROACH", "RTE 1's ARR: its ARRIVALS")

T.done()
