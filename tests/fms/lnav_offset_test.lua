-- Run from the repository root with LuaJIT: luajit tests/fms/lnav_offset_test.lua
-- The FMC's lateral offset (6-1/6-2 step 7d; notes/ATA-34-61-FMC.md §35):
-- the route model's offset (its extent: FMSPG p.155; FCOM p.1299), the path
-- model's offset lines and LNAV in closed loop with the airplane of
-- tests/lib/lnav_sim.lua: the turn to capture the offset course (FCOM
-- p.1298), the fly-by turn on the offset path, END OF OFFSET 5 nm before
-- its end (FCOM p.1431; FMSPG p.155), the route rejoined after it, the
-- sequencing limit of 200 nm on a wide offset (FCOM p.1298), the OFST
-- light's guidance (FCOM p.1210).
local T = dofile("tests/lib/check.lua")("lnav_offset")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")

local VAR = -7
local SIM = dofile("tests/lib/lnav_sim.lua")(N, R, P, L, VAR)
local route, plane, fly = SIM.route, SIM.plane, SIM.fly
local function fmt(v) return string.format("%.2f", v) end
local function dist(a, b) local _, d = P.course(a, b) return d end

-- A to B north, B to C east (a fly-by turn of 90 degrees), C to D a
-- STAR's (the offset ends at C: FMSPG p.155)
local A, B, C = {lat = 35.0, lon = 140.0}, {lat = 35.5, lon = 140.0}, {lat = 35.5, lon = 140.6}
local D = P.point(C, 90, 30)
local function legs() return {{via = "DIRECT", fix = B}, {via = "DIRECT", fix = C}, {via = "STAR1", proc = "STAR", pt = "TF", fix = D}} end
-- LNAV's path: the route's with its offset (the glue's B747_fmc_lnav_build)
local function offset_path(st, path)
    local d = st.rte.offset
    if not d then return path end
    return P.offset(path, d, R.offset_legs(st.rte))
end

-- R5 from A on the route north
local st = route(legs(), A)
st.rte.offset = 5
T.equal(R.offset_legs(st.rte), 2, "the offset reaches B and C, not the STAR's D")
local s = L.new(P)
local a = plane({lat = A.lat, lon = A.lon, hdg = 0, tas = 250})
local right, maxb, eoo_at, ofst_seen, cap_t = false, 0, nil, false, nil
local route_x = {}
local log = fly(st, s, a, 900, {path = offset_path, each = function(t, s, air, path)
    if t < 20 and s.roll > 5 then right = true end
    maxb = math.max(maxb, math.abs(s.roll))
    if s.ofst then ofst_seen = true end
    if not cap_t and path[1].offset and math.abs(s.xtk) < 0.1 and t > 30 then cap_t = t end
    if s.msg_eoo and not eoo_at then eoo_at = dist(air, P.point(C, 180, 5)) end
    if st.rte.legs[1].fix == B and t > 150 and t < 250 then route_x[#route_x + 1] = (P.track(A, 0, air)) end
end})
T.check(right, "EXEC with LNAV: the turn to capture the offset course, right (FCOM p.1298)")
T.check(cap_t and cap_t < 150, "the offset course captured: in " .. tostring(cap_t) .. " s")
T.check(maxb <= 25, "25 degrees of bank at most: " .. fmt(maxb))
T.check(#route_x > 0 and math.abs(route_x[#route_x] - 5) < 0.1, "5 nm right of the route: " .. fmt(route_x[#route_x] or 0))
T.check(ofst_seen, "the OFST light's guidance (FCOM p.1210)")
T.check(#log >= 2 and log[1].e.offset and log[1].e.leg == 1, "B's offset leg sequenced")
local corner = log[1] and dist(log[1], P.point(P.point(B, 90, 5), 180, 5)) or 99
T.check(corner < 1.5, "at the turn's bisector near the offset corner (5 nm east and south of B): " .. fmt(corner))
T.check(eoo_at and eoo_at < 5.3 and eoo_at > 4.5, "END OF OFFSET 5 nm before the offset's end abeam C (FMSPG p.155): " .. tostring(eoo_at and fmt(eoo_at)))
T.check(log[2] and log[2].e.offset, "C's offset leg sequenced")
T.equal(st.rte.offset, nil, "the offset over (estimate)")
T.equal(st.rte.legs[1].fix, D, "D the active waypoint")
T.check(not s.ofst and not s.msg_eoo and math.abs(s.xtk) < 0.2, "the route rejoined to D: " .. fmt(s.xtk))

-- a wide offset, 40 nm right, B 15 nm on: B sequenced while still more
-- than 21 nm from the offset line (the limit 200 nm: FCOM p.1298)
local B15 = P.point(A, 0, 15)
st = route({{via = "DIRECT", fix = B15}, {via = "DIRECT", fix = P.point(B15, 0, 60)}}, A)
st.rte.offset = 40
s = L.new(P)
a = plane({lat = A.lat, lon = A.lon, hdg = 0, tas = 250})
local seq_xt = nil
log = fly(st, s, a, 400, {path = offset_path, each = function(t, s, air, path)
    if not seq_xt and s.seq > 0 then seq_xt = s.xtk end
end})
T.check(log[1] and log[1].e.wide, "the offset's lines marked wide")
T.check(seq_xt and math.abs(seq_xt) > 21, "B sequenced more than 21 nm from the offset line: " .. tostring(seq_xt and fmt(seq_xt)))
-- 10 nm: not wide
st = route({{via = "DIRECT", fix = B15}, {via = "DIRECT", fix = P.point(B15, 0, 60)}}, A)
st.rte.offset = 10
local p10 = offset_path(st, P.build(st.rte.legs, R.leg_from(st.rte, 1), {var = function() return VAR end, alt = 0}))
T.check(p10[1].offset == 10 and not p10[1].wide, "10 nm: not wide")

T.done()
