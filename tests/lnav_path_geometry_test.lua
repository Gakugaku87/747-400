-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The lateral path of a fly-by fix for LNAV's path guidance (item i-1b): the
-- inbound leg, the arc of radius R tangent to both legs R tan(turn / 2) from
-- the fix, and the outbound leg, in east/north nm from the fix. The aircraft's
-- signed cross-track from that path (+ right of it; from the arc while on it,
-- as the PROGRESS page's XTK should read in the turn), the path's course
-- there, and the point a look-ahead distance further along the path that a
-- pure-pursuit guidance aims at (on a straight leg at most 45 deg off its
-- course: the look-ahead is never shorter than the cross-track). Pure
-- geometry from afds_helpers; LNAV's path guidance (B747_lnav_path_track) flies it.
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

-- Past a turn of more than 90 deg the outbound leg runs back behind the arc's start in the inbound leg's
-- frame: the turn's bisector (through the fix and the arc's centre) parts the inbound leg's side from the
-- outbound leg's. 120 deg right, R 2.5 nm: 8.7 nm along the outbound leg is 4.35 nm behind the fix, the arc
-- starting 4.33 nm before it.
local function on_leg(nm, course) return nm * math.sin(math.rad(course)), nm * math.cos(math.rad(course)) end
local e, n = on_leg(8.7, 120)
p = path(e, n, 0, 120, 2.5, 1)
check(p.element == "out", "120 deg: 8.7 nm along the outbound leg is on it, got "..tostring(p.element))
near(p.xtk_nm, 0, 1e-9, "120 deg: on the outbound leg, no cross-track")
near(p.course_deg, 120, 1e-9, "120 deg: the outbound leg's course")
local ae, an = on_leg(9.7, 120)
near(p.aim_east_nm, ae, 1e-9, "120 deg: aim 1 nm further along the outbound leg (east)")
near(p.aim_north_nm, an, 1e-9, "120 deg: aim 1 nm further along the outbound leg (north)")
e, n = on_leg(8.7, 240)
p = path(e, n, 0, 240, 2.5, 1)
check(p.element == "out", "120 deg left: the same, got "..tostring(p.element))
-- 150 deg right, R 2 nm: 10 nm along the outbound leg (8.66 nm behind the fix, the arc from 7.46 nm), 0.4 nm
-- right of it
e, n = on_leg(10, 150)
local re, rn = on_leg(0.4, 240)
p = path(e + re, n + rn, 0, 150, 2, 1)
check(p.element == "out", "150 deg: 10 nm along the outbound leg is on it, got "..tostring(p.element))
near(p.xtk_nm, 0.4, 1e-9, "150 deg: 0.4 nm right of the outbound leg")
-- the inbound leg's side is the inbound leg's, also where the outbound leg's extension behind the fix runs
p = path(0, -10, 0, 120, 2.5, 1)
check(p.element == "in", "120 deg: 10 nm before the fix on the inbound leg")
near(p.xtk_nm, 0, 1e-9, "120 deg: on the inbound leg")

-- A capture look-ahead for the legs (rolling out onto a leg takes room that grows with the turn radius), the
-- look-ahead round the arc: on the inbound leg the aim waits at the arc's start until the look-ahead reaches
-- it. 90 deg right, R 2 (the arc from 2 nm before the fix), look-ahead 0.5 nm, capture 3 nm.
p = path(0.4, -10, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 0, 1e-9, "8 nm before the arc: aim on the inbound leg (east)")
near(p.aim_north_nm, -7, 1e-9, "8 nm before the arc: aim the capture's 3 nm along it")
p = path(0.4, -4, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 0, 1e-9, "2 nm before the arc: aim at its start (east)")
near(p.aim_north_nm, -2, 1e-9, "2 nm before the arc: aim at its start (north)")
p = path(0, -2.3, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 2 - 2 * math.cos(0.1), 1e-9, "0.3 nm before the arc: aim 0.2 nm onto it (east)")
near(p.aim_north_nm, -2 + 2 * math.sin(0.1), 1e-9, "0.3 nm before the arc: aim 0.2 nm onto it (north)")
p = path(m, -m, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 2 + 2 * math.sin(math.rad(315) + 0.25), 1e-9, "on the arc: the look-ahead (east)")
p = path(5, 0.3, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 8, 1e-9, "on the outbound leg: the capture's 3 nm along it")
near(p.aim_north_nm, 0, 1e-9, "on the outbound leg: aim on it")
p = path(5, 4, 0, 90, 2, 0.5, 3)
near(p.aim_east_nm, 9, 1e-9, "4 nm off the outbound leg: aim 4 nm along it (45 deg)")

-- The turn's bisector (through the fix and the arc's middle): whether the aircraft is past it, where the
-- FMC sequences the turn.
check(path(0, -10, 0, 90, 2, 2).past_bisector == false, "10 nm before the fix: not past the bisector")
check(path(m + 0.01, -m, 0, 90, 2, 2).past_bisector == true, "just past the arc's middle: past it")
check(path(m - 0.01, -m, 0, 90, 2, 2).past_bisector == false, "just before the arc's middle: not past it")
check(path(5, 0.3, 0, 90, 2, 2).past_bisector == true, "on the outbound leg: past it")

-- The ground speed a fly-by arc is drawn for: the TAS plus the wind along the track, the highest across the
-- turn (an arc the 747 can follow all round at the bank limit, no bigger).
local gsk = afds.lnav_turn_ground_speed_kts
check(type(gsk) == "function", "afds.lnav_turn_ground_speed_kts exists")
if type(gsk) == "function" then
    local function wind(from_deg, kt) return -kt * math.sin(math.rad(from_deg)), -kt * math.cos(math.rad(from_deg)) end
    local we, wn = wind(265, 96)
    near(gsk(478, 0, 0, 270, 0), 478, 1e-9, "no wind: the TAS")
    near(gsk(478, we, wn, 270, 0), 478 + 96 * math.cos(math.rad(275)), 1e-6, "BEDRA (270 to 000) in 265/96: the highest at 000")
    we, wn = wind(355, 96)
    near(gsk(482, we, wn, 0, 137), 482 + 96 * math.cos(math.rad(38)), 1e-6, "BILTO (000 to 137) in 355/96: the highest at 137")
    we, wn = wind(270, 90)
    near(gsk(250, we, wn, 0, 170), 340, 1e-6, "000 to 170 right through the wind toward 090: its whole speed")
    near(gsk(250, we, wn, 0, -170), 250, 1e-6, "000 to 190 left, never toward 090: the start's, across the wind")
end

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
