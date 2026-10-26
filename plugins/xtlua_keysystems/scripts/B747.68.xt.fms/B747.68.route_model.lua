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
    return {origin = r.origin, dest = r.dest, runway = r.runway, legs = legs, sid = r.sid, star = r.star, appr = r.appr}
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
    r.origin, r.dest, r.runway, r.legs = apt, nil, nil, {}
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

-- the point a leg starts from: the waypoint before it, the origin's runway
-- or the origin before the first; nil after a discontinuity
function M.leg_from(r, i)
    local prev = r.legs[i - 1]
    if prev then
        if prev.fix and not prev.disc and not prev.pending then return prev.fix end
        return nil
    end
    return r.runway or r.origin
end

-- the leg from `from` on with this fix (the same identifier and place)
local function find_leg(r, fix, from)
    for i = from or 1, #r.legs do
        local f = r.legs[i].fix
        if f and f.ident == fix.ident and math.abs(f.lat - fix.lat) < 1e-4 and math.abs(f.lon - fix.lon) < 1e-4 then
            return i
        end
    end
    return nil
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
        l.via, l.intc, l.dto, l.crs, l.pt = M.DIRECT, nil, nil, nil, nil
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
-- deleted: INVALID DELETE)
M.INVALID_DELETE = "INVALID DELETE"
function M.legs_delete(st, i)
    local l = M.shown(st).legs[i]
    if not l or l.disc or l.pending then return M.INVALID_DELETE end
    local r = M.edit(st)
    table.remove(r.legs, i)
    local nxt = r.legs[i]
    if nxt and nxt.fix then nxt.via, nxt.dto, nxt.crs, nxt.pt = M.DIRECT, nil, nil, nil end
end

-- DIRECT TO (FMSPG p.141-144): a waypoint entered over the active
-- waypoint, the first leg of the active route: from the airplane's
-- position direct to it, the legs before it gone (one later in the
-- route), or it inserted with a ROUTE DISCONTINUITY after it (another).
-- `route_crs`: the route's course into it (INTC CRS offers it)
function M.direct_to(st, fix, route_crs)
    if not st.active then return M.INVALID_ENTRY end
    local err = M.legs_entry(st, 1, fix)
    if err then return err end
    local l = M.edit(st).legs[1]
    l.dto, l.crs, l.route_crs = true, nil, route_crs
end

-- INTC CRS (FMSPG p.143-144): the course into the direct-to waypoint (a
-- course to intercept, 0-360); the direct-to modification only
function M.intc_crs(st, crs)
    local l = st.mod and st.mod.legs[1]
    if not (l and l.dto) or crs < 0 or crs > 360 then return M.INVALID_ENTRY end
    l.crs = crs % 360
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
-- (an NDB 2, a VOR or DME 3, the FMC's own points a position 28), DRCT or
-- its airway; the runways as positions by their names with the
-- thresholds' elevations, the departure runway after the origin (as
-- X-Plane's DEP ARR puts them: the ND finds them there); no procedure
-- headers (the FMC's own legs: X-Plane would expand its own, and the
-- procedures' legs go DRCT); discontinuities, pending airways, the
-- conditional legs (no fix: step 5e) and the missed approach left out
local FMS_TYPE = {VOR = 3, DME = 3, NDB = 2, LL = 28, RWY = 28}
function M.to_fms(r, cycle)
    local rows = {}
    local function row(t, ident, via, alt, lat, lon)
        rows[#rows + 1] = string.format("%d %s %s %.6f %.6f %.6f", t, ident, via, alt or 0, lat, lon)
    end
    if r.origin then row(1, r.origin.ident, "ADEP", r.origin.elev, r.origin.lat, r.origin.lon) end
    if r.runway then row(28, r.runway.ident, "DRCT", r.runway.elev, r.runway.lat, r.runway.lon) end
    for _, l in ipairs(r.legs) do
        if l.fix and not l.missed then
            local via = (l.via == M.DIRECT or l.proc) and "DRCT" or l.via
            if l.fix.kind == "APT" then
                row(1, l.fix.ident, via, l.fix.elev, l.fix.lat, l.fix.lon)
            else
                row(FMS_TYPE[l.fix.kind] or 11, l.fix.ident, via, l.fix.kind == "RWY" and l.fix.elev or 0,
                    l.fix.lat, l.fix.lon)
            end
        end
    end
    if r.dest then row(1, r.dest.ident, "ADES", r.dest.elev, r.dest.lat, r.dest.lon) end
    local head = {"I", "1100 Version", "CYCLE " .. (cycle or "0000")}
    if r.origin then head[#head + 1] = "ADEP " .. r.origin.ident end
    if r.runway then head[#head + 1] = "DEPRWY " .. r.runway.ident end
    if r.dest then head[#head + 1] = "ADES " .. r.dest.ident end
    if r.appr and r.appr.rwy then head[#head + 1] = "DESRWY " .. r.appr.rwy end
    head[#head + 1] = "NUMENR " .. #rows
    return table.concat(head, "\n") .. "\n" .. table.concat(rows, "\n") .. "\n"
end

return M
