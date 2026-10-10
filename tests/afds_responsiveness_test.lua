local nav = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.afds_helpers.lua")
local controls = dofile("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulics_afds_helpers.lua")

local tests_run = 0

local function assert_equal(actual, expected, message)
    tests_run = tests_run + 1
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end

local function assert_near(actual, expected, tolerance, message)
    tests_run = tests_run + 1
    assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        (message or "values not near") .. ": expected " .. tostring(expected)
        .. " +/- " .. tostring(tolerance) .. ", got " .. tostring(actual))
end

-- Turn radius: R = V^2 / (g * tan(bank)).
assert_near(nav.turn_radius_nm(180, 25), 1.013, 0.01, "180 kt / 25 degree radius")
assert_near(nav.turn_radius_nm(250, 25), 1.954, 0.02, "250 kt / 25 degree radius")
assert_near(nav.turn_radius_nm(450, 15), 11.00, 0.1, "450 kt / 15 degree radius")
assert_equal(nav.turn_radius_nm(0, 25), nil, "zero speed is invalid")
assert_equal(nav.turn_radius_nm(250, 0), nil, "zero bank is invalid")

local small_turn = nav.turn_anticipation_nm(250, 25, 10, 0.5, 8.0)
local medium_turn = nav.turn_anticipation_nm(250, 25, 45, 0.5, 8.0)
local right_angle_turn = nav.turn_anticipation_nm(250, 25, 90, 0.5, 8.0)
local straight_turn = nav.turn_anticipation_nm(250, 25, 0.5, 0.5, 8.0)
local reversal_turn = nav.turn_anticipation_nm(250, 25, 179, 0.5, 8.0)
local clamped_turn = nav.turn_anticipation_nm(450, 15, 120, 0.5, 8.0)
assert_near(small_turn, 0.5, 0.001, "small turn lower clamp")
assert_near(medium_turn, 0.809, 0.02, "medium turn anticipation")
assert_near(right_angle_turn, 1.954, 0.02, "90 degree turn anticipation")
assert_equal(straight_turn, 0, "near-zero turn")
assert_equal(reversal_turn, nil, "reversal geometry is rejected")
assert_equal(clamped_turn, 8.0, "turn anticipation upper clamp")

local watched_values = {
    {key = "accel_height_ft", reason = "selected ACCEL HT changed"},
    {key = "flap_bucket", reason = "flap speed limit changed"},
    {key = "climb_speed", reason = "FMC climb speed changed"},
    {key = "leg_index", reason = "flight-plan leg sequenced"}
}
local previous = {
    pressure_alt_ft = 1490, accel_height_ft = 1500, flap_bucket = 5,
    climb_speed = 250, leg_index = 3
}
local current = {
    pressure_alt_ft = 1510, accel_height_ft = 1500, flap_bucket = 5,
    climb_speed = 250, leg_index = 3
}
assert_equal(nav.vnav_speed_change_reason(previous, current,
    {above = 1500, above_reason = "crossed selected ACCEL HT"}, watched_values),
    "crossed selected ACCEL HT", "ACCEL HT crossing")

current.pressure_alt_ft = previous.pressure_alt_ft
current.flap_bucket = 10
assert_equal(nav.vnav_speed_change_reason(previous, current, {}, watched_values),
    "flap speed limit changed", "flap-position change")
current.flap_bucket = previous.flap_bucket
current.climb_speed = 270
assert_equal(nav.vnav_speed_change_reason(previous, current, {}, watched_values),
    "FMC climb speed changed", "FMC speed-value change")
current.climb_speed = previous.climb_speed
current.leg_index = 4
assert_equal(nav.vnav_speed_change_reason(previous, current, {}, watched_values),
    "flight-plan leg sequenced", "leg sequencing")

assert_equal(nav.should_schedule_ias_update(false), true, "unscheduled IAS update is accepted")
assert_equal(nav.should_schedule_ias_update(true), false, "duplicate IAS update is rejected")

assert_equal(nav.climb_speed_key_for_state("aptres"), "clbrestspd",
    "climb restriction state uses SPD REST")
assert_equal(nav.climb_speed_key_for_state("spcres"), "transpd",
    "below-transition climb state uses SPD TRANS")
assert_equal(nav.climb_speed_key_for_state("nores"), "clbspd",
    "unrestricted climb state uses ECON CLB")
assert_equal(nav.climb_speed_key_for_state("crz"), nil,
    "cruise state does not select an IAS climb field")
local climb_profile = {
    clbrestspd = "210",
    transpd = "250",
    clbspd = "272"
}
assert_equal(nav.climb_speed_for_state("aptres", climb_profile), 210,
    "SPD REST value is selected below its altitude")
assert_equal(nav.climb_speed_for_state("spcres", climb_profile), 250,
    "SPD TRANS value is selected below transition altitude")
assert_equal(nav.climb_speed_for_state("nores", climb_profile), 272,
    "ECON CLB value is selected above transition altitude")

-- [g-3] CAS to Mach with the ISA pressure ratio of the FMC performance model,
-- and the climb CAS/Mach crossover judged on the CAS target.
local performance = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.performance.lua")
assert_near(nav.cas_to_mach(326, 31000), 0.869, 0.002, "326 kt at FL310")
assert_near(nav.cas_to_mach(300.4, 31000), 0.807, 0.002, "recorded 300.4 kt at FL310")
assert_near(nav.cas_to_mach(performance.mach_to_cas_kts(0.815, 31000), 31000), 0.815, 0.0001,
    "CAS to Mach inverts the FMC Mach to CAS at FL310")
assert_near(nav.cas_to_mach(performance.mach_to_cas_kts(0.78, 39000), 39000), 0.78, 0.0001,
    "CAS to Mach inverts the FMC Mach to CAS above the tropopause")
assert_equal(nav.cas_to_mach(nil, 31000), nil, "missing CAS has no Mach")
-- Arguments: CAS target, climb Mach, pressure altitude, current Mach, is_mach.
assert_equal(nav.climb_speed_uses_mach(326, 0.815, 31000, 0.807, 0), true,
    "CAS target above the climb Mach selects Mach")
assert_equal(nav.climb_speed_uses_mach(272, 0.78, 12000, 0.70, 1), false,
    "CAS target below the climb Mach stays on CAS")
assert_equal(nav.climb_speed_uses_mach(272, 0.78, 12000, 0.79, 0), true,
    "current Mach above the climb Mach still selects Mach")
-- 302.5 kt is M.812 at FL310: below the M.815 climb Mach, within 0.005 of it.
assert_equal(nav.climb_speed_uses_mach(302.5, 0.815, 31000, 0.70, 0), false,
    "CAS target just below the climb Mach stays on CAS")
assert_equal(nav.climb_speed_uses_mach(302.5, 0.815, 31000, 0.70, 1), true,
    "selected Mach is kept within 0.005 of the climb Mach")
assert_equal(nav.climb_speed_uses_mach(300, 0.815, 31000, 0.70, 1), false,
    "selected Mach returns to CAS more than 0.005 below the climb Mach")

local function energy_guidance(path_error_ft, actual_speed_kts, nominal_vspeed_fpm,
        speed_trend_kts_per_sec, previous_path_axis, previous_speed_axis, protection_active)
    return nav.vnav_energy_guidance({
        path_error_ft = path_error_ft,
        path_trend_fpm = 0,
        target_speed_kts = 250,
        actual_speed_kts = actual_speed_kts,
        speed_trend_kts_per_sec = speed_trend_kts_per_sec or 0,
        nominal_vspeed_fpm = nominal_vspeed_fpm or -1800,
        min_safe_speed_kts = 210,
        previous_path_axis = previous_path_axis,
        previous_speed_axis = previous_speed_axis,
        protection_active = protection_active
    })
end

local above_above = energy_guidance(500, 265)
assert_equal(above_above.state, nav.VNAV_ENERGY_STATE_ABOVE_ABOVE,
    "above path / above speed quadrant")
assert(above_above.target_vspeed_fpm < -1800,
    "above path / above speed commands more descent")
tests_run = tests_run + 1
assert_equal(above_above.thrust_policy, nav.VNAV_ENERGY_THRUST_IDLE,
    "above path / above speed retains idle thrust")
assert_equal(above_above.drag_required, true,
    "above path / above speed requests drag")

local above_below = energy_guidance(500, 240)
assert_equal(above_below.state, nav.VNAV_ENERGY_STATE_ABOVE_BELOW,
    "above path / below speed quadrant")
assert(above_below.target_vspeed_fpm < above_above.target_vspeed_fpm,
    "above path / below speed exchanges more altitude for speed")
tests_run = tests_run + 1
assert_equal(above_below.thrust_policy, nav.VNAV_ENERGY_THRUST_IDLE,
    "recoverable above path / below speed retains idle thrust")

local below_below = energy_guidance(-500, 240)
assert_equal(below_below.state, nav.VNAV_ENERGY_STATE_BELOW_BELOW,
    "below path / below speed quadrant")
assert(below_below.target_vspeed_fpm > -1800,
    "below path / below speed reduces descent")
tests_run = tests_run + 1
assert_equal(below_below.thrust_policy, nav.VNAV_ENERGY_THRUST_ALLOW,
    "below path / below speed permits thrust")

local below_above = energy_guidance(-500, 260)
assert_equal(below_above.state, nav.VNAV_ENERGY_STATE_BELOW_ABOVE,
    "below path / above speed quadrant")
assert(below_above.target_vspeed_fpm > -1800,
    "below path / above speed reduces descent")
tests_run = tests_run + 1
assert_equal(below_above.thrust_policy, nav.VNAV_ENERGY_THRUST_IDLE,
    "below path / above speed does not add thrust")

local protected = energy_guidance(500, 230)
assert_equal(protected.thrust_policy, nav.VNAV_ENERGY_THRUST_ALLOW,
    "genuine underspeed protection permits thrust above path")
assert_equal(protected.thrust_reason, nav.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION,
    "underspeed protection reason")
local protected_hysteresis = energy_guidance(500, 238, -1800, 0, 1, -1, true)
assert_equal(protected_hysteresis.protection_active, true,
    "underspeed protection remains latched inside release hysteresis")
local protected_released = energy_guidance(500, 241, -1800, 0, 1, -1, true)
assert_equal(protected_released.protection_active, false,
    "underspeed protection releases above its hysteresis band")

local limited_recovery = energy_guidance(2000, 240, -2500, -0.1)
assert_equal(limited_recovery.recovery_limited, true,
    "path recovery identifies descent-rate saturation")
assert_equal(limited_recovery.thrust_reason, nav.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED,
    "limited pitch recovery may permit protected thrust")
assert_equal(limited_recovery.drag_required, true,
    "unrecoverable high path preserves DRAG REQUIRED")

local path_axis, speed_axis = nav.vnav_energy_axes(160, -6, 0, 0)
assert_equal(path_axis, 1, "path axis enters above-path state")
assert_equal(speed_axis, -1, "speed axis enters below-speed state")
path_axis, speed_axis = nav.vnav_energy_axes(100, -3, path_axis, speed_axis)
assert_equal(path_axis, 1, "path axis holds inside hysteresis")
assert_equal(speed_axis, -1, "speed axis holds inside hysteresis")
path_axis, speed_axis = nav.vnav_energy_axes(70, -1, path_axis, speed_axis)
assert_equal(path_axis, 0, "path axis exits below hysteresis")
assert_equal(speed_axis, 0, "speed axis exits below hysteresis")

assert_near(nav.rate_limit(-1800, -3000, 0.5, 400, 600), -2000, 0.001,
    "steeper descent command rate limit")
assert_near(nav.rate_limit(-1800, -1000, 0.5, 400, 600), -1500, 0.001,
    "shallower descent command rate limit")

local vnav_path_mode = {
    in_vnav_descent = 1,
    vnav_state = 2,
    active_pitch_mode = 6,
    vs_status = 2,
    flch_status = 0,
    alt_hold_status = 0,
    gs_status = 0,
    actual_gs_status = 0,
    approach_mode = 0,
    actual_approach_status = 0,
    autoland = 0,
    active_land = 0,
    radar_alt_ft = 5000,
    altitude_to_capture_ft = 5000,
    capture_window_ft = 1000
}
assert_equal(nav.vnav_energy_mode_is_active(vnav_path_mode), true,
    "combined energy control is active only in established VNAV PATH descent")
for _, excluded_mode in ipairs({
    {"FLCH", "flch_status", 2},
    {"altitude capture", "alt_hold_status", 2},
    {"glideslope", "gs_status", 1},
    {"actual glideslope", "actual_gs_status", 1},
    {"approach", "approach_mode", 1},
    {"actual approach", "actual_approach_status", 1},
    {"autoland", "autoland", 1},
    {"active landing", "active_land", 1},
    {"non-PTH pitch mode", "active_pitch_mode", 4},
    {"external V/S", "vnav_state", 0}
}) do
    local field = excluded_mode[2]
    local original = vnav_path_mode[field]
    vnav_path_mode[field] = excluded_mode[3]
    assert_equal(nav.vnav_energy_mode_is_active(vnav_path_mode), false,
        excluded_mode[1] .. " is isolated from VNAV energy control")
    vnav_path_mode[field] = original
end
vnav_path_mode.altitude_to_capture_ft = 900
assert_equal(nav.vnav_energy_mode_is_active(vnav_path_mode), false,
    "altitude-capture window is isolated from VNAV energy control")

assert_near(controls.pitch_transition_value(2, 8, 0, 0.7), 2, 0.0001, "pitch blend start")
assert_near(controls.pitch_transition_value(2, 8, 0.35, 0.7), 5, 0.0001, "pitch blend midpoint")
assert_near(controls.pitch_transition_value(2, 8, 0.7, 0.7), 8, 0.0001, "pitch blend completion")
local variable_frame_elapsed = 0
for _, frame_duration in ipairs({0.016, 0.033, 0.101, 0.2}) do
    variable_frame_elapsed = variable_frame_elapsed + frame_duration
end
assert_near(controls.pitch_transition_value(2, 8, variable_frame_elapsed, 0.7),
    2 + (6 * variable_frame_elapsed / 0.7), 0.0001, "variable-frame pitch blend")
assert(controls.pitch_controller_update_due(true, 0, 0.3),
    "a pitch mode change must update the controller immediately")
assert(not controls.pitch_controller_update_due(false, 0.05, 0.3),
    "transition display refresh must not accelerate the pitch controller")
assert(controls.pitch_controller_update_due(false, 0.3, 0.3),
    "pitch controller must update at its normal sample interval")

assert_equal(controls.vertical_direction_for_altitude(10000, 20000, 200),
    controls.VERTICAL_DIRECTION_CLIMB, "selected-altitude climb direction")
assert_equal(controls.vertical_direction_for_altitude(20000, 10000, 200),
    controls.VERTICAL_DIRECTION_DESCENT, "selected-altitude descent direction")
assert_equal(controls.vertical_direction_for_altitude(10000, 10100, 200),
    controls.VERTICAL_DIRECTION_LEVEL, "altitude capture direction")

assert_near(controls.limit_speed_pitch_target(-0.2, 0.1, controls.VERTICAL_DIRECTION_CLIMB,
    800, 245, 250, 160, 340, 0.3), 0.0, 0.0001, "climb target cannot cross below level")
assert_near(controls.limit_speed_pitch_target(2.9, 3.0, controls.VERTICAL_DIRECTION_CLIMB,
    800, 245, 250, 160, 340, 0.3), 2.9, 0.0001, "climb may trade excess climb rate for speed")
assert_near(controls.limit_speed_pitch_target(2.9, 3.0, controls.VERTICAL_DIRECTION_CLIMB,
    50, 245, 250, 160, 340, 0.3), 3.0, 0.0001, "climb pitch-down stops near level flight")
assert_near(controls.limit_speed_pitch_target(3.0, 3.0, controls.VERTICAL_DIRECTION_CLIMB,
    -200, 245, 250, 160, 340, 0.3), 3.3, 0.0001, "wrong-way climb recovers upward")
assert_near(controls.limit_speed_pitch_target(-0.2, 0.1, controls.VERTICAL_DIRECTION_CLIMB,
    50, 230, 250, 160, 340, 0.3), -0.2, 0.0001, "severe underspeed overrides climb floor")

-- [g-1] The minimum safe speed (Vmc + 10 kt) never lifts the severe underspeed
-- threshold above target - 5 kt. Flaps 20 at 310 t: Vmc + 10 kt is 174.2 kt,
-- above the V2 + 10 kt target of 169.5 kt, so the climb guard used to drop
-- with the speed on target.
assert_near(controls.severe_underspeed_threshold(169.5, 174.2), 164.5, 0.0001,
    "minimum safe speed above the target is capped at target - 5 kt")
assert_near(controls.severe_underspeed_threshold(250, 160), 235, 0.0001,
    "target - 15 kt above the minimum safe speed is unchanged")
assert_near(controls.severe_underspeed_threshold(200, 190), 190, 0.0001,
    "minimum safe speed below target - 5 kt is unchanged")
local on_target_pitch, on_target_severe = controls.limit_speed_pitch_target(9.0, 10.0,
    controls.VERTICAL_DIRECTION_CLIMB, 50, 170.0, 169.5, 174.2, 365, 0.3)
assert_near(on_target_pitch, 10.0, 0.0001, "initial climb on the V2 + 10 target keeps the climb guard")
assert_equal(on_target_severe, false, "initial climb on the V2 + 10 target is not a severe underspeed")
local slow_pitch, slow_severe = controls.limit_speed_pitch_target(9.0, 10.0,
    controls.VERTICAL_DIRECTION_CLIMB, 50, 147.6, 169.5, 174.2, 365, 0.3)
assert_near(slow_pitch, 9.0, 0.0001, "initial climb 22 kt slow may still pitch down")
assert_equal(slow_severe, true, "initial climb 22 kt slow is a severe underspeed")

-- [g-2] Accelerating to a raised speed target (flap retraction +20 kt, 250 to
-- 326 kt at 10,000 ft) is latched: set when the target rises 5 kt or more
-- above the reference while the speed is above the minimum safe speed, kept
-- until the speed is within 5 kt of the target. Arguments: latched, reference
-- target, target, IAS, minimum safe speed.
assert_equal(controls.update_speed_target_acceleration(false, 250, 326, 249, 225), true,
    "a 76 kt target step latches the acceleration")
assert_equal(controls.update_speed_target_acceleration(true, 326, 326, 300, 225), true,
    "the latch holds while the speed is more than 5 kt below the target")
assert_equal(controls.update_speed_target_acceleration(true, 326, 326, 322, 225), false,
    "the latch releases within 5 kt of the target")
assert_equal(controls.update_speed_target_acceleration(false, 155.2, 210, 130, 160), false,
    "a target step below the minimum safe speed is a real underspeed, not latched")
assert_equal(controls.update_speed_target_acceleration(false, 250, 254, 240, 225), false,
    "a target change under 5 kt does not latch")
-- While latched only the minimum safe speed (capped at target - 5 kt) is a
-- severe underspeed, so the climb guard stays and the aircraft accelerates
-- without descending.
local latched_pitch, latched_severe = controls.limit_speed_pitch_target(2.6, 2.7,
    controls.VERTICAL_DIRECTION_CLIMB, 50, 280, 326, 225, 365, 0.3, true)
assert_near(latched_pitch, 2.7, 0.0001, "latched acceleration keeps the climb guard 46 kt slow")
assert_equal(latched_severe, false, "latched acceleration 46 kt slow is not a severe underspeed")
latched_pitch, latched_severe = controls.limit_speed_pitch_target(2.6, 2.7,
    controls.VERTICAL_DIRECTION_CLIMB, 50, 220, 326, 225, 365, 0.3, true)
assert_near(latched_pitch, 2.6, 0.0001, "latched acceleration below the minimum safe speed may pitch down")
assert_equal(latched_severe, true, "latched acceleration below the minimum safe speed is severe")

assert_near(controls.limit_speed_pitch_target(5.2, 4.9, controls.VERTICAL_DIRECTION_DESCENT,
    -800, 260, 250, 160, 340, 0.3), 5.0, 0.0001, "descent target cannot pitch above envelope")
assert_near(controls.limit_speed_pitch_target(4.1, 4.0, controls.VERTICAL_DIRECTION_DESCENT,
    -50, 260, 250, 160, 340, 0.3), 4.0, 0.0001, "descent pitch-up stops near level flight")
assert_near(controls.limit_speed_pitch_target(4.0, 4.0, controls.VERTICAL_DIRECTION_DESCENT,
    200, 260, 250, 160, 340, 0.3), 3.7, 0.0001, "wrong-way descent recovers downward")
assert_near(controls.limit_speed_pitch_target(5.2, 4.9, controls.VERTICAL_DIRECTION_DESCENT,
    -50, 336, 250, 160, 340, 0.3), 5.2, 0.0001, "severe overspeed overrides descent ceiling")

local large_roll_step = controls.adaptive_roll_filter(0, 20, 0.1, false)
local small_roll_step = controls.adaptive_roll_filter(0, 2, 0.1, false)
assert(large_roll_step > small_roll_step, "large roll errors must respond faster than small errors")
tests_run = tests_run + 1
assert_equal(controls.roll_output_response_sec(15, 0.1, 0.8, false),
    controls.ROLL_OUTPUT_LARGE_RESPONSE_SEC, "large roll output response")
assert_equal(controls.roll_output_response_sec(1, 0.1, 0.2, false),
    controls.ROLL_OUTPUT_SMALL_RESPONSE_SEC, "small roll output damping")
assert_equal(controls.roll_output_response_sec(15, 0.1, -0.8, false),
    controls.ROLL_OUTPUT_REVERSAL_RESPONSE_SEC, "roll reversal smoothing")

-- [g-2] The production ap_director_pitch (hydraulics_override.lua) passes the
-- latch to the limiter. ap_director_pitch and its file locals are loaded with
-- mocked datarefs; B747_afds_controls and the pitch-target records are file
-- locals above the slice, so here they are globals of the environment.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local function slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local director_source = slice(HYD .. "B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")

-- VNAV SPD climb through 10,000 ft toward FL350 at 250 kt, +50 fpm.
local director = setmetatable({
    print = function() end,
    B747_afds_controls = controls,
    B747_interpolate_value = function(current, target) return target end,
    debug_flight_directors = 0, B747DR_ap_autoland = 0, B744DR_autolandPitch = 0,
    simDR_AHARS_pitch_heading_deg_pilot = 2.7, simDR_flight_director_pitch = 0,
    simDR_autopilot_TOGA_pitch_deg = 2.7,
    B747DR_airspeed_Vmc = 215, B747DR_airspeed_Vmax = 365,
    simDR_ind_airspeed_kts_pilot = 250, simDR_autopilot_airspeed_kts = 250,
    simDR_vvi_fpm_pilot = 50, B747DR_alt_capture_window = 400,
    simDR_pressureAlt1 = 10100, simDR_autopilot_altitude_ft = 35000,
    simDR_autopilot_hold_altitude_ft = 35000, simDR_autopilot_alt_hold_status = 0,
    simDR_autopilot_flch_status = 2, simDR_autopilot_vs_status = 0,
    B747_afds_pitch_target_before_blend = 0, B747_afds_pitch_target_after_blend = 0,
    simDRTime = 100
}, {__index = _G})
setfenv(assert(loadstring(director_source)), director)()

-- One director update 0.3 s after the previous one; the attitude follows the
-- raw pitch target, as the servo loop would. Returns the raw pitch target.
local function director_update(pitch_mode)
    director.simDRTime = director.simDRTime + 0.3
    director.simDR_AHARS_pitch_heading_deg_pilot = director.B747_afds_pitch_target_before_blend
    director.ap_director_pitch(pitch_mode)
    return director.B747_afds_pitch_target_before_blend
end
director.ap_director_pitch(1) -- first update only resets the director
director_update(1)              -- TO/GA sets the pitch target to 2.7 degrees
for _ = 1, 3 do director_update(4) end
assert_near(director.B747_afds_pitch_target_before_blend, 2.7, 0.0001, "VNAV SPD on speed holds 2.7 degrees")
director.simDR_autopilot_airspeed_kts = 326
local lowest_pitch = 2.7
for _ = 1, 10 do
    director.simDR_ind_airspeed_kts_pilot = director.simDR_ind_airspeed_kts_pilot + 0.5
    lowest_pitch = math.min(lowest_pitch, director_update(4))
end
assert_near(lowest_pitch, 2.7, 0.0001, "250 to 326 kt target step at +50 fpm does not pitch down")
-- The latch keeps only the descent guard: climbing the director still trades
-- climb rate for speed. Here the speed rises 0.1 kt in the 0.3 s (0.33 kt/s),
-- less than the 1 kt/s the climb speed law (g-6) wants 70 kt below the
-- target; at +600 fpm its climb floor allows 0.5 deg/s per 1,000 fpm above
-- +300 fpm, 0.15 deg/s, so 0.045 deg in the 0.3 s.
director.simDR_vvi_fpm_pilot = 600
director.simDR_ind_airspeed_kts_pilot = director.simDR_ind_airspeed_kts_pilot + 0.1
local before_trade = director.B747_afds_pitch_target_before_blend
assert_near(director_update(4), before_trade - 0.045, 0.002, "latched acceleration at +600 fpm still pitches down")

print("AFDS responsiveness tests passed: " .. tests_run)
