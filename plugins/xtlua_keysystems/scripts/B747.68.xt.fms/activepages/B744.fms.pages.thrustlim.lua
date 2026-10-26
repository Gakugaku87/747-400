simDR_EPR_target_bug		= find_dataref("sim/cockpit2/engine/actuators/EPR_target_bug")
simDR_N1_target_bug			= find_dataref("sim/cockpit2/engine/actuators/N1_target_bug")

thrust_text = ""
to_mode = ""

fmsPages["THRUSTLIM"]=createPage("THRUSTLIM")
simDR_OAT=find_dataref("sim/weather/temperature_ambient_c")
fmsPages["THRUSTLIM"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  local t1="     "
  local t2="     "
  local t3="     "
  if toderate==0 then t1="<SEL>" to_mode="TO" end
  if toderate==1 then t2="<SEL>" to_mode="TO-1" end
  if toderate==2 then t3="<SEL>" to_mode="TO-2" end
  local c1="     "
  local c2="     "
  local c3="     "
  local thrust_ref = 0.0  --string.format("%4.2f", simDR_EPR_target_bug[0])
  
  if simConfigData["data"].PLANE.thrust_ref == "EPR" then
	thrust_ref = string.format("%6.2f", simDR_EPR_target_bug[0])
	thrust_text = "EPR"
  elseif simConfigData["data"].PLANE.thrust_ref == "N1" then
	thrust_ref = string.format("%5.1f", simDR_N1_target_bug[0]).."%"
	thrust_text = "N1"
  end
  
  if simDR_onGround==1 then
    fmsFunctionsDefs["THRUSTLIM"]["R6"]={"setpage","TAKEOFF"}
	  if clbderate==0 then c1="<ARM>" end
	  if clbderate==1 then c2="<ARM>" end
	  if clbderate==2 then c3="<ARM>" end
	  -- SEL large, the OAT (in F with an F SEL) and the takeoff limit small
	  -- (6-1/6-2 step 3b; FCOM p.1314-1315)
	  local selC = tonumber(fmsModules["data"]["thrustsel"])
	  local inF = str_trim(fmsModules["data"]["selunit"]) == "F"
	  local selText = ""
	  if selC then
		selText = inF and (str_trim(fmsModules["data"]["thrustself"]) .. "`F") or string.format("%d`C", selC)
	  end
	  thrust_sel_line = string.format("%-24s", selText)
	  local oat = inF and math.floor(simDR_OAT * 9 / 5 + 32 + 0.5) or math.floor(simDR_OAT + 0.5)
	  thrust_oat_line = string.format("          %-5s%9s", string.format("%d`%s", oat, inF and "F" or "C"), thrust_ref)
	    return{
	"       THRUST LIM       ",
	"                        ",
	thrust_sel_line,
	"                        ",
	"<TO   "..t1.." "..c1.."    CLB>",
	"                        ",
	"<TO 1 "..t2.." "..c2.."  CLB 1>",
	"                        ",
	"<TO 2 "..t3.." "..c3.."  CLB 2>",
	"                        ",
	"                        ",
	"------------------------",
	"<INDEX          TAKEOFF>"
		}
  else
    fmsFunctionsDefs["THRUSTLIM"]["R6"]={"setpage","APPROACH"}
	if clbderate==0 then c1="<SEL>" end
	  if clbderate==1 then c2="<SEL>" end
	  if clbderate==2 then c3="<SEL>" end
	    return{
	"       THRUST LIM       ",
	"                        ",
	"          "..string.format("%02d",simDR_OAT).."`C         ",
	"                        ",
	"<GA         "..c1.."    CLB>",
	"                        ",
	"<CON        "..c2.."  CLB 1>",
	"                        ",
	"<CRZ        "..c3.."  CLB 2>",
	"                        ",
	"                        ", 
	"------------------------",
	"<INDEX         APPROACH>"
		}
  end
end
fmsPages["THRUSTLIM"].getSmallPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
if simDR_onGround==1 then
  return {
"                        ",
--" SEL      OAT D-TO 1 N1 ",
" SEL      OAT  "..string.format("%-6s", to_mode).." "..string.format("%3s", thrust_text),
(thrust_oat_line or "                        "),
"                        ",
"                        ",
"                        ",
"                        ",
"  10%                   ",
"                        ",
"  20%                   ",
"                        ", 
"                        ",
"                        "
}
else
  return {
"                        ",
"          OAT           ",
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
fmsPages["THRUSTLIM"]["templateSmall"]={
"                        ",
" SEL      OAT D-TO 1 N1 ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"  10%                   ",
"                        ",
"  20%                   ",
"                        ", 
"                        ",
"                        "
}

--[[ Only if in the air!
fmsPages["THRUSTLIM"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
    return{
"       THRUST LIM       ",
"                        ",
"             "..fmsModules["data"]["thrustn1"],
"                        ",
"<GA                 CLB>",
"                        ",
"<CON              CLB 1>",
"                        ",
"<CRZ              CLB 2>",
"                        ",
"                        ", 
"------------------------",
"<INDEX         APPROACH>"
         }
end

fmsPages["THRUSTLIM"]["templateSmall"]={
"                        ",
"               CLB 1 N1 ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"  5%                    ",
"                        ",
"  20%                   ",
"                        ", 
"                        ",
"                        "
}

]]

fmsFunctionsDefs["THRUSTLIM"]={}


fmsFunctionsDefs["THRUSTLIM"]["L1"]={"setdata","thrustsel"}
fmsFunctionsDefs["THRUSTLIM"]["L2"]={"setDref","TO"}
fmsFunctionsDefs["THRUSTLIM"]["L3"]={"setDref","TO1"}
fmsFunctionsDefs["THRUSTLIM"]["L4"]={"setDref","TO2"}
fmsFunctionsDefs["THRUSTLIM"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["THRUSTLIM"]["R2"]={"setDref","CLB"}
fmsFunctionsDefs["THRUSTLIM"]["R3"]={"setDref","CLB1"}
fmsFunctionsDefs["THRUSTLIM"]["R4"]={"setDref","CLB2"}
