local helpers = dofile(
    "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.afds_helpers.lua")

local fms_data = {
    clbrestspd = "210",
    transpd = "250",
    clbspd = "272",
    crzspd = "810",
    transalt = "18000",
    costindex = "200"
}

local runtime = {
    dofile = function(path)
        assert(path == "B747.70.xt.autopilot.afds_helpers.lua",
            "unexpected helper path: " .. tostring(path))
        return helpers
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

print("VNAV climb-speed semantic tests passed")
