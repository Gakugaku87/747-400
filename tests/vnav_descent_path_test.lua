-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV PTH's descent between the route's points: its V/S follows the path the
-- path error is measured from. With the MCP above 5,000 ft it aimed 250 ft
-- below each point, reached the point's altitude before the point and levelled
-- off to it (the target then above: a climb, held at 0 V/S) 230-270 ft below
-- the path, and climbed back with thrust after the point: the A/T SPD, IDLE,
-- HOLD, SPD... at every point of EIDW-EHAM's descent (p21-line1: 37 changes,
-- every 95-105 s). The vertical bearing is from the aircraft to the point.
-- The production autopilot, VNAV, energy mode, pitch director and A/T in
-- approach_model.lua's closed loop, on the EHAM route from 15 nm before LAMSO
-- at 270 kt with the MCP at 7,000 ft.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local m = model.fly(model.eham({active = 3, start_nm = 15, alt_ft = 21438 + 15 * (26309 - 21438) / 18.3,
    ias_kt = 270, vs_fpm = -1900, flaps = 0, mcp_alt_ft = 7000, vnav_speed_kt = 270, at_mode = 1,
    tod_before = {2, 30}, app_nm = 0, seconds = 500, stop_agl_ft = 8000, weight_kg = 250000}))
-- from 150 s, the path captured, to 500 s (LAMSO, ETPOS and on towards SUGOL), between the points: from 70 s after
-- each new target (here the energy mode lets go within 600 ft above the AP altitude, the point's, before the point)
local low, high, sum, n, target, since = 1e9, -1e9, 0, 0, nil, 0
for _, q in ipairs(m.track) do
    if q.target ~= target then target, since = q.target, q.t end
    if q.t >= 150 and q.t - since >= 70 and q.energy == 1 then
        low, high, sum, n = math.min(low, q.fpe), math.max(high, q.fpe), sum + q.fpe, n + 1
    end
end
check(n > 250 and low >= -100 and high <= 100, string.format(
    "the path error between the points from 150 s: %+.0f to %+.0f ft (+-100) in %d samples", low, high, n))
check(n > 0 and math.abs(sum / n) <= 40, string.format("the mean path error between the points: %+.0f ft (+-40)",
    n > 0 and sum / n or 0))
-- the vertical bearing at the end: from the aircraft to the point (as a real FMC's VB)
local d = m.d
local feet = math.max(d.B747DR_fmstargetDistance, 1) * 6076.12
local vb = math.atan2(d.B747DR_ap_vnav_target_alt - d.simDR_pressureAlt1, feet) * -57.2958
check(math.abs(d.B747DR_ap_vb - vb) <= 0.05, string.format(
    "the vertical bearing %.2f deg, from the aircraft at %.0f ft to %.0f ft in %.1f nm: %.2f", d.B747DR_ap_vb,
    d.simDR_pressureAlt1, d.B747DR_ap_vnav_target_alt, d.B747DR_fmstargetDistance, vb))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV descent path tests passed: "..checks)
