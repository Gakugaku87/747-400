-- The SRM model (B747.45.srm_model.lua) in the aircraft (4-1 step 2a):
-- reads the captain's and F/O's airspeed and Mach, X-Plane's air data
-- computer failure, the FCUs' leading edge group A and their failures,
-- the air/ground relays, the autopilot's autoland and the failures
-- (laminar/B747/flt_ctrls/fail/...); writes the outboard aileron lockout
-- and the upper and lower rudder ratios, which the hydraulics module's
-- controlObject rows scale the surfaces with, AILERON LOCKOUT, RUD RATIO
-- SNGL and DUAL and their STATUS. B747.45.xt.fltCtrls.lua loads it after
-- the FCU's glue.
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

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_AILERON_LOCKOUT = 3
local ADV_RUD_RATIO_DUAL, ADV_RUD_RATIO_SNGL = 261, 262
local STATUS_AILERON_LOCKOUT, STATUS_RUDDER_RATIO = 88, 89
local LE_A_IN = 0.01        -- a group A panel counts as in below this (the FCU's position)

local srm_state = S.new()
local srm_inputs = S.inputs()

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_srm_flight_start()
    srm_state = S.new()
end

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

    local out = S.update(srm_state, inp, SIM_PERIOD)

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
end
