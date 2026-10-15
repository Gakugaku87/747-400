-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Approach LOC and G/S capture: the production APP switch handler, the APP
-- arming logic and the approach monitor run together on mocked simulator
-- datarefs.  This does not validate flight dynamics or receiver behaviour.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local failures = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
-- Run each case on its own so one failure does not hide the others.
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        failures = failures + 1
        print("FAIL "..name..": "..tostring(err))
    end
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    if first_marker then
        local first = assert(source:find(first_marker, 1, true))
        local last = assert(source:find(last_marker, first, true))
        source = source:sub(first, last-1)
    end
    setfenv(assert(loadstring(source, "@"..path)), runtime)()
end

local helpers = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

-- A fresh autopilot namespace per scenario: ILS tuned (course 054 on both
-- receivers, bearing 054), HDG SEL engaged in the simulator, CMD engaged,
-- 2500 ft RA, nothing armed yet.
local function new_runtime()
    local r = setmetatable({}, {__index=_G})
    r.print = function() end
    r.dofile = function(path) return dofile(AP..path) end
    -- monitor.lua loads its own copy; the global serves code sliced from it
    r.B747_afds_helpers = helpers
    r.heading_selects = 0
    r.simCMD_autopilot_heading_select = {once=function() r.heading_selects = r.heading_selects + 1 end}
    r.B747CMD_fdr_log_app = {once=function() end}
    r.B747_ap_button_switch_position_target = {}
    r.B747DR_fmc_notifications = {}
    r.simDRTime, r.B747DR_ap_lastCommand = 99.7, 0
    r.B747DR_ils_dots, r.B747DR_ap_approach_mode = 1, 0
    r.B747DR_ap_heading_deg, r.simDR_autopilot_heading_deg = 24, 24
    r.B747DR_ap_cmd_L_mode, r.B747DR_ap_cmd_C_mode, r.B747DR_ap_cmd_R_mode = 1, 0, 0
    r.B747DR_hyd_sys_pressure_1, r.B747DR_hyd_sys_pressure_2, r.B747DR_hyd_sys_pressure_3 = 3000, 3000, 3000
    r.simDR_radarAlt1, r.simDR_onGround = 2500, 0
    r.simDR_radio_nav_obs_deg = {[0]=54, 54}
    r.simDR_radio_nav1_bearing_deg, r.simDR_radio_nav2_bearing_deg = 54, 54
    r.simDR_AHARS_heading_deg_pilot = 24
    r.simDR_autopilot_heading_status = 2
    r.simDR_autopilot_nav_status, r.simDR_autopilot_gs_status = 0, 0
    r.B747DR_autopilot_nav_status, r.B747DR_autopilot_gs_status = 0, 0
    r.simDR_hsi_nav1_horizontal_signal, r.simDR_hsi_nav2_horizontal_signal = 1, 1
    r.simDR_hsi_nav1_vertical_signal, r.simDR_hsi_nav2_vertical_signal = 1, 1
    r.simDR_nav1_gs_flag, r.simDR_nav2_gs_flag = 0, 0
    r.simDR_hsi_ldef_dots_nav1, r.simDR_hsi_ldef_dots_nav2 = -2.5, -2.5
    r.simDR_hsi_vdef_dots_pilot = 0
    r.B747DR_ap_lnav_state, r.B747DR_ap_lnavHeading_mode = 0, 0
    r.B747DR_fmscurrentIndex, r.B747DR_ap_lnav_xtk_target = 0, 0
    r.B747DR_ap_ATT = 0
    r.simDR_TAS_mps, r.B747DR_ND_Wind_Bearing, r.simDR_wind_speed_kts = 100, 0, 0
    r.simDR_variation = 0
    r.fmsO = {}
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function roundToIncrement(", "function B747_ap_heading_hold_mode_beforeCMDhandler(")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function getHeadingDifference(", "function getDistance(")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B747_ap_appr_mode_beforeCMDhandler(", "function B747_ap_switch_loc_mode_CMDhandler(")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B747_ap_appr_mode()", "----- FLIGHT MODE ANNUNCIATORS")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B474_ap_target_heading()", "----- EICAS MESSAGES")
    load_in(AP.."B747.70.xt.autopilot.monitor.lua", r)
    return r
end

-- Press APP at t=99.7 and let the APP logic arm LOC and G/S 0.3 s later.
local function arm_approach(r, heading)
    r.simDR_AHARS_heading_deg_pilot = heading
    r.simDRTime = 99.7
    r.B747_ap_appr_mode_beforeCMDhandler(0, 0)
    r.simDRTime = 100
    r.B747_ap_appr_mode()
    equal(r.simDR_autopilot_nav_status, 1, "APP arms LOC")
    equal(r.simDR_autopilot_gs_status, 1, "APP arms G/S")
end

-- One approach-monitor frame with both receivers showing the same LOC deviation.
local function frame(r, time, loc_dots, gs_dots)
    r.simDRTime = time
    r.simDR_hsi_ldef_dots_nav1, r.simDR_hsi_ldef_dots_nav2 = loc_dots, loc_dots
    if gs_dots ~= nil then r.simDR_hsi_vdef_dots_pilot = gs_dots end
    r.B747_updateApproachHeading(r.fmsO)
end

-- Every LOC or G/S capture stamps B747DR_ap_lastCommand with the frame time.
-- With the bearing on the course, the existing on-course glitch check (both
-- receivers together beyond 4 dots) demotes a LOC captured beyond 2.0 dots
-- again in the same frame, so the nav status alone cannot show such a capture.
local function nothing_captured(r, time, message)
    check(r.B747DR_ap_lastCommand < time, message)
end

-- Pure LOC capture window: 2.0 dots, closing at 0.01 dot/s or more over a
-- sample at least 1 s old, or within 1.0 dot and growing less than
-- 0.02 dot/s; both receivers; intercept no more than 90 degrees.
case("LOC capture helper", function()
    local function input(nav1_dots, sample_dots, sample_time)
        return {nav1_signal=1, nav2_signal=1, course_deg=54, heading_deg=24,
            nav1_dots=nav1_dots, nav2_dots=nav1_dots, time=101,
            sample={time=sample_time or 100, dots=sample_dots}}
    end
    equal(helpers.loc_deviation_dots(-2.5, -1.5), 2.0, "LOC deviation is the mean of both receivers")
    equal(helpers.loc_deviation_dots(1.0, nil), nil, "a missing receiver gives no LOC deviation")
    equal(helpers.loc_capture_ready(input(-2.0, 2.25)), true, "closing at 2.0 dots captures")
    equal(helpers.loc_capture_ready(input(-2.0625, 2.3125)), false, "closing beyond 2.0 dots waits")
    local mixed = input(-2.5, 2.25)
    mixed.nav2_dots = -1.5
    equal(helpers.loc_capture_ready(mixed), true, "the receivers are averaged before the window")
    equal(helpers.loc_capture_ready(input(-1.5, 1.5 + 1/64)), true, "closing at 1/64 dot/s captures")
    equal(helpers.loc_capture_ready(input(-1.5, 1.5 + 1/128)), false, "closing at 1/128 dot/s is too slow")
    equal(helpers.loc_capture_ready(input(-1.5, 1.75, 76)), true, "closing at exactly 0.01 dot/s captures")
    equal(helpers.loc_capture_ready(input(1.0, 1.0)), true, "steady at 1.0 dot captures")
    equal(helpers.loc_capture_ready(input(-1.0625, 1.0625)), false, "steady beyond 1.0 dot waits")
    equal(helpers.loc_capture_ready(input(-1.0, 1.0 - 1/64)), true, "slow growth within 1.0 dot captures")
    equal(helpers.loc_capture_ready(input(-1.0, 0.0, 51)), false, "growth of 0.02 dot/s waits")
    equal(helpers.loc_capture_ready(input(-1.8, 1.7)), false, "diverging within 2.0 dots waits")
    local wide = input(-1.0, 1.0)
    wide.heading_deg = 144
    equal(helpers.loc_capture_ready(wide), true, "90 degree intercept captures")
    wide.heading_deg = 144.5
    equal(helpers.loc_capture_ready(wide), false, "intercept beyond 90 degrees waits")
    wide.course_deg, wide.heading_deg = 350, 80
    equal(helpers.loc_capture_ready(wide), true, "intercept angle wraps through north")
    wide.heading_deg = 81
    equal(helpers.loc_capture_ready(wide), false, "wrapped intercept beyond 90 degrees waits")
    local no_signal = input(-1.0, 1.0)
    no_signal.nav1_signal = 0
    equal(helpers.loc_capture_ready(no_signal), false, "NAV1 without a localizer waits")
    no_signal.nav1_signal, no_signal.nav2_signal = 1, 0
    equal(helpers.loc_capture_ready(no_signal), false, "NAV2 without a localizer waits")
    local no_sample = input(-1.0, 1.0)
    no_sample.sample = nil
    equal(helpers.loc_capture_ready(no_sample), false, "no earlier sample waits")
    equal(helpers.loc_capture_ready(input(-1.0, 1.0, 100.5)), false, "a sample under 1 s old waits")
end)

-- Pure G/S capture window: LOC captured, LOC within 1.5 dots, G/S within
-- 1.5 dots, no G/S flags, vertical guidance on both receivers.
case("G/S capture helper", function()
    local function input()
        return {loc_captured=true, nav1_dots=-0.6, nav2_dots=-0.6, gs_dots=-1.2,
            nav1_gs_flag=0, nav2_gs_flag=0, nav1_vertical_signal=1, nav2_vertical_signal=1}
    end
    equal(helpers.gs_capture_ready(input()), true, "LOC 0.6 dot, G/S -1.2 dots captures")
    local value = input()
    value.loc_captured = false
    equal(helpers.gs_capture_ready(value), false, "G/S waits for LOC capture")
    value = input()
    value.nav1_dots, value.nav2_dots = -1.6, -1.6
    equal(helpers.gs_capture_ready(value), false, "G/S waits with LOC at 1.6 dots")
    value.nav1_dots, value.nav2_dots = 1.5, 1.5
    equal(helpers.gs_capture_ready(value), true, "G/S captures with LOC at 1.5 dots")
    value = input()
    value.gs_dots = -1.5
    equal(helpers.gs_capture_ready(value), false, "G/S waits at 1.5 dots")
    value = input()
    value.nav2_gs_flag = 1
    equal(helpers.gs_capture_ready(value), false, "G/S waits with a G/S flag")
    value = input()
    value.nav1_vertical_signal = 0
    equal(helpers.gs_capture_ready(value), false, "G/S waits without vertical guidance")
end)

-- (a) 2.5 dots (saturated) on a 77 degree intercept: neither LOC nor G/S
-- may capture, even with G/S centred.
case("(a) saturated LOC does not capture", function()
    local r = new_runtime()
    arm_approach(r, 130.9)
    for i = 1, 4 do
        frame(r, 100 + i, -2.5, 0)
        nothing_captured(r, 100 + i, "no LOC or G/S capture, frame "..i)
        equal(r.simDR_autopilot_nav_status, 1, "saturated LOC stays armed, frame "..i)
        equal(r.simDR_autopilot_gs_status, 1, "G/S stays armed before LOC, frame "..i)
    end
end)

-- (b) Inside 2.0 dots but moving away from the localizer.
case("(b) diverging LOC does not capture", function()
    local r = new_runtime()
    arm_approach(r, 93)
    local deviations = {-1.64, -1.72, -1.81}
    for i = 1, #deviations do
        frame(r, 100 + i, deviations[i], 0)
        equal(r.simDR_autopilot_nav_status, 1, "diverging LOC stays armed, frame "..i)
    end
end)

-- (c) A 30 degree intercept: capture once inside 2.0 dots and closing.
case("(c) closing LOC captures inside 2.0 dots", function()
    local r = new_runtime()
    arm_approach(r, 24)
    local deviations = {-2.5, -2.5, -2.2, -1.9}
    for i = 1, 3 do
        frame(r, 100 + i, deviations[i], 0)
        nothing_captured(r, 100 + i, "no LOC or G/S capture, frame "..i)
        equal(r.simDR_autopilot_nav_status, 1, "LOC still armed, frame "..i)
        equal(r.simDR_autopilot_gs_status, 1, "G/S still armed, frame "..i)
    end
    frame(r, 104, deviations[4], 0)
    equal(r.simDR_autopilot_nav_status, 2, "LOC captures at 1.9 dots closing")
    equal(r.simDR_autopilot_gs_status, 1, "G/S does not capture with LOC at 1.9 dots")
end)

-- (d) Guard: a LOC captured before (signal glitch demotion or APP pressed
-- again) recaptures at once, outside the window.  The bearing is 6 degrees
-- off the course so the existing on-course glitch check (both receivers
-- together beyond 4 dots) does not demote LOC again in the same frame.
case("(d) previously captured LOC recaptures at once", function()
    local r = new_runtime()
    arm_approach(r, 24)
    r.simDR_radio_nav1_bearing_deg, r.simDR_radio_nav2_bearing_deg = 60, 60
    r.B747DR_autopilot_nav_status = 2
    frame(r, 101, -2.3, 0)
    equal(r.simDR_autopilot_nav_status, 2, "previously captured LOC recaptures")
end)

-- (e) APP must not overwrite the MCP heading with the LOC course.
case("(e) APP keeps the MCP heading", function()
    local r = new_runtime()
    r.B747DR_ap_heading_deg = 24
    r.simDRTime = 99.7
    r.B747_ap_appr_mode_beforeCMDhandler(0, 0)
    equal(r.B747DR_ap_approach_mode, 1, "APP arms the approach")
    equal(r.B747DR_ap_heading_deg, 24, "MCP heading stays at the crew selection")
end)

-- (f) LNAV keeps steering while LOC is armed and not yet captured.
case("(f) LNAV steers while LOC is armed", function()
    local r = new_runtime()
    r.simDRTime, r.B747DR_ap_lastCommand = 200, 0
    r.simDR_autopilot_nav_status, r.simDR_autopilot_gs_status = 1, 1
    r.B747DR_autopilot_nav_status = 1
    r.B747DR_ap_approach_mode = 1
    r.B747DR_ap_lnav_state, r.B747DR_ap_lnavHeading_mode = 2, 2
    r.simDR_latitude, r.simDR_longitude = 53, -9
    r.getDistance = function() return 20 end
    r.getHeading = function() return 100 end
    r.simDR_autopilot_heading_deg = 999
    r.fmsO = {{0, 0, 0, 0, 52.9, -9.3}}
    r.B747_updateApproachHeading(r.fmsO)
    equal(r.simDR_autopilot_nav_status, 1, "LOC stays armed at 2.5 dots")
    equal(r.simDR_autopilot_heading_deg, 100, "LNAV heading target is still written")
end)

-- The APP logic and the target-heading monitor keep the simulator heading
-- mode selected for LNAV while LOC is only armed.
local function lnav_armed_runtime()
    local r = new_runtime()
    r.simDRTime, r.B747DR_ap_lastCommand = 200, 0
    r.simDR_autopilot_nav_status, r.simDR_autopilot_gs_status = 1, 1
    r.B747DR_ap_approach_mode = 1
    r.B747DR_ap_lnav_state = 2
    r.simDR_autopilot_heading_status = 0
    return r
end
case("APP logic reselects the heading mode while LOC is armed", function()
    local r = lnav_armed_runtime()
    r.B747_ap_appr_mode()
    equal(r.heading_selects, 1, "APP logic reselects the heading mode for LNAV")
end)
case("target-heading monitor reselects the heading mode while LOC is armed", function()
    local r = lnav_armed_runtime()
    r.B747DR_ap_activate_target_heading_deg, r.B747DR_ap_target_heading_deg = 0, -1
    r.B474_ap_target_heading()
    equal(r.heading_selects, 1, "target-heading monitor reselects the heading mode for LNAV")
end)

-- (g)-(i) G/S captures only with LOC within 1.5 dots and G/S within 1.5 dots.
local function loc_captured_runtime()
    local r = new_runtime()
    arm_approach(r, 54)
    r.simDR_autopilot_nav_status, r.B747DR_autopilot_nav_status = 2, 2
    return r
end
case("(g) G/S waits with LOC at 1.8 dots", function()
    local r = loc_captured_runtime()
    frame(r, 101, -1.8, -1.0)
    equal(r.simDR_autopilot_nav_status, 2, "LOC stays captured at 1.8 dots")
    equal(r.simDR_autopilot_gs_status, 1, "G/S stays armed with LOC at 1.8 dots")
end)
case("(h) G/S waits at 2.0 dots", function()
    local r = loc_captured_runtime()
    frame(r, 101, -0.6, -2.0)
    equal(r.simDR_autopilot_gs_status, 1, "G/S stays armed at 2.0 dots")
end)
case("(i) G/S captures inside both windows", function()
    local r = loc_captured_runtime()
    frame(r, 101, -0.6, -1.2)
    equal(r.simDR_autopilot_gs_status, 2, "G/S captures with LOC 0.6 and G/S 1.2 dots")
end)

-- (j) A steady LOC inside 1.0 dot captures on the first frame with a 1 s old
-- sample; G/S follows on a later frame, never in the LOC capture frame.
case("(j) G/S does not capture in the LOC capture frame", function()
    local r = new_runtime()
    arm_approach(r, 54)
    frame(r, 101, -0.6, -1.2)
    equal(r.simDR_autopilot_nav_status, 1, "LOC needs a sample at least 1 s old")
    equal(r.simDR_autopilot_gs_status, 1, "G/S stays armed before LOC")
    frame(r, 102, -0.6, -1.2)
    equal(r.simDR_autopilot_nav_status, 2, "steady LOC within 1.0 dot captures")
    equal(r.simDR_autopilot_gs_status, 1, "G/S waits for a later frame")
    frame(r, 103, -0.6, -1.2)
    equal(r.simDR_autopilot_gs_status, 2, "G/S captures after LOC")
end)

check(failures == 0, failures.." approach capture case(s) failed")
print("Approach capture tests passed: "..checks)
