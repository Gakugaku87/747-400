--Read out and set displays for ND icons
-- (C) Mark 'mSparks' Parker 2020 CCBYNC4 release
-- Small changes by Matt726
simDR_version=find_dataref("sim/version/xplane_internal_version")
B747DR_nd_pln_capt                 = find_dataref("laminar/B747/nd/pln/capt")
B747DR_nd_pln_fo                 = find_dataref("laminar/B747/nd/pln/fo")
simDR_variation = find_dataref("sim/flightmodel/position/magnetic_variation")
simDR_tcas_lat                = find_dataref("sim/cockpit2/tcas/targets/position/lat")
simDR_tcas_lon                = find_dataref("sim/cockpit2/tcas/targets/position/lon")
simDR_tcas_alt                = find_dataref("sim/cockpit2/tcas/targets/position/ele")
simDR_radarAlt1 = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
simDR_tcas_vs                = find_dataref("sim/cockpit2/tcas/targets/position/vertical_speed")
simDR_radio_nav03_ID                = find_dataref("sim/cockpit2/radios/indicators/nav3_nav_id")
simDR_radio_nav04_ID                = find_dataref("sim/cockpit2/radios/indicators/nav4_nav_id")
B747DR_text_capt_show 				= find_dataref("laminar/B747/nd/capt/text/show")
B747DR_text_capt_heading			= find_dataref("laminar/B747/nd/capt/text/heading")
B747DR_text_capt_distance			= find_dataref("laminar/B747/nd/capt/text/distance")
--B747DR_text_capt_icon				= find_dataref("laminar/B747/nd/capt/text/icon","array[60]")
B747DR_nd_mode_capt_sel_dial_pos                = find_dataref("laminar/B747/nd/mode/capt/sel_dial_pos", "number")
B747DR_nd_mode_fo_sel_dial_pos                  = find_dataref("laminar/B747/nd/mode/fo/sel_dial_pos", "number")
B747DR_text_fo_show 				= find_dataref("laminar/B747/nd/fo/text/show")
B747DR_text_fo_heading			= find_dataref("laminar/B747/nd/fo/text/heading")
B747DR_text_fo_distance			= find_dataref("laminar/B747/nd/fo/text/distance")
--B747DR_text_fo_icon				= find_dataref("laminar/B747/nd/fo/text/icon","array[60]")
B747DR_fmscurrentIndex      = find_dataref("laminar/B747/autopilot/ap_monitor/fmscurrentIndex")
B747BR_totalDistance 			= find_dataref("laminar/B747/autopilot/dist/remaining_distance")
B747BR_eod_index 			= find_dataref("laminar/B747/autopilot/dist/eod_index")
B747BR_nextDistanceInFeet 		= find_dataref("laminar/B747/autopilot/dist/next_distance_feet")
B747BR_cruiseAlt 			= find_dataref("laminar/B747/autopilot/dist/cruise_alt")
B747BR_tod				= find_dataref("laminar/B747/autopilot/dist/top_of_descent")
B747BR_todLat				= find_dataref("laminar/B747/autopilot/dist/top_of_descent_lat")
B747BR_todLong				= find_dataref("laminar/B747/autopilot/dist/top_of_descent_long")
B747BR_tocLat				= find_dataref("laminar/B747/autopilot/dist/top_of_climb_lat")
B747BR_tocLong				= find_dataref("laminar/B747/autopilot/dist/top_of_climb_long")
B747BR_toc				= find_dataref("laminar/B747/autopilot/dist/distance_to_toc")
B747DR_ap_FMA_active_pitch_mode     	= find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
simDR_autopilot_vs_fpm = find_dataref("sim/cockpit2/autopilot/vvi_dial_fpm")
simDR_autopilot_alt_hold_status = find_dataref("laminar/B747/autopilot/altitude_hold_status")

B747DR_text_capt_wxrtext			= find_dataref("laminar/B747/nd/capt/text/wxr")
B747DR_text_fo_wxrtext			= find_dataref("laminar/B747/nd/fo/text/wxr")
B747DR_text_capt_wxrtilt			= find_dataref("laminar/B747/nd/capt/text/tilt")
B747DR_text_fo_wxrtilt			= find_dataref("laminar/B747/nd/fo/text/tilt")
B747DR_text_capt_wxr3			= find_dataref("laminar/B747/nd/capt/text/wxr3")
B747DR_text_fo_wxr3			= find_dataref("laminar/B747/nd/fo/text/wxr3")
B747DR_text_capt_wxr_color		= find_dataref("laminar/B747/nd/capt/text/wxr_color")
B747DR_text_fo_wxr_color		= find_dataref("laminar/B747/nd/fo/text/wxr_color")
-- the weather radar model's annunciations for each ND (B747.34.xt.wxr.lua)
B747DR_wxr_nd_fail				= find_dataref("laminar/B747/wxr/nd_fail")
B747DR_wxr_nd_fault				= find_dataref("laminar/B747/wxr/nd_fault")
B747DR_wxr_nd_msg				= find_dataref("laminar/B747/wxr/nd_msg")
B747DR_wxr_nd_gain				= find_dataref("laminar/B747/wxr/nd_gain")
simDR_wxrMode_cpt = find_dataref("sim/cockpit2/EFIS/EFIS_weather_mode")
simDR_wxrMode_fo = find_dataref("sim/cockpit2/EFIS/EFIS_weather_mode_copilot")
simDR_wxrTilt_cpt = find_dataref("sim/cockpit2/EFIS/EFIS_weather_tilt")
simDR_wxrTilt_fo = find_dataref("sim/cockpit2/EFIS/EFIS_weather_tilt_copilot")
iconTextDataCapt={}
iconTextDataCapt.icons=find_dataref("laminar/B747/nd/capt/text/icon")
for n=0,59,1 do
  iconTextDataCapt[n]={}
  iconTextDataCapt[n].whitetext=find_dataref("laminar/B747/nd/capt/text/whitetext"..n)
  iconTextDataCapt[n].bluetext=find_dataref("laminar/B747/nd/capt/text/bluetext"..n)
  iconTextDataCapt[n].redtext=find_dataref("laminar/B747/nd/capt/text/redtext"..n)
  iconTextDataCapt[n].greentext=find_dataref("laminar/B747/nd/capt/text/greentext"..n)
end

iconTextDataFO={}
iconTextDataFO.icons=find_dataref("laminar/B747/nd/fo/text/icon")
for n=0,59,1 do
  iconTextDataFO[n]={}
  iconTextDataFO[n].whitetext=find_dataref("laminar/B747/nd/fo/text/whitetext"..n)
  iconTextDataFO[n].bluetext=find_dataref("laminar/B747/nd/fo/text/bluetext"..n)
  iconTextDataFO[n].redtext=find_dataref("laminar/B747/nd/fo/text/redtext"..n)
  iconTextDataFO[n].greentext=find_dataref("laminar/B747/nd/fo/text/greentext"..n)
end

-- the route data (5-2 step 5c, B747.61.nd_data.lua): each side's DATA
-- switch, the first slots' colour and two lines, the FMC's ETA for each route
-- entry and its transition altitude
dofile("B747.61.nd_data.lua")
local ND_DATA = B747_nd_data
B747DR_nd_capt_data_sel = find_dataref("laminar/B747/nd/data/capt/data")
B747DR_nd_fo_data_sel = find_dataref("laminar/B747/nd/data/fo/data")
B747DR_nd_fms_route_eta = find_dataref("laminar/B747/fms/route_eta")
B747DR_nd_fms_data = find_dataref("laminar/B747/fms/data")
iconTextDataCapt.rdata=find_dataref("laminar/B747/nd/capt/text/rdata_color")
iconTextDataFO.rdata=find_dataref("laminar/B747/nd/fo/text/rdata_color")
for n=0,ND_DATA.SLOTS-1,1 do
  iconTextDataCapt[n].rdata1=find_dataref("laminar/B747/nd/capt/text/rdata1_"..n)
  iconTextDataCapt[n].rdata2=find_dataref("laminar/B747/nd/capt/text/rdata2_"..n)
  iconTextDataFO[n].rdata1=find_dataref("laminar/B747/nd/fo/text/rdata1_"..n)
  iconTextDataFO[n].rdata2=find_dataref("laminar/B747/nd/fo/text/rdata2_"..n)
end
local routeEta={}
local transAlt=ND_DATA.TRANS_ALT_FT

-- TCAS traffic (5-1 step 5b): each ND's 30 TCAS slots (B747.61.nd init),
-- filled from the TCAS model's symbols (laminar/B747/tcas/sym,
-- plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.tcas.lua) and X-Plane's
-- TCAS targets while that ND draws traffic (nd/capt|fo/tcas_show)
simDR_tcas_ssr                = find_dataref("sim/cockpit2/tcas/targets/ssr_mode")
B747DR_tcas_sym               = find_dataref("laminar/B747/tcas/sym")
B747DR_nd_capt_tcas_on        = find_dataref("laminar/B747/nd/capt/tcas_show")
B747DR_nd_fo_tcas_on          = find_dataref("laminar/B747/nd/fo/tcas_show")
tcasCapt={}
tcasCapt.show=find_dataref("laminar/B747/nd/capt/tcas/show")
tcasCapt.heading=find_dataref("laminar/B747/nd/capt/tcas/heading")
tcasCapt.distance=find_dataref("laminar/B747/nd/capt/tcas/distance")
tcasCapt.sym=find_dataref("laminar/B747/nd/capt/tcas/sym")
tcasCapt.color=find_dataref("laminar/B747/nd/capt/tcas/tag_color")
tcasCapt.dy=find_dataref("laminar/B747/nd/capt/tcas/tag_dy")
tcasCapt.tags={}
for n=0,29,1 do tcasCapt.tags[n]=find_dataref("laminar/B747/nd/capt/tcas/tag"..n) end
tcasFO={}
tcasFO.show=find_dataref("laminar/B747/nd/fo/tcas/show")
tcasFO.heading=find_dataref("laminar/B747/nd/fo/tcas/heading")
tcasFO.distance=find_dataref("laminar/B747/nd/fo/tcas/distance")
tcasFO.sym=find_dataref("laminar/B747/nd/fo/tcas/sym")
tcasFO.color=find_dataref("laminar/B747/nd/fo/tcas/tag_color")
tcasFO.dy=find_dataref("laminar/B747/nd/fo/tcas/tag_dy")
tcasFO.tags={}
for n=0,29,1 do tcasFO.tags[n]=find_dataref("laminar/B747/nd/fo/tcas/tag"..n) end

navAidsJSON   = find_dataref("xtlua/navaids")
fmsJSON = find_dataref("xtlua/fms")
xpFMSDataJSON = find_dataref("xtlua/xpFMSData")
simDRTime=find_dataref("sim/time/total_running_time_sec")
simDR_latitude				= find_dataref("sim/flightmodel/position/latitude")
simDR_longitude				= find_dataref("sim/flightmodel/position/longitude")
simDR_true_heading			= find_dataref("sim/flightmodel/position/psi")
simDR_mag_heading			= find_dataref("sim/cockpit/gyros/psi_ind_ahars_pilot_degm")
simDR_ground_track			= find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
simDR_heading_track			= find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
-- each ND from its own side and mode (5-2 step 5a)
simDR_heading_copilot			= find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_copilot")
simDR_ground_track_copilot		= find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_copilot")
B747DR_nd_mode_capt			= find_dataref("laminar/B747/nd/mode/capt/sel_dial_pos")
B747DR_nd_mode_fo			= find_dataref("laminar/B747/nd/mode/fo/sel_dial_pos")
B747DR_nd_terr_weather_capt                  		= find_dataref("laminar/B747/nd/terr_weather/capt")
B747DR_nd_terr_weather_fo                  		= find_dataref("laminar/B747/nd/terr_weather/fo")
B747DR_nd_capt_terr                          = find_dataref("laminar/B747/nd/data/capt/terr")
B747DR_nd_fo_terr                          	= find_dataref("laminar/B747/nd/data/fo/terr")
simDR_EFIS_wxr_on                   = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on")
simDR_EFIS_wxr_on_copilot           = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on_copilot")
B747DR_nd_capt_up                  		= find_dataref("laminar/B747/nd/up/capt")
B747DR_nd_fo_up                  		= find_dataref("laminar/B747/nd/up/fo")

simDR_map_range				= find_dataref("sim/cockpit2/EFIS/map_range")
simDR_map_mode				= find_dataref("sim/cockpit2/EFIS/map_mode")
simDR_map_range_copilot				= find_dataref("sim/cockpit2/EFIS/map_range_copilot")
simDR_map_mode_copilot				= find_dataref("sim/cockpit2/EFIS/map_mode_copilot")
backport_map_mode_copilot = 0
backport_map_range_copilot = 0
simDR_range_dial_capt			= find_dataref("laminar/B747/nd/range/capt/sel_dial_pos")
simDR_range_dial_fo			= find_dataref("laminar/B747/nd/range/fo/sel_dial_pos")
B747_nd_map_center_capt                 = find_dataref("laminar/B747/nd/map_center/capt")
B747_nd_map_center_fo                   = find_dataref("laminar/B747/nd/map_center/fo")
B747DR_nd_capt_vor_ndb                  = find_dataref("laminar/B747/nd/data/capt/vor_ndb")
B747DR_nd_fo_vor_ndb                    = find_dataref("laminar/B747/nd/data/fo/vor_ndb")
B747DR_nd_capt_wpt                  = find_dataref("laminar/B747/nd/data/capt/wpt")
B747DR_nd_fo_wpt                    = find_dataref("laminar/B747/nd/data/fo/wpt")
B747DR_nd_capt_apt	                = find_dataref("laminar/B747/nd/data/capt/apt")
B747DR_nd_fo_apt	                = find_dataref("laminar/B747/nd/data/fo/apt")
B747DR_pfd_mode_capt		 = find_dataref("laminar/B747/pfd/capt/irs")
B747DR_pfd_mode_fo		 = find_dataref("laminar/B747/pfd/fo/irs")
B747DR_nd_capt_tfc	                        = find_dataref("laminar/B747/nd/capt/tfc")
B747DR_nd_fo_tfc	                        = find_dataref("laminar/B747/nd/fo/tfc")

simDR_groundspeed			                      = find_dataref("sim/flightmodel2/position/groundspeed")
simDR_vvi_fpm_pilot        	                = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_autopilot_altitude_ft    		          = find_dataref("laminar/B747/autopilot/altitude_dial_ft") -- alternate might better MCP which is B747DR_autopilot_altitude_ft
simDR_pressureAlt1	                        = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
--B747DR_nd_alt_distance                  		= find_dataref("laminar/B747/nd/toc/distance")
B747DR_nd_alt_distance_fo                  		= find_dataref("laminar/B747/nd/toc/distance/fo")
B747DR_nd_alt_distance_capt                  		= find_dataref("laminar/B747/nd/toc/distance/capt")
B747DR_nd_alt_fo_active			                = find_dataref("laminar/B747/nd/toc/fo_active")
B747DR_nd_alt_capt_active			              = find_dataref("laminar/B747/nd/toc/capt_active")

local display_latitude_cpt=0
local display_latitude_fo=0
local display_longitude_cpt=0
local display_longitude_fo=0
local captIRS=0
local foIRS=0
local ranges = {10, 20, 40, 80, 160, 320, 640}
local usedNaviadsTableFO={}
local usedNaviadsTableCapt={}
local currentNaviadsTable={}
local fmsTable={}
local lastCaptNavaid=0
local lastFONavaid=0
local lastUpdate=0
local lastUpdateIcon=0
local lastUpdateFixes=0
local nLength=0
local numFixes=0
local localFixes={}
local scansize=1000
dofile("json/json.lua")
dofile("numberlua.lua")
function livery_load()
  scansize=1000
end

function decodeNAVAIDS()
  if string.len(navAidsJSON) ~= nLength then
      currentNaviadsTable=json.decode(navAidsJSON)
      nLength=string.len(navAidsJSON)
  end
end

function decodeFlightPlan()
  if string.len(fmsJSON) >0 then
      fmsTable=json.decode(fmsJSON)
  end
  -- the FMC's ETA for each route entry and its transition altitude (step 5c)
  local e=B747DR_nd_fms_route_eta
  if type(e)=="string" and string.len(e)>1 then routeEta=json.decode(e) else routeEta={} end
  local d=B747DR_nd_fms_data
  transAlt=(type(d)=="string" and tonumber(d:match('"transalt"%s*:%s*"?(%d+)'))) or ND_DATA.TRANS_ALT_FT
end
function getHeading(lat1,lon1,lat2,lon2)
  b10=math.rad(lat1)
  b11=math.rad(lon1)
  b12=math.rad(lat2)
  b13=math.rad(lon2)
  retVal=math.atan2(math.sin(b13-b11)*math.cos(b12),math.cos(b10)*math.sin(b12)-math.sin(b10)*math.cos(b12)*math.cos(b13-b11))
  return math.deg(retVal)
end
function getHeadingDifference(desireddirection,current_heading)
	error = current_heading - desireddirection
	if (error >  180) then error =error- 360 end
	if (error < -180) then error =error+ 360 end
	return error
end

-- each ND's top (5-2 step 5a; the rule of B747.60.nd_model.lua's
-- orientation, FCOM p.1109-1110 for the 109): MAP that side's track, VOR
-- and APP its heading, PLN north
function nd_up(mode,hdg,trk)
  if mode==2 then return trk end
  if mode==3 then return 0 end
  return hdg
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
function makeIcon(iconTextData,navtype,text,latitude,longitude,distance,routeIndex)
  if text~=nil and string.lower(text)~="latlong" and iconTextData==iconTextDataCapt and usedNaviadsTableCapt[text]~=nil then return end
  if text~=nil and string.lower(text)~="latlong" and iconTextData==iconTextDataFO and usedNaviadsTableFO[text]~=nil then return end
  if text~=nil and string.lower(text)=="latlong" then text=" " end
  if text~=nil and string.lower(text)=="latlon" then text=" " end
  local cLat=display_latitude_cpt
  local cLon=display_longitude_cpt
  if iconTextData~=iconTextDataCapt then
    cLat=display_latitude_fo
    cLon=display_longitude_fo
  end

  local abs_heading=getHeading(cLat,cLon,latitude,longitude)
  local heading_diff=0
  -- the symbol's bearing from the display's top, as nd_up orients it (step
  -- 5a): that side's track (MAP) or heading (VOR, APP) made true with the
  -- variation; PLN north up as before
  local mode, trk, hdg = B747DR_nd_mode_capt, simDR_ground_track, simDR_heading_track
  if iconTextData~=iconTextDataCapt then
    mode, trk, hdg = B747DR_nd_mode_fo, simDR_ground_track_copilot, simDR_heading_copilot
  end
  local mag_diff=getHeadingDifference(simDR_true_heading,simDR_mag_heading)
  if mode==2 then
    heading_diff=getHeadingDifference(trk-mag_diff,abs_heading)
  elseif mode==3 then
    heading_diff=abs_heading+simDR_variation
  else
    heading_diff=getHeadingDifference(hdg-mag_diff,abs_heading)
  end
  
  local lastNavaid=0
  local vor_ndb=0
  local wpt=0
  local apt=0
  local displayDistance=0
  local range=0
  if iconTextData==iconTextDataCapt then
    if captIRS==0 then return end
    range=ranges[simDR_range_dial_capt + 1]
    displayDistance=distance*(640/ranges[simDR_range_dial_capt + 1])
    if (heading_diff < -90 or heading_diff > 90) and B747_nd_map_center_capt<1 then return end
    if (heading_diff < -135 or heading_diff > 135) and displayDistance> 160 and B747_nd_map_center_capt<1 then return end
    if displayDistance> 250 and B747_nd_map_center_capt>0 and simDR_map_mode~=4 then return end
    if displayDistance > 450 and simDR_map_mode==4 then return end
    if (heading_diff < -45 or heading_diff > 45) and displayDistance> 480 and B747_nd_map_center_capt<1 then return end
    if (heading_diff < -55 or heading_diff > 55) and displayDistance> 400 and B747_nd_map_center_capt<1 then return end
    lastNavaid=lastCaptNavaid
    apt=B747DR_nd_capt_apt
    vor_ndb=B747DR_nd_capt_vor_ndb
    wpt=B747DR_nd_capt_wpt
  else
    if foIRS==0 then return end
    range=ranges[simDR_range_dial_fo + 1]
    displayDistance=distance*(640/ranges[simDR_range_dial_fo + 1])
    if (heading_diff < -90 or heading_diff > 90) and B747_nd_map_center_fo<1 then return end 
    if (heading_diff < -135 or heading_diff > 135) and displayDistance> 160 and B747_nd_map_center_fo<1 then return end 
     if displayDistance> 250 and B747_nd_map_center_fo>0 and backport_map_mode_copilot~=4 then return end
     if displayDistance > 450 and backport_map_mode_copilot==4 then return end
     if (heading_diff < -45 or heading_diff > 45) and displayDistance> 480 and B747_nd_map_center_fo<1 then return end
     if (heading_diff < -55 or heading_diff > 55) and displayDistance> 400 and B747_nd_map_center_fo<1 then return end
    lastNavaid=lastFONavaid
    apt=B747DR_nd_fo_apt
    vor_ndb=B747DR_nd_fo_vor_ndb
    wpt=B747DR_nd_fo_wpt
  end
  
  if lastNavaid > 59 then return end
  
  if navtype==1 and apt>0 then --airport
    iconTextData.icons[lastNavaid]=2
    iconTextData[lastNavaid].bluetext=text
    iconTextData[lastNavaid].whitetext=" "
    iconTextData[lastNavaid].redtext=" "
    iconTextData[lastNavaid].greentext=" "
  elseif navtype==3003 then --current FMS waypoint
    iconTextData.icons[lastNavaid]=4
    iconTextData[lastNavaid].whitetext=" "
    iconTextData[lastNavaid].bluetext=" "
    iconTextData[lastNavaid].redtext=text
    iconTextData[lastNavaid].greentext=" "
  elseif navtype==3005 then --non current FMS waypoint
    iconTextData.icons[lastNavaid]=5
    iconTextData[lastNavaid].whitetext=text
    iconTextData[lastNavaid].bluetext=" "
    iconTextData[lastNavaid].redtext=" "
    iconTextData[lastNavaid].greentext=" "
  elseif (navtype==3007) then --FIX
    if range>40 or wpt==0 then return end
    iconTextData.icons[lastNavaid]=13
    iconTextData[lastNavaid].bluetext=text
    iconTextData[lastNavaid].whitetext=" "
    iconTextData[lastNavaid].redtext=" "
    iconTextData[lastNavaid].greentext=" " 
  elseif (navtype==3008) then --TOD
    iconTextData.icons[lastNavaid]=8
    iconTextData[lastNavaid].bluetext=" "
    iconTextData[lastNavaid].whitetext=" " 
    iconTextData[lastNavaid].redtext=" "
    iconTextData[lastNavaid].greentext=text 
  elseif bit_and(navtype,4)>0 and vor_ndb>0 then
    iconTextData.icons[lastNavaid]=11
    if text==simDR_radio_nav03_ID or text==simDR_radio_nav04_ID then
      iconTextData.icons[lastNavaid]=10
      iconTextData[lastNavaid].bluetext=" "
      iconTextData[lastNavaid].greentext=text
    else
      iconTextData.icons[lastNavaid]=11
      iconTextData[lastNavaid].bluetext=text
      iconTextData[lastNavaid].greentext=" "
    end
    
    iconTextData[lastNavaid].whitetext=" "
    iconTextData[lastNavaid].redtext=" "
    
  elseif navtype==2 and vor_ndb>0 then
    iconTextData.icons[lastNavaid]=0
    iconTextData[lastNavaid].bluetext=text
    iconTextData[lastNavaid].whitetext=" "
    iconTextData[lastNavaid].redtext=" "
    iconTextData[lastNavaid].greentext=" " 
  else
    return
  end
  iconTextData[lastNavaid].latitude=latitude
  iconTextData[lastNavaid].longitude=longitude
  -- the first slots' route data lines (step 5c): a route waypoint's (its
  -- index in the route) with that side's DATA switch on
  if lastNavaid < ND_DATA.SLOTS then
    local sel=B747DR_nd_capt_data_sel
    if iconTextData~=iconTextDataCapt then sel=B747DR_nd_fo_data_sel end
    local on=routeIndex~=nil and sel>0.5
    local alt, eta
    if on then
      alt=ND_DATA.alt_text(fmsTable[routeIndex][9], transAlt)
      eta=ND_DATA.eta_text(routeEta[routeIndex])
    end
    local c, l1, l2=ND_DATA.lines(on, navtype==3003, alt, eta)
    if iconTextData.rdata[lastNavaid]~=c then iconTextData.rdata[lastNavaid]=c end
    local s=iconTextData[lastNavaid]
    if s.rdata1~=l1 then s.rdata1=l1 end
    if s.rdata2~=l2 then s.rdata2=l2 end
  end
  if iconTextData==iconTextDataCapt then
    B747DR_text_capt_show[lastNavaid]=1
    B747DR_text_capt_heading[lastNavaid]=heading_diff
    B747DR_text_capt_distance[lastNavaid]=displayDistance
    lastCaptNavaid=lastCaptNavaid+1
    if text~=nil then usedNaviadsTableCapt[text]=true end
  else
     B747DR_text_fo_show[lastNavaid]=1
     B747DR_text_fo_heading[lastNavaid]=heading_diff
     B747DR_text_fo_distance[lastNavaid]=displayDistance
     lastFONavaid=lastFONavaid+1
     if text~=nil then usedNaviadsTableFO[text]=true end
  end
  
end

function updateIcon(iconData,n,isCaptain)
  local cLat=display_latitude_cpt
  local cLon=display_longitude_cpt
  if isCaptain~=1 then
    cLat=display_latitude_fo
    cLon=display_longitude_fo
  end
   local distance = getDistance(cLat,cLon,iconData[n].latitude,iconData[n].longitude)
  local abs_heading=getHeading(cLat,cLon,iconData[n].latitude,iconData[n].longitude)
  local heading_diff=0
  if (simDR_map_mode==2 and isCaptain==1) or (backport_map_mode_copilot==2 and isCaptain==0) then
    mag_diff=getHeadingDifference(simDR_true_heading,simDR_mag_heading)
    heading_diff=getHeadingDifference(simDR_ground_track-mag_diff,abs_heading)
  elseif (simDR_map_mode==4 and isCaptain==1) or (backport_map_mode_copilot==4 and isCaptain==0) then
    heading_diff=abs_heading+simDR_variation
  else
    heading_diff=getHeadingDifference(simDR_true_heading,abs_heading)
  end
  if isCaptain==1 then
    displayDistance=distance*(640/ranges[simDR_range_dial_capt + 1])
    B747DR_text_capt_heading[n]=heading_diff
    B747DR_text_capt_distance[n]=displayDistance
  else
     displayDistance=distance*(640/ranges[simDR_range_dial_fo + 1])
     B747DR_text_fo_heading[n]=heading_diff
     B747DR_text_fo_distance[n]=displayDistance

  end
end
-- the weather radar's annunciations (FCOM p.1155; 5-1 steps 5c, 5d), shown
-- with this side's WXR in MAP, MAP CTR and VOR and APP not centred (ATA34_1
-- p.244), three lines in cyan or amber:
--  - WXR FAIL in amber (the R/T, the antenna or the control panel: no
--    returns, ATA34_1 p.246);
--  - the mode, then the tilt in whole degrees ("+5": FCOM p.1013-1018);
--    in TEST the tilt field shows the fault source in amber (FCOM p.1224);
--  - the third line: WEAK or ATT in amber (the returns stay: ATA34_1
--    p.246), or the gain in MAP, CAL or VAR (the radar model's estimate)
local WXR_MODE_TEXT = {[1] = "TEST", [2] = "WXR", [3] = "WX+T", [4] = "MAP"}
local WXR_FAULT_TEXT = {[1] = "ANT", [2] = "ATT", [3] = "WEAK", [4] = "CONT", [5] = "RT"}
local WXR_GAIN_TEXT = {[1] = "CAL", [2] = "VAR"}
local WXR_CYAN, WXR_AMBER = 1, 2
local wxrLine = {" ", " ", " "}
local wxrColor = {0, 0, 0}
local function wxrTexts(on, mode, tilt, ndMode, center, fail, fault, msg, gain)
  local t, c = wxrLine, wxrColor
  t[1], t[2], t[3], c[1], c[2], c[3] = " ", " ", " ", 0, 0, 0
  if on < 0.5 or not (ndMode == 2 or (ndMode < 2 and center < 0.5)) then return end
  if fail > 0.5 then
    t[1], t[2], c[1], c[2] = "WXR", "FAIL", WXR_AMBER, WXR_AMBER
    return
  end
  local text = WXR_MODE_TEXT[mode]
  if text == nil then return end
  t[1], c[1] = text, WXR_CYAN
  if mode == 1 then
    local f = WXR_FAULT_TEXT[fault]
    if f then t[2], c[2] = f, WXR_AMBER end
    return
  end
  local d = math.floor(tilt + 0.5)
  t[2], c[2] = (d > 0) and ("+" .. d) or tostring(d), WXR_CYAN
  local m = WXR_FAULT_TEXT[msg]
  if m then
    t[3], c[3] = m, WXR_AMBER
  elseif WXR_GAIN_TEXT[gain] then
    t[3], c[3] = WXR_GAIN_TEXT[gain], WXR_CYAN
  end
end
function updateIcons()
  wxrTexts(simDR_EFIS_wxr_on, simDR_wxrMode_cpt, simDR_wxrTilt_cpt, B747DR_nd_mode_capt_sel_dial_pos, B747_nd_map_center_capt,
    B747DR_wxr_nd_fail[0], B747DR_wxr_nd_fault[0], B747DR_wxr_nd_msg[0], B747DR_wxr_nd_gain[0])
  if B747DR_text_capt_wxrtext ~= wxrLine[1] then B747DR_text_capt_wxrtext = wxrLine[1] end
  if B747DR_text_capt_wxrtilt ~= wxrLine[2] then B747DR_text_capt_wxrtilt = wxrLine[2] end
  if B747DR_text_capt_wxr3 ~= wxrLine[3] then B747DR_text_capt_wxr3 = wxrLine[3] end
  for k = 1, 3 do
    if B747DR_text_capt_wxr_color[k - 1] ~= wxrColor[k] then B747DR_text_capt_wxr_color[k - 1] = wxrColor[k] end
  end
  wxrTexts(simDR_EFIS_wxr_on_copilot, simDR_wxrMode_fo, simDR_wxrTilt_fo, B747DR_nd_mode_fo_sel_dial_pos, B747_nd_map_center_fo,
    B747DR_wxr_nd_fail[1], B747DR_wxr_nd_fault[1], B747DR_wxr_nd_msg[1], B747DR_wxr_nd_gain[1])
  if B747DR_text_fo_wxrtext ~= wxrLine[1] then B747DR_text_fo_wxrtext = wxrLine[1] end
  if B747DR_text_fo_wxrtilt ~= wxrLine[2] then B747DR_text_fo_wxrtilt = wxrLine[2] end
  if B747DR_text_fo_wxr3 ~= wxrLine[3] then B747DR_text_fo_wxr3 = wxrLine[3] end
  for k = 1, 3 do
    if B747DR_text_fo_wxr_color[k - 1] ~= wxrColor[k] then B747DR_text_fo_wxr_color[k - 1] = wxrColor[k] end
  end

  for n=0,lastCaptNavaid,1 do
    if B747DR_text_capt_show[n]==0 then break end
    updateIcon(iconTextDataCapt,n,1)
  end
  for n=0,lastFONavaid,1 do
    if B747DR_text_fo_show[n]==0 then break end
    updateIcon(iconTextDataFO,n,0)
  end
end

-- TCAS traffic in each ND's 30 slots, every frame: RAs and TAs first, then
-- the nearest (the TCAS model has already kept the 30 nearest), placed as
-- the icons are (makeIcon's bearing, distance and limits); the symbol with
-- its arrow (climbing or descending at 500 fpm or more), the relative
-- altitude in hundreds of feet above the symbol for traffic above and below
-- it for traffic below, none when the altitude is unknown, in the symbol's
-- colour (FCOM p.1534, p.1152; ATA34_2 p.44)
local TCAS_SLOTS = 30
local TCAS_FRAME = {[1] = 1, [2] = 4, [3] = 7, [4] = 10}   -- other, proximate, TA, RA
local TCAS_COLOR = {[1] = 1, [2] = 1, [3] = 2, [4] = 3}    -- white, white, amber, red
local TCAS_TAG_UP, TCAS_TAG_DOWN = 12, -28                  -- panel pixels
local tcasCand = {}
local function byTcas(a, b)
  if a.sym ~= b.sym then return a.sym > b.sym end
  return a.distance < b.distance
end
local function tcasSide(slots, isCaptain)
  local on, irs, cLat, cLon, mapMode, center, range
  if isCaptain then
    on, irs = B747DR_nd_capt_tcas_on, captIRS
    cLat, cLon, mapMode, center = display_latitude_cpt, display_longitude_cpt, simDR_map_mode, B747_nd_map_center_capt
    range = ranges[simDR_range_dial_capt + 1]
  else
    on, irs = B747DR_nd_fo_tcas_on, foIRS
    cLat, cLon, mapMode, center = display_latitude_fo, display_longitude_fo, backport_map_mode_copilot, B747_nd_map_center_fo
    range = ranges[simDR_range_dial_fo + 1]
  end
  local k = 0
  if on > 0.5 and irs > 0 and range ~= nil then
    local nc = 0
    for j = 1, 63 do
      local sym = B747DR_tcas_sym[j]
      if sym > 0 then
        local distance = getDistance(cLat, cLon, simDR_tcas_lat[j], simDR_tcas_lon[j])
        if distance < range then
          nc = nc + 1
          local c = tcasCand[nc]
          if c == nil then c = {}; tcasCand[nc] = c end
          c.j, c.sym, c.distance = j, sym, distance
        end
      end
    end
    for n = nc + 1, #tcasCand do tcasCand[n] = nil end
    table.sort(tcasCand, byTcas)
    for n = 1, nc do
      if k >= TCAS_SLOTS then break end
      local c = tcasCand[n]
      local j = c.j
      local abs_heading = getHeading(cLat, cLon, simDR_tcas_lat[j], simDR_tcas_lon[j])
      local heading_diff
      if mapMode == 2 then
        local mag_diff = getHeadingDifference(simDR_true_heading, simDR_mag_heading)
        heading_diff = getHeadingDifference(simDR_ground_track - mag_diff, abs_heading)
      else
        heading_diff = getHeadingDifference(simDR_true_heading, abs_heading)
      end
      local displayDistance = c.distance * (640 / range)
      local visible = true
      if center < 1 then
        if heading_diff < -90 or heading_diff > 90 then visible = false end
        if (heading_diff < -45 or heading_diff > 45) and displayDistance > 480 then visible = false end
        if (heading_diff < -55 or heading_diff > 55) and displayDistance > 400 then visible = false end
      elseif displayDistance > 320 then
        -- centred: the compass rose's radius is half the range (seen in X-Plane)
        visible = false
      end
      if visible then
        local rel = (simDR_tcas_alt[j] - simDR_tcas_alt[0]) * 3.28084
        local arrow = 0
        if simDR_tcas_vs[j] >= 500 then arrow = 1 elseif simDR_tcas_vs[j] <= -500 then arrow = 2 end
        local tag = " "
        if simDR_tcas_ssr[j] >= 3 then
          local h = math.min(99, math.floor(math.abs(rel) / 100 + 0.5))
          tag = string.format("%s%02d", rel >= 0 and "+" or "-", h)
        end
        local frame = TCAS_FRAME[c.sym] + arrow
        local color = TCAS_COLOR[c.sym]
        local dy = rel >= 0 and TCAS_TAG_UP or TCAS_TAG_DOWN
        if slots.sym[k] ~= frame then slots.sym[k] = frame end
        if slots.color[k] ~= color then slots.color[k] = color end
        if slots.dy[k] ~= dy then slots.dy[k] = dy end
        if slots.tags[k] ~= tag then slots.tags[k] = tag end
        slots.heading[k] = heading_diff
        slots.distance[k] = displayDistance
        if slots.show[k] ~= 1 then slots.show[k] = 1 end
        k = k + 1
      end
    end
  end
  for n = k, TCAS_SLOTS - 1 do
    if slots.show[n] ~= 0 then slots.show[n] = 0 end
  end
end
function updateTCAS()
  tcasSide(tcasCapt, true)
  tcasSide(tcasFO, false)
end

function newIcons()
  lastCaptNavaid=0
  lastFONavaid=0
  if B747DR_pfd_mode_capt>0 or simDR_map_mode==4 then
    B747DR_nd_pln_capt=1
    captIRS=1
  else
    B747DR_nd_pln_capt=0
    captIRS=0
  end
  if B747DR_pfd_mode_fo>0 or backport_map_mode_copilot==4 then
    B747DR_nd_pln_fo=1
    foIRS=1
  else
    B747DR_nd_pln_fo=0
    foIRS=0
  end
  
  --[[if simDR_map_mode==4 then
    for n=0,59,1 do
    B747DR_text_capt_show[n]=0
    B747DR_text_fo_show[n]=0
    end
    return
  end]]--
  local cLat=display_latitude_cpt
  local cLon=display_longitude_cpt
  if isCaptain~=1 then
    cLat=display_latitude_fo
    cLon=display_longitude_fo
  end
  usedNaviadsTableCapt={}
  usedNaviadsTableFO={}
  --flightplan
  local start=B747DR_fmscurrentIndex-1
  if start<1 then start=1 end

  for n=start,table.getn(fmsTable),1 do
    local distance = getDistance(display_latitude_cpt,display_longitude_cpt,fmsTable[n][5],fmsTable[n][6])
    --Captain flightplan
    if distance < ranges[simDR_range_dial_capt + 1] and (simDR_map_mode==2 or simDR_map_mode==4) then 

      if fmsTable[n][10]==true then
	      makeIcon(iconTextDataCapt,3003,fmsTable[n][8],fmsTable[n][5],fmsTable[n][6],distance,n)
      else
	      makeIcon(iconTextDataCapt,3005,fmsTable[n][8],fmsTable[n][5],fmsTable[n][6],distance,n)
      end
    end
    --FO flightplan
    distance = getDistance(display_latitude_fo,display_longitude_fo,fmsTable[n][5],fmsTable[n][6])
    if distance < ranges[simDR_range_dial_fo + 1] and (backport_map_mode_copilot==2 or backport_map_mode_copilot==4) then 

      if fmsTable[n][10]==true then
	      makeIcon(iconTextDataFO,3003,fmsTable[n][8],fmsTable[n][5],fmsTable[n][6],distance,n)
      else
	      makeIcon(iconTextDataFO,3005,fmsTable[n][8],fmsTable[n][5],fmsTable[n][6],distance,n)
      end
    end
  end
  --TODs
  if B747BR_cruiseAlt>0 and B747BR_totalDistance-B747BR_tod>-3 then
    local toddist=getDistance(display_latitude_cpt,display_longitude_cpt,B747BR_todLat,B747BR_todLong)
    if B747DR_nd_mode_capt_sel_dial_pos==2 then
      if toddist < ranges[simDR_range_dial_capt + 1] and simDR_radarAlt1>5000 then 
        makeIcon(iconTextDataCapt,3008,"T/D",B747BR_todLat,B747BR_todLong,toddist)
      end
    end
    toddist=getDistance(display_latitude_fo,display_longitude_fo,B747BR_todLat,B747BR_todLong)
    if B747DR_nd_mode_fo_sel_dial_pos==2 then
      if toddist < ranges[simDR_range_dial_fo + 1] and simDR_radarAlt1>5000 then 
        makeIcon(iconTextDataFO,3008,"T/D",B747BR_todLat,B747BR_todLong,toddist)
      end
    end
  end
  --TOCs
  if B747BR_cruiseAlt>0 and B747BR_toc>0 then
    local tocdist=getDistance(display_latitude_cpt,display_longitude_cpt,B747BR_tocLat,B747BR_tocLong)
    if B747DR_nd_mode_capt_sel_dial_pos==2 then
      if tocdist < ranges[simDR_range_dial_capt + 1] and simDR_radarAlt1>-5000 then 
        makeIcon(iconTextDataCapt,3008,"T/C",B747BR_tocLat,B747BR_tocLong,tocdist)
      end
    end
    tocdist=getDistance(display_latitude_fo,display_longitude_fo,B747BR_tocLat,B747BR_tocLong)
    if B747DR_nd_mode_fo_sel_dial_pos==2 then
      if tocdist < ranges[simDR_range_dial_fo + 1] and simDR_radarAlt1>-5000 then 
        makeIcon(iconTextDataFO,3008,"T/C",B747BR_tocLat,B747BR_tocLong,tocdist)
      end
    end
  end
  -- TCAS traffic has its own slots (updateTCAS)

  --NAVAIDS
  for n=table.getn(currentNaviadsTable),1,-1 do
    local distance = getDistance(display_latitude_cpt,display_longitude_cpt,currentNaviadsTable[n][5],currentNaviadsTable[n][6])
    if distance < ranges[simDR_range_dial_capt + 1] then 
      makeIcon(iconTextDataCapt,currentNaviadsTable[n][2],currentNaviadsTable[n][8],currentNaviadsTable[n][5],currentNaviadsTable[n][6],distance)
    end
    distance = getDistance(display_latitude_fo,display_longitude_fo,currentNaviadsTable[n][5],currentNaviadsTable[n][6])
    if distance < ranges[simDR_range_dial_fo + 1] then 
      makeIcon(iconTextDataFO,currentNaviadsTable[n][2],currentNaviadsTable[n][8],currentNaviadsTable[n][5],currentNaviadsTable[n][6],distance)
    end
  end
  --FIXES
  for n=1,numFixes do
    local distance = getDistance(display_latitude_cpt,display_longitude_cpt,localFixes[n]["lat"],localFixes[n]["long"])
    if distance < ranges[simDR_range_dial_capt + 1] then 
      makeIcon(iconTextDataCapt,3007,localFixes[n]["name"],localFixes[n]["lat"],localFixes[n]["long"],distance)
    end
    local distance = getDistance(display_latitude_fo,display_longitude_fo,localFixes[n]["lat"],localFixes[n]["long"])
    if distance < ranges[simDR_range_dial_fo + 1] then 
      makeIcon(iconTextDataFO,3007,localFixes[n]["name"],localFixes[n]["lat"],localFixes[n]["long"],distance)
    end
  end

  for n=lastCaptNavaid,59,1 do
    B747DR_text_capt_show[n]=0
  end
  for n=lastFONavaid,59,1 do
    B747DR_text_fo_show[n]=0
  end
  --print(lastCaptNavaid.." ".. lastFONavaid)
end


debug_nd     = find_dataref("laminar/B747/debug/nd")

local fix_data_file=nil
local nLines=0
local numTempFixes=0
local tmplocalFixes={}


function read_fixes()
  if fix_data_file==nil then
    fix_data_file = io.open( "Resources/default data/earth_fix.dat", "r" )
    fix_data_file:read( "*line")
    fix_data_file:read( "*line")
    fix_data_file:read( "*line") 
  end

  local line=""
  local lat=0
  local long=0
  local name=""
  local distance=0
  --scansize kept low after first pass to ensure time constraints met/no warn:xtlua time overflow during flight
  for n=0 ,scansize do
    line=fix_data_file:read( "*line" )
    if line~=nil then 
      lat=tonumber(string.sub(line,1,13))
      long=tonumber(string.sub(line,16,29))
      if lat~=nil and long~=nil then 
        distance=getDistance(simDR_latitude,simDR_longitude,lat,long)
        name=string.sub(line,31,36)
        i, j = string.find(name, "%d+")
        if distance<40 and string.sub(name,1,1)~=" " and i==nil then
          numTempFixes=numTempFixes+1
          tmplocalFixes[numTempFixes]={}
          tmplocalFixes[numTempFixes]["name"]=name
          tmplocalFixes[numTempFixes]["lat"]=lat
          tmplocalFixes[numTempFixes]["long"]=long
          
          --print(name)
        end
      end
      nLines=nLines+1
    else
      break
    end
  end
  if line==nil then 
    fix_data_file:close()
    fix_data_file=nil
    localFixes={}
    scansize=25
    numFixes=numTempFixes
    for n=1 ,numTempFixes do
      localFixes[n]={}
      localFixes[n]["name"]=tmplocalFixes[n]["name"]
      localFixes[n]["lat"]=tmplocalFixes[n]["lat"]
      localFixes[n]["long"]=tmplocalFixes[n]["long"]
    end
    tmplocalFixes={}
    numTempFixes=0
    nLines=0
    lastUpdateFixes=simDRTime
  end
end
function compute_and_show_alt_range_arc()
  local meters_per_second_to_kts = 1.94384449
  local actual_speed = simDR_groundspeed * meters_per_second_to_kts
  if B747DR_ap_FMA_active_pitch_mode==2 then --Glideslope
    B747DR_nd_alt_distance_capt=-99
    B747DR_nd_alt_distance_fo=-99
    B747DR_nd_alt_fo_active=0
    B747DR_nd_alt_capt_active=0 
    return
  end
  if simDR_autopilot_alt_hold_status<2 and ((simDR_autopilot_altitude_ft>simDR_pressureAlt1 and simDR_vvi_fpm_pilot>500) or (simDR_autopilot_altitude_ft<simDR_pressureAlt1 and simDR_vvi_fpm_pilot<-500) or B747DR_ap_FMA_active_pitch_mode==7) then
    altDiff=simDR_autopilot_altitude_ft-simDR_pressureAlt1
    local fpmVal=simDR_vvi_fpm_pilot
    if B747DR_ap_FMA_active_pitch_mode==6 or B747DR_ap_FMA_active_pitch_mode==7 then
      fpmVal=simDR_autopilot_vs_fpm
    end
    minsToAlt=altDiff/fpmVal
    distanceToAlt=(actual_speed*minsToAlt)/60
    --print("distanceToAlt="..distanceToAlt.." minsToAlt="..minsToAlt.." altDiff="..altDiff.." actual_speed="..actual_speed)
    if distanceToAlt < ranges[simDR_range_dial_capt + 1] then
      B747DR_nd_alt_distance_capt=distanceToAlt*(640/ranges[simDR_range_dial_capt + 1])
    else
      B747DR_nd_alt_distance_capt=-99
    end
    if distanceToAlt < ranges[simDR_range_dial_fo + 1] then
      B747DR_nd_alt_distance_fo=distanceToAlt*(640/ranges[simDR_range_dial_fo + 1])
    else
      B747DR_nd_alt_distance_fo=-99
    end
  else
    B747DR_nd_alt_distance_capt=-99
    B747DR_nd_alt_distance_fo=-99
  end
  

  if captIRS==0 or B747DR_nd_alt_distance_capt<-90 or B747DR_nd_mode_capt_sel_dial_pos~=2 then 
    B747DR_nd_alt_capt_active=0 
  else
    B747DR_nd_alt_capt_active=1
  end
  if foIRS==0 or B747DR_nd_alt_distance_fo<-90 or B747DR_nd_mode_fo_sel_dial_pos~=2 then 
    B747DR_nd_alt_fo_active=0
  else
    B747DR_nd_alt_fo_active=1
   end
end
last_range_dial = 0
function aircraft_unload()
  print("ND aircraft unload")
  if fix_data_file~=nil then
    print("ND close fix_data_file")
    fix_data_file:close()
    fix_data_file=nil
  end
end

function updateNDLatLong()
  display_latitude_cpt=simDR_latitude
  display_longitude_cpt=simDR_longitude
  display_latitude_fo=simDR_latitude
  display_longitude_fo=simDR_longitude
  if string.len(xpFMSDataJSON) <3 then
    return
  end
  --simDR_latitude, simDR_longitude
  --print("xpFMSDataJSON"..xpFMSDataJSON)
  local displayJSON=json.decode(xpFMSDataJSON)
  --print("displayJSON="..displayJSON[1])
  local dV=displayJSON[1]
  if dV<table.getn(fmsTable) then
    --print("display Lat Long="..fmsTable[dV][5].." "..fmsTable[dV][6])
    if simDR_map_mode==4 then
      display_latitude_cpt=fmsTable[dV][5]
      display_longitude_cpt=fmsTable[dV][6]
    end
    if backport_map_mode_copilot==4 then
      display_latitude_fo=fmsTable[dV][5]
      display_longitude_fo=fmsTable[dV][6]
    end
  end
end

function after_physics()
  collectgarbage("collect")
  
  if debug_nd>0 then return end
  local diff=simDRTime-lastUpdate
  -- each ND's top from its own mode and side (step 5a)
  B747DR_nd_capt_up = nd_up(B747DR_nd_mode_capt, simDR_heading_track, simDR_ground_track)
  B747DR_nd_fo_up = nd_up(B747DR_nd_mode_fo, simDR_heading_copilot, simDR_ground_track_copilot)
  if simDR_version>=120012 then
    backport_map_mode_copilot=simDR_map_mode_copilot
    if B747DR_nd_capt_terr>0 or simDR_EFIS_wxr_on>0 then
      B747DR_nd_terr_weather_capt=1
    else
      B747DR_nd_terr_weather_capt=0
    end
    if B747DR_nd_fo_terr>0 or simDR_EFIS_wxr_on_copilot>0 then
      B747DR_nd_terr_weather_fo=1
    else
      B747DR_nd_terr_weather_fo=0
    end
  else
    backport_map_range_copilot=simDR_map_range
    backport_map_mode_copilot=simDR_map_mode
  end

  updateNDLatLong()

  --force new icons if range dial changes (stop bleed into other displays)
  if simDR_range_dial_capt~=last_range_dial then
    last_range_dial=simDR_range_dial_capt
    newIcons()
  end

  updateIcons()
  updateTCAS()
  compute_and_show_alt_range_arc()
  if debug_nd<-2 then return end
  local diff2=simDRTime-lastUpdateIcon
  if diff2>0.2 then
    newIcons()
    lastUpdateIcon=simDRTime
  end
  if debug_nd<-1 then return end
  diff2=simDRTime-lastUpdateFixes
  if diff2>10 then 
    read_fixes()
  end
  if diff<2 then return end
  lastUpdate=simDRTime
  if debug_nd<0 then return end
  decodeNAVAIDS()
  decodeFlightPlan()
  newIcons()
  
  --print("navaids size="..table.getn(currentNaviadsTable))
  --print("fms size="..table.getn(fmsTable))
  
end 
