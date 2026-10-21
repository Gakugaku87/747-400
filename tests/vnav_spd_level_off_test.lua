-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV SPD's descent (FLCH: the IAS window open above SPD TRANS) still levels off at the STAR's constraints
-- (their floors), as a real 747-400's VNAV SPD (FCOM 4.10.5), not at the points' predicted altitudes; only VNAV PTH,
-- which flies the path through them, takes the MCP altitude alone as the AFDS's. With the MCP altitude the AFDS's in
-- VNAV SPD too, the idle descent went through SUGOL's FL100-FL140 window and NETOM's at or above FL070 to the MCP. The
-- production VNAV_DES_ALT (approach_model.lua's loader) on the EHAM route, its CIFP constraints as
-- approach_model.lua's, the T/D passed, the MCP still for 30 s.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local SUGOL, NETOM = 5, 6
local FMS_DATA = {desspdtransalt = "10000", destranspd = "240", desspd = "270", desrestspd = "---",
    desrestalt = "-----", transalt = "18000", crzalt = "FL370"}
-- the AFDS's altitude VNAV_DES_ALT sets nm before `active` at alt_ft, in VNAV SPD or VNAV PTH (mode)
local function afds_alt(o)
    local e = model.eham({active = o.active, mcp_alt_ft = o.mcp or 2000, vnav_speed_kt = 250, at_mode = 3})
    for index, alt in pairs(o.changes or {}) do e.route[index][9] = alt end
    for index, c in pairs(o.constraints or {}) do e.constraints[index] = c end
    local d = {}
    local ap = model.load(d, {fmsData = FMS_DATA, B747_route_constraints = e.constraints})
    model.set_datarefs(d, e, 0.05)
    local route = e.route
    for i = 1, #route do route[i][10] = (i == o.active) end
    local prev = route[o.active - 1]
    d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[o.active][5], route[o.active][6], o.nm,
        ap.getHeading(route[o.active][5], route[o.active][6], prev[5], prev[6]))
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = o.alt_ft, o.alt_ft
    d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot, d.simDR_groundspeed = 280, 280, 170
    d.simDR_TAS_mps, d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = 170, 2, 150
    d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = o.active, 0
    d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
    d.B747BR_todLat, d.B747BR_todLong = route[2][5], route[2][6]
    d.B747DR_ap_inVNAVdescent = 2
    -- "spd": FLCH; "spd level": X-Plane's ALT HOLD where VNAV SPD levelled off; "pth": V/S; "pth window": V/S with
    -- the IAS window open
    d.simDR_autopilot_flch_status = o.mode == "spd" and 2 or 0
    d.simDR_autopilot_vs_status = (o.mode == "pth" or o.mode == "pth window") and 2 or 0
    d.simDR_autopilot_alt_hold_status = o.mode == "spd level" and 2 or 0
    d.B747DR_ap_ias_mach_window_open = o.mode == "pth" and 0 or 1
    d.simDRTime, d.B747DR_mcp_hold_pressed = 1000, 0
    d.simDR_autopilot_altitude_ft = o.mcp or 2000
    ap.B747_reset_vnav_energy()
    for _ = 1, 3 do ap.setDistances(route) end
    ap.VNAV_DES_ALT(1, route)
    return d.simDR_autopilot_altitude_ft
end

local a = afds_alt({active = SUGOL, nm = 5, alt_ft = 13000, mode = "spd"})
check(a == 10000, "VNAV SPD at 13,000 ft 5 nm before SUGOL (FL100-FL140, its path 11315), the MCP at 2000: the "
    .."AFDS levels off at SUGOL's floor 10000 (not its predicted 11315), got "..a)
a = afds_alt({active = SUGOL, nm = 2, alt_ft = 11000, mode = "spd level",
    constraints = {[SUGOL] = {alt_desc = "B", floor = 11000, ceiling = 14000, fl = true, phase = "descent"}}})
check(a == 11000, "VNAV SPD levelled off at SUGOL's floor (made FL110) 2 nm before it (X-Plane's ALT HOLD, the IAS "
    .."window open): the AFDS stays at 11000 until SUGOL, got "..a)
a = afds_alt({active = SUGOL, nm = 5, alt_ft = 13000, mode = "spd", changes = {[SUGOL] = 9500}})
check(a == 10000, "VNAV SPD at 13,000 ft 5 nm before SUGOL, the native FMS's 9500 below its window's FL100: at the "
    .."floor 10000, got "..a)
a = afds_alt({active = SUGOL, nm = 5, alt_ft = 13000, mode = "spd", mcp = 12000})
check(a == 12000, "VNAV SPD with the MCP at 12,000 ft above SUGOL's 11315: the MCP's 12000, got "..a)
a = afds_alt({active = SUGOL, nm = 5, alt_ft = 13000, mode = "pth"})
check(a == 2000, "VNAV PTH at 13,000 ft 5 nm before SUGOL: the MCP's 2000 (the path through SUGOL), got "..a)
a = afds_alt({active = NETOM, nm = 5, alt_ft = 9000, mode = "pth window"})
check(a == 2000, "the IAS window open at 9,000 ft below SPD TRANS 10000 (VNAV PTH, the A/T on the window's speed) 5 "
    .."nm before NETOM: the MCP's 2000, got "..a)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV SPD level-off tests passed: "..checks)
