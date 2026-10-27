-- Run from the repository root with LuaJIT: luajit tests/fms/path_model_test.lua
-- The FMC's lateral path (6-1/6-2 step 6a; notes/ATA-34-61-FMC.md §26):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua.
-- The great circles' courses and cross-track distances, each leg type's
-- element (lines, courses, headings, arcs) with the conditional legs' ends
-- as predicted (FCOM p.1245, p.1249), an RF leg from the synthetic CIFP of
-- ZZBB (FCOM p.1247), the fly-by turns (estimate: 25 degrees of bank), the
-- holds' elements, size and racetrack (step 7a; FMSPG p.164, p.224).
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
T.check(path[1].direct, "flown from where the airplane is (direct)")
path = M.build({{via = "DIRECT", fix = C, dto = true, from = from, crs = 90}}, A, env)
T.check(not path[1].direct, "with an INTC CRS: the course, not direct")
path = M.build({{via = "DIRECT", fix = B}, {pt = "DF", fix = C}, {pt = "TF", fix = A}}, A, env)
T.check(not path[1].direct and path[2].direct and not path[3].direct, "a DF direct; DIRECT and TF not")

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

-- the shape for the ND's line (step 6d): the arc's points every 15
-- degrees, the conditional legs' ends as predicted, a vectors leg's line
local sh = M.shape(path)
T.check(sh[2] and #sh[2].pts == 5, "the RF's 90 degrees: 5 points between its ends (15 to 75 degrees)")
T.near(dist(legs[2].center, sh[2].pts[1]), 3.0, 0.01, "on the arc")
T.near((M.course(legs[2].center, sh[2].pts[1])), (M.course(legs[2].center, rf.a) + 15) % 360, 0.01, "15 degrees on, clockwise")
T.check(sh[1] == nil and sh[3] == nil, "nothing for the other legs")
path = M.build({
    {pt = "VA", crs = 337, alt = 600, altterm = true, name = "(600)"},
    {pt = "VI", crs = 45, turn = "R", name = "(INTC)"},
    {pt = "CF", fix = ZZV, crs = 90, dist = 8},
    {pt = "VM", crs = 90, name = "VECTORS"},
}, RWY, {var = env.var, alt = 98})
sh = M.shape(path)
T.check(sh[1].at == path[1].b and sh[2].at == path[2].b and sh[3] == nil, "the conditional legs' ends as predicted")
T.near(dist(path[4].a, sh[4].at), M.VECTORS_LEN, 1e-6, "VECTORS: its line's end, 10 nm on")

-- the holds (step 7a; FCOM p.1413; FMSPG p.164, p.221-224): HM, HA, HF at
-- their fix, the inbound course true, right unless left
path = M.build({
    {via = "DIRECT", fix = B},
    {pt = "HM", fix = B, crs = 7, time = 1.5},
    {pt = "HA", fix = B, crs = 97, turn = "L", alt = 6000, dist = 4},
    {pt = "HF", fix = B, crs = 187, exit = true},
}, A, env)
local hm, ha, hf = path[2], path[3], path[4]
T.check(hm.kind == "hold" and hm.a == B and hm.b == B and hm.len == 0 and hm.term == "fix", "HM: a hold at B")
T.near(hm.inbd, 0, 1e-9, "inbound 007 magnetic: 000 true")
T.check(hm.dir == "R" and hm.time == 1.5 and hm.hold == "manual", "right turns, 1.5 minutes, ended by the crew")
T.check(ha.dir == "L" and ha.dist == 4 and ha.hold == "alt" and ha.alt == 6000, "HA: left, 4 nm legs, ended at 6000 ft")
T.check(hf.hold == "fix" and hf.exit, "HF: ended at the fix; EXIT armed")
T.check(M.turn(path[1], hm, 250) == nil, "no fly-by turn into it: over the fix")
-- its size: the radius at 250 kt and 25 degrees, the legs' time at the
-- speed inbound, or their distance
local r, l = M.hold_size(hm, 250, 240)
T.near(r, 1.953, 0.001, "the turns' radius at 250 kt: 1.95 nm")
T.near(l, 6, 1e-9, "1.5 minutes at 240 kt inbound: 6 nm")
T.near(select(2, M.hold_size(ha, 250, 240)), 4, 1e-9, "the legs' distance")
T.near(select(2, M.hold_size(hf, 250)), 250 / 60, 1e-9, "neither: 1 minute (FMSPG p.222)")
T.near(select(2, M.hold_size({alt = 15000}, 250)), 1.5 * 250 / 60, 1e-9, "above 14,000 ft: 1.5 minutes")
-- its racetrack (right): the turn at the fix east of it, the outbound leg
-- south from 2 r east, the turn back, the inbound leg's start
local t = M.racetrack(hm, 2, 5)
T.near(dist(B, t.o1), 2, 1e-6, "the turn at the fix: its centre r from it")
T.near((M.course(B, t.o1)), 90, 1e-6, "east: the hold's side")
T.near(dist(B, t.p1), 4, 1e-6, "the outbound leg's start 2 r across")
T.near(dist(t.p1, t.p2), 5, 1e-6, "the outbound leg: l")
T.near((M.course(t.p1, t.p2)), 180, 0.05, "south")
T.near(dist(t.o2, t.p2), 2, 1e-6, "the turn back: r")
T.near(dist(B, t.s), 5, 1e-6, "the inbound leg: l to the fix")
T.near((M.course(t.s, B)), 0, 0.01, "on the inbound course")
T.near(dist(t.o2, t.s), 2, 0.01, "the turn back's end")
T.check(t.sgn == 1 and M.racetrack(ha, 2, 4).sgn == -1, "right and left")
T.near((M.course(ha.b, M.racetrack(ha, 2, 4).o1)), (90 - 90) % 360, 1e-6, "left, inbound 090: north")
-- its shape for the ND's line: round the turn at the fix every 30
-- degrees, the outbound leg, round the turn back, the inbound leg's start
sh = M.shape(path, 250)
local hp = sh[2] and sh[2].pts or {}
t = M.racetrack(hm, M.hold_size(hm, 250))
T.equal(#hp, 13, "13 points: 5, the outbound leg's ends, 5, the inbound leg's start")
T.near(dist(t.o1, hp[1]), t.r, 1e-6, "on the turn at the fix")
T.near((M.course(t.o1, hp[1])), 300, 1e-6, "30 degrees round it, clockwise")
T.check(hp[13] and dist(hp[6], t.p1) < 1e-6 and dist(hp[7], t.p2) < 1e-6 and dist(hp[13], t.s) < 1e-6,
    "the outbound leg, the inbound leg's start")
T.near(dist(t.o2, hp[10]), t.r, 1e-6, "on the turn back")
T.near(dist(B, hp[6]), 2 * 1.953, 0.002, "250 kt: 2 r across")

-- the lateral offset (step 7d): A north to B, B east to C; 5 nm right
path = M.build({{via = "DIRECT", fix = B}, {via = "J1", pt = "TF", fix = C}, {via = "DIRECT", fix = ZZV}}, A, env)
local off = M.offset(path, 5, 2)
local o1, o2 = off[1], off[2]
T.check(o1.kind == "line" and o1.offset == 5 and o1.leg == 1 and not o1.wide, "the offset lines")
T.near((M.track(A, 0, o1.a)), 5, 0.01, "the first from abeam its start, 5 nm right")
T.near((M.track(A, 0, o1.b)), 5, 0.01, "parallel to A-B")
local cx, cy = (o1.b.lon - B.lon) * 60 * math.cos(B.lat * rad), (o1.b.lat - B.lat) * 60
T.check(math.abs(cx - 5) < 0.05 and math.abs(cy + 5) < 0.05, "the corner 5 nm east and 5 nm south of B (inside the right turn)")
T.check(o2.a == o1.b, "the next from the corner")
T.near((M.track(B, path[2].crs, o2.b)), 5, 0.02, "and 5 nm right of B-C to abeam C")
T.check(off[3] == path[3], "the route on after the offset")
T.check(M.turn(o1, o2, 250) ~= nil, "a fly-by turn at the corner")
local wide = M.offset(path, -30, 1)
T.check(wide[1].offset == -30 and wide[1].wide and wide[2].wide and not wide[3].wide, "30 nm left: wide, and the element after")
T.check(not path[2].wide, "the route's own element not changed")
T.near((M.track(A, 0, wide[1].b)), -30, 0.05, "left: negative")

-- a procedure turn (step 7f, estimate): PI at F, its 45 degree leg 045
-- true (052 magnetic, 7 W), a right turn, 10 nm
local Fp = {lat = 35.5, lon = 140.0}
local pe = M.element({pt = "PI", fix = Fp, crs = 52, turn = "R", dist = 10}, 1, Fp, nil, env, 0)
T.check(pe.kind == "pturn" and math.abs(pe.pc - 45) < 1e-9 and math.abs(pe.out - 90) < 1e-9 and pe.dir == "R" and pe.limit == 10,
    "a PI: the 45 degree leg 045, outbound 090 (45 degrees the other way), a right turn, 10 nm")
local g = M.pturn(pe, 220)
local _, far = M.course(Fp, g.c)
T.near(far + g.r, 9, 0.02, "the turn's farthest point 1 nm inside the 10 nm")
T.near((M.track(Fp, 90, g.x)), 0, 0.01, "the leg back meets the inbound course")
T.check(M.track(Fp, 90, g.p) < 0 and M.track(Fp, 90, g.q) < 0, "the 45 degree leg and the turn left of the outbound course")
T.near(select(2, M.course(g.o, g.p)), 220 * 1.25 / 60, 0.01, "the 45 degree leg 1 min 15 s at 220 kt")
local ld = M.element({pt = "PI", fix = Fp, crs = 142, turn = "L"}, 1, Fp, nil, env, 0)
T.check(math.abs(ld.out - 90) < 1e-9 and ld.limit == 10 and M.track(Fp, 90, M.pturn(ld, 220).p) > 0,
    "left: 135 true, outbound 090, its 45 degree leg on the right; 10 nm without a distance")
local sh = M.shape({pe}, 220)
local pts = sh[1] and sh[1].pts
T.check(pts and pts[1] == nil or (pts[1].lat == M.pturn(pe, 220).o.lat), "the ND's points from the outbound leg's end")
T.check(pts and #pts == 9 and math.abs(pts[#pts].lat - g.x.lat) < 1e-9, "o, p, five points round the turn, q, x: " .. (pts and #pts or 0))

T.done()
