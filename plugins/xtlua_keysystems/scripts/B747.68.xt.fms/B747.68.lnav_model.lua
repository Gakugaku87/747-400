-- The FMC's LNAV (6-1/6-2 step 6b; the plan and sources:
-- docs/overhaul/notes/ATA-34-61-FMC.md §26): the active leg's guidance on
-- the path (B747.68.path_model.lua's elements), the sequencing and the
-- capture.
--  - The active leg is the active route's first (FCOM p.1331), its element
--    path[1]. The cross-track error from the path and the desired track
--    (ATA34_2 p.617); on a heading leg the heading.
--  - Sequencing (FCOM p.1237): not on the ground (estimate) nor more than
--    21 nm off the active leg; a fly-by fix at the turn's bisector, a
--    fly-over fix abeam it (estimate); a conditional leg when its condition
--    is met (FCOM p.1249: an altitude at or above, a DME distance or a
--    radial crossed, an intercept where the turn onto the next leg starts;
--    vectors never: FCOM p.1237).
--  - Capture (ATA34_2 p.618; FCOM p.644): within 2.5 nm of the active leg,
--    or on a track that intercepts it, where a turn of 25 degrees of bank
--    onto it begins; a heading leg at once. The steering is valid then and
--    the FCC engages LNAV (ATA34_2 p.619). NOT ON INTERCEPT HEADING: armed
--    in the air, out of the capture and not intercepting (FCOM p.1435).
--  - Steering (ATA22 p.348, p.358: from the deviations from the desired
--    track; the law is an estimate): a track back onto the path at most
--    MAX_INTC degrees off it, the more the farther, a bank to it, on an arc
--    or a fly-by turn the arc's own bank too; at most 25 degrees (ATA34_2
--    p.618). A heading leg's heading, magnetic. The procedure's turn
--    direction into a heading leg, or a direct leg still turning onto its
--    course, the long way round too (estimate).
--  - The heading held (FCOM p.644, p.1431): past the last waypoint (END OF
--    ROUTE), at a discontinuity (DISCONTINUITY), and after a new active leg
--    out of the capture until the capture (`recapture`).
--  - A DIRECT TO or a DF flown from where the airplane is: the course to
--    the fix while it turns onto it, then the great circle from there
--    (FCOM p.1237; the turn: estimate).
--  - A hold (step 7a; notes §31): to its fix, the entry by the track over
--    it, the loops, the exit; 30 degrees of bank at most (FCOM p.1413;
--    FMSPG p.164-165, p.221-226).
--  - A procedure turn (step 7f, estimate: the path model's pturn): out
--    from its fix, round the corner onto the 45 degree leg, the 45 degree
--    leg, the 180 degree turn, back until the turn onto the inbound course
--    begins (the next leg captures it).
-- Pure: the path model in, the path and the airplane's state each frame;
-- the commands and the messages out.
--   local L = B747_lnav_model                      -- in XTLua, after dofile
--   local L = dofile(".../B747.68.lnav_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_lnav_model = M

local RAD = math.pi / 180
local G = 9.80665
local KT = 1852 / 3600        -- m/s in a knot
M.CAPTURE = 2.5
M.SEQ_LIMIT = 21
-- during the transitions to and from an offset over 21 nm (FCOM p.1298);
-- END OF OFFSET this far before the offset's end (FCOM p.1431; FMSPG
-- p.155)
M.SEQ_LIMIT_WIDE = 200
M.EOO_DIST = 5
M.BANK = 25
-- in a hold and its entry (FCOM p.1413; FMSPG p.164, p.226-227)
M.HOLD_BANK = 30
-- the steering law (estimate): the steepest intercept back onto the path,
-- the distance ahead it aims at (s at the ground speed), the bank for a
-- degree of track or heading error
M.MAX_INTC = 45
M.LOOKAHEAD = 25
M.K_TRK = 2.5
M.K_HDG = 2.5
-- the turns started this many seconds early for the roll into them
-- (estimate: about 3 degrees a second to 25 degrees)
M.ROLL_LEAD = 4

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function wrap180(a) return (a + 180) % 360 - 180 end

-- the state: `P` the path model
function M.new(P)
    return setmetatable({P = P, mode = nil, hold = nil, turn = nil, recapture = false, eor = false,
        valid = false, roll = 0, xtk = 0, dtk = nil, tae = 0, dtg = nil, seq = 0,
        msg_disc = false, msg_eor = false, msg_intc = false, msg_eoo = false, ofst = false}, {})
end

-- a new active leg not by sequencing (EXEC, ACTIVATE: the route changed):
-- the fly-by turn, the end of the route and a direct leg's start
-- forgotten; engaged, the heading held until the new leg is captured
-- (FCOM p.644)
function M.reset(s)
    s.turn, s.eor, s.recapture, s.anchor, s.hp, s.ahead, s.ptn = nil, false, true, nil, nil, nil, nil
end

-- a direct leg (a DIRECT TO, a DF: the path model's `direct`) as flown:
-- while the airplane turns onto it, the course from where it is to the
-- fix; once on that course (within 3 degrees), the great circle from
-- there (FCOM p.1237: after the EXEC the course is the current course to
-- the waypoint; the turn onto it: estimate)
local function direct(s, e, air, p)
    local P = s.P
    local a = s.anchor
    if not (a and a.lat == e.b.lat and a.lon == e.b.lon) then
        a = {lat = e.b.lat, lon = e.b.lon}
        s.anchor = a
    end
    if not a.from then
        local c, d = P.course(p, e.b)
        if math.abs(wrap180(air.trk - c)) <= 3 or d < 0.5 then a.from = {lat = p.lat, lon = p.lon} end
    end
    local from = a.from or p
    local c, d = P.course(from, e.b)
    return {kind = "line", a = from, b = e.b, crs = c, len = d, term = e.term, flyover = e.flyover, turn = e.turn,
        leg = e.leg, missed = e.missed, direct = true}
end

-- the radius of a turn at gs kt with `bank` degrees of bank (nm)
local function radius(gs, bank)
    return (math.max(gs, 60) * KT) ^ 2 / (G * math.tan(bank * RAD)) / 1852
end
-- the bank of a turn of radius r nm at gs kt, signed by its direction
local function arc_bank(gs, r, dir)
    local b = math.atan((gs * KT) ^ 2 / (G * r * 1852)) / RAD
    return dir == "R" and b or -b
end

-- the airplane at p against a circle around `center` (radius r nm, dir):
-- the cross-track error (nm, right positive), the track along it
local function circle(P, center, r, dir, p)
    local brg, dc = P.course(center, p)
    local xt = dir == "R" and (r - dc) or (dc - r)
    return xt, (brg + (dir == "R" and 90 or -90)) % 360, brg
end

-- the track's angle off a path to fly back onto it from xt nm off it
-- (right positive): the steepest MAX_INTC, the more the farther, aimed
-- LOOKAHEAD s ahead
local function intc_of(xt, air)
    local ahead = math.max(air.gs * KT * M.LOOKAHEAD / 1852, 0.5)
    return clamp(math.atan2(xt, ahead) / RAD, -M.MAX_INTC, M.MAX_INTC)
end
-- in a turn the way `way` (1 right, -1 left): on the track c (within 5
-- degrees) or past it
local function onto(c, trk, way)
    local left = (way * (c - trk)) % 360
    return left <= 5 or left > 300
end

-- the wind along the true course crs (kt): the ground speed's vector less
-- the true airspeed's
local function wind_along(air, crs)
    local tas = air.tas or air.gs
    local wx = air.gs * math.sin(air.trk * RAD) - tas * math.sin(air.hdg * RAD)
    local wy = air.gs * math.cos(air.trk * RAD) - tas * math.cos(air.hdg * RAD)
    return wx * math.sin(crs * RAD) + wy * math.cos(crs * RAD)
end

-- a hold (step 7a): entered as the airplane crosses its fix, by its track
-- then (FCOM p.1413; FMSPG p.165, p.225: the lines through the fix 5 and
-- 70 degrees off the inbound course; the hold's way round: direct 75 (type
-- I) and 105 degrees (type II), parallel 105, teardrop 75)
local function hold_entry(e, air)
    local th = wrap180(air.trk - e.inbd)
    if e.dir == "L" then th = -th end
    if th > -70 and th <= 110 then return "direct" end
    if th > 110 or th <= -175 then return "teardrop" end
    return "parallel"
end
-- its racetrack: the turns at `vt` kt, the legs' time at the speed along
-- the inbound course (FMSPG p.224); with its inbound course `u` and its
-- direction `dir` (a change to the hold flown from the next crossing of
-- the fix: FCOM p.1416)
local function hold_track(s, e, air, vt)
    local P = s.P
    local t = P.racetrack(e, P.hold_size(e, vt, (air.tas or air.gs) + wind_along(air, e.inbd)))
    t.u, t.dir = e.inbd, e.dir
    return t
end
-- the airplane farther than this from the fix as the hold becomes the
-- active leg: to the fix first (FMSPG p.225: the entry once over it;
-- estimate)
M.HOLD_NEAR = 1
-- the hold next, its fix the TO fix (the active leg's: step 7b): its
-- racetrack as it is first made then (FMSPG p.224), kept for the entry
-- and the ND (`s.ahead`)
local function hold_ahead(s, e, nxt, air, vt)
    if not (nxt and nxt.kind == "hold" and e.b and e.b.lat == nxt.b.lat and e.b.lon == nxt.b.lon) then
        s.ahead = nil
        return
    end
    local a = s.ahead
    if a and a.lat == nxt.b.lat and a.lon == nxt.b.lon then return end
    s.ahead = {lat = nxt.b.lat, lon = nxt.b.lon, t = hold_track(s, nxt, air, vt)}
end
-- the hold entered over its fix: its racetrack and its entry. A direct
-- entry (FMSPG p.165, p.225: type I and II, no segment of its own): a turn
-- the hold's way of the turns' radius from the track over the fix onto
-- the outbound course, then the outbound leg captured (estimate). An
-- altitude hold not flown when at its altitude already, nor a hold whose
-- exit is armed (FMSPG p.221-222): false
local function hold_enter(s, h, e, air, vt)
    if e.exit or (e.hold == "alt" and air.alt >= (e.alt or 0)) then return false end
    local a = s.ahead
    local t = (a and a.lat == e.b.lat and a.lon == e.b.lon) and a.t or hold_track(s, e, air, vt)
    s.ahead = nil
    h.t = t
    h.entry = hold_entry(e, air)
    h.phase = h.entry
    -- a fix hold: one loop (FMSPG p.221)
    h.exit = e.hold == "fix"
    if h.entry == "direct" then
        h.c0 = s.P.point(e.b, (air.trk + 90 * t.sgn) % 360, t.r)
    end
    return true
end
-- a hold's racetrack were it made now (the ND's, step 7b)
function M.hold_now(s, e, air)
    return hold_track(s, e, air, (air.tas or air.gs) + (air.wind or 0))
end
-- a frame in the hold: the phases (to the fix; the entry: teardrop, the
-- 40 degree leg of 2.95 r, or parallel, 2.41 r on the reciprocal track,
-- then a turn back onto the inbound course (FMSPG p.225); then the turn
-- at the fix, the outbound leg, the turn back, the inbound leg) and how
-- it ends: at the fix after the exit armed by the crew (EXIT HOLD) or at
-- its altitude, the racetrack made the shortest way back then (on the
-- outbound leg the turn back at once; in the turn at the fix, no outbound
-- leg: FMSPG p.221-222); a fix hold at the fix after its entry. The size
-- anew at each crossing of the fix (FMSPG p.224). Returns 1 when it ends,
-- the cross-track error, the desired track, the arc's bank and a turn
-- direction asked for
local function hold_step(s, e, air, p, vt)
    local P = s.P
    local h = s.hp
    if not (h and h.lat == e.b.lat and h.lon == e.b.lon) then
        h = {lat = e.b.lat, lon = e.b.lon, loops = 0}
        s.hp = h
        local _, d = P.course(p, e.b)
        if d > M.HOLD_NEAR then
            h.phase, h.from = "to", {lat = p.lat, lon = p.lon}
        elseif not hold_enter(s, h, e, air, vt) then
            s.hp = nil
            return 1, 0, nil, 0
        end
    end
    if h.phase == "to" then
        local c, len = P.course(h.from, e.b)
        local xt, at = P.track(h.from, c, p)
        if at < len then return 0, xt, P.course_at(h.from, c, at), 0 end
        if not hold_enter(s, h, e, air, vt) then
            s.hp = nil
            return 1, 0, nil, 0
        end
    end
    local t = h.t
    local u, sgn, dir = t.u, t.sgn, t.dir
    local out = (u + 180) % 360
    local ph = h.phase
    -- EXIT ARMED: by the crew, at the altitude
    if not h.exit and (e.exit or (e.hold == "alt" and air.alt >= (e.alt or 0))) then
        h.exit = true
        if ph == "turn1" or ph == "direct" or ph == "outbound" then
            local l = 0
            if ph == "outbound" then
                local _, at = P.track(t.p1, out, p)
                l, ph = clamp(at, 0, t.l), "turn2"
            end
            t = P.racetrack({b = t.f, inbd = u, dir = dir}, t.r, l)
            t.u, t.dir = u, dir
            h.t = t
        end
    end
    if ph == "direct" or ph == "turn1" then
        -- turned onto the track that captures the outbound leg
        local xt = P.track(t.p1, out, p)
        if onto((out - intc_of(xt, air)) % 360, air.trk, sgn) then ph = "outbound" end
    elseif ph == "outbound" then
        -- the turn back begun ROLL_LEAD early
        local _, at = P.track(t.p1, out, p)
        if at >= t.l - air.gs * KT * M.ROLL_LEAD / 1852 then ph = "turn2" end
    elseif ph == "turn2" or ph == "intercept" then
        -- turned onto the track that captures the inbound course (the
        -- entry's turn back its way)
        local xt = P.track(t.f, u, p)
        local way = ph == "turn2" and sgn or (h.back == "L" and -1 or 1)
        if onto((u - intc_of(xt, air)) % 360, air.trk, way) then ph = "inbound" end
    elseif ph == "inbound" then
        local _, at = P.track(t.f, u, p)
        if at >= 0 then
            h.loops = h.loops + 1
            if h.exit then
                s.hp = nil
                return 1, 0, nil, 0
            end
            t = hold_track(s, e, air, vt)
            h.t = t
            u, sgn, dir = t.u, t.sgn, t.dir
            out = (u + 180) % 360
            ph = "turn1"
        end
    elseif ph == "teardrop" then
        local _, at = P.track(t.f, (out - 40 * sgn) % 360, p)
        if at >= 2.95 * t.r then ph, h.back = "intercept", dir end
    elseif ph == "parallel" then
        local _, at = P.track(t.f, out, p)
        if at >= 2.41 * t.r then ph, h.back = "intercept", dir == "R" and "L" or "R" end
    end
    h.phase = ph
    if ph == "turn1" or ph == "turn2" or ph == "direct" then
        local c = ph == "direct" and h.c0 or (ph == "turn1" and t.o1 or t.o2)
        local xt, dtk = circle(P, c, t.r, dir, p)
        return 0, xt, dtk, arc_bank(air.gs, t.r, dir)
    elseif ph == "outbound" then
        local xt, at = P.track(t.p1, out, p)
        return 0, xt, P.course_at(t.p1, out, at), 0
    elseif ph == "teardrop" then
        local c = (out - 40 * sgn) % 360
        local xt, at = P.track(t.f, c, p)
        return 0, xt, P.course_at(t.f, c, at), 0
    elseif ph == "parallel" then
        -- the track; the offset as the turn from the fix leaves it (FMSPG
        -- p.225)
        return 0, 0, out, 0
    elseif ph == "intercept" then
        -- onto the track that captures the inbound course, its way
        return 0, (P.track(t.f, u, p)), u, 0, h.back
    end
    local xt, at = P.track(t.f, u, p)
    return 0, xt, P.course_at(t.f, u, at), 0
end

-- the airplane at p against element e: the cross-track error (nm, right
-- positive), the desired track (true; nil without one), the distance to
-- its end (nm; nil when open)
local function against(P, e, p)
    if e.kind == "line" or e.kind == "course" then
        if not e.crs then return 0, nil, 0 end
        local xt, at = P.track(e.a, e.crs, p)
        return xt, P.course_at(e.a, e.crs, at), e.len and e.len - at or nil
    elseif e.kind == "arc" then
        local xt, dtk, brg = circle(P, e.center, e.r, e.dir, p)
        local fb = P.course(e.center, e.b)
        local left = e.dir == "R" and (fb - brg) % 360 or (brg - fb) % 360
        -- just past its end: negative
        if left > 300 then left = left - 360 end
        return xt, dtk, left * RAD * e.r
    end
    return 0, nil, nil
end

-- a procedure turn (step 7f, estimate): its shape (the path model's
-- pturn at the turns' speed `vt`) made as it starts, then its phases: out
-- on the outbound course from its fix, round the corner onto the 45
-- degree leg (the shape's fly-by arc, the other way), the 45 degree leg,
-- the 180 degree turn its way, back on the reciprocal of the 45 degree leg
-- until the turn onto the inbound course (45 degrees) begins (the next
-- leg's capture); the corner and the turn begun ROLL_LEAD early (as a
-- hold's turns). Returns 1 when it ends, the cross-track error, the
-- desired track, the arc's bank and a turn direction asked for
local function pturn_step(s, e, air, p, vt)
    local P = s.P
    local h = s.ptn
    if not (h and h.lat == e.fix.lat and h.lon == e.fix.lon and h.leg == e.leg) then
        h = {lat = e.fix.lat, lon = e.fix.lon, leg = e.leg, t = P.pturn(e, vt), phase = "out"}
        s.ptn = h
    end
    local t = h.t
    local roll = air.gs * KT * M.ROLL_LEAD / 1852
    if h.phase == "out" then
        local xt, at = P.track(t.f, t.out, p)
        if at < t.dout - t.k - roll then return 0, xt, P.course_at(t.f, t.out, at), 0, nil end
        h.phase = "corner"
    end
    if h.phase == "corner" then
        local cdir = t.sgn > 0 and "L" or "R"
        if not onto(t.pc, air.trk, -t.sgn) then
            local xt, dtk = circle(P, t.kc, t.r, cdir, p)
            return 0, xt, dtk, arc_bank(air.gs, t.r, cdir), cdir
        end
        h.phase = "leg45"
    end
    local dir = t.sgn > 0 and "R" or "L"
    if h.phase == "leg45" then
        local xt, at = P.track(t.o, t.pc, p)
        if at < t.d45 - roll then return 0, xt, P.course_at(t.o, t.pc, at), 0, nil end
        h.phase = "turn"
    end
    if h.phase == "turn" then
        if not onto(t.back, air.trk, t.sgn) then
            local xt, dtk = circle(P, t.c, t.r, dir, p)
            return 0, xt, dtk, arc_bank(air.gs, t.r, dir), dir
        end
        h.phase = "back"
    end
    local xt, at = P.track(t.q, t.back, p)
    local _, len = P.course(t.q, t.x)
    local lead = radius(vt, M.BANK) * math.tan(22.5 * RAD) + roll
    return (at >= len - lead) and 1 or 0, xt, P.course_at(t.q, t.back, at), 0, nil
end

-- how far off a path the turn onto it at `theta` degrees (up to 150: an
-- intercept leg's) begins (nm): the turn's radius at the speed `vt` kt,
-- the roll into it at the ground speed (estimate)
local function turn_in(air, vt, theta)
    local t = math.min(math.abs(theta), 150) * RAD
    local roll = air.gs * KT * M.ROLL_LEAD / 1852
    return radius(vt, M.BANK) * (1 - math.cos(t)) + roll * (t <= math.pi / 2 and math.sin(t) or 1)
end

-- a track or heading error turned the procedure's way (its turn direction
-- "L" or "R" into the leg: CIFP field 10) while the turn into the leg
-- lasts, the long way round too (estimate: until within 10 degrees)
local function directed(err, dir)
    if dir == "R" and err < -5 then return err + 360 end
    if dir == "L" and err > 5 then return err - 360 end
    return err
end

-- the capture of element e (ATA34_2 p.618): met, and whether the track
-- intercepts it
local function capture(s, e, air, p, vt)
    if e.kind == "heading" then return true, true end
    if e.kind ~= "line" and e.kind ~= "course" and e.kind ~= "arc" then return false, false end
    local xt, dtk, dtg = against(s.P, e, p)
    if not dtk or math.abs(xt) <= M.CAPTURE then return true, true end
    local theta = wrap180(air.trk - dtk)
    if xt * theta >= 0 or math.abs(theta) > 90 then return false, false end
    -- where the track meets it: before its end
    if dtg and math.abs(xt) / math.tan(math.abs(theta) * RAD) > dtg then return false, false end
    return math.abs(xt) <= turn_in(air, vt, theta) + 0.1, true
end

-- whether conditional element e has ended (FCOM p.1249)
local function ended(s, e, path, air, p, vt)
    local P = s.P
    if e.term == "alt" then
        return air.alt >= (e.alt or 0)
    elseif e.term == "dme" and e.navaid and e.dme then
        local _, d = P.course(e.navaid, p)
        local _, d0 = P.course(e.navaid, e.a)
        if d0 < e.dme then return d >= e.dme end
        return d <= e.dme
    elseif e.term == "radial" and e.navaid and e.radial then
        local x0 = P.track(e.navaid, e.radial, e.a)
        local x, at = P.track(e.navaid, e.radial, p)
        return at > 0 and (x0 >= 0) ~= (x >= 0)
    elseif e.term == "dist" then
        local _, _, dtg = against(P, e, p)
        return dtg ~= nil and dtg <= 0
    elseif e.term == "intc" then
        -- where the turn onto the next leg starts
        local n = path[2]
        if not n or (n.kind ~= "line" and n.kind ~= "course" and n.kind ~= "arc") then return false end
        local xt, dtk = against(P, n, p)
        if not dtk then return true end
        local theta = wrap180(air.trk - dtk)
        if xt * theta > 0 or math.abs(theta) >= 150 then return false end
        return math.abs(xt) <= turn_in(air, vt, theta) + 0.05
    end
    return false
end

-- the bank to fly the desired track dtk with the cross-track error xt
-- (and `ff` the arc's own bank; `dir` a turn direction asked for;
-- `bank` the most, BANK unless given)
local function steer(xt, dtk, ff, air, dir, bank)
    local b = bank or M.BANK
    return clamp(M.K_TRK * directed(wrap180(dtk - intc_of(xt, air) - air.trk), dir) + ff, -b, b)
end
local function steer_hdg(hdg, air, dir)
    return clamp(M.K_HDG * directed(wrap180(hdg - air.hdg), dir), -M.BANK, M.BANK)
end

-- the turn direction a leg asks for while the turn into it lasts: a
-- heading leg's, a direct leg's still turning onto its course (the
-- procedure's: `turn`); `err` the heading or track error now (degrees)
local function turn_dir(s, e, err)
    if not e.turn then return nil end
    local key
    if e.kind == "heading" and e.a then
        key = string.format("H %.5f %.5f %s", e.a.lat, e.a.lon, tostring(e.mag))
    elseif e.direct and e.b and not (s.anchor and s.anchor.from) then
        key = string.format("D %.5f %.5f", e.b.lat, e.b.lon)
    else
        return nil
    end
    if s.turned == key then return nil end
    if math.abs(err) < 10 then
        s.turned = key
        return nil
    end
    return e.turn
end

-- one frame: `path` the active route's elements (nil: no active route),
-- air = {lat, lon, trk, hdg (true degrees), gs, tas, wind (kt), alt (ft),
-- var (degrees east), ground (true on the ground)}, `armed` and `engaged`
-- the FCC's LNAV. Sets the outputs: valid (the steering: the FCC engages
-- LNAV), roll (degrees, right positive), mode ("path", "heading", "hold"
-- engaged), xtk (nm, right positive), dtk, tae (the track angle error,
-- degrees), dtg (nm to the active waypoint), the messages. Returns the
-- legs to sequence (0 or 1)
function M.update(s, path, air, armed, engaged)
    local P = s.P
    local p = {lat = air.lat, lon = air.lon}
    local e = path and path[1]
    s.seq, s.msg_intc = 0, false
    if not engaged then s.mode, s.hold, s.recapture = nil, nil, false end
    if not e then
        s.valid, s.roll, s.xtk, s.dtk, s.dtg, s.tae = false, 0, 0, nil, nil, 0
        s.msg_disc, s.msg_eor, s.msg_eoo, s.ofst = false, false, false, false
        return 0
    end
    -- the turns' speed: the true airspeed and the wind's (the fastest
    -- ground speed in a turn; as for the holds: FMSPG p.164)
    local vt = (air.tas or air.gs) + (air.wind or 0)
    if e.direct and e.kind == "line" and e.b then e = direct(s, e, air, p) end
    local met, conv = capture(s, e, air, p, vt)
    local xt, dtk, dtg = against(P, e, p)
    local nxt = path[2]
    hold_ahead(s, e, nxt, air, vt)
    -- a hold (step 7a): its phases, its end, its bank
    local hff, hdir, bank = 0, nil, M.BANK
    if e.kind == "hold" then
        local seq
        seq, xt, dtk, hff, hdir = hold_step(s, e, air, p, vt)
        met, conv, dtg, bank = true, true, nil, M.HOLD_BANK
        if seq == 1 and not air.ground then
            if nxt then s.seq = 1 else s.eor = true end
        end
    elseif e.kind == "pturn" then
        local seq
        seq, xt, dtk, hff, hdir = pturn_step(s, e, air, p, vt)
        met, conv, dtg = true, true, nil
        if seq == 1 and not air.ground then
            if nxt then s.seq = 1 else s.eor = true end
        end
    -- sequencing (not on the ground; within 21 nm of the leg, 200 to and
    -- from a wide offset)
    elseif not air.ground and not s.eor and math.abs(xt) <= (e.wide and M.SEQ_LIMIT_WIDE or M.SEQ_LIMIT) then
        if e.term == "fix" and (e.kind == "line" or e.kind == "arc") then
            -- a turn not flown (the airplane back away from the fix)
            if s.turn and not s.turn.past and dtg and dtg > s.turn.d + 1 then s.turn = nil end
            if not s.turn then
                local tr = P.turn(e, nxt, vt)
                if tr and dtg and dtg <= tr.d + air.gs * KT * M.ROLL_LEAD / 1852 then s.turn = tr end
            end
            if s.turn and not s.turn.past then
                -- past the bisector of the turn
                local u = s.turn
                local _, a1 = P.track(e.b, u.c1, p)
                local _, a2 = P.track(e.b, u.c2, p)
                if a1 + a2 > 0 then u.past, s.seq = true, 1 end
            elseif not s.turn and dtg and dtg <= 0 then
                if nxt then s.seq = 1 else s.eor = true end
            end
        elseif e.kind == "course" or e.kind == "heading" then
            if ended(s, e, path, air, p, vt) then
                if nxt then s.seq = 1 else s.eor = true end
            end
        end
    end
    -- the fly-by turn flown to its end (past the bisector it belongs to
    -- the leg out); not without LNAV, nor 2 nm off it
    local u = s.turn
    if u and u.past and s.seq == 0 then
        local _, at = P.track(u.t2, u.c2, p)
        local cx = circle(P, u.center, u.r, u.dir, p)
        if at >= 0 or not engaged or math.abs(cx) > 2 then s.turn, u = nil, nil end
    end
    -- the guidance
    local ref_xt, ref_dtk, ff = xt, dtk, hff
    if u then
        ref_xt, ref_dtk = circle(P, u.center, u.r, u.dir, p)
        ff = arc_bank(air.gs, u.r, u.dir)
    elseif e.kind == "arc" then
        ff = arc_bank(air.gs, e.r, e.dir)
    end
    s.xtk, s.dtk, s.dtg = ref_xt, ref_dtk, dtg
    s.tae = ref_dtk and wrap180(air.trk - ref_dtk) or 0
    if engaged then
        local mode = "path"
        if e.kind == "heading" then mode = "heading" end
        if e.kind == "disc" or e.kind == "none" or s.eor then mode = "hold" end
        if s.recapture then
            if met and mode ~= "hold" then s.recapture = false else mode = "hold" end
        end
        if mode == "hold" and s.mode ~= "hold" then s.hold = air.hdg end
        s.mode = mode
        s.valid = true
        if mode == "path" and ref_dtk then
            s.roll = steer(ref_xt, ref_dtk, ff, air, hdir or turn_dir(s, e, wrap180(ref_dtk - air.trk)), bank)
        elseif mode == "heading" then
            local hdg = ((e.mag or 0) + (air.var or 0)) % 360
            s.roll = steer_hdg(hdg, air, turn_dir(s, e, wrap180(hdg - air.hdg)))
        else
            s.roll = steer_hdg(s.hold or air.hdg, air)
        end
    else
        s.valid = met and e.kind ~= "disc" and e.kind ~= "none"
        s.roll = (s.valid and ref_dtk) and steer(ref_xt, ref_dtk, ff, air, hdir, bank) or 0
        s.msg_intc = armed and not air.ground and not met and not conv and e.kind ~= "disc"
    end
    s.msg_disc = engaged and (e.kind == "disc" or e.kind == "none")
    s.msg_eor = engaged and s.eor
    -- the offset (step 7d): its guidance (the OFST light: FCOM p.1210),
    -- END OF OFFSET on its last leg
    s.ofst = engaged and e.offset ~= nil
    s.msg_eoo = s.ofst and not (nxt and nxt.offset) and dtg ~= nil and dtg <= M.EOO_DIST
    return s.seq
end

return M
