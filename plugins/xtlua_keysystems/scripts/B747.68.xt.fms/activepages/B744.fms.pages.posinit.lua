fmsPages["POSINIT"]=createPage("POSINIT")
-- (6-1/6-2 step 10a) POS REF 2/3 and 3/3 (FCOM p.1367-1370; FMSPG p.74-76;
-- ATA34_2 p.517; before, fixed text): B747.68.navperf_model.lua's source,
-- ANP and RNP through B747.68.xt.fms.lua (B747_fms_navperf).
--  2/3: 1L FMC POS (its source in the title; the mixed IRS position while
--  CONFIRM shows) and GS, 2L IRS(X) (B747_fms_irs_pos), 3L RNP/ACTUAL (the
--  default small, an entry large; the IRS's ACTUAL while CONFIRM shows),
--  3R DME-DME, VOR-DME or NAV STA, 5L <PURGE and <CONFIRM, 5R GPS NAV
--  INHIBIT> and ENABLE>, 6R BRG/DIST> and LAT/LON> (the IRS line as the
--  bearing and distance from the FMC position: 150`/3.7, FCOM p.1244).
--  3/3: IRS L, C, R and GPS L, R (blank when invalid, GPS also when
--  inhibited), in either format.
-- Estimates: the FMC position X-Plane's (the model's), the GPSs' too;
-- the bearings magnetic (the FMC's variation); NM small after the
-- distance; PURGE in the title's place of the dashes while CONFIRM shows,
-- FMC POS without its source then.
local function pp_lr(l, r) return l .. string.rep(" ", math.max(1, 24 - string.len(l) - string.len(r))) .. r end
local function pp_kt(gs) return string.format("%3d", math.floor(gs + 0.5)) end
-- a position's large and small lines: KT small after the ground speed;
-- with brg the bearing and distance from the FMC position, NM small
local function pp_line(lat, lon, gs, brg)
  local left, small = toDMS(lat, true) .. " " .. toDMS(lon, false), ""
  if brg then
    local c, d = B747_route_model.course(simDR_latitude, simDR_longitude, lat, lon)
    local var = B747_navdb.variation(B747_fmc_navdb, simDR_latitude, simDR_longitude)
    if var == nil then var = -simDR_variation end
    local b = d < 0.05 and 0 or math.floor((c - var) % 360 + 0.5) % 360
    left = string.format("%03d`/%.1f", b, d)
    small = string.rep(" ", string.len(left)) .. "NM"
  end
  return pp_lr(left, pp_kt(gs) .. "  "), pp_lr(small, "KT")
end
local function pos_ref(pgNo, small)
  local NP, s = B747_navperf_model, B747_fms_navperf()
  local out = s.out
  local L, S = {}, {}
  for i = 1, 13 do L[i], S[i] = string.rep(" ", 24), string.rep(" ", 24) end
  L[1] = "        POS REF         "
  S[1] = string.format("                    %d/3 ", pgNo)
  local ilat, ilon, igs, irs = B747_fms_irs_pos()
  local gs = simDR_groundspeed * 1.943844
  local defs = fmsFunctionsDefs["POSINIT"]
  if pgNo == 2 then
    local title = (s.purge or (out.title or "") == "") and " FMC POS" or (" FMC POS (" .. out.title .. ")")
    S[2] = pp_lr(title, "GS")
    if s.purge and ilat then
      L[3], S[3] = pp_line(ilat, ilon, igs, false)
    elseif s.anp then
      L[3], S[3] = pp_line(simDR_latitude, simDR_longitude, gs, false)
    end
    if irs then
      S[4] = pp_lr(" IRS(" .. irs .. ")", "")
      L[5], S[5] = pp_line(ilat, ilon, igs, s.brg)
    end
    S[6] = pp_lr(" RNP/ACTUAL", out.sta_title or "NAV STA")
    local rnp = NP.text(NP.rnp(s))
    local anp = s.purge and s.irs_anp or s.anp
    local a = anp and ("/" .. NP.text(anp)) or ""
    local man = s.rnp_man ~= nil
    L[7] = pp_lr((man and rnp or string.rep(" ", string.len(rnp))) .. a, out.sta or "")
    S[7] = pp_lr((man and string.rep(" ", string.len(rnp)) or rnp) .. string.rep(" ", string.len(a)) .. (anp and "NM" or ""), "")
    S[10] = s.purge and pp_lr("PURGE", "GPS NAV") or "---------------- GPS NAV"
    L[11] = pp_lr(s.purge and "<CONFIRM" or "<PURGE", s.gps_inhibit and "ENABLE>" or "INHIBIT>")
    if not small then
      defs["L1"], defs["L2"], defs["L3"], defs["L4"], defs["L5"] = nil, nil, {"posref", "rnp"}, nil, {"posref", "purge"}
      defs["R1"], defs["R2"], defs["R3"], defs["R4"], defs["R5"] = nil, nil, nil, nil, {"posref", "gpsnav"}
    end
  else
    local valid = B747DR_nav_irs_nav_valid
    for n, name in ipairs({"L", "C", "R"}) do
      S[2 * n] = pp_lr(" IRS " .. name, n == 1 and "GS" or "")
      if valid[n - 1] == 1 then
        L[2 * n + 1], S[2 * n + 1] = pp_line(B747DR_nav_irs_lat[n - 1], B747DR_nav_irs_lon[n - 1], B747DR_nav_irs_gs[n - 1], s.brg)
      end
    end
    for n, name in ipairs({"L", "R"}) do
      S[6 + 2 * n] = pp_lr(" GPS " .. name, "")
      if B747DR_nav_gps_valid[n - 1] == 1 and not s.gps_inhibit then
        L[7 + 2 * n], S[7 + 2 * n] = pp_line(simDR_latitude, simDR_longitude, gs, s.brg)
      end
    end
    S[12] = "------------------------"
    if not small then
      for k = 1, 5 do defs["L" .. k], defs["R" .. k] = nil, nil end
    end
  end
  L[13] = pp_lr("<INDEX", s.brg and "LAT/LON>" or "BRG/DIST>")
  if not small then defs["R6"] = {"posref", "brg"} end
  return small and S or L
end

fmsPages["POSINIT"].getPage=function(self,pgNo,fmsID)
  if pgNo==1 then

	--Marauder28
	--Load last aircraft position (for this livery)
	aircraft_last_pos("LOAD")

    fmsFunctionsDefs["POSINIT"]["R1"]={"getdata","lastpos"}
    
    fmsFunctionsDefs["POSINIT"]["R4"]={"getdata","gpspos"}
    if irsSystem.aligning() then
      fmsFunctionsDefs["POSINIT"]["R5"]={"setdata","irspos"}
      fmsFunctionsDefs["POSINIT"]["L2"]={"setdata","airportpos"}
      fmsFunctionsDefs["POSINIT"]["L3"]={"setdata","airportgate"}
    else
      fmsFunctionsDefs["POSINIT"]["L2"]=nil
      fmsFunctionsDefs["POSINIT"]["L3"]=nil
      fmsFunctionsDefs["POSINIT"]["R5"]=nil
    end
	if fmsModules["data"].sethdg == "---`" then
		fmsFunctionsDefs["POSINIT"]["L5"]={"setdata","sethdg"}
	else
		fmsFunctionsDefs["POSINIT"]["L5"]=nil
	end
    fmsFunctionsDefs["POSINIT"]["R6"]={"rtepage",""}
    return {
    "      POS INIT       1/3",
    "                        ",
    "     "..fmsModules["data"].lastpos,
    "                        ",
    fmsModules["data"]["airportpos"].." "..fmsModules["data"].irsLat.." "..fmsModules["data"].irsLon,
    "                        ",
    fmsModules["data"]["airportgate"].."                  ",
    "                        ",
    string.format("%02d%02dz ",hh,mm).. irsSystem.gpsPos(),
    "                        ",
    fmsModules["data"].sethdg.." ".. irsSystem.getInitLatPos().." ".. irsSystem.getInitLonPos(), 
    "                         ",
    "<INDEX            ROUTE>"
    } 
  else
    return pos_ref(pgNo,false)
  end
end
fmsPages["POSINIT"].getSmallPage=function(self,pgNo,fmsID)
  if pgNo==1 then
    -- SET HDG with an IRU in ATT, SET IRS POS with an IRU aligning (FCOM p.1286)
    local setIRS=(B747DR_nav_irs_set_hdg_shown==1 and "SET HDG" or "       ").."      "..(irsSystem.aligning() and "SET IRS POS" or "           ")
    return {
    "                        ",
    "                LAST POS",
    "                         ",
    "REF AIRPORT             ",
    "                        ",
    "GATE                    ",
    "                        ",
    "UTC (GPS)        GPS POS",
    "                        ",
    setIRS,
    "                        ",
    "------------------------",
    "                        "
    } 
  else
    return pos_ref(pgNo,true)
  end
end
fmsPages["POSINIT"].getNumPages=function(self)
  return 3 
end
fmsFunctionsDefs["POSINIT"]={}
fmsFunctionsDefs["POSINIT"]["L6"]={"setpage","INITREF"}

-- (step 10a) POS REF 2/3's 3L RNP (0.01-99.9, DELETE the default: FCOM
-- p.1368; VERIFY RNP ENTRY: p.1436), 5L PURGE and CONFIRM, 5R GPS NAV,
-- both pages' 6R BRG/DIST and LAT/LON (FCOM p.1368-1369)
function fmsFunctions.posref(fmsO, value)
  local NP, s = B747_navperf_model, B747_fms_navperf()
  if value == "rnp" then
    local sp = fmsO["scratchpad"]
    if sp == "" then return end
    local r = NP.enter_rnp(s, sp)
    if r == "invalid" then fmsO["notify"] = sp == "DELETE" and "INVALID DELETE" or "INVALID ENTRY" return end
    fmsO["scratchpad"] = ""
    if r == "verify" then fmsO["notify"] = "VERIFY RNP ENTRY" end
  elseif value == "purge" then
    if s.purge then NP.confirm(s) elseif s.anp then NP.purge(s) end
  elseif value == "gpsnav" then
    NP.gps_nav(s)
  elseif value == "brg" then
    s.brg = not s.brg
  end
end
-- (step 10a) INIT/REF INDEX's <POS: POS REF 2/3 in the air with no IRU in
-- ATT, else POS INIT (FCOM p.1367; FMSPG p.74)
function fmsFunctions.initrefpos(fmsO, value)
  if simDR_onGround == 0 and not irsSystem.anyATT() then
    fmsFunctions.setpage_no(fmsO, "POSINIT_2")
  else
    fmsFunctions.setpage(fmsO, "POSINIT")
  end
end
