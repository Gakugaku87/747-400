local helpers = dofile(
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.afds_helpers.lua")

local fms_data = {
    clbrestspd = "210",
    transpd = "250",
    clbspd = "272",
    clbmach = "780",
    crzspd = "810",
    transalt = "18000",
    costindex = "200"
}

local runtime = {
    dofile = function(path)
        if path == "B747.70.xt.autopilot.afds_helpers.lua" then return helpers end
        assert(path == "B747.70.xt.autopilot.takeoff.lua", "unexpected helper path: "..tostring(path))
        return dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"..path)
    end,
    getFMSData = function(name)
        return fms_data[name]
    end,
    is_timer_scheduled = function()
        return false
    end,
    run_after_time = function()
    end,
    B747DR_airspeed_Vmc = 120,
    B747DR_airspeed_Vmo = 400,
    simDR_flap_ratio_control = 0,
    simDR_ind_airspeed_kts_pilot = 200,
    simDR_airspeed_mach = 0,
    simDR_autopilot_airspeed_is_mach = 0,
    B747DR_switchingIASMode = 0,
    B747DR_ap_ias_dial_value = 0,
    B747DR_lastap_dial_airspeed = 0
}
setmetatable(runtime, {__index = _G})

local chunk, load_error = loadfile(
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.vnavspd.lua")
assert(chunk ~= nil, load_error)
setfenv(chunk, runtime)
chunk()

runtime.clb_aptres_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 210,
    "SPD REST state did not command clbrestspd")

runtime.clb_spcres_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 250,
    "below-transition state did not command transpd")

runtime.clb_nores_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 272,
    "unrestricted climb state did not command clbspd")

-- ECON CLB is a CAS/Mach pair.  The crossover is the climb Mach (.780 here),
-- not the cruise Mach; cruise Mach is only picked up at top of climb.
runtime.simDR_airspeed_mach = 0.79
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1,
    "climb did not change over to Mach at the climb Mach")
assert(runtime.B747DR_ap_ias_dial_value == 78,
    "climb changed over to the cruise Mach instead of the climb Mach")

runtime.simDR_autopilot_airspeed_is_mach = 0
runtime.clb_spcres_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 78,
    "transition-speed state changed over to the cruise Mach")

-- Below the climb Mach the schedule stays on CAS.
runtime.simDR_airspeed_mach = 0.70
runtime.simDR_autopilot_airspeed_is_mach = 1
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 0,
    "climb stayed on Mach below the climb Mach crossover")
assert(runtime.B747DR_ap_ias_dial_value == 272,
    "climb did not return to the ECON climb CAS")

-- Without a scheduled climb Mach the cruise Mach is still the fallback.
fms_data.clbmach = nil
runtime.simDR_airspeed_mach = 0.79
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 0,
    "fallback crossed over below the cruise Mach")
runtime.simDR_airspeed_mach = 0.82
runtime.clb_nores_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 81,
    "fallback did not use the cruise Mach")
fms_data.clbmach = "780"

print("VNAV climb-speed semantic tests passed")
