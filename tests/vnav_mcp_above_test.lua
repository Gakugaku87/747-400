-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] The MCP altitude set above the airplane in a VNAV descent: the airplane levels off where it is, FMA VNAV
-- ALT, the A/T on the speed - it neither climbs to the MCP altitude nor goes on descending (747-400 FCOM 4.10.7 and
-- 4.20.7: a conflict between the VNAV profile and the MCP altitude levels the airplane in VNAV ALT); a selector push
-- does not make VNAV climb. VNAV_DES_ALT kept VNAV_NEXT_ALT's target with the MCP more than 100 ft above, and the
-- descent went on to the next point's altitude (review 26 MINOR 4). In the approach (VNAV's approach path) the descent
-- goes on, the MCP set to the missed approach's altitude. tests/mcp_alt_dial_model.lua's closed loop: the production
-- knob, VNAV, FMA and altitude capture; a VNAV PTH descent at 12,000 ft toward TENK (6000, 30 nm), the MCP at 9000
-- dialled up to 13,000 (40 clicks from 1 s).
local M = dofile("tests/mcp_alt_dial_model.lua")
local route_north, dial = M.route_north, M.dial

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local function descent(alt, mcp)
    return function() return {alt = alt, vs = -2000, vs_cmd = -2000, mcp = mcp,
        route = route_north({{"TENK", 30, 6000}, {"DEST", 200, 0, 1}}),
        d = {B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_inDescent = 1, B747DR_ap_flightPhase = 3,
            simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 2, simDR_autopilot_alt_hold_status = 0,
            B747DR_ap_FMA_active_pitch_mode = 6, B747BR_totalDistance = 200, B747BR_tod = 300,
            B747DR_ap_thrust_mode = 0, B747DR_ap_FMA_autothrottle_mode = 2, simDR_airspeed_mach = 0.6,
            simDR_ind_airspeed_kts_pilot = 290, simDR_autopilot_airspeed_kts = 290, B747DR_ap_vnav_target_alt = 6000,
            B747DR_mcp_hold_pressed = -1000}} end
end

-- the MCP dialled from 9000 up to 13,000 at 12,000 ft
local res = M.run({setup = descent(12000, 9000), clicks = dial(1.0, 40, 1), seconds = 60})
local s = res.samples[#res.samples]
local lowest, highest = math.huge, -math.huge
for _, q in ipairs(res.samples) do
    if q.t >= 5 then lowest, highest = math.min(lowest, q.alt), math.max(highest, q.alt) end
end
check(lowest > 11000 and highest < 12100, string.format("the MCP set to 13,000 above the 747 at 12,000 ft: it levels "
    .."off, between %.0f and %.0f ft from 5 s (it neither climbs nor goes on descending)", lowest, highest))
check(s.alt_hold == 2 and math.abs(s.vs) < 200, string.format("held level at the end: alt_hold %s, V/S %.0f",
    tostring(s.alt_hold), s.vs))
check(s.fma == 5, string.format("FMA VNAV ALT (5) at the end, got %s", tostring(s.fma)))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV MCP above tests passed: "..checks)
