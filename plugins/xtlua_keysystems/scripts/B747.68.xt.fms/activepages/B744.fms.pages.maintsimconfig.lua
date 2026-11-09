fmsPages["MAINTSIMCONFIG"]=createPage("MAINTSIMCONFIG")
-- (2026-11-09) FUEL MGMT: the sim's option "Auto fuel management" (Plugins >
-- 747-400, the FMS bridge's; the fuel module does it), shown here and
-- turned over by L3 (B744.fms.pages.lua's autoFuelMgmt) through the
-- bridge's command, which keeps it; before, the livery's simconfig.dat
-- auto_fuel_mgmt for the previous code's tank helper. Read on each page
-- draw (an XTLua read of another plugin's dataref gives its previous read)
B747DR_opt_auto_fuel = find_dataref("laminar/B747/options/auto_fuel_mgmt")
B747CMD_opt_auto_fuel_toggle = find_command("laminar/B747/options/auto_fuel_mgmt_toggle")
function B747_fms_auto_fuel_on()
	return B747DR_opt_auto_fuel == 1
end
fmsPages["MAINTSIMCONFIG"].getPage=function(self,pgNo,fmsID)
	if pgNo == 1 then
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L1"]={"setdata","weightUnits"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L2"]={"setdata","irsAlignTime"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L3"]={"setdata","autoFuelMgmt"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"]={"setdata","baroIndicator"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L5"]={"setdata","baroSync"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R1"]={"setdata","stdPaxWeight"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R2"]={"setdata","captInbd"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R3"]={"setdata","captLwr"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R4"]={"setdata","foInbd"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R5"]={"setdata","foLwr"}
	    fmsFunctionsDefs["MAINTSIMCONFIG"]["R6"]={"setdata","simConfigSave"}
		local weight_factor = 1
		local display_weight_units = string.format("%-3s", simConfigData["data"].SIM.weight_display_units)
		local irs_align_time = string.format("%-2d", simConfigData["data"].SIM.irs_align_time / 60)  --Mins
		local std_pax_weight = string.format("%5.1f", simConfigData["data"].SIM.std_pax_weight * weight_factor)
		local fuel_mgmt = B747_fms_auto_fuel_on() and "YES" or "NO "
		local capt_inbd_display = string.format("%5s", simConfigData["data"].SIM.capt_inbd)
		local capt_lwr_display = string.format("%9s", simConfigData["data"].SIM.capt_lwr)
		local fo_inbd_display = string.format("%5s", simConfigData["data"].SIM.fo_inbd)
		local fo_lwr_display = string.format("%9s", simConfigData["data"].SIM.fo_lwr)
		local baro_indicator = string.format("%-3s", simConfigData["data"].SIM.baro_indicator)
		local baro_sync = string.format("%-3s", simConfigData["data"].SIM.baro_sync)
		
		if simConfigData["data"].SIM.weight_display_units == "LBS" then
			weight_factor = simConfigData["data"].SIM.kgs_to_lbs
		end

		std_pax_weight = string.format("%5.1f", simConfigData["data"].SIM.std_pax_weight * weight_factor)
		
		return {
		"       SIM CONFIG       ",
		"                        ",
		" "..display_weight_units.."                "..std_pax_weight,
		"                        ",
		" "..irs_align_time.."                 "..capt_inbd_display,
		"                        ",
		" "..fuel_mgmt.."            "..capt_lwr_display,
		"                        ",
		" "..baro_indicator.."                "..fo_inbd_display,
		"                        ",
		" "..baro_sync.."            "..fo_lwr_display,
		"                        ",
		"<MENU              SAVE>"
    }

--silvereagle added to end	
    elseif pgNo == 2 then
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L1"]={"setdata","spillLights"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L2"]={"setdata","cockpitSeatsHide"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L3"]={"setdata","setacarsprovider"}
		-- (6-1/6-2 step 12a) the FMC's datalink: AUTO, ON, OFF; page 1's
		-- other keys off here
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"]={"setdata","fmcDatalink"}
		-- (§131) SimBrief's Pilot ID: the company's flight plan fetched
		-- from SimBrief (the FMS bridge keeps it)
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L5"]={"setdata","simbriefId"}
		for _, k in ipairs({"R1", "R2", "R3", "R4", "R5"}) do fmsFunctionsDefs["MAINTSIMCONFIG"][k]=nil end
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R6"]={"setdata","simConfigSave"}
		local lineA = ""
		if B747DR_fmc_spill_lights==0 then
			lineA = "NORM/  "
		else
			lineA = "    /HI"
		end
		local lineB = ""
		if B747DR_fmc_cockpit_seats_hide==0 then
			lineB = "SHOW/    "
		else
			lineB = "    /HIDE"
		end
		local lineC = "OFFLINE"
		if acars==1 then
			if B747DR_acarsProvider==0 then
				lineC = "AUTOATC"
			elseif B747DR_acarsProvider==1 then
				lineC = "HOPPIE"
			end
		end
		return{
		"       SIM CONFIG       ",
		"                        ",
		"<SPILL LIGHTS    " ..lineA,
		"                        ",
		"<COCKPIT SEATS " ..lineB,
		"                        ",
		"<ACARS           "..lineC,
		"                        ",
		string.format("<FMC DATALINK%11s", B747_fms_datalink_cfg()),
		"                        ",
		string.format("%-24s", (B747DR_simbrief_id or 0) > 0 and tostring(B747DR_simbrief_id) or "--------"),
		"------------------------",
		"<MENU              SAVE>"
		}
--silvereagle end	
		
  elseif pgNo == 3 then --silvereagle
    fmsFunctionsDefs["MAINTSIMCONFIG"]["L1"]={"setDref","VNAVSPAUSE"}
    fmsFunctionsDefs["MAINTSIMCONFIG"]["L2"]={"setDref","PAUSEVAL"}
    fmsFunctionsDefs["MAINTSIMCONFIG"]["L3"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L5"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R1"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R2"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R3"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R4"]=nil
    fmsFunctionsDefs["MAINTSIMCONFIG"]["R5"]=nil
    fmsFunctionsDefs["MAINTSIMCONFIG"]["R6"]=nil
    local LineA="<ENABLE PAUSE AT T/D    "	
    local LineB="<PAUSE AT ***NM TO DEST "	
    if B747DR_ap_vnav_pause ==1.0 then 
        LineA="<DISABLE PAUSE AT T/D   "
        if B747BR_tod>0 then 
          LineB="<PAUSE AT ".. string.format("%03d",B747BR_tod) .."NM TO DEST "
        end
  
    elseif B747DR_ap_vnav_pause >1.0 then 
        LineA="<DISABLE PAUSE          "
        LineB="<PAUSE AT ".. string.format("%03d",B747DR_ap_vnav_pause) .."NM TO DEST "    
    end
    return {
  
    "     CONFIG PAUSE       ",
    "                        ",
    LineA,
    "                        ",
    LineB,
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "                        ",
    "<MENU                   "
    }
	elseif pgNo == 4 then --silvereagle
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L1"]={"setdata","model"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L2"]={"setdata","aircraftType"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L3"]={"setdata","engines"}
	    --fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"]={"setdata","thrustRef"}
    	fmsFunctionsDefs["MAINTSIMCONFIG"]["L5"]=nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R1"]={"setdata","airline"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R2"]={"setdata","civilRegistration"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R3"]={"setdata","finNbr"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R4"]={"setdata","pfdStyle"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R5"]={"setdata","ndStyle"}
    	fmsFunctionsDefs["MAINTSIMCONFIG"]["R6"]={"setdata","simConfigSave"}
		local model = string.format("%-10s", string.sub(simConfigData["data"].PLANE.model, 1, 10))
		local aircraft_type = string.format("%-10s", simConfigData["data"].PLANE.aircraft_type)
		local engines = string.format("%-15s", simConfigData["data"].PLANE.engines)
		local thrust_ref = string.format("%-3s", simConfigData["data"].PLANE.thrust_ref)
		local airline = string.format("%14s", string.sub(simConfigData["data"].PLANE.airline, 1, 14))
		local civil_reg = string.format("%10s", string.sub(simConfigData["data"].PLANE.civil_registration, 1, 10))
		local fin_nbr = string.format("%5s", string.sub(simConfigData["data"].PLANE.fin_nbr,1, 5))
		local pfd_style = string.format("%-3s", simConfigData["data"].PLANE.pfd_style)
		local nd_style = string.format("%-3s", simConfigData["data"].PLANE.nd_style)

		return {
		"      PLANE CONFIG      ",
		"                        ",
		" "..model..""..airline,
		"                        ",
		" "..aircraft_type.."    "..civil_reg,
		"                        ",
		" "..engines.."    "..fin_nbr,
		"                        ",
		" "..thrust_ref.."                  "..pfd_style,
		"                        ",
		"                      "..nd_style,
		"                        ",
		"<MENU              SAVE>"
		}


	elseif pgNo == 5 then --silvereagle

		-- SOUND OPTIONS (CRAZYTIMTIMTIM + MATT726)

		fmsFunctionsDefs["MAINTSIMCONFIG"]["L1"]={"setpage","MISCSOUNDCONFIG"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L2"]={"setpage","PASSENGERSOUNDCONFIG"}
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L3"]={"setpage","GPWSSOUNDCONFIG"}
		--fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"]={"setpage","VOLUME"}

		fmsFunctionsDefs["MAINTSIMCONFIG"]["R1"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R2"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R3"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R4"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R5"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["R6"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L4"] = nil
		fmsFunctionsDefs["MAINTSIMCONFIG"]["L5"] = nil

		return{
		"      SOUND CONFIG      ",
		"                        ",
		"<GENERAL                ",
		"                        ",
		"<PASSENGERS             ",
		"                        ",
		"<GPWS CALLOUTS          ",
		"                        ",
		"<VOLUME (INOP.)         ",
		"                        ",
		"                        ",
		"------------------------",
		"<MENU                   "
		}

	end
end

fmsPages["MAINTSIMCONFIG"].getSmallPage=function(self,pgNo,fmsID)
	if pgNo == 1 then
		local display_weight_units = "KGS"
		local fuel_mgmt = "NO"
		local baro_indicator = "IN"
		local baro_sync = "NO"
		
		if simConfigData["data"].SIM.weight_display_units == "KGS" then
			display_weight_units = "/LBS"
		else
			display_weight_units = "/KGS"
		end

		if not B747_fms_auto_fuel_on() then
			fuel_mgmt = "/YES"
		else
			fuel_mgmt = "/NO "
		end

		if simConfigData["data"].SIM.baro_indicator == "IN" then
			baro_indicator = "/HPA"
		else
			baro_indicator = "/IN "
		end

		if simConfigData["data"].SIM.baro_sync == "NO" then
			baro_sync = "/YES"
		else
			baro_sync = "/NO "
		end

		return {
		"                     1/5", --silvereagle
		" WGT UNITS    STD PAX WGT",
		"<    "..display_weight_units,
		" IRS ALIGN      CAPT INBD",
		"    MINS                 >",
		" FUEL MGMT(X)   CAPT  LWR",
		"<    "..fuel_mgmt.."                >",
		" BARO INDICATOR   FO INBD",
		"<    "..baro_indicator.."                >",
		" BARO SYNC        FO  LWR",
		"<    "..baro_sync.."                >",
		"                        ",
		"                        "
    }

--silvereagle added to end	
	elseif pgNo == 2 then
		if B747DR_fmc_spill_lights==0 then	
			lineA = "                      HI"
		else
			lineA = "                 NORM   "
		end
		if B747DR_fmc_cockpit_seats_hide==0 then				
			lineB = "                    HIDE"			
		else
			lineB = "               SHOW     "		
		end

	return{
		"                     2/5",
		"                        ",
		lineA,
		"                        ",
		lineB,
		"                        ",
		"                        ",
		string.format(" ATC, FMC COMM%10s", B747_fms_datalink() and "ACTIVE" or "INOP"),
		"                        ",
		" SIMBRIEF PILOT ID      ",
		"                        ",
		"                        ",
		"                        "
		}
--silvereagle end	
		
  elseif pgNo == 3 then --silvereagle
    return {
      "                     3/5", --silvereagle
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
	elseif pgNo == 4 then --silvereagle
		local thrust_ref = "EPR"
		
		if simConfigData["data"].PLANE.thrust_ref == "EPR" then
			thrust_ref = "/N1 "
		else
			thrust_ref = "/EPR"
		end
		
		return {
		"                     4/5",
		" MODEL            AIRLINE",
		"                        ",
		" TYPE           CIVIL REG",
		"<                        ",
		" ENGINES          FIN NBR",
		"<                        ",
		" THRUST REF     PFD STYLE",
		"     "..thrust_ref       .."                >",
		"              (X)ND STYLE",
		"                         >",
		"                        ",
		"                        "
		}

	elseif pgNo == 5 then --silvereagle

		return {
			"                     5/5",
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
		
	end
end

fmsPages["MAINTSIMCONFIG"].getNumPages=function(self)
  return 5
end
fmsFunctionsDefs["MAINTSIMCONFIG"]["L6"]={"setpage","INDEX"}
