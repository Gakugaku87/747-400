-- Pure flight-director response calculations.  Lua 5.1 compatible.

local afds_controls = {}

afds_controls.PITCH_TRANSITION_DURATION_SEC = 0.70

afds_controls.VERTICAL_DIRECTION_DESCENT = -1
afds_controls.VERTICAL_DIRECTION_LEVEL = 0
afds_controls.VERTICAL_DIRECTION_CLIMB = 1

-- Speed-on-pitch modes may trade vertical rate for airspeed, but should not
-- reverse the selected vertical direction for an ordinary speed error.
afds_controls.SPEED_PITCH_MIN_TARGET_DEG = -3.5
-- [P39] 25 deg (it was 15): the 744's AFDS has no fixed limit below the pitch limit indicator, and holding V2 + 10
-- after a light takeoff takes 17-22 deg (p35-line1, 233 t: 19.8 deg hand-flown at V2 + 4)
afds_controls.SPEED_PITCH_MAX_TARGET_DEG = 25.0
afds_controls.SPEED_PITCH_CLIMB_MIN_TARGET_DEG = 0.0
afds_controls.SPEED_PITCH_DESCENT_MAX_TARGET_DEG = 5.0
afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM = 100.0
afds_controls.SPEED_PITCH_PHASE_RECOVERY_DEG_PER_SEC = 1.0
-- In a climb, while the VSI shows +100 fpm or less, the target is not left
-- below the attitude that flies level at the current angle of attack and bank
-- (climb_path_pitch_deg) and rises to it at the recovery rate. It used to rise
-- at that rate for as long as the VSI showed more than 100 fpm down, but the
-- VSI lags the flight path and the attitude lags the target, and at altitude
-- 1 deg is about 850 fpm: on 2026-10-10 (final-L1, P4 0dd3b35d) the step
-- climbs began at waypoints where LNAV rolled, a -300 fpm sink in the turn
-- became +4,745 fpm and the speed fell 24 kt below the target. Level, not a
-- climb, so that at a thrust-limited ceiling the speed is still held; only at
-- +100 fpm or less, so that the angle of attack of a hunting attitude ratchets
-- the target up only once the climb has nearly stopped. Without the angle of
-- attack the VSI rule stays.
afds_controls.SPEED_PITCH_CLIMB_PATH_FPM = 0.0
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
-- Outside the approach the filtered command moves at most this fast.
-- X-Plane's HDG SEL slews its command at about 6 deg/s and the filter let the
-- large errors through at up to 25 deg/s; the roll loop, underdamped at
-- altitude, then rolled the aircraft at 7-8.7 deg/s (2026-10-11 final3-L1:
-- a 5 deg heading change at FL310, 14 deg of bank at 8.7 deg/s). The
-- approach (LOC, autoland) keeps its response.
afds_controls.ROLL_FILTER_MAX_SLEW_DEG_PER_SEC = 3.0

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

-- The attitude that climbs at SPEED_PITCH_CLIMB_PATH_FPM (level) at this angle
-- of attack, true airspeed (m/s) and bank (pitch = flight path + alpha x cos
-- bank), or nil without them.
function afds_controls.climb_path_pitch_deg(alpha_deg, true_airspeed_mps, bank_deg)
    if type(alpha_deg) ~= "number" or type(true_airspeed_mps) ~= "number" or true_airspeed_mps <= 0 then
        return nil
    end
    local climb_mps = afds_controls.SPEED_PITCH_CLIMB_PATH_FPM * 0.3048 / 60
    local path_deg = math.deg(math.asin(math.min(1, climb_mps / true_airspeed_mps)))
    return path_deg + alpha_deg * math.cos(math.rad(tonumber(bank_deg) or 0))
end

-- [P37] G/S flies the beam's V/S (getGlideSlopeFPM) as a flight path angle by a PI law (ap_director_pitch): every
-- 0.1 s the path angle the 747 is short of, at most GS_MAX_PATH_ERROR_DEG, moves an integrator by GS_PATH_KI of it
-- a second, from the director's pitch when G/S began, and the director's pitch is the integrator plus GS_PATH_KP of
-- it, less GS_PITCH_RATE_DAMPING (s) x the attitude's rate (deg/s). With the pitch loop as X-Plane flies it
-- (approach_model's pitch_loop: the PID's integral and the two tenth-of-the-way filters) the law that stepped the
-- pitch for the VSI's error hunted around the beam (p32-line1: +-0.6 deg at 13-16 s) and fell behind slowing down
-- on it; the attitude plus the error (review 41) hunted by 5-6 deg. The damping keeps the PI law from hunting at a
-- low frame rate (20 fps: 6-10 pitch reversals from 1,500 to 200 ft without it, 0-2 with it) and with 1.0 rather
-- than 0.6 it holds 1.5 x the gains at 20 fps (review 43); the limit keeps a capture from level flight above the
-- beam (EINN) to about 0.1 g (0.16 g without).
afds_controls.GS_PATH_KP = 0.3
afds_controls.GS_PATH_KI = 0.3
afds_controls.GS_PITCH_RATE_DAMPING = 1.0
afds_controls.GS_MAX_PATH_ERROR_DEG = 1.5
-- The path angle (deg) the 747 is short of: the target V/S (fpm) at the ground speed (m/s, at least 30) against
-- the vertical speed (m/s; the director's from the elevation's rate).
function afds_controls.glide_slope_path_error_deg(target_fpm, vertical_speed_mps, ground_speed_mps)
    local ground_speed = math.max(tonumber(ground_speed_mps) or 0, 30)
    local target = math.atan2((tonumber(target_fpm) or 0) * 0.3048 / 60, ground_speed)
    local actual = math.atan2(tonumber(vertical_speed_mps) or 0, ground_speed)
    return math.deg(target - actual)
end

function afds_controls.limit_speed_pitch_target(requested_target_deg, previous_target_deg, vertical_direction,
        vertical_speed_fpm, actual_speed_kts, target_speed_kts, min_safe_speed_kts, max_safe_speed_kts,
        elapsed_sec, accelerating_to_target, climb_path_pitch_deg)
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
        if type(climb_path_pitch_deg) == "number" then
            if vertical_speed_fpm <= afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM
                and requested_target_deg < climb_path_pitch_deg then
                requested_target_deg = math.max(requested_target_deg,
                    math.min(climb_path_pitch_deg, previous_target_deg + recovery_step_deg))
            end
        elseif vertical_speed_fpm < -afds_controls.SPEED_PITCH_DIRECTION_GUARD_FPM then
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
    if not approach_protected then
        slew_deg_per_sec = math.min(slew_deg_per_sec, afds_controls.ROLL_FILTER_MAX_SLEW_DEG_PER_SEC)
    end

    local alpha = 1 - math.exp(-math.min(elapsed_sec, 0.25) / time_constant_sec)
    local requested_change_deg = error_deg * alpha
    local maximum_change_deg = slew_deg_per_sec * elapsed_sec
    requested_change_deg = clamp(requested_change_deg, -maximum_change_deg, maximum_change_deg)
    return current_deg + requested_change_deg
end

-- [P40] The roll PID's gains at a true airspeed (m/s): 1 up to ROLL_GAIN_TAS_KT, then ROLL_GAIN_TAS_KT / TAS, at
-- least ROLL_GAIN_MIN_SCALE (1 for a TAS that is not a number). The surfaces' roll power grows with the true
-- airspeed while the roll ratio reaches their effect late (the output timing and pressure_output each go a tenth of
-- the way a frame: more time at a low frame rate): light at FL300, M.81 (TAS 480 kt) the loop kept a roll
-- oscillation that grew to +-30-38 deg of bank at about 4.8 s (p33-line1 and its re-fly, 18-27 fps).
afds_controls.ROLL_GAIN_TAS_KT = 340
afds_controls.ROLL_GAIN_MIN_SCALE = 0.7
function afds_controls.roll_gain_scale(true_airspeed_mps)
    local tas_kt = (tonumber(true_airspeed_mps) or 0) * 1.943844
    if tas_kt ~= tas_kt or tas_kt <= afds_controls.ROLL_GAIN_TAS_KT then return 1 end
    return math.max(afds_controls.ROLL_GAIN_MIN_SCALE, afds_controls.ROLL_GAIN_TAS_KT / tas_kt)
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

-- [P43] Speed on pitch (FLCH SPD and VNAV SPD outside the capture window): a flight path law on the acceleration
-- error, every 0.1 s (ap_director_speed_on_pitch). The IAS's rate (speed_pitch_accel) against the acceleration wanted
-- (speed_pitch_wanted_accel: the speed error over SPEED_PITCH_TIME_CONSTANT_SEC within +-1 kt/s; climbing, at most
-- SPEED_PITCH_CLIMB_ACCEL_SHARE of the energy rate) is a flight path the aircraft has too much or too little of
-- (speed_pitch_path_error_deg): the pitch moves SPEED_PITCH_KI of it a second, at most the rate that turns the path
-- with SPEED_PITCH_MAX_LOAD_FACTOR_G (speed_pitch_max_rate_deg: 0.37 deg/s at 150 m/s TAS), plus SPEED_PITCH_KP of it
-- within +-SPEED_PITCH_P_LIMIT_DEG, less SPEED_PITCH_RATE_DAMPING s x the attitude's rate; then
-- limit_speed_pitch_target's guards. The law it replaced moved the pitch by increments
-- 0.3-0.5 s apart (0.01 + 0.5 x the speed change a step near the target; climb_speed_pitch_target's 0.6 deg/s per kt/s
-- of the acceleration missing further away), none while the attitude was 0.5 deg behind, averaged over 10 updates:
-- resuming the climb at 8,950 ft (p35-line1, 2026-10-20) it pitched up at about 0.4 deg/s 4-6 s after the A/T added
-- climb thrust and the IAS went from 251 to 271 kt; FLCH at idle at FL310 (p34-L1) pitched down at 0.08 deg/s and fell
-- 26 kt below the Mach's speed; accelerating at 10,000 ft (p34-L1) it kept 22-31 % of the climb, where 744s in ADS-B
-- keep 40-55 % (median 47 %) at 0.45-0.77 kt/s (research_climb_accel.md: 55-70 % of the energy into the acceleration).
-- In climb_model (the production director and pitch loop on a point mass fitted to those flights): 271 -> 268 kt,
-- -25 -> -8 kt, and 43-57 % of the climb at 0.56 kt/s.
afds_controls.SPEED_PITCH_TIME_CONSTANT_SEC = 20.0
afds_controls.SPEED_PITCH_MAX_ACCEL_KTS_PER_SEC = 1.0
afds_controls.SPEED_PITCH_ACCEL_FILTER_SEC = 1.0
afds_controls.SPEED_PITCH_MAX_IAS_RATE_KTS_PER_SEC = 10.0
afds_controls.SPEED_PITCH_CLIMB_ACCEL_SHARE = 0.6
afds_controls.SPEED_PITCH_KI = 0.10
afds_controls.SPEED_PITCH_MAX_LOAD_FACTOR_G = 0.10
afds_controls.SPEED_PITCH_KP = 0.3
afds_controls.SPEED_PITCH_P_LIMIT_DEG = 1.0
afds_controls.SPEED_PITCH_RATE_DAMPING = 1.0
-- [P45] The thrust's lead: a change of the thrust over the weight (T/W) changes the flight path that holds the speed
-- by as much (radians), so the integrator also turns the path at SPEED_PITCH_THRUST_FEED_FORWARD of T/W's rate,
-- within the same 0.1 g. On its own it followed a thrust ramp with a steady error of (the path's rate) / KI: resuming
-- the climb with the A/T's 20 s to climb thrust (P44) about 3 deg of path, the IAS 11 kt over the target, where 744s
-- in ADS-B are 3 kt (0-6) over with the IAS flat for 10-25 s (research_reclimb.md). A larger KI followed it but took
-- the 10,000 ft acceleration's climb away and turned the flap steps into pitch reversals (review 45).
afds_controls.SPEED_PITCH_THRUST_FEED_FORWARD = 1.0
-- a decrease leads at this share of it: the takeoff's thrust reduction (190 kN an engine to 82 % over 1.5 s at 233 t) at
-- the full rate took the director down at 0.7-1.0 deg/s and the A/P's attitude 1.9 deg below where it settled at -0.104 g
-- (the pitch loop's overshoot after the ramp; P43 alone: 0.02 deg, but the IAS 6.3 kt low; review 46)
afds_controls.SPEED_PITCH_THRUST_DECREASE_SHARE = 0.5
-- only a real decrease: the filtered T/W this much below its peak, which decays by it in SPEED_PITCH_THRUST_PEAK_SEC.
-- Applied to every falling update, the half share turned the thrust's jitter into a steady pitch-up and the IAS sat
-- 1.0-1.4 kt low in the takeoff climb with 3 kN of jitter (review 46b); the jitter moves the filtered T/W 0.001-0.002.
afds_controls.SPEED_PITCH_THRUST_DECREASE_MARGIN = 0.005
afds_controls.SPEED_PITCH_THRUST_PEAK_SEC = 3.0
-- T/W through a first order of this many seconds: X-Plane's thrust moves 1-4 kN an engine in 0.25 s as the A/T works
-- the levers on the takeoff (p35-line1), 0.4-1.6 deg/s of path unfiltered
afds_controls.SPEED_PITCH_THRUST_FILTER_SEC = 2.0
-- a T/W changing faster than this a second is not thrust (engines spool from idle to takeoff thrust's 0.25 in 6-8 s):
-- XTLua's first read of 0, a weight read; the filter starts again from it, and that change is not led. One or two
-- engines' failure does not reach T/W (the shared thrust); a light go-around's spool-up comes near it (180 t, GA thrust
-- in 2.5 s: 0.19 a second; in 4.5 s 0.11; review 46).
afds_controls.SPEED_PITCH_THRUST_MAX_RATE = 0.2

-- The IAS's rate (kt/s): the last one moved towards the IAS's change over elapsed_sec by a first order of
-- SPEED_PITCH_ACCEL_FILTER_SEC. A change faster than SPEED_PITCH_MAX_IAS_RATE_KTS_PER_SEC (a first read of 0, a jump
-- of the instrument) is left out.
function afds_controls.speed_pitch_accel(previous_kts_per_sec, ias_change_kts, elapsed_sec)
    previous_kts_per_sec = tonumber(previous_kts_per_sec) or 0
    elapsed_sec = tonumber(elapsed_sec) or 0
    if elapsed_sec <= 0 or type(ias_change_kts) ~= "number" or ias_change_kts ~= ias_change_kts then
        return previous_kts_per_sec
    end
    local rate = ias_change_kts / elapsed_sec
    if math.abs(rate) > afds_controls.SPEED_PITCH_MAX_IAS_RATE_KTS_PER_SEC then return previous_kts_per_sec end
    return previous_kts_per_sec + (rate - previous_kts_per_sec)
        * math.min(1, elapsed_sec / afds_controls.SPEED_PITCH_ACCEL_FILTER_SEC)
end

-- The acceleration (kt/s of IAS) wanted: the speed error over SPEED_PITCH_TIME_CONSTANT_SEC within
-- +-SPEED_PITCH_MAX_ACCEL_KTS_PER_SEC. Climbing, an acceleration of at most SPEED_PITCH_CLIMB_ACCEL_SHARE of the
-- energy rate (the IAS's rate and the climb's g sin(path) in kt/s of IAS, from the vertical speed in fpm and the TAS in
-- m/s), none when that is not positive: the rest of it keeps climbing.
function afds_controls.speed_pitch_wanted_accel(target_kts, ias_kts, climbing, accel_kts_per_sec, vertical_speed_fpm,
        tas_mps)
    if type(target_kts) ~= "number" or type(ias_kts) ~= "number" then return 0 end
    local limit = afds_controls.SPEED_PITCH_MAX_ACCEL_KTS_PER_SEC
    local wanted = clamp((target_kts - ias_kts) / afds_controls.SPEED_PITCH_TIME_CONSTANT_SEC, -limit, limit)
    if climbing and wanted > 0 then
        local tas = math.max(tonumber(tas_mps) or 0, 30)
        local climb = (9.80665 / 0.514444) * ((tonumber(vertical_speed_fpm) or 0) * 0.00508 / tas)
            * (ias_kts * 0.514444 / tas)
        local energy = (tonumber(accel_kts_per_sec) or 0) + climb
        wanted = math.min(wanted, math.max(0, afds_controls.SPEED_PITCH_CLIMB_ACCEL_SHARE * energy))
    end
    return wanted
end

-- The pitch rate (deg/s) that turns the flight path with SPEED_PITCH_MAX_LOAD_FACTOR_G at a TAS (m/s, at least 60).
function afds_controls.speed_pitch_max_rate_deg(tas_mps)
    return math.deg(afds_controls.SPEED_PITCH_MAX_LOAD_FACTOR_G * 9.80665 / math.max(tonumber(tas_mps) or 0, 60))
end

-- [P45] The thrust's lead over elapsed_sec: T/W (tw, nil when unknown; previous_tw at the last update) through
-- SPEED_PITCH_THRUST_FILTER_SEC's first order from filtered_tw, and the path's rate (deg/s) its change asks for,
-- SPEED_PITCH_THRUST_FEED_FORWARD of it; a decrease SPEED_PITCH_THRUST_DECREASE_SHARE of that once the filtered T/W is
-- SPEED_PITCH_THRUST_DECREASE_MARGIN below peak_tw, its peak (decaying by the margin in SPEED_PITCH_THRUST_PEAK_SEC).
-- The filter starts from tw with no rate after an unknown T/W or a change faster than SPEED_PITCH_THRUST_MAX_RATE.
-- Returns the filtered T/W (nil when unknown), the rate and the peak.
function afds_controls.speed_pitch_thrust_lead(filtered_tw, previous_tw, tw, elapsed_sec, peak_tw)
    elapsed_sec = tonumber(elapsed_sec) or 0
    if tw == nil then return nil, 0, nil end
    if filtered_tw == nil or previous_tw == nil or elapsed_sec <= 0
        or math.abs(tw - previous_tw) > afds_controls.SPEED_PITCH_THRUST_MAX_RATE * elapsed_sec then
        return tw, 0, tw
    end
    local next_tw = filtered_tw
        + (tw - filtered_tw) * math.min(1, elapsed_sec / afds_controls.SPEED_PITCH_THRUST_FILTER_SEC)
    local margin = afds_controls.SPEED_PITCH_THRUST_DECREASE_MARGIN
    local peak = math.max(next_tw, (tonumber(peak_tw) or filtered_tw)
        - margin / afds_controls.SPEED_PITCH_THRUST_PEAK_SEC * elapsed_sec)
    local rate = afds_controls.SPEED_PITCH_THRUST_FEED_FORWARD * math.deg(next_tw - filtered_tw) / elapsed_sec
    if rate < 0 and next_tw < peak - margin then rate = rate * afds_controls.SPEED_PITCH_THRUST_DECREASE_SHARE end
    return next_tw, rate, peak
end

-- [P45] The engines' shared thrust over the weight: thrust_n the four engines' thrust (N, indexed 0-3:
-- sim/flightmodel/engine/POINT_thrust), mass_kg the aircraft's mass (sim/flightmodel/weight/m_total); nil without a
-- mass a 747 can have (XTLua's first read gives 0). The shared thrust is 4 x the second-highest engine's: the A/T
-- moves the four levers together, and one or two engines' loss (a failure, a lever) is left to the integrator. Fed the
-- sum, an engine failure at 397 t with 400 fpm on three engines took the director down at the law's 0.1 g and the
-- climb to -100 fpm for about 5 s (review 46); the two middle engines' mean read a second engine's failure at twice
-- its size, and two failing on one side at 300 t took the climb to -33 fpm (review 46b). After a failure a change of
-- the engines left is read at 4/3 (one failed) or 2 (two).
function afds_controls.speed_pitch_thrust_weight(thrust_n, mass_kg)
    local mass = tonumber(mass_kg)
    if mass == nil or mass < 100000 or thrust_n == nil then return nil end
    local thrust = {}
    for i = 0, 3 do thrust[i + 1] = tonumber(thrust_n[i]) or 0 end
    table.sort(thrust)
    return 4 * thrust[3] / (mass * 9.80665)
end

-- [review 45] ALT (15 deg) and V/S and VNAV PTH (10 deg) taking over above their upper pitch limit: the pitch comes
-- down to it from the previous one at the speed law's 0.1 g (speed_pitch_max_rate_deg at the TAS, m/s), whatever the
-- branch's own law wants. Since P39 the speed modes go to 25 deg, and a capture or a V/S selection from a light
-- takeoff's 16-20 deg climb took the director to the limit in one update, the V/S law its own steps on: in climb_model
-- -0.36 to -0.39 g into ALT, -0.57 to -0.59 g into V/S. Returns the upper limit for this update and the lowest pitch
-- (-math.huge at or below the limit).
function afds_controls.pitch_cap_approach(cap_deg, previous_deg, elapsed_sec, tas_mps)
    previous_deg = tonumber(previous_deg) or cap_deg
    if previous_deg <= cap_deg then return cap_deg, -math.huge end
    local next_deg = math.max(cap_deg, previous_deg
        - afds_controls.speed_pitch_max_rate_deg(tas_mps) * clamp(tonumber(elapsed_sec) or 0, 0, 0.5))
    return next_deg, next_deg
end

-- [P39] TO/GA's speed (FCOM vol 2, quoted by a BA 744 captain and confirmed by Aerowinx, topic 2796.20 reply 24;
-- research_afds_climb.md 1): after takeoff the AFDS commands a pitch below the pitch limit indicator to hold the
-- greater of V2 + 10 kt and the IAS when the pitch passed 2 deg on the takeoff roll (the rotation) + 10 kt; if the IAS
-- stays above it for 5 s the target becomes the IAS, at most V2 + 25 kt; the IAS/MACH window's speed when it is set
-- above it. The AFDS takes the window's speed, set to V2 before the start, as V2: here the FMC's V2 when it has one.
-- In a go-around the window's speed, and the same 5 s reset to the IAS, at most the window's + 25 kt (FCOM vol 2
-- 4.20.16 as quoted on AVSIM: "the target airspeed is reset to current airspeed (to a maximum of the IAS/MACH window
-- speed plus 25 knots)").
afds_controls.TOGA_TARGET_ABOVE_V2_KTS = 10
afds_controls.TOGA_TARGET_LIMIT_ABOVE_V2_KTS = 25
afds_controls.TOGA_TARGET_RESET_SEC = 5
afds_controls.TOGA_ROTATION_PITCH_DEG = 2
afds_controls.TOGA_GO_AROUND_LIMIT_ABOVE_WINDOW_KTS = 25

-- TO/GA's speed (kt) for state (a table the caller keeps; TO/GA again after more than a second without a call), or nil
-- on the ground (the F/D is parked there). v2_kts: the FMC's V2 (none at 0 or 900+: the window's speed), window_kts:
-- the IAS/MACH window's speed (none below 60 kt: the IAS), time_sec: the simulator's time, floor_kts: a go-around's
-- lowest target, taken as TO/GA comes on (the add-on's Vmc, fltInst02's minimum manoeuvring speed for the flaps: a
-- window set low; kept as the flaps come up, as the FCOM's target does; review 45c). A takeoff when TO/GA was on on
-- the ground (no floor: with takeoff flaps that speed is above V2), a go-around when it came on in the air.
function afds_controls.toga_target_speed(state, on_ground, pitch_deg, ias_kts, v2_kts, window_kts, time_sec, floor_kts)
    ias_kts = tonumber(ias_kts) or 0
    time_sec = tonumber(time_sec) or 0
    local window = tonumber(window_kts)
    if window ~= nil and window < 60 then window = nil end
    if state.time == nil or time_sec - state.time > 1 or time_sec < state.time then
        state.v2, state.rotation_ias, state.target, state.limit, state.above_since, state.go_around =
            nil, nil, nil, nil, nil, false
    end
    state.time = time_sec
    if on_ground then
        local v2 = tonumber(v2_kts)
        if v2 == nil or v2 <= 0 or v2 >= 900 then v2 = window end
        state.v2, state.target, state.above_since, state.go_around = v2, nil, nil, false
        if ias_kts < 60 then
            state.rotation_ias = nil
        elseif state.rotation_ias == nil and (tonumber(pitch_deg) or 0) > afds_controls.TOGA_ROTATION_PITCH_DEG then
            state.rotation_ias = ias_kts
        end
        return nil
    end
    if state.target == nil then
        if state.v2 == nil then
            -- a go-around: the window's speed (the IAS when it reads none), at least the floor, up to it + 25 kt
            state.go_around = true
            state.target = math.max(window or ias_kts, tonumber(floor_kts) or 0)
            state.limit = state.target + afds_controls.TOGA_GO_AROUND_LIMIT_ABOVE_WINDOW_KTS
        else
            state.target = math.max(state.v2, state.rotation_ias or state.v2) + afds_controls.TOGA_TARGET_ABOVE_V2_KTS
            state.limit = state.v2 + afds_controls.TOGA_TARGET_LIMIT_ABOVE_V2_KTS
        end
    end
    -- above the target for 5 s: the IAS, at most the limit
    if ias_kts > state.target and state.target < state.limit then
        state.above_since = state.above_since or time_sec
        if time_sec - state.above_since >= afds_controls.TOGA_TARGET_RESET_SEC then
            state.target = math.min(ias_kts, state.limit)
            state.above_since = time_sec
        end
    else
        state.above_since = nil
    end
    if window ~= nil and window > state.target then return window end
    return state.target
end

-- The flight path (deg) the aircraft has too much of (+: it accelerates more than wanted) or too little (-): 1 deg of
-- path is g/57.3 m/s^2 of TAS a second, IAS/TAS of that in IAS.
function afds_controls.speed_pitch_path_error_deg(accel_kts_per_sec, wanted_kts_per_sec, tas_mps, ias_kts)
    local tas = math.max(tonumber(tas_mps) or 0, 30)
    local ias = math.max((tonumber(ias_kts) or 0) * 0.514444, 30)
    return math.deg(0.514444 / 9.80665) * tas / ias
        * ((tonumber(accel_kts_per_sec) or 0) - (tonumber(wanted_kts_per_sec) or 0))
end

-- [B-10] The yaw dampers' law, both channels alike: the 747-400's Dutch roll damping and turn coordination. The rudder
-- command (-1..1, the dampers' authority) is against the yaw rate less the yaw rate of a coordinated turn at this bank
-- and true airspeed, washed out with YAW_DAMPER_WASHOUT_SEC so that a steady yaw rate keeps no rudder, at the 747's
-- gain (P25, below; ias_kts is not used). The yaw rate is the stability axes', r cos(alpha) - p sin(alpha) from X-Plane's
-- body axes' yaw and roll rates (sim/flightmodel/position/R, P) and the angle of attack: rolling about the flight path
-- the body axes yaw by p sin(alpha), which is no Dutch roll (p11-L1: +0.040 p above 270 kt, +0.077 p below 200 kt), and
-- the dampers put rudder against a roll-in (-0.29 of their command rolling in at 3 deg/s, 160 kt, alpha 6 deg; a
-- review). A coordinated turn's is g sin(bank) / TAS (the heading's rate times cos(bank); recorded at 19.9 deg, FL310,
-- 301 kt: 0.77-0.78 deg/s). Taking the heading's rate, g tan(bank) / TAS, the dampers put rudder into a roll-in (+0.24
-- of their command rolling into 30 deg at 160 kt; a review). One law at every bank, the same both ways, at any frame
-- rate. state is a table the caller keeps; the first call, or one after a gap of more than a second, starts the filter
-- (0). roll_rate_dps and alpha_deg: 0 without.
-- [P25] The gain and filters are the 747's (NASA CR-2144, Heffley and Jewell 1972, Fig IX-4, from Boeing's 747
-- simulator description D6-30643): delta_r = 5.05 s / ((s + 0.368)(s + 3.68)) r flaps up - the yaw rate through a
-- 2.72 s washout and a 0.27 s lag, 1.37 deg of rudder per deg/s - and twice that with the flaps out (blended over the
-- flap handle's first detent; the 747-100's law adds bank-angle terms there, which the coordinated turn's yaw rate
-- taken away stands for here). The command's +-1 is each damper's authority, +-4 deg of rudder command (FAA NPRM
-- FAA-2011-0571, 76 FR 36391, which puts the damper's piston in each rudder's PCM and does not say whether the 4 deg
-- changes with the airspeed: taken here at any airspeed, past the pedals' ratio changer; hydraulicsmodel.lua's control
-- overrides). It was +-3.5 deg times the pedals' rudder
-- ratio (2.0 deg at 300 kt) with a gain against the IAS (0.8 to 1.6 times 0.6 of the command per deg/s), no lag and a
-- 2.5 s washout: about the 747's at 300 kt, half its authority, and about 20 % above it at 160 kt with the flaps out
-- (at the Dutch roll's 0.9 rad/s).
afds_controls.YAW_DAMPER_WASHOUT_SEC = 2.72
afds_controls.YAW_DAMPER_LAG_SEC = 0.27
afds_controls.YAW_DAMPER_AUTHORITY_DEG = 4.0
afds_controls.YAW_DAMPER_GAIN_DEG_PER_DEG_SEC = 1.37
afds_controls.YAW_DAMPER_FLAPS_DOUBLE_RATIO = 1 / 6    -- the flap handle ratio (flaps 1) where the gain is doubled
-- [review 23] X-Plane's rudder follows the dampers' output a tenth of the way a frame (hydraulics_override.lua's
-- pressure_output, B747_animate_value: 9 frames behind on average, 0.18 s at 50 fps and 0.30 s at 30 fps), a frame
-- after the cable controls have the output and a frame before the flight model has the rudder (the control override
-- rows). YAW_DAMPER_LAG_SEC is the lag all the way to the rudder; the law's own is what those 11 frames leave of it
-- (0.05 s at 50 fps, none below 41 fps). The law's whole 0.27 s on top of them put the rudder 11 deg behind CR-2144's
-- law at the Dutch roll's 0.9 rad/s at 50 fps and 18 deg at 30 fps (a review: the damping fell with the frame rate).
afds_controls.YAW_DAMPER_RUDDER_FRAMES = 11

-- whether x is no NaN nor infinite (nil is: the inputs that may be missing default to 0)
local function finite(x)
    return x == x and x ~= math.huge and x ~= -math.huge
end

function afds_controls.yaw_damper_command(state, yaw_rate_dps, bank_deg, tas_mps, ias_kts, time_s, roll_rate_dps,
        alpha_deg, flap_ratio)
    -- an input that is no number (NaN) or infinite starts the filter again, as a gap does (math.min and math.max pass
    -- NaN through in LuaJIT: the filter kept it, and the rudder command was NaN; inf - inf left NaN in it, and the
    -- output stayed 0 under LuaJIT or +1 under Lua 5.1: a review)
    if not (finite(yaw_rate_dps) and finite(bank_deg) and finite(tas_mps) and finite(ias_kts) and finite(time_s)
        and finite(roll_rate_dps) and finite(alpha_deg) and finite(flap_ratio)) then
        state.time, state.command = nil, 0
        return 0
    end
    local coordinated = 0
    if tas_mps ~= nil and tas_mps > 50 then
        local bank = math.max(-60, math.min(60, bank_deg or 0))
        coordinated = math.deg(9.80665 * math.sin(math.rad(bank)) / tas_mps)
    end
    local alpha = math.rad(math.max(-30, math.min(30, alpha_deg or 0)))
    local input = (yaw_rate_dps or 0) * math.cos(alpha) - (roll_rate_dps or 0) * math.sin(alpha) - coordinated
    local dt = state.time ~= nil and time_s - state.time or nil
    if dt == nil or dt < 0 or dt > 1.0 then
        state.time, state.input, state.washed, state.lagged, state.command = time_s, input, 0, 0, 0
        return 0
    end
    if dt == 0 then return state.command end
    local washout = afds_controls.YAW_DAMPER_WASHOUT_SEC
    local lag = math.max(0, afds_controls.YAW_DAMPER_LAG_SEC - afds_controls.YAW_DAMPER_RUDDER_FRAMES * dt)
    state.washed = washout / (washout + dt) * (state.washed + input - state.input)
    state.lagged = (state.lagged or 0) + dt / (lag + dt) * (state.washed - (state.lagged or 0))
    state.input, state.time = input, time_s
    local flaps = math.max(0, math.min(1, (flap_ratio or 0) / afds_controls.YAW_DAMPER_FLAPS_DOUBLE_RATIO))
    local gain = afds_controls.YAW_DAMPER_GAIN_DEG_PER_DEG_SEC * (1 + flaps) / afds_controls.YAW_DAMPER_AUTHORITY_DEG
    state.command = math.max(-1, math.min(1, -gain * state.lagged))
    return state.command
end

-- A yaw damper channel's output moving towards its command at most over its range (-1..1) in
-- YAW_DAMPER_FULL_TRAVEL_SEC, the same at any frame rate (B747_interpolate_value moved it a tenth of the way a frame
-- near the command and then by a whole step: stair steps of 0.22 at 30 fps, and a lag that grew with the frame time)
afds_controls.YAW_DAMPER_FULL_TRAVEL_SEC = 0.3
function afds_controls.yaw_damper_slew(current, command, elapsed_sec)
    if not finite(current) then current = 0 end
    if not finite(command) then command = 0 end
    if not finite(elapsed_sec) then elapsed_sec = 0 end
    local step = 2 / afds_controls.YAW_DAMPER_FULL_TRAVEL_SEC * math.max(elapsed_sec or 0, 0)
    return current + math.max(-step, math.min(step, command - current))
end

return afds_controls
