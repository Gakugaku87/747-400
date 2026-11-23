-- RTE 1 HOLD and RTE 1 LEGS HOLD AT (6-1/6-2 step 7b; notes/ATA-34-61-FMC.md
-- §33): the holds of the FMC's route (B747.68.route_model.lua) on the HOLD
-- key (FCOM p.1413-1419; FMSPG p.157-163, p.221-223).
--  - The HOLD key: the route's first hold's page, RTE LEGS HOLD AT without
--    one (the LEGS pages with the HOLD AT boxes and PPOS>:
--    B744.fms.pages.legs.lua).
--  - HOLD AT: a waypoint of the route, its hold after the leg to it; any
--    other, HOLD AT XXXXX in the scratchpad to put on a LEGS line (not the
--    active waypoint); PPOS, a hold where the airplane is at EXEC. Then the
--    MOD RTE 1 HOLD page.
--  - RTE 1 HOLD, a page a hold: FIX (PROC HOLD for a procedure's in lieu
--    of a procedure turn, HOLD AT for one ended at an altitude), QUAD/
--    RADIAL, INBD CRS/DIR, LEG TIME, LEG DIST, SPD/TGT ALT, EFC TIME, NEXT
--    HOLD or ERASE, EXIT HOLD and EXIT ARMED. FIX ETA, HOLD AVAIL and BEST
--    SPEED from the predictions and the performance data (2026-11-24,
--    CDU-4: below; before, dashes always).
-- Before: X-Plane's HOLD page shown through.
local R = B747_route_model
local BLANK = "                        "

local function pad(s) return string.sub(s .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function route() return R.shown(B747_fmc_route) end
local function trans_alt() return tonumber(fmsModules["data"]["transalt"]) or 18000 end
local function crz_alt() return B747_cdu_model.parse_alt((string.gsub(fmsModules["data"]["crzalt"], "%s+$", ""))) end
local function airplane() return {lat = simDR_latitude, lon = simDR_longitude} end

-- the page of the hold at leg i (its number among the route's holds)
local function show_hold(fmsO, i)
  for k, j in ipairs(R.holds(route())) do
    if j == i then
      fmsO.targetCustomFMC, fmsO.targetPage, fmsO.targetpgNo = true, "RTEHOLD", k
      return
    end
  end
end
-- a hold made: the scratchpad emptied, its page (MOD RTE 1 HOLD: FMSPG
-- p.158)
local function made(fmsO, i, err)
  if err then fmsO["notify"] = err return end
  B747_fmc_route_entry(fmsO, nil)
  show_hold(fmsO, i)
end

-- the HOLD key (FCOM p.1413, p.1416; FMSPG p.222): the route's first hold
-- (the nearest), else RTE LEGS HOLD AT
function B747_cdu_hold_page(fmsO)
  fmsO.targetCustomFMC = true
  fmsO.targetpgNo = 1
  fmsO.targetPage = #R.holds(route()) > 0 and "RTEHOLD" or "LEGSHOLD"
end

-- each CDU's HOLD AT XXXXX: the waypoint in its scratchpad
local holdAtFix = {}
local HOLD_AT = "HOLD AT "
-- 6L, the HOLD AT boxes (FCOM p.1414; FMSPG p.158): a waypoint of the
-- route, its hold; another, HOLD AT XXXXX in the scratchpad
function fmsFunctions.legsholdat(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  B747_fmc_with_point(fmsO, sp, airplane(), function(p)
    local j = R.find_fix(route(), p)
    if j then
      made(fmsO, R.hold_at(B747_fmc_route, j, crz_alt()))
      return
    end
    fmsO["scratchpad"] = HOLD_AT .. p.ident
    holdAtFix[fmsO.id] = p
  end)
end
-- HOLD AT XXXXX put on LEGS line i (from legsfix): its waypoint and its
-- hold there. False when the scratchpad holds something else
function B747_cdu_hold_at_entry(fmsO, i)
  local p = holdAtFix[fmsO.id]
  if not (p and fmsO["scratchpad"] == HOLD_AT .. p.ident) then return false end
  local h, err = R.hold_insert(B747_fmc_route, i, p, crz_alt(), airplane())
  if not err then holdAtFix[fmsO.id] = nil end
  made(fmsO, h, err)
  return true
end
-- 6R, PPOS> (FCOM p.1415): a hold where the airplane is at EXEC
function fmsFunctions.legsholdppos(fmsO, value)
  local ppos = airplane()
  ppos.trk = B747_fmc_track_mag()
  made(fmsO, R.hold_ppos(B747_fmc_route, ppos, crz_alt()))
end

-- RTE 1 HOLD (FCOM p.1415-1419; FMSPG p.159-163)
local QUADS = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
-- the quadrant of a radial (FMSPG p.159: N 337.5-022.5 ...)
local function quadrant(radial) return QUADS[math.floor(((radial + 22.5) % 360) / 45) + 1] end
local function deg(n)
  n = math.floor(n + 0.5) % 360
  return string.format("%03d`", n == 0 and 360 or n)
end
-- the hold on page pgNo: its leg
local function hold_of(pgNo)
  local i = R.holds(route())[pgNo]
  return i, i and route().legs[i]
end
-- the hold flown by LNAV (the active route's first leg): its state
local function flown(i, l)
  local st = B747_fmc_route
  local h = B747_fmc_lnav and B747_fmc_lnav.hp
  if not (st.active and i == 1 and h and l.fix) then return nil end
  if h.lat ~= l.fix.lat or h.lon ~= l.fix.lon then return nil end
  return h
end
-- 6R (FMSPG p.162): EXIT HOLD> on the active leg of the active route or
-- its modification, EXIT ARMED once armed: by the crew, at the altitude,
-- a hold of one loop flown
local function exit_text(i, l)
  local st = B747_fmc_route
  if not (st.active and i == 1) then return "" end
  local h = flown(i, l)
  if l.exit or (h and h.exit) then return "EXIT ARMED" end
  return "EXIT HOLD>"
end
-- (2026-11-24, stage 4 review CDU-4; notes/ATA-34-61-FMC.md §177.7) 2R FIX
-- ETA, 4R HOLD AVAIL and 5R BEST SPEED (FCOM p.1415, p.1417's figures,
-- p.1419 (11.43.31) items 8, 10, 11; FMSPG p.161-162; ATA34_2 p.574) from
-- the FMC's predictions and performance data; dashes without them. Before,
-- dashes always.
local KT = 1.94384
-- the shown hold's leg in the active route (a modification's copies its
-- legs: orig), for the predictions' points; nil
local function active_index(l)
  local st = B747_fmc_route
  if not st.active then return nil end
  local o = l.orig or l
  for j, x in ipairs(st.rte.legs) do
    if x == o then return j end
  end
  return nil
end
-- the speed limits of the phase's speed transition and restriction below
-- their altitudes at ft (the climb's in the climb, else the descent's)
local function limit_cas(cas, ft)
  local clb, des = B747_fms_schedules(B747_fms_perf())
  local s = (B747_fms_vnav_page()) == 1 and clb or des
  if s.trans_cas and s.trans_alt and ft < s.trans_alt then cas = math.min(cas, s.trans_cas) end
  if s.restr_cas and s.restr_alt and ft < s.restr_alt then cas = math.min(cas, s.restr_cas) end
  return cas
end
-- BEST SPEED (kt): the holding table's (PI 11.6, flaps up) at the FMC's
-- gross weight and the present altitude (ATA34_2 p.574: "for the present
-- altitude"; FCOM p.1419: gross weight, altitude and flap setting; flaps
-- out the flaps up table's too: estimate), limited by the hold's speed
-- constraint and the speed transition's and restriction's below their
-- altitudes (FMSPG p.162); nil without the FMC's gross weight
local function best_speed(l)
  local gw = perf_gw_t()
  if not gw then return nil end
  local ft = math.max(0, simDR_pressureAlt1)
  local cas = B747_perf_db.hold(B747_fms_perf(), gw * 1000, ft)
  if l.spd then cas = math.min(cas, l.spd) end
  return limit_cas(cas, ft)
end
-- the racetrack's loop (s) at kt
local function loop_s(r, len, kt) return (2 * len + 2 * math.pi * r) / math.max(kt, 60) * 3600 end
-- in the hold LNAV flies (h): the time (s) to the next crossing of the fix
-- along the rest of its racetrack at the ground speed, and the loop's;
-- the entries' legs and turns as LNAV flies them (B747.68.lnav_model.lua:
-- teardrop 2.95 r, parallel 2.41 r; their turns back 220 and 225 degrees,
-- the way back to the fix as long as the leg's way out: estimates)
local function in_hold_s(h)
  local P, t = B747_path_model, h.t
  local p = {lat = simDR_latitude, lon = simDR_longitude}
  local gs = math.max(simDR_groundspeed * KT, 60)
  local trk, r, len, sgn, u = simDR_lnav_trk, t.r, t.l, t.sgn, t.u
  local out = (u + 180) % 360
  local function arc(to, way) return math.rad(((to - trk) * way) % 360) * r end
  local ph, d = h.phase, nil
  if ph == "inbound" then
    local _, at = P.track(t.f, u, p)
    d = math.max(0, -at)
  elseif ph == "outbound" then
    local _, at = P.track(t.p1, out, p)
    d = math.max(0, len - at) + math.pi * r + len
  elseif ph == "turn1" or ph == "direct" then
    d = arc(out, sgn) + len + math.pi * r + len
  elseif ph == "turn2" then
    d = arc(u, sgn) + len
  elseif ph == "teardrop" then
    local _, at = P.track(t.f, (out - 40 * sgn) % 360, p)
    d = math.max(0, 2.95 * r - at) + math.rad(220) * r + 2.95 * r
  elseif ph == "parallel" then
    local _, at = P.track(t.f, out, p)
    d = math.max(0, 2.41 * r - at) + math.rad(225) * r + 2.41 * r
  elseif ph == "intercept" then
    local _, dd = P.course(p, t.f)
    d = arc(u, h.back == "L" and -1 or 1) + dd
  end
  if not d then return nil end
  return d / gs * 3600, loop_s(r, len, gs)
end
-- FIX ETA: the next crossing of the fix (in the hold LNAV flies, the rest
-- of its racetrack; ahead, the predictions' time there); with an EFC TIME
-- the first crossing at or after it (FCOM p.1419 item 8), a loop at the
-- predictions' speed there (the holding table's speed, limited as BEST
-- SPEED, as true airspeed: estimate). "HHMM.T " or nil
local function fix_eta(i, l)
  local h = flown(i, l)
  local s, loop
  if h and h.t and h.phase ~= "to" then
    s, loop = in_hold_s(h)
  else
    local pred, j = B747_fms_preds(), active_index(l)
    local q = pred and j and pred.pts[j]
    if not (q and q.t) then return nil end
    s = q.t
    local inp = B747_fms_pred_input_last()
    if l.efc and inp then
      local P = B747_perf_db
      local kg = inp.gw - ((inp.fuel or 0) - (q.fuel or inp.fuel or 0))
      local cas = limit_cas(P.hold(inp.t, kg, q.h), q.h)
      if l.spd then cas = math.min(cas, l.spd) end
      local tas = P.tas(P.cas_to_mach(cas, q.h), q.h, inp.isa)
      local r, len = B747_path_model.hold_size({time = l.time, dist = l.dist, alt = l.alt}, tas, tas)
      loop = loop_s(r, len, tas)
    end
  end
  if not s then return nil end
  local eh, em = l.efc and tonumber(l.efc:sub(1, 2)), l.efc and tonumber(l.efc:sub(3, 4))
  if eh and em and loop then
    local wait = ((eh * 60 + em - B747_fms_utc_min()) % 1440) * 60 - s
    if wait > 0 and wait < 720 * 60 then s = s + math.ceil(wait / loop) * loop end
  end
  local _, hh, mm, frac = get_ETA_for_Distance(0, s)
  return string.format("%02d%02d.%d ", hh, mm, math.min(9, math.floor(frac * 10)))
end
-- HOLD AVAIL: the holding time before the exit needed to reach the
-- destination with RESERVES (FCOM p.1419 item 10; FMSPG p.161: 4,000 lb
-- without a RESERVES entry), for a manually ended hold only (FMSPG p.223):
-- the predictions' fuel at the destination (an exit at once) less
-- RESERVES, at the holding table's fuel flow (four engines: estimate) at
-- the weight and altitude there (in the hold LNAV flies, the present
-- ones). "H+MM" or nil
local RESERVES_DEFAULT_KG = 4000 / 2.20462
local function hold_avail(i, l)
  if l.pt ~= "HM" then return nil end
  local pred, j, inp = B747_fms_preds(), active_index(l), B747_fms_pred_input_last()
  local q = pred and j and pred.pts[j]
  if not (q and inp and pred.dest and pred.dest.fuel) or pred.no_fuel then return nil end
  if pred.ed_i and j > pred.ed_i then return nil end
  local kg, ft = inp.gw - ((inp.fuel or 0) - (q.fuel or inp.fuel or 0)), q.h
  local h = flown(i, l)
  if h and h.phase ~= "to" then
    local gw = perf_gw_t()
    kg, ft = gw and gw * 1000 or kg, math.max(0, simDR_pressureAlt1)
  end
  local rsv = tonumber(fmsModules["data"]["reserves"])
  local spare = pred.dest.fuel - (rsv and rsv * 1000 or RESERVES_DEFAULT_KG)
  local _, ff = B747_perf_db.hold(inp.t, kg, ft)
  if not ff or ff <= 0 then return nil end
  local min = math.max(0, math.floor(spare / (4 * ff) * 60))
  return string.format("%d+%02d", math.floor(min / 60), min % 60)
end
local FIX_LABEL = {HM = " FIX", HA = " HOLD AT", HF = " PROC HOLD"}

fmsPages["RTEHOLD"]=createPage("RTEHOLD")
fmsPages["RTEHOLD"].getNumPages=function(self)
  return math.max(1, #R.holds(route()))
end
fmsPages["RTEHOLD"].getPage=function(self,pgNo,fmsID)
  local s = R.status(B747_fmc_route)
  local t = (s ~= "" and (s .. " ") or "") .. "RTE " .. B747_fmc_route.num .. " HOLD"
  local lines = {pad(string.rep(" ", math.floor((24 - #t) / 2)) .. t)}
  local i, l = hold_of(pgNo)
  if not l then
    -- no hold left (exited, deleted): RTE LEGS HOLD AT, as the HOLD key
    -- would show (estimate), from the next frame (the pages switch on keys
    -- only: B744.createfms.lua)
    local fmsO = fmsModules[fmsID]
    if fmsO then
      fmsO.targetCustomFMC, fmsO.targetPage, fmsO.targetpgNo = true, "LEGSHOLD", 1
      fmsO.inCustomFMC, fmsO.currentPage, fmsO.pgNo = true, "LEGSHOLD", 1
    end
    for k = 2, 13 do lines[k] = BLANK end
    return lines
  end
  local quad = l.radial and (quadrant(l.radial) .. "/" .. string.format("%03d", l.radial == 0 and 360 or l.radial)) or "--/---"
  local dir = (l.turn == "L") and "L" or "R"
  local time = l.time and string.format("%.1f", l.time) or "-.-"
  local dist = l.dist and string.format("%.1f", l.dist) or "--.-"
  lines[2] = BLANK
  lines[3] = lr(l.fix.ident, R.constraint_text(l, trans_alt()) or "---/-----")
  lines[4] = BLANK
  -- (CDU-4) FIX ETA, HOLD AVAIL and BEST SPEED, dashes without them
  local best = best_speed(l)
  lines[5] = lr(quad, fix_eta(i, l) or "----.- ")
  lines[6] = BLANK
  lines[7] = lr(deg(l.crs or 0) .. "/" .. dir .. " TURN", (l.efc or "----") .. " ")
  lines[8] = BLANK
  lines[9] = lr(time, hold_avail(i, l) or "-+--")
  lines[10] = BLANK
  lines[11] = lr(dist, best and string.format("%3d  ", math.floor(best + 0.5)) or "---  ")
  lines[12] = "------------------------"
  lines[13] = lr(B747_fmc_route.mod and "<ERASE" or "<NEXT HOLD", exit_text(i, l))
  return lines
end
fmsPages["RTEHOLD"].getSmallPage=function(self,pgNo,fmsID)
  local n = math.max(1, #R.holds(route()))
  local lines = {string.format("%23s ", pgNo .. "/" .. n)}
  local _, l = hold_of(pgNo)
  if not l then
    for k = 2, 13 do lines[k] = BLANK end
    return lines
  end
  local time = l.time and string.format("%.1f", l.time) or "-.-"
  local dist = l.dist and string.format("%.1f", l.dist) or "--.-"
  lines[2] = lr(FIX_LABEL[l.pt] or " FIX", "SPD/TGT ALT")
  lines[3] = BLANK
  lines[4] = lr(" QUAD/RADIAL", "FIX ETA")
  lines[5] = lr("", "Z")
  lines[6] = lr(" INBD CRS/DIR", "EFC TIME")
  lines[7] = lr("", "Z")
  lines[8] = lr(" LEG TIME", "HOLD AVAIL")
  lines[9] = pad(string.rep(" ", #time) .. " MIN")
  lines[10] = lr(" LEG DIST", "BEST SPEED")
  lines[11] = lr(string.rep(" ", #dist) .. "NM", "KT")
  lines[12] = BLANK
  lines[13] = BLANK
  return lines
end
fmsFunctionsDefs["RTEHOLD"]={}
fmsFunctionsDefs["RTEHOLD"]["L1"]={"holdfix", ""}
fmsFunctionsDefs["RTEHOLD"]["L2"]={"holdquad", ""}
fmsFunctionsDefs["RTEHOLD"]["L3"]={"holdinbd", ""}
fmsFunctionsDefs["RTEHOLD"]["L4"]={"holdtime", ""}
fmsFunctionsDefs["RTEHOLD"]["L5"]={"holddist", ""}
fmsFunctionsDefs["RTEHOLD"]["L6"]={"holdnext", ""}
fmsFunctionsDefs["RTEHOLD"]["R1"]={"holdspd", ""}
fmsFunctionsDefs["RTEHOLD"]["R3"]={"holdefc", ""}
fmsFunctionsDefs["RTEHOLD"]["R6"]={"holdexit", ""}
fmsFunctionsDefs["RTEHOLD"]["exec"]={"rteexec", ""}

-- the page's hold and the scratchpad's entry: nil when there is none (an
-- empty scratchpad copies nothing: estimate)
local function entry_of(fmsO)
  local i = hold_of(fmsO.pgNo)
  local sp = fmsO["scratchpad"]
  if not i or sp == "" then return nil end
  return i, sp
end
-- FIX: not changed here (FMSPG p.159: deleted on the LEGS pages)
function fmsFunctions.holdfix(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY"
end
-- QUAD/RADIAL (FMSPG p.159; FCOM p.1417): NW/330, NW330, /330 or 330; the
-- quadrant from the radial; the inbound course its reciprocal. No DELETE
function fmsFunctions.holdquad(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  local q, rad = sp:match("^([NSEW]?[NSEW]?)/?(%d%d%d)$")
  rad = tonumber(rad)
  if not rad or rad > 360 then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.hold_set(B747_fmc_route, i, {radial = rad}))
end
-- INBD CRS/DIR (FCOM p.1417; FMSPG p.160): XXX, XXX/L or XXXL, /L or L
function fmsFunctions.holdinbd(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  local crs, turn = sp:match("^(%d%d%d)/?([LR]?)$")
  if not crs then turn = sp:match("^/?([LR])$") end
  crs = tonumber(crs)
  if (crs and crs > 360) or not (crs or turn) then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.hold_set(B747_fmc_route, i, {crs = crs, turn = (turn ~= "" and turn) or nil}))
end
-- LEG TIME (FCOM p.1417-1418): XXX.X minutes; LEG DIST dashed
function fmsFunctions.holdtime(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  local m = sp:match("^%d?%d?%d?%.?%d?$") and tonumber(sp)
  if not m or m <= 0 or m >= 1000 then fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.hold_set(B747_fmc_route, i, {time = math.floor(m * 10 + 0.5) / 10}))
end
-- LEG DIST (FCOM p.1418): XX.X or X.X nm; LEG TIME dashed
function fmsFunctions.holddist(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  local d = sp:match("^%d?%d?%.?%d?$") and tonumber(sp)
  if not d or d <= 0 or d >= 100 then fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.hold_set(B747_fmc_route, i, {dist = math.floor(d * 10 + 0.5) / 10}))
end
-- SPD/TGT ALT (FCOM p.1418; FMSPG p.161): the hold's constraint, as on its
-- LEGS line (a speed over an altitude, below the cruise altitude)
function fmsFunctions.holdspd(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  if sp == "DELETE" then
    B747_fmc_route_entry(fmsO, R.delete_constraint(B747_fmc_route, i))
    return
  end
  local c = B747_cdu_parse_constraint(sp)
  if not c then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.set_constraint(B747_fmc_route, i, c, crz_alt()))
end
-- EFC TIME (FCOM p.1419): XXXX, hours and minutes; DELETE dashes
function fmsFunctions.holdefc(fmsO, value)
  local i, sp = entry_of(fmsO)
  if not i then return end
  if sp == "DELETE" then
    B747_fmc_route_entry(fmsO, R.hold_efc(B747_fmc_route, i, nil))
    return
  end
  local h, m = sp:match("^(%d%d)(%d%d)$")
  if not h or tonumber(h) > 23 or tonumber(m) > 59 then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_route_entry(fmsO, R.hold_efc(B747_fmc_route, i, sp))
end
-- 6L: <NEXT HOLD, RTE LEGS HOLD AT for another hold (FCOM p.1418); ERASE
-- on a modification
function fmsFunctions.holdnext(fmsO, value)
  if B747_fmc_route.mod then
    R.erase(B747_fmc_route)
    B747_fmc_route_changed()
    return
  end
  fmsO.targetCustomFMC, fmsO.targetPage, fmsO.targetpgNo = true, "LEGSHOLD", 1
end
-- 6R: EXIT HOLD> (FCOM p.1419): EXIT ARMED, executed by EXEC
function fmsFunctions.holdexit(fmsO, value)
  local i, l = hold_of(fmsO.pgNo)
  if not l or exit_text(i, l) ~= "EXIT HOLD>" then return end
  local err = R.hold_exit(B747_fmc_route, i)
  if err then fmsO["notify"] = err return end
  B747_fmc_route_changed()
end
