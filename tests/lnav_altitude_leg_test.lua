-- Run from the repository root with Lua 5.1 or LuaJIT.
-- LNAV sequencing at the end of an altitude-terminated leg (CA, VA, FA).
-- X-Plane names the end of such a leg after its altitude ("(650)" for the
-- first leg of EIDW's ENDE3J, 28R heading to 650 ft) and, as the 747 overrides
-- its sequencing, keeps that point about 0.05 NM ahead of the aircraft once
-- the altitude is reached. On the first SimBrief line flight (2026-10-10) the
-- active waypoint stayed "(650)" and the 747 flew the runway heading west over
-- Ireland, climbing through 10,000 ft. The production waypoint sequencing
-- (B747_getCurrentWayPoint_function) runs against mocked datarefs; this does
-- not validate flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
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

-- One xtlua/fms entry: [2] type (1 airport, 512 fix, 2048 lat/lon), [5]/[6]
-- position, [8] name, [9] altitude, [10] active.
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end

local function new_runtime(position, heading, altitude, index, on_ground)
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    for _, chunk in ipairs({
            slice("function B747_rescale(", "function getFMSData(name)"),
            slice("function getTriSpaceSolver(ab,ac,cb)", "local beganDescentAny"),
            slice("function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice("function movePoint(", "\nend\n").."\nend\n",
            slice("local LNAV_MAX_PREEMPT_XTK_NM", "function B747_getCurrentWayPoint_default(fmsO)")}) do
        setfenv(assert(loadstring(chunk)), env)()
    end
    env.simDR_latitude, env.simDR_longitude = position[1], position[2]
    env.simDR_true_heading, env.simDR_pressureAlt1 = heading, altitude
    env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = altitude - 242, 2500
    env.simDR_groundspeed, env.simDR_onGround = 90, on_ground and 1 or 0
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent = index, index
    env.B747DR_ap_lnav_state, env.B747DR_ap_lnavHeading_mode = 2, index
    env.B747DR_ap_approach_mode, env.B747DR_ap_lnav_xtk_target, env.B747DR_ap_lnav_xtk_error = 0, 0, 0
    env.B747DR_CAS_caution_status, env.simDR_override_fms_progress = {}, 1
    env.setVNAVState = function() end
    return env
end

-- EIDW 28R ENDE3J as the native route lists it: the runway, DE28R, the CA
-- leg's end, then DW128 to the north-west. The aircraft has passed DE28R on
-- the runway heading; X-Plane's "(650)" rides 0.05 NM ahead of it.
local function departure(env, end_name)
    local here_lat, here_lon = env.simDR_latitude, env.simDR_longitude
    local ahead_lat, ahead_lon = env.movePoint(here_lat, here_lon, 0.05, env.simDR_true_heading)
    local route = {
        entry("EIDW", 53.4213, -6.2703, 242, 1), entry("RW28R", 53.4352, -6.2450, 218),
        entry("DE28R", 53.4380, -6.2900), entry(end_name or "(650)", ahead_lat, ahead_lon, 650, 2048),
        entry("DW128", 53.4700, -6.3600), entry("DW129", 53.5300, -6.3500), entry("DW124", 53.5500, -6.0500),
        entry("ATGOW", 53.5100, -5.8000), entry("ENDEQ", 53.4457, -5.5000), entry("RULAV", 53.4373, -5.1670),
        entry("EHAM", 52.3175, 4.7716, -11, 1)
    }
    route[env.B747DR_fmscurrentIndex][10] = true
    return route
end

local WEST = {53.4410, -6.3420}         -- 3.4 NM past the threshold on 277 deg

-- 1. Above the leg's altitude the next leg is active (the native FMS gets it
-- through fms_setCurrent).
for _, case in ipairs({{"just above, 700 ft", 700}, {"10,700 ft, as the line flight", 10700}}) do
    local env = new_runtime(WEST, 277, case[2], 4)
    env.B747_getCurrentWayPoint_function(departure(env))
    check(env.B747DR_fmscurrentIndex == 5 and env.B747DR_fms_setCurrent == 5 and env.B747DR_ap_lnavHeading_mode == 5,
        string.format("(650) at %s: DW128 active (index %d, native %d, LNAV heading mode %d)", case[1],
            env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode))
end

-- 2. Below it the leg goes on, and on the ground nothing is sequenced.
local env = new_runtime(WEST, 277, 600, 4)
env.B747_getCurrentWayPoint_function(departure(env))
check(env.B747DR_fmscurrentIndex == 4, "(650) at 600 ft: still active, index "..env.B747DR_fmscurrentIndex)
env = new_runtime(WEST, 277, 700, 4, true)
env.simDR_vvi_fpm_pilot = 0
env.B747_getCurrentWayPoint_function(departure(env))
check(env.B747DR_fmscurrentIndex == 4, "(650) on the ground: still active, index "..env.B747DR_fmscurrentIndex)

-- 3. Only a name that is an altitude: other computed points ("(VECT)",
-- "(INTC)") end otherwise.
for _, name in ipairs({"(VECT)", "(INTC)"}) do
    env = new_runtime(WEST, 277, 10700, 4)
    env.B747_getCurrentWayPoint_function(departure(env, name))
    check(env.B747DR_fmscurrentIndex == 4, name.." at 10,700 ft: not ended by altitude, index "..env.B747DR_fmscurrentIndex)
end

-- 4. Flying the departure: 200 kt, turning at 2 deg/s toward the 747's active
-- fix, for 10 minutes. "(650)" lies where the climb reaches 650 ft and, while
-- it is the active leg's end above that, 0.05 NM ahead of the aircraft (as
-- seen in X-Plane). Whether X-Plane keeps it moving with the aircraft after
-- the 747 has passed it or leaves it there, and whether 650 ft comes before or
-- after DE28R, the legs after it are sequenced in order to ENDEQ: a leg ending
-- there no longer counts and is no leg in the one-leg advance limit, and the
-- leg after it is measured from DE28R. (From a point riding with the aircraft
-- DW128 was never passed and the aircraft circled it; with 650 ft reached
-- while DE28R was active the 747 stayed on DE28R and circled it - X-Plane,
-- the second line flight, 2026-10-10.)
local function fly_departure(behaviour, start, altitude, fpm, index)
    local env = new_runtime(start, 277, altitude, index)
    local route = departure(env)
    local lat, lon, heading = start[1], start[2], 277
    local reached, back = index, false
    for _ = 1, 2400 do
        local dt = 0.25
        if env.B747DR_fmscurrentIndex <= 4 or behaviour == "moving" then
            local ahead = math.max(0.05, (650 - altitude)/fpm*200/60)
            route[4][5], route[4][6] = env.movePoint(lat, lon, ahead, heading)
        end
        for i = 1, #route do route[i][10] = (i == env.B747DR_fmscurrentIndex) end
        env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading = lat, lon, heading
        env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = altitude, altitude - 242, fpm
        local before = env.B747DR_fmscurrentIndex
        env.B747_getCurrentWayPoint_function(route)
        if env.B747DR_fmscurrentIndex < before then back = true end
        reached = math.max(reached, env.B747DR_fmscurrentIndex)
        local active = route[env.B747DR_fmscurrentIndex]
        local turn = env.getHeadingDifference(heading, env.getHeading(lat, lon, active[5], active[6]))
        heading = (heading + math.max(-2*dt, math.min(2*dt, turn))) % 360
        lat, lon = env.movePoint(lat, lon, 200/3600*dt, heading)
        altitude = altitude + fpm/60*dt
    end
    return route[reached][8], reached, back
end
local DE28R = {53.4380, -6.2900}
local probe = new_runtime(DE28R, 277, 0, 3)
local BEFORE_DE28R = {probe.movePoint(DE28R[1], DE28R[2], 1.0, 97)}
local PAST_DE28R = {probe.movePoint(DE28R[1], DE28R[2], 2.0, 277)}
for _, case in ipairs({
        {"from DE28R at 300 ft, 2,000 fpm", DE28R, 300, 2000},
        {"650 ft reached 0.8 NM before DE28R (3,000 fpm)", BEFORE_DE28R, 560, 3000},
        {"DE28R still active 2 NM past it at 3,000 ft, as the second line flight", PAST_DE28R, 3000, 2000}}) do
    for _, behaviour in ipairs({"moving", "left behind"}) do
        local name, reached, back = fly_departure(behaviour, case[2], case[3], case[4], 3)
        check(reached >= 9 and not back, string.format("departure %s, the passed (650) %s: up to %s in order (back %s)",
            case[1], behaviour, name, tostring(back)))
    end
end

-- 5. The helper: the altitude of an altitude leg's end, its route altitude
-- first, else the one in its name; nil for any other entry.
check(afds.altitude_leg_end_ft(entry("(650)", 0, 0, 650, 2048)) == 650, "altitude_leg_end_ft (650) = 650")
check(afds.altitude_leg_end_ft(entry("(3000)", 0, 0, 0, 2048)) == 3000, "altitude_leg_end_ft (3000) with [9] 0 = 3000")
check(afds.altitude_leg_end_ft(entry("DW128", 0, 0, 650)) == nil, "altitude_leg_end_ft DW128 = nil")
check(afds.altitude_leg_end_ft(entry("(VECT)", 0, 0, 2000, 2048)) == nil, "altitude_leg_end_ft (VECT) = nil")
check(afds.altitude_leg_end_ft(nil) == nil, "altitude_leg_end_ft nil = nil")

print("LNAV altitude leg tests passed: "..checks)
