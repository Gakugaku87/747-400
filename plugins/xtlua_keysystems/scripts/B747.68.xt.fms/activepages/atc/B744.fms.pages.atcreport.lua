-- ATC REPORT, VERIFY REPORT and XXXXZ ATC REPORT (6-1/6-2 step 12g3c;
-- FCOM p.748-751; FMSPG p.328-344; B747.68.atc_report_model.lua through
-- the FMS's B747_fms_report_*).
-- ATC REPORT: 1L <RTE REPORT (with an active route), 1R FREE TEXT>; the
-- report list from line 2 (oldest first; ARMED over an armed one; long
-- texts cut with two periods), a left key opens its VERIFY REPORT (REQUEST
-- POSITION REPORT: POS REPORT), DELETE deletes it; 6L <INDEX.
-- VERIFY REPORT: the report's lines (the fixed words small, the data
-- large, boxes for an entry needed), <CANNOT ACCEPT for WHEN CAN YOU
-- ACCEPT, the free text lines, 1R ARM>/ARMED for LEVEL, REACHING and
-- PASSING, REPORT SEND> on the last page (no SEND before the boxes are
-- filled), 6L <REPORT. XXXXZ ATC REPORT: the time, STATUS, the text, LOG>.
-- Estimates: the lines' columns; ARM> and ARMED large; a position entry a
-- waypoint of the active route only (FMSPG p.336); no PRINT (no printer).
-- Before, ATC REPORT was a fixed picture (titled ATC INDEX) and VERIFY
-- REPORT none.
local A = B747_atc_report_model
local BLANK = "                        "
local function put(line, col, text)
  if text == nil or text == "" then return line end
  return string.sub(string.sub(line, 1, col - 1) .. text .. string.sub(line, col + #text), 1, 24)
end
local function left(line, text) return put(line, 1, text) end
local function right(line, text) return put(line, 25 - #text, text) end
local function blank13()
  local out = {}
  for n = 1, 13 do out[n] = BLANK end
  return out
end
local function title(t) return put(BLANK, math.max(1, math.floor((20 - #t) / 2) + 1), t) end
local function pageno(pg, n) return string.format("%24s", pg .. "/" .. n .. " ") end
local function cut(text, n) if #text > n then return string.sub(text, 1, n - 2) .. ".." end return text end
local function ctx() return B747_fms_report_ctx() end

-- ATC REPORT (FCOM p.748-749; FMSPG p.337-338): four entries on page 1
-- (lines 2-5), five after
local function entries(pg)
  local list = B747_fms_report_list()
  local from, n, line = 1, 4, 2
  if pg > 1 then from, n, line = 5 + (pg - 2) * 5, 5, 1 end
  local out = {}
  for k = from, math.min(#list, from + n - 1) do out[#out + 1] = list[k] end
  return out, line
end
local function report_pages()
  local n = #B747_fms_report_list()
  if n <= 4 then return 1 end
  return 1 + math.ceil((n - 4) / 5)
end
fmsPages["ATCREPORT"]=createPage("ATCREPORT")
fmsPages["ATCREPORT"].getNumPages=function(self) return report_pages() end
fmsPages["ATCREPORT"].getPage=function(self,pgNo,fmsID)
  local out = blank13()
  out[1] = title("ATC REPORT")
  if pgNo == 1 then
    out[3] = right(B747_fmc_route.active and left(BLANK, "<RTE REPORT") or BLANK, "FREE TEXT>")
  end
  local list, first = entries(pgNo)
  for k, rep in ipairs(list) do out[1 + 2 * (first + k - 1)] = left(BLANK, "<" .. cut(rep.text, 23)) end
  out[13] = left(BLANK, "<INDEX")
  return out
end
fmsPages["ATCREPORT"].getSmallPage=function(self,pgNo,fmsID)
  local out = blank13()
  out[1] = pageno(pgNo, report_pages())
  if pgNo == 1 and B747_fmc_route.active then out[2] = left(BLANK, " ATC") end
  local list, first = entries(pgNo)
  for k, rep in ipairs(list) do
    if rep.armed then out[2 * (first + k - 1)] = left(BLANK, " ARMED") end
  end
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["ATCREPORT"]={}
for k = 1, 5 do fmsFunctionsDefs["ATCREPORT"]["L" .. k]={"atcreport","L" .. k} end
fmsFunctionsDefs["ATCREPORT"]["R1"]={"atcreport","free"}
fmsFunctionsDefs["ATCREPORT"]["L6"]={"setpage","ATCINDEX"}
function fmsFunctions.atcreport(fmsO, value)
  local pg = fmsO.pgNo or 1
  if value == "free" then
    if pg ~= 1 then return end
    B747_fms_report_verify(fmsO.id, A.new())
    fmsFunctions.setpage(fmsO, "ATCVERIFYREPORT")
    return
  end
  local k = tonumber(string.sub(value, 2))
  if pg == 1 and k == 1 then
    -- <RTE REPORT: ASSIGNED ROUTE RTE X (FMSPG p.338)
    if not B747_fmc_route.active then return end
    B747_fms_report_verify(fmsO.id, A.new({id = "RTE REPORT"}))
    fmsFunctions.setpage(fmsO, "ATCVERIFYREPORT")
    return
  end
  local list, first = entries(pg)
  local rep = list[k - first + 1]
  if not rep then return end
  if fmsO["scratchpad"] == "DELETE" then
    B747_fms_report_delete(rep)
    fmsO["scratchpad"] = ""
    return
  end
  if rep.posrep then fmsFunctions.setpage(fmsO, "POSREPORT") return end
  B747_fms_report_verify(fmsO.id, rep)
  fmsFunctions.setpage(fmsO, "ATCVERIFYREPORT")
end

-- VERIFY REPORT (FCOM p.750-751; FMSPG p.338-340): the report's rows,
-- CANNOT ACCEPT, the free text lines (from the line after them to the
-- page's fourth: at least one)
local function vrows(fmsID)
  local rep = B747_fms_report_verify(fmsID)
  if not rep then return {}, nil end
  local rows = A.rows(rep, ctx())
  if rep.wcya then
    rows[#rows + 1] = {head = "", data = rep.cannot and "CANNOT ACCEPT" or "<CANNOT ACCEPT", cannot = true}
  end
  if #rows % 5 == 4 then rows[#rows + 1] = {head = "", data = ""} end
  local used = #rows % 5
  local sending = rep.sent and rep.sent.status == "SENDING"
  for k = 1, 4 - used do
    local t = rep.free[k]
    local row = {head = "", data = "", free = k}
    if t ~= "" then row.data = t elseif not sending then row.data = "<" end
    if k == 1 and (t ~= "" or not sending) then row.head = #rows > 0 and "/FREE TEXT" or "FREE TEXT" end
    rows[#rows + 1] = row
  end
  return rows, rep
end
local function vpages(rows) return math.max(1, math.ceil(#rows / 5)) end
fmsPages["ATCVERIFYREPORT"]=createPage("ATCVERIFYREPORT")
fmsPages["ATCVERIFYREPORT"].getNumPages=function(self,fmsID) return vpages((vrows(fmsID))) end
fmsPages["ATCVERIFYREPORT"].getPage=function(self,pgNo,fmsID)
  local out = blank13()
  out[1] = title("VERIFY REPORT")
  local rows, rep = vrows(fmsID)
  out[13] = left(BLANK, "<REPORT")
  if not rep then return out end
  local np = vpages(rows)
  for k = 1, 5 do
    local row = rows[(pgNo - 1) * 5 + k]
    if row then out[1 + 2 * k] = left(BLANK, row.data) end
  end
  if pgNo == 1 and rep.armable then out[3] = right(out[3], rep.armed and "ARMED" or "ARM>") end
  if pgNo == np then
    local st = B747_fms_report_status(rep)
    if st == "SEND" or st == "RESEND" then st = st .. ">" end
    out[11] = right(out[11], st)
  end
  return out
end
fmsPages["ATCVERIFYREPORT"].getSmallPage=function(self,pgNo,fmsID)
  local out = blank13()
  local rows, rep = vrows(fmsID)
  if not rep then return out end
  local np = vpages(rows)
  out[1] = pageno(pgNo, np)
  for k = 1, 5 do
    local row = rows[(pgNo - 1) * 5 + k]
    if row and row.head ~= "" then
      out[2 * k] = left(BLANK, #row.head < 24 and (" " .. row.head) or row.head)
    end
  end
  if pgNo == np then
    local st = B747_fms_report_status(rep)
    if st ~= "" then out[10] = right(BLANK, st == "NO COMM" and "DATA LINK" or "REPORT") end
  end
  out[12] = pgNo < np and "-------CONTINUED--------" or "------------------------"
  return out
end
fmsFunctionsDefs["ATCVERIFYREPORT"]={}
for k = 1, 5 do fmsFunctionsDefs["ATCVERIFYREPORT"]["L" .. k]={"atcverifyrep","L" .. k} end
fmsFunctionsDefs["ATCVERIFYREPORT"]["R1"]={"atcverifyrep","arm"}
fmsFunctionsDefs["ATCVERIFYREPORT"]["R5"]={"atcverifyrep","send"}
fmsFunctionsDefs["ATCVERIFYREPORT"]["L6"]={"setpage","ATCREPORT"}
-- a waypoint of the active route (FMSPG p.336)
local function in_route(name)
  local r = B747_route_model.shown(B747_fmc_route)
  if r.dest and r.dest.ident == name then return true end
  if r.origin and r.origin.ident == name then return true end
  for _, l in ipairs(r.legs) do
    if l.fix and l.fix.ident == name then return true end
  end
  return false
end
function fmsFunctions.atcverifyrep(fmsO, value)
  local rows, rep = vrows(fmsO.id)
  if not rep then return end
  local pg = fmsO.pgNo or 1
  local sp = fmsO["scratchpad"]
  if value == "send" then
    if pg == vpages(rows) then B747_fms_report_send(fmsO, rep) end
    return
  end
  if rep.sent and rep.sent.status == "SENDING" then return end
  local err
  if value == "arm" then
    if pg ~= 1 or not rep.armable then return end
    err = A.arm(rep, sp ~= "DELETE")
    if not err and sp == "DELETE" then fmsO["scratchpad"] = "" end
    if err then fmsO["notify"] = err end
    return
  end
  local row = rows[(pg - 1) * 5 + tonumber(string.sub(value, 2))]
  if not row then return end
  if row.cannot then
    if sp == "" then err = A.cannot(rep, true)
    elseif sp == "DELETE" then err = A.cannot(rep, false)
    else err = A.INVALID end
  elseif row.free then
    if sp == "" then return end
    err = A.set_free(rep, row.free, sp)
  elseif row.field then
    if sp == "" then return end
    local c = ctx()
    if sp ~= "DELETE" and A.field_kind(rep, c, row.field) == "pos" and not in_route(sp) then
      err = A.INVALID
    else
      err = A.enter(rep, row.field, sp, c)
    end
  elseif sp ~= "" then
    -- the uplink's data: not to be changed (FMSPG p.333)
    err = A.INVALID
  else
    return
  end
  if err then fmsO["notify"] = err return end
  if sp ~= "" then fmsO["scratchpad"] = "" end
end

-- XXXXZ ATC REPORT (FMSPG p.343-344): a report sent
local function sent(fmsID) return B747_fms_report_shown(fmsID) end
local function spages(d)
  local n = #d.rows
  if n <= 4 then return 1 end
  return 1 + math.ceil((n - 4) / 5)
end
local function spage_rows(d, pg)
  local from, n, line = 1, 4, 2
  if pg > 1 then from, n, line = 5 + (pg - 2) * 5, 5, 1 end
  local out = {}
  for k = from, math.min(#d.rows, from + n - 1) do out[#out + 1] = d.rows[k] end
  return out, line
end
fmsPages["ATCREPORTLOG"]=createPage("ATCREPORTLOG")
fmsPages["ATCREPORTLOG"].getNumPages=function(self,fmsID)
  local d = sent(fmsID)
  return d and spages(d) or 1
end
fmsPages["ATCREPORTLOG"].getPage=function(self,pgNo,fmsID)
  local out = blank13()
  out[13] = right(BLANK, "LOG>")
  local d = sent(fmsID)
  if not d then out[1] = title("ATC REPORT") return out end
  out[1] = title(d.time .. "Z ATC REPORT")
  if pgNo == 1 then out[3] = right(BLANK, d.status) end
  local list, first = spage_rows(d, pgNo)
  for k, row in ipairs(list) do out[1 + 2 * (first + k - 1)] = left(BLANK, row.data) end
  return out
end
fmsPages["ATCREPORTLOG"].getSmallPage=function(self,pgNo,fmsID)
  local out = blank13()
  local d = sent(fmsID)
  if not d then return out end
  out[1] = pageno(pgNo, spages(d))
  if pgNo == 1 then out[2] = right(BLANK, "STATUS") end
  local list, first = spage_rows(d, pgNo)
  for k, row in ipairs(list) do
    if row.head ~= "" then out[2 * (first + k - 1)] = left(BLANK, #row.head < 24 and (" " .. row.head) or row.head) end
  end
  out[12] = pgNo < spages(d) and "-------CONTINUED--------" or "------------------------"
  return out
end
fmsFunctionsDefs["ATCREPORTLOG"]={}
fmsFunctionsDefs["ATCREPORTLOG"]["R6"]={"setpage","ATCLOG"}
