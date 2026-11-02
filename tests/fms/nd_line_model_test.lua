-- Run from the repository root with LuaJIT: luajit tests/fms/nd_line_model_test.lua
-- The ND's route line (6-1/6-2 step 6d2; notes/ATA-34-61-FMC.md §132; FCOM
-- p.1147-1148): plugins/xtlua_keysystems/scripts/B747.68.xt.fms/
-- B747.68.nd_line_model.lua. The lines between the legs' ends, the fly-by
-- turns' arcs (the path model's turn), s198's ATMUG turn of 157 degrees
-- flown over the fix as LNAV steers it (the LNAV model's flyover_path,
-- X-Plane's map broke it up), no line across a discontinuity, after a
-- vectors leg or into the missed approach, an intercept's turn as LNAV
-- begins it (s91's (INTC)), a radial's end a corner, a hold's racetrack,
-- the turn at the fix sequenced last while flown, the datarefs' arrays.
local T = dofile("tests/lib/check.lua")("nd_line_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")
local D = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.nd_line_model.lua")

local function line(a, b)
    local c, d = P.course(a, b)
    return {kind = "line", a = a, b = b, crs = c, len = d, term = "fix"}
end
local function dist(a, b) local _, d = P.course(a, b) return d end
local function same(p, q) return math.abs(p.lat - q.lat) < 1e-6 and math.abs(p.lon - q.lon) < 1e-6 end
local function pens(pts)
    local n = 0
    for _, p in ipairs(pts) do if p.pen ~= 0 then n = n + 1 end end
    return n
end

-- a fly-by turn of 90 degrees at 300 kt (r 2.81 NM, 2.81 NM before the fix)
local A = {lat = 35, lon = 135}
local B = P.point(A, 90, 30)
local C = P.point(B, 0, 30)
local path = {line(A, B), line(B, C)}
local pts = D.route(path, {P = P, L = L, style = D.ACTIVE, kt = 300})
local tr = P.turn(path[1], path[2], 300)
T.check(same(pts[1], A), "the line from the active leg's start")
T.equal(pts[1].pen, D.ACTIVE, "a piece of the active route")
T.equal(pens(pts), 1, "one piece")
T.check(same(pts[2], tr.t1), "to the turn's start")
T.check(same(pts[#pts - 1], tr.t2) and same(pts[#pts], C), "from its end on to C")
local n_arc = #pts - 4
T.equal(n_arc, 17, "the arc's points every 5 degrees (90 degrees: 17 between its ends)")
local on_arc = true
for k = 3, #pts - 2 do
    if math.abs(dist(tr.center, pts[k]) - tr.r) > 0.01 then on_arc = false end
end
T.check(on_arc, "on the turn's circle")
T.check(dist(B, pts[3 + 8]) > 0.5, "the arc cuts the corner: not through B")
-- the speed by element
local seen = {}
D.route(path, {P = P, L = L, kt = function(i) seen[#seen + 1] = i return 250 end})
T.equal(seen[1], 1, "the turn's speed asked for at element 1's fix")

-- s198's ATMUG: XAC (268 degrees) onto ATMUG-SAKVA (111 degrees), a left
-- turn of 157 degrees flown over the fix at 250 kt
local XAC = {lat = 34.712252778, lon = 139.414016667}
local ATMUG = {lat = 34.558322222, lon = 134.127066667}
local SAKVA = {lat = 34.3705, lon = 134.723722222}
local ATVID = {lat = 34.303166667, lon = 134.93475}
path = {line(XAC, ATMUG), line(ATMUG, SAKVA), line(SAKVA, ATVID)}
local cache = {}
pts = D.route(path, {P = P, L = L, kt = 250, cache = cache})
T.equal(pens(pts), 1, "ATMUG: one piece (X-Plane's map broke it up)")
T.check(same(pts[2], ATMUG), "on to ATMUG itself: flown over")
local k_sak = nil
for k, p in ipairs(pts) do if same(p, SAKVA) then k_sak = k end end
T.check(k_sak and k_sak > 6, "the turn's points between ATMUG and SAKVA: " .. tostring(k_sak and k_sak - 3))
local left, beyond = true, false
for k = 3, (k_sak or 3) - 1 do
    local xt = P.track(ATMUG, P.end_course(path[1]), pts[k])
    -- left of the course in (south: the turn's side) and past ATMUG first
    if xt > 0.05 then left = false end
    local _, a2 = P.track(ATMUG, P.end_course(path[1]), pts[k])
    if a2 > 0.5 then beyond = true end
end
T.check(left, "the turn on its left side (south)")
T.check(beyond, "beyond ATMUG before it comes round")
local cap = pts[(k_sak or 2) - 1]
local xt = P.track(ATMUG, path[2].crs, cap)
T.check(math.abs(xt) <= L.FLY_XT + 0.01, string.format("then on ATMUG-SAKVA where LNAV is on it (%.3f NM off)", xt))
local n_cache = 0
for _ in pairs(cache) do n_cache = n_cache + 1 end
T.equal(n_cache, 1, "the turn kept in the cache")
local pts2 = D.route(path, {P = P, L = L, kt = 252, cache = cache})
T.equal(#pts2, #pts, "the same turn at 252 kt (10 kt steps) from the cache")
local pts3 = D.route(path, {P = P, L = L, kt = 370, cache = cache})
T.check(#pts3 ~= #pts or not same(pts3[k_sak - 1], cap), "at 370 kt another, wider turn")
-- the turn flown: ATMUG sequenced, the active leg ATMUG-SAKVA, the turn
-- still in the line from the fix (prev)
pts = D.route({path[2], path[3]}, {P = P, L = L, kt = 250, cache = cache, prev = path[1]})
T.check(same(pts[1], ATMUG), "sequenced: the line from ATMUG")
T.check(#pts > 4 and not same(pts[2], SAKVA), "through the turn LNAV is flying")

-- a discontinuity: two pieces
path = {line(A, B), {kind = "disc", leg = 2}, line(C, P.point(C, 0, 20))}
pts = D.route(path, {P = P, L = L, kt = 250})
T.equal(pens(pts), 2, "a discontinuity: two pieces")
T.check(same(pts[2], B) and same(pts[3], C) and pts[3].pen == D.ACTIVE, "B, then a new piece from C")
-- a vectors leg (FM): its 10 NM, no line on
local fm = {kind = "course", a = B, crs = 0, term = "manual", len = P.VECTORS_LEN}
path = {line(A, B), fm, line(C, P.point(C, 90, 20))}
pts = D.route(path, {P = P, L = L, kt = 250})
local k_end = nil
for k = 2, #pts do if pts[k].pen ~= 0 then k_end = k - 1 break end end
T.near(k_end and dist(B, pts[k_end]) or -1, P.VECTORS_LEN, 0.01, "a vectors leg (a fly-by turn onto it): its 10 NM")
T.equal(pens(pts), 2, "then a new piece")
-- the missed approach left out
local m = line(B, C)
m.missed = true
pts = D.route({line(A, B), m}, {P = P, L = L, kt = 250})
T.equal(#pts, 2, "the missed approach left out: A, B")
-- s91's (INTC): heading 160 until the course 283 into NRE, a right turn
-- of 123 degrees at 250 kt. LNAV begins it where the turn brings the
-- airplane onto the course (its `ended`: r (1 - cos 123) off the course,
-- 3.0 NM), so the line rounds the corner as a fly-by turn's arc
local NRE = {lat = 35.8, lon = 140.4}
local X = P.point(NRE, 60, 20)
local function off(t) return (P.track(NRE, 103, P.point(X, 160, t))) end
local lo, hi = 0, 40
for _ = 1, 60 do
    local mid = (lo + hi) / 2
    if (off(mid) > 0) == (off(lo) > 0) then lo = mid else hi = mid end
end
local INTC = P.point(X, 160, lo)
local vi = {kind = "heading", a = X, b = INTC, hdg = 160, len = lo, term = "intc"}
local cf = line(INTC, NRE)
pts = D.route({vi, cf}, {P = P, L = L, kt = 250})
local fix = {kind = "line", a = X, b = INTC, crs = 160, len = lo, term = "fix"}
tr = P.turn(fix, cf, 250)
T.check(tr ~= nil and tr.dir == "R", "the intercept: a right turn")
T.check(same(pts[1], X) and same(pts[2], tr.t1), "on the heading to the turn's start")
local r = (250 * 1852 / 3600) ^ 2 / (9.80665 * math.tan(25 * math.pi / 180)) / 1852
T.near(math.abs(P.track(NRE, 103, tr.t1)), r * (1 - math.cos(123 * math.pi / 180)), 0.05,
    "the turn's start r (1 - cos 123) off the course: where LNAV begins it")
local k_t2 = nil
for k, p in ipairs(pts) do if same(p, tr.t2) then k_t2 = k end end
T.check(k_t2 and k_t2 > 20 and same(pts[#pts], NRE), "round the arc to the course, then on to NRE")
local inside = true
for _, p in ipairs(pts) do if dist(INTC, p) < 0.5 then inside = false end end
T.check(inside, "not through the corner")
-- a radial's end (a VR's) into a heading leg: the turn begins at the
-- radial (LNAV sequences it there), the line's corner at the crossing
local vr = {kind = "heading", a = A, b = B, hdg = 90, len = dist(A, B), term = "radial"}
local vh = {kind = "heading", a = B, b = C, hdg = 0, len = dist(B, C), term = "intc"}
pts = D.route({vr, vh}, {P = P, L = L, kt = 250})
T.equal(#pts, 3, "a radial's end: A, the crossing, C")
T.check(same(pts[2], B), "the corner at the crossing")
-- (step 6d3) the path model's turn before a leg (turn_in): s91's D337F
-- flown over, round the turn onto heading 100 to NRE's radial 001
local var7 = function() return -7 end
local D337F = {lat = 35.9, lon = 140.3}
local NRE_ = {ident = "NRE", lat = 35.8, lon = 140.4}
path = P.build({
    {pt = "CF", fix = D337F, crs = 337, dist = 5, flyover = true},
    {pt = "VR", crs = 100, navaid = NRE_, theta = 1, turn = "R", name = "NRE001"},
}, nil, {var = var7, alt = 3000, kt = function() return 250 end})
local ti = path[2].turn_in
pts = D.route(path, {P = P, L = L, kt = 250})
local k_from, k_a = nil, nil
for k, p in ipairs(pts) do
    if same(p, D337F) then k_from = k end
    if same(p, path[2].a) then k_a = k end
end
T.check(ti and k_from and k_a and k_a - k_from > 20, "D337F, round the turn (123 degrees), then the heading from its end")
local round = true
for k = (k_from or 1) + 1, (k_a or 1) - 1 do
    if math.abs(dist(ti.center, pts[k]) - ti.r) > 0.01 then round = false end
end
T.check(round, "on the turn's circle")
local steps = true
for k = (k_from or 1) + 1, k_a or 1 do
    if dist(pts[k - 1], pts[k]) > ti.r * 6 * math.pi / 180 then steps = false end
end
T.check(steps, "round its way in steps of 5 degrees, to the turn's end")
T.check(same(pts[#pts], path[2].b) and pens(pts) == 1, "to the radial's crossing, one piece")
-- a conditional leg's end into a CF (from abeam it): the turn onto its
-- course as LNAV steers it, then on to the fix (F2 15 nm on, its course
-- 083 true 4.4 nm right of the altitude's point)
local VA2 = {pt = "VA", crs = 337, alt = 2000, altterm = true, name = "(2000)"}
local F2 = P.point(P.build({VA2}, D337F, {var = var7, alt = 100})[1].b, 100, 15)
local CF2 = {pt = "CF", fix = F2, crs = 90, dist = 10}
path = P.build({VA2, CF2}, D337F, {var = var7, alt = 100, kt = function() return 220 end})
local va2 = path[1]
pts = D.route(path, {P = P, L = L, kt = 220, cache = {}})
local k_va = nil
for k, p in ipairs(pts) do if same(p, va2.b) then k_va = k end end
T.check(k_va and #pts - k_va > 4 and same(pts[#pts], F2), "from the altitude's point round the turn to the fix")
local cap2 = pts[#pts - 1]
T.check(math.abs(P.track(F2, 263, cap2)) < L.FLY_XT + 0.01, "on the course into it where LNAV is on it")
-- the active leg after the altitude met where it was not predicted: from
-- there (its start), not from the prediction
local met = P.point(va2.b, 330, 1)
local cf_now = P.build({CF2}, met, {var = var7, alt = 2000})
pts = D.route(cf_now, {P = P, L = L, kt = 220, cache = {}, prev = va2})
T.check(same(pts[1], met) and #pts > 4 and same(pts[#pts], F2), "the active leg's turn from where the altitude was met")
-- a hold at B: round its racetrack and back to B
local hold = {kind = "hold", a = B, b = B, len = 0, inbd = 90, dir = "R", term = "fix"}
path = {line(A, B), hold}
local shape = P.shape(path, 210)
pts = D.route(path, {P = P, L = L, kt = 250, shape = shape})
T.check(same(pts[2], B) and same(pts[#pts], B), "into the hold's fix and round to it")
T.equal(#pts, 2 + #shape[2].pts + 1, "the racetrack's points")
T.equal(pens(pts), 1, "one piece")
-- the styles
pts = D.route({line(A, B)}, {P = P, L = L, style = D.MOD})
T.equal(pts[1].pen, D.MOD, "a modification's piece")

-- the arrays: at most MAXP, a piece's last start left out
local many = {}
for k = 1, 700 do many[k] = {lat = 35, lon = 135 + k / 1000, pen = k == 1 and 1 or 0} end
local lat, lon, pen, n = D.pack(many)
T.equal(n, D.MAXP, "at most MAXP points")
T.equal(pen[1], 1, "the first starts its piece")
T.near(lon[2], 135.002, 1e-9, "in order")
local few = {{lat = 1, lon = 1, pen = 1}, {lat = 1, lon = 2, pen = 0}, {lat = 2, lon = 2, pen = 3}}
lat, lon, pen, n = D.pack(few)
T.equal(n, 2, "a last point starting a piece left out")

T.done()
