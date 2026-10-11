-- Run from the repository root with Lua 5.1 or LuaJIT.
-- End of descent, remaining distance, T/D and the VNAV descent path on routes
-- that start and end at the same airport, and the VNAV climb target on them;
-- the T/D from the descent constraints and the end of descent altitude, and
-- the remaining distance without the leg after the end of descent.
-- Production setDistances and VNAV_NEXT_ALT run against mocked datarefs; this
-- does not validate flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local json = dofile(AP.."json/json.lua")

local checks = 0
local failures = {}
local function check(condition, message)
    checks = checks + 1
    if not condition then error(message, 0) end
end
local function equal(actual, expected, message)
    check(actual == expected, message..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function near(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": expected "..tostring(expected).." +/- "..tostring(tolerance)
        ..", got "..tostring(actual))
end
-- Run every scenario and report all of them, so one failure does not hide the rest.
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then failures[#failures + 1] = name..": "..tostring(err) end
end

local sources = {}
local function load_in(path, runtime, first_marker, last_marker)
    if sources[path] == nil then
        local file = assert(io.open(path))
        sources[path] = file:read("*a")
        file:close()
    end
    local source = sources[path]
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    setfenv(assert(loadstring(source:sub(first, last - 1), "@"..path)), runtime)()
end

-- Load getDistance, setDistances and VNAV_NEXT_ALT into one namespace, as the
-- autopilot and its monitor share one XTLua namespace in the aircraft.
local function new_runtime(route, lat, lon, current_index)
    local r = setmetatable({
        print = function() end,
        json = json,
        -- Production keeps this as a local at autopilot.lua:553, outside the slice.
        B747_afds_helpers = afds,
        B747BR_cruiseAlt = 35000, B747DR_ap_flightPhase = 2, simDR_pressureAlt1 = 35000,
        simDR_groundspeed = 0, B744_fpm = 0,
        B747BR_totalDistance = 0, B747BR_tod = 0, B747BR_toc = 0,
        B747BR_todLat = 0, B747BR_todLong = 0, B747BR_tocLat = 0, B747BR_tocLong = 0,
        B747BR_distance_to_dest = 0, B747BR_eod_index = 0, B747BR_nextDistanceInFeet = 0,
        B747BR_fpe = 0, B747BR_vnavProfile = "",
        simDR_latitude = lat, simDR_longitude = lon, B747DR_fmscurrentIndex = current_index,
        B747DR_ap_inVNAVdescent = 0, simDR_autopilot_altitude_ft = 35000,
        B747DR_fmstargetDistance = 0, B747DR_ap_vnav_target_alt = 0,
        getFMSData = function(key)
            if key == "transalt" then return "18000" end
            return ""
        end
    }, {__index = _G})
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function getDistance(lat1, lon1, lat2, lon2)", "function movePoint(")
    load_in(AP.."B747.70.xt.autopilot.lua", r,
        "function setDistances(fmsO)", "----- ALTITUDE SELECTED")
    load_in(AP.."B747.70.xt.autopilot.monitor.lua", r,
        "function VNAV_NEXT_ALT(numAPengaged,fms)", "function VNAV_CLB_ALT(numAPengaged,fms)")
    for i = 1, #route do route[i][10] = (i == current_index) end
    r.route = route
    return r
end

-- The production great-circle distance, for the helper cases below.
local geo = setmetatable({}, {__index = _G})
load_in(AP.."B747.70.xt.autopilot.lua", geo,
    "function getDistance(lat1, lon1, lat2, lon2)", "function movePoint(")
local distance_nm = geo.getDistance

-- One xtlua/fms entry: [2] type (1 = airport), [3] the field the T/D formula
-- reads, [5]/[6] position, [8] name, [9] altitude, [10] active leg.
local function fix(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end

-- Depart ORIG eastbound, fly a 3 x 3 degree box and return to ORIG from the
-- north, as a training circuit out of and back into the same airport does.
local function circuit(route_alt, approach_alts)
    local iaf, faf = 3000, 2000
    if approach_alts == false then iaf, faf = 0, 0 end
    return {
        fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("DEP1", 1, 1.1),
        fix("WPT1", 1, 4, route_alt), fix("WPT2", 4, 4, route_alt), fix("WPT3", 4, 1, route_alt),
        fix("IAF", 1.25, 1, iaf), fix("FAF", 1.1, 1, faf), fix("RW18", 1.01, 1),
        fix("ORIG", 1, 1, 0, 1)
    }
end

-- An ordinary A to B route along one parallel.
local function normal(route_alt)
    return {
        fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("WPT1", 1, 3.5, route_alt),
        fix("IAF", 1, 5.75, 3000), fix("FAF", 1, 5.9, 2000), fix("RW27", 1, 5.99),
        fix("DEST", 1, 6, 0, 1)
    }
end

-- setDistances places the T/D from the previous call's distance and T/D, so
-- the aircraft calls it every frame; two calls settle a fresh namespace.
local function settle(r)
    r.setDistances(r.route)
    r.setDistances(r.route)
end

local function profile_point(r, lat, lon, alt)
    local profile = json.decode(r.B747BR_vnavProfile)
    for i = 1, #profile do
        local point = profile[i]
        if point[1] == lat and point[2] == lon and point[3] == alt then return point end
    end
    return nil
end

-- The descent into the IAF must start at the T/D from CRZ ALT, whatever the
-- route altitude in [9] says. With the T/D taken from the IAF itself, the
-- path into it is the planned 290 ft/nm (319 ft/nm while the T/D came from
-- the destination alone and the leg after the end of descent).
local function check_iaf_path(r, label)
    local iaf = profile_point(r, 1.25, 1, 3000)
    check(iaf ~= nil, label..": IAF 3000 is in the VNAV profile "..r.B747BR_vnavProfile)
    equal(iaf[4], true, label..": IAF is still ahead")
    near(iaf[5], 290, 0.5, label..": IAF path gradient ft/nm")
    local from_tod = r.getDistance(r.B747BR_todLat, r.B747BR_todLong, 1.25, 1)
    near(iaf[5] * from_tod + 3000, 35000, 5, label..": path altitude at the T/D")
end

-- Distance along a list of {lat, lon} points.
local function along(points)
    local total = 0
    for i = 1, #points - 1 do
        total = total + distance_nm(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2])
    end
    return total
end

-- T/D of both fixtures at CRZ ALT 35000: the IAF at 3000 ft, 9 + 6 NM before
-- the destination, at 290 ft/nm.
local CIRCUIT_TOD = along({{1.25, 1}, {1.1, 1}, {1, 1}}) + 32000 / 290   -- 125.35
local NORMAL_TOD = along({{1, 5.75}, {1, 5.9}, {1, 6}}) + 32000 / 290     -- 125.35

-- The rule setDistances used before: the first entry within 10 NM of the
-- destination, or the destination itself.
local function first_within_10nm(route)
    local dest = route[#route]
    for i = 1, #route - 1 do
        if distance_nm(route[i][5], route[i][6], dest[5], dest[6]) < 10 then return i end
    end
    return #route
end

-- [c-1] EOD, remaining distance and T/D
-- (distances and T/D as measured since c-4: no leg after the end of descent,
-- and the T/D from the IAF)

case("circuit in cruise: EOD on the arrival side", function()
    local r = new_runtime(circuit(0), 2.5, 4, 5)
    settle(r)
    equal(r.B747BR_eod_index, 8, "EOD is the FAF, not the departure airport")
    near(r.B747BR_totalDistance, 449.86, 0.05, "remaining distance runs to the arrival")
    near(r.B747BR_tod, CIRCUIT_TOD, 0.01, "T/D distance")
    -- vnav.lua:157 of the FMS pages shows TO T/D when 0 < rem - T/D <= 200.
    check(r.B747BR_totalDistance - r.B747BR_tod > 200,
        "cruise STEP advisory stays clear of TO T/D: rem-T/D "
        ..(r.B747BR_totalDistance - r.B747BR_tod))
end)

case("circuit on the ground: VNAV climb branch available", function()
    local r = new_runtime(circuit(0), 1, 1, 3)
    settle(r)
    -- VNAV_modeSwitch climbs only while rem - T/D > 10 (monitor.lua:528).
    near(r.B747BR_totalDistance - r.B747BR_tod, 594.65, 0.1, "rem-T/D at brake release")
end)

case("circuit on final approach: EOD already passed", function()
    local r = new_runtime(circuit(0), 1.05, 1, 9)
    settle(r)
    equal(r.B747BR_eod_index, 8, "EOD stays the FAF")
    near(r.B747BR_totalDistance, 8.41, 0.05, "remaining distance on final")
end)

case("normal route: EOD unchanged", function()
    local r = new_runtime(normal(0), 1, 2, 3)
    settle(r)
    equal(r.B747BR_eod_index, 5, "EOD is the FAF")
    near(r.B747BR_totalDistance, 240.12, 0.05, "remaining distance")
    near(r.B747BR_tod, NORMAL_TOD, 0.01, "T/D distance")
end)

case("route_eod_index: whole route inside 10 NM", function()
    -- FINL after BASE (the farthest fix) is inside 10 NM too, so only the
    -- whole-route rule keeps the airport as the EOD here.
    local pattern = {
        fix("ORIG", 1, 1, 0, 1), fix("RW27", 1, 1.01), fix("XWND", 1.05, 0.98),
        fix("DWND", 1.05, 1.05), fix("BASE", 1, 1.08), fix("FINL", 1, 1.03),
        fix("ORIG", 1, 1, 0, 1)
    }
    equal(afds.route_eod_index(pattern, distance_nm, 10), #pattern,
        "a traffic pattern has no arrival point before the airport")
end)

case("route_eod_index: SID back over the airfield", function()
    local route = circuit(0)
    table.insert(route, 4, fix("OVHD", 1.02, 1))
    equal(afds.route_eod_index(route, distance_nm, 10), 9,
        "the overhead fix 1.2 NM from the airport is not the EOD")
end)

case("route_eod_index: distant T-P first", function()
    local route = {
        fix("T-P", 1.3, 1.3, 0, 2048), fix("OVHD", 1.02, 1), fix("WPT1", 1, 4),
        fix("WPT2", 4, 4), fix("WPT3", 4, 1), fix("IAF", 1.25, 1, 3000),
        fix("FAF", 1.1, 1, 2000), fix("RW18", 1.01, 1), fix("ORIG", 1, 1, 0, 1)
    }
    equal(afds.route_eod_index(route, distance_nm, 10), 7,
        "EOD found without a departure airport at the start")
end)

-- The missed approach after the arrival runway: X-Plane ends its vectors leg
-- ("(VECT)", EHAM ILS 18R's missed approach on 299 deg after AM624) about
-- 640 NM away (2026-10-10, EIDW to EHAM: the 747's remaining distance 1,732 NM
-- for a 440 NM route, its T/D about 1,300 NM late). That point is no route's
-- farthest point, and the EOD stays before the runway.
local function with_far_missed_approach()
    return {
        fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("WPT1", 1, 3.5),
        fix("IAF", 1, 5.75, 3000), fix("FAF", 1, 5.9, 2000), fix("RW27", 1, 5.99, 50),
        fix("(500)", 1, 6.02, 500, 2048), fix("MAP1", 1.1, 6.1, 2000), fix("(VECT)", 6, 15, 2000, 2048),
        fix("DEST", 1, 6, 0, 1)
    }
end

case("route_eod_index: a missed approach's distant vectors point", function()
    equal(afds.route_eod_index(with_far_missed_approach(), distance_nm, 10), 5,
        "the EOD is the FAF, as without the missed approach")
end)

case("setDistances: a missed approach's distant vectors point", function()
    local r = new_runtime(with_far_missed_approach(), 1, 2, 3)
    settle(r)
    local plain = new_runtime(normal(0), 1, 2, 3)
    settle(plain)
    equal(r.B747BR_eod_index, 5, "EOD is the FAF")
    near(r.B747BR_totalDistance, plain.B747BR_totalDistance, 0.05,
        "remaining distance as on the same route without the missed approach")
end)

case("route_eod_index: a SID's runway on a route back without an approach", function()
    -- the departure runway is near the destination too, but nothing of the route
    -- lies before it: the EOD is still found after the farthest point
    local route = circuit(0)
    table.remove(route, 9)      -- no arrival runway
    equal(afds.route_eod_index(route, distance_nm, 10), 8, "EOD is the FAF")
end)

case("route_eod_index: normal routes keep the old EOD", function()
    local routes = {
        {normal(0), 5},
        {normal(31000), 5},
        {{fix("ORIG", 1, 1, 0, 1), fix("WPT1", 1, 3), fix("DEST", 1, 6, 0, 1)}, 3},
        {{fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("WPT1", 2, 3),
            fix("IAF", 1, 5.75, 3000), fix("RW27", 1, 5.99), fix("MAP1", 1, 6.3),
            fix("MAP2", 1.2, 6.1), fix("DEST", 1, 6, 0, 1)}, 5},
        {{fix("ORIG", 5, 5, 0, 1), fix("WPT1", 4, 3), fix("WPT2", 2, 2),
            fix("FAF", 1.08, 1.02, 2000), fix("DEST", 1, 1, 0, 1)}, 4}
    }
    for i = 1, #routes do
        local route, expected = routes[i][1], routes[i][2]
        equal(first_within_10nm(route), expected, "old rule on normal route "..i)
        equal(afds.route_eod_index(route, distance_nm, 10), expected, "normal route "..i)
    end
end)

-- [c-2] VNAV descent path into the first descent constraint

case("circuit in cruise: IAF path, route altitude 0", function()
    local r = new_runtime(circuit(0), 2.5, 4, 5)
    settle(r)
    check_iaf_path(r, "route [9]=0")
end)

case("circuit in cruise: IAF path, route altitude 31000", function()
    local r = new_runtime(circuit(31000), 2.5, 4, 5)
    settle(r)
    check_iaf_path(r, "route [9]=31000")
end)

-- The T/D on the leg to the active fix belongs to that fix, not to a passed
-- entry that still carries a route altitude.
case("circuit, IAF active with the T/D 25 NM ahead, route altitude 31000", function()
    local r = new_runtime(circuit(31000), 3.5, 1, 7)
    settle(r)
    near(r.getDistance(3.5, 1, r.B747BR_todLat, r.B747BR_todLong), 24.74, 0.5, "T/D ahead")
    check_iaf_path(r, "route [9]=31000, IAF active")
end)

case("circuit, IAF active, route altitude 0, before and past the T/D", function()
    local r = new_runtime(circuit(0), 3.5, 1, 7)
    settle(r)
    check_iaf_path(r, "route [9]=0, IAF active")
    -- Past the T/D the frame no longer sets it, but the stored T/D still
    -- anchors the path into the first constraint.
    r.simDR_latitude = 2.7
    r.B747BR_totalDistance = r.B747BR_tod - 5
    r.setDistances(r.route)
    check_iaf_path(r, "route [9]=0, past the T/D")
end)

-- The route altitude does not change the path into the IAF.
case("normal route: IAF path", function()
    for _, route_alt in ipairs({0, 31000, 35000}) do
        local r = new_runtime(normal(route_alt), 1, 2, 3)
        settle(r)
        local iaf = profile_point(r, 1, 5.75, 3000)
        check(iaf ~= nil, "IAF in profile "..r.B747BR_vnavProfile)
        near(iaf[5], 290, 0.5, "normal route [9]="..route_alt.." IAF gradient")
    end
end)

case("vnav_entry_slope", function()
    local slope, alt = afds.vnav_entry_slope(-9999, 3000, 165.1, false, 35000)
    equal(slope, 0, "no gradient from an unset previous altitude")
    equal(alt, 3000, "unset previous altitude keeps the constraint")
    slope, alt = afds.vnav_entry_slope(5000, 3000, 0.05, false, 35000)
    equal(slope, 0, "no gradient over 0.05 NM")
    equal(alt, 5000, "0.05 NM keeps the previous altitude")
    slope, alt = afds.vnav_entry_slope(-9999, 3000, 0.05, true, 35000)
    equal(slope, 0, "no gradient over 0.05 NM from the T/D")
    equal(alt, 3000, "unset previous altitude is never a target")
    slope, alt = afds.vnav_entry_slope(5000, 3000, 100, false, 35000)
    near(slope, 20, 1e-9, "constraint to constraint")
    equal(alt, 3000, "constraint altitude")
    near(afds.vnav_entry_slope(-9999, 3000, 100, true, 35000), 320, 1e-9, "T/D from CRZ ALT")
    near(afds.vnav_entry_slope(31000, 3000, 100, true, 35000), 320, 1e-9, "T/D above route alt")
    near(afds.vnav_entry_slope(37000, 3000, 100, true, 35000), 340, 1e-9, "higher route alt kept")
end)

-- [c-3] VNAV climb target along the route

-- After takeoff the arrival fixes are only about 20 NM away in a straight
-- line, but about 690 NM away along the route, beyond the T/D.
-- The climb cases start with a sim altitude target below CRZ ALT, so CRZ ALT
-- can only come from the along-route T/D check, not from a target left as is.
for _, approach_alts in ipairs({true, false}) do
    case("circuit climb: arrival fixes are not climb targets, IAF/FAF altitudes "
            ..tostring(approach_alts), function()
        local r = new_runtime(circuit(0, approach_alts), 1, 1.2, 4)
        r.simDR_autopilot_altitude_ft = 12000
        r.B747BR_totalDistance, r.B747BR_tod = 708.00, 125.35
        equal(r.VNAV_NEXT_ALT(1, r.route), 35000, "climb target")
    end)
end

case("circuit: setDistances gives the climb distance used above", function()
    local r = new_runtime(circuit(0), 1, 1.2, 4)
    settle(r)
    near(r.B747BR_totalDistance, 708.00, 0.05, "remaining distance after takeoff")
    near(r.B747BR_tod, 125.35, 0.01, "T/D distance after takeoff")
end)

case("normal route climb targets unchanged", function()
    local r = new_runtime(normal(0), 1, 1.2, 3)
    r.simDR_autopilot_altitude_ft = 12000
    settle(r)
    equal(r.VNAV_NEXT_ALT(1, r.route), 35000, "climb to CRZ ALT")

    local route = normal(0)
    table.insert(route, 3, fix("SID1", 1, 1.4))
    table.insert(route, 4, fix("SID2", 1, 1.6, 5000))
    r = new_runtime(route, 1, 1.2, 3)
    r.simDR_autopilot_altitude_ft = 12000
    settle(r)
    equal(r.VNAV_NEXT_ALT(1, r.route), 5000, "SID constraint after the active fix")
end)

-- A CA, VA or FA leg ends where its altitude is reached ("(650)" in the native
-- route, EIDW 28R ENDE3J): it is no altitude to level off at. At the 400 ft
-- hand-off with the runway's end still the active fix, VNAV took 650 ft as its
-- climb target (route_integrity's WARN on the 2026-10-10 line flight).
case("SID: an altitude leg's end is no climb target", function()
    local route = normal(0)
    table.insert(route, 3, fix("(650)", 1, 1.03, 650, 2048))
    local r = new_runtime(route, 1, 1.015, 2)
    r.simDR_pressureAlt1, r.simDR_autopilot_altitude_ft = 640, 35000
    settle(r)
    equal(r.VNAV_NEXT_ALT(1, r.route), 35000, "climb to CRZ ALT past the CA leg's 650 ft")

    table.insert(route, 4, fix("SID2", 1, 1.6, 5000))
    r = new_runtime(route, 1, 1.015, 2)
    r.simDR_pressureAlt1, r.simDR_autopilot_altitude_ft = 640, 35000
    settle(r)
    equal(r.VNAV_NEXT_ALT(1, r.route), 5000, "the SID constraint after the CA leg")
end)

-- On a route back to the departure airport the fix after the CA leg is within
-- 10 NM of the destination: an entry without an altitude is no climb target
-- (it gave 0 ft, which VNAV_CLB_ALT writes to the AP altitude).
case("circuit SID: a departure fix without an altitude is no climb target", function()
    local route = circuit(0)
    table.insert(route, 3, fix("(650)", 1, 1.03, 650, 2048))
    local r = new_runtime(route, 1, 1.015, 2)
    r.simDR_pressureAlt1, r.simDR_autopilot_altitude_ft = 640, 35000
    settle(r)
    equal(r.VNAV_NEXT_ALT(1, r.route), 35000, "climb to CRZ ALT past the CA leg and DEP1")
end)

case("circuit descent: next descent constraint unchanged", function()
    local r = new_runtime(circuit(0), 4, 1.5, 6)
    r.B747BR_totalDistance, r.B747BR_tod = 100, 120.69
    r.B747DR_ap_inVNAVdescent = 1
    equal(r.VNAV_NEXT_ALT(1, r.route), 3000, "descent target is the IAF")
end)

-- [c-4] T/D from the descent constraints, end of descent altitude, and the
-- remaining distance without the leg after the end of descent

-- The T/D was (CRZ ALT - [3] of the end of descent) / 290 before the
-- destination: it ignored the descent constraints and read [3], which is a
-- frequency on a navaid. Now each descent constraint must be reached at
-- 290 ft/nm from CRZ ALT, and the end of descent altitude is its route
-- altitude, or the destination elevation.
case("normal route: T/D from the IAF 15 NM before the destination", function()
    local r = new_runtime(normal(0), 1, 2, 3)
    settle(r)
    check(r.B747BR_tod >= 15 + 32000 / 290, "T/D reaches 3000 ft at the IAF: "..r.B747BR_tod)
    near(r.B747BR_tod, NORMAL_TOD, 0.01, "T/D distance")
end)

-- ORIG, RW09, WPT1, a VOR 9 NM before the destination as the end of descent,
-- RW27 and DEST; no altitude constraints.
local function vor_route(vor_alt, dest_elevation)
    local route = {
        fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("WPT1", 1, 3.5),
        fix("VOR", 1, 5.85, vor_alt, 4), fix("RW27", 1, 5.99), fix("DEST", 1, 6, dest_elevation, 1)
    }
    route[4][3] = 11330   -- 113.30 MHz, not an altitude
    return route
end

case("end of descent at a VOR: [3] is not its altitude", function()
    local r = new_runtime(vor_route(0, 0), 1, 2, 3)
    settle(r)
    equal(r.B747BR_eod_index, 4, "EOD is the VOR")
    near(r.B747BR_tod, 35000 / 290, 0.01, "T/D to the destination elevation 0")

    r = new_runtime(vor_route(0, 1000), 1, 2, 3)
    settle(r)
    near(r.B747BR_tod, 34000 / 290, 0.01, "T/D to the destination elevation 1000 ft")

    r = new_runtime(vor_route(3000, 0), 1, 2, 3)
    settle(r)
    near(r.B747BR_tod, along({{1, 5.85}, {1, 6}}) + 32000 / 290, 0.01,
        "T/D to the EOD route altitude 3000 ft at the VOR")

    -- CRZ ALT only 1,500 ft above the EOD altitude: 5.2 NM from the destination
    -- would put the T/D after the VOR 9 NM out
    r = new_runtime(vor_route(2000, 0), 1, 2, 3)
    r.B747BR_cruiseAlt = 3500
    settle(r)
    near(r.B747BR_tod, along({{1, 5.85}, {1, 6}}) + 1500 / 290, 0.01,
        "T/D before the VOR with CRZ ALT 3500 ft")
end)

case("remaining distance ends at the end of descent and the destination", function()
    local r = new_runtime(normal(0), 1, 2, 3)
    settle(r)
    -- WPT1, IAF and FAF (the EOD), then straight to DEST; not FAF-RW27 as well
    near(r.B747BR_totalDistance, along({{1, 2}, {1, 3.5}, {1, 5.75}, {1, 5.9}, {1, 6}}), 0.01,
        "normal route remaining distance")
    r = new_runtime(circuit(0), 2.5, 4, 5)
    settle(r)
    near(r.B747BR_totalDistance, along({{2.5, 4}, {4, 4}, {4, 1}, {1.25, 1}, {1.1, 1}, {1, 1}}), 0.01,
        "circuit remaining distance")
end)

case("descent constraint farther out moves the T/D back", function()
    local route = normal(0)
    table.insert(route, 4, fix("STAR", 1, 4.33, 24000))
    local r = new_runtime(route, 1, 2, 3)
    settle(r)
    -- FL240 about 100 NM before the destination needs 11000 ft at 290 ft/nm
    near(r.B747BR_tod, along({{1, 4.33}, {1, 5.75}, {1, 5.9}, {1, 6}}) + 11000 / 290, 0.01,
        "T/D from the FL240 constraint")
end)

-- A route altitude before the T/D is cruise, not descent: the old CRZ ALT left
-- in [9] after a step climb must not bring the T/D forward to it.
case("route cruise altitude in [9] is not a descent constraint", function()
    local r = new_runtime(circuit(31000), 2.5, 4, 5)
    settle(r)
    near(r.B747BR_tod, CIRCUIT_TOD, 0.01, "circuit [9]=31000 T/D")
    r = new_runtime(normal(31000), 1, 2, 3)
    settle(r)
    near(r.B747BR_tod, NORMAL_TOD, 0.01, "normal route [9]=31000 T/D")
end)

-- A SID constraint is a climb constraint. On a 180 NM route the 5000 ft SID
-- fix lies within the T/D distance of the destination, but closer to the
-- departure; taken as a descent constraint it would put the T/D behind the
-- aircraft at brake release.
case("SID climb constraint is not a descent constraint", function()
    local route = {
        fix("ORIG", 1, 1, 0, 1), fix("RW09", 1, 1.01), fix("SID1", 1, 1.5),
        fix("SID2", 1, 2.17, 5000), fix("IAF", 1, 3.75, 3000), fix("FAF", 1, 3.9, 2000),
        fix("RW27", 1, 3.99), fix("DEST", 1, 4, 0, 1)
    }
    local r = new_runtime(route, 1, 1, 2)
    settle(r)
    equal(r.B747BR_eod_index, 6, "EOD is the FAF")
    near(r.B747BR_tod, along({{1, 3.75}, {1, 3.9}, {1, 4}}) + 32000 / 290, 0.01, "T/D from the IAF")
    check(r.B747BR_totalDistance - r.B747BR_tod > 10,
        "VNAV climb branch available at brake release: rem-T/D "
        ..(r.B747BR_totalDistance - r.B747BR_tod))

    route = normal(0)
    table.insert(route, 3, fix("SID1", 1, 1.4))
    table.insert(route, 4, fix("SID2", 1, 1.6, 5000))
    r = new_runtime(route, 1, 1, 2)
    settle(r)
    near(r.B747BR_tod, NORMAL_TOD, 0.01, "normal route with a SID constraint")
end)

-- Passed constraints still count: the aircraft is already below CRZ ALT
-- there, so dropping them would move the T/D after the aircraft and turn
-- rem - T/D positive in the descent (VNAV_modeSwitch climbs above 10 NM).
case("T/D does not move as the descent constraints are passed", function()
    local positions = {
        {"ground", 1, 1, 3}, {"cruise", 2.5, 4, 5}, {"IAF active", 3.5, 1, 7},
        {"FAF active", 1.2, 1, 8}, {"final", 1.05, 1, 9}
    }
    for i = 1, #positions do
        local p = positions[i]
        local r = new_runtime(circuit(0), p[2], p[3], p[4])
        settle(r)
        near(r.B747BR_tod, CIRCUIT_TOD, 0.01, p[1].." T/D")
    end
end)

case("route_tod_distance", function()
    -- returns the T/D distance and the end of descent altitude
    local tod, eod_alt = afds.route_tod_distance(vor_route(0, 1000), 4, 35000, distance_nm)
    near(tod, 34000 / 290, 1e-9, "T/D to the destination elevation")
    equal(eod_alt, 1000, "destination elevation")
    tod, eod_alt = afds.route_tod_distance(vor_route(3000, 1000), 4, 35000, distance_nm)
    equal(eod_alt, 3000, "EOD route altitude")
    -- a route altitude at or above CRZ ALT inside the descent is no constraint
    local route = normal(0)
    table.insert(route, 4, fix("HIGH", 1, 5, 36000))
    near(afds.route_tod_distance(route, 6, 35000, distance_nm), NORMAL_TOD, 1e-9, "36000 ft fix")
    -- no CRZ ALT: no T/D before the destination, as before
    check(afds.route_tod_distance(normal(0), 5, 0, distance_nm) <= 0, "no CRZ ALT")
    check(afds.route_tod_distance(vor_route(2000, 0), 4, 0, distance_nm) <= 0,
        "no CRZ ALT with an EOD route altitude 9 NM out")
end)

if #failures > 0 then
    for i = 1, #failures do io.stderr:write("FAIL "..failures[i].."\n") end
    error(#failures.." VNAV route EOD case(s) failed", 0)
end
print("VNAV route EOD tests passed: "..checks)
