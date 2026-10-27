-- The FMC's route (6-1/6-2 step 5a; the plan and sources:
-- docs/overhaul/notes/ATA-34-61-FMC.md §18): RTE 1's origin, destination,
-- origin runway and legs, the active route and its modification.
--  - A leg: {via = "DIRECT", an airway or a procedure, fix = a point of the
--    navigation database (B747.68.navdb.lua's records: ident, lat, lon,
--    kind, region, ...)}; {via = airway, pending = true}: an airway entered
--    without its TO waypoint (the RTE page's boxes); {disc = true}: a ROUTE
--    DISCONTINUITY, no path to the next leg (FMSPG p.91).
--  - The route's segments, the RTE pages 2/X... in the ATC format (FCOM
--    p.1296-1298), come from the legs: an airway's or a procedure's
--    consecutive legs, each DIRECT leg, each discontinuity.
--  - RTE 1 is inactive until ACTIVATE and EXEC (FCOM p.1290); on the active
--    route a change makes the modification (MOD), EXEC makes it active and
--    ERASE drops it (FCOM p.1238).
--  - The entries' messages are the CDU's: INVALID ENTRY, NOT IN DATA BASE,
--    ROUTE FULL (120 waypoints: FCOM p.1435).
-- Pure: the glue gives the navigation database module and its database.
--   local R = B747_route_model                     -- in XTLua, after dofile
--   local R = dofile(".../B747.68.route_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_route_model = M

M.MAX_WPTS = 120
M.INVALID_ENTRY, M.NOT_IN_DATA_BASE, M.ROUTE_FULL = "INVALID ENTRY", "NOT IN DATA BASE", "ROUTE FULL"
M.DIRECT = "DIRECT"

local function new_route()
    return {origin = nil, dest = nil, runway = nil, legs = {}, passed = {}}
end

local function copy_route(r)
    local legs = {}
    for i, l in ipairs(r.legs) do
        local c = {}
        for k, v in pairs(l) do c[k] = v end
        legs[i] = c
    end
    local passed = {}
    for i, l in ipairs(r.passed) do passed[i] = l end
    return {origin = r.origin, dest = r.dest, runway = r.runway, legs = legs, passed = passed,
        sid = r.sid, star = r.star, appr = r.appr, offset = r.offset}
end

-- the FMC's routes: `N` the navigation database module, `db` its database
function M.new(N, db)
    return setmetatable({N = N, db = db, rte = new_route(), active = false, mod = nil, activating = false}, {})
end

-- the route the pages show: the modification, else RTE 1
function M.shown(st)
    return st.mod or st.rte
end

-- the route a change goes to: on the active route the modification
-- (made by the first change), else RTE 1 itself. `st.edits` counts the
-- changes (the direct-to's prompts last until the next: step 7e2)
function M.edit(st)
    st.edits = (st.edits or 0) + 1
    if st.active then
        if not st.mod then st.mod = copy_route(st.rte) end
        return st.mod
    end
    return st.rte
end

-- ACTIVATE (an inactive route with an origin and a destination: estimate)
function M.activate(st)
    local r = st.rte
    if st.active or not (r.origin and r.dest) then return M.INVALID_ENTRY end
    st.activating = true
end

-- EXEC: the modification or the activation; false when there is none.
-- `ppos`: the airplane's position ({lat, lon}), where a direct-to's path
-- starts (step 5e)
local start_of_dto, latlon_name
function M.exec(st, ppos)
    if st.mod then
        local l = st.mod.legs[1]
        if l and l.dto_exec then
            l.from, l.dto_exec = ppos and start_of_dto(st, l, ppos) or l.from, nil
        end
        -- a PPOS hold: its fix the position at EXEC, its default inbound
        -- course the track then (FCOM p.1415; the course: estimate)
        for _, h in ipairs(st.mod.legs) do
            if h.ppos and ppos and h.fix.ident == M.PPOS then
                h.fix = {kind = "LL", ident = latlon_name(ppos), lat = ppos.lat, lon = ppos.lon}
                if h.crs_default and ppos.trk then h.crs = math.floor(ppos.trk + 0.5) % 360 end
            end
        end
        -- the legs passed as they are now (the modification's copy may be
        -- older: step 5e)
        st.mod.passed = st.rte.passed
        st.rte, st.mod = st.mod, nil
        return true
    end
    if st.activating then
        st.active, st.activating = true, false
        return true
    end
    return false
end

-- ERASE: the modification or the activation dropped
function M.erase(st)
    st.mod, st.activating = nil, false
end

-- RTE 2 (step 7e4; FCOM p.1287-1294; FMSPG p.134-136): two routes, each a
-- state of its own (`num` 1 or 2); the glue keeps the active one as its
-- B747_fmc_route. EXEC: the active route's modification or activation,
-- else the other route's activation: it is active and the one before
-- inactive (FCOM p.1290), the two states' contents exchanged so that `st`
-- is the active one after. False with nothing to execute
function M.swap(a, b)
    local keys = {}
    for k in pairs(a) do keys[k] = true end
    for k in pairs(b) do keys[k] = true end
    for k in pairs(keys) do a[k], b[k] = b[k], a[k] end
end
function M.exec_both(st, other, ppos)
    if st.mod or st.activating then return M.exec(st, ppos) end
    if other.activating then
        other.activating, other.active, other.mod = false, true, nil
        st.active, st.activating, st.mod = false, false, nil
        M.swap(st, other)
        return true
    end
    return false
end
-- RTE COPY (FCOM p.1289, p.1334; FMSPG p.134-136): the active route as it
-- is (not its modification) into the other, the route there before gone;
-- COMPLETE until the active route changes again (estimate)
function M.copy_active(st, other)
    if not st.active then return M.INVALID_ENTRY end
    local c = copy_route(st.rte)
    c.passed = {}
    other.rte, other.mod, other.active, other.activating = c, nil, false, false
    st.copied = st.edits or 0
end
function M.copy_done(st)
    return st.copied ~= nil and st.copied == (st.edits or 0)
end
-- RTE COPY> on the direct-to modification's LEGS page (FCOM p.1334;
-- FMSPG p.135): until another change
function M.copy_offered(st)
    return st.mod ~= nil and st.dto_offer == st.edits and not M.copy_done(st)
end

-- the EXEC light: a modification or an activation to execute
function M.exec_lit(st)
    return st.mod ~= nil or st.activating
end

-- the title's word: ACT, MOD or none (FCOM p.1331)
function M.status(st)
    if st.mod then return "MOD" end
    if st.active then return "ACT" end
    return ""
end

-- a hold's leg (step 7b): at its fix after the leg to that fix (FCOM
-- p.1413-1419; FMSPG p.157-163, p.221-223): pt "HM" (ended by the crew:
-- the crew's holds and a procedure's), "HA" (at an altitude), "HF" (at
-- the fix: a procedure's); crs its inbound course (magnetic), turn "L" or
-- "R", time (minutes) or dist (nm), radial (the QUAD/RADIAL entered), efc
-- (the EFC TIME, "hhmm"), exit (EXIT HOLD executed), ppos (a PPOS hold:
-- its fix where the airplane is at EXEC), crs_default (the course not
-- entered)
local HOLD_PT = {HM = true, HA = true, HF = true}
function M.is_hold(l)
    return l ~= nil and l.pt ~= nil and HOLD_PT[l.pt] == true
end

-- the number of waypoints in a route's legs (the conditional ones too)
local function count(r)
    local n = 0
    for _, l in ipairs(r.legs) do
        if l.fix or l.name then n = n + 1 end
    end
    return n
end
-- a procedure's legs out of a route (`proc`: "SID", "STAR", "APPR"); the
-- route's waypoint a procedure joined at (`joined`: its leg) back, where
-- a procedure selected again joins again (estimate: the sources leave it
-- out; the RTE pages' segments go on after the procedure's)
local function strip(r, kind)
    local legs = {}
    for _, l in ipairs(r.legs) do
        if l.proc ~= kind then legs[#legs + 1] = l
        elseif l.joined then
            -- a copy: the modification's copied legs share it
            local c = {}
            for k, v in pairs(l.joined) do c[k] = v end
            legs[#legs + 1] = c
        end
    end
    r.legs = legs
end
-- a leg's waypoint as the pages name it: the fix, or a conditional leg's
-- name (FCOM p.1249)
function M.leg_name(l)
    return l.fix and l.fix.ident or l.name or ""
end

-- the fix the legs up to `n` end on (where the next segment starts; an
-- airway crossing waypoint's `node` the airways' point); nil after a
-- discontinuity or a pending airway, or with no leg
local function end_fix(r, n)
    local l = r.legs[n or #r.legs]
    if l and l.fix and not l.disc and not l.pending then return l.fix end
    return nil
end

-- ORIGIN (FCOM p.1288): an airport of the database; on the ground a new
-- origin erases the route (the destination too, as the FMC's ORIGIN line
-- did: estimate)
function M.set_origin(st, icao)
    local apt = st.N.airport(st.db, icao)
    if not apt then return M.NOT_IN_DATA_BASE end
    local r = M.edit(st)
    r.origin, r.dest, r.runway, r.legs, r.passed = apt, nil, nil, {}, {}
    r.sid, r.star, r.appr = nil, nil, nil
end

-- DEST (FCOM p.1289): an airport of the database; a new destination
-- deletes the arrival procedures of the one before (FMSPG p.79), the
-- discontinuity before them with them (estimate)
function M.set_dest(st, icao)
    local apt = st.N.airport(st.db, icao)
    if not apt then return M.NOT_IN_DATA_BASE end
    local r = M.edit(st)
    if r.dest and r.dest.ident ~= apt.ident and (r.star or r.appr) then
        strip(r, "STAR")
        strip(r, "APPR")
        r.star, r.appr = nil, nil
        while r.legs[#r.legs] and r.legs[#r.legs].disc do r.legs[#r.legs] = nil end
    end
    r.dest = apt
end

-- RUNWAY (FCOM p.1289): a runway of the origin in the database ("16R" or
-- "RW16R")
function M.set_runway(st, text)
    local r = M.shown(st)
    if not r.origin then return M.INVALID_ENTRY end
    local id = text:match("^RW(%d%d[LCR]?)$") or text:match("^(%d%d[LCR]?)$")
    if not id then return M.INVALID_ENTRY end
    local c = st.N.cifp(st.db, r.origin.ident)
    local rw = c and c.runways["RW" .. id]
    if not rw then return M.NOT_IN_DATA_BASE end
    M.edit(st).runway = rw
end

-- the route's segments (the RTE pages' VIA and TO lines): {via, to (the
-- TO waypoint's ident; nil: boxes), first, last (the legs), disc}
function M.segments(r)
    local segs, cur = {}, nil
    for i, l in ipairs(r.legs) do
        if l.disc then
            segs[#segs + 1] = {disc = true, first = i, last = i}
            cur = nil
        elseif l.pending then
            segs[#segs + 1] = {via = l.via, first = i, last = i}
            cur = nil
        elseif M.is_hold(l) and cur then
            -- a hold: the segment its fix ends (not a route segment of
            -- its own: step 7b)
            cur.last = i
        elseif l.via == M.DIRECT or not cur or cur.via ~= l.via then
            cur = {via = l.via, to = M.leg_name(l), first = i, last = i}
            segs[#segs + 1] = cur
        else
            cur.to, cur.last = M.leg_name(l), i
        end
    end
    return segs
end

-- the candidates for an identifier (SELECT DESIRED WPT when more than
-- one: FCOM p.1335), nearest first to `lat`, `lon`; the origin's and the
-- destination's terminal waypoints with them, and the waypoints the crew
-- defined in the route by their names (step 7e3a: SEA01, N47W008) but
-- with `db_only` (REF NAV DATA, FIX INFO: the database's)
local PILOT = {LL = true, PBD = true}
function M.candidates(st, ident, lat, lon, db_only)
    local r = M.shown(st)
    local apts = {}
    if r.origin then apts[#apts + 1] = r.origin.ident end
    if r.dest then apts[#apts + 1] = r.dest.ident end
    local list = st.N.find(st.db, ident, lat, lon, apts)
    if db_only then return list end
    for _, l in ipairs(r.legs) do
        local f = l.fix
        if f and PILOT[f.kind] and f.ident == ident then
            local seen = false
            for _, c in ipairs(list) do
                if c.ident == f.ident and math.abs(c.lat - f.lat) < 1e-6 and math.abs(c.lon - f.lon) < 1e-6 then seen = true end
            end
            if not seen then list[#list + 1] = f end
        end
    end
    return list
end

local function full(r, extra)
    return count(r) + extra > M.MAX_WPTS
end

-- a TO waypoint on the line after the route's end (the dashes): a DIRECT
-- leg to it, or the pending airway's TO waypoint (the boxes): the airway's
-- points from the previous TO waypoint to it (FCOM p.1297-1298; FMSPG
-- p.82-83)
function M.add_to(st, fix)
    local r = M.shown(st)
    local last = r.legs[#r.legs]
    if last and last.pending then
        local from = end_fix(r, #r.legs - 1)
        if not from then return M.INVALID_ENTRY end
        local path = st.N.airway_path(st.db, last.via, from.node or from.ident, fix.ident)
        if not path or #path < 2 then return M.INVALID_ENTRY end
        if full(r, #path - 1) then return M.ROUTE_FULL end
        r = M.edit(st)
        local via = last.via
        r.legs[#r.legs] = nil
        for k = 2, #path do
            local p = path[k]
            local pt = (k == #path) and fix or st.N.point(st.db, p.ident, p.region, p.kind) or p
            r.legs[#r.legs + 1] = {via = via, fix = pt}
        end
        return
    end
    if full(r, 1) then return M.ROUTE_FULL end
    r = M.edit(st)
    r.legs[#r.legs + 1] = {via = M.DIRECT, fix = fix}
end

-- the point where two airways meet (each listing the other's point)
local function intersection(st, a, b)
    local sa, sb = st.N.airway(st.db, a), st.N.airway(st.db, b)
    if not (sa and sb) then return nil end
    local on_b = {}
    for _, s in ipairs(sb) do
        on_b[s.from.ident .. " " .. s.from.region] = s.from
        on_b[s.to.ident .. " " .. s.to.region] = s.to
    end
    for _, s in ipairs(sa) do
        for _, p in ipairs({s.from, s.to}) do
            if on_b[p.ident .. " " .. p.region] then return p end
        end
    end
    return nil
end

-- an airway on the VIA line after the route's end (FCOM p.1296-1297): it
-- must contain the previous TO waypoint (the boxes for its TO), or meet
-- the previous airway entered without a TO waypoint: the FMC's airway
-- crossing waypoint, X and the second airway's name (FCOM p.1250: J70 then
-- J52 gives XJ52), at the point the two airways share, as that airway's TO
function M.add_via(st, name)
    local segs = st.N.airway(st.db, name)
    if not segs then return M.NOT_IN_DATA_BASE end
    local r = M.shown(st)
    local last = r.legs[#r.legs]
    if last and last.pending then
        local x = intersection(st, last.via, name)
        if not x then return M.INVALID_ENTRY end
        local p = st.N.point(st.db, x.ident, x.region, x.kind) or x
        local err = M.add_to(st, p)
        if err then return err end
        r = M.edit(st)
        r.legs[#r.legs].fix = {kind = "LL", ident = "X" .. name, lat = p.lat, lon = p.lon, node = p.ident}
        r.legs[#r.legs].intc = true
        r.legs[#r.legs + 1] = {via = name, pending = true}
        return
    end
    local from = end_fix(r)
    if not from then return M.INVALID_ENTRY end
    local id, found = from.node or from.ident, false
    for _, s in ipairs(segs) do
        if s.from.ident == id or s.to.ident == id then found = true break end
    end
    if not found then return M.INVALID_ENTRY end
    local e = M.edit(st)
    e.legs[#e.legs + 1] = {via = name, pending = true}
end

-- the waypoints in flight order (the LEGS pages, the X-Plane FMS):
-- {fix, via, disc}
function M.legs(r)
    return r.legs
end

-- the great circle's course from one point to another at the first (true
-- degrees) and its length (nm)
function M.course(lat1, lon1, lat2, lon2)
    local r = math.pi / 180
    local p1, p2, dl = lat1 * r, lat2 * r, (lon2 - lon1) * r
    local y = math.sin(dl) * math.cos(p2)
    local x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    local a = math.sin((p2 - p1) / 2) ^ 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ^ 2
    return (math.atan2(y, x) / r + 360) % 360, 2 * math.asin(math.min(1, math.sqrt(a))) * 3440.065
end

-- the point a leg starts from: a direct-to's start, where LNAV started it
-- (`start`: step 6b), the waypoint before it, the last passed waypoint,
-- the origin's runway or the origin before the first; nil after a
-- discontinuity
function M.leg_from(r, i)
    local l = r.legs[i]
    if l and l.dto and l.from then return l.from end
    if l and l.start then return l.start end
    local prev = r.legs[i - 1]
    if i == 1 then prev = r.passed[#r.passed] end
    if prev then
        if prev.fix and not prev.disc and not prev.pending then return prev.fix end
        return nil
    end
    return r.runway or r.origin
end

-- the leg from `from` on with this fix (the same identifier and place;
-- not a hold at it)
local function find_leg(r, fix, from)
    for i = from or 1, #r.legs do
        local f = r.legs[i].fix
        if f and not M.is_hold(r.legs[i]) and f.ident == fix.ident and math.abs(f.lat - fix.lat) < 1e-4 and math.abs(f.lon - fix.lon) < 1e-4 then
            return i
        end
    end
    return nil
end

-- the route's leg to this waypoint (not a hold at it); nil when none
function M.find_fix(r, fix)
    return find_leg(r, fix, 1)
end

-- a waypoint entered on the LEGS pages over leg `i` (#legs + 1: the dashes
-- after the end) (6-1/6-2 step 5c; FMSPG p.82, p.91; the rules the sources
-- leave out: estimate): a waypoint later in the route: the legs before it
-- from `i` on go and the route goes DIRECT to it (a discontinuity's boxes
-- closed with the waypoint after it); another: inserted before leg `i`, a
-- ROUTE DISCONTINUITY after it
function M.legs_entry(st, i, fix)
    local r = M.shown(st)
    if i < 1 or i > #r.legs + 1 then return M.INVALID_ENTRY end
    local j = find_leg(r, fix, i)
    if j then
        r = M.edit(st)
        for _ = i, j - 1 do table.remove(r.legs, i) end
        local l = r.legs[i]
        l.via, l.intc, l.dto, l.crs, l.pt, l.start = M.DIRECT, nil, nil, nil, nil, nil
        return
    end
    if full(r, 1) then return M.ROUTE_FULL end
    r = M.edit(st)
    table.insert(r.legs, i, {via = M.DIRECT, fix = fix})
    local nxt = r.legs[i + 1]
    if nxt and not nxt.disc then table.insert(r.legs, i + 1, {disc = true}) end
end

-- DELETE over leg `i` (estimate: the waypoints before and after it joined
-- DIRECT; a discontinuity is closed by entering the waypoint after it, not
-- deleted: INVALID DELETE). The hold being flown (the active route's
-- first leg): LNAV direct to the next waypoint (FCOM p.1416), from where
-- the airplane is at EXEC
M.INVALID_DELETE = "INVALID DELETE"
function M.legs_delete(st, i)
    local l = M.shown(st).legs[i]
    if not l or l.disc or l.pending then return M.INVALID_DELETE end
    local r = M.edit(st)
    table.remove(r.legs, i)
    local nxt = r.legs[i]
    if nxt and nxt.fix then nxt.via, nxt.dto, nxt.crs, nxt.pt, nxt.start = M.DIRECT, nil, nil, nil, nil end
    if nxt and nxt.fix and i == 1 and st.active and M.is_hold(l) then nxt.dto, nxt.dto_exec = true, true end
end

-- DIRECT TO (FMSPG p.141-144): a waypoint entered over the active
-- waypoint, the first leg of the active route: from the airplane's
-- position direct to it, the legs before it gone (one later in the
-- route), or it inserted with a ROUTE DISCONTINUITY after it (another).
-- `route_crs`: the route's course into it (INTC CRS offers it); `ppos`:
-- the airplane's position, the path's start until EXEC sets it
function M.direct_to(st, fix, route_crs, ppos)
    if not st.active then return M.INVALID_ENTRY end
    local err = M.legs_entry(st, 1, fix)
    if err then return err end
    local e = M.edit(st)
    local l = e.legs[1]
    l.dto, l.crs, l.route_crs, l.dto_exec = true, nil, route_crs, true
    l.from = ppos and {lat = ppos.lat, lon = ppos.lon} or nil
    -- the offset cancelled (FCOM p.1299; FMSPG p.156)
    e.offset = nil
    -- ABEAM PTS> (and RTE COPY>) until the next change (FCOM p.1334)
    st.dto_offer = st.edits
end

-- the point `d` nm from `p` on the true course `crs`
local function course_point(p, crs, d)
    local r = math.pi / 180
    local lat1, lon1, t, a = p.lat * r, p.lon * r, crs * r, d / 3440.065
    local lat2 = math.asin(math.sin(lat1) * math.cos(a) + math.cos(lat1) * math.sin(a) * math.cos(t))
    local lon2 = lon1 + math.atan2(math.sin(t) * math.sin(a) * math.cos(lat1), math.cos(a) - math.sin(lat1) * math.sin(lat2))
    return {lat = lat2 / r, lon = (lon2 / r + 540) % 360 - 180}
end

-- where a direct-to's path starts at EXEC (step 5e; the sources leave the
-- moment out: estimate): the airplane's position; with an INTC CRS, the
-- point on the course into the waypoint as far from it as the airplane
-- (estimate: X-Plane's flight plan has the course as a leg, and the AFDS
-- intercepts it)
function start_of_dto(st, l, ppos)
    if not l.crs then return {lat = ppos.lat, lon = ppos.lon} end
    local _, d = M.course(ppos.lat, ppos.lon, l.fix.lat, l.fix.lon)
    local var = st.N.variation and st.N.variation(st.db, l.fix.lat, l.fix.lon) or 0
    return course_point(l.fix, (l.crs + (var or 0) + 180) % 360, math.max(d, 5))
end

-- INTC CRS (FMSPG p.143-144): the course into the direct-to waypoint (a
-- course to intercept, 0-360); the direct-to modification only
function M.intc_crs(st, crs)
    local l = st.mod and st.mod.legs[1]
    if not (l and l.dto) or st.mod.abeam or crs < 0 or crs > 360 then return M.INVALID_ENTRY end
    -- a change: the ABEAM PTS and RTE COPY prompts gone (FCOM p.1334)
    st.edits = (st.edits or 0) + 1
    l.crs = crs % 360
end

-- ABEAM PTS (step 7e2; FCOM p.1333-1334; FMSPG p.136-139): the direct-to
-- modification offers it at 4R until another change (FCOM p.1334);
-- SELECTED after it until another change
function M.abeam_offered(st)
    return st.mod ~= nil and st.dto_offer == st.edits and not st.mod.abeam
end
function M.abeam_selected(st)
    return st.mod ~= nil and st.dto_offer == st.edits and st.mod.abeam == true
end

-- the point abeam `p` on the great circle from `a` to `b`: its distance
-- along it from `a` (negative behind `a`) and across it (nm), the
-- course at `a` and the length to `b`
local function abeam_of(a, b, p)
    local crs, len = M.course(a.lat, a.lon, b.lat, b.lon)
    local crs_p, d_p = M.course(a.lat, a.lon, p.lat, p.lon)
    local dp, dc = d_p / 3440.065, math.rad(crs_p - crs)
    local across = math.asin(math.sin(dp) * math.sin(dc))
    local along = math.acos(math.max(-1, math.min(1, math.cos(dp) / math.cos(across))))
    if math.cos(dc) < 0 then along = -along end
    return along * 3440.065, across * 3440.065, crs, len
end

-- a place/bearing/distance waypoint's number: RTE 1's 01-49, RTE 2's
-- 51-99 (FCOM p.1250), the lowest no waypoint of the route has
-- (estimate); nil when none is left
local function pbd_number(st, more)
    local used = {}
    local function mark(l) if l.fix and l.fix.kind == "PBD" then used[l.fix.seq] = true end end
    for _, r in ipairs({st.rte, st.mod}) do
        for _, l in ipairs(r.legs) do mark(l) end
        for _, l in ipairs(r.passed) do mark(l) end
    end
    for _, f in ipairs(more) do mark({fix = f}) end
    local lo = st.num == 2 and 51 or 1
    for n = lo, lo + 48 do
        if not used[n] then return n end
    end
    return nil
end

-- the waypoints the crew defines (step 7e3a; FCOM p.1245, p.1249-1250):
--  - latitude/longitude: N47W008 (whole degrees) or N4715.4W00803.4 (the
--    minutes to the tenth), each part on its own; named by its whole
--    degrees (N47W008);
--  - place/bearing/distance: SEA330/10, ABC180.0/026.4 (FIX INFO's copy:
--    FCOM p.1359); place bearing/place bearing: SEA240/OLM320. The
--    bearings magnetic (the variation at the place: the nearest VOR's,
--    estimate), 000-360 with a tenth; the distance up to 999.9 nm, more
--    than 0 (estimate). Named by the place's first three characters and a
--    number (SEA01: FCOM p.1250).
local function lat_lon_part(s, hemi, ndeg)
    local h, rest = string.match(s, "^([" .. hemi .. "])(.+)$")
    if not h then return nil end
    local digits = string.rep("%d", ndeg)
    local v = tonumber(string.match(rest, "^(" .. digits .. ")$") or "")
    if not v then
        local d, m = string.match(rest, "^(" .. digits .. ")(%d%d%.%d)$")
        if not d or tonumber(m) >= 60 then return nil end
        v = tonumber(d) + tonumber(m) / 60
    end
    return (h == "S" or h == "W") and -v or v
end
function M.parse_latlon(s)
    local a, b = string.match(s, "^([NS][%d%.]+)([EW][%d%.]+)$")
    if not a then return nil end
    local lat, lon = lat_lon_part(a, "NS", 2), lat_lon_part(b, "EW", 3)
    if not (lat and lon) or math.abs(lat) > 90 or math.abs(lon) > 180 then return nil end
    return {kind = "LL", ident = latlon_name({lat = lat, lon = lon}), lat = lat, lon = lon}
end
-- "SEA330" or "ABC180.0": the place and the bearing
local function place_bearing(s)
    local p, b = string.match(s, "^(%w-)(%d%d%d%.%d)$")
    if not p then p, b = string.match(s, "^(%w-)(%d%d%d)$") end
    b = tonumber(b or "")
    if not p or #p < 1 or #p > 5 or not string.match(p, "^%a") or b > 360 then return nil end
    return p, b % 360
end
-- {place, brg, dist} or {place, brg, place2, brg2} (the identifiers and
-- magnetic bearings), nil for another entry
function M.parse_pbd(s)
    local a, b = string.match(s, "^([%w%.]+)/([%w%.]+)$")
    if not a then return nil end
    local p, brg = place_bearing(a)
    if not p then return nil end
    local d = tonumber(string.match(b, "^%d%d?%d?$") or string.match(b, "^%d?%d?%d?%.%d$") or "")
    if d then
        if d <= 0 then return nil end
        return {place = p, brg = brg, dist = d}
    end
    local p2, brg2 = place_bearing(b)
    if not p2 then return nil end
    return {place = p, brg = brg, place2 = p2, brg2 = brg2}
end
-- the true course of a magnetic bearing at a point
local function true_of(st, mag, p)
    local var = st.N.variation and st.N.variation(st.db, p.lat, p.lon) or nil
    return (mag + (var or 0)) % 360
end
-- where two great circles from `a` on the course `c1` and from `b` on
-- `c2` (true) meet ahead of both (E. Williams' formulary); nil when they
-- do not
local function radials_meet(a, c1, b, c2)
    local r = math.pi / 180
    local la1, lo1, la2, lo2 = a.lat * r, a.lon * r, b.lat * r, b.lon * r
    local _, d = M.course(a.lat, a.lon, b.lat, b.lon)
    local d12 = d / 3440.065
    if d12 < 1e-9 then return nil end
    local c12, c21 = M.course(a.lat, a.lon, b.lat, b.lon), M.course(b.lat, b.lon, a.lat, a.lon)
    local a1 = ((c1 - c12 + 180) % 360 - 180) * r
    local a2 = ((c21 - c2 + 180) % 360 - 180) * r
    if math.sin(a1) == 0 and math.sin(a2) == 0 then return nil end
    if math.sin(a1) * math.sin(a2) < 0 then return nil end
    a1, a2 = math.abs(a1), math.abs(a2)
    local a3 = math.acos(math.max(-1, math.min(1, -math.cos(a1) * math.cos(a2) + math.sin(a1) * math.sin(a2) * math.cos(d12))))
    local d13 = math.atan2(math.sin(d12) * math.sin(a1) * math.sin(a2), math.cos(a2) + math.cos(a1) * math.cos(a3))
    if d13 <= 0 then return nil end
    return course_point(a, c1, d13 * 3440.065)
end
-- a place/bearing/distance or place bearing/place bearing waypoint from
-- `e` (M.parse_pbd's) with its places' records; nil when the radials do
-- not meet or no number is left
function M.pbd_fix(st, e, place, place2)
    local p
    if e.dist then
        p = course_point(place, true_of(st, e.brg, place), e.dist)
    else
        p = radials_meet(place, true_of(st, e.brg, place), place2, true_of(st, e.brg2, place2))
    end
    if not p then return nil end
    local n = pbd_number(st, {})
    if not n then return nil end
    local brg, dist = M.course(place.lat, place.lon, p.lat, p.lon)
    return {kind = "PBD", ident = string.format("%s%02d", string.sub(place.ident, 1, 3), n), seq = n,
        place = place, brg = brg, dist = dist, lat = p.lat, lon = p.lon}
end

-- FIX INFO (step 7e3b; FCOM p.1358-1359; FMSPG p.166-169): the active
-- route's path, its points from where the active leg starts through the
-- waypoints to the first discontinuity (conditional legs and holds left
-- out: estimate), and the airplane's distance along it; nil without an
-- active route of two points
function M.fix_path(st, ppos)
    if not st.active then return nil end
    local r = st.rte
    local pts = {}
    local start = M.leg_from(r, 1)
    if start then pts[1] = {lat = start.lat, lon = start.lon} end
    for _, l in ipairs(r.legs) do
        if l.disc or l.pending then break end
        if l.fix and not M.is_hold(l) then pts[#pts + 1] = {lat = l.fix.lat, lon = l.fix.lon} end
    end
    if #pts < 2 then return nil end
    local segs, d = {}, 0
    for k = 1, #pts - 1 do
        local a, b = pts[k], pts[k + 1]
        local crs, len = M.course(a.lat, a.lon, b.lat, b.lon)
        segs[k] = {a = a, b = b, crs = crs, len = len, d0 = d}
        d = d + len
    end
    return {segs = segs, at = (abeam_of(pts[1], pts[2], ppos))}
end
-- a point on the path: its position and its distance to go from the
-- airplane (negative behind it: FMSPG p.168)
local function path_point(path, s, along)
    local x = course_point(s.a, s.crs, along)
    return {lat = x.lat, lon = x.lon, dtg = s.d0 + along - path.at}
end
local function closer(best, p)
    if not best or math.abs(p.dtg) < math.abs(best.dtg) then return p end
    return best
end
-- where the radial from `f` on the true course `crs` crosses the path
-- within `maxd` nm of it (512: FMSPG p.167); the one nearest the airplane
-- along the path (estimate)
function M.fix_radial(path, f, crs, maxd)
    local best
    for _, s in ipairs(path.segs) do
        local x = radials_meet(f, crs, s.a, s.crs)
        if x then
            local _, along = M.course(s.a.lat, s.a.lon, x.lat, x.lon)
            local _, df = M.course(f.lat, f.lon, x.lat, x.lon)
            if along <= s.len + 1e-6 and df <= maxd then best = closer(best, path_point(path, s, along)) end
        end
    end
    return best
end
-- where the circle of `r` nm round `f` crosses the path: the crossing
-- nearest the airplane (FCOM p.1358: the closest of the two)
function M.fix_circle(path, f, r)
    local best
    for _, s in ipairs(path.segs) do
        local along, across = abeam_of(s.a, s.b, f)
        local cx = math.cos(across / 3440.065)
        if math.abs(across) <= r and cx > 0 then
            local h = math.acos(math.max(-1, math.min(1, math.cos(r / 3440.065) / cx))) * 3440.065
            for _, d in ipairs({along - h, along + h}) do
                if d >= 0 and d <= s.len then best = closer(best, path_point(path, s, d)) end
            end
        end
    end
    return best
end
-- the point of the path abeam `f`, square to its nearest segment (FCOM
-- p.1359; FMSPG p.168); nil when no segment has one
function M.fix_abeam(path, f)
    local best, best_x
    for _, s in ipairs(path.segs) do
        local along, across = abeam_of(s.a, s.b, f)
        if along >= 0 and along <= s.len and (not best_x or math.abs(across) < best_x) then
            best, best_x = path_point(path, s, along), math.abs(across)
        end
    end
    return best
end

-- ABEAM PTS pushed (FMSPG p.136-137): the waypoints the direct-to passes
-- by (the active route's from the active waypoint to the one before the
-- direct-to waypoint) put on the direct path abeam where they are, in
-- order along it, within 700 nm across. Not the procedures' but a
-- departure's last fix and the fix before an arrival; not a runway, a
-- hold or a conditional leg (estimate). A database point's abeam point a
-- place/bearing/distance waypoint from it ("FOO01"), a lat/lon waypoint's
-- another lat/lon waypoint, a place/bearing/distance waypoint's another
-- from its place; no constraints. The first leg the direct-to's then; no
-- INTC CRS after it (FMSPG p.139's figure). Points abeam behind the
-- airplane or past the direct-to waypoint left out (estimate). `ppos`:
-- the airplane's position, the direct path's start
M.ABEAM_LIMIT = 700
function M.abeam_points(st, ppos)
    if not M.abeam_offered(st) then return M.INVALID_ENTRY end
    local rte, dto = st.rte, st.mod.legs[1]
    local j = find_leg(rte, dto.fix, 1)
    local last_dep, first_arr
    for i, l in ipairs(rte.legs) do
        if l.proc == "SID" then last_dep = i end
        if (l.proc == "STAR" or l.proc == "APPR") and not first_arr then first_arr = i end
    end
    local pts = {}
    for i = 1, (j or 1) - 1 do
        local l = rte.legs[i]
        local f = l.fix
        if f and not l.disc and not M.is_hold(l) and f.kind ~= "RWY"
            and (not l.proc or i == last_dep or (first_arr and i == first_arr - 1)) then
            local along, across, crs, len = abeam_of(ppos, dto.fix, f)
            if along > 0 and along < len and math.abs(across) <= M.ABEAM_LIMIT then
                pts[#pts + 1] = {along = along, fix = f, at = course_point(ppos, crs, along)}
            end
        end
    end
    table.sort(pts, function(a, b) return a.along < b.along end)
    local made = {}
    for _, a in ipairs(pts) do
        local f, p = a.fix, a.at
        if f.kind == "LL" then
            made[#made + 1] = {kind = "LL", ident = latlon_name(p), lat = p.lat, lon = p.lon}
        else
            local place = f.kind == "PBD" and f.place or f
            local n = pbd_number(st, made)
            if not n then break end
            local brg, dist = M.course(place.lat, place.lon, p.lat, p.lon)
            made[#made + 1] = {kind = "PBD", ident = string.format("%s%02d", string.sub(place.ident, 1, 3), n),
                seq = n, place = place, brg = brg, dist = dist, lat = p.lat, lon = p.lon}
        end
    end
    if full(M.shown(st), #made) then return M.ROUTE_FULL end
    local r = M.edit(st)
    local old = r.legs[1]
    for k = #made, 1, -1 do table.insert(r.legs, 1, {via = M.DIRECT, fix = made[k]}) end
    if #made > 0 then
        local l = r.legs[1]
        l.dto, l.dto_exec, l.from = true, old.dto_exec, old.from
        old.dto, old.dto_exec, old.from, old.crs, old.route_crs = nil, nil, nil, nil, nil
    end
    r.abeam = true
    st.dto_offer = st.edits
end

-- a waypoint's speed and altitude constraint (FCOM p.1332; FMSPG
-- p.125-128): `c` = {spd (CAS, 100-400 kt), alt, alt2 (feet), akind ("":
-- at, "A": at or above, "B": at or below, "AB": the block alt..alt2)};
-- below the cruise altitude; a speed alone over an altitude constraint;
-- a new constraint drops the old speed. Not on a leg ending at an altitude
-- (`altterm`, the procedures' legs: step 5d)
function M.set_constraint(st, i, c, crz_alt)
    local l = M.shown(st).legs[i]
    if not l or l.disc or l.pending or l.altterm then return M.INVALID_ENTRY end
    if c.spd and (c.spd < 100 or c.spd > 400) then return M.INVALID_ENTRY end
    if not c.alt then
        if not (c.spd and l.alt) then return M.INVALID_ENTRY end
    else
        local top = math.max(c.alt, c.alt2 or c.alt)
        if crz_alt and top >= crz_alt then return M.INVALID_ENTRY end
    end
    l = M.edit(st).legs[i]
    l.spd = c.spd
    if c.alt then l.alt, l.alt2, l.akind = c.alt, c.alt2, c.akind or "" end
end

-- DELETE over a constraint: the speed and the altitude both go (FMSPG
-- p.128); INVALID DELETE where there is none
function M.delete_constraint(st, i)
    local l = M.shown(st).legs[i]
    if not (l and (l.alt or l.spd)) or l.altterm then return M.INVALID_DELETE end
    l = M.edit(st).legs[i]
    l.spd, l.alt, l.alt2, l.akind = nil, nil, nil, nil
end

-- a constraint as the LEGS pages show it: "250/10000A", "/FL240",
-- "220A240B" (the speed's slash also alone: FCOM p.1332)
function M.constraint_text(l, trans_alt)
    if not l.alt and not l.spd then return nil end
    local function ft(a) return a > (trans_alt or 18000) and string.format("FL%03d", math.floor(a / 100 + 0.5)) or tostring(a) end
    local alt = ""
    if l.alt then
        if l.akind == "AB" then
            alt = ft(l.alt) .. "A" .. ft(l.alt2) .. "B"
        else
            alt = ft(l.alt) .. (l.akind or "")
        end
    end
    return (l.spd and tostring(l.spd) or "") .. "/" .. alt
end

-- the holds (6-1/6-2 step 7b; notes/ATA-34-61-FMC.md §33)

-- the holds' legs in flight order
function M.holds(r)
    local out = {}
    for i, l in ipairs(r.legs) do
        if M.is_hold(l) then out[#out + 1] = i end
    end
    return out
end

-- a lat/lon fix's name by its whole degrees ("N47W120": FCOM p.1415)
function latlon_name(p)
    return string.format("%s%02d%s%03d", p.lat >= 0 and "N" or "S", math.floor(math.abs(p.lat)),
        p.lon >= 0 and "E" or "W", math.floor(math.abs(p.lon)))
end
M.PPOS = "PPOS"

-- the inbound course into `fix` from `from` (the great circle's at the
-- fix), magnetic (the nearest VOR's variation; true without one)
local function inbound_course(st, from, fix)
    if not from then return 0 end
    local back = M.course(fix.lat, fix.lon, from.lat, from.lon)
    local var = st.N.variation and st.N.variation(st.db, fix.lat, fix.lon) or 0
    return math.floor((back + 180 - (var or 0)) % 360 + 0.5) % 360
end
-- a hold's default leg time (FMSPG p.222-223; FCOM p.1417-1418): 1.5
-- minutes above 14,000 ft, else 1.0, by the hold's altitude constraint
-- (a block's upper), else the leg before it's, else the cruise altitude
-- (estimate: the flight phase is VNAV's, step 9), else 1.0
local function time_default(r, i, crz_alt)
    local function top(l) return l and l.alt and math.max(l.alt, l.alt2 or l.alt) end
    local alt = top(r.legs[i]) or top(r.legs[i - 1]) or crz_alt
    return (alt and alt > 14000) and 1.5 or 1.0
end
-- a new hold at `fix` as leg i: the default inbound course (into the fix
-- from `from`) and right turns (FMSPG p.160), the default leg time
local function new_hold(st, r, i, fix, crz_alt, from)
    local h = {via = M.DIRECT, pt = "HM", fix = fix, crs = inbound_course(st, from, fix), turn = "R", crs_default = true}
    table.insert(r.legs, i, h)
    h.time = time_default(r, i, crz_alt)
    return h
end

-- HOLD AT a waypoint of the route, leg j (FMSPG p.158: the hold after the
-- leg to it, the legs between staying). Returns the hold's leg, or nil
-- and the error
function M.hold_at(st, j, crz_alt)
    local r = M.shown(st)
    local l = r.legs[j]
    if not (l and l.fix) or l.disc or l.pending or M.is_hold(l) or M.is_hold(r.legs[j + 1]) then
        return nil, M.INVALID_ENTRY
    end
    if full(r, 1) then return nil, M.ROUTE_FULL end
    r = M.edit(st)
    new_hold(st, r, j + 1, r.legs[j].fix, crz_alt, M.leg_from(r, j))
    return j + 1
end

-- HOLD AT a waypoint not in the route on line i of the LEGS pages (FCOM
-- p.1414; not the active waypoint): the waypoint and its hold before leg
-- i, a ROUTE DISCONTINUITY after them (as a waypoint inserted: FMSPG p.91;
-- estimate). `ppos` the airplane's position: the course into it when no
-- leg comes before
function M.hold_insert(st, i, fix, crz_alt, ppos)
    local r = M.shown(st)
    if i < 1 or i > #r.legs + 1 or (st.active and i == 1) then return nil, M.INVALID_ENTRY end
    if full(r, 2) then return nil, M.ROUTE_FULL end
    r = M.edit(st)
    table.insert(r.legs, i, {via = M.DIRECT, fix = fix})
    new_hold(st, r, i + 1, fix, crz_alt, M.leg_from(r, i) or ppos)
    local nxt = r.legs[i + 2]
    if nxt and not nxt.disc then table.insert(r.legs, i + 2, {disc = true}) end
    return i + 1
end

-- HOLD AT PPOS (FCOM p.1415; FMSPG p.158): on the active route a hold
-- where the airplane is, its fix set at EXEC, before the active leg (the
-- route on after it from its fix: estimate); `ppos` = {lat, lon, trk (the
-- track, magnetic: the default inbound course, estimate)}
function M.hold_ppos(st, ppos, crz_alt)
    if not st.active then return nil, M.INVALID_ENTRY end
    local r = M.shown(st)
    if full(r, 1) then return nil, M.ROUTE_FULL end
    r = M.edit(st)
    local nxt = r.legs[1]
    if nxt then
        nxt.dto, nxt.from, nxt.dto_exec, nxt.start = nil, nil, nil, nil
        if not nxt.pt then nxt.crs = nil end
    end
    local h = new_hold(st, r, 1, {kind = "LL", ident = M.PPOS, lat = ppos.lat, lon = ppos.lon}, crz_alt)
    h.crs, h.ppos = math.floor((ppos.trk or 0) + 0.5) % 360, true
    -- the offset deleted (FMSPG p.158)
    r.offset = nil
    return 1
end

-- the RTE HOLD page's entries on hold leg i (FCOM p.1417-1418; FMSPG
-- p.159-160): `f` = {crs (the inbound course, 0-360), turn ("L", "R"),
-- radial (the QUAD/RADIAL: the inbound course its reciprocal), time
-- (minutes: no distance), dist (nm: no time)}
function M.hold_set(st, i, f)
    if not M.is_hold(M.shown(st).legs[i]) then return M.INVALID_ENTRY end
    local l = M.edit(st).legs[i]
    if f.crs then l.crs, l.radial, l.crs_default = f.crs % 360, nil, nil end
    if f.radial then l.radial, l.crs, l.crs_default = f.radial % 360, (f.radial + 180) % 360, nil end
    if f.turn then l.turn = f.turn end
    if f.time then l.time, l.dist = f.time, nil end
    if f.dist then l.dist, l.time = f.dist, nil end
end
-- EFC TIME ("hhmm", nil: none): the route shown, no modification (it
-- moves the predictions only: estimate)
function M.hold_efc(st, i, efc)
    local l = M.shown(st).legs[i]
    if not M.is_hold(l) then return M.INVALID_ENTRY end
    l.efc = efc
end
-- EXIT HOLD (FCOM p.1419; FMSPG p.162): the hold flown (the active route's
-- first leg), the exit armed by EXEC
function M.hold_exit(st, i)
    local l = M.shown(st).legs[i]
    if not (st.active and i == 1 and M.is_hold(l)) or l.exit then return M.INVALID_ENTRY end
    M.edit(st).legs[i].exit = true
end

-- the lateral offset (step 7d; notes/ATA-34-61-FMC.md §35; FCOM
-- p.1298-1299; FMSPG p.155-156): `r.offset`, nm, right positive, from the
-- active leg through the legs it reaches.

-- a leg the offset goes along: one straight to its fix (the FMC's own
-- DIRECT and airway legs, a direct-to's, TF: estimate), not a hold, a
-- SID's, a STAR's or an approach's (their transitions too: FCOM p.1298)
local function offset_leg(l)
    return l ~= nil and l.fix ~= nil and not (l.disc or l.pending or M.is_hold(l))
        and (l.pt == nil or l.pt == "TF") and l.proc ~= "SID" and l.proc ~= "STAR" and l.proc ~= "APPR"
end
-- how many legs from the first the offset reaches: up to the end of the
-- route, a discontinuity, a STAR's or an approach's (or their
-- transitions') first leg, a DME arc, a heading leg, a hold, a course
-- change of 135 degrees or more (FMSPG p.155; FCOM p.1299)
function M.offset_legs(r)
    local n = 0
    for i, l in ipairs(r.legs) do
        if not offset_leg(l) then break end
        n = i
        local nxt, from = r.legs[i + 1], M.leg_from(r, i)
        if offset_leg(nxt) and from then
            local back = M.course(l.fix.lat, l.fix.lon, from.lat, from.lon)
            local out = M.course(l.fix.lat, l.fix.lon, nxt.fix.lat, nxt.fix.lon)
            if math.abs((out - back) % 360 - 180) >= 135 then break end
        end
    end
    return n
end
-- OFFSET possible (FCOM p.1298; FMSPG p.155): the active route in the
-- air, its active leg one the offset goes along (not on a SID, a STAR or
-- an approach or their transitions)
function M.offset_allowed(st, airborne)
    return st.active and airborne and offset_leg(M.shown(st).legs[1]) or false
end
-- OFFSET L or R 1-99 nm (signed), 0 cancels it; in the modification until
-- EXEC (FCOM p.1298; FMSPG p.156)
function M.set_offset(st, d, airborne)
    if not M.offset_allowed(st, airborne) or math.abs(d) > 99 then return M.INVALID_ENTRY end
    if d == 0 and not M.shown(st).offset then return M.INVALID_DELETE end
    M.edit(st).offset = (d ~= 0) and d or nil
end

-- CRS REVERSAL AT FA FIX (step 7c; FCOM p.1435): the route comes to its
-- final approach fix against the final approach course (the course from
-- the waypoint before it more than 90 degrees off the course on from it:
-- estimate) without a procedure turn or a hold at the fix before it
function M.crs_reversal(st, r)
    for i, l in ipairs(r.legs) do
        if l.faf and l.fix and not M.is_hold(l) then
            local from, nxt = M.leg_from(r, i), r.legs[i + 1]
            if not (from and nxt) then return false end
            local back, d = M.course(l.fix.lat, l.fix.lon, from.lat, from.lon)
            if d < 0.1 then return false end
            local out = nil
            if nxt.fix then
                out = M.course(l.fix.lat, l.fix.lon, nxt.fix.lat, nxt.fix.lon)
            elseif nxt.crs then
                local var = st.N.variation and st.N.variation(st.db, l.fix.lat, l.fix.lon) or 0
                out = (nxt.crs + (var or 0)) % 360
            end
            if not out then return false end
            if math.abs((out - (back + 180) + 180) % 360 - 180) <= 90 then return false end
            for j = 1, i - 1 do
                local k = r.legs[j]
                if (k.pt == "PI" or M.is_hold(k)) and k.fix and k.fix.ident == l.fix.ident then return false end
            end
            return true
        end
    end
    return false
end

-- the terminal procedures (6-1/6-2 step 5d; B747.68.proc_model.lua makes
-- their legs, the glue gives it as `st.P`). A procedure's legs carry `proc`
-- ("SID", "STAR", "APPR"); the route keeps the selections (`sid`, `star`,
-- `appr`: their names, runways and transitions) for the DEP/ARR pages.
local function count_new(legs)
    local n = 0
    for _, l in ipairs(legs) do if l.fix or l.name then n = n + 1 end end
    return n
end
local function procs_of(legs, kind)
    for _, l in ipairs(legs) do l.proc = kind end
    return legs
end

-- DEPARTURES (FCOM p.1301-1302): the SID `name` (nil: none) with the
-- runway `rwy` and the enroute transition `trans`, before the route's
-- legs: the route goes on from the SID's last fix when it has it (its legs
-- up to there go), else after a ROUTE DISCONTINUITY. A runway alone sets
-- the origin's runway; a new runway the SID does not serve deletes it
function M.set_departure(st, name, rwy, trans)
    local r = M.shown(st)
    if not r.origin then return M.INVALID_ENTRY end
    local c = st.N.cifp(st.db, r.origin.ident)
    local runway = rwy and c and c.runways[rwy]
    if rwy and not runway then return M.NOT_IN_DATA_BASE end
    local new = {}
    if name then
        new = st.P.sid_legs(st.N, st.db, r.origin.ident, name, rwy, trans)
        if not new then return M.NOT_IN_DATA_BASE end
    end
    local old = 0
    for _, l in ipairs(r.legs) do if l.proc == "SID" and (l.fix or l.name) then old = old + 1 end end
    if count(r) - old + count_new(new) > M.MAX_WPTS then return M.ROUTE_FULL end
    r = M.edit(st)
    strip(r, "SID")
    if r.legs[1] and r.legs[1].disc then table.remove(r.legs, 1) end
    procs_of(new, "SID")
    local last = new[#new]
    if #new > 0 and #r.legs > 0 then
        local j = last.fix and find_leg(r, last.fix, 1)
        if j then
            -- the route's leg the SID ends on, back when the SID goes
            last.joined = r.legs[j]
            for _ = 1, j do table.remove(r.legs, 1) end
        else
            table.insert(r.legs, 1, {disc = true})
        end
    end
    for k = #new, 1, -1 do table.insert(r.legs, 1, new[k]) end
    if runway then r.runway = runway end
    r.sid = name and {name = name, rwy = rwy, trans = trans} or nil
end

-- the arrival's legs at the end of the route: the STAR, then the approach
-- (a ROUTE DISCONTINUITY between them when they do not meet)
local function arrival_legs(st, r)
    local out = {}
    local dest = r.dest.ident
    if r.star then
        for _, l in ipairs(procs_of(st.P.star_legs(st.N, st.db, dest, r.star.name, r.star.trans, r.appr and r.appr.rwy) or {}, "STAR")) do
            out[#out + 1] = l
        end
    end
    if r.appr then
        local legs = procs_of(st.P.approach_legs(st.N, st.db, dest, r.appr.id, r.appr.trans) or {}, "APPR")
        local last = out[#out]
        local first = legs[1]
        if last and first and last.fix and first.fix and last.fix.ident == first.fix.ident then
            table.remove(legs, 1)
        elseif last and first then
            out[#out + 1] = {disc = true, proc = "STAR"}
        end
        for _, l in ipairs(legs) do out[#out + 1] = l end
    end
    return out
end

-- ARRIVALS (FCOM p.1401-1405): the STAR (`star` = {name, trans}) and the
-- approach (`appr` = {id, trans}) (false: out; nil: as it is), after the
-- route's legs: from the arrival's first fix when the route has it (its
-- legs from there go), else after a ROUTE DISCONTINUITY
function M.set_arrival(st, star, appr)
    local r = M.shown(st)
    if not r.dest then return M.INVALID_ENTRY end
    local sel = {star = r.star, appr = r.appr}
    if star ~= nil then sel.star = star or nil end
    if appr ~= nil then
        sel.appr = appr or nil
        if appr then
            local _, rwy = st.P.approach_legs(st.N, st.db, r.dest.ident, appr.id, appr.trans)
            sel.appr.rwy = rwy
        end
    end
    local new = arrival_legs(st, {dest = r.dest, star = sel.star, appr = sel.appr})
    local old = 0
    for _, l in ipairs(r.legs) do if (l.proc == "STAR" or l.proc == "APPR") and (l.fix or l.name) then old = old + 1 end end
    if count(r) - old + count_new(new) > M.MAX_WPTS then return M.ROUTE_FULL end
    r = M.edit(st)
    strip(r, "STAR")
    strip(r, "APPR")
    while r.legs[#r.legs] and r.legs[#r.legs].disc do r.legs[#r.legs] = nil end
    local first = new[1]
    if first and #r.legs > 0 then
        local j = first.fix and find_leg(r, first.fix, 1)
        if j then
            -- the route's leg the arrival starts on, back when it goes
            first.joined = r.legs[j]
            for _ = j, #r.legs do r.legs[#r.legs] = nil end
        else
            r.legs[#r.legs + 1] = {disc = true}
        end
    end
    for _, l in ipairs(new) do r.legs[#r.legs + 1] = l end
    r.star, r.appr = sel.star, sel.appr
end

-- the route as X-Plane's flight plan file (version 1100), for
-- xtlua/loadtoFMS: X-Plane's FMS draws the ND's line and the readers not
-- rebuilt yet (the AFDS's LNAV and VNAV) fly it. The origin and the
-- destination as airports (1), each waypoint as a fix (11) by its position
-- (an NDB 2, a VOR or DME 3, the FMC's own points a position 28) with its
-- altitude constraint, DRCT or its airway; the runways as positions by
-- their names with the
-- thresholds' elevations, the departure runway after the origin (as
-- X-Plane's DEP ARR puts them: the ND finds them there); no procedure
-- headers (the FMC's own legs: X-Plane would expand its own, and the
-- procedures' legs go DRCT); discontinuities, pending airways, the
-- conditional legs (no fix) and the missed approach left out. The passed
-- legs before the route's (step 5e: the active leg starts at the last of
-- them); a direct-to's start as a position DTOPOS before its waypoint (no
-- fix's name; not X-Plane's own direct-to's PPOS: after a PPOS the AFDS
-- follows X-Plane's current waypoint, which only xtlua/currentFMSID sets,
-- while the AFDS's best track takes this leg as any other). Also the rows'
-- map: `leg[row]` the route's leg, `row[leg]` its row, `ident[row]`, `n`
-- the rows.
-- The legs' shape (step 6d; `shape`: the path model's `shape`, shape[i] =
-- {at = conditional leg i's end as predicted, pts = arc leg i's points}):
-- a conditional leg's end as a position by its name ((600), NRE001,
-- (INTC), VECTORS: FCOM p.1249) where the path model predicts it (a
-- passed one where it ended: `end_at`), an RF or DME arc's points as
-- positions "~" before its fix (no symbol on the ND). X-Plane's map draws
-- the ND's line straight from row to row, through each: the fly-by turns
-- not as curves, a VECTORS leg's end joined to the next waypoint. At most
-- MAX_XP_ROWS rows (X-Plane's FMS: 100, XPLMNavigation.h): the arcs'
-- points left out first, then the passed legs but the last
M.DTO_START = "DTOPOS"
M.ARC_POINT = "~"
M.MAX_XP_ROWS = 100
local FMS_TYPE = {VOR = 3, DME = 3, NDB = 2, LL = 28, RWY = 28, PBD = 28}
local function fms_rows(r, shape, arcs, first_passed)
    local rows, map = {}, {leg = {}, row = {}, ident = {}}
    local function row(t, ident, via, alt, lat, lon)
        rows[#rows + 1] = string.format("%d %s %s %.6f %.6f %.6f", t, ident, via, alt or 0, lat, lon)
        map.ident[#rows] = ident
    end
    local function leg_rows(l, i)
        if l.dto and l.from then row(28, M.DTO_START, "DRCT", 0, l.from.lat, l.from.lon) end
        local sh = i and shape and shape[i]
        local hold = M.is_hold(l)
        if l.fix and not l.missed then
            if arcs and sh and sh.pts and not hold then
                for _, p in ipairs(sh.pts) do row(28, M.ARC_POINT, "DRCT", 0, p.lat, p.lon) end
            end
            local via = (l.via == M.DIRECT or l.proc) and "DRCT" or l.via
            if l.fix.kind == "APT" then
                row(1, l.fix.ident, via, l.fix.elev, l.fix.lat, l.fix.lon)
            else
                -- its altitude constraint, entered or the procedure's (the
                -- ND's DATA shows it: FCOM p.1148; the AFDS's VNAV reads
                -- it; a block's first altitude: estimate); a runway its
                -- threshold's elevation
                local alt = l.fix.kind == "RWY" and l.fix.elev or l.alt or 0
                row(FMS_TYPE[l.fix.kind] or 11, l.fix.ident, via, alt, l.fix.lat, l.fix.lon)
            end
            if i then map.leg[#rows], map.row[i] = i, #rows end
            -- a hold's racetrack after its fix, round to the fix again
            -- (the line drawn while it is the active waypoint: step 7b)
            if hold and arcs and sh and sh.pts then
                for _, p in ipairs(sh.pts) do row(28, M.ARC_POINT, "DRCT", 0, p.lat, p.lon) end
                row(28, M.ARC_POINT, "DRCT", 0, l.fix.lat, l.fix.lon)
            end
        elseif not l.fix and not l.missed and l.name and l.name ~= "" then
            -- a conditional leg's end (no altitude: not a constraint for
            -- the AFDS's VNAV)
            local at = (sh and sh.at) or (not i and l.end_at)
            if at then
                row(28, l.name, "DRCT", 0, at.lat, at.lon)
                if i then map.leg[#rows], map.row[i] = i, #rows end
            end
        end
    end
    if r.origin then row(1, r.origin.ident, "ADEP", r.origin.elev, r.origin.lat, r.origin.lon) end
    if r.runway then row(28, r.runway.ident, "DRCT", r.runway.elev, r.runway.lat, r.runway.lon) end
    for k = first_passed, #r.passed do leg_rows(r.passed[k], nil) end
    for i, l in ipairs(r.legs) do leg_rows(l, i) end
    if r.dest then row(1, r.dest.ident, "ADES", r.dest.elev, r.dest.lat, r.dest.lon) end
    map.n = #rows
    return rows, map
end
function M.to_fms(r, cycle, shape)
    local rows, map = fms_rows(r, shape, true, 1)
    if map.n > M.MAX_XP_ROWS then rows, map = fms_rows(r, shape, false, 1) end
    if map.n > M.MAX_XP_ROWS then rows, map = fms_rows(r, shape, false, math.max(1, #r.passed)) end
    local head = {"I", "1100 Version", "CYCLE " .. (cycle or "0000")}
    if r.origin then head[#head + 1] = "ADEP " .. r.origin.ident end
    if r.runway then head[#head + 1] = "DEPRWY " .. r.runway.ident end
    if r.dest then head[#head + 1] = "ADES " .. r.dest.ident end
    if r.appr and r.appr.rwy then head[#head + 1] = "DESRWY " .. r.appr.rwy end
    head[#head + 1] = "NUMENR " .. #rows
    return table.concat(head, "\n") .. "\n" .. table.concat(rows, "\n") .. "\n", map
end

-- the active waypoint and X-Plane's flight plan (6-1/6-2 step 5e). Until
-- LNAV sequences the route itself (step 6), the AFDS's current waypoint in
-- X-Plane's flight plan (its best track, laminar/B747/autopilot/ap_monitor/
-- fmscurrentIndex) is the active waypoint: the legs before it passed
-- (FMSPG p.119: they leave the LEGS pages; FCOM p.1331: the active leg is
-- the first line). The passed legs stay in the flight plan before the
-- active waypoint, so it does not change when the route sequences.

-- the same leg: the same fix, the same conditional leg, discontinuities
local function same_leg(a, b)
    if not (a and b) then return false end
    if a.disc or b.disc then return a.disc == b.disc end
    if M.is_hold(a) ~= M.is_hold(b) then return false end
    if a.fix and b.fix then
        return a.fix.ident == b.fix.ident and math.abs(a.fix.lat - b.fix.lat) < 1e-4
            and math.abs(a.fix.lon - b.fix.lon) < 1e-4
    end
    return not (a.fix or b.fix) and a.name == b.name
end

-- the active route's first `n` legs passed (the active leg stays); the
-- modification's too when it starts with them. `start`: where the new
-- active leg starts (LNAV, step 6b: the airplane's position after a leg
-- ending at a condition, else nil: the passed leg's fix). True when it
-- sequenced
function M.sequence(st, n, start)
    local r, m = st.rte, st.mod
    if not st.active then return false end
    n = math.min(n, #r.legs - 1)
    if n < 1 then return false end
    -- the offset's last leg passed: the offset over (step 7d; estimate)
    if r.offset and M.offset_legs(r) <= n then r.offset = nil end
    if m and m.offset and M.offset_legs(m) <= n then m.offset = nil end
    for k = 1, n do
        if m and not same_leg(r.legs[k], m.legs[k]) then m = nil end
    end
    for _ = 1, n do
        r.passed[#r.passed + 1] = table.remove(r.legs, 1)
        if m then m.passed[#m.passed + 1] = table.remove(m.legs, 1) end
    end
    if start then
        -- where the conditional leg ended and the next one starts (its
        -- row in X-Plane's flight plan there: step 6d)
        local at = {lat = start.lat, lon = start.lon}
        r.passed[#r.passed].end_at, r.legs[1].start = at, at
        if m and m.legs[1] then m.passed[#m.passed].end_at, m.legs[1].start = at, at end
    end
    return true
end

-- the row of the active waypoint (the first leg with one) in the flight
-- plan to_fms made with `map`; nil without one
function M.active_row(r, map)
    for i = 1, #r.legs do
        if map.row[i] then return map.row[i] end
    end
    return nil
end

return M
