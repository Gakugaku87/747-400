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
T.done()
