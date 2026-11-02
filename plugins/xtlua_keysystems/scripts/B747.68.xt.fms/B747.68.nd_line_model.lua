-- The ND's route line (6-1/6-2 step 6d2; notes/ATA-34-61-FMC.md §132): the
-- FMC's path as LNAV flies it (FCOM p.1147-1148: the active route a
-- continuous magenta line, a modification short white dashes, an inactive
-- route long cyan dashes, a lateral offset's path dashed beside the route;
-- the holds and procedure turns in the line; (step 6d4) FCOM p.1251: an
-- activated route not yet executed alternating cyan and white dashes), as
-- points the FMS bridge
-- plugin draws on each ND (X-Plane's map drew straight lines between the
-- flight plan's rows with its own turns: a turn of more than 135 degrees
-- broke up on the ND, s198's ATMUG). From the path model's elements (the
-- active leg first):
--  - a line, course or heading to its end (a vectors leg its VECTORS_LEN
--    nm, no line on from it), an arc along its circle;
--  - the fly-by turns' arcs (the path model's turn, at the speed the turn is
--    flown at: `kt(i)` for the turn at element i's end);
--  - a turn flown over its fix as LNAV steers it (the LNAV model's
--    flyover_path), the next leg's line from where LNAV is on it;
--  - an intercept's end (a CI's or VI's) as a fly-by turn's arc: LNAV
--    begins the turn onto the next leg where it brings the airplane onto
--    that leg's course (the LNAV model's `ended`), not at the corner;
--  - (step 6d3) the turn the path model put before a heading or course
--    leg or a DF (its `turn_in`: flown over the point before it) round its
--    arc; after a conditional leg's end (an altitude, a DME distance, a
--    radial, a distance) the turn onto a line or course as LNAV steers it
--    (flyover_path, as after a fly-over fix), the active leg's from where
--    the condition was met;
--  - a hold's racetrack and a procedure turn's shape (the path model's
--    shape, `shape[i]`);
--  - no line across a discontinuity or into a leg with no path, nor the
--    missed approach (X-Plane's flight plan left it out too: estimate).
-- `prev`: the element sequenced last (the leg before the active one): the
-- turn at its fix into the active leg stays in the line while it is flown
-- (FCOM p.1147: the path's transitions; estimate).
-- Pure.
--   local D = B747_nd_line_model                   -- in XTLua, after dofile
--   local D = dofile(".../B747.68.nd_line_model.lua") -- in the tests
--   local pts = D.route(path, {P = P, L = L, style = D.ACTIVE, kt = kt,
--       shape = shape, cache = {}, prev = e0})
--   D.pack(pts, max) -> lat, lon, pen, n
local M = setmetatable({}, {})
B747_nd_line_model = M

-- the pieces' styles (the plugin's colours and dashes: FCOM p.1148; step
-- 6d4: ACTIVATING, FCOM p.1251)
M.ACTIVE, M.MOD, M.INACTIVE, M.OFFSET, M.ACTIVATING = 1, 2, 3, 4, 5
-- the points the datarefs hold (laminar/B747/nd/line/*)
M.MAXP = 600
-- a turn's or an arc's points every TURN_STEP degrees (estimate: smooth at
-- the 10 NM range)
M.TURN_STEP = 5

local RAD = math.pi / 180
local function wrap180(a) return (a + 180) % 360 - 180 end
-- the conditional legs' ends LNAV turns after (not an intercept's)
local COND = {alt = true, dme = true, radial = true, dist = true}

-- the points of an arc around c of radius r from bearing b0 sweeping
-- `sweep` degrees (dir "R" clockwise), its ends left out
local function arc(add, P, c, r, b0, sweep, dir)
    local sgn = dir == "R" and 1 or -1
    local n = math.floor(sweep / M.TURN_STEP)
    for k = 1, n do
        if k * M.TURN_STEP < sweep - M.TURN_STEP / 3 then add(P.point(c, (b0 + sgn * k * M.TURN_STEP) % 360, r)) end
    end
end

-- the turn flown over e1's fix (or a conditional leg's end) onto e2 (the
-- LNAV model's flyover_path at `vt` kt; e2's line need not start there: a
-- CF's from abeam it), kept in `cache` by the point, the courses, e2's end
-- and the speed: {pts, cap (where LNAV is on e2)} or false
local function flyover(o, e1, e2, vt)
    local P, L = o.P, o.L
    if not (L and e2 and e1.b and e2.a) then return nil end
    if e2.kind ~= "line" and e2.kind ~= "course" then return nil end
    local c1, c2 = P.end_course(e1), P.start_course(e2)
    if not (c1 and c2) or math.abs(wrap180(c2 - c1)) < 1 then return nil end
    local v = math.floor(vt / 10 + 0.5) * 10
    local b2 = e2.b or e2.a
    local key = string.format("%.5f %.5f %.1f %.1f %.5f %.5f %d", e1.b.lat, e1.b.lon, c1, c2, b2.lat, b2.lon, v)
    local cache = o.cache or {}
    local f = cache[key]
    if f == nil then
        local pts, cap = L.flyover_path(P, e2, e1.b, c1, v)
        f = pts and {pts = pts, cap = cap} or false
        cache[key] = f
    end
    if o.used then o.used[key] = f end
    return f or nil
end

-- an intercept's end as the path model's fly-by fix (a line from its start
-- to the corner on its course or heading)
local function intc_fix(e)
    return {kind = "line", term = "fix", a = e.a, b = e.b, len = e.len, crs = e.crs or e.hdg}
end

-- the line's points for the path's elements: {lat, lon, pen} with pen the
-- style at a piece's first point, 0 after it; appended to `out`
function M.route(path, o, out)
    out = out or {}
    local P = o.P
    local style = o.style or M.ACTIVE
    local shape = o.shape or {}
    local open, last = false, nil
    local function add(p)
        if not p then return end
        if open and last and math.abs(last.lat - p.lat) < 1e-7 and math.abs(last.lon - p.lon) < 1e-7 then return end
        out[#out + 1] = {lat = p.lat, lon = p.lon, pen = open and 0 or style}
        open, last = true, p
    end
    local function kt(i)
        local v = type(o.kt) == "function" and o.kt(i) or o.kt
        return v or 250
    end
    -- the turn at e1's fix (or intercept, or conditional end) into e2: a
    -- fly-by turn's arc (the line on e2 from its end) or a turn flown over
    -- the point; where e2's line starts
    local function turn(e1, e2, vt)
        -- the path model's turn into e2 (drawn with e2)
        if e2.turn_in then add(e1.b) return nil end
        local tr = P.turn(e1.term == "intc" and intc_fix(e1) or e1, e2, vt)
        if tr then
            add(tr.t1)
            local sgn = tr.delta > 0 and 1 or -1
            arc(add, P, tr.center, tr.r, (tr.c1 - 90 * sgn) % 360, math.abs(tr.delta), tr.dir)
            add(tr.t2)
            return tr.t2
        end
        add(e1.b)
        if e1.missed then return nil end
        if e1.term == "fix" then
            if e1.kind ~= "line" and e1.kind ~= "arc" then return nil end
        elseif not COND[e1.term] then
            return nil
        end
        local f = flyover(o, e1, e2, vt)
        if not f then return nil end
        for _, q in ipairs(f.pts) do add(q) end
        return f.cap
    end
    local start = nil
    -- the turn into the active leg at the fix sequenced last, while flown;
    -- at a conditional leg's end from where its condition was met (the
    -- active leg's start), not where it was predicted
    local e0, e1 = o.prev, path and path[1]
    local s1 = e1 and (e1.start or e1.a)
    if e0 and e1 and e0.b and s1 and e1.a and not e1.turn_in and (e1.kind == "line" or e1.kind == "course") then
        local _, gap = P.course(e0.b, s1)
        if gap <= 0.1 then
            start = turn(e0, e1, kt(0))
        elseif COND[e0.term] then
            start = turn(setmetatable({b = s1}, {__index = e0}), e1, kt(0))
        end
    end
    for i, e in ipairs(path or {}) do
        local nxt = path[i + 1]
        if nxt and nxt.missed then nxt = nil end
        local k = e.kind
        if e.missed then
            open, start = false, nil
        elseif k == "line" or k == "course" or k == "heading" or k == "arc" then
            local a = start or e.a
            start = nil
            if not a then
                open = false
            else
                -- (step 6d3) round the turn into it to where it starts
                local ti = e.turn_in
                if ti then
                    add(ti.from)
                    arc(add, P, ti.center, ti.r, P.course(ti.center, ti.from), ti.sweep, ti.dir)
                end
                add(a)
                if k == "arc" and e.center and e.r and e.len then
                    local s0 = P.course(e.center, e.a)
                    arc(add, P, e.center, e.r, s0, e.len / (e.r * RAD), e.dir)
                end
                local b = e.b
                if not b and (k == "course" or k == "heading") and e.term == "manual" then
                    b = P.point(e.a, e.crs or e.hdg, P.VECTORS_LEN)
                end
                if not b then
                    open = false
                elseif e.term == "manual" then
                    -- a vectors leg: no line on to the next leg
                    add(b)
                    open = false
                elseif nxt and (e.term == "fix" or e.term == "intc" or COND[e.term]) then
                    start = turn(e, nxt, kt(i))
                else
                    add(b)
                end
            end
        elseif k == "hold" then
            -- round the racetrack from the fix and back to it
            add(start or e.b)
            local sh = shape[i]
            if sh and sh.pts then
                for _, q in ipairs(sh.pts) do add(q) end
                add(e.b)
            end
            start = nil
        elseif k == "pturn" then
            add(start or e.a)
            local sh = shape[i]
            if sh and sh.pts then for _, q in ipairs(sh.pts) do add(q) end end
            start = nil
        else
            -- a discontinuity, a leg with no path into its fix
            open, start = false, nil
        end
    end
    return out
end

-- the points as the datarefs' arrays (at most `max`, MAXP: the route's far
-- end left out): lat, lon, pen and their number
function M.pack(pts, max)
    max = math.min(max or M.MAXP, M.MAXP)
    local lat, lon, pen = {}, {}, {}
    local n = math.min(#pts, max)
    for k = 1, n do
        local p = pts[k]
        lat[k], lon[k], pen[k] = p.lat, p.lon, p.pen
    end
    -- a last point starting a piece draws nothing
    if n > 0 and pen[n] ~= 0 then n = n - 1 end
    return lat, lon, pen, n
end

return M
