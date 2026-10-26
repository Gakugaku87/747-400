-- Run from the repository root with LuaJIT: luajit tests/fms/hold_pages_test.lua
-- The holds on the CDU (6-1/6-2 step 7b; notes/ATA-34-61-FMC.md §33) in the
-- FMS module as XTLua runs it (tests/lib/xtlua.lua), on the synthetic
-- navigation data in tests/fms/data/navdb: the HOLD key (RTE LEGS HOLD AT
-- without a hold, RTE 1 HOLD with one: FCOM p.1413-1416), HOLD AT a
-- waypoint of the route and one not in it, PPOS (FCOM p.1414-1415; FMSPG
-- p.157-158), the RTE HOLD page's lines and entries (FCOM p.1417-1419;
-- FMSPG p.159-162), EXIT HOLD, DELETE of the hold flown (FCOM p.1416), the
-- hold in X-Plane's flight plan (its racetrack after its fix).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("hold_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

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
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or ch == " " and "key/space"
            or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(text, lsk) type_in(text) key("ls_key/" .. lsk) end
local function clear() key("key/clear") key("key/clear", 1.2) end
local function xpfms() frames(1.2) return rt:get("xtlua/loadtoFMS") or "" end
local function onces(suffix)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.phase == "once" and tostring(e.name):find(suffix .. "$") then n = n + 1 end
    end
    return n
end
local function count(s, pat) local n = 0 for _ in s:gmatch(pat) do n = n + 1 end return n end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local st = fms.ns.B747_fmc_route

-- a route, active: ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL, ZZBB
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("Z1", "L2")
enter("CHARL", "R2")
key("ls_key/R6")
key("key/execute")

-- the HOLD key without a hold: RTE LEGS HOLD AT (FCOM p.1413-1414)
local before = onces("FMS/hold")
key("func_key/dep_arr")
T.equal(onces("FMS/hold") - before, 0, "the HOLD key: the FMC's page (before: X-Plane's HOLD page)")
T.check(line(1):find("ACT RTE 1 LEGS"), "no hold in the route: ACT RTE 1 LEGS (FCOM p.1414): " .. line(1))
T.equal(line(12), "--------HOLD AT---------", "the HOLD AT line")
T.equal(line(13), "*****              PPOS>", "its boxes and PPOS>")
T.equal(line(5), "BRAVO                   ", "the route's waypoints on it")

-- HOLD AT BRAVO, a waypoint of the route (FMSPG p.158): its hold after
-- the leg to it, MOD RTE 1 HOLD
enter("BRAVO", "L6")
T.check(line(1):find("MOD RTE 1 HOLD"), "MOD RTE 1 HOLD: " .. line(1))
T.equal(small(1), "                    1/1 ", "1/1")
T.equal(small(2), lr(" FIX", "SPD/TGT ALT"), "FIX, SPD/TGT ALT")
T.equal(line(3), lr("BRAVO", "---/-----"), "BRAVO; no target")
T.equal(small(4), lr(" QUAD/RADIAL", "FIX ETA"), "QUAD/RADIAL, FIX ETA")
T.equal(line(5), lr("--/---", "----.- "), "dashes (FMSPG p.159); no predictions yet (step 8)")
T.equal(small(5), lr("", "Z"), "its Z small (FCOM p.1415)")
T.equal(line(7), lr("007`/R TURN", "---- "), "inbound the leg's course into BRAVO (north: 007 magnetic), right turns (FMSPG p.160); EFC dashes")
T.equal(small(7), lr("", "Z"), "its Z")
T.equal(line(9), lr("1.0", "-+--"), "LEG TIME 1.0 (no altitude above 14,000 ft: FMSPG p.222)")
T.equal(small(9), "    MIN                 ", "MIN")
T.equal(line(11), lr("--.-", "---  "), "LEG DIST dashes; BEST SPEED dashes")
T.equal(small(11), lr("    NM", "KT"), "NM, KT small (FCOM p.1415)")
T.equal(line(13), "<ERASE                  ", "ERASE on the modification; no EXIT HOLD (not the active leg)")
T.check(rt:get("laminar/B747/fms/exec_light_pilot") == 1, "the EXEC light")
key("key/execute")
T.check(line(1):find("ACT RTE 1 HOLD"), "EXEC: ACT RTE 1 HOLD: " .. line(1))
T.equal(line(13), "<NEXT HOLD              ", "NEXT HOLD")
local plan = xpfms()
T.check(plan:find("\n11 BRAVO Z1 [^\n]*\n11 BRAVO DRCT [^\n]*\n28 ~ DRCT "), "X-Plane's plan: BRAVO, the hold at BRAVO, its racetrack")
T.equal(count(plan, "\n28 ~ DRCT "), 14, "13 points round the racetrack and BRAVO again")
T.check(plan:find("\n28 ~ DRCT [^\n]*\n11 CHARL Z1 "), "then CHARL")
key("func_key/legs")
T.equal(small(6), " HOLD AT                ", "LEGS: HOLD AT over the hold's line (FCOM p.1331)")
T.equal(line(7), "BRAVO                   ", "BRAVO")
T.equal(line(9), "CHARL                   ", "then CHARL")
key("func_key/fpln")
key("func_key/next_pg")
T.equal(line(5), "Z1                 CHARL", "RTE: Z1 to CHARL as before (the hold no segment of its own)")

-- the HOLD key with a hold: its page (FCOM p.1416)
key("func_key/dep_arr")
T.check(line(1):find("ACT RTE 1 HOLD") and line(3):find("^BRAVO"), "the HOLD key: BRAVO's hold")
-- the entries (FCOM p.1417-1418; FMSPG p.159-161)
enter("180/L", "L3")
T.check(line(1):find("MOD RTE 1 HOLD"), "an entry: the modification")
T.equal(line(7), lr("180`/L TURN", "---- "), "INBD CRS/DIR 180/L")
enter("R", "L3")
T.equal(line(7):sub(1, 11), "180`/R TURN", "R alone: the turn")
enter("NW330", "L2")
T.equal(line(5):sub(1, 6), "NW/330", "QUAD/RADIAL NW/330")
T.equal(line(7):sub(1, 11), "150`/R TURN", "the inbound course its reciprocal")
enter("/090", "L2")
T.equal(line(5):sub(1, 5), "E/090", "/090: the quadrant from the radial (FMSPG p.159)")
enter("045", "L3")
T.equal(line(5):sub(1, 6), "--/---", "an inbound course: QUAD/RADIAL dashed (FMSPG p.160)")
enter("1.5", "L4")
T.equal(line(9):sub(1, 3), "1.5", "LEG TIME 1.5")
enter("4.5", "L5")
T.equal(line(11):sub(1, 4), "4.5 ", "LEG DIST 4.5")
T.equal(line(9):sub(1, 3), "-.-", "LEG TIME dashed (FCOM p.1418)")
enter("220/8000", "R1")
T.equal(line(3), lr("BRAVO", "220/8000"), "SPD/TGT ALT 220/8000")
enter("1440", "R3")
T.equal(line(7):sub(-5), "1440 ", "EFC TIME 1440Z")
enter("400", "L3")
T.equal(pad(), "INVALID ENTRY", "inbound 400: INVALID ENTRY")
clear()
key("key/del")
key("ls_key/L2")
T.equal(pad(), "INVALID DELETE", "QUAD/RADIAL: no DELETE (FMSPG p.159)")
clear()
enter("ZZD", "L1")
T.equal(pad(), "INVALID ENTRY", "FIX: not changed here (FMSPG p.159)")
clear()
key("func_key/legs")
T.equal(line(7), lr("BRAVO", "220/8000"), "the target on the hold's LEGS line (FCOM p.1418)")
key("func_key/dep_arr")
key("key/execute")
local h = st.rte.legs[3]
T.check(R.is_hold(h) and h.crs == 45 and h.turn == "R" and h.dist == 4.5 and h.time == nil and h.alt == 8000
    and h.spd == 220 and h.efc == "1440", "EXEC: the hold as entered")

-- NEXT HOLD: RTE LEGS HOLD AT; HOLD AT ZZD, not in the route: HOLD AT ZZD
-- in the scratchpad, put on a line (FCOM p.1414)
key("ls_key/L6")
T.equal(line(12), "--------HOLD AT---------", "NEXT HOLD: RTE LEGS HOLD AT")
enter("ZZD", "L6")
T.equal(pad(), "HOLD AT ZZD", "ZZD not in the route: HOLD AT ZZD in the scratchpad")
key("ls_key/L1")
T.equal(pad(), "INVALID ENTRY", "not the active waypoint (FCOM p.1414)")
key("key/clear")
T.equal(pad(), "HOLD AT ZZD", "CLR: HOLD AT ZZD back")
key("ls_key/L4")
T.check(line(1):find("MOD RTE 1 HOLD") and line(3):find("^ZZD"), "on CHARL's line: ZZD's hold, MOD RTE 1 HOLD")
T.equal(small(1), "                    2/2 ", "the second hold")
local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local zzd = N.find(db, "ZZD", 35.5, 140.5)[1]
local bravo = st.mod.legs[2].fix
local back = R.course(zzd.lat, zzd.lon, bravo.lat, bravo.lon)
T.equal(line(7):sub(1, 4), string.format("%03d`", math.floor((back + 180 + 7) % 360 + 0.5)),
    "inbound from BRAVO's hold into ZZD")
local legs = st.mod.legs
local function is_zzd(p) return p and p.ident == "ZZD" and math.abs(p.lat - zzd.lat) < 1e-9 end
T.check(is_zzd(legs[4].fix) and not R.is_hold(legs[4]) and R.is_hold(legs[5]) and is_zzd(legs[5].fix) and legs[6].disc
    and legs[7].fix.ident == "CHARL", "ZZD, its hold, a ROUTE DISCONTINUITY, CHARL")
key("func_key/prev_pg")
T.check(line(3):find("^BRAVO"), "PREV PAGE: BRAVO's hold")
key("ls_key/L6")
T.check(line(1):find("ACT RTE 1 HOLD"), "ERASE: the modification gone")
T.equal(#R.holds(st.rte), 1, "one hold")

-- a procedure's hold in lieu of a procedure turn: PROC HOLD (FCOM p.1416)
table.insert(st.rte.legs, 5, {via = "DIRECT", pt = "HF", fix = st.rte.legs[4].fix, crs = 7, time = 1})
key("func_key/next_pg")
T.equal(small(2):sub(1, 10), " PROC HOLD", "an HF hold after CHARL: PROC HOLD at 1L")
key("func_key/legs")
T.equal(small(10), " PROC HOLD              ", "and over its LEGS line (FCOM p.1331)")
table.remove(st.rte.legs, 5)

-- in the air: PPOS (FCOM p.1415), EXIT HOLD (FCOM p.1419), DELETE of the
-- hold flown (FCOM p.1416)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/position/latitude", 35.2)
rt:set("sim/flightmodel/position/longitude", 140.3)
rt:set("sim/flightmodel/position/hpath", 45)
frames(0.5)
key("func_key/dep_arr")
key("ls_key/L6")
key("ls_key/R6")
T.check(line(1):find("MOD RTE 1 HOLD") and line(3):find("^PPOS"), "PPOS: MOD RTE 1 HOLD at PPOS")
T.equal(small(1), "                    1/2 ", "the first hold")
T.equal(line(7):sub(1, 11), "052`/R TURN", "inbound the track (045 true, 052 magnetic: estimate)")
T.equal(line(13), "<ERASE        EXIT HOLD>", "EXIT HOLD> on the active leg of the modified route (FMSPG p.162)")
rt:set("sim/flightmodel/position/latitude", 35.21)
key("key/execute")
T.check(line(3):find("^N35E140"), "EXEC: the fix where the airplane is then, N35E140 (FCOM p.1415): " .. line(3))
T.check(math.abs(st.rte.legs[1].fix.lat - 35.21) < 1e-9, "its position at EXEC")
T.equal(line(13), "<NEXT HOLD    EXIT HOLD>", "ACT: EXIT HOLD>")
T.check(xpfms():find("\n28 N35E140 DRCT [^\n]*\n28 ~ DRCT "), "X-Plane's plan: the PPOS hold's fix and racetrack")
frames(1)
T.equal(rt:get("laminar/B747/fms/lnav/hold_phase"), 2, "LNAV: the direct entry (2)")
key("ls_key/R6")
T.equal(line(13), "<ERASE        EXIT ARMED", "EXIT HOLD: EXIT ARMED, the modification")
key("key/execute")
T.equal(line(13), "<NEXT HOLD    EXIT ARMED", "EXEC: EXIT ARMED")
T.check(st.rte.legs[1].exit, "the exit armed")
frames(0.5)
T.equal(rt:get("laminar/B747/fms/lnav/hold_exit"), 1, "LNAV: the exit armed")
-- DELETE the hold flown: a direct to the next waypoint
key("func_key/legs")
key("key/del")
key("ls_key/L1")
T.check(line(1):find("MOD RTE 1 LEGS") and line(3):find("^ALPHA"), "DELETE the hold flown: ALPHA next (FCOM p.1416)")
rt:set("sim/flightmodel/position/latitude", 35.22)
key("key/execute")
local a = st.rte.legs[1]
T.check(a.fix.ident == "ALPHA" and a.dto and a.from and math.abs(a.from.lat - 35.22) < 1e-9,
    "EXEC: direct to ALPHA from where the airplane is")
frames(0.5)
T.equal(rt:get("laminar/B747/fms/lnav/hold_phase"), 0, "LNAV: no hold")
key("func_key/dep_arr")
T.check(line(1):find("ACT RTE 1 HOLD"), "BRAVO's hold still ahead: " .. line(1))
table.remove(st.rte.legs, 3)
frames(0.5)
T.equal(line(12), "--------HOLD AT---------", "no hold left on the RTE HOLD page: RTE LEGS HOLD AT (estimate)")

T.done()
