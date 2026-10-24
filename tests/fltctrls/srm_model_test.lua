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

-- ======== stabilizer trim (step 2b; notes §4.5)
-- in the air, systems 2 and 3 pressurized, at `kt`
local function stab_setup(kt, units)
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    inp.hyd_psi[1], inp.hyd_psi[2] = 3000, 3000
    inp.vc[1], inp.vc[2], inp.mach[1], inp.mach[2] = kt, kt, 0.3, 0.3
    M.stab_set(s, units or 5)
    M.update(s, inp, DT)
    return s, inp
end
local S2, S3 = 1, 2         -- the modules of systems 2 and 3

-- rates (ATA27 p.452; ATA22 p.132: 1 unit = 1 degree): both modules 0.5
-- units/s at or below 220 kt, 0.2 from 230 kt, the hysteresis between
do
    local s, inp = stab_setup(200)
    inp.trim_capt = 1
    local out = run(s, inp, 2)
    T.near(out.stab_units, 6, 1e-6, "200 kt: captain's switches nose up, 0.5 units/s")
    T.near(out.stab_rate, 0.5, 1e-6, "rate out")
    inp.trim_capt, inp.trim_fo = 0, -1
    out = run(s, inp, 2)
    T.near(out.stab_units, 5, 1e-6, "F/O's switches nose down")
    inp.trim_fo = 0
    out = fly(s, inp, 250, 0.4, 0.1)
    inp.trim_capt = 1
    out = run(s, inp, 2)
    T.near(out.stab_units, 5.4, 1e-6, "250 kt: 0.2 units/s")
    out = fly(s, inp, 225, 0.4, 1)
    T.near(out.stab_units, 5.6, 1e-6, "225 kt from above: still the slow rate")
    out = fly(s, inp, 215, 0.4, 1)
    T.near(out.stab_units, 6.1, 1e-6, "215 kt: fast again")
    -- the captain's and F/O's switches opposite: no trim (FCOM p.944)
    inp.trim_fo = -1
    out = run(s, inp, 1)
    T.near(out.stab_units, 6.1, 1e-6, "captain up, F/O down: no trim")
    -- no air data, or no SRM: the slow rate (p.452)
    inp.trim_fo = 0
    inp.air_valid[1], inp.air_valid[2] = false, false
    out = run(s, inp, 1)
    T.near(out.stab_units, 6.3, 1e-6, "no air data: slow rate")
    inp.air_valid[1], inp.air_valid[2] = true, true
    inp.srm_fail[1], inp.srm_fail[2] = true, true
    out = run(s, inp, 1)
    T.near(out.stab_units, 6.5, 1e-6, "both SRMs failed: manual trim still works, at the slow rate (p.483)")
    inp.trim_capt = 0
end

-- limits (ATA27 p.483, p.520): electric nose up 11.6, nose down 1.8 clean,
-- 0.8 with the gear down or the LE flaps out; the alternate switches 0.25
-- to 14.75, past the electric limits; the wheel against the alternate: none
do
    local s, inp = stab_setup(200, 11.3)
    inp.trim_capt = 1
    local out = run(s, inp, 2)
    T.near(out.stab_units, 11.6, 1e-9, "nose up stops at 11.6")
    inp.trim_capt = -1
    M.stab_set(s, 2.1)
    out = run(s, inp, 2)
    T.near(out.stab_units, 1.8, 1e-9, "clean: nose down stops at 1.8")
    inp.gear_down = true
    out = run(s, inp, 4)
    T.near(out.stab_units, 0.8, 1e-9, "gear down: 0.8")
    inp.gear_down, inp.le_up = false, false
    M.stab_set(s, 1.5)
    out = run(s, inp, 4)
    T.near(out.stab_units, 0.8, 1e-9, "LE flaps out: 0.8")
    inp.le_up, inp.trim_capt = true, 0
    inp.altn = -1
    out = run(s, inp, 4)
    T.near(out.stab_units, 0.25, 1e-9, "ALTN: down to 0.25")
    inp.altn = 1
    M.stab_set(s, 14)
    out = run(s, inp, 4)
    T.near(out.stab_units, 14.75, 1e-9, "ALTN: up to 14.75")
    -- electric trim from beyond its limit: only back toward it
    inp.altn, inp.trim_capt = 0, 1
    out = run(s, inp, 1)
    T.near(out.stab_units, 14.75, 1e-9, "past 11.6: no electric nose up")
    inp.trim_capt = -1
    out = run(s, inp, 1)
    T.near(out.stab_units, 14.25, 1e-6, "electric nose down from there")
    inp.altn = 1
    out = run(s, inp, 1)
    T.near(out.stab_units, 14.25, 1e-9, "ALTN up against the wheel down: no trim")
    inp.altn, inp.trim_capt = 0, 0
end

-- the column cutout (ATA27 p.476; FCOM p.945): the column 4.5 degrees
-- against an electric command stops it; with it, or the alternate: trims
do
    local s, inp = stab_setup(200, 6)
    inp.trim_capt, inp.column = -1, 0.5
    local out = run(s, inp, 1)
    T.near(out.stab_units, 6, 1e-9, "column aft, nose down trim: cut out")
    inp.column = 0.2
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.5, 1e-6, "column slightly aft: trims")
    inp.trim_capt, inp.column = 1, 0.5
    out = run(s, inp, 1)
    T.near(out.stab_units, 6, 1e-6, "column aft, nose up trim: trims")
    inp.trim_capt, inp.column = -1, 0.5
    inp.altn = -1
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.5, 1e-6, "the alternate switches: no column cutout")
    inp.altn, inp.trim_capt, inp.column = 0, 0, 0
    -- power: the wheel switches DC 3, the alternate the battery bus
    inp.manual_pwr, inp.trim_fo = false, 1
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.5, 1e-9, "DC 3 off: no wheel trim")
    inp.trim_fo, inp.altn = 0, 1
    inp.altn_pwr = false
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.5, 1e-9, "battery bus off: no alternate trim")
    inp.altn_pwr, inp.manual_pwr, inp.altn = true, true, 0
end

-- one module out: half rate; on a manual command its >STAB TRIM latches
-- (ATA27 p.455-456; FCOM p.958); full rate with a manual command, or the
-- system's pressure back, clears it; STATUS STAB TRIM stays
do
    local s, inp = stab_setup(200, 5)
    inp.hyd_psi[S3] = 0
    inp.trim_capt = 1
    local out = run(s, inp, 2)
    T.near(out.stab_units, 5.5, 1e-6, "system 3 out: half rate")
    T.check(out.stab_trim[S3] and not out.stab_trim[S2], ">STAB TRIM 3")
    T.check(out.st_stab_trim, "STATUS STAB TRIM")
    inp.trim_capt = 0
    out = run(s, inp, 1)
    T.check(out.stab_trim[S3], "latched")
    inp.hyd_psi[S3] = 3000
    out = run(s, inp, 0.1)
    T.check(not out.stab_trim[S3], "system 3's pressure back: cleared (no command needed)")
    T.check(out.st_stab_trim, "STATUS STAB TRIM stays")
    inp.stcm_fail[S2] = true
    inp.trim_capt = -1
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.25, 1e-6, "system 2's actuator failed: half rate")
    T.check(out.stab_trim[S2], ">STAB TRIM 2")
    inp.stcm_fail[S2] = false
    out = run(s, inp, 1)
    T.check(not out.stab_trim[S2], "full rate with a manual command: cleared")
    T.near(out.stab_units, 4.75, 1e-6, "full rate again")
    -- both out: nothing moves, no message
    inp.hyd_psi[S2], inp.hyd_psi[S3] = 0, 0
    out = run(s, inp, 1)
    T.near(out.stab_units, 4.75, 1e-9, "no pressure: no trim")
    T.check(not out.stab_trim[S2] and not out.stab_trim[S3], "no half rate, no message")
    inp.trim_capt = 0
end

-- the cutout switches (ATA27 p.450, p.456; FCOM p.945): CUTOUT closes the
-- valve (>STAB TRIM, half rate); back to AUTO it opens after 5 s and the
-- message goes; ON opens at once
do
    local s, inp = stab_setup(200, 5)
    inp.cutout[S2] = M.CUTOUT
    local out = run(s, inp, 0.1)
    T.check(out.stab_trim[S2] and not out.mov_open[S2], "CUTOUT: valve closed, >STAB TRIM 2")
    inp.trim_capt = 1
    out = run(s, inp, 1)
    T.near(out.stab_units, 5.25, 1e-6, "half rate")
    inp.trim_capt = 0
    inp.cutout[S2] = M.AUTO
    out = run(s, inp, 4.5)
    T.check(out.stab_trim[S2] and not out.mov_open[S2], "AUTO, 4.5 s: still closed")
    out = run(s, inp, 0.6)
    T.check(out.mov_open[S2] and not out.stab_trim[S2], "AUTO, 5 s: open, message gone")
    inp.cutout[S3] = M.CUTOUT
    out = run(s, inp, 0.1)
    inp.cutout[S3] = M.ON
    out = run(s, inp, 0.1)
    T.check(out.mov_open[S3] and not out.stab_trim[S3], "ON: open at once")
    inp.cutout[S3] = M.AUTO
end

-- autotrim (ATA27 p.488; ATA22 p.142-152): the engaged FCC's SRM trims at
-- half rate through its own module after the command has held 3.5 s
do
    local s, inp = stab_setup(300, 6)
    inp.ap_l, inp.autotrim_cmd = true, 1
    local out = run(s, inp, 3)
    T.near(out.stab_units, 6, 1e-9, "3 s: not yet")
    out = run(s, inp, 2.5)
    T.check(out.stab_units > 6.15 and out.stab_units < 6.25, "after 3.5 s: 0.1 units/s at 300 kt (one module)")
    out = fly(s, inp, 200, 0.3, 1)
    T.near(out.stab_rate, 0.25, 1e-6, "200 kt: 0.25 units/s")
    -- the command reverses: the delay again
    inp.autotrim_cmd = -1
    local at = out.stab_units
    out = run(s, inp, 3)
    T.near(out.stab_units, at, 1e-9, "reversed: waits again")
    inp.autotrim_cmd = 0
    -- SRM L drives system 3's module: with system 3 out, dead trim, STAB
    -- AUTO TRIM; with C engaged too the path moves to SRM R (system 2)
    inp.hyd_psi[S3] = 0
    inp.ap_c, inp.autotrim_cmd = true, 1
    at = out.stab_units
    out = run(s, inp, 3.6)
    T.near(out.stab_units, at, 1e-9, "system 3 out: SRM L cannot trim")
    out = run(s, inp, 2)
    T.check(out.st_auto_trim, "dead trim: STATUS STAB AUTO TRIM")
    out = run(s, inp, 1)
    T.check(out.stab_units > at + 0.1, "moved to SRM R: trims through system 2")
    inp.ap_l, inp.ap_c, inp.autotrim_cmd = false, false, 0
    out = run(s, inp, 0.1)
    T.check(not out.st_auto_trim, "all autopilots off: reset")
    inp.hyd_psi[S3] = 3000
end

-- the autopilots and the wheel switches (FCOM p.945): one is disengaged
-- (a single request) and the stabilizer trims; with two or more they are
-- inhibited and autotrim goes on; the alternate switches override autotrim
-- and do not disengage, but show STAB TRIM UNSCHD (FCOM p.958)
do
    local s, inp = stab_setup(200, 6)
    inp.ap_l = true
    inp.trim_capt = 1
    local out = M.update(s, inp, DT)
    T.check(out.ap_disengage, "one A/P: disengage")
    out = M.update(s, inp, DT)
    T.check(not out.ap_disengage, "once")
    T.check(out.stab_units > 6, "and trims")
    inp.trim_capt = 0
    inp.ap_c = true
    inp.trim_fo = -1
    local at = M.update(s, inp, DT).stab_units
    out = run(s, inp, 1)
    T.check(not out.ap_disengage, "two A/Ps: no disengagement")
    T.near(out.stab_units, at, 1e-9, "the wheel switches inhibited")
    inp.autotrim_cmd = 1
    out = run(s, inp, 4)
    T.check(out.stab_units > at, "autotrim goes on")
    inp.trim_fo, inp.autotrim_cmd = 0, 0
    T.check(not out.unschd, "no STAB TRIM UNSCHD yet")
    inp.altn = -1
    at = out.stab_units
    out = run(s, inp, 1)
    T.near(out.stab_units, at - 0.5, 1e-6, "ALTN with the A/Ps: trims at full rate")
    T.check(out.unschd and out.st_unschd, "ALTN with an A/P engaged: STAB TRIM UNSCHD")
    T.check(out.mov_open[S2] and out.mov_open[S3], "no automatic cutout")
    inp.altn = 0
    out = run(s, inp, 29)
    T.check(out.unschd, "29 s after: still shown")
    out = run(s, inp, 1.5)
    T.check(not out.unschd and out.st_unschd, "30 s after it stopped: caution gone, STATUS stays")
    inp.ap_l, inp.ap_c = false, false
end

-- full-rate autotrim (ATA27 p.488, p.520): both SRMs, no delay, nose up to
-- 13.5; one SRM failed: not available
do
    local s, inp = stab_setup(150, 11.4)
    inp.ap_l, inp.ap_c, inp.ap_r, inp.frat_req, inp.autotrim_cmd = true, true, true, true, 1
    local out = run(s, inp, 0.2)
    T.near(out.stab_rate, 0.5, 1e-6, "full-rate autotrim: no delay, both modules")
    out = run(s, inp, 6)
    T.near(out.stab_units, 13.5, 1e-9, "nose up to 13.5")
    inp.srm_fail[2] = true
    inp.autotrim_cmd = -1
    out = run(s, inp, 1)
    T.near(out.stab_units, 13.5, 1e-9, "SRM R failed: no full rate, the delay again")
    out = run(s, inp, 3)
    T.near(out.stab_rate, -0.25, 1e-6, "half rate after 3.5 s")
end

-- runaway (ATA27 p.450, p.458): a module driving without a command; at
-- AUTO its valve closes once the monitor sees the movement (>STAB TRIM,
-- no UNSCHD); at ON nothing closes it: STAB TRIM UNSCHD until 30 s after
-- the crew's CUTOUT stops it; after the automatic cutout the valve opens
-- only through ON or CUTOUT
do
    local s, inp = stab_setup(200, 6)
    inp.runaway[S3] = 1
    local out = run(s, inp, 1)
    T.check(not out.mov_open[S3], "system 3's module ran: its valve closed")
    T.check(out.stab_units > 6 + M.UNSCHD_UNITS - 1e-6 and out.stab_units < 6 + M.UNSCHD_UNITS + 0.05, "stopped after the monitor's 0.1 units")
    T.check(out.stab_trim[S3] and not out.unschd, ">STAB TRIM 3, no STAB TRIM UNSCHD")
    T.check(out.mov_open[S2], "system 2's stays open")
    out = run(s, inp, 10)
    T.check(not out.mov_open[S3], "AUTO after the automatic cutout: stays closed")
    inp.cutout[S3] = M.CUTOUT
    out = run(s, inp, 0.1)
    inp.cutout[S3] = M.AUTO
    inp.runaway[S3] = 0
    out = run(s, inp, 5.1)
    T.check(out.mov_open[S3] and not out.stab_trim[S3], "CUTOUT then AUTO: open after 5 s")
    -- at ON
    inp.cutout[S3], inp.runaway[S3] = M.ON, -1
    local at = out.stab_units
    out = run(s, inp, 2)
    T.near(out.stab_units, at - 0.5, 1e-6, "ON: runs on at half rate")
    T.check(out.unschd and out.st_unschd, "STAB TRIM UNSCHD")
    inp.cutout[S3] = M.CUTOUT
    out = run(s, inp, 20)
    T.check(out.unschd, "stopped by CUTOUT, 20 s: still shown")
    out = run(s, inp, 11)
    T.check(not out.unschd and out.st_unschd, "30 s after: gone, STATUS stays")
    -- X-Plane's trim set from outside: not a movement
    s, inp = stab_setup(200, 6)
    M.stab_set(s, 9)
    out = run(s, inp, 1)
    T.near(out.stab_units, 9, 1e-9, "stab_set: placed")
    T.check(not out.unschd and out.mov_open[S2] and out.mov_open[S3], "no monitor trip")
    M.stab_set(s, 20)
    T.equal(s.stab, 15, "clamped to 15")
end

-- speed trim (step 2c; ATA22 p.155-159; ATA27 p.486): 20 s after liftoff,
-- at or below 220 kt, with nothing else trimming, the stabilizer follows the
-- speed, 2.55 units nose up from 120 to 220 kt, from where it engaged; one
-- module at half rate. Manual trim, the column cutout and an autopilot
-- disengage it and it synchronizes again; above 220 kt it is inhibited; the
-- air data sides 10 kt apart lose it in both SRMs
do
    local s, inp = stab_setup(160, 6)
    local out = run(s, inp, 19)
    T.check(not out.speed_trim, "19 s after liftoff: not yet")
    out = run(s, inp, 1.5)
    T.check(out.speed_trim, "20 s: speed trim engaged")
    T.near(out.stab_units, 6, 1e-9, "synchronized: no movement at the same speed")
    out = fly(s, inp, 180, 0.3, 1)
    T.near(out.stab_units, 6.25, 0.03, "+20 kt: nose up at half rate (0.25 units/s)")
    out = run(s, inp, 9)
    T.near(out.stab_units, 6 + 20 * 2.55 / 100, 0.03, "+20 kt: 0.51 units nose up (the p.159 law)")
    out = fly(s, inp, 160, 0.3, 10)
    T.near(out.stab_units, 6, 0.03, "back to 160 kt: back to where it engaged")
    out = fly(s, inp, 100, 0.2, 10)
    T.near(out.stab_units, 6 - 40 * 2.55 / 100, 0.03, "below 120 kt: no more than the 120 kt position")
    out = fly(s, inp, 160, 0.3, 10)
    -- manual trim disengages it; it synchronizes again where the pilot left it
    inp.trim_capt = 1
    out = run(s, inp, 1)
    T.check(not out.speed_trim, "manual trim: disengaged")
    inp.trim_capt = 0
    local at = M.update(s, inp, DT).stab_units
    out = run(s, inp, 5)
    T.check(out.speed_trim, "engaged again")
    T.near(out.stab_units, at, 1e-9, "synchronized to the new position: holds it")
    inp.column = -0.5
    out = run(s, inp, 0.2)
    T.check(not out.speed_trim, "the column past the cutout switches: disengaged")
    inp.column = 0
    inp.ap_l = true
    out = run(s, inp, 0.2)
    T.check(not out.speed_trim, "an autopilot (autotrim): no speed trim")
    inp.ap_l = false
    out = fly(s, inp, 230, 0.4, 1)
    T.check(not out.speed_trim, "230 kt: inhibited")
    inp.vc[1], inp.vc[2] = 200, 215
    out = run(s, inp, 0.2)
    T.check(not out.speed_trim and out.st_speed_trim, "the air data sides 15 kt apart: lost in both, STATUS STAB SPEED TRIM")
    inp.vc[2] = 200
    out = run(s, inp, 0.2)
    T.check(out.speed_trim and not out.st_speed_trim, "agreeing again: back")
    -- SRM L failed: SRM R takes it, through system 2's module
    inp.srm_fail[1] = true
    out = run(s, inp, 0.2)
    T.check(out.speed_trim and not out.st_speed_trim, "SRM L failed: SRM R has speed trim")
    inp.hyd_psi[S3] = 0
    at = out.stab_units
    out = fly(s, inp, 220, 0.35, 4)
    T.near(out.stab_units, at + 20 * 2.55 / 100, 0.03, "SRM R drives system 2's module (system 3 out): +0.51 units")
    inp.srm_fail[1], inp.hyd_psi[S3] = false, 3000
    -- the nose down limit in speed trim is 0.8 (p.483)
    s, inp = stab_setup(200, 1.3)
    run(s, inp, 21)
    out = fly(s, inp, 150, 0.25, 10)
    T.near(out.stab_units, 0.8, 1e-9, "speed trim nose down: stops at 0.8, not 1.8")
    -- on the ground: none
    inp.on_ground = true
    out = run(s, inp, 1)
    T.check(not out.speed_trim, "on the ground: no speed trim")
end

T.done()
