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
    simDR_pressureAlt1 = 12000,
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

-- At top of climb the cruise state flies the ECON cruise Mach the FMC keeps
-- in crzspd (shared with the CLB page Mach), or the crew-selected one.
runtime.simDR_pressureAlt1 = 35000
fms_data.crzspd = "846"
runtime.clb_crz_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1,
    "cruise did not change over to Mach")
assert(runtime.B747DR_ap_ias_dial_value == 84.6,
    "cruise did not fly the FMC ECON cruise Mach")
fms_data.crzspd = "800"
runtime.clb_crz_setSpd()
assert(runtime.B747DR_ap_ias_dial_value == 80,
    "cruise did not fly the selected cruise Mach")
fms_data.crzspd = "810"

-- [g-3] The crossover is judged on the CAS target, not on the current Mach.
-- TST744L step climb from FL310: ECON 326 kt / M.815 at 300.4 kt and M.807.
-- 326 kt is M.869 at FL310, so the climb Mach is flown, with no 26 kt
-- underspeed on the CAS target and no CAS/Mach flip as M.807 changes to
-- M.810 and back.
fms_data.clbspd = "326"
fms_data.clbmach = "815"
runtime.simDR_pressureAlt1 = 31000
runtime.simDR_ind_airspeed_kts_pilot = 300.4
runtime.simDR_airspeed_mach = 0.807
runtime.simDR_autopilot_airspeed_is_mach = 1
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1,
    "climb at FL310 left the climb Mach for a CAS target above it")
assert(runtime.B747DR_ap_ias_dial_value == 81.5,
    "climb at FL310 did not fly the climb Mach")
runtime.simDR_pressureAlt1 = 31138
runtime.simDR_airspeed_mach = 0.810
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1 and runtime.B747DR_ap_ias_dial_value == 81.5,
    "climb at FL311 and M.810 flipped back to CAS")
runtime.simDR_pressureAlt1 = 31000
runtime.simDR_airspeed_mach = 0.807
runtime.simDR_autopilot_airspeed_is_mach = 0
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1 and runtime.B747DR_ap_ias_dial_value == 81.5,
    "a CAS climb at FL310 did not change over to the climb Mach")
-- The SPD TRANS state uses the same crossover: 250 kt is M.711 at FL330,
-- above a M.700 climb Mach.
fms_data.clbmach = "700"
runtime.simDR_pressureAlt1 = 33000
runtime.simDR_ind_airspeed_kts_pilot = 245
runtime.simDR_airspeed_mach = 0.69
runtime.simDR_autopilot_airspeed_is_mach = 0
runtime.clb_spcres_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1 and runtime.B747DR_ap_ias_dial_value == 70,
    "SPD TRANS state did not change over at the CAS target's Mach")
fms_data.clbspd = "272"
fms_data.clbmach = "780"
runtime.simDR_pressureAlt1 = 12000
runtime.simDR_ind_airspeed_kts_pilot = 200

print("VNAV climb-speed semantic tests passed")
