--[[
*****************************************************************************************
* Program Script Name	:	B747.60.fltInst
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







--*************************************************************************************--
--** 					            GLOBAL VARIABLES                				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 					            LOCAL VARIABLES                 				 **--
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



--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")
simDR_version=find_dataref("sim/version/xplane_internal_version")
simDR_all_wheels_on_ground          = find_dataref("sim/flightmodel/failures/onground_any")

--simDR_HSI_source_sel                = find_dataref("sim/cockpit2/radios/actuators/HSI_source_select_pilot")
simDR_autopilot_source              = find_dataref("sim/cockpit2/autopilot/autopilot_source")
simDR_apu_start_switch_mode     = find_dataref("sim/cockpit2/electrical/APU_starter_switch")
simDR_apu_N1_pct                = find_dataref("sim/cockpit2/electrical/APU_N1_percent")

simDR_rmi_captain_left_use_adf      = find_dataref("sim/cockpit2/radios/actuators/RMI_left_use_adf_pilot")
simDR_rmi_captain_right_use_adf     = find_dataref("sim/cockpit2/radios/actuators/RMI_right_use_adf_pilot")

simDR_adf1_relative_bearing_deg     = find_dataref("sim/cockpit2/radios/indicators/adf1_relative_bearing_deg")
simDR_adf2_relative_bearing_deg     = find_dataref("sim/cockpit2/radios/indicators/adf2_relative_bearing_deg")
--simDR_nav1_relative_bearing_deg     = find_dataref("sim/cockpit2/radios/indicators/nav1_relative_bearing_deg")
--simDR_nav2_relative_bearing_deg     = find_dataref("sim/cockpit2/radios/indicators/nav2_relative_bearing_deg")

simDR_nav_relative_bearing_deg      = find_dataref("sim/cockpit2/radios/indicators/nav_relative_bearing_deg")

simDR_nav3_ID                       = find_dataref("sim/cockpit2/radios/indicators/nav3_nav_id")
simDR_nav4_ID                       = find_dataref("sim/cockpit2/radios/indicators/nav4_nav_id")
simDR_adf1_ID                       = find_dataref("sim/cockpit2/radios/indicators/adf1_nav_id")
simDR_adf2_ID                       = find_dataref("sim/cockpit2/radios/indicators/adf2_nav_id")

simDR_altimeter_baro_inHg           = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
simDR_altimeter_baro_inHg_fo        = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot")
simDR_altitude_ft_pilot             = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")

simDR_radio_alt_DH_capt             = find_dataref("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot")
simDR_radio_alt_DH_fo               = find_dataref("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_copilot")
simDR_radio_alt_height_capt         = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
--simDR_radio_alt_height_fo           = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_copilot")
--simDR_radio_alt_DH_alert_capt       = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_dh_lit_pilot")
--simDR_radio_alt_DH_alert_fo         = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_dh_lit_copilot")

simDR_EFIS_map_mode                 = find_dataref("sim/cockpit2/EFIS/map_mode")
simDR_EFIS_map_mode_copilot                 = find_dataref("sim/cockpit2/EFIS/map_mode_copilot")
simDR_EFIS_map_range                = find_dataref("sim/cockpit2/EFIS/map_range")
simDR_EFIS_map_range_copilot               = find_dataref("sim/cockpit2/EFIS/map_range_copilot")
simDR_EFIS_map_is_center            = find_dataref("sim/cockpit2/EFIS/map_mode_is_HSI")

simDR_EFIS_1_sel_pilot              = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_pilot")
simDR_EFIS_2_sel_pilot              = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_pilot")
simDR_EFIS_1_sel_fo                 = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_copilot")
simDR_EFIS_2_sel_fo                 = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_copilot")

simDR_vvi_fpm_pilot                 = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")

simDR_EFIS_wxr_on                   = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on")
simDR_EFIS_wxr_on_fo                = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on_copilot")
simDR_EFIS_tcas_on                  = find_dataref("sim/cockpit2/EFIS/EFIS_tcas_on")
simDR_EFIS_terr_on_capt                  = find_dataref("sim/cockpit2/EFIS/EFIS_terrain_on")
simDR_EFIS_terr_on_fo                  = find_dataref("sim/cockpit2/EFIS/EFIS_terrain_on_copilot")
B747DR_nd_capt_tfc	                = find_dataref("laminar/B747/nd/capt/tfc")
B747DR_nd_fo_tfc	                = find_dataref("laminar/B747/nd/fo/tfc")
B747DR_pfd_mode_capt		        = find_dataref("laminar/B747/pfd/capt/irs")
B747DR_pfd_mode_fo                  = find_dataref("laminar/B747/pfd/fo/irs")
B747DR_pfd_mode_show_mins          	= find_dataref("laminar/B747/pfd/show_mins")
B747DR_ref_thr_limit_mode           = find_dataref("laminar/B747/engines/ref_thr_limit_mode")
B747DR_nd_fo_heading_bug            = find_dataref("laminar/B747/nd/mode/fo/show_heading_bug")
B747DR_nd_capt_heading_bug          = find_dataref("laminar/B747/nd/mode/capt/show_heading_bug")
B747DR_ap_heading_deg               = deferred_dataref("laminar/B747/autopilot/heading/degrees", "number")
--simDR_acf_weight_payload_kg         = find_dataref("sim/flightmodel/weight/m_fixed")
simDR_acf_weight_total_kg           = find_dataref("sim/flightmodel/weight/m_total")
simDR_wing_flap1_deg                = find_dataref("sim/flightmodel2/wing/flap1_deg")

simDR_OAT_degC                      = find_dataref("sim/cockpit2/temperature/outside_air_temp_degc")
simDR_wind_heading_deg              = find_dataref("sim/cockpit2/gauges/indicators/wind_heading_deg_mag")
simDR_wind_speed_kts                = find_dataref("sim/cockpit2/gauges/indicators/wind_speed_kts")
simDR_position_mag_psi              = find_dataref("sim/flightmodel/position/mag_psi")

simDR_gear_deploy_ratio             = find_dataref("sim/flightmodel2/gear/deploy_ratio")
simDR_airspeed_pilot                = find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_pilot")
simDR_airspeed_copilot              = find_dataref("sim/cockpit2/gauges/indicators/airspeed_kts_copilot")
simDR_airspeed                      = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
simDR_airspeed2                      = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_copilot")
simDR_airspeed_mach                 = find_dataref("sim/flightmodel/misc/machno")
simDR_AOA_fail                      = find_dataref("sim/operation/failures/rel_AOA")
simDR_battery_chg_watt_hr           = find_dataref("sim/cockpit/electrical/battery_charge_watt_hr")
simDR_stalled_elements              = find_dataref("sim/flightmodel2/wing/elements/element_is_stalled")
simDR_stall_warning                  = find_dataref("sim/flightmodel/failures/stallwarning")
simDR_has_stall_warning                  = find_dataref("sim/aircraft/view/acf_has_stallwarn")
simDR_hsi_hdef_dots_pilot           = find_dataref("sim/cockpit2/radios/indicators/hsi_hdef_dots_pilot")
simDR_hsi_vdef_dots_pilot           = find_dataref("sim/cockpit2/radios/indicators/hsi_vdef_dots_pilot")

simDR_hsi_hdef_dots_copilot         = find_dataref("sim/cockpit2/radios/indicators/hsi_hdef_dots_copilot")
simDR_hsi_vdef_dots_copilot         = find_dataref("sim/cockpit2/radios/indicators/hsi_vdef_dots_copilot")

simDR_elec_bus_volts				= find_dataref("sim/cockpit2/electrical/bus_volts")		
simDR_time_now						= find_dataref("sim/time/total_running_time_sec")

simDR_autopilot_TOGA_pitch_deg      	= find_dataref("sim/cockpit2/autopilot/TOGA_pitch_deg")
--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_button_switch_position   = find_dataref("laminar/B747/button_switch/position")

-- CANC and RCL are counted here; the alert model (B747.87.xt.alerts.lua)
-- turns the pages and writes msg_page
B747DR_CAS_canc_count           = find_dataref("laminar/B747/CAS/canc_count")
B747DR_CAS_rcl_count            = find_dataref("laminar/B747/CAS/rcl_count")
B747DR_CAS_recall_ind           = find_dataref("laminar/B747/CAS/recall_ind")

B747DR_CAS_warning_status       = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status       = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status      = find_dataref("laminar/B747/CAS/advisory_status")

B747DR_elec_standby_power_sel_pos   = find_dataref("laminar/B747/electrical/standby_power/sel_dial_pos")

B747DR_autothrottle_fail            	= find_dataref("laminar/B747/engines/autothrottle_fail")

B747DR_toga_mode                 = find_dataref("sim/cockpit2/autopilot/TOGA_status")
--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_flt_inst_fd_src_capt_dial_pos            = deferred_dataref("laminar/B747/flt_inst/flt_dir_src/capt/sel_dial_pos", "number")
B747DR_flt_inst_nav_src_capt_dial_pos           = deferred_dataref("laminar/B747/flt_inst/nav_src/capt/sel_dial_pos", "number")
B747DR_flt_inst_eiu_src_capt_dial_pos           = deferred_dataref("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", "number")
B747DR_flt_inst_irs_src_capt_dial_pos           = deferred_dataref("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos", "number")
B747DR_flt_inst_air_data_src_capt_dial_pos      = deferred_dataref("laminar/B747/flt_inst/air_data_src/capt/sel_dial_pos", "number")

B747DR_flt_inst_fd_src_fo_dial_pos              = deferred_dataref("laminar/B747/flt_inst/flt_dir_src/fo/sel_dial_pos", "number")
B747DR_flt_inst_nav_src_fo_dial_pos             = deferred_dataref("laminar/B747/flt_inst/nav_src/fo/sel_dial_pos", "number")
B747DR_flt_inst_eiu_src_fo_dial_pos             = deferred_dataref("laminar/B747/flt_inst/eiu_src/fo/sel_dial_pos", "number")
B747DR_flt_inst_irs_src_fo_dial_pos             = deferred_dataref("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", "number")
B747DR_flt_inst_air_data_src_fo_dial_pos        = deferred_dataref("laminar/B747/flt_inst/air_data_src/fo/sel_dial_pos", "number")

B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos        = deferred_dataref("laminar/B747/flt_inst/eiu_src/ctr_pnl/sel_dial_pos", "number")
B747DR_flt_inst_fmc_master_src_ctr_pnl_sel_pos  = deferred_dataref("laminar/B747/flt_inst/fmc_master_src/ctr_pnl/sel_dial_pos", "number")

B747DR_flt_inst_inbd_disp_capt_sel_dial_pos     = deferred_dataref("laminar/B747/flt_inst/capt_inbd_display/sel_dial_pos", "number")
B747DR_flt_inst_lwr_disp_capt_sel_dial_pos      = deferred_dataref("laminar/B747/flt_inst/capt_lwr_display/sel_dial_pos", "number")

B747DR_flt_inst_inbd_disp_fo_sel_dial_pos       = deferred_dataref("laminar/B747/flt_inst/fo_inbd_display/sel_dial_pos", "number")
B747DR_flt_inst_lwr_disp_fo_sel_dial_pos        = deferred_dataref("laminar/B747/flt_inst/fo_lwr_display/sel_dial_pos", "number")

B747DR_flt_inst_capt_pfd_pos      		= deferred_dataref("laminar/B747/flt_inst/display/capt/pfd_pos", "number")
B747DR_flt_inst_fo_pfd_pos      		= deferred_dataref("laminar/B747/flt_inst/display/fo/pfd_pos", "number")
B747DR_flt_inst_capt_nd_pos      		= deferred_dataref("laminar/B747/flt_inst/display/capt/nd_pos", "number")
B747DR_flt_inst_fo_nd_pos      			= deferred_dataref("laminar/B747/flt_inst/display/fo/nd_pos", "number")
B747DR_flt_inst_eicas_pos      			= deferred_dataref("laminar/B747/flt_inst/display/eicas_pos", "number")
B747DR_flt_inst_pri_eicas_pos      		= deferred_dataref("laminar/B747/flt_inst/display/pri_eicas_pos", "number")

B747DR_efis_min_ref_alt_capt_sel_dial_pos       = deferred_dataref("laminar/B747/efis/min_ref_alt/capt/sel_dial_pos", "number")
B747DR_efis_ref_alt_capt_set_dial_pos           = deferred_dataref("laminar/B747/efis/ref_alt/capt/set_dial_pos", "number")
B747DR_efis_dh_reset_capt_switch_pos            = deferred_dataref("laminar/B747/efis/dh_reset/capt/switch_pos", "number")
B747DR_efis_baro_ref_capt_sel_dial_pos          = deferred_dataref("laminar/B747/efis/baro_ref/capt/sel_dial_pos", "number")
B747DR_efis_baro_std_capt_switch_pos            = deferred_dataref("laminar/B747/efis/baro_std/capt/switch_pos", "number")
B747DR_efis_baro_std_capt_show_preselect              = deferred_dataref("laminar/B747/efis/baro_std/capt/show_preselect", "number")
B747DR_efis_baro_capt_set_dial_pos              = deferred_dataref("laminar/B747/efis/baro/capt/set_dial_pos", "number")
B747DR_efis_baro_capt_preselect                 = deferred_dataref("laminar/B747/efis/baro/capt/preselect", "number")
B747DR_efis_baro_alt_ref_capt                   = deferred_dataref("laminar/B747/efis/baro_ref/capt", "number")

B747DR_efis_min_ref_alt_fo_sel_dial_pos         = deferred_dataref("laminar/B747/efis/min_ref_alt/fo/sel_dial_pos", "number")
B747DR_efis_ref_alt_fo_set_dial_pos             = deferred_dataref("laminar/B747/efis/ref_alt/fo/set_dial_pos", "number")
B747DR_efis_dh_reset_fo_switch_pos              = deferred_dataref("laminar/B747/efis/dh_reset/fo/switch_pos", "number")
B747DR_efis_baro_ref_fo_sel_dial_pos            = deferred_dataref("laminar/B747/efis/baro_ref/fo/sel_dial_pos", "number")
B747DR_efis_baro_std_fo_switch_pos              = deferred_dataref("laminar/B747/efis/baro_std/fo/switch_pos", "number")
B747DR_efis_baro_fo_set_dial_pos                = deferred_dataref("laminar/B747/efis/baro/fo/set_dial_pos", "number")
B747DR_efis_baro_std_fo_show_preselect              = deferred_dataref("laminar/B747/efis/baro_std/fo/show_preselect", "number")
B747DR_efis_baro_fo_preselect                   = deferred_dataref("laminar/B747/efis/baro/fo/preselect", "number")
B747DR_efis_baro_alt_ref_fo                     = deferred_dataref("laminar/B747/efis/baro_ref/fo", "number")

B747DR_efis_fpv_capt_switch_pos                 = deferred_dataref("laminar/B747/efis/fpv/capt/switch_pos", "number")
B747DR_efis_fpv_capt_selected                   = deferred_dataref("laminar/B747/efis/fpv/capt/selected", "number")
B747DR_efis_meters_capt_switch_pos              = deferred_dataref("laminar/B747/efis/meters/capt/switch_pos", "number")
B747DR_efis_meters_capt_selected                = deferred_dataref("laminar/B747/efis/meters/capt/selected", "number")

B747DR_efis_fpv_fo_switch_pos                   = deferred_dataref("laminar/B747/efis/fpv/fo/switch_pos", "number")
B747DR_efis_fpv_fo_selected                     = deferred_dataref("laminar/B747/efis/fpv/fo/selected", "number")
B747DR_efis_meters_fo_switch_pos                = deferred_dataref("laminar/B747/efis/meters/fo/switch_pos", "number")
B747DR_efis_meters_fo_selected                  = deferred_dataref("laminar/B747/efis/meters/fo/selected", "number")

B747DR_nd_mode_capt_sel_dial_pos                = deferred_dataref("laminar/B747/nd/mode/capt/sel_dial_pos", "number")
B747DR_nd_range_capt_sel_dial_pos               = deferred_dataref("laminar/B747/nd/range/capt/sel_dial_pos", "number")

B747DR_nd_center_capt_switch_pos                = deferred_dataref("laminar/B747/nd/center/capt/switch_pos", "number")
B747DR_nd_traffic_capt_switch_pos               = deferred_dataref("laminar/B747/nd/traffic/capt/switch_pos", "number")

B747_nd_map_center_capt                         = deferred_dataref("laminar/B747/nd/map_center/capt", "number")

B747DR_nd_mode_fo_sel_dial_pos                  = deferred_dataref("laminar/B747/nd/mode/fo/sel_dial_pos", "number")
B747DR_nd_range_fo_sel_dial_pos                 = deferred_dataref("laminar/B747/nd/range/fo/sel_dial_pos", "number")

B747DR_nd_center_fo_switch_pos                  = deferred_dataref("laminar/B747/nd/center/fo/switch_pos", "number")
B747DR_nd_traffic_fo_switch_pos                 = deferred_dataref("laminar/B747/nd/traffic/fo/switch_pos", "number")

B747_nd_map_center_fo                           = deferred_dataref("laminar/B747/nd/map_center/fo", "number")

B747DR_nd_wxr_capt_switch_pos                   = deferred_dataref("laminar/B747/nd/wxr/capt/switch_pos", "number")
B747DR_nd_sta_capt_switch_pos                   = deferred_dataref("laminar/B747/nd/sta/capt/switch_pos", "number")
B747DR_nd_wpt_capt_switch_pos                   = deferred_dataref("laminar/B747/nd/wpt/capt/switch_pos", "number")
B747DR_nd_arpt_capt_switch_pos                  = deferred_dataref("laminar/B747/nd/arpt/capt/switch_pos", "number")
B747DR_nd_data_capt_switch_pos                  = deferred_dataref("laminar/B747/nd/data/capt/switch_pos", "number")
B747DR_nd_pos_capt_switch_pos                   = deferred_dataref("laminar/B747/nd/pos/capt/switch_pos", "number")
B747DR_nd_terr_capt_switch_pos                  = deferred_dataref("laminar/B747/nd/terr/capt/switch_pos", "number")
-- the TFC switches' pushes, for the TCAS model (B747.34.xt.tcas.lua), which
-- keeps each ND's traffic display and writes nd/capt|fo/tfc
B747DR_nd_capt_tfc_pushes                       = find_dataref("laminar/B747/nd/traffic/capt/pushes")
B747DR_nd_fo_tfc_pushes                         = find_dataref("laminar/B747/nd/traffic/fo/pushes")
B747DR_nd_capt_terr                          = deferred_dataref("laminar/B747/nd/data/capt/terr", "number")
B747DR_nd_fo_terr                          	= deferred_dataref("laminar/B747/nd/data/fo/terr", "number")
B747DR_nd_capt_vor_ndb                          = deferred_dataref("laminar/B747/nd/data/capt/vor_ndb", "number")
B747DR_nd_fo_vor_ndb                          	= deferred_dataref("laminar/B747/nd/data/fo/vor_ndb", "number")
B747DR_nd_capt_wpt                          = deferred_dataref("laminar/B747/nd/data/capt/wpt", "number")
B747DR_nd_fo_wpt                         	= deferred_dataref("laminar/B747/nd/data/fo/wpt", "number")
B747DR_nd_capt_apt	                        = deferred_dataref("laminar/B747/nd/data/capt/apt", "number")
B747DR_nd_fo_apt	                        = deferred_dataref("laminar/B747/nd/data/fo/apt", "number")
B747DR_nd_capt_data                             = find_dataref("laminar/B747/nd/data/capt/data")
B747DR_nd_fo_data                               = find_dataref("laminar/B747/nd/data/fo/data")
B747DR_nd_capt_pos                              = find_dataref("laminar/B747/nd/data/capt/pos")
B747DR_nd_fo_pos                                = find_dataref("laminar/B747/nd/data/fo/pos")
B747DR_efis_panel_fail                          = find_dataref("laminar/B747/efis/fail")

-- an EFIS control panel takes no input while it is failed (5-2 step 5c:
-- >EFIS CONTROL L, R, FCOM p.1198; its functions on the CDU instead, FCOM
-- p.1060); 0 the Captain's, 1 the F/O's
local function efis_panel_ok(i)
    return B747DR_efis_panel_fail[i] < 0.5
end

B747_nd_vorL_ID_flag_capt                       = deferred_dataref("laminar/B747/nd/vorL_id_flag/capt", "number")
B747_nd_vorR_ID_flag_capt                       = deferred_dataref("laminar/B747/nd/vorR_id_flag/capt", "number")

B747_nd_adfL_ID_flag_capt                       = deferred_dataref("laminar/B747/nd/adfL_id_flag/capt", "number")
B747_nd_adfR_ID_flag_capt                       = deferred_dataref("laminar/B747/nd/adfR_id_flag/capt", "number")

B747_exp_fo_nd_track_line_on                       = deferred_dataref("laminar/B747/nd/fo/track_line_on", "number")
B747_exp_capt_nd_track_line_on                       = deferred_dataref("laminar/B747/nd/capt/track_line_on", "number")

B747DR_nd_wxr_fo_switch_pos                     = deferred_dataref("laminar/B747/nd/wxr/fo/switch_pos", "number")
B747DR_nd_sta_fo_switch_pos                     = deferred_dataref("laminar/B747/nd/sta/fo/switch_pos", "number")
B747DR_nd_wpt_fo_switch_pos                     = deferred_dataref("laminar/B747/nd/wpt/fo/switch_pos", "number")
B747DR_nd_arpt_fo_switch_pos                    = deferred_dataref("laminar/B747/nd/arpt/fo/switch_pos", "number")
B747DR_nd_data_fo_switch_pos                    = deferred_dataref("laminar/B747/nd/data/fo/switch_pos", "number")
B747DR_nd_pos_fo_switch_pos                     = deferred_dataref("laminar/B747/nd/pos/fo/switch_pos", "number")
B747DR_nd_terr_fo_switch_pos                    = deferred_dataref("laminar/B747/nd/terr/fo/switch_pos", "number")

B747_nd_vorL_ID_flag_fo                         = deferred_dataref("laminar/B747/nd/vorL_id_flag/fo", "number")
B747_nd_vorR_ID_flag_fo                         = deferred_dataref("laminar/B747/nd/vorR_id_flag/fo", "number")

B747_nd_adfL_ID_flag_fo                         = deferred_dataref("laminar/B747/nd/adfL_id_flag/fo", "number")
B747_nd_adfR_ID_flag_fo                         = deferred_dataref("laminar/B747/nd/adfR_id_flag/fo", "number")

B747DR_dsp_eng_switch_pos                       = deferred_dataref("laminar/B747/dsp/eng/switch_pos", "number")
B747DR_dsp_stat_switch_pos                      = deferred_dataref("laminar/B747/dsp/stat/switch_pos", "number")
B747DR_dsp_elec_switch_pos                      = deferred_dataref("laminar/B747/dsp/elec/switch_pos", "number")
B747DR_dsp_fuel_switch_pos                      = deferred_dataref("laminar/B747/dsp/fuel/switch_pos", "number")
B747DR_dsp_ecs_switch_pos                       = deferred_dataref("laminar/B747/dsp/ecs/switch_pos", "number")
B747DR_dsp_hyd_switch_pos                       = deferred_dataref("laminar/B747/dsp/hyd/switch_pos", "number")
B747DR_dsp_drs_switch_pos                       = deferred_dataref("laminar/B747/dsp/drs/switch_pos", "number")
B747DR_dsp_gear_switch_pos                      = deferred_dataref("laminar/B747/dsp/gear/switch_pos", "number")

B747DR_dsp_canc_switch_pos                      = deferred_dataref("laminar/B747/dsp/canc/switch_pos", "number")
B747DR_dsp_rcl_switch_pos                       = deferred_dataref("laminar/B747/dsp/rcl/switch_pos", "number")

B747DR_dsp_synoptic_display                     = deferred_dataref("laminar/B747/dsp/synoptic_display", "number")

B747DR_STAT_msg_page                            = deferred_dataref("laminar/B747/STAT/msg_page", "number")
B747DR_STAT_num_msg_pages                       = deferred_dataref("laminar/B747/STAT/num_msg_pages", "number")
B747DR_simDR_captain_display              = find_dataref("laminar/B747/electrical/capt_display_power")
B747DR_simDR_fo_display                 = find_dataref("laminar/B747/electrical/fo_display_power")
B747DR_fltInst_elec_stby_main            = find_dataref("laminar/B747/electrical/bus/stby_main")
-- the clocks keep time on the main hot battery bus (FCOM p.820, p.1075)
B747DR_fltInst_elec_hot_bat_main         = find_dataref("laminar/B747/electrical/bus/hot_bat_main")
B747DR_elec_display_power               = find_dataref("laminar/B747/electrical/display_has_power")
B747DR_ap_FMA_active_roll_mode      	= find_dataref("laminar/B747/autopilot/FMA/active_roll_mode", "number")
--[[
    0 = NONE
    1 = TOGA
    2 = LNAV
    3 = LOC
    4 = ROLLOUT
    5 = ATT
    6 = HDG SEL
    7 = HDG HOLD
--]]

B747DR_RMI_left_bearing                         = deferred_dataref("laminar/B747/rmi_left/captain/bearing", "number")
B747DR_RMI_right_bearing                        = deferred_dataref("laminar/B747/rmi_right/captain/bearing", "number")

B747DR_alt_hectopascal                          = deferred_dataref("laminar/B747/altimeter/baro_hectopascal", "number")
B747DR_altimter_ft_adjusted                     = deferred_dataref("laminar/B747/altimeter/ft_adjusted", "number")

B747DR_dec_ht_display_status                    = deferred_dataref("laminar/B747/dec_height/display_status", "number")
B747DR_radio_alt_display_status                 = deferred_dataref("laminar/B747/radio_alt/display_status", "number")
B747DR_dec_ht_display_status_fo                 = deferred_dataref("laminar/B747/dec_height/display_status_fo", "number")
B747DR_radio_alt_display_status_fo              = deferred_dataref("laminar/B747/radio_alt/display_status_fo", "number")
-- each PFD's radio altitude (the nav module's: B747.34.xt.ra.lua)
B747DR_ra_capt_value                            = find_dataref("laminar/B747/ra/capt/value")
B747DR_ra_capt_flag                             = find_dataref("laminar/B747/ra/capt/flag")
B747DR_ra_fo_value                              = find_dataref("laminar/B747/ra/fo/value")
B747DR_ra_fo_flag                               = find_dataref("laminar/B747/ra/fo/flag")

B747DR_radio_altitude                           = deferred_dataref("laminar/B747/efis/radio_altitude", "number")

B747DR_vertical_speed_fpm                       = deferred_dataref("laminar/B747/vsi/fpm", "number")

B747DR_airspeed_V1                              = deferred_dataref("laminar/B747/airspeed/V1", "number")
B747DR_airspeed_Vr                              = deferred_dataref("laminar/B747/airspeed/Vr", "number")
B747DR_airspeed_V2                              = deferred_dataref("laminar/B747/airspeed/V2", "number")
B747DR_airspeed_Va                              = deferred_dataref("laminar/B747/airspeed/Va", "number")
B747DR_airspeed_Vf0                             = deferred_dataref("laminar/B747/airspeed/Vf0", "number")
B747DR_airspeed_Vf1                             = deferred_dataref("laminar/B747/airspeed/Vf1", "number")
B747DR_airspeed_Vf5                             = deferred_dataref("laminar/B747/airspeed/Vf5", "number")
B747DR_airspeed_Vf10                            = deferred_dataref("laminar/B747/airspeed/Vf10", "number")
B747DR_airspeed_Vf20                            = deferred_dataref("laminar/B747/airspeed/Vf20", "number")
B747DR_airspeed_Vf25                            = deferred_dataref("laminar/B747/airspeed/Vf25", "number")
B747DR_airspeed_Vf30                            = deferred_dataref("laminar/B747/airspeed/Vf30", "number")
B747DR_airspeed_Vfe0                            = deferred_dataref("laminar/B747/airspeed/Vfe0", "number")
B747DR_airspeed_Vfe1                            = deferred_dataref("laminar/B747/airspeed/Vfe1", "number")
B747DR_airspeed_Vfe5                            = deferred_dataref("laminar/B747/airspeed/Vfe2", "number")
B747DR_airspeed_Vfe10                           = deferred_dataref("laminar/B747/airspeed/Vfe10", "number")
B747DR_airspeed_Vfe20                           = deferred_dataref("laminar/B747/airspeed/Vfe20", "number")
B747DR_airspeed_Vfe25                           = deferred_dataref("laminar/B747/airspeed/Vfe25", "number")
B747DR_airspeed_Vfe30                           = deferred_dataref("laminar/B747/airspeed/Vfe30", "number")
B747DR_airspeed_Vlo                             = deferred_dataref("laminar/B747/airspeed/Vlo", "number")
B747DR_airspeed_Mlo                             = deferred_dataref("laminar/B747/airspeed/Mlo", "number")
B747DR_airspeed_Mms                             = deferred_dataref("laminar/B747/airspeed/Mms", "number")
B747DR_airspeed_Vle                             = deferred_dataref("laminar/B747/airspeed/Vle", "number")
B747DR_airspeed_Mle                             = deferred_dataref("laminar/B747/airspeed/Mle", "number")
B747DR_airspeed_Vmo                             = deferred_dataref("laminar/B747/airspeed/Vmo", "number")
B747DR_airspeed_Mmo                             = deferred_dataref("laminar/B747/airspeed/Mmo", "number")
B747DR_airspeed_Vmc                             = deferred_dataref("laminar/B747/airspeed/Vmc", "number")
B747DR_airspeed_Vne                             = deferred_dataref("laminar/B747/airspeed/Vne", "number")
B747DR_airspeed_Mne                             = deferred_dataref("laminar/B747/airspeed/Mne", "number")
B747DR_airspeed_Vref30                          = deferred_dataref("laminar/B747/airspeed/Vref30", "number")
B747DR_airspeed_Vref                          = deferred_dataref("laminar/B747/airspeed/Vref", "number")
B747DR_airspeed_VrefFlap                          = deferred_dataref("laminar/B747/airspeed/VrefFlap", "number")
B747DR_airspeed_showVf25                            = deferred_dataref("laminar/B747/airspeed/showVf25", "number")
B747DR_airspeed_showVf30                            = deferred_dataref("laminar/B747/airspeed/showVf30", "number")
B747DR_airspeed_Vmax                            = deferred_dataref("laminar/B747/airspeed/Vmax", "number")
B747DR_airspeed_Vmaxm                           = deferred_dataref("laminar/B747/airspeed/Vmaxm", "number")
B747DR_airspeed_Vs                              = deferred_dataref("laminar/B747/airspeed/Vs", "number")
simDR_flap_ratio_control                        = find_dataref("sim/cockpit2/controls/flap_ratio")                      -- FLAP HANDLE
simDR_innerslats_ratio  	= find_dataref("sim/flightmodel2/controls/slat1_deploy_ratio")
B747DR_airspeed_window_min                      = deferred_dataref("laminar/B747/airspeed_window/min", "number")

B747DR_init_inst_CD                             = deferred_dataref("laminar/B747/inst/init_CD", "number")

B747DR_loc_ptr_vis_capt                         = deferred_dataref("laminar/B747/localizer_ptr/visibility_flag_capt", "number")
B747DR_loc_scale_vis_capt                       = deferred_dataref("laminar/B747/localizer_scale/visibility_flag_capt", "number")
B747DR_glideslope_ptr_vis_capt                  = deferred_dataref("laminar/B747/glideslope_ptr/visibility_flag_capt", "number")
B747DR_loc_ptr_vis_fo                           = deferred_dataref("laminar/B747/localizer_ptr/visibility_flag_fo", "number")
B747DR_loc_scale_vis_fo                         = deferred_dataref("laminar/B747/localizer_scale/visibility_flag_fo", "number")
B747DR_glideslope_ptr_vis_fo                    = deferred_dataref("laminar/B747/glideslope_ptr/visibility_flag_fo", "number")

-- crazytimtimtim ( + Matt726)
B747DR_v1_alert                                 = deferred_dataref("laminar/B747/fmod/callouts/v1", "number")
B747DR_vr_alert                                 = deferred_dataref("laminar/B747/fmod/callouts/vr", "number")
B747DR_appDH_alert                              = deferred_dataref("laminar/B747/fmod/callouts/appDH", "number")
B747DR_DH_alert                                 = deferred_dataref("laminar/B747/fmod/callouts/DH", "number")
B747DR_10000_callout                            = deferred_dataref("laminar/B747/fmod/callouts/10000", "number")


--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--



--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--



--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--


simCMD_EFIS_wxr                 = find_command("sim/instruments/EFIS_wxr")
simCMD_EFIS_wxr_fo                 = find_command("sim/instruments/EFIS_copilot_wxr")
simCMD_EFIS_tcas                = find_command("sim/instruments/EFIS_tcas")

-- simCMD_EFIS_apt                 = find_command("sim/instruments/EFIS_apt")
-- simCMD_EFIS_vor                 = find_command("sim/instruments/EFIS_vor")
-- simCMD_EFIS_ndb                 = find_command("sim/instruments/EFIS_ndb")
simCMD_EFIS_fix                 = find_command("sim/instruments/EFIS_fix")

simDR_EFIS_apt			= find_dataref("sim/cockpit2/EFIS/EFIS_airport_on")
simDR_EFIS_fix 			= find_dataref("sim/cockpit2/EFIS/EFIS_fix_on")
simDR_EFIS_vor 			= find_dataref("sim/cockpit2/EFIS/EFIS_vor_on")
simDR_EFIS_ndb 			= find_dataref("sim/cockpit2/EFIS/EFIS_ndb_on")

simDR_EFIS_apt_fo			= find_dataref("sim/cockpit2/EFIS/EFIS_airport_on_copilot")
simDR_EFIS_fix_fo 			= find_dataref("sim/cockpit2/EFIS/EFIS_fix_on_copilot")
simDR_EFIS_vor_fo 			= find_dataref("sim/cockpit2/EFIS/EFIS_vor_on_copilot")
simDR_EFIS_ndb_fo 			= find_dataref("sim/cockpit2/EFIS/EFIS_ndb_on_copilot")

--*************************************************************************************--
--** 				               FIND CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747CMD_autothrottle_disarm                 = find_command("laminar/B747/authrottle_disarm")



--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- FLIGHT DIRECTOR SOURCE SELECTOR (CAPTAIN)
function B747_flt_inst_fd_src_capt_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_fd_src_capt_dial_pos = math.min(B747DR_flt_inst_fd_src_capt_dial_pos+1, 2)
    end
end
function B747_flt_inst_fd_src_capt_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_fd_src_capt_dial_pos = math.max(B747DR_flt_inst_fd_src_capt_dial_pos-1, 0)
    end
end

-- NAV SOURCE SELECTOR (CAPTAIN)
function B747_inst_src_capt_nav_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_nav_src_capt_dial_pos = math.min(B747DR_flt_inst_nav_src_capt_dial_pos+1, 3)
    end
end
function B747_inst_src_capt_nav_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_nav_src_capt_dial_pos = math.max(B747DR_flt_inst_nav_src_capt_dial_pos-1, 0)
    end
end

-- EIU SOURCE SELECTOR (CAPTAIN)
function B747_inst_src_capt_eiu_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_capt_dial_pos = math.min(B747DR_flt_inst_eiu_src_capt_dial_pos+1, 3)
    end
end
function B747_inst_src_capt_eiu_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_capt_dial_pos = math.max(B747DR_flt_inst_eiu_src_capt_dial_pos-1, 0)
    end
end

-- IRS SOURCE SELECTOR (CAPTAIN)
function B747_inst_src_capt_irs_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_irs_src_capt_dial_pos = math.min(B747DR_flt_inst_irs_src_capt_dial_pos+1, 2)
    end
end
function B747_inst_src_capt_irs_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_irs_src_capt_dial_pos = math.max(B747DR_flt_inst_irs_src_capt_dial_pos-1, 0)
    end
end

-- AIR DATA SOURCE SELECTOR (CAPTAIN)
function B747_inst_src_capt_air_data_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_air_data_src_capt_dial_pos = math.min(B747DR_flt_inst_air_data_src_capt_dial_pos+1, 1)
    end
end
function B747_inst_src_capt_air_data_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_air_data_src_capt_dial_pos = math.max(B747DR_flt_inst_air_data_src_capt_dial_pos-1, 0)
    end
end





-- FLIGHT DIRECTOR SOURCE SELECTOR (FIRST OFFICER)
function B747_flt_inst_fd_src_fo_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_fd_src_fo_dial_pos = math.min(B747DR_flt_inst_fd_src_fo_dial_pos+1, 2)
    end
end
function B747_flt_inst_fd_src_fo_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_fd_src_fo_dial_pos = math.max(B747DR_flt_inst_fd_src_fo_dial_pos-1, 0)
    end
end

-- NAV SOURCE SELECTOR (FIRST OFFICER)
function B747_inst_src_fo_nav_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_nav_src_fo_dial_pos = math.min(B747DR_flt_inst_nav_src_fo_dial_pos+1, 3)
    end
end
function B747_inst_src_fo_nav_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_nav_src_fo_dial_pos = math.max(B747DR_flt_inst_nav_src_fo_dial_pos-1, 0)
    end
end

-- EIU SOURCE SELECTOR (FIRST OFFICER)
function B747_inst_src_fo_eiu_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_fo_dial_pos = math.min(B747DR_flt_inst_eiu_src_fo_dial_pos+1, 3)
    end
end
function B747_inst_src_fo_eiu_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_fo_dial_pos = math.max(B747DR_flt_inst_eiu_src_fo_dial_pos-1, 0)
    end
end

-- IRS SOURCE SELECTOR (FIRST OFFICER)
function B747_inst_src_fo_irs_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_irs_src_fo_dial_pos = math.min(B747DR_flt_inst_irs_src_fo_dial_pos+1, 2)
    end
end
function B747_inst_src_fo_irs_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_irs_src_fo_dial_pos = math.max(B747DR_flt_inst_irs_src_fo_dial_pos-1, 0)
    end
end

-- AIR DATA SOURCE SELECTOR (FIRST OFFICER)
function B747_inst_src_fo_air_data_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_air_data_src_fo_dial_pos = math.min(B747DR_flt_inst_air_data_src_fo_dial_pos+1, 1)
    end
end
function B747_inst_src_fo_air_data_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_air_data_src_fo_dial_pos = math.max(B747DR_flt_inst_air_data_src_fo_dial_pos-1, 0)
    end
end





-- EIU SOURCE SELECTOR (CENTER PANEL)
function B747_flt_inst_eiu_src_ctr_pnl_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos = math.min(B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos+1, 3)
    end
end
function B747_flt_inst_eiu_src_ctr_pnl_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos = math.max(B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos-1, 0)
    end
end

--  FMC MASTER SELECTOR (CENTER PANEL)
function B747_flt_inst_fmc_master_src_ctr_pnl_sel_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_fmc_master_src_ctr_pnl_sel_pos = 1.0 - B747DR_flt_inst_fmc_master_src_ctr_pnl_sel_pos
        simDR_autopilot_source = B747DR_flt_inst_fmc_master_src_ctr_pnl_sel_pos                               -- TODO:  VERIFY WITH HOW TO SWITCH NAV1/NAV2 (HSI SOURCE SEL)
        --B747CMD_autothrottle_disarm:once()
    end
end






-- DISPLAY SELECTOR (CAPTAIN)
function B747_flt_inst_inbd_disp_capt_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_inbd_disp_capt_sel_dial_pos = math.min(B747DR_flt_inst_inbd_disp_capt_sel_dial_pos+1, 2)
    end
end
function B747_flt_inst_inbd_disp_capt_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_inbd_disp_capt_sel_dial_pos = math.max(B747DR_flt_inst_inbd_disp_capt_sel_dial_pos-1, 0)
    end
end

function B747_flt_inst_lwr_disp_capt_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_lwr_disp_capt_sel_dial_pos = math.min(B747DR_flt_inst_lwr_disp_capt_sel_dial_pos+1, 2)
    end
end
function B747_flt_inst_lwr_disp_capt_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_lwr_disp_capt_sel_dial_pos = math.max(B747DR_flt_inst_lwr_disp_capt_sel_dial_pos-1, 0)
    end
end





-- DISPLAY SELECTOR (FIRST OFFICER)
function B747_flt_inst_inbd_disp_fo_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_inbd_disp_fo_sel_dial_pos = math.min(B747DR_flt_inst_inbd_disp_fo_sel_dial_pos+1, 2)
    end
end
function B747_flt_inst_inbd_disp_fo_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_inbd_disp_fo_sel_dial_pos = math.max(B747DR_flt_inst_inbd_disp_fo_sel_dial_pos-1, 0)
    end
end

function B747_flt_inst_lwr_disp_fo_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_lwr_disp_fo_sel_dial_pos = math.min(B747DR_flt_inst_lwr_disp_fo_sel_dial_pos+1, 2)
    end
end
function B747_flt_inst_lwr_disp_fo_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_flt_inst_lwr_disp_fo_sel_dial_pos = math.max(B747DR_flt_inst_lwr_disp_fo_sel_dial_pos-1, 0)
    end
end





-- EFIS CONTROLS (CAPTAIN)
function B747_efis_min_ref_alt_capt_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_min_ref_alt_capt_sel_dial_pos = math.min(B747DR_efis_min_ref_alt_capt_sel_dial_pos + 1, 1)
    end
end

function B747_efis_min_ref_alt_capt_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_min_ref_alt_capt_sel_dial_pos = math.max(B747DR_efis_min_ref_alt_capt_sel_dial_pos - 1, 0)
    end
end


function B747_efis_ref_alt_capt_set_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_ref_alt_capt_set_dial_pos = B747DR_efis_ref_alt_capt_set_dial_pos + 0.1
        if B747DR_efis_min_ref_alt_capt_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_capt = math.min(simDR_radio_alt_DH_capt + 1.0,1000)
        elseif B747DR_efis_min_ref_alt_capt_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_capt = math.min(B747DR_efis_baro_alt_ref_capt + 1.0,10000)
        end
    elseif phase == 1 and duration > 1.0 then
        B747DR_efis_ref_alt_capt_set_dial_pos = B747DR_efis_ref_alt_capt_set_dial_pos + 0.1
        if B747DR_efis_min_ref_alt_capt_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_capt = math.min(simDR_radio_alt_DH_capt + 10.0,1000)
        elseif B747DR_efis_min_ref_alt_capt_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_capt = math.min(B747DR_efis_baro_alt_ref_capt + 10.0,10000)
        end
    end
end

function B747_efis_ref_alt_capt_set_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_ref_alt_capt_set_dial_pos = B747DR_efis_ref_alt_capt_set_dial_pos - 0.1
        if B747DR_efis_min_ref_alt_capt_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_capt = math.max(simDR_radio_alt_DH_capt - 1.0,-1)
        elseif B747DR_efis_min_ref_alt_capt_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_capt = math.max(B747DR_efis_baro_alt_ref_capt - 1.0,-101)
        end
    elseif phase == 1 and duration > 1.0 then
        B747DR_efis_ref_alt_capt_set_dial_pos = B747DR_efis_ref_alt_capt_set_dial_pos - 0.1
        if B747DR_efis_min_ref_alt_capt_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_capt = math.max(simDR_radio_alt_DH_capt - 10.0,-1)
        elseif B747DR_efis_min_ref_alt_capt_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_capt = math.max(B747DR_efis_baro_alt_ref_capt - 10.0,-101)
        end
    end
end


-- MINS RST resets the flashing minimums alert of its own side only (FCOM
-- p.982, p.1036)
function B747_efis_dh_capt_reset_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_dh_reset_capt_switch_pos = 1
        B747_dh_rst_capt = true
    elseif phase == 2 then
        B747DR_efis_dh_reset_capt_switch_pos = 0
    end
end
-- the CDU's DH RESET (EFIS CONTROL page, FCOM p.1062): its own side, also
-- with the panel failed (5-2 step 5c; before, both CDUs pushed the
-- Captain's switch)
function B747_cdu_dh_reset_capt_CMDhandler(phase, duration)
    if phase == 0 then B747_dh_rst_capt = true end
end

function B747_efis_baro_ref_capt_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_baro_ref_capt_sel_dial_pos = math.min(B747DR_efis_baro_ref_capt_sel_dial_pos + 1, 1)
    end
end

function B747_efis_baro_ref_capt_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_baro_ref_capt_sel_dial_pos = math.max(B747DR_efis_baro_ref_capt_sel_dial_pos - 1, 0)
    end
end

function B747_efis_baro_set_capt_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_baro_capt_set_dial_pos = B747DR_efis_baro_capt_set_dial_pos + 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_capt_switch_pos == 0 then
            simDR_altimeter_baro_inHg = math.min(34.00, simDR_altimeter_baro_inHg + 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_capt_switch_pos == 1 then
            B747DR_efis_baro_capt_preselect = math.min(34.00, B747DR_efis_baro_capt_preselect + 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 1
        end
    elseif phase == 1 and duration > 0.5 then 
        B747DR_efis_baro_capt_set_dial_pos = B747DR_efis_baro_capt_set_dial_pos + 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_capt_switch_pos == 0 then
            simDR_altimeter_baro_inHg = math.min(34.00, simDR_altimeter_baro_inHg + 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_capt_switch_pos == 1 then
            B747DR_efis_baro_capt_preselect = math.min(34.00, B747DR_efis_baro_capt_preselect + 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 1
        end
    end
end

function B747_efis_baro_set_capt_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_baro_capt_set_dial_pos = B747DR_efis_baro_capt_set_dial_pos - 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_capt_switch_pos == 0 then
            simDR_altimeter_baro_inHg = math.max(26.00, simDR_altimeter_baro_inHg - 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_capt_switch_pos == 1 then
            B747DR_efis_baro_capt_preselect = math.max(26.00, B747DR_efis_baro_capt_preselect - 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 1
        end
    elseif phase == 1 and duration > 0.5 then  
        B747DR_efis_baro_capt_set_dial_pos = B747DR_efis_baro_capt_set_dial_pos - 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_capt_switch_pos == 0 then
            simDR_altimeter_baro_inHg = math.max(26.00, simDR_altimeter_baro_inHg - 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_capt_switch_pos == 1 then
            B747DR_efis_baro_capt_preselect = math.max(26.00, B747DR_efis_baro_capt_preselect - 0.01)
            B747DR_efis_baro_std_capt_show_preselect = 1
        end
    end
end


local function B747_baro_std_capt(phase)
    if phase == 0 then
        B747DR_efis_baro_std_capt_switch_pos = 1.0 -  B747DR_efis_baro_std_capt_switch_pos
        if B747DR_efis_baro_std_capt_switch_pos == 0 then
            simDR_altimeter_baro_inHg = B747DR_efis_baro_capt_preselect
            B747DR_efis_baro_std_capt_show_preselect = 0
        elseif B747DR_efis_baro_std_capt_switch_pos == 1 then
            B747DR_efis_baro_capt_preselect = simDR_altimeter_baro_inHg   -- the setting before STD comes back on the next push (FCOM p.1037; NAV-06)
            simDR_altimeter_baro_inHg = 29.92
            B747DR_efis_baro_std_capt_show_preselect = 0
        end
    end
end
function B747_efis_baro_std_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    B747_baro_std_capt(phase)
end
-- the CDU's STD entry (EFIS CONTROL page BARO SET, FCOM p.1062): the same
-- push, also with the panel failed (5-2 step 5c)
function B747_cdu_baro_std_capt_CMDhandler(phase, duration)
    B747_baro_std_capt(phase)
end



-- the FPV switch: each push shows or removes the PFD's flight path vector
-- (FCOM p.1037; 5-2 step 4d: it did not latch)
function B747_efis_fpv_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_fpv_capt_switch_pos = 1
        B747DR_efis_fpv_capt_selected = 1 - B747DR_efis_fpv_capt_selected
    elseif phase == 2 then
        B747DR_efis_fpv_capt_switch_pos = 0
    end
end


function B747_efis_meters_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_efis_meters_capt_switch_pos = 1
        B747DR_efis_meters_capt_selected = 1.0 - B747DR_efis_meters_capt_selected
    elseif phase == 2 then
        B747DR_efis_meters_capt_switch_pos = 0
    end
end






-- EFIS CONTROLS (FIRST OFFICER)
function B747_efis_min_ref_alt_fo_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_min_ref_alt_fo_sel_dial_pos = math.min(B747DR_efis_min_ref_alt_fo_sel_dial_pos+1, 1)
    end
end

function B747_efis_min_ref_alt_fo_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_min_ref_alt_fo_sel_dial_pos = math.max(B747DR_efis_min_ref_alt_fo_sel_dial_pos-1, 0)
    end
end


function B747_efis_ref_alt_fo_set_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_ref_alt_fo_set_dial_pos = B747DR_efis_ref_alt_fo_set_dial_pos + 0.1
        if B747DR_efis_min_ref_alt_fo_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_fo = math.min(simDR_radio_alt_DH_fo + 1.0,1000)
        elseif B747DR_efis_min_ref_alt_fo_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_fo = math.min(B747DR_efis_baro_alt_ref_fo + 1.0,10000)
        end
    elseif phase == 1 and duration > 1.0 then
        B747DR_efis_ref_alt_fo_set_dial_pos = B747DR_efis_ref_alt_fo_set_dial_pos + 0.1
        if B747DR_efis_min_ref_alt_fo_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_fo = math.min(simDR_radio_alt_DH_fo + 10.0,1000)
        elseif B747DR_efis_min_ref_alt_fo_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_fo = math.min(B747DR_efis_baro_alt_ref_fo + 10.0,10000)
        end
    end
end

function B747_efis_ref_alt_fo_set_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_ref_alt_fo_set_dial_pos = B747DR_efis_ref_alt_fo_set_dial_pos - 0.1
        if B747DR_efis_min_ref_alt_fo_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_fo = math.max(simDR_radio_alt_DH_fo - 1.0,-1)
        elseif B747DR_efis_min_ref_alt_fo_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_fo = math.max(B747DR_efis_baro_alt_ref_fo - 1.0,-101)
        end
    elseif phase == 1 and duration > 1.0 then
        B747DR_efis_ref_alt_fo_set_dial_pos = B747DR_efis_ref_alt_fo_set_dial_pos - 0.1
        if B747DR_efis_min_ref_alt_fo_sel_dial_pos == 0 then                                          -- RADIO ALT
            simDR_radio_alt_DH_fo = math.max(simDR_radio_alt_DH_fo - 10.0,-1)
        elseif B747DR_efis_min_ref_alt_fo_sel_dial_pos == 1 then                                      -- BARO ALT
            B747DR_efis_baro_alt_ref_fo = math.max(B747DR_efis_baro_alt_ref_fo - 10.0,-101)
        end
    end
end


function B747_efis_dh_fo_reset_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_dh_reset_fo_switch_pos = 1
        B747_dh_rst_fo = true
    elseif phase == 2 then
        B747DR_efis_dh_reset_fo_switch_pos = 0
    end
end
function B747_cdu_dh_reset_fo_CMDhandler(phase, duration)
    if phase == 0 then B747_dh_rst_fo = true end
end

function B747_efis_baro_ref_fo_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_baro_ref_fo_sel_dial_pos = math.min(B747DR_efis_baro_ref_fo_sel_dial_pos + 1, 1)
    end
end

function B747_efis_baro_ref_fo_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_baro_ref_fo_sel_dial_pos = math.max(B747DR_efis_baro_ref_fo_sel_dial_pos - 1, 0)
    end
end

function B747_efis_baro_set_fo_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_baro_fo_set_dial_pos = B747DR_efis_baro_fo_set_dial_pos + 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_fo_switch_pos == 0 then
            simDR_altimeter_baro_inHg_fo = math.min(34.00, simDR_altimeter_baro_inHg_fo + 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 0 
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_fo_switch_pos == 1 then
            B747DR_efis_baro_fo_preselect = math.min(34.00, B747DR_efis_baro_fo_preselect + 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 1
        end
    elseif phase == 1 and duration > 0.5 then
        B747DR_efis_baro_fo_set_dial_pos = B747DR_efis_baro_fo_set_dial_pos + 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_fo_switch_pos == 0 then
            simDR_altimeter_baro_inHg_fo = math.min(34.00, simDR_altimeter_baro_inHg_fo + 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 0 
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_fo_switch_pos == 1 then
            B747DR_efis_baro_fo_preselect = math.min(34.00, B747DR_efis_baro_fo_preselect + 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 1
        end
    end
end

function B747_efis_baro_set_fo_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_baro_fo_set_dial_pos = B747DR_efis_baro_fo_set_dial_pos - 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_fo_switch_pos == 0 then
            simDR_altimeter_baro_inHg_fo = math.max(26.00, simDR_altimeter_baro_inHg_fo - 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_fo_switch_pos == 1 then
            B747DR_efis_baro_fo_preselect = math.max(26.00, B747DR_efis_baro_fo_preselect - 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 1
        end
    elseif phase == 1 and duration > 0.5 then
        B747DR_efis_baro_fo_set_dial_pos = B747DR_efis_baro_fo_set_dial_pos - 0.01
        -- NORMAL BARO ADJUST
        if B747DR_efis_baro_std_fo_switch_pos == 0 then
            simDR_altimeter_baro_inHg_fo = math.max(26.00, simDR_altimeter_baro_inHg_fo - 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 0
        -- PRESELECT BARO ADJUST
        elseif B747DR_efis_baro_std_fo_switch_pos == 1 then
            B747DR_efis_baro_fo_preselect = math.max(26.00, B747DR_efis_baro_fo_preselect - 0.01)
            B747DR_efis_baro_std_fo_show_preselect = 1
        end
    end
end


local function B747_baro_std_fo(phase)
    if phase == 0 then
        B747DR_efis_baro_std_fo_switch_pos = 1.0 -  B747DR_efis_baro_std_fo_switch_pos
        if B747DR_efis_baro_std_fo_switch_pos == 0 then
            simDR_altimeter_baro_inHg_fo = B747DR_efis_baro_fo_preselect
            B747DR_efis_baro_std_fo_show_preselect = 0
        elseif B747DR_efis_baro_std_fo_switch_pos == 1 then
            B747DR_efis_baro_fo_preselect = simDR_altimeter_baro_inHg_fo   -- the setting before STD (NAV-06)
            simDR_altimeter_baro_inHg_fo = 29.92
            B747DR_efis_baro_std_fo_show_preselect = 0
        end
    end
end
function B747_efis_baro_std_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    B747_baro_std_fo(phase)
end
function B747_cdu_baro_std_fo_CMDhandler(phase, duration)
    B747_baro_std_fo(phase)
end



function B747_efis_fpv_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_fpv_fo_switch_pos = 1
        B747DR_efis_fpv_fo_selected = 1 - B747DR_efis_fpv_fo_selected
    elseif phase == 2 then
        B747DR_efis_fpv_fo_switch_pos = 0
    end
end


function B747_efis_meters_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_efis_meters_fo_switch_pos = 1
        B747DR_efis_meters_fo_selected = 1.0 - B747DR_efis_meters_fo_selected
    elseif phase == 2 then
        B747DR_efis_meters_fo_switch_pos = 0
    end
end





-- ND CONTROLS
local B747_center_status_old_cpt = 0
local B747_center_status_old_fo = 0
-- 744 Map Mode. 0=APP,1=VOR,2=Map,3=Plan
-- XP Map mode. 0=approach, 1=vor,2=map,3=nav,4=plan
function B747_nd_mode_capt_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747_center_status_old_cpt = B747_nd_map_center_capt
        B747DR_nd_mode_capt_sel_dial_pos = math.min(B747DR_nd_mode_capt_sel_dial_pos+1, 3)
        if B747DR_nd_mode_capt_sel_dial_pos == 3 then
            B747_nd_map_center_capt = 1
        else
            B747_nd_map_center_capt = B747_center_status_old_cpt
        end
        if B747DR_nd_mode_capt_sel_dial_pos == 0 then
            simDR_EFIS_map_mode=0
        elseif B747DR_nd_mode_capt_sel_dial_pos < 3 then
            simDR_EFIS_map_mode=2
        else
            simDR_EFIS_map_mode=4
        end
    end
end

function B747_nd_mode_capt_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747_center_status_old_cpt = B747_nd_map_center_capt
        B747DR_nd_mode_capt_sel_dial_pos = math.max(B747DR_nd_mode_capt_sel_dial_pos-1, 0)
        simDR_EFIS_map_mode = 2
        if B747DR_nd_mode_capt_sel_dial_pos == 2 then
            B747_nd_map_center_capt = 0
        else
            B747_nd_map_center_capt = B747_center_status_old_cpt
        end
        if B747DR_nd_mode_capt_sel_dial_pos == 0 then
            simDR_EFIS_map_mode=0
        elseif B747DR_nd_mode_capt_sel_dial_pos < 3 then
            simDR_EFIS_map_mode=2
        else
            simDR_EFIS_map_mode=4
        end
    end
end


function B747_nd_range_capt_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_range_capt_sel_dial_pos = math.min(B747DR_nd_range_capt_sel_dial_pos+1, 6)
        simDR_EFIS_map_range = B747DR_nd_range_capt_sel_dial_pos
        --B747DR_nd_range_fo_sel_dial_pos = B747DR_nd_range_capt_sel_dial_pos
    end
end

function B747_nd_range_capt_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_range_capt_sel_dial_pos = math.max(B747DR_nd_range_capt_sel_dial_pos-1, 0)
        simDR_EFIS_map_range = B747DR_nd_range_capt_sel_dial_pos
        --B747DR_nd_range_fo_sel_dial_pos = B747DR_nd_range_capt_sel_dial_pos
    end
end


function B747_nd_center_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_center_capt_switch_pos = 1
        if B747DR_nd_mode_capt_sel_dial_pos < 3 then
            B747_nd_map_center_capt = 1.0 - B747_nd_map_center_capt
            --B747_nd_map_center_fo = B747_nd_map_center_capt
        end
    elseif phase == 2 then
        B747DR_nd_center_capt_switch_pos = 0
    end
end


function B747_nd_traffic_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_traffic_capt_switch_pos = 1
        B747DR_nd_capt_tfc_pushes = B747DR_nd_capt_tfc_pushes + 1
    elseif phase == 2 then
        B747DR_nd_traffic_capt_switch_pos = 0
    end
end




function B747_nd_wxr_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_wxr_capt_switch_pos = 1
        simCMD_EFIS_wxr:once()
    elseif phase == 2 then
        B747DR_nd_wxr_capt_switch_pos = 0
    end
end

function B747_nd_sta_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_sta_capt_switch_pos = 1
        --simCMD_EFIS_vor:once()
        --simCMD_EFIS_ndb:once()
        B747DR_nd_capt_vor_ndb = 1.0 - B747DR_nd_capt_vor_ndb
    elseif phase == 2 then
        B747DR_nd_sta_capt_switch_pos = 0
    end
end

function B747_nd_wpt_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_wpt_capt_switch_pos = 1
        B747DR_nd_capt_wpt = 1.0 - B747DR_nd_capt_wpt
    elseif phase == 2 then
        B747DR_nd_wpt_capt_switch_pos = 0
    end
end

function B747_nd_arpt_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_arpt_capt_switch_pos = 1
        --simCMD_EFIS_apt:once()
	B747DR_nd_capt_apt = 1.0 - B747DR_nd_capt_apt
    elseif phase == 2 then
        B747DR_nd_arpt_capt_switch_pos = 0
    end
end

function B747_nd_data_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_data_capt_switch_pos = 1
        B747DR_nd_capt_data = 1.0 - B747DR_nd_capt_data
    elseif phase == 2 then
        B747DR_nd_data_capt_switch_pos = 0
    end
end

function B747_nd_pos_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_pos_capt_switch_pos = 1
        B747DR_nd_capt_pos = 1.0 - B747DR_nd_capt_pos
    elseif phase == 2 then
        B747DR_nd_pos_capt_switch_pos = 0
    end
end

function B747_nd_terr_capt_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(0) then return end
    if phase == 0 then
        B747DR_nd_terr_capt_switch_pos = 1
        B747DR_nd_capt_terr=1.0-B747DR_nd_capt_terr
    elseif phase == 2 then
        B747DR_nd_terr_capt_switch_pos = 0
    end
end







function B747_nd_mode_fo_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        --B747_center_status_old = B747_nd_map_center_capt
	B747_center_status_old_fo = B747_nd_map_center_fo
        B747DR_nd_mode_fo_sel_dial_pos = math.min(B747DR_nd_mode_fo_sel_dial_pos+1, 3)
       if B747DR_nd_mode_fo_sel_dial_pos == 3 then
            B747_nd_map_center_fo = 1
        else
            B747_nd_map_center_fo = B747_center_status_old_fo
        end
        if B747DR_nd_mode_fo_sel_dial_pos == 0 then
            simDR_EFIS_map_mode_copilot=0
        elseif B747DR_nd_mode_fo_sel_dial_pos < 3 then
            simDR_EFIS_map_mode_copilot=2
        else
            simDR_EFIS_map_mode_copilot=4
        end
    end
end

function B747_nd_mode_fo_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
	B747_center_status_old_fo = B747_nd_map_center_fo
        B747DR_nd_mode_fo_sel_dial_pos = math.max(B747DR_nd_mode_fo_sel_dial_pos-1, 0)
       simDR_EFIS_map_mode_copilot = 2
        if B747DR_nd_mode_fo_sel_dial_pos == 2 then
            B747_nd_map_center_fo = 0
        else
            B747_nd_map_center_fo = B747_center_status_old_fo
        end
        if B747DR_nd_mode_fo_sel_dial_pos == 0 then
            simDR_EFIS_map_mode_copilot=0
        elseif B747DR_nd_mode_fo_sel_dial_pos < 3 then
            simDR_EFIS_map_mode_copilot=2
        else
            simDR_EFIS_map_mode_copilot=4
        end
    end
end


function B747_nd_range_fo_sel_dial_up_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_range_fo_sel_dial_pos = math.min(B747DR_nd_range_fo_sel_dial_pos+1, 6)
        simDR_EFIS_map_range_copilot = B747DR_nd_range_fo_sel_dial_pos
        --B747DR_nd_range_fo_sel_dial_pos = B747DR_nd_range_fo_sel_dial_pos
    end
end

function B747_nd_range_fo_sel_dial_dn_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_range_fo_sel_dial_pos = math.max(B747DR_nd_range_fo_sel_dial_pos-1, 0)
        simDR_EFIS_map_range_copilot = B747DR_nd_range_fo_sel_dial_pos
        --B747DR_nd_range_capt_sel_dial_pos = B747DR_nd_range_fo_sel_dial_pos
    end
end



function B747_nd_center_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_center_fo_switch_pos = 1
        if B747DR_nd_mode_fo_sel_dial_pos < 3 then
            B747_nd_map_center_fo = 1.0 - B747_nd_map_center_fo
            --B747_nd_map_center_capt = B747_nd_map_center_fo
        end
    elseif phase == 2 then
        B747DR_nd_center_fo_switch_pos = 0
    end
end

function B747_nd_traffic_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_traffic_fo_switch_pos = 1
        B747DR_nd_fo_tfc_pushes = B747DR_nd_fo_tfc_pushes + 1
    elseif phase == 2 then
        B747DR_nd_traffic_fo_switch_pos = 0
    end
end



function B747_nd_wxr_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_wxr_fo_switch_pos = 1
        if simDR_version>=120012 then
            simCMD_EFIS_wxr_fo:once()
        else
            simCMD_EFIS_wxr:once()
        end
        
    elseif phase == 2 then
        B747DR_nd_wxr_fo_switch_pos = 0
    end
end

function B747_nd_sta_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_sta_fo_switch_pos = 1
        --simCMD_EFIS_vor:once()
        --simCMD_EFIS_ndb:once()
        B747DR_nd_fo_vor_ndb = 1.0 - B747DR_nd_fo_vor_ndb
	
    elseif phase == 2 then
        B747DR_nd_sta_fo_switch_pos = 0
    end
end

function B747_nd_wpt_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_wpt_fo_switch_pos = 1
        B747DR_nd_fo_wpt = 1.0 - B747DR_nd_fo_wpt
    elseif phase == 2 then
        B747DR_nd_wpt_fo_switch_pos = 0
    end
end

function B747_nd_arpt_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_arpt_fo_switch_pos = 1
        --simCMD_EFIS_apt:once()
	B747DR_nd_fo_apt = 1.0 - B747DR_nd_fo_apt
    elseif phase == 2 then
        B747DR_nd_arpt_fo_switch_pos = 0
    end
end

function B747_nd_data_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_data_fo_switch_pos = 1
        B747DR_nd_fo_data = 1.0 - B747DR_nd_fo_data
    elseif phase == 2 then
        B747DR_nd_data_fo_switch_pos = 0
    end
end

function B747_nd_pos_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_pos_fo_switch_pos = 1
        B747DR_nd_fo_pos = 1.0 - B747DR_nd_fo_pos
    elseif phase == 2 then
        B747DR_nd_pos_fo_switch_pos = 0
    end
end

function B747_nd_terr_fo_switch_CMDhandler(phase, duration)
    if not efis_panel_ok(1) then return end
    if phase == 0 then
        B747DR_nd_terr_fo_switch_pos = 1
        B747DR_nd_fo_terr=1.0-B747DR_nd_fo_terr
    elseif phase == 2 then
        B747DR_nd_terr_fo_switch_pos = 0
    end
end




-- DISPLAY SELECT PANEL
function B747_dsp_eng_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_eng_switch_pos = 1
        if B747DR_dsp_synoptic_display == 1 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 1 end
    elseif phase == 2 then
        B747DR_dsp_eng_switch_pos = 0
    end
end

function B747_dsp_stat_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_stat_switch_pos = 1
        if B747DR_dsp_synoptic_display == 2 then
            if B747DR_STAT_msg_page == B747DR_STAT_num_msg_pages then
                B747DR_dsp_synoptic_display = 0
            else
                B747DR_STAT_msg_page = B747DR_STAT_msg_page + 1
            end
        else
            B747DR_dsp_synoptic_display = 2
            B747DR_STAT_msg_page = 1
        end
    elseif phase == 2 then
        B747DR_dsp_stat_switch_pos = 0
    end
end

function B747_dsp_elec_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_elec_switch_pos = 1
        if B747DR_dsp_synoptic_display == 3 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 3 end
    elseif phase == 2 then
        B747DR_dsp_elec_switch_pos = 0
    end
end

function B747_dsp_fuel_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_fuel_switch_pos = 1
        if B747DR_dsp_synoptic_display == 4 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 4 end
    elseif phase == 2 then
        B747DR_dsp_fuel_switch_pos = 0
    end
end

function B747_dsp_ecs_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_ecs_switch_pos = 1
        if B747DR_dsp_synoptic_display == 5 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 5 end
    elseif phase == 2 then
        B747DR_dsp_ecs_switch_pos = 0
    end
end

function B747_dsp_hyd_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_hyd_switch_pos = 1
        if B747DR_dsp_synoptic_display == 6 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 6 end
    elseif phase == 2 then
        B747DR_dsp_hyd_switch_pos = 0
    end
end

function B747_dsp_drs_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_drs_switch_pos = 1
        if B747DR_dsp_synoptic_display == 7 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 7 end
    elseif phase == 2 then
        B747DR_dsp_drs_switch_pos = 0
    end
end

function B747_dsp_gear_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_gear_switch_pos = 1
        if B747DR_dsp_synoptic_display == 8 then B747DR_dsp_synoptic_display = 0 else B747DR_dsp_synoptic_display = 8 end
    elseif phase == 2 then
        B747DR_dsp_gear_switch_pos = 0
    end
end

function B747_dsp_canc_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_canc_switch_pos = 1
        B747DR_CAS_canc_count = B747DR_CAS_canc_count + 1
    elseif phase == 2 then
        B747DR_dsp_canc_switch_pos = 0
    end
end



function B747_CAS_canx_recall_display()
    B747DR_CAS_recall_ind = 0
end

function B747_dsp_rcl_switch_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_dsp_rcl_switch_pos = 1
        B747DR_CAS_rcl_count = B747DR_CAS_rcl_count + 1
        B747DR_CAS_recall_ind = 1
    elseif phase == 2 then
        B747DR_dsp_rcl_switch_pos = 0
        if is_timer_scheduled(B747_CAS_canx_recall_display) == false then
            run_after_time(B747_CAS_canx_recall_display, 1.0)
        else
            stop_timer(B747_CAS_canx_recall_display)
            run_after_time(B747_CAS_canx_recall_display, 1.0)
        end
    end
end






function B747_ai_fltinst_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
    	 B747_set_inst_all_modes()
    	 B747_set_inst_CD()
    	 B747_set_inst_ER()  
    end
end




--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- INSTRUMENT SOURCE SELECTORS (CAPTAIN)
B747CMD_flt_inst_fd_src_capt_dial_up        = deferred_command("laminar/B747/flt_inst/flt_dir_src/capt/sel_dial_up", "Flight Inst Flight Director Source Captain Up", B747_flt_inst_fd_src_capt_dial_up_CMDhandler)
B747CMD_flt_inst_fd_src_capt_dial_dn        = deferred_command("laminar/B747/flt_inst/flt_dir_src/capt/sel_dial_dn", "Flight Inst Flight Director Source Captain Down", B747_flt_inst_fd_src_capt_dial_dn_CMDhandler)

B747CMD_flt_inst_nav_src_capt_dial_up       = deferred_command("laminar/B747/flt_inst/nav_src/capt/sel_dial_up", "Flight Inst NAV Source Captain Up", B747_inst_src_capt_nav_up_CMDhandler)
B747CMD_flt_inst_nav_src_capt_dial_dn       = deferred_command("laminar/B747/flt_inst/nav_src/capt/sel_dial_dn", "Flight Inst NAV Source Captain Down", B747_inst_src_capt_nav_dn_CMDhandler)

B747CMD_flt_inst_eiu_src_capt_dial_up       = deferred_command("laminar/B747/flt_inst/eiu_src/capt/sel_dial_up", "Flight Inst EIU Source Captain Up", B747_inst_src_capt_eiu_up_CMDhandler)
B747CMD_flt_inst_eiu_src_capt_dial_dn       = deferred_command("laminar/B747/flt_inst/eiu_src/capt/sel_dial_dn", "Flight Inst EIU Source Captain Down", B747_inst_src_capt_eiu_dn_CMDhandler)

B747CMD_flt_inst_irs_src_capt_dial_up       = deferred_command("laminar/B747/flt_inst/irs_src/capt/sel_dial_up", "Flight Inst IRS Source Captain Up", B747_inst_src_capt_irs_up_CMDhandler)
B747CMD_flt_inst_irs_src_capt_dial_dn       = deferred_command("laminar/B747/flt_inst/irs_src/capt/sel_dial_dn", "Flight Inst IRS Source Captain Down", B747_inst_src_capt_irs_dn_CMDhandler)

B747CMD_flt_inst_air_data_src_capt_dial_up  = deferred_command("laminar/B747/flt_inst/air_data_src/capt/sel_dial_up", "Flight Inst Air Data Source Captain Up", B747_inst_src_capt_air_data_up_CMDhandler)
B747CMD_flt_inst_air_data_src_capt_dial_dn  = deferred_command("laminar/B747/flt_inst/air_data_src/capt/sel_dial_dn", "Flight Inst Air Data Source Captain Down", B747_inst_src_capt_air_data_dn_CMDhandler)




-- INSTRUMENT SOURCE SELECTORS (FIRST OFFICER)
B747CMD_flt_inst_fd_src_fo_dial_up          = deferred_command("laminar/B747/flt_inst/flt_dir_src/fo/sel_dial_up", "Flight Inst Flight Director Source First Officer Up", B747_flt_inst_fd_src_fo_dial_up_CMDhandler)
B747CMD_flt_inst_fd_src_fo_dial_dn          = deferred_command("laminar/B747/flt_inst/flt_dir_src/fo/sel_dial_dn", "Flight Inst Flight Director Source First Officer Down", B747_flt_inst_fd_src_fo_dial_dn_CMDhandler)

B747CMD_flt_inst_nav_src_fo_dial_up         = deferred_command("laminar/B747/flt_inst/nav_src/fo/sel_dial_up", "Flight Inst NAV Source First Officer Up", B747_inst_src_fo_nav_up_CMDhandler)
B747CMD_flt_inst_nav_src_fo_dial_dn         = deferred_command("laminar/B747/flt_inst/nav_src/fo/sel_dial_dn", "Flight Inst NAV Source First Officer Down", B747_inst_src_fo_nav_dn_CMDhandler)

B747CMD_flt_inst_eiu_src_fo_dial_up         = deferred_command("laminar/B747/flt_inst/eiu_src/fo/sel_dial_up", "Flight Inst EIU Source First Officer Up", B747_inst_src_fo_eiu_up_CMDhandler)
B747CMD_flt_inst_eiu_src_fo_dial_dn         = deferred_command("laminar/B747/flt_inst/eiu_src/fo/sel_dial_dn", "Flight Inst EIU Source First Officer Down", B747_inst_src_fo_eiu_dn_CMDhandler)

B747CMD_flt_inst_irs_src_fo_dial_up         = deferred_command("laminar/B747/flt_inst/irs_src/fo/sel_dial_up", "Flight Inst IRS Source First Officer Up", B747_inst_src_fo_irs_up_CMDhandler)
B747CMD_flt_inst_irs_src_fo_dial_dn         = deferred_command("laminar/B747/flt_inst/irs_src/fo/sel_dial_dn", "Flight Inst IRS Source First Officer Down", B747_inst_src_fo_irs_dn_CMDhandler)

B747CMD_flt_inst_air_data_src_fo_dial_up    = deferred_command("laminar/B747/flt_inst/air_data_src/fo/sel_dial_up", "Flight Inst Air Data Source First Officer Up", B747_inst_src_fo_air_data_up_CMDhandler)
B747CMD_flt_inst_air_data_src_fo_dial_dn    = deferred_command("laminar/B747/flt_inst/air_data_src/fo/sel_dial_dn", "Flight Inst Air Data Source First Officer Down", B747_inst_src_fo_air_data_dn_CMDhandler)





-- INSTRUMENT SOURCE SELECTORS (CENTER PANEL)
B747CMD_flt_inst_eiu_src_ctr_pnl_dial_up    = deferred_command("laminar/B747/flt_inst/eiu_src/ctr_pnl/sel_dial_up", "Flight Inst Center Panel EIU Up", B747_flt_inst_eiu_src_ctr_pnl_dial_up_CMDhandler)
B747CMD_flt_inst_eiu_src_ctr_pnl_dial_dn    = deferred_command("laminar/B747/flt_inst/eiu_src/ctr_pnl/sel_dial_dn", "Flight Inst Center Panel EIU Down", B747_flt_inst_eiu_src_ctr_pnl_dial_dn_CMDhandler)

B747CMD_flt_inst_fmc_master_src_ctr_pnl_sel = deferred_command("laminar/B747/flt_inst/fmc_master_src/ctr_pnl/sel_dial", "Flight Instr Center Panel FMC Master Selector", B747_flt_inst_fmc_master_src_ctr_pnl_sel_CMDhandler)






-- DISPLAY SELECTORS (CAPTAIN)
B747CMD_flt_inst_inbd_disp_capt_sel_dial_up = deferred_command("laminar/B747/flt_inst/capt_inbd_display/sel_dial_up", "Flight Inst Captain Inboard Display Selector Up", B747_flt_inst_inbd_disp_capt_sel_dial_up_CMDhandler)
B747CMD_flt_inst_inbd_disp_capt_sel_dial_dn = deferred_command("laminar/B747/flt_inst/capt_inbd_display/sel_dial_dn", "Flight Inst Captain Inboard Display Selector Down", B747_flt_inst_inbd_disp_capt_sel_dial_dn_CMDhandler)

B747CMD_flt_inst_lwr_disp_capt_sel_dial_up  = deferred_command("laminar/B747/flt_inst/capt_lwr_display/sel_dial_up", "Flight Inst Captain Lower Display Selector Up", B747_flt_inst_lwr_disp_capt_sel_dial_up_CMDhandler)
B747CMD_flt_inst_lwr_disp_capt_sel_dial_dn  = deferred_command("laminar/B747/flt_inst/capt_lwr_display/sel_dial_dn", "Flight Inst Captain Lower Display Selector Down", B747_flt_inst_lwr_disp_capt_sel_dial_dn_CMDhandler)



-- DISPLAY SELECTORS (FIRST OFFICER)
B747CMD_flt_inst_inbd_disp_fo_sel_dial_up   = deferred_command("laminar/B747/flt_inst/fo_inbd_display/sel_dial_up", "Flight Inst First Officer Inboard Display Selector Up", B747_flt_inst_inbd_disp_fo_sel_dial_up_CMDhandler)
B747CMD_flt_inst_inbd_disp_fo_sel_dial_dn   = deferred_command("laminar/B747/flt_inst/fo_inbd_display/sel_dial_dn", "Flight Inst First Officer Inboard Display Selector Down", B747_flt_inst_inbd_disp_fo_sel_dial_dn_CMDhandler)

B747CMD_flt_inst_lwr_disp_fo_sel_dial_up    = deferred_command("laminar/B747/flt_inst/fo_lwr_display/sel_dial_up", "Flight Inst First Officer Lower Display Selector Up", B747_flt_inst_lwr_disp_fo_sel_dial_up_CMDhandler)
B747CMD_flt_inst_lwr_disp_fo_sel_dial_dn    = deferred_command("laminar/B747/flt_inst/fo_lwr_display/sel_dial_dn", "Flight Inst First Officer Lower Display Selector Down", B747_flt_inst_lwr_disp_fo_sel_dial_dn_CMDhandler)




-- EFIS CONTROLS (CAPTAIN)
B747CMD_efis_min_ref_alt_capt_sel_dial_up   = deferred_command("laminar/B747/efis/min_ref_alt/capt/sel_dial_up", "EFIS Altitude Minimums Ref Selector Up", B747_efis_min_ref_alt_capt_sel_dial_up_CMDhandler)
B747CMD_efis_min_ref_alt_capt_sel_dial_dn   = deferred_command("laminar/B747/efis/min_ref_alt/capt/sel_dial_dn", "EFIS Altitude Minimums Ref Selector Down", B747_efis_min_ref_alt_capt_sel_dial_dn_CMDhandler)

B747CMD_efis_ref_alt_capt_set_dial_up       = deferred_command("laminar/B747/efis/ref_alt/capt/set_dial_up", "EFIS Altitude Ref Set Dial Up", B747_efis_ref_alt_capt_set_dial_up_CMDhandler)
B747CMD_efis_ref_alt_capt_set_dial_dn       = deferred_command("laminar/B747/efis/ref_alt/capt/set_dial_dn", "EFIS Altitude Ref Set Dial Down", B747_efis_ref_alt_capt_set_dial_dn_CMDhandler)

B747DR_efis_min_alt_ctrl_fo_rheo            = deferred_dataref("laminar/B747/efis/min_alt_ctrl/fo/rheostat", "number", B747_efis_min_alt_ctrl_fo_rheo)

B747CMD_efis_dh_capt_reset_switch           = deferred_command("laminar/B747/efis/dh/capt/reset_switch", "EFIS Decision Height Reset Switch", B747_efis_dh_capt_reset_switch_CMDhandler)

B747CMD_efis_baro_ref_capt_sel_dial_up      = deferred_command("laminar/B747/efis/baro_ref/capt/sel_dial_up", "EFIS BARO Ref Selector Up", B747_efis_baro_ref_capt_sel_dial_up_CMDhandler)
B747CMD_efis_baro_ref_capt_sel_dial_dn      = deferred_command("laminar/B747/efis/baro_ref/capt/sel_dial_dn", "EFIS BARO Ref Selector Down", B747_efis_baro_ref_capt_sel_dial_dn_CMDhandler)
B747CMD_efis_baro_set_capt_sel_dial_up      = deferred_command("laminar/B747/efis/baro_set/capt/sel_dial_up", "EFIS BARO Set Selector Up", B747_efis_baro_set_capt_sel_dial_up_CMDhandler)
B747CMD_efis_baro_set_capt_sel_dial_dn      = deferred_command("laminar/B747/efis/baro_set/capt/sel_dial_dn", "EFIS BARO Set Selector Down", B747_efis_baro_set_capt_sel_dial_dn_CMDhandler)
B747CMD_efis_baro_std_capt_switch           = deferred_command("laminar/B747/efis/baro_std/capt/switch", "EFIS BARO STD Switch", B747_efis_baro_std_capt_switch_CMDhandler)
B747CMD_cdu_baro_std_capt                   = deferred_command("laminar/B747/efis/baro_std/capt/cdu", "CDU EFIS CONTROL BARO STD", B747_cdu_baro_std_capt_CMDhandler)
B747CMD_cdu_dh_reset_capt                   = deferred_command("laminar/B747/efis/dh/capt/cdu_reset", "CDU EFIS CONTROL DH RESET", B747_cdu_dh_reset_capt_CMDhandler)

B747CMD_efis_fpv_capt_switch                = deferred_command("laminar/B747/efis/fpv/capt/switch", "EFIS FPV Switch", B747_efis_fpv_capt_switch_CMDhandler)
B747CMD_efis_meters_capt_switch             = deferred_command("laminar/B747/efis/meters/capt/switch", "EFIS Meters Switch", B747_efis_meters_capt_switch_CMDhandler)




-- EFIS CONTROLS (FIRST OFFICER)
B747CMD_efis_min_ref_alt_fo_sel_dial_up     = deferred_command("laminar/B747/efis/min_ref_alt/fo/sel_dial_up", "EFIS Altitude Minimums Ref Selector Up", B747_efis_min_ref_alt_fo_sel_dial_up_CMDhandler)
B747CMD_efis_min_ref_alt_fo_sel_dial_dn     = deferred_command("laminar/B747/efis/min_ref_alt/fo/sel_dial_dn", "EFIS Altitude Minimums Ref Selector Down", B747_efis_min_ref_alt_fo_sel_dial_dn_CMDhandler)

B747CMD_efis_ref_alt_fo_set_dial_up         = deferred_command("laminar/B747/efis/ref_alt/fo/set_dial_up", "EFIS Altitude Ref Set Dial Up", B747_efis_ref_alt_fo_set_dial_up_CMDhandler)
B747CMD_efis_ref_alt_fo_set_dial_dn         = deferred_command("laminar/B747/efis/ref_alt/fo/set_dial_dn", "EFIS Altitude Ref Set Dial Down", B747_efis_ref_alt_fo_set_dial_dn_CMDhandler)

B747CMD_efis_dh_fo_reset_switch             = deferred_command("laminar/B747/efis/dh/fo/reset_switch", "EFIS Decision Height Reset Switch", B747_efis_dh_fo_reset_switch_CMDhandler)

B747CMD_efis_baro_ref_fo_sel_dial_up        = deferred_command("laminar/B747/efis/baro_ref/fo/sel_dial_up", "EFIS BARO Ref Selector Up", B747_efis_baro_ref_fo_sel_dial_up_CMDhandler)
B747CMD_efis_baro_ref_fo_sel_dial_dn        = deferred_command("laminar/B747/efis/baro_ref/fo/sel_dial_dn", "EFIS BARO Ref Selector Down", B747_efis_baro_ref_fo_sel_dial_dn_CMDhandler)
B747CMD_efis_baro_set_fo_sel_dial_up        = deferred_command("laminar/B747/efis/baro_set/fo/sel_dial_up", "EFIS BARO Set Selector Up", B747_efis_baro_set_fo_sel_dial_up_CMDhandler)
B747CMD_efis_baro_set_fo_sel_dial_dn        = deferred_command("laminar/B747/efis/baro_set/fo/sel_dial_dn", "EFIS BARO Set Selector Down", B747_efis_baro_set_fo_sel_dial_dn_CMDhandler)
B747CMD_efis_baro_std_fo_switch             = deferred_command("laminar/B747/efis/baro_std/fo/switch", "EFIS BARO STD Switch", B747_efis_baro_std_fo_switch_CMDhandler)
B747CMD_cdu_baro_std_fo                     = deferred_command("laminar/B747/efis/baro_std/fo/cdu", "CDU EFIS CONTROL BARO STD", B747_cdu_baro_std_fo_CMDhandler)
B747CMD_cdu_dh_reset_fo                     = deferred_command("laminar/B747/efis/dh/fo/cdu_reset", "CDU EFIS CONTROL DH RESET", B747_cdu_dh_reset_fo_CMDhandler)

B747CMD_efis_fpv_fo_switch                  = deferred_command("laminar/B747/efis/fpv/fo/switch", "EFIS FPV Switch", B747_efis_fpv_fo_switch_CMDhandler)
B747CMD_efis_meters_fo_switch               = deferred_command("laminar/B747/efis/meters/fo/switch", "EFIS Meters Switch", B747_efis_meters_fo_switch_CMDhandler)


-- the VOR/ADF switches: X-Plane's selector commands in the 3D cockpit (up
-- towards VOR 2, down towards ADF 0, as X-Plane's own), taken over so that a
-- failed EFIS control panel takes no input (5-2 step 5c)
function B747_efis_vor_adf_l_capt_up_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(0) then simDR_EFIS_1_sel_pilot = math.min(simDR_EFIS_1_sel_pilot + 1, 2) end
end
function B747_efis_vor_adf_l_capt_dn_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(0) then simDR_EFIS_1_sel_pilot = math.max(simDR_EFIS_1_sel_pilot - 1, 0) end
end
function B747_efis_vor_adf_r_capt_up_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(0) then simDR_EFIS_2_sel_pilot = math.min(simDR_EFIS_2_sel_pilot + 1, 2) end
end
function B747_efis_vor_adf_r_capt_dn_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(0) then simDR_EFIS_2_sel_pilot = math.max(simDR_EFIS_2_sel_pilot - 1, 0) end
end
function B747_efis_vor_adf_l_fo_up_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(1) then simDR_EFIS_1_sel_fo = math.min(simDR_EFIS_1_sel_fo + 1, 2) end
end
function B747_efis_vor_adf_l_fo_dn_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(1) then simDR_EFIS_1_sel_fo = math.max(simDR_EFIS_1_sel_fo - 1, 0) end
end
function B747_efis_vor_adf_r_fo_up_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(1) then simDR_EFIS_2_sel_fo = math.min(simDR_EFIS_2_sel_fo + 1, 2) end
end
function B747_efis_vor_adf_r_fo_dn_CMDhandler(phase, duration)
    if phase == 0 and efis_panel_ok(1) then simDR_EFIS_2_sel_fo = math.max(simDR_EFIS_2_sel_fo - 1, 0) end
end
simCMD_EFIS_1_pilot_sel_up          = replace_command("sim/instruments/EFIS_1_pilot_sel_up", B747_efis_vor_adf_l_capt_up_CMDhandler)
simCMD_EFIS_1_pilot_sel_dn          = replace_command("sim/instruments/EFIS_1_pilot_sel_dn", B747_efis_vor_adf_l_capt_dn_CMDhandler)
simCMD_EFIS_2_pilot_sel_up          = replace_command("sim/instruments/EFIS_2_pilot_sel_up", B747_efis_vor_adf_r_capt_up_CMDhandler)
simCMD_EFIS_2_pilot_sel_dn          = replace_command("sim/instruments/EFIS_2_pilot_sel_dn", B747_efis_vor_adf_r_capt_dn_CMDhandler)
simCMD_EFIS_1_copilot_sel_up        = replace_command("sim/instruments/EFIS_1_copilot_sel_up", B747_efis_vor_adf_l_fo_up_CMDhandler)
simCMD_EFIS_1_copilot_sel_dn        = replace_command("sim/instruments/EFIS_1_copilot_sel_dn", B747_efis_vor_adf_l_fo_dn_CMDhandler)
simCMD_EFIS_2_copilot_sel_up        = replace_command("sim/instruments/EFIS_2_copilot_sel_up", B747_efis_vor_adf_r_fo_up_CMDhandler)
simCMD_EFIS_2_copilot_sel_dn        = replace_command("sim/instruments/EFIS_2_copilot_sel_dn", B747_efis_vor_adf_r_fo_dn_CMDhandler)



-- ND CONTROLS (CAPTAIN)
B747CMD_nd_mode_capt_sel_dial_up            = deferred_command("laminar/B747/nd/mode/capt/sel_dial_up", "ND Mode Selector Up", B747_nd_mode_capt_sel_dial_up_CMDhandler)
B747CMD_nd_mode_capt_sel_dial_dn            = deferred_command("laminar/B747/nd/mode/capt/sel_dial_dn", "ND Mode Selector Down", B747_nd_mode_capt_sel_dial_dn_CMDhandler)

B747CMD_nd_range_capt_sel_dial_up           = deferred_command("laminar/B747/nd/range/capt/sel_dial_up", "ND Range Selector Up", B747_nd_range_capt_sel_dial_up_CMDhandler)
B747CMD_nd_range_capt_sel_dial_dn           = deferred_command("laminar/B747/nd/range/capt/sel_dial_dn", "ND Range Selector Down", B747_nd_range_capt_sel_dial_dn_CMDhandler)

B747CMD_nd_center_capt_switch               = deferred_command("laminar/B747/nd/center/capt/switch", "ND Center Switch", B747_nd_center_capt_switch_CMDhandler)
B747CMD_nd_traffic_capt_switch              = deferred_command("laminar/B747/nd/traffic/capt/switch", "ND Traffic Switch", B747_nd_traffic_capt_switch_CMDhandler)

B747CMD_nd_wxr_capt_switch                  = deferred_command("laminar/B747/nd/wxr/capt/switch", "ND WXR Switch", B747_nd_wxr_capt_switch_CMDhandler)
B747CMD_nd_sta_capt_switch                  = deferred_command("laminar/B747/nd/sta/capt/switch", "ND STA Switch", B747_nd_sta_capt_switch_CMDhandler)
B747CMD_nd_wpt_capt_switch                  = deferred_command("laminar/B747/nd/wpt/capt/switch", "ND WPT Switch", B747_nd_wpt_capt_switch_CMDhandler)
B747CMD_nd_arpt_capt_switch                 = deferred_command("laminar/B747/nd/arpt/capt/switch", "ND ARPT Switch", B747_nd_arpt_capt_switch_CMDhandler)
B747CMD_nd_data_capt_switch                 = deferred_command("laminar/B747/nd/data/capt/switch", "ND DATA Switch", B747_nd_data_capt_switch_CMDhandler)
B747CMD_nd_pos_capt_switch                  = deferred_command("laminar/B747/nd/pos/capt/switch", "ND POS Switch", B747_nd_pos_capt_switch_CMDhandler)
B747CMD_nd_terr_capt_switch                 = deferred_command("laminar/B747/nd/terr/capt/switch", "ND TERR Switch", B747_nd_terr_capt_switch_CMDhandler)



-- ND CONTROLS (FIRST OFFICER)
B747CMD_nd_mode_fo_sel_dial_up              = deferred_command("laminar/B747/nd/mode/fo/sel_dial_up", "ND Mode Selector Up", B747_nd_mode_fo_sel_dial_up_CMDhandler)
B747CMD_nd_mode_fo_sel_dial_dn              = deferred_command("laminar/B747/nd/mode/fo/sel_dial_dn", "ND Mode Selector Down", B747_nd_mode_fo_sel_dial_dn_CMDhandler)

B747CMD_nd_range_fo_sel_dial_up             = deferred_command("laminar/B747/nd/range/fo/sel_dial_up", "ND Range Selector Up", B747_nd_range_fo_sel_dial_up_CMDhandler)
B747CMD_nd_range_fo_sel_dial_dn             = deferred_command("laminar/B747/nd/range/fo/sel_dial_dn", "ND Range Selector Down", B747_nd_range_fo_sel_dial_dn_CMDhandler)

B747CMD_nd_center_fo_switch                 = deferred_command("laminar/B747/nd/center/fo/switch", "ND Center Switch", B747_nd_center_fo_switch_CMDhandler)
B747CMD_nd_traffic_fo_switch                = deferred_command("laminar/B747/nd/traffic/fo/switch", "ND Traffic Switch", B747_nd_traffic_fo_switch_CMDhandler)

B747CMD_nd_wxr_fo_switch                    = deferred_command("laminar/B747/nd/wxr/fo/switch", "ND WXR Switch", B747_nd_wxr_fo_switch_CMDhandler)
B747CMD_nd_sta_fo_switch                    = deferred_command("laminar/B747/nd/sta/fo/switch", "ND STA Switch", B747_nd_sta_fo_switch_CMDhandler)
B747CMD_nd_wpt_fo_switch                    = deferred_command("laminar/B747/nd/wpt/fo/switch", "ND WPT Switch", B747_nd_wpt_fo_switch_CMDhandler)
B747CMD_nd_arpt_fo_switch                   = deferred_command("laminar/B747/nd/arpt/fo/switch", "ND ARPT Switch", B747_nd_arpt_fo_switch_CMDhandler)
B747CMD_nd_data_fo_switch                   = deferred_command("laminar/B747/nd/data/fo/switch", "ND DATA Switch", B747_nd_data_fo_switch_CMDhandler)
B747CMD_nd_pos_fo_switch                    = deferred_command("laminar/B747/nd/pos/fo/switch", "ND POS Switch", B747_nd_pos_fo_switch_CMDhandler)
B747CMD_nd_terr_fo_switch                   = deferred_command("laminar/B747/nd/terr/fo/switch", "ND TERR Switch", B747_nd_terr_fo_switch_CMDhandler)




-- DISPLAY SELECT PANEL
B747CMD_dsp_eng_switch                      = deferred_command("laminar/B747/dsp/eng_switch", "Display Select Panel ENG Switch", B747_dsp_eng_switch_CMDhandler)
B747CMD_dsp_stat_switch                     = deferred_command("laminar/B747/dsp/stat_switch", "Display Select Panel STAT Switch", B747_dsp_stat_switch_CMDhandler)
B747CMD_dsp_elec_switch                     = deferred_command("laminar/B747/dsp/elec_switch", "Display Select Panel ELEC Switch", B747_dsp_elec_switch_CMDhandler)
B747CMD_dsp_fuel_switch                     = deferred_command("laminar/B747/dsp/fuel_switch", "Display Select Panel FUEL Switch", B747_dsp_fuel_switch_CMDhandler)
B747CMD_dsp_ecs_switch                      = deferred_command("laminar/B747/dsp/ecs_switch", "Display Select Panel ECS Switch", B747_dsp_ecs_switch_CMDhandler)
B747CMD_dsp_hyd_switch                      = deferred_command("laminar/B747/dsp/hyd_switch", "Display Select Panel HYD Switch", B747_dsp_hyd_switch_CMDhandler)
B747CMD_dsp_drs_switch                      = deferred_command("laminar/B747/dsp/drs_switch", "Display Select Panel DRS Switch", B747_dsp_drs_switch_CMDhandler)
B747CMD_dsp_gear_switch                     = deferred_command("laminar/B747/dsp/gear_switch", "Display Select Panel GEAR Switch", B747_dsp_gear_switch_CMDhandler)

B747CMD_dsp_canc_switch                     = deferred_command("laminar/B747/dsp/canc_switch", "Display Select Panel CANC Switch", B747_dsp_canc_switch_CMDhandler)
B747CMD_dsp_rcl_switch                      = deferred_command("laminar/B747/dsp/rcl_switch", "Display Select Panel Recall Switch", B747_dsp_rcl_switch_CMDhandler)




-- AI
B747CMD_ai_fltinst_quick_start			= deferred_command("laminar/B747/ai/fltinst_quick_start", "number", B747_ai_fltinst_quick_start_CMDhandler)



--*************************************************************************************--
--** 					            OBJECT CONSTRUCTORS         		    		 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				               CREATE SYSTEM OBJECTS            				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

----- RESCALE FLOAT AND CLAMP TO OUTER LIMITS -------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    if in2 - in1 == 0 then return out1 + (out2 - out1) * (x - in1) end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end






----- ROUNDING --------------------------------------------------------------------------
function roundToIncrement(number, increment)

    local y = number / increment
    local q = math.floor(y + 0.5)
    local z = q * increment

    return z

end



function roundUpToIncrement(number, increment)

    local y = number / increment
    local q = math.ceil(y)
    local z = q * increment

    return z

end



function roundDownToIncrement(number, increment)

    local y = number / increment
    local q = math.floor(y)
    local z = q * increment

    return z

end



function roundUp(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end





----- RECIPROCAL ANGLE ------------------------------------------------------------------
function recipAngle(angle)
    return (angle + 180) % 360
end



















----- RMI -------------------------------------------------------------------------------
function B747_rmi()

    -- LEFT
    if simDR_rmi_captain_left_use_adf == 0 then
        B747DR_RMI_left_bearing = simDR_nav_relative_bearing_deg[2]
    elseif simDR_rmi_captain_left_use_adf == 1 then
        B747DR_RMI_left_bearing = simDR_adf1_relative_bearing_deg
    end


    --RIGHT
    if simDR_rmi_captain_right_use_adf == 0 then
        B747DR_RMI_right_bearing = simDR_nav_relative_bearing_deg[3]
    elseif simDR_rmi_captain_right_use_adf == 1 then
        B747DR_RMI_right_bearing = simDR_adf2_relative_bearing_deg
    end

end





----- MINIMUMS (DH) ---------------------------------------------------------------------
-- Each PFD's DH alert from its own radio altitude (laminar/B747/ra/capt|fo,
-- the nav module's B747.34.xt.ra.lua) and its own DH: armed by climbing
-- above DH + 75 ft, set by descending to DH, the amber DH flashing the first
-- 3 s; reset by that side's MINS RST, on landing and by climbing above
-- DH + 75 ft (ATA34_2 p.95, FCOM p.981-982). The panel shows the amber DH at
-- display_status 1 and the green DH and setting at 0 (2: the flash's dark
-- half). The radio altitude stays shown in white (FCOM p.981):
-- radio_alt/display_status (and _fo) stays 0, since at 1 the panel showed
-- neither the white nor the amber radio altitude (the digits went during the
-- alert). The minimums voices are the GPWS's (B747.34.xt.gpws.lua).
local DH_ARM_FT = 75
local DH_FLASH_S = 3
local DH_FLASH_HALF_S = 0.5
B747_dh_rst_capt, B747_dh_rst_fo = false, false
-- each side's alert (the MINS RST handlers above set B747_dh_rst_capt and
-- _fo: XTLua turns a global table into a namespace)
local B747_dh_capt = {armed = false, since = false}
local B747_dh_fo = {armed = false, since = false}

local function B747_dh_status(st, rst, ra, ra_valid, dh, on_ground, now)
    if on_ground or rst then st.since = false end
    if on_ground then st.armed = false end
    if ra_valid and dh >= 0 and not on_ground then
        if ra > dh + DH_ARM_FT then
            st.armed, st.since = true, false
        elseif st.armed and ra <= dh then
            st.armed, st.since = false, now
        end
    end
    if not st.since then return 0 end
    local e = now - st.since
    if e < DH_FLASH_S and math.floor(e / DH_FLASH_HALF_S) % 2 == 1 then return 2 end
    return 1
end

function B747_minimums()
    local now = simDR_time_now
    local on_ground = simDR_all_wheels_on_ground > 0
    local c = B747_dh_status(B747_dh_capt, B747_dh_rst_capt, B747DR_ra_capt_value, B747DR_ra_capt_flag == 0,
        simDR_radio_alt_DH_capt, on_ground, now)
    local f = B747_dh_status(B747_dh_fo, B747_dh_rst_fo, B747DR_ra_fo_value, B747DR_ra_fo_flag == 0,
        simDR_radio_alt_DH_fo, on_ground, now)
    B747_dh_rst_capt, B747_dh_rst_fo = false, false
    if B747DR_dec_ht_display_status ~= c then B747DR_dec_ht_display_status = c end
    if B747DR_dec_ht_display_status_fo ~= f then B747DR_dec_ht_display_status_fo = f end
end

-- PM 10,000ft Callout (crazytimtimtim + Matt726)
function B747_10000_callout()
    if simDR_altitude_ft_pilot <= 10050 and simDR_altitude_ft_pilot >= 9050 then
        B747DR_10000_callout = 1
    elseif simDR_altitude_ft_pilot <= 9000 or simDR_altitude_ft_pilot >= 11000 then
        B747DR_10000_callout = 0
    end
end



----- RADIO ALTITUDE --------------------------------------------------------------------
-- laminar/B747/efis/radio_altitude (the Captain's PFD) is written by the nav
-- module (B747.34.xt.ra.lua: the radio altimeters, 5-1 step 4)

----- ALTIMETER -------------------------------------------------------------------------
function B747_altimteter()

    B747DR_alt_hectopascal = string.format("%04d", roundToIncrement((simDR_altimeter_baro_inHg * 33.8639), 1))
    B747DR_altimter_ft_adjusted = simDR_altitude_ft_pilot * 0.01

end






----- LOCALIZER & GLIDESLOPE FLAGS PM VISIBILITY FLAGS ----------------------------------
function B747_loc_gs_vis_flags()

    -- CAPTAIN LOCALIZER SCALE
    
    if simDR_hsi_hdef_dots_pilot < -0.50 or simDR_hsi_hdef_dots_pilot > 0.50 then
        B747DR_loc_scale_vis_capt = 1
    elseif simDR_hsi_hdef_dots_pilot >= -0.50 and simDR_hsi_hdef_dots_pilot <= 0.50 then
        B747DR_loc_scale_vis_capt = 2
    else
        B747DR_loc_scale_vis_capt = 0
    end


    -- CAPTAIN LOCALIZER POINTER
    
    if simDR_hsi_hdef_dots_pilot < -2.3 or simDR_hsi_hdef_dots_pilot > 2.3
    then
        B747DR_loc_ptr_vis_capt = 1
    elseif (simDR_hsi_hdef_dots_pilot >= -2.3 and simDR_hsi_hdef_dots_pilot < -0.5)
        or (simDR_hsi_hdef_dots_pilot <= 2.3 and simDR_hsi_hdef_dots_pilot > 0.5)
    then
        B747DR_loc_ptr_vis_capt = 2
    elseif simDR_hsi_hdef_dots_pilot >= -0.5 and simDR_hsi_hdef_dots_pilot <= 0.5
    then
        B747DR_loc_ptr_vis_capt = 3
    else
        B747DR_loc_ptr_vis_capt = 0
    end


    -- CAPTAIN GLIDESLOPE POINTER
    
    if simDR_hsi_vdef_dots_pilot < -2.3 or simDR_hsi_vdef_dots_pilot > 2.3 then
        B747DR_glideslope_ptr_vis_capt = 1
    elseif simDR_hsi_vdef_dots_pilot >= -2.3 and simDR_hsi_vdef_dots_pilot <= 2.3 then
        B747DR_glideslope_ptr_vis_capt = 2
    else
        B747DR_glideslope_ptr_vis_capt = 0
    end


    -- FIRST OFFICER LOCALIZER SCALE
    
    if simDR_hsi_hdef_dots_copilot < -0.50 or simDR_hsi_hdef_dots_copilot > 0.50 then
        B747DR_loc_scale_vis_fo = 1
    elseif simDR_hsi_hdef_dots_copilot >= -0.50 and simDR_hsi_hdef_dots_copilot <= 0.50 then
        B747DR_loc_scale_vis_fo = 2
    else
        B747DR_loc_scale_vis_fo = 0
    end


    -- FIRST OFFICER LOCALIZER POINTER
    
    if simDR_hsi_hdef_dots_copilot < -2.3 or simDR_hsi_hdef_dots_copilot > 2.3
    then
        B747DR_loc_ptr_vis_fo = 1
    elseif (simDR_hsi_hdef_dots_copilot >= -2.3 and simDR_hsi_hdef_dots_copilot < -0.5)
        or (simDR_hsi_hdef_dots_copilot <= 2.3 and simDR_hsi_hdef_dots_copilot > 0.5)
    then
        B747DR_loc_ptr_vis_fo = 2
    elseif simDR_hsi_hdef_dots_copilot >= -0.5 and simDR_hsi_hdef_dots_copilot <= 0.5
    then
        B747DR_loc_ptr_vis_fo = 3
    else
        B747DR_loc_ptr_vis_fo = 0
    end


    -- FIRST OFFICER GLIDESLOPE POIUNTER
    
    if simDR_hsi_vdef_dots_copilot < -2.3 or simDR_hsi_vdef_dots_copilot > 2.3 then
        B747DR_glideslope_ptr_vis_fo = 1
    elseif simDR_hsi_vdef_dots_copilot >= -2.3 and simDR_hsi_vdef_dots_copilot <= 2.3 then
        B747DR_glideslope_ptr_vis_fo = 2
    else
        B747DR_glideslope_ptr_vis_fo = 0
    end

end




----- ND NAV RAD FREQ ID ----------------------------------------------------------------
function B747_ND_nav_rad_ID()

    -- VOR RADIOS
    B747_nd_vorL_ID_flag_capt = 1
    if string.byte(simDR_nav3_ID) == nil then
        B747_nd_vorL_ID_flag_capt = 0
    end

    B747_nd_vorR_ID_flag_capt = 1
    if string.byte(simDR_nav4_ID) == nil then
        B747_nd_vorR_ID_flag_capt = 0
    end
    

    -- ADF RADIOS
    B747_nd_adfL_ID_flag_capt = 1
    if string.byte(simDR_adf1_ID) == nil then
        B747_nd_adfL_ID_flag_capt = 0
    end

    B747_nd_adfR_ID_flag_capt = 1
    if string.byte(simDR_adf2_ID) == nil then
        B747_nd_adfR_ID_flag_capt = 0
    end    

end





----- BARO INIT -------------------------------------------------------------------------
function B747_baro_init()

    -- CAPT BARO
    --[[if simDR_altimeter_baro_inHg > 29.91
        and simDR_altimeter_baro_inHg < 29.93
    then
        if B747DR_efis_baro_std_capt_switch_pos == 0 then B747CMD_efis_baro_std_capt_switch:once() end
    end]]
    B747DR_efis_baro_std_capt_switch_pos = 0
    B747DR_efis_baro_capt_preselect = 29.92
    simDR_altimeter_baro_inHg =29.92
    B747DR_efis_baro_std_capt_show_preselect = 0
    -- F/O BARO
    --[[if simDR_altimeter_baro_inHg_fo > 29.91
        and simDR_altimeter_baro_inHg_fo < 29.93
    then
        if B747DR_efis_baro_std_fo_switch_pos == 0 then B747CMD_efis_baro_std_fo_switch:once() end
    end]]
    B747DR_efis_baro_std_fo_switch_pos = 0
    B747DR_efis_baro_fo_preselect = 29.92
    simDR_altimeter_baro_inHg_fo = 29.92
    B747DR_efis_baro_std_fo_show_preselect = 0
    simDR_radio_alt_DH_capt=-1
    simDR_radio_alt_DH_fo=-1
    B747DR_efis_baro_alt_ref_capt=-101
    B747DR_efis_baro_alt_ref_fo=-101

end






----- VERTICAL SPEED INDICATOR ----------------------------------------------------------
function B747_vsi()

    B747DR_vertical_speed_fpm = roundToIncrement(simDR_vvi_fpm_pilot, 50)
end







----- ND MODES --------------------------------------------------------------------------
-- TFC, TCAS OFF and the ND's traffic come from the TCAS model
-- (B747.34.xt.tcas.lua) and B747.61.xt.nd.lua; X-Plane's map draws no traffic
function B747_nd_EFIS_map_modes()

    local mapCenter=simDR_EFIS_map_is_center--force read state
    if simDR_EFIS_tcas_on ~= 0 then simDR_EFIS_tcas_on = 0 end
end





----- ND TRACK LINE ---------------------------------------------------------------------
function B747_nd_track_line()

    

    -- not centred: the CTR state, not the CTR switch (pressed only while held)
    if (B747DR_nd_mode_capt_sel_dial_pos <= 1 and B747_nd_map_center_capt < 0.5 and (simDR_EFIS_wxr_on > 0.5 or B747DR_nd_capt_tfc > 0.5))
        or
        (B747DR_nd_mode_capt_sel_dial_pos == 2 and B747_nd_map_center_capt < 0.5)
    then
        B747_exp_capt_nd_track_line_on = 1
    else
      B747_exp_capt_nd_track_line_on = 0
    end
    if (B747DR_nd_mode_fo_sel_dial_pos <= 1 and B747_nd_map_center_fo < 0.5 and (simDR_EFIS_wxr_on_fo > 0.5 or B747DR_nd_fo_tfc > 0.5))
        or
        (B747DR_nd_mode_fo_sel_dial_pos == 2 and B747_nd_map_center_fo < 0.5)
    then
        B747_exp_fo_nd_track_line_on = 1
    else
        B747_exp_fo_nd_track_line_on = 0
    end
end







----- V-SPEEDS --------------------------------------------------------------------------

-- V1 / Vr / V2 - TEMPERATURE/ALTITUDE REGIONS
local regions = {}
local tempAltRegion = 0

function B747_getTempAltRegions()

    local regTop = {0, 0, 0, 0, 0}
    for region = 1, 5 do
        local lowTempIndex = 1
        for index = 1, #VtempAltRegionData[region] do
            if VtempAltRegionData[region][index].temp <= simDR_OAT_degC then
                lowTempIndex = index
            end
        end
        regTop[region] = B747_rescale(VtempAltRegionData[region][lowTempIndex].temp, VtempAltRegionData[region][lowTempIndex].alt , VtempAltRegionData[region][math.min(#VtempAltRegionData[region], lowTempIndex+1)].temp, VtempAltRegionData[region][math.min(#VtempAltRegionData[region], lowTempIndex+1)].alt, simDR_OAT_degC)
    end
    local regBottom = {-2000, regTop[1], regTop[2], regTop[3], regTop[4]}


    regions = {

        {-- REGION A

            -- DEFINE THE REGION
            l=-60, b=regBottom[1], t=regTop[1], r=46.29,

            -- SET THE CURRENT TEMPERATURE/ALTITUDE REGION
            f = function()
                tempAltRegion = 1
            end,

        },

        {-- REGION B

            -- DEFINE THE REGION
            l=-60.0, b=regBottom[2], t=regTop[2], r=50.16,

            -- SET THE CURRENT TEMPERATURE/ALTITUDE REGION
            f = function()
                tempAltRegion = 2
            end,

        },

        {-- REGION C

            -- DEFINE THE REGION
            l=-60.0, b=regBottom[3], t=regTop[3], r=55.53,

            -- SET THE CURRENT TEMPERATURE/ALTITUDE REGION
            f = function()
                tempAltRegion = 3
            end,

        },

        {-- REGION D

            -- DEFINE THE REGION
            l=-60.0, b=regBottom[4], t=regTop[4], r=60.31,

            -- SET THE CURRENT TEMPERATURE/ALTITUDE REGION
            f = function()
                tempAltRegion = 4
            end,

        },

        {-- REGION E

            -- DEFINE THE REGION
            l=-60.0, b=regBottom[5], t=regTop[5], r=64.80,

            -- SET THE CURRENT TEMPERATURE/ALTITUDE REGION
            f = function()
                tempAltRegion = 5
            end,

        }

    }

end

function B747_setTempAltRegion()

    B747_getTempAltRegions()

    local num_regions = #regions

    for i=1, num_regions do

        local r = regions[i]

        if (simDR_OAT_degC > r.l) and (simDR_OAT_degC < r.r) then

            if (simDR_altitude_ft_pilot > r.b) and (simDR_altitude_ft_pilot < r.t) then

                r.f()

                return true

            end -- ALTITUDE TEST
        end -- TEMPERATURE TEST
    end -- LOOP ALL REGIONS

    return false

end




-- the FMC's takeoff speeds (6-1/6-2 step 3b; FCOM p.1319-1320): computed
-- into airspeed/V1_ref, Vr_ref and V2_ref from the TAKEOFF REF flaps (10 or
-- 20), the FMC's gross weight (PERF INIT), the temperature and altitude
-- region and the TAKEOFF REF wind (none entered: calm); 999 (dashes) when
-- the flaps or the weight are missing or no IRU is aligned. The FMC selects
-- them for the PFD (airspeed/V1, Vr, V2: B744.fms.pages.takeoff.lua).
-- Before: the airplane's weight and X-Plane's wind, straight to the PFD
-- when the flaps were entered. V1 not above VR (estimate).
B747DR_airspeed_V1_ref = find_dataref("laminar/B747/airspeed/V1_ref")
B747DR_airspeed_Vr_ref = find_dataref("laminar/B747/airspeed/Vr_ref")
B747DR_airspeed_V2_ref = find_dataref("laminar/B747/airspeed/V2_ref")
B747DR_fltinst_fms_data = find_dataref("laminar/B747/fms/data")
B747DR_fltinst_irs_mode = find_dataref("laminar/B747/irs/mode")
local V1_WIND_KEYS = {-15, -10, -5, 0, 10, 20, 30, 40}
-- the V1 wind adjustment between the table's weights and headwinds (kg, kt)
local function v1_wind_adjustment(weight, hw)
    local w1 = math.max(200000, math.min(400000, math.floor(weight / 20000) * 20000))
    local w2 = w1 + 20000
    hw = math.max(-15, math.min(40, hw))
    local h1, h2 = -15, -10
    for i = 1, #V1_WIND_KEYS - 1 do
        if hw >= V1_WIND_KEYS[i] and hw <= V1_WIND_KEYS[i + 1] then
            h1, h2 = V1_WIND_KEYS[i], V1_WIND_KEYS[i + 1]
            break
        end
    end
    local function at(h) return B747_rescale(w1, V1windAdj[h][w1], w2, V1windAdj[h][w2], weight) end
    return B747_rescale(h1, at(h1), h2, at(h2), hw)
end
-- the FMC's gross weight (kg; nil before PERF INIT) and the TAKEOFF REF
-- headwind (kt; a tailwind negative)
local function fms_takeoff_data()
    local d = B747DR_fltinst_fms_data
    if type(d) ~= "string" then return nil, 0 end
    local gw = tonumber(d:match('"grwt"%s*:%s*"%s*([%d.]+)'))
    local dir, kt = d:match('"towind"%s*:%s*"([HT]?)(%d+)')
    local hw = tonumber(kt) or 0
    if dir == "T" then hw = -hw end
    return gw and gw * 1000 or nil, hw
end
function B747_V1_wind_adjustment()
end
B747DR_airspeed_flapsRef                              = find_dataref("laminar/B747/airspeed/flapsRef")
-- V1 / Vr / V2: the FMC's
function B747_setV1VrV2()

    local flaps = roundToIncrement(B747DR_airspeed_flapsRef, 10)
    if B747DR_radio_altitude>1000 then
        B747DR_airspeed_flapsRef=0
    end
    local gw, hw = fms_takeoff_data()
    local aligned = false
    for i = 0, 2 do
        if B747DR_fltinst_irs_mode[i] == 2 then aligned = true end
    end
    local v1, vr, v2 = 999, 999, 999
    if (flaps == 10 or flaps == 20) and gw ~= nil and aligned and tempAltRegion > 0 then
        local weight = math.max(200000, math.min(420000, gw))
        local weight_max = math.max(220000, math.min(420000, roundUpToIncrement(weight, 20000)))
        local weight_min = weight_max - 20000
        local function speed(t)
            return B747_rescale(weight_min, t[flaps][tempAltRegion][weight_min], weight_max, t[flaps][tempAltRegion][weight_max], weight)
        end
        vr = math.floor(speed(B747_Vr) + 0.5)
        v2 = math.floor(speed(B747_V2) + 0.5)
        v1 = math.min(vr, math.floor(speed(B747_V1) + v1_wind_adjustment(weight, hw) + 0.5))
    end
    if B747DR_airspeed_V1_ref ~= v1 then B747DR_airspeed_V1_ref = v1 end
    if B747DR_airspeed_Vr_ref ~= vr then B747DR_airspeed_Vr_ref = vr end
    if B747DR_airspeed_V2_ref ~= v2 then B747DR_airspeed_V2_ref = v2 end

    -- crazytimtimtim V1 callout
    if simDR_airspeed >= B747DR_airspeed_V1 and
    simDR_all_wheels_on_ground == 1 and
    B747DR_airspeed_V1 > 0 then
        B747DR_v1_alert = 1
    else
        B747DR_v1_alert = 0
    end

    -- Rotate Callout
    if simDR_airspeed >= B747DR_airspeed_Vr and
    simDR_all_wheels_on_ground == 1 and
    B747DR_airspeed_Vr > 0 then
        B747DR_vr_alert = 1
    else
        B747DR_vr_alert = 0
    end

end





-- the table's weights that bracket the gross weight (rounding to the nearest
-- 20 t took the lower weight's value in the first half of each step: VREF30
-- up to 3 kt low, the stall speed up to 4 kt; 5-2 step 3b)
local function bracket_weights()
    local w = math.max(200000, math.min(400000, simDR_acf_weight_total_kg))
    local weight_min = math.min(380000, math.floor(w / 20000) * 20000)
    return weight_min, weight_min + 20000
end

-- Vref30
function B747_setVref30()

    local weight_min, weight_max = bracket_weights()

    local speed = {}
    if simDR_altitude_ft_pilot <= -2000 then speed = Vref30data.speedMinus2k
        elseif simDR_altitude_ft_pilot <= 0 then speed = Vref30data.speed0k
        elseif simDR_altitude_ft_pilot <= 2000 then speed = Vref30data.speed2k
        elseif simDR_altitude_ft_pilot <= 6000 then speed = Vref30data.speed6k
        else speed = Vref30data.speed10k
    end
    B747DR_airspeed_Vref30 = B747_rescale(weight_min, speed[weight_min], weight_max, speed[weight_max], simDR_acf_weight_total_kg)

end



function setVmc(weight,flaps)

    local weight_factor =  B747_rescale(179000.0, 0, 396000.0, 61.0, weight) 
    local flap_Vmc      = 0
    if flaps<1 then
      flap_Vmc      =B747_rescale(0.0, (179), 1.0, 166, flaps) + weight_factor --13/1
    elseif flaps<10 then
      flap_Vmc      =B747_rescale(1.0, 166, 10.0, 137, flaps) + weight_factor --3/1
    else
      flap_Vmc      =B747_rescale(10.0, 137, 30.0, 118, flaps) + weight_factor --0.95/1
    end
    B747DR_airspeed_Vmc = flap_Vmc
    -- Vmc is the old approximation of the minimum maneuvering speed, kept for
    -- the AFDS, A/T and VNAV speed floors (their Vmc + 10 and flap offsets
    -- are tuned to it) until their rebuild (6-3, 6-4); the PFDs show Vminm
    -- from the minimum speed model (5-2 step 3b)
    --print(" " ..weight/1000 .. "t, " .. flaps .. "=" .. math.floor(B747DR_airspeed_Vmc) .." ")
end

-- MISC V-SPEEDS
function B747_Vspeeds()

    -- Vf (the flap maneuver speeds) and their bugs: the speed tape model
    -- (B747.60.xt.speedtape.lua, 5-2 step 3a)

    if simDR_radio_alt_height_capt< 5.0 then
        B747DR_airspeed_VrefFlap=0
    end

    -- Vfe (MAXIMUM FLAP EXTENDED SPEED - [PLACARD])
    B747DR_airspeed_Vfe1 = 280.0
    B747DR_airspeed_Vfe5 = 260.0
    B747DR_airspeed_Vfe10 = 240.0
    B747DR_airspeed_Vfe20 = 230.0
    B747DR_airspeed_Vfe25 = 205.0
    B747DR_airspeed_Vfe30 = 180.0


    -- Va (DESIGN MANEUVERING SPEED)
    B747DR_airspeed_Va = B747_rescale(0.0, 329.31, 10000.0, 334.78, simDR_altitude_ft_pilot)
    if simDR_altitude_ft_pilot > 10000.0 then B747DR_airspeed_Va = B747_rescale(10000.0, 334.78, 20000.0, 343.52, simDR_altitude_ft_pilot) end
    if simDR_altitude_ft_pilot > 200000.0 then B747DR_airspeed_Va = B747_rescale(20000.0, 343.52, 30000.0, 360.0, simDR_altitude_ft_pilot) end


    -- Vlo / Mlo (MAXIMUM LANDING GEAR OPERATING SPEED)
    -- 270/.820
    B747DR_airspeed_Vlo = 270.0
    B747DR_airspeed_Mlo = 0.820


    -- Vle  /Mle (MAXIMUM LANDING GEAR EXTENDED SPEED)
    -- 320/.820
    B747DR_airspeed_Vle = 320.0
    B747DR_airspeed_Mle = 0.820


    -- Vmc: the old minimum maneuvering approximation for the AFDS and A/T
    -- floors; the PFD's band (Vminm) and its amber box: the minimum speed
    -- model (B747.60.xt.speedtape.lua, 5-2 step 3b)
    setVmc(simDR_acf_weight_total_kg,simDR_wing_flap1_deg[0])


    -- Vmo / Mmo (MAXIMUM OPERATING LIMIT SPEED)
   
    if simDR_altitude_ft_pilot > 28620.0 then 
        B747DR_airspeed_Vmo = B747_rescale(28620.0, 365.0, 45000.0, 252.35, simDR_altitude_ft_pilot) 
    else
        B747DR_airspeed_Vmo = 365.0
    end

    if simDR_altitude_ft_pilot <= 28620.0 then B747DR_airspeed_Mmo = 0.880 end
    if simDR_altitude_ft_pilot > 28620.0 then B747DR_airspeed_Mmo = 0.920 end
    B747DR_airspeed_Mms = B747_rescale(20620.0,0.740,28620,0.920,simDR_altitude_ft_pilot)


    -- Vne / Mne (NEVER EXCEED SPEED)
    B747DR_airspeed_Vne = 365.0
    B747DR_airspeed_Mne = 0.920


    -- Vmax (MAXIMUM SPEED -  HIGH SPEED RED CHECKER BOX ON ASI
    local flapSpeed = B747DR_airspeed_Vmo
    if simDR_innerslats_ratio>0.0 and simDR_wing_flap1_deg[0] < 1.0 then
        flapSpeed = B747_rescale(0.0, B747DR_airspeed_Vmo, 1.0, B747DR_airspeed_Vfe1, simDR_innerslats_ratio)
    elseif simDR_wing_flap1_deg[0] > 0.0 and simDR_wing_flap1_deg[0] <= 5.0 then
        flapSpeed = B747_rescale(0.0, B747DR_airspeed_Vfe1, 5.0, B747DR_airspeed_Vfe5, simDR_wing_flap1_deg[0])
    elseif simDR_wing_flap1_deg[0] > 5.0 and simDR_wing_flap1_deg[0] <= 10.0 then
        flapSpeed = B747_rescale(5.0, B747DR_airspeed_Vfe5, 10.0, B747DR_airspeed_Vfe10, simDR_wing_flap1_deg[0])
    elseif simDR_wing_flap1_deg[0] > 10.0 and simDR_wing_flap1_deg[0] <= 20.0 then
        flapSpeed = B747_rescale(10.0, B747DR_airspeed_Vfe10, 20.0, B747DR_airspeed_Vfe20, simDR_wing_flap1_deg[0])
    elseif simDR_wing_flap1_deg[0] > 20.0 and simDR_wing_flap1_deg[0] <= 25.0 then
        flapSpeed = B747_rescale(20.0, B747DR_airspeed_Vfe20, 25.0, B747DR_airspeed_Vfe25, simDR_wing_flap1_deg[0])
    elseif simDR_wing_flap1_deg[0] > 25.0 and simDR_wing_flap1_deg[0] <= 30.0 then
        flapSpeed = B747_rescale(25.0, B747DR_airspeed_Vfe25, 30.0, B747DR_airspeed_Vfe30, simDR_wing_flap1_deg[0])
    end

    local gearSpeed = B747DR_airspeed_Vmo
    gearSpeed = B747_rescale(0.0, B747DR_airspeed_Vmo, 1.0, B747DR_airspeed_Vle, simDR_gear_deploy_ratio[0])

    B747DR_airspeed_Vmax = math.min(B747DR_airspeed_Vmo, flapSpeed, gearSpeed)

    -- Vmaxm (the maximum maneuvering speed, 1.3 g to high speed buffet; it
    -- was Vmax - 10): the minimum speed model (5-2 step 3b)

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

-- The stall speed table (Laminar's; the FCTM's stall speeds: notes/FCTM.md
-- §1.14) for X-Plane's TOGA pitch below, which the AFDS uses (6-3). The
-- speed tape's red and black band and the stick shaker are the minimum speed
-- model's (B747.60.xt.speedtape.lua, 5-2 step 3b): the band is the stick
-- shaker speed (FCOM p.973), not the stall speed.
function B747_Vs()

    local weight_min, weight_max = bracket_weights()

    -- the table's altitude bands, highest first (DSP-07: the 0 ft band
    -- caught every altitude above it)
    local alt_min = -2000
    local alt_max = 0.0
    if simDR_altitude_ft_pilot >= 10000.0 then
        alt_min = 10000.0
        alt_max = 10000.0
    elseif simDR_altitude_ft_pilot >= 6000.0 then
        alt_min = 6000.0
        alt_max = 10000.0
    elseif simDR_altitude_ft_pilot >= 2000.0 then
        alt_min = 2000.0
        alt_max = 6000.0
    elseif simDR_altitude_ft_pilot >= 0.0 then
        alt_min = 0.0
        alt_max = 2000.0
    end

    local flap_min = 0
    local flap_max = 0
    if simDR_wing_flap1_deg[0] >= 0.01 and simDR_wing_flap1_deg[0] < 1.0 then
        flap_min = 0
        flap_max = 1
    elseif simDR_wing_flap1_deg[0] >= 0.99 and simDR_wing_flap1_deg[0] < 1.01 then
        flap_min = 1
        flap_max = 1
    elseif simDR_wing_flap1_deg[0] >= 1.01 and simDR_wing_flap1_deg[0] < 4.99 then
        flap_min = 1
        flap_max = 5
    elseif simDR_wing_flap1_deg[0] >= 4.99 and simDR_wing_flap1_deg[0] < 5.01 then
        flap_min = 5
        flap_max = 5
    elseif simDR_wing_flap1_deg[0] >= 5.01 and simDR_wing_flap1_deg[0] < 9.99 then
        flap_min = 5
        flap_max = 10
    elseif simDR_wing_flap1_deg[0] >= 9.99 and simDR_wing_flap1_deg[0] < 10.01 then
        flap_min = 10
        flap_max = 10
    elseif simDR_wing_flap1_deg[0] >= 10.01 and simDR_wing_flap1_deg[0] < 19.99 then
        flap_min = 10
        flap_max = 20
    elseif simDR_wing_flap1_deg[0] >= 19.99 and simDR_wing_flap1_deg[0] < 20.01 then
        flap_min = 20
        flap_max = 20
    elseif simDR_wing_flap1_deg[0] >= 20.01 and simDR_wing_flap1_deg[0] < 24.99 then
        flap_min = 20
        flap_max = 25
    elseif simDR_wing_flap1_deg[0] >= 24.99 and simDR_wing_flap1_deg[0] < 25.01 then
        flap_min = 25
        flap_max = 25
    elseif simDR_wing_flap1_deg[0] >= 25.01 and simDR_wing_flap1_deg[0] < 29.99 then
        flap_min = 25
        flap_max = 30
    elseif simDR_wing_flap1_deg[0] >= 29.99 then
        flap_min = 30
        flap_max = 30
    end

    local weight_min_index          = weight_min*0.001
    local weight_max_index          = weight_max*0.001
    local Vs_min_flap_min_alt_speed = B747_rescale(weight_min, VsData[flap_min][alt_min][weight_min_index], weight_max, VsData[flap_min][alt_min][weight_max_index], simDR_acf_weight_total_kg)
    local Vs_min_flap_max_alt_speed = B747_rescale(weight_min, VsData[flap_min][alt_max][weight_min_index], weight_max, VsData[flap_min][alt_max][weight_max_index], simDR_acf_weight_total_kg)
    local Vs_min_flap_alt_speed     = B747_rescale(alt_min, Vs_min_flap_min_alt_speed, alt_max, Vs_min_flap_max_alt_speed, simDR_altitude_ft_pilot)
    local Vs_max_flap_min_alt_speed = B747_rescale(weight_min, VsData[flap_max][alt_min][weight_min_index], weight_max, VsData[flap_max][alt_min][weight_max_index], simDR_acf_weight_total_kg)
    local Vs_max_flap_max_alt_speed = B747_rescale(weight_min, VsData[flap_max][alt_max][weight_min_index], weight_max, VsData[flap_max][alt_max][weight_max_index], simDR_acf_weight_total_kg)
    local Vs_max_flap_alt_speed     = B747_rescale(alt_min, Vs_max_flap_min_alt_speed, alt_max, Vs_max_flap_max_alt_speed, simDR_altitude_ft_pilot)
    local target_airspeed_Vs              = B747_rescale(flap_min, Vs_min_flap_alt_speed, flap_max, Vs_max_flap_alt_speed, simDR_wing_flap1_deg[0])
    if simDR_airspeed > target_airspeed_Vs then
        local numStalled=0
        for i=0,320 do
            if simDR_stalled_elements[i]>0 then
                numStalled=numStalled+1
            end
        end
        if numStalled > 0 then
           if simDR_all_wheels_on_ground==0 then
                simDR_autopilot_TOGA_pitch_deg=math.min(12-(17*numStalled/10),3)
                --print("simDR_autopilot_TOGA_pitch_deg1="..simDR_autopilot_TOGA_pitch_deg)
           else --on ground, pitch for 8
                simDR_autopilot_TOGA_pitch_deg=8
           end

        elseif simDR_all_wheels_on_ground==1 then
            simDR_autopilot_TOGA_pitch_deg=8
        else
            local tSpeed=target_airspeed_Vs+20
            if B747DR_airspeed_V2<900 then
                tSpeed=B747DR_airspeed_V2+10
            end
            simDR_autopilot_TOGA_pitch_deg=B747_rescale(target_airspeed_Vs,2,tSpeed,12,simDR_airspeed)
            --print("simDR_autopilot_TOGA_pitch_deg2="..simDR_autopilot_TOGA_pitch_deg)
        end
    else
        simDR_autopilot_TOGA_pitch_deg=8
        --print("simDR_autopilot_TOGA_pitch_deg3="..simDR_autopilot_TOGA_pitch_deg)
    end
end





-- INIT V1 / Vr / V2
function B747_initV1VrV2()

    B747_setTempAltRegion()
    B747_V1_wind_adjustment()
    B747_setV1VrV2()

end






----- FLIGHT INSTRUMENTS EICAS MESSAGES -------------------------------------------------
function B747_baro_disagree()
    --if math.abs(B747DR_efis_baro_capt_set_dial_pos - B747DR_efis_baro_fo_set_dial_pos) > 0.01 then
    if math.abs(simDR_altimeter_baro_inHg - simDR_altimeter_baro_inHg_fo) > 0.01 then  
        B747DR_CAS_advisory_status[18] = 1
    end
end

function B747_fltInst_EICAS_msg()

    -- OVERSPEED, >AOA RIGHT: the air data glue of the navigation sensors
    -- module (B747.34.xt.nav, 5-1 step 1; OVERSPEED was the placard speeds'
    -- Vmax, NAV-02)

    -- >AIRSPEED LOW: the minimum speed model (B747.60.xt.speedtape.lua, 5-2
    -- step 3b): below the minimum maneuvering speed (FCOM p.1556); it was
    -- below the old Vmc or the stall speed


    -- >BARO DISAGREE
    --if math.abs(B747DR_efis_baro_capt_set_dial_pos - B747DR_efis_baro_fo_set_dial_pos) > 0.01 then
    if math.abs(simDR_altimeter_baro_inHg - simDR_altimeter_baro_inHg_fo) > 0.01 then  
        if is_timer_scheduled(B747_baro_disagree) == false then
            run_after_time(B747_baro_disagree, 60.0)
        end
    else
        B747DR_CAS_advisory_status[18] = 0
         if is_timer_scheduled(B747_baro_disagree) == true then
            stop_timer(B747_baro_disagree)
        end
    end

    -- >BAT DISCH MAIN, >BAT DISCH APU, >BATTERY OFF: the electrical model
    -- (B747.03.xt.elec_buses.lua)

end


-- the display units and EIUs: B747.60.xt.displays.lua (5-2 step 1)




----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_inst_monitor_AI()

    if B747DR_init_inst_CD == 1 then
        B747_set_inst_all_modes()
        B747_set_inst_CD()
        B747DR_init_inst_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_inst_all_modes()

	B747DR_init_inst_CD = 0
	
    B747DR_STAT_msg_page = 1
    B747DR_STAT_num_msg_pages = 1

    
    
    B747DR_dsp_synoptic_display = 1
    B747_baro_init()

    B747DR_flt_inst_inbd_disp_capt_sel_dial_pos = 1
    B747DR_flt_inst_lwr_disp_capt_sel_dial_pos = 1
    B747DR_flt_inst_eiu_src_capt_dial_pos = 1

    B747DR_flt_inst_inbd_disp_fo_sel_dial_pos = 1
    B747DR_flt_inst_lwr_disp_fo_sel_dial_pos = 1

    B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos = 1

    B747DR_flt_inst_fd_src_fo_dial_pos = 2
    B747DR_flt_inst_nav_src_fo_dial_pos = 3

    B747DR_flt_inst_eiu_src_fo_dial_pos = 2
    B747DR_flt_inst_irs_src_fo_dial_pos = 2
    B747DR_flt_inst_air_data_src_fo_dial_pos = 1


    simDR_EFIS_map_mode = 2
    simDR_EFIS_map_mode_copilot = 2
    B747DR_nd_mode_capt_sel_dial_pos = 2
    B747DR_nd_mode_fo_sel_dial_pos = 2

    B747DR_nd_range_capt_sel_dial_pos = simDR_EFIS_map_range
    B747DR_nd_range_fo_sel_dial_pos = B747DR_nd_range_capt_sel_dial_pos

    simDR_EFIS_1_sel_pilot = 1
    simDR_EFIS_2_sel_pilot = 1
    simDR_EFIS_1_sel_fo = 1
    simDR_EFIS_2_sel_fo = 1
    B747DR_nd_capt_terr=0
    B747DR_nd_fo_terr=0
    B747DR_nd_capt_vor_ndb = 0
    B747DR_nd_fo_vor_ndb = 0
    B747DR_nd_capt_wpt = 0
    B747DR_nd_fo_wpt = 0
    B747DR_nd_capt_apt = 0
    B747DR_nd_fo_apt = 0
    simDR_EFIS_apt = 0
    simDR_EFIS_fix = 0
    simDR_EFIS_vor = 0
    simDR_EFIS_ndb = 0
    simDR_EFIS_apt_fo = 0
    simDR_EFIS_fix_fo = 0
    simDR_EFIS_vor_fo = 0
    simDR_EFIS_ndb_fo = 0
end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_inst_CD()
  simDR_EFIS_tcas_on=0
    simDR_EFIS_terr_on_fo=0
    simDR_EFIS_terr_on_capt=0

end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_inst_ER()
    simDR_EFIS_tcas_on=0
    simDR_EFIS_terr_on_fo=0
    simDR_EFIS_terr_on_capt=0

	
end






----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_fltInst()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_inst_all_modes()



    -- DEFERRED INIT





    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then    
    
    	B747_set_inst_CD()





    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then
	    
		B747_set_inst_ER()


	end

end











--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end


--function aircraft_unload() end


function flight_start()
    simDR_has_stall_warning=0
    simDR_autopilot_TOGA_pitch_deg      = 8.0
    B747_flight_start_fltInst()
    B747_speedtape_flight_start()
    B747_clocks_flight_start()

end
local lastHeading=0
local lastRollMode=-1
local mapHeading=false
function clear_heading_bug()
    mapHeading=false
end
function update_heading_bug()
    if B747DR_ap_FMA_active_roll_mode<2 or B747DR_ap_FMA_active_roll_mode>4 then
        if is_timer_scheduled(clear_heading_bug) == true then
            stop_timer(clear_heading_bug)
        end
        mapHeading=true
    elseif lastHeading~=B747DR_ap_heading_deg or lastRollMode~=B747DR_ap_FMA_active_roll_mode then
        mapHeading=true
        if is_timer_scheduled(clear_heading_bug) == true then
            stop_timer(clear_heading_bug)
        end
        run_after_time(clear_heading_bug, 10.0)
    end
    if B747DR_nd_mode_capt_sel_dial_pos==2 then
        if mapHeading==true then
            B747DR_nd_capt_heading_bug=1
        else
            B747DR_nd_capt_heading_bug=0
        end
    elseif B747DR_nd_mode_capt_sel_dial_pos<=1 then
        B747DR_nd_capt_heading_bug=1
    else
        B747DR_nd_capt_heading_bug=0
    end
    if B747DR_nd_mode_fo_sel_dial_pos==2 then
        if mapHeading==true then
            B747DR_nd_fo_heading_bug=1
        else
            B747DR_nd_fo_heading_bug=0
        end
    elseif B747DR_nd_mode_fo_sel_dial_pos<=1 then
        B747DR_nd_fo_heading_bug=1
    else
        B747DR_nd_fo_heading_bug=0
    end
    lastHeading=B747DR_ap_heading_deg
    lastRollMode=B747DR_ap_FMA_active_roll_mode
end
--function flight_crash() end


--function before_physics() end

debug_fltinst     = deferred_dataref("laminar/B747/debug/fltinst", "number")
function after_physics()
  if debug_fltinst>0 then return end

    local refresh_capt_nd=simDR_EFIS_map_mode  
    local refresh_fo_nd=simDR_EFIS_map_mode_copilot
    -- the clocks (B747.60.xt.fltInst03.lua)
    B747_clocks()
    
    B747_rmi()
    B747_altimteter()
    B747_minimums()
    B747_ND_nav_rad_ID()
    B747_vsi()

    B747_loc_gs_vis_flags()

    --simDR_EFIS_map_is_center = 0                                                        -- FORCE TO (PERSISTENT) EXPANDED MODE
    B747_nd_EFIS_map_modes()
    B747_nd_track_line()

    B747_setVref30()
    B747_Vspeeds()
    B747_speedtape()
    B747_Vs()

    B747_setTempAltRegion()
    B747_V1_wind_adjustment()
    B747_setV1VrV2()

    B747_fltInst_EICAS_msg()

    B747_inst_monitor_AI()
    B747_displays()
    -- each PFD's airspeed: the air data module (the selected ADC)
    update_heading_bug()

    B747_10000_callout()
end


--function after_replay() end


