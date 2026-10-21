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
-- with a look-ahead shorter than that cross-track the aim is the cross-track along the arc (45 deg at most)
p = path(1.5, -1.5, 0, 90, 2, 0.5)
local aim_bearing = -math.pi / 2 + (2 * math.pi / 4 + (2 - math.sqrt(0.5))) / 2
near(p.aim_east_nm, 2 + 2 * math.sin(aim_bearing), 1e-9, "inside the arc, 0.5 nm look-ahead: aim 1.29 nm round it (east)")
near(p.aim_north_nm, -2 + 2 * math.cos(aim_bearing), 1e-9, "inside the arc, 0.5 nm look-ahead: aim 1.29 nm round it (north)")

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

-- 5b. [P15] A turn of more than 150 deg (and less than 175) starts where a 150 deg turn's arc would, R tan(75)
-- before the fix (its own tangent arc would start R tan(turn / 2) before it: 11.4 R for 170 deg). Round an arc of R
-- from there the 747 reaches the outbound course outside the outbound leg by R (1 - cos turn) - R tan(75) sin turn;
-- the path turns on by up to 45 deg, closes on the leg on a straight line and rolls out onto it, all at R.
-- 170 deg right, R 2 nm: 7.46 nm before the fix, 2.67 nm outside, 45 deg on, 2.12 nm of straight line.
local capped = afds.lnav_capped_turn
check(type(capped) == "function", "afds.lnav_capped_turn exists")
local extent = afds.lnav_turn_extent_nm
check(type(extent) == "function", "afds.lnav_turn_extent_nm exists")
if type(capped) == "function" and type(extent) == "function" then
    local R, T = 2, 2 * math.tan(math.rad(75))
    local c = capped(170, R)
    check(c ~= nil, "170 deg: a capped turn")
    near(c.before_nm, T, 1e-9, "170 deg: the turn starts R tan(75) before the fix")
    near(c.outside_nm, R * (1 - math.cos(math.rad(170))) - T * math.sin(math.rad(170)), 1e-9,
        "170 deg: outside the outbound leg at its course")
    near(c.beta_deg, 45, 1e-9, "170 deg: 45 deg on")
    near(c.straight_nm, (c.outside_nm - 2 * R * (1 - math.cos(math.rad(45)))) / math.sin(math.rad(45)), 1e-9,
        "170 deg: the straight line closing on the leg")
    check(c.after_nm > T, "170 deg: onto the outbound leg farther after the fix than the turn starts before it, "
        ..tostring(c.after_nm))
    local before, after = extent(170, R)
    near(before, T, 1e-9, "170 deg: the extent before the fix")
    near(after, c.after_nm, 1e-9, "170 deg: the extent after it")
    before, after = extent(90, R)
    check(math.abs(before - R) < 1e-9 and math.abs(after - R) < 1e-9, "90 deg: R tan(45) before and after")
    before, after = extent(-150, R)
    check(math.abs(before - T) < 1e-9 and math.abs(after - T) < 1e-9, "150 deg left: R tan(75) before and after")
    check(capped(150, R) == nil and capped(175, R) == nil and capped(-176, R) == nil,
        "no capped turn at 150 deg or less, nor at 175 deg or more")
    -- points on the path (in 000, out 170, right): arc 1 round (R, -T)
    local function on_arc1(psi)
        return R - R * math.cos(math.rad(psi)), -T + R * math.sin(math.rad(psi))
    end
    local e0, n0 = on_arc1(90)
    p = path(e0, n0, 0, 170, R, 1)
    check(p ~= nil and p.element == "arc", "170 deg: a quarter round the first arc is on it, got "
        ..tostring(p and p.element))
    near(p and p.xtk_nm, 0, 1e-9, "170 deg: on the first arc, no cross-track")
    near(p and p.course_deg, 90, 1e-9, "170 deg: the first arc's course there")
    near(p and p.along_nm, R * math.pi / 2, 1e-9, "170 deg: a quarter round the arc along it")
    near(p and p.arc_start_nm, T, 1e-9, "170 deg: the arc starts R tan(75) before the fix")
    check(p and p.past_bisector == true, "170 deg: a quarter round the first arc is past the bisector")
    -- on the first arc at the outbound course: outside the outbound leg (left of it) by outside_nm
    local e1, n1 = on_arc1(170)
    near(e1 * math.cos(math.rad(170)) - n1 * math.sin(math.rad(170)), -c.outside_nm, 1e-9,
        "170 deg: on the outbound course, outside_nm left of the outbound leg")
    p = path(e1, n1, 0, 170, R, 1)
    near(p and p.xtk_nm, 0, 1e-9, "170 deg: there on the path")
    -- the middle of the straight line, on course 215
    local ee, en = on_arc1(215)
    local se = ee + c.straight_nm / 2 * math.sin(math.rad(215))
    local sn = en + c.straight_nm / 2 * math.cos(math.rad(215))
    p = path(se, sn, 0, 170, R, 1)
    check(p ~= nil and p.element == "straight", "170 deg: the straight line's middle is on it, got "
        ..tostring(p and p.element))
    near(p and p.xtk_nm, 0, 1e-9, "170 deg: on the straight line, no cross-track")
    near(p and p.course_deg, 215, 1e-9, "170 deg: the straight line's course, 45 deg on")
    near(p and p.along_nm, R * math.rad(215) + c.straight_nm / 2, 1e-9, "170 deg: along the path to it")
    -- 0.5 nm right of the outbound leg 3 nm after the path joins it
    local oe, on = math.sin(math.rad(170)), math.cos(math.rad(170))
    local re, rn = math.cos(math.rad(170)), -math.sin(math.rad(170))
    p = path((c.after_nm + 3) * oe + 0.5 * re, (c.after_nm + 3) * on + 0.5 * rn, 0, 170, R, 1)
    check(p ~= nil and p.element == "out", "170 deg: after the path joins the outbound leg, on it, got "
        ..tostring(p and p.element))
    near(p and p.xtk_nm, 0.5, 1e-9, "170 deg: 0.5 nm right of the outbound leg")
    near(p and p.along_nm, R * math.rad(215) + c.straight_nm + R * math.rad(45) + 3, 1e-9,
        "170 deg: along the whole path")
    -- on the inbound leg: not past the bisector, the aim as on any path
    p = path(0, -20, 0, 170, R, 1)
    check(p ~= nil and p.element == "in" and p.past_bisector == false,
        "170 deg: 20 nm before the fix on the inbound leg")
    near(p and p.along_nm, T - 20, 1e-9, "170 deg: before the arc's start")
    -- the left turn is its mirror
    p = path(-e0, n0, 0, -170, R, 1)
    check(p ~= nil and p.element == "arc", "170 deg left: on its first arc")
    near(p and p.xtk_nm, 0, 1e-9, "170 deg left: no cross-track")
    near(p and p.course_deg, 270, 1e-9, "170 deg left: the first arc's course there")
    -- just past 150 deg the 747 is little outside: it turns on less and back at once (no straight line)
    c = capped(151, R)
    near(c and c.beta_deg, math.deg(math.acos(1 - c.outside_nm / (2 * R))), 1e-9, "151 deg: on just enough")
    check(c and c.beta_deg < 20 and c.straight_nm == 0, "151 deg: less than 20 deg on and no straight line")
    check(path(0, 0, 0, 174.9, R, 1) ~= nil and path(0, 0, 0, 175, R, 1) == nil, "a path below 175 deg, none from it")
    -- [review 15] Near such a fix the inbound leg and the outbound side of the path run close (2.3 nm apart 13 nm before
    -- a 170 deg fix at 250 kt), and the nearest element by distance took the one for the other, the turn's bisector line
    -- (5 deg off the inbound leg for 170) the same: 0.9 nm inside the inbound leg 10 nm before the fix was the inbound
    -- leg but past the bisector, and 1 nm inside the straight line the inbound leg. The element now moves on only from
    -- the caller's last one (min_element) to the next, and the bisector is the path's: on it, as far along as where the
    -- first arc crosses the bisector line (44 deg round it for 170).
    p = path(0.9, -10, 0, 170, R, 1, nil, 1)
    check(p ~= nil and p.element == "in" and p.past_bisector == false, string.format(
        "170 deg: 0.9 nm inside the inbound leg 10 nm before the fix: the inbound leg, not past the bisector (%s, %s)",
        tostring(p and p.element), tostring(p and p.past_bisector)))
    check(p ~= nil and p.element_index == 1, "170 deg: its element's index 1, "..tostring(p and p.element_index))
    local c170 = capped(170, R)
    local h1 = 170 + c170.beta_deg
    local se0 = R - R * math.cos(math.rad(h1)) + c170.straight_nm / 2 * math.sin(math.rad(h1))
    local sn0 = -T + R * math.sin(math.rad(h1)) + c170.straight_nm / 2 * math.cos(math.rad(h1))
    -- 1 nm inside the straight line's middle (right of its course 215, towards the inbound leg)
    local ie, inn = math.cos(math.rad(h1)), -math.sin(math.rad(h1))
    p = path(se0 + ie, sn0 + inn, 0, 170, R, 1, nil, 3)
    check(p ~= nil and p.element_index ~= nil and p.element_index >= 3, string.format(
        "170 deg: 1 nm inside the straight line, the straight line its least: not back to the inbound leg (%s)",
        tostring(p and p.element)))
    near(p and p.xtk_nm, 1, 1e-9, "170 deg: 1 nm right of the straight line")
    p = path(se0 + ie, sn0 + inn, 0, 170, R, 1, nil, 1)
    check(p ~= nil and p.element_index ~= nil and p.element_index <= 2, string.format(
        "170 deg: the same place from the inbound leg reaches the first arc at most (%s)", tostring(p and p.element)))
    -- the bisector on the path: 30 and 60 deg round the first arc
    local function arc1(psi) return R - R * math.cos(math.rad(psi)), -T + R * math.sin(math.rad(psi)) end
    local a30e, a30n = arc1(30)
    local a60e, a60n = arc1(60)
    p = path(a30e, a30n, 0, 170, R, 1, nil, 2)
    check(p ~= nil and p.past_bisector == false, "170 deg: 30 deg round the first arc not past the bisector")
    p = path(a60e, a60n, 0, 170, R, 1, nil, 2)
    check(p ~= nil and p.past_bisector == true, "170 deg: 60 deg round the first arc past the bisector")
    -- [review 18] below about 159 deg the straight line has no length: just past the first arc's end (0.02-0.3 nm on
    -- along its last course) the element moves on from the first arc (min_element 2), at any radius. The arc's end and
    -- the line of no length are as near, worked out two ways, and rounding kept the arc (150.1 deg from 000: at every
    -- radius; 1326 of 18360 places in a review's sweep under LuaJIT, 660 under Lua 5.1)
    local stuck, tried = 0, 0
    for r = 1.5, 14, 0.25 do
        local c1 = capped(150.1, r)
        local h = 150.1 + c1.beta_deg
        local ee, en = r - r * math.cos(math.rad(h)), -c1.before_nm + r * math.sin(math.rad(h))
        for _, d in ipairs({0.02, 0.1, 0.3}) do
            local q = path(ee + d * math.sin(math.rad(h)), en + d * math.cos(math.rad(h)), 0, 150.1, r, 0.83, 1.0, 2)
            tried = tried + 1
            if not (q and q.element_index and q.element_index >= 3) then stuck = stuck + 1 end
        end
    end
    check(stuck == 0, string.format(
        "150.1 deg from 000, just past the first arc's end: the element moves on (%d of %d stayed on the arc)", stuck,
        tried))
    check(p ~= nil and p.bisector_along_nm ~= nil and math.abs(p.bisector_along_nm - R * math.rad(44)) < 0.05, string.format(
        "170 deg: the first arc crosses the bisector 44 deg round it (%s nm along)", tostring(p and p.bisector_along_nm)))
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
