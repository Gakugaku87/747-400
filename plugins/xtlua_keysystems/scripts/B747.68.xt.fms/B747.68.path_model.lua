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
--    procedure's turn direction into it: "L", "R"), missed, start (step
--    6d3: the point before it, where the leg before ended; a CF's line
--    from abeam it)}
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
--      "hold": a hold at its fix (step 7a); "pturn": a procedure turn from
--        its fix (step 7f: M.pturn's shape)
--  - The sources leave these out (estimate): a course leg flies the line
--    from where it starts; a DF and the conditional legs start where the
--    leg before ended; a leg ending at an altitude ends where a climb of
--    GRAD ft/nm from the altitude before reaches it; a CF starts abeam the
--    point before it on its course; a procedure turn's shape (step 7f:
--    M.pturn). A fly-by turn's radius from
--    the ground speed and BANK degrees of bank, its start r tan(delta / 2)
--    before the fix, at most half of either leg; turns of more than
--    MAX_FLYBY degrees, against the procedure's turn direction, onto a
--    heading or onto a leg not starting at the fix flown over the fix.
--  - (step 6d3) A turn flown over the point before a heading or course
--    leg or a DF (a conditional leg's end: LNAV turns once its condition
--    is met, FCOM p.1249; a fly-over fix; a fix with no fly-by turn into
--    the leg): with the turns' speeds (env.kt(i), the turn into leg i)
--    the leg starts where the turn ends, its end predicted from there
--    (ATA34_2 p.615: curved transitions between the path's segments).
--    The turn as LNAV's (estimate): BANK degrees at that speed, the
--    procedure's way else the shorter, from the point itself (no roll-in),
--    a DF's until its track meets the course to the fix (LNAV's direct).
--    turn_in = {from, center, r, dir, sweep (degrees), len (nm)}; none
--    when the condition is met in the turn. The first leg's with env.prev,
--    the element before it (LNAV's last sequenced).
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

-- (2026-11-09) a navaid's own magnetic variation (degrees east), or nil: a
-- localizer's from its magnetic and true courses (earth_nav.dat's 360 *
-- magnetic + true, XP 1200; none in the older form, the magnetic 0), a
-- VOR's station declination
local function nav_var(nav)
    if not nav then return nil end
    if nav.crs_true and nav.crs_mag and nav.crs_mag > 0 then
        local v = (nav.crs_true - nav.crs_mag + 180) % 360 - 180
        if math.abs(v) < 60 then return v end
        return nil
    end
    if nav.kind == "VOR" and nav.var then return nav.var end
    return nil
end
-- a magnetic course, heading or radial as true at p: (2026-11-09) a
-- procedure's course or radial by the variation of the leg's recommended
-- navaid `nav` when it has one (nav_var), else the variation there (the
-- nearest VOR's: B747.68.navdb.lua's variation; headings always). Before,
-- every course by the nearest VOR's: KLAX's ILS24R's final CF legs (251
-- degrees, IOSS: 11.97 degrees east) by the LAX VORTAC's 15 degrees, the
-- ND's line and LNAV's course 3 degrees off the localizer (the line from
-- beside each fix: the perf session's KSEA-KLAX flight, the user).
-- Estimate: the sources give the navaid's MAG VAR (FCOM p.1304, ATA34_2
-- p.547), not which variation a procedure's course takes
local function true_of(env, mag, p, nav)
    local v = nav_var(nav)
    if v == nil then v = env.var and env.var(p.lat, p.lon) or 0 end
    return (mag + (v or 0)) % 360
end

-- an arc's track at p: around its centre, clockwise or not
local function arc_track(e, p)
    return (M.course(e.center, p) + (e.dir == "R" and 90 or -90)) % 360
end

-- the course an element ends on and the one it starts on (true degrees)
function M.end_course(e)
    -- (step 6d3) a leg ended in its turn: the track there
    if e.end_crs then return e.end_crs end
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
-- a procedure turn (PI; step 7f): the sources give no shape (FCTM p.150:
-- within the airspace, its size by the ground speed); asked for as an
-- estimate (the user, 2026-10-27): PANS-OPS's 45/180, from its fix out on
-- the reciprocal of the inbound course, then on the leg's course (45
-- degrees off it, away from the turn) for PT_TIME minutes (PANS-OPS
-- category C-E: 1 min 15 s), a 180 degree turn its way, back on the
-- reciprocal of the leg's course to the inbound course; the outbound leg
-- as long as keeps the turn PT_MARGIN nm inside the leg's distance (its
-- "remain within": ARINC 424's route distance; PT_LIMIT without one)
M.PT_TIME = 1.25
M.PT_LIMIT = 10
M.PT_MARGIN = 1
-- the speed of a procedure turn's end on the route (the ND's symbol's, as
-- the holds': estimate)
M.PT_KT = 210

-- where a course or heading from a on the true direction crs ends, as
-- predicted: e's term with the next leg `nxt` (for the intercepts);
-- `alt` the altitude at a. Sets e.b and e.len
local function predict(e, l, nxt, env, alt, nxt2)
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
            e.radial = true_of(env, l.theta, l.navaid, l.navaid)
            b = line_line(a, crs, l.navaid, e.radial, true)
        end
    elseif e.term == "dist" then
        if l.dist then b = M.point(a, crs, l.dist) end
    elseif e.term == "intc" and nxt then
        -- the next leg's course: a CF's into its fix, an FA/FC/FD/FM's
        -- from its fix; an AF's arc
        if nxt.pt == "CF" and nxt.fix and nxt.crs then
            b = line_line(a, crs, nxt.fix, true_of(env, nxt.crs, nxt.fix, nxt.navaid), false)
        elseif FROM_FIX[nxt.pt] and nxt.from_fix and nxt.crs then
            b = line_line(a, crs, nxt.from_fix, true_of(env, nxt.crs, nxt.from_fix, nxt.navaid), false)
        elseif nxt.pt == "AF" and nxt.navaid and nxt.rho then
            b = line_circle(a, crs, nxt.navaid, nxt.rho)
        elseif nxt.pt == "IF" and nxt.fix and nxt2 and nxt2.fix then
            -- (2026-11-12 review FMC-3) an IF next (an approach's
            -- transition ending on an intercept, the final approach from
            -- its IF: RJBB ILS24R Y via MAYAH, (INTC) then BRASS IF, BEBIL
            -- CF): the course from the IF on, the leg after it (a CF's into
            -- its fix, through the IF; else the IF to that leg's fix).
            -- Before, no end: LNAV held the (INTC)'s heading through the
            -- final approach course (FCOM p.1249: an intercept of the
            -- course to the next waypoint)
            if nxt2.pt == "CF" and nxt2.crs then
                b = line_line(a, crs, nxt2.fix, true_of(env, nxt2.crs, nxt2.fix, nxt2.navaid), false)
            else
                b = line_line(a, crs, nxt.fix, (M.course(nxt.fix, nxt2.fix)), false)
            end
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

-- (step 6d3) the turns flown over the point before a leg (the header's
-- last item). The radius of a turn at kt (LNAV's: at least 60 kt)
local function radius(kt)
    return (math.max(kt, 60) * KT) ^ 2 / (G * math.tan(M.BANK * RAD)) / 1852
end
local COND = {alt = true, dme = true, radial = true, dist = true}
-- whether the turn from element pe into e (from pe's end) is flown over
-- pe's end: a conditional leg's (an intercept's turn begins before it,
-- vectors have no line on), else a fix with no fly-by turn into e
local function turn_over(pe, e, kt)
    if not (pe and pe.b and e.a) then return false end
    if COND[pe.term] then return true end
    if pe.term ~= "fix" or (pe.kind ~= "line" and pe.kind ~= "arc") then return false end
    return M.turn(pe, e, kt) == nil
end
-- a heading or course leg's start moved to the turn's end: from its start
-- on pe's end course round onto its own, `dir` the procedure's way
local function turn_into(e, from, dir)
    local pe = from.pe
    if not turn_over(pe, e, from.kt) then return false end
    local c1, c2 = M.end_course(pe), e.crs or e.hdg
    if not (c1 and c2) then return false end
    local delta = wrap180(c2 - c1)
    if dir == "R" and delta < 0 then delta = delta + 360 elseif dir == "L" and delta > 0 then delta = delta - 360 end
    if math.abs(delta) < 1 then return false end
    local r, sgn, a = radius(from.kt), delta > 0 and 1 or -1, e.a
    local c = M.point(a, (c1 + 90 * sgn) % 360, r)
    e.turn_in = {from = a, center = c, r = r, dir = sgn > 0 and "R" or "L", sweep = math.abs(delta),
        len = r * math.abs(delta) * RAD}
    e.a = M.point(c, (c2 - 90 * sgn) % 360, r)
    return true
end
-- a DF's: from its start on pe's end course round towards the fix (the
-- procedure's way, else the fix's side) until the track meets the course
-- to it, the line from there
local function turn_onto(e, from, dir, fix)
    local pe = from.pe
    if not turn_over(pe, e, from.kt) then return false end
    local c1, a = M.end_course(pe), e.a
    if not c1 then return false end
    local rel = wrap180(M.course(a, fix) - c1)
    if math.abs(rel) < 1 and not dir then return false end
    dir = dir or (rel > 0 and "R" or "L")
    local r, sgn = radius(from.kt), dir == "R" and 1 or -1
    local c = M.point(a, (c1 + 90 * sgn) % 360, r)
    local phi, dc = M.course(c, fix)
    if dc <= r + 0.01 then return false end
    local th0 = (c1 - 90 * sgn) % 360
    local th = (phi - sgn * math.acos(r / dc) / RAD) % 360
    local sweep = sgn > 0 and (th - th0) % 360 or (th0 - th) % 360
    if sweep < 1 or sweep > 359 then return false end
    e.turn_in = {from = a, center = c, r = r, dir = dir, sweep = sweep, len = r * sweep * RAD}
    line(e, M.point(c, th, r), fix)
    return true
end
-- e's condition met in its turn (an altitude reached, a DME distance or a
-- radial crossed between the turn's start and its end; `alt` at the
-- turn's start): a test of the arc's point `deg` degrees round, else nil
local function met_in_turn(e, alt, grad)
    local t = e.turn_in
    local a0 = t.from
    if e.term == "alt" and e.alt then
        if alt + t.len * grad < e.alt then return nil end
        return function(_, deg) return alt + t.r * deg * RAD * grad >= e.alt end
    elseif e.term == "dme" and e.navaid and e.dme then
        local _, d0 = M.course(e.navaid, a0)
        local _, d1 = M.course(e.navaid, e.a)
        if (d0 < e.dme) == (d1 < e.dme) then return nil end
        return function(p) local _, d = M.course(e.navaid, p) return (d < e.dme) ~= (d0 < e.dme) end
    elseif e.term == "radial" and e.navaid and e.radial then
        local x0, at0 = M.track(e.navaid, e.radial, a0)
        local x1, at1 = M.track(e.navaid, e.radial, e.a)
        if not ((at0 > 0 or at1 > 0) and (x0 >= 0) ~= (x1 >= 0)) then return nil end
        return function(p) local x = M.track(e.navaid, e.radial, p) return (x >= 0) ~= (x0 >= 0) end
    end
    return nil
end
-- the leg ended on its turn's arc where `met` first holds (LNAV sequences
-- it there and turns on into the next leg): the arc cut there, no line
-- after it, end_crs the track there (M.end_course)
local function end_in_turn(e, met)
    local t = e.turn_in
    local sgn = t.dir == "R" and 1 or -1
    local b0 = M.course(t.center, t.from)
    local function at(deg) return M.point(t.center, (b0 + sgn * deg) % 360, t.r) end
    local lo, hi = 0, t.sweep
    if met(at(0), 0) then hi = 0 end
    for _ = 1, 30 do
        if hi - lo < 0.01 then break end
        local mid = (lo + hi) / 2
        if met(at(mid), mid) then hi = mid else lo = mid end
    end
    local p = at(hi)
    t.sweep, t.len = hi, t.r * hi * RAD
    e.a, e.b, e.len = p, p, 0
    e.end_crs = (b0 + sgn * hi + 90 * sgn) % 360
end

-- one leg's element: `l` the route's leg `i`, `prev` where it starts (the
-- leg before's end; nil when unknown), `nxt` the leg after it, `alt` the
-- altitude at `prev` (ft); `from` (step 6d3) {pe = the element before, kt
-- = the turn's speed} for a turn flown over `prev`
function M.element(l, i, prev, nxt, env, alt, from, nxt2)
    local e = {leg = i, flyover = l.flyover, turn = l.turn, missed = l.missed, term = "fix", start = prev}
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
        local c = true_of(env, l.crs, l.fix, l.navaid)
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
            e.kind, e.crs = "course", true_of(env, l.crs, prev, l.navaid)
        else
            e.kind, e.hdg, e.mag = "heading", true_of(env, l.crs, prev), l.crs
        end
        -- (step 6d3) from the turn's end, climbing in the turn
        local a0 = alt
        if from and turn_into(e, from, l.turn) then a0 = alt + e.turn_in.len * (env.grad or M.GRAD) end
        predict(e, l, nxt, env, a0, nxt2)
        if e.turn_in then
            local met = met_in_turn(e, alt, env.grad or M.GRAD)
            if met then
                -- the condition met in the turn: the leg ends on its arc
                end_in_turn(e, met)
            elseif not e.b and e.term ~= "manual" then
                -- no end from the turn's end: from the point itself
                e.a, e.turn_in = prev, nil
                predict(e, l, nxt, env, alt, nxt2)
            end
        end
        return e
    elseif FROM_FIX[pt] then
        local a = l.from_fix or prev
        if not (a and l.crs) then
            e.kind, e.term = "none", FROM_FIX[pt]
            return e
        end
        e.kind, e.term, e.a, e.crs = "course", FROM_FIX[pt], a, true_of(env, l.crs, a, l.navaid)
        predict(e, l, nxt, env, alt, nxt2)
        return e
    elseif pt == "AF" and l.navaid and l.rho and l.crs and l.fix then
        -- the DME arc from its boundary radial to its fix (ARINC 424: the
        -- course field the radial it starts on)
        e.kind, e.center, e.r, e.dir = "arc", l.navaid, l.rho, l.turn == "L" and "L" or "R"
        e.a = M.point(l.navaid, true_of(env, l.crs, l.navaid, l.navaid), l.rho)
        e.b = l.fix
    elseif HOLD[pt] and l.fix then
        -- a hold (step 7a): around its fix, the inbound course (true) and
        -- the turn direction (right unless left), its legs' time or
        -- distance; `hold` how it ends, `exit` armed by the crew
        e.kind, e.a, e.b, e.len = "hold", l.fix, l.fix, 0
        e.inbd, e.dir = true_of(env, l.crs or 0, l.fix, l.navaid), l.turn == "L" and "L" or "R"
        e.time, e.dist, e.alt, e.hold, e.exit = l.time, l.dist, l.alt, HOLD[pt], l.exit
        return e
    elseif pt == "PI" and l.fix and l.crs then
        -- a procedure turn (step 7f, estimate): from its fix; pc the 45
        -- degree leg's course (true), dir the 180 degree turn's, out the
        -- outbound course (45 degrees the other way from pc), limit its
        -- distance
        e.kind, e.a, e.fix, e.len = "pturn", l.fix, l.fix, 0
        e.pc, e.dir = true_of(env, l.crs, l.fix, l.navaid), l.turn == "L" and "L" or "R"
        e.out = (e.pc + (e.dir == "R" and 45 or -45)) % 360
        e.limit = l.dist or M.PT_LIMIT
        -- where it ends at PT_KT (the next leg starts there; LNAV flies its
        -- own at the speed then)
        e.b = M.pturn(e, M.PT_KT).x
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
        -- (step 6d3) a DF from the turn towards its fix
        if e.direct and from then turn_onto(e, from, l.turn, l.fix) end
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
-- alt (ft, the altitude at the start), grad (ft/nm); (step 6d3) kt =
-- function(i) (the speed of the turn into leg i, kt; none: no turns
-- flown over a point), prev (the element before the first leg)}.
-- elements[i] for legs[i]
function M.build(legs, start, env)
    local out = {}
    local prev, alt, pe = start, env.alt or 0, env.prev
    for i, l in ipairs(legs) do
        if l.disc or l.pending then
            out[i] = {leg = i, kind = "disc"}
            prev, pe = nil, nil
        else
            local from = env.kt and pe and {pe = pe, kt = env.kt(i)} or nil
            local e = M.element(l, i, prev, legs[i + 1], env, alt, from, legs[i + 2])
            out[i] = e
            if e.term == "alt" and e.alt then alt = math.max(alt, e.alt) end
            prev, pe = e.b, e
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
-- a procedure turn's shape at `kt` (step 7f, estimate): the turn's radius
-- with BANK degrees of bank, the 45 degree leg PT_TIME minutes; the
-- corner onto it flown as a fly-by arc of the same radius the other way:
-- {f, o (the outbound leg's end), p (the 45 degree leg's end), c (the
-- turn's centre), q (its end), x (where the leg back meets the inbound
-- course), k (the corner's arc from k nm before o), kc (its centre), r,
-- out, pc, back (the course from q), sgn (1 right, -1 left), dout, d45}
function M.pturn(e, kt)
    local sgn = e.dir == "L" and -1 or 1
    local r = (math.max(kt, 60) * KT) ^ 2 / (G * math.tan(M.BANK * RAD)) / 1852
    local d45 = M.PT_TIME / 60 * math.max(kt, 60)
    -- the turn's centre past the outbound leg's end along it (a) and to
    -- the 45 degree leg's side (b): its farthest point |centre| + r
    local a, b = 0.70711 * (d45 + r), 0.70711 * (d45 - r)
    local lim = math.max(e.limit - M.PT_MARGIN, r)
    local dout = math.max(0, math.sqrt(math.max(0, (lim - r) ^ 2 - b ^ 2)) - a)
    local f = e.fix
    local o = M.point(f, e.out, dout)
    local p = M.point(o, e.pc, d45)
    local n = (e.pc + 90 * sgn) % 360
    local c = M.point(p, n, r)
    local q = M.point(p, n, 2 * r)
    local back = (e.pc + 180) % 360
    local x = line_line(q, back, f, e.out, true) or q
    local k = r * math.tan(22.5 * RAD)
    local kc = M.point(M.point(f, e.out, dout - k), (e.out - 90 * sgn) % 360, r)
    return {f = f, o = o, p = p, c = c, q = q, x = x, k = k, kc = kc, r = r, out = e.out, pc = e.pc, back = back,
        sgn = sgn, dout = dout, d45 = d45, n = n}
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

-- the lateral offset (step 7d; FCOM p.1298-1299; FMSPG p.155): the
-- path with its first n elements (lines to their fixes: the route model's
-- offset_legs) as lines d nm to their right (left negative), each from
-- the corner with the one before to the corner with the one after (the
-- miter of the two offset lines, on the turn's bisector: the fly-by turns
-- and their sequencing as on the route), the first from abeam its start,
-- the last to abeam its fix; then the route as it is. An offset over 21
-- nm: `wide` on the offset lines and the element after (LNAV's sequencing
-- limit 200 nm during the transitions: FCOM p.1298). The path's own
-- elements are not changed
local function normal(crs) return math.cos(crs * RAD), -math.sin(crs * RAD) end
local function shifted(p, crs, d)
    local nx, ny = normal(crs)
    return ll(p, nx * d, ny * d)
end
local function offset_line(e) return e.kind == "line" and e.crs and e.a and e.b end
function M.offset(path, d, n)
    local out = {}
    local wide = math.abs(d) > 21
    local prev_b, done = nil, false
    for i, e in ipairs(path) do
        if not done and i <= n and offset_line(e) then
            local a = prev_b or shifted(e.a, M.start_course(e), d)
            local b
            local nx = path[i + 1]
            if i < n and nx and offset_line(nx) then
                -- the corner: W + d (n1 + n2) / (1 + n1 . n2)
                local n1x, n1y = normal(M.end_course(e))
                local n2x, n2y = normal(M.start_course(nx))
                local k = d / (1 + n1x * n2x + n1y * n2y)
                b = ll(e.b, (n1x + n2x) * k, (n1y + n2y) * k)
            else
                b = shifted(e.b, M.end_course(e), d)
            end
            local c, len = M.course(a, b)
            out[i] = {kind = "line", a = a, b = b, crs = c, len = len, term = "fix", leg = e.leg, flyover = e.flyover,
                missed = e.missed, offset = d, wide = wide or nil}
            prev_b = b
        else
            if prev_b and not done and wide then
                local c = {}
                for k, v in pairs(e) do c[k] = v end
                c.wide, e = true, c
            end
            done = done or prev_b ~= nil
            out[i] = e
        end
    end
    return out
end

-- the legs' shape for the ND's line (step 6d; the route model's to_fms):
-- shape[i] = {at = the end of conditional element i (a vectors leg's: its
-- line's VECTORS_LEN nm)} or {pts = the points of arc element i every
-- ARC_STEP degrees (estimate), its ends left out; of hold element i its
-- racetrack, from the fix round to the inbound leg's start: of the size
-- sizes[i] = {r, l} (the hold whose fix is the TO fix: step 7b), else at
-- `kt` (default 250: step 7a); of procedure turn element i its shape
-- after the fix, sizes[i] = {pt = M.pturn's} (the one LNAV flies), else
-- at `kt` (step 7f)}
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
        if e.kind == "pturn" then
            local z = sizes and sizes[i]
            local t = (z and z.pt) or M.pturn(e, kt or 250)
            local pts = {t.o, t.p}
            arc_points(pts, t.c, (t.n + 180) % 360, t.r, t.sgn, 30, 180)
            pts[#pts + 1] = t.q
            pts[#pts + 1] = t.x
            out[i] = {pts = pts}
        elseif e.kind == "hold" then
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
