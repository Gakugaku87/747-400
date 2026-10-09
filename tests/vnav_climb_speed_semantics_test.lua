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
    B747DR_lastap_dial_airspeed = 0,
    B747DR_airspeed_Mms = 0.92,
    simDR_autopilot_airspeed_kts_mach = 0
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

-- [g-5] The speed states write the X-Plane autopilot target
-- (airspeed_dial_kts_mach) in the new unit together with the speed mode.
-- Before, B747_ap_ias_mach_mode wrote it only after the 0.25 s IAS update,
-- and X-Plane read the old value in the new unit meanwhile (326 kt as a
-- Mach number, M.815 as knots).
local function near_target(expected, message)
    local actual = runtime.simDR_autopilot_airspeed_kts_mach
    assert(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
        message..": autopilot target "..tostring(actual)..", expected "..expected)
end
fms_data.clbspd = "326"
fms_data.clbmach = "815"
runtime.simDR_pressureAlt1 = 31000
runtime.simDR_ind_airspeed_kts_pilot = 300.4
runtime.simDR_airspeed_mach = 0.82
runtime.simDR_autopilot_airspeed_is_mach = 0
runtime.simDR_autopilot_airspeed_kts_mach = 326
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1, "climb at FL310 did not select Mach")
near_target(0.815, "CAS to Mach change did not write the climb Mach")
fms_data.clbspd = "272"
runtime.simDR_pressureAlt1 = 12000
runtime.simDR_ind_airspeed_kts_pilot = 270
runtime.simDR_airspeed_mach = 0.70
runtime.clb_nores_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 0, "climb at 12000 ft did not select CAS")
near_target(272, "Mach to CAS change did not write the ECON climb CAS")
runtime.simDR_pressureAlt1 = 35000
runtime.clb_crz_setSpd()
near_target(0.81, "cruise state did not write the cruise Mach")
-- The Mach target is limited to Mmo - 0.01, as B747_ap_ias_mach_mode limits
-- it; an unset Mmo does not limit it.
runtime.B747DR_airspeed_Mms = 0.80
runtime.clb_crz_setSpd()
near_target(0.79, "cruise Mach above Mmo - 0.01 was not limited")
runtime.B747DR_airspeed_Mms = nil
runtime.clb_crz_setSpd()
near_target(0.81, "cruise Mach without Mmo")
runtime.B747DR_airspeed_Mms = 0.92
-- The descent states write it the same way.
fms_data.desspdmach = "805"
runtime.simDR_airspeed_mach = 0.82
runtime.des_src_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 1, "descent at M.82 did not select Mach")
near_target(0.805, "descent Mach was not written")
fms_data.desrestspd = "240"
runtime.B747DR_autothrottle_active = 1
runtime.des_spcres_setSpd()
assert(runtime.simDR_autopilot_airspeed_is_mach == 0, "SPD REST descent did not select CAS")
near_target(240, "descent SPD REST was not written")
runtime.simDR_ind_airspeed_kts_pilot = 200

-- The MCP IAS/MACH button and the automatic changeover in
-- B747_ap_ias_mach_mode (B747.70.xt.autopilot.lua) write the target in the
-- new unit in the same call: the knots target (X-Plane keeps
-- airspeed_dial_kts in knots), or that target as a Mach number at the
-- current altitude. The two slices load into one environment;
-- B747_afds_helpers is a file local of the autopilot script, so here it is a
-- global of the environment.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local function slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local ap = setmetatable({
    print = function() end,
    B747_afds_helpers = helpers,
    run_after_time = function() end,
    getVNAVState = function() return 0 end,
    setFMSData = function() end,
    B747_ap_button_switch_position_target = {},
    B747DR_ap_ias_mach_window_open = 1, B747DR_switchingIASMode = 0,
    B747DR_lastap_dial_airspeed = 0, B747DR_ap_ias_dial_value = 300,
    B747DR_ap_autoland = 0, B747DR_ap_vnav_state = 0, B747DR_ap_inVNAVdescent = 0,
    B747DR_airspeed_Vmc = 200, B747DR_airspeed_Vmo = 365, B747DR_airspeed_Mms = 0.92,
    B747DR_ap_ias_bug_value = 300, simDR_flap_ratio_control = 0, simDR_radarAlt1 = 30000,
    simDR_autopilot_flch_status = 2, simDR_ind_airspeed_kts_pilot = 300,
    simDR_pressureAlt1 = 33000, simDR_airspeed_mach = 0.83, simDR_vvi_fpm_pilot = 1500,
    simDR_autopilot_airspeed_kts = 300, simDR_autopilot_airspeed_kts_mach = 300,
    simDR_autopilot_airspeed_is_mach = 0
}, {__index = _G})
setfenv(assert(loadstring(slice(AP.."B747.70.xt.autopilot.lua",
    "function B747_updateIASWindow()", "function B747_ap_airspeed_up_CMDhandler(phase, duration)"))), ap)()
setfenv(assert(loadstring(slice(AP.."B747.70.xt.autopilot.lua",
    "function B747_ap_ias_mach_mode()", "function setDistances(fmsO)"))), ap)()
local function near_ap_target(expected, message)
    local actual = ap.simDR_autopilot_airspeed_kts_mach
    assert(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
        message..": autopilot target "..tostring(actual)..", expected "..expected)
end
local mach_300kt_fl330 = helpers.cas_to_mach(300, 33000)
ap.B747_ap_knots_mach_toggle_CMDhandler(0, 0)
assert(ap.simDR_autopilot_airspeed_is_mach == 1, "IAS/MACH button did not select Mach")
near_ap_target(mach_300kt_fl330, "IAS/MACH button to Mach did not write the Mach of the knots target")
ap.B747DR_ap_ias_mach_window_open = 1
ap.B747DR_switchingIASMode = 0
ap.simDR_autopilot_airspeed_kts_mach = mach_300kt_fl330
ap.B747_ap_knots_mach_toggle_CMDhandler(0, 0)
assert(ap.simDR_autopilot_airspeed_is_mach == 0, "IAS/MACH button did not select knots")
near_ap_target(300, "IAS/MACH button to knots did not write the knots target")
-- Automatic changeover to Mach above M.84 in a climb.
ap.B747DR_switchingIASMode = 0
ap.simDR_airspeed_mach = 0.845
ap.B747_ap_ias_mach_mode()
assert(ap.simDR_autopilot_airspeed_is_mach == 1, "climb above M.84 did not change over to Mach")
near_ap_target(mach_300kt_fl330, "automatic change to Mach did not write the Mach of the knots target")
-- Automatic changeover to knots above 310 kt in a descent.
ap.B747DR_switchingIASMode = 0
ap.simDR_airspeed_mach = 0.80
ap.simDR_vvi_fpm_pilot = -1500
ap.simDR_autopilot_airspeed_kts = 320
ap.simDR_autopilot_airspeed_kts_mach = 0.825
ap.B747_ap_ias_mach_mode()
assert(ap.simDR_autopilot_airspeed_is_mach == 0, "descent above 310 kt did not change over to knots")
near_ap_target(320, "automatic change to knots did not write the knots target")

print("VNAV climb-speed semantic tests passed")
