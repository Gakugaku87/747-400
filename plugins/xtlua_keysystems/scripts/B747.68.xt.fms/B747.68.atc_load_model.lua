-- 747-400 FMC ATC uplink LOAD without X-Plane (2026-11-20, GAP N19-ATC-03
-- stage A; docs/overhaul/notes/ATA-34-61-FMC.md §175.5): the elements of an
-- ATC uplink the FMC loads into the active route, and how (CPDLC
-- p.202-203, appendix G: the B747-400 FMS's loadable uplink message rules;
-- FMSPG p.290, p.293; FCOM p.760-761, p.1433-1434):
--   UM74 PROCEED DIRECT TO [position]: the position the first fix of the
--     active route; one in the route: the route between the airplane and
--     it collapsed, else a ROUTE DISCONTINUITY after it (the LEGS page's
--     DIRECT TO);
--   UM77 AT [position] PROCEED DIRECT TO [position]: the first a fix of the
--     active route; the second later in it: the route between the two
--     collapsed, else inserted after the first with a discontinuity;
--   UM46 CROSS [position] AT [level]: a fix of the active route, its AT
--     altitude constraint as RTE LEGS takes it;
--   UM51, 52, 53 CROSS [position] AT, AT OR BEFORE, AT OR AFTER [time]: a
--     fix of the active route, RTA PROGRESS's FIX and time (B, A); only on
--     an airplane with RTA (not the 570: FCOM p.1375) and when RTA can be
--     entered (not with ENG OUT); appendix G's UM53 says "AT OR BEFORE" (a
--     misprint: AFTER's own words), here A;
--   UM64 OFFSET [distance] [direction] OF ROUTE: LEFT or RIGHT, nautical
--     miles, at most 99: RTE's offset (where RTE takes one: in the air, not
--     on a procedure - FMSPG p.293's example);
--   not loadable on the 747-400 (appendix G): UM47, 48 (CROSS AT OR ABOVE,
--     AT OR BELOW), UM75 (WHEN ABLE PROCEED DIRECT TO); nor anything else
--     (CLIMB, EXPECT, a direct-to after a time or a level: UM76, 78; CROSS
--     ... AT AND MAINTAIN: UM49, 61 - CPDLC p.128);
--   loadable on the airplane, not here yet (stage B: the user's decision,
--     their form not in the sources): the route clearances (UM79 CLEARED TO
--     [position] VIA, UM80 CLEARED, UM83 AT [position] CLEARED), the
--     procedures (UM81: FMSPG p.293's DEPARTURES and ARRIVALS, appendix G
--     not) and the holds (HOLD AT: FMSPG p.293's HOLD): loadable data the
--     FMC does not load (PARTIAL CLEARANCE LOADED: estimate), no LOAD
--     prompt of their own.
-- LOAD: each element in the message's order (CPDLC p.90, p.129); none
-- loaded UNABLE TO LOAD CLEARANCE, some PARTIAL CLEARANCE LOADED (FCOM
-- p.1433-1434; FMSPG p.293).
-- Estimates (the providers' text is free text, without its elements'
-- boundaries or parameter marks): the elements the uplink model's (by "/",
-- by the words), "CROSS X" and an "AT ..." after it one element (the
-- uplink model splits after a position with a digit), Hoppie's "@" marks
-- dropped; a time HHMMZ or HHMMSSZ (with its Z: "AT 8000" is a level); a
-- level FLnnn or feet (FT, FEET or none); a distance an integer with NM or
-- none; a position an identifier (the route's, the first downtrack; else
-- the navigation data's nearest to the airplane, for UM77's second to the
-- first: CPDLC p.31's rules 6 and 7) or a latitude/longitude as the CDU
-- takes it.
--
--   local L = B747_atc_load_model
--   local items = L.items(text)         -- {kind, um, fix, at, alt, time, suffix, dist}
--   L.loadable(items, has_rta)          -- the LOAD prompt
--   local res = L.load(items, env)      -- {route, rta, data, ok, msg}

local M = setmetatable({}, {})
B747_atc_load_model = M

M.UNABLE = "UNABLE TO LOAD CLEARANCE"
M.PARTIAL = "PARTIAL CLEARANCE LOADED"

-- a time HHMMZ or HHMMSSZ: minutes of the day (to a tenth, as RTA PROGRESS
-- takes it: FCOM p.1384), nil else
local function time_of(w)
    local h, m, s = string.match(w or "", "^(%d%d)(%d%d)(%d*)Z$")
    if not h or (s ~= "" and #s ~= 2) then return nil end
    h, m, s = tonumber(h), tonumber(m), tonumber(s) or 0
    if h > 23 or m > 59 or s > 59 then return nil end
    return math.floor((h * 60 + m + s / 60) * 10 + 0.5) / 10
end
-- a level: FL250, FL 250, 12000 FT, 12000FT, 12000 FEET, 12000 (feet)
local function level_of(t)
    local fl = string.match(t, "^FL ?(%d%d%d?)$")
    if fl then return tonumber(fl) * 100 end
    local ft = string.match(t, "^(%d+) ?FT$") or string.match(t, "^(%d+) FEET$") or string.match(t, "^(%d+)$")
    ft = tonumber(ft or "")
    if ft and ft > 0 then return ft end
    return nil
end
-- a distance: 20NM, 20 NM, 20
local function nm_of(t)
    return tonumber(string.match(t, "^(%d+) ?NM$") or string.match(t, "^(%d+)$") or "")
end
-- a position: an identifier or a latitude/longitude (letters, digits,
-- points, a letter among them), not a time nor a level
local function position(w)
    if not w or #w > 16 or not string.match(w, "^[%u%d%.]+$") or not string.match(w, "%u") then return nil end
    if string.match(w, "^FL%d+$") or string.match(w, "^%d+FT$") or string.match(w, "^%d+Z$") then return nil end
    return w
end

-- an element's kind and values, nil when not loadable
local function element(e)
    local s = string.gsub(e, "%.$", "")
    -- UM74
    local p = string.match(s, "^PROCEED DIRECT TO (%S+)$")
    if p then return position(p) and {kind = "DIRECT", um = 74, fix = p} or nil end
    -- UM77 (AT a position: not a time, UM76, nor a level, UM78)
    local a, b = string.match(s, "^AT (%S+) PROCEED DIRECT TO (%S+)$")
    if a then return (position(a) and position(b)) and {kind = "AT_DIRECT", um = 77, at = a, fix = b} or nil end
    -- UM46, UM51-53 (UM47, 48: not loadable on the 747-400)
    local f, rest = string.match(s, "^CROSS (%S+) AT (.+)$")
    if f then
        if not position(f) then return nil end
        local mode, tw = string.match(rest, "^OR (%u+) (.+)$")
        if mode then
            local t = time_of(tw)
            if t and (mode == "BEFORE" or mode == "AFTER") then
                return {kind = "RTA", um = mode == "BEFORE" and 52 or 53, fix = f, time = t,
                    suffix = mode == "BEFORE" and "B" or "A"}
            end
            return nil
        end
        local t = time_of(rest)
        if t then return {kind = "RTA", um = 51, fix = f, time = t} end
        local ft = level_of(rest)
        if ft then return {kind = "ALT", um = 46, fix = f, alt = ft} end
        return nil
    end
    -- UM64: LEFT or RIGHT, 1 to 99 NM
    local d, dir = string.match(s, "^OFFSET (.-) (%u+) OF ROUTE$")
    if d then
        local n = nm_of(d)
        if n and n >= 1 and n <= 99 and (dir == "LEFT" or dir == "RIGHT") then
            return {kind = "OFFSET", um = 64, dist = dir == "LEFT" and -n or n}
        end
        return nil
    end
    -- stage B: loadable on the airplane, not here
    if string.match(s, "^CLEARED TO DEVIATE ") then return nil end
    if string.match(s, "^CLEARED ") or string.match(s, "^AT %S+ CLEARED ") or string.match(s, "^HOLD AT ") then
        return {kind = "LATER"}
    end
    return nil
end

-- the uplink's elements the LOAD knows: a list of {kind ("DIRECT",
-- "AT_DIRECT", "ALT", "RTA", "OFFSET", "LATER"), um, and its values}
function M.items(text)
    local out = {}
    local t = string.upper((string.gsub(text or "", "@", "")))
    for piece in (t .. "/"):gmatch("([^/]*)/") do
        local merged = {}
        for _, e in ipairs(B747_atc_uplink_model.elements(piece)) do
            local prev = merged[#merged]
            if prev and string.match(prev, "^CROSS ") and string.match(e, "^AT ") then
                merged[#merged] = prev .. " " .. e
            else
                merged[#merged + 1] = e
            end
        end
        for _, e in ipairs(merged) do
            local it = element(e)
            if it then out[#out + 1] = it end
        end
    end
    return out
end

-- the kinds the LOAD prompt is for (RTA's only with RTA)
local STAGE_A = {DIRECT = true, AT_DIRECT = true, ALT = true, OFFSET = true}
local function counted(it, has_rta)
    return it.kind ~= "RTA" or has_rta == true
end
function M.loadable(items, has_rta)
    for _, it in ipairs(items or {}) do
        if STAGE_A[it.kind] or (it.kind == "RTA" and has_rta == true) then return true end
    end
    return false
end

-- a fix of the route shown (the active route, or its modification once an
-- element has made one) from leg `from` on: its leg and fix
local function in_route(R, st, ident, from)
    local legs = R.shown(st).legs
    for i = from or 1, #legs do
        local l = legs[i]
        if l.fix and not l.disc and not R.is_hold(l) and l.fix.ident == ident then return i, l.fix end
    end
    return nil
end
-- a position not in the route: a latitude/longitude, else the navigation
-- data's nearest to `near`
local function resolve(env, ident, near)
    local ll = env.R.parse_latlon(ident)
    if ll then return ll end
    return env.R.candidates(env.st, ident, near.lat, near.lon)[1]
end
-- the route's course into leg j's fix (magnetic: INTC CRS offers it, as the
-- LEGS page's DIRECT TO)
local function route_crs(env, j, f)
    local R = env.R
    local from = R.leg_from(R.shown(env.st), j)
    if not from then return nil end
    local c = R.course(from.lat, from.lon, f.lat, f.lon)
    local var = env.var and env.var(from.lat, from.lon) or 0
    return math.floor((c - (var or 0)) % 360 + 0.5) % 360
end

local LOAD = {}
-- UM74
function LOAD.DIRECT(it, env)
    local R, st = env.R, env.st
    if not st.active then return false end
    local j, f = in_route(R, st, it.fix, 1)
    local rc = j and route_crs(env, j, f) or nil
    f = f or resolve(env, it.fix, env.ppos)
    if not f then return false end
    return R.direct_to(st, f, rc, env.ppos) == nil
end
-- UM77
function LOAD.AT_DIRECT(it, env)
    local R, st = env.R, env.st
    if not st.active then return false end
    local i, a = in_route(R, st, it.at, 1)
    if not i then return false end
    local _, f = in_route(R, st, it.fix, i + 1)
    f = f or resolve(env, it.fix, a)
    if not f then return false end
    return R.legs_entry(st, i + 1, f) == nil
end
-- UM46
function LOAD.ALT(it, env)
    local R, st = env.R, env.st
    if not st.active then return false end
    local i = in_route(R, st, it.fix, 1)
    if not i then return false end
    return R.set_constraint(st, i, {alt = it.alt, akind = ""}, env.crz_alt) == nil
end
-- UM64
function LOAD.OFFSET(it, env)
    return env.R.set_offset(env.st, it.dist, env.airborne) == nil
end
-- UM51-53: RTA PROGRESS's modification
function LOAD.RTA(it, env)
    local R, st, s = env.R, env.st, env.rta
    if not (s and st.active) or not in_route(R, st, it.fix, 1) then return false end
    env.T.enter_fix(s, it.fix)
    return env.T.enter_time(s, it.time, it.suffix) == true
end
-- stage B
function LOAD.LATER() return false end

-- LOAD: the elements into the active route (env: R the route model, st
-- the active route's state, ppos {lat, lon}, airborne, crz_alt (ft, nil
-- without), var(lat, lon) the magnetic variation, T the RTA model, rta its
-- state (nil: RTA cannot be entered now), has_rta (the airplane's)). The
-- result: route (the route changed: its modification), rta (RTA's
-- modification), data (the loadable elements), ok (those loaded), msg
-- (UNABLE TO LOAD CLEARANCE, PARTIAL CLEARANCE LOADED or nil)
function M.load(items, env)
    local res = {route = false, rta = false, data = 0, ok = 0, msg = nil}
    for _, it in ipairs(items or {}) do
        if counted(it, env.has_rta) then
            res.data = res.data + 1
            if LOAD[it.kind](it, env) then
                res.ok = res.ok + 1
                if it.kind == "RTA" then res.rta = true elseif it.kind ~= "LATER" then res.route = true end
            end
        end
    end
    if res.ok == 0 then
        res.msg = M.UNABLE
    elseif res.ok < res.data then
        res.msg = M.PARTIAL
    end
    return res
end

return M
