-- The air data model (B747.34.airdata_model.lua) in the aircraft: reads
-- X-Plane's pilot and copilot air data (ADC L: pitot 1, static 1, ADC 1;
-- ADC R: pitot 2, static 2, ADC 2) and its standby pitot-static (taken for
-- ADC C: estimate), their failures, the buses, the AIR DATA selectors, each
-- pilot's baro setting, and for the altitude alert the MCP altitude, the
-- A/P CMD lights, the glideslope capture, the flap lever, the PSEU and the
-- parking brake lever; writes each pilot's airspeed for the PFD
-- (laminar/B747/gauges/indicators/airspeed_kts_pilot, _copilot: the
-- selected ADC, 30 kt at the bottom), the sources and validity
-- (laminar/B747/airdata/...), OVERSPEED, ALT DISAGREE, >ALTITUDE ALERT,
-- IAS DISAGREE, >SOURCE SEL ADC and >AOA RIGHT. B747.34.xt.nav.lua loads it.
-- The 3D AIR DATA knobs have two positions (the 570's L / R: FCOM p.1043);
-- 0 is taken as L and 1 as R (estimate: their markings are not known).

dofile("B747.34.airdata_model.lua")
local A = B747_airdata_model


--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_ad_ias_pilot              = find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
simDR_ad_ias_copilot            = find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_copilot")
simDR_ad_ias_stby               = find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_stby")
simDR_ad_mach_pilot             = find_dataref("sim/cockpit2/gauges/indicators/mach_pilot")
simDR_ad_mach_copilot           = find_dataref("sim/cockpit2/gauges/indicators/mach_copilot")
simDR_ad_alt_pilot              = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_ad_alt_copilot            = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_copilot")
simDR_ad_alt_stby               = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_stby")
simDR_ad_vvi_pilot              = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_ad_vvi_copilot            = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_copilot")
simDR_ad_baro_pilot             = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
simDR_ad_baro_copilot           = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot")
simDR_ad_baro_stby              = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_stby")
simDR_ad_fail_adc1              = find_dataref("sim/operation/failures/rel_adc_comp")
simDR_ad_fail_adc2              = find_dataref("sim/operation/failures/rel_adc_comp_2")
simDR_ad_fail_aoa_cop           = find_dataref("sim/operation/failures/rel_cop_AOA")
simDR_ad_flap_lever             = find_dataref("sim/cockpit2/controls/flap_ratio")
simDR_ad_time                   = find_dataref("sim/time/total_running_time_sec")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_ad_sel_capt              = find_dataref("laminar/B747/flt_inst/air_data_src/capt/sel_dial_pos")
B747DR_ad_sel_fo                = find_dataref("laminar/B747/flt_inst/air_data_src/fo/sel_dial_pos")
B747DR_ad_bus_stby              = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_ad_bus_xfr_capt          = find_dataref("laminar/B747/electrical/bus/xfr_capt")
B747DR_ad_bus_xfr_fo            = find_dataref("laminar/B747/electrical/bus/xfr_fo")
B747DR_ad_mcp_alt               = find_dataref("laminar/B747/autopilot/heading/altitude_dial_ft")
B747DR_ad_cmd_L                 = find_dataref("laminar/B747/autopilot/cmd_L_mode/status")
B747DR_ad_cmd_C                 = find_dataref("laminar/B747/autopilot/cmd_C_mode/status")
B747DR_ad_cmd_R                 = find_dataref("laminar/B747/autopilot/cmd_R_mode/status")
B747DR_ad_pitch_mode            = find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
B747DR_ad_all_gear_down         = find_dataref("laminar/B747/gear/air_ground/all_gear_down")
B747DR_ad_pri_gnd               = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_ad_park_lever            = find_dataref("laminar/B747/flt_ctrls/parking_brake_ratio")
B747DR_ad_ias_capt              = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
B747DR_ad_ias_fo                = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_copilot")
B747DR_ad_src_capt              = find_dataref("laminar/B747/airdata/src_capt")
B747DR_ad_src_fo                = find_dataref("laminar/B747/airdata/src_fo")
B747DR_ad_valid                 = find_dataref("laminar/B747/airdata/valid")
B747DR_ad_valid_capt            = find_dataref("laminar/B747/airdata/valid_capt")
B747DR_ad_valid_fo              = find_dataref("laminar/B747/airdata/valid_fo")
B747DR_ad_alt_advise            = find_dataref("laminar/B747/airdata/alt_advise")
B747DR_ad_alt_alert             = find_dataref("laminar/B747/airdata/alt_alert")
B747DR_ad_fail                  = find_dataref("laminar/B747/airdata/fail/adc")
B747DR_CAS_warning_status       = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status       = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status      = find_dataref("laminar/B747/CAS/advisory_status")

-- EICAS slots (B747.87.xt.warning.lua)
local WARN_OVERSPEED = 22
local CAUT_ALT_DISAGREE, CAUT_ALTITUDE_ALERT, CAUT_IAS_DISAGREE = 1, 2, 44
local ADV_AOA_RIGHT, ADV_SOURCE_SEL_ADC = 12, 267
local LANDING_FLAPS = 0.83          -- the flap lever at 25 or 30
local MIN_IAS = 30                  -- the PFD's speed tape stops at 30 kt (ATA34_1 p.126)
local INIT_S = 3                    -- the first reads are 0

local ad_state = A.new()
local ad_inputs = A.inputs()
local ad_t0 = nil
local ad_last_alt_c = nil

-- the knob's position (0 L, 1 R) as an ADC (1 L, 3 R)
local function knob(pos)
    if pos >= 0.5 then return A.R end
    return A.L
end


--*************************************************************************************--
--** 				                 MAIN PROGRAM                 			    	 **--
--*************************************************************************************--

function B747_airdata()
    local now = simDR_ad_time
    if ad_t0 == nil then ad_t0 = now end
    if now - ad_t0 < INIT_S then
        -- until the model starts, each PFD's airspeed from its own side as
        -- before (the autopilot, FMC, EEC and SRM read it)
        local c, f = math.max(simDR_ad_ias_pilot, MIN_IAS), math.max(simDR_ad_ias_copilot, MIN_IAS)
        if B747DR_ad_ias_capt ~= c then B747DR_ad_ias_capt = c end
        if B747DR_ad_ias_fo ~= f then B747DR_ad_ias_fo = f end
        return
    end

    local inp = ad_inputs
    inp.power[1] = B747DR_ad_bus_stby > 0.5
    inp.power[2] = B747DR_ad_bus_xfr_capt > 0.5
    inp.power[3] = B747DR_ad_bus_xfr_fo > 0.5
    inp.fail[1] = simDR_ad_fail_adc1 == 6 or B747DR_ad_fail[0] > 0.5
    inp.fail[2] = B747DR_ad_fail[1] > 0.5
    inp.fail[3] = simDR_ad_fail_adc2 == 6 or B747DR_ad_fail[2] > 0.5
    inp.cas[1], inp.cas[2], inp.cas[3] = simDR_ad_ias_pilot, simDR_ad_ias_stby, simDR_ad_ias_copilot
    inp.mach[1], inp.mach[3] = simDR_ad_mach_pilot, simDR_ad_mach_copilot
    inp.alt_std[1] = A.pressure_alt(simDR_ad_alt_pilot, simDR_ad_baro_pilot)
    inp.alt_std[2] = A.pressure_alt(simDR_ad_alt_stby, simDR_ad_baro_stby)
    inp.alt_std[3] = A.pressure_alt(simDR_ad_alt_copilot, simDR_ad_baro_copilot)
    inp.vs[1], inp.vs[3] = simDR_ad_vvi_pilot, simDR_ad_vvi_copilot
    -- ADC C from the standby pitot-static: its Mach from its airspeed and
    -- altitude, its rate from its altitude (estimate)
    inp.mach[2] = A.mach_from(inp.cas[2], inp.alt_std[2])
    if ad_last_alt_c ~= nil and SIM_PERIOD > 0 then inp.vs[2] = (inp.alt_std[2] - ad_last_alt_c) / SIM_PERIOD * 60 end
    ad_last_alt_c = inp.alt_std[2]
    inp.sel_capt, inp.sel_fo = knob(B747DR_ad_sel_capt), knob(B747DR_ad_sel_fo)
    inp.baro_capt, inp.baro_fo = simDR_ad_baro_pilot, simDR_ad_baro_copilot
    inp.mcp_alt = B747DR_ad_mcp_alt
    local cmds = B747_nav_flag(B747DR_ad_cmd_L > 0.5) + B747_nav_flag(B747DR_ad_cmd_C > 0.5) + B747_nav_flag(B747DR_ad_cmd_R > 0.5)
    if cmds ~= 1 then inp.fcc_cmd = 0
    elseif B747DR_ad_cmd_L > 0.5 then inp.fcc_cmd = A.L
    elseif B747DR_ad_cmd_C > 0.5 then inp.fcc_cmd = A.C
    else inp.fcc_cmd = A.R end
    inp.gs_capture = B747DR_ad_pitch_mode == 2
    inp.landing_flaps = simDR_ad_flap_lever >= LANDING_FLAPS
    inp.gear_down = B747DR_ad_all_gear_down == 1
    inp.ground = B747DR_ad_pri_gnd == 1
    inp.park_brake = B747DR_ad_park_lever > 0.9
    local out = A.update(ad_state, inp, SIM_PERIOD)

    -- each PFD's airspeed from the selected ADC
    local ias_c = math.max(out.capt.cas, MIN_IAS)
    local ias_f = math.max(out.fo.cas, MIN_IAS)
    if B747DR_ad_ias_capt ~= ias_c then B747DR_ad_ias_capt = ias_c end
    if B747DR_ad_ias_fo ~= ias_f then B747DR_ad_ias_fo = ias_f end
    if B747DR_ad_src_capt ~= out.capt.src then B747DR_ad_src_capt = out.capt.src end
    if B747DR_ad_src_fo ~= out.fo.src then B747DR_ad_src_fo = out.fo.src end
    for i = 1, 3 do B747_nav_put(B747DR_ad_valid, i - 1, B747_nav_flag(out.valid[i])) end
    if B747DR_ad_valid_capt ~= B747_nav_flag(out.capt.valid) then B747DR_ad_valid_capt = B747_nav_flag(out.capt.valid) end
    if B747DR_ad_valid_fo ~= B747_nav_flag(out.fo.valid) then B747DR_ad_valid_fo = B747_nav_flag(out.fo.valid) end
    if B747DR_ad_alt_advise ~= B747_nav_flag(out.alt_advise) then B747DR_ad_alt_advise = B747_nav_flag(out.alt_advise) end
    if B747DR_ad_alt_alert ~= B747_nav_flag(out.alt_alert) then B747DR_ad_alt_alert = B747_nav_flag(out.alt_alert) end

    B747_nav_put(B747DR_CAS_warning_status, WARN_OVERSPEED, B747_nav_flag(out.overspeed))
    B747_nav_put(B747DR_CAS_caution_status, CAUT_ALT_DISAGREE, B747_nav_flag(out.alt_disagree))
    B747_nav_put(B747DR_CAS_caution_status, CAUT_ALTITUDE_ALERT, B747_nav_flag(out.alt_alert))
    B747_nav_put(B747DR_CAS_caution_status, CAUT_IAS_DISAGREE, B747_nav_flag(out.ias_disagree))
    B747_nav_put(B747DR_CAS_advisory_status, ADV_SOURCE_SEL_ADC, B747_nav_flag(out.source_sel_adc))
    -- >AOA RIGHT: the right vane (X-Plane's copilot AOA; NAV-07: it read the left)
    B747_nav_put(B747DR_CAS_advisory_status, ADV_AOA_RIGHT, B747_nav_flag(simDR_ad_fail_aoa_cop == 6))
end

function B747_airdata_flight_start()
    ad_state = A.new()
    ad_t0 = nil
    ad_last_alt_c = nil
end
