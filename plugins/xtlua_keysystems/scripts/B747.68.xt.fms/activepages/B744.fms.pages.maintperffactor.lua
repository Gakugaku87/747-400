-- PERF FACTORS (6-1/6-2 step 12c1; FMSPG p.265-268; ATA34_2 p.678-679,
-- p.681): the FMC's performance factors (B747.68.perf_factors_model.lua,
-- kept in the simconfig: B747_fms_perf_factors), the page's form FMSPG
-- p.265's. A static display until ARM is entered at 6R (ATA34_2 p.679:
-- 6R shows --- before, ARM after: the two sources' figures); leaving the
-- page deletes it (FMSPG p.268). PERF CODE and OPTION CODE are not
-- entries (ATA34_2 p.679); a DELETE is not either (FMSPG p.266 for TO 1/
-- TO 2; the others an estimate). An entry before ARM: INVALID ENTRY
-- (estimate)
fmsPages["MAINTPERFFACTOR"]=createPage("MAINTPERFFACTOR")
-- each CDU's ARM
local armed = {}
fmsPages["MAINTPERFFACTOR"].getPage=function(self,pgNo,fmsID)
  local t = B747_perf_factors_model.text(B747_fms_perf_factors())
  return {
"      PERF FACTORS      ",
"                        ",
"1111        000001004806",
"                        ",
string.format("%-12s%12s", t.dragff, t.rc_clb),
"                        ",
string.format("%7s%17s", t.derates, t.thrcrz),
"                        ",
string.format("%-12s%12s", t.mnvr, t.thrred),
"                        ",
string.format("%-12s%12s", t.mincrz, t.accel),
"------------------------",
string.format("<INDEX%18s", armed[fmsID] and "ARM" or "---")
  }
end
fmsPages["MAINTPERFFACTOR"].getSmallPage=function(self,pgNo,fmsID)
  return {
"                        ",
" PERF CODE   OPTION CODE",
"                        ",
" DRAG/F-F        R/C CLB",
"                        ",
" TO 1/TO 2       THR/CRZ",
"                        ",
" MNVR MARGIN     THR RED",
"                        ",
" MIN CRZ TIME   ACCEL HT",
"                        ",
"                        ",
"                        "
  }
end
fmsPages["MAINTPERFFACTOR"].onLeave=function(self,fmsID)
  armed[fmsID] = nil
end

fmsFunctionsDefs["MAINTPERFFACTOR"]={}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L1"]={"perffactor","perfcode"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L2"]={"perffactor","dragff"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L3"]={"perffactor","derates"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L4"]={"perffactor","mnvr"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L5"]={"perffactor","mincrz"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["L6"]={"setpage","MAINT"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R1"]={"perffactor","option"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R2"]={"perffactor","rc_clb"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R3"]={"perffactor","thrcrz"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R4"]={"perffactor","thrred"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R5"]={"perffactor","accel"}
fmsFunctionsDefs["MAINTPERFFACTOR"]["R6"]={"perffactor","arm"}
function fmsFunctions.perffactor(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  if value == "arm" then
    if sp ~= "ARM" then fmsO["notify"] = "INVALID ENTRY" return end
    armed[fmsO.id] = true
    fmsO["scratchpad"] = ""
    return
  end
  if value == "perfcode" or value == "option" or not armed[fmsO.id] then
    fmsO["notify"] = "INVALID ENTRY"
    return
  end
  local err = B747_fms_perf_factors_enter(value, sp)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end
