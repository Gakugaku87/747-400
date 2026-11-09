-- VNAV LRC Page by Garen Evans, Revised 15 April 2021 2016 UTC
----------------------------------------------------------------------------------------------
--
-- the following datarefs nil if not assigned:
fmsJson = find_dataref("xtlua/fms") -- fmsJSON is nil

-- the following were identifed as redundant dataref calls (April 2021)
----------------------------------------------------------------------------------------------
--simDR_groundspeed = find_dataref("sim/flightmodel/position/groundspeed") --meters per second
--simDR_onGround=find_dataref("sim/flightmodel/failures/onground_any")
--simDR_autopilot_vs_status = find_dataref("sim/cockpit2/autopilot/vvi_status")

-- the following were replaced with simDR_latitude and simDR_longitude
--simDR_lat=find_dataref("sim/flightmodel/position/latitude")
--simDR_lon=find_dataref("sim/flightmodel/position/longitude")

-- the following was replaced by B747DR_airspeed_V2
--simDR_V2 =find_dataref("laminar/B747/airspeed/V2")

-- the following was replaced by simDR_fueL_tank_weight_total_kg
--fob_kg = find_dataref("sim/flightmodel/weight/m_fuel_total") -- fuel weight total, kg
-- ======================================================================================

-- (step 12b2) the CLB or DES page's AT XXXXX waypoint (nil: none) and
-- whether the DES page has an E/D, for the small-font labels
local nxWpt = nil
local edShown = false
local dICAO = "****"

local conv = 1.0 --converter (pounds to kilos)

-- the speeds (6-1/6-2 step 8b; notes/ATA-34-61-FMC.md §45): ECON from the
-- cost index (B747.68.xt.fms.lua's update_econ), SEL SPD by a crew's entry,
-- LRC; <ECON (5L) and LRC> (CRZ 6R) choose (FCOM p.1327-1328, p.1347-1350,
-- p.1391-1392; FMSPG p.112-113, p.131-134, p.192-193)
local function vnav_text(id) return (string.gsub(fmsModules["data"][id], "%s+$", "")) end
-- the CRZ page's STEP TO and its step point (step 8b2; FCOM p.1257,
-- p.1348-1349, FMSPG p.133; also the sim's automatic step climb's: notes/
-- ATA-34-61-FMC.md §126): a crew's STEP TO or the FMC's by the step size,
-- none without an active route and within 200 NM of the T/D (the
-- predictions': step 8c); the optimum step point, where OPT is halfway to
-- STEP TO, AVAIL AT where MAX reaches STEP TO when that comes later.
-- Returns {to (ft) or nil, td (NM) or nil, near_td, avail (AVAIL AT), w
-- (the step point's weight, kg), now (AT NOW: w at least the gross
-- weight)}; the CRZ page passes its own performance data, weight and OPT.
-- (2026-11-05) A planned step: also planned (its waypoint) and nm (the
-- distance to it)
local STEP_NOW_NM = 1
function B747_fms_crz_step(perf, isaDev, gw, optFt)
  perf = perf or B747_fms_perf()
  isaDev = isaDev or B747_fms_isa_dev()
  gw = gw or B747_fms_gw_kg()
  optFt = optFt or B747_perf_db.opt_alt(perf, gw)
  local crz = B747BR_cruiseAlt
  local pred = B747_fms_preds()
  local s = {td = pred and pred.td or nil}
  s.near_td = s.td ~= nil and s.td < 200
  -- (2026-11-05) the crew's planned step climb (RTE LEGS "XXXS": FCOM
  -- p.1332) overrides a STEP TO entry and the FMC's steps (FCOM p.1257):
  -- STEP TO its altitude, the step point its waypoint `nm` along the route
  -- (now: the predictions' S/C comes every 10 s, 1.3 NM at 480 kt), NOW
  -- within STEP_NOW_NM of it and once it is passed (the waypoint just
  -- sequenced: a turn's sequences it early) (estimate)
  if crz > 0 and B747_fmc_route.active and not s.near_td then
    local r = B747_fmc_route.rte
    local lp = r.passed[#r.passed]
    if lp and lp.step and lp.step > crz + 1 then
      s.to, s.planned, s.nm, s.now = lp.step, lp.fix and lp.fix.ident or "", 0, true
      return s
    end
    local from, nm = {lat = simDR_latitude, lon = simDR_longitude}, 0
    for _, l in ipairs(r.legs) do
      if l.fix then
        local _, d = B747_route_model.course(from.lat, from.lon, l.fix.lat, l.fix.lon)
        nm, from = nm + d, l.fix
      end
      if l.step and l.step > crz + 1 then
        s.to, s.planned, s.nm = l.step, l.fix and l.fix.ident or "", nm
        s.now = nm <= STEP_NOW_NM
        return s
      end
    end
  end
  if crz > 0 and B747_fmc_route.active and not s.near_td then
    s.to = B747_cdu_model.parse_alt(vnav_text("stepalt"))
      or B747_crz_model.step_to(crz, optFt, vnav_text("stepsize"), B747_fms_step_east())
  end
  if s.to then
    local light = perf.MAX_ALT_W[#perf.MAX_ALT_W] * 1000 * perf.wf
    local w = B747_crz_model.step_weight(crz, s.to, function(kg) return B747_perf_db.opt_alt(perf, kg) end, light, gw)
    if B747_perf_db.max_alt(perf, w, isaDev) < s.to then
      s.avail = true
      w = math.min(w, B747_perf_db.max_alt_weight(perf, s.to, isaDev))
    end
    s.w, s.now = w, w >= gw
  end
  return s
end
-- a page title centred in the room left of the page number, ACT if active,
-- MOD if modified (step 9d2b: its 6R's modification to execute)
local function vnav_title(text, active, mod)
  local s = (mod and "MOD " or active and "ACT " or "") .. text
  local pad = math.max(0, math.floor((22 - string.len(s)) / 2))
  return string.rep(" ", pad) .. s .. string.rep(" ", math.max(0, 24 - pad - string.len(s)))
end
-- the title's speed: ECON, LRC, or the selected XXXKT, or M.XXX once at it
local function spd_title(mode, cas, mach)
  if mode == "E" then return "ECON" end
  if mode == "L" then return "LRC" end
  if mach and (cas == nil or simDR_mach_pilot >= mach / 1000 - 0.0005) then return string.format("M.%03d", mach) end
  return string.format("%dKT", cas)
end
-- (step 9d3) the active page's title in speed intervention: MCP SPD
-- (ATA34_2 p.557, p.563; FCOM p.1327, p.1347, p.1391)
local function int_title(active, title)
  if active and B747_fms_spd_int() then return "MCP SPD" end
  return title
end
-- (step 9h4a) the engine-out pages (FCOM p.1341-1342, p.1350-1353; FMSPG
-- p.3.3-6, p.3.4-5): the titles start E/O, 2E/O with two engines out
-- (FCOM p.1350); a crew's speed as CAS or Mach and the title's XXXKT or
-- M.XXX; on the active page LIM SPD or MCP SPD for the speed's part
local function eo_base(eo) return B747_eo_model.engines(eo) >= 2 and "2E/O" or "E/O" end
local function eo_sel_text(sel)
  if sel.mach then
    local m = math.floor(sel.mach * 1000 + 0.5)
    return string.format(".%03d", m), string.format(" M.%03d", m)
  end
  return string.format("%3d", sel.cas), string.format(" %dKT", sel.cas)
end
local function eo_spd_title(active, spd)
  if active then
    if B747_fms_vnav_title() == "LIM SPD" then return " LIM SPD" end
    if B747_fms_spd_int() then return " MCP SPD" end
  end
  return spd
end
local function eo_alt_text(ft)
  return B747_cdu_model.format_alt(math.floor(ft / 100) * 100, tonumber(fmsModules["data"]["transalt"]) or 18000)
end
-- ENG OUT> and ALL ENG> (5R); the speed's entry (2L: XXX a CAS 100 to 400,
-- .XXX a Mach .100 to .990, trailing zeros left out; DELETE the E/O climb
-- speed or E/O LRC: FCOM p.1342, p.1353); <E/O SPD (5L) and LRC> (6R) on
-- the E/O CRZ page
function fmsFunctions.eoeng(fmsO, value)
  if value == "out" then B747_fms_eo_eng_out() else B747_fms_eo_all_eng() end
end
function fmsFunctions.eospdmode(fmsO, value)
  B747_fms_eo().crz = value
  B747_fms_preds_now()
end
function fmsFunctions.eospd(fmsO, value)
  local sp = fmsO["scratchpad"]
  local sel = nil
  if sp ~= "DELETE" then
    local m = sp:match("^%.(%d%d?%d?)$")
    local c = sp:match("^(%d%d%d)$")
    local mach = m and tonumber(m) / 10 ^ #m
    if mach and mach >= 0.1 and mach <= 0.99 then
      sel = {mach = mach}
    elseif c and tonumber(c) >= 100 and tonumber(c) <= 400 then
      sel = {cas = tonumber(c)}
    else
      fmsO["notify"] = "INVALID ENTRY"
      return
    end
  end
  local eo = B747_fms_eo()
  if value == "clb" then eo.clb = sel else eo.crz = sel or "LRC" end
  fmsO["scratchpad"] = ""
  B747_fms_preds_now()
end
-- a line of a left and a right part
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - string.len(l) - string.len(r))) .. r end
-- (step 12b2) a waypoint's constraint as the VNAV pages show it: the LEGS
-- pages' (B747_route_model.constraint_text) with the altitude in five
-- places (FCOM p.1327: 250/ 2500; p.1391: 240/ 6000)
local function wpt_text(l, trans)
  local t = B747_route_model.constraint_text(l, trans) or ""
  local spd, alt = t:match("^(.-)/(.*)$")
  if not spd then return t end
  return ((spd .. "/" .. string.format("%5s", alt)):gsub("%s+$", ""))
end
-- the CLB page's ERROR (FCOM p.1327: 350LO 2LONG): the feet low to the
-- nearest 10, the NM long to the nearest one (at least 1; estimates)
local function err_text(w)
  local ft = math.floor(w.err_ft / 10 + 0.5) * 10
  if not w.err_nm then return string.format("%dLO", ft) end
  return string.format("%dLO %dLONG", ft, math.max(1, math.floor(w.err_nm + 0.5)))
end
-- the page active (6-1/6-2 step 9d2a): the FMC's phase (B747.68.xt.fms.lua's
-- B747_fms_vnav_page: 1 CLB, 2 CRZ with the cruise climb and descent, 3
-- DES; before, the AP's old flightPhase), the CRZ page's CRZ CLB or CRZ
-- DES while climbing or descending to a new CRZ ALT (FCOM p.1347)
local function vnav_active(pg)
  local p, chg = B747_fms_vnav_page()
  return p == pg, chg
end
-- (step 9d2b) 6R's CLB DIR>, DES NOW> or DES DIR> (B747_fms_vnav_prompt)
-- and its push (a modification of the active route for EXEC); ERASE at 6L
-- while a modification waits (ATA34_2 p.558, p.564); EXEC on these pages
-- the route's (and DES NOW's early descent: B744.fms.pages.rte.lua)
local function vnav_6r(pg)
  local p = B747_fms_vnav_prompt(pg)
  fmsFunctionsDefs["VNAV"]["R6"] = p and {"vnavdir", (string.gsub(p, ">$", ""))} or nil
  return p or ""
end
local function vnav_6l(other)
  -- (step 9h4a) the engine-out modification too
  if B747_fmc_route.mod or B747_fms_eo().mod then
    fmsFunctionsDefs["VNAV"]["L6"] = {"rteerase", ""}
    return "<ERASE"
  end
  return other
end
function fmsFunctions.vnavdir(fmsO, value)
  B747_fms_vnav_select(value)
end
-- (FMC-08, 2026-11-09) the descent's selected speed segment (FCOM p.1391-
-- 1392; ATA34_2 p.564): the speed a waypoint's constraint or the
-- deceleration into a segment sets (B747_fms_vnav_spd_kt), else the
-- restriction's or the transition's below its altitude, the lower, under
-- the page's own speed own; and whether the airplane is below the
-- restriction's and the transition's altitudes. Nil kt outside one
local function des_segment(own)
  local kt = B747_fms_vnav_spd_kt()
  local rs, ra = tonumber(fmsModules["data"]["desrestspd"]), tonumber(fmsModules["data"]["desrestalt"])
  local ts, ta = tonumber(fmsModules["data"]["destranspd"]), tonumber(fmsModules["data"]["desspdtransalt"])
  local belowR = (rs and ra and simDR_pressureAlt1 < ra) and true or false
  local belowT = (ts and ta and simDR_pressureAlt1 < ta) and true or false
  if not kt then
    if belowR then kt = rs end
    if belowT and (not kt or ts < kt) then kt = ts end
    if kt and own and kt >= own then kt = nil end
  end
  return kt, belowR, belowT
end
-- (2026-11-09) the climb's speed transition above its altitude (FCOM
-- p.1328: not displayed above transition; FMSPG p.3.3-4: blanked upon
-- climbing through it)
local function clb_trans_above()
  local ta = tonumber(fmsModules["data"]["spdtransalt"])
  return ta ~= nil and simDR_pressureAlt1 > ta
end
-- the CRZ page's labels that change: AT, AVAIL AT or TO T/D; EPR or N1
local crzAtLabel, crzThrLabel = "AT", "N1"
function fmsFunctions.vnavspd(fmsO, value)
  if value == "clb" then
    setFMSData("clbspdmode", "E") setFMSData("clbspd", "") setFMSData("clbspdmach", "")
  elseif value == "crz" then
    setFMSData("crzspdmode", "E") setFMSData("crzspd", "") setFMSData("crzcas", "")
  elseif value == "des" then
    setFMSData("desspdmode", "E") setFMSData("desspd", "") setFMSData("desspdmach", "")
  elseif value == "lrc" then
    setFMSData("crzspdmode", "L") setFMSData("crzcas", "")
  end
  -- (step 9h5b) ECON or LRC selected: an active RTA ended (FCOM p.1354:
  -- ECON's execution ends it; at once and for LRC too: estimate)
  if value == "crz" or value == "lrc" then B747_rta_model.terminate(B747_fms_rta()) B747_fms_preds_now() end
  B747_fms_econ_now()
  update_econ()
end

fmsPages["VNAV"]=createPage("VNAV")
-- (step 9d2b) EXEC on the VNAV pages: the modification's
fmsFunctionsDefs["VNAV"]["exec"]={"rteexec", ""}
fmsPages["VNAV"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  

  if simConfigData["data"].SIM.weight_display_units == "LBS" then
    conv = 1.0
  else
    conv = 1 / simConfigData["data"].SIM.kgs_to_lbs
  end
  
    gsKTS = 1.94384 * simDR_groundspeed
    if pgNo==1 then 

      --ref pg 1519 fcomm
      fmsFunctionsDefs["VNAV"]["L1"]={"setdata","crzalt"}
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","clbspd"}
      fmsFunctionsDefs["VNAV"]["L3"]={"setdata","clbtrans"}
      fmsFunctionsDefs["VNAV"]["L4"]={"setdata","clbrest"}
      fmsFunctionsDefs["VNAV"]["L5"]=fmsModules["data"]["clbspdmode"]=="S" and {"vnavspd","clb"} or nil
      fmsFunctionsDefs["VNAV"]["L6"]=nil
      fmsFunctionsDefs["VNAV"]["R1"]=nil
      fmsFunctionsDefs["VNAV"]["R3"]={"setdata","transalt"}
      fmsFunctionsDefs["VNAV"]["R5"]=nil
      fmsFunctionsDefs["VNAV"]["R6"]=nil

      -- (step 12b2) the next speed or altitude constraint before the T/C
      -- (AT XXXXX: FCOM p.1328) and its ERROR (p.1329) from the active route
      -- and the predictions (B747_fms_vnav_wpts; before, X-Plane's FMS legs
      -- and their altitudes: FL001 at a point without a constraint)
      local w = B747_fms_vnav_wpts().clb
      spdalt, error_line, nxWpt = "", "", nil
      if w then
        spdalt = wpt_text(w.leg, tonumber(fmsModules["data"]["transalt"]) or 18000)
        nxWpt = w.name
        if w.err_ft then error_line = err_text(w) end
      end

      -- MAX ANGLE: the minimum drag speed at the weight and altitude (the
      -- cruise model, 6-1/6-2 step 8b: an estimate; before, V2 + 80 or 100)
      local _, maxAngle = B747_perf_db.min_drag(B747_fms_perf(), B747_fms_gw_kg(), math.max(0, simDR_pressureAlt1))
      VxSpeed = string.format("%3d", math.floor(maxAngle + 0.5))

      -- the title: the speed restriction's or transition's below their
      -- altitudes while active (FMSPG p.112: ACT 250KT CLB), else ECON or
      -- the selected speed
      local mode = vnav_text("clbspdmode")
      local cas, mach = tonumber(fmsModules["data"]["clbspd"]), tonumber(fmsModules["data"]["clbspdmach"])
      local active = vnav_active(1)
      local title = spd_title(mode, cas, mach)
      local restSpd, restAlt = tonumber(fmsModules["data"]["clbrestspd"]), tonumber(fmsModules["data"]["clbrestalt"])
      local transSpd, transAlt = tonumber(fmsModules["data"]["transpd"]), tonumber(fmsModules["data"]["spdtransalt"])
      if active and restSpd and restAlt and simDR_pressureAlt1 < restAlt then
        title = string.format("%dKT", restSpd)
      elseif active and transSpd and transAlt and simDR_pressureAlt1 < transAlt then
        title = string.format("%dKT", transSpd)
      end
      -- (FMC-08) a climb waypoint's speed constraint setting the target
      -- (FMSPG p.3.3-3: XXXKT for a fixed speed; p.3.3-2: ACT 250KT CLB, or
      -- any speed restriction's)
      local wkt = active and B747_fms_vnav_spd_kt()
      if wkt then title = string.format("%dKT", math.floor(wkt + 0.5)) end
      -- (step 9h3b) the engine-out takeoff's VREF + 100 (FCOM p.1265);
      -- LIM SPD while the flap placard or the minimum speed limits the
      -- target, over MCP SPD (FCOM p.1265's note; FMSPG p.3.3-3, p.3.4-19)
      local fmcTitle = active and B747_fms_vnav_title() or nil
      if fmcTitle == "VREF + 100" then title = fmcTitle end
      title = int_title(active, title)
      if fmcTitle == "LIM SPD" then title = fmcTitle end
      -- ECON SPD or SEL SPD: CAS/Mach (FMSPG p.113: 358/.853), a selected
      -- CAS alone without the Mach
      local spdText = vnav_text("clbspd")
      local machText = vnav_text("clbspdmach")
      if machText == "" and mode ~= "S" then machText = vnav_text("crzspd") end
      if machText ~= "" then spdText = spdText .. "/." .. machText end
      -- (step 9h4a) the engine-out data (ENG OUT's modification or active:
      -- FCOM p.1341-1342; FMSPG p.3.3-4, p.3.3-6): CRZ ALT at most MAX ALT,
      -- E/O SPD (the minimum drag speed, or the crew's), MAX ALT (the lower
      -- at the E/O climb and cruise speeds), ALL ENG>; no SPD TRANS, SPD
      -- REST nor MAX ANGLE
      local eo = B747_fms_eo()
      if B747_eo_model.shown(eo) then
        fmsFunctionsDefs["VNAV"]["L2"]={"eospd","clb"}
        fmsFunctionsDefs["VNAV"]["L3"]=nil
        fmsFunctionsDefs["VNAV"]["L4"]=nil
        fmsFunctionsDefs["VNAV"]["L5"]=nil
        fmsFunctionsDefs["VNAV"]["R5"]={"eoeng","all"}
        local maxFt = B747_fms_eo_max("CLB")
        local crzText = fmsModules["data"]["crzalt"]
        if B747BR_cruiseAlt > maxFt then crzText = eo_alt_text(maxFt) end
        local eoSpd, spdPart = string.format("%3d", math.floor(B747_fms_eo_min_drag() + 0.5)), ""
        if eo.clb then eoSpd, spdPart = eo_sel_text(eo.clb) end
        local eoActive = active and eo.active and eo.mod == nil
        return{
          vnav_title(eo_base(eo) .. eo_spd_title(eoActive, spdPart) .. " CLB", eoActive,
            eo.mod == "ENG OUT" or B747_fms_vnav_mod() == "CLB DIR"),
          "                        ",
          lr(crzText, spdalt),
          "                        ",
          lr(eoSpd, (string.gsub(error_line, "%s+$", ""))),
          "                        ",
          lr("", fmsModules["data"]["transalt"]),
          "                        ",
          lr("", string.format("FL%03d", math.floor(maxFt / 100))),
          "------------------------",
          lr("", "ALL ENG>"),
          "                        ",
          lr(vnav_6l(""), vnav_6r(1))
        }
      end
      fmsFunctionsDefs["VNAV"]["R5"]={"eoeng","out"}
      return{
        vnav_title(title .. " CLB", active, B747_fms_vnav_mod() == "CLB DIR" or eo.mod == "ALL ENG"),
      "                        ",
      lr(fmsModules["data"]["crzalt"], spdalt),
      "                        ",
      lr(spdText, (string.gsub(error_line, "%s+$", ""))),
                                        --**** LO  ** LONG
      "                        ",
      -- (2026-11-09) SPD TRANS not displayed above its altitude (FCOM
      -- p.1328; FMSPG p.3.3-4), TRANS ALT kept. Before, at every altitude
      lr(clb_trans_above() and "" or (fmsModules["data"]["transpd"].."/"..fmsModules["data"]["spdtransalt"]),
        fmsModules["data"]["transalt"]),
      "                        ",
      lr(fmsModules["data"]["clbrestspd"].."/"..fmsModules["data"]["clbrestalt"], VxSpeed),
      "------------------------",
      lr(mode=="S" and "<ECON" or "", "ENG OUT>"),
      "                        ",
      lr(vnav_6l(""), vnav_6r(1))
      }
    elseif pgNo==2 then 
      --ref pg 1543 fcomm
      fmsFunctionsDefs["VNAV"]["L1"]={"setdata","crzalt"}
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","crzspd"}
      fmsFunctionsDefs["VNAV"]["L3"]=nil
      fmsFunctionsDefs["VNAV"]["L4"]={"setdata","stepsize"}
      -- (step 9h5b) an active RTA's speed (FCOM p.1354): <ECON too
      local rtaMach = B747_fms_rta_mach()
      fmsFunctionsDefs["VNAV"]["L5"]=(fmsModules["data"]["crzspdmode"]~="E" or rtaMach) and {"vnavspd","crz"} or nil
      -- (step 9h5a) <RTA PROGRESS: PROGRESS 3/3, the 109's (FCOM p.1354,
      -- p.1383; before, PROGRESS 1/3); none on the 570
      fmsFunctionsDefs["VNAV"]["L6"]=B747DR_fms_engine_type ~= 1 and {"setpage_no","PROGRESS_3"} or nil
      fmsFunctionsDefs["VNAV"]["R1"]={"setdata","stepalt"}
      fmsFunctionsDefs["VNAV"]["R3"]=nil
      fmsFunctionsDefs["VNAV"]["R5"]=nil
      fmsFunctionsDefs["VNAV"]["R6"]=fmsModules["data"]["crzspdmode"]~="L" and {"vnavspd","lrc"} or nil

      -- OPT and MAX: the FCOM PI tables at the FMC's weight (6-1/6-2 steps
      -- 8a, 8b2: notes/ATA-34-61-FMC.md §44, §46; before, lines fitted to FCOM
      -- p.1576). OPT is the long range cruise's least fuel in every speed
      -- mode (ECON's least cost by the cost index: not made)
      local perf = B747_fms_perf()
      local isaDev = B747_fms_isa_dev()
      local gw = B747_fms_gw_kg()
      local optFt = B747_perf_db.opt_alt(perf, gw)
      local maxFt = math.min(B747_perf_db.max_alt(perf, gw, isaDev), 45100)
      local optmax = string.format("FL%03.0f  FL%03.0f", optFt / 100, maxFt / 100)

      -- STEP TO and AT (step 8b2; FCOM p.1257, p.1348-1349, FMSPG p.133): a
      -- crew's STEP TO or the FMC's by the step size, blank without an
      -- active route and within 200 NM of the T/D (the predictions': step
      -- 8c), where AT is TO T/D
      local crz = B747BR_cruiseAlt
      local mode = vnav_text("crzspdmode")
      local cas, mach = tonumber(fmsModules["data"]["crzcas"]), tonumber(fmsModules["data"]["crzspd"])
      local cmdMach = (cas and crz > 0) and B747_perf_db.cas_to_mach(cas, crz) or (mach or 810) / 1000
      if rtaMach then cmdMach = rtaMach end
      local pred = B747_fms_preds()
      local step = B747_fms_crz_step(perf, isaDev, gw, optFt)
      local tdNM, nearTD, stepTo = step.td, step.near_td, step.to
      local atText = ""
      crzAtLabel = "AT"
      local function eta_text(hours, nm)
        local _, h, m = get_ETA_for_Distance(0, hours * 3600)
        return string.format("%02d%02dz/%4dNM", h, m, math.floor(nm + 0.5))
      end
      if nearTD then
        crzAtLabel = "TO T/D"
        atText = eta_text(tdNM / math.max(gsKTS, 100), tdNM)
      elseif stepTo then
        if step.avail then crzAtLabel = "AVAIL AT" end
        if step.now then
          atText = "NOW"
        elseif step.planned then
          -- (2026-11-05) a planned step: the time and distance to its point
          atText = step.nm and eta_text(step.nm / math.max(gsKTS, 100), step.nm) or ""
        else
          -- the fuel down to it at the cruise model's flow at the mean weight
          local w = step.w
          local hrs = (gw - w) / (4 * B747_perf_db.cruise_ff(perf, (gw + w) / 2, crz, cmdMach, isaDev))
          atText = eta_text(hrs, hrs * (B747_perf_db.tas(cmdMach, crz, isaDev) - B747_fms_crz_headwind()))
        end
      end
      -- EPR (PW, RR) or N1 (GE) for level flight at the command speed at CRZ
      -- ALT on the active page (FCOM p.1348, FMSPG p.132; the cruise model:
      -- an estimate; before, N1 from the weight alone for every engine)
      local thrText = ""
      crzThrLabel = perf.N1 and "N1" or "EPR"
      local crzActive, crzChg = vnav_active(2)
      if crzActive and crz > 0 then
        local v = B747_perf_db.level_setting(perf, gw, crz, cmdMach, isaDev)
        thrText = perf.N1 and string.format("%.1f%%", v) or string.format("%.2f", v)
      end

      -- the destination's ETA and fuel: the predictions' (step 8c; FCOM
      -- p.1349: with the step climbs; before, rules of thumb such as 51.6 lb a
      -- NM); blank without them
      local etafuel = ""
      if pred then
        local _, eh, em = get_ETA_for_Distance(0, pred.dest.t)
        -- the fuel blank with CRZ ALT at or above MAX (ATA34_2 p.611;
        -- 2026-11-05 review 4)
        local f = pred.no_fuel and "" or string.format("%.1f", perf_out(pred.dest.fuel / 1000))
        etafuel = string.format("%02d%02dz/%s", eh, em, f)
      end
      dICAO = (B747_fmc_route.rte.dest and B747_fmc_route.rte.dest.ident) or "****"
      -- ECON, LRC or SEL SPD: a Mach, or a selected CAS; (step 9h5b) RTA
      -- SPD's Mach
      local spdText = cas and string.format("%3d", cas) or "." .. vnav_text("crzspd")
      if rtaMach then spdText = string.format(".%03d", math.floor(rtaMach * 1000 + 0.5)) end
      -- (step 9h4a) the engine-out data (FCOM p.1350-1353; FMSPG p.3.4-5):
      -- CRZ ALT at most MAX (so shown in the modification), LRC SPD (E/O LRC
      -- at CRZ ALT), E/O SPD (the minimum drag) or SEL SPD; the title E/O
      -- LRC D/D above MAX, E/O CRZ CLB or DES, else the speed's (E/O LRC,
      -- E/O, E/O XXXKT or M.XXX) CRZ; the thrust setting, OPT (estimate)
      -- and MAX the engine-out ones; STEP TO up to MAX; <E/O SPD, ALL
      -- ENG>, LRC>; AT the driftdown's level off (step 9h4b) or TO T/D
      local eo = B747_fms_eo()
      if B747_eo_model.shown(eo) then
        fmsFunctionsDefs["VNAV"]["L2"]={"eospd","crz"}
        fmsFunctionsDefs["VNAV"]["L5"]=eo.crz ~= "EO" and {"eospdmode","EO"} or nil
        fmsFunctionsDefs["VNAV"]["R5"]={"eoeng","all"}
        fmsFunctionsDefs["VNAV"]["R6"]=eo.crz ~= "LRC" and {"eospdmode","LRC"} or nil
        local maxFt = B747_fms_eo_crz_max()
        local crzFt = (crz > maxFt and eo.mod == "ENG OUT") and math.floor(maxFt / 100) * 100 or crz
        local crzText = crzFt == crz and fmsModules["data"]["crzalt"] or eo_alt_text(crzFt)
        local eoSpd, spdPart, eoMach
        if eo.crz == "LRC" then
          eoMach = B747_fms_eo_lrc(crzFt)
          eoSpd, spdPart = string.format(".%03d", math.floor(eoMach * 1000 + 0.5)), " LRC"
        elseif eo.crz == "EO" then
          local v = B747_fms_eo_min_drag()
          eoSpd, spdPart = string.format("%3d", math.floor(v + 0.5)), ""
          eoMach = B747_perf_db.cas_to_mach(v, crzFt)
        else
          eoSpd, spdPart = eo_sel_text(eo.crz)
          eoMach = eo.crz.mach or B747_perf_db.cas_to_mach(eo.crz.cas, crzFt)
        end
        local eoActive = crzActive and eo.active and eo.mod == nil
        local title
        -- (step 9h4b) D/D also while VNAV's driftdown goes on (the maximum
        -- grown over the airplane as the fuel burns)
        if eo.crz == "LRC" and (simDR_pressureAlt1 > maxFt + 200 or B747_fms_vnav_dd()) then
          title = eo_base(eo) .. " LRC D/D"
        elseif crzChg then
          title = eo_base(eo) .. " CRZ " .. crzChg
        else
          title = eo_base(eo) .. eo_spd_title(eoActive, spdPart) .. " CRZ"
        end
        local eoThr = ""
        if eoActive and crzFt > 0 then
          local v = B747_fms_eo_setting(crzFt, eoMach)
          eoThr = perf.N1 and string.format("%.1f%%", v) or string.format("%.2f", v)
        end
        local optFt = B747_fms_eo_opt()
        local eoStep = nil
        if crzFt > 0 and B747_fmc_route.active and not nearTD then
          eoStep = B747_cdu_model.parse_alt(vnav_text("stepalt"))
            or B747_crz_model.step_to(crzFt, optFt, vnav_text("stepsize"), B747_fms_step_east())
          if eoStep and eoStep > maxFt then eoStep = nil end
        end
        -- (step 9h4b) AT: in the driftdown the predictions' level off at CRZ
        -- ALT (FCOM p.1268, p.1353), else TO T/D near it
        local ddAt = (eoActive and pred and pred.lvl_dd and B747_fms_vnav_dd()) and eta_text(pred.lvl_t / 3600, pred.lvl) or nil
        crzAtLabel = ddAt and "AT" or nearTD and "TO T/D" or ""
        return{
          vnav_title(title, eoActive, eo.mod == "ENG OUT"),
          "                        ",
          lr(crzText, eoStep and string.format("FL%03d", math.floor(eoStep / 100 + 0.5)) or ""),
          "                        ",
          lr(eoSpd, ddAt or (nearTD and atText) or ""),
          "                        ",
          lr(eoThr, etafuel),
          "                        ",
          string.format("%-12s", vnav_text("stepsize")) .. string.format("FL%03.0f  FL%03.0f", optFt / 100, maxFt / 100),
          "------------------------",
          lr(eo.crz ~= "EO" and "<E/O SPD" or "", "ALL ENG>"),
          "                        ",
          lr(vnav_6l(B747DR_fms_engine_type ~= 1 and "<RTA PROGRESS" or ""), eo.crz ~= "LRC" and "LRC>" or "")
        }
      end
      fmsFunctionsDefs["VNAV"]["R5"]={"eoeng","out"}
      return{
        vnav_title(int_title(crzActive, rtaMach and "RTA" or spd_title(mode, cas, (not cas) and mach or nil)) .. " CRZ" .. (crzChg and " " .. crzChg or ""), crzActive,
          eo.mod == "ALL ENG"),
      "                        ",
      lr(fmsModules["data"]["crzalt"], stepTo and string.format("FL%03d", math.floor(stepTo / 100 + 0.5)) or ""),
      "                        ",
      lr(spdText, atText),
      "                        ",
      lr(thrText, etafuel),
      "                        ",
      string.format("%-12s", vnav_text("stepsize"))..optmax,
      "------------------------",
      lr((mode~="E" or rtaMach) and "<ECON" or "", "ENG OUT>"),
      "                        ",
      lr(vnav_6l(B747DR_fms_engine_type ~= 1 and "<RTA PROGRESS" or ""), mode~="L" and "LRC>" or "")
      }
    elseif pgNo==3 then 
      --ref FCOM Virgin p.1023, Lease p.822
      fmsFunctionsDefs["VNAV"]["L1"]=nil
      fmsFunctionsDefs["VNAV"]["L2"]={"setdata","desspds"}
      fmsFunctionsDefs["VNAV"]["L3"]={"setdata","destrans"}
      fmsFunctionsDefs["VNAV"]["L4"]={"setdata","desrest"}
      fmsFunctionsDefs["VNAV"]["L5"]=fmsModules["data"]["desspdmode"]=="S" and {"vnavspd","des"} or nil
      -- (2026-11-04) <OFFPATH DES: the OFFPATH DES page (FCOM p.1398;
      -- before, the prompt's text without a page); <ERASE over it with a
      -- modification (vnav_6l)
      fmsFunctionsDefs["VNAV"]["L6"]={"setpage","OFFPATH"}
      fmsFunctionsDefs["VNAV"]["R1"]=nil
      fmsFunctionsDefs["VNAV"]["R3"]=nil
      -- FORECAST> (FCOM p.1393; step 8e2): the DESCENT FORECAST page
      fmsFunctionsDefs["VNAV"]["R5"]={"setpage","DESFORECAST"}
      fmsFunctionsDefs["VNAV"]["R6"]=nil

      if B747DR_ap_vnav_state==2 and simDR_autopilot_vs_status==2 then
	      fmsModules["data"]["fpa"]=string.format("%1.1f",B747DR_ap_fpa)
	      fmsModules["data"]["vb"]=string.format("%1.1f", B747DR_ap_vb)
	      fmsModules["data"]["vs"]=string.format("%4d",simDR_autopilot_vs_fpm*-1) 
      else
	      fmsModules["data"]["fpa"]="*.*"
	      fmsModules["data"]["vb"]="*.*"
	      fmsModules["data"]["vs"]="****"
      end

      -- (step 12b2) E/D AT, the E/D's altitude and waypoint, and AT XXXXX,
      -- the next constraint after the T/D (FCOM p.1392), from the active route
      -- and the predictions (B747_fms_vnav_wpts; before, X-Plane's FMS legs
      -- and the old AP's E/D: boxes without them); blank without them
      local wp = B747_fms_vnav_wpts()
      local edText, atText = "", ""
      nxWpt, edShown = nil, wp.ed ~= nil
      if wp.ed then
        edText = B747_cdu_model.format_alt(wp.ed.alt, B747_fms_trans_lvl()) .. " " .. wp.ed.name
      end
      if wp.des then
        atText = wpt_text(wp.des.leg, B747_fms_trans_lvl())
        nxWpt = wp.des.name
      end
      local mode = vnav_text("desspdmode")
      -- (step 9e2) END OF DES past the E/D (FCOM p.1391)
      local desActive = (vnav_active(3))
      local own = tonumber(fmsModules["data"]["desspd"])
      local dspd = spd_title(mode, own, tonumber(fmsModules["data"]["desspdmach"]))
      -- (FMC-08) the active descent's fixed speeds (FCOM p.1391: XXXKT for a
      -- speed transition, a speed restriction and waypoint speed
      -- constraints): the target's where a waypoint's constraint or the
      -- deceleration into a speed segment sets it (the deceleration's: an
      -- estimate from p.1392's SEL SPD transitioning into a selected speed
      -- segment), else the restriction's
      -- or the transition's below their altitudes, the lower, under the
      -- page's own speed; LIM SPD (p.1391) over MCP SPD as on the CLB page.
      -- Before, ECON (or the selected speed's) at every altitude.
      -- (2026-11-09) In that segment 2L SEL SPD with its speed, 3L SPD TRANS
      -- blank below its altitude, 4L SPD RESTR dashes below its (FCOM
      -- p.1392; ATA34_2 p.564: the segment's speed moves to 2L, the line
      -- blank or dashes; FMSPG p.3.5-3 the same for 3L and 4L, its 2L the
      -- speed above them all: the FCOM's taken). Before, 2L the page's own
      -- speed, 3L and 4L kept
      local kt, belowR, belowT = nil, false, false
      if desActive then
        kt, belowR, belowT = des_segment(own)
        if kt then dspd = string.format("%dKT", math.floor(kt + 0.5)) end
      end
      local spd2 = ".".. fmsModules["data"]["desspdmach"].."/"..fmsModules["data"]["desspd"]
      if kt then spd2 = string.format("%3d", math.floor(kt + 0.5)) end
      local tr3 = belowT and "" or (fmsModules["data"]["destranspd"].."/"..fmsModules["data"]["desspdtransalt"])
      local rs4 = belowR and "---/-----" or (fmsModules["data"]["desrestspd"].."/"..fmsModules["data"]["desrestalt"])
      dspd = int_title(desActive, dspd)
      if desActive and B747_fms_vnav_title() == "LIM SPD" then dspd = "LIM SPD" end
      local desTitle = (desActive and B747_fms_end_des()) and "END OF DES" or dspd .. " DES"
      return{
        vnav_title(desTitle, desActive, B747_fms_vnav_mod() == "DES NOW" or B747_fms_vnav_mod() == "DES DIR"),
      "                        ",
      --"  **** *****    ***/****",
      lr(edText, atText),
      "                        ",
      string.format("%-24s", spd2),
      "                        ",
      string.format("%-24s", tr3),
      "                        ",
      rs4.."   "..fmsModules["data"]["fpa"].." "..fmsModules["data"]["vb"].." "..fmsModules["data"]["vs"],
      "------------------------",
      lr(mode=="S" and "<ECON" or "", "FORECAST>"),
      "                        ",
      lr(vnav_6l("<OFFPATH DES"), vnav_6r(3))
      

      }
    end
end

-- the speed line's label by its mode
local function spd_label(id)
  local mode = vnav_text(id)
  return mode == "S" and " SEL SPD " or mode == "L" and " LRC SPD " or " ECON SPD"
end

fmsPages["VNAV"].getSmallPage=function(self,pgNo,fmsID)
    -- (step 9h4a) the engine-out pages' labels (FCOM p.1341, p.1351-1352)
    local eo = B747_fms_eo()
    local eoShown = B747_eo_model.shown(eo)
    if pgNo==1 and eoShown then
      return{
      "                    1/3 ",
      lr(" CRZ ALT", nxWpt and ("AT " .. nxWpt) or ""),
      "                        ",
      lr(" E/O SPD", error_line ~= "" and "ERROR" or ""),
      "                        ",
      "               TRANS ALT",
      "                        ",
      "                 MAX ALT",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        "
      }
    elseif pgNo==2 and eoShown then
      local lbl = eo.crz == "LRC" and " LRC SPD" or eo.crz == "EO" and " E/O SPD" or " SEL SPD"
      return{
      "                    2/3 ",
      " CRZ ALT         STEP TO",
      "                        ",
      lr(lbl, crzAtLabel ~= "" and crzAtLabel or " "),
      "                        ",
      string.format(" %-10s", crzThrLabel)..dICAO.." ETA/FUEL",
      "                        ",
      " STEP SIZE  OPT      MAX",
      "                        ",
      "                        ",
      "                        ",
      "                        ",
      "                        "
      }
    end
    if pgNo==1 then

      return{
      "                    1/3 ",
      lr(" CRZ ALT", nxWpt and ("AT " .. nxWpt) or ""),
      "                        ",
      lr(spd_label("clbspdmode"), error_line ~= "" and "ERROR" or ""),
      "                        ",
      " SPD TRANS     TRANS ALT",
      "                        ",
      " SPD REST      MAX ANGLE",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    elseif pgNo==2 then 

      return{
      "                    2/3 ",
      " CRZ ALT         STEP TO",
      "                        ",
      lr(B747_fms_rta_mach() and " RTA SPD " or spd_label("crzspdmode"), crzAtLabel),
      "                        ",
      string.format(" %-10s", crzThrLabel)..dICAO.." ETA/FUEL",  
      "                        ",
      " STEP SIZE  OPT      MAX",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    elseif pgNo==3 then
      -- (2026-11-09) SEL SPD in the active descent's selected speed segment
      -- (FCOM p.1392; ATA34_2 p.564: as the large page's 2L)
      local dLbl = spd_label("desspdmode")
      if vnav_active(3) and des_segment(tonumber(fmsModules["data"]["desspd"])) then dLbl = " SEL SPD " end
      return{
      "                    3/3 ",
      lr(edShown and " E/D AT" or "", nxWpt and ("AT " .. nxWpt) or ""),
      "                        ",
      dLbl .. "               ",
      "                        ",
      " SPD TRANS              ",
      "                        ",
      " SPD REST   FPA V/B  V/S",
      "                        ",
      "                        ",
      "                        ", 
      "                        ",
      "                        "
      }
    end
end

fmsPages["VNAV"].getNumPages=function(self)
  return 3
end


function getDistance(lat1,lon1,lat2,lon2)
  if lat1==lat2 and lon1==lon2 then return 0 end
  alat=math.rad(lat1)
  alon=math.rad(lon1)
  blat=math.rad(lat2)
  blon=math.rad(lon2)
  av=math.sin(alat)*math.sin(blat) + math.cos(alat)*math.cos(blat)*math.cos(blon-alon)
  if av > 1 then av=1 end
  retVal=math.acos(av) * 3440
  return retVal
end

-- http://lua-users.org/wiki/StringTrim
function trim1(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
