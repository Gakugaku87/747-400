-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P42] The VNAV climb speed target is never above the climb's limits where they apply: the SPD REST and the SPD
-- TRANS below their altitudes, the route's constraint speed and the flaps' (FCOM: the FMC's speed transition and
-- restrictions are limits of the commanded speed). The climb's IAS - 15 kt floor (a target cut by more than 15 kt
-- comes down by steps, one a recalculation) raised the target past them: on p35-line1 (EIDW, 2026-10-20) the climb
-- resumed from the SID's 9,000 ft level-off with the IAS running to 270 kt, and VNAV asked for 254.7-255.3 kt below
-- 10,000 ft (the kit's spd_trans_rest FAIL, also on p32-line1). Where no limit binds the floor stays.
-- Loads the production VNAV speed state machine with mocked simulator interfaces; logic only.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks, failures = 0, {}
local function equal(actual, expected, message)
    checks = checks + 1
    if actual ~= expected then
        failures[#failures + 1] = message..": "..tostring(actual).." ~= "..tostring(expected)
    end
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
    B747DR_airspeed_Vf0=220, B747DR_airspeed_Vf1=200, B747DR_airspeed_Vf5=190,
    B747DR_airspeed_Vf10=180, B747DR_airspeed_Vf20=170, B747DR_airspeed_Vf25=160,
    B747DR_vnav_constraint_speed=0,
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

-- A sea-level departure datum, the takeoff past its acceleration.
runtime.simDR_onGround = 1
runtime.simDR_pressureAlt1 = 0
runtime.simDR_ind_airspeed_kts_pilot = 100
runtime.B747_update_takeoff_profile()
runtime.simDR_onGround = 0
runtime.simDR_pressureAlt1 = 3000
runtime.simDR_ind_airspeed_kts_pilot = 260
runtime.B747_update_takeoff_profile()

-- The climb's state and IAS target at this altitude, IAS, flap handle, constraint speed and (in_mach) the target in Mach.
local function climb(altitude_ft, ias_kts, flap_ratio, constraint_kts, in_mach)
    runtime.simDR_pressureAlt1 = altitude_ft
    runtime.simDR_ind_airspeed_kts_pilot = ias_kts
    runtime.simDR_flap_ratio_control = flap_ratio or 0
    runtime.B747DR_vnav_constraint_speed = constraint_kts or 0
    runtime.simDR_autopilot_airspeed_is_mach = in_mach or 0
    runtime.B747_invalidate_vnav_speed("test")
    runtime.B747_vnav_setClimbspeed()
    return runtime.B747_get_vnav_speed_diagnostics().state, runtime.B747DR_ap_ias_dial_value
end

-- SPD TRANS 250/10000: 270 kt below it (p35-line1's IAS after resuming the climb at 8,948 ft, 9,200-9,600 ft) is
-- asked for 250, not 255.
local state, target = climb(8945, 270)
equal(state, "clb_spcres/IAS", "SPD TRANS state below 10,000 ft")
equal(target, 250, "270 kt below 10,000 ft: SPD TRANS's 250 kt, not IAS - 15")
state, target = climb(9193, 269.7)
equal(target, 250, "269.7 kt at 9,193 ft (p35-line1): 250 kt")
state, target = climb(8945, 262)
equal(target, 250, "262 kt below 10,000 ft: 250 kt as before")
state, target = climb(8945, 240)
equal(target, 250, "240 kt below 10,000 ft: accelerates to 250 kt as before")
-- the SPD TRANS state is flown to 100 ft above its altitude, 10,100 ft itself included (review 44)
state, target = climb(10100, 270)
equal(state, "clb_spcres/IAS", "SPD TRANS state at 10,100 ft")
equal(target, 250, "270 kt at 10,100 ft: 250 kt")
-- with flaps 5 (Vf1 + 15 = 215 kt) the flaps' limit, not IAS - 15 (245 kt)
state, target = climb(4000, 260, 0.25)
equal(target, 215, "flaps 5 at 260 kt: the flaps' 215 kt, not IAS - 15")
-- a constraint speed of 230 kt below 10,000 ft: 230
state, target = climb(6000, 265, 0, 230)
equal(target, 230, "a 230 kt constraint at 265 kt below 10,000 ft: 230 kt, not IAS - 15")

-- SPD REST 210/8000: 210 below it whatever the IAS (the floor asked for 245 kt at 260 kt)
fms.clbrestspd = "210"
fms.clbrestalt = "8000"
state, target = climb(3000, 260)
equal(state, "clb_aptres/IAS", "SPD REST state below its altitude")
equal(target, 210, "260 kt below SPD REST 210/8000: 210 kt, not IAS - 15")
state, target = climb(3000, 222)
equal(target, 210, "222 kt below SPD REST: 210 kt as before")
-- a SPD REST above SPD TRANS (260/12000): 250 below 10,000 ft, 260 above it
fms.clbrestspd = "260"
fms.clbrestalt = "12000"
state, target = climb(9000, 245)
equal(state, "clb_aptres/IAS", "SPD REST 260/12000 at 9,000 ft")
equal(target, 250, "SPD REST 260/12000 below SPD TRANS 250/10000: 250 kt")
state, target = climb(11000, 245)
equal(target, 260, "SPD REST 260/12000 above 10,000 ft: 260 kt")
-- a route constraint below the flaps' manoeuvre speed keeps the flaps' speed (B747_constraint_speed_cap), but never
-- above the target without it (review 44): SPD REST 210 with a 200 kt constraint and Vf0 220 is 210, not 220
fms.clbrestspd = "210"
fms.clbrestalt = "8000"
state, target = climb(3000, 205, 0, 200)
equal(target, 210, "SPD REST 210 and a 200 kt constraint below Vf0 220: 210 kt, not 220")
fms.clbrestspd = "---"
fms.clbrestalt = "-----"
-- heavy, Vf0 252 above SPD TRANS: a 240 kt constraint leaves 250 kt, not 252
runtime.B747DR_airspeed_Vf0 = 252
state, target = climb(6000, 245, 0, 240)
equal(target, 250, "SPD TRANS 250 and a 240 kt constraint below Vf0 252: 250 kt, not 252")
runtime.B747DR_airspeed_Vf0 = 220
fms.clbrestspd = "---"
fms.clbrestalt = "-----"

-- Above SPD TRANS (ECON 320 kt): a 230 kt constraint caps the floor; with no limit binding the floor stays.
state, target = climb(12000, 265, 0, 230)
equal(state, "clb_nores/IAS", "ECON climb state above 10,000 ft")
equal(target, 230, "a 230 kt constraint at 265 kt above 10,000 ft: 230 kt, not IAS - 15")
state, target = climb(12000, 350)
equal(target, 335, "350 kt above 10,000 ft with no limit: IAS - 15 as before")
state, target = climb(12000, 300)
equal(target, 320, "300 kt above 10,000 ft: ECON 320 kt as before")
state, target = climb(10200, 252)
equal(target, 320, "past 10,100 ft: ECON 320 kt as before")

-- [P47] SPD REST and SPD TRANS are limits, not targets: the FMC commands the lowest of the ECON (or selected) climb
-- speed and the restrictions that apply here (review 44, NIT-4). A SPD REST above the ECON climb speed, or SPD TRANS
-- above a selected climb speed, was flown as the target.
-- (The CLB page takes speeds of 130-300 kt; review 51.)
fms.clbrestspd = "300"
fms.clbrestalt = "12000"
fms.clbspd = "290"
state, target = climb(11000, 290)
equal(state, "clb_aptres/IAS", "SPD REST 300/12000 at 11,000 ft")
equal(target, 290, "SPD REST 300/12000 above an ECON of 290 kt: 290 kt, not 300")
state, target = climb(9000, 250)
equal(target, 250, "SPD REST 300/12000 below SPD TRANS 250/10000: 250 kt as before")
-- a selected climb speed of 240 kt: 240 below SPD REST 300/12000 and below SPD TRANS 250/10000
fms.clbspd = "240"
state, target = climb(11000, 240)
equal(target, 240, "a 240 kt climb speed below SPD REST 300/12000: 240 kt, not 300")
fms.clbrestspd = "---"
fms.clbrestalt = "-----"
state, target = climb(6000, 240)
equal(state, "clb_spcres/IAS", "SPD TRANS state with a 240 kt climb speed")
equal(target, 240, "a 240 kt climb speed below SPD TRANS 250/10000: 240 kt, not 250")
-- a selected climb speed below the flaps' manoeuvre speed (130 kt, Vf0 220) gives the manoeuvre speed under SPD TRANS,
-- as a constraint does (review 51): it gave Vmc + 10 (145 kt here; 204 kt at 233 t, 14 kt under Vf0)
fms.clbspd = "130"
state, target = climb(6000, 200)
equal(target, 220, "a 130 kt climb speed below SPD TRANS with Vf0 220: 220 kt, not Vmc + 10")
-- and the same above SPD TRANS: clb_nores floored it only at Vmc + 10, so the target dropped past 10,100 ft (217.7 to
-- 204.3 kt at 233 t; review 52)
state, target = climb(12000, 200)
equal(state, "clb_nores/IAS", "ECON climb state with a 130 kt climb speed")
equal(target, 220, "a 130 kt climb speed above SPD TRANS with Vf0 220: 220 kt, not Vmc + 10")
fms.clbspd = "320"

-- [P48] A route constraint caps the Mach climb too. Above the climb Mach (M.80 against .78 at FL300) the climb flew
-- the climb Mach whatever the constraint: a 250 kt constraint gave M.78, 295.6 kt by the add-on's conversion (review
-- 44, NIT-4; review 51). Its CAS is flown when it is the slower; a constraint above the climb Mach's CAS leaves the
-- climb Mach.
runtime.simDR_airspeed_mach = 0.80
state, target = climb(30000, 290, 0, 250)
equal(state, "clb_nores/IAS", "a 250 kt constraint at FL300 at M.80: IAS")
equal(target, 250, "a 250 kt constraint at FL300 at M.80: 250 kt, not M.78")
-- the same with the target already in Mach (review 51)
state, target = climb(30000, 290, 0, 250, 1)
equal(state, "clb_nores/IAS", "a 250 kt constraint at FL300 at M.80, the target in Mach: IAS")
equal(target, 250, "a 250 kt constraint at FL300 at M.80, the target in Mach: 250 kt, not M.78")
state, target = climb(30000, 290, 0, 310)
equal(state, "clb_nores/MACH", "a 310 kt constraint at FL300 at M.80 (above M.78's 295.6 kt): Mach as before")
equal(target, 78, "a 310 kt constraint at FL300 at M.80: M.78 as before")
state, target = climb(30000, 290)
equal(state, "clb_nores/MACH", "no constraint at FL300 at M.80: Mach as before")
equal(target, 78, "no constraint at FL300 at M.80: M.78 as before")
runtime.simDR_airspeed_mach = 0.5

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV climb speed cap tests passed: "..checks)
