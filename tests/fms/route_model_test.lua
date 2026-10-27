-- Run from the repository root with LuaJIT: luajit tests/fms/route_model_test.lua
-- The FMC's route (6-1/6-2 step 5a; notes/ATA-34-61-FMC.md §18):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua
-- on the synthetic navigation data in tests/fms/data/navdb (airway Z1
-- ALPHA-BRAVO-CHARL-DELTA, CHARL to DELTA one way, BRAVO-ZZV shared with
-- Z2): ORIGIN, DEST and RUNWAY (FCOM p.1288-1289), the RTE pages' DIRECT
-- and airway segments, the airways' intersection, ROUTE FULL (FCOM
-- p.1296-1298, p.1435; FMSPG p.82-83), ACTIVATE, MOD, EXEC and ERASE (FCOM
-- p.1238, p.1290), X-Plane's flight plan file, the holds (step 7b: HOLD AT,
-- PPOS, the entries, EXIT HOLD, DELETE).
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

-- the holds (step 7b; FCOM p.1413-1419; FMSPG p.157-163, p.221-223)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.set_runway(st, "16R")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("CHARL"))
local h, err = R.hold_at(st, 2, nil)
T.check(h == 3 and not err, "HOLD AT BRAVO on the inactive route: the hold after the leg to BRAVO (FMSPG p.158)")
local hl = R.shown(st).legs[3]
T.check(R.is_hold(hl) and hl.pt == "HM" and hl.fix.ident == "BRAVO" and hl.turn == "R" and hl.time == 1.0,
    "a hold ended by the crew (HM), right turns, 1.0 minute")
T.equal(hl.crs, 7, "inbound the leg's course into BRAVO: north, 007 magnetic (FMSPG p.160)")
T.equal(idents(st), "ALPHA BRAVO BRAVO CHARL", "the legs")
T.equal(segs(st), "DIRECT ALPHA, Z1 CHARL", "the RTE segments as before: the hold in Z1's")
T.check(select(2, R.hold_at(st, 3, nil)) == R.INVALID_ENTRY and select(2, R.hold_at(st, 2, nil)) == R.INVALID_ENTRY,
    "not at a hold, nor twice")
T.equal(R.find_fix(R.shown(st), fix("BRAVO")), 2, "BRAVO's leg, not its hold")
T.equal(table.concat(R.holds(R.shown(st)), " "), "3", "the holds")
-- the default leg time (FMSPG p.222-223)
R.set_constraint(st, 2, {alt = 15000, akind = "A"}, nil)
R.hold_at(st, 4, nil)
T.equal(R.shown(st).legs[5].time, 1.0, "at CHARL, nothing above 14,000 ft: 1.0")
st.rte.legs[4].alt = 15000
table.remove(st.rte.legs, 5)
R.hold_at(st, 4, nil)
T.equal(R.shown(st).legs[5].time, 1.5, "CHARL at or above 15,000: 1.5 minutes")
table.remove(st.rte.legs, 5)
st.rte.legs[4].alt = nil
R.hold_at(st, 4, 35000)
T.equal(R.shown(st).legs[5].time, 1.5, "no constraint, cruise FL350: 1.5 minutes (estimate)")
table.remove(st.rte.legs, 5)
-- its entries
T.equal(R.hold_set(st, 3, {radial = 330}), nil, "QUAD/RADIAL 330")
T.check(hl.crs == 150 and hl.radial == 330, "the inbound course 150")
R.hold_set(st, 3, {crs = 90, turn = "L"})
T.check(hl.crs == 90 and hl.radial == nil and hl.turn == "L", "INBD CRS/DIR 090/L: no radial")
R.hold_set(st, 3, {dist = 5})
T.check(hl.dist == 5 and hl.time == nil, "LEG DIST: no time")
R.hold_set(st, 3, {time = 2})
T.check(hl.time == 2 and hl.dist == nil, "LEG TIME: no distance")
T.equal(R.hold_set(st, 2, {time = 2}), R.INVALID_ENTRY, "not a hold")
T.equal(R.hold_exit(st, 3), R.INVALID_ENTRY, "EXIT HOLD: not on the inactive route")
-- X-Plane's flight plan: the hold's fix, its racetrack, the fix again
local hpts = {{lat = 36.01, lon = 140.52}, {lat = 36.02, lon = 140.55}}
text, map = R.to_fms(st.rte, "2610", {[3] = {pts = hpts}})
T.check(text:find("\n11 BRAVO Z1 [^\n]*\n11 BRAVO DRCT [^\n]*\n28 ~ DRCT 0.000000 36.010000 140.520000\n28 ~ DRCT 0.000000 36.020000 140.550000\n28 ~ DRCT 0.000000 36.000000 140.500000\n11 CHARL Z1 "),
    "BRAVO, the hold's BRAVO, its points and BRAVO again, CHARL")
T.equal(map.leg[map.row[3]], 3, "the hold's row: its fix's")
T.equal(map.ident[map.row[3]], "BRAVO", "BRAVO")
-- active: the hold flown, EXIT HOLD, DELETE (FCOM p.1416, p.1419)
R.activate(st)
R.exec(st)
T.check(R.sequence(st, 2), "ALPHA and BRAVO passed: the hold active")
T.check(R.is_hold(st.rte.legs[1]), "the hold first")
T.equal(R.hold_exit(st, 1), nil, "EXIT HOLD")
T.check(st.mod and st.mod.legs[1].exit and not st.rte.legs[1].exit, "armed in the modification")
R.exec(st)
T.check(st.rte.legs[1].exit, "EXEC: armed")
T.equal(R.hold_exit(st, 1), R.INVALID_ENTRY, "once")
T.equal(R.legs_delete(st, 1), nil, "DELETE the hold flown")
local nx = st.mod.legs[1]
T.check(nx.fix.ident == "CHARL" and nx.dto and nx.dto_exec, "CHARL direct (FCOM p.1416)")
R.exec(st, {lat = 36.1, lon = 140.6})
T.check(st.rte.legs[1].from.lat == 36.1, "from where the airplane is at EXEC")
-- PPOS (FCOM p.1415): its fix at EXEC, N36E140
h, err = R.hold_ppos(st, {lat = 36.2, lon = 140.7, trk = 52.4}, nil)
T.check(h == 1 and not err and st.mod.legs[1].fix.ident == R.PPOS and st.mod.legs[1].crs == 52, "PPOS: the hold first, inbound the track")
T.check(not st.mod.legs[2].dto and st.mod.legs[2].from == nil, "the leg on from its fix")
R.exec(st, {lat = 36.25, lon = 140.75, trk = 60})
local pp = st.rte.legs[1]
T.check(pp.fix.ident == "N36E140" and pp.fix.lat == 36.25 and pp.fix.kind == "LL", "EXEC: the fix there, N36E140")
T.equal(pp.crs, 60, "inbound the track at EXEC (estimate)")
T.check(R.sequence(st, 1), "the hold sequenced (LNAV: its exit)")
T.check(st.rte.passed[#st.rte.passed] == pp and st.rte.legs[1].fix.ident == "CHARL", "CHARL next")
T.equal(select(2, R.hold_ppos(R.new(N, db), {lat = 36, lon = 140})), R.INVALID_ENTRY, "PPOS: not without an active route")

-- CRS REVERSAL AT FA FIX (step 7c; FCOM p.1435): the route coming to the
-- final approach fix against the final approach course
local function rev(legs)
    local s2 = R.new(N, db)
    s2.rte.legs, s2.rte.runway = legs, {ident = "RW", lat = 35.3, lon = 139.8}
    return R.crs_reversal(s2, s2.rte)
end
local FAF = {ident = "FAFX", kind = "WPT", lat = 35.0, lon = 140.0}
local RWX = {ident = "RWX", kind = "RWY", lat = 34.92, lon = 140.04}
local SOUTH = {ident = "SOUTH", kind = "WPT", lat = 34.8, lon = 140.1}
local NORTH = {ident = "NORTH", kind = "WPT", lat = 35.1, lon = 139.95}
T.check(not rev({{via = "DIRECT", fix = NORTH}, {via = "APPR", pt = "CF", fix = FAF, crs = 164, faf = true}, {via = "APPR", fix = RWX}}),
    "from the north on to the runway south-south-east: no reversal")
T.check(rev({{via = "DIRECT", fix = SOUTH}, {via = "APPR", pt = "CF", fix = FAF, crs = 164, faf = true}, {via = "APPR", fix = RWX}}),
    "from the south, the final course back south: CRS REVERSAL AT FA FIX")
T.check(not rev({{via = "DIRECT", fix = SOUTH}, {via = "APPR", fix = FAF}, {via = "APPR", pt = "PI", fix = FAF, crs = 300, turn = "L"},
    {via = "APPR", pt = "CF", fix = FAF, crs = 164, faf = true}, {via = "APPR", fix = RWX}}), "with a procedure turn at it: none")
T.check(not rev({{via = "DIRECT", fix = SOUTH}, {via = "APPR", fix = FAF}, {via = "APPR", pt = "HF", fix = FAF, crs = 164},
    {via = "APPR", pt = "CF", fix = FAF, crs = 164, faf = true}, {via = "APPR", fix = RWX}}), "with a hold in lieu of it: none")
T.check(not rev({{via = "DIRECT", fix = SOUTH}}), "no final approach fix: none")

-- the lateral offset (step 7d; FCOM p.1298-1299; FMSPG p.155-156)
local function off_legs(legs)
    local s3 = R.new(N, db)
    s3.rte.legs, s3.rte.runway = legs, {ident = "RW", lat = 34.9, lon = 140.0}
    return R.offset_legs(s3.rte)
end
local P1, P2 = {ident = "P1", kind = "WPT", lat = 35.0, lon = 140.0}, {ident = "P2", kind = "WPT", lat = 35.5, lon = 140.0}
local P3, P4 = {ident = "P3", kind = "WPT", lat = 35.5, lon = 140.6}, {ident = "P4", kind = "WPT", lat = 35.1, lon = 140.05}
T.equal(off_legs({{via = "DIRECT", fix = P1}, {via = "J1", fix = P2}, {via = "J1", fix = P3}}), 3, "to the end of the route")
T.equal(off_legs({{via = "DIRECT", fix = P1}, {via = "J1", fix = P2}, {via = "STAR1", proc = "STAR", pt = "TF", fix = P3}}), 2, "not into a STAR")
T.equal(off_legs({{via = "DIRECT", fix = P1}, {disc = true}, {via = "DIRECT", fix = P2}}), 1, "not past a discontinuity")
T.equal(off_legs({{via = "DIRECT", fix = P1}, {via = "DIRECT", fix = P2}, {via = "DIRECT", pt = "HM", fix = P2}, {via = "DIRECT", fix = P3}}), 2, "not into a hold")
T.equal(off_legs({{via = "DIRECT", fix = P1}, {via = "DIRECT", fix = P2}, {via = "DIRECT", fix = P4}}), 2, "a course change of 135 or more ends it after its leg")
T.equal(off_legs({{via = "DIRECT", fix = P1}, {via = "APPR", pt = "VA", crs = 90, alt = 3000}, {via = "DIRECT", fix = P2}}), 1, "not a heading leg")
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("CHARL"))
T.equal(R.set_offset(st, 20, true), R.INVALID_ENTRY, "OFFSET: not on the inactive route")
R.activate(st)
R.exec(st)
T.check(not R.offset_allowed(st, false), "not on the ground")
T.equal(R.set_offset(st, 20, false), R.INVALID_ENTRY, "INVALID ENTRY on the ground")
T.equal(R.set_offset(st, 20, true), nil, "R20 in the air")
T.check(st.mod and st.mod.offset == 20 and not st.rte.offset, "in the modification")
R.exec(st)
T.equal(st.rte.offset, 20, "EXEC: the active route's")
T.equal(R.set_offset(st, 100, true), R.INVALID_ENTRY, "100: INVALID ENTRY")
T.equal(R.set_offset(st, -5, true), nil, "L5")
T.equal(st.mod.offset, -5, "left: negative")
R.erase(st)
T.equal(R.set_offset(st, 0, true), nil, "0 cancels it")
R.exec(st)
T.equal(st.rte.offset, nil, "cancelled")
T.equal(R.set_offset(st, 0, true), R.INVALID_DELETE, "nothing to cancel: INVALID DELETE")
R.set_offset(st, 10, true)
R.exec(st)
R.direct_to(st, fix("CHARL"), nil, {lat = 35.5, lon = 140.5})
T.equal(st.mod.offset, nil, "DIRECT TO cancels it (FCOM p.1299)")
R.exec(st, {lat = 35.5, lon = 140.5})
T.check(R.offset_allowed(st, true), "a new one on the direct-to's leg (FCOM p.1298: not on a SID, STAR or transition)")
st.rte.offset = 10
R.hold_ppos(st, {lat = 35.6, lon = 140.5, trk = 0})
T.equal(st.mod.offset, nil, "PPOS deletes it (FMSPG p.158)")
R.erase(st)
st.rte.legs[1].proc = "SID"
T.check(not R.offset_allowed(st, true), "not on a SID (FMSPG p.155)")

-- ABEAM PTS (step 7e2; FCOM p.1333-1334; FMSPG p.136-139): ALPHA, BRAVO,
-- CHARL and DELTA north along 140.5 E; the airplane east of ALPHA, direct
-- to DELTA
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("DELTA"))
R.activate(st)
R.exec(st)
local ppos = {lat = 35.5, lon = 141.0}
T.check(not R.abeam_offered(st), "no ABEAM PTS without a direct-to")
R.direct_to(st, fix("DELTA"), nil, ppos)
T.equal(idents(st), "DELTA", "DIRECT TO DELTA: ALPHA, BRAVO and CHARL passed by")
T.check(R.abeam_offered(st) and not R.abeam_selected(st), "ABEAM PTS> offered (FCOM p.1334)")
T.equal(R.abeam_points(st, ppos), nil, "ABEAM PTS")
T.equal(idents(st), "ALP01 BRA02 CHA03 DELTA", "their abeam points: the first three characters and a number (FCOM p.1250)")
T.check(R.abeam_selected(st) and not R.abeam_offered(st), "SELECTED (FMSPG p.138)")
local legs = R.legs(R.shown(st))
local crs0, len0 = R.course(ppos.lat, ppos.lon, 37.0, 140.5)
local ok_line = true
for k = 1, 3 do
    local f = legs[k].fix
    local c, d = R.course(ppos.lat, ppos.lon, f.lat, f.lon)
    if math.abs(c - crs0) > 0.01 or d >= len0 then ok_line = false end
end
T.check(ok_line, "on the direct path to DELTA, before it")
local a1 = legs[1].fix
local brg, dist = R.course(35.5, 140.5, a1.lat, a1.lon)
local cpt = R.course(a1.lat, a1.lon, 37.0, 140.5)
T.check(a1.kind == "PBD" and a1.place.ident == "ALPHA" and math.abs(brg - a1.brg) < 1e-6 and math.abs(dist - a1.dist) < 1e-6,
    "ALP01: from ALPHA, its bearing and distance")
T.check(math.abs(((brg - cpt) % 360) - 90) < 0.5, "abeam ALPHA: square to the path (FMSPG p.136)")
T.check(legs[1].dto and legs[1].dto_exec and not legs[4].dto and not legs[4].dto_exec, "the direct-to's first leg the first abeam point's")
T.check(not legs[2].alt and not legs[2].spd, "no constraints (FMSPG p.137)")
T.equal(R.intc_crs(st, 300), R.INVALID_ENTRY, "no INTC CRS after it (FMSPG p.139's figure)")
T.equal(R.abeam_points(st, ppos), R.INVALID_ENTRY, "once")
R.exec(st, {lat = 35.51, lon = 140.99})
T.check(R.legs(st.rte)[1].from.lat == 35.51, "EXEC: from where the airplane is then")
local xp = R.to_fms(st.rte, "2610")
T.check(xp:find("\n28 ALP01 DRCT ") and xp:find("\n28 CHA03 DRCT ") and xp:find("\n11 DELTA DRCT "), "X-Plane's flight plan: the abeam points as lat/lon rows")
-- another direct-to past ALP01 and BRA02: a new point from ALPHA, the
-- lowest number free (estimate)
R.direct_to(st, R.legs(st.rte)[3].fix, nil, {lat = 35.6, lon = 141.2})
R.abeam_points(st, {lat = 35.6, lon = 141.2})
T.equal(idents(st), "ALP04 BRA05 CHA03 DELTA", "ALP01's from ALPHA again (FMSPG p.136); 01-03 still the active route's: 04 and 05")
R.erase(st)
-- a change removes the prompt (FCOM p.1334); INTC CRS too
R.direct_to(st, fix("DELTA"), nil, ppos)
R.set_constraint(st, 1, {alt = 10000}, 35000)
T.check(not R.abeam_offered(st), "another change: no ABEAM PTS>")
R.erase(st)
R.direct_to(st, fix("DELTA"), nil, ppos)
R.intc_crs(st, 10)
T.check(not R.abeam_offered(st), "INTC CRS: no ABEAM PTS> (FCOM p.1334)")
R.erase(st)
-- a direct-to waypoint not in the route: none passed by
R.direct_to(st, fix("ZZV"), nil, ppos)
local before = idents(st)
T.equal(R.abeam_points(st, ppos), nil, "ABEAM PTS to ZZV, not in the route")
T.check(idents(st) == before and R.abeam_selected(st), "no points: SELECTED (estimate)")
R.erase(st)
-- procedures: not their points but a departure's last (FMSPG p.137)
st.rte.legs[1].proc, st.rte.legs[2].proc, st.rte.legs[3].proc = "SID", "SID", nil
R.direct_to(st, fix("DELTA"), nil, ppos)
R.abeam_points(st, ppos)
T.equal((idents(st):gsub("%d", "#")), "BRA## CHA## DELTA", "ALPHA a SID's point: none; BRAVO the SID's last: one")
R.erase(st)
-- a lat/lon waypoint's a lat/lon one; 700 nm across at most (FMSPG p.136-137)
st = R.new(N, db)
st.rte.legs = {{via = "DIRECT", fix = {kind = "LL", ident = "N40E148", lat = 40, lon = 148}},
    {via = "DIRECT", fix = {kind = "WPT", ident = "FARAW", lat = 41, lon = 157}},
    {via = "DIRECT", fix = {kind = "WPT", ident = "ENDPT", lat = 45, lon = 140.5}}}
st.active = true
R.direct_to(st, st.rte.legs[3].fix, nil, {lat = 35, lon = 140.5})
R.abeam_points(st, {lat = 35, lon = 140.5})
T.check(idents(st):match("^N4%dE140 ENDPT$"), "N40E148 abeam: a lat/lon waypoint (N4xE140); FARAW 750 nm across: none: " .. idents(st))

-- the waypoints the crew defines (step 7e3a; FCOM p.1245, p.1249-1250)
local ll = R.parse_latlon("N47W008")
T.check(ll and ll.kind == "LL" and ll.ident == "N47W008" and ll.lat == 47 and ll.lon == -8, "N47W008")
ll = R.parse_latlon("N4715.4W00803.4")
T.check(ll and ll.ident == "N47W008" and math.abs(ll.lat - (47 + 15.4 / 60)) < 1e-9 and math.abs(ll.lon + (8 + 3.4 / 60)) < 1e-9,
    "N4715.4W00803.4: shown N47W008 (FCOM p.1250)")
ll = R.parse_latlon("S3330.0E151")
T.check(ll and ll.ident == "S33E151" and math.abs(ll.lat + 33.5) < 1e-9 and ll.lon == 151, "the minutes on one part only: S3330.0E151")
T.check(not R.parse_latlon("N47W08") and not R.parse_latlon("N4760.0W008") and not R.parse_latlon("N91E000")
    and not R.parse_latlon("N47W181") and not R.parse_latlon("ALPHA") and not R.parse_latlon("N4715W008"),
    "not: two digits of longitude, 60 minutes, 91 N, 181 W, an identifier, minutes without the tenth")
local e = R.parse_pbd("SEA330/10")
T.check(e and e.place == "SEA" and e.brg == 330 and e.dist == 10 and not e.place2, "SEA330/10")
e = R.parse_pbd("ABC180.0/026.4")
T.check(e and e.place == "ABC" and e.brg == 180 and math.abs(e.dist - 26.4) < 1e-9, "ABC180.0/026.4 (FIX INFO's copy: FCOM p.1359)")
e = R.parse_pbd("SEA240/OLM320")
T.check(e and e.place == "SEA" and e.brg == 240 and e.place2 == "OLM" and e.brg2 == 320 and not e.dist, "SEA240/OLM320")
e = R.parse_pbd("ZA001090/5")
T.check(e and e.place == "ZA001" and e.brg == 90 and e.dist == 5, "a place with digits: ZA001090/5")
e = R.parse_pbd("SEA360/7")
T.check(e and e.brg == 0, "360: north")
T.check(not R.parse_pbd("SEA361/10") and not R.parse_pbd("SEA330/0") and not R.parse_pbd("SEA33/10") and not R.parse_pbd("330/10")
    and not R.parse_pbd("250/10000A") and not R.parse_pbd("SEA330/1000") and not R.parse_pbd("ABCDEF330/10"),
    "not: 361, distance 0, two digits of bearing, no place, a constraint, 1000 nm, a place of six")
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
local alpha, bravo = fix("ALPHA"), fix("BRAVO")
local f1 = R.pbd_fix(st, R.parse_pbd("ALPHA097/10"), alpha)
local c1, d1 = R.course(alpha.lat, alpha.lon, f1.lat, f1.lon)
T.check(f1.kind == "PBD" and f1.ident == "ALP01" and math.abs(d1 - 10) < 1e-6 and math.abs(c1 - 90) < 1e-6,
    "ALPHA097/10: ALP01, 10 nm on 090 true (097 magnetic, the variation 7 W)")
R.add_to(st, f1)
T.equal(R.pbd_fix(st, R.parse_pbd("ALPHA180/5"), alpha).ident, "ALP02", "the next number (FCOM p.1250)")
local cands = R.candidates(st, "ALP01", 35, 140)
T.check(#cands == 1 and cands[1] == f1, "ALP01 by its name: the route's")
T.equal(#R.candidates(st, "ALP01", 35, 140, true), 0, "but not for the database's points alone (REF NAV DATA, FIX INFO)")
-- place bearing/place bearing: ALPHA 097 (090 true) and BRAVO 142 (135
-- true) meet east of ALPHA
local f2 = R.pbd_fix(st, R.parse_pbd("ALPHA097/BRAVO142"), alpha, bravo)
local ca = R.course(alpha.lat, alpha.lon, f2.lat, f2.lon)
local cb = R.course(bravo.lat, bravo.lon, f2.lat, f2.lon)
T.check(f2.ident == "ALP02" and math.abs(ca - 90) < 0.01 and math.abs(cb - 135) < 0.01,
    "ALPHA097/BRAVO142: on both radials (" .. string.format("%.3f %.3f", ca, cb) .. ")")
T.equal(R.pbd_fix(st, R.parse_pbd("ALPHA097/BRAVO007"), alpha, bravo), nil, "radials that do not meet: none")

-- FIX INFO's geometry (step 7e3b; FCOM p.1358-1359; FMSPG p.166-169): the
-- route RW16R, ALPHA, BRAVO, CHARL; the airplane at 35 N 140 E, just
-- short of RW16R; a fix 12.9 nm east of ALPHA-BRAVO
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.set_runway(st, "16R")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
R.add_to(st, fix("CHARL"))
local here = {lat = 35, lon = 140}
T.equal(R.fix_path(st, here), nil, "no active route: no path")
R.activate(st)
R.exec(st)
local path = R.fix_path(st, here)
T.check(path and #path.segs == 3, "the path: RW16R-ALPHA, ALPHA-BRAVO, BRAVO-CHARL")
T.check(path.at < 0 and path.at > -1, "the airplane just short of the first segment's start: " .. path.at)
local seg1 = select(2, R.course(35.01, 140.005, 35.5, 140.5))
local fx = {lat = 35.95, lon = 140.7646}
local across = (140.7646 - 140.5) * 60 * math.cos(math.rad(35.95))
local ab = R.fix_abeam(path, fx)
local _, ab_d = R.course(fx.lat, fx.lon, ab.lat, ab.lon)
T.check(math.abs(ab.lon - 140.5) < 1e-6 and math.abs(ab.lat - 35.95) < 0.01, "ABEAM: on ALPHA-BRAVO at the fix's latitude")
T.near(ab_d, across, 0.1, "square to it: " .. string.format("%.2f", ab_d) .. " nm")
T.near(ab.dtg, seg1 + (ab.lat - 35.5) * 60 - path.at, 0.1, "its distance to go along the path")
local rx = R.fix_radial(path, fx, 270, 512)
T.check(rx and math.abs(rx.lon - 140.5) < 1e-6 and math.abs(rx.lat - 35.95) < 0.01, "the radial 270 true: across ALPHA-BRAVO")
T.equal(R.fix_radial(path, fx, 90, 512), nil, "090: away from the route: none")
T.equal(R.fix_radial(path, fx, 270, 10), nil, "beyond the radial's reach: none")
local cx = R.fix_circle(path, fx, 20)
local _, cx_d = R.course(fx.lat, fx.lon, cx.lat, cx.lon)
local h = math.sqrt(20 ^ 2 - across ^ 2) / 60
T.check(math.abs(cx.lon - 140.5) < 1e-6 and math.abs(cx.lat - (35.95 - h)) < 0.01 and math.abs(cx_d - 20) < 0.01,
    "the circle of 20 nm: the nearer crossing, on ALPHA-BRAVO (FCOM p.1358: the closest of the two)")
T.equal(R.fix_circle(path, fx, 5), nil, "a circle short of the route: none")
T.equal(R.fix_abeam(path, {lat = 34.5, lon = 142.0}), nil, "no segment square to it: none (FMSPG p.168: INVALID ENTRY)")
local fx2 = {lat = 35.15, lon = 140.40}
local past = R.fix_path(st, {lat = 35.45, lon = 140.45})
T.check(past.at > 0 and R.fix_abeam(past, fx2).dtg < 0, "a fix abeam the first leg, the airplane past it: negative (FMSPG p.168)")

T.done()
