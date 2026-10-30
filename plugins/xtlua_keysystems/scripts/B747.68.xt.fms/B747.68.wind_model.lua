-- 747-400 FMC waypoint winds and temperatures without X-Plane (6-1/6-2
-- step 8e1; docs/overhaul/notes/ATA-34-61-FMC.md §51): the WIND pages'
-- data on a route (FCOM p.1364-1366; FMSPG p.121-124, p.228-232): up to
-- four wind altitudes shared by all of the route's waypoints; each
-- waypoint's entered winds at them, propagated down the route to the next
-- entry at that altitude, the first entry at an altitude also back to the
-- route's start; without an entry at an altitude, no wind there. One
-- forecast temperature (an altitude and its OAT) a waypoint, propagated the
-- same way (an estimate: the sources say only that it is), the other
-- altitudes' OATs by the standard lapse rate; without one, the standard
-- day. A deleted waypoint takes its entries with it (estimate: as the FMC
-- loads before 10.2, FMSPG p.231).
--
--   local W = B747_wind_model
--   W.add_alt(r, ft)                 -> nil, or an error to show
--   W.delete_alt(r, ft)              the altitude and its winds everywhere
--   W.set_wind(r, i, ft, dir, kt)    W.delete_wind(r, i, ft)
--   W.wind(r, i, ft)                 -> dir, kt, entered at leg i (nil: none)
--   W.set_oat(r, i, ft, c)           W.delete_oat(r, i)
--   W.oat(r, i, ft)                  -> C, entered at leg i
--
-- r: a route (B747.68.route_model.lua): r.windAlts the altitudes (ft, the
-- highest first), a leg's winds l.wind[ft] = {dir, kt} (true degrees the
-- wind blows from, knots), its temperature l.oat = {ft, c}.

local M = setmetatable({}, {})
B747_wind_model = M

M.ALTS = 4
M.INVALID_ENTRY = "INVALID ENTRY"

-- the wind altitudes, the highest first
function M.alts(r) return r.windAlts or {} end

function M.add_alt(r, ft)
    local a = r.windAlts or {}
    if #a >= M.ALTS then return M.INVALID_ENTRY end
    for _, h in ipairs(a) do if h == ft then return M.INVALID_ENTRY end end
    a[#a + 1] = ft
    table.sort(a, function(x, y) return x > y end)
    r.windAlts = a
    return nil
end

function M.delete_alt(r, ft)
    local a = r.windAlts or {}
    for k = #a, 1, -1 do if a[k] == ft then table.remove(a, k) end end
    for _, legs in ipairs({r.legs, r.passed or {}}) do
        for i in ipairs(legs) do M.delete_wind({legs = legs}, i, ft) end
    end
end

function M.set_wind(r, i, ft, dir, kt)
    local l = r.legs[i]
    -- a new table: a route's copy (a modification) shares its legs' fields
    local w = {}
    for h, v in pairs(l.wind or {}) do w[h] = v end
    w[ft] = {dir = dir, kt = kt}
    l.wind = w
end

function M.delete_wind(r, i, ft)
    local l = r.legs[i]
    if not (l.wind and l.wind[ft]) then return end
    local w = {}
    for h, v in pairs(l.wind) do if h ~= ft then w[h] = v end end
    l.wind = next(w) and w or nil
end

-- a wind entry (FMSPG p.179, the DESCENT FORECAST's; the WIND pages' as
-- well: an estimate): ddd/sss, ddd/ or /sss, the direction (true) three
-- digits up to 360, the speed up to 250 kt; nil, nil when not valid
function M.parse_wind(s)
    s = s or ""
    local d, k = s:match("^(%d%d%d)/(%d%d?%d?)$")
    if not d then d = s:match("^(%d%d%d)/$") end
    if not d and not k then k = s:match("^/(%d%d?%d?)$") end
    local dir, kt = tonumber(d), tonumber(k)
    if (not dir and not kt) or (dir and dir > 360) or (kt and kt > 250) then return nil, nil end
    return dir and dir % 360, kt
end

-- a leg has winds entered (RTE DATA's W>: FCOM p.1363)
function M.entered(l) return l ~= nil and l.wind ~= nil and next(l.wind) ~= nil end

-- the entry that applies at leg i (get: a leg's own entry or nil): the
-- leg's, else the last one before it (the passed legs' too: they go on
-- propagating, FMSPG p.232), else the first one after it
local function propagated(r, i, get)
    local e = get(r.legs[i])
    if e then return e, true end
    for j = i - 1, 1, -1 do
        e = get(r.legs[j])
        if e then return e, false end
    end
    local passed = r.passed or {}
    for j = #passed, 1, -1 do
        e = get(passed[j])
        if e then return e, false end
    end
    for j = i + 1, #r.legs do
        e = get(r.legs[j])
        if e then return e, false end
    end
    return nil
end

function M.wind(r, i, ft)
    local w, here = propagated(r, i, function(l) return l.wind and l.wind[ft] end)
    if not w then return nil end
    return w.dir, w.kt, here
end

-- the standard day's temperature (C) at ft
function M.isa(ft)
    return 15 - 1.98 * math.min(ft, 36089) / 1000
end

-- an OAT entry's limits (FMSPG p.122): from -80 C up to 55 C at sea level
-- and -40 C at 45,100 ft, in a line between them
function M.oat_valid(ft, c)
    local hi = 55 - 95 * math.max(0, math.min(ft, 45100)) / 45100
    return c >= -80 and c <= hi
end

function M.set_oat(r, i, ft, c) r.legs[i].oat = {ft = ft, c = c} end
function M.delete_oat(r, i) r.legs[i].oat = nil end

-- the OAT at ft at leg i: the (propagated) entry's deviation from the
-- standard day at its altitude, at ft; the standard day without one
function M.oat(r, i, ft)
    local e, here = propagated(r, i, function(l) return l.oat end)
    if not e then return M.isa(ft), false end
    return M.isa(ft) + (e.c - M.isa(e.ft)), here
end

return M
