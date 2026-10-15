-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The lateral path of a fly-by fix for LNAV's path guidance (item i-1b): the
-- inbound leg, the arc of radius R tangent to both legs R tan(turn / 2) from
-- the fix, and the outbound leg, in east/north nm from the fix. The aircraft's
-- signed cross-track from that path (+ right of it; from the arc while on it,
-- as the PROGRESS page's XTK should read in the turn), the path's course
-- there, and the point a look-ahead distance further along the path that a
-- pure-pursuit guidance aims at (on a straight leg at most 45 deg off its
-- course: the look-ahead is never shorter than the cross-track). Pure
-- geometry from afds_helpers; nothing in the aircraft uses it yet.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function near(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function wrap(a) return (a + 180) % 360 - 180 end

local path = afds.lnav_path_at

-- 1. A 90 deg right turn (in 000, out 090), R 2 nm: the arc from (0, -2) to (2, 0), centre (2, -2).
local p = path(0, -10, 0, 90, 2, 2)
check(p ~= nil, "a path for the 90 deg right turn")
near(p.xtk_nm, 0, 1e-9, "on the inbound leg: no cross-track")
check(p.element == "in", "10 nm before the fix: the inbound leg")
near(p.course_deg, 0, 1e-9, "the inbound leg's course")
near(p.aim_east_nm, 0, 1e-9, "aim on the inbound leg (east)")
near(p.aim_north_nm, -8, 1e-9, "aim 2 nm further along it")
near(p.arc_start_nm, 2, 1e-9, "the arc starts R tan(45) = 2 nm before the fix")

p = path(0.5, -10, 0, 90, 2, 2)
near(p.xtk_nm, 0.5, 1e-9, "0.5 nm right of the inbound leg")
near(wrap(math.deg(math.atan2(p.aim_east_nm - 0.5, p.aim_north_nm + 10))), -14.04, 0.01,
    "aim back to the leg: atan(0.5 / 2) to the left")

p = path(-6, -20, 0, 90, 2, 2)
near(p.xtk_nm, -6, 1e-9, "6 nm left of the inbound leg")
near(wrap(math.deg(math.atan2(p.aim_east_nm + 6, p.aim_north_nm + 20))), 45, 1e-6,
    "6 nm off with a 2 nm look-ahead: the intercept is 45 deg")

-- on the arc: its middle, the point of the bisector (0.586, -0.586)
local m = 2 - math.sqrt(2)
p = path(m, -m, 0, 90, 2, 0.5)
check(p.element == "arc", "the arc's middle is on the arc")
near(p.xtk_nm, 0, 1e-9, "on the arc: no cross-track")
near(p.course_deg, 45, 1e-9, "the arc's course at its middle is 045")
-- 0.5 nm further along the arc: 0.25 rad further round the centre
near(p.aim_east_nm, 2 + 2 * math.sin(math.rad(270) + math.rad(45) + 0.25), 1e-9, "aim along the arc (east)")
near(p.aim_north_nm, -2 + 2 * math.cos(math.rad(270) + math.rad(45) + 0.25), 1e-9, "aim along the arc (north)")

-- the fix itself lies outside the arc, left of the path: R - |C - fix| = 2 - 2.828
p = path(0, 0, 0, 90, 2, 2)
check(p.element == "arc", "the fix is abeam the arc")
near(p.xtk_nm, 2 - 2 * math.sqrt(2), 1e-9, "the fix is 0.83 nm left of (outside) the arc")
-- inside the arc, right of the path
p = path(1.5, -1.5, 0, 90, 2, 2)
near(p.xtk_nm, 2 - math.sqrt(0.5), 1e-9, "inside the arc: right of the path")

-- on the outbound leg
p = path(5, 0.3, 0, 90, 2, 2)
check(p.element == "out", "5 nm past the fix: the outbound leg")
near(p.xtk_nm, -0.3, 1e-9, "0.3 nm north of an eastbound leg is left of it")
near(p.course_deg, 90, 1e-9, "the outbound leg's course")
near(p.aim_east_nm, 7, 1e-9, "aim 2 nm further along the outbound leg")
near(p.aim_north_nm, 0, 1e-9, "aim on the outbound leg")

-- 2. The aim point runs from the inbound leg onto the arc, and from the arc onto the outbound leg.
p = path(0, -3, 0, 90, 2, 2)
check(p.element == "in", "1 nm before the arc: the inbound leg")
-- 1 nm along the leg to the arc's start, then 1 nm (0.5 rad) round it
near(p.aim_east_nm, 2 - 2 * math.cos(0.5), 1e-9, "aim 1 nm onto the arc (east)")
near(p.aim_north_nm, -2 + 2 * math.sin(0.5), 1e-9, "aim 1 nm onto the arc (north)")
local arc_len = 2 * math.pi / 2
p = path(2 - 2 * math.cos(arc_len / 2 - 0.5), -2 + 2 * math.sin(arc_len / 2 - 0.5), 0, 90, 2, 1)
check(p.element == "arc", "on the arc near its end")
p = path(2 - 2 * math.cos(math.pi / 2 - 0.25), -2 + 2 * math.sin(math.pi / 2 - 0.25), 0, 90, 2, 1)
-- 0.5 nm (0.25 rad) to the arc's end at (2, 0), then 0.5 nm along the outbound leg
near(p.aim_east_nm, 2.5, 1e-9, "aim 0.5 nm onto the outbound leg (east)")
near(p.aim_north_nm, 0, 1e-9, "aim on the outbound leg (north)")

-- 3. A left turn mirrors it: in 000, out 270, the centre at (-2, -2).
p = path(-m, -m, 0, 270, 2, 0.5)
check(p.element == "arc", "the left arc's middle")
near(p.xtk_nm, 0, 1e-9, "on the left arc")
near(p.course_deg, 315, 1e-9, "the left arc's course at its middle is 315")
p = path(0, 0, 0, 270, 2, 2)
near(p.xtk_nm, 2 * math.sqrt(2) - 2, 1e-9, "the fix is outside the left arc: right of the path")

-- 4. No turn: one straight line through the fix.
p = path(0.2, 3, 90, 90, 2, 2)
check(p.element == "out", "past a fix with no turn: the leg after it")
near(p.xtk_nm, -3, 1e-9, "3 nm north of an eastbound leg")
near(p.arc_start_nm, 0, 1e-9, "no turn, no arc")
p = path(0.2, 3, 90, 90.5, 2, 2)
near(p.arc_start_nm, 2 * math.tan(math.rad(0.25)), 1e-9, "a 0.5 deg turn: a tiny arc")

-- 5. A 150 deg turn: the arc starts R tan(75) = 3.73 R before the fix.
p = path(0, -20, 0, 150, 2, 2)
near(p.arc_start_nm, 2 * math.tan(math.rad(75)), 1e-9, "150 deg: R tan(75) before the fix")
p = path(0, -20, 0, -150, 2, 2)
near(p.arc_start_nm, 2 * math.tan(math.rad(75)), 1e-9, "150 deg left: the same")

-- 6. Not a path: no radius, no courses, a reversal.
check(path(0, 0, 0, 90, 0, 2) == nil, "no radius")
check(path(0, 0, nil, 90, 2, 2) == nil, "no inbound course")
check(path(0, 0, 0, 180, 2, 2) == nil, "a 180 deg reversal has no fly-by arc")
check(path(0, 0, 0, 90, 2, 0) == nil, "no look-ahead")

if #failures > 0 then
    error(string.format("lnav_path_geometry_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("lnav_path_geometry_test: %d checks passed", checks))
