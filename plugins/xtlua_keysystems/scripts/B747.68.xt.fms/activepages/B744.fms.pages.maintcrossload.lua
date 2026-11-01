-- NAV DATA CROSSLOAD (6-1/6-2 step 12c2; FMSPG p.264; ATA34_2 p.676-
-- 677): 2L the navigation database's identifier (the IDENT page's);
-- <TRANSMIT at 3L on one CDU, then RECEIVE> at 3R on another, each armed
-- by ARM at 6R (--- before, ARM after; another page cancels it); 4L and
-- 4R blank before, TRANSFER IN PROGRESS during the transfer, then TRANSFER
-- COMPLETE, or TRANSFER ABORTED when an FMC stops working during it. The
-- FMCs share X-Plane's navigation data, so nothing is copied; the
-- transfer's time and the status centred are estimates (no source).
-- Before: a static page
fmsPages["MAINTCROSSLOAD"]=createPage("MAINTCROSSLOAD")
local XFER_S = 30
-- each CDU's ARM; the CDU that transmits, the transfer's start and its end
-- ("COMPLETE", "ABORTED")
local armed = {}
local sender, xferT, xferEnd = nil, nil, nil
local function status()
  if xferT and not xferEnd then
    if B747DR_fms_fmc_ok[0] < 0.5 or B747DR_fms_fmc_ok[1] < 0.5 then
      xferEnd = "ABORTED"
    elseif simDRTime - xferT >= XFER_S then
      xferEnd = "COMPLETE"
    end
  end
  local s = xferEnd and ("TRANSFER " .. xferEnd) or (xferT and "TRANSFER IN PROGRESS" or "")
  return string.format("%-24s", string.rep(" ", math.floor((24 - #s) / 2)) .. s)
end
fmsPages["MAINTCROSSLOAD"].getPage=function(self,pgNo,fmsID)
  local cycle = B747_navdb.cycle_info(B747_fmc_navdb)
  local ident = (B747_fmc_navdb.ready and cycle) and ("AIRAC " .. cycle) or ""
  return {
"   NAV DATA CROSSLOAD   ",
"                        ",
"                        ",
"                        ",
string.format("%-24s", ident),
"                        ",
"<TRANSMIT       RECEIVE>",
"                        ",
status(),
"                        ",
"                        ",
"------------------------",
string.format("<INDEX%18s", armed[fmsID] and "ARM" or "---")
  }
end
fmsPages["MAINTCROSSLOAD"].onLeave=function(self,fmsID)
  armed[fmsID] = nil
  if sender == fmsID and not xferT then sender = nil end
end

fmsFunctionsDefs["MAINTCROSSLOAD"]={}
fmsFunctionsDefs["MAINTCROSSLOAD"]["L3"]={"crossload","transmit"}
fmsFunctionsDefs["MAINTCROSSLOAD"]["R3"]={"crossload","receive"}
fmsFunctionsDefs["MAINTCROSSLOAD"]["R6"]={"crossload","arm"}
fmsFunctionsDefs["MAINTCROSSLOAD"]["L6"]={"setpage","MAINT"}
function fmsFunctions.crossload(fmsO, value)
  local sp = fmsO["scratchpad"]
  if value == "arm" then
    if sp == "" then return end
    if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
    if sp ~= "ARM" then fmsO["notify"] = "INVALID ENTRY" return end
    armed[fmsO.id] = true
    fmsO["scratchpad"] = ""
    return
  end
  if sp ~= "" then fmsO["notify"] = "INVALID ENTRY" return end
  -- armed, and no transfer going on
  if not armed[fmsO.id] or (xferT and not xferEnd) then return end
  if value == "transmit" then
    sender, xferT, xferEnd = fmsO.id, nil, nil
  elseif sender and sender ~= fmsO.id and armed[sender] then
    xferT, xferEnd = simDRTime, nil
  end
end
