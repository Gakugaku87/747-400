-- DEP/ARR INDEX, DEPARTURES and ARRIVALS (6-1/6-2 step 5d;
-- notes/ATA-34-61-FMC.md §18): the origin's SIDs, runways and transitions,
-- the destination's STARs, approaches and transitions from its CIFP
-- (B747.68.proc_model.lua), selected into the FMC's route (FCOM
-- p.1299-1302, p.1400-1405). A selection shows <SEL> inboard of it, the
-- others of its kind no longer show and the route has a modification
-- (on the inactive route the change itself); after EXEC <SEL> is <ACT>;
-- leaving the page and coming back shows all the options again with the
-- prompts. RTE 2's from the INDEX's RTE 2 lines (step 7e4; FCOM
-- p.1299-1300). Before: X-Plane's DEP ARR page.
local R = B747_route_model
local P = B747_proc_model
local BLANK = "                        "
local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function short_rwy(id) return (id:gsub("^RW", "")) end

-- each CDU's view: the airport, the page's kind, the options narrowed by a
-- selection on this visit (FCOM p.1301-1302, p.1401), the route (num: 1
-- or 2)
local view = {}
local function v_of(fmsID)
  local v = view[fmsID]
  if not v then v = {narrow = false}; view[fmsID] = v end
  return v
end
-- the route of the view in use, set where a page or a key starts
local curNum = 1
local function use(fmsID) curNum = v_of(fmsID).num or B747_fmc_route.num end
local function st_cur() return B747_fmc_route_num(curNum) end
local function route() return R.shown(st_cur()) end

-- <SEL> or <ACT>: a selection not yet executed, or one of the active route
local function marker(field, value)
  local st = st_cur()
  local shown = R.shown(st)
  local function sel_of(r) return r and r[field[1]] and r[field[1]][field[2]] end
  if sel_of(shown) ~= value then return nil end
  if st.active and sel_of(st.rte) == value and not st.mod then return "<ACT>" end
  if st.active and st.mod and sel_of(st.rte) == value then return "<ACT>" end
  return "<SEL>"
end

-- the rows of a column: {text, action} five a page
local function page_rows(list, pgNo)
  local out = {}
  for k = 1, 5 do out[k] = list[(pgNo - 1) * 5 + k] end
  return out
end
local function num_pages_of(left, right)
  return math.max(1, math.ceil(math.max(#left, #right) / 5))
end

-------------------------------------------------------------------------
-- DEPARTURES
local function dep_columns(fmsID)
  local r = route()
  local v = v_of(fmsID)
  local left, right = {}, {}
  if not r.origin then return left, right end
  local icao = r.origin.ident
  local sid = r.sid
  local rwy = r.runway and r.runway.ident
  if v.narrow and sid then
    left[#left + 1] = {text = sid.name, mark = marker({"sid", "name"}, sid.name), act = {"sid", sid.name}}
    local tr = P.transitions(B747_navdb, B747_fmc_navdb, icao, P.SID, sid.name).trans
    local title = "TRANS"
    for _, t in ipairs(tr) do
      if not sid.trans or sid.trans == t then
        left[#left + 1] = {text = t, mark = marker({"sid", "trans"}, t), act = {"trans", t}, title = title}
        title = nil
      end
    end
  else
    for _, name in ipairs(P.list(B747_navdb, B747_fmc_navdb, icao, P.SID)) do
      local ok = not (v.narrow and rwy)
      if not ok then
        for _, id in ipairs(P.runways(B747_navdb, B747_fmc_navdb, icao, P.SID, name)) do
          if id == rwy then ok = true break end
        end
      end
      if ok then left[#left + 1] = {text = name, mark = sid and marker({"sid", "name"}, name), act = {"sid", name}} end
    end
  end
  local rwys
  if v.narrow and rwy then
    rwys = {rwy}
  elseif v.narrow and sid then
    rwys = P.runways(B747_navdb, B747_fmc_navdb, icao, P.SID, sid.name)
  else
    rwys = P.runways(B747_navdb, B747_fmc_navdb, icao, P.SID, nil)
  end
  for _, id in ipairs(rwys) do
    local m = nil
    if rwy == id then m = (st_cur().active and not st_cur().mod) and "<ACT>" or "<SEL>" end
    right[#right + 1] = {text = short_rwy(id), mark = m, act = {"rwy", id}}
  end
  return left, right
end

local function draw(title, left, right, pgNo, labels)
  local lines = {pad("   " .. title)}
  local lrows, rrows = page_rows(left, pgNo), page_rows(right, pgNo)
  for k = 1, 5 do
    local l, r = lrows[k], rrows[k]
    lines[#lines + 1] = BLANK
    local lt = l and (l.text .. (l.mark and l.mark or "")) or ""
    local rt = r and ((r.mark and r.mark or "") .. r.text) or ""
    lines[#lines + 1] = lr(lt, rt)
  end
  return lines
end
local function small_draw(left, right, pgNo, n, first)
  local lines = {string.format("%23s ", pgNo .. "/" .. n)}
  local lrows, rrows = page_rows(left, pgNo), page_rows(right, pgNo)
  for k = 1, 5 do
    local l, r = lrows[k], rrows[k]
    local t = (k == 1 and pgNo == 1) and first or BLANK
    -- a column's title over its line (TRANS: FCOM p.1403)
    if l and l.title then t = pad(" " .. l.title .. string.sub(t, 2 + #l.title)) end
    if r and r.title then t = string.sub(pad(t), 1, 24 - #r.title - 1) .. r.title .. " " end
    lines[#lines + 1] = pad(t)
    lines[#lines + 1] = BLANK
  end
  return lines
end

local function six(fmsID, page)
  local st = st_cur()
  local defs = fmsFunctionsDefs[page]
  defs["L6"] = st.mod and {"rteerase", ""} or {"setpage", "DEPARRINDEX"}
  defs["R6"] = {"setpage", "RTE" .. curNum}
  return lr(st.mod and "<ERASE" or "<INDEX", "ROUTE>")
end

fmsPages["DEPARTURES"]=createPage("DEPARTURES")
fmsPages["DEPARTURES"].getNumPages=function(self, fmsID)
  use(fmsID)
  local left, right = dep_columns(fmsID)
  return num_pages_of(left, right)
end
fmsPages["DEPARTURES"].getPage=function(self,pgNo,fmsID)
  use(fmsID)
  local r = route()
  local left, right = dep_columns(fmsID)
  local lines = draw((r.origin and r.origin.ident or "----") .. " DEPARTURES", left, right, pgNo)
  local defs = fmsFunctionsDefs["DEPARTURES"]
  for k = 1, 5 do
    defs["L" .. k] = {"depsel", "L" .. k}
    defs["R" .. k] = {"depsel", "R" .. k}
  end
  lines[12] = "------------------------"
  lines[13] = six(fmsID, "DEPARTURES")
  return lines
end
fmsPages["DEPARTURES"].getSmallPage=function(self,pgNo,fmsID)
  use(fmsID)
  local left, right = dep_columns(fmsID)
  return small_draw(left, right, pgNo, num_pages_of(left, right), string.format(" SIDS    RTE %d   RUNWAYS", curNum))
end
fmsFunctionsDefs["DEPARTURES"]={}
fmsFunctionsDefs["DEPARTURES"]["exec"]={"rteexec", ""}

-- a selection on DEPARTURES: a SID (its runway kept when it serves it), a
-- transition, a runway (a SID that does not serve it out)
function fmsFunctions.depsel(fmsO, value)
  use(fmsO.id)
  local st = st_cur()
  local side, k = value:sub(1, 1), tonumber(value:sub(2))
  local left, right = dep_columns(fmsO.id)
  local item = page_rows(side == "L" and left or right, fmsO.pgNo)[k]
  if not item or not item.act then return end
  local r = route()
  local sid = r.sid
  local rwy = r.runway and r.runway.ident
  local err
  local a = item.act
  if a[1] == "sid" then
    local ok = rwy == nil
    for _, id in ipairs(P.runways(B747_navdb, B747_fmc_navdb, r.origin.ident, P.SID, a[2])) do
      if id == rwy then ok = true end
    end
    err = R.set_departure(st, a[2], ok and rwy or nil, nil)
  elseif a[1] == "trans" then
    err = R.set_departure(st, sid.name, rwy, a[2])
  else
    local keep = false
    if sid then
      for _, id in ipairs(P.runways(B747_navdb, B747_fmc_navdb, r.origin.ident, P.SID, sid.name)) do
        if id == a[2] then keep = true end
      end
    end
    err = R.set_departure(st, keep and sid.name or nil, a[2], keep and sid.trans or nil)
  end
  if err then fmsO["notify"] = err return end
  v_of(fmsO.id).narrow = true
  B747_fmc_route_changed()
end

-------------------------------------------------------------------------
-- ARRIVALS (the destination's)
local function arr_columns(fmsID)
  local r = route()
  local v = v_of(fmsID)
  local left, right = {}, {}
  if not r.dest then return left, right end
  local icao = r.dest.ident
  local star, appr = r.star, r.appr
  if v.narrow and star then
    left[#left + 1] = {text = star.name, mark = marker({"star", "name"}, star.name), act = {"star", star.name}}
    local title = "TRANS"
    for _, t in ipairs(P.transitions(B747_navdb, B747_fmc_navdb, icao, P.STAR, star.name).trans) do
      if not star.trans or star.trans == t then
        left[#left + 1] = {text = t, mark = marker({"star", "trans"}, t), act = {"startrans", t}, title = title}
        title = nil
      end
    end
  else
    local list = P.list(B747_navdb, B747_fmc_navdb, icao, P.STAR)
    if #list == 0 then left[#left + 1] = {text = "NONE"} end
    for _, name in ipairs(list) do
      left[#left + 1] = {text = name, mark = star and marker({"star", "name"}, name), act = {"star", name}}
    end
  end
  if v.narrow and appr then
    right[#right + 1] = {text = P.approach_name(appr.id), mark = marker({"appr", "id"}, appr.id), act = {"appr", appr.id}}
    local title = "TRANS"
    for _, t in ipairs(P.transitions(B747_navdb, B747_fmc_navdb, icao, P.APPCH, appr.id).trans) do
      if not appr.trans or appr.trans == t then
        right[#right + 1] = {text = t, mark = marker({"appr", "trans"}, t), act = {"apprtrans", t}, title = title}
        title = nil
      end
    end
  else
    for _, id in ipairs(P.list(B747_navdb, B747_fmc_navdb, icao, P.APPCH)) do
      right[#right + 1] = {text = P.approach_name(id), mark = appr and marker({"appr", "id"}, id), act = {"appr", id}}
    end
  end
  return left, right
end

fmsPages["ARRIVALS"]=createPage("ARRIVALS")
fmsPages["ARRIVALS"].getNumPages=function(self, fmsID)
  use(fmsID)
  local left, right = arr_columns(fmsID)
  return num_pages_of(left, right)
end
fmsPages["ARRIVALS"].getPage=function(self,pgNo,fmsID)
  use(fmsID)
  local r = route()
  local left, right = arr_columns(fmsID)
  local lines = draw((r.dest and r.dest.ident or "----") .. " ARRIVALS", left, right, pgNo)
  local defs = fmsFunctionsDefs["ARRIVALS"]
  for k = 1, 5 do
    defs["L" .. k] = {"arrsel", "L" .. k}
    defs["R" .. k] = {"arrsel", "R" .. k}
  end
  lines[12] = "------------------------"
  lines[13] = six(fmsID, "ARRIVALS")
  return lines
end
fmsPages["ARRIVALS"].getSmallPage=function(self,pgNo,fmsID)
  use(fmsID)
  local left, right = arr_columns(fmsID)
  return small_draw(left, right, pgNo, num_pages_of(left, right), string.format(" STARS   RTE %d  APPROACH", curNum))
end
fmsFunctionsDefs["ARRIVALS"]={}
fmsFunctionsDefs["ARRIVALS"]["exec"]={"rteexec", ""}

function fmsFunctions.arrsel(fmsO, value)
  use(fmsO.id)
  local st = st_cur()
  local side, k = value:sub(1, 1), tonumber(value:sub(2))
  local left, right = arr_columns(fmsO.id)
  local item = page_rows(side == "L" and left or right, fmsO.pgNo)[k]
  if not item or not item.act then return end
  local r = route()
  local a = item.act
  local err
  if a[1] == "star" then
    err = R.set_arrival(st, {name = a[2]}, nil)
  elseif a[1] == "startrans" then
    err = R.set_arrival(st, {name = r.star.name, trans = a[2]}, nil)
  elseif a[1] == "appr" then
    err = R.set_arrival(st, nil, {id = a[2]})
  else
    err = R.set_arrival(st, nil, {id = r.appr.id, trans = a[2]})
  end
  if err then fmsO["notify"] = err return end
  v_of(fmsO.id).narrow = true
  B747_fmc_route_changed()
end

-------------------------------------------------------------------------
-- DEP/ARR INDEX (FCOM p.1299-1300): RTE 1's and RTE 2's origin (DEP) and
-- destination (ARR) (RTE 2 step 7e4); the origins' ARR (an air turnback)
-- and OTHER airports (viewing only) not yet
fmsPages["DEPARRINDEX"]=createPage("DEPARRINDEX")
fmsPages["DEPARRINDEX"].getPage=function(self,pgNo,fmsID)
  local defs = fmsFunctionsDefs["DEPARRINDEX"]
  local function rows(n, dep_key, arr_key)
    local r = R.shown(B747_fmc_route_num(n))
    defs[dep_key] = r.origin and {"deparrgo", "DEPARTURES:" .. n} or nil
    defs[arr_key] = r.dest and {"deparrgo", "ARRIVALS:" .. n} or nil
    return lr(r.origin and ("<DEP    " .. r.origin.ident) or "", ""),
      lr(r.dest and ("        " .. r.dest.ident) or "", r.dest and "ARR>" or "")
  end
  local a1, a2 = rows(1, "L1", "R2")
  local b1, b2 = rows(2, "L3", "R4")
  return {
    pad("     DEP/ARR INDEX"), BLANK, a1, BLANK, a2, BLANK, b1, BLANK, b2,
    BLANK, BLANK, BLANK, BLANK,
  }
end
fmsPages["DEPARRINDEX"].getSmallPage=function(self,pgNo,fmsID)
  local function status(n) return B747_fmc_route_num(n).active and "(ACT)" or "" end
  return {"                    1/1 ", pad("          RTE 1 " .. status(1)), BLANK, BLANK, BLANK,
    pad("          RTE 2 " .. status(2)), BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK}
end
fmsFunctionsDefs["DEPARRINDEX"]={}
function fmsFunctions.deparrgo(fmsO, value)
  local page, n = string.match(value, "^(%u+):(%d)$")
  local v = v_of(fmsO.id)
  v.narrow, v.num = false, tonumber(n)
  fmsO.targetCustomFMC = true
  fmsO.targetPage = page
  fmsO.targetpgNo = 1
end

-- the DEP ARR key's page (FCOM p.1299, p.1301, p.1343, p.1400; the CDU's
-- notes §4.5): the INDEX without an active route, DEPARTURES on the ground,
-- ARRIVALS in the air (the destination's: its origin's view while near the
-- origin is not made yet)
function B747_cdu_deparr_page(fmsO)
  local v = v_of(fmsO.id)
  v.narrow, v.num = false, B747_fmc_route.num
  local st = B747_fmc_route
  fmsO.targetCustomFMC = true
  fmsO.targetpgNo = 1
  if not st.active then
    fmsO.targetPage = "DEPARRINDEX"
  elseif simDR_onGround == 1 then
    fmsO.targetPage = "DEPARTURES"
  else
    fmsO.targetPage = "ARRIVALS"
  end
end
