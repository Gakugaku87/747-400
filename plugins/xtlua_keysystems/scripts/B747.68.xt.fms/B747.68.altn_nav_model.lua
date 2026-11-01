-- A CDU's alternate navigation (6-1/6-2 step 11e1; notes/ATA-34-61-FMC.md
-- §102). Logic and sources (FCOM p.1275, p.1421-1424; FMSPG p.247-249;
-- ATA34_2 p.589):
--  - Each CDU keeps a copy of the FMC's active route, which the FMC sends
--    at each change (FMSPG p.248): its waypoints and discontinuities, the
--    conditional waypoints, offsets and holding patterns left out (FCOM
--    p.1421); the destination.
--  - With both FMCs failed each CDU navigates on its own IRU: great circle
--    legs (FCOM p.1421); the active waypoint passed when abeam (estimate),
--    the LAST waypoint then with its crossing altitude (FMSPG p.250).
--  - IRS LEGS (FCOM p.1423-1424; FMSPG p.248-249): each leg's course (the
--    active one by the heading reference, magnetic or true; the others
--    true), its distance from the waypoint before (none for the active
--    leg) and the waypoint's coordinates. Entries in 1L-5L, as the FMC's
--    LEGS pages: a waypoint later in the route (the legs before it from
--    that line on go: it moves up), a latitude/longitude (a new waypoint
--    before that line, a discontinuity after it); either on the active
--    waypoint's line from the present position direct to it (FCOM
--    p.1421). Another entry INVALID ENTRY (FMSPG p.248). DELETE: a
--    waypoint (the ones before and after it joined); not a discontinuity
--    (closed by entering the waypoint after it) or the active waypoint
--    (estimates, as the FMC's LEGS). A change is a modification (MOD IRS
--    LEGS), EXEC makes it active, ERASE drops it.
--  - IRS PROGRESS (step 11e2; FCOM p.1425-1426; FMSPG p.250-251): the TO
--    waypoint's distance along the leg from the airplane's abeam point,
--    NEXT's that and the great circle between them, the destination's
--    along the route (MOD during a modification); an alternate entered on
--    4L: a route waypoint ENROUTE WPT (along the route to its first
--    time), another DIR TO ALTERNATE (direct from the airplane), gone with
--    a route change or once the enroute one is passed (the page's glue
--    drops it when the page is left); the cross track error and the
--    desired track (the leg's course at the abeam point).
--
--   local M = B747_altn_nav_model          -- in XTLua, after dofile
--   local s = M.new()
--   M.copy(s, fmc_route, pos)               -- while an FMC works
--   M.sequence(s, pos, alt)                 -- with both failed

local M = setmetatable({}, {})
B747_altn_nav_model = M

M.INVALID_ENTRY, M.INVALID_DELETE = "INVALID ENTRY", "INVALID DELETE"
M.ROWS = 5
local NM = 3440.065
local D = math.pi / 180

function M.distance(a, b)
    local la1, la2 = a.lat * D, b.lat * D
    local dl = (b.lon - a.lon) * D
    local c = math.sin(la1) * math.sin(la2) + math.cos(la1) * math.cos(la2) * math.cos(dl)
    return math.acos(math.max(-1, math.min(1, c))) * NM
end
-- the great circle's true course at `a` towards `b`, 0-360
function M.course(a, b)
    local la1, la2 = a.lat * D, b.lat * D
    local dl = (b.lon - a.lon) * D
    local y = math.sin(dl) * math.cos(la2)
    local x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(dl)
    return (math.atan2(y, x) / D) % 360
end
-- `p` along the great circle from `a` to `b` (nm from a) and across it
-- (nm, right positive)
function M.along_cross(a, b, p)
    local d13 = M.distance(a, p) / NM
    local t13, t12 = M.course(a, p) * D, M.course(a, b) * D
    local xt = math.asin(math.max(-1, math.min(1, math.sin(d13) * math.sin(t13 - t12))))
    local at = math.acos(math.max(-1, math.min(1, math.cos(d13) / math.cos(xt))))
    if math.cos(t13 - t12) < 0 then at = -at end
    return at * NM, xt * NM
end

-- the point `d` nm from `a` on the true course `crs`
function M.course_point(a, crs, d)
    local lat1, lon1, t, x = a.lat * D, a.lon * D, crs * D, d / NM
    local lat2 = math.asin(math.sin(lat1) * math.cos(x) + math.cos(lat1) * math.sin(x) * math.cos(t))
    local lon2 = lon1 + math.atan2(math.sin(t) * math.sin(x) * math.cos(lat1), math.cos(x) - math.sin(lat1) * math.sin(lat2))
    return {lat = lat2 / D, lon = (lon2 / D + 540) % 360 - 180}
end

function M.new()
    return {legs = {}, from = nil, dest = nil, last = nil, last_alt = nil, mod = nil, alt = nil}
end
-- the route the pages show: the modification, else the active one
function M.shown(s)
    return s.mod or s
end

local function point(f)
    return {ident = f.ident, lat = f.lat, lon = f.lon}
end
-- the copy of the FMC's active route `r` (B747.68.route_model.lua's: its
-- legs with fix, disc, a hold's pt, a conditional leg's name; passed;
-- dest); `is_hold` the route model's; `pos` where the airplane is (the
-- active leg's start without a waypoint passed)
function M.copy(s, r, is_hold, pos)
    local legs = {}
    for _, l in ipairs(r.legs) do
        if l.disc then
            if #legs > 0 and not legs[#legs].disc then legs[#legs + 1] = {disc = true} end
        elseif l.fix and not is_hold(l) then
            legs[#legs + 1] = point(l.fix)
        end
    end
    s.legs = legs
    local p = r.passed[#r.passed]
    local f = p and p.fix or nil
    if f and (not s.last or s.last.ident ~= f.ident) then s.last, s.last_alt = point(f), nil end
    s.from = f and point(f) or (s.from or (pos and {lat = pos.lat, lon = pos.lon}))
    s.dest = r.dest and point(r.dest) or nil
    s.mod = nil
end

-- the active waypoint passed abeam (estimate): the next one active, the
-- LAST waypoint with the altitude `alt` (FMSPG p.250)
function M.sequence(s, pos, alt)
    local l = s.legs[1]
    if not l or l.disc or not pos then return false end
    local a = s.from or pos
    local along = M.along_cross(a, l, pos)
    if along < M.distance(a, l) then return false end
    s.last, s.last_alt = l, alt
    s.from = {lat = l.lat, lon = l.lon}
    table.remove(s.legs, 1)
    -- an enroute alternate passed: the destination again (FMSPG p.251)
    if s.alt and s.alt.enroute and s.alt.ident == l.ident then s.alt = nil end
    -- the modification too when it starts with the same waypoint
    local m = s.mod
    if m and m.legs[1] == l then
        table.remove(m.legs, 1)
        m.from = s.from
    elseif m then
        s.mod = nil
    end
    return true
end

-- the modification, made from the active route when there is none (a
-- route change drops IRS PROGRESS's alternate: FMSPG p.251)
local function edit(s)
    s.alt = nil
    if not s.mod then
        local legs = {}
        for i, l in ipairs(s.legs) do legs[i] = l end
        s.mod = {legs = legs, from = s.from}
    end
    return s.mod
end

-- an entry on line `k` (1-5 of the page: `i` the leg's index); `ll` the
-- entry as a latitude/longitude (the route model's parse_latlon) or nil;
-- `pos` the airplane's position. Returns an error message or nil
function M.enter(s, i, text, ll, pos)
    local r = M.shown(s)
    if i < 1 or i > #r.legs + 1 then return M.INVALID_ENTRY end
    local j = nil
    if not ll then
        for n = i, #r.legs do
            if r.legs[n].ident == text then j = n break end
        end
        if not j then return M.INVALID_ENTRY end
    end
    local e = edit(s)
    if j then
        for _ = i, j - 1 do table.remove(e.legs, i) end
    else
        table.insert(e.legs, i, {ident = ll.ident, lat = ll.lat, lon = ll.lon})
        local nxt = e.legs[i + 1]
        if nxt and not nxt.disc then table.insert(e.legs, i + 1, {disc = true}) end
    end
    -- the active waypoint's line: present position direct (FCOM p.1421)
    if i == 1 and pos then e.from = {lat = pos.lat, lon = pos.lon} end
    return nil
end

-- DELETE on leg `i`
function M.delete(s, i)
    local r = M.shown(s)
    local l = r.legs[i]
    if not l or l.disc or i == 1 then return M.INVALID_DELETE end
    local e = edit(s)
    table.remove(e.legs, i)
    return nil
end

function M.exec(s)
    if not s.mod then return false end
    s.legs, s.from, s.mod, s.alt = s.mod.legs, s.mod.from, nil, nil
    return true
end
function M.erase(s)
    s.mod, s.alt = nil, nil
end

-- IRS PROGRESS's 4L: a waypoint of the route shown (ENROUTE WPT) or a
-- latitude/longitude `ll` (DIR TO ALTERNATE: FMSPG p.251)
function M.set_alternate(s, text, ll)
    for _, l in ipairs(M.shown(s).legs) do
        if not l.disc and l.ident == text then
            s.alt = {ident = l.ident, lat = l.lat, lon = l.lon, enroute = true}
            return nil
        end
    end
    if ll then
        s.alt = {ident = ll.ident, lat = ll.lat, lon = ll.lon, enroute = false}
        return nil
    end
    return M.INVALID_ENTRY
end

-- IRS PROGRESS from the airplane's position `pos`: {to = {ident, dtg},
-- next, dest = {ident, dtg, title}, xtk (nm, right positive), dtk (true)};
-- the parts without data nil
function M.progress(s, pos)
    local r = M.shown(s)
    local out = {}
    local l = r.legs[1]
    if not pos or not l or l.disc then return out end
    local a = r.from or pos
    local leg = M.distance(a, l)
    local along, cross = M.along_cross(a, l, pos)
    local to_dtg = math.max(0, leg - along)
    out.to = {ident = l.ident, dtg = to_dtg}
    out.xtk = cross
    local abeam = M.course_point(a, M.course(a, l), math.max(0, math.min(leg, along)))
    out.dtk = M.distance(abeam, l) > 0.01 and M.course(abeam, l) or M.course(a, l)
    local n = r.legs[2]
    if n and not n.disc then out.next = {ident = n.ident, dtg = to_dtg + M.distance(l, n)} end
    -- along the route (a discontinuity's waypoints joined: estimate)
    local total, prev, alt_dtg = to_dtg, l, nil
    if s.alt and s.alt.enroute and l.ident == s.alt.ident then alt_dtg = to_dtg end
    for i = 2, #r.legs do
        local p = r.legs[i]
        if not p.disc then
            total = total + M.distance(prev, p)
            prev = p
            if s.alt and s.alt.enroute and not alt_dtg and p.ident == s.alt.ident then alt_dtg = total end
        end
    end
    if s.dest then
        out.dest = {ident = s.dest.ident, dtg = total + M.distance(prev, s.dest), title = s.mod and "MOD" or "DEST"}
    end
    if s.alt and s.alt.enroute and alt_dtg then
        out.dest = {ident = s.alt.ident, dtg = alt_dtg, title = "ENROUTE WPT"}
    elseif s.alt and not s.alt.enroute then
        out.dest = {ident = s.alt.ident, dtg = M.distance(pos, s.alt), title = "DIR TO ALTERNATE"}
    end
    return out
end

-- the IRS LEGS rows from leg `first` on (FCOM p.1423): {ident, lat, lon,
-- crs (true), dist (from the waypoint before; nil for the active leg)} or
-- {disc = true}
function M.rows(s, first, n)
    local r = M.shown(s)
    local out = {}
    for i = first, math.min(#r.legs, first + n - 1) do
        local l = r.legs[i]
        if l.disc then
            out[#out + 1] = {disc = true}
        else
            local prev = i == 1 and r.from or r.legs[i - 1]
            if prev and prev.disc then prev = nil end
            out[#out + 1] = {ident = l.ident, lat = l.lat, lon = l.lon,
                crs = prev and M.course(prev, l) or nil, dist = (i > 1 and prev) and M.distance(prev, l) or nil}
        end
    end
    return out
end

return M
