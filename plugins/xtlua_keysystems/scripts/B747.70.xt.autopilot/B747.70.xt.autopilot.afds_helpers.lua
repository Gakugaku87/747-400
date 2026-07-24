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

return afds
