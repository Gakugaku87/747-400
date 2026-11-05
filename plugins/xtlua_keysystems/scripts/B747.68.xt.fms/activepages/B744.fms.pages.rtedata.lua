-- RTE DATA (6-1/6-2 step 8d2; notes/ATA-34-61-FMC.md §49; FCOM p.1360-1363):
-- the active route's waypoints, five a page as on its LEGS pages, each with
-- its ETA and fuel remaining (small) from the trajectory predictions (step
-- 8c; across a discontinuity direct: FCOM p.1363; none after the E/D, as on
-- LEGS) and the waypoint's WIND page at 1R-5R (step 8e1: "W>" where winds
-- are entered, else ">"; FCOM p.1363). LEGS> at 6R on the 109 (FCOM p.1362),
-- <LEGS at 6L on the 570 (FCOM p.1361). From the active LEGS page's 6R.
-- (step 12h2; notes/ATA-34-61-FMC.md §124) with the FMC's datalink the
-- company's winds (FCOM p.1361, p.1363-1364; FMSPG p.377-378): 6R REQUEST
-- SEND> (not in the descent or on approach; SENT), WIND DATA LOAD> with
-- an uplink, loading it the modification's MOD RTE DATA with <ERASE at 6L
-- (EXEC applies it).
local R = B747_route_model
local BLANK = string.rep(" ", 24)
local function lr(l, r) return l .. string.rep(" ", math.max(1, 24 - #l - #r)) .. r end

-- the 570's layout (the GE airplane; the PW and RR the 109's); (step 12h2)
-- the FMC's datalink's too (SIM CONFIG's FMC DATALINK ON: step 12a)
local function is570() return B747DR_fms_engine_type == 1 or B747_fms_datalink() end

fmsPages["RTEDATA"] = createPage("RTEDATA")
fmsPages["RTEDATA"].getNumPages = function(self)
  return math.max(1, math.ceil(#R.shown(B747_fmc_route).legs / 5))
end

-- a page's five rows: the large (WPT at the 7th place, ">" at the 24th) and
-- the small (the ETA at the 1st to 5th, FUEL at the 15th to 19th) parts
local function rd_rows(pgNo)
  local r = R.shown(B747_fmc_route)
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
        -- the fuel blank with CRZ ALT at or above MAX (ATA34_2 p.611;
        -- 2026-11-05 review 4)
        local f = pred.no_fuel and "     " or string.format("%5.1f", perf_out(p.fuel / 1000))
        small[k] = string.format("%02d%02dz         %s     ", h, m, f)
      end
    end
  end
  return large, small
end

-- (step 12h2) the datalink's 6R: "SEND", "SENDING", "LOAD" or "" (FCOM
-- p.1363), with the company's link and its request's SENT
local function six_r()
  if not B747_fms_datalink() then return "", false end
  local wr, wup = B747_fms_company_winds()
  if wup then return "LOAD", false end
  if not B747_fms_company_wind_send_shown() then return "", false end
  if wr and wr.status == "SENDING" then return "SENDING", false end
  return "SEND", wr ~= nil and wr.status == "SENT"
end

fmsPages["RTEDATA"].getPage = function(self, pgNo, fmsID)
  local large = rd_rows(pgNo)
  local ge = is570()
  local st = B747_fmc_route
  local six = ge and lr("<LEGS", "") or lr("", "LEGS>")
  local dashes = ge and "----------------        " or "--------------          "
  if ge and B747_fms_datalink() then
    local r6 = six_r()
    six = lr(st.mod and "<ERASE" or "<LEGS", (r6 == "SEND" or r6 == "LOAD") and (r6 .. ">") or r6)
    if r6 == "LOAD" then dashes = "--------------          " end
  end
  return {
    string.format("%-24s", string.format("     %s RTE %d DATA", st.mod and "MOD" or "ACT", st.num)),
    BLANK, large[1], BLANK, large[2], BLANK, large[3], BLANK, large[4], BLANK, large[5],
    dashes,
    six
  }
end

fmsPages["RTEDATA"].getSmallPage = function(self, pgNo, fmsID)
  local _, small = rd_rows(pgNo)
  -- (step 12h2) REQUEST or WIND DATA over 6R, SENT after SEND
  local title, sent = BLANK, BLANK
  if is570() and B747_fms_datalink() then
    local r6, isSent = six_r()
    if r6 == "LOAD" then title = "               WIND DATA"
    elseif r6 ~= "" then title = "                 REQUEST" end
    if isSent then sent = "               SENT     " end
  end
  return {
    string.format("%23s ", pgNo .. "/" .. fmsPages["RTEDATA"]:getNumPages()),
    " ETA    WPT   FUEL  WIND",
    small[1], BLANK, small[2], BLANK, small[3], BLANK, small[4], BLANK, small[5],
    title,
    sent
  }
end

-- LEGS: the active route's LEGS pages (6R on the 109, 6L on the 570);
-- (step 12h2) 6L ERASE on the wind uplink's modification, 6R the
-- datalink's SEND and LOAD
function fmsFunctions.rtedatalegs(fmsO, value)
  local dl = is570() and B747_fms_datalink()
  if dl and value == "L" and B747_fmc_route.mod then
    B747_route_model.erase(B747_fmc_route)
    B747_fmc_route_changed()
    return
  end
  if dl and value == "R" then
    local r6 = six_r()
    if r6 == "SEND" then B747_fms_company_wind_request() end
    if r6 == "LOAD" then B747_fms_company_wind_load() end
    return
  end
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
-- (step 12h2) EXEC: the wind uplink's modification (FCOM p.1364)
fmsFunctionsDefs["RTEDATA"]["exec"] = {"rteexec", ""}
