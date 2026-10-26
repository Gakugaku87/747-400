-- Run from the repository root with LuaJIT: luajit tests/fms/route_model_test.lua
-- The FMC's route (6-1/6-2 step 5a; notes/ATA-34-61-FMC.md §18):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua
-- on the synthetic navigation data in tests/fms/data/navdb (airway Z1
-- ALPHA-BRAVO-CHARL-DELTA, CHARL to DELTA one way, BRAVO-ZZV shared with
-- Z2): ORIGIN, DEST and RUNWAY (FCOM p.1288-1289), the RTE pages' DIRECT
-- and airway segments, the airways' intersection, ROUTE FULL (FCOM
-- p.1296-1298, p.1435; FMSPG p.82-83), ACTIVATE, MOD, EXEC and ERASE (FCOM
-- p.1238, p.1290), X-Plane's flight plan file.
local T = dofile("tests/lib/check.lua")("route_model")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local function fix(ident) return N.find(db, ident, 35.5, 140.5)[1] end
local function segs(st)
    local out = {}
    for _, s in ipairs(R.segments(R.shown(st))) do
        out[#out + 1] = s.disc and "DISC" or (s.via .. " " .. (s.to or "[]"))
    end
    return table.concat(out, ", ")
end
local function idents(st)
    local out = {}
    for _, l in ipairs(R.legs(R.shown(st))) do out[#out + 1] = l.fix and l.fix.ident or (l.pending and "[]" or "DISC") end
    return table.concat(out, " ")
end

-- RTE page 1
local st = R.new(N, db)
T.equal(R.status(st), "", "a new route: inactive (no ACT, no MOD)")
T.check(not R.exec_lit(st), "no EXEC")
T.equal(R.set_origin(st, "ZZXX"), R.NOT_IN_DATA_BASE, "ORIGIN not in the database (FCOM p.1288)")
T.equal(R.set_origin(st, "ZZAA"), nil, "ORIGIN ZZAA")
T.equal(R.shown(st).origin.ident, "ZZAA", "the origin")
T.equal(R.set_runway(st, "XX"), R.INVALID_ENTRY, "RUNWAY XX: not a runway")
T.equal(R.set_runway(st, "99"), R.NOT_IN_DATA_BASE, "RUNWAY 99: not ZZAA's (FCOM p.1289)")
T.equal(R.set_runway(st, "16R"), nil, "RUNWAY 16R")
T.equal(R.shown(st).runway.ident, "RW16R", "RW16R")
T.equal(R.set_runway(st, "RW34L"), nil, "RW34L")
T.equal(R.set_dest(st, "ZZBB"), nil, "DEST ZZBB")
T.equal(R.shown(st).dest.ident, "ZZBB", "the destination")

-- the RTE pages' segments
T.equal(R.add_via(st, "Z1"), R.INVALID_ENTRY, "an airway first, no TO before it: INVALID ENTRY (the airway intercept is not made: estimate)")
T.equal(R.add_to(st, fix("ALPHA")), nil, "TO ALPHA on the dashes")
T.equal(segs(st), "DIRECT ALPHA", "DIRECT ALPHA (FCOM p.1297: dashes change to DIRECT)")
T.equal(R.add_via(st, "Z9"), R.NOT_IN_DATA_BASE, "airway Z9: NOT IN DATA BASE (FMSPG p.83)")
T.equal(R.add_via(st, "Z1"), nil, "VIA Z1")
T.equal(segs(st), "DIRECT ALPHA, Z1 []", "Z1 with boxes for its TO")
T.equal(R.add_to(st, fix("ZZD")), R.INVALID_ENTRY, "TO ZZD: not on Z1 (FMSPG p.83)")
T.equal(R.add_to(st, fix("CHARL")), nil, "TO CHARL")
T.equal(segs(st), "DIRECT ALPHA, Z1 CHARL", "Z1 to CHARL")
T.equal(idents(st), "ALPHA BRAVO CHARL", "the legs: Z1's points from ALPHA (FMSPG p.83: the LEGS pages show them)")
T.equal(R.add_via(st, "Z2"), R.INVALID_ENTRY, "Z2 does not contain CHARL: INVALID ENTRY (FCOM p.1297)")

-- two airways without a TO: their intersection (FCOM p.1297)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
T.equal(R.add_via(st, "Z2"), nil, "VIA Z1 then VIA Z2")
T.equal(segs(st), "DIRECT ALPHA, Z1 XZ2, Z2 []", "Z1's TO: the crossing waypoint XZ2 (FCOM p.1250)")
local x = R.legs(R.shown(st))[2]
T.check(x.intc and x.fix.lat == 36 and x.fix.lon == 140.5, "at the point they share (BRAVO's)")
T.equal(R.add_to(st, fix("ZZV")), nil, "Z2 to ZZV")
T.equal(idents(st), "ALPHA XZ2 ZZV", "the legs")

-- a one-way segment: not against its way
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("DELTA"))
T.equal(R.add_via(st, "Z1"), nil, "Z1 contains DELTA")
T.equal(R.add_to(st, fix("CHARL")), R.INVALID_ENTRY, "DELTA to CHARL against Z1's one way: INVALID ENTRY")

-- ROUTE FULL (120 waypoints; here 3)
R.MAX_WPTS = 3
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
T.equal(R.add_to(st, fix("DELTA")), R.ROUTE_FULL, "ALPHA to DELTA on Z1: 4 waypoints, ROUTE FULL (FCOM p.1435)")
T.equal(idents(st), "ALPHA []", "the route as it was")
T.equal(R.add_to(st, fix("CHARL")), nil, "to CHARL: 3")
T.equal(R.add_to(st, fix("DELTA")), R.ROUTE_FULL, "a fourth: ROUTE FULL")
R.MAX_WPTS = 120

-- ACTIVATE, EXEC, MOD, ERASE
st = R.new(N, db)
T.equal(R.activate(st), R.INVALID_ENTRY, "ACTIVATE without an origin and a destination")
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
T.check(not R.exec_lit(st), "inactive route changes: no EXEC (FCOM p.1290)")
T.equal(R.activate(st), nil, "ACTIVATE")
T.check(R.exec_lit(st), "EXEC lit")
T.equal(R.status(st), "", "not active until EXEC")
T.check(R.exec(st), "EXEC")
T.equal(R.status(st), "ACT", "ACT RTE 1")
T.check(not R.exec_lit(st), "EXEC out")
T.equal(R.add_to(st, fix("BRAVO")), nil, "a change on the active route")
T.equal(R.status(st), "MOD", "MOD RTE 1 (FCOM p.1238)")
T.check(R.exec_lit(st), "EXEC lit")
T.equal(idents(st), "ALPHA BRAVO", "the pages show the modification")
T.equal(#st.rte.legs, 1, "the active route as it was")
R.erase(st)
T.equal(R.status(st), "ACT", "ERASE: the active route back")
T.equal(idents(st), "ALPHA", "without the change")
R.add_to(st, fix("CHARL"))
T.check(R.exec(st), "EXEC the change")
T.equal(idents(st), "ALPHA CHARL", "the active route changed")
T.check(not R.exec(st), "nothing more to execute")
T.equal(R.set_origin(st, "ZZBB"), nil, "a new origin")
T.equal(R.status(st), "MOD", "on the active route: a modification")
T.equal(idents(st), "", "the route erased (FCOM p.1288)")
T.equal(R.shown(st).dest, nil, "with the destination")

-- SELECT DESIRED WPT: the candidates nearest first, the airports' terminal
-- waypoints with them
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
local c = R.candidates(st, "ZA001", 36, 141)
T.check(#c == 2 and c[1].terminal == "ZZBB" and c[2].terminal == "ZZAA", "ZA001: ZZBB's then ZZAA's (FCOM p.1335)")
c = R.candidates(st, "ALPHA", 35, 140)
T.check(#c == 2 and c[1].region == "ZZ" and c[2].region == "YY", "ALPHA: the near one first")

-- the LEGS pages (step 5c): a waypoint later in the route, another one, a
-- discontinuity closed, DELETE
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("CHARL"))
T.equal(idents(st), "ALPHA BRAVO CHARL", "ALPHA, Z1 to CHARL")
T.equal(R.legs_entry(st, 2, fix("CHARL")), nil, "CHARL over BRAVO")
T.equal(idents(st), "ALPHA CHARL", "a waypoint later in the route: the legs before it go")
T.equal(R.legs(R.shown(st))[2].via, R.DIRECT, "DIRECT to it")
T.equal(R.legs_entry(st, 2, fix("ZZD")), nil, "ZZD over CHARL")
T.equal(idents(st), "ALPHA ZZD DISC CHARL", "another waypoint: inserted, a ROUTE DISCONTINUITY after it (FMSPG p.91)")
T.equal(segs(st), "DIRECT ALPHA, DIRECT ZZD, DISC, DIRECT CHARL", "the RTE pages")
T.equal(R.legs_delete(st, 3), R.INVALID_DELETE, "a discontinuity: not deleted (estimate)")
T.equal(R.legs_entry(st, 3, fix("CHARL")), nil, "CHARL over the boxes")
T.equal(idents(st), "ALPHA ZZD CHARL", "the discontinuity closed (FMSPG p.91)")
T.equal(R.legs_delete(st, 2), nil, "DELETE ZZD")
T.equal(idents(st), "ALPHA CHARL", "the waypoints before and after joined (estimate)")
T.equal(R.legs_delete(st, 5), R.INVALID_DELETE, "DELETE where there is no waypoint")
T.equal(R.legs_entry(st, 3, fix("DELTA")), nil, "DELTA on the dashes after the end")
T.equal(idents(st), "ALPHA CHARL DELTA", "added at the end (no discontinuity after it)")

-- DIRECT TO and INTC CRS (FMSPG p.141-144)
T.equal(R.direct_to(st, fix("CHARL")), R.INVALID_ENTRY, "DIRECT TO on an inactive route")
R.activate(st)
R.exec(st)
T.equal(R.direct_to(st, fix("CHARL")), nil, "DIRECT TO CHARL")
T.equal(R.status(st), "MOD", "a modification")
T.equal(idents(st), "CHARL DELTA", "the legs before it gone")
T.check(R.legs(R.shown(st))[1].dto, "from the airplane's position")
T.equal(R.intc_crs(st, 222), nil, "INTC CRS 222")
T.equal(R.legs(R.shown(st))[1].crs, 222, "the course into CHARL")
T.equal(R.intc_crs(st, 361), R.INVALID_ENTRY, "INTC CRS 361")
R.exec(st)
T.equal(R.intc_crs(st, 100), R.INVALID_ENTRY, "INTC CRS without a direct-to modification")

-- speed and altitude constraints (FCOM p.1332; FMSPG p.125-128)
T.equal(R.set_constraint(st, 1, {spd = 250}, 35000), R.INVALID_ENTRY, "a speed alone without an altitude constraint")
T.equal(R.set_constraint(st, 1, {alt = 10000, akind = "A"}, 35000), nil, "10000A")
T.equal(R.constraint_text(R.legs(R.shown(st))[1], 18000), "/10000A", "shown /10000A")
T.equal(R.set_constraint(st, 1, {spd = 250}, 35000), nil, "250/ over the altitude constraint")
T.equal(R.constraint_text(R.legs(R.shown(st))[1], 18000), "250/10000A", "250/10000A")
T.equal(R.set_constraint(st, 1, {spd = 90, alt = 5000}, 35000), R.INVALID_ENTRY, "a speed below 100 kt")
T.equal(R.set_constraint(st, 1, {alt = 35000}, 35000), R.INVALID_ENTRY, "not below the cruise altitude")
T.equal(R.set_constraint(st, 1, {alt = 24000, akind = "B"}, 35000), nil, "24000B")
T.equal(R.constraint_text(R.legs(R.shown(st))[1], 18000), "/FL240B", "the old speed dropped (FMSPG p.128), FL above the transition")
T.equal(R.set_constraint(st, 2, {alt = 22000, alt2 = 24000, akind = "AB"}, 35000), nil, "a block")
T.equal(R.constraint_text(R.legs(R.shown(st))[2], 18000), "/FL220AFL240B", "the block")
T.equal(R.delete_constraint(st, 1), nil, "DELETE the constraint")
T.equal(R.constraint_text(R.legs(R.shown(st))[1], 18000), nil, "the speed and the altitude both gone")
T.equal(R.delete_constraint(st, 1), R.INVALID_DELETE, "DELETE where there is none")

-- X-Plane's flight plan file for its FMS (xtlua/loadtoFMS)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_runway(st, "16R")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ZZV"))
R.add_via(st, "Z2")
R.add_to(st, fix("BRAVO"))
local fms = R.to_fms(R.shown(st), "2610")
T.check(fms:find("^I\n1100 Version\nCYCLE 2610\nADEP ZZAA\nDEPRWY RW16R\nADES ZZBB\nNUMENR 5\n"), "the header: " .. fms:sub(1, 80))
T.check(fms:find("\n1 ZZAA ADEP 100%.000000 35%.000000 140%.000000\n", 1, false), "the origin as an airport")
T.check(fms:find("\n1 ZZAA ADEP [^\n]*\n28 RW16R DRCT %d+%.000000 "), "the departure runway after the origin, by its name and elevation (as X-Plane's DEP ARR puts it)")
T.check(fms:find("\n3 ZZV DRCT 0%.000000 35%.200000 140%.200000\n"), "a VOR, DIRECT")
T.check(fms:find("\n11 BRAVO Z2 0%.000000 36%.000000 140%.500000\n"), "a fix on Z2")
T.check(fms:find("\n1 ZZBB ADES 50%.000000 36%.000000 141%.000000\n$"), "the destination last")
T.equal(R.set_constraint(st, 1, {alt = 5000, akind = "A"}, 35000), nil, "5000A at ZZV")
T.check(R.to_fms(R.shown(st), "2610"):find("\n3 ZZV DRCT 5000%.000000 35%.200000 140%.200000\n"),
    "its altitude in X-Plane's flight plan (the ND's DATA shows it: FCOM p.1148)")

-- the active waypoint and X-Plane's flight plan (step 5e): the rows' map,
-- the legs passed as the AFDS's current waypoint moves on (FMSPG p.119;
-- FCOM p.1331), the flight plan the same
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_runway(st, "16R")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("DELTA"))
local text, map = R.to_fms(R.shown(st), "2610")
T.check(map.n == 7 and map.ident[1] == "ZZAA" and map.ident[2] == "RW16R" and map.ident[3] == "ALPHA"
    and map.ident[7] == "ZZBB", "the rows: the origin, its runway, ALPHA BRAVO CHARL DELTA, the destination")
T.check(map.leg[3] == 1 and map.row[1] == 3 and map.leg[6] == 4 and not map.leg[2] and not map.leg[7], "the rows' legs")
T.equal(R.active_row(R.shown(st), map), 3, "the active waypoint's row: ALPHA's")
T.check(not R.sequence(st, 1), "an inactive route does not sequence")
R.activate(st)
R.exec(st)
T.check(R.sequence(st, 2), "the AFDS at CHARL: ALPHA and BRAVO passed")
T.equal(idents(st), "CHARL DELTA", "the LEGS pages from the active waypoint")
T.equal(segs(st), "Z1 DELTA", "the RTE pages from the active leg")
local text2, map2 = R.to_fms(R.shown(st), "2610")
T.equal(text2, text, "X-Plane's flight plan the same: the passed legs before the active one")
T.check(map2.leg[5] == 1 and not map2.leg[3] and R.active_row(R.shown(st), map2) == 5, "CHARL's row the active one")
T.equal(R.leg_from(R.shown(st), 1).ident, "BRAVO", "the active leg from the last passed waypoint")
T.check(R.sequence(st, 5) and idents(st) == "DELTA", "never past the last leg: DELTA active")
T.check(not R.sequence(st, 1), "the active leg stays")

-- a modification sequences with the route when it starts with the same
-- legs; a direct-to's keeps its own
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("DELTA"))
R.activate(st)
R.exec(st)
R.legs_delete(st, 4)
T.check(R.sequence(st, 1) and idents(st) == "BRAVO CHARL", "DELTA deleted in the modification, ALPHA passed: BRAVO CHARL")
R.exec(st)
T.equal(table.concat({st.rte.passed[1].fix.ident, #st.rte.passed}, " "), "ALPHA 1", "EXEC: ALPHA passed")
T.equal(R.direct_to(st, fix("CHARL"), nil, {lat = 35.9, lon = 140.4}), nil, "DIRECT TO CHARL")
T.check(R.sequence(st, 1) and idents(st) == "CHARL" and st.rte.legs[1].fix.ident == "CHARL",
    "BRAVO passed on the route, the direct-to's modification as it was")
R.exec(st, {lat = 35.95, lon = 140.45})
local text3, map3 = R.to_fms(R.shown(st), "2610")
T.check(text3:find("\n11 BRAVO Z1 [^\n]*\n28 DTOPOS DRCT 0%.000000 35%.950000 140%.450000\n11 CHARL DRCT "),
    "the direct-to from the airplane's position at EXEC (estimate): DTOPOS before CHARL")
T.check(map3.ident[4] == "DTOPOS" and not map3.leg[4] and R.active_row(R.shown(st), map3) == 5, "CHARL's row active, DTOPOS no leg's")
T.equal(R.leg_from(R.shown(st), 1).lat, 35.95, "the direct-to's leg from its start")
T.check(not R.legs(R.shown(st))[1].dto_exec, "set once")

-- the legs' shape in X-Plane's flight plan (step 6d): the conditional
-- legs' ends by their names where predicted, an arc's points "~", a
-- passed conditional leg where it ended
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
st.rte.legs = {
    {pt = "VA", via = "ZULU1", crs = 337, alt = 600, altterm = true, name = "(600)", proc = "SID"},
    {pt = "VI", via = "ZULU1", crs = 45, name = "(INTC)", proc = "SID"},
    {pt = "CF", via = "ZULU1", fix = fix("ZZV"), crs = 90, proc = "SID"},
}
local shape = {{at = {lat = 35.01, lon = 140.0}}, {at = {lat = 35.1, lon = 140.1}}, {pts = {{lat = 35.15, lon = 140.15}}}}
text, map = R.to_fms(st.rte, "2610", shape)
T.check(text:find("\n28 %(600%) DRCT 0%.000000 35%.010000 140%.000000\n28 %(INTC%) DRCT 0%.000000 35%.100000 140%.100000\n"
    .. "28 ~ DRCT 0%.000000 35%.150000 140%.150000\n3 ZZV DRCT "),
    "(600) and (INTC) where predicted, an arc's point ~, then ZZV: " .. text:gsub("\n", " | "))
T.check(map.leg[2] == 1 and map.leg[3] == 2 and not map.leg[4] and map.leg[5] == 3, "the conditional legs' rows theirs, ~ no leg's")
T.equal(R.active_row(st.rte, map), 2, "the active waypoint (600)'s row")
T.check(not R.to_fms(st.rte, "2610"):find("%(600%)"), "without the shape: no conditional rows (as before step 6d)")
st.active = true
T.check(R.sequence(st, 1, {lat = 35.02, lon = 140.01}), "(600) passed at an altitude")
T.check(st.rte.passed[1].end_at.lat == 35.02 and st.rte.legs[1].start.lat == 35.02, "where it ended: its end, the next leg's start")
text = R.to_fms(st.rte, "2610", {{at = {lat = 35.1, lon = 140.1}}})
T.check(text:find("\n28 %(600%) DRCT 0%.000000 35%.020000 140%.010000\n28 %(INTC%) "), "the passed (600) where it ended")
-- at most 100 rows (X-Plane's FMS): the arcs' points left out first, then
-- the passed legs but the last
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
local many, pts = {}, {}
for k = 1, 60 do many[k] = {via = "DIRECT", fix = {ident = "P" .. k, kind = "WPT", lat = 35 + k / 100, lon = 140}} end
for k = 1, 40 do pts[k] = {lat = 35, lon = 140 + k / 100} end
st.rte.legs = many
text, map = R.to_fms(st.rte, "2610", {[30] = {pts = pts}})
T.equal(map.n, 62, "102 rows with the arc's 40 points: 62 without them")
T.check(not text:find("\n28 ~ "), "no arc points")
st.rte.passed = {}
for k = 1, 50 do st.rte.passed[k] = {via = "DIRECT", fix = {ident = "Q" .. k, kind = "WPT", lat = 34, lon = 140 + k / 100}} end
text, map = R.to_fms(st.rte, "2610")
T.equal(map.n, 63, "112 rows with 50 passed legs: the last passed one kept")
T.check(text:find("\n11 Q50 DRCT ") and not text:find("\n11 Q49 DRCT "), "Q50, the last passed, kept")

-- INTC CRS: the start on the course into the waypoint, as far from it as
-- the airplane (estimate)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_to(st, fix("DELTA"))
R.activate(st)
R.exec(st)
local delta = fix("DELTA")
R.direct_to(st, delta, nil, {lat = 35.5, lon = 140.5})
R.intc_crs(st, 90)
R.exec(st, {lat = 35.6, lon = 140.6})
local from = R.legs(R.shown(st))[1].from
local var = N.variation(db, delta.lat, delta.lon) or 0
local back, d = R.course(delta.lat, delta.lon, from.lat, from.lon)
local _, d0 = R.course(35.6, 140.6, delta.lat, delta.lon)
T.check(math.abs(d - d0) < 0.1 and math.abs((back - (90 + var + 180) + 180) % 360 - 180) < 0.1,
    string.format("INTC CRS 090: from %.1f nm on the course into DELTA (%.1f true back; the airplane %.1f nm)", d, back, d0))

T.done()
