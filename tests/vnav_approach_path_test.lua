-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV PTH in the approach flies the FMC's descent path to the runway: back
-- from the runway's threshold crossing altitude up the final approach angle to
-- the glide slope intercept, through the route altitudes of the fixes before,
-- never climbing, up to CRZ ALT at the T/D's 290 ft/nm; the path error is from
-- it and the V/S is its gradient at the ground speed corrected by the path
-- error. Before, within 15 NM of the end of descent the path error was from a
-- 290 ft/nm line to the airport's reference point and the V/S aimed at the
-- next fix's altitude and was left alone within 600 ft above the AP altitude:
-- p6-line1 (EHAM, 2026-10-16) climbed at +600 fpm to a passed fix's 3,400 ft,
-- p6-L1 (EINN) stayed at 3,450 ft, 450 ft above the 3,000 ft it was cleared to,
-- and both captured a false glide slope lobe.
-- The production helpers, setDescentVSpeed (through the XTLua dofile) and
-- setDistances run against mocked datarefs; this does not fly the aircraft
-- (approach_model_test.lua does).
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local json = dofile(AP.."json/json.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function near(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": expected "..tostring(expected).." +/- "..tostring(tolerance)..", got "..tostring(actual))
end
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

-- the production getDistance and movePoint, for the distances and positions along the routes below
local geo = setmetatable({}, {__index = _G})
setfenv(assert(loadstring(slice(AP.."B747.70.xt.autopilot.lua", "function getHeading(lat1, lon1, lat2, lon2)",
    "local lastILSUpdate = 0"))), geo)()
local getDistance = geo.getDistance

local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
-- EIDW -> EHAM, LAMS2A and ILS 18R via SUG1D, the native FMS's route altitudes (p6-line1)
local function eham()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("DIBAL", 52.797217, 2.5, 26309),
        entry("LAMSO", 52.732889, 2.994361, 21438), entry("ETPOS", 52.585122, 3.414178, 16752),
        entry("SUGOL", 52.525511, 3.96735, 11315), entry("NETOM", 52.422444, 4.387917, 7849),
        entry("NIRSI", 52.583878, 4.513372, 5563), entry("AM607", 52.583889, 4.646889, 4272),
        entry("AM608", 52.539417, 4.728139, 3400), entry("AM621", 52.462694, 4.721111, 2000),
        entry("AM622", 52.426722, 4.717806, 1310), entry("RW18R", 52.360258, 4.711725, 37),
        entry("EHAM", 52.317497, 4.771616, -11, 1)}
end
local NIRSI, AM607, AM608, AM621, AM622, RW18R = 7, 8, 9, 10, 11, 12
-- TST744L back to EINN, ILS 06 from ELPOM (BILTO -> ELPOM 92 deg left): ASGON's 3,046 ft is the glide slope
-- there, above ELPOM's 3,000
local function einn()
    return {entry("EINN", 52.701992, -8.924772, 41, 1), entry("EMPER", 49, -9, 31000),
        entry("BEDRA", 49, -15, 33000), entry("ETARI", 55.5, -15, 35000), entry("BILTO", 56.5, -15, 35000),
        entry("ELPOM", 52.560306, -9.224111, 3000), entry("ASGON", 52.598444, -9.143917, 3046),
        entry("RW06", 52.693172, -8.943519, 101), entry("EINN", 52.701992, -8.924772, 41, 1)}
end
local BILTO, ELPOM, ASGON, RW06 = 5, 6, 7, 8

-- distance along the route from entry i to entry j (i < j)
local function along(route, i, j)
    local d = 0
    for k = i, j - 1 do d = d + getDistance(route[k][5], route[k][6], route[k + 1][5], route[k + 1][6]) end
    return d
end
-- a point nm before entry j on the (great circle) leg from entry j - 1
local function before(route, j, nm)
    local a, b = route[j - 1], route[j]
    return geo.movePoint(b[5], b[6], nm, geo.getHeading(b[5], b[6], a[5], a[6]))
end
local GLIDE = math.tan(math.rad(3)) * 6076.12

-- 1. The arrival runway.
case("the arrival runway", function()
    check(afds.route_runway_index(eham(), getDistance, 10) == RW18R, "EHAM: RW18R")
    check(afds.route_runway_index(einn(), getDistance, 10) == RW06,
        "EINN back to EINN: RW06, not the departure end")
    -- a route back to the departure airport without an approach: its departure runway is no arrival runway
    local loop = {entry("EINN", 52.701992, -8.924772, 41, 1), entry("RW24", 52.7100, -8.9000, 41),
        entry("BILTO", 56.5, -15, 35000), entry("EINN", 52.701992, -8.924772, 41, 1)}
    check(afds.route_runway_index(loop, getDistance, 10) == nil, "no approach: no arrival runway")
end)

-- 2. The path: EHAM from AM607 (NIRSI before it), EINN from ELPOM (BILTO before it is cruise).
case("the path to RW18R", function()
    local route = eham()
    local points = afds.vnav_approach_path(route, RW18R, AM607, getDistance, 18000, 37000, 3.0)
    local expected = {{0, 37}, {along(route, AM622, RW18R), 1310}, {along(route, AM621, RW18R), 2000},
        {along(route, AM608, RW18R), 3400}, {along(route, AM607, RW18R), 4272}, {along(route, NIRSI, RW18R), 5563}}
    check(#points == #expected + 1, "the runway, AM622 (on the glide slope), AM621, AM608, AM607, NIRSI and the T/D: "
        ..#points.." points")
    for k, e in ipairs(expected) do
        near(points[k] and points[k].d, e[1], 0.001, "point "..k.." distance")
        near(points[k] and points[k].alt, e[2], 0.001, "point "..k.." altitude")
    end
    local tod = points[#points]
    near(tod.alt, 37000, 0.001, "the T/D at CRZ ALT")
    near(tod.d, along(route, NIRSI, RW18R) + (37000 - 5563) / 290, 0.001, "the T/D at 290 ft/nm from NIRSI")
    local alt, gradient = afds.vnav_path_at(points, 2.0)
    near(gradient, (1310 - 37) / along(route, AM622, RW18R), 0.01, "the final approach's gradient")
    near(alt, 37 + 2.0 * gradient, 0.01, "2 nm out")
    local d621 = along(route, AM621, RW18R)
    alt, gradient = afds.vnav_path_at(points, d621 + 1.0)
    near(gradient, 1400 / along(route, AM608, AM621), 0.01, "AM608 to AM621")
    near(alt, 2000 + gradient, 0.01, "1 nm before AM621")
end)
case("the path to RW06", function()
    local route = einn()
    local points = afds.vnav_approach_path(route, RW06, ELPOM, getDistance, 18000, 35000, 3.0)
    local d_asgon, d_elpom = along(route, ASGON, RW06), along(route, ELPOM, RW06)
    local intercept = (3000 - 101) / GLIDE
    check(#points == 5, "the runway, the intercept, ASGON, ELPOM and the T/D: "..#points.." points")
    near(points[2].d, intercept, 0.001, "the glide slope intercept at 3,000 ft")
    near(points[2].alt, 3000, 0.001, "the intercept altitude")
    near(points[3].d, d_asgon, 0.001, "ASGON")
    near(points[3].alt, 3000, 0.001, "ASGON no higher than ELPOM before it")
    near(points[4].alt, 3000, 0.001, "ELPOM")
    near(points[5].d, d_elpom + 32000 / 290, 0.001, "the T/D from ELPOM, BILTO being cruise")
    local alt, gradient = afds.vnav_path_at(points, (intercept + d_asgon) / 2)
    near(alt, 3000, 0.001, "level from ASGON to the intercept")
    near(gradient, 0, 0.001, "level: no gradient")
    alt, gradient = afds.vnav_path_at(points, 5)
    near(alt, 101 + 5 * GLIDE, 0.01, "on the 3 deg final 5 nm out")
    near(gradient, GLIDE, 0.01, "the 3 deg gradient")
    alt, gradient = afds.vnav_path_at(points, d_elpom + 7)
    near(alt, 3000 + 7 * 290, 0.01, "7 nm before ELPOM on the descent from the T/D")
    near(gradient, 290, 0.001, "the T/D's gradient")
    -- a 3.2 deg final from the CIFP meets 3,000 ft closer in; a 2.5 deg one only beyond ASGON, so the path
    -- goes straight from ASGON down to the runway
    points = afds.vnav_approach_path(route, RW06, ELPOM, getDistance, 18000, 35000, 3.2)
    near(points[2].d, (3000 - 101) / (math.tan(math.rad(3.2)) * 6076.12), 0.001, "a 3.2 deg final")
    points = afds.vnav_approach_path(route, RW06, ELPOM, getDistance, 18000, 35000, 2.5)
    near(points[2].d, d_asgon, 0.001, "a 2.5 deg final: no intercept before ASGON")
end)

-- 3. The V/S along the path.
case("the V/S along the path", function()
    near(afds.vnav_path_vspeed(304, 180, 0), -912, 0.001, "on the path: its gradient at 180 kt")
    near(afds.vnav_path_vspeed(304, 180, 200), -1212, 0.001, "200 ft above: 300 fpm more")
    near(afds.vnav_path_vspeed(304, 180, -300), -462, 0.001, "300 ft below: 450 fpm less")
    near(afds.vnav_path_vspeed(304, 180, -1000), 0, 0.001, "far below: level, not a climb")
    near(afds.vnav_path_vspeed(0, 180, 450), -675, 0.001, "450 ft above a level path")
    near(afds.vnav_path_vspeed(304, 180, 2000), -2412, 0.001, "far above: at most 1,500 fpm more")
    near(afds.vnav_path_vspeed(500, 250, 2000), -3500, 0.001, "not below -3,500 fpm")
    -- the speed: the path's correction down fades over the last 5 kt below the limit (the flaps' placard
    -- - 5 kt, Vmo - 11 kt), and beyond it the descent shallows, level 10 kt over
    near(afds.vnav_path_vspeed(304, 180, 200, 20), -1212, 0.001, "20 kt below the limit: all of it")
    near(afds.vnav_path_vspeed(304, 180, 200, 5), -1212, 0.001, "5 kt below the limit: all of it")
    near(afds.vnav_path_vspeed(304, 180, 200, 2.5), -1062, 0.001, "2.5 kt below the limit: half the correction")
    near(afds.vnav_path_vspeed(304, 180, 200, 0), -912, 0.001, "at the limit: the path's gradient only")
    near(afds.vnav_path_vspeed(304, 180, 200, -5), -456, 0.001, "5 kt over: half the gradient")
    near(afds.vnav_path_vspeed(304, 180, 200, -12), 0, 0.001, "10 kt over and more: level")
    near(afds.vnav_path_vspeed(304, 180, -300, -5), -6, 0.001, "below the path 5 kt over: shallower still")
    near(afds.vnav_path_vspeed(304, 180, -300, 3), -462, 0.001, "below the path near the limit: as before")
end)

-- 4. setDescentVSpeed (vnav.lua through the XTLua dofile) and setDistances in the approach.
local function load_in_environment(path, environment)
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    chunk()
end
local runtime = setmetatable({}, {__index = _G})
load_in_environment("plugins/xtlua_keysystems/init.lua", runtime)
runtime.XLuaGetCode = function(requested_path)
    local resolved_path = requested_path
    if not string.find(requested_path, "/", 1, true) then resolved_path = AP..requested_path end
    return assert(loadfile(resolved_path))
end
-- The autopilot's namespace at lat, lon (the fix flown to: active; one sequenced early: held), descending
-- in VNAV PTH at 180 kt ground speed with the MCP and AP altitude at mcp, CRZ ALT cruise (37,000 ft).
local function new_runtime(route, active, lat, lon, alt, mcp, held, cruise)
    local r = setmetatable({print = function() end, json = json, B747_afds_helpers = afds}, {__index = _G})
    r.dofile = runtime.get_run_file_in_namespace(r)
    r.dofile(AP.."B747.70.xt.autopilot.vnav.lua")
    for _, chunk in ipairs({
            slice(AP.."B747.70.xt.autopilot.lua", "function B747_rescale(", "function getFMSData(name)"),
            slice(AP.."B747.70.xt.autopilot.lua", "function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice(AP.."B747.70.xt.autopilot.lua", "function setDistances(fmsO)", "----- ALTITUDE SELECTED")}) do
        setfenv(assert(loadstring(chunk)), r)()
    end
    for i = 1, #route do route[i][10] = (i == active) end
    local values = {
        simDRTime = 1000, simDR_latitude = lat, simDR_longitude = lon, simDR_pressureAlt1 = alt,
        simDR_radarAlt1 = alt, simDR_groundspeed = 180 / 1.94384, simDR_ind_airspeed_kts_pilot = 180,
        simDR_vvi_fpm_pilot = -900, simDR_autopilot_vs_fpm = -1234, simDR_autopilot_altitude_ft = mcp,
        B747DR_autopilot_altitude_ft = mcp, simDR_autopilot_airspeed_kts = 180, simDR_autopilot_airspeed_is_mach = 0,
        B747DR_fmscurrentIndex = active, B747DR_vnav_hold_index = held or 0,
        B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_flightPhase = 3,
        B747DR_ap_FMA_active_pitch_mode = 6, simDR_autopilot_vs_status = 2, simDR_autopilot_flch_status = 0,
        simDR_autopilot_alt_hold_status = 0, B747DR_autopilot_gs_status = 0, simDR_autopilot_gs_status = 0,
        B747DR_ap_approach_mode = 0, simDR_autopilot_approach_status = 0, B747DR_ap_autoland = 0,
        B747DR_ap_active_land = 0, B747DR_alt_capture_window = 400, B747DR_airspeed_Vmc = 130,
        B747DR_speedbrake_lever = 0, B747BR_cruiseAlt = cruise or 37000,
        B747BR_totalDistance = 9, B747BR_tod = 120, B747BR_toc = -1, B747BR_fpe = 4321,
        B747BR_todLat = 0, B747BR_todLong = 0, B747BR_tocLat = 0, B747BR_tocLong = 0,
        B747BR_distance_to_dest = 0, B747BR_eod_index = 0, B747BR_nextDistanceInFeet = 0,
        B747BR_vnavProfile = "[]", B747DR_fmstargetDistance = 3, B747DR_ap_vnav_target_alt = mcp, B744_fpm = 0,
        B747_route_constraints = setmetatable({}, {}),
        getFMSData = function(key)
            local data = {transalt = "18000", desspdtransalt = "10000", destranspd = "240", desspd = "270"}
            return data[key]
        end}
    for key, value in pairs(values) do r[key] = value end
    return r
end

case("EHAM between AM608 and AM621", function()
    local route = eham()
    local d621 = along(route, AM621, RW18R)
    local gradient = 1400 / along(route, AM608, AM621)
    local lat, lon = before(route, AM621, 2.0)
    local on_path = 2000 + 2.0 * gradient
    -- on the path, 2 nm before AM621 (8.2 nm out), the MCP at 2,000 ft: within 600 ft of it
    local r = new_runtime(route, AM621, lat, lon, on_path, 2000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 0, 1, "on the path: no path error")
    near(r.simDR_autopilot_vs_fpm, -gradient * 180 / 60, 2, "on the path: the path's V/S within 600 ft of the MCP")
    -- 300 ft above, and 400 ft below
    r = new_runtime(route, AM621, lat, lon, on_path + 300, 2000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 300, 1, "300 ft above")
    near(r.simDR_autopilot_vs_fpm, -gradient * 3 - 450, 2, "300 ft above: 450 fpm more")
    r = new_runtime(route, AM621, lat, lon, on_path - 400, 2000)
    r.setDescentVSpeed(route)
    near(r.simDR_autopilot_vs_fpm, math.min(0, -gradient * 3 + 600), 2, "400 ft below: shallower, not a climb")
    -- setDistances leaves the path error to the path: no 290 ft/nm line to the airport's reference point
    r = new_runtime(route, AM621, lat, lon, on_path, 2000)
    r.setDistances(route)
    near(r.B747BR_fpe, 0, 1, "setDistances: the path error from the path")
    check(r.B747BR_totalDistance < 15, "inside 15 nm of the end of descent: "..r.B747BR_totalDistance)
    -- AM608 sequenced early for its turn, 0.4 nm before it: the distance by AM608 until it is passed
    lat, lon = before(route, AM608, 0.4)
    local at = along(route, AM608, RW18R) + 0.4
    local alt608 = 3400 + 0.4 * 872 / along(route, AM607, AM608)
    r = new_runtime(route, AM621, lat, lon, alt608, 2000, AM608)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 0, 1, "AM608 held: the path by AM608, "..at.." nm out")
end)

case("EINN level at 3,000 ft before the glide slope", function()
    local route = einn()
    -- 1 nm after ELPOM at 3,450 ft, cleared to 3,000 (p6-L1 stayed there at V/S 0)
    local lat, lon = before(route, ASGON, along(route, ELPOM, ASGON) - 1)
    local r = new_runtime(route, ASGON, lat, lon, 3450, 3000, nil, 35000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 450, 1, "450 ft above the level path")
    near(r.simDR_autopilot_vs_fpm, -675, 2, "down to it within 600 ft of the AP altitude")
    -- on the 3 deg final 5 nm out (the G/S not captured)
    local d = along(route, ASGON, RW06)
    lat, lon = before(route, RW06, 5)
    r = new_runtime(route, RW06, lat, lon, 101 + 5 * GLIDE, 3000, nil, 35000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 0, 1, "on the final "..d.." nm long")
    near(r.simDR_autopilot_vs_fpm, -GLIDE * 3, 2, "the final's V/S at 180 kt")
    -- 7 nm before ELPOM, coming down from the T/D: the descent's 290 ft/nm, BILTO's 35,000 ft not a fix of it
    lat, lon = before(route, ELPOM, 7)
    r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290, 3000, nil, 35000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 0, 1, "on the descent into ELPOM")
    near(r.simDR_autopilot_vs_fpm, -290 * 3, 2, "290 ft/nm at 180 kt")
end)

case("the speed limit in the approach", function()
    -- 7 nm before ELPOM, 600 ft above the descent from the T/D, flaps 5 (placard 260 kt)
    local route = einn()
    local lat, lon = before(route, ELPOM, 7)
    local function vspeed(ias, vmo)
        local r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290 + 600, 3000, nil, 35000)
        r.simDR_flap_ratio_control, r.simDR_ind_airspeed_kts_pilot, r.B747DR_airspeed_Vmo = 2 / 6, ias, vmo
        r.setDescentVSpeed(route)
        return r.simDR_autopilot_vs_fpm
    end
    near(vspeed(240), -870 - 900, 2, "240 kt, 15 kt below the placard - 5: back to the path at 900 fpm more")
    near(vspeed(252), -870 - 540, 2, "252 kt: 3 kt from the limit, 60 percent of it")
    near(vspeed(262), -870 * 0.3, 2, "262 kt: 7 kt over, the descent shallows")
    -- flaps up the limit is Vmo - 11 kt
    local r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290 + 600, 3000, nil, 35000)
    r.simDR_flap_ratio_control, r.simDR_ind_airspeed_kts_pilot, r.B747DR_airspeed_Vmo = 0, 351, 365
    r.setDescentVSpeed(route)
    near(r.simDR_autopilot_vs_fpm, -870 - 540, 2, "351 kt flaps up: 3 kt below Vmo - 11")
end)

case("outside the approach", function()
    -- 28 nm out on NETOM -> NIRSI: the approach's path is not flown yet
    local route = eham()
    local lat, lon = before(route, NIRSI, 8)
    local r = new_runtime(route, NIRSI, lat, lon, 8000, 2000)
    r.setDescentVSpeed(route)
    check(r.B747_vnav_approach_active ~= true, "28 nm out: not the approach")
    check(r.B747BR_fpe == 4321, "28 nm out: the path error from the profile (left alone when empty)")
end)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV approach path tests passed: "..checks)
