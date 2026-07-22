-- Pure flight-director response calculations.  Lua 5.1 compatible.

local afds_controls = {}

afds_controls.PITCH_TRANSITION_DURATION_SEC = 0.70

afds_controls.VERTICAL_DIRECTION_DESCENT = -1
afds_controls.VERTICAL_DIRECTION_LEVEL = 0
afds_controls.VERTICAL_DIRECTION_CLIMB = 1

-- Speed-on-pitch modes may trade vertical rate for airspeed, but should not
-- reverse the selected vertical direction for an ordinary speed error.
afds_controls.SPEED_PITCH_MIN_TARGET_DEG = -3.5
afds_controls.SPEED_PITCH_MAX_TARGET_DEG = 15.0
afds_controls.SPEED_PITCH_CLIMB_MIN_TARGET_DEG = 0.0
afds_controls.SPEED_PITCH_DESCENT_MAX_TARGET_DEG = 5.0
afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM = 100.0
afds_controls.SPEED_PITCH_PHASE_RECOVERY_DEG_PER_SEC = 1.0
afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_MARGIN_KTS = 15.0
afds_controls.SPEED_PITCH_SEVERE_OVERSPEED_MARGIN_KTS = 5.0

afds_controls.ROLL_FILTER_LARGE_ERROR_DEG = 10.0
afds_controls.ROLL_FILTER_MEDIUM_ERROR_DEG = 3.0
afds_controls.ROLL_FILTER_LARGE_TIME_CONSTANT_SEC = 0.18
afds_controls.ROLL_FILTER_MEDIUM_TIME_CONSTANT_SEC = 0.35
afds_controls.ROLL_FILTER_SMALL_TIME_CONSTANT_SEC = 0.85
afds_controls.ROLL_FILTER_REVERSAL_TIME_CONSTANT_SEC = 0.45
afds_controls.ROLL_FILTER_APPROACH_TIME_CONSTANT_SEC = 0.55
afds_controls.ROLL_FILTER_LARGE_SLEW_DEG_PER_SEC = 25.0
afds_controls.ROLL_FILTER_MEDIUM_SLEW_DEG_PER_SEC = 12.0
afds_controls.ROLL_FILTER_SMALL_SLEW_DEG_PER_SEC = 4.0
afds_controls.ROLL_FILTER_REVERSAL_SLEW_DEG_PER_SEC = 10.0
afds_controls.ROLL_FILTER_APPROACH_SLEW_DEG_PER_SEC = 8.0

afds_controls.ROLL_OUTPUT_LARGE_RESPONSE_SEC = 1.8
afds_controls.ROLL_OUTPUT_MEDIUM_RESPONSE_SEC = 2.8
afds_controls.ROLL_OUTPUT_SMALL_RESPONSE_SEC = 4.5
afds_controls.ROLL_OUTPUT_REVERSAL_RESPONSE_SEC = 3.2
afds_controls.ROLL_OUTPUT_APPROACH_RESPONSE_SEC = 4.0

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function afds_controls.vertical_direction_for_altitude(current_altitude_ft, target_altitude_ft, capture_window_ft)
    if type(current_altitude_ft) ~= "number" or type(target_altitude_ft) ~= "number" then
        return afds_controls.VERTICAL_DIRECTION_LEVEL
    end
    capture_window_ft = math.max(tonumber(capture_window_ft) or 0, 0)
    local altitude_error_ft = target_altitude_ft - current_altitude_ft
    if altitude_error_ft > capture_window_ft then
        return afds_controls.VERTICAL_DIRECTION_CLIMB
    elseif altitude_error_ft < -capture_window_ft then
        return afds_controls.VERTICAL_DIRECTION_DESCENT
    end
    return afds_controls.VERTICAL_DIRECTION_LEVEL
end

function afds_controls.limit_speed_pitch_target(requested_target_deg, previous_target_deg, vertical_direction,
        vertical_speed_fpm, actual_speed_kts, target_speed_kts, min_safe_speed_kts, max_safe_speed_kts,
        elapsed_sec)
    if type(previous_target_deg) ~= "number" then previous_target_deg = requested_target_deg or 0 end
    if type(requested_target_deg) ~= "number" then requested_target_deg = previous_target_deg end
    vertical_speed_fpm = tonumber(vertical_speed_fpm) or 0

    local severe_underspeed = false
    if type(actual_speed_kts) == "number" and type(target_speed_kts) == "number" then
        local underspeed_threshold_kts = target_speed_kts
            - afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_MARGIN_KTS
        if type(min_safe_speed_kts) == "number" and min_safe_speed_kts > 0 then
            underspeed_threshold_kts = math.max(underspeed_threshold_kts, min_safe_speed_kts)
        end
        severe_underspeed = actual_speed_kts <= underspeed_threshold_kts
    end

    local severe_overspeed = type(actual_speed_kts) == "number"
        and type(max_safe_speed_kts) == "number" and max_safe_speed_kts > 0
        and actual_speed_kts >= max_safe_speed_kts
            - afds_controls.SPEED_PITCH_SEVERE_OVERSPEED_MARGIN_KTS

    local recovery_step_deg = afds_controls.SPEED_PITCH_PHASE_RECOVERY_DEG_PER_SEC
        * clamp(tonumber(elapsed_sec) or 0, 0, 0.5)

    if vertical_direction == afds_controls.VERTICAL_DIRECTION_CLIMB and not severe_underspeed then
        if previous_target_deg < afds_controls.SPEED_PITCH_CLIMB_MIN_TARGET_DEG then
            requested_target_deg = math.max(requested_target_deg,
                math.min(afds_controls.SPEED_PITCH_CLIMB_MIN_TARGET_DEG,
                    previous_target_deg + recovery_step_deg))
        else
            requested_target_deg = math.max(requested_target_deg,
                afds_controls.SPEED_PITCH_CLIMB_MIN_TARGET_DEG)
        end

        if vertical_speed_fpm <= afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM
            and requested_target_deg < previous_target_deg then
            requested_target_deg = previous_target_deg
        end
        if vertical_speed_fpm < -afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM then
            requested_target_deg = math.max(requested_target_deg, previous_target_deg + recovery_step_deg)
        end
    elseif vertical_direction == afds_controls.VERTICAL_DIRECTION_DESCENT and not severe_overspeed then
        if previous_target_deg > afds_controls.SPEED_PITCH_DESCENT_MAX_TARGET_DEG then
            requested_target_deg = math.min(requested_target_deg,
                math.max(afds_controls.SPEED_PITCH_DESCENT_MAX_TARGET_DEG,
                    previous_target_deg - recovery_step_deg))
        else
            requested_target_deg = math.min(requested_target_deg,
                afds_controls.SPEED_PITCH_DESCENT_MAX_TARGET_DEG)
        end

        if vertical_speed_fpm >= -afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM
            and requested_target_deg > previous_target_deg then
            requested_target_deg = previous_target_deg
        end
        if vertical_speed_fpm > afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM then
            requested_target_deg = math.min(requested_target_deg, previous_target_deg - recovery_step_deg)
        end
    end

    return clamp(requested_target_deg, afds_controls.SPEED_PITCH_MIN_TARGET_DEG,
        afds_controls.SPEED_PITCH_MAX_TARGET_DEG), severe_underspeed, severe_overspeed
end

function afds_controls.pitch_transition_value(old_target_deg, new_target_deg, elapsed_sec, duration_sec)
    if type(old_target_deg) ~= "number" or type(new_target_deg) ~= "number" then return new_target_deg end
    duration_sec = duration_sec or afds_controls.PITCH_TRANSITION_DURATION_SEC
    if type(duration_sec) ~= "number" or duration_sec <= 0 then return new_target_deg end

    local fraction = clamp((elapsed_sec or 0) / duration_sec, 0, 1)
    return old_target_deg + ((new_target_deg - old_target_deg) * fraction)
end

function afds_controls.pitch_controller_update_due(mode_changed, elapsed_sec, update_interval_sec)
    if mode_changed then return true end
    elapsed_sec = math.max(tonumber(elapsed_sec) or 0, 0)
    update_interval_sec = math.max(tonumber(update_interval_sec) or 0, 0)
    return elapsed_sec >= update_interval_sec
end

function afds_controls.adaptive_roll_filter(current_deg, target_deg, elapsed_sec, approach_protected)
    if type(current_deg) ~= "number" then current_deg = target_deg or 0 end
    if type(target_deg) ~= "number" then return current_deg end
    if type(elapsed_sec) ~= "number" or elapsed_sec <= 0 then return current_deg end

    local error_deg = target_deg - current_deg
    local absolute_error_deg = math.abs(error_deg)
    local time_constant_sec
    local slew_deg_per_sec

    if approach_protected then
        time_constant_sec = afds_controls.ROLL_FILTER_APPROACH_TIME_CONSTANT_SEC
        slew_deg_per_sec = afds_controls.ROLL_FILTER_APPROACH_SLEW_DEG_PER_SEC
    elseif current_deg * target_deg < 0 and absolute_error_deg > afds_controls.ROLL_FILTER_MEDIUM_ERROR_DEG then
        time_constant_sec = afds_controls.ROLL_FILTER_REVERSAL_TIME_CONSTANT_SEC
        slew_deg_per_sec = afds_controls.ROLL_FILTER_REVERSAL_SLEW_DEG_PER_SEC
    elseif absolute_error_deg >= afds_controls.ROLL_FILTER_LARGE_ERROR_DEG then
        time_constant_sec = afds_controls.ROLL_FILTER_LARGE_TIME_CONSTANT_SEC
        slew_deg_per_sec = afds_controls.ROLL_FILTER_LARGE_SLEW_DEG_PER_SEC
    elseif absolute_error_deg >= afds_controls.ROLL_FILTER_MEDIUM_ERROR_DEG then
        time_constant_sec = afds_controls.ROLL_FILTER_MEDIUM_TIME_CONSTANT_SEC
        slew_deg_per_sec = afds_controls.ROLL_FILTER_MEDIUM_SLEW_DEG_PER_SEC
    else
        time_constant_sec = afds_controls.ROLL_FILTER_SMALL_TIME_CONSTANT_SEC
        slew_deg_per_sec = afds_controls.ROLL_FILTER_SMALL_SLEW_DEG_PER_SEC
    end

    local alpha = 1 - math.exp(-math.min(elapsed_sec, 0.25) / time_constant_sec)
    local requested_change_deg = error_deg * alpha
    local maximum_change_deg = slew_deg_per_sec * elapsed_sec
    requested_change_deg = clamp(requested_change_deg, -maximum_change_deg, maximum_change_deg)
    return current_deg + requested_change_deg
end

function afds_controls.roll_output_response_sec(bank_error_deg, current_output, target_output, approach_protected)
    if approach_protected then return afds_controls.ROLL_OUTPUT_APPROACH_RESPONSE_SEC end
    if type(current_output) == "number" and type(target_output) == "number"
        and current_output * target_output < 0 then
        return afds_controls.ROLL_OUTPUT_REVERSAL_RESPONSE_SEC
    end

    local absolute_error_deg = math.abs(bank_error_deg or 0)
    if absolute_error_deg >= afds_controls.ROLL_FILTER_LARGE_ERROR_DEG then
        return afds_controls.ROLL_OUTPUT_LARGE_RESPONSE_SEC
    elseif absolute_error_deg >= afds_controls.ROLL_FILTER_MEDIUM_ERROR_DEG then
        return afds_controls.ROLL_OUTPUT_MEDIUM_RESPONSE_SEC
    end
    return afds_controls.ROLL_OUTPUT_SMALL_RESPONSE_SEC
end

return afds_controls
