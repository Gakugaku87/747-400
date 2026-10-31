-- The SRM model (B747.45.srm_model.lua) in the aircraft (4-1 step 2a):
-- reads the captain's and F/O's airspeed and Mach, X-Plane's air data
-- computer failure, the FCUs' leading edge group A and their failures,
-- the air/ground relays, the autopilot's autoland and the failures
-- (laminar/B747/flt_ctrls/fail/...); writes the outboard aileron lockout
-- and the upper and lower rudder ratios, which the hydraulics module's
-- controlObject rows scale the surfaces with, AILERON LOCKOUT, RUD RATIO
-- SNGL and DUAL and their STATUS. B747.45.xt.fltCtrls.lua loads it after
-- the FCU's glue.
-- The stabilizer trim (step 2b): the control wheel switches (the 3D's
-- commands, and X-Plane's pitch trim commands as the captain's), the
-- alternate switches and the cutout switches (commands and datarefs: no
-- 3D), hydraulic systems 2 and 3, the buses, the gear, the LE flaps, the
-- column, the autopilots and the FCCs' autotrim command (the AFDS,
-- B747.19.xt.afds_control.lua) in; X-Plane's elevator trim (0-15 units on
-- -1..1; the stabilizer's angle comes from it in the hydraulics module),
-- STAB TRIM UNSCHD, >STAB TRIM 2 and 3, their STATUS and the autopilot's
-- disengagement out. X-Plane's own changes to the trim (the flight's
-- start, a trim axis, a test) move the model's stabilizer. Speed trim
-- (step 2c): its state and STATUS STAB SPEED TRIM.
dofile("B747.45.srm_model.lua")
local S = B747_srm_model

B747DR_srm_vc_capt              = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
B747DR_srm_vc_fo                = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_copilot")
simDR_srm_mach_capt             = find_dataref("sim/cockpit2/gauges/indicators/mach_pilot")
simDR_srm_mach_fo               = find_dataref("sim/cockpit2/gauges/indicators/mach_copilot")
simDR_srm_adc_fail              = find_dataref("sim/operation/failures/rel_adc_comp")
B747DR_srm_autoland             = find_dataref("laminar/B747/autopilot/autoland")
B747DR_srm_lockout_L            = find_dataref("laminar/B747/flt_ctrls/left_outer_aileron_lockout")
B747DR_srm_lockout_R            = find_dataref("laminar/B747/flt_ctrls/right_outer_aileron_lockout")
B747DR_srm_rudder_ratio         = find_dataref("laminar/B747/flt_ctrls/rudder_ratio")
B747DR_srm_rudder_ratio_upr     = find_dataref("laminar/B747/flt_ctrls/rudder_ratio_upr")
B747DR_srm_rudder_ratio_lwr     = find_dataref("laminar/B747/flt_ctrls/rudder_ratio_lwr")
B747DR_srm_fail_srm             = find_dataref("laminar/B747/flt_ctrls/fail/srm")
B747DR_srm_fail_lockout         = find_dataref("laminar/B747/flt_ctrls/fail/lockout_actuator")
B747DR_srm_fail_rrc             = find_dataref("laminar/B747/flt_ctrls/fail/rrc")
-- stabilizer trim
simDR_srm_elevator_trim         = find_dataref("sim/flightmodel2/controls/elevator_trim")
simDR_srm_yoke_pitch            = find_dataref("sim/cockpit2/controls/yoke_pitch_ratio")
simDR_srm_trim_runaway          = find_dataref("sim/operation/failures/rel_elv_trim_run")
simDR_srm_trim_fail             = find_dataref("sim/operation/failures/rel_trim_elv")
-- X-Plane's flight start on the ground or in the air (its flight load, not
-- the airplane's air/ground logic: the PSEU can still say ground then)
simDR_srm_xp_on_ground          = find_dataref("sim/flightmodel/failures/onground_any")
B747DR_srm_hyd_2                = find_dataref("laminar/B747/hydraulics/pressure_2")
B747DR_srm_hyd_3                = find_dataref("laminar/B747/hydraulics/pressure_3")
B747DR_srm_all_gear_down        = find_dataref("laminar/B747/gear/air_ground/all_gear_down")
B747DR_srm_bus_bat_main         = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_srm_bus_stby_main        = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_srm_ap_L                 = find_dataref("laminar/B747/autopilot/cmd_L_mode/status")
B747DR_srm_ap_C                 = find_dataref("laminar/B747/autopilot/cmd_C_mode/status")
B747DR_srm_ap_R                 = find_dataref("laminar/B747/autopilot/cmd_R_mode/status")
B747DR_srm_autotrim_cmd         = find_dataref("laminar/B747/flt_ctrls/stab_trim/autotrim_cmd")
B747DR_srm_frat                 = find_dataref("laminar/B747/flt_ctrls/stab_trim/frat")
B747DR_srm_stab_units           = find_dataref("laminar/B747/flt_ctrls/stab_trim/units")
B747DR_srm_speed_trim           = find_dataref("laminar/B747/flt_ctrls/stab_trim/speed_trim")
B747DR_srm_autotrim_valid       = find_dataref("laminar/B747/flt_ctrls/stab_trim/autotrim_valid")
B747DR_srm_valid                = find_dataref("laminar/B747/flt_ctrls/stab_trim/srm_valid")
B747DR_srm_cutout_sw            = find_dataref("laminar/B747/flt_ctrls/stab_trim/cutout_sw")
B747DR_srm_altn_sw              = find_dataref("laminar/B747/flt_ctrls/stab_trim/altn_sw")
B747DR_srm_fail_stab_actuator   = find_dataref("laminar/B747/flt_ctrls/fail/stab_actuator")
B747DR_srm_fail_stab_runaway    = find_dataref("laminar/B747/flt_ctrls/fail/stab_runaway")
B747CMD_srm_ap_trim_disengage   = find_command("laminar/B747/autopilot/trim_disengage")

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_AILERON_LOCKOUT = 3
local ADV_RUD_RATIO_DUAL, ADV_RUD_RATIO_SNGL = 261, 262
local STATUS_AILERON_LOCKOUT, STATUS_RUDDER_RATIO = 88, 89
local CAUTION_STAB_TRIM_UNSCHD = 60
local ADV_STAB_TRIM = {274, 275}    -- >STAB TRIM 2, 3
local STATUS_STAB_TRIM, STATUS_STAB_TRIM_UNSCHD, STATUS_STAB_AUTO_TRIM = 90, 91, 92
local STATUS_STAB_SPEED_TRIM = 93
local LE_A_IN = 0.01        -- a group A panel counts as in below this (the FCU's position)
local STAB_INIT_S = 3       -- from the flight's start, the stabilizer follows X-Plane's trim
local TRIM_SAME = 1e-4      -- X-Plane's trim this close to what was written is ours
-- (2026-10-31) the model's time step at most X-Plane's 0.05 s a frame: below
-- 20 fps X-Plane's time runs slower while SIM_PERIOD stays real time (s145:
-- one long frame moved the stabilizer 0.13 of X-Plane's trim at once)
local SRM_DT_MAX = 0.05

local srm_state = S.new()
local srm_inputs = S.inputs()
local srm_t = 0
local trim_w1, trim_w2 = nil, nil   -- the trim written last frame and the one before
local altn_held = false

-- the switches the commands hold (B747.45.xt.fltCtrls.lua and below): -1
-- nose down, 0, 1 nose up. The captain's: the 3D's switch and X-Plane's
-- pitch trim commands (a joystick's buttons)
B747_srm_switches = setmetatable({capt = 0, fo = 0, xp = 0, altn = 0}, {})
function B747_srm_trim_switch(who, dir, phase)
    if phase == 2 then
        if B747_srm_switches[who] == dir then B747_srm_switches[who] = 0 end
    else
        B747_srm_switches[who] = dir
    end
end

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_srm_flight_start()
    srm_state = S.new()
    srm_t = 0
    trim_w1, trim_w2 = nil, nil
    -- a new flight: the cutout switches guarded at AUTO, nothing held
    local sw = B747_srm_switches
    sw.capt, sw.fo, sw.xp, sw.altn = 0, 0, 0, 0
    altn_held = false
    B747DR_srm_cutout_sw[0], B747DR_srm_cutout_sw[1] = 0, 0
    B747DR_srm_altn_sw = 0
end

-- the alternate switches (both of the pair together) and the cutout
-- switches (one position per press), which the 3D does not have
function B747_altn_stab_trim_up_CMDhandler(phase, duration) B747_srm_trim_switch("altn", 1, phase) end
function B747_altn_stab_trim_dn_CMDhandler(phase, duration) B747_srm_trim_switch("altn", -1, phase) end
local function cutout_move(i, step, phase)
    if phase ~= 0 then return end
    local v = B747DR_srm_cutout_sw[i] + step
    if v >= S.CUTOUT and v <= S.ON then B747DR_srm_cutout_sw[i] = v end
end
function B747_stab_cutout_2_up_CMDhandler(phase, duration) cutout_move(0, 1, phase) end
function B747_stab_cutout_2_dn_CMDhandler(phase, duration) cutout_move(0, -1, phase) end
function B747_stab_cutout_3_up_CMDhandler(phase, duration) cutout_move(1, 1, phase) end
function B747_stab_cutout_3_dn_CMDhandler(phase, duration) cutout_move(1, -1, phase) end
B747CMD_altn_stab_trim_up       = deferred_command("laminar/B747/flt_ctrls/altn_stab_trim_up", "Alternate Stabilizer Trim Nose Up", B747_altn_stab_trim_up_CMDhandler)
B747CMD_altn_stab_trim_dn       = deferred_command("laminar/B747/flt_ctrls/altn_stab_trim_dn", "Alternate Stabilizer Trim Nose Down", B747_altn_stab_trim_dn_CMDhandler)
B747CMD_stab_cutout_2_up        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_2_up", "Stab Trim Cutout 2 toward ON", B747_stab_cutout_2_up_CMDhandler)
B747CMD_stab_cutout_2_dn        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_2_dn", "Stab Trim Cutout 2 toward CUTOUT", B747_stab_cutout_2_dn_CMDhandler)
B747CMD_stab_cutout_3_up        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_3_up", "Stab Trim Cutout 3 toward ON", B747_stab_cutout_3_up_CMDhandler)
B747CMD_stab_cutout_3_dn        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_3_dn", "Stab Trim Cutout 3 toward CUTOUT", B747_stab_cutout_3_dn_CMDhandler)

local function units(trim) return 7.5 * (trim + 1) end
local function trim_of(u) return u / 7.5 - 1 end
-- one switch pair from two sources: either, or both the same way
local function either(a, b)
    if a == 0 then return b end
    if b == 0 or b == a then return a end
    return 0
end
local function dir_of(v) return (v > 0.5 and 1) or (v < -0.5 and -1) or 0 end

function B747_srm()
    local inp = srm_inputs
    inp.vc[1], inp.vc[2] = B747DR_srm_vc_capt, B747DR_srm_vc_fo
    inp.mach[1], inp.mach[2] = simDR_srm_mach_capt, simDR_srm_mach_fo
    local adc = simDR_srm_adc_fail ~= 6
    inp.air_valid[1], inp.air_valid[2] = adc, adc
    -- LE group A: the inboard and midspan groups on both wings (the FCU)
    local a_in = true
    for i = 0, 3 do
        if B747DR_fcu_le[i] > LE_A_IN then a_in = false end
    end
    inp.le_a_in = a_in
    inp.le_valid = B747DR_fcu_fail_fcu[0] < 0.5 or B747DR_fcu_fail_fcu[1] < 0.5 or B747DR_fcu_fail_fcu[2] < 0.5
    inp.on_ground = B747DR_fcu_pri_gnd == 1
    inp.autoland = B747DR_srm_autoland == 1
    inp.srm_fail[1] = B747DR_srm_fail_srm[0] > 0.5
    inp.srm_fail[2] = B747DR_srm_fail_srm[1] > 0.5
    inp.lockout_stuck = B747DR_srm_fail_lockout > 0.5
    inp.rrc_stuck[1] = B747DR_srm_fail_rrc[0] > 0.5
    inp.rrc_stuck[2] = B747DR_srm_fail_rrc[1] > 0.5

    -- stabilizer trim
    local sw = B747_srm_switches
    inp.trim_capt = either(sw.capt, sw.xp)
    inp.trim_fo = sw.fo
    -- the alternate switches: the commands hold the dataref (back to 0 when
    -- released); otherwise as written (a test)
    local altn = B747DR_srm_altn_sw
    if sw.altn ~= 0 or altn_held then altn = sw.altn end
    altn_held = sw.altn ~= 0
    if altn ~= B747DR_srm_altn_sw then B747DR_srm_altn_sw = altn end
    inp.altn = dir_of(altn)
    for k = 1, 2 do
        inp.cutout[k] = dir_of(B747DR_srm_cutout_sw[k - 1])     -- -1 CUTOUT, 0 AUTO, 1 ON
        inp.stcm_fail[k] = B747DR_srm_fail_stab_actuator[k - 1] > 0.5 or simDR_srm_trim_fail == 6
        inp.runaway[k] = dir_of(B747DR_srm_fail_stab_runaway[k - 1])
    end
    -- X-Plane's elevator trim runaway: system 3's module runs nose up (estimate)
    local xp_runaway = simDR_srm_trim_runaway == 6
    if xp_runaway and inp.runaway[2] == 0 then inp.runaway[2] = 1 end
    inp.hyd_psi[1], inp.hyd_psi[2] = B747DR_srm_hyd_2, B747DR_srm_hyd_3
    inp.column = simDR_srm_yoke_pitch
    inp.ap_l, inp.ap_c, inp.ap_r = B747DR_srm_ap_L > 0.5, B747DR_srm_ap_C > 0.5, B747DR_srm_ap_R > 0.5
    local dc = B747DR_fcu_bus_dc
    inp.autotrim_cmd = dir_of(B747DR_srm_autotrim_cmd)
    inp.frat_req = B747DR_srm_frat > 0.5
    inp.gear_down = B747DR_srm_all_gear_down == 1
    local le_up = true
    for i = 0, 5 do
        if B747DR_fcu_le[i] > LE_A_IN then le_up = false end
    end
    inp.le_up = le_up
    -- power (ATA22 p.116-118): SRM L from the standby AC or battery bus and
    -- DC 3, SRM R from AC 2 or DC 2 and DC 2; the wheel switches DC 3, the
    -- alternate switches the battery bus
    local bat = B747DR_srm_bus_bat_main == 1
    inp.srm_pwr[1] = dc[2] > 0.5 and (B747DR_srm_bus_stby_main == 1 or bat)
    inp.srm_pwr[2] = dc[1] > 0.5
    inp.manual_pwr = dc[2] > 0.5
    inp.altn_pwr = bat

    -- X-Plane's trim: followed at a start on the ground; afterwards a value
    -- that is not one we wrote (allowing for XTLua's one-frame lag) is an
    -- outside change. An air start keeps the model's stabilizer (7.5 units):
    -- X-Plane trims the airplane there for its own trim, not for the
    -- stabilizer this aircraft drives (0.5 at FL350, 45 degrees nose up
    -- without the A/P: 2026-10-26; the 7.5 units an estimate)
    local xp = simDR_srm_elevator_trim
    srm_t = srm_t + SIM_PERIOD
    local starting = srm_t < STAB_INIT_S
    if (starting and simDR_srm_xp_on_ground == 1) or (not starting and trim_w1
        and math.abs(xp - trim_w1) > TRIM_SAME and math.abs(xp - (trim_w2 or trim_w1)) > TRIM_SAME
        and not xp_runaway) then
        S.stab_set(srm_state, units(xp))
    end

    local out = S.update(srm_state, inp, math.min(SIM_PERIOD, SRM_DT_MAX))

    -- the stabilizer (X-Plane keeps a float: compare with a margin)
    local trim = trim_of(out.stab_units)
    if math.abs(xp - trim) > 1e-6 then simDR_srm_elevator_trim = trim end
    trim_w2, trim_w1 = trim_w1, trim
    if B747DR_srm_stab_units ~= out.stab_units then B747DR_srm_stab_units = out.stab_units end
    local sp = flag(out.speed_trim)
    if B747DR_srm_speed_trim ~= sp then B747DR_srm_speed_trim = sp end
    if out.ap_disengage then B747CMD_srm_ap_trim_disengage:once() end
    -- the autotrim valid to the FCCs (6-3 step 5a: the AFDS's engage
    -- interlocks) and the SRMs' validity (step 5b: the autoland capability)
    for k = 1, 2 do
        local v = flag(out.autotrim_valid[k])
        if B747DR_srm_autotrim_valid[k - 1] ~= v then B747DR_srm_autotrim_valid[k - 1] = v end
        v = flag(out.srm_valid[k])
        if B747DR_srm_valid[k - 1] ~= v then B747DR_srm_valid[k - 1] = v end
    end

    -- the controlObject rows' scales (the right outboard aileron's is negative)
    local lock = out.lockout
    if B747DR_srm_lockout_L ~= lock then B747DR_srm_lockout_L = lock end
    if B747DR_srm_lockout_R ~= -lock then B747DR_srm_lockout_R = -lock end
    local upr, lwr = out.rudder_ratio[S.UPR], out.rudder_ratio[S.LWR]
    if B747DR_srm_rudder_ratio_upr ~= upr then B747DR_srm_rudder_ratio_upr = upr end
    if B747DR_srm_rudder_ratio_lwr ~= lwr then B747DR_srm_rudder_ratio_lwr = lwr end
    if B747DR_srm_rudder_ratio ~= lwr then B747DR_srm_rudder_ratio = lwr end

    -- messages (FCOM p.957; ATA27 p.133, p.685)
    put(B747DR_CAS_advisory_status, ADV_AILERON_LOCKOUT, flag(out.aileron_lockout))
    put(B747DR_CAS_advisory_status, ADV_RUD_RATIO_DUAL, flag(out.rud_ratio_dual))
    put(B747DR_CAS_advisory_status, ADV_RUD_RATIO_SNGL, flag(out.rud_ratio_sngl))
    put(B747DR_fcu_status, STATUS_AILERON_LOCKOUT, flag(out.aileron_lockout))
    put(B747DR_fcu_status, STATUS_RUDDER_RATIO, flag(out.st_rudder_ratio))
    -- (FCOM p.958; ATA27 p.523)
    put(B747DR_CAS_caution_status, CAUTION_STAB_TRIM_UNSCHD, flag(out.unschd))
    put(B747DR_CAS_advisory_status, ADV_STAB_TRIM[1], flag(out.stab_trim[1]))
    put(B747DR_CAS_advisory_status, ADV_STAB_TRIM[2], flag(out.stab_trim[2]))
    put(B747DR_fcu_status, STATUS_STAB_TRIM, flag(out.st_stab_trim))
    put(B747DR_fcu_status, STATUS_STAB_TRIM_UNSCHD, flag(out.st_unschd))
    put(B747DR_fcu_status, STATUS_STAB_AUTO_TRIM, flag(out.st_auto_trim))
    put(B747DR_fcu_status, STATUS_STAB_SPEED_TRIM, flag(out.st_speed_trim))
end
