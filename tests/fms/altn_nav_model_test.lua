-- Run from the repository root with LuaJIT: luajit tests/fms/altn_nav_model_test.lua
-- A CDU's alternate navigation (6-1/6-2 step 11e1; notes/ATA-34-61-FMC.md
-- §102; FCOM p.1421-1424; FMSPG p.247-249): the copy of the FMC's active
-- route without its conditional waypoints and holds, its discontinuities
-- kept; great circle courses and distances; the active waypoint sequenced
-- abeam with the LAST waypoint's altitude; the IRS LEGS entries (a later
-- waypoint, a latitude/longitude with a discontinuity after it, the active
-- line direct from the present position, other INVALID ENTRY), DELETE,
-- MOD, EXEC and ERASE.
local T = dofile("tests/lib/check.lua")("altn_nav_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.altn_nav_model.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

local function fix(ident, lat, lon) return {ident = ident, lat = lat, lon = lon, kind = "WPT"} end
local A, B, C, Dd = fix("AAA", 35.0, 140.0), fix("BBB", 35.5, 140.0), fix("CCC", 36.0, 140.5), fix("DDD", 36.5, 141.0)
-- the FMC's active route: AAA, a conditional leg, BBB, a hold at BBB, a
-- discontinuity, CCC, DDD; AAA's leg from ORG passed
local route = {
    legs = {{fix = A}, {name = "(4000)"}, {fix = B}, {fix = B, pt = "HM"}, {disc = true}, {fix = C}, {fix = Dd}},
    passed = {{fix = fix("ORG", 34.8, 140.0)}},
    dest = fix("DST", 37.0, 141.5),
}
local s = M.new()
M.copy(s, route, R.is_hold, {lat = 34.9, lon = 140.0})
local function idents(r)
    local t = {}
    for _, l in ipairs(r.legs) do t[#t + 1] = l.disc and "*" or l.ident end
    return table.concat(t, ",")
end
T.equal(idents(s), "AAA,BBB,*,CCC,DDD", "the copy: no conditional waypoint, no hold, the discontinuity kept (FCOM p.1421)")
T.equal(s.dest.ident, "DST", "the destination")
T.equal(s.from.ident, "ORG", "the active leg from the last waypoint passed")
T.equal(s.last.ident, "ORG", "LAST")

-- great circle courses and distances
T.near(M.distance(A, B), 30.0, 0.05, "AAA to BBB: 30 nm (0.5 degree of latitude)")
T.near(M.course(A, B), 0, 1e-6, "north: 000")
T.near(M.course(B, A), 180, 1e-6, "south: 180")
local along, cross = M.along_cross(A, B, {lat = 35.25, lon = 140.1})
T.near(along, 15.0, 0.1, "along track: 15 nm")
T.check(cross > 4.8 and cross < 4.95, "across: about 4.9 nm right (east of a northbound leg)")

-- the IRS LEGS rows: the active leg's course from its start, no distance
local rows = M.rows(s, 1, 5)
T.equal(rows[1].ident, "AAA", "row 1 AAA")
T.near(rows[1].crs, 0, 0.01, "its course from ORG: north")
T.equal(rows[1].dist, nil, "no distance for the active leg (FMSPG p.249)")
T.near(rows[2].dist, 30.0, 0.05, "BBB: 30 nm from AAA")
T.check(rows[3].disc, "row 3 the discontinuity")
T.equal(rows[4].crs, nil, "CCC after a discontinuity: no course")

-- sequencing abeam: before, then after
T.check(not M.sequence(s, {lat = 34.99, lon = 140.05}, 5000), "short of AAA: not sequenced")
T.check(M.sequence(s, {lat = 35.01, lon = 140.05}, 5200), "abeam AAA: sequenced (estimate)")
T.equal(idents(s), "BBB,*,CCC,DDD", "BBB active")
T.check(s.last.ident == "AAA" and s.last_alt == 5200, "LAST AAA with its crossing altitude (FMSPG p.250)")

-- entries: a later waypoint over line 1 (direct from the present position)
local pos = {lat = 35.2, lon = 140.2}
T.equal(M.enter(s, 1, "CCC", nil, pos), nil, "CCC over BBB: accepted")
T.equal(idents(M.shown(s)), "CCC,DDD", "MOD: direct to CCC (the legs before it gone)")
T.check(s.mod and s.mod.from.lat == 35.2, "from the present position (FCOM p.1421)")
T.equal(idents(s), "BBB,*,CCC,DDD", "the active route unchanged before EXEC")
M.erase(s)
T.check(s.mod == nil and idents(M.shown(s)) == "BBB,*,CCC,DDD", "ERASE: the active route again")
-- a latitude/longitude before line 2: a discontinuity after it
local ll = R.parse_latlon("N3530.0E14030.0")
T.equal(M.enter(s, 2, "N3530.0E14030.0", ll, pos), nil, "a latitude/longitude on line 2: accepted")
T.equal(idents(M.shown(s)), "BBB,N35E140,*,CCC,DDD", "inserted before the discontinuity (none added: one there)")
T.check(M.exec(s) and s.mod == nil, "EXEC")
T.equal(idents(s), "BBB,N35E140,*,CCC,DDD", "active")
T.equal(M.enter(s, 2, "N3545.0E14030.0", R.parse_latlon("N3545.0E14030.0"), pos), nil, "another on line 2")
T.equal(idents(M.shown(s)), "BBB,N35E140,*,N35E140,*,CCC,DDD", "a discontinuity after it (as the FMC's LEGS)")
M.erase(s)
-- not in the route and not a latitude/longitude
T.equal(M.enter(s, 2, "ZZZ", nil, pos), M.INVALID_ENTRY, "an identifier not in the route: INVALID ENTRY (FMSPG p.248)")
T.equal(M.enter(s, 9, "CCC", nil, pos), M.INVALID_ENTRY, "past the end: INVALID ENTRY")
-- the discontinuity closed by entering the waypoint after it
T.equal(M.enter(s, 3, "CCC", nil, pos), nil, "CCC over the discontinuity: accepted")
T.equal(idents(M.shown(s)), "BBB,N35E140,CCC,DDD", "the discontinuities closed")
M.exec(s)
-- DELETE
T.equal(M.delete(s, 1), M.INVALID_DELETE, "the active waypoint: INVALID DELETE (estimate)")
T.equal(M.delete(s, 2), nil, "N35E140 deleted")
T.equal(idents(M.shown(s)), "BBB,CCC,DDD", "BBB to CCC joined")
M.exec(s)
T.check(M.enter(s, 2, "N3600.0E14030.0", R.parse_latlon("N3600.0E14030.0"), pos) == nil, "(a new waypoint)")
T.equal(M.delete(s, 3), M.INVALID_DELETE, "a discontinuity: INVALID DELETE (closed by entering the next waypoint)")
M.erase(s)

-- the modification sequenced with the route when it starts the same
s = M.new()
M.copy(s, route, R.is_hold, nil)
M.enter(s, 3, "DDD", nil, pos)
T.equal(idents(M.shown(s)), "AAA,BBB,DDD", "(MOD: DDD after BBB)")
M.sequence(s, {lat = 35.01, lon = 140.0}, 5000)
T.equal(idents(M.shown(s)), "BBB,DDD", "AAA passed: the modification sequenced too")
T.equal(idents(s), "BBB,*,CCC,DDD", "the active route sequenced")

-- a new copy drops a CDU's modification (the FMCs back)
M.copy(s, route, R.is_hold, nil)
T.check(s.mod == nil and idents(s) == "AAA,BBB,*,CCC,DDD", "copied again: the FMC's route")

-- (6-1/6-2 step 11e2) IRS PROGRESS (FCOM p.1425-1426; FMSPG p.250-251):
-- the leg ORG to AAA northbound, the airplane 0.1 degree short of AAA
-- and 0.05 degree east
s = M.new()
M.copy(s, route, R.is_hold, nil)
local here = {lat = 34.9, lon = 140.05}
local pp = M.progress(s, here)
T.equal(pp.to.ident, "AAA", "TO AAA")
T.near(pp.to.dtg, 6.0, 0.05, "its DTG from the abeam point: 6 nm (FMSPG p.250)")
T.check(pp.xtk > 2.4 and pp.xtk < 2.5, "XTK ERROR: about 2.46 nm right: " .. pp.xtk)
T.near(pp.dtk, 0, 0.01, "DTK: north")
T.equal(pp.next.ident, "BBB", "NEXT BBB")
T.near(pp.next.dtg, 36.0, 0.1, "NEXT's DTG: TO's and AAA to BBB")
local total = 6 + M.distance(A, B) + M.distance(B, C) + M.distance(C, Dd) + M.distance(Dd, route.dest)
T.check(pp.dest.ident == "DST" and pp.dest.title == "DEST", "DEST DST")
T.near(pp.dest.dtg, total, 0.2, "along the route (the discontinuity's waypoints joined: estimate)")
-- 4L: a route waypoint ENROUTE WPT, a latitude/longitude DIR TO ALTERNATE
T.equal(M.set_alternate(s, "CCC", nil), nil, "CCC on 4L")
pp = M.progress(s, here)
T.equal(pp.dest.title, "ENROUTE WPT", "ENROUTE WPT (FMSPG p.251)")
T.near(pp.dest.dtg, 6 + M.distance(A, B) + M.distance(B, C), 0.2, "along the route to CCC")
local alt_ll = R.parse_latlon("N3700.0E14100.0")
T.equal(M.set_alternate(s, "N3700.0E14100.0", alt_ll), nil, "a latitude/longitude on 4L")
pp = M.progress(s, here)
T.equal(pp.dest.title, "DIR TO ALTERNATE", "DIR TO ALTERNATE")
T.near(pp.dest.dtg, M.distance(here, alt_ll), 0.01, "direct from the airplane")
T.equal(M.set_alternate(s, "ZZZ", nil), M.INVALID_ENTRY, "another: INVALID ENTRY")
-- a route change drops it; MOD while modified
M.enter(s, 2, "CCC", nil, pos)
T.check(s.alt == nil, "a route change: the alternate gone (FMSPG p.251)")
T.equal(M.progress(s, here).dest.title, "MOD", "MOD with a modification (FMSPG p.250)")
M.erase(s)
T.equal(M.progress(s, here).dest.title, "DEST", "ERASE: DEST again")
-- an enroute alternate passed: DEST again
M.set_alternate(s, "AAA", nil)
M.sequence(s, {lat = 35.01, lon = 140.0}, 5000)
T.check(s.alt == nil, "the enroute alternate passed: DEST again (FMSPG p.251)")
T.equal(M.progress(s, nil).to, nil, "no position: no data")

T.done()
