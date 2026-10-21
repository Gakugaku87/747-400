-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The route constraints' code as XTLua runs it.
-- 1. In the xt autopilot deferred_dataref is find_dataref: a dataref it binds
--    exists only if an init script creates it (init/scripts/...); otherwise
--    reads give 0 and writes are dropped. Every laminar/ dataref the autopilot
--    binds must be created by one.
-- 2. XTLua runs a script in a namespace (init.lua's create_namespace) that
--    stores a global table without a metatable as a namespace of its own, whose
--    read of a missing index recurses until the stack overflows: the route's
--    constraints (B747_route_constraints, read by index every frame) must read
--    as a table there. The production functions run in such a namespace.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    return text
end

-- 1. Datarefs created, by the init scripts of any of the aircraft's XTLua plugins.
local function init_scripts()
    local command = package.config:sub(1, 1) == "\\" and 'dir /s /b "plugins\\*.lua"' or 'find plugins -name "*.lua"'
    local pipe = assert(io.popen(command))
    local scripts = {}
    for line in pipe:lines() do
        local path = string.gsub(line, "\\", "/")
        if string.find(path, "/init/scripts/", 1, true) then scripts[#scripts + 1] = path end
    end
    pipe:close()
    return scripts
end
local created, scripts = {}, init_scripts()
check(#scripts >= 8, "init scripts found ("..#scripts..")")
for _, script in ipairs(scripts) do
    for path in string.gmatch(read(script), "deferred_dataref%(%s*\"([^\"]+)\"") do
        created[path] = true
    end
end
local autopilot = read(AP.."B747.70.xt.autopilot.lua")
local bound = 0
for line in string.gmatch(autopilot.."\n", "([^\n]*)\n") do
    local path = string.match(line, "^%s*[%w_]+%s*=%s*deferred_dataref%(%s*\"(laminar/[^\"]+)\"")
    if path ~= nil then
        bound = bound + 1
        check(created[path] == true, "the autopilot's "..path.." is created by an init script")
    end
end
check(bound > 50, "the autopilot's deferred datarefs were found ("..bound..")")

-- 2. In XTLua's namespace.
local runtime = setmetatable({}, {__index = _G})
local init = assert(loadfile("plugins/xtlua_keysystems/init.lua"))
setfenv(init, runtime)()
local ns = runtime.create_namespace()
local function slice(source, first_marker, last_marker, alt_first)
    local first = source:find(first_marker, 1, true) or (alt_first and source:find(alt_first, 1, true))
    assert(first, first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local monitor = read(AP.."B747.70.xt.autopilot.monitor.lua")
for _, chunk in ipairs({
        slice(autopilot, "function getDistance(lat1, lon1, lat2, lon2)", "function movePoint("),
        slice(autopilot, "B747_route_constraints=setmetatable({},{})", "function B747_getCurrentWayPoint_default(fmsO)",
            "B747_route_constraints={}"),
        slice(monitor, "function VNAV_NEXT_ALT(numAPengaged,fms)", "function VNAV_CLB_ALT(numAPengaged,fms)")}) do
    local fn = assert(loadstring(chunk))
    setfenv(fn, ns)
    fn()
end
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
local route = {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("RW28R", 53.435203, -6.244964),
    entry("DE28R", 53.437394, -6.284811), entry("(650)", 53.4395, -6.2970, 650, 2048),
    entry("DW128", 53.465722, -6.352278), entry("DW129", 53.526722, -6.348806),
    entry("DW124", 53.522306, -6.073889), entry("ATGOW", 53.488944, -5.842361),
    entry("ENDEQ", 53.445661, -5.5), entry("RULAV", 53.437319, -5.167014, 37000), entry("EHAM", 52.3175, 4.7716, -11, 1)}
-- the CIFP module's work stood in for: ENDE3J's DW129 at or below 210 kt and DW124 at or below FL090
ns.B747_constraints = {LINES_PER_STEP = 150,
    new_loader = function() return {records = {}} end,
    loader_start = function() end,
    loader_step = function() return true end,
    match_route = function()
        return {constraints = {[6] = {speed_desc = "-", speed = 210, phase = "climb"},
            [7] = {alt_desc = "-", ceiling = 9000, phase = "climb"}}, summary = "SID ENDE3J/6"}
    end}
ns.B747_afds_helpers = afds
ns.B747DR_vnav_procedures, ns.B747DR_vnav_constraint_speed, ns.B747DR_vnav_hold_index = "", -1, 0
ns.B747DR_fmscurrentIndex, ns.B747DR_ap_inVNAVdescent = 6, 0
ns.simDR_latitude, ns.simDR_longitude, ns.simDR_groundspeed, ns.simDR_ind_airspeed_kts_pilot = 53.5, -6.35, 100, 200
ns.simDR_pressureAlt1, ns.simDR_autopilot_altitude_ft = 5000, 37000
ns.B747BR_totalDistance, ns.B747BR_tod, ns.B747BR_cruiseAlt = 300, 100, 37000
ns.B747DR_fmstargetDistance, ns.B747DR_ap_vnav_target_alt = 0, 0
ns.getFMSData = function(key) if key == "transalt" then return "18000" end return "" end
ns.print = function() end
for i = 1, #route do route[i][10] = (i == 6) end

local ok, err = pcall(function() ns.B747_update_route_constraints(route) end)
check(ok, "B747_update_route_constraints in the namespace: "..tostring(err))
check(ns.B747DR_vnav_procedures == "SID ENDE3J/6", "procedures: "..tostring(ns.B747DR_vnav_procedures))
ok, err = pcall(function() return ns.B747_route_constraints[99] end)
check(ok and err == nil, "a missing index of B747_route_constraints reads nil: "..tostring(err))
ok, err = pcall(function() return ns.B747_route_constraints[6].speed end)
check(ok and err == 210, "DW129's speed by index: "..tostring(err))
if type(ns.B747_update_constraint_speed) == "function" then
    ok, err = pcall(function() ns.B747_update_constraint_speed(route) end)
    check(ok and ns.B747DR_vnav_constraint_speed == 210, "B747_update_constraint_speed in the namespace: 210, got "
        ..tostring(ns.B747DR_vnav_constraint_speed).." "..tostring(err))
end
ok, err = pcall(function() return ns.VNAV_NEXT_ALT(1, route) end)
check(ok and err == 9000, "VNAV_NEXT_ALT in the namespace: DW124's 9000, got "..tostring(err))
-- a new route with no procedure (TST744L): the empty table reads too
ns.B747_constraints.match_route = function() return {constraints = {}, summary = ""} end
route[3][8] = "EMPER"
ok, err = pcall(function() ns.B747_update_route_constraints(route) end)
check(ok, "a route without procedures: "..tostring(err))
ok, err = pcall(function() return ns.VNAV_NEXT_ALT(1, route) end)
check(ok and err == 37000, "VNAV_NEXT_ALT without constraints: 37000, got "..tostring(err))
ok, err = pcall(function() ns.B747_update_route_constraints({}) end)
ok = ok and pcall(function() return ns.B747_route_constraints[1] end)
check(ok, "no route: the table reads, "..tostring(err))

if #failures > 0 then
    error(string.format("xtlua_route_constraints_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("xtlua_route_constraints_test: %d checks passed", checks))
