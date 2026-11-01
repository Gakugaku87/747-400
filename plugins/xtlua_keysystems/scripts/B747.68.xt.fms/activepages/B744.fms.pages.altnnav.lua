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

-- the keys of a CDU without an FMC to connect to (B744.createfms.lua's
-- pageKey; FCOM p.1275): LEGS the IRS LEGS page, EXEC its modification;
-- true when taken
function B747_cdu_altn_key(fmsO, key)
  if key == "legs" then
    fmsO.targetCustomFMC = true
    fmsO.targetPage = "IRSLEGS"
    fmsO.targetpgNo = 1
    return true
  end
  if key == "exec" and fmsO.currentPage == "IRSLEGS" then
    AN.exec(B747_fms_altn(fmsO.id))
    return true
  end
  return false
end
