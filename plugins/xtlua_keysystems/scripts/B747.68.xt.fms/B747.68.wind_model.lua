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

-- The winds and temperatures the predictions fly in (step 8e3; notes/
-- ATA-34-61-FMC.md §53; FCOM p.1364, FMSPG p.230-234):
--   forecast: between two waypoints in a line along the route, at each
--   waypoint between its altitudes in a line, the highest's above them,
--   below the lowest down to none at the origin's elevation in the climb,
--   the destination's else (FMSPG p.230); in the descent the DESCENT
--   FORECAST's winds when there are any, the highest blending into the
--   route's wind at the cruise altitude (none: itself up to it), the
--   lowest down to none at the destination; the temperature the waypoints'
--   (propagated) deviation from the standard day, none without an entry
--   (the standard day: FMSPG p.122);
--   mixed with the measured wind (and temperature: an estimate), the
--   measured's share by FMSPG p.233's figure 4.6-3 (read off: 1 here, .5
--   at 200 NM, .2 at 400, none from 750) of the distance ahead in the
--   cruise, of the altitude from the airplane's in the climb and descent
--   (5,000 ft for 200 NM): the airplane's phase (an estimate).
--   local F = W.field{legs = the prediction's legs ({dist, p0, p1}),
--       route = r, course = function(lat1, lon1, lat2, lon2) -> true
--       course, measured = {dir, kt, isa, h, phase}, orig_elev, dest_elev,
--       crz, des = DESCENT FORECAST's {{ft, dir, kt}...}}
--   F.wind(x, h, phase) -> the headwind (kt) on the leg's track at x NM
--   F.isa(x, h) -> the ISA deviation (C); F.vec(x, h, phase) -> east,
--   north (kt, the air's motion)
local RAD = math.pi / 180
local function vec(dir, kt) return -kt * math.sin(dir * RAD), -kt * math.cos(dir * RAD) end
local MIX = {{0, 1}, {50, 0.95}, {100, 0.82}, {150, 0.64}, {200, 0.5}, {250, 0.4}, {300, 0.32},
    {350, 0.25}, {400, 0.2}, {450, 0.15}, {500, 0.11}, {550, 0.07}, {600, 0.04}, {650, 0.02}, {700, 0.01}, {750, 0}}
M.MIX_FT_PER_NM = 5000 / 200

-- the measured wind's share at d NM (equivalent) from the airplane
function M.mix(d)
    if d <= 0 then return 1 end
    for k = 2, #MIX do
        if d <= MIX[k][1] then
            local a, b = MIX[k - 1], MIX[k]
            return a[2] + (b[2] - a[2]) * (d - a[1]) / (b[1] - a[1])
        end
    end
    return 0
end

-- a waypoint's forecast winds, high first: {{ft, u, v}...}
local function profile(r, i)
    local p = {}
    for _, ft in ipairs(M.alts(r)) do
        local dir, kt = M.wind(r, i, ft)
        if dir then
            local u, v = vec(dir, kt)
            p[#p + 1] = {ft = ft, u = u, v = v}
        end
    end
    return p
end

-- a profile's wind at h: between its altitudes, the highest's above, the
-- lowest's down to none at ground (ft)
local function at_alt(p, h, ground)
    if #p == 0 then return 0, 0 end
    if h >= p[1].ft then return p[1].u, p[1].v end
    for k = 2, #p do
        if h >= p[k].ft then
            local a, b = p[k - 1], p[k]
            local t = (h - b.ft) / (a.ft - b.ft)
            return b.u + (a.u - b.u) * t, b.v + (a.v - b.v) * t
        end
    end
    local low = p[#p]
    if h <= ground or low.ft <= ground then return 0, 0 end
    local t = (h - ground) / (low.ft - ground)
    return low.u * t, low.v * t
end

function M.field(f)
    local legs, r = f.legs or {}, f.route
    local n = #legs
    local lx, crs, prof, dev = {}, {}, {}, {}
    local acc, winds = 0, false
    for i, l in ipairs(legs) do
        acc = acc + (l.dist or 0)
        lx[i] = acc
        if (l.dist or 0) > 0 and l.p0 and l.p1 then crs[i] = f.course(l.p0.lat, l.p0.lon, l.p1.lat, l.p1.lon) end
        prof[i] = (r and r.legs[i]) and profile(r, i) or {}
        if #prof[i] > 0 then winds = true end
        dev[i] = (r and r.legs[i]) and (M.oat(r, i, 0) - M.isa(0)) or 0
    end
    -- a leg without a track (a conditional leg) the one before's, else after
    local last = nil
    for i = 1, n do if crs[i] then last = crs[i] else crs[i] = last end end
    for i = n, 1, -1 do if crs[i] then last = crs[i] else crs[i] = last end end

    -- the leg x is on (the last beyond the route)
    local function seg(x)
        local lo, hi = 1, n
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if lx[mid] < x then lo = mid + 1 else hi = mid end
        end
        return lo
    end
    -- between the waypoint before (the first's before the first) and after
    local function along(x, get)
        local k = seg(x)
        local x0 = lx[k - 1] or 0
        local t = lx[k] > x0 and math.max(0, math.min(1, (x - x0) / (lx[k] - x0))) or 1
        return get(math.max(1, k - 1)), get(k), t
    end
    local function forecast(x, h, phase)
        if n == 0 then return 0, 0 end
        local ground = phase == "clb" and (f.orig_elev or 0) or (f.dest_elev or 0)
        local a, b, t = along(x, function(i) return prof[i] end)
        local ua, va = at_alt(a, h, ground)
        local ub, vb = at_alt(b, h, ground)
        return ua + (ub - ua) * t, va + (vb - va) * t
    end
    local desP = {}
    for _, s in ipairs(f.des or {}) do
        if s.ft and s.dir then
            local u, v = vec(s.dir, s.kt)
            desP[#desP + 1] = {ft = s.ft, u = u, v = v}
        end
    end
    table.sort(desP, function(a, b) return a.ft > b.ft end)
    local function des_forecast(x, h)
        if #desP == 0 then return forecast(x, h, "des") end
        local top = desP[1]
        if h > top.ft and f.crz and f.crz > top.ft then
            local cu, cv = top.u, top.v
            if winds then cu, cv = forecast(x, f.crz, "crz") end
            local t = math.min(1, (h - top.ft) / (f.crz - top.ft))
            return top.u + (cu - top.u) * t, top.v + (cv - top.v) * t
        end
        return at_alt(desP, h, f.dest_elev or 0)
    end

    local m = f.measured or {}
    local mu, mv = 0, 0
    if m.kt then mu, mv = vec(m.dir, m.kt) end
    local function share(x, h)
        if m.phase == "crz" then return M.mix(x) end
        return M.mix(math.abs(h - (m.h or h)) / M.MIX_FT_PER_NM)
    end
    local F = {}
    function F.vec(x, h, phase)
        local fu, fv
        if phase == "des" then fu, fv = des_forecast(x, h) else fu, fv = forecast(x, h, phase) end
        local w = share(x, h)
        return w * mu + (1 - w) * fu, w * mv + (1 - w) * fv
    end
    function F.wind(x, h, phase)
        local u, v = F.vec(x, h, phase)
        local c = n > 0 and crs[seg(x)] or nil
        if not c then return 0 end
        return -(u * math.sin(c * RAD) + v * math.cos(c * RAD))
    end
    function F.isa(x, h)
        local fd = 0
        if n > 0 then
            local a, b, t = along(x, function(i) return dev[i] end)
            fd = a + (b - a) * t
        end
        local w = share(x, h)
        return w * (m.isa or 0) + (1 - w) * fd
    end
    return F
end

return M
