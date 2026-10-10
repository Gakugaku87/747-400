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
-- The minimum safe speed never lifts the severe underspeed threshold above
-- target - 5 kt (with takeoff flaps Vmc + 10 kt can be above V2 + 10 kt).
afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_FLOOR_MARGIN_KTS = 5.0
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
        elapsed_sec, accelerating_to_target)
    if type(previous_target_deg) ~= "number" then previous_target_deg = requested_target_deg or 0 end
    if type(requested_target_deg) ~= "number" then requested_target_deg = previous_target_deg end
    vertical_speed_fpm = tonumber(vertical_speed_fpm) or 0

    -- While accelerating to a raised target (update_speed_target_acceleration;
    -- accelerating_to_target true, or the speed it started from) the target -
    -- 15 kt rule is not used, so the climb guard stays.
    local severe_underspeed = false
    if type(actual_speed_kts) == "number" and type(target_speed_kts) == "number" then
        if accelerating_to_target then
            severe_underspeed = actual_speed_kts <= afds_controls.accelerating_underspeed_threshold(
                target_speed_kts, min_safe_speed_kts, tonumber(accelerating_to_target))
        else
            severe_underspeed = actual_speed_kts
                <= afds_controls.severe_underspeed_threshold(target_speed_kts, min_safe_speed_kts)
        end
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

-- [a] ALT capture and ALT hold protection

-- ALT hold flies 2 fpm per foot of altitude error (the hold altitude in about
-- 30 s). A normal capture starts inside the capture window, which is at most
-- 1000 ft, so the 2000 fpm limit only slows holds that start far away.
afds_controls.ALTITUDE_HOLD_FPM_PER_FT = 2.0
afds_controls.ALTITUDE_HOLD_MAX_TARGET_FPM = 2000.0
-- While the speed runs away in the direction of the altitude change, ALT hold
-- slows the change to this rate instead of trading more speed for altitude.
afds_controls.ALTITUDE_HOLD_SPEED_LIMITED_FPM = 500.0
afds_controls.ALTITUDE_HOLD_OVERSPEED_MARGIN_KTS = 15.0

-- Highest speed that counts as a severe underspeed: target - 15 kt, but not
-- below the minimum safe speed, itself capped at target - 5 kt so that a
-- climb on target is never a severe underspeed. Shared by the FLCH pitch
-- limiter and ALT hold.
function afds_controls.severe_underspeed_threshold(target_speed_kts, min_safe_speed_kts)
    local threshold_kts = target_speed_kts - afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_MARGIN_KTS
    if type(min_safe_speed_kts) == "number" and min_safe_speed_kts > 0 then
        threshold_kts = math.max(threshold_kts, math.min(min_safe_speed_kts,
            target_speed_kts - afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_FLOOR_MARGIN_KTS))
    end
    return threshold_kts
end

-- Target vertical speed for ALT hold: 2 x altitude error, limited to
-- +/-2000 fpm. Descending at target + 15 kt (or Vmax - 5 kt) or climbing at the
-- severe underspeed threshold limits it further to +/-500 fpm. The direction is
-- never reversed and errors under 250 ft are unchanged.
function afds_controls.altitude_hold_target_fpm(hold_altitude_ft, altitude_ft, actual_speed_kts,
        target_speed_kts, min_safe_speed_kts, max_safe_speed_kts)
    local target_fpm = clamp((hold_altitude_ft - altitude_ft) * afds_controls.ALTITUDE_HOLD_FPM_PER_FT,
        -afds_controls.ALTITUDE_HOLD_MAX_TARGET_FPM, afds_controls.ALTITUDE_HOLD_MAX_TARGET_FPM)
    if type(actual_speed_kts) ~= "number" or type(target_speed_kts) ~= "number" then
        return target_fpm
    end

    if target_fpm < 0 then
        local overspeed_threshold_kts = target_speed_kts + afds_controls.ALTITUDE_HOLD_OVERSPEED_MARGIN_KTS
        if type(max_safe_speed_kts) == "number" and max_safe_speed_kts > 0 then
            overspeed_threshold_kts = math.min(overspeed_threshold_kts,
                max_safe_speed_kts - afds_controls.SPEED_PITCH_SEVERE_OVERSPEED_MARGIN_KTS)
        end
        if actual_speed_kts >= overspeed_threshold_kts then
            target_fpm = math.max(target_fpm, -afds_controls.ALTITUDE_HOLD_SPEED_LIMITED_FPM)
        end
    elseif target_fpm > 0 and actual_speed_kts
            <= afds_controls.severe_underspeed_threshold(target_speed_kts, min_safe_speed_kts) then
        target_fpm = math.min(target_fpm, afds_controls.ALTITUDE_HOLD_SPEED_LIMITED_FPM)
    end
    return target_fpm
end

-- Altitude to capture when the director enters the ALT branch without an ALT
-- hold. Inside the capture window (the same strict test as ap_director_pitch)
-- it is the MCP altitude. Outside it, a FLCH or V/S request means the FMA has
-- not caught up with a mode push yet, so nothing is captured (nil). Otherwise
-- the current altitude is held.
function afds_controls.implicit_altitude_capture_target(flch_status, vs_status, altitude_ft,
        mcp_altitude_ft, capture_window_ft)
    capture_window_ft = tonumber(capture_window_ft) or 0
    if altitude_ft < mcp_altitude_ft + capture_window_ft and altitude_ft > mcp_altitude_ft - capture_window_ft then
        return mcp_altitude_ft
    end
    if flch_status == 2 or vs_status == 2 then return nil end
    return altitude_ft
end

-- Whether ap_director_pitch may drop an ALT hold in this pitch mode. ALT (9),
-- VNAV ALT (5) and VNAV PTH (6) keep it. FLCH (8) and V/S (7) drop it only
-- when that mode is requested, and VNAV SPD (4) only when FLCH or V/S is
-- requested (the FMA shows it only then); otherwise the FMA is stale after an
-- ALT HOLD push and the hold must survive until the FMA catches up.
function afds_controls.altitude_hold_release_allowed(pitch_mode, flch_status, vs_status)
    if pitch_mode == 5 or pitch_mode == 6 or pitch_mode == 9 then return false end
    if pitch_mode == 8 and flch_status ~= 2 then return false end
    if pitch_mode == 7 and vs_status ~= 2 then return false end
    if pitch_mode == 4 and flch_status ~= 2 and vs_status ~= 2 then return false end
    return true
end

-- [g-2] Acceleration to a raised speed target

-- The VNAV speed target steps up (+20 kt at flap retraction, 250 to the ECON
-- climb speed above 10,000 ft) and a step of more than 15 kt used to be a
-- severe underspeed at once, so the speed-on-pitch modes dropped the climb
-- guard and descended at climb thrust. A rise of at least 5 kt is latched as
-- an acceleration until the speed is within 5 kt of the target.
afds_controls.SPEED_TARGET_ACCELERATION_STEP_KTS = 5.0
afds_controls.SPEED_TARGET_ACCELERATION_RELEASE_KTS = 5.0

-- Whether the aircraft is accelerating to a raised target. The latch is set
-- when the target is at least 5 kt above the reference target (the previous
-- target, or the speed when the mode engages) and the speed is above the
-- minimum safe speed, so a real underspeed is never latched. It is kept until
-- the speed is within 5 kt of the target.
function afds_controls.update_speed_target_acceleration(latched, reference_target_kts, target_speed_kts,
        actual_speed_kts, min_safe_speed_kts)
    if type(target_speed_kts) ~= "number" or type(actual_speed_kts) ~= "number" then return false end
    if actual_speed_kts >= target_speed_kts - afds_controls.SPEED_TARGET_ACCELERATION_RELEASE_KTS then
        return false
    end
    if latched == true then return true end
    return type(reference_target_kts) == "number" and type(min_safe_speed_kts) == "number"
        and target_speed_kts - reference_target_kts >= afds_controls.SPEED_TARGET_ACCELERATION_STEP_KTS
        and actual_speed_kts > min_safe_speed_kts
end

-- Highest speed that counts as a severe underspeed while accelerating to a
-- raised target: the minimum safe speed, capped at target - 5 kt. Without a
-- minimum safe speed the usual threshold applies. Given the speed the
-- acceleration started from, also 15 kt below that (capped the same way): with
-- thrust lost on the way (an engine early in a VNAV step) the climb guard held
-- the aircraft up while the speed ran down to the minimum safe speed, 221 kt at
-- FL310 at 294 t (model: 306 kt -> +4,862 fpm, then 202 kt).
afds_controls.SPEED_TARGET_ACCELERATION_LOSS_KTS = 15.0
function afds_controls.accelerating_underspeed_threshold(target_speed_kts, min_safe_speed_kts, accelerated_from_kts)
    local threshold_kts
    if type(min_safe_speed_kts) ~= "number" or min_safe_speed_kts <= 0 then
        threshold_kts = afds_controls.severe_underspeed_threshold(target_speed_kts, min_safe_speed_kts)
    else
        threshold_kts = math.min(min_safe_speed_kts,
            target_speed_kts - afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_FLOOR_MARGIN_KTS)
    end
    if type(accelerated_from_kts) == "number" then
        threshold_kts = math.max(threshold_kts, math.min(
            accelerated_from_kts - afds_controls.SPEED_TARGET_ACCELERATION_LOSS_KTS,
            target_speed_kts - afds_controls.SPEED_PITCH_SEVERE_UNDERSPEED_FLOOR_MARGIN_KTS))
    end
    return threshold_kts
end

-- [g-4] Pitch target with no active pitch mode

-- With no pitch mode (the FMA shows NONE for about 0.5 s after an ALT
-- selector push, or FLARE without autoland) the director holds the current
-- attitude, limited to the speed-on-pitch range, instead of 0 degrees, so the
-- next mode starts from the attitude. Without an attitude it is level.
function afds_controls.inactive_mode_pitch_target(pitch_deg)
    if type(pitch_deg) ~= "number" then return 0 end
    return clamp(pitch_deg, afds_controls.SPEED_PITCH_MIN_TARGET_DEG, afds_controls.SPEED_PITCH_MAX_TARGET_DEG)
end

-- [g-6] Speed-on-pitch climb away from the target speed

-- More than 2 kt from the target in a FLCH SPD or VNAV SPD climb, the pitch
-- target moves with the acceleration still missing. The wanted acceleration
-- is the speed error over 20 s, at most 1 kt/s either way. Below the target
-- the pitch goes down while the aircraft accelerates less than wanted and up
-- once it accelerates more than 0.1 kt/s beyond it (mirrored above the
-- target), at 0.6 deg/s per kt/s of difference and at most 0.5 deg/s, and
-- not while the attitude is still 0.5 deg or more on the far side of the last
-- target (the same interlock as the speed law). Within 2 kt, level or
-- descending the speed law is unchanged. That law moved the pitch by
-- (0.01 + 0.5 x the speed change)/3 deg an update below the target, about
-- 0.01 deg/s at a steady speed, so a 26 kt rise with takeoff flaps was not
-- flown in 250 s of climb. The climb guard of limit_speed_pitch_target still
-- applies to the result.
afds_controls.CLIMB_SPEED_PITCH_MARGIN_KTS = 2.0
afds_controls.CLIMB_SPEED_PITCH_TIME_CONSTANT_SEC = 20.0
afds_controls.CLIMB_SPEED_PITCH_MAX_ACCEL_KTS_PER_SEC = 1.0
afds_controls.CLIMB_SPEED_PITCH_ACCEL_BAND_KTS_PER_SEC = 0.1
afds_controls.CLIMB_SPEED_PITCH_GAIN_DEG_PER_KT = 0.6
afds_controls.CLIMB_SPEED_PITCH_MAX_RATE_DEG_PER_SEC = 0.5
afds_controls.CLIMB_SPEED_PITCH_ATTITUDE_LAG_DEG = 0.5
-- Below the target the pitch comes down only while the aircraft climbs at
-- more than +300 fpm, and from there at most 0.5 deg/s per 1,000 fpm above
-- it: at altitude climb thrust leaves little to accelerate with (FL330,
-- 282 t: about +700 fpm at a steady speed), and the wanted acceleration was
-- taken from a descent until the climb guard pulled the nose back up at
-- 1 deg/s (2026-10-10 TST744L step to FL350: -851 fpm, then 0.8 -> 7.4 deg
-- and +3,800 fpm).
afds_controls.CLIMB_SPEED_PITCH_MIN_CLIMB_FPM = 300.0
afds_controls.CLIMB_SPEED_PITCH_DOWN_RATE_DEG_PER_SEC_PER_KFPM = 0.5

-- Pitch target for a speed-on-pitch climb more than 2 kt from the target, or
-- nil to leave it to the speed law. speed_change_kts is the change since the
-- previous update, elapsed_sec the time since it, pitch_error_deg the
-- attitude minus the previous target, vertical_speed_fpm the vertical speed
-- (nil: no climb floor).
function afds_controls.climb_speed_pitch_target(previous_target_deg, speed_change_kts, elapsed_sec,
        actual_speed_kts, target_speed_kts, vertical_direction, pitch_error_deg, vertical_speed_fpm)
    if vertical_direction ~= afds_controls.VERTICAL_DIRECTION_CLIMB then return nil end
    if type(previous_target_deg) ~= "number" or type(speed_change_kts) ~= "number"
        or type(actual_speed_kts) ~= "number" or type(target_speed_kts) ~= "number" then
        return nil
    end
    local speed_error_kts = target_speed_kts - actual_speed_kts
    if math.abs(speed_error_kts) <= afds_controls.CLIMB_SPEED_PITCH_MARGIN_KTS then return nil end
    elapsed_sec = tonumber(elapsed_sec) or 0
    if elapsed_sec <= 0 then return previous_target_deg end
    local acceleration = speed_change_kts / elapsed_sec
    local limit = afds_controls.CLIMB_SPEED_PITCH_MAX_ACCEL_KTS_PER_SEC
    local wanted = clamp(speed_error_kts / afds_controls.CLIMB_SPEED_PITCH_TIME_CONSTANT_SEC, -limit, limit)
    local low, high = wanted, wanted + afds_controls.CLIMB_SPEED_PITCH_ACCEL_BAND_KTS_PER_SEC
    if speed_error_kts < 0 then
        low, high = wanted - afds_controls.CLIMB_SPEED_PITCH_ACCEL_BAND_KTS_PER_SEC, wanted
    end
    pitch_error_deg = tonumber(pitch_error_deg) or 0
    local lag = afds_controls.CLIMB_SPEED_PITCH_ATTITUDE_LAG_DEG
    local rate
    local max_down_rate = afds_controls.CLIMB_SPEED_PITCH_MAX_RATE_DEG_PER_SEC
    vertical_speed_fpm = tonumber(vertical_speed_fpm)
    if vertical_speed_fpm then
        max_down_rate = math.min(max_down_rate, math.max(0,
            vertical_speed_fpm - afds_controls.CLIMB_SPEED_PITCH_MIN_CLIMB_FPM) / 1000
            * afds_controls.CLIMB_SPEED_PITCH_DOWN_RATE_DEG_PER_SEC_PER_KFPM)
    end
    if acceleration < low then
        if pitch_error_deg >= lag or max_down_rate <= 0 then return previous_target_deg end
        rate = -math.min(afds_controls.CLIMB_SPEED_PITCH_GAIN_DEG_PER_KT * (low - acceleration), max_down_rate)
    elseif acceleration > high then
        if pitch_error_deg <= -lag then return previous_target_deg end
        rate = afds_controls.CLIMB_SPEED_PITCH_GAIN_DEG_PER_KT * (acceleration - high)
    else
        return previous_target_deg
    end
    local max_rate = afds_controls.CLIMB_SPEED_PITCH_MAX_RATE_DEG_PER_SEC
    return previous_target_deg + clamp(rate, -max_rate, max_rate) * elapsed_sec
end

return afds_controls
