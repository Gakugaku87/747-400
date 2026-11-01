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

function M.new()
    return {legs = {}, from = nil, dest = nil, last = nil, last_alt = nil, mod = nil}
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

-- the modification, made from the active route when there is none
local function edit(s)
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
    s.legs, s.from, s.mod = s.mod.legs, s.mod.from, nil
    return true
end
function M.erase(s)
    s.mod = nil
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
