-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] A fix LNAV sequenced early for its turn (B747DR_vnav_hold_index) stays the next point of VNAV's descent
-- path (setDistances' profile) until the aircraft is past the turn's bisector, as it stays the approach path's and
-- the speed limits' fix: the profile marked only the active fix and those after it, so at the start of NETOM's
-- 97 deg turn (sequenced at its lead) setDescentVSpeed aimed at NIRSI's 5563 ft, 10 nm on, the aircraft 180 ft above
-- that path, and descended through NETOM's 7849 before reaching it; only the AFDS's altitude at the held fix's
-- (VNAV_NEXT_ALT) stopped it there. The production setDistances and setDescentVSpeed (approach_model.lua's loader)
-- on the EHAM route, 1 nm before NETOM on the leg from SUGOL at its path's altitude, NIRSI active and NETOM held.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local SUGOL, NETOM, NIRSI = 5, 6, 7
local o = model.eham({active = NIRSI, mcp_alt_ft = 2000, vnav_speed_kt = 250, at_mode = 3})
local d = {}
local ap = model.load(d, {fmsData = {desspdtransalt = "10000", destranspd = "240", desspd = "270",
    desrestspd = "---", desrestalt = "-----", transalt = "18000", crzalt = "FL370"},
    B747_route_constraints = o.constraints})
model.set_datarefs(d, o, 0.05)
local route = o.route
for i = 1, #route do route[i][10] = (i == NIRSI) end
-- the aircraft 1 nm before NETOM on the leg from SUGOL, on its path (209 ft/nm), 250 kt, past the T/D
local gradient = (route[SUGOL][9] - route[NETOM][9]) / ap.getDistance(route[SUGOL][5], route[SUGOL][6],
    route[NETOM][5], route[NETOM][6])
local inbound = ap.getHeading(route[SUGOL][5], route[SUGOL][6], route[NETOM][5], route[NETOM][6])
d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[NETOM][5], route[NETOM][6], 1.0, (inbound + 180) % 360)
d.simDR_pressureAlt1, d.simDR_radarAlt1 = route[NETOM][9] + gradient, route[NETOM][9] + gradient
d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot = 250, 250
d.simDR_groundspeed = 290 * 0.514444
d.simDR_vvi_fpm_pilot = -gradient * 290 / 60
d.simDR_autopilot_vs_fpm = d.simDR_vvi_fpm_pilot
d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = NIRSI, NETOM
d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
d.B747DR_airspeed_Vmc, d.simDR_TAS_mps, d.simDR_alpha_deg = 150, 300 * 0.514444, 2
d.B747BR_todLat, d.B747BR_todLong = route[2][5], route[2][6]
ap.B747_reset_vnav_energy()
for _ = 1, 3 do ap.setDistances(route) end
for _ = 1, 60 do
    ap.setDescentVSpeed(route)
    d.simDRTime = d.simDRTime + 0.05
end
check(d.B747DR_ap_vnav_target_alt == route[NETOM][9], string.format(
    "NETOM held (NIRSI active, 1 nm before NETOM): the path's next point is NETOM's %d, got %s", route[NETOM][9],
    tostring(d.B747DR_ap_vnav_target_alt)))
check(math.abs(d.B747BR_fpe) <= 60, string.format("on NETOM's leg the 747 is on the path (path error %+.0f ft)",
    d.B747BR_fpe))
local path_vs = -gradient * 290 / 60
check(d.simDR_autopilot_vs_fpm >= path_vs - 250, string.format(
    "the V/S follows NETOM's leg (%.0f fpm, its path %.0f): not steeper towards NIRSI", d.simDR_autopilot_vs_fpm,
    path_vs))

-- past the bisector the hold is let go and NIRSI is the next point
d.B747DR_vnav_hold_index = 0
d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[NETOM][5], route[NETOM][6], 0.8,
    ap.getHeading(route[NETOM][5], route[NETOM][6], route[NIRSI][5], route[NIRSI][6]))
d.simDR_pressureAlt1 = route[NETOM][9] - 150
for _ = 1, 3 do ap.setDistances(route) end
ap.setDescentVSpeed(route)
check(d.B747DR_ap_vnav_target_alt == route[NIRSI][9], string.format(
    "past NETOM's bisector (no hold): the next point is NIRSI's %d, got %s", route[NIRSI][9],
    tostring(d.B747DR_ap_vnav_target_alt)))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV held fix path tests passed: "..checks)
