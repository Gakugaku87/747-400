simDR_GRWT=find_dataref("sim/flightmodel/weight/m_total")
simDR_fuel=find_dataref("sim/flightmodel/weight/m_fuel_total")
--simDR_payload=find_dataref("sim/flightmodel/weight/m_fixed")
--simDR_fuel_tanks=find_dataref("sim/flightmodel/weight/m_fuel") --res on 5 and 6
--simDR_cg=find_dataref("sim/flightmodel/misc/cgz_ref_to_default")

--Marauder28
grwt_lineLg = ""
grwt_lineSm = ""
crzcg_lineLg = ""
crzcg_lineSm = ""
--Marauder28

fmsPages["PERFINIT"]=createPage("PERFINIT")
-- PERF INIT (6-1/6-2 step 3a; FCOM p.1307-1312). The weights in thousands
-- of the display units (kilograms or pounds), kept in thousands of
-- kilograms. GR WT or ZFW is entered, the other follows from the FUEL line
-- (an entered GR WT is kept as the ZFW it gives, so that it goes down as
-- the fuel burns); FUEL: the totalizer's (CALC) or an entry (MANUAL, which
-- can be deleted). Entered values in large font, the FMC's in small
-- (estimate for the computed GR WT and ZFW).
function perf_lbs()
	return simConfigData["data"].SIM.weight_display_units == "LBS"
end
-- thousands of the display units from thousands of kilograms, and back
function perf_out(t)
	if perf_lbs() then return t * simConfigData["data"].SIM.kgs_to_lbs end
	return t
end
function perf_in(v)
	if perf_lbs() then return v / simConfigData["data"].SIM.kgs_to_lbs end
	return v
end
-- the FUEL line in thousands of kilograms: the entry, else the totalizer's
function perf_fuel_t()
	local m = tonumber(fmsModules["data"].fuelman)
	if m then return m end
	return simDR_fuel / 1000
end
-- the zero fuel weight and the gross weight, thousands of kilograms; nil
-- before an entry
function perf_zfw_t()
	return tonumber(fmsModules["data"].zfw)
end
function perf_gw_t()
	local z = perf_zfw_t()
	if z == nil then return nil end
	return z + perf_fuel_t()
end
-- each frame: the GR WT kept with the fuel (other pages read it)
function update_perf()
	local gw = perf_gw_t()
	local s = gw and string.format("%5.1f", gw) or "***.*"
	if string.sub(fmsModules["data"].grwt, 1, 5) ~= s then fmsModules:setData("grwt", s) end
end
local function weight_text(t)
	if t == nil then return "***.*" end
	return string.format("%5.1f", perf_out(t))
end

fmsPages["PERFINIT"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
	local src = str_trim(fmsModules["data"].gwsrc)
	local gw, zfw = perf_gw_t(), perf_zfw_t()
	-- large: the entered one of GR WT and ZFW, FUEL, RESERVES, COST INDEX
	local gwL = (src == "GW" or gw == nil) and weight_text(gw) or "     "
	local zfwL = (src == "ZFW" or zfw == nil) and weight_text(zfw) or "     "
	local rsv = tonumber(fmsModules["data"].reserves)
	local rsvL = rsv and string.format("%5.1f", perf_out(rsv)) or "***.*"
	local crzcgV = tonumber(fmsModules["data"].crzcg) or 20.0
	if string.len(crzcg_lineLg) < 1 then
		crzcg_lineSm = string.format("%5.1f%%", crzcgV)
	else
		crzcg_lineLg = string.format("%5.1f%%", crzcgV)
		crzcg_lineSm = ""
	end
	local jet_weightV=simDR_m_jettison/1000
	local jet_weight="     "
	if jet_weightV>0 then jet_weight=string.format("%5.1f",perf_out(jet_weightV)) end
	return{
 "       PERF INIT        ",
 "                        ",
 gwL.."              "..fmsModules["data"]["crzalt"],
 "                        ",
 string.format("%5.1f", perf_out(perf_fuel_t())).."              "..jet_weight,
 "                        ",
 zfwL.."                   ",
 "                        ",
 rsvL.."              "..string.format("%-5s", crzcg_lineLg),
 "                        ",
 string.format("%-4s", str_trim(fmsModules["data"]["costindex"])).."                "..string.format("%4s", str_trim(fmsModules["data"].stepsize)),
 "                        ",
 "<INDEX       THRUST LIM>"
	}
end
fmsPages["PERFINIT"].getSmallPage=function(self,pgNo,fmsID)
	local src = str_trim(fmsModules["data"].gwsrc)
	local gw, zfw = perf_gw_t(), perf_zfw_t()
	-- small: the computed one of GR WT and ZFW, FUEL's source
	local gwS = (src ~= "GW" and gw ~= nil) and weight_text(gw) or "     "
	local zfwS = (src ~= "ZFW" and zfw ~= nil) and weight_text(zfw) or "     "
	local fuelSrc = tonumber(fmsModules["data"].fuelman) and "MANUAL" or "CALC  "
	local lineA=" FUEL                   "
	if simDR_m_jettison>0 then
		lineA=" FUEL         RETARDANT "
	end
	return{
	  "                        ",
	  " GR WT           CRZ ALT",
	  gwS.."                   ",
	  lineA,
	  "      "..fuelSrc.."            ",
	  " ZFW                    ",
	  zfwS.."                   ",
	  " RESERVES         CRZ CG",
	  "                   "..crzcg_lineSm,
	  " COST INDEX    STEP SIZE",
	  "                        ",
	  "------------------------",
	  "                        "
	}
end

fmsFunctionsDefs["PERFINIT"]={}


fmsFunctionsDefs["PERFINIT"]["L1"]={"setdata","grwt"}
fmsFunctionsDefs["PERFINIT"]["L2"]={"setdata","fuel"}
fmsFunctionsDefs["PERFINIT"]["L3"]={"setdata","zfw"}
fmsFunctionsDefs["PERFINIT"]["L4"]={"setdata","reserves"}
fmsFunctionsDefs["PERFINIT"]["L5"]={"setdata","costindex"}
fmsFunctionsDefs["PERFINIT"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["PERFINIT"]["R1"]={"setdata","crzalt"}
fmsFunctionsDefs["PERFINIT"]["R4"]={"setdata","crzcg"}
fmsFunctionsDefs["PERFINIT"]["R5"]={"setdata","stepsize"}
fmsFunctionsDefs["PERFINIT"]["R6"]={"setpage","THRUSTLIM"}
