-- RTE 1 and RTE 2 (6-1/6-2 step 5b, RTE 2 step 7e4; notes/ATA-34-61-FMC.md
-- §18, §40): the FMC's routes (B747.68.route_model.lua) on their own
-- pages. Page 1: ORIGIN, DEST, RUNWAY, FLT NO, CO ROUTE and ACTIVATE (FCOM
-- p.1287-1290); the next pages the route's segments, VIA and TO five a
-- page, dashes after the end (FCOM p.1296-1298). The title RTE n, ACT RTE n
-- or MOD RTE n, ERASE at 6L on a modification (FCOM p.1238), else the
-- other route's pages (<RTE 2, <RTE 1: FCOM p.1289, p.1296's figure);
-- RTE COPY at 5L of the active route's page 1 (FCOM p.1289, p.1293's
-- figure: COMPLETE after it, under its title: estimate). Before: X-Plane's
-- RTE page shown through. OFFSET at 6R in the air on the active route, its
-- active leg not a SID's, a STAR's or an approach's (step 7d; FCOM p.1298;
-- FMSPG p.155-156).
local R = B747_route_model
local BLANK = "                        "

local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function rows_on(pg) return (pg - 2) * 5 end
-- the route of the page a CDU shows (its keys' route)
local PAGE_NUM = {RTE1 = 1, RTE2 = 2}
local function st_of(fmsO) return B747_fmc_route_num(PAGE_NUM[fmsO.targetPage] or B747_fmc_route.num) end

-- the number of pages: page 1 and the segments with the dashes line, five
-- a page (two at least: FCOM p.1287)
local function num_pages(st)
  local n = #R.segments(R.shown(st)) + 1
  return 1 + math.max(1, math.ceil(n / 5))
end

local function title(st)
  local s = R.status(st)
  local t = (s ~= "" and (s .. " ") or "") .. "RTE " .. st.num
  return pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)
end

-- 6R: ACTIVATE on the inactive route (until EXEC), then PERF INIT until
-- the performance data are complete, then TAKEOFF (FCOM p.1290); OFFSET in
-- the air (step 7d)
local function offset_shown(st)
  return R.offset_allowed(st, simDR_onGround == 0)
end
local function offset_text(st)
  local d = R.shown(st).offset
  if not d then return "---" end
  return (d < 0 and "L" or "R") .. tostring(math.abs(d))
end
-- (step 12h1) the route's flight plan uplink from the company (FMC COMM:
-- B747_fms_company), and whether it is being loaded
local function uplink_of(st)
  local up = B747_fms_datalink() and B747_fms_company().up
  return up and up.num == st.num and up or nil
end
local function six_right(st)
  -- blank while an uplink is loaded (FMSPG p.372)
  local up = uplink_of(st)
  if up and up.loading then return "", nil end
  if not st.active then return "ACTIVATE>", {"rteactivate", ""} end
  if offset_shown(st) then return offset_text(st), {"rteoffset", ""} end
  if not perf_init_complete() then return "PERF INIT>", {"setpage", "PERFINIT"} end
  return "TAKEOFF>", {"setpage", "TAKEOFF"}
end
-- 6L: ERASE on a modification, else the other route's pages
local function six_left(st)
  if st.mod then return "<ERASE", {"rteerase", ""} end
  local o = 3 - st.num
  return "<RTE " .. o, {"setpage", "RTE" .. o}
end

local function make_rte(name, num)
  fmsPages[name]=createPage(name)
  fmsPages[name].getNumPages=function(self)
    return num_pages(B747_fmc_route_num(num))
  end
  fmsPages[name].getPage=function(self,pgNo,fmsID)
    local st = B747_fmc_route_num(num)
    local r = R.shown(st)
    local defs = fmsFunctionsDefs[name]
    local sr, srDef = six_right(st)
    local sl, slDef = six_left(st)
    defs["R6"], defs["L6"] = srDef, slDef
    local six = lr(sl, sr)
    if pgNo == 1 then
      defs["L1"] = {"rteorigin", ""}
      defs["R1"] = {"rtedest", ""}
      defs["L2"] = {"rterunway", ""}
      defs["R2"] = {"setdata", "fltno"}
      defs["R3"] = {"rtecoroute", ""}
      for _, k in ipairs({"L3", "L4", "L5", "R4", "R5"}) do defs[k] = nil end
      local copy = ""
      if st.active then
        copy = R.copy_done(st) and "COMPLETE" or "<RTE COPY"
        if copy == "<RTE COPY" then defs["L5"] = {"rtecopy", ""} end
      end
      local fltno = string.format("%8s", (string.gsub(fmsModules["data"]["fltno"], "%s+$", "")))
      local origin = r.origin and r.origin.ident or "****"
      local dest = r.dest and r.dest.ident or "****"
      local runway = r.runway and r.runway.ident or "-----"
      -- (step 12h1) the company datalink (405, 570: FCOM p.1288-1291;
      -- FMSPG p.370-376): REQUEST <SEND (SENDING; blank while a flight
      -- plan uplink waits), the data link's status when not READY, the
      -- ROUTE UPLINK line with LOAD and PURGE (an inactive route's, not
      -- while loading)
      local send, dashes, load = "", "------------------------", BLANK
      if B747_fms_datalink() then
        local c = B747_fms_company()
        local up = uplink_of(st)
        local status = B747_fms_company_status()
        if up then
          B747_fms_company_reviewed()
          dashes = "-----              -----"
          local purge = not st.active and not up.loading
          load = lr("<LOAD", purge and "PURGE>" or "")
          defs["L4"] = {"rteload", ""}
          if purge then defs["R4"] = {"rtepurge", ""} end
        elseif not c.up then
          if status ~= "READY" then
            send = status
          else
            local q = c.req
            send = (q and q.route == num and q.status == "SENDING") and "SENDING" or "<SEND"
            if send == "<SEND" then defs["L3"] = {"rterequest", ""} end
          end
        end
      end
      return {
        title(st), BLANK,
        lr(origin, dest), BLANK,
        lr(runway, fltno), BLANK,
        lr(send, st.co_route or "----------"), dashes,
        load, BLANK,
        pad(copy), BLANK,
        six
      }
    end
    local segs = R.segments(r)
    local lines = {title(st)}
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
    -- the dashes over 6L (FCOM p.1296's figure), short of OFFSET (p.1298)
    lines[12] = offset_shown(st) and "------------------      " or "------------------------"
    lines[13] = six
    return lines
  end
  fmsPages[name].getSmallPage=function(self,pgNo,fmsID)
    local st = B747_fmc_route_num(num)
    local n = num_pages(st)
    local pn = string.format("%23s ", pgNo .. "/" .. n)
    -- the OFFSET label in small font at the dashes' end (FCOM p.1298)
    local off = offset_shown(st) and "                  OFFSET" or BLANK
    if pgNo == 1 then
      local copied = st.active and R.copy_done(st)
      -- (step 12h1) REQUEST (DATA LINK when not READY) and its SENT, ROUTE
      -- UPLINK (FCOM p.1289, p.1291; FMSPG p.372)
      local co, sent, uplink = "                CO ROUTE", BLANK, BLANK
      if B747_fms_datalink() then
        local c = B747_fms_company()
        if uplink_of(st) then
          uplink = "      ROUTE UPLINK      "
        elseif not c.up then
          local ready = B747_fms_company_status() == "READY"
          co = (ready and " REQUEST" or " DATA LINK") .. string.sub(co, ready and 9 or 11)
          local q = c.req
          if ready and q and q.route == num and q.status == "SENT" then sent = "     SENT               " end
        end
      end
      return {
        pn, " ORIGIN             DEST", BLANK,
        " RUNWAY           FLT NO", BLANK,
        co, sent,
        uplink, BLANK, copied and " RTE COPY               " or BLANK, BLANK, off, BLANK
      }
    end
    return {pn, " VIA                  TO", BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, off, BLANK}
  end
  fmsFunctionsDefs[name]={}
  fmsFunctionsDefs[name]["exec"]={"rteexec", ""}
end
make_rte("RTE1", 1)
make_rte("RTE2", 2)

-- the RTE key (B744.createfms.lua) and the ROUTE> prompts: the active
-- route's pages, RTE 1's with none active (FCOM p.1287: RTE 2 active, the
-- same logic)
function B747_cdu_rte_page(fmsO)
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "RTE" .. B747_fmc_route.num
  fmsO.targetpgNo = 1
end
function fmsFunctions.rtepage(fmsO, value)
  B747_cdu_rte_page(fmsO)
end

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
-- NOT IN DATA BASE when none (the RTE and LEGS pages); `list`, the
-- candidates when the page takes only some (REF NAV DATA's inhibits);
-- `st` the route entered into (its airports' terminal waypoints; the
-- active one by default)
function B747_fmc_with_point(fmsO, ident, near, done, list, st)
  local lat, lon = simDR_latitude, simDR_longitude
  if near then lat, lon = near.lat, near.lon end
  list = list or R.candidates(st or B747_fmc_route, ident, lat, lon)
  if #list == 0 then fmsO["notify"] = "NOT IN DATA BASE" return end
  if #list == 1 then done(list[1]) return end
  -- (2026-11-12 review FMC-9) one of them downtrack in the active route:
  -- that one, no SELECT DESIRED WPT (FCOM p.1249 (11.31.15)); before, the
  -- page, and another one picked made an insertion and a discontinuity
  -- in place of the direct-to
  -- (the RTE and LEGS pages' entries: their route given; FIX INFO, REF NAV
  -- DATA, OFFPATH and HOLD AT as before)
  if st and st.active then
    for _, l in ipairs(R.shown(st).legs) do
      if l.fix and l.fix.ident == ident and not l.disc then done(l.fix) return end
    end
  end
  selwpt[fmsO.id] = {list = list, done = done, page = fmsO.currentPage, pgNo = fmsO.pgNo, sp = fmsO["scratchpad"]}
  fmsO.targetCustomFMC = true
  fmsO.targetPage = "SELWPT"
  fmsO.targetpgNo = 1
end

-- a waypoint entered on the RTE and LEGS pages: a database point (or a
-- waypoint of the route the crew defined: B747_fmc_with_point), or one
-- the crew defines (step 7e3a; FCOM p.1245, p.1249-1250): latitude/
-- longitude, place/bearing/distance, place bearing/place bearing; the
-- first place by SELECT DESIRED WPT, the second the nearest to it
-- (estimate); INVALID ENTRY when the radials do not meet; `st` the route
function B747_fmc_with_fix(fmsO, sp, near, done, st)
  st = st or B747_fmc_route
  local ll = R.parse_latlon(sp)
  if ll then done(ll) return end
  local e = R.parse_pbd(sp)
  if not e then B747_fmc_with_point(fmsO, sp, near, done, nil, st) return end
  B747_fmc_with_point(fmsO, e.place, near, function(place)
    local place2 = nil
    if e.place2 then
      place2 = R.candidates(st, e.place2, place.lat, place.lon)[1]
      if not place2 then fmsO["notify"] = "NOT IN DATA BASE" return end
    end
    local f = R.pbd_fix(st, e, place, place2)
    if not f then fmsO["notify"] = "INVALID ENTRY" return end
    done(f)
  end, nil, st)
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
  local st = st_of(fmsO)
  local r = R.shown(st)
  local sp = copy_or_entry(fmsO, r.origin and r.origin.ident)
  if not sp then return end
  -- in flight only on the inactive route (FCOM p.1288)
  if simDR_onGround == 0 and st.active then fmsO["notify"] = "INVALID ENTRY" return end
  entry(fmsO, R.set_origin(st, sp))
end
function fmsFunctions.rtedest(fmsO, value)
  local st = st_of(fmsO)
  local r = R.shown(st)
  local sp = copy_or_entry(fmsO, r.dest and r.dest.ident)
  if not sp then return end
  entry(fmsO, R.set_dest(st, sp))
end
function fmsFunctions.rterunway(fmsO, value)
  local st = st_of(fmsO)
  local r = R.shown(st)
  local sp = copy_or_entry(fmsO, r.runway and r.runway.ident)
  if not sp then return end
  entry(fmsO, R.set_runway(st, sp))
end
-- CO ROUTE: no company routes in the database: NOT IN DATA BASE, the
-- entry kept for the company's route request (FCOM p.1290; step 12h1),
-- DELETE clears it (FCOM p.774)
function fmsFunctions.rtecoroute(fmsO, value)
  local st = st_of(fmsO)
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if st.co_route then fmsO["scratchpad"] = st.co_route end
    return
  end
  local msg = B747_fms_company_co_route(st.num, sp ~= "DELETE" and sp or nil)
  if msg == "INVALID ENTRY" then fmsO["notify"] = msg return end
  fmsO["scratchpad"] = ""
  if msg then fmsO["notify"] = msg end
end
-- (step 12h1) REQUEST <SEND, LOAD and PURGE (FCOM p.1289, p.1291)
function fmsFunctions.rterequest(fmsO, value)
  B747_fms_company_request(fmsO, st_of(fmsO).num)
end
function fmsFunctions.rteload(fmsO, value)
  B747_fms_company_load(st_of(fmsO).num)
end
function fmsFunctions.rtepurge(fmsO, value)
  B747_fms_company_purge(st_of(fmsO).num)
end
function fmsFunctions.rtevia(fmsO, value)
  local st = st_of(fmsO)
  local segs = R.segments(R.shown(st))
  local i = rows_on(fmsO.pgNo) + tonumber(value)
  local s = segs[i]
  -- (2026-11-13; the review FMC-7, 案 20) DELETE: an airway's VIA (FMSPG
  -- p.82; R.rte_via_delete)
  if fmsO["scratchpad"] == "DELETE" then
    entry(fmsO, R.rte_via_delete(st, i, simDR_onGround == 0))
    return
  end
  local sp = copy_or_entry(fmsO, s and not s.disc and s.via ~= R.DIRECT and s.via or nil)
  if not sp then return end
  -- after the route's end only (other changes on the LEGS pages: estimate)
  if i ~= #segs + 1 then fmsO["notify"] = "INVALID ENTRY" return end
  entry(fmsO, R.add_via(st, sp))
end
function fmsFunctions.rteto(fmsO, value)
  local st = st_of(fmsO)
  local r = R.shown(st)
  local segs = R.segments(r)
  local i = rows_on(fmsO.pgNo) + tonumber(value)
  local s = segs[i]
  local sp = copy_or_entry(fmsO, s and s.to or nil)
  if not sp then return end
  -- (2026-11-13; the review FMC-7, 案 20) a discontinuity's boxes and a
  -- DIRECT segment's TO waypoint (a previous leg termination) take an entry
  -- too (FMSPG p.82), as on the LEGS pages over that leg (R.rte_to_entry);
  -- before, INVALID ENTRY there. An airway's TO line as before
  if s and i <= #segs and (s.disc or (s.via == R.DIRECT and s.to)) then
    local li = s.first
    if not s.disc then
      li = s.last
      while li > s.first and R.is_hold(r.legs[li]) do li = li - 1 end
    end
    local before = r.legs[li - 1]
    local near = (before and before.fix) or r.origin
    B747_fmc_with_fix(fmsO, sp, near, function(p) entry(fmsO, R.rte_to_entry(st, li, p, simDR_onGround == 0)) end, st)
    return
  end
  -- the dashes after the end, or an airway's boxes (FMSPG p.82)
  local boxes = s and not s.disc and s.to == nil and i == #segs
  if i ~= #segs + 1 and not boxes then fmsO["notify"] = "INVALID ENTRY" return end
  local before = r.legs[#r.legs - (boxes and 1 or 0)]
  local near = before and before.fix or r.origin
  B747_fmc_with_fix(fmsO, sp, near, function(p) entry(fmsO, R.add_to(st, p)) end, st)
end
-- OFFSET (FCOM p.1298; FMSPG p.156): L or R and 1-99 nm (R20, L5); L0, 0,
-- R0 or DELETE cancels it
function fmsFunctions.rteoffset(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local d
  if sp == "DELETE" or sp == "0" then
    d = 0
  else
    local side, n = sp:match("^([LR])(%d%d?)$")
    if not side then fmsO["notify"] = "INVALID ENTRY" return end
    d = tonumber(n) * (side == "L" and -1 or 1)
  end
  entry(fmsO, R.set_offset(st_of(fmsO), d, simDR_onGround == 0))
end
function fmsFunctions.rteactivate(fmsO, value)
  entry(fmsO, R.activate(st_of(fmsO)))
end
function fmsFunctions.rteerase(fmsO, value)
  R.erase(st_of(fmsO))
  -- (6-1/6-2 step 9d2b) the VNAV pages' 6R's part too; (step 9h4a) the
  -- engine-out modification; (step 9h5a) RTA's
  B747_fms_vnav_erase()
  B747_fms_eo_erase()
  B747_fms_rta_erase()
  B747_fmc_route_changed()
end
-- EXEC: the active route's modification or activation, else the other
-- route's activation (step 7e4: it becomes the active one); (step 9d2b)
-- the VNAV pages' 6R's part with it (DES NOW's early descent); (step
-- 9h4a) the engine-out modification (a performance one, no route's);
-- (step 9h5a) RTA's
function fmsFunctions.rteexec(fmsO, value)
  B747_fms_eo_exec()
  B747_fms_rta_exec()
  -- the airplane's position: a direct-to's start (step 5e)
  if R.exec_both(B747_fmc_route, B747_fmc_route2, {lat = simDR_latitude, lon = simDR_longitude}) then
    B747_fms_vnav_exec()
    B747_fmc_route_changed()
  end
end
-- RTE COPY (FCOM p.1289, p.1334; FMSPG p.134-136): the active route into
-- the other, COMPLETE
function fmsFunctions.rtecopy(fmsO, value)
  local err = R.copy_active(B747_fmc_route, B747_fmc_route2)
  if err then fmsO["notify"] = err end
end
