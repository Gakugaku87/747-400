-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV PTH's descent through the route's points below the transition altitude, as a real 747-400's: the
-- AFDS's altitude is the MCP's (the clearance), the points' altitudes and the STAR's constraints shape the path
-- (crossing SUGOL inside its FL100-FL140 window at its path altitude, NETOM at or above FL070), and the descent goes
-- on through them without a level-off or a change of the A/T's mode. VNAV_NEXT_ALT made each point's altitude below
-- the transition altitude (and the CIFP's floors) the AFDS's level-off, so the energy mode let go 600 ft above each
-- point and the A/T went from SPD to IDLE and HOLD (p27-line1: 13 of the descent's 16 A/T changes at ETPOS, SUGOL and
-- NETOM). The production autopilot, VNAV, energy mode, pitch director and A/T in approach_model.lua's closed loop, on
-- the EHAM route (transition altitude 18000 ft) from 12 nm before SUGOL at its path's altitude, the MCP at 2000 ft,
-- VNAV's speed 250 kt (SPD TRANS 250/10000: deceleratedDesent's -500 fpm for a speed above the transition's, which
-- the model's fixed VNAV speed never meets, is not what this is about).
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local SUGOL, NETOM = 5, 6
local o = model.eham({active = SUGOL, start_nm = 12, alt_ft = 11315 + 12 * (16752 - 11315) / 20.5, ias_kt = 250,
    vs_fpm = -1300, flaps = 0, mcp_alt_ft = 2000, vnav_speed_kt = 250, at_mode = 3, tod_before = {2, 30},
    app_nm = 0, seconds = 420, stop_agl_ft = 6000, weight_kg = 250000,
    fms_data = {desspdtransalt = "10000", destranspd = "250", desspd = "270", desrestspd = "---",
        desrestalt = "-----", transalt = "18000", crzalt = "FL370"}})
local m = model.fly(o)
local route = o.route

-- the samples before the approach's path (26 nm of the route to go)
local en_route = {}
for _, q in ipairs(m.track) do
    if q.t >= 10 and q.dist_thr > 26 then en_route[#en_route + 1] = q end
end
check(#en_route > 200, string.format("the descent was flown en route for %d samples", #en_route))

-- 1. the AFDS's altitude is the MCP's
local other = {}
for _, q in ipairs(en_route) do
    if q.ap_alt ~= 2000 then other[#other + 1] = string.format("%.0f at %.0f s", q.ap_alt, q.t) end
end
check(#other == 0, "the AFDS's altitude stays the MCP's 2000 ft through the points ("..#other.." samples off: "
    ..table.concat({other[1] or "", other[#other] or ""}, ", ")..")")

-- 2. the energy mode stays on, and the A/T's mode stays the same once settled from the start (40 s)
local off, changes, last = 0, 0, nil
for _, q in ipairs(en_route) do
    if q.energy ~= 1 then off = off + 1 end
    if q.t >= 40 then
        if last ~= nil and q.at_mode ~= last then changes = changes + 1 end
        last = q.at_mode
    end
end
check(off == 0 and changes == 0, string.format(
    "through SUGOL and NETOM the energy mode stays on (%d samples off) and the A/T's mode the same (%d changes)",
    off, changes))

-- 3. each point crossed on its path, inside its constraint, without levelling off
local function abeam(index)
    local best, best_q = math.huge, nil
    for _, q in ipairs(m.track) do
        local d = math.abs(q.dist_thr - (m.cum[m.runway] - m.cum[index]))
        if d < best then best, best_q = d, q end
    end
    return best_q
end
local function slowest_vs(t0, t1)
    local slowest = math.huge
    for _, q in ipairs(m.track) do
        if q.t >= t0 and q.t <= t1 then slowest = math.min(slowest, math.abs(q.vs)) end
    end
    return slowest
end
local s, n = abeam(SUGOL), abeam(NETOM)
check(s ~= nil and s.alt >= 10000 and s.alt <= 14000 and math.abs(s.alt - route[SUGOL][9]) <= 200, string.format(
    "SUGOL crossed at %.0f ft (its window FL100-FL140, its path %d +- 200)", s and s.alt or -1, route[SUGOL][9]))
check(n ~= nil and n.alt >= 7000 and math.abs(n.alt - route[NETOM][9]) <= 200, string.format(
    "NETOM crossed at %.0f ft (at or above FL070, its path %d +- 200)", n and n.alt or -1, route[NETOM][9]))
for _, p in ipairs({{"SUGOL", s}, {"NETOM", n}}) do
    if p[2] then
        local v = slowest_vs(p[2].t - 30, p[2].t + 30)
        check(v >= 500, string.format("no level-off at %s: the V/S at least 500 fpm within 30 s of it (slowest %.0f)",
            p[1], v))
    end
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV descent points tests passed: "..checks)
