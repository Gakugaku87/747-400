-- THRUST LIM (6-1/6-2 step 9g2; FCOM p.1313-1316, p.1338-1340; ATA34_2
-- p.535-536): on the ground or while the takeoff's limit is active (its
-- form, ATA34_2 p.535): SEL and OAT, the selected mode (D-: the assumed
-- temperature's, step 9g3) and its limit; <TO, TO 1's and TO 2's derates
-- (<-8 %: B747_fms_thrlim_pct) with <SEL>, CLB, CLB 1, CLB 2 with <ARM>
-- at the armed climb; INDEX, TAKEOFF. In the air after it: the active mode
-- and its limit, <GA, <CON, <CRZ, CLB, CLB 1, CLB 2 with <SEL> at the
-- active one; INDEX, APPROACH. The limit the EEC's reference for the
-- FMC's mode (B747.68.thrlim_model.lua), the A/T's target bug (step 9g4:
-- always the limit; the EICAS's cursor may be the FMC's target). Before: TO-1 style titles, the
-- A/T's target bug (0.90 in a descent), nothing in the air, <GA, <CON and
-- <CRZ on the takeoff's keys (ATHR-02)
B747DR_thrlim_epr_ref = find_dataref("sim/cockpit2/engine/actuators/EPR_target_bug")
B747DR_thrlim_n1_ref = find_dataref("sim/cockpit2/engine/actuators/N1_target_bug")
simDR_OAT=find_dataref("sim/weather/temperature_ambient_c")

fmsPages["THRUSTLIM"]=createPage("THRUSTLIM")
fmsFunctionsDefs["THRUSTLIM"]={}
fmsFunctionsDefs["THRUSTLIM"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["THRUSTLIM"]["R2"]={"setDref","CLB"}
fmsFunctionsDefs["THRUSTLIM"]["R3"]={"setDref","CLB1"}
fmsFunctionsDefs["THRUSTLIM"]["R4"]={"setDref","CLB2"}

local SEL, ARM, NONE = "<SEL>", "<ARM>", "     "
local function epr() return simConfigData["data"].PLANE.thrust_ref == "EPR" end
-- the mode and its unit ("TO 1 EPR"), the limit ("1.42", "101.6%")
local function thrlim_title()
  return B747_thrlim_model.label(B747_fms_thrlim()) .. (epr() and " EPR" or " N1")
end
local function thrlim_value()
  if epr() then return string.format("%4.2f", B747DR_thrlim_epr_ref[0]) end
  return string.format("%5.1f%%", B747DR_thrlim_n1_ref[0])
end
-- the takeoff's form: on the ground or the takeoff's limit active
local function takeoff_form()
  return simDR_onGround == 1 or B747_fms_thrlim().mode == "TO"
end
-- a row: the left item with its mark, the right's mark and item (FCOM
-- p.1314: "<-8 % <SEL> <ARM> CLB 1>")
local function row(left, lmark, rmark, right)
  return string.format("%-6s%s %s %6s", left, lmark, rmark, right)
end
-- a derate's left item ("<-8 %")
local function derate(n) return string.format("<-%d %%", B747_fms_thrlim_pct(n)) end

fmsPages["THRUSTLIM"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  local s = B747_fms_thrlim()
  local defs = fmsFunctionsDefs["THRUSTLIM"]
  if takeoff_form() then
    defs["L1"]={"setdata","thrustsel"}
    defs["L2"]={"setDref","TO"}
    defs["L3"]={"setDref","TO1"}
    defs["L4"]={"setDref","TO2"}
    defs["R6"]={"setpage","TAKEOFF"}
    -- SEL large (in F with an F entry: step 3b)
    local selC = tonumber(fmsModules["data"]["thrustsel"])
    local inF = str_trim(fmsModules["data"]["selunit"]) == "F"
    local selText = ""
    if selC then
      selText = inF and (str_trim(fmsModules["data"]["thrustself"]) .. "`F") or string.format("%d`C", selC)
    end
    local function to(n) return s.to == n and SEL or NONE end
    local function arm(n) return s.clb == n and ARM or NONE end
    return {
"       THRUST LIM       ",
"                        ",
string.format("%-24s", selText),
"                        ",
row("<TO", to(0), arm(0), "CLB>"),
"                        ",
row(derate(1), to(1), arm(1), "CLB 1>"),
"                        ",
row(derate(2), to(2), arm(2), "CLB 2>"),
"                        ",
"                        ",
"------------------------",
"<INDEX          TAKEOFF>"
    }
  end
  defs["L1"]=nil
  defs["L2"]={"setDref","GA"}
  defs["L3"]={"setDref","CON"}
  defs["L4"]={"setDref","CRZ"}
  defs["R6"]={"setpage","APPROACH"}
  local function act(mode) return s.mode == mode and SEL or NONE end
  local function clb(n) return (s.mode == "CLB" and s.clb == n) and SEL or NONE end
  return {
"       THRUST LIM       ",
"                        ",
"                        ",
"                        ",
row("<GA", act("GA"), clb(0), "CLB>"),
"                        ",
row("<CON", act("CON"), clb(1), "CLB 1>"),
"                        ",
row("<CRZ", act("CRZ"), clb(2), "CLB 2>"),
"                        ",
"                        ",
"------------------------",
"<INDEX         APPROACH>"
  }
end
fmsPages["THRUSTLIM"].getSmallPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  if takeoff_form() then
    -- the OAT (in F with an F SEL) and the limit small (step 3b)
    local inF = str_trim(fmsModules["data"]["selunit"]) == "F"
    local oat = inF and math.floor(simDR_OAT * 9 / 5 + 32 + 0.5) or math.floor(simDR_OAT + 0.5)
    return {
"                        ",
string.format(" SEL      OAT%11s", thrlim_title()),
string.format("          %-5s%9s", string.format("%d`%s", oat, inF and "F" or "C"), thrlim_value()),
"                        ",
"                        ",
" TO 1                   ",
"                        ",
" TO 2                   ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        "
    }
  end
  return {
"                        ",
string.format("%24s", thrlim_title()),
string.format("%24s", thrlim_value()),
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
fmsPages["THRUSTLIM"]["templateSmall"]={
"                        ",
" SEL      OAT D-TO 1 N1 ",
"                        ",
"                        ",
"                        ",
" TO 1                   ",
"                        ",
" TO 2                   ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        "
}
