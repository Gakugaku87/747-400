-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV in the climb with the SID's constraints from the CIFP
-- (B747_route_constraints): it levels at the lowest ceiling (at or below, at,
-- a window's top) of the fixes not passed yet and climbs on once that fix is
-- passed - a fix LNAV sequenced early for its turn counts until past the
-- turn's bisector; at or above is no level-off. The native FMS passes 0 as a
-- climb's at or below ([9]), so VNAV climbed straight through EIDW 28R
-- ENDE3J's DW124 at or below FL090 (the kit's flights passed it climbing at
-- 7,900-8,400 ft only because the climb was slow); and levelled at a fix's
-- altitude it would have climbed on at once, the resume taking the active
-- fix's [9] (0, so the MCP's). The production VNAV_NEXT_ALT, VNAV_CLB_ALT and
-- VNAV_CLB (B747.70.xt.autopilot.monitor.lua) run against mocked datarefs.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
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

local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
-- EIDW 28R ENDE3J with the native FMS's altitudes: (650) its CA leg's, 0 for the at or below and the
-- fixes without a constraint, CRZ ALT from RULAV on.
local function eidw()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("RW28R", 53.435203, -6.244964),
        entry("DE28R", 53.437394, -6.284811), entry("(650)", 53.4395, -6.2970, 650, 2048),
        entry("DW128", 53.465722, -6.352278), entry("DW129", 53.526722, -6.348806),
        entry("DW124", 53.522306, -6.073889), entry("ATGOW", 53.488944, -5.842361),
        entry("ENDEQ", 53.445661, -5.5), entry("RULAV", 53.437319, -5.167014, 37000),
        entry("ABGEP", 53.427589, -4.861031, 37000), entry("EHAM", 52.3175, 4.7716, -11, 1)}
end
local DW128, DW129, DW124, ATGOW, ENDEQ = 5, 6, 7, 8, 9
-- ENDE3J's constraints as B747.70.xt.autopilot.constraints.lua gives them
local function ende3j()
    return {[4] = {alt_desc = "+", floor = 650, speed_desc = "-", speed = 210, phase = "climb", source = "SID ENDE3J"},
        [DW128] = {speed_desc = "-", speed = 210, phase = "climb", source = "SID ENDE3J"},
        [DW129] = {speed_desc = "-", speed = 210, phase = "climb", source = "SID ENDE3J"},
        [DW124] = {alt_desc = "-", ceiling = 9000, fl = true, phase = "climb", source = "SID ENDE3J"},
        [ENDEQ] = {alt_desc = "-", ceiling = 23000, fl = true, speed_desc = "-", speed = 290, phase = "climb",
            source = "SID ENDE3J"}}
end

local function new_runtime(route, active, alt)
    local env = setmetatable({print = function() end, B747_afds_helpers = afds, json = json}, {__index = _G})
    for _, chunk in ipairs({
            slice(AP.."B747.70.xt.autopilot.lua", "function getDistance(lat1, lon1, lat2, lon2)", "function movePoint("),
            slice(AP.."B747.70.xt.autopilot.monitor.lua", "function VNAV_NEXT_ALT(numAPengaged,fms)",
                "function VNAV_CRZ(numAPengaged,dist)")}) do
        setfenv(assert(loadstring(chunk)), env)()
    end
    local lat, lon = route[active][5], route[active][6]
    -- 3 nm short of the active fix on the leg to it
    env.simDR_latitude = lat + (route[active - 1][5] - lat) * 0.3
    env.simDR_longitude = lon + (route[active - 1][6] - lon) * 0.3
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_groundspeed = alt, alt - 200, 130
    env.B747DR_fmscurrentIndex = active
    for i = 1, #route do route[i][10] = (i == active) end
    -- climbing: the T/D 200 nm ahead
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 300, 100, 0
    env.B747BR_cruiseAlt, env.B747DR_autopilot_altitude_ft = 37000, 37000      -- CRZ ALT, the MCP
    env.simDR_autopilot_altitude_ft = 37000
    env.B747DR_mcp_hold, env.B747DR_mcp_hold_pressed, env.simDRTime = 0, 0, 1000
    env.B747DR_alt_capture_window = 300
    env.simDR_autopilot_alt_hold_status, env.simDR_autopilot_flch_status, env.simDR_autopilot_vs_status = 0, 2, 0
    env.B747DR_ap_vnav_state, env.B747DR_engine_TOGA_mode, env.B747DR_autopilot_TOGA_status = 2, 0, 0
    env.B747DR_ap_autoland, env.B747DR_ap_lastCommand, env.B747DR_ap_thrust_mode = 0, 0, 2
    env.B747DR_fmstargetDistance, env.B747DR_ap_vnav_target_alt, env.B747DR_vnav_hold_index = 0, 0, 0
    env.simDR_autopilot_hold_altitude_ft = 0
    env.flch_pushed = 0
    env.simCMD_autopilot_flch_mode = {once = function() env.flch_pushed = env.flch_pushed + 1 end}
    env.setVNAVState = function() end
    env.getVNAVState = function() return 0 end
    env.B747_invalidate_vnav_speed = function() end
    env.B747_vnav_speed = function() end
    env.getFMSData = function(key)
        if key == "transalt" then return "18000" end
        return ""
    end
    env.B747_route_constraints = ende3j()
    return env
end

-- 1. Before DW124 (at or below FL090): the target is 9000, and the dial.
case("before DW124", function()
    local route = eidw()
    local env = new_runtime(route, DW124, 6000)
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 9000, "6000 ft, DW124 active: the target is DW124's 9000, got "..tostring(target))
    env.VNAV_CLB(1, route)
    check(env.simDR_autopilot_altitude_ft == 9000, "the dial at 9000, got "..tostring(env.simDR_autopilot_altitude_ft))
    -- from DW129 on: DW124's ceiling ahead already
    env = new_runtime(route, DW129, 4000)
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 9000, "4000 ft, DW129 active: the target is DW124's 9000, got "..tostring(target))
end)

-- 2. Levelled at 9000 before DW124: no resume (it used to climb on at once).
case("levelled at DW124's ceiling", function()
    local route = eidw()
    local env = new_runtime(route, DW124, 9000)
    env.simDR_autopilot_altitude_ft, env.simDR_autopilot_alt_hold_status, env.simDR_autopilot_flch_status = 9000, 2, 0
    env.VNAV_CLB(1, route)
    check(env.B747DR_ap_vnav_state ~= 3 and env.flch_pushed == 0 and env.simDR_autopilot_flch_status == 0,
        "at 9000 in ALT before DW124: no resume, vnav_state "..tostring(env.B747DR_ap_vnav_state)
        ..", FLCH pushed "..env.flch_pushed)
    check(env.simDR_autopilot_altitude_ft == 9000, "the dial stays 9000, got "..tostring(env.simDR_autopilot_altitude_ft))
end)

-- 3. DW124 passed: on to ENDEQ's FL230.
case("past DW124", function()
    local route = eidw()
    local env = new_runtime(route, ATGOW, 9000)
    env.simDR_autopilot_altitude_ft, env.simDR_autopilot_alt_hold_status, env.simDR_autopilot_flch_status = 9000, 2, 0
    env.VNAV_CLB(1, route)
    check(env.B747DR_ap_vnav_target_alt == 23000, "ATGOW active: the target is ENDEQ's 23000, got "
        ..tostring(env.B747DR_ap_vnav_target_alt))
    check(env.simDR_autopilot_altitude_ft == 23000 and env.flch_pushed == 1,
        "the climb resumes to 23000, dial "..tostring(env.simDR_autopilot_altitude_ft)..", FLCH pushed "..env.flch_pushed)
    -- and past ENDEQ: CRZ ALT
    env = new_runtime(route, 10, 23000)
    check(env.VNAV_NEXT_ALT(1, route) == 37000, "RULAV active: CRZ ALT 37000")
end)

-- 4. DW124 sequenced early for its turn: its ceiling stands until past the bisector.
case("DW124 held", function()
    local route = eidw()
    local env = new_runtime(route, ATGOW, 8800)
    env.B747DR_vnav_hold_index = DW124
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 9000, "ATGOW active, DW124 held: 9000, got "..tostring(target))
end)

-- 5. At or above is no level-off: a fix the native FMS gives its altitude ([9]) with an at or above.
case("at or above", function()
    local route = eidw()
    route[DW129][9] = 5000
    local env = new_runtime(route, DW128, 3000)
    env.B747_route_constraints = {[DW129] = {alt_desc = "+", floor = 5000, phase = "climb", source = "SID TEST"}}
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 37000, "DW129 at or above 5000 ahead: no level-off there, CRZ ALT, got "..tostring(target))
    -- an at (ceiling and floor): levels there
    env.B747_route_constraints = {[DW129] = {alt_desc = "@", floor = 5000, ceiling = 5000, phase = "climb"}}
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 5000, "DW129 at 5000: levels at 5000, got "..tostring(target))
    -- a window: its top
    env.B747_route_constraints = {[DW129] = {alt_desc = "B", floor = 5000, ceiling = 7000, phase = "climb"}}
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 7000, "DW129 window 5000-7000: levels at 7000, got "..tostring(target))
end)

-- 6. A ceiling more than 300 ft below the aircraft is let go (no descent in the climb); within 300 ft the
-- aircraft comes back to it.
case("above a ceiling", function()
    local route = eidw()
    local env = new_runtime(route, DW124, 9500)
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target == 23000, "9500 ft before DW124 (at or below 9000): ENDEQ's 23000, got "..tostring(target))
    env = new_runtime(route, DW124, 9200)
    target = env.VNAV_NEXT_ALT(1, route)
    check(target == 9000, "9200 ft before DW124: back to 9000, got "..tostring(target))
end)

-- 7. The MCP below the ceiling: the MCP stands, as before.
case("MCP below", function()
    local route = eidw()
    local env = new_runtime(route, DW124, 6000)
    env.B747DR_autopilot_altitude_ft = 7000
    env.VNAV_CLB(1, route)
    check(env.simDR_autopilot_altitude_ft == 7000, "MCP 7000: the dial at 7000, got "..tostring(env.simDR_autopilot_altitude_ft))
end)

-- 8. Without the CIFP's constraints, or in the descent: as before.
case("no constraints, descent", function()
    local route = eidw()
    local env = new_runtime(route, DW124, 6000)
    env.B747_route_constraints = {}
    check(env.VNAV_NEXT_ALT(1, route) == 37000, "no constraints: CRZ ALT")
    env.B747_route_constraints = nil
    check(env.VNAV_NEXT_ALT(1, route) == 37000, "nil constraints: CRZ ALT")
    env = new_runtime(route, DW124, 6000)
    env.B747BR_totalDistance, env.B747BR_tod, env.B747DR_ap_inVNAVdescent = 30, 100, 2
    env.simDR_autopilot_altitude_ft = 3000
    local target = env.VNAV_NEXT_ALT(1, route)
    check(target ~= 9000, "descending: no climb ceiling, got "..tostring(target))
end)

if #failures > 0 then
    error(string.format("vnav_climb_constraints_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_climb_constraints_test: %d checks passed", checks))
