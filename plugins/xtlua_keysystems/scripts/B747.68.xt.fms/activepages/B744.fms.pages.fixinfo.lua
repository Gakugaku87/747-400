-- FIX INFO (6-1/6-2 step 7e3b; notes/ATA-34-61-FMC.md §39): two pages of a
-- fix each, its bearings and distances and where they cross the active
-- route (FCOM p.1358-1359; FMSPG p.166-169).
--  - The FIX key; NEXT and PREV between the two pages (FMSPG p.168).
--  - FIX (1L): an airport, a navaid or a waypoint of the database (FCOM
--    p.1358): boxes, SELECT DESIRED WPT, NOT IN DATA BASE; no DELETE
--    (FMSPG p.167: <ERASE FIX only); an empty scratchpad copies it.
--  - BRG/DIS FR (1R): the airplane's bearing and distance from the fix.
--  - BRG/DIS (2L-4L): a bearing XXX (000-360), a distance /YYY, or both
--    (FCOM p.1358-1359). A bearing's crossing of the active route within
--    512 nm of the fix: its distance in small font after the slash; a
--    distance's crossing nearest the airplane: its bearing in small font
--    before it (FMSPG p.167; FCOM p.1358's figure); DTG to it, negative
--    once passed (FMSPG p.168); both entered: no crossing. An empty
--    scratchpad copies the place/bearing/distance (ABC180.0/026.4: FCOM
--    p.1359) for the RTE and LEGS pages; DELETE takes it back to dashes.
--  - <ABEAM (5L): the bearing and distance of the active route's point
--    square to its nearest segment and DTG; INVALID ENTRY without one
--    (FMSPG p.168); pushed again, its place/bearing/distance copied (FCOM
--    p.1359); DELETE takes it back to the prompt.
--  - <ERASE FIX (6L): the page's fix and lines gone, not PRED ETA-ALT
--    (FMSPG p.168).
--  - PRED ETA-ALT (6R): a time (hhmmZ) or an altitude, kept (FMSPG p.169).
-- The fixes are the FMC's (both CDUs show them). The bearings magnetic: a
-- VOR's own variation, else the nearest VOR's (estimate; true near the
-- poles comes with step 10).
-- (2026-11-04; notes/ATA-34-61-FMC.md §143) a crossing's ETA and predicted
-- altitude, PRED ETA-ALT's distance along the route (the predictions'
-- profile, B747_fms_pred_at and the like), and the ND's fixes, radials,
-- circles and PRED points (B747_fms_fix_nd). Estimates: the route's path
-- its waypoints' great circles from the active leg's start to the first
-- discontinuity (B747.68.route_model.lua); the crossing nearest the
-- airplane along it; a new fix clears the lines; a distance without a
-- crossing shows no bearing; the lines blank without a fix; a passed
-- crossing's ETA and ALT blank; the profile straight between the
-- predictions' points.
-- Before: X-Plane's FIX page shown through.
local R = B747_route_model
local BLANK = "                        "

local function pad(s) return string.sub((s or "") .. BLANK, 1, 24) end
local function put(t, col, s) return string.sub(t, 1, col - 1) .. s .. string.sub(t, col + #s) end
local function airplane() return {lat = simDR_latitude, lon = simDR_longitude} end
local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end

local MAX_RADIAL = 512
-- the two pages: fix (a database record), lines[1..3] {brg (magnetic, as
-- entered), dist}, abeam (pushed), pred {time "hhmm" or alt (feet)}
local fixPages = {{lines = {}}, {lines = {}}}

-- a fix's variation (east positive)
local function variation(f)
  if f.kind == "VOR" and f.var then return f.var end
  return B747_navdb.variation(B747_fmc_navdb, f.lat, f.lon) or 0
end
local function mag_of(f, crs) return (crs - variation(f)) % 360 end
local function true_of(f, brg) return (brg + variation(f)) % 360 end
local function brg3(b)
  local n = math.floor(b + 0.5) % 360
  return string.format("%03d", n == 0 and 360 or n)
end
local function nm(d) return string.format("%d", math.floor(d + 0.5)) end
-- the place/bearing/distance for the scratchpad (FCOM p.1359's figure)
local function pbd_text(f, brg, dist)
  local b = math.floor(brg * 10 + 0.5) / 10
  if b <= 0 or b > 360 then b = 360 end
  return string.format("%s%05.1f/%05.1f", f.ident, b, math.floor(dist * 10 + 0.5) / 10)
end

-- a line's crossing of the path: {brg, dist (from the fix), dtg}; nil
-- for a bearing and a distance both entered or no crossing
local function crossing(f, e, path)
  if not path or (e.brg and e.dist) then return nil end
  if e.brg then
    local x = R.fix_radial(path, f, true_of(f, e.brg), MAX_RADIAL)
    if not x then return nil end
    local _, d = R.course(f.lat, f.lon, x.lat, x.lon)
    return {brg = e.brg, dist = d, dtg = x.dtg}
  end
  local x = R.fix_circle(path, f, e.dist)
  if not x then return nil end
  return {brg = mag_of(f, (R.course(f.lat, f.lon, x.lat, x.lon))), dist = e.dist, dtg = x.dtg}
end
local function abeam_point(f, path)
  local x = path and R.fix_abeam(path, f)
  if not x then return nil end
  local c, d = R.course(f.lat, f.lon, x.lat, x.lon)
  return {brg = mag_of(f, c), dist = d, dtg = x.dtg}
end

-- (2026-11-04) the predictions at a crossing ahead (FCOM p.1359; FMSPG
-- p.168): its ETA (hhmm, UTC) and altitude (ft, to 10 ft), nil without
-- predictions or once passed (estimate: blank, its DTG negative)
local function hhmm(min)
  local m = math.floor(min + 0.5) % 1440
  return string.format("%02d%02d", math.floor(m / 60), m % 60)
end
local function at_crossing(dtg)
  if not dtg or dtg < 0 or not B747_fms_pred_at then return nil end
  local h, t = B747_fms_pred_at(dtg)
  if not h then return nil end
  return hhmm(B747_fms_utc_min() + t / 60), math.floor(h / 10 + 0.5) * 10
end
-- PRED ETA-ALT's point (FCOM p.1359; FMSPG p.169): NM along the route to
-- where the predictions reach the entered altitude or time, nil if they do
-- not. A time an hour or more before now counts as the next day's
-- (estimate)
local function pred_x(p)
  if not p or not B747_fms_pred_alt_x then return nil end
  if p.alt then return B747_fms_pred_alt_x(p.alt) end
  local h, m = tonumber(string.sub(p.time, 1, 2)), tonumber(string.sub(p.time, 3, 4))
  local dmin = (h * 60 + m - B747_fms_utc_min()) % 1440
  return B747_fms_pred_time_x(dmin * 60)
end
-- each page's PRED ETA-ALT point, the entry back to dashes once a valid
-- point is passed (FMSPG p.169: with predictions, no crossing ahead any more)
local function pred_point(pg)
  local x = pred_x(pg.pred)
  if pg.pred then
    if x then
      pg.pred.seen = true
    elseif pg.pred.seen and B747_fms_preds and B747_fms_preds() then
      pg.pred = nil
    end
  end
  return x
end

-- a crossing's ETA (cols 9-12, its z small at 13) and ALT (to col 24) on
-- its line (FCOM p.1358's figure: 130/24 2004z 10 12000)
local function eta_alt(l, s, dtg)
  local eta, alt = at_crossing(dtg)
  if not eta then return l, s end
  local a = B747_cdu_model.format_alt(alt, trans_alt())
  return put(put(l, 9, eta), 25 - #a, a), put(s, 13, "z")
end

-- the page's large and small lines
local function page_lines(pgNo)
  local pg = fixPages[pgNo]
  local L, S = {}, {}
  for n = 1, 13 do L[n], S[n] = BLANK, BLANK end
  L[1] = "      FIX INFO          "
  S[1] = string.format("%23s ", pgNo .. "/2")
  S[2] = " FIX  BRG/DIS FR        "
  S[4] = " BRG/DIS ETA   DTG   ALT"
  S[12] = "            PRED ETA-ALT"
  local f = pg.fix
  if f then
    local path = R.fix_path(B747_fmc_route, airplane())
    local c, d = R.course(f.lat, f.lon, simDR_latitude, simDR_longitude)
    L[3] = pad(string.format("%-8s%s/%s", f.ident, brg3(mag_of(f, c)), nm(d)))
    for k = 1, 3 do
      local n = 3 + 2 * k
      local e = pg.lines[k]
      if not e then
        L[n] = pad("---/---")
      else
        local x = crossing(f, e, path)
        if e.brg then L[n] = put(L[n], 1, string.format("%03d", e.brg)) elseif x then S[n] = put(S[n], 1, brg3(x.brg)) end
        L[n] = put(L[n], 4, "/")
        if e.dist then L[n] = put(L[n], 5, string.format("%d", e.dist)) elseif x then S[n] = put(S[n], 5, nm(x.dist)) end
        if x then
          L[n] = put(L[n], 19 - #nm(x.dtg), nm(x.dtg))
          L[n], S[n] = eta_alt(L[n], S[n], x.dtg)
        end
      end
    end
    S[10] = " ABEAM                  "
    if not pg.abeam then
      L[11] = pad("<ABEAM")
    else
      local x = abeam_point(f, path)
      if x then
        L[11] = put(pad(brg3(x.brg) .. "/" .. nm(x.dist)), 19 - #nm(x.dtg), nm(x.dtg))
        L[11], S[11] = eta_alt(L[11], S[11], x.dtg)
      else
        L[11] = pad("---/---")
      end
    end
    L[13] = pad("<ERASE FIX")
  end
  local px = pred_point(pg)
  local p = pg.pred
  if not p then
    L[13] = put(L[13], 20, "-----")
  else
    -- the predicted along track distance (FCOM p.1359's figure: 112NM)
    if px then
      L[13] = put(L[13], 17 - #nm(px), nm(px))
      S[13] = put(S[13], 17, "NM")
    end
    if p.time then
      L[13], S[13] = put(L[13], 20, p.time), put(S[13], 24, "z")
    else
      local t = B747_cdu_model.format_alt(p.alt, trans_alt())
      L[13] = put(L[13], 25 - #t, t)
    end
  end
  return L, S
end

fmsPages["FIXINFO"]=createPage("FIXINFO")
fmsPages["FIXINFO"].getNumPages=function(self)
  return 2
end
-- the lines made once a frame: the small ones kept for getSmallPage,
-- called after getPage (B744.createfms.lua)
local smallLines = {}
fmsPages["FIXINFO"].getPage=function(self,pgNo,fmsID)
  local L, S = page_lines(pgNo)
  if not fixPages[pgNo].fix then L[3] = pad("*****") end
  smallLines[fmsID] = S
  return L
end
fmsPages["FIXINFO"].getSmallPage=function(self,pgNo,fmsID)
  return smallLines[fmsID] or select(2, page_lines(pgNo))
end
fmsFunctionsDefs["FIXINFO"]={}
fmsFunctionsDefs["FIXINFO"]["L1"]={"fixinfofix",""}
fmsFunctionsDefs["FIXINFO"]["L2"]={"fixinfobrg","1"}
fmsFunctionsDefs["FIXINFO"]["L3"]={"fixinfobrg","2"}
fmsFunctionsDefs["FIXINFO"]["L4"]={"fixinfobrg","3"}
fmsFunctionsDefs["FIXINFO"]["L5"]={"fixinfoabeam",""}
fmsFunctionsDefs["FIXINFO"]["L6"]={"fixinfoerase",""}
fmsFunctionsDefs["FIXINFO"]["R6"]={"fixinfopred",""}

-- the FIX key (B744.createfms.lua)
function B747_cdu_fix_page(fmsO)
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "FIXINFO"
  fmsO.targetpgNo = 1
end
-- the page shown on this CDU (1 or 2)
local function page_of(fmsO) return fixPages[fmsO.pgNo] and fmsO.pgNo or 1 end

-- 1L FIX
function fmsFunctions.fixinfofix(fmsO, value)
  local pg = fixPages[page_of(fmsO)]
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if pg.fix then fmsO["scratchpad"] = pg.fix.ident end
    return
  end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  if not string.match(sp, "^%w%w?%w?%w?%w?$") then fmsO["notify"] = "NOT IN DATA BASE" return end
  local list = R.candidates(B747_fmc_route, sp, simDR_latitude, simDR_longitude, true)
  B747_fmc_with_point(fmsO, sp, nil, function(p)
    pg.fix, pg.lines, pg.abeam = p, {}, false
    fmsO["scratchpad"] = ""
  end, list)
end

-- 2L-4L BRG/DIS: XXX, /YYY or XXX/YYY
local function parse_brgdis(sp)
  local b, d = string.match(sp, "^(%d%d%d)/(%d%d?%d?)$")
  if not b then b = string.match(sp, "^(%d%d%d)$") end
  if not b then d = string.match(sp, "^/(%d%d?%d?)$") end
  b, d = tonumber(b or ""), tonumber(d or "")
  if (b and b > 360) or (d and d <= 0) or not (b or d) then return nil end
  return {brg = b, dist = d}
end
function fmsFunctions.fixinfobrg(fmsO, value)
  local pg = fixPages[page_of(fmsO)]
  local k = tonumber(value)
  local sp = fmsO["scratchpad"]
  if not pg.fix then
    if sp ~= "" then fmsO["notify"] = "INVALID ENTRY" end
    return
  end
  local e = pg.lines[k]
  if sp == "" then
    if not e then return end
    local x = crossing(pg.fix, e, R.fix_path(B747_fmc_route, airplane()))
    local brg, dist = e.brg or (x and x.brg), e.dist or (x and x.dist)
    if brg and dist then fmsO["scratchpad"] = pbd_text(pg.fix, brg, dist) end
    return
  end
  if sp == "DELETE" then
    if not e then fmsO["notify"] = "INVALID DELETE" return end
    pg.lines[k] = nil
    fmsO["scratchpad"] = ""
    return
  end
  local n = parse_brgdis(sp)
  if not n then fmsO["notify"] = "INVALID ENTRY" return end
  pg.lines[k] = n
  fmsO["scratchpad"] = ""
end

-- 5L <ABEAM
function fmsFunctions.fixinfoabeam(fmsO, value)
  local pg = fixPages[page_of(fmsO)]
  local sp = fmsO["scratchpad"]
  if not pg.fix then
    if sp ~= "" then fmsO["notify"] = "INVALID ENTRY" end
    return
  end
  if sp == "DELETE" then
    if not pg.abeam then fmsO["notify"] = "INVALID DELETE" return end
    pg.abeam = false
    fmsO["scratchpad"] = ""
    return
  end
  if sp ~= "" then fmsO["notify"] = "INVALID ENTRY" return end
  local x = abeam_point(pg.fix, R.fix_path(B747_fmc_route, airplane()))
  if not x then fmsO["notify"] = "INVALID ENTRY" return end
  if pg.abeam then
    fmsO["scratchpad"] = pbd_text(pg.fix, x.brg, x.dist)
    return
  end
  pg.abeam = true
end

-- 6L <ERASE FIX
function fmsFunctions.fixinfoerase(fmsO, value)
  local pg = fixPages[page_of(fmsO)]
  pg.fix, pg.lines, pg.abeam = nil, {}, false
end

-- 6R PRED ETA-ALT: hhmmZ or an altitude
function fmsFunctions.fixinfopred(fmsO, value)
  local pg = fixPages[page_of(fmsO)]
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then
    if not pg.pred then fmsO["notify"] = "INVALID DELETE" return end
    pg.pred = nil
    fmsO["scratchpad"] = ""
    return
  end
  local h, m = string.match(sp, "^(%d%d)(%d%d)Z$")
  if h then
    if tonumber(h) > 23 or tonumber(m) > 59 then fmsO["notify"] = "INVALID ENTRY" return end
    pg.pred = {time = h .. m}
  else
    local alt = B747_cdu_model.parse_alt(sp)
    if not alt then fmsO["notify"] = "INVALID ENTRY" return end
    pg.pred = {alt = alt}
  end
  fmsO["scratchpad"] = ""
end

-- (2026-11-04) the fixes for the ND (FCOM p.1149-1150, p.1358-1359; FMSPG
-- p.166-169): each page's {fix, radials (true bearings), circles (NM),
-- pred = {lat, lon, text} or nil}: the fix in a small circle with its
-- identifier, its bearings as radial lines from it, its distances as
-- circles round it (a bearing and a distance both entered: both; estimate),
-- PRED ETA-ALT's point on the route with the entered time or altitude
function B747_fms_fix_nd()
  local out = {}
  for pgNo = 1, 2 do
    local pg = fixPages[pgNo]
    local o = {radials = {}, circles = {}}
    if pg.fix then
      o.fix = pg.fix
      for k = 1, 3 do
        local e = pg.lines[k]
        if e and e.brg then o.radials[#o.radials + 1] = true_of(pg.fix, e.brg) end
        if e and e.dist then o.circles[#o.circles + 1] = e.dist end
      end
    end
    local px = pred_point(pg)
    local q = px and B747_fms_pred_pos and B747_fms_pred_pos(px)
    if q and pg.pred then
      local text = pg.pred.time and (pg.pred.time .. "Z") or B747_cdu_model.format_alt(pg.pred.alt, trans_alt())
      o.pred = {lat = q.lat, lon = q.lon, text = text}
    end
    out[pgNo] = o
  end
  return out
end
