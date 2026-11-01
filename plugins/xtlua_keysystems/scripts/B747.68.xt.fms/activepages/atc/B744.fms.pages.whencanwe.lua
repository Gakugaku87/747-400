-- WHEN CAN WE EXPECT (6-1/6-2 step 12g3a; FCOM p.769-770; FMSPG
-- p.319-323; B747.68.atc_request_model.lua's "WCW" request through the
-- FMS's B747_fms_atc_draft: one in the FMC, both CDUs'): 1L CRZ CLB TO,
-- 2L CLIMB TO, 3L DESCENT TO (an altitude), 2R HIGHER ALT>, 3R LOWER ALT>
-- (one of these five, the others blank), 4L SPEED, 4R BACK ON RTE>; a
-- selection large once selected; <ERASE WHEN CAN WE with something; 6L
-- <INDEX, 6R VERIFY> (VERIFY REQUEST with 6L <WHEN CAN WE). Nothing
-- changed while the query is SENDING. Before, the page wrote FMS data
-- fields without checks and its own VERIFY page wrote the shared text
-- while drawing (CDU-34).
local Q = B747_atc_request_model
local BLANK = "                        "
local function blank13()
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  return out
end
local function put(line, col, text)
  if text == nil or text == "" then return line end
  return string.sub(string.sub(line, 1, col - 1) .. text .. string.sub(line, col + #text), 1, 24)
end
local function left(line, text) return put(line, 1, text) end
local function right(line, text) return put(line, 25 - #text, text) end
local function dr() return B747_fms_atc_draft("WCW") end
local function ias(s) return s and string.sub(s, 1, 1) ~= "." end

fmsPages["WHENCANWE"]=createPage("WHENCANWE")
fmsPages["WHENCANWE"].getPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  out[1] = put(BLANK, 4, "WHEN CAN WE EXPECT")
  if Q.can(r, "wcw_crz") then out[3] = left(BLANK, r.wcw_crz or "-----") end
  if Q.can(r, "wcw_clb") then out[5] = left(BLANK, r.wcw_clb or "-----") end
  if Q.can(r, "wcw_des") then out[7] = left(BLANK, r.wcw_des or "-----") end
  out[9] = left(BLANK, r.wcw_spd or "---")
  if r.wcw_higher then out[5] = right(out[5], "HIGHER ALT") end
  if r.wcw_lower then out[7] = right(out[7], "LOWER ALT") end
  if r.wcw_back then out[9] = right(out[9], "BACK ON RTE") end
  if Q.any(r) then out[11] = left(BLANK, "<ERASE WHEN CAN WE") end
  out[13] = "<INDEX           VERIFY>"
  return out
end
fmsPages["WHENCANWE"].getSmallPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  if Q.can(r, "wcw_crz") then out[2] = left(BLANK, " CRZ CLB TO") end
  if Q.can(r, "wcw_clb") then out[4] = left(BLANK, " CLIMB TO") end
  if Q.can(r, "wcw_des") then out[6] = left(BLANK, " DESCENT TO") end
  out[8] = left(BLANK, " SPEED")
  if ias(r.wcw_spd) then out[9] = put(BLANK, 1 + #r.wcw_spd, "KT") end
  if Q.can(r, "wcw_higher") and not r.wcw_higher then out[5] = right(BLANK, "HIGHER ALT>") end
  if Q.can(r, "wcw_lower") and not r.wcw_lower then out[7] = right(BLANK, "LOWER ALT>") end
  if not r.wcw_back then out[9] = right(out[9], "BACK ON RTE>") end
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["WHENCANWE"]={}
fmsFunctionsDefs["WHENCANWE"]["L1"]={"atcwcw","wcw_crz"}
fmsFunctionsDefs["WHENCANWE"]["L2"]={"atcwcw","wcw_clb"}
fmsFunctionsDefs["WHENCANWE"]["L3"]={"atcwcw","wcw_des"}
fmsFunctionsDefs["WHENCANWE"]["L4"]={"atcwcw","wcw_spd"}
fmsFunctionsDefs["WHENCANWE"]["L5"]={"atcwcw","erase"}
fmsFunctionsDefs["WHENCANWE"]["L6"]={"setpage","ATCINDEX"}
fmsFunctionsDefs["WHENCANWE"]["R2"]={"atcwcw","wcw_higher"}
fmsFunctionsDefs["WHENCANWE"]["R3"]={"atcwcw","wcw_lower"}
fmsFunctionsDefs["WHENCANWE"]["R4"]={"atcwcw","wcw_back"}
fmsFunctionsDefs["WHENCANWE"]["R6"]={"atcwcw","verify"}
local SELECTION = {wcw_higher = true, wcw_lower = true, wcw_back = true}
function fmsFunctions.atcwcw(fmsO, value)
  if value == "verify" then
    B747_fms_atc_verify_req(fmsO.id, "WCW", "WHEN CAN WE")
    fmsFunctions.setpage(fmsO, "ATCVERIFYREQUEST")
    return
  end
  -- not while the query is SENDING (FMSPG p.320)
  if B747_fms_atc_req_sending("WCW") then return end
  local r = dr()
  if value == "erase" then
    if Q.any(r) then Q.erase(r) end
    return
  end
  local sp = fmsO["scratchpad"]
  local err
  if sp == "DELETE" then
    err = Q.delete(r, value)
  elseif SELECTION[value] then
    if sp ~= "" then err = Q.INVALID else err = Q.select(r, value) end
  elseif sp == "" then
    return
  else
    err = Q.enter(r, value, sp, B747_fms_atc_present_ft())
  end
  if err then fmsO["notify"] = err return end
  if sp ~= "" then fmsO["scratchpad"] = "" end
end
