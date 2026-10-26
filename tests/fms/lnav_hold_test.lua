-- Run from the repository root with LuaJIT: luajit tests/fms/lnav_hold_test.lua
-- The FMC's holds (6-1/6-2 step 7a; notes/ATA-34-61-FMC.md §31): the LNAV
-- model (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua)
-- in a hold of the path model, in closed loop with the airplane of
-- tests/lib/lnav_sim.lua: the entries by the track over the fix (FMSPG
-- p.165, p.225: direct type I and II, teardrop, parallel), right and left,
-- the loops (FCOM p.1413; FMSPG p.164: 30 degrees of bank at most), the
-- size anew at each crossing (FMSPG p.224), the ends (FMSPG p.221-222: EXIT
-- HOLD the shortest way back, the altitude, one loop), the fix crossed
-- first (FMSPG p.225), a change flown from the next crossing (FCOM p.1416).
local T = dofile("tests/lib/check.lua")("lnav_hold")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")

local VAR = -7
local SIM = dofile("tests/lib/lnav_sim.lua")(N, R, P, L, VAR)
local route, plane, fly = SIM.route, SIM.plane, SIM.fly
local function wrap180(a) return (a + 180) % 360 - 180 end
local function mag(t) return (t - VAR) % 360 end
local function fmt(v) return string.format("%.2f", v) end

-- the hold's fix, a leg on after it
local H = {lat = 35.5, lon = 140.0}
local NEXT = P.point(H, 90, 40)
-- 250 kt in still air: the turns' radius at 25 degrees, 1 minute legs
local R250, L250 = 1.953, 250 / 60

-- p in the hold's frame: x toward its side (nm), y along the inbound
-- course from the fix
local function frame(u, dir, p)
    local xt, at = P.track(H, u, p)
    return dir == "L" and -xt or xt, at
end
-- the hold `hold` (its course `inbd` true) flown `secs` s, the airplane
-- coming to it on the true track `trk` (from 6 nm, opts.dist); opts.tas,
-- alt, vs, wind, wind_from; opts.legs the route instead of the leg to H,
-- the hold, a leg on; opts.each(t, s, air, path, r). Returns what was
-- seen: the phases in turn, the bank most, the frame's extent after the
-- entry (from the first inbound leg), the crossings of the fix (time, x),
-- the turn directions in the phases
local function fly_hold(hold, trk, secs, opts)
    opts = opts or {}
    local back = (trk + 180) % 360
    local p0 = P.point(H, back, opts.dist or 6)
    local legs = opts.legs or {{via = "DIRECT", fix = H}, hold, {via = "DIRECT", fix = NEXT}}
    local st = route(legs, P.point(H, back, 20))
    local s = L.new(P)
    local a = plane({lat = p0.lat, lon = p0.lon, hdg = trk, tas = opts.tas or 250, alt = opts.alt or 10000,
        vs = opts.vs or 0, wind = opts.wind or 0, wind_from = opts.wind_from or 0})
    local r = {phases = {}, bank = 0, xmin = 99, xmax = -99, ymin = 99, ymax = -99, cross = {}, roll = {}, st = st, s = s, a = a}
    local u = (hold.crs + VAR) % 360
    local entered, loops = false, 0
    r.log = fly(st, s, a, secs, {each = function(t, s, air, path)
        local e = path[1]
        if e and e.kind == "hold" and s.hp and s.hp.phase then
            local ph = s.hp.phase
            if r.phases[#r.phases] ~= ph then r.phases[#r.phases + 1] = ph end
            r.bank = math.max(r.bank, math.abs(s.roll))
            local x, y = frame(u, hold.turn, air)
            if ph == "inbound" then entered = true end
            if entered then
                r.xmin, r.xmax = math.min(r.xmin, x), math.max(r.xmax, x)
                r.ymin, r.ymax = math.min(r.ymin, y), math.max(r.ymax, y)
            end
            local rr = r.roll[ph] or {min = 0, max = 0}
            rr.min, rr.max = math.min(rr.min, s.roll), math.max(rr.max, s.roll)
            r.roll[ph] = rr
            if s.hp.loops > loops then
                loops = s.hp.loops
                r.cross[#r.cross + 1] = {t = t, x = x}
            end
            r.hp = s.hp
        end
        if opts.each then return opts.each(t, s, air, path, r) end
    end})
    return r
end
local function phases(r, n) return table.concat(r.phases, " ", 1, math.min(n or #r.phases, #r.phases)) end
local function hm(t)
    t.pt, t.fix, t.crs, t.turn, t.time = t.pt or "HM", t.fix or H, mag(t.inbd or 0), t.turn or "R", t.time or 1
    return t
end

-- a direct entry on the inbound course (type I: FMSPG p.165), three loops
local hold = hm({})
local r = fly_hold(hold, 0, 1050)
T.equal(phases(r, 6), "direct outbound turn2 inbound turn1 outbound", "on the inbound course: the turn at the fix, the outbound leg, the turn back, the inbound leg")
T.check(r.log[1] and r.log[1].e.leg == 1 and #r.log == 1, "the leg to H sequenced, the hold active since")
T.equal(#r.cross, 3, "three loops in 1050 s")
T.check(r.bank <= 30, "the bank at most 30 degrees (FMSPG p.164): " .. fmt(r.bank))
T.near(r.hp.t.r, R250, 0.01, "the turns' radius at 250 kt and 25 degrees (FMSPG p.224)")
T.near(r.hp.t.l, L250, 0.01, "the legs: 1 minute at 250 kt")
local lt = r.cross[2] and r.cross[3] and r.cross[3].t - r.cross[2].t or -1
T.check(math.abs(lt - (2 * math.pi * R250 / 250 * 3600 + 120)) < 15, "a loop in the two turns and two minutes: " .. fmt(lt) .. " s")
T.check(r.xmin > -0.3 and r.xmax < 2 * R250 + 0.3, "within the racetrack's width: " .. fmt(r.xmin) .. " to " .. fmt(r.xmax))
T.check(r.ymin > -(L250 + R250) - 0.4 and r.ymax < R250 + 0.4, "and its length: " .. fmt(r.ymin) .. " to " .. fmt(r.ymax))
T.check(math.abs(r.cross[2] and r.cross[2].x or 9) < 0.15 and math.abs(r.cross[3] and r.cross[3].x or 9) < 0.15,
    "over the fix on the inbound course")
T.check(r.roll.turn1.min > -1 and r.roll.turn2.min > -1, "turning right only")
T.equal(r.s.mode, "path", "LNAV's mode: on the path")

-- teardrop (FMSPG p.225): from the north-west on 150, the leg 40 degrees
-- off the outbound course on the hold's side for 2.95 r, the turn the
-- hold's way onto the inbound course
r = fly_hold(hm({}), 150, 700)
T.equal(phases(r, 5), "teardrop intercept inbound turn1 outbound", "on 150: teardrop")
T.check(r.roll.intercept.min > -1 and r.roll.intercept.max > 25, "the turn back to the right")
T.check(math.abs(r.cross[1] and r.cross[1].x or 9) < 0.3, "the inbound course captured before the fix: " .. fmt(r.cross[1] and r.cross[1].x or 9))
T.check(r.bank <= 30, "at most 30 degrees of bank: " .. fmt(r.bank))
T.check(r.xmin > -0.3, "not out of the hold's side after: " .. fmt(r.xmin))
-- parallel: from the north-east on 240, the reciprocal track on the
-- other side for 2.41 r, the turn the other way back
local px = 0
r = fly_hold(hm({}), 240, 700, {each = function(t, s, air, path, r)
    if s.hp and s.hp.phase == "parallel" then local x = frame(0, "R", air) px = math.min(px, x) end end})
T.equal(phases(r, 5), "parallel intercept inbound turn1 outbound", "on 240: parallel")
T.check(px < -0.3, "the parallel leg on the other side: " .. fmt(px))
T.check(r.roll.intercept.max < 1 and r.roll.intercept.min < -25, "the turn back to the left")
T.check(math.abs(r.cross[1] and r.cross[1].x or 9) < 0.3, "the inbound course captured before the fix: " .. fmt(r.cross[1] and r.cross[1].x or 9))
-- direct, type II (FMSPG p.165): on 030 toward the hold's side, the turn
-- at the fix to the right at once (the shorter way to the turn's track is
-- left), the outbound leg captured
local out_x = nil
r = fly_hold(hm({}), 30, 400, {each = function(t, s, air, path, r)
    if s.hp and s.hp.phase == "outbound" and not out_x and s.hp.loops == 0 and t > 200 then out_x = s.xtk end end})
T.equal(phases(r, 2), "direct outbound", "on 030: direct")
T.check(r.roll.direct.min > -1 and r.roll.direct.max > 20, "turning right at once: " .. fmt(r.roll.direct.min))
T.check(out_x and math.abs(out_x) < 0.1, "on the outbound leg: " .. tostring(out_x))
-- on 100, away from the inbound course: the turn onto the outbound course,
-- the outbound leg captured (FMSPG p.225)
r = fly_hold(hm({}), 100, 500)
T.equal(phases(r, 4), "direct outbound turn2 inbound", "on 100: direct")
T.check(r.roll.direct.min > -1, "turning right")
T.check(math.abs(r.cross[1] and r.cross[1].x or 9) < 0.15, "then on the inbound course over the fix")
-- type I from the hold's side on 300: the turn at the fix to the right
r = fly_hold(hm({}), 300, 500)
T.equal(phases(r, 3), "direct outbound turn2", "on 300: direct")
T.check(r.roll.direct.min > -1, "turning right: " .. fmt(r.roll.direct.min))
T.check(math.abs(r.cross[1] and r.cross[1].x or 9) < 0.15, "then on the inbound course over the fix")

-- a left hold: teardrop on 210, parallel on 120, direct on 330
r = fly_hold(hm({turn = "L"}), 210, 700)
T.equal(phases(r, 3), "teardrop intercept inbound", "left, on 210: teardrop")
T.check(r.roll.intercept.max < 1, "the turn back to the left")
T.check(r.xmin > -0.3 and math.abs(r.cross[1] and r.cross[1].x or 9) < 0.3, "then on the hold's side, on the inbound course")
r = fly_hold(hm({turn = "L"}), 120, 700)
T.equal(phases(r, 3), "parallel intercept inbound", "left, on 120: parallel")
T.check(r.roll.intercept.min > -1, "the turn back to the right")
r = fly_hold(hm({turn = "L"}), 330, 1000)
T.equal(phases(r, 4), "direct outbound turn2 inbound", "left, on 330: direct")
T.check(r.roll.direct.max < 1 and r.roll.turn2.max < 1, "turning left only")
T.check(r.xmin > -0.3 and r.xmax < 2 * R250 + 0.3 and r.ymin > -(L250 + R250) - 0.4, "within the racetrack")
T.check(math.abs(r.cross[2] and r.cross[2].x or 9) < 0.15, "over the fix on the inbound course")

-- the wind: 30 kt on the nose inbound; the radius at the airspeed and the
-- wind (280 kt), the legs at the speed inbound (220 kt) (FMSPG p.224)
r = fly_hold(hm({}), 0, 1000, {wind = 30, wind_from = 0})
T.near(r.hp.t.r, 2.448, 0.01, "the radius: 280 kt at 25 degrees")
T.near(r.hp.t.l, 220 / 60, 0.02, "the legs: a minute at 220 kt")
T.check(math.abs(r.cross[2] and r.cross[2].x or 9) < 0.2, "over the fix on the inbound course")
T.check(r.bank <= 30, "at most 30 degrees of bank: " .. fmt(r.bank))
-- 30 kt across it
r = fly_hold(hm({}), 0, 1200, {wind = 30, wind_from = 270})
T.check(math.abs(r.cross[2] and r.cross[2].x or 9) < 0.2 and math.abs(r.cross[3] and r.cross[3].x or 9) < 0.2, "across: over the fix on the inbound course")
T.check(r.xmin > -0.6 and r.xmax < 2 * 2.448 + 0.6, "near the racetrack's width: " .. fmt(r.xmin) .. " to " .. fmt(r.xmax))

-- the size anew at each crossing (FMSPG p.224): slower, 210 kt
r = fly_hold(hm({}), 0, 900, {each = function(t, s, air, path, r)
    if #r.cross == 1 and not r.slowed then r.slowed = true r.a.tas = 210 end end})
T.near(r.hp.t.r, 1.378, 0.01, "after the next crossing: the radius at 210 kt")
-- a change in the hold flown from the next crossing (FCOM p.1416)
hold = hm({})
r = fly_hold(hold, 0, 800, {each = function(t, s, air, path, r)
    if #r.cross == 1 and s.hp.phase == "outbound" and not r.changed then
        r.changed = true
        hold.crs = mag(20)
    end
    if r.changed and #r.cross == 1 then r.u1 = s.hp.t.u end
    if #r.cross == 2 then r.u2 = s.hp.t.u return true end end})
T.equal(r.u1, 0, "the inbound course changed to 020: the loop flown as it was")
T.near(r.u2 or -1, 20, 1e-6, "from the next crossing, 020")

-- EXIT HOLD on the outbound leg (FMSPG p.222): the turn back at once,
-- out at the fix
hold = hm({})
r = fly_hold(hold, 0, 900, {each = function(t, s, air, path, r)
    if #r.cross == 1 and s.hp and s.hp.phase == "outbound" then
        r.out_t = r.out_t or t
        if not r.armed and t - r.out_t >= 20 then
            hold.exit, r.armed = true, t
            r.y_armed = select(2, frame(0, "R", air))
        end
    end
    if r.armed and path[1].kind == "hold" then r.y_after = math.min(r.y_after or 0, (select(2, frame(0, "R", air)))) end end})
local out = r.log[2]
T.check(out and out.e.kind == "hold", "the hold sequenced")
T.check(out and r.armed and out.t - r.armed < 2 * math.pi * R250 / 2 / 250 * 3600 + 30, "out the shortest way back: "
    .. fmt(out and r.armed and out.t - r.armed or -1) .. " s after")
T.check(r.y_after and r.y_after > r.y_armed - R250 - 0.4, "no farther than the turn back from where it was armed: "
    .. fmt(r.y_after or 0) .. ", armed at " .. fmt(r.y_armed or 0))
T.check(out and math.abs((frame(0, "R", out))) < 0.15 and math.abs(select(2, frame(0, "R", out))) < 0.1, "out over the fix")
T.check(r.st.rte.legs[1].fix == NEXT, "the leg on active")
-- in the turn at the fix: no outbound leg, round to the fix
hold = hm({})
r = fly_hold(hold, 0, 900, {each = function(t, s, air, path, r)
    if #r.cross == 1 and s.hp and s.hp.phase == "turn1" and not r.armed then hold.exit, r.armed = true, t end
    if r.armed and path[1].kind == "hold" then r.y_after = math.min(r.y_after or 0, (select(2, frame(0, "R", air)))) end end})
out = r.log[2]
T.check(out and out.e.kind == "hold" and out.t - r.armed < 2 * math.pi * R250 / 250 * 3600 + 30, "out after a turn round: "
    .. fmt(out and out.t - r.armed or -1) .. " s")
T.check(r.y_after and r.y_after > -R250 - 0.4, "no outbound leg: " .. fmt(r.y_after or 0))

-- an altitude hold (HA, FMSPG p.221): climbing at 500 fpm to at or above
-- 11000 ft; exit armed there, out the shortest way
hold = hm({pt = "HA", alt = 11000})
r = fly_hold(hold, 0, 900, {alt = 9500, vs = 500})
out = r.log[2]
T.check(out and out.e.kind == "hold" and out.alt >= 11000, "out above 11000 ft: " .. fmt(out and out.alt or 0))
T.check(out and out.t < r.log[1].t + 260, "before a whole loop: " .. fmt(out and out.t - r.log[1].t or -1) .. " s in it")
-- already above it at the fix: not flown
r = fly_hold(hm({pt = "HA", alt = 11000}), 0, 200, {alt = 12000})
T.check(r.log[2] and r.log[2].e.kind == "hold" and r.log[2].t - r.log[1].t < 0.5, "above it at the fix: not flown")
-- a fix hold (HF): one loop
r = fly_hold(hm({pt = "HF"}), 0, 900)
out = r.log[2]
T.check(out and out.e.kind == "hold" and #r.cross == 0, "a fix hold: out at the first crossing")
T.check(out and math.abs(out.t - r.log[1].t - (2 * math.pi * R250 / 250 * 3600 + 120)) < 15, "after one loop: "
    .. fmt(out and out.t - r.log[1].t or -1) .. " s")

-- the hold the active leg 10 nm away: to the fix first (FMSPG p.225)
hold = hm({})
local tox = 0
r = fly_hold(hold, 0, 500, {dist = 10, legs = {hold, {via = "DIRECT", fix = NEXT}}, each = function(t, s, air, path, r)
    if s.hp and s.hp.phase == "to" then tox = math.max(tox, math.abs(s.xtk)) end end})
T.equal(phases(r, 3), "to direct outbound", "to the fix, then the direct entry")
T.check(tox < 0.1, "on the line to it: " .. fmt(tox))
T.check(math.abs(r.cross[1] and r.cross[1].x or 9) < 0.15, "a loop on")

-- DIRECT TO in the hold: out of it at once (FMSPG p.222)
hold = hm({})
r = fly_hold(hold, 0, 600, {each = function(t, s, air, path, r)
    if #r.cross == 1 and s.hp and s.hp.phase == "outbound" then
        r.st.rte.legs = {{via = "DIRECT", fix = NEXT, dto = true, from = {lat = air.lat, lon = air.lon}}}
        L.reset(s)
        r.dto = true
        return true
    end end})
T.check(r.dto and r.s.hp == nil, "the hold forgotten")
fly(r.st, r.s, r.a, 120)
T.check(r.s.mode == "path" and r.s.hp == nil and math.abs(r.s.xtk) < 0.2, "flying to the fix: " .. fmt(r.s.xtk))

T.done()
