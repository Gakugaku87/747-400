-- BITE REPORT (6-1/6-2 step 12c2; ATA34_2 p.684-685): the FMC's BITE
-- history to the data loader. The title the CDU's FMC (the one <FMC
-- connects it to: L without one); DATA LOADER's caret only on the ground
-- with the data loader selected to that FMC, powered and its disk in: the
-- airplane here has no data loader, so no caret and 1L does nothing (the
-- text in its place: estimate)
fmsPages["MAINTBITE"]=createPage("MAINTBITE")
fmsPages["MAINTBITE"].getPage=function(self,pgNo,fmsID)
  local side = B747_fms_fmc_available(fmsID) == 2 and "R" or "L"
  return {
"   FMC " .. side .. " BITE REPORT    ",
"                        ",
" DATA LOADER            ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"                        ",
"------------------------",
"<INDEX                  "
  }
end

fmsFunctionsDefs["MAINTBITE"]={}
fmsFunctionsDefs["MAINTBITE"]["L6"]={"setpage","MAINT"}
