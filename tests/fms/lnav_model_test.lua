-- Run from the repository root with LuaJIT: luajit tests/fms/lnav_model_test.lua
-- The FMC's LNAV (6-1/6-2 step 6b; notes/ATA-34-61-FMC.md §26):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua
-- with the route model (sequencing) and the path model, in closed loop
-- with a simple airplane (its bank after the command with a lag of 1 s and
-- 3 degrees a second at most, its turn from its bank, the wind): the
-- capture of a leg, fly-by and fly-over turns, an RF and a DME arc, a
-- heading to an altitude and to an intercept, the capture criteria (2.5 nm,
-- the intercept: ATA34_2 p.618; NOT ON INTERCEPT HEADING: FCOM p.1435), the
-- 21 nm limit (FCOM p.1237), a discontinuity and the end of the route
-- (FCOM p.644, p.1431), the recapture after a new active leg.
local T = dofile("tests/lib/check.lua")("lnav_model")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local PR = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")

local RAD = math.pi / 180
local VAR = -7
local function var() return VAR end
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function dist(a, b) local _, d = P.course(a, b) return d end

-- an active route of `legs` starting at `start`
local function route(legs, start)
    local st = R.new(N, nil)
    st.rte.legs, st.rte.runway, st.active = legs, start, true
    return st
end
-- the airplane: {lat, lon, hdg (true), bank, tas (kt), alt, vs (fpm),
-- wind_from (true), wind (kt), ground}
local function plane(t)
    t.bank, t.alt, t.vs, t.wind, t.wind_from = t.bank or 0, t.alt or 10000, t.vs or 0, t.wind or 0, t.wind_from or 0
    return t
end
local function state(a)
    local vn = a.tas * math.cos(a.hdg * RAD) - a.wind * math.cos(a.wind_from * RAD)
    local ve = a.tas * math.sin(a.hdg * RAD) - a.wind * math.sin(a.wind_from * RAD)
    return {lat = a.lat, lon = a.lon, hdg = a.hdg, trk = (math.atan2(ve, vn) / RAD + 360) % 360,
        gs = math.sqrt(vn * vn + ve * ve), tas = a.tas, wind = a.wind, alt = a.alt, var = VAR, ground = a.ground or false}
end
-- fly `seconds` (steps of 0.1 s): the route sequenced as LNAV says;
-- opts.engaged (default true), opts.armed, opts.engage_when_valid, opts.each(t, s,
-- air, path).
-- Returns the sequencing log
local function fly(st, s, a, seconds, opts)
    opts = opts or {}
    local engaged = opts.engaged ~= false
    local dt, log = 0.1, {}
    for k = 1, math.floor(seconds / dt + 0.5) do
        local r = st.rte
        local path = P.build(r.legs, R.leg_from(r, 1), {var = var, alt = a.alt})
        local air = state(a)
        local n = L.update(s, path, air, opts.armed or false, engaged)
        if opts.each then opts.each(k * dt, s, air, path) end
        -- the FCC engages an armed LNAV once its steering is valid
        if opts.engage_when_valid and not engaged and s.valid then engaged = true end
        if n > 0 then
            local e = path[1]
            local start = e.term ~= "fix" and {lat = a.lat, lon = a.lon} or nil
            if R.sequence(st, n, start) then
                log[#log + 1] = {t = k * dt, lat = a.lat, lon = a.lon, alt = a.alt, e = e}
            end
        end
        local cmd = engaged and s.roll or 0
        a.bank = a.bank + clamp(cmd - a.bank, -3 * dt, 3 * dt)
        a.hdg = (a.hdg + 9.80665 * math.tan(a.bank * RAD) / (a.tas * 1852 / 3600) / RAD * dt) % 360
        local sa = state(a)
        local q = P.point(a, sa.trk, sa.gs * dt / 3600)
        a.lat, a.lon = q.lat, q.lon
        a.alt = a.alt + a.vs / 60 * dt
    end
    return log
end

local A, B, C = {lat = 35.0, lon = 140.0}, {lat = 35.5, lon = 140.0}, {lat = 35.5, lon = 140.6}

-- capturing a leg 2 nm off it, on a 30 degree intercept
local st = route({{via = "DIRECT", fix = B}}, A)
local s = L.new(P)
local a = plane({lat = 35.1, lon = 140.0 + 2 / (60 * math.cos(35.1 * RAD)), hdg = 330, tas = 250})
local over, maxbank = 0, 0
fly(st, s, a, 180, {each = function(t, s) over = math.min(over, s.xtk) maxbank = math.max(maxbank, math.abs(s.roll)) end})
T.equal(s.mode, "path", "on the path")
T.check(math.abs(s.xtk) < 0.05, "captured: cross-track " .. s.xtk)
T.check(math.abs(s.tae) < 1, "on the track: " .. s.tae)
T.check(over > -0.2, "overshooting less than 0.2 nm: " .. over)
T.check(maxbank <= 25, "the bank at most 25 degrees (ATA34_2 p.618): " .. maxbank)

-- a fly-by turn of 90 degrees at 250 kt
local function flyby(wind, from)
    local st = route({{via = "DIRECT", fix = B}, {via = "DIRECT", fix = C}}, A)
    local s = L.new(P)
    local a = plane({lat = 35.3, lon = 140.0, hdg = 0, tas = 250, wind = wind, wind_from = from})
    local maxxt, peak = 0, 0
    local log = fly(st, s, a, 300, {each = function(t, s)
        maxxt = math.max(maxxt, math.abs(s.xtk)) peak = math.max(peak, math.abs(s.roll)) end})
    return st, s, log, maxxt, peak
end
local st2, s2, log2, maxxt2, peak2 = flyby(0, 0)
T.equal(#log2, 1, "B sequenced once")
local d = log2[1] and dist(log2[1], B) or 99
T.check(d > 0.5 and d < 1.1, "at the turn's bisector, 0.8 nm inside B (estimate): " .. d)
T.check(st2.rte.legs[1].fix == C and st2.rte.passed[1].fix == B, "C the active waypoint, B passed")
T.check(maxxt2 < 0.3, "the turn flown within 0.3 nm of the path: " .. maxxt2)
T.check(peak2 > 20 and peak2 <= 25, "about 25 degrees of bank in the turn: " .. peak2)
T.check(math.abs(s2.xtk) < 0.05 and s2.mode == "path", "on C's leg after it: " .. s2.xtk)
local _, _, _, maxxt3 = flyby(40, 270)
T.check(maxxt3 < 0.6, "with 40 kt from the west: within 0.6 nm: " .. maxxt3)

-- a fly-over fix: over it, then back onto the leg
st = route({{via = "DIRECT", fix = B, flyover = true}, {via = "DIRECT", fix = C}}, A)
s = L.new(P)
a = plane({lat = 35.3, lon = 140.0, hdg = 0, tas = 250})
local maxout = 0
local log = fly(st, s, a, 400, {each = function(t, s) if t > 330 then maxout = math.max(maxout, math.abs(s.xtk)) end end})
T.equal(#log, 1, "the fly-over fix sequenced")
T.check(log[1] and dist(log[1], B) < 0.1, "over it: " .. (log[1] and dist(log[1], B) or -1))
T.check(math.abs(s.xtk) < 0.1, "back on C's leg: " .. s.xtk)
T.check(maxout < 0.2, "and staying on it: " .. maxout)

-- an RF leg (ZZBB's R09: tests/fms/data/navdb/CIFP/ZZBB.dat) at 180 kt
local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local appr = PR.approach_legs(N, db, "ZZBB", "R09")
local ZB002 = appr[1].fix
st = route({{via = "DIRECT", fix = ZB002}, appr[2], appr[3]}, P.point(ZB002, 180, 6))
s = L.new(P)
a = plane({lat = P.point(ZB002, 180, 5).lat, lon = ZB002.lon, hdg = 0, tas = 180, alt = 3000})
local onarc = 0
log = fly(st, s, a, 300, {each = function(t, s, air, path)
    if path[1].kind == "arc" and t > 5 then onarc = math.max(onarc, math.abs(s.xtk)) end end})
T.equal(#log, 2, "ZB002 and ZB001 sequenced")
T.check(onarc > 0 and onarc < 0.2, "the RF arc flown within 0.2 nm (FCTM p.61): " .. onarc)
T.check(math.abs(s.xtk) < 0.05 and math.abs(s.dtk - 90) < 1, "then on the final course east: " .. s.xtk)

-- a DME arc: 10 nm around ZZV, clockwise from radial 180 to 270
local ZZV = {ident = "ZZV", lat = 35.2, lon = 140.2}
local ARC0 = P.point(ZZV, 173, 10)
local F = P.point(ZZV, 263, 10)
st = route({{via = "DIRECT", fix = ARC0}, {pt = "AF", fix = F, navaid = ZZV, rho = 10, theta = 270, crs = 180, turn = "R"},
    {via = "DIRECT", fix = P.point(F, 353, 20)}}, P.point(ARC0, 83, 8))
s = L.new(P)
local in0 = P.point(ARC0, 83, 6)
a = plane({lat = in0.lat, lon = in0.lon, hdg = 263, tas = 210})
onarc = 0
log = fly(st, s, a, 500, {each = function(t, s, air, path)
    if path[1].kind == "arc" and t > 30 then onarc = math.max(onarc, math.abs(s.xtk)) end end})
T.equal(#log, 2, "the arc's start and its end sequenced")
T.check(onarc > 0 and onarc < 0.2, "the DME arc flown within 0.2 nm (FCOM p.1245): " .. onarc)

-- after the takeoff: heading 337 to 600 ft, then direct ZZV
local RWY = {lat = 34.983333, lon = 140.016667}
st = route({{pt = "VA", crs = 337, alt = 600, altterm = true, name = "(600)"}, {pt = "DF", via = "ZULU1", fix = ZZV}}, RWY)
s = L.new(P)
a = plane({lat = RWY.lat, lon = RWY.lon, hdg = 330, tas = 160, alt = 98, vs = 2000})
local hdgerr = 0
log = fly(st, s, a, 240, {each = function(t, s, air, path)
    if path[1].kind == "heading" then hdgerr = math.max(hdgerr, math.abs(P.wrap180(air.hdg - 330))) end end})
T.check(log[1] and math.abs(log[1].t - (600 - 98) / 2000 * 60) < 0.2, "the heading leg sequenced at 600 ft: "
    .. (log[1] and log[1].t or -1) .. " s")
T.check(hdgerr < 0.5, "heading 337 magnetic held: " .. hdgerr)
T.check(st.rte.legs[1].fix == ZZV and st.rte.legs[1].start, "direct ZZV active, from where the airplane was")
T.check(log[1] and dist(st.rte.legs[1].start, log[1]) < 0.01, "its start: the position at 600 ft")
T.check(math.abs(s.xtk) < 0.1 and s.mode == "path", "then on the line to ZZV: " .. s.xtk)

-- heading 045 to intercept the course 090 into ZZV
st = route({{pt = "VI", crs = 45, turn = "R", name = "(INTC)"}, {pt = "CF", fix = ZZV, crs = 90, dist = 8}},
    P.point(P.point(ZZV, 263, 15), 173, 6))
s = L.new(P)
local s0 = P.point(P.point(ZZV, 263, 15), 173, 6)
a = plane({lat = s0.lat, lon = s0.lon, hdg = 38, tas = 250, alt = 5000})
-- (south of the course, its right: the overshoot to its left)
local after = 0
log = fly(st, s, a, 240, {each = function(t, s, air, path) if path[1].kind == "line" then
    after = math.max(after, -s.xtk) end end})
T.equal(#log, 1, "the intercept sequenced")
local xti = log[1] and math.abs((P.track(ZZV, 83, log[1]))) or -1
T.check(xti > 0.6 and xti < 1.0, "where the turn onto the course starts, 0.8 nm off it (the roll into it too): " .. xti)
T.check(after < 0.3, "the course captured without overshooting 0.3 nm: " .. after)
T.check(math.abs(s.xtk) < 0.05, "and held: " .. s.xtk)

-- DIRECT TO a fix behind (FCOM p.1237): the turn onto the course from
-- where the airplane is, then the great circle from there; no loop back
-- to the line from where it was at EXEC
local HERE = {lat = 35.3, lon = 140.0}
local BEHIND = P.point(HERE, 170, 10)
st = route({{via = "DIRECT", fix = BEHIND, dto = true, from = HERE}, {via = "DIRECT", fix = P.point(BEHIND, 170, 30)}}, A)
s = L.new(P)
a = plane({lat = HERE.lat, lon = HERE.lon, hdg = 0, tas = 250})
local devd, left = 0, false
log = fly(st, s, a, 300, {each = function(t, s, air, path)
    if path[1].direct then devd = math.max(devd, math.abs(s.xtk)) end
    if t < 15 and a.bank < -1 then left = true end end})
T.equal(#log, 1, "the fix behind reached")
T.check(not left, "the shorter turn, to the right")
T.check(devd < 0.1, "within 0.1 nm of the path flown (from where the turn ended): " .. devd)
T.check(log[1] and log[1].t < 260, "no loop: there in " .. (log[1] and log[1].t or -1) .. " s (the turn and 10 nm: about 230 s)")

-- the procedure's turn direction: heading 300 (293 true) turning right
-- from north, the long way round (the shorter is left)
st = route({{pt = "VM", crs = 300, turn = "R", name = "VECTORS"}, {via = "DIRECT", fix = ZZV}}, A)
s = L.new(P)
a = plane({lat = A.lat, lon = A.lon, hdg = 0, tas = 250})
local wentleft, rightturn = false, false
fly(st, s, a, 200, {each = function(t, s)
    if t < 60 and s.roll < -1 then wentleft = true end
    if t > 5 and t < 60 and s.roll > 20 then rightturn = true end end})
T.check(rightturn and not wentleft, "turned right as the procedure says, not the shorter way left (CIFP field 10)")
T.check(math.abs(P.wrap180(a.hdg - 293)) < 1, "then heading 300 magnetic held: " .. a.hdg)
-- heading 160 to intercept the course 283 into ZZV: a turn of 123 degrees
-- onto it, begun early enough (estimate)
local Z283 = P.point(P.point(ZZV, 96, 10), 6, 5)
st = route({{pt = "VI", crs = 160, name = "(INTC)"}, {pt = "CF", fix = ZZV, crs = 283, dist = 10}}, Z283)
s = L.new(P)
a = plane({lat = Z283.lat, lon = Z283.lon, hdg = 153, tas = 220, alt = 5000})
local over123 = 0
log = fly(st, s, a, 240, {each = function(t, s, air, path) if path[1].kind == "line" then
    over123 = math.max(over123, -s.xtk) end end})
T.equal(#log, 1, "the 123 degree intercept sequenced")
T.check(over123 < 0.5, "the course 283 captured overshooting less than 0.5 nm: " .. over123)
T.check(math.abs(s.xtk) < 0.05, "and held: " .. s.xtk)

-- the capture criteria, armed (not engaged): 10 nm off the leg
local LEFT = P.point(P.point(A, 0, 10), 270, 10)
st = route({{via = "DIRECT", fix = B}}, A)
s = L.new(P)
a = plane({lat = LEFT.lat, lon = LEFT.lon, hdg = 0, tas = 250})
fly(st, s, a, 1, {engaged = false, armed = true})
T.check(not s.valid and s.msg_intc, "parallel 10 nm off: not captured, NOT ON INTERCEPT HEADING (FCOM p.1435)")
local function captured_at(hdg, tas)
    local a = plane({lat = LEFT.lat, lon = LEFT.lon, hdg = hdg, tas = tas})
    local at_valid = nil
    fly(st, L.new(P), a, 400, {engaged = false, armed = true, each = function(t, s)
        if s.valid and not at_valid then at_valid = math.abs(s.xtk) end end})
    return at_valid or -1
end
local c45 = captured_at(45, 250)
T.check(c45 > 2.45 and c45 <= 2.5, "heading 045 toward it at 250 kt: captured within 2.5 nm (ATA34_2 p.618): " .. c45)
-- 090 at 450 kt: the turn onto it begins 6.3 nm off it (the radius) and
-- 0.5 nm for the roll into it
local c90 = captured_at(90, 450)
T.check(c90 > 6.5 and c90 < 7.2, "heading 090 at 450 kt: captured where the turn onto it at 25 degrees begins: " .. c90)
a = plane({lat = LEFT.lat, lon = LEFT.lon, hdg = 45, tas = 250})
fly(st, s, a, 1, {engaged = false, armed = true})
T.check(not s.valid and not s.msg_intc, "still far: not captured yet, no message")
local NEAR = P.point(P.point(A, 0, 26), 270, 10)
a = plane({lat = NEAR.lat, lon = NEAR.lon, hdg = 30, tas = 250})
fly(st, s, a, 1, {engaged = false, armed = true})
T.check(not s.valid and s.msg_intc, "meeting the leg past its end: not intercepting")
a = plane({lat = P.point(A, 0, 10).lat, lon = 140.0 + 2 / 50, hdg = 180, tas = 250})
fly(st, s, a, 1, {engaged = false, armed = true})
T.check(s.valid, "within 2.5 nm: captured whatever the heading")
a = plane({lat = LEFT.lat, lon = LEFT.lon, hdg = 45, tas = 250, ground = true})
fly(st, s, a, 1, {engaged = false, armed = true})
T.check(not s.msg_intc, "on the ground: no message (estimate)")

-- 21 nm off the leg: not sequenced (FCOM p.1237)
local function abeam(off)
    local st = route({{via = "DIRECT", fix = B, flyover = true}, {via = "DIRECT", fix = C}}, A)
    local s = L.new(P)
    local p0 = P.point(P.point(A, 0, 25), 90, off)
    local a = plane({lat = p0.lat, lon = p0.lon, hdg = 0, tas = 250})
    return #fly(st, s, a, 120, {engaged = false})
end
T.equal(abeam(25), 0, "25 nm off: B not sequenced")
T.equal(abeam(15), 1, "15 nm off: sequenced")

-- a discontinuity after B: the heading held, DISCONTINUITY (FCOM p.1431)
st = route({{via = "DIRECT", fix = B}, {disc = true}, {via = "DIRECT", fix = C}}, A)
s = L.new(P)
a = plane({lat = 35.4, lon = 140.0, hdg = 0, tas = 250})
log = fly(st, s, a, 120)
T.equal(#log, 1, "B sequenced")
T.check(st.rte.legs[1].disc, "the discontinuity now first")
T.check(s.mode == "hold" and s.msg_disc, "the heading held, DISCONTINUITY")
T.check(math.abs(P.wrap180(a.hdg - 0)) < 1, "north still: " .. a.hdg)
-- the end of the route
st = route({{via = "DIRECT", fix = B}}, A)
s = L.new(P)
a = plane({lat = 35.4, lon = 140.0, hdg = 2, tas = 250})
log = fly(st, s, a, 120)
T.equal(#log, 0, "the last waypoint not sequenced")
T.check(s.eor and s.mode == "hold" and s.msg_eor, "past it: the heading held, END OF ROUTE")
local h0 = a.hdg
fly(st, s, a, 30)
T.check(math.abs(P.wrap180(a.hdg - h0)) < 1, "the heading kept")

-- a new active leg out of the capture: the heading held until captured
st = route({{via = "DIRECT", fix = B}}, A)
s = L.new(P)
a = plane({lat = 35.2, lon = 140.0, hdg = 0, tas = 250})
fly(st, s, a, 5)
st.rte.legs = {{via = "DIRECT", fix = P.point(P.point(A, 90, 30), 0, 60)}}
st.rte.runway = P.point(A, 90, 30)
L.reset(s)
fly(st, s, a, 5)
T.check(s.mode == "hold", "30 nm from the new leg, parallel: the heading held (FCOM p.644)")
-- the crew: HDG SEL 060 toward it (LNAV out), LNAV armed again
a.hdg = 60
local captured = nil
fly(st, s, a, 600, {engaged = false, armed = true, engage_when_valid = true, each = function(t, s)
    if s.valid and not captured then captured = math.abs(s.xtk) end end})
T.check(captured and captured <= 2.5, "heading 060 toward it, LNAV armed: captured within 2.5 nm (" .. tostring(captured) .. " nm)")
T.check(s.mode == "path" and math.abs(s.xtk) < 0.1, "then flown: " .. s.xtk)

-- on the ground nothing sequences (estimate)
st = route({{pt = "VA", crs = 337, alt = 600, altterm = true}, {via = "DIRECT", fix = ZZV}}, RWY)
s = L.new(P)
a = plane({lat = RWY.lat, lon = RWY.lon, hdg = 330, tas = 0.1, alt = 1000, ground = true})
T.equal(#fly(st, s, a, 1, {engaged = false}), 0, "on the ground above 600 ft: not sequenced")
a.ground = false
a.tas = 150
T.equal(#fly(st, s, a, 1, {engaged = false}), 1, "airborne: sequenced")

-- vectors: the heading flown, never sequenced (FCOM p.1237)
st = route({{pt = "VM", crs = 330, name = "VECTORS"}, {via = "DIRECT", fix = ZZV}}, A)
s = L.new(P)
a = plane({lat = A.lat, lon = A.lon, hdg = 300, tas = 220})
log = fly(st, s, a, 120)
T.equal(#log, 0, "VECTORS not sequenced")
T.check(s.mode == "heading" and math.abs(P.wrap180(a.hdg - 323)) < 1, "heading 330 magnetic (323 true) flown: " .. a.hdg)

-- no active route: nothing valid
s = L.new(P)
L.update(s, nil, state(plane({lat = 35, lon = 140, hdg = 0, tas = 250})), true, false)
T.check(not s.valid and s.roll == 0, "no active route: no steering")

T.done()
