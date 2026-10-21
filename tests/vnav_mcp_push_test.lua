-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] After the ALT selector is pushed in the descent (a lower MCP altitude set from VNAV ALT), the AFDS's altitude
-- is the new MCP altitude at once, as a real 747-400's descent resumes to it, and once there it is VNAV ALT at once.
-- VNAV_DES_ALT took the MCP altitude only 30 s after a push, and until then VNAV_NEXT_ALT's target - the next point's
-- altitude below the transition altitude - was the AFDS's: the descent levelled off at NETOM's 7849 above the cleared
-- 7000 (review 26 MINOR 3). VNAV ALT waited 30 s after the push too (B747DR_mcp_hold_pressed): a step down reached
-- within it was held by X-Plane, and VNAV_DES took the capture back every 0.2 s ("clear descent"), FMA VNAV PTH, until
-- the 30 s were up (review 27 MINOR 3). The production VNAV_DES_ALT and VNAV_DES (approach_model.lua's loader) on the
-- EHAM route, its CIFP constraints as approach_model.lua's.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local NETOM = 6
local FMS_DATA = {desspdtransalt = "10000", destranspd = "240", desspd = "270", desrestspd = "---",
    desrestalt = "-----", transalt = "18000", crzalt = "FL370"}
-- VNAV_DES_ALT nm before NETOM at alt_ft in VNAV PTH, pushed seconds after the ALT selector's push, the MCP at mcp_ft;
-- returns the AFDS's altitude and B747DR_mcp_hold
local function after_push(o)
    local e = model.eham({active = NETOM, mcp_alt_ft = o.mcp_ft, vnav_speed_kt = 250, at_mode = 3})
    local d = {}
    local ap = model.load(d, {fmsData = FMS_DATA, B747_route_constraints = e.constraints})
    model.set_datarefs(d, e, 0.05)
    local route = e.route
    for i = 1, #route do route[i][10] = (i == NETOM) end
    local prev = route[NETOM - 1]
    d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[NETOM][5], route[NETOM][6], o.nm,
        ap.getHeading(route[NETOM][5], route[NETOM][6], prev[5], prev[6]))
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = o.alt_ft, o.alt_ft
    d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot, d.simDR_groundspeed = 250, 250, 150
    d.simDR_TAS_mps, d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = 150, 2, 150
    d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = NETOM, 0
    d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
    d.B747BR_todLat, d.B747BR_todLong = route[2][5], route[2][6]
    d.B747DR_ap_inVNAVdescent = 1
    d.simDR_autopilot_flch_status, d.simDR_autopilot_vs_status = 0, 2
    d.simDR_autopilot_alt_hold_status = o.alt_hold or 0
    if o.alt_hold == 2 then d.simDR_autopilot_vs_status = 0 end
    d.B747DR_ap_ias_mach_window_open = 0
    d.simDRTime = 1000
    d.B747DR_mcp_hold_pressed = d.simDRTime - o.pushed
    d.B747DR_mcp_hold = 0
    d.simDR_autopilot_altitude_ft = o.afds_ft or o.mcp_ft
    ap.B747_reset_vnav_energy()
    for _ = 1, 3 do ap.setDistances(route) end
    if o.des then
        -- VNAV_DES twice, 0.5 s apart (it acts at most every 0.2 s), X-Plane holding the capture in between
        ap.VNAV_DES(1, route)
        d.simDRTime = d.simDRTime + 0.5
        if o.alt_hold == 2 then d.simDR_autopilot_alt_hold_status, d.simDR_autopilot_vs_status = 2, 0 end
        ap.VNAV_DES(1, route)
        return d.simDR_autopilot_altitude_ft, d.B747DR_mcp_hold, d.simDR_autopilot_alt_hold_status
    end
    ap.VNAV_DES_ALT(1, route)
    return d.simDR_autopilot_altitude_ft, d.B747DR_mcp_hold
end

-- levelled in VNAV ALT at 11,000 ft, the MCP dialled to 7000 and the selector pushed: the descent resumes to 7000
local a = after_push({nm = 8, alt_ft = 11000, mcp_ft = 7000, afds_ft = 11000, pushed = 2})
check(a == 7000, "2 s after the push from VNAV ALT at 11,000 ft, the MCP at 7000: the AFDS's altitude is 7000 (not "
    .."NETOM's 7849), got "..a)
a = after_push({nm = 6, alt_ft = 10500, mcp_ft = 7000, afds_ft = 7000, pushed = 20})
check(a == 7000, "20 s after the push at 10,500 ft: still 7000, got "..a)
a = after_push({nm = 6, alt_ft = 10500, mcp_ft = 7000, afds_ft = 7000, pushed = 40})
check(a == 7000, "40 s after the push: 7000, got "..a)
-- the new MCP altitude reached: VNAV ALT at once, also within 30 s of the push (a 1000 ft step down)
local _, hold = after_push({nm = 2, alt_ft = 7010, mcp_ft = 7000, afds_ft = 7000, pushed = 5, alt_hold = 2})
check(hold == 1, "5 s after a push, holding 7000 at the MCP's 7000: VNAV ALT, got mcp_hold "..hold)
_, hold = after_push({nm = 2, alt_ft = 7010, mcp_ft = 7000, afds_ft = 7000, pushed = 40, alt_hold = 2})
check(hold == 1, "40 s after the push, holding the MCP's 7000: VNAV ALT, got mcp_hold "..hold)
-- and VNAV_DES leaves X-Plane's capture of it alone: no "clear descent" every 0.2 s
local held
_, hold, held = after_push({nm = 2, alt_ft = 7010, mcp_ft = 7000, afds_ft = 7000, pushed = 5, alt_hold = 2,
    des = true})
check(hold == 1 and held == 2, "VNAV_DES 5 s after a push, X-Plane holding the MCP's 7000: VNAV ALT and the capture "
    .."kept, got mcp_hold "..hold..", alt_hold_status "..held)
-- a push with the MCP altitude where the 747 is levelled (nothing to resume): VNAV ALT stays
_, hold, held = after_push({nm = 8, alt_ft = 11000, mcp_ft = 11000, afds_ft = 11000, pushed = 1, alt_hold = 2,
    des = true})
check(hold == 1 and held == 2, "VNAV_DES 1 s after a push at the MCP's 11,000 where the 747 is levelled: VNAV ALT "
    .."stays, got mcp_hold "..hold..", alt_hold_status "..held)

-- [review 28 MINOR 3] the climb as the descent: within 30 s of a push the AFDS's altitude was VNAV's next target, not
-- the MCP altitude below it (33000 for the MCP's 11000 at 10,500 ft), and the 747 could climb through the MCP altitude
-- before the 30 s were up; VNAV ALT waited for them too. The production VNAV_CLB_ALT on TST744L's EINN route, 150 nm
-- before EMPER on its leg from EINN, CRZ ALT FL350
local function climb_push(o)
    local e = model.einn({active = 2, mcp_alt_ft = o.mcp_ft, vnav_speed_kt = 250, at_mode = 3})
    local d = {}
    local ap = model.load(d, {fmsData = e.fms_data, B747_route_constraints = setmetatable({}, {})})
    model.set_datarefs(d, e, 0.05)
    local f = assert(io.open("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.monitor.lua"))
    local source = f:read("*a"); f:close()
    local first = assert(source:find("function VNAV_CLB_ALT(numAPengaged,fms)", 1, true))
    local last = assert(source:find("function VNAV_CLB(numAPengaged,fmsO)", first + 1, true))
    setfenv(assert(loadstring(source:sub(first, last - 1), "@VNAV_CLB_ALT")), ap)()
    local route = e.route
    for i = 1, #route do route[i][10] = (i == 2) end
    d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[2][5], route[2][6], 150,
        ap.getHeading(route[2][5], route[2][6], route[1][5], route[1][6]))
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = o.alt_ft, o.alt_ft
    d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot, d.simDR_groundspeed = 290, 290, 170
    d.simDR_TAS_mps, d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = 170, 2, 150
    d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = 2, 0
    d.B747BR_cruiseAlt = 35000
    d.B747DR_ap_inVNAVdescent = 0
    d.simDR_autopilot_flch_status, d.simDR_autopilot_vs_status = o.alt_hold == 2 and 0 or 2, 0
    d.simDR_autopilot_alt_hold_status = o.alt_hold or 0
    d.simDRTime = 1000
    d.B747DR_mcp_hold_pressed = d.simDRTime - o.pushed
    d.B747DR_mcp_hold = 0
    d.simDR_autopilot_altitude_ft = o.mcp_ft
    for _ = 1, 3 do ap.setDistances(route) end
    ap.VNAV_CLB_ALT(1, route)
    return d.simDR_autopilot_altitude_ft, d.B747DR_mcp_hold
end
a = climb_push({mcp_ft = 11000, alt_ft = 10500, pushed = 25})
check(a == 11000, "climbing at 10,500 ft 25 s after a push, the MCP at 11000: the AFDS's altitude 11000 (not VNAV's "
    .."next target), got "..a)
a = climb_push({mcp_ft = 11000, alt_ft = 10500, pushed = 35})
check(a == 11000, "35 s after the push: 11000, got "..a)
_, hold = climb_push({mcp_ft = 11000, alt_ft = 11010, pushed = 5, alt_hold = 2})
check(hold == 1, "5 s after a push in the climb, holding the MCP's 11000: VNAV ALT, got mcp_hold "..hold)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV MCP push tests passed: "..checks)
