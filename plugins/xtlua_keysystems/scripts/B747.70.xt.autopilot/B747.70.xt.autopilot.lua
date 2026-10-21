--[[
*****************************************************************************************
* Program Script Name	:	B747.70.autopilot
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
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED
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

NUM_AUTOPILOT_BUTTONS = 18
function null_command(phase, duration)
end
function deferred_command(name, desc, realFunc)
	return wrap_command(name, realFunc, null_command)
end
function replace_char(pos, str, r)
	return str:sub(1, pos - 1) .. r .. str:sub(pos + 1)
end
--replace deferred_dataref
function deferred_dataref(name, nilType, callFunction)
	if callFunction ~= nil then
		print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
	end
	return find_dataref(name)
end

--*************************************************************************************--
--** 					            GLOBAL VARIABLES                				 **--
--*************************************************************************************--
B747CMD_fdr_log_lnav           = find_command("laminar/B747/fdr/lnav")
B747CMD_fdr_log_vnav           = find_command("laminar/B747/fdr/vnav")
B747CMD_fdr_log_apon           = find_command("laminar/B747/fdr/apon")
B747CMD_fdr_log_apdisconnect           = find_command("laminar/B747/fdr/apdisconnect")
B747CMD_fdr_log_flch           = find_command("laminar/B747/fdr/flch")
B747CMD_fdr_log_vs           = find_command("laminar/B747/fdr/vs")
B747CMD_fdr_log_alt           = find_command("laminar/B747/fdr/alt")
B747CMD_fdr_log_toga           = find_command("laminar/B747/fdr/toga")
B747CMD_fdr_log_loc           = find_command("laminar/B747/fdr/loc")
B747CMD_fdr_log_app           = find_command("laminar/B747/fdr/app")
B747CMD_fdr_log_altmod           = find_command("laminar/B747/fdr/altmod")
B747CMD_fdr_log_spdmod           = find_command("laminar/B747/fdr/spdmod")
B747CMD_fdr_log_spd           = find_command("laminar/B747/fdr/spd")
B747CMD_fdr_log_headsel           = find_command("laminar/B747/fdr/headsel")
B747CMD_fdr_log_headhold          = find_command("laminar/B747/fdr/headhold")
--*************************************************************************************--
--** 					            LOCAL VARIABLES                 				 **--
--*************************************************************************************--

local B747_ap_button_switch_position_target = {}
for i = 0, NUM_AUTOPILOT_BUTTONS - 1 do
	B747_ap_button_switch_position_target[i] = 0
end

local B747_ap_last_AFDS_status = 0
local B747_ap_last_FMA_autothrottle_mode = 0
local B747_ap_last_FMA_roll_mode = 0
local B747_ap_last_FMA_pitch_mode = 0
local fmsData = {}
function B747_rescale(in1, out1, in2, out2, x)
	if x < in1 then
		return out1
	end
	if x > in2 then
		return out2
	end
	return out1 + (out2 - out1) * (x - in1) / (in2 - in1)
end
function getFMSData(name)
	return fmsData[name]
end
function setFMSData(id, value)
	if string.len(B747DR_FMSdata) > 0 then
		fmsData = json.decode(B747DR_FMSdata)
	else
		fmsData = json.decode("[]")
	end
	fmsData[id] = value
	B747DR_FMSdata = json.encode(fmsData)
end

function getTriSpaceSolver(ab,ac,cb)
	local ac2=(ac*ac)
	local retVal=((ab*ab)-(cb*cb)+ac2)/(2*ab);
	if ac2-(retVal*retVal)>0 then
		return {retVal,math.sqrt(ac2-(retVal*retVal))};
	else
		return {retVal,0};
	end
end

local beganDescentAny = false
function beganDescent()
	return beganDescentAny
end
function setDescent(val)
	beganDescentAny = val
end

--*************************************************************************************--
--** 				             FIND X-PLANE DATAREFS           			    	 **--
--*************************************************************************************--
B747DR_airspeed_Vf0 = find_dataref("laminar/B747/airspeed/Vf0", "number")
B747DR_airspeed_Vf1 = find_dataref("laminar/B747/airspeed/Vf1")
B747DR_airspeed_Vf5 = find_dataref("laminar/B747/airspeed/Vf5")
B747DR_airspeed_Vf10 = find_dataref("laminar/B747/airspeed/Vf10")
B747DR_airspeed_Vf20 = find_dataref("laminar/B747/airspeed/Vf20")
B747DR_airspeed_Vf25 = find_dataref("laminar/B747/airspeed/Vf25")
B747DR_airspeed_Vf30 = find_dataref("laminar/B747/airspeed/Vf30")
B747DR_CAS_warning_status = find_dataref("laminar/B747/CAS/warning_status")
simDR_autopilot_flight_dir_active = find_dataref("sim/cockpit2/annunciators/flight_director")
simDR_autopilot_flight_dir_mode = find_dataref("sim/cockpit2/autopilot/flight_director_mode")
B747DR_autothrottle_active = find_dataref("laminar/B747/engines/autothrottle_active")
simDR_autopilot_autothrottle_on = find_dataref("sim/cockpit2/autopilot/autothrottle_on")
simCMD_ATOff = find_command("sim/autopilot/autothrottle_hard_off")
simCMD_ATOffXP11 = find_command("sim/autopilot/autothrottle_off")
simCMD_ThrottleDown = find_command("sim/engines/throttle_down")
simCMD_ThrottleUp = find_command("sim/engines/throttle_up")
B747DR_ap_vnav_pause = find_dataref("laminar/B747/autopilot/vnav_pause")
simCMD_pause = find_command("sim/operation/pause_toggle")
simDRTime = find_dataref("sim/time/total_running_time_sec")
simDR_autopilot_autothrottle_enabled = find_dataref("sim/cockpit2/autopilot/autothrottle_enabled")
simDR_autopilot_autothrottle_arm = find_dataref("sim/cockpit2/autopilot/autothrottle_arm")
simDR_autopilot_bank_limit = find_dataref("sim/cockpit2/autopilot/bank_angle_mode")
simDR_autopilot_bank_angles = find_dataref("sim/cockpit2/autopilot/bank_angles_values")
simDR_autopilot_airspeed_is_mach = find_dataref("sim/cockpit2/autopilot/airspeed_is_mach")
simDR_autopilot_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_dial_ft")
simDR_disabled_autopilot_altitude_ft = find_dataref("sim/cockpit2/autopilot/altitude_dial_ft")
simDR_autopilot_hold_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_hold_ft")
simDR_autopilot_tod_index = find_dataref("sim/cockpit2/radios/indicators/fms_tod_before_index_pilot")
simDR_autopilot_tod_distance = find_dataref("sim/cockpit2/radios/indicators/fms_distance_to_tod_pilot")
B747DR_alt_capture_window        = deferred_dataref("laminar/B747/autopilot/ap_monitor/alt_capture_window", "number")
B747DR_switching_servos_on = deferred_dataref("laminar/B747/autopilot/ap_monitor/servos_on_time", "number")
B747DR_display_N1 = find_dataref("laminar/B747/engines/display_N1")
simDR_engine_N1 = find_dataref("sim/cockpit2/engine/indicators/N1_percent") -- [review 24] X-Plane's N1 (vnav.lua)
B747DR_display_N2 = find_dataref("laminar/B747/engines/display_N2")
simDR_true_heading			= find_dataref("sim/flightmodel/position/psi")
B747DR_fmc_notifications = find_dataref("laminar/B747/fms/notification")
B747BR_distance_to_dest  = deferred_dataref("laminar/B747/autopilot/dist/distance_to_dest", "number")
B747BR_toc				= deferred_dataref("laminar/B747/autopilot/dist/distance_to_toc", "number")
B747DR_ils_dots = deferred_dataref("laminar/B747/autopilot/ils_dots", "number") --display only
B747BR_vnavProfile 	= find_dataref("laminar/B747/autopilot/dist/vnavProfile")
B747BR_totalDistance = find_dataref("laminar/B747/autopilot/dist/remaining_distance")
B747BR_eod_index = deferred_dataref("laminar/B747/autopilot/dist/eod_index", "number")
B747BR_nextDistanceInFeet = find_dataref("laminar/B747/autopilot/dist/next_distance_feet")
B747BR_cruiseAlt = find_dataref("laminar/B747/autopilot/dist/cruise_alt")
B747BR_fpe				= find_dataref("laminar/B747/autopilot/dist/flight_path_error")
B747BR_tod = find_dataref("laminar/B747/autopilot/dist/top_of_descent")
B747BR_todLat = deferred_dataref("laminar/B747/autopilot/dist/top_of_descent_lat", "number")
B747BR_todLong = deferred_dataref("laminar/B747/autopilot/dist/top_of_descent_long", "number")
B747BR_tocLat				= deferred_dataref("laminar/B747/autopilot/dist/top_of_climb_lat", "number")
B747BR_tocLong				= deferred_dataref("laminar/B747/autopilot/dist/top_of_climb_long", "number")
B747DR_ND_Wind_Bearing = find_dataref("laminar/B747/nd/wind_bearing")
B747DR_throttle		= find_dataref("laminar/B747/engine/throttle")
simDR_wind_speed_kts = find_dataref("sim/cockpit2/gauges/indicators/wind_speed_kts")
simDR_autopilot_course = find_dataref("sim/cockpit/gps/course")
simDR_autopilot_destination_type = find_dataref("sim/cockpit/gps/destination_type")
simDR_autopilot_destination_index = find_dataref("sim/cockpit/gps/destination_index")
simDR_autopilot_airspeed_kts = find_dataref("sim/cockpit2/autopilot/airspeed_dial_kts")
simDR_autopilot_airspeed_kts_mach = find_dataref("sim/cockpit2/autopilot/airspeed_dial_kts_mach")
B747DR_fms_setCurrent = find_dataref("xtlua/currentFMSID")
--simDR_autopilot_heading_deg         	= find_dataref("sim/cockpit2/autopilot/heading_dial_deg_mag_pilot")
simDR_autopilot_heading_deg = find_dataref("sim/cockpit/autopilot/heading_mag")
simDR_autopilot_vs_fpm = find_dataref("sim/cockpit2/autopilot/vvi_dial_fpm")
B747DR_autopilot_vs_fpm = find_dataref("laminar/B747/cockpit2/autopilot/vvi_dial_fpm")
simDR_hsi_vdef_dots_pilot           = find_dataref("sim/cockpit2/radios/indicators/hsi_vdef_dots_pilot")

simDR_hsi_ldef_dots_nav1           = find_dataref("sim/cockpit2/radios/indicators/nav1_hdef_dots_pilot")
simDR_hsi_ldef_dots_nav2           = find_dataref("sim/cockpit2/radios/indicators/nav2_hdef_dots_pilot")
simDR_hsi_nav1_horizontal_signal           = find_dataref("sim/cockpit2/radios/indicators/nav1_display_horizontal")
simDR_hsi_nav2_horizontal_signal           = find_dataref("sim/cockpit2/radios/indicators/nav2_display_horizontal")
simDR_hsi_nav1_vertical_signal           = find_dataref("sim/cockpit2/radios/indicators/nav1_display_vertical")
simDR_hsi_nav2_vertical_signal           = find_dataref("sim/cockpit2/radios/indicators/nav2_display_vertical")


simDR_autopilot_state = find_dataref("sim/cockpit/autopilot/autopilot_state")
simDR_autopilot_vs_status = find_dataref("laminar/B747/autopilot/vvi_status")
simDR_autopilot_flch_status = find_dataref("laminar/B747/autopilot/speed_status")
simDR_autopilot_TOGA_vert_status = find_dataref("sim/cockpit2/autopilot/TOGA_status")
B747DR_autopilot_TOGA_status     	= deferred_dataref("laminar/B747/autopilot/TOGA_status","number")
simDR_autopilot_TOGA_lat_status = find_dataref("sim/cockpit2/autopilot/TOGA_lateral_status")
simDR_autopilot_heading_status = find_dataref("sim/cockpit2/autopilot/heading_status")
simDR_autopilot_heading_hold_status = find_dataref("sim/cockpit2/autopilot/heading_hold_status")
simDR_autopilot_alt_hold_status = find_dataref("laminar/B747/autopilot/altitude_hold_status")
B747DR_ap_approach_mode = find_dataref("laminar/B747/autopilot/approach_mode")
B747DR_ap_lnavHeading_mode     	= deferred_dataref("laminar/B747/autopilot/lnavHeading_mode", "number")
--simDR_autopilot_nav_status = find_dataref("sim/cockpit2/autopilot/nav_status")
--simDR_autopilot_gs_status = find_dataref("sim/cockpit2/autopilot/glideslope_status")
simDR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/actual_nav_status")
simDR_autopilot_gs_status = find_dataref("laminar/B747/autopilot/actual_glideslope_status")


B747DR_autopilot_nav_status = find_dataref("laminar/B747/autopilot/nav_status")
B747DR_autopilot_gs_status = find_dataref("laminar/B747/autopilot/glideslope_status")
simDR_nav1_gs_flag = find_dataref("sim/cockpit2/radios/indicators/nav1_flag_glideslope")
simDR_nav2_gs_flag = find_dataref("sim/cockpit2/radios/indicators/nav2_flag_glideslope")
simDR_autopilot_approach_status = find_dataref("sim/cockpit2/autopilot/approach_status")
simDR_autopilot_roll_sync_degrees = find_dataref("sim/cockpit2/autopilot/sync_hold_roll_deg")
simDR_autopilot_roll_status = find_dataref("sim/cockpit2/autopilot/roll_status")
simDR_autopilot_servos_on = find_dataref("laminar/B747/autopilot/servos_on")

simDR_autopilot_fms_vnav = find_dataref("sim/cockpit2/autopilot/fms_vnav")
simDR_autopilot_pitch = find_dataref("sim/cockpit2/autopilot/pitch_status")
B747DR_capt_ap_roll = find_dataref("laminar/B747/autopilot/capt_roll_ref")
B747DR_fo_ap_roll = find_dataref("laminar/B747/autopilot/fo_roll_ref")
B747DR_ap_target_roll = find_dataref("sim/cockpit2/autopilot/flight_director_roll_deg")
simDR_ap_aileron_trim = find_dataref("sim/cockpit2/controls/aileron_trim")
simDR_fo_roll = find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_copilot")
simDR_capt_roll = find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot")
simDR_airspeed_mach = find_dataref("sim/flightmodel/misc/machno")
simDR_vvi_fpm_pilot = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_ind_airspeed_kts_pilot = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
simDR_groundspeed = find_dataref("sim/flightmodel/position/groundspeed")
simDR_latitude = find_dataref("sim/flightmodel/position/latitude")
simDR_longitude = find_dataref("sim/flightmodel/position/longitude")
simDR_ground_track_true = find_dataref("sim/cockpit2/gauges/indicators/ground_track_true_pilot")
B747DR_airspeed_Vmc = find_dataref("laminar/B747/airspeed/Vmc")
B747DR_airspeed_Vmo = find_dataref("laminar/B747/airspeed/Vmo")
simDR_flap_ratio_control = find_dataref("sim/cockpit2/controls/flap_ratio") -- FLAP HANDLE
simDR_autopilot_nav_source = find_dataref("sim/cockpit2/radios/actuators/HSI_source_select_pilot")
simDR_AHARS_roll_deg_pilot = find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot")
--simDR_AHARS_heading_deg_pilot       	= find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")--find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
simDR_AHARS_heading_deg_pilot = find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
simDR_nav1_radio_course_deg = find_dataref("sim/cockpit2/radios/actuators/nav1_course_deg_mag_pilot")
simDR_pressureAlt1 = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_radarAlt1 = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
simDR_radarAlt2 = find_dataref("sim/cockpit2/guages/indicators/radio_altimeter_height_ft_copilot")
simDR_allThrottle = 0 --find_dataref("sim/cockpit2/engine/actuators/throttle_ratio_all")
simDR_override_throttles = find_dataref("sim/operation/override/override_throttles")
simDR_override_fms_progress = find_dataref("sim/operation/override/override_fms_advance")
simDR_descent = find_dataref("sim/cockpit2/autopilot/des_adjust")
simDR_pitch = find_dataref("sim/cockpit2/autopilot/sync_hold_pitch_deg")
simDR_touchGround = find_dataref("sim/flightmodel/failures/onground_any")
simDR_onGround = find_dataref("sim/flightmodel/failures/onground_any")
--simDR_pitch2           	= find_dataref("sim/cockpit2/autopilot/fpa")
B744_fpm = find_dataref("laminar/B747/vsi/fpm")
B747BR_showFMA				= deferred_dataref("laminar/B747/autopilot/FMA/showFMA", "number")
simDR_AHARS_pitch_heading_deg_pilot = find_dataref("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot")
--simDR_AHARS_pitch_heading_deg_pilot=find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
simDR_elevator = find_dataref("sim/flightmodel2/controls/elevator_trim")
simDR_rudder = find_dataref("sim/flightmodel2/controls/rudder_trim")
--simDR_roll=find_dataref("sim/cockpit2/controls/total_roll_ratio")

--simDR_elevator =find_dataref("sim/joystick/artstab_pitch_ratio")--	float	y	[-1..1]	The artificial stability input modifications for pitch. Use override_artstab
simDR_roll = find_dataref("sim/joystick/artstab_roll_ratio")
 --	float	y	[-1..1]	The artificial stability input modifications for roll. Use override_artstab
--simDR_rudder=find_dataref("sim/joystick/artstab_heading_ratio")

simDR_reqHeading = find_dataref("sim/cockpit2/radios/actuators/hsi_obs_deg_mag_pilot")

--simDR_overRideStab = find_dataref("sim/operation/override/override_artstab")
simDR_nav1_radio_nav_type = find_dataref("sim/cockpit2/radios/indicators/nav1_type")
toderate = deferred_dataref("laminar/B747/engine/derate/TO", "number")
clbderate = deferred_dataref("laminar/B747/engine/derate/CLB", "number")
throttlederate = find_dataref("sim/aircraft/engine/acf_throtmax_FWD") -- can use this for engine type?
--[[
    0 = UNKNONW
    4 = VOR
    8 = ILS WITHOUT GLIDESLOPE
   16 = LOCALIZER (ONLY)
   32 = GLIDESLOPE
   40 = ILS WITH GLIDESLOPE
-]]
-- Datarefs for cost index calculations
gwtKG = find_dataref("sim/flightmodel/weight/m_total") -- kilograms
simDR_TAS_mps = find_dataref("sim/flightmodel/position/true_airspeed") -- true airspeed in meters per second
simDR_alpha_deg = find_dataref("sim/flightmodel/position/alpha")
simDR_beta_deg = find_dataref("sim/flightmodel/position/beta")
simDR_GS_mps = find_dataref("sim/flightmodel/position/groundspeed") -- ground airspeed in meters per secon

--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_toggle_switch_position = find_dataref("laminar/B747/toggle_switch/position")
B747DR_CAS_caution_status = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_speedbrake_lever = find_dataref("laminar/B747/flt_ctrls/speedbrake_lever")
B747DR_ap_autoland = deferred_dataref("laminar/B747/autopilot/autoland", "number")
B747DR_ap_autoland = 0
B744DR_autolandPitch = find_dataref("laminar/B747/autopilot/autolandPitch")
B747DR_lastap_dial_airspeed = deferred_dataref("laminar/B747/autopilot/ap_monitor/last_airspeed", "number")
B747DR_max_dial_machspeed = deferred_dataref("laminar/B747/autopilot/ap_monitor/max_dial_machspeed", "number")
B747DR_target_descentAlt = deferred_dataref("laminar/B747/autopilot/ap_monitor/target_descentAlt", "number")
B747DR_target_descentSpeed = deferred_dataref("laminar/B747/autopilot/ap_monitor/target_descentSpeed", "number")
B747DR_descentSpeedGradient = deferred_dataref("laminar/B747/autopilot/ap_monitor/descentSpeedGradient", "number")
B747DR_switchingIASMode = deferred_dataref("laminar/B747/autopilot/ap_monitor/switchingIASMode", "number")
--B747DR_fmstargetIndex = deferred_dataref("laminar/B747/autopilot/ap_monitor/fmstargetIndex", "number")
B747DR_fmstargetDistance           = deferred_dataref("laminar/B747/autopilot/ap_monitor/fmstargetDistance", "number")
B747DR_fmscurrentIndex = deferred_dataref("laminar/B747/autopilot/ap_monitor/fmscurrentIndex", "number")
B747DR_mcp_hold = deferred_dataref("laminar/B747/autopilot/ap_monitor/mcp_hold", "number")
B747DR_mcp_hold_pressed = deferred_dataref("laminar/B747/autopilot/ap_monitor/mcp_hold_pressed", "number")
--*************************************************************************************--
--** 				             FIND X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--

--simCMD_autopilot_autothrottle_on = find_command("sim/autopilot/autothrottle_on")
simCMD_autopilot_autothrottle_off = find_command("sim/autopilot/autothrottle_off")
simDR_version=find_dataref("sim/version/xplane_internal_version")
--simCMD_autopilot_toggle_knots_mach  	= find_command("sim/autopilot/knots_mach_toggle")
simCMD_autopilot_roll_center_sync_mode = find_command("sim/autopilot/override_center")
simCMD_autopilot_roll_right_sync_mode = find_command("sim/autopilot/override_right")
simCMD_autopilot_servos_on = find_command("sim/autopilot/servos_on")
simCMD_autopilot_servos_fdir_off = find_command("sim/autopilot/servos_fdir_off")
simCMD_autopilot_servos2_on = find_command("sim/autopilot/servos2_on")
simCMD_autopilot_servos2_fdir_off = find_command("sim/autopilot/servos_fdir2_off")
simCMD_autopilot_servos3_on = find_command("sim/autopilot/servos3_on")
simCMD_autopilot_servos3_fdir_off = find_command("sim/autopilot/servos_fdir3_off")
simCMD_autopilot_servos_off = find_command("sim/autopilot/servos_off_any")
simCMD_autopilot_fdir_off = find_command("sim/autopilot/servos_fdir_off")
simCMD_autopilot_fdir_servos_down_one = find_command("sim/autopilot/fdir_servos_down_one")
simCMD_autopilot_pitch_sync = find_command("sim/autopilot/pitch_sync")
simCMD_autopilot_set_nav1_as_nav_source = find_command("sim/autopilot/hsi_select_nav_1")
simCMD_autopilot_nav_mode = find_command("sim/autopilot/NAV")
simCMD_autopilot_wing_leveler = find_command("sim/autopilot/wing_leveler")
simCMD_autopilot_heading_select = find_command("sim/autopilot/heading")
simCMD_autopilot_vert_speed_mode = find_command("sim/autopilot/vertical_speed")
simCMD_autopilot_flch_mode = find_command("sim/autopilot/level_change")

--simCMD_autopilot_alt_hold_mode = find_command("sim/autopilot/altitude_hold")
simCMD_autopilot_glideslope_mode = find_command("sim/autopilot/glide_slope")


--*************************************************************************************--
--** 				              FIND CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747DR_engine_TOGA_mode = find_dataref("laminar/B747/engines/TOGA_mode")

B747DR_autothrottle_fail = find_dataref("laminar/B747/engines/autothrottle_fail")

B747DR_hyd_sys_pressure_1      = deferred_dataref("laminar/B747/hydraulics/pressure_1", "number") -- AP C
B747DR_hyd_sys_pressure_2      = deferred_dataref("laminar/B747/hydraulics/pressure_2", "number") -- AP R
B747DR_hyd_sys_pressure_3      = deferred_dataref("laminar/B747/hydraulics/pressure_3", "number") -- AP L

B747DR_radioModes = deferred_dataref("laminar/B747/radio/tuningmodes", "string")
B747DR_FMSdata = deferred_dataref("laminar/B747/fms/data", "string")
--B747DR_efis_baro_capt_set_dial_pos              = deferred_dataref("laminar/B747/efis/baro/capt/set_dial_pos", "number")
B747DR_efis_baro_std_capt_switch_pos = deferred_dataref("laminar/B747/efis/baro_std/capt/switch_pos", "number")
B747DR_efis_baro_capt_preselect = deferred_dataref("laminar/B747/efis/baro/capt/preselect", "number")
B747DR_efis_baro_std_fo_switch_pos = deferred_dataref("laminar/B747/efis/baro_std/fo/switch_pos", "number")
simDR_altimeter_baro_inHg = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
simDR_altimeter_baro_inHg_fo = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot")
--B747DR_efis_baro_fo_set_dial_pos                = deferred_dataref("laminar/B747/efis/baro/fo/set_dial_pos", "number")
B747DR_efis_baro_fo_preselect = deferred_dataref("laminar/B747/efis/baro/fo/preselect", "number")
B747DR_ap_button_switch_position =
	deferred_dataref("laminar/B747/autopilot/button_switch/position", "array[" .. tostring(NUM_AUTOPILOT_BUTTONS) .. "]")
B747DR_ap_bank_limit_sel_dial_pos = deferred_dataref("laminar/B747/autopilot/bank_limit/sel_dial_pos", "number")
B747DR_ap_ias_mach_window_open = deferred_dataref("laminar/B747/autopilot/ias_mach/window_open", "number")
B747DR_ap_vs_window_open = deferred_dataref("laminar/B747/autopilot/vert_spd/window_open", "number")
B747DR_ap_vs_show_thousands = deferred_dataref("laminar/B747/autopilot/vert_speed/show_thousands", "number")
--B747DR_ap_hdg_hold_mode             	= deferred_dataref("laminar/B747/autopilot/heading_hold_mode", "number")
--B747DR_ap_hdg_sel_mode              	= deferred_dataref("laminar/B747/autopilot/heading_sel_mode", "number")
B747DR_autopilot_altitude_ft = find_dataref("laminar/B747/autopilot/heading/altitude_dial_ft")
B747DR_autopilot_altitude_ft_pfd = deferred_dataref("laminar/B747/autopilot/heading/altitude_dial_ft_pfd", "number")
B747DR_ap_heading_deg = deferred_dataref("laminar/B747/autopilot/heading/degrees", "number")
B747DR_ap_target_heading_deg = deferred_dataref("laminar/B747/autopilot/heading/target", "number")
B747DR_ap_activate_target_heading_deg   = deferred_dataref("laminar/B747/autopilot/heading/active_target", "number")
B747DR_ap_target_speed               	= deferred_dataref("laminar/B747/autopilot/speed/target", "number")
B747DR_ap_target_altitude               	= deferred_dataref("laminar/B747/autopilot/altitude/target", "number")
B747DR_ap_target_vertspeed               	= deferred_dataref("laminar/B747/autopilot/vertspeed/target", "number")
B747DR_ap_target_flaps   = deferred_dataref("laminar/B747/autopilot/flaps/target", "number")
B747DR_ap_ias_dial_value = deferred_dataref("laminar/B747/autopilot/ias_dial_value", "number")
B747DR_ap_ias_bug_value = deferred_dataref("laminar/B747/autopilot/ias_bug_value", "number")
B747DR_ap_ias_bug_value_pfd = deferred_dataref("laminar/B747/autopilot/ias_bug_value_pfd", "number")
B747DR_ap_ias_mach_dial_value = deferred_dataref("laminar/B747/autopilot/ias_mach_dial_value", "number") -- display only
B747DR_airspeed_V2 = deferred_dataref("laminar/B747/airspeed/V2", "number")
B747DR_ap_vnav_system = deferred_dataref("laminar/B747/autopilot/vnav_system", "number")
B747DR_ap_vnav_target_alt = deferred_dataref("laminar/B747/autopilot/vnav_target_alt", "number")
B747DR_ap_vnav_state = deferred_dataref("laminar/B747/autopilot/vnav_state", "number")
B747DR_ap_lnav_state = deferred_dataref("laminar/B747/autopilot/lnav_state", "number")
B747DR_ap_lnav_xtk_error           	= deferred_dataref("laminar/B747/autopilot/lnav/xtk_error", "number")
B747DR_ap_lnav_xtk_target           	= deferred_dataref("laminar/B747/autopilot/lnav/xtk_target", "number")
-- the route index of a fix LNAV sequenced early for its turn, whose altitude VNAV keeps until the aircraft
-- is past the turn's bisector; 0 when none
B747DR_vnav_hold_index           	= deferred_dataref("laminar/B747/autopilot/lnav/vnav_hold_index", "number")
-- the SID, STAR and approach found in the CIFP for the route's constraints (B747_update_route_constraints)
B747DR_vnav_procedures           	= deferred_dataref("laminar/B747/autopilot/vnav/procedures", "string")
-- the speed (kt) the route's constraints allow VNAV now, 0 for none (B747_update_constraint_speed)
B747DR_vnav_constraint_speed     	= deferred_dataref("laminar/B747/autopilot/vnav/constraint_speed", "number")
B747DR_ap_inVNAVdescent = deferred_dataref("laminar/B747/autopilot/vnav_descent", "number")
B747DR_ap_inDescent 		= deferred_dataref("laminar/B747/autopilot/vnav/after_tod", "number")
B747DR_vnav_energy_active = deferred_dataref("laminar/B747/autopilot/vnav/energy_active", "number")
B747DR_vnav_energy_state = deferred_dataref("laminar/B747/autopilot/vnav/energy_state", "number")
B747DR_vnav_energy_thrust_policy = deferred_dataref("laminar/B747/autopilot/vnav/energy_thrust_policy", "number")
B747DR_vnav_energy_thrust_reason = deferred_dataref("laminar/B747/autopilot/vnav/energy_thrust_reason", "number")
B747DR_vnav_energy_path_trend = deferred_dataref("laminar/B747/autopilot/vnav/energy_path_trend_fpm", "number")
B747DR_vnav_energy_target_vspeed = deferred_dataref("laminar/B747/autopilot/vnav/energy_target_vspeed_fpm", "number")
B747DR_vnav_energy_drag_required = deferred_dataref("laminar/B747/autopilot/vnav/energy_drag_required", "number")
B747DR_ap_flightPhase = deferred_dataref("laminar/B747/autopilot/flightPhase", "number")
B747DR_ap_active_land = deferred_dataref("laminar/B747/autopilot/active_land", "number")
-- 0 take off
-- 1 climb
-- 2 cruise
-- 3 descend
-- 4 landing
B747DR_airspeed_Mms = deferred_dataref("laminar/B747/airspeed/Mms", "number")
B747DR_ap_vvi_fpm = deferred_dataref("laminar/B747/autopilot/vvi_fpm", "number")
B747DR_ap_alt_show_thousands = deferred_dataref("laminar/B747/autopilot/altitude/show_thousands", "number")
B747DR_ap_alt_show_tenThousands = deferred_dataref("laminar/B747/autopilot/altitude/show_tenThousands", "number")
B747DR_ap_cmd_L_mode = deferred_dataref("laminar/B747/autopilot/cmd_L_mode/status", "number")
B747DR_ap_cmd_C_mode = deferred_dataref("laminar/B747/autopilot/cmd_C_mode/status", "number")
B747DR_ap_cmd_R_mode = deferred_dataref("laminar/B747/autopilot/cmd_R_mode/status", "number")
B747DR_ap_autothrottle_armed = deferred_dataref("laminar/B747/autothrottle/armed", "number")
B747DR_ap_mach_decimal_visibiilty = deferred_dataref("laminar/B747/autopilot/mach_dec_vis", "number")
B747DR_ap_fpa = deferred_dataref("laminar/B747/autopilot/navadata/fpa", "number")
B747DR_ap_vb = deferred_dataref("laminar/B747/autopilot/navadata/vb", "number")
B747DR_flight_director_pitch = find_dataref("laminar/B747/autopilot/flight_director_pitch_deg")

B747DR_ap_FMA_autothrottle_mode_box_status =
	deferred_dataref("laminar/B747/autopilot/FMA/autothrottle/mode_box_status", "number")
B747DR_ap_roll_mode_box_status = deferred_dataref("laminar/B747/autopilot/FMA/roll/mode_box_status", "number")
B747DR_ap_pitch_mode_box_status = deferred_dataref("laminar/B747/autopilot/FMA/pitch/mode_box_status", "number")
B747DR_ap_ATT     	                = deferred_dataref("laminar/B747/autopilot/att_rate", "number")
B747DR_ap_FMA_autothrottle_mode = deferred_dataref("laminar/B747/autopilot/FMA/autothrottle_mode", "number")
--[[
    0 = NONE
    1 = HOLD
    2 = IDLE
    3 = SPD
    4 = THR
    5 = THR REF
--]]
B747DR_ap_FMA_armed_roll_mode = deferred_dataref("laminar/B747/autopilot/FMA/armed_roll_mode", "number")
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
B747DR_ap_FMA_active_roll_mode = deferred_dataref("laminar/B747/autopilot/FMA/active_roll_mode", "number")
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
B747DR_ap_FMA_armed_pitch_mode = deferred_dataref("laminar/B747/autopilot/FMA/armed_pitch_mode", "number")
--[[
    0 = NONE
    1 = TOGA
    2 = G/S
    3 = FLARE
    4 = VNAV
    7 = V/S
    8 = FLCH SPD
    9 = ALT
--]]
B747DR_ap_FMA_active_pitch_mode = deferred_dataref("laminar/B747/autopilot/FMA/active_pitch_mode", "number")
--[[
    0 = NONE
    1 = TOGA
    2 = G/S
    3 = FLARE
    4 = VNAV SPD
    5 = VNAV ALT
    6 = VNAV PATH
    7 = V/S
    8 = FLCH SPD
    9 = ALT
--]]
B747DR_ap_AFDS_mode_box_status_pilot = deferred_dataref("laminar/B747/autopilot/AFDS/mode_box_status_pilot", "number")
B747DR_ap_AFDS_mode_box_status_copilot =
	deferred_dataref("laminar/B747/autopilot/AFDS/mode_box_status_copilot", "number")
B747DR_ap_AFDS_mode_box2_status_pilot = deferred_dataref("laminar/B747/autopilot/AFDS/mode_box2_status_pilot", "number")
B747DR_ap_AFDS_mode_box2_status_copilot =
	deferred_dataref("laminar/B747/autopilot/AFDS/mode_box2_status_copilot", "number")

B747DR_ap_AFDS_status_annun_pilot = deferred_dataref("laminar/B747/autopilot/AFDS/status_annun_pilot", "number")
B747DR_ap_AFDS_status_annun_copilot = deferred_dataref("laminar/B747/autopilot/AFDS/status_annun_copilot", "number")
--[[
    0 = NONE
    1 = FD
    2 = CMD
    3 = LAND 2
    4 = LAND 3
    5 = NO AUTOLAND
--]]
--Marauder28
B747DR_ref_thr_limit_mode = deferred_dataref("laminar/B747/engines/ref_thr_limit_mode", "string")
--[[
    ["NONE"]
    ["TO"]
    ["TO 1"]
    ["TO 2"]
    ["D-TO"]
    ["D-TO 1"]
    ["D-TO 2"]
    ["CLB"]
    ["CLB 1"]
    ["CLB 2"]
    ["CRZ"]
    ["CON"]
    ["GA"]
]]
-- Holds all SimConfig options
B747DR_simconfig_data = deferred_dataref("laminar/B747/simconfig", "string")
B747DR_newsimconfig_data = deferred_dataref("laminar/B747/newsimconfig", "number")
--Simulator Config Options
simConfigData = {}

--Marauder28
if string.len(B747DR_simconfig_data) > 1 then
	simConfigData["data"] = json.decode(B747DR_simconfig_data)
end
--Marauder28

--Marauder28

--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--

--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

--*************************************************************************************--
--** 				             CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--
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
function isATEnabled()
	if B747DR_toggle_switch_position[29] == 1 and B747DR_autothrottle_fail == 0 then return true end
	return false
end
local B747_afds_helpers = dofile("B747.70.xt.autopilot.afds_helpers.lua")
local B747_constraints = dofile("B747.70.xt.autopilot.constraints.lua")

-- Set true only while collecting AFDS tuning data.  Output is rate limited below.
local AFDS_DIAGNOSTICS_ENABLED = false
local AFDS_DIAGNOSTIC_INTERVAL_SEC = 1.0
local AFDS_DIAGNOSTIC_TURN_BANK_DEG = 25.0
local AFDS_DIAGNOSTIC_MIN_ANTICIPATION_NM = 0.5
local AFDS_DIAGNOSTIC_MAX_ANTICIPATION_NM = 8.0
local B747_afds_last_diagnostic_time = -AFDS_DIAGNOSTIC_INTERVAL_SEC

local function B747_afds_valid_waypoint(waypoint)
	return waypoint ~= nil and type(waypoint[5]) == "number" and type(waypoint[6]) == "number"
end

local function B747_afds_log_diagnostics(fms)
	if not AFDS_DIAGNOSTICS_ENABLED or simDRTime - B747_afds_last_diagnostic_time < AFDS_DIAGNOSTIC_INTERVAL_SEC then
		return
	end
	B747_afds_last_diagnostic_time = simDRTime

	local leg_index = B747DR_fmscurrentIndex
	local distance_nm = -1
	local turn_angle_deg = -1
	local turn_radius_nm = -1
	local anticipation_nm = -1
	local signed_xtk_nm = 0
	if fms ~= nil and B747_afds_valid_waypoint(fms[leg_index]) then
		distance_nm = getDistance(simDR_latitude, simDR_longitude, fms[leg_index][5], fms[leg_index][6])
		if B747_afds_valid_waypoint(fms[leg_index - 1]) then
			signed_xtk_nm = B747_afds_helpers.signed_cross_track_nm(
				fms[leg_index - 1][5], fms[leg_index - 1][6], fms[leg_index][5], fms[leg_index][6],
				simDR_latitude, simDR_longitude, getDistance, getHeading) or 0
		end
		if B747_afds_valid_waypoint(fms[leg_index - 1]) and B747_afds_valid_waypoint(fms[leg_index + 1]) then
			local incoming_heading = getHeading(fms[leg_index - 1][5], fms[leg_index - 1][6],
				fms[leg_index][5], fms[leg_index][6])
			local outgoing_heading = getHeading(fms[leg_index][5], fms[leg_index][6],
				fms[leg_index + 1][5], fms[leg_index + 1][6])
			turn_angle_deg = math.abs(getHeadingDifference(outgoing_heading, incoming_heading))
			local anticipation, radius = B747_afds_helpers.turn_anticipation_nm(
				simDR_groundspeed * 1.94384449, AFDS_DIAGNOSTIC_TURN_BANK_DEG, turn_angle_deg,
				AFDS_DIAGNOSTIC_MIN_ANTICIPATION_NM, AFDS_DIAGNOSTIC_MAX_ANTICIPATION_NM)
			anticipation_nm = anticipation or -1
			turn_radius_nm = radius or -1
		end
	end

	local vnav_state = "unknown"
	local vnav_reason = "none"
	if B747_get_vnav_speed_diagnostics ~= nil then
		local diagnostics = B747_get_vnav_speed_diagnostics()
		vnav_state = diagnostics.state or vnav_state
		vnav_reason = diagnostics.reason or vnav_reason
	end

	print(string.format(
		"[AFDS NAV] roll=%d/%d pitch=%d/%d leg=%d dist=%.2fnm turn=%.1fdeg radius=%.2fnm anticipate=%.2fnm xtk=%+.2fnm heading=%.1f bankCmd=%.1f bank=%.1f vnav=%s target=%.2f reason=%s",
		B747DR_ap_FMA_active_roll_mode, B747DR_ap_FMA_armed_roll_mode,
		B747DR_ap_FMA_active_pitch_mode, B747DR_ap_FMA_armed_pitch_mode,
		leg_index, distance_nm, turn_angle_deg, turn_radius_nm, anticipation_nm, signed_xtk_nm,
		simDR_autopilot_heading_deg, B747DR_ap_target_roll, simDR_capt_roll,
		tostring(vnav_state), B747DR_ap_ias_dial_value, tostring(vnav_reason)))
end
dofile("B747.70.xt.autopilot.vnav.lua")
function autothrottle_reengage()
	if B747DR_autothrottle_active == 0 and isATEnabled() and simDR_onGround == 0 then
		--simCMD_autopilot_autothrottle_on:once()
		B747DR_autothrottle_active=1
	end
end

function B747_ap_thrust_mode_CMDhandler(phase, duration) -- INOP, NO CORRESPONDING FUNCTIONALITY IN X-PLANE
	if phase == 0 then
		B747_ap_button_switch_position_target[0] = 1
		--simCMD_autopilot_autothrottle_off:once()
		B747DR_autothrottle_active=0
		B747DR_ap_lastCommand = simDRTime
		if simDR_radarAlt1 > 400 then
			B747DR_ap_thrust_mode = 3
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[0] = 0
	end
end

function B747_ap_switch_speed_mode_CMDhandler(phase, duration)
	print("B747_ap_switch_speed_mode_CMDhandler "..phase.." "..duration)
	if phase == 0 then
		B747CMD_fdr_log_spd:once()
		B747_ap_button_switch_position_target[1] = 1 -- SET THE SPEED SWITCH ANIMATION TO "IN"
		B747DR_ap_lastCommand = simDRTime

		if isATEnabled() and simDR_onGround == 0 then -- AUTOTHROTTLE ""ARM" SWITCH IS "ON"

			B747DR_autothrottle_active=1

			if B747DR_engine_TOGA_mode > 0 then
				B747DR_engine_TOGA_mode = 0
			end -- CANX ENGINE TOGA IF ACTIVE
		end
		B747DR_ap_vnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		if simDR_autopilot_flch_status~=0 then
		 simDR_autopilot_flch_status=0
		 if simDR_autopilot_vs_status==0 and  simDR_autopilot_alt_hold_status==0 then
			simDR_autopilot_vs_status=2
		 end
		end
		--B747DR_ap_flightPhase = 2
		if B747DR_autopilot_altitude_ft > simDR_pressureAlt1 then
			B747DR_ap_flightPhase = 1
		else
			B747DR_ap_flightPhase = 3
		end
		--print("B747DR_ap_thrust_mode " .. B747DR_ap_thrust_mode)
		B747DR_ap_thrust_mode = 0
		--print("B747DR_ap_thrust_mode " .. B747DR_ap_thrust_mode)
		if B747DR_switchingIASMode == 0 then
			if simDR_autopilot_airspeed_is_mach == 0 then
				simDR_autopilot_airspeed_kts = B747DR_ap_ias_dial_value
			elseif simDR_autopilot_airspeed_is_mach == 1 and B747DR_ap_ias_dial_value * 0.01 then
				simDR_autopilot_airspeed_kts_mach = B747DR_ap_ias_dial_value * 0.01 ---roundToIncrement(B747DR_ap_ias_dial_value, 1) * 0.01
			end
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[1] = 0 -- SET THE SPEED SWITCH ANIMATION TO "OUT"
	end
end
function B747_ap_switch_vnavspeed_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_spdmod:once()
		-- every push acts: a push that finds the knob still in (its release lost,
		-- as for a command fired once) is a new push, not the release
		B747_ap_button_switch_position_target[15] = 1 -- SET THE SPEED KNOB ANIMATION TO "IN"
		if B747DR_ap_vnav_state == 2 and B747DR_switchingIASMode==0 then
			setVNAVState("manualVNAVspd", 1 - getVNAVState("manualVNAVspd"))
			if getVNAVState("manualVNAVspd") == 0 then
				B747_invalidate_vnav_speed("manual speed intervention ended")
				B747_vnav_speed()
			end
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[15] = 0 -- SET THE SPEED KNOB ANIMATION TO "OUT"
	end
end

function update_new_crzalt()
	print("doing set new cruise to "..B747BR_cruiseAlt)
	if simDR_autopilot_alt_hold_status==2 and B747DR_ap_vnav_state>1 then
		-- Leave the hold only for a climb that still stands: CRZ ALT may be
		-- back at this level by now, and near T/D the climb is not started.
		local climbAction=B747_afds_helpers.cruise_climb_action(B747BR_cruiseAlt,
			simDR_pressureAlt1, B747BR_totalDistance - B747BR_tod, B747DR_alt_capture_window)
		if climbAction~="climb" then
			print("no cruise climb to "..B747BR_cruiseAlt..": "..climbAction)
			return
		end
		B747DR_mcp_hold = 0
		simDR_autopilot_alt_hold_status=0
		if B747DR_autopilot_altitude_ft > simDR_pressureAlt1 then
			B747DR_ap_flightPhase = 1
		else
			B747DR_ap_flightPhase = 3
		end
		B747DR_mcp_hold_pressed = simDRTime
		setVNAVState("vnavcalcwithTargetAlt", 0)
		if getVNAVState("manualVNAVspd") == 0 then
			B747_invalidate_vnav_speed("new cruise altitude accepted")
			B747_vnav_speed()
		end

		if B747DR_ap_vnav_state == 2 then
			B747DR_ap_vnav_state = 3 --resume
		end
		-- Near T/D, descend only to an MCP altitude below the aircraft.
		if B747BR_totalDistance - B747BR_tod <= 50
			and B747DR_autopilot_altitude_ft < simDR_pressureAlt1 then
			B747DR_ap_inVNAVdescent = 1
			B747DR_ap_flightPhase = 3
			setDescent(true)
			print("Begin descent 1")
			getDescentTarget()
		end
	end
end

function B747_ap_switch_vnavalt_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_altmod:once()
		B747DR_ap_lastCommand = simDRTime
		print("vnav alt button")

		-- every push acts: a push that finds the knob still in (its release lost,
		-- as for a command fired once) is a new push, not the release
		B747_ap_button_switch_position_target[16] = 1 -- SET THE ALT KNOB ANIMATION TO "IN"

		local currentCruiseAltitude=tonumber(B747BR_cruiseAlt) or 0
		local isVnavClimbOrCruise=simDR_onGround==0
			and B747DR_ap_vnav_state>1
			and B747DR_ap_inVNAVdescent==0
			and currentCruiseAltitude>0
		local isVnavCruise=isVnavClimbOrCruise
			and simDR_autopilot_alt_hold_status==2
			and math.abs(simDR_pressureAlt1-currentCruiseAltitude)<=500
		if isVnavCruise and B747DR_autopilot_altitude_ft>currentCruiseAltitude then
			B747BR_cruiseAlt = B747DR_autopilot_altitude_ft
			setFMSData("stepto", "*****")
			setFMSData("stepatwpt", "")
			print("set new cruise to "..B747BR_cruiseAlt)
			if is_timer_scheduled(update_new_crzalt) then
				stop_timer(update_new_crzalt)
			end
			run_after_time(update_new_crzalt, 2.0)
			B747DR_mcp_hold_pressed = simDRTime
			return
		end

		-- VNAV climb altitude intervention: with the MCP altitude above CRZ
		-- ALT, pushing the selector resets CRZ ALT to the MCP altitude and
		-- VNAV keeps climbing to it (resuming from VNAV ALT below).
		if isVnavClimbOrCruise and B747DR_autopilot_altitude_ft>currentCruiseAltitude then
			B747BR_cruiseAlt = B747DR_autopilot_altitude_ft
			print("set new cruise in climb to "..B747BR_cruiseAlt)
		end

		if simDR_autopilot_alt_hold_status==2 and B747DR_ap_vnav_state>1 then
			simDR_autopilot_altitude_ft=B747DR_autopilot_altitude_ft

			if B747DR_autopilot_altitude_ft > simDR_pressureAlt1 then

				B747DR_ap_flightPhase = 1
			else
				B747DR_ap_flightPhase = 3
			end
			B747DR_mcp_hold = 0
			simDR_autopilot_alt_hold_status=0
			B747DR_mcp_hold_pressed = simDRTime
			setVNAVState("vnavcalcwithTargetAlt", 0)
			if getVNAVState("manualVNAVspd") == 0 then
				B747_invalidate_vnav_speed("MCP altitude selector pushed")
				B747_vnav_speed()
			end

			if B747DR_ap_vnav_state == 2 then
				B747DR_ap_vnav_state = 3 --resume
			end
			-- Near T/D, descend only to an MCP altitude below the aircraft:
			-- a push for a climb must not start the descent.
			if B747BR_totalDistance - B747BR_tod <= 50
				and B747DR_autopilot_altitude_ft < simDR_pressureAlt1 then
				B747DR_ap_inVNAVdescent = 1
				B747DR_ap_flightPhase = 3
				setDescent(true)
				print("Begin descent 2")
				getDescentTarget()
			end
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[16] = 0 -- SET THE ALT KNOB ANIMATION TO "OUT"
	end
end

function B747_ap_ias_mach_sel_button_CMDhandler(phase, duration) -- INOP, NO CORRESPONDING FUNCTIONALITY IN X-PLANE
	-- print("B747_ap_ias_mach_sel_button_CMDhandler")
	if phase == 0 then
		if simDR_autopilot_airspeed_is_mach == 0 then
			B747DR_ap_ias_dial_value = math.floor(simDR_ind_airspeed_kts_pilot)
		else
			B747DR_ap_ias_dial_value = math.floor(simDR_airspeed_mach * 100)
		end

	-- TODO: IN VNAV THIS ALTERNATELY OPENS AND CLOSES IAS/MACH WINDOW AND CONTROLS VNAV INTERACTION (FCOM Pg 643)
	-- TODO: CURRENTLY INOP - THE CURRENT XP FMS DOES NOT ALLOW THIS OPTION
	end
end

function B747_ap_switch_flch_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_flch:once()
		B747_ap_button_switch_position_target[4] = 1
		B747DR_ap_lastCommand = simDRTime
		simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
		simDR_autopilot_hold_altitude_ft=simDR_autopilot_altitude_ft
		B747DR_autopilot_TOGA_status=0
		if B747DR_ap_vnav_state == 0 or (simDR_autopilot_flch_status == 0 and B747DR_ap_vnav_state > 0) then
			simCMD_autopilot_flch_mode:once()
			simDR_autopilot_flch_status=2
            simDR_autopilot_vs_status=0
            simDR_autopilot_alt_hold_status=0
			--simDR_autopilot_flch_status=2

		end
		simDR_autopilot_alt_hold_status=0
		B747DR_ap_vnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		if B747DR_autopilot_altitude_ft > simDR_pressureAlt1 then
			B747DR_ap_flightPhase = 1
		else
			B747DR_ap_flightPhase = 3
		end
		B747DR_ap_thrust_mode = 2
	elseif phase == 2 then
		B747_ap_button_switch_position_target[4] = 0
	end
end

function B747_ap_switch_vs_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_vs:once()
		local cAlt = simDR_radarAlt1
		B747_ap_button_switch_position_target[6] = 1
		--for animation

		if B747DR_autothrottle_active == 0 and isATEnabled() and simDR_onGround == 0 then -- AUTOTHROTTLE IS "OFF"
			--simCMD_autopilot_autothrottle_on:once() -- ACTIVATE THE AUTOTHROTTLE
			B747DR_autothrottle_active=1

		end
		B747DR_engine_TOGA_mode = 0
		B747DR_autopilot_TOGA_status=0
		simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
		simDR_autopilot_hold_altitude_ft=simDR_autopilot_altitude_ft
		simDR_autopilot_alt_hold_status=0
		B747DR_ap_thrust_mode = 0
		B747DR_ap_inVNAVdescent = 0
		if B747DR_autopilot_altitude_ft > simDR_pressureAlt1 then
			B747DR_ap_flightPhase = 1
		else
			B747DR_ap_flightPhase = 3
		end
		if B747DR_ap_vnav_state == 0 or (simDR_autopilot_vs_status == 0 and B747DR_ap_vnav_state > 0) then
			simCMD_autopilot_vert_speed_mode:once()
			simDR_autopilot_vs_status=2
			simDR_autopilot_vs_fpm = 0
			B747DR_ap_vvi_fpm = 0
			B747DR_autopilot_vs_fpm = 0
		end
		B747DR_ap_vnav_state = 0
	elseif phase == 2 then
	--for autpilot
	end
end

function B747_ap_alt_hold_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_alt:once()
		B747_ap_button_switch_position_target[7] = 1
		if B747DR_autothrottle_active == 0 and isATEnabled() then -- AUTOTHROTTLE IS "OFF"
			--simCMD_autopilot_autothrottle_on:once() -- ACTIVATE THE AUTOTHROTTLE
			B747DR_autothrottle_active=1
			B747DR_engine_TOGA_mode = 0
		end

		if simDR_autopilot_alt_hold_status == 2 and B747DR_ap_vnav_state > 0 then
			print("dont leave alt hold")
			simDR_autopilot_hold_altitude_ft=simDR_pressureAlt1
		else
			--simCMD_autopilot_alt_hold_mode:once()
			simDR_autopilot_alt_hold_status = 2
			simDR_autopilot_vs_status=0
            simDR_autopilot_flch_status=0
			simDR_autopilot_hold_altitude_ft=simDR_pressureAlt1
		end
		B747DR_ap_thrust_mode = 0
		B747DR_ap_vnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		B747DR_ap_flightPhase = 2
		B747DR_autopilot_TOGA_status=0
	elseif phase == 2 then
		B747_ap_button_switch_position_target[7] = 0
	end
end


function B747_ap_switch_cmd_L_CMDhandler(phase, duration)
	print("B747_ap_switch_cmd_L_CMDhandler "..phase.." "..duration)
	if phase == 0 then
		--B747CMD_ap_reset:once()
		B747CMD_fdr_log_apon:once()
		B747DR_CAS_warning_status[0] = 0
		if B747DR_ap_button_switch_position[14] == 0 then -- DISENGAGE BAR IS "UP/OFF"
			if B747DR_ap_cmd_L_mode == 0 and simDR_radarAlt1>400 and (B747DR_ap_cmd_R_mode+B747DR_ap_cmd_C_mode)==0 then -- LEFT CMD AP MODE IS "OFF"
				if simDR_autopilot_servos_on == 0 then -- AUTOPILOT IS NOT ENGAGED
					--simCMD_autopilot_servos_on:once()

					B747DR_switching_servos_on = simDRTime -- TURN THE AP SERVOS "ON"
					simDR_autopilot_servos_on=1
				end
				B747DR_ap_cmd_L_mode = 1 -- SET AP CMD L MODE TO "ON"
			end
		end
	elseif phase == 1 then
		B747_ap_button_switch_position_target[10] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
	elseif phase == 2 then
		B747_ap_button_switch_position_target[10] = 0 -- SET THE BUTTON ANIMATION TO "UP"

	end
end

function B747_ap_switch_cmd_C_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_apon:once()
		B747_ap_button_switch_position_target[11] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
		B747DR_CAS_warning_status[0] = 0
	elseif phase == 2 then
		B747_ap_button_switch_position_target[11] = 0 -- SET THE BUTTON ANIMATION TO "UP"
		if B747DR_ap_button_switch_position[14] == 0 then -- DISENGAGE BAR IS "UP/OFF"
			if B747DR_ap_cmd_C_mode == 0 and simDR_radarAlt1>400 and (B747DR_ap_cmd_L_mode+B747DR_ap_cmd_R_mode)==0 then -- CENTER CMD AP MODE IS "OFF"
				if simDR_autopilot_servos_on == 0 then -- AUTOPILOT IS NOT ENGAGED
					--simCMD_autopilot_servos2_on:once()
					--simCMD_autopilot_servos_on:once()
					simDR_autopilot_servos_on=1
					B747DR_switching_servos_on = simDRTime
				end
				B747DR_ap_cmd_C_mode = 1 -- SET AP CMD C MODE TO "ON"
			end
		end
	end
end

function B747_ap_switch_cmd_R_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_apon:once()
		B747_ap_button_switch_position_target[12] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
		B747DR_CAS_warning_status[0] = 0
	elseif phase == 2 then
		B747_ap_button_switch_position_target[12] = 0 -- SET THE BUTTON ANIMATION TO "UP"
		if B747DR_ap_button_switch_position[14] == 0 then -- DISENGAGE BAR IS "UP/OFF"
			if B747DR_ap_cmd_R_mode == 0 and simDR_radarAlt1>400 and (B747DR_ap_cmd_L_mode+B747DR_ap_cmd_C_mode)==0 then -- RIGHT CMD AP MODE IS "OFF"
				if simDR_autopilot_servos_on == 0 then -- AUTOPILOT IS NOT ENGAGED
					--simCMD_autopilot_servos3_on:once()
					--simCMD_autopilot_servos_on:once()
					simDR_autopilot_servos_on=1
					B747DR_switching_servos_on = simDRTime
				end
				B747DR_ap_cmd_R_mode = 1 -- SET AP CMD R MODE TO "ON"
			end
		end
	end
end

function B747_ap_switch_disengage_bar_CMDhandler(phase, duration) --disengage bar
	if phase == 0 then
		B747CMD_fdr_log_apdisconnect:once()
		B747_ap_button_switch_position_target[14] = 1.0 - B747_ap_button_switch_position_target[14]
		B747DR_ap_lastCommand = simDRTime
		if B747_ap_button_switch_position_target[14] == 1.0 then -- DISENGAGE
			local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
			if numAPengaged > 0 then
				B747DR_CAS_warning_status[0] = 1
			end
			if B747DR_autothrottle_active == 1 then
				run_after_time(autothrottle_reengage,0.5)
			end
			B747CMD_ap_reset:once() -- TURN FLIGHT DIRECTOR AND SERVOS "OFF"
			B747_ap_all_cmd_modes_off()
			B747DR_ap_lastCommand=simDRTime
			simCMD_autopilot_servos_off:once()
			simCMD_autopilot_servos_fdir_off:once()
			simCMD_autopilot_servos2_fdir_off:once()
			simCMD_autopilot_servos3_fdir_off:once()
			simDR_autopilot_servos_on=0

		else
			B747DR_CAS_warning_status[0] = 0
		end
	end
end

function B747_ap_switch_yoke_disengage_capt_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_apdisconnect:once()
		B747DR_ap_lastCommand = simDRTime
		local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
		if B747DR_CAS_warning_status[0] == 0 and numAPengaged > 0 then
			B747DR_CAS_warning_status[0] = 1
		else
			B747DR_CAS_warning_status[0] = 0
		end
		if B747DR_autothrottle_active == 1 then
			run_after_time(autothrottle_reengage,0.5)
		end
		B747CMD_ap_reset:once()
		simCMD_autopilot_servos_off:once()
		simDR_autopilot_servos_on=0
		--simCMD_autopilot_fdir_servos_down_one:once()							-- TURN ONLY THE SERVOS OFF, LEAVE FLIGHT DIRECTOR ON
		B747_ap_all_cmd_modes_off()
		B747DR_ap_lastCommand=simDRTime
	end
end

function B747_ap_switch_yoke_disengage_fo_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_apdisconnect:once()
		B747DR_ap_lastCommand = simDRTime
		local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
		if B747DR_CAS_warning_status[0] == 0 and numAPengaged > 0 then
			B747DR_CAS_warning_status[0] = 1
		else
			B747DR_CAS_warning_status[0] = 0
		end
		if B747DR_autothrottle_active == 1 then
			run_after_time(autothrottle_reengage,0.5)
		end
		B747CMD_ap_reset:once()
		simCMD_autopilot_servos_off:once()
		simDR_autopilot_servos_on=0
		--simCMD_autopilot_fdir_servos_down_one:once()							-- TURN ONLY THE SERVOS OFF, LEAVE FLIGHT DIRECTOR ON
		B747_ap_all_cmd_modes_off()
		B747DR_ap_lastCommand=simDRTime
	end
end

function B747_ap_switch_autothrottle_disco_L_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_autothrottle_fail == 0 then
			B747DR_autothrottle_fail = 1
		else
			B747DR_autothrottle_fail = 0
		end
	end
end

function B747_ap_switch_autothrottle_disco_R_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_autothrottle_fail == 0 then
			B747DR_autothrottle_fail = 1
		else
			B747DR_autothrottle_fail = 0
		end
	end
end

function B747_ap_att_mode_CMDhandler(phase, duration)
	--[[if phase == 0 then
		if simDR_AHARS_roll_deg_pilot > 30.0 then
			simDR_autopilot_roll_sync_degrees = 30.0 -- LIMIT TO 30 DEGREES
			simCMD_autopilot_roll_right_sync_mode:once() -- ACTIVATE ROLL SYNC (RIGHT) MODE
		elseif simDR_AHARS_roll_deg_pilot < -30.0 then
			simDR_autopilot_roll_sync_degrees = -30.0 -- LIMIT TO 30 DEGREES
			simCMD_autopilot_roll_left_sync_mode:once() -- ACTIVATE ROLL SYNC (LEFT) MODE
		end
	end]]--
end

function B747_ap_reset_CMDhandler(phase, duration)
	print("B747_ap_reset_CMDhandler")
	if phase == 0 then
		--simCMD_autopilot_pitch_sync:once()

		B747DR_engine_TOGA_mode = 0
		B747_ap_all_cmd_modes_off() --B747_ap_reset_CMDhandler
		B747DR_ap_ias_mach_window_open = 0
	end
end

function B747_ai_ap_quick_start_CMDhandler(phase, duration)
	if phase == 0 then
		B747_set_ap_all_modes()
		B747_set_ap_CD()
		B747_set_ap_ER()
	end
end

function B747_ap_VNAV_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_vnav:once()
		B747_ap_button_switch_position_target[3] = 1
		local dist = B747BR_totalDistance - B747BR_tod
		local action = B747_afds_helpers.vnav_button_action(B747DR_ap_vnav_state, B747BR_cruiseAlt,
			dist, simDR_onGround, B747DR_ap_FMA_active_pitch_mode)
		if action == B747_afds_helpers.VNAV_BUTTON_REFUSE then
			B747DR_fmc_notifications[30] = 1
			return
		end
		if action == B747_afds_helpers.VNAV_BUTTON_DISARM then
			B747DR_ap_vnav_state = 0
			B747DR_ap_inVNAVdescent = 0
			B747DR_ap_thrust_mode = 0
			B747DR_mcp_hold=0
			if B747DR_autothrottle_active == 0 and isATEnabled() and simDR_onGround == 1 then
				--simCMD_autopilot_autothrottle_on:once()
				B747DR_autothrottle_active=1
			end
		elseif action == B747_afds_helpers.VNAV_BUTTON_ARM then
			-- On the ground or in TO/GA VNAV is only armed; VNAV_CLB engages it after
			-- takeoff. Do not write ALT HOLD here: the thrust monitor reads it as
			-- cruise and cancels TO/GA and the takeoff thrust.
			B747DR_ap_vnav_state = 1
			local reason = "VNAV armed during TOGA"
			if simDR_onGround == 1 then
				-- Clear a stale MCP altitude hold or VNAV descent, as the engage
				-- branch does; a held MCP altitude stops VNAV_CLB after takeoff.
				B747DR_mcp_hold=0
				B747DR_ap_inVNAVdescent = 0
				if B747DR_ap_FMA_active_pitch_mode~=1 then reason = "VNAV armed on the ground" end
			end
			setDescent(false)
			B747_invalidate_vnav_speed(reason)
			B747_vnav_speed()
		else
			B747DR_ap_vnav_state = 1
			simDR_autopilot_alt_hold_status = 2
			simDR_autopilot_vs_status=0
			B747DR_ap_thrust_mode = 0
			B747DR_mcp_hold=0
			B747DR_ap_inVNAVdescent = 0
			setDescent(false)
			B747_invalidate_vnav_speed("VNAV armed")
			B747_vnav_speed()
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[3] = 0
	end
end
function B747_ap_LNAV_mode_afterCMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_lnav:once();
		B747_ap_button_switch_position_target[2] = 1
		B747DR_ap_ATT = 0.0
		--simCMD_autopilot_gpss_mode:once()
		if B747DR_ap_lnav_state > 0 then
			B747DR_ap_lnav_state = 0

		else
			print("arm LNAV")
			B747DR_ap_lnav_state = 1
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[2] = 0
	end
end
function B747_ap_switch_hdg_sel_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_headsel:once()
		B747DR_ap_activate_target_heading_deg = 1
		
	end
end
--*************************************************************************************--
--** 				             CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747CMD_ap_thrust_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/thrust_mode",
	"Autopilot THR Mode",
	B747_ap_thrust_mode_CMDhandler
)
B747DR_ap_thrust_mode = deferred_dataref("laminar/B747/autopilot/thrust_mode", "number")
B747DR_ap_lastCommand = deferred_dataref("laminar/B747/autopilot/lastCommand", "number")
B747CMD_ap_switch_speed_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/speed_mode",
	"A/P Speed Mode Switch",
	B747_ap_switch_speed_mode_CMDhandler
)
B747CMD_ap_press_airspeed =
	deferred_command(
	"laminar/B747/button_switch/press_airspeed",
	"Airspeed Dial Press",
	B747_ap_switch_vnavspeed_mode_CMDhandler
)
B747CMD_ap_press_altitude =
	deferred_command(
	"laminar/B747/button_switch/press_altitude",
	"Altitude Dial Press",
	B747_ap_switch_vnavalt_mode_CMDhandler
)
B747CMD_ap_ias_mach_sel_button =
	deferred_command(
	"laminar/B747/autopilot/ias_mach/sel_button",
	"Autopilot IAS/Mach Selector Button",
	B747_ap_ias_mach_sel_button_CMDhandler
)
B747CMD_ap_switch_flch_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/flch_mode",
	"Autopilot Fl CH Mode Switch",
	B747_ap_switch_flch_mode_CMDhandler
)
B747CMD_ap_switch_vs_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/vs_mode",
	"A/P V/S Mode Switch",
	B747_ap_switch_vs_mode_CMDhandler
)
B747CMD_ap_switch_alt_hold_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/alt_hold_mode",
	"A/P Altitude Hold Mode Switch",
	B747_ap_alt_hold_mode_CMDhandler
)
B747CMD_autopilot_VNAV_mode =
	deferred_command("laminar/B747/autopilot/button_switch/VNAV", "A/P VNAV Mode Switch", B747_ap_VNAV_mode_CMDhandler)
B747CMD_autopilot_LNAV_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/LNAV",
	"A/P LNAV Mode Switch",
	B747_ap_LNAV_mode_afterCMDhandler
)
B747CMD_ap_switch_hdg_sel_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/heading_select",
	"A/P Heading Select Mode Switch",
	B747_ap_switch_hdg_sel_mode_CMDhandler
)
--B747CMD_ap_switch_hdg_hold_mode			= deferred_command("laminar/B747/autopilot/button_switch/hdg_hold_mode", "A/P Heading Hold Mode Switch", B747_ap_switch_hdg_hold_mode_CMDhandler)

B747CMD_ap_switch_cmd_L =
	deferred_command("laminar/B747/autopilot/button_switch/cmd_L", "A/P CMD L Switch", B747_ap_switch_cmd_L_CMDhandler)
B747CMD_ap_switch_cmd_C =
	deferred_command("laminar/B747/autopilot/button_switch/cmd_C", "A/P CMD C Switch", B747_ap_switch_cmd_C_CMDhandler)
B747CMD_ap_switch_cmd_R =
	deferred_command("laminar/B747/autopilot/button_switch/cmd_R", "A/P CMD R Switch", B747_ap_switch_cmd_R_CMDhandler)

B747CMD_ap_switch_disengage_bar =
	deferred_command(
	"laminar/B747/autopilot/slide_switch/disengage_bar",
	"A/P Disenage Bar",
	B747_ap_switch_disengage_bar_CMDhandler
)
B747CMD_ap_switch_yoke_disengage_capt =
	deferred_command(
	"laminar/B747/autopilot/button_switch/yoke_disengage_capt",
	"A/P Capt Yoke Disengage Switch",
	B747_ap_switch_yoke_disengage_capt_CMDhandler
)
B747CMD_ap_switch_yoke_disengage_fo =
	deferred_command(
	"laminar/B747/autopilot/button_switch/yoke_disengage_fo",
	"A/P F/O Yoke Disengage Switch",
	B747_ap_switch_yoke_disengage_fo_CMDhandler
)
B747CMD_ap_switch_autothrottle_disco_L =
	deferred_command(
	"laminar/B747/autopilot/button_switch/autothrottle_disco_L",
	"A/P Autothrottle Disco Left",
	B747_ap_switch_autothrottle_disco_L_CMDhandler
)
B747CMD_ap_switch_autothrottle_disco_R =
	deferred_command(
	"laminar/B747/autopilot/button_switch/autothrottle_disco_R",
	"A/P Autothrottle Disco Right",
	B747_ap_switch_autothrottle_disco_R_CMDhandler
)

--B747CMD_ap_att_mode =
--	deferred_command("laminar/B747/autopilot/att_mode", "Set Autopilot ATT Mode", B747_ap_att_mode_CMDhandler)
B747CMD_ap_reset =
	deferred_command("laminar/B747/autopilot/mode_reset", "Autopilot Mode Reset", B747_ap_reset_CMDhandler)

--B747CMD_reverseThrust 						= find_command("sim/engines/thrust_reverse_toggle")

-- AI
B747CMD_ai_ap_quick_start =
	deferred_command("laminar/B747/ai/autopilot_quick_start", "Autopilot Quick Start", B747_ai_ap_quick_start_CMDhandler)

--*************************************************************************************--
--** 				          REPLACE X-PLANE COMMAND HANDLERS             	    	 **--
--*************************************************************************************--
--[[local lastap_dial_airspeed = simDR_autopilot_airspeed_kts
local max_dial_machspeed = 0.95
local target_descentAlt = 0.0
local target_descentSpeed = 0.0
local descentSpeedGradient = 0.0
local switchingIASMode=0]]
function B747_updateIASWindow()
	if simDR_autopilot_airspeed_is_mach == 0 then
		B747DR_ap_ias_dial_value = math.floor(simDR_ind_airspeed_kts_pilot)
	else
		B747DR_ap_ias_dial_value = math.floor(simDR_airspeed_mach * 100)
	end
	simDR_autopilot_airspeed_kts = B747DR_lastap_dial_airspeed
	B747DR_ap_ias_mach_window_open = 1
	B747DR_switchingIASMode = 0
end
function B747_updateIAS()
	--simDR_autopilot_airspeed_kts = lastap_dial_airspeed
	B747DR_switchingIASMode = 0
end
function confirm_B747_updateIASSpeed()
	simDR_autopilot_airspeed_kts_mach = B747DR_lastap_dial_airspeed
	print("confirm set kts_mach to " .. B747DR_lastap_dial_airspeed)
end
function B747_updateIASSpeed()
	simDR_autopilot_airspeed_kts_mach = B747DR_lastap_dial_airspeed
	print("set kts_mach to " .. B747DR_lastap_dial_airspeed)
	B747DR_switchingIASMode = 0
	run_after_time(confirm_B747_updateIASSpeed, 1)
end
function B747_updateIASMaxSpeed()
	B747DR_max_dial_machspeed = simDR_autopilot_airspeed_kts_mach
	print("set max kts_mach to " .. B747DR_max_dial_machspeed)
	B747DR_switchingIASMode = 0
end
-- After a knots/Mach swap, write the X-Plane autopilot target in the new unit
-- in the same call: the knots target, or that target as a Mach number at the
-- current altitude (limited to Mmo - 0.01). B747_ap_ias_mach_mode only writes
-- it after the 0.25 s B747_updateIASWindow, and until then X-Plane read the
-- old value in the new unit (325 kt as a Mach number, M.825 as knots).
-- The callers pass the speed and unit they have just written rather than
-- reading those datarefs back in the same frame.
function B747_ap_set_speed_target_in_unit(target_kts, is_mach)
	if is_mach == 1 then
		local mach = B747_afds_helpers.cas_to_mach(target_kts, simDR_pressureAlt1)
		if mach ~= nil then
			simDR_autopilot_airspeed_kts_mach = B747_afds_helpers.limited_mach_target(mach, B747DR_airspeed_Mms)
		end
	else
		simDR_autopilot_airspeed_kts_mach = target_kts
	end
end
function B747_ap_knots_mach_toggle_CMDhandler(phase, duration)
	if phase == 0 then
		B747_ap_button_switch_position_target[13] = 1
		if B747DR_ap_ias_mach_window_open == 1 then
			if simDR_airspeed_mach > 0.4 then
				local target = simDR_autopilot_airspeed_kts -- READ THE CURRENT AIRSPEED SETTING
				local is_mach = 1 - simDR_autopilot_airspeed_is_mach
				B747DR_lastap_dial_airspeed = target
				simDR_autopilot_airspeed_is_mach = is_mach -- SWAP THE MACH/KNOTS STATE
				B747_ap_set_speed_target_in_unit(target, is_mach)
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			elseif simDR_airspeed_mach <= 0.4 and simDR_autopilot_airspeed_is_mach == 1 then
				local target = simDR_autopilot_airspeed_kts -- READ THE CURRENT AIRSPEED SETTING
				B747DR_lastap_dial_airspeed = target
				simDR_autopilot_airspeed_is_mach = 0 -- SWAP THE MACH/KNOTS STATE
				B747_ap_set_speed_target_in_unit(target, 0)
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			end
		end
	elseif phase == 2 then
		B747_ap_button_switch_position_target[13] = 0
	end
end

function B747_ap_airspeed_up_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_ap_ias_mach_window_open == 1 then
			if simDR_autopilot_airspeed_is_mach == 0 then
				--simDR_autopilot_airspeed_kts = math.min(399.0, simDR_autopilot_airspeed_kts + 1)
				B747DR_ap_ias_dial_value = math.floor(math.min(399.0, B747DR_ap_ias_dial_value + 1))
			elseif simDR_autopilot_airspeed_is_mach == 1 then
				--simDR_autopilot_airspeed_kts_mach = math.min(0.950, simDR_autopilot_airspeed_kts_mach + 0.01)
				B747DR_ap_ias_dial_value = math.floor(math.min(95.0, B747DR_ap_ias_dial_value + 1))
			end
		end
	elseif phase == 1 then
		if duration > 0.5 then
			if B747DR_ap_ias_mach_window_open == 1 then
				if simDR_autopilot_airspeed_is_mach == 0 then
					--simDR_autopilot_airspeed_kts = math.min(399.0, simDR_autopilot_airspeed_kts + 1)
					B747DR_ap_ias_dial_value = math.floor(math.min(399.0, B747DR_ap_ias_dial_value + 1))
				elseif simDR_autopilot_airspeed_is_mach == 1 then
					B747DR_ap_ias_dial_value = math.floor(math.min(95.0, B747DR_ap_ias_dial_value + 1))
				--simDR_autopilot_airspeed_kts_mach = math.min(0.950, simDR_autopilot_airspeed_kts_mach + 0.01)
				end
			end
		end
	end
end

function B747_ap_airspeed_down_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_ap_ias_mach_window_open == 1 then
			if simDR_autopilot_airspeed_is_mach == 0 then
				--simDR_autopilot_airspeed_kts = math.max(100.0, simDR_autopilot_airspeed_kts - 1)
				B747DR_ap_ias_dial_value = math.floor(math.max(100.0, B747DR_ap_ias_dial_value - 1))
			elseif simDR_autopilot_airspeed_is_mach == 1 then
				--simDR_autopilot_airspeed_kts_mach = math.max(0.400, simDR_autopilot_airspeed_kts_mach - 0.01)
				B747DR_ap_ias_dial_value = math.floor(math.max(40.0, B747DR_ap_ias_dial_value - 1))
			end
		end
	elseif phase == 1 then
		if duration > 0.5 then
			if B747DR_ap_ias_mach_window_open == 1 then
				if simDR_autopilot_airspeed_is_mach == 0 then
					--simDR_autopilot_airspeed_kts = math.max(100.0, simDR_autopilot_airspeed_kts - 1)
					B747DR_ap_ias_dial_value = math.floor(math.max(100.0, B747DR_ap_ias_dial_value - 1))
				elseif simDR_autopilot_airspeed_is_mach == 1 then
					B747DR_ap_ias_dial_value = math.floor(math.max(40.0, B747DR_ap_ias_dial_value - 1))
				--simDR_autopilot_airspeed_kts_mach = math.max(0.400, simDR_autopilot_airspeed_kts_mach - 0.01)
				end
			end
		end
	end
end

function B747_ap_heading_up_CMDhandler(phase, duration)
	if phase == 0 then
		--if B747DR_ap_hdg_sel_mode == 1 then simDR_autopilot_heading_deg = B747DR_ap_heading_deg end
		--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg + 1), 360.0)	)
		B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg + 1), 360.0))
		if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state == 2) then
			simDR_autopilot_heading_deg = B747DR_ap_heading_deg
		end
	elseif phase == 1 then
		if duration > 0.5 then
			--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg + 1), 360.0)	)
			B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg + 1), 360.0))
			if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state == 2) then
				simDR_autopilot_heading_deg = B747DR_ap_heading_deg
			end
		--if B747DR_ap_hdg_sel_mode == 1 then simDR_autopilot_heading_deg = B747DR_ap_heading_deg end
		end
	end
end

function B747_ap_heading_down_CMDhandler(phase, duration)
	if phase == 0 then
		--if B747DR_ap_hdg_sel_mode == 1 then simDR_autopilot_heading_deg = B747DR_ap_heading_deg end
		--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg - 1), 360.0)	)
		--if simDR_autopilot_heading_deg < 0.0 then simDR_autopilot_heading_deg = simDR_autopilot_heading_deg + 360.0 end
		B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg - 1), 360.0))
		if B747DR_ap_heading_deg < 0.0 then
			B747DR_ap_heading_deg = B747DR_ap_heading_deg + 360.0
		end
		if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state == 2) then
			simDR_autopilot_heading_deg = B747DR_ap_heading_deg
		end
	elseif phase == 1 then
		if duration > 0.5 then
			--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg - 1), 360.0)	)
			--if simDR_autopilot_heading_deg < 0.0 then simDR_autopilot_heading_deg = simDR_autopilot_heading_deg + 360.0 end
			B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg - 1), 360.0))
			if B747DR_ap_heading_deg < 0.0 then
				B747DR_ap_heading_deg = B747DR_ap_heading_deg + 360.0
			end
			if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state == 2) then
				simDR_autopilot_heading_deg = B747DR_ap_heading_deg
			end
		--if B747DR_ap_hdg_sel_mode == 1 then simDR_autopilot_heading_deg = B747DR_ap_heading_deg end
		end
	end
end

function B747_ap_bank_limit_up_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_ap_bank_limit_sel_dial_pos = math.min(B747DR_ap_bank_limit_sel_dial_pos + 1, 5)
		if B747DR_ap_bank_limit_sel_dial_pos == 0 then
			simDR_autopilot_bank_limit = 4
		else
			simDR_autopilot_bank_limit = B747DR_ap_bank_limit_sel_dial_pos
		end
	end
end

function B747_ap_bank_limit_down_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_ap_bank_limit_sel_dial_pos = math.max(B747DR_ap_bank_limit_sel_dial_pos - 1, 0)
		if B747DR_ap_bank_limit_sel_dial_pos == 0 then
			simDR_autopilot_bank_limit = 4
		else
			simDR_autopilot_bank_limit = B747DR_ap_bank_limit_sel_dial_pos
		end
	end
end

function B747_ap_vertical_speed_up_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_ap_vs_window_open == 1 then
			simDR_autopilot_vs_fpm = math.min(6000.0, simDR_autopilot_vs_fpm + 100.0)
			B747DR_autopilot_vs_fpm = simDR_autopilot_vs_fpm
		end
		if B747DR_autopilot_vs_fpm > 0 then
			B747DR_ap_flightPhase = 1
		else
			B747DR_ap_flightPhase = 3
		end
	elseif phase == 1 then
		if duration > 0.5 then
			if B747DR_ap_vs_window_open == 1 then
				simDR_autopilot_vs_fpm = math.min(6000.0, simDR_autopilot_vs_fpm + 100.0)
				B747DR_autopilot_vs_fpm = simDR_autopilot_vs_fpm
			end
		end
	end
end
function B747_ap_vertical_speed_down_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_ap_vs_window_open == 1 then
			simDR_autopilot_vs_fpm = math.max(-8000.0, simDR_autopilot_vs_fpm - 100.0)
			B747DR_autopilot_vs_fpm = simDR_autopilot_vs_fpm

			if B747DR_autopilot_vs_fpm > 0 then
				B747DR_ap_flightPhase = 1
			else
				B747DR_ap_flightPhase = 3
			end
		end
	elseif phase == 1 then
		if duration > 0.5 then
			if B747DR_ap_vs_window_open == 1 then
				simDR_autopilot_vs_fpm = math.max(-8000.0, simDR_autopilot_vs_fpm - 100.0)
				B747DR_autopilot_vs_fpm = simDR_autopilot_vs_fpm
			end
		end
	end
end

-- [B-12] The MCP altitude knob freezes nothing. It wrote B747DR_ap_lastCommand 1 s ahead at each click (and every frame
-- held), and everything waiting 0.5 s on it stopped for the whole dial and 1.5 s after it: VNAV's mode switching, its
-- descent V/S target and the start of the descent at T/D, the A/T modes, LOC and G/S capture, the roll FMA, APP
-- arming, AFDS status (the kit's 37000 -> 2000 ft before T/D: 28 s at 0.079 s a click). A real 747-400 uses the
-- selection at once. Unfrozen, VNAV's altitude legs took each passing value as a level-off (a stop climb at FL200 from
-- 23,000 levelled 100-400 ft high in 23 of 30 model runs), so VNAV now takes the MCP altitude as one only once it has
-- been still for MCP_ALT_SETTLE_SEC (B747_mcp_alt_settled; B747_mcp_alt_dial_time is the last click).
-- Outside VNAV the AFDS altitude takes the MCP once it has settled (was 3 s, which left a stale altitude to capture:
-- V/S at 10,150 ft towards 11,000 cleared to 10,000 levelled at 11,000), and at once when a click takes it farther from
-- the aircraft on the same side (it cannot make a capture and drops a stale one); in VNAV it is VNAV's to set.
function setSimAlt()
	if B747DR_ap_vnav_state<2 then
		simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
		print("set sim alt")
	end
end
MCP_ALT_SETTLE_SEC=1.5
B747_mcp_alt_dial_time=-100
function B747_mcp_alt_settled()
	return simDRTime-B747_mcp_alt_dial_time>=MCP_ALT_SETTLE_SEC
end
local function B747_mcp_alt_dialled()
	B747_mcp_alt_dial_time=simDRTime
	if B747DR_ap_vnav_state<2 then
		local old=simDR_autopilot_altitude_ft-simDR_pressureAlt1
		local new=B747DR_autopilot_altitude_ft-simDR_pressureAlt1
		if old*new>0 and math.abs(new)>math.abs(old) then simDR_autopilot_altitude_ft=B747DR_autopilot_altitude_ft end
	end
	if is_timer_scheduled(setSimAlt) then
		stop_timer(setSimAlt)
	end
	run_after_time(setSimAlt, MCP_ALT_SETTLE_SEC)
end

function B747_ap_altitude_up_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_autopilot_altitude_ft = math.min(50000.0, B747DR_autopilot_altitude_ft + 100)
		B747_mcp_alt_dialled()
	elseif phase == 1 then
		if duration > 0.5 then
			B747DR_autopilot_altitude_ft = math.min(50000.0, B747DR_autopilot_altitude_ft + 100)
			B747_mcp_alt_dialled()
		end
	end
end

function B747_ap_altitude_down_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_autopilot_altitude_ft = math.max(0.0, B747DR_autopilot_altitude_ft - 100)
		B747_mcp_alt_dialled()
	elseif phase == 1 then
		if duration > 0.5 then
			B747DR_autopilot_altitude_ft = math.max(0.0, B747DR_autopilot_altitude_ft - 100)
			B747_mcp_alt_dialled()
		end
	end
end
--[[function B747CMD_ap_heading_up_CMDhandler(phase, duration)
end
function B747CMD_ap_heading_down_CMDhandler(phase, duration)
end]]--

--*************************************************************************************--
--** 				            REPLACE X-PLANE COMMANDS                  	    	 **--
--*************************************************************************************--

simCMD_ap_knots_mach_toggle = replace_command("sim/autopilot/knots_mach_toggle", B747_ap_knots_mach_toggle_CMDhandler)

simCMD_ap_airspeed_up = replace_command("sim/autopilot/airspeed_up", B747_ap_airspeed_up_CMDhandler)
simCMD_ap_airspeed_down = replace_command("sim/autopilot/airspeed_down", B747_ap_airspeed_down_CMDhandler)
simCMD_ap_heading_up = replace_command("sim/autopilot/heading_up", B747_ap_heading_up_CMDhandler)
simCMD_ap_heading_down = replace_command("sim/autopilot/heading_down", B747_ap_heading_down_CMDhandler)
simCMD_ap_bank_limit_up = replace_command("sim/autopilot/bank_limit_up", B747_ap_bank_limit_up_CMDhandler)
simCMD_ap_bank_limit_down = replace_command("sim/autopilot/bank_limit_down", B747_ap_bank_limit_down_CMDhandler)
simCMD_ap_vertical_speed_up = replace_command("sim/autopilot/vertical_speed_up", B747_ap_vertical_speed_up_CMDhandler)
simCMD_ap_vertical_speed_down =
	replace_command("sim/autopilot/vertical_speed_down", B747_ap_vertical_speed_down_CMDhandler)
simCMD_ap_altitude_up = replace_command("sim/autopilot/altitude_up", B747_ap_altitude_up_CMDhandler)
simCMD_ap_altitude_down = replace_command("sim/autopilot/altitude_down", B747_ap_altitude_down_CMDhandler)
--B747CMD_ap_heading_up = replace_command("laminar/B747/autopilot/heading_up", B747CMD_ap_heading_up_CMDhandler)
--B747CMD_ap_heading_down = replace_command("laminar/B747/autopilot/heading_down", B747CMD_ap_heading_down_CMDhandler)

--*************************************************************************************--
--** 				          WRAP X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************-

----- ROUND TO INCREMENT ----------------------------------------------------------------
function roundToIncrement(numberToRound, increment)
	local y = numberToRound / increment
	local q = math.floor(y + 0.5)
	local z = q * increment

	return z
end

function B747_ap_heading_hold_mode_beforeCMDhandler(phase, duration)
	--[[print("heading hold "..simDR_AHARS_heading_deg_pilot)

  --B747DR_ap_heading_deg=roundToIncrement(simDR_AHARS_heading_deg_pilot, 1) unused?
  if simDR_autopilot_heading_hold_status ==0 then
    simDR_autopilot_heading_deg=roundToIncrement(simDR_AHARS_heading_deg_pilot, 1)
  end]]
end
function B747_ap_heading_hold_mode_afterCMDhandler(phase, duration)
	--print("heading hold2"..simDR_AHARS_heading_deg_pilot)
	B747DR_ap_lnav_state = 0
	if phase == 0 then
		B747CMD_fdr_log_headhold:once()
		B747DR_ap_ATT = 0.0
		B747_ap_clear_toga_roll() -- HDG HOLD replaces TO/GA roll in flight
		B747_ap_button_switch_position_target[5] = 1
	elseif phase == 2 then
		B747_ap_button_switch_position_target[5] = 0
	end
end

dofile("json/json.lua")
simDR_variation = find_dataref("sim/flightmodel/position/magnetic_variation")
simDR_nav1Freq = find_dataref("sim/cockpit/radios/nav1_freq_hz")
simDR_nav2Freq = find_dataref("sim/cockpit/radios/nav2_freq_hz")
--simDR_nav1crs=find_dataref("sim/cockpit/radios/nav1_course_degm")
--simDR_nav2crs=find_dataref("sim/cockpit/radios/nav2_course_degm")
simDR_radio_nav_obs_deg = find_dataref("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot")
simDR_radio_nav1_obs_deg = find_dataref("sim/cockpit/radios/nav1_obs_degt")
simDR_radio_nav2_obs_deg = find_dataref("sim/cockpit/radios/nav2_obs_degt")
simDR_radio_nav1_bearing_deg = find_dataref("sim/cockpit2/radios/indicators/nav1_bearing_deg_mag")
simDR_radio_nav2_bearing_deg = find_dataref("sim/cockpit2/radios/indicators/nav2_bearing_deg_mag")

navAidsJSON = find_dataref("xtlua/navaids")
fmsJSON = find_dataref("xtlua/fms")
nSize = 0
local navAids = {}
targetILS = find_dataref("laminar/B747/radio/ilsData")
local targetILSS = ""
local targetFMS = ""
local targetFMSnum = -1
targetFix = 0
bestDiff = 180
function getHeading(lat1, lon1, lat2, lon2)
	b10 = math.rad(lat1)
	b11 = math.rad(lon1)
	b12 = math.rad(lat2)
	b13 = math.rad(lon2)
	retVal =
		math.atan2(
		math.sin(b13 - b11) * math.cos(b12),
		math.cos(b10) * math.sin(b12) - math.sin(b10) * math.cos(b12) * math.cos(b13 - b11)
	)
	return math.deg(retVal)
end
function getHeadingDifference(desireddirection, current_heading)
	error = current_heading - desireddirection
	if (error > 180) then
		error = error - 360
	end
	if (error < -180) then
		error = error + 360
	end
	return error
end

function getDistance(lat1, lon1, lat2, lon2)
	if lat1 == lat2 and lon1 == lon2 then
		return 0
	end
	alat = math.rad(lat1)
	alon = math.rad(lon1)
	blat = math.rad(lat2)
	blon = math.rad(lon2)
	av = math.sin(alat) * math.sin(blat) + math.cos(alat) * math.cos(blat) * math.cos(blon - alon)
	if av > 1 then
		av = 1
	end
	retVal = math.acos(av) * 3440
	return retVal
end

function movePoint(lat1,lon1,distanceInNM,bearing)
	local brngRad = math.rad(bearing)
	local latRad = math.rad(lat1)
	local lonRad = math.rad(lon1)
	local distFrac = distanceInNM / 3440;
	local latitudeResult = math.asin(math.sin(latRad) * math.cos(distFrac) + math.cos(latRad) * math.sin(distFrac) * math.cos(brngRad))
	local a = math.atan2(math.sin(brngRad) * math.sin(distFrac) * math.cos(latRad), math.cos(distFrac) - math.sin(latRad) * math.sin(latitudeResult))
	local longitudeResult = (lonRad + a + 3 * math.pi) % (2 * math.pi) - math.pi;
	lat2 = math.deg(latitudeResult)
    lon2 = math.deg(longitudeResult)

    return lat2, lon2							   
end

local lastILSUpdate = 0
original_distance = -1
function round(x)
	return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end
function int(x)
	return x >= 0 and math.floor(x) or math.ceil(x)
end
function B747_fltmgmt_setILS(fmsO)
	local modes = B747DR_radioModes
	local targetDots=0
	--print("B747_fltmgmt_setILS")
	if modes:sub(1, 1) == " " then
		targetFMSnum = -1
		B747DR_radioModes = replace_char(1, modes, "A")
	elseif modes:sub(1, 1) == "M" then
		--local fms=json.decode(fmsSTR)

		setDistances(fmsO)
		--print("Dist B747DR_ils_dots = "..B747DR_ils_dots)
		--print("Dist targetILSS = "..targetILS)
		--print("Dist B747BR_distance_to_dest = "..B747BR_distance_to_dest)
		if B747DR_ils_dots==0 and ((B747BR_totalDistance>0 and B747BR_totalDistance< 50) or (B747BR_distance_to_dest>=0 and B747BR_distance_to_dest<50)) then
			if string.len(targetILS) > 2 then
				B747DR_ils_dots=1
				--print("do Dist B747DR_ils_dots = "..B747DR_ils_dots)
			end
		end
		return
	end
	local diff = simDRTime - lastILSUpdate
	if diff < 2 then
		return
	end
	--collectgarbage("collect")
	lastILSUpdate = simDRTime
	local n1 = simDR_nav1Freq
	local n2 = simDR_nav2Freq
	local d1 = simDR_radio_nav1_obs_deg
	local d2 = simDR_radio_nav2_obs_deg
	 --continually get latest
	local d1 = simDR_radio_nav_obs_deg[0]
	local d2 = simDR_radio_nav_obs_deg[1]
	 --continually get latest
	--print("fmsJSON=".. fmsSTR)


	setDistances(fmsO)

	local newTargetFix = 0
	local hitI = -1
	--print(navAidsJSON)
	if table.getn(fmsO) > 4 and (fmsO[targetFMSnum] == nil or targetFMS ~= fmsO[targetFMSnum][8]) then
		if string.len(navAidsJSON) ~= nSize then
			navAids = json.decode(navAidsJSON)
			nSize = string.len(navAidsJSON)
		end
		if fmsO[table.getn(fmsO)][2] == 1 then
			--we have an airport as our dst
			local apdistance = getDistance(simDR_latitude, simDR_longitude, fmsO[table.getn(fmsO)][5], fmsO[table.getn(fmsO)][6])
			if apdistance > 45 then
				return
			end

			--Marauder28
			if original_distance == -1 then
				original_distance = B747BR_totalDistance --capture original flightplan distance
			end
			local pct_remaining = 100 - (((original_distance - B747BR_totalDistance) / original_distance) * 100)
			local dist_to_TOD = B747BR_totalDistance - B747BR_tod
			--print("Orig Dist = "..original_distance)
			--print("Dist Remain = "..B747BR_totalDistance)
			--if dist_to_TOD > 0 then print("Dist TOD = "..dist_to_TOD) end
			--print("Pct Remain = "..pct_remaining)
			--if (apdistance>=200) or (pct_remaining > 50) then
			--if dist_to_TOD >= 200 then --or pct_remaining > 50 then
			--return    --more than 200nm away from TOD or less than half-way to DEST (used in NAV RAD auto-tune scenario #2)
			--end
			--Marauder28

			found = false
			local runwayHeading = -999
			for i = table.getn(fmsO) - 1, 2, -1 do --last is the airport, before that go-around [may] be dup
				--we have a fix coming in to the airport
				--if fms[i][2] == 512 then
				local ap1Heading = getHeading(fmsO[i][5], fmsO[i][6], fmsO[table.getn(fmsO)][5], fmsO[table.getn(fmsO)][6])
				local ap2Heading = getHeading(fmsO[i - 1][5], fmsO[i - 1][6], fmsO[table.getn(fmsO)][5], fmsO[table.getn(fmsO)][6])
				local diffap = getHeadingDifference(ap1Heading, ap2Heading)
				local distance = getDistance(fmsO[i][5], fmsO[i][6], fmsO[table.getn(fmsO)][5], fmsO[table.getn(fmsO)][6])
				print("finding ils FMS i=" .. i .. ":" .. ap1Heading .. ":" .. ap2Heading .. ":" .. diffap .. ":" .. distance.. ":" .. fmsO[i][8].. ":" .. fmsO[i - 1][8] )
				if diffap < 10 and diffap > -10 and distance < 11 then
					print("potential matched from" .. i)
					for n = table.getn(navAids), 1, -1 do
						--now find an ils

						if navAids[n][2] == 8 then
							local headingToILS = getHeading(fmsO[i][5], fmsO[i][6], navAids[n][5], navAids[n][6])
							local headingToNext = getHeading(fmsO[i][5], fmsO[i][6], fmsO[i + 1][5], fmsO[i + 1][6])
							local diff = getHeadingDifference(navAids[n][4], headingToILS)
							local diff2 = getHeadingDifference(headingToILS, headingToNext)
							if diff < 0 then
								diff = diff * -1
							end

							if diff2 < 5 and diff2 > -5 then
								local distance2 = getDistance(fmsO[table.getn(fmsO)][5], fmsO[table.getn(fmsO)][6], navAids[n][5], navAids[n][6])
								if diff < 1 and diff <= bestDiff and distance2 < 10 then
									--print("navaid "..n.."->"..fms[i][8].."="..diff.." ".. navAids[n][1].." ".. navAids[n][2].." ".. navAids[n][3].." ".. navAids[n][4].." ".. navAids[n][5].." ".. navAids[n][6].." ".. navAids[n][7].." ".. navAids[n][8])
									bestDiff = diff
									runwayHeading = headingToNext
									print("bestdiff = " .. bestDiff .. " on heading " .. headingToILS .. " course=" .. headingToNext)
									--if targetFix == newTargetFix then
									found = true
									newTargetFix = n
									print("newTargetFix = " .. newTargetFix)
									hitI = i
								end
							end
						end
					end
				end
			end
			targetFix = newTargetFix
			-- if found==false then
			bestDiff = 180

			--else
			if targetFix ~= 0 then
				--print("set targetILS")
				--navAids[targetFix][4]=runwayHeading
				targetILSS = json.encode(navAids[targetFix])
				targetFMS = fmsO[hitI][8]
				targetFMSnum = hitI
				targetILS = targetILSS
				print("Tune ILS" .. targetILSS)

				if string.len(targetILSS) > 0 then
					print("Tuning ILS" .. targetILSS)
					local ilsNav = json.decode(targetILSS)
					simDR_nav1Freq = ilsNav[3]
					simDR_nav2Freq = ilsNav[3]
					local course = (ilsNav[4] + int(simDR_variation))
					if course < 0 then
						course = course + 360
					end
					simDR_radio_nav_obs_deg[0] = course
					simDR_radio_nav_obs_deg[1] = course
					print("Tuned ILS " .. course)
					targetDots = 1 -- make PFD loc and GS dots visible
				end
			elseif B747DR_ap_FMA_active_roll_mode ~= 3 then
				--print("cleared targetILS")
				targetILS = " "
				targetILSS = " "
			end
		end
	elseif string.len(targetILSS) > 1 and string.len(targetILS) > 2 then
		--print("Tuned ILS "..course)
		--print("Tuning ILS".. targetILSS)
		local ilsNav = json.decode(targetILSS)
		simDR_nav1Freq = ilsNav[3]
		simDR_nav2Freq = ilsNav[3]
		local course = (ilsNav[4] + simDR_variation)
		if course < 0 then
			course = course + 360
		elseif course > 360 then
			course = course - 360
		end
		--course=round(course)
		simDR_radio_nav_obs_deg[0] = course
		simDR_radio_nav_obs_deg[1] = course
		targetDots = 1 -- make PFD loc and GS dots visible
	else
		if B747DR_ap_FMA_active_roll_mode == 3 then
			targetDots = 1 -- make PFD loc and GS dots visible
		elseif string.len(targetILS) < 2 and B747DR_ap_FMA_active_roll_mode ~= 3 then
			targetDots = 0
		end
	end
	local tDots=B747DR_ils_dots
	if (B747BR_totalDistance>0 and B747BR_totalDistance< 50) or (B747BR_distance_to_dest>=0 and B747BR_distance_to_dest<50) then
		B747DR_ils_dots=targetDots
	else
		B747DR_ils_dots=0
	end
	--print("target="..targetILS.."= "..targetILSS.."= "..targetFix.. " "..nSize.. " "..table.getn(navAids))
	--[[for i=table.getn(fms)-1,1,-1 do
    if fms[i][10]==true then
      print("fms"..i.."=".. fms[i][1].." "..fms[i][2].." "..fms[i][3].." "..fms[i][4].." "..fms[i][5].." "..fms[i][6].." "..fms[i][7].." "..fms[i][8].." "..fms[i][9].." active")
    else
      print("fms"..i.."=".. fms[i][1].." "..fms[i][2].." "..fms[i][3].." "..fms[i][4].." "..fms[i][5].." "..fms[i][6].." "..fms[i][7].." "..fms[i][8].." "..fms[i][9].." inactive")
    end
  end]]
end

--*************************************************************************************--
--** 				              WRAP X-PLANE COMMANDS                  	    	 **--
--*************************************************************************************--
simCMD_autopilot_gpss_mode = find_command("sim/autopilot/gpss")

simCMD_autopilot_FMS_mode = find_command("sim/autopilot/FMS")
simCMD_autopilot_heading_hold_mode =
	wrap_command(
	"sim/autopilot/heading_hold",
	B747_ap_heading_hold_mode_beforeCMDhandler,
	B747_ap_heading_hold_mode_afterCMDhandler
)
simCMD_autopilot_appr_mode = find_command("sim/autopilot/approach")

--*************************************************************************************--
--** 					           OBJECT CONSTRUCTORS         	    	    		 **--
--*************************************************************************************--

--*************************************************************************************--
--** 				                 CREATE OBJECTS        	         				 **--
--*************************************************************************************--

--*************************************************************************************--
--** 				                SYSTEM FUNCTIONS             	    			 **--
--*************************************************************************************--

----- TERNARY CONDITIONAL ---------------------------------------------------------------
function B747_ternary(condition, ifTrue, ifFalse)
	if condition then
		return ifTrue
	else
		return ifFalse
	end
end

----- ANIMATION UNILITY -----------------------------------------------------------------
function B747_set_ap_animation_position(current_value, target, min, max, speed)
	if target >= (max - 0.001) and current_value >= (max - 0.01) then
		return max
	elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
		return min
	else
		return current_value + ((target - current_value) * (speed * SIM_PERIOD))
	end
end

---- BUTTON SWITCH POSITION ANIMATION ---------------------------------------------------
function B747_ap_button_switch_animation()
	for i = 0, NUM_AUTOPILOT_BUTTONS - 1 do
		B747DR_ap_button_switch_position[i] =
			B747_set_ap_animation_position(
			B747DR_ap_button_switch_position[i],
			B747_ap_button_switch_position_target[i],
			0.0,
			1.0,
			30.0
		)
	end
end

----- VERTICAL SPEED MODE ---------------------------------------------------------------
function B747_ap_vs_mode()
	----- WINDOW
	B747DR_ap_vs_window_open = B747_ternary(simDR_autopilot_vs_status >= 1 and B747DR_ap_vnav_state < 2 and simDR_autopilot_alt_hold_status<2 and B747DR_autopilot_gs_status < 2, 1, 0)

	----- VVI FOR ANIMATION

	B747DR_ap_vvi_fpm = math.abs(simDR_autopilot_vs_fpm)

	----- THOUSANDS DIGIT HIDE/SHOW
	B747DR_ap_vs_show_thousands = B747_ternary(B747DR_ap_vs_window_open == 1 and B747DR_ap_vvi_fpm >= 1000, 1, 0)
end

----- IAS/MACH MODE ---------------------------------------------------------------------
function B747_ap_ias_mach_mode()
	if B747DR_ap_autoland < 0 and (simDR_radarAlt1 > 1500) then
		B747DR_ap_autoland = 0
		print("IAS end Go Around")
	end
	----- SET THE IAS/MACH WINDOW STATUS
	if B747DR_switchingIASMode == 0 and (B747DR_ap_vnav_state < 2 or getVNAVState("manualVNAVspd") == 1) then --inop until we know speed!
		B747DR_ap_ias_mach_window_open = 1
	else
		B747DR_ap_ias_mach_window_open = 0
	end
	local ap_dial_airspeed = simDR_autopilot_airspeed_kts -- READ THE CURRENT AIRSPEED SETTING
	local ap_simDR_autopilot_airspeed_is_mach = simDR_autopilot_airspeed_is_mach -- READ THE CURRENT mach SETTING

	----- AUTO-SWITCH AUTOPILOT IAS/MACH WINDOW AIRSPEED MODE
	if simDR_airspeed_mach < 0.40 and B747DR_switchingIASMode == 0 and B747DR_ap_vnav_state == 0 then
		if simDR_vvi_fpm_pilot < -250.0 then
			if ap_simDR_autopilot_airspeed_is_mach == 1 then
				--simDR_autopilot_airspeed_kts = ap_dial_airspeed								-- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				local target = simDR_autopilot_airspeed_kts
				B747DR_lastap_dial_airspeed = target
				simDR_autopilot_airspeed_is_mach = 0 -- CHANGE TO KNOTS
				B747_ap_set_speed_target_in_unit(target, 0)
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				print("AUTO-SWITCH AUTOPILOT IAS/MACH WINDOW AIRSPEED MODE")
				run_after_time(B747_updateIASWindow, 0.25) --update target
			end
		end
	end
    --D6-30151-481 4.10.4/5
	if simDR_airspeed_mach > 0.84 and B747DR_switchingIASMode == 0 and B747DR_ap_vnav_state == 0 then
		if simDR_vvi_fpm_pilot > 250.0 then
			if ap_simDR_autopilot_airspeed_is_mach == 0 then
				local target = simDR_autopilot_airspeed_kts
				B747DR_lastap_dial_airspeed = target
				--simDR_autopilot_airspeed_kts = ap_dial_airspeed								-- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				simDR_autopilot_airspeed_is_mach = 1 -- CHANGE TO KNOTS
				B747_ap_set_speed_target_in_unit(target, 1)
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			end
		end
	end
	if simDR_autopilot_airspeed_kts > 310 and B747DR_switchingIASMode == 0 and B747DR_ap_vnav_state == 0 then
		if simDR_vvi_fpm_pilot < -250.0 then
			if ap_simDR_autopilot_airspeed_is_mach == 1 then
				local target = simDR_autopilot_airspeed_kts
				B747DR_lastap_dial_airspeed = target
				--simDR_autopilot_airspeed_kts = ap_dial_airspeed								-- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				simDR_autopilot_airspeed_is_mach = 0 -- CHANGE TO KNOTS
				B747_ap_set_speed_target_in_unit(target, 0)
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			end
		end
	end
	----- SET THE IAS/MACH TUMBLER VALUE
	if B747DR_ap_ias_mach_window_open == 1 and simDR_autopilot_airspeed_is_mach == 1 then
		B747DR_ap_mach_decimal_visibiilty = 1
	else
		B747DR_ap_mach_decimal_visibiilty = 0
	end

	local minSafeSpeed = B747DR_airspeed_Vmc + 10
	local maxSafeSpeed = B747DR_airspeed_Vmo

	if simDR_flap_ratio_control > 0 then
		if simDR_flap_ratio_control <= 0.168 then --flaps 1
			maxSafeSpeed =275
		elseif simDR_flap_ratio_control <= 0.34 then --flaps 5
			maxSafeSpeed = 255
		elseif simDR_flap_ratio_control <= 0.5 then --flaps 10
			maxSafeSpeed = 235
			minSafeSpeed = minSafeSpeed - 5
		elseif simDR_flap_ratio_control <= 0.668 then --flaps 20
			maxSafeSpeed = 225
			minSafeSpeed = minSafeSpeed - 5
		elseif simDR_flap_ratio_control <= 0.84 then --flaps 25
			maxSafeSpeed = 200
			minSafeSpeed = minSafeSpeed - 9
		elseif simDR_flap_ratio_control <= 1.0 then --flaps 30
			maxSafeSpeed = 175
			minSafeSpeed = minSafeSpeed - 9
		end
	end
	local maxmach = B747DR_airspeed_Mms

	if B747DR_switchingIASMode == 0 then
		if simDR_autopilot_airspeed_is_mach == 0 then
			B747DR_ap_ias_bug_value = B747DR_ap_ias_dial_value
			if B747DR_ap_ias_dial_value < minSafeSpeed then
				simDR_autopilot_airspeed_kts = minSafeSpeed
			else
				simDR_autopilot_airspeed_kts = math.min(B747DR_ap_ias_dial_value, maxSafeSpeed)
			end
		elseif simDR_autopilot_airspeed_is_mach == 1 and B747DR_ap_ias_dial_value * 0.01 > 0.4 then
			B747DR_ap_ias_mach_dial_value = B747DR_ap_ias_dial_value * 0.01

			if simDR_autopilot_airspeed_kts >= maxSafeSpeed - 10 then
				if simDR_autopilot_airspeed_kts < maxSafeSpeed then
					B747DR_ap_ias_bug_value = maxSafeSpeed - 10 --simDR_autopilot_airspeed_kts
				end

				if
					simDR_autopilot_flch_status == 0 and B747DR_ap_inVNAVdescent == 0 and
						simDR_autopilot_airspeed_kts > maxSafeSpeed - 10
				 then
					simDR_autopilot_airspeed_kts = maxSafeSpeed - 10
					setFMSData("maxkts", simDR_autopilot_airspeed_kts)
				elseif simDR_autopilot_airspeed_kts > maxSafeSpeed - 20 then
					simDR_autopilot_airspeed_kts = maxSafeSpeed - 20 --flch/descent overspeed
					setFMSData("maxkts", simDR_autopilot_airspeed_kts)
				end
			else
				B747DR_ap_ias_bug_value = simDR_autopilot_airspeed_kts
				simDR_autopilot_airspeed_kts_mach = math.min(B747DR_ap_ias_dial_value * 0.01, maxmach - 0.01) ---roundToIncrement(B747DR_ap_ias_dial_value, 1) * 0.01
			end
		end
	end
	if simDR_ind_airspeed_kts_pilot < B747DR_ap_ias_bug_value then
		if B747DR_ap_ias_bug_value - simDR_ind_airspeed_kts_pilot > 60 then
			B747DR_ap_ias_bug_value_pfd = simDR_ind_airspeed_kts_pilot + 60
		else
			B747DR_ap_ias_bug_value_pfd = B747DR_ap_ias_bug_value
		end
	else
		if simDR_ind_airspeed_kts_pilot - B747DR_ap_ias_bug_value > 57.5 then
			B747DR_ap_ias_bug_value_pfd = simDR_ind_airspeed_kts_pilot - 57.5
		else
			B747DR_ap_ias_bug_value_pfd = B747DR_ap_ias_bug_value
		end
	end
end


function setDistances(fmsO)
	--print("set distances")
	if B747BR_cruiseAlt>0 and B747DR_ap_flightPhase<2 then
		local useFPM=2000
		if B744_fpm>2000 then useFPM=B744_fpm end
		local altDiff=B747BR_cruiseAlt-simDR_pressureAlt1
		local minsToAlt=altDiff/useFPM
		if simDR_groundspeed<150 then minsToAlt=minsToAlt+15 end
		local meters_per_second_to_kts = 1.94384449
		local default_speed = 250 * meters_per_second_to_kts
  		local actual_speed = simDR_groundspeed * meters_per_second_to_kts
		B747BR_toc=(math.max(default_speed, actual_speed)*minsToAlt)/60
	else
		B747BR_toc=-1
	end
	if (fmsO) == nil then
		B747BR_distance_to_dest=-1
		B747BR_totalDistance = 0
		return
	end
	if table.getn(fmsO) == 0 then
		B747BR_distance_to_dest=-1
		B747BR_totalDistance = 0
		return
	end

	local start = B747DR_fmscurrentIndex
	if start == 0 then
		start = 1
	end
	-- [B-14] a fix LNAV sequenced early for its turn (B747DR_vnav_hold_index) stays the path's next point until the
	-- aircraft is past the turn's bisector, as it stays the approach path's and the speed limits' fix: marked only
	-- from the active fix, the profile had setDescentVSpeed aim at the fix after it from the turn's start (NETOM's
	-- 86 deg turn: at NIRSI, 10 nm on, 180 ft below the leg into NETOM), and only the AFDS's altitude at the held
	-- fix's stopped the descent there
	local held = B747DR_vnav_hold_index or 0
	if held >= start then held = 0 end
	local iLat = simDR_latitude
	local iLong = simDR_longitude
	local endI = table.getn(fmsO)
	B747BR_distance_to_dest= getDistance(iLat, iLong, fmsO[endI][5], fmsO[endI][6])
	if table.getn(fmsO) <= 2 then
		B747BR_totalDistance = 0
		return
	end
	if fmsO[start] == nil then
		B747BR_totalDistance = 0
		print("empty data")
		return
	end
	local LastLeg = getDistance(simDR_latitude, simDR_longitude, fmsO[start][5], fmsO[start][6])

	local eLat = fmsO[start][5]
	local eLong = fmsO[start][6]
	local totalDistance = LastLeg
	local nextDistanceInFeet = totalDistance * 6076.12

	-- the end of descent comes after the farthest point of the route, so a route
	-- back to the departure airport does not end at its own departure fixes
	local eod = B747_afds_helpers.route_eod_index(fmsO, getDistance, 10)
	local setTOD = false
	local setTOC = false
	local todDist = B747BR_totalDistance - B747BR_tod
	-- [P49] each entry's distance to the destination as the T/D (B747BR_tod) is measured
	local toEnd = B747_afds_helpers.route_distance_to_end(fmsO, eod, getDistance)
	local vnavData={}
	local vnavI=1
	local lastVnavAlt=-9999
	--print("setDistances")
	local usedToD=false
	for i = 1, endI - 1, 1 do
		-- the route ends at the end of descent and then runs straight to the destination
		-- (added after the loop), so the leg after the end of descent is not added
		if i == eod then
			--print("end fms"..i.."=at alt "..fms[i][3])
			break
		end
		if i >= start then
			iLat = fmsO[i][5]
			iLong = fmsO[i][6]
			eLat = fmsO[i + 1][5]
			eLong = fmsO[i + 1][6]
			LastLeg = getDistance(fmsO[i][5], fmsO[i][6], fmsO[i + 1][5], fmsO[i + 1][6])
			totalDistance = totalDistance + LastLeg
		end

		if totalDistance > todDist and setTOD == false and B747BR_totalDistance > 0 and todDist > 0 then
			setTOD = true
			--interpolate last leg
			local backingDist = totalDistance - todDist
			local legFrac = (LastLeg - backingDist) / LastLeg
			if legFrac >= 0 and legFrac <= 1 and totalDistance - LastLeg < todDist then
				B747BR_todLat = iLat + (eLat - iLat) * legFrac
				B747BR_todLong = iLong + (eLong - iLong) * legFrac
			end
		end
		if B747BR_toc>=0 and totalDistance > B747BR_toc and setTOC == false and B747BR_totalDistance > 0 then
			setTOC = true
			local backingDist = totalDistance - B747BR_toc
			local legFrac = (LastLeg - backingDist) / LastLeg
			if legFrac >= 0 and legFrac <= 1 and totalDistance - LastLeg < B747BR_toc then
				B747BR_tocLat = iLat + (eLat - iLat) * legFrac
				B747BR_tocLong = iLong + (eLong - iLong) * legFrac
			end
		end
		--print("setVNAV "..i.." "..fmsO[i][5]..":"..fmsO[i][6].."/"..fmsO[i][9])
		-- [B-14] the point's altitude on the path: [9] inside its CIFP constraint, a point without [9] the path's there
		-- inside it (afds.vnav_route_point_alt). The profile took [9] alone, and a point below its floor was kept above
		-- it only by the AFDS's altitude at the floor
		local pointAlt=B747_afds_helpers.vnav_route_point_alt(fmsO,i,B747_route_constraints,getDistance,B747BR_cruiseAlt)
		if pointAlt>0 then
			--construct vnav profile
			--[[local isNext="false"
			if i==start then
				isNext="true"
			end]]--
			if pointAlt~=lastVnavAlt or i==start or i==held then
				local vAlt=0
				local tAlt=pointAlt
				if i>1 then
					local distance=getDistance(fmsO[i-1][5],fmsO[i-1][6], fmsO[i][5],fmsO[i][6])
					local fromToD=false
					-- [P49] the first point below CRZ ALT after the T/D on the route (nearer the destination
					-- than the T/D), ahead of the aircraft or passed, starts at the T/D; the entries before the
					-- T/D (the departure, the climb, an older CRZ ALT) never do. The first step down in the
					-- route's order took it: the departure airport's and runway's elevations in [9] (EIDW 242,
					-- 218 ft), so the descent's first path ran from the entry before its point, 3,600 ft below
					-- CRZ ALT at EIDW-EHAM's T/D (DRAG REQUIRED, the kit's speedbrake, 0.5 g on every line
					-- flight); with no route altitude at all before the first descent point, past that point the
					-- next one's path ran from the T/D. An older CRZ ALT left in [9] after the T/D still takes it
					-- as the active or held fix (in the profile then), as before (review 55)
					local afterToD=B747BR_tod>0 and toEnd[i]~=nil and toEnd[i]<B747BR_tod
					if afterToD and pointAlt<B747BR_cruiseAlt and not(usedToD) and B747BR_totalDistance > 0 and B747BR_todLat ~=0 and B747BR_todLong ~=0 then
						distance=getDistance(B747BR_todLat,B747BR_todLong, fmsO[i][5],fmsO[i][6])
						usedToD=true
						fromToD=true
					end
					-- a path from the T/D starts at CRZ ALT, not at an older route altitude
					vAlt,tAlt=B747_afds_helpers.vnav_entry_slope(lastVnavAlt,pointAlt,distance,fromToD,B747BR_cruiseAlt)
				end
				local vNavdataI={fmsO[i][5],fmsO[i][6],tAlt,i>=start or i==held,vAlt}
				vnavData[vnavI]=vNavdataI
				vnavI=vnavI+1
				lastVnavAlt=pointAlt
				--print("setVNAV "..i.." "..fmsO[i][5]..":"..fmsO[i][6].."/"..fmsO[i][9].." "..vAlt)
			end
		end
	end
	local vAlt=0
	if lastVnavAlt>0 then
		local distance=getDistance(vnavData[vnavI-1][1],vnavData[vnavI-1][2], fmsO[endI][5],fmsO[endI][6])
		if distance>0.1 then
			vAlt=(lastVnavAlt-fmsO[endI][9])/distance
        else
            vAlt=0
          end
	end
	if vnavI==1 and vAlt==0 then
		-- we dont have any altitude data, just make a glideslope to the airport
		vAlt=257
	end
	local vNavdataI={fmsO[endI][5],fmsO[endI][6],fmsO[endI][9],(endI>=start),vAlt}
	vnavData[vnavI]=vNavdataI
	B747BR_vnavProfile = json.encode(vnavData)
	--print("setVNAV "..B747BR_vnavProfile)
	totalDistance = totalDistance + getDistance(fmsO[eod][5], fmsO[eod][6], fmsO[endI][5], fmsO[endI][6])
	--simDR_autopilot_altitude_ft
	B747BR_eod_index = eod
	B747BR_totalDistance = totalDistance
	-- in the approach the path error is from the path to the runway, as setDescentVSpeed has it; else
	-- within 15 NM from a 290 ft/nm line to the destination
	local approach = B747_vnav_approach_path(fmsO)
	if approach ~= nil then
		B747BR_fpe = simDR_pressureAlt1 - approach.alt
	elseif B747BR_totalDistance<15 then
		local dtoAirport = getDistance(simDR_latitude, simDR_longitude, fmsO[endI][5], fmsO[endI][6])
		local glideAlt= dtoAirport*290 +fmsO[endI][9]
		B747BR_fpe	= simDR_pressureAlt1-glideAlt
	end
	B747BR_nextDistanceInFeet = nextDistanceInFeet
	-- the T/D reaches every descent constraint and the end of descent altitude ([9], or the
	-- destination elevation) at 290 ft/nm; [3] of the end of descent is a frequency on a navaid
	local cruiseTOD, eodAlt = B747_afds_helpers.route_tod_distance(fmsO, eod, B747BR_cruiseAlt, getDistance,
		B747_route_constraints)
	local currentTOD = ((simDR_pressureAlt1 - eodAlt) / 100) / 2.9
	
	B747BR_tod = cruiseTOD
end

----- ALTITUDE SELECTED -----------------------------------------------------------------
function B747_getCurrentWayPoint(fmsO)
	if table.getn(fmsO)<B747DR_fmscurrentIndex then
		simDR_override_fms_progress=0
		B747_getCurrentWayPoint_default(fmsO)
	else
		B747_getCurrentWayPoint_function(fmsO)
	end
	B747_lnav_update_xtk(fmsO)
	B747_lnav_update_vnav_hold(fmsO)
end

local LNAV_MAX_PREEMPT_XTK_NM=2.0
local LNAV_MIN_PREEMPT_XTK_NM=0.3
local LNAV_PREEMPT_XTK_LEG_FRACTION=0.2
local LNAV_MAX_AUTOMATIC_SEQUENCE_ADVANCE_LEGS=1
-- A leg flown direct to its fix (after an altitude leg's end, VECTORS ...):
-- its turn is anticipated once the track is within LNAV_DIRECT_TO_TRACK_DEG of
-- the fix, after an altitude leg's end (a departure or a missed approach) as a
-- fly-by only up to LNAV_DIRECT_TO_MAX_TURN_DEG (beyond, the fix is passed
-- within LNAV_DIRECT_TO_PASS_NM: a turn-back started near the runway), and
-- the fix is passed within LNAV_DIRECT_TO_ABEAM_NM whatever the track.
local LNAV_DIRECT_TO_TRACK_DEG=30
local LNAV_DIRECT_TO_MAX_TURN_DEG=90
local LNAV_DIRECT_TO_PASS_NM=0.3
local LNAV_DIRECT_TO_ABEAM_NM=0.5

-- X-Plane's HDG SEL bank limit for its bank angle mode (1-6), 20 deg in AUTO;
-- a mode or a limit that cannot be (XTLua's 0 on a first read) is AUTO's 20
local function B747_lnav_bank_limit_deg()
	local mode=tonumber(simDR_autopilot_bank_limit)
	if mode==nil or mode<1 or mode>6 or mode~=math.floor(mode) then return 20 end
	local limit=tonumber(simDR_autopilot_bank_angles[mode-1])
	if limit==nil or limit<5 or limit>35 then return 20 end
	return limit
end

-- [P18] The wind LNAV draws its turns and its path with (kt east and north): the ground velocity less the TAS along
-- the air path (B747_lnav_air_heading_deg), filtered over LNAV_WIND_FILTER_SEC as an IRS's wind is. Taken frame by
-- frame along the nose it swung with the nose off the air path (sideslip in the yaw and roll motion: TAS x beta,
-- 2.5 kt for 0.3 deg at 481 kt), and the arc's radius with it: in a cruise arc a 0.3 deg swing at 3.5 s swung LNAV's
-- heading command 4.8 deg and the bank 2.6 (TST744L's BILTO in p11-L1 and p16-L1: 10-15 deg of bank swinging at
-- about 3.5 s through the arc). The filter starts again after a gap of more than LNAV_WIND_GAP_SEC; a sample that is
-- no number or more than LNAV_MAX_WIND_KTS leaves the filtered wind as it was (none before the first; it gave none for
-- that frame, and the radius jumped: a review).
-- [review 18] The air path's heading: the nose's less the sideslip's and the angle of attack's share in a bank,
-- psi - (beta cos(phi) + alpha sin(phi)) in X-Plane's signs. Taken along the nose the wind also carried alpha sin(phi),
-- steadily: 0.8 deg in a 20 deg bank at FL350 (alpha 2.65 deg), 6.6 kt turning with the 747, which the 30 s filter
-- passed. Through BILTO's turn in a 270/100 wind (p11-L1, p16-L1, p17-L1) the wind along the nose went from 92 to
-- 104 kt with the heading, along the air path it held 98-100 kt (X-Plane's wind indicator goes as the nose's). In the
-- model the arc moved through the turn (radius 13.10, 12.86, 13.29 nm) and the 747 held the bank limit 125 s and went
-- 0.37 nm outside it (a review).
-- Along the air path a 10 s filter is enough: the 3-8 s swing is gone from the sample itself. A sideslip or an angle of
-- attack that is no number counts as 0; both are taken at most 30 deg.
local LNAV_WIND_FILTER_SEC=10
local LNAV_WIND_GAP_SEC=5
local function B747_lnav_air_heading_deg()
	local phi,beta,alpha=tonumber(simDR_AHARS_roll_deg_pilot) or 0,tonumber(simDR_beta_deg) or 0,tonumber(simDR_alpha_deg) or 0
	if phi~=phi then phi=0 end
	if beta~=beta then beta=0 end
	if alpha~=alpha then alpha=0 end
	phi=math.rad(phi)
	beta=B747_afds_helpers.clamp(beta,-30,30)
	alpha=B747_afds_helpers.clamp(alpha,-30,30)
	return simDR_true_heading-(beta*math.cos(phi)+alpha*math.sin(phi))
end
local lnavWind={time=nil,east=0,north=0}
local function B747_lnav_wind()
	local tas=simDR_TAS_mps*1.94384
	local gs=simDR_groundspeed*1.94384
	local track,heading=math.rad(simDR_ground_track_true),math.rad(B747_lnav_air_heading_deg())
	local east=gs*math.sin(track)-tas*math.sin(heading)
	local north=gs*math.cos(track)-tas*math.cos(heading)
	local wind=math.sqrt(east*east+north*north)
	-- [review 18] a sample that is no wind keeps the filtered one (it gave none for that frame: the radius jumped)
	if wind~=wind or wind>B747_afds_helpers.LNAV_MAX_WIND_KTS then
		if lnavWind.time~=nil then return lnavWind.east,lnavWind.north end
		return 0,0
	end
	local now=tonumber(simDRTime) or 0
	local dt=lnavWind.time~=nil and now-lnavWind.time or nil
	if dt==nil or dt<0 or dt>LNAV_WIND_GAP_SEC then
		lnavWind.east,lnavWind.north=east,north
	elseif dt>0 then
		local a=dt/(LNAV_WIND_FILTER_SEC+dt)
		lnavWind.east=lnavWind.east+a*(east-lnavWind.east)
		lnavWind.north=lnavWind.north+a*(north-lnavWind.north)
	end
	lnavWind.time=now
	return lnavWind.east,lnavWind.north
end

-- How far before the fix the fly-by turn from inCourse to outCourse (true, the
-- inbound one at the fix) starts, from the TAS, the bank limit and the wind
-- (B747_lnav_wind); 0 on the ground, below 400 ft
-- above it (as LNAV_ALTITUDE_LEG_MIN_RA_FT: no departure turn is designed
-- lower) and when it is no fly-by
local function B747_lnav_turn_anticipation_nm(inCourse,outCourse)
	if simDR_onGround==1 or simDR_radarAlt1<400 then return 0 end
	local tas=simDR_TAS_mps*1.94384
	local gs=simDR_groundspeed*1.94384
	local windEast,windNorth=B747_lnav_wind()
	return B747_afds_helpers.lnav_turn_anticipation_nm(tas,windEast,windNorth,B747_lnav_bank_limit_deg(),
		inCourse,outCourse,B747_afds_helpers.LNAV_ROLL_RATE_DEG_PER_SEC,gs)
end

local function B747_lnav_leg_supports_preemption(waypoint)
	if waypoint==nil or type(waypoint[5])~="number" or type(waypoint[6])~="number" then return false end
	local waypointType=tonumber(waypoint[2])
	local waypointName=string.upper(tostring(waypoint[8] or ""))
	if waypointType==nil or waypointType==0 or waypointType==2048 then return false end
	if waypointName=="" or waypointName=="PPOS" or waypointName=="LATLON"
		or string.find(waypointName,"VECTOR",1,true) then
		return false
	end
	if string.find(waypointName,"DISCONT",1,true) or string.find(waypointName,"HOLD",1,true)
		or string.find(waypointName,"PROC TURN",1,true) then
		return false
	end
	return true
end

-- An altitude-terminated leg's end (CA/VA/FA, "(650)") is reached once the aircraft is airborne at or
-- above its altitude and 400 ft above the ground (no departure turn is designed lower; a misset
-- altimeter does not end the leg on the runway)
local LNAV_ALTITUDE_LEG_MIN_RA_FT=400
local function B747_altitude_leg_reached(entry)
	local legEndAlt=B747_afds_helpers.altitude_leg_end_ft(entry)
	return legEndAlt~=nil and simDR_onGround==0 and simDR_radarAlt1>=LNAV_ALTITUDE_LEG_MIN_RA_FT
		and simDR_pressureAlt1>=legEndAlt
end

-- The start of the leg to fmsO[i]: the entry before it, but for the leg after altitude-terminated legs'
-- ends ("(650)", which X-Plane may keep moving with the aircraft) the entry before them; and its index
local function B747_lnav_leg_start(fmsO, i)
	local k=i-1
	while k>1 and B747_afds_helpers.altitude_leg_end_ft(fmsO[k])~=nil do
		k=k-1
	end
	return fmsO[k],k
end

-- The inbound course at fmsO[i] (true) for its turn, whether its leg is flown
-- direct to the fix from where the aircraft is, and whether that is after an
-- altitude-terminated leg's end: after such ends ("(650)", reached, from where
-- their altitude was reached) and from an entry that is no course's start
-- (VECTORS, "(VECT)", a discontinuity, a hold, a procedure turn, PPOS) the
-- course is the aircraft's to the fix
local function B747_lnav_inbound_course(fmsO,i)
	local fix=fmsO[i]
	local previous=fmsO[i-1]
	local legStart=B747_lnav_leg_start(fmsO,i)
	local name=string.upper(tostring(legStart[8] or ""))
	local afterAltitude=previous~=nil and B747_afds_helpers.altitude_leg_end_ft(previous)~=nil
	if afterAltitude or name=="(VECT)" or string.find(name,"VECTOR",1,true) or string.find(name,"DISCONT",1,true)
		or string.find(name,"HOLD",1,true) or string.find(name,"PROC TURN",1,true) or name=="PPOS" then
		return (getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude)+180)%360,true,afterAltitude
	end
	return (getHeading(fix[5],fix[6],legStart[5],legStart[6])+180)%360,false,false
end

-- [P14] Whether LNAV was engaged when the active fix became fmsO[current]: noted as B747_lnav_sequence_to sequences
-- it, else on the first call after another change of the active fix (every frame from
-- B747_getCurrentWayPoint_function). Noted only on that first call, a fix sequenced abeam while LNAV was armed was
-- taken for one sequenced with LNAV engaged when LNAV engaged in the same frame (within 2.5 nm of the leg after it),
-- and its arc flown: +30 deg, 2.6 nm inside at 480 kt, 0.92 nm through the leg after it, 63 deg of turning (a review).
-- Where the 747 was then is noted too: where a leg flown direct to that fix starts (B747_lnav_passed_abeam). Noted
-- with the fix's position (fixLat, fixLon; nil as B747_lnav_sequence_to notes it, completed on the next call), and
-- again when another fix takes the active one's place at its index (a route edit), and not a position of 0/0 (XTLua's
-- first read after a script reload): the leg ran from where the 747 was when the fix before became active, or from
-- 0N 0E, and the fix was sequenced 8.9 or 2.1 nm off its wayline (a review).
local lnavSequenced={current=0,engaged=false,lat=nil,lon=nil,fixLat=nil,fixLon=nil}
local function B747_lnav_note_position()
	if simDR_latitude~=0 or simDR_longitude~=0 then
		lnavSequenced.lat,lnavSequenced.lon=simDR_latitude,simDR_longitude
	else
		lnavSequenced.lat,lnavSequenced.lon=nil,nil
	end
end
local function B747_lnav_note_sequenced(current,fix)
	lnavSequenced.current,lnavSequenced.engaged=current,B747DR_ap_lnav_state==2
	lnavSequenced.fixLat,lnavSequenced.fixLon=fix and fix[5],fix and fix[6]
	B747_lnav_note_position()
end
local function B747_lnav_sequenced_engaged(fmsO,current)
	local fix=fmsO[current]
	if lnavSequenced.current~=current or (fix~=nil and lnavSequenced.fixLat~=nil
		and (lnavSequenced.fixLat~=fix[5] or lnavSequenced.fixLon~=fix[6])) then
		B747_lnav_note_sequenced(current,fix)
	else
		if fix~=nil and lnavSequenced.fixLat==nil then lnavSequenced.fixLat,lnavSequenced.fixLon=fix[5],fix[6] end
		if lnavSequenced.lat==nil then B747_lnav_note_position() end
	end
	return lnavSequenced.engaged
end

local function B747_lnav_sequence_to(index, why)
	B747_lnav_note_sequenced(index)
	B747DR_fms_setCurrent=index
	B747DR_fmscurrentIndex=index
	if B747DR_ap_lnav_state==2 then
		B747DR_ap_lnavHeading_mode=index
	end
	print("B747DR_fmscurrentIndex="..index.." "..why)
	setVNAVState("recalcAfter", index)
end

-- [i-1b] The lateral path through fmsO[k] (afds.lnav_path_at at the aircraft): the leg into it, the fly-by arc
-- of its turn and the leg after it, with the parameters p (B747_lnav_path_parameters): the arc's radius the
-- turn's at the bank limit and the highest ground speed the wind gives across it (also the capture
-- look-ahead's base); a turn LNAV does not fly by (into an entry that is no
-- fix, or of LNAV_FLYBY_REVERSAL_DEG or more; on the ground or below LNAV_ALTITUDE_LEG_MIN_RA_FT above it, as
-- the anticipation: a SID's arc banked from 118 ft) straight on through the fix; the turn to the leg after a fix
-- listed twice in a row (a leg of no length, whose course is none: the path took it as 000 or 180 and
-- orbited). nil where the leg into it is no course from a fix: from the origin airport, flown direct to the
-- fix (after an altitude leg's end, from VECTORS, a hold, PPOS...), or of no length.
local LNAV_PATH_MIN_LEG_NM=0.1
local function B747_lnav_leg_has_course(a,b)
	return a~=nil and b~=nil and getDistance(a[5],a[6],b[5],b[6])>=LNAV_PATH_MIN_LEG_NM
end
-- The turn LNAV's path makes at fmsO[k], as B747_lnav_path_at_fix says (nil where there is no path through it):
-- the fix, the inbound and outbound courses, the radius for the ground speed across the turn at the bank
-- limit (for a turn of more than LNAV_FLYBY_MAX_TURN_DEG, whose path sweeps on past the outbound course, the
-- wind's whole speed: afds.lnav_capped_turn), and the entries at both ends of its legs with their indexes.
-- [P15] Such a turn is decided once, as the 747 comes to where its path starts (B747_lnav_capped_decide): flown by
-- its path, or passed abeam as a reversal is (straight on through the fix); raw: as if flown, for the turns next to it.
local B747_lnav_capped_turn_fits
local B747_lnav_capped_decide
-- The decisions, per fix flown to or just behind (by its index and position): decided ("flown", "abeam", nil before
-- the path's start) and the element of its path the 747 has come to (B747_lnav_path_at_fix: it only moves on)
local lnavCapped={}
-- [review 17] the active fix as last seen: when it moves back (the leg search moving back, a reposition) no decision is
-- kept. A fix flown by and active again had its path from its last element on, and was sequenced in that frame, 10 nm
-- before it, the 747 turning 355-375 deg (a review).
local lnavCappedCurrent=0
local function B747_lnav_capped_state(fmsO,k)
	if B747DR_fmscurrentIndex<lnavCappedCurrent then lnavCapped={} end
	lnavCappedCurrent=B747DR_fmscurrentIndex
	local fix=fmsO[k]
	local key=k..":"..tostring(fix[5])..":"..tostring(fix[6])
	local state=lnavCapped[key]
	if state==nil then
		local current=B747DR_fmscurrentIndex
		for other,o in pairs(lnavCapped) do
			if o.index<current-2 or o.index>current then lnavCapped[other]=nil end
		end
		state={index=k,decided=nil,element=1}
		lnavCapped[key]=state
	end
	return state
end
-- [P21] A fly-by turn's radius is fixed once the 747 comes to where its path leaves the leg into the fix, as a real
-- FMC builds a turn's transition from the ground speed it predicts and keeps it while the turn is flown. Drawn every
-- frame from the TAS of the moment, the arc moved as the speed changed in the turn: p20-L1's BILTO (137 deg at FL350)
-- slowed from M.836 to .816, the arc's radius went from 13.4 to 12.95 nm, and the 747, round it at the 20 deg bank
-- limit with nothing to spare, held the limit 99 s and went 0.54 nm outside it. Kept while the fix is the one flown to
-- or the one before it (two back past a fix listed twice, as B747_lnav_fix_before takes it); let go when the route
-- there changes (keyed by the fix's place), when the active fix moves back
-- (the leg search, a reposition), and when the 747 is back on the leg more than LNAV_TURN_RADIUS_RELATCH_NM before
-- where the turn starts.
local LNAV_TURN_RADIUS_RELATCH_NM=1
local lnavTurnRadius={}
local lnavTurnRadiusCurrent=0
local function B747_lnav_turn_radius_fixed(fmsO,k,inCourse,outCourse,radius)
	local current=B747DR_fmscurrentIndex
	if current<lnavTurnRadiusCurrent then lnavTurnRadius={} end
	lnavTurnRadiusCurrent=current
	for other,o in pairs(lnavTurnRadius) do
		if o.index<current-2 or o.index>current then lnavTurnRadius[other]=nil end
	end
	if k<current-2 or k>current then return radius end
	local fix=fmsO[k]
	local key=k..":"..tostring(fix[5])..":"..tostring(fix[6])
	local turn=(outCourse-inCourse+540)%360-180
	-- where the 747 is along the leg into the fix (0 at the fix, - before it)
	local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
	local bearing=math.rad(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude))
	local inRad=math.rad(inCourse)
	local along=distance*(math.sin(bearing)*math.sin(inRad)+math.cos(bearing)*math.cos(inRad))
	local fixed=lnavTurnRadius[key]
	if fixed~=nil then
		local before=B747_afds_helpers.lnav_turn_extent_nm(turn,fixed.radius)
		if k~=current or along+before>=-LNAV_TURN_RADIUS_RELATCH_NM then return fixed.radius end
		lnavTurnRadius[key]=nil
	end
	if k==current and along+B747_afds_helpers.lnav_turn_extent_nm(turn,radius)>=0 then
		lnavTurnRadius[key]={index=k,radius=radius}
	end
	return radius
end

local function B747_lnav_turn_at(fmsO,k,p,raw)
	local count=table.getn(fmsO)
	local fix=fmsO[k]
	if k<2 or k>=count or not B747_lnav_leg_supports_preemption(fix) then return nil end
	local s=k-1
	while s>1 and B747_afds_helpers.altitude_leg_end_ft(fmsO[s])~=nil do s=s-1 end
	local legStart=fmsO[s]
	if legStart==nil or tonumber(legStart[2])==1 or type(legStart[5])~="number" or type(legStart[6])~="number"
		or not B747_lnav_leg_has_course(legStart,fix) then
		return nil
	end
	local inCourse,directTo=B747_lnav_inbound_course(fmsO,k)
	if directTo then return nil end
	local outCourse=inCourse
	local n=k+1
	if fmsO[n]~=nil and not B747_lnav_leg_has_course(fix,fmsO[n]) then n=n+1 end
	local nextFix=fmsO[n]
	if n<count and simDR_onGround==0 and simDR_radarAlt1>=LNAV_ALTITUDE_LEG_MIN_RA_FT
		and B747_lnav_leg_supports_preemption(nextFix) and B747_lnav_leg_has_course(fix,nextFix) then
		local course=getHeading(fix[5],fix[6],nextFix[5],nextFix[6])
		if math.abs(getHeadingDifference(course,inCourse))<B747_afds_helpers.LNAV_FLYBY_REVERSAL_DEG then
			outCourse=course
		end
	end
	local capped=math.abs(getHeadingDifference(outCourse,inCourse))>B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG
	local groundSpeed
	if capped then
		groundSpeed=p.tas+math.sqrt(p.windEast*p.windEast+p.windNorth*p.windNorth)
	else
		groundSpeed=B747_afds_helpers.lnav_turn_ground_speed_kts(p.tas,p.windEast,p.windNorth,inCourse,outCourse)
	end
	local radius=B747_afds_helpers.turn_radius_nm(groundSpeed,p.bank)
	if radius==nil then return nil end
	radius=B747_lnav_turn_radius_fixed(fmsO,k,inCourse,outCourse,radius)
	if capped and not raw then
		local state=B747_lnav_capped_state(fmsO,k)
		local active=k==B747DR_fmscurrentIndex
		if active then
			B747_lnav_capped_decide(state,fmsO,k,p,inCourse,outCourse,radius,legStart,s,fix,nextFix,n)
		end
		-- passed abeam: decided so, or a fix behind the active one that was never decided
		if state.decided=="abeam" or (state.decided==nil and not active) then
			outCourse=inCourse
			radius=B747_afds_helpers.turn_radius_nm(B747_afds_helpers.lnav_turn_ground_speed_kts(p.tas,p.windEast,
				p.windNorth,inCourse,outCourse),p.bank)
			if radius==nil then return nil end
		end
	end
	return fix,inCourse,outCourse,radius,legStart,s,nextFix,n
end

-- Whether the path of a turn of more than LNAV_FLYBY_MAX_TURN_DEG at fix (from legStart, fmsO[s], to nextFix,
-- fmsO[n]) fits on its legs: where it leaves the leg into the fix (afds.lnav_turn_extent_nm) no farther back than
-- where the turn at legStart joins that leg, and where it joins the leg after the fix no farther on than where the
-- turn at nextFix leaves it (those turns flown by). On a 10 nm leg after a 170 deg turn-back at 200 kt the path
-- joined the leg only after the next turn's arc began (9.6 and 8.4 nm along it): still 45 deg on, the 747 went
-- 1.16 nm outside the leg after that 90 deg turn (0.54 passed abeam).
B747_lnav_capped_turn_fits=function(fmsO,p,inCourse,outCourse,radius,legStart,s,fix,nextFix,n)
	local before,after=B747_afds_helpers.lnav_turn_extent_nm((outCourse-inCourse+540)%360-180,radius)
	local prevAfter,nextBefore=0,0
	local _,pIn,pOut,pRadius=B747_lnav_turn_at(fmsO,s,p,true)
	if pIn~=nil then
		local _,a=B747_afds_helpers.lnav_turn_extent_nm((pOut-pIn+540)%360-180,pRadius)
		prevAfter=a
	end
	local _,nIn,nOut,nRadius=B747_lnav_turn_at(fmsO,n,p,true)
	if nIn~=nil then
		nextBefore=B747_afds_helpers.lnav_turn_extent_nm((nOut-nIn+540)%360-180,nRadius)
	end
	return before+prevAfter<=getDistance(legStart[5],legStart[6],fix[5],fix[6])
		and after+nextBefore<=getDistance(fix[5],fix[6],nextFix[5],nextFix[6])
end

-- How far before fmsO[j] LNAV's path leaves the leg into it and how far after it the path joins the leg after
-- it (afds.lnav_turn_extent_nm), before the legs are shared, and the turn there (deg, + right); 0, 0, 0 without a
-- fly-by turn there. [review 17] None for a turn of more than LNAV_FLYBY_MAX_TURN_DEG until it is decided flown (its
-- path then fits, B747_lnav_capped_turn_fits, and leaves room for the arcs next to it): as the active fix's undecided
-- turn it was taken as flown though it did not fit, the arc before it shrank mid-turn, the 747 rolled from +20 to
-- -5.9 deg, and 9 s later, decided abeam, the arc grew back (1.2 nm outside it; a review).
local function B747_lnav_turn_tangent_nm(fmsO,j,p)
	local fix,inCourse,outCourse,radius=B747_lnav_turn_at(fmsO,j,p)
	if fix==nil then return 0,0,0 end
	local turn=(outCourse-inCourse+540)%360-180
	if math.abs(turn)>B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then
		local state=lnavCapped[j..":"..tostring(fix[5])..":"..tostring(fix[6])]
		if state==nil or state.decided~="flown" then return 0,0,0 end
	end
	local before,after=B747_afds_helpers.lnav_turn_extent_nm(turn,radius)
	return before,after,turn
end

-- Whether the arc of a fly-by turn (turn, deg + right) shares a leg with the turn at the leg's other end
-- (otherTurn): one the same way at least as big (within a degree), or one that turns the 747 round with it
-- (LNAV_PATH_REVERSAL_DEG or more together, which no fly-by arc joins). A bigger turn keeps its arc next to a
-- slighter one, which shares the leg with it: squeezed to fit, its arc could not be flown (120 deg with 1.5 nm
-- to a fix where the route turned 2 deg: 2.2 nm outside the leg after it at 250 kt, 9.5 nm with 4.5 nm at 480
-- kt), and ending past the next fix it hands the 747 over to that fix's path facing much its way.
local LNAV_PATH_REVERSAL_DEG=175
local function B747_lnav_arc_shares_leg(turn,otherTurn)
	return turn*otherTurn>0 and (math.abs(otherTurn)>=math.abs(turn)-1
		or math.abs(turn+otherTurn)>=LNAV_PATH_REVERSAL_DEG)
end

local function B747_lnav_path_at_fix(fmsO,k,p)
	local fix,inCourse,outCourse,radius,legStart,s,nextFix,n=B747_lnav_turn_at(fmsO,k,p)
	if fix==nil then return nil end
	local capture=math.min(radius*B747_afds_helpers.LNAV_PATH_CAPTURE_RADII,B747_afds_helpers.LNAV_PATH_MAX_LOOKAHEAD_NM)
	-- the arcs of turns the same way at the two ends of a leg share it (B747_lnav_arc_shares_leg): where they
	-- would overlap the arc is made smaller in proportion, so the path runs round the one, along the leg and
	-- round the other in turn (overlapping on a short leg, they handed the 747 over to the next leg's capture
	-- while it still faced away from it, and it turned the wrong way round: 287 deg more than two 120 deg turns
	-- 2 nm apart at 250 kt). Opposite turns' arcs cross where they overlap, and the 747 goes from the one to the
	-- other.
	local turn=(outCourse-inCourse+540)%360-180
	if math.abs(turn)>=1 then
		local before,after=B747_afds_helpers.lnav_turn_extent_nm(turn,radius)
		local share=1
		local _,otherAfter,otherTurn=B747_lnav_turn_tangent_nm(fmsO,s,p)
		local into=getDistance(legStart[5],legStart[6],fix[5],fix[6])
		if B747_lnav_arc_shares_leg(turn,otherTurn) and before+otherAfter>into then
			share=math.min(share,into/(before+otherAfter))
		end
		local otherBefore
		otherBefore,_,otherTurn=B747_lnav_turn_tangent_nm(fmsO,n,p)
		local outof=getDistance(fix[5],fix[6],nextFix[5],nextFix[6])
		if B747_lnav_arc_shares_leg(turn,otherTurn) and after+otherBefore>outof then
			share=math.min(share,outof/(after+otherBefore))
		end
		-- [review 22] the share fixed with the turn's radius (B747_lnav_turn_radius_fixed): the next turn's arc, drawn
		-- for the AFDS's target until its own start, grew with a target step (x1.69 at the cap), and through the share
		-- the arc being flown shrank (2.90 to 2.23 nm at 250 kt: 25 deg of bank; a review)
		local fixed=lnavTurnRadius[k..":"..tostring(fix[5])..":"..tostring(fix[6])]
		if fixed~=nil then
			if fixed.share==nil then fixed.share=share end
			share=fixed.share
		end
		radius=radius*share
	end
	local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
	local bearing=math.rad(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude))
	-- [P15] on a capped turn's path the 747's place only moves on (B747_lnav_capped_state's element)
	local state=nil
	if math.abs(turn)>B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then state=B747_lnav_capped_state(fmsO,k) end
	local path=B747_afds_helpers.lnav_path_at(distance*math.sin(bearing),distance*math.cos(bearing),inCourse,outCourse,
		radius,p.lookahead,capture,state and state.element)
	if state and path and path.element_index then state.element=math.max(state.element,path.element_index) end
	return path,fix
end

-- [review 21] The TAS the 747 is coming to: the AFDS's speed target as a TAS (at the IAS's or the Mach's ratio of the
-- moment) when it is faster than the TAS, by at most LNAV_TARGET_TAS_MAX_RATIO; else, or when it cannot be told, the
-- TAS. A turn's radius fixed at its arc start from the TAS of the moment was too tight for an accelerating 747 later in
-- the turn (DW129 at 0.45 kt/s: 0.20 nm outside, 0.16 drawn every frame; a review), as a real FMC draws a turn for the
-- speed it predicts there.
local LNAV_TARGET_TAS_MAX_RATIO=1.3
local function B747_lnav_target_tas_kts(tas)
	local ratio
	if simDR_autopilot_airspeed_is_mach==1 then
		local mach,target=tonumber(simDR_airspeed_mach),tonumber(simDR_autopilot_airspeed_kts_mach)
		if mach~=nil and target~=nil and mach>0.2 then ratio=target/mach end
	else
		local ias,target=tonumber(simDR_ind_airspeed_kts_pilot),tonumber(simDR_autopilot_airspeed_kts)
		if ias~=nil and target~=nil and ias>60 then ratio=target/ias end
	end
	if ratio==nil or not (ratio>1) then return tas end
	return tas*math.min(ratio,LNAV_TARGET_TAS_MAX_RATIO)
end

-- What LNAV's path is drawn with now: the TAS the 747 is coming to (B747_lnav_target_tas_kts), the wind
-- (B747_lnav_wind: kt east and north; none when it cannot be), the bank limit and the look-ahead; nil not moving.
local function B747_lnav_path_parameters()
	local tas=simDR_TAS_mps*1.94384
	local gs=simDR_groundspeed*1.94384
	if not (tas>0) or not (gs>0) then return nil end
	local windEast,windNorth=B747_lnav_wind()
	return {tas=B747_lnav_target_tas_kts(tas),windEast=windEast,windNorth=windNorth,bank=B747_lnav_bank_limit_deg(),
		lookahead=B747_afds_helpers.clamp(gs*B747_afds_helpers.LNAV_PATH_LOOKAHEAD_S/3600,
			B747_afds_helpers.LNAV_PATH_MIN_LOOKAHEAD_NM,B747_afds_helpers.LNAV_PATH_MAX_LOOKAHEAD_NM)}
end

-- [P15] Whether the turn at fmsO[k] (of turnDeg) is flown by: up to LNAV_FLYBY_MAX_TURN_DEG; beyond it, short of
-- LNAV_FLYBY_REVERSAL_DEG, where its path fits on its legs (B747_lnav_turn_at); never not moving.
local function B747_lnav_turn_flown_by(fmsO,k,turnDeg)
	local turn=math.abs(turnDeg)
	if turn>=B747_afds_helpers.LNAV_FLYBY_REVERSAL_DEG then return false end
	if turn<=B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then return true end
	local p=B747_lnav_path_parameters()
	if p==nil then return false end
	local fix,inCourse,outCourse=B747_lnav_turn_at(fmsO,k,p)
	return fix~=nil and math.abs(getHeadingDifference(outCourse,inCourse))>B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG
end

-- The fix of the 747's own DIRECT TO (B747DR_ap_lnav_xtk_target -100, which the steering makes 0 within 10 nm
-- of it): its leg is flown direct to it until it is passed, and it is no fly-by turn's fix after that (LNAV's
-- path took the leg back once the target was 0 and passed the fix 4 to 7.5 nm off). 0 for none.
local lnavDirectToIndex=0
local function B747_lnav_direct_to_index(current)
	if B747DR_ap_lnav_xtk_target<=-99.5 then
		lnavDirectToIndex=current
	elseif current~=lnavDirectToIndex and current~=lnavDirectToIndex+1 then
		lnavDirectToIndex=0
	end
	return lnavDirectToIndex
end

-- The fix before fmsO[i] (past one listed twice in a row) where a leg to fmsO[i] starts that LNAV's path could
-- take (nil from the origin airport, from an entry that is no fix, or for a leg of no length), and whether that
-- fix was no fly-by: reached direct, or a turn not flown by (B747_lnav_turn_flown_by: passed abeam).
local function B747_lnav_fix_before(fmsO,i)
	local k=i-1
	if k>2 and not B747_lnav_leg_has_course(B747_lnav_leg_start(fmsO,k),fmsO[k]) then k=k-1 end
	local before=fmsO[k]
	if k<2 or not B747_lnav_leg_supports_preemption(before) or tonumber(B747_lnav_leg_start(fmsO,k)[2])==1
		or not B747_lnav_leg_has_course(B747_lnav_leg_start(fmsO,k),before)
		or not B747_lnav_leg_has_course(before,fmsO[i]) then
		return nil,false
	end
	local inCourse,directTo=B747_lnav_inbound_course(fmsO,k)
	local outCourse=getHeading(before[5],before[6],fmsO[i][5],fmsO[i][6])
	return k,(directTo or not B747_lnav_turn_flown_by(fmsO,k,getHeadingDifference(outCourse,inCourse)))
end

-- [P15] Decides the capped turn at fmsO[k] (state, B747_lnav_capped_state) as the 747 comes to where its path starts:
-- flown by its path if LNAV is engaged then, the 747 is on the leg into the fix (within LNAV_MAX_PREEMPT_XTK_NM of it,
-- its track within 90 deg of it), the fix before was flown by and the path fits on its legs; else passed abeam.
-- Decided once: judged every frame from the TAS and the wind, the fit flipped 20 times in a turn at 250 +-1.5 kt (13
-- bank reversals), and a 747 off the path past its start (LNAV pushed late, a leg steered as before) flew round the
-- path from there or had it given up (a review). Decided again once the 747 is back on the leg more than a mile before
-- the start.
B747_lnav_capped_decide=function(state,fmsO,k,p,inCourse,outCourse,radius,legStart,s,fix,nextFix,n)
	local capped=B747_afds_helpers.lnav_capped_turn((outCourse-inCourse+540)%360-180,radius)
	if capped==nil then return end
	local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
	local bearing=math.rad(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude))
	local inRad=math.rad(inCourse)
	local east,north=distance*math.sin(bearing),distance*math.cos(bearing)
	local alongStart=east*math.sin(inRad)+north*math.cos(inRad)+capped.before_nm
	local onLeg=math.abs(east*math.cos(inRad)-north*math.sin(inRad))<=LNAV_MAX_PREEMPT_XTK_NM
		and math.abs(getHeadingDifference(simDR_ground_track_true,inCourse))<=90
	if state.decided~=nil and alongStart<-1 and onLeg then
		state.decided,state.element=nil,1
	end
	if state.decided==nil and alongStart>=0 then
		local _,noFlyBy=B747_lnav_fix_before(fmsO,k)
		local flown=B747DR_ap_lnav_state==2 and onLeg and not noFlyBy
			and B747_lnav_capped_turn_fits(fmsO,p,inCourse,outCourse,radius,legStart,s,fix,nextFix,n)
		state.decided=flown and "flown" or "abeam"
	end
	-- [review 17] flown, then LNAV not engaged past the start (HDG SEL, LNAV disconnected): passed abeam from then on.
	-- Kept flown, LNAV pushed again 3 nm before the fix steered for the path's arc 4.3 nm away, the leg search
	-- sequenced the fix 2.4 nm out and the path switched back to the arc: 612-705 deg of turning (a review)
	if state.decided=="flown" and alongStart>=0 and B747DR_ap_lnav_state~=2 then
		-- [review 18] only once the 747 is more than LNAV_MAX_PREEMPT_XTK_NM off the path, as for the fix before's:
		-- let go for 5 s 20 s into the path, the 747 went back to the inbound leg and passed the fix abeam (507 deg of
		-- turning, against 359 on round the path; a review)
		local capture=math.min(radius*B747_afds_helpers.LNAV_PATH_CAPTURE_RADII,B747_afds_helpers.LNAV_PATH_MAX_LOOKAHEAD_NM)
		local path=B747_afds_helpers.lnav_path_at(east,north,inCourse,outCourse,radius,p.lookahead,capture,state.element)
		if path==nil or math.abs(path.xtk_nm)>LNAV_MAX_PREEMPT_XTK_NM then
			state.decided="abeam"
		end
	end
end

-- [i-1b] Whether the arc at the fix before (fmsO[k], LNAV's path through it path) is flown once that fix has
-- been sequenced: after a leg LNAV steered as before (the fix before k no fly-by), only if the 747 was on that
-- path or on the leg into k then, within LNAV_PATH_ON_LEG_NM and LNAV_PATH_ON_LEG_DEG of either; else LNAV takes
-- the next leg's path. Drawn from a leg the 747 was not on, k's arc first rolled it away from its turn: 1.16 nm
-- outside the leg after a 90 deg turn 10 nm after a 170 deg turn-back (0.6 nm inside the leg to it, 19 deg off),
-- 0.42 nm 15 nm after a 165 deg one (0.2 nm, 7 deg off), steered as before 0.54 and 0.24. The leg too: the arc,
-- drawn for the highest ground speed across the turn, begins before the anticipation's lead in wind, and a 747
-- on the leg is already into it, the arc's course turned away (9 deg at 250 kt, +90 deg, 000/40). [P14] So too
-- after a fix sequenced while LNAV was not engaged (abeam it, B747_lnav_passed_abeam), whose turn LNAV did not
-- fly: armed LNAV engaging on the active leg flew the fix before's leg and arc instead (LNAV pushed at 250 kt
-- 12 nm off, 90 deg towards the leg 1 nm past its start, 1 nm beside the leg into its start: engaged 5.2 nm off
-- the active leg, it turned 208 deg and went 0.68 nm through it; engaged where the turn onto it begins, 2.7 nm
-- off, 2.0 nm). Decided once for each fix flown to.
local LNAV_PATH_ON_LEG_NM=0.1
local LNAV_PATH_ON_LEG_DEG=5
local lnavArcBefore={current=0,lat=0,lon=0,flown=false}
local function B747_lnav_arc_before_flown(fmsO,k,current,path)
	local before=fmsO[k]
	if lnavArcBefore.current~=current or lnavArcBefore.lat~=before[5] or lnavArcBefore.lon~=before[6] then
		local _,noFlyBy=B747_lnav_fix_before(fmsO,k)
		local turnFlown=not noFlyBy and B747_lnav_sequenced_engaged(fmsO,current)
		lnavArcBefore.current,lnavArcBefore.lat,lnavArcBefore.lon=current,before[5],before[6]
		local onPath=math.abs(path.xtk_nm)<=LNAV_PATH_ON_LEG_NM
			and math.abs(getHeadingDifference(simDR_ground_track_true,path.course_deg))<=LNAV_PATH_ON_LEG_DEG
		local onLeg=false
		if not turnFlown and not onPath then
			local legStart=B747_lnav_leg_start(fmsO,k)
			local legXtk=B747_afds_helpers.signed_cross_track_nm(legStart[5],legStart[6],before[5],before[6],
				simDR_latitude,simDR_longitude,getDistance,getHeading)
			local inCourse=B747_lnav_inbound_course(fmsO,k)
			onLeg=legXtk~=nil and math.abs(legXtk)<=LNAV_PATH_ON_LEG_NM
				and math.abs(getHeadingDifference(simDR_ground_track_true,inCourse))<=LNAV_PATH_ON_LEG_DEG
		end
		lnavArcBefore.flown=turnFlown or onPath or onLeg
	end
	return lnavArcBefore.flown
end

-- [i-1b] The lateral path LNAV flies now (afds.lnav_path_at through a fix, B747_lnav_path_at_fix), with the
-- fix it is about: the fix flown to's, but after its turn has been sequenced the fix before's until its arc
-- ends, the aircraft gets farther off it than the anticipation allows (2 nm), or the fix flown to's arc is
-- within the look-ahead (and not after a leg steered as before the 747 was not on: B747_lnav_arc_before_flown).
-- The aim a look-ahead (LNAV_PATH_LOOKAHEAD_S of ground speed) along round the arcs
-- and LNAV_PATH_CAPTURE_RADII of the turn radius along the legs, never nearer than the cross-track (an
-- intercept of at most 45 deg). nil without such a path, with an offset or a direct-to
-- (B747DR_ap_lnav_xtk_target, the 747's own direct-to until its fix is passed), or not moving; and after a
-- fix that was no fly-by (reached direct, or a turn not flown by passed abeam: B747_lnav_fix_before), whose
-- next leg starts behind the 747 (on a 170 deg turn passed abeam the path guidance orbited round it): LNAV
-- steers as before there (at the fix within 10 nm of it, 5 nm along the leg beyond).
local function B747_lnav_path_now(fmsO,current)
	-- another fix flown to: B747_lnav_arc_before_flown decides again when the same one comes back (a reposition,
	-- back-sequencing)
	if lnavArcBefore.current~=current then lnavArcBefore.current=0 end
	local directToIndex=B747_lnav_direct_to_index(current)
	if B747DR_ap_lnav_xtk_target~=0 or current<2 or fmsO[current]==nil or directToIndex==current then return nil end
	local p=B747_lnav_path_parameters()
	if p==nil then return nil end
	local path,fix=nil,nil
	local k,noFlyBy=B747_lnav_fix_before(fmsO,current)
	if k~=nil and k~=directToIndex then
		if noFlyBy then return nil end
		path,fix=B747_lnav_path_at_fix(fmsO,k,p)
		if path~=nil and (path.element=="out" or math.abs(path.xtk_nm)>LNAV_MAX_PREEMPT_XTK_NM
			or not B747_lnav_arc_before_flown(fmsO,k,current,path)) then
			path=nil
		end
	end
	-- the fix flown to's path once its arc is within the look-ahead: on a short leg the arcs at its two ends
	-- meet (EIDW DW128-DW129, 3.7 nm), and following the fix before's to its end the 747 began DW129's turn
	-- 0.4 nm into its arc
	local own,ownFix=B747_lnav_path_at_fix(fmsO,current,p)
	if path==nil or (own~=nil and own.along_nm+p.lookahead>=0) then path,fix=own,ownFix end
	if path==nil then return nil end
	return path,fix
end

-- [i-1b] LNAV's path guidance: the true track to the aim point along the path (B747_lnav_path_now); nil
-- without a path, LNAV then steering as before.
function B747_lnav_path_track(fmsO,current)
	local path,fix=B747_lnav_path_now(fmsO,current)
	if path==nil then return nil end
	local aimDistance=math.sqrt(path.aim_east_nm*path.aim_east_nm+path.aim_north_nm*path.aim_north_nm)
	local aimLat,aimLon=movePoint(fix[5],fix[6],aimDistance,math.deg(math.atan2(path.aim_east_nm,path.aim_north_nm))%360)
	return getHeading(simDR_latitude,simDR_longitude,aimLat,aimLon)
end

-- [i-1b] LNAV ARM: LNAV pushed in flight (armed, B747DR_ap_lnav_state 1) engages within LNAV_CAPTURE_XTK_NM of the
-- active leg's line on any track, before the leg's start too, or on a track towards the line at up to 90 deg that
-- crosses it before the active fix, where the turn onto it begins (the turn's anticipation across the leg: 3.0 nm for
-- 45 deg at 480 kt and 20 deg of bank, 9.7 for 90). Otherwise LNAV stays armed and the roll mode before it (HDG SEL,
-- HDG HOLD) flies on, as on Aerowinx PSX's 747-400 (2.5 nm; the FCOM's figure to be confirmed). While LNAV is not
-- engaged the FMC sequences the active fix only abeam it (B747_lnav_passed_abeam), so the active leg is the one the
-- 747 is beside or coming to. At once where there is no such leg: none active, from the origin airport, of no length,
-- flown direct (after VECTORS, an altitude leg's end, PPOS, a hold), with an offset or a direct-to (the 747's own:
-- from where it is).
local LNAV_CAPTURE_XTK_NM=2.5
-- 90 deg, and 0.001 more: a track square to the leg can come out at 90.00000000000001
local LNAV_CAPTURE_MAX_INTERCEPT_DEG=90.001
-- Whether the 747 is where armed LNAV captures the active leg to fmsO[i] (true or false), nil where there is no such
-- leg.
local function B747_lnav_captures_leg(fmsO,i)
	local fix=fmsO[i]
	if i<2 or fix==nil or type(fix[5])~="number" or type(fix[6])~="number" then return nil end
	local legStart=B747_lnav_leg_start(fmsO,i)
	if legStart==nil or tonumber(legStart[2])==1 or type(legStart[5])~="number" or type(legStart[6])~="number"
		or not B747_lnav_leg_has_course(legStart,fix) then
		return nil
	end
	local _,directTo=B747_lnav_inbound_course(fmsO,i)
	if directTo then return nil end
	local xtk=B747_afds_helpers.signed_cross_track_nm(legStart[5],legStart[6],fix[5],fix[6],simDR_latitude,
		simDR_longitude,getDistance,getHeading)
	if xtk==nil then return nil end
	if math.abs(xtk)<=LNAV_CAPTURE_XTK_NM then return true end
	-- on a track towards the line at up to 90 deg crossing it before the fix: where the turn onto it begins, the
	-- anticipation of the fly-by turn from the track onto the leg (the arc at the bank limit, half the roll-in, the
	-- wind) across the leg, from the leg's course abeam the 747 (a long great-circle leg turns: 1 deg in 50 nm at
	-- 52 N), before the start the course it starts on; where the track crosses the line: along + |xtk| / tan(intercept)
	local legCourse=getHeading(legStart[5],legStart[6],fix[5],fix[6])
	local fromStart=getDistance(legStart[5],legStart[6],simDR_latitude,simDR_longitude)
	local along=fromStart*math.cos(math.rad(
		getHeadingDifference(legCourse,getHeading(legStart[5],legStart[6],simDR_latitude,simDR_longitude))))
	local course=legCourse
	if along>0 then
		local abeamLat,abeamLon=movePoint(legStart[5],legStart[6],along,legCourse)
		course=(getHeading(abeamLat,abeamLon,legStart[5],legStart[6])+180)%360
	end
	local towards=getHeadingDifference(course,simDR_ground_track_true)
	if xtk*towards>=0 or math.abs(towards)>LNAV_CAPTURE_MAX_INTERCEPT_DEG then return false end
	local crossing=along+math.abs(xtk)/math.tan(math.rad(math.max(math.abs(towards),1)))
	if crossing>=getDistance(legStart[5],legStart[6],fix[5],fix[6]) then return false end
	local lead=B747_lnav_turn_anticipation_nm(simDR_ground_track_true,course)
	return math.abs(xtk)<=lead*math.sin(math.rad(math.abs(towards)))
end
local function B747_lnav_capture_now(fmsO)
	if B747DR_ap_lnav_xtk_target~=0 then return true end
	return B747_lnav_captures_leg(fmsO,B747DR_fmscurrentIndex)~=false
end

-- [i-1b] Armed LNAV engages above 50 ft where B747_lnav_capture_now allows, and when it was armed on the ground for
-- the takeoff as before (a leg from a runway end ahead of the 747 lifting off), from B747_ap_fma; before LNAV ARM it
-- engaged at once, wherever the 747 was.
local lnavArmedForTakeoff=false
function B747_lnav_engage_armed(fmsO)
	if B747DR_ap_lnav_state~=1 then
		lnavArmedForTakeoff=false
		return
	end
	if simDR_onGround==1 then lnavArmedForTakeoff=true end
	if simDR_radarAlt1>50 and (lnavArmedForTakeoff or B747_lnav_capture_now(fmsO)) then
		B747DR_ap_lnav_state=2
		lnavArmedForTakeoff=false
		print("LNAV engaged")
	end
end

-- [P14] While LNAV is not engaged (off, or only armed) the FMC sequences the active fix as the 747 passes abeam it:
-- past its leg's wayline, the perpendicular to the leg's inbound course at the fix, within LNAV_ABEAM_SEQUENCE_MAX_NM
-- of the leg (Honeywell's FMC in heading mode keeps track of the active leg within 21 nm of the path and makes the
-- next leg active as the aircraft passes the wayline: US 7,024,287), not at the turn's lead, which LNAV flies only
-- while it steers. On the leg that is at the fix, where the turn's bisector crosses it; 15 nm off, abeam the fix; 25 nm
-- off, never. A leg flown direct to its fix (no course from a fix: after VECTORS, an altitude leg's end, a hold) runs
-- from where the 747 was when the fix became active (B747_lnav_note_sequenced: where the altitude was reached...), as
-- a real DF leg from where it began: its wayline that leg's (passed only within 0.3 or 0.5 nm, a fix passed 0.75-1.24 nm
-- off stayed active, and LNAV pushed then turned back to it: a review); without such a start, as the anticipation
-- passes it, without the lead. In HDG SEL along the leg to a +90 deg turn at 480 kt (its
-- lead 9.7 nm) the FMC sequenced the fix 2.8 nm before it, once the 747 was 2 nm off the turn's arc (6.1 nm before it
-- 1.5 nm left of the leg), and LNAV pushed then had a leg starting ahead of the 747 to capture.
local LNAV_ABEAM_SEQUENCE_MAX_NM=21
local function B747_lnav_passed_abeam(fmsO,i)
	local fix=fmsO[i]
	local legStart=B747_lnav_leg_start(fmsO,i)
	local inCourse,directTo=B747_lnav_inbound_course(fmsO,i)
	local dToFix=getDistance(simDR_latitude,simDR_longitude,fix[5],fix[6])
	if directTo and lnavSequenced.current==i and lnavSequenced.lat~=nil
		and getDistance(lnavSequenced.lat,lnavSequenced.lon,fix[5],fix[6])>=LNAV_PATH_MIN_LEG_NM then
		legStart={0,0,0,0,lnavSequenced.lat,lnavSequenced.lon}
		inCourse=(getHeading(fix[5],fix[6],legStart[5],legStart[6])+180)%360
	elseif directTo or not B747_lnav_leg_has_course(legStart,fix) then
		local trackError=math.abs(getHeadingDifference(getHeading(simDR_latitude,simDR_longitude,fix[5],fix[6]),
			simDR_ground_track_true))
		return (trackError<=LNAV_DIRECT_TO_TRACK_DEG and dToFix<=LNAV_DIRECT_TO_PASS_NM)
			or (trackError>LNAV_DIRECT_TO_TRACK_DEG and dToFix<=LNAV_DIRECT_TO_ABEAM_NM)
	end
	if dToFix>0.01
		and math.abs(getHeadingDifference(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude),inCourse))>90 then
		return false
	end
	local xtk=B747_afds_helpers.signed_cross_track_nm(legStart[5],legStart[6],fix[5],fix[6],simDR_latitude,
		simDR_longitude,getDistance,getHeading)
	return xtk~=nil and math.abs(xtk)<=LNAV_ABEAM_SEQUENCE_MAX_NM
end

function B747_getCurrentWayPoint_function(fmsO)
	local current=B747DR_fmscurrentIndex
	local count=table.getn(fmsO)
	B747_lnav_sequenced_engaged(fmsO,current)
	-- the end of an altitude-terminated leg is reached at its altitude: X-Plane, whose sequencing the
	-- 747 overrides, keeps that point just ahead of the aircraft after it
	if current<count and B747_altitude_leg_reached(fmsO[current]) then
		B747_lnav_sequence_to(current+1, "past the altitude leg end "..tostring(fmsO[current][8]))
		return
	end
	-- the fix before such legs passed with their altitude reached: on to the fix after them (the leg
	-- search finds no leg to it when it lies behind, and the 747 turned back to the passed fix); the
	-- departure runway (after the origin airport) counts as passed in the air
	if current>1 and current<count-1 and B747_altitude_leg_reached(fmsO[current+1]) then
		local fix=fmsO[current]
		local legStart=B747_lnav_leg_start(fmsO,current)
		local dToFix=getDistance(simDR_latitude,simDR_longitude,fix[5],fix[6])
		local legLength=getDistance(legStart[5],legStart[6],fix[5],fix[6])
		local passed=dToFix<0.3 or (current==2 and fmsO[1][2]==1)
		if not passed and legLength>0.1 then
			local dFromStart=getDistance(simDR_latitude,simDR_longitude,legStart[5],legStart[6])
			passed=getTriSpaceSolver(legLength,dFromStart,dToFix)[1]>=legLength
		end
		if passed then
			local nextIndex=current+1
			while nextIndex<count and B747_altitude_leg_reached(fmsO[nextIndex]) do
				nextIndex=nextIndex+1
			end
			B747_lnav_sequence_to(nextIndex, "past "..tostring(fix[8]).." and the altitude legs after it")
			return
		end
	end
	if simDR_radarAlt1<1000 and simDR_vvi_fpm_pilot < 500.0 then return end --surpress during final/on ground
	if (B747DR_fmscurrentIndex>1 and fmsO[B747DR_fmscurrentIndex-1][8]=="PPOS") then
		simDR_override_fms_progress=0
		--print("simDR_override_fms_progress B747DR_fmscurrentIndex="..B747DR_fmscurrentIndex)
		B747_getCurrentWayPoint_default(fmsO)
		return
	end
	simDR_override_fms_progress=1
	local best=0
	local bestOffTrack=100 --can offset 99 miles
	local bestheadingDiff=180
	local minPhaseLeg=2
	local maxPhaseLeg=(table.getn(fmsO)-2)
	if B747DR_fmscurrentIndex<3 then bestheadingDiff=110 end
	local dToAP=100
	if maxPhaseLeg>3 and fmsO[table.getn(fmsO)][2] == 1 and B747DR_fmscurrentIndex>1 then
		dToAP=getDistance(simDR_latitude,simDR_longitude,fmsO[table.getn(fmsO)][5],fmsO[table.getn(fmsO)][6])
		local dToAP2=getDistance(fmsO[B747DR_fmscurrentIndex][5],fmsO[B747DR_fmscurrentIndex][6],fmsO[table.getn(fmsO)][5],fmsO[table.getn(fmsO)][6])
		if dToAP<40 and dToAP2<40 then
			--print("dToAP "..dToAP)
			minPhaseLeg=math.max(B747DR_fmscurrentIndex-1,3)
			maxPhaseLeg=math.min(minPhaseLeg+4,(table.getn(fmsO)-2))
			bestheadingDiff=120
		end
	end
	-- the legs up to an altitude-terminated leg's end that is reached are flown: the search does not go
	-- back to them (a SID turning back over the airport matched the runway's legs again)
	for k=B747DR_fmscurrentIndex-1,2,-1 do
		if B747_altitude_leg_reached(fmsO[k]) then
			minPhaseLeg=math.max(minPhaseLeg,k+1)
			break
		end
	end
	-- [i-1b] a turn LNAV flies by its path (B747_lnav_path_at_fix, on a leg it flies by the path:
	-- B747_lnav_path_now) is sequenced at its bisector, where the FMC sequences it, while the aircraft is as near
	-- that path as the anticipation below allows; neither the anticipation nor the leg search move the fix
	-- before. The path's arc allows for the wind and so does not start where the anticipation's lead does: a
	-- 137 deg turn in a crosswind, already 2 nm into its arc at the lead, was never sequenced (the 747 flew on
	-- past the next fix). A leg LNAV steers as before (after an altitude leg's end, from VECTORS or PPOS, after
	-- a turn passed abeam) keeps the lead: flown straight at its fix, the 747 reached the bisector only at the
	-- fix (EIDW's DW129 after "(650)": 3.2 nm outside).
	local current=B747DR_fmscurrentIndex
	-- a fix listed again right after itself (a leg of no length) is passed with the one before it; not an
	-- altitude leg's end there, which is passed at its altitude
	if current>2 and current<table.getn(fmsO)-1 and B747_lnav_leg_supports_preemption(fmsO[current])
		and B747_afds_helpers.altitude_leg_end_ft(fmsO[current])==nil
		and not B747_lnav_leg_has_course(B747_lnav_leg_start(fmsO,current),fmsO[current]) then
		B747_lnav_sequence_to(current+1,"listed again: "..tostring(fmsO[current][8]))
		return
	end
	-- [P14] LNAV not engaged: a fix only abeam it (B747_lnav_passed_abeam), not at its turn's lead nor its arc's
	-- bisector, and no leg search; on the leg from the origin airport or to an entry that is no fix, the leg search
	-- below without the lead, as before
	local lnavEngaged=B747DR_ap_lnav_state==2
	local abeamOnly=false
	if not lnavEngaged and current>1 and current<table.getn(fmsO)-1 and B747_lnav_leg_supports_preemption(fmsO[current])
		and tonumber(B747_lnav_leg_start(fmsO,current)[2])~=1 then
		if B747_lnav_passed_abeam(fmsO,current) then
			B747_lnav_sequence_to(current+1,"abeam "..tostring(fmsO[current][8]).." (LNAV not engaged)")
			return
		end
		abeamOnly=true
	end
	local pathFlown=false
	if lnavEngaged and current>1 and current<table.getn(fmsO)-1 and B747DR_ap_lnav_xtk_target==0
		and B747_lnav_path_now(fmsO,current)~=nil then
		local p=B747_lnav_path_parameters()
		local path=p and B747_lnav_path_at_fix(fmsO,current,p)
		if path and math.abs(path.xtk_nm)<=LNAV_MAX_PREEMPT_XTK_NM then
			if path.past_bisector then
				B747_lnav_sequence_to(current+1,"past the bisector of the turn at "..tostring(fmsO[current][8]))
				return
			end
			pathFlown=true
		end
	end
	-- the active leg's fly-by turn starts its lead before the fix (the search
	-- below looks only at the last 5 nm or third of a leg, and a 90 deg turn at
	-- cruise needs about 9 nm); not on the leg from the origin airport, nor
	-- after a direct-to or with an offset (as before)
	if lnavEngaged and not pathFlown and current>1 and current<table.getn(fmsO)-1 and B747DR_ap_lnav_xtk_target==0 then
		local fix,nextFix=fmsO[current],fmsO[current+1]
		local legStart=B747_lnav_leg_start(fmsO,current)
		local inCourse,directTo,afterAltitude=B747_lnav_inbound_course(fmsO,current)
		if tonumber(legStart[2])~=1 and B747_lnav_leg_supports_preemption(fix)
			and B747_lnav_leg_supports_preemption(nextFix) then
			local outCourse=getHeading(fix[5],fix[6],nextFix[5],nextFix[6])
			-- [P15] none for a turn of more than LNAV_FLYBY_MAX_TURN_DEG: flown by its path its fix is sequenced at the
			-- path's bisector, passed abeam abeam it (its 150 deg turn's lead sequenced it before its path began: a review)
			local lead=0
			if math.abs(getHeadingDifference(outCourse,inCourse))<=B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then
				lead=B747_lnav_turn_anticipation_nm(inCourse,outCourse)
			end
			local dToFix=getDistance(simDR_latitude,simDR_longitude,fix[5],fix[6])
			local legLength=getDistance(legStart[5],legStart[6],fix[5],fix[6])
			local due=false
			if directTo then
				-- not while still turning to the fix (a turn-back SID after its
				-- altitude); no large fly-by; passed close by
				local trackError=math.abs(getHeadingDifference(getHeading(simDR_latitude,simDR_longitude,fix[5],fix[6]),
					simDR_ground_track_true))
				if afterAltitude and math.abs(getHeadingDifference(outCourse,inCourse))>LNAV_DIRECT_TO_MAX_TURN_DEG then
					lead=0
				end
				due=(trackError<=LNAV_DIRECT_TO_TRACK_DEG and dToFix<=math.max(lead,LNAV_DIRECT_TO_PASS_NM))
					or (trackError>LNAV_DIRECT_TO_TRACK_DEG and dToFix<=LNAV_DIRECT_TO_ABEAM_NM)
			elseif legLength>0.1 then
				local dFromStart=getDistance(simDR_latitude,simDR_longitude,legStart[5],legStart[6])
				local track=getTriSpaceSolver(legLength,dFromStart,dToFix)
				local maximumPreemptXtk=math.min(LNAV_MAX_PREEMPT_XTK_NM,
					math.max(LNAV_MIN_PREEMPT_XTK_NM,legLength*LNAV_PREEMPT_XTK_LEG_FRACTION))
				due=track[1]>0 and track[2]<=maximumPreemptXtk and legLength-track[1]<=lead
			end
			if due then
				B747_lnav_sequence_to(current+1,string.format("turn anticipation %.1f nm before ",lead)..tostring(fix[8]))
				return
			end
		end
	end
	local canNew=true
	if B747DR_fmscurrentIndex>1 then
		local dToNext=getDistance(simDR_latitude,simDR_longitude,fmsO[B747DR_fmscurrentIndex][5],fmsO[B747DR_fmscurrentIndex][6])
		local legStart=B747_lnav_leg_start(fmsO,B747DR_fmscurrentIndex)
		dFromLast=getDistance(simDR_latitude,simDR_longitude,legStart[5],legStart[6])
		trackLength=getDistance(legStart[5],legStart[6],fmsO[B747DR_fmscurrentIndex][5],fmsO[B747DR_fmscurrentIndex][6])
		local track=getTriSpaceSolver(trackLength,dFromLast,dToNext)
		if track[1]<math.max(trackLength-5,trackLength*2/3) then
			canNew=false
			--print("In current track "..B747DR_fmscurrentIndex.." "..minPhaseLeg.."->"..maxPhaseLeg)
		end
		local maxError=5
		if dToAP<40 then
			if B747DR_ap_approach_mode~=0 then
				maxError=0.3
			else
				maxError=1
			end
			-- [i-1b] off the path LNAV flies (round a fly-by turn's arc: in its first half the 747 is up to
			-- R (1 - cos(turn / 2)) off the leg to the fix, and with APP armed UNABLE RNP flashed), else off the leg
			local offTrack=track[2]
			local path=B747_lnav_path_now(fmsO,B747DR_fmscurrentIndex)
			if path~=nil then offTrack=math.abs(path.xtk_nm) end
			if B747DR_ap_lnav_xtk_target>=-99 and offTrack>maxError and track[1]>math.min(5,trackLength/5) then
				B747DR_CAS_caution_status[66]=1 --its an advisory when > 40
			else
				B747DR_CAS_caution_status[66]=0
			end
		end
		
	end
	--print("Start Track Data "..minPhaseLeg.."->"..maxPhaseLeg)
	if canNew and not pathFlown and not abeamOnly then
		for i = minPhaseLeg, maxPhaseLeg, 1 do --last is always the airport, never go past last track

			local dFromLast=0.1
			local trackLength=1
			local dToNext=getDistance(simDR_latitude,simDR_longitude,fmsO[i][5],fmsO[i][6])

			local legStart=nil
			if i>1 then
				legStart=B747_lnav_leg_start(fmsO,i)
				dFromLast=getDistance(simDR_latitude,simDR_longitude,legStart[5],legStart[6])
				trackLength=getDistance(legStart[5],legStart[6],fmsO[i][5],fmsO[i][6])
			else
				trackLength=dToNext+0.11
			end

			
			
			-- a leg to an altitude-terminated leg's end is done once its altitude is reached (X-Plane may
			-- keep that point just ahead of the aircraft, which would make it the leg flown)
			if trackLength>0.1 and not B747_altitude_leg_reached(fmsO[i]) then
				local track=getTriSpaceSolver(trackLength,dFromLast,dToNext)
				
				local thisHeading=0
				if i>1 then
					thisHeading=getHeading(legStart[5],legStart[6],fmsO[i][5],fmsO[i][6])
				else
					thisHeading=getHeading(simDR_latitude,simDR_longitude,fmsO[i][5],fmsO[i][6])
					track[2]=dToNext
				end
				local headingmatch=math.abs(getHeadingDifference(simDR_true_heading,thisHeading))
				--[[if headingmatch>45 then
					track[1]=track[1]-3
				end]]--
				--print("Track Data "..fmsO[i][8].." "..track[1].." "..track[2].." "..dFromLast.." "..dToNext.." "..trackLength.." "..headingmatch)
				if track[1]>0 and track[1]<trackLength and track[2]<100 and (headingmatch<bestheadingDiff) then
					--print("In Track to waypoint="..i)
					if track[2]<bestOffTrack then
						bestOffTrack=track[2]
						
						local nextHeading=getHeading(fmsO[i][5],fmsO[i][6],fmsO[i+1][5],fmsO[i+1][6])
						-- a leg flown direct to its fix is anticipated above; none while LNAV is not engaged
						local pemptNext=0
						if i>1 and lnavEngaged then
							local inCourse,directTo=B747_lnav_inbound_course(fmsO,i)
							if not directTo and math.abs(getHeadingDifference(nextHeading,inCourse))
								<=B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then
								pemptNext=B747_lnav_turn_anticipation_nm(inCourse,nextHeading)
							end
						end
						local maximumPreemptXtk=math.min(LNAV_MAX_PREEMPT_XTK_NM,
							math.max(LNAV_MIN_PREEMPT_XTK_NM,trackLength*LNAV_PREEMPT_XTK_LEG_FRACTION))
						local canPreempt=B747_lnav_leg_supports_preemption(fmsO[i])
							and B747_lnav_leg_supports_preemption(fmsO[i+1]) and track[2]<=maximumPreemptXtk
						if canPreempt and track[1]>math.max((trackLength-pemptNext),0.5) then
							--print("End of Track to waypoint "..headingChange.." "..pemptNext)
							best=i+1
							bestheadingDiff=headingmatch
						else
							--print("End of Track to waypoint "..headingChange.." "..pemptNext)
							best=i
							bestheadingDiff=headingmatch
						end
					end
				end
			end
		end
		--if best==1 then best=2 end
		
		--print("best Track to waypoint="..best.." / "..bestOffTrack)
		-- an altitude-terminated leg's end whose altitude is reached is no leg to stop at
		local maxAdvance=LNAV_MAX_AUTOMATIC_SEQUENCE_ADVANCE_LEGS
		local skipIndex=B747DR_fmscurrentIndex+1
		while skipIndex<best and skipIndex<=B747DR_fmscurrentIndex+maxAdvance do
			if B747_altitude_leg_reached(fmsO[skipIndex]) then
				maxAdvance=maxAdvance+1
			end
			skipIndex=skipIndex+1
		end
		if B747DR_ap_lnav_xtk_target>-99 and B747DR_fmscurrentIndex>0
			and best>B747DR_fmscurrentIndex+maxAdvance then
			best=B747DR_fmscurrentIndex
		end
		if best>0 and (best>B747DR_fmscurrentIndex or best<B747DR_fmscurrentIndex-1) and B747DR_fmscurrentIndex ~=best then
			B747DR_fms_setCurrent = best
			B747DR_fmscurrentIndex = best
			if B747DR_ap_lnav_state == 2 then
				B747DR_ap_lnavHeading_mode = best
			end
			
			print("B747DR_fmscurrentIndex="..best)
			setVNAVState("recalcAfter", best)
		elseif B747DR_fmscurrentIndex == 0 and maxPhaseLeg>2 and fmsO[2][2]~=2048 then
			B747DR_fmscurrentIndex = 2
			B747DR_fms_setCurrent = 2
			B747DR_ap_lnav_xtk_target=0 --target no track offset
			--print("B747DR_fmscurrentIndex="..1)
			setVNAVState("recalcAfter", 1)
		end
	end
	if B747DR_ap_lnavHeading_mode>0 and best<B747DR_ap_lnavHeading_mode then
		best=B747DR_ap_lnavHeading_mode
	elseif B747DR_ap_lnavHeading_mode ~=B747DR_fmscurrentIndex and B747DR_fmscurrentIndex>1 and B747DR_ap_lnav_state == 2 then
		B747DR_ap_lnavHeading_mode = B747DR_fmscurrentIndex
	end
end

-- The cross-track error every frame (laminar/B747/autopilot/lnav/xtk_error,
-- the PROGRESS page's XTK ERROR): the signed distance from the active leg,
-- + right of it, from the offset track while an offset is flown; 0 without a
-- leg. It was written only by the leg search, which runs near a leg's end.
function B747_lnav_update_xtk(fmsO)
	local current=B747DR_fmscurrentIndex
	local fix=fmsO[current]
	if current<2 or fix==nil then
		B747DR_ap_lnav_xtk_error=0
		return
	end
	-- from the path LNAV flies (the arc in a fly-by turn), else from the active leg; [P14] while LNAV is not engaged
	-- not from the active fix's own path past its turn's bisector: the FMC then sequences the fix only abeam it, and
	-- until then the active leg is the leg to it (the path's arc or next leg gave the next leg's side and size, and the
	-- kit's rejoin intercepted away from the active leg: a review). Engaged, LNAV steers that path also past the
	-- bisector more than LNAV_MAX_PREEMPT_XTK_NM off it, where the fix is not sequenced (from the leg the XTK jumped
	-- to the other side of the path and grew to 27 nm: a review).
	local path,pathFix=B747_lnav_path_now(fmsO,current)
	if path~=nil and not (pathFix==fix and path.past_bisector and B747DR_ap_lnav_state~=2) then
		B747DR_ap_lnav_xtk_error=path.xtk_nm
		return
	end
	local legStart=B747_lnav_leg_start(fmsO,current)
	local xtk=B747_afds_helpers.signed_cross_track_nm(legStart[5],legStart[6],fix[5],fix[6],
		simDR_latitude,simDR_longitude,getDistance,getHeading)
	if xtk==nil then return end
	-- offsets are -99 (L99) to 99 as LNAV steers them; -100 is a direct-to
	if B747DR_ap_lnav_xtk_target>=-99 then
		xtk=xtk-B747DR_ap_lnav_xtk_target
	end
	B747DR_ap_lnav_xtk_error=xtk
end

-- A fix LNAV sequenced early for its turn stays VNAV's fix (B747DR_vnav_hold_index) until the aircraft
-- is past the turn's bisector, where the FMC sequences it: VNAV's targets were the active fix's, so at
-- the start of the turn they dropped to the next fix's and the descent went on through the passed fix's
-- constraint (EHAM's NIRSI, at or above FL055, passed 95 ft low). A fix is held when the active one
-- moved on from it by one entry within its turn's lead (plus LNAV_VNAV_HOLD_MARGIN_NM) of it, not a
-- direct-to from afar; it is let go past the bisector, as the courses were then, or once the aircraft is
-- half as far again from it (vectored away).
local LNAV_VNAV_HOLD_MARGIN_NM=1.0
local lnavHoldLastIndex=0
local lnavHoldIndex=0
local lnavHoldInCourse=0
local lnavHoldOutCourse=0
local lnavHoldMaxNm=0
-- [B-14] The turn VNAV's descent path goes through (setDescentVSpeed, afds.vnav_turn_distance_nm): {fix (its index),
-- in_course, out_course, lead_nm (B747_lnav_turn_anticipation_nm), start_nm (the distance to the fix when taken),
-- released (past the bisector), lat, lon and next_lat, next_lon (where the fix and the one after it were), prev (the
-- turn before, on a short leg), fade (out of VNAV's path while LNAV does not fly the turns; fade_lat, fade_lon)}: the
-- active fix's from its lead (plus LNAV_VNAV_HOLD_MARGIN_NM) before it (B747_lnav_active_turn), kept through its
-- sequence - at the bisector for a turn LNAV flies by its path, where it is released, or at the turn's start for a held
-- fix, released at the bisector - and once released until the turn has ended (B747_lnav_turn_ended) and the next fix's
-- begins; nil without a turn and once vectored away. Taken only from the held fix's sequence, the path ran straight to
-- a fix LNAV sequences at the bisector through the first half of its turn and stepped 245-290 ft there (NETOM; review
-- 27). A route edit that moves the fix or the one after it, or puts another fix in their place
-- (B747_lnav_turn_on_route), ends the turn and a hold of its fix, and the new route's is taken: latched by its index,
-- the turn kept the old courses and lead, and with NIRSI moved 2.5 nm before NETOM the path stepped +303 ft after the
-- bisector and -142 ft at the old turn's end (review 27b MINOR 1). Only a turn LNAV flies is taken - LNAV engaged with
-- no offset and no direct-to (B747_lnav_flies_turns), on its path - and it ends, before the fix, once the aircraft is
-- vectored more than the margin farther from it than where it was taken. While LNAV does not fly the turns (HDG SEL,
-- the kit's DIRECT TO) the aircraft's distance off the turn's path (B747_lnav_turn_path_offset) fades the turn out of
-- VNAV's path (fade, B747_vnav_turn_distance): taken without LNAV, kept in HDG SEL and released at a sequence abeam the
-- fix, it put the path about 170 ft high behind NETOM flown straight past it (review 27b MINOR 3); ended at HDG SEL
-- whatever the 747 then flew, the path ran straight to the fix while the 747 turned on round the arc and stepped
-- 740-820 ft where the fix was sequenced abeam (review 28 MAJOR 1); ended 0.5 nm off LNAV's path, it stepped 330-500 ft
-- there (review 29 MAJOR 1). With a metatable, as B747_route_constraints: XTLua copies a global table without one into
-- a namespace of its own, whose read of a missing index recurses until the stack overflows.
B747_lnav_vnav_turn=nil
-- The turn at fmsO[k] for VNAV's path, taken distance nm from the fix (B747_lnav_vnav_turn's form)
local function B747_lnav_new_vnav_turn(fmsO,k,inCourse,outCourse,lead,distance)
	return setmetatable({fix=k,in_course=inCourse,out_course=outCourse,lead_nm=lead,start_nm=distance,released=false,
		lat=fmsO[k][5],lon=fmsO[k][6],next_lat=fmsO[k+1][5],next_lon=fmsO[k+1][6]},{})
end
-- Whether t's fix and the one after it are still where they were when it was taken
local function B747_lnav_turn_on_route(fmsO,t)
	local fix,nextFix=fmsO[t.fix],fmsO[t.fix+1]
	return fix~=nil and nextFix~=nil and fix[5]==t.lat and fix[6]==t.lon and nextFix[5]==t.next_lat
		and nextFix[6]==t.next_lon
end
-- Whether fmsO[k]'s turn is one VNAV's path goes through: a fly-by of at most LNAV_FLYBY_MAX_TURN_DEG between two fixes
-- with courses (a capped turn's path is no tangent arc); its inbound and outbound courses and its lead
local function B747_lnav_vnav_turn_at(fmsO,k)
	local fix,nextFix=fmsO[k],fmsO[k+1]
	if k<2 or fix==nil or nextFix==nil or not B747_lnav_leg_supports_preemption(fix)
		or not B747_lnav_leg_supports_preemption(nextFix) or tonumber(fix[2])==1
		or B747_afds_helpers.altitude_leg_end_ft(fix)~=nil then
		return nil
	end
	local inCourse=B747_lnav_inbound_course(fmsO,k)
	local outCourse=getHeading(fix[5],fix[6],nextFix[5],nextFix[6])
	local turn=math.abs((outCourse-inCourse+540)%360-180)
	if turn<1 or turn>B747_afds_helpers.LNAV_FLYBY_MAX_TURN_DEG then return nil end
	return inCourse,outCourse,B747_lnav_turn_anticipation_nm(inCourse,outCourse)
end
-- Whether LNAV flies the route's fly-by turns by their path: engaged, with no offset and no direct-to (as
-- B747_getCurrentWayPoint_function's path and anticipation take them)
local function B747_lnav_flies_turns()
	return B747DR_ap_lnav_state==2 and B747DR_ap_lnav_xtk_target==0
end
-- The active fix's turn worked out last (B747_lnav_active_turn): the fix's index and position, when (t) and its lead
-- (0 without a turn VNAV's path goes through). Farther from the fix than that lead, the margin and
-- LNAV_VNAV_TURN_LOOK_NM, it is worked out again only every LNAV_VNAV_TURN_LOOK_SEC: its courses, the wind and the
-- anticipation were worked out every frame of the cruise (review 27b NIT).
local LNAV_VNAV_TURN_LOOK_NM=2.0
local LNAV_VNAV_TURN_LOOK_SEC=5.0
local lnavTurnLook={fix=0,lat=nil,lon=nil,t=0,lead=0}
-- The active fix's turn once within its lead (plus the margin) of it, LNAV flying the turns and on its path (within
-- LNAV_MAX_PREEMPT_XTK_NM), latched when first taken (t, if it is that fix's and not released); else nil
local function B747_lnav_active_turn(fmsO,current,t)
	if t~=nil and t.fix==current and not t.released then return t end
	if not B747_lnav_flies_turns() or math.abs(tonumber(B747DR_ap_lnav_xtk_error) or 0)>LNAV_MAX_PREEMPT_XTK_NM then
		return nil
	end
	local fix=fmsO[current]
	if fix==nil then return nil end
	local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
	local look=lnavTurnLook
	local now=tonumber(simDRTime)
	if now~=nil and look.fix==current and look.lat==fix[5] and look.lon==fix[6] and now>=look.t
		and now-look.t<=LNAV_VNAV_TURN_LOOK_SEC and distance>look.lead+LNAV_VNAV_HOLD_MARGIN_NM+LNAV_VNAV_TURN_LOOK_NM then
		return nil
	end
	local inCourse,outCourse,lead=B747_lnav_vnav_turn_at(fmsO,current)
	look.fix,look.lat,look.lon,look.t,look.lead=current,fix[5],fix[6],now or 0,lead or 0
	if inCourse==nil then return nil end
	if distance>lead+LNAV_VNAV_HOLD_MARGIN_NM then return nil end
	return B747_lnav_new_vnav_turn(fmsO,current,inCourse,outCourse,lead,distance)
end
-- Whether the aircraft is past the end of t's turn: its lead along the outbound course past the fix
local function B747_lnav_turn_ended(fmsO,t)
	local fix=fmsO[t.fix]
	if fix==nil then return true end
	local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
	local bearing=math.rad(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude))
	local course=math.rad(t.out_course)
	return distance*math.cos(bearing-course)>=t.lead_nm
end
-- How far the aircraft is off t's fly-by path (B747_lnav_path_at_fix: the inbound leg, the arc LNAV flies, the
-- outbound leg), or off the carried turn's (prev) inbound leg and arc if nearer, nm; 0 where that cannot be told (no
-- such path: VNAV's own cross-track blend then). Taken from t's path alone, on a short leg with the 747 still on
-- prev's arc it was 0.5 nm; prev's outbound leg runs on through t's fix, and taken from it too, the 747 flown straight
-- on past t's arc kept t's turn 0.9 nm longer.
local function B747_lnav_turn_path_offset(fmsO,t)
	local p=B747_lnav_path_parameters()
	if p==nil then return 0 end
	local path=B747_lnav_path_at_fix(fmsO,t.fix,p)
	local off=path and math.abs(path.xtk_nm) or 0
	if t.prev~=nil then
		local before=B747_lnav_path_at_fix(fmsO,t.prev.fix,p)
		if before~=nil and before.element~="out" then off=math.min(off,math.abs(before.xtk_nm)) end
	end
	return off
end
function B747_lnav_update_vnav_hold(fmsO)
	local current=B747DR_fmscurrentIndex
	-- a route edit at the turn's fix or the next one: the turn and a hold of its fix end
	local edited=B747_lnav_vnav_turn
	if edited~=nil and not B747_lnav_turn_on_route(fmsO,edited) then
		if lnavHoldIndex==edited.fix then lnavHoldIndex=0 end
		B747_lnav_vnav_turn=nil
	elseif edited~=nil and edited.prev~=nil and not B747_lnav_turn_on_route(fmsO,edited.prev) then
		-- the turn carried on ends: a new table without it, so that VNAV's path takes out what it gave back
		-- (B747_vnav_path_continuity goes by the table); dropped from the table in place, the path stepped -105 ft at
		-- once with NIRSI nudged 1 m on a 3.2 nm leg (review 28)
		local t=setmetatable({},{})
		for key,value in pairs(edited) do
			if key~="prev" then t[key]=value end
		end
		B747_lnav_vnav_turn=t
	end
	-- the aircraft vectored away from the fix before its turn: the turn ends. The turn fades out of VNAV's path
	-- (fade, B747_vnav_turn_distance) towards its target - 0 while LNAV flies the turns, else the aircraft's distance off
	-- the turn's path from VNAV_TURN_FADE_FROM_NM over VNAV_TURN_FADE_NM - by at most the distance flown over
	-- VNAV_TURN_FADE_RATE_NM, and ends once it has faded out. Set at once from the distance off the path, it stepped where
	-- LNAV engaged or let go off the path (-123 ft 1 nm off NETOM's, -381 ft off a 110 deg turn's; review 30 MAJOR 1).
	local taken=B747_lnav_vnav_turn
	if taken~=nil then
		local fix=fmsO[taken.fix]
		local away=not taken.released
			and getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)>taken.start_nm+LNAV_VNAV_HOLD_MARGIN_NM
		local target=0
		if not B747_lnav_flies_turns() then
			target=B747_afds_helpers.clamp((B747_lnav_turn_path_offset(fmsO,taken)-B747_afds_helpers.VNAV_TURN_FADE_FROM_NM)
				/B747_afds_helpers.VNAV_TURN_FADE_NM,0,1)
		end
		local flown=0
		if taken.fade_lat~=nil then
			flown=getDistance(taken.fade_lat,taken.fade_lon,simDR_latitude,simDR_longitude)
		end
		taken.fade_lat,taken.fade_lon=simDR_latitude,simDR_longitude
		local most=flown/B747_afds_helpers.VNAV_TURN_FADE_RATE_NM
		local fade=taken.fade or 0
		taken.fade=fade+B747_afds_helpers.clamp(target-fade,-most,most)
		if away or taken.fade>=1 then B747_lnav_vnav_turn=nil end
	end
	if current~=lnavHoldLastIndex then
		local passed=lnavHoldLastIndex
		lnavHoldLastIndex=current
		lnavHoldIndex=0
		-- the passed fix's turn, taken while it was the active one, stays through its sequence
		local t=B747_lnav_vnav_turn
		if t==nil or t.fix~=passed or current~=passed+1 then t=nil end
		B747_lnav_vnav_turn=t
		local fix=fmsO[passed]
		local nextFix=fmsO[current]
		if current==passed+1 and passed>=2 and nextFix~=nil and B747_lnav_leg_supports_preemption(fix)
			and B747_lnav_leg_supports_preemption(nextFix) and tonumber(fix[2])~=1
			and B747_afds_helpers.altitude_leg_end_ft(fix)==nil then
			local inCourse=B747_lnav_inbound_course(fmsO,passed)
			local outCourse=getHeading(fix[5],fix[6],nextFix[5],nextFix[6])
			local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
			local lead=B747_lnav_turn_anticipation_nm(inCourse,outCourse)
			if distance<=lead+LNAV_VNAV_HOLD_MARGIN_NM then
				lnavHoldIndex=passed
				lnavHoldInCourse=inCourse
				lnavHoldOutCourse=outCourse
				lnavHoldMaxNm=1.5*distance+LNAV_VNAV_HOLD_MARGIN_NM
				if B747_lnav_vnav_turn==nil and B747_lnav_flies_turns() then
					B747_lnav_vnav_turn=B747_lnav_new_vnav_turn(fmsO,passed,inCourse,outCourse,lead,distance)
				end
			end
		end
		-- not held: sequenced at (or past) the bisector
		if B747_lnav_vnav_turn~=nil and lnavHoldIndex==0 then B747_lnav_vnav_turn.released=true end
	end
	if lnavHoldIndex>0 then
		local fix=fmsO[lnavHoldIndex]
		if fix==nil then
			lnavHoldIndex=0
			B747_lnav_vnav_turn=nil
		else
			local distance=getDistance(fix[5],fix[6],simDR_latitude,simDR_longitude)
			local bearing=math.rad(getHeading(fix[5],fix[6],simDR_latitude,simDR_longitude))
			if distance>lnavHoldMaxNm then
				lnavHoldIndex=0
				B747_lnav_vnav_turn=nil
			elseif B747_afds_helpers.past_turn_bisector(distance*math.sin(bearing),
				distance*math.cos(bearing),lnavHoldInCourse,lnavHoldOutCourse)~=false then
				lnavHoldIndex=0
				if B747_lnav_vnav_turn~=nil then B747_lnav_vnav_turn.released=true end
			end
		end
	end
	-- without a held fix: the passed fix's turn until it has ended, and the active fix's from its lead, also before the
	-- passed one's has ended on a leg too short for both: it carries that one on (prev) until it has ended or its own
	-- fix is passed, what that one still gives back of its cut counting towards the distance to its fix. Taken only
	-- once the passed turn had ended, it was taken late, close to the fix, and the path stepped by up to its cut: about
	-- 375 ft at AM607's 90 deg 2.6 nm after NIRSI (review 27b MINOR 2).
	if lnavHoldIndex==0 then
		local t=B747_lnav_vnav_turn
		if t==nil or not t.released then
			B747_lnav_vnav_turn=B747_lnav_active_turn(fmsO,current,t)
		elseif B747_lnav_turn_ended(fmsO,t) then
			B747_lnav_vnav_turn=B747_lnav_active_turn(fmsO,current,nil)
		elseif t.fix+1==current then
			local nextTurn=B747_lnav_active_turn(fmsO,current,nil)
			if nextTurn~=nil then
				nextTurn.prev=t
				B747_lnav_vnav_turn=nextTurn
			end
		end
		local c=B747_lnav_vnav_turn
		if c~=nil and c.prev~=nil and (c.released or B747_lnav_turn_ended(fmsO,c.prev)) then c.prev=nil end
	end
	B747DR_vnav_hold_index=lnavHoldIndex
end

-- The constraints of the route's SID, STAR and approach (B747.70.xt.autopilot.constraints.lua), read from
-- X-Plane's CIFP when the route's idents change, a few hundred lines a frame: B747_route_constraints by
-- route index, for VNAV; laminar/B747/autopilot/vnav/procedures names the procedures found with the
-- number of their fixes on the route ("SID ENDE3J/6 STAR LAMS2A/3 APPCH I18R SUG1D/7"), "reading" while
-- the files are read. The table has a metatable: XTLua stores a global table without one as a namespace
-- of its own, whose read of a missing index recurses until the stack overflows.
B747_route_constraints=setmetatable({},{})
local routeConstraintLoader=nil
local routeConstraintSignature=""
local routeConstraintPending=false
function B747_update_route_constraints(fmsO)
	local n=table.getn(fmsO)
	local names={}
	for i=1,n do names[i]=tostring(fmsO[i][8]) end
	local signature=table.concat(names,",")
	if signature~=routeConstraintSignature then
		routeConstraintSignature=signature
		B747_route_constraints=setmetatable({},{})
		routeConstraintPending=false
		B747DR_vnav_procedures=""
		-- without a route a file being read for the one before is closed (loader_start closes it otherwise)
		if n<3 and routeConstraintLoader~=nil then B747_constraints.loader_start(routeConstraintLoader,{}) end
		if n>=3 then
			if routeConstraintLoader==nil then routeConstraintLoader=B747_constraints.new_loader() end
			local airports={}
			if fmsO[1][2]==1 then airports[table.getn(airports)+1]=names[1] end
			if fmsO[n][2]==1 then airports[table.getn(airports)+1]=names[n] end
			B747_constraints.loader_start(routeConstraintLoader,airports)
			routeConstraintPending=true
			B747DR_vnav_procedures="reading"
		end
	end
	if routeConstraintPending and B747_constraints.loader_step(routeConstraintLoader,B747_constraints.LINES_PER_STEP) then
		routeConstraintPending=false
		local result=B747_constraints.match_route(fmsO,routeConstraintLoader.records)
		B747_route_constraints=setmetatable(result.constraints,{})
		B747DR_vnav_procedures=result.summary
		print("route constraints: "..result.summary)
	end
end

-- The speed the route's constraints (B747_route_constraints) allow VNAV now (laminar/B747/autopilot/vnav/
-- constraint_speed, kt; 0 for none). In the climb a SID's at or below (or at) speed holds from the
-- departure until its fix is passed - a fix LNAV sequenced early for its turn until past the turn's
-- bisector - as the FMC keeps a climb speed constraint over the legs before its fix. In the descent a
-- STAR's or an approach's holds from its fix on (until a later one), and before it from where VNAV has
-- to start slowing to have it at the fix: (IAS - speed) at VNAV_CONSTRAINT_DECEL_KT_PER_SEC (the 747
-- slowed 0.6 kt/s on its path at idle, the descent shallowed) at the ground speed, plus
-- VNAV_CONSTRAINT_DECEL_MARGIN_NM. An at or above speed is the crew's (MCP), not VNAV's.
local VNAV_CONSTRAINT_DECEL_KT_PER_SEC=0.5
local VNAV_CONSTRAINT_DECEL_MARGIN_NM=1.0
local function B747_speed_limit_of(c,phase)
	if c~=nil and c.phase==phase and c.speed~=nil and (c.speed_desc=="-" or c.speed_desc=="@") then return c.speed end
	return nil
end
function B747_update_constraint_speed(fmsO)
	local limit=0
	local constraints=B747_route_constraints
	local active=B747DR_fmscurrentIndex
	if constraints~=nil and active>0 then
		local first=active
		local held=B747DR_vnav_hold_index or 0
		if held>0 and held<first then first=held end
		local n=table.getn(fmsO)
		if B747DR_ap_inVNAVdescent==0 then
			for i=first,n do
				local speed=B747_speed_limit_of(constraints[i],"climb")
				if speed~=nil and (limit==0 or speed<limit) then limit=speed end
			end
		else
			-- the latest fix passed with one (a fix held for its turn is passed for this)
			for i=1,math.min(active-1,n) do
				local speed=B747_speed_limit_of(constraints[i],"descent")
				if speed~=nil then limit=speed end
			end
			-- those ahead whose deceleration has begun (it stays begun: slowing shortens the distance it
			-- needs, which would let the speed go and come back)
			local gs=math.max(simDR_groundspeed*1.94384,100)
			local along=0
			local lat,lon=simDR_latitude,simDR_longitude
			for i=active,n do
				local fix=fmsO[i]
				along=along+getDistance(lat,lon,fix[5],fix[6])
				lat,lon=fix[5],fix[6]
				local c=constraints[i]
				local speed=B747_speed_limit_of(c,"descent")
				if speed~=nil then
					local decel=math.max(0,simDR_ind_airspeed_kts_pilot-speed)/VNAV_CONSTRAINT_DECEL_KT_PER_SEC*gs/3600
						+VNAV_CONSTRAINT_DECEL_MARGIN_NM
					if along<=decel then c.decelerating=true end
					if c.decelerating and (limit==0 or speed<limit) then limit=speed end
				end
				-- no deceleration starts that far before its fix
				if along>40 then break end
			end
		end
	end
	B747DR_vnav_constraint_speed=limit
end

function B747_getCurrentWayPoint_default(fmsO)
	B747DR_ap_lnavHeading_mode = 0
	for i = 1, table.getn(fmsO), 1 do
		--print("FMS j="..fmsJSON)

		if fmsO[i][10] == true then
			B747DR_fmscurrentIndex = i
			B747DR_ap_lnavHeading_mode = B747DR_fmscurrentIndex
			setVNAVState("recalcAfter", i)
			break
		end
	end
end

function B747_ap_altitude(fms)
	local currentapAlt = simDR_autopilot_altitude_ft
	B747DR_ap_alt_show_thousands = B747_ternary(B747DR_autopilot_altitude_ft > 999.9, 1.0, 0.0)
	B747DR_ap_alt_show_tenThousands = B747_ternary(B747DR_autopilot_altitude_ft > 9999.99, 1.0, 0.0)
	local vvi_status = simDR_autopilot_vs_status
	local servoStatus = simDR_autopilot_servos_on
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode

	B747DR_alt_capture_window = B747_rescale(0,200,3000,1000,math.abs(simDR_vvi_fpm_pilot))
	if simDR_pressureAlt1 < B747DR_autopilot_altitude_ft then
		if B747DR_autopilot_altitude_ft - simDR_pressureAlt1 > 400 then
			B747DR_autopilot_altitude_ft_pfd = simDR_pressureAlt1 + 400
		else
			B747DR_autopilot_altitude_ft_pfd = B747DR_autopilot_altitude_ft
		end
	else
		if simDR_pressureAlt1 - B747DR_autopilot_altitude_ft > 380 then
			B747DR_autopilot_altitude_ft_pfd = simDR_pressureAlt1 - 380
		else
			B747DR_autopilot_altitude_ft_pfd = B747DR_autopilot_altitude_ft
		end
	end

	--print("B747_ap_altitude")
	--local fms = json.decode(fmsJSON)
	-- 	if table.getn(fms)<2 or fms[table.getn(fms)][2] ~= 1 then
	-- 	  B747DR_ap_vnav_state=0
	-- 	  return
	-- 	end --no nav
	if (B747BR_totalDistance>0 and B747BR_tod >0) and (
		(B747DR_ap_vnav_pause > 1 and B747BR_totalDistance <= B747DR_ap_vnav_pause) or
			(B747DR_ap_vnav_pause == 1 and B747BR_totalDistance - B747BR_tod <= 1))
	 then
		B747DR_ap_vnav_pause = 0
		simCMD_pause:once()
	end
	if B747DR_ap_vnav_state > 0 or B747DR_ap_lnav_state>0 then
		if table.getn(fms) < 2 or fms[table.getn(fms)][2] ~= 1 then
			print("Cancel LNAV/VNAV " .. table.getn(fms))
			B747DR_fmc_notifications[54] = 1
			B747DR_ap_vnav_state = 0
			B747DR_ap_lnav_state = 0
			--B747DR_ap_thrust_mode = 0
		end --no vnav

	--computeVNAVAlt(fms)
	end
end
--OLD button functions
--[[

]]
function B747_ap_appr_mode_beforeCMDhandler(phase, duration)
	if phase == 0 then
		--simCMD_autopilot_appr_mode:once()
		B747CMD_fdr_log_app:once()
		B747_ap_button_switch_position_target[9] = 1
		if B747DR_ils_dots ==0 then
			B747DR_fmc_notifications[40]=1
			return;
		else
			B747DR_fmc_notifications[40]=0
		end
		--simCMD_autopilot_roll_center_sync_mode:once()
		local diff = simDRTime - B747DR_ap_lastCommand
		--if diff>0.5 then
		if B747DR_ap_approach_mode <= 0 then
			B747DR_ap_approach_mode = 1
			if (B747DR_ap_cmd_L_mode ==1 or B747DR_ap_cmd_C_mode ==1 or B747DR_ap_cmd_R_mode==1) and simDR_radarAlt1>1500 then
				B747DR_ap_cmd_L_mode=1
				B747DR_ap_cmd_C_mode=1
				B747DR_ap_cmd_R_mode=1
			end
			print("arm APP approach")
		elseif B747DR_autopilot_gs_status ~= 2 and B747DR_autopilot_nav_status ~= 2 then
			B747DR_ap_approach_mode = 0
		end

		B747DR_ap_lastCommand = simDRTime
		-- leave the MCP heading at the crew selection: HDG SEL keeps flying it while LOC is armed
	elseif phase == 2 then
		B747_ap_button_switch_position_target[9] = 0 -- SET THE LOC SWITCH ANIMATION TO "OUT"
	end
end

function B747_ap_switch_loc_mode_CMDhandler(phase, duration)
	if phase == 0 then
		--simCMD_autopilot_nav_mode:once()
		B747CMD_fdr_log_loc:once()
		B747_ap_button_switch_position_target[8] = 1
		if B747DR_ils_dots ==0 then
			B747DR_fmc_notifications[40]=1
			return;
		else
			B747DR_fmc_notifications[40]=0
		end
		local diff = simDRTime - B747DR_ap_lastCommand
		--if diff>0.5 then
		if B747DR_ap_approach_mode >= 0 then
			B747DR_ap_approach_mode = -1

			print("arm LOC approach")
		--else
		--	B747DR_ap_approach_mode=0
		end
		--end
		B747DR_ap_lastCommand = simDRTime
	elseif phase == 2 then
		B747_ap_button_switch_position_target[8] = 0 -- SET THE LOC SWITCH ANIMATION TO "OUT"
	end
end

B747CMD_autopilot_appr_mode =
	deferred_command("laminar/B747/autopilot/approach", "APP Switch", B747_ap_appr_mode_beforeCMDhandler)
B747CMD_ap_switch_loc_mode =
	deferred_command(
	"laminar/B747/autopilot/button_switch/loc_mode",
	"A/P Localizer Mode Switch",
	B747_ap_switch_loc_mode_CMDhandler
)
----- APPROACH MODE ---------------------------------------------------------------------

function B747_ap_appr_mode()
	local diff = simDRTime - B747DR_ap_lastCommand
	local appRefreshnav = simDR_autopilot_nav_status
	local appRefreshgs = simDR_autopilot_gs_status
	if B747DR_ap_approach_mode ~= 0 then --only if we'll need it
		local refreshheading = simDR_autopilot_heading_status
	end
	--reactivate LNAV if required

	if diff < 0.2 then
		return
	end

	if
		B747DR_ap_approach_mode ~= 0 and simDR_radarAlt1 < 1500 and B747DR_autopilot_nav_status == 2 and
		B747DR_autopilot_gs_status == 2 and
			(B747DR_ap_cmd_L_mode == 1 or B747DR_ap_cmd_C_mode == 1 or B747DR_ap_cmd_R_mode == 1)
	 then
		if B747DR_hyd_sys_pressure_3>1000 then
			B747DR_ap_cmd_L_mode = 1
		end
		if B747DR_hyd_sys_pressure_1>1000 then
			B747DR_ap_cmd_C_mode = 1
		end
		if B747DR_hyd_sys_pressure_2>1000 then
			B747DR_ap_cmd_R_mode = 1
		end
	end
	--print(B747DR_hyd_sys_pressure_1.." "..B747DR_hyd_sys_pressure_2.." "..B747DR_hyd_sys_pressure_3.." "..B747DR_ap_cmd_L_mode.." "..B747DR_ap_cmd_C_mode.." "..B747DR_ap_cmd_R_mode)
	if B747DR_hyd_sys_pressure_3<1000 then
		B747DR_ap_cmd_L_mode = 0
	end
	if B747DR_hyd_sys_pressure_1<1000 then
		B747DR_ap_cmd_C_mode = 0
	end
	if B747DR_hyd_sys_pressure_2<1000 then
		B747DR_ap_cmd_R_mode = 0
	end
	if B747DR_ap_approach_mode == 0 then
		--[[if simDR_autopilot_gs_status > 0 then
			simCMD_autopilot_glideslope_mode:once() -- CANX GLIDESLOPE MODE
			B747DR_ap_lastCommand = simDRTime
			return
		end
		if simDR_autopilot_nav_status > 0 then
			simCMD_autopilot_nav_mode:once() --DEACTIVATE LOC
			B747DR_ap_lastCommand = simDRTime
			return
		end]]--
		if simDR_autopilot_nav_status~=0 or simDR_autopilot_gs_status~=0 then
			B747DR_ap_lastCommand = simDRTime
		end
		simDR_autopilot_nav_status=0
		simDR_autopilot_gs_status=0

		return
	end -- no approach mode enabled
	local diffap = getHeadingDifference(simDR_radio_nav_obs_deg[0], simDR_AHARS_heading_deg_pilot)
	if diffap > -120 and diffap < 120 then --can really arm the mode
		if B747DR_ap_approach_mode == -1 then --WANT LOC
			if simDR_autopilot_nav_status == 0 or simDR_autopilot_gs_status > 0 then
				--simCMD_autopilot_nav_mode:once() --ACTIVATE LOC
				simDR_autopilot_nav_status=1
				simDR_autopilot_gs_status=0

				B747DR_ap_lastCommand = simDRTime

			end
		elseif B747DR_ap_approach_mode == 1 then --WANT APP
			if simDR_autopilot_gs_status == 0 and simDR_radarAlt1 < 3500 then
				print("simCMD_autopilot_appr_mode in B747DR_ap_approach_mode=1")
				--simCMD_autopilot_appr_mode:once() --ACTIVATE APP
				simDR_autopilot_nav_status=1
				simDR_autopilot_gs_status=1
				B747DR_ap_lastCommand = simDRTime
			end
		end
	elseif simDR_autopilot_nav_status > 0 then
		--[[if simDR_autopilot_gs_status > 0 then
			print("simCMD_autopilot_appr_mode in elseif")
			simCMD_autopilot_appr_mode:once() --DEACTIVATE APP
			B747DR_ap_lastCommand = simDRTime
		else
			simCMD_autopilot_nav_mode:once() --DEACTIVATE LOC
			B747DR_ap_lastCommand = simDRTime
		end]]--
		simDR_autopilot_nav_status=0
		simDR_autopilot_gs_status=0
		B747DR_ap_lastCommand = simDRTime
	elseif simDR_autopilot_gs_status > 0 then
		--simCMD_autopilot_glideslope_mode:once() -- CANX GLIDESLOPE MODE
		simDR_autopilot_nav_status=0
		simDR_autopilot_gs_status=0
		B747DR_ap_lastCommand = simDRTime
	end
	if simDR_onGround == 1 then
		print("simDR_onGround to B747DR_ap_approach_mode=0")
		B747DR_ap_approach_mode = 0
	end

	if (B747DR_ap_lnav_state == 2 or (B747DR_ap_lnav_state == 1 and simDR_onGround == 1))
		and simDR_autopilot_heading_status == 0 and simDR_autopilot_nav_status ~= 2 then
		print("simCMD_autopilot_heading_select in appr_mode")
		simCMD_autopilot_heading_select:once()
		B747DR_ap_ATT = 0.0
		B747DR_ap_lastCommand = simDRTime
	end
end



----- FLIGHT MODE ANNUNCIATORS ----------------------------------------------------------

dofile("B747.autoland.lua")
dofile("B747.70.xt.autopilot.monitor.lua")
local apWasOn=0
-- TO/GA roll is replaced by HDG SEL / HDG HOLD selected in flight or by LNAV,
-- while TO/GA pitch (B747DR_autopilot_TOGA_status) stays until a pitch mode
-- clears it. A new TO/GA press in the air (the engines module sets autoland
-- to -2) brings TO/GA roll back, and nothing is remembered on the ground.
local togaRollCleared=false
local lastAutolandSeen=0
function B747_ap_clear_toga_roll()
	if simDR_onGround == 0 and B747DR_autopilot_TOGA_status ~= 0 then
		togaRollCleared=true
		-- a TO/GA press made before this selection must not undo it
		lastAutolandSeen=B747DR_ap_autoland
	end
end
function fma_rollModes()
	local diff = simDRTime - B747DR_ap_lastCommand

	if diff < 0.2 then
		return
	end
	-- ROLL MODES: ARMED
	-- ----------------------------------------------------------------------------------

	-- (NONE) --
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	if numAPengaged>0 then
		apWasOn=1
	end
	if numAPengaged>0 or B747DR_toggle_switch_position[23] > 0.5 or B747DR_toggle_switch_position[24] > 0.5 then
		B747BR_showFMA=1
	else
		B747BR_showFMA=0
	end
	if B747DR_toggle_switch_position[23] == 0.0 and B747DR_toggle_switch_position[24] == 0.0  and numAPengaged == 0 and apWasOn==1 then
		
		B747DR_ap_FMA_armed_roll_mode = 0
	elseif B747DR_ap_lnav_state == 1 then
		B747DR_ap_FMA_armed_roll_mode = 2 -- (LNAV) --
	elseif B747DR_autopilot_nav_status == 1 or (B747DR_ap_approach_mode ~= 0 and B747DR_autopilot_nav_status ~= 2) then
		B747DR_ap_FMA_armed_roll_mode = 3 -- (LOC) --
	elseif simDR_radarAlt1 > 200 and (B747DR_ap_AFDS_status_annun_pilot == 3 or B747DR_ap_AFDS_status_annun_pilot == 4) then -- LAND 2/LAND 3
		B747DR_ap_FMA_armed_roll_mode = 4 -- ROLLOUT and FLARE ARMED
	else
		B747DR_ap_FMA_armed_roll_mode = 0
	end

	-- ROLL MODES: ACTIVE
	-- ----------------------------------------------------------------------------------

	-- (NONE) --
	--B747DR_ap_FMA_active_roll_mode = 0

	-- (TOGA) --
	-- on the ground the roll FMA stays as before; a stale LNAV state or a
	-- selection from the last flight must not hide TO/GA roll at the next takeoff
	if B747DR_autopilot_TOGA_status == 0 or simDR_onGround == 1
		or (B747DR_ap_autoland == -2 and lastAutolandSeen ~= -2) then
		togaRollCleared=false
	elseif B747DR_ap_lnav_state == 2 then
		togaRollCleared=true
	end
	lastAutolandSeen=B747DR_ap_autoland
	local navcrz = simDR_nav1_radio_course_deg
	--print("navcrz "..navcrz)
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	if B747DR_toggle_switch_position[23] == 0.0 and B747DR_toggle_switch_position[24] == 0.0  and numAPengaged == 0 and apWasOn==1 then
		B747DR_ap_FMA_active_roll_mode = 0 -- (NONE) --
	elseif math.abs(B747DR_ap_ATT) >= 5.0 then
		B747DR_ap_FMA_active_roll_mode = 5
	elseif B747_afds_helpers.toga_roll_mode_active(B747DR_autopilot_TOGA_status, B747DR_ap_lnav_state,
			B747DR_autopilot_nav_status, togaRollCleared) then --simDR_autopilot_TOGA_lat_status == 2 then
		B747DR_ap_FMA_active_roll_mode = 1 -- (TOGA) --
	elseif simDR_onGround == 1 then
		B747DR_ap_FMA_active_roll_mode = 0 -- (NONE) --
		B747DR_ap_thrust_mode = 0
	elseif B747DR_autopilot_nav_status == 2 then
		
		B747DR_ap_FMA_active_roll_mode = 3 -- (LOC) --
		--simDR_autopilot_heading_deg = roundToIncrement(simDR_radio_nav_obs_deg[0], 1) -- SET THE SELECTED HEADING VALUE TO THE LOC COURSE
		B747DR_ap_lnav_state = 0
	elseif B747DR_ap_lnav_state == 2 then
		B747DR_ap_FMA_active_roll_mode = 2 -- (LNAV) --
	elseif simDR_autopilot_heading_status == 2 and B747DR_ap_lnav_state ~= 2 then
		-- (HDG SEL) -- (also with LNAV armed)
		simDR_autopilot_heading_deg = B747DR_ap_heading_deg
		B747DR_ap_FMA_active_roll_mode = 6 -- (HDG SEL) --
	elseif simDR_autopilot_heading_hold_status == 2 then
		-- (an armed LNAV stays armed: LNAV ARM; it cleared it)
		B747DR_ap_FMA_active_roll_mode = 7 -- (HDG HLD) --
	else
		B747DR_ap_FMA_active_roll_mode = 0 -- (NONE) --
	end
end
local restoreAlt=0
function restoreAltFunc()
	simDR_autopilot_altitude_ft=restoreAlt
end
local lastGSProgress=0
function glideSlopeLOCProgress()
	--print("B747DR_ap_approach_mode "..B747DR_ap_approach_mode.." B747DR_engine_TOGA_mode "..B747DR_engine_TOGA_mode)
	if B747DR_ap_approach_mode == 0 or B747DR_engine_TOGA_mode == 1 then
		B747DR_autopilot_gs_status = 0
		B747DR_autopilot_nav_status = 0
		B747DR_ap_approach_mode = 0
	elseif B747DR_toggle_switch_position[23] == 1.0 or B747DR_toggle_switch_position[24] == 1.0 then
		if 	simDR_autopilot_gs_status>B747DR_autopilot_gs_status  then
			B747DR_autopilot_gs_status=simDR_autopilot_gs_status
		end
		if 	simDR_autopilot_nav_status>B747DR_autopilot_nav_status  then
			B747DR_autopilot_nav_status=simDR_autopilot_nav_status
		end
		local diff=simDRTime-lastGSProgress
		if simDR_autopilot_nav_status ==0 and B747DR_autopilot_nav_status>1 and diff>1 then
			lastGSProgress=simDRTime
			print("recover LOC mode")
			--simCMD_pause:once()
			if B747DR_autopilot_nav_status > 0 then
				--simCMD_autopilot_nav_mode:once() --DEACTIVATE LOC
				simDR_autopilot_nav_status=1

				B747DR_ap_lastCommand = simDRTime
				return
			end
		end
		if simDR_autopilot_gs_status ==0 and B747DR_autopilot_gs_status>1 and diff>1 then
			lastGSProgress=simDRTime
			print("recover GS mode")
			--simCMD_pause:once()
			if B747DR_autopilot_gs_status > 0 then
				--simCMD_autopilot_glideslope_mode:once() -- CANX GLIDESLOPE MODE
				simDR_autopilot_gs_status=1
				B747DR_ap_lastCommand = simDRTime
				return
			end
		end

	end
end
function fma_PitchModes()
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode

	-- PITCH MODES: ARMED
	-- ----------------------------------------------------------------------------------

	-- (NONE) --

	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	if B747DR_toggle_switch_position[23] == 0.0 and B747DR_toggle_switch_position[24] == 0.0  and numAPengaged == 0 and apWasOn==1 then
			-- (TOGA) --
		B747DR_ap_FMA_armed_pitch_mode = 0
	elseif B747DR_ap_vnav_state == 1 then
		-- (G/S) --
		B747DR_ap_FMA_armed_pitch_mode = 4
	elseif B747DR_autopilot_gs_status == 1 or (B747DR_ap_approach_mode > 0 and B747DR_autopilot_gs_status ~= 2) then
		-- (VNAV) --
		B747DR_ap_FMA_armed_pitch_mode = 2
	elseif B747DR_ap_vnav_state == 1 then
		B747DR_ap_FMA_armed_pitch_mode = 4
	elseif simDR_radarAlt1 > 200 and (B747DR_ap_AFDS_status_annun_pilot == 3 or B747DR_ap_AFDS_status_annun_pilot == 4) then
		-- ROLLOUT and FLARE ARMED (dont get here once in autoland)
		B747DR_ap_FMA_armed_pitch_mode = 3
	else
		-- (FLARE) --
		B747DR_ap_FMA_armed_pitch_mode = 0
	end

	-- PITCH MODES: ACTIVE
	-- ----------------------------------------------------------------------------------
	local altDiff=math.abs(simDR_pressureAlt1-simDR_autopilot_altitude_ft)
	-- (NONE) --
	--B747DR_ap_FMA_active_pitch_mode = 0
	if B747DR_toggle_switch_position[23] == 0.0 and B747DR_toggle_switch_position[24] == 0.0 and numAPengaged == 0 and apWasOn==1 then
		-- (TOGA) --
		if (simDRTime - B747DR_switching_servos_on) > 1 then
			B747_ap_all_cmd_modes_off()
			simCMD_autopilot_servos_fdir_off:once()
			simCMD_autopilot_servos2_fdir_off:once()
			simCMD_autopilot_servos3_fdir_off:once()
		end

		B747DR_ap_FMA_active_pitch_mode = 0
		B747DR_ap_vnav_state = 0
		B747DR_ap_lnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		--B747DR_ap_thrust_mode=0
		B747DR_engine_TOGA_mode = 0
		--if B747DR_autopilot_gs_status ~= 2 and B747DR_autopilot_nav_status ~= 2 then
		B747DR_ap_approach_mode = 0
		apWasOn=0
		B747DR_autopilot_gs_status = 0
		B747DR_autopilot_nav_status = 0
		--end
	elseif B747DR_autopilot_TOGA_status == 1 then
		--if B747DR_engine_TOGA_mode == 1 then

		B747DR_ap_FMA_active_pitch_mode = 1
	elseif simDR_onGround == 1 then
		-- (G/S) --
		B747DR_ap_FMA_active_pitch_mode = 0
	elseif B747DR_autopilot_gs_status == 2 then
		-- (FLARE) --
		-- TODO: AUTOLAND LOGIC

		B747DR_ap_FMA_active_pitch_mode = 2 -- (GS) --
		B747DR_ap_vnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		B747DR_ap_flightPhase = 4
		B747DR_ap_thrust_mode = 0
	elseif (simDR_autopilot_fms_vnav == 1 or B747DR_ap_vnav_state >= 2) and simDR_autopilot_flch_status == 2 then


		B747DR_ap_FMA_active_pitch_mode = 4 -- (VNAV SPD) --

	 --
	elseif (simDR_autopilot_fms_vnav == 1 or B747DR_ap_vnav_state >= 2) and (simDR_autopilot_alt_hold_status == 2 or altDiff<B747DR_alt_capture_window) then
		--[[if clbderate==0 then
			throttlederate=1.0
		elseif clbderate==1 then
			throttlederate=0.9
		elseif clbderate==2 then
			throttlederate=0.8
		end   ]]
		-- (VNAV PATH) --
		if B747DR_mcp_hold == 1 and (simDR_autopilot_altitude_ft / 100 ~= tonumber(string.sub(fmsData["crzalt"], 3))) then
			B747DR_ap_FMA_active_pitch_mode = 5 --VNAV ALT - MCP alt
		else
			B747DR_ap_FMA_active_pitch_mode = 6 --VNAV PTH - FMC alt
		end
	elseif (simDR_autopilot_fms_vnav == 1 or B747DR_ap_vnav_state >= 2) and simDR_autopilot_vs_status == 2 then
		-- (V/S) --
		if B747DR_ap_flightPhase == 3 and simDR_autopilot_vs_fpm == -500 then
			B747DR_ap_FMA_active_pitch_mode = 4 -- (VNAV SPD) --
		else
			B747DR_ap_FMA_active_pitch_mode = 6 -- (VNAV PATH) --
		end
	elseif (simDR_autopilot_vs_status == 2 and altDiff>B747DR_alt_capture_window) and simDR_autopilot_fms_vnav == 0 and B747DR_ap_vnav_state == 0 and simDR_autopilot_alt_hold_status ~= 2 then
		-- (FLCH SPD) --
		B747DR_ap_FMA_active_pitch_mode = 7 --VS


	elseif (simDR_autopilot_flch_status == 2 and altDiff>B747DR_alt_capture_window) and simDR_autopilot_fms_vnav == 0 and B747DR_ap_vnav_state == 0 and simDR_autopilot_alt_hold_status ~= 2 then
		-- (ALT) --
		B747DR_ap_FMA_active_pitch_mode = 8 --FLCH

	elseif (simDR_autopilot_alt_hold_status == 2 or altDiff<B747DR_alt_capture_window) and simDR_autopilot_fms_vnav == 0 and B747DR_ap_vnav_state == 0 then
		--throttlederate=1.0

		B747DR_ap_FMA_active_pitch_mode = 9 -- ALT
	else
		-- (NONE) --
		--throttlederate=1.0
		B747DR_ap_FMA_active_pitch_mode = 0
	end
end

-- [review 21] B747_ap_fma set HOLD in a VNAV descent's idle in the frame before
local vnavDescentHold=false
function B747_ap_fma(fms)
	B747DR_capt_ap_roll = B747_animate_value(B747DR_capt_ap_roll, B747DR_ap_target_roll - simDR_capt_roll, -25, 25, 10)
	B747DR_fo_ap_roll = B747_animate_value(B747DR_fo_ap_roll, B747DR_ap_target_roll - simDR_fo_roll, -25, 25, 10)
	--B747DR_capt_ap_roll=B747DR_ap_target_roll-simDR_capt_roll
	--B747DR_fo_ap_roll=B747DR_ap_target_roll-simDR_fo_roll
	glideSlopeLOCProgress()
	if B747DR_autothrottle_active==0 then
		B747DR_ap_FMA_autothrottle_mode = 0
	elseif B747DR_autothrottle_active==1 and B747DR_ap_FMA_active_pitch_mode==2 and B747DR_ap_FMA_autothrottle_mode ~= 3 then -- SPD
			B747DR_ap_lastCommand=simDRTime
			B747DR_ap_FMA_autothrottle_mode=3
	end
	if (B747DR_ap_AFDS_status_annun_pilot == 3 or B747DR_ap_AFDS_status_annun_pilot == 4) and runAutoland() then
		if fms~=nil then
			local endI = table.getn(fms)
			if endI>0 then
				local dtoAirport = getDistance(simDR_latitude,simDR_longitude, fms[endI][5], fms[endI][6])
				B747DR_fmstargetDistance=dtoAirport
				--B747DR_fmstargetIndex=endI
				B747DR_ap_vnav_target_alt=fms[endI][9]
			end
		end
		return
	end
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	-- AUTOTHROTTLE
	-------------------------------------------------------------------------------------
	local descentHold=vnavDescentHold
	vnavDescentHold=false
	if B747DR_ap_autoland == 1 and simDR_radarAlt1 < 25 then

		B747DR_ap_FMA_autothrottle_mode = 2 --IDLE
	elseif B747DR_toggle_switch_position[29] == 0 or B747DR_autothrottle_fail > 0 then
		B747DR_ap_FMA_autothrottle_mode = 0
	elseif
		(B747DR_engine_TOGA_mode > 0 and simDR_ind_airspeed_kts_pilot < 65) or B747DR_ap_autoland < 0 or
			(B747DR_ap_vnav_state == 0 and B747DR_ap_thrust_mode > 0)
	 then
		if B747DR_engine_TOGA_mode == 1 then
			B747DR_engine_TOGA_mode = 0
			B747DR_ap_FMA_autothrottle_mode = 0
		else
			B747DR_ap_FMA_autothrottle_mode = 5 --THR REF
		end
	elseif (B747DR_engine_TOGA_mode > 0 and simDR_radarAlt1 < 50) then
		B747DR_ap_FMA_autothrottle_mode = 1 --HOLD
		B747DR_engine_TOGA_mode = 1 --reached hold state
	elseif
		(simDR_autopilot_fms_vnav == 1 or B747DR_ap_vnav_state == 2) and
			(((simDR_autopilot_flch_status > 0 and (simDR_pressureAlt1> simDR_autopilot_altitude_ft+B747DR_alt_capture_window or simDR_pressureAlt1< simDR_autopilot_altitude_ft-B747DR_alt_capture_window)) or B747DR_engine_TOGA_mode == 1) and B747DR_ap_inVNAVdescent == 0)
	 then
		B747DR_ap_FMA_autothrottle_mode = 5 --THR REF
	elseif B747DR_vnav_energy_active == 1 and B747DR_ap_inVNAVdescent > 0
		and B747DR_autothrottle_active == 1 then
		if B747DR_vnav_energy_thrust_policy == B747_afds_helpers.VNAV_ENERGY_THRUST_IDLE then
			-- [B-13] IDLE while the A/T takes the levers back, HOLD once they are at idle (the servos off), as on a real
			-- 747-400 (THR, IDLE, HOLD); it stayed IDLE all the way down. HOLD only after IDLE, so it always follows it.
			-- [review 21] Then HOLD while VNAV wants idle: a pilot's lever movement stays (the servos are off; it went
			-- back to IDLE, which took the levers to idle again). A HOLD from before the descent goes IDLE first.
			if (descentHold and B747DR_ap_FMA_autothrottle_mode==1)
				or (simDR_allThrottle<=0.001 and (B747DR_ap_FMA_autothrottle_mode==2 or B747DR_ap_FMA_autothrottle_mode==1)) then
				B747DR_ap_FMA_autothrottle_mode = 1 --HOLD
				vnavDescentHold=true
			else
				B747DR_ap_FMA_autothrottle_mode = 2 --IDLE
			end
		else
			B747DR_ap_FMA_autothrottle_mode = 3 --SPD
		end
	elseif B747DR_autothrottle_active == 1 then
		-- in the approach (setDescentVSpeed) VNAV PTH's A/T is SPD, at idle too
		if B747DR_ap_vnav_state > 0 and simDR_allThrottle < 0.1 and B747DR_ap_inVNAVdescent > 0
			and not B747_vnav_approach_active then
			B747DR_ap_FMA_autothrottle_mode = 2 --IDLE
		elseif simDR_onGround == 0 and B747DR_ap_FMA_active_pitch_mode==1 then --TOGA
			B747DR_ap_FMA_autothrottle_mode = 5 --THR REF
		elseif simDR_onGround == 0 then
			B747DR_ap_FMA_autothrottle_mode = 3 -- SPD
		end
	else
		if B747DR_ap_vnav_state > 0 and simDR_allThrottle < 0.1 and simDR_onGround == 0 then
			B747DR_ap_FMA_autothrottle_mode = 2 --IDLE
		elseif (B747DR_ap_vnav_state > 0 or isATEnabled()) and simDR_onGround == 0  and simDR_radarAlt1 < 50 then
			B747DR_ap_FMA_autothrottle_mode = 1 --HOLD
		else
			B747DR_ap_FMA_autothrottle_mode = 0
			--simDR_override_throttles = 0
		end
	end

	B747_lnav_engage_armed(fms)

	if B747DR_toggle_switch_position[23] == 0.0 and B747DR_toggle_switch_position[24] == 0.0  and numAPengaged == 0 then
		B747DR_ap_approach_mode = 0
	end
	fma_rollModes()
	fma_PitchModes()
end

function ap_reset()
	print("full reset AP in B747_ap_afds")
	B747CMD_ap_reset:once()
	B747DR_ap_lastCommand=simDRTime
end

local B747_ap_AFDS_status_annun = 0
function set_afds_status(value)
	if value ~= B747_ap_AFDS_status_annun then
		print("Set AFDS=" .. value .. " @ " .. simDR_radarAlt1 .. "feet")
	end
	B747_ap_AFDS_status_annun = value
	if value == 1 then
		if B747DR_toggle_switch_position[23] == 1.0 then
			B747DR_ap_AFDS_status_annun_pilot = value
		else
			B747DR_ap_AFDS_status_annun_pilot = 0
		end
		if B747DR_toggle_switch_position[24] == 1.0 then
			B747DR_ap_AFDS_status_annun_copilot = value
		else
			B747DR_ap_AFDS_status_annun_copilot = 0
		end
	else
		B747DR_ap_AFDS_status_annun_pilot = value
		B747DR_ap_AFDS_status_annun_copilot = value
	end
end
---- AFDS STATUS -------------------------------------------------------------------------
function B747_ap_afds()
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	if simDR_autopilot_servos_on == 0 then
		if numAPengaged > 0 and (simDRTime - B747DR_switching_servos_on) > 1 then
			print("reset AP in B747_ap_afds")
			run_after_time(ap_reset, 2)
			B747DR_CAS_warning_status[0] = 1
			B747DR_ap_cmd_L_mode = 0
			B747DR_ap_cmd_C_mode = 0
			B747DR_ap_cmd_R_mode = 0
		elseif numAPengaged == 0 then
			B747DR_switching_servos_on = simDRTime

		end


		--simDR_autopilot_approach_status =0
		B747DR_ap_autoland = 0
		landAssist = false
	elseif simDR_autopilot_servos_on == 1 and (simDRTime - B747DR_switching_servos_on) > 1 then
		if numAPengaged == 0 then
			if B747DR_autothrottle_active == 1 then
				run_after_time(autothrottle_reengage,0.5)
			end
			B747CMD_ap_reset:once()
			simCMD_autopilot_servos_off:once()
			simDR_autopilot_servos_on=0
			B747_ap_all_cmd_modes_off()
			B747DR_CAS_warning_status[0] = 1
			B747DR_ap_lastCommand=simDRTime

		end
	end
	local diff = simDRTime - B747DR_ap_lastCommand
	if diff < 0.1 then
		return
	end

	local landAssist = false

	if ((B747DR_autopilot_nav_status ==2 and B747DR_autopilot_gs_status==2) or simDR_autopilot_approach_status > 1 or B747DR_ap_autoland == 1) and simDR_radarAlt1<1500 then
		landAssist = true
	end
	noAutoLand = false
	if
		numAPengaged > 0 and (B747DR_ap_approach_mode ~= 0) and simDR_radarAlt1 > 200 and simDR_radarAlt1 < 1000 and
		B747DR_autopilot_nav_status ~= 2 and
		B747DR_autopilot_gs_status ~= 2
	 then
		set_afds_status(5)
		noAutoLand = true
	elseif numAPengaged == 1 then -- TODO:  CHANGE TO "==" WHEN AUTOLAND LOGIC (BELOW) IS IMPLEMENTED
		-- TODO: IF LOC OR APP CAPTURED ? THEN...
		if landAssist == true and simDR_radarAlt1 < 1500 then
			set_afds_status(5) -- AFDS MODE = "NO AUTOLAND" (NOT MODELED)
		else
			set_afds_status(2) -- AFDS MODE = "CMD"
		end
	elseif numAPengaged == 2 and landAssist == true then
		set_afds_status(3) -- AFDS MODE = "LAND 2"
		B747_AFDS_land2_EICAS_status = 1
	elseif numAPengaged == 3 and landAssist == true then
		set_afds_status(4) -- AFDS MODE = "LAND 3"
		B747_AFDS_land3_EICAS_status = 1
	else
		if numAPengaged >= 1 then
			set_afds_status(2) -- AFDS MODE = "CMD"
		elseif B747DR_toggle_switch_position[23] > 0.95 or B747DR_toggle_switch_position[24] > 0.95 then
			set_afds_status(1) -- AFDS MODE = "FD"
		else
			set_afds_status(0)
		end
	end
	if noAutoLand then
		B747DR_CAS_advisory_status[246] = 1
	else
		B747DR_CAS_advisory_status[246] = 0
	end
end

----- FLIGHT MODE ANNUNCIATORS MODE CHANGE BOX ------------------------------------------
function B747_AFDS_status_mode_chg_timeout()
	B747DR_ap_AFDS_mode_box_status_pilot = 0
	B747DR_ap_AFDS_mode_box_status_copilot = 0
end

function B747_AFDS_status_mode_chg2_timeout()
	B747DR_ap_AFDS_mode_box2_status_pilot = 0
	B747DR_ap_AFDS_mode_box2_status_copilot = 0
end

function B747_at_mode_chg_timeout()
	B747DR_ap_FMA_autothrottle_mode_box_status = 0
end

function B747_roll_mode_chg_timeout()
	B747DR_ap_roll_mode_box_status = 0
end

function B747_pitch_mode_chg_timeout()
	B747DR_ap_pitch_mode_box_status = 0
end

function B747_ap_afds_fma_mode_change()
	-- AFDS STATUS
	if B747_ap_AFDS_status_annun ~= B747_ap_last_AFDS_status then
		if B747_ap_AFDS_status_annun == 0 then -- MODE IS "NONE"
			if is_timer_scheduled(B747_AFDS_status_mode_chg2_timeout) == true then -- TEST IF TIMER IS RUNNING
				stop_timer(B747_AFDS_status_mode_chg2_timeout) -- KILL THE TIMER
			end
			B747DR_ap_AFDS_mode_box_status_pilot = 0
			B747DR_ap_AFDS_mode_box_status_copilot = 0
			B747DR_ap_AFDS_mode_box2_status_pilot = 0
			B747DR_ap_AFDS_mode_box2_status_copilot = 0
		elseif B747_ap_AFDS_status_annun > 0 and B747_ap_AFDS_status_annun < 5 then -- MODE IS NOT "NONE" AND NOT "NO AUTOLAND"
			if B747DR_toggle_switch_position[23] == 1 then
				B747DR_ap_AFDS_mode_box_status_pilot = 1
			else
				B747DR_ap_AFDS_mode_box2_status_pilot = 0
			end -- SHOW THE MODE CHANGE BOX
			if B747DR_toggle_switch_position[24] == 1 then
				B747DR_ap_AFDS_mode_box_status_copilot = 1
			else
				B747DR_ap_AFDS_mode_box2_status_copilot = 0
			end -- SHOW THE MODE CHANGE BOX                                          -- SHOW THE MODE CHANGE BOX
			if is_timer_scheduled(B747_AFDS_status_mode_chg_timeout) == false then -- CHECK TIMEOUT STATUS
				run_after_time(B747_AFDS_status_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			else
				stop_timer(B747_AFDS_status_mode_chg_timeout) -- STOP PREVIOUS TIMER
				run_after_time(B747_AFDS_status_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			end
		elseif B747_ap_AFDS_status_annun == 5 then -- MODE IS "NO AUTOLAND"
			B747DR_ap_AFDS_mode_box_status_pilot = 0
			B747DR_ap_AFDS_mode_box_status_copilot = 0
			if B747DR_toggle_switch_position[23] == 1 then
				B747DR_ap_AFDS_mode_box2_status_pilot = 1
			end -- SHOW THE MODE CHANGE BOX
			if B747DR_toggle_switch_position[24] == 1 then
				B747DR_ap_AFDS_mode_box2_status_copilot = 1
			end -- SHOW THE MODE CHANGE BOX
			if is_timer_scheduled(B747_AFDS_status_mode_chg2_timeout) == false then -- CHECK TIMEOUT STATUS
				run_after_time(B747_AFDS_status_mode_chg2_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			else
				stop_timer(B747_AFDS_status_mode_chg2_timeout) -- STOP PREVIOUS TIMER
				run_after_time(B747_AFDS_status_mode_chg2_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			end
		end
	end
	B747_ap_last_AFDS_status = B747_ap_AFDS_status_annun -- RESET LAST MODE

	-- AUTOTHROTTLE MODE
	if B747DR_ap_FMA_autothrottle_mode ~= B747_ap_last_FMA_autothrottle_mode then -- THE MODE HAS CHANGED
		if B747DR_ap_FMA_autothrottle_mode == 0 then -- MODE IS "NONE"
			if is_timer_scheduled(B747_at_mode_chg_timeout) == true then -- TEST IF TIMER IS RUNNING
				stop_timer(B747_at_mode_chg_timeout) -- KILL THE TIMER
			end
			B747DR_ap_FMA_autothrottle_mode_box_status = 0
		elseif B747DR_ap_FMA_autothrottle_mode > 0 then -- MODE IS NOT "NONE"
			B747DR_ap_FMA_autothrottle_mode_box_status = 1 -- SHOW THE MODE CHANGE BOX
			if is_timer_scheduled(B747_at_mode_chg_timeout) == false then -- CHECK TIMEOUT STATUS
				run_after_time(B747_at_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			else
				stop_timer(B747_at_mode_chg_timeout) -- STOP PREVIOUS TIMER
				run_after_time(B747_at_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			end
		end
	end
	B747_ap_last_FMA_autothrottle_mode = B747DR_ap_FMA_autothrottle_mode -- RESET LAST MODE

	-- ROLL MODE
	if B747DR_ap_FMA_active_roll_mode ~= B747_ap_last_FMA_roll_mode then -- THE MODE HAS CHANGED
		if B747DR_ap_FMA_active_roll_mode == 0 then -- MODE IS "NONE"
			if is_timer_scheduled(B747_roll_mode_chg_timeout) == true then -- TEST IF TIMER IS RUNNING
				stop_timer(B747_roll_mode_chg_timeout) -- KILL THE TIMER
			end
			B747DR_ap_roll_mode_box_status = 0
		elseif B747DR_ap_FMA_active_roll_mode > 0 then -- MODE IS NOT "NONE"
			B747DR_ap_roll_mode_box_status = 1 -- SHOW THE MODE CHANGE BOX
			if is_timer_scheduled(B747_roll_mode_chg_timeout) == false then -- CHECK TIMEOUT STATUS
				run_after_time(B747_roll_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			else
				stop_timer(B747_roll_mode_chg_timeout) -- STOP PREVIOUS TIMER
				run_after_time(B747_roll_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			end
		end
	end
	B747_ap_last_FMA_roll_mode = B747DR_ap_FMA_active_roll_mode -- RESET LAST MODE

	-- PITCH MODE
	if B747DR_ap_FMA_active_pitch_mode ~= B747_ap_last_FMA_pitch_mode then -- THE MODE HAS CHANGED
		if B747DR_ap_FMA_active_pitch_mode == 0 then -- MODE IS "NONE"
			if is_timer_scheduled(B747_pitch_mode_chg_timeout) == true then -- TEST IF TIMER IS RUNNING
				stop_timer(B747_pitch_mode_chg_timeout) -- KILL THE TIMER
			end
			B747DR_ap_pitch_mode_box_status = 0
		elseif B747DR_ap_FMA_active_pitch_mode > 0 then -- MODE IS NOT "NONE"
			B747DR_ap_pitch_mode_box_status = 1 -- SHOW THE MODE CHANGE BOX
			if is_timer_scheduled(B747_pitch_mode_chg_timeout) == false then -- CHECK TIMEOUT STATUS
				run_after_time(B747_pitch_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			else
				stop_timer(B747_pitch_mode_chg_timeout) -- STOP PREVIOUS TIMER
				run_after_time(B747_pitch_mode_chg_timeout, 10.0) -- SET TO TIMEOUT IN 10 SECONDS
			end
		end
	end
	B747_ap_last_FMA_pitch_mode = B747DR_ap_FMA_active_pitch_mode -- RESET LAST MODE
end

----- TURN AUTOPILOT COMMAND MODES OFF --------------------------------------------------
function B747_ap_all_cmd_modes_off()
	print("B747_ap_all_cmd_modes_off")
	B747DR_ap_cmd_L_mode = 0
	B747DR_ap_cmd_C_mode = 0
	B747DR_ap_cmd_R_mode = 0
	--B747DR_ap_approach_mode = 0
	B747DR_switching_servos_on = simDRTime
end

local last_airspeed = 0
local last_target_heading = 0
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
    if newValue <= min+0.001 and newValue >= min-0.001 then
        newValue = min
    elseif newValue >= max-0.001 and newValue <= max+0.001 then
        newValue = max
    elseif newValue <= min then
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
function B747_ap_target_flaps()
	if B747DR_ap_target_flaps == -1 then
		return
	end
	local diff = simDRTime - last_target_heading --set by next function
	if diff < 0.05 then
		return
	end
	local cFlaps=0
	local fTarget=0
	if B747DR_ap_target_flaps==0 then --flaps 1
		fTarget=0.0
	elseif B747DR_ap_target_flaps==1 then --flaps 1
		fTarget=0.167
	 elseif B747DR_ap_target_flaps== 5 then --flaps 5
		fTarget=0.333
	 elseif B747DR_ap_target_flaps==10 then --flaps 10
		fTarget=0.50
	 elseif B747DR_ap_target_flaps==20 then --flaps 20
		fTarget=0.667
	 elseif B747DR_ap_target_flaps==25 then --flaps 25
		fTarget=0.833
	 elseif B747DR_ap_target_flaps==30 then --flaps 30
		fTarget=1.0
	 else
		B747DR_ap_target_flaps=-1
		return
	 end
	 if fTarget<simDR_flap_ratio_control+0.01 and fTarget>simDR_flap_ratio_control-0.01 then
		B747DR_ap_target_flaps = -1
		print("set flaps")
		return
	 end
	 if simDR_flap_ratio_control>fTarget then
		simDR_flap_ratio_control=B747_interpolate_value(simDR_flap_ratio_control,0,0,1,8)
	 else
		simDR_flap_ratio_control=B747_interpolate_value(simDR_flap_ratio_control,1,0,1,8)
	 end
end
function B474_ap_target_vspeed()
	if B747DR_ap_target_vertspeed == -1 then
		return
	end
	if B747DR_ap_target_vertspeed == B747DR_autopilot_vs_fpm then
		B747DR_ap_target_vertspeed = -1
		return
	end
	if B747DR_ap_target_vertspeed<-8000 then
		B747DR_ap_target_vertspeed=-1
		return
	end
	if B747DR_ap_target_vertspeed>8000 then
		B747DR_ap_target_vertspeed=-1
		return
	end
	if B747DR_ap_vs_window_open==0 then
		B747CMD_ap_switch_vs_mode:once()
		return
	end
	--B747DR_ap_target_heading_deg = math.floor(B747DR_ap_target_speed)
	local vspd_diff = B747DR_autopilot_vs_fpm - B747DR_ap_target_vertspeed
	if vspd_diff<100 and vspd_diff>-100 then
		B747DR_ap_target_vertspeed = -1
		print("set vspeed")
		return
	 end
	print("target spd " .. B747DR_autopilot_vs_fpm .. " " .. B747DR_ap_target_vertspeed .. " " .. vspd_diff)
	if vspd_diff < 0 then
		simCMD_ap_vertical_speed_up:once()
	else
		simCMD_ap_vertical_speed_down:once()
	end


end

function B474_ap_target_altitude()
	if B747DR_ap_target_altitude == -1 then
		return
	end
	if B747DR_ap_target_altitude == B747DR_autopilot_altitude_ft then
		B747DR_ap_target_altitude = -1
		return
	end
	local diff = simDRTime - last_target_heading
	if diff < 0.05 then
		return
	end
	if B747DR_ap_target_altitude<100 then
		B747DR_ap_target_altitude=-1
		return
	end
	if B747DR_ap_target_speed>40000 then
		B747DR_ap_target_altitude=-1
		return
	end

	--B747DR_ap_target_heading_deg = math.floor(B747DR_ap_target_speed)
	local alt_diff = B747DR_autopilot_altitude_ft - B747DR_ap_target_altitude
	if alt_diff<100 and alt_diff>-100 then
		B747DR_autopilot_altitude_ft=B747DR_ap_target_altitude
		B747DR_ap_target_altitude = -1
		print("set altitude")
		return
	 end
	print("target alt " .. B747DR_autopilot_altitude_ft .. " " .. B747DR_ap_target_speed .. " " .. alt_diff)
	if alt_diff < 0 then
		B747DR_autopilot_altitude_ft = math.floor(B747DR_autopilot_altitude_ft + 100)
	else
		B747DR_autopilot_altitude_ft = math.floor(B747DR_autopilot_altitude_ft - 100)
	end
end

function B474_ap_target_speed()
	if B747DR_ap_target_speed == -1 then
		return
	end
	if B747DR_ap_ias_dial_value == B747DR_ap_target_speed then
		B747DR_ap_target_speed = -1
		return
	end
	local diff = simDRTime - last_target_heading
	if diff < 0.05 then
		return
	end
	if B747DR_ap_target_speed<100 then
		B747DR_ap_target_speed=-1
		return
	end
	if B747DR_ap_target_speed>350 then
		B747DR_ap_target_speed=-1
		return
	end
	--B747DR_ap_target_heading_deg = math.floor(B747DR_ap_target_speed)
	local speed_diff = B747DR_ap_ias_dial_value - B747DR_ap_target_speed
	print("target speed " .. B747DR_ap_ias_dial_value .. " " .. B747DR_ap_target_speed .. " " .. speed_diff)
	if speed_diff < 0 then
		B747DR_ap_ias_dial_value = math.floor(B747DR_ap_ias_dial_value + 1)
	else
		B747DR_ap_ias_dial_value = math.floor(B747DR_ap_ias_dial_value - 1)
	end
end
function B474_ap_target_heading()
	local diff = simDRTime - B747DR_ap_lastCommand
		
	local simDR_autopilot_heading_status=simDR_autopilot_heading_status
	if B747DR_ap_activate_target_heading_deg==1 then
		if diff < 0.05 then
			return
		end	
		
		if B747DR_ap_lnav_state > 0 then
			B747DR_ap_lnav_state=0
		end
		if simDR_autopilot_heading_status == 0 then
			print("simCMD_autopilot_heading_select in B474_ap_target_heading")
			simCMD_autopilot_heading_select:once()
		end
		--simDR_autopilot_heading_status=0
		B747DR_ap_ATT = 0.0
		simDR_autopilot_heading_deg = B747DR_ap_heading_deg
		B747DR_ap_lnav_state = 0
		B747DR_ap_lastCommand=simDRTime
		B747DR_ap_activate_target_heading_deg=0
		-- HDG SEL replaces TO/GA roll in flight. Done here, where X-Plane's
		-- heading mode is engaged, not in the button handler, so the roll FMA
		-- (run earlier in the frame) never goes blank in between.
		B747_ap_clear_toga_roll()
		print("change to HDG SEL")
	end
	if simDR_autopilot_heading_status == 0 and simDR_autopilot_nav_status ~= 2
		and (B747DR_ap_lnav_state == 2 or (B747DR_ap_lnav_state == 1 and simDR_onGround == 1)) then
		if diff < 0.05 then
			return
		end	
		print("simCMD_autopilot_heading_select in B747DR_ap_lnav_state")
		simCMD_autopilot_heading_select:once()
		B747DR_ap_lastCommand=simDRTime
	end
	if B747DR_ap_target_heading_deg == -1 then
		return
	end
	if B747DR_ap_heading_deg == B747DR_ap_target_heading_deg then
		B747DR_ap_target_heading_deg = -1
		return
	end
	local diff = simDRTime - last_target_heading
	if diff < 0.05 then
		return
	end
	last_target_heading = simDRTime

	B747DR_ap_target_heading_deg = math.floor(B747DR_ap_target_heading_deg)
	local heading_diff = getHeadingDifference(B747DR_ap_target_heading_deg, B747DR_ap_heading_deg)
	print("target heading " .. B747DR_ap_target_heading_deg .. " " .. B747DR_ap_heading_deg .. " " .. heading_diff)
	if heading_diff < 0 then
		B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg + 1), 360.0))
	else
		B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg - 1), 360.0))
		if B747DR_ap_heading_deg < 0.0 then
			B747DR_ap_heading_deg = B747DR_ap_heading_deg + 360.0
		end
	end
end
----- EICAS MESSAGES --------------------------------------------------------------------
function B747_ap_EICAS_msg()
	-- >AUTOPILOT

	if simDR_autopilot_fail == 6 then
		B747DR_CAS_caution_status[4] = 1
	else
		B747DR_CAS_caution_status[4] = 0
	end

	--print("test drag required".. B747DR_speedbrake_lever .. " " .. simDR_all_wheels_on_ground .. " " .. simDR_autopilot_vs_fpm .. " " .. simDR_autopilot_vs_status .. " " )
	-- >AUTOTHROT DISC
	if B747DR_autothrottle_fail == 1 then
		B747DR_CAS_caution_status[5] = 1
	else
		B747DR_CAS_caution_status[5] = 0
	end

	if B747DR_vnav_energy_active == 1 and B747DR_vnav_energy_drag_required == 1
		and B747DR_speedbrake_lever < 0.3 and simDR_radarAlt1 > 1000 then
		B747DR_fmc_notifications[9] = 1 --DRAG REQUIRED: path recovery is at its normal limit
	elseif
		B747DR_speedbrake_lever < 0.3 and simDR_ind_airspeed_kts_pilot > (simDR_autopilot_airspeed_kts + 10) and
			simDR_ind_airspeed_kts_pilot > last_airspeed and
			simDR_autopilot_vs_status >= 1 and
			B747DR_ap_vnav_state > 0
	 then
		if
			simDR_allThrottle < 0.01 and simDR_radarAlt1 > 1000
		 then
			B747DR_fmc_notifications[9] = 1 --DRAG REQUIRED
		end
	elseif simDR_ind_airspeed_kts_pilot ~= last_airspeed then --dont turn it off if airspeed didn't update
		B747DR_fmc_notifications[9] = 0
	end
	last_airspeed = simDR_ind_airspeed_kts_pilot
end

----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_ap_monitor_AI()
	if B747DR_init_autopilot_CD == 1 then
		B747_set_ap_all_modes()
		B747_set_ap_CD()
		B747DR_init_autopilot_CD = 2
	end
end

----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_ap_all_modes()
	B747DR_init_autopilot_CD = 0

	simDR_autopilot_airspeed_is_mach = 0
	B747DR_ap_alt_show_thousands = 1

	simDR_autopilot_airspeed_kts_mach = 0.76 --200.0
	B747DR_ap_ias_dial_value = 100
	simDR_autopilot_heading_deg = 0.0
	simDR_autopilot_vs_fpm = 0.0
	simDR_autopilot_altitude_ft = 10000.0
	B747DR_autopilot_altitude_ft = 10000.0
end

----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_ap_CD()
end

----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_ap_ER()
end

----- FLGHT START -----------------------------------------------------------------------
function B747_flight_start_autopilot()
	-- ALL MODES ------------------------------------------------------------------------
	B747_set_ap_all_modes()
	simCMD_autopilot_set_nav1_as_nav_source:once()
	simDR_autopilot_bank_limit = 4
	B747DR_ap_approach_mode=0
	-- COLD & DARK ----------------------------------------------------------------------
	if simDR_startup_running == 0 then
		-- ENGINES RUNNING ------------------------------------------------------------------
		B747_set_ap_CD()
	elseif simDR_startup_running == 1 then
		B747_set_ap_ER()
	end
end

--*************************************************************************************--
--** 				                 EVENT CALLBACKS           	        			 **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end

function flight_start()
	B747_flight_start_autopilot()
	B747_reset_takeoff_profile()
	simDR_elevator = 0
	simDR_rudder = 0
	simDR_pitch = 0
	B747DR_ap_vnav_system = 2
	simDR_disabled_autopilot_altitude_ft=150000
	B747BR_vnavProfile="[]"
	
end

--function flight_crash() end

--function before_physics() end
debug_autopilot = deferred_dataref("laminar/B747/debug/autopilot", "number")
local setSimConfig = false
function hasSimConfig()
	if B747DR_newsimconfig_data == 1 then
		if string.len(B747DR_simconfig_data) > 1 then
			simConfigData["data"] = json.decode(B747DR_simconfig_data)
			setSimConfig = true
		else
			return false
		end
	end
	return setSimConfig
end
function after_physics()
	if hasSimConfig() == false then
		return
	end
	collectgarbage("collect")
	if debug_autopilot > 0 then
		return
	end
	simDR_allThrottle=math.max(B747DR_throttle[0],B747DR_throttle[1],B747DR_throttle[2],B747DR_throttle[3])
	local cHeading = simDR_AHARS_heading_deg_pilot --constant refresh of data
	local tHeading = simDR_autopilot_heading_deg --constant refresh of data
	local headingStatus = simDR_autopilot_heading_hold_status --constant refresh of data
	local groundspeed = simDR_groundspeed
	-- the fly-by turn anticipation's inputs: XTLua gives 0 for a first read
	local groundTrack = simDR_ground_track_true
	local trueHeading = simDR_true_heading
	local trueAirspeed = simDR_TAS_mps
	local bankLimit = simDR_autopilot_bank_angles[3]
	local bankMode = simDR_autopilot_bank_limit
	 --constant refresh of dat
	local latitude = simDR_latitude
	 --constant refresh of dat
	local longitude = simDR_longitude
	 --constant refresh of dat
	local vsi = B744_fpm
	local isMachSpd = simDR_autopilot_airspeed_is_mach
	local machSpd = simDR_autopilot_airspeed_kts_mach
	local flch_status = simDR_autopilot_flch_status
	local vs_status =simDR_autopilot_vs_status
	local onGround = simDR_onGround
	local cruiseAlt = B747BR_cruiseAlt
	local tDist = B747BR_totalDistance
	local tod = B747BR_tod
	--print(B747DR_FMSdata)
	if string.len(B747DR_FMSdata) > 0 then
		fmsData = json.decode(B747DR_FMSdata)
	else
		fmsData = json.decode("[]")
	end

	local fmsSTR = fmsJSON
	local fms = json.decode(fmsSTR)
	B747_update_takeoff_profile()
	B747_update_route_constraints(fms)
	B747_getCurrentWayPoint(fms)
	B747_update_constraint_speed(fms)
	B747_monitorAP(fms)
	B747_update_vnav_energy_mode_isolation()
	B747_ap_fma(fms)
	B747_ap_button_switch_animation()
	B747_fltmgmt_setILS(fms)
	B747_ap_vs_mode()
	B747_ap_ias_mach_mode()
	B747_ap_altitude(fms)
	B747_vnav_speed()
	B747_ap_appr_mode()
	B747_ap_afds()
	B747_ap_afds_fma_mode_change()
	B747_ap_EICAS_msg()
	B747_ap_target_flaps()
	B474_ap_target_vspeed()
	B474_ap_target_speed()
	B474_ap_target_altitude()
	B474_ap_target_heading()

	B747_ap_monitor_AI()
	B747_afds_log_diagnostics(fms)
	B747_log_vnav_energy_diagnostics()
end

--function after_replay() end

--*************************************************************************************--
--** 				               SUB-MODULE PROCESSING       	        			 **--
--*************************************************************************************--

-- dofile("")
