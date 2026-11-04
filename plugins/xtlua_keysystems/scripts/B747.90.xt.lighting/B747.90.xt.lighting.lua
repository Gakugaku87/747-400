--[[
*****************************************************************************************
* Program Script Name	:	B747.90.lighting
* Author Name			:	Jim Gregory
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2016-04-26	0.01a				Start of Dev
*
*
*
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	        *
*****************************************************************************************
--]]


--*************************************************************************************--
--** 					              XLUA GLOBALS              				     **--
--*************************************************************************************--

--[[

SIM_PERIOD - this contains the duration of the current frame in seconds (so it is alway a
fraction).  Use this to normalize rates,  e.g. to add 3 units of fuel per second in a
per-frame callback you’d do fuel = fuel + 3 * SIM_PERIOD.

--]]


--*************************************************************************************--
--** 					               CONSTANTS                    				 **--
--*************************************************************************************--
function deferred_command(name,desc,realFunc)
	return replace_command(name,realFunc)
end
--replace deferred_dataref
function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end
NUM_SPILL_LIGHT_INDICES = 9
NUM_LANDING_LIGHTS      = 4
NUM_ANNUN_LIGHTS        = 270


--*************************************************************************************--
--** 					            GLOBAL VARIABLES                				 **--
--*************************************************************************************--





--*************************************************************************************--
--** 					            LOCAL VARIABLES                 				 **--
--*************************************************************************************--
local annun = {}
annun.a = {}
annun.b = {}



--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--
simDR_version=find_dataref("sim/version/xplane_internal_version")
simDR_shadow			    = find_dataref("sim/private/controls/shadow/total_fade_ratio")
simDR_headX=find_dataref("sim/graphics/view/pilots_head_x")
simDR_headY=find_dataref("sim/graphics/view/pilots_head_y")
simDR_headZ=find_dataref("sim/graphics/view/pilots_head_z")
simDR_headpsi=find_dataref("sim/graphics/view/pilots_head_psi")
simDR_headpitch=find_dataref("sim/graphics/view/pilots_head_the")
simDR_photoBias			    = find_dataref("sim/private/controls/photometric/ev100_bias")
simDR_capt_visor_lr			    = find_dataref("laminar/B747/misc/sun_visor/left_right/capt") --left/right
simDR_capt_visor_ud			    = find_dataref("laminar/B747/toggle_switch/position[31]") --up/down
simDR_fo_visor_lr			    = find_dataref("laminar/B747/misc/sun_visor/left_right/fo") --left/right
simDR_fo_visor_ud			    = find_dataref("laminar/B747/toggle_switch/position[32]") --up/down
simDR_contrast			    = find_dataref("sim/private/controls/tonemap/contrast")
simDR_light_storage			    = find_dataref("sim/private/controls/photometric/light_storage_scale")
simDR_tone_mode			    = find_dataref("sim/private/controls/tonemap/mode")
simDR_exposure_fusion			    = find_dataref("sim/private/controls/tonemap/exposure_fusion")
simDR_ev100			    = find_dataref("sim/private/controls/photometric/ev100")
simDR_sun_pitch			    = find_dataref("sim/graphics/scenery/sun_pitch_degrees")
simDR_view_pitch			    = find_dataref("sim/graphics/view/view_pitch")
simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")
simDR_percent_lights_on             = find_dataref("sim/graphics/scenery/percent_lights_on")
simDR_ai_flies_aircraft				= find_dataref("sim/operation/prefs/ai_flies_aircraft")



simDR_sim_brightness_ratio      = find_dataref("sim/cockpit2/electrical/HUD_brightness_ratio")
simDR_generic_brightness_switch     = find_dataref("sim/cockpit2/switches/generic_lights_switch")
simDR_generic_brightness_ratio      = find_dataref("sim/flightmodel2/lights/generic_lights_brightness_ratio")
simDR_panel_brightness_switch       = find_dataref("sim/cockpit2/switches/panel_brightness_ratio")
simDR_panel_brightness_ratio        = find_dataref("sim/cockpit2/electrical/panel_brightness_ratio_manual")
simDR_instrument_brightness_switch  = find_dataref("sim/cockpit2/switches/instrument_brightness_ratio")
--simDR_instrument_brightness_ratio   = find_dataref("sim/cockpit2/electrical/instrument_brightness_ratio_manual")

B747DR_instrument_brightness_ratio  = find_dataref("laminar/B747/switches/instrument_brightness_ratio")
simDR_landing_light_switch          = find_dataref("sim/cockpit2/switches/landing_lights_switch")
simDR_taxi_light_switch_on          = find_dataref("sim/cockpit2/switches/taxi_light_on")
simDR_beacon_lights_switch          = find_dataref("sim/cockpit/electrical/beacon_lights_on")
simDR_nav_lights_switch             = find_dataref("sim/cockpit2/switches/navigation_lights_on")
simDR_strobe_lights_switch          = find_dataref("sim/cockpit2/switches/strobe_lights_on")

simDR_apu_running                   = find_dataref("sim/cockpit2/electrical/APU_running")
simDR_apu_N1_pct                    = find_dataref("sim/cockpit2/electrical/APU_N1_percent")

simDR_aircraft_groundspeed          = find_dataref("sim/flightmodel/position/groundspeed")

simDR_hyd_press_01                  = find_dataref("laminar/B747/hydraulics/pressure_1")
simDR_hyd_press_02                  = find_dataref("laminar/B747/hydraulics/pressure_2")
simDR_hyd_press_03                  = find_dataref("laminar/B747/hydraulics/pressure_3")
simDR_hyd_press_04                  = find_dataref("laminar/B747/hydraulics/pressure_4")
simDR_hyd_fluid_level_01            = find_dataref("laminar/B747/hydraulics/res_1")
simDR_hyd_fluid_level_02            = find_dataref("laminar/B747/hydraulics/res_2")
simDR_hyd_fluid_level_03            = find_dataref("laminar/B747/hydraulics/res_3")
simDR_hyd_fluid_level_04            = find_dataref("laminar/B747/hydraulics/res_4")

--simDR_annun_master_caution          = find_dataref("sim/cockpit2/annunciators/master_caution")
--simDR_annun_master_warning          = find_dataref("sim/cockpit2/annunciators/master_warning")
simDR_annun_generator_off           = find_dataref("sim/cockpit2/annunciators/generator_off")
simDR_yaw_damper_annun              = find_dataref("sim/cockpit2/annunciators/yaw_damper")
B747DR_yaw_damper_upr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_upr_on", "number")
B747DR_yaw_damper_lwr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_lwr_on", "number")
-- the flight control shutoff valves' travel toward shut (the hydraulics module)
B747DR_lt_fcsov_wing_valve      = find_dataref("laminar/B747/flt_ctrls/hyd_power/wing_valve_shut")
B747DR_lt_fcsov_tail_valve      = find_dataref("laminar/B747/flt_ctrls/hyd_power/tail_valve_shut")
--simDR_bleed_air_off                 = find_dataref("sim/cockpit2/annunciators/bleed_air_off")
--simDR_bleed_air_mode                = find_dataref("sim/cockpit2/pressurization/actuators/bleed_air_mode")
simDR_annun_GPWS                    = find_dataref("sim/cockpit2/annunciators/GPWS")
-- the GND PROX light (the GPWS, B747.34.xt.gpws.lua)
B747DR_lt_gpws_gnd_prox             = find_dataref("laminar/B747/gpws/gnd_prox_light")

simDR_generator_fail_01             = find_dataref("sim/operation/failures/rel_genera0")
simDR_generator_fail_02             = find_dataref("sim/operation/failures/rel_genera1")
simDR_generator_fail_03             = find_dataref("sim/operation/failures/rel_genera2")
simDR_generator_fail_04             = find_dataref("sim/operation/failures/rel_genera3")
-- the hydraulic model's P5 lights (B747.19.xt.hyd_power.lua)
B747DR_light_hyd_eng_press          = find_dataref("laminar/B747/hydraulics/light/eng_press")
B747DR_light_hyd_dem_press          = find_dataref("laminar/B747/hydraulics/light/dem_press")
B747DR_light_hyd_sys_fault          = find_dataref("laminar/B747/hydraulics/light/sys_fault")
B747DR_light_hyd_brake_source       = find_dataref("laminar/B747/hydraulics/light/brake_source")
--simDR_nacelle_inlet_antiice_fail_01 = find_dataref("sim/operation/failures/rel_ice_inlet_heat")
--simDR_nacelle_inlet_antiice_fail_02 = find_dataref("sim/operation/failures/rel_ice_inlet_heat2")
--simDR_nacelle_inlet_antiice_fail_03 = find_dataref("sim/operation/failures/rel_ice_inlet_heat3")
--simDR_nacelle_inlet_antiice_fail_04 = find_dataref("sim/operation/failures/rel_ice_inlet_heat4")
--simDR_wing_anti_ice_fail_01         = find_dataref("sim/operation/failures/rel_ice_surf_heat")
--simDR_wing_anti_ice_fail_02         = find_dataref("sim/operation/failures/rel_ice_surf_heat2")
--simDR_bleed_air_fail_L              = find_dataref("sim/operation/failures/rel_bleed_air_lft")
--simDR_bleed_air_fail_R              = find_dataref("sim/operation/failures/rel_bleed_air_rgt")

--simDR_window_ice                    = find_dataref("sim/flightmodel/failures/window_ice")
simDR_OAT=find_dataref("sim/weather/temperature_ambient_c")

-- the bleed air model's P5 lights (B747.55.xt.bleed.lua)
B747DR_light_bleed_sys_fault        = find_dataref("laminar/B747/air/light/sys_fault")
B747DR_light_bleed_isln_valve       = find_dataref("laminar/B747/air/light/isln_valve")
B747DR_light_bleed_apu_valve        = find_dataref("laminar/B747/air/light/apu_valve")
-- the pack model's PACK RST SYS FAULT light (B747.55.xt.packs.lua)
B747DR_light_pack_sys_fault         = find_dataref("laminar/B747/air/light/pack_sys_fault")
B747DR_light_zone_sys_fault         = find_dataref("laminar/B747/air/light/zone_sys_fault")
B747DR_light_aft_cargo_temp         = find_dataref("laminar/B747/air/light/aft_cargo_temp")
B747DR_antiice_light_nai_valve      = find_dataref("laminar/B747/antiice/light/nai_valve")
B747DR_antiice_light_wai_valve      = find_dataref("laminar/B747/antiice/light/wai_valve")
B747DR_antiice_light_window_inop    = find_dataref("laminar/B747/antiice/light/window_inop")
-- the passenger oxygen actuated (B747.36.xt.oxygen.lua)
B747DR_oxy_pass_on                  = find_dataref("laminar/B747/oxygen/pass_oxy_on")

simDR_gear_deploy_ratio             = find_dataref("sim/flightmodel2/gear/deploy_ratio")
simDR_aircraft_altitude             = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_cabin_altitude                = find_dataref("sim/cockpit2/pressurization/indicators/cabin_altitude_ft")

simDR_autopilot_servos_on           	= find_dataref("laminar/B747/autopilot/servos_on")
B747DR_autothrottle_active	= find_dataref("laminar/B747/engines/autothrottle_active")

simDR_autopilot_fms_vnav_status			= find_dataref("sim/cockpit2/autopilot/fms_vnav")
B747DR_ap_FMA_active_pitch_mode     	= find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
simDR_autopilot_flch_status         	= find_dataref("laminar/B747/autopilot/speed_status")
simDR_autopilot_heading_hold_status     = find_dataref("sim/cockpit2/autopilot/heading_hold_status")
B747DR_ap_FMA_active_roll_mode          = find_dataref("laminar/B747/autopilot/FMA/active_roll_mode")
simDR_autopilot_vs_status           	= find_dataref("laminar/B747/autopilot/vvi_status")
simDR_autopilot_alt_hold_status         = find_dataref("laminar/B747/autopilot/altitude_hold_status")
B747DR_ap_approach_mode     	= find_dataref("laminar/B747/autopilot/approach_mode")
--simDR_autopilot_nav_status          = find_dataref("sim/cockpit2/autopilot/nav_status")
--simDR_autopilot_gs_status           = find_dataref("sim/cockpit2/autopilot/glideslope_status")
simDR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/actual_nav_status")
simDR_autopilot_gs_status = find_dataref("laminar/B747/autopilot/actual_glideslope_status")

simDR_autopilot_app_status          = find_dataref("sim/cockpit2/autopilot/approach_status")
B747DR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/nav_status")
B747DR_autopilot_gs_status = find_dataref("laminar/B747/autopilot/glideslope_status")
simDR_esys0              = find_dataref("sim/operation/failures/rel_esys")
simDR_esys1              = find_dataref("sim/operation/failures/rel_esys2")
simDR_esys2              = find_dataref("sim/operation/failures/rel_esys3")
simDR_esys3              = find_dataref("sim/operation/failures/rel_esys4")


simDR_cockpit2_no_smoking_switch    = find_dataref("sim/cockpit2/switches/no_smoking")
simDR_cockpit2_seat_belt_switch     = find_dataref("sim/cockpit2/switches/fasten_seat_belts")


simDR_autoboard_in_progress         = find_dataref("sim/flightmodel2/misc/auto_board_in_progress")
simDR_autostart_in_progress         = find_dataref("sim/flightmodel2/misc/auto_start_in_progress")

simDR_flap_ratio_control        	= find_dataref("sim/cockpit2/controls/flap_ratio")





--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--
B747DR_ap_lnav_state                = find_dataref("laminar/B747/autopilot/lnav_state")
B747DR_ap_vnav_state                = find_dataref("laminar/B747/autopilot/vnav_state")
B747DR_button_switch_position       = find_dataref("laminar/B747/button_switch/position")
B747DR_toggle_switch_position       = find_dataref("laminar/B747/toggle_switch/position")
B747DR_engine_TOGA_mode             = find_dataref("laminar/B747/engines/TOGA_mode")
B747DR_elec_ext_pwr1_available      = find_dataref("laminar/B747/electrical/ext_pwr1_avail")
B747DR_elec_ext_pwr2_available      = find_dataref("laminar/B747/electrical/ext_pwr2_avail")
B747DR_elec_apu_pwr1_available      = find_dataref("laminar/B747/electrical/apu_pwr1_avail")
B747DR_elec_apu_pwr2_available      = find_dataref("laminar/B747/electrical/apu_pwr2_avail")
B747DR_elec_ext_pwr1_on      	    = find_dataref("laminar/B747/electrical/ext_pwr1_on")
B747DR_elec_ext_pwr2_on      	    = find_dataref("laminar/B747/electrical/ext_pwr2_on")
B747DR_elec_apu_pwr1_on      	    = find_dataref("laminar/B747/electrical/apu_pwr1_on")
B747DR_elec_apu_pwr2_on      	    = find_dataref("laminar/B747/electrical/apu_pwr2_on")
B747DR_elec_ext_pwr_1_switch_mode   = find_dataref("laminar/B747/elec_ext_pwr_1/switch_mode")
B747DR_elec_apu_pwr_1_switch_mode   = find_dataref("laminar/B747/apu_pwr_1/switch_mode")
B747DR_elec_ext_pwr_2_switch_mode   = find_dataref("laminar/B747/elec_ext_pwr_2/switch_mode")
B747DR_elec_apu_pwr_2_switch_mode   = find_dataref("laminar/B747/apu_pwr_2/switch_mode")
-- P5 electrical panel lights, from the electrical model (B747.03.xt.elec_buses.lua)
B747DR_elec_light_ext_avail         = find_dataref("laminar/B747/electrical/light/ext_avail")
B747DR_elec_light_apu_avail         = find_dataref("laminar/B747/electrical/light/apu_avail")
B747DR_elec_light_isln              = find_dataref("laminar/B747/electrical/light/isln")
B747DR_elec_light_gen_off           = find_dataref("laminar/B747/electrical/light/gen_off")
B747DR_elec_light_drive             = find_dataref("laminar/B747/electrical/light/drive")
B747DR_elec_light_util_off          = find_dataref("laminar/B747/electrical/light/util_off")
B747DR_gear_handle 					= find_dataref("laminar/B747/actuator/gear_handle")
--B747DR_gear_handle_position         = find_dataref("laminar/B747/gear_handle/position")
--B747DR_flap_lever                   = find_dataref("laminar/B747/flt_ctrls/flap_lever")
B747DR_hyd_dmd_pmp_sel_pos          = find_dataref("laminar/B747/hydraulics/dmd_pump/sel_dial_pos")

B747DR_rtp_L_offside_tuning_status  = find_dataref("laminar/B747/comm/rtp_L/offside_tuning_status")
B747DR_rtp_L_off_status             = find_dataref("laminar/B747/comm/rtp_L/off_status")
B747DR_rtp_L_vhf_L_status           = find_dataref("laminar/B747/comm/rtp_L/vhf_L_status")
B747DR_rtp_L_vhf_C_status           = find_dataref("laminar/B747/comm/rtp_L/vhf_C_status")
B747DR_rtp_L_vhf_R_status           = find_dataref("laminar/B747/comm/rtp_L/vhf_R_status")
B747DR_rtp_L_hf_L_status            = find_dataref("laminar/B747/comm/rtp_L/hf_L_status")
B747DR_rtp_L_am_status              = find_dataref("laminar/B747/comm/rtp_L/am_status")
B747DR_rtp_L_hf_R_status            = find_dataref("laminar/B747/comm/rtp_L/hf_R_status")
B747DR_rtp_R_offside_tuning_status  = find_dataref("laminar/B747/comm/rtp_R/offside_tuning_status")
B747DR_rtp_R_off_status             = find_dataref("laminar/B747/comm/rtp_R/off_status")
B747DR_rtp_R_vhf_L_status           = find_dataref("laminar/B747/comm/rtp_R/vhf_L_status")
B747DR_rtp_R_vhf_C_status           = find_dataref("laminar/B747/comm/rtp_R/vhf_C_status")
B747DR_rtp_R_vhf_R_status           = find_dataref("laminar/B747/comm/rtp_R/vhf_R_status")
B747DR_rtp_R_hf_L_status            = find_dataref("laminar/B747/comm/rtp_R/hf_L_status")
B747DR_rtp_R_am_status              = find_dataref("laminar/B747/comm/rtp_R/am_status")
B747DR_rtp_R_hf_R_status            = find_dataref("laminar/B747/comm/rtp_R/hf_R_status")
B747DR_rtp_C_offside_tuning_status  = find_dataref("laminar/B747/comm/rtp_C/offside_tuning_status")
B747DR_rtp_C_off_status             = find_dataref("laminar/B747/comm/rtp_C/off_status")
B747DR_rtp_C_vhf_L_status           = find_dataref("laminar/B747/comm/rtp_C/vhf_L_status")
B747DR_rtp_C_vhf_C_status           = find_dataref("laminar/B747/comm/rtp_C/vhf_C_status")
B747DR_rtp_C_vhf_R_status           = find_dataref("laminar/B747/comm/rtp_C/vhf_R_status")
B747DR_rtp_C_hf_L_status            = find_dataref("laminar/B747/comm/rtp_C/hf_L_status")
B747DR_rtp_C_am_status              = find_dataref("laminar/B747/comm/rtp_C/am_status")
B747DR_rtp_C_hf_R_status            = find_dataref("laminar/B747/comm/rtp_C/hf_R_status")

B747DR_ap_L_vhf_L_xmt_status        = find_dataref("laminar/B747/ap_L/vhf_L/xmt_status")
B747DR_ap_L_vhf_C_xmt_status        = find_dataref("laminar/B747/ap_L/vhf_C/xmt_status")
B747DR_ap_L_vhf_R_xmt_status        = find_dataref("laminar/B747/ap_L/vhf_R/xmt_status")
B747DR_ap_L_flt_xmt_status          = find_dataref("laminar/B747/ap_L/flt/xmt_status")
B747DR_ap_L_cab_xmt_status          = find_dataref("laminar/B747/ap_L/cab/xmt_status")
B747DR_ap_L_pa_xmt_status           = find_dataref("laminar/B747/ap_L/pa/xmt_status")
B747DR_ap_L_hf_L_xmt_status         = find_dataref("laminar/B747/ap_L/hf_L/xmt_status")
B747DR_ap_L_hf_R_xmt_status         = find_dataref("laminar/B747/ap_L/hf_R/xmt_status")
B747DR_ap_L_sat_L_xmt_status        = find_dataref("laminar/B747/ap_L/sat_L/xmt_status")
B747DR_ap_L_sat_R_xmt_status        = find_dataref("laminar/B747/ap_L/sat_R/xmt_status")

B747DR_ap_L_vhf_L_call_status       = find_dataref("laminar/B747/ap_L/vhf_L/call_status")
B747DR_ap_L_vhf_C_call_status       = find_dataref("laminar/B747/ap_L/vhf_C/call_status")
B747DR_ap_L_vhf_R_call_status       = find_dataref("laminar/B747/ap_L/vhf_R/call_status")
B747DR_ap_L_flt_call_status         = find_dataref("laminar/B747/ap_L/flt/call_status")
B747DR_ap_L_cab_call_status         = find_dataref("laminar/B747/ap_L/cab/call_status")
B747DR_ap_L_pa_call_status          = find_dataref("laminar/B747/ap_L/pa/call_status")
B747DR_ap_L_hf_L_call_status        = find_dataref("laminar/B747/ap_L/hf_L/call_status")
B747DR_ap_L_hf_R_call_status        = find_dataref("laminar/B747/ap_L/hf_R/call_status")
B747DR_ap_L_sat_L_call_status       = find_dataref("laminar/B747/ap_L/sat_L/call_status")
B747DR_ap_L_sat_R_call_status       = find_dataref("laminar/B747/ap_L/sat_R/call_status")

B747DR_ap_L_vhf_L_audio_status      = find_dataref("laminar/B747/ap_L/vhf_L/audio_status")
B747DR_ap_L_vhf_C_audio_status      = find_dataref("laminar/B747/ap_L/vhf_C/audio_status")
B747DR_ap_L_vhf_R_audio_status      = find_dataref("laminar/B747/ap_L/vhf_R/audio_status")
B747DR_ap_L_flt_audio_status        = find_dataref("laminar/B747/ap_L/flt/audio_status")
B747DR_ap_L_cab_audio_status        = find_dataref("laminar/B747/ap_L/cab/audio_status")
B747DR_ap_L_pa_audio_status         = find_dataref("laminar/B747/ap_L/pa/audio_status")
B747DR_ap_L_hf_L_audio_status       = find_dataref("laminar/B747/ap_L/hf_L/audio_status")
B747DR_ap_L_hf_R_audio_status       = find_dataref("laminar/B747/ap_L/hf_R/audio_status")
B747DR_ap_L_sat_L_audio_status      = find_dataref("laminar/B747/ap_L/sat_L/audio_status")
B747DR_ap_L_sat_R_udio_status       = find_dataref("laminar/B747/ap_L/sat_R/audio_status")
B747DR_ap_L_spkr_audio_status       = find_dataref("laminar/B747/ap_L/spkr/audio_status")
B747DR_ap_L_vor_adf_audio_status    = find_dataref("laminar/B747/ap_L/vor_adf/audio_status")
B747DR_ap_L_app_mkr_audio_status    = find_dataref("laminar/B747/ap_L/app_mkr/audio_status")

B747DR_ap_C_vhf_L_xmt_status        = find_dataref("laminar/B747/ap_C/vhf_L/xmt_status")
B747DR_ap_C_vhf_C_xmt_status        = find_dataref("laminar/B747/ap_C/vhf_C/xmt_status")
B747DR_ap_C_vhf_R_xmt_status        = find_dataref("laminar/B747/ap_C/vhf_R/xmt_status")
B747DR_ap_C_flt_xmt_status          = find_dataref("laminar/B747/ap_C/flt/xmt_status")
B747DR_ap_C_cab_xmt_status          = find_dataref("laminar/B747/ap_C/cab/xmt_status")
B747DR_ap_C_pa_xmt_status           = find_dataref("laminar/B747/ap_C/pa/xmt_status")
B747DR_ap_C_hf_L_xmt_status         = find_dataref("laminar/B747/ap_C/hf_L/xmt_status")
B747DR_ap_C_hf_R_xmt_status         = find_dataref("laminar/B747/ap_C/hf_R/xmt_status")
B747DR_ap_C_sat_L_xmt_status        = find_dataref("laminar/B747/ap_C/sat_L/xmt_status")
B747DR_ap_C_sat_R_xmt_status        = find_dataref("laminar/B747/ap_C/sat_R/xmt_status")

B747DR_ap_C_vhf_L_call_status       = find_dataref("laminar/B747/ap_C/vhf_L/call_status")
B747DR_ap_C_vhf_C_call_status       = find_dataref("laminar/B747/ap_C/vhf_C/call_status")
B747DR_ap_C_vhf_R_call_status       = find_dataref("laminar/B747/ap_C/vhf_R/call_status")
B747DR_ap_C_flt_call_status         = find_dataref("laminar/B747/ap_C/flt/call_status")
B747DR_ap_C_cab_call_status         = find_dataref("laminar/B747/ap_C/cab/call_status")
B747DR_ap_C_pa_call_status          = find_dataref("laminar/B747/ap_C/pa/call_status")
B747DR_ap_C_hf_L_call_status        = find_dataref("laminar/B747/ap_C/hf_L/call_status")
B747DR_ap_C_hf_R_call_status        = find_dataref("laminar/B747/ap_C/hf_R/call_status")
B747DR_ap_C_sat_L_call_status       = find_dataref("laminar/B747/ap_C/sat_L/call_status")
B747DR_ap_C_sat_R_call_status       = find_dataref("laminar/B747/ap_C/sat_R/call_status")

B747DR_ap_C_vhf_L_audio_status      = find_dataref("laminar/B747/ap_C/vhf_L/audio_status")
B747DR_ap_C_vhf_C_audio_status      = find_dataref("laminar/B747/ap_C/vhf_C/audio_status")
B747DR_ap_C_vhf_R_audio_status      = find_dataref("laminar/B747/ap_C/vhf_R/audio_status")
B747DR_ap_C_flt_audio_status        = find_dataref("laminar/B747/ap_C/flt/audio_status")
B747DR_ap_C_cab_audio_status        = find_dataref("laminar/B747/ap_C/cab/audio_status")
B747DR_ap_C_pa_audio_status         = find_dataref("laminar/B747/ap_C/pa/audio_status")
B747DR_ap_C_hf_L_audio_status       = find_dataref("laminar/B747/ap_C/hf_L/audio_status")
B747DR_ap_C_hf_R_audio_status       = find_dataref("laminar/B747/ap_C/hf_R/audio_status")
B747DR_ap_C_sat_L_audio_status      = find_dataref("laminar/B747/ap_C/sat_L/audio_status")
B747DR_ap_C_sat_R_udio_status       = find_dataref("laminar/B747/ap_C/sat_R/audio_status")
B747DR_ap_C_spkr_audio_status       = find_dataref("laminar/B747/ap_C/spkr/audio_status")
B747DR_ap_C_vor_adf_audio_status    = find_dataref("laminar/B747/ap_C/vor_adf/audio_status")
B747DR_ap_C_app_mkr_audio_status    = find_dataref("laminar/B747/ap_C/app_mkr/audio_status")

B747DR_ap_R_vhf_L_xmt_status        = find_dataref("laminar/B747/ap_R/vhf_L/xmt_status")
B747DR_ap_R_vhf_C_xmt_status        = find_dataref("laminar/B747/ap_R/vhf_C/xmt_status")
B747DR_ap_R_vhf_R_xmt_status        = find_dataref("laminar/B747/ap_R/vhf_R/xmt_status")
B747DR_ap_R_flt_xmt_status          = find_dataref("laminar/B747/ap_R/flt/xmt_status")
B747DR_ap_R_cab_xmt_status          = find_dataref("laminar/B747/ap_R/cab/xmt_status")
B747DR_ap_R_pa_xmt_status           = find_dataref("laminar/B747/ap_R/pa/xmt_status")
B747DR_ap_R_hf_L_xmt_status         = find_dataref("laminar/B747/ap_R/hf_L/xmt_status")
B747DR_ap_R_hf_R_xmt_status         = find_dataref("laminar/B747/ap_R/hf_R/xmt_status")
B747DR_ap_R_sat_L_xmt_status        = find_dataref("laminar/B747/ap_R/sat_L/xmt_status")
B747DR_ap_R_sat_R_xmt_status        = find_dataref("laminar/B747/ap_R/sat_R/xmt_status")

B747DR_ap_R_vhf_L_call_status       = find_dataref("laminar/B747/ap_R/vhf_L/call_status")
B747DR_ap_R_vhf_C_call_status       = find_dataref("laminar/B747/ap_R/vhf_C/call_status")
B747DR_ap_R_vhf_R_call_status       = find_dataref("laminar/B747/ap_R/vhf_R/call_status")
B747DR_ap_R_flt_call_status         = find_dataref("laminar/B747/ap_R/flt/call_status")
B747DR_ap_R_cab_call_status         = find_dataref("laminar/B747/ap_R/cab/call_status")
B747DR_ap_R_pa_call_status          = find_dataref("laminar/B747/ap_R/pa/call_status")
B747DR_ap_R_hf_L_call_status        = find_dataref("laminar/B747/ap_R/hf_L/call_status")
B747DR_ap_R_hf_R_call_status        = find_dataref("laminar/B747/ap_R/hf_R/call_status")
B747DR_ap_R_sat_L_call_status       = find_dataref("laminar/B747/ap_R/sat_L/call_status")
B747DR_ap_R_sat_R_call_status       = find_dataref("laminar/B747/ap_R/sat_R/call_status")

B747DR_ap_R_vhf_L_audio_status      = find_dataref("laminar/B747/ap_R/vhf_L/audio_status")
B747DR_ap_R_vhf_C_audio_status      = find_dataref("laminar/B747/ap_R/vhf_C/audio_status")
B747DR_ap_R_vhf_R_audio_status      = find_dataref("laminar/B747/ap_R/vhf_R/audio_status")
B747DR_ap_R_flt_audio_status        = find_dataref("laminar/B747/ap_R/flt/audio_status")
B747DR_ap_R_cab_audio_status        = find_dataref("laminar/B747/ap_R/cab/audio_status")
B747DR_ap_R_pa_audio_status         = find_dataref("laminar/B747/ap_R/pa/audio_status")
B747DR_ap_R_hf_L_audio_status       = find_dataref("laminar/B747/ap_R/hf_L/audio_status")
B747DR_ap_R_hf_R_audio_status       = find_dataref("laminar/B747/ap_R/hf_R/audio_status")
B747DR_ap_R_sat_L_audio_status      = find_dataref("laminar/B747/ap_R/sat_L/audio_status")
B747DR_ap_R_sat_R_udio_status       = find_dataref("laminar/B747/ap_R/sat_R/audio_status")
B747DR_ap_R_spkr_audio_status       = find_dataref("laminar/B747/ap_R/spkr/audio_status")
B747DR_ap_R_vor_adf_audio_status    = find_dataref("laminar/B747/ap_R/vor_adf/audio_status")
B747DR_ap_R_app_mkr_audio_status    = find_dataref("laminar/B747/ap_R/app_mkr/audio_status")


B747DR_call_pnl_ud_call_status     = find_dataref("laminar/B747/call_pnl/ud/call_status")
B747DR_call_pnl_crw_rst_L_call_status = find_dataref("laminar/B747/call_pnl/crw_rst_L/call_status")
B747DR_call_pnl_crw_rst_R_call_status = find_dataref("laminar/B747/call_pnl/crw_rst_R/call_status")
B747DR_call_pnl_cargo_call_status  = find_dataref("laminar/B747/call_pnl/cargo/call_status")
B747DR_call_pnl_grnd_call_status   = find_dataref("laminar/B747/call_pnl/grnd/call_status")


B747DR_sfty_no_smoke_sel_dial_pos   = find_dataref("laminar/B747/safety/no_smoking/sel_dial_pos")
B747DR_sfty_seat_belts_sel_dial_pos = find_dataref("laminar/B747/safety/seat_belts/sel_dial_pos")


-- the fire protection model's BTL DISCH lights: L ENG A, B, R ENG A, B, APU (B747.35.xt.fire.lua)
B747DR_fire_light_btl_disch         = find_dataref("laminar/B747/fire/light/btl_disch")
-- CARGO FIRE FWD, AFT, DISCH and the squib test lights (engines 1-4, APU, cargo A-D)
B747DR_fire_light_cargo             = find_dataref("laminar/B747/fire/light/cargo")
B747DR_fire_light_squib             = find_dataref("laminar/B747/fire/light/squib")

-- the fuel system's overhead lights (fuel module; created by the B747.25.fuel init)
B747DR_fuel_light_pump_press        = find_dataref("laminar/B747/fuel/light/pump_press")
B747DR_fuel_light_xfeed_valve       = find_dataref("laminar/B747/fuel/light/xfeed_valve")
B747DR_fuel_light_nozzle_valve      = find_dataref("laminar/B747/fuel/light/nozzle_valve")

B747DR_bleed_air_iso_vlv_L_pos      = find_dataref("laminar/B747/air/isolation_valve_L_pos")
B747DR_bleed_air_iso_vlv_R_pos      = find_dataref("laminar/B747/air/isolation_valve_R_pos")

B747DR_bleed_air_apu_vlv_pos        = find_dataref("laminar/B747/air/apu/bleed_valve_pos")

B747DR_bleed_air_engine1_vlv_pos    = find_dataref("laminar/B747/air/engine1/bleed_valve_pos")
B747DR_bleed_air_engine2_vlv_pos    = find_dataref("laminar/B747/air/engine2/bleed_valve_pos")
B747DR_bleed_air_engine3_vlv_pos    = find_dataref("laminar/B747/air/engine3/bleed_valve_pos")
B747DR_bleed_air_engine4_vlv_pos    = find_dataref("laminar/B747/air/engine4/bleed_valve_pos")

B747DR_bleed_air_engine1_start_valve_pos = find_dataref("laminar/B747/air/engine1/bleed_start_valve_pos")
B747DR_bleed_air_engine2_start_valve_pos = find_dataref("laminar/B747/air/engine2/bleed_start_valve_pos")
B747DR_bleed_air_engine3_start_valve_pos = find_dataref("laminar/B747/air/engine3/bleed_start_valve_pos")
B747DR_bleed_air_engine4_start_valve_pos = find_dataref("laminar/B747/air/engine4/bleed_start_valve_pos")

B747DR_autopilot_cmd_L_status       = find_dataref("laminar/B747/autopilot/cmd_L_mode/status")
B747DR_autopilot_cmd_C_status       = find_dataref("laminar/B747/autopilot/cmd_C_mode/status")
B747DR_autopilot_cmd_R_status       = find_dataref("laminar/B747/autopilot/cmd_R_mode/status")
-- the channels L, C, R armed for multi-channel: their CMD lights on too
-- (6-3 step 4a; ATA22 p.288)
B747DR_autopilot_cmd_armed          = find_dataref("laminar/B747/autopilot/cmd_armed")

B747DR_master_warning               = find_dataref("laminar/B747/warning/master_warning")
B747DR_master_caution               = find_dataref("laminar/B747/warning/master_caution")

B747DR_CAS_memo_status              = find_dataref("laminar/B747/CAS/memo_status")
-- the IRS ON BAT light (the navigation sensors module, B747.34.xt.irs.lua)
B747DR_irs_on_bat                   = find_dataref("laminar/B747/irs/on_bat")

B747DR_simDR_captain_display             = deferred_dataref("laminar/B747/electrical/capt_display_power", "number")
B747DR_simDR_fo_display             = deferred_dataref("laminar/B747/electrical/fo_display_power", "number")
B747DR_elec_display_power               = find_dataref("laminar/B747/electrical/display_has_power")


--wxr lighting
B747DR_wxr_left_GCS             = deferred_dataref("laminar/B747/wxr/left/GCS", "number")
B747DR_wxr_left_TFR             = deferred_dataref("laminar/B747/wxr/left/TFR", "number")
B747DR_wxr_left_WX             = deferred_dataref("laminar/B747/wxr/left/WX", "number")
B747DR_wxr_left_WX_T            = deferred_dataref("laminar/B747/wxr/left/WX_T", "number")
B747DR_wxr_left_MAP            = deferred_dataref("laminar/B747/wxr/left/MAP", "number")
B747DR_wxr_right_GCS             = deferred_dataref("laminar/B747/wxr/right/GCS", "number")
B747DR_wxr_right_TFR             = deferred_dataref("laminar/B747/wxr/right/TFR", "number")
B747DR_wxr_right_WX             = deferred_dataref("laminar/B747/wxr/right/WX", "number")
B747DR_wxr_right_WX_T            = deferred_dataref("laminar/B747/wxr/right/WX_T", "number")
B747DR_wxr_right_MAP            = deferred_dataref("laminar/B747/wxr/right/MAP", "number")

B747DR_wxr_test            = deferred_dataref("laminar/B747/wxr/test", "number")
B747DR_wxr_RR            = deferred_dataref("laminar/B747/wxr/RR", "number")
B747DR_wxr_LR            = deferred_dataref("laminar/B747/wxr/LR", "number")

-- the weather radar control's lamps (B747.34.xt.wxr.lua): each side's lit mode
-- switch (1 WX, 2 WX+T, 3 MAP, 4 TFR) and GCS, TEST, the lit R/T (1 L, 2 R)
B747DR_wxr_lamp_sel             = find_dataref("laminar/B747/wxr/lamp/sel")
B747DR_wxr_lamp_gcs             = find_dataref("laminar/B747/wxr/lamp/gcs")
B747DR_wxr_lamp_test            = find_dataref("laminar/B747/wxr/lamp/test")
B747DR_wxr_lamp_rt              = find_dataref("laminar/B747/wxr/lamp/rt")
local function wxr_lamp(light_test, on, level)
    if light_test or on then return level end
    return 0
end
--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

----- SPILL LIGHTS ----------------------------------------------------------------------
B747DR_spill_light_capt_panel_flood     = deferred_dataref("laminar/B747/light/spill/ratio/captain_panel", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_center_panel_flood   = deferred_dataref("laminar/B747/light/spill/ratio/center_panel", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_capt_map             = deferred_dataref("laminar/B747/light/spill/ratio/captain_map", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_capt_chart           = deferred_dataref("laminar/B747/light/spill/ratio/captain_chart", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_fo_panel_flood       = deferred_dataref("laminar/B747/light/spill/ratio/first_officer_panel", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_fo_map               = deferred_dataref("laminar/B747/light/spill/ratio/first_officer_map", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_fo_chart             = deferred_dataref("laminar/B747/light/spill/ratio/first_officer_chart", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_observer_map         = deferred_dataref("laminar/B747/light/spill/ratio/observer_map", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_mcp_flood            = deferred_dataref("laminar/B747/light/spill/ratio/mcp_panel", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_aisle_stand_flood    = deferred_dataref("laminar/B747/light/spill/ratio/aisle_stand", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")
B747DR_spill_light_mag_compass_flood    = deferred_dataref("laminar/B747/light/spill/ratio/mag_compass", "array[" .. tostring(NUM_SPILL_LIGHT_INDICES) .. "]")

B747DR_init_lighting_CD                 = deferred_dataref("laminar/B747/lighting/init_CD", "number")



----- LIT -------------------------------------------------------------------------------
--B747DR_LIT_capt_panel_flood             = deferred_dataref("laminar/B747/light/LIT/capt_panel_flood", "number")
--B747DR_LIT_fo_panel_flood               = deferred_dataref("laminar/B747/light/LIT/fo_panel_flood", "number")



----- ANNUNCIATORS ----------------------------------------------------------------------
B747DR_annun_brightness_ratio           = deferred_dataref("laminar/B747/annunciator/brightness_ratio", "array[" .. tostring(NUM_ANNUN_LIGHTS) .. "]")

B747DR_ap_FMA_autothrottle_mode     	= deferred_dataref("laminar/B747/autopilot/FMA/autothrottle_mode", "number")



--*************************************************************************************--
--** 				         READ-WRITE CUSTOM DATAREF HANDLERS     	    	     **--
--*************************************************************************************--

----- LIGHTING RHEOSTATS ----------------------------------------------------------------
function B747DR_flood_light_rheo_capt_panel_DRhandler() end
function B747DR_map_light_rheo_capt_DRhandler() end
function B747DR_chart_light_rheo_capt_DRhandler() end
function B747DR_flood_light_rheo_fo_panel_DRhandler() end
function B747DR_map_light_rheo_fo_DRhandler() end
function B747DR_chart_light_rheo_fo_DRhandler() end
function B747DR_map_light_rheo_observer_DRhandler() end
function B747DR_flood_light_rheo_mcp_DRhandler() end
function B747DR_flood_light_rheo_aisle_stand_DRhandler() end
function B747DR_flood_light_rheo_overhead_DRhandler() end




--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

----- LIGHTING RHEOSTATS ----------------------------------------------------------------
B747DR_flood_light_rheo_capt_panel      = deferred_dataref("laminar/B747/light/flood/rheostat/captain_panel", "number", B747DR_flood_light_rheo_capt_panel_DRhandler)
B747DR_map_light_rheo_capt              = deferred_dataref("laminar/B747/light/map/rheostat/captain", "number", B747DR_map_light_rheo_capt_DRhandler)
B747DR_chart_light_rheo_capt            = deferred_dataref("laminar/B747/light/chart/rheostat/captain", "number", B747DR_chart_light_rheo_capt_DRhandler)
B747DR_flood_light_rheo_fo_panel        = deferred_dataref("laminar/B747/light/flood/rheostat/first_officer_panel", "number", B747DR_flood_light_rheo_fo_panel_DRhandler)
B747DR_map_light_rheo_fo                = deferred_dataref("laminar/B747/light/map/rheostat/first_officer", "number", B747DR_map_light_rheo_fo_DRhandler)
B747DR_chart_light_rheo_fo              = deferred_dataref("laminar/B747/light/chart/rheostat/first_officer", "number", B747DR_chart_light_rheo_fo_DRhandler)
B747DR_map_light_rheo_observer          = deferred_dataref("laminar/B747/light/map/rheostat/observer", "number", B747DR_map_light_rheo_observer_DRhandler)
B747DR_flood_light_rheo_mcp             = deferred_dataref("laminar/B747/light/flood/rheostat/mcp_panel", "number", B747DR_flood_light_rheo_mcp_DRhandler)
B747DR_flood_light_rheo_aisle_stand     = deferred_dataref("laminar/B747/light/flood/rheostat/aisle_stand", "number", B747DR_flood_light_rheo_aisle_stand_DRhandler)
B747DR_flood_light_rheo_overhead        = deferred_dataref("laminar/B747/light/flood/rheostat/overhead", "number", B747DR_flood_light_rheo_overhead_DRhandler)

----- SPILL LIGHTS ----------------------------------------------------------------------
B747DR_fmc_spill_lights			= deferred_dataref("laminar/B747/fmc/spill_lights", "number") --silvereagle

function B747CMD_cockpitLightsOn_CMDhandler()
  --TODO Animate
  B747DR_flood_light_rheo_capt_panel=1
  B747DR_map_light_rheo_capt=1
  B747DR_chart_light_rheo_capt=1
  B747DR_flood_light_rheo_fo_panel=1
  B747DR_map_light_rheo_fo=1
  B747DR_chart_light_rheo_fo=1
  B747DR_map_light_rheo_observer=1
  B747DR_flood_light_rheo_mcp=1
  B747DR_flood_light_rheo_aisle_stand=1
  B747DR_flood_light_rheo_overhead=1
end

function B747CMD_cockpitLightsOff_CMDhandler()
  --TODO Animate
  B747DR_flood_light_rheo_capt_panel=0
  B747DR_map_light_rheo_capt=0
  B747DR_chart_light_rheo_capt=0
  B747DR_flood_light_rheo_fo_panel=0
  B747DR_map_light_rheo_fo=0
  B747DR_chart_light_rheo_fo=0
  B747DR_map_light_rheo_observer=0
  B747DR_flood_light_rheo_mcp=0
  B747DR_flood_light_rheo_aisle_stand=0
  B747DR_flood_light_rheo_overhead=0
end

B747CMD_cockpitLightsOn		= deferred_command("laminar/B747/light/cockpit_lightsOn", "cockpit lights On", B747CMD_cockpitLightsOn_CMDhandler)
B747CMD_cockpitLightsOff		= deferred_command("laminar/B747/light/cockpit_lightsOff", "cockpit lights Off", B747CMD_cockpitLightsOff_CMDhandler)

--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--






--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--





--*************************************************************************************--
--** 				               FIND CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747CMD_taxi_light_switch               = find_command("laminar/B747/toggle_switch/taxi_light")
B747CMD_runway_turnoff_light_switch_L   = find_command("laminar/B747/toggle_switch/rwy_tunoff_L")
B747CMD_runway_turnoff_light_switch_R   = find_command("laminar/B747/toggle_switch/rwy_tunoff_R")



--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--


function B747_ai_lighting_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
		B747_set_lighting_all_modes()
		B747_set_lighting_CD()
		B747_set_lighting_ER()	
	end 	
end	



--*************************************************************************************--
--** 				               CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- AI
B747CMD_ai_lighting_quick_start			= deferred_command("laminar/B747/ai/lighting_quick_start", "number", B747_ai_lighting_quick_start_CMDhandler)



--*************************************************************************************--
--** 					            OBJECT CONSTRUCTORS         		    		 **--
--*************************************************************************************--




--*************************************************************************************--
--** 				              CREATE SYSTEM OBJECTS            	    			 **--
--*************************************************************************************--




--*************************************************************************************--
--** 				                 SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

----- TERNARY CONDITIONAL ---------------------------------------------------------------
function B747_ternary(condition, ifTrue, ifFalse)
    if condition then return ifTrue else return ifFalse end
end





----- RESCALE FLOAT AND CLAMP TO OUTER LIMITS -------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end






----- INITIALIZE LIGHTING ---------------------------------------------------------------
function B747_init_lighting()

    -- TURN OFF THE FLIGHT DECK OVERHEAD FLOOD LIGHTS
    simDR_panel_brightness_switch[0] = 0.0

    -- SPILL LIGHTS
    --[[
    NOTE: FOR SPILL LIGHTS (AS PER BEN SUPNIK)...
    THE ORDER OF ARRAY DATA FOR THE OBJ FILE IS DIFFERENT THAN WHAT WE NEED TO USE TO SET THE DATAREF IN CODE.

    OBJ IS AS FOLLOWS:
    X	Y	Z	R	G	B	A	SIZE	Dx	Dy	Dz	SEMI	DATAREF

    SET DATAREF WITH CODE AS FOLLOWS:
    X	Y	Z	R	G	B	A	SIZE	SEMI	Dx	Dy	Dz
    --]]

    local capt_panel_flood_values = {1.0, 0.70, 0.24, 0.0, 0.55, 0.60, -0.05, -0.525, -0.425}
    local center_panel_flood_values = {1.0, 0.70, 0.24, 0.0, 0.65, 0.15, 0.0, -1.0, 0.0}
    local capt_map_values = {1.0, 0.70, 0.24, 0.0, 2.0, 0.98, 0.0, -1.0, 0.0}
    local capt_chart_values = {1.0, 0.70, 0.24, 0.0, 0.37, 0.88, -0.35, -0.65, 0.25}
    local fo_panel_flood_values = {1.0, 0.70, 0.24,  0.0, 0.55, 0.60, 0.05, -0.525, -0.425}
    local fo_map_values = {1.0, 0.70, 0.24, 0.0, 2.0, 0.98, 0.0, -1.0, 0.0}
    local fo_chart_values = {1.0, 0.70, 0.24, 0.0, 0.37, 0.88, 0.35, -0.65, 0.25}
    local observer_map_values = {1.0, 0.70, 0.24, 0.0, 2.5, 0.95, 0.15, -0.68, 0.17}
    local mcp_flood_values = {1.0, 0.70, 0.24, 0.0, 0.12, 0.08, 0.0, -0.50, 0.50}
    local aisle_stand_flood_values = {1.0, 0.70, 0.24, 0.0, 2.0, 0.85, 0.0, -0.8, -0.2}
    local mag_compass_flood_values = {1.0, 0.70, 0.24, 0.0, 0.1, 0.55, 0.0, 0.0 , -1.0}
    if simDR_version>=120012 then
        capt_panel_flood_values = {1.0, 0.70, 0.24, 10.0, 55.0, 0.60, -0.05, -0.525, -0.425}
        center_panel_flood_values = {1.0, 0.70, 0.24, 10.0, 65.0, 0.15, 0.0, -1.0, 0.0}
        capt_map_values = {1.0, 0.70, 0.24, 10.0, 200.0, 0.98, 0.0, -1.0, 0.0}
        capt_chart_values = {1.0, 0.70, 0.24, 10.0, 37.0, 0.88, -0.35, -0.65, 0.25}
        fo_panel_flood_values = {1.0, 0.70, 0.24,  10.0, 55.0, 0.60, 0.05, -0.525, -0.425}
        fo_map_values = {1.0, 0.70, 0.24, 10.0, 200.0, 0.98, 0.0, -1.0, 0.0}
        fo_chart_values = {1.0, 0.70, 0.24, 10.0, 37.0, 0.88, 0.35, -0.65, 0.25}
        observer_map_values = {1.0, 0.70, 0.24, 10.0, 250.0, 0.95, 0.15, -0.68, 0.17}
        mcp_flood_values = {1.0, 0.70, 0.24, 10.0, 12.0, 0.08, 0.0, -0.50, 0.50}
        aisle_stand_flood_values = {1.0, 0.70, 0.24, 10.0, 200.0, 0.85, 0.0, -0.8, -0.2}
        mag_compass_flood_values = {1.0, 0.70, 0.24, 10.0, 10.0, 0.55, 0.0, 0.0 , -1.0}
    end
    for i = 1, NUM_SPILL_LIGHT_INDICES do
        B747DR_spill_light_capt_panel_flood[i-1] = capt_panel_flood_values[i]
        B747DR_spill_light_center_panel_flood[i-1] = center_panel_flood_values[i]
        B747DR_spill_light_capt_map[i-1] = capt_map_values[i]
        B747DR_spill_light_capt_chart[i-1] = capt_chart_values[i]
        B747DR_spill_light_fo_panel_flood[i-1] = fo_panel_flood_values[i]
        B747DR_spill_light_fo_map[i-1] = fo_map_values[i]
        B747DR_spill_light_fo_chart[i-1] = fo_chart_values[i]
        B747DR_spill_light_observer_map[i-1] = observer_map_values[i]
        B747DR_spill_light_mcp_flood[i-1] = mcp_flood_values[i]
        B747DR_spill_light_aisle_stand_flood[i-1] = aisle_stand_flood_values[i]
        B747DR_spill_light_mag_compass_flood[i-1] = mag_compass_flood_values[i]
    end

end




----- INIT THE LIGHT RHEOSTATS ----------------------------------------------------------
function B747_init_light_rheostats()					

    local light_level = B747_rescale(0.1, 0.0, 0.2, 0.45, simDR_percent_lights_on)
    
    B747DR_flood_light_rheo_capt_panel      = light_level
    B747DR_map_light_rheo_capt              = 0
    B747DR_chart_light_rheo_capt            = 0
    B747DR_flood_light_rheo_fo_panel        = light_level
    B747DR_map_light_rheo_fo                = 0
    B747DR_chart_light_rheo_fo              = 0
    B747DR_map_light_rheo_observer          = 0
    B747DR_flood_light_rheo_mcp             = light_level
    B747DR_flood_light_rheo_aisle_stand     = light_level
    B747DR_flood_light_rheo_overhead        = 0
    simDR_panel_brightness_switch[1]        = light_level * 0.85                            -- FIRST OBSERVER PANEL
    simDR_panel_brightness_switch[2]        = light_level * 0.85                            -- AISLE STAND PANEL
    simDR_panel_brightness_switch[3]        = light_level * 0.90                            -- GLARESHIELD PANEL/MCP PANEL/COMPASS
    B747DR_instrument_brightness_ratio[6]   = light_level * 0.10                            -- CAPTAIN PANEL
    B747DR_instrument_brightness_ratio[7]   = light_level * 0.10                            -- OVERHEAD PANEL
    B747DR_instrument_brightness_ratio[8]   = light_level * 0.10                            -- F/O PANEL
    
    --simDR_panel_brightness_switch[1]        = light_level * 0.85                            -- FIRST OBSERVER PANEL
    --simDR_panel_brightness_switch[2]        = light_level * 0.85                            -- AISLE STAND PANEL
    --simDR_panel_brightness_switch[3]        = light_level * 0.90                            -- GLARESHIELD PANEL/MCP PANEL/COMPASS
    --B747DR_instrument_brightness_ratio[6]   = light_level * 0.90                            -- CAPTAIN PANEL
    --B747DR_instrument_brightness_ratio[7]   = light_level * 0.90                            -- OVERHEAD PANEL
    --B747DR_instrument_brightness_ratio[8]   = light_level * 0.90                            -- F/O PANEL

end




----- EXTERIOR LIGHTS --------------------------------------------------------------------
-- (7-2b; notes/ATA-33.md §12) the exterior lights by B747.90.light_model.lua:
-- their switches (position 0 on; the beacon's LWR 1 and BOTH -1), the AC
-- buses and the ground service bus (laminar/B747/electrical/bus/*), the
-- PSEU's ground mode and the gear lever (before, X-Plane's onground_any and
-- no power: on with the batteries alone; the landing lights 50 % with the
-- lever up). (7-2a, LIGHT-04 and 05) the strobe switch as the others
-- (before, position 1 on), the strobes' only writer
dofile("B747.90.light_model.lua")
B747DR_light_bus_ac = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_light_bus_gsb = find_dataref("laminar/B747/electrical/bus/gnd_svc")
B747DR_light_pseu_gnd = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
local lightIn = {sw = {landing = {}, turnoff = {}}, ac = {}}
-- (7-2e, LIGHT-07) the flight deck lighting's power by the same model
-- (M.cockpit): the AC buses, the main standby bus, the ground service bus,
-- the main battery bus and STORM (toggle switch 0 at 0). The plugin's own
-- channels only: the captain's, overhead and F/O's panel lighting
-- (instrument_brightness 6-8), the floods, the dome (panel_brightness 0) and
-- the map lights. The glareshield's, aisle stand's and observer's panel
-- lighting are X-Plane's switches (panel_brightness 1-3) the 3D's knobs move
-- themselves: left to X-Plane. The fixed brightnesses: estimates (the
-- sources say only "fixed")
B747DR_light_bus_stby = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_light_bus_bat = find_dataref("laminar/B747/electrical/bus/bat_main")
-- (1-1) any AC bus: the cabin lights (B747_cabin_lights)
B747DR_light_bus_any_ac = find_dataref("laminar/B747/electrical/bus/any_ac")
local cockpitIn = {ac = {false, false, false, false}}
local cockpit_mode = B747_light_model.cockpit(cockpitIn)
local FIXED_PANEL, FIXED_FLOOD, FIXED_AISLE, FIXED_DOME = 0.3, 0.5, 0.3, 0.4
local function B747_cockpit_power()
    for i = 1, 4 do cockpitIn.ac[i] = B747DR_light_bus_ac[i - 1] > 0.5 end
    cockpitIn.stby = B747DR_light_bus_stby > 0.5
    cockpitIn.gsb = B747DR_light_bus_gsb > 0.5
    cockpitIn.bat = B747DR_light_bus_bat > 0.5
    cockpitIn.storm = B747DR_toggle_switch_position[0] <= 0.05
    cockpit_mode = B747_light_model.cockpit(cockpitIn)
end
-- a group's level from its mode: its knob's, a fixed one, the maximum or none
local function cockpit_level(mode, knob, fixed, max)
    if mode == B747_light_model.KNOB then return knob
    elseif mode == B747_light_model.FIXED then return fixed
    elseif mode == B747_light_model.MAX then return max end
    return 0
end
local function cockpit_on(mode)
    if mode == B747_light_model.OFF then return 0 end
    return 1
end
-- instrument_brightness channels of the panel lighting
local PANEL_GROUP = {[6] = "capt_panel", [7] = "overhead", [8] = "fo_panel"}
-- X-Plane's landing light i (OUTBD L, INBD L, INBD R, OUTBD R): its switch
local LANDING_SW = {1, 3, 4, 2}
function B747_exterior_lights()
    local p = B747DR_toggle_switch_position
    local sw = lightIn.sw
    for i = 1, 4 do sw.landing[i] = p[LANDING_SW[i]] < 0.05 end
    sw.turnoff[1], sw.turnoff[2] = p[5] < 0.05, p[6] < 0.05
    sw.taxi = p[7] < 0.05
    sw.beacon = p[8] > 0.95 or p[8] < -0.95
    sw.nav, sw.strobe, sw.wing, sw.logo = p[9] < 0.05, p[10] < 0.05, p[11] < 0.05, p[12] < 0.05
    for i = 1, 4 do lightIn.ac[i] = B747DR_light_bus_ac[i - 1] > 0.5 end
    lightIn.gsb = B747DR_light_bus_gsb > 0.5
    lightIn.ground = B747DR_light_pseu_gnd > 0.5
    lightIn.gear_down = B747DR_gear_handle < 0.05
    local out = B747_light_model.update(lightIn)
    for i = 1, 4 do simDR_landing_light_switch[i - 1] = out.landing[i] end
    simDR_generic_brightness_switch[0] = out.turnoff[1]
    simDR_generic_brightness_switch[1] = out.turnoff[2]
    simDR_taxi_light_switch_on = out.taxi
    simDR_beacon_lights_switch = out.beacon
    simDR_nav_lights_switch = out.nav
    simDR_strobe_lights_switch = out.strobe
    simDR_generic_brightness_switch[2] = out.wing
    simDR_generic_brightness_switch[3] = out.logo
end



function B747_animate_value(current_value, target, min, max, speed)

    local fps_factor = math.min(0.1, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end

local brightnessRate={}
local brightnessPower={}
for i = 0, 32 do
	brightnessRate[i]=0.5+math.random()
	brightnessPower[i]=1
end
-- a display takes the brightness knob of the unit it is on (5-2 step 1,
-- DSP-30; FCOM p.1071): each display's rheostat in the panel (as
-- display_has_power: Captain PFD, F/O PFD, F/O ND, Captain ND, primary
-- EICAS, secondary EICAS) and each unit's knob (instrument_brightness_ratio:
-- Captain outboard, Captain inboard, upper, lower, F/O inboard, F/O outboard)
B747DR_light_content_unit       = find_dataref("laminar/B747/displays/content_unit")
local DISPLAY_RHEOSTAT = {2, 5, 3, 0, 9, 10}
local UNIT_KNOB = {2, 0, 9, 10, 3, 5}
local knob_of = {}
for i = 0, 32 do knob_of[i] = i end
----- CABIN LIGHTS ----------------------------------------------------------------------
function B747_cabin_lights()
    --B747DR_elec_display_power
        -- Captain PFD 0
    -- First Officer PFD 1
    -- First Officer ND 2
    -- Captain ND 3
    -- Upper EIACAS 4
    -- Lower EICAS 5
       brightnessPower[3]=B747_animate_value(brightnessPower[3],B747DR_elec_display_power[2],0,1,0.5) --FO ND
       brightnessPower[5]=B747_animate_value(brightnessPower[5],B747DR_elec_display_power[1],0,1,0.5) --FO PFD
       brightnessPower[10]=B747_animate_value(brightnessPower[10],B747DR_elec_display_power[5],0,1,0.5) --LOWER EICAS
       brightnessPower[0]=B747_animate_value(brightnessPower[0],B747DR_elec_display_power[3],0,1,0.5) --C ND
       brightnessPower[2]=B747_animate_value(brightnessPower[2],B747DR_elec_display_power[0],0,1,0.5) --C PFD
       brightnessPower[9]=B747_animate_value(brightnessPower[9],B747DR_elec_display_power[4],0,1,0.5) --UPPER EICAS
     if B747DR_simDR_fo_display==6 then --FO Transfer bus
       brightnessPower[13]=0 --FMS R
     else
       brightnessPower[13]=B747_animate_value(brightnessPower[13],1,0,1,0.5)
     end
     
     if B747DR_simDR_captain_display==6 then --Capt Transfer bus
       brightnessPower[12]=0 --FMS C/L
     else
       brightnessPower[12]=B747_animate_value(brightnessPower[12],1,0,1,0.5)
     end
     

     for c = 1, 6 do
         local u = B747DR_light_content_unit[c - 1]
         knob_of[DISPLAY_RHEOSTAT[c]] = UNIT_KNOB[u] or DISPLAY_RHEOSTAT[c]
     end
     -- (7-2e) the panel lighting (6-8) by the flight deck lighting's power
     B747_cockpit_power()
     for i = 0, 32 do
-- 	--print(i)
         local target
         local group = PANEL_GROUP[i]
         if group then
             target = cockpit_level(cockpit_mode[group], B747DR_instrument_brightness_ratio[i], FIXED_PANEL, 1)
         else
             target = B747DR_instrument_brightness_ratio[knob_of[i]] * simDR_generic_brightness_ratio[63] * brightnessPower[i]
         end
         simDR_instrument_brightness_switch[i] = B747_animate_value(simDR_instrument_brightness_switch[i], target, 0, 1, brightnessRate[i])
     end
    -- (1-1) the cabin lights from the 747's AC buses: any of AC buses 1-4
    -- (the cabin lighting's buses not in the sources: estimate). Before,
    -- X-Plane's APU generator, GPU, engine generators and cross tie
    local power = B747DR_light_bus_any_ac > 0.5 and 1 or 0



    local switch_value = 0

    if simDR_ai_flies_aircraft == 1
        or simDR_autoboard_in_progress == 1
        or simDR_autostart_in_progress == 1
    then
        if B747DR_toggle_switch_position[37] > 0.95
            and power == 1
        then
            switch_value = 0.25
        else
            switch_value = 0.0
        end
    else
        if simDR_percent_lights_on > 0.25
            and power == 1 and ((simDR_aircraft_altitude > 10000.0) or simDR_aircraft_groundspeed<15)
        then
            switch_value = 0.25
        elseif simDR_percent_lights_on > 0.25
        and power == 1 and ((simDR_aircraft_altitude < 10000.0) and simDR_aircraft_groundspeed>15)
            then 
            switch_value = 0.001      
        else
            switch_value = 0.0
        end
    end
    simDR_generic_brightness_switch[25] = switch_value
    

end

--silvereagle added/modified to end
----- SPILL LIGHTS ----------------------------------------------------------------------
function B747_spill_lights()
    local lightMod=0.5
    if simDR_version>=120012 then
        lightMod=simDR_sim_brightness_ratio
    end

	if B747DR_fmc_spill_lights == 1 then
		-- HERE FOR FMC "SIM CONFIG" PAGE "<SPILL LIGHTS HI" (BRIGHT DAY), STORM SWITCH HAS NO EFFECT

		-- USE THE GENERIC LIGHT INDEX [63] AS A "POWER" VALUE FOR THE SPILL LIGHTS
		
		-- TODO:  ADD BUS POWER LOGIC ?

		local storm_light_brt_level = 16.0 * lightMod 
		local storm_light_level = storm_light_brt_level * simDR_generic_brightness_ratio[63]

		-- SET THE SPILL LIGHT LEVELS ((7-2e) none where the group has no power)
		local m = cockpit_mode
		local maps = cockpit_on(m.maps)
		B747DR_spill_light_capt_panel_flood[3]      = storm_light_level * 3 * cockpit_on(m.capt_flood)
		B747DR_spill_light_center_panel_flood[3]    = storm_light_level * 3 * cockpit_on(m.capt_flood)
		B747DR_spill_light_capt_map[3]              = B747DR_map_light_rheo_capt * maps
		B747DR_spill_light_capt_chart[3]            = B747DR_chart_light_rheo_capt * maps
		B747DR_spill_light_fo_panel_flood[3]        = storm_light_level * 3 * cockpit_on(m.fo_flood)
		B747DR_spill_light_fo_map[3]                = B747DR_map_light_rheo_fo * maps
		B747DR_spill_light_fo_chart[3]              = B747DR_chart_light_rheo_fo * maps
		B747DR_spill_light_observer_map[3]          = B747DR_map_light_rheo_observer * maps
		B747DR_spill_light_mcp_flood[3]             = storm_light_level * cockpit_on(m.glareshield_flood)
		B747DR_spill_light_aisle_stand_flood[3]     = storm_light_level * 3 * cockpit_on(m.aisle_flood)

		--SET THE OVERHEAD FLOOD BRIGHTNESS LEVEL
		simDR_panel_brightness_switch[0]            = storm_light_level * cockpit_on(m.dome)

		-- SET THE MAG COMPASS SPILL LIGHT LEVEL
		B747DR_spill_light_mag_compass_flood[3]     = simDR_panel_brightness_ratio[3] * lightMod *2
	
	elseif B747DR_fmc_spill_lights == 0 then
		-- HERE FOR "SIM CONFIG" PAGE "<SPILL LIGHTS NORM" (NOT BRIGHT DAY), STORM SWITCH HAS EFFECT

		-- USE THE GENERIC LIGHT INDEX [63] AS A "POWER" VALUE FOR THE SPILL LIGHTS

		-- TODO:  ADD BUS POWER LOGIC ?

		-- BRIGHTNESS LEVEL FOR STORM LIGHTS
		-- (7-2c) the knobs' maximum: R8068 puts a fixed resistor for them
		-- (ATA33 p.72; FCOM p.438). Before, 1.9: 95 %
		local storm_light_brt_level = 2.0 * lightMod
		-- (7-2e) each group's power from the flight deck lighting's model
		-- (B747_cockpit_power): its knob, a fixed level (estimates), STORM's
		-- maximum or none. Before, every flood followed X-Plane's generic
		-- light 63 and STORM worked without the battery bus
        local lightLevel = lightMod * 2
		local storm_light_level = storm_light_brt_level
		local m = cockpit_mode
		local fixed_flood = FIXED_FLOOD * lightLevel
		local maps = cockpit_on(m.maps)

		-- SET THE SPILL LIGHT LEVELS
		B747DR_spill_light_capt_panel_flood[3]      = cockpit_level(m.capt_flood, B747DR_flood_light_rheo_capt_panel * lightLevel, fixed_flood, storm_light_level)
		B747DR_spill_light_center_panel_flood[3]    = cockpit_level(m.capt_flood, B747DR_flood_light_rheo_capt_panel * lightLevel, fixed_flood, storm_light_level)
		B747DR_spill_light_capt_map[3]              = B747DR_map_light_rheo_capt * maps
		B747DR_spill_light_capt_chart[3]            = B747DR_chart_light_rheo_capt * maps
		B747DR_spill_light_fo_panel_flood[3]        = cockpit_level(m.fo_flood, B747DR_flood_light_rheo_fo_panel * lightLevel, fixed_flood, storm_light_level)
		B747DR_spill_light_fo_map[3]                = B747DR_map_light_rheo_fo * maps
		B747DR_spill_light_fo_chart[3]              = B747DR_chart_light_rheo_fo * maps
		B747DR_spill_light_observer_map[3]          = B747DR_map_light_rheo_observer * maps
		B747DR_spill_light_mcp_flood[3]             = cockpit_level(m.glareshield_flood, B747DR_flood_light_rheo_mcp * lightLevel, fixed_flood, storm_light_level)
		B747DR_spill_light_aisle_stand_flood[3]     = cockpit_level(m.aisle_flood, B747DR_flood_light_rheo_aisle_stand * lightLevel, FIXED_AISLE * lightLevel, storm_light_level)

		--SET THE OVERHEAD FLOOD BRIGHTNESS LEVEL (the dome)
		simDR_panel_brightness_switch[0]            = cockpit_level(m.dome, B747DR_flood_light_rheo_overhead, FIXED_DOME, storm_light_level)
        simDR_panel_brightness_switch[0]            = simDR_panel_brightness_switch[0]
        simDR_panel_brightness_switch[1]            = simDR_panel_brightness_switch[1]
        simDR_panel_brightness_switch[2]            = simDR_panel_brightness_switch[2]
        simDR_panel_brightness_switch[3]            = simDR_panel_brightness_switch[3]
		-- SET THE MAG COMPASS SPILL LIGHT LEVEL
		B747DR_spill_light_mag_compass_flood[3]     = simDR_panel_brightness_ratio[3] * lightLevel

	end
end
--silvereagle end

----- ANNUNCIATORS ----------------------------------------------------------------------
function B747_annunciators()

    -- BUTTON SWITCHES --------------------------------------------------------

    ------ GLARESHIELD -----

    -- MASTER CAUTION
    annun.b.master_caution = B747DR_master_caution

    -- MASTER WARNING
    annun.b.master_warning = B747DR_master_warning



    ----- MAIN PANEL -----

    -- GROUND PROXIMITY: the GPWS's alerts (FCOM p.1538)
    annun.b.gpws = B747DR_lt_gpws_gnd_prox

    -- GLIDESLOPE INHIBIT: the 109's light; the 405's G/S INHB switch has none
    -- (FCOM p.1537-1539)
    annun.b.gs_inhibit = 0



    ----- OVERHEAD PANEL -----

    -- ELECTRONIC ENGING CONTROL
    annun.b.el_eng_ctrl_01 = B747_ternary((B747DR_button_switch_position[7] < 0.5), 1, 0)
    annun.b.el_eng_ctrl_02 = B747_ternary((B747DR_button_switch_position[8] < 0.5), 1, 0)
    annun.b.el_eng_ctrl_03 = B747_ternary((B747DR_button_switch_position[9] < 0.5), 1, 0)
    annun.b.el_eng_ctrl_04 = B747_ternary((B747DR_button_switch_position[10] < 0.5), 1, 0)

    -- ELECTRICAL PANEL (P5): the electrical model computes the lights
    -- (B747.03.xt.elec_buses.lua; FCOM p.781-786) and the EXT/APU ON states
    annun.b.util_power_L = B747DR_elec_light_util_off[0]
    annun.b.util_power_R = B747DR_elec_light_util_off[1]

    -- BATTERY
    annun.b.battery_off = B747_ternary((B747DR_button_switch_position[13] < 0.5), 1, 0)

    -- EXTERNAL POWER
    annun.b.ext_pwr_avail_01 = B747DR_elec_light_ext_avail[0]
    annun.b.ext_pwr_avail_02 = B747DR_elec_light_ext_avail[1]

    -- APU GENERATOR
    annun.b.apu_gen_avail_01 = B747DR_elec_light_apu_avail[0]
    annun.b.apu_gen_avail_02 = B747DR_elec_light_apu_avail[1]

    -- BUS TIE (ISLN)
    annun.b.bus_tie_01 = B747DR_elec_light_isln[0]
    annun.b.bus_tie_02 = B747DR_elec_light_isln[1]
    annun.b.bus_tie_03 = B747DR_elec_light_isln[2]
    annun.b.bus_tie_04 = B747DR_elec_light_isln[3]

    -- GENERATOR CONTROL (OFF)
    annun.b.gen_ctrl_off_01 = B747DR_elec_light_gen_off[0]
    annun.b.gen_ctrl_off_02 = B747DR_elec_light_gen_off[1]
    annun.b.gen_ctrl_off_03 = B747DR_elec_light_gen_off[2]
    annun.b.gen_ctrl_off_04 = B747DR_elec_light_gen_off[3]

    -- GENERATOR DRIVE
    annun.b.gen_drive_disc_01 = B747DR_elec_light_drive[0]
    annun.b.gen_drive_disc_02 = B747DR_elec_light_drive[1]
    annun.b.gen_drive_disc_03 = B747DR_elec_light_drive[2]
    annun.b.gen_drive_disc_04 = B747DR_elec_light_drive[3]

    -- HYDRAULIC PUMP
    -- ENGINE PRESS: the engine pump's pressure low for 2 s (FCOM p.1484)
    annun.b.hyd_pump_01 = B747DR_light_hyd_eng_press[0]
    annun.b.hyd_pump_02 = B747DR_light_hyd_eng_press[1]
    annun.b.hyd_pump_03 = B747DR_light_hyd_eng_press[2]
    annun.b.hyd_pump_04 = B747DR_light_hyd_eng_press[3]

    -- CARGO FIRE
    annun.b.cargo_fire_fwd = B747DR_fire_light_cargo[0]      -- fire or test (FCOM p.908)
    annun.b.cargo_fire_aft = B747DR_fire_light_cargo[1]
    annun.b.cargo_fire_disch = B747DR_fire_light_cargo[2]    -- bottles discharged

    -- FUEL SYSTEM: the lights come from the fuel model (fuel module,
    -- laminar/B747/fuel/light/*; FCOM p.1439-1441, ATA26_28 p.414)
    -- FUEL JETTISON NOZZLE VALVE
    annun.b.fuel_jett_valve_L = B747DR_fuel_light_nozzle_valve[0]
    annun.b.fuel_jett_valve_R = B747DR_fuel_light_nozzle_valve[1]
    -- X FEED VALVE
    annun.b.fuel_xfeed_01 = B747DR_fuel_light_xfeed_valve[0]
    annun.b.fuel_xfeed_02 = B747DR_fuel_light_xfeed_valve[1]
    annun.b.fuel_xfeed_03 = B747DR_fuel_light_xfeed_valve[2]
    annun.b.fuel_xfeed_04 = B747DR_fuel_light_xfeed_valve[3]
    -- PUMP PRESS, in the order of B747_fuel_model.PUMPS
    annun.b.fuel_pump_main_fwd_01 = B747DR_fuel_light_pump_press[0]
    annun.b.fuel_pump_main_aft_01 = B747DR_fuel_light_pump_press[1]
    annun.b.fuel_pump_main_fwd_02 = B747DR_fuel_light_pump_press[2]
    annun.b.fuel_pump_main_aft_02 = B747DR_fuel_light_pump_press[3]
    annun.b.fuel_pump_main_fwd_03 = B747DR_fuel_light_pump_press[4]
    annun.b.fuel_pump_main_aft_03 = B747DR_fuel_light_pump_press[5]
    annun.b.fuel_pump_main_fwd_04 = B747DR_fuel_light_pump_press[6]
    annun.b.fuel_pump_main_aft_04 = B747DR_fuel_light_pump_press[7]
    annun.b.fuel_pump_main_ovrd_fwd_02 = B747DR_fuel_light_pump_press[8]
    annun.b.fuel_pump_main_ovrd_aft_02 = B747DR_fuel_light_pump_press[9]
    annun.b.fuel_pump_main_ovrd_fwd_03 = B747DR_fuel_light_pump_press[10]
    annun.b.fuel_pump_main_ovrd_aft_03 = B747DR_fuel_light_pump_press[11]
    annun.b.fuel_pump_center_L = B747DR_fuel_light_pump_press[12]
    annun.b.fuel_pump_center_R = B747DR_fuel_light_pump_press[13]
    annun.b.fuel_pump_stab_L = B747DR_fuel_light_pump_press[14]
    annun.b.fuel_pump_stab_R = B747DR_fuel_light_pump_press[15]

    -- ANTI-ICE: the anti-ice model's lights (B747.50.xt.antiice.lua): the
    -- valves not where commanded, the windshields without heat (FCOM
    -- p.625-628)
    annun.b.anti_ice_nacelle_heat_01 = B747DR_antiice_light_nai_valve[0]
    annun.b.anti_ice_nacelle_heat_02 = B747DR_antiice_light_nai_valve[1]
    annun.b.anti_ice_nacelle_heat_03 = B747DR_antiice_light_nai_valve[2]
    annun.b.anti_ice_nacelle_heat_04 = B747DR_antiice_light_nai_valve[3]
    annun.b.anti_ice_wing_heat = B747DR_antiice_light_wai_valve
    annun.b.anti_ice_window_heat_L = B747DR_antiice_light_window_inop[0]
    annun.b.anti_ice_window_heat_R = B747DR_antiice_light_window_inop[1]

    -- YAW DAMPER
    annun.b.yaw_damper_upper = B747_ternary((B747DR_yaw_damper_upr_on == 0), 1, 0)
    annun.b.yaw_damper_lower = B747_ternary((B747DR_yaw_damper_lwr_on == 0), 1, 0)

    -- TEMPERATURE
    annun.b.temp_zone_reset = B747DR_light_zone_sys_fault       -- TRIM AIR off, overheat, valve closed (FCOM p.555)
    annun.b.temp_aft_cargo_heat = B747DR_light_aft_cargo_temp   -- aft cargo overheat, in the air (FCOM p.557)
    annun.b.temp_pack_reset = B747DR_light_pack_sys_fault     -- a pack tripped (FCOM p.560)

    -- BLEED AIR
    -- VALVE lights: the valve moving or not where commanded (FCOM p.576)
    annun.b.bleed_air_isolation_L = B747DR_light_bleed_isln_valve[0]
    annun.b.bleed_air_isolation_R = B747DR_light_bleed_isln_valve[1]
    annun.b.apu_bleed_air = B747DR_light_bleed_apu_valve

    annun.b.engine_bleed_air_01 = B747_ternary((B747DR_bleed_air_engine1_vlv_pos == 0.0), 1, 0)
    annun.b.engine_bleed_air_02 = B747_ternary((B747DR_bleed_air_engine2_vlv_pos == 0.0), 1, 0)
    annun.b.engine_bleed_air_03 = B747_ternary((B747DR_bleed_air_engine3_vlv_pos == 0.0), 1, 0)
    annun.b.engine_bleed_air_04 = B747_ternary((B747DR_bleed_air_engine4_vlv_pos == 0.0), 1, 0)








    -- FIXED  ----------------------------------------------------------------------

    ----- MAIN PANEL -----

    -- BRAKE SOURCE LOW PRESS           simDR_hyd_press_01
    annun.a.brake_source = B747DR_light_hyd_brake_source


    ----- OVERHEAD PANEL -----

    -- FLIGHT CONTROL HYDRAULIC POWER VALVES: VALVE CLOSED while the valve is
    -- not fully open (FCOM p.940; the hydraulics module moves them. Before,
    -- always out: 4-1 step 4)
    annun.a.flt_ctl_hyd_vlv_wing_01 = B747_ternary((B747DR_lt_fcsov_wing_valve[0] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_wing_02 = B747_ternary((B747DR_lt_fcsov_wing_valve[1] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_wing_03 = B747_ternary((B747DR_lt_fcsov_wing_valve[2] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_wing_04 = B747_ternary((B747DR_lt_fcsov_wing_valve[3] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_tail_01 = B747_ternary((B747DR_lt_fcsov_tail_valve[0] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_tail_02 = B747_ternary((B747DR_lt_fcsov_tail_valve[1] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_tail_03 = B747_ternary((B747DR_lt_fcsov_tail_valve[2] > 0), 1, 0)
    annun.a.flt_ctl_hyd_vlv_tail_04 = B747_ternary((B747DR_lt_fcsov_tail_valve[3] > 0), 1, 0)

    -- GEN FIELD
    annun.a.eng_gen_field_01 = 0
    annun.a.eng_gen_field_02 = 0
    annun.a.eng_gen_field_03 = 0
    annun.a.eng_gen_field_04 = 0
    annun.a.apu_gen_field_01 = 0
    annun.a.apu_gen_field_02 = 0
    annun.a.split_sys_breaker = 0

    -- SQUIB TEST
    annun.a.squib_test_eng_01 = B747DR_fire_light_squib[0]   -- SQUIB TEST 1, 2 (FCOM p.187-188)
    annun.a.squib_test_eng_02 = B747DR_fire_light_squib[1]
    annun.a.squib_test_eng_03 = B747DR_fire_light_squib[2]
    annun.a.squib_test_eng_04 = B747DR_fire_light_squib[3]
    annun.a.squib_test_apu = B747DR_fire_light_squib[4]
    annun.a.squib_test_cargo_A = B747DR_fire_light_squib[5]
    annun.a.squib_test_cargo_B = B747DR_fire_light_squib[6]
    annun.a.squib_test_cargo_C = B747DR_fire_light_squib[7]
    annun.a.squib_test_cargo_D = B747DR_fire_light_squib[8]

    -- IRS: an IRU on DC on the ground without the ground service bus (FCOM p.1217)
    annun.a.irs_on_bat = B747DR_irs_on_bat

    -- HYDRAULIC SYSTEM FAULT
    annun.a.hyd_sys_fault_01 = B747DR_light_hyd_sys_fault[0]
    annun.a.hyd_sys_fault_02 = B747DR_light_hyd_sys_fault[1]
    annun.a.hyd_sys_fault_03 = B747DR_light_hyd_sys_fault[2]
    annun.a.hyd_sys_fault_04 = B747DR_light_hyd_sys_fault[3]

    -- HYDRAULIC DEMAND PUMP PRESS LOW              -- TODO:  ADD CONDITIONS:  DEMAND PUMP PRESS LOW / DEMAND PUMP FAIL
    annun.a.demand_pump_press_01 = B747DR_light_hyd_dem_press[0]
    annun.a.demand_pump_press_02 = B747DR_light_hyd_dem_press[1]
    annun.a.demand_pump_press_03 = B747DR_light_hyd_dem_press[2]
    annun.a.demand_pump_press_04 = B747DR_light_hyd_dem_press[3]

    -- FIRE EXTINGUISHER BOTTLE DISCHARGE
    annun.a.fire_bottle_0102A_disch = B747DR_fire_light_btl_disch[0]     -- discharged or low (FCOM p.905, p.907)
    annun.a.fire_bottle_0102B_disch = B747DR_fire_light_btl_disch[1]
    annun.a.fire_bottle_0304A_disch = B747DR_fire_light_btl_disch[2]
    annun.a.fire_bottle_0304B_disch = B747DR_fire_light_btl_disch[3]
    annun.a.fire_bottle_APU_disch = B747DR_fire_light_btl_disch[4]

    -- ENGINE BLEED AIR SYS FAULT
    annun.a.eng_bleed_air_sys_fault_01 = B747DR_light_bleed_sys_fault[0]
    annun.a.eng_bleed_air_sys_fault_02 = B747DR_light_bleed_sys_fault[1]
    annun.a.eng_bleed_air_sys_fault_03 = B747DR_light_bleed_sys_fault[2]
    annun.a.eng_bleed_air_sys_fault_04 = B747DR_light_bleed_sys_fault[3]

    -- START SWITCHES
    annun.a.start_vlv_open_01 = B747DR_bleed_air_engine1_start_valve_pos
    annun.a.start_vlv_open_02 = B747DR_bleed_air_engine2_start_valve_pos
    annun.a.start_vlv_open_03 = B747DR_bleed_air_engine3_start_valve_pos
    annun.a.start_vlv_open_04 = B747DR_bleed_air_engine4_start_valve_pos



    ----- PEDESTAL ----
    
    -- RADIO TUNING PANELS
    annun.a.rtp_L_offside_tuning = B747DR_rtp_L_offside_tuning_status
    annun.a.rtp_L_off = B747DR_rtp_L_off_status
    annun.a.rtp_L_vhf_L = B747DR_rtp_L_vhf_L_status
    annun.a.rtp_L_vhf_C = B747DR_rtp_L_vhf_C_status
    annun.a.rtp_L_vhf_R = B747DR_rtp_L_vhf_R_status
    annun.a.rtp_L_hf_L = B747DR_rtp_L_hf_L_status
    annun.a.rtp_L_am = B747DR_rtp_L_am_status
    annun.a.rtp_L_hf_R = B747DR_rtp_L_hf_R_status

    annun.a.rtp_R_offside_tuning = B747DR_rtp_R_offside_tuning_status
    annun.a.rtp_R_off = B747DR_rtp_R_off_status
    annun.a.rtp_R_vhf_L = B747DR_rtp_R_vhf_L_status
    annun.a.rtp_R_vhf_C = B747DR_rtp_R_vhf_C_status
    annun.a.rtp_R_vhf_R = B747DR_rtp_R_vhf_R_status
    annun.a.rtp_R_hf_L = B747DR_rtp_R_hf_L_status
    annun.a.rtp_R_am = B747DR_rtp_R_am_status
    annun.a.rtp_R_hf_R = B747DR_rtp_R_hf_R_status

    annun.a.rtp_C_offside_tuning = B747DR_rtp_C_offside_tuning_status
    annun.a.rtp_C_off = B747DR_rtp_C_off_status
    annun.a.rtp_C_vhf_L = B747DR_rtp_C_vhf_L_status
    annun.a.rtp_C_vhf_C = B747DR_rtp_C_vhf_C_status
    annun.a.rtp_C_vhf_R = B747DR_rtp_C_vhf_R_status
    annun.a.rtp_C_hf_L = B747DR_rtp_C_hf_L_status
    annun.a.rtp_C_am = B747DR_rtp_C_am_status
    annun.a.rtp_C_hf_R = B747DR_rtp_C_hf_R_status


    -- AUDIO PANEL L
    annun.a.ap_L_vhf_L_xmt = B747DR_ap_L_vhf_L_xmt_status
    annun.a.ap_L_vhf_C_xmt = B747DR_ap_L_vhf_C_xmt_status
    annun.a.ap_L_vhf_R_xmt = B747DR_ap_L_vhf_R_xmt_status
    annun.a.ap_L_flt_xmt = B747DR_ap_L_flt_xmt_status
    annun.a.ap_L_cab_xmt = B747DR_ap_L_cab_xmt_status
    annun.a.ap_L_pa_xmt = B747DR_ap_L_pa_xmt_status
    annun.a.ap_L_hf_L_xmt = B747DR_ap_L_hf_L_xmt_status
    annun.a.ap_L_hf_R_xmt = B747DR_ap_L_hf_R_xmt_status
    annun.a.ap_L_sat_L_xmt = B747DR_ap_L_sat_L_xmt_status
    annun.a.ap_L_sat_R_xmt = B747DR_ap_L_sat_R_xmt_status

    annun.a.ap_L_vhf_L_audio = B747DR_ap_L_vhf_L_audio_status
    annun.a.ap_L_vhf_C_audio = B747DR_ap_L_vhf_C_audio_status
    annun.a.ap_L_vhf_R_audio = B747DR_ap_L_vhf_R_audio_status
    annun.a.ap_L_flt_audio = B747DR_ap_L_flt_audio_status
    annun.a.ap_L_cab_audio = B747DR_ap_L_cab_audio_status
    annun.a.ap_L_pa_audio = B747DR_ap_L_pa_audio_status
    annun.a.ap_L_hf_L_audio = B747DR_ap_L_hf_L_audio_status
    annun.a.ap_L_hf_R_audio = B747DR_ap_L_hf_R_audio_status
    annun.a.ap_L_sat_L_audio = B747DR_ap_L_sat_L_audio_status
    annun.a.ap_L_sat_R_audio = B747DR_ap_L_sat_R_udio_status
    annun.a.ap_L_spkr_audio = B747DR_ap_L_spkr_audio_status
    annun.a.ap_L_vor_adf_audio = B747DR_ap_L_vor_adf_audio_status
    annun.a.ap_L_app_mkr_audio = B747DR_ap_L_app_mkr_audio_status

    annun.a.ap_L_vhf_L_call = B747DR_ap_L_vhf_L_call_status
    annun.a.ap_L_vhf_C_call = B747DR_ap_L_vhf_C_call_status
    annun.a.ap_L_vhf_R_call = B747DR_ap_L_vhf_R_call_status
    annun.a.ap_L_flt_call = B747DR_ap_L_flt_call_status
    annun.a.ap_L_cab_call = B747DR_ap_L_cab_call_status
    annun.a.ap_L_hf_L_call = B747DR_ap_L_hf_L_call_status
    annun.a.ap_L_hf_R_call = B747DR_ap_L_hf_R_call_status
    annun.a.ap_L_sat_L_call = B747DR_ap_L_sat_L_call_status
    annun.a.ap_L_sat_R_call = B747DR_ap_L_sat_R_call_status


    -- AUDIO PANEL C
    annun.a.ap_C_vhf_L_xmt = B747DR_ap_C_vhf_L_xmt_status
    annun.a.ap_C_vhf_C_xmt = B747DR_ap_C_vhf_C_xmt_status
    annun.a.ap_C_vhf_R_xmt = B747DR_ap_C_vhf_R_xmt_status
    annun.a.ap_C_flt_xmt = B747DR_ap_C_flt_xmt_status
    annun.a.ap_C_cab_xmt = B747DR_ap_C_cab_xmt_status
    annun.a.ap_C_pa_xmt = B747DR_ap_C_pa_xmt_status
    annun.a.ap_C_hf_L_xmt = B747DR_ap_C_hf_L_xmt_status
    annun.a.ap_C_hf_R_xmt = B747DR_ap_C_hf_R_xmt_status
    annun.a.ap_C_sat_L_xmt = B747DR_ap_C_sat_L_xmt_status
    annun.a.ap_C_sat_R_xmt = B747DR_ap_C_sat_R_xmt_status

    annun.a.ap_C_vhf_L_audio = B747DR_ap_C_vhf_L_audio_status
    annun.a.ap_C_vhf_C_audio = B747DR_ap_C_vhf_C_audio_status
    annun.a.ap_C_vhf_R_audio = B747DR_ap_C_vhf_R_audio_status
    annun.a.ap_C_flt_audio = B747DR_ap_C_flt_audio_status
    annun.a.ap_C_cab_audio = B747DR_ap_C_cab_audio_status
    annun.a.ap_C_pa_audio = B747DR_ap_C_pa_audio_status
    annun.a.ap_C_hf_L_audio = B747DR_ap_C_hf_L_audio_status
    annun.a.ap_C_hf_R_audio = B747DR_ap_C_hf_R_audio_status
    annun.a.ap_C_sat_L_audio = B747DR_ap_C_sat_L_audio_status
    annun.a.ap_C_sat_R_audio = B747DR_ap_C_sat_R_udio_status
    annun.a.ap_C_spkr_audio = B747DR_ap_C_spkr_audio_status
    annun.a.ap_C_vor_adf_audio = B747DR_ap_C_vor_adf_audio_status
    annun.a.ap_C_app_mkr_audio = B747DR_ap_C_app_mkr_audio_status

    annun.a.ap_C_vhf_L_call = B747DR_ap_C_vhf_L_call_status
    annun.a.ap_C_vhf_C_call = B747DR_ap_C_vhf_C_call_status
    annun.a.ap_C_vhf_R_call = B747DR_ap_C_vhf_R_call_status
    annun.a.ap_C_flt_call = B747DR_ap_C_flt_call_status
    annun.a.ap_C_cab_call = B747DR_ap_C_cab_call_status
    annun.a.ap_C_hf_L_call = B747DR_ap_C_hf_L_call_status
    annun.a.ap_C_hf_R_call = B747DR_ap_C_hf_R_call_status
    annun.a.ap_C_sat_L_call = B747DR_ap_C_sat_L_call_status
    annun.a.ap_C_sat_R_call = B747DR_ap_C_sat_R_call_status


    -- AUDIO PANEL R
    annun.a.ap_R_vhf_L_xmt = B747DR_ap_R_vhf_L_xmt_status
    annun.a.ap_R_vhf_C_xmt = B747DR_ap_R_vhf_C_xmt_status
    annun.a.ap_R_vhf_R_xmt = B747DR_ap_R_vhf_R_xmt_status
    annun.a.ap_R_flt_xmt = B747DR_ap_R_flt_xmt_status
    annun.a.ap_R_cab_xmt = B747DR_ap_R_cab_xmt_status
    annun.a.ap_R_pa_xmt = B747DR_ap_R_pa_xmt_status
    annun.a.ap_R_hf_L_xmt = B747DR_ap_R_hf_L_xmt_status
    annun.a.ap_R_hf_R_xmt = B747DR_ap_R_hf_R_xmt_status
    annun.a.ap_R_sat_L_xmt = B747DR_ap_R_sat_L_xmt_status
    annun.a.ap_R_sat_R_xmt = B747DR_ap_R_sat_R_xmt_status

    annun.a.ap_R_vhf_L_audio = B747DR_ap_R_vhf_L_audio_status
    annun.a.ap_R_vhf_C_audio = B747DR_ap_R_vhf_C_audio_status
    annun.a.ap_R_vhf_R_audio = B747DR_ap_R_vhf_R_audio_status
    annun.a.ap_R_flt_audio = B747DR_ap_R_flt_audio_status
    annun.a.ap_R_cab_audio = B747DR_ap_R_cab_audio_status
    annun.a.ap_R_pa_audio = B747DR_ap_R_pa_audio_status
    annun.a.ap_R_hf_L_audio = B747DR_ap_R_hf_L_audio_status
    annun.a.ap_R_hf_R_audio = B747DR_ap_R_hf_R_audio_status
    annun.a.ap_R_sat_L_audio = B747DR_ap_R_sat_L_audio_status
    annun.a.ap_R_sat_R_audio = B747DR_ap_R_sat_R_udio_status
    annun.a.ap_R_spkr_audio = B747DR_ap_R_spkr_audio_status
    annun.a.ap_R_vor_adf_audio = B747DR_ap_R_vor_adf_audio_status
    annun.a.ap_R_app_mkr_audio = B747DR_ap_R_app_mkr_audio_status

    annun.a.ap_R_vhf_L_call = B747DR_ap_R_vhf_L_call_status
    annun.a.ap_R_vhf_C_call = B747DR_ap_R_vhf_C_call_status
    annun.a.ap_R_vhf_R_call = B747DR_ap_R_vhf_R_call_status
    annun.a.ap_R_flt_call = B747DR_ap_R_flt_call_status
    annun.a.ap_R_cab_call = B747DR_ap_R_cab_call_status
    annun.a.ap_R_hf_L_call = B747DR_ap_R_hf_L_call_status
    annun.a.ap_R_hf_R_call = B747DR_ap_R_hf_R_call_status
    annun.a.ap_R_sat_L_call = B747DR_ap_R_sat_L_call_status
    annun.a.ap_R_sat_R_call = B747DR_ap_R_sat_R_call_status


    -- CALL PANEL
    annun.a.call_pnl_ud_call = B747DR_call_pnl_ud_call_status
    annun.a.call_pnl_crw_rst_L_call = B747DR_call_pnl_crw_rst_L_call_status
    annun.a.call_pnl_crw_rst_R_call = B747DR_call_pnl_crw_rst_R_call_status
    annun.a.call_pnl_cargo_call = B747DR_call_pnl_cargo_call_status
    annun.a.call_pnl_grnd_call = B747DR_call_pnl_grnd_call_status


    -- SAFETY
    annun.a.no_smoking = B747_ternary(
        (
            (B747DR_sfty_no_smoke_sel_dial_pos == 2)            -- "ON" POSITION
            or
        (
       
        (B747DR_sfty_no_smoke_sel_dial_pos == 1)            -- "AUTO" POSITION
        )

        and

        (
        (simDR_gear_deploy_ratio[0] > 0) or                 --|
        (simDR_gear_deploy_ratio[1] > 0) or                 --|
        (simDR_gear_deploy_ratio[2] > 0) or                 -- GEAR NOT UP
        (simDR_gear_deploy_ratio[3] > 0) or                 --|
        (simDR_gear_deploy_ratio[4] > 0) or                 --|
        (simDR_cabin_altitude > 10000.0)                    -- CABIN ALTITUDE IS GREATER THAN 10,000 FEET
        )
            or
        (B747DR_oxy_pass_on == 1)                           -- PASSENGER OXYGEN ON, ANY POSITION (FCOM p.437, p.502)

        ), 1, 0)
    simDR_cockpit2_no_smoking_switch  = B747_ternary((annun.a.no_smoking == 1), 1, 0)       -- SET THE SIM ANNUNCIATOR



    annun.a.seat_belts = B747_ternary(
        (
            (B747DR_sfty_seat_belts_sel_dial_pos == 2)          -- "ON" POSITION
            or
        (
        
        (B747DR_sfty_seat_belts_sel_dial_pos == 1)          -- "AUTO" POSITION
        )

        and

        (
        (simDR_gear_deploy_ratio[0] > 0) or                 --|
        (simDR_gear_deploy_ratio[1] > 0) or                 --|
        (simDR_gear_deploy_ratio[2] > 0) or                 -- GEAR NOT UP
        (simDR_gear_deploy_ratio[3] > 0) or                 --|
        (simDR_gear_deploy_ratio[4] > 0) or                 --|
        (simDR_aircraft_altitude < 10300.0) or              -- AIRCRAFT ALTITUDE IS LESS THAN 10,300 FEET
        (simDR_cabin_altitude > 10000.0) or                 -- CABIN ALTITUDE IS GREATER THAN 10,000 FEET
        (simDR_flap_ratio_control > 0)                      -- FLAP LEVER IS NOT UP
        )
            or
        (B747DR_oxy_pass_on == 1)                           -- PASSENGER OXYGEN ON, ANY POSITION (FCOM p.437, p.502)

        ), 1, 0)
    simDR_cockpit2_seat_belt_switch = B747_ternary((annun.a.seat_belts == 1), 1, 0)         -- SET THE SIM ANNUNCIATOR






    -- MCP AUTOPILOT BUTTON SWITCHES ---------------------------------------------
	--annun.b.ap_thrust 	= B747_ternary(B747DR_engine_TOGA_mode >0 , 1, 0)
    annun.b.ap_thrust 	= B747_ternary(B747DR_ap_FMA_autothrottle_mode==5 and (simDR_autopilot_vs_status == 2 or simDR_autopilot_alt_hold_status == 2) , 1, 0)
    -- the MCP's lights (FCOM p.642, p.645-650): LNAV and VNAV armed or
    -- active, the others their mode active. VNAV engaged puts out SPD,
    -- FLCH, V/S and ALT HOLD (the old VNAV sets the old law's flags for its
    -- sub-modes), its arm does not (the active mode stays: 6-3 step 1c)
    annun.b.ap_speed 	= B747_ternary(B747DR_ap_FMA_autothrottle_mode==3 and B747DR_ap_vnav_state < 2, 1, 0)
    annun.b.ap_lnav 	= B747_ternary(B747DR_ap_lnav_state>0, 1, 0)
    annun.b.ap_vnav 	= B747_ternary(simDR_autopilot_fms_vnav_status > 0 or B747DR_ap_vnav_state>0, 1, 0)
    annun.b.ap_fl_ch 	= B747_ternary(B747DR_ap_FMA_active_pitch_mode == 8 and simDR_autopilot_fms_vnav_status < 1 and B747DR_ap_vnav_state < 2, 1, 0)
    annun.b.ap_hdg_hold	= B747_ternary(B747DR_ap_FMA_active_roll_mode == 7 or B747DR_ap_FMA_active_roll_mode == 5, 1, 0)
    annun.b.ap_vs 		= B747_ternary(simDR_autopilot_vs_status == 2 and simDR_autopilot_fms_vnav_status < 1 and B747DR_ap_vnav_state < 2 and simDR_autopilot_alt_hold_status==0 and B747DR_autopilot_gs_status < 2, 1, 0)
    annun.b.ap_alt_hold = B747_ternary(simDR_autopilot_alt_hold_status == 2 and simDR_autopilot_fms_vnav_status < 1 and B747DR_ap_vnav_state < 2 and B747DR_autopilot_gs_status < 2, 1, 0)
    annun.b.ap_app 		= B747_ternary((B747DR_autopilot_nav_status > 0 and B747DR_autopilot_gs_status > 0) or B747DR_ap_approach_mode>0, 1, 0)
    annun.b.ap_loc 		= B747_ternary((B747DR_autopilot_nav_status > 0 or B747DR_ap_approach_mode<0) and annun.b.ap_app == 0, 1, 0) --test this
    annun.b.ap_CMD_L 	= B747_ternary((B747DR_autopilot_cmd_L_status == 1 and simDR_autopilot_servos_on == 1) or B747DR_autopilot_cmd_armed[0] == 1, 1, 0)
    annun.b.ap_CMD_C 	= B747_ternary((B747DR_autopilot_cmd_C_status == 1 and simDR_autopilot_servos_on == 1) or B747DR_autopilot_cmd_armed[1] == 1, 1, 0)
    annun.b.ap_CMD_R 	= B747_ternary((B747DR_autopilot_cmd_R_status == 1 and simDR_autopilot_servos_on == 1) or B747DR_autopilot_cmd_armed[2] == 1, 1, 0)
    
    
end





----- ANNUNCIATORS (IND LTS) -----------------------------------------------------
-- (7-2c; notes/ATA-33.md §13) each indicator light: its condition (annun.a
-- and annun.b from B747_annunciators) or the TEST, times the master dim and
-- test's level (B747.90.ind_model.lua: BRT, DIM, TEST bright and dimmed
-- after 10 s, STORM bright, its power from the battery bus or DC bus 1 or
-- 3). Before, 270 lines of one expression: TEST 1.0 while held, STORM left
-- the lights dim, the power X-Plane's bus volts and generic light 63
dofile("B747.90.ind_model.lua")
B747DR_ind_bus_dc = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_ind_bus_bat = find_dataref("laminar/B747/electrical/bus/bat_main")
simDR_ind_time = find_dataref("sim/time/total_running_time_sec")
-- annunciator -> its condition: annun.<a or b>.<key>
local IND_ANNUN = {
    ----- MAIN PANEL -----
    -- GROUND PROXIMITY
    [2] = "b.gpws",
    -- GLIDESLOPE INHIBIT
    [3] = "b.gs_inhibit",
    ----- OVERHEAD PANEL -----
    -- ELECTRONIC ENGING CONTROL
    [4] = "b.el_eng_ctrl_01",
    [5] = "b.el_eng_ctrl_02",
    [6] = "b.el_eng_ctrl_03",
    [7] = "b.el_eng_ctrl_04",
    -- ELECTRIC UTILITY POWER
    [8] = "b.util_power_L",
    [9] = "b.util_power_R",
    -- BATTERY
    [10] = "b.battery_off",
    -- BUS TIE
    [19] = "b.bus_tie_01",
    [20] = "b.bus_tie_02",
    [21] = "b.bus_tie_03",
    [22] = "b.bus_tie_04",
    -- GENERATOR CONTROL
    [23] = "b.gen_ctrl_off_01",
    [24] = "b.gen_ctrl_off_02",
    [25] = "b.gen_ctrl_off_03",
    [26] = "b.gen_ctrl_off_04",
    -- GENERATOR DRIVE DISC
    [27] = "b.gen_drive_disc_01",
    [28] = "b.gen_drive_disc_02",
    [29] = "b.gen_drive_disc_03",
    [30] = "b.gen_drive_disc_04",
    -- HYDRAULIC PUMP
    [31] = "b.hyd_pump_01",
    [32] = "b.hyd_pump_02",
    [33] = "b.hyd_pump_03",
    [34] = "b.hyd_pump_04",
    -- CARGO FIRE
    [35] = "b.cargo_fire_fwd",
    [36] = "b.cargo_fire_aft",
    [37] = "b.cargo_fire_disch",
    -- FUEL JETTISON VALVE
    [38] = "b.fuel_jett_valve_L",
    [39] = "b.fuel_jett_valve_R",
    -- FUEL SYSTEM
    [40] = "b.fuel_xfeed_01",
    [41] = "b.fuel_xfeed_02",
    [42] = "b.fuel_xfeed_03",
    [43] = "b.fuel_xfeed_04",
    [44] = "b.fuel_pump_center_L",
    [45] = "b.fuel_pump_center_R",
    [46] = "b.fuel_pump_stab_L",
    [47] = "b.fuel_pump_stab_R",
    [48] = "b.fuel_pump_main_fwd_01",
    [49] = "b.fuel_pump_main_fwd_02",
    [50] = "b.fuel_pump_main_fwd_03",
    [51] = "b.fuel_pump_main_fwd_04",
    [52] = "b.fuel_pump_main_aft_01",
    [53] = "b.fuel_pump_main_aft_02",
    [54] = "b.fuel_pump_main_aft_03",
    [55] = "b.fuel_pump_main_aft_04",
    [56] = "b.fuel_pump_main_ovrd_fwd_02",
    [57] = "b.fuel_pump_main_ovrd_fwd_03",
    [58] = "b.fuel_pump_main_ovrd_aft_02",
    [59] = "b.fuel_pump_main_ovrd_aft_03",
    -- ANTI-ICE
    [60] = "b.anti_ice_nacelle_heat_01",
    [61] = "b.anti_ice_nacelle_heat_02",
    [62] = "b.anti_ice_nacelle_heat_03",
    [63] = "b.anti_ice_nacelle_heat_04",
    [64] = "b.anti_ice_wing_heat",
    [65] = "b.anti_ice_window_heat_L",
    [66] = "b.anti_ice_window_heat_R",
    -- YAW DAMPER
    [67] = "b.yaw_damper_upper",
    [68] = "b.yaw_damper_lower",
    -- TEMPERATURE
    [69] = "b.temp_zone_reset",
    [70] = "b.temp_aft_cargo_heat",
    [71] = "b.temp_pack_reset",
    -- BLEED AIR
    [72] = "b.bleed_air_isolation_L",
    [73] = "b.bleed_air_isolation_R",
    [74] = "b.apu_bleed_air",
    [75] = "b.engine_bleed_air_01",
    [76] = "b.engine_bleed_air_02",
    [77] = "b.engine_bleed_air_03",
    [78] = "b.engine_bleed_air_04",
    -- FIXED  -------------------------------------------------------------------
    ----- MAIN PANEL -----
    -- BRAKE SOURCE LOW PRESS
    [79] = "a.brake_source",
    ----- OVERHEAD PANEL -----
    -- FLIGHT CONTROL HYDRAULIC VALVES
    [80] = "a.flt_ctl_hyd_vlv_wing_01",
    [81] = "a.flt_ctl_hyd_vlv_wing_02",
    [82] = "a.flt_ctl_hyd_vlv_wing_03",
    [83] = "a.flt_ctl_hyd_vlv_wing_04",
    [84] = "a.flt_ctl_hyd_vlv_tail_01",
    [85] = "a.flt_ctl_hyd_vlv_tail_02",
    [86] = "a.flt_ctl_hyd_vlv_tail_03",
    [87] = "a.flt_ctl_hyd_vlv_tail_04",
    -- GEN FIELD
    [88] = "a.eng_gen_field_01",
    [89] = "a.eng_gen_field_02",
    [90] = "a.eng_gen_field_03",
    [91] = "a.eng_gen_field_04",
    [92] = "a.apu_gen_field_01",
    [93] = "a.apu_gen_field_02",
    [94] = "a.split_sys_breaker",
    -- SQUIB TEST
    [95] = "a.squib_test_eng_01",
    [96] = "a.squib_test_eng_02",
    [97] = "a.squib_test_eng_03",
    [98] = "a.squib_test_eng_04",
    [99] = "a.squib_test_apu",
    [100] = "a.squib_test_cargo_A",
    [101] = "a.squib_test_cargo_B",
    [102] = "a.squib_test_cargo_C",
    [103] = "a.squib_test_cargo_D",
    -- IRS
    [104] = "a.irs_on_bat",
    -- HYDRAULIC SYSTEM FAULT
    [105] = "a.hyd_sys_fault_01",
    [106] = "a.hyd_sys_fault_02",
    [107] = "a.hyd_sys_fault_03",
    [108] = "a.hyd_sys_fault_04",
    -- HYDRAULIC DEMAND PUMP PRESS LOW
    [109] = "a.demand_pump_press_01",
    [110] = "a.demand_pump_press_02",
    [111] = "a.demand_pump_press_03",
    [112] = "a.demand_pump_press_04",
    -- FIRE EXTINGUISHER BOTTLE DISCHARGE
    [113] = "a.fire_bottle_0102A_disch",
    [114] = "a.fire_bottle_0102B_disch",
    [115] = "a.fire_bottle_0304A_disch",
    [116] = "a.fire_bottle_0304B_disch",
    [117] = "a.fire_bottle_APU_disch",
    -- ENGINE BLEED AIR SYS FAULT
    [118] = "a.eng_bleed_air_sys_fault_01",
    [119] = "a.eng_bleed_air_sys_fault_02",
    [120] = "a.eng_bleed_air_sys_fault_03",
    [121] = "a.eng_bleed_air_sys_fault_04",
    -- START SWITCH (START VALVE OPEN)
    [122] = "a.start_vlv_open_01",
    [123] = "a.start_vlv_open_02",
    [124] = "a.start_vlv_open_03",
    [125] = "a.start_vlv_open_04",
    ----- PEDESTAL PANEL -----
    -- RADIO TUNING PANEL LEFT
    [126] = "a.rtp_L_offside_tuning",
    [127] = "a.rtp_L_off",
    [128] = "a.rtp_L_vhf_L",
    [129] = "a.rtp_L_vhf_C",
    [130] = "a.rtp_L_vhf_R",
    [131] = "a.rtp_L_hf_L",
    [132] = "a.rtp_L_am",
    [133] = "a.rtp_L_hf_R",
    -- RADIO TUNING PANEL RIGHT
    [134] = "a.rtp_R_offside_tuning",
    [135] = "a.rtp_R_off",
    [136] = "a.rtp_R_vhf_L",
    [137] = "a.rtp_R_vhf_C",
    [138] = "a.rtp_R_vhf_R",
    [139] = "a.rtp_R_hf_L",
    [140] = "a.rtp_R_am",
    [141] = "a.rtp_R_hf_R",
    -- RADIO TUNING PANEL CENTER
    [142] = "a.rtp_C_offside_tuning",
    [143] = "a.rtp_C_off",
    [144] = "a.rtp_C_vhf_L",
    [145] = "a.rtp_C_vhf_C",
    [146] = "a.rtp_C_vhf_R",
    [147] = "a.rtp_C_hf_L",
    [148] = "a.rtp_C_am",
    [149] = "a.rtp_C_hf_R",
    -- AUDIO PANEL LEFT
    [150] = "a.ap_L_vhf_L_xmt",
    [151] = "a.ap_L_vhf_C_xmt",
    [152] = "a.ap_L_vhf_R_xmt",
    [153] = "a.ap_L_flt_xmt",
    [154] = "a.ap_L_cab_xmt",
    [155] = "a.ap_L_pa_xmt",
    [156] = "a.ap_L_hf_L_xmt",
    [157] = "a.ap_L_hf_R_xmt",
    [158] = "a.ap_L_sat_L_xmt",
    [159] = "a.ap_L_sat_R_xmt",
    [160] = "a.ap_L_vhf_L_audio",
    [161] = "a.ap_L_vhf_C_audio",
    [162] = "a.ap_L_vhf_R_audio",
    [163] = "a.ap_L_flt_audio",
    [164] = "a.ap_L_cab_audio",
    [165] = "a.ap_L_pa_audio",
    [166] = "a.ap_L_hf_L_audio",
    [167] = "a.ap_L_hf_R_audio",
    [168] = "a.ap_L_sat_L_audio",
    [169] = "a.ap_L_sat_R_audio",
    [170] = "a.ap_L_spkr_audio",
    [171] = "a.ap_L_vor_adf_audio",
    [172] = "a.ap_L_app_mkr_audio",
    [173] = "a.ap_L_vhf_L_call",
    [174] = "a.ap_L_vhf_C_call",
    [175] = "a.ap_L_vhf_R_call",
    [176] = "a.ap_L_flt_call",
    [177] = "a.ap_L_cab_call",
    [178] = "a.ap_L_hf_L_call",
    [179] = "a.ap_L_hf_R_call",
    [180] = "a.ap_L_sat_L_call",
    [181] = "a.ap_L_sat_R_call",
    -- AUDIO PANEL CENTER
    [182] = "a.ap_C_vhf_L_xmt",
    [183] = "a.ap_C_vhf_C_xmt",
    [184] = "a.ap_C_vhf_R_xmt",
    [185] = "a.ap_C_flt_xmt",
    [186] = "a.ap_C_cab_xmt",
    [187] = "a.ap_C_pa_xmt",
    [188] = "a.ap_C_hf_L_xmt",
    [189] = "a.ap_C_hf_R_xmt",
    [190] = "a.ap_C_sat_L_xmt",
    [191] = "a.ap_C_sat_R_xmt",
    [192] = "a.ap_C_vhf_L_audio",
    [193] = "a.ap_C_vhf_C_audio",
    [194] = "a.ap_C_vhf_R_audio",
    [195] = "a.ap_C_flt_audio",
    [196] = "a.ap_C_cab_audio",
    [197] = "a.ap_C_pa_audio",
    [198] = "a.ap_C_hf_L_audio",
    [199] = "a.ap_C_hf_R_audio",
    [200] = "a.ap_C_sat_L_audio",
    [201] = "a.ap_C_sat_R_audio",
    [202] = "a.ap_C_spkr_audio",
    [203] = "a.ap_C_vor_adf_audio",
    [204] = "a.ap_C_app_mkr_audio",
    [205] = "a.ap_C_vhf_L_call",
    [206] = "a.ap_C_vhf_C_call",
    [207] = "a.ap_C_vhf_R_call",
    [208] = "a.ap_C_flt_call",
    [209] = "a.ap_C_cab_call",
    [210] = "a.ap_C_hf_L_call",
    [211] = "a.ap_C_hf_R_call",
    [212] = "a.ap_C_sat_L_call",
    [213] = "a.ap_C_sat_R_call",
    -- AUDIO PANEL RIGHT
    [214] = "a.ap_R_vhf_L_xmt",
    [215] = "a.ap_R_vhf_C_xmt",
    [216] = "a.ap_R_vhf_R_xmt",
    [217] = "a.ap_R_flt_xmt",
    [218] = "a.ap_R_cab_xmt",
    [219] = "a.ap_R_pa_xmt",
    [220] = "a.ap_R_hf_L_xmt",
    [221] = "a.ap_R_hf_R_xmt",
    [222] = "a.ap_R_sat_L_xmt",
    [223] = "a.ap_R_sat_R_xmt",
    [224] = "a.ap_R_vhf_L_audio",
    [225] = "a.ap_R_vhf_C_audio",
    [226] = "a.ap_R_vhf_R_audio",
    [227] = "a.ap_R_flt_audio",
    [228] = "a.ap_R_cab_audio",
    [229] = "a.ap_R_pa_audio",
    [230] = "a.ap_R_hf_L_audio",
    [231] = "a.ap_R_hf_R_audio",
    [232] = "a.ap_R_sat_L_audio",
    [233] = "a.ap_R_sat_R_audio",
    [234] = "a.ap_R_spkr_audio",
    [235] = "a.ap_R_vor_adf_audio",
    [236] = "a.ap_R_app_mkr_audio",
    [237] = "a.ap_R_vhf_L_call",
    [238] = "a.ap_R_vhf_C_call",
    [239] = "a.ap_R_vhf_R_call",
    [240] = "a.ap_R_flt_call",
    [241] = "a.ap_R_cab_call",
    [242] = "a.ap_R_hf_L_call",
    [243] = "a.ap_R_hf_R_call",
    [244] = "a.ap_R_sat_L_call",
    [245] = "a.ap_R_sat_R_call",
    [246] = "a.call_pnl_ud_call",
    [247] = "a.call_pnl_crw_rst_L_call",
    [248] = "a.call_pnl_crw_rst_R_call",
    [249] = "a.call_pnl_cargo_call",
    [250] = "a.call_pnl_grnd_call",
    -- SAFETY                                                                           -- TODO:  CHANGE ATTR_light_level ON CABIN SIGNS IN BLENDER and ADD TRIGGER FOR XP SMOKE/SEAT BELT
    [251] = "a.no_smoking",
    [252] = "a.seat_belts",
    ----- MCP -----
    -- AUTOPILOT BUTTON SWITCHES
    [257] = "b.ap_thrust",
    [258] = "b.ap_speed",
    [259] = "b.ap_lnav",
    [260] = "b.ap_vnav",
    [261] = "b.ap_fl_ch",
    [262] = "b.ap_hdg_hold",
    [263] = "b.ap_vs",
    [264] = "b.ap_alt_hold",
    [265] = "b.ap_loc",
    [266] = "b.ap_app",
    [267] = "b.ap_CMD_L",
    [268] = "b.ap_CMD_C",
    [269] = "b.ap_CMD_R",
}
-- the lights the TEST leaves: the cabin signs (estimate: not the flight
-- deck's lights; ATA33 p.52, p.67)
local IND_NO_TEST = {[251] = true, [252] = true}
-- the lights DIM leaves: the cargo FIRE lights (ATA33 p.68)
local IND_NO_DIM = {[35] = true, [36] = true}
local indLights = {}
for i, k in pairs(IND_ANNUN) do
    local g, key = k:match("^(%a)%.(.+)$")
    indLights[#indLights + 1] = {i = i, group = annun[g], key = key, test = not IND_NO_TEST[i], dim = not IND_NO_DIM[i]}
end
local indState = B747_ind_model.new()
local indIn = {}
function B747_ind_lights()
    local p = B747DR_toggle_switch_position
    indIn.sel, indIn.storm, indIn.t = p[13], p[0] < 0.05, simDR_ind_time
    indIn.bat = B747DR_ind_bus_bat > 0.5
    indIn.dc1, indIn.dc3 = B747DR_ind_bus_dc[0] > 0.5, B747DR_ind_bus_dc[2] > 0.5
    local lv = B747_ind_model.update(indState, indIn)
    local lit, test = lv.lit, lv.test
    local bright = lit > 0 and B747_ind_model.BRT or 0
    for _, l in ipairs(indLights) do
        local on = (test and l.test) and 1 or l.group[l.key]
        B747DR_annun_brightness_ratio[l.i] = on * (l.dim and lit or bright)
    end
    local t = test and 1

    -- MASTER CAUTION and WARNING: darker still on DIM (as before)
    local master = lit * (lv.dim and 0.125 or 1)
    B747DR_annun_brightness_ratio[0] = (t or annun.b.master_caution) * master
    B747DR_annun_brightness_ratio[1] = (t or annun.b.master_warning) * master

    -- EXT PWR and APU GEN AVAIL on their sources' power (as before); the ON
    -- lights on the buses (before, APU GEN 1 ON also took X-Plane's APU
    -- generator)
    B747DR_annun_brightness_ratio[11] = (t or annun.b.ext_pwr_avail_01) * lv.own
    B747DR_annun_brightness_ratio[12] = (t or B747DR_elec_ext_pwr1_on) * lit
    B747DR_annun_brightness_ratio[13] = (t or annun.b.ext_pwr_avail_02) * lv.own
    B747DR_annun_brightness_ratio[14] = (t or B747DR_elec_ext_pwr2_on) * lit
    B747DR_annun_brightness_ratio[15] = (t or annun.b.apu_gen_avail_01) * lv.own
    B747DR_annun_brightness_ratio[16] = (t or B747DR_elec_apu_pwr1_on) * lit
    B747DR_annun_brightness_ratio[17] = (t or annun.b.apu_gen_avail_02) * lv.own
    B747DR_annun_brightness_ratio[18] = (t or B747DR_elec_apu_pwr2_on) * lit

    -- RADIO LCD: the panels' glass glows BRT or DIM, not by the TEST (the
    -- aisle stand's displays: ATA33 p.52; before, the TEST lit them)
    B747DR_annun_brightness_ratio[253] = lit * (1.0 - B747DR_rtp_L_off_status)     -- LEFT RADIO PANEL GLASS (GLOW)
    B747DR_annun_brightness_ratio[254] = lit * (1.0 - B747DR_rtp_C_off_status)     -- CENTER RADIO PANEL GLASS (GLOW)
    B747DR_annun_brightness_ratio[255] = lit * (1.0 - B747DR_rtp_R_off_status)     -- RIGHT RADIO PANEL GLASS (GLOW)
    B747DR_annun_brightness_ratio[256] = lit                                        -- TRANSPONDER RADIO PANEL GLASS (GLOW)
    simDR_instrument_brightness_switch[15] = lit > 0 and 1 or 0                     -- RADIO LCDs

    --wxr panel: the lamps of the weather radar control (B747.34.xt.wxr.lua);
    -- before, they followed X-Plane's radar modes and LR/T was always lit.
    -- (7-2c) BRT or DIM; the TEST leaves them (estimate: the control's own
    -- lamps, not the master dim and test's; before, the TEST lit them)
    B747DR_wxr_left_GCS             = wxr_lamp(false, B747DR_wxr_lamp_gcs[0] > 0.5, lit)
    B747DR_wxr_left_TFR             = wxr_lamp(false, B747DR_wxr_lamp_sel[0] == 4, lit)
    B747DR_wxr_left_WX              = wxr_lamp(false, B747DR_wxr_lamp_sel[0] == 1, lit)
    B747DR_wxr_left_WX_T            = wxr_lamp(false, B747DR_wxr_lamp_sel[0] == 2, lit)
    B747DR_wxr_left_MAP             = wxr_lamp(false, B747DR_wxr_lamp_sel[0] == 3, lit)
    B747DR_wxr_right_GCS            = wxr_lamp(false, B747DR_wxr_lamp_gcs[1] > 0.5, lit)
    B747DR_wxr_right_TFR            = wxr_lamp(false, B747DR_wxr_lamp_sel[1] == 4, lit)
    B747DR_wxr_right_WX             = wxr_lamp(false, B747DR_wxr_lamp_sel[1] == 1, lit)
    B747DR_wxr_right_WX_T           = wxr_lamp(false, B747DR_wxr_lamp_sel[1] == 2, lit)
    B747DR_wxr_right_MAP            = wxr_lamp(false, B747DR_wxr_lamp_sel[1] == 3, lit)
    B747DR_wxr_test                 = wxr_lamp(false, B747DR_wxr_lamp_test > 0.5, lit)
    B747DR_wxr_LR                   = wxr_lamp(false, B747DR_wxr_lamp_rt == 1, lit)
    B747DR_wxr_RR                   = wxr_lamp(false, B747DR_wxr_lamp_rt == 2, lit)
end







----- EMERGENCY LIGHTS ------------------------------------------------------------------
-- (7-2d; notes/ATA-33.md §14) P5's EMER LIGHTS switch (0 OFF, 1 ARMED, 2
-- ON) and the cabin's switch (door 1L) by commands: the 3D has neither
-- (LIGHT-06). Every flight starts ARMED (FCOM p.104), cold and dark too
-- (estimate: no switch in the 3D to arm them). Lit and >EMER LIGHTS by
-- B747.90.light_model.lua
B747DR_emer_switch = find_dataref("laminar/B747/light/emer/switch")
B747DR_emer_cabin = find_dataref("laminar/B747/light/emer/cabin")
B747DR_emer_lit = find_dataref("laminar/B747/light/emer/lit")
B747DR_emer_bus_dc = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_emer_CAS_advisory = find_dataref("laminar/B747/CAS/advisory_status")
function B747_emer_switch_on_CMDhandler(phase, duration)
    if phase == 0 then B747DR_emer_switch = math.min(B747_light_model.EMER_ON, B747DR_emer_switch + 1) end
end
function B747_emer_switch_off_CMDhandler(phase, duration)
    if phase == 0 then B747DR_emer_switch = math.max(B747_light_model.EMER_OFF, B747DR_emer_switch - 1) end
end
-- the cabin's switch: pushed on, pushed again off (FCOM p.453)
function B747_emer_cabin_CMDhandler(phase, duration)
    if phase == 0 then B747DR_emer_cabin = 1 - B747DR_emer_cabin end
end
B747CMD_emer_switch_on = deferred_command("laminar/B747/light/emer/switch_on", "EMER LIGHTS switch toward ON", B747_emer_switch_on_CMDhandler)
B747CMD_emer_switch_off = deferred_command("laminar/B747/light/emer/switch_off", "EMER LIGHTS switch toward OFF", B747_emer_switch_off_CMDhandler)
B747CMD_emer_cabin = deferred_command("laminar/B747/light/emer/cabin", "Cabin EMER LIGHTS switch (door 1L)", B747_emer_cabin_CMDhandler)
function B747_emergency_lights()
    local lit, msg = B747_light_model.emer(B747DR_emer_switch, B747DR_emer_cabin > 0.5, B747DR_emer_bus_dc[3] > 0.5)
    B747DR_emer_lit = lit and 1 or 0
    B747DR_emer_CAS_advisory[108] = msg and 1 or 0
end







----- LIGHTING EICAS MESSAGES -----------------------------------------------------------
function B747_lighting_EICAS_msg()

    -- STROBE LIGHT OFF
    
    -- (1-2) off in both branches before (the memo is in none of the sources'
    -- lists): kept off, without X-Plane's ground
    B747DR_CAS_memo_status[35] = 0

end









----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_lighting_monitor_AI()

    if B747DR_init_lighting_CD == 1 then
        B747_set_lighting_all_modes()
        B747_set_lighting_CD()
        B747DR_init_lighting_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_lighting_all_modes()

	B747DR_init_lighting_CD = 0
    B747_init_lighting()
    B747_init_light_rheostats()
    -- (7-2d) EMER LIGHTS ARMED, the cabin's switch off
    B747DR_emer_switch = B747_light_model.EMER_ARMED
    B747DR_emer_cabin = 0

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
--simDR_window_ice                    = find_dataref("sim/flightmodel/failures/window_ice")
-- (1-1) the second simDR_OAT binding removed: XTLua took it for a write of
-- 0 to X-Plane's read-only temperature (PROGRESS.md, 2026-10-24)
function B747_set_lighting_CD()
    --[[if simDR_OAT<-1 then
        simDR_window_ice                    = 1
    end]]--
end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_lighting_ER()
	

	
end







----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_lighting()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_lighting_all_modes()



    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_lighting_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_lighting_ER()

    end

end










----- EXIT PROCESSING -----------------------------------------------------------------------
function B747_aircraft_unload_lighting()

    -- RESET DEFAULT LIGHTING VALUES
    for i = 0, 63 do
        simDR_generic_brightness_switch[i] = 0.0
    end

    for i = 0, 3 do
        simDR_panel_brightness_switch[i] = 0.75
    end

    for i = 0, 15 do
        simDR_instrument_brightness_switch[i] = 0.0
	B747DR_instrument_brightness_ratio[i] = 0.75
    end

end





--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end

function aircraft_unload()

    B747_aircraft_unload_lighting()

end


function flight_start()
    print("Lighting start")
    -- GENERIC LIGHT INDEX [63] (USED AS A "POWER SOURCE" VALUE FOR LIGHTS)
    simDR_generic_brightness_switch[63] = 1.0
    for i = 0, 15 do
        simDR_instrument_brightness_switch[i] = 0.0
	    B747DR_instrument_brightness_ratio[i] = 1.0
    end
    B747_flight_start_lighting()
    if simDR_version<115602 then
        simDR_shadow=-1
    end
end
function closest_intercept(x1,y1,z1,x2,y2,z2,psi,pitch)
    dx=x1 - x2;
    dy=y1 - y2;
    dz=z1 - z2;
    distance=math.sqrt(((dx*dx) + (dy*dy) + (dz*dz)));
    psiI=psi;



    pitchI=pitch;
    pdistance=math.cos(pitchI*math.pi/180.0)*distance;
    px=(-math.sin(psiI*math.pi/180.0))*pdistance;
    pz=math.cos(psiI*math.pi/180.0)*pdistance;
    py=(-math.sin(pitchI*math.pi/180.0))*distance;
    
    pdx=dx-px;
    pdy=dy-py;
    pdz=dz-pz;
    --print(distance.. " " .. pdx .. " " .. pdy .. " " .. pdz)
    loc=math.sqrt(((pdx*pdx) + (pdz*pdz) + (pdy*pdy)));
    return loc
end
function viewheadCoPilotVisor()
    local psi=simDR_headpsi
    local pitch=simDR_headpitch
    local visorX=B747_rescale(0.5,0.845,1,0.102,simDR_fo_visor_lr) 
    local visorY=5.2
    local visorZ=B747_rescale(0,-25.41,0.6,-26.4,simDR_fo_visor_lr)
    local thisHit=closest_intercept(simDR_headX,simDR_headY,simDR_headZ,visorX,visorY,visorZ,psi,pitch)
    
    local retVal=B747_rescale(0,1,0.4,0,thisHit)
    return retVal
end
function viewheadPilotVisor()
    local psi=simDR_headpsi
    local pitch=simDR_headpitch
    local visorX=B747_rescale(0.5,-0.845,1,-0.102,simDR_capt_visor_lr)
    local visorY=5.2
    local visorZ=B747_rescale(0,-25.41,0.6,-26.4,simDR_capt_visor_lr)
    local thisHit=closest_intercept(simDR_headX,simDR_headY,simDR_headZ,visorX,visorY,visorZ,psi,pitch)
    
    local retVal=B747_rescale(0,1,0.4,0,thisHit)
    return retVal
end
function getPilotVisorValue()
    local retVal=viewheadPilotVisor()
    --print("getPilotVisorValue "..(retVal))
 
    return retVal*(1-simDR_capt_visor_ud)
end
function getCoPilotVisorValue()
    local retVal=viewheadCoPilotVisor()
    --print("getCoPilotVisorValue "..retVal)
 
    return retVal*(1-simDR_fo_visor_ud)
end
local defaultBias=-0.3
function tone_mapping()

    simDR_photoBias=defaultBias-1.6*math.max(getPilotVisorValue(),getCoPilotVisorValue())
   
 --[[   if simDR_sun_pitch>0 then
        simDR_contrast	= B747_rescale(0,1.25,30,0.8,math.abs(simDR_view_pitch))
        simDR_ev100	    = B747_rescale(-10,8,15,14,math.abs(simDR_sun_pitch))
        simDR_tone_mode			    = 0
        simDR_exposure_fusion			    = 0
    else
        simDR_contrast	= B747_rescale(0,0.8,30,1.25,math.abs(simDR_view_pitch))
        simDR_light_storage		    = B747_rescale(0,10,30,1,math.abs(simDR_view_pitch))
        simDR_tone_mode			    = 1
    simDR_exposure_fusion			    = 1
    end]]--
    
end
--function flight_crash() end

--function before_physics() end
debug_lighting     = deferred_dataref("laminar/B747/debug/lighting", "number")
-- The generic light 63 is the "power source" of the display and panel
-- brightness (B747_cabin_lights). X-Plane sets it back to 0 when a new flight
-- starts without reloading the aircraft, after flight_start has set it, and
-- the displays and CDUs stay dark (2026-10-23, both acfs). Read every frame,
-- written only when it changed (ARCHITECTURE.md §9a).
function B747_keep_light_power()
    if simDR_generic_brightness_switch[63] ~= 1.0 then simDR_generic_brightness_switch[63] = 1.0 end
end

-- (7-2a, LIGHT-08) no full garbage collection each frame (before, at the
-- start of every frame: Lua's own incremental collector does it)
function after_physics()
  if debug_lighting>0 then return end

    B747_keep_light_power()
    B747_exterior_lights()
    B747_emergency_lights()
    B747_cabin_lights()

    B747_spill_lights()
    B747_annunciators()
    B747_ind_lights()

    B747_lighting_EICAS_msg()

    B747_lighting_monitor_AI()
    --tone_mapping()
end

--function after_replay() end



