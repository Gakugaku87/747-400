
-- The FMC's side of the IRS (5-1 step 2): the IRUs are in the navigation
-- sensors module (plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.irs.lua),
-- which writes laminar/B747/irs/... and the IRU modes, the PFDs' IRS
-- validity and the IRS messages. This reads them for the CDU (POS INIT,
-- POS REF, IRS MONITOR) and the ND (TIME TO ALIGN, the position update
-- line), and hands the present position and SET HDG entries to the IRUs
-- (laminar/B747/irs/pos_entry_*, set_hdg_*). GPS L and R: X-Plane's position
-- while the module has them navigating (laminar/B747/gps/valid).
simDR_groundspeed=find_dataref("sim/flightmodel/position/groundspeed")
B747DR_iru_mode_sel_pos         = find_dataref("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos")
irs_A_status=find_dataref("laminar/B747/irs/line1")
irs_L_status=find_dataref("laminar/B747/irs/line2")
irs_C_status=find_dataref("laminar/B747/irs/line3")
irs_R_status=find_dataref("laminar/B747/irs/line4")
B747DR_nav_irs_mode             = find_dataref("laminar/B747/irs/mode")
B747DR_nav_irs_time_left        = find_dataref("laminar/B747/irs/time_left")
B747DR_nav_irs_nav_valid        = find_dataref("laminar/B747/irs/nav_valid")
B747DR_nav_irs_lat              = find_dataref("laminar/B747/irs/lat")
B747DR_nav_irs_lon              = find_dataref("laminar/B747/irs/lon")
B747DR_nav_irs_gs               = find_dataref("laminar/B747/irs/gs")
B747DR_nav_irs_motion           = find_dataref("laminar/B747/irs/motion")
B747DR_nav_irs_set_pos          = find_dataref("laminar/B747/irs/set_pos")
B747DR_nav_irs_aligning         = find_dataref("laminar/B747/irs/aligning")
B747DR_nav_irs_set_hdg_shown    = find_dataref("laminar/B747/irs/set_hdg_shown")
B747DR_nav_irs_pos_seq          = find_dataref("laminar/B747/irs/pos_entry_seq")
B747DR_nav_irs_pos_lat          = find_dataref("laminar/B747/irs/pos_entry_lat")
B747DR_nav_irs_pos_lon          = find_dataref("laminar/B747/irs/pos_entry_lon")
B747DR_nav_irs_hdg_seq          = find_dataref("laminar/B747/irs/set_hdg_seq")
B747DR_nav_irs_hdg              = find_dataref("laminar/B747/irs/set_hdg")
B747CMD_nav_irs_align_now       = find_command("laminar/B747/irs/align_now")
B747DR_nav_gps_valid            = find_dataref("laminar/B747/gps/valid")

--IRS ND DISPLAY
B747DR_ND_IRS_Line	= deferred_dataref("laminar/B747/irs/irs_display_line", "string")

-- the navigation sensors module's IRU modes (laminar/B747/irs/mode)
local MODE_OFF, MODE_ALIGN, MODE_NAV, MODE_ATT, MODE_FAIL = 0, 1, 2, 3, 4

irs={
  index=0,
  aligned=false,
  getLat=function(self)
   if self["aligned"] then return toDMS(self:getLatD(),true)
   else return "***`**.*" end
  end,
  getLon=function(self)
   if self["aligned"] then return toDMS(self:getLonD(),false)
   else return "****`**.*" end
  end,
  -- an IRU's position (the module's); the GPS: X-Plane's
  getLatD=function(self)
   if not self["aligned"] then return 0 end
   if self["gps"] then return simDR_latitude end
   return B747DR_nav_irs_lat[self["index"]]
  end,
  getLonD=function(self)
   if not self["aligned"] then return 0 end
   if self["gps"] then return simDR_longitude end
   return B747DR_nav_irs_lon[self["index"]]
  end,
  getGS=function(self)
   if not self["aligned"] then return "**" end
   if self["gps"] then return string.format("%02d",simDR_groundspeed/0.514444) end
   return string.format("%02d",B747DR_nav_irs_gs[self["index"]])
  end
}

irsL = {}
setmetatable(irsL, {__index = irs})
irsL["id"]="irsL"
irsL["index"]=0
irsC = {}
setmetatable(irsC, {__index = irs})
irsC["id"]="irsC"
irsC["index"]=1
irsR = {}
setmetatable(irsR, {__index = irs})
irsR["id"]="irsR"
irsR["index"]=2
gpsL = {}
setmetatable(gpsL, {__index = irs})
gpsL["aligned"]=true
gpsL["gps"]=true
gpsR = {}
setmetatable(gpsR, {__index = irs})
gpsR["aligned"]=true
gpsR["gps"]=true

irsSystem={}
irsSystem["motion"]={irsL=false,irsC=false,irsR=false}
irsSystem["setPos"]=false
irsSystem["irsL"]=irsL
irsSystem["irsC"]=irsC
irsSystem["irsR"]=irsR
irsSystem["irsLat"]=fmsModules["data"]["irsLat"]
irsSystem["irsLon"]=fmsModules["data"]["irsLon"]
irsSystem["gpsL"]=gpsL
irsSystem["gpsR"]=gpsR

function irsFromNum(num)
  if num==0 then return "irsL" end
  if num==1 then return "irsC" end
  return "irsR"
end

-- degrees from a CDU latitude or longitude: N35`45.9 or N3545.9 (minutes
-- with tenths), E140`23.2 or E14023.2; nil if it is not one
function irs_deg(str,isLat)
  local h,d,m
  if isLat then
    h,d,m=string.match(str,"^%s*([NS])(%d%d)`?(%d%d%.?%d*)%s*$")
  else
    h,d,m=string.match(str,"^%s*([EW])(%d%d%d)`?(%d%d%.?%d*)%s*$")
  end
  if h==nil then return nil end
  d,m=tonumber(d),tonumber(m)
  if m>=60 or (isLat and d>90) or (not isLat and d>180) then return nil end
  local v=d+m/60
  if h=="S" or h=="W" then v=-v end
  return v
end

-- the present position entered on POS INIT (CDU strings) for the IRUs:
-- false if it is not a position
irsSystem.enterPos=function(lat,lon)
  local la=irs_deg(lat,true)
  local lo=irs_deg(lon,false)
  if la==nil or lo==nil then return false end
  B747DR_nav_irs_pos_lat=la
  B747DR_nav_irs_pos_lon=lo
  B747DR_nav_irs_pos_seq=B747DR_nav_irs_pos_seq+1
  return true
end
-- SET HDG (magnetic, 0-360) for the IRUs in ATT
irsSystem.enterHdg=function(hdg)
  B747DR_nav_irs_hdg=hdg
  B747DR_nav_irs_hdg_seq=B747DR_nav_irs_hdg_seq+1
end
-- an IRU aligning: the SET IRS POS line is in use
irsSystem.aligning=function()
  return B747DR_nav_irs_aligning==1
end
-- the GPS for POS INIT's GPS POS: L, or R if L is not navigating; nil if
-- neither is (the line blank: FCOM p.1286)
irsSystem.gpsSource=function()
  if gpsL["aligned"] then return "gpsL" end
  if gpsR["aligned"] then return "gpsR" end
  return nil
end
irsSystem.gpsPos=function()
  local g=irsSystem.gpsSource()
  if g==nil then return "                  " end
  return irsSystem.getLat(g).." "..irsSystem.getLon(g)
end

-- the ND's TIME TO ALIGN while an IRU is in align mode
irsSystem.setStatus=function()
  if irsSystem.aligning() then
    irs_A_status="TIME TO ALIGN"
    irs_L_status=irsSystem.getStatus("irsL")
    irs_C_status=irsSystem.getStatus("irsC")
    irs_R_status=irsSystem.getStatus("irsR")
  else
    irs_A_status=" "
    irs_L_status=" "
    irs_C_status=" "
    irs_R_status=" "
  end
end

irsSystem.off=function()
end

irsSystem.update=function()
  for _,id in ipairs({"irsL","irsC","irsR"}) do
    local i=irsSystem[id]["index"]
    irsSystem[id]["aligned"]=B747DR_nav_irs_nav_valid[i]==1
    irsSystem["motion"][id]=B747DR_nav_irs_motion==1 and B747DR_nav_irs_mode[i]==MODE_ALIGN
  end
  irsSystem["setPos"]=B747DR_nav_irs_set_pos==0
  gpsL["aligned"]=B747DR_nav_gps_valid[0]==1
  gpsR["aligned"]=B747DR_nav_gps_valid[1]==1
  irsSystem.setStatus()

  --Marauder28
  --GPS/IRS DISPLAY
  if irsSystem["irsL"]["aligned"] == true and irsSystem["irsC"]["aligned"] == true and irsSystem["irsR"]["aligned"] == true then
    B747DR_ND_IRS_Line = "IRS (3)"
  elseif irsSystem["irsL"]["aligned"] == true then
	  B747DR_ND_IRS_Line = "IRS (L)"
  elseif irsSystem["irsC"]["aligned"] == true then
	  B747DR_ND_IRS_Line = "IRS (C)"
  elseif irsSystem["irsR"]["aligned"] == true then
	  B747DR_ND_IRS_Line = "IRS (R)"
  else
    B747DR_ND_GPS_Line = "GPS"
  end

  --Update Set Hdg on FMC: dashes while an IRU is in ATT (FCOM p.1286),
  --an entry shown for 2 seconds
  if B747DR_nav_irs_set_hdg_shown==1 then
	if tonumber(string.sub(fmsModules["data"].sethdg,1,3)) ~= nil then
		local diff = simDRTime - timer_start
		if diff < 2 then  --Display for 2 seconds
			return
		end
		timer_start = simDRTime
	end
	fmsModules["data"].sethdg = "---`"
  else
	fmsModules["data"].sethdg = defaultFMSData().sethdg
  end
  --Marauder28
end
function timeToAlignString(left)
  local min=left/60
  if min>7 then return " 7+" end

  return string.format(" %1d",min+1)
end
irsSystem.getStatus=function(systemID)
  local i=irsSystem[systemID]["index"]
  local l=systemID:sub(4, 4)
  local mode=B747DR_nav_irs_mode[i]
  if irsSystem["motion"][systemID]==true then return l.." MOTION" end
  if mode==MODE_OFF then return l.." OFF" end
  if mode==MODE_FAIL then return l.." FAIL" end
  if mode==MODE_ATT then return l.." ATT" end
  if mode==MODE_NAV then return l.." ALIGNED" end
  if B747DR_nav_irs_time_left[i]<=0 then return l.." ALIGN" end
  return l..timeToAlignString(B747DR_nav_irs_time_left[i]).." MIN"
end
irsSystem.getPos=function()
 return toDMS(simDR_latitude,true).." "..toDMS(simDR_longitude,false).. " "..string.format("%02d",simDR_groundspeed).."KT"
end
irsSystem.getLat=function(systemID)
 return irsSystem[systemID].getLat(irsSystem[systemID])
end
irsSystem.getLon=function(systemID)
 return irsSystem[systemID].getLon(irsSystem[systemID])
end
-- SET IRS POS: boxes while the IRUs want a position, then the entered one
-- while they align; blank when none is aligning (FCOM p.1286-1287)
irsSystem.getInitLatPos=function()
 if B747DR_nav_irs_set_pos==1 then return defaultFMSData().initIRSLat end
 if irsSystem.aligning() then return fmsModules["data"]["initIRSLat"] end
 return "         "
end
irsSystem.getInitLonPos=function()
 if B747DR_nav_irs_set_pos==1 then return defaultFMSData().initIRSLon end
 if irsSystem.aligning() then return fmsModules["data"]["initIRSLon"] end
 return "         "
end
irsSystem.getLatD=function(systemID)
 return irsSystem[systemID].getLatD(irsSystem[systemID])
end
irsSystem.getLonD=function(systemID)
 return irsSystem[systemID].getLonD(irsSystem[systemID])
end
irsSystem.calcLatA=function()
 --should use the closest two, but meh
 local alignedIRS=0
 local calcLat=0
 if irsSystem["irsL"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsL") end
 if irsSystem["irsC"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsC") end
 if irsSystem["irsR"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsR") end
 if alignedIRS>1 then return toDMS((calcLat/alignedIRS),true) else return fmsModules["data"]["irsLat"] end
end
irsSystem.calcLonA=function()
 local alignedIRS=0
 local calcLon=0
 if irsSystem["irsL"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsL") end
 if irsSystem["irsC"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsC") end
 if irsSystem["irsR"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsR") end
 if alignedIRS>1 then return toDMS((calcLon/alignedIRS),false) else return fmsModules["data"]["irsLon"] end
end
irsSystem.calcLatD=function()
 --should use the closest two, but meh
 local alignedIRS=0
 local calcLat=0
 if irsSystem["irsL"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsL") end
 if irsSystem["irsC"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsC") end
 if irsSystem["irsR"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLat=calcLat+irsSystem.getLatD("irsR") end
 if alignedIRS>1 then return (calcLat/alignedIRS) else return -9999 end
end
irsSystem.calcLonD=function()
 local alignedIRS=0
 local calcLon=0
 if irsSystem["irsL"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsL") end
 if irsSystem["irsC"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsC") end
 if irsSystem["irsR"]["aligned"]==true then alignedIRS=alignedIRS+1 calcLon=calcLon+irsSystem.getLonD("irsR") end
 if alignedIRS>1 then return (calcLon/alignedIRS) else return -9999 end
end


irsSystem.getGS=function(systemID)
 return irsSystem[systemID].getGS(irsSystem[systemID])
end
irsSystem.getLine=function(systemID)
 return irsSystem.getLat(systemID).." ".. irsSystem.getLon(systemID).. " "..irsSystem.getGS(systemID).."KT"
end

-- a quick start (instant): the module aligns every IRU at NAV at once
irsSystem.align=function(systemID,instant)
  if instant==true then B747CMD_nav_irs_align_now:once() end
end
