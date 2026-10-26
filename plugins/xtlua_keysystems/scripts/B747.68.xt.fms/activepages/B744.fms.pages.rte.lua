-- RTE 1 (6-1/6-2 step 5b; notes/ATA-34-61-FMC.md §18): the FMC's route
-- (B747.68.route_model.lua) on its own pages. Page 1: ORIGIN, DEST,
-- RUNWAY, FLT NO, CO ROUTE and ACTIVATE (FCOM p.1287-1290); the next pages
-- the route's segments, VIA and TO five a page, dashes after the end (FCOM
-- p.1296-1298). The title RTE 1, ACT RTE 1 or MOD RTE 1, ERASE at 6L on a
-- modification (FCOM p.1238). Before: X-Plane's RTE page shown through.
local R = B747_route_model
local BLANK = "                        "

local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function route() return R.shown(B747_fmc_route) end
local function rows_on(pg) return (pg - 2) * 5 end

-- the number of pages: page 1 and the segments with the dashes line, five
-- a page (two at least: FCOM p.1287)
local function num_pages()
  local n = #R.segments(route()) + 1
  return 1 + math.max(1, math.ceil(n / 5))
end

local function title()
  local s = R.status(B747_fmc_route)
  local t = s ~= "" and (s .. " RTE 1") or "RTE 1"
  return pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)
end

-- 6R: ACTIVATE on the inactive route (until EXEC), then PERF INIT until
-- the performance data are complete, then TAKEOFF (FCOM p.1290)
local function six_right()
  if not B747_fmc_route.active then return "ACTIVATE>", {"rteactivate", ""} end
  if not perf_init_complete() then return "PERF INIT>", {"setpage", "PERFINIT"} end
  return "TAKEOFF>", {"setpage", "TAKEOFF"}
end

fmsPages["RTE1"]=createPage("RTE1")
fmsPages["RTE1"].getNumPages=function(self)
  return num_pages()
end
fmsPages["RTE1"].getPage=function(self,pgNo,fmsID)
  local r = route()
  local defs = fmsFunctionsDefs["RTE1"]
  local sr, srDef = six_right()
  defs["R6"] = srDef
  defs["L6"] = B747_fmc_route.mod and {"rteerase", ""} or nil
  local six = lr(B747_fmc_route.mod and "<ERASE" or "", sr)
  if pgNo == 1 then
    defs["L1"] = {"rteorigin", ""}
    defs["R1"] = {"rtedest", ""}
    defs["L2"] = {"rterunway", ""}
    defs["R2"] = {"setdata", "fltno"}
    defs["R3"] = {"rtecoroute", ""}
    for _, k in ipairs({"L3", "L4", "L5", "R4", "R5"}) do defs[k] = nil end
    local fltno = string.format("%8s", (string.gsub(fmsModules["data"]["fltno"], "%s+$", "")))
    local origin = r.origin and r.origin.ident or "****"
    local dest = r.dest and r.dest.ident or "****"
    local runway = r.runway and r.runway.ident or "-----"
    return {
      title(), BLANK,
      lr(origin, dest), BLANK,
      lr(runway, fltno), BLANK,
      lr("", "----------"), BLANK,
      BLANK, BLANK,
      BLANK, "------------------------",
      six
    }
  end
  local segs = R.segments(r)
  local lines = {title()}
  for k = 1, 5 do
    local i = rows_on(pgNo) + k
    local s = segs[i]
    defs["L" .. k] = {"rtevia", tostring(k)}
    defs["R" .. k] = {"rteto", tostring(k)}
    local via, to = "", ""
    if s and s.disc then
      via, to = "", "*****"
    elseif s then
      via, to = s.via, s.to or "*****"
    elseif i == #segs + 1 then
      via, to = "-----", "-----"
    else
      -- blank lines: an entry is INVALID ENTRY (FMSPG p.82)
    end
    lines[#lines + 1] = BLANK
    lines[#lines + 1] = lr(via, to)
  end
  lines[12] = BLANK
  lines[13] = six
  return lines
end
fmsPages["RTE1"].getSmallPage=function(self,pgNo,fmsID)
  local n = num_pages()
  local pn = string.format("%23s ", pgNo .. "/" .. n)
  if pgNo == 1 then
    return {
      pn, " ORIGIN             DEST", BLANK,
      " RUNWAY           FLT NO", BLANK,
      "                CO ROUTE", BLANK,
      BLANK, BLANK, BLANK, BLANK, BLANK, BLANK
    }
  end
  return {pn, " VIA                  TO", BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK}
end
fmsFunctionsDefs["RTE1"]={}

-- SELECT DESIRED WPT (FCOM p.1335): an identifier with more than one
-- location; each candidate's identifier and kind, frequency and position,
-- nearest first; a line select key takes one and goes back to the page in
-- use, a function key leaves without one
local selwpt = {}   -- each CDU's: {list, done (the entry with the point), page, pgNo}
local KIND_NAME = {VOR = "VOR", DME = "DME", NDB = "NDB", LOC = "LOC", APT = "", WPT = ""}
local function freq_text(p)
  if p.kind == "VOR" or p.kind == "DME" or p.kind == "LOC" then
    return string.format("%5.1f", (p.freq or 0) / 100)
  elseif p.kind == "NDB" then
    return string.format("%5d", p.freq or 0)
  end
  return "     "
end
fmsPages["SELWPT"]=createPage("SELWPT")
fmsPages["SELWPT"].getNumPages=function(self, fmsID)
  local s = selwpt[fmsID]
  return s and math.max(1, math.ceil(#s.list / 6)) or 1
end
fmsPages["SELWPT"].getPage=function(self,pgNo,fmsID)
  local s = selwpt[fmsID]
  local n = s and math.max(1, math.ceil(#s.list / 6)) or 1
  -- the title centred and no page number on one page (FCOM p.1335's
  -- figure), left of the page number on more
  local lines = {pad(n > 1 and " SELECT DESIRED WPT" or "   SELECT DESIRED WPT")}
  for k = 1, 6 do
    local p = s and s.list[(pgNo - 1) * 6 + k]
    lines[#lines + 1] = BLANK
    lines[#lines + 1] = p and pad(freq_text(p) .. " " .. toDMS(p.lat, true) .. " " .. toDMS(p.lon, false)) or BLANK
    fmsFunctionsDefs["SELWPT"]["L" .. k] = p and {"selwpt", tostring(k)} or nil
    fmsFunctionsDefs["SELWPT"]["R" .. k] = p and {"selwpt", tostring(k)} or nil
  end
  return lines
end
fmsPages["SELWPT"].getSmallPage=function(self,pgNo,fmsID)
  local s = selwpt[fmsID]
  local n = s and math.max(1, math.ceil(#s.list / 6)) or 1
  local lines = {n > 1 and string.format("%23s ", pgNo .. "/" .. n) or BLANK}
  for k = 1, 6 do
    local p = s and s.list[(pgNo - 1) * 6 + k]
    lines[#lines + 1] = p and pad(" " .. p.ident .. " " .. (KIND_NAME[p.kind] or "")) or BLANK
    lines[#lines + 1] = BLANK
  end
  return lines
end
fmsFunctionsDefs["SELWPT"]={}
function fmsFunctions.selwpt(fmsO, value)
  local s = selwpt[fmsO.id]
  local p = s and s.list[(fmsO.pgNo - 1) * 6 + tonumber(value)]
  if not p then return end
  selwpt[fmsO.id] = nil
  fmsO.targetCustomFMC = true
  fmsO.targetPage = s.page
  fmsO.targetpgNo = s.pgNo
  fmsO["scratchpad"] = s.sp
  s.done(p)
end

-- a point entered by its identifier: the one location, or SELECT DESIRED
-- WPT (sorted from the point before it, else the airplane: FCOM p.1335);
-- NOT IN DATA BASE when none (the RTE and LEGS pages)
function B747_fmc_with_point(fmsO, ident, near, done)
  local lat, lon = simDR_latitude, simDR_longitude
  if near then lat, lon = near.lat, near.lon end
  local list = R.candidates(B747_fmc_route, ident, lat, lon)
  if #list == 0 then fmsO["notify"] = "NOT IN DATA BASE" return end
  if #list == 1 then done(list[1]) return end
  selwpt[fmsO.id] = {list = list, done = done, page = fmsO.currentPage, pgNo = fmsO.pgNo, sp = fmsO["scratchpad"]}
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "SELWPT"
  fmsO.targetpgNo = 1
end

-- the entries (FCOM p.1288-1289, p.1296-1298; FMSPG p.82-83): an empty
-- scratchpad copies the line's identifier into it (FMSPG p.82); a route
-- entry's message, or the scratchpad emptied and the route changed (the
-- RTE and LEGS pages)
function B747_fmc_route_entry(fmsO, err)
  if err then fmsO["notify"] = err return end
  fmsO["scratchpad"] = ""
  B747_fmc_route_changed()
end
local entry = B747_fmc_route_entry
local function copy_or_entry(fmsO, text)
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if text then fmsO["scratchpad"] = text end
    return nil
  end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return nil end
  return sp
end
function fmsFunctions.rteorigin(fmsO, value)
  local r = route()
  local sp = copy_or_entry(fmsO, r.origin and r.origin.ident)
  if not sp then return end
  -- in flight only on the inactive route (FCOM p.1288)
  if simDR_onGround == 0 and B747_fmc_route.active then fmsO["notify"] = "INVALID ENTRY" return end
  entry(fmsO, R.set_origin(B747_fmc_route, sp))
end
function fmsFunctions.rtedest(fmsO, value)
  local r = route()
  local sp = copy_or_entry(fmsO, r.dest and r.dest.ident)
  if not sp then return end
  entry(fmsO, R.set_dest(B747_fmc_route, sp))
end
function fmsFunctions.rterunway(fmsO, value)
  local r = route()
  local sp = copy_or_entry(fmsO, r.runway and r.runway.ident)
  if not sp then return end
  entry(fmsO, R.set_runway(B747_fmc_route, sp))
end
-- CO ROUTE: no company routes in the database: NOT IN DATA BASE (FCOM
-- p.1290: the entry taken; nothing to load)
function fmsFunctions.rtecoroute(fmsO, value)
  local sp = copy_or_entry(fmsO, nil)
  if not sp then return end
  fmsO["notify"] = "NOT IN DATA BASE"
end
function fmsFunctions.rtevia(fmsO, value)
  local segs = R.segments(route())
  local i = rows_on(fmsO.pgNo) + tonumber(value)
  local s = segs[i]
  local sp = copy_or_entry(fmsO, s and not s.disc and s.via ~= R.DIRECT and s.via or nil)
  if not sp then return end
  -- after the route's end only (other changes on the LEGS pages: estimate)
  if i ~= #segs + 1 then fmsO["notify"] = "INVALID ENTRY" return end
  entry(fmsO, R.add_via(B747_fmc_route, sp))
end
function fmsFunctions.rteto(fmsO, value)
  local r = route()
  local segs = R.segments(r)
  local i = rows_on(fmsO.pgNo) + tonumber(value)
  local s = segs[i]
  local sp = copy_or_entry(fmsO, s and s.to or nil)
  if not sp then return end
  -- the dashes after the end, or an airway's boxes (FMSPG p.82)
  local boxes = s and not s.disc and s.to == nil and i == #segs
  if i ~= #segs + 1 and not boxes then fmsO["notify"] = "INVALID ENTRY" return end
  local last = r.legs[#r.legs]
  local before = r.legs[#r.legs - (boxes and 1 or 0)]
  local near = before and before.fix or r.origin
  B747_fmc_with_point(fmsO, sp, near, function(p) entry(fmsO, R.add_to(B747_fmc_route, p)) end)
end
function fmsFunctions.rteactivate(fmsO, value)
  entry(fmsO, R.activate(B747_fmc_route))
end
function fmsFunctions.rteerase(fmsO, value)
  R.erase(B747_fmc_route)
  B747_fmc_route_changed()
end
function fmsFunctions.rteexec(fmsO, value)
  -- the airplane's position: a direct-to's start (step 5e)
  if R.exec(B747_fmc_route, {lat = simDR_latitude, lon = simDR_longitude}) then B747_fmc_route_changed() end
end
fmsFunctionsDefs["RTE1"]["exec"]={"rteexec", ""}
fmsFunctionsDefs["RTE1"]["next"]=nil
fmsFunctionsDefs["RTE1"]["prev"]=nil
