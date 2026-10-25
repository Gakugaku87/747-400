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
local fmsVersion=0
local transAlt=ND_DATA.TRANS_ALT_FT
-- EXCESS DATA (step 5c, FCOM p.1111): more symbols than the 60 slots
B747DR_nd_capt_excess_data = find_dataref("laminar/B747/nd/capt/excess_data")
B747DR_nd_fo_excess_data = find_dataref("laminar/B747/nd/fo/excess_data")
local excessCapt, excessFO = false, false
-- the navaids' altitude class for STA (step 5c, FCOM p.1040): read once,
-- a chunk a frame, from the navigation data X-Plane uses (Custom Data
-- first; B747.61.nd_data.lua's nav_line)
local navHigh={}
local navFile, navDone=nil, false
function read_navclass()
  if navDone then return end
  if navFile==nil then
    navFile=io.open("Custom Data/earth_nav.dat", "r") or io.open("Resources/default data/earth_nav.dat", "r")
    if navFile==nil then navDone=true return end
  end
  for n=1,ND_DATA.NAV_LINES do
    local line=navFile:read("*line")
    if line==nil then navFile:close() navFile=nil navDone=true return end
    local id, lat, lon=ND_DATA.nav_line(line)
    if id then
      local l=navHigh[id]
      if l==nil then l={} navHigh[id]=l end
      l[#l+1]=lat
      l[#l+1]=lon
    end
  end
end
local function nav_high(id, lat, lon)
  return ND_DATA.nav_near(navHigh[id], lat, lon)
end

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
-- each side's heading and track in the heading reference (5-2 step 5d: the
-- display glue's, magnetic or true)
B747DR_nd_hdg_deg_capt                  = find_dataref("laminar/B747/pfd/capt/hdg_deg")
B747DR_nd_trk_deg_capt                  = find_dataref("laminar/B747/pfd/capt/trk_deg")
B747DR_nd_hdg_deg_fo                    = find_dataref("laminar/B747/pfd/fo/hdg_deg")
B747DR_nd_trk_deg_fo                    = find_dataref("laminar/B747/pfd/fo/trk_deg")

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
  fmsVersion=fmsVersion+1
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

-- a true bearing on that side's ND, from the display's top as nd_up orients
-- it (step 5a): that side's track (MAP) or heading (VOR, APP) made true with
-- the variation; PLN north up as before. The map symbols every 0.2 s
-- (makeIcon) and every frame (updateIcon: before, the Captain's track in
-- MAP for both sides and the true heading in the other modes) and the
-- airports (step 5c)
local function nd_bearing(isCapt,abs_heading)
  local mode, trk, hdg = B747DR_nd_mode_capt, simDR_ground_track, simDR_heading_track
  if not isCapt then
    mode, trk, hdg = B747DR_nd_mode_fo, simDR_ground_track_copilot, simDR_heading_copilot
  end
  local mag_diff=getHeadingDifference(simDR_true_heading,simDR_mag_heading)
  if mode==2 then return getHeadingDifference(trk-mag_diff,abs_heading) end
  if mode==3 then return abs_heading+simDR_variation end
  return getHeadingDifference(hdg-mag_diff,abs_heading)
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
  local isCapt=iconTextData==iconTextDataCapt
  local mode=isCapt and B747DR_nd_mode_capt or B747DR_nd_mode_fo
  local heading_diff=nd_bearing(isCapt,abs_heading)
  
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
  
  -- the symbol and its text's colour on that side's ND (none: not shown).
  -- STA, WPT and ARPT in MAP and MAP CTR (FCOM p.1040; step 5c: before, in
  -- every mode): the airports on all ranges, the waypoints at 40 NM and
  -- less; the tuned VORs always, in green (FCOM p.1145: before, only with
  -- STA), the other navaids with STA: high and low altitude ones at 40 NM
  -- and less, high altitude ones beyond (before, all on all ranges). The
  -- route's waypoints in MAP, MAP CTR and PLAN (FCOM p.1148: before, also in
  -- VOR, where X-Plane's map mode is MAP)
  local icon, color
  local map=mode==2
  if navtype==1 then
    if apt>0 and map then icon, color=2, "blue" end
  elseif navtype==3003 then
    if map or mode==3 then icon, color=4, "red" end
  elseif navtype==3005 then
    if map or mode==3 then icon, color=5, "white" end
  elseif navtype==3007 then
    if wpt>0 and map and range<=40 then icon, color=13, "blue" end
  elseif navtype==3008 then
    icon, color=8, "green"
  elseif bit_and(navtype,4)>0 then
    if map and (text==simDR_radio_nav03_ID or text==simDR_radio_nav04_ID) then
      icon, color=10, "green"
    elseif map and vor_ndb>0 and (range<=40 or nav_high(text,latitude,longitude)) then
      icon, color=11, "blue"
    end
  elseif navtype==2 then
    if map and vor_ndb>0 and (range<=40 or nav_high(text,latitude,longitude)) then icon, color=0, "blue" end
  end
  if icon==nil then return end
  -- the panel's 60 slots full: EXCESS DATA (FCOM p.1111)
  if lastNavaid > 59 then
    if iconTextData==iconTextDataCapt then excessCapt=true else excessFO=true end
    return
  end
  iconTextData.icons[lastNavaid]=icon
  local w, b, r, g=" ", " ", " ", " "
  if color=="white" then w=text elseif color=="blue" then b=text elseif color=="red" then r=text else g=text end
  local slot=iconTextData[lastNavaid]
  slot.whitetext=w
  slot.bluetext=b
  slot.redtext=r
  slot.greentext=g
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
  local heading_diff=nd_bearing(isCaptain==1,abs_heading)
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

-- The origin and destination airports and their runways (step 5c, FCOM
-- p.1149; B747.61.nd_data.lua): from the route's ends in X-Plane's FMS, the
-- runways' other ends from the airport's CIFP file (read a chunk a frame
-- after loading); each ND's two airports, 0 the origin and 1 the
-- destination, in MAP, MAP CTR and PLAN whatever the ARPT switch, in white:
-- on 80 NM and more the airport symbol and identifier with the selected
-- runway's under it and a line along the runway, from the airport toward
-- the selected threshold's end (estimate: FCOM's figure); on 10 to 40 NM
-- the runway to scale with its dashed centrelines and its identifier at the
-- threshold, the airport symbol when the runway is not known (estimate):
-- the dashes on the map's visible part, the runway when its middle is, the
-- identifier when the threshold is.
-- The route's waypoints and the ARPT symbols for them give way to these
-- (estimate: before, the route's waypoints).
aptDataCapt={}
aptDataFO={}
aptDataCapt.sym=find_dataref("laminar/B747/nd/capt/apt/sym")
aptDataCapt.heading=find_dataref("laminar/B747/nd/capt/apt/heading")
aptDataCapt.distance=find_dataref("laminar/B747/nd/capt/apt/distance")
aptDataCapt.line=find_dataref("laminar/B747/nd/capt/apt/line")
aptDataCapt.dir=find_dataref("laminar/B747/nd/capt/apt/dir")
aptDataCapt.rwy_show=find_dataref("laminar/B747/nd/capt/apt/rwy_show")
aptDataCapt.rwy_heading=find_dataref("laminar/B747/nd/capt/apt/rwy_heading")
aptDataCapt.rwy_distance=find_dataref("laminar/B747/nd/capt/apt/rwy_distance")
aptDataCapt.rwy_len=find_dataref("laminar/B747/nd/capt/apt/rwy_len")
aptDataCapt.rwy_frame=find_dataref("laminar/B747/nd/capt/apt/rwy_frame")
aptDataCapt.thr_heading=find_dataref("laminar/B747/nd/capt/apt/thr_heading")
aptDataCapt.thr_distance=find_dataref("laminar/B747/nd/capt/apt/thr_distance")
aptDataCapt.thr_show=find_dataref("laminar/B747/nd/capt/apt/thr_show")
aptDataCapt.dash=find_dataref("laminar/B747/nd/capt/apt/dash")
aptDataCapt.id0=find_dataref("laminar/B747/nd/capt/apt/id0")
aptDataCapt.id1=find_dataref("laminar/B747/nd/capt/apt/id1")
aptDataCapt.rwy0=find_dataref("laminar/B747/nd/capt/apt/rwy0")
aptDataCapt.rwy1=find_dataref("laminar/B747/nd/capt/apt/rwy1")
aptDataFO.sym=find_dataref("laminar/B747/nd/fo/apt/sym")
aptDataFO.heading=find_dataref("laminar/B747/nd/fo/apt/heading")
aptDataFO.distance=find_dataref("laminar/B747/nd/fo/apt/distance")
aptDataFO.line=find_dataref("laminar/B747/nd/fo/apt/line")
aptDataFO.dir=find_dataref("laminar/B747/nd/fo/apt/dir")
aptDataFO.rwy_show=find_dataref("laminar/B747/nd/fo/apt/rwy_show")
aptDataFO.rwy_heading=find_dataref("laminar/B747/nd/fo/apt/rwy_heading")
aptDataFO.rwy_distance=find_dataref("laminar/B747/nd/fo/apt/rwy_distance")
aptDataFO.rwy_len=find_dataref("laminar/B747/nd/fo/apt/rwy_len")
aptDataFO.rwy_frame=find_dataref("laminar/B747/nd/fo/apt/rwy_frame")
aptDataFO.thr_heading=find_dataref("laminar/B747/nd/fo/apt/thr_heading")
aptDataFO.thr_distance=find_dataref("laminar/B747/nd/fo/apt/thr_distance")
aptDataFO.thr_show=find_dataref("laminar/B747/nd/fo/apt/thr_show")
aptDataFO.dash=find_dataref("laminar/B747/nd/fo/apt/dash")
aptDataFO.id0=find_dataref("laminar/B747/nd/fo/apt/id0")
aptDataFO.id1=find_dataref("laminar/B747/nd/fo/apt/id1")
aptDataFO.rwy0=find_dataref("laminar/B747/nd/fo/apt/rwy0")
aptDataFO.rwy1=find_dataref("laminar/B747/nd/fo/apt/rwy1")
local aptO, aptOR, aptD, aptDR=nil, nil, nil, nil
local aptVersion=-1
local cifp={}                   -- by airport: its thresholds by runway, false without a file
local cifpFile, cifpApt, cifpRwys=nil, nil, nil
local rwyGeo={}                 -- by airport and runway: {lat, lon, length NM, bearing}, false if unknown
local dashBuf={}
local dashLast={{}, {}}
local DASH_N=2*2*ND_DATA.DASHES
for j=0,DASH_N-1 do dashBuf[j]=0 dashLast[1][j]=-1 dashLast[2][j]=-1 end

-- the route's ends when it changed
local function aptRoute()
  if aptVersion==fmsVersion then return end
  aptVersion=fmsVersion
  aptO, aptOR, aptD, aptDR=ND_DATA.route_ends(fmsTable)
end
-- the airports and their runways as used (makeIcon leaves them)
local function aptUsed(used)
  for _, i in ipairs({aptO or 0, aptOR or 0, aptD or 0, aptDR or 0}) do
    local e=fmsTable[i]
    if e and e[8] then used[e[8]]=true end
  end
end
-- the airport's CIFP file in the navigation data X-Plane uses
function cifp_open(apt)
  return io.open("Custom Data/CIFP/"..apt..".dat", "r") or io.open("Resources/default data/CIFP/"..apt..".dat", "r")
end
-- the CIFP file of an airport with a selected runway, a chunk a frame
function read_cifp()
  if cifpFile==nil then
    local want=nil
    for _, p in ipairs({{aptO or 0, aptOR}, {aptD or 0, aptDR}}) do
      local e=fmsTable[p[1]]
      if e and p[2] and cifp[e[8]]==nil then want=e[8] break end
    end
    if want==nil then return end
    cifpFile=cifp_open(want)
    if cifpFile==nil then cifp[want]=false return end
    cifpApt, cifpRwys=want, {}
  end
  for n=1,ND_DATA.NAV_LINES do
    local line=cifpFile:read("*line")
    if line==nil then
      cifpFile:close()
      cifpFile=nil
      cifp[cifpApt]=cifpRwys
      cifpApt, cifpRwys=nil, nil
      return
    end
    local id, lat, lon, disp=ND_DATA.cifp_rwy(line)
    if id then cifpRwys[id]={lat, lon, disp} end
  end
end
-- a selected runway's middle, length and bearing to its threshold's end
-- (the route's threshold, the other end's from the CIFP file), or nil
local function rwy_geo(ai, ri)
  local a, r=fmsTable[ai or 0], fmsTable[ri or 0]
  if a==nil or r==nil then return nil end
  local key=a[8].." "..r[8]
  local g=rwyGeo[key]
  if g~=nil then return g or nil end
  local c=cifp[a[8]]
  if c==nil then return nil end
  local o=c and c[ND_DATA.rwy_opposite(r[8])]
  if not o then rwyGeo[key]=false return nil end
  local s=c[r[8]]
  local lat, lon, len, brg=ND_DATA.runway(r[5], r[6], s and s[3] or 0, o[1], o[2], o[3])
  if lat==nil then rwyGeo[key]=false return nil end
  g={lat, lon, len, brg}
  rwyGeo[key]=g
  return g
end
-- a position's bearing and distance on that side's ND, and whether it is
-- on the map's visible part
local function aptPlace(isCapt, cLat, cLon, lat, lon, ppn, view)
  local d=getDistance(cLat,cLon,lat,lon)
  local h=nd_bearing(isCapt,getHeading(cLat,cLon,lat,lon))
  local x, y=d*ppn*math.sin(math.rad(h)), d*ppn*math.cos(math.rad(h))
  return h, d, x, y, ND_DATA.inside(x, y, view)
end
local function aptSide(isCapt, t, last)
  local mode=isCapt and B747DR_nd_mode_capt or B747DR_nd_mode_fo
  local irs=isCapt and captIRS or foIRS
  local dial=isCapt and simDR_range_dial_capt or simDR_range_dial_fo
  local center=(isCapt and B747_nd_map_center_capt or B747_nd_map_center_fo)>0
  local view=ND_DATA.EXPANDED
  if mode==3 then view=ND_DATA.PLAN elseif center then view=ND_DATA.CENTRED end
  local range=ranges[dial+1] or 40
  local units, ppn=640/range, ND_DATA.PX_PER_RANGE/range
  local cLat, cLon=display_latitude_cpt, display_longitude_cpt
  if not isCapt then cLat, cLon=display_latitude_fo, display_longitude_fo end
  local on=irs>0 and (mode==2 or mode==3)
  for k=0,1 do
    local ai, ri=aptO, aptOR
    if k==1 then ai, ri=aptD, aptDR end
    local a=on and fmsTable[ai or 0] or nil
    local sym, line, rwy, frame, thr=0, 0, 0, -1, 0
    local id, rid=" ", " "
    local base=k*2*ND_DATA.DASHES
    if a then
      local r=fmsTable[ri or 0]
      local geo=rwy_geo(ai, ri)
      id=a[8]
      rid=r and ND_DATA.rwy_id(r[8]) or " "
      if range<ND_DATA.APT_RANGE_NM and geo then
        local h, d, x, y, inside=aptPlace(isCapt, cLat, cLon, geo[1], geo[2], ppn, view)
        local th, td, _, _, thrIn=aptPlace(isCapt, cLat, cLon, r[5], r[6], ppn, view)
        local dir=nd_bearing(isCapt,geo[4])
        local len=geo[3]*ppn
        ND_DATA.dashes(x, y, dir, len, ppn, view, dashBuf, base)
        local dashes=false
        for j=base,base+2*ND_DATA.DASHES-1 do
          if dashBuf[j]>0 then dashes=true break end
        end
        if inside or thrIn or dashes then
          rwy=1
          t.rwy_heading[k]=h
          t.rwy_distance[k]=d*units
          t.dir[k]=dir
          t.rwy_len[k]=len
          t.thr_heading[k]=th
          t.thr_distance[k]=td*units
          if inside then frame=ND_DATA.rwy_frame(len) end
          if thrIn then thr=1 end
        end
      else
        local h, d, x, y, inside=aptPlace(isCapt, cLat, cLon, a[5], a[6], ppn, view)
        if inside then
          sym=1
          t.heading[k]=h
          t.distance[k]=d*units
          if geo then
            line=1
            t.dir[k]=nd_bearing(isCapt,geo[4])
          end
        end
      end
    end
    if rwy==0 then for j=base,base+2*ND_DATA.DASHES-1 do dashBuf[j]=0 end end
    if t.sym[k]~=sym then t.sym[k]=sym end
    if t.line[k]~=line then t.line[k]=line end
    if t.rwy_show[k]~=rwy then t.rwy_show[k]=rwy end
    if t.rwy_frame[k]~=frame then t.rwy_frame[k]=frame end
    if t.thr_show[k]~=thr then t.thr_show[k]=thr end
    if k==0 then
      if t.id0~=id then t.id0=id end
      if t.rwy0~=rid then t.rwy0=rid end
    else
      if t.id1~=id then t.id1=id end
      if t.rwy1~=rid then t.rwy1=rid end
    end
  end
  for j=0,DASH_N-1 do
    if last[j]~=dashBuf[j] then
      t.dash[j]=dashBuf[j]
      last[j]=dashBuf[j]
    end
  end
end
-- every frame
function updateAirports()
  aptRoute()
  aptSide(true, aptDataCapt, dashLast[1])
  aptSide(false, aptDataFO, dashLast[2])
end

-- The manually tuned VORs' course lines (step 5c, FCOM p.1145;
-- B747.61.nd_data.lua): VOR L and R (X-Plane's NAV3 and NAV4) tuned on the
-- CDU's NAV RADIO page (laminar/B747/radio/tuningmodes, its 2nd and 3rd
-- letters M), the station from the navaids list (the tuned one nearest the
-- airplane), the page's course (the receiver's OBS, made true with the
-- airplane's variation: estimate, the station's own may differ); on each ND
-- in MAP and MAP CTR, a green dashed line through the station both ways to
-- the map's edge, the course and the reciprocal 50 pixels from the station
-- on each side.
crsDataCapt={}
crsDataFO={}
crsDataCapt.show=find_dataref("laminar/B747/nd/capt/crs/show")
crsDataCapt.heading=find_dataref("laminar/B747/nd/capt/crs/heading")
crsDataCapt.distance=find_dataref("laminar/B747/nd/capt/crs/distance")
crsDataCapt.dir=find_dataref("laminar/B747/nd/capt/crs/dir")
crsDataCapt.phase=find_dataref("laminar/B747/nd/capt/crs/phase")
crsDataCapt.dash=find_dataref("laminar/B747/nd/capt/crs/dash")
crsDataCapt.lbl_heading=find_dataref("laminar/B747/nd/capt/crs/lbl_heading")
crsDataCapt.lbl_distance=find_dataref("laminar/B747/nd/capt/crs/lbl_distance")
crsDataCapt.lbl_show=find_dataref("laminar/B747/nd/capt/crs/lbl_show")
crsDataCapt.tbrg=find_dataref("laminar/B747/nd/capt/crs/tbrg")
crsDataCapt.tside=find_dataref("laminar/B747/nd/capt/crs/tside")
crsDataCapt.text0=find_dataref("laminar/B747/nd/capt/crs/text0")
crsDataCapt.text1=find_dataref("laminar/B747/nd/capt/crs/text1")
crsDataCapt.text2=find_dataref("laminar/B747/nd/capt/crs/text2")
crsDataCapt.text3=find_dataref("laminar/B747/nd/capt/crs/text3")
crsDataFO.show=find_dataref("laminar/B747/nd/fo/crs/show")
crsDataFO.heading=find_dataref("laminar/B747/nd/fo/crs/heading")
crsDataFO.distance=find_dataref("laminar/B747/nd/fo/crs/distance")
crsDataFO.dir=find_dataref("laminar/B747/nd/fo/crs/dir")
crsDataFO.phase=find_dataref("laminar/B747/nd/fo/crs/phase")
crsDataFO.dash=find_dataref("laminar/B747/nd/fo/crs/dash")
crsDataFO.lbl_heading=find_dataref("laminar/B747/nd/fo/crs/lbl_heading")
crsDataFO.lbl_distance=find_dataref("laminar/B747/nd/fo/crs/lbl_distance")
crsDataFO.lbl_show=find_dataref("laminar/B747/nd/fo/crs/lbl_show")
crsDataFO.tbrg=find_dataref("laminar/B747/nd/fo/crs/tbrg")
crsDataFO.tside=find_dataref("laminar/B747/nd/fo/crs/tside")
crsDataFO.text0=find_dataref("laminar/B747/nd/fo/crs/text0")
crsDataFO.text1=find_dataref("laminar/B747/nd/fo/crs/text1")
crsDataFO.text2=find_dataref("laminar/B747/nd/fo/crs/text2")
crsDataFO.text3=find_dataref("laminar/B747/nd/fo/crs/text3")
B747DR_nd_radio_modes = find_dataref("laminar/B747/radio/tuningmodes")
simDR_nav_obs = find_dataref("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot")
local CRS_N=2*ND_DATA.CRS_DASHES+1
local crsBuf={}
local crsLast={{}, {}}
for j=0,2*CRS_N-1 do crsBuf[j]=0 crsLast[1][j]=-1 crsLast[2][j]=-1 end
local crsStation={false, false}
local crsStationId={"", ""}
local crsStationTime=-10
-- the tuned stations, once a second or when a receiver's identifier changes
local function crsStations()
  local ids={simDR_radio_nav03_ID, simDR_radio_nav04_ID}
  if ids[1]==crsStationId[1] and ids[2]==crsStationId[2] and simDRTime-crsStationTime<1 then return end
  crsStationTime=simDRTime
  for k=1,2 do
    crsStationId[k]=ids[k]
    local best, bestD=false, 1e9
    if ids[k]~="" then
      for n=1,table.getn(currentNaviadsTable) do
        local e=currentNaviadsTable[n]
        if e[8]==ids[k] and bit_and(e[2],4)>0 then
          local d=getDistance(simDR_latitude,simDR_longitude,e[5],e[6])
          if d<bestD then best, bestD={e[5], e[6]}, d end
        end
      end
    end
    crsStation[k]=best
  end
end
local function crsSide(isCapt, t, last)
  local mode=isCapt and B747DR_nd_mode_capt or B747DR_nd_mode_fo
  local irs=isCapt and captIRS or foIRS
  local dial=isCapt and simDR_range_dial_capt or simDR_range_dial_fo
  local center=(isCapt and B747_nd_map_center_capt or B747_nd_map_center_fo)>0
  local view=center and ND_DATA.CENTRED or ND_DATA.EXPANDED
  local range=ranges[dial+1] or 40
  local units, ppn=640/range, ND_DATA.PX_PER_RANGE/range
  local cLat, cLon=display_latitude_cpt, display_longitude_cpt
  if not isCapt then cLat, cLon=display_latitude_fo, display_longitude_fo end
  local modes=B747DR_nd_radio_modes
  if type(modes)~="string" then modes="" end
  local mag_diff=getHeadingDifference(simDR_true_heading,simDR_mag_heading)
  for k=0,1 do
    local st=crsStation[k+1]
    local show, l0, l1=0, 0, 0
    local base=k*CRS_N
    if irs>0 and mode==2 and st and modes:sub(k+2,k+2)=="M" then
      local crs=simDR_nav_obs[k+2]
      local dir=nd_bearing(isCapt,crs-mag_diff)
      local d=getDistance(cLat,cLon,st[1],st[2])
      local h=nd_bearing(isCapt,getHeading(cLat,cLon,st[1],st[2]))
      local sx, sy=d*ppn*math.sin(math.rad(h)), d*ppn*math.cos(math.rad(h))
      local fx, fy, phase, any=ND_DATA.crs_line(sx, sy, dir, view, crsBuf, base)
      if any then
        show=1
        t.heading[k]=math.deg(math.atan2(fx, fy))
        t.distance[k]=math.sqrt(fx*fx+fy*fy)/ppn*units
        t.dir[k]=dir
        t.phase[k]=phase
        t.lbl_heading[k]=h
        t.lbl_distance[k]=d*units
        local ux, uy, L=math.sin(math.rad(dir)), math.cos(math.rad(dir)), ND_DATA.CRS_LABEL_PX
        if ND_DATA.inside(sx+L*ux, sy+L*uy, view) then l0=1 end
        if ND_DATA.inside(sx-L*ux, sy-L*uy, view) then l1=1 end
        local tb, ts=ND_DATA.crs_label(dir)
        t.tbrg[k*2]=tb
        if t.tside[k*2]~=ts then t.tside[k*2]=ts end
        tb, ts=ND_DATA.crs_label(dir+180)
        t.tbrg[k*2+1]=tb
        if t.tside[k*2+1]~=ts then t.tside[k*2+1]=ts end
        local c0, c1=ND_DATA.crs_text(crs), ND_DATA.crs_text(crs+180)
        if k==0 then
          if t.text0~=c0 then t.text0=c0 end
          if t.text1~=c1 then t.text1=c1 end
        else
          if t.text2~=c0 then t.text2=c0 end
          if t.text3~=c1 then t.text3=c1 end
        end
      end
    end
    if show==0 then for j=base,base+CRS_N-1 do crsBuf[j]=0 end end
    if t.show[k]~=show then t.show[k]=show end
    if t.lbl_show[k*2]~=l0 then t.lbl_show[k*2]=l0 end
    if t.lbl_show[k*2+1]~=l1 then t.lbl_show[k*2+1]=l1 end
  end
  for j=0,2*CRS_N-1 do
    if last[j]~=crsBuf[j] then
      t.dash[j]=crsBuf[j]
      last[j]=crsBuf[j]
    end
  end
end
-- every frame
function updateCourses()
  crsStations()
  crsSide(true, crsDataCapt, crsLast[1])
  crsSide(false, crsDataFO, crsLast[2])
end

function newIcons()
  lastCaptNavaid=0
  lastFONavaid=0
  excessCapt, excessFO=false, false
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
  -- the origin and destination and their runways have their own symbols
  aptRoute()
  aptUsed(usedNaviadsTableCapt)
  aptUsed(usedNaviadsTableFO)
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
  local v=excessCapt and 1 or 0
  if B747DR_nd_capt_excess_data~=v then B747DR_nd_capt_excess_data=v end
  v=excessFO and 1 or 0
  if B747DR_nd_fo_excess_data~=v then B747DR_nd_fo_excess_data=v end
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
  -- each ND's top from its own mode and side (step 5a), in the heading
  -- reference (step 5d: the rose's numbers magnetic or true; the map
  -- symbols' bearings stay true, nd_bearing)
  B747DR_nd_capt_up = nd_up(B747DR_nd_mode_capt, B747DR_nd_hdg_deg_capt, B747DR_nd_trk_deg_capt)
  B747DR_nd_fo_up = nd_up(B747DR_nd_mode_fo, B747DR_nd_hdg_deg_fo, B747DR_nd_trk_deg_fo)
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
  updateAirports()
  updateCourses()
  updateTCAS()
  compute_and_show_alt_range_arc()
  if debug_nd<-2 then return end
  local diff2=simDRTime-lastUpdateIcon
  if diff2>0.2 then
    newIcons()
    lastUpdateIcon=simDRTime
  end
  if debug_nd<-1 then return end
  read_navclass()
  read_cifp()
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
