-- Run from the repository root with LuaJIT: luajit tests/fltctrls/srm_model_test.lua
-- The SRM model (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.srm_model.lua)
-- against FCOM 9.20 and ATA27 27-11, 27-21 (docs/overhaul/notes/ATA-27.md
-- §4.1, §4.8): the outboard aileron lockout with its hysteresis, Mach and
-- LE group A, the SRMs taking over and the monitoring; the upper and lower
-- rudder ratio changers' schedule, the air data and autoland positions,
-- failing in place and RUD RATIO SNGL/DUAL.
local T = dofile("tests/lib/check.lua")("srm_model")
local M = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.srm_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
local function fly(s, inp, kt, mach, seconds)
    inp.vc[1], inp.vc[2], inp.mach[1], inp.mach[2] = kt, kt, mach or 0.3, mach or 0.3
    return run(s, inp, seconds or 0.1)
end
local UPR, LWR = M.UPR, M.LWR

-- lockout (ATA27 p.106-107): clean, locks above 238 kt, unlocks below
-- 232 kt; between, the last command holds; LE group A out unlocks
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    local out = fly(s, inp, 200, 0.4, 1)
    T.equal(out.lockout, 1, "clean, 200 kt: unlocked")
    out = fly(s, inp, 236, 0.4, 3)
    T.equal(out.lockout, 1, "236 kt from below: still unlocked")
    out = fly(s, inp, 240, 0.4, 1)
    T.check(out.lockout > 0 and out.lockout < 1, "240 kt: locking (the actuator moving)")
    out = fly(s, inp, 240, 0.4, M.LOCK_TRAVEL_S)
    T.equal(out.lockout, 0, "240 kt: locked")
    out = fly(s, inp, 234, 0.4, 3)
    T.equal(out.lockout, 0, "234 kt from above: still locked")
    out = fly(s, inp, 231, 0.4, 3)
    T.equal(out.lockout, 1, "231 kt: unlocked")
    -- Mach: M .53 locks at a low airspeed (high altitude), M .51 unlocks
    out = fly(s, inp, 220, 0.55, 3)
    T.equal(out.lockout, 0, "220 kt, M .55: locked")
    out = fly(s, inp, 220, 0.52, 3)
    T.equal(out.lockout, 0, "M .52: still locked")
    out = fly(s, inp, 220, 0.50, 3)
    T.equal(out.lockout, 1, "M .50, 220 kt: unlocked")
    -- LE group A out: unlocked whatever the speed
    out = fly(s, inp, 260, 0.45, 3)
    T.equal(out.lockout, 0, "260 kt clean: locked")
    inp.le_a_in = false
    out = run(s, inp, 3)
    T.equal(out.lockout, 1, "group A out: unlocked (p.106)")
    -- the FCUs' flap data lost: by speed and Mach only
    inp.le_valid = false
    out = run(s, inp, 3)
    T.equal(out.lockout, 0, "no flap data: by speed, locked (p.108)")
    inp.le_a_in, inp.le_valid = true, true
end

-- the SRMs: L fails, R takes over; both: unlocked in the air, held on the
-- ground (p.108)
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    local out = fly(s, inp, 260, 0.45, 3)
    T.equal(out.lockout, 0, "locked")
    inp.srm_fail[1] = true
    out = fly(s, inp, 220, 0.4, 3)
    T.equal(out.lockout, 1, "SRM L failed: R unlocks at 220 kt")
    out = fly(s, inp, 260, 0.45, 3)
    T.equal(out.lockout, 0, "R locks at 260 kt")
    inp.srm_fail[2] = true
    out = run(s, inp, 3)
    T.equal(out.lockout, 1, "both SRMs failed in the air: unlocked (default)")
    -- left air data lost: the SRM uses the right
    s, inp = M.new(), M.inputs()
    inp.on_ground = false
    inp.air_valid[1] = false
    inp.vc[1], inp.vc[2], inp.mach[1], inp.mach[2] = 0, 260, 0, 0.45
    out = run(s, inp, 3)
    T.equal(out.lockout, 0, "left air data lost: SRM L locks with the right's")
end

-- monitoring: the actuator stuck; 45 s, the other SRM; 45 s more,
-- AILERON LOCKOUT (p.110)
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    local out = fly(s, inp, 200, 0.4, 1)
    inp.lockout_stuck = true
    out = fly(s, inp, 260, 0.45, 44)
    T.equal(out.lockout, 1, "stuck: stays unlocked")
    T.check(not out.aileron_lockout, "under 45 s: no AILERON LOCKOUT")
    out = run(s, inp, 2)
    T.equal(s.lock_srm, 2, "45 s: SRM R takes the lockout")
    T.check(not out.aileron_lockout, "the other SRM tries first")
    out = run(s, inp, 45)
    T.check(out.aileron_lockout, "still not there: AILERON LOCKOUT (FCOM p.957)")
end

-- the rudder ratio changers (p.634-637): full authority up to 155.5 kt,
-- 5 degrees at 450 kt; the actuator moves at its speed; both alike
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    local out = fly(s, inp, 150, 0.3, 1)
    T.equal(out.rudder_max[UPR], 32, "150 kt: 32 degrees")
    T.equal(out.rudder_ratio[LWR], 1, "ratio 1")
    out = fly(s, inp, 245, 0.4, 0.1)
    T.check(out.rudder_max[UPR] > 25, "the actuator takes time")
    out = fly(s, inp, 245, 0.4, 5)
    T.near(out.rudder_max[UPR], 32 - 27 * 0.6, 1e-6, "245 kt: 0.6 in, about 16 degrees")
    T.near(out.rudder_max[LWR], out.rudder_max[UPR], 1e-9, "lower the same")
    out = fly(s, inp, 450, 0.7, 6)
    T.near(out.rudder_max[UPR], 5, 1e-6, "450 kt: 5 degrees")
    T.near(out.rudder_ratio[UPR], 5 / 32, 1e-6, "ratio 5/32")
    -- the ground test: about 7 degrees at the 367 kt position (p.682: 6-8)
    T.check(32 - 27 * M.rrc_in(367) > 6 and 32 - 27 * M.rrc_in(367) < 8, "367 kt: 6-8 degrees")
    -- air data lost: upper at 329 kt, lower at 209 kt (p.640)
    inp.air_valid[1], inp.air_valid[2] = false, false
    out = run(s, inp, 10)
    T.near(out.rudder_max[UPR], 32 - 27 * M.rrc_in(329), 1e-6, "no air data: upper at the 329 kt position")
    T.near(out.rudder_max[LWR], 32 - 27 * M.rrc_in(209), 1e-6, "lower at the 209 kt position")
    inp.air_valid[1], inp.air_valid[2] = true, true
    -- autoland: full authority (p.636)
    inp.autoland = true
    out = fly(s, inp, 140, 0.2, 10)
    T.equal(out.rudder_max[UPR], 32, "autoland: full rudder")
    inp.autoland = false
end

-- failures: an actuator stuck fails in place (FCOM p.949): RUD RATIO SNGL
-- once the servo error latches above 160 kt; both: DUAL; both SRMs lost:
-- the actuators stay, DUAL
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    local out = fly(s, inp, 300, 0.5, 10)
    local stuck_at = out.rudder_max[UPR]
    inp.rrc_stuck[UPR] = true
    out = fly(s, inp, 200, 0.4, 1)
    T.check(not out.rud_ratio_sngl, "stuck, 1 s: not yet")
    out = run(s, inp, 2)
    T.check(out.rud_ratio_sngl, "upper stuck above 160 kt: RUD RATIO SNGL (FCOM p.957)")
    T.check(out.st_rudder_ratio, "STATUS RUDDER RATIO")
    T.near(out.rudder_max[UPR], stuck_at, 1e-6, "upper stays where it failed")
    T.check(out.rudder_max[LWR] > stuck_at, "lower follows the slower speed")
    inp.rrc_stuck[LWR] = true
    out = fly(s, inp, 300, 0.5, 4)
    T.check(out.rud_ratio_dual and not out.rud_ratio_sngl, "both stuck: RUD RATIO DUAL")
    s, inp = M.new(), M.inputs()
    inp.on_ground = false
    out = fly(s, inp, 300, 0.5, 10)
    local at = out.rudder_max[LWR]
    inp.srm_fail[1], inp.srm_fail[2] = true, true
    out = fly(s, inp, 150, 0.3, 10)
    T.near(out.rudder_max[LWR], at, 1e-6, "both SRMs lost: the RRCs stay")
    T.check(out.rud_ratio_dual, "RUD RATIO DUAL")
    -- below 160 kt the monitor is quiet
    s, inp = M.new(), M.inputs()
    out = fly(s, inp, 100, 0.15, 1)
    inp.rrc_stuck[LWR] = true
    out = fly(s, inp, 150, 0.2, 10)
    T.check(not out.rud_ratio_sngl, "below 160 kt: no RUD RATIO")
    -- without air data the commands go to the fixed positions; a stuck
    -- actuator then shows (the speed is not known)
    inp.air_valid[1], inp.air_valid[2] = false, false
    out = run(s, inp, 4)
    T.check(out.rud_ratio_sngl, "no air data, lower stuck away from the 209 kt position: RUD RATIO SNGL")
end

T.done()
