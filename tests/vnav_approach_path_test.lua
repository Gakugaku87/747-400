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

-- TST744L as the native FMS has it: the departure runway, the oceanic fixes, ILS 06 and its missed approach
local function tst744l()
    return {entry("EINN", 52.701992, -8.924772, 41, 1), entry("RW24", 52.710008, -8.906353, 41),
        entry("EMPER", 49, -9, 31000), entry("BEDRA", 49, -15, 33000), entry("ETARI", 55.5, -15, 35000),
        entry("BILTO", 56.5, -15, 35000), entry("ELPOM", 52.560306, -9.224111, 3000),
        entry("ASGON", 52.598444, -9.143917, 3046), entry("RW06", 52.693172, -8.943519, 101),
        entry("NN005", 52.7303, -8.8633, 4000), entry("SHA", 52.7214, -8.8853, 4000), entry("EINN", 52.701992, -8.924772, 41, 1)}
end

-- 1. The arrival runway.
case("the arrival runway", function()
    check(afds.route_runway_index(eham(), getDistance, 10) == RW18R, "EHAM: RW18R")
    -- with its missed approach, a vectors leg's end hundreds of nm away
    local route = eham()
    table.insert(route, RW18R + 1, entry("(500)", 52.345, 4.711, 500, 2048))
    table.insert(route, RW18R + 2, entry("AM624", 52.2667, 4.6333, 2000))
    table.insert(route, RW18R + 3, entry("(VECT)", 60.5, 15.0, 2000, 2048))
    check(afds.route_runway_index(route, getDistance, 10) == RW18R, "EHAM with its missed approach: RW18R")
    check(afds.route_runway_index(tst744l(), getDistance, 10) == 9, "TST744L: RW06, not the departure's RW24")
    -- the route back to EINN without its approach: the departure runway is no arrival runway
    local loop = tst744l()
    for _ = 7, 11 do table.remove(loop, 7) end
    check(afds.route_runway_index(loop, getDistance, 10) == nil, "no approach: no arrival runway")
    -- only a runway's name: not a fix whose name begins with RW
    route = eham()
    route[RW18R][8] = "RWY18"
    check(afds.route_runway_index(route, getDistance, 10) == nil, "RWY18 is no runway")
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

-- The fixes of the approach's path: after the route's farthest point from the destination, without a
-- departure runway, pseudo fixes ("(...)") or airports.
case("the approach's fixes", function()
    -- a short circuit: the departure runway at 41 ft and a fix at 2,000 ft before the downwind at 3,000 ft
    local circuit = {entry("EINN", 52.701992, -8.924772, 41, 1), entry("RW24", 52.710008, -8.906353, 41),
        entry("DEP1", 52.75, -8.98, 2000), entry("DW1", 52.80, -8.90, 3000), entry("BASE", 52.62, -8.80, 3000),
        entry("FAF", 52.65, -8.99, 2500), entry("RW06", 52.693172, -8.943519, 101),
        entry("EINN", 52.701992, -8.924772, 41, 1)}
    -- DW1 flown to (still on the way out) and FAF flown to: the path from the circuit's farthest point
    -- (BASE) in, the departure's 2,000 and 41 ft left out; level at BASE's 3,000 ft beyond it
    for _, flown_to in ipairs({4, 6}) do
        local points = afds.vnav_approach_path(circuit, 7, flown_to, getDistance, 18000, 3000, 3.0)
        local alts = {}
        for _, point in ipairs(points or {}) do alts[#alts + 1] = point.alt end
        check(table.concat(alts, " ") == "101 2500 3000", "the circuit's path, "..circuit[flown_to][8].." flown"
            .." to: the runway's 101 ft, the FAF's 2,500 (3.1 nm out, below the 3 deg line), BASE's 3,000, no"
            .." 2,000 or 41 ft: "..table.concat(alts, " "))
    end
    local points = afds.vnav_approach_path(circuit, 7, 4, getDistance, 18000, 3000, 3.0)
    check(afds.vnav_path_at(points, 12) == 3000, "on the way out: level at BASE's 3,000 ft")
    -- a DIRECT TO ELPOM that left only the origin before it: ELPOM is the farthest point, the path from it
    local direct = tst744l()
    for _ = 2, 6 do table.remove(direct, 2) end
    points = afds.vnav_approach_path(direct, 4, 2, getDistance, 18000, 35000, 3.0)
    check(points ~= nil and #points == 5 and points[4].alt == 3000,
        "DIRECT TO ELPOM: the path from ELPOM ("..(points and #points or 0).." points)")
    -- a runway entry before the arrival runway (a runway change left in the route) is no fix of the path
    local changed = eham()
    table.insert(changed, RW18R, entry("RW18C", 52.37, 4.737, 50))
    points = afds.vnav_approach_path(changed, RW18R + 1, AM621, getDistance, 18000, 37000, 3.0)
    for _, point in ipairs(points) do check(point.alt ~= 50, "no runway entry as a fix of the path") end
    local route = eham()
    table.insert(route, AM608, entry("(INTC)", 52.56, 4.69, 3800, 2048))
    route[RW18R + 1][9] = 0
    points = afds.vnav_approach_path(route, RW18R + 1, AM607, getDistance, 18000, 37000, 3.0)
    check(points[1].alt == -11 + 50, "the runway without an altitude: the destination's + 50 ft")
    for _, point in ipairs(points) do check(point.alt ~= 3800, "no pseudo fix in the path") end
    -- the runway active, nothing before it with an altitude: the runway's and the T/D's 290 ft/nm
    route = eham()
    route[AM622][9] = 0
    points = afds.vnav_approach_path(route, RW18R, RW18R, getDistance, 18000, 37000, 3.0)
    check(#points == 2 and points[2].alt == 37000, "no fix: from the runway at 290 ft/nm")
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
    -- the DES page's V/B: the angle from here down to the next fix's altitude (AM621's 2,000 ft, 2 nm on)
    near(r.B747DR_ap_vb, math.deg(math.atan((on_path - 400 - 2000) / (2.0 * 6076.12))), 0.01,
        "V/B 400 ft below the path: to AM621")
    r = new_runtime(route, AM621, lat, lon, on_path + 300, 2000)
    r.setDescentVSpeed(route)
    near(r.B747DR_ap_vb, math.deg(math.atan((on_path + 300 - 2000) / (2.0 * 6076.12))), 0.01,
        "V/B 300 ft above the path: to AM621")
    -- vectored 6 nm east of AM621, AM621 flown to (farther from the runway than AM608 is): still to AM621
    lat, lon = geo.movePoint(route[AM621][5], route[AM621][6], 6, 90)
    r = new_runtime(route, AM621, lat, lon, 2500, 2000)
    r.setDescentVSpeed(route)
    near(r.B747DR_ap_vb, math.deg(math.atan(500 / (6 * 6076.12))), 0.01, "V/B off the route: to AM621, not AM608")
    lat, lon = before(route, AM621, 2.0)
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
    near(r.B747DR_ap_vb, math.deg(math.atan((alt608 - 3400) / (0.4 * 6076.12))), 0.01,
        "AM608 held: the V/B to AM608's 3,400 ft, not AM621's")
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
    -- level at 3,000 ft between ASGON and the glide slope intercept: the V/B to the runway, not to the intercept
    lat, lon = before(route, RW06, 9.2)
    r = new_runtime(route, RW06, lat, lon, 3000, 3000, nil, 35000)
    r.setDescentVSpeed(route)
    near(r.B747DR_ap_vb, math.deg(math.atan((3000 - 101) / (9.2 * 6076.12))), 0.01, "V/B to RW06's 101 ft")
    -- 7 nm before ELPOM, coming down from the T/D: the descent's 290 ft/nm, BILTO's 35,000 ft not a fix of it
    lat, lon = before(route, ELPOM, 7)
    r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290, 3000, nil, 35000)
    r.setDescentVSpeed(route)
    near(r.B747BR_fpe, 0, 1, "on the descent into ELPOM")
    near(r.simDR_autopilot_vs_fpm, -290 * 3, 2, "290 ft/nm at 180 kt")
end)

case("the speed limit in the approach", function()
    -- 7 nm before ELPOM, 600 ft above the descent from the T/D, flaps 5 (placard 260 kt): the limit is the
    -- placard - 2 kt, above every A/T target with the flaps out (VNAV's and the window's at most the placard - 5)
    local route = einn()
    local lat, lon = before(route, ELPOM, 7)
    local function vspeed(ias, vmo)
        local r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290 + 600, 3000, nil, 35000)
        r.simDR_flap_ratio_control, r.simDR_ind_airspeed_kts_pilot, r.B747DR_airspeed_Vmo = 2 / 6, ias, vmo
        r.setDescentVSpeed(route)
        return r.simDR_autopilot_vs_fpm
    end
    near(vspeed(240), -870 - 900, 2, "240 kt, 18 kt below the placard - 2: back to the path at 900 fpm more")
    near(vspeed(255.5), -870 - 450, 2, "255.5 kt, just over the A/T's cap: 2.5 kt from the limit, half of it")
    near(vspeed(262), -870 * 0.6, 2, "262 kt: 4 kt over, the descent shallows")
    -- flaps up the limit is Vmo - 11 kt
    local r = new_runtime(route, ELPOM, lat, lon, 3000 + 7 * 290 + 600, 3000, nil, 35000)
    r.simDR_flap_ratio_control, r.simDR_ind_airspeed_kts_pilot, r.B747DR_airspeed_Vmo = 0, 351, 365
    r.setDescentVSpeed(route)
    near(r.simDR_autopilot_vs_fpm, -870 - 540, 2, "351 kt flaps up: 3 kt below Vmo - 11")
end)

case("setDistances with the missed approach after the runway", function()
    local route = eham()
    table.insert(route, RW18R + 1, entry("(500)", 52.345, 4.711, 500, 2048))
    table.insert(route, RW18R + 2, entry("AM624", 52.2667, 4.6333, 2000))
    table.insert(route, RW18R + 3, entry("(VECT)", 60.5, 15.0, 2000, 2048))
    local gradient = 1400 / along(route, AM608, AM621)
    local lat, lon = before(route, AM621, 2.0)
    local r = new_runtime(route, AM621, lat, lon, 2000 + 2.0 * gradient + 100, 2000)
    r.setDistances(route)
    near(r.B747BR_fpe, 100, 1, "100 ft above the path to RW18R")
    -- past the runway: no approach any more
    r = new_runtime(route, RW18R + 2, 52.30, 4.70, 600, 2000)
    r.B747BR_fpe = 4321
    r.setDescentVSpeed(route)
    check(r.B747_vnav_approach_active ~= true, "on the missed approach: no approach path")
end)

case("VNAV off", function()
    -- VNAV disengaged in the descent (inDescent 1, vnav_state 0): the path error only, no V/S
    local route = eham()
    local lat, lon = before(route, AM621, 2.0)
    local r = new_runtime(route, AM621, lat, lon, 2600, 2000)
    r.B747DR_ap_vnav_state = 0
    r.setDescentVSpeed(route)
    check(r.simDR_autopilot_vs_fpm == -1234, "VNAV off: the V/S left alone")
    check(r.B747BR_fpe < 1000 and r.B747BR_fpe > -1000, "VNAV off: the path error from the path")
    check(r.B747_vnav_approach_active == false, "VNAV off: not VNAV's approach")
end)

case("into and out of the approach", function()
    -- on NETOM -> NIRSI (NIRSI 19.7 nm from RW18R): into the approach at 25 nm, out of it beyond 27 nm, so
    -- radar vectors or a hold about 25 nm out do not switch it on and off
    local route = eham()
    local to_nirsi = along(route, NIRSI, RW18R)
    local r = new_runtime(route, NIRSI, 0, 0, 7000, 2000)
    local function at(nm)
        r.simDR_latitude, r.simDR_longitude = before(route, NIRSI, nm - to_nirsi)
        r.setDescentVSpeed(route)
        return r.B747_vnav_approach_active == true
    end
    check(not at(26), "26 nm, coming from farther out: not yet")
    check(at(24.5), "24.5 nm: the approach")
    check(at(26), "26 nm after it: still the approach")
    check(at(26.9), "26.9 nm: still the approach")
    check(not at(27.5), "27.5 nm: out of it")
    check(not at(26), "26 nm again: not until 25 nm")
    -- held by the runway, not by its place in the route: a fix added before it keeps the approach, another
    -- runway in its place does not
    check(at(24.5), "24.5 nm: the approach again")
    table.insert(route, AM607, entry("XTRA", 52.59, 4.60, 4800))
    for i = 1, #route do route[i][10] = (i == NIRSI) end
    check(at(26), "a fix added before the runway: still the approach at 26 nm")
    -- the runway's name and its position each count
    check(at(24.5), "24.5 nm: the approach")
    route[RW18R + 1][6] = 4.75
    check(not at(26), "a runway of that name elsewhere (another airport's): not the approach at 26 nm")
    route[RW18R + 1][6] = 4.711725
    check(at(24.5), "24.5 nm: the approach")
    route[RW18R + 1][8] = "RW18C"
    check(not at(26), "another runway's name at its place: not the approach at 26 nm")
    route[RW18R + 1][8] = "RW18R"
    check(at(24.5), "24.5 nm: the approach")
    route[RW18R + 1][8], route[RW18R + 1][6] = "RW18C", 4.75
    check(not at(26), "another runway in its place: not the approach at 26 nm")
    table.remove(route, AM607)
    route[RW18R][8], route[RW18R][6] = "RW18R", 4.711725
    -- let go when the route is gone or the runway passed
    check(at(24.5), "24.5 nm: the approach")
    check(r.B747_vnav_approach_path(nil) == nil, "no route: none")
    check(not at(26), "after no route: not at 26 nm")
    check(at(24.5), "24.5 nm: the approach")
    r.B747DR_fmscurrentIndex = RW18R + 1
    check(r.B747_vnav_approach_path(route) == nil, "past the runway: none")
    r.B747DR_fmscurrentIndex = NIRSI
    check(not at(26), "after the runway: not at 26 nm")
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
