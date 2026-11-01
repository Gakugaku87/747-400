-- MAINTENANCE INDEX (6-1/6-2 step 12c1; FCOM p.1239; FMSPG p.263;
-- ATA34_2 p.676): from INIT/REF INDEX's MAINT> on the ground. Its prompts
-- are used on the ground only (blank in the air: estimate); <INDEX the
-- INIT/REF INDEX page (before: ACMS). The FCOM's labels (<CROSS LOAD,
-- <PERF FACTORS) and the line above <INDEX
fmsPages["MAINT"]=createPage("MAINT")
fmsPages["MAINT"].getPage=function(self,pgNo,fmsID)
  local ground = simDR_onGround == 1
  return {
"   MAINTENANCE INDEX    ",
"                        ",
ground and "<CROSS LOAD        BITE>" or "                        ",
"                        ",
ground and "<PERF FACTORS           " or "                        ",
"                        ",
ground and "<IRS MONITOR            " or "                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"------------------------",
"<INDEX                  "
  }
end

fmsFunctionsDefs["MAINT"]={}
fmsFunctionsDefs["MAINT"]["L1"]={"maintpage","MAINTCROSSLOAD"}
fmsFunctionsDefs["MAINT"]["L2"]={"maintpage","MAINTPERFFACTOR"}
fmsFunctionsDefs["MAINT"]["L3"]={"maintpage","MAINTIRSMONITOR"}
fmsFunctionsDefs["MAINT"]["R1"]={"maintpage","MAINTBITE"}
fmsFunctionsDefs["MAINT"]["L6"]={"setpage","INITREF"}
-- a maintenance page, on the ground
function fmsFunctions.maintpage(fmsO, value)
  if simDR_onGround ~= 1 then return end
  fmsFunctions.setpage(fmsO, value)
end
