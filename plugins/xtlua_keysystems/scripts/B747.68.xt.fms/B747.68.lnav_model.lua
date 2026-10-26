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
M.BANK = 25
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
        msg_disc = false, msg_eor = false, msg_intc = false}, {})
end

-- a new active leg not by sequencing (EXEC, ACTIVATE: the route changed):
-- the fly-by turn, the end of the route and a direct leg's start
-- forgotten; engaged, the heading held until the new leg is captured
-- (FCOM p.644)
function M.reset(s)
    s.turn, s.eor, s.recapture, s.anchor = nil, false, true, nil
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
-- (and `ff` the arc's own bank; `dir` a turn direction asked for)
local function steer(xt, dtk, ff, air, dir)
    local ahead = math.max(air.gs * KT * M.LOOKAHEAD / 1852, 0.5)
    local intc = clamp(math.atan2(xt, ahead) / RAD, -M.MAX_INTC, M.MAX_INTC)
    return clamp(M.K_TRK * directed(wrap180(dtk - intc - air.trk), dir) + ff, -M.BANK, M.BANK)
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
        s.msg_disc, s.msg_eor = false, false
        return 0
    end
    -- the turns' speed: the true airspeed and the wind's (the fastest
    -- ground speed in a turn; as for the holds: FMSPG p.164)
    local vt = (air.tas or air.gs) + (air.wind or 0)
    if e.direct and e.kind == "line" and e.b then e = direct(s, e, air, p) end
    local met, conv = capture(s, e, air, p, vt)
    local xt, dtk, dtg = against(P, e, p)
    -- sequencing (not on the ground; within 21 nm of the leg)
    local nxt = path[2]
    if not air.ground and not s.eor and math.abs(xt) <= M.SEQ_LIMIT then
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
    local ref_xt, ref_dtk, ff = xt, dtk, 0
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
            s.roll = steer(ref_xt, ref_dtk, ff, air, turn_dir(s, e, wrap180(ref_dtk - air.trk)))
        elseif mode == "heading" then
            local hdg = ((e.mag or 0) + (air.var or 0)) % 360
            s.roll = steer_hdg(hdg, air, turn_dir(s, e, wrap180(hdg - air.hdg)))
        else
            s.roll = steer_hdg(s.hold or air.hdg, air)
        end
    else
        s.valid = met and e.kind ~= "disc" and e.kind ~= "none"
        s.roll = (s.valid and ref_dtk) and steer(ref_xt, ref_dtk, ff, air) or 0
        s.msg_intc = armed and not air.ground and not met and not conv and e.kind ~= "disc"
    end
    s.msg_disc = engaged and (e.kind == "disc" or e.kind == "none")
    s.msg_eor = engaged and s.eor
    return s.seq
end

return M
