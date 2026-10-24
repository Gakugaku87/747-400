-- Run from the repository root with LuaJIT: luajit tests/gear/btms_model_test.lua
-- The brake temperature model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.btms_model.lua)
-- against FCOM PI.12.8 (p.282, the recommended brake cooling schedule),
-- p.1521 and ATA29_32 p.428 (docs/overhaul/notes/ATA-32.md §4.10): the
-- indication in proportion, 5 at 482 °C, BRAKE TEMP at 5, the BTMS reading
-- 10-15 min after a stop against the brake energy, the cooling times on the
-- ground and gear down in flight, BRAKE TEMP SYS.
local T = dofile("tests/lib/check.lua")("btms_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.btms_model.lua")

local FTLB = 1.35582                -- J per ft-lb
local DT = 1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do out = M.update(s, inp, DT) end
    return out
end
-- a stop adding `mftlb` million ft-lb to every brake, then `minutes` stopped
local function stop(mftlb, minutes, airflow)
    local s, inp = M.new(15), M.inputs()
    inp.oat = 15
    for i = 1, M.BRAKES do inp.heat_j[i] = mftlb * 1e6 * FTLB end
    M.update(s, inp, DT)
    for i = 1, M.BRAKES do inp.heat_j[i] = 0 end
    inp.airflow = airflow or false
    return run(s, inp, minutes * 60), s
end

T.equal(M.level(15), 0, "15 °C: 0")
T.equal(M.level(481), 4, "481 °C: 4")
T.equal(M.level(482.1), 5, "482 °C: 5 (ATA29_32 p.428)")
T.equal(M.level(2000), 9, "the indication stops at 9")

-- the BTMS reading 10-15 min after the stop (PI.12.8)
T.equal(stop(16, 12).level[1], 2, "16 million ft-lb, 12 min: 2")
local l20 = stop(20, 12).level[1]
T.check(l20 == 2 or l20 == 3, "20: 2 (3 here: the schedule is not in proportion) (" .. l20 .. ")")
T.equal(stop(22, 12).level[1], 3, "22: 3")
local l27 = stop(27, 12).level[1]
T.check(l27 == 3 or l27 == 4, "27: 3 (4 here) (" .. l27 .. ")")
T.equal(stop(31, 12).level[1], 4, "31: 4")
local out = stop(34, 10)
T.check(out.level[1] >= 5 and out.level[1] <= 6, "34, 10 min: 5 to 6 (" .. out.level[1] .. ")")
T.check(out.brake_temp, "BRAKE TEMP at 5 (FCOM p.1521)")
T.check(stop(46, 10).level[1] >= 6, "46: 6 or more (the fuse plug melt zone)")
-- the thermocouples lag: just after the stop the reading is still low
T.check(stop(31, 0.5).level[1] <= 2, "31, half a minute after: the reading still rising")
-- the cooling times to 15 million ft-lb (no special procedure): on the
-- ground 31 -> 62 min, 20 -> 28 min; gear down in flight 31 -> 7 min
-- (the heat sink's energy: the schedule is in brake energy)
local function energy_left(mftlb, minutes, airflow)
    local _, st = stop(mftlb, minutes, airflow)
    return (st.sink[1] - 15) * M.HEAT_J_PER_C / FTLB / 1e6
end
T.near(energy_left(31, 62), 15, 2, "31 million ft-lb, 62 min on the ground: about 15 left")
T.near(energy_left(20, 28), 15, 1.5, "20, 28 min on the ground: about 15")
T.near(energy_left(31, 7, true), 15, 2, "31, 7 min gear down in flight: about 15")
-- BRAKE TEMP goes with the level back at 4; one brake is enough
local s, inp = M.new(15), M.inputs()
inp.heat_j[6] = 50 * 1e6 * FTLB
M.update(s, inp, DT)
inp.heat_j[6] = 0
out = run(s, inp, 600)
T.check(out.brake_temp, "one hot brake: BRAKE TEMP")
T.equal(out.level[5], 0, "the cool one next to it: 0")
out = run(s, inp, 3 * 3600)
T.check(not out.brake_temp and out.level[6] <= 4, "cooled to 4: no BRAKE TEMP (" .. out.level[6] .. ")")
-- the BTMU failed: BRAKE TEMP SYS, no BRAKE TEMP
inp.heat_j[6] = 50 * 1e6 * FTLB
M.update(s, inp, DT)
inp.heat_j[6] = 0
run(s, inp, 600)
inp.fail = true
out = M.update(s, inp, DT)
T.check(out.sys and not out.brake_temp, "BTMU failed: BRAKE TEMP SYS, no BRAKE TEMP (ATA29_32 p.428)")
T.done()
