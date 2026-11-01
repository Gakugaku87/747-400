-- The alternate navigation's pages (6-1/6-2 step 11e; notes/ATA-34-61-FMC.md
-- §102): with no FMC to connect to (the MENU page without <FMC: FCOM
-- p.1275), the LEGS key shows the CDU's own ACT IRS LEGS (step 11e1: FCOM
-- p.1421-1424; FMSPG p.248-249; ATA34_2 p.589): the CDU's copy of the
-- active route (B747.68.altn_nav_model.lua, the FMS's B747_fms_altn) five
-- waypoints a page, each one's course (the active leg's by the heading
-- reference, M or T; the others T) and distance from the one before (none
-- for the active leg) in small font, its identifier and coordinates; the
-- entries and DELETE on 1L-5L, MOD IRS LEGS with <ERASE at 6L, EXEC.
local AN = B747_altn_nav_model
local BLANK = "                        "
local DISC_TITLE = "-- ROUTE DISCONTINUITY -"
local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function leg_index(pgNo, k) return (pgNo - 1) * AN.ROWS + k end

local function num_pages(s)
  return math.max(1, math.ceil((#AN.shown(s).legs + 1) / AN.ROWS))
end

-- the course in the CDU's form: the active leg's magnetic (the IRU's
-- variation: X-Plane's) unless the heading reference is TRUE, the others
-- true (FCOM p.1422-1423; FMSPG p.249)
local function crs_text(crs, active)
  if not crs then return "---`" end
  local c, ref = crs, "T"
  if active and B747DR_fms_hdg_ref_true <= 0.5 then
    c, ref = (crs + simDR_variation) % 360, "M"
  end
  local n = math.floor(c + 0.5) % 360
  return string.format("%03d`%s", n == 0 and 360 or n, ref)
end

-- a waypoint's line: its identifier and coordinates (one space less when
-- a long identifier needs it: estimate)
local function wpt_line(ident, lat, lon)
  local c = toDMS(lat, true) .. " " .. toDMS(lon, false)
  if #ident + 1 + #c > 24 then c = toDMS(lat, true) .. toDMS(lon, false) end
  if #ident + #c > 24 then return string.sub(ident .. c, 1, 24) end
  return ident .. string.rep(" ", 24 - #ident - #c) .. c
end

local function title(s)
  local t = (s.mod and "MOD" or "ACT") .. " IRS LEGS"
  return pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)
end

fmsPages["IRSLEGS"] = createPage("IRSLEGS")
fmsPages["IRSLEGS"].getNumPages = function(self, fmsID)
  return num_pages(B747_fms_altn(fmsID or "fmsL"))
end
fmsPages["IRSLEGS"].getPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn(fmsID)
  local r = AN.shown(s)
  local first = leg_index(pgNo, 1)
  local rows = AN.rows(s, first, AN.ROWS)
  local lines = {title(s)}
  for k = 1, AN.ROWS do
    local i = first + k - 1
    local row = rows[k]
    lines[#lines + 1] = BLANK
    if row and row.disc then
      lines[#lines + 1] = pad("*****")
    elseif row then
      lines[#lines + 1] = wpt_line(row.ident, row.lat, row.lon)
    elseif i == #r.legs + 1 then
      lines[#lines + 1] = pad("-----")
    else
      lines[#lines + 1] = BLANK
    end
  end
  lines[12] = s.mod and BLANK or "------------------------"
  lines[13] = s.mod and pad("<ERASE") or BLANK
  return lines
end
fmsPages["IRSLEGS"].getSmallPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn(fmsID)
  local r = AN.shown(s)
  local first = leg_index(pgNo, 1)
  local rows = AN.rows(s, first, AN.ROWS)
  local lines = {string.format("%23s ", pgNo .. "/" .. num_pages(s))}
  for k = 1, AN.ROWS do
    local i = first + k - 1
    local row = rows[k]
    local prev = r.legs[i - 1]
    local t = BLANK
    if row and row.disc then
      t = " THEN"
    elseif row and prev and prev.disc then
      t = DISC_TITLE
    elseif row then
      local dist = row.dist and string.format("%dNM", math.floor(row.dist + 0.5)) or ""
      t = pad(string.format(" %-7s%6s", crs_text(row.crs, i == 1), dist))
    end
    lines[#lines + 1] = pad(t)
    lines[#lines + 1] = BLANK
  end
  lines[12] = BLANK
  lines[13] = BLANK
  return lines
end
fmsFunctionsDefs["IRSLEGS"] = {}
for k = 1, AN.ROWS do fmsFunctionsDefs["IRSLEGS"]["L" .. k] = {"altnlegsfix", tostring(k)} end
fmsFunctionsDefs["IRSLEGS"]["L6"] = {"altnerase", ""}

-- the airplane's position by the CDU's own IRU (nil without one)
local function irs_pos(fmsO) return B747_fms_altn_pos(fmsO.id) end

function fmsFunctions.altnlegsfix(fmsO, value)
  local s = B747_fms_altn(fmsO.id)
  local i = leg_index(fmsO.pgNo, tonumber(value))
  local l = AN.shown(s).legs[i]
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if l and l.ident then fmsO["scratchpad"] = l.ident end
    return
  end
  local err
  if sp == "DELETE" then
    err = AN.delete(s, i)
  else
    err = AN.enter(s, i, sp, B747_route_model.parse_latlon(sp), irs_pos(fmsO))
  end
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end
function fmsFunctions.altnerase(fmsO, value)
  local s = B747_fms_altn(fmsO.id)
  if s.mod then AN.erase(s) end
end

-- IRS PROGRESS (step 11e2; FCOM p.1425-1426; FMSPG p.250-251): LAST and
-- its crossing altitude; TO, NEXT and DEST (MOD, ENROUTE WPT, DIR TO
-- ALTERNATE) with their distance and time to go at the IRU's ground speed
-- (blank without it); the CDU's IRU's position and ground speed; XTK
-- ERROR, DTK and TK by the heading reference (TK X-Plane's ground track:
-- the F/O's for the right CDU, estimate). 4L takes an alternate, gone
-- when the page is left
local function nm_text(d) return d and string.format("%dNM", math.floor(d + 0.5)) or "" end
local function ttg_text(d, gs)
  if not d or not gs or gs < 1 then return "" end
  local m = math.floor(d / gs * 60 + 0.5)
  return string.format("%02d:%02d", math.floor(m / 60), m % 60)
end
-- a true course by the heading reference ("250`M", "248`T")
local function ref_crs(c)
  if not c then return "" end
  local ref = "T"
  if B747DR_fms_hdg_ref_true <= 0.5 then c, ref = (c + simDR_variation) % 360, "M" end
  local n = math.floor(c + 0.5) % 360
  return string.format("%03d`%s", n == 0 and 360 or n, ref)
end
local function row(a, b, c) return string.format("%-7s%9s%8s", a or "", b or "", c or "") end
local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end

fmsPages["IRSPROG"] = createPage("IRSPROG")
fmsPages["IRSPROG"].getNumPages = function(self) return 1 end
fmsPages["IRSPROG"].getPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn(fmsID)
  -- the page left since its last drawing (not drawn the frame before):
  -- its alternate gone (FMSPG p.251)
  local f = B747_fms_frame_no()
  if s.prog_f and f - s.prog_f > 1 then s.alt = nil end
  s.prog_f = f
  local pos = B747_fms_altn_pos(fmsID)
  local gs = pos and pos.gs or nil
  local p = AN.progress(s, pos)
  local lines = {pad("      IRS PROGRESS")}
  local alt = s.last_alt and B747_cdu_model.format_alt(math.floor(s.last_alt + 0.5), trans_alt()) or ""
  lines[2], lines[3] = BLANK, row(s.last and s.last.ident or "", alt, "")
  lines[4], lines[5] = BLANK, p.to and row(p.to.ident, nm_text(p.to.dtg), ttg_text(p.to.dtg, gs)) or BLANK
  lines[6], lines[7] = BLANK, p.next and row(p.next.ident, nm_text(p.next.dtg), ttg_text(p.next.dtg, gs)) or BLANK
  lines[8], lines[9] = BLANK, p.dest and row(p.dest.ident, nm_text(p.dest.dtg), ttg_text(p.dest.dtg, gs)) or BLANK
  lines[10] = BLANK
  if pos then
    local at = toDMS(pos.lat, true) .. " " .. toDMS(pos.lon, false)
    local g = string.format("%dKT", math.floor(gs + 0.5))
    lines[11] = at .. string.rep(" ", math.max(1, 24 - #at - #g)) .. g
  else
    lines[11] = BLANK
  end
  lines[12] = BLANK
  local xtk = p.xtk and string.format("%s %.1fNM", p.xtk < 0 and "L" or "R", math.abs(p.xtk)) or ""
  local tk = B747_fms_altn_track(fmsID)
  if tk and B747DR_fms_hdg_ref_true > 0.5 then tk = (tk - simDR_variation) % 360 end
  local tk_text = ""
  if tk and pos then
    local n = math.floor(tk + 0.5) % 360
    tk_text = string.format("%03d`%s", n == 0 and 360 or n, B747DR_fms_hdg_ref_true > 0.5 and "T" or "M")
  end
  lines[13] = string.format("%-10s%6s%8s", xtk, ref_crs(p.dtk), tk_text)
  return lines
end
fmsPages["IRSPROG"].getSmallPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn(fmsID)
  local p = AN.progress(s, B747_fms_altn_pos(fmsID))
  local lines = {BLANK}
  lines[2], lines[3] = row(" LAST", "ALT", ""), BLANK
  lines[4], lines[5] = row(" TO", "DTG", "TTG"), BLANK
  lines[6], lines[7] = pad(" NEXT"), BLANK
  lines[8], lines[9] = pad(" " .. (p.dest and p.dest.title or "DEST")), BLANK
  local h = " IRS " .. B747_fms_altn_iru(fmsID)
  lines[10], lines[11] = h .. string.rep(" ", 24 - #h - 2) .. "GS", BLANK
  lines[12], lines[13] = string.format("%-10s%6s%8s", " XTK ERROR", "DTK", "TK"), BLANK
  return lines
end
fmsFunctionsDefs["IRSPROG"] = {}
fmsFunctionsDefs["IRSPROG"]["L4"] = {"altnprogdest", ""}
function fmsFunctions.altnprogdest(fmsO, value)
  local s = B747_fms_altn(fmsO.id)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then fmsO["notify"] = AN.INVALID_DELETE return end
  local err = AN.set_alternate(s, sp, B747_route_model.parse_latlon(sp))
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end

-- ALTN NAV RADIO (step 11e3; FCOM p.1427-1428; FMSPG p.252-254; ATA34_2
-- p.592; B747.68.altn_radio_model.lua through the FMS's
-- B747_fms_altn_radio): VOR with M, CRS, ADF with ANT or BFO (the three
-- blank on the centre CDU), ILS-MLS frequency/course or PARK, PRESELECT
-- 6L and 6R; an entry tunes the CDU's side at once (B747_fms_altn_tune)
local AR = B747_altn_radio_model
local TM = B747_tune_model
fmsPages["ALTNRAD"] = createPage("ALTNRAD")
fmsPages["ALTNRAD"].getNumPages = function(self) return 1 end
fmsPages["ALTNRAD"].getPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn_radio(fmsID)
  local side = B747_fms_altn_side(fmsID) ~= nil
  local lines = {pad("     ALTN NAV RADIO"), BLANK}
  lines[3] = side and pad(s.vor.freq and TM.freq_text(s.vor.freq) or "------") or BLANK
  lines[4] = BLANK
  lines[5] = side and pad(s.vor.crs and string.format("%03d", s.vor.crs) or "---") or BLANK
  lines[6] = BLANK
  lines[7] = side and pad(s.adf.khz and TM.adf_text(s.adf.khz) or "------") or BLANK
  lines[8] = BLANK
  lines[9] = pad(s.ils.freq and TM.ils_text({freq = s.ils.freq, crs = s.ils.crs or 0}) or "PARK")
  lines[10], lines[11], lines[12] = BLANK, BLANK, BLANK
  local p1, p2 = s.pre[1] or "------", s.pre[2] or "------"
  lines[13] = p1 .. string.rep(" ", math.max(1, 24 - #p1 - #p2)) .. p2
  return lines
end
fmsPages["ALTNRAD"].getSmallPage = function(self, pgNo, fmsID)
  local s = B747_fms_altn_radio(fmsID)
  local side = B747_fms_altn_side(fmsID) ~= nil
  local lines = {BLANK}
  lines[2] = side and pad(" VOR") or BLANK
  -- the VOR's M after its frequency (FCOM p.1427's figure)
  lines[3] = (side and s.vor.freq) and pad(string.rep(" ", #TM.freq_text(s.vor.freq)) .. "M") or BLANK
  lines[4] = side and pad(" CRS") or BLANK
  lines[5] = BLANK
  lines[6] = side and pad(" ADF") or BLANK
  local mode = s.adf.mode ~= "ADF" and s.adf.mode or ""
  lines[7] = (side and s.adf.khz) and pad(string.rep(" ", #TM.adf_text(s.adf.khz)) .. mode) or BLANK
  lines[8] = pad(" ILS-MLS")
  lines[9], lines[10], lines[11] = BLANK, BLANK, BLANK
  lines[12] = pad("       PRESELECT")
  lines[13] = BLANK
  return lines
end
fmsFunctionsDefs["ALTNRAD"] = {}
fmsFunctionsDefs["ALTNRAD"]["L1"] = {"altnrad", "vor"}
fmsFunctionsDefs["ALTNRAD"]["L2"] = {"altnrad", "crs"}
fmsFunctionsDefs["ALTNRAD"]["L3"] = {"altnrad", "adf"}
fmsFunctionsDefs["ALTNRAD"]["L4"] = {"altnrad", "ils"}
fmsFunctionsDefs["ALTNRAD"]["L6"] = {"altnradpre", "1"}
fmsFunctionsDefs["ALTNRAD"]["R6"] = {"altnradpre", "2"}
-- the VOR, CRS and ADF lines: the left and right CDUs only
local SIDE_ONLY = {vor = true, crs = true, adf = true}
function fmsFunctions.altnrad(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if SIDE_ONLY[value] and not B747_fms_altn_side(fmsO.id) then fmsO["notify"] = AR.INVALID return end
  local s = B747_fms_altn_radio(fmsO.id)
  local err = AR[value](s, sp, value == "ils" and B747_fms_altn_rwy_crs() or nil)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
  B747_fms_altn_tune(fmsO.id)
end
-- PRESELECT: an entry kept; with an empty scratchpad down-selected into it
function fmsFunctions.altnradpre(fmsO, value)
  local k = tonumber(value)
  local s = B747_fms_altn_radio(fmsO.id)
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if s.pre[k] then fmsO["scratchpad"] = s.pre[k] end
    return
  end
  local err = AR.preselect(s, k, sp)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
end

-- the keys of a CDU without an FMC to connect to (B744.createfms.lua's
-- pageKey; FCOM p.1275): LEGS the IRS LEGS page, PROG IRS PROGRESS
-- (step 11e2), NAV RAD ALTN NAV RADIO (step 11e3), EXEC IRS LEGS's
-- modification; true when taken
local ALTN_PAGE = {legs = "IRSLEGS", prog = "IRSPROG", navrad = "ALTNRAD"}
function B747_cdu_altn_key(fmsO, key)
  if ALTN_PAGE[key] then
    fmsO.targetCustomFMC = true
    fmsO.targetPage = ALTN_PAGE[key]
    fmsO.targetpgNo = 1
    return true
  end
  if key == "exec" and fmsO.currentPage == "IRSLEGS" then
    AN.exec(B747_fms_altn(fmsO.id))
    return true
  end
  return false
end
