-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Loads the production speed state machine and thrust monitor; only simulator
-- interfaces are mocked. These are logic regressions, not flight-model tests.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local profile = dofile(AP.."B747.70.xt.autopilot.takeoff.lua")
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function near(actual, expected, message)
    checks = checks + 1
    assert(math.abs(actual - expected) < 0.01, message)
end
local function update(state, ground, ias, altitude, active, setting)
    return profile.update(state, {on_ground=ground, ias_kts=ias,
        altitude_ft=altitude, vnav_active=active, v2_kts=160,
        baro_inhg=setting or 29.92, accel_height_ft=1500, thrust_height_ft=1000})
end

local state = profile.new()
update(state, true, 99, 4990, false)
equal(state.reference_altitude_ft, nil, "do not freeze the datum before 100 KIAS")
update(state, true, 100, 5000, false)
update(state, true, 145, 5005, false)
equal(state.reference_altitude_ft, 5000, "freeze the 100-KIAS datum")
update(state, false, 180, 5499, true)
equal(state.vnav_speed_kts, 180, "VNAV activation captures current IAS")
update(state, false, 174, 5999, true)
equal(state.vnav_speed_kts, 180, "speed is held rather than following IAS")
equal(state.thrust_reduction_complete, false, "below selected thrust reduction")
update(state, false, 174, 6000, true)
equal(state.thrust_reduction_complete, true, "thrust reduction at selected height")
equal(state.acceleration_complete, false, "thrust reduction does not accelerate early")
update(state, false, 174, 6500, true)
equal(state.acceleration_complete, true, "acceleration at selected height")
update(state, false, 174, 5400, true)
equal(state.acceleration_complete, true, "descent does not re-enter takeoff speed band")
equal(state.thrust_reduction_complete, true, "thrust reduction is latched")
update(state, true, 130, 5400, false)
equal(state.reference_altitude_ft, 5000, "high-speed gear bounce does not reset datum")
update(state, true, 60, 1000, false)
equal(state.reference_altitude_ft, nil, "landing/rejected takeoff rearms capture")
equal(state.vnav_speed_kts, nil, "rearm clears previous departure speed")
equal(state.acceleration_complete, false, "rearm clears acceleration latch")
update(state, true, 100, 1000, false)
update(state, false, 165, 1500, true)
equal(state.vnav_speed_kts, 165, "new departure uses new activation speed")

-- Same static pressure, displayed on QNH 30.12 and then STD 29.92. The STD
-- altitude below is an independently evaluated standard-atmosphere value.
state = profile.new()
update(state, true, 100, 1000, false, 30.12)
update(state, false, 170, 1900, true, 30.12)
update(state, false, 170, 1717.933513205, true, 29.92)
near(profile.height(state, 1717.933513205, 29.92), 900,
    "QNH/STD change preserves departure-relative height")
equal(state.thrust_reduction_complete, false, "baro knob alone does not reduce thrust")
update(state, false, 170, 2170.418750269, true, 30.42)
near(profile.height(state, 2170.418750269, 30.42), 900,
    "higher QNH also preserves departure-relative height")
equal(state.thrust_reduction_complete, false, "increased indicated altitude alone does not reduce thrust")

state = profile.new()
update(state, true, 95, 2200, false)
update(state, false, 175, 2600, true)
equal(state.reference_altitude_ft, 2200, "missing 100-KIAS sample uses last ground observation")
state = profile.new()
update(state, false, 280, 22000, true)
equal(state.acceleration_complete, true, "airborne reload does not guess departure from RA")
equal(state.thrust_reduction_complete, true, "airborne reload stays out of takeoff thrust")

local fms = {accelht="1500", thrredht="1000", clbrestalt="10000",
    clbrestspd="250", spdtransalt="10000", transpd="250", clbspd="320",
    crzspd="810", transalt="18000", costindex="200"}
local runtime = {
    dofile=function(path) return dofile(AP..path) end,
    print=function() end,
    getFMSData=function(key) return fms[key] end,
    is_timer_scheduled=function() return false end,
    run_after_time=function() end,
    isATEnabled=function() return true end,
    B747DR_airspeed_V2=160, B747DR_airspeed_Vmc=135,
    B747DR_airspeed_Vmo=365, B747DR_airspeed_Vf10=190,
    simDR_flap_ratio_control=0.667, simDR_ind_airspeed_kts_pilot=100,
    simDR_airspeed_mach=0.3, simDR_autopilot_airspeed_is_mach=0,
    simDR_pressureAlt1=5000, simDR_radarAlt1=0, simDR_onGround=1,
    simDR_altimeter_baro_inHg=29.92, B747BR_cruiseAlt=35000,
    B747DR_ap_inVNAVdescent=0, B747DR_ap_vnav_state=1,
    simDR_autopilot_fms_vnav=0, B747DR_fmscurrentIndex=2, simDRTime=100,
    B747DR_ap_lastCommand=0, simDR_autopilot_flch_status=0,
    simDR_autopilot_altitude_ft=35000, B747DR_alt_capture_window=200,
    B747DR_autothrottle_active=1, B747DR_ap_FMA_autothrottle_mode=5,
    simDR_override_throttles=0, B747DR_display_N1={[0]=100,100,100,100},
    toderate=0, clbderate=0, B747DR_ap_flightPhase=0, B747DR_ap_thrust_mode=0
}
setmetatable(runtime, {__index=_G})
local chunk = assert(loadfile(AP.."B747.70.xt.autopilot.vnavspd.lua"))
setfenv(chunk, runtime)()
local file = assert(io.open(AP.."B747.70.xt.autopilot.monitor.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("local last_THR_REF=0", 1, true))
local last = assert(source:find("function checkMCPAlt(dist)", first, true))
setfenv(assert(loadstring(source:sub(first, last-1))), runtime)()

runtime.B747_vnav_setClimbspeed()
equal(runtime.B747DR_ap_ias_dial_value, 160, "VNAV armed on ground retains V2")
runtime.simDR_onGround = 0
runtime.B747DR_ap_vnav_state = 2
runtime.simDR_ind_airspeed_kts_pilot = 180
runtime.simDR_pressureAlt1 = 5500
runtime.simDR_radarAlt1 = 8000 -- Falling terrain must not trigger acceleration.
runtime.B747_vnav_setClimbspeed()
runtime.B747_monitor_THR_REF_AT()
equal(runtime.B747DR_ap_ias_dial_value, 180, "production speed state uses captured IAS")
equal(runtime.B747DR_ap_flightPhase, 0, "production monitor ignores high RA before thrust height")
runtime.simDR_pressureAlt1 = 6000
runtime.simDR_radarAlt1 = 20 -- Rising terrain must not delay thrust reduction.
runtime.simDR_ind_airspeed_kts_pilot = 174
runtime.simDRTime = 101
runtime.B747_vnav_setClimbspeed()
runtime.B747_monitor_THR_REF_AT()
equal(runtime.B747DR_ap_ias_dial_value, 180, "production speed remains held before acceleration")
equal(runtime.B747DR_ap_flightPhase, 1, "production monitor reduces thrust using departure datum")
runtime.simDR_pressureAlt1 = 6500
runtime.B747_vnav_setClimbspeed()
equal(runtime.B747DR_ap_ias_dial_value, 205, "acceleration enters existing flap-limited speed schedule")
runtime.simDR_pressureAlt1 = 5900
runtime.simDRTime = 162
runtime.B747_vnav_setClimbspeed()
runtime.B747_monitor_THR_REF_AT()
equal(runtime.B747DR_ap_ias_dial_value, 205, "production recalculation cannot restore V2")
equal(runtime.B747DR_ap_flightPhase, 1, "production monitor cannot restore takeoff phase")
runtime.B747_reset_takeoff_profile()
equal(runtime.B747_takeoff_height(), nil, "flight-start callback clears departure datum")

print("Takeoff profile regression tests passed: "..checks)
