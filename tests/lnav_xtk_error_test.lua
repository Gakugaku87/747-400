-- Run from the repository root with Lua 5.1 or LuaJIT.
-- LNAV's cross-track error (laminar/B747/autopilot/lnav/xtk_error, the
-- PROGRESS page's XTK ERROR): every frame the signed distance from the active
-- leg, + right of it, from the offset track when an offset is flown, and from
-- the path LNAV flies (the arc in a fly-by turn) where it flies one. It used
-- to be written only by the leg search (the smallest unsigned distance of the
-- legs it looked at, 100 when none), which runs in the last 5 nm or third of
-- a leg, so in flight it stayed at an old value for most of a leg (the kit
-- recorded 100 or 0.0015 for hours). The production waypoint functions
-- (B747.70.xt.autopilot.lua) run against mocked datarefs; the PROGRESS page
-- (B744.fms.pages.progress.lua) is rendered with mocked datarefs.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local file = assert(io.open(AP.."B747.70.xt.autopilot.lua"))
local source = file:read("*a")
file:close()
local function slice(first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end

local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end

local function new_runtime()
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    for _, chunk in ipairs({
            slice("function B747_rescale(", "function getFMSData(name)"),
            slice("function getTriSpaceSolver(ab,ac,cb)", "local beganDescentAny"),
            slice("function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice("function movePoint(", "\nend\n").."\nend\n",
            slice("function B747_getCurrentWayPoint(fmsO)", "local LNAV_MAX_PREEMPT_XTK_NM"),
            slice("local LNAV_MAX_PREEMPT_XTK_NM", "function B747_ap_altitude(fms)")}) do
        setfenv(assert(loadstring(chunk)), env)()
    end
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot, env.simDR_onGround = 31000, 31000, 0, 0
    env.simDR_groundspeed, env.simDR_TAS_mps = 246, 246
    env.simDR_autopilot_bank_limit, env.simDR_autopilot_bank_angles = 4, {[0] = 5, 10, 15, 20, 25, 30}
    env.B747DR_ap_lnav_state, env.B747DR_ap_approach_mode = 2, 0
    env.B747DR_ap_lnav_xtk_target, env.B747DR_ap_lnav_xtk_error = 0, 0
    env.B747DR_CAS_caution_status, env.simDR_override_fms_progress = {}, 1
    env.setVNAVState = function() end
    return env
end

-- A route north along 10 W: START, a fix 100 nm on, the next 100 nm further.
local function route_north(env, extra)
    local start = {50, -10}
    local fix = {env.movePoint(start[1], start[2], 100, 0)}
    local after = {env.movePoint(fix[1], fix[2], 100, 0)}
    local route = {entry("ORIG", 49, -10, 0, 1), entry("START", start[1], start[2]), entry("FIX", fix[1], fix[2]),
        entry("NEXT", after[1], after[2]), entry("DEST", 55, -10, 0, 1)}
    if extra then extra(route) end
    return route
end
-- The aircraft along_nm on the leg START -> FIX and right_nm to its right.
local function place(env, route, along_nm, right_nm, index)
    local lat, lon = env.movePoint(route[2][5], route[2][6], along_nm, 0)
    if right_nm ~= 0 then lat, lon = env.movePoint(lat, lon, math.abs(right_nm), right_nm > 0 and 90 or 270) end
    env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading, env.simDR_ground_track_true = lat, lon, 0, 0
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = index, index, index
    for i = 1, #route do route[i][10] = (i == index) end
end
local function near(value, expected, message)
    check(type(value) == "number" and math.abs(value - expected) < 0.02,
        string.format("%s: %s (expected %+.2f)", message, tostring(value), expected))
end

-- 1. Mid-leg, where the leg search does not run: the distance and its side.
for _, right in ipairs({1.2, -1.2, 0.3, -7}) do
    local env = new_runtime()
    local route = route_north(env)
    place(env, route, 40, right, 3)
    env.B747_getCurrentWayPoint(route)
    near(env.B747DR_ap_lnav_xtk_error, right, string.format("40 nm along the leg, %+.1f nm", right))
    check(env.B747DR_fmscurrentIndex == 3, "40 nm along the leg: FIX still active")
end

-- 2. In the last 5 nm, where the search runs: signed, not its smallest
-- unsigned distance.
local env = new_runtime()
local route = route_north(env)
place(env, route, 96, -0.4, 3)
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, -0.4, "4 nm before the fix, 0.4 nm left")

-- 3. Flying an offset (2 nm right): the error from the offset track.
env = new_runtime()
route = route_north(env)
place(env, route, 40, 1.5, 3)
env.B747DR_ap_lnav_xtk_target = 2
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, -0.5, "an offset 2 nm right, 1.5 nm right of the leg")
env.B747DR_ap_lnav_xtk_target = -100     -- a direct-to: no offset
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, 1.5, "after a direct-to (-100), 1.5 nm right")
-- the largest offset, L99 (-99), is one too (LNAV steers it: monitor.lua)
env = new_runtime()
route = route_north(env)
place(env, route, 40, -98.5, 3)
env.B747DR_ap_lnav_xtk_target = -99
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, 0.5, "an offset L99, 98.5 nm left of the leg")

-- 4. The leg after an altitude-terminated leg's end ("(650)") starts at the
-- fix before it.
env = new_runtime()
route = route_north(env, function(r)
    local lat, lon = env.movePoint(r[2][5], r[2][6], 2, 60)
    table.insert(r, 3, entry("(650)", lat, lon, 650, 2048))
end)
env.simDR_pressureAlt1 = 31000
place(env, route, 40, 1.0, 4)
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, 1.0, "after (650): from START to FIX, 1 nm right")

-- 5. After a direct-to the native FMS sequences (PPOS before the active fix):
-- the leg from PPOS.
env = new_runtime()
route = route_north(env, function(r) r[2][8] = "PPOS" end)
place(env, route, 40, -2.0, 3)
env.B747_getCurrentWayPoint(route)
near(env.B747DR_ap_lnav_xtk_error, -2.0, "native sequencing from PPOS, 2 nm left")

-- 6. No active leg: none.
env = new_runtime()
route = route_north(env)
place(env, route, 40, 1.2, 1)
env.B747DR_ap_lnav_xtk_error = 3.3
env.B747_getCurrentWayPoint(route)
check(env.B747DR_ap_lnav_xtk_error == 0, "the origin active: no cross-track, "..tostring(env.B747DR_ap_lnav_xtk_error))

-- 8. In a fly-by turn the cross-track is from the path LNAV flies (item i-1b), the arc: it was from the next
-- leg once the turn's anticipation had made it active, 2.7 nm right on the arc of a 90 deg turn at 478 kt.
-- START -> FIX 100 nm north, NEXT 100 nm east of FIX: the arc of R 9.16 nm (478 kt, 20 deg) centred 9.16 nm
-- east and south of FIX, its middle 3.79 nm from FIX on 135.
local function on_turn(outside_nm)
    local e = new_runtime()
    local start = {50, -10}
    local fix = {e.movePoint(start[1], start[2], 100, 0)}
    local after = {e.movePoint(fix[1], fix[2], 100, 90)}
    local r = {entry("ORIG", 49, -10, 0, 1), entry("START", start[1], start[2]), entry("FIX", fix[1], fix[2]),
        entry("NEXT", after[1], after[2]), entry("DEST", after[1] + 5, after[2], 0, 1)}
    local radius = 246 ^ 2 / (9.80665 * math.tan(math.rad(20))) / 1852
    local lat, lon = e.movePoint(fix[1], fix[2], radius * (math.sqrt(2) - 1) - outside_nm, 135)
    e.simDR_latitude, e.simDR_longitude, e.simDR_true_heading, e.simDR_ground_track_true = lat, lon, 45, 45
    e.B747DR_fmscurrentIndex, e.B747DR_fms_setCurrent, e.B747DR_ap_lnavHeading_mode = 4, 4, 4
    for i = 1, #r do r[i][10] = (i == 4) end
    e.B747_getCurrentWayPoint(r)
    check(e.B747DR_fmscurrentIndex == 4, "on the turn: NEXT active, "..e.B747DR_fmscurrentIndex)
    return e.B747DR_ap_lnav_xtk_error
end
near(on_turn(0), 0, "on the arc's middle, NEXT active: on the path")
near(on_turn(0.5), -0.5, "0.5 nm outside the arc's middle: 0.5 nm left of the path")
-- the arc is LNAV's path only within the anticipation's 2 nm of it: 3 nm outside it is the leg after the turn's
-- (FIX to NEXT, east), 0.79 nm from FIX on 135, right of it
near(on_turn(1.0), -1.0, "1 nm outside the arc's middle: still the arc's, 1 nm left")
local radius = 246 ^ 2 / (9.80665 * math.tan(math.rad(20))) / 1852
near(on_turn(3.0), math.sqrt(0.5) * (radius * (math.sqrt(2) - 1) - 3), "3 nm outside it: from the leg after the turn")

-- 9. [P14] While LNAV is not engaged the FMC sequences a fix only abeam it, so the 747 can be past its turn's
-- bisector with the fix still active: the cross-track is still from the leg to that fix, the active leg the PROGRESS
-- page and X-Plane's course show, not from the turn's path beyond the bisector (its arc or the leg after it; the
-- kit's rejoin took the next leg's side for the active leg's, its intercept heading pointed away and LNAV never
-- engaged: a review). The 90 deg turn of 8 at FIX, the 747 5 nm east of the leg to FIX and 3 nm before FIX. With
-- LNAV engaged FIX is sequenced at its bisector, and the cross-track is from its arc as in 8.
local function past_bisector(lnav_state)
    local e = new_runtime()
    local start = {50, -10}
    local fix = {e.movePoint(start[1], start[2], 100, 0)}
    local after = {e.movePoint(fix[1], fix[2], 100, 90)}
    local r = {entry("ORIG", 49, -10, 0, 1), entry("START", start[1], start[2]), entry("FIX", fix[1], fix[2]),
        entry("NEXT", after[1], after[2]), entry("DEST", after[1] + 5, after[2], 0, 1)}
    local lat, lon = e.movePoint(fix[1], fix[2], 3, 180)
    lat, lon = e.movePoint(lat, lon, 5, 90)
    e.simDR_latitude, e.simDR_longitude, e.simDR_true_heading, e.simDR_ground_track_true = lat, lon, 0, 0
    e.B747DR_ap_lnav_state = lnav_state
    e.B747DR_fmscurrentIndex, e.B747DR_fms_setCurrent, e.B747DR_ap_lnavHeading_mode = 3, 3, 3
    for i = 1, #r do r[i][10] = (i == 3) end
    e.B747_getCurrentWayPoint(r)
    return e.B747DR_fmscurrentIndex, e.B747DR_ap_lnav_xtk_error, e
end
for _, state in ipairs({0, 1}) do
    local index, xtk = past_bisector(state)
    check(index == 3, string.format("LNAV %s past FIX's bisector, before its wayline: FIX still active (%d)",
        state == 0 and "off" or "armed", index))
    near(xtk, 5.0, string.format("LNAV %s past FIX's bisector, FIX active: from the leg to FIX, 5 nm right",
        state == 0 and "off" or "armed"))
end
do
    local index, xtk = past_bisector(2)
    local radius = 246 ^ 2 / (9.80665 * math.tan(math.rad(20))) / 1852
    local centre_e, centre_n = radius, -radius
    local arc = radius - math.sqrt((5 - centre_e) ^ 2 + (-3 - centre_n) ^ 2)
    check(index == 4, "LNAV engaged past FIX's bisector: FIX sequenced ("..index..")")
    check(type(xtk) == "number" and math.abs(xtk - arc) < 0.05, string.format(
        "LNAV engaged past FIX's bisector: from FIX's arc, %.2f nm right (%s)", arc, tostring(xtk)))
end

-- 7. The PROGRESS page shows the side of the error and its size.
local page_env = setmetatable({
    print = function() end, fmsPages = {}, fmsFunctionsDefs = {PROGRESS = {}},
    createPage = function(name) return {name = name} end,
    simConfigData = {data = {SIM = {weight_display_units = "KGS", kgs_to_lbs = 2.205}}},
    is_timer_scheduled = function() return true end, run_after_time = function() end,
    simDR_onGround = 0, simDR_fueL_tank_weight_total_kg = 80000, B747DR_engine_used_fuel = {[0] = 1000, 1000, 1000, 1000, 4000},
    B747DR_ND_Wind_Bearing = 30, simDR_wind_speed = 40, B747DR_ND_Wind_Line = "270`/ 40", B747DR_TAS_pilot = 478,
    simDR_air_temp = -45, B747DR_ap_lnav_xtk_error = 0}, {__index = _G})
setfenv(assert(loadfile(FMS.."activepages/B744.fms.pages.progress.lua")), page_env)()
for _, case in ipairs({{1.24, "R 1.2"}, {-1.24, "L 1.2"}, {-12.3, "L 12.3"}}) do
    page_env.B747DR_ap_lnav_xtk_error = case[1]
    page_env.refreshPages()
    local line = page_env.fmsPages.PROGRESS:getPage(2, "fmsL")[5]
    check(line:sub(1, #case[2]) == case[2], string.format("PROGRESS 2 for %+.2f nm: [%s] starts with [%s]", case[1],
        line, case[2]))
end

print("LNAV cross-track error tests passed: "..checks)
