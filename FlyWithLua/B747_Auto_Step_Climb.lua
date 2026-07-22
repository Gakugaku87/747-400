-- B747 Auto Step Climb
-- Standalone FlyWithLua NG script for X-Plane 12.
--
-- This script does not modify the aircraft.  It reads the FMC step-climb
-- advisory published by the aircraft, sets the MCP altitude at the predicted
-- S/C point, and presses the aircraft's ALT selector command.

B747_ASC_CONFIG = {
    enabled_at_start = true,
    trigger_distance_nm = 0.5,
    mcp_settle_seconds = 0.35,
    scan_interval_seconds = 0.25,
    cooldown_seconds = 10.0,
    cruise_altitude_tolerance_ft = 1200,
    minimum_step_ft = 500,
    minimum_radio_altitude_ft = 5000,
    require_vnav = true,
    require_autopilot = true
}

-- Aircraft/FMC interface.  These are public X-Plane datarefs and commands;
-- no file inside the aircraft is changed by this script.
dataref("B747_ASC_fms_data", "laminar/B747/fms/data")
dataref("B747_ASC_mcp_altitude", "laminar/B747/autopilot/heading/altitude_dial_ft", "writable")
dataref("B747_ASC_cruise_altitude", "laminar/B747/autopilot/dist/cruise_alt")
dataref("B747_ASC_pressure_altitude", "sim/cockpit2/gauges/indicators/altitude_ft_pilot")
dataref("B747_ASC_radio_altitude", "sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
dataref("B747_ASC_on_ground", "sim/flightmodel/failures/onground_any")
dataref("B747_ASC_vnav_state", "laminar/B747/autopilot/vnav_state")
dataref("B747_ASC_vnav_descent", "laminar/B747/autopilot/vnav_descent")
dataref("B747_ASC_servos_on", "laminar/B747/autopilot/servos_on")
dataref("B747_ASC_sim_time", "sim/time/total_running_time_sec")

local ALT_SELECTOR_COMMAND = "laminar/B747/button_switch/press_altitude"
local LOG_PREFIX = "[B747 Auto S/C] "

B747_ASC = {
    enabled = B747_ASC_CONFIG.enabled_at_start,
    armed_target = nil,
    pending_target = nil,
    pending_press_time = 0,
    awaiting_target = nil,
    verify_deadline = 0,
    last_executed_target = nil,
    cooldown_until = 0,
    next_scan = 0
}

local function asc_log(message)
    logMsg(LOG_PREFIX .. message)
end

local function asc_trim(value)
    if value == nil then return nil end
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function asc_json_string(key)
    local source = B747_ASC_fms_data or ""
    return string.match(source, '"' .. key .. '"%s*:%s*"([^\"]*)"')
end

local function asc_json_number(key)
    local value = asc_json_string(key)
    if value == nil then
        local source = B747_ASC_fms_data or ""
        value = string.match(source, '"' .. key .. '"%s*:%s*([%+%-]?[%d%.]+)')
    end
    return tonumber(value)
end

local function asc_parse_altitude(value)
    value = asc_trim(value)
    if value == nil or value == "" or value == "*****" then return nil end

    local flight_level = tonumber(string.match(string.upper(value), "^FL(%d%d%d)$"))
    if flight_level ~= nil then return flight_level * 100 end

    local altitude = tonumber(value)
    if altitude == nil then return nil end
    if altitude >= 100 and altitude <= 500 then altitude = altitude * 100 end
    if altitude < 10000 or altitude > 50000 then return nil end
    return math.floor((altitude + 50) / 100) * 100
end

local function asc_get_target()
    local target = asc_parse_altitude(asc_json_string("stepto"))
    if target == nil then target = asc_parse_altitude(asc_json_string("stepalt")) end
    return target, asc_json_number("stepdistance")
end

local function asc_clear_transient_state()
    B747_ASC.armed_target = nil
    B747_ASC.pending_target = nil
    B747_ASC.pending_press_time = 0
    B747_ASC.awaiting_target = nil
    B747_ASC.verify_deadline = 0
end

local function asc_environment_is_safe(target)
    if B747_ASC_on_ground ~= 0 then return false end
    if B747_ASC_radio_altitude < B747_ASC_CONFIG.minimum_radio_altitude_ft then return false end
    if B747_ASC_vnav_descent ~= 0 then return false end
    if B747_ASC_CONFIG.require_vnav and B747_ASC_vnav_state < 2 then return false end
    if B747_ASC_CONFIG.require_autopilot and B747_ASC_servos_on <= 0 then return false end
    if B747_ASC_cruise_altitude == nil or B747_ASC_cruise_altitude <= 0 then return false end
    if math.abs(B747_ASC_pressure_altitude - B747_ASC_cruise_altitude)
        > B747_ASC_CONFIG.cruise_altitude_tolerance_ft then return false end
    if target == nil or target < B747_ASC_cruise_altitude + B747_ASC_CONFIG.minimum_step_ft then return false end
    return true
end

local function asc_cancel_pending(reason)
    if B747_ASC.pending_target ~= nil then asc_log("cancelled: " .. reason) end
    B747_ASC.pending_target = nil
    B747_ASC.pending_press_time = 0
    B747_ASC.armed_target = nil
end

local function asc_begin_mcp_sequence(target, now)
    B747_ASC_mcp_altitude = target
    B747_ASC.pending_target = target
    B747_ASC.pending_press_time = now + B747_ASC_CONFIG.mcp_settle_seconds
    asc_log(string.format("S/C reached; MCP set to FL%03d", target / 100))
end

local function asc_handle_pending(now)
    local target = B747_ASC.pending_target
    if target == nil or now < B747_ASC.pending_press_time then return end

    if not B747_ASC.enabled then
        asc_cancel_pending("automation disabled")
        return
    end
    if not asc_environment_is_safe(target) then
        asc_cancel_pending("flight conditions changed")
        return
    end
    -- A crew change during the settle delay always wins over automation.
    if math.abs(B747_ASC_mcp_altitude - target) > 50 then
        asc_cancel_pending("MCP changed by crew")
        return
    end

    command_once(ALT_SELECTOR_COMMAND)
    B747_ASC.last_executed_target = target
    B747_ASC.awaiting_target = target
    B747_ASC.verify_deadline = now + 5.0
    B747_ASC.cooldown_until = now + B747_ASC_CONFIG.cooldown_seconds
    B747_ASC.pending_target = nil
    B747_ASC.pending_press_time = 0
    B747_ASC.armed_target = nil
    asc_log(string.format("ALT selector pressed for FL%03d", target / 100))
end

local function asc_verify_acceptance(now)
    local target = B747_ASC.awaiting_target
    if target == nil then return end
    if B747_ASC_cruise_altitude >= target - 50 then
        asc_log(string.format("CRZ CLB accepted to FL%03d", target / 100))
        B747_ASC.awaiting_target = nil
        return
    end
    if now >= B747_ASC.verify_deadline then
        asc_log(string.format("warning: aircraft did not accept FL%03d", target / 100))
        B747_ASC.awaiting_target = nil
    end
end

function B747_ASC_update()
    local now = tonumber(B747_ASC_sim_time) or 0
    asc_handle_pending(now)
    asc_verify_acceptance(now)

    if now < B747_ASC.next_scan then return end
    B747_ASC.next_scan = now + B747_ASC_CONFIG.scan_interval_seconds

    if not B747_ASC.enabled then
        B747_ASC.armed_target = nil
        return
    end
    if B747_ASC.pending_target ~= nil or now < B747_ASC.cooldown_until then return end

    local target, distance = asc_get_target()
    if target == nil or distance == nil or distance < 0 then
        B747_ASC.armed_target = nil
        return
    end
    if not asc_environment_is_safe(target) then
        B747_ASC.armed_target = nil
        return
    end
    if B747_ASC.last_executed_target == target then return end

    -- The script must first observe a future S/C point.  This prevents loading
    -- or enabling the script while the FMC already says NOW from causing an
    -- immediate, unexpected climb.
    if distance > B747_ASC_CONFIG.trigger_distance_nm then
        if B747_ASC.armed_target ~= target then
            B747_ASC.armed_target = target
            asc_log(string.format("armed for FL%03d at %.1f NM", target / 100, distance))
        end
        return
    end

    if distance >= 0 and B747_ASC.armed_target == target then
        asc_begin_mcp_sequence(target, now)
    end
end

function B747_ASC_enable_command()
    B747_ASC.enabled = true
    asc_clear_transient_state()
    B747_ASC.next_scan = 0
    asc_log("enabled")
end

function B747_ASC_disable_command()
    B747_ASC.enabled = false
    asc_clear_transient_state()
    asc_log("disabled")
end

function B747_ASC_toggle_command()
    if B747_ASC.enabled then B747_ASC_disable_command() else B747_ASC_enable_command() end
end

create_command(
    "FlyWithLua/B747_Auto_Step_Climb/enable",
    "Enable B747 automatic step climb",
    "B747_ASC_enable_command()", "", ""
)
create_command(
    "FlyWithLua/B747_Auto_Step_Climb/disable",
    "Disable B747 automatic step climb",
    "B747_ASC_disable_command()", "", ""
)
create_command(
    "FlyWithLua/B747_Auto_Step_Climb/toggle",
    "Toggle B747 automatic step climb",
    "B747_ASC_toggle_command()", "", ""
)

do_every_frame("B747_ASC_update()")
asc_log(B747_ASC.enabled and "loaded and enabled" or "loaded and disabled")
