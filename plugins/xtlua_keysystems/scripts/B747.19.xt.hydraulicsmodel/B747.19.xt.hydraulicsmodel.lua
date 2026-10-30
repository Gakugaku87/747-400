--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks
*****************************************************************************************
xt.hydraulicsmodel.lua
27/04/2020
]]
function deferred_command(name,desc,realFunc)
	return replace_command(name,realFunc)
end

function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end
function getHeadingDifference(desireddirection,current_heading)
	error = current_heading - desireddirection
	if (error >  180) then error =error- 360 end
	if (error < -180) then error =error+ 360 end
	return error
end
--simDR_autopilot_nav_status = find_dataref("sim/cockpit2/autopilot/nav_status")
simDR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/actual_nav_status")
B747DR_ap_ATT     	                = deferred_dataref("laminar/B747/autopilot/att_rate", "number")
B747DR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/nav_status")
simCMD_pause = find_command("sim/operation/pause_toggle")
debug_flight_directors     = deferred_dataref("laminar/B747/debug/flight_directors", "number")
simDR_autopilot_hold_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_hold_ft")
simDR_autopilot_alt_hold_status         = find_dataref("laminar/B747/autopilot/altitude_hold_status")
B747DR_autopilot_TOGA_status     	= deferred_dataref("laminar/B747/autopilot/TOGA_status","number")
B747DR_ap_flightPhase 				= deferred_dataref("laminar/B747/autopilot/flightPhase", "number")
B747DR_autopilot_altitude_ft_pfd = deferred_dataref("laminar/B747/autopilot/heading/altitude_dial_ft_pfd", "number")
simDR_radarAlt1 = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
B747DR_flap_ratio = deferred_dataref("laminar/B747/cablecontrols/flap_ratio", "number")
B747DR_flap_lever_detent		= deferred_dataref("laminar/B747/flt_ctrls/flap_lever_detent", "number")
B747DR_pidRollP = deferred_dataref("laminar/B747/flt_ctrls/pid/roll/p", "number")
B747DR_pidRollI = deferred_dataref("laminar/B747/flt_ctrls/pid/roll/i", "number")
B747DR_pidRollDL = deferred_dataref("laminar/B747/flt_ctrls/pid/roll/dl", "number")
B747DR_pidRollDH = deferred_dataref("laminar/B747/flt_ctrls/pid/roll/dh", "number")
B747DR_pidRollD = deferred_dataref("laminar/B747/flt_ctrls/pid/roll/d", "number")

B747DR_pidPitchPL = deferred_dataref("laminar/B747/flt_ctrls/pid/pitch/pl", "number")
B747DR_pidPitchPH = deferred_dataref("laminar/B747/flt_ctrls/pid/pitch/ph", "number")
B747DR_pidPitchP = deferred_dataref("laminar/B747/flt_ctrls/pid/pitch/p", "number")
B747DR_pidPitchI = deferred_dataref("laminar/B747/flt_ctrls/pid/pitch/i", "number")
B747DR_pidPitchD = deferred_dataref("laminar/B747/flt_ctrls/pid/pitch/d", "number")

-- (the yaw dampers' PID gains, laminar/B747/flt_ctrls/pid/yaw/...: no
-- longer used, the yaw damper model's law: 6-3 step 6b)
B747DR_alt_capture_window        = deferred_dataref("laminar/B747/autopilot/ap_monitor/alt_capture_window", "number")

simDR_AHARS_heading_deg_pilot = find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
simDR_autopilot_TOGA_pitch_deg      	= find_dataref("sim/cockpit2/autopilot/TOGA_pitch_deg")
B747DR_controlOverrides   = find_dataref("xtlua/controlObject")
B747DR_speedbrake_lever     	= find_dataref("laminar/B747/flt_ctrls/speedbrake_lever")   -- the flight controls module's
simDR_prop_mode                 = find_dataref("sim/cockpit2/engine/actuators/prop_mode")
B747DR_button_switch_position   = find_dataref("laminar/B747/button_switch/position")
--simDR_ias_pilot				= find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
simDR_ias_pilot				= find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
B747DR_display_N1					= deferred_dataref("laminar/B747/engines/display_N1", "array[4]")
B747DR_display_N2					= deferred_dataref("laminar/B747/engines/display_N2", "array[4]")
B747_duct_pressure_L                = deferred_dataref("laminar/B747/air/duct_pressure_L", "number")
B747_duct_pressure_R                = deferred_dataref("laminar/B747/air/duct_pressure_R", "number")
--B747DR_engine1psi    = deferred_dataref("laminar/B747/air/engine1/bleed_air_psi", "number")
--B747DR_engine4psi    = deferred_dataref("laminar/B747/air/engine4/bleed_air_psi", "number")
simDR_startup_running           = find_dataref("sim/operation/prefs/startup_running")
simDRTime=find_dataref("sim/time/total_running_time_sec")
B747DR_hyd_temp = find_dataref("sim/physics/earth_temp_c")
B747DR_hyd_sys_pressure_1      = deferred_dataref("laminar/B747/hydraulics/pressure_1", "number")
B747DR_hyd_sys_pressure_2      = deferred_dataref("laminar/B747/hydraulics/pressure_2", "number")
B747DR_hyd_sys_pressure_3      = deferred_dataref("laminar/B747/hydraulics/pressure_3", "number")
B747DR_hyd_sys_pressure_4      = deferred_dataref("laminar/B747/hydraulics/pressure_4", "number")
B747DR_hyd_sys_pressure_dsp_1      = deferred_dataref("laminar/B747/hydraulics/pressure_dsp_1", "number")
B747DR_hyd_sys_pressure_dsp_2      = deferred_dataref("laminar/B747/hydraulics/pressure_dsp_2", "number")
B747DR_hyd_sys_pressure_dsp_3      = deferred_dataref("laminar/B747/hydraulics/pressure_dsp_3", "number")
B747DR_hyd_sys_pressure_dsp_4      = deferred_dataref("laminar/B747/hydraulics/pressure_dsp_4", "number")
B747DR_hyd_sys_pressure_13      = deferred_dataref("laminar/B747/hydraulics/pressure_13", "number")
B747DR_hyd_sys_pressure_23      = deferred_dataref("laminar/B747/hydraulics/pressure_23", "number")
B747DR_hyd_sys_pressure_24      = deferred_dataref("laminar/B747/hydraulics/pressure_24", "number")
B747DR_hyd_sys_pressure_234      = deferred_dataref("laminar/B747/hydraulics/pressure_234", "number")
B747DR_hyd_sys_pressure_use_1      = deferred_dataref("laminar/B747/hydraulics/pressure_use_1", "number")
B747DR_hyd_sys_pressure_use_2      = deferred_dataref("laminar/B747/hydraulics/pressure_use_2", "number")
B747DR_hyd_sys_pressure_use_3      = deferred_dataref("laminar/B747/hydraulics/pressure_use_3", "number")
B747DR_hyd_sys_pressure_use_4      = deferred_dataref("laminar/B747/hydraulics/pressure_use_4", "number")

B747DR_hyd_sys_temp_1      = deferred_dataref("laminar/B747/hydraulics/temp_1", "number")
B747DR_hyd_sys_temp_2      = deferred_dataref("laminar/B747/hydraulics/temp_2", "number")
B747DR_hyd_sys_temp_3      = deferred_dataref("laminar/B747/hydraulics/temp_3", "number")
B747DR_hyd_sys_temp_4      = deferred_dataref("laminar/B747/hydraulics/temp_4", "number")

B747DR_hyd_sys_res_1      = deferred_dataref("laminar/B747/hydraulics/res_1", "number")
B747DR_hyd_sys_res_2      = deferred_dataref("laminar/B747/hydraulics/res_2", "number")
B747DR_hyd_sys_res_3      = deferred_dataref("laminar/B747/hydraulics/res_3", "number")
B747DR_hyd_sys_res_4      = deferred_dataref("laminar/B747/hydraulics/res_4", "number")

B747DR_hyd_sys_restotal_1      = deferred_dataref("laminar/B747/hydraulics/restotal_1", "number")
B747DR_hyd_sys_restotal_2      = deferred_dataref("laminar/B747/hydraulics/restotal_2", "number")
B747DR_hyd_sys_restotal_3      = deferred_dataref("laminar/B747/hydraulics/restotal_3", "number")
B747DR_hyd_sys_restotal_4      = deferred_dataref("laminar/B747/hydraulics/restotal_4", "number")

B747DR_hyd_dem_pressure_1      = deferred_dataref("laminar/B747/hydraulics/dem_pressure_1", "number")
B747DR_hyd_dem_pressure_2      = deferred_dataref("laminar/B747/hydraulics/dem_pressure_2", "number")
B747DR_hyd_dem_pressure_3      = deferred_dataref("laminar/B747/hydraulics/dem_pressure_3", "number")
B747DR_hyd_dem_pressure_4      = deferred_dataref("laminar/B747/hydraulics/dem_pressure_4", "number")

B747DR_hyd_edp_pressure_1      = deferred_dataref("laminar/B747/hydraulics/edp_pressure_1", "number")
B747DR_hyd_edp_pressure_2      = deferred_dataref("laminar/B747/hydraulics/edp_pressure_2", "number")
B747DR_hyd_edp_pressure_3      = deferred_dataref("laminar/B747/hydraulics/edp_pressure_3", "number")
B747DR_hyd_edp_pressure_4      = deferred_dataref("laminar/B747/hydraulics/edp_pressure_4", "number")
B747DR_hyd_aux_pressure      = deferred_dataref("laminar/B747/hydraulics/aux_pressure", "number")

B747DR_hyd_dem_mode_1      = deferred_dataref("laminar/B747/hydraulics/dem_mode_1", "number")--off auto on
B747DR_hyd_dem_mode_2      = deferred_dataref("laminar/B747/hydraulics/dem_mode_2", "number")
B747DR_hyd_dem_mode_3      = deferred_dataref("laminar/B747/hydraulics/dem_mode_3", "number")
B747DR_hyd_dem_mode_4      = deferred_dataref("laminar/B747/hydraulics/dem_mode_4", "number")-- -1 aux off auto on
-- CRT Displays/EICAS Lower/HYD/valve_on
B747DR_hyd_valve_1      = deferred_dataref("laminar/B747/hydraulics/valve_1", "number")
B747DR_hyd_valve_2      = deferred_dataref("laminar/B747/hydraulics/valve_2", "number")
B747DR_hyd_valve_3      = deferred_dataref("laminar/B747/hydraulics/valve_3", "number")
B747DR_hyd_valve_4      = deferred_dataref("laminar/B747/hydraulics/valve_4", "number")
simDR_hyd_press_1_2               = deferred_dataref("laminar/B747/hydraulics/indicators/hydraulic_pressure_1_2_4", "number")
simDR_parking_brake_ratio       = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
--************ FLIGHT SURFACES **********

B747DR_rudder_lwr_pos   = deferred_dataref("laminar/B747/flt_ctrls/rudder_lwr_pos", "number")
B747DR_rudder_upr_pos   = deferred_dataref("laminar/B747/flt_ctrls/rudder_upr_pos", "number")
B747DR_rudder_ratio   = deferred_dataref("laminar/B747/flt_ctrls/rudder_ratio", "number")
-- the pilots' pedals alone: X-Plane's total_heading_ratio adds 0.3 of the
-- rudder trim in the air (the acf's trim authority; checked 2026-10-24)
simDR_yoke_heading_ratio    = find_dataref("sim/cockpit2/controls/yoke_heading_ratio")
simDR_rudder_trim_ratio     = find_dataref("sim/cockpit2/controls/rudder_trim")
B747DR_rudder_input         = find_dataref("laminar/B747/flt_ctrls/rudder_input")
-- the A/P's rudder (ROLLOUT, more than one channel: 6-3 step 4c)
B747DR_ap_rudder_cmd        = find_dataref("laminar/B747/autopilot/rudder_cmd")
-- the FCCs' autotrim to the SRMs (B747.19.xt.afds_control.lua, 4-1 step 2b)
B747DR_autotrim_cmd         = find_dataref("laminar/B747/flt_ctrls/stab_trim/autotrim_cmd")
B747DR_autotrim_frat        = find_dataref("laminar/B747/flt_ctrls/stab_trim/frat")

B747DR_elevator_ratio   = deferred_dataref("laminar/B747/flt_ctrls/elevator_ratio", "number")
B747_controls_lower_rudder           = deferred_dataref("laminar/B747/cablecontrols/lower_rudder", "number")
B747_controls_upper_rudder           = deferred_dataref("laminar/B747/cablecontrols/upper_rudder", "number")

B747_controls_left_outer_elevator           = deferred_dataref("laminar/B747/cablecontrols/left_outer_elevator", "number")
B747_controls_right_outer_elevator            = deferred_dataref("laminar/B747/cablecontrols/right_outer_elevator", "number")
B747_controls_left_inner_elevator           = deferred_dataref("laminar/B747/cablecontrols/left_inner_elevator", "number")
B747_controls_right_inner_elevator          = deferred_dataref("laminar/B747/cablecontrols/right_inner_elevator", "number")

simDR_rudder            = find_dataref("sim/flightmodel2/wing/rudder1_deg")
B747DR_yaw_damper_lwr   = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_lwr", "number")
B747DR_yaw_damper_upr   = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_upr", "number")
simDR_sideslip             = find_dataref("sim/cockpit2/gauges/indicators/sideslip_degrees")
simDR_elevator_trim             = find_dataref("sim/flightmodel2/controls/elevator_trim")
simDR_autopilot_airspeed_kts = find_dataref("sim/cockpit2/autopilot/airspeed_dial_kts")
simDR_ind_airspeed_kts_pilot = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
B747DR_airspeed_Vmax      = find_dataref("laminar/B747/airspeed/Vmax")
B747DR_airspeed_Vmc = find_dataref("laminar/B747/airspeed/Vmc")
simDR_autopilot_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_dial_ft")
simDR_pressureAlt1 = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_touchGround = find_dataref("sim/flightmodel/failures/onground_any")
simDR_autopilot_vs_fpm = find_dataref("sim/cockpit2/autopilot/vvi_dial_fpm")
B747DR_l_elev_inner   = deferred_dataref("laminar/B747/flt_ctrls/l_elev_inner", "number")
B747DR_r_elev_inner   = deferred_dataref("laminar/B747/flt_ctrls/r_elev_inner", "number")
B747DR_l_elev_outer   = deferred_dataref("laminar/B747/flt_ctrls/l_elev_outer", "number")
B747DR_r_elev_outer   = deferred_dataref("laminar/B747/flt_ctrls/r_elev_outer", "number")

simDR_yoke_pitch_ratio           = find_dataref("sim/cockpit2/controls/yoke_pitch_ratio")
simDR_yoke_roll_ratio            = find_dataref("sim/cockpit2/controls/yoke_roll_ratio")
B747DR_sim_pitch_ratio   = find_dataref("laminar/B747/flt_ctrls/sim_pitch_ratio")
B747DR_sim_roll_ratio   = find_dataref("laminar/B747/flt_ctrls/sim_roll_ratio")
--B747DR_yaw_damp_ratio   = deferred_dataref("laminar/B747/flt_ctrls/sim_yaw_damp_ratio", "number")
B747DR_yaw_damper_upr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_upr_on", "number")
B747DR_yaw_damper_lwr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_lwr_on", "number")
B747DR_ap_target_roll = find_dataref("sim/cockpit2/autopilot/flight_director_roll_deg")
B747DR_fo_ap_roll = find_dataref("laminar/B747/autopilot/fo_roll_ref")
B747DR_custom_pitch_ratio   = find_dataref("laminar/B747/flt_ctrls/custom_pitch_ratio")
B747DR_custom_roll_ratio   = deferred_dataref("laminar/B747/flt_ctrls/custom_roll_ratio", "number")
B747DR_ap_autoland            	= deferred_dataref("laminar/B747/autopilot/autoland", "number")
B744DR_autolandPitch            = deferred_dataref("laminar/B747/autopilot/autolandPitch", "number")
B747DR_ap_inVNAVdescent = deferred_dataref("laminar/B747/autopilot/vnav_descent", "number")
simDR_electric_trim   = find_dataref("sim/cockpit2/autopilot/electric_trim_on")
simDR_pitch_mistrim   = find_dataref("sim/cockpit2/autopilot/pitch_mistrim")
simDR_AHARS_roll_heading_deg_pilot          	= find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot")
simDR_AHARS_pitch_heading_deg_pilot           = find_dataref("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot")
simDR_flight_director_pitch = find_dataref("sim/cockpit2/autopilot/flight_director_pitch_deg")
B747DR_flight_director_pitch           = deferred_dataref("laminar/B747/autopilot/flight_director_pitch_deg", "number")
B747DR_flight_director_roll 		= deferred_dataref("laminar/B747/autopilot/flight_director_roll_deg", "number")
simDR_autopilot_servos_on           	= find_dataref("laminar/B747/autopilot/servos_on")
B747DR_ap_FMA_active_pitch_mode     	= find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
B747DR_ap_FMA_active_roll_mode      	= find_dataref("laminar/B747/autopilot/FMA/active_roll_mode")
-- the FMC's LNAV steering (6-1/6-2 step 6c)
B747DR_fms_lnav_valid               	= find_dataref("laminar/B747/fms/lnav/valid")
B747DR_fms_lnav_roll                	= find_dataref("laminar/B747/fms/lnav/roll")
simDR_vvi_fpm_pilot                 = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_autopilot_alt_hold_status     	= find_dataref("laminar/B747/autopilot/altitude_hold_status")
--simCMD_autopilot_alt_hold_mode      = find_command("sim/autopilot/altitude_hold")
-- the control wheel angle, degrees, right wing down positive (the
-- controlObject's), for the ailerons and spoilers: B747.19.lateral_model.lua
B747_controls_wheel                  = deferred_dataref("laminar/B747/cablecontrols/wheel", "number")
-- FLT CONTROL HYD POWER (the init script's; B747.19.xt.hydraulics_override.lua)
B747DR_fcsov_wing_shut          = deferred_dataref("laminar/B747/flt_ctrls/hyd_power/wing_shut", "array[4]")
B747DR_fcsov_tail_shut          = deferred_dataref("laminar/B747/flt_ctrls/hyd_power/tail_shut", "array[4]")
B747DR_fcsov_wing_valve         = deferred_dataref("laminar/B747/flt_ctrls/hyd_power/wing_valve_shut", "array[4]")
B747DR_fcsov_tail_valve         = deferred_dataref("laminar/B747/flt_ctrls/hyd_power/tail_valve_shut", "array[4]")


simDR_left_aileron_inner = find_dataref("sim/flightmodel/controls/wing2l_ail1def")
simDR_right_aileron_inner = find_dataref("sim/flightmodel/controls/wing2r_ail1def")
simDR_left_aileron_outer = find_dataref("sim/flightmodel/controls/wing4l_ail2def")
simDR_right_aileron_outer = find_dataref("sim/flightmodel/controls/wing4r_ail2def")
B747DR_l_aileron_inner   = deferred_dataref("laminar/B747/flt_ctrls/l_aileron_inner", "number")
B747DR_r_aileron_inner   = deferred_dataref("laminar/B747/flt_ctrls/r_aileron_inner", "number")
B747DR_l_aileron_outer   = deferred_dataref("laminar/B747/flt_ctrls/l_aileron_outer", "number")
B747DR_r_aileron_outer   = deferred_dataref("laminar/B747/flt_ctrls/r_aileron_outer", "number")

B747DR_l_aileron_outer_lockout   = deferred_dataref("laminar/B747/flt_ctrls/left_outer_aileron_lockout", "number")
B747DR_r_aileron_outer_lockout   = deferred_dataref("laminar/B747/flt_ctrls/right_outer_aileron_lockout", "number")

B747DR_spoilers      = deferred_dataref("laminar/B747/flt_ctrls/spoilers", "array[13]") --0 unused
B747DR_outer_spoilers      = deferred_dataref("laminar/B747/flt_ctrls/outer_spoilers", "array[2]") --for stat display
B747DR_flaps      = deferred_dataref("laminar/B747/flt_ctrls/flaps", "array[5]") --0 unuse

-- X-Plane's spoilers, from the inboard end (the acf's wing elements): wing 1
-- speedbrake 1 = spoilers 6 and 7, wing 1 spoiler 1 = 5 and 8, wing 2
-- spoiler 1 = 4 and 9, wing 3 spoiler 2 = 3 and 10, wing 3 spoiler 1 = 1, 2
-- and 11, 12 (before, nothing moved wing 2's nor speedbrake 1: 4-1 step 4)
simDR_spoiler12  = find_dataref("sim/flightmodel/controls/wing3l_spo1def")
simDR_spoiler3  = find_dataref("sim/flightmodel/controls/wing3l_spo2def")
simDR_spoiler4  = find_dataref("sim/flightmodel/controls/wing2l_spo1def")
simDR_spoiler5  = find_dataref("sim/flightmodel/controls/wing1l_spo1def")
simDR_spoiler67  = find_dataref("sim/flightmodel2/wing/speedbrake1_deg") -- array [0] left, [1] right
simDR_spoiler8  = find_dataref("sim/flightmodel/controls/wing1r_spo1def")
simDR_spoiler9  = find_dataref("sim/flightmodel/controls/wing2r_spo1def")
simDR_spoiler10  = find_dataref("sim/flightmodel/controls/wing3r_spo2def")
simDR_spoiler1112  = find_dataref("sim/flightmodel/controls/wing3r_spo1def")

-- the flaps from the flap control units (B747.45.xt.fcu.lua, 4-1): the
-- trailing edge panels L OB, L IB, R IB, R OB in degrees, the leading edge
-- groups A and B as slat ratios, the TE moving and out
B747DR_fcu_te_deg   = find_dataref("laminar/B747/flt_ctrls/fcu/te_deg")
B747DR_fcu_slat     = find_dataref("laminar/B747/flt_ctrls/fcu/slat")
B747DR_fcu_te_moving = find_dataref("laminar/B747/flt_ctrls/fcu/te_moving")
B747DR_fcu_te_down  = find_dataref("laminar/B747/flt_ctrls/fcu/te_down")
simDR_flap_ratio			= find_dataref("sim/cockpit2/controls/flap_ratio")
simDR_innerslats_ratio  	= find_dataref("sim/flightmodel2/controls/slat1_deploy_ratio")
simDR_outerslats_ratio  	= find_dataref("sim/flightmodel2/controls/slat2_deploy_ratio")

-- the acf's flaps: set 1 (inboard) on wing 1, set 2 (outboard) on wings 2 and 3
simDR_flap1  = find_dataref("sim/flightmodel/controls/wing3l_fla2def")
simDR_flap2  = find_dataref("sim/flightmodel/controls/wing1l_fla1def")
simDR_flap3  = find_dataref("sim/flightmodel/controls/wing1r_fla1def")
simDR_flap4  = find_dataref("sim/flightmodel/controls/wing3r_fla2def")
simDR_flap1_wing2 = find_dataref("sim/flightmodel/controls/wing2l_fla2def")
simDR_flap4_wing2 = find_dataref("sim/flightmodel/controls/wing2r_fla2def")

simDR_version=find_dataref("sim/version/xplane_internal_version")
simDR_failhyd1  = find_dataref("sim/operation/failures/rel_hydleak")
simDR_failhyd2  = find_dataref("sim/operation/failures/rel_hydleak2")
simDR_failhyd3  = find_dataref("sim/operation/failures/rel_hydleak3")



simDR_override_control_surfaces       = find_dataref("sim/operation/override/override_control_surfaces")
--simDR_hyd_press_2               = find_dataref("sim/cockpit2/hydraulics/indicators/hydraulic_pressure_2")
B747DR_hyd_dmd_pmp_sel_pos      = deferred_dataref("laminar/B747/hydraulics/dmd_pump/sel_dial_pos", "array[4]")

function B747_animate_value(current_value, target, min, max, speed)

    

    if target >= (max - 0.001) then
        return max
    elseif target <= (min + 0.001) then
       return min
    else
      local fps_factor = math.min(0.1, speed * SIM_PERIOD)
        return current_value + ((target - current_value) * fps_factor)
    end

end

function B747_interpolate_value(current_value, target, min, max, speed)--speed in sex min->max

  --[[if math.abs(current_value-target) <0.01 then
    return target
  end]]

  local change = ((max-min)/speed)*(SIM_PERIOD)
  newValue=current_value
  
  if newValue<=target then
    newValue=newValue+change
    --print(current_value.." ->newValue<= "..newValue)
    if newValue >= target then
      newValue = B747_animate_value(current_value,target,-100,100,100)
    end
  elseif newValue>target then
    newValue=newValue-change
    --print(current_value.." ->newValue>= "..newValue)
    if newValue <= target then
      newValue = B747_animate_value(current_value,target,-100,100,100)
    end
  end
  if newValue <= min then
    newValue = B747_animate_value(current_value,min,-100,100,100)
  elseif newValue >= max then
    newValue = B747_animate_value(current_value,max,-100,100,100)
  else
    --print(current_value.." ->newValue== "..newValue)
    --newValue = newValue
    if math.abs(current_value-target) < change then
      newValue = B747_animate_value(current_value,target,-100,100,100)
    --  print(current_value.." ->newValue== "..newValue)
    --else
    --  print(current_value.." ->newValue=== "..newValue)
    end

    
  end
  return newValue
end
----- RESCALE ---------------------------------------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

  if x < in1 then return out1 end
  if x > in2 then return out2 end
  return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end
dofile("pid.lua")
dofile("B747.19.lateral_model.lua")
dofile("B747.19.xt.hydraulics_override.lua")
-- the flight control shutoff switches (commands; the 3D has none)
for n = 1, 4 do
    deferred_command("laminar/B747/flt_ctrls/hyd_power/wing_" .. n, "Flight Control Hyd Power Wing " .. n, B747_fcsov_toggle("wing", n))
    deferred_command("laminar/B747/flt_ctrls/hyd_power/tail_" .. n, "Flight Control Hyd Power Tail " .. n, B747_fcsov_toggle("tail", n))
end
dofile("B747.19.xt.slats.lua")
dofile("B747.19.xt.afds_control.lua")
dofile("B747.19.xt.yaw_damper.lua")
dofile("B747.19.xt.hyd_power.lua")
local lastpressureUpdate=0
function B747_show_system_pressures()
  local diff = simDRTime - lastpressureUpdate
	if diff < 0.5 then
		return
	end
  B747DR_hyd_sys_pressure_dsp_1=math.floor(B747DR_hyd_sys_pressure_1/10)*10
  B747DR_hyd_sys_pressure_dsp_2=math.floor(B747DR_hyd_sys_pressure_2/10)*10
  B747DR_hyd_sys_pressure_dsp_3=math.floor(B747DR_hyd_sys_pressure_3/10)*10
  B747DR_hyd_sys_pressure_dsp_4=math.floor(B747DR_hyd_sys_pressure_4/10)*10

  lastpressureUpdate=simDRTime
end
--*************************************************************************************--
--**                          EVENT CALLBACKS                        **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end
local initialiseControls=true
function flight_start() 
  --initial pids
  --lockedout
  --p 0.1
  --i 0.003
  --d 0.04

  -- the A/P's inner roll loop (6-3 step 4d, afds_control: the aileron trim
  -- integrator, ATA22 p.348-349): the same at all speeds; the roll and yaw
  -- rates' gains there (estimates). Before 0.05 and 0.0003 with the error's
  -- derivative (DL, DH by altitude: no longer used)
  B747DR_pidRollP = 0.05
  B747DR_pidRollI = 0.02
  B747DR_pidRollDL = 0.05 --low 0.1 high 0.4
  B747DR_pidRollDH = 0.1 --low 0.1 high 0.4

  -- the A/P's attitude loop: one gain at all altitudes, with the attitude
  -- rate in afds_control (6-3, after step 3b: notes/ATA-22.md §21). The MCP
  -- altitude's schedule, 0.07 at 3,000 ft down to 0.04 at 40,000, left the
  -- A/P 0.45 degree behind a 0.11 degree a second command at FL350 and ALT
  -- HOLD swinging 250 fpm; 0.1 holds within 12 fpm (estimate)
  B747DR_pidPitchPL = 0.1
  B747DR_pidPitchPH = 0.1
  B747DR_pidPitchI = 0.07 --0.07
  B747DR_pidPitchD = 0.0002

    --rudder
    B747DR_rudder_ratio=1.0
    B747DR_elevator_ratio   = 1.0
    if initialiseControls then

      --YAW DAMPER: each module's 4 degrees on its rudder, added after the
      --ratio changers (the damper's actuator drives the summing bar of the
      --rudder's power control module: ATA27 p.656; 6-3 step 6b. Before,
      --3.5 degrees scaled by each rudder's ratio changer)
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-4,"maxout":4,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/yaw_damper_lwr","dstDref":"laminar/B747/cablecontrols/lower_rudder"}';
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-4,"maxout":4,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/yaw_damper_upr","dstDref":"laminar/B747/cablecontrols/upper_rudder"}';

      --PEDALS AND RUDDER TRIM together (the trim moves the pedals' neutral,
      --up to 80 % of the full travel: hydraulics_override.lua), through the
      --ratio changers, so 32 degrees at low speed and 5 at 450 kt for both
      --together (ATA27 p.596, p.612-614, p.634; before, each was scaled on
      --its own and their sum not limited). The outputs to one dstDref add
      --up, each clamped to its own range
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-32,"maxout":32,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/rudder_input","dstDref":"laminar/B747/cablecontrols/lower_rudder","scaledref":"laminar/B747/flt_ctrls/rudder_ratio_lwr"}';
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-32,"maxout":32,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/rudder_input","dstDref":"laminar/B747/cablecontrols/upper_rudder","scaledref":"laminar/B747/flt_ctrls/rudder_ratio_upr"}';

      B747DR_controlOverrides = '{"minin":-32,"maxin":32,"minout":-32,"maxout":32,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/rudder_lwr_pos","dstDref":"sim/flightmodel/controls/vstab2_rud1def"}';
      B747DR_controlOverrides = '{"minin":-32,"maxin":32,"minout":-32,"maxout":32,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/rudder_upr_pos","dstDref":"sim/flightmodel/controls/vstab2_rud2def"}';
    
      --elevators

      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-1,"maxout":1,"scale":1.0,"srcDref":"sim/cockpit2/controls/yoke_pitch_ratio","dstDref":"laminar/B747/flt_ctrls/custom_pitch_ratio"}';
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-1,"maxout":1,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/sim_pitch_ratio","dstDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","scaledref":"laminar/B747/flt_ctrls/elevator_ratio"}';

      B747DR_controlOverrides = '{"minin":-1,"maxin":0,"minout":-17,"maxout":0,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/left_outer_elevator"}';
      B747DR_controlOverrides = '{"minin":0,"maxin":1,"minout":0,"maxout":22,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/left_outer_elevator"}';

      B747DR_controlOverrides = '{"minin":-1,"maxin":0,"minout":-17,"maxout":0,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/right_outer_elevator"}';
      B747DR_controlOverrides = '{"minin":0,"maxin":1,"minout":0,"maxout":22,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/right_outer_elevator"}';

      B747DR_controlOverrides = '{"minin":-1,"maxin":0,"minout":-17,"maxout":0,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/left_inner_elevator"}';
      B747DR_controlOverrides = '{"minin":0,"maxin":1,"minout":0,"maxout":22,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/left_inner_elevator"}';

      B747DR_controlOverrides = '{"minin":-1,"maxin":0,"minout":-17,"maxout":0,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/right_inner_elevator"}';
      B747DR_controlOverrides = '{"minin":0,"maxin":1,"minout":0,"maxout":22,"scale":-1.0,"srcDref":"laminar/B747/flt_ctrls/custom_pitch_ratio","dstDref":"laminar/B747/cablecontrols/right_inner_elevator"}';

      B747DR_controlOverrides = '{"minin":-22,"maxin":17,"minout":-22,"maxout":17,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/l_elev_outer","dstDref":"sim/flightmodel/controls/hstab1_elv1def"}'; --left_outer_elevator
      B747DR_controlOverrides = '{"minin":-22,"maxin":17,"minout":-22,"maxout":17,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/r_elev_outer","dstDref":"sim/flightmodel/controls/hstab2_elv1def"}'; --right_outer_elevator
      B747DR_controlOverrides = '{"minin":-22,"maxin":17,"minout":-22,"maxout":17,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/l_elev_inner","dstDref":"sim/flightmodel/controls/hstab1_elv2def"}'; --left_inner_elevator
      B747DR_controlOverrides = '{"minin":-22,"maxin":17,"minout":-22,"maxout":17,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/r_elev_inner","dstDref":"sim/flightmodel/controls/hstab2_elv2def"}'; --right_inner_elevator
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-15,"maxout":15,"scale":-1.0,"srcDref":"sim/flightmodel2/controls/elevator_trim","dstDref":"sim/flightmodel2/controls/stabilizer_deflection_degrees"}'; --trim
      
      
      --ailerons: the control wheel's angle (the pilots', the A/P's and the
      --aileron trim, whose 6 units move the wheel's neutral 47 degrees of the
      --90 to the stop: ATA27 p.59, p.76; before, full trim was a full wheel)
      --for the hydraulics module, whose aileron programmers and spoiler mixers
      --(B747.19.lateral_model.lua, 4-1 step 4) make the surfaces' commands
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-1,"maxout":1,"scale":1.0,"srcDref":"sim/cockpit2/controls/yoke_roll_ratio","dstDref":"laminar/B747/flt_ctrls/custom_roll_ratio"}';
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-1,"maxout":1,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/sim_roll_ratio","dstDref":"laminar/B747/flt_ctrls/custom_roll_ratio"}';
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-1,"maxout":1,"scale":0.5222,"srcDref":"sim/cockpit2/controls/aileron_trim","dstDref":"laminar/B747/flt_ctrls/custom_roll_ratio"}';
      
      B747DR_controlOverrides = '{"minin":-1,"maxin":1,"minout":-90,"maxout":90,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/custom_roll_ratio","dstDref":"laminar/B747/cablecontrols/wheel"}';

      B747DR_controlOverrides = '{"minin":-20,"maxin":20,"minout":-20,"maxout":20,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/l_aileron_inner","dstDref":"sim/flightmodel/controls/wing2l_ail1def"}';
      B747DR_controlOverrides = '{"minin":-20,"maxin":20,"minout":-20,"maxout":20,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/r_aileron_inner","dstDref":"sim/flightmodel/controls/wing2r_ail1def"}';
      B747DR_controlOverrides = '{"minin":-25,"maxin":15,"minout":-25,"maxout":15,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/l_aileron_outer","dstDref":"sim/flightmodel/controls/wing4l_ail2def"}';
      B747DR_controlOverrides = '{"minin":-25,"maxin":15,"minout":-25,"maxout":15,"scale":1.0,"srcDref":"laminar/B747/flt_ctrls/r_aileron_outer","dstDref":"sim/flightmodel/controls/wing4r_ail2def"}';  

      --flaps and their indication: the flap control units (B747.45.xt.fcu.lua)

      --spoilers and speedbrakes: the hydraulics module from the wheel and the
      --speedbrake lever (the speedbrake program, ATA27 p.165)
      initialiseControls=false
    else 
      print("not reinitialising controls!!!")
    end
    B747_hyd_power_flight_start()
    B747_fcsov_flight_start()
end

--function flight_crash() end

--function before_physics() end
debug_hydro     = deferred_dataref("laminar/B747/debug/hydro", "number")

local lastStat=0
local countFrame=0
function roundToIncrement(number, increment)

  local y = number / increment
  local q = math.floor(y + 0.5)
  local z = q * increment

  return z

end
function after_physics()
  if debug_hydro>0 then return end
  

   B747_hyd_power()
   --consumers
   pressure_input()
   flight_controls_consumption()
   pressure_output()
   B747_show_system_pressures()
   flight_controls_override()
   if debug_hydro<0 then
    local diff=simDRTime-lastStat
    countFrame=countFrame+1
    if diff>=1 then
      print("Hydro fps="..countFrame)
      lastStat=simDRTime
      countFrame=0
    end
  end
end

--function after_replay() end
