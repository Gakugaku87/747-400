-- Run from the repository root with Lua 5.1 or LuaJIT.
-- A fix LNAV sequences early for its turn keeps its altitude as VNAV's floor
-- until the aircraft is past the turn's bisector, where the FMC sequences it.
-- A turn LNAV flies by its path (item i-1b) is itself sequenced at the
-- bisector, so its fix stays the active one and VNAV's until there; the early
-- sequencing and this hold remain for the turns at the end of a leg flown
-- direct to its fix (after VECTORS here).
-- LNAV starts a fly-by turn at the turn's lead before the fix and makes the
-- next fix the active one there; VNAV's descent target was the active fix's
-- altitude, so it dropped to the next fix's at the start of the turn and the
-- aircraft went on descending through the passed fix's constraint: EHAM ILS
-- 18R via SUG1D, NIRSI at or above FL055 (the native FMS's VNAV altitude
-- 5563), sequenced 1.9 nm before NIRSI for its 65 deg turn while descending
-- at 900-1100 fpm through 5850 ft, passed at 5400 ft (the kit's p5-line1 and
-- line4: 95 and 79 ft low). The production LNAV (B747.70.xt.autopilot.lua)
-- and VNAV_NEXT_ALT (monitor.lua) run against mocked datarefs.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
-- Run every scenario and report all of them, so one failure does not hide the rest.
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        checks = checks + 1
        failures[#failures + 1] = name..": "..tostring(err)
    end
end

local sources = {}
local function slice(path, first_marker, last_marker)
    if sources[path] == nil then
        local file = assert(io.open(path))
        sources[path] = file:read("*a")
        file:close()
    end
    local source = sources[path]
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end

-- 1. The bisector of the turn at a fix: the aircraft at (east, north) nm from
-- the fix is past it once its position along the mean of the inbound and
-- outbound courses is positive (for a straight fix: abeam the fix; for a
-- course reversal, where the mean vanishes: abeam on the inbound course).
case("the turn's bisector", function()
    local past = afds.past_turn_bisector or function() return nil end
    local function at(dist_nm, bearing_deg)
        return dist_nm * math.sin(math.rad(bearing_deg)), dist_nm * math.cos(math.rad(bearing_deg))
    end
    -- straight, north: before and after abeam
    check(past(0.2, -0.3, 0, 0) == false, "straight: 0.3 nm before the fix")
    check(past(-0.2, 0.05, 0, 0) == true, "straight: 0.05 nm past the fix")
    -- 90 deg right (000 then 090): the bisector runs NW-SE through the fix
    local e, n = at(1.0, 180)                      -- on the inbound leg 1 nm before
    check(past(e, n, 0, 90) == false, "90 right: 1 nm before the fix on the inbound leg")
    e, n = at(0.5, 90)                             -- on the outbound leg 0.5 nm after
    check(past(e, n, 0, 90) == true, "90 right: 0.5 nm along the outbound leg")
    -- the fly-by arc's middle (radius 2 nm, lead 2 nm) is on the bisector 0.83 nm SE of the fix
    e, n = at(0.75, 135)
    check(past(e - 0.05, n - 0.05, 0, 90) == false, "90 right: on the arc, short of the bisector")
    check(past(e + 0.05, n + 0.05, 0, 90) == true, "90 right: on the arc, past the bisector")
    -- 65 deg right as at NIRSI (inbound 025, outbound 090)
    e, n = at(1.9, 205)                            -- the turn's start, 1.9 nm before
    check(past(e, n, 25, 90) == false, "65 right: the turn's start 1.9 nm before")
    e, n = at(0.6, 90)
    check(past(e, n, 25, 90) == true, "65 right: 0.6 nm along the outbound leg")
    -- 137 deg right as at BILTO (000 then 137): 31 nm before is not past
    e, n = at(31, 180)
    check(past(e, n, 0, 137) == false, "137 right: 31 nm before")
    e, n = at(5, 137)
    check(past(e, n, 0, 137) == true, "137 right: 5 nm along the outbound leg")
    -- a reversal (000 then 180): abeam on the inbound course
    check(past(0.3, -0.2, 0, 180) == false, "reversal: short of abeam")
    check(past(0.3, 0.2, 0, 180) == true, "reversal: past abeam")
    -- left turns are the mirror image
    e, n = at(1.0, 180)
    check(past(e, n, 0, 270) == false, "90 left: 1 nm before")
    e, n = at(0.5, 270)
    check(past(e, n, 0, 270) == true, "90 left: 0.5 nm along the outbound leg")
end)

-- 2. LNAV and VNAV_NEXT_ALT together, as one XTLua namespace.
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
local function new_runtime()
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    for _, chunk in ipairs({
            slice(AP.."B747.70.xt.autopilot.lua", "function B747_rescale(", "function getFMSData(name)"),
            slice(AP.."B747.70.xt.autopilot.lua", "function getTriSpaceSolver(ab,ac,cb)", "local beganDescentAny"),
            slice(AP.."B747.70.xt.autopilot.lua", "function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice(AP.."B747.70.xt.autopilot.lua", "function movePoint(", "\nend\n").."\nend\n",
            slice(AP.."B747.70.xt.autopilot.lua", "function B747_getCurrentWayPoint(fmsO)", "local LNAV_MAX_PREEMPT_XTK_NM"),
            slice(AP.."B747.70.xt.autopilot.lua", "local LNAV_MAX_PREEMPT_XTK_NM", "function B747_ap_altitude(fms)"),
            slice(AP.."B747.70.xt.autopilot.monitor.lua", "function VNAV_NEXT_ALT(numAPengaged,fms)",
                "function VNAV_CLB_ALT(numAPengaged,fms)")}) do
        setfenv(assert(loadstring(chunk)), env)()
    end
    -- 233 KIAS at 5,800 ft: 255 kt TAS, no wind
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot, env.simDR_onGround = 5850, 5800, -1000, 0
    env.simDR_groundspeed, env.simDR_TAS_mps = 131, 131
    env.simDR_true_heading, env.simDR_ground_track_true = 90, 90
    env.simDR_autopilot_bank_limit, env.simDR_autopilot_bank_angles = 4, {[0] = 5, 10, 15, 20, 25, 30}
    env.B747DR_ap_lnav_state, env.B747DR_ap_approach_mode = 2, 0
    env.B747DR_ap_lnav_xtk_target, env.B747DR_ap_lnav_xtk_error = 0, 0
    env.B747DR_CAS_caution_status, env.simDR_override_fms_progress = {}, 1
    env.setVNAVState = function() end
    -- descending: past the T/D (the route to go less than the T/D's distance)
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 30, 100, 2
    env.B747BR_cruiseAlt, env.simDR_autopilot_altitude_ft = 37000, 5563
    env.B747DR_fmstargetDistance, env.B747DR_ap_vnav_target_alt = 0, 0
    env.getFMSData = function(key)
        if key == "transalt" then return "18000" end
        return ""
    end
    return env
end

-- EHAM ILS 18R via SUG1D with the native FMS's VNAV altitudes ([9]).
local function eham()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("SUGOL", 52.525511, 3.96735, 11315),
        entry("NETOM", 52.422444, 4.387917, 7849), entry("NIRSI", 52.583878, 4.513372, 5563),
        entry("AM607", 52.583889, 4.646889, 4272), entry("AM608", 52.539417, 4.728139, 3400),
        entry("AM621", 52.462694, 4.721111, 2000), entry("AM622", 52.426722, 4.717806, 1310),
        entry("RW18R", 52.360258, 4.711725, 37), entry("EHAM", 52.3175, 4.7716, -11, 1)}
end
local NIRSI, AM607 = 4, 5
-- The same with NIRSI's leg flown direct to it (from VECTORS where NETOM is), its turn sequenced at the lead.
local function eham_direct()
    local route = eham()
    route[3][8] = "VECTORS"
    return route
end
local geo = new_runtime()
local ROUTE = eham()
local inbound = geo.getHeading(ROUTE[3][5], ROUTE[3][6], ROUTE[NIRSI][5], ROUTE[NIRSI][6])
local outbound = geo.getHeading(ROUTE[NIRSI][5], ROUTE[NIRSI][6], ROUTE[AM607][5], ROUTE[AM607][6])
-- dist_nm from NIRSI on the bearing
local function from_nirsi(dist_nm, bearing_deg)
    return geo.movePoint(ROUTE[NIRSI][5], ROUTE[NIRSI][6], dist_nm, bearing_deg % 360)
end

-- One frame: LNAV, X-Plane following the 747's active fix ([10]) and VNAV's
-- target. The aircraft at (lat, lon), on the track it flies.
local function frame(env, route, lat, lon, track)
    env.simDR_latitude, env.simDR_longitude = lat, lon
    env.simDR_true_heading, env.simDR_ground_track_true = track, track
    env.B747_getCurrentWayPoint(route)
    for i = 1, #route do route[i][10] = (i == env.B747DR_fmscurrentIndex) end
    return env.VNAV_NEXT_ALT(1, route)
end
local function start_on_leg(env, route, index)
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = index, index, index
    for i = 1, #route do route[i][10] = (i == index) end
end

-- 2a. NIRSI: before the turn, after LNAV made AM607 active, past the bisector.
case("NIRSI's turn", function()
    local env, route = new_runtime(), eham_direct()
    start_on_leg(env, route, NIRSI)
    local lat, lon = from_nirsi(4, inbound + 180)
    local target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == NIRSI and target == 5563, "4 nm before NIRSI: NIRSI active, VNAV target 5563, got "
        ..tostring(env.B747DR_fmscurrentIndex).." "..tostring(target))
    lat, lon = from_nirsi(1.6, inbound + 180)
    target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == AM607, "1.6 nm before NIRSI (its 65 deg turn's lead is 1.9 nm): AM607 active, got "
        ..tostring(env.B747DR_fmscurrentIndex))
    check(target == 5563, "1.6 nm before NIRSI with AM607 active: the target stays NIRSI's 5563, got "..tostring(target))
    check(env.B747DR_vnav_hold_index == NIRSI, "the hold is on NIRSI, got "..tostring(env.B747DR_vnav_hold_index))
    -- on the turn: 0.5 nm before NIRSI, 0.15 nm inside
    lat, lon = from_nirsi(0.5, inbound + 180)
    lat, lon = geo.movePoint(lat, lon, 0.15, (inbound + 90) % 360)
    target = frame(env, route, lat, lon, (inbound + 30) % 360)
    check(target == 5563, "in the turn short of the bisector: still 5563, got "..tostring(target))
    -- past the bisector, on the outbound leg 0.4 nm after NIRSI
    lat, lon = from_nirsi(0.4, outbound)
    target = frame(env, route, lat, lon, outbound)
    check(env.B747DR_vnav_hold_index == 0, "past the bisector: no hold, got "..tostring(env.B747DR_vnav_hold_index))
    check(target == 4272, "past the bisector: AM607's 4272, got "..tostring(target))
end)

-- 2b. Already below the passed fix's altitude: no hold above the aircraft
-- (the dial would be behind it).
case("below the passed fix", function()
    local env, route = new_runtime(), eham_direct()
    start_on_leg(env, route, NIRSI)
    env.simDR_pressureAlt1 = 5300
    local lat, lon = from_nirsi(4, inbound + 180)
    frame(env, route, lat, lon, inbound)
    lat, lon = from_nirsi(1.6, inbound + 180)
    local target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == AM607 and target == 4272,
        "5300 ft (below NIRSI's 5563) after the switch: AM607's 4272, got "..tostring(target))
end)

-- 2c. In the climb the target is not the passed fix's (VNAV's climb targets
-- are unchanged).
case("climb", function()
    local env, route = new_runtime(), eham_direct()
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 300, 100, 0
    env.simDR_pressureAlt1, env.simDR_autopilot_altitude_ft = 5850, 37000
    start_on_leg(env, route, NIRSI)
    local lat, lon = from_nirsi(4, inbound + 180)
    local before = frame(env, route, lat, lon, inbound)
    lat, lon = from_nirsi(1.6, inbound + 180)
    local target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == AM607, "climb: AM607 active after the switch")
    check(target ~= 5563, "climb: the passed NIRSI is no climb target, got "..tostring(target)
        .." (before "..tostring(before)..")")
end)

-- 2d. A jump of the active fix (a direct-to, a new route): no hold. The
-- bookkeeping alone, without LNAV's own sequencing.
case("a jump", function()
    local env, route = new_runtime(), eham()
    env.simDR_latitude, env.simDR_longitude = from_nirsi(1.6, inbound + 180)
    env.B747DR_fmscurrentIndex = NIRSI
    env.B747_lnav_update_vnav_hold(route)
    env.B747DR_fmscurrentIndex = 6                                      -- direct to AM608
    env.B747_lnav_update_vnav_hold(route)
    check(env.B747DR_vnav_hold_index == 0, "a jump from NIRSI to AM608: no hold, got "..tostring(env.B747DR_vnav_hold_index))
    env.B747DR_fmscurrentIndex = 7
    env.B747_lnav_update_vnav_hold(route)
    check(env.B747DR_vnav_hold_index == 0, "then on to AM621 far from AM608: no hold, got "
        ..tostring(env.B747DR_vnav_hold_index))
end)

-- 2e. Sequenced at the fix (no turn to anticipate): no hold once abeam.
case("a straight fix", function()
    local env, route = new_runtime(), eham()
    -- NIRSI made a straight fix: AM607 on NETOM-NIRSI's extension
    route[AM607][5], route[AM607][6] = from_nirsi(5, inbound)
    start_on_leg(env, route, NIRSI)
    local lat, lon = from_nirsi(0.3, inbound + 180)
    frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == NIRSI, "straight NIRSI 0.3 nm before: still NIRSI")
    lat, lon = from_nirsi(0.1, inbound)
    frame(env, route, lat, lon, inbound)
    check(env.B747DR_vnav_hold_index == 0, "straight NIRSI passed: no hold, got "..tostring(env.B747DR_vnav_hold_index))
end)

-- 2f. Far from the held fix without crossing its bisector (vectored away): the
-- hold ends.
case("vectored away", function()
    local env, route = new_runtime(), eham_direct()
    start_on_leg(env, route, NIRSI)
    local lat, lon = from_nirsi(4, inbound + 180)
    frame(env, route, lat, lon, inbound)
    lat, lon = from_nirsi(1.6, inbound + 180)
    frame(env, route, lat, lon, inbound)
    check(env.B747DR_vnav_hold_index == NIRSI, "vectored: held after the switch")
    lat, lon = from_nirsi(15, inbound + 250)
    env.B747DR_ap_lnav_state = 0                                        -- HDG SEL, no LNAV
    frame(env, route, lat, lon, (inbound + 250) % 360)
    check(env.B747DR_vnav_hold_index == 0, "15 nm away short of the bisector: no hold, got "
        ..tostring(env.B747DR_vnav_hold_index))
end)

-- 2g. The passed entry is an altitude leg's end ("(5600)") or the departure
-- airport: no hold. The bookkeeping alone.
for _, passed in ipairs({{"(5600)", 2048, NIRSI}, {"EIDW", 1, 1}}) do
    case("passed "..passed[1], function()
        local env, route = new_runtime(), eham()
        local k = passed[3]
        route[k][8], route[k][2] = passed[1], passed[2]
        env.simDR_latitude, env.simDR_longitude = geo.movePoint(route[k + 1][5], route[k + 1][6], 30, 270)
        env.B747DR_fmscurrentIndex = k
        env.B747_lnav_update_vnav_hold(route)
        env.B747DR_fmscurrentIndex = k + 1
        env.B747_lnav_update_vnav_hold(route)
        check(env.B747DR_vnav_hold_index == 0, passed[1].." passed: no hold, got "..tostring(env.B747DR_vnav_hold_index))
    end)
end
-- and a fix passed while a hold was on: the hold moves to it (NIRSI then AM607
-- sequenced early in a row)
case("two in a row", function()
    local env, route = new_runtime(), eham()
    env.simDR_latitude, env.simDR_longitude = geo.movePoint(route[AM607][5], route[AM607][6], 1.0, 270)
    env.B747DR_fmscurrentIndex = NIRSI
    env.B747_lnav_update_vnav_hold(route)
    env.B747DR_fmscurrentIndex = AM607
    env.B747_lnav_update_vnav_hold(route)
    env.B747DR_fmscurrentIndex = AM607 + 1
    env.B747_lnav_update_vnav_hold(route)
    check(env.B747DR_vnav_hold_index == AM607, "AM607 sequenced 1 nm before it: the hold is on AM607, got "
        ..tostring(env.B747DR_vnav_hold_index))
end)

-- 3. NIRSI's turn flown by its path (SUG1D as it is): sequenced at the bisector, NIRSI VNAV's fix until
-- there without a hold (the arc of R 2.6 nm starts 1.65 nm before NIRSI, its middle 0.5 nm from it).
case("NIRSI's turn flown by its path", function()
    local env, route = new_runtime(), eham()
    start_on_leg(env, route, NIRSI)
    local lat, lon = from_nirsi(4, inbound + 180)
    local target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == NIRSI and target == 5563, "path: 4 nm before NIRSI: NIRSI, 5563, got "
        ..tostring(env.B747DR_fmscurrentIndex).." "..tostring(target))
    lat, lon = from_nirsi(1.6, inbound + 180)
    target = frame(env, route, lat, lon, inbound)
    check(env.B747DR_fmscurrentIndex == NIRSI and target == 5563,
        "path: 1.6 nm before NIRSI, at its arc's start: still NIRSI, 5563, got "
        ..tostring(env.B747DR_fmscurrentIndex).." "..tostring(target))
    check(env.B747DR_vnav_hold_index == 0, "path: no hold, got "..tostring(env.B747DR_vnav_hold_index))
    lat, lon = from_nirsi(0.6, inbound + 180)
    lat, lon = geo.movePoint(lat, lon, 0.12, (inbound + 90) % 360)
    target = frame(env, route, lat, lon, (inbound + 25) % 360)
    check(env.B747DR_fmscurrentIndex == NIRSI and target == 5563, "path: on the arc short of the bisector: NIRSI, 5563, got "
        ..tostring(env.B747DR_fmscurrentIndex).." "..tostring(target))
    lat, lon = from_nirsi(0.4, outbound)
    target = frame(env, route, lat, lon, outbound)
    check(env.B747DR_fmscurrentIndex == AM607 and env.B747DR_vnav_hold_index == 0 and target == 4272,
        "path: past the bisector: AM607, no hold, 4272, got "..tostring(env.B747DR_fmscurrentIndex).." "
        ..tostring(env.B747DR_vnav_hold_index).." "..tostring(target))
end)

if #failures > 0 then
    error(string.format("vnav_turn_hold_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_turn_hold_test: %d checks passed", checks))
