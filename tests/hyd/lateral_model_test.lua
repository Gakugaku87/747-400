-- Run from the repository root with LuaJIT: luajit tests/hyd/lateral_model_test.lua
-- The lateral control model (plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.lateral_model.lua)
-- against ATA27 p.59, p.76, p.88, p.143-150, p.165, p.188-190, p.206-207 and
-- FCOM p.947 (docs/overhaul/notes/ATA-27.md §4.1-§4.2): the aileron
-- programmers, the flight spoilers' share of roll, the speedbrake program
-- and the spoiler mixers.
local T = dofile("tests/lib/check.lua")("lateral_model")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.lateral_model.lua")

-- the aileron programmers (p.59, p.88): a large initial travel, full at
-- about 45 degrees of wheel, nothing more beyond
T.near(L.inner(10), 5.65, 1e-6, "inboard aileron: 10 degrees of wheel, 5.65 down (p.59)")
T.near(L.inner(-10), -5.65, 1e-6, "inboard aileron: the same up")
T.near(L.inner(45), 20, 1e-6, "inboard aileron: full 20 at 45 degrees of wheel")
T.near(L.inner(90), 20, 1e-6, "inboard aileron: 20 at the wheel stop")
T.near(L.outer(10), 4.3, 1e-6, "outboard aileron down: 4.3 at 10 degrees")
T.near(L.outer(-10), -7.6, 1e-6, "outboard aileron up: 7.6 at 10 degrees")
T.near(L.outer(90), 15, 1e-6, "outboard aileron: 15 down at the stop")
T.near(L.outer(-90), -25, 1e-6, "outboard aileron: 25 up at the stop")
T.near(L.inner(12.5), (5.65 + 8.5) / 2, 1e-6, "between the read points: straight")
T.check(L.inner(10) > 20 * 10 / 90, "steeper than in proportion to the whole wheel (before: 2.2 at 10 degrees)")
T.near(L.TRIM_WHEEL / L.WHEEL_MAX, 0.5222, 1e-4, "full aileron trim (6 units) is 47 of the 90 degrees (the controlObject's 0.5222, p.76)")

-- the flight spoilers' share of roll: pickup at 11 degrees (8 to 14,
-- p.206), all of it at the wheel stop (estimate)
T.equal(L.lateral_share(10), 0, "10 degrees of wheel: no spoiler yet")
T.equal(L.lateral_share(-11), 0, "11 degrees: pickup")
T.near(L.lateral_share(50.5), 0.5, 1e-6, "halfway between the pickup and the stop: half")
T.equal(L.lateral_share(90), 1, "the stop: all")

-- the speedbrake lever's angle (p.165: ARM 3, the flight detent 37, UP 80)
T.near(L.lever_deg(0.125), 3, 1e-6, "ARM: 3 degrees of lever")
T.near(L.lever_deg(0.53), 37, 1e-6, "flight detent: 37 degrees")
T.near(L.lever_deg(1), 80, 1e-6, "UP: 80 degrees")

-- the speedbrake program (p.165, p.188-190, p.206-207)
local function all(lever, wheel)
    return L.spoilers(wheel or 0, lever, {})
end
local s = all(0)
for n = 1, 12 do T.equal(s[n], 0, "DN: spoiler " .. n .. " down") end
s = all(0.125)
for n = 1, 12 do T.equal(s[n], 0, "ARM: spoiler " .. n .. " down") end
s = all(0.53)
T.equal(s[3], 45, "flight detent: spoiler 3 at 45 (p.206)")
T.equal(s[10], 45, "flight detent: spoiler 10 at 45")
T.equal(s[5], 20, "flight detent: spoiler 5 at 20")
T.equal(s[6], 20, "flight detent: spoiler 6 at 20 (the ground spoiler valve's U1)")
T.equal(s[7], 20, "flight detent: spoiler 7 at 20")
T.equal(s[1], 0, "flight detent: spoiler 1 down (not a speedbrake in flight)")
T.equal(s[12], 0, "flight detent: spoiler 12 down")
s = all(1.0)
for n = 1, 12 do T.equal(s[n], 45, "UP: spoiler " .. n .. " at 45 (p.207)") end
-- spoilers 6 and 7 step at 28 degrees of lever and at 49 (p.165)
T.equal(L.program("g67", 28.0), 0, "spoilers 6, 7: down below 28 degrees of lever")
T.equal(L.program("g67", 28.3), 20, "spoilers 6, 7: 20 from 28")
T.equal(L.program("g67", 49), 45, "spoilers 6, 7: 45 from 49")
T.equal(L.program("g58", 48.9), 20, "spoilers 5, 8: 20 up to 49")
T.equal(L.program("g58", 49), 45, "spoilers 5, 8: 45 from 49 (the ratio changers extended)")
T.near(L.program("g34", 20.5), 29.3, 1e-6, "spoilers 3, 4, 9, 10: the curve (29.3 at 20.5 degrees)")
T.equal(L.program("g1212", 42.8), 0, "spoilers 1, 2, 11, 12: from 43 degrees")
T.near(L.program("g1212", 65), 23.9, 1e-6, "spoilers 1, 2, 11, 12: 23.9 at 65 degrees")

-- roll with the speedbrakes down: the wing going up only (nothing below 0)
s = all(0, 50.5)
T.near(s[12], 22.5, 1e-6, "roll right, half the spoiler travel: spoiler 12 at 22.5")
T.near(s[9], 22.5, 1e-6, "spoiler 9 at 22.5")
T.near(s[8], 10, 1e-6, "spoiler 8 at 10 (20 at most)")
T.equal(s[7], 0, "spoiler 7: not in roll")
T.equal(s[1], 0, "left wing: spoiler 1 stays down")
T.equal(s[5], 0, "left wing: spoiler 5 stays down")
s = all(0, -90)
T.equal(s[1], 45, "full left roll: spoiler 1 at 45")
T.equal(s[5], 20, "spoiler 5 at 20")
T.equal(s[6], 0, "spoiler 6: not in roll")
T.equal(s[12], 0, "right wing: down")
s = all(0, 10)
for n = 1, 12 do T.equal(s[n], 0, "10 degrees of wheel: spoiler " .. n .. " still down (before the pickup)") end

-- the mixers (FCOM p.947, ATA27 p.150): roll with the speedbrakes out
-- lowers the other wing's spoilers from their speedbrake position
s = all(0.53, 50.5)
T.near(s[3], 45 - 22.5, 1e-6, "flight detent, roll right: left spoiler 3 lowered to 22.5")
T.equal(s[10], 45, "right spoiler 10 stays at 45 (its travel)")
T.near(s[5], 20 - 10, 1e-6, "left spoiler 5 lowered to 10")
T.equal(s[8], 20, "right spoiler 8 at 20 (20 at most in flight)")
T.equal(s[6], 20, "spoiler 6 stays at 20")
T.equal(s[1], 0, "left spoiler 1 stays down")
T.near(s[12], 22.5, 1e-6, "right spoiler 12 up by the roll")
s = all(0.53, 90)
T.equal(s[3], 0, "flight detent, full right roll: left spoiler 3 all the way down")
s = all(1.0, -50.5)
T.near(s[12], 22.5, 1e-6, "on the ground at UP, roll left: right spoiler 12 lowered to 22.5")
T.near(s[8], 45 - 10, 1e-6, "right spoiler 8 lowered to 35 (45 with its ratio changer extended)")
T.equal(s[1], 45, "left spoiler 1 stays at 45")

T.done()
