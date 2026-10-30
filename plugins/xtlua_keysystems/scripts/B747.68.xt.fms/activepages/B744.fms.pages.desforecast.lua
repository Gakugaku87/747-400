-- DESCENT FORECAST (6-1/6-2 step 8e2; notes/ATA-34-61-FMC.md §52; FCOM
-- p.1395-1397, FMSPG p.178-179, p.230): from the DES page's FORECAST>
-- (5R): TRANS LVL (1L: the destination's, else FL180; a crew's entry, no
-- DELETE; the FMC's altitudes in the descent as flight levels above it),
-- TAI/ON ALT (1R: where anti-ice comes on in the descent), and up to four
-- descent winds (2L-5L ALT in any order, not sorted, none twice; 2R-5R
-- WIND DIR/SPD, true: the first entry both, later ones either, ddd/ or
-- /sss; the direction three digits, the speed up to 250 kt).
-- The 109's 6th line as FCOM p.1396's figure (<OFFPATH DES, DES DIR>: as on
-- the DES page, no functions yet); the 570's DES> at 6R (its datalink's
-- SEND, LOAD and PURGE: none, an estimate as on RTE DATA). The predictions
-- use the forecast in step 8e3.
local BLANK = string.rep(" ", 24)
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end

-- the forecast (the descent's: B747_fms_des_forecast() for the predictions)
local fc = {translvl = nil, tai = nil, slots = {{}, {}, {}, {}}}
function B747_fms_des_forecast() return fc end
-- the transition level (ft): the crew's entry, else the destination's
-- (the navigation data's: FMSPG p.178), else FL180 (FCOM p.1396)
function B747_fms_trans_lvl()
  if fc.translvl then return fc.translvl end
  local d = B747_fmc_route.rte.dest
  if d and d.tl and d.tl > 0 then return d.tl end
  return 18000
end

-- the 570's layout (the GE airplane; the PW and RR the 109's)
local function is570() return B747DR_fms_engine_type == 1 end
local function alt_text(ft) return B747_cdu_model.format_alt(ft, B747_fms_trans_lvl()) end

fmsPages["DESFORECAST"] = createPage("DESFORECAST")
fmsPages["DESFORECAST"].getNumPages = function(self) return 1 end

fmsPages["DESFORECAST"].getPage = function(self, pgNo, fmsID)
  local rows = {}
  for k = 1, 4 do
    local s = fc.slots[k]
    local w = s.dir and string.format("%03d`/%3d", s.dir, s.kt) or "---`/---"
    -- ALT at 1-5, WIND DIR/SPD at 15-22 and "KT" at 23-24 (small)
    rows[k] = string.format("%-14s", s.ft and alt_text(s.ft) or "-----") .. w .. "  "
  end
  return {
    "    DESCENT FORECAST    ",
    BLANK,
    lr(string.format("FL%03d", math.floor(B747_fms_trans_lvl() / 100 + 0.5)), fc.tai and alt_text(fc.tai) or "-----"),
    BLANK, rows[1], BLANK, rows[2], BLANK, rows[3], BLANK, rows[4],
    "------------------------",
    is570() and lr("", "DES>") or lr("<OFFPATH DES", "DES DIR>")
  }
end

fmsPages["DESFORECAST"].getSmallPage = function(self, pgNo, fmsID)
  local kt = string.rep(" ", 22) .. "KT"
  return {
    BLANK,
    " TRANS LVL    TAI/ON ALT",
    BLANK,
    " ALT        WIND DIR/SPD",
    kt, BLANK, kt, BLANK, kt, BLANK, kt,
    BLANK,
    BLANK
  }
end

-- an altitude entry: an altitude or flight level up to FL450
local function alt_entry(sp)
  local h = B747_cdu_model.parse_alt(sp)
  if h and h > 0 and h <= 45000 then return h end
  return nil
end
local function accepted(fmsO)
  fmsO["scratchpad"] = ""
  B747_fms_preds_now()
end

-- 1L TRANS LVL (FCOM p.1396): an altitude or flight level; no DELETE
-- (FMSPG p.179)
function fmsFunctions.dftranslvl(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then fmsO["notify"] = "INVALID DELETE" return end
  local h = alt_entry(sp)
  if not h then fmsO["notify"] = "INVALID ENTRY" return end
  fc.translvl = h
  accepted(fmsO)
end

-- 1R TAI/ON ALT (FCOM p.1397): where anti-ice first comes on in the
-- descent; DELETE
function fmsFunctions.dftai(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  if sp == "DELETE" then
    if not fc.tai then fmsO["notify"] = "INVALID DELETE" return end
    fc.tai = nil
  else
    local h = alt_entry(sp)
    if not h then fmsO["notify"] = "INVALID ENTRY" return end
    fc.tai = h
  end
  accepted(fmsO)
end

-- 2L-5L ALT (FCOM p.1396; FMSPG p.179): any order, not sorted, none twice;
-- DELETE the line (its wind too)
function fmsFunctions.dfalt(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local s = fc.slots[tonumber(value)]
  if sp == "DELETE" then
    if not s.ft then fmsO["notify"] = "INVALID DELETE" return end
    fc.slots[tonumber(value)] = {}
  else
    local h = alt_entry(sp)
    if not h then fmsO["notify"] = "INVALID ENTRY" return end
    for k, o in ipairs(fc.slots) do
      if k ~= tonumber(value) and o.ft == h then fmsO["notify"] = "INVALID ENTRY" return end
    end
    s.ft = h
  end
  accepted(fmsO)
end

-- 2R-5R WIND DIR/SPD (FCOM p.1397; FMSPG p.179): on a line with an altitude
-- (an estimate); the first entry ddd/sss, later ones ddd/ or /sss as well;
-- DELETE
function fmsFunctions.dfwind(fmsO, value)
  local sp = fmsO["scratchpad"]
  if sp == "" then return end
  local s = fc.slots[tonumber(value)]
  if sp == "DELETE" then
    if not s.dir then fmsO["notify"] = "INVALID DELETE" return end
    s.dir, s.kt = nil, nil
    accepted(fmsO)
    return
  end
  local dir, kt = B747_wind_model.parse_wind(sp)
  local ok = s.ft and (dir or kt) and (s.dir or (dir and kt))
  if not ok then fmsO["notify"] = "INVALID ENTRY" return end
  s.dir, s.kt = dir or s.dir, kt or s.kt
  accepted(fmsO)
end

-- the 570's DES> (FCOM p.1397): the DES page
function fmsFunctions.dfdes(fmsO, value)
  if is570() then fmsFunctions.setpage_no(fmsO, "VNAV_3") end
end

fmsFunctionsDefs["DESFORECAST"] = {}
fmsFunctionsDefs["DESFORECAST"]["L1"] = {"dftranslvl", ""}
fmsFunctionsDefs["DESFORECAST"]["R1"] = {"dftai", ""}
for k = 1, 4 do
  fmsFunctionsDefs["DESFORECAST"]["L" .. (k + 1)] = {"dfalt", tostring(k)}
  fmsFunctionsDefs["DESFORECAST"]["R" .. (k + 1)] = {"dfwind", tostring(k)}
end
fmsFunctionsDefs["DESFORECAST"]["R6"] = {"dfdes", ""}
