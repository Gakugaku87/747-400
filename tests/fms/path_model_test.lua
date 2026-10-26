-- Run from the repository root with LuaJIT: luajit tests/fms/path_model_test.lua
-- The FMC's lateral path (6-1/6-2 step 6a; notes/ATA-34-61-FMC.md §26):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua.
-- The great circles' courses and cross-track distances, each leg type's
-- element (lines, courses, headings, arcs) with the conditional legs' ends
-- as predicted (FCOM p.1245, p.1249), an RF leg from the synthetic CIFP of
-- ZZBB (FCOM p.1247), the fly-by turns (estimate: 25 degrees of bank).
local T = dofile("tests/lib/check.lua")("path_model")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")

local rad = math.pi / 180
local function dist(a, b) local _, d = M.course(a, b) return d end
local function on_line(a, crs, p) local xt = M.track(a, crs, p) return math.abs(xt) < 0.02 end
-- the variation everywhere: 7 degrees west (true = magnetic - 7)
local env = {var = function() return -7 end, alt = 0}

-- the great circle
local A, B, C = {lat = 35.0, lon = 140.0}, {lat = 35.5, lon = 140.0}, {lat = 35.5, lon = 140.6}
local c, d = M.course(A, B)
T.near(c, 0, 1e-6, "A to B: north")
T.near(d, 30.02, 0.001, "A to B: 30.02 nm (0.5 degrees on a sphere of 3440.065 nm)")
local p = M.point(A, 45, 10)
T.near(dist(A, p), 10, 1e-6, "a point 10 nm away")
T.near((M.course(A, p)), 45, 1e-6, "on course 045")
local xt, at = M.track(A, 0, {lat = 35.25, lon = 140.1})
T.check(xt > 4.8 and xt < 5.0, "east of a northbound course: right, positive: " .. xt)
T.near(at, 15.0, 0.05, "15 nm along it")
xt, at = M.track(A, 0, {lat = 34.9, lon = 139.9})
T.check(xt < 0 and at < 0, "west and behind: left, before: " .. xt .. " " .. at)
T.near(M.course_at(B, (M.course(B, C)), dist(B, C)), (M.course(C, B) + 180) % 360, 1e-6,
    "the great circle's course at its end: the final course")

-- lines: the FMC's own legs and TF
local path = M.build({{via = "DIRECT", fix = B}, {via = "J1", fix = C, pt = "TF"}}, A, env)
T.check(path[1].kind == "line" and path[1].a == A and path[1].b == B and path[1].term == "fix", "DIRECT B: the line from A")
T.near(path[1].len, 30.02, 0.001, "its length")
T.check(path[2].kind == "line" and path[2].a == B and path[2].b == C, "TF C: the line from B")
T.near(path[2].crs, 89.83, 0.01, "east along 35.5 N: the great circle's course at B")
T.near(M.end_course(path[2]), 90.17, 0.01, "and at C")

-- the fly-by turn at B: 250 kt, 25 degrees of bank
local tr = M.turn(path[1], path[2], 250)
local r = (250 * 1852 / 3600) ^ 2 / (9.80665 * math.tan(25 * rad)) / 1852
T.near(tr.r, r, 1e-6, "the radius at 250 kt and 25 degrees: about 1.95 nm")
T.near(tr.r, 1.953, 0.001, "1.95 nm")
T.equal(tr.dir, "R", "a right turn")
T.near(tr.delta, 89.83, 0.01, "89.8 degrees")
T.near(tr.d, tr.r * math.tan(tr.delta / 2 * rad), 1e-6, "it starts r tan(delta / 2) before B")
T.near(dist(tr.t1, B), tr.d, 1e-4, "t1 before B")
T.near(dist(tr.t2, B), tr.d, 1e-4, "t2 after it")
T.near(dist(tr.center, tr.t1), tr.r, 1e-3, "the centre r from t1")
T.near(dist(tr.center, tr.t2), tr.r, 1e-3, "and from t2")
T.check(M.track(A, 0, tr.center) > 0, "the centre right of the leg in")
T.check(M.turn(path[1], path[2], 450).r > 6, "at 450 kt a wider turn")
-- flown over the fix
local over = M.build({{via = "DIRECT", fix = B, flyover = true}, {via = "DIRECT", fix = C}}, A, env)
T.check(M.turn(over[1], over[2], 250) == nil, "a fly-over fix: no fly-by")
local back = M.build({{via = "DIRECT", fix = B}, {via = "DIRECT", fix = {lat = 35.0, lon = 139.8}}}, A, env)
T.check(M.turn(back[1], back[2], 250) == nil, "a turn of more than 135 degrees: over the fix")
local against = M.build({{via = "DIRECT", fix = B}, {pt = "TF", fix = C, turn = "L"}}, A, env)
T.check(M.turn(against[1], against[2], 250) == nil, "a right turn where the procedure turns left: the long way, over the fix")
local short = M.build({{via = "DIRECT", fix = B}, {via = "DIRECT", fix = M.point(B, 90, 1)}}, A, env)
local st = M.turn(short[1], short[2], 250)
T.near(st.d, 0.5, 1e-3, "a 1 nm leg out: the turn at most half of it")
T.near(st.r, 0.5 / math.tan(45 * rad), 0.01, "a tighter radius")
local straight = M.build({{via = "DIRECT", fix = B}, {via = "DIRECT", fix = M.point(B, 0.5, 20)}}, A, env)
T.check(M.turn(straight[1], straight[2], 250) == nil, "straight on: no turn")

-- a discontinuity: no path into the waypoint after it
path = M.build({{via = "DIRECT", fix = B}, {disc = true}, {via = "DIRECT", fix = C}}, A, env)
T.check(path[2].kind == "disc", "the discontinuity: no path")
T.check(path[3].kind == "none" and path[3].b == C, "C after it: no path in, its fix")

-- a direct-to: from its start
local from = {lat = 35.2, lon = 140.3}
path = M.build({{via = "DIRECT", fix = C, dto = true, from = from}}, A, env)
T.check(path[1].kind == "line" and path[1].a == from and path[1].b == C, "a direct-to: the line from its start")

-- a departure: heading 337 to 600 ft, heading 045 to intercept the course
-- 090 into ZZV, ZZV (ZZAA's ZULU1 from RW34L: tests/fms/data/navdb)
local RWY = {lat = 34.983333, lon = 140.016667}
local ZZV = {ident = "ZZV", lat = 35.2, lon = 140.2}
path = M.build({
    {pt = "VA", crs = 337, alt = 600, altterm = true, name = "(600)"},
    {pt = "VI", crs = 45, turn = "R", name = "(INTC)"},
    {pt = "CF", fix = ZZV, crs = 90, dist = 8},
}, RWY, {var = env.var, alt = 98})
local va, vi, cf = path[1], path[2], path[3]
T.check(va.kind == "heading" and va.term == "alt" and va.a == RWY and va.mag == 337, "VA: a heading from the runway, to an altitude")
T.near(va.hdg, 330, 1e-9, "heading 337 magnetic: 330 true")
T.equal(va.alt, 600, "600 ft")
T.near(va.len, (600 - 98) / 500, 1e-6, "its end as predicted: 502 ft at 500 ft/nm (estimate)")
T.check(vi.kind == "heading" and vi.term == "intc" and vi.a == va.b, "VI: a heading from VA's end, to the intercept")
T.near(vi.hdg, 38, 1e-9, "045 magnetic: 038 true")
T.check(vi.b and on_line(vi.a, vi.hdg, vi.b), "its end on its heading")
T.check(vi.b and on_line(ZZV, 83, vi.b), "and on the course 083 true into ZZV")
T.check(cf.kind == "line" and cf.b == ZZV and cf.term == "fix", "CF: the line into ZZV")
T.near(cf.crs, 83, 1e-9, "on its course, 090 magnetic")
T.check(dist(cf.a, vi.b) < 0.02, "from abeam the intercept")
T.check(M.turn(vi, cf, 200) == nil, "no fly-by from a heading leg")
-- a CF with nothing before it: its distance back along the course
path = M.build({{disc = true}, {pt = "CF", fix = ZZV, crs = 90, dist = 8}}, nil, env)
T.near(dist(path[2].a, ZZV), 8, 1e-6, "a CF with no leg before: 8 nm back along its course")

-- the other conditional legs (FCOM p.1249): to a radial, to a DME
-- distance, to vectors; from a fix for a distance
local S = {lat = 35.0, lon = 140.0}
path = M.build({{pt = "VR", crs = 100, navaid = ZZV, theta = 187, name = "ZZV187"}}, S, env)
T.check(path[1].kind == "heading" and path[1].term == "radial", "VR: a heading to a radial")
T.near(path[1].radial, 180, 1e-9, "radial 187 magnetic: 180 true")
T.near((M.course(ZZV, path[1].b)), 180, 0.05, "it ends on ZZV's radial")
T.check(on_line(S, 93, path[1].b), "on its heading")
path = M.build({{pt = "CD", crs = 90, navaid = ZZV, dist = 12, name = "ZZV/12"}}, S, env)
T.check(path[1].kind == "course" and path[1].term == "dme", "CD: a course to a DME distance")
T.near(dist(ZZV, path[1].b), 12, 0.01, "it ends 12 nm from ZZV (coming in: the first crossing)")
T.check(on_line(S, 83, path[1].b), "on its course")
path = M.build({{pt = "VD", crs = 0, navaid = ZZV, dist = 5, name = "ZZV/5"}}, ZZV, env)
T.near(dist(ZZV, path[1].b), 5, 0.01, "VD from inside the DME distance: going out to it")
path = M.build({{pt = "CA", crs = 90, alt = 3000, altterm = true}}, S, {var = env.var, alt = 1000})
T.near(path[1].len, 4, 1e-6, "CA from 1000 ft to 3000 ft: 4 nm at 500 ft/nm")
path = M.build({{pt = "CA", crs = 90, alt = 3000, altterm = true}}, S, {var = env.var, alt = 1000, grad = 250})
T.near(path[1].len, 8, 1e-6, "at 250 ft/nm: 8 nm")
path = M.build({{via = "DIRECT", fix = ZZV}, {pt = "FM", from_fix = ZZV, crs = 270, name = "VECTORS"}}, S, env)
T.check(path[2].kind == "course" and path[2].term == "manual" and path[2].a == ZZV and path[2].b == nil,
    "FM: a course from ZZV, no end (vectors: FCOM p.1237)")
T.equal(path[2].len, M.VECTORS_LEN, "a line of 10 nm for the ND")
path = M.build({{via = "DIRECT", fix = ZZV}, {pt = "FC", from_fix = ZZV, crs = 270, dist = 5}, {via = "DIRECT", fix = B}}, S, env)
T.near(dist(ZZV, path[2].b), 5, 1e-6, "FC: 5 nm from ZZV")
T.check(path[3].a == path[2].b, "the next leg from its end")
path = M.build({{pt = "VM", crs = 330, name = "VECTORS"}, {via = "DIRECT", fix = B}}, S, env)
T.check(path[1].kind == "heading" and path[1].term == "manual" and path[1].b == nil, "VM: a heading for vectors, no end")
T.check(path[2].kind == "none" and path[2].b == B, "after it no path into the next fix (DIRECT TO or INTC: FCOM p.1237)")
path = M.build({{pt = "CA", crs = 90, alt = 3000, altterm = true}}, nil, env)
T.check(path[1].kind == "none" and path[1].term == "alt", "a conditional leg with nowhere to start: no path")

-- a DME arc: from its boundary radial (the course field) to its fix
local F = M.point(ZZV, 263, 10)
path = M.build({{pt = "AF", fix = F, navaid = ZZV, rho = 10, theta = 270, crs = 180, turn = "R"}}, nil, env)
local af = path[1]
T.check(af.kind == "arc" and af.center == ZZV and af.r == 10 and af.dir == "R", "AF: an arc around ZZV at 10 nm, clockwise")
T.near(dist(ZZV, af.a), 10, 1e-6, "it starts on the arc")
T.near((M.course(ZZV, af.a)), 173, 1e-6, "on the boundary radial 180 (173 true)")
T.near(af.len, 90 * rad * 10, 0.01, "90 degrees of the arc: 15.7 nm")
T.near(M.start_course(af), 263, 0.01, "flown clockwise: west at its start")
T.near(M.end_course(af), 353, 0.01, "north at its end")

-- an RF leg from the CIFP (ZZBB's R09: tests/fms/data/navdb/CIFP/ZZBB.dat)
local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local legs = P.approach_legs(N, db, "ZZBB", "R09")
T.check(legs and #legs == 3 and legs[2].pt == "RF", "ZZBB's R09: IF, RF, TF")
T.check(legs[2].center and legs[2].center.ident == "ZBRF1", "the RF's centre ZBRF1 (fields 31-34)")
T.near(legs[2].arc_r, 3.0, 1e-9, "its radius 3.0 nm (field 18)")
path = M.build(legs, nil, env)
T.check(path[1].kind == "none" and path[1].b.ident == "ZB002", "the IF: no path into it")
local rf = path[2]
T.check(rf.kind == "arc" and rf.dir == "R" and rf.a.ident == "ZB002" and rf.b.ident == "ZB001", "the RF: clockwise from ZB002 to ZB001")
T.near(rf.len, math.pi / 2 * 3, 0.01, "a quarter of the circle: 4.71 nm")
T.near(M.end_course(rf), 90, 0.05, "east at ZB001")
T.near(path[3].crs, 90, 0.05, "the TF to RW09: east")
T.check(M.turn(rf, path[3], 160) == nil, "tangent: no turn")

T.done()
