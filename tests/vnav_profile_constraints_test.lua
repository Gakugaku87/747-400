-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV's descent path (setDistances' profile) crosses each point inside the STAR's and the approach's
-- constraints from the CIFP (B747_route_constraints): the native FMS's altitude ([9]) raised to the floor, lowered to
-- the ceiling, and a point with no altitude but a constraint taken at its floor (else its ceiling). The profile took
-- [9] alone; a point below its floor was kept above it only by the AFDS's altitude at the floor (VNAV_NEXT_ALT's
-- level-off), which a real 747-400's AFDS does not have (its MCP altitude only). The production setDistances and
-- setDescentVSpeed (approach_model.lua's loader) on the EHAM route, its CIFP constraints as approach_model.lua's.
local model = dofile("tests/approach_model.lua")
local json = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/json/json.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local DIBAL, LAMSO, ETPOS, SUGOL, NETOM, AM608 = 2, 3, 4, 5, 6, 9
local FMS_DATA = {desspdtransalt = "10000", destranspd = "240", desspd = "270", desrestspd = "---",
    desrestalt = "-----", transalt = "18000", crzalt = "FL370"}
-- the profile's altitude at the route's point (nil without one), with the aircraft 10 nm before `active` on its leg;
-- changes to the native FMS's altitudes ([9]) and to the constraints
local function profile(changes, active, constraint_changes)
    local o = model.eham({active = active, mcp_alt_ft = 2000, vnav_speed_kt = 250, at_mode = 3})
    for index, alt in pairs(changes) do o.route[index][9] = alt end
    for index, c in pairs(constraint_changes or {}) do o.constraints[index] = c end
    local d = {}
    local ap = model.load(d, {fmsData = FMS_DATA, B747_route_constraints = o.constraints})
    model.set_datarefs(d, o, 0.05)
    local route = o.route
    for i = 1, #route do route[i][10] = (i == active) end
    local prev = route[active - 1]
    d.simDR_latitude, d.simDR_longitude = ap.movePoint(route[active][5], route[active][6], 10,
        ap.getHeading(route[active][5], route[active][6], prev[5], prev[6]))
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 14000, 14000
    d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot, d.simDR_groundspeed = 250, 250, 150
    d.simDR_TAS_mps, d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = 150, 2, 150
    d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = active, 0
    d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
    d.B747BR_todLat, d.B747BR_todLong = route[2][5], route[2][6]
    ap.B747_reset_vnav_energy()
    for _ = 1, 3 do ap.setDistances(route) end
    local points = {}
    for _, p in ipairs(json.decode(d.B747BR_vnavProfile)) do
        for i = 1, #route do
            if math.abs(route[i][5] - p[1]) < 1e-9 and math.abs(route[i][6] - p[2]) < 1e-9 then points[i] = p[3] end
        end
    end
    ap.setDescentVSpeed(route)
    return points, d.B747DR_ap_vnav_target_alt
end

local p = profile({}, SUGOL)
check(p[SUGOL] == 11315 and p[NETOM] == 7849, string.format(
    "inside their constraints the points keep the native FMS's altitudes (SUGOL %s, NETOM %s)", tostring(p[SUGOL]),
    tostring(p[NETOM])))
p = profile({[NETOM] = 6800}, SUGOL)
check(p[NETOM] == 7000, "NETOM's 6800 below its floor FL070: the path crosses it at 7000, got "..tostring(p[NETOM]))
p = profile({[SUGOL] = 15000}, SUGOL)
check(p[SUGOL] == 14000, "SUGOL's 15000 above its window's FL140: 14000, got "..tostring(p[SUGOL]))
p = profile({[SUGOL] = 9500}, SUGOL)
check(p[SUGOL] == 10000, "SUGOL's 9500 below its window's FL100: 10000, got "..tostring(p[SUGOL]))
p = profile({[AM608] = 0}, SUGOL)
check(p[AM608] == 3400, "AM608 without an altitude: its floor 3400, got "..tostring(p[AM608]))
local _, target = profile({[NETOM] = 6800}, NETOM)
check(target == 7000, "NETOM next with 6800 below its floor: setDescentVSpeed aims at 7000, got "..tostring(target))
-- [review 26 MINOR 5] a point without [9] takes the straight path's altitude between its neighbours, inside its
-- constraint
p = profile({[SUGOL] = 0}, SUGOL)
check(p[SUGOL] ~= nil and p[SUGOL] > 11700 and p[SUGOL] < 11950, "SUGOL without an altitude: the straight path from "
    .."ETPOS's 16752 to NETOM's 7849 (about 11,830), inside its window FL100-FL140 (it took the floor 10000), got "
    ..tostring(p[SUGOL]))
local AT_OR_BELOW = function(ft) return {alt_desc = "-", ceiling = ft, fl = true, phase = "descent"} end
p = profile({[LAMSO] = 0}, SUGOL, {[LAMSO] = AT_OR_BELOW(23000)})
check(p[LAMSO] ~= nil and p[LAMSO] > 21300 and p[LAMSO] < 21600, "LAMSO without an altitude, at or below FL230: the "
    .."straight path from DIBAL's 26309 to ETPOS's 16752 (about 21,450; it took the ceiling 23000, a level-off), got "
    ..tostring(p[LAMSO]))
p = profile({[LAMSO] = 0}, SUGOL, {[LAMSO] = AT_OR_BELOW(20000)})
check(p[LAMSO] == 20000, "LAMSO without an altitude, at or below FL200 under the straight path: 20000, got "
    ..tostring(p[LAMSO]))
-- [review 27 MINOR 4] after a point in the cruise (its [9] the CRZ ALT) the path is level to the T/D and comes down at
-- the T/D's 290 ft/nm: a point without [9] takes that line back from the next point with one, not the straight line
-- from the cruise point
p = profile({[DIBAL] = 37000, [LAMSO] = 0}, SUGOL, {[LAMSO] = AT_OR_BELOW(23000)})
check(p[LAMSO] ~= nil and p[LAMSO] > 21700 and p[LAMSO] < 22050, "LAMSO without an altitude after DIBAL in the "
    .."cruise (FL370), at or below FL230: 290 ft/nm back from ETPOS's 16752 (about 21,870; the straight line from "
    .."DIBAL's 37000 took the ceiling 23000), got "..tostring(p[LAMSO]))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV profile constraints tests passed: "..checks)
