-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV PTH descent: thrust allowed for a speed below the target on or below
-- the path (A/T SPD) is kept while the speed stays below the target + 2 kt and
-- the aircraft is not above the path. Released as soon as the speed was back
-- within 2 kt of the target, the A/T went to IDLE on a path that needed some
-- thrust, slowed again and went back to SPD every 15-35 s through the descents
-- (p20-line1: about 40 times, p20-L1: about 30). A real 747-400's A/T in SPD
-- holds the speed with the thrust it needs. On a path steep enough at idle the
-- speed goes past the target and the thrust ends.
-- Logic only (the pure helper in a closed loop with a point-mass speed); this
-- does not validate flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local nav = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local IDLE = nav.VNAV_ENERGY_THRUST_IDLE
local ALLOW = nav.VNAV_ENERGY_THRUST_ALLOW
local NONE = nav.VNAV_ENERGY_THRUST_REASON_NONE
local ON_PATH_BELOW = nav.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED

-- On the path for `seconds` from `speed` kt (target 270), the speed changing by idle_kt_s at idle; in SPD the A/T
-- holds the target, adding up to 0.8 kt/s. Returns the policy changes, the last guidance and the speed.
local function descend(idle_kt_s, seconds, speed, policy, reason)
    local target, dt = 270, 0.5
    local prev = {path = 0, speed = 0, policy = policy or IDLE, reason = reason or NONE}
    local trend, changes, last = 0, 0, nil
    for _ = 1, math.floor(seconds / dt) do
        local g = nav.vnav_energy_guidance({
            path_error_ft = 0, path_trend_fpm = 0, target_speed_kts = target, actual_speed_kts = speed,
            speed_trend_kts_per_sec = trend, nominal_vspeed_fpm = -2000, min_safe_speed_kts = 200,
            previous_path_axis = prev.path, previous_speed_axis = prev.speed,
            previous_thrust_policy = prev.policy, previous_thrust_reason = prev.reason})
        if g.thrust_policy ~= prev.policy then changes = changes + 1 end
        local accel = idle_kt_s
        if g.thrust_policy == ALLOW then
            accel = math.max(idle_kt_s, math.min(idle_kt_s + 0.8, 0.3 * (target - speed)))
        end
        speed, trend = speed + accel * dt, accel
        prev = {path = g.path_axis, speed = g.speed_axis, policy = g.thrust_policy, reason = g.thrust_reason}
        last = g
    end
    return changes, last, speed
end

-- D1: a path idle cannot hold the speed on (0.25 kt/s slower at idle): SPD once and kept, the speed on the target.
local changes, last, speed = descend(-0.25, 300, 270)
check(changes <= 1 and last.thrust_policy == ALLOW, string.format(
    "D1 shallow path: the A/T changed %d times in 300 s (at most 1, to SPD) and ends %s", changes,
    last.thrust_policy == ALLOW and "in SPD" or "at IDLE"))
check(math.abs(speed - 270) <= 2, string.format("D1 shallow path: the speed held at %.1f kt (270 +- 2)", speed))

-- D2: a path steep enough at idle (0.2 kt/s faster): SPD from 7 kt slow ends once the speed is past the target.
changes, last, speed = descend(0.2, 120, 263, ALLOW, ON_PATH_BELOW)
check(last.thrust_policy == IDLE and changes == 1, string.format(
    "D2 steep path: thrust released once (%d changes) and ends %s at %.1f kt", changes,
    last.thrust_policy == IDLE and "at IDLE" or "in SPD", speed))

-- D3: the hold itself, one sample each: on speed after thrust for a slow speed stays SPD; 2.5 kt fast, or above the
-- path, it ends.
local function step(changes_in)
    local input = {path_error_ft = 0, path_trend_fpm = 0, target_speed_kts = 270, actual_speed_kts = 269,
        speed_trend_kts_per_sec = 0.3, nominal_vspeed_fpm = -2000, min_safe_speed_kts = 200,
        previous_path_axis = 0, previous_speed_axis = -1, previous_thrust_policy = ALLOW,
        previous_thrust_reason = ON_PATH_BELOW}
    for k, v in pairs(changes_in or {}) do input[k] = v end
    return nav.vnav_energy_guidance(input)
end
check(step().thrust_policy == ALLOW, "D3 back within 2 kt of the target after thrust for a slow speed: still SPD")
check(step({actual_speed_kts = 272.5, previous_speed_axis = 0}).thrust_policy == IDLE,
    "D3 2.5 kt above the target: IDLE")
check(step({path_error_ft = 400, previous_path_axis = 1}).thrust_policy == IDLE,
    "D3 above the path: the hold ends")
check(step({previous_thrust_policy = IDLE, previous_thrust_reason = NONE}).thrust_policy == IDLE,
    "D3 an idle descent 1 kt slow does not start thrust")

print("VNAV descent thrust hold tests passed: "..checks)
