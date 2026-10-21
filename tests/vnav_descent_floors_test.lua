-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV in the descent with the STAR's and the approach's constraints from the
-- CIFP (B747_route_constraints): the highest floor (at or above, at, a
-- window's bottom, the glide slope's at the FAF) of the fixes not passed yet
-- is a level-off, whatever its height. VNAV took only the native FMS's
-- altitudes ([9]) below the transition altitude (CLB TRANS ALT, 18000 by
-- default) as level-offs, since above it [9] may be a copy of CRZ ALT; so a
-- STAR's at or above FL200 was no level-off and a descent in VNAV SPD (idle,
-- the dial its only stop) went through it. Below the transition altitude the
-- native FMS's [9], its path's altitude, stays the target where it is higher.
-- The production VNAV_NEXT_ALT (B747.70.xt.autopilot.monitor.lua) runs
-- against mocked datarefs.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        checks = checks + 1
        failures[#failures + 1] = name..": "..tostring(err)
    end
end

local sources = {}
local function slice(path, first_marker, last_marker)
    if sources[path] == nil then
        local file = assert(io.open(path))
        sources[path] = file:read("*a")
        file:close()
    end
    local source = sources[path]
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end

local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
-- EHAM LAMS2A, ILS 18R via SUG1D with the native FMS's altitudes; STRFL made up between LAMSO and ETPOS
-- with an at or above FL200 (the native FMS's path altitude there 21000)
local function eham()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("DIBAL", 52.797217, 2.5, 37000),
        entry("LAMSO", 52.732889, 2.994361, 21438), entry("STRFL", 52.65, 3.2, 21000),
        entry("ETPOS", 52.585122, 3.414178, 16752), entry("SUGOL", 52.525511, 3.96735, 11315),
        entry("NETOM", 52.422444, 4.387917, 7849), entry("NIRSI", 52.583878, 4.513372, 5563),
        entry("AM607", 52.583889, 4.646889, 4272), entry("AM608", 52.539417, 4.728139, 3400),
        entry("AM621", 52.462694, 4.721111, 2000), entry("AM622", 52.426722, 4.717806, 1310),
        entry("RW18R", 52.360258, 4.711725, 37), entry("EHAM", 52.3175, 4.7716, -11, 1)}
end
local LAMSO, STRFL, ETPOS, SUGOL, NETOM, NIRSI = 3, 4, 5, 6, 7, 8
local function constraints()
    return {[LAMSO] = {alt_desc = "-", ceiling = 23000, fl = true, phase = "descent", source = "STAR LAMS2A"},
        [STRFL] = {alt_desc = "+", floor = 20000, fl = true, phase = "descent", source = "STAR LAMS2A"},
        [SUGOL] = {alt_desc = "B", floor = 10000, ceiling = 14000, fl = true, phase = "descent",
            source = "APPCH I18R SUG1D"},
        [NETOM] = {alt_desc = "+", floor = 7000, fl = true, speed_desc = "-", speed = 250, phase = "descent"},
        [NIRSI] = {alt_desc = "+", floor = 5500, fl = true, speed_desc = "-", speed = 220, phase = "descent"},
        [10] = {alt_desc = "+", floor = 3400, phase = "descent"},
        [11] = {alt_desc = "J", floor = 2000, phase = "descent"},
        [12] = {alt_desc = "H", floor = 1310, speed_desc = "+", speed = 160, phase = "descent"},
        [13] = {alt_desc = "@", floor = 37, ceiling = 37, phase = "descent"}}
end

local function new_runtime(route, active, alt)
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    for _, chunk in ipairs({
            slice(AP.."B747.70.xt.autopilot.lua", "function getDistance(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice(AP.."B747.70.xt.autopilot.monitor.lua", "function VNAV_NEXT_ALT(numAPengaged,fms)",
                "function VNAV_CLB_ALT(numAPengaged,fms)")}) do
        setfenv(assert(loadstring(chunk)), env)()
    end
    env.simDR_latitude = route[active][5] + (route[active - 1][5] - route[active][5]) * 0.3
    env.simDR_longitude = route[active][6] + (route[active - 1][6] - route[active][6]) * 0.3
    env.simDR_pressureAlt1, env.simDR_groundspeed = alt, 200
    env.B747DR_fmscurrentIndex = active
    for i = 1, #route do route[i][10] = (i == active) end
    -- descending: past the T/D
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 100, 150, 2
    env.B747BR_cruiseAlt, env.simDR_autopilot_altitude_ft = 37000, 3000
    env.B747DR_fmstargetDistance, env.B747DR_ap_vnav_target_alt, env.B747DR_vnav_hold_index = 0, 0, 0
    env.getFMSData = function(key)
        if key == "transalt" then return "18000" end
        return ""
    end
    env.B747_route_constraints = constraints()
    return env
end

-- 1. Above the transition altitude: STRFL's at or above FL200 is the level-off before it.
case("a floor above the transition altitude", function()
    local route = eham()
    local env = new_runtime(route, STRFL, 24000)
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 20000, "24000 ft, STRFL active: STRFL's FL200, got "..tostring(target))
    -- LAMSO (at or below FL230, no floor) active: the native FMS's 21000 at STRFL, above STRFL's FL200
    env = new_runtime(route, LAMSO, 30000)
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 21000, "30000 ft, LAMSO active: STRFL's path altitude 21000, got "..tostring(target))
    -- STRFL passed: the next level-off below the transition altitude, the native FMS's 16752 at ETPOS
    env = new_runtime(route, ETPOS, 20000)
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 16752, "20000 ft past STRFL: ETPOS's 16752, got "..tostring(target))
    -- STRFL sequenced early for its turn: still its floor until the bisector
    env = new_runtime(route, ETPOS, 20500)
    env.B747DR_vnav_hold_index = STRFL
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 20000, "ETPOS active, STRFL held: FL200, got "..tostring(target))
end)

-- 2. Below the transition altitude the native FMS's path altitude stays where it is higher.
case("below the transition altitude", function()
    local route = eham()
    local env = new_runtime(route, SUGOL, 12500)
    check(env.VNAV_NEXT_ALT(1, route) == 11315, "SUGOL active: the native FMS's 11315 (above the window's FL100)")
    env = new_runtime(route, NIRSI, 6500)
    check(env.VNAV_NEXT_ALT(1, route) == 5563, "NIRSI active: the native FMS's 5563 (above FL055)")
    -- where [9] is missing or lower than the floor, the floor
    route[NIRSI][9] = 0
    route[9][9] = 0
    env = new_runtime(route, NIRSI, 6500)
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 5500, "NIRSI without [9]: its floor FL055, got "..tostring(target))
end)

-- 3. A floor the aircraft is already below is no level-off above it.
case("below a floor", function()
    local route = eham()
    local env = new_runtime(route, STRFL, 19500)
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target ~= 20000, "19500 ft, below STRFL's FL200: no level-off above, got "..tostring(target))
end)

-- 4. Without the constraints, and in the climb: as before.
case("no constraints, climb", function()
    local route = eham()
    local env = new_runtime(route, STRFL, 24000)
    env.B747_route_constraints = {}
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 16752, "no constraints: the first [9] below the transition altitude, got "..tostring(target))
    env = new_runtime(route, STRFL, 24000)
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 300, 150, 0
    env.simDR_autopilot_altitude_ft = 37000
    target = env.VNAV_NEXT_ALT(1, route)
    check(target ~= 20000, "climbing: a STAR floor is no climb target, got "..tostring(target))
end)

if #failures > 0 then
    error(string.format("vnav_descent_floors_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_descent_floors_test: %d checks passed", checks))
