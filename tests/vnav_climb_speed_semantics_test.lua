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
-- A climb through FL310 (TST744L's step climb from FL310 flew this state
-- before a climb from the cruise phase kept the cruise Mach, B-8 below):
-- ECON 326 kt / M.815 at 300.4 kt and M.807.
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

-- [B-8] A step climb from the cruise phase is a cruise climb, flown at the cruise speed: once VNAV reached the
-- cruise state (within 500 ft of CRZ ALT), a climb to a higher CRZ ALT keeps the ECON cruise Mach (crzspd, here
-- .810) instead of the climb schedule (326 kt or the climb Mach .836: TST744L's BEDRA step from FL310 flew .836 and
-- 326 kt below the crossover). The descent and the ground end the cruise phase: a climb after them is a climb.
runtime.print = function() end
runtime.B747_rescale = function(in1, out1, in2, out2, x)
    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)
end
for k, v in pairs({clbspd = "326", clbmach = "836", crzspd = "810", accelht = "1500", thrredht = "1500",
        spdtransalt = "10000", transalt = "18000", desspdmach = "820", desspd = "300", destranspd = "250",
        desspdtransalt = "10000"}) do
    fms_data[k] = v
end
fms_data.clbrestalt, fms_data.desrestalt, fms_data.thrredflap = nil, nil, nil
for k, v in pairs({simDR_onGround = 0, simDR_altimeter_baro_inHg = 29.92, B747DR_airspeed_V2 = 160,
        B747DR_ap_vnav_state = 2, simDR_autopilot_fms_vnav = 0, B747DR_ap_inVNAVdescent = 0,
        B747DR_alt_capture_window = 500, B747DR_fmscurrentIndex = 5, simDRTime = 1000, B747BR_cruiseAlt = 31000,
        simDR_pressureAlt1 = 31000, simDR_ind_airspeed_kts_pilot = 306, simDR_airspeed_mach = 0.81,
        simDR_autopilot_airspeed_is_mach = 1, B747DR_vnav_constraint_speed = 0}) do
    runtime[k] = v
end
local function climb_speed(reason)
    runtime.B747_invalidate_vnav_speed(reason)
    runtime.B747_vnav_setClimbspeed()
    return runtime.simDR_autopilot_airspeed_is_mach, runtime.B747DR_ap_ias_dial_value
end
local is_mach, dial = climb_speed("level at CRZ ALT FL310")
assert(is_mach == 1 and dial == 81, "at CRZ ALT the cruise state did not fly the cruise Mach: "..tostring(dial))
runtime.B747BR_cruiseAlt = 33000
is_mach, dial = climb_speed("new cruise altitude accepted")
assert(is_mach == 1 and dial == 81,
    "the step climb from FL310 to FL330 left the cruise Mach .810 for "..tostring(dial)..(is_mach == 1 and " (Mach)" or " kt"))
runtime.simDR_pressureAlt1 = 32200
is_mach, dial = climb_speed("climbing through FL322")
assert(is_mach == 1 and dial == 81, "the step climb through FL322 left the cruise Mach: "..tostring(dial))
-- the descent ends the cruise phase: a climb from 20,000 ft after it flies the climb schedule
runtime.B747DR_ap_inVNAVdescent = 1
runtime.simDR_pressureAlt1 = 25000
runtime.B747_invalidate_vnav_speed("descent")
runtime.B747_vnav_setDescendspeed()
runtime.B747DR_ap_inVNAVdescent = 0
runtime.simDR_pressureAlt1, runtime.simDR_airspeed_mach, runtime.simDR_ind_airspeed_kts_pilot = 20000, 0.70, 300
runtime.simDR_autopilot_airspeed_is_mach = 0
is_mach, dial = climb_speed("climb after the descent")
assert(is_mach == 0 and dial == 326, "a climb after the descent did not fly the climb speed 326 kt: "..tostring(dial))
-- so does the ground: the next flight's climb
runtime.simDR_pressureAlt1, runtime.B747BR_cruiseAlt = 31000, 31000
runtime.simDR_airspeed_mach, runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_autopilot_airspeed_is_mach = 0.81, 306, 1
climb_speed("level at CRZ ALT again")
runtime.simDR_onGround, runtime.simDR_pressureAlt1 = 1, 50
climb_speed("landed")
runtime.simDR_onGround = 0
runtime.simDR_pressureAlt1, runtime.simDR_airspeed_mach, runtime.simDR_ind_airspeed_kts_pilot = 20000, 0.70, 300
runtime.simDR_autopilot_airspeed_is_mach = 0
is_mach, dial = climb_speed("the next flight's climb")
assert(is_mach == 0 and dial == 326, "the next flight's climb did not fly the climb speed 326 kt: "..tostring(dial))
-- [B-8] The cruise phase ends out of cruise even while VNAV is off (VNAV's per-frame update, B747_vnav_speed, ends
-- it before it returns): on the approach (flight phase 4, the G/S), in TOGA, below the transition altitude, with CRZ
-- ALT deleted; and VNAV enters it only at a valid CRZ ALT, at or above the transition altitude. A descent VNAV did
-- not fly left it set, and VNAV pushed in the go-around at 3,000 ft climbed at the cruise Mach .81 (520 KCAS) or
-- kept a stale 180 kt; with CRZ ALT deleted in the climb the cruise state set it, and the rest of the climb flew
-- .81 from FL205 (400 KCAS; a review). A climb in cruise after a descent in FLCH (still at CRZ ALT's cruise, above
-- the transition altitude) stays a cruise climb.
for k, v in pairs({B747DR_airspeed_Vf0 = 230, B747DR_airspeed_Vf1 = 210, B747DR_airspeed_Vf5 = 190,
        B747DR_airspeed_Vf10 = 180, B747DR_airspeed_Vf20 = 170, B747DR_airspeed_Vf25 = 160,
        B747DR_ap_flightPhase = 2, B747DR_ap_FMA_active_pitch_mode = 0}) do
    runtime[k] = v
end
fms_data.transpd = "250"
local function cruise_at_fl310()
    runtime.simDR_flap_ratio_control, runtime.B747DR_ap_vnav_state, runtime.B747DR_ap_flightPhase = 0, 2, 2
    runtime.simDR_pressureAlt1, runtime.B747BR_cruiseAlt = 31000, 31000
    runtime.simDR_airspeed_mach, runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_autopilot_airspeed_is_mach = 0.81, 306, 1
    local m, d = climb_speed("level at CRZ ALT FL310")
    assert(m == 1 and d == 81, "at CRZ ALT FL310 not the cruise Mach: "..tostring(d))
end
-- a descent in FLCH from cruise to FL250 and VNAV's climb back: still the cruise, the cruise Mach
cruise_at_fl310()
runtime.B747DR_ap_vnav_state, runtime.B747DR_ap_flightPhase, runtime.simDR_pressureAlt1 = 0, 3, 25000
runtime.B747_vnav_speed()
runtime.B747DR_ap_vnav_state, runtime.B747DR_ap_flightPhase = 2, 1
runtime.simDR_airspeed_mach, runtime.simDR_ind_airspeed_kts_pilot = 0.81, 340
is_mach, dial = climb_speed("VNAV climb back to CRZ ALT after FLCH")
assert(is_mach == 1 and dial == 81, "the climb back to CRZ ALT after a descent in FLCH left the cruise Mach: "
    ..tostring(dial)..(is_mach == 1 and " (Mach)" or " kt"))
-- the approach (G/S) and a go-around with VNAV pushed at 3,000 ft: the climb speed, not the cruise Mach nor a stale
-- target
for _, c in ipairs({{flap = 0, ias = 250, want = 250, name = "flaps up at 250 kt"},
        {flap = 0.167, ias = 246, want = 245, name = "flaps 1 at 246 kt"}}) do
    cruise_at_fl310()
    runtime.B747DR_ap_vnav_state, runtime.B747DR_ap_flightPhase, runtime.simDR_pressureAlt1 = 0, 3, 12000
    runtime.B747_vnav_speed()
    runtime.B747DR_ap_flightPhase, runtime.simDR_pressureAlt1 = 4, 1500
    runtime.B747_vnav_speed()
    runtime.B747DR_ap_FMA_active_pitch_mode, runtime.simDR_pressureAlt1 = 1, 2000
    runtime.B747_vnav_speed()
    runtime.B747DR_ap_FMA_active_pitch_mode, runtime.B747DR_ap_vnav_state, runtime.B747DR_ap_flightPhase = 4, 2, 1
    runtime.simDR_flap_ratio_control, runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_pressureAlt1 = c.flap, c.ias, 3000
    runtime.simDR_airspeed_mach, runtime.simDR_autopilot_airspeed_is_mach = c.ias / 600, 0
    runtime.B747DR_ap_ias_dial_value, runtime.simDR_autopilot_airspeed_kts_mach = 180, 180
    is_mach, dial = climb_speed("go-around, VNAV pushed")
    assert(is_mach == 0 and dial == c.want, string.format(
        "a go-around climb in VNAV at 3,000 ft (%s) after the cruise flew %s%s, not the climb speed %d kt", c.name,
        tostring(dial), is_mach == 1 and " (Mach)" or " kt", c.want))
end
runtime.simDR_flap_ratio_control, runtime.B747DR_ap_FMA_active_pitch_mode = 0, 0
-- CRZ ALT deleted in the climb (B744.fms.pages: B747BR_cruiseAlt 0) and entered again: still the climb speed
runtime.simDR_onGround, runtime.simDR_pressureAlt1 = 1, 50
climb_speed("on the ground")
runtime.simDR_onGround = 0
runtime.B747BR_cruiseAlt, runtime.simDR_pressureAlt1, runtime.simDR_ind_airspeed_kts_pilot = 35000, 20000, 326
runtime.simDR_airspeed_mach, runtime.simDR_autopilot_airspeed_is_mach = 0.70, 0
is_mach, dial = climb_speed("climb through FL200")
assert(is_mach == 0 and dial == 326, "the climb through FL200 did not fly 326 kt: "..tostring(dial))
runtime.B747BR_cruiseAlt = 0
climb_speed("FMC cruise altitude changed (deleted)")
runtime.B747BR_cruiseAlt, runtime.simDR_pressureAlt1 = 35000, 20500
is_mach, dial = climb_speed("FMC cruise altitude changed (FL350 again)")
assert(is_mach == 0 and dial == 326, "CRZ ALT deleted and entered again at FL205: not the climb speed 326 kt but "
    ..tostring(dial)..(is_mach == 1 and " (Mach)" or " kt"))
runtime.print = print

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

-- The same with the two datarefs these calls write and then use,
-- laminar/B747/autopilot/ap_monitor/last_airspeed and
-- sim/cockpit2/autopilot/airspeed_is_mach, reading back their old values
-- until the next frame (sync), as an XTLua dataref might (its first read
-- gives 0): the new-unit target must come from the speed and unit just
-- decided, not from those datarefs read back.
local synced = {B747DR_lastap_dial_airspeed = 0, simDR_autopilot_airspeed_is_mach = 0}
local pending = {}
for key in pairs(synced) do rawset(ap, key, nil) end
setmetatable(ap, {
    __index = function(_, key)
        if synced[key] ~= nil then return synced[key] end
        return _G[key]
    end,
    __newindex = function(t, key, value)
        if synced[key] ~= nil then pending[key] = value return end
        rawset(t, key, value)
    end})
local function sync()
    for key, value in pairs(pending) do synced[key] = value end
    pending = {}
end
ap.B747DR_ap_ias_mach_window_open = 1
ap.B747DR_switchingIASMode = 0
ap.simDR_airspeed_mach = 0.83
ap.simDR_vvi_fpm_pilot = 1500
ap.simDR_autopilot_airspeed_kts = 300
ap.simDR_autopilot_airspeed_kts_mach = 300
ap.B747_ap_knots_mach_toggle_CMDhandler(0, 0)
sync()
assert(ap.simDR_autopilot_airspeed_is_mach == 1, "IAS/MACH button (stale read-back) did not select Mach")
near_ap_target(mach_300kt_fl330, "IAS/MACH button to Mach with a stale read-back did not write the Mach of 300 kt")
ap.B747DR_ap_ias_mach_window_open = 1
ap.B747DR_switchingIASMode = 0
ap.simDR_autopilot_airspeed_kts_mach = mach_300kt_fl330
ap.B747_ap_knots_mach_toggle_CMDhandler(0, 0)
sync()
assert(ap.simDR_autopilot_airspeed_is_mach == 0, "IAS/MACH button (stale read-back) did not select knots")
near_ap_target(300, "IAS/MACH button to knots with a stale read-back did not write 300 kt")
ap.B747DR_switchingIASMode = 0
ap.simDR_airspeed_mach = 0.845
ap.B747_ap_ias_mach_mode()
sync()
assert(ap.simDR_autopilot_airspeed_is_mach == 1, "climb above M.84 (stale read-back) did not change over to Mach")
near_ap_target(mach_300kt_fl330, "automatic change to Mach with a stale read-back did not write the Mach of 300 kt")
ap.B747DR_switchingIASMode = 0
ap.simDR_airspeed_mach = 0.80
ap.simDR_vvi_fpm_pilot = -1500
ap.simDR_autopilot_airspeed_kts = 320
ap.simDR_autopilot_airspeed_kts_mach = 0.825
ap.B747_ap_ias_mach_mode()
sync()
assert(ap.simDR_autopilot_airspeed_is_mach == 0, "descent above 310 kt (stale read-back) did not change over to knots")
near_ap_target(320, "automatic change to knots with a stale read-back did not write 320 kt")

print("VNAV climb-speed semantic tests passed")
