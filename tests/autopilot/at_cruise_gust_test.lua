-- Run from the repository root with LuaJIT: luajit tests/autopilot/at_cruise_gust_test.lua
-- The A/T's SPD in the cruise's gusts (2026-11-10; docs/overhaul/notes/
-- ATA-34-61-FMC.md §162): the A/T model (B747.70.at_model.lua) closed on
-- the airplane of PERF_SIMBRIEF's KSEA-KLAX (2026-11-09, FL390, M.859,
-- 239 t): each engine 88.66 kN per unit of EPR over 1 (the record's fit),
-- the EEC's EPR 1.17 + 0.63 of the levers 1.25 s behind them (the levers'
-- and the EPR's live reads), the drag's slope 0.68 kN a kt of TAS (FCOM's
-- +2.5 % for M+.01), IAS/TAS 0.5526; the air's along-track wind from the
-- record (tests/flight/data/gusts/ksea_klax_fl390.txt: X-Plane's real
-- weather, gusts of 1.3 kt). On the IAS (before) the levers followed each
-- gust and the speed sat over its target (X-Plane: +0.7 kt, 83 % of the
-- time); complemented by the inertial acceleration the levers move a
-- seventh as much and the speed sits on the target, its spread the same.
-- In still air the same as before (a new target); a shear comes in over
-- GUST_TAU (FCOM p.214: speed excursions in turbulence are expected).
local T = dofile("tests/lib/check.lua")("at_cruise_gust")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")
local KT = 1852 / 3600
local DT = 0.05
local K_IT, TGT = 0.5526, 269.61
local TAS0, D0 = TGT / K_IT, 4 * 88657 * 0.4367

local rt, rw = {}, {}
for line in io.lines("tests/flight/data/gusts/ksea_klax_fl390.txt") do
    local a, b = line:match("^([%d%.]+)%s+([%-%d%.]+)")
    if a then rt[#rt + 1], rw[#rw + 1] = tonumber(a), tonumber(b) end
end
T.check(#rt > 1200, string.format("the record's 21 minutes (%d samples)", #rt))
local function record_wind()
    local j = 1
    return function(t)
        while j < #rt - 1 and rt[j + 1] < t do j = j + 1 end
        local f = math.max(0, math.min(1, (t - rt[j]) / (rt[j + 1] - rt[j])))
        return rw[j] + f * (rw[j + 1] - rw[j])
    end
end

-- opt.wind fn(t), opt.target fn(t), opt.seconds, opt.inertial (the TAS and
-- the inertial acceleration given), opt.skip; r: the IAS's error's mean and
-- spread, the time over the target, the levers' travel a minute (on 0.6 s
-- reads), the IAS's errors' extremes, trace (t, error) each 0.5 s
local function run(opt)
    local wind = opt.wind
    local vg = TAS0 - wind(0)
    local lever = (D0 / (4 * 88657) + 1 - 1.17) / 0.63
    local epr = 1.17 + 0.63 * lever
    local as = A.new()
    A.update(as, {arm = true, ok = true, ground = false, cas = TGT, ra = 39000, flaps_up = true,
        reverse = false, limit_to = false, limit_ga = false, pitch = "VNAV", retard = false,
        vnav_at = A.SPD, vnav_level = true, lever_idle = false})
    local ai = {dt = DT, n1 = false, thrust_ref = 1.517, v_max = 291, v_min = 230, flaps_up = true,
        vs = 0, alt = 39000, mcp_alt = 39000, ivs = 0, evs = 0}
    local last_ias, accel, last_vg = nil, 0, vg
    local r = {n = 0, sum = 0, sq = 0, over = 0, travel = 0, lo = 99, hi = -99, trace = {}}
    local last_read, next_read = lever, 0
    local skip = opt.skip or 60
    for n = 1, math.floor(opt.seconds / DT + 0.5) do
        local t = n * DT
        local tas = vg + wind(t)
        local ias = tas * K_IT
        if last_ias then accel = accel + ((ias - last_ias) / DT - accel) * math.min(1, DT / 0.5) end
        last_ias = ias
        local target = opt.target and opt.target(t) or TGT
        ai.ias, ai.accel, ai.target, ai.lever, ai.thrust = ias, accel, target, lever, 1.17 + 0.63 * lever
        if opt.inertial then ai.tas, ai.accel_in = tas, (vg - last_vg) / DT end
        last_vg = vg
        A.servo(as, ai)
        lever = as.cmd
        epr = epr + ((1.17 + 0.63 * lever) - epr) * DT / 1.25
        vg = vg + (4 * 88657 * (epr - 1) - (D0 + 680 * (tas - TAS0))) / 239000 / KT * DT
        if t >= skip then
            local e = ias - target
            r.n, r.sum, r.sq = r.n + 1, r.sum + e, r.sq + e * e
            if e > 0 then r.over = r.over + 1 end
            r.lo, r.hi = math.min(r.lo, e), math.max(r.hi, e)
            if t >= next_read then
                r.travel, last_read, next_read = r.travel + math.abs(lever - last_read), lever, t + 0.6
            end
            if n % 10 == 0 then r.trace[#r.trace + 1] = {t, e} end
        end
    end
    r.mean = r.sum / r.n
    r.sd = math.sqrt(math.max(0, r.sq / r.n - r.mean ^ 2))
    r.over = r.over / r.n
    r.travel = r.travel / (opt.seconds - skip) * 60
    return r
end

-- the record's gusts: on the IAS and complemented
local a = run({wind = record_wind(), seconds = 1200})
local b = run({wind = record_wind(), seconds = 1200, inertial = true})
T.check(a.mean > 0.6 and a.over > 0.8, string.format(
    "on the IAS (before): the speed %+.2f kt over its target, %.0f %% of the time over (X-Plane +0.7 kt, 83 %%)",
    a.mean, 100 * a.over))
T.check(a.travel > 0.25, string.format("  the levers' travel %.3f of their range a minute (X-Plane's live 150 s 0.17)", a.travel))
T.check(b.travel < a.travel / 4, string.format("complemented: the levers' travel %.3f a minute (under a quarter)", b.travel))
T.check(math.abs(b.mean) < 0.3, string.format("  the speed %+.2f kt from its target", b.mean))
T.check(b.sd <= a.sd + 0.05, string.format("  its spread %.2f kt (on the IAS %.2f)", b.sd, a.sd))
T.check(b.lo > -3 and b.hi < 4, string.format("  within %+.1f..%+.1f kt", b.lo, b.hi))
-- still air, the target 5 kt up at 60 s: the same as on the IAS
local function still() return 40 end
local function up5(t) return t < 60 and TGT or TGT + 5 end
local c = run({wind = still, target = up5, seconds = 400, skip = 0})
local d = run({wind = still, target = up5, seconds = 400, skip = 0, inertial = true})
local function overshoot(r)
    local m = -99
    for _, x in ipairs(r.trace) do if x[1] > 60 then m = math.max(m, x[2]) end end
    return m
end
T.near(overshoot(d), overshoot(c), 0.02, string.format(
    "still air, the target 5 kt up: the overshoot as on the IAS (%+.2f, %+.2f kt)", overshoot(d), overshoot(c)))
T.near(d.mean, c.mean, 0.01, "  the same errors throughout")
-- a shear: the headwind 10 kt less over 30 s from 60 s on, held
local function shear(t) return 40 - 10 * math.max(0, math.min(1, (t - 60) / 30)) end
local e = run({wind = shear, seconds = 600, skip = 0, inertial = true})
local f = run({wind = shear, seconds = 600, skip = 0})
local back
for _, x in ipairs(e.trace) do if x[1] > 100 and not back and math.abs(x[2]) <= 1 then back = x[1] - 60 end end
T.check(e.lo > -5, string.format("a 10 kt shear over 30 s: %.1f kt slow at most (on the IAS %.1f)", e.lo, f.lo))
T.check(back and back < 80, string.format("  within 1 kt again %s s after it began", back and string.format("%.0f", back) or "never"))
T.done()
