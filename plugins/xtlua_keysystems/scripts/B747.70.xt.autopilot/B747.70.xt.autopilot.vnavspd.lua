--[[
*****************************************************************************************
* Program Script Name	:	B747.70.autopilot.vnavspd
* Author Name			:	Mark Parker (mSparks)
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2021-03-23	0.01a				Start of Dev
*
*
*
*
--]]

-- the speed restrictions and the transition (6-1 step 1): SPD RESTR shows
-- dashes until entered (FMC-10), SPD TRANS can be deleted; without them the
-- climb goes on at the next speed (the restriction's altitude below any),
-- the descent's restriction is the transition's (FCOM p.1326-1329, p.1392)
function clbRestAlt() return tonumber(getFMSData("clbrestalt")) or -99999 end
function clbEconSpd() return tonumber(getFMSData("clbspd")) or 340 end
function clbTransSpd() return tonumber(getFMSData("transpd")) or clbEconSpd() end
function clbRestSpd() return tonumber(getFMSData("clbrestspd")) or clbTransSpd() end
function desRestAlt() return tonumber(getFMSData("desrestalt")) or tonumber(getFMSData("desspdtransalt")) or 10000 end
function desRestSpd() return tonumber(getFMSData("desrestspd")) or tonumber(getFMSData("destranspd")) or 240 end
-- the FMC's speeds (6-1/6-2 step 8b: ECON from the cost index, SEL SPD,
-- LRC): the climb's Mach in thousandths (blank: the cruise's), and the
-- limit of VNAV's descent targets, VMO/MMO less 11 kt for a crew's (the
-- FMC's ECON is less: FCOM p.1258) here: the CAS, and the Mach of MMO's
function clbMachSpd() return tonumber(getFMSData("clbspdmach")) or tonumber(getFMSData("crzspd")) end
local function desSpdLimit()
    local h = simDR_pressureAlt1 * 0.3048
    local p = h <= 11000 and 101325 * (1 - 2.25577e-5 * h) ^ 5.25588 or 22632.06 * math.exp(-1.5769e-4 * (h - 11000))
    local qc = p * (1.16928 ^ 3.5 - 1)
    local mmoCas = 661.4786 * math.sqrt(5 * ((qc / 101325 + 1) ^ (2 / 7) - 1))
    qc = 101325 * ((1 + 0.2 * ((mmoCas - 11) / 661.4786) ^ 2) ^ 3.5 - 1)
    return math.min(365, mmoCas) - 11, math.sqrt(5 * ((qc / p + 1) ^ (2 / 7) - 1))
end
-- the FMC's speeds together: a change is a new target (6-1/6-2 step 8b)
function fmcSpdKey()
    local k = ""
    for _, id in ipairs({"crzspd", "crzcas", "clbspd", "clbspdmach", "desspd", "desspdmach"}) do k = k .. tostring(getFMSData(id)) .. "," end
    return k
end
local vnavSPD_conditions={}
vnavSPD_conditions["onground"]=0
vnavSPD_conditions["below"]=-1
vnavSPD_conditions["above"]=-1
vnavSPD_conditions["leg"]=0
vnavSPD_conditions["name"]="unknown"
local vnavSPD_state={}
vnavSPD_state["targetSpd"]=180
vnavSPD_state["targetAlt"]=5000
vnavSPD_state["targetVS"]=0 --descend, hold climb
vnavSPD_state["targetAltHold"]=false
vnavSPD_state["spdIsMach"]=false
vnavSPD_state["manualVNAVspd"]=0
vnavSPD_state["vnavcalcwithMCPAlt"]=0
vnavSPD_state["vnavcalcwithTargetAlt"]=0
vnavSPD_state["gotVNAVSpeed"]=false
vnavSPD_state["recalcAfter"]=0
vnavSPD_state["setBaro"]=false
--[[
    clb_src_next()
    First state during climb, get the altitude for next update as 200ft agl
]]
function clb_src_next()
    return simDR_pressureAlt1+(100-simDR_radarAlt1) --400ft agl at current pressure alt
end

--[[
    clb_aptres_next()
    Lower airspeed restriction , get the altitude for next update 100ft above SPD REST ALT, L4 on FMC VNAV page 1
    updates every 500 feet
]]
function clb_aptres_next()
    --return tonumber(getFMSData("clbrestalt"))+100
    local tAlt=clbRestAlt()+100
    if tAlt>simDR_pressureAlt1+500 then
        tAlt=math.min(simDR_pressureAlt1+500,tAlt)
    end
    return tAlt
end
--[[
    clb_spcres_next()
    Lower airspace airspeed restriction , get the altitude for next update 100ft above SPD TRANSE ALT, L3 on FMC VNAV page 1
    updates every 500 feet
]]
function clb_spcres_next()
    --return tonumber(getFMSData("spdtransalt"))+100
    local tAlt=tonumber(getFMSData("spdtransalt"))+100
    if tAlt>simDR_pressureAlt1+500 then
        tAlt=math.min(simDR_pressureAlt1+500,tAlt)
    end
    return tAlt
end
--[[
    clb_spcres_next()
    Unrestrictied airspeed climb speed , get the altitude for next update 100ft above SPD TRANSE ALT, L3 on FMC VNAV page 1
    updates every 500 feet
]]
function clb_nores_next()
    --return (tonumber(string.sub(getFMSData("crzalt"),3))*100)-1000
    local tAlt=(B747BR_cruiseAlt)-500
    if tAlt>simDR_pressureAlt1+500 then
        tAlt=math.min(simDR_pressureAlt1+500,tAlt,B747BR_cruiseAlt-math.max(B747DR_alt_capture_window,500))
    end
    return tAlt
end
function clb_crz_next()
    return B747BR_cruiseAlt+1000
end
function des_src_next()
    --return tonumber(getFMSData("desspdtransalt"))
    local tAlt=tonumber(getFMSData("desspdtransalt"))
    if tAlt<simDR_pressureAlt1-500 then
        tAlt=math.max(simDR_pressureAlt1-500,tAlt)
    end
    return tAlt
end
function des_aptres_next()
    local tAlt=desRestAlt()
    if tAlt<simDR_pressureAlt1-500 then
        tAlt=math.max(simDR_pressureAlt1-500,tAlt)
    end
    return tAlt
end
function des_spcres_next()
    return -100
end
local spd_states={}
spd_states["clb"]={}
spd_states["des"]={}
spd_states["clb"]["src"]={}
spd_states["clb"]["aptres"]={}
spd_states["clb"]["spcres"]={}
spd_states["clb"]["nores"]={}
spd_states["clb"]["crz"]={}
spd_states["des"]["src"]={}
spd_states["des"]["aptres"]={}
spd_states["des"]["spcres"]={}

spd_states["clb"]["src"]["nextfunc"]=clb_src_next
spd_states["clb"]["aptres"]["nextfunc"]=clb_aptres_next
spd_states["clb"]["spcres"]["nextfunc"]=clb_spcres_next
spd_states["clb"]["nores"]["nextfunc"]=clb_nores_next
spd_states["clb"]["crz"]["nextfunc"]=clb_crz_next
spd_states["des"]["src"]["nextfunc"]=des_src_next
spd_states["des"]["aptres"]["nextfunc"]=des_aptres_next
spd_states["des"]["spcres"]["nextfunc"]=des_spcres_next

spd_states["clb"]["src"]["nextstate"]="aptres"
spd_states["clb"]["aptres"]["nextstate"]="spcres"
spd_states["clb"]["spcres"]["nextstate"]="nores"
spd_states["clb"]["nores"]["nextstate"]="crz"
spd_states["clb"]["crz"]["nextstate"]=nil
spd_states["des"]["src"]["nextstate"]="aptres"
spd_states["des"]["aptres"]["nextstate"]="spcres"
spd_states["des"]["spcres"]["nextstate"]=nil
function modFlapSpeed(speed)
    local minSafeSpeed = B747DR_airspeed_Vmc + 10
	local maxSafeSpeed = B747DR_airspeed_Vmo
	if simDR_flap_ratio_control > 0 then
		if simDR_flap_ratio_control <= 0.168 then --flaps 1
			maxSafeSpeed = math.min(275,B747DR_airspeed_Vf0+15)
		elseif simDR_flap_ratio_control <= 0.34 then --flaps 5
			maxSafeSpeed = math.min(255,B747DR_airspeed_Vf1+15)
		elseif simDR_flap_ratio_control <= 0.5 then --flaps 10
			maxSafeSpeed = math.min(235,B747DR_airspeed_Vf5+15)
			minSafeSpeed = minSafeSpeed - 5
		elseif simDR_flap_ratio_control <= 0.668 then --flaps 20
			maxSafeSpeed = math.min(225,B747DR_airspeed_Vf10+15)
			minSafeSpeed = minSafeSpeed - 5
		elseif simDR_flap_ratio_control <= 0.84 then --flaps 25
			maxSafeSpeed = math.min(200,B747DR_airspeed_Vf20+2)
			minSafeSpeed = minSafeSpeed - 9
		elseif simDR_flap_ratio_control <= 1.0 then --flaps 30
			maxSafeSpeed = math.min(175,B747DR_airspeed_Vf25+2)
			minSafeSpeed = minSafeSpeed - 9
		end
	end
    if speed<minSafeSpeed then return minSafeSpeed
    elseif speed>maxSafeSpeed then return maxSafeSpeed
    else return speed end
end
function clb_src_setSpd()
    
    if B747DR_airspeed_V2<900 then
        simDR_autopilot_airspeed_is_mach = 0
        B747DR_ap_ias_dial_value = math.min(399.0, B747DR_airspeed_V2)
        B747DR_switchingIASMode=1
        B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
        run_after_time(B747_updateIAS, 0.25)
    end
    vnavSPD_state["setBaro"]=false
end
function clb_aptres_setSpd()
    local spdval=modFlapSpeed(clbRestSpd())
    spdval=math.max(spdval,simDR_ind_airspeed_kts_pilot-15)
    simDR_autopilot_airspeed_is_mach = 0
    print("convert to clb clbrestspd ".. spdval)
    B747DR_ap_ias_dial_value = math.min(399.0, spdval)
    B747DR_switchingIASMode=1
    B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
    run_after_time(B747_updateIAS, 0.25)

end
function clb_spcres_setSpd()
    -- below the SPD TRANS altitude: the SPD TRANS speed (FMC-09; FCOM p.1326)
    local spdval=modFlapSpeed(clbTransSpd())
    B747DR_switchingIASMode=1
    local crzspdval=clbMachSpd()/10
    if simDR_airspeed_mach > (crzspdval/100) then
      print("convert to cruise speed in clb ".. crzspdval)
      simDR_autopilot_airspeed_is_mach = 1
      B747DR_ap_ias_dial_value = crzspdval
      B747DR_lastap_dial_airspeed=crzspdval*0.01
    else

      --[[if B747DR_ap_ias_dial_value+5<simDR_ind_airspeed_kts_pilot then
        spdval=math.min(simDR_ind_airspeed_kts_pilot,spdval)
      elseif(B747DR_ap_ias_dial_value<spdval) and simDR_autopilot_airspeed_is_mach == 0 then
        spdval=math.min(B747DR_ap_ias_dial_value+5,spdval)
      end]]--
      spdval=math.max(spdval,simDR_ind_airspeed_kts_pilot-15)
      simDR_autopilot_airspeed_is_mach = 0
      print("convert to clb speed ".. spdval.. " at "..simDR_ind_airspeed_kts_pilot)
      B747DR_ap_ias_dial_value = math.min(399.0, spdval)
      B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
    end
    run_after_time(B747_updateIAS, 0.25)

end
function clb_nores_setSpd()
    -- above the SPD TRANS altitude: ECON (FMC-09; FCOM p.1326)
    local spdval=modFlapSpeed(clbEconSpd())
    B747DR_switchingIASMode=1
    local crzspdval=clbMachSpd()/10
    if simDR_airspeed_mach > (crzspdval/100) then
      print("convert to cruise speed in clb".. crzspdval)
      simDR_autopilot_airspeed_is_mach = 1
      B747DR_ap_ias_dial_value = crzspdval
      B747DR_lastap_dial_airspeed=crzspdval*0.01
    else
      if simDR_autopilot_airspeed_is_mach == 0 then
      --[[if(B747DR_ap_ias_dial_value<spdval) then
        spdval=math.min(B747DR_ap_ias_dial_value+10,spdval)
      elseif(B747DR_ap_ias_dial_value>spdval) then
            spdval=math.max(B747DR_ap_ias_dial_value-10,spdval)
      end]]--
     else
        simDR_autopilot_airspeed_is_mach = 0
     end
      spdval=math.max(spdval,simDR_ind_airspeed_kts_pilot-15)
      print("convert to transpd speed ".. spdval)
      B747DR_ap_ias_dial_value = math.min(399.0, spdval)
      B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
    end
    run_after_time(B747_updateIAS, 0.25)

end
function clb_crz_setSpd()
    -- the FMC's cruise speed (6-1/6-2 step 8b: ECON from the cost index by
    -- the FMC's cruise model, SEL SPD or LRC; before, a Mach fitted to the
    -- weight and altitude here): a Mach, or a crew's CAS
    local spdval=tonumber(getFMSData("crzspd"))/10
    local cas=tonumber(getFMSData("crzcas"))
    local transalt=tonumber(getFMSData("transalt"))
    local tspdval=modFlapSpeed(clbEconSpd())
    if simDR_pressureAlt1>=transalt or simDR_ind_airspeed_kts_pilot>=tspdval-1 then
        if cas then
            print("convert to cruise CAS in clb_crz_setSpd ".. cas)
            simDR_autopilot_airspeed_is_mach = 0
            B747DR_ap_ias_dial_value = math.min(399.0, cas)
            B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
        else
            print("convert to cruise speed in clb_crz_setSpd ".. spdval)
            simDR_autopilot_airspeed_is_mach = 1
            B747DR_ap_ias_dial_value = spdval
            B747DR_lastap_dial_airspeed=spdval*0.01
        end
        run_after_time(B747_updateIAS, 0.25)
    end
end

function des_src_setSpd()
    local limcas, limmach = desSpdLimit()
    local crzspdval=math.min(tonumber(getFMSData("desspdmach")), limmach * 1000)/10
    local spdval=math.min(tonumber(getFMSData("desspd")), limcas)
    local nextspdval=tonumber(getFMSData("destranspd"))
    if simDR_airspeed_mach > (crzspdval/100) then
      print("convert to mach descend speed in des".. crzspdval)
      simDR_autopilot_airspeed_is_mach = 1
      B747DR_ap_ias_dial_value = crzspdval
      B747DR_lastap_dial_airspeed=crzspdval*0.01
    else

      if simDR_autopilot_airspeed_is_mach==1 then
        spdval=simDR_ind_airspeed_kts_pilot
      elseif(B747DR_ap_ias_dial_value>spdval) then
        spdval=math.max(B747DR_ap_ias_dial_value-15,spdval)
      else
        local lowerAlt=tonumber(getFMSData("desspdtransalt"))+1000
        local upperAlt=lowerAlt+1500
        spdval=B747_rescale(lowerAlt,nextspdval,upperAlt,spdval,simDR_pressureAlt1)
      end
      simDR_autopilot_airspeed_is_mach = 0
      print("des_src_setSpd:convert to descend speed ".. spdval)
      B747DR_ap_ias_dial_value = math.min(399.0, spdval)
      B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value

    end
    run_after_time(B747_updateIAS, 0.25)
end
function des_aptres_setSpd()
    local spdval=tonumber(getFMSData("destranspd"))
    local lowerAlt=desRestAlt()


    local nextspdval=desRestSpd()
    spdval=B747_rescale(lowerAlt+1000,nextspdval,lowerAlt+1500,spdval,simDR_pressureAlt1)
    simDR_autopilot_airspeed_is_mach = 0
    print("convert to destranspd speed ".. spdval)
    B747DR_ap_ias_dial_value = math.min(399.0, spdval)
    B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
    run_after_time(B747_updateIAS, 0.25)
    if B747DR_autothrottle_active == 0 and simDR_ind_airspeed_kts_pilot < spdval+5 then							-- AUTOTHROTTLE IS "OFF"
       if isATEnabled() then
        B747DR_autothrottle_active=1
       end
        B747DR_ap_lastCommand = simDRTime
        if B747DR_engine_TOGA_mode ==1 then B747DR_engine_TOGA_mode = 0 end	-- CANX ENGINE TOGA IF ACTIVE
    end
end
function des_spcres_setSpd()
    local spdval=desRestSpd()
    simDR_autopilot_airspeed_is_mach = 0
    print("convert to desrestspd speed ".. spdval)
    B747DR_ap_ias_dial_value = math.min(399.0, spdval)
    B747DR_lastap_dial_airspeed=B747DR_ap_ias_dial_value
    run_after_time(B747_updateIAS, 0.25)
    if B747DR_autothrottle_active == 0 and simDR_ind_airspeed_kts_pilot < spdval+5 then							-- AUTOTHROTTLE IS "OFF"
        if isATEnabled() then
            B747DR_autothrottle_active=1
        end
        B747DR_ap_lastCommand = simDRTime
        if B747DR_engine_TOGA_mode ==1 then B747DR_engine_TOGA_mode = 0 end	-- CANX ENGINE TOGA IF ACTIVE
    end
end
spd_states["clb"]["src"]["spdfunc"]=clb_src_setSpd
spd_states["clb"]["aptres"]["spdfunc"]=clb_aptres_setSpd
spd_states["clb"]["spcres"]["spdfunc"]=clb_spcres_setSpd
spd_states["clb"]["nores"]["spdfunc"]=clb_nores_setSpd
spd_states["clb"]["crz"]["spdfunc"]=clb_crz_setSpd
spd_states["des"]["src"]["spdfunc"]=des_src_setSpd
spd_states["des"]["aptres"]["spdfunc"]=des_aptres_setSpd
spd_states["des"]["spcres"]["spdfunc"]=des_spcres_setSpd

function setVNAVState(name,value)
    vnavSPD_state[name]=value
end
function getVNAVState(name)
    return vnavSPD_state[name]
end
local lastVNAVSpeed=0
function B747_update_vnav_speed()
    if simDR_onGround~=vnavSPD_conditions["onground"] then vnavSPD_state["gotVNAVSpeed"]=false end
    if vnavSPD_conditions["above"]>0 and vnavSPD_conditions["above"]<simDR_pressureAlt1 then
      print("above "..vnavSPD_conditions["above"].. " " ..vnavSPD_conditions["name"])
      vnavSPD_state["gotVNAVSpeed"]=false
      lastVNAVSpeed=simDRTime
    end
    if vnavSPD_conditions["descent"]==(B747DR_ap_inVNAVdescent>0) then
       print("descent "..B747DR_ap_inVNAVdescent.. " " ..vnavSPD_conditions["name"])
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end
    if vnavSPD_conditions["below"]>0 and vnavSPD_conditions["below"]>simDR_pressureAlt1 then
       print("below "..vnavSPD_conditions["below"].. " " ..vnavSPD_conditions["name"])
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end
    if vnavSPD_conditions["crzAlt"]~=B747BR_cruiseAlt then
       print("new crzAlt")
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end
    if vnavSPD_conditions["crzSpd"]~=fmcSpdKey() then
       print("new crzSpd")
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end
    if vnavSPD_conditions["leg"]~=B747DR_fmscurrentIndex then
       print("new crzSpd leg")
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end

    local diff=simDRTime-lastVNAVSpeed
    if diff>30 then
       vnavSPD_state["gotVNAVSpeed"]=false
       lastVNAVSpeed=simDRTime
    end
    --probably not needed?
    --[[if vnavSPD_conditions["mcpAlt"]~=B747DR_autopilot_altitude_ft then
        print("new mcpAlt")
        vnavSPD_conditions["mcpAlt"]=B747DR_autopilot_altitude_ft
        vnavSPD_state["gotVNAVSpeed"]=false
     end]]
end
function B747_vnav_setClimbspeed()
    local lastAlt=simDR_pressureAlt1+(simDR_radarAlt1-400)
    local cState="src"
    local nextAlt=spd_states["clb"]["src"]["nextfunc"]()
     --print("B747_vnav_setClimbspeed "..nextAlt.." "..simDR_pressureAlt1)

    while simDR_pressureAlt1>nextAlt and spd_states["clb"][cState]["nextstate"]~=nil do
        lastAlt=nextAlt
        if simDR_pressureAlt1>nextAlt then
            cState=spd_states["clb"][cState]["nextstate"]
        end
        nextAlt=spd_states["clb"][cState]["nextfunc"]()
        print("B747_vnav_setClimbspeed "..lastAlt .. " cState ".. cState.. " nextAlt ".. nextAlt)
    end
    -- no altimeters to STD at the transition altitude: the FMC has no such
    -- function (FMC-33, 6-1 step 1; FCOM p.1329)
    vnavSPD_conditions["name"]="clb_"..cState
    vnavSPD_conditions["onground"]=simDR_onGround
    vnavSPD_conditions["below"]=lastAlt
    vnavSPD_conditions["above"]=nextAlt
    vnavSPD_conditions["descent"]=true
    vnavSPD_conditions["crzAlt"]=B747BR_cruiseAlt
    vnavSPD_conditions["crzSpd"]=fmcSpdKey()
    vnavSPD_conditions["leg"]=B747DR_fmscurrentIndex
    vnavSPD_state["spdIsMach"]=simDR_autopilot_airspeed_is_mach
    vnavSPD_state["gotVNAVSpeed"]=true
    print("climb cState " .. cState .. " lastAlt "..lastAlt .. " nextAlt "..nextAlt)
    spd_states["clb"][cState]["spdfunc"]()
end

function B747_vnav_setDescendspeed()
    local lastAlt=simDR_pressureAlt1+1000
    local cState="src"
    local nextAlt=spd_states["des"]["src"]["nextfunc"]()
    while simDR_pressureAlt1<nextAlt and spd_states["des"][cState]["nextstate"]~=nil do
        lastAlt=nextAlt
        if simDR_pressureAlt1<nextAlt then
            cState=spd_states["des"][cState]["nextstate"]
        end
        nextAlt=spd_states["des"][cState]["nextfunc"]()
    end

    vnavSPD_conditions["name"]="des_"..cState
    vnavSPD_conditions["onground"]=simDR_onGround
    vnavSPD_conditions["below"]=nextAlt
    vnavSPD_conditions["above"]=lastAlt
    vnavSPD_conditions["descent"]=false
    vnavSPD_conditions["crzAlt"]=B747BR_cruiseAlt
    vnavSPD_conditions["crzSpd"]=fmcSpdKey()
    vnavSPD_conditions["leg"]=B747DR_fmscurrentIndex
    vnavSPD_state["spdIsMach"]=simDR_autopilot_airspeed_is_mach
    vnavSPD_state["gotVNAVSpeed"]=true
    print("des cState " .. cState .. " lastAlt "..lastAlt .. " nextAlt "..nextAlt)
    spd_states["des"][cState]["spdfunc"]()
end
function B747_vnav_speed()
    
    if B747DR_ap_vnav_state==0 then return end
    if getFMSData("crzalt")==nil then
        print("B747_vnav_speed nil "..B747BR_cruiseAlt)
        -- through the AFDS model (6-3 step 1c: its arm would set it again)
        B747_afds_vnav_lost()
    end
    local radarAltRefresh=simDR_radarAlt1
    local pressureAltRefresh=simDR_pressureAlt1
    if getVNAVState("manualVNAVspd")==1 then return end
    B747_update_vnav_speed()
    if vnavSPD_state["gotVNAVSpeed"]==true then return end
    if B747DR_ap_inVNAVdescent ==0 then
        B747_vnav_setClimbspeed()
        print("B747_vnav_setClimbspeed ")
    else
        B747_vnav_setDescendspeed()

    end

end
