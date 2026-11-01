-- EMERGENCY REPORT, VERIFY EMERGENCY and XXXXZ EMERGENCY (6-1/6-2 step
-- 12g4; FCOM p.728-733; FMSPG p.345-356; B747.68.atc_emergency_model.lua
-- through the FMS's B747_fms_emergency: one in the FMC, both CDUs').
-- EMERGENCY REPORT: <MAYDAY and PAN> (VERIFY EMERGENCY at once; the other
-- blank once one is selected), DIVERT TO (the active destination with its
-- caret, or a position entered), OFFSET, DESCEND TO (the MCP altitude with
-- its caret, or one entered), SOB, FUEL REMAINING (the FMC's quantity and
-- time once SOB is in, the time enterable), <ERASE EMERGENCY or <CANCEL
-- EMERGENCY (in the emergency mode with nothing selected), <INDEX,
-- VERIFY>; nothing changed while SENDING. VERIFY EMERGENCY: the report's
-- lines, the free text, REPORT SEND> on the last page (then EMERGENCY
-- REPORT: FCOM p.732), CONTINUED before it, 6L <EMERGENCY. XXXXZ
-- EMERGENCY: the time, STATUS, the text, LOG>. Estimates: the FMC's values
-- small, the crew's and the selected large; the lines' columns; no PRINT.
-- Before, the pages wrote FMS data fields unchecked and VERIFY the shared
-- text while drawing (CDU-34)
local E = B747_atc_emergency_model
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
local function centre(t) return put(BLANK, math.floor((24 - #t) / 2) + 1, t) end
local function pageno(pg, n) return string.format("%24s", pg .. "/" .. n .. " ") end
local function ctx() return B747_fms_emergency_ctx() end
local function em() return B747_fms_emergency() end

-- EMERGENCY REPORT (FCOM p.728-730; FMSPG p.347-350)
fmsPages["ATCEMERGENCYREPORT"]=createPage("ATCEMERGENCYREPORT")
fmsPages["ATCEMERGENCYREPORT"].getPage=function(self,pgNo,fmsID)
  local e, c = em(), ctx()
  local out = blank13()
  out[1] = centre("EMERGENCY REPORT")
  out[3] = right(e.mayday and left(BLANK, "MAYDAY") or BLANK, e.pan and "PAN" or "")
  local div = e.divert or ((e.divert_sel and c.dest) or nil)
  out[5] = right(div and left(BLANK, div) or BLANK, e.sob or "---")
  out[7] = left(BLANK, e.offset or "---")
  if e.sob and e.fuel then out[7] = right(out[7], e.fuel) end
  local dsc = e.descend or ((e.descend_sel and c.mcp) or nil)
  if dsc then out[9] = left(BLANK, dsc) end
  if e.cancel then out[11] = left(BLANK, "CANCEL EMERGENCY")
  elseif E.any(e) then out[11] = left(BLANK, "<ERASE EMERGENCY")
  elseif B747_fms_emergency_mode() then out[11] = left(BLANK, "<CANCEL EMERGENCY") end
  out[13] = "<INDEX           VERIFY>"
  return out
end
fmsPages["ATCEMERGENCYREPORT"].getSmallPage=function(self,pgNo,fmsID)
  local e, c = em(), ctx()
  local out = blank13()
  local mp = (not e.mayday and not e.pan) and left(BLANK, "<MAYDAY") or BLANK
  out[3] = right(e.pan and BLANK or mp, (not e.mayday and not e.pan) and "PAN>" or "")
  out[4] = right(left(BLANK, " DIVERT TO"), "SOB")
  if not e.divert and not e.divert_sel and c.dest then out[5] = left(BLANK, "<" .. c.dest) end
  out[6] = right(left(BLANK, " OFFSET"), "FUEL REMAINING")
  if e.sob then
    local q = c.fuel_k and string.format("%.1f%s", c.fuel_k, c.unit) or ""
    local t = e.fuel and "" or (c.endurance or "**+**")
    out[7] = right(BLANK, q .. " " .. string.rep(" ", e.fuel and 5 or 0) .. t)
  end
  out[8] = left(BLANK, " DESCEND TO")
  if not e.descend and not e.descend_sel and c.mcp then out[9] = left(BLANK, "<" .. c.mcp) end
  out[12] = "------------------------"
  return out
end
fmsFunctionsDefs["ATCEMERGENCYREPORT"]={}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L1"]={"atcemer","mayday"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["R1"]={"atcemer","pan"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L2"]={"atcemer","divert"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L3"]={"atcemer","offset"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L4"]={"atcemer","descend"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L5"]={"atcemer","erase"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["R2"]={"atcemer","sob"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["R3"]={"atcemer","fuel"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["L6"]={"setpage","ATCINDEX"}
fmsFunctionsDefs["ATCEMERGENCYREPORT"]["R6"]={"setpage","ATCVERIFYEMERGENCY"}
function fmsFunctions.atcemer(fmsO, value)
  -- nothing changed while SENDING (FMSPG p.347)
  if B747_fms_emergency_sending() then return end
  local e, c = em(), ctx()
  local sp = fmsO["scratchpad"]
  local err
  if value == "erase" then
    -- 5L: CANCEL EMERGENCY (DELETE deselects it), else ERASE EMERGENCY
    if sp == "DELETE" then err = E.delete(e, "cancel")
    elseif e.cancel or sp ~= "" then return
    elseif E.any(e) then E.erase(e) return
    else err = E.select(e, "cancel", c, B747_fms_emergency_mode()) end
  elseif sp == "DELETE" then
    err = E.delete(e, value)
  elseif value == "mayday" or value == "pan" then
    if sp ~= "" then err = E.INVALID
    else
      err = E.select(e, value, c)
      if not err and e[value] then fmsFunctions.setpage(fmsO, "ATCVERIFYEMERGENCY") end
    end
  elseif value == "divert" then
    if sp == "" then err = E.select(e, "divert", c)
    else
      B747_fmc_with_fix(fmsO, sp, nil, function()
        local x = E.set_divert(em(), sp, ctx())
        if x then fmsO["notify"] = x else fmsO["scratchpad"] = "" end
      end)
      return
    end
  elseif value == "descend" and sp == "" then
    err = E.select(e, "descend", c)
  elseif sp == "" then
    return
  else
    err = E.enter(e, value, sp, c)
  end
  if err then fmsO["notify"] = err return end
  if sp ~= "" then fmsO["scratchpad"] = "" end
end

-- VERIFY EMERGENCY (FCOM p.731-733; FMSPG p.351-352)
local function vrows() return E.verify_rows(em(), ctx(), not B747_fms_emergency_sending()) end
local function vpages(rows) return math.max(1, math.ceil(#rows / 5)) end
fmsPages["ATCVERIFYEMERGENCY"]=createPage("ATCVERIFYEMERGENCY")
fmsPages["ATCVERIFYEMERGENCY"].getNumPages=function(self) return vpages(vrows()) end
fmsPages["ATCVERIFYEMERGENCY"].getPage=function(self,pgNo,fmsID)
  local rows = vrows()
  local np = vpages(rows)
  local out = blank13()
  out[1] = title("VERIFY EMERGENCY")
  for k = 1, 5 do
    local row = rows[(pgNo - 1) * 5 + k]
    if row then out[1 + 2 * k] = left(BLANK, row.data) end
  end
  if pgNo == np then out[11] = right(out[11], (B747_fms_emergency_status())) end
  out[13] = left(BLANK, "<EMERGENCY")
  return out
end
fmsPages["ATCVERIFYEMERGENCY"].getSmallPage=function(self,pgNo,fmsID)
  local rows = vrows()
  local np = vpages(rows)
  local out = blank13()
  out[1] = pageno(pgNo, np)
  for k = 1, 5 do
    local row = rows[(pgNo - 1) * 5 + k]
    if row and row.head ~= "" then out[2 * k] = left(BLANK, #row.head < 24 and (" " .. row.head) or row.head) end
  end
  if pgNo == np then
    local st, head = B747_fms_emergency_status()
    if st ~= "" then out[10] = right(BLANK, head) end
  end
  out[12] = pgNo < np and "-------CONTINUED--------" or "------------------------"
  return out
end
fmsFunctionsDefs["ATCVERIFYEMERGENCY"]={}
for k = 1, 5 do fmsFunctionsDefs["ATCVERIFYEMERGENCY"]["L" .. k]={"atcverifyemer","L" .. k} end
fmsFunctionsDefs["ATCVERIFYEMERGENCY"]["R5"]={"atcverifyemer","send"}
fmsFunctionsDefs["ATCVERIFYEMERGENCY"]["L6"]={"setpage","ATCEMERGENCYREPORT"}
function fmsFunctions.atcverifyemer(fmsO, value)
  local rows = vrows()
  local pg = fmsO.pgNo or 1
  if value == "send" then
    -- SEND: the report, then EMERGENCY REPORT (FCOM p.732)
    if pg == vpages(rows) and B747_fms_emergency_send(fmsO) then fmsFunctions.setpage(fmsO, "ATCEMERGENCYREPORT") end
    return
  end
  if B747_fms_emergency_sending() then return end
  local row = rows[(pg - 1) * 5 + tonumber(string.sub(value, 2))]
  local sp = fmsO["scratchpad"]
  if not row or sp == "" then return end
  local e = em()
  local err
  if row.free then
    err = E.set_free(e, row.free, sp)
  elseif sp == "DELETE" and row.data == "MAYDAY MAYDAY MAYDAY" then
    err = E.delete(e, "mayday")
  elseif sp == "DELETE" and row.data == "PAN PAN PAN" then
    err = E.delete(e, "pan")
  else
    err = E.INVALID
  end
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end

-- XXXXZ EMERGENCY (FMSPG p.353): a report sent
local function shown(fmsID) return B747_fms_emergency_shown(fmsID) end
local function spages(d)
  if #d.rows <= 4 then return 1 end
  return 1 + math.ceil((#d.rows - 4) / 5)
end
local function spage_rows(d, pg)
  local from, n, line = 1, 4, 2
  if pg > 1 then from, n, line = 5 + (pg - 2) * 5, 5, 1 end
  local out = {}
  for k = from, math.min(#d.rows, from + n - 1) do out[#out + 1] = d.rows[k] end
  return out, line
end
fmsPages["ATCEMERGENCYLOG"]=createPage("ATCEMERGENCYLOG")
fmsPages["ATCEMERGENCYLOG"].getNumPages=function(self,fmsID)
  local d = shown(fmsID)
  return d and spages(d) or 1
end
fmsPages["ATCEMERGENCYLOG"].getPage=function(self,pgNo,fmsID)
  local out = blank13()
  out[13] = right(BLANK, "LOG>")
  local d = shown(fmsID)
  if not d then out[1] = title("EMERGENCY") return out end
  out[1] = title(d.time .. "Z EMERGENCY")
  if pgNo == 1 then out[3] = right(BLANK, d.status) end
  local list, first = spage_rows(d, pgNo)
  for k, row in ipairs(list) do out[1 + 2 * (first + k - 1)] = left(BLANK, row.data) end
  return out
end
fmsPages["ATCEMERGENCYLOG"].getSmallPage=function(self,pgNo,fmsID)
  local out = blank13()
  local d = shown(fmsID)
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
fmsFunctionsDefs["ATCEMERGENCYLOG"]={}
fmsFunctionsDefs["ATCEMERGENCYLOG"]["R6"]={"setpage","ATCLOG"}
