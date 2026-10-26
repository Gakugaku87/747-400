-- The FMC's lateral path (6-1/6-2 step 6a; the plan and sources:
-- docs/overhaul/notes/ATA-34-61-FMC.md §26): the shape of the route's legs
-- for LNAV (step 6b) and the ND (step 6d).
--  - LNAV flies great circles between the waypoints; a procedure's legs a
--    heading, a track or a DME arc (FCOM p.1245), an RF leg an arc of
--    constant radius (FCOM p.1247; FCTM p.61); curved transitions join the
--    legs (ATA34_2 p.615, p.626).
--  - An element for each leg: {leg (its index), kind, a (where it
--    starts), b (where it ends: the fix, or a conditional leg's end as
--    predicted; nil when it cannot be), len (nm), term (how it ends:
--    "fix", "alt", "dme", "radial", "intc", "dist", "manual"), alt (ft),
--    dme (nm), navaid, radial (true degrees), flyover, turn (the
--    procedure's turn direction into it: "L", "R"), missed}
--      "disc": a discontinuity or a pending airway, no path
--      "line": the great circle from a to b, crs its course at a (true
--        degrees): TF, DF, IF, CF and the FMC's own legs (DIRECT, airways,
--        direct-to); `direct` for a DF and a DIRECT TO (not one with an
--        INTC CRS): LNAV flies them from where the airplane is
--      "course": the great circle from a on the true course crs: CA, CD,
--        CI, CR from the leg before's end; FA, FC, FD, FM from their fix
--      "heading": the true heading hdg from a (mag: the magnetic one), no
--        wind in the prediction: VA, VD, VI, VM, VR
--      "arc": around center, radius r (nm), dir "R" clockwise or "L", from
--        a to b: RF; AF around its navaid at its DME distance
--      "none": no path into the fix b (after a discontinuity, or after a
--        leg whose end cannot be predicted)
--  - The sources leave these out (estimate): a course leg flies the line
--    from where it starts; a DF and the conditional legs start where the
--    leg before ended; a leg ending at an altitude ends where a climb of
--    GRAD ft/nm from the altitude before reaches it; a CF starts abeam the
--    point before it on its course; holds and procedure turns (HA, HF, HM,
--    PI) the line to their fix until step 7. A fly-by turn's radius from
--    the ground speed and BANK degrees of bank, its start r tan(delta / 2)
--    before the fix, at most half of either leg; turns of more than
--    MAX_FLYBY degrees, against the procedure's turn direction, onto a
--    heading or onto a leg not starting at the fix flown over the fix.
-- Pure.
--   local P = B747_path_model                      -- in XTLua, after dofile
--   local P = dofile(".../B747.68.path_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_path_model = M

local NM = 3440.065           -- the earth's radius, nm
local RAD = math.pi / 180
local G = 9.80665
local KT = 1852 / 3600        -- m/s in a knot
M.BANK = 25
M.MAX_FLYBY = 135
M.GRAD = 500
-- an FM or VM leg's line on the ND (no end: FCOM p.1237), nm (estimate)
M.VECTORS_LEN = 10

local function wrap180(a) return (a + 180) % 360 - 180 end
M.wrap180 = wrap180

-- the great circle's course from a to b at a (true degrees) and its length
-- (nm)
function M.course(a, b)
    local p1, p2, dl = a.lat * RAD, b.lat * RAD, (b.lon - a.lon) * RAD
    local y = math.sin(dl) * math.cos(p2)
    local x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    local h = math.sin((p2 - p1) / 2) ^ 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ^ 2
    return (math.atan2(y, x) / RAD + 360) % 360, 2 * math.asin(math.min(1, math.sqrt(h))) * NM
end

-- the point d nm from a on the true course crs
function M.point(a, crs, d)
    local lat1, lon1, t, s = a.lat * RAD, a.lon * RAD, crs * RAD, d / NM
    local lat2 = math.asin(math.sin(lat1) * math.cos(s) + math.cos(lat1) * math.sin(s) * math.cos(t))
    local lon2 = lon1 + math.atan2(math.sin(t) * math.sin(s) * math.cos(lat1), math.cos(s) - math.sin(lat1) * math.sin(lat2))
    return {lat = lat2 / RAD, lon = (lon2 / RAD + 540) % 360 - 180}
end

-- p against the great circle through a on the true course crs: its
-- cross-track distance (nm, right of the course positive) and its
-- along-track distance from a (nm, negative before a)
function M.track(a, crs, p)
    local c, d = M.course(a, p)
    local s = d / NM
    local xt = math.asin(math.sin(s) * math.sin((c - crs) * RAD))
    local at = math.acos(math.max(-1, math.min(1, math.cos(s) / math.cos(xt))))
    if math.cos((c - crs) * RAD) < 0 then at = -at end
    return xt * NM, at * NM
end

-- the course of the great circle through a on crs, `at` nm along it
function M.course_at(a, crs, at)
    if math.abs(at) < 0.01 then return crs end
    local q = M.point(a, crs, at)
    local back = M.course(q, a)
    if at > 0 then return (back + 180) % 360 end
    return back
end

-- a local plane around o (nm east and north), for the terminal geometry
local function xy(o, p)
    local dlon = (p.lon - o.lon + 540) % 360 - 180
    return dlon * 60 * math.cos(o.lat * RAD), (p.lat - o.lat) * 60
end
local function ll(o, x, y)
    return {lat = o.lat + y / 60, lon = (o.lon + x / (60 * math.cos(o.lat * RAD)) + 540) % 360 - 180}
end

-- where the line from a on the true course crs first meets the circle
-- around c of radius r (from inside: going out), ahead of a; nil if never
local function line_circle(a, crs, c, r)
    local ax, ay = xy(c, a)
    local ux, uy = math.sin(crs * RAD), math.cos(crs * RAD)
    local b = ax * ux + ay * uy
    local q = ax * ax + ay * ay - r * r
    local disc = b * b - q
    if disc < 0 then return nil end
    local t = q < 0 and (-b + math.sqrt(disc)) or (-b - math.sqrt(disc))
    if t < 0 then return nil end
    return ll(c, ax + t * ux, ay + t * uy)
end

-- where the line from a on crs crosses the line through o on crs2 (only
-- ahead of o too when `ray`), ahead of a; nil if never
local function line_line(a, crs, o, crs2, ray)
    local ax, ay = xy(o, a)
    local ux, uy = math.sin(crs * RAD), math.cos(crs * RAD)
    local vx, vy = math.sin(crs2 * RAD), math.cos(crs2 * RAD)
    local den = ux * vy - uy * vx
    if math.abs(den) < 1e-6 then return nil end
    local t = -(ax * vy - ay * vx) / den
    local px, py = ax + t * ux, ay + t * uy
    if t < 0 or (ray and px * vx + py * vy < 0) then return nil end
    return ll(o, px, py)
end

-- a magnetic course, heading or radial as true at p
local function true_of(env, mag, p)
    local v = env.var and env.var(p.lat, p.lon) or 0
    return (mag + (v or 0)) % 360
end

-- an arc's track at p: around its centre, clockwise or not
local function arc_track(e, p)
    return (M.course(e.center, p) + (e.dir == "R" and 90 or -90)) % 360
end

-- the course an element ends on and the one it starts on (true degrees)
function M.end_course(e)
    if e.kind == "line" then
        if e.len < 0.01 then return e.crs end
        return (M.course(e.b, e.a) + 180) % 360
    elseif e.kind == "arc" then
        return arc_track(e, e.b)
    end
    return e.crs or e.hdg
end
function M.start_course(e)
    if e.kind == "arc" then return arc_track(e, e.a) end
    return e.crs or e.hdg
end

local COURSE = {CA = "alt", CD = "dme", CI = "intc", CR = "radial"}
local FROM_FIX = {FA = "alt", FC = "dist", FD = "dme", FM = "manual"}
local HEADING = {VA = "alt", VD = "dme", VI = "intc", VM = "manual", VR = "radial"}
-- the holds' ends (FMSPG p.221-222): at an altitude, at the fix after one
-- loop, by the crew
local HOLD = {HA = "alt", HF = "fix", HM = "manual"}

-- where a course or heading from a on the true direction crs ends, as
-- predicted: e's term with the next leg `nxt` (for the intercepts);
-- `alt` the altitude at a. Sets e.b and e.len
local function predict(e, l, nxt, env, alt)
    local a, crs = e.a, e.crs or e.hdg
    local b = nil
    if e.term == "alt" then
        e.alt = l.alt or 0
        b = M.point(a, crs, math.max(0, e.alt - alt) / (env.grad or M.GRAD))
    elseif e.term == "dme" then
        e.navaid, e.dme = l.navaid, l.dist
        if l.navaid and l.dist then b = line_circle(a, crs, l.navaid, l.dist) end
    elseif e.term == "radial" then
        e.navaid = l.navaid
        if l.navaid and l.theta then
            e.radial = true_of(env, l.theta, l.navaid)
            b = line_line(a, crs, l.navaid, e.radial, true)
        end
    elseif e.term == "dist" then
        if l.dist then b = M.point(a, crs, l.dist) end
    elseif e.term == "intc" and nxt then
        -- the next leg's course: a CF's into its fix, an FA/FC/FD/FM's
        -- from its fix; an AF's arc
        if nxt.pt == "CF" and nxt.fix and nxt.crs then
            b = line_line(a, crs, nxt.fix, true_of(env, nxt.crs, nxt.fix), false)
        elseif FROM_FIX[nxt.pt] and nxt.from_fix and nxt.crs then
            b = line_line(a, crs, nxt.from_fix, true_of(env, nxt.crs, nxt.from_fix), false)
        elseif nxt.pt == "AF" and nxt.navaid and nxt.rho then
            b = line_circle(a, crs, nxt.navaid, nxt.rho)
        end
    elseif e.term == "manual" then
        -- no end (FCOM p.1237): a line for the ND
        e.b, e.len = nil, M.VECTORS_LEN
        return
    end
    e.b = b
    if b then
        local _, d = M.course(a, b)
        e.len = d
    end
end

-- a line's element from a to b
local function line(e, a, b)
    e.kind, e.a, e.b = "line", a, b
    local c, d = M.course(a, b)
    e.crs, e.len = c, d
    if d < 0.01 then e.crs = nil end
    return e
end

-- one leg's element: `l` the route's leg `i`, `prev` where it starts (the
-- leg before's end; nil when unknown), `nxt` the leg after it, `alt` the
-- altitude at `prev` (ft)
function M.element(l, i, prev, nxt, env, alt)
    local e = {leg = i, flyover = l.flyover, turn = l.turn, missed = l.missed, term = "fix"}
    local pt = l.pt
    if l.dto and l.from then
        -- a DIRECT TO (not one with an INTC CRS): flown from where the
        -- airplane is (`direct`: the LNAV model)
        line(e, l.from, l.fix)
        e.direct = not l.crs
        return e
    elseif pt == "CF" and l.fix and l.crs then
        -- the course into the fix, from abeam the point before it
        -- (estimate), else its distance (or 5 nm) back along it
        local c = true_of(env, l.crs, l.fix)
        local a = nil
        if prev then
            local _, at = M.track(l.fix, c, prev)
            if at < 0 then a = M.point(l.fix, c, at) end
        end
        a = a or M.point(l.fix, (c + 180) % 360, l.dist or 5)
        line(e, a, l.fix)
        e.crs = c
        return e
    elseif COURSE[pt] or HEADING[pt] then
        if not (prev and l.crs) then
            e.kind, e.term = "none", COURSE[pt] or HEADING[pt]
            return e
        end
        e.term, e.a = COURSE[pt] or HEADING[pt], prev
        if COURSE[pt] then
            e.kind, e.crs = "course", true_of(env, l.crs, prev)
        else
            e.kind, e.hdg, e.mag = "heading", true_of(env, l.crs, prev), l.crs
        end
        predict(e, l, nxt, env, alt)
        return e
    elseif FROM_FIX[pt] then
        local a = l.from_fix or prev
        if not (a and l.crs) then
            e.kind, e.term = "none", FROM_FIX[pt]
            return e
        end
        e.kind, e.term, e.a, e.crs = "course", FROM_FIX[pt], a, true_of(env, l.crs, a)
        predict(e, l, nxt, env, alt)
        return e
    elseif pt == "AF" and l.navaid and l.rho and l.crs and l.fix then
        -- the DME arc from its boundary radial to its fix (ARINC 424: the
        -- course field the radial it starts on)
        e.kind, e.center, e.r, e.dir = "arc", l.navaid, l.rho, l.turn == "L" and "L" or "R"
        e.a = M.point(l.navaid, true_of(env, l.crs, l.navaid), l.rho)
        e.b = l.fix
    elseif HOLD[pt] and l.fix then
        -- a hold (step 7a): around its fix, the inbound course (true) and
        -- the turn direction (right unless left), its legs' time or
        -- distance; `hold` how it ends, `exit` armed by the crew
        e.kind, e.a, e.b, e.len = "hold", l.fix, l.fix, 0
        e.inbd, e.dir = true_of(env, l.crs or 0, l.fix), l.turn == "L" and "L" or "R"
        e.time, e.dist, e.alt, e.hold, e.exit = l.time, l.dist, l.alt, HOLD[pt], l.exit
        return e
    elseif pt == "RF" and l.center and l.fix and prev then
        local _, r = M.course(l.center, l.fix)
        e.kind, e.center, e.r, e.dir = "arc", l.center, l.arc_r or r, l.turn == "L" and "L" or "R"
        e.a, e.b = prev, l.fix
    elseif l.fix then
        -- TF, DF, IF, the FMC's own legs; holds and procedure turns (step 7)
        if not prev then
            e.kind, e.b = "none", l.fix
            return e
        end
        line(e, prev, l.fix)
        e.direct = pt == "DF"
        return e
    else
        e.kind = "none"
        return e
    end
    -- an arc's length: its swept angle in its direction
    local s, f = M.course(e.center, e.a), M.course(e.center, e.b)
    local sweep = e.dir == "R" and (f - s) % 360 or (s - f) % 360
    e.len = sweep * RAD * e.r
    return e
end

-- the elements of a route's legs (the route model's legs): `start` where
-- the first one starts (the route model's leg_from), env = {var =
-- function(lat, lon) (the magnetic variation there, degrees east, or nil),
-- alt (ft, the altitude at the start), grad (ft/nm)}. elements[i] for
-- legs[i]
function M.build(legs, start, env)
    local out = {}
    local prev, alt = start, env.alt or 0
    for i, l in ipairs(legs) do
        if l.disc or l.pending then
            out[i] = {leg = i, kind = "disc"}
            prev = nil
        else
            local e = M.element(l, i, prev, legs[i + 1], env, alt)
            out[i] = e
            if e.term == "alt" and e.alt then alt = math.max(alt, e.alt) end
            prev = e.b
        end
    end
    return out
end

-- a hold's racetrack (step 7a; FCOM p.1413; FMSPG p.164-165): around its
-- fix f, the inbound course (true) and turns of radius r nm the hold's
-- way, straight legs l nm: {f, o1 (the turn at the fix: its centre), p1
-- (its end, where the outbound leg starts), p2 (the outbound leg's end),
-- o2 (the turn back's centre), s (where the inbound leg starts), sgn (1
-- right, -1 left), n (the course from the fix to the pattern's side)}
function M.racetrack(e, r, l)
    local sgn = e.dir == "L" and -1 or 1
    local n = (e.inbd + 90 * sgn) % 360
    local f = e.b
    local p1 = M.point(f, n, 2 * r)
    local p2 = M.point(p1, (e.inbd + 180) % 360, l)
    return {f = f, o1 = M.point(f, n, r), p1 = p1, p2 = p2, o2 = M.point(p2, (n + 180) % 360, r),
        s = M.point(f, (e.inbd + 180) % 360, l), sgn = sgn, n = n, r = r, l = l}
end
-- a hold's size (FMSPG p.224): the turns' radius at `kt` with BANK
-- degrees of bank, the legs' length: its distance, or its time at
-- `inbound_kt` (the ground speed along the inbound course); without
-- either 1 minute, 1.5 above 14,000 ft (its altitude constraint: FMSPG
-- p.222-223)
function M.hold_size(e, kt, inbound_kt)
    local r = (math.max(kt, 60) * KT) ^ 2 / (G * math.tan(M.BANK * RAD)) / 1852
    local time = e.time or ((e.alt or 0) > 14000 and 1.5 or 1)
    return r, e.dist or time / 60 * math.max(inbound_kt or kt, 60)
end

-- the legs' shape for the ND's line (step 6d; the route model's to_fms):
-- shape[i] = {at = the end of conditional element i (a vectors leg's: its
-- line's VECTORS_LEN nm)} or {pts = the points of arc element i every
-- ARC_STEP degrees (estimate), its ends left out; of hold element i its
-- racetrack, from the fix round to the inbound leg's start: of the size
-- sizes[i] = {r, l} (the hold whose fix is the TO fix: step 7b), else at
-- `kt` (default 250: step 7a)}
M.ARC_STEP = 15
local function arc_points(pts, c, from_brg, r, sgn, step, sweep)
    local k = 1
    while k * step < sweep - step / 3 do
        pts[#pts + 1] = M.point(c, (from_brg + sgn * k * step) % 360, r)
        k = k + 1
    end
end
function M.shape(path, kt, sizes)
    local out = {}
    for i, e in ipairs(path or {}) do
        if e.kind == "hold" then
            local z = sizes and sizes[i]
            local t
            if z then t = M.racetrack(e, z.r, z.l) else t = M.racetrack(e, M.hold_size(e, kt or 250)) end
            local pts = {}
            arc_points(pts, t.o1, (t.n + 180) % 360, t.r, t.sgn, 30, 180)
            pts[#pts + 1] = t.p1
            pts[#pts + 1] = t.p2
            arc_points(pts, t.o2, t.n, t.r, t.sgn, 30, 180)
            pts[#pts + 1] = t.s
            out[i] = {pts = pts}
        elseif (e.kind == "course" or e.kind == "heading") and e.a then
            if e.b then
                out[i] = {at = e.b}
            elseif e.term == "manual" then
                out[i] = {at = M.point(e.a, e.crs or e.hdg, M.VECTORS_LEN)}
            end
        elseif e.kind == "arc" and e.center and e.a and e.len then
            local s0 = M.course(e.center, e.a)
            local sweep = e.len / (e.r * RAD)
            local pts = {}
            local k = 1
            while k * M.ARC_STEP < sweep - M.ARC_STEP / 3 do
                local brg = e.dir == "R" and s0 + k * M.ARC_STEP or s0 - k * M.ARC_STEP
                pts[#pts + 1] = M.point(e.center, brg % 360, e.r)
                k = k + 1
            end
            out[i] = {pts = pts}
        end
    end
    return out
end

-- the fly-by turn from element e1 into e2 at e1's fix, flown at `gs` kt:
-- {r (nm), d (nm before the fix), delta (degrees, right positive), dir,
-- center, t1 (where it starts), t2 (where it ends), c1, c2 (the courses
-- in and out)}; nil when flown over the fix or straight on
function M.turn(e1, e2, gs)
    if not (e1 and e2 and e1.b and e2.a) or e1.term ~= "fix" or e1.flyover then return nil end
    if e1.kind ~= "line" and e1.kind ~= "arc" then return nil end
    if e2.kind ~= "line" and e2.kind ~= "course" and e2.kind ~= "arc" then return nil end
    local _, gap = M.course(e1.b, e2.a)
    if gap > 0.1 then return nil end
    local c1, c2 = M.end_course(e1), M.start_course(e2)
    if not (c1 and c2) then return nil end
    local delta = wrap180(c2 - c1)
    if math.abs(delta) < 1 or math.abs(delta) > M.MAX_FLYBY then return nil end
    if e2.turn and (e2.turn == "R") ~= (delta > 0) then return nil end
    local half = math.tan(math.abs(delta) / 2 * RAD)
    local r = (gs * KT) ^ 2 / (G * math.tan(M.BANK * RAD)) / 1852
    local d = r * half
    local lim = math.min(e1.len or d, e2.len or d) / 2
    if d > lim then d, r = lim, lim / half end
    local t1 = M.point(e1.b, (c1 + 180) % 360, d)
    return {r = r, d = d, delta = delta, dir = delta > 0 and "R" or "L", c1 = c1, c2 = c2,
        t1 = t1, t2 = M.point(e1.b, c2, d), center = M.point(t1, (c1 + (delta > 0 and 90 or -90)) % 360, r)}
end

return M
