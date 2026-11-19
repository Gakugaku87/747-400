-- Run from the repository root with LuaJIT: luajit tests/fms/atc_load_model_test.lua
-- An ATC uplink's LOAD, stage A (2026-11-20, GAP N19-ATC-03; notes/
-- ATA-34-61-FMC.md §175.5): B747.68.atc_load_model.lua on the synthetic
-- navigation data (tests/fms/data/navdb: ZZAA DIRECT ALPHA, Z1 BRAVO
-- CHARL, DIRECT DELTA, ZZBB) with the real route and RTA models:
--  - the elements it knows (CPDLC p.202-203, appendix G): UM74, UM77,
--    UM46, UM51-53, UM64; not UM47, 48, 75 (not loadable on the 747-400),
--    76, 78, 49, the others; the route clearances, procedures and holds
--    (stage B) as loadable data not loaded; the forms of the time, level
--    and distance; "CROSS X12" and its "AT ..." one element;
--  - the LOAD prompt's data (the RTA's only with RTA);
--  - LOAD: DIRECT TO a fix in the route (collapsed) and one not (a
--    discontinuity after it), AT X DIRECT TO Y (collapsed between, or Y
--    inserted after X with a discontinuity), CROSS's AT constraint (not at
--    or above the cruise altitude), RTA PROGRESS's FIX and time (B, A),
--    the offset (in the air, not on the ground), UNABLE TO LOAD CLEARANCE
--    and PARTIAL CLEARANCE LOADED (FCOM p.1433-1434; FMSPG p.293).
local T = dofile("tests/lib/check.lua")("atc_load_model")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_uplink_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_load_model.lua")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local RTA = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.rta_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua")

local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end

-- the elements
local function kinds(text)
    local out = {}
    for _, it in ipairs(L.items(text)) do
        local v = it.kind
        if it.at then v = v .. " " .. it.at end
        if it.fix then v = v .. " " .. it.fix end
        if it.alt then v = v .. " " .. it.alt end
        if it.time then v = v .. " " .. it.time .. (it.suffix or "") end
        if it.dist then v = v .. " " .. it.dist end
        out[#out + 1] = v
    end
    return table.concat(out, "|")
end
T.equal(kinds("PROCEED DIRECT TO CHARL"), "DIRECT CHARL", "UM74 PROCEED DIRECT TO")
T.equal(L.items("PROCEED DIRECT TO CHARL")[1].um, 74, "its number")
T.equal(kinds("AT BRAVO PROCEED DIRECT TO DELTA"), "AT_DIRECT BRAVO DELTA", "UM77 AT [position] PROCEED DIRECT TO")
T.equal(kinds("CROSS CHARL AT FL250"), "ALT CHARL 25000", "UM46 CROSS AT FL250")
T.equal(kinds("CROSS CHARL AT FL 250"), "ALT CHARL 25000", "FL 250")
T.equal(kinds("CROSS CHARL AT 12000 FT"), "ALT CHARL 12000", "12000 FT")
T.equal(kinds("CROSS CHARL AT 8000"), "ALT CHARL 8000", "8000: a level (a time has its Z: estimate)")
T.equal(kinds("CROSS DELTA AT 1740Z"), "RTA DELTA 1060", "UM51 CROSS AT 1740Z")
T.equal(kinds("CROSS DELTA AT OR BEFORE 1740Z"), "RTA DELTA 1060B", "UM52 AT OR BEFORE: B")
T.equal(kinds("CROSS DELTA AT OR AFTER 1740Z"), "RTA DELTA 1060A", "UM53 AT OR AFTER: A (appendix G's BEFORE a misprint)")
T.equal(kinds("CROSS DELTA AT 174030Z"), "RTA DELTA 1060.5", "HHMMSSZ: to a tenth of a minute")
T.equal(kinds("CROSS DELTA AT 2460Z"), "", "2460Z: no time")
T.equal(kinds("OFFSET 20NM RIGHT OF ROUTE"), "OFFSET 20", "UM64 OFFSET 20NM RIGHT")
T.equal(kinds("OFFSET 5 NM LEFT OF ROUTE"), "OFFSET -5", "5 NM LEFT")
T.equal(kinds("OFFSET 99NM LEFT OF ROUTE"), "OFFSET -99", "99 NM")
T.equal(kinds("OFFSET 100NM RIGHT OF ROUTE"), "", "100 NM: not loadable (at most 99: appendix G)")
T.equal(kinds("OFFSET 20KM RIGHT OF ROUTE"), "", "kilometres: not loadable (nautical miles: appendix G)")
T.equal(kinds("OFFSET 20NM EITHER SIDE OF ROUTE"), "", "either side: not loadable (left or right: appendix G)")
T.equal(kinds("WHEN ABLE PROCEED DIRECT TO CHARL"), "", "UM75 WHEN ABLE: not loadable on the 747-400")
T.equal(kinds("CROSS CHARL AT OR ABOVE FL250"), "", "UM47 AT OR ABOVE: not loadable on the 747-400")
T.equal(kinds("CROSS CHARL AT OR BELOW FL250"), "", "UM48 AT OR BELOW: not loadable on the 747-400")
T.equal(kinds("CROSS CHARL AT AND MAINTAIN FL250"), "", "UM49: not")
T.equal(kinds("AT 1605Z PROCEED DIRECT TO CHARL"), "", "UM76 AT [time] PROCEED DIRECT TO: not")
T.equal(kinds("AT FL250 PROCEED DIRECT TO CHARL"), "", "UM78 AT [level] PROCEED DIRECT TO: not")
T.equal(kinds("CROSS CHARL AT 1605Z AT FL350"), "", "UM58 (time and level): not")
T.equal(kinds("CLIMB TO AND MAINTAIN FL350"), "", "CLIMB: not")
T.equal(kinds("EXPECT DIRECT CHARL"), "", "EXPECT: not")
T.equal(kinds("CLEARED TO ZZBB VIA Z1"), "LATER", "UM79 CLEARED TO ... VIA: stage B")
T.equal(kinds("AT CHARL CLEARED Z1 DELTA"), "LATER", "UM83 AT ... CLEARED: stage B")
T.equal(kinds("HOLD AT CHARL MAINTAIN FL250 INBOUND TRACK 180 RIGHT TURNS"), "LATER", "HOLD AT: stage B (FMSPG p.293)")
T.equal(kinds("CLEARED TO DEVIATE UP TO 20NM RIGHT OF ROUTE"), "", "UM82 deviation: not")
T.equal(kinds("CROSS ZB001 AT FL250"), "ALT ZB001 25000", "a position with a digit: CROSS and its AT one element")
T.equal(kinds("CROSS ZB001 AT OR BEFORE 1740Z"), "RTA ZB001 1060B", "and its AT OR BEFORE")
T.equal(kinds("PROCEED DIRECT TO @CHARL@"), "DIRECT CHARL", "Hoppie's @ marks dropped")
T.equal(kinds("proceed direct to charl."), "DIRECT CHARL", "lower case and a full stop")
T.equal(kinds("PROCEED DIRECT TO N36E141"), "DIRECT N36E141", "a latitude/longitude")
T.equal(kinds("PROCEED DIRECT TO CHARL/CROSS DELTA AT FL250/OFFSET 20NM RIGHT OF ROUTE/CLIMB TO FL350"),
    "DIRECT CHARL|ALT DELTA 25000|OFFSET 20", "a concatenation: its loadable elements in order")
T.equal(kinds("PROCEED DIRECT TO DELTA CROSS DELTA AT FL250"), "", "no boundary after a position without a digit: one element, not loadable")

-- the LOAD prompt's data
T.check(L.loadable(L.items("PROCEED DIRECT TO CHARL"), false), "DIRECT TO: loadable")
T.check(not L.loadable(L.items("CLIMB TO FL350"), true), "CLIMB: not")
T.check(not L.loadable(L.items("CLEARED TO ZZBB VIA Z1"), true), "stage B alone: no LOAD prompt")
T.check(L.loadable(L.items("CROSS DELTA AT 1740Z"), true), "RTA with RTA: loadable")
T.check(not L.loadable(L.items("CROSS DELTA AT 1740Z"), false), "RTA without (the 570: FCOM p.1375): not")

-- the active route: ZZAA, DIRECT ALPHA, Z1 BRAVO CHARL, DIRECT DELTA, ZZBB
local function fix(ident) return N.find(db, ident, 35.5, 140.5)[1] end
local function idents(st)
    local out = {}
    for _, l in ipairs(R.legs(R.shown(st))) do out[#out + 1] = l.fix and l.fix.ident or (l.pending and "[]" or "DISC") end
    return table.concat(out, " ")
end
local function route()
    local st = R.new(N, db)
    R.set_origin(st, "ZZAA")
    R.set_dest(st, "ZZBB")
    R.add_to(st, fix("ALPHA"))
    R.add_via(st, "Z1")
    R.add_to(st, fix("CHARL"))
    R.add_to(st, fix("DELTA"))
    R.activate(st)
    R.exec(st)
    return st
end
local PPOS = {lat = 35.4, lon = 140.4}
local function env(st, o)
    o = o or {}
    local e = {R = R, st = st, T = RTA, rta = o.rta, has_rta = o.has_rta ~= false, ppos = PPOS,
        airborne = o.airborne ~= false, crz_alt = o.crz_alt or 35000, var = function() return -7 end}
    return e
end
local function load(st, text, o) return L.load(L.items(text), env(st, o)) end

local st = route()
T.equal(idents(st), "ALPHA BRAVO CHARL DELTA", "the route")
-- UM74, a fix in the route: the route to it collapsed (appendix G)
local res = load(st, "PROCEED DIRECT TO CHARL")
T.equal(res.msg, nil, "DIRECT TO CHARL: loaded, no message")
T.check(res.route and not res.rta and res.data == 1 and res.ok == 1, "the route changed")
T.check(st.mod ~= nil, "a modification (EXEC, ERASE)")
T.equal(idents(st), "CHARL DELTA", "ALPHA and BRAVO collapsed")
local l1 = R.shown(st).legs[1]
T.check(l1.dto and l1.from and math.abs(l1.from.lat - PPOS.lat) < 1e-9, "a direct-to from the airplane (the LEGS page's)")
T.check(l1.route_crs ~= nil, "the route's course into CHARL for INTC CRS: " .. tostring(l1.route_crs))
T.equal(st.rte.legs[1].fix.ident, "ALPHA", "the active route as it was until EXEC")
R.erase(st)
-- UM74, a fix not in the route: inserted first, a discontinuity after it
res = load(st, "PROCEED DIRECT TO ZZD")
T.equal(res.msg, nil, "DIRECT TO ZZD (not in the route)")
T.equal(idents(st), "ZZD DISC ALPHA BRAVO CHARL DELTA", "ZZD first, a ROUTE DISCONTINUITY after it (appendix G)")
R.erase(st)
res = load(st, "PROCEED DIRECT TO N36E141")
T.equal(res.msg, nil, "DIRECT TO a latitude/longitude")
T.check(R.shown(st).legs[1].fix.kind == "LL" and math.abs(R.shown(st).legs[1].fix.lat - 36) < 1e-9, "its point")
R.erase(st)
res = load(st, "PROCEED DIRECT TO NOFIX")
T.equal(res.msg, L.UNABLE, "a position not in the navigation data: UNABLE TO LOAD CLEARANCE")
T.check(st.mod == nil and not res.route, "nothing changed")
-- UM77
res = load(st, "AT BRAVO PROCEED DIRECT TO DELTA")
T.equal(res.msg, nil, "AT BRAVO DIRECT TO DELTA")
T.equal(idents(st), "ALPHA BRAVO DELTA", "the route between BRAVO and DELTA collapsed (CHARL out)")
T.equal(R.shown(st).legs[3].via, R.DIRECT, "DELTA DIRECT from BRAVO")
R.erase(st)
res = load(st, "AT ALPHA PROCEED DIRECT TO ZZD")
T.equal(idents(st), "ALPHA ZZD DISC BRAVO CHARL DELTA", "ZZD not in the route: after ALPHA, a discontinuity after it")
R.erase(st)
res = load(st, "AT ZZD PROCEED DIRECT TO DELTA")
T.equal(res.msg, L.UNABLE, "AT ZZD (not in the route): UNABLE TO LOAD CLEARANCE")
T.equal(st.mod, nil, "no modification")
-- UM46
res = load(st, "CROSS CHARL AT FL250")
T.equal(res.msg, nil, "CROSS CHARL AT FL250")
local c = R.shown(st).legs[3]
T.check(c.fix.ident == "CHARL" and c.alt == 25000 and c.akind == "" and st.mod ~= nil, "CHARL's AT constraint FL250 (RTE LEGS: FCOM p.1332)")
R.erase(st)
res = load(st, "CROSS CHARL AT FL370")
T.equal(res.msg, L.UNABLE, "FL370 above the cruise altitude FL350: UNABLE (RTE LEGS's INVALID ENTRY)")
res = load(st, "CROSS ZZD AT FL250")
T.equal(res.msg, L.UNABLE, "a fix not in the route: UNABLE (appendix G: a fix in the active route)")
T.equal(st.mod, nil, "no modification")
-- UM51-53
local rs = RTA.new()
res = load(st, "CROSS DELTA AT OR BEFORE 1740Z", {rta = rs})
T.equal(res.msg, nil, "CROSS DELTA AT OR BEFORE 1740Z")
T.check(res.rta and not res.route and st.mod == nil, "RTA PROGRESS's modification, no route's")
T.check(rs.mod and rs.mod.fix == "DELTA" and rs.mod.time == 1060 and rs.mod.suffix == "B" and RTA.ready(rs),
    "RTA PROGRESS: DELTA 1740.0B, ready for EXEC")
res = load(st, "CROSS DELTA AT OR AFTER 1740Z", {rta = rs})
T.equal(rs.mod.suffix, "A", "AT OR AFTER: A")
res = load(st, "CROSS DELTA AT 1740Z", {rta = rs})
T.equal(rs.mod.suffix, nil, "AT: no suffix")
RTA.erase(rs)
res = load(st, "CROSS ZZD AT 1740Z", {rta = rs})
T.equal(res.msg, L.UNABLE, "RTA at a fix not in the route: UNABLE")
T.equal(rs.mod, nil, "no RTA modification")
res = load(st, "CROSS DELTA AT 1740Z", {rta = nil})
T.equal(res.msg, L.UNABLE, "RTA not available now (ENG OUT): UNABLE")
-- UM64
res = load(st, "OFFSET 20NM RIGHT OF ROUTE")
T.equal(res.msg, nil, "OFFSET 20NM RIGHT in the air")
T.equal(R.shown(st).offset, 20, "the offset R20 in the modification (RTE: FCOM p.1298)")
R.erase(st)
res = load(st, "OFFSET 20NM LEFT OF ROUTE", {airborne = false})
T.equal(res.msg, L.UNABLE, "on the ground: UNABLE (RTE takes none)")
-- the offset where a procedure is flown: UNABLE (FMSPG p.293's example)
local sp = R.new(N, db)
sp.P = P
R.set_origin(sp, "ZZAA")
R.set_dest(sp, "ZZBB")
R.set_runway(sp, "16R")
R.set_departure(sp, "ZULU1", "RW16R", nil)
R.add_to(sp, fix("DELTA"))
R.activate(sp)
R.exec(sp)
T.check(R.shown(sp).legs[1].proc == "SID", "a route on its SID: " .. idents(sp))
res = load(sp, "OFFSET 10NM RIGHT OF ROUTE")
T.equal(res.msg, L.UNABLE, "the offset on a SID: UNABLE TO LOAD CLEARANCE (FMSPG p.293)")
-- PARTIAL
res = load(st, "PROCEED DIRECT TO CHARL/CROSS ZZD AT FL250")
T.equal(res.msg, L.PARTIAL, "DIRECT TO loaded, CROSS not: PARTIAL CLEARANCE LOADED")
T.check(res.data == 2 and res.ok == 1 and st.mod ~= nil, "one of two, the modification kept")
R.erase(st)
res = load(st, "PROCEED DIRECT TO CHARL/CLEARED TO ZZBB VIA Z1")
T.equal(res.msg, L.PARTIAL, "with a route clearance (stage B, not loaded here): PARTIAL (estimate)")
R.erase(st)
res = load(st, "PROCEED DIRECT TO CHARL/CROSS DELTA AT 1740Z", {has_rta = false})
T.equal(res.msg, nil, "without RTA the RTA element is no loadable data: no message")
T.equal(res.data, 1, "one element")
R.erase(st)
-- the elements in order: DIRECT TO, then the constraint on the new route
res = load(st, "PROCEED DIRECT TO CHARL/CROSS DELTA AT FL250/OFFSET 20NM RIGHT OF ROUTE", {rta = rs})
T.equal(res.msg, nil, "three elements loaded")
T.equal(idents(st), "CHARL DELTA", "DIRECT TO CHARL")
T.check(R.shown(st).legs[2].alt == 25000, "DELTA FL250")
T.equal(R.shown(st).offset, 20, "the offset (after the direct-to, which cancels one)")
R.erase(st)
-- an inactive route: nothing to load into
local si = R.new(N, db)
R.set_origin(si, "ZZAA")
R.set_dest(si, "ZZBB")
R.add_to(si, fix("ALPHA"))
res = load(si, "PROCEED DIRECT TO ALPHA")
T.equal(res.msg, L.UNABLE, "no active route: UNABLE")

T.done()
