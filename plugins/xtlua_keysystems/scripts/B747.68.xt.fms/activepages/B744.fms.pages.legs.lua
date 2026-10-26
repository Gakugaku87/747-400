-- RTE 1 LEGS (6-1/6-2 step 5c; notes/ATA-34-61-FMC.md §18): the FMC's
-- route (B747.68.route_model.lua) five waypoints a page (FCOM p.1330-1334):
-- each one's course and distance from the one before (from the airplane to
-- the active waypoint), its speed and altitude constraint in large font
-- (the predictions in small font with the performance, step 8); a ROUTE
-- DISCONTINUITY's boxes; the waypoints entered, deleted and their
-- constraints on the line select keys; DIRECT TO and INTC CRS on the active
-- route's first line (FMSPG p.141-144). Before: X-Plane's LEGS page shown
-- through.
local R = B747_route_model
local BLANK = "                        "
local DISC_TITLE = "-- ROUTE DISCONTINUITY -"

local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function route() return R.shown(B747_fmc_route) end
local function leg_index(pgNo, k) return (pgNo - 1) * 5 + k end

local function num_pages()
  return math.max(1, math.ceil((#route().legs + 1) / 5))
end

local function title()
  local s = R.status(B747_fmc_route)
  local t = (s ~= "" and (s .. " ") or "") .. "RTE 1 LEGS"
  return pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)
end

-- the airplane's position (the active waypoint's leg)
local function airplane() return {lat = simDR_latitude, lon = simDR_longitude} end

-- where leg `i` starts: the airplane for the active route's first leg,
-- else the waypoint before it (the origin's runway or the origin before
-- the first); nil after a discontinuity
local function leg_start(r, i)
  if i == 1 and B747_fmc_route.active then return airplane() end
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
-- for a hold; else the great circle's from where the leg starts, dashes
-- when undefined) and the distance (none for a conditional waypoint:
-- FMSPG p.119)
local function leg_title(r, i)
  local l = r.legs[i]
  local pt = l.pt or ""
  if pt == "HA" or pt == "HF" or pt == "HM" then return pad(" HOLD AT") end
  local from = leg_start(r, i)
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
  return pad(string.format(" %-11s%5s", crs, dist))
end

local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end
local function crz_alt() return B747_cdu_model.parse_alt((string.gsub(fmsModules["data"]["crzalt"], "%s+$", ""))) end

-- the direct-to modification: the INTC CRS line at 6R (boxes, or the
-- route's course into the waypoint with its caret: FMSPG p.144)
local function dto_mod()
  local m = B747_fmc_route.mod
  local l = m and m.legs[1]
  return l and l.dto and l or nil
end

fmsPages["LEGS"]=createPage("LEGS")
fmsPages["LEGS"].getNumPages=function(self)
  return num_pages()
end
fmsPages["LEGS"].getPage=function(self,pgNo,fmsID)
  local r = route()
  local defs = fmsFunctionsDefs["LEGS"]
  local lines = {title()}
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
  local d = dto_mod()
  defs["L6"] = B747_fmc_route.mod and {"rteerase", ""} or nil
  local left = B747_fmc_route.mod and "<ERASE" or ""
  local right = ""
  defs["R6"] = nil
  if d then
    defs["R6"] = {"legsintc", ""}
    right = d.crs and string.format("%03d`", d.crs == 0 and 360 or d.crs)
      or (d.route_crs and string.format("%03d`>", d.route_crs == 0 and 360 or d.route_crs) or "***")
  elseif not B747_fmc_route.active and not B747_fmc_route.activating then
    defs["R6"] = {"rteactivate", ""}
    right = "ACTIVATE>"
  end
  lines[12] = d and "-------------           " or "------------------------"
  lines[13] = lr(left, right)
  return lines
end
fmsPages["LEGS"].getSmallPage=function(self,pgNo,fmsID)
  local r = route()
  local lines = {string.format("%23s ", pgNo .. "/" .. num_pages())}
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
      t = leg_title(r, i)
    end
    lines[#lines + 1] = pad(t)
    lines[#lines + 1] = BLANK
  end
  lines[12] = dto_mod() and "                INTC CRS" or BLANK
  lines[13] = BLANK
  return lines
end
fmsFunctionsDefs["LEGS"]={}
fmsFunctionsDefs["LEGS"]["exec"]={"rteexec", ""}

-- a waypoint over leg i (FMSPG p.82, p.91, p.141): an empty scratchpad
-- copies its identifier; DELETE deletes it (not the active waypoint in
-- the air); an entry on the active route's first line is a DIRECT TO
function fmsFunctions.legsfix(fmsO, value)
  local st = B747_fmc_route
  local r = route()
  local i = leg_index(fmsO.pgNo, tonumber(value))
  local l = r.legs[i]
  local sp = fmsO["scratchpad"]
  if sp == "" then
    if l and l.fix then fmsO["scratchpad"] = l.fix.ident end
    return
  end
  if sp == "DELETE" then
    if st.active and i == 1 and simDR_onGround == 0 then fmsO["notify"] = "INVALID DELETE" return end
    B747_fmc_route_entry(fmsO, R.legs_delete(st, i))
    return
  end
  if i > #r.legs + 1 then fmsO["notify"] = "INVALID ENTRY" return end
  local near = leg_start(r, i) or (i == 1 and airplane()) or r.origin
  B747_fmc_with_point(fmsO, sp, near, function(p)
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
      B747_fmc_route_entry(fmsO, R.direct_to(st, p, rc))
    else
      B747_fmc_route_entry(fmsO, R.legs_entry(st, i, p))
    end
  end)
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
function fmsFunctions.legscons(fmsO, value)
  local st = B747_fmc_route
  local i = leg_index(fmsO.pgNo, tonumber(value))
  local l = route().legs[i]
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

-- INTC CRS: a course (0-360) or, with an empty scratchpad, the route's
-- course offered (FMSPG p.143-144)
function fmsFunctions.legsintc(fmsO, value)
  local d = dto_mod()
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
