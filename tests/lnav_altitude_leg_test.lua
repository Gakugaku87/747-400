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

local FIELD_FT = 242        -- EIDW
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
    env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = altitude - FIELD_FT, 2500
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
local ENDE3J = {
    entry("DW128", 53.4700, -6.3600), entry("DW129", 53.5300, -6.3500), entry("DW124", 53.5500, -6.0500),
    entry("ATGOW", 53.5100, -5.8000), entry("ENDEQ", 53.4457, -5.5000), entry("RULAV", 53.4373, -5.1670)}
local function departure(env, end_name, after)
    local here_lat, here_lon = env.simDR_latitude, env.simDR_longitude
    local ahead_lat, ahead_lon = env.movePoint(here_lat, here_lon, 0.05, env.simDR_true_heading)
    local route = {
        entry("EIDW", 53.4213, -6.2703, 242, 1), entry("RW28R", 53.4352, -6.2450, 218),
        entry("DE28R", 53.4380, -6.2900), entry(end_name or "(650)", ahead_lat, ahead_lon, 650, 2048)}
    for _, fix in ipairs(after or ENDE3J) do route[#route + 1] = {unpack(fix)} end
    route[#route + 1] = entry("EHAM", 52.3175, 4.7716, -11, 1)
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

-- 2. Below it the leg goes on; on the ground, and below 400 ft above it (a
-- misset altimeter reading 700 ft at 300 ft), nothing is sequenced.
local env = new_runtime(WEST, 277, 600, 4)
env.B747_getCurrentWayPoint_function(departure(env))
check(env.B747DR_fmscurrentIndex == 4, "(650) at 600 ft: still active, index "..env.B747DR_fmscurrentIndex)
env = new_runtime(WEST, 277, 700, 4, true)
env.simDR_vvi_fpm_pilot = 0
env.B747_getCurrentWayPoint_function(departure(env))
check(env.B747DR_fmscurrentIndex == 4, "(650) on the ground: still active, index "..env.B747DR_fmscurrentIndex)
env = new_runtime(WEST, 277, 700, 4)
env.simDR_radarAlt1 = 300
env.B747_getCurrentWayPoint_function(departure(env))
check(env.B747DR_fmscurrentIndex == 4, "(650) at 700 ft on the altimeter, 300 ft above the ground: still active, index "
    ..env.B747DR_fmscurrentIndex)

-- 3. Only a name that is an altitude: other computed points ("(VECT)",
-- "(INTC)") end otherwise.
for _, name in ipairs({"(VECT)", "(INTC)"}) do
    env = new_runtime(WEST, 277, 10700, 4)
    env.B747_getCurrentWayPoint_function(departure(env, name))
    check(env.B747DR_fmscurrentIndex == 4, name.." at 10,700 ft: not ended by altitude, index "..env.B747DR_fmscurrentIndex)
end

-- 4. Flying the departure: 200 kt, turning at 2 deg/s toward the 747's active
-- fix, for 10 minutes. Each altitude leg's end lies where the climb reaches its
-- altitude and, while it is the active leg's end above that, 0.05 NM ahead of
-- the aircraft (as seen in X-Plane). Whether X-Plane keeps it moving with the
-- aircraft after the 747 has passed it or leaves it there, and whether 650 ft
-- comes before or after DE28R, the legs are sequenced in order to the last fix
-- but one: a leg ending at a reached altitude leg's end no longer counts and is
-- no leg in the one-leg advance limit, the leg after it is measured from the
-- fix before it, and the fix before it, once passed with the altitude reached,
-- leads straight to the fix after it. (From a point riding with the aircraft
-- DW128 was never passed and the aircraft circled it; with 650 ft reached while
-- DE28R was active the 747 stayed on DE28R and circled it - the second line
-- flight, 2026-10-10 - as it does when the fix after the altitude leg lies
-- behind.)
local function fly_departure(behaviour, start, altitude, fpm, index, ends, after)
    local env = new_runtime(start, 277, altitude, index)
    local route = departure(env, nil, after)
    if #ends > 1 then
        for k = 2, #ends do table.insert(route, 3 + k, entry(ends[k][1], 0, 0, ends[k][2], 2048)) end
    end
    route[4][8], route[4][9] = ends[1][1], ends[1][2]
    local lat, lon, heading = start[1], start[2], 277
    local reached, back = index, false
    for _ = 1, 2400 do
        local dt = 0.25
        for k = 1, #ends do
            local i = 3 + k
            if env.B747DR_fmscurrentIndex <= i or behaviour == "moving" then
                local ahead = math.max(0.05, (ends[k][2] - altitude)/fpm*200/60)
                route[i][5], route[i][6] = env.movePoint(lat, lon, ahead, heading)
            end
        end
        for i = 1, #route do route[i][10] = (i == env.B747DR_fmscurrentIndex) end
        env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading = lat, lon, heading
        env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = altitude, altitude - FIELD_FT, fpm
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
    return route[reached][8], reached, back, #route - 2
end
local DE28R = {53.4380, -6.2900}
local probe = new_runtime(DE28R, 277, 0, 3)
local BEFORE_DE28R = {probe.movePoint(DE28R[1], DE28R[2], 1.0, 97)}
local PAST_DE28R = {probe.movePoint(DE28R[1], DE28R[2], 2.0, 277)}
-- a SID turning back after its CA leg (a quarter of SID runway transitions with
-- a fix before the altitude leg turn more than 120 deg to the next fix)
local function behind(bearing, nm, name) local lat, lon = probe.movePoint(DE28R[1], DE28R[2], nm, bearing)
    return entry(name, lat, lon) end
local TURN_BACK = {behind(120, 3, "BACK1"), behind(100, 8, "BACK2"), behind(95, 14, "BACK3"), behind(92, 20, "BACK4")}
local ONE, TWO = {{"(650)", 650}}, {{"(650)", 650}, {"(1500)", 1500}}
for _, case in ipairs({
        {"from DE28R at 300 ft, 2,000 fpm", DE28R, 300, 2000, ONE, ENDE3J},
        {"650 ft reached 0.8 NM before DE28R (3,000 fpm)", BEFORE_DE28R, 560, 3000, ONE, ENDE3J},
        {"DE28R still active 2 NM past it at 3,000 ft, as the second line flight", PAST_DE28R, 3000, 2000, ONE, ENDE3J},
        {"turning back after the CA leg, 650 ft before DE28R", BEFORE_DE28R, 560, 3000, ONE, TURN_BACK},
        {"turning back after the CA leg, from DE28R at 300 ft", DE28R, 300, 2000, ONE, TURN_BACK},
        {"two altitude legs in a row, (650) and (1500)", DE28R, 300, 2000, TWO, ENDE3J}}) do
    for _, behaviour in ipairs({"moving", "left behind"}) do
        local name, reached, back, last = fly_departure(behaviour, case[2], case[3], case[4], 3, case[5], case[6])
        check(reached >= last and not back, string.format("departure %s, the passed point %s: up to %s in order (back %s)",
            case[1], behaviour, name, tostring(back)))
    end
end

-- 5. The arrival: EHAM ILS 18R with its missed approach (500) after RW18R. On
-- final above 500 ft the runway stays active; on a go-around past the
-- threshold through 500 ft the next leg is AM624.
local function arrival(index)
    local route = {
        entry("EIDW", 53.4213, -6.2703, 242, 1), entry("AM621", 52.4627, 4.7211, 2000), entry("AM622", 52.4267, 4.7178, 1310),
        entry("RW18R", 52.3603, 4.7117, 37), entry("(500)", 52.3457, 4.7102, 500, 2048), entry("AM624", 52.3527, 4.5487, 2000),
        entry("(VECT)", 57.0, -12.0, 2000, 2048), entry("EHAM", 52.3175, 4.7716, -11, 1)}
    route[index][10] = true
    return route
end
local FINAL = {probe.movePoint(52.3603, 4.7117, 2.0, 3)}           -- 2 NM before RW18R on 183 deg
env = new_runtime(FINAL, 183, 690, 4)
env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 680, -700
env.B747_getCurrentWayPoint_function(arrival(4))
check(env.B747DR_fmscurrentIndex == 4, "final, RW18R active at 690 ft 2 NM out: RW18R stays, index "..env.B747DR_fmscurrentIndex)
local PAST_THRESHOLD = {probe.movePoint(52.3603, 4.7117, 0.5, 183)}
env = new_runtime(PAST_THRESHOLD, 183, 600, 4)
env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 610, 2000
env.B747_getCurrentWayPoint_function(arrival(4))
check(env.B747DR_fmscurrentIndex == 6, "go-around 0.5 NM past RW18R at 600 ft: AM624 active, index "
    ..env.B747DR_fmscurrentIndex)

-- 6. The helper: the altitude of an altitude leg's end, its route altitude
-- first, else the one in its name; nil for any other entry.
check(afds.altitude_leg_end_ft(entry("(650)", 0, 0, 650, 2048)) == 650, "altitude_leg_end_ft (650) = 650")
check(afds.altitude_leg_end_ft(entry("(3000)", 0, 0, 0, 2048)) == 3000, "altitude_leg_end_ft (3000) with [9] 0 = 3000")
check(afds.altitude_leg_end_ft(entry("DW128", 0, 0, 650)) == nil, "altitude_leg_end_ft DW128 = nil")
check(afds.altitude_leg_end_ft(entry("(VECT)", 0, 0, 2000, 2048)) == nil, "altitude_leg_end_ft (VECT) = nil")
check(afds.altitude_leg_end_ft(nil) == nil, "altitude_leg_end_ft nil = nil")

print("LNAV altitude leg tests passed: "..checks)
