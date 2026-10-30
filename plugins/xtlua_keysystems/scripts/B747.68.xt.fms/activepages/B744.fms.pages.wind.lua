-- XXXXX WINDS (6-1/6-2 step 8e1; notes/ATA-34-61-FMC.md §51; FCOM
-- p.1364-1366, FMSPG p.121-124): the active route's waypoint winds, from
-- RTE DATA's ">" or "W>" (1R-5R), one page a waypoint (NEXT and PREV PAGE
-- go along the route: "9/13"). Up to four altitudes for all waypoints
-- (1L: a new one while fewer than four, the highest first, the others
-- under it; DELETE removes one and its winds everywhere), each one's
-- DIR/SPD at this waypoint (entered large, propagated small: B747.68.
-- wind_model.lua), each one's OAT by the standard lapse rate from the
-- (propagated) ALT/OAT entry (5R; large on the waypoint it was entered at:
-- FMSPG p.122); RTE DATA> at 6R to the RTE DATA page with this waypoint.
-- Entries take effect at once (an estimate: no modification to EXEC) on
-- the active route and its modification, when there is one.
local R = B747_route_model
local W = B747_wind_model
local BLANK = string.rep(" ", 24)
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end

-- the waypoints (the route's legs but its discontinuities)
local function waypoints()
  local list = {}
  for i, l in ipairs(B747_fmc_route.rte.legs) do
    if not (l.disc or l.pending) then list[#list + 1] = i end
  end
  return list
end
-- the leg of page pgNo
local function leg_of(pgNo) return waypoints()[pgNo] end

-- the WIND page of leg i (from RTE DATA)
function B747_cdu_wind_page(fmsO, i)
  for k, j in ipairs(waypoints()) do
    if j == i then
      fmsO.targetCustomFMC = true
      fmsO.targetPage = "WIND"
      fmsO.targetpgNo = k
      return
    end
  end
end

-- the four rows, high to low: the altitudes at the bottom, 1L dashed while
-- there are fewer than four
local function row_alt(r, row)
  local a = W.alts(r)
  local k = row - (W.ALTS - #a)
  return k >= 1 and a[k] or nil
end

-- a row's parts: the large and the small text
local function wind_rows(pgNo)
  local r = B747_fmc_route.rte
  local i = leg_of(pgNo)
  local large, small = {}, {}
  for row = 1, W.ALTS do
    large[row], small[row] = BLANK, BLANK
    local ft = row_alt(r, row)
    if row == 1 and #W.alts(r) < W.ALTS then
      large[row] = "-----" .. string.rep(" ", 19)
    elseif ft and i then
      local alt = string.format("%-7s", B747_cdu_model.format_alt(ft, trans_alt()))
      local c, cHere = W.oat(r, i, ft)
      local t = string.format("%3d`", math.floor(c + 0.5))
      local dir, kt, wHere = W.wind(r, i, ft)
      local w = dir and string.format("%03d`/%3d", dir, kt) or "---`/---"
      local wLarge = wHere or not dir
      -- ALT at 1-5, OAT at 8-11 and its "C" at 12 (small), DIR/SPD at
      -- 15-22 and "KT" at 23-24 (small: FCOM p.1365's figure)
      large[row] = alt .. (cHere and t or "    ") .. "   " .. (wLarge and w or "        ") .. "  "
      small[row] = string.rep(" ", 7) .. (cHere and "    " or t) .. "C  " .. (wLarge and "        " or w) .. "KT"
    end
  end
  return large, small
end

-- the ALT/OAT line (5R): this waypoint's entry, dashes without one
local function oat_line(pgNo)
  local r = B747_fmc_route.rte
  local i = leg_of(pgNo)
  local e = i and r.legs[i].oat
  local text = "-----/---`"
  if e then text = B747_cdu_model.format_alt(e.ft, trans_alt()) .. "/" .. string.format("%d", e.c) .. "`" end
  -- the "C" at 24, small
  return string.format("%23s ", text), string.rep(" ", 23) .. "C"
end

fmsPages["WIND"] = createPage("WIND")
fmsPages["WIND"].getNumPages = function(self)
  return math.max(1, #waypoints())
end

fmsPages["WIND"].getPage = function(self, pgNo, fmsID)
  local i = leg_of(pgNo)
  local name = i and R.leg_name(B747_fmc_route.rte.legs[i]) or ""
  local t = name .. " WINDS"
  local large = wind_rows(pgNo)
  local oatL = oat_line(pgNo)
  return {
    string.format("%-24s", string.rep(" ", math.floor((24 - #t) / 2)) .. t),
    BLANK, large[1], BLANK, large[2], BLANK, large[3], BLANK, large[4], BLANK,
    oatL,
    "------------------------",
    lr("", "RTE DATA>")
  }
end

fmsPages["WIND"].getSmallPage = function(self, pgNo, fmsID)
  local _, small = wind_rows(pgNo)
  local _, oatS = oat_line(pgNo)
  return {
    string.format("%23s ", pgNo .. "/" .. fmsPages["WIND"]:getNumPages()),
    " ALT    OAT      DIR/SPD",
    small[1], BLANK, small[2], BLANK, small[3], BLANK, small[4],
    lr("", "ALT/OAT"),
    oatS,
    BLANK,
    BLANK
  }
end

-- an entry on the active route, and on its modification's same leg (a
-- copy of the same one: the route model's `orig`) when there is one
local function on_routes(fmsO, i, fn)
  local st = B747_fmc_route
  local l = i and st.rte.legs[i]
  local key = l and (l.orig or l)
  fn(st.rte, i)
  if st.mod and st.mod ~= st.rte then
    if not i then fn(st.mod) end
    for j, m in ipairs(st.mod.legs) do
      if key and (m.orig or m) == key then fn(st.mod, j) end
    end
  end
  fmsO["scratchpad"] = ""
  B747_fms_preds_now()
end

-- 1L-4L: a new altitude at 1L (while fewer than four), DELETE an altitude
-- (FCOM p.1365; FMSPG p.121-122: replaced only after a delete)
function fmsFunctions.windalt(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local st = B747_fmc_route
  local row = tonumber(value)
  local ft = row_alt(st.rte, row)
  if sp == "DELETE" then
    if not ft then fmsO["notify"] = "INVALID DELETE" return end
    on_routes(fmsO, nil, function(r) W.delete_alt(r, ft) end)
    return
  end
  local h = B747_cdu_model.parse_alt(sp)
  if row ~= 1 or ft or not h or h <= 0 or h > 45100 then fmsO["notify"] = "INVALID ENTRY" return end
  if W.add_alt(st.rte, h) then fmsO["notify"] = "INVALID ENTRY" return end
  if st.mod and st.mod ~= st.rte then W.add_alt(st.mod, h) end
  fmsO["scratchpad"] = ""
  B747_fms_preds_now()
end

-- 1R-4R: DIR/SPD at this waypoint (both: FCOM p.1366), DELETE this
-- waypoint's (the others' propagate here then)
function fmsFunctions.windspd(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local r = B747_fmc_route.rte
  local i = leg_of(fmsO.pgNo)
  local ft = row_alt(r, tonumber(value))
  if not (i and ft) then fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY" return end
  if sp == "DELETE" then
    if not (r.legs[i].wind and r.legs[i].wind[ft]) then fmsO["notify"] = "INVALID DELETE" return end
    on_routes(fmsO, i, function(rr, j) W.delete_wind(rr, j, ft) end)
    return
  end
  local dir, kt = sp:match("^(%d%d?%d?)/(%d%d?%d?)$")
  dir, kt = tonumber(dir), tonumber(kt)
  if not dir or dir > 360 or kt > 250 then fmsO["notify"] = "INVALID ENTRY" return end
  on_routes(fmsO, i, function(rr, j) W.set_wind(rr, j, ft, dir % 360, kt) end)
end

-- 5R ALT/OAT (FCOM p.1366; FMSPG p.122): an altitude and its OAT (C),
-- -80 C up to the line from 55 C at sea level to -40 C at 45,100 ft;
-- DELETE this waypoint's
function fmsFunctions.windoat(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local r = B747_fmc_route.rte
  local i = leg_of(fmsO.pgNo)
  if not i then fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY" return end
  if sp == "DELETE" then
    if not r.legs[i].oat then fmsO["notify"] = "INVALID DELETE" return end
    on_routes(fmsO, i, function(rr, j) W.delete_oat(rr, j) end)
    return
  end
  local a, t = sp:match("^([^/]+)/([%+%-]?%d%d?)$")
  local h, c = B747_cdu_model.parse_alt(a), tonumber(t)
  if not (h and c) or h < 0 or h > 45100 or not W.oat_valid(h, c) then fmsO["notify"] = "INVALID ENTRY" return end
  on_routes(fmsO, i, function(rr, j) W.set_oat(rr, j, h, c) end)
end

-- RTE DATA>: the RTE DATA page with this waypoint (FMSPG p.123)
function fmsFunctions.windrtedata(fmsO, value)
  local i = leg_of(fmsO.pgNo) or 1
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "RTEDATA"
  fmsO.targetpgNo = math.ceil(i / 5)
end

fmsFunctionsDefs["WIND"] = {}
for row = 1, 4 do
  fmsFunctionsDefs["WIND"]["L" .. row] = {"windalt", tostring(row)}
  fmsFunctionsDefs["WIND"]["R" .. row] = {"windspd", tostring(row)}
end
fmsFunctionsDefs["WIND"]["R5"] = {"windoat", ""}
fmsFunctionsDefs["WIND"]["R6"] = {"windrtedata", ""}
