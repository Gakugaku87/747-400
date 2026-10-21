-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The roll rate of HDG SEL and LNAV turns. X-Plane's HDG SEL makes the roll
-- command (sim/cockpit2/autopilot/flight_director_roll_deg) and the 747
-- filters it (adaptive_roll_filter, B747.19.xt.hydraulics_afds_helpers.lua)
-- before its roll PID flies it. Outside the approach the filtered command
-- moves at most 3 deg/s; the approach (LOC, autoland) keeps its response.
-- The kit's 2026-10-11 recordings (final3-L1 HDG tests at FL310, line4 DW129
-- and NETOM at 5,000-8,000 ft) give the models flown here: X-Plane's command
-- is 0.165 x GS / g deg per deg of heading error (at most the 20 deg bank
-- limit) slewed at 5.9 deg/s, and the bank follows the filtered command as a
-- second order with 0.1 s delay, underdamped at FL310 (wn 3.2 rad/s, zeta
-- 0.22) and damped at 5,000 ft (wn 4.7, zeta 0.73). Before the limit the
-- filter slewed up to 25 deg/s and the roll rate peaked at 7.2-8.7 deg/s
-- (1 s mean 7.1-7.9) at FL310, 6.5-7.1 deg/s at 5,000 ft.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")

local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local MAX_RATE = 3.0     -- deg/s, the filtered command outside the approach

-- 1. The filter itself: the fastest change of the filtered command over 4 s
-- of frames at 20, 30 and 60 fps.
local function fastest(from, to, fps, approach)
    local value, worst = from, 0
    for _ = 1, 4 * fps do
        local new = controls.adaptive_roll_filter(value, to, 1 / fps, approach)
        worst = math.max(worst, math.abs(new - value) * fps)
        value = new
    end
    return worst, value
end
for _, fps in ipairs({20, 30, 60}) do
    for _, case in ipairs({{"roll in to 20 deg", 0, 20}, {"6 deg", 0, 6}, {"reversal 20 to -20 deg", 20, -20},
            {"roll out from 20 deg", 20, 0}}) do
        local rate = fastest(case[2], case[3], fps, false)
        check(rate <= MAX_RATE + 1e-6, string.format("%s at %d fps outside the approach: %.2f deg/s (at most %.1f)",
            case[1], fps, rate, MAX_RATE))
    end
    -- the approach keeps its response (8 deg/s): the LOC capture is not slowed
    local rate, reached = fastest(0, 20, fps, true)
    check(rate > 6 and reached > 19, string.format("approach at %d fps: %.2f deg/s, %.1f deg after 4 s", fps, rate, reached))
end
-- a held command is reached, and a small error is still followed smoothly
local value = 0
for _ = 1, 30 * 12 do value = controls.adaptive_roll_filter(value, 20, 1 / 30, false) end
check(math.abs(value - 20) < 0.01, string.format("20 deg reached within 12 s: %.3f", value))

-- 2. Closed loop: X-Plane's HDG SEL, the production filter and the fitted
-- bank response turn the aircraft. The kit judges the roll rate as a 1 s
-- centred mean (WARN 7 deg/s).
local G, KT = 9.80665, 0.514444
local FL310 = {name = "FL310", tas = 478, wn = 3.2, zeta = 0.22}
local LOW = {name = "5,000 ft", tas = 260, wn = 4.7, zeta = 0.73}
local function wrap(a) return (a + 180) % 360 - 180 end
local function turn(c, target, reverse_to, seconds)
    local dt, delay = 1 / 30, 0.1
    local heading, bank, rate, command, filtered = 0, 0, 0, 0, 0
    local history, rates = {}, {}
    local v = c.tas * KT
    local overshoot, t_capture, reversed = 0, nil, false
    local direction = target >= 0 and 1 or -1
    for i = 1, math.floor(seconds / dt) do
        local t = i * dt
        if reverse_to and not reversed and math.abs(bank) > 15 then
            target, reversed = reverse_to, true
            direction = wrap(target - heading) >= 0 and 1 or -1
        end
        local err = wrap(target - heading)
        local want = math.max(-20, math.min(20, 0.165 * v / G * err))
        command = command + math.max(-5.9 * dt, math.min(5.9 * dt, want - command))
        filtered = controls.adaptive_roll_filter(filtered, command, dt, false)
        history[#history + 1] = filtered
        local u = history[math.max(1, #history - math.floor(delay / dt + 0.5))]
        rate = rate + (c.wn * c.wn * (u - bank) - 2 * c.zeta * c.wn * rate) * dt
        bank = bank + rate * dt
        heading = heading + math.deg(G * math.tan(math.rad(bank)) / v) * dt
        rates[#rates + 1] = rate
        if not reverse_to or reversed then
            overshoot = math.max(overshoot, -direction * wrap(target - heading))
            if not t_capture and math.abs(wrap(target - heading)) < 2 then t_capture = t end
        end
    end
    local n, peak = math.floor(0.5 / dt + 0.5), 0
    for i = 1, #rates do
        local sum, count = 0, 0
        for j = math.max(1, i - n), math.min(#rates, i + n) do sum, count = sum + rates[j], count + 1 end
        peak = math.max(peak, math.abs(sum / count))
    end
    return peak, overshoot, t_capture
end
for _, c in ipairs({FL310, LOW}) do
    for _, case in ipairs({{"HDG +5", 5, nil, 60, 15}, {"HDG +20", 20, nil, 90, 40}, {"HDG +90", 90, nil, 200, 125},
            {"HDG +60 reversed to -60", 60, -60, 260, 200}}) do
        local peak, overshoot, t_capture = turn(c, case[2], case[3], case[4])
        check(peak <= 4.5, string.format("%s %s: roll rate %.2f deg/s (1 s mean, at most 4.5)", c.name, case[1], peak))
        check(overshoot <= 1.0, string.format("%s %s: heading overshoot %.2f deg (at most 1)", c.name, case[1], overshoot))
        check(t_capture and t_capture <= case[5], string.format("%s %s: within 2 deg after %s s (at most %d s)",
            c.name, case[1], tostring(t_capture and math.floor(t_capture * 10 + 0.5) / 10), case[5]))
    end
end

print("AFDS roll rate limit tests passed: "..checks)
