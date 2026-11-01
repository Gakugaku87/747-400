-- IRS MONITOR (6-1/6-2 step 12c2; FMSPG p.269; ATA34_2 p.682): each
-- IRU's position error rate for the flight in NM/HR (B747_fms_irs_monitor:
-- the change of the IRU's position from the FMC's between the liftoff and
-- the flight's completion, over the flight's time), shown about 45 s
-- after the engines' shutdown, cleared in the air and without the FMCs'
-- power. Blank for an IRU not navigating at either end (estimate). Before:
-- each IRU's alignment status
fmsPages["MAINTIRSMONITOR"]=createPage("MAINTIRSMONITOR")
local function rate(r, i) return (r and r[i]) and string.format("%.1f", r[i]) or "" end
fmsPages["MAINTIRSMONITOR"].getPage=function(self,pgNo,fmsID)
  local r = B747_fms_irs_monitor()
  return {
"      IRS MONITOR       ",
"                        ",
"                        ",
"                        ",
string.format("%-24s", rate(r, 1)),
"                        ",
string.format("%-24s", rate(r, 2)),
"                        ",
string.format("%-24s", rate(r, 3)),
"                        ",
"                        ",
"------------------------",
"<INDEX                  "
  }
end
-- the labels, and NM/HR small after a rate (FMSPG p.269's figure)
fmsPages["MAINTIRSMONITOR"].getSmallPage=function(self,pgNo,fmsID)
  local r = B747_fms_irs_monitor()
  local function unit(i)
    local v = rate(r, i)
    return string.format("%-24s", v == "" and "" or (string.rep(" ", #v) .. "NM/HR"))
  end
  return {
"                        ",
"                        ",
"                        ",
" IRS L                  ",
unit(1),
" IRS C                  ",
unit(2),
" IRS R                  ",
unit(3),
"                        ",
"                        ",
"                        ",
"                        "
  }
end

fmsFunctionsDefs["MAINTIRSMONITOR"]={}
fmsFunctionsDefs["MAINTIRSMONITOR"]["L6"]={"setpage","MAINT"}
