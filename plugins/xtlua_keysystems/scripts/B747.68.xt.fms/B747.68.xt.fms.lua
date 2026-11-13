--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks CC-BY-NC4
*****************************************************************************************
]]
fmsLoadDref=find_dataref("xtlua/loadtoFMS")
simDR_inReplay              = find_dataref("sim/time/is_in_replay")
B747DR_fdr_log_json     = find_dataref("laminar/B747/fdr/json")
simDRTime=find_dataref("sim/time/total_running_time_sec")
-- (1-2) the FMC's air/ground: the PSEU's primary ground (the FMCs' relays
-- in the table of ATA29_32 p.299, p.303 are of both systems: the primary,
-- estimate; notes/ATA-32.md §16). Before, X-Plane's onground_any (any
-- wheel). X-Plane's own for the sim's set-up of an in-flight start
simDR_onGround=find_dataref("laminar/B747/gear/air_ground/pri_gnd")
simDR_xp_onGround=find_dataref("sim/flightmodel/failures/onground_any")
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
B747DR_elec_ext_pwr_requested       = find_dataref("laminar/B747/electrical/ext_pwr_requested")  -- (2026-11-04)
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

-- the config taken (set), and (2026-11-11) the seconds this module waited
-- for its first config without the pulse and how long it waits before it
-- takes the one published (late_s, estimate: the pulse comes within about
-- 5 s of the plugins' start). One local: this chunk is at Lua's 200
local simConfigGot = {set = false, wait = 0, late_s = 10}
function hasSimConfig()
	if B747DR_newsimconfig_data==1 then
		if string.len(B747DR_simconfig_data) > 1 then
			simConfigData["data"] = json.decode(B747DR_simconfig_data)
			simConfigGot.set=true
		else
			return false
		end
	elseif not simConfigGot.set then
		-- (2026-11-11) the simconfig module (plugin xtlua) holds newsimconfig
		-- at 1 for about 4 s when it publishes the livery's config; started
		-- after that (the user's cold start of the release), this module never
		-- saw it and returned in after_physics for good: the CDUs blank, the
		-- weight and balance window's inputs dead. Without a config after
		-- late_s, the one published once it decodes to a config
		-- (tests/fms/simconfig_late_start_test.lua). Not at once: a usual
		-- start still takes it with the pulse, at the moment it always did
		-- (right after an aircraft's reload the previous flight's config can
		-- still be published)
		simConfigGot.wait = simConfigGot.wait + (SIM_PERIOD or 0)
		local s = simConfigGot.wait >= simConfigGot.late_s and B747DR_simconfig_data or ""
		if string.len(s) > 1 then
			local d = json.decode(s)
			if type(d) == "table" and d.PLANE ~= nil then
				simConfigData["data"] = d
				simConfigGot.set=true
			end
		end
	end
	return simConfigGot.set
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
	-- (2026-11-05 review) numbers only: a weight not entered yet ("***.*")
	-- leaves the trim as it is (arithmetic on text stopped the whole plugin)
	GW, CG_MAC = tonumber(GW), tonumber(CG_MAC)
	if GW == nil or CG_MAC == nil then return end

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
  wxapt="****",   -- (2026-11-05 review 4) the ACARS WEATHER page's airport
  grwt="***.*   ",
  crzalt=string.rep("*", 5),
  acarsMessage="",
  clbspd="340",
  transpd="250",
  spdtransalt="10000",
  transalt="18000",
  -- (2026-11-13; the 2026-11-12 review DSP-2) DESCENT FORECAST's TRANS LVL
  -- for the PFD's barometric box and the ND's DATA (B747_fms_publish_trans_lvl)
  translvl="18000",
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

-- (2026-11-05 review) a field of the FMS data by its name, nil when there
-- is none: fmsModules["data"] is an XTLua namespace, and reading a name it
-- lacks overflowed the stack (the whole plugin stopped)
local function fms_field(id)
	local t=fmsModules["data"]
	local vals=rawget(t,"values")
	if vals~=nil then return vals[id] end
	return rawget(t,id)
end

fmsModules["setData"]=function(self,id,value)
    -- (2026-11-05 review) a name the data lacks, or no value: refused
    -- (before, a Lua error that stopped the plugin; no caller does it now)
    if value==nil or fms_field(id)==nil then
      print("setData: refused " .. tostring(id))
      return
    end
    --always retain the same length
    if value=="" and id~="acarsMessage" then
      local initData=defaultFMSData()
      if initData[id]~=nil then
		print("default for " .. id .. " is " .. initData[id])
		value=initData[id]
      else
		-- (2026-11-05 review) a field without a default is emptied, not
		-- removed (before, nil: reading it again stopped the plugin)
		print("default for " .. id .. " is nil")
		self["data"][id]=""
		return
      end
    end
    len=string.len(self["data"][id])
    if len < string.len(value) and id~="acarsMessage" then
      -- (2026-11-05 review) a value longer than its field is cut to the
      -- field (before, to 3 characters whatever the field); a field
      -- shorter than 3 still takes 3 and grows, as the ACARS pages' 2-wide
      -- speeds rely on
      value=string.sub(value,1,math.max(len,3))
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
	-- (2026-11-05 review) the old prints read the field before setData's
	-- check (a name the data lacks stopped the plugin) and reach no log in
	-- XTLua: removed
   fmsModules:setData(id,value)
end
-- the climb's SPD TRANS speed: the greater of the transition speed and VREF
-- 30 + 100 kt (FCOM p.1328: "272/10000"; VREF 30: estimate); dashes once
-- deleted (FMC-09, 6-1 step 1). The transition speed 250 kt for every
-- origin: X-Plane's nav data (CIFP, apt.dat) has no airport speed limits,
-- where the real nav DB's come from (2026-11-05 review 4: kept, no source)
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
  -- (step 12c1) a CDU left the page (B744.createfms.lua; a missing key
  -- of XTLua's namespace table cannot be read)
  retVal.onLeave=function(self,fmsID) end
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
-- (§131) SimBrief's latest OFP by the Pilot ID: the FMS bridge's
B747DR_simbrief_id=find_dataref("laminar/B747/options/simbrief_id")
B747DR_simbrief_fetch=find_dataref("laminar/B747/fms/company/simbrief_fetch")
B747DR_simbrief_done=find_dataref("laminar/B747/fms/company/simbrief_done")
B747DR_simbrief_status=find_dataref("laminar/B747/fms/company/simbrief_status")
B747DR_fms_exec_light_pilot=find_dataref("laminar/B747/fms/exec_light_pilot")
B747DR_fms_exec_light_copilot=find_dataref("laminar/B747/fms/exec_light_copilot")
simDR_fms_exec_light=find_dataref("sim/cockpit2/radios/indicators/fms_exec_light_pilot")
-- LNAV (6-1/6-2 step 6c; notes/ATA-34-61-FMC.md §29): the active route's
-- path (B747.68.path_model.lua) built anew when the route changes or
-- sequences; LNAV (B747.68.lnav_model.lua) each frame, its steering to
-- the AFDS
dofile("B747.68.path_model.lua")
dofile("B747.68.lnav_model.lua")
dofile("B747.68.nd_line_model.lua")
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
-- (6-1/6-2 step 12c1; notes/ATA-34-61-FMC.md §109) PERF FACTORS
-- (B747.68.perf_factors_model.lua; the maintenance page in
-- B744.fms.pages.maintperffactor.lua), kept in the livery's simconfig
-- (FMC.PERF, saved with SIM CONFIG's save: the FMC keeps the last
-- entries). DRAG/F-F the IDENT page's and the performance data's fuel
-- flows (B747_perf_db.DRAG_F, FF_F); TO 1/TO 2 THRUST LIM's derates
-- (B747_fms_thrlim_pct); MNVR MARGIN the maximum altitude's buffet margin
-- (B747_perf_db.MARGIN_G) and the PFDs' maneuvering speeds' (laminar/
-- B747/fms/mnvr_margin: FCOM p.969, p.973); THR/CRZ the thrust limit at
-- the T/C (FCOM p.1273); THR RED and ACCEL HT TAKEOFF REF's defaults,
-- taken at the flight's start and at its completion (ATA34_2 p.678: at
-- the end of each flight or after a long term power interrupt). MIN CRZ
-- TIME, R/C CLB and R/C CRZ are kept and shown only: the FCOM's tables
-- give the maximum altitude at 100 fpm (PI.11.1), no short trip's optimum
-- altitude
dofile("B747.68.perf_factors_model.lua")
B747DR_fms_mnvr_margin = find_dataref("laminar/B747/fms/mnvr_margin")
do
  local PF = B747_perf_factors_model
  local cfgText, cfgPerf = nil, nil
  local values, valuesType, applied = nil, nil, nil
  local toDefaults = nil
  -- the simconfig's FMC.PERF, decoded again when the simconfig changes (a
  -- plain table: simConfigData is XTLua's namespace)
  local function stored()
    local s = B747DR_simconfig_data
    if s ~= cfgText then
      cfgText, cfgPerf, values = s, nil, nil
      local ok, t = pcall(json.decode, s)
      if ok and type(t) == "table" and type(t.FMC) == "table" and type(t.FMC.PERF) == "table" then
        cfgPerf = t.FMC.PERF
      end
    end
    return cfgPerf
  end
  -- the values (B747_perf_factors_model.values)
  function B747_fms_perf_factors()
    local st = stored()
    local et = B747DR_fms_engine_type
    if values == nil or valuesType ~= et then values, valuesType = PF.values(st, et), et end
    return values
  end
  -- an entry into a field (B747_perf_factors_model.enter): nil, or the
  -- CDU's message
  function B747_fms_perf_factors_enter(field, text)
    local new, err = PF.enter(field, text)
    if not new then return err end
    local fmc = simConfigData["data"].FMC
    if type(fmc.PERF) ~= "table" then fmc.PERF = {} end
    for k, x in pairs(new) do fmc.PERF[k] = x end
    if (new.drag or new.ff) and type(fmc.INIT) == "table" then
      fmc.INIT.drag_ff = PF.text(PF.values(fmc.PERF, B747DR_fms_engine_type)).dragff
    end
    pushSimConfig(simConfigData["data"]["values"])
    return nil
  end
  -- each frame: the performance data's factors and the PFDs' margin
  function B747_fms_perf_factors_update()
    local v = B747_fms_perf_factors()
    if v == applied then return end
    applied = v
    B747_perf_db.DRAG_F, B747_perf_db.FF_F = 1 + v.drag / 100, 1 + v.ff / 100
    B747_perf_db.MARGIN_G = v.mnvr
    B747DR_fms_mnvr_margin = v.mnvr
  end
  -- TAKEOFF REF's defaults (THR REDUCTION, ACCEL HT, E/O ACCEL HT: the
  -- FMC's data), taken at the flight's start and its completion; with
  -- apply into those the crew has not entered
  local TO_SET = {thrred = "thrredset", accelht = "accelset", eoaccelht = "eoaccelset"}
  function B747_fms_perf_to_take(apply)
    local v = B747_fms_perf_factors()
    toDefaults = {thrred = string.format("%d", v.thr_red), accelht = string.format("%d", v.accel),
      eoaccelht = string.format("%d", v.eo_accel)}
    if not apply then return end
    for k, set in pairs(TO_SET) do
      if str_trim(fmsModules["data"][set]) == "" and str_trim(fmsModules["data"][k]) ~= toDefaults[k] then
        setFMSData(k, toDefaults[k])
      end
    end
  end
  function B747_fms_perf_to()
    if toDefaults == nil then B747_fms_perf_to_take(false) end
    return toDefaults
  end
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
-- (step 9h5b) the active RTA's cruise Mach (RTA SPD), or nil
function B747_fms_rta_mach()
  if rtaState.active and rtaState.mach and B747_fms_rta_avail() then return rtaState.mach end
  return nil
end
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
-- (FIX INFO, 2026-11-04) the predictions' profile along the route
-- (B747_pred_model.profile) and the legs it was made on
local predProfile, predLegs, predInput = nil, nil, nil
function B747_fms_preds() return predResult end
-- (OFFPATH DES, 2026-11-04) the last predictions' input (B747_fms_pred_input:
-- the performance database, the DES page's speeds, the weight), nil without
-- predictions
function B747_fms_pred_input_last() return predInput end
function B747_fms_preds_now() predNext = 0 end
-- the predicted altitude (ft) and time (s from now) x NM along the route,
-- nil without predictions or past their end
function B747_fms_pred_at(x)
  if not predProfile then return nil end
  return B747_pred_model.profile_at(predProfile, x)
end
-- where (NM along the route) the predictions reach an altitude, or a time
-- (s from now), nil if they do not
function B747_fms_pred_alt_x(h) return predProfile and B747_pred_model.profile_alt(predProfile, h) or nil end
function B747_fms_pred_time_x(t) return predProfile and B747_pred_model.profile_time(predProfile, t) or nil end
-- the place x NM along the predictions' legs, nil beyond them
function B747_fms_pred_pos(x)
  if not predLegs or not x then return nil end
  return B747_fms_pred_point(predLegs, x)
end
local function pred_num(id) return tonumber(fmsModules["data"][id]) end
-- the FMC's climb, descent and cruise speeds as the predictions and VNAV
-- fly them (the CLB, CRZ and DES pages'); (step 9h5b) an active RTA's
-- cruise Mach unless base (the cruise's own)
function B747_fms_schedules(perf, base)
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
  if not base and rtaState.active and rtaState.mach then crzspd = {mach = rtaState.mach} end
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
    if l.proc == "APPR" and ((l.fix and l.fix.kind == "RWY") or l.missed) then missed = true end
  end
  -- (2026-11-12 review FMC-1) an approach with no runway waypoint (LOC,
  -- LDA, VOR, NDB and some RNAV: its MAP before the threshold): its missed
  -- approach's legs give no E/D, the last constraint before them (the
  -- MAP's) is it. Before, the missed approach's last constraint was (RJAA
  -- LOC16R: BINKS 6000A, the T/D 49 NM late). FCOM p.1258: a VOR
  -- approach's E/D is its missed approach point; the others without a
  -- runway waypoint the same: estimate
  local mapPassed = false
  -- the distances: great circles from the point before (the airplane's
  -- for the first), across a conditional leg or a discontinuity too (an
  -- estimate; a conditional leg itself none)
  local from = {lat = simDR_latitude, lon = simDR_longitude}
  local total, lxs = 0, {}
  for i, l in ipairs(r.legs) do
    local d, p0 = 0, from
    if l.fix then
      local _, dd = R.course(from.lat, from.lon, l.fix.lat, l.fix.lon)
      d = dd
      from = l.fix
    end
    total = total + d
    lxs[i] = total
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
    -- 9e4: the leg's glide path angle down, the CIFP's: FCOM p.1262; step
    -- 9i: its procedure, for VNAV's climb constraints: vnav_geo_set)
    -- (FMC-08) the waypoint's speed constraint (CAS: the procedure's or the
    -- crew's; none on a missed approach's leg)
    legs[i] = {name = l.fix and l.fix.ident or "", dist = d, con = con, p0 = p0, p1 = l.fix,
      gp = (l.vangle and l.vangle < 0) and -l.vangle or nil, step = l.step, proc = l.proc,
      spd = (l.spd and not missed_leg(l)) and l.spd or nil}
    if l.missed and l.proc == "APPR" then mapPassed = true end
    if con and not rwy and not mapPassed and not (missed and l.proc == "APPR") then lastCon = i end
  end
  -- (step LF2; notes/ATA-34-61-FMC.md §127) each leg the longer (a turn
  -- flown over its fix) or shorter (a fly-by turn) by the turn into it as
  -- LNAV flies it
  B747_fms_turns(legs, r)
  -- the phase: the FMC's VNAV's (step 9b; before, the old AP's flightPhase)
  local phase = "clb"
  local vph = B747_fms_vnav_phase and B747_fms_vnav_phase()
  if simDR_onGround ~= 1 and vph then phase = string.lower(vph) end
  -- (2026-11-09) in the descent, the waypoint passed last with its
  -- altitude constraint behind the airplane (its great circle's distance
  -- back), for the descent path's line from it (B747.68.pred_model.lua's
  -- behind): before, the leg flown became the idle path back from the
  -- next constraint at each sequencing (IRNMN2: 229 to 469 ft higher, the
  -- A/T's SPD at each waypoint in the perf session's KSEA-KLAX flight)
  -- (2026-11-11) and the others passed in the descent (des_seq: marked at
  -- their sequencing in DES), each at the great circles' distance back fix
  -- to fix (behind_list, the nearest first): with the last one only, the
  -- path built back past a waypoint without a constraint, or past the one
  -- that shaped it, took another shape at the sequencing (offline, 300
  -- random STARs: 126 of 1,178 sequencings moved it over 100 ft; IRNMN2's
  -- windows at every waypoint kept it). A discontinuity passed: across it,
  -- as the predictions' direct; a leg without an end point ends the list
  local behind, behindList = nil, nil
  if phase == "des" then
    local lat, lon, dacc = simDR_latitude, simDR_longitude, 0
    for k = #r.passed, 1, -1 do
      local pl = r.passed[k]
      if not pl.disc then
        if k < #r.passed and not pl.des_seq then break end
        local p = pl.fix or pl.end_at
        if not p then break end
        local _, d = R.course(p.lat, p.lon, lat, lon)
        dacc, lat, lon = dacc + d, p.lat, p.lon
        if pl.fix and pl.alt and pl.proc ~= "SID" and pl.fix.kind ~= "RWY" and not missed_leg(pl) then
          local con
          if pl.akind == "A" then con = {kind = "A", a = pl.alt}
          elseif pl.akind == "B" then con = {kind = "B", a = pl.alt}
          elseif pl.akind == "AB" then con = {kind = "W", a = math.max(pl.alt, pl.alt2 or pl.alt), b = math.min(pl.alt, pl.alt2 or pl.alt)}
          else con = {kind = "AT", a = pl.alt} end
          behindList = behindList or {}
          behindList[#behindList + 1] = {x = -dacc, con = con}
          if k == #r.passed then behind = behindList[1] end
        end
      end
    end
  end
  -- (2026-11-08, step 9i's review, finding 3) the climb's legs, the
  -- predictions' and VNAV's (vnav_geo_set): B747_vnav_model.clb_last, the
  -- rule of the climb constraints' clb_keep. The SID's; in the climb the
  -- enroute legs on to the last predictions' T/C or a short flight's T/D
  -- (none in a cruise climb), before there are predictions those within
  -- half the route ahead (estimate, as before); never an arrival's or an
  -- approach's. Before, the SID's, else those before half the way in any
  -- phase: in the descent an arrival's constraint there was left out of the
  -- path
  local chg = nil
  if B747_fms_vnav_page then
    local _, c = B747_fms_vnav_page()
    chg = c
  end
  local line = chg ~= "CLB" and predResult and (predResult.tc or predResult.td) or nil
  clbLast = B747_vnav_model.clb_last(legs, lxs, phase, line, total / 2)
  -- the E/D: the approach's runway, else the last constraint after the
  -- climb's legs (before 2026-11-01 without a SID the last constraint
  -- anywhere: one 20 NM out on the climb was the E/D, the T/D before it:
  -- s185)
  local ed = rwy
  if not ed and lastCon and lastCon > clbLast then ed = lastCon end
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
  -- (step 9h4b) VNAV's cruise descent under way, its driftdown
  local crzDes = nil
  if chg == "DES" then crzDes = B747_fms_vnav_dd() and "dd" or "des" end
  -- the winds and temperatures along the route (step 8e3; notes/
  -- ATA-34-61-FMC.md §53): the WIND pages' and DESCENT FORECAST's mixed
  -- with the measured wind (true) and temperature
  local fc = B747_fms_des_forecast and B747_fms_des_forecast()
  local field = B747_wind_model.field{legs = legs, route = r, course = R.course,
    measured = {dir = B747_fms_wind_true(), kt = simDR_wind_speed, isa = isa, h = simDR_pressureAlt1, phase = phase},
    orig_elev = r.origin and r.origin.elev or 0, dest_elev = r.dest and r.dest.elev or 0, crz = crz,
    des = fc and fc.slots or nil}
  -- (FMC-08) the descent's speed constraint passed (B747_fms_des_spd), the
  -- climb's floor VREF 30 + 100 (FCOM p.1326)
  local vref = B747DR_airspeed_Vf30
  local floor = (vref and vref > 0 and vref < 900) and vref + B747_vnav_model.CLB_SPD_VREF_ADD or nil
  return {P = B747_perf_db, t = perf, isa = isa, gw = B747_fms_gw_kg(), fuel = perf_fuel_t() * 1000,
    alt = math.max(0, simDR_pressureAlt1), cas = (simDR_onGround ~= 1 and simDR_ias_pilot > 100) and simDR_ias_pilot or nil,
    phase = phase, crz = crz, clb = clb, des = des, crzspd = crzspd, legs = legs, ed = ed, clb_last = clbLast,
    steps = steps, wind = {clb = 0, crz = 0, des = 0}, field = field, eo = eo, crz_des = crzDes, behind = behind, behind_list = behindList,
    spd_behind = (phase == "des" or phase == "crz") and B747_fms_des_spd() or nil, clb_floor = floor}
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
-- the point x NM along the prediction's legs, nil beyond them; in a leg
-- with no fix (a conditional leg: its distance the turn into it alone,
-- B747_fms_turns since step 6d3) at its start (estimate). Before, such a
-- leg's point read its missing end: the error stopped every module of the
-- XTLua plugin (s150's G/A, 2026-11-02)
function B747_fms_pred_point(legs, x)
  local acc = 0
  for _, l in ipairs(legs) do
    if l.dist > 0 and x <= acc + l.dist then
      if not l.p1 then return l.p0 end
      local crs = B747_route_model.course(l.p0.lat, l.p0.lon, l.p1.lat, l.p1.lon)
      -- (step LF2) the turn into the leg its first part (at its start)
      return B747_route_model.course_point(l.p0, crs, math.max(0, x - acc - (l.turn or 0)))
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
    local q = p and B747_fms_pred_point(s.legs, p.x)
    if q then
      B747DR_fms_profile_lat[k] = q.lat
      B747DR_fms_profile_lon[k] = q.lon
      B747DR_fms_profile_kind[k] = p.kind
    elseif B747DR_fms_profile_kind[k] ~= 0 then
      B747DR_fms_profile_kind[k] = 0
    end
  end
end
-- (6-1/6-2 step 11c2a; notes/ATA-34-61-FMC.md §94) VNAV's and RTA's alerts
-- from the predictions (FCOM p.1431-1434): UNABLE NEXT ALT (flag 47: VNAV
-- engaged in the climb, the next waypoint with an AT, AT OR ABOVE or window
-- constraint before the T/C predicted under it, a window's lower; FCOM
-- p.1255, FMSPG p.117), UNABLE FLXXX AT RTA FIX (the RTA FIX's crossing
-- predicted under its altitude constraint while its ETA is within the
-- tolerance), LIMIT ALT FLXXX (VNAV engaged with CRZ ALT above VNAV's
-- limit altitude), DESCENT PATH DELETED (flag 6, an event: VNAV engaged,
-- the path gone with the last constraint defining it). Estimates: 10 ft
-- under; FLXXX at the RTA FIX its constraint's, none without one; VNAV's
-- limit altitude the maximum altitude (the CRZ page's MAX, ENG OUT's
-- engine-out maximum while active: the sources do not say); the path's
-- deletion not after the approach's runway nor in a missed approach.
local UNABLE_TOL_FT=10
local predUnableNext,vnavUnableFlag=false,0
-- (step 11c2b) CHECK ALT TGT's flag (4) as the VNAV model says
local vnavCheckFlag=0
local function unable_next(s,r)
  if not (s and r and r.pts) then return false end
  for i,l in ipairs(s.legs) do
    local p=r.pts[i]
    if not p or (r.tc and p.x>r.tc) or (r.td and p.x>=r.td) then return false end
    local c=l.con
    if c and c.kind~="B" then return p.h<(c.kind=="W" and c.b or c.a)-UNABLE_TOL_FT end
  end
  return false
end
-- a message with an altitude in its text: the old text's gone when it
-- changes (B747_cdu_fmc_condition)
local function fmc_alt_message(old,text)
  if old==text then return text end
  if old then B747_cdu_fmc_condition(old,false,true) end
  if text then B747_cdu_fmc_condition(text,true,true) end
  return text
end
local rtaFlText=nil
local limitText,limitT=nil,nil
local function update_limit_alt(inp)
  local now=simDRTime
  if limitT and now>=limitT and now-limitT<1 then return end
  limitT=now
  local text=nil
  if inp.engaged and inp.crz_alt and inp.kg then
    local lim
    if B747_fms_eo().active then
      lim=B747_fms_eo_crz_max()
    else
      lim=B747_perf_db.max_alt(B747_fms_perf(),inp.kg,B747_fms_isa_dev())
    end
    if lim and inp.crz_alt>lim+1 then text=string.format("LIMIT ALT FL%03d",math.floor(lim/100)) end
  end
  limitText=fmc_alt_message(limitText,text)
end
-- (step 9h5b) RTA's speed (FCOM p.1269, p.1354, p.1383-1384; notes/
-- ATA-34-61-FMC.md §85): with the predictions s and r, the cruise Mach that
-- brings the airplane to its FIX at its time (B747_rta_model.speed: up to
-- RTA_ITER steps, each predicting again), bounded by MAX SPD and VMO/MMO
-- less 16 kt (FCOM p.1258) and by the larger of the minimum drag speed and
-- the minimum maneuvering speed plus 5 kt (estimates); UNABLE RTA (FCOM
-- p.1434: flag 48) more than 30 s off at a bound; RTA FIX DELETED (flag 39)
-- while the route's modification has no FIX; ended once its FIX is no
-- longer ahead in the active route (passed, or gone with an executed
-- modification: estimate). The predictions after it
local RTA_ITER = 3
local function rta_update(s, r)
  local st = rtaState
  local unable, deleted, flText, rtaD = false, false, nil, nil
  if st.active and not B747_fms_rta_avail() then B747_rta_model.terminate(st) end
  if st.active then
    local fix = st.active.fix
    local mod = B747_fmc_route.mod
    if mod then
      deleted = true
      for _, l in ipairs(mod.legs) do
        if l.fix and l.fix.ident == fix then deleted = false break end
      end
    end
    local i = B747_fms_rta_leg(fix)
    if not i then
      B747_rta_model.terminate(st)
    elseif s and r and r.pts[i] then
      local P = B747_perf_db
      local _, _, own = B747_fms_schedules(s.t, true)
      local base = B747_pred_model.crz_mach(P, own, s.crz, s.gw)
      local lo = P.min_drag(s.t, s.gw, s.crz)
      local vmin = B747DR_fms_vnav_vminm
      if vmin and vmin > 0 then lo = math.max(lo, P.cas_to_mach(vmin + 5, s.crz)) end
      local hi = math.min(B747_rta_model.max(st), (P.econ_limit(s.crz)))
      for k = 1, RTA_ITER do
        local p = r.pts[i]
        -- the cruise's time before the FIX: from the T/C (now in the
        -- cruise) to the FIX or the T/D; none in the descent
        local t0 = (s.phase == "clb" and r.tc_t) or 0
        local t1 = math.min(p.t, r.td_t or p.t)
        local tc = s.phase == "des" and 0 or math.max(0, t1 - t0)
        local m, un, d = B747_rta_model.speed(st.active, {mach = st.mach, base = base, now = B747_fms_utc_min(),
          t_fix = p.t, t_cruise = tc, lo = lo, hi = hi})
        unable, rtaD = un, d
        local moved = st.mach == nil or math.abs(m - st.mach) > 0.001
        st.mach = m
        if k == RTA_ITER or not moved then break end
        s.crzspd = {mach = m}
        r = B747_pred_model.predict(s)
      end
      -- (step 11c2a) UNABLE FLXXX AT RTA FIX: its ETA within the
      -- tolerance (the suffix's side free), its crossing under its
      -- constraint
      local c = s.legs[i] and s.legs[i].con
      local want = c and c.kind ~= "B" and (c.kind == "W" and c.b or c.a) or nil
      local p = r.pts[i]
      local suf, tol = st.active.suffix, B747_rta_model.TOL_MIN
      local within = rtaD ~= nil and not ((suf ~= "A" and rtaD > tol) or (suf ~= "B" and rtaD < -tol))
      if want and p and within and p.h < want - UNABLE_TOL_FT then
        flText = string.format("UNABLE FL%03d AT RTA FIX", math.floor(want / 100))
      end
    end
  end
  if not st.active then st.mach = nil end
  rtaFlText = fmc_alt_message(rtaFlText, flText)
  B747DR_fmc_notifications[48] = unable and 1 or 0
  B747DR_fmc_notifications[39] = deleted and 1 or 0
  return r
end
function update_preds()
  if simDRTime < predNext then return end
  predNext = simDRTime + 10
  local s = B747_fms_pred_input(B747BR_cruiseAlt)
  predField = s and s.field or nil
  -- CRZ ALT at or above MAX: the fuel predictions not shown "to prevent bad
  -- predictions" (ATA34_2 p.611), the rest made (no_fuel: 2026-11-05 review
  -- 4; before, none at all: no path, no T/D, no VNAV descent at CRZ ALT =
  -- MAX); (step 9h4b) with ENG OUT active above the engine-out MAX (CRZ ALT
  -- set to it: on) none
  local noFuel = s ~= nil and s.crz >= B747_perf_db.max_alt(s.t, s.gw, s.isa)
  if s and s.eo and s.crz > B747_fms_eo_crz_max() + 1 then s = nil end
  predResult = s and B747_pred_model.predict(s) or nil
  -- (step 9h5b) RTA's speed, the predictions with it
  predResult = rta_update(s, predResult)
  if predResult then predResult.no_fuel = noFuel or nil end
  -- (FIX INFO, 2026-11-04) the profile along the route and the legs it is on;
  -- (OFFPATH DES) the input, its descent's speeds and weight
  predProfile = predResult and B747_pred_model.profile(predResult, s) or nil
  predLegs = predResult and s.legs or nil
  predInput = s
  put_profile(s, predResult)
  vnav_geo_set(s, predResult)
  predUnableNext = unable_next(s, predResult)
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
-- (step 9i) past the T/D, the cruise kept by the MCP altitude: the AFDS's
-- VNAV ALT (FMSPG p.34 (2-22))
B747DR_fms_vnav_td_hold = find_dataref("laminar/B747/fms/vnav/td_hold")
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
-- (6-1/6-2 step 12b2; notes/ATA-34-61-FMC.md §107) the VNAV pages'
-- waypoints from the active route and the predictions (before: X-Plane's
-- FMS legs and their altitudes, FL001 at a point without a constraint):
-- clb, the next waypoint with a speed or altitude constraint before the
-- T/C (CLB's AT XXXXX: FCOM p.1328), with err_ft and err_nm where the
-- prediction there is under an AT, AT OR ABOVE or window's lower by more
-- than UNABLE_TOL_FT: the feet low and how far past it the climb reaches
-- that altitude (ERROR: p.1329); des, the next one after the T/D (DES's AT
-- XXXXX: p.1392); ed, the E/D's waypoint and altitude (E/D AT: p.1392).
-- Without predictions by the FMC's phase. {i, name, leg} each, or nil
function B747_fms_vnav_wpts()
  local st = B747_fmc_route
  local out = {}
  if not st.active then return out end
  local legs, p = st.rte.legs, B747_fms_preds()
  local ph = vnavState.phase
  for i, l in ipairs(legs) do
    if l.fix and (l.alt or l.spd) then
      local x = p and p.pts[i] and p.pts[i].x
      local clb, des
      if p then
        clb = p.tc ~= nil and x ~= nil and x < p.tc
        -- the descent's: after the T/D; without one, in the descent or
        -- with the descent from here to an E/D (the predictions' start of
        -- the descent where the airplane is: no T/C, no T/D)
        des = x ~= nil and ((p.td ~= nil and x >= p.td)
          or (p.td == nil and (ph == "DES" or (p.tc == nil and p.ed ~= nil))))
      else
        clb, des = ph == "CLB", ph == "DES"
      end
      if clb and not out.clb then out.clb = {i = i, name = l.fix.ident, leg = l} end
      if des and not out.des then out.des = {i = i, name = l.fix.ident, leg = l} end
    end
  end
  local c = out.clb
  if c and p and p.pts[c.i] then
    local l = c.leg
    local want = l.alt and l.akind ~= "B" and (l.akind == "AB" and math.min(l.alt, l.alt2 or l.alt) or l.alt) or nil
    local h, x0 = p.pts[c.i].h, p.pts[c.i].x
    if want and h < want - UNABLE_TOL_FT then
      c.err_ft = want - h
      local px, phh = x0, h
      for j = c.i + 1, #legs do
        local q = p.pts[j]
        if q and q.h >= want then
          c.err_nm = px + (want - phh) / math.max(q.h - phh, 1) * (q.x - px) - x0
          break
        elseif q then
          px, phh = q.x, q.h
        end
      end
    end
  end
  local e = p and p.ed_i and legs[p.ed_i]
  if e and e.fix then
    local alt = e.fix.kind == "RWY" and (e.fix.elev or 0) + 50
      or (e.akind == "AB" and math.min(e.alt, e.alt2 or e.alt) or e.alt)
    if alt then out.ed = {i = p.ed_i, name = e.fix.ident, alt = alt} end
  end
  return out
end
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
  -- the climb's legs: the predictions' (B747_fms_pred_input's, from
  -- 2026-11-08 B747_vnav_model.clb_last), else those before half the way
  local clbLast = s.clb_last
  if not clbLast then
    local half = ((s.ed and lx[s.ed]) or acc) / 2
    clbLast = 0
    for i = 1, #s.legs do if lx[i] <= half then clbLast = i end end
  end
  -- (step 9d1) the climb's last point, for the altitude selector's push:
  -- the last of the climb's legs with a point (2026-11-08: they can end on
  -- a discontinuity or a vector, without one; nil then ran the climb's
  -- constraints on to the route's end), none without one
  g.clb_end = nil
  for i = math.min(clbLast, #s.legs), 1, -1 do
    if s.legs[i].p1 then g.clb_end = s.legs[i].p1 break end
  end
  g.clb_none = g.clb_end == nil
  -- (step 9d2a) the points of the legs before the T/D (the climb's and the
  -- cruise's: the early descent deletes their constraints, FMSPG p.3.5-5)
  g.pre_td = {}
  if r.td then
    for i, l in ipairs(s.legs) do
      if l.p1 and lx[i] < r.td then g.pre_td[l.p1] = true end
    end
  end
  -- (step 9i) the climb's own constraints, kept at any altitude until their
  -- waypoints (B747_vnav_model.clb_keep): the SID's, and the enroute legs'
  -- before the T/C or, a short flight's, the T/D where the climb meets the
  -- path; none in a cruise climb (estimates: FCOM p.1258, a constraint
  -- entered in the cruise a descent one). The descent's kinds and points,
  -- for its FMC altitude (B747_vnav_model.des_target)
  local line = vnavState.crz_chg ~= "CLB" and (r.tc or r.td) or nil
  g.des_k, g.des_p = {}, {}
  -- (FMC-08) the climb's legs' speed constraints with their waypoints
  g.clb_spd = {}
  for i = 1, math.min(clbLast, #s.legs) do
    local l = s.legs[i]
    if l.spd and l.p1 then g.clb_spd[#g.clb_spd + 1] = {spd = l.spd, p = l.p1} end
  end
  for i, l in ipairs(s.legs) do
    local c = l.con
    if c and (not s.ed or i < s.ed) then
      if i <= clbLast then
        -- (2026-11-05) with its waypoint, for the target's choice below
        if c.kind == "AT" or c.kind == "B" or c.kind == "W" then
          g.clb[#g.clb + 1] = {a = c.a, p = l.p1, keep = B747_vnav_model.clb_keep(l.proc, lx[i], line)}
        end
      else
        local n = #g.des + 1
        g.des[n], g.des_k[n], g.des_p[n] = c.kind == "W" and c.b or c.a, c.kind, l.p1
      end
    end
  end
  if r.dp and r.ed then
    local dp = r.dp
    -- (step LF1) the decelerations' targets (c) and the T/D's level
    -- deceleration (td_decel NM)
    -- (FMC-08) and the planned CAS at each point (s), for VNAV's speed
    -- limits on a deceleration
    g.path = {e = {}, h = dp.h, k = dp.k, c = dp.c, s = dp.s, td_decel = r.td_decel or 0}
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
  -- (step 11c2a) DESCENT PATH DELETED (an event): VNAV engaged, the path
  -- gone with the last constraint defining it (no E/D left), not after the
  -- approach's runway nor in a missed approach
  if vnavGeo and vnavGeo.path and not g.path and not s.ed and B747DR_ap_vnav_state == 2 and vnavMissed == nil then
    local landed = false
    for _, l in ipairs(B747_fmc_route.rte.passed) do
      if l.proc == "APPR" and l.fix and l.fix.kind == "RWY" then landed = true end
    end
    if not landed then B747DR_fmc_notifications[6] = 1 end
  end
  vnavGeo = g
end
-- (step 9d2a) the distance to go to the T/D (NM: where the path reaches
-- CRZ ALT, else its top; negative past it), nil without a path
function B747_fms_vnav_td()
  local inp = vnavIn
  if not (inp.path and inp.d_ed) then return nil end
  local e = inp.crz_alt and B747_vnav_model.td_e(inp.path, inp.crz_alt) or inp.path.e[#inp.path.e]
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
-- (FMC-08) the target's fixed CAS where a waypoint's speed constraint or the
-- descent's deceleration into a speed segment sets it (the titles' XXXKT:
-- FCOM p.1391-1392; FMSPG p.3.3-3), nil else
function B747_fms_vnav_spd_kt() return vnavState.out.spd_kt end
-- (6-1/6-2 step 11a) PROGRESS 2's VTK ERROR: the VNAV path's deviation
-- (ft, above +) while the descent is active, else nil (FCOM p.1381)
function B747_fms_vtk()
  if not B747_fmc_route.active or vnavState.phase~="DES" then return nil end
  return vnavState.out.path_dev
end
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
-- (FMC-08, 2026-11-09) the descent's waypoint speed constraints passed: the
-- lowest speed (CAS kt) of the waypoints sequenced while VNAV is in the
-- cruise or the descent, in force on to the E/D (FCOM p.1332: at or below
-- its speed; FMSPG p.3.5-3: the descent's speed line above all waypoint
-- speed constraints, the constraint's or the performance speed whichever
-- is less: at and after the waypoint), for VNAV's target and the
-- predictions (B747.68.pred_model.lua's spd_behind: those after the
-- climb's legs, a STAR's waypoint before the T/D too); not a SID's nor a
-- missed approach's, none after the approach's runway; gone in the climb
-- (a missed approach's) and on the ground. Each passed leg looked at
-- once, as it is passed: one passed in the climb (the SID's, the climb's
-- enroute legs) is not the descent's (the cruise's and the descent's
-- only, on to the E/D: an estimate). Nil without one. (One local table:
-- the main chunk is 2 locals short of LuaJIT's 200 at the company
-- uplink's block, 2026-11-09)
local desSpdS = {spd = nil, rwy = false, seen = setmetatable({}, {__mode = "k"})}
function B747_fms_des_spd() return desSpdS.spd end
function desSpdS.update()
  local S, st = desSpdS, B747_fmc_route
  local ph = vnavState.phase
  local inDes = st.active and simDR_onGround ~= 1 and (ph == "DES" or ph == "CRZ")
  if not inDes then S.spd, S.rwy = nil, false end
  local p = st.rte and st.rte.passed
  if not (p and #p > 0) or S.seen[p[#p]] then return end
  -- the legs passed since the last look, in the order passed
  local first = #p
  while first > 1 and not S.seen[p[first - 1]] do first = first - 1 end
  for k = first, #p do
    local l = p[k]
    S.seen[l] = true
    if inDes and not S.rwy then
      if l.fix and l.fix.kind == "RWY" and l.proc ~= "SID" and not missed_leg(l) then
        S.rwy = true
      elseif l.spd and l.proc ~= "SID" and not missed_leg(l) and (not S.spd or l.spd < S.spd) then
        S.spd = l.spd
      end
    end
  end
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
  -- (step 6d5) the route changed or not, X-Plane's plan and the ND's line
  -- anew with the missed approach's legs (B747_fms_missed_shown); the
  -- predictions with them
  B747_fmc_route_changed()
end
-- (step 6d5) whether route leg l is the missed approach flown after a G/A
-- (its legs in X-Plane's plan and on the ND then: FCOM p.147, the missed
-- approach route tracked; before, never)
function B747_fms_missed_shown(l) return l.missed == true and missed_leg(l) end
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
-- cruise descent. A cruise climb (the climb's phase, the CRZ page's CRZ
-- CLB: FCOM p.1347) is the cruise's here (2026-11-05 review 4: before,
-- the climb's: the MCP below CRZ ALT pushed in it did nothing, the climb
-- went on to the old CRZ ALT)
local DES_NOW_NM = 50
local vnavPushSeen = nil
function B747_fms_alt_sel_push()
  local st = B747_fmc_route
  local alt, mcp, ph = simDR_pressureAlt1, B747DR_fms_vnav_mcp_alt, vnavState.phase
  if ph == "CLB" and vnavState.crz_chg == "CLB" then ph = "CRZ" end
  -- (2026-11-11 review) the push that ends the T/D's VNAV ALT: past the T/D,
  -- still level at CRZ ALT in VNAV ALT (the AFDS's FMA 5), a cruise push
  -- (FCOM p.649: in cruise in VNAV PTH or VNAV ALT it begins the descent; the
  -- AFDS's own handler does that). Before, the MCP set below had already made
  -- the phase DES, and this push deleted the next descent constraint
  local crzA = B747BR_cruiseAlt
  if ph == "DES" and B747DR_fms_afds_pitch == 5 and crzA and crzA > 0 and math.abs(alt - crzA) < 300 then
    local td = B747_fms_vnav_td()
    if td and td <= 0 then return end
  end
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
    -- (the sim's options, notes/ATA-34-61-FMC.md §126: the automatic step
    -- climb's) a crew's STEP TO kept until a new CRZ ALT, as CRZ ALT
    -- entered on the CDU (step 8b2; before, kept: STEP TO FL350 at FL350
    -- after the step, s204)
    setFMSData("stepalt", "")
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
    setFMSData("stepalt", "")
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
  if inp.ground and vnavMissed ~= nil then
    vnavMissed, vnavMissedCrz = nil, nil
    B747_fmc_route_changed()
  end
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
  inp.des_kind, inp.des_e = nil, nil
  -- (FMC-08) the waypoints' speed constraints in force: the descent's
  -- passed (desSpdS), the climb's ahead (below)
  desSpdS.update()
  inp.des_spd, inp.clb_spd = desSpdS.spd, nil
  if g then
    -- (FMC-08) the lowest of the climb's waypoints' speed constraints not
    -- passed (each until passing it: FMSPG p.3.3-17)
    if g.clb_spd then
      for _, e in ipairs(g.clb_spd) do
        if (not inp.clb_spd or e.spd < inp.clb_spd) and not point_passed(e.p) then inp.clb_spd = e.spd end
      end
    end
    -- the climb's next AT, AT OR BELOW or block constraint: (2026-11-05)
    -- kept through a level-off's overshoot while its waypoint is ahead
    -- (B747_vnav_model.clb_target; before, 100 ft over it went on to the
    -- next: s253; step 9i: a climb constraint at any altitude)
    inp.clb_alt = B747_vnav_model.clb_target(g.clb, inp.alt, inp.crz_alt, point_passed)
    inp.des_alt = g.des[1] or g.hed
    -- (step 9i) its kind and its point's distance to go to the E/D: an AT
    -- OR BELOW's FMC altitude the lower of it and the path there
    -- (B747_vnav_model.des_target; FMSPG p.227 (4-16))
    if g.des[1] then
      local p = g.des_p and g.des_p[1]
      inp.des_kind = g.des_k and g.des_k[1] or nil
      inp.des_e = p and g.rem and g.rem[p] or nil
    end
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
      -- (step LF2; notes/ATA-34-61-FMC.md §127) through a turn flown over
      -- its fix the distance flown taken off, until LNAV is on the leg (or
      -- not engaged, or TURN_MAX_S on); LNAV's deviations from the new leg
      -- only after TURN_LNAV_S (LNAV runs after VNAV: a frame on they are
      -- still the leg before's)
      local tr = vnavState.turn
      if tr then
        local s = B747_fmc_lnav
        local L, V = B747_lnav_model, B747_vnav_model
        local age = simDRTime - tr.t1
        local onLeg = B747DR_fms_ap_lnav_state ~= 2 or age > V.TURN_MAX_S
          or (age > V.TURN_LNAV_S and math.abs(s.xtk or 0) <= L.FLY_XT and math.abs(s.tae or 0) <= L.FLY_TAE)
        local d, on = B747_vnav_model.turn_dist(tr, inp.d_ed, inp.gs, simDRTime, onLeg)
        inp.d_ed = d
        if not on then vnavState.turn = nil end
      end
    end
  end
  local out = B747_vnav_model.update(vnavState, inp)
  -- (2026-11-11 review, FMC-2b F1) the descent over (a missed approach, on
  -- the ground): its legs' marks cleared, the dataref still last frame's
  -- phase. Before, after a go-around with one leg or none sequenced in the
  -- climb, the second descent's path took the first arrival's constraints
  -- behind the airplane (1,200 to 1,500 ft low at its start)
  if out.phase ~= "DES" and B747DR_fms_vnav_phase == 3 and B747_fmc_route.rte then
    for _, l in ipairs(B747_fmc_route.rte.passed) do l.des_seq = nil end
  end
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
  local tdh = out.td_hold and 1 or 0
  if B747DR_fms_vnav_td_hold ~= tdh then B747DR_fms_vnav_td_hold = tdh end
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
  -- (step 11c2a) UNABLE NEXT ALT (flag 47, written when it changes), LIMIT
  -- ALT FLXXX
  local un = (inp.engaged and out.phase == "CLB" and predUnableNext) and 1 or 0
  if vnavUnableFlag ~= un then
    vnavUnableFlag = un
    B747DR_fmc_notifications[47] = un
  end
  update_limit_alt(inp)
  -- (step 11c2b) CHECK ALT TGT (flag 4: B747.68.vnav_model.lua's)
  local chk = out.check_alt and 1 or 0
  if vnavCheckFlag ~= chk then
    vnavCheckFlag = chk
    B747DR_fmc_notifications[4] = chk
  end
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
-- TO 1's and TO 2's derates, %: PERF FACTORS' (step 12c1; before, the
-- FCOM's operator's fixed here)
function B747_fms_thrlim_pct(n)
  if n == 0 then return 0 end
  local v = B747_fms_perf_factors()
  return n == 1 and v.to1 or v.to2
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
  -- (step 12c1) PERF FACTORS' THR/CRZ: the cruise's limit CLB or CRZ
  inp.crz_clb = B747_fms_perf_factors().thr_crz == "CLB"
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
-- (step LF2; notes/ATA-34-61-FMC.md §127) the turn transitions in the
-- predictions' legs: the turn at the fix before leg i as LNAV flies it
-- between its path's elements (B747.68.lnav_model.lua's transition) added
-- to the leg's distance (turn: the NM added, for the ND's points), at the
-- turns' speed there (LNAV's: the true airspeed, the last predictions' at
-- the fix else the ground speed now, and the wind now); kept by the fix,
-- the courses and the speed in 10 kt steps, and by the route's leg for
-- VNAV's distance through a turn flown over its fix (B747_fms_turn_of).
-- (2026-11-05 review 4) A turn kept until TURN_KEEP calls have not used it:
-- the speed with the wind, near a 10 kt step's edge, goes from one step to
-- the other in gusts (before, the last call's turns alone: each change made
-- them again)
local TURN_KEEP = 4
do
  local cache, age, gen, byRouteLeg = {}, {}, 0, setmetatable({}, {__mode = "k"})
  function B747_fms_turns(legs, r)
    local path = lnavPath
    if not path then return end
    local byLeg = {}
    for _, e in ipairs(path) do if e.leg then byLeg[e.leg] = e end end
    local pts = predResult and predResult.pts
    local isa = B747_fms_isa_dev()
    gen = gen + 1
    for i = 2, #legs do
      local e1, e2 = byLeg[i - 1], byLeg[i]
      if e1 and e2 and e1.b then
        local vt = nil
        local p = pts and pts[i - 1]
        if p and p.h then
          local m = p.machMode and p.mach or (p.cas and B747_perf_db.cas_to_mach(p.cas, p.h)) or p.mach
          if m then vt = B747_perf_db.tas(m, p.h, isa) end
        end
        vt = math.max(vt or simDR_groundspeed * 1.94384, 150) + simDR_wind_speed
        local a2, b2 = e2.a or e1.b, e2.b or e1.b
        local key = string.format("%.5f %.5f %.1f %.1f %.5f %.5f %.5f %.5f %d", e1.b.lat, e1.b.lon, e1.crs or e1.hdg or -1,
          e2.crs or e2.hdg or -1, a2.lat, a2.lon, b2.lat, b2.lon, math.floor(vt / 10 + 0.5))
        local x = cache[key]
        if x == nil then
          x = B747_lnav_model.transition(B747_path_model, e1, e2, math.floor(vt / 10 + 0.5) * 10)
          cache[key] = x
        end
        age[key] = gen
        local l = legs[i]
        l.turn = math.max(x, -l.dist)
        l.dist = l.dist + l.turn
        if r.legs[i] then byRouteLeg[r.legs[i]] = x end
      end
    end
    for k in pairs(cache) do
      if age[k] <= gen - TURN_KEEP then cache[k], age[k] = nil, nil end
    end
  end
  function B747_fms_turn_of(leg) return leg and byRouteLeg[leg] or nil end
end
-- the active leg the path was built with (a new one not by sequencing:
-- captured again, FCOM p.644), sequencing now, LNAV engaged a frame ago
local lnavFirst=nil
local lnavSequencing=false
local lnavWasEngaged=false
-- (step 6d2) the ND's line to draw anew (B747_fmc_nd_line), the element
-- LNAV sequenced last (its turn into the active leg drawn while flown)
B747_nd_line_dirty=true
do
  local prev,prevKt=nil,nil
  function B747_fmc_nd_line_prev(e)
    prev=e
    prevKt=e and B747_fmc_turn_kt(0) or nil
  end
  function B747_fmc_nd_line_prev_of() return prev end
  -- (step 6d3) the speed when it was sequenced (the active leg's turn)
  function B747_fmc_nd_line_prev_kt() return prevKt end
end
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
-- the sizes for the path model's shape, marked drawn ((step 6d2) not for
-- the ND's line: `keep`)
local function lnav_hold_sizes(keep)
  local i,t=lnav_to_hold()
  local h=lnav_pturn()
  if not keep then
    holdDrawn=i and {i=i,r=t.r,l=t.l} or nil
    ptDrawn=h
  end
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
-- (step 6d2) the speed of the turn at the fix ending leg i (the ND's line,
-- the path's turns): LNAV's now (the true airspeed and the wind) at the
-- active waypoint and the fix sequenced last (i<=1), the predictions' true
-- airspeed at the others' fixes with the wind now (B747_fms_turns')
function B747_fmc_turn_kt(i)
  local air=lnavAir
  local now=air and ((air.tas or air.gs)+(air.wind or 0)) or (simDR_groundspeed*1.94384+simDR_wind_speed)
  if i<=1 then return now end
  local p=predResult and predResult.pts and predResult.pts[i]
  local vt=nil
  if p and p.h then
    local m=p.machMode and p.mach or (p.cas and B747_perf_db.cas_to_mach(p.cas,p.h)) or p.mach
    if m then vt=B747_perf_db.tas(m,p.h,B747_fms_isa_dev()) end
  end
  if not vt then return now end
  return math.max(vt,150)+simDR_wind_speed
end
-- (step 6d3; notes/ATA-34-61-FMC.md §133) the speed of the turn into leg i
-- flown over the point before it (the path model's turn_in): at the fix
-- before it, the active leg's at the speed when its leg before was
-- sequenced; at least 150 kt (B747_fms_turns')
function B747_fmc_turn_kt_into(i)
  local v=(i<=1 and B747_fmc_nd_line_prev_kt()) or B747_fmc_turn_kt(i-1)
  return math.max(v or 150,150)
end
function B747_fmc_lnav_build()
  local st=B747_fmc_route
  local r=st.rte
  -- a new active leg not by sequencing: no leg before it (its turn)
  local key=st.active and lnav_leg_key(r.legs[1]) or nil
  if st.active and key~=lnavFirst and not lnavSequencing then B747_fmc_nd_line_prev(nil) end
  routePath=B747_path_model.build(r.legs,B747_route_model.leg_from(r,1),{var=lnav_var,alt=simDR_pressureAlt1,
    kt=B747_fmc_turn_kt_into,prev=st.active and B747_fmc_nd_line_prev_of() or nil})
  if not st.active then lnavPath,lnavFirst=nil,nil return end
  if key~=lnavFirst and not lnavSequencing then
    B747_lnav_model.reset(B747_fmc_lnav)
  end
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
  B747_nd_line_dirty=true
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
  local fms,map=B747_route_model.to_fms(r,(B747_navdb.cycle_info(B747_fmc_navdb)),B747_path_model.shape(routePath,HOLD_SYMBOL_KT,lnav_hold_sizes()),
    B747_fms_missed_shown)
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
  -- the activation in flight: X-Plane's current waypoint looked at again
  -- (with a new plan: once it is loaded; the AFDS's the active one's row
  -- each frame: B747_fmc_route_sync)
  if active and not routeWasActive and simDR_onGround==0 and routePending==nil then
    routeSync=map.n
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
  -- (step 11e1) a CDU's IRS LEGS modification its own
  local l=((on or B747_fms_altn_mod("fmsL")) and cduPowered("fmsL")) and 1 or 0
  local r=((on or B747_fms_altn_mod("fmsR")) and cduPowered("fmsR")) and 1 or 0
  if B747DR_fms_exec_light_pilot~=l then B747DR_fms_exec_light_pilot=l end
  if B747DR_fms_exec_light_copilot~=r then B747DR_fms_exec_light_copilot=r end
end

-- each frame (6-1/6-2 step 5e): a new plan to X-Plane once the route has
-- stayed the same a second. (step 6d2; notes/ATA-34-61-FMC.md §132)
-- X-Plane's current waypoint its plan's last row: X-Plane's map (kept for
-- the weather radar) draws the legs from its current waypoint on, none so
-- (the ND's line is the FMS bridge's); before, the active one in flight.
-- The AFDS's, the ND's and the FMC's own current waypoint (fmscurrentIndex,
-- xtlua/fms's rows) the active route's active one's row, an inactive
-- route's first, once X-Plane has the plan; X-Plane's looked at again every
-- 5 s (LNAV sequences the route itself since step 6c)
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
    -- X-Plane starts a new plan at its first waypoint: its last current
    -- (the bridge right after the load)
    if bridge then
      B747DR_xp_plan=string.format("CURRENT %d\n",routeMap.n)..routePending
    else
      fmsLoadDref=routePending
    end
    routePending=nil
    routeSync=routeMap.n
    routeSyncT,routeSyncWrites=simDRTime,0
    return
  end
  if not routeMap or routePending then routeSync=nil return end
  local fms=fms_route()
  -- X-Plane's plan the one loaded last: not before xtlua/fms shows it (the
  -- old one, with as many rows, a second)
  if table.getn(fms)~=routeMap.n then return end
  if fmsJSON==routeLoadOld and simDRTime-routeLoadT<1 then return end
  local k=st.active and B747_route_model.active_row(st.rte,routeMap) or 1
  if cur~=k then B747DR_fmscurrentIndex=k end
  local last=routeMap.n
  if routeSync then
    if simDRTime-routeSyncT>10 or fms[last][10]==true then routeSync=nil return end
    if bridge then
      -- X-Plane's thread: until X-Plane shows it
      if xpcur~=last then B747DR_xp_current=last end
    elseif routeSyncWrites<2 and simDRTime-routeSyncT>=2*routeSyncWrites then
      -- XTLua's: now, and once more after two seconds
      B747DR_fms_currentID=last
      routeSyncWrites=routeSyncWrites+1
    end
    return
  end
  if simDRTime-routeSyncT<5 then return end
  routeSyncT=simDRTime
  if fms[last][10]~=true then
    routeSync=last
    routeSyncWrites=0
  end
end

-- (6-1/6-2 step 6d2; notes/ATA-34-61-FMC.md §132) the ND's route line for
-- the FMS bridge plugin (B747.68.nd_line_model.lua; FCOM p.1147-1148): RTE
-- 1's path (the active route, else an inactive one), the lateral offset's
-- lines beside it, the modification's path, (step 6d4) the other route's
-- under them (inactive: FCOM p.1148; an activation not yet executed:
-- p.1251); anew each ND_LINE_S seconds
-- (the turns' speeds, LNAV's turn) and when the route changes, the points
-- that changed written. The turns' speed: LNAV's now (the true airspeed and
-- the wind) at the active waypoint and the fix sequenced last, the
-- predictions' true airspeed at the others' fixes with the wind now
-- (B747_fms_turns')
B747DR_nd_line_n=find_dataref("laminar/B747/nd/line/n")
B747DR_nd_line_lat=find_dataref("laminar/B747/nd/line/lat")
B747DR_nd_line_lon=find_dataref("laminar/B747/nd/line/lon")
B747DR_nd_line_pen=find_dataref("laminar/B747/nd/line/pen")
-- (2026-11-04) FIX INFO's and OFFPATH DES's shapes on the ND (FCOM
-- p.1149-1150, p.1358-1359, p.1398-1399; FMSPG p.166-169): the bearings'
-- radial lines from the fix (green dashes, RADIAL_NM long: estimate, as far
-- as FIX INFO looks for their crossings) into the line's points; the
-- distances' circles round the fix and the energy management circles as
-- centres and radii for the FMS bridge plugin; the fixes (the ND module
-- draws them in a small green circle with their identifiers) and PRED
-- ETA-ALT's points (a green profile circle with the entered time or
-- altitude) for the ND module, the texts as character codes
B747DR_nd_circle_n=find_dataref("laminar/B747/nd/circle/n")
B747DR_nd_circle_lat=find_dataref("laminar/B747/nd/circle/lat")
B747DR_nd_circle_lon=find_dataref("laminar/B747/nd/circle/lon")
B747DR_nd_circle_radius=find_dataref("laminar/B747/nd/circle/radius")
B747DR_nd_circle_pen=find_dataref("laminar/B747/nd/circle/pen")
B747DR_fms_fix_show=find_dataref("laminar/B747/fms/fix/show")
B747DR_fms_fix_lat=find_dataref("laminar/B747/fms/fix/lat")
B747DR_fms_fix_lon=find_dataref("laminar/B747/fms/fix/lon")
B747DR_fms_fix_ident=find_dataref("laminar/B747/fms/fix/ident")
B747DR_fms_fix_pred_show=find_dataref("laminar/B747/fms/fix/pred_show")
B747DR_fms_fix_pred_lat=find_dataref("laminar/B747/fms/fix/pred_lat")
B747DR_fms_fix_pred_lon=find_dataref("laminar/B747/fms/fix/pred_lon")
B747DR_fms_fix_pred_text=find_dataref("laminar/B747/fms/fix/pred_text")
do
local RADIAL_NM=512
local function put_if(ref,k,v) if ref[k]~=v then ref[k]=v end end
local function put_text(ref,base,s)
  for c=0,4 do put_if(ref,base+c,string.byte(s or "",c+1) or 0) end
end
function B747_fmc_nd_fixes(pts)
  local D=B747_nd_line_model
  local fx=B747_fms_fix_nd and B747_fms_fix_nd() or {}
  local circles={}
  for p=1,2 do
    local o=fx[p] or {radials={},circles={}}
    local f=o.fix
    if f then
      for _,b in ipairs(o.radials) do
        if #pts+2<=D.MAXP then
          local e=B747_route_model.course_point(f,b,RADIAL_NM)
          pts[#pts+1]={lat=f.lat,lon=f.lon,pen=D.FIX}
          pts[#pts+1]={lat=e.lat,lon=e.lon,pen=0}
        end
      end
      for _,r in ipairs(o.circles) do circles[#circles+1]={lat=f.lat,lon=f.lon,r=r,pen=D.FIX} end
    end
    put_if(B747DR_fms_fix_show,p-1,f and 1 or 0)
    if f then
      put_if(B747DR_fms_fix_lat,p-1,f.lat)
      put_if(B747DR_fms_fix_lon,p-1,f.lon)
      put_text(B747DR_fms_fix_ident,(p-1)*5,f.ident)
    end
    local q=o.pred
    put_if(B747DR_fms_fix_pred_show,p-1,q and 1 or 0)
    if q then
      put_if(B747DR_fms_fix_pred_lat,p-1,q.lat)
      put_if(B747DR_fms_fix_pred_lon,p-1,q.lon)
      put_text(B747DR_fms_fix_pred_text,(p-1)*5,q.text)
    end
  end
  -- OFFPATH DES's energy management circles
  if B747_fms_offpath_nd then
    for _,c in ipairs(B747_fms_offpath_nd()) do circles[#circles+1]=c end
  end
  local n=math.min(#circles,D.MAXC)
  for k=1,n do
    local c=circles[k]
    put_if(B747DR_nd_circle_lat,k-1,c.lat)
    put_if(B747DR_nd_circle_lon,k-1,c.lon)
    put_if(B747DR_nd_circle_radius,k-1,c.r)
    put_if(B747DR_nd_circle_pen,k-1,c.pen)
  end
  if B747DR_nd_circle_n~=n then B747DR_nd_circle_n=n end
end
end
do
local ND_LINE_S=1
local ndLineT=-100
-- the flyover turns kept until TURN_KEEP lines have not used them
-- (2026-11-05 review 4: their speed with the wind in 10 kt steps goes from
-- one step to the other in gusts; before, the last line's alone, each
-- change a turn made again)
local ndLineCache,ndLineAge,ndLineGen={},{},0
local ndLineOld={n=0,lat={},lon={},pen={}}
function B747_fmc_nd_line()
  if not B747_nd_line_dirty and simDRTime-ndLineT<ND_LINE_S then return end
  B747_nd_line_dirty,ndLineT=false,simDRTime
  local D,P=B747_nd_line_model,B747_path_model
  local st=B747_fmc_route
  local r=st.rte
  local used={}
  local o={P=P,L=B747_lnav_model,cache=ndLineCache,used=used,kt=B747_fmc_turn_kt}
  local pts={}
  -- (step 6d5) the missed approach flown after a G/A drawn as the route's
  local function shown_in(legs)
    return function(e) local l=legs[e.leg] return l~=nil and B747_fms_missed_shown(l) end
  end
  if routePath and #r.legs>0 then
    o.shown=st.active and shown_in(r.legs) or nil
    o.style=st.active and D.ACTIVE or (st.activating and D.ACTIVATING or D.INACTIVE)
    o.shape=P.shape(routePath,HOLD_SYMBOL_KT,(lnav_hold_sizes(true)))
    o.prev=st.active and B747_fmc_nd_line_prev_of() or nil
    D.route(routePath,o,pts)
    -- the lateral offset's lines (step 7d; FCOM p.1148: dashed beside the
    -- route)
    if st.active and r.offset and lnavPath then
      local off={}
      for _,e in ipairs(lnavPath) do
        if e.offset then off[#off+1]=e else break end
      end
      o.style,o.prev,o.shape=D.OFFSET,nil,nil
      D.route(off,o,pts)
    end
  end
  local m=st.active and st.mod or nil
  if m and #m.legs>0 then
    local mp=P.build(m.legs,B747_route_model.leg_from(m,1),{var=lnav_var,alt=simDR_pressureAlt1,
      kt=B747_fmc_turn_kt_into,prev=B747_fmc_nd_line_prev_of()})
    o.style,o.prev,o.shape,o.shown=D.MOD,nil,P.shape(mp,HOLD_SYMBOL_KT),shown_in(m.legs)
    D.route(mp,o,pts)
  end
  -- (2026-11-04) FIX INFO's radial lines; the circles, the fixes and the
  -- PRED points
  B747_fmc_nd_fixes(pts)
  -- (step 6d4) the other route (B747_fmc_route2: never the active one),
  -- under these (its points first, as many as they leave); its turns at
  -- the speed now (no predictions of its own), in the air from its first
  -- waypoint (a copy has no legs passed: not from the origin; estimate)
  local st2=B747_fmc_route2
  local r2=st2.rte
  if #r2.legs>0 and #pts<D.MAXP then
    local kt2=math.max(B747_fmc_turn_kt(0),150)
    local p2=P.build(r2.legs,simDR_onGround==1 and B747_route_model.leg_from(r2,1) or nil,{var=lnav_var,alt=simDR_pressureAlt1,
      kt=function() return kt2 end})
    local under={}
    o.style=st2.activating and D.ACTIVATING or D.INACTIVE
    o.prev,o.shape,o.kt,o.shown=nil,P.shape(p2,HOLD_SYMBOL_KT),kt2,nil
    D.route(p2,o,under)
    for k=#under,D.MAXP-#pts+1,-1 do under[k]=nil end
    for _,p in ipairs(pts) do under[#under+1]=p end
    pts=under
  end
  -- the turns this line used kept, the others until TURN_KEEP lines
  -- have gone without them (the model adds new ones to the cache)
  ndLineGen=ndLineGen+1
  for k in pairs(used) do ndLineAge[k]=ndLineGen end
  for k in pairs(ndLineCache) do
    if (ndLineAge[k] or 0)<=ndLineGen-TURN_KEEP then ndLineCache[k],ndLineAge[k]=nil,nil end
  end
  local lat,lon,pen,n=D.pack(pts)
  local old=ndLineOld
  for k=1,n do
    if old.lat[k]~=lat[k] then B747DR_nd_line_lat[k-1]=lat[k] old.lat[k]=lat[k] end
    if old.lon[k]~=lon[k] then B747DR_nd_line_lon[k-1]=lon[k] old.lon[k]=lon[k] end
    if old.pen[k]~=pen[k] then B747DR_nd_line_pen[k-1]=pen[k] old.pen[k]=pen[k] end
  end
  if old.n~=n then
    old.n=n
    B747DR_nd_line_n=n
  end
end
end

-- each frame (6-1/6-2; notes/ATA-34-61-FMC.md §42; FCOM p.1333; FMSPG
-- p.124): with an ND in PLN, the ND's PLAN centre (plan_ctr_row, from 1;
-- step 6d2: before, X-Plane's displayed waypoint through the FMS bridge,
-- which X-Plane keeps at or after its current one, its plan's last row now)
-- the row of the LEGS pages' centre (B744.fms.pages.legs.lua) in X-Plane's
-- flight plan: its leg's, else the same waypoint's in the route X-Plane has
-- (a modification's, the other route's); none there (a modification's new
-- waypoint, a conditional leg not predicted): as it was
B747DR_fms_plan_ctr_row=find_dataref("laminar/B747/fms/plan_ctr_row")
function B747_fmc_plan_ctr_sync()
  if not B747_cdu_plan_ctr_update() then return end
  if not routeMap or routePending then return end
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
  if B747DR_fms_plan_ctr_row~=k then B747DR_fms_plan_ctr_row=k end
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
    -- (step LF2) a turn flown over the fix sequenced (the predictions' leg
    -- after it the longer by more than TURN_MIN_NM): VNAV's distance to
    -- go through it by the distance flown (B747.68.vnav_model.lua's
    -- turn_dist)
    local tx=B747_fms_turn_of(st.rte.legs[2])
    if tx and tx>B747_vnav_model.TURN_MIN_NM and vnavIn.d_ed then vnavState.turn={d=vnavIn.d_ed,t=simDRTime,t1=simDRTime} end
    -- (step 6d2) the ND's line keeps the turn at its fix (the route's
    -- element: the line is the route's, an offset's beside it); none when
    -- the airplane is farther from the fix than the fly-by turn's start and
    -- LNAV's 2.5 nm (FCOM p.644; estimate): a route executed in flight with
    -- the airplane past its first fix on its first leg (from the origin)
    -- sequences it at once, and the ND drew that fix's turn far from the
    -- airplane (s219's RTE 2)
    local pe=routePath and routePath[n]
    if pe and pe.term=="fix" and pe.b then
      local t=B747_path_model.turn(pe,routePath[n+1],B747_fmc_turn_kt(0))
      local _,d=B747_path_model.course(air,pe.b)
      if d>(t and t.d or 0)+2.5 then pe=nil end
    end
    B747_fmc_nd_line_prev(pe)
    -- (the AFDS's and the ND's current waypoint the next row: route sync;
    -- 2026-11-11: those passed in the descent marked, des_seq, for the
    -- predictions' behind_list; past the T/D still in the cruise too, the
    -- MCP not set down (the late descent: the 2026-11-11 review's FMC-2b F2)
    local tdNm=B747_fms_vnav_td()
    local inDes=vnavState.phase=="DES" or (vnavState.phase=="CRZ" and tdNm~=nil and tdNm<=0)
    if B747_route_model.sequence(st,n,start,inDes) then B747_fmc_route_changed() end
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
-- (6-1/6-2 step 10a) the FMC's position updating and navigation
-- performance (B747.68.navperf_model.lua; notes/ATA-34-61-FMC.md §86).
-- Once a second the model's inputs: the IRUs (B747_fms_irs_pos), the
-- GPSs, the DME-DME pair from the FMC's database (its DMEs in reach each
-- 10 s, not the NAVAID INHIBIT ones nor an ILS's: FCOM p.1356), the tuned
-- VOR/DME (VOR L, R: not a VOR ONLY INHIBIT one nor with VOR/DME NAV
-- inhibited: FCOM p.1356-1357), LOC updating with ILS L's localizer, the
-- RNP's phase. It writes the ND's update lines (FCOM p.1150), UNABLE RNP
-- (the caution 66 on the approach, else the advisory 295: FCOM p.1430),
-- VERIFY RNP and SPLIT IRS OPERATION (FCOM p.1434-1435) when they change.
-- POS REF 2/3 and 3/3 show it (activepages/B744.fms.pages.posinit.lua):
-- their PURGE (CONFIRM showing) back when no CDU shows page 2, BRG/DIST
-- (the state's brg) when none shows 2 or 3 (FCOM p.1368-1369).
dofile("B747.68.navperf_model.lua")
local NP=B747_navperf_model
local navperfState=NP.new()
navperfState.brg=false
local navperfIn=NP.inputs()
local navperfT,ddT=nil,nil
local ddPair,ddCands=nil,{}
local navperfFlags={}
B747DR_CAS_caution_status=find_dataref("laminar/B747/CAS/caution_status")
local UNABLE_RNP_CAUTION,UNABLE_RNP_ADVISORY=66,295
local VERIFY_RNP,SPLIT_IRS_OPERATION=52,43
function B747_fms_navperf() return navperfState end
-- the IRS position the FMC uses: the three's mix, else one (L or C, then
-- R; L in polar operation: ATA34_2 p.601-602; FCOM p.1241): latitude,
-- longitude, ground speed (kt) and "3", "L", "C" or "R"; nil without one
function B747_fms_irs_pos()
  local v=B747DR_nav_irs_nav_valid
  local ok={v[0]==1,v[1]==1,v[2]==1}
  if ok[1] and ok[2] and ok[3] and not navperfState.polar then
    local lat0,lon0=B747DR_nav_irs_lat[0],B747DR_nav_irs_lon[0]
    local la,lo,gs=0,0,0
    for i=0,2 do
      la=la+B747DR_nav_irs_lat[i]
      lo=lo+((B747DR_nav_irs_lon[i]-lon0+180)%360-180)
      gs=gs+B747DR_nav_irs_gs[i]
    end
    return la/3,(lon0+lo/3+180)%360-180,gs/3,"3"
  end
  for n,name in ipairs({"L","C","R"}) do
    if ok[n] then return B747DR_nav_irs_lat[n-1],B747DR_nav_irs_lon[n-1],B747DR_nav_irs_gs[n-1],name end
  end
  return nil
end
-- an identifier from X-Plane's receivers
local function rx_ident(s) return type(s)=="string" and string.match(s,"^%s*(%w+)") or nil end
-- the nearest database point of a kind with this identifier: its index and nm
local function nearest_kind(db,ident,kind,lat,lon)
  local best,bd=nil,nil
  local i=ident and db.first[ident]
  while i do
    if db.kind[i]==kind and db.nav[i] then
      local d=B747_navdb.distance(lat,lon,db.lat[i],db.lon[i])
      if not bd or d<bd then best,bd=i,d end
    end
    i=db.nxt[i]
  end
  return best,bd
end
-- REF NAV DATA's inhibits (FCOM p.1356-1357): NAVAID INHIBIT for any
-- updating, VOR ONLY INHIBIT and VOR/DME NAV for VOR/DME's (`vor`)
local function same_point(p,db,i)
  return p~=nil and p.ident==db.ident[i] and math.abs(p.lat-db.lat[i])<0.01 and math.abs(p.lon-db.lon[i])<0.01
end
local function nav_inhibited(db,i,vor)
  local inh=B747_fmc_nav_inhibits and B747_fmc_nav_inhibits()
  if not inh then return false end
  if same_point(inh.navaid[1],db,i) or same_point(inh.navaid[2],db,i) then return true end
  return vor and (inh.vordme or same_point(inh.vor[1],db,i) or same_point(inh.vor[2],db,i)) or false
end
-- a TACAN alone (the navigation data's VOR record named "... TACAN"; a
-- VORTAC is "... VORTAC"): its DME for the DME-DME updating, no VOR for
-- the VOR receivers
local function tacan_only(rec)
  return rec~=nil and rec.name~=nil and string.match(rec.name,"TACAN$")~=nil
end
-- the DMEs in reach (a VOR's DME, a DME alone; not an ILS's: the DME's
-- channel 5, ATA34_2 p.605), the 30 nearest; and a VOR or DME within the
-- oceanic distance
local function dd_scan(db,lat,lon,alt)
  local N=B747_navdb
  local cands,near={},false
  for _,e in ipairs(N.radio_near(db,lat,lon,NP.OCEANIC_NM)) do
    local i=e.i
    local k,rec=db.kind[i],db.nav[i]
    if k==N.VOR or k==N.DME then near=true end
    local ils=rec.name~=nil and (string.find(rec.name,"ILS") or string.find(rec.name,"LOC"))
    if (k==N.DME or (k==N.VOR and rec.dme)) and not ils and not nav_inhibited(db,i,false) then
      local la,lo,el=db.lat[i],db.lon[i],rec.elev
      if k==N.VOR then la,lo,el=rec.dme_lat or la,rec.dme_lon or lo,rec.dme_elev or el end
      local brg,d=B747_route_model.course(lat,lon,la,lo)
      if NP.dme_ok(d,rec.range,alt,el) then
        cands[#cands+1]={ident=db.ident[i],freq=rec.freq,lat=la,lon=lo,elev=el,range=rec.range,dist=d,brg=brg,
          tacan=k==N.VOR and tacan_only(rec)}
      end
    end
  end
  table.sort(cands,function(a,b) return a.dist<b.dist end)
  for j=#cands,31,-1 do cands[j]=nil end
  return cands,near
end
-- the pair between the scans: nil out of reach or of the angles
local function dd_refresh(p,lat,lon,alt)
  for _,c in ipairs({p.a,p.b}) do
    c.brg,c.dist=B747_route_model.course(lat,lon,c.lat,c.lon)
    if not NP.dme_ok(c.dist,c.range,alt,c.elev) then return nil end
  end
  local ang=NP.angle(p.a.brg,p.b.brg)
  if ang<NP.DD_ANGLE_MIN or ang>NP.DD_ANGLE_MAX then return nil end
  p.angle,p.anp=ang,NP.anp_dd(p.a.dist,p.b.dist,ang)
  return p
end
-- VOR/DME: VOR L or R (X-Plane's NAV 3, 4) receiving a VOR with its DME,
-- the database's station in reach within 25 nm; the nearer
local function vd_find(db,lat,lon,alt)
  local best=nil
  for k,idx in ipairs({2,3}) do
    if simDR_radio_nav_horizontal[idx]==1 and simDR_radio_nav_hasDME[idx]==1 then
      local ident=rx_ident(k==1 and simDR_radio_nav03_ID or simDR_radio_nav04_ID)
      local i,d=nearest_kind(db,ident,B747_navdb.VOR,lat,lon)
      local rec=i and db.nav[i]
      if rec and rec.dme and d<=NP.VD_MAX_NM and NP.dme_ok(d,rec.range,alt,rec.elev)
        and not nav_inhibited(db,i,true) and (best==nil or d<best.dist) then
        best={ident=ident,dist=d,anp=NP.anp_vd(d)}
      end
    end
  end
  return best
end
-- LOC updating: ILS L's localizer (X-Plane's NAV 1) received, the active
-- route's approach's runway at its destination (FCOM p.1241)
local function loc_find(db,lat,lon,alt)
  if simDR_radio_nav_horizontal[0]~=1 then return false end
  local i,d=nearest_kind(db,rx_ident(simDR_radio_nav01_ID),B747_navdb.LOC,lat,lon)
  if not i then return false end
  local rec=db.nav[i]
  local st=B747_fmc_route
  local r=st.active and st.rte or nil
  local dest=r and r.dest and r.dest.ident
  local rwy=r and r.appr and r.appr.rwy
  local brg=B747_route_model.course(db.lat[i],db.lon[i],lat,lon)
  return NP.loc_ok({dest_rwy=dest~=nil and rwy~=nil and rec.terminal==dest and "RW"..(rec.runway or "")==rwy,
    alt_above=alt-(rec.elev or 0),dist=d,brg_from=brg,crs=rec.crs_true or 0,track=simDR_lnav_trk})
end
-- a CDU on POS REF page 2 (or 3)
local function cdu_on_pos_ref(page3)
  for _,id in ipairs({"fmsL","fmsC","fmsR"}) do
    local f=fmsModules[id]
    if f and f.inCustomFMC and f.currentPage=="POSINIT" and (f.pgNo==2 or (page3 and f.pgNo==3)) then return true end
  end
  return false
end
local function navperf_flag(key,arr,i,on)
  local v=on and 1 or 0
  if navperfFlags[key]~=v then
    navperfFlags[key]=v
    arr[i]=v
  end
end
function update_navperf()
  local now=simDRTime
  if navperfT and now-navperfT<1 and now>=navperfT then return end
  local dt=(navperfT and now>navperfT) and math.min(now-navperfT,5) or 0
  navperfT=now
  local db,N=B747_fmc_navdb,B747_navdb
  local inp,s=navperfIn,navperfState
  local lat,lon,alt=simDR_latitude,simDR_longitude,simDR_pressureAlt1
  inp.dt,inp.ground,inp.lat=dt,simDR_onGround==1,lat
  local _,_,_,irs=B747_fms_irs_pos()
  inp.irs=irs~=nil
  inp.gps_l,inp.gps_r=B747DR_nav_gps_valid[0]==1,B747DR_nav_gps_valid[1]==1
  if db.ready then
    if not ddT or now-ddT>=10 or now<ddT then
      ddT=now
      ddCands,inp.navaid_near=dd_scan(db,lat,lon,alt)
      ddPair=NP.dd_pair(ddCands,alt)
    elseif ddPair then
      ddPair=dd_refresh(ddPair,lat,lon,alt)
      if not ddPair then ddT=nil end
    end
    inp.dd=ddPair
    inp.vd=vd_find(db,lat,lon,alt)
    inp.loc=loc_find(db,lat,lon,alt)
  end
  local st=B747_fmc_route
  local r=st.active and st.rte or nil
  local dTerm=nil
  for _,a in ipairs(r and {r.origin or false,r.dest or false} or {}) do
    if a and a.lat then
      local d=N.distance(lat,lon,a.lat,a.lon)
      if not dTerm or d<dTerm then dTerm=d end
    end
  end
  inp.d_term=dTerm
  inp.approach=on_approach()
  local out=NP.update(s,inp)
  if s.purge and not cdu_on_pos_ref(false) then NP.purge_cancel(s) end
  if s.brg and not cdu_on_pos_ref(true) then s.brg=false end
  local irsLine=irs and ("IRS ("..irs..")") or ""
  if B747DR_ND_GPS_Line~=out.nd then B747DR_ND_GPS_Line=out.nd end
  if B747DR_ND_IRS_Line~=irsLine then B747DR_ND_IRS_Line=irsLine end
  navperf_flag("caution",B747DR_CAS_caution_status,UNABLE_RNP_CAUTION,out.caution)
  navperf_flag("advisory",B747DR_CAS_advisory_status,UNABLE_RNP_ADVISORY,out.advisory)
  navperf_flag("verify",B747DR_fmc_notifications,VERIFY_RNP,out.verify)
  navperf_flag("split",B747DR_fmc_notifications,SPLIT_IRS_OPERATION,out.polar)
end
-- (6-1/6-2 step 10b) the VOR and ADF tuning (B747.68.tune_model.lua;
-- notes/ATA-34-61-FMC.md §87). Once a second the FMC's stations for VOR
-- L and R (X-Plane's NAV 3 and 4) not manual: the active leg's procedure
-- navaid (a SID's, a STAR's, the approach's once on it with the final
-- course: FCOM p.1304), the active route's downpath and previous VORs
-- within 250 nm, the DME-DME pair's stations, else the nearest in reach;
-- NAV RADIO's entries for the manual ones and the ADFs. The tuning modes
-- (laminar/B747/radio/tuningmodes: ILS, VOR L, VOR R, ADF L, ADF R): P, R,
-- A, M for the VORs (the ND and the displays take any but M as
-- autotuned), M, A (ANT), B (BFO) for the ADFs (no ADF bearing in ANT:
-- B747.60.xt.displays.lua). Before, irs/rnav_system.lua tuned the two
-- nearest VORs every 10 s.
dofile("B747.68.tune_model.lua")
local TM=B747_tune_model
local tuneState=TM.new()
local tuneT=nil
function B747_fms_tune() return tuneState end
local VOR_IDX={2,3}
local function tune_station(p)
  return {ident=p.ident,freq=p.freq,lat=p.lat,lon=p.lon}
end
-- NAV RADIO's identifier: the nearest VOR or DME not an ILS's; false when
-- only another kind of point has it, nil when none
function B747_fms_tune_find(ident)
  local db,N=B747_fmc_navdb,B747_navdb
  if not db.ready then return nil end
  local best,bd,other=nil,nil,false
  local i=db.first[ident]
  while i do
    local k,rec=db.kind[i],db.nav[i]
    local ils=rec~=nil and rec.name~=nil and (string.find(rec.name,"ILS") or string.find(rec.name,"LOC"))
    if (k==N.VOR or k==N.DME) and rec and rec.freq and not ils then
      local d=N.distance(simDR_latitude,simDR_longitude,db.lat[i],db.lon[i])
      if not bd or d<bd then best,bd=i,d end
    else
      other=true
    end
    i=db.nxt[i]
  end
  if best then return {ident=db.ident[best],freq=db.nav[best].freq,lat=db.lat[best],lon=db.lon[best]} end
  if other or db.apt[ident] then return false end
  return nil
end
-- the procedure's navaid: the active leg's in a SID or STAR, or in the
-- approach once on it, a VOR or DME; the approach's runway leg's course
local function proc_navaids(r)
  local N=B747_navdb
  local l=r.legs[1]
  if not (l and l.proc) then return {} end
  if l.proc=="APPR" and not on_approach() then return {} end
  local nav=l.navaid
  if not (nav and (nav.kind==N.VOR or nav.kind==N.DME) and nav.freq) or tacan_only(nav) then return {} end
  local crs=nil
  if l.proc=="APPR" then
    for _,a in ipairs(r.legs) do
      if a.proc=="APPR" and a.fix and a.fix.kind=="RWY" and a.crs then crs=math.floor(a.crs+0.5)%360 break end
    end
  end
  return {{st=tune_station(nav),crs=crs}}
end
-- the route's VORs: the first downpath one within 250 nm, the previous one
-- (the last passed) within 250 nm
local function route_vors(r,lat,lon)
  local N=B747_navdb
  local nextVor,prevVor=nil,nil
  for j=1,math.min(#r.legs,40) do
    local f=r.legs[j].fix
    if f and f.kind==N.VOR and f.freq and not tacan_only(f) and N.distance(lat,lon,f.lat,f.lon)<=TM.ROUTE_NM then nextVor=tune_station(f) break end
  end
  for j=#r.passed,1,-1 do
    local f=r.passed[j].fix
    if f and f.kind==N.VOR and f.freq and not tacan_only(f) then
      if N.distance(lat,lon,f.lat,f.lon)<=TM.ROUTE_NM then prevVor=tune_station(f) end
      break
    end
  end
  return nextVor,prevVor
end
-- (6-1/6-2 step 10c; notes/ATA-34-61-FMC.md §88) the ILS: the active
-- route's approach runway's localizer at its destination (the FMC's
-- database), STBY within 200 nm of the T/D and past halfway (the direct
-- distances from the origin and to the destination: estimate), A within
-- 50 nm of the T/D, 150 nm of the runway threshold or in the descent, in
-- the air (estimate), not for ten minutes after lift-off unless the
-- destination runway changes (FCOM p.1305-1307); held under the FCCs'
-- ILS TUNE INHIBIT. ILS L, C and R are X-Plane's NAV 1 and 2 (frequency
-- and course); the PFDs' scales with the frequency tuned (FCOM p.987:
-- laminar/B747/autopilot/ils_dots; DSP-14: before, within 50 nm of the
-- destination). Before, the autopilot (B747_fltmgmt_setILS) tuned an ILS
-- near the destination from X-Plane's flight plan's geometry.
-- the ILS's messages (B744.notifications.lua's DRindex + 1)
local TUNE_INHIBITED,RW_ILS_CRS_ERROR=16,40
local ilsKey,ilsSt=nil,nil
local ilsLiftoff,ilsLiftoffKey,ilsWasGround=nil,nil,nil
local ilsIn={}
local ilsShown={}
-- (2026-11-12 review FMC-6) the approach's own localizer: the recommended
-- navaid of its legs that is a localizer (FCOM p.1306: the ILS of the
-- selected approach). Before, the runway's first localizer in the data: a
-- runway with two (EDDF 07L: IFEL and the approach's IFNE; KDTW, KORD) had
-- the other one tuned
local function appr_loc_ident(r)
  local N=B747_navdb
  for _,list in ipairs({r.passed or {},r.legs or {}}) do
    for _,l in ipairs(list) do
      if l.proc=="APPR" and l.navaid and l.navaid.kind==N.LOC then return l.navaid.ident end
    end
  end
  return nil
end
local function dest_ils(db,r)
  if not (r and r.dest and r.dest.lat and r.appr and r.appr.rwy) then return nil,nil end
  local want=appr_loc_ident(r)
  local key=r.dest.ident.." "..r.appr.rwy.." "..(want or "")
  if key~=ilsKey then
    ilsKey,ilsSt=key,nil
    local N=B747_navdb
    for _,e in ipairs(N.radio_near(db,r.dest.lat,r.dest.lon,8)) do
      local i=e.i
      local rec=db.nav[i]
      if db.kind[i]==N.LOC and rec.terminal==r.dest.ident and "RW"..(rec.runway or "")==r.appr.rwy and rec.freq then
        local st={ident=db.ident[i],freq=rec.freq,crs=(rec.crs_mag or 0)%360,lat=db.lat[i],lon=db.lon[i]}
        if not ilsSt then ilsSt=st end
        if want==nil or db.ident[i]==want then ilsSt=st break end
      end
    end
  end
  return ilsSt,key
end
local function ils_flag(key,on,fn)
  local v=on and 1 or 0
  if ilsShown[key]~=v then ilsShown[key]=v fn(on) end
end
local function update_ils(db)
  local N=B747_navdb
  local now=simDRTime
  local st=B747_fmc_route
  local r=st.active and st.rte or nil
  local il,key=nil,nil
  if db.ready then il,key=dest_ils(db,r) end
  local ground=simDR_onGround==1
  if ilsWasGround==true and not ground then ilsLiftoff,ilsLiftoffKey=now,key end
  ilsWasGround=ground
  if ilsLiftoff and (now-ilsLiftoff>=TM.TAKEOFF_S or key~=ilsLiftoffKey or now<ilsLiftoff) then ilsLiftoff=nil end
  local standby,auto=false,false
  if il then
    local lat,lon=simDR_latitude,simDR_longitude
    local td=B747_fms_vnav_td()
    local past=r.origin~=nil and r.origin.lat~=nil and N.distance(lat,lon,r.origin.lat,r.origin.lon)>N.distance(lat,lon,r.dest.lat,r.dest.lon)
    local thrLat,thrLon=il.lat,il.lon
    local c=N.cifp(db,r.dest.ident)
    local rw=c and c.runways and c.runways[r.appr.rwy]
    if rw then thrLat,thrLon=rw.lat,rw.lon end
    standby=td~=nil and td<TM.STANDBY_TD_NM and past
    auto=not ground and ((td~=nil and td<TM.AUTO_TD_NM) or N.distance(lat,lon,thrLat,thrLon)<TM.AUTO_THR_NM
      or B747_fms_vnav_phase()=="DES")
  end
  ilsIn.ils,ilsIn.standby,ilsIn.auto=il,standby,auto
  ilsIn.after_takeoff=ilsLiftoff~=nil
  ilsIn.inhibit=B747DR_fms_ils_tune_inhibit>0.5
  local o=TM.ils_update(tuneState,ilsIn)
  if o.tune and not ilsIn.inhibit then
    if simDR_nav1Freq~=o.tune.freq then simDR_nav1Freq=o.tune.freq end
    if simDR_nav2Freq~=o.tune.freq then simDR_nav2Freq=o.tune.freq end
    for i=0,1 do
      if math.abs(((simDR_radio_nav_obs_deg[i]-o.tune.crs)+180)%360-180)>0.5 then simDR_radio_nav_obs_deg[i]=o.tune.crs end
    end
  end
  local dots=o.tune and 1 or 0
  if B747DR_ils_dots~=dots then B747DR_ils_dots=dots end
  if o.held_change then B747DR_fmc_notifications[TUNE_INHIBITED]=1 end
  ils_flag("crs",o.crs_err,function(on) B747DR_fmc_notifications[RW_ILS_CRS_ERROR]=on and 1 or 0 end)
  ils_flag("freq",o.freq_err,function(on) B747_cdu_fmc_condition("RW/ILS FREQ ERROR",on,true) end)
  return o
end
-- NAV RADIO's ILS entry while the FCCs inhibit the tuning: the message
-- (an event: FCOM p.1432)
function B747_fms_ils_inhibited() B747DR_fmc_notifications[TUNE_INHIBITED]=1 end
function update_tuning()
  local now=simDRTime
  if tuneT and now-tuneT<1 and now>=tuneT then return end
  tuneT=now
  local db=B747_fmc_navdb
  local s=tuneState
  if db.ready then
    local st=B747_fmc_route
    local r=st.active and st.rte or nil
    local proc,nextVor,prevVor={},nil,nil
    if r then
      proc=proc_navaids(r)
      nextVor,prevVor=route_vors(r,simDR_latitude,simDR_longitude)
    end
    -- the position's stations: the DME-DME pair's, else (and in place of
    -- a TACAN of it) the nearest in reach; no TACAN alone (FCOM p.1303:
    -- A, a navaid for the position's orientation; a VOR receiver gets no
    -- bearing from a TACAN, X-Plane's NAV radio no identifier either:
    -- 2026-11-03, s69's VOR R on Wiesbaden's TACAN 114.10, the ND showing
    -- the frequency and no station)
    local auto={}
    local function add(c)
      if c and not c.tacan and #auto<2 then
        for _,a in ipairs(auto) do if a.ident==c.ident and a.freq==c.freq then return end end
        auto[#auto+1]=tune_station(c)
      end
    end
    if ddPair then add(ddPair.a) add(ddPair.b) end
    for j=1,#ddCands do add(ddCands[j]) end
    TM.choose(s,TM.candidates(proc,nextVor,prevVor,auto))
  end
  local o=update_ils(db)
  local modes=B747DR_radioModes
  if type(modes)~="string" or string.len(modes)<5 then modes="AAAMM" end
  modes=replace_char(1,modes,(o.mode=="A" or o.mode=="M") and o.mode or "P")
  for side=1,2 do
    local v,idx=s.vor[side],VOR_IDX[side]
    if v.st and v.st.freq and simDR_radio_nav_freq_hz[idx]~=v.st.freq then simDR_radio_nav_freq_hz[idx]=v.st.freq end
    if v.crs and math.abs(((simDR_radio_nav_obs_deg[idx]-v.crs)+180)%360-180)>0.5 then simDR_radio_nav_obs_deg[idx]=v.crs end
    modes=replace_char(side+1,modes,v.mode or "A")
    local a=s.adf[side].mode
    modes=replace_char(side+3,modes,a=="ANT" and "A" or (a=="BFO" and "B" or "M"))
  end
  if B747DR_radioModes~=modes then B747DR_radioModes=modes end
end
-- an entry's tuning at once
function B747_fms_tune_now() tuneT=nil update_tuning() end
-- (6-1/6-2 step 11b; notes/ATA-34-61-FMC.md §91) the landing altitude for
-- the cabin pressure controllers (B747.68.ldgalt_model.lua; FCOM p.1400,
-- p.993; ATA34_2 p.477): the active route's, once a second, into
-- laminar/B747/fms/landing_alt (ft) and landing_alt_valid (1 with one);
-- the pressurization (B747.55.xt.press.lua) reads them. The departure
-- runway's or the origin's elevation, from the arrivals page's switch point
-- the active approach's runway threshold or the destination's (the
-- runways' from the CIFP, the airports' from earth_aptmeta.dat). Before,
-- the pressurization took the route's airports from laminar/B747/fms/data
-- and their elevations, and switched at its own cruise.
dofile("B747.68.ldgalt_model.lua")
local LA=B747_ldgalt_model
local ldgState=LA.new()
local ldgIn={}
local ldgT=nil
B747DR_fms_landing_alt=find_dataref("laminar/B747/fms/landing_alt")
B747DR_fms_landing_alt_valid=find_dataref("laminar/B747/fms/landing_alt_valid")
local function rwy_ft(icao,id)
  if not (icao and id) then return nil end
  local c=B747_navdb.cifp(B747_fmc_navdb,icao)
  local rw=c and c.runways[id]
  return rw and rw.elev or nil
end
function update_ldgalt()
  local now=simDRTime
  if ldgT and now>=ldgT and now-ldgT<1 then return end
  ldgT=now
  local st=B747_fmc_route
  local r=st.active and st.rte or nil
  local ft=nil
  if r then
    local N=B747_navdb
    local inp=ldgIn
    local o,d=r.origin,r.dest
    local lat,lon=simDR_latitude,simDR_longitude
    inp.origin_ft=o and o.elev or nil
    inp.dep_rwy_ft=o and r.runway and r.runway.elev or nil
    inp.dest_ft=d and d.elev or nil
    inp.appr_rwy_ft=d and r.appr and rwy_ft(d.ident,r.appr.rwy) or nil
    inp.from_nm=o and o.lat and N.distance(o.lat,o.lon,lat,lon) or nil
    inp.to_nm=d and d.lat and N.distance(lat,lon,d.lat,d.lon) or nil
    inp.phase=vnavState.phase
    inp.td_nm=B747_fms_vnav_td()
    inp.gs_kt=simDR_groundspeed*1.94384
    inp.air=simDR_onGround==0
    ft=LA.update(ldgState,inp)
  end
  local valid=ft and 1 or 0
  if B747DR_fms_landing_alt_valid~=valid then B747DR_fms_landing_alt_valid=valid end
  if ft and B747DR_fms_landing_alt~=ft then B747DR_fms_landing_alt=ft end
end
-- (6-1/6-2 step 3d; notes/ATA-34-61-FMC.md §128) VREF 25 and 30 for the
-- gross weight (the FMC's; before PERF INIT the airplane's: estimate) and
-- the landing altitude (sea level without one: estimate) into
-- laminar/B747/fms/vref25 and vref30, for the PFDs' flap maneuver speeds
-- (B747.60.xt.speedtape.lua: FCOM p.1412 "for the current gross weight");
-- APPROACH REF works out its own for the weight it shows
-- (B744.fms.pages.approach.lua). Before, the flight instruments took the
-- airplane's weight and the present altitude.
dofile("B747.68.vref_model.lua")
B747DR_fms_vref25=find_dataref("laminar/B747/fms/vref25")
B747DR_fms_vref30=find_dataref("laminar/B747/fms/vref30")
simDR_fms_weight_kg=find_dataref("sim/flightmodel/weight/m_total")
-- the landing elevation (ft) VREF is for
function B747_fms_vref_elev()
  return B747DR_fms_landing_alt_valid==1 and B747DR_fms_landing_alt or 0
end
function update_vref()
  local gw=perf_gw_t()
  local kg=gw and gw*1000 or simDR_fms_weight_kg
  local elev=B747_fms_vref_elev()
  local v25=B747_vref_model.vref(25,kg,elev)
  local v30=B747_vref_model.vref(30,kg,elev)
  if B747DR_fms_vref25~=v25 then B747DR_fms_vref25=v25 end
  if B747DR_fms_vref30~=v30 then B747DR_fms_vref30=v30 end
end
-- (6-1/6-2 step 11c1; notes/ATA-34-61-FMC.md §93) the FMC's alerts held
-- below 500 ft AGL in the approach phase with a runway in the active
-- route, shown again after climbing through 1,000 ft AGL or at the flight
-- completion (ATA34_2 p.635; B747_cdu_fmc_inhibit). The approach phase
-- (FCOM p.1236): the approach's first waypoint sequenced, or the runway
-- the active waypoint within 25 NM. Estimate: the runway an approach's or
-- a runway waypoint.
local MSG_INHIBIT_FT,MSG_RELEASE_FT,APPR_RWY_NM=500,1000,25
local msgInhibit=false
local function route_runway(r)
  if r.appr and r.appr.rwy then return true end
  for _,l in ipairs(r.legs) do
    if l.fix and l.fix.kind=="RWY" then return true end
  end
  return false
end
local function approach_phase(r)
  for _,l in ipairs(r.passed) do
    if l.proc=="APPR" then return true end
  end
  local f=r.legs[1] and r.legs[1].fix
  return f~=nil and f.kind=="RWY" and B747_navdb.distance(simDR_latitude,simDR_longitude,f.lat,f.lon)<APPR_RWY_NM
end
function update_msg_inhibit()
  local ra=simDR_fms_radio_alt
  local air=simDR_onGround==0
  if msgInhibit then
    if air and ra>MSG_RELEASE_FT then msgInhibit=false end
  elseif air and ra<MSG_INHIBIT_FT then
    local st=B747_fmc_route
    if st.active and route_runway(st.rte) and approach_phase(st.rte) then msgInhibit=true end
  end
  B747_cdu_fmc_inhibit(msgInhibit)
end
-- (6-1/6-2 step 11c3; notes/ATA-34-61-FMC.md §96) the navigation alerts
-- (FCOM p.1433-1434), once a second: SET CLOCK TO UTC TIME (flag 41: a GPS
-- valid and its UTC, X-Plane's, more than 12 s off the Captain's clock,
-- the F/O's while the Captain's has no power: fltInst/<side>/
-- clock_utc_offset, clock_valid), IRS POS/ORIGIN DISAGREE (flag 23: on the
-- ground the IRS position valid and more than ORIGIN_NM from the active
-- route's origin), NAV INVALID-TUNE AAA (on approach the approach's VOR,
-- its legs' recommended navaid, received by neither VOR receiver for
-- NAV_INVALID_S). Estimates: ORIGIN_NM (the sources give none), the IRS
-- position the FMC's mix (B747_fms_irs_pos), NAV_INVALID_S. VERIFY
-- POSITION and PURGE UPDATES - POS 2 not made: the FMC's position here is
-- X-Plane's, no updating sensor disagrees with it.
local CLOCK_TOL_S,ORIGIN_NM,NAV_INVALID_S=12,10,5
local SET_CLOCK,IRS_ORIGIN=41,23
B747DR_fms_clock_capt_offset=find_dataref("laminar/B747/fltInst/capt/clock_utc_offset")
B747DR_fms_clock_capt_valid=find_dataref("laminar/B747/fltInst/capt/clock_valid")
B747DR_fms_clock_fo_offset=find_dataref("laminar/B747/fltInst/fo/clock_utc_offset")
B747DR_fms_clock_fo_valid=find_dataref("laminar/B747/fltInst/fo/clock_valid")
local navMsgFlags,navMsgT={},nil
local navInvalidText,navInvalidSince=nil,nil
local function nav_msg_flag(i,on)
  local v=on and 1 or 0
  if navMsgFlags[i]~=v then
    navMsgFlags[i]=v
    B747DR_fmc_notifications[i]=v
  end
end
-- the approach's VOR on approach: its legs' recommended navaid ahead
local function approach_vor(r)
  local N=B747_navdb
  if not on_approach() then return nil end
  for _,l in ipairs(r.legs) do
    local nav=l.proc=="APPR" and not l.missed and l.navaid or nil
    if nav and (nav.kind==N.VOR or nav.kind==N.DME) and nav.ident then return nav end
  end
  return nil
end
function update_nav_msgs()
  local now=simDRTime
  if navMsgT and now>=navMsgT and now-navMsgT<1 then return end
  navMsgT=now
  -- SET CLOCK TO UTC TIME
  local gps=B747DR_nav_gps_valid[0]==1 or B747DR_nav_gps_valid[1]==1
  local off=nil
  if B747DR_fms_clock_capt_valid==1 then off=B747DR_fms_clock_capt_offset
  elseif B747DR_fms_clock_fo_valid==1 then off=B747DR_fms_clock_fo_offset end
  nav_msg_flag(SET_CLOCK,gps and off~=nil and math.abs(off)>CLOCK_TOL_S)
  -- IRS POS/ORIGIN DISAGREE
  local st=B747_fmc_route
  local o=st.active and st.rte.origin or nil
  local far=false
  if simDR_onGround==1 and o and o.lat then
    local lat,lon=B747_fms_irs_pos()
    far=lat~=nil and B747_navdb.distance(lat,lon,o.lat,o.lon)>ORIGIN_NM
  end
  nav_msg_flag(IRS_ORIGIN,far)
  -- NAV INVALID-TUNE AAA
  local nav=st.active and approach_vor(st.rte) or nil
  local text=nil
  if nav and rx_ident(simDR_radio_nav03_ID)~=nav.ident and rx_ident(simDR_radio_nav04_ID)~=nav.ident then
    navInvalidSince=navInvalidSince or now
    if now-navInvalidSince>=NAV_INVALID_S then text="NAV INVALID-TUNE "..nav.ident end
  else
    navInvalidSince=nil
  end
  navInvalidText=fmc_alt_message(navInvalidText,text)
end
-- (6-1/6-2 step 11d1; notes/ATA-34-61-FMC.md §98) the two FMCs
-- (B747.68.fmc_link_model.lua): each frame their power (the left on the
-- Captain's transfer bus or the APU standby bus, the right on the F/O's:
-- FCOM p.800, p.804) and failure (laminar/B747/fms/fail[0], [1]: the
-- failure injection), the CDUs' power, the NAV source selectors and the
-- FMC master selector; fmc_ok and cdu_link out. A CDU whose FMC goes: the
-- MENU page and TIMEOUT - RESELECT (B744.createfms.lua's
-- B747_cdu_fmc_lost); SINGLE FMC OPERATION while one works (FCOM p.1275,
-- p.1434); FMC LEFT, RIGHT on the EICAS after a delay (p.1275, p.1429).
-- Before, one FMC that could not fail
-- (in a block: the main chunk's 200 locals; B747_fms_any_fmc for the rest)
do
dofile("B747.68.fmc_link_model.lua")
local FL=B747_fmc_link_model
local fmcLink=FL.new()
local fmcIn={power={true,true},fail={false,false},src={},cdu_power={},master=FL.L,ground=true}
B747DR_fms_fail=find_dataref("laminar/B747/fms/fail")
B747DR_fms_fmc_ok=find_dataref("laminar/B747/fms/fmc_ok")
B747DR_fms_cdu_link=find_dataref("laminar/B747/fms/cdu_link")
B747DR_fms_bus_xfr_capt=find_dataref("laminar/B747/electrical/bus/xfr_capt")
B747DR_fms_bus_xfr_fo=find_dataref("laminar/B747/electrical/bus/xfr_fo")
B747DR_fms_bus_stby_apu=find_dataref("laminar/B747/electrical/bus/stby_apu")
B747DR_fms_nav_src_capt=find_dataref("laminar/B747/flt_inst/nav_src/capt/sel_dial_pos")
B747DR_fms_nav_src_fo=find_dataref("laminar/B747/flt_inst/nav_src/fo/sel_dial_pos")
B747DR_fms_fmc_master=find_dataref("laminar/B747/flt_inst/fmc_master_src/ctr_pnl/sel_dial_pos")
-- the NAV source selectors' FMC positions (FCOM p.1043; B747.60.xt.displays.lua):
-- Captain FMC L, FMC R, CDU L, CDU C; F/O CDU C, CDU R, FMC L, FMC R
local NAV_SRC_CAPT={[0]=FL.L,[1]=FL.R}
local NAV_SRC_FO={[2]=FL.L,[3]=FL.R}
local SINGLE_FMC=42
local RESYNC_FAIL_FMC,RESYNCING_FMC=35,36
local ADV_FMC_LEFT,ADV_FMC_RIGHT=144,146
local CDU_LINK_INDEX={fmsL=0,fmsC=1,fmsR=2}
local singleFMC,resyncingFMC,resyncFailFMC=nil,nil,nil
local function anyFMC() return fmcLink.ok[FL.L] or fmcLink.ok[FL.R] end
-- an FMC working (>FMC MESSAGE: setNotifications)
function B747_fms_any_fmc() return anyFMC() end
-- (1-1) an FMC's bus powered, the FMC failed or not: the left FMC's the
-- Captain's transfer bus or the APU standby bus, the right FMC's the F/O's
-- transfer bus (FCOM p.800, p.804; update_fmc_link)
function B747_fms_bus_powered() return fmcIn.power[FL.L] or fmcIn.power[FL.R] end
function update_fmc_link()
  local inp=fmcIn
  inp.power[FL.L]=B747DR_fms_bus_xfr_capt>0.5 or B747DR_fms_bus_stby_apu>0.5
  inp.power[FL.R]=B747DR_fms_bus_xfr_fo>0.5
  -- (step 11d3: 2 and 3 an internal test's failure and the resync)
  inp.fail[FL.L]=math.floor(B747DR_fms_fail[0]+0.5)
  inp.fail[FL.R]=math.floor(B747DR_fms_fail[1]+0.5)
  inp.src.fmsL=NAV_SRC_CAPT[math.floor(B747DR_fms_nav_src_capt+0.5)]
  inp.src.fmsR=NAV_SRC_FO[math.floor(B747DR_fms_nav_src_fo+0.5)]
  inp.master=B747DR_fms_fmc_master>0.5 and FL.R or FL.L
  inp.ground=simDR_onGround==1
  for _,cdu in ipairs(FL.CDUS) do inp.cdu_power[cdu]=cduPowered(cdu) end
  local out=FL.update(fmcLink,inp,SIM_PERIOD)
  for i=1,2 do
    local v=out.ok[i] and 1 or 0
    if B747DR_fms_fmc_ok[i-1]~=v then B747DR_fms_fmc_ok[i-1]=v end
  end
  for cdu,k in pairs(CDU_LINK_INDEX) do
    local v=fmcLink.link[cdu] or 0
    if B747DR_fms_cdu_link[k]~=v then B747DR_fms_cdu_link[k]=v end
    if out.lost[cdu] then B747_cdu_fmc_lost(cdu) end
  end
  if out.single~=singleFMC then
    singleFMC=out.single
    B747DR_fmc_notifications[SINGLE_FMC]=out.single and 1 or 0
  end
  -- (step 11d3) RESYNCING OTHER FMC, RESYNC FAIL - SINGLE FMC (FCOM
  -- p.1433-1434)
  if out.resyncing~=resyncingFMC then
    resyncingFMC=out.resyncing
    B747DR_fmc_notifications[RESYNCING_FMC]=out.resyncing and 1 or 0
  end
  if out.resync_fail~=resyncFailFMC then
    resyncFailFMC=out.resync_fail
    B747DR_fmc_notifications[RESYNC_FAIL_FMC]=out.resync_fail and 1 or 0
  end
  local l,r=out.eicas[FL.L] and 1 or 0,out.eicas[FL.R] and 1 or 0
  if B747DR_CAS_advisory_status[ADV_FMC_LEFT]~=l then B747DR_CAS_advisory_status[ADV_FMC_LEFT]=l end
  if B747DR_CAS_advisory_status[ADV_FMC_RIGHT]~=r then B747DR_CAS_advisory_status[ADV_FMC_RIGHT]=r end
end
-- MENU's <FMC (B744.createfms.lua): the FMC it connects the CDU to, nil
-- without one; the FMC it would; the CDU connected
function B747_fms_fmc_connect(cdu) return FL.connect(fmcLink,cdu,fmcIn) end
function B747_fms_fmc_available(cdu) return FL.available(fmcLink,cdu,fmcIn) end
function B747_fms_fmc_linked(cdu) return FL.linked(fmcLink,cdu) end
-- (step 11d3) the CDU's FMC being resynchronized: its display frozen, no
-- keys (FCOM p.1277)
function B747_fms_fmc_frozen(cdu) return FL.frozen(fmcLink,cdu) end
-- (6-1/6-2 step 11e1; notes/ATA-34-61-FMC.md §102) the CDUs' alternate
-- navigation (B747.68.altn_nav_model.lua): each second, while an FMC
-- works, each CDU's copy of the active route (the FMC sends it at each
-- change: FMSPG p.248); with both failed each CDU's route sequenced on its
-- own IRU (left, centre, right: FCOM p.1421)
dofile("B747.68.altn_nav_model.lua")
local AN=B747_altn_nav_model
local altnNav={fmsL=AN.new(),fmsC=AN.new(),fmsR=AN.new()}
local ALTN_IRU={fmsL=0,fmsC=1,fmsR=2}
local altnT=nil
function B747_fms_altn(cdu) return altnNav[cdu] or altnNav.fmsL end
-- that CDU's IRU position and ground speed, nil without one
function B747_fms_altn_pos(cdu)
  local n=ALTN_IRU[cdu] or 0
  if B747DR_nav_irs_nav_valid[n]~=1 then return nil end
  return {lat=B747DR_nav_irs_lat[n],lon=B747DR_nav_irs_lon[n],gs=B747DR_nav_irs_gs[n]}
end
-- a CDU's IRS LEGS modification waiting (its EXEC light)
function B747_fms_altn_mod(cdu) return altnNav[cdu]~=nil and altnNav[cdu].mod~=nil end
-- (step 11e3) ALTN NAV RADIO (B747.68.altn_radio_model.lua): while the
-- master FMC works each CDU's copy of its side's tuning (FMSPG p.252);
-- with no FMC to connect to, its entries tune its side's radios at once
-- (FCOM p.1422): the left CDU VOR L (NAV3) with its DME, ADF L, ILS L
-- (NAV1); the right CDU VOR R (NAV4), ADF R, ILS R (NAV2); the centre
-- CDU's centre ILS X-Plane does not have (not tuned: estimate)
dofile("B747.68.altn_radio_model.lua")
local AR=B747_altn_radio_model
local altnRadio={fmsL=AR.new(),fmsC=AR.new(),fmsR=AR.new()}
local RADIO_SIDE={fmsL=1,fmsR=2}
function B747_fms_altn_radio(cdu) return altnRadio[cdu] or altnRadio.fmsL end
function B747_fms_altn_side(cdu) return RADIO_SIDE[cdu] end
-- the FMC's ILS's course (the active route's runway's: estimate), nil
-- without one
function B747_fms_altn_rwy_crs()
  local o=B747_fms_tune().ils_out
  return o and o.st and o.st.crs or nil
end
local function altn_radio_copy(cdu,s)
  local side=RADIO_SIDE[cdu] or 1
  local t=B747_fms_tune()
  local khz=side==1 and simDR_radio_adf1_freq_hz or simDR_radio_adf2_freq_hz
  local o=t.ils_out
  local ils=o and (o.mode=="A" or o.mode=="M") and o.st or nil
  AR.copy(s,{vor_freq=simDR_radio_nav_freq_hz[side+1],vor_crs=t.vor[side].crs,
    adf_khz=(khz and khz>0) and khz or nil,adf_mode=t.adf[side].mode,
    ils_freq=ils and ils.freq or nil,ils_crs=ils and ils.crs or nil})
end
function B747_fms_altn_radio_copy()
  for cdu,s in pairs(altnRadio) do altn_radio_copy(cdu,s) end
end
-- a CDU's ALTN NAV RADIO into its side's radios
function B747_fms_altn_tune(cdu)
  local side=RADIO_SIDE[cdu]
  if not side then return end
  local s=altnRadio[cdu]
  local vidx,iidx=side+1,side-1
  if s.vor.freq and simDR_radio_nav_freq_hz[vidx]~=s.vor.freq then simDR_radio_nav_freq_hz[vidx]=s.vor.freq end
  if s.vor.crs then simDR_radio_nav_obs_deg[vidx]=s.vor.crs end
  if s.adf.khz then
    local k=math.floor(s.adf.khz)
    if side==1 then simDR_radio_adf1_freq_hz=k else simDR_radio_adf2_freq_hz=k end
  end
  if s.ils.freq then
    if simDR_radio_nav_freq_hz[iidx]~=s.ils.freq then simDR_radio_nav_freq_hz[iidx]=s.ils.freq end
    simDR_radio_nav_obs_deg[iidx]=s.ils.crs or 0
  end
  local modes=B747DR_radioModes
  if type(modes)~="string" or string.len(modes)<5 then modes="AAAMM" end
  local ilsOn=altnRadio.fmsL.ils.freq~=nil or altnRadio.fmsR.ils.freq~=nil
  modes=replace_char(1,modes,ilsOn and "M" or "P")
  modes=replace_char(side+1,modes,"M")
  local a=s.adf.mode
  modes=replace_char(side+3,modes,a=="ANT" and "A" or (a=="BFO" and "B" or "M"))
  if B747DR_radioModes~=modes then B747DR_radioModes=modes end
  -- the PFDs' ILS scales with an ILS tuned (step 10c's)
  local dots=ilsOn and 1 or 0
  if B747DR_ils_dots~=dots then B747DR_ils_dots=dots end
end
-- (step 11e2) IRS PROGRESS: that CDU's IRU ("L", "C", "R") and track
-- (magnetic: X-Plane's ground track, the F/O's for the right CDU: estimate)
simDR_altn_trk_pilot=find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
simDR_altn_trk_copilot=find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_copilot")
local ALTN_IRU_NAME={fmsL="L",fmsC="C",fmsR="R"}
function B747_fms_altn_iru(cdu) return ALTN_IRU_NAME[cdu] or "L" end
function B747_fms_altn_track(cdu) return cdu=="fmsR" and simDR_altn_trk_copilot or simDR_altn_trk_pilot end
-- the frames (step 11e2: IRS PROGRESS's page left when it missed one)
local altnFrame=0
function B747_fms_frame_no() return altnFrame end
function update_altn_nav()
  altnFrame=altnFrame+1
  local now=simDRTime
  if altnT and now>=altnT and now-altnT<1 then return end
  altnT=now
  local st=B747_fmc_route
  -- (step 11e3) the radios' tuning from the master FMC
  if B747_fms_master_ok() then B747_fms_altn_radio_copy() end
  for cdu,s in pairs(altnNav) do
    if anyFMC() then
      if st.active then
        AN.copy(s,st.rte,B747_route_model.is_hold,B747_fms_altn_pos(cdu))
      else
        s.legs,s.dest,s.mod=AN.new().legs,nil,nil
      end
    else
      AN.sequence(s,B747_fms_altn_pos(cdu),simDR_pressureAlt1)
    end
  end
end
-- (6-1/6-2 step 11d2) the FMC the FMC master selector selects working: the
-- radios' tuning is its (ATA34_2 p.496; ATA34_1 p.332, p.350: held at the
-- last frequencies without it)
function B747_fms_master_ok() return fmcLink.ok[fmcIn.master] end
end
-- (6-1/6-2 step 12c2; notes/ATA-34-61-FMC.md §110) IRS MONITOR (FMSPG
-- p.269; ATA34_2 p.682): each IRU's position error rate for the flight,
-- NM/HR: the change of the IRU's position from the FMC's (X-Plane's
-- position: the FMC's here) between the liftoff and the flight's
-- completion, over the time between; shown about 45 s after the engines'
-- shutdown (the completion's 30 s and 15 more), cleared in the air and
-- when no FMC works (its power cycled: estimate). An IRU not navigating
-- at either end: none (estimate)
do
  local IRS_MON_SHOW_S = 15
  local liftT, liftOff = nil, nil
  local monShow, monRates = nil, nil
  local wasGround = nil
  -- each IRU's position from the FMC's: {NM north, NM east}, or false
  local function irs_offsets()
    local out = {}
    local k = math.cos(math.rad(simDR_latitude))
    for i = 0, 2 do
      if B747DR_nav_irs_nav_valid[i] > 0.5 then
        out[i + 1] = {(B747DR_nav_irs_lat[i] - simDR_latitude) * 60,
          ((B747DR_nav_irs_lon[i] - simDR_longitude + 540) % 360 - 180) * 60 * k}
      else
        out[i + 1] = false
      end
    end
    return out
  end
  -- each frame: the liftoff
  function B747_fms_irs_monitor_update()
    local g = simDR_onGround == 1
    if wasGround and not g then
      liftT, liftOff = simDRTime, irs_offsets()
      monShow, monRates = nil, nil
    end
    wasGround = g
    if monRates and not B747_fms_any_fmc() then monShow, monRates = nil, nil end
  end
  -- the flight's completion
  function B747_fms_irs_monitor_complete()
    if not liftT then return end
    local hrs = (simDRTime - liftT) / 3600
    local now = irs_offsets()
    local rates = {}
    for i = 1, 3 do
      local a, b = liftOff[i], now[i]
      rates[i] = (a and b and hrs > 0) and math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2) / hrs or false
    end
    monShow, monRates = simDRTime + IRS_MON_SHOW_S, rates
    liftT, liftOff = nil, nil
  end
  -- the rates (NM/HR; false: none) once shown, else nil
  function B747_fms_irs_monitor()
    if monRates and simDRTime >= monShow then return monRates end
    return nil
  end
end
-- (6-1/6-2 step 12d1; notes/ATA-34-61-FMC.md §111) the datalink's EICAS
-- messages (FCOM p.725, p.775-776): with the FMC's datalink (405, 570:
-- B747_fms_datalink) ATC MESSAGE for an unread ATC uplink (cpdlc) and a
-- low chime as one comes (laminar/B747/fms/atc_chime: the .snd's cockpit
-- chime, an estimate), ACARS MESSAGE for an unread ACARS message (telex);
-- without it ACARS MESSAGE for any. >DATALINK LOST while the ACARS
-- provider is not connected after it was (a loss; nothing before the first
-- connection: estimate), >DATALINK AVAIL for DL_AVAIL_S when it is again
-- (estimate). No ACARS NO COMM memo (not the FCOM's); >DATALINK SYS never
-- (no ACARS failure here)
B747DR_fms_atc_chime=find_dataref("laminar/B747/fms/atc_chime")
do
  local DL_AVAIL_S, CHIME_S = 60, 1
  local MEMO_ACARS, MEMO_NO_COMM, MEMO_ATC = 0, 40, 46
  local ADV_DL_AVAIL, ADV_DL_LOST = 55, 56
  local hadOnline, lost, availT = false, false, nil
  local atcUnreadWas, chimeT = 0, nil
  local acarsUnread = false
  local function put(arr, i, v) if arr[i] ~= v then arr[i] = v end end
  -- (step 12d2) an unread ACARS message: MENU's <REQ>
  function B747_fms_acars_unread() return acarsUnread end
  function B747_fms_datalink_eicas(online)
    local now = simDRTime
    -- the unread messages
    local dl = B747_fms_datalink()
    local acarsNew, atcNew = 0, 0
    for i = table.getn(acarsSystem.messages.values), 1, -1 do
      local m = acarsSystem.messages[i]
      if not m["read"] then
        if dl and m["type"] == "cpdlc" then atcNew = atcNew + 1 else acarsNew = acarsNew + 1 end
      end
    end
    acarsUnread = acarsNew > 0
    put(B747DR_CAS_memo_status, MEMO_ACARS, acarsNew > 0 and 1 or 0)
    put(B747DR_CAS_memo_status, MEMO_ATC, atcNew > 0 and 1 or 0)
    put(B747DR_CAS_memo_status, MEMO_NO_COMM, 0)
    if atcNew > atcUnreadWas then chimeT = now end
    atcUnreadWas = atcNew
    local chime = (chimeT and now - chimeT < CHIME_S) and 1 or 0
    if B747DR_fms_atc_chime ~= chime then B747DR_fms_atc_chime = chime end
    -- the connection
    if online then
      if lost then availT = now end
      hadOnline, lost = true, false
    elseif hadOnline then
      lost, availT = true, nil
    end
    put(B747DR_CAS_advisory_status, ADV_DL_LOST, lost and 1 or 0)
    put(B747DR_CAS_advisory_status, ADV_DL_AVAIL, (availT and now - availT < DL_AVAIL_S) and 1 or 0)
  end
end
-- (6-1/6-2 step 12e; notes/ATA-34-61-FMC.md §113) the ATC logon
-- (B747.68.atc_logon_model.lua) over the ACARS provider, AutoATC's protocol
-- kept (acars/autoatcProvider.lua): SEND sends its REQUEST LOGON to the
-- facility (fmsModules data "atc" its address while a logon or ATC COMM
-- goes on, "****" otherwise); the network's acknowledgement while the
-- provider is connected (estimate); its LOGON ACCEPTED the AFN acceptance
-- and the connection request together (one message there: estimate);
-- LOGON REJECTED or an UNABLE during a logon the rejection (estimate); its
-- SERVICE TERMINATED the end of ATC COMM (during its transfer to NEXT CTR,
-- as before, no message: the new connection's ATC COMM ESTABLISHED); SELECT
-- OFF its LOGOFF; NEXT CTR its data. No departure or destination needed
-- (before, DEPARTURE and DESTINATION NOT SET, not Boeing's). The tail
-- number the FMC's database's (X-Plane's tail number) until one is entered
-- (VERIFY TAIL NUMBER when it differs: FCOM p.1436); the position valid
-- with an IRU or a GPS navigating
dofile("B747.68.atc_logon_model.lua")
simDR_fms_tailnum = find_dataref("sim/aircraft/view/acf_tailnum")
B747DR_fms_atc_irs_nav = find_dataref("laminar/B747/irs/nav_valid")
B747DR_fms_atc_gps_valid = find_dataref("laminar/B747/gps/valid")
do
  local A = B747_atc_logon_model
  local logon = A.new()
  local tailEntered = nil
  local seenMsgs = 0
  local function post(msgs)
    for _, m in ipairs(msgs) do B747_cdu_fmc_event(m, true) end
  end
  local function pending() return logon.status == "SENDING" or logon.status == "SENT" end
  function B747_fms_atc_logon() return logon end
  -- the FMC's database's tail number (X-Plane's, its letters and digits)
  function B747_fms_tail_db()
    local t = simDR_fms_tailnum
    if type(t) ~= "string" then return "" end
    return string.sub((string.gsub(t, "[^%w]", "")), 1, 7)
  end
  function B747_fms_tail() return tailEntered or B747_fms_tail_db() end
  -- TAIL NO's entry, one to seven letters and digits: nil or the message
  function B747_fms_tail_enter(text)
    if not string.match(text, "^%w+$") or #text > 7 then return "INVALID ENTRY" end
    tailEntered = text
    if text ~= B747_fms_tail_db() then return "VERIFY TAIL NUMBER" end
    return nil
  end
  function B747_fms_flt_ok()
    local f = str_trim(getFMSData("fltno"))
    return f ~= "" and not string.find(f, "^%-+$")
  end
  function B747_fms_atc_ready() return acarsSystem.provider.online() end
  local function pos_ok()
    for i = 0, 2 do if B747DR_fms_atc_irs_nav[i] > 0.5 then return true end end
    return B747DR_fms_atc_gps_valid[0] > 0.5 or B747DR_fms_atc_gps_valid[1] > 0.5
  end
  -- the page's fields (B747_atc_logon_model.view)
  function B747_fms_atc_view()
    return A.view(logon, {flt_ok = B747_fms_flt_ok(), ready = B747_fms_atc_ready(), pos_ok = pos_ok(),
      tail_ok = B747_fms_tail() ~= ""})
  end
  -- ATC COMM ended by the crew or with a logon elsewhere: the provider's
  -- LOGOFF
  local function logoff(msgs)
    acarsSystem.provider.logoff()
    setFMSData("atc", "****")
    post(msgs)
  end
  -- SEND> or RESEND>: false when not shown
  function B747_fms_atc_send(fmsO)
    if not A.send(logon, simDRTime, B747_fms_flt_ok(), B747_fms_atc_ready()) then return false end
    if logon.comm and logon.act ~= logon.sent_ctr then logoff(A.terminate(logon, false)) end
    setFMSData("atc", logon.sent_ctr)
    fmsFunctions.acarsSystemSendATC(fmsO, json.encode({type = "cpdlc", msg = "REQUEST LOGON", RR = "Y"}))
    return true
  end
  -- a logon by the other pages and the provider (acarsLogonATC: a four
  -- letter facility; anything else a logoff)
  function B747_fms_atc_logon_to(fmsO, ctr)
    if logon.comm and logon.act == ctr then return end
    if A.enter_ctr(logon, ctr or "") then B747_fms_atc_off() return end
    -- the provider's transfer: the old connection already ended there
    if logon.comm and getFMSData("atc") == "****" then logon.comm, logon.act, logon.next = false, nil, nil end
    B747_fms_atc_send(fmsO)
  end
  -- ATC COMM SELECT OFF
  function B747_fms_atc_off()
    if logon.comm then logoff(A.terminate(logon, false)) end
  end
  -- a new flight number (RTE, LOGON/STATUS)
  function B747_fms_atc_new_flight()
    local was = logon.comm or pending()
    if logon.comm then acarsSystem.provider.logoff() end
    local msgs = A.new_flight(logon)
    if was then setFMSData("atc", "****") end
    post(msgs)
  end
  -- each frame: the provider's ATC messages since the last, the timers
  function B747_fms_atc_update()
    local ready = B747_fms_atc_ready()
    if ready then A.ack(logon) end
    local n = table.getn(acarsSystem.messages.values)
    if n < seenMsgs then seenMsgs = 0 end
    for i = seenMsgs + 1, n do
      local m = acarsSystem.messages[i]
      if m["type"] == "cpdlc" then
        local title = m["title"] or ""
        if title == "LOGON ACCEPTED" and pending() then
          local ctr = logon.sent_ctr
          post(A.response(logon, true))
          setFMSData("atc", ctr)
          post({A.connect(logon, ctr)})
        elseif title == "SERVICE TERMINATED" then
          if pending() then
            logon.comm, logon.act, logon.next = false, nil, nil
          else
            setFMSData("atc", "****")
            post(A.terminate(logon, false))
          end
        elseif (title == "LOGON REJECTED" or string.find(title, "^UNABLE")) and pending() then
          setFMSData("atc", "****")
          post(A.response(logon, false))
        end
      end
    end
    seenMsgs = n
    local nx = str_trim(getFMSData("nextCTR"))
    A.set_next(logon, (string.match(nx, "^%a%a%a%a$") and nx ~= "****") and nx or nil)
    local msgs = A.update(logon, simDRTime, ready)
    if not logon.comm and not pending() and getFMSData("atc") ~= "****" then setFMSData("atc", "****") end
    post(msgs)
  end
end
-- (6-1/6-2 step 12f; notes/ATA-34-61-FMC.md §114) the ATC uplinks
-- (B747.68.atc_uplink_model.lua): the provider's ATC messages (cpdlc) in
-- its received list, each one's response state kept here by its place in
-- the list (reviewed: the message's read, as the ATC MESSAGE memo's);
-- the responses through the provider as before (cpdlc, RT the uplink's
-- ID), the network's acknowledgement while it is connected (estimate);
-- the pending ones ABORTED when ATC COMM ends; the CDUs' VERIFY RESPONSE
-- (the response chosen) and REJECT DUE TO (the reasons, the free text)
dofile("B747.68.atc_uplink_model.lua")
dofile("B747.68.atc_log_model.lua")
do
  local U = B747_atc_uplink_model
  local ul = {}
  local verify = {}
  local due = {}
  local wasComm, lastN = false, 0
  -- (step 12g1) the ATC LOG's order (each uplink when first seen, each
  -- downlink when sent) and the downlinks sent from here; (step 12g2a) the
  -- downlinks' pending states (FCOM p.753-754)
  local seq = 0
  local down = {}
  local scanned = 0
  local DOWN_PENDING = {SENDING = true, OPEN = true, DEFERRED = true}
  local function msg(i) return acarsSystem.messages[i] end
  -- a message's field (its namespace table cannot read a missing key)
  local function field(m, k)
    local v = rawget(m, "values")
    if type(v) == "table" then return v[k] end
    return rawget(m, k)
  end
  -- a message's field by its place (the pages)
  function B747_fms_atc_msg_field(i, k) return field(msg(i), k) end
  -- the provider's connection messages (step 12e: the logon's), not uplinks
  local CONNECTION = {["LOGON ACCEPTED"] = true, ["LOGON REJECTED"] = true, ["SERVICE TERMINATED"] = true}
  -- an uplink's state by its place (nil: not an ATC uplink)
  function B747_fms_atc_uplink(i)
    if type(i) ~= "number" or i < 1 or i > table.getn(acarsSystem.messages.values) then return nil end
    local m = msg(i)
    if field(m, "type") ~= "cpdlc" or CONNECTION[field(m, "title") or ""] then return nil end
    local s = ul[i]
    if not s then
      seq = seq + 1
      s = {resp = U.response(field(m, "msg") or ""), sent = nil, acked = nil, aborted = false,
        seq = seq, deleted = false}
      ul[i] = s
    end
    s.read = field(m, "read") == true
    return s
  end
  -- the uplinks in order, not deleted: {i = place, s = state}
  local function uplinks()
    local out = {}
    for i = 1, table.getn(acarsSystem.messages.values) do
      local s = B747_fms_atc_uplink(i)
      if s and not s.deleted then out[#out + 1] = {i = i, s = s} end
    end
    return out
  end
  -- (step 12g1) the ATC LOG's entries (B747.68.atc_log_model.lua): {seq,
  -- up, time, text, status, pending, i (an uplink's place), d (a
  -- downlink's)}
  function B747_fms_atc_log_entries()
    local out = {}
    for _, u in ipairs(uplinks()) do
      out[#out + 1] = {seq = u.s.seq, up = true, i = u.i, time = string.gsub(field(msg(u.i), "time") or "", ":", ""),
        text = field(msg(u.i), "msg") or "", status = U.status(u.s), pending = U.pending(u.s)}
    end
    for _, d in ipairs(down) do
      if not d.deleted then
        out[#out + 1] = {seq = d.seq, up = false, d = d, time = d.time, text = d.text, status = d.status,
          pending = DOWN_PENDING[d.status] == true}
      end
    end
    return out
  end
  -- (step 12g2a) a downlink sent elsewhere (a request): its ATC LOG entry
  function B747_fms_atc_log_add(d)
    seq = seq + 1
    d.seq, d.deleted = seq, false
    down[#down + 1] = d
    return d
  end
  -- the uplink answering a downlink (its RT the downlink's ID; the newest,
  -- not deleted): its place, nil without
  local function rt(m)
    local v = field(m, "rt") or field(m, "RT")
    return tonumber(v)
  end
  function B747_fms_atc_response_to(id)
    if not id then return nil end
    for i = table.getn(acarsSystem.messages.values), 1, -1 do
      local s = B747_fms_atc_uplink(i)
      if s and not s.deleted and rt(msg(i)) == id then return i end
    end
    return nil
  end
  -- the request an uplink answers (nil: none)
  function B747_fms_atc_uplink_request(i)
    if not B747_fms_atc_uplink(i) then return nil end
    local id = rt(msg(i))
    if not id then return nil end
    for _, d in ipairs(down) do
      if d.kind == "REQUEST" and d.id == id and not d.deleted then return d end
    end
    return nil
  end
  -- an entry deleted (DELETE on its left key); every non-pending one (ERASE
  -- LOG's CONFIRM)
  function B747_fms_atc_log_delete(e)
    if e.up then ul[e.i].deleted = true else e.d.deleted = true end
  end
  function B747_fms_atc_log_erase()
    for _, e in ipairs(B747_fms_atc_log_entries()) do
      if not e.pending then B747_fms_atc_log_delete(e) end
    end
  end
  -- the ATC key's page: "LOGON", "INDEX", "LOG", or an uplink's place
  function B747_fms_atc_route()
    local list = uplinks()
    local states = {}
    for k, u in ipairs(list) do states[k] = u.s end
    local r = U.route(B747_fms_atc_logon().comm, states)
    if type(r) == "number" then return list[r].i end
    return r
  end
  -- an uplink reviewed (its page shown)
  function B747_fms_atc_review(i)
    if B747_fms_atc_uplink(i) then msg(i)["read"] = true end
  end
  -- VERIFY RESPONSE's response on a CDU: {i, kind ("ACCEPT", "REJECT",
  -- "STANDBY"), word, state (nil, "SENDING", "SENT")}
  function B747_fms_atc_verify(fmsID) return verify[fmsID] end
  function B747_fms_atc_choose(fmsID, i, kind)
    local s = B747_fms_atc_uplink(i)
    if not s then return false end
    local word = kind == "STANDBY" and "STANDBY"
      or (kind == "ACCEPT" and U.accept_word(s.resp) or U.reject_word(s.resp))
    if not word then return false end
    verify[fmsID] = {i = i, kind = kind, word = word, state = nil}
    return true
  end
  -- REJECT DUE TO on a CDU: perf, wx, free (four lines)
  function B747_fms_atc_due(fmsID)
    if not due[fmsID] then due[fmsID] = {perf = false, wx = false, free = {"", "", "", ""}} end
    return due[fmsID]
  end
  -- the response's text: the word, with REJECT the reasons and free text
  function B747_fms_atc_response_text(fmsID)
    local v = verify[fmsID]
    if not v then return "" end
    local t = v.word
    if v.kind == "REJECT" then
      local d = B747_fms_atc_due(fmsID)
      if d.perf then t = t .. " DUE TO AIRCRAFT PERFORMANCE" end
      if d.wx then t = t .. " DUE TO WEATHER" end
      for _, f in ipairs(d.free) do
        if f ~= "" then t = t .. " " .. f end
      end
    end
    return t
  end
  -- RESPONSE SEND: nil, or the message (no ATC COMM, the datalink's)
  function B747_fms_atc_send_response(fmsO)
    local v = verify[fmsO.id]
    if not v or v.state then return nil end
    if not B747_fms_atc_ready() then return "NO COMM" end
    if not B747_fms_atc_logon().comm then return "NO ATC COMM" end
    local m = msg(v.i)
    local reply = {type = "cpdlc", msg = B747_fms_atc_response_text(fmsO.id), RR = "N", status = "SENDING",
      RT = field(m, "srcID")}
    fmsFunctions.acarsSystemSendATC(fmsO, json.encode(reply))
    local s = B747_fms_atc_uplink(v.i)
    s.sent = v.kind
    v.state = "SENDING"
    if v.kind ~= "STANDBY" then m["REPLIED"] = true end
    -- (step 12g1) its ATC LOG entry (FCOM p.765)
    seq = seq + 1
    v.down = {seq = seq, time = string.format("%02d%02d", hh or 0, mm or 0), text = reply.msg, status = "SENDING",
      deleted = false}
    down[#down + 1] = v.down
    return nil
  end
  -- each frame: the acknowledgements, ATC COMM's end
  function B747_fms_atc_uplinks_update()
    local n = table.getn(acarsSystem.messages.values)
    if n < lastN then ul, verify, due = {}, {}, {} end
    lastN = n
    local ready = B747_fms_atc_ready()
    for _, v in pairs(verify) do
      if v.state == "SENDING" and ready then
        v.state = "SENT"
        local s = ul[v.i]
        if s and v.kind ~= "STANDBY" then s.acked = v.kind end
        -- a response needs none: SENT (FCOM p.754)
        if v.down then v.down.status = "SENT" end
      end
    end
    -- (step 12g2a) ATC's response to a request: STANDBY keeps it OPEN,
    -- REQUEST DEFERRED makes it DEFERRED, any other RESPONSE RCVD (FCOM
    -- p.753-754)
    if n < scanned then scanned = 0 end
    for i = scanned + 1, n do
      local id = B747_fms_atc_uplink(i) and rt(msg(i))
      if id then
        for _, d in ipairs(down) do
          if d.kind == "REQUEST" and d.id == id and DOWN_PENDING[d.status] == true then
            local t = str_trim(string.upper(field(msg(i), "msg") or ""))
            if t == "STANDBY" then d.status = "OPEN"
            elseif t == "REQUEST DEFERRED" then d.status = "DEFERRED"
            else d.status = "RESPONSE RCVD" end
          end
        end
      end
    end
    scanned = n
    local comm = B747_fms_atc_logon().comm
    if wasComm and not comm then
      for i, s in pairs(ul) do
        if U.pending(B747_fms_atc_uplink(i) or s) then s.aborted = true end
      end
      -- (step 12g2a) the pending downlinks: a request OPEN or DEFERRED too
      for _, d in ipairs(down) do
        if DOWN_PENDING[d.status] == true then d.status = "ABORTED" end
      end
    end
    wasComm = comm
  end
  -- the message list cleared (ACARS's clear)
  function B747_fms_atc_uplinks_clear() ul, verify, due, down, scanned = {}, {}, {}, {}, 0 end
end
-- (6-1/6-2 step 12g2a; notes/ATA-34-61-FMC.md §116) the ATC requests
-- (B747.68.atc_request_model.lua): the ATC REQUEST pages' request and ATC
-- INDEX's CLEARANCE and VOICE, one each in the FMC (each CDU shows and
-- changes them), the text sent built at SEND (before, the pages wrote one
-- shared text while drawing and the last CDU drawn's went: CDU-34); SEND
-- through the provider as before (cpdlc, RR Y) and its ATC LOG entry (FCOM
-- p.745); the network's acknowledgement the provider's sending it (one
-- message each 15 s: estimate): OPEN (a request needs a response), the
-- CDU that showed its VERIFY REQUEST to XXXXZ ATC REQUEST (FMSPG p.326),
-- the request erased (estimate); none in the logon's ACK_S: NO ACK and
-- RESEND> while unchanged (FMSPG p.365; the same entry again: estimate);
-- fields not to be changed while SENDING (FMSPG p.300-316); (step 12g2b)
-- RTE 1 and RTE 2's text, DEP/ARR's default and its check
dofile("B747.68.atc_request_model.lua")
do
  local Q = B747_atc_request_model
  -- (step 12g3a) WHEN CAN WE EXPECT's ("WCW") too
  local KINDS = {"REQUEST", "CLEARANCE", "VOICE", "WCW"}
  local drafts = {REQUEST = Q.new("REQUEST"), CLEARANCE = Q.new("CLEARANCE"), VOICE = Q.new("VOICE"), WCW = Q.new("WCW")}
  local verifyOf = {}
  local shownReq = {}
  function B747_fms_atc_draft(kind) return drafts[kind] end
  function B747_fms_atc_present_ft() return simDR_pressureAlt1 end
  -- a CDU's VERIFY REQUEST: the draft's kind and where from (6L: "REQUEST",
  -- "INDEX" or "WHEN CAN WE"); set with a kind
  function B747_fms_atc_verify_req(fmsID, kind, from)
    if kind then verifyOf[fmsID] = {kind = kind, from = from} end
    return verifyOf[fmsID] or {kind = "REQUEST", from = "REQUEST"}
  end
  -- a CDU's XXXXZ ATC REQUEST: the downlink
  function B747_fms_atc_show_request(fmsID, d) shownReq[fmsID] = d end
  function B747_fms_atc_shown_request(fmsID) return shownReq[fmsID] end
  local function sending(dr) return dr.sent ~= nil and dr.sent.status == "SENDING" end
  function B747_fms_atc_req_sending(kind) return sending(drafts[kind]) end
  -- 5R's text and its header (FMSPG p.365: blank with nothing to send)
  function B747_fms_atc_req_status(kind)
    local dr = drafts[kind]
    if sending(dr) then return "SENDING", "REQUEST" end
    if not B747_fms_atc_ready() then return "NO COMM", "DATA LINK" end
    if not B747_fms_atc_logon().comm then return "NO ATC COMM", "REQUEST" end
    if not Q.sendable(dr) then return "", "" end
    if dr.sent and dr.sent.status == "NO ACK" and dr.sent_rev == dr.rev then return "RESEND>", "REQUEST" end
    return "SEND>", "REQUEST"
  end
  -- (step 12g2b) a route's text for REQUEST ROUTE CLEARANCE: the origin,
  -- its runway and SID, each segment's airway and TO waypoint (DIRECT: the
  -- waypoint; not the procedures' legs, the discontinuities, an airway
  -- without its TO), the STAR, the approach, the destination; the
  -- modification when there is one (FMSPG p.317); nil without an origin
  -- and a destination. The form an estimate (the FANS route clearance's
  -- data as text)
  local function proc_name(p, name)
    return name .. ((p.trans and p.trans ~= "") and ("." .. p.trans) or "")
  end
  function B747_fms_atc_route_text(n)
    local R = B747_route_model
    local r = R.shown(B747_fmc_route_num(n))
    if not r.origin or not r.dest then return nil end
    local parts = {r.origin.ident}
    if r.runway and r.runway.ident then parts[#parts + 1] = r.runway.ident end
    if r.sid then parts[#parts + 1] = proc_name(r.sid, r.sid.name) end
    for _, sg in ipairs(R.segments(r)) do
      local l = r.legs[sg.first]
      if not sg.disc and sg.to and sg.to ~= "" and not (l and l.proc) then
        if sg.via and sg.via ~= R.DIRECT then parts[#parts + 1] = sg.via end
        parts[#parts + 1] = sg.to
      end
    end
    if r.star then parts[#parts + 1] = proc_name(r.star, r.star.name) end
    if r.appr then parts[#parts + 1] = proc_name(r.appr, B747_proc_model.approach_name(r.appr.id)) end
    parts[#parts + 1] = r.dest.ident
    return table.concat(parts, " ")
  end
  -- DEP/ARR's default: on the ground the departure selected, in the air
  -- the arrival (the STAR, else the approach: estimate), with its
  -- transition (FMSPG p.317); nil without one
  function B747_fms_atc_deparr_default()
    local r = B747_route_model.shown(B747_fmc_route)
    if simDR_onGround == 1 then return r.sid and proc_name(r.sid, r.sid.name) or nil end
    if r.star then return proc_name(r.star, r.star.name) end
    if r.appr then return proc_name(r.appr, B747_proc_model.approach_name(r.appr.id)) end
    return nil
  end
  -- an entered procedure: nil, or the message; the active route's origin's
  -- SIDs, its destination's STARs and approaches (as the CDU names them),
  -- the transition one of its enroute transitions (the messages: estimate)
  function B747_fms_atc_proc_check(text)
    if not Q.proc_form(text) then return Q.INVALID end
    local name, trans = string.match(text, "^(%w+)%.(%w+)$")
    name = name or text
    local P, N, db = B747_proc_model, B747_navdb, B747_fmc_navdb
    local r = B747_route_model.shown(B747_fmc_route)
    local function has(icao, kind)
      local c = icao and N.cifp(db, icao)
      if not c then return false end
      local id = nil
      for _, p in ipairs(c.order[kind] or {}) do
        if p == name or (kind == P.APPCH and P.approach_name(p) == name) then id = p end
      end
      if not id then return false end
      if not trans then return true end
      for _, t in ipairs(P.transitions(N, db, icao, kind, id).trans) do
        if t == trans then return true end
      end
      return false
    end
    local o, d = r.origin and r.origin.ident, r.dest and r.dest.ident
    if has(o, P.SID) or has(d, P.STAR) or has(d, P.APPCH) then return nil end
    return "NOT IN DATA BASE"
  end
  -- the selected route's text again (VERIFY, SEND)
  function B747_fms_atc_refresh_route(kind)
    local dr = drafts[kind]
    if dr.rte then Q.update_route(dr, B747_fms_atc_route_text(dr.rte)) end
  end
  -- SEND> or RESEND> (nothing when not shown)
  function B747_fms_atc_send_request(fmsO, kind)
    local st = B747_fms_atc_req_status(kind)
    if st ~= "SEND>" and st ~= "RESEND>" then return end
    local dr = drafts[kind]
    B747_fms_atc_refresh_route(kind)
    local text = Q.text(dr)
    fmsFunctions.acarsSystemSendATC(fmsO, json.encode({type = "cpdlc", msg = text, RR = "Y"}))
    local d = (st == "RESEND>") and dr.sent or {kind = "REQUEST"}
    d.req, d.text, d.status, d.sent_t = Q.copy(dr), text, "SENDING", simDRTime
    d.time = string.format("%02d%02d", hh or 0, mm or 0)
    d.id = acarsSystem.provider.messageID - 1
    d.queue = table.getn(acarsSystem.messageSendQueue.values)
    if st ~= "RESEND>" then B747_fms_atc_log_add(d) end
    dr.sent, dr.sent_rev = d, dr.rev
  end
  -- acknowledged (or answered first): the CDUs on its VERIFY REQUEST to
  -- XXXXZ ATC REQUEST, the request erased
  local function finish(kind, dr, d)
    for _, id in ipairs({"fmsL", "fmsC", "fmsR"}) do
      local o = fmsModules[id]
      local v = verifyOf[id]
      if o and o.currentPage == "ATCVERIFYREQUEST" and v and v.kind == kind then
        shownReq[id] = d
        fmsFunctions.setpage(o, "ATCREQUESTLOG")
      end
    end
    Q.erase(dr)
  end
  -- each frame: the acknowledgements, the time-outs
  function B747_fms_atc_requests_update()
    for _, kind in ipairs(KINDS) do
      local dr = drafts[kind]
      local d = dr.sent
      if d and d.status == "SENDING" then
        if acarsSystem.sentMessage >= d.queue then
          d.status = "OPEN"
          finish(kind, dr, d)
        elseif simDRTime - d.sent_t >= B747_atc_logon_model.ACK_S then
          d.status = "NO ACK"
        end
      elseif d and d.status ~= "NO ACK" and d.status ~= "ABORTED" then
        finish(kind, dr, d)
      end
    end
  end
end
-- (6-1/6-2 step 12g3b; notes/ATA-34-61-FMC.md §119) POS REPORT
-- (B747.68.atc_posrep_model.lua): the FMC's values (LAST and ATA as
-- PROGRESS 1's; TO, NEXT and their ETAs, DEST ETA from the predictions;
-- the altitude as the CDU shows it; the speed target; SAT; the true wind;
-- the lesser of the calculated and the totalizer fuel: FCOM p.766-768,
-- FMSPG p.340-343); the ATC report through the provider (cpdlc, no
-- response: SENT once the provider sends it) and its ATC LOG entry, the
-- company report (telex) with the FMC's values; NO ACK after the logon's
-- ACK_S, RESEND. Before, the page wrote the shared text while drawing
-- (CDU-34) from the old ND's waypoints, with no SEND that sent
dofile("B747.68.atc_posrep_model.lua")
do
  local P = B747_atc_posrep_model
  local pr = P.new()
  local sends = {}
  function B747_fms_posrep() return pr end
  local function eta(t)
    local _, h, m = get_ETA_for_Distance(0, t)
    return string.format("%02d%02dZ", h, m)
  end
  -- the FMC's values (B747_atc_posrep_model.values's `d`)
  function B747_fms_posrep_defaults()
    local d = {}
    local last = type(B747DR_last_waypoint) == "string" and str_trim(B747DR_last_waypoint) or ""
    if last ~= "" and not string.find(last, "^%-") then
      d.last = last
      local ata = string.sub(type(B747DR_waypoint_ata) == "string" and B747DR_waypoint_ata or "", 1, 4)
      if string.match(ata, "^%d%d%d%d$") then d.ata = ata .. "Z" end
    end
    d.alt = B747_cdu_model.format_alt(math.floor(simDR_pressureAlt1 + 0.5), tonumber(fmsModules["data"]["transalt"]) or 18000)
    local legs = B747_fmc_route.rte.legs
    local pred = B747_fmc_route.active and B747_fms_preds() or nil
    local to, nxt
    for i, l in ipairs(legs) do
      if l.fix and not l.disc then
        if not to then to = i elseif not nxt then nxt = i break end
      end
    end
    if B747_fmc_route.active and to then
      d.to = legs[to].fix.ident
      if pred and pred.pts[to] then d.eta = eta(pred.pts[to].t) end
      if nxt then d.nxt = legs[nxt].fix.ident end
      if pred and pred.dest then d.dest_eta = eta(pred.dest.t) end
    end
    if simDR_autopilot_airspeed_is_mach == 1 then
      d.spd = string.format(".%02d", math.floor(simDR_autopilot_airspeed_kts_mach * 100 + 0.5))
    else
      d.spd = string.format("%d", math.floor(simDR_autopilot_airspeed_kts + 0.5))
    end
    d.temp_c = math.floor(simDR_air_temp + 0.5)
    d.wind_dir, d.wind_kt = math.floor(B747_fms_wind_true() + 0.5) % 360, math.floor(simDR_wind_speed + 0.5)
    local fs = B747_fms_fuel()
    local calc = fs and fs.out and fs.out.calc
    local kg = calc and math.min(calc, simDR_fms_fuel_total) or simDR_fms_fuel_total
    local mult = simConfigData["data"].SIM.weight_display_units == "LBS" and simConfigData["data"].SIM.kgs_to_lbs or 1
    d.fuel_k = kg * mult / 1000
    return d
  end
  -- the page's values
  function B747_fms_posrep_values() return P.values(pr, B747_fms_posrep_defaults()) end
  -- a SEND's state: "SEND", "RESEND", "SENDING", "NO ATC COMM", "NO COMM"
  function B747_fms_posrep_status(which)
    local s = sends[which]
    if s and s.status == "SENDING" then return "SENDING" end
    if not B747_fms_atc_ready() then return "NO COMM" end
    if which == "ATC" and not B747_fms_atc_logon().comm then return "NO ATC COMM" end
    if s and s.status == "NO ACK" then return "RESEND" end
    return "SEND"
  end
  -- 6R ATC SEND, 6L COMPANY SEND
  function B747_fms_posrep_send(fmsO, which)
    local st = B747_fms_posrep_status(which)
    if st ~= "SEND" and st ~= "RESEND" then return end
    local d = B747_fms_posrep_defaults()
    local s
    local before = table.getn(acarsSystem.messageSendQueue.values)
    if which == "ATC" then
      local text = P.atc_text(P.values(pr, d), {offset = B747_route_model.shown(B747_fmc_route).offset,
        alt_ft = simDR_pressureAlt1, mcp_ft = B747DR_fms_vnav_mcp_alt,
        mcp_text = B747_cdu_model.format_alt(math.floor(B747DR_fms_vnav_mcp_alt + 0.5), tonumber(fmsModules["data"]["transalt"]) or 18000)})
      fmsFunctions.acarsSystemSendATC(fmsO, json.encode({type = "cpdlc", msg = text, RR = "N"}))
      s = (st == "RESEND" and sends.ATC) or {kind = "REPORT"}
      s.text, s.id = text, acarsSystem.provider.messageID - 1
      if st ~= "RESEND" then B747_fms_atc_log_add(s) end
    else
      -- the provider refuses without the flight's data (its message: FLT
      -- NO, DEPARTURE or DESTINATION NOT SET)
      acarsSystem.provider.sendCompany(json.encode({type = "telex", msg = P.company_text(d)}), fmsO)
      if table.getn(acarsSystem.messageSendQueue.values) == before then return end
      s = {}
    end
    s.status, s.sent_t = "SENDING", simDRTime
    s.time = string.format("%02d%02d", hh or 0, mm or 0)
    s.queue = table.getn(acarsSystem.messageSendQueue.values)
    sends[which] = s
  end
  -- each frame: the acknowledgements (the provider's sending: estimate),
  -- the time-outs
  function B747_fms_posrep_update()
    for _, which in ipairs({"ATC", "COMPANY"}) do
      local s = sends[which]
      if s and s.status == "SENDING" then
        if acarsSystem.sentMessage >= s.queue then
          s.status = "SENT"
          -- (step 12g3c) an ATC position report sent: the oldest REQUEST
          -- POSITION REPORT entry goes (FMSPG p.337)
          if which == "ATC" and B747_fms_report_posrep_sent then B747_fms_report_posrep_sent() end
        elseif simDRTime - s.sent_t >= B747_atc_logon_model.ACK_S then s.status = "NO ACK" end
      end
    end
  end
end
-- (6-1/6-2 step 12g3c; notes/ATA-34-61-FMC.md §120) ATC reports
-- (B747.68.atc_report_model.lua): an uplink's report or confirmation
-- request made a report when first seen (the uplink page's ARM), put on
-- the ATC REPORT list once the uplink is not pending (up to nine: REPORT
-- LIST FULL: FMSPG p.328); the FMC's values for the reports; SEND through
-- the provider (cpdlc, no response, RT the uplink's) and its ATC LOG
-- entry; acknowledged when the provider sends it (the entry goes, the CDU
-- on its VERIFY REPORT to ATC REPORT: estimate); an armed LEVEL, REACHING
-- or PASSING sent when its condition comes (FMSPG p.340); RTE REPORT and
-- FREE TEXT reports of ATC REPORT's own
dofile("B747.68.atc_report_model.lua")
do
  local A = B747_atc_report_model
  local list = {}
  local byUplink = {}
  local verifyOf = {}
  local shownRep = {}
  local seen = 0
  local function latlon(lat, lon)
    local function part(v, pos, neg, w)
      local a = math.abs(v)
      local d = math.floor(a)
      return string.format("%s%0" .. w .. "d%04.1f", v < 0 and neg or pos, d, (a - d) * 60)
    end
    return part(lat, "N", "S", 2) .. part(lon, "E", "W", 3)
  end
  -- the FMC's values for the reports (B747_atc_report_model.elements's `c`)
  local function report_ctx_make()
    local d = B747_fms_posrep_defaults()
    local ta = tonumber(fmsModules["data"]["transalt"]) or 18000
    local c = {alt = d.alt, next_wpt = d.to, next_eta = d.eta, ensuing = d.nxt, last = d.last, ata = d.ata,
      spd = d.spd and ((string.sub(d.spd, 1, 1) == ".") and d.spd or (d.spd .. "KT")) or nil}
    local mcp = B747DR_fms_vnav_mcp_alt
    c.mcp = B747_cdu_model.format_alt(math.floor(mcp + 0.5), ta)
    if mcp > simDR_pressureAlt1 + A.LEVEL_FT then c.mcp_dir = "CLIMBING"
    elseif mcp < simDR_pressureAlt1 - A.LEVEL_FT then c.mcp_dir = "DESCENDING" end
    if B747_fmc_route.active then
      c.route = B747_fms_atc_route_text(B747_fmc_route.num or 1)
      c.rte_name = "RTE " .. (B747_fmc_route.num or 1)
      local off = B747_route_model.shown(B747_fmc_route).offset
      if off and off ~= 0 then c.offset_text = string.format("%s%dNM", off < 0 and "L" or "R", math.abs(off)) end
    end
    c.ppos = latlon(simDR_latitude, simDR_longitude)
    c.hdg = string.format("%03d", math.floor(simDR_fms_mag_psi + 0.5) % 360)
    c.trk = string.format("%03d", math.floor(simDR_lnav_trk - (simDR_fms_true_psi - simDR_fms_mag_psi) + 0.5) % 360)
    local ff = 0
    for n = 0, 3 do ff = ff + simDR_fms_ff[n] end
    if ff > 0.01 then
      local min = math.min(23 * 60 + 59, math.floor(simDR_fms_fuel_total / ff / 60))
      c.endurance = string.format("%02d+%02d", math.floor(min / 60), min % 60)
    end
    c.now = string.format("%02d%02dZ", hh or 0, mm or 0)
    return c
  end
  -- made once a frame (2026-11-05 review 4: before, at each look: VERIFY
  -- REPORT's three renders a frame and its status's two looks each made
  -- it, the position report's defaults and the route's text with it); a
  -- copy to each caller, the emergency's adds to it
  local ctxT, ctxC = nil, nil
  function B747_fms_report_ctx()
    if ctxC == nil or ctxT ~= simDRTime then ctxC, ctxT = report_ctx_make(), simDRTime end
    local c = {}
    for k, v in pairs(ctxC) do c[k] = v end
    return c
  end
  -- an uplink's report (nil: no request in it); made when first seen
  function B747_fms_report_for_uplink(i)
    if not B747_fms_atc_uplink(i) then return nil end
    local rep = byUplink[i]
    if rep == nil then
      local req = A.parse(B747_fms_atc_msg_field(i, "msg") or "")
      rep = req and A.new(req) or false
      if rep then rep.i = i end
      byUplink[i] = rep
    end
    return rep or nil
  end
  function B747_fms_report_list() return list end
  -- the CDUs' VERIFY REPORT (a report) and XXXXZ ATC REPORT (a downlink)
  function B747_fms_report_verify(fmsID, rep)
    if rep ~= nil then verifyOf[fmsID] = rep end
    return verifyOf[fmsID]
  end
  function B747_fms_report_show(fmsID, d) shownRep[fmsID] = d end
  function B747_fms_report_shown(fmsID) return shownRep[fmsID] end
  -- 5R: the state, "" while an entry is missing
  function B747_fms_report_status(rep)
    local d = rep.sent
    if d and d.status == "SENDING" then return "SENDING" end
    if not B747_fms_atc_ready() then return "NO COMM" end
    if not B747_fms_atc_logon().comm then return "NO ATC COMM" end
    if not A.complete(rep, B747_fms_report_ctx()) or A.text(rep, B747_fms_report_ctx()) == "" then return "" end
    if d and d.status == "NO ACK" and rep.sent_rev == rep.rev then return "RESEND" end
    return "SEND"
  end
  -- SEND> or RESEND> (or an armed report's condition)
  function B747_fms_report_send(fmsO, rep)
    local st = B747_fms_report_status(rep)
    if st ~= "SEND" and st ~= "RESEND" then return false end
    local c = B747_fms_report_ctx()
    local text = A.text(rep, c)
    local msg = {type = "cpdlc", msg = text, RR = "N"}
    if rep.i then msg.RT = B747_fms_atc_msg_field(rep.i, "srcID") end
    fmsFunctions.acarsSystemSendATC(fmsO, json.encode(msg))
    local d = (st == "RESEND" and rep.sent) or {kind = "REPORT"}
    d.text, d.rows, d.status, d.sent_t = text, A.rows(rep, c), "SENDING", simDRTime
    d.time = string.format("%02d%02d", hh or 0, mm or 0)
    d.id = acarsSystem.provider.messageID - 1
    d.queue = table.getn(acarsSystem.messageSendQueue.values)
    d.rep = rep
    if st ~= "RESEND" then B747_fms_atc_log_add(d) end
    rep.sent, rep.sent_rev, rep.armed = d, rep.rev, false
    return true
  end
  local function drop(rep)
    for k, e in ipairs(list) do
      if e == rep then table.remove(list, k) break end
    end
    for _, id in ipairs({"fmsL", "fmsC", "fmsR"}) do
      local o = fmsModules[id]
      if verifyOf[id] == rep and o and o.currentPage == "ATCVERIFYREPORT" then fmsFunctions.setpage(o, "ATCREPORT") end
    end
  end
  -- DELETE on its ATC REPORT line
  function B747_fms_report_delete(rep) drop(rep) end
  -- POS REPORT's ATC report sent: the oldest REQUEST POSITION REPORT
  function B747_fms_report_posrep_sent()
    for _, e in ipairs(list) do
      if e.posrep then drop(e) return end
    end
  end
  -- each frame: the uplinks' requests to the list, the armed reports, the
  -- acknowledgements
  function B747_fms_reports_update()
    local n = table.getn(acarsSystem.messages.values)
    if n < seen then list, byUplink, seen = {}, {}, 0 end
    for i = 1, n do
      local s = B747_fms_atc_uplink(i)
      local rep = s and not s.deleted and B747_fms_report_for_uplink(i)
      if rep and not rep.listed and not B747_atc_uplink_model.pending(s) then
        rep.listed = true
        if #list >= A.MAX_LIST then B747_cdu_fmc_event("REPORT LIST FULL", false)
        else list[#list + 1] = rep end
      end
    end
    seen = n
    local passed = nil
    for _, rep in ipairs(list) do
      local d = rep.sent
      if d and d.status == "SENDING" then
        if acarsSystem.sentMessage >= d.queue then
          d.status = "SENT"
          drop(rep)
          break
        elseif simDRTime - d.sent_t >= B747_atc_logon_model.ACK_S then d.status = "NO ACK" end
      end
      if rep.armed then
        if not passed then
          passed = {}
          for _, l in ipairs(B747_fmc_route.rte.passed or {}) do
            if l.fix then passed[l.fix.ident] = true end
          end
        end
        local _, ft = B747_atc_request_model.alt_text(rep.args[1] or "")
        if A.triggered(rep, {alt_ft = simDR_pressureAlt1, vs_fpm = simDR_vvi_fpm_pilot, passed = passed}, ft) then
          B747_fms_report_send(fmsModules["fmsL"], rep)
        end
      end
    end
  end
end
-- (6-1/6-2 step 12g4; notes/ATA-34-61-FMC.md §121) ATC emergency reports
-- (B747.68.atc_emergency_model.lua): one in the FMC; the FMC's values
-- (the active destination and route, the MCP altitude, the altitude now,
-- the position, the fuel in thousands and its time); SEND through the
-- provider (cpdlc, no response) and its ATC LOG entry; acknowledged when
-- the provider sends it: the emergency mode with a MAYDAY or PAN report,
-- its end with CANCEL EMERGENCY or when ATC COMM ends (FMSPG p.345), the
-- data erased (CANCEL EMERGENCY offered: FCOM p.729); NO ACK after 60 s
dofile("B747.68.atc_emergency_model.lua")
do
  local E = B747_atc_emergency_model
  local em = E.new()
  local mode = false
  local shownEm = {}
  function B747_fms_emergency() return em end
  function B747_fms_emergency_mode() return mode end
  function B747_fms_emergency_ctx()
    local c = B747_fms_report_ctx()
    local r = B747_route_model.shown(B747_fmc_route)
    c.dest = B747_fmc_route.active and r.dest and r.dest.ident or nil
    c.mcp_ft, c.alt_ft = B747DR_fms_vnav_mcp_alt, simDR_pressureAlt1
    c.fuel_k = B747_fms_posrep_defaults().fuel_k
    c.unit = simConfigData["data"].SIM.weight_display_units == "LBS" and "LB" or "KG"
    return c
  end
  local function sending() return em.sent ~= nil and em.sent.status == "SENDING" end
  function B747_fms_emergency_sending() return sending() end
  -- 5R: the state and its header
  function B747_fms_emergency_status()
    if sending() then return "SENDING", "REPORT" end
    if not B747_fms_atc_ready() then return "NO COMM", "DATA LINK" end
    if not B747_fms_atc_logon().comm then return "NO ATC COMM", "REPORT" end
    if E.text(em, B747_fms_emergency_ctx()) == "" then return "", "" end
    if em.sent and em.sent.status == "NO ACK" and em.sent_rev == em.rev then return "RESEND>", "REPORT" end
    return "SEND>", "REPORT"
  end
  -- REPORT SEND> or RESEND>: true when sent
  function B747_fms_emergency_send(fmsO)
    local st = B747_fms_emergency_status()
    if st ~= "SEND>" and st ~= "RESEND>" then return false end
    local c = B747_fms_emergency_ctx()
    local text = E.text(em, c)
    fmsFunctions.acarsSystemSendATC(fmsO, json.encode({type = "cpdlc", msg = text, RR = "N"}))
    local d = (st == "RESEND>" and em.sent) or {kind = "EMERGENCY"}
    d.text, d.rows, d.status, d.sent_t = text, E.sent_rows(em, c), "SENDING", simDRTime
    d.time = string.format("%02d%02d", hh or 0, mm or 0)
    d.id = acarsSystem.provider.messageID - 1
    d.queue = table.getn(acarsSystem.messageSendQueue.values)
    d.declares, d.cancels = em.mayday or em.pan, em.cancel
    if st ~= "RESEND>" then B747_fms_atc_log_add(d) end
    em.sent, em.sent_rev = d, em.rev
    return true
  end
  function B747_fms_emergency_show(fmsID, d) shownEm[fmsID] = d end
  function B747_fms_emergency_shown(fmsID) return shownEm[fmsID] end
  -- each frame: the acknowledgement, the emergency mode
  local wasComm = false
  function B747_fms_emergency_update()
    local d = em.sent
    if d and d.status == "SENDING" then
      if acarsSystem.sentMessage >= d.queue then
        d.status = "SENT"
        if d.declares then mode = true end
        if d.cancels then mode = false end
        E.erase(em)
      elseif simDRTime - d.sent_t >= B747_atc_logon_model.ACK_S then
        d.status = "NO ACK"
      end
    end
    local comm = B747_fms_atc_logon().comm
    if wasComm and not comm then mode = false end
    wasComm = comm
  end
end
-- (6-1/6-2 step 12h1; notes/ATA-34-61-FMC.md §122) the company datalink's
-- flight plan (FCOM p.771-774, p.1288-1291; FMSPG p.367-376, p.382): RTE
-- REQUEST (FMC COMM 2/2's 1L, a RTE page's 3L) with its CO ROUTE, SENDING
-- until the network's acknowledgement, then SEND with SENT; the company's
-- flight plan uplink: ROUTE n UPLINK READY, ROUTE UPLINK with LOAD and
-- PURGE on the route's page, LOAD (ROUTE n UPLINK LOADING; the inactive
-- route replaced, the active route's a modification), PURGE; the flight
-- number uplinked (FLT NUMBER UPLINK); INVALID ROUTE UPLINK, PARTIAL ROUTE
-- n UPLINK. The company is the sim's airline operations (B747.68.
-- simbrief_model.lua): SimBrief's .fms (the CO ROUTE's file, else the
-- newest) and OFP (the newest .xml, its flight number; its navigation log
-- without an .fms) in the aircraft folder's simbrief folder, whose newest
-- files' names the native plugin b747_fms_bridge writes into its
-- _newest.txt (XTLua cannot list a folder, and its copy of another
-- plugin's text dataref can stay old: s201, 2026-11-01); its link the
-- sim's own, READY with the FMC's datalink (no AutoATC needed).
-- Estimates: the times (the acknowledgement ACK_S, the answer ANSWER_S,
-- the loading LOAD_S), the route an uplink goes to (the request's route
-- on the ground, the inactive one in the air; FMC COMM's: the active one
-- on the ground, else RTE 1), the CO ROUTE the .fms's name, a point not in
-- the database a latitude/longitude point at its place (PARTIAL), no
-- accept or reject downlinks, the company's ACARS text without a flight
-- plan.
dofile("B747.68.simbrief_model.lua")
simDR_acf_relative_path=find_dataref("sim/aircraft/view/acf_relative_path")
do
  local S = B747_simbrief_model
  local R = B747_route_model
  local ACK_S, ANSWER_S, LOAD_S = 4, 20, 2
  local CO_ROUTE_LEN, FLT_NO_LEN, FIX_NM = 10, 8, 5
  -- (§131) SimBrief's latest OFP by the Pilot ID, fetched by the FMS
  -- bridge on a request without a CO ROUTE (that names a file of the
  -- folder's): the answer waits for it FETCH_MAX_S at most (the bridge's
  -- own timeouts are shorter); a failed fetch said in the company's ACARS
  -- text, the folder's newest files used
  local FETCH_MAX_S = 60
  local FETCH_FAIL = {
    [3] = {"SIMBRIEF PILOT ID", "NOT SET"},
    [4] = {"SIMBRIEF: NO ANSWER", "FOLDER FILES USED"},
    [5] = {"SIMBRIEF: NO OFP FOR", "THE PILOT ID", "FOLDER FILES USED"},
    [6] = {"SIMBRIEF OFP WITHOUT", "X-PLANE FLIGHT PLAN"},
    [7] = {"SIMBRIEF FILES", "NOT SAVED", "FOLDER FILES USED"},
  }
  local function fetch_wanted(co)
    return B747DR_xp_bridge == 1 and B747DR_simbrief_id > 0 and not (co and co ~= "")
  end
  -- the route request: {status ("SENDING", "SENT"), t, num (the route
  -- asked from; nil: FMC COMM's), route (the route its uplink goes to),
  -- co_route}
  local req = nil
  local commCoRoute = nil   -- FMC COMM 2/2's CO ROUTE
  -- the uplink: {num, rte (the route built), partial, co_route, loading
  -- (the time LOAD was pushed)}
  local up = nil
  local fltUnreviewed = false
  local shownMsg = ""
  local function read_file(path)
    if type(path) ~= "string" or path == "" then return nil end
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
  end
  local function base_name(path)
    return path and (string.match(path, "([^/\\]+)%.[Ff][Mm][Ss]$")) or nil
  end
  -- the company's ACARS text (a telex)
  local function telex(title, lines)
    local m = {type = "telex", title = title, msg = table.concat(lines, "@"), from = "COMPANY", read = false, rr = "N",
      time = string.format("%02d:%02d", hh or 0, mm or 0), messageID = acarsSystem.provider.messageID}
    acarsSystem.provider.messageID = acarsSystem.provider.messageID + 1
    acarsSystem.messages[table.getn(acarsSystem.messages.values) + 1] = m
  end
  function B747_fms_company_telex(title, lines) telex(title, lines) end
  -- the link: the FMC's datalink (FCOM p.772: READY, NO COMM, VOICE, FAIL)
  function B747_fms_company_status()
    if not B747_fms_datalink() then return "NO COMM" end
    return "READY"
  end
  -- the route an uplink goes to (estimate)
  local function target(asked)
    local act = B747_fmc_route.active and B747_fmc_route.num or nil
    local n = asked or act or 1
    if simDR_onGround == 0 and act == n then n = 3 - n end
    return n
  end
  local function dist_nm(a, b)
    local dlat = math.rad(b.lat - a.lat)
    local dlon = math.rad(b.lon - a.lon) * math.cos(math.rad((a.lat + b.lat) / 2))
    return math.sqrt(dlat * dlat + dlon * dlon) * 3440.065
  end
  local function ll_fix(p)
    return {kind = "LL", ident = string.format("%s%02d%s%03d", p.lat >= 0 and "N" or "S", math.floor(math.abs(p.lat)),
      p.lon >= 0 and "E" or "W", math.floor(math.abs(p.lon))), lat = p.lat, lon = p.lon}
  end
  -- a point of the uplink in the database (the nearest of its name within
  -- FIX_NM), else a latitude/longitude point at its place (the second
  -- value true: not the database's)
  local function find_fix(st, p)
    if p.kind == "ltlg" then return ll_fix(p) end
    local best = R.candidates(st, p.ident, p.lat, p.lon, true)[1]
    if best and dist_nm(best, p) <= FIX_NM then return best end
    return ll_fix(p), true
  end
  local function last_fix(st)
    local l = st.rte.legs[#st.rte.legs]
    return l and l.fix
  end
  local function drop_pending(st)
    local legs = st.rte.legs
    if legs[#legs] and legs[#legs].pending then legs[#legs] = nil end
  end
  local function same_name(a, b)
    return a and b and string.gsub(string.upper(a), "[^%w]", "") == string.gsub(string.upper(b), "[^%w]", "")
  end
  -- the destination's STAR or approach of an uplinked name (the approach
  -- by its identifier or its CDU name: I06L or ILS06L)
  local function proc_name(dest, kind, name)
    local P = B747_proc_model
    for _, id in ipairs(P.list(B747_navdb, B747_fmc_navdb, dest, kind)) do
      if same_name(id, name) or (kind == P.APPCH and same_name(P.approach_name(id), name)) then return id end
    end
    return nil
  end
  -- the uplink's route built as the crew would enter it: ORIGIN, DEST,
  -- RUNWAY, the SID, the route's elements (an airway to its point, else
  -- DIRECT to each point), the STAR and the approach; nil when the origin
  -- or the destination is not in the database (INVALID ROUTE UPLINK)
  local function build(u)
    local st = R.new(B747_navdb, B747_fmc_navdb)
    st.P = B747_proc_model
    if not u.origin or not u.dest or R.set_origin(st, u.origin) or R.set_dest(st, u.dest) then return nil end
    local partial = false
    if u.runway and R.set_runway(st, u.runway) then partial = true end
    if u.sid then
      local rwy = st.rte.runway and st.rte.runway.ident
      if R.set_departure(st, u.sid, rwy, u.sidtrans) and (not u.sidtrans or R.set_departure(st, u.sid, rwy, nil)) then
        partial = true
      end
    end
    for _, e in ipairs(u.elements or {}) do
      local done = false
      if e.via ~= "DIRECT" and not R.add_via(st, e.via) then
        local f, other = find_fix(st, e.fix)
        if not other and not R.add_to(st, f) then done = true else drop_pending(st) end
      end
      if not done then
        for _, p in ipairs(e.points) do
          local f, other = find_fix(st, p)
          if other then partial = true end
          local l = last_fix(st)
          if not (l and l.ident == f.ident and dist_nm(l, f) < 1) and R.add_to(st, f) then partial = true end
        end
      end
    end
    local P = B747_proc_model
    if u.star then
      local name = proc_name(u.dest, P.STAR, u.star)
      if not name or (R.set_arrival(st, {name = name, trans = u.startrans}, nil)
          and (not u.startrans or R.set_arrival(st, {name = name}, nil))) then
        partial = true
      end
    end
    if u.app then
      local id = proc_name(u.dest, P.APPCH, u.app)
      if not id or (R.set_arrival(st, nil, {id = id, trans = u.apptrans})
          and (not u.apptrans or R.set_arrival(st, nil, {id = id}))) then
        partial = true
      end
    end
    return st.rte, partial
  end
  -- the company's answer to a route request: the flight plan uplink, its
  -- flight number at once (FCOM p.1433: FLT NUMBER UPLINK)
  -- a text dataref up to its terminating 0
  local function text_of(v)
    return type(v) == "string" and (string.match(v, "^[^%z]*")) or ""
  end
  -- the simbrief folder: by the aircraft's .acf (relative to X-Plane's
  -- folder, where XTLua opens files), B747_COMPANY_FOLDER in the tests
  local function folder_of()
    if B747_COMPANY_FOLDER then return B747_COMPANY_FOLDER end
    return (string.match(text_of(simDR_acf_relative_path), "^(.*[/\\])") or "") .. "simbrief/"
  end
  local function answer(r)
    local folder = folder_of()
    -- the plugin's list: "FMS name" and "OFP name"
    local list = read_file(folder .. "_newest.txt") or ""
    local fmsName, ofpName = string.match(list, "FMS ([^\r\n]+)"), string.match(list, "OFP ([^\r\n]+)")
    local path = fmsName and (folder .. fmsName)
    if r.co_route and r.co_route ~= "" then path = folder .. r.co_route .. ".fms" end
    local plan = S.parse_fms(read_file(path))
    local ofp = S.parse_ofp(read_file(ofpName and (folder .. ofpName)))
    -- another flight's OFP: not this plan's
    if plan and ofp and (ofp.origin.icao ~= plan.origin or ofp.dest.icao ~= plan.dest) then ofp = nil end
    if not plan and r.co_route and r.co_route ~= "" then ofp = nil end
    local co = r.co_route
    if not co or co == "" then co = plan and base_name(path) or (ofp and (ofp.origin.icao .. ofp.dest.icao)) end
    local u = S.route_uplink(plan, ofp, co and string.sub(string.upper(co), 1, CO_ROUTE_LEN))
    if not u then
      telex("NO FLIGHT PLAN", {r.co_route and r.co_route ~= "" and ("CO ROUTE " .. r.co_route .. " NOT ON FILE") or "NO FLIGHT PLAN ON FILE",
        "SIMBRIEF FOLDER:", "AIRCRAFT/SIMBRIEF"})
      return
    end
    if u.flt_no then
      if #u.flt_no <= FLT_NO_LEN and string.match(u.flt_no, "^%w+$") then
        -- (the same number again: no message, estimate)
        if fms_text("fltno") ~= u.flt_no then
          setFMSData("fltno", u.flt_no)
          fltUnreviewed = true
          B747_cdu_fmc_event("FLT NUMBER UPLINK", true)
        end
      else
        B747_cdu_fmc_event("INVALID FLT NO UPLINK", true)
      end
    end
    local rte, partial = build(u)
    if not rte then B747_cdu_fmc_event("INVALID ROUTE UPLINK", true) return end
    up = {num = r.route, rte = rte, partial = partial, co_route = u.co_route}
    -- (6-1/6-2 step 12h3; notes/ATA-34-61-FMC.md §125) with the flight
    -- plan, the OFP's weights, fuel, cruise altitude and step climbs as
    -- the company's ACARS text, for the crew to enter on PERF INIT (the
    -- user's choice, 2026-11-01: no automatic fill; FCOM p.1310-1311
    -- names a performance uplink without its procedure)
    if ofp then telex("OFP " .. ofp.origin.icao .. "-" .. ofp.dest.icao, S.ofp_text(ofp)) end
  end
  -- the pages' state (one table, no garbage each frame)
  local view = {}
  function B747_fms_company()
    view.req, view.up, view.comm_co_route, view.flt_unreviewed = req, up, commCoRoute, fltUnreviewed
    return view
  end
  -- RTE REQUEST's SEND (FCOM p.773, p.1289): from RTE page `num` or FMC
  -- COMM (nil); blank while an uplink waits to be loaded
  function B747_fms_company_request(fmsO, num)
    if B747_fms_company_status() ~= "READY" or (req and req.status == "SENDING") or up then return end
    local co
    if num then
      co = B747_fmc_route_num(num).co_route
    else
      co = commCoRoute
      -- FMC COMM's CO ROUTE to the RTE page (FMSPG p.382)
      if co then B747_fmc_route_num(target(nil)).co_route = co end
    end
    req = {status = "SENDING", t = simDRTime, num = num, route = target(num), co_route = co}
    if fetch_wanted(co) then
      req.fetch = B747DR_simbrief_fetch + 1
      B747DR_simbrief_fetch = req.fetch
    end
  end
  -- CO ROUTE (FCOM p.774, p.1290): any identifier (NOT IN DATA BASE: no
  -- company routes in the database); DELETE clears it and the request's
  -- status back to SEND
  function B747_fms_company_co_route(num, value)
    if value == nil then
      if num then B747_fmc_route_num(num).co_route = nil else commCoRoute = nil end
      if req and req.status == "SENT" then req = nil end
      return nil
    end
    if #value < 1 or #value > CO_ROUTE_LEN or not string.match(value, "^%w+$") then return "INVALID ENTRY" end
    if num then B747_fmc_route_num(num).co_route = value else commCoRoute = value end
    if req and req.status == "SENT" then req = nil end
    return "NOT IN DATA BASE"
  end
  -- LOAD (FCOM p.1291; FMSPG p.374-376): the inactive route replaced, the
  -- active route's modification (ERASE and EXEC)
  function B747_fms_company_load(num)
    if not up or up.num ~= num or up.loading then return end
    up.loading = simDRTime
  end
  -- PURGE: the uplink dropped (an inactive route's only)
  function B747_fms_company_purge(num)
    if not up or up.num ~= num or up.loading or B747_fmc_route_num(num).active then return end
    up = nil
  end
  -- the RTE page reviewed: the flight number uplink's UPLINK goes (FMSPG
  -- p.368)
  function B747_fms_company_reviewed() fltUnreviewed = false end
  local function loaded(u)
    local st = B747_fmc_route_num(u.num)
    local rte = u.rte
    rte.passed = {}
    if st.active then
      st.mod = rte
    else
      st.rte, st.mod, st.activating = rte, nil, false
    end
    st.co_route = u.co_route
    st.edits = (st.edits or 0) + 1
    if u.partial then B747_cdu_fmc_event("PARTIAL ROUTE " .. u.num .. " UPLINK", true) end
    B747_fmc_route_changed()
  end
  -- (6-1/6-2 step 12h2) the winds (FCOM p.771-774, p.1361-1364,
  -- p.1395-1397, p.1431-1434; FMSPG p.377-380, p.383): WIND REQUEST (FMC
  -- COMM 2/2's 2L, RTE DATA's 6R, DESCENT FORECAST's 6L; not in the descent
  -- or on approach), SENDING, SENT; the company's answer from the OFP of
  -- the active route's airports: the en route winds (WIND DATA UPLINK
  -- READY; RTE DATA's LOAD> makes the active route's modification with
  -- them, EXEC or ERASE) and the descent forecast (DES FORECST UPLINK
  -- READY; DESCENT FORECAST's <LOAD replaces its winds, PURGE> drops
  -- them); INVALID WIND DATA UPLINK and INVALID FORECAST UPLINK when none
  -- of their data can be used. Estimates: the times (as the route's), the
  -- winds at the OFP's cruise altitudes (up to 4: its initial and step
  -- climbs' altitudes), each waypoint's of the route by its name and place,
  -- the forecast's 4 altitudes from the top of descent to 5,000 ft, the
  -- route's earlier winds and temperatures replaced, no OFP for another
  -- route: the company's ACARS text.
  -- the winds' state and helpers in one table (the main chunk's locals are
  -- near Lua's 200): req, up (en route), fup (forecast), shown (the
  -- messages' key)
  local wd = {req = nil, up = nil, fup = nil, shown = "",
    -- the messages' flags (B744.notifications.lua's places, from 1)
    DES_FORECST = 7, WIND_DATA = 53}
  function wd.in_descent() return B747DR_fms_vnav_phase == 3 or B747_fms_on_app() end
  -- the OFP the company has (the plugin's newest .xml) for the active route
  function wd.ofp_for_route()
    local folder = folder_of()
    local list = read_file(folder .. "_newest.txt") or ""
    local name = string.match(list, "OFP ([^\r\n]+)")
    local ofp = S.parse_ofp(read_file(name and (folder .. name)))
    local r = B747_fmc_route.rte
    if not (ofp and B747_fmc_route.active and r.origin and r.dest) then return nil end
    if ofp.origin.icao ~= r.origin.ident or ofp.dest.icao ~= r.dest.ident then return nil end
    return ofp
  end
  -- the uplinked points on the active route's legs: {leg index = point}
  function wd.legs(u)
    local r = B747_fmc_route.rte
    local out, n = {}, 0
    for i, l in ipairs(r.legs) do
      local f = l.fix
      if f and f.lat and not l.disc then
        for _, p in ipairs(u.points) do
          if p.ident == f.ident and dist_nm(p, f) <= FIX_NM then out[i] = p n = n + 1 break end
        end
      end
    end
    return out, n
  end
  function wd.answer()
    local ofp = wd.ofp_for_route()
    if not ofp then
      telex("NO WIND DATA", {"NO WIND DATA ON FILE", "FOR THE ACTIVE ROUTE"})
      return
    end
    local u = S.wind_uplink(ofp)
    if u then
      local _, n = wd.legs(u)
      if n > 0 then wd.up = u else B747_cdu_fmc_event("INVALID WIND DATA UPLINK", true) end
    end
    local f = S.forecast_uplink(ofp)
    if f and #f.levels > 0 then wd.fup = f elseif u then B747_cdu_fmc_event("INVALID FORECAST UPLINK", true) end
  end
  function B747_fms_company_winds()
    return wd.req, wd.up, wd.fup
  end
  function B747_fms_company_wind_send_shown()
    return B747_fms_company_status() == "READY" and not wd.in_descent()
  end
  -- WIND REQUEST's SEND
  function B747_fms_company_wind_request()
    if not B747_fms_company_wind_send_shown() or (wd.req and wd.req.status == "SENDING") then return end
    wd.req = {status = "SENDING", t = simDRTime}
  end
  -- RTE DATA's LOAD>: the active route's modification with the uplinked
  -- winds (FCOM p.1364: "results in a modification"), the legs' earlier
  -- winds and temperatures replaced (new tables: the modification's legs
  -- share the active route's)
  function B747_fms_company_wind_load()
    local u = wd.up
    local st = B747_fmc_route
    if not (u and st.active) then return end
    local byLeg = wd.legs(u)
    local r = R.edit(st)
    local alts = {}
    for k, a in ipairs(u.alts) do alts[k] = a end
    r.windAlts = alts
    for i, l in ipairs(r.legs) do
      local p = byLeg[i]
      l.wind, l.oat = nil, nil
      if p then
        local w = {}
        for _, x in ipairs(p.winds) do w[x.alt] = {dir = x.dir % 360, kt = x.spd} end
        l.wind = w
        if p.oat then l.oat = {ft = alts[#alts], c = p.oat} end
      end
    end
    wd.up = nil
    B747_fmc_route_changed()
  end
  -- DESCENT FORECAST's <LOAD (FCOM p.1397: shown and kept) and PURGE>
  function B747_fms_company_forecast_load()
    if not wd.fup then return end
    local fc = B747_fms_des_forecast()
    for k = 1, 4 do
      local l = wd.fup.levels[k]
      fc.slots[k] = l and {ft = l.alt, dir = l.dir % 360, kt = l.spd} or {}
    end
    wd.fup = nil
    B747_fms_preds_now()
  end
  function B747_fms_company_forecast_purge() wd.fup = nil end
  function wd.update(now)
    local q = wd.req
    if q and q.status == "SENDING" and now - q.t >= ACK_S then
      q.status, q.t = "SENT", now
    end
    if q and q.status == "SENT" and not q.answered and now - q.t >= ANSWER_S then
      q.answered = true
      wd.answer()
    end
    -- the uplink came: SENT goes (as the route's)
    if q and q.answered and (wd.up or wd.fup) then wd.req = nil end
    -- the messages by their flags, as they change (B744.notifications.lua
    -- has them: B747_cdu_sync_fmc_messages keeps its conditions by the
    -- flags)
    local key = (wd.up and "W" or "") .. (wd.fup and "F" or "")
    if key ~= wd.shown then
      B747DR_fmc_notifications[wd.WIND_DATA] = wd.up and 1 or 0
      B747DR_fmc_notifications[wd.DES_FORECST] = wd.fup and 1 or 0
      wd.shown = key
    end
  end
  function B747_fms_company_update()
    local now = simDRTime
    wd.update(now)
    if req and req.status == "SENDING" and now - req.t >= ACK_S then
      req.status, req.t = "SENT", now
    end
    if req and req.status == "SENT" and not req.answered and now - req.t >= ANSWER_S then
      local waiting = req.fetch and B747DR_simbrief_done < req.fetch
      if not waiting or now - req.t >= FETCH_MAX_S then
        req.answered = true
        if req.fetch then
          local st = waiting and 4 or B747DR_simbrief_status
          if FETCH_FAIL[st] then telex("SIMBRIEF", FETCH_FAIL[st]) end
        end
        answer(req)
      end
    end
    -- the uplink came: the request's SENT goes (FMSPG p.372)
    if up and req and req.answered then req = nil end
    if up and up.loading and now - up.loading >= LOAD_S then
      local u = up
      up = nil
      loaded(u)
    end
    -- the messages as they change
    local key = up and ((up.loading and "LOADING" or "READY") .. up.num) or ""
    if key ~= shownMsg then
      for n = 1, 2 do
        B747_cdu_fmc_condition("ROUTE " .. n .. " UPLINK READY", key == "READY" .. n, true)
        B747_cdu_fmc_condition("ROUTE " .. n .. " UPLINK LOADING", key == "LOADING" .. n, true)
      end
      shownMsg = key
    end
  end
end
-- the sim's options (2026-11-01 the user; notes/ATA-34-61-FMC.md §126):
-- the sim's conveniences, not the airplane's, from X-Plane's Plugins >
-- 747-400 menu (plugins/b747_fms_bridge: Windows): the automatic step
-- climb (at the CRZ page's AT NOW the MCP altitude STEP TO, then the
-- altitude selector's push) and the pause two minutes before the T/D
-- (B747.68.simopts_model.lua), every half second
dofile("B747.68.simopts_model.lua")
B747DR_opt_step_climb = find_dataref("laminar/B747/options/auto_step_climb")
B747DR_opt_pause_td = find_dataref("laminar/B747/options/pause_at_td")
B747DR_opt_ap_alt = find_dataref("laminar/B747/autopilot/altitude_dial_ft")
simCMD_pause_on = find_command("sim/operation/pause_on")
B747CMD_fms_press_altitude = find_command("laminar/B747/button_switch/press_altitude")
do
  local O = B747_simopts_model
  local s, nextT = O.new(), 0
  function B747_fms_simopts_update()
    local now = simDRTime
    if now < nextT then return end
    nextT = now + 0.5
    local air = simDR_onGround ~= 1
    local page, chg = B747_fms_vnav_page()
    local crz = page == 2 and chg == nil
    local on = B747DR_opt_step_climb == 1
    local step = (on and air and crz) and B747_fms_crz_step() or {}
    local act, alt = O.step(s, {on = on, air = air, vnav = B747DR_ap_vnav_state == 2, crz = crz,
      crz_alt = B747BR_cruiseAlt, mcp = B747DR_fms_vnav_mcp_alt, to = step.to, now = step.now, t = now})
    if act == "mcp" then
      -- the window and the AFDS's altitude, as the knob sets them (the
      -- second 3 s later: B747.70.xt.autopilot.lua's setSimAlt)
      B747DR_fms_vnav_mcp_alt = alt
      B747DR_opt_ap_alt = alt
    elseif act == "push" then
      B747CMD_fms_press_altitude:once()
    end
    if O.pause(s, {on = B747DR_opt_pause_td == 1, air = air, crz = page == 2, td = B747_fms_vnav_td(),
        gs = simDR_groundspeed * 1.94384}) then
      simCMD_pause_on:once()
    end
  end
end
-- (6-1/6-2 step 10d; notes/ATA-34-61-FMC.md §89) flight completion (FCOM
-- p.1236): thirty seconds after the engines' shutdown on the ground after
-- a flight (all four's N2 under the ENG FAIL speed: laminar/B747/engines/
-- inop) the active route and the load data cleared, some preflight data
-- back to their defaults: RTE 1 (FMSPG p.78), PERF INIT's entries and CRZ
-- ALT (FCOM p.1307; FMSPG p.97), FLT NO (FCOM p.1290), TAKEOFF REF's
-- (ATA34_2 p.540: its flaps too), REF NAV DATA's inhibits (FCOM
-- p.1356-1357), GPS NAV (FCOM p.1369). Estimates: APPROACH REF's flaps and
-- VREF, THRUST LIM's and the VNAV pages' selections, RTA, ENG OUT, the
-- RNP entry; X-Plane's flight plan stays (it takes none without a
-- destination). Before, nothing cleared after a flight.
local FC_DELAY_S=30
local fcFlown,fcStop=false,nil
local FC_KEYS={"fltno","grwt","fuel","zfw","reserves","costindex","crzalt","crzcg","stepsize","fuelman","gwsrc",
  "toflap","v1","vr","v2","v1sel","vrsel","v2sel","accelht","accelset","eoaccelht","eoaccelset","thrred","thrredset",
  "towind","toslope","posshift","selunit","thrustsel","thrustself","cg_mac","stab_trim","flapspeed","vref1","vref2",
  "clbspd","clbspdmach","clbspdmode","clbrestspd","clbrestalt","crzspd","crzcas","crzspdmode","stepalt",
  "desspd","desspdmach","desspdmode","desrestspd","desrestalt"}
local function renew(t,fresh)
  for k in pairs(t) do t[k]=nil end
  for k,v in pairs(fresh) do t[k]=v end
end
function B747_fms_flight_complete()
  local d=defaultFMSData()
  for _,k in ipairs(FC_KEYS) do
    if d[k]~=nil and fmsModules["data"][k]~=d[k] then fmsModules:setData(k,d[k]) end
  end
  B747_route_model.clear(B747_fmc_route)
  B747_fmc_route_changed()
  renew(rtaState,B747_rta_model.new())
  renew(eoState,B747_eo_model.new())
  renew(thrlimState,B747_thrlim_model.new())
  renew(ldgState,LA.new())
  msgInhibit=false
  local inh=B747_fmc_nav_inhibits and B747_fmc_nav_inhibits()
  if inh then inh.navaid,inh.vor,inh.vordme={},{},false end
  navperfState.gps_inhibit,navperfState.rnp_man=false,nil
  if B747DR_airspeed_flapsRef~=0 then B747DR_airspeed_flapsRef=0 end
  if B747DR_airspeed_VrefFlap~=0 then B747DR_airspeed_VrefFlap=0 end
  -- (step 12c1) TAKEOFF REF's defaults from PERF FACTORS again
  B747_fms_perf_to_take(true)
  -- (step 12c2) IRS MONITOR's rates
  B747_fms_irs_monitor_complete()
end
-- (6-1/6-2 step 11a; notes/ATA-34-61-FMC.md §90) the fuel monitoring
-- (B747.68.fuel_model.lua): each frame the FQIS (X-Plane's total fuel:
-- estimate), the fuel system's totaliser (FUEL USED: laminar/B747/fuel/
-- totaliser), the engines' fuel flow, a jettison (its nozzle valves open);
-- the FMC's quantity (perf_fuel_t: PERF INIT, the predictions), PROGRESS 2
-- read it; FUEL DISAGREE - PROG 2 and INSUFFICIENT FUEL (the predictions'
-- fuel at the destination under RESERVES, with an active route) when they
-- change (FCOM p.1273-1274, p.1381-1382, p.1432)
dofile("B747.68.fuel_model.lua")
local FM=B747_fuel_model
local fuelState=FM.new()
local fuelIn={used={0,0,0,0,0},ff={0,0,0,0}}
simDR_fms_fuel_total=find_dataref("sim/flightmodel/weight/m_fuel_total")
simDR_fms_ff=find_dataref("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")
B747DR_fms_jett_l=find_dataref("laminar/B747/fuel/jett_nozzle_vlv_L_pos")
B747DR_fms_jett_r=find_dataref("laminar/B747/fuel/jett_nozzle_vlv_R_pos")
local FUEL_DISAGREE,INSUFFICIENT_FUEL=15,17
local fuelFlags={}
function B747_fms_fuel() return fuelState end
local function fuel_inputs()
  local inp=fuelIn
  inp.fqis=simDR_fms_fuel_total
  for n=1,4 do
    inp.used[n]=B747DR_engine_used_fuel[n-1]
    inp.ff[n]=simDR_fms_ff[n-1]
  end
  inp.used[5]=B747DR_engine_used_fuel[4]
  inp.jett=B747DR_fms_jett_l>0.5 or B747DR_fms_jett_r>0.5
  local pred=B747_fmc_route.active and B747_fms_preds() or nil
  -- (2026-11-05 review 4) none with CRZ ALT at or above MAX (ATA34_2 p.611)
  inp.pred_dest=pred and not pred.no_fuel and pred.dest and pred.dest.fuel or nil
  local rsv=tonumber(fmsModules["data"].reserves)
  inp.reserves=rsv and rsv*1000 or nil
  return inp
end
local function fuel_flag(i,on)
  local v=on and 1 or 0
  if fuelFlags[i]~=v then
    fuelFlags[i]=v
    B747DR_fmc_notifications[i]=v
  end
end
function update_fuel()
  local out=FM.update(fuelState,fuel_inputs())
  fuel_flag(FUEL_DISAGREE,out.disagree)
  fuel_flag(INSUFFICIENT_FUEL,out.insufficient)
end
-- the FMC's fuel quantity, kg (nil before the first update)
function B747_fms_fuel_kg() return fuelState.out.fmc end
-- PERF INIT's FUEL entry (kg) or DELETE (nil): false when not allowed
function B747_fms_fuel_enter(kg)
  local inp=fuel_inputs()
  local ok=FM.enter(fuelState,kg,inp.fqis,inp.used)
  if ok then update_fuel() end
  return ok
end
-- PROGRESS 2's <USE and USE> (fmsFunctions.fueluse)
function B747_fms_fuel_choose(which)
  if FM.choose(fuelState,which) then update_fuel() end
end
function update_flight_complete()
  if simDR_onGround~=1 then fcFlown,fcStop=true,nil return end
  if not fcFlown then return end
  for i=0,3 do
    if B747DR_fms_eng_inop[i]<0.5 then fcStop=nil return end
  end
  local now=simDRTime
  if not fcStop or now<fcStop then fcStop=now end
  if now-fcStop>=FC_DELAY_S then
    fcFlown,fcStop=false,nil
    B747_fms_flight_complete()
  end
end
dofile("B744.notifications.lua")
dofile("irs/irs_system.lua")
dofile("B744.fms.baro.lua")
dofile("B744.fms.pages.lua")

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
-- the current waypoint (or the next): the FMC's active one's row in
-- xtlua/fms (6-1/6-2 step 6d2: fmscurrentIndex; before, X-Plane's current
-- waypoint, now its plan's last row)
function getCurrentWayPoint(fms,usenext)
	local i=B747DR_fmscurrentIndex
	if i<1 or i>table.getn(fms) or (i<=1 and not B747_fmc_route.active) then return "" end  --NOT FOUND
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
-- (2026-11-13; the 2026-11-12 review DSP-2) the transition level in the
-- FMC's data ("translvl") for the PFD's barometric setting's amber box and
-- the ND's DATA (FCOM p.995, p.1396): DESCENT FORECAST's TRANS LVL
-- (B747_fms_trans_lvl: the crew's entry, the arrival's, the destination's
-- data, else FL180), once a second when it changes. Before, the displays
-- took FL180 for every descent (17,600 ft for RJAA's FL140)
local trans_lvl_t = -1
function B747_fms_publish_trans_lvl()
	if simDRTime - trans_lvl_t < 1 and simDRTime >= trans_lvl_t then return end
	trans_lvl_t = simDRTime
	local v = B747_fms_trans_lvl and tonumber(B747_fms_trans_lvl()) or 18000
	local s = string.format("%d", math.floor(v + 0.5))
	if (string.gsub(fmsModules["data"]["translvl"] or "", "%s+$", "")) ~= s then setFMSData("translvl", s) end
end
function B747_route_eta(fms, airborne)
	if simDRTime - route_eta_t < 1 and simDRTime >= route_eta_t then return end
	route_eta_t = simDRTime
	local out = {}
	-- the active waypoint's row (step 6d2: the FMC's, not X-Plane's current
	-- waypoint, its plan's last row now)
	local active = nil
	local k = B747DR_fmscurrentIndex
	if k >= 1 and k <= table.getn(fms) then active = k end
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
		B747_fms_publish_trans_lvl()
	else
		B747DR_destination="----"	
		if B747DR_fms_route_eta ~= "[]" then B747DR_fms_route_eta = "[]" end
		B747_fms_publish_trans_lvl()
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

-- (2026-11-05 review) POS INIT's LAST POS from the livery's file: read
-- once per livery (the file changes only when the aircraft unloads).
-- Before, POS INIT called this in every frame it was drawn, on each CDU (a
-- file opened and read 60-120 times a second while the page showed, on
-- the plugin's thread), switched the Lua state's default input and output,
-- and an empty file put nil in the FMS data (the next read of LAST POS
-- stopped the plugin)
local lastPosRead=nil
function aircraft_last_pos(phase)
	local file_location = simDR_livery_path.."B747-400_lastpos.dat"

	if phase == "LOAD" then
		--Load FMC last position
		if lastPosRead == file_location then return end
		lastPosRead = file_location
		local file = io.open(file_location, "r")
		if file ~= nil then
			local pos = file:read("*l")
			file:close()
			if pos ~= nil then fmsModules["data"].lastpos = pos end
		end
	else  --UNLOAD
		local file = io.open(file_location, "w+")
		if file ~= nil then
			file:write(irsSystem.getLat("gpsL") .." " .. irsSystem.getLon("gpsL"))
			file:close()
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
	renew(ldgState,LA.new())
	msgInhibit=false
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
	-- (6-1/6-2 step 12c1) the FMC's start: TAKEOFF REF's defaults from PERF
	-- FACTORS
	B747_fms_perf_to_take(true)
end

debug_fms     = find_dataref("laminar/B747/debug/fms")
fms_style = find_dataref("sim/cockpit2/radios/indicators/fms_cdu1_style_line2")
-- the FMC's messages each frame from laminar/B747/fms/notification's flags
-- into the CDUs' message list (B744.createfms.lua); >FMC MESSAGE while an
-- alert waits (FCOM p.1429-1430; 6-1/6-2 step 2: before, one flag every
-- ten seconds, any message, and CLR cleared the flag)
function setNotifications()
  B747_cdu_sync_fmc_messages(B747DR_fmc_notifications)
  -- (6-1/6-2 step 11d1) none without an FMC
  B747DR_CAS_advisory_status[145] = (B747_cdu_fmc_alert() and B747_fms_any_fmc()) and 1 or 0
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
B747DR_fms_irs_hdg_valid				= find_dataref("laminar/B747/irs/hdg_valid")
-- The in-flight start (a sim convenience) waits for the IRUs and the ADCs,
-- whose modules start 3 s after the load (their first reads are 0), about
-- when it runs: F/D L for two IRUs' headings (its HDG HOLD with fewer fails
-- until a new mode: the mode failures, 6-3 step 5c; 2026-11-01: s179's air
-- start kept HDG HOLD failed), CMD L pressed again until it engages (the
-- engage interlocks, 6-3 step 5a); each INFLIGHT_AP_TRIES times
-- INFLIGHT_AP_S apart. At an interval that stops itself: XTLua ends a
-- run_after_time after its function, so one set again from its own
-- function never ran again (XTLua/src/xptimers.cpp; 2026-11-01: s180
-- without the F/D, and CMD L was never pressed again)
local INFLIGHT_AP_TRIES, INFLIGHT_AP_S = 60, 0.5
local INFLIGHT_IRU_HDG = 2

local inflightAP_tries = 0
function retry_inflightAP_cmd()
	if B747DR_fms_ap_cmd_L > 0.5 or inflightAP_tries >= INFLIGHT_AP_TRIES then
		stop_timer(retry_inflightAP_cmd)
		return
	end
	inflightAP_tries = inflightAP_tries + 1
	B747CMD_ap_switch_cmd_L:once()
end
function fin_activate_inflightAP()
	-- ALT HOLD after the F/D's default V/S and HDG HOLD (the AFDS model,
	-- 6-3 step 1a), then the A/P in the F/D's modes
	B747CMD_ap_switch_alt_hold_mode:once()
	B747CMD_ap_switch_cmd_L:once()
	inflightAP_tries = 0
	run_at_interval(retry_inflightAP_cmd, INFLIGHT_AP_S)
	B747DR_ap_target_altitude=math.floor(simDR_pressureAlt1/100)*100
	
	B747DR_CAS_advisory_status[233] = 0
	B747DR_pfd_mode_capt		 = 1
	B747DR_pfd_mode_fo		 = 1
end
function wait_inflightAP()
	local hdg = 0
	for i = 0, 2 do
		if B747DR_fms_irs_hdg_valid[i] > 0.5 then hdg = hdg + 1 end
	end
	if hdg < INFLIGHT_IRU_HDG and inflightAP_tries < INFLIGHT_AP_TRIES then
		inflightAP_tries = inflightAP_tries + 1
		return
	end
	stop_timer(wait_inflightAP)
	activate_inflightAP()
end
function activate_inflightAP()
	-- idempotent (it may run twice around an air start re-done): F/D L ON
	-- only when OFF (its switch toggles), the A/T by its arm command
	if B747DR_fms_toggle_sw[23] < 0.5 then B747CMD_flight_dir_switch_L:once() end
	B747CMD_autothrottle_arm:once()
	-- the MCP's speed the airspeed now, not below the old minimum (Vmc +
	-- 10); before (min) any faster air start wound the window down to
	-- Vmc + 10, about 214 kt flaps up (2026-11-02, notes/ATA-22.md)
	B747DR_ap_target_speed=math.floor(math.max(simDR_ias_pilot,B747DR_airspeed_Vmc+10))
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
  -- (2026-11-05) the sim's weight and balance window's load (B744.fms.pages.lua):
  -- from the start, without the FMCs' power or warm-up (the sim's, as the
  -- CDU's PAX/CARGO data)
  B747_fms_wb_update()
  -- the FMCs from the start (6-1/6-2 step 11d2b: fmc_ok for the NDs and the
  -- AFDS before the systems' warm-up)
  update_fmc_link()
  -- (step 3d) VREF for the PFDs from the start too
  update_vref()
  if systemsWarmedUp==false and simDR_startup_running == 1 and is_timer_scheduled(alignIRSs) == false then 
	run_after_time(alignIRSs,1)
	return
  end
  if systemsWarmedUp==false then return end
  local refreshmins=B747DR_airspeed_Vmc
  if didFlightInit==false and simDR_startup_running == 1 and simDR_xp_onGround==0 then
	print("activate AP stuff")
	-- a second on, then each INFLIGHT_AP_S until the IRUs' headings; an
	-- in-flight start not yet over (an air start re-done) stops
	stop_timer(retry_inflightAP_cmd)
	stop_timer(fin_activate_inflightAP)
	inflightAP_tries = 0
	run_timer(wait_inflightAP, 1, INFLIGHT_AP_S)
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
    update_appr_ref()
    update_flight_complete()
    update_fuel()
    update_ldgalt()
    update_msg_inhibit()
    update_nav_msgs()
    update_altn_nav()
    B747_fmc_lnav_update()
    B747_fmc_route_sync()
    B747_fmc_nd_line()
    B747_fmc_plan_ctr_sync()
    B747_fmc_exec_lights()
    B747DR_FMSdata=json.encode(fmsModules["data"]["values"])--make the fms data available to other modules
    --print(B747DR_FMSdata)
    -- (6-1/6-2 step 12c1) PERF FACTORS' factors and margin; (step 12c2)
    -- IRS MONITOR's liftoff
    B747_fms_perf_factors_update()
    B747_fms_irs_monitor_update()
    -- (6-1/6-2 step 12b) the automatic page changes (B744.createfms.lua)
    B747_cdu_page_changes(B747_fms_vnav_page())
    fmsL:B747_fms_display()
    fmsC:B747_fms_display()
    fmsR:B747_fms_display()
    -- (1-1) by the 747's buses (notes/ATA-34-61-FMC.md §144): the IRUs'
    -- status for the CDU and the ND while an FMC's bus is powered, failed
    -- FMC or not; the navigation while an FMC works; the tuning by the
    -- selected FMC. Before, all three while X-Plane's bus 0 was above 22 V
    if B747_fms_bus_powered() then irsSystem.update() end
    if B747_fms_any_fmc() then
      update_navperf()
      if B747_fms_master_ok() then update_tuning() end
    end
    local acarsOnline=acarsSystem.provider.online()
    if acarsOnline then
      acars=1 --for radio
      acarsSystem.provider.receive()
	  acarsSystem.provider.send()
	  acarsSystem.remote.receive()
	  --acarsSystem.remote.send()
    else
      acars=0 --for radio
    end
    -- (6-1/6-2 step 12d1) the datalink's EICAS messages (before: ACARS
    -- MESSAGE for any message, the ACARS NO COMM memo offline); (step 12e)
    -- the ATC logon
    B747_fms_datalink_eicas(acarsOnline)
    B747_fms_atc_update()
    B747_fms_atc_uplinks_update()
    -- (step 12g2a) the requests' acknowledgements; (step 12g3b) POS
    -- REPORT's
    B747_fms_atc_requests_update()
    B747_fms_posrep_update()
    -- (step 12g3c) the ATC reports; (step 12g4) the emergency reports
    B747_fms_reports_update()
    B747_fms_emergency_update()
    -- (step 12h1) the company's flight plan uplink
    B747_fms_company_update()
    -- the sim's options: the automatic step climb, the pause before the T/D
    B747_fms_simopts_update()

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
