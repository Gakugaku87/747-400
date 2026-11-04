-- OFFPATH DES (2026-11-04; notes/ATA-34-61-FMC.md §143): a descent direct
-- to a waypoint analysed, its clean and drag ranges on the page and the ND
-- (FCOM p.1398-1399; FMSPG p.190-194):
--  - DES TO (1L): the DES page's E/D (B747_fms_vnav_wpts' ed: the last
--    descent waypoint with an altitude constraint, FCOM p.1398), or a
--    waypoint of the database entered (SELECT DESIRED WPT, NOT IN DATA
--    BASE); DELETE back to the E/D (FMSPG p.192); boxes without either. Its
--    direct distance in the centre (DTG). Within 150 ft of its altitude, an
--    entered waypoint gives way to the E/D (FMSPG p.192).
--  - SPD/ALT (1R): the E/D's constraint, or an entered waypoint's when it
--    is an active route waypoint with one; else boxes, a speed and altitude
--    to enter (FCOM p.1399).
--  - ECON SPD, SPD TRANS, SPD RESTR (2L-4L): the DES page's, entered the
--    same way (FCOM p.1398); <ECON at 5L with SEL SPD (FMSPG p.193).
--  - CLEAN CIRCLE (2R), DRAG CIRCLE (3R): the distance to the circles round
--    the fix where a clean idle descent and one with full speedbrakes from
--    the present altitude reach its altitude and speed (negative inside),
--    the drag one once inside the clean one (FCOM p.1399; FMSPG p.193):
--    B747_pred_model.offpath (the speedbrakes' drag an estimate).
--  - FORECAST> (5R), <DES (6L), DISPLAY SELECT ON>/OFF> (6R): the circles
--    on the ND (the clean one, the drag one once inside the clean one:
--    FMSPG p.194).
-- Estimates: the descent's headwind the DES page's predictions' (not the
-- route's winds), the weight now; the circles anew each second.
local R = B747_route_model
local BLANK = "                        "
local function pad(s) return string.sub((s or "") .. BLANK, 1, 24) end
local function put(t, col, s) return string.sub(t, 1, col - 1) .. s .. string.sub(t, col + #s) end
local function lr(l, r) return string.sub(l .. string.rep(" ", 24 - #l - #r) .. r, 1, 24) end
local function trans_lvl() return B747_fms_trans_lvl and B747_fms_trans_lvl() or 18000 end

-- the page's state: an entered waypoint (a database record), its entered
-- speed and altitude, the ND's display
local offpath = {fix = nil, spd = nil, alt = nil, display = false}
-- the last computation (each second): the target {fix, alt, spd, ed},
-- DTG, the clean and drag radii
local calc = {t = -100}

-- the waypoint, its altitude and speed: the entered one, else the E/D
local function target()
  if offpath.fix then
    local f = offpath.fix
    local alt, spd = offpath.alt, offpath.spd
    if not alt then
      for _, l in ipairs(B747_fmc_route.rte.legs) do
        if l.fix and l.fix.ident == f.ident and math.abs(l.fix.lat - f.lat) < 1e-4
            and math.abs(l.fix.lon - f.lon) < 1e-4 and l.alt then
          alt = l.akind == "AB" and math.min(l.alt, l.alt2 or l.alt) or l.alt
          spd = spd or l.spd
          break
        end
      end
    end
    return {fix = f, alt = alt, spd = spd, ed = false}
  end
  local wp = B747_fms_vnav_wpts and B747_fms_vnav_wpts() or {}
  local e = wp.ed
  local l = e and B747_fmc_route.rte.legs[e.i]
  if l and l.fix then return {fix = l.fix, alt = e.alt, spd = l.spd, ed = true} end
  return nil
end

-- the target, DTG and radii anew (each second; at once after an entry)
local function update(force)
  if not force and simDRTime - calc.t < 1 then return calc end
  calc = {t = simDRTime}
  local t = target()
  -- an entered waypoint within 150 ft of its altitude: the E/D again
  if t and not t.ed and t.alt and math.abs(simDR_pressureAlt1 - t.alt) < 150 then
    offpath.fix, offpath.spd, offpath.alt = nil, nil, nil
    t = target()
  end
  calc.target = t
  if not t then return calc end
  local _, d = R.course(simDR_latitude, simDR_longitude, t.fix.lat, t.fix.lon)
  calc.dtg = d
  local s = B747_fms_pred_input_last and B747_fms_pred_input_last()
  if t.alt and s then
    local gw = s.gw
    calc.clean = B747_pred_model.offpath(s, gw, simDR_pressureAlt1, t.alt, t.spd, false)
    calc.drag = B747_pred_model.offpath(s, gw, simDR_pressureAlt1, t.alt, t.spd, true)
  end
  return calc
end

local function spd_label(id)
  local mode = fmsModules["data"][id]
  return mode == "S" and " SEL SPD " or mode == "L" and " LRC SPD " or " ECON SPD"
end
local function nm_signed(d) return string.format("%d", d >= 0 and math.floor(d + 0.5) or -math.floor(-d + 0.5)) end

fmsPages["OFFPATH"] = createPage("OFFPATH")
fmsPages["OFFPATH"].getNumPages = function(self) return 1 end
fmsPages["OFFPATH"].getPage = function(self, pgNo, fmsID)
  local c = update(false)
  local t = c.target
  local L3 = pad("*****")
  if t then
    L3 = pad(t.fix.ident)
    if c.dtg then
      local d = string.format("%d", math.floor(c.dtg + 0.5))
      L3 = put(L3, 15 - #d, d)
    end
    local a = t.alt and B747_cdu_model.format_alt(t.alt, trans_lvl())
    local sa
    if a then
      sa = (t.spd and string.format("%d", t.spd) or "---") .. "/" .. string.rep(" ", math.max(0, 5 - #a)) .. a
    else
      sa = "***/*****"
    end
    L3 = put(L3, 25 - #sa, sa)
  end
  local data = fmsModules["data"]
  local L5 = pad("." .. data["desspdmach"] .. "/" .. data["desspd"])
  local L7 = pad(data["destranspd"] .. "/" .. data["desspdtransalt"])
  if c.clean and c.dtg then
    local v = nm_signed(c.dtg - c.clean)
    L5 = put(L5, 15 - #v, v)
    -- the drag circle's distance once inside the clean circle (FMSPG p.193)
    if c.drag and c.dtg < c.clean then
      local w = nm_signed(c.dtg - c.drag)
      L7 = put(L7, 15 - #w, w)
    end
  end
  local mode = data["desspdmode"]
  fmsFunctionsDefs["OFFPATH"]["L5"] = mode == "S" and {"vnavspd", "des"} or nil
  return {
    "       OFFPATH DES      ",
    BLANK,
    L3,
    BLANK,
    L5,
    BLANK,
    L7,
    BLANK,
    pad(data["desrestspd"] .. "/" .. data["desrestalt"]),
    "------------------------",
    lr(mode == "S" and "<ECON" or "", "FORECAST>"),
    BLANK,
    lr("<DES", offpath.display and "SELECT OFF>" or "SELECT ON>"),
  }
end
fmsPages["OFFPATH"].getSmallPage = function(self, pgNo, fmsID)
  return {
    BLANK,
    " DES TO    DTG   SPD/ALT",
    BLANK,
    spd_label("desspdmode") .. " CLEAN CIRCLE  ",
    BLANK,
    " SPD TRANS DRAG CIRCLE  ",
    BLANK,
    " SPD RESTR              ",
    BLANK,
    BLANK,
    BLANK,
    "                 DISPLAY",
    BLANK,
  }
end

fmsFunctionsDefs["OFFPATH"] = {}
fmsFunctionsDefs["OFFPATH"]["L1"] = {"offpathfix", ""}
fmsFunctionsDefs["OFFPATH"]["R1"] = {"offpathspdalt", ""}
fmsFunctionsDefs["OFFPATH"]["L2"] = {"setdata", "desspds"}
fmsFunctionsDefs["OFFPATH"]["L3"] = {"setdata", "destrans"}
fmsFunctionsDefs["OFFPATH"]["L4"] = {"setdata", "desrest"}
fmsFunctionsDefs["OFFPATH"]["R5"] = {"setpage", "DESFORECAST"}
fmsFunctionsDefs["OFFPATH"]["L6"] = {"offpathdes", ""}
fmsFunctionsDefs["OFFPATH"]["R6"] = {"offpathdisplay", ""}

-- 1L DES TO: a waypoint of the database; DELETE: the E/D again; an empty
-- scratchpad copies the waypoint
function fmsFunctions.offpathfix(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then
    local t = update(true).target
    if t then fmsO["scratchpad"] = t.fix.ident end
    return
  end
  if sp == "DELETE" then
    if not offpath.fix then fmsO["notify"] = "INVALID DELETE" return end
    offpath.fix, offpath.spd, offpath.alt = nil, nil, nil
    fmsO["scratchpad"] = ""
    update(true)
    return
  end
  if not string.match(sp, "^%w%w?%w?%w?%w?$") then fmsO["notify"] = "NOT IN DATA BASE" return end
  local list = R.candidates(B747_fmc_route, sp, simDR_latitude, simDR_longitude, true)
  B747_fmc_with_point(fmsO, sp, nil, function(p)
    offpath.fix, offpath.spd, offpath.alt = p, nil, nil
    fmsO["scratchpad"] = ""
    update(true)
  end, list)
end

-- 1R SPD/ALT: speed/altitude, /altitude or speed/ for an entered waypoint
-- (FCOM p.1399: boxes for a waypoint without a constraint); DELETE: the
-- route's constraint again
function fmsFunctions.offpathspdalt(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if not offpath.fix then fmsO["notify"] = "INVALID ENTRY" return end
  if sp == "DELETE" then
    offpath.spd, offpath.alt = nil, nil
    fmsO["scratchpad"] = ""
    update(true)
    return
  end
  local s, a = string.match(sp, "^(%d*)/(.*)$")
  if not s then fmsO["notify"] = "INVALID ENTRY" return end
  local spd = tonumber(s)
  local alt = a ~= "" and B747_cdu_model.parse_alt(a) or nil
  if (s ~= "" and not (spd and spd >= 100 and spd <= 399)) or (a ~= "" and not alt) or (not spd and not alt) then
    fmsO["notify"] = "INVALID ENTRY"
    return
  end
  if spd then offpath.spd = spd end
  if alt then offpath.alt = alt end
  fmsO["scratchpad"] = ""
  update(true)
end

-- 6L <DES
function fmsFunctions.offpathdes(fmsO, value)
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "VNAV"
  fmsO.targetpgNo = 3
end

-- 6R DISPLAY SELECT ON>/OFF>
function fmsFunctions.offpathdisplay(fmsO, value)
  offpath.display = not offpath.display
end

-- the energy management circles for the ND (FMSPG p.194: the clean one,
-- the drag one once the airplane is inside the clean one; FCOM p.1150: the
-- clean blue, the drag white), {lat, lon, r, pen} each
function B747_fms_offpath_nd()
  if not offpath.display then return {} end
  local c = update(false)
  local t = c.target
  if not (t and c.clean) then return {} end
  local D = B747_nd_line_model
  local out = {{lat = t.fix.lat, lon = t.fix.lon, r = c.clean, pen = D.CLEAN}}
  if c.drag and c.dtg and c.dtg < c.clean then
    out[#out + 1] = {lat = t.fix.lat, lon = t.fix.lon, r = c.drag, pen = D.DRAG}
  end
  return out
end
