-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV pressed on the ground, before or after the flight directors bring up
-- TO/GA, must only arm VNAV. It must not write ALT HOLD (alt_hold_status 2),
-- which the thrust monitor reads as cruise: it cancels TO/GA and engine TO/GA
-- and the autothrottle drops to SPD after liftoff. Loads the production VNAV
-- and LNAV button handlers, VNAV mode switch and thrust monitor with mocked
-- simulator interfaces; this does not validate flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
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
local function environment(values)
    values = values or {}
    values.print = function() end
    return setmetatable(values, {__index=_G})
end

local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

-- The production VNAV and LNAV button handlers, on the ground at the runway
-- with the flight directors still off (pitch FMA blank). A stale MCP altitude
-- hold and VNAV descent are left over to show that a ground arm clears them.
local function button_runtime(values)
    local r = environment({
        B747_afds_helpers=afds,
        B747CMD_fdr_log_vnav={once=function() end},
        B747CMD_fdr_log_lnav={once=function() end},
        B747_ap_button_switch_position_target={},
        B747DR_fmc_notifications={[30]=0},
        simDR_onGround=1, B747DR_ap_FMA_active_pitch_mode=0,
        B747DR_ap_vnav_state=0, B747DR_ap_lnav_state=0, B747DR_ap_ATT=0,
        simDR_autopilot_alt_hold_status=0, simDR_autopilot_vs_status=0,
        B747DR_mcp_hold=1, B747DR_ap_inVNAVdescent=1,
        B747BR_cruiseAlt=10000, B747BR_totalDistance=75.5, B747BR_tod=34.5,
        B747DR_ap_thrust_mode=0, B747DR_autothrottle_active=1,
        B747DR_autopilot_TOGA_status=0,
        setDescent=function() end,
        B747_invalidate_vnav_speed=function() end,
        B747_vnav_speed=function() end,
        isATEnabled=function() return true end
    })
    for key, value in pairs(values or {}) do r[key] = value end
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function B747_ap_VNAV_mode_CMDhandler(phase, duration)",
        "function B747_ap_switch_hdg_sel_mode_CMDhandler(phase, duration)")
    return r
end

-- VNAV pressed on the ground before the flight directors: arm only.
local r = button_runtime()
r.B747_ap_VNAV_mode_CMDhandler(0, 0)
equal(r.simDR_autopilot_alt_hold_status, 0, "VNAV pressed on the ground does not write ALT HOLD")
equal(r.B747DR_ap_vnav_state, 1, "VNAV pressed on the ground arms VNAV")
equal(r.B747DR_mcp_hold, 0, "ground arm clears a stale MCP altitude hold")
equal(r.B747DR_ap_inVNAVdescent, 0, "ground arm clears a stale VNAV descent")
equal(r.B747DR_fmc_notifications[30], 0, "41 NM to T/D on the ground is not refused")

-- The flight directors then bring up TO/GA. The production thrust monitor
-- must keep TO/GA, engine TO/GA and the takeoff phase.
r.B747DR_autopilot_TOGA_status = 1
r.B747DR_ap_FMA_active_pitch_mode = 1
r.B747DR_engine_TOGA_mode = 0.9
r.B747DR_ap_flightPhase = 0
r.simDR_version = 120400
r.simDR_autopilot_autothrottle_enabled = 0
r.simCMD_ATOff = {once=function() end}
r.B747DR_autothrottle_fail = 0
r.B747DR_autothrottle_active = 1
r.B747DR_display_N1 = {[0]=25,25,25,25}
r.B747DR_ap_thrust_mode = 0
r.simDRTime = 100
r.B747DR_ap_lastCommand = 0
load_in(AP.."B747.70.xt.autopilot.monitor.lua", r,
    "function B747_monitorAT()", "function getWCAforHeading(theading)")
r.B747_monitorAT()
equal(r.B747DR_autopilot_TOGA_status, 1, "thrust monitor keeps TO/GA after a ground VNAV arm")
equal(r.B747DR_ap_flightPhase, 0, "thrust monitor keeps the takeoff phase after a ground VNAV arm")
equal(r.B747DR_engine_TOGA_mode, 0.9, "thrust monitor keeps engine TO/GA after a ground VNAV arm")

-- LNAV pressed on the ground in TO/GA only arms LNAV (no change, guard).
r = button_runtime({B747DR_autopilot_TOGA_status=1})
r.B747_ap_LNAV_mode_afterCMDhandler(0, 0)
equal(r.B747DR_ap_lnav_state, 1, "LNAV pressed on the ground arms LNAV")
equal(r.simDR_autopilot_alt_hold_status, 0, "LNAV pressed on the ground does not write ALT HOLD")
equal(r.B747DR_autopilot_TOGA_status, 1, "LNAV pressed on the ground keeps TO/GA")

-- VNAV pressed on the ground in TO/GA also arms only.
r = button_runtime({B747DR_autopilot_TOGA_status=1, B747DR_ap_FMA_active_pitch_mode=1})
r.B747_ap_VNAV_mode_CMDhandler(0, 0)
equal(r.simDR_autopilot_alt_hold_status, 0, "VNAV pressed in TO/GA on the ground does not write ALT HOLD")
equal(r.B747DR_ap_vnav_state, 1, "VNAV pressed in TO/GA on the ground arms VNAV")
equal(r.B747DR_mcp_hold, 0, "ground arm in TO/GA clears a stale MCP altitude hold")

-- Airborne in TO/GA VNAV still arms, and airborne outside TO/GA it still
-- engages at once (both unchanged).
r = button_runtime({simDR_onGround=0, B747DR_ap_FMA_active_pitch_mode=1})
r.B747_ap_VNAV_mode_CMDhandler(0, 0)
equal(r.simDR_autopilot_alt_hold_status, 0, "airborne VNAV press in TO/GA does not write ALT HOLD")
equal(r.B747DR_ap_vnav_state, 1, "airborne VNAV press in TO/GA arms VNAV")
r = button_runtime({simDR_onGround=0, B747DR_ap_FMA_active_pitch_mode=9})
r.B747_ap_VNAV_mode_CMDhandler(0, 0)
equal(r.simDR_autopilot_alt_hold_status, 2, "airborne VNAV press outside TO/GA engages at once")
equal(r.B747DR_ap_vnav_state, 1, "airborne VNAV press outside TO/GA sets VNAV")
equal(r.B747DR_mcp_hold, 0, "airborne engage clears the MCP altitude hold")
equal(r.B747DR_ap_inVNAVdescent, 0, "airborne engage clears VNAV descent")

-- PERF/VNAV UNAVAILABLE on the ground with less than 10 NM to T/D is kept.
r = button_runtime({B747BR_totalDistance=40})
r.B747_ap_VNAV_mode_CMDhandler(0, 0)
equal(r.B747DR_ap_vnav_state, 0, "refused ground VNAV press leaves VNAV off")
equal(r.simDR_autopilot_alt_hold_status, 0, "refused ground VNAV press does not write ALT HOLD")
equal(r.B747DR_fmc_notifications[30], 1, "refused ground VNAV press shows PERF/VNAV UNAVAILABLE")

-- The production VNAV mode switch with VNAV armed on the ground and the MCP
-- altitude set less than 1000 ft above the field: VNAV ALT capture must wait
-- until the aircraft is airborne above the VNAV engage height.
local m = environment({
    B747_afds_helpers=afds,
    B747DR_ap_vnav_state=1, simDR_onGround=1, simDR_radarAlt1=0,
    simDR_pressureAlt1=46, B747DR_autopilot_altitude_ft=1000,
    simDR_autopilot_alt_hold_status=0, simDR_autopilot_vs_status=0,
    simDR_autopilot_flch_status=0, B747DR_mcp_hold=0,
    B747DR_ap_inVNAVdescent=0, B747DR_ap_inDescent=0, B747DR_ap_flightPhase=0,
    simDRTime=100, B747DR_ap_lastCommand=0,
    B747BR_totalDistance=75.5, B747BR_tod=34.5, B747BR_cruiseAlt=10000,
    B747DR_alt_capture_window=200,
    B747DR_ap_cmd_L_mode=0, B747DR_ap_cmd_C_mode=0, B747DR_ap_cmd_R_mode=0,
    B747_monitor_THR_REF_AT=function() end,
    VNAV_CLB=function() end, VNAV_CRZ=function() end, VNAV_DES=function() end,
    checkMCPAlt=function() end, setDescentVSpeed=function() end
})
load_in(AP.."B747.70.xt.autopilot.monitor.lua", m,
    "local lastVNAVSwitch=0", "function LNAV_modeSwitch()")
m.VNAV_modeSwitch({})
equal(m.simDR_autopilot_alt_hold_status, 0, "MCP altitude near the field does not capture on the ground")
equal(m.B747DR_mcp_hold, 0, "no MCP altitude hold on the ground")
equal(m.B747DR_ap_vnav_state, 1, "VNAV stays armed on the ground")
m.simDR_onGround, m.simDR_radarAlt1, m.simDR_pressureAlt1, m.simDRTime = 0, 300, 350, 101
m.VNAV_modeSwitch({})
equal(m.simDR_autopilot_alt_hold_status, 0, "no VNAV ALT capture below the VNAV engage height")
equal(m.B747DR_ap_vnav_state, 1, "VNAV stays armed below the VNAV engage height")
m.simDR_radarAlt1, m.simDR_pressureAlt1, m.simDRTime = 450, 500, 102
m.VNAV_modeSwitch({})
equal(m.simDR_autopilot_alt_hold_status, 2, "airborne VNAV ALT capture of the MCP altitude is kept")
equal(m.B747DR_mcp_hold, 1, "airborne VNAV ALT capture holds the MCP altitude")
equal(m.B747DR_ap_vnav_state, 2, "airborne VNAV ALT capture makes VNAV active")

-- The button decision keeps the existing order: the PERF/VNAV UNAVAILABLE
-- refusal first, then the toggle off, then arm or engage.
-- Inputs: vnav_state, cruise_alt_ft, dist_to_tod_nm, on_ground, active_pitch_mode.
local button_cases = {
    {0, 10000, 41, 1, 0, afds.VNAV_BUTTON_ARM, "ground, flight directors off: arm"},
    {0, 10000, 41, 1, 1, afds.VNAV_BUTTON_ARM, "ground, TO/GA: arm"},
    {0, 10000, 41, 0, 1, afds.VNAV_BUTTON_ARM, "airborne TO/GA: arm"},
    {0, 10000, 41, 0, 9, afds.VNAV_BUTTON_ENGAGE, "airborne outside TO/GA: engage"},
    {1, 10000, 41, 1, 0, afds.VNAV_BUTTON_DISARM, "armed VNAV: second press disarms"},
    {0, 10000, 5, 1, 0, afds.VNAV_BUTTON_REFUSE, "ground, under 10 NM to T/D: refuse"},
    {0, 0, 41, 0, 9, afds.VNAV_BUTTON_REFUSE, "no cruise altitude: refuse"},
    {1, 10000, 5, 1, 0, afds.VNAV_BUTTON_REFUSE, "refusal is checked before disarm"}
}
for _, case in ipairs(button_cases) do
    equal(afds.vnav_button_action(case[1], case[2], case[3], case[4], case[5]), case[6],
        "VNAV button "..case[7])
end
local actions = {afds.VNAV_BUTTON_REFUSE, afds.VNAV_BUTTON_DISARM, afds.VNAV_BUTTON_ARM,
    afds.VNAV_BUTTON_ENGAGE}
for i = 1, #actions do
    equal(type(actions[i]), "number", "VNAV button action "..i.." is defined")
    for j = i + 1, #actions do
        equal(actions[i] ~= actions[j], true, "VNAV button actions "..i.." and "..j.." differ")
    end
end

-- VNAV may engage only when airborne above the VNAV_CLB engage height.
equal(afds.VNAV_ENGAGE_MIN_RA_FT, 400, "VNAV engage height matches VNAV_CLB")
equal(afds.vnav_engage_height_reached(1, 0), false, "not on the ground")
equal(afds.vnav_engage_height_reached(1, 450), false, "not on the ground with a high radio altitude")
equal(afds.vnav_engage_height_reached(0, 400), false, "not at the engage height")
equal(afds.vnav_engage_height_reached(0, 401), true, "airborne above the engage height")

print("VNAV ground arm tests passed: "..checks)
