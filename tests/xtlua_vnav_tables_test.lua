-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV's new global tables as XTLua runs them: XTLua runs a script in a namespace (init.lua's
-- create_namespace) that copies a global table without a metatable into a namespace of its own, whose read of a
-- missing index recurses until the stack overflows (as B747_route_constraints, which therefore has a metatable). LNAV's
-- held turn (B747_lnav_vnav_turn, B747_lnav_update_vnav_hold) and the MCP altitude's conflict with the descent
-- (B747_vnav_mcp_conflict, VNAV_DES_ALT) must read as plain tables there, a missing index nil. The production LNAV
-- and VNAV_DES_ALT run in such a namespace, on the EHAM route at NETOM's turn and in a descent with the MCP above.
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
local function slice(source, first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    return source:sub(first, last - 1)
end

local runtime = setmetatable({}, {__index = _G})
local init = assert(loadfile("plugins/xtlua_keysystems/init.lua"))
setfenv(init, runtime)()
local ns = runtime.create_namespace()
local autopilot = read(AP.."B747.70.xt.autopilot.lua")
local monitor = read(AP.."B747.70.xt.autopilot.monitor.lua")
for _, chunk in ipairs({
        slice(autopilot, "function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
        slice(autopilot, "function movePoint(", "\nend\n").."\nend\n",
        slice(autopilot, "function B747_getCurrentWayPoint(fmsO)", "local LNAV_MAX_PREEMPT_XTK_NM"),
        slice(autopilot, "local LNAV_MAX_PREEMPT_XTK_NM", "function B747_ap_altitude(fms)"),
        slice(monitor, "function VNAV_NEXT_ALT(numAPengaged,fms)", "function LNAV_modeSwitch()")}) do
    local fn = assert(loadstring(chunk))
    setfenv(fn, ns)
    fn()
end
ns.B747_afds_helpers = afds
ns.print = function() end
ns.B747_route_constraints = setmetatable({}, {})
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
local route = {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("SUGOL", 52.525511, 3.96735, 11315),
    entry("NETOM", 52.422444, 4.387917, 7849), entry("NIRSI", 52.583878, 4.513372, 5563),
    entry("AM607", 52.583889, 4.646889, 4272), entry("RW18R", 52.360258, 4.711725, 37),
    entry("EHAM", 52.3175, 4.7716, -11, 1)}
local NETOM, NIRSI = 3, 4

-- 1. LNAV holds NETOM at its turn's start: B747_lnav_vnav_turn
ns.simDR_pressureAlt1, ns.simDR_radarAlt1, ns.simDR_vvi_fpm_pilot, ns.simDR_onGround = 8000, 8000, -1000, 0
ns.simDR_groundspeed, ns.simDR_TAS_mps = 149, 149
ns.simDR_true_heading, ns.simDR_ground_track_true = 112, 112
ns.simDR_autopilot_bank_limit, ns.simDR_autopilot_bank_angles = 4, {[0] = 5, 10, 15, 20, 25, 30}
ns.B747DR_ap_lnav_state, ns.B747DR_ap_approach_mode, ns.B747DR_ap_lnav_xtk_target = 2, 0, 0
ns.B747DR_ap_lnav_xtk_error, ns.B747DR_CAS_caution_status, ns.simDR_override_fms_progress = 0, {}, 1
-- 3 nm before NETOM on the leg from SUGOL
ns.simDR_latitude, ns.simDR_longitude = ns.movePoint(route[NETOM][5], route[NETOM][6], 3,
    ns.getHeading(route[NETOM][5], route[NETOM][6], route[2][5], route[2][6]))
for i = 1, #route do route[i][10] = (i == NETOM) end
ns.B747DR_fmscurrentIndex = NETOM
local ok, err = pcall(function() ns.B747_lnav_update_vnav_hold(route) end)
check(ok, "B747_lnav_update_vnav_hold on NETOM: "..tostring(err))
for i = 1, #route do route[i][10] = (i == NIRSI) end
ns.B747DR_fmscurrentIndex = NIRSI
ok, err = pcall(function() ns.B747_lnav_update_vnav_hold(route) end)
check(ok and ns.B747DR_vnav_hold_index == NETOM, "NETOM held at its turn's start: "..tostring(err).." "
    ..tostring(ns.B747DR_vnav_hold_index))
ok, err = pcall(function() return ns.B747_lnav_vnav_turn.fix end)
check(ok and err == NETOM, "the held turn's fix reads: "..tostring(err))
ok, err = pcall(function() return ns.B747_lnav_vnav_turn.missing end)
check(ok and err == nil, "a missing index of B747_lnav_vnav_turn reads nil: "..tostring(err))

-- 2. the MCP altitude above the airplane in a VNAV descent: B747_vnav_mcp_conflict
ns.getFMSData = function(key)
    if key == "transalt" then return "18000" end
    if key == "desspdtransalt" then return "10000" end
    return ""
end
ns.simDRTime, ns.B747DR_mcp_hold_pressed, ns.B747DR_mcp_hold = 1000, 0, 0
ns.simDR_pressureAlt1, ns.B747DR_autopilot_altitude_ft, ns.simDR_autopilot_altitude_ft = 12000, 13000, 9000
ns.simDR_autopilot_alt_hold_status, ns.B747DR_alt_capture_window = 0, 600
ns.B747DR_ap_ias_mach_window_open, ns.simDR_ind_airspeed_kts_pilot, ns.B747DR_airspeed_Vmc = 0, 280, 150
ns.B747BR_totalDistance, ns.B747BR_tod, ns.B747BR_cruiseAlt, ns.B747DR_ap_inVNAVdescent = 50, 100, 37000, 2
ns.B747DR_fmstargetDistance, ns.B747DR_ap_vnav_target_alt = 0, 0
ok, err = pcall(function() ns.VNAV_DES_ALT(1, route) end)
check(ok, "VNAV_DES_ALT with the MCP above: "..tostring(err))
if type(ns.B747_vnav_mcp_conflict) ~= "nil" then
    ok, err = pcall(function() return ns.B747_vnav_mcp_conflict.alt end)
    check(ok and err == 12000, "the conflict's altitude reads: "..tostring(err))
    ok, err = pcall(function() return ns.B747_vnav_mcp_conflict.missing end)
    check(ok and err == nil, "a missing index of B747_vnav_mcp_conflict reads nil: "..tostring(err))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("XTLua VNAV tables tests passed: "..checks)
