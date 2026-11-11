-- Run from the repository root with LuaJIT: luajit tests/autopilot/spd_step_tool_test.lua
-- The flight-test recording's speed changes (2026-11-12; docs/overhaul/
-- notes/ATA-22.md §62): tests/flight/tools/spd_step.lua's analyse on rows
-- made here (no file, no X-Plane): a step of the target against the way
-- kept near level (PASS) and not (the flight's -850 fpm: FAIL), a descent's
-- deceleration, a change ended by the next one or by the mode's end (still
-- checked on the vertical speed and the altitude), the mode beginning off
-- its target, no step taken from the mode before or from a target that
-- moves slowly, the way without the FMC's phase and not known, a change
-- that begins past near level, a change along the way (no check).
local T = dofile("tests/lib/check.lua")("spd_step_tool")
local S = dofile("tests/flight/tools/spd_step.lua")

-- rows every 0.1 s for `secs`: at(t) gives {fma, tgt, vs, ias, mcp, phase};
-- the altitude from the vertical speed
local function build(secs, at, alt0)
    local rows, alt = {}, alt0 or 10000
    for n = 0, math.floor(secs * 10 + 0.5) do
        local t = n / 10
        local x = at(t)
        alt = alt + x.vs / 60 * 0.1
        rows[#rows + 1] = {t = t, alt = alt, ias = x.ias, vs = x.vs, tgt = x.tgt, fma = x.fma, mcp = x.mcp,
            phase = x.phase, weight = 347500}
    end
    return rows
end
local function ramp(t, t0, t1, a, b)
    if t <= t0 then return a elseif t >= t1 then return b end
    return a + (b - a) * (t - t0) / (t1 - t0)
end

-- VNAV SPD's climb: the target 272 to 340 kt at 10 s, the vertical speed
-- down to `floor` fpm in 15 s and up again from 75 s, the speed a knot a
-- second from 12 s
local function climb(floor, o)
    o = o or {}
    return build(o.secs or 150, function(t)
        local vs = t < 75 and ramp(t, 10, 25, 2000, floor) or ramp(t, 75, 90, floor, 2000)
        return {fma = o.fma or 4, phase = o.phase, mcp = o.mcp, tgt = t < 10 and 272 or 340, vs = vs,
            ias = math.min(340, 272 + math.max(0, t - 12))}
    end)
end
local c = S.analyse(climb(100, {phase = 1}))
T.equal(#c, 1, "a step of the target in VNAV SPD's climb: one change")
T.check(c[1].from == 272 and c[1].to == 340 and c[1].way == 1 and c[1].against, "272 to 340 kt, the way up, against it")
T.near(c[1].t, 10, 0.05, "at 10 s")
T.near(c[1].lo, 100, 1, "the vertical speed's least 100 fpm")
T.near(c[1].t5, 65, 0.2, "within 5 kt after 65 s")
T.near(c[1].t1, 69, 0.2, "within 1 kt after 69 s")
T.check(c[1].lost == 0 and c[1].ended == "within" and c[1].ok == true, "near level kept: PASS")
T.check(S.lines(1, c[1])[4]:find("PASS", 1, true) ~= nil, "the report's line says so")
-- the flight's: down to -850 fpm
c = S.analyse(climb(-850, {phase = 1}))
T.check(#c == 1 and c[1].ok == false, "down to -850 fpm: FAIL")
T.check(c[1].lo < -800 and c[1].lost > 100, ("  %.0f fpm at the least, %.0f ft lost"):format(c[1].lo, c[1].lost))
-- 60 fpm under level flight for a while: past the 50 fpm
c = S.analyse(climb(-60, {phase = 1}))
T.check(c[1].ok == false, "60 fpm under level flight: FAIL")
c = S.analyse(climb(-40, {phase = 1}))
T.check(c[1].lost > S.PAST_FT and c[1].ok == false, ("40 fpm under level flight for 50 s: %.0f ft lost, FAIL"):format(c[1].lost))
c = S.analyse(climb(0, {phase = 1}))
T.check(c[1].ok == true, "level flight: PASS")
-- a least change of 80 kt asked for: none
T.equal(#S.analyse(climb(100, {phase = 1}), 80), 0, "a least change of 80 kt: none found")

-- without the FMC's phase (a recorder before v8): the way to the MCP altitude
c = S.analyse(climb(100, {mcp = 31000}))
T.check(c[1].way == 1 and c[1].against and c[1].ok == true, "no FMC phase in the recording: the way to the MCP altitude")
-- neither: not known, no check
c = S.analyse(climb(-850, {}))
T.check(c[1].way == 0 and not c[1].against and c[1].ok == nil, "no FMC phase nor MCP altitude: the way not known, no check")
T.check(S.lines(1, c[1])[4]:find("not known", 1, true) ~= nil, "  and the report says so")
-- VNAV SPD in the FMC's descent, the speed up: along the way, no check
c = S.analyse(climb(-850, {phase = 3}))
T.check(c[1].way == -1 and not c[1].against and c[1].ok == nil, "faster in a descent: along the way, no check")

-- FLCH's descent: 300 to 250 kt at 10 s, the vertical speed up to `ceil`
local function descent(ceil)
    return build(120, function(t)
        local vs = t < 60 and ramp(t, 10, 25, -2200, ceil) or ramp(t, 60, 75, ceil, -1800)
        return {fma = 8, mcp = 5000, tgt = t < 10 and 300 or 250, vs = vs, ias = math.max(250, 300 - math.max(0, t - 12))}
    end, 15000)
end
c = S.analyse(descent(-100))
T.check(#c == 1 and c[1].way == -1 and c[1].against and c[1].ok == true, "FLCH's descent, 300 to 250 kt, -100 fpm at the most: PASS")
T.near(c[1].hi, -100, 1, "  the vertical speed's most -100 fpm")
c = S.analyse(descent(500))
T.check(c[1].ok == false and c[1].gained > 50, ("  up to +500 fpm: FAIL (%.0f ft gained)"):format(c[1].gained))

-- two steps, the second 10 s after the first: the first ended by it and
-- still checked on the vertical speed and the altitude
local two = build(150, function(t)
    return {fma = 4, phase = 1, tgt = t < 10 and 250 or (t < 20 and 272 or 340), vs = ramp(t, 10, 30, 1500, 100),
        ias = math.min(340, 250 + math.max(0, t - 12))}
end)
c = S.analyse(two)
T.equal(#c, 2, "two steps 10 s apart: two changes")
T.check(c[1].to == 272 and c[1].ended == "change" and c[1].t5 == nil and c[1].ok == true,
    "the first ended by the next change before its speed: checked all the same, PASS")
T.check(c[2].from == 272 and c[2].to == 340 and c[2].ok == true, "the second: 272 to 340 kt, PASS")
T.check(S.lines(1, c[1])[2]:find("until the next change", 1, true) ~= nil, "  the report: until the next change")
-- the mode's end (the altitude captured) before the speed
local cap = build(60, function(t)
    return {fma = t < 40 and 4 or 9, phase = 1, tgt = t < 10 and 272 or 340, vs = ramp(t, 10, 25, 1700, 110),
        ias = 272 + math.max(0, t - 12) * 0.9}
end)
c = S.analyse(cap)
T.check(#c == 1 and c[1].ended == "mode" and c[1].ok == true, "the mode's end before the speed: checked all the same, PASS")

-- FLCH pushed in level flight with 340 kt set (the dial at 340 before it):
-- the mode begins off its target
local push = build(120, function(t)
    return {fma = t < 10 and 9 or 8, mcp = 35000, tgt = 340, vs = t < 10 and 0 or ramp(t, 10, 20, 0, 100),
        ias = math.min(340, 250 + math.max(0, t - 12))}
end)
c = S.analyse(push)
T.check(#c == 1 and c[1].from == 250 and c[1].to == 340 and c[1].against and c[1].ok == true,
    "FLCH pushed 90 kt under its speed: a change from the airspeed, PASS")
-- ALT with the dial at 250 kt, then VNAV SPD on its protected target (272
-- kt, the airplane on it, the target a little on the move): no step from
-- the mode before
local prot = build(60, function(t)
    return {fma = t < 10 and 9 or 4, phase = 1, tgt = t < 10 and 250 or 272 + (t - 10) * 0.01, vs = 1500, ias = 272}
end)
T.equal(#S.analyse(prot), 0, "the target of the mode before is no step's start")
-- a Mach held: the target 0.33 kt a second down: no change
local mach = build(120, function(t) return {fma = 8, mcp = 35000, tgt = 300 - 0.33 * t, vs = 2500, ias = 300 - 0.33 * t} end)
T.equal(#S.analyse(mach), 0, "a target moving 0.33 kt a second: no change")

-- FLCH up pushed in a descent of 1,500 fpm, 20 kt under its speed: the law
-- brings the vertical speed up; checked from where it is back within 50
-- fpm of level flight
local function from_descent(to_vs, secs_up)
    return build(120, function(t)
        return {fma = t < 10 and 7 or 8, mcp = 20000, tgt = 300, vs = t < 10 and -1500 or ramp(t, 10, 10 + secs_up, -1500, to_vs),
            ias = math.min(300, 280 + math.max(0, t - 30) * 0.5)}
    end)
end
c = S.analyse(from_descent(100, 20))
T.check(#c == 1 and c[1].vs0 < -1400 and c[1].lost > 100 and c[1].ok == true,
    ("pushed in a 1,500 fpm descent: the %.0f ft lost coming up are not the check's, PASS"):format(c[1].lost))
c = S.analyse(from_descent(-300, 20))
T.check(c[1].ok == nil, "never back within 50 fpm of level flight: no check")
T.check(S.lines(1, c[1])[4]:find("no check", 1, true) ~= nil, "  and the report says so")
T.done()
