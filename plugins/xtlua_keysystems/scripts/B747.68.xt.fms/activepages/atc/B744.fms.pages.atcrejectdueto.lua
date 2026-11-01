-- REJECT DUE TO (6-1/6-2 step 12f; FCOM p.762-763; FMSPG p.290): the
-- reasons for an uplink's rejection on this CDU (B747_fms_atc_due): 1L DUE
-- TO <PERFORMANCE and 1R DUE TO WEATHER>, small until selected (then large:
-- DUE TO AIRCRAFT PERFORMANCE, DUE TO WEATHER in the response), lines 2 to
-- 5 the free text (a caret on the first empty one; DELETE clears a line),
-- 6L <UPLINK, 6R VERIFY> (VERIFY RESPONSE with UNABLE or NEGATIVE). Before:
-- a fixed page, not loaded
fmsPages["ATCREJECTDUETO"]=createPage("ATCREJECTDUETO")
local BLANK = "                        "
local function free_rows(d)
  local rows, caret = {}, false
  for k = 1, 4 do
    local f = d.free[k]
    if f ~= "" then
      rows[k] = string.format("%-24s", f)
    elseif not caret then
      rows[k], caret = "<                       ", true
    else
      rows[k] = BLANK
    end
  end
  return rows
end
fmsPages["ATCREJECTDUETO"].getPage=function(self,pgNo,fmsID)
  local d = B747_fms_atc_due(fmsID)
  local rows = free_rows(d)
  local perf = d.perf and "<PERFORMANCE" or ""
  local wx = d.wx and "WEATHER>" or ""
  return {
"     REJECT DUE TO      ",
BLANK,
perf .. string.rep(" ", 24 - #perf - #wx) .. wx,
BLANK,
rows[1],
BLANK,
rows[2],
BLANK,
rows[3],
BLANK,
rows[4],
BLANK,
"<UPLINK          VERIFY>"
  }
end
fmsPages["ATCREJECTDUETO"].getSmallPage=function(self,pgNo,fmsID)
  local d = B747_fms_atc_due(fmsID)
  local perf = d.perf and "" or "<PERFORMANCE"
  local wx = d.wx and "" or "WEATHER>"
  return {
"                    1/1 ",
" DUE TO           DUE TO",
perf .. string.rep(" ", 24 - #perf - #wx) .. wx,
" FREE TEXT              ",
BLANK,
BLANK,
BLANK,
BLANK,
BLANK,
BLANK,
BLANK,
"------------------------",
BLANK
  }
end
fmsFunctionsDefs["ATCREJECTDUETO"]={}
fmsFunctionsDefs["ATCREJECTDUETO"]["L1"]={"atcdueto","perf"}
fmsFunctionsDefs["ATCREJECTDUETO"]["R1"]={"atcdueto","wx"}
fmsFunctionsDefs["ATCREJECTDUETO"]["L2"]={"atcdueto","1"}
fmsFunctionsDefs["ATCREJECTDUETO"]["L3"]={"atcdueto","2"}
fmsFunctionsDefs["ATCREJECTDUETO"]["L4"]={"atcdueto","3"}
fmsFunctionsDefs["ATCREJECTDUETO"]["L5"]={"atcdueto","4"}
fmsFunctionsDefs["ATCREJECTDUETO"]["L6"]={"setpage","ATCUPLINK"}
fmsFunctionsDefs["ATCREJECTDUETO"]["R6"]={"atcdueto","verify"}
function fmsFunctions.atcdueto(fmsO, value)
  local d = B747_fms_atc_due(fmsO.id)
  local sp = fmsO["scratchpad"]
  if value == "perf" then
    d.perf = not d.perf
  elseif value == "wx" then
    d.wx = not d.wx
  elseif value == "verify" then
    local v = B747_fms_atc_verify(fmsO.id)
    if v and v.kind == "REJECT" then fmsFunctions.setpage(fmsO, "ATCVERIFYRESP") end
  else
    local k = tonumber(value)
    if sp == "" then return end
    if sp == "DELETE" then
      d.free[k] = ""
    else
      d.free[k] = string.sub(sp, 1, 24)
    end
    fmsO["scratchpad"] = ""
  end
end
