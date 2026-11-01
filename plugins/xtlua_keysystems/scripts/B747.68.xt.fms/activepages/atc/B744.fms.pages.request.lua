-- ATC REQUEST, ATC ALT/SPEED/OFFSET/ROUTE REQUEST 1/4-4/4, VERIFY REQUEST
-- and XXXXZ ATC REQUEST (6-1/6-2 step 12g2a; FCOM p.736-747; FMSPG
-- p.298-327; B747.68.atc_request_model.lua through the FMS's
-- B747_fms_atc_draft: one request in the FMC, both CDUs'; ATC INDEX's
-- CLEARANCE and VOICE too).
-- ATC REQUEST: ALTITUDE, SPEED, OFFSET (an entry: its page with it; the key
-- alone: its page), <ROUTE REQUEST, <ERASE REQUEST (with something
-- selected), <INDEX, VERIFY>. The four pages (NEXT and PREV around them):
-- the selections small with their caret, large once selected (FCOM
-- p.739-741; FMSPG p.306); what depends on the altitude, the speed or the
-- offset blank without it. VERIFY REQUEST: the request's lines, the free
-- text lines, REQUEST SEND> on the last page (SENDING, RESEND>, NO ATC
-- COMM, DATA LINK NO COMM), CONTINUED before it, 6L <REQUEST or <INDEX.
-- XXXXZ ATC REQUEST: <UPLINK with ATC's response and the STATUS, the text
-- from line 2, the response's time after it, LOG>. (Step 12g2b) 4/4's
-- REQUEST RTE 1 and RTE 2 (small with the caret, large once selected, the
-- other blank) and REQUEST DEP/ARR (the departure or arrival selected
-- with its caret, an entry or the pushed one large, dashes without one:
-- FCOM p.742-743; FMSPG p.316-318). Not here yet: WHEN CAN WE (step
-- 12g3). Estimates: no
-- PRINT (no printer, as the uplink's page); the lines' columns. Before,
-- the pages wrote and read FMS data fields (acarsREQ*) without the
-- entries' checks, VERIFY wrote the shared text while drawing (CDU-34).
local Q = B747_atc_request_model
local BLANK = "                        "
local function blank13()
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  return out
end
-- text written into a line from a column (the line kept at 24)
local function put(line, col, text)
  if text == nil or text == "" then return line end
  return string.sub(string.sub(line, 1, col - 1) .. text .. string.sub(line, col + #text), 1, 24)
end
local function left(line, text) return put(line, 1, text) end
local function right(line, text) return put(line, 25 - #text, text) end
-- a title left of the page number
local function title(t) return put(BLANK, math.max(1, math.floor((20 - #t) / 2) + 1), t) end
local function pageno(pg, n) return string.format("%24s", pg .. "/" .. n .. " ") end
local function centre(t) return put(BLANK, math.floor((24 - #t) / 2) + 1, t) end
local function dr() return B747_fms_atc_draft("REQUEST") end
-- an IAS's KT (the Mach's nothing)
local function ias(s) return s and string.sub(s, 1, 1) ~= "." end

-- ATC REQUEST (FCOM p.736-737; FMSPG p.300-303)
fmsPages["ATCREQUEST"]=createPage("ATCREQUEST")
fmsPages["ATCREQUEST"].getPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  out[1] = centre("ATC REQUEST")
  out[3] = left(BLANK, "<" .. (r.alt or "-----"))
  out[5] = left(BLANK, "<" .. (r.spd or "---"))
  out[7] = left(BLANK, "<" .. (r.off or "---"))
  out[9] = left(BLANK, "<ROUTE REQUEST")
  if Q.any(r) then out[11] = left(BLANK, "<ERASE REQUEST") end
  out[13] = "<INDEX           VERIFY>"
  return out
end
fmsPages["ATCREQUEST"].getSmallPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  out[2] = left(BLANK, " ALTITUDE")
  out[4] = left(BLANK, " SPEED")
  if ias(r.spd) then out[5] = put(BLANK, 2 + #r.spd, "KT") end
  out[6] = left(BLANK, " OFFSET")
  if r.off then out[7] = put(BLANK, 2 + #r.off, "NM") end
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["ATCREQUEST"]={}
fmsFunctionsDefs["ATCREQUEST"]["L1"]={"atcreq","alt"}
fmsFunctionsDefs["ATCREQUEST"]["L2"]={"atcreq","spd"}
fmsFunctionsDefs["ATCREQUEST"]["L3"]={"atcreq","off"}
fmsFunctionsDefs["ATCREQUEST"]["L4"]={"setpage_no","ATCSUBREQUEST_4"}
fmsFunctionsDefs["ATCREQUEST"]["L5"]={"atcreq","erase"}
fmsFunctionsDefs["ATCREQUEST"]["L6"]={"setpage","ATCINDEX"}
fmsFunctionsDefs["ATCREQUEST"]["R6"]={"atcreq","verify"}
local SUBPAGE = {alt = 1, spd = 2, off = 3}
function fmsFunctions.atcreq(fmsO, value)
  if value == "verify" then
    B747_fms_atc_verify_req(fmsO.id, "REQUEST", "REQUEST")
    if not B747_fms_atc_req_sending("REQUEST") then B747_fms_atc_refresh_route("REQUEST") end
    fmsFunctions.setpage(fmsO, "ATCVERIFYREQUEST")
    return
  end
  -- 1L, 2L, 3L, 5L not while the request is SENDING (FMSPG p.300)
  if B747_fms_atc_req_sending("REQUEST") then return end
  local r = dr()
  if value == "erase" then
    if Q.any(r) then Q.erase(r) end
    return
  end
  local sp = fmsO["scratchpad"]
  if sp == "" then fmsFunctions.setpage_no(fmsO, "ATCSUBREQUEST_" .. SUBPAGE[value]) return end
  local err
  if sp == "DELETE" then err = Q.delete(r, value)
  else err = Q.enter(r, value, sp, B747_fms_atc_present_ft()) end
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
  if sp ~= "DELETE" then fmsFunctions.setpage_no(fmsO, "ATCSUBREQUEST_" .. SUBPAGE[value]) end
end

-- ATC ALT/SPEED/OFFSET/ROUTE REQUEST 1/4-4/4 (FCOM p.738-743; FMSPG
-- p.306-318)
local TITLES = {"ATC ALT REQUEST", "ATC SPEED REQUEST", "ATC OFFSET REQUEST", "ATC ROUTE REQUEST"}
-- a selection on the right: large once selected, else its prompt (small)
local function sel_large(line, on, text) if on then return right(line, text) end return line end
local function sel_small(line, on, text) if not on then return right(line, text .. ">") end return line end
fmsPages["ATCSUBREQUEST"]=createPage("ATCSUBREQUEST")
fmsPages["ATCSUBREQUEST"].getNumPages=function(self) return 4 end
fmsPages["ATCSUBREQUEST"].getPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  out[1] = title(TITLES[pgNo] or TITLES[1])
  if pgNo == 1 then
    out[3] = left(BLANK, r.alt or "-----")
    if r.alt then
      out[3] = sel_large(out[3], r.crz_clb, "CRZ CLB")
      out[5] = sel_large(left(BLANK, r.step_at or "-----"), r.own_sep, "SEPARATION/VMC")
      out[7] = sel_large(BLANK, r.alt_perf, "PERFORMANCE")
      out[9] = sel_large(r.pilot_disc and left(BLANK, "AT PILOT DISC") or BLANK, r.alt_wx, "WEATHER")
    end
  elseif pgNo == 2 then
    out[3] = left(BLANK, r.spd or "---")
    if r.spd then
      out[7] = sel_large(BLANK, r.spd_perf, "PERFORMANCE")
      out[9] = sel_large(BLANK, r.spd_wx, "WEATHER")
    end
  elseif pgNo == 3 then
    out[3] = left(BLANK, r.off or "---")
    if Q.can(r, "off_at") then out[5] = left(BLANK, r.off_at or "-----") end
    if Q.can(r, "off_wx") or r.off_wx then out[9] = sel_large(BLANK, r.off_wx, "WEATHER") end
  else
    out[3] = right(left(BLANK, r.direct or "-----"), r.hdg or "---")
    out[5] = right(BLANK, r.trk or "---")
    out[7] = right(r.rte == 1 and left(BLANK, "RTE 1") or BLANK, r.rte == 2 and "RTE 2" or "")
    if r.proc then out[11] = left(BLANK, r.proc)
    elseif not B747_fms_atc_deparr_default() then out[11] = left(BLANK, "-----") end
  end
  out[13] = "<REQUEST         VERIFY>"
  return out
end
fmsPages["ATCSUBREQUEST"].getSmallPage=function(self,pgNo,fmsID)
  local r = dr()
  local out = blank13()
  out[1] = pageno(pgNo, 4)
  if pgNo == 1 then
    out[2] = left(BLANK, " ALTITUDE")
    if r.alt then
      out[2] = right(out[2], "REQUEST")
      out[3] = sel_small(BLANK, r.crz_clb, "CRZ CLB")
      out[4] = right(left(BLANK, " STEP AT"), "MAINTAIN OWN")
      out[5] = sel_small(BLANK, r.own_sep, "SEPARATION/VMC")
      out[6] = right(BLANK, "DUE TO")
      out[7] = sel_small(BLANK, r.alt_perf, "PERFORMANCE")
      out[8] = right(BLANK, "DUE TO")
      out[9] = sel_small(r.pilot_disc and BLANK or left(BLANK, "<AT PILOT DISC"), r.alt_wx, "WEATHER")
    end
  elseif pgNo == 2 then
    out[2] = left(BLANK, " SPEED")
    if ias(r.spd) then out[3] = put(BLANK, 1 + #r.spd, "KT IAS") end
    if r.spd then
      out[6] = right(BLANK, "DUE TO")
      out[7] = sel_small(BLANK, r.spd_perf, "PERFORMANCE")
      out[8] = right(BLANK, "DUE TO")
      out[9] = sel_small(BLANK, r.spd_wx, "WEATHER")
    end
  elseif pgNo == 3 then
    out[2] = left(BLANK, " OFFSET")
    if r.off then out[3] = put(BLANK, 1 + #r.off, "NM") end
    if Q.can(r, "off_at") then out[4] = left(BLANK, " OFFSET AT") end
    if Q.can(r, "off_wx") or r.off_wx then
      out[8] = right(BLANK, "DUE TO")
      out[9] = sel_small(BLANK, r.off_wx, "WEATHER")
    end
  else
    out[2] = right(left(BLANK, " DIRECT TO"), "HEADING")
    out[4] = right(BLANK, "GROUND TRACK")
    out[6] = right(Q.can(r, "rte1") and left(BLANK, " REQUEST") or BLANK, Q.can(r, "rte2") and "REQUEST" or "")
    out[7] = right((Q.can(r, "rte1") and r.rte ~= 1) and left(BLANK, "<RTE 1") or BLANK,
      (Q.can(r, "rte2") and r.rte ~= 2) and "RTE 2>" or "")
    out[10] = left(BLANK, " REQUEST DEP/ARR")
    local def = not r.proc and B747_fms_atc_deparr_default()
    if def then out[11] = left(BLANK, "<" .. def) end
  end
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["ATCSUBREQUEST"]={}
for k = 1, 5 do
  fmsFunctionsDefs["ATCSUBREQUEST"]["L" .. k]={"atcsubreq","L" .. k}
  fmsFunctionsDefs["ATCSUBREQUEST"]["R" .. k]={"atcsubreq","R" .. k}
end
fmsFunctionsDefs["ATCSUBREQUEST"]["L6"]={"setpage","ATCREQUEST"}
fmsFunctionsDefs["ATCSUBREQUEST"]["R6"]={"atcreq","verify"}
fmsFunctionsDefs["ATCSUBREQUEST"]["prev"]={"atcsubreq","prev"}
local FIELDS = {
  {L1 = "alt", L2 = "step_at", L4 = "pilot_disc", R1 = "crz_clb", R2 = "own_sep", R3 = "alt_perf", R4 = "alt_wx"},
  {L1 = "spd", R3 = "spd_perf", R4 = "spd_wx"},
  {L1 = "off", L2 = "off_at", R4 = "off_wx"},
  {L1 = "direct", R1 = "hdg", R2 = "trk", L3 = "rte1", R3 = "rte2", L5 = "proc"},
}
local SELECTION = {pilot_disc = true, crz_clb = true, own_sep = true, alt_perf = true, alt_wx = true,
  spd_perf = true, spd_wx = true, off_wx = true}
local PLACE = {step_at = true, off_at = true, direct = true}
function fmsFunctions.atcsubreq(fmsO, value)
  local pg = fmsO.pgNo or 1
  -- PREV on 1/4: 4/4 (FMSPG p.316)
  if value == "prev" then fmsO.targetpgNo = (pg > 1) and (pg - 1) or 4 return end
  if B747_fms_atc_req_sending("REQUEST") then return end
  local field = (FIELDS[pg] or {})[value]
  if not field then return end
  local r = dr()
  local sp = fmsO["scratchpad"]
  local err
  -- (step 12g2b) RTE 1, RTE 2: the key selects, DELETE deselects
  local n = (field == "rte1" and 1) or (field == "rte2" and 2) or nil
  if n then
    if sp == "DELETE" then
      if r.rte ~= n then fmsO["notify"] = "INVALID DELETE" return end
      err = Q.delete(r, "rte")
    elseif sp ~= "" then
      err = Q.INVALID
    else
      local text = B747_fms_atc_route_text(n)
      if text then err = Q.select_route(r, n, text) end
    end
    if err then fmsO["notify"] = err return end
    if sp == "DELETE" then fmsO["scratchpad"] = "" end
    return
  end
  -- DEP/ARR: the default pushed, or a procedure entered
  if field == "proc" then
    if sp == "DELETE" then
      err = Q.delete(r, "proc")
    elseif sp == "" then
      local def = B747_fms_atc_deparr_default()
      if def and not r.proc then err = Q.set_proc(r, def) end
    else
      err = B747_fms_atc_proc_check(sp) or Q.set_proc(r, sp)
    end
    if err then fmsO["notify"] = err return end
    if sp ~= "" then fmsO["scratchpad"] = "" end
    return
  end
  if sp == "DELETE" then
    err = Q.delete(r, field)
  elseif SELECTION[field] then
    if sp ~= "" then err = Q.INVALID else err = Q.select(r, field) end
  elseif sp == "" then
    return
  elseif PLACE[field] and not (field ~= "direct" and Q.time_text(sp)) then
    -- a position: the FMC's (a fix, navaid, airport, latitude/longitude,
    -- place bearing/distance; SELECT DESIRED WPT for several)
    if not Q.can(r, field) then fmsO["notify"] = Q.INVALID return end
    B747_fmc_with_fix(fmsO, sp, nil, function(p)
      local e = Q.set_place(dr(), field, sp)
      if e then fmsO["notify"] = e else fmsO["scratchpad"] = "" end
    end)
    return
  else
    err = Q.enter(r, field, sp, B747_fms_atc_present_ft())
  end
  if err then fmsO["notify"] = err return end
  if sp ~= "" then fmsO["scratchpad"] = "" end
end

-- VERIFY REQUEST (FCOM p.744-745; FMSPG p.299-300, p.324-326, p.365)
local function vstate(fmsID)
  local v = B747_fms_atc_verify_req(fmsID)
  local d = B747_fms_atc_draft(v.kind)
  return Q.verify_rows(d, not B747_fms_atc_req_sending(v.kind)), d, v
end
fmsPages["ATCVERIFYREQUEST"]=createPage("ATCVERIFYREQUEST")
fmsPages["ATCVERIFYREQUEST"].getNumPages=function(self,fmsID)
  local rows = vstate(fmsID)
  return Q.pages(rows)
end
fmsPages["ATCVERIFYREQUEST"].getPage=function(self,pgNo,fmsID)
  local rows, d, v = vstate(fmsID)
  local np = Q.pages(rows)
  local out = blank13()
  out[1] = title("VERIFY REQUEST")
  local list, first = Q.page_rows(rows, pgNo)
  for k, row in ipairs(list) do out[1 + 2 * (first + k - 1)] = left(BLANK, row.data) end
  if pgNo == np then out[11] = right(out[11], (B747_fms_atc_req_status(v.kind))) end
  -- 6L: where it came from (FCOM p.745; step 12g3a WHEN CAN WE)
  out[13] = left(BLANK, "<" .. (v.from or "REQUEST"))
  return out
end
fmsPages["ATCVERIFYREQUEST"].getSmallPage=function(self,pgNo,fmsID)
  local rows, d, v = vstate(fmsID)
  local np = Q.pages(rows)
  local out = blank13()
  out[1] = pageno(pgNo, np)
  local list, first = Q.page_rows(rows, pgNo)
  for k, row in ipairs(list) do
    local n = 2 * (first + k - 1)
    out[n] = left(BLANK, (#row.head < 24 and row.head ~= "") and (" " .. row.head) or row.head)
    if row.unit then out[n + 1] = put(BLANK, #row.data + 1, row.unit) end
  end
  if pgNo == np then
    local st, head = B747_fms_atc_req_status(v.kind)
    if st ~= "" then out[10] = right(BLANK, head) end
  end
  out[12] = pgNo < np and "-------CONTINUED--------" or "------------------------"
  return out
end
local BACK = {INDEX = "ATCINDEX", REQUEST = "ATCREQUEST", ["WHEN CAN WE"] = "WHENCANWE"}
fmsFunctionsDefs["ATCVERIFYREQUEST"]={}
for k = 1, 5 do fmsFunctionsDefs["ATCVERIFYREQUEST"]["L" .. k]={"atcverifyreq","L" .. k} end
fmsFunctionsDefs["ATCVERIFYREQUEST"]["R5"]={"atcverifyreq","send"}
fmsFunctionsDefs["ATCVERIFYREQUEST"]["L6"]={"atcverifyreq","back"}
function fmsFunctions.atcverifyreq(fmsO, value)
  local rows, d, v = vstate(fmsO.id)
  if value == "back" then
    fmsFunctions.setpage(fmsO, BACK[v.from] or "ATCREQUEST")
    return
  end
  if value == "send" then
    if (fmsO.pgNo or 1) == Q.pages(rows) then B747_fms_atc_send_request(fmsO, v.kind) end
    return
  end
  -- a free text line (not while SENDING)
  if B747_fms_atc_req_sending(v.kind) then return end
  local list, first = Q.page_rows(rows, fmsO.pgNo or 1)
  local row = list[tonumber(string.sub(value, 2)) - first + 1]
  local sp = fmsO["scratchpad"]
  if not row or not row.free or sp == "" then return end
  local err = Q.set_free(d, row.free, sp)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end
-- ATC INDEX's CLEARANCE> and VOICE> (FMSPG p.298-300)
function fmsFunctions.atcindexreq(fmsO, value)
  B747_fms_atc_verify_req(fmsO.id, value, "INDEX")
  fmsFunctions.setpage(fmsO, "ATCVERIFYREQUEST")
end

-- XXXXZ ATC REQUEST (FCOM p.746-747; FMSPG p.326-327): the request sent
local FIRST = 4
local function sent(fmsID)
  local d = B747_fms_atc_shown_request(fmsID)
  if not d then return nil end
  return d, Q.sent_rows(d.req)
end
fmsPages["ATCREQUESTLOG"]=createPage("ATCREQUESTLOG")
fmsPages["ATCREQUESTLOG"].getNumPages=function(self,fmsID)
  local d, rows = sent(fmsID)
  return d and Q.pages(rows, FIRST) or 1
end
fmsPages["ATCREQUESTLOG"].getPage=function(self,pgNo,fmsID)
  local out = blank13()
  local d, rows = sent(fmsID)
  out[13] = right(BLANK, "LOG>")
  if not d then
    out[1] = centre("ATC REQUEST")
    return out
  end
  out[1] = title(d.time .. "Z ATC REQUEST")
  if pgNo == 1 then
    out[3] = right(B747_fms_atc_response_to(d.id) and left(BLANK, "<UPLINK") or BLANK, d.status)
  end
  local list, first = Q.page_rows(rows, pgNo, FIRST)
  for k, row in ipairs(list) do out[1 + 2 * (first + k - 1)] = left(BLANK, row.data) end
  return out
end
fmsPages["ATCREQUESTLOG"].getSmallPage=function(self,pgNo,fmsID)
  local out = blank13()
  local d, rows = sent(fmsID)
  if not d then return out end
  local np = Q.pages(rows, FIRST)
  out[1] = pageno(pgNo, np)
  if pgNo == 1 then out[2] = right(BLANK, "STATUS") end
  local list, first = Q.page_rows(rows, pgNo, FIRST)
  for k, row in ipairs(list) do
    local n = 2 * (first + k - 1)
    out[n] = left(BLANK, (#row.head < 24 and row.head ~= "") and (" " .. row.head) or row.head)
    if row.unit then out[n + 1] = put(BLANK, #row.data + 1, row.unit) end
  end
  out[12] = pgNo < np and "-------CONTINUED--------" or "------------------------"
  -- the response's time after the text (FCOM p.746: under its last line)
  local i = B747_fms_atc_response_to(d.id)
  if i and pgNo == np then
    local t = string.gsub(B747_fms_atc_msg_field(i, "time") or "", ":", "")
    out[2 * (first + #list)] = "---- RESPONSE " .. string.sub(t .. "0000", 1, 4) .. "Z ----"
  end
  return out
end
fmsFunctionsDefs["ATCREQUESTLOG"]={}
fmsFunctionsDefs["ATCREQUESTLOG"]["L1"]={"atcreqlog","uplink"}
fmsFunctionsDefs["ATCREQUESTLOG"]["R6"]={"setpage","ATCLOG"}
function fmsFunctions.atcreqlog(fmsO, value)
  local d = B747_fms_atc_shown_request(fmsO.id)
  if not d or (fmsO.pgNo or 1) ~= 1 then return end
  local i = B747_fms_atc_response_to(d.id)
  if not i then return end
  acarsSystem.setCurrentMessage(fmsO.id, i)
  fmsFunctions.setpage(fmsO, "ATCUPLINK")
end
