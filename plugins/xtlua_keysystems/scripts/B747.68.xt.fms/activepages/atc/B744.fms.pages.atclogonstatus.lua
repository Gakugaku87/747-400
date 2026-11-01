-- ATC LOGON/STATUS (6-1/6-2 step 12e; FCOM p.755-757; FMSPG p.277-280):
-- the ATC logon's state (B747.68.atc_logon_model.lua through
-- B747_fms_atc_view). 1L LOGON TO (boxes, the facility, dashes while ATC
-- COMM is established with it, blank with the position or the tail number
-- invalid), 1R LOGON SEND> (RESEND>, SENDING, SENT, ACCEPTED, REJECTED);
-- 2L FLT NO (RTE's: boxes without one, no deletion; a new one ends ATC
-- COMM); 3L TAIL NO (the FMC's, an entry VERIFY TAIL NUMBER when it
-- differs), 3R ACT CTR; 4L ATC COMM <SELECT OFF while connected, 4R NEXT
-- CTR; 5L ADS (ARM) <SELECT OFF or (OFF) <SELECT ARM, 5R ADS EMERG SELECT
-- ON> (OFF>) while not off; 6L <INDEX, 6R the datalink's READY or NO COMM.
-- Estimates: the headers of a blank ATC COMM, ACT CTR and NEXT CTR blank;
-- DELETE of TAIL NO not allowed. Before: the facility sent at once from 1L,
-- the provider's own state words
fmsPages["ATCLOGONSTATUS"]=createPage("ATCLOGONSTATUS")
fmsPages["ATCLOGONSTATUS"].getPage=function(self,pgNo,fmsID)
  local v = B747_fms_atc_view()
  local s = B747_fms_atc_logon()
  local flt = B747_fms_flt_ok() and str_trim(getFMSData("fltno")) or "********"
  return {
"    ATC LOGON/STATUS    ",
"                        ",
string.format("%-12s%12s", v.l1, v.r1),
"                        ",
string.format("%-24s", flt),
"                        ",
string.format("%-12s%12s", B747_fms_tail(), v.act),
"                        ",
string.format("%-12s%12s", s.comm and "<SELECT OFF" or "", v.next),
"                        ",
string.format("%-12s%12s", s.ads == "OFF" and "<SELECT ARM" or "<SELECT OFF",
  s.ads == "OFF" and "" or (s.emerg and "SELECT OFF>" or "SELECT ON>")),
"                        ",
string.format("<INDEX%18s", B747_fms_atc_ready() and "READY" or "NO COMM")
  }
end
fmsPages["ATCLOGONSTATUS"].getSmallPage=function(self,pgNo,fmsID)
  local s = B747_fms_atc_logon()
  local v = B747_fms_atc_view()
  return {
"                        ",
" LOGON TO          LOGON",
"                        ",
" FLT NO                 ",
"                        ",
string.format(" %-11s%12s", "TAIL NO", v.act ~= "" and "ACT CTR" or ""),
"                        ",
string.format(" %-11s%12s", s.comm and "ATC COMM" or "", v.next ~= "" and "NEXT CTR" or ""),
"                        ",
string.format(" %-11s%12s", "ADS (" .. s.ads .. ")", s.ads == "OFF" and "" or "ADS EMERG"),
"                        ",
"--------------  DATALINK",
"                        "
  }
end

fmsFunctionsDefs["ATCLOGONSTATUS"]={}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L1"]={"atclogon","ctr"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L2"]={"setdata","fltno"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L3"]={"atclogon","tail"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L4"]={"atclogon","off"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L5"]={"atclogon","ads"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["L6"]={"setpage","ATCINDEX"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["R1"]={"atclogon","send"}
fmsFunctionsDefs["ATCLOGONSTATUS"]["R5"]={"atclogon","emerg"}
function fmsFunctions.atclogon(fmsO, value)
  local sp = fmsO["scratchpad"]
  local del = sp == "DELETE"
  local s = B747_fms_atc_logon()
  if value == "ctr" then
    if sp == "" then return end
    local err
    if del then err = B747_atc_logon_model.delete_ctr(s) else err = B747_atc_logon_model.enter_ctr(s, sp) end
    if err then fmsO["notify"] = err return end
    fmsO["scratchpad"] = ""
  elseif value == "tail" then
    if sp == "" then return end
    if del then fmsO["notify"] = "INVALID DELETE" return end
    local msg = B747_fms_tail_enter(sp)
    if msg == "INVALID ENTRY" then fmsO["notify"] = msg return end
    fmsO["scratchpad"] = ""
    if msg then fmsO["notify"] = msg end
  elseif sp ~= "" then
    fmsO["notify"] = "INVALID ENTRY"
  elseif value == "send" then
    B747_fms_atc_send(fmsO)
  elseif value == "off" then
    B747_fms_atc_off()
  elseif value == "ads" then
    B747_atc_logon_model.ads_toggle(s)
  elseif value == "emerg" then
    B747_atc_logon_model.emerg_toggle(s)
  end
end
