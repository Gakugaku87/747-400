-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Loads the production VNAV speed state machine with mocked simulator
-- interfaces.  SPD REST reads "---/-----" on the CLB and DES pages until the
-- crew enters one (FCOM CLB/DES pages), so the schedule must hold SPD TRANS
-- instead of an invented restriction, and pick the restriction up when it is
-- entered.  Logic only; this does not validate flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end

local fms = {
    accelht="1500", thrredht="1500",
    clbrestspd="---", clbrestalt="-----",
    transpd="250", spdtransalt="10000", transalt="18000",
    clbspd="320", clbmach="780", crzspd="810", costindex="200",
    desspd="270", desspdmach="805",
    destranspd="240", desspdtransalt="10000",
    desrestspd="---", desrestalt="-----"
}
local runtime = {
    dofile=function(path) return dofile(AP..path) end,
    print=function() end,
    getFMSData=function(key) return fms[key] end,
    is_timer_scheduled=function() return false end,
    run_after_time=function() end,
    isATEnabled=function() return true end,
    B747_rescale=function(x1, y1, x2, y2, x)
        if x1 == x2 then return y2 end
        local fraction = (x - x1) / (x2 - x1)
        if fraction < 0 then fraction = 0 end
        if fraction > 1 then fraction = 1 end
        return y1 + (y2 - y1) * fraction
    end,
    B747DR_airspeed_V2=160, B747DR_airspeed_Vmc=135, B747DR_airspeed_Vmo=365,
    simDR_flap_ratio_control=0, simDR_ind_airspeed_kts_pilot=260,
    simDR_airspeed_mach=0.5, simDR_autopilot_airspeed_is_mach=0,
    simDR_pressureAlt1=3000, simDR_radarAlt1=3000, simDR_onGround=0,
    simDR_altimeter_baro_inHg=29.92, B747BR_cruiseAlt=35000,
    B747DR_ap_inVNAVdescent=0, B747DR_ap_vnav_state=2,
    simDR_autopilot_fms_vnav=1, B747DR_fmscurrentIndex=2, simDRTime=100,
    B747DR_efis_baro_std_capt_switch_pos=0, B747DR_efis_baro_std_fo_switch_pos=0,
    simDR_altimeter_baro_inHg_fo=29.92, B747DR_alt_capture_window=200,
    simDR_autopilot_altitude_ft=35000, B747DR_autothrottle_active=1,
    B747DR_engine_TOGA_mode=0, B747DR_ap_lastCommand=0,
    B747DR_ap_flightPhase=1, B747DR_ap_vnav_target_alt=35000,
    B747DR_switchingIASMode=0, B747DR_ap_ias_dial_value=0,
    B747DR_lastap_dial_airspeed=0
}
setmetatable(runtime, {__index=_G})
local chunk = assert(loadfile(AP.."B747.70.xt.autopilot.vnavspd.lua"))
setfenv(chunk, runtime)()

-- Freeze a sea-level departure datum so the takeoff state is past acceleration.
runtime.simDR_onGround = 1
runtime.simDR_pressureAlt1 = 0
runtime.simDR_ind_airspeed_kts_pilot = 100
runtime.B747_update_takeoff_profile()
runtime.simDR_onGround = 0
runtime.simDR_pressureAlt1 = 3000
runtime.simDR_ind_airspeed_kts_pilot = 260
runtime.B747_update_takeoff_profile()

local function climbState()
    runtime.B747_invalidate_vnav_speed("test")
    runtime.B747_vnav_setClimbspeed()
    return runtime.B747_get_vnav_speed_diagnostics().state
end

-- No SPD REST entered: the restriction state is skipped entirely and the
-- climb holds the SPD TRANS speed below the transition altitude.
equal(runtime.clb_aptres_next(), runtime.simDR_pressureAlt1 - 1,
    "a blank SPD REST hands straight to SPD TRANS")
equal(climbState(), "clb_spcres/IAS", "blank SPD REST selects the SPD TRANS state")
equal(runtime.B747DR_ap_ias_dial_value, 250, "blank SPD REST commands SPD TRANS speed")

-- Entering one brings the restriction state back.
fms.clbrestspd = "210"
fms.clbrestalt = "8000"
equal(runtime.clb_aptres_next(), runtime.simDR_pressureAlt1 + 500,
    "an entered SPD REST steps the boundary up in 500 ft increments")
equal(climbState(), "clb_aptres/IAS", "an entered SPD REST selects the restriction state")
equal(runtime.B747DR_ap_ias_dial_value, 245,
    "the restriction state commands SPD REST, decelerating gradually")
runtime.simDR_ind_airspeed_kts_pilot = 215
equal(climbState(), "clb_aptres/IAS", "the restriction state is held while below it")
equal(runtime.B747DR_ap_ias_dial_value, 210, "SPD REST speed is reached")

-- Above the restriction altitude the climb moves on to SPD TRANS again.
runtime.simDR_pressureAlt1 = 8500
runtime.simDR_ind_airspeed_kts_pilot = 245
equal(climbState(), "clb_spcres/IAS", "above SPD REST the climb resumes SPD TRANS")
equal(runtime.B747DR_ap_ias_dial_value, 250, "SPD TRANS speed after the restriction")

-- Deleting it returns to the blank field and the skipped state.
fms.clbrestspd = "---"
fms.clbrestalt = "-----"
runtime.simDR_pressureAlt1 = 3000
runtime.simDR_ind_airspeed_kts_pilot = 260
equal(climbState(), "clb_spcres/IAS", "a deleted SPD REST is skipped again")

-- The DES page field behaves the same way: with none entered there is no
-- lower restriction state, so SPD TRANS is held down to the ground.
equal(runtime.des_aptres_next(), -100,
    "a blank descent SPD REST leaves no lower restriction state")
runtime.des_aptres_setSpd()
equal(runtime.B747DR_ap_ias_dial_value, 240,
    "the descent holds SPD TRANS with no SPD REST entered")
fms.desrestspd = "180"
fms.desrestalt = "5000"
runtime.simDR_pressureAlt1 = 5200
equal(runtime.des_aptres_next(), 5000,
    "an entered descent SPD REST restores the boundary")
runtime.des_spcres_setSpd()
equal(runtime.B747DR_ap_ias_dial_value, 180,
    "the descent restriction state commands SPD REST")

-- The descent VNAV planner reads both halves of SPD REST; with the field
-- blank it must fall back to SPD TRANS rather than dereference a dash.
runtime.B747BR_fpe = 0
local vnavFile = assert(io.open(AP.."B747.70.xt.autopilot.vnav.lua"))
local vnavSource = vnavFile:read("*a")
vnavFile:close()
local vnavFirst = assert(vnavSource:find("function deceleratedDesent(targetvspeed)", 1, true))
local vnavLast = assert(vnavSource:find("function setDescentVSpeed(fmsO)", vnavFirst, true))
setfenv(assert(loadstring(vnavSource:sub(vnavFirst, vnavLast-1))), runtime)()

fms.desrestspd = "---"
fms.desrestalt = "-----"
runtime.simDR_autopilot_airspeed_is_mach = 0
runtime.simDR_pressureAlt1 = 30000
runtime.simDR_ind_airspeed_kts_pilot = 300
equal(runtime.deceleratedDesent(-2000), -2000,
    "a blank SPD REST leaves the descent rate alone far above SPD TRANS")
runtime.simDR_pressureAlt1 = 10500
equal(runtime.deceleratedDesent(-2000), -500,
    "a blank SPD REST still decelerates towards SPD TRANS")
runtime.simDR_ind_airspeed_kts_pilot = 240
equal(runtime.deceleratedDesent(-2000), -2000,
    "no lower restriction to decelerate towards once at SPD TRANS")
fms.desrestspd = "180"
fms.desrestalt = "5000"
runtime.simDR_pressureAlt1 = 5500
equal(runtime.deceleratedDesent(-2000), -500,
    "an entered SPD REST resumes the deceleration planning")

-- CDU entry: the field is a speed/altitude pair and DELETE blanks it again.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local step = dofile(FMS.."B744.fms.step.lua")
local data = {clbrestspd="---", clbrestalt="-----",
    desrestspd="---", desrestalt="-----"}
local defaults = {clbrestspd="---", clbrestalt="-----",
    desrestspd="---", desrestalt="-----"}
local pages = setmetatable({
    print=function() end,
    fmsFunctions={},
    getFMSData=function(id) return data[id] end,
    setFMSData=function(id, value)
        if value == "" then value = defaults[id] end
        data[id] = step.fixed_width(value, string.len(data[id]))
    end,
    validateSpeed=function(value)
        local speed = tonumber(value)
        return speed ~= nil and speed >= 100 and speed <= 399
    end,
    validAlt=function(value)
        local altitude = tonumber(value)
        if altitude == nil then return nil end
        if altitude < 1000 then altitude = altitude * 100 end
        if altitude < 2000 or altitude > 45000 then return nil end
        return ""..altitude
    end
}, {__index=_G})
local file = assert(io.open(FMS.."B744.fms.pages.lua"))
local source = file:read("*a")
file:close()
local first = assert(source:find("function fmsFunctions.setdata(fmsO,value)", 1, true))
local last = assert(source:find("function fmsFunctions.setDref(fmsO,value)", first, true))
setfenv(assert(loadstring(source:sub(first, last-1))), pages)()

local function enter(field, text)
    local fmsO = {id="fmsL", scratchpad=text, notify=""}
    pages.fmsFunctions.setdata(fmsO, field)
    return fmsO
end

equal(enter("clbrest", "210/8000").notify, "", "a full SPD REST pair is accepted")
equal(step.trim(data.clbrestspd).."/"..step.trim(data.clbrestalt), "210/8000",
    "both halves of the pair are stored")
equal(enter("clbrest", "210").notify, "INVALID ENTRY",
    "a speed without an altitude is not a SPD REST")
equal(enter("clbrest", "210/1000").notify, "INVALID ENTRY",
    "an unusable restriction altitude is rejected")
equal(step.trim(data.clbrestalt), "8000", "a rejected entry leaves the pair alone")
equal(enter("clbrest", "DELETE").notify, "", "DELETE is accepted")
equal(step.trim(data.clbrestspd).."/"..step.trim(data.clbrestalt), "---/-----",
    "DELETE returns SPD REST to the blank field")

equal(enter("desrest", "180/5000").notify, "", "the DES page pair is accepted")
equal(step.trim(data.desrestspd).."/"..step.trim(data.desrestalt), "180/5000",
    "the DES page stores both halves")
equal(enter("desrest", "DELETE").notify, "", "DELETE is accepted on the DES page")
equal(step.trim(data.desrestspd).."/"..step.trim(data.desrestalt), "---/-----",
    "DELETE blanks the DES page field too")

print("VNAV speed-restriction tests passed: "..checks)
