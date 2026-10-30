-- RTE DATA (6-1/6-2 step 8d2; notes/ATA-34-61-FMC.md §49; FCOM p.1360-1363):
-- the active route's waypoints, five a page as on its LEGS pages, each with
-- its ETA and fuel remaining (small) from the trajectory predictions (step
-- 8c; across a discontinuity direct: FCOM p.1363; none after the E/D, as on
-- LEGS) and the waypoint's WIND page at 1R-5R (step 8e1: "W>" where winds
-- are entered, else ">"; FCOM p.1363). LEGS> at 6R on the 109 (FCOM p.1362),
-- <LEGS at 6L on the 570 (FCOM p.1361; its REQUEST SEND> only with a wind
-- uplink, which there is none of: not shown, an estimate). From the active
-- LEGS page's 6R.
local R = B747_route_model
local BLANK = string.rep(" ", 24)
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end

-- the 570's layout (the GE airplane; the PW and RR the 109's)
local function is570() return B747DR_fms_engine_type == 1 end

fmsPages["RTEDATA"] = createPage("RTEDATA")
fmsPages["RTEDATA"].getNumPages = function(self)
  return math.max(1, math.ceil(#B747_fmc_route.rte.legs / 5))
end

-- a page's five rows: the large (WPT at the 7th place, ">" at the 24th) and
-- the small (the ETA at the 1st to 5th, FUEL at the 15th to 19th) parts
local function rd_rows(pgNo)
  local r = B747_fmc_route.rte
  local pred = B747_fms_preds()
  local large, small = {}, {}
  for k = 1, 5 do
    local i = (pgNo - 1) * 5 + k
    local l = r.legs[i]
    large[k], small[k] = BLANK, BLANK
    if l and (l.disc or l.pending) then
      small[k] = "-- ROUTE DISCONTINUITY -"
    elseif l then
      large[k] = lr(string.format("      %-8s", R.leg_name(l)), B747_wind_model.entered(l) and "W>" or ">")
      local p = pred and not (pred.ed_i and i > pred.ed_i) and pred.pts[i]
      if p then
        local _, h, m = get_ETA_for_Distance(0, p.t)
        small[k] = string.format("%02d%02dz         %5.1f     ", h, m, perf_out(p.fuel / 1000))
      end
    end
  end
  return large, small
end

fmsPages["RTEDATA"].getPage = function(self, pgNo, fmsID)
  local large = rd_rows(pgNo)
  local ge = is570()
  return {
    string.format("%-24s", string.format("     ACT RTE %d DATA", B747_fmc_route.num)),
    BLANK, large[1], BLANK, large[2], BLANK, large[3], BLANK, large[4], BLANK, large[5],
    ge and "----------------        " or "--------------          ",
    ge and lr("<LEGS", "") or lr("", "LEGS>")
  }
end

fmsPages["RTEDATA"].getSmallPage = function(self, pgNo, fmsID)
  local _, small = rd_rows(pgNo)
  return {
    string.format("%23s ", pgNo .. "/" .. fmsPages["RTEDATA"]:getNumPages()),
    " ETA    WPT   FUEL  WIND",
    small[1], BLANK, small[2], BLANK, small[3], BLANK, small[4], BLANK, small[5],
    BLANK,
    BLANK
  }
end

-- LEGS: the active route's LEGS pages (6R on the 109, 6L on the 570)
function fmsFunctions.rtedatalegs(fmsO, value)
  if (value == "L") == is570() then B747_cdu_legs_page(fmsO) end
end
-- 1R-5R: that row's waypoint's WIND page (FCOM p.1363)
function fmsFunctions.rtedatawind(fmsO, value)
  local i = (fmsO.pgNo - 1) * 5 + tonumber(value)
  local l = B747_fmc_route.rte.legs[i]
  if l and not (l.disc or l.pending) then B747_cdu_wind_page(fmsO, i) end
end
fmsFunctionsDefs["RTEDATA"] = {}
fmsFunctionsDefs["RTEDATA"]["L6"] = {"rtedatalegs", "L"}
fmsFunctionsDefs["RTEDATA"]["R6"] = {"rtedatalegs", "R"}
for k = 1, 5 do fmsFunctionsDefs["RTEDATA"]["R" .. k] = {"rtedatawind", tostring(k)} end
