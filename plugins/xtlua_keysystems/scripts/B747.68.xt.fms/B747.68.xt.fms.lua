--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks CC-BY-NC4
*****************************************************************************************
]]
fmsLoadDref=find_dataref("xtlua/loadtoFMS")
simDR_inReplay              = find_dataref("sim/time/is_in_replay")
B747DR_fdr_log_json     = find_dataref("laminar/B747/fdr/json")
simDRTime=find_dataref("sim/time/total_running_time_sec")
simDR_onGround=find_dataref("sim/flightmodel/failures/onground_any")
simDR_vvi_fpm_pilot = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_pressureAlt1	= find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_eng_fuel_flow_kg_sec = find_dataref("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")
B747DR_ap_flightPhase = find_dataref("laminar/B747/autopilot/flightPhase")
B747DR_fms_setCurrent = find_dataref("xtlua/currentFMS")
B747DR_ap_lnavHeading_mode     	= find_dataref("laminar/B747/autopilot/lnavHeading_mode")
B747DR_acfType               = find_dataref("laminar/B747/acfType")
B747DR_payload_weight               = find_dataref("sim/flightmodel/weight/m_fixed")
simDR_acf_m_jettison  		=find_dataref("sim/aircraft/weight/acf_m_jettison")
simDR_m_jettison  		=find_dataref("sim/flightmodel/weight/m_jettison")
B747DR_CAS_advisory_status       = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_ap_vnav_system            = find_dataref("laminar/B747/autopilot/vnav_system")
B747DR_ap_vnav_pause            = find_dataref("laminar/B747/autopilot/vnav_pause")
simDR_nav1Freq			 =find_dataref("sim/cockpit/radios/nav1_freq_hz")
simDR_nav2Freq			 =find_dataref("sim/cockpit/radios/nav2_freq_hz")
B747DR_iru_status         	= find_dataref("laminar/B747/flt_mgmt/iru/status")
B747DR_iru_mode_sel_pos         = find_dataref("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos")
simDR_version=find_dataref("sim/version/xplane_internal_version")
B747DR_rtp_C_off 		 = find_dataref("laminar/B747/comm/rtp_C/off_status")
B747DR_pfd_mode_capt		 = find_dataref("laminar/B747/pfd/capt/irs")
B747DR_pfd_mode_fo		 = find_dataref("laminar/B747/pfd/fo/irs")
B747DR_irs_src_fo		 = find_dataref("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos")
B747DR_irs_src_capt		 = find_dataref("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos")
B747DR_ap_fpa	    = find_dataref("laminar/B747/autopilot/navadata/fpa")
B747DR_ap_vb	    = find_dataref("laminar/B747/autopilot/navadata/vb")
simDR_autopilot_vs_fpm         			= find_dataref("sim/cockpit2/autopilot/vvi_dial_fpm")
B747DR_ap_lnav_xtk_error           	= find_dataref("laminar/B747/autopilot/lnav/xtk_error")
B747DR_ap_lnav_xtk_target           	= find_dataref("laminar/B747/autopilot/lnav/xtk_target")
B747DR_fmc_notifications            = find_dataref("laminar/B747/fms/notification")
B747DR_airspeed_Vref                          = find_dataref("laminar/B747/airspeed/Vref")
B747DR_airspeed_VrefFlap                          = find_dataref("laminar/B747/airspeed/VrefFlap")
B747DR_altimter_ft_adjusted                     = find_dataref("laminar/B747/altimeter/ft_adjusted")
B747BR_eod_index 			= find_dataref("laminar/B747/autopilot/dist/eod_index")
B747DR_TAS_pilot			  =find_dataref("laminar/B747/nd/TAS_pilot")
B747DR_engine_used_fuel       = find_dataref("laminar/B747/fuel/totaliser")
simDR_autopilot_airspeed_is_mach	= find_dataref("sim/cockpit2/autopilot/airspeed_is_mach")
simDR_autopilot_airspeed_kts_mach   	= find_dataref("sim/cockpit2/autopilot/airspeed_dial_kts_mach")
simDR_autopilot_airspeed_kts   		= find_dataref("sim/cockpit2/autopilot/airspeed_dial_kts")
B747DR_elec_ext_pwr1_available      = find_dataref("laminar/B747/electrical/ext_pwr1_avail")
simDR_xpdr_code         = find_dataref("sim/cockpit2/radios/actuators/transponder_code")
--Workaround for stack overflow in init.lua namespace_read


function replace_char(pos, str, r)
    return str:sub(1, pos-1) .. r .. str:sub(pos+1)
end
function hasChild(parent,childKey)
  if(parent==nil) then
    return false
  end
  local keyFuncs=rawget(parent,'values')
  if keyFuncs==nil then return false end
  local keyFunc=rawget(keyFuncs,childKey)
  if keyFunc==nil then return false end
 
  return true
end
function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function str_trim(s)
	return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end
function string.starts(String,Start)
	return string.sub(String,1,string.len(Start))==Start
 end 
function round(x)
	return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
  end
function cleanFMSLine(line)
    local retval=line:gsub("☐","*")
    retval=retval:gsub("°","`")
	retval=retval:gsub("[%[%]]"," ")
	--retval=retval:gsub("]"," ")
    return retval
end 
function getHeadingDifference(desireddirection,current_heading)
	error = current_heading - desireddirection
	if (error >  180) then error =error- 360 end
	if (error < -180) then error =error+ 360 end
	return error
end
function getHeadingDifferenceM(desireddirection,current_heading)
	error = current_heading - desireddirection
	if (error >  180) then error =error- 360 end
	if (error < -180) then error =error+ 360 end
	if error<0 then error = error *-1 end
	return error
end
function getDistance(lat1,lon1,lat2,lon2)
  alat=math.rad(lat1)
  alon=math.rad(lon1)
  blat=math.rad(lat2)
  blon=math.rad(lon2)
  av=math.sin(alat)*math.sin(blat) + math.cos(alat)*math.cos(blat)*math.cos(blon-alon)
  if av > 1 then av=1 end
  retVal=math.acos(av) * 3440
  --print(lat1.." "..lon1.." "..lat2.." "..lon2)
  --print("Distance = "..retVal) 
  return retVal
end

-- degrees and minutes with tenths (N35`45.9, E140`23.2), rounded to the
-- tenth (step 7e: they were cut, so 35.3 showed N35`17.9); the minutes
-- from the size of the value (NAV-23: they came from the signed value,
-- wrong west and south)
function toDMS(value,isLat)
  local tenths=math.floor(math.abs(value)*600+0.5)
  local degrees=math.floor(tenths/600)
  local minutes=(tenths%600)/10
  local p="E"
  if isLat==true and value<0 then 
    p="S"
  elseif isLat==true then  
    p="N"
  elseif value<0 then
    p="W"
  end
  local retVal
  if isLat==true then
  	retVal=string.format(p .. "%02d`%04.1f",degrees,minutes)
  else
	retVal=string.format(p .. "%03d`%04.1f",degrees,minutes)
  end
  return retVal
end

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
dofile("json/json.lua")
hh=find_dataref("sim/cockpit2/clock_timer/zulu_time_hours")
mm=find_dataref("sim/cockpit2/clock_timer/zulu_time_minutes")
ss=find_dataref("sim/cockpit2/clock_timer/zulu_time_seconds")
simDR_bus_volts               = find_dataref("sim/cockpit2/electrical/bus_volts")
simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")

simDR_instrument_brightness_switch  = find_dataref("sim/cockpit2/switches/instrument_brightness_ratio")
simDR_instrument_brightness_ratio   = find_dataref("sim/cockpit2/electrical/instrument_brightness_ratio_manual")

simDR_radio_nav_freq_Mhz            = find_dataref("sim/cockpit2/radios/actuators/nav_frequency_Mhz")
simDR_radio_nav_freq_khz            = find_dataref("sim/cockpit2/radios/actuators/nav_frequency_khz")
simDR_radio_nav_freq_hz             = find_dataref("sim/cockpit2/radios/actuators/nav_frequency_hz")

simDR_radio_nav_course_deg          = find_dataref("sim/cockpit2/radios/actuators/nav_course_deg_mag_pilot")
simDR_radio_nav_obs_deg             = find_dataref("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot")
simDR_radio_nav1_obs_deg             = find_dataref("sim/cockpit/radios/nav1_obs_degt")
simDR_radio_nav2_obs_deg             = find_dataref("sim/cockpit/radios/nav2_obs_degt")
simDR_radio_nav_horizontal          = find_dataref("sim/cockpit2/radios/indicators/nav_display_horizontal")
simDR_radio_nav_hasDME              = find_dataref("sim/cockpit2/radios/indicators/nav_has_dme")
simDR_radio_nav_radial		    = find_dataref("sim/cockpit2/radios/indicators/nav_bearing_deg_mag")
simDR_radio_nav01_ID                = find_dataref("sim/cockpit2/radios/indicators/nav1_nav_id")
simDR_radio_nav02_ID                = find_dataref("sim/cockpit2/radios/indicators/nav2_nav_id")
simDR_radio_nav03_ID                = find_dataref("sim/cockpit2/radios/indicators/nav3_nav_id")
simDR_radio_nav04_ID                = find_dataref("sim/cockpit2/radios/indicators/nav4_nav_id")

simDR_radio_adf1_freq_hz            = find_dataref("sim/cockpit2/radios/actuators/adf1_frequency_hz")
simDR_radio_adf2_freq_hz            = find_dataref("sim/cockpit2/radios/actuators/adf2_frequency_hz")

simDR_fueL_tank_weight_total_kg     = find_dataref("sim/flightmodel/weight/m_fuel_total")

navAidsJSON   = find_dataref("xtlua/navaids")
fmsJSON = find_dataref("xtlua/fms")
-- X-Plane's flight plan decoded when it changes (FMC-40, 6-1 step 1); the
-- callers do not change it
local fmsRouteSTR, fmsRoute = nil, {}
function fms_route()
	local s = fmsJSON
	if s ~= fmsRouteSTR then
		fmsRouteSTR = s
		fmsRoute = string.len(s) > 2 and json.decode(s) or {}
	end
	return fmsRoute
end
fmsFlightPlan = find_dataref("xtlua/fltpln")

B747DR_fms1_display_mode            = find_dataref("laminar/B747/fms1/display_mode")

B747DR_init_fmsL_CD                 = find_dataref("laminar/B747/fmsL/init_CD")
ilsData=deferred_dataref("laminar/B747/radio/ilsData", "string")
acars=deferred_dataref("laminar/B747/comm/acars","number")  
toderate=deferred_dataref("laminar/B747/engine/derate/TO","number") 
clbderate=deferred_dataref("laminar/B747/engine/derate/CLB","number")
B747DR_radioModes=deferred_dataref("laminar/B747/radio/tuningmodes", "string")
B747DR_FMSdata=deferred_dataref("laminar/B747/fms/data", "string")
B747DR_ap_vnav_state                = find_dataref("laminar/B747/autopilot/vnav_state")
simDR_autopilot_vs_status          = find_dataref("laminar/B747/autopilot/vvi_status")
B747BR_totalDistance 			= find_dataref("laminar/B747/autopilot/dist/remaining_distance")
B747BR_nextDistanceInFeet 		= find_dataref("laminar/B747/autopilot/dist/next_distance_feet")
B747BR_cruiseAlt 			= find_dataref("laminar/B747/autopilot/dist/cruise_alt")
B747BR_tod				= find_dataref("laminar/B747/autopilot/dist/top_of_descent")
B747BR_toc				= find_dataref("laminar/B747/autopilot/dist/distance_to_toc")
B747DR__gear_chocked           = find_dataref("laminar/B747/gear/chocked")
B747DR_fuel_preselect		= find_dataref("laminar/B747/fuel/preselect")
B747DR_refuel				= find_dataref("laminar/B747/fuel/refuel")
B747DR_fuel_add				= find_dataref("laminar/B747/fuel/add_fuel")
B747DR_airspeed_Vmc = find_dataref("laminar/B747/airspeed/Vmc")
B747DR_ap_ATT     	                = find_dataref("laminar/B747/autopilot/att_rate")

B747DR_efis_min_ref_alt_capt_sel_dial_pos       = find_dataref("laminar/B747/efis/min_ref_alt/capt/sel_dial_pos")
B747DR_efis_ref_alt_capt_set_dial_pos           = find_dataref("laminar/B747/efis/ref_alt/capt/set_dial_pos")
B747DR_efis_dh_reset_capt_switch_pos            = find_dataref("laminar/B747/efis/dh_reset/capt/switch_pos")
B747DR_efis_baro_ref_capt_sel_dial_pos          = find_dataref("laminar/B747/efis/baro_ref/capt/sel_dial_pos")
B747DR_efis_baro_std_capt_switch_pos            = find_dataref("laminar/B747/efis/baro_std/capt/switch_pos")
B747DR_efis_baro_capt_set_dial_pos              = find_dataref("laminar/B747/efis/baro/capt/set_dial_pos")
B747DR_efis_baro_capt_preselect                 = find_dataref("laminar/B747/efis/baro/capt/preselect")
B747DR_efis_baro_alt_ref_capt                   = find_dataref("laminar/B747/efis/baro_ref/capt")

B747DR_efis_min_ref_alt_fo_sel_dial_pos         = find_dataref("laminar/B747/efis/min_ref_alt/fo/sel_dial_pos")
B747DR_efis_ref_alt_fo_set_dial_pos             = find_dataref("laminar/B747/efis/ref_alt/fo/set_dial_pos")
B747DR_efis_dh_reset_fo_switch_pos              = find_dataref("laminar/B747/efis/dh_reset/fo/switch_pos")
B747DR_efis_baro_ref_fo_sel_dial_pos            = find_dataref("laminar/B747/efis/baro_ref/fo/sel_dial_pos")
B747DR_efis_baro_std_fo_switch_pos              = find_dataref("laminar/B747/efis/baro_std/fo/switch_pos")
B747DR_efis_baro_fo_set_dial_pos                = find_dataref("laminar/B747/efis/baro/fo/set_dial_pos")
B747DR_efis_baro_fo_preselect                   = find_dataref("laminar/B747/efis/baro/fo/preselect")
B747DR_efis_baro_alt_ref_fo                     = find_dataref("laminar/B747/efis/baro_ref/fo")
-- the CDU's BARO SET entry (5-2 step 4b): STD as the EFIS control panel's push
B747DR_efis_baro_std_capt_show_preselect        = find_dataref("laminar/B747/efis/baro_std/capt/show_preselect")
B747DR_efis_baro_std_fo_show_preselect          = find_dataref("laminar/B747/efis/baro_std/fo/show_preselect")
-- the CDU's own entries to the STD push and MINS RST: they work with the
-- EFIS control panel failed (5-2 step 5c)
B747CMD_fms_baro_std_capt                       = find_command("laminar/B747/efis/baro_std/capt/cdu")
B747CMD_fms_baro_std_fo                         = find_command("laminar/B747/efis/baro_std/fo/cdu")
B747CMD_fms_dh_reset_capt                       = find_command("laminar/B747/efis/dh/capt/cdu_reset")
B747CMD_fms_dh_reset_fo                         = find_command("laminar/B747/efis/dh/fo/cdu_reset")


simDR_EFIS_1_sel_pilot              = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_pilot")
simDR_EFIS_1_sel_fo              = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_copilot")
simDR_EFIS_2_sel_pilot                 = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_pilot")
simDR_EFIS_2_sel_fo                 = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_copilot")
B747DR_nd_capt_terr                          = deferred_dataref("laminar/B747/nd/data/capt/terr", "number")
B747DR_nd_fo_terr                          	= deferred_dataref("laminar/B747/nd/data/fo/terr", "number")
B747DR_nd_capt_vor_ndb                          = find_dataref("laminar/B747/nd/data/capt/vor_ndb")
B747DR_nd_capt_wpt							= find_dataref("laminar/B747/nd/data/capt/wpt")
B747DR_nd_fo_vor_ndb                          	= find_dataref("laminar/B747/nd/data/fo/vor_ndb")
B747DR_nd_fo_wpt                          	= find_dataref("laminar/B747/nd/data/fo/wpt")
B747DR_nd_capt_apt	                        = find_dataref("laminar/B747/nd/data/capt/apt")
B747DR_nd_fo_apt	                        = find_dataref("laminar/B747/nd/data/fo/apt")
B747DR_nd_fo_ftc	                        = find_dataref("laminar/B747/nd/fo/tfc")
B747DR_nd_capt_ftc	                        = find_dataref("laminar/B747/nd/capt/tfc")
B747DR_nd_capt_traffic_Selected                 = find_dataref("laminar/B747/nd/traffic/capt/selected")
B747DR_nd_fo_traffic_Selected                   = find_dataref("laminar/B747/nd/traffic/fo/selected")
B747DR_nd_wxr	                        = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on")
-- 5-2 step 5c: the CDU's EFIS CONTROL and OPTIONS on that CDU's side, with
-- the EFIS control panel failed (FCOM p.1060-1065)
B747DR_fms_efis_fail                            = find_dataref("laminar/B747/efis/fail")
B747DR_fms_dsp_fail                             = find_dataref("laminar/B747/dsp/fail")
B747DR_nd_capt_data                             = find_dataref("laminar/B747/nd/data/capt/data")
B747DR_nd_fo_data                               = find_dataref("laminar/B747/nd/data/fo/data")
B747DR_nd_capt_pos                              = find_dataref("laminar/B747/nd/data/capt/pos")
B747DR_nd_fo_pos                                = find_dataref("laminar/B747/nd/data/fo/pos")
B747DR_efis_fpv_capt_selected                   = find_dataref("laminar/B747/efis/fpv/capt/selected")
B747DR_efis_fpv_fo_selected                     = find_dataref("laminar/B747/efis/fpv/fo/selected")
B747DR_efis_meters_capt_selected                = find_dataref("laminar/B747/efis/meters/capt/selected")
B747DR_efis_meters_fo_selected                  = find_dataref("laminar/B747/efis/meters/fo/selected")
simDR_EFIS_wxr_copilot                          = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on_copilot")
simDR_radio_alt_DH_capt             = find_dataref("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot")
simDR_radio_alt_DH_fo               = find_dataref("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_copilot")

simDR_altimeter_baro_inHg           = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
simDR_altimeter_baro_inHg_fo        = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_copilot")

--Marauder28
--Used in ND DISPLAY
simDR_latitude				= find_dataref("sim/flightmodel/position/latitude")
simDR_longitude				= find_dataref("sim/flightmodel/position/longitude")
simDR_navID					= find_dataref("sim/cockpit2/radios/indicators/gps_nav_id")
simDR_range_dial_capt		= find_dataref("laminar/B747/nd/range/capt/sel_dial_pos")
simDR_range_dial_fo			= find_dataref("laminar/B747/nd/range/fo/sel_dial_pos")
simDR_nd_mode_dial_capt		= find_dataref("laminar/B747/nd/mode/capt/sel_dial_pos")
simDR_nd_mode_dial_fo			= find_dataref("laminar/B747/nd/mode/fo/sel_dial_pos")
simDR_nd_center_dial_capt		= find_dataref("laminar/B747/nd/map_center/capt")
simDR_nd_center_dial_fo			= find_dataref("laminar/B747/nd/map_center/fo")
simDR_EFIS_map_mode                 = find_dataref("sim/cockpit2/EFIS/map_mode")

simDR_groundspeed			= find_dataref("sim/flightmodel2/position/groundspeed")
simDR_ias_pilot				= find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
simDR_wind_degrees			= find_dataref("sim/cockpit2/gauges/indicators/wind_heading_deg_mag")
simDR_wind_speed			= find_dataref("sim/cockpit2/gauges/indicators/wind_speed_kts")
simDR_mach_pilot			= find_dataref("sim/cockpit2/gauges/indicators/mach_pilot")
simDR_mach_copilot			= find_dataref("sim/cockpit2/gauges/indicators/mach_copilot")
simDR_total_air_temp		= find_dataref("sim/cockpit2/temperature/outside_air_LE_temp_degc")
simDR_air_temp		= find_dataref("sim/cockpit2/temperature/outside_air_temp_degc")
simDR_aircraft_hdg		 	= find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
-- the heading reference for the ND's wind (5-2 step 5d)
B747DR_fms_hdg_ref_true			= find_dataref("laminar/B747/efis/hdg_ref/true")
simDR_fms_true_psi			= find_dataref("sim/flightmodel/position/psi")
simDR_fms_mag_psi			= find_dataref("sim/flightmodel/position/mag_psi")

--WB CG Info
simDR_cgZ_ref_point			= find_dataref("sim/aircraft/weight/acf_cgZ_original")
simDR_cgz_ref_to_default	= find_dataref("sim/flightmodel/misc/cgz_ref_to_default")
simDR_empty_weight			= find_dataref("sim/aircraft/weight/acf_m_empty")
simDR_fuel_qty				= find_dataref("sim/flightmodel/weight/m_fuel")
simDR_cg_adjust				= find_dataref("sim/flightmodel/misc/cgz_ref_to_default")
simDR_livery_path			= find_dataref("sim/aircraft/view/acf_livery_path")
simDR_onground				= find_dataref("sim/flightmodel/failures/onground_any")
simDR_payload_weight		= find_dataref("sim/flightmodel/weight/m_fixed")
simDR_fuel_totalizer_kg		= find_dataref("sim/cockpit2/fuel/fuel_totalizer_init_kg")
--Marauder28

--*************************************************************************************--
--** 				        CREATE READ-WRITE CUSTOM DATAREFS                        **--
--*************************************************************************************--

-- CRT BRIGHTNESS DIAL ------------------------------------------------------------------
B747DR_fms1_display_brightness      = deferred_dataref("laminar/B747/fms1/display_brightness", "number", B747_fms1_display_brightness_DRhandler)

--Marauder28
-- Holds all SimConfig options
B747DR_simconfig_data					= deferred_dataref("laminar/B747/simconfig", "string")
B747DR_newsimconfig_data				= deferred_dataref("laminar/B747/newsimconfig", "number")
-- Temp location for fuel preselect for displaying in correct units
B747DR_fuel_preselect_temp				= deferred_dataref("laminar/B747/fuel/fuel_preselect_temp", "number")

--pos data
B747DR_waypoint_ata					= deferred_dataref("laminar/B747/nd/waypoint_ata", "string")
B747DR_last_waypoint				= deferred_dataref("laminar/B747/nd/last_waypoint", "string")
B747DR_last_waypoint_fuel=simDR_fueL_tank_weight_total_kg
B747DR_destination					= deferred_dataref("laminar/B747/nd/dest", "string")
B747DR_next_waypoint_eta					= deferred_dataref("laminar/B747/nd/next_waypoint_eta", "string")
B747DR_next_waypoint_dist					= deferred_dataref("laminar/B747/nd/next_waypoint_dist", "number")
B747DR_next_waypoint				= deferred_dataref("laminar/B747/nd/next_waypoint", "string")

--Waypoint info for ND DISPLAY
B747DR_ND_waypoint_eta					= deferred_dataref("laminar/B747/nd/waypoint_eta", "string")
B747DR_ND_current_waypoint				= deferred_dataref("laminar/B747/nd/current_waypoint", "string")
B747DR_ND_waypoint_distance				= deferred_dataref("laminar/B747/nd/waypoint_distance", "string")

--ND Range DISPLAY
B747DR_ND_range_display_capt			= deferred_dataref("laminar/B747/nd/range_display_capt", "number")
B747DR_ND_range_display_fo				= deferred_dataref("laminar/B747/nd/range_display_fo", "number")

--IRS ND DISPLAY
B747DR_ND_GPS_Line						= deferred_dataref("laminar/B747/irs/gps_display_line", "string")
B747DR_ND_IRS_Line						= deferred_dataref("laminar/B747/irs/irs_display_line", "string")

--SPEED ND DISPLAY
B747DR_ND_GS_TAS_Line					= deferred_dataref("laminar/B747/nd/gs_tas_line", "string")
B747DR_ND_GS_TAS_Line_Pilot				= deferred_dataref("laminar/B747/nd/gs_tas_line_pilot", "string")
B747DR_ND_GS_TAS_Line_CoPilot			= deferred_dataref("laminar/B747/nd/gs_tas_line_copilot", "string")
B747DR_ND_Wind_Line						= deferred_dataref("laminar/B747/nd/wind_line", "string")
B747DR_ND_Wind_Bearing					= deferred_dataref("laminar/B747/nd/wind_bearing", "number")

--STAB TRIM setting
B747DR_elevator_trim				    = deferred_dataref("laminar/B747/fmc/elevator_trim", "number")

--Sound Options (crazytimtimtim + Matt726)
B747DR_SNDoptions			        	= deferred_dataref("laminar/B747/fmod/options", "array[7]")
--B747DR_SNDoptions_volume				= deferred_dataref("laminar/B747/fmod/options/volume", "array[8]")
B747DR_SNDoptions_gpws					= deferred_dataref("laminar/B747/fmod/options/gpws", "array[16]")

simDR_stalled_elements= find_dataref("sim/flightmodel2/wing/elements/element_is_stalled")

B747DR_throttle						= deferred_dataref("laminar/B747/engine/throttle", "array[4]")
B747DR_throttle_reversor			= deferred_dataref("laminar/B747/engine/throttle_reversor", "array[4]")
simDR_throttle_ratio_all		= find_dataref("sim/cockpit2/engine/actuators/throttle_ratio_all")
simDR_throttle_ratio		= find_dataref("sim/cockpit2/engine/actuators/throttle_ratio")
--simDR_throttle_ratio	= find_dataref("sim/cockpit2/engine/actuators/hardware_throttle_ratio")
B747DR_throttle_resolver_angle 		= deferred_dataref("laminar/B747/engines/TRA", "array[4]")
simDR_engn_thro				= find_dataref("sim/flightmodel/engine/ENGN_thro")
simDR_engn_thro_use			= find_dataref("sim/flightmodel/engine/ENGN_thro_use")
simDR_throttle_max			= find_dataref("sim/aircraft/engine/acf_throtmax_FWD")

--Simulator Config Options
simConfigData = {}
function doneNewSimConfig()
	B747DR_newsimconfig_data=0
end
function pushSimConfig(values)
	B747DR_simconfig_data=json.encode(values)
	--print("in fms "..B747DR_simconfig_data)
	B747DR_newsimconfig_data=1
	run_after_time(doneNewSimConfig, 1)
end

local setSimConfig=false
function hasSimConfig()
	if B747DR_newsimconfig_data==1 then
		if string.len(B747DR_simconfig_data) > 1 then
			simConfigData["data"] = json.decode(B747DR_simconfig_data)
			setSimConfig=true
		else
			return false
		end
	end
	return setSimConfig
end

--Marauder28

--Marauder28
--Weight & Balance data
wb = {
		--Weights
		OEW_weight				= 0,
		fuel_CTR_0_weight		= 0,
		fuel_L_main1_weight		= 0,
		fuel_L_main2_weight		= 0,
		fuel_R_main3_weight		= 0,
		fuel_R_main4_weight		= 0,
		fuel_L_rsv5_weight		= 0,
		fuel_R_rsv6_weight		= 0,
		fuel_stab7_weight		= 0,

		-- Passenger Zones are defined A - E, A=First, B=Business, C-D-E=Economy split in 3 zones
		passenger_zoneA_weight	= 0,  --defined via FMC passenger loading function
		passenger_zoneB_weight	= 0,  --defined via FMC passenger loading function
		passenger_zoneC_weight	= 0,  --defined via FMC passenger loading function
		passenger_zoneD_weight	= 0,  --defined via FMC passenger loading function
		passenger_zoneE_weight	= 0,  --defined via FMC passenger loading function
		
		--Payload/Cargo Zones
		fwd_lower_cargo_weight	= 0,  --defined via FMC cargo loading function
		aft_lower_cargo_weight	= 0,  --defined via FMC cargo loading function
		bulk_lower_cargo_weight	= 0,  --defined via FMC cargo loading function
		freight_zoneA_weight	= 0,  --defined via FMC cargo loading function
		freight_zoneB_weight	= 0,  --defined via FMC cargo loading function
		freight_zoneC_weight	= 0,  --defined via FMC cargo loading function
		freight_zoneD_weight	= 0,  --defined via FMC cargo loading function
		freight_zoneE_weight	= 0,  --defined via FMC cargo loading function
		
		--Moment Arm Distances (inches from reference point [aircraft nose] stored in feet in aircraft .acf file)
		OEW_distance				= 1243.32, --103.61 feet
		fuel_CTR_0_distance			= 1008.00, --84.00 feet
		fuel_L_main1_distance		= 1383.60, --115.30 feet
		fuel_L_main2_distance		= 1140.00, --95.00 feet
		fuel_R_main3_distance		= 1140.00, --95.00 feet
		fuel_R_main4_distance		= 1383.60, --115.30 feet
		fuel_L_rsv5_distance		= 1596.00, --133.00 feet
		fuel_R_rsv6_distance		= 1596.00, --133.00 feet
		fuel_stab7_distance			= 2412.00, --201.00 feet
		-- Passenger Zone moment arm distances are an approximation using the middle of the Zone as a reference
		passenger_zoneA_distance	= 285.00, --23.75 feet (23 First Class seats in the nose)
		passenger_zoneB_distance	= 735.00, --61.25 feet (80 Business Class seats behind First Class, including the Upper Deck Business Class seats)
		passenger_zoneC_distance	= 1060.00, --88.33 feet (77 Economy Class seats)
		passenger_zoneD_distance	= 1405.00, --117.08 feet (104 Economy Class seats)
		passenger_zoneE_distance	= 1950.00, --162.5 feet (132 Economy Class seats)
		
		--Payload/Cargo Zone moment arm distances are an approximation using the middle of the Zone as a reference
		fwd_lower_cargo_distance	= 650.00,  --54.16 feet (5 pallets [5035 KGS] or 16 LD1/LD3 [1588 KGS] containers or combination totalling 26,490 KGS).
		aft_lower_cargo_distance	= 1675.00,  --139.58 feet (4 pallets or 14 LD1/LD3 containers or combination totalling 22,938 KGS).
		bulk_lower_cargo_distance	= 1935.00,  --161.25 feet (6,749 KGS).  In the tail of the aircraft beneath the rear galley.
		freight_zoneA_distance		= 290.00,  --24.16 feet (3 pallets [3763 KGS] or equivalent totalling 11,289 KGS).
		freight_zoneB_distance		= 690.00,  --57.50 feet (8 pallets [3763 KGS] or equivalent totalling 30,104 KGS).
		freight_zoneC_distance		= 1135.00,  --94.58 feet (6 pallets [3763 KGS] or equivalent totalling 22,578 KGS).
		freight_zoneD_distance		= 1750.00,  --145.83 feet (12 pallets [3763 KGS] or equivalent totalling 45,156 KGS).
		freight_zoneE_distance		= 2220.00,  --185.00 feet (1 pallet [3763 KGS] or equivalent totalling 3763 KGS).

		--Calculated Results
		stab_trim = 0,
		cg_mac = 0,
}

--Calculate CG %MAC & Trim
function calc_stab_trim(GW, CG_MAC)
	local stab_trim = 0
	
	GW = GW * simConfigData["data"].SIM.kgs_to_lbs  --Formula uses LBS to calculate Stab TRIM.  GW passed in should always be in KGS.
	--print("GWin = "..GW.." MACin = "..CG_MAC)

	if GW > 1000 then
		GW = GW / 1000  --GW must be in 1000s of LBS
	end

	stab_trim = (0.000000717 * GW^2 - 0.001217 * GW + 0.24) * CG_MAC + (-0.0000309 * GW^2 + 0.05558 * GW - 12.24)  --GW must be in 1000s of LBS
	
	--Stab Trim can never be less than zero
	if stab_trim < 0 then
		stab_trim = 0
	end
	
	wb.stab_trim	= stab_trim
	fmsModules["data"].stab_trim 	= string.format("%4.1f", wb.stab_trim)
	B747DR_elevator_trim = fmsModules["data"].stab_trim  --Set STAB TRIM for green band calculation
	--print("Setting trim_mid = "..B747DR_elevator_trim)
	--print("Trim = "..fmsModules["data"].stab_trim)
end

function calc_CGMAC()

	local inch_to_meters	= 39.3700787
	
	--Setup initial weights
	wb.OEW_weight				= simDR_empty_weight
	wb.fuel_CTR_0_weight		= simDR_fuel_qty[0]
	wb.fuel_L_main1_weight		= simDR_fuel_qty[1]
	wb.fuel_L_main2_weight		= simDR_fuel_qty[2]
	wb.fuel_R_main3_weight		= simDR_fuel_qty[3]
	wb.fuel_R_main4_weight		= simDR_fuel_qty[4]
	wb.fuel_L_rsv5_weight		= simDR_fuel_qty[5]
	wb.fuel_R_rsv6_weight		= simDR_fuel_qty[6]
	wb.fuel_stab7_weight		= simDR_fuel_qty[7]

	--CG variables (in inches from reference point)
	local GW				= wb.OEW_weight + wb.fuel_CTR_0_weight + wb.fuel_L_main1_weight + wb.fuel_L_main2_weight + wb.fuel_R_main3_weight + wb.fuel_R_main4_weight
								+ wb.fuel_L_rsv5_weight + wb.fuel_R_rsv6_weight + wb.fuel_stab7_weight + wb.passenger_zoneA_weight + wb.passenger_zoneB_weight
								+ wb.passenger_zoneC_weight + wb.passenger_zoneD_weight + wb.passenger_zoneE_weight
								+ wb.fwd_lower_cargo_weight + wb.aft_lower_cargo_weight + wb.bulk_lower_cargo_weight
								+ wb.freight_zoneA_weight + wb.freight_zoneB_weight + wb.freight_zoneC_weight
								+ wb.freight_zoneD_weight + wb.freight_zoneE_weight
	local total_moment		= (wb.OEW_weight * wb.OEW_distance) + (wb.fuel_CTR_0_weight * wb.fuel_CTR_0_distance) + (wb.fuel_L_main1_weight * wb.fuel_L_main1_distance)
								+ (wb.fuel_L_main2_weight * wb.fuel_L_main2_distance) + (wb.fuel_R_main3_weight * wb.fuel_R_main3_distance)
								+ (wb.fuel_R_main4_weight * wb.fuel_R_main4_distance) + (wb.fuel_L_rsv5_weight * wb.fuel_L_rsv5_distance)
								+ (wb.fuel_R_rsv6_weight * wb.fuel_R_rsv6_distance) + (wb.fuel_stab7_weight * wb.fuel_stab7_distance)
								+ (wb.passenger_zoneA_weight * wb.passenger_zoneA_distance) + (wb.passenger_zoneB_weight * wb.passenger_zoneB_distance)
								+ (wb.passenger_zoneC_weight * wb.passenger_zoneC_distance) + (wb.passenger_zoneD_weight * wb.passenger_zoneD_distance)
								+ (wb.passenger_zoneE_weight * wb.passenger_zoneE_distance) + (wb.fwd_lower_cargo_weight * wb.fwd_lower_cargo_distance)
								+ (wb.aft_lower_cargo_weight * wb.aft_lower_cargo_distance) + (wb.bulk_lower_cargo_weight * wb.bulk_lower_cargo_distance)
								+ (wb.freight_zoneA_weight * wb.freight_zoneA_distance) + (wb.freight_zoneB_weight * wb.freight_zoneB_distance)
								+ (wb.freight_zoneC_weight * wb.freight_zoneC_distance) + (wb.freight_zoneD_weight * wb.freight_zoneD_distance)
								+ (wb.freight_zoneE_weight * wb.freight_zoneE_distance)
	local CG				= total_moment / GW
	local wing_root_chord	= 648.99996  --54.10 feet (from the aircraft .acf file)
	local wing_tip_chord	= 159.99996  --13.40 feet (from the aircraft .acf file)
	local wing_taper		= wing_tip_chord / wing_root_chord
	local MAC				= (2/3) * wing_root_chord * ((1 + wing_taper + wing_taper^2) / (1 + wing_taper))
	local LEMAC				= 1129.87932  --Approximately 94.18 feet as measured by where the default XP CG hits the 25% chord line at MAC and subtracting the 25% from the
										  --default CG reference point of 1243.32 inches (103.61 feet)
	local dist_default_CG	= 1243.32  --103.61 feet (from the aircraft .acf file)
	local dist_aft_LEMAC	= CG - LEMAC
	local CG_shift			= (dist_default_CG - CG) / inch_to_meters  --determine how far ahead or behind the OEW CG we are
	local CG_MAC			= (dist_aft_LEMAC / MAC) * 100
		
	wb.cg_mac 				= CG_MAC
	
	fmsModules["data"].cg_mac 		= string.format("%2.0f", wb.cg_mac)
	calc_stab_trim(GW, CG_MAC)

	simDR_cg_adjust = CG_shift * -1  --Value is flipped from what is in the XP slider
	
	--print("Dist = "..dist_default_CG.." - "..CG)
	--print("CG Shift = "..CG_shift)
	--print("OEW weight = "..wb.OEW_weight)
	--print("OEW distance = "..wb.OEW_distance)
	--print("Fuel = "..simDR_fuel_qty[0])
	--print("Fuel = "..wb.fuel_CTR_0_weight)
	--print("CG %MAC = "..wb.cg_mac)
	--print("Stab Trim = "..wb.stab_trim)
	--print("GW = "..GW)
end

function inflight_update_CG()

	local inch_to_meters	= 39.3700787
	
	--Setup initial weights
	wb.OEW_weight				= simDR_empty_weight
	wb.fuel_CTR_0_weight		= simDR_fuel_qty[0]
	wb.fuel_L_main1_weight		= simDR_fuel_qty[1]
	wb.fuel_L_main2_weight		= simDR_fuel_qty[2]
	wb.fuel_R_main3_weight		= simDR_fuel_qty[3]
	wb.fuel_R_main4_weight		= simDR_fuel_qty[4]
	wb.fuel_L_rsv5_weight		= simDR_fuel_qty[5]
	wb.fuel_R_rsv6_weight		= simDR_fuel_qty[6]
	wb.fuel_stab7_weight		= simDR_fuel_qty[7]

	--CG variables (in inches from reference point)
	local GW				= wb.OEW_weight + wb.fuel_CTR_0_weight + wb.fuel_L_main1_weight + wb.fuel_L_main2_weight + wb.fuel_R_main3_weight + wb.fuel_R_main4_weight
								+ wb.fuel_L_rsv5_weight + wb.fuel_R_rsv6_weight + wb.fuel_stab7_weight + wb.passenger_zoneA_weight + wb.passenger_zoneB_weight
								+ wb.passenger_zoneC_weight + wb.passenger_zoneD_weight + wb.passenger_zoneE_weight
								+ wb.fwd_lower_cargo_weight + wb.aft_lower_cargo_weight + wb.bulk_lower_cargo_weight
								+ wb.freight_zoneA_weight + wb.freight_zoneB_weight + wb.freight_zoneC_weight
								+ wb.freight_zoneD_weight + wb.freight_zoneE_weight
	local total_moment		= (wb.OEW_weight * wb.OEW_distance) + (wb.fuel_CTR_0_weight * wb.fuel_CTR_0_distance) + (wb.fuel_L_main1_weight * wb.fuel_L_main1_distance)
								+ (wb.fuel_L_main2_weight * wb.fuel_L_main2_distance) + (wb.fuel_R_main3_weight * wb.fuel_R_main3_distance)
								+ (wb.fuel_R_main4_weight * wb.fuel_R_main4_distance) + (wb.fuel_L_rsv5_weight * wb.fuel_L_rsv5_distance)
								+ (wb.fuel_R_rsv6_weight * wb.fuel_R_rsv6_distance) + (wb.fuel_stab7_weight * wb.fuel_stab7_distance)
								+ (wb.passenger_zoneA_weight * wb.passenger_zoneA_distance) + (wb.passenger_zoneB_weight * wb.passenger_zoneB_distance)
								+ (wb.passenger_zoneC_weight * wb.passenger_zoneC_distance) + (wb.passenger_zoneD_weight * wb.passenger_zoneD_distance)
								+ (wb.passenger_zoneE_weight * wb.passenger_zoneE_distance) + (wb.fwd_lower_cargo_weight * wb.fwd_lower_cargo_distance)
								+ (wb.aft_lower_cargo_weight * wb.aft_lower_cargo_distance) + (wb.bulk_lower_cargo_weight * wb.bulk_lower_cargo_distance)
								+ (wb.freight_zoneA_weight * wb.freight_zoneA_distance) + (wb.freight_zoneB_weight * wb.freight_zoneB_distance)
								+ (wb.freight_zoneC_weight * wb.freight_zoneC_distance) + (wb.freight_zoneD_weight * wb.freight_zoneD_distance)
								+ (wb.freight_zoneE_weight * wb.freight_zoneE_distance)

	local CG				= total_moment / GW
	local dist_default_CG	= 1243.32  --103.61 feet (from the aircraft .acf file)
	local cg_shift			= (dist_default_CG - CG) / inch_to_meters  --determine how far ahead or behind the OEW CG we are

	simDR_cg_adjust = cg_shift * -1  --Value is flipped from what is in the XP slider

	--print("Dist = "..dist_default_CG.." - "..CG)
	--print("CG Shift = "..cg_shift)
end
--Marauder28

fmsPages={}
--fmsPagesmall={}
fmsFunctionsDefs={}
fmsModules={} --set later

function defaultFMSData()
  return {
  acarsInitString="{}",
  acarsEMERMSG="MAYDAY MAYDAY MAYDAY",
  acarsEMERSOB=string.rep("-", 3),
  acarsEMEROFFSET=string.rep("-", 3),
  acarsEMERDESC="-----",
  acarsEMERDIVERT="               ",
  acarsWCWCRZCLB=string.rep("-", 5),
  acarsWCWCLB=string.rep("-", 5),
  acarsWCWDES=string.rep("-", 5),
  acarsWCWSPEED=string.rep("-", 2),
  acarsREQALT=string.rep("-", 5),
  acarsREQSPEED=string.rep("-", 2),
  acarsREQOFFSET=string.rep("-", 3),
  acarsREQHDG=string.rep("-", 3),
  acarsREQTRK=string.rep("-", 3),
  acarsREQAT=string.rep("-", 5),
  acarsREQTO=string.rep("-", 5),
  acarsREQDUE=string.rep("-", 16),
  fltno=string.rep("-", 8),
  curCTR=string.rep("*", 4),
  nextCTR=string.rep("*", 4),
  fltdate="********",
  fltdep="****",
  fltdst="****",
  flttimehh="**",
  flttimemm="**",
  rpttimehh="**",
  rpttimemm="**",
  acarsAddress="*******",
  atc="****",
  grwt="***.*   ",
  crzalt=string.rep("*", 5),
  acarsMessage="",
  clbspd="340",
  transpd="250",
  spdtransalt="10000",
  transalt="18000",
  clbrestspd="---",
  maxkts="420",
  clbrestalt="-----",
  stepalt="     ",
  crzspd="810",
  desspdmach="805",
  desspd="270",
  destranspd="240",
  desspdtransalt="10000",
  -- the speeds' modes (6-1/6-2 step 8b): E ECON from the cost index, S a
  -- crew's (SEL SPD), L the cruise's LRC; the climb's Mach (blank: the
  -- cruise's) and a cruise CAS (blank: crzspd's Mach)
  clbspdmode="E",
  crzspdmode="E",
  desspdmode="E",
  clbspdmach="   ",
  crzcas="   ",
  desrestspd="---",
  desrestalt="-----",
  fpa="*.*",
  vb="*.*",
  vs="****",
  fuel="***.*",
  zfw="***.*   ",
  accelht="1000",
  accelset=" ",
  eoaccelht="1000",
  eoaccelset=" ",
  thrred="5   ",
  thrredset=" ",
  towind="---",
  toslope="----",
  posshift="---",
  selunit=" ",
  thrustself="   ",
  v1sel="   ",
  vrsel="   ",
  v2sel="   ",
  fuelman="     ",
  gwsrc="   ",
  reserves="***.*",
  costindex="****",
  crzcg="20.0",
  thrustsel=string.rep(" ", 2), --"26",  --Initally "blank" per FCOM FMC Preflight 2B - Thrust Limit Page
  thrustn1="**.*",
  toflap="**",
  v1="***",
  vr="***",
  v2="***",
  runway=string.rep("-", 5),
  coroute=string.rep("-", 10),
  grosswt="***.*",
  vref1="***",
  vref2="***",
  irsLat=string.rep(" ", 9),
  irsLon=string.rep(" ", 9),
  initIRSLat="****`**.*",
  initIRSLon="****`**.*",
  flapspeed="--/---",
  airportpos=string.rep("-", 4),
  airportgate=string.rep(" ", 5),
  preselectLeft=string.rep("-", 6),
  preselectRight=string.rep("-", 6),
  codata = string.rep("-", 6),
  lastpos = string.rep(" ", 18),
  sethdg = string.rep(" ", 4),
  stepsize = "ICAO",
  cg_mac = string.rep("-", 2),
  stab_trim = string.rep(" ", 4),
  paxFirstClassA = string.rep("0", 2),
  paxBusClassB = string.rep("0", 2),
  paxEconClassC = string.rep("0", 2),
  paxEconClassD = string.rep("0", 3),
  paxEconClassE = string.rep("0", 3),
  paxTotal = string.rep("0", 3),
  paxWeightA = string.rep("0", 4),
  paxWeightB = string.rep("0", 5),
  paxWeightC = string.rep("0", 5),
  paxWeightD = string.rep("0", 5),
  paxWeightE = string.rep("0", 5),
  paxWeightTotal = string.rep("0", 6),
  cargoFwd = string.rep("0", 6),
  cargoAft = string.rep("0", 6),
  cargoBulk = string.rep("0", 5),
  cargoTotal = string.rep("0", 6),
  freightZoneA = string.rep("0", 6),
  freightZoneB = string.rep("0", 6),
  freightZoneC = string.rep("0", 6),
  freightZoneD = string.rep("0", 6),
  freightZoneE = string.rep("0", 6),
  freightTotal = string.rep("0", 7),
  --irsAlignTime = string.rep("0", 3),
}
end


fmsModules["data"]=defaultFMSData()

B747DR_FMSdata=json.encode(fmsModules["data"]["values"])--make the fms data available to other modules

fmsModules["setData"]=function(self,id,value)
    --always retain the same length
    if value=="" and id~="acarsMessage" then 
      local initData=defaultFMSData()
      if initData[id]~=nil then
		print("default for " .. id .. " is " .. initData[id])
		value=initData[id]
      else
		print("default for " .. id .. " is nil")
		self["data"][id]=nil
		return
      end
    end
    len=string.len(self["data"][id])
    if len < string.len(value) and id~="acarsMessage" then 
      value=string.sub(value,1,3)
    end
    --newVal=string.sub(value,1,len)
	if id~="acarsMessage" then
    	self["data"][id]=string.format("%s%"..(len-string.len(value)).."s",value,"")
	else
		self["data"][id]=value
	end
	B747DR_FMSdata=json.encode(fmsModules["data"]["values"])--make the fms data available to other modules
end
function setFMSData(id,value)
	if not string.starts(id,"acars") then 
		print("setting " .. id )
		print(" to "..value)
		print(" curently "..fmsModules["data"][id])
	end
   fmsModules:setData(id,value)
end  
-- the climb's SPD TRANS speed: the greater of the transition speed (250 kt;
-- the origin's from the nav DB comes in step 4) and VREF 30 + 100 kt (FCOM
-- p.1328: "272/10000"; VREF 30: estimate); dashes once deleted (FMC-09,
-- 6-1 step 1)
B747DR_airspeed_Vf30 = find_dataref("laminar/B747/airspeed/Vf30")
function update_spd_trans()
	local cur = fmsModules["data"]["transpd"]
	if cur == nil or cur == "---" then return end
	local vref = tonumber(B747DR_airspeed_Vf30) or 0
	local spd = string.format("%3d", math.max(250, math.floor(vref + 100 + 0.5)))
	if vref > 80 and spd ~= cur then fmsModules:setData("transpd", spd) end
end
function getFMSData(id)
  if hasChild(fmsModules["data"],id) then
    return fmsModules["data"][id]
  end
  if not string.starts(id,"acars") then 
	print("getting getFMSData" )
	print("getting " .. id )
	print(" curently "..fmsModules["data"][id])
  end
  return fmsModules["data"][id]
end 
fmsModules["lastcmd"]=" "
fmsModules["cmds"]={}
fmsModules["cmdstrings"]={}
function registerFMCCommand(commandID,dataString)
  fmsModules["cmds"][commandID]=find_command(commandID)
  fmsModules["cmdstrings"][commandID]=dataString
end

function switchCustomMode()
  fmsModules["fmsL"]["inCustomFMC"]=fmsModules["fmsL"]["targetCustomFMC"]
  fmsModules["fmsC"]["inCustomFMC"]=fmsModules["fmsC"]["targetCustomFMC"]
  fmsModules["fmsR"]["inCustomFMC"]=fmsModules["fmsR"]["targetCustomFMC"]
  fmsModules["fmsL"]["currentPage"]=fmsModules["fmsL"]["targetPage"]
  fmsModules["fmsC"]["currentPage"]=fmsModules["fmsC"]["targetPage"]
  fmsModules["fmsR"]["currentPage"]=fmsModules["fmsR"]["targetPage"]
  fmsModules["fmsL"]["pgNo"]=fmsModules["fmsL"]["targetpgNo"]
  fmsModules["fmsC"]["pgNo"]=fmsModules["fmsC"]["targetpgNo"]
  fmsModules["fmsR"]["pgNo"]=fmsModules["fmsR"]["targetpgNo"]
  print("targetCustomFMC"..tostring(fmsModules["fmsL"]["targetCustomFMC"]))
  print("targetPage"..tostring(fmsModules["fmsL"]["targetPage"]))
  print("targetpgNo"..tostring(fmsModules["fmsL"]["targetpgNo"]))
  print("left cdu switchCustomMode")
end
function createPage(page)
  retVal={}
  retVal.name=page
  retVal.template={
  "    " .. page,
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        "
  }  
  retVal.templateSmall={
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        ",
  "                        "
  }
  retVal.getPage=function(self,pgNo) return self.template end
  retVal.getSmallPage=function(self,pgNo) return self.templateSmall end
  retVal.getNumPages=function(self) return 1 end
  fmsFunctionsDefs[page]={}
  return retVal
end
dofile("B747.68.cdu_model.lua")
dofile("B747.68.navdb.lua")
-- the FMC's navigation database (6-1/6-2 step 4; notes/ATA-34-61-FMC.md
-- §17): X-Plane's navigation data, Custom Data's when it has them (a
-- Navigraph cycle) else the default, read a block a frame
local function navdb_folder()
  if B747_NAVDB_FOLDER then return B747_NAVDB_FOLDER end
  local f=io.open("Custom Data/earth_nav.dat","rb")
  if f then f:close() return "Custom Data/" end
  return "Resources/default data/"
end
local NAVDB_FOLDER=navdb_folder()
B747_fmc_navdb=B747_navdb.new(function(name) return io.open(NAVDB_FOLDER..name,"rb") end)
dofile("B747.68.route_model.lua")
-- the routes' waypoint winds and temperatures (6-1/6-2 step 8e1; notes/
-- ATA-34-61-FMC.md §51: the WIND pages)
dofile("B747.68.wind_model.lua")
-- the FMC's route (6-1/6-2 step 5b; notes/ATA-34-61-FMC.md §18): RTE 1 on
-- the RTE pages. When RTE 1 changes, the FMC's data the other modules
-- read (fltdep, fltdst, runway; TRANS ALT from a new origin: FCOM p.1329)
-- and X-Plane's FMS (its ND line; the AFDS's LNAV and VNAV until they are
-- rebuilt: xtlua/loadtoFMS) follow
dofile("B747.68.proc_model.lua")
B747_fmc_route=B747_route_model.new(B747_navdb,B747_fmc_navdb)
-- the terminal procedures (6-1/6-2 step 5d)
B747_fmc_route.P=B747_proc_model
-- RTE 2 (6-1/6-2 step 7e4; FCOM p.1287-1294): the other route's state.
-- The two exchange their contents when the other is activated, so that
-- B747_fmc_route is always the active one (or RTE 1 with none); `num`
-- tells which route a state holds
B747_fmc_route.num=1
B747_fmc_route2=B747_route_model.new(B747_navdb,B747_fmc_navdb)
B747_fmc_route2.P=B747_proc_model
B747_fmc_route2.num=2
function B747_fmc_route_num(n)
  if B747_fmc_route.num==n then return B747_fmc_route end
  return B747_fmc_route2
end
local routeLoaded=nil
-- the loaded flight plan's rows and the route's legs, and the row X-Plane's
-- current waypoint goes to once X-Plane has the plan (6-1/6-2 step 5e)
local routeMap=nil
local routeSync=nil
local routeSyncT=0
local routeSyncWrites=0
-- the last load: when, and xtlua/fms before it
local routeLoadT=-10
local routeLoadOld=nil
local routeWasActive=false
-- XTLua's xtlua/loadtoFMS and xtlua/currentFMSID call X-Plane's FMS from
-- XTLua's own thread, with no lock against X-Plane's (XTLua's
-- xpmtdatarefs.cpp; X-Plane crashed three times, 2026-10-26): the FMS
-- bridge plugin (plugins/b747_fms_bridge) takes the plan and the current
-- waypoint on X-Plane's thread; without it, a new plan goes to X-Plane once
-- the route has stayed the same a second, X-Plane's current waypoint is
-- written twice at most a plan
local routePending=nil
local routePendingMap=nil
local routePendingT=0
B747DR_fmscurrentIndex=find_dataref("laminar/B747/autopilot/ap_monitor/fmscurrentIndex")
-- (B747DR_fms_setCurrent is xtlua/currentFMS, by name: a global XTLua has
-- bound to a dataref keeps it)
B747DR_fms_currentID=find_dataref("xtlua/currentFMSID")
B747DR_xp_bridge=find_dataref("laminar/B747/fms/xp/bridge")
B747DR_xp_plan=find_dataref("laminar/B747/fms/xp/plan")
B747DR_xp_current=find_dataref("laminar/B747/fms/xp/current")
B747DR_xp_displayed=find_dataref("laminar/B747/fms/xp/displayed")
B747DR_fms_exec_light_pilot=find_dataref("laminar/B747/fms/exec_light_pilot")
B747DR_fms_exec_light_copilot=find_dataref("laminar/B747/fms/exec_light_copilot")
simDR_fms_exec_light=find_dataref("sim/cockpit2/radios/indicators/fms_exec_light_pilot")
-- LNAV (6-1/6-2 step 6c; notes/ATA-34-61-FMC.md §29): the active route's
-- path (B747.68.path_model.lua) built anew when the route changes or
-- sequences; LNAV (B747.68.lnav_model.lua) each frame, its steering to
-- the AFDS
dofile("B747.68.path_model.lua")
dofile("B747.68.lnav_model.lua")
-- the FMC's performance database (6-1/6-2 step 8a; notes/ATA-34-61-FMC.md
-- §44): the FCOM PI tables for the engine type, and the outside air's ISA
-- deviation (degrees C) at the pressure altitude for the maximum altitude
dofile("B747.68.perf_db.lua")
B747DR_fms_engine_type = find_dataref("laminar/B747/engines/type")
function B747_fms_perf()
  return B747_perf_db.tables(B747DR_fms_engine_type)
end
function B747_fms_isa_dev()
  local h = math.min(simDR_pressureAlt1, 36089)
  return simDR_air_temp - (15 - 1.98 * h / 1000)
end
-- the FMC's gross weight (kg): PERF INIT's (ZFW + fuel), else X-Plane's
function B747_fms_gw_kg()
  local gw = perf_gw_t()
  if gw then return gw * 1000 end
  return simDR_GRWT
end
-- the measured wind's direction (true; X-Plane's indicated one magnetic)
function B747_fms_wind_true()
  return (simDR_wind_degrees - ((simDR_fms_mag_psi - simDR_fms_true_psi + 180) % 360 - 180)) % 360
end
-- the headwind (kt) of the cruise for ECON (step 8e3): the predictions'
-- winds (the last ones') at CRZ ALT here, the measured wind mixed with the
-- forecasts; before any, the present wind's within 2,000 ft of CRZ ALT
local predField = nil
function B747_fms_crz_headwind()
  local crz = B747BR_cruiseAlt
  if crz == nil or crz <= 0 then return 0 end
  if predField then return predField.wind(0, crz, "crz") end
  if simDR_onGround == 1 or math.abs(simDR_pressureAlt1 - crz) >= 2000 then return 0 end
  return simDR_wind_speed * math.cos(math.rad(simDR_wind_degrees - simDR_fms_mag_psi))
end
-- the step climb (6-1/6-2 step 8b2; notes/ATA-34-61-FMC.md §46): ICAO's
-- STEP TO goes by the direction of the cruise altitude entered before
-- takeoff (FCOM p.1349), kept while on the ground; CRZ ALT's without it
-- (an air start)
dofile("B747.68.crz_model.lua")
local crzAltTakeoff = nil
function B747_fms_step_east()
  return B747_crz_model.east(crzAltTakeoff or B747BR_cruiseAlt)
end
-- the economy speeds (6-1/6-2 step 8b; notes/ATA-34-61-FMC.md §45): every
-- 5 s by the performance database's cruise model (an estimate) from the
-- cost index, the gross weight, the cruise altitude, the wind there (the
-- present one while near it; forecasts are step 8e) and the ISA deviation,
-- into the climb's, cruise's and descent's speeds while they are ECON (a
-- crew's entry makes one SEL SPD); LRC the table's long range cruise. After
-- the first value since an entry, a change under 2 kt or .002 is left (the
-- A/P takes each change as a new target).
local econNext = 0
local econPut = {}
function B747_fms_econ_now() econNext = 0 econPut = {} end
local function econ_put(id, v, mach)
  local old = tonumber(fmsModules["data"][id])
  local s = mach and string.format("%03d", math.floor(v * 1000 + 0.5)) or string.format("%3d", math.floor(v + 0.5))
  if econPut[id] and old and math.abs(old - tonumber(s)) < 2 then return end
  econPut[id] = true
  if fmsModules["data"][id] ~= s then fmsModules:setData(id, s) end
end
function update_econ()
  if simDR_onGround == 1 and B747BR_cruiseAlt > 0 then crzAltTakeoff = B747BR_cruiseAlt end
  if simDRTime < econNext then return end
  econNext = simDRTime + 5
  local crz = B747BR_cruiseAlt
  if crz == nil or crz <= 0 then return end
  local d = fmsModules["data"]
  local P, t, kg, isa = B747_perf_db, B747_fms_perf(), B747_fms_gw_kg(), B747_fms_isa_dev()
  if d.crzspdmode == "L" then econ_put("crzspd", (P.lrc(t, kg, crz)), true) end
  local ci = tonumber(d.costindex)
  if ci == nil then return end
  if d.crzspdmode == "E" then econ_put("crzspd", (P.econ_cruise(t, kg, crz, ci, B747_fms_crz_headwind(), isa)), true) end
  if d.clbspdmode == "E" then
    local cas, m = P.econ_climb(t, kg, crz, ci, isa)
    econ_put("clbspd", cas)
    econ_put("clbspdmach", m, true)
  end
  if d.desspdmode == "E" then
    local m, cas = P.econ_descent(t, kg, crz, ci, isa)
    econ_put("desspdmach", m, true)
    econ_put("desspd", cas)
  end
end

-- (step 9h4a) the engine-out mode (B747.68.eo_model.lua; notes/
-- ATA-34-61-FMC.md §81; FCOM p.1266, p.1341-1342, p.1350-1353; FMSPG
-- p.3.3-4, p.3.3-6, p.3.4-5): ENG OUT> and ALL ENG> on the VNAV CLB and CRZ
-- pages as modifications for EXEC; the data for the engines sensed
-- inoperative (one if none); executed, CRZ ALT lowered to the engine-out
-- maximum, the reference thrust limit CON, the engine-out speeds VNAV's
dofile("B747.68.eo_model.lua")
local eoState = B747_eo_model.new()
B747DR_fms_eo_nai = find_dataref("laminar/B747/antiice/nacelle/valve_pos")
B747DR_fms_eo_wai = find_dataref("laminar/B747/antiice/wing/valve_pos")
function B747_fms_eo() return eoState end
-- the anti-ice for the engine-out maximum altitude: 0 off, 1 engine, 2
-- engine and wing (PI.13.3, PI.23.4)
local function eo_ai()
  local nai = false
  for i = 0, 3 do
    if B747DR_fms_eo_nai[i] > 0.5 then nai = true end
  end
  if not nai then return 0 end
  if B747DR_fms_eo_wai[0] > 0.5 or B747DR_fms_eo_wai[1] > 0.5 then return 2 end
  return 1
end
-- the engine-out maximum altitude (ft) at the FMC's weight: at E/O LRC
-- ("LRC"), at the minimum drag speed ("EO"), or the lower ("CLB": FCOM
-- p.1342); the optimum at E/O LRC (estimate: perf_db's)
function B747_fms_eo_max(kind)
  local lrc, dd = B747_perf_db.eo_max_alt(B747_fms_perf(), B747_eo_model.engines(eoState), B747_fms_gw_kg(),
    B747_fms_isa_dev(), eo_ai())
  if kind == "EO" then return dd end
  if kind == "LRC" then return lrc end
  return math.min(lrc, dd)
end
function B747_fms_eo_crz_max() return B747_fms_eo_max(eoState.crz == "EO" and "EO" or "LRC") end
function B747_fms_eo_opt()
  return B747_perf_db.eo_opt_alt(B747_fms_perf(), B747_eo_model.engines(eoState), B747_fms_gw_kg(), B747_fms_isa_dev(), eo_ai())
end
-- the E/O climb speed and <E/O SPD's (kt): the minimum drag speed
-- (estimate: FCOM p.1342's engine out climb speed as the best gradient's)
function B747_fms_eo_min_drag()
  return B747_perf_db.eo_min_drag(B747_fms_perf(), B747_eo_model.engines(eoState), B747_fms_gw_kg())
end
-- E/O LRC at an altitude (ft): Mach and KIAS
function B747_fms_eo_lrc(ft)
  local m, k = B747_perf_db.eo_lrc(B747_fms_perf(), B747_eo_model.engines(eoState), B747_fms_gw_kg(), ft)
  return m, k
end
-- the thrust setting (EPR or N1) for engine-out level flight
function B747_fms_eo_setting(ft, mach)
  return B747_perf_db.eo_level_setting(B747_fms_perf(), B747_eo_model.engines(eoState), B747_fms_gw_kg(), ft, mach,
    B747_fms_isa_dev())
end
-- the pages' ENG OUT> and ALL ENG>
function B747_fms_eo_eng_out()
  if B747_eo_model.eng_out(eoState, B747_fms_eng_out()) then B747_fms_preds_now() end
end
function B747_fms_eo_all_eng()
  if B747_eo_model.all_eng(eoState) then B747_fms_preds_now() end
end
-- EXEC: ENG OUT's CRZ ALT at most the engine-out maximum (the CLB page's
-- lower one, else E/O LRC's: FMSPG p.3.3-4, p.3.4-5), CON (FCOM p.1266,
-- p.1350); ALL ENG's the all-engine data back. True when there was one
function B747_fms_eo_exec()
  local kind = eoState.mod
  local maxFt = (kind == "ENG OUT") and B747_fms_eo_max(B747_fms_vnav_page() == 1 and "CLB" or "LRC") or nil
  if not B747_eo_model.exec(eoState) then return false end
  -- (step 9h5a) RTA not with ENG OUT (FCOM p.1269): an active one ended
  if kind == "ENG OUT" then B747_rta_model.terminate(B747_fms_rta()) end
  if maxFt then
    local crz = B747BR_cruiseAlt
    if crz and crz > maxFt then
      B747BR_cruiseAlt = math.floor(maxFt / 100) * 100
      monitorCRZALT()
      setFMSData("stepalt", "")
    end
    B747_fms_thrlim_sel("CON")
  end
  B747_fms_econ_now()
  B747_fms_preds_now()
  return true
end
function B747_fms_eo_erase() return B747_eo_model.erase(eoState) end

-- (step 9h5a) the required time of arrival (B747.68.rta_model.lua; notes/
-- ATA-34-61-FMC.md §84; FCOM p.1269, p.1383-1385): the RTA PROGRESS page's
-- modification for EXEC and ERASE beside the route's and the engine-out
-- one; the 109's and 405's only (none on the 570: laminar/B747/engines/type
-- 1), not with ENG OUT active (FCOM p.1269: its execution ends one)
dofile("B747.68.rta_model.lua")
local rtaState = B747_rta_model.new()
function B747_fms_rta() return rtaState end
function B747_fms_rta_avail() return B747DR_fms_engine_type ~= 1 and not eoState.active end
-- the FIX in the route the pages show (the modification's, else the
-- active one's) ahead
function B747_fms_rta_in_route(fix)
  for _, l in ipairs(B747_route_model.shown(B747_fmc_route).legs) do
    if l.fix and l.fix.ident == fix then return true end
  end
  return false
end
-- the FIX's leg in the active route ahead (the predictions' index), or nil
function B747_fms_rta_leg(fix)
  for i, l in ipairs(B747_fmc_route.rte.legs) do
    if l.fix and l.fix.ident == fix then return i end
  end
  return nil
end
function B747_fms_rta_exec()
  if not B747_rta_model.exec(rtaState) then return false end
  B747_fms_preds_now()
  return true
end
function B747_fms_rta_erase() return B747_rta_model.erase(rtaState) end
-- the time now (minutes of the day, UTC)
function B747_fms_utc_min() return hh * 60 + mm + ss / 60 end

-- the trajectory predictions (6-1/6-2 step 8c; notes/ATA-34-61-FMC.md
-- §47): every 10 s (at once after an entry) along the active route's legs
-- ahead, with their great circle distances and altitude constraints, by
-- B747.68.pred_model.lua with the FMC's speeds (ECON or SEL, LRC), weight
-- and fuel, the step climbs (STEP SIZE, STEP TO) and the cruise's wind.
-- The E/D: the approach's runway, 50 ft above it (FCOM p.1258; the missed
-- approach after it not the descent's), else the last constrained leg
-- after the climb's (the SID's); none, no descent (ATA34_2 p.611)
dofile("B747.68.pred_model.lua")
local predNext, predResult = 0, nil
function B747_fms_preds() return predResult end
function B747_fms_preds_now() predNext = 0 end
local function pred_num(id) return tonumber(fmsModules["data"][id]) end
-- the FMC's climb, descent and cruise speeds as the predictions and VNAV
-- fly them (the CLB, CRZ and DES pages')
function B747_fms_schedules(perf)
  local clb = {cas = pred_num("clbspd") or 340, mach = (pred_num("clbspdmach") or pred_num("crzspd") or 810) / 1000,
    trans_cas = pred_num("transpd"), trans_alt = pred_num("spdtransalt"),
    restr_cas = pred_num("clbrestspd"), restr_alt = pred_num("clbrestalt")}
  local des = {cas = pred_num("desspd") or 270, mach = (pred_num("desspdmach") or 805) / 1000,
    trans_cas = pred_num("destranspd"), trans_alt = pred_num("desspdtransalt"),
    restr_cas = pred_num("desrestspd"), restr_alt = pred_num("desrestalt")}
  local crzspd
  -- (step 9h4b) LRC's weight without one given (VNAV's without the FMC's
  -- gross weight): the FMC's or X-Plane's (before, an error)
  local gw = B747_fms_gw_kg()
  if pred_num("crzcas") then
    crzspd = {cas = pred_num("crzcas")}
  elseif fmsModules["data"]["crzspdmode"] == "L" then
    crzspd = {fn = function(h, kg) return (B747_perf_db.lrc(perf, kg or gw, h)) end}
  else
    crzspd = {mach = (pred_num("crzspd") or 810) / 1000}
  end
  -- (step 9h4a) engine out: the E/O climb speed or the crew's, no SPD
  -- TRANS nor SPD REST (the E/O CLB page has none: estimate); E/O LRC, the
  -- minimum drag speed or the crew's (FCOM p.1342, p.1350-1353)
  if eoState.active then
    local n = eoState.n
    local sel = eoState.clb
    if sel then
      clb = {cas = sel.cas or 400, mach = sel.mach}
    else
      clb = {cas = B747_perf_db.eo_min_drag(perf, n, gw)}
    end
    local c = eoState.crz
    if c == "LRC" then
      crzspd = {fn = function(h, kg) return (B747_perf_db.eo_lrc(perf, n, kg or gw, h)) end}
    elseif c == "EO" then
      crzspd = {cas = B747_perf_db.eo_min_drag(perf, n, gw)}
    else
      crzspd = c.mach and {mach = c.mach} or {cas = c.cas}
    end
  end
  return clb, des, crzspd
end
-- (step 9e3) after a missed approach (B747_fms_missed_approach): the
-- approach's legs then (by the leg each copies: the route's modifications
-- copy them), no longer on approach, END OF DES's nor an E/D (a new
-- approach's legs are), and CRZ ALT then; nil before one and on the ground
local vnavMissed, vnavMissedCrz = nil, nil
local function missed_leg(l) return vnavMissed ~= nil and vnavMissed[l.orig or l] == true end
-- the prediction's input for a cruise altitude, nil without an active route
function B747_fms_pred_input(crz)
  local st = B747_fmc_route
  if not st.active or crz == nil or crz <= 0 then return nil end
  local R, r = B747_route_model, st.rte
  local legs, clbLast, lastCon, rwy = {}, nil, nil, nil
  -- (step 9e2) the approach's runway passed: its legs left are the missed
  -- approach's, no E/D (FCOM p.1258: the E/D 50 ft above the threshold;
  -- before, its constraint made a new one and ended END OF DES); (step 9e3)
  -- after a missed approach the same, its runway ahead no E/D either
  local missed = vnavMissed ~= nil
  for _, l in ipairs(r.passed) do
    if l.proc == "APPR" and l.fix and l.fix.kind == "RWY" then missed = true end
  end
  -- the distances: great circles from the point before (the airplane's
  -- for the first), across a conditional leg or a discontinuity too (an
  -- estimate; a conditional leg itself none)
  local from = {lat = simDR_latitude, lon = simDR_longitude}
  for i, l in ipairs(r.legs) do
    local d, p0 = 0, from
    if l.fix then
      local _, dd = R.course(from.lat, from.lon, l.fix.lat, l.fix.lon)
      d = dd
      from = l.fix
    end
    local con = nil
    if l.alt then
      if l.akind == "A" then con = {kind = "A", a = l.alt}
      elseif l.akind == "B" then con = {kind = "B", a = l.alt}
      elseif l.akind == "AB" then con = {kind = "W", a = math.max(l.alt, l.alt2 or l.alt), b = math.min(l.alt, l.alt2 or l.alt)}
      else con = {kind = "AT", a = l.alt} end
    end
    if l.fix and l.fix.kind == "RWY" and l.proc ~= "SID" and not missed_leg(l) then
      con = {kind = "AT", a = (l.fix.elev or 0) + 50}
      rwy = rwy or i
    end
    -- (p0, p1: the great circle's ends, for the ND's profile points; step
    -- 9e4: the leg's glide path angle down, the CIFP's: FCOM p.1262)
    legs[i] = {name = l.fix and l.fix.ident or "", dist = d, con = con, p0 = p0, p1 = l.fix,
      gp = (l.vangle and l.vangle < 0) and -l.vangle or nil}
    if l.proc == "SID" then clbLast = i end
    if con and not rwy and not (missed and l.proc == "APPR") then lastCon = i end
  end
  local ed = rwy
  if not ed and lastCon and lastCon > (clbLast or 0) then ed = lastCon end
  local perf, isa = B747_fms_perf(), B747_fms_isa_dev()
  local clb, des, crzspd = B747_fms_schedules(perf)
  -- (step 9h4b) ENG OUT active: the engine-out data (no step climbs:
  -- estimate)
  local eo = eoState.active and eoState.n or nil
  -- the step climbs: STEP SIZE's (none with 0), the crew's STEP TO first
  local steps = nil
  local size = (string.gsub(fmsModules["data"]["stepsize"], "%s+$", ""))
  if tonumber(size) ~= 0 and not eo then
    local east = B747_fms_step_east()
    local crewTo = B747_cdu_model.parse_alt((string.gsub(fmsModules["data"]["stepalt"], "%s+$", "")))
    local light = perf.MAX_ALT_W[#perf.MAX_ALT_W] * 1000 * perf.wf
    local heavy = perf.MAX_ALT_W[1] * 1000 * perf.wf
    local function opt(kg) return B747_perf_db.opt_alt(perf, kg) end
    steps = function(h, kg)
      local to = (crewTo and crewTo > h + 1) and crewTo or B747_crz_model.step_to(h, opt(kg), size, east)
      if not to then return nil end
      local w = B747_crz_model.step_weight(h, to, opt, light, heavy)
      if B747_perf_db.max_alt(perf, w, isa) < to then w = math.min(w, B747_perf_db.max_alt_weight(perf, to, isa)) end
      return to, w
    end
  end
  -- the phase: the FMC's VNAV's (step 9b; before, the old AP's flightPhase)
  local phase = "clb"
  local vph = B747_fms_vnav_phase and B747_fms_vnav_phase()
  if simDR_onGround ~= 1 and vph then phase = string.lower(vph) end
  -- (step 9h4b) VNAV's cruise descent under way, its driftdown
  local crzDes = nil
  if B747_fms_vnav_page then
    local _, chg = B747_fms_vnav_page()
    if chg == "DES" then crzDes = B747_fms_vnav_dd() and "dd" or "des" end
  end
  -- the winds and temperatures along the route (step 8e3; notes/
  -- ATA-34-61-FMC.md §53): the WIND pages' and DESCENT FORECAST's mixed
  -- with the measured wind (true) and temperature
  local fc = B747_fms_des_forecast and B747_fms_des_forecast()
  local field = B747_wind_model.field{legs = legs, route = r, course = R.course,
    measured = {dir = B747_fms_wind_true(), kt = simDR_wind_speed, isa = isa, h = simDR_pressureAlt1, phase = phase},
    orig_elev = r.origin and r.origin.elev or 0, dest_elev = r.dest and r.dest.elev or 0, crz = crz,
    des = fc and fc.slots or nil}
  return {P = B747_perf_db, t = perf, isa = isa, gw = B747_fms_gw_kg(), fuel = perf_fuel_t() * 1000,
    alt = math.max(0, simDR_pressureAlt1), cas = (simDR_onGround ~= 1 and simDR_ias_pilot > 100) and simDR_ias_pilot or nil,
    phase = phase, crz = crz, clb = clb, des = des, crzspd = crzspd, legs = legs, ed = ed, clb_last = clbLast,
    steps = steps, wind = {clb = 0, crz = 0, des = 0}, field = field, eo = eo, crz_des = crzDes}
end
-- the ND's altitude profile points (6-1/6-2 step 8d3; notes/
-- ATA-34-61-FMC.md §50; FCOM p.1149): the predictions' T/C, the next S/C
-- (FMSPG p.153: the step point; estimate: the next one only), T/D, E/D and
-- the descent's deceleration points ahead, where they are on the legs'
-- great circles, for the ND module
B747DR_fms_profile_kind = find_dataref("laminar/B747/fms/profile/kind")
B747DR_fms_profile_lat = find_dataref("laminar/B747/fms/profile/lat")
B747DR_fms_profile_lon = find_dataref("laminar/B747/fms/profile/lon")
local PROFILE_N = 8
-- the point x NM along the prediction's legs, nil beyond them
local function pred_point(legs, x)
  local acc = 0
  for _, l in ipairs(legs) do
    if l.dist > 0 and x <= acc + l.dist then
      local crs = B747_route_model.course(l.p0.lat, l.p0.lon, l.p1.lat, l.p1.lon)
      return B747_route_model.course_point(l.p0, crs, x - acc)
    end
    acc = acc + l.dist
  end
  return nil
end
local function put_profile(s, r)
  local pts = {}
  if r then
    local function add(kind, x) if x and x > 0 then pts[#pts + 1] = {kind = kind, x = x} end end
    add(1, r.tc)
    add(2, r.sc[1])
    add(3, r.td)
    add(4, r.ed)
    for _, x in ipairs(r.decel) do add(5, x) end
  end
  for k = 0, PROFILE_N - 1 do
    local p = pts[k + 1]
    local q = p and pred_point(s.legs, p.x)
    if q then
      B747DR_fms_profile_lat[k] = q.lat
      B747DR_fms_profile_lon[k] = q.lon
      B747DR_fms_profile_kind[k] = p.kind
    elseif B747DR_fms_profile_kind[k] ~= 0 then
      B747DR_fms_profile_kind[k] = 0
    end
  end
end
function update_preds()
  if simDRTime < predNext then return end
  predNext = simDRTime + 10
  local s = B747_fms_pred_input(B747BR_cruiseAlt)
  predField = s and s.field or nil
  -- none with CRZ ALT at or above MAX (ATA34_2 p.611); (step 9h4b) with
  -- ENG OUT active above the engine-out MAX (CRZ ALT set to it: on)
  if s and s.crz >= B747_perf_db.max_alt(s.t, s.gw, s.isa) then s = nil end
  if s and s.eo and s.crz > B747_fms_eo_crz_max() + 1 then s = nil end
  predResult = s and B747_pred_model.predict(s) or nil
  put_profile(s, predResult)
  vnav_geo_set(s, predResult)
end

-- VNAV (6-1/6-2 step 9b; notes/ATA-34-61-FMC.md §56): the FMC's vertical
-- guidance (B747.68.vnav_model.lua) every frame from the predictions'
-- descent path (fixed to the ground by the distance to go to the E/D), the
-- FMC's speeds, CRZ ALT, the route's constraints and the MCP altitude into
-- laminar/B747/fms/vnav/* for the AFDS and the A/T (step 9c: until then
-- they fly the old VNAV)
dofile("B747.68.vnav_model.lua")
B747DR_fms_vnav_valid = find_dataref("laminar/B747/fms/vnav/valid")
B747DR_fms_vnav_phase = find_dataref("laminar/B747/fms/vnav/phase")
B747DR_fms_vnav_mode = find_dataref("laminar/B747/fms/vnav/mode")
B747DR_fms_vnav_cas = find_dataref("laminar/B747/fms/vnav/cas")
B747DR_fms_vnav_mach = find_dataref("laminar/B747/fms/vnav/mach")
B747DR_fms_vnav_mach_mode = find_dataref("laminar/B747/fms/vnav/mach_mode")
B747DR_fms_vnav_alt = find_dataref("laminar/B747/fms/vnav/alt")
B747DR_fms_vnav_vs = find_dataref("laminar/B747/fms/vnav/vs")
B747DR_fms_vnav_path_dev = find_dataref("laminar/B747/fms/vnav/path_dev")
B747DR_fms_vnav_at = find_dataref("laminar/B747/fms/vnav/at")
B747DR_fms_vnav_msg = find_dataref("laminar/B747/fms/vnav/msg")
B747DR_fms_vnav_on_app = find_dataref("laminar/B747/fms/vnav/on_app")
B747DR_fms_vnav_perf = find_dataref("laminar/B747/fms/vnav/perf")
B747DR_fms_vnav_dist = find_dataref("laminar/B747/fms/vnav/dist")
-- (step 9h4b) the engine-out driftdown for the A/T
B747DR_fms_vnav_dd = find_dataref("laminar/B747/fms/vnav/dd")
B747DR_fms_alt_sel_pushes = find_dataref("laminar/B747/autopilot/alt_sel_pushes")
-- (step 9e3) the AFDS's pitch mode (the FMA's: 1 TO/GA, in the air G/A's)
B747DR_fms_afds_pitch = find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
-- (step 9d3) speed intervention (the AP's: the IAS/MACH window opened with
-- VNAV) and the MCP's speed (kt, a Mach as Mach x 100)
B747DR_fms_spd_int = find_dataref("laminar/B747/autopilot/spd_intervention")
B747DR_fms_ias_dial = find_dataref("laminar/B747/autopilot/ias_dial_value")
B747DR_fms_vnav_mcp_alt = find_dataref("laminar/B747/autopilot/heading/altitude_dial_ft")
B747DR_fms_vnav_vmax = find_dataref("laminar/B747/airspeed/Vmax")
B747DR_fms_vnav_vminm = find_dataref("laminar/B747/airspeed/Vminm")
simDR_fms_vnav_flaps = find_dataref("sim/cockpit2/controls/flap_ratio")
local vnavState = B747_vnav_model.new()
function B747_fms_vnav_phase() return vnavState.phase end
local vnavIn = {P = B747_perf_db, sched = B747_pred_model.schedule, crz = B747_pred_model.crz_mach}
local vnavTakeoff = {}
local vnavSpdInt = {}
-- the distance to go to the E/D VNAV's path is looked up with (NM; nil
-- without a path)
function B747_fms_vnav_dist() return vnavIn.d_ed end
-- the predictions' path by the distance to go to the E/D, the route's first
-- point and its distance on to the E/D, the climb's and descent's
-- constraints (route order: {upper} and {alt})
local vnavGeo = nil
local VNAV_PHASE = {CLB = 1, CRZ = 2, DES = 3}
local VNAV_MODE = {SPD = 1, PTH = 2}
function vnav_geo_set(s, r)
  if not (s and r) then vnavGeo = nil return end
  local g = {clb = {}, des = {}}
  local lx, acc = {}, 0
  for i, l in ipairs(s.legs) do acc = acc + l.dist; lx[i] = acc end
  -- the climb's legs: the SID's, else those before half the way (the
  -- predictions')
  local clbLast = s.clb_last
  if not clbLast then
    local half = ((s.ed and lx[s.ed]) or acc) / 2
    clbLast = 0
    for i = 1, #s.legs do if lx[i] <= half then clbLast = i end end
  end
  -- (step 9d1) the climb's last point, for the altitude selector's push
  g.clb_end = clbLast > 0 and s.legs[clbLast] and s.legs[clbLast].p1 or nil
  g.clb_none = clbLast == 0
  -- (step 9d2a) the points of the legs before the T/D (the climb's and the
  -- cruise's: the early descent deletes their constraints, FMSPG p.3.5-5)
  g.pre_td = {}
  if r.td then
    for i, l in ipairs(s.legs) do
      if l.p1 and lx[i] < r.td then g.pre_td[l.p1] = true end
    end
  end
  for i, l in ipairs(s.legs) do
    local c = l.con
    if c and (not s.ed or i < s.ed) then
      if i <= clbLast then
        if c.kind == "AT" or c.kind == "B" or c.kind == "W" then g.clb[#g.clb + 1] = c.a end
      else
        g.des[#g.des + 1] = c.kind == "W" and c.b or c.a
      end
    end
  end
  if r.dp and r.ed then
    local dp = r.dp
    g.path = {e = {}, h = dp.h, k = dp.k}
    for i = 1, #dp.x do g.path.e[i] = r.ed - dp.x[i] end
    g.hed = dp.h[1]
    -- (step 9e2) the E/D's point, for END OF DES
    g.ed_p = s.ed and s.legs[s.ed] and s.legs[s.ed].p1 or nil
    -- the first leg with a point, the legs' distance after it to the E/D;
    -- (step 9c) each point's distance on to the E/D, by the point (the
    -- route's legs keep their tables as LNAV sequences them: the distance
    -- goes on from the active leg's point between the predictions; s140
    -- went 700 ft off the path in the 10 s after ATMUG, the distance
    -- growing from the point passed)
    local sum = 0
    for i = 1, s.ed do
      local l = s.legs[i]
      if not g.first then
        if l.p1 then g.first = l.p1 end
      else
        sum = sum + l.dist
      end
    end
    g.sum = sum
    g.rem = {}
    local rem = 0
    for i = s.ed, 1, -1 do
      local l = s.legs[i]
      if l.p1 then g.rem[l.p1] = rem end
      rem = rem + l.dist
    end
  end
  vnavGeo = g
end
-- (step 9d2a) the distance to go to the T/D (NM: where the path reaches
-- CRZ ALT, else its top; negative past it), nil without a path
function B747_fms_vnav_td()
  local inp = vnavIn
  if not (inp.path and inp.d_ed) then return nil end
  local e = inp.crz_alt and B747_vnav_model.path_e_at(inp.path, inp.crz_alt) or inp.path.e[#inp.path.e]
  return inp.d_ed - e
end
-- the VNAV page active (1 CLB, 2 CRZ, 3 DES; 0 on the ground or without an
-- active route) and the cruise climb's or descent's ("CLB", "DES") for the
-- CDU's titles (FCOM p.1327, p.1347, p.1391; before, the AP's old
-- flightPhase)
function B747_fms_vnav_page()
  if not B747_fmc_route.active or simDR_onGround == 1 then return 0, nil end
  if vnavState.crz_chg then return 2, vnavState.crz_chg end
  return VNAV_PHASE[vnavState.phase] or 0, nil
end
-- (step 9h3b) the active page's title for the target: LIM SPD where the flap
-- placard or the minimum speed limits it, VREF + 100 in the engine-out
-- takeoff's climb (FCOM p.1265), nil else
function B747_fms_vnav_title() return vnavState.out.title end
-- (step 9h4b) the engine-out driftdown (FCOM p.1268): VNAV's in it
function B747_fms_vnav_dd() return vnavState.dd ~= nil end
-- (step 9d3) speed intervention: the FMC's target the MCP speed, the active
-- page's title MCP SPD and PROGRESS's 5L (FCOM p.643; ATA34_2 p.557, p.563,
-- p.568, p.623)
function B747_fms_spd_int() return B747DR_fms_spd_int == 1 end
-- (step 9e2) on approach (FCOM p.1261): a published approach's first point
-- passed in the air (the VFR approach's: not made); END OF DES (p.1391):
-- the E/D's point passed, kept until a new E/D is ahead or the airplane is
-- on the ground; on approach ends with it. (step 9e3) A missed approach
-- ends both: that approach's legs no longer count (FCOM p.1261)
local vnavEndDes = false
local function point_passed(p)
  for _, l in ipairs(B747_fmc_route.rte.passed) do
    if l.fix == p and not missed_leg(l) then return true end
  end
  return false
end
local function on_approach()
  local st = B747_fmc_route
  if not st.active or simDR_onGround == 1 then return false end
  for _, l in ipairs(st.rte.passed) do
    if l.proc == "APPR" and l.fix and not missed_leg(l) then return true end
  end
  return false
end
function B747_fms_end_des() return vnavEndDes end
function B747_fms_on_app() return vnavIn.on_app == true end
-- (step 9e3) the missed approach (FCOM p.1261-1262; FMSPG p.97; ATA34_2
-- p.472: the FMC goes by the AFDS's go-around, not by the TO/GA switches):
-- the descent's altitude constraints below the airplane deleted from the
-- active route (its legs before the missed approach's; the waypoints
-- kept), the missed approach's highest altitude CRZ ALT (none: CRZ ALT
-- kept, estimate), the climb phase; on approach and END OF DES over, the
-- approach's runway no E/D
function B747_fms_missed_approach()
  local st = B747_fmc_route
  local r, alt = st.rte, simDR_pressureAlt1
  local skip = {}
  for _, l in ipairs(r.passed) do
    if l.proc == "APPR" then skip[l.orig or l] = true end
  end
  local changed, top, ma = false, nil, false
  for i, l in ipairs(r.legs) do
    if l.proc == "APPR" then skip[l.orig or l] = true end
    ma = ma or l.missed == true
    if ma then
      local a = math.max(l.alt or 0, l.alt2 or 0)
      if l.proc == "APPR" and a > 0 and (not top or a > top) then top = a end
    elseif l.alt and not l.altterm and math.max(l.alt, l.alt2 or l.alt) < alt then
      changed = B747_route_model.delete_alt_active(st, i) or changed
    end
  end
  vnavMissed = skip
  if top then B747BR_cruiseAlt = top end
  vnavMissedCrz = B747BR_cruiseAlt
  vnavEndDes = false
  B747_vnav_model.missed(vnavState)
  -- the approach's descent path gone at once, the predictions' next without
  -- it (s150's G/A 255 ft above the MCP altitude in its capture went back
  -- to the descent past the old T/D in the same frame)
  vnavGeo = nil
  if changed then B747_fmc_route_changed() end
  B747_fms_preds_now()
end
-- the descent's highest altitude constraint ahead (ft) or nil
function B747_fms_des_top()
  local top = nil
  for _, a in ipairs(vnavGeo and vnavGeo.des or {}) do
    if not top or a > top then top = a end
  end
  return top
end
-- the early descent (DES NOW's: FCOM p.1260, p.1389, p.1393): the VNAV
-- model's, the constraints of the legs before the T/D (the climb's and the
-- cruise's: FMSPG p.3.5-5) deleted from the active route; false in the
-- descent already
function B747_fms_des_now()
  if not B747_vnav_model.des_now(vnavState) then return false end
  local g, st = vnavGeo, B747_fmc_route
  if g and g.pre_td and st.active then
    local changed = false
    for i, l in ipairs(st.rte.legs) do
      if l.fix and g.pre_td[l.fix] and l.alt and not l.altterm then
        changed = B747_route_model.delete_alt_active(st, i) or changed
      end
    end
    if changed then B747_fmc_route_changed() end
  end
  return true
end
-- a route's legs with an altitude constraint (not on a leg ending at an
-- altitude): fn(i, leg, the climb's, its lowest, its highest) for each
-- until it gives true (then true). The climb's legs: to the predictions'
-- climb's last point (step 9d1), all without the predictions
local function vnav_con_legs(r, fn)
  local g = vnavGeo
  local inClimb = not (g and g.clb_none)
  for i, l in ipairs(r.legs) do
    local clb = inClimb
    if g and g.clb_end and l.fix == g.clb_end then inClimb = false end
    if l.alt and not l.altterm then
      local lo, hi = l.alt, l.alt
      if l.akind == "AB" then lo, hi = math.min(l.alt, l.alt2 or l.alt), math.max(l.alt, l.alt2 or l.alt) end
      if fn(i, l, clb, lo, hi) then return true end
    end
  end
  return false
end
-- the MCP altitude selector's push (step 9d1; FCOM p.649): in the climb or
-- the descent the next altitude constraint between the airplane and the
-- MCP altitude deleted from the active route; without one, in the climb
-- with the MCP above CRZ ALT, or in the cruise above it, CRZ ALT the MCP
-- altitude; (step 9d2a) in the cruise below it the early descent or a
-- cruise descent
local DES_NOW_NM = 50
local vnavPushSeen = nil
function B747_fms_alt_sel_push()
  local st = B747_fmc_route
  local alt, mcp, ph = simDR_pressureAlt1, B747DR_fms_vnav_mcp_alt, vnavState.phase
  if st.active and ph ~= "CRZ" then
    local up = mcp > alt
    -- the climb's legs in the climb, the others in the descent
    local done = vnav_con_legs(st.rte, function(i, l, clb, lo, hi)
      if vnavGeo and clb ~= (ph == "CLB") then return false end
      local a = up and hi or lo
      if (up and a > alt and a < mcp) or (not up and a < alt and a > mcp) then
        B747_route_model.delete_alt_active(st, i)
        B747_fmc_route_changed()
        return true
      end
      return false
    end)
    if done then return end
  end
  local crz = B747BR_cruiseAlt
  if crz and crz > 0 and (ph == "CLB" or ph == "CRZ") and mcp > crz + 50 then
    B747BR_cruiseAlt = mcp
    B747_fms_preds_now()
  elseif crz and crz > 0 and ph == "CRZ" and mcp < crz - 50 then
    -- (step 9d2a) below CRZ ALT: within 50 NM of the T/D or under the
    -- descent's highest constraint the early descent (FCOM p.649, p.1260,
    -- p.1389: DES NOW's; ATA34_2 p.624), else a cruise descent to it (CRZ
    -- ALT the MCP's, the DES page's SPD TRANS and SPD RESTR above it
    -- deleted: FCOM p.1257, p.1261); past the T/D nothing (the descent by
    -- itself: the MCP below CRZ ALT)
    local td, top = B747_fms_vnav_td(), B747_fms_des_top()
    if td and td <= 0 then return end
    if td and (td <= DES_NOW_NM or (top and mcp < top)) then
      B747_fms_des_now()
      return
    end
    B747BR_cruiseAlt = mcp
    local d = fmsModules["data"]
    local ta, ra = tonumber(d.desspdtransalt), tonumber(d.desrestalt)
    if ta and mcp < ta then setFMSData("destranspd", "---") setFMSData("desspdtransalt", "-----") end
    if ra and mcp < ra then setFMSData("desrestspd", "---") setFMSData("desrestalt", "-----") end
    B747_fms_preds_now()
  end
end
-- the VNAV pages' 6R (step 9d2b; FCOM p.1329, p.1393; FMSPG p.116,
-- p.3.5-4 to 3.5-6): CLB DIR> on the active CLB page with a climb
-- constraint between the airplane and CRZ ALT; DES NOW> on the DES page
-- with a T/D ahead and the descent not active; DES DIR> on the active DES
-- page with a descent constraint between the airplane and the E/D. A push
-- modifies the active route, its constraints deleted (CLB DIR's between
-- the airplane and the lower of the MCP altitude and CRZ ALT, one at the
-- MCP altitude kept; DES DIR's between the airplane and the MCP altitude;
-- DES NOW's those of the legs before the T/D, the climb's and cruise's)
-- for EXEC (the EXEC light: FMSPG p.3.5-5); its EXEC begins DES NOW's
-- early descent, ERASE drops it
local vnavMod = nil
function B747_fms_vnav_mod() return vnavMod end
function B747_fms_vnav_prompt(pg)
  local st = B747_fmc_route
  if not st.active then return nil end
  local active = B747_fms_vnav_page()
  local alt = simDR_pressureAlt1
  if pg == 1 then
    local crz = B747BR_cruiseAlt
    if active ~= 1 or not (crz and crz > 0) then return nil end
    local any = vnav_con_legs(st.rte, function(i, l, clb, lo, hi) return clb and hi > alt and lo < crz end)
    return any and "CLB DIR>" or nil
  elseif pg == 3 then
    if active == 3 then
      local ed = vnavGeo and vnavGeo.hed or 0
      local any = vnav_con_legs(st.rte, function(i, l, clb, lo, hi) return not clb and lo < alt and hi > ed end)
      return any and "DES DIR>" or nil
    end
    local td = B747_fms_vnav_td()
    if td and td > 0 then return "DES NOW>" end
  end
  return nil
end
function B747_fms_vnav_select(kind)
  local st, R = B747_fmc_route, B747_route_model
  if not st.active or B747_fms_vnav_prompt(kind == "CLB DIR" and 1 or 3) ~= kind .. ">" then return end
  local alt, mcp = simDR_pressureAlt1, B747DR_fms_vnav_mcp_alt
  local r = R.edit(st)
  vnav_con_legs(r, function(i, l, clb, lo, hi)
    local del = false
    if kind == "CLB DIR" then
      local top = math.min(mcp, B747BR_cruiseAlt)
      del = clb and hi > alt and lo < top and not (lo <= mcp and hi >= mcp)
    elseif kind == "DES DIR" then
      del = not clb and lo < alt and hi > mcp
    else
      del = vnavGeo and vnavGeo.pre_td and l.fix and vnavGeo.pre_td[l.fix]
    end
    -- the altitude only (FCOM p.1329, p.1393: the altitude constraints;
    -- the speed kept as the selector's push keeps it)
    if del then l.alt, l.alt2, l.akind = nil, nil, nil end
    return false
  end)
  vnavMod = kind
  B747_fmc_route_changed()
end
-- EXEC (the route's after its modification) and ERASE
function B747_fms_vnav_exec()
  if vnavMod == "DES NOW" then B747_vnav_model.des_now(vnavState) end
  vnavMod = nil
end
function B747_fms_vnav_erase() vnavMod = nil end
local vnavGaSeen = nil
local vnavEoNext = 0
local function update_vnav()
  local inp = vnavIn
  local pushes = B747DR_fms_alt_sel_pushes
  if vnavPushSeen ~= nil and pushes ~= vnavPushSeen then B747_fms_alt_sel_push() end
  vnavPushSeen = pushes
  -- (step 9e3) the AFDS's G/A engaged in the air (the FMA's pitch to TO/GA
  -- there; T/O's comes on on the ground) in the descent, on approach or at
  -- END OF DES: the missed approach
  local ga = B747DR_fms_afds_pitch == 1
  if ga and vnavGaSeen == false and simDR_onGround == 0 and B747_fmc_route.active
      and (vnavState.phase == "DES" or inp.on_app or vnavEndDes) then
    B747_fms_missed_approach()
  end
  vnavGaSeen = ga
  -- (after the missed approach's: its path gone)
  local g = vnavGeo
  -- (step 9d2b) the modification gone (executed or erased elsewhere): its
  -- VNAV part too
  if vnavMod and not B747_fmc_route.mod then vnavMod = nil end
  local perf = B747_fms_perf()
  inp.alt = simDR_pressureAlt1
  inp.vs = simDR_vvi_fpm_pilot
  inp.gs = simDR_groundspeed * 1.94384
  inp.ground = simDR_onGround == 1
  inp.active = B747_fmc_route.active
  local gw = perf_gw_t()
  inp.kg = gw and gw * 1000 or nil
  inp.crz_alt = (B747BR_cruiseAlt and B747BR_cruiseAlt > 0) and B747BR_cruiseAlt or nil
  inp.mcp_alt = B747DR_fms_vnav_mcp_alt
  inp.clb, inp.des, inp.crzspd = B747_fms_schedules(perf)
  inp.flaps_placard = simDR_fms_vnav_flaps > 0.01 and B747DR_fms_vnav_vmax > 0 and B747DR_fms_vnav_vmax or nil
  inp.vmin = B747DR_fms_vnav_vminm > 0 and B747DR_fms_vnav_vminm or nil
  -- (step 9e2) END OF DES and on approach
  if inp.ground or not inp.active then
    vnavEndDes = false
  elseif g and g.ed_p then
    vnavEndDes = point_passed(g.ed_p)
  end
  inp.end_des = vnavEndDes
  inp.on_app = (not vnavEndDes) and on_approach()
  local onApp = inp.on_app and 1 or 0
  if B747DR_fms_vnav_on_app ~= onApp then B747DR_fms_vnav_on_app = onApp end
  -- (step 9e3) after a missed approach while its CRZ ALT stays; over on the
  -- ground
  if inp.ground then vnavMissed, vnavMissedCrz = nil, nil end
  inp.missed = vnavMissed ~= nil and inp.crz_alt ~= nil and vnavMissedCrz == inp.crz_alt
  -- (step 9e1) the best holding speed for the descent's slow speed
  -- reversion (FCOM p.1259; PI.11.6), in the descent only; (step 9e3) the
  -- cruise's after a missed approach too
  inp.hold_cas = ((vnavState.phase == "DES" or inp.missed) and perf and inp.kg) and (B747_perf_db.hold(perf, inp.kg, inp.alt)) or nil
  -- (step 9d3) speed intervention: the MCP's speed (FCOM p.643)
  if B747_fms_spd_int() then
    local v, mach = B747DR_fms_ias_dial, simDR_autopilot_airspeed_is_mach == 1
    vnavSpdInt.mach = mach and v / 100 or nil
    vnavSpdInt.cas = (not mach) and v or nil
    inp.spd_int = vnavSpdInt
  else
    inp.spd_int = nil
  end
  -- the takeoff (step 9c; FCOM p.1255): V2 selected on TAKEOFF REF (999
  -- none), ACCEL HT above the origin, the flap handle; the airspeed, VNAV
  -- engaged (the AFDS's)
  local rte = B747_fmc_route.rte
  local v2 = B747DR_airspeed_V2
  vnavTakeoff.v2 = (v2 > 0 and v2 < 900) and v2 or nil
  vnavTakeoff.accel_alt = (rte and rte.origin and rte.origin.elev or 0) + (tonumber(fmsModules["data"].accelht) or 1000)
  -- (step 9h3b) the E/O ACCEL HT above the origin; an engine failure
  -- sensed, VREF 30 (FCOM p.1265-1266)
  vnavTakeoff.eo_accel_alt = (rte and rte.origin and rte.origin.elev or 0) + (tonumber(fmsModules["data"].eoaccelht) or 1000)
  vnavTakeoff.flaps = simDR_fms_vnav_flaps
  inp.takeoff = vnavTakeoff
  inp.eo, inp.vref = B747_fms_eng_out(), B747DR_airspeed_Vf30
  -- (step 9h4b) ENG OUT active: the CRZ page's engine-out maximum for the
  -- driftdown, once a second
  local eo = B747_fms_eo()
  if not (eo.active and inp.kg) then
    inp.eo_max, vnavEoNext = nil, 0
  elseif simDRTime >= vnavEoNext then
    inp.eo_max, vnavEoNext = B747_fms_eo_crz_max(), simDRTime + 1
  end
  inp.ias = simDR_ias_pilot
  inp.engaged = B747DR_ap_vnav_state == 2
  inp.clb_alt, inp.des_alt, inp.path, inp.d_ed = nil, nil, nil, nil
  if g then
    for _, a in ipairs(g.clb) do
      if a > inp.alt - 100 and (not inp.crz_alt or a < inp.crz_alt) then inp.clb_alt = a break end
    end
    inp.des_alt = g.des[1] or g.hed
    if g.path and g.first then
      -- the distance to go: to the active route's first point the
      -- predictions had (step 9c: the active leg's once LNAV sequenced),
      -- else the first then, and on from it
      local p, rem = g.first, g.sum
      local st = B747_fmc_route
      if g.rem and st.active then
        for _, l in ipairs(st.rte.legs) do
          if l.fix and g.rem[l.fix] then p, rem = l.fix, g.rem[l.fix] break end
        end
      end
      local _, d1 = B747_route_model.course(simDR_latitude, simDR_longitude, p.lat, p.lon)
      inp.path = g.path
      inp.d_ed = d1 + rem
    end
  end
  local out = B747_vnav_model.update(vnavState, inp)
  B747DR_fms_vnav_valid = out.valid and 1 or 0
  B747DR_fms_vnav_phase = VNAV_PHASE[out.phase] or 0
  B747DR_fms_vnav_mode = VNAV_MODE[out.mode] or 0
  B747DR_fms_vnav_cas = out.cas or 0
  B747DR_fms_vnav_mach = out.mach or 0
  B747DR_fms_vnav_mach_mode = out.mach_mode and 1 or 0
  B747DR_fms_vnav_alt = out.alt or 0
  B747DR_fms_vnav_vs = out.vs or 0
  B747DR_fms_vnav_path_dev = out.path_dev or 0
  B747DR_fms_vnav_at = out.at or 0
  -- (step 9h4b) the driftdown; the predictions at once when it starts or
  -- ends (its level off: s157's first ones were before it)
  local dd = out.dd and 1 or 0
  if B747DR_fms_vnav_dd ~= dd then
    B747DR_fms_vnav_dd = dd
    B747_fms_preds_now()
  end
  -- (step 9e1) THRUST REQUIRED, DRAG REQUIRED (the AP's notifications)
  local msg = out.msg == "THRUST" and 1 or out.msg == "DRAG" and 2 or 0
  if B747DR_fms_vnav_msg ~= msg then B747DR_fms_vnav_msg = msg end
  B747DR_fms_vnav_dist = inp.d_ed or 0
  -- RESET MCP ALT (step 9d1; FCOM p.665, p.1433: flag 33, DRindex 32 + 1;
  -- before, the old VNAV's T/D): VNAV in the cruise within two minutes of
  -- the T/D (where the path reaches CRZ ALT) or past it with the MCP
  -- altitude not below CRZ ALT (past it: estimate)
  local reset = 0
  if B747DR_ap_vnav_state == 2 and out.phase == "CRZ" and inp.crz_alt
      and inp.gs > 100 and inp.mcp_alt >= inp.crz_alt - 50 then
    local td = B747_fms_vnav_td()
    if td and td / inp.gs * 60 <= 2 then reset = 1 end
  end
  if B747DR_fmc_notifications[33] ~= reset then B747DR_fmc_notifications[33] = reset end
  -- (step 9c) PERF INIT's gross weight and cost index, and CRZ ALT, entered
  local perfIn = inp.kg and inp.crz_alt and tonumber(fmsModules["data"].costindex)
  B747DR_fms_vnav_perf = perfIn and 1 or 0
end
-- (6-1/6-2 step 9g1; notes/ATA-34-61-FMC.md §73) the thrust limit's mode
-- (B747.68.thrlim_model.lua) into laminar/B747/engines/ref_thr_limit_mode
-- (before, the EEC's from the AP's flightPhase) and the ratings the EEC
-- reads (laminar/B747/engine/derate/TO, CLB); the takeoff derates' thrust
-- reductions (%) FCOM p.1314's examples, the operator's: P&W and RR TO 1
-- 8, TO 2 20, GE 5 and 15
dofile("B747.68.thrlim_model.lua")
B747DR_fms_thrlim_mode = find_dataref("laminar/B747/engines/ref_thr_limit_mode")
B747DR_fms_thr_pushes = find_dataref("laminar/B747/autopilot/thr_pushes")
B747DR_fms_toga_pushes = find_dataref("laminar/B747/autopilot/toga_pushes")
simDR_fms_radio_alt = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
-- (step 9g3) the assumed temperature (°C, -99 none) and the takeoff derate
-- (%) for the EEC's reference, the takeoff's thrust reduction (%) back
B747DR_fms_thrlim_sel = find_dataref("laminar/B747/fms/thrlim/sel")
B747DR_fms_thrlim_to_pct = find_dataref("laminar/B747/fms/thrlim/to_pct")
B747DR_fms_to_reduction = find_dataref("laminar/B747/engines/to_reduction")
simDR_fms_thrlim_oat = find_dataref("sim/weather/temperature_ambient_c")
-- (step 9g4) the EICAS's thrust limit line ("D-TO 1 +38C": FCOM p.831)
B747DR_fms_thrlim_eicas = find_dataref("laminar/B747/fms/thrlim/eicas")
-- the mode as a number for the EEC (in the other XTLua plugin, which does
-- not see this one's string writes: s152 and s141's references were TO's)
B747DR_fms_thrlim_code = find_dataref("laminar/B747/fms/thrlim/code")
local THRLIM_CODE = {TO = 1, CLB = 2, CRZ = 3, CON = 4, GA = 5}
-- (step 9h3) the engines inoperative (the engines' N2 under the ENG FAIL
-- speed: B747.40.engine_start_model.lua), sensed in the air (on the
-- ground before the start all four are)
B747DR_fms_eng_inop = find_dataref("laminar/B747/engines/inop")
function B747_fms_eng_out()
  if simDR_onGround == 1 then return 0 end
  local n = 0
  for i = 0, 3 do
    if B747DR_fms_eng_inop[i] > 0.5 then n = n + 1 end
  end
  return n
end
local thrlimState = B747_thrlim_model.new()
local thrlimIn = {}
local thrlimSeen = {}
function B747_fms_thrlim_pct(n)
  if n == 0 then return 0 end
  return (B747DR_fms_engine_type == 1 and {5, 15} or {8, 20})[n]
end
-- the THRUST LIM page's selections: TO n on the ground (false in the air),
-- CLB n, GA, CON or CRZ in the air (false while GA is held)
function B747_fms_thrlim_to(n) return B747_thrlim_model.select_to(thrlimState, n, B747_fms_thrlim_pct(n), simDR_onGround == 1) end
function B747_fms_thrlim_clb(n) return B747_thrlim_model.select_clb(thrlimState, n, simDR_onGround == 1) end
function B747_fms_thrlim_sel(kind) return B747_thrlim_model.select(thrlimState, kind) end
function B747_fms_thrlim() return thrlimState end
-- the AFDS's pitch modes (the FMA's numbers) the model looks at
local THRLIM_PITCH = {[4] = "VNAV", [5] = "VNAV", [6] = "VNAV", [8] = "FLCH"}
local function update_thrlim()
  local inp, r = thrlimIn, B747_fmc_route.rte
  inp.ground = simDR_onGround == 1
  inp.alt_agl = simDR_pressureAlt1 - ((r and r.origin and r.origin.elev) or 0)
  inp.thr_red = tonumber(fmsModules["data"].thrred) or 5
  inp.flaps = simDR_fms_vnav_flaps
  local pitch = B747DR_fms_afds_pitch
  inp.pitch, inp.gs = THRLIM_PITCH[pitch], pitch == 2
  inp.vnav = B747DR_ap_vnav_state == 2
  inp.phase = vnavState.phase
  inp.flch_up = pitch == 8 and B747DR_fms_vnav_mcp_alt > simDR_pressureAlt1 + 50
  local n, g = B747DR_fms_thr_pushes, B747DR_fms_toga_pushes
  inp.thr = thrlimSeen.thr ~= nil and n ~= thrlimSeen.thr
  inp.toga = thrlimSeen.toga ~= nil and g ~= thrlimSeen.toga
  thrlimSeen.thr, thrlimSeen.toga = n, g
  inp.ra = simDR_fms_radio_alt
  -- (step 9g3) SEL above the OAT: D- (FCOM p.1273, p.1314)
  local sel = tonumber(fmsModules["data"]["thrustsel"])
  inp.sel_up = sel ~= nil and sel > simDR_fms_thrlim_oat
  -- (the derate's own %, or the EEC's whole reduction with the assumed
  -- temperature's)
  inp.to_red = math.max(B747_fms_thrlim_pct(thrlimState.to), B747DR_fms_to_reduction)
  -- (step 9h3) an engine inoperative: the takeoff's CON at VREF 30 + 98
  inp.eo, inp.ias, inp.vref = B747_fms_eng_out(), simDR_ias_pilot, B747DR_airspeed_Vf30
  -- (step 9h4a) the engine-out mode: a second engine's data; CON kept
  -- while it is active
  B747_eo_model.update(B747_fms_eo(), inp.eo)
  inp.eo_vnav = B747_fms_eo().active
  local mode = B747_thrlim_model.update(thrlimState, inp)
  if B747DR_fms_thrlim_mode ~= mode then B747DR_fms_thrlim_mode = mode end
  local s = thrlimState
  local code = 10 * THRLIM_CODE[s.mode] + ((s.mode == "TO" and s.to) or (s.mode == "CLB" and s.clb) or 0)
    + ((s.mode == "TO" and s.d) and 100 or 0)
  if B747DR_fms_thrlim_code ~= code then B747DR_fms_thrlim_code = code end
  -- (step 9g4) the EICAS's line: with D- the assumed temperature after
  local eicas = mode
  if thrlimState.d and sel then eicas = string.format("%s %+dC", mode, math.floor(sel + 0.5)) end
  if B747DR_fms_thrlim_eicas ~= eicas then B747DR_fms_thrlim_eicas = eicas end
  local selOut = (sel and not thrlimState.no_sel) and sel or -99
  if B747DR_fms_thrlim_sel ~= selOut then B747DR_fms_thrlim_sel = selOut end
  local pct = B747_fms_thrlim_pct(thrlimState.to)
  if B747DR_fms_thrlim_to_pct ~= pct then B747DR_fms_thrlim_to_pct = pct end
  if toderate ~= thrlimState.to then toderate = thrlimState.to end
  if clbderate ~= thrlimState.clb then clbderate = thrlimState.clb end
end
-- UNABLE CRZ ALT: in the climb, the climb to a cruise altitude meets the
-- descent path before it (FCOM p.1436; estimate: no minimum cruise time)
function B747_fms_unable_crz(crz)
  local s = B747_fms_pred_input(crz)
  if not s or s.phase ~= "clb" or not s.ed then return false end
  local r = B747_pred_model.predict(s)
  return r.tc == nil and r.td ~= nil
end
B747_fmc_lnav=B747_lnav_model.new(B747_path_model)
local lnavPath=nil
-- the active leg the path was built with (a new one not by sequencing:
-- captured again, FCOM p.644), sequencing now, LNAV engaged a frame ago
local lnavFirst=nil
local lnavSequencing=false
local lnavWasEngaged=false
B747DR_fms_lnav_valid=find_dataref("laminar/B747/fms/lnav/valid")
B747DR_fms_lnav_roll=find_dataref("laminar/B747/fms/lnav/roll")
B747DR_fms_lnav_mode=find_dataref("laminar/B747/fms/lnav/mode")
B747DR_fms_lnav_xtk=find_dataref("laminar/B747/fms/lnav/xtk")
B747DR_fms_lnav_dtk=find_dataref("laminar/B747/fms/lnav/dtk")
B747DR_fms_lnav_route=find_dataref("laminar/B747/fms/lnav/route")
B747DR_fms_ap_lnav_state=find_dataref("laminar/B747/autopilot/lnav_state")
simDR_lnav_trk=find_dataref("sim/flightmodel/position/hpath")
simDR_lnav_tas=find_dataref("sim/flightmodel/position/true_airspeed")
local function lnav_var(lat,lon) return B747_navdb.variation(B747_fmc_navdb,lat,lon) end
-- a leg as LNAV flies it: its fix or name, a direct-to's or LNAV's start,
-- a hold at its fix
local function lnav_leg_key(l)
  if not l then return "" end
  local k=l.fix and string.format("%s %.5f %.5f",l.fix.ident,l.fix.lat,l.fix.lon) or (l.name or (l.disc and "DISC" or ""))
  if B747_route_model.is_hold(l) then k=k.." HOLD" end
  local f=(l.dto and l.from) or l.start
  if f then k=k..string.format(" %.5f %.5f",f.lat,f.lon) end
  return k
end
-- RTE 1's path, active or not: LNAV's and the ND's line's shape in
-- X-Plane's flight plan (step 6d)
local routePath=nil
-- the holds' racetracks on the ND's line (step 7b; FMSPG p.223; FCOM
-- p.1148): the hold whose fix is the TO fix as LNAV makes it (when the
-- fix becomes the TO fix, anew at each crossing: FMSPG p.224), the others
-- of one size (the small symbol: 210 kt and their legs, estimate)
local HOLD_SYMBOL_KT=210
local lnavAir=nil
local holdDrawn=nil
-- the hold whose fix is the TO fix: its leg and racetrack, or nil (on
-- the ground the small symbol: estimate)
local function lnav_to_hold()
  local path=lnavPath
  if not path or simDR_onGround==1 then return nil end
  local s=B747_fmc_lnav
  local e1,e2=path[1],path[2]
  local i,t
  if e1 and e1.kind=="hold" then
    i=1
    local h=s.hp
    if h and h.t and h.lat==e1.b.lat and h.lon==e1.b.lon then t=h.t end
  elseif e2 and e2.kind=="hold" and e1 and e1.b and e1.b.lat==e2.b.lat and e1.b.lon==e2.b.lon then
    i=2
    local a=s.ahead
    if a and a.lat==e2.b.lat and a.lon==e2.b.lon then t=a.t end
  end
  if not i then return nil end
  if not t and lnavAir then t=B747_lnav_model.hold_now(s,path[i],lnavAir) end
  if not t then return nil end
  return i,t
end
-- the procedure turn LNAV flies (step 7f): its shape on the ND's line
local ptDrawn=nil
local function lnav_pturn()
  local e1=lnavPath and lnavPath[1]
  local h=B747_fmc_lnav.ptn
  if e1 and e1.kind=="pturn" and h and h.leg==e1.leg then return h end
  return nil
end
local function lnav_hold_sizes()
  local i,t=lnav_to_hold()
  holdDrawn=i and {i=i,r=t.r,l=t.l} or nil
  local h=lnav_pturn()
  ptDrawn=h
  if not i and not h then return nil end
  local out={}
  if i then out[i]={r=t.r,l=t.l} end
  if h then out[1]={pt=h.t} end
  return out
end
-- the TO hold's racetrack other than drawn (by 2 % or 0.05 nm: estimate):
-- drawn anew (true)
local function lnav_hold_changed()
  local i,t=lnav_to_hold()
  local d=holdDrawn
  local function off(a,b) return math.abs(a-b)>math.max(0.05,0.02*b) end
  local changed
  if not i then changed=d~=nil
  else changed=not d or d.i~=i or off(t.r,d.r) or off(t.l,d.l) end
  if changed then holdDrawn=i and {i=i,r=t.r,l=t.l} or nil end
  if lnav_pturn()~=ptDrawn then changed=true end
  return changed
end
function B747_fmc_lnav_build()
  local st=B747_fmc_route
  local r=st.rte
  routePath=B747_path_model.build(r.legs,B747_route_model.leg_from(r,1),{var=lnav_var,alt=simDR_pressureAlt1})
  if not st.active then lnavPath,lnavFirst=nil,nil return end
  local key=lnav_leg_key(r.legs[1])
  if key~=lnavFirst and not lnavSequencing then B747_lnav_model.reset(B747_fmc_lnav) end
  lnavFirst=key
  lnavPath=routePath
  -- the lateral offset (step 7d): LNAV's path its lines; the ND's line the
  -- route (X-Plane's flight plan draws one line)
  if r.offset then lnavPath=B747_path_model.offset(routePath,r.offset,B747_route_model.offset_legs(r)) end
end
local function fms_text(id) return (string.gsub(fmsModules["data"][id],"%s+$","")) end
-- CRS REVERSAL AT FA FIX (step 7c; FCOM p.1435), the route shown
local crsReversal=false
function B747_fmc_route_changed()
  B747_fmc_lnav_build()
  -- the predictions for the new legs at once (step 8d: the pages read them
  -- by the legs' places)
  B747_fms_preds_now()
  crsReversal=B747_route_model.crs_reversal(B747_fmc_route,B747_route_model.shown(B747_fmc_route))
  local r=B747_fmc_route.rte
  local dep=r.origin and r.origin.ident or "****"
  if fms_text("fltdep")~=dep then
    setFMSData("fltdep",dep)
    local ta=r.origin and r.origin.ta
    setFMSData("transalt",string.format("%d",ta and ta>0 and ta or 18000))
  end
  local dst=r.dest and r.dest.ident or "****"
  if fms_text("fltdst")~=dst then setFMSData("fltdst",dst) end
  local rwy=r.runway and r.runway.ident or "-----"
  if fms_text("runway")~=rwy then setFMSData("runway",rwy) end
  -- X-Plane takes a flight plan with a destination only (without, an error
  -- message on the screen): none before the DEST
  if r.dest==nil then return end
  local fms,map=B747_route_model.to_fms(r,(B747_navdb.cycle_info(B747_fmc_navdb)),B747_path_model.shape(routePath,HOLD_SYMBOL_KT,lnav_hold_sizes()))
  local active=B747_fmc_route.active
  if fms==routeLoaded then
    -- the plan X-Plane has: its rows' legs as the route is now (sequencing
    -- keeps the plan, not the legs' numbers)
    routeMap=map
    routePending=nil
  else
    -- loaded by B747_fmc_route_sync once the route stays the same
    if fms~=routePending then routePending,routePendingT=fms,simDRTime end
    routePendingMap=map
  end
  -- the activation in flight: X-Plane's current waypoint and the AFDS's to
  -- the active one (with a new plan: once it is loaded)
  if active and not routeWasActive and simDR_onGround==0 and routePending==nil then
    routeSync=B747_route_model.active_row(r,map)
    routeSyncT,routeSyncWrites=simDRTime,0
  end
  routeWasActive=active
end

-- the EXEC keys' lights (6-1/6-2 step 5; FCOM p.1238: a modification or an
-- activation to execute; X-Plane's own for its pages still behind the
-- CDUs, HOLD and FIX): the left and centre CDUs' light (the 3D cockpit's
-- "pilot" one) with the left CDU's power, the right CDU's with its own
function B747_fmc_exec_lights()
  -- (step 9h4a) the engine-out modification too; (step 9h5a) RTA's, once
  -- complete
  local on=B747_route_model.exec_lit(B747_fmc_route) or B747_route_model.exec_lit(B747_fmc_route2) or simDR_fms_exec_light>0
    or B747_fms_eo().mod~=nil or B747_rta_model.ready(B747_fms_rta())
  local l=(on and cduPowered("fmsL")) and 1 or 0
  local r=(on and cduPowered("fmsR")) and 1 or 0
  if B747DR_fms_exec_light_pilot~=l then B747DR_fms_exec_light_pilot=l end
  if B747DR_fms_exec_light_copilot~=r then B747DR_fms_exec_light_copilot=r end
end

-- each frame (6-1/6-2 step 5e): a new plan to X-Plane once the route has
-- stayed the same a second; in flight on the active route, X-Plane's
-- current waypoint and the AFDS's to the active one once X-Plane has the
-- plan, then the route sequenced as the AFDS's current waypoint moves on
-- (its best track, until LNAV's own sequencing: step 6)
function B747_fmc_route_sync()
  -- read every frame: XTLua passes a write on only when it differs from
  -- the value it last read
  local cur=B747DR_fmscurrentIndex
  local set=B747DR_fms_currentID
  local xpcur=B747DR_xp_current
  local bridge=B747DR_xp_bridge==1
  local st=B747_fmc_route
  if routePending and simDRTime-routePendingT>=1 then
    routeLoadT,routeLoadOld=simDRTime,fmsJSON
    routeLoaded,routeMap=routePending,routePendingMap
    -- X-Plane starts a new plan at its first waypoint: in flight the
    -- active one current again (the bridge right after the load)
    local k=nil
    if st.active and simDR_onGround==0 then k=B747_route_model.active_row(st.rte,routeMap) end
    if bridge then
      B747DR_xp_plan=(k and string.format("CURRENT %d\n",k) or "")..routePending
    else
      fmsLoadDref=routePending
    end
    routePending=nil
    routeSync=k
    routeSyncT,routeSyncWrites=simDRTime,0
    return
  end
  if not (st.active and routeMap) or simDR_onGround==1 or routePending then routeSync=nil return end
  local fms=fms_route()
  -- X-Plane's plan the one loaded last
  if table.getn(fms)~=routeMap.n then return end
  if routeSync then
    local k=routeSync
    -- not before xtlua/fms shows the plan loaded last (the old one, with
    -- as many rows, could show the active waypoint current already, and a
    -- write before X-Plane takes the plan is lost to it: the activation
    -- right after a load); a second: the same as before
    if fmsJSON==routeLoadOld and simDRTime-routeLoadT<1 then return end
    if fms[k]==nil or simDRTime-routeSyncT>10 then routeSync=nil return end
    if fms[k][8]~=routeMap.ident[k] then return end
    if fms[k][10]==true and cur==k then routeSync=nil return end
    if bridge then
      -- X-Plane's thread: until X-Plane shows it
      if xpcur~=k then B747DR_xp_current=k end
    elseif routeSyncWrites<2 and simDRTime-routeSyncT>=2*routeSyncWrites then
      -- XTLua's: now, and once more after two seconds
      B747DR_fms_currentID=k
      routeSyncWrites=routeSyncWrites+1
    end
    if cur~=k then B747DR_fmscurrentIndex=k end
    return
  end
  -- X-Plane's current waypoint and the AFDS's after the FMC's active one
  -- (LNAV sequences the route itself since step 6c), looked at again
  -- every 5 s
  if simDRTime-routeSyncT<5 then return end
  routeSyncT=simDRTime
  local k=B747_route_model.active_row(st.rte,routeMap)
  if not k then return end
  local xk=nil
  for i=1,table.getn(fms) do
    if fms[i][10]==true then xk=i break end
  end
  if cur~=k or xk~=k then
    routeSync=k
    routeSyncT,routeSyncWrites=simDRTime,0
  end
end

-- each frame (6-1/6-2; notes/ATA-34-61-FMC.md §42; FCOM p.1333; FMSPG
-- p.124): with an ND in PLN, X-Plane's displayed waypoint (the ND's PLAN
-- centre, the FMS bridge's from 1) the row of the LEGS pages' centre
-- (B744.fms.pages.legs.lua) in X-Plane's flight plan: its leg's, else the
-- same waypoint's in the route X-Plane has (a modification's, the other
-- route's); none there (a modification's new waypoint, a conditional leg
-- not predicted): as it was. One row written again after a second at most
local planCtrRow,planCtrT=nil,-10
function B747_fmc_plan_ctr_sync()
  if not B747_cdu_plan_ctr_update() then return end
  if B747DR_xp_bridge~=1 or not routeMap or routePending then return end
  local st,r,i=B747_cdu_plan_ctr()
  if not st then return end
  local act=B747_fmc_route
  local k=nil
  if st==act and r==act.rte then
    k=routeMap.row[i]
  else
    local l=r.legs[i]
    for j,a in ipairs(act.rte.legs) do
      if B747_route_model.same_leg(a,l) then k=routeMap.row[j] break end
    end
  end
  -- X-Plane's plan the one loaded last
  if not k or table.getn(fms_route())~=routeMap.n then return end
  if B747DR_xp_displayed~=k and (k~=planCtrRow or simDRTime-planCtrT>=1) then
    B747DR_xp_displayed=k
    planCtrRow,planCtrT=k,simDRTime
  end
end

-- each frame (6-1/6-2 step 6c; notes/ATA-34-61-FMC.md §29): LNAV on the
-- active route (B747.68.lnav_model.lua): the route sequenced as it says,
-- X-Plane's current waypoint and the AFDS's after it; its steering for
-- the AFDS, its cross-track error, its messages (FCOM p.1431, p.1433,
-- p.1435)
local LNAV_MODE={path=1,heading=2,hold=3}
-- a hold's phase (step 7b): to its fix, the entries, the loop's parts
local HOLD_PHASE={to=1,direct=2,teardrop=3,parallel=4,intercept=5,turn1=6,outbound=7,turn2=8,inbound=9}
B747DR_fms_lnav_hold_phase=find_dataref("laminar/B747/fms/lnav/hold_phase")
local PTURN_PHASE={out=1,corner=2,leg45=2,turn=3,back=4}
B747DR_fms_lnav_pturn_phase=find_dataref("laminar/B747/fms/lnav/pturn_phase")
B747DR_fms_lnav_hold_loops=find_dataref("laminar/B747/fms/lnav/hold_loops")
B747DR_fms_lnav_hold_exit=find_dataref("laminar/B747/fms/lnav/hold_exit")
B747DR_fms_ofst_light=find_dataref("laminar/B747/fms/ofst_light")
-- the airplane's track, magnetic as the FMC's courses (the nearest VOR's
-- variation, else X-Plane's): a PPOS hold's inbound course (step 7b)
function B747_fmc_track_mag()
  local var=B747_navdb.variation(B747_fmc_navdb,simDR_latitude,simDR_longitude)
  if var==nil then var=-simDR_variation end
  return (simDR_lnav_trk-var)%360
end
local DISCONTINUITY,END_OF_OFFSET,END_OF_ROUTE,NO_ACTIVE_ROUTE=8,10,11,27
-- a message's flag, written when LNAV's condition changes
local lnavFlags={}
local function lnav_flag(i,on)
  local v=on and 1 or 0
  if lnavFlags[i]~=v then
    lnavFlags[i]=v
    B747DR_fmc_notifications[i]=v
  end
end
function B747_fmc_lnav_update()
  local st=B747_fmc_route
  local lnavState=B747DR_fms_ap_lnav_state
  local armed,engaged=lnavState==1,lnavState==2
  local s=B747_fmc_lnav
  -- a DF from where the airplane is when LNAV engages (estimate: after the
  -- takeoff the runway's threshold is behind it)
  if engaged and not lnavWasEngaged and st.active then
    local l=st.rte.legs[1]
    if l and l.pt=="DF" and not l.dto then
      l.start={lat=simDR_latitude,lon=simDR_longitude}
      B747_fmc_lnav_build()
    end
  end
  lnavWasEngaged=engaged
  if st.active and not lnavPath then B747_fmc_lnav_build() end
  -- X-Plane's variation: west positive (magnetic = true + it)
  local air={lat=simDR_latitude,lon=simDR_longitude,trk=simDR_lnav_trk,hdg=simDR_fms_true_psi,
    gs=simDR_groundspeed*1.94384,tas=simDR_lnav_tas*1.94384,wind=simDR_wind_speed,
    alt=simDR_pressureAlt1,var=-simDR_variation,ground=simDR_onGround==1}
  lnavAir=air
  local n=B747_lnav_model.update(s,st.active and lnavPath or nil,air,armed,engaged)
  if n>0 then
    -- after a leg ending at a condition the next starts where the airplane is
    local start=lnavPath[1].term~="fix" and {lat=air.lat,lon=air.lon} or nil
    lnavSequencing=true
    if B747_route_model.sequence(st,n,start) then
      B747_fmc_route_changed()
      if routeMap and not routePending then
        routeSync=B747_route_model.active_row(st.rte,routeMap)
        routeSyncT,routeSyncWrites=simDRTime,0
      end
    end
    lnavSequencing=false
  end
  local valid=s.valid and 1 or 0
  if B747DR_fms_lnav_valid~=valid then B747DR_fms_lnav_valid=valid end
  B747DR_fms_lnav_roll=s.roll
  local mode=LNAV_MODE[s.mode] or 0
  if B747DR_fms_lnav_mode~=mode then B747DR_fms_lnav_mode=mode end
  B747DR_fms_lnav_xtk=s.xtk
  B747DR_fms_lnav_dtk=s.dtk or 0
  local route=st.active and 1 or 0
  if B747DR_fms_lnav_route~=route then B747DR_fms_lnav_route=route end
  -- PROGRESS page 2's XTK ERROR (FCOM p.1377: the AFDS's best track's
  -- before)
  if st.active then B747DR_ap_lnav_xtk_error=math.abs(s.xtk) end
  -- the hold (step 7b): its phase, its loops, its exit armed
  local h=st.active and s.hp or nil
  local ph=h and HOLD_PHASE[h.phase] or 0
  if B747DR_fms_lnav_hold_phase~=ph then B747DR_fms_lnav_hold_phase=ph end
  local loops=h and h.loops or 0
  if B747DR_fms_lnav_hold_loops~=loops then B747DR_fms_lnav_hold_loops=loops end
  local ex=(h and h.exit) and 1 or 0
  if B747DR_fms_lnav_hold_exit~=ex then B747DR_fms_lnav_hold_exit=ex end
  -- the procedure turn (step 7f): its phase
  local pt=st.active and lnav_pturn() or nil
  local pp=pt and PTURN_PHASE[pt.phase] or 0
  if B747DR_fms_lnav_pturn_phase~=pp then B747DR_fms_lnav_pturn_phase=pp end
  -- the ND's racetrack anew when LNAV made the TO hold's anew
  if st.active and n==0 and lnav_hold_changed() then B747_fmc_route_changed() end
  lnav_flag(DISCONTINUITY,s.msg_disc)
  lnav_flag(END_OF_OFFSET,s.msg_eoo)
  lnav_flag(END_OF_ROUTE,s.msg_eor)
  -- the CDU's OFST light (FCOM p.1210: LNAV's offset guidance)
  local ofst=s.ofst and 1 or 0
  if B747DR_fms_ofst_light~=ofst then B747DR_fms_ofst_light=ofst end
  lnav_flag(NO_ACTIVE_ROUTE,(armed or engaged) and not st.active)
  B747_cdu_fmc_condition("NOT ON INTERCEPT HEADING",s.msg_intc,false)
  B747_cdu_fmc_condition("CRS REVERSAL AT FA FIX",crsReversal,false)
end
-- the clocks' dates: the FMC's clock calendar from the Captain's clock,
-- else the F/O's (FCOM p.1285)
B747DR_fmc_clock_capt_on=find_dataref("laminar/B747/fltInst/capt/clock_on")
B747DR_fmc_clock_capt_day=find_dataref("laminar/B747/fltInst/capt/clock_day")
B747DR_fmc_clock_capt_month=find_dataref("laminar/B747/fltInst/capt/clock_month")
B747DR_fmc_clock_capt_year=find_dataref("laminar/B747/fltInst/capt/clock_year")
B747DR_fmc_clock_fo_on=find_dataref("laminar/B747/fltInst/fo/clock_on")
B747DR_fmc_clock_fo_day=find_dataref("laminar/B747/fltInst/fo/clock_day")
B747DR_fmc_clock_fo_month=find_dataref("laminar/B747/fltInst/fo/clock_month")
B747DR_fmc_clock_fo_year=find_dataref("laminar/B747/fltInst/fo/clock_year")
local function clock_date()
  if B747DR_fmc_clock_capt_on>0 and B747DR_fmc_clock_capt_month>=1 then
    return 2000+B747DR_fmc_clock_capt_year,B747DR_fmc_clock_capt_month,B747DR_fmc_clock_capt_day
  end
  if B747DR_fmc_clock_fo_on>0 and B747DR_fmc_clock_fo_month>=1 then
    return 2000+B747DR_fmc_clock_fo_year,B747DR_fmc_clock_fo_month,B747DR_fmc_clock_fo_day
  end
end
-- NAV DATA OUT OF DATE (an alert, FCOM p.1433): the clock's date past the
-- database's cycle; REF AIRPORT and GATE blank at lift-off (FCOM p.1285-
-- 1286)
local NAV_DATA_OUT_OF_DATE=55
function update_navdb()
  local db=B747_fmc_navdb
  local out=0
  local y,m,d=clock_date()
  if db.ready and y and B747_navdb.out_of_date(db,y,m,d) then out=1 end
  if B747DR_fmc_notifications[NAV_DATA_OUT_OF_DATE]~=out then B747DR_fmc_notifications[NAV_DATA_OUT_OF_DATE]=out end
  if simDR_onGround==0 and fmsModules["data"]["airportpos"]~="----" then
    setFMSData("airportpos","----")
    setFMSData("airportgate","----")
    setFMSData("irsLat",defaultFMSData().irsLat)
    setFMSData("irsLon",defaultFMSData().irsLon)
  end
end
dofile("B744.notifications.lua")
dofile("irs/irs_system.lua")
dofile("B744.fms.baro.lua")
dofile("B744.fms.pages.lua")

dofile("irs/rnav_system.lua")
dofile("B744.createfms.lua")

fmsC = {}
setmetatable(fmsC, {__index = fms})
fmsC.id="fmsC"
setDREFs(fmsC,"cdu1","fms1","sim/FMS/","fms3")
fmsC.inCustomFMC=true
fmsC.targetCustomFMC=true
fmsC.currentPage="INDEX"
fmsC.targetPage="INDEX"

fmsL = {}
setmetatable(fmsL, {__index = fms})
fmsL.id="fmsL"
setDREFs(fmsL,"cdu1","fms3","sim/FMS/","fms1")
fmsL.inCustomFMC=true
fmsL.targetCustomFMC=true
fmsL.currentPage="INDEX"
fmsL.targetPage="INDEX"

fmsR = {}
setmetatable(fmsR, {__index = fms})
fmsR.id="fmsR"
setDREFs(fmsR,"cdu1","fms2","sim/FMS/","fms2")
fmsR.inCustomFMC=true
fmsR.targetCustomFMC=true
fmsR.currentPage="INDEX"
fmsR.targetPage="INDEX"

fmsModules.fmsL=fmsL;
fmsModules.fmsC=fmsC;
fmsModules.fmsR=fmsR;


B747DR_CAS_memo_status          = find_dataref("laminar/B747/CAS/memo_status")

--Marauder28
function getCurrentWayPoint(fms,usenext)
	--print("FMS j="..fmsJSON)
	for i=1,table.getn(fms),1 do
     --print("FMS j="..fmsJSON)

		if fms[i][10] == true then
				--print("Found TRUE = "..fms[i][1].." "..fms[i][2].." "..fms[i][8])
				if usenext==false then
				if fms[i][8] == "latlon" then
					return simDR_navID, fms[i][5], fms[i][6]
				else
					return fms[i][8], fms[i][5], fms[i][6]
				end
				elseif i+1<table.getn(fms) then
				  if fms[i+1][8] == "latlon" then
					return "-----", fms[i+1][5], fms[i+1][6]
				else
					return fms[i+1][8], fms[i+1][5], fms[i+1][6]
				end
				end
		end		
	end
	return ""  --NOT FOUND
end
function get_ETA_for_Distance(distance,additionalTime)
	local meters_per_second_to_kts = 1.94384449
	local hours = 0
	local mins = 0
	local secs = 0
	local time_to_waypoint = 0
	local default_speed = 275 -- kt (FMC-21; the predictions come in step 8)
	local actual_speed = simDR_groundspeed * meters_per_second_to_kts
	time_to_waypoint = additionalTime + (distance / math.max(default_speed, actual_speed)) * 3600
	
	hours = math.floor((time_to_waypoint % 86400) / 3600)
	mins = math.floor((time_to_waypoint % 3600) / 60)
	secs = (time_to_waypoint % 60) / 60
	--Add to current Zulu time
	hours = hours + hh
	mins = mins + mm

	secs = secs + (ss / 60)

	if secs >= 1 then
		secs = secs - 1
		mins = mins + 1
	end

	if mins >= 60 then
		mins = mins - 60
		hours = hours + 1
	end
	
	if hours >= 24 then
		hours = hours - 24
	end

	return time_to_waypoint,hours,mins,secs
end
function get_waypoint_estimate(latitude,longitude,fms_waypoint, fms_latitude, fms_longitude,additionalTime)
  
  local hours = 0
  local mins = 0
  local secs = 0
  
  local time_to_waypoint = 0
  local fms_distance_to_waypoint = 0
  if fms_waypoint ~= "" and fms_waypoint ~= "VECTOR" and not string.match(fms_waypoint, "%(") then
	--print("Checking distance for waypoint = "..fms_current_waypoint)
	fms_distance_to_waypoint = getDistance(latitude, longitude, fms_latitude, fms_longitude)
	time_to_waypoint,hours,mins,secs = get_ETA_for_Distance(fms_distance_to_waypoint,additionalTime)
	
  end
  
  return fms_distance_to_waypoint,time_to_waypoint,hours,mins,secs
end


-- each route entry's ETA for the ND's route data (5-2 step 5c: the DATA
-- switch shows the FMC's ETA at each waypoint, FCOM p.1040, p.1148): from
-- the active waypoint on, the distance along the route by
-- get_ETA_for_Distance, as the active and next waypoints' ETAs (the FMC's
-- predictions come with its rebuild: FMC-20, FMC-21); the zulu time of day
-- in minutes for each entry of xtlua/fms, -1 before the active waypoint, on
-- the ground and for an entry without a position; a JSON array
-- (laminar/B747/fms/route_eta) written when it changes, once a second
B747DR_fms_route_eta = find_dataref("laminar/B747/fms/route_eta")
local route_eta_t = -1
function B747_route_eta(fms, airborne)
	if simDRTime - route_eta_t < 1 and simDRTime >= route_eta_t then return end
	route_eta_t = simDRTime
	local out = {}
	local active = nil
	for i = 1, table.getn(fms) do
		if active == nil and fms[i][10] == true then active = i end
	end
	local dist, lat, lon = 0, simDR_latitude, simDR_longitude
	for i = 1, table.getn(fms) do
		local v = -1
		local wlat, wlon = fms[i][5], fms[i][6]
		if airborne and active ~= nil and i >= active and not (wlat == 0 and wlon == 0) then
			dist = dist + getDistance(lat, lon, wlat, wlon)
			lat, lon = wlat, wlon
			local _, h, m = get_ETA_for_Distance(dist, 0)
			v = h * 60 + m
		end
		out[i] = v
	end
	local s = "[" .. table.concat(out, ",") .. "]"
	if B747DR_fms_route_eta ~= s then B747DR_fms_route_eta = s end
end

function waypoint_eta_display()
	local hours = 0
	local mins = 0
	local secs = 0
	local nhours = 0
	local nmins = 0
	local nsecs = 0
	local fms = {}
	local fms_current_waypoint = ""
	local fms_next_waypoint = ""
	local fms_latitude = ""
	local fms_longitude = ""
	local fms_next_latitude = ""
	local fms_next_longitude = ""
	local time_to_waypoint = 0
	local fms_distance_to_waypoint = 0
	local fms_distance_to_next_waypoint = 0
	if string.len(fmsJSON) > 2 then
		fms = fms_route()
		if fms[table.getn(fms)][8]~="LATLON" then
        	B747DR_destination = string.format("%4s",fms[table.getn(fms)][8])
		else
			B747DR_destination="----"
		end
		if simDR_onGround ~= 1 then
		--print(fmsJSON)
			
		fms_current_waypoint, fms_latitude, fms_longitude = getCurrentWayPoint(fms,false)
		--print(string.match(fms_current_waypoint, "%("))
		fms_distance_to_waypoint,time_to_waypoint,hours,mins,secs = get_waypoint_estimate(simDR_latitude, simDR_longitude,fms_current_waypoint, fms_latitude, fms_longitude,0)
		
		fms_next_waypoint, fms_next_latitude, fms_next_longitude = getCurrentWayPoint(fms,true)
		--print(string.match(fms_current_waypoint, "%("))
		fms_distance_to_next_waypoint,time_to_waypoint,nhours,nmins,nsecs = get_waypoint_estimate(fms_latitude, fms_longitude,fms_next_waypoint, fms_next_latitude, fms_next_longitude,time_to_waypoint)
		end
		B747_route_eta(fms, simDR_onGround ~= 1)
	else
		B747DR_destination="----"	
		if B747DR_fms_route_eta ~= "[]" then B747DR_fms_route_eta = "[]" end
	end
	
	-- the active waypoint (FCOM p.1147), a conditional one by its name too
	-- ((INTC), (600): its end as the FMC predicts it, 6-1/6-2 step 6d;
	-- before, dashes); vectors without a distance (no end: FCOM p.1237)
	if fms_current_waypoint == "" then
		B747DR_ND_current_waypoint = "-----"
		B747DR_ND_waypoint_distance = "------NM"
		B747DR_ND_waypoint_eta = "------Z"

	elseif fms_current_waypoint == "VECTOR" or fms_current_waypoint == "VECTORS" then
		B747DR_ND_current_waypoint = fms_current_waypoint
		B747DR_ND_waypoint_distance = "------NM"
		B747DR_ND_waypoint_eta = "------Z"
	else
	    if B747DR_ND_current_waypoint ~= fms_current_waypoint then
		  B747DR_waypoint_ata = B747DR_ND_waypoint_eta
		  B747DR_last_waypoint = B747DR_ND_current_waypoint
		  B747DR_last_waypoint_fuel=simDR_fueL_tank_weight_total_kg
		end
		B747DR_ND_current_waypoint = fms_current_waypoint
		B747DR_ND_waypoint_distance = string.format("%5.1f".."nm", fms_distance_to_waypoint)
		B747DR_ND_waypoint_eta = string.format("%02d%02d.%d".."z", hours, mins, secs * 10)			
	end
	if B747DR_last_waypoint=="" then
	  B747DR_last_waypoint="-----"
	  B747DR_waypoint_ata="------Z"
	end
	if fms_next_waypoint == "" or string.match(fms_next_waypoint, "%(") then
		B747DR_next_waypoint = "-----"
		B747DR_next_waypoint_eta = "------Z"
		B747DR_next_waypoint_dist=0	
	elseif fms_next_waypoint == "VECTOR" then
		B747DR_next_waypoint = fms_next_waypoint
		B747DR_next_waypoint_dist=fms_distance_to_next_waypoint
		B747DR_next_waypoint_eta = "------Z"
	else
		B747DR_next_waypoint = fms_next_waypoint
		B747DR_next_waypoint_dist=fms_distance_to_next_waypoint
		B747DR_next_waypoint_eta = string.format("%02d%02d.%d".."z", nhours, nmins, nsecs * 10)			
	end
end

function nd_range_display ()
	local range = {5, 10, 20, 40, 80, 160, 320}
			
	B747DR_ND_range_display_capt	= range[simDR_range_dial_capt + 1]
	B747DR_ND_range_display_fo		= range[simDR_range_dial_fo + 1]
end



function nd_speed_wind_display()
	local meters_per_second_to_kts = 1.94384449  --Convert meters per second to KTS
	local a0 = 661.47  --Speed of sound at sea level
	local K0 = 273.15  --Kelvin temperature at sea level
	local M_pilot = simDR_mach_pilot  --Current Mach number
	local M_copilot = simDR_mach_copilot  --Current Mach number
	local T0 = 288.15  --Standard air temperature at sea level in Kelvin
	local Tt = K0 + simDR_total_air_temp  --Total air temperature in Kelvin
	local T_pilot = Tt / (1 + (0.2 * math.pow(M_pilot, 2)))  --Static air temperature in Kelvin	
	local T_copilot = Tt / (1 + (0.2 * math.pow(M_copilot, 2)))  --Static air temperature in Kelvin	
	
	local TAS_pilot = round(a0 * M_pilot * math.sqrt(T_pilot/T0))
	B747DR_TAS_pilot=TAS_pilot
	local TAS_copilot = round(a0 * M_copilot * math.sqrt(T_copilot/T0))
	
	local groundspeed = simDR_groundspeed * meters_per_second_to_kts
	-- the wind's direction in the heading reference (5-2 step 5d: FCOM
	-- p.1142), true with TRU
	local wind_dir = simDR_wind_degrees
	if B747DR_fms_hdg_ref_true > 0.5 then
		wind_dir = (wind_dir - ((simDR_fms_mag_psi - simDR_fms_true_psi + 180) % 360 - 180)) % 360
	end
	local wind_hdg = round(wind_dir)
	local wind_hdg_deviation = 360 - wind_hdg + simDR_aircraft_hdg
	local wind_bearing = 360 - wind_hdg_deviation
	local wind_spd = tostring(round(simDR_wind_speed))
	local wind_line_tmp = string.format("%03.0f`/%s", wind_hdg, wind_spd)
	
	if simDR_ias_pilot < 100 then
		B747DR_ND_GS_TAS_Line = "GS"
		B747DR_ND_GS_TAS_Line_Pilot = string.format("%d", groundspeed)
		B747DR_ND_GS_TAS_Line_CoPilot = string.format("%d", groundspeed)
		B747DR_ND_Wind_Line = ""
	else
		-- the groundspeed only: the 109 has no TAS on the ND (FCOM p.1141:
		-- 405, 570; 5-2 step 5c)
		B747DR_ND_GS_TAS_Line = "GS"
		B747DR_ND_GS_TAS_Line_Pilot = string.format("%3.0f", groundspeed)
		B747DR_ND_GS_TAS_Line_CoPilot = string.format("%3.0f", groundspeed)
		B747DR_ND_Wind_Line = wind_line_tmp:gsub("°", "`")
		if wind_bearing < 0 then
			B747DR_ND_Wind_Bearing = wind_bearing + 180
		else
			B747DR_ND_Wind_Bearing = wind_bearing - 180
		end
	end
end

function aircraft_last_pos(phase)
	file_location = simDR_livery_path.."B747-400_lastpos.dat"
	--print("File = "..file_location)

	if phase == "LOAD" then
		--Load FMC last position
		local file = io.open(file_location, "r")
		if file ~= nil then
			io.input(file)
			fmsModules["data"].lastpos = io.read()
			io.close(file)
		end
	else  --UNLOAD
		local file = io.open(file_location, "w+")
		if file ~= nil then
			io.output(file)
			io.write(irsSystem.getLat("gpsL") .." " .. irsSystem.getLon("gpsL"))
			io.close(file)
		end
	end
end
local systemsWarmedUp=false
--Marauder28
function alignIRSs()
	irsSystem["setPos"]=true
	irsSystem.align("irsL",true)
	irsSystem.align("irsC",true)
	irsSystem.align("irsR",true)
	systemsWarmedUp=true
end

function disalignIRSs()
	irsSystem["irsL"]["aligned"]=false
    irsSystem["irsC"]["aligned"]=false
    irsSystem["irsR"]["aligned"]=false
	systemsWarmedUp=true
end

local flightInit=false
local didFlightInit=false
-- a new flight: the in-flight start again (an air start re-done after the
-- aircraft's reload: the AFDS's flight_start resets its engage state)
function flight_start()
    flightInit=false
    didFlightInit=false
end
function do_flight_start()
	B747DR_last_waypoint_fuel=simDR_fueL_tank_weight_total_kg
	systemsWarmedUp=false
	local difLat=simDR_latitude
  	local difLon=simDR_longitude
  if simDR_startup_running == 0 then
		irsSystem.update()
    	run_after_time(disalignIRSs,1)
    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then
		irsSystem.update()
      	
      
    end

	simDR_cg_adjust = 0  --reset CG slider to begin current flight
	
	--Ensure that CG location gets updated periodically so that the CG slider repositions automatically as fuel is burned during flight
	run_at_interval(inflight_update_CG, 60)	
end

debug_fms     = find_dataref("laminar/B747/debug/fms")
fms_style = find_dataref("sim/cockpit2/radios/indicators/fms_cdu1_style_line2")
-- the FMC's messages each frame from laminar/B747/fms/notification's flags
-- into the CDUs' message list (B744.createfms.lua); >FMC MESSAGE while an
-- alert waits (FCOM p.1429-1430; 6-1/6-2 step 2: before, one flag every
-- ten seconds, any message, and CLR cleared the flag)
function setNotifications()
  B747_cdu_sync_fmc_messages(B747DR_fmc_notifications)
  B747DR_CAS_advisory_status[145] = B747_cdu_fmc_alert() and 1 or 0
end
B747DR_ap_target_speed               	= find_dataref("laminar/B747/autopilot/speed/target")
B747DR_ap_target_heading_deg               	= find_dataref("laminar/B747/autopilot/heading/target")
B747CMD_flight_dir_switch_L = find_command("laminar/B747/toggle_switch/flight_dir_L")
B747CMD_autothrottle_arm 		= find_command("laminar/B747/authrottle_arm")
B747DR_fms_toggle_sw		= find_dataref("laminar/B747/toggle_switch/position")
B747CMD_ap_switch_alt_hold_mode			= find_command("laminar/B747/autopilot/button_switch/alt_hold_mode")
B747CMD_ap_switch_cmd_L					= find_command("laminar/B747/autopilot/button_switch/cmd_L")
B747DR_ap_target_altitude               	= find_dataref("laminar/B747/autopilot/altitude/target")
B747DR_fms_ap_cmd_L					= find_dataref("laminar/B747/autopilot/cmd_L_mode/status")
-- CMD L again until it engages, INFLIGHT_AP_TRIES times INFLIGHT_AP_S apart:
-- the engage interlocks (6-3 step 5a) wait for the IRUs and the ADCs, whose
-- modules start 3 s after the load (their first reads are 0), about when
-- this runs; for 30 s (2026-10-31: 5 s before, and s139's air start on a
-- reloaded airplane once went on without the A/P)
local INFLIGHT_AP_TRIES, INFLIGHT_AP_S = 60, 0.5

local inflightAP_tries = 0
function retry_inflightAP_cmd()
	if B747DR_fms_ap_cmd_L > 0.5 or inflightAP_tries >= INFLIGHT_AP_TRIES then return end
	inflightAP_tries = inflightAP_tries + 1
	B747CMD_ap_switch_cmd_L:once()
	run_after_time(retry_inflightAP_cmd, INFLIGHT_AP_S)
end
function fin_activate_inflightAP()
	-- ALT HOLD after the F/D's default V/S and HDG HOLD (the AFDS model,
	-- 6-3 step 1a), then the A/P in the F/D's modes
	B747CMD_ap_switch_alt_hold_mode:once()
	B747CMD_ap_switch_cmd_L:once()
	inflightAP_tries = 0
	run_after_time(retry_inflightAP_cmd, INFLIGHT_AP_S)
	B747DR_ap_target_altitude=math.floor(simDR_pressureAlt1/100)*100
	
	B747DR_CAS_advisory_status[233] = 0
	B747DR_pfd_mode_capt		 = 1
	B747DR_pfd_mode_fo		 = 1
end
function activate_inflightAP()
	-- idempotent (it may run twice around an air start re-done): F/D L ON
	-- only when OFF (its switch toggles), the A/T by its arm command
	if B747DR_fms_toggle_sw[23] < 0.5 then B747CMD_flight_dir_switch_L:once() end
	B747CMD_autothrottle_arm:once()
	B747DR_ap_target_speed=math.floor(math.min(simDR_ias_pilot,B747DR_airspeed_Vmc+10))
	B747DR_ap_target_heading_deg=math.floor(simDR_aircraft_hdg)
	local ref1=B747DR_CAS_advisory_status[233]
	local ref2=B747DR_pfd_mode_capt
	local ref2=B747DR_pfd_mode_fo
	irsSystem["motion"]["irsL"]=false
	irsSystem["motion"]["irsC"]=false
	irsSystem["motion"]["irsR"]=false
	irsSystem.align("irsL",true)
	irsSystem.align("irsC",true)
	irsSystem.align("irsR",true)
	B747DR_ap_ATT=0
	run_after_time(fin_activate_inflightAP,1)
end

function throttleDataRefresh()
	-- make sure all the throttle data is synchronized
	local ref1=B747DR_throttle[0]
	local ref2=B747DR_throttle[1]
	local ref3=B747DR_throttle[2]
	local ref4=B747DR_throttle[3]
	local ref5=B747DR_throttle_reversor[0]
	local ref6=B747DR_throttle_reversor[1]
	local ref7=B747DR_throttle_reversor[2]
	local ref8=B747DR_throttle_reversor[3]
	local ref9=simDR_throttle_ratio_all
	local ref10=simDR_throttle_ratio[0]
	local ref11=simDR_throttle_ratio[1]
	local ref12=simDR_throttle_ratio[2]
	local ref13=simDR_throttle_ratio[3]
	local ref14=B747DR_throttle_resolver_angle[0]
	local ref15=B747DR_throttle_resolver_angle[1]
	local ref16=B747DR_throttle_resolver_angle[2]
	local ref17=B747DR_throttle_resolver_angle[3]
	local ref18=simDR_engn_thro[0]
	local ref19=simDR_engn_thro[1]
	local ref20=simDR_engn_thro[2]
	local ref21=simDR_engn_thro[3]
	local ref22=simDR_engn_thro_use[0]
	local ref23=simDR_engn_thro_use[1]
	local ref24=simDR_engn_thro_use[2]
	local ref25=simDR_engn_thro_use[3]
	local ref26=simDR_throttle_max      
end

function after_physics()
  if debug_fms>0 then return end
  if not B747_fmc_navdb.ready then B747_navdb.load(B747_fmc_navdb,32768) end
	
  if hasSimConfig()==false then return end
  if flightInit==false then
	do_flight_start()
	end
	flightInit=true
  if systemsWarmedUp==false and simDR_startup_running == 1 and is_timer_scheduled(alignIRSs) == false then 
	run_after_time(alignIRSs,1)
	return
  end
  if systemsWarmedUp==false then return end
  local refreshmins=B747DR_airspeed_Vmc
  if didFlightInit==false and simDR_startup_running == 1 and simDR_onGround==0 then
	print("activate AP stuff")
	
	run_after_time(activate_inflightAP,1)
  end
  --print("FMS j="..fmsJSON)
  didFlightInit=true;
--     for i =1,24,1 do
--       print(string.byte(fms_style,i))
--     end
	--refresh time
	local cM=hh
	cM=mm
	cM=ss
    setNotifications()
    update_spd_trans()
    update_perf()
    update_econ()
    update_preds()
    update_vnav()
    update_thrlim()
    update_navdb()
    update_takeoff()
    B747_fmc_lnav_update()
    B747_fmc_route_sync()
    B747_fmc_plan_ctr_sync()
    B747_fmc_exec_lights()
    B747DR_FMSdata=json.encode(fmsModules["data"]["values"])--make the fms data available to other modules
    --print(B747DR_FMSdata)
    fmsL:B747_fms_display()
    fmsC:B747_fms_display()
    fmsR:B747_fms_display()
    if simDR_bus_volts[0]>22 then
      irsSystem.update()
      B747_setNAVRAD()
    end
    if acarsSystem.provider.online() then
      B747DR_CAS_memo_status[40]=0 --for CAS
      acars=1 --for radio
      acarsSystem.provider.receive()
	  acarsSystem.provider.send()
	  acarsSystem.remote.receive()
	  --acarsSystem.remote.send()
      local hasNew=0
      for i = table.getn(acarsSystem.messages.values), 1, -1 do
		--local msgRead="true"
		if not acarsSystem.messages[i]["read"] then 
			hasNew=1
			--msgRead="false"
		end 
		--print("acars msg "..i.." "..msgRead)
      end 
      B747DR_CAS_memo_status[0]=hasNew --ACARS MESSAGE
    else
      
      if B747DR_rtp_C_off==0 then
		B747DR_CAS_memo_status[40]=1 --for CAS
      else
		B747DR_CAS_memo_status[40]=0
      end
      acars=0 --for radio
    end

	--Display Waypoint ETA on ND
	waypoint_eta_display()

	--Display range NM on ND
	nd_range_display ()
	
	--Display speed and wind info on ND
	nd_speed_wind_display()

	--Ensure simConfig data is fresh
	--update FMS with any cruise altitude changes
	monitorCRZALT()
		
	--Ensure DR's are updated in time for use in calc_CGMAC()
	local payload_weight = B747DR_payload_weight
	local fuel_qty = simDR_fuel_qty
	local simconfig = B747DR_simconfig_data
	throttleDataRefresh()
end

function aircraft_load()
	simDR_cg_adjust = 0 --reset CG slider to begin current flight
end

function aircraft_unload()
	aircraft_last_pos("UNLOAD")
	simDR_cg_adjust = 0 --reset CG slider to neutral for future flights
end
