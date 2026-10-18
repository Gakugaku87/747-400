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

-- D4 [B-13]: with the A/T's own speed loop, which overshoots: SPD from the target - 5 kt went 3-4 kt past the target,
-- the levers came to idle and the thrust was released on a path idle could not hold the speed on, which slowed it to
-- SPD again (p21-line1: SPD, IDLE, HOLD, SPD on the path). Released only with the levers at idle and the speed not
-- falling. The A/T: a PI loop on the speed (0.05 per kt, 0.004 per kt s), its thrust 4 s behind, 1 kt/s at full; the
-- energy mode's latches (2 s to SPD, 5 s to IDLE) as vnav.lua's; 600 s.
local function descend_at(idle_kt_s, speed, policy, reason, with_idle)
    local target, dt = 270, 0.5
    local prev = {path = 0, speed = 0, policy = policy, reason = reason}
    local latched, pending, since = policy, nil, 0
    local cmd, thrust, integral, trend, changes = 0, 0, 0, 0, 0
    for k = 1, math.floor(600 / dt) do
        local t = k * dt
        local input = {path_error_ft = 0, path_trend_fpm = 0, target_speed_kts = target, actual_speed_kts = speed,
            speed_trend_kts_per_sec = trend, nominal_vspeed_fpm = -2000, min_safe_speed_kts = 200,
            previous_path_axis = prev.path, previous_speed_axis = prev.speed,
            previous_thrust_policy = latched, previous_thrust_reason = prev.reason}
        if with_idle then input.thrust_at_idle = cmd <= 0.001 end
        local g = nav.vnav_energy_guidance(input)
        if g.thrust_policy == latched then
            pending = nil
        elseif pending ~= g.thrust_policy then
            pending, since = g.thrust_policy, t
        elseif t - since >= (latched == ALLOW and 5 or 2) then
            latched, pending, changes = g.thrust_policy, nil, changes + 1
        end
        if latched == ALLOW then
            local err = target - speed
            integral = math.max(-50, math.min(250, integral + err * dt))
            cmd = math.max(0, math.min(1, 0.05 * err + 0.004 * integral))
        else
            cmd, integral = 0, 0
        end
        thrust = thrust + (cmd - thrust) * dt / 4
        local accel = idle_kt_s + thrust
        speed, trend = speed + accel * dt, trend * 0.7 + accel * 0.3
        prev = {path = g.path_axis, speed = g.speed_axis, reason = g.thrust_reason}
    end
    return changes, latched, speed
end
local c_old = descend_at(-0.15, 270, IDLE, NONE, false)
local c_new, p_new, s_new = descend_at(-0.15, 270, IDLE, NONE, true)
check(c_old >= 3 and c_new <= 1 and p_new == ALLOW and math.abs(s_new - 270) <= 3, string.format(
    "D4 shallow path, the A/T's own loop: %d policy changes in 600 s (%d released at +2 kt alone), ends %s at %.1f kt",
    c_new, c_old, p_new == ALLOW and "in SPD" or "at IDLE", s_new))
local c_steep, p_steep = descend_at(0.15, 263, ALLOW, ON_PATH_BELOW, true)
check(c_steep == 1 and p_steep == IDLE, string.format(
    "D4 steep path, the A/T's own loop: thrust released once (%d changes), ends %s", c_steep,
    p_steep == IDLE and "at IDLE" or "in SPD"))
check(step({actual_speed_kts = 273, previous_speed_axis = 1, thrust_at_idle = false}).thrust_policy == ALLOW,
    "D4 3 kt fast with the levers above idle: still SPD")
check(step({actual_speed_kts = 273, previous_speed_axis = 1, thrust_at_idle = true,
    speed_trend_kts_per_sec = -0.1}).thrust_policy == ALLOW, "D4 3 kt fast at idle, slowing: still SPD")
check(step({actual_speed_kts = 273, previous_speed_axis = 1, thrust_at_idle = true,
    speed_trend_kts_per_sec = 0.05}).thrust_policy == IDLE, "D4 3 kt fast at idle, not slowing: IDLE")

-- D5 [B-13]: the production vnav.lua (its trends, latches and release) with the A/T's own speed loop (the EEC's
-- spd_throttle, a frame of 0.02 s) and engines fitted to p23-line1's descent at FL260-300: N1 = idle + (96 - idle) x
-- lever^0.3 (76-78 at 0.22-0.24, 84 at 0.41, still 73.8 at 0.095 on the way down), up 1.5 s, down 35 s (with the
-- levers at idle 76 to 46 in 38 s, 72 to 49 in 37 s, 67 to 50 in 28 s towards 36: 27-38 s), shown to 0.1 %. With the
-- levers at idle the speed went on rising for 7-18 s while the engines spooled down; released then, the thrust ended
-- on a path idle could not hold the speed on (p23-line1: 36 A/T changes in the descent). Released only once the
-- engines have spooled down to idle.
local function load_in_environment(path, environment)
    local chunk, load_error = loadfile(path)
    assert(chunk ~= nil, load_error)
    setfenv(chunk, environment)
    chunk()
end
local runtime = setmetatable({}, {__index = _G})
load_in_environment("plugins/xtlua_keysystems/init.lua", runtime)
runtime.XLuaGetCode = function(requested_path)
    local resolved_path = requested_path
    if not string.find(requested_path, "/", 1, true) then resolved_path = AP..requested_path end
    local chunk, load_error = loadfile(resolved_path)
    assert(chunk ~= nil, load_error)
    return chunk
end
local function load_vnav()
    local vnav = setmetatable({}, {__index = _G})
    vnav.dofile = runtime.get_run_file_in_namespace(vnav)
    vnav.dofile(AP.."B747.70.xt.autopilot.vnav.lua")
    local sim = {
        simDRTime = 100, B747BR_totalDistance = 10, B747BR_fpe = 0, B747BR_vnavProfile = "",
        B747DR_fmstargetDistance = 50, B747DR_ap_vnav_target_alt = 10000,
        simDR_pressureAlt1 = 28000, simDR_autopilot_altitude_ft = 3000,
        simDR_groundspeed = 230, simDR_radarAlt1 = 28000,
        B747DR_ap_inVNAVdescent = 2, B747DR_ap_vnav_state = 2,
        B747DR_ap_FMA_active_pitch_mode = 6, simDR_autopilot_vs_status = 2,
        simDR_autopilot_flch_status = 0, simDR_autopilot_alt_hold_status = 0,
        B747DR_autopilot_gs_status = 0, simDR_autopilot_gs_status = 0,
        B747DR_ap_approach_mode = 0, simDR_autopilot_approach_status = 0,
        B747DR_ap_autoland = 0, B747DR_ap_active_land = 0, B747DR_alt_capture_window = 1000,
        -- a Mach target (setDescentVSpeed's deceleratedDesent wants the FMC's speed transition without one)
        simDR_autopilot_airspeed_is_mach = 1, simDR_autopilot_airspeed_kts = 270,
        simDR_ind_airspeed_kts_pilot = 270, simDR_vvi_fpm_pilot = -1500,
        simDR_autopilot_vs_fpm = -1500, B747DR_airspeed_Vmc = 150, B747DR_speedbrake_lever = 0,
        simDR_allThrottle = 0, B747DR_display_N1 = {[0] = 38, 38, 38, 38}}
    for key, value in pairs(sim) do vnav[key] = value end
    vnav.B747_reset_vnav_energy()
    return vnav
end
local IDLE_N1 = 38
local function n1_target(lever)
    if lever <= 0 then return IDLE_N1 end
    return IDLE_N1 + (96 - IDLE_N1) * lever ^ 0.3
end
-- The descent for `seconds` on the path from `speed` kt (target 270), the speed changing by idle_kt_s at idle and by
-- 0.65 kt/s more at N1 77; the A/T in SPD while VNAV allows thrust (the EEC's spd_throttle, its levers at 0.5 a
-- second), else its levers to idle at 1 a second. Returns VNAV's thrust policy changes, the last policy, the speed
-- and its extremes after 120 s.
local function descend_xp(idle_kt_s, speed, seconds, down_s, start_spd)
    local vnav = load_vnav()
    local dt, target = 0.02, 270
    local lever, thr, n1 = 0, 0, IDLE_N1
    local lastSample, lastIas, sd, lastSpd = 0, speed, 0, -10
    local changes, policy, hi, lo = 0, nil, -1e9, 1e9
    if start_spd then lever, thr, n1 = 0.24, 0.24, n1_target(0.24) end
    for k = 1, math.floor(seconds / dt) do
        local t = k * dt
        vnav.simDR_ind_airspeed_kts_pilot, vnav.simDR_allThrottle = speed, lever
        local shown = math.floor(n1 * 10 + 0.5) / 10
        vnav.B747DR_display_N1 = {[0] = shown, shown, shown, shown}
        vnav.setDescentVSpeed({})
        local p = vnav.B747DR_vnav_energy_thrust_policy
        if policy ~= nil and p ~= policy then changes = changes + 1 end
        policy = p
        if p == ALLOW or (start_spd and t < 1) then
            if t - lastSpd > 1 then thr = lever end
            lastSpd = t
            if t - lastSample > 0.1 then sd, lastSample, lastIas = speed - lastIas, t, speed end
            local err = math.abs(speed - target)
            local rog = math.min(0.005, math.max(0.0001 + 0.0001 * err, 0.0001 + 0.005 * math.abs(sd)))
            local maxsd, minsd = 0, 0
            if err > 1 then maxsd = 0.001 + err / 100; minsd = maxsd / 5 end
            if (target > speed + 0.5 and sd < minsd) or (target < speed - 0.5 and sd < -maxsd) then
                thr = thr + rog
            elseif (target < speed - 0.5 and sd > -minsd) or (target > speed + 0.5 and sd > maxsd) then
                thr = thr - rog
            end
            thr = math.max(0, math.min(1, thr))
            local step = 0.5 * dt
            if math.abs(thr - lever) <= step then lever = lever + (thr - lever) * 0.1
            elseif thr > lever then lever = lever + step else lever = lever - step end
        else
            lever = math.max(0, lever - dt)
            if lever < 1e-4 then lever = 0 end
        end
        local goal = n1_target(lever)
        n1 = n1 + (goal - n1) * dt / (goal > n1 and 1.5 or down_s)
        speed = speed + (idle_kt_s + 0.65 * (n1 - IDLE_N1) / (77 - IDLE_N1)) * dt
        if t > 120 then hi, lo = math.max(hi, speed - target), math.min(lo, speed - target) end
        vnav.simDRTime = vnav.simDRTime + dt
    end
    return changes, policy, speed, hi, lo
end
for _, idle in ipairs({-0.15, -0.35, -0.55}) do
    local c, p, s, hi, lo = descend_xp(idle, 270, 900, 35)
    check(c <= 1 and p == ALLOW, string.format(
        "D5 path %.2f kt/s at idle, X-Plane's spool-down: %d thrust policy changes in 900 s (at most 1, to SPD), ends %s"
        .. " at %.1f kt (%+.1f to %+.1f after 120 s)", idle, c, p == ALLOW and "SPD" or "IDLE", s, lo, hi))
end
local c5, p5 = descend_xp(0.1, 263, 300, 35, true)
check(c5 == 1 and p5 == IDLE, string.format(
    "D5 steep path (+0.10 kt/s at idle) from 7 kt slow in SPD: thrust released once (%d changes), ends %s", c5,
    p5 == IDLE and "at IDLE" or "in SPD"))

print("VNAV descent thrust hold tests passed: "..checks)
