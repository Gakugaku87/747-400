-- RTE 1 LEGS and RTE 2 LEGS (6-1/6-2 step 5c, RTE 2 step 7e4;
-- notes/ATA-34-61-FMC.md §18, §40): the FMC's routes
-- (B747.68.route_model.lua) five waypoints a page (FCOM p.1330-1334):
-- each one's course and distance from the one before (from the airplane to
-- the active waypoint), its speed and altitude constraint in large font
-- (the predictions in small font with the performance, step 8); a ROUTE
-- DISCONTINUITY's boxes; the waypoints entered, deleted and their
-- constraints on the line select keys; DIRECT TO and INTC CRS on the active
-- route's first line (FMSPG p.141-144), ABEAM PTS on its modification
-- (step 7e2: FCOM p.1333-1334; FMSPG p.136-139) and RTE COPY (step 7e4:
-- FCOM p.1334; FMSPG p.135-136); <RTE 2 LEGS and <RTE 1 LEGS at 6L (FCOM
-- p.1330's figure). Before: X-Plane's LEGS page shown through. RTE LEGS
-- HOLD AT (step 7b; FCOM p.1414; FMSPG p.157-158): the active route's LEGS
-- pages with the HOLD AT boxes and PPOS> (B744.fms.pages.hold.lua).
local R = B747_route_model
local BLANK = "                        "
local DISC_TITLE = "-- ROUTE DISCONTINUITY -"

local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function leg_index(pgNo, k) return (pgNo - 1) * 5 + k end
-- the route of the page a CDU shows: LEGS RTE 1's, LEGS2 RTE 2's, LEGSHOLD
-- the active route's
local PAGE_NUM = {LEGS = 1, LEGS2 = 2}
local function st_of(fmsO)
  local n = PAGE_NUM[fmsO.targetPage]
  return n and B747_fmc_route_num(n) or B747_fmc_route
end

local function num_pages(st)
  return math.max(1, math.ceil((#R.shown(st).legs + 1) / 5))
end

local function title(st)
  local s = R.status(st)
  local t = (s ~= "" and (s .. " ") or "") .. "RTE " .. st.num .. " LEGS"
  return pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)
end

-- the airplane's position (the active waypoint's leg)
local function airplane() return {lat = simDR_latitude, lon = simDR_longitude} end

-- where leg `i` starts: the airplane for the active route's first leg,
-- else the waypoint before it (the origin's runway or the origin before
-- the first); nil after a discontinuity
local function leg_start(st, r, i)
  if i == 1 and st.active then return airplane() end
  return R.leg_from(r, i)
end

-- a course in the CDU's form: magnetic from the nearest VOR's variation,
-- else true with T (FCOM p.1331)
local function course_text(crs, lat, lon)
  local var = B747_navdb.variation(B747_fmc_navdb, lat, lon)
  local c, t = crs, "T"
  if var then c, t = (crs - var) % 360, "" end
  local n = math.floor(c + 0.5) % 360
  return string.format("%03d`%s", n == 0 and 360 or n, t)
end

-- a leg's title line (FCOM p.1331-1332): the course into the waypoint
-- (the INTC CRS; a procedure's course, or its heading with HDG; HOLD AT
-- for a hold, PROC HOLD for a procedure's in lieu of a procedure turn
-- (HF: FCOM p.1331, p.1416), PROC TURN for a procedure turn (PI: step 7c);
-- else the great circle's from where the leg starts, dashes when
-- undefined) and the distance (none for a conditional waypoint: FMSPG
-- p.119), its last character at the 14th place (FCOM p.1330, p.1333 and
-- FMSPG p.137-139's figures: before step 7e2 at the 17th, under the
-- constraints)
local function leg_title(st, r, i)
  local l = r.legs[i]
  local pt = l.pt or ""
  if pt == "HF" then return pad(" PROC HOLD") end
  if pt == "PI" then return pad(" PROC TURN") end
  if pt == "HA" or pt == "HM" then return pad(" HOLD AT") end
  local from = leg_start(st, r, i)
  local crs, dist = "---`", ""
  if l.fix and from then
    local c, d = R.course(from.lat, from.lon, l.fix.lat, l.fix.lon)
    crs = course_text(c, from.lat, from.lon)
    dist = string.format("%dNM", math.floor(d + 0.5))
  end
  if l.crs and pt ~= "" and pt ~= "TF" and pt ~= "DF" and pt ~= "IF" then
    local n = math.floor(l.crs + 0.5) % 360
    -- a heading with HDG ("180` HDG"; an FM leg a course: FCOM p.1249)
    crs = string.format("%03d`", n == 0 and 360 or n) .. (pt:sub(1, 1) == "V" and " HDG" or "")
  end
  if not l.fix then dist = "" end
  -- the INTC CRS: the crew's magnetic course
  if l.dto and l.crs then crs = string.format("%03d`", l.crs == 0 and 360 or l.crs) end
  return pad(string.format(" %-7s%6s", crs, dist))
end

local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end
local function crz_alt() return B747_cdu_model.parse_alt((string.gsub(fmsModules["data"]["crzalt"], "%s+$", ""))) end

-- the active route's direct-to modification: the INTC CRS line at 6R
-- (boxes, or the route's course into the waypoint with its caret: FMSPG
-- p.144); none once ABEAM PTS made the abeam points (FMSPG p.139's figure)
local function dto_mod(st)
  local m = st.active and st.mod
  local l = m and m.legs[1]
  return l and l.dto and not m.abeam and l or nil
end

-- ABEAM PTS on the direct-to modification's first page (FCOM p.1333-1334;
-- FMSPG p.138-139): "ABEAM PTS>" at 4R under dashes, then ABEAM PTS
-- SELECTED, until another change (in the 4th waypoint's constraint's
-- place; the first page only: estimate)
local function abeam_state(st, pgNo)
  if pgNo ~= 1 or not st.active then return nil end
  if R.abeam_offered(st) then return "offered" end
  if R.abeam_selected(st) then return "selected" end
  return nil
end
-- RTE COPY at 5R likewise (FCOM p.1334; FMSPG p.135-136): RTE COPY>, then
-- RTE COPY COMPLETE while the modification stays as it is
local function copy_state(st, pgNo)
  if pgNo ~= 1 or not st.active then return nil end
  if R.copy_offered(st) then return "offered" end
  if st.mod and st.dto_offer == st.edits and R.copy_done(st) then return "complete" end
  return nil
end

-- the LEGS page's lines, its line select keys' functions in `defs`;
-- `hold_at`: RTE LEGS HOLD AT, the HOLD AT boxes at 6L and PPOS> at 6R
-- (FCOM p.1414)
local function legs_page(st, pgNo, defs, hold_at)
  local r = R.shown(st)
  local lines = {title(st)}
  for k = 1, 5 do
    local i = leg_index(pgNo, k)
    local l = r.legs[i]
    defs["L" .. k] = {"legsfix", tostring(k)}
    defs["R" .. k] = {"legscons", tostring(k)}
    lines[#lines + 1] = BLANK
    if l and (l.disc or l.pending) then
      lines[#lines + 1] = pad("*****")
    elseif l then
      lines[#lines + 1] = lr(R.leg_name(l), R.constraint_text(l, trans_alt()) or "")
    elseif i == #r.legs + 1 then
      lines[#lines + 1] = pad("-----")
    else
      lines[#lines + 1] = BLANK
    end
  end
  local ab = not hold_at and abeam_state(st, pgNo)
  if ab then
    defs["R4"] = {"legsabeam", ""}
    lines[8] = ab == "offered" and string.rep(" ", 14) .. "----------" or BLANK
    lines[9] = string.sub(lines[9], 1, 14) .. (ab == "offered" and "ABEAM PTS>" or "  SELECTED")
  end
  local cp = not hold_at and copy_state(st, pgNo)
  if cp then
    defs["R5"] = {"legscopy", ""}
    lines[11] = cp == "offered" and string.sub(lines[11], 1, 15) .. "RTE COPY>" or string.sub(lines[11], 1, 16) .. "COMPLETE"
  end
  if hold_at then
    defs["L6"] = {"legsholdat", ""}
    defs["R6"] = {"legsholdppos", ""}
    lines[12] = "--------HOLD AT---------"
    lines[13] = lr("*****", "PPOS>")
    return lines
  end
  local d = dto_mod(st)
  -- 6L: ERASE on a modification, else the other route's LEGS pages
  local o = 3 - st.num
  defs["L6"] = st.mod and {"rteerase", ""} or {"setpage", o == 2 and "LEGS2" or "LEGS"}
  local left = st.mod and "<ERASE" or ("<RTE " .. o .. " LEGS")
  local right = ""
  defs["R6"] = nil
  if d then
    defs["R6"] = {"legsintc", ""}
    right = d.crs and string.format("%03d`", d.crs == 0 and 360 or d.crs)
      or (d.route_crs and string.format("%03d`>", d.route_crs == 0 and 360 or d.route_crs) or "***")
  elseif not st.active and not st.activating then
    defs["R6"] = {"rteactivate", ""}
    right = "ACTIVATE>"
  end
  lines[12] = d and "-------------           " or "------------------------"
  lines[13] = lr(left, right)
  return lines
end
local function legs_small(st, pgNo, hold_at)
  local r = R.shown(st)
  local lines = {string.format("%23s ", pgNo .. "/" .. num_pages(st))}
  for k = 1, 5 do
    local i = leg_index(pgNo, k)
    local l = r.legs[i]
    local prev = r.legs[i - 1]
    local t = BLANK
    if l and (l.disc or l.pending) then
      t = " THEN"
    elseif l and prev and (prev.disc or prev.pending) then
      t = DISC_TITLE
    elseif l then
      t = leg_title(st, r, i)
    end
    lines[#lines + 1] = pad(t)
    lines[#lines + 1] = BLANK
  end
  local ab = not hold_at and abeam_state(st, pgNo)
  if ab then
    lines[8] = ab == "offered" and string.sub(lines[8], 1, 14) .. "          " or string.sub(lines[8], 1, 15) .. "ABEAM PTS"
  end
  if not hold_at and copy_state(st, pgNo) == "complete" then
    lines[10] = string.sub(lines[10], 1, 16) .. "RTE COPY"
  end
  lines[12] = (dto_mod(st) and not hold_at) and "                INTC CRS" or BLANK
  lines[13] = BLANK
  return lines
end
local function make_legs(name, num)
  fmsPages[name]=createPage(name)
  fmsPages[name].getNumPages=function(self)
    return num_pages(B747_fmc_route_num(num))
  end
  fmsPages[name].getPage=function(self,pgNo,fmsID)
    return legs_page(B747_fmc_route_num(num), pgNo, fmsFunctionsDefs[name], false)
  end
  fmsPages[name].getSmallPage=function(self,pgNo,fmsID)
    return legs_small(B747_fmc_route_num(num), pgNo, false)
  end
  fmsFunctionsDefs[name]={}
  fmsFunctionsDefs[name]["exec"]={"rteexec", ""}
end
make_legs("LEGS", 1)
make_legs("LEGS2", 2)
-- the LEGS key (B744.createfms.lua): the active route's LEGS pages (FCOM
-- p.1330's figure), RTE 1's with none active
function B747_cdu_legs_page(fmsO)
  fmsO.targetCustomFMC = true
  fmsO.targetPage = B747_fmc_route.num == 2 and "LEGS2" or "LEGS"
  fmsO.targetpgNo = 1
end
fmsPages["LEGSHOLD"]=createPage("LEGSHOLD")
fmsPages["LEGSHOLD"].getNumPages=function(self)
  return num_pages(B747_fmc_route)
end
fmsPages["LEGSHOLD"].getPage=function(self,pgNo,fmsID)
  return legs_page(B747_fmc_route, pgNo, fmsFunctionsDefs["LEGSHOLD"], true)
end
fmsPages["LEGSHOLD"].getSmallPage=function(self,pgNo,fmsID)
  return legs_small(B747_fmc_route, pgNo, true)
end
fmsFunctionsDefs["LEGSHOLD"]={}
fmsFunctionsDefs["LEGSHOLD"]["exec"]={"rteexec", ""}

-- a waypoint over leg i (FMSPG p.82, p.91, p.141): an empty scratchpad
-- copies its identifier; DELETE deletes it (not the active waypoint in
-- the air, but the hold flown: FCOM p.1416); an entry on the active
-- route's first line is a DIRECT TO; HOLD AT XXXXX (a waypoint not in the
-- route: FCOM p.1414) its hold there
function fmsFunctions.legsfix(fmsO, value)
  local st = st_of(fmsO)
  local r = R.shown(st)
  local i = leg_index(fmsO.pgNo, tonumber(value))
  local l = r.legs[i]
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if l and l.fix then fmsO["scratchpad"] = l.fix.ident end
    return
  end
  if sp == "DELETE" then
    if st.active and i == 1 and simDR_onGround == 0 and not R.is_hold(l) then fmsO["notify"] = "INVALID DELETE" return end
    B747_fmc_route_entry(fmsO, R.legs_delete(st, i))
    return
  end
  if st == B747_fmc_route and B747_cdu_hold_at_entry(fmsO, i) then return end
  if i > #r.legs + 1 then fmsO["notify"] = "INVALID ENTRY" return end
  local near = leg_start(st, r, i) or (i == 1 and airplane()) or r.origin
  B747_fmc_with_fix(fmsO, sp, near, function(p)
    if st.active and i == 1 then
      -- the route's course into it when it is later in the route
      local rc = nil
      for j = 1, #r.legs do
        local f = r.legs[j].fix
        if f and f.ident == p.ident and math.abs(f.lat - p.lat) < 1e-4 and math.abs(f.lon - p.lon) < 1e-4 then
          local from = R.leg_from(r, j)
          if from then
            local c = R.course(from.lat, from.lon, p.lat, p.lon)
            local var = B747_navdb.variation(B747_fmc_navdb, from.lat, from.lon)
            rc = math.floor((c - (var or 0)) % 360 + 0.5) % 360
          end
          break
        end
      end
      B747_fmc_route_entry(fmsO, R.direct_to(st, p, rc, airplane()))
    else
      B747_fmc_route_entry(fmsO, R.legs_entry(st, i, p))
    end
  end, st)
end

-- a speed and altitude constraint "XXX/", "XXX/ALT", "/ALT" or "ALT", ALT
-- an altitude with A, B or a block "220A240B" (either way round) (FCOM
-- p.1332; FMSPG p.125-128)
local function parse_alt_kind(s)
  local a1, a2 = s:match("^(%-?F?L?%d+)A(F?L?%d+)B$")
  local b1, b2 = s:match("^(F?L?%d+)B(%-?F?L?%d+)A$")
  if a1 or b1 then
    local lo, hi
    if a1 then lo, hi = B747_cdu_model.parse_alt(a1), B747_cdu_model.parse_alt(a2)
    else hi, lo = B747_cdu_model.parse_alt(b1), B747_cdu_model.parse_alt(b2) end
    if not (lo and hi) or lo >= hi then return nil end
    return lo, hi, "AB"
  end
  local a, k = s:match("^(%-?F?L?%d+)([AB]?)$")
  local ft = a and B747_cdu_model.parse_alt(a)
  if not ft then return nil end
  return ft, nil, k
end
local function parse_constraint(s)
  local spd, alt = s:match("^(%d*)/(.*)$")
  if not spd then spd, alt = "", s end
  local c = {}
  if spd ~= "" then
    if not spd:match("^%d%d%d$") then return nil end
    c.spd = tonumber(spd)
  end
  if alt ~= "" then
    c.alt, c.alt2, c.akind = parse_alt_kind(alt)
    if not c.alt then return nil end
  end
  if not (c.spd or c.alt) then return nil end
  return c
end
-- the RTE HOLD page's SPD/TGT ALT too (step 7b)
B747_cdu_parse_constraint = parse_constraint
function fmsFunctions.legscons(fmsO, value)
  local st = st_of(fmsO)
  local i = leg_index(fmsO.pgNo, tonumber(value))
  local l = R.shown(st).legs[i]
  local sp = fmsO["scratchpad"]
  if sp == "" then
    local t = l and l.fix and R.constraint_text(l, trans_alt())
    if t then fmsO["scratchpad"] = t end
    return
  end
  if sp == "DELETE" then
    B747_fmc_route_entry(fmsO, R.delete_constraint(st, i))
    return
  end
  local c = parse_constraint(sp)
  if not c then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.set_constraint(st, i, c, crz_alt()))
end

-- ABEAM PTS> (FCOM p.1334; FMSPG p.138): the abeam points made, the
-- scratchpad as it is (a prompt)
function fmsFunctions.legsabeam(fmsO, value)
  if not R.abeam_offered(B747_fmc_route) then return end
  local err = R.abeam_points(B747_fmc_route, airplane())
  if err then fmsO["notify"] = err return end
  B747_fmc_route_changed()
end

-- INTC CRS: a course (0-360) or, with an empty scratchpad, the route's
-- course offered (FMSPG p.143-144)
-- RTE COPY> (FCOM p.1334; FMSPG p.135): the active route into the other
function fmsFunctions.legscopy(fmsO, value)
  if not R.copy_offered(B747_fmc_route) then return end
  local err = R.copy_active(B747_fmc_route, B747_fmc_route2)
  if err then fmsO["notify"] = err end
end

function fmsFunctions.legsintc(fmsO, value)
  local d = dto_mod(B747_fmc_route)
  if not d then return end
  local sp = fmsO["scratchpad"]
  local crs
  if sp == "" then
    crs = d.route_crs
  else
    crs = B747_cdu_model.parse_int(sp, 0, 360)
  end
  if not crs then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.intc_crs(B747_fmc_route, crs))
end
