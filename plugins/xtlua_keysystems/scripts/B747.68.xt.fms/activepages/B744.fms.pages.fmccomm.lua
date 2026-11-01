-- FMC COMM (6-1/6-2 step 12h1; notes/ATA-34-61-FMC.md §122): the company
-- datalink's pages (FCOM p.771-774; FMSPG p.368-369, p.382-383) over the
-- FMS module's company datalink (B747_fms_company). Page 1: <RTE n (the
-- route a flight plan uplink goes to, else the active route; UPLINK over
-- it with that uplink or a flight number uplink not yet reviewed), <DES
-- FORECAST, <RTE DATA with an active route, POS REPORT>, DATA LINK. Page 2:
-- RTE REQUEST <SEND (SENDING, then SENT; blank while a flight plan uplink
-- waits), CO ROUTE, WIND REQUEST <SEND, DATA LINK. Before: fixed text,
-- OFFLINE without AutoATC, the requests did nothing.
local BLANK = "                        "
local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end

-- the route of <RTE n: the uplink's, else the active one (RTE 1 with none)
local function rte_num()
  local c = B747_fms_company()
  if c.up then return c.up.num end
  return B747_fmc_route.active and B747_fmc_route.num or 1
end

fmsPages["FMCCOMM"]=createPage("FMCCOMM")
fmsPages["FMCCOMM"].getNumPages=function(self) return 2 end
fmsPages["FMCCOMM"].getPage=function(self,pgNo,fmsID)
  local c = B747_fms_company()
  local defs = fmsFunctionsDefs["FMCCOMM"]
  for _, k in ipairs({"L1", "L2", "L3", "L4", "L5", "L6", "R1", "R2", "R3", "R4", "R5", "R6"}) do defs[k] = nil end
  local status = B747_fms_company_status()
  if pgNo == 1 then
    local n = rte_num()
    local act = B747_fmc_route.active
    defs["L1"] = {"fmccommrte", tostring(n)}
    defs["L2"] = {"setpage", "DESFORECAST"}
    defs["R1"] = {"setpage", "POSREPORT"}
    if act then defs["L3"] = {"setpage", "RTEDATA"} end
    return {
      "        FMC COMM        ", BLANK,
      lr("<RTE " .. n, "POS REPORT>"), BLANK,
      "<DES FORECAST           ", BLANK,
      act and "<RTE DATA               " or BLANK, BLANK,
      BLANK, BLANK, BLANK, BLANK,
      lr("", status),
    }
  end
  local r = c.req
  local send = ""
  if not c.up then
    send = (r and r.status == "SENDING") and "SENDING" or "<SEND"
    if send == "<SEND" then defs["L1"] = {"fmccommreq", "rte"} end
  end
  defs["R1"] = {"fmccommco", ""}
  return {
    "        FMC COMM        ", BLANK,
    lr(send, c.comm_co_route or "----------"), BLANK,
    "<SEND                   ", BLANK,
    BLANK, BLANK, BLANK, BLANK, BLANK, BLANK,
    lr("", status),
  }
end
fmsPages["FMCCOMM"].getSmallPage=function(self,pgNo,fmsID)
  local c = B747_fms_company()
  if pgNo == 1 then
    local uplink = (c.up and not c.up.loading) or c.flt_unreviewed
    return {
      "                    1/2 ",
      uplink and " UPLINK                 " or BLANK, BLANK,
      BLANK, BLANK,
      BLANK, BLANK,
      BLANK, BLANK, BLANK, BLANK,
      "               DATA LINK", BLANK,
    }
  end
  local r = c.req
  return {
    "                    2/2 ",
    c.up and "                CO ROUTE" or " RTE REQUEST    CO ROUTE",
    (not c.up and r and r.status == "SENT") and "     SENT               " or BLANK,
    " WIND REQUEST           ", BLANK,
    BLANK, BLANK, BLANK, BLANK, BLANK, BLANK,
    "               DATA LINK", BLANK,
  }
end
fmsFunctionsDefs["FMCCOMM"]={}

-- <RTE n: that route's page 1, its flight number uplink reviewed
function fmsFunctions.fmccommrte(fmsO, value)
  B747_fms_company_reviewed()
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "RTE" .. value
  fmsO.targetpgNo = 1
end
-- RTE REQUEST <SEND
function fmsFunctions.fmccommreq(fmsO, value)
  if value == "rte" then B747_fms_company_request(fmsO, nil) end
end
-- CO ROUTE: an empty scratchpad copies it; DELETE clears it
function fmsFunctions.fmccommco(fmsO, value)
  local sp = fmsO["scratchpad"]
  local cur = B747_fms_company().comm_co_route
  if sp == "" then
    if cur then fmsO["scratchpad"] = cur end
    return
  end
  local msg = B747_fms_company_co_route(nil, sp ~= "DELETE" and sp or nil)
  if msg == "INVALID ENTRY" then fmsO["notify"] = msg return end
  fmsO["scratchpad"] = ""
  if msg then fmsO["notify"] = msg end
end
