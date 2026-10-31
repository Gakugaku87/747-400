-- Run from the repository root with LuaJIT: luajit tests/fms/rta_model_test.lua
-- The FMC's required time of arrival (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.rta_model.lua; 6-1/6-2 step 9h5a, notes/
-- ATA-34-61-FMC.md §84; FCOM p.1383-1385, FMSPG p.3.4-52~55): the time's
-- entries, a FIX's modification with boxes, EXEC, DELETE of the FIX and of
-- the time, ERASE, PRIOR RTA, MAX SPD.
local T = dofile("tests/lib/check.lua")("rta_model")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.rta_model.lua")

-- the time's entries (FCOM p.1384: 0000.0 to 2359.9, .0 optional, A or B)
local t, sfx = R.parse_time("1740.0B")
T.check(t == 17 * 60 + 40 and sfx == "B", "1740.0B: 17:40.0, at or before")
t, sfx = R.parse_time("1740")
T.check(t == 1060 and sfx == nil, "1740: the tenth optional, no suffix")
t, sfx = R.parse_time("0005.5A")
T.near(t, 5.5, 1e-9, "0005.5A: 5.5 minutes")
T.equal(sfx, "A", "at or after")
T.near(R.parse_time("2359.9"), 23 * 60 + 59.9, 1e-9, "2359.9: the last")
for _, bad in ipairs({"2400", "1760", "1740.", "17400", "174", "1740.0C", "1740.12", "", "17:40"}) do
    T.equal(R.parse_time(bad), nil, "not a time: " .. bad)
end
T.equal(R.time_text(17 * 60 + 40, "B"), "1740.0zB", "shown as 1740.0zB (FCOM p.1383's figure)")
T.equal(R.time_text(5.5), "0005.5z", "0005.5z")

-- a FIX: a modification, boxes for the time; the time completes it; EXEC
local s = R.new()
T.equal(R.shown(s), nil, "none at first")
R.enter_fix(s, "DENOH")
T.check(s.mod.fix == "DENOH" and s.mod.time == nil and not R.ready(s), "DENOH: a modification without its time (boxes)")
T.equal(R.exec(s), false, "EXEC without the time: nothing")
T.check(R.enter_time(s, R.parse_time("1740.0B")), "the time entered")
T.check(R.ready(s) and s.mod.suffix == "B", "the modification complete")
T.check(R.exec(s) and s.active.fix == "DENOH" and s.mod == nil, "EXEC: active")
-- a new time on the active RTA: a modification of it
R.enter_time(s, R.parse_time("1745"))
T.check(s.mod.fix == "DENOH" and s.mod.time == 1065 and s.active.time == 1060, "a new time: a modification, the active one kept until EXEC")
T.check(R.erase(s) and s.mod == nil and s.active.time == 1060, "ERASE: the active one again")
-- DELETE on the time or the FIX ends an active RTA (ECON again), kept as the prior one
R.delete_time(s)
T.check(s.active == nil and s.prior.fix == "DENOH", "DELETE on the time: ended, the prior one kept")
local inRoute = function(fix) return fix == "DENOH" end
T.check(R.prior_shown(s, inRoute), "PRIOR RTA> shown: its FIX in the route")
T.check(not R.prior_shown(s, function() return false end), "not with its FIX gone")
T.check(R.prior(s, inRoute) and s.mod.fix == "DENOH" and s.mod.time == 1060, "PRIOR RTA>: its FIX and time as a modification")
T.check(R.exec(s) and s.active.time == 1060, "EXEC: active again")
T.check(not R.prior_shown(s, inRoute), "no PRIOR RTA> with one active")
R.delete_fix(s)
T.check(s.active == nil and s.mod == nil, "DELETE on the FIX: ended")
-- a modification's FIX deleted: dropped; its time deleted: boxes again
R.enter_fix(s, "AAA")
R.enter_time(s, 600)
R.delete_time(s)
T.check(s.mod and s.mod.fix == "AAA" and s.mod.time == nil, "a modification's time deleted: boxes again")
R.delete_fix(s)
T.equal(s.mod, nil, "its FIX deleted: dropped")
T.equal(R.enter_time(s, 600), false, "a time without a FIX: no")
-- MAX SPD (FCOM p.1384: .880 by default)
T.near(R.max(s), 0.880, 1e-9, "MAX SPD .880")
R.set_max(s, 0.85)
T.near(R.max(s), 0.85, 1e-9, "the crew's .850")
R.set_max(s, nil)
T.near(R.max(s), 0.880, 1e-9, "deleted: .880 again")

-- (step 9h5b) the cruise Mach for the time (FCOM p.1269: within 30 s):
-- the cruise's time scaled for the error, A no faster than the base, B no
-- slower, within the bounds; UNABLE RTA at a bound more than 30 s off
local r = {fix = "X", time = 600}
local base = {mach = nil, base = 0.85, now = 590, t_fix = 600, t_cruise = 540, lo = 0.70, hi = 0.88}
-- 10 min to go, now 590: arriving 600.0, on time
local m, un, d = R.speed(r, base)
T.check(math.abs(d) < 1e-9 and math.abs(m - 0.85) < 1e-9 and not un, "on time: the base's .850")
-- 1 min early (the time 601): slower, 9 min of cruise over 10
r.time = 601
m, un, d = R.speed(r, base)
T.near(d, -1, 1e-9, "a minute early")
T.near(m, 0.85 * 9 / 10, 1e-9, "the cruise's 9 min to 10: .765")
T.check(not un, "not UNABLE")
-- 0.4 min late (the time 599.6): faster
r.time = 599.6
m, un = R.speed(r, base)
T.check(math.abs(m - 0.88) < 1e-9 and not un, "0.4 min late: faster, .890 needed, held at the bound .880 (not UNABLE: not there yet)")
r.time = 599.8
T.near((R.speed(r, base)), 0.85 * 9 / 8.8, 1e-9, "0.2 min late: .869")
-- then at the bound .880 still late: UNABLE RTA
local at = {mach = 0.88, base = 0.85, now = 590, t_fix = 590, t_cruise = 530, lo = 0.70, hi = 0.88}
r.time = 599
m, un = R.speed(r, at)
T.check(math.abs(m - 0.88) < 1e-9 and un, "at .880 a minute late: UNABLE RTA")
r.time = 599.6
m, un = R.speed(r, at)
T.check(not un, "within 30 s: not UNABLE")
-- early at the low bound: UNABLE; with B (at or before) not
r.time = 610
m, un = R.speed(r, {mach = 0.70, base = 0.85, now = 590, t_fix = 590, t_cruise = 530, lo = 0.70, hi = 0.88})
T.check(un and math.abs(m - 0.70) < 1e-9, "10 min early at the low bound: UNABLE RTA")
r.suffix = "B"
m, un = R.speed(r, {mach = 0.70, base = 0.85, now = 590, t_fix = 590, t_cruise = 530, lo = 0.70, hi = 0.88})
T.check(not un and math.abs(m - 0.85) < 1e-9, "B (at or before) early: the base, not UNABLE")
-- A (at or after) late: the base; early: slower
r.suffix, r.time = "A", 595
m, un = R.speed(r, base)
T.check(not un and math.abs(m - 0.85) < 1e-9, "A 5 min late: the base, not UNABLE")
r.time = 601
T.near((R.speed(r, base)), 0.765, 1e-9, "A a minute early: slower")
-- across midnight: the time 0001, now 23:55, 10 min to go: 4 min late
r.suffix, r.time = nil, 1
local _, _, dm = R.speed(r, {base = 0.85, now = 1435, t_fix = 600, t_cruise = 540, lo = 0.7, hi = 0.88})
T.near(dm, 4, 1e-9, "across midnight: 4 min late")
-- no cruise left: the Mach kept, UNABLE more than 30 s off
m, un = R.speed(r, {mach = 0.8, base = 0.85, now = 1435, t_fix = 600, t_cruise = 0, lo = 0.7, hi = 0.88})
T.check(math.abs(m - 0.8) < 1e-9 and un, "no cruise left: kept, UNABLE")
T.done()
