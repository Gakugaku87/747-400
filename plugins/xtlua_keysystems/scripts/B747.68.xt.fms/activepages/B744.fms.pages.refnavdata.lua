-- REF NAV DATA (6-1/6-2 step 7e; notes/ATA-34-61-FMC.md §36): a point of the
-- FMC's navigation database (B747.68.navdb.lua) and the navaids the FMCs
-- leave out of their radio position updating (FCOM p.1355-1357; FMSPG
-- p.170-174; ATA34_2 p.547-548).
--  - NAV DATA> on the INIT/REF INDEX, the only way to it (FCOM p.1281).
--  - IDENT: dashes each time the page is selected (FCOM p.1355); a
--    waypoint, a navaid, an airport, or a runway of the destination
--    ("RW16R": FMSPG p.171; ATA34_2 p.547); SELECT DESIRED WPT for an
--    identifier of more than one, the nearest to the airplane first (FCOM
--    p.1335); NOT IN DATA BASE for any other entry (ATA34_2 p.547); no
--    DELETE (FMSPG p.171).
--  - FREQ for a navaid; LATITUDE and LONGITUDE; MAG VAR for a navaid,
--    LENGTH for a runway; ELEVATION for a navaid, an airport or a runway's
--    threshold, not a waypoint (FCOM p.1356; FMSPG p.171-172; ATA34_2
--    p.547-548).
--  - NAVAID INHIBIT: two VORs, VOR/DMEs, VORTACs or DMEs; VOR ONLY
--    INHIBIT: two VORs; DELETE or another entry takes one back (FCOM
--    p.1356; FMSPG p.172-173). VOR/DME NAV INHIBIT> and ENABLE>: ALL in
--    small font in the VOR ONLY lines, their entries gone (FCOM p.1357;
--    FMSPG p.173-174). They are both FMCs' (every CDU shows them):
--    B747_fmc_nav_inhibits() for the radio position updating (step 10);
--    cleared at flight completion (FCOM p.1356-1357) with the flight
--    phases (step 9).
-- Estimates: the headers under IDENT only with a point; five dashes for
-- the IDENT; an NDB's frequency in kHz; the MAG VAR of an NDB, a DME alone
-- or a localizer the variation there (the nearest VOR's:
-- B747.68.navdb.lua); E15, W7; the runway's length from the CIFP's
-- thresholds (B747.68.navdb.lua) in feet with FT small, blank without the
-- other end; INVALID ENTRY for a navaid of another kind in the inhibit
-- lines and in the VOR ONLY lines while ALL shows; INVALID DELETE on
-- dashes.
-- Before: X-Plane's own nav data page (its DATABASE page) shown through.
local R = B747_route_model
local BLANK = "                        "

local function pad(s) return string.sub((s or "") .. BLANK, 1, 24) end
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end
local function db_N() return B747_fmc_route.N, B747_fmc_route.db end

-- each CDU's point (nil: the dashes)
local refPoint = {}
-- the FMCs' inhibits: navaid[1], navaid[2] (4L, 4R), vor[1], vor[2] (5L,
-- 5R): the navaids' records; vordme: VOR/DME NAV inhibited
local inhibit = {navaid = {}, vor = {}, vordme = false}
function B747_fmc_nav_inhibits() return inhibit end

local NAVAID = {VOR = true, DME = true, NDB = true, LOC = true}
local function freq_text(p)
  if not p.freq then return "" end
  if p.kind == "NDB" then return string.format("%d", p.freq) end
  return string.format("%.2f", p.freq / 100)
end
-- a VOR's own variation, else the variation there; east positive
local function var_text(p)
  local N, db = db_N()
  local v = p.kind == "VOR" and p.var or N.variation(db, p.lat, p.lon)
  if not v then return "" end
  v = math.floor(v + 0.5)
  return (v < 0 and "W" or "E") .. math.abs(v)
end

-- a runway of the destination (FMSPG p.171; ATA34_2 p.547)
local function dest_runway(ident)
  local id = string.match(ident, "^RW%d%d[LCR]?$")
  local dest = id and R.shown(B747_fmc_route).dest
  if not dest then return nil end
  local N, db = db_N()
  local c = N.cifp(db, dest.ident)
  local rw = c and c.runways[id]
  if not rw then return nil end
  return {kind = "RWY", ident = id, lat = rw.lat, lon = rw.lon, elev = rw.elev, length = N.runway_length(c, id)}
end

-- a point's lines: large 3, 5 and 7, small 2, 4, 6 and 7 (FT)
local function point_lines(p)
  if not p then return {l3 = "-----", s2 = " IDENT"} end
  local freq = NAVAID[p.kind] and freq_text(p) or ""
  local left, left_hdr, left_ft = "", "", ""
  if NAVAID[p.kind] then
    left = var_text(p)
    left_hdr = left ~= "" and " MAG VAR" or ""
  elseif p.kind == "RWY" and p.length then
    left = string.format("%d", math.floor(p.length + 0.5))
    left_hdr, left_ft = " LENGTH", string.rep(" ", #left) .. "FT"
    left = left .. "  "
  end
  local right, right_hdr, right_ft = "", "", ""
  if p.kind ~= "WPT" and p.elev then
    right, right_hdr, right_ft = string.format("%d  ", math.floor(p.elev + 0.5)), "ELEVATION", "FT"
  end
  return {
    l3 = lr(p.ident, freq), l5 = lr(toDMS(p.lat, true), toDMS(p.lon, false)), l7 = lr(left, right),
    s2 = freq ~= "" and lr(" IDENT", "FREQ") or " IDENT", s4 = " LATITUDE      LONGITUDE",
    s6 = lr(left_hdr, right_hdr), s7 = lr(left_ft, right_ft)
  }
end

local function ident_of(p) return p and p.ident or "----" end

fmsPages["REFNAVDATA"]=createPage("REFNAVDATA")
fmsPages["REFNAVDATA"].getPage=function(self,pgNo,fmsID)
  local t = point_lines(refPoint[fmsID])
  return {
    "      REF NAV DATA      ",
    BLANK, pad(t.l3), BLANK, pad(t.l5), BLANK, pad(t.l7),
    BLANK, lr(ident_of(inhibit.navaid[1]), ident_of(inhibit.navaid[2])),
    BLANK, inhibit.vordme and BLANK or lr(ident_of(inhibit.vor[1]), ident_of(inhibit.vor[2])),
    "-------------           ",
    lr("<INDEX", inhibit.vordme and "ENABLE>" or "INHIBIT>")
  }
end
fmsPages["REFNAVDATA"].getSmallPage=function(self,pgNo,fmsID)
  local t = point_lines(refPoint[fmsID])
  return {
    BLANK, pad(t.s2), BLANK, pad(t.s4), BLANK, pad(t.s6), pad(t.s7),
    "     NAVAID INHIBIT     ", BLANK,
    "    VOR ONLY INHIBIT    ", inhibit.vordme and lr("ALL", "ALL") or BLANK,
    "             VOR/DME NAV", BLANK
  }
end
fmsFunctionsDefs["REFNAVDATA"]={}
fmsFunctionsDefs["REFNAVDATA"]["L1"]={"refnavident",""}
fmsFunctionsDefs["REFNAVDATA"]["L4"]={"refnavinhibit","navaid1"}
fmsFunctionsDefs["REFNAVDATA"]["R4"]={"refnavinhibit","navaid2"}
fmsFunctionsDefs["REFNAVDATA"]["L5"]={"refnavinhibit","vor1"}
fmsFunctionsDefs["REFNAVDATA"]["R5"]={"refnavinhibit","vor2"}
fmsFunctionsDefs["REFNAVDATA"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["REFNAVDATA"]["R6"]={"refnavvordme",""}

-- NAV DATA> (INIT/REF INDEX 1R): the page with the IDENT's dashes (FCOM
-- p.1355; FMSPG p.171)
function fmsFunctions.refnavdata(fmsO, value)
  refPoint[fmsO.id] = nil
  fmsFunctions.setpage(fmsO, "REFNAVDATA")
end

-- 1L IDENT
function fmsFunctions.refnavident(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  local rw = dest_runway(sp)
  if rw then
    refPoint[fmsO.id] = rw
    fmsO["scratchpad"] = ""
    return
  end
  if not string.match(sp, "^%w%w?%w?%w?%w?$") then fmsO["notify"] = "NOT IN DATA BASE" return end
  -- the database's points, not the crew's waypoints of the route (step 7e3a)
  local list = R.candidates(B747_fmc_route, sp, simDR_latitude, simDR_longitude, true)
  B747_fmc_with_point(fmsO, sp, nil, function(p)
    refPoint[fmsO.id] = p
    fmsO["scratchpad"] = ""
  end, list)
end

-- 4L/4R NAVAID INHIBIT: a VOR, VOR/DME, VORTAC or DME; 5L/5R VOR ONLY
-- INHIBIT: a VOR (FCOM p.1356; FMSPG p.172-173)
local SLOT = {navaid1 = {"navaid", 1}, navaid2 = {"navaid", 2}, vor1 = {"vor", 1}, vor2 = {"vor", 2}}
function fmsFunctions.refnavinhibit(fmsO, value)
  local list, n = SLOT[value][1], SLOT[value][2]
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then
    if not inhibit[list][n] then fmsO["notify"] = "INVALID DELETE" return end
    inhibit[list][n] = nil
    fmsO["scratchpad"] = ""
    return
  end
  if list == "vor" and inhibit.vordme then fmsO["notify"] = "INVALID ENTRY" return end
  if not string.match(sp, "^%w%w?%w?%w?$") then fmsO["notify"] = "INVALID ENTRY" return end
  local N, db = db_N()
  local all = N.find(db, sp, simDR_latitude, simDR_longitude)
  if #all == 0 then fmsO["notify"] = "NOT IN DATA BASE" return end
  local cands = {}
  for _, p in ipairs(all) do
    if p.kind == "VOR" or (list == "navaid" and p.kind == "DME") then cands[#cands + 1] = p end
  end
  if #cands == 0 then fmsO["notify"] = "INVALID ENTRY" return end
  B747_fmc_with_point(fmsO, sp, nil, function(p)
    inhibit[list][n] = p
    fmsO["scratchpad"] = ""
  end, cands)
end

-- 6R VOR/DME NAV: INHIBIT> inhibits the VOR/DME updating, ALL over the VOR
-- ONLY entries; ENABLE> back to dashes (FCOM p.1357; FMSPG p.173-174)
function fmsFunctions.refnavvordme(fmsO, value)
  inhibit.vordme = not inhibit.vordme
  inhibit.vor = {}
end
