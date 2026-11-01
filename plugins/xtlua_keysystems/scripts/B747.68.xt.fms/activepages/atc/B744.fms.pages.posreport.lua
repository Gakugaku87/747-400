-- XXXX POS REPORT (6-1/6-2 step 12g3b; FCOM p.766-768; FMSPG p.340-343;
-- B747.68.atc_posrep_model.lua through the FMS's B747_fms_posrep): the
-- title the flight number's; LAST and ATA, ALT, TEMP, WIND, FUEL the FMC's;
-- TO, NEXT (a position: B747_fmc_with_fix), SPD, ETA, DEST ETA the FMC's
-- or the crew's (DELETE: the FMC's again; SPD's back when the page is
-- left); COMPANY <SEND and ATC SEND> (SENDING, RESEND, NO ATC COMM, NO
-- COMM). Estimates: the WIND's column; IAS as 290KT; the ATC side's DATA
-- LINK header not shown (the line holds COMPANY and ATC). Before, the page
-- wrote the shared text while drawing (CDU-34), from the old ND's
-- waypoints, and its SEND went to ATC REPORT
local P = B747_atc_posrep_model
local BLANK = "                        "
local function put(line, col, text)
  if text == nil or text == "" then return line end
  return string.sub(string.sub(line, 1, col - 1) .. text .. string.sub(line, col + #text), 1, 24)
end
local function left(line, text) return put(line, 1, text) end
local function right(line, text) return put(line, 25 - #text, text) end
local function lr(l, r) return right(left(BLANK, l), r) end

fmsPages["POSREPORT"]=createPage("POSREPORT")
fmsPages["POSREPORT"].getPage=function(self,pgNo,fmsID)
  local s = P.display(B747_fms_posrep_values())
  local flt = str_trim(getFMSData("fltno") or "")
  if flt == "" or string.find(flt, "^%-") then flt = "" else flt = flt .. " " end
  local title = flt .. "POS REPORT"
  local out = {}
  out[1] = put(BLANK, math.max(1, math.floor((24 - #title) / 2) + 1), title)
  out[2] = BLANK
  out[3] = lr(s.last, s.ata)
  out[4] = BLANK
  out[5] = lr(s.alt, s.spd)
  out[6] = BLANK
  out[7] = lr(s.to, s.eta)
  out[8] = BLANK
  out[9] = lr(s.nxt, s.dest_eta)
  out[10] = BLANK
  out[11] = right(put(left(BLANK, s.temp), 7, s.wind), s.fuel)
  out[12] = BLANK
  local co, atc = B747_fms_posrep_status("COMPANY"), B747_fms_posrep_status("ATC")
  co = (co == "SEND" or co == "RESEND") and ("<" .. co) or co
  atc = (atc == "SEND" or atc == "RESEND") and (atc .. ">") or atc
  out[13] = lr(co, atc)
  return out
end
fmsPages["POSREPORT"].getSmallPage=function(self,pgNo,fmsID)
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  out[2] = lr(" LAST", "ATA")
  out[4] = lr(" ALT", "SPD")
  out[6] = lr(" TO", "ETA")
  out[8] = lr(" NEXT", "DEST ETA")
  out[10] = right(put(left(BLANK, " TEMP"), 9, "WIND"), "FUEL")
  out[12] = "COMPANY--------------ATC"
  return out
end
-- SPD's entry gone when the page is left (FCOM p.767)
fmsPages["POSREPORT"].onLeave=function(self,fmsID) P.leave(B747_fms_posrep()) end
fmsFunctionsDefs["POSREPORT"]={}
fmsFunctionsDefs["POSREPORT"]["L3"]={"posrep","to"}
fmsFunctionsDefs["POSREPORT"]["L4"]={"posrep","nxt"}
fmsFunctionsDefs["POSREPORT"]["R2"]={"posrep","spd"}
fmsFunctionsDefs["POSREPORT"]["R3"]={"posrep","eta"}
fmsFunctionsDefs["POSREPORT"]["R4"]={"posrep","dest_eta"}
fmsFunctionsDefs["POSREPORT"]["L6"]={"posrep","COMPANY"}
fmsFunctionsDefs["POSREPORT"]["R6"]={"posrep","ATC"}
function fmsFunctions.posrep(fmsO, value)
  if value == "ATC" or value == "COMPANY" then
    B747_fms_posrep_send(fmsO, value)
    return
  end
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local p = B747_fms_posrep()
  if (value == "to" or value == "nxt") and sp ~= "DELETE" then
    B747_fmc_with_fix(fmsO, sp, nil, function()
      P.enter(B747_fms_posrep(), value, sp)
      fmsO["scratchpad"] = ""
    end)
    return
  end
  local err = P.enter(p, value, sp)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end
