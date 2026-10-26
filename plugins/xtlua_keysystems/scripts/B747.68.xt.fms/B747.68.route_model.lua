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
    return {origin = nil, dest = nil, runway = nil, legs = {}}
end

local function copy_route(r)
    local legs = {}
    for i, l in ipairs(r.legs) do
        local c = {}
        for k, v in pairs(l) do c[k] = v end
        legs[i] = c
    end
    return {origin = r.origin, dest = r.dest, runway = r.runway, legs = legs}
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
-- (made by the first change), else RTE 1 itself
function M.edit(st)
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

-- EXEC: the modification or the activation; false when there is none
function M.exec(st)
    if st.mod then
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

-- the number of waypoints in a route's legs
local function count(r)
    local n = 0
    for _, l in ipairs(r.legs) do
        if l.fix then n = n + 1 end
    end
    return n
end

-- the fix the legs up to `n` end on (where the next segment starts); nil
-- after a discontinuity or a pending airway, or with no leg
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
    r.origin, r.dest, r.runway, r.legs = apt, nil, nil, {}
end

-- DEST (FCOM p.1289): an airport of the database
function M.set_dest(st, icao)
    local apt = st.N.airport(st.db, icao)
    if not apt then return M.NOT_IN_DATA_BASE end
    M.edit(st).dest = apt
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
        elseif l.via == M.DIRECT or not cur or cur.via ~= l.via then
            cur = {via = l.via, to = l.fix.ident, first = i, last = i}
            segs[#segs + 1] = cur
        else
            cur.to, cur.last = l.fix.ident, i
        end
    end
    return segs
end

-- the candidates for an identifier (SELECT DESIRED WPT when more than
-- one: FCOM p.1335), nearest first to `lat`, `lon`; the origin's and the
-- destination's terminal waypoints with them
function M.candidates(st, ident, lat, lon)
    local r = M.shown(st)
    local apts = {}
    if r.origin then apts[#apts + 1] = r.origin.ident end
    if r.dest then apts[#apts + 1] = r.dest.ident end
    return st.N.find(st.db, ident, lat, lon, apts)
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
        local path = st.N.airway_path(st.db, last.via, from.ident, fix.ident)
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
-- the previous airway entered without a TO waypoint (the FMC's
-- intersection waypoint, INTC, as that airway's TO)
function M.add_via(st, name)
    local segs = st.N.airway(st.db, name)
    if not segs then return M.NOT_IN_DATA_BASE end
    local r = M.shown(st)
    local last = r.legs[#r.legs]
    if last and last.pending then
        local x = intersection(st, last.via, name)
        if not x then return M.INVALID_ENTRY end
        local err = M.add_to(st, st.N.point(st.db, x.ident, x.region, x.kind) or x)
        if err then return err end
        r = M.edit(st)
        r.legs[#r.legs].intc = true
        r.legs[#r.legs + 1] = {via = name, pending = true}
        return
    end
    local from = end_fix(r)
    if not from then return M.INVALID_ENTRY end
    local found = false
    for _, s in ipairs(segs) do
        if s.from.ident == from.ident or s.to.ident == from.ident then found = true break end
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

-- the route as X-Plane's flight plan file (version 1100), for
-- xtlua/loadtoFMS: X-Plane's FMS draws the ND's line and the readers not
-- rebuilt yet (the AFDS's LNAV and VNAV) fly it. The origin and the
-- destination as airports (1), each waypoint as a fix (11) by its position
-- (an NDB 2, a VOR or DME 3), DRCT or its airway; no procedure headers (the
-- FMC's own legs: X-Plane would expand its own); discontinuities and
-- pending airways left out
local FMS_TYPE = {VOR = 3, DME = 3, NDB = 2}
function M.to_fms(r, cycle)
    local rows = {}
    local function row(t, ident, via, alt, lat, lon)
        rows[#rows + 1] = string.format("%d %s %s %.6f %.6f %.6f", t, ident, via, alt or 0, lat, lon)
    end
    if r.origin then row(1, r.origin.ident, "ADEP", r.origin.elev, r.origin.lat, r.origin.lon) end
    for _, l in ipairs(r.legs) do
        if l.fix then
            local via = l.via == M.DIRECT and "DRCT" or l.via
            if l.fix.kind == "APT" then
                row(1, l.fix.ident, via, l.fix.elev, l.fix.lat, l.fix.lon)
            else
                row(FMS_TYPE[l.fix.kind] or 11, l.fix.ident, via, 0, l.fix.lat, l.fix.lon)
            end
        end
    end
    if r.dest then row(1, r.dest.ident, "ADES", r.dest.elev, r.dest.lat, r.dest.lon) end
    local head = {"I", "1100 Version", "CYCLE " .. (cycle or "0000")}
    if r.origin then head[#head + 1] = "ADEP " .. r.origin.ident end
    if r.runway then head[#head + 1] = "DEPRWY " .. r.runway.ident end
    if r.dest then head[#head + 1] = "ADES " .. r.dest.ident end
    head[#head + 1] = "NUMENR " .. #rows
    return table.concat(head, "\n") .. "\n" .. table.concat(rows, "\n") .. "\n"
end

return M
