-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV SPD's descent (FLCH: the IAS window open above SPD TRANS) levels off at the STAR's constraints (their
-- floors) and at the MCP altitude only, as a real 747-400's VNAV SPD, and holds the level-off steadily: X-Plane holds
-- it (FMA VNAV PTH) until the fix is passed and the level-off moves below, then the idle descent goes on. It took
-- VNAV_NEXT_ALT's targets - every point's predicted altitude below the transition altitude too - and VNAV_DES put
-- FLCH back every 0.2 s while X-Plane held the level-off, so the FMA went VNAV SPD, VNAV PTH, VNAV SPD every 0.6 s
-- there (602 changes in 3 minutes; review 26 MINOR 2). tests/mcp_alt_dial_model.lua's closed loop: the production
-- VNAV, FMA and altitude capture, a kinematic vertical model; at FL250, 300 kt, toward FLOOR (at or above FL150, 25 nm
-- ahead) and NEXT (no constraint, the native FMS's 9000), the MCP at 5000, SPD TRANS at 3,000 ft.
local M = dofile("tests/mcp_alt_dial_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

-- SPD TRANS at 3,000 ft, so that VNAV SPD goes on below 10,000 ft
local FMS_DATA = {}
for k, v in pairs(M.FMS_DATA) do FMS_DATA[k] = v end
FMS_DATA.desspdtransalt = "3000"
local o
local function descent(pass)
    local function setup()
        o = {alt = 25000, vs = -2500, vs_cmd = -2500, mcp = 5000, active = 2, gs_ms = 230, ias = 300,
            fms_data = FMS_DATA,
            route = M.route_north({{"FLOOR", 25, 15000}, {"NEXT", 60, 9000}, {"DEST", 150, 0, 1}}),
            d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_inDescent = 1,
                B747DR_ap_flightPhase = 3, simDR_autopilot_flch_status = 2, simDR_autopilot_vs_status = 0,
                simDR_autopilot_alt_hold_status = 0, B747DR_ap_FMA_active_pitch_mode = 4, B747BR_totalDistance = 150,
                B747BR_tod = 300, B747DR_ap_thrust_mode = 2, B747DR_ap_FMA_autothrottle_mode = 2,
                simDR_airspeed_mach = 0.7, B747DR_ap_ias_mach_window_open = 1, simDR_ind_airspeed_kts_pilot = 300,
                simDR_autopilot_airspeed_kts = 300, B747DR_autothrottle_active = 1, B747DR_mcp_hold_pressed = -1000,
                B747DR_toggle_switch_position = setmetatable({}, {__index = function() return 1 end})}}
        return o
    end
    return M.run({setup = setup, seconds = pass + 300, each = function(d, t, ap)
        if t == 0 then
            rawset(ap, "B747_route_constraints", {[2] = {alt_desc = "+", floor = 15000, fl = true, phase = "descent"}})
        end
        d.B747DR_ap_ias_mach_window_open = 1
        if t >= pass and o.active == 2 then o.active = 3 end
    end})
end

local res = descent(400)
-- 1. the level-off at FLOOR's FL150, held steadily until the fix
local level, changes, lowest = nil, 0, math.huge
local last
for _, s in ipairs(res.samples) do
    if s.t < 400 then
        lowest = math.min(lowest, s.alt)
        if s.alt_hold == 2 and level == nil then level = s end
        if level and s.t >= level.t then
            if last ~= nil and s.fma ~= last then changes = changes + 1 end
            last = s.fma
        end
    end
end
check(level ~= nil and lowest > 14900, string.format("VNAV SPD levels off at FLOOR's FL150 (lowest %.0f ft before the "
    .."fix)", lowest))
check(changes <= 1, string.format("held steadily at FL150 until the fix: %d pitch-mode changes after the capture "
    .."(1: VNAV SPD to VNAV PTH)", changes))
-- 2. past the fix the idle descent goes on to the MCP's 5000, not levelling at NEXT's predicted 9000 (no constraint)
local other = nil
for _, s in ipairs(res.samples) do
    if s.t > 401 and s.alt > 5500 and s.afds ~= 5000 and other == nil then other = s end
end
check(other == nil, "past the fix VNAV SPD's level-off is the MCP's 5000"..(other and string.format(" (%s at %.0f ft, "
    .."%.0f s)", tostring(other.afds), other.alt, other.t) or ""))
check(res.alt < 5300, string.format("the descent goes on to the MCP's 5000: %.0f ft at the end", res.alt))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV SPD descent tests passed: "..checks)
