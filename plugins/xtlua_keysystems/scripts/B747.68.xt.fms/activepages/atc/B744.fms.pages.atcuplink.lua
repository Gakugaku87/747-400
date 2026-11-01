-- XXXXZ ATC UPLINK and VERIFY RESPONSE (6-1/6-2 step 12f; FCOM p.758-765;
-- FMSPG p.288-291; B747.68.atc_uplink_model.lua through the FMS's
-- B747_fms_atc_uplink). The uplink a CDU shows: acarsSystem's current
-- message for it.
-- ATC UPLINK: the title the receipt time, page 1 STATUS at 1R and the text
-- from line 2, CONTINUED while it goes on; the last page STANDBY (4L),
-- REJECT (5L) and ACCEPT (5R) while a response is due, LOG (6R). Shown,
-- the uplink is reviewed (NEW to OPEN or OLD). Not here yet: <REQUEST,
-- LOAD, ARM, REPORT (step 12g and after), PRINT (no printer: blank, an
-- estimate).
-- VERIFY RESPONSE: 1L the response (WILCO, ROGER, AFFIRM, UNABLE, NEGATIVE,
-- STANDBY), the reasons and free text below, RESPONSE SEND> (SENDING,
-- SENT; NO COMM, NO ATC COMM), STATUS ACCEPTED once acknowledged, 6L
-- <UPLINK or <REJECT DUE TO. Estimates: the lines of the text and of the
-- status.
local U = B747_atc_uplink_model
local function hhmm(i)
  local t = B747_fms_atc_msg_field(i, "time") or ""
  return (string.gsub(t, ":", ""))
end
local function lines_of(i) return U.wrap(B747_fms_atc_msg_field(i, "msg") or "", 24) end
local function centre(t) return string.format("%-24s", string.rep(" ", math.floor((24 - #t) / 2)) .. t) end
local BLANK = "                        "

fmsPages["ATCUPLINK"]=createPage("ATCUPLINK")
fmsPages["ATCUPLINK"].getNumPages=function(self,fmsID)
  local i = acarsSystem.getCurrentMessage(fmsID)
  if not B747_fms_atc_uplink(i) then return 1 end
  return U.pages(lines_of(i))
end
fmsPages["ATCUPLINK"].getPage=function(self,pgNo,fmsID)
  local i = acarsSystem.getCurrentMessage(fmsID)
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  local s = B747_fms_atc_uplink(i)
  if not s then
    out[1] = centre("ATC UPLINK")
    out[13] = string.format("%24s", "LOG>")
    return out
  end
  B747_fms_atc_review(i)
  s = B747_fms_atc_uplink(i)
  local lines = lines_of(i)
  local np = U.pages(lines)
  out[1] = centre(hhmm(i) .. "Z ATC UPLINK")
  if pgNo == 1 then out[3] = string.format("%24s", U.status(s)) end
  local first, text, more = U.page_lines(lines, pgNo)
  for k, t in ipairs(text) do out[first + k - 1] = string.format("%-24s", t) end
  if pgNo == np and U.awaiting(s) then
    out[9] = string.format("%-24s", "<STANDBY")
    local rej = U.reject_word(s.resp) and "<REJECT" or ""
    local acc = U.accept_word(s.resp) and "ACCEPT>" or ""
    out[11] = rej .. string.rep(" ", 24 - #rej - #acc) .. acc
  end
  out[13] = string.format("%24s", "LOG>")
  return out
end
fmsPages["ATCUPLINK"].getSmallPage=function(self,pgNo,fmsID)
  local i = acarsSystem.getCurrentMessage(fmsID)
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  if not B747_fms_atc_uplink(i) then return out end
  local lines = lines_of(i)
  local np = U.pages(lines)
  out[1] = string.format("%24s", pgNo .. "/" .. np .. " ")
  if pgNo == 1 then out[2] = string.format("%24s", "STATUS") end
  local _, _, more = U.page_lines(lines, pgNo)
  out[12] = more and "-------CONTINUED--------" or "------------------------"
  return out
end
fmsFunctionsDefs["ATCUPLINK"]={}
fmsFunctionsDefs["ATCUPLINK"]["L4"]={"atcuplink","STANDBY"}
fmsFunctionsDefs["ATCUPLINK"]["L5"]={"atcuplink","REJECT"}
fmsFunctionsDefs["ATCUPLINK"]["R5"]={"atcuplink","ACCEPT"}
fmsFunctionsDefs["ATCUPLINK"]["R6"]={"setpage","ATCLOG"}
-- STANDBY, REJECT, ACCEPT on the last page while a response is due
function fmsFunctions.atcuplink(fmsO, value)
  local i = acarsSystem.getCurrentMessage(fmsO.id)
  local s = B747_fms_atc_uplink(i)
  if not s or not U.awaiting(s) then return end
  if fmsO.pgNo ~= U.pages(lines_of(i)) then return end
  if not B747_fms_atc_choose(fmsO.id, i, value) then return end
  local d = B747_fms_atc_due(fmsO.id)
  if value == "REJECT" then
    d.perf, d.wx, d.free = false, false, {"", "", "", ""}
    fmsFunctions.setpage(fmsO, "ATCREJECTDUETO")
  else
    fmsFunctions.setpage(fmsO, "ATCVERIFYRESP")
  end
end

fmsPages["ATCVERIFYRESP"]=createPage("ATCVERIFYRESP")
fmsPages["ATCVERIFYRESP"].getPage=function(self,pgNo,fmsID)
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  out[1] = centre("VERIFY RESPONSE")
  local v = B747_fms_atc_verify(fmsID)
  if not v then return out end
  local acked = v.state == "SENT" and v.kind ~= "STANDBY"
  out[3] = v.word .. string.rep(" ", 24 - #v.word - (acked and 8 or 0)) .. (acked and "ACCEPTED" or "")
  local rest = string.sub(B747_fms_atc_response_text(fmsID), #v.word + 2)
  local extra = U.wrap(rest, 24)
  for k = 1, math.min(#extra, 6) do out[3 + k] = string.format("%-24s", extra[k]) end
  local r
  if v.state then r = v.state
  elseif not B747_fms_atc_ready() then r = "NO COMM"
  elseif not B747_fms_atc_logon().comm then r = "NO ATC COMM"
  else r = "SEND>" end
  out[11] = string.format("%24s", r)
  out[13] = v.kind == "REJECT" and "<REJECT DUE TO          " or "<UPLINK                 "
  return out
end
fmsPages["ATCVERIFYRESP"].getSmallPage=function(self,pgNo,fmsID)
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  local v = B747_fms_atc_verify(fmsID)
  if not v then return out end
  out[1] = string.format("%24s", "1/1 ")
  if v.state == "SENT" and v.kind ~= "STANDBY" then out[2] = string.format("%24s", "STATUS") end
  out[10] = string.format("%24s", (not v.state and not B747_fms_atc_ready()) and "DATA LINK" or "RESPONSE")
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["ATCVERIFYRESP"]={}
fmsFunctionsDefs["ATCVERIFYRESP"]["R5"]={"atcverify","send"}
fmsFunctionsDefs["ATCVERIFYRESP"]["L6"]={"atcverify","back"}
function fmsFunctions.atcverify(fmsO, value)
  local v = B747_fms_atc_verify(fmsO.id)
  if not v then return end
  if value == "send" then
    local err = B747_fms_atc_send_response(fmsO)
    if err then fmsO["notify"] = err end
  elseif v.kind == "REJECT" then
    fmsFunctions.setpage(fmsO, "ATCREJECTDUETO")
  else
    fmsFunctions.setpage(fmsO, "ATCUPLINK")
  end
end
