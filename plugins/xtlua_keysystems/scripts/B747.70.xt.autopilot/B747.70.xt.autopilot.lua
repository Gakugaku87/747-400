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
simDR_autopilot_airspeed_is_mach = find_dataref("sim/cockpit2/autopilot/airspeed_is_mach")
simDR_autopilot_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_dial_ft")
simDR_disabled_autopilot_altitude_ft = find_dataref("sim/cockpit2/autopilot/altitude_dial_ft")
simDR_autopilot_hold_altitude_ft = find_dataref("laminar/B747/autopilot/altitude_hold_ft")
simDR_autopilot_tod_index = find_dataref("sim/cockpit2/radios/indicators/fms_tod_before_index_pilot")
simDR_autopilot_tod_distance = find_dataref("sim/cockpit2/radios/indicators/fms_distance_to_tod_pilot")
B747DR_alt_capture_window        = deferred_dataref("laminar/B747/autopilot/ap_monitor/alt_capture_window", "number")
B747DR_switching_servos_on = deferred_dataref("laminar/B747/autopilot/ap_monitor/servos_on_time", "number")
B747DR_display_N1 = find_dataref("laminar/B747/engines/display_N1")
B747DR_display_N2 = find_dataref("laminar/B747/engines/display_N2")
simDR_true_heading			= find_dataref("sim/flightmodel/position/psi")
-- the heading reference (5-2 step 5d): the display glue's (1 true north),
-- the HDG REF switch (the toggle switches' 31st, 1 TRUE)
B747DR_ap_hdg_ref_true			= find_dataref("laminar/B747/efis/hdg_ref/true")
B747DR_ap_toggle_sw			= find_dataref("laminar/B747/toggle_switch/position")
simDR_ap_mag_psi			= find_dataref("sim/flightmodel/position/mag_psi")
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
B747DR_fms_xp_bridge = find_dataref("laminar/B747/fms/xp/bridge")
B747DR_fms_xp_current = find_dataref("laminar/B747/fms/xp/current")
-- the FMC's LNAV (6-1/6-2 step 6c; notes/ATA-34-61-FMC.md §29): its
-- steering's validity (LNAV engages on it: ATA34_2 p.619) and bank
-- command, and whether it sequences its active route itself
B747DR_fms_lnav_valid = find_dataref("laminar/B747/fms/lnav/valid")
B747DR_fms_lnav_roll = find_dataref("laminar/B747/fms/lnav/roll")
B747DR_fms_lnav_route = find_dataref("laminar/B747/fms/lnav/route")
-- X-Plane's FMS's current entry (from 1): through the FMS bridge plugin when
-- it is there (X-Plane's thread), else XTLua's currentFMSID (XTLua's own
-- thread with no lock against X-Plane's: 6-1/6-2 step 5e)
function B747_set_fms_current(n)
	if B747DR_fms_xp_bridge == 1 then
		B747DR_fms_xp_current = n
	else
		B747DR_fms_setCurrent = n
	end
end
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
B747DR_ap_inVNAVdescent = deferred_dataref("laminar/B747/autopilot/vnav_descent", "number")
B747DR_ap_inDescent 		= deferred_dataref("laminar/B747/autopilot/vnav/after_tod", "number")
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
dofile("B747.70.xt.autopilot.vnav.lua")

-- the FCCs' mode logic (6-3 step 1a; notes/ATA-22.md §10): the engage
-- state, AUTOPILOT DISC, the F/Ds and the default modes. The other modes
-- are still the code below; the defaults asked for go to it
dofile("B747.70.afds_model.lua")
B747DR_ap_engine_type = find_dataref("laminar/B747/engines/type")
local afds = B747_afds_model.new()
-- the roll laws (step 2a; notes/ATA-22.md §16): the command the A/P flies
-- (the hydraulics module's servo law reads it) and the F/Ds show; without
-- a law there the old law. ROLLOUT's rudder (step 4c) and runway align's
-- (step 4d): the pedals' ratio the A/P adds with more than one channel (the
-- hydraulics module: the rudder and the nose wheel steering, FCOM p.659)
dofile("B747.70.afds_roll_model.lua")
local afdsRoll = B747_afds_roll_model.new()
local afdsRollIn = B747_afds_roll_model.inputs()
B747DR_ap_roll_cmd = find_dataref("laminar/B747/autopilot/roll_cmd")
B747DR_ap_roll_law = find_dataref("laminar/B747/autopilot/roll_law")
B747DR_ap_roll_valid = find_dataref("laminar/B747/autopilot/roll_valid")
B747DR_ap_rudder_cmd = find_dataref("laminar/B747/autopilot/rudder_cmd")
simDR_afds_tas = find_dataref("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot")
-- the pitch laws (steps 3a and 3b; notes/ATA-22.md §18, §19): the command
-- the A/P flies (the hydraulics module's servo law reads it) and the F/Ds
-- show; without a law there (G/S, FLARE) the old law
dofile("B747.70.afds_pitch_model.lua")
local afdsPitch = B747_afds_pitch_model.new()
local afdsPitchIn = B747_afds_pitch_model.inputs()
B747DR_ap_pitch_cmd = find_dataref("laminar/B747/autopilot/pitch_cmd")
B747DR_ap_pitch_law = find_dataref("laminar/B747/autopilot/pitch_law")
simDR_afds_pitch = find_dataref("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot")
simDR_afds_vs = find_dataref("sim/flightmodel/position/vh_ind_fpm")
-- the speed laws' (step 3b): the minimum maneuvering and the maximum speeds
-- (the speed tape's, for the FMC's of FCOM p.675), the PLI (valid when the
-- PFDs show it: estimate), GPWS's windshear
B747DR_afds_vminm = find_dataref("laminar/B747/airspeed/Vminm")
B747DR_afds_vmax = find_dataref("laminar/B747/airspeed/Vmax")
-- the FMC's VNAV (6-1/6-2 step 9c; the FMS module's: notes/
-- ATA-34-61-FMC.md §56-57): valid, the phase (1 climb, 2 cruise, 3
-- descent), the sub-mode asked for (1 SPD, 2 PTH), the target speed, the
-- FMC altitude, PTH's vertical speed, the path's deviation, the A/T mode
B747DR_ap_fvn_valid = find_dataref("laminar/B747/fms/vnav/valid")
B747DR_ap_fvn_phase = find_dataref("laminar/B747/fms/vnav/phase")
B747DR_ap_fvn_mode = find_dataref("laminar/B747/fms/vnav/mode")
B747DR_ap_fvn_cas = find_dataref("laminar/B747/fms/vnav/cas")
B747DR_ap_fvn_mach = find_dataref("laminar/B747/fms/vnav/mach")
B747DR_ap_fvn_mach_mode = find_dataref("laminar/B747/fms/vnav/mach_mode")
B747DR_ap_fvn_alt = find_dataref("laminar/B747/fms/vnav/alt")
B747DR_ap_fvn_vs = find_dataref("laminar/B747/fms/vnav/vs")
B747DR_ap_fvn_path_dev = find_dataref("laminar/B747/fms/vnav/path_dev")
B747DR_ap_fvn_at = find_dataref("laminar/B747/fms/vnav/at")
B747DR_ap_fvn_perf = find_dataref("laminar/B747/fms/vnav/perf")
B747DR_afds_pli = find_dataref("laminar/B747/pfd/pli")
B747DR_afds_pli_show = find_dataref("laminar/B747/pfd/pli_show")
B747DR_afds_windshear = find_dataref("laminar/B747/gpws/windshear")
-- the speed laws' reference: the IAS/MACH window's when open (a Mach's
-- knots: X-Plane's dial), else the old VNAV's (X-Plane's dial)
local function afds_speed_ref()
	if B747DR_ap_ias_mach_window_open == 1 and simDR_autopilot_airspeed_is_mach == 0 then return B747DR_ap_ias_dial_value end
	return simDR_autopilot_airspeed_kts
end
-- VNAV's speed (step 9c): the FMC's target speed on the speed dial while
-- VNAV is engaged with the IAS/MACH window shut (FCOM p.645), a Mach as
-- Mach x 100 with the dial in Mach (B747_ap_ias_mach_mode puts the dial on
-- X-Plane's, the speed laws' and the A/T's reference, and the speed bug);
-- the units changed as the old VNAV changed them (a quarter second). The
-- ND's VNAV path pointer from the FMC's path in the descent (FCOM p.1149:
-- the panel's after_tod and flight_path_error). Before, the old VNAV's
-- (B747_vnav_speed, setDescentVSpeed)
local function afds_fmc_vnav()
	local des = B747DR_ap_fvn_valid == 1 and B747DR_ap_fvn_phase == 3
	local td = des and 1 or 0
	if B747DR_ap_inDescent ~= td then B747DR_ap_inDescent = td end
	B747BR_fpe = des and B747DR_ap_fvn_path_dev or 0
	if afds.pitch ~= "VNAV" or B747DR_ap_ias_mach_window_open == 1 or B747DR_switchingIASMode ~= 0 then return end
	if getVNAVState("manualVNAVspd") == 1 then return end
	local mach = B747DR_ap_fvn_mach_mode == 1
	local v = mach and math.floor(B747DR_ap_fvn_mach * 1000 + 0.5) / 10 or math.floor(B747DR_ap_fvn_cas + 0.5)
	if v <= 0 then return end
	if mach ~= (simDR_autopilot_airspeed_is_mach == 1) then
		simDR_autopilot_airspeed_is_mach = mach and 1 or 0
		B747DR_switchingIASMode = 1
		run_after_time(B747_updateIAS, 0.25)
	end
	if B747DR_ap_ias_dial_value ~= v then B747DR_ap_ias_dial_value = v end
end
-- G/S's inputs to the pitch laws (step 3c): NAV 1's glide slope deviation
-- (X-Plane's dots: plus above the beam), both receivers' glide slope with
-- no flag, the radio altitude, the ground speed, the inertial vertical
-- speed (the capture's too)
simDR_afds_gs_dots_nav1 = find_dataref("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot")
-- the gear altitude (step 4b; ATA22 p.346: the radio altitude, the pitch
-- and the antenna's distance to the gear): X-Plane's radio altitude reads
-- AFDS_RA_ZERO ft and AFDS_RA_ARM ft x sin pitch as the main gear touches
-- (estimate: a line through s114's four touchdowns, 3.12 ft at 5.0
-- degrees to 3.48 at 7.0; s109's lift-off, 3 ft at 3.1, on it)
local AFDS_RA_ZERO, AFDS_RA_ARM = 2.3, 10
local function afds_gear_alt()
	return simDR_radarAlt1 - AFDS_RA_ZERO - AFDS_RA_ARM * math.sin(math.rad(simDR_afds_pitch))
end
local function afds_gs_inputs(p)
	p.gs_dots = simDR_afds_gs_dots_nav1
	p.gs_valid = simDR_hsi_nav1_vertical_signal == 1 and simDR_hsi_nav2_vertical_signal == 1
		and simDR_nav1_gs_flag == 0 and simDR_nav2_gs_flag == 0
	p.ra = simDR_radarAlt1
	p.gs = simDR_groundspeed * 1.94384
	p.vs = simDR_afds_vs
	-- FLARE and NOSE LETDOWN (step 4b)
	p.gear_alt = afds_gear_alt()
	p.letdown = afds.letdown
end
-- the pitch laws' inputs: the attitude, the inertial vertical speed (ATA22
-- p.344), the TAS, the altitude, the MCP's V/S, the old VNAV's law by its
-- flags and its targets; the speed laws' (step 3b): the IAS, the reference
-- (T/O's V2 and G/A's MCP speed too), the speed protection, the PLI, the
-- flaps, a windshear; G/S's (step 3c)
-- (6-1/6-2 step 9a, until the FMC's VNAV of step 9c) VNAV levels off at
-- the MCP altitude (VNAV ALT: FCOM p.645, ATA22 p.280) and, in the climb,
-- at the FMC altitude (VNAV PTH: ATA22 p.280, the FMC's next constraint or
-- CRZ ALT; step 9c: the FMC's VNAV's, before the old VNAV's target),
-- captured as V/S and FLCH capture theirs (B747.70.afds_pitch_model.lua's
-- capture), and holds it until that altitude moves (a new MCP altitude,
-- the FMC's next). Before, the rebuilt AFDS flew the old VNAV's FLCH and
-- V/S flags through them (s137: on through MCP 13,000 ft to 16,900 ft)
local vnavLevel = nil
local function afds_vnav_level(p)
	if afds.pitch ~= "VNAV" then vnavLevel = nil return end
	local mcp, tgt = B747DR_autopilot_altitude_ft, B747DR_ap_fvn_alt
	if vnavLevel then
		local now = vnavLevel.fma == 5 and mcp or tgt
		if math.abs(now - vnavLevel.alt) > 50 then vnavLevel = nil end
	end
	if not vnavLevel and p.vnav_law ~= "ALT" then
		if B747_afds_pitch_model.capture(p, mcp) then
			vnavLevel = {alt = mcp, fma = 5}
		elseif B747DR_ap_fvn_phase == 1 and tgt ~= mcp and B747_afds_pitch_model.capture(p, tgt) then
			vnavLevel = {alt = tgt, fma = 6}
		end
	end
	if vnavLevel then p.vnav_law, p.vnav_alt = "ALT", vnavLevel.alt end
end
local function afds_pitch_inputs(p)
	p.pitch = simDR_afds_pitch
	p.vs = simDR_afds_vs
	p.tas = simDR_afds_tas
	p.alt = simDR_pressureAlt1
	p.vs_sel = simDR_autopilot_vs_fpm
	-- VNAV's laws by the FMC's VNAV (6-1/6-2 step 9c; notes/
	-- ATA-34-61-FMC.md §57): VNAV SPD on the speed law at the FMC's target
	-- speed (the speed dial: afds_fmc_speed), VNAV PTH level at the FMC
	-- altitude (the cruise) or on its descent path's vertical speed; before,
	-- the old VNAV's flags (FLCH, V/S, ALT)
	p.vnav_law, p.vnav_vs, p.vnav_alt = nil, 0, simDR_pressureAlt1
	if B747DR_ap_fvn_mode == 1 then
		p.vnav_law = "FLCH"
	elseif B747DR_ap_fvn_phase == 3 then
		p.vnav_law, p.vnav_vs = "VS", B747DR_ap_fvn_vs
	elseif B747DR_ap_fvn_mode == 2 then
		p.vnav_law, p.vnav_alt = "ALT", B747DR_ap_fvn_alt
	end
	afds_vnav_level(p)
	local ref = afds_speed_ref()
	p.ias = simDR_ind_airspeed_kts_pilot
	p.spd_sel = ref
	p.mcp_ias = ref
	p.v_min = B747DR_afds_vminm
	p.v_max = B747DR_afds_vmax
	p.pli = B747DR_afds_pli_show > 0.5 and B747DR_afds_pli or nil
	p.flaps_up = simDR_flap_ratio_control < 0.01
	p.windshear = B747DR_afds_windshear > 0.5
	afds_gs_inputs(p)
end
-- the magnetic track (LOC and G/S capture within 120 and 80 degrees of the
-- localizer course: 6-3 step 1d)
simDR_afds_track_mag = find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
local afdsIn = {fd = {L = false, R = false}, hyd = {0, 0, 0}}
-- the autoland status's redundancy (step 4a; ATA22 p.256): the FCCs'
-- power (L AC 3 and DC 3, C AC 1 and DC 1, R AC 2 and DC 2: ATA22 p.191,
-- p.304), the autoland sensors: the IRUs, the radio altimeters and the ILS
-- receivers valid (X-Plane has two: ILS C as L, an estimate), their glide
-- slope only until FLARE (G/S ends there: ATA22 p.342; X-Plane flags it in
-- the last feet, and LAND 3 went to NO AUTOLAND before the touchdown:
-- step 4c); the channels armed for multi-channel (their CMD lights)
B747DR_afds_bus_ac = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_afds_bus_dc = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_afds_irs_nav_valid = find_dataref("laminar/B747/irs/nav_valid")
B747DR_afds_ra_valid = find_dataref("laminar/B747/ra/valid")
B747DR_ap_cmd_armed = deferred_dataref("laminar/B747/autopilot/cmd_armed", "array[3]")
-- the engage interlocks (step 5a; ATA22 p.302-322): each FCC powered (its
-- AC and DC bus), the MCP (DC 3 or DC 2: p.191, p.209), the 28V DC STBY
-- bus (the battery bus: p.190), the inner loop sensors (the IRUs' attitude,
-- the ADCs), each SRM's autotrim valid (B747.45.xt.srm.lua), the control
-- wheel (degrees, the captain's)
B747DR_afds_bus_bat = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_afds_irs_att_valid = find_dataref("laminar/B747/irs/att_valid")
B747DR_afds_adc_valid = find_dataref("laminar/B747/airdata/valid")
B747DR_afds_autotrim_valid = find_dataref("laminar/B747/flt_ctrls/stab_trim/autotrim_valid")
B747DR_afds_wheel = find_dataref("laminar/B747/cablecontrols/wheel")
-- (ELEC-18: BCU 2's BUS ISOLATED, B747.03.xt.elec_buses.lua; the request
-- out, afds_sync)
B747DR_afds_bus_isolated = find_dataref("laminar/B747/electrical/bus_isolated")
B747DR_ap_bus_isolate_req = find_dataref("laminar/B747/autopilot/bus_isolate_req")
local AFDS_FCC_BUS = {2, 0, 1}
local afdsFcc = {L = false, C = false, R = false}
local afdsTrim = {L = false, R = false}
-- the FCCs powered (L, C, R as AFDS_FCC_BUS): how many
local function afds_power()
	local n = 0
	for k, ch in ipairs(B747_afds_model.CHANNELS) do
		local i = AFDS_FCC_BUS[k]
		afdsFcc[ch] = B747DR_afds_bus_ac[i] > 0.5 and B747DR_afds_bus_dc[i] > 0.5
		if afdsFcc[ch] then n = n + 1 end
	end
	return n
end
local function afds_interlocks(inp)
	inp.fcc = afdsFcc
	inp.mcp = B747DR_afds_bus_dc[2] > 0.5 or B747DR_afds_bus_dc[1] > 0.5
	inp.stby = B747DR_afds_bus_bat > 0.5
	local iru, adc = 0, 0
	for i = 0, 2 do
		if B747DR_afds_irs_att_valid[i] > 0.5 then iru = iru + 1 end
		if B747DR_afds_adc_valid[i] > 0.5 then adc = adc + 1 end
	end
	inp.iru, inp.adc = iru, adc
	afdsTrim.L = B747DR_afds_autotrim_valid[0] > 0.5
	afdsTrim.R = B747DR_afds_autotrim_valid[1] > 0.5
	inp.trim = afdsTrim
	inp.wheel = B747DR_afds_wheel
	inp.bus_isolated = B747DR_afds_bus_isolated > 0.5
end
-- the autoland capability (step 5b; ATA22 p.384): the channels valid, the
-- FCCs' power, the IRUs (NAV), the radio altimeters, the ILS receivers
-- (X-Plane's failures, not the signal: NAV 1 as L and C, NAV 2 as R, the
-- localizer's and glide slope's failures all three), the SRMs (their
-- validity: B747.45.xt.srm.lua), the FCUs (their failures)
simDR_afds_fail_nav1 = find_dataref("sim/operation/failures/rel_nav1")
simDR_afds_fail_nav2 = find_dataref("sim/operation/failures/rel_nav2")
simDR_afds_fail_loc = find_dataref("sim/operation/failures/rel_loc")
simDR_afds_fail_gs = find_dataref("sim/operation/failures/rel_gls")
B747DR_afds_srm_valid = find_dataref("laminar/B747/flt_ctrls/stab_trim/srm_valid")
B747DR_afds_fcu_fail = find_dataref("laminar/B747/flt_ctrls/fail/fcu")
local AFDS_XP_FAILED = 6
local afdsCap = {}
local function afds_cap(inp)
	local c = afdsCap
	local n = 0
	for _, ch in ipairs(B747_afds_model.CHANNELS) do
		if B747_afds_model.valid(ch, inp) then n = n + 1 end
	end
	c.channels, c.power = n, inp.power
	local iru, ra, fcu = 0, 0, 0
	for i = 0, 2 do
		if B747DR_afds_irs_nav_valid[i] > 0.5 then iru = iru + 1 end
		if B747DR_afds_ra_valid[i] > 0.5 then ra = ra + 1 end
		if B747DR_afds_fcu_fail[i] < 0.5 then fcu = fcu + 1 end
	end
	c.iru, c.ra, c.fcu = iru, ra, fcu
	local ils = 0
	if simDR_afds_fail_loc ~= AFDS_XP_FAILED and simDR_afds_fail_gs ~= AFDS_XP_FAILED then
		ils = (simDR_afds_fail_nav1 ~= AFDS_XP_FAILED and 2 or 0) + (simDR_afds_fail_nav2 ~= AFDS_XP_FAILED and 1 or 0)
	end
	c.ils = ils
	c.srm = (B747DR_afds_srm_valid[0] > 0.5 and 1 or 0) + (B747DR_afds_srm_valid[1] > 0.5 and 1 or 0)
	inp.cap = c
end
-- the mode failures (step 5c; ATA22 p.382): the ILS receivers with a
-- localizer and with a glide slope (a signal and not failed: NAV 1 as L and
-- C, NAV 2 as R), the radio altimeters and IRUs at NAV (afds_cap's), the
-- IRUs with a heading, both pilots' selected ADCs, the pitch, NAV 1's
-- frequency; out, the FMA's amber lines and the F/Ds' command bars
B747DR_afds_irs_hdg_valid = find_dataref("laminar/B747/irs/hdg_valid")
B747DR_afds_adc_valid_capt = find_dataref("laminar/B747/airdata/valid_capt")
B747DR_afds_adc_valid_fo = find_dataref("laminar/B747/airdata/valid_fo")
B747DR_ap_FMA_roll_fail = find_dataref("laminar/B747/autopilot/FMA/roll_fail")
B747DR_ap_FMA_pitch_fail = find_dataref("laminar/B747/autopilot/FMA/pitch_fail")
B747DR_ap_fd_roll_bar = find_dataref("laminar/B747/autopilot/fd/roll_bar")
B747DR_ap_fd_pitch_bar = find_dataref("laminar/B747/autopilot/fd/pitch_bar")
-- ILS TUNE INHIBIT and RA TEST INHIBIT (step 5d): a localizer alive, the
-- heading against NAV 1's course, the ground speed; out, the inhibits
B747DR_ap_ils_tune_inhibit = find_dataref("laminar/B747/autopilot/ils_tune_inhibit")
B747DR_ap_ra_test_inhibit = find_dataref("laminar/B747/autopilot/ra_test_inhibit")
local function afds_mode_inputs(inp)
	local loc_ok = simDR_afds_fail_loc ~= AFDS_XP_FAILED
	local gs_ok = simDR_afds_fail_gs ~= AFDS_XP_FAILED
	local nav1, nav2 = simDR_afds_fail_nav1 ~= AFDS_XP_FAILED, simDR_afds_fail_nav2 ~= AFDS_XP_FAILED
	local loc1 = loc_ok and nav1 and simDR_hsi_nav1_horizontal_signal == 1
	local loc2 = loc_ok and nav2 and simDR_hsi_nav2_horizontal_signal == 1
	inp.loc_rx = (loc1 and 2 or 0) + (loc2 and 1 or 0)
	local gs1 = gs_ok and nav1 and simDR_hsi_nav1_vertical_signal == 1 and simDR_nav1_gs_flag == 0
	local gs2 = gs_ok and nav2 and simDR_hsi_nav2_vertical_signal == 1 and simDR_nav2_gs_flag == 0
	inp.gs_rx = (gs1 and 2 or 0) + (gs2 and 1 or 0)
	inp.ra_n, inp.iru_nav = afdsCap.ra, afdsCap.iru
	local hdg = 0
	for i = 0, 2 do
		if B747DR_afds_irs_hdg_valid[i] > 0.5 then hdg = hdg + 1 end
	end
	inp.iru_hdg = hdg
	inp.adc_sel = B747DR_afds_adc_valid_capt > 0.5 and B747DR_afds_adc_valid_fo > 0.5
	inp.pitch_att = simDR_afds_pitch
	inp.ils_freq = simDR_nav1Freq
	-- (step 5d)
	inp.loc_alive = loc1 or loc2
	inp.loc_hdg_err = getHeadingDifference(simDR_radio_nav_obs_deg[0], simDR_ap_mag_psi)
	inp.gs_kt = simDR_groundspeed * 1.94384
end
local function afds_sensors()
	local iru, ra = 0, 0
	for i = 0, 2 do
		if B747DR_afds_irs_nav_valid[i] > 0.5 then iru = iru + 1 end
		if B747DR_afds_ra_valid[i] > 0.5 then ra = ra + 1 end
	end
	local gs_used = afds.pitch ~= "FLARE" and not afds.letdown
	local l = simDR_hsi_nav1_horizontal_signal == 1
		and (not gs_used or (simDR_hsi_nav1_vertical_signal == 1 and simDR_nav1_gs_flag == 0))
	local r = simDR_hsi_nav2_horizontal_signal == 1
		and (not gs_used or (simDR_hsi_nav2_vertical_signal == 1 and simDR_nav2_gs_flag == 0))
	local ils = (l and 2 or 0) + (r and 1 or 0)
	return math.min(iru, ra, ils)
end
-- LOC's inputs to the roll laws (step 2b): NAV 1's deviation (X-Plane's
-- dots), both receivers' localizer, the course and the track (magnetic),
-- the ground speed, the radio altitude; no LOC in NORM's polar areas
local function afds_loc_inputs(r)
	r.loc_dots = simDR_hsi_ldef_dots_nav1
	r.loc_valid = simDR_hsi_nav1_horizontal_signal == 1 and simDR_hsi_nav2_horizontal_signal == 1
	r.course = simDR_radio_nav_obs_deg[0]
	r.trk_mag = simDR_afds_track_mag
	r.gs = simDR_groundspeed * 1.94384
	r.ra = simDR_radarAlt1
	r.hdg_valid = not (B747DR_ap_hdg_ref_true > 0.5 and B747DR_ap_toggle_sw[30] < 0.5)
end
-- the TO/GA switches (step 1e): the engines module counts their pushes
-- (its command handler, with the A/T's part); the F/Ds shown, a switch ON
-- or TO/GA's display with them OFF (FCOM p.661), for the panel's command
-- bars and the AFDS status
B747DR_ap_toga_pushes = find_dataref("laminar/B747/autopilot/toga_pushes")
B747DR_ap_fd_shown_capt = find_dataref("laminar/B747/autopilot/fd/capt/shown")
B747DR_ap_fd_shown_fo = find_dataref("laminar/B747/autopilot/fd/fo/shown")
local afdsTogaPushes = nil
-- VNAV's sub-mode in the FMA (step 9c: the FMC's VNAV's; before, the old
-- VNAV's law's flags): VNAV SPD 4, VNAV ALT 5 (levelled at the MCP
-- altitude), VNAV PTH 6 (levelled at the FMC altitude, the cruise, the
-- descent path)
local function afds_old_vnav_fma()
	if vnavLevel then return vnavLevel.fma end
	if B747DR_ap_fvn_mode == 1 then return 4 end
	return 6
end
-- the A/T (6-4, the FMC's step 9f1; notes/ATA-34-61-FMC.md §58): its
-- engage logic, AUTOTHROT DISC and modes (B747.70.at_model.lua), each
-- frame after the AFDS, the only writer of the A/T's state (before, the
-- old FMA's if chain and the A/T flags written in seven places); the
-- switches' pushes counted for it. The levers are still the EEC's by the
-- mode (step 9f2)
dofile("B747.70.at_model.lua")
simDR_at_rev_deploy = find_dataref("sim/flightmodel2/engines/thrust_reverser_deploy_ratio")
-- (step 9f2) the servo's command for the EEC; the thrust and its
-- reference (the EEC's EPR or N1 bugs) for the laws
B747DR_at_servo = deferred_dataref("laminar/B747/autothrottle/servo", "number")
B747DR_at_lever_cmd = deferred_dataref("laminar/B747/autothrottle/lever_cmd", "number")
B747DR_at_TRA = find_dataref("laminar/B747/engines/TRA")
simDR_at_EPR_bug = find_dataref("sim/cockpit2/engine/actuators/EPR_target_bug")
simDR_at_N1_bug = find_dataref("sim/cockpit2/engine/actuators/N1_target_bug")
local atState = B747_at_model.new()
local atIn = {}
local atIas, atAccel = nil, 0
local atPush = {spd = 0, thr = 0, disc = 0}
local atSeen = {spd = 0, thr = 0, disc = 0, toga = nil}
local function afds_at()
	local i = atIn
	i.arm = B747DR_ap_autothrottle_armed == 1
	-- the interlocks: three engines running (N1 over 15 %: the old
	-- monitor's), the A/T's fail (the EECs' ALTN: B747.42.xt.eec_thrust.lua)
	local run = 0
	for e = 0, 3 do
		if B747DR_display_N1[e] > 15 then run = run + 1 end
	end
	i.ok = run >= 3 and B747DR_autothrottle_fail == 0
	i.ground = simDR_onGround == 1
	i.cas, i.ra = simDR_ind_airspeed_kts_pilot, simDR_radarAlt1
	i.flaps_up = simDR_flap_ratio_control < 0.01
	local rev, idle = false, true
	for e = 0, 3 do
		if simDR_at_rev_deploy[e] > 0.01 then rev = true end
		if B747DR_throttle[e] > 0.01 then idle = false end
	end
	i.reverse, i.lever_idle = rev, idle
	local lim = B747DR_ref_thr_limit_mode
	i.limit_to = string.find(lim, "TO", 1, true) ~= nil
	i.limit_ga = lim == "GA"
	i.pitch = afds.pitch
	i.retard = afds.retard and true or false
	i.vnav_at, i.vnav_level = B747DR_ap_fvn_at, vnavLevel ~= nil
	local n = B747DR_ap_toga_pushes
	i.toga = atSeen.toga ~= nil and n ~= atSeen.toga
	atSeen.toga = n
	for _, k in ipairs({"spd", "thr", "disc"}) do
		i[k] = atPush[k] ~= atSeen[k]
		atSeen[k] = atPush[k]
	end
	B747_at_model.update(atState, i)
	-- the servo (step 9f2): the laws' inputs, the command out. The speed's
	-- acceleration filtered over a second (estimate); the thrust the
	-- levers' command, the EEC's TRA (EPR for P&W and RR, N1 for GE: type
	-- 1; the highest), its reference the EEC's bug; the speed laws' target
	-- X-Plane's dial (afds_speed_ref)
	local dt = SIM_PERIOD
	local ias = simDR_ind_airspeed_kts_pilot
	if atIas and dt > 0 then
		atAccel = atAccel + ((ias - atIas) / dt - atAccel) * math.min(1, dt)
	end
	atIas = ias
	local n1 = B747DR_ap_engine_type == 1
	local thr, lev = 0, 0
	for e = 0, 3 do
		thr = math.max(thr, B747DR_at_TRA[e])
		lev = lev + B747DR_throttle[e] / 4
	end
	i.dt, i.ias, i.accel, i.target = dt, ias, atAccel, afds_speed_ref()
	i.v_max = B747DR_afds_vmax > 0 and B747DR_afds_vmax or 365
	i.v_min = B747DR_afds_vminm > 0 and B747DR_afds_vminm or 0
	i.vs, i.alt, i.mcp_alt = simDR_vvi_fpm_pilot, simDR_pressureAlt1, B747DR_autopilot_altitude_ft
	i.n1, i.thrust = n1, thr
	i.thrust_ref = n1 and simDR_at_N1_bug[0] or simDR_at_EPR_bug[0]
	i.lever = lev
	B747_at_model.servo(atState, i)
	local sv = atState.servo and 1 or 0
	if B747DR_at_servo ~= sv then B747DR_at_servo = sv end
	B747DR_at_lever_cmd = atState.cmd
	local act = atState.engaged and 1 or 0
	if B747DR_autothrottle_active ~= act then B747DR_autothrottle_active = act end
	local fma = B747_at_model.fma(atState)
	if B747DR_ap_FMA_autothrottle_mode ~= fma then B747DR_ap_FMA_autothrottle_mode = fma end
	-- (TO's state for the old readers: 0.9 its THR REF, 1 its HOLD)
	local to = atState.engaged and (atState.to == "thr" and 0.9 or (atState.to == "hold" and 1)) or 0
	if B747DR_engine_TOGA_mode ~= to then B747DR_engine_TOGA_mode = to end
end
local function afds_inp()
	afdsIn.fd.L = B747DR_toggle_switch_position[23] > 0.5
	afdsIn.fd.R = B747DR_toggle_switch_position[24] > 0.5
	afdsIn.hyd[1], afdsIn.hyd[2], afdsIn.hyd[3] = B747DR_hyd_sys_pressure_1, B747DR_hyd_sys_pressure_2, B747DR_hyd_sys_pressure_3
	afdsIn.bank = simDR_AHARS_roll_deg_pilot
	afdsIn.engine = B747DR_ap_engine_type
	afdsIn.ground = simDR_onGround == 1
	-- TO/GA (step 1e): the flaps up (the handle at UP: estimate, the FCC's
	-- flaps up), the A/T in SPD (T/O's pitch reset: ATA22 p.337)
	afdsIn.flaps_up = simDR_flap_ratio_control < 0.01
	afdsIn.at_spd = B747DR_ap_FMA_autothrottle_mode == 3
	-- the roll (step 1b): the heading HDG HOLD holds (magnetic, as X-Plane's
	-- HDG SEL's target), the FMC's steering
	afdsIn.ra = simDR_radarAlt1
	afdsIn.hdg = simDR_ap_mag_psi
	-- HDG SEL valid (step 2a): no heading in NORM's polar areas (FCOM p.1046)
	afdsIn.hdg_valid = not (B747DR_ap_hdg_ref_true > 0.5 and B747DR_ap_toggle_sw[30] < 0.5)
	afdsIn.lnav_valid = B747DR_fms_lnav_valid == 1
	-- the autoland status's redundancy (step 4a), the engage interlocks
	-- (step 5a: the FCCs' power after afds_power)
	afdsIn.power = afds_power()
	afdsIn.sensors = afds_sensors()
	afds_interlocks(afdsIn)
	afds_cap(afdsIn)
	afds_mode_inputs(afdsIn)
	-- FLARE's height (step 4b): the gear altitude, the inertial vertical
	-- speed (the VSI's lags)
	afdsIn.gear_alt = afds_gear_alt()
	afdsIn.ivs = simDR_afds_vs
	afdsIn.dt = SIM_PERIOD
	-- the approach (step 1d): LOC's capture by the roll laws (step 2b: the
	-- ground speed, the intercept angle and the deviation, ATA22 p.290),
	-- G/S's by the pitch laws (step 3c: the distance from the beam's centre
	-- and its rate, ATA22 p.292; before, under 1.5 dots), the track's angle
	-- to the course
	afds_loc_inputs(afdsRollIn)
	afdsIn.loc_detect = B747_afds_roll_model.loc_capture(afdsRollIn)
	afds_gs_inputs(afdsPitchIn)
	afdsIn.gs_detect = B747_afds_pitch_model.gs_capture(afdsPitchIn)
	afdsIn.course_err = getHeadingDifference(simDR_radio_nav_obs_deg[0], simDR_afds_track_mag)
	-- the pitch (step 1c): the vertical speed, the altitude, the speeds, the
	-- MCP altitude's capture by the pitch laws (step 3a: the 0.05 g level-off;
	-- before, the old window), the old VNAV (until the FMC's step 9), the old
	-- law's mode, the old autoland's FLARE arm
	afdsIn.vs = simDR_vvi_fpm_pilot
	afdsIn.alt = simDR_pressureAlt1
	afdsIn.ias = simDR_ind_airspeed_kts_pilot
	afdsIn.mcp_ias = B747DR_ap_ias_dial_value
	afdsIn.window_open = B747DR_ap_ias_mach_window_open == 1
	afdsIn.fmc_speed = afds.pitch == "VNAV" and simDR_autopilot_airspeed_kts or nil
	afds_pitch_inputs(afdsPitchIn)
	afdsIn.capture = B747_afds_pitch_model.capture(afdsPitchIn, simDR_autopilot_altitude_ft)
	afdsIn.capture_alt = simDR_autopilot_altitude_ft
	afdsIn.old_hold_alt = simDR_autopilot_hold_altitude_ft
	-- VNAV engages from its arm above 400 ft (FCOM p.645) on the FMC's valid
	-- (ATA22 p.341: FMC DATA VALID), stays while valid (step 9c; before,
	-- the old VNAV's state)
	afdsIn.vnav_engaged = B747DR_ap_fvn_valid == 1 and (afds.pitch == "VNAV" or (simDR_onGround == 0 and simDR_radarAlt1 > 400))
	afdsIn.vnav_fma = afds_old_vnav_fma()
	if afds.pitch == "VNAV" then
		-- VNAV lost (the FMC's valid gone): ALT HOLD at the altitude (ATA22
		-- p.338's default; the old flags are not VNAV's now)
		afdsIn.old_law, afdsIn.old_hold_alt = "ALT", simDR_pressureAlt1
	elseif simDR_autopilot_alt_hold_status == 2 then
		afdsIn.old_law = "ALT"
	elseif simDR_autopilot_vs_status == 2 then
		afdsIn.old_law = "VS"
	elseif simDR_autopilot_flch_status == 2 then
		afdsIn.old_law = "FLCH"
	else
		afdsIn.old_law = nil
	end
	return afdsIn
end
-- V/S as the V/S switch sets it, synced to the present vertical speed
-- (ATA22 p.282, p.344: the switch's own sync is step 1c)
local function afds_vs_default()
	-- (the A/T is the A/T model's: the FMC's step 9f1; before, V/S made it
	-- active)
	simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
	simDR_autopilot_hold_altitude_ft = simDR_autopilot_altitude_ft
	simDR_autopilot_alt_hold_status = 0
	simDR_autopilot_flch_status = 0
	simDR_autopilot_vs_status = 2
	B747DR_ap_thrust_mode = 0
	B747DR_ap_inVNAVdescent = 0
	B747DR_ap_flightPhase = B747DR_autopilot_altitude_ft > simDR_pressureAlt1 and 1 or 3
	B747DR_ap_vnav_state = 0
	local vs = math.max(-8000, math.min(6000, roundToIncrement(simDR_vvi_fpm_pilot, 100)))
	simDR_autopilot_vs_fpm = vs
	B747DR_autopilot_vs_fpm = vs
end
-- the modes the model asks for, on the old code's state: V/S; all off
-- (FCOM p.660) with X-Plane's heading modes (the roll modes are the
-- model's own: afds_sync)
local function afds_apply(act)
	if not act then return end
	if act.all_off then
		B747DR_ap_vnav_state = 0
		B747DR_ap_lnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		B747DR_ap_approach_mode = 0
		B747DR_autopilot_gs_status = 0
		B747DR_autopilot_nav_status = 0
		B747DR_ap_ATT = 0
		simDR_autopilot_vs_status = 0
		simDR_autopilot_flch_status = 0
		simDR_autopilot_alt_hold_status = 0
		simCMD_autopilot_servos_fdir_off:once()
		simCMD_autopilot_servos2_fdir_off:once()
		simCMD_autopilot_servos3_fdir_off:once()
		return
	end
	if act.pitch == "VS" then afds_vs_default() end
end
-- the engage state on the datarefs: the channels (CMD lights), the servos
-- (and the time they came on), AUTOPILOT DISC
local function afds_sync()
	-- the SRMs' autoland (step 4c; ATA27 p.636: the rudder ratio changers at
	-- full authority, the autotrim without its delay): a multi-channel
	-- landing, LAND 3 or 2 through the rollout (before, the old autoland's
	-- below 100 ft with three channels); the old go-around's -2 kept (the
	-- A/T's G/A thrust) until 1,500 ft
	if B747DR_ap_autoland >= 0 then
		local al = (afds.land == "LAND3" or afds.land == "LAND2") and 1 or 0
		if B747DR_ap_autoland ~= al then B747DR_ap_autoland = al end
	end
	local L, C, R = afds.L and 1 or 0, afds.C and 1 or 0, afds.R and 1 or 0
	local on = (L + C + R) > 0 and 1 or 0
	if on == 1 and simDR_autopilot_servos_on == 0 then B747DR_switching_servos_on = simDRTime end
	if B747DR_ap_cmd_L_mode ~= L then B747DR_ap_cmd_L_mode = L end
	if B747DR_ap_cmd_C_mode ~= C then B747DR_ap_cmd_C_mode = C end
	if B747DR_ap_cmd_R_mode ~= R then B747DR_ap_cmd_R_mode = R end
	-- the channels armed for multi-channel (step 4a): their CMD lights
	for i, ch in ipairs(B747_afds_model.CHANNELS) do
		local a = afds.arm[ch] and 1 or 0
		if B747DR_ap_cmd_armed[i - 1] ~= a then B747DR_ap_cmd_armed[i - 1] = a end
	end
	if simDR_autopilot_servos_on ~= on then simDR_autopilot_servos_on = on end
	local w = afds.disc and 1 or 0
	if B747DR_CAS_warning_status[0] ~= w then B747DR_CAS_warning_status[0] = w end
	-- the roll modes (step 1b) on the old code's state: LNAV's (0 off, 1
	-- armed, 2 engaged: the FMC's LNAV reads it), ATT's bank; the roll laws
	-- are the new model's (step 2a: afds_roll_law)
	local ln = afds.lnav_arm and 1 or (afds.roll == "LNAV" and 2 or 0)
	if B747DR_ap_lnav_state ~= ln then B747DR_ap_lnav_state = ln end
	-- the pitch modes (step 1c) on the old code's state: VNAV's (1 armed,
	-- 2 engaged), the old law's flags for V/S, ALT (its altitude) and FLCH
	-- (the old G/S and TO/GA laws go by the FMA)
	if afds.pitch == "VNAV" then
		-- VNAV engaged (step 9c: the FMC's VNAV flies it, afds_pitch_inputs):
		-- at the engage the A/T active with its ARM switch on (FCOM p.645),
		-- TO/GA's thrust and the old laws' flags off; the FMC's phase for
		-- the EEC's thrust reference (CLB, CRZ), TO kept below 1,000 ft as
		-- the old THR REF kept it (an estimate until step 9f's THR
		-- REDUCTION)
		if B747DR_ap_vnav_state ~= 2 then
			B747DR_ap_vnav_state = 2
			-- the IAS/MACH window shut: a speed intervention of before ends
			-- (the A/T engages with VNAV in the A/T model: step 9f1)
			setVNAVState("manualVNAVspd", 0)
			B747DR_ap_inVNAVdescent = 0
			B747DR_mcp_hold = 0
			simDR_autopilot_vs_status = 0
			simDR_autopilot_alt_hold_status = 0
			simDR_autopilot_flch_status = 0
		end
		local ph = B747DR_ap_fvn_phase
		if ph >= 1 and ph <= 3 and B747DR_ap_flightPhase ~= ph
			and not (B747DR_ap_flightPhase == 0 and simDR_radarAlt1 < 1000) then
			B747DR_ap_flightPhase = ph
		end
	else
		local vn = afds.vnav_arm and 1 or 0
		if B747DR_ap_vnav_state ~= vn then B747DR_ap_vnav_state = vn end
		local p = afds.pitch
		local vs, al, fl = p == "VS" and 2 or 0, p == "ALT" and 2 or 0, p == "FLCH" and 2 or 0
		if p then
			if simDR_autopilot_vs_status ~= vs then simDR_autopilot_vs_status = vs end
			if simDR_autopilot_alt_hold_status ~= al then simDR_autopilot_alt_hold_status = al end
			if simDR_autopilot_flch_status ~= fl then simDR_autopilot_flch_status = fl end
			if p == "ALT" and afds.hold_alt and simDR_autopilot_hold_altitude_ft ~= afds.hold_alt then
				simDR_autopilot_hold_altitude_ft = afds.hold_alt
			end
		end
	end
	local att = afds.roll == "ATT" and afds.att_bank or 0
	if B747DR_ap_ATT ~= att then B747DR_ap_ATT = att end
	-- the approach (step 1d) on the old code's state: the approach mode (-1
	-- LOC, 1 APP), LOC's and G/S's status (1 armed, 2 engaged) for the old
	-- laws, lights and autoland, the MCP's heading to the course at LOC's
	-- capture (ATA22 p.290; the old APP switch set it at once)
	local nav = afds.roll == "LOC" and 2 or (afds.loc_arm and 1 or 0)
	local gs = afds.pitch == "GS" and 2 or (afds.gs_arm and 1 or 0)
	local app = gs > 0 and 1 or (nav > 0 and -1 or 0)
	if B747DR_ap_approach_mode ~= app then B747DR_ap_approach_mode = app end
	if simDR_autopilot_nav_status ~= nav then simDR_autopilot_nav_status = nav end
	if B747DR_autopilot_nav_status ~= nav then B747DR_autopilot_nav_status = nav end
	if simDR_autopilot_gs_status ~= gs then simDR_autopilot_gs_status = gs end
	if B747DR_autopilot_gs_status ~= gs then B747DR_autopilot_gs_status = gs end
	if B747_afds_model.loc_engaged_now(afds) then
		B747DR_ap_heading_deg = roundToIncrement(simDR_radio_nav_obs_deg[0], 1)
	end
	-- TO/GA (step 1e) on the old code's state: its TO/GA flag (its laws and
	-- A/T go by the FMA), the F/Ds shown (FCOM p.661)
	local tg = B747_afds_model.toga_active(afds) and 1 or 0
	if B747DR_autopilot_TOGA_status ~= tg then B747DR_autopilot_TOGA_status = tg end
	local auto = B747_afds_model.fd_auto(afds)
	local fc = (B747DR_toggle_switch_position[23] > 0.5 or auto) and 1 or 0
	local ff = (B747DR_toggle_switch_position[24] > 0.5 or auto) and 1 or 0
	if B747DR_ap_fd_shown_capt ~= fc then B747DR_ap_fd_shown_capt = fc end
	if B747DR_ap_fd_shown_fo ~= ff then B747DR_ap_fd_shown_fo = ff end
	-- the mode failures (step 5c; FCOM p.660): the FMA's amber lines; the
	-- F/Ds' bars with a mode on the FMA, not failed (the 109's and 405's
	-- bar of the failed axis goes, the 570's both: RR as PW, an estimate);
	-- AUTOPILOT (caution [4]: before, an undefined X-Plane failure's)
	local rf, pf = afds.roll_fail, afds.pitch_fail
	local both = afdsIn.engine == B747_afds_model.ENGINE_GE and (rf or pf)
	local v = rf and 1 or 0
	if B747DR_ap_FMA_roll_fail ~= v then B747DR_ap_FMA_roll_fail = v end
	v = pf and 1 or 0
	if B747DR_ap_FMA_pitch_fail ~= v then B747DR_ap_FMA_pitch_fail = v end
	v = (B747DR_ap_FMA_active_roll_mode >= 1 and not (rf or both)) and 1 or 0
	if B747DR_ap_fd_roll_bar ~= v then B747DR_ap_fd_roll_bar = v end
	v = (B747DR_ap_FMA_active_pitch_mode >= 1 and not (pf or both)) and 1 or 0
	if B747DR_ap_fd_pitch_bar ~= v then B747DR_ap_fd_pitch_bar = v end
	v = B747_afds_model.caution(afds) and 1 or 0
	if B747DR_CAS_caution_status[4] ~= v then B747DR_CAS_caution_status[4] = v end
	-- ILS TUNE INHIBIT and RA TEST INHIBIT (step 5d; ATA22 p.212; FCOM p.1305)
	v = B747_afds_model.ils_inhibit(afds, afdsIn) and 1 or 0
	if B747DR_ap_ils_tune_inhibit ~= v then B747DR_ap_ils_tune_inhibit = v end
	v = B747_afds_model.ra_test_inhibit(afds, afdsIn) and 1 or 0
	if B747DR_ap_ra_test_inhibit ~= v then B747DR_ap_ra_test_inhibit = v end
	-- the bus isolation request to BCU 1 (ELEC-18; ATA22 p.192)
	v = B747_afds_model.bus_isolate_request(afds) and 1 or 0
	if B747DR_ap_bus_isolate_req ~= v then B747DR_ap_bus_isolate_req = v end
end
-- the roll law (step 2a), each frame after the modes: the heading in the
-- reference (true north by the switch or in the polar areas, where NORM
-- gives HDG SEL and HDG HOLD no reference: FCOM p.1046), the track true
local function afds_roll_law()
	local r = afdsRollIn
	-- a failed roll mode holds the bank of then (step 5c: ATT's law)
	r.mode = afds.roll_fail and "ATT" or afds.roll
	r.active = B747_afds_model.engaged(afds) > 0 or B747DR_ap_fd_shown_capt == 1 or B747DR_ap_fd_shown_fo == 1
	r.ground = simDR_onGround == 1
	r.bank = simDR_AHARS_roll_deg_pilot
	r.ref_true = B747DR_ap_hdg_ref_true > 0.5
	r.hdg = r.ref_true and simDR_true_heading or simDR_ap_mag_psi
	r.hdg_valid = not (r.ref_true and B747DR_ap_toggle_sw[30] < 0.5)
	r.trk = (simDR_afds_track_mag + simDR_true_heading - simDR_ap_mag_psi) % 360
	r.sel = B747DR_ap_heading_deg
	r.held = afds.hold_hdg ~= nil
	r.att_bank = afds.roll_fail and afds.fail_bank or afds.att_bank
	r.lnav_bank = B747DR_fms_lnav_roll
	r.selector = B747DR_ap_bank_limit_sel_dial_pos
	r.tas = simDR_afds_tas
	r.ias = simDR_ind_airspeed_kts_pilot
	r.flaps_up = simDR_flap_ratio_control < 0.01
	r.v2 = B747DR_airspeed_V2
	afds_loc_inputs(r)
	-- runway align (step 4d): the AFDS model's, the heading magnetic
	r.rwy_align = afds.rwy_align and not afds.roll_fail
	r.hdg_mag = simDR_ap_mag_psi
	local cmd = B747_afds_roll_model.update(afdsRoll, r, SIM_PERIOD)
	local law, valid = cmd and 1 or 0, (cmd and afdsRoll.valid) and 1 or 0
	if B747DR_ap_roll_law ~= law then B747DR_ap_roll_law = law end
	if B747DR_ap_roll_valid ~= valid then B747DR_ap_roll_valid = valid end
	B747DR_ap_roll_cmd = cmd or 0
	-- ROLLOUT's and runway align's rudder with more than one channel (steps
	-- 4c and 4d; FCOM p.659, p.670)
	local rud = (afdsRoll.rudder and B747_afds_model.engaged(afds) >= 2) and afdsRoll.rudder or 0
	if B747DR_ap_rudder_cmd ~= rud then B747DR_ap_rudder_cmd = rud end
end
-- the pitch laws (steps 3a and 3b), each frame after the roll law
local function afds_pitch_law()
	local p = afdsPitchIn
	p.mode = afds.pitch
	p.active = afdsRollIn.active
	p.ground = simDR_onGround == 1
	p.hold_alt = afds.hold_alt
	-- a failed pitch mode holds the pitch of then (step 5c)
	p.att_pitch = afds.pitch_fail and afds.fail_pitch or nil
	afds_pitch_inputs(p)
	local cmd = B747_afds_pitch_model.update(afdsPitch, p, SIM_PERIOD)
	local law = cmd and 1 or 0
	if B747DR_ap_pitch_law ~= law then B747DR_ap_pitch_law = law end
	B747DR_ap_pitch_cmd = cmd or 0
end
-- the roll switches (step 1b)
function B747_afds_hdg_sel()
	B747_afds_model.hdg_sel(afds, afds_inp())
	afds_sync()
end
function B747_afds_hdg_hold(default)
	B747_afds_model.hdg_hold(afds, afds_inp(), default)
	afds_sync()
end
-- the approach switches (step 1d)
function B747_afds_loc()
	B747_afds_model.loc(afds, afds_inp())
	afds_sync()
end
function B747_afds_app()
	B747_afds_model.app(afds, afds_inp())
	afds_sync()
end
function B747_afds_lnav()
	B747_afds_model.lnav(afds, afds_inp())
	afds_sync()
end
-- the FMA's roll
function B747_afds_roll_fma()
	return B747_afds_model.roll_fma(afds, afds_inp())
end
-- the pitch switches (step 1c): the old code's own parts kept (the A/T,
-- its flight phase, its targets)
function B747_afds_vs()
	local sync = B747_afds_model.vs(afds, afds_inp())
	if not sync then return end
	simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
	B747DR_ap_thrust_mode = 0
	B747DR_ap_inVNAVdescent = 0
	B747DR_ap_flightPhase = B747DR_autopilot_altitude_ft > simDR_pressureAlt1 and 1 or 3
	simDR_autopilot_vs_fpm = sync
	B747DR_autopilot_vs_fpm = sync
	afds_sync()
end
function B747_afds_alt_hold()
	if not B747_afds_model.alt_hold(afds, afds_inp()) then return end
	B747DR_ap_thrust_mode = 0
	B747DR_ap_inVNAVdescent = 0
	B747DR_ap_flightPhase = 2
	afds_sync()
end
function B747_afds_flch()
	local ok, speed = B747_afds_model.flch(afds, afds_inp())
	if not ok then return end
	simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
	if speed and simDR_autopilot_airspeed_is_mach == 0 then
		B747DR_ap_ias_dial_value = math.floor(speed + 0.5)
	end
	B747DR_ap_inVNAVdescent = 0
	B747DR_ap_flightPhase = B747DR_autopilot_altitude_ft > simDR_pressureAlt1 and 1 or 3
	B747DR_ap_thrust_mode = 2
	afds_sync()
end
function B747_afds_vnav()
	B747_afds_model.vnav(afds, afds_inp())
	afds_sync()
end
-- VNAV's arm lost: the FMC's VNAV not valid (step 9c; before, no route for
-- the old VNAV)
function B747_afds_vnav_lost()
	B747_afds_model.vnav_lost(afds)
	B747DR_ap_vnav_state = 0
end
function B747_afds_spd_works()
	return B747_afds_model.spd_works(afds, afds_inp())
end
-- the FMA's pitch
function B747_afds_pitch_fma()
	return B747_afds_model.pitch_fma(afds, afds_inp())
end
-- the roll mode is HDG SEL (the HDG REF switch's default)
function B747_afds_roll_is(mode)
	return afds.roll == mode
end
-- a CMD switch pushed
local function afds_cmd(ch)
	B747CMD_fdr_log_apon:once()
	afds_apply(B747_afds_model.cmd(afds, ch, afds_inp()))
	afds_sync()
end
-- the old code's part of a disengage: X-Plane's servos (the A/T is not
-- the A/P's: before, a reset and re-engage 0.5 s later)
local function afds_disengaged()
	B747CMD_ap_reset:once()
	simCMD_autopilot_servos_off:once()
end
-- a control wheel A/P disengage switch pushed
local function afds_wheel()
	B747CMD_fdr_log_apdisconnect:once()
	local was = B747_afds_model.engaged(afds)
	B747_afds_model.wheel(afds)
	if was > 0 then afds_disengaged() end
	afds_sync()
end
-- the old code's go-around on G/A's engage, as its TO/GA switch did in the
-- air: its autoland's (until step 4) and its A/T's debounce
local function afds_go_around()
	B747DR_ap_autoland = -2
	B747DR_ap_lastCommand = simDRTime
end
-- each frame, first: a TO/GA push (step 1e), the F/Ds, the hydraulics, the
-- defaults asked for
function B747_afds_update()
	local inp = afds_inp()
	local n = B747DR_ap_toga_pushes
	if afdsTogaPushes ~= nil and n ~= afdsTogaPushes and B747_afds_model.toga(afds, inp) then afds_go_around() end
	afdsTogaPushes = n
	afds_apply(B747_afds_model.update(afds, inp))
	afds_sync()
	afds_roll_law()
	afds_pitch_law()
end
-- a new flight: the FCCs anew
function B747_afds_reset()
	afds = B747_afds_model.new()
	afdsRoll = B747_afds_roll_model.new()
	afdsPitch = B747_afds_pitch_model.new()
end
function B747_ap_thrust_mode_CMDhandler(phase, duration) -- INOP, NO CORRESPONDING FUNCTIONALITY IN X-PLANE
	if phase == 0 then
		B747_ap_button_switch_position_target[0] = 1
		-- a push to the A/T (the FMC's step 9f1: its THR REF; before, it
		-- disengaged the A/T)
		atPush.thr = atPush.thr + 1
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
		-- inactive in VNAV, FLCH SPD and TO/GA (FCOM p.642: the AFDS model,
		-- 6-3 step 1c; the old one ended VNAV and FLCH into V/S)
		if not B747_afds_spd_works() then return end
		B747DR_ap_lastCommand = simDRTime
		-- a push to the A/T (the FMC's step 9f1: its SPD)
		atPush.spd = atPush.spd + 1
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
		if B747_ap_button_switch_position_target[15] == 1 then
			B747_ap_button_switch_position_target[15] = 0
			return
		end
		B747_ap_button_switch_position_target[15] = 1 -- SET THE SPEED KNOB ANIMATION TO "IN"
		if B747DR_ap_vnav_state == 2 and B747DR_switchingIASMode==0 then
			setVNAVState("manualVNAVspd", 1 - getVNAVState("manualVNAVspd"))
			if getVNAVState("manualVNAVspd") == 0 then
				setVNAVState("gotVNAVSpeed", false)
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
			setVNAVState("gotVNAVSpeed", false)
			B747_vnav_speed()
		end

		if B747DR_ap_vnav_state == 2 then
			B747DR_ap_vnav_state = 3 --resume
		end
		if B747BR_totalDistance - B747BR_tod <= 50 then
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

		if B747_ap_button_switch_position_target[16] == 1 then
			B747_ap_button_switch_position_target[16] = 0
			return
		end

		B747_ap_button_switch_position_target[16] = 1 -- SET THE ALT KNOB ANIMATION TO "IN"

		if B747DR_autopilot_altitude_ft > B747BR_cruiseAlt then
			B747BR_cruiseAlt = B747DR_autopilot_altitude_ft
			print("set new cruise to "..B747BR_cruiseAlt)
			if is_timer_scheduled(update_new_crzalt) then
				stop_timer(update_new_crzalt)
			end
			run_after_time(update_new_crzalt, 2.0)
			B747DR_mcp_hold_pressed = simDRTime
			return
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
				setVNAVState("gotVNAVSpeed", false)
				B747_vnav_speed()
			end

			if B747DR_ap_vnav_state == 2 then
				B747DR_ap_vnav_state = 3 --resume
			end
			if B747BR_totalDistance - B747BR_tod <= 50 then
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
		-- the AFDS model (6-3 step 1c; the old one ended TO/GA's roll too)
		B747_afds_flch()
	elseif phase == 2 then
		B747_ap_button_switch_position_target[4] = 0
	end
end

function B747_ap_switch_vs_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_vs:once()
		B747_ap_button_switch_position_target[6] = 1
		-- the AFDS model (6-3 step 1c): synced to the present vertical speed
		-- (the old one set 0, and ended TO/GA's roll too)
		B747_afds_vs()
	elseif phase == 2 then
	--for autpilot
	end
end

function B747_ap_alt_hold_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_alt:once()
		B747_ap_button_switch_position_target[7] = 1
		-- the AFDS model (6-3 step 1c; the old one ended TO/GA's roll too)
		B747_afds_alt_hold()
	elseif phase == 2 then
		B747_ap_button_switch_position_target[7] = 0
	end
end


-- the CMD switches (6-3 step 1a): the AFDS model engages on the push
-- (the old code engaged L on the push, C and R on the release, and only
-- above 400 ft)
function B747_ap_switch_cmd_L_CMDhandler(phase, duration)
	if phase == 0 then
		B747_ap_button_switch_position_target[10] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
		afds_cmd("L")
	elseif phase == 2 then
		B747_ap_button_switch_position_target[10] = 0 -- SET THE BUTTON ANIMATION TO "UP"
	end
end

function B747_ap_switch_cmd_C_CMDhandler(phase, duration)
	if phase == 0 then
		B747_ap_button_switch_position_target[11] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
		afds_cmd("C")
	elseif phase == 2 then
		B747_ap_button_switch_position_target[11] = 0 -- SET THE BUTTON ANIMATION TO "UP"
	end
end

function B747_ap_switch_cmd_R_CMDhandler(phase, duration)
	if phase == 0 then
		B747_ap_button_switch_position_target[12] = 1 -- SET THE BUTTON ANIMATION TO "DOWN"
		afds_cmd("R")
	elseif phase == 2 then
		B747_ap_button_switch_position_target[12] = 0 -- SET THE BUTTON ANIMATION TO "UP"
	end
end

-- the disengage bar: down disengages all A/Ps and keeps them off, the F/Ds
-- keep their modes (FCOM p.640); lifting it does not reset AUTOPILOT DISC
-- (ATA22 p.380)
function B747_ap_switch_disengage_bar_CMDhandler(phase, duration) --disengage bar
	if phase == 0 then
		B747CMD_fdr_log_apdisconnect:once()
		B747_ap_button_switch_position_target[14] = 1.0 - B747_ap_button_switch_position_target[14]
		local down = B747_ap_button_switch_position_target[14] == 1.0
		local was = B747_afds_model.engaged(afds)
		B747_afds_model.bar(afds, down)
		if down and was > 0 then afds_disengaged() end
		afds_sync()
	end
end

-- the control wheel A/P disengage switches (FCOM p.655)
function B747_ap_switch_yoke_disengage_capt_CMDhandler(phase, duration)
	if phase == 0 then afds_wheel() end
end

function B747_ap_switch_yoke_disengage_fo_CMDhandler(phase, duration)
	if phase == 0 then afds_wheel() end
end

-- the control wheel stab trim switches with a single A/P engaged (the SRMs,
-- B747.45.xt.srm.lua, 4-1 step 2b): the A/P disengages (FCOM p.945; ATA22
-- p.142), an automatic disengagement, so AUTOPILOT DISC shows (FCOM 4.20)
function B747_ap_trim_disengage_CMDhandler(phase, duration)
	if phase == 0 then
		if B747_afds_model.engaged(afds) == 0 then return end
		B747CMD_fdr_log_apdisconnect:once()
		B747_afds_model.disengage(afds)
		afds_disengaged()
		afds_sync()
	end
end

-- the A/T disconnect switches: a push to the A/T (the FMC's step 9f1:
-- off with AUTOTHROT DISC, else its reset; before, they flipped its fail)
function B747_ap_switch_autothrottle_disco_L_CMDhandler(phase, duration)
	if phase == 0 then atPush.disc = atPush.disc + 1 end
end

function B747_ap_switch_autothrottle_disco_R_CMDhandler(phase, duration)
	if phase == 0 then atPush.disc = atPush.disc + 1 end
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
		-- (the A/T's TO is the A/T model's: the FMC's step 9f1)
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
		-- PERF/VNAV UNAVAILABLE without the gross weight, the cost index or
		-- CRZ ALT (FCOM p.1433; step 9c: the FMC's; before, CRZ ALT only)
		if B747DR_ap_fvn_perf ~= 1 then
			B747DR_fmc_notifications[30] = 1
			return
		end
		-- the AFDS model (6-3 step 1c): the arm, the second push; the active
		-- mode stays while it is armed (the old one forced ALT HOLD)
		B747_afds_vnav()
	elseif phase == 2 then
		B747_ap_button_switch_position_target[3] = 0
	end
end
function B747_ap_LNAV_mode_afterCMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_lnav:once();
		B747_ap_button_switch_position_target[2] = 1
		B747_afds_lnav()
	elseif phase == 2 then
		B747_ap_button_switch_position_target[2] = 0
	end
end
function B747_ap_switch_hdg_sel_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_headsel:once()
		B747_afds_hdg_sel()
		
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
B747CMD_ap_trim_disengage =
	deferred_command(
	"laminar/B747/autopilot/trim_disengage",
	"A/P Disengage by the Stab Trim Switches",
	B747_ap_trim_disengage_CMDhandler
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
function B747_ap_knots_mach_toggle_CMDhandler(phase, duration)
	if phase == 0 then
		B747_ap_button_switch_position_target[13] = 1
		if B747DR_ap_ias_mach_window_open == 1 then
			if simDR_airspeed_mach > 0.4 then
				B747DR_lastap_dial_airspeed = simDR_autopilot_airspeed_kts -- READ THE CURRENT AIRSPEED SETTING
				simDR_autopilot_airspeed_is_mach = 1 - simDR_autopilot_airspeed_is_mach -- SWAP THE MACH/KNOTS STATE
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			elseif simDR_airspeed_mach <= 0.4 and simDR_autopilot_airspeed_is_mach == 1 then
				B747DR_lastap_dial_airspeed = simDR_autopilot_airspeed_kts -- READ THE CURRENT AIRSPEED SETTING
				simDR_autopilot_airspeed_is_mach = 0 -- SWAP THE MACH/KNOTS STATE
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
		if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state > 0) then
			simDR_autopilot_heading_deg = ap_hdg_target(B747DR_ap_heading_deg)
		end
	elseif phase == 1 then
		if duration > 0.5 then
			--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg + 1), 360.0)	)
			B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg + 1), 360.0))
			if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state > 0) then
				simDR_autopilot_heading_deg = ap_hdg_target(B747DR_ap_heading_deg)
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
		if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state > 0) then
			simDR_autopilot_heading_deg = ap_hdg_target(B747DR_ap_heading_deg)
		end
	elseif phase == 1 then
		if duration > 0.5 then
			--simDR_autopilot_heading_deg =	math.floor(math.fmod((simDR_autopilot_heading_deg - 1), 360.0)	)
			--if simDR_autopilot_heading_deg < 0.0 then simDR_autopilot_heading_deg = simDR_autopilot_heading_deg + 360.0 end
			B747DR_ap_heading_deg = math.floor(math.fmod((B747DR_ap_heading_deg - 1), 360.0))
			if B747DR_ap_heading_deg < 0.0 then
				B747DR_ap_heading_deg = B747DR_ap_heading_deg + 360.0
			end
			if not (B747DR_ap_approach_mode ~= 0 and simDR_autopilot_nav_status ~= 2 and B747DR_ap_lnav_state > 0) then
				simDR_autopilot_heading_deg = ap_hdg_target(B747DR_ap_heading_deg)
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

function setSimAlt()
	--if B747DR_ap_vnav_state == 0 then
		simDR_autopilot_altitude_ft = B747DR_autopilot_altitude_ft
		print("set sim alt")
	--end
end

function B747_ap_altitude_up_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_autopilot_altitude_ft = math.min(50000.0, B747DR_autopilot_altitude_ft + 100)
		B747DR_ap_lastCommand = simDRTime + 1
		--if B747DR_ap_vnav_state == 0 then
			if is_timer_scheduled(setSimAlt) then
				stop_timer(setSimAlt)
			end
			run_after_time(setSimAlt, 3.0)
		--end
	elseif phase == 1 then
		if duration > 0.5 then
			B747DR_autopilot_altitude_ft = math.min(50000.0, B747DR_autopilot_altitude_ft + 100)
			B747DR_ap_lastCommand = simDRTime + 1
			--if B747DR_ap_vnav_state == 0 then
				if is_timer_scheduled(setSimAlt) then
					stop_timer(setSimAlt)
				end
				run_after_time(setSimAlt, 3.0)
			--end
		end
	end
end

function B747_ap_altitude_down_CMDhandler(phase, duration)
	if phase == 0 then
		B747DR_autopilot_altitude_ft = math.max(0.0, B747DR_autopilot_altitude_ft - 100)
		B747DR_ap_lastCommand = simDRTime + 1
		--if B747DR_ap_vnav_state == 0 then
			if is_timer_scheduled(setSimAlt) then
				stop_timer(setSimAlt)
			end
			run_after_time(setSimAlt, 3.0)
		--end
	elseif phase == 1 then
		if duration > 0.5 then
			B747DR_autopilot_altitude_ft = math.max(0.0, B747DR_autopilot_altitude_ft - 100)
			B747DR_ap_lastCommand = simDRTime + 1
			--if B747DR_ap_vnav_state == 0 then
				if is_timer_scheduled(setSimAlt) then
					stop_timer(setSimAlt)
				end
				run_after_time(setSimAlt, 3.0)
			--end
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

-- the MCP's heading for X-Plane's heading mode (magnetic): the MCP heading
-- is in the heading reference (5-2 step 5d; FCOM p.1046, ATA22 p.358: the
-- heading modes on the airplane's magnetic or true heading), so true north
-- makes it magnetic with the variation
function ap_hdg_target(sel)
	if B747DR_ap_hdg_ref_true < 0.5 then return sel end
	return (sel + ((simDR_ap_mag_psi - simDR_true_heading + 180) % 360 - 180)) % 360
end
-- the HDG REF switch moved while in HDG SEL: HDG HOLD (FCOM p.1046, ATA22
-- p.352)
local lastHdgRefSwitch=nil
function ap_hdg_ref_hold()
	local sw=B747DR_ap_toggle_sw[30] > 0.5
	if lastHdgRefSwitch~=nil and sw~=lastHdgRefSwitch and B747_afds_roll_is("HDG_SEL") then
		B747_afds_hdg_hold(true)
	end
	lastHdgRefSwitch=sw
end

----- ROUND TO INCREMENT ----------------------------------------------------------------
function roundToIncrement(numberToRound, increment)
	local y = numberToRound / increment
	local q = math.floor(y + 0.5)
	local z = q * increment

	return z
end

-- the HDG HOLD switch (6-3 step 1b): the model
function B747_ap_heading_hold_mode_CMDhandler(phase, duration)
	if phase == 0 then
		B747CMD_fdr_log_headhold:once()
		B747_ap_button_switch_position_target[5] = 1
		B747_afds_hdg_hold(false)
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

				-- not while ILS TUNE INHIBIT holds the frequency (6-3 step 5d;
				-- FCOM p.1305: before, the tuning went on after the capture)
				if string.len(targetILSS) > 0 and B747DR_ap_ils_tune_inhibit < 0.5 then
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
				elseif string.len(targetILSS) > 0 then
					targetDots = 1
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
		-- (not while ILS TUNE INHIBIT holds the frequency: 6-3 step 5d)
		if B747DR_ap_ils_tune_inhibit < 0.5 then
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
		end
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
	replace_command("sim/autopilot/heading_hold", B747_ap_heading_hold_mode_CMDhandler)
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
				B747DR_lastap_dial_airspeed = simDR_autopilot_airspeed_kts
				simDR_autopilot_airspeed_is_mach = 0 -- CHANGE TO KNOTS
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
				B747DR_lastap_dial_airspeed = simDR_autopilot_airspeed_kts
				--simDR_autopilot_airspeed_kts = ap_dial_airspeed								-- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				simDR_autopilot_airspeed_is_mach = 1 -- CHANGE TO KNOTS
				B747DR_ap_ias_mach_window_open = 0 -- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				B747DR_switchingIASMode = 1
				run_after_time(B747_updateIASWindow, 0.25) --update target
			end
		end
	end
	if simDR_autopilot_airspeed_kts > 310 and B747DR_switchingIASMode == 0 and B747DR_ap_vnav_state == 0 then
		if simDR_vvi_fpm_pilot < -250.0 then
			if ap_simDR_autopilot_airspeed_is_mach == 1 then
				B747DR_lastap_dial_airspeed = simDR_autopilot_airspeed_kts
				--simDR_autopilot_airspeed_kts = ap_dial_airspeed								-- WRITE THE NEW VALUE TO FORCE CONVERSION TO CORRECT UNITS
				simDR_autopilot_airspeed_is_mach = 0 -- CHANGE TO KNOTS
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
		local default_speed = 250 -- kt (FMC-21; the predictions come in step 8)
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

	local eod = endI
	local setTOD = false
	local setTOC = false
	local todDist = B747BR_totalDistance - B747BR_tod
	local vnavData={}
	local vnavI=1
	local lastVnavAlt=-9999
	--print("setDistances")
	local usedToD=false
	for i = 1, endI - 1, 1 do
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
		dtoAirport = getDistance(fmsO[i][5], fmsO[i][6], fmsO[endI][5], fmsO[endI][6])
		--print("i=".. i .." B747DR_fmscurrentIndex="..B747DR_fmscurrentIndex .." speed="..simDR_groundspeed .. " distance="..totalDistance.." dtoAirport="..dtoAirport.. " ".. fmsO[i][5].." ".. fmsO[i][6].." ".. fmsO[i+1][5].." ".. fmsO[i+1][6])
		if dtoAirport < 10 then
			eod = i
			--print("end fms"..i.."=at alt "..fms[i][3])
			break
		end
		if fmsO[i][9]>0 then
			--construct vnav profile
			--[[local isNext="false"
			if i==start then
				isNext="true"
			end]]--
			if fmsO[i][9]~=lastVnavAlt or i==start then
				local vAlt=0
				local tAlt=fmsO[i][9]
				if i>1 then
					local distance=getDistance(fmsO[i-1][5],fmsO[i-1][6], fmsO[i][5],fmsO[i][6])
					if fmsO[i][9]<lastVnavAlt and not(usedToD) and B747BR_totalDistance > 0 and B747BR_todLat ~=0 and B747BR_todLong ~=0 then
						distance=getDistance(B747BR_todLat,B747BR_todLong, fmsO[i][5],fmsO[i][6])
						usedToD=true
					end
					if distance>0.1 then
					  vAlt=(lastVnavAlt-fmsO[i][9])/distance
					else
						vAlt=0
						tAlt=lastVnavAlt
					end
				end
				local vNavdataI={fmsO[i][5],fmsO[i][6],tAlt,i>=start,vAlt}
				vnavData[vnavI]=vNavdataI
				vnavI=vnavI+1
				lastVnavAlt=fmsO[i][9]
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
	if B747BR_totalDistance<15 then
		local dtoAirport = getDistance(simDR_latitude, simDR_longitude, fmsO[endI][5], fmsO[endI][6])
		local glideAlt= dtoAirport*290 +fmsO[endI][9]
		B747BR_fpe	= simDR_pressureAlt1-glideAlt
	end
	B747BR_nextDistanceInFeet = nextDistanceInFeet
	local cruiseTOD = ((B747BR_cruiseAlt - fmsO[eod][3]) / 100) / 2.9
	local currentTOD = ((simDR_pressureAlt1 - fmsO[eod][3]) / 100) / 2.9
	
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
end

function B747_getCurrentWayPoint_function(fmsO)
	
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
	local canNew=true
	if B747DR_fmscurrentIndex>1 then
		local dToNext=getDistance(simDR_latitude,simDR_longitude,fmsO[B747DR_fmscurrentIndex][5],fmsO[B747DR_fmscurrentIndex][6])
		dFromLast=getDistance(simDR_latitude,simDR_longitude,fmsO[B747DR_fmscurrentIndex-1][5],fmsO[B747DR_fmscurrentIndex-1][6])
		trackLength=getDistance(fmsO[B747DR_fmscurrentIndex-1][5],fmsO[B747DR_fmscurrentIndex-1][6],fmsO[B747DR_fmscurrentIndex][5],fmsO[B747DR_fmscurrentIndex][6])
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
			if B747DR_ap_lnav_xtk_target>=-99 and track[2]>maxError and track[1]>math.min(5,trackLength/5) then
				B747DR_CAS_caution_status[66]=0 -- not from the cross-track (FMC-29): ANP above RNP, 6-1 step 10
			else
				B747DR_CAS_caution_status[66]=0
			end
		end
		
	end
	--print("Start Track Data "..minPhaseLeg.."->"..maxPhaseLeg)
	if canNew then
		for i = minPhaseLeg, maxPhaseLeg, 1 do --last is always the airport, never go past last track

			local dFromLast=0.1
			local trackLength=1
			local dToNext=getDistance(simDR_latitude,simDR_longitude,fmsO[i][5],fmsO[i][6])

			if i>1 then
				dFromLast=getDistance(simDR_latitude,simDR_longitude,fmsO[i-1][5],fmsO[i-1][6])
				trackLength=getDistance(fmsO[i-1][5],fmsO[i-1][6],fmsO[i][5],fmsO[i][6])
			else
				trackLength=dToNext+0.11
			end

			
			
			if trackLength>0.1 then
				local track=getTriSpaceSolver(trackLength,dFromLast,dToNext)
				
				local thisHeading=0
				if i>1 then
					thisHeading=getHeading(fmsO[i-1][5],fmsO[i-1][6],fmsO[i][5],fmsO[i][6])
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
						local headingChange=math.abs(getHeadingDifference(nextHeading,thisHeading))
						local pemptNext=B747_rescale(0,1,160,20,headingChange)
						pemptNext=math.min( pemptNext,8)
						pemptNext=B747_rescale(120,pemptNext/5,320,pemptNext,simDR_groundspeed)
						if track[1]>math.max((trackLength-pemptNext),0.5) then
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
		
		B747DR_ap_lnav_xtk_error=bestOffTrack
		--print("best Track to waypoint="..best.." / "..bestOffTrack)
		if best>0 and (best>B747DR_fmscurrentIndex or best<B747DR_fmscurrentIndex-1) and B747DR_fmscurrentIndex ~=best then
			B747_set_fms_current(best)
			B747DR_fmscurrentIndex = best
			if B747DR_ap_lnav_state == 2 then
				B747DR_ap_lnavHeading_mode = best
			end
			
			print("B747DR_fmscurrentIndex="..best)
			setVNAVState("recalcAfter", best)
		elseif B747DR_fmscurrentIndex == 0 and maxPhaseLeg>2 and fmsO[2][2]~=2048 then
			B747DR_fmscurrentIndex = 2
			B747_set_fms_current(2)
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

function B747_getCurrentWayPoint_default(fmsO)
	B747DR_ap_lnavHeading_mode = 0
	for i = 1, table.getn(fmsO), 1 do
		--print("FMS j="..fmsJSON)

		if fmsO[i][10] == true then
			B747DR_fmscurrentIndex = i
			B747DR_ap_lnavHeading_mode = B747DR_fmscurrentIndex
			if i>1 then
				local dFromLast=getDistance(simDR_latitude,simDR_longitude,fmsO[i-1][5],fmsO[i-1][6])
				local dToNext=getDistance(simDR_latitude,simDR_longitude,fmsO[i][5],fmsO[i][6])
				local trackLength=getDistance(fmsO[i-1][5],fmsO[i-1][6],fmsO[i][5],fmsO[i][6])
				local track=getTriSpaceSolver(trackLength,dFromLast,dToNext)
				B747DR_ap_lnav_xtk_error=track[2]
				--print("Track Data "..track[1].." "..track[2].." "..dFromLast.." "..dToNext.." "..trackLength)
			end
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
	-- the FMC's VNAV not valid (step 9c; before, no route for the old
	-- VNAV): the arm ends (the AFDS model ends VNAV engaged: afds_inp's
	-- vnav_engaged)
	if B747DR_ap_vnav_state > 0 and B747DR_ap_fvn_valid ~= 1 then
		B747_afds_vnav_lost()
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
		-- the AFDS model (6-3 step 1d): LOC and G/S armed, the second push;
		-- with no ILS too (the old one posted RW/ILS CRS ERROR, the FMC's
		-- message for an ILS course not the runway's); the MCP's heading to
		-- the course at LOC's capture (the old switch set it at once); with a
		-- channel engaged the others armed for multi-channel (step 4a; before,
		-- all engaged at once)
		B747_afds_app()
		B747DR_ap_lastCommand = simDRTime
	elseif phase == 2 then
		B747_ap_button_switch_position_target[9] = 0 -- SET THE LOC SWITCH ANIMATION TO "OUT"
	end
end

function B747_ap_switch_loc_mode_CMDhandler(phase, duration)
	if phase == 0 then
		--simCMD_autopilot_nav_mode:once()
		B747CMD_fdr_log_loc:once()
		B747_ap_button_switch_position_target[8] = 1
		-- the AFDS model (6-3 step 1d): armed, the second push, a localizer
		-- approach from APP; with no ILS too (the old one posted RW/ILS CRS
		-- ERROR)
		B747_afds_loc()
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
	-- the approach's modes and channels are the AFDS model's (6-3 steps 1d
	-- and 4a)
end



----- FLIGHT MODE ANNUNCIATORS ----------------------------------------------------------

-- (the old autoland, B747.autoland.lua, is gone: 6-3 step 4c)
dofile("B747.70.xt.autopilot.monitor.lua")
function fma_rollModes()
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	if numAPengaged>0 or B747DR_ap_fd_shown_capt == 1 or B747DR_ap_fd_shown_fo == 1 then
		B747BR_showFMA=1
	else
		B747BR_showFMA=0
	end
	-- everything off with neither the A/P nor a F/D (FCOM p.660; the AFDS
	-- model clears the old state as it happens: 6-3 step 1a)
	if numAPengaged == 0 and B747DR_ap_fd_shown_capt == 0 and B747DR_ap_fd_shown_fo == 0 then
		B747DR_ap_FMA_armed_roll_mode = 0
		B747DR_ap_FMA_active_roll_mode = 0
		return
	end
	-- the AFDS model's roll modes (6-3 step 1b), the old LOC and TO/GA
	-- first, the old arms of LOC and ROLLOUT after LNAV's
	B747DR_ap_FMA_active_roll_mode, B747DR_ap_FMA_armed_roll_mode = B747_afds_roll_fma()
end
local restoreAlt=0
function restoreAltFunc()
	simDR_autopilot_altitude_ft=restoreAlt
end
-- the approach's states are the AFDS model's (6-3 step 1d: its sync
-- writes them; the old latch with a F/D ON and its "recover" are gone)
function glideSlopeLOCProgress()
end
function fma_PitchModes()
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	-- everything off with neither the A/P nor a F/D (FCOM p.660; the old
	-- capture window showed ALT near the MCP altitude without a mode)
	if numAPengaged == 0 and B747DR_ap_fd_shown_capt == 0 and B747DR_ap_fd_shown_fo == 0 then
		B747DR_ap_FMA_armed_pitch_mode = 0
		B747DR_ap_FMA_active_pitch_mode = 0
		return
	end
	-- the old G/S (until 6-3 step 1d) ends VNAV
	if B747DR_autopilot_gs_status == 2 then
		B747DR_ap_vnav_state = 0
		B747DR_ap_inVNAVdescent = 0
		B747DR_ap_flightPhase = 4
		B747DR_ap_thrust_mode = 0
	end
	-- the AFDS model's pitch modes (6-3 step 1c), the old G/S and TO/GA
	-- first, VNAV's sub-mode the old VNAV's
	local active, armed = B747_afds_pitch_fma()
	-- on the ground only TO/GA: the old pitch law goes by this number and
	-- would move the elevator for V/S or ALT with the A/P engaged on the
	-- ground (as the old FMA did, until 6-3 step 3)
	if simDR_onGround == 1 and active ~= 1 then active = 0 end
	B747DR_ap_FMA_active_pitch_mode, B747DR_ap_FMA_armed_pitch_mode = active, armed
end

function B747_ap_fma(fms)
	-- the flight directors' roll: the roll laws' command (6-3 steps 2a and
	-- 2b; NCD centred until the mode failures, step 5), else X-Plane's (none
	-- of the modes now)
	local fdRoll = B747DR_ap_target_roll
	if B747DR_ap_roll_law == 1 then
		fdRoll = B747DR_ap_roll_valid == 1 and B747DR_ap_roll_cmd or simDR_capt_roll
	end
	B747DR_capt_ap_roll = B747_animate_value(B747DR_capt_ap_roll, fdRoll - simDR_capt_roll, -25, 25, 10)
	B747DR_fo_ap_roll = B747_animate_value(B747DR_fo_ap_roll, fdRoll - simDR_fo_roll, -25, 25, 10)
	--B747DR_capt_ap_roll=B747DR_ap_target_roll-simDR_capt_roll
	--B747DR_fo_ap_roll=B747DR_ap_target_roll-simDR_fo_roll
	glideSlopeLOCProgress()
	-- (the old autoland is gone, 6-3 step 4c: FLARE, NOSE LETDOWN, the
	-- retard and ROLLOUT are the AFDS model's; before, with LAND 3 or 2 it
	-- returned here and the FMAs froze at the LAND's engage)
	local numAPengaged = B747DR_ap_cmd_L_mode + B747DR_ap_cmd_C_mode + B747DR_ap_cmd_R_mode
	-- the A/T and its FMA (the FMC's step 9f1: afds_at; before, an if chain
	-- here over the flags the A/T's writers had left)
	afds_at()

	-- (LNAV engages in the AFDS model: 6-3 step 1b)

	if B747DR_ap_fd_shown_capt == 0 and B747DR_ap_fd_shown_fo == 0 and numAPengaged == 0 then
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
		if B747DR_ap_fd_shown_capt == 1 then
			B747DR_ap_AFDS_status_annun_pilot = value
		else
			B747DR_ap_AFDS_status_annun_pilot = 0
		end
		if B747DR_ap_fd_shown_fo == 1 then
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
	-- (the engage state is the AFDS model's: 6-3 step 1a)
	if numAPengaged == 0 then
		B747DR_ap_autoland = 0
	end
	-- the AFDS model's status (6-3 step 4a): FD, CMD, or below 1,500 ft in
	-- a multi-channel approach LAND 3, LAND 2 or NO AUTOLAND (before, LAND
	-- 3 and 2 by the channels engaged only, and NO AUTOLAND for a single
	-- channel approach below 1,500 ft)
	local status = B747_afds_model.status(afds)
	set_afds_status(status)
	-- the autoland capability's EICAS message (step 5b) at the model's level:
	-- NO AUTOLAND caution [49] or advisory [246], NO LAND 3 caution [50] or
	-- advisory [248] (B747.87.xt.warning.lua). Before, the advisory [246]
	-- came with the PFD's NO AUTOLAND and nothing else
	local a, lv = afds.alert, afds.alert_level
	local function put(arr, i, on)
		local v = on and 1 or 0
		if arr[i] ~= v then arr[i] = v end
	end
	put(B747DR_CAS_caution_status, 49, a == "NO_AUTOLAND" and lv == "caution")
	put(B747DR_CAS_caution_status, 50, a == "NO_LAND3" and lv == "caution")
	put(B747DR_CAS_advisory_status, 246, a == "NO_AUTOLAND" and lv == "advisory")
	put(B747DR_CAS_advisory_status, 248, a == "NO_LAND3" and lv == "advisory")
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
			if B747DR_ap_fd_shown_capt == 1 then
				B747DR_ap_AFDS_mode_box_status_pilot = 1
			else
				B747DR_ap_AFDS_mode_box2_status_pilot = 0
			end -- SHOW THE MODE CHANGE BOX
			if B747DR_ap_fd_shown_fo == 1 then
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
			if B747DR_ap_fd_shown_capt == 1 then
				B747DR_ap_AFDS_mode_box2_status_pilot = 1
			end -- SHOW THE MODE CHANGE BOX
			if B747DR_ap_fd_shown_fo == 1 then
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
	B747_afds_model.disengage(afds, true)
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
	if B747DR_ap_activate_target_heading_deg==1 then
		B747DR_ap_activate_target_heading_deg=0
		B747_afds_hdg_sel()
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
	-- >AUTOPILOT: the AFDS model's (6-3 step 5c, afds_sync)

	--print("test drag required".. B747DR_speedbrake_lever .. " " .. simDR_all_wheels_on_ground .. " " .. simDR_autopilot_vs_fpm .. " " .. simDR_autopilot_vs_status .. " " )
	-- >AUTOTHROT DISC: the A/T's latch (the FMC's step 9f1; before, its
	-- fail flag: every reverse landing, any disconnect push)
	local disc = atState.disc and 1 or 0
	if B747DR_CAS_caution_status[5] ~= disc then B747DR_CAS_caution_status[5] = disc end

	if
		B747DR_speedbrake_lever < 0.3 and simDR_ind_airspeed_kts_pilot > (simDR_autopilot_airspeed_kts + 10) and
			simDR_ind_airspeed_kts_pilot > last_airspeed and
			-- (step 9c: VNAV on the FMC's descent path)
			(simDR_autopilot_vs_status >= 1 or B747DR_ap_inDescent == 1) and
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
	B747DR_ap_ias_dial_value = 200
	simDR_autopilot_heading_deg = 0.0
	simDR_autopilot_vs_fpm = 0.0
	simDR_autopilot_altitude_ft = 10000.0
	B747DR_autopilot_altitude_ft = 10000.0
	-- no flap target: the dataref is made at 0, flaps UP to B747_ap_target_flaps,
	-- which took the handle of a flight starting with flaps out to UP
	B747DR_ap_target_flaps = -1
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
	B747_afds_reset()
	B747_flight_start_autopilot()
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
-- the last strings decoded and X-Plane's flight plan decoded (locals: a
-- table in a global would be copied by XTLua)
local lastFMSdataSTR, lastFMSSTR, lastFMS
function after_physics()
	if hasSimConfig() == false then
		return
	end
	if debug_autopilot > 0 then
		return
	end
	simDR_allThrottle=math.max(B747DR_throttle[0],B747DR_throttle[1],B747DR_throttle[2],B747DR_throttle[3])
	ap_hdg_ref_hold()
	B747_afds_update()
	local cHeading = simDR_AHARS_heading_deg_pilot --constant refresh of data
	local tHeading = simDR_autopilot_heading_deg --constant refresh of data
	local headingStatus = simDR_autopilot_heading_hold_status --constant refresh of data
	local groundspeed = simDR_groundspeed
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
	-- the FMC's data and X-Plane's flight plan decoded when they change, not
	-- every frame, and no full garbage collection every frame (FMC-40, 6-1
	-- step 1); nothing here changes the decoded tables
	local fmsDataSTR = B747DR_FMSdata
	if fmsDataSTR ~= lastFMSdataSTR then
		lastFMSdataSTR = fmsDataSTR
		fmsData = json.decode(string.len(fmsDataSTR) > 0 and fmsDataSTR or "[]")
	end
	local fmsSTR = fmsJSON
	if fmsSTR ~= lastFMSSTR then
		lastFMSSTR = fmsSTR
		lastFMS = json.decode(fmsSTR)
	end
	local fms = lastFMS
	-- the FMC sequences its active route and sets the current waypoints
	-- itself (6-1/6-2 step 6c): X-Plane's FMS does not advance; the best
	-- track only without the FMC's
	if B747DR_fms_lnav_route == 1 then
		if simDR_override_fms_progress ~= 1 then simDR_override_fms_progress = 1 end
	else
		B747_getCurrentWayPoint(fms)
	end
	B747_monitorAP(fms)
	B747_ap_fma(fms)
	B747_ap_button_switch_animation()
	B747_fltmgmt_setILS(fms)
	B747_ap_vs_mode()
	B747_ap_ias_mach_mode()
	B747_ap_altitude(fms)
	afds_fmc_vnav()
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
end

--function after_replay() end

--*************************************************************************************--
--** 				               SUB-MODULE PROCESSING       	        			 **--
--*************************************************************************************--

-- dofile("")
