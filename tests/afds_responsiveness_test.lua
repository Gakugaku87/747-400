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

print("AFDS responsiveness tests passed: " .. tests_run)
