-- Pure AFDS calculations shared by the autopilot implementation and tests.
-- Keep this file compatible with the Lua 5.1 runtime embedded in xtlua.

local afds = {}

local KNOT_TO_MPS = 0.514444
local METERS_PER_NM = 1852.0
local GRAVITY_MPS2 = 9.80665

afds.VNAV_ENERGY_PATH_ENTER_FT = 150
afds.VNAV_ENERGY_PATH_EXIT_FT = 75
afds.VNAV_ENERGY_SPEED_ENTER_KTS = 5
afds.VNAV_ENERGY_SPEED_EXIT_KTS = 2
afds.VNAV_ENERGY_MAX_DESCENT_FPM = -3500
afds.VNAV_ENERGY_MIN_DESCENT_FPM = 0
afds.VNAV_ENERGY_DESCENT_RATE_LIMIT_FPM_PER_SEC = 400
afds.VNAV_ENERGY_SHALLOW_RATE_LIMIT_FPM_PER_SEC = 600
afds.VNAV_ENERGY_PROTECTION_MARGIN_KTS = 15
afds.VNAV_ENERGY_PROTECTION_RELEASE_KTS = 5
afds.VNAV_ENERGY_DRAG_PATH_ERROR_FT = 1000

afds.VNAV_ENERGY_STATE_INACTIVE = 0
afds.VNAV_ENERGY_STATE_ABOVE_ABOVE = 1
afds.VNAV_ENERGY_STATE_ABOVE_BELOW = 2
afds.VNAV_ENERGY_STATE_BELOW_BELOW = 3
afds.VNAV_ENERGY_STATE_BELOW_ABOVE = 4
afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED = 5
afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED = 6
afds.VNAV_ENERGY_STATE_ON_PATH_BELOW = 7
afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE = 8
afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED = 9

afds.VNAV_ENERGY_THRUST_NORMAL = 0
afds.VNAV_ENERGY_THRUST_IDLE = 1
afds.VNAV_ENERGY_THRUST_ALLOW = 2

afds.VNAV_ENERGY_THRUST_REASON_NONE = 0
afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION = 1
afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED = 2
afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED = 3
afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED = 4

function afds.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if type(speed_kts) ~= "number" or speed_kts <= 0 then return nil end
    if type(bank_angle_deg) ~= "number" or bank_angle_deg <= 0 or bank_angle_deg >= 89 then return nil end

    local speed_mps = speed_kts * KNOT_TO_MPS
    local radius_m = (speed_mps * speed_mps) / (GRAVITY_MPS2 * math.tan(math.rad(bank_angle_deg)))
    if radius_m <= 0 or radius_m ~= radius_m then return nil end
    return radius_m / METERS_PER_NM
end

function afds.turn_anticipation_nm(speed_kts, bank_angle_deg, turn_angle_deg, minimum_nm, maximum_nm)
    if type(turn_angle_deg) ~= "number" or turn_angle_deg < 0 or turn_angle_deg > 180 then return nil, nil end

    local radius_nm = afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if radius_nm == nil then return nil, nil end
    if turn_angle_deg <= 1 then return 0, radius_nm end
    if turn_angle_deg >= 175 then return nil, radius_nm end

    local anticipation_nm = radius_nm * math.tan(math.rad(turn_angle_deg * 0.5))
    if anticipation_nm ~= anticipation_nm or anticipation_nm < 0 then return nil, radius_nm end
    return afds.clamp(anticipation_nm, minimum_nm or 0, maximum_nm or anticipation_nm), radius_nm
end

function afds.signed_cross_track_nm(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon,
        aircraft_lat, aircraft_lon, distance_func, heading_func)
    if type(distance_func) ~= "function" or type(heading_func) ~= "function" then return nil end
    if type(leg_start_lat) ~= "number" or type(leg_start_lon) ~= "number"
        or type(leg_end_lat) ~= "number" or type(leg_end_lon) ~= "number"
        or type(aircraft_lat) ~= "number" or type(aircraft_lon) ~= "number" then
        return nil
    end

    local distance_nm = distance_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    local leg_heading = heading_func(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon)
    local aircraft_heading = heading_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    if type(distance_nm) ~= "number" or type(leg_heading) ~= "number" or type(aircraft_heading) ~= "number" then
        return nil
    end

    local earth_radius_nm = 3440.065
    local angular_distance = distance_nm / earth_radius_nm
    local cross_track = math.asin(math.sin(angular_distance)
        * math.sin(math.rad(aircraft_heading - leg_heading))) * earth_radius_nm
    if cross_track ~= cross_track then return nil end
    return cross_track
end

function afds.flap_speed_bucket(flap_ratio)
    if type(flap_ratio) ~= "number" or flap_ratio <= 0 then return 0 end
    if flap_ratio <= 0.168 then return 1 end
    if flap_ratio <= 0.34 then return 5 end
    if flap_ratio <= 0.5 then return 10 end
    if flap_ratio <= 0.668 then return 20 end
    if flap_ratio <= 0.84 then return 25 end
    return 30
end

function afds.climb_speed_key_for_state(state)
    if state == "aptres" then return "clbrestspd" end
    if state == "spcres" then return "transpd" end
    if state == "nores" then return "clbspd" end
    return nil
end

function afds.climb_speed_for_state(state, data_source)
    local key = afds.climb_speed_key_for_state(state)
    if key == nil then return nil end
    if type(data_source) == "function" then return tonumber(data_source(key)) end
    if type(data_source) == "table" then return tonumber(data_source[key]) end
    return nil
end

function afds.first_changed_value(previous, current, watched_values)
    if previous == nil or current == nil then return nil end
    for i = 1, #watched_values do
        local item = watched_values[i]
        if previous[item.key] ~= current[item.key] then
            return item.reason or item.key
        end
    end
    return nil
end

function afds.vnav_speed_change_reason(previous, current, conditions, watched_values)
    if previous == nil or current == nil then return nil end

    if conditions ~= nil and type(conditions.above) == "number" and conditions.above > 0
        and previous.pressure_alt_ft <= conditions.above and current.pressure_alt_ft > conditions.above then
        return conditions.above_reason or "crossed upper speed boundary"
    end
    if conditions ~= nil and type(conditions.below) == "number" and conditions.below > 0
        and previous.pressure_alt_ft >= conditions.below and current.pressure_alt_ft < conditions.below then
        return conditions.below_reason or "crossed lower speed boundary"
    end

    return afds.first_changed_value(previous, current, watched_values)
end

function afds.should_schedule_ias_update(timer_is_scheduled)
    return timer_is_scheduled ~= true
end

local function hysteresis_axis(value, previous_axis, enter_threshold, exit_threshold)
    value = tonumber(value) or 0
    previous_axis = tonumber(previous_axis) or 0

    if previous_axis > 0 and value >= exit_threshold then return 1 end
    if previous_axis < 0 and value <= -exit_threshold then return -1 end
    if value >= enter_threshold then return 1 end
    if value <= -enter_threshold then return -1 end
    return 0
end

function afds.vnav_energy_axes(path_error_ft, speed_error_kts, previous_path_axis, previous_speed_axis)
    return hysteresis_axis(path_error_ft, previous_path_axis,
            afds.VNAV_ENERGY_PATH_ENTER_FT, afds.VNAV_ENERGY_PATH_EXIT_FT),
        hysteresis_axis(speed_error_kts, previous_speed_axis,
            afds.VNAV_ENERGY_SPEED_ENTER_KTS, afds.VNAV_ENERGY_SPEED_EXIT_KTS)
end

function afds.vnav_energy_state(path_axis, speed_axis)
    if path_axis > 0 and speed_axis > 0 then return afds.VNAV_ENERGY_STATE_ABOVE_ABOVE end
    if path_axis > 0 and speed_axis < 0 then return afds.VNAV_ENERGY_STATE_ABOVE_BELOW end
    if path_axis < 0 and speed_axis < 0 then return afds.VNAV_ENERGY_STATE_BELOW_BELOW end
    if path_axis < 0 and speed_axis > 0 then return afds.VNAV_ENERGY_STATE_BELOW_ABOVE end
    if path_axis > 0 then return afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED end
    if path_axis < 0 then return afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED end
    if speed_axis < 0 then return afds.VNAV_ENERGY_STATE_ON_PATH_BELOW end
    if speed_axis > 0 then return afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE end
    return afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED
end

function afds.vnav_energy_state_name(state)
    local names = {
        [afds.VNAV_ENERGY_STATE_INACTIVE] = "INACTIVE",
        [afds.VNAV_ENERGY_STATE_ABOVE_ABOVE] = "ABOVE_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ABOVE_BELOW] = "ABOVE_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_BELOW] = "BELOW_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_ABOVE] = "BELOW_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED] = "ABOVE_PATH_ON_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED] = "BELOW_PATH_ON_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_BELOW] = "ON_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE] = "ON_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED] = "ON_PATH_ON_SPEED"
    }
    return names[state] or "UNKNOWN"
end

function afds.vnav_energy_thrust_reason_name(reason)
    local names = {
        [afds.VNAV_ENERGY_THRUST_REASON_NONE] = "none",
        [afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION] = "underspeed protection",
        [afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED] = "below path and below speed",
        [afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED] = "path recovery limited",
        [afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED] = "on path and below speed"
    }
    return names[reason] or "unknown"
end

function afds.rate_limit(current_value, target_value, elapsed_sec, decreasing_rate_per_sec,
        increasing_rate_per_sec)
    if type(target_value) ~= "number" then return current_value end
    if type(current_value) ~= "number" then return target_value end
    elapsed_sec = afds.clamp(tonumber(elapsed_sec) or 0, 0, 1)
    decreasing_rate_per_sec = math.max(tonumber(decreasing_rate_per_sec) or 0, 0)
    increasing_rate_per_sec = math.max(tonumber(increasing_rate_per_sec) or decreasing_rate_per_sec, 0)
    if target_value < current_value then
        return math.max(target_value, current_value - decreasing_rate_per_sec * elapsed_sec)
    end
    return math.min(target_value, current_value + increasing_rate_per_sec * elapsed_sec)
end

function afds.vnav_energy_mode_is_active(input)
    input = input or {}
    return (tonumber(input.in_vnav_descent) or 0) > 0
        and (tonumber(input.vnav_state) or 0) > 0
        and (tonumber(input.active_pitch_mode) or 0) == 6
        and (tonumber(input.vs_status) or 0) == 2
        and (tonumber(input.flch_status) or 0) == 0
        and (tonumber(input.alt_hold_status) or 0) ~= 2
        and (tonumber(input.gs_status) or 0) < 1
        and (tonumber(input.actual_gs_status) or 0) < 1
        and (tonumber(input.approach_mode) or 0) == 0
        and (tonumber(input.actual_approach_status) or 0) < 1
        and (tonumber(input.autoland) or 0) ~= 1
        and (tonumber(input.active_land) or 0) < 1
        and (tonumber(input.radar_alt_ft) or 0) > 1000
        and (tonumber(input.altitude_to_capture_ft) or 0)
            > math.max(600, tonumber(input.capture_window_ft) or 0)
end

function afds.vnav_energy_guidance(input)
    input = input or {}
    local path_error_ft = tonumber(input.path_error_ft) or 0
    local path_trend_fpm = tonumber(input.path_trend_fpm) or 0
    local target_speed_kts = tonumber(input.target_speed_kts) or 0
    local actual_speed_kts = tonumber(input.actual_speed_kts) or target_speed_kts
    local speed_trend_kts_per_sec = tonumber(input.speed_trend_kts_per_sec) or 0
    local nominal_vspeed_fpm = tonumber(input.nominal_vspeed_fpm) or 0
    local min_safe_speed_kts = tonumber(input.min_safe_speed_kts) or 0
    local maximum_descent_fpm = tonumber(input.maximum_descent_fpm)
        or afds.VNAV_ENERGY_MAX_DESCENT_FPM
    local minimum_descent_fpm = tonumber(input.minimum_descent_fpm)
        or afds.VNAV_ENERGY_MIN_DESCENT_FPM
    local speed_error_kts = actual_speed_kts - target_speed_kts
    local path_axis, speed_axis = afds.vnav_energy_axes(path_error_ft, speed_error_kts,
        input.previous_path_axis, input.previous_speed_axis)
    local state = afds.vnav_energy_state(path_axis, speed_axis)

    local worsening_path_fpm = 0
    if path_axis > 0 then
        worsening_path_fpm = math.max(path_trend_fpm, 0)
    elseif path_axis < 0 then
        worsening_path_fpm = math.min(path_trend_fpm, 0)
    end
    local path_correction_fpm = afds.clamp(path_error_ft * 0.45 + worsening_path_fpm * 0.20,
        -900, 1200)
    local speed_adjustment_fpm = 0

    if state == afds.VNAV_ENERGY_STATE_ABOVE_BELOW then
        speed_adjustment_fpm = -math.min(math.abs(speed_error_kts) * 45, 900)
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_BELOW then
        speed_adjustment_fpm = math.min(math.abs(speed_error_kts) * 35, 700)
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_ABOVE then
        speed_adjustment_fpm = math.min(speed_error_kts * 25, 500)
    elseif state == afds.VNAV_ENERGY_STATE_ON_PATH_BELOW then
        speed_adjustment_fpm = math.min(math.abs(speed_error_kts) * 20, 400)
    end

    local unconstrained_vspeed_fpm = nominal_vspeed_fpm - path_correction_fpm + speed_adjustment_fpm
    local target_vspeed_fpm = afds.clamp(unconstrained_vspeed_fpm,
        maximum_descent_fpm, minimum_descent_fpm)
    local recovery_limited = unconstrained_vspeed_fpm < maximum_descent_fpm
    local protection_speed_kts = math.max(min_safe_speed_kts,
        target_speed_kts - afds.VNAV_ENERGY_PROTECTION_MARGIN_KTS)
    local protection_active = actual_speed_kts <= protection_speed_kts
    if input.protection_active == true then
        protection_active = actual_speed_kts
            < protection_speed_kts + afds.VNAV_ENERGY_PROTECTION_RELEASE_KTS
    end

    local thrust_policy = afds.VNAV_ENERGY_THRUST_IDLE
    local thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_NONE
    if protection_active then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_BELOW then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED
    elseif state == afds.VNAV_ENERGY_STATE_ON_PATH_BELOW then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED
    elseif state == afds.VNAV_ENERGY_STATE_ABOVE_BELOW and recovery_limited
        and speed_error_kts <= -afds.VNAV_ENERGY_SPEED_ENTER_KTS
        and speed_trend_kts_per_sec <= 0 then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED
    end

    local drag_required = path_axis > 0
        and ((speed_axis > 0 and speed_error_kts >= 10)
            or (recovery_limited and path_error_ft >= afds.VNAV_ENERGY_DRAG_PATH_ERROR_FT))

    return {
        path_axis = path_axis,
        speed_axis = speed_axis,
        state = state,
        state_name = afds.vnav_energy_state_name(state),
        speed_error_kts = speed_error_kts,
        target_vspeed_fpm = target_vspeed_fpm,
        unconstrained_vspeed_fpm = unconstrained_vspeed_fpm,
        thrust_policy = thrust_policy,
        thrust_reason = thrust_reason,
        thrust_reason_name = afds.vnav_energy_thrust_reason_name(thrust_reason),
        protection_active = protection_active,
        protection_speed_kts = protection_speed_kts,
        recovery_limited = recovery_limited,
        drag_required = drag_required
    }
end

-- [b] VNAV button on the ground and VNAV engage height

-- What a VNAV button press does, in the existing order: PERF/VNAV UNAVAILABLE
-- first (no cruise altitude, or less than 10 NM to T/D on the ground), then a
-- press with VNAV armed or active turns it off. On the ground, or in TO/GA,
-- VNAV is only armed and VNAV_CLB engages it after takeoff. Only an airborne
-- press outside TO/GA engages VNAV at once.
afds.VNAV_BUTTON_REFUSE = 1
afds.VNAV_BUTTON_DISARM = 2
afds.VNAV_BUTTON_ARM = 3
afds.VNAV_BUTTON_ENGAGE = 4

-- Lowest radio altitude at which an armed VNAV may engage (as in VNAV_CLB).
afds.VNAV_ENGAGE_MIN_RA_FT = 400

function afds.vnav_button_action(vnav_state, cruise_alt_ft, dist_to_tod_nm, on_ground, active_pitch_mode)
    local grounded = tonumber(on_ground) == 1
    if (tonumber(cruise_alt_ft) or 0) < 10
        or ((tonumber(dist_to_tod_nm) or 0) < 10 and grounded) then
        return afds.VNAV_BUTTON_REFUSE
    end
    if (tonumber(vnav_state) or 0) > 0 then return afds.VNAV_BUTTON_DISARM end
    if grounded or tonumber(active_pitch_mode) == 1 then return afds.VNAV_BUTTON_ARM end
    return afds.VNAV_BUTTON_ENGAGE
end

function afds.vnav_engage_height_reached(on_ground, radio_alt_ft)
    return tonumber(on_ground) ~= 1
        and (tonumber(radio_alt_ft) or 0) > afds.VNAV_ENGAGE_MIN_RA_FT
end

-- [c] Route end of descent and VNAV descent path entry
-- Index of the end of descent in an xtlua/fms route: the first entry within
-- radius_nm of the destination (the last entry) after the entry farthest from
-- it. On an A to B route this is the first entry inside the radius, as before.
-- On a route that starts and ends at the same airport the departure entries
-- are inside the radius too, and must not end the route there. If no entry
-- qualifies, or the whole route is inside the radius, the destination is used.
-- The missed approach after the arrival runway (the last runway entry inside
-- the radius with route outside it before) is left out: X-Plane ends a
-- missed approach's vectors leg ("(VECT)") hundreds of NM away, which would
-- otherwise be the farthest point and put the EOD at the destination.
function afds.route_eod_index(route, distance_fn, radius_nm)
    local count = #route
    if count < 2 or type(distance_fn) ~= "function" then return count end
    local destination = route[count]
    local distances = {}
    for i = 1, count - 1 do
        distances[i] = distance_fn(route[i][5], route[i][6], destination[5], destination[6])
    end
    local last = count - 1
    for i = count - 1, 1, -1 do
        if string.sub(tostring(route[i][8] or ""), 1, 2) == "RW" and distances[i] < radius_nm then
            for k = 1, i - 1 do
                if distances[k] >= radius_nm then
                    last = i
                    break
                end
            end
            break
        end
    end
    local farthest_index, farthest_nm = 1, -1
    for i = 1, last do
        if distances[i] > farthest_nm then
            farthest_index, farthest_nm = i, distances[i]
        end
    end
    if farthest_nm < radius_nm then return count end
    for i = farthest_index + 1, last do
        if distances[i] < radius_nm then return i end
    end
    return count
end

-- Gradient (ft/nm) and target altitude of one VNAV profile entry. The path
-- normally starts at the previous constraint; from_tod starts it at the T/D
-- instead, at CRZ ALT or at a higher previous route altitude. An unset
-- previous altitude (below zero) or a leg of 0.1 NM or less gives no gradient,
-- and only a real previous altitude may replace the target altitude.
function afds.vnav_entry_slope(previous_alt_ft, alt_ft, distance_nm, from_tod, cruise_alt_ft)
    local start_alt_ft = previous_alt_ft
    if from_tod then start_alt_ft = math.max(previous_alt_ft, cruise_alt_ft) end
    if start_alt_ft <= 0 or distance_nm <= 0.1 then
        if previous_alt_ft > 0 then return 0, previous_alt_ft end
        return 0, alt_ft
    end
    return (start_alt_ft - alt_ft) / distance_nm, alt_ft
end

-- [d] Cruise climb after the ALT selector push
-- The climb starts 2 s after the push.  By then CRZ ALT may be back at the
-- level being flown (put back, or the step cancelled), and close to T/D a
-- climb would only be followed by the descent: a 2,000 ft step takes 15-20 NM
-- and VNAV leaves the cruise climb 10 NM before T/D.
afds.CRUISE_CLIMB_TOD_MARGIN_NM = 50

-- Returns "climb", "cancelled" (CRZ ALT not above the aircraft by more than
-- the capture window) or "tod" (T/D within CRUISE_CLIMB_TOD_MARGIN_NM, or
-- already passed).
function afds.cruise_climb_action(cruise_alt_ft, altitude_ft, distance_to_tod_nm, capture_window_ft)
    local cruise_alt = tonumber(cruise_alt_ft)
    local altitude = tonumber(altitude_ft)
    local window = tonumber(capture_window_ft) or 0
    if cruise_alt == nil or altitude == nil or cruise_alt <= altitude + window then
        return "cancelled"
    end
    local distance = tonumber(distance_to_tod_nm)
    if distance == nil or distance <= afds.CRUISE_CLIMB_TOD_MARGIN_NM then
        return "tod"
    end
    return "climb"
end

-- [e] Approach LOC and G/S capture windows
-- LOC captures within 2 dots while closing on the localizer, or within 1 dot
-- when settled; G/S captures only after LOC, with both within 1.5 dots.
afds.LOC_CAPTURE_MAX_DOTS = 2.0
afds.LOC_CAPTURE_STEADY_DOTS = 1.0
afds.LOC_CAPTURE_CLOSING_DOTS_PER_SEC = 0.01
afds.LOC_CAPTURE_STEADY_GROWTH_DOTS_PER_SEC = 0.02
afds.LOC_CAPTURE_MAX_INTERCEPT_DEG = 90
afds.LOC_CAPTURE_SAMPLE_SEC = 1.0
afds.GS_CAPTURE_MAX_LOC_DOTS = 1.5
afds.GS_CAPTURE_MAX_GS_DOTS = 1.5

-- Mean LOC deviation of the two receivers, in dots without sign.
function afds.loc_deviation_dots(nav1_dots, nav2_dots)
    nav1_dots = tonumber(nav1_dots)
    nav2_dots = tonumber(nav2_dots)
    if nav1_dots == nil or nav2_dots == nil then return nil end
    return math.abs((nav1_dots + nav2_dots) / 2)
end

local function heading_difference_deg(from_deg, to_deg)
    local difference = math.fmod(to_deg - from_deg, 360)
    if difference > 180 then difference = difference - 360 end
    if difference < -180 then difference = difference + 360 end
    return difference
end

-- input.sample is an earlier {time, dots} reading of loc_deviation_dots; it
-- must be at least LOC_CAPTURE_SAMPLE_SEC older than input.time so the rate
-- of change is measured over a useful interval.
function afds.loc_capture_ready(input)
    input = input or {}
    if (tonumber(input.nav1_signal) or 0) ~= 1 or (tonumber(input.nav2_signal) or 0) ~= 1 then
        return false
    end
    local course_deg = tonumber(input.course_deg)
    local heading_deg = tonumber(input.heading_deg)
    if course_deg == nil or heading_deg == nil
        or math.abs(heading_difference_deg(course_deg, heading_deg)) > afds.LOC_CAPTURE_MAX_INTERCEPT_DEG then
        return false
    end
    local dots = afds.loc_deviation_dots(input.nav1_dots, input.nav2_dots)
    if dots == nil or dots > afds.LOC_CAPTURE_MAX_DOTS then return false end

    local sample = input.sample
    local time = tonumber(input.time)
    if type(sample) ~= "table" or time == nil
        or tonumber(sample.time) == nil or tonumber(sample.dots) == nil then
        return false
    end
    local elapsed = time - tonumber(sample.time)
    if elapsed < afds.LOC_CAPTURE_SAMPLE_SEC then return false end
    local rate = (dots - tonumber(sample.dots)) / elapsed
    if rate <= -afds.LOC_CAPTURE_CLOSING_DOTS_PER_SEC then return true end
    return dots <= afds.LOC_CAPTURE_STEADY_DOTS and rate < afds.LOC_CAPTURE_STEADY_GROWTH_DOTS_PER_SEC
end

function afds.gs_capture_ready(input)
    input = input or {}
    if input.loc_captured ~= true then return false end
    local loc_dots = afds.loc_deviation_dots(input.nav1_dots, input.nav2_dots)
    local gs_dots = tonumber(input.gs_dots)
    return loc_dots ~= nil and loc_dots <= afds.GS_CAPTURE_MAX_LOC_DOTS
        and gs_dots ~= nil and math.abs(gs_dots) < afds.GS_CAPTURE_MAX_GS_DOTS
        and (tonumber(input.nav1_gs_flag) or 1) == 0 and (tonumber(input.nav2_gs_flag) or 1) == 0
        and (tonumber(input.nav1_vertical_signal) or 0) == 1
        and (tonumber(input.nav2_vertical_signal) or 0) == 1
end

-- [c-4] T/D from the descent constraints and the end of descent altitude
-- Planned descent gradient of the T/D (2.9 NM per 1,000 ft, as before).
afds.VNAV_TOD_FT_PER_NM = 290

-- Distance (NM) before the destination at which the descent from cruise_alt_ft
-- starts, and the end of descent altitude. As in setDistances, the route runs
-- to the end of descent (eod_index) and then straight to the destination (the
-- last entry). The end of descent altitude is its route altitude ([9]), reached
-- at the end of descent, or the destination elevation when it has none ([3] is
-- a frequency on a navaid).
-- Each descent constraint up to the end of descent must also be reached at
-- 290 ft/nm from CRZ ALT, so the T/D is the earliest of these. Walking back
-- from the end of descent, the descent constraints are the route altitudes
-- that lie after the T/D found so far (one at or above CRZ ALT there cannot
-- move it). A route altitude before it is cruise (such as the older CRZ ALT
-- left in [9] after a step climb), and an entry closer to the start of the
-- route than to its end is climb (a SID constraint). Passed constraints count
-- as well, so the T/D does not move while the aircraft passes them on the
-- descent.
function afds.route_tod_distance(route, eod_index, cruise_alt_ft, distance_fn)
    local count = #route
    if count < 1 then return 0, 0 end
    local cruise_alt = tonumber(cruise_alt_ft) or 0
    local eod = math.max(1, math.min(tonumber(eod_index) or count, count))
    local eod_alt = tonumber(route[eod][9]) or 0
    if eod_alt <= 0 then eod_alt = tonumber(route[count][9]) or 0 end
    local tod_nm = (cruise_alt - eod_alt) / afds.VNAV_TOD_FT_PER_NM
    if type(distance_fn) ~= "function" then return tod_nm, eod_alt end
    -- distance from each entry along the route to the end of descent, then to the destination
    local to_end = {}
    to_end[eod] = distance_fn(route[eod][5], route[eod][6], route[count][5], route[count][6])
    for i = eod - 1, 1, -1 do
        to_end[i] = to_end[i + 1] + distance_fn(route[i][5], route[i][6], route[i + 1][5], route[i + 1][6])
    end
    for i = eod, 1, -1 do
        -- the route altitude of the end of descent applies there, even when CRZ ALT is
        -- so close to it that the T/D from the destination lies after that point
        if i < eod and (to_end[i] >= tod_nm or to_end[i] * 2 > to_end[1]) then break end
        local alt = tonumber(route[i][9]) or 0
        if alt > 0 and alt < cruise_alt then
            tod_nm = math.max(tod_nm, to_end[i] + (cruise_alt - alt) / afds.VNAV_TOD_FT_PER_NM)
        end
    end
    return tod_nm, eod_alt
end

return afds
