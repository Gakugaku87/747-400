--[[
*****************************************************************************************
*        COPYRIGHT � 2020 Mark Parker/mSparks CC-BY-NC4
*****************************************************************************************
]]
--Marauder28
--V Speeds
B747DR_airspeed_V1			= deferred_dataref("laminar/B747/airspeed/V1", "number")
B747DR_airspeed_Vr			= deferred_dataref("laminar/B747/airspeed/Vr", "number")
B747DR_airspeed_V2			= deferred_dataref("laminar/B747/airspeed/V2", "number")
B747DR_airspeed_flapsRef	= deferred_dataref("laminar/B747/airspeed/flapsRef", "number")

--Refuel DR
B747DR_refuel							= deferred_dataref("laminar/B747/fuel/refuel", "number")
--Marauder28

--silvereagle added to end
-- Misc.
B747DR_fmc_spill_lights		= deferred_dataref("laminar/B747/fmc/spill_lights", "number")
B747DR_fmc_cockpit_seats_hide	= deferred_dataref("laminar/B747/fmc/cockpit_seats_hide", "number")
--silvereagle end

acarsOnlineDataref = find_dataref("autoatc/acars/online")
B747DR_acarsProvider = deferred_dataref("laminar/B747/acars/systemProvider", "number")
B747DR_acars = find_dataref("laminar/B747/comm/acars")
fmsFunctions={}
dofile("acars/acars.lua")

-- the EFIS control panel a CDU stands in for: the left CDU the Captain's (0),
-- the right one the F/O's (1), the centre one none (5-2 step 5c; FCOM
-- p.1060: CDU-152; estimate: FCOM gives no CDU for each side)
function B744_cdu_efis_side(fmsID)
  if fmsID=="fmsL" then return 0 elseif fmsID=="fmsR" then return 1 end
  return nil
end
-- EFIS CP SELECT and EICAS CP SELECT only with that control panel failed
-- (FCOM p.1061: "available if EFIS control panel fails"; before, always);
-- otherwise the prompt blank under its title, as CDU-161's (estimate)
function B744_cdu_efis_cp_available(fmsID)
  local side=B744_cdu_efis_side(fmsID)
  return side~=nil and B747DR_fms_efis_fail[side]>0.5
end
function B744_cdu_eicas_cp_available()
  return B747DR_fms_dsp_fail>0.5
end

fmsPages["INDEX"]=createPage("INDEX")
fmsPages["INDEX"].getPage=function(self,pgNo,fmsID)
  local acarsS="             "
  local gs1="                        "
  local efisS=B744_cdu_efis_cp_available(fmsID) and "SELECT>" or "       "
  local eicasS=B744_cdu_eicas_cp_available() and "SELECT>" or "       "

  if simDR_onGround ==1 then
    gs1="                 SELECT>"

  end
  if acars==1 and B747DR_rtp_C_off==0 then 
	acarsS="<ACARS  <REQ>" 
	fmsFunctionsDefs["INDEX"]["L2"]={"setpage","ACARS"}
  else
	fmsFunctionsDefs["INDEX"]["L2"]=nil
	end
return {

"          MENU          ",
"                        ",
"<FMC    <ACT>    "..efisS,
"                        ",
acarsS.."    "..eicasS,
"                        ",
"<SAT                    ",
"                        ",
gs1,
"                        ",
"<ACMS                   ", 
"                        ",
"<CMC             SELECT>"
}
end
fmsPages["INDEX"].getSmallPage=function(self,pgNo,fmsID)

  local gs2="                        "
  if simDR_onGround ==1 then

    gs2="         GROUND HANDLING"
  end
  return {
      "                        ",
      "                 EFIS CP",
      "                        ",
      "                EICAS CP",
      "                        ",
      "                        ",
      "                        ",
      gs2,
      "                        ",
      "                        ",
      "                        ",
      "         AIRCRAFT CONFIG",
      "                        ",
      }
end
fmsFunctionsDefs["INDEX"]={}
fmsFunctionsDefs["INDEX"]["L1"]={"menufmc",""}

fmsFunctionsDefs["INDEX"]["L5"]={"setpage","ACMS"}
fmsFunctionsDefs["INDEX"]["L6"]={"setpage","CMC"}
fmsFunctionsDefs["INDEX"]["R1"]={"efiscp","EFISCTL152"}
fmsFunctionsDefs["INDEX"]["R2"]={"eicascp","EICASMODES"}
fmsFunctionsDefs["INDEX"]["R4"]={"setpage","GNDHNDL"}
fmsFunctionsDefs["INDEX"]["R6"]={"setpage","MAINTSIMCONFIG"}
--fmsFunctionsDefs["INDEX"]["R6"]={"setpage", "MAINTSIMCONFIG"}

-- RTE 1: activepages/B744.fms.pages.rte.lua (6-1/6-2 step 5b)
dofile("activepages/B744.fms.pages.rte.lua")
dofile("activepages/B744.fms.pages.deparr.lua")
dofile("activepages/B744.fms.pages.posinit.lua")
dofile("activepages/B744.fms.pages.perfinit.lua")
dofile("activepages/B744.fms.pages.thrustlim.lua")
dofile("activepages/B744.fms.pages.takeoff.lua")
dofile("activepages/B744.fms.pages.approach.lua")
dofile("activepages/B744.fms.pages.legs.lua")
dofile("activepages/B744.fms.pages.rtedata.lua")
dofile("activepages/B744.fms.pages.wind.lua")
dofile("activepages/B744.fms.pages.desforecast.lua")
dofile("activepages/B744.fms.pages.hold.lua")
dofile("activepages/B744.fms.pages.refnavdata.lua")
dofile("activepages/B744.fms.pages.fixinfo.lua")
dofile("activepages/B744.fms.pages.maint.lua")
dofile("activepages/B744.fms.pages.maintbite.lua")
dofile("activepages/B744.fms.pages.maintcrossload.lua")
dofile("activepages/B744.fms.pages.maintirsmonitor.lua")
dofile("activepages/B744.fms.pages.maintperffactor.lua")
dofile("activepages/B744.fms.pages.progress.lua")
dofile("activepages/B744.fms.pages.actrte1.lua")
dofile("activepages/B744.fms.pages.fmccomm.lua")
dofile("activepages/B744.fms.pages.vnav.lua")
dofile("activepages/B744.fms.pages.groundhandling.lua")
dofile("activepages/B744.fms.pages.maintsimconfig.lua")
dofile("activepages/B744.fms.pages.identpage.lua")
dofile("activepages/atc/B744.fms.pages.atcindex.lua")
dofile("activepages/atc/B744.fms.pages.atclogonstatus.lua")
dofile("activepages/atc/B744.fms.pages.emergency.lua")
dofile("activepages/atc/B744.fms.pages.atcreport.lua")
dofile("activepages/atc/B744.fms.pages.posreport.lua")
dofile("activepages/atc/B744.fms.pages.request.lua")
dofile("activepages/atc/B744.fms.pages.whencanwe.lua")
dofile("activepages/B744.fms.pages.cmc.lua")
dofile("activepages/B744.fms.pages.acms.lua")
dofile("activepages/B744.fms.pages.pax-cargo.lua")
dofile("activepages/B744.fms.pages.efisctl.lua")
dofile("activepages/B744.fms.pages.eicasctl.lua")
dofile("activepages/B744.fms.pages.doors.lua")
dofile("activepages/B744.fms.pages.soundconfig.lua")

--[[
dofile("B744.fms.pages.actclb.lua")
dofile("B744.fms.pages.actcrz.lua")
dofile("B744.fms.pages.actdes.lua")
dofile("B744.fms.pages.actirslegs.lua")
dofile("B744.fms.pages.actrte1data.lua")
dofile("B744.fms.pages.actrte1hold.lua")
dofile("B744.fms.pages.actrte1legs.lua")
dofile("B744.fms.pages.altnnavradio.lua")
dofile("B744.fms.pages.approach.lua")
dofile("B744.fms.pages.arrivals.lua")


dofile("B744.fms.pages.atcrejectdueto.lua")

dofile("B744.fms.pages.atcreport2.lua")
dofile("B744.fms.pages.atcuplink.lua")
dofile("B744.fms.pages.atcverifyresponse.lua")
dofile("B744.fms.pages.deparrindex.lua")
dofile("B744.fms.pages.departures.lua")
dofile("B744.fms.pages.fixinfo.lua")

dofile("B744.fms.pages.identpage.lua")
dofile("B744.fms.pages.irsprogress.lua")
dofile("B744.fms.pages.navradpage.lua")
dofile("B744.fms.pages.progress.lua")
dofile("B744.fms.pages.refnavdata1.lua")
dofile("B744.fms.pages.satcom.lua")
dofile("B744.fms.pages.waypointwinds.lua")

]]


fmsPages["INITREF"]=createPage("INITREF")
fmsPages["INITREF"].getPage=function(self,pgNo,fmsID)
  local lineA="                        "
  local LineB="<APPROACH               "
  if simDR_onGround ==1 then
    fmsFunctionsDefs["INITREF"]["L5"]={"setpage","TAKEOFF"}
    fmsFunctionsDefs["INITREF"]["R6"]={"setpage","MAINT"}
    lineA="<TAKEOFF                "
    LineB="<APPROACH         MAINT>"
  else
    fmsFunctionsDefs["INITREF"]["L5"]=nil
    fmsFunctionsDefs["INITREF"]["R6"]=nil
  end
  return {

  "     INIT/REF INDEX 1/1 ",
  "                        ",
  "<IDENT         NAV DATA>",
  "                        ",
  "<POS                    ",
  "                        ",
  "<PERF                   ",
  "                        ",
  "<THRUST LIM             ",
  "                        ",
  lineA, 
  "                        ",
  LineB
  }
end

fmsFunctionsDefs["INITREF"]={}
fmsFunctionsDefs["INITREF"]["L1"]={"setpage","IDENT"}
fmsFunctionsDefs["INITREF"]["L2"]={"setpage","POSINIT"}
fmsFunctionsDefs["INITREF"]["L3"]={"setpage","PERFINIT"}
fmsFunctionsDefs["INITREF"]["L4"]={"setpage","THRUSTLIM"}

fmsFunctionsDefs["INITREF"]["L6"]={"setpage","APPROACH"}

-- REF NAV DATA (step 7e: B744.fms.pages.refnavdata.lua; before: X-Plane's
-- DATABASE page)
fmsFunctionsDefs["INITREF"]["R1"]={"refnavdata",""}
local navAids
simDR_variation=find_dataref("sim/flightmodel/position/magnetic_variation")
B747DR_ils_dots           	= deferred_dataref("laminar/B747/autopilot/ils_dots", "number")
-- the AFDS's ILS TUNE INHIBIT (6-3 step 5d; FCOM p.1305: "manual-tuning
-- [is] inhibited" with it): no entry or deletion then (INVALID ENTRY: an
-- estimate of the CDU's answer)
B747DR_fms_ils_tune_inhibit	= find_dataref("laminar/B747/autopilot/ils_tune_inhibit")
function findILS(value)

  local modes=B747DR_radioModes
  if B747DR_fms_ils_tune_inhibit > 0.5 then return false end
  if navAidsJSON==nil or string.len(navAidsJSON)<5 then return false end
  if value=="DELETE" then 
    B747DR_radioModes=replace_char(1,modes," ")
	ilsData=""
	B747DR_ils_dots=0
    return true
  end
  B747DR_radioModes=replace_char(1,modes,"M")
  navAids=json.decode(navAidsJSON)
  local direction=nil
  local valueSO=split(value,"/")
  --print(value)
  if table.getn(valueSO) > 1 then
    value=valueSO[1]
     --print(value)
    direction=tonumber(valueSO[2])
    --print(value.." and " .. direction)
  else
    --print(value)
  end
  --print(" in " .. navAidsJSON)
  local val=tonumber(value)
  if val~=nil then val=val*100 end
  local found=false
  local bestDist=360
  for n=table.getn(navAids),1,-1 do
      if navAids[n][2] == 8 then
	  --print("navaid "..n.."->".. navAids[n][1].." ".. navAids[n][2].." ".. navAids[n][3].." ".. navAids[n][4].." ".. navAids[n][5].." ".. navAids[n][6].." ".. navAids[n][7].." ".. navAids[n][8])
	  
	 if (value==navAids[n][8] or (val~=nil and val==navAids[n][3])) and (direction==nil or getHeadingDifferenceM(direction,navAids[n][4])<bestDist) then
	    found=true
		ilsData=json.encode(navAids[n])
		local course=(navAids[n][4]+simDR_variation)
	    print("68 - Tuning ILSs ".. ilsData)
	    if direction ~=nil then
		  bestDist=getHeadingDifferenceM(direction,navAids[n][4])
		  --course=direction
		end
		if course<0 then
			course=course+360
		elseif course>360 then
			course=course-360
  		end
	    simDR_nav1Freq=navAids[n][3]
	    simDR_nav2Freq=navAids[n][3] 	
	    simDR_radio_nav_obs_deg[0]=course
		simDR_radio_nav_obs_deg[1]=course
	    print("68 - Tuned ILS "..course)
	    print("68 - useThis "..bestDist)
	  end
      end
   end

   return found
end



fmsPages["NAVRAD"]=createPage("NAVRAD")

ils_line1 = ""
ils_line2 = ""
park = "PARK"
original_distance = -1

fmsPages["NAVRAD"].getPage=function(self,pgNo,fmsID)
  local ils1="                        "
  local ils2="                        "
  local modes=B747DR_radioModes
  local dist_to_TOD = B747BR_totalDistance - B747BR_tod
  if string.len(ilsData)>1 then
    local ilsNav=json.decode(ilsData)
    ils2= ilsNav[7]
	ils_line2 = "   "..ils2
    if original_distance == -1 then
		original_distance = B747BR_totalDistance  --capture original flightplan distance
	end
  --print("Dist to TOD = "..dist_to_tod)	
	local course = ilsNav[4]+simDR_variation
	if course<0 then
		course=course+360
	end

		if (dist_to_TOD >= 50 and dist_to_TOD < 200) then
			--ils2= string.format("%6.2f/%03d%s %4s          .", ilsNav[3]*0.01,(ilsNav[4]+simDR_variation), "˚", park)
			ils1 = "            "..park
			ils_line1 = string.format("<%6.2f/%03d%s           ", ilsNav[3]*0.01,((simDR_radio_nav_obs_deg[0])), "˚")
		elseif (dist_to_TOD < 50) then
			ils1= string.format("%6.2f/%03d%s          ", ilsNav[3]*0.01,((simDR_radio_nav_obs_deg[0])), "`"..modes:sub(1, 1))
			ils_line1 = ""
		end
  else
    ils1 = park
	ils_line1 = ""
	ils_line2 = ""
  end
  local modes=B747DR_radioModes
  local vorL_radial="---"
  local vorR_radial="---"
  local vorL_obs="---"
  local vorR_obs="---"
  if simDR_radio_nav_horizontal[2]==1 then vorL_radial=string.format("%03d",simDR_radio_nav_radial[2]) end
  if simDR_radio_nav_horizontal[3]==1 then vorR_radial=string.format("%03d",simDR_radio_nav_radial[3]) end
  if modes:sub(2, 2)=="M" then vorL_obs=string.format("%03d",simDR_radio_nav_obs_deg[2]) end
  if modes:sub(3, 3)=="M" then vorR_obs=string.format("%03d",simDR_radio_nav_obs_deg[3]) end
  local page={
    "        NAV RADIO       ",
    "                        ",
    string.format("%6.2f %4s  %4s %6.2f", simDR_radio_nav_freq_hz[2]*0.01, simDR_radio_nav03_ID, simDR_radio_nav04_ID, simDR_radio_nav_freq_hz[3]*0.01),
    string.format("                        ", ""),
    string.format("%3s      %3s  %3s    %3s", vorL_obs, vorL_radial,vorR_radial, vorR_obs),
    "                        ",
    string.format("%06.1f           %06.1f ", simDR_radio_adf1_freq_hz, simDR_radio_adf2_freq_hz),
    "                        ",
    ils1,
--    ils2,
    "                        ",	
    "                        ", 
--    "--------         -------",
    "                        ", 
    fmsModules["data"]["preselectLeft"].."            "..fmsModules["data"]["preselectRight"],
    }
  return page
end
fmsPages["NAVRAD"].getSmallPage=function(self,pgNo,fmsID)
  local modes=B747DR_radioModes
  return{
  "                        ",
  " VOR L             VOR R",
  "      ".. modes:sub(2, 2) .."          ".. modes:sub(3, 3) .."      ",
  " CRS      RADIAL     CRS",
  "                        ",
  " ADF L             ADF R",
  "      M                M",
--  " ILS ".. modes:sub(1, 1) .."                  ",
  " ILS - MLS              ",  
--  "                        ",
  ils_line1,
  ils_line2,
--  ,
--  "                        ",
  "                        ",
  "        PRESELECT       ",
  "                        ",
  }
end
fmsFunctionsDefs["NAVRAD"]["L1"]={"setDref","VORL"}
fmsFunctionsDefs["NAVRAD"]["L2"]={"setDref","CRSL"}
fmsFunctionsDefs["NAVRAD"]["L3"]={"setDref","ADFL"}
fmsFunctionsDefs["NAVRAD"]["R1"]={"setDref","VORR"}
fmsFunctionsDefs["NAVRAD"]["R2"]={"setDref","CRSR"}
fmsFunctionsDefs["NAVRAD"]["R3"]={"setDref","ADFR"}
fmsFunctionsDefs["NAVRAD"]["L4"]={"setDref","ILS"}
fmsFunctionsDefs["NAVRAD"]["L6"]={"setdata","preselectLeft"}
fmsFunctionsDefs["NAVRAD"]["R6"]={"setdata","preselectRight"}
--fmsFunctionsDefs["NAVRAD"]["L6"]={"setpage","ACARS"}
function fmsFunctions.setpage_no(fmsO,valueA)
  print("setpage_no="..valueA)
    local valueO=split(valueA,"_")
    print(valueO[1].." "..valueO[2])
   --fmsO["pgNo"]=tonumber(valueO[2])
   fmsO["targetpgNo"]=tonumber(valueO[2])
   value=valueO[1]

     
  if value=="FMC" then
    fmsO["targetCustomFMC"]=false
    fmsO["targetPage"]="FMC"
    simCMD_FMS_key[fmsO.id]["fpln"]:once()
    simCMD_FMS_key[fmsO.id]["L6"]:once()
	simCMD_FMS_key[fmsO.id]["L2"]:once()
  elseif value=="PROGRESS" then
    -- (6-1/6-2 step 9h5a) the FMC's own PROGRESS pages (the PROG key's) at
    -- the page given: the CRZ page's <RTA PROGRESS to 3/3 (before, X-Plane's
    -- CDU's PROGRESS at its page 1)
    fmsO["targetCustomFMC"]=true
    fmsO["targetPage"]="PROGRESS"
  elseif value=="VHFCONTROL" then
    fmsO["targetCustomFMC"]=false
    fmsO["targetPage"]="VHFCONTROL"
    simCMD_FMS_key[fmsO.id]["navrad"]:once()
    
  elseif value=="IDENT" then
    fmsO["targetCustomFMC"]=true
    fmsO["targetPage"]="IDENT"
    simCMD_FMS_key[fmsO.id]["index"]:once()
    simCMD_FMS_key[fmsO.id]["L1"]:once()
    
  elseif value=="DATABASE" then
    fmsO["targetCustomFMC"]=false
    fmsO["targetPage"]="DATABASE"
    simCMD_FMS_key[fmsO.id]["index"]:once()
    simCMD_FMS_key[fmsO.id]["R2"]:once()
  else
    fmsO["targetCustomFMC"]=true
    fmsO["targetPage"]=value 
 
  end
  print("setpage " .. value)
  run_after_time(switchCustomMode, 0.5)
end
function fmsFunctions.efiscp(fmsO,value)
  if B744_cdu_efis_cp_available(fmsO.id) then fmsFunctions.setpage(fmsO,value) end
end
function fmsFunctions.eicascp(fmsO,value)
  if B744_cdu_eicas_cp_available() then fmsFunctions.setpage(fmsO,value) end
end
-- MENU's <FMC (6-1/6-2 step 3c)
function fmsFunctions.menufmc(fmsO,value)
  B747_cdu_menu_fmc(fmsO)
end
function fmsFunctions.setpage(fmsO,value)
  value=value.."_1"
  fmsFunctions["setpage_no"](fmsO,value)
  --sim/FMS/navrad
  --sim/FMS2/navrad
  
end
function fmsFunctions.custom2fmc(fmsO,value)
  print("custom2fmc" .. value)
  B747_cdu_native_sent(fmsO["id"], fmsO["scratchpad"], 3 + string.len(fmsO["scratchpad"]))
  simCMD_FMS_key[fmsO["id"]]["del"]:once()
  simCMD_FMS_key[fmsO["id"]]["clear"]:once()
  if value~="next" and value~="prev" and string.len(fmsO["scratchpad"])>0 then
    for c in string.gmatch(fmsO["scratchpad"],".") do
      local v=c
	if v=="/" then v="slash" end
	simCMD_FMS_key[fmsO["id"]][v]:once()
    end
  elseif value=="next" then
    fmsO["targetpgNo"]=fmsO["pgNo"]+1
    run_after_time(switchCustomMode, 0.5)
  elseif value=="prev" then 
    fmsO["targetpgNo"]=fmsO["pgNo"]-1
    run_after_time(switchCustomMode, 0.5)
  end
  simCMD_FMS_key[fmsO["id"]][value]:once()
  fmsO["scratchpad"]=""
end
function fmsFunctions.key2fmc(fmsO,value)
  print("key2fmc" .. value)
  B747_cdu_native_sent(fmsO["id"], fmsO["scratchpad"], 3 + string.len(fmsO["scratchpad"]))
  if string.len(fmsO["scratchpad"])>0 then
    simCMD_FMS_key[fmsO["id"]]["del"]:once()
    simCMD_FMS_key[fmsO["id"]]["clear"]:once()
    if value~="next" and value~="prev" then
      for c in string.gmatch(fmsO["scratchpad"],".") do
	local v=c
	if v=="/" then v="slash" end
	simCMD_FMS_key[fmsO["id"]][v]:once()
      end
    end
  end
  simCMD_FMS_key[fmsO["id"]][value]:once()
  fmsO["scratchpad"]=""
  fmsO["notify"]=""
end
local updateFrom="fmsL"
local lastCrz=0

function updateCRZ()
  local setVal=string.sub(B747DR_srcfms[updateFrom][3],20,24)
  print("from line".. updateFrom.." "..B747DR_srcfms[updateFrom][3])
  print("to:"..setVal)
  local alt=validAlt(setVal)
  if alt~=nil then 
	B747BR_cruiseAlt=alt 
	lastCrz=B747BR_cruiseAlt
  end
  fmsModules:setData("crzalt",setVal)
end

function monitorCRZALT()
	local thisCRZ=B747BR_cruiseAlt
	if thisCRZ==lastCrz then return end
	lastCrz=thisCRZ
	if thisCRZ>0 then
		fmsModules:setData("crzalt", B747_cdu_model.format_alt(thisCRZ, tonumber(fmsModules["data"]["transalt"]) or 18000))
	else
		fmsModules:setData("crzalt", "*****")
	end
end

function fmsFunctions.getdata(fmsO,value) 
  local data=""
  if value=="gpspos" then
    -- GPS L, or R; nothing without a navigating GPS
    local g=irsSystem.gpsSource()
    if g~=nil then data=irsSystem.getLat(g) .." " .. irsSystem.getLon(g) end
  elseif value=="lastpos" then
    data=irsSystem.calcLatA() .." "..irsSystem.calcLonA()
  else
    data=getFMSData(value)
  end
  fmsO["scratchpad"]=data
end
function validateSpeed(value)
  local val=tonumber(value)
  if val==nil then return false end
  if val<100 or val>400 then return false end

  return true
end
function validAlt(value)
  local val=tonumber(value)
  if string.len(value)>2 and string.sub(value,1,2)=="FL" then val=tonumber(string.sub(value,3)) end
  
  if val==nil then return nil end
  if val<1000 then val=val*100 end
  local maxA = 58.16363636 - 0.06154545  * (simDR_GRWT/1000) -- model derived fcom p. 1576, ISA+10 and below
  if val<2000 or val>(maxA*1000) then return nil end

  return ""..val
end
function validFL(value)
  local val=tonumber(value)
  if string.len(value)>2 and string.sub(value,1,2)=="FL" then val=tonumber(string.sub(value,3)) end
  
  if val==nil then return nil end
  if val<1000 then val=val*100 end
  local maxA = 58.16363636 - 0.06154545  * (simDR_GRWT/1000) -- model derived fcom p. 1576, ISA+10 and below
  if val<10000 or val>(maxA*1000) then return nil end

  return "FL".. (val/100)
end
-- a speed entry (6-1/6-2 step 8b; FMSPG p.113): a CAS of 100 to 400 kt, a
-- Mach of .100 to .990 (the point and one to three digits) or both, CAS/Mach
-- or Mach/CAS: the CAS and the Mach in thousandths, either nil; nil, nil if
-- invalid
function parseSpeedEntry(s)
  local cas, mach
  local a, b = string.match(s, "^([^/]*)/([^/]*)$")
  for _, v in ipairs(a and {a, b} or {s}) do
    local c, m = B747_cdu_model.parse_speed(v)
    if c and c >= 100 and c <= 400 and not cas then
      cas = c
    elseif m and m >= 0.1 and not mach then
      mach = math.floor(m * 1000 + 0.5)
    else
      return nil, nil
    end
  end
  return cas, mach
end
function validateMachSpeed(value)
  local val=tonumber(value)
  
  
  if val==nil then return nil end
  if val<1 then val=val*1000 end
  if val<100 then val=val*10 end
  if val<400 or val>870 then return nil end

  return ""..val
end

-- VALIDATE ENTRY OF WEIGHT UNITS
function validate_weight_units(value)
	--local val=tostring(value)
	--print(value)
	if value == "KGS" or value == "LBS" then
		return true
	else
		return false
	end
end

-- VALIDATE ENTRY OF SETHDG
function validate_sethdg(value)
	--print(value)
	local hdg = tonumber(value)
	if hdg ~= nil and hdg >= 0 and hdg <= 360 then
		return true
	else
		return false
	end
end

function preselect_fuel()
	-- DETERMINE FUEL WEIGHT DISPLAY UNITS
	local fuel_calculation_factor = 1
	
	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		fuel_calculation_factor = simConfigData["data"].SIM.kgs_to_lbs
	end
	
	B747DR_refuel=B747DR_fuel_add * 1000 / fuel_calculation_factor  --(always add fuel in KGS behind the scenes)
	B747DR_fuel_preselect=simDR_fueL_tank_weight_total_kg + B747DR_refuel
	
	-- Used in calculation for displaying Preselect Fuel Qty in correct weight units (actual display done in B747.25.xt.fuel)
	B747DR_fuel_preselect_temp = B747DR_fuel_preselect
	B747DR_fuel_add=0
	simDR_m_jettison=simDR_acf_m_jettison
	
	--Marauder28
	--Set the totalizer to the current fuel amount before refueling
	simDR_fuel_totalizer_kg = simDR_fueL_tank_weight_total_kg
	--Marauder28
end

--Marauder28
function calc_pax_cargo()
	local pax_total				= 0
	local pax_weightA			= 0
	local pax_weightB			= 0
	local pax_weightC			= 0
	local pax_weightD			= 0
	local pax_weightE			= 0
	local pax_weight_Tot		= 0
	local cargo_weight_fwd		= 0
	local cargo_weight_aft		= 0
	local cargo_weight_bulk		= 0
	local cargo_weight_tot		= 0
	local freight_weightA		= 0
	local freight_weightB		= 0
	local freight_weightC		= 0
	local freight_weightD		= 0
	local freight_weightE		= 0
	local freight_weight_tot	= 0

	pax_total		= 	tonumber(fmsModules["data"].paxFirstClassA) + tonumber(fmsModules["data"].paxBusClassB)
						+ tonumber(fmsModules["data"].paxEconClassC) + tonumber(fmsModules["data"].paxEconClassD)
						+ tonumber(fmsModules["data"].paxEconClassE)
	pax_weightA		=	tonumber(fmsModules["data"].paxFirstClassA) * simConfigData["data"].SIM.std_pax_weight
	pax_weightB		= 	tonumber(fmsModules["data"].paxBusClassB) * simConfigData["data"].SIM.std_pax_weight
	pax_weightC		=	tonumber(fmsModules["data"].paxEconClassC) * simConfigData["data"].SIM.std_pax_weight
	pax_weightD		=	tonumber(fmsModules["data"].paxEconClassD) * simConfigData["data"].SIM.std_pax_weight
	pax_weightE		=	tonumber(fmsModules["data"].paxEconClassE) * simConfigData["data"].SIM.std_pax_weight
	pax_weight_Tot	=	pax_weightA + pax_weightB + pax_weightC + pax_weightD + pax_weightE

	cargo_weight_fwd	= tonumber(fmsModules["data"].cargoFwd)
	cargo_weight_aft	= tonumber(fmsModules["data"].cargoAft)
	cargo_weight_bulk	= tonumber(fmsModules["data"].cargoBulk)
	cargo_weight_tot	= cargo_weight_fwd + cargo_weight_aft + cargo_weight_bulk
	
	freight_weightA		= tonumber(fmsModules["data"].freightZoneA)
	freight_weightB		= tonumber(fmsModules["data"].freightZoneB)
	freight_weightC		= tonumber(fmsModules["data"].freightZoneC)
	freight_weightD		= tonumber(fmsModules["data"].freightZoneD)
	freight_weightE		= tonumber(fmsModules["data"].freightZoneE)
	freight_weight_tot	= freight_weightA + freight_weightB + freight_weightC + freight_weightD + freight_weightE
	
	--Assign values to FMC
	fmsModules["data"].paxTotal 		= pax_total
	fmsModules["data"].paxWeightA		= pax_weightA
	fmsModules["data"].paxWeightB		= pax_weightB
	fmsModules["data"].paxWeightC		= pax_weightC
	fmsModules["data"].paxWeightD		= pax_weightD
	fmsModules["data"].paxWeightE		= pax_weightE
	fmsModules["data"].paxWeightTotal	= pax_weight_Tot
	fmsModules["data"].cargoTotal		= cargo_weight_tot
	fmsModules["data"].freightTotal		= freight_weight_tot
	
	--Assign values to WB
	wb.passenger_zoneA_weight		= pax_weightA	
	wb.passenger_zoneB_weight		= pax_weightB
	wb.passenger_zoneC_weight		= pax_weightC
	wb.passenger_zoneD_weight		= pax_weightD
	wb.passenger_zoneE_weight		= pax_weightE
	wb.fwd_lower_cargo_weight		= cargo_weight_fwd
	wb.aft_lower_cargo_weight		= cargo_weight_aft
	wb.bulk_lower_cargo_weight		= cargo_weight_bulk
	wb.freight_zoneA_weight			= freight_weightA
	wb.freight_zoneB_weight			= freight_weightB
	wb.freight_zoneC_weight			= freight_weightC
	wb.freight_zoneD_weight			= freight_weightD
	wb.freight_zoneE_weight			= freight_weightE
	
	--Update Sim Payload weight with PAX & Cargo entries
	simDR_payload_weight = pax_weight_Tot + cargo_weight_tot + freight_weight_tot
	
	--print("PAX A Wgt = "..pax_weightA)
	--print("PAX A = "..tonumber(fmsModules["data"].paxFirstClassA))
	--print("PAX B Wgt = "..pax_weightB)
	--print("PAX B = "..tonumber(fmsModules["data"].paxBusClassB))
	--print("PAX C Wgt = "..pax_weightC)
	--print("PAX C = "..tonumber(fmsModules["data"].paxEconClassC))
	--print("PAX D Wgt = "..pax_weightD)
	--print("PAX D = "..tonumber(fmsModules["data"].paxEconClassD))
	--print("PAX E Wgt = "..pax_weightE)
	--print("PAX E = "..tonumber(fmsModules["data"].paxEconClassE))
	--print("PAX Tot = "..pax_weight_Tot)
	--print("Cargo Fwd = "..cargo_weight_fwd)
	--print("Cargo Aft = "..cargo_weight_aft)
	--print("Cargo Bulk = "..cargo_weight_bulk)
	--print("Cargo Tot = "..cargo_weight_tot)
	--print("FREIGHT A = "..freight_weightA)
	--print("FREIGHT B = "..freight_weightB)
	--print("FREIGHT C = "..freight_weightC)
	--print("FREIGHT D = "..freight_weightD)
	--print("FREIGHT E = "..freight_weightE)
	--print("Freight Tot = "..freight_weight_tot)
end
--Marauder28

--Marauder28
timer_start = 0
--Marauder28

function fmsFunctions.setdata(fmsO,value)
  local del=false  
  if fmsO["scratchpad"]=="DELETE" then fmsO["scratchpad"]="" del=true end
  local fo=fmsO.id=="fmsR"
  if value=="WXR" then
	-- that CDU's side (5-2 step 5c: always the Captain's before)
	if fo then
		fmsModules["cmds"]["sim/instruments/EFIS_copilot_wxr"]:once()
	else
		fmsModules["cmds"]["sim/instruments/EFIS_wxr"]:once()
	end
  elseif value=="POS" then
	if fo then B747DR_nd_fo_pos=1-B747DR_nd_fo_pos else B747DR_nd_capt_pos=1-B747DR_nd_capt_pos end
  elseif value=="MTRS" then
	if fo then
		B747DR_efis_meters_fo_selected=1-B747DR_efis_meters_fo_selected
	else
		B747DR_efis_meters_capt_selected=1-B747DR_efis_meters_capt_selected
	end
  elseif value=="FPV" then
	if fo then
		B747DR_efis_fpv_fo_selected=1-B747DR_efis_fpv_fo_selected
	else
		B747DR_efis_fpv_capt_selected=1-B747DR_efis_fpv_capt_selected
	end
  elseif value=="TERR" then
	if fmsO.id=="fmsR" then 
		B747DR_nd_fo_terr = 1-B747DR_nd_fo_terr
	else
		B747DR_nd_capt_terr=1-B747DR_nd_capt_terr
	end
  elseif value=="TFC" then
	if fmsO.id=="fmsR" then 
		B747DR_nd_fo_traffic_Selected=1-B747DR_nd_fo_traffic_Selected
	else
		B747DR_nd_capt_traffic_Selected=1-B747DR_nd_capt_traffic_Selected
	end
	
  elseif value=="VORDISP" then
	if fmsO.id=="fmsR" then 
		simDR_EFIS_1_sel_fo =2
		simDR_EFIS_2_sel_fo =2
	else
		simDR_EFIS_1_sel_pilot=2
		simDR_EFIS_2_sel_pilot=2
	end
  elseif value=="WPT" then
	
	if fmsO.id=="fmsR" then 
		B747DR_nd_fo_wpt=1-B747DR_nd_fo_wpt 
	else
		B747DR_nd_capt_wpt=1-B747DR_nd_capt_wpt
	end
  elseif value=="STA" then
	if fmsO.id=="fmsR" then 
		B747DR_nd_fo_vor_ndb = 1-B747DR_nd_fo_vor_ndb 
	else
		B747DR_nd_capt_vor_ndb=1-B747DR_nd_capt_vor_ndb
	end
  elseif value=="ARPT" then
	if fmsO.id=="fmsR" then 
		B747DR_nd_fo_apt=1-B747DR_nd_fo_apt
	else
		B747DR_nd_capt_apt=1-B747DR_nd_capt_apt
	end
  elseif value=="DATA" then
	if fo then B747DR_nd_fo_data=1-B747DR_nd_fo_data else B747DR_nd_capt_data=1-B747DR_nd_capt_data end
  elseif value=="ADFDISP" then
	if fmsO.id=="fmsR" then 
		simDR_EFIS_1_sel_fo =0
		simDR_EFIS_2_sel_fo =0
	else
		simDR_EFIS_1_sel_pilot=0
		simDR_EFIS_2_sel_pilot=0
	end
  elseif value=="DHRESET" then
	-- that CDU's side, also with the panel failed (5-2 step 5c: both CDUs
	-- pushed the Captain's switch before)
	if fo then B747CMD_fms_dh_reset_fo:once() else B747CMD_fms_dh_reset_capt:once() end
  elseif value=="DH" then
	if tonumber(fmsO["scratchpad"]) ==nil then 
		fmsO["notify"]="INVALID ENTRY"
		return
	end
	local alt=tonumber(fmsO["scratchpad"])
	if fmsO.id=="fmsR" then 
		simDR_radio_alt_DH_fo=alt
	else
		simDR_radio_alt_DH_capt=alt
	end
  elseif value=="MDA" then
		if tonumber(fmsO["scratchpad"]) ==nil then 
			fmsO["notify"]="INVALID ENTRY"
			return
		end
		local alt=tonumber(fmsO["scratchpad"])
		if fmsO.id=="fmsR" then 
			B747DR_efis_baro_alt_ref_fo=alt
		else
			B747DR_efis_baro_alt_ref_capt=alt
		end
  elseif value=="EFISMAP" then
	if fmsO.id=="fmsR" then 
		simDR_nd_mode_dial_fo= 2
	else
		simDR_nd_mode_dial_capt= 2
	end
  elseif value=="EFISPLN" then
		if fmsO.id=="fmsR" then 
			simDR_nd_mode_dial_fo= 3
		else
			simDR_nd_mode_dial_capt= 3
		end	
  elseif value=="EFISAPP" then
		if fmsO.id=="fmsR" then 
			simDR_nd_mode_dial_fo= 0
		else
			simDR_nd_mode_dial_capt= 0
		end	
  elseif value=="EFISVOR" then
		if fmsO.id=="fmsR" then 
			simDR_nd_mode_dial_fo= 1
		else
			simDR_nd_mode_dial_capt= 1
		end	
  elseif value=="EFISCTR" then
	-- as the CTR switch: APP, VOR and MAP (FCOM p.1063; 5-2 step 5c)
	if fo then
		if simDR_nd_mode_dial_fo<3 then simDR_nd_center_dial_fo=1-simDR_nd_center_dial_fo end
	elseif simDR_nd_mode_dial_capt<3 then
		simDR_nd_center_dial_capt=1-simDR_nd_center_dial_capt
	end
	elseif value=="BARO" then
		-- this CDU's side only, with the entries of FCOM p.1064 (5-2 step 4b,
		-- B744.fms.baro.lua; both sides were set before, and a number was
		-- taken in the units the knob showed)
		local fo = fmsO.id=="fmsR"
		local kind, inhg, hpa = B744_cdu_baro_entry(fmsO["scratchpad"])
		if kind==nil then
			fmsO["notify"]="INVALID ENTRY"
			return
		end
		if kind=="std" then
			-- as the EFIS control panel's STD push: the setting before STD
			-- comes back on the next push (FCOM p.1037)
			if fo then
				if B747DR_efis_baro_std_fo_switch_pos==0 then B747CMD_fms_baro_std_fo:once() end
			elseif B747DR_efis_baro_std_capt_switch_pos==0 then
				B747CMD_fms_baro_std_capt:once()
			end
			return
		end
		local units = hpa and 1 or 0
		if fo then B747DR_efis_baro_ref_fo_sel_dial_pos=units else B747DR_efis_baro_ref_capt_sel_dial_pos=units end
		if kind=="units" then return end
		if fo then
			simDR_altimeter_baro_inHg_fo=inhg
			B747DR_efis_baro_std_fo_switch_pos=0
			B747DR_efis_baro_std_fo_show_preselect=0
		else
			simDR_altimeter_baro_inHg=inhg
			B747DR_efis_baro_std_capt_switch_pos=0
			B747DR_efis_baro_std_capt_show_preselect=0
		end
  elseif value=="RANGEINC" or value=="RANGEDEC" then
	-- that CDU's side (5-2 step 5c: both before), as the range selector does;
	-- X-Plane's map range follows the selector in the display glue
	-- (B747.60.xt.displays.lua: MAP CTR one range up, 2026-10-28)
	local step=value=="RANGEINC" and 1 or -1
	if fo then
		simDR_range_dial_fo=math.max(0, math.min(6, simDR_range_dial_fo+step))
	else
		simDR_range_dial_capt=math.max(0, math.min(6, simDR_range_dial_capt+step))
	end
  elseif value=="depdst" and string.len(fmsO["scratchpad"])>3  then
    dep=string.sub(fmsO["scratchpad"],1,4)
    dst=string.sub(fmsO["scratchpad"],-4)
    --fmsModules["data"]["fltdep"]=dep
    --fmsModules["data"]["fltdst"]=dst
    setFMSData("fltdep",dep)
    setFMSData("fltdst",dst)
  elseif value=="clbspd" then
    -- SEL SPD (6-1/6-2 step 8b; FMSPG p.113): a CAS, a Mach or both; a
    -- CAS alone climbs to the cruise's Mach. <ECON gives ECON back.
    local cas, mach = parseSpeedEntry(fmsO["scratchpad"])
    if cas == nil and mach == nil then fmsO["notify"]="INVALID ENTRY" return end
    if cas then setFMSData("clbspd", string.format("%3d", cas)) end
    setFMSData("clbspdmach", mach and string.format("%03d", mach) or "")
    setFMSData("clbspdmode", "S")
  elseif value=="clbtrans" then
    -- SPD TRANS: from the nav DB and VREF, deleted only (FMC-09, 6-1 step 1;
    -- FCOM p.1328); no transition speed then
    if del then
      setFMSData("transpd","---")
    else
      fmsO["notify"]="INVALID ENTRY"
    end
  elseif value=="transalt" then
    if validAlt(fmsO["scratchpad"]) ~=nil then 
	setFMSData("transalt",validAlt(fmsO["scratchpad"]))
    else
      fmsO["notify"]="INVALID ENTRY"
    end
  elseif value=="clbrest" and del then
    setFMSData("clbrestspd","---")
    setFMSData("clbrestalt","-----")
  elseif value=="clbrest" then
    spd=string.sub(fmsO["scratchpad"],1,3)
    alt=string.sub(fmsO["scratchpad"],5)
    if validateSpeed(spd) ==false then 
      fmsO["notify"]="INVALID ENTRY"
    else
      setFMSData("clbrestspd",spd)
      if validAlt(alt) ~=nil then 
	setFMSData("clbrestalt",validAlt(alt))
      end
    end
  elseif value=="crzspd" then
    -- SEL SPD (6-1/6-2 step 8b; FCOM p.1348, FMSPG p.132): a CAS or a Mach
    local cas, mach = parseSpeedEntry(fmsO["scratchpad"])
    if (cas == nil) == (mach == nil) then fmsO["notify"]="INVALID ENTRY" return end
    if mach then setFMSData("crzspd", string.format("%03d", mach)) end
    setFMSData("crzcas", cas and string.format("%3d", cas) or "")
    setFMSData("crzspdmode", "S")
  elseif value=="stepalt" then
    -- STEP TO (6-1/6-2 step 8b2; FCOM p.1348, FMSPG p.133): a crew's entry
    -- above CRZ ALT, FLXXX, XXX or XXXXX, kept until a new CRZ ALT; DELETE
    -- gives the FMC's back
    if del then setFMSData("stepalt", "") return end
    local ft = B747_cdu_model.parse_alt(fmsO["scratchpad"])
    if ft == nil or B747BR_cruiseAlt <= 0 or ft <= B747BR_cruiseAlt or ft > 45100 then
      fmsO["notify"]="INVALID ENTRY"
      return
    end
    setFMSData("stepalt", string.format("FL%03d", math.floor(ft / 100 + 0.5)))
  elseif value=="desspds" then
    -- SEL SPD (6-1/6-2 step 8b; FCOM p.1392, FMSPG p.192): a CAS, a Mach or
    -- both (the A/P commands no more than 354 kt of them, FCOM p.1258)
    local cas, mach = parseSpeedEntry(fmsO["scratchpad"])
    if cas == nil and mach == nil then fmsO["notify"]="INVALID ENTRY" return end
    if cas then setFMSData("desspd", string.format("%3d", cas)) end
    if mach then setFMSData("desspdmach", string.format("%03d", mach)) end
    setFMSData("desspdmode", "S")
  elseif value=="destrans" then
    spd=string.sub(fmsO["scratchpad"],1,3)
    alt=string.sub(fmsO["scratchpad"],5)
    if validateSpeed(spd) ==false then 
      fmsO["notify"]="INVALID ENTRY"
    else
      setFMSData("destranspd",spd)
      if validAlt(alt) ~=nil then 
	setFMSData("desspdtransalt",validAlt(alt))
      end
    end 
   elseif value=="desrest" and del then
    setFMSData("desrestspd","---")
    setFMSData("desrestalt","-----")
   elseif value=="desrest" then
    spd=string.sub(fmsO["scratchpad"],1,3)
    alt=string.sub(fmsO["scratchpad"],5)
    if validateSpeed(spd) ==false then 
      fmsO["notify"]="INVALID ENTRY"
    else
      setFMSData("desrestspd",spd)
      if validAlt(alt) ~=nil then 
	setFMSData("desrestalt",validAlt(alt))
      end
    end
  elseif value=="airportpos" then
	-- REF AIRPORT (FCOM p.1285): an ICAO identifier of an airport in the FMC's
	-- navigation database, its position on the line (6-1/6-2 step 4; before
	-- the ND's navaid list); STANDBY ONE while the database is read
	if del == true then
		setFMSData("airportpos",defaultFMSData().airportpos)
		setFMSData("airportgate",defaultFMSData().airportgate)
		setFMSData("irsLat",defaultFMSData().irsLat)
		setFMSData("irsLon",defaultFMSData().irsLon)
		return
	end
	if not B747_fmc_navdb.ready then fmsO["notify"]="STANDBY ONE" return end
	local sp=fmsO["scratchpad"]
	local apt=string.match(sp,"^%u%u%u%u$") and B747_navdb.airport(B747_fmc_navdb,sp) or nil
	if apt==nil then fmsO["notify"]=string.match(sp,"^%w%w%w%w$") and "NOT IN DATA BASE" or "INVALID ENTRY" return end
	setFMSData("irsLat",toDMS(apt.lat,true))
	setFMSData("irsLon",toDMS(apt.lon,false))
	setFMSData("airportpos",sp)
	setFMSData("airportgate","----")

  elseif value=="flttime" then 
  elseif value=="flttime" then 
    hhV=string.sub(fmsO["scratchpad"],1,2)
    mmV=string.sub(fmsO["scratchpad"],-2)
    setFMSData("flttimehh",hhV)
    setFMSData("flttimemm",mmV)
  elseif value=="rpttime" then 
    hhV=string.sub(fmsO["scratchpad"],1,2)
    mmV=string.sub(fmsO["scratchpad"],-2)
    setFMSData("rpttimehh",hhV)
    setFMSData("rpttimemm",mmV)
  elseif value=="fltdate" then 
    setFMSData("fltdate",os.date("%Y%m%d"))
  elseif value=="lnoffs" then	
	if del then
		B747DR_ap_lnav_xtk_target=0
	else
		local invalid=false
		if string.len(fmsO["scratchpad"])>3 or string.len(fmsO["scratchpad"])<2 
			or (string.sub(fmsO["scratchpad"],1,1)~="R" and string.sub(fmsO["scratchpad"],1,1)~="L") then
			invalid=true
		end
		local newOffset=0
		if not(invalid) then
			newOffset=tonumber(string.sub(fmsO["scratchpad"],2))
		end
		if newOffset==nil then
			invalid=true
		elseif not(invalid) then
			if string.sub(fmsO["scratchpad"],1,1)=="L" and newOffset>0 then newOffset=newOffset*-1 end
			B747DR_ap_lnav_xtk_target=newOffset
		end
		if invalid then fmsO["notify"]="INVALID ENTRY" end
		
	end
  elseif value=="drtto" then
	if del then
		B747DR_ap_lnavHeading_mode=0
	else
		local wpt=fmsO["scratchpad"]
		
		if string.len(wpt)==0 then
			wpt=string.sub(B747DR_srcfms[fmsO.id][14],2,-2)
			wpt=str_trim(wpt)
		end
		simCMD_FMS_key[fmsO["id"]]["del"]:once()
		simCMD_FMS_key[fmsO["id"]]["clear"]:once()
		fmsO["scratchpad"]=""
		if string.len(wpt)>0 and (string.len(fmsJson) > 2) then
			
			local fms2 = json.decode(fmsJson)
			local found=0
			if fms2 ~= nil then
				for i=1,table.getn(fms2),1 do
				if fms2[i][8]==wpt then
					print(wpt .." found at "..i)
					found=i
				else
					print(wpt .." not found at "..i)
				end
			end
			end
			if found>0 then
				--B747DR_fms_setCurrent=wpt
				B747DR_ap_lnavHeading_mode = found 
				B747DR_ap_lnav_xtk_target=-100 --direct to
			else
				print("INVALID ENTRY 1 "..wpt.." 1")
				fmsO["notify"]="INVALID ENTRY"	
			end

		else
			print("INVALID ENTRY 2 "..fmsO["scratchpad"].." 2")
			fmsO["notify"]="INVALID ENTRY"
		end	
	end
  elseif value=="crzalt" then
	-- CRZ ALT (6-1/6-2 step 3a; FCOM p.1311, p.1269-1270): XXX, XXXX, XXXXX
	-- or FLXXX, up to the maximum certified altitude 45,100 ft; on the
	-- ground above the airplane (FMSPG p.97); in the air PERF INIT takes it
	-- into the boxes only, the CLB and CRZ pages change it. The FMC keeps it
	-- (before: typed into X-Plane's FMS and read back)
	if del then fmsO["notify"]="INVALID DELETE" return end
	local ft = B747_cdu_model.parse_alt(fmsO["scratchpad"])
	local onPerfInit = fmsO.currentPage == "PERFINIT"
	if ft == nil or ft > 45100 or (simDR_onGround == 1 and ft <= simDR_pressureAlt1)
		or (onPerfInit and simDR_onGround ~= 1 and B747BR_cruiseAlt > 0) then
		fmsO["notify"]="INVALID ENTRY"
		return
	end
	B747BR_cruiseAlt=ft
	monitorCRZALT()
	B747_fms_econ_now()
	setFMSData("stepalt", "")
	-- above the maximum altitude the entry stands with MAX ALT FLXXX (6-1/6-2
	-- step 8b2; FMSPG p.131, FCOM p.1435)
	local maxft = B747_perf_db.max_alt(B747_fms_perf(), B747_fms_gw_kg(), B747_fms_isa_dev())
	if ft > maxft then
		fmsO["notify"] = string.format("MAX ALT FL%03d", math.floor(maxft / 100))
	elseif B747_fms_unable_crz(ft) then
		-- the predicted climb meets the descent below it (6-1/6-2 step 8c;
		-- FCOM p.1436)
		fmsO["notify"] = "UNABLE CRZ ALT"
	end
	B747_fms_preds_now()
  elseif value=="irspos" then
	if string.len(fmsO["scratchpad"])>10 then
		print("set irs pos")
		lat=string.sub(fmsO["scratchpad"],1,9)
		lon=string.sub(fmsO["scratchpad"],-9)
		--fmsModules["data"]["fltdep"]=dep
		--fmsModules["data"]["fltdst"]=dst
		print(getFMSData("irsLat").." "..lat)
		print(getFMSData("irsLon").." "..lon)
		-- to the IRUs, which check it (ENTER IRS POSITION: the navigation
		-- sensors module)
		if irsSystem.aligning() and irsSystem.enterPos(lat,lon) then
			setFMSData("irsLat",lat)
			setFMSData("irsLon",lon)
			irsSystem["irsLat"]=lat
			irsSystem["irsLon"]=lon
			fmsModules["data"]["initIRSLat"]=lat
			fmsModules["data"]["initIRSLon"]=lon
		else
			fmsO["notify"]="INVALID ENTRY"
		end
	else
		fmsO["notify"]="INVALID ENTRY"
	end
--     if fmsModules["fmsL"].notify=="ENTER IRS POSITION" then fmsModules["fmsL"].notify="" end
--     if fmsModules["fmsC"].notify=="ENTER IRS POSITION" then fmsModules["fmsC"].notify="" end
--     if fmsModules["fmsR"].notify=="ENTER IRS POSITION" then fmsModules["fmsR"].notify="" end
   elseif value=="passengers" then
     local numPassengers=tonumber(fmsO["scratchpad"])
     if numPassengers==nil then numPassengers=2 end
     if numPassengers<2 then numPassengers=2 end
     if numPassengers>416 then numPassengers=416 end
     B747DR_payload_weight=numPassengers*120
   elseif value=="services" then
     if simDR_acf_m_jettison==0 then
		if B747DR_elec_ext_pwr1_available==0 then
        	fmsModules["cmds"]["laminar/B747/electrical/connect_power"]:once() 
		end
		fmsModules["cmds"]["sim/ground_ops/service_plane"]:once() 
     end
     fmsModules["lastcmd"]=fmsModules["cmdstrings"]["sim/ground_ops/service_plane"]
     run_after_time(preselect_fuel,30)
   elseif value=="fuelpreselect" then
	if string.len(fmsO["scratchpad"])>0 then
     local fuel=tonumber(fmsO["scratchpad"])
     if fuel~=nil then
       B747DR_fuel_add=fuel
       
     end
	else
		fmsO["notify"]="INVALID ENTRY"
	end
   elseif value=="origin" then
	if string.len(fmsO["scratchpad"])>0 then
     fmsFunctions["custom2fmc"](fmsO,"L1")
     fmsModules:setData("crzalt","*****") -- clear cruise alt /crzalt when entering a new source airport (this is broken and currently disabled)
	else
		fmsO["notify"]="INVALID ENTRY"
	end
   elseif value=="airportgate" then
	if string.len(fmsO["scratchpad"])>0 then
		local lat=toDMS(simDR_latitude,true)
		local lon=toDMS(simDR_longitude,false)
		irsSystem["irsLat"]=lat
		irsSystem["irsLon"]=lon
		setFMSData("irsLat",lat)
		setFMSData("irsLon",lon)
		setFMSData(value,fmsO["scratchpad"])
	else
		fmsO["notify"]="INVALID ENTRY"
	end
  elseif value == "codata" then
	if string.len(fmsO["scratchpad"])>0 then
		setFMSData(value, fmsO["scratchpad"])
	else
		fmsO["notify"]="INVALID ENTRY"
	end
  elseif value == "sethdg" then
	if validate_sethdg(fmsO["scratchpad"]) == false then
		fmsO["notify"]="INVALID ENTRY"
	else
		-- only while an IRU is in ATT (the dashes: FCOM p.1286); the heading
		-- to the IRUs in ATT
		if B747DR_nav_irs_set_hdg_shown == 1 then
			if (fmsO["scratchpad"] == "0" or fmsO["scratchpad"] == "00" or fmsO["scratchpad"] == "000") then
				fmsO["scratchpad"] = "360"
			end
			irsSystem.enterHdg(tonumber(fmsO["scratchpad"]) % 360)
			setFMSData(value, fmsO["scratchpad"].."`")
			timer_start = simDRTime
		else
			fmsO["notify"]="INVALID ENTRY"
		end
	end
  elseif value == "fltdep" then
	print("set fltdep "..fmsO["scratchpad"])
	if string.len(fmsO["scratchpad"])>0 or del==true then
		fmsFlightPlan = "[]" --clear the flight plan
		if del==true then
			setFMSData("fltdep","****")
			setFMSData("fltdst","****")
			setFMSData("transalt","18000")
		else	
			dep=string.sub(fmsO["scratchpad"],1,4)
			setFMSData("fltdep",dep)
			setFMSData("fltdst","****")
			-- TRANS ALT: the origin's from the FMC's navigation database, 18,000 ft
			-- when it has none (FCOM p.1329; 6-1/6-2 step 4)
			local apt=B747_fmc_navdb.ready and B747_navdb.airport(B747_fmc_navdb,dep) or nil
			setFMSData("transalt",string.format("%d",apt and apt.ta and apt.ta>0 and apt.ta or 18000))
			simCMD_FMS_key[fmsO.id]["fpln"]:once()
			fmsFunctions["custom2fmc"](fmsO,"L1")
		end
		fmsModules:setData("crzalt","*****") -- clear cruise alt /crzalt when entering a new source airport
	else
		   fmsO["notify"]="INVALID ENTRY"
	end
  elseif value == "fltdst" then
	print("set fltdst")
	if string.len(fmsO["scratchpad"])>0 or del==true then
		if del==true then
			setFMSData("fltdep","****")
			setFMSData("fltdst","****")
			fmsFlightPlan = "[]" --clear the flight plan
		else	
			dep=string.sub(fmsO["scratchpad"],1,4)
			setFMSData("fltdst",dep)
			simCMD_FMS_key[fmsO.id]["fpln"]:once()
			fmsFunctions["custom2fmc"](fmsO,"R1")
		end
	else
		fmsO["notify"]="INVALID ENTRY"
 	end
  elseif value == "vref1" then
	fmsO["scratchpad"]=string.format("25/%3d", B747DR_airspeed_Vf25)
	return
  elseif value == "vref2" then
	fmsO["scratchpad"]=string.format("30/%3d", B747DR_airspeed_Vf30)
	return
  elseif value == "flapspeed" then
	-- XX/YYY, /YYY or YYY; the empty scratchpad copies the value; DELETE
	-- removes VREF (CDU-28, 6-1 step 1; FCOM p.1412). Without the flap: the
	-- one before, else 30 (estimate)
	local cur = getFMSData(value)
	if del then
		B747DR_airspeed_VrefFlap=0
		setFMSData(value,"")
		return
	end
	if fmsO["scratchpad"]=="" then
		if string.match(cur, "%d") then fmsO["scratchpad"]=str_trim(cur) end
		return
	end
	local flap, spd = string.match(fmsO["scratchpad"], "^(%d*)/(%d+)$")
	if not spd then flap, spd = "", string.match(fmsO["scratchpad"], "^(%d+)$") end
	local vref=tonumber(spd or "")
	if flap == "" then flap = string.match(cur, "^(%d%d)/") or "30" end
	if vref==nil or vref<110 or vref>180 or (flap ~= "25" and flap ~= "30") then
		fmsO["notify"]="INVALID ENTRY"
		return
	end
	B747DR_airspeed_Vref=vref
	B747DR_airspeed_VrefFlap=(flap == "25") and 1 or 2
	setFMSData(value,flap.."/"..string.format("%3d", vref))
  elseif value == "grwt" or value == "zfw" then
	-- GR WT or ZFW (6-1/6-2 step 3a; FCOM p.1309-1310): XXX or XXX.X; the
	-- other follows from FUEL; an entry after the takeoff speeds are
	-- selected deletes them (TAKEOFF SPEEDS DELETED)
	if del then fmsO["notify"]="INVALID DELETE" return end
	local v = B747_cdu_model.parse_weight(fmsO["scratchpad"])
	if v == nil then fmsO["notify"]="INVALID ENTRY" return end
	local t = perf_in(v)
	local fuel = perf_fuel_t()
	local zfw = value == "grwt" and t - fuel or t
	local gw = zfw + fuel
	if zfw < 130 or zfw > 270 or gw < 150 or gw > 400 then fmsO["notify"]="INVALID ENTRY" return end
	setFMSData("zfw", string.format("%5.1f", zfw))
	setFMSData("gwsrc", value == "grwt" and "GW" or "ZFW")
	update_perf()
	calc_CGMAC()  --Recalc CG %MAC and TRIM units
	takeoff_speeds_deleted()
  elseif value == "fuel" then
	-- FUEL: an entry makes it MANUAL; only that can be deleted (FCOM p.1310)
	if del then
		if tonumber(fmsModules["data"].fuelman) == nil then fmsO["notify"]="INVALID DELETE" return end
		setFMSData("fuelman", "")
	else
		local v = B747_cdu_model.parse_weight(fmsO["scratchpad"])
		if v == nil or perf_in(v) > 180 then fmsO["notify"]="INVALID ENTRY" return end
		setFMSData("fuelman", string.format("%5.1f", perf_in(v)))
	end
	update_perf()
  elseif value == "reserves" then
	-- RESERVES: XXX or XXX.X (FCOM p.1311)
	if del then fmsO["notify"]="INVALID DELETE" return end
	local v = B747_cdu_model.parse_weight(fmsO["scratchpad"])
	if v == nil or perf_in(v) > 180 then fmsO["notify"]="INVALID ENTRY" return end
	setFMSData(value, string.format("%5.1f", perf_in(v)))
  elseif value == "costindex" then
	-- COST INDEX: 0 to 9999 (FCOM p.1311); not within 10 NM of the T/D
	-- (FMSPG p.97)
	if del then fmsO["notify"]="INVALID DELETE" return end
	local ci = B747_cdu_model.parse_int(fmsO["scratchpad"], 0, 9999)
	local nearTD = simDR_onGround ~= 1 and B747BR_tod > 0 and B747BR_totalDistance > 0
		and (B747BR_totalDistance - B747BR_tod) < 10
	if ci == nil or nearTD then fmsO["notify"]="INVALID ENTRY" return end
	setFMSData(value, string.format("%d", ci))
	B747_fms_econ_now()
  elseif value == "crzcg" then
	-- 8.5 to 33.0 % (CDU-09, 6-1 step 1; FCOM p.1311)
	local cg = string.match(fmsO["scratchpad"], "^%d%d?%.?%d?$") and tonumber(fmsO["scratchpad"])
	if del then
		-- the default, 20.0 in small font (FCOM p.1311)
		setFMSData(value, "20.0")
		crzcg_lineLg = ""
		return
	elseif cg and cg >= 8.5 and cg <= 33.0 then
		setFMSData(value, string.format("%4.1f", cg))
	else
		fmsO["notify"]="INVALID ENTRY"
		return
	end
	if string.len(fmsModules["data"].crzcg) > 0 then
		crzcg_lineLg = string.format("%4.1f%%", tonumber(fmsModules["data"].crzcg))
	end
  elseif value == "stepsize" then
	-- STEP SIZE (PERF INIT 5R, CRZ 4L): DELETE gives ICAO back (FMSPG p.98,
	-- p.132; 6-1/6-2 step 8b2)
	if del then setFMSData(value, "ICAO") return end
	if fmsO["scratchpad"] == "ICAO" then
		setFMSData(value, fmsO["scratchpad"])
	elseif tonumber(fmsO["scratchpad"]) == nil then
		fmsO["notify"] = "INVALID ENTRY"
	elseif tonumber(fmsO["scratchpad"]) < 0 or tonumber(fmsO["scratchpad"]) > 9000 or math.fmod(tonumber(fmsO["scratchpad"]), 1000) > 0 then  --ensure increments of 1000
		fmsO["notify"] = "INVALID ENTRY"
	else
		setFMSData(value, fmsO["scratchpad"])
	end
  elseif value == "fltno" then
	-- FLT NO (RTE page 1, ATC LOGON/STATUS, ACARS; 6-1/6-2 step 3c): 1 to 8
	-- letters or digits, no deletion (FMSPG p.79, p.278); the FMC's flight
	-- number for PROGRESS, ATC and ACARS (FCOM p.1289; LH3460 p.85)
	if del then fmsO["notify"] = "INVALID DELETE" return end
	local sp = fmsO["scratchpad"]
	if not string.match(sp, "^%w+$") or string.len(sp) > 8 then fmsO["notify"] = "INVALID ENTRY" return end
	setFMSData("fltno", sp)
  elseif value == "toflaps" then
	-- FLAP/ACCEL HT (6-1/6-2 step 3b; FCOM p.1318-1319): XX (10 or 20),
	-- /YYYY (400 to 9999 ft above the airport) or both; a new flap setting
	-- after the takeoff speeds are selected deletes them. DELETE: the
	-- acceleration height's default (estimate)
	if del then setFMSData("accelset", "") setFMSData("accelht", "1000") return end
	local sp = fmsO["scratchpad"]
	local f, h = string.match(sp, "^(%d%d)/(%d+)$")
	if not f then f = string.match(sp, "^(%d%d)$") end
	if not f then h = string.match(sp, "^/(%d+)$") end
	local fv, hv = tonumber(f), tonumber(h)
	if (f and fv ~= 10 and fv ~= 20) or (h and (hv < 400 or hv > 9999)) or (not f and not h) then
		fmsO["notify"] = "INVALID ENTRY"
		return
	end
	if fv then
		if fv ~= B747DR_airspeed_flapsRef then takeoff_speeds_deleted() end
		B747DR_airspeed_flapsRef = fv
	end
	if hv then setFMSData("accelht", string.format("%d", hv)) setFMSData("accelset", "Y") end
  elseif value == "eoaccelht" then
	-- E/O ACCEL HT: 400 to 9999 ft (FCOM p.1319); DELETE: the default
	if del then setFMSData("eoaccelset", "") setFMSData("eoaccelht", "1000") return end
	local hv = B747_cdu_model.parse_int(fmsO["scratchpad"], 400, 9999)
	if hv == nil then fmsO["notify"] = "INVALID ENTRY" return end
	setFMSData("eoaccelht", string.format("%d", hv))
	setFMSData("eoaccelset", "Y")
  elseif value == "thrred" then
	-- THR REDUCTION: 5 (flaps 5) or 400 to 9999 ft (FCOM p.1319); DELETE:
	-- the default, FLAPS 5
	if del then setFMSData("thrredset", "") setFMSData("thrred", "5") return end
	local sp = fmsO["scratchpad"]
	local hv = sp == "5" and 5 or B747_cdu_model.parse_int(sp, 400, 9999)
	if hv == nil then fmsO["notify"] = "INVALID ENTRY" return end
	setFMSData("thrred", string.format("%d", hv))
	setFMSData("thrredset", "Y")
  elseif value == "towind" then
	-- WIND/SLOPE (FCOM p.1319): HXX, XX (headwind) or TXX; UX.X, X.X
	-- (upslope) or DX.X, 0.0 to 2.0 (FMSPG p.106); the wind goes into the
	-- V1 (the flight instruments' takeoff speeds); a change deletes the
	-- selected speeds. DELETE: dashes
	if del then setFMSData("towind", "---") setFMSData("toslope", "----") takeoff_speeds_deleted() return end
	local w, s = B747_cdu_model.pair(fmsO["scratchpad"], "L")
	if w == nil then fmsO["notify"] = "INVALID ENTRY" return end
	local wd, wv = string.match(w, "^([HT]?)(%d%d?)$")
	local sd, sv = string.match(s, "^([UD]?)(%d%.%d)$")
	if (w ~= "" and not wv) or (s ~= "" and (not sv or tonumber(sv) > 2.0)) then
		fmsO["notify"] = "INVALID ENTRY"
		return
	end
	if wv then setFMSData("towind", string.format("%s%02d", wd == "T" and "T" or "H", tonumber(wv))) end
	if sv then setFMSData("toslope", (sd == "D" and "D" or "U") .. sv) end
	takeoff_speeds_deleted()
  elseif value == "posshift" then
	-- POS SHIFT (FCOM p.1321, 109): +/- X or XX hundreds of meters past the
	-- threshold; DELETE: none
	if del then setFMSData("posshift", "---") return end
	local sg, n = string.match(fmsO["scratchpad"], "^([+-]?)(%d%d?)$")
	if not n then fmsO["notify"] = "INVALID ENTRY" return end
	setFMSData("posshift", string.format("%s%02d", sg == "-" and "-" or "+", tonumber(n)))
  elseif value == "topreflt" then
	-- PRE-FLT: the first page not complete, else THRUST LIM (FCOM p.1321)
	fmsFunctions["setpage"](fmsO, takeoff_preflight())
	return
  elseif value == "thrustsel" then
	-- SEL (FCOM p.1314): 0 to 99 C or 32 to 210 F (XX, XXC, XXF, XXXF),
	-- kept in degrees C; an F entry shows the OAT in F too. The assumed
	-- temperature thrust reduction is the thrust management's (6-4).
	-- After the takeoff speeds are selected an entry deletes them
	if del then
		setFMSData("thrustsel", "  ")
		setFMSData("selunit", "")
		return
	end
	local sp = fmsO["scratchpad"]
	local c = string.match(sp, "^(%d%d?)C?$")
	local fv = string.match(sp, "^(%d%d%d?)F$")
	if c then
		setFMSData("thrustsel", string.format("%2d", tonumber(c)))
		setFMSData("selunit", "")
	elseif fv and tonumber(fv) >= 32 and tonumber(fv) <= 210 then
		setFMSData("thrustsel", string.format("%2d", math.floor((tonumber(fv) - 32) * 5 / 9 + 0.5)))
		setFMSData("thrustself", string.format("%3d", tonumber(fv)))
		setFMSData("selunit", "F")
	else
		fmsO["notify"] = "INVALID ENTRY"
		return
	end
	takeoff_speeds_deleted()
  elseif value == "cg_mac" then
	-- CG (FCOM p.1320, 109): whole numbers 0 to 40 % MAC; the trim from
	-- it. DELETE: dashes (before: no entry until the PAX/CARGO page set one)
	if del then
		setFMSData(value, "--")
		setFMSData("stab_trim", "    ")
		cg_lineLg = ""
		return
	end
	local cg = B747_cdu_model.parse_int(fmsO["scratchpad"], 0, 40)
	if cg == nil then fmsO["notify"] = "INVALID ENTRY" return end
	calc_stab_trim(fmsModules["data"].grwt, string.format("%d", cg))
	setFMSData(value, string.format("%d", cg))
	cg_lineLg = string.format("%2.0f%%", cg)
--Marauder28
--PAX / CARGO page
  elseif value == "paxFirstClassA" then
	if string.match(fmsO["scratchpad"], "%d") and math.abs(tonumber(fmsO["scratchpad"])) <= 23 then
		setFMSData(value, math.abs(string.format("%2d", fmsO["scratchpad"])))
		calc_pax_cargo()
	elseif fmsO["scratchpad"] == "F" then  --Add FULL PAX
		setFMSData("paxFirstClassA", "23")
		setFMSData("paxBusClassB", "80")
		setFMSData("paxEconClassC", "77")
		setFMSData("paxEconClassD", "104")
		setFMSData("paxEconClassE", "132")
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")
		calc_pax_cargo()
	elseif fmsO["scratchpad"] == "C" then  --Clear PAX / CARGO entries
		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")
		setFMSData("cargoFwd", "")
		setFMSData("cargoAft", "")
		setFMSData("cargoBulk", "")
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "23")
		calc_pax_cargo()
	elseif string.match(fmsO["scratchpad"], "%d") and tonumber(fmsO["scratchpad"]) > 23 then  --Add set number of PAX by round-robin through all zones
		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")

		local x = tonumber(fmsO["scratchpad"])
		local paxA = 0
		local paxB = 0
		local paxC = 0
		local paxD = 0
		local paxE = 0
		
		if x > 416 then
			x = 416
		end
		repeat
			if x > 0 and paxA < 23 then
				paxA = paxA + 1
				x = x - 1
			end
			if x > 0 and paxB < 80 then
				paxB = paxB + 1
				x = x - 1
			end
			if x > 0 and paxC < 77 then
				paxC = paxC + 1
				x = x - 1
			end
			if x > 0 and paxD < 104 then
				paxD = paxD + 1
				x = x - 1
			end
			if x > 0 and paxE < 132 then
				paxE = paxE + 1
				x = x - 1
			end
		until (x == 0)
		
		fmsModules["data"].paxFirstClassA = string.format("%2d", paxA)
		fmsModules["data"].paxBusClassB = string.format("%2d", paxB)
		fmsModules["data"].paxEconClassC = string.format("%2d", paxC)
		fmsModules["data"].paxEconClassD = string.format("%3d", paxD)
		fmsModules["data"].paxEconClassE = string.format("%3d", paxE)
		
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "paxBusClassB" then
	if string.match(fmsO["scratchpad"], "%d") then
		local pax = math.abs(tonumber(fmsO["scratchpad"]))
		if pax > 80 then
			pax = 80
		end
		setFMSData(value, string.format("%2d", pax))
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "80")
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "paxEconClassC" then
	if string.match(fmsO["scratchpad"], "%d") then
		local pax = math.abs(tonumber(fmsO["scratchpad"]))
		if pax > 77 then
			pax = 77
		end
		setFMSData(value, string.format("%2d", pax))
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "77")
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "paxEconClassD" then
	if string.match(fmsO["scratchpad"], "%d") then
		local pax = math.abs(tonumber(fmsO["scratchpad"]))
		if pax > 104 then
			pax = 104
		end
		setFMSData(value, string.format("%3d", pax))
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "104")
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "paxEconClassE" then
	if string.match(fmsO["scratchpad"], "%d") then
		local pax = math.abs(tonumber(fmsO["scratchpad"]))
		if pax > 132 then
			pax = 132
		end
		setFMSData(value, string.format("%3d", pax))
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "132")
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "paxPayload" then
	if string.match(fmsO["scratchpad"], "%d") then
		local weight_factor = 1

		if simConfigData["data"].SIM.weight_display_units == "LBS" then
			weight_factor = simConfigData["data"].SIM.kgs_to_lbs
		else
			weight_factor = 1
		end

		local pax_weight = math.abs(tonumber(fmsO["scratchpad"])) * 1000
		local pax = 0
		local paxA = 0
		local paxB = 0
		local paxC = 0
		local paxD = 0
		local paxE = 0
	
		pax = math.ceil(pax_weight / (simConfigData["data"].SIM.std_pax_weight * weight_factor))
		if pax > 416 then
			pax = 416
		end

		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")

		repeat
			if pax > 0 and paxA < 23 then
				paxA = paxA + 1
				pax = pax - 1
			end
			if pax > 0 and paxB < 80 then
				paxB = paxB + 1
				pax = pax - 1
			end
			if pax > 0 and paxC < 77 then
				paxC = paxC + 1
				pax = pax - 1
			end
			if pax > 0 and paxD < 104 then
				paxD = paxD + 1
				pax = pax - 1
			end
			if pax > 0 and paxE < 132 then
				paxE = paxE + 1
				pax = pax - 1
			end
		until (pax == 0)
		
		fmsModules["data"].paxFirstClassA = string.format("%2d", paxA)
		fmsModules["data"].paxBusClassB = string.format("%2d", paxB)
		fmsModules["data"].paxEconClassC = string.format("%2d", paxC)
		fmsModules["data"].paxEconClassD = string.format("%3d", paxD)
		fmsModules["data"].paxEconClassE = string.format("%3d", paxE)

		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData("paxFirstClassA", "0")
		setFMSData("paxBusClassB", "0")
		setFMSData("paxEconClassC", "0")
		setFMSData("paxEconClassD", "0")
		setFMSData("paxEconClassE", "0")
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "cargoFwd" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and (string.match(fmsO["scratchpad"], "P") or string.match(fmsO["scratchpad"], "C")) then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 5035 * weight_factor
			if digits > 5 then
				digits = 5
			end
		elseif chars == "C" then
			weight_per_unit = 1588 * weight_factor
			if digits > 16 then
				digits = 16
			end
		end
		
		fmsO["scratchpad"] = string.format("%6d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local cwt = 0

		cwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if cwt > 26490 then
			cwt = 26490
		end
		
		setFMSData(value, string.format("%6d", cwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "cargoAft" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and (string.match(fmsO["scratchpad"], "P") or string.match(fmsO["scratchpad"], "C")) then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0
		
		if chars == "P" then
			weight_per_unit = 5035 * weight_factor
			if digits > 4 then
				digits = 4
			end
		elseif chars == "C" then
			weight_per_unit = 1588 * weight_factor
			if digits > 14 then
				digits = 14
			end
		end
		
		fmsO["scratchpad"] = string.format("%6d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local cwt = 0

		cwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS

		if cwt > 22938 then
			cwt = 22938
		end

		setFMSData(value, string.format("%6d", cwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "cargoBulk" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local cwt = 0

		cwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS

		if cwt > 6749 then
			cwt = 6749
		end

		setFMSData(value, string.format("%5d", cwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
--FREIGHT Page
  elseif value == "freightZoneA" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") and math.abs(tonumber(fmsO["scratchpad"])) <= (11160 * weight_factor) then
		setFMSData(value, math.abs(string.format("%5d", fmsO["scratchpad"])) / weight_factor)
		calc_pax_cargo()
	elseif fmsO["scratchpad"] == "F" then  --Add FULL FREIGHT
		setFMSData("freightZoneA", "11289")
		setFMSData("freightZoneB", "30104")
		setFMSData("freightZoneC", "22578")
		setFMSData("freightZoneD", "45156")
		setFMSData("freightZoneE", "3763")
		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")
		calc_pax_cargo()
	elseif fmsO["scratchpad"] == "C" then  --Clear FREIGHT entries
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")
		setFMSData("cargoFwd", "")
		setFMSData("cargoAft", "")
		setFMSData("cargoBulk", "")
		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")
		calc_pax_cargo()
	elseif string.len(fmsO["scratchpad"]) < 1 then
		setFMSData(value, "11160")
		calc_pax_cargo()
	elseif string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") and tonumber(fmsO["scratchpad"]) > (11289 * weight_factor) then  --Add FREIGHT by round-robin through all zones
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")

		local x = tonumber(string.format("%6d", fmsO["scratchpad"] / weight_factor)) --convert to base units of KGS
		local zoneA = 0
		local zoneB = 0
		local zoneC = 0
		local zoneD = 0
		local zoneE = 0
		
		if x > 112890 then  --112,900 KGS is the MAX Revenue Payload.  112,890 KGS is the defined average pallet weight (3763) * 30 pallets
			x = 112890
		end
		repeat
			if x > 0 and zoneA < 11289 then
				zoneA = zoneA + 1
				x = x - 1
			end
			if x > 0 and zoneB < 30104 then
				zoneB = zoneB + 1
				x = x - 1
			end
			if x > 0 and zoneC < 22578 then
				zoneC = zoneC + 1
				x = x - 1
			end
			if x > 0 and zoneD < 45156 then
				zoneD = zoneD + 1
				x = x - 1
			end
			if x > 0 and zoneE < 3763 then
				zoneE = zoneE + 1
				x = x - 1
			end
			--print("X = "..x.." ZoneA = "..zoneA.." ZoneB = "..zoneB.." ZoneC = "..zoneC.." ZoneD = "..zoneD.." ZoneE = "..zoneE)
		until (x == 0)
		
		fmsModules["data"].freightZoneA = string.format("%5d", zoneA)
		fmsModules["data"].freightZoneB = string.format("%5d", zoneB)
		fmsModules["data"].freightZoneC = string.format("%5d", zoneC)
		fmsModules["data"].freightZoneD = string.format("%5d", zoneD)
		fmsModules["data"].freightZoneE = string.format("%4d", zoneE)
		
		fmsO["scratchpad"] = ""
		
		calc_pax_cargo()
	elseif string.match(fmsO["scratchpad"], "%d") and string.match(fmsO["scratchpad"], "P") then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 3763 * weight_factor
			if digits > 3 then
				digits = 3
			end
		end
		
		fmsO["scratchpad"] = string.format("%5d", digits * weight_per_unit)
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local fwt = 0

		fwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if fwt > 11289 then
			fwt = 11289
		end
		
		setFMSData(value, string.format("%5d", fwt))
		calc_pax_cargo()
	end
  elseif value == "freightZoneB" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and string.match(fmsO["scratchpad"], "P") then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 3763 * weight_factor
			if digits > 8 then
				digits = 8
			end
		end
		
		fmsO["scratchpad"] = string.format("%5d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local fwt = 0

		fwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if fwt > 30104 then
			fwt = 30104
		end
		
		setFMSData(value, string.format("%5d", fwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "freightZoneC" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and string.match(fmsO["scratchpad"], "P") then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 3763 * weight_factor
			if digits > 6 then
				digits = 6
			end
		end
		
		fmsO["scratchpad"] = string.format("%5d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local fwt = 0

		fwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if fwt > 22578 then
			fwt = 22578
		end
		
		setFMSData(value, string.format("%5d", fwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "freightZoneD" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and string.match(fmsO["scratchpad"], "P") then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 3763 * weight_factor
			if digits > 12 then
				digits = 12
			end
		end
		
		fmsO["scratchpad"] = string.format("%6d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local fwt = 0

		fwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if fwt > 45156 then
			fwt = 45156
		end
		
		setFMSData(value, string.format("%6d", fwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
  elseif value == "freightZoneE" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and string.match(fmsO["scratchpad"], "P") then
		local digits = math.abs(tonumber(string.match(fmsO["scratchpad"], "%d+")))
		local chars = string.match(fmsO["scratchpad"], "%u")
		local weight_per_unit = 0

		if chars == "P" then
			weight_per_unit = 3763 * weight_factor
			if digits > 1 then
				digits = 1
			end
		end
		
		fmsO["scratchpad"] = string.format("%4d", digits * weight_per_unit)
	end
	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") then
		local fwt = 0

		fwt = math.abs(tonumber(fmsO["scratchpad"])) / weight_factor  --store LBS in KGS
		
		if fwt > 3763 then
			fwt = 3763
		end
		
		setFMSData(value, string.format("%4d", fwt))
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
   elseif value == "freightPayload" then
	if string.match(fmsO["scratchpad"], "%d") then --and not string.match(fmsO["scratchpad"], "%u") then
		local weight_factor = 1

		if simConfigData["data"].SIM.weight_display_units == "LBS" then
			weight_factor = simConfigData["data"].SIM.kgs_to_lbs
		else
			weight_factor = 1
		end

		setFMSData("paxFirstClassA", "")
		setFMSData("paxBusClassB", "")
		setFMSData("paxEconClassC", "")
		setFMSData("paxEconClassD", "")
		setFMSData("paxEconClassE", "")
		setFMSData("freightZoneA", "")
		setFMSData("freightZoneB", "")
		setFMSData("freightZoneC", "")
		setFMSData("freightZoneD", "")
		setFMSData("freightZoneE", "")

		local x = math.abs(tonumber(fmsO["scratchpad"]) / weight_factor) * 1000  --convert to base units of KGS
		local zoneA = 0
		local zoneB = 0
		local zoneC = 0
		local zoneD = 0
		local zoneE = 0
		
		if x > 112890 then  --112,900 KGS is the MAX Revenue Payload.  112,890 KGS is the defined average pallet weight (3763) * 30 pallets
			x = 112890
		end
		
		repeat
			if x > 0 and zoneA < 11289 then
				zoneA = zoneA + 1
				x = x - 1
			end
			if x > 0 and zoneB < 30104 then
				zoneB = zoneB + 1
				x = x - 1
			end
			if x > 0 and zoneC < 22578 then
				zoneC = zoneC + 1
				x = x - 1
			end
			if x > 0 and zoneD < 45156 then
				zoneD = zoneD + 1
				x = x - 1
			end
			if x > 0 and zoneE < 3763 then
				zoneE = zoneE + 1
				x = x - 1
			end
			--print("X = "..x.." ZoneA = "..zoneA.." ZoneB = "..zoneB.." ZoneC = "..zoneC.." ZoneD = "..zoneD.." ZoneE = "..zoneE)
		until (x <= 0)
		
		fmsModules["data"].freightZoneA = string.format("%5d", zoneA)
		fmsModules["data"].freightZoneB = string.format("%5d", zoneB)
		fmsModules["data"].freightZoneC = string.format("%5d", zoneC)
		fmsModules["data"].freightZoneD = string.format("%5d", zoneD)
		fmsModules["data"].freightZoneE = string.format("%4d", zoneE)
		
		fmsO["scratchpad"] = ""
		
		calc_pax_cargo()
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
--Marauder28
--SimConfig Page
   elseif value=="weightUnits" then
	if string.len(fmsO["scratchpad"])>0 and validate_weight_units(fmsO["scratchpad"]) == false then 
      fmsO["notify"]="INVALID ENTRY"
	elseif is_timer_scheduled(preselect_fuel) == true then
	  fmsO["notify"]="NA - WAITING FOR FUEL TRUCK"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.weight_display_units = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.weight_display_units == "KGS" then
			fmsO["scratchpad"] = "LBS"
		else
			fmsO["scratchpad"] = "KGS"
		end
		simConfigData["data"].SIM.weight_display_units = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
  elseif value == "irsAlignTime" then
	if not string.match(fmsO["scratchpad"], "%d") or string.len(fmsO["scratchpad"]) > 2 then
		fmsO["notify"] = "INVALID ENTRY"
	else
		--setFMSData(value, tonumber(fmsO["scratchpad"]) * 60)
		simConfigData["data"].SIM.irs_align_time = tonumber(fmsO["scratchpad"]) * 60
		pushSimConfig(simConfigData["data"]["values"])
		--print("FMC IRS = "..fmsO["scratchpad"] * 60)
	end
   elseif value=="autoFuelMgmt" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "YES" or fmsO["scratchpad"] == "NO") then 
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.auto_fuel_mgmt = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.auto_fuel_mgmt == "NO" then
			fmsO["scratchpad"] = "YES"
		else
			fmsO["scratchpad"] = "NO"
		end
		simConfigData["data"].SIM.auto_fuel_mgmt = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="baroIndicator" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "IN" or fmsO["scratchpad"] == "HPA") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.baro_indicator = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.baro_indicator == "IN" then
			fmsO["scratchpad"] = "HPA"
		else
			fmsO["scratchpad"] = "IN"
		end
		simConfigData["data"].SIM.baro_indicator = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="baroSync" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "YES" or fmsO["scratchpad"] == "NO") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.baro_sync = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.baro_sync == "NO" then
			fmsO["scratchpad"] = "YES"
		else
			fmsO["scratchpad"] = "NO"
		end
		simConfigData["data"].SIM.baro_sync = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
  elseif value == "stdPaxWeight" then
	local weight_factor = 1

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		weight_factor = simConfigData["data"].SIM.kgs_to_lbs
	else
		weight_factor = 1
	end

	if string.match(fmsO["scratchpad"], "%d") and not string.match(fmsO["scratchpad"], "%u") and tonumber(fmsO["scratchpad"]) < 500.0 then
		local pax_weight = 0

		pax_weight = string.format("%5.1f", math.abs(tonumber(fmsO["scratchpad"]) / weight_factor))  --store weight in KGS

		simConfigData["data"].SIM.std_pax_weight = pax_weight
		pushSimConfig(simConfigData["data"]["values"])		
	else
		fmsO["notify"] = "INVALID ENTRY"
	end
   elseif value=="captInbd" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "EICAS" or fmsO["scratchpad"] == "NORM" or fmsO["scratchpad"] == "PFD") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.capt_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.capt_inbd == "EICAS" then
			fmsO["scratchpad"] = "NORM"
		elseif simConfigData["data"].SIM.capt_inbd == "NORM" then
			fmsO["scratchpad"] = "PFD"
		else
			fmsO["scratchpad"] = "EICAS"
		end
		simConfigData["data"].SIM.capt_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="captLwr" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "EICAS PRI" or fmsO["scratchpad"] == "NORM" or fmsO["scratchpad"] == "ND") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.capt_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.capt_lwr == "EICAS PRI" then
			fmsO["scratchpad"] = "NORM"
		elseif simConfigData["data"].SIM.capt_lwr == "NORM" then
			fmsO["scratchpad"] = "ND"
		else
			fmsO["scratchpad"] = "EICAS PRI"
		end
		simConfigData["data"].SIM.capt_lwr = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="foInbd" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "PFD" or fmsO["scratchpad"] == "NORM" or fmsO["scratchpad"] == "EICAS") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.fo_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.fo_inbd == "PFD" then
			fmsO["scratchpad"] = "NORM"
		elseif simConfigData["data"].SIM.fo_inbd == "NORM" then
			fmsO["scratchpad"] = "EICAS"
		else
			fmsO["scratchpad"] = "PFD"
		end
		simConfigData["data"].SIM.fo_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="foLwr" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "ND" or fmsO["scratchpad"] == "NORM" or fmsO["scratchpad"] == "EICAS PRI") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].SIM.fo_inbd = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].SIM.fo_lwr == "ND" then
			fmsO["scratchpad"] = "NORM"
		elseif simConfigData["data"].SIM.fo_lwr == "NORM" then
			fmsO["scratchpad"] = "EICAS PRI"
		else
			fmsO["scratchpad"] = "ND"
		end
		simConfigData["data"].SIM.fo_lwr = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
	
--silvereagle added to end
    elseif value=="spillLights" then
		if B747DR_fmc_spill_lights == 0 then
			fmsO["scratchpad"] = "HI"
			B747DR_fmc_spill_lights = 1
		else	
			fmsO["scratchpad"] = "NORM"
			B747DR_fmc_spill_lights = 0
		end
		simConfigData["data"].SIM.spill_lights = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])

    elseif value=="cockpitSeatsHide" then
		if B747DR_fmc_cockpit_seats_hide == 0 then
			fmsO["scratchpad"] = "HIDE"
			B747DR_fmc_cockpit_seats_hide = 1
		else	
			fmsO["scratchpad"] = "SHOW"
			B747DR_fmc_cockpit_seats_hide = 0
		end
		simConfigData["data"].SIM.cockpit_seats_hide = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
--silvereagle end
	elseif value=="setacarsprovider" then
		if B747DR_acarsProvider == 0 then
			fmsO["scratchpad"] = "HOPPIE"
			B747DR_acarsProvider = 1
			--fmsLoadDref ="I\n1100 Version\nCYCLE 2306\nADEP EDDS\nDEPRWY RW25\nSID ETAS4B\nADES EDDF\nDESRWY RW25L\nSTAR SPES4B\nAPP I25L\nAPPTRANS CHA\nNUMENR 6\n1 EDDS ADEP 1272.000000 48.689877 9.221964\n11 XINLA T163 0.000000 49.283646 9.141608\n11 SUKON T163 0.000000 49.659721 9.195556\n11 SUPIX T163 0.000000 49.727779 9.305278\n11 SPESA T163 0.000000 49.862240 9.348325\n1 EDDF ADES 354.000000 50.033306 8.570456\n"
		else	
			fmsO["scratchpad"] = "AUTOATC"
			B747DR_acarsProvider = 0
		end
		simConfigData["data"].SIM.acarsProvider = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])	
	elseif value=="simConfigSave" then
			local file_location = simDR_livery_path.."B747-400_simconfig.dat"
			--print("File = "..file_location)
			local file = io.open(file_location, "w")

			if file ~= nil then
				io.output(file)
				io.write(B747DR_simconfig_data)
				io.close(file)
			end
--Plane Config Page
	elseif value=="model" then
		simConfigData["data"].PLANE.model = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
   elseif value=="aircraftType" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "PASSENGER" or fmsO["scratchpad"] == "FREIGHTER") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].PLANE.aircraft_type = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].PLANE.aircraft_type == "PASSENGER" then
			fmsO["scratchpad"] = "FREIGHTER"
		else
			fmsO["scratchpad"] = "PASSENGER"
		end
		simConfigData["data"].PLANE.aircraft_type = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="engines" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "CF6-80C2-B1F" or fmsO["scratchpad"] == "CF6-80C2-B5F" or fmsO["scratchpad"] == "CF6-80C2-B1F1"
		or fmsO["scratchpad"] == "PW4056" or fmsO["scratchpad"] == "PW4060" or fmsO["scratchpad"] == "PW4062"
		or fmsO["scratchpad"] == "RB211-524G" or fmsO["scratchpad"] == "RB211-524H") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].PLANE.engines = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].PLANE.engines == "CF6-80C2-B1F" then
			fmsO["scratchpad"] = "CF6-80C2-B5F"
			simConfigData["data"].PLANE.thrust_ref = "N1"
		elseif simConfigData["data"].PLANE.engines == "CF6-80C2-B5F" then
			fmsO["scratchpad"] = "CF6-80C2-B1F1"
			simConfigData["data"].PLANE.thrust_ref = "N1"
		elseif simConfigData["data"].PLANE.engines == "CF6-80C2-B1F1" then
			fmsO["scratchpad"] = "PW4056"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		elseif simConfigData["data"].PLANE.engines == "PW4056" then
			fmsO["scratchpad"] = "PW4060"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		elseif simConfigData["data"].PLANE.engines == "PW4060" then
			fmsO["scratchpad"] = "PW4062"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		elseif simConfigData["data"].PLANE.engines == "PW4062" then
			fmsO["scratchpad"] = "RB211-524G"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		elseif simConfigData["data"].PLANE.engines == "RB211-524G" then
			fmsO["scratchpad"] = "RB211-524H"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		elseif simConfigData["data"].PLANE.engines == "RB211-524H" then
			fmsO["scratchpad"] = "RB211-524H8T"
			simConfigData["data"].PLANE.thrust_ref = "EPR"
		else
			fmsO["scratchpad"] = "CF6-80C2-B1F"
			simConfigData["data"].PLANE.thrust_ref = "N1"
		end
		simConfigData["data"].PLANE.engines = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   --Removed to allow engine code above to forcibly set the thrust_ref mode (i.e. don't let users select and mess things up)
--[[   elseif value=="thrustRef" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "EPR" or fmsO["scratchpad"] == "N1") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].PLANE.thrust_ref = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].PLANE.thrust_ref == "EPR" then
			fmsO["scratchpad"] = "N1"
		else
			fmsO["scratchpad"] = "EPR"
		end
		simConfigData["data"].PLANE.thrust_ref = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end]]
   elseif value=="airline" then
		simConfigData["data"].PLANE.airline = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
   elseif value=="civilRegistration" then
		simConfigData["data"].PLANE.civil_registration = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
   elseif value=="finNbr" then
		simConfigData["data"].PLANE.fin_nbr = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
   elseif value=="pfdStyle" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "CRT" or fmsO["scratchpad"] == "LCD") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].PLANE.pfd_style = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].PLANE.pfd_style == "CRT" then
			fmsO["scratchpad"] = "LCD"
		else
			fmsO["scratchpad"] = "CRT"
		end
		simConfigData["data"].PLANE.pfd_style = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
   elseif value=="ndStyle" then
	if string.len(fmsO["scratchpad"])>0 and not (fmsO["scratchpad"] == "LCD" or fmsO["scratchpad"] == "CRT") then
      fmsO["notify"]="INVALID ENTRY"
	elseif string.len(fmsO["scratchpad"]) > 0 then
		simConfigData["data"].PLANE.nd_style = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
    else
		if simConfigData["data"].PLANE.nd_style == "CRT" then
			fmsO["scratchpad"] = "LCD"
		else
			fmsO["scratchpad"] = "CRT"
		end
		simConfigData["data"].PLANE.nd_style = fmsO.scratchpad
		pushSimConfig(simConfigData["data"]["values"])
	end
--Marauder28
   elseif value=="atc" then
		--setFMSData(value,fmsO["scratchpad"])
		
		fmsFunctions["acarsLogonATC"](fmsO,fmsO["scratchpad"])
	elseif value=="fltdepatc" then
		--setFMSData("atc",fmsModules.data["fltdep"])
		
		fmsFunctions["acarsLogonATC"](fmsO,fmsModules.data["fltdep"])
	elseif value=="fltdstatc" then
		--setFMSData("atc",fmsModules.data["fltdst"])
		
		fmsFunctions["acarsLogonATC"](fmsO,fmsModules.data["fltdst"])	
	elseif value=="acarsEMERSOB" and string.len(fmsO["scratchpad"]) > 0 then
		tVal=tonumber(fmsO["scratchpad"])
		if tVal==nil or tVal<1 or tVal>450 then
			fmsO["notify"]="INVALID ENTRY"
		else
			setFMSData("acarsEMERSOB",fmsO["scratchpad"])
		end
	elseif value=="metarreq" then
		if acarsSystem.provider.loggedOn()~="ACCEPTED" then fmsO["notify"]="RE-LOGON TO ATC COMM" return end
		fmsFunctions["acarsATCRequest"](fmsO,"REQUEST METAR") --request metar	
		fmsFunctions["setpage_no"](fmsO,"VIEWUPACARS_1") --then go to the message page
	elseif value=="sendarmedacarsnr" then
		if not(fmsFunctions.acarsDataReady(fmsO)) then return end	
		if fmsModules["data"]["atc"]=="****" then fmsO["notify"]="NO LOGON" return end	
		local ln=getFMSData("acarsMessage")
		fmsFunctions["acarsSendATCMessage"](fmsO,ln,"N") --send message
		setFMSData("acarsMessage","")
		fmsFunctions["setpage_no"](fmsO,"VIEWDOWNACARS_1") --then go to the sent message page	
	elseif value=="sendarmedacarsrr" then
		if not(fmsFunctions.acarsDataReady(fmsO)) then return end	
		if fmsModules["data"]["atc"]=="****" then fmsO["notify"]="NO LOGON" return end
		local ln=getFMSData("acarsMessage")
		fmsFunctions["acarsSendATCMessage"](fmsO,ln,"Y") --send message
		setFMSData("acarsMessage","")
		fmsFunctions["setpage_no"](fmsO,"VIEWDOWNACARS_1") --then go to the sent message page
	elseif value=="tafreq" then	
		if acarsSystem.provider.loggedOn()~="ACCEPTED" then fmsO["notify"]="RE-LOGON TO ATC COMM" return end
		fmsFunctions["acarsATCRequest"](fmsO,"REQUEST TAF")	--request metar
		fmsFunctions["setpage_no"](fmsO,"VIEWUPACARS_1") --then go to the message page
   elseif fmsO["scratchpad"]=="" and del==false then
      cVal=getFMSData(value)
    
      fmsO["scratchpad"]=cVal
    return 
  else
    setFMSData(value,fmsO["scratchpad"])
  end
  fmsO["scratchpad"]=""
end

function fmsFunctions.setDref(fmsO,value)
   local val=tonumber(fmsO["scratchpad"])
  if value=="VNAVS1" and B747DR_ap_vnav_system ~=1.0 then B747DR_ap_vnav_system=1 return elseif value=="VNAVS1" then B747DR_ap_vnav_system=0 return end 
  if value=="VNAVS2" and B747DR_ap_vnav_system ~=2.0 then B747DR_ap_vnav_system=2 return elseif value=="VNAVS2" then B747DR_ap_vnav_system=0 return end 
  if value=="VNAVSPAUSE" then 
	if B747DR_ap_vnav_pause>0 then 
		B747DR_ap_vnav_pause=0
	else
		B747DR_ap_vnav_pause=1 
	end 
	return 
	end 
  if value=="CHOCKS" then
	B747DR__gear_chocked = 1 - B747DR__gear_chocked
	--Stop refueling operation if CHOCKS are removed
	if B747DR__gear_chocked == 0 then
		B747DR_refuel=0.0
	end
	return
  end
  if value=="PAUSEVAL" then
	local numVal=tonumber(fmsO["scratchpad"])
	fmsO["scratchpad"]="" 
	if numVal==nil then fmsO["notify"]="INVALID ENTRY" return end
	if numVal>999 then numVal=999 end
	if numVal<=1 then numVal=1 end
	B747DR_ap_vnav_pause=numVal
	return 
  end


 	
  -- in the air <GA, <CON and <CRZ, not the takeoff's (CDU-10, 6-1 step 1;
  -- FCOM p.1337-1340): the thrust management's (6-4)
  if (value=="TO" or value=="TO1" or value=="TO2") and simDR_onGround~=1 then fmsO["notify"]="KEY/FUNCTION INOP" return end
  local rating = ({TO = 0, TO1 = 1, TO2 = 2})[value]
  if rating and rating ~= toderate then takeoff_speeds_deleted() end
  -- (6-1/6-2 step 9g1) the thrust limit's selections: the FMC's mode
  -- (B747_fms_thrlim_*: the climb armed with a takeoff derate by its
  -- reduction; before, TO n wrote the derates, CLB n armed)
  if rating then B747_fms_thrlim_to(rating) return end
  local clb = ({CLB = 0, CLB1 = 1, CLB2 = 2})[value]
  if clb then B747_fms_thrlim_clb(clb) return end
  -- (step 9g2) in the air <GA, <CON, <CRZ (FCOM p.1339-1340; nothing while
  -- GA is held: p.672)
  if value=="GA" or value=="CON" or value=="CRZ" then
    if simDR_onGround==1 then fmsO["notify"]="KEY/FUNCTION INOP" return end
    B747_fms_thrlim_sel(value)
    return
  end
  if value=="V1" or value=="VR" or value=="V2" then takeoff_speed_entry(fmsO, value) return end
  if value=="ILS" then 
    if findILS(fmsO["scratchpad"])==false then fmsO["notify"]="INVALID ENTRY" end
    fmsO["scratchpad"]="" 
    return 
  end
  local modes=B747DR_radioModes
  if value=="VORL" and val==nil then B747DR_radioModes=replace_char(2,modes,"A") fmsO["scratchpad"]="" return end
  if value=="VORR" and val==nil then B747DR_radioModes=replace_char(3,modes,"A") fmsO["scratchpad"]="" return end
   if val==nil or (value=="CRSL" and modes:sub(2, 2)=="A") or (value=="CRSR" and modes:sub(3, 3)=="A") then
     fmsO["notify"]="INVALID ENTRY"
     return 
   end
 --print(val)
  if value=="VORL" then B747DR_radioModes=replace_char(2,modes,"M") simDR_radio_nav_freq_hz[2]=val*100  end
  if value=="VORR" then B747DR_radioModes=replace_char(3,modes,"M") simDR_radio_nav_freq_hz[3]=val*100  end
  if value=="CRSL" then simDR_radio_nav_obs_deg[2]=val end
  if value=="CRSR" then simDR_radio_nav_obs_deg[3]=val end
  if value=="ADFL" then simDR_radio_adf1_freq_hz=val end
  if value=="ADFR" then simDR_radio_adf2_freq_hz=val end
  if value=="V1" then
	if val<100 or val>200 then
		fmsO["notify"]="INVALID ENTRY"
     	return 
	end
	B747DR_airspeed_V1=val 
  end
  if value=="VR" then
	if val<100 or val>200 then
		fmsO["notify"]="INVALID ENTRY"
     	return 
	end
	
	B747DR_airspeed_Vr=val 
  end
  if value=="V2" then
	if val<100 or val>200 then
		fmsO["notify"]="INVALID ENTRY"
     	return 
	end
	B747DR_airspeed_V2=val 
  end
  if value=="flapsRef" then 
	if val~=10 and val~=20 then
		fmsO["notify"]="INVALID ENTRY"
     	return 
	end
	if val ~= B747DR_airspeed_flapsRef then takeoff_speeds_deleted() end
	B747DR_airspeed_flapsRef=val 
  end

  fmsO["scratchpad"]=""
end
function fmsFunctions.setscratchpad(fmsO,value)
	fmsO["scratchpad"]=value
end
function fmsFunctions.respondmessage(fmsO,value)
	acarsSystem.setCurrentMessage(fmsO.id,value)
	fmsO["inCustomFMC"]=true
	fmsO["targetPage"]="RESPONDACARSMSG"
	run_after_time(switchCustomMode, 0.5)
  end

function fmsFunctions.sendACARSmessage(fmsO,value)
	print("send "..value)
	acarsSystem.setCurrentMessage(fmsO.id,value)
	print("setCurrentMessage "..value)
	fmsFunctions["acarsRespondATC"](fmsO,value)
	print("acarsRespondATC "..value)
	fmsO["inCustomFMC"]=true
  	fmsO["targetPage"]="VIEWACARSLOG"
  	run_after_time(switchCustomMode, 0.5)
end
function fmsFunctions.showmessage(fmsO,value)
  acarsSystem.setCurrentMessage(fmsO.id,value)
  fmsO["inCustomFMC"]=true
  fmsO["targetPage"]="VIEWACARSMSG"
  fmsO["pgNo"]=1
  run_after_time(switchCustomMode, 0.5)
end

function fmsFunctions.doCMD(fmsO,value)
  print("do fmc command "..value)
  if fmsModules["cmds"][value] ~= nil then
	fmsModules["cmds"][value]:once()
	fmsModules["lastcmd"]=fmsModules["cmdstrings"][value]
  end
end
function fmsFunctions.setacars(fmsO,value)
	setFMSData("acarsMessage",value)
	fmsO["inCustomFMC"]=true
  	fmsO["targetPage"]="ATCVERIFYWCEREQUEST"
  	run_after_time(switchCustomMode, 0.5)
end
function fmsFunctions.clearreq(fmsO,value)
	setFMSData("acarsREQALT","")
	setFMSData("acarsREQSPEED","")
	setFMSData("acarsREQOFFSET","")
	setFMSData("acarsREQHDG","")
	setFMSData("acarsREQTRK","")
	setFMSData("acarsREQAT","")
	setFMSData("acarsREQTO","")
	setFMSData("acarsREQDUE","")
	setFMSData("acarsMessage","")
end
function fmsFunctions.setmayday(fmsO,value)
	setFMSData("acarsEMERMSG",value)
	fmsO["inCustomFMC"]=true
  	fmsO["targetPage"]="ATCVERIFYEMERGENCY"
  	run_after_time(switchCustomMode, 0.5)
end
function fmsFunctions.clearemergency(fmsO,value)
	setFMSData("acarsEMEROFFSET","")
	setFMSData("acarsEMERMSG","")
	setFMSData("acarsEMERDESC","")
	setFMSData("acarsMessage","")
end
function fmsFunctions.clearwce(fmsO,value)
	setFMSData("acarsWCWCRZCLB","")
	setFMSData("acarsWCWCLB","")
	setFMSData("acarsWCWDES","")
	setFMSData("acarsWCWSPEED","")
	setFMSData("acarsMessage","")
end	
function fmsFunctions.clearacars(fmsO,value)
	print("do fmc clearacars")
	acarsSystem.clear()
end

function fmsFunctions.setSoundOption(fmsO,value) -- sound options (crazytimtimtim + Matt726)
	-- TODO, this would make more sense to use an array lookup of options, but copied pasted for now
	if value == "alarmsOption" then
		if B747DR_SNDoptions[0] ~= 2 then
			B747DR_SNDoptions[0] = B747DR_SNDoptions[0] + 1
		elseif B747DR_SNDoptions[0] == 2 then
			B747DR_SNDoptions[0] = 0
		end
		simConfigData["data"].SOUND.alarmsOption = B747DR_SNDoptions[0]
		pushSimConfig(simConfigData["data"]["values"])
	end

	if value == "seatBeltOption" then 
		B747DR_SNDoptions[1] = 1 - B747DR_SNDoptions[1] 
		simConfigData["data"].SOUND.seatBeltOption = B747DR_SNDoptions[1]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "paOption" then 
		B747DR_SNDoptions[2] = 1 - B747DR_SNDoptions[2] 
		simConfigData["data"].SOUND.paOption = B747DR_SNDoptions[2]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "musicOption" then 
		B747DR_SNDoptions[3] = 1 - B747DR_SNDoptions[3] 
		simConfigData["data"].SOUND.musicOption = B747DR_SNDoptions[3]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "PM_toggle" then 
		B747DR_SNDoptions[4] = 1 - B747DR_SNDoptions[4] 
		simConfigData["data"].SOUND.PM_toggle = B747DR_SNDoptions[4]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "V1Option" then 
		B747DR_SNDoptions[5] = 1 - B747DR_SNDoptions[5] 
		simConfigData["data"].SOUND.V1Option = B747DR_SNDoptions[5]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end

	-- laminar/B747/fmod/options/gpws[n] in the sound bank's order: 1-13 the
	-- radio altitudes 2500 down to 5, 14 MINIMUMS, 15 APPROACHING MINIMUMS
	if value == "GPWSminimums" then 
		B747DR_SNDoptions_gpws[14] = 1 - B747DR_SNDoptions_gpws[14] 
		simConfigData["data"].SOUND.GPWSminimums = B747DR_SNDoptions_gpws[14]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWSapproachingMinimums" then 
		B747DR_SNDoptions_gpws[15] = 1 - B747DR_SNDoptions_gpws[15] 
		simConfigData["data"].SOUND.GPWSapproachingMinimums = B747DR_SNDoptions_gpws[15]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS2500" then 
		B747DR_SNDoptions_gpws[1] = 1 - B747DR_SNDoptions_gpws[1] 
		simConfigData["data"].SOUND.GPWS2500 = B747DR_SNDoptions_gpws[1]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS1000" then 
		B747DR_SNDoptions_gpws[2] = 1 - B747DR_SNDoptions_gpws[2] 
		simConfigData["data"].SOUND.GPWS1000 = B747DR_SNDoptions_gpws[2]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS500" then 
		B747DR_SNDoptions_gpws[3] = 1 - B747DR_SNDoptions_gpws[3] 
		simConfigData["data"].SOUND.GPWS500 = B747DR_SNDoptions_gpws[3]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS400" then 
		B747DR_SNDoptions_gpws[4] = 1 - B747DR_SNDoptions_gpws[4] 
		simConfigData["data"].SOUND.GPWS400 = B747DR_SNDoptions_gpws[4]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS300" then 
		B747DR_SNDoptions_gpws[5] = 1 - B747DR_SNDoptions_gpws[5] 
		simConfigData["data"].SOUND.GPWS300 = B747DR_SNDoptions_gpws[5]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS200" then
		 B747DR_SNDoptions_gpws[6] = 1 - B747DR_SNDoptions_gpws[6] 
		 simConfigData["data"].SOUND.GPWS200 = B747DR_SNDoptions_gpws[6]
		pushSimConfig(simConfigData["data"]["values"])
		 return 
	end
	if value == "GPWS100" then 
		B747DR_SNDoptions_gpws[7] = 1 - B747DR_SNDoptions_gpws[7] 
		simConfigData["data"].SOUND.GPWS100 = B747DR_SNDoptions_gpws[7]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS50" then 
		B747DR_SNDoptions_gpws[8] = 1 - B747DR_SNDoptions_gpws[8] 
		simConfigData["data"].SOUND.GPWS50 = B747DR_SNDoptions_gpws[8]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS40" then 
		B747DR_SNDoptions_gpws[9] = 1 - B747DR_SNDoptions_gpws[9] 
		simConfigData["data"].SOUND.GPWS40 = B747DR_SNDoptions_gpws[9]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS30" then 
		B747DR_SNDoptions_gpws[10] = 1 - B747DR_SNDoptions_gpws[10] 
		simConfigData["data"].SOUND.GPWS30 = B747DR_SNDoptions_gpws[10]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS20" then 
		B747DR_SNDoptions_gpws[11] = 1 - B747DR_SNDoptions_gpws[11] 
		simConfigData["data"].SOUND.GPWS20 = B747DR_SNDoptions_gpws[11]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS10" then 
		B747DR_SNDoptions_gpws[12] = 1 - B747DR_SNDoptions_gpws[12]
		simConfigData["data"].SOUND.GPWS10 = B747DR_SNDoptions_gpws[12]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end
	if value == "GPWS5" then 
		B747DR_SNDoptions_gpws[13] = 1 - B747DR_SNDoptions_gpws[13] 
		simConfigData["data"].SOUND.GPWS5 = B747DR_SNDoptions_gpws[13]
		pushSimConfig(simConfigData["data"]["values"])
		return 
	end

end
