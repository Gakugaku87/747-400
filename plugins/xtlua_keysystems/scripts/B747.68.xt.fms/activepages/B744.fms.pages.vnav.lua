-- VNAV LRC Page by Garen Evans, Revised 15 April 2021 2016 UTC
----------------------------------------------------------------------------------------------
--
-- the following datarefs nil if not assigned:
fmsJson = find_dataref("xtlua/fms") -- fmsJSON is nil

-- the following were identifed as redundant dataref calls (April 2021)
----------------------------------------------------------------------------------------------
--simDR_groundspeed = find_dataref("sim/flightmodel/position/groundspeed") --meters per second
--simDR_onGround=find_dataref("sim/flightmodel/failures/onground_any")
--simDR_autopilot_vs_status = find_dataref("sim/cockpit2/autopilot/vvi_status")

-- the following were replaced with simDR_latitude and simDR_longitude
--simDR_lat=find_dataref("sim/flightmodel/position/latitude")
--simDR_lon=find_dataref("sim/flightmodel/position/longitude")

-- the following was replaced by B747DR_airspeed_V2
--simDR_V2 =find_dataref("laminar/B747/airspeed/V2")

-- the following was replaced by simDR_fueL_tank_weight_total_kg
--fob_kg = find_dataref("sim/flightmodel/weight/m_fuel_total") -- fuel weight total, kg
-- ======================================================================================

local nxWpt = "*****"
local eodWpt = "*****"
local eodAlt =0
local dICAO = "****"
local dLat = 0 --destination latitude
local dLon = 0 --destination longitude
local dNM = -1 --distance to destination, this is currently assigned and used on Pg1 and also used on Pg2
--dNM = find_dataref("laminar/B747/autopilot/dist/remaining_distance") -- this is too inconsistent to use right now

local conv = 1.0 --converter (pounds to kilos)

-- the speeds (6-1/6-2 step 8b; notes/ATA-34-61-FMC.md §45): ECON from the
-- cost index (B747.68.xt.fms.lua's update_econ), SEL SPD by a crew's entry,
-- LRC; <ECON (5L) and LRC> (CRZ 6R) choose (FCOM p.1327-1328, p.1347-1350,
-- p.1391-1392; FMSPG p.112-113, p.131-134, p.192-193)
local function vnav_text(id) return (string.gsub(fmsModules["data"][id], "%s+$", "")) end
-- a page title centred in the room left of the page number, ACT if active
local function vnav_title(text, active)
  local s = (active and "ACT " or "") .. text
  local pad = math.max(0, math.floor((22 - string.len(s)) / 2))
  return string.rep(" ", pad) .. s .. string.rep(" ", math.max(0, 24 - pad - string.len(s)))
end
-- the title's speed: ECON, LRC, or the selected XXXKT, or M.XXX once at it
local function spd_title(mode, cas, mach)
  if mode == "E" then return "ECON" end
  if mode == "L" then return "LRC" end
  if mach and (cas == nil or simDR_mach_pilot >= mach / 1000 - 0.0005) then return string.format("M.%03d", mach) end
  return string.format("%dKT", cas)
end
-- a line of a left and a right part
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - string.len(l) - string.len(r))) .. r end
function fmsFunctions.vnavspd(fmsO, value)
  if value == "clb" then
    setFMSData("clbspdmode", "E") setFMSData("clbspd", "") setFMSData("clbspdmach", "")
  elseif value == "crz" then
    setFMSData("crzspdmode", "E") setFMSData("crzspd", "") setFMSData("crzcas", "")
  elseif value == "des" then
    setFMSData("desspdmode", "E") setFMSData("desspd", "") setFMSData("desspdmach", "")
  elseif value == "lrc" then
    setFMSData("crzspdmode", "L") setFMSData("crzcas", "")
  end
  B747_fms_econ_now()
  update_econ()
end

fmsPages["VNAV"]=createPage("VNAV")
fmsPages["VNAV"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  

  if simConfigData["data"].SIM.weight_display_units == "LBS" then
    conv = 1.0
  else
    conv = 1 / simConfigData["data"].SIM.kgs_to_lbs
  end
  
    gsKTS = 1.94384 * simDR_groundspeed
    if pgNo==1 then 

      --ref pg 1519 fcomm
      fmsFunctionsDefs["VNAV"]["L1"]={"setdata","crzalt"}
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","clbspd"}
      fmsFunctionsDefs["VNAV"]["L3"]={"setdata","clbtrans"}
      fmsFunctionsDefs["VNAV"]["L4"]={"setdata","clbrest"}
      fmsFunctionsDefs["VNAV"]["L5"]=fmsModules["data"]["clbspdmode"]=="S" and {"vnavspd","clb"} or nil
      fmsFunctionsDefs["VNAV"]["L6"]=nil
      fmsFunctionsDefs["VNAV"]["R1"]=nil
      fmsFunctionsDefs["VNAV"]["R3"]={"setdata","transalt"}
      fmsFunctionsDefs["VNAV"]["R6"]=nil

      spdalt = "     -----"
      error_line = "                 "

      
      --print(" --------------------- ")
      --print(simDR_RA_Min)
      --print("--------------------------------------"..B747DR_FMSdata)

      --if(simDR_onGround~=1) then
      if(string.len(fmsJson) > 2) then
        local fms2 = fms_route()
        if(fms2 ~= nil and fmsModules["data"]["crzalt"]~="*****") then
--          print("fmsJson")
--          print(fmsJson)
          --print("----------------------------------------")
          -- Determine cruise alt from FMC based on max altitude set -------- start
          maxalt = -999 -- this will be cruise altitude when we're done
          maxidx = 0 --place in fms where first occurence of cruise is found
          for i=1,table.getn(fms2),1 do
            if(tonumber(fms2[i][9]) > maxalt) then 
              maxalt = tonumber(fms2[i][9])
              maxidx = i
            end
          end
          -- ------------------------- ---------------------------------------- end
          nfms2 = table.getn(fms2)
          dICAO = fms2[nfms2][8] -- desintation icao (used on page2)
          dLat = fms2[nfms2][5]
          dLon = fms2[nfms2][6]
          dNM = getDistance(simDR_latitude, simDR_longitude, dLat, dLon)
          for i=1,nfms2,1 do
            if(fms2[i][10] == true) then -- find the next waypoint

              -- increment through the fms to find valid waypoint
              while((i==1 or string.len(fms2[i][8])>5 or tonumber(fms2[i][8])~=nil) and ((i+1)<nfms2) ) do
                i = i + 1
              end

              nxWpt = fms2[i][8] -- used on small page
              alt = tonumber(fms2[i][9]) --altitude at the waypoint
              if(alt == 0) then alt = maxalt end --default to max alt if zero
              --spdalt = " ***/*****"
              spdalt = "     FL"..string.format("%03d",alt/100)
              if(i <= maxidx and math.abs(maxalt-simDR_pressureAlt1) > 500) then -- climb phase
                -- no SPD RESTR (dashes) or SPD TRANS (deleted): none (6-1 step 1)
                local restSpd = tonumber(fmsModules["data"]["clbrestspd"])
                local restAlt = tonumber(fmsModules["data"]["clbrestalt"]) or -99999
                local transSpd = tonumber(fmsModules["data"]["transpd"])
                local transAlt = tonumber(fmsModules["data"]["spdtransalt"]) or 10000
                local econSpd = tonumber(fmsModules["data"]["clbspd"]) or 340
                if(restSpd and alt < restAlt) then
                  spdalt = restSpd.."/"..alt
                elseif(transSpd and alt < transAlt) then
                  spdalt = transSpd.."/"..alt
                else
                  spdalt = econSpd.."/"..alt
                end
                
                local altdif = math.abs(simDR_pressureAlt1 - alt) --diff actual vs cruise altitude
                -- Error at Waypoint (FCOM p.974)
                if(altdif > 500 and  simDR_onGround ~= 1) then -- still in climb phase
                  wlat = tonumber(fms2[i][5])
                  wlon = tonumber(fms2[i][6])
                  walt = tonumber(fms2[i][9])
                  dist_to_wpt = getDistance(simDR_latitude,simDR_longitude,wlat,wlon)
                  alt_at_wpt = simDR_pressureAlt1 + (60*(dist_to_wpt/gsKTS))*simDR_vvi_fpm_pilot
    
                  dist_to_alt = dist_to_wpt - ((((walt-simDR_pressureAlt1)/simDR_vvi_fpm_pilot)/60)*gsKTS)
                  alt_discrep = alt_at_wpt - walt
                  if(alt_discrep < 0) then
                    error_line = string.format("%.0f LO  %.0f LONG",-alt_discrep, -dist_to_alt)
                  end
                end
              end
            end
          end
        end
      end        
      --end

      -- MAX ANGLE: the minimum drag speed at the weight and altitude (the
      -- cruise model, 6-1/6-2 step 8b: an estimate; before, V2 + 80 or 100)
      local _, maxAngle = B747_perf_db.min_drag(B747_fms_perf(), B747_fms_gw_kg(), math.max(0, simDR_pressureAlt1))
      VxSpeed = string.format("%3d", math.floor(maxAngle + 0.5))

      -- the title: the speed restriction's or transition's below their
      -- altitudes while active (FMSPG p.112: ACT 250KT CLB), else ECON or
      -- the selected speed
      local mode = vnav_text("clbspdmode")
      local cas, mach = tonumber(fmsModules["data"]["clbspd"]), tonumber(fmsModules["data"]["clbspdmach"])
      local active = B747DR_ap_flightPhase==1
      local title = spd_title(mode, cas, mach)
      local restSpd, restAlt = tonumber(fmsModules["data"]["clbrestspd"]), tonumber(fmsModules["data"]["clbrestalt"])
      local transSpd, transAlt = tonumber(fmsModules["data"]["transpd"]), tonumber(fmsModules["data"]["spdtransalt"])
      if active and restSpd and restAlt and simDR_pressureAlt1 < restAlt then
        title = string.format("%dKT", restSpd)
      elseif active and transSpd and transAlt and simDR_pressureAlt1 < transAlt then
        title = string.format("%dKT", transSpd)
      end
      -- ECON SPD or SEL SPD: CAS/Mach (FMSPG p.113: 358/.853), a selected
      -- CAS alone without the Mach
      local spdText = vnav_text("clbspd")
      local machText = vnav_text("clbspdmach")
      if machText == "" and mode ~= "S" then machText = vnav_text("crzspd") end
      if machText ~= "" then spdText = spdText .. "/." .. machText end
      return{
        vnav_title(title .. " CLB", active),
      "                        ",
      fmsModules["data"]["crzalt"].."         "..spdalt,
      "                        ",
      lr(spdText, (string.gsub(error_line, "%s+$", ""))),
                                        --**** LO  ** LONG
      "                        ",
      fmsModules["data"]["transpd"].."/"..fmsModules["data"]["spdtransalt"].."          "..fmsModules["data"]["transalt"],
      "                        ",
      lr(fmsModules["data"]["clbrestspd"].."/"..fmsModules["data"]["clbrestalt"], VxSpeed),
      "------------------------",
      lr(mode=="S" and "<ECON" or "", "ENG OUT>"),
      "                        ",
      "                CLB DIR>"
      }
    elseif pgNo==2 then 
      --ref pg 1543 fcomm
      fmsFunctionsDefs["VNAV"]["L1"]={"setdata","crzalt"}
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","crzspd"}
      fmsFunctionsDefs["VNAV"]["L3"]=nil
      fmsFunctionsDefs["VNAV"]["L4"]=nil
      fmsFunctionsDefs["VNAV"]["L5"]=fmsModules["data"]["crzspdmode"]~="E" and {"vnavspd","crz"} or nil
      fmsFunctionsDefs["VNAV"]["L6"]={"setpage","PROGRESS"}
      fmsFunctionsDefs["VNAV"]["R1"]={"setdata","stepalt"}
      fmsFunctionsDefs["VNAV"]["R3"]=nil
      fmsFunctionsDefs["VNAV"]["R6"]=fmsModules["data"]["crzspdmode"]~="L" and {"vnavspd","lrc"} or nil
      
      dNM = getDistance(simDR_latitude, simDR_longitude, dLat, dLon)


      local gwtk = simDR_GRWT/1000 -- kilograms, thousands
      local optmax = "FL***/***"
      local pctn1 = "*.**"
      local svcCeil = 45.1 --service ceiling in thousands of feet
      local perf = B747_fms_perf()
      local isaDev = B747_fms_isa_dev()
      if(gwtk ~= nil) then
        -- the FCOM PI tables (6-1/6-2 step 8a: notes/ATA-34-61-FMC.md §44;
        -- before, lines fitted to FCOM p.1576, ISA+10 and below)
        optA = B747_perf_db.opt_alt(perf, simDR_GRWT) / 1000
        maxA = B747_perf_db.max_alt(perf, simDR_GRWT, isaDev) / 1000
        pctn1 = string.format("%02.1f",74.157374+ 0.053892*gwtk) -- percent N1
        if(maxA > svcCeil) then maxA=svcCeil end -- service ceiling 45100 MSL
        optmax = string.format("FL%03.0f  FL%03.0f",optA*10,maxA*10) -- displayed in flight levels
      end
  
      -- Calculate altitude, and time/distance to step climb altitude
      -- only show if crz alt +2000 < max
      local czak = -1
      local crzaltString = fmsModules["data"]["crzalt"]
      local stepTD = "  ****z /****NM"

      if(crzaltString ~= "*****" and crzaltString ~= nil and gwtk ~= nil) then
      
        if(string.sub(crzaltString,1,2) == "FL") then
          czak = string.sub(crzaltString,3)/10 --altitude in thousands of feet
        else
          czak = crzaltString/1000 ----altitude in thousands of feet
        end
        if((czak + 2) < maxA) then
          fmsModules["data"]["stepalt"] = "FL"..string.format("%03.0f",(czak+2)*10)
          --stepTD = string.format("     %02d%02dz %04d",hh,mm,dNM)
          stepTD = string.format("          %02d%02dz",hh,mm)

        elseif(czak+2 < svcCeil) then --step climb below service ceiline

          local stepAlt = maxA + 2 --in thousands of feet
          rgw = B747_perf_db.max_alt_weight(perf, stepAlt * 1000, isaDev) / 1000 -- required gross weight, thousands of kg (step 8a)

          --gross weight to lose == kg*1000 fuel to burn
          gwl = gwtk - rgw -- thousands of kg
          
          local hh_sc = hh --default to current time
          local mm_sc = mm --default to current time
          local ffkgh = (simDR_eng_fuel_flow_kg_sec[0] + simDR_eng_fuel_flow_kg_sec[1] + simDR_eng_fuel_flow_kg_sec[2] + simDR_eng_fuel_flow_kg_sec[3]) * 3600.0
          if(ffkgh == nil or ffkgh == 0) then ffkgh = 11000 end
          if(ffkgh > 0) then
            htsc = (gwl*1000) / ffkgh --hours to step climb
            tasc = hh+mm/60 + htsc --time at step climb
            hh_sc = math.floor(tasc)
            mm_sc = math.floor(60*(tasc - hh_sc))
            if(hh_sc > 24) then hh_sc = hh_sc%24 end

            local nmsc = htsc*400 --default, eg., used on ground to approximate time of step climb
            if(gsKTS > 200) then
              nmsc = htsc * gsKTS
            end
            stepTD = string.format("%02d%02dz/ %4.1fNM",hh_sc,mm_sc,nmsc) --"****z /****NM"

          else
            --engines not running
            stepTD="NO ENG PERF"
          end

          fmsModules["data"]["stepalt"] = string.format("FL%03d",(czak+2)*10)

        else --cannot climb above service ceiling
          fmsModules["data"]["stepalt"] = "*****"
          stepTD = "****z /****NM"    
        end
      end

      -- Calculate ETA based on sim time
      local dtogo = dNM 
      local tmnow = hh + mm/60
      local eta = 0
      local fad = 0 --fuel at destination, lbs
      local fuelKg = simDR_fueL_tank_weight_total_kg

      if(simDR_onGround==1) then --on the ground
        if(dtogo > 10) then -- at origin with route set
          eta = tmnow + (18.464 + 0.132 * dtogo) / 60 -- hours
          fad = simDR_fueL_tank_weight_total_kg * 2.205 - dtogo * 51.6 --rough approximation of fuel remaining at dest
          if(fad < 0) then fad = 0 end
        end
      else
        if(dtogo < 10) then -- near origin (0 with no flight plan) , or very near destination
          eta = tmnow -- terminal airspace, therefore now
          fad = simDR_fueL_tank_weight_total_kg * 2.205

        elseif(dtogo < 90) then --near terminal airspace, assume idle thrust
          ttg = dtogo/200 -- avg speed approx 200 kts from TOD to land
          eta = tmnow + ttg
          fad = simDR_fueL_tank_weight_total_kg * 2.205 - ( ttg * 22029/2.5 ) --40% of average enroute fuelage

        elseif(simDR_vvi_fpm_pilot > 500 or simDR_vvi_fpm_pilot < -500) then --climbing or descending
          eta = tmnow + (18.464 + 0.132 * dtogo) / 60 -- hours
          fad = simDR_fueL_tank_weight_total_kg * 2.205 - dtogo * 51.6 -- mean fuel burn 55 pounds per nautical mile

        else --enroute phase of flight
          eta = tmnow + dtogo / gsKTS
          ffkgh = (simDR_eng_fuel_flow_kg_sec[0] + simDR_eng_fuel_flow_kg_sec[1] + simDR_eng_fuel_flow_kg_sec[2] + simDR_eng_fuel_flow_kg_sec[3]) * 3600.0
          
          if(ffkgh ~= nil and ffkgh > 0 and dtogo ~= nil) then
            ff  = math.floor(ffkgh/1000) * 1000 -- fuel flow 
            if(ff < 1000) then ff = 1000 end
            ttg = math.floor( 10 * dtogo / gsKTS ) / 10 --time to go, hh.m
            fad = (simDR_fueL_tank_weight_total_kg - ttg*ff) * 2.205
          else
            fad = simDR_fueL_tank_weight_total_kg * 2.205 - dtogo * 51.6 -- mean fuel burn per NM, fuelplanner.com
          end          

        end
      end

      -- ETA based on sim zulu 
      eta_h = math.floor(eta)
      eta_m = math.ceil( (eta - eta_h) * 60 )
      if(eta_h >= 24) then eta_h = eta_h - 24 end

      --local timestamp = os.time() 
      --local dt1 = os.date( "!%X", timestamp )  -- UTC
      --local utcNow = string.formt("%02f%02f",dt1hour,dt1.min)

      etafuel = string.format("%02d%02dz/ %03.1f",eta_h,eta_m,conv*fad/1000)
      -- ECON, LRC or SEL SPD: a Mach, or a selected CAS
      local mode = vnav_text("crzspdmode")
      local cas, mach = tonumber(fmsModules["data"]["crzcas"]), tonumber(fmsModules["data"]["crzspd"])
      local spdText = cas and string.format("%3d", cas) or "." .. vnav_text("crzspd")
      return{
        vnav_title(spd_title(mode, cas, (not cas) and mach or nil) .. " CRZ", B747DR_ap_flightPhase==2),
      "                        ",
      fmsModules["data"]["crzalt"].."              "..fmsModules["data"]["stepalt"],
      "                        ",
      lr(spdText, stepTD),
      "                        ",
      --pctn1.."    ****z /***.*",
      pctn1.."%       "..etafuel,
      "                        ",
      "ICAO        "..optmax,
      "------------------------",
      lr(mode~="E" and "<ECON" or "", "ENG OUT>"),
      "                        ",
      lr("<RTA PROGRESS", mode~="L" and "LRC>" or "")
      }
    elseif pgNo==3 then 
      --ref FCOM Virgin p.1023, Lease p.822
      fmsFunctionsDefs["VNAV"]["L1"]=nil
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","desspds"}
      fmsFunctionsDefs["VNAV"]["L3"]={"setdata","destrans"}
      fmsFunctionsDefs["VNAV"]["L4"]={"setdata","desrest"}
      fmsFunctionsDefs["VNAV"]["L5"]=fmsModules["data"]["desspdmode"]=="S" and {"vnavspd","des"} or nil
      fmsFunctionsDefs["VNAV"]["L6"]=nil
      fmsFunctionsDefs["VNAV"]["R1"]=nil
      fmsFunctionsDefs["VNAV"]["R3"]=nil
      fmsFunctionsDefs["VNAV"]["R6"]=nil

      if B747DR_ap_vnav_state==2 and simDR_autopilot_vs_status==2 then
	      fmsModules["data"]["fpa"]=string.format("%1.1f",B747DR_ap_fpa)
	      fmsModules["data"]["vb"]=string.format("%1.1f", B747DR_ap_vb)
	      fmsModules["data"]["vs"]=string.format("%4d",simDR_autopilot_vs_fpm*-1) 
      else
	      fmsModules["data"]["fpa"]="*.*"
	      fmsModules["data"]["vb"]="*.*"
	      fmsModules["data"]["vs"]="****"
      end

      local nxtwpt = ""
      local nxtalt = 0
      local lowwpt = ""
      local lowalt = 99999

      if(string.len(fmsJson) > 2) then
        local fms = fms_route()
        if(fms ~= nil and fmsModules["data"]["crzalt"]~="*****" ) then
          n = table.getn(fms)
          
          local currentWP=0
          for i=1,n,1 do
            if(fms[i][10] == true) then -- this is the next waypoint
              -- increment through the fms to find valid waypoint
              currentWP=i
              while((i==1 or string.len(fms[i][8])>5 or tonumber(fms[i][8])~=nil or fms[i][9]>=B747BR_cruiseAlt-500) and ((i+1)<n) ) do
                i = i + 1
              end
              if(nxtwpt == "") then
                nxtwpt = fms[i][8] -- next waypoint from legs page
                nxWpt = nxtwpt
                nxtalt = fms[i][9] -- next waypoint altitude
                nxtspd = "---" --fms[i][4] -- next waypoint speed                
              end
              if(i ~= n and trim1(fms[i][8])~="latlon") then
                lowwpt = fms[i][8] -- waypoint with lowest alt constraint
                lowalt = fms[i][9] -- altitude constraint of that waypoint
              end
            else
              --if(nxtwpt ~= "") then
          
              if( i ~= n and trim1(fms[i][8]) ~= "latlon") then
                x = math.floor(fms[i][9]) 
                if(x > 1 and x < lowalt) then
                  lowwpt = fms[i][8] 
                  lowalt = x
                end
              end
            end

          end

          if B747BR_eod_index>0 and currentWP<=B747BR_eod_index then
            eodWpt=fms[B747BR_eod_index][8]
            eodAlt=fms[B747BR_eod_index][9]
          else
            eodWpt = "*****"
            eodAlt = 0
          end
        end
      end

      if(lowalt == 99999) then lowalt = " " end

      nxtspd = tonumber(fmsModules["data"]["desspd"])
      local dtransalt = tonumber(fmsModules["data"]["desspdtransalt"])
      local dtransspd = tonumber(fmsModules["data"]["destranspd"])
      -- no SPD RESTR (dashes): none (6-1 step 1)
      local drestalt  = tonumber(fmsModules["data"]["desrestalt"]) or -99999
      local drestspd  = tonumber(fmsModules["data"]["desrestspd"]) or dtransspd

      if(nxtalt < dtransalt) then
        nxtspd = dtransspd
      end
      if(nxtalt < drestalt) then
        nxtspd = drestspd
      end
      local edaltText="****"
      local nextAltText="***/*****"
      if eodAlt>0 then
        edaltText=string.format("%4d",eodAlt)
      end
      if nxtalt>0 then
        nextAltText=string.format("%3d",nxtspd).."/"..string.format("%5d",nxtalt)
      end
      local mode = vnav_text("desspdmode")
      return{
        vnav_title(spd_title(mode, tonumber(fmsModules["data"]["desspd"]), tonumber(fmsModules["data"]["desspdmach"])) .. " DES", B747DR_ap_flightPhase==3),
      "                        ",
      --"  **** *****    ***/****",
      " "..edaltText.." "..string.format("%5s",eodWpt).."    "..nextAltText,
      "                        ",
      ".".. fmsModules["data"]["desspdmach"].."/"..fmsModules["data"]["desspd"].."                ",
      "                        ",
      fmsModules["data"]["destranspd"].."/"..fmsModules["data"]["desspdtransalt"].."               ",
      "                        ",
      fmsModules["data"]["desrestspd"].."/"..fmsModules["data"]["desrestalt"].."   "..fmsModules["data"]["fpa"].." "..fmsModules["data"]["vb"].." "..fmsModules["data"]["vs"],
      "------------------------",
      lr(mode=="S" and "<ECON" or "", "FORECAST>"),
      "                        ",
      "OFFPATH DES     DES DIR>"
      

      }
    end
end

-- the speed line's label by its mode
local function spd_label(id)
  local mode = vnav_text(id)
  return mode == "S" and " SEL SPD " or mode == "L" and " LRC SPD " or " ECON SPD"
end

fmsPages["VNAV"].getSmallPage=function(self,pgNo,fmsID)
    if pgNo==1 then
          
      return{
      "                    1/3 ",
      " CRZ ALT        AT "..nxWpt,
      "                        ",
      spd_label("clbspdmode") .. "          ERROR",
      "                        ",
      " SPD TRANS     TRANS ALT",
      "                        ",
      " SPD REST      MAX ANGLE",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    elseif pgNo==2 then 

      return{
      "                    2/3 ",
      " CRZ ALT         STEP TO",
      "                        ",
      spd_label("crzspdmode") .. "             AT",
      "                        ",
      " N1        "..dICAO.." ETA/FUEL",  
      "                        ",
      " STEP SIZE  OPT      MAX",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    elseif pgNo==3 then 
      return{
      "                    3/3 ",
      --" E/D AT         AT *****",
      " E/D AT         AT "..nxWpt,
      "                        ",
      spd_label("desspdmode") .. "               ",
      "                        ",
      " SPD TRANS              ",
      "                        ",
      " SPD REST   FPA V/B  V/S",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    end
end

fmsPages["VNAV"].getNumPages=function(self)
  return 3
end


function getDistance(lat1,lon1,lat2,lon2)
  if lat1==lat2 and lon1==lon2 then return 0 end
  alat=math.rad(lat1)
  alon=math.rad(lon1)
  blat=math.rad(lat2)
  blon=math.rad(lon2)
  av=math.sin(alat)*math.sin(blat) + math.cos(alat)*math.cos(blat)*math.cos(blon-alon)
  if av > 1 then av=1 end
  retVal=math.acos(av) * 3440
  return retVal
end

-- http://lua-users.org/wiki/StringTrim
function trim1(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end