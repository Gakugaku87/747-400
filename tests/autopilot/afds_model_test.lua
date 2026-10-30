-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_model_test.lua
-- The FCCs' mode logic, steps 1a-1e (6-3: docs/overhaul/notes/ATA-22.md
-- §10): plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua.
-- 1a: the A/P's engage (CMD: the bar, the other channels, the servos'
-- hydraulics; on the ground too) and disengage (the bar, the control wheel
-- switches, automatically, the hydraulics), AUTOPILOT DISC and its reset,
-- the default modes on the A/P's engage and the first F/D ON (V/S with
-- HDG HOLD or ATT by the bank, PW and GE; T/O on the ground), everything
-- off with neither the A/P nor a F/D, the old approach's channels.
-- 1b: the roll modes HDG SEL, HDG HOLD (its heading after 2 s under 3
-- degrees), ATT, LNAV (arm, second push, engage, kept armed by HDG SEL),
-- the transitions from the old LOC and G/A, the FMA's roll.
-- (TO/GA as the 1e model has it: T/O by the first F/D ON on the ground, G/A
-- by A.toga in the air.)
-- 1c: the pitch modes V/S (synced: 000 after ALT and TO/GA descending),
-- ALT HOLD, the capture, FLCH (its speed), VNAV (arm, second push, the old
-- VNAV's engage and end), the transitions, the SPD switch, the FMA's pitch.
-- 1d: the approach modes LOC, G/S and APP (arms, second pushes, the mutual
-- disarms with LNAV and VNAV, captures within 120 and 80 degrees, either
-- first (the 109, the 570) or after LOC (a 405), deselects, TO/GA, the
-- A/P's engage with LOC and G/S engaged).
-- 1e: TO/GA (T/O's latches and resets, G/A's conditions, after the
-- takeoff only G/A's roll from 50 ft, the switches' inhibit after a
-- touchdown, the captures above 800 ft, LNAV from G/A, the F/Ds shown with
-- their switches OFF and cycled, the A/P engaged in it).
local T = dofile("tests/lib/check.lua")("afds_model")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua")

local HYD = {3000, 3000, 3000}
local function inp(o)
    o = o or {}
    return {fd = {L = o.fdL or false, R = o.fdR or false}, hyd = o.hyd or HYD, bank = o.bank or 0,
        engine = o.engine or 0, ground = o.ground or false, ra = o.ra or 9000,
        hdg = o.hdg or 100, lnav_valid = o.lnav_valid or false, flaps_up = o.flaps_up or false,
        old_armed_roll = o.old_armed_roll, dt = o.dt or 0.1, at_spd = o.at_spd or false,
        vs = o.vs or 0, alt = o.alt or 10000, old_pitch = o.old_pitch, window_open = o.window_open,
        ias = o.ias or 250, mcp_ias = o.mcp_ias or 250, fmc_speed = o.fmc_speed, capture = o.capture or false,
        capture_alt = o.capture_alt, vnav_engaged = o.vnav_engaged or false, vnav_fma = o.vnav_fma,
        old_law = o.old_law, old_armed_pitch = o.old_armed_pitch, old_hold_alt = o.old_hold_alt,
        loc_detect = o.loc_detect, gs_detect = o.gs_detect, course_err = o.course_err,
        gs_after_loc = o.gs_after_loc, sensors = o.sensors, power = o.power, gear_alt = o.gear_alt,
        fcc = o.fcc, mcp = o.mcp, stby = o.stby, iru = o.iru, adc = o.adc, trim = o.trim, wheel = o.wheel,
        cap = o.cap, loc_rx = o.loc_rx, gs_rx = o.gs_rx, ra_n = o.ra_n, iru_nav = o.iru_nav,
        iru_hdg = o.iru_hdg, adc_sel = o.adc_sel, pitch_att = o.pitch_att, ils_freq = o.ils_freq,
        loc_alive = o.loc_alive, loc_hdg_err = o.loc_hdg_err, gs_kt = o.gs_kt, bus_isolated = o.bus_isolated}
end

-- engage with both F/Ds OFF: V/S and HDG HOLD (FCOM p.640; ATA22 p.266)
local s = A.new()
local act = A.cmd(s, "L", inp())
T.check(s.L and A.engaged(s) == 1, "CMD L engages the left channel")
T.check(act and act.pitch == "VS" and s.roll == "HDG_HOLD", "with both F/Ds OFF: V/S and HDG HOLD")
T.equal(A.cmd(s, "C", inp()), nil, "a second channel does not engage in cruise (ATA22 p.314, p.318)")
T.check(not s.C and A.engaged(s) == 1, "only the left channel")
T.equal(A.cmd(s, "L", inp()), nil, "its own CMD again: nothing")

-- the bank: ATT above 5 degrees on the PW (and RR), held to 30; HDG HOLD
-- on the GE 570 (FCOM p.640, p.663)
local function engage_bank(bank, engine)
    local s2 = A.new()
    A.cmd(s2, "C", inp({bank = bank, engine = engine}))
    return s2
end
local a1 = engage_bank(12, 0)
T.check(a1.roll == "ATT" and a1.att_bank == 12, "PW, 12 degrees of bank: ATT holding 12")
local a2 = engage_bank(-40, 0)
T.check(a2.roll == "ATT" and a2.att_bank == -30, "PW, 40 degrees left: ATT to 30 left")
T.equal(engage_bank(4, 0).roll, "HDG_HOLD", "PW, 4 degrees: HDG HOLD")
T.equal(engage_bank(12, 1).roll, "HDG_HOLD", "GE, 12 degrees: HDG HOLD (no ATT)")
T.equal(engage_bank(12, 2).roll, "ATT", "RR, 12 degrees: ATT (as PW: estimate)")

-- no hydraulic pressure for the channel's servos (L system 3, C 1, R 2)
local s3 = A.new()
T.equal(A.cmd(s3, "L", inp({hyd = {3000, 3000, 0}})), nil, "CMD L without system 3: no engage")
T.check(A.engaged(s3) == 0 and not s3.disc, "nothing engaged, no warning")
T.check(A.cmd(s3, "C", inp({hyd = {3000, 3000, 0}})) ~= nil and s3.C, "CMD C with system 1: engaged")
-- the ground (the old code's 400 ft is in no source)
local s4 = A.new()
T.check(A.cmd(s4, "R", inp({ground = true})) ~= nil and s4.R, "on the ground the A/P engages too")

-- the disengage bar (FCOM p.640): all off and the warning, no engage while
-- down, lifting it does not reset the warning (ATA22 p.380)
A.bar(s, true)
T.check(A.engaged(s) == 0 and s.disc, "the bar down: disengaged, AUTOPILOT DISC")
T.equal(A.cmd(s, "L", inp()), nil, "CMD with the bar down: no engage")
A.bar(s, false)
T.check(s.disc, "the bar lifted: AUTOPILOT DISC stays")
A.cmd(s, "L", inp())
T.check(s.L and not s.disc, "an engage resets AUTOPILOT DISC")
local s5 = A.new()
A.bar(s5, true)
T.check(not s5.disc, "the bar down with nothing engaged: no warning")

-- the control wheel switches (FCOM p.655): the first push disengages with
-- the warning, the second resets it
A.wheel(s)
T.check(A.engaged(s) == 0 and s.disc, "a control wheel switch: disengaged, AUTOPILOT DISC")
A.wheel(s)
T.check(not s.disc, "the second push resets the warning")
A.wheel(s)
T.check(not s.disc and A.engaged(s) == 0, "a push with nothing engaged and no warning: nothing")

-- automatically (the stab trim switches with one A/P): the warning, reset
-- by the first push
A.cmd(s, "L", inp())
A.disengage(s)
T.check(A.engaged(s) == 0 and s.disc, "automatically: disengaged, AUTOPILOT DISC")
A.wheel(s)
T.check(not s.disc, "after an automatic disengage the first push resets")
-- quietly (the old autoland's disconnect on the rollout, until step 4)
A.cmd(s, "L", inp())
A.disengage(s, true)
T.check(A.engaged(s) == 0 and not s.disc, "quietly: no warning")

-- the channel's hydraulics lost: it drops out with the warning
A.cmd(s, "L", inp())
A.update(s, inp({hyd = {3000, 3000, 500}}))
T.check(A.engaged(s) == 0 and s.disc, "system 3 lost: the left channel out, AUTOPILOT DISC")

-- the F/Ds (FCOM p.639-640): the first ON in the air with no A/P: V/S and
-- HDG HOLD or ATT; the second ON: nothing; with the A/P engaged: nothing
local f = A.new()
T.equal(A.update(f, inp()), nil, "nothing on: nothing asked")
local fa = A.update(f, inp({fdL = true, bank = 3}))
T.check(fa and fa.pitch == "VS" and f.roll == "HDG_HOLD", "the first F/D ON in the air: V/S and HDG HOLD")
T.equal(A.update(f, inp({fdL = true, fdR = true})), nil, "the second F/D ON: nothing")
T.equal(A.update(f, inp({fdL = true, fdR = true})), nil, "and nothing after")
local f2 = A.new()
A.update(f2, inp({fdR = true, bank = -20}))
T.check(f2.roll == "ATT" and f2.att_bank == -20, "the first F/D ON at 20 degrees left: ATT")
local f3 = A.new()
local fc = A.update(f3, inp({fdL = true, ground = true}))
T.check(fc == nil and f3.roll == "TO" and f3.pitch == "TO", "the first F/D ON on the ground: T/O, roll and pitch (ATA22 p.337, p.353)")
T.check(A.toga_active(f3) and select(1, A.roll_fma(f3, inp())) == 1 and select(1, A.pitch_fma(f3, inp())) == 1,
    "the FMA's TO/GA (1) for both")
local f4 = A.new()
A.cmd(f4, "L", inp())
T.equal(A.update(f4, inp({fdL = true})), nil, "a F/D ON with the A/P engaged: the A/P's modes")

-- the A/P engaged with a F/D ON: its modes, but from the F/D's takeoff on
-- the ground HDG HOLD and V/S (ATA22 p.266)
local g = A.new()
A.update(g, inp({fdL = true, ground = true}))
local ga = A.cmd(g, "L", inp({fdL = true, ground = true}))
T.check(ga and ga.pitch == "VS" and g.roll == "HDG_HOLD" and g.pitch == "VS" and not A.toga_active(g),
    "the A/P on the ground ends T/O: HDG HOLD and V/S")
local g2 = A.new()
A.update(g2, inp({fdL = true, ground = true}))
T.equal(A.cmd(g2, "L", inp({fdL = true})), nil, "T/O in the air: the A/P in it")
T.check(g2.roll == "TO" and g2.pitch == "TO", "T/O kept")

-- everything off with neither the A/P nor a F/D (FCOM p.660)
local h = A.new()
A.update(h, inp({fdL = true}))
A.lnav(h, inp({fdL = true}))
local ho = A.update(h, inp())
T.check(ho and ho.all_off and not h.roll and not h.lnav_arm, "both F/Ds OFF with no A/P: everything off, LNAV's arm too")
T.equal(A.update(h, inp()), nil, "once")
local h2 = A.new()
A.cmd(h2, "C", inp())
T.equal(A.update(h2, inp()), nil, "the A/P engaged with the F/Ds OFF: modes on")
A.wheel(h2)
local h2o = A.update(h2, inp())
T.check(h2o and h2o.all_off, "the A/P disengaged with both F/Ds OFF: everything off")
local h3 = A.new()
A.update(h3, inp({fdL = true}))
A.cmd(h3, "L", inp({fdL = true}))
T.equal(A.update(h3, inp()), nil, "both F/Ds OFF with the A/P engaged: its modes stay")

-- 4a: multi-channel (ATA22 p.288, p.314, p.318; FCOM p.653, p.662,
-- p.671). APP with a channel engaged arms the others with hydraulic
-- pressure; none without one engaged
local function app_inp(o)
    o = o or {}
    o.fdL = true
    return inp(o)
end
local m0 = A.new()
A.update(m0, app_inp())
A.app(m0, app_inp())
T.equal(A.armed(m0), 0, "APP with no channel engaged: no multi-channel arm")
local m = A.new()
A.update(m, app_inp())
A.cmd(m, "C", app_inp())
A.app(m, app_inp({hyd = {3000, 0, 3000}}))
T.check(m.arm.L and not m.arm.C and not m.arm.R, "APP with C engaged: L armed, not R (system 2 without pressure)")
T.equal(A.engaged(m), 1, "armed, not engaged")
local function approach(st, o)
    o = o or {}
    o.loc_detect, o.gs_detect, o.course_err = true, true, o.course_err or 0
    o.ra = o.ra or 1400
    return A.update(st, app_inp(o))
end
-- three channels engaged in LOC and G/S at 1,400 ft (LAND 3)
local function land3()
    local st = A.new()
    A.update(st, app_inp())
    A.cmd(st, "L", app_inp())
    A.app(st, app_inp())
    for _ = 1, 55 do approach(st) end
    return st
end
-- LOC and G/S captured below 1,500 ft with the track on the course: the
-- armed channels engage 5 s later
m = A.new()
A.update(m, app_inp())
A.cmd(m, "L", app_inp())
A.app(m, app_inp())
T.check(m.arm.C and m.arm.R, "APP with L engaged: C and R armed")
approach(m, {ra = 1600})
T.equal(m.roll .. m.pitch, "LOCGS", "LOC and G/S captured")
for _ = 1, 60 do approach(m, {ra = 1600}) end
T.equal(A.engaged(m), 1, "above 1,500 ft: not engaged")
for _ = 1, 48 do approach(m) end
-- (4.8 s)
T.equal(A.engaged(m), 1, "4.8 s below 1,500 ft: not yet")
T.check(not m.rwy_align, "one channel: no runway align")
approach(m)
approach(m)
approach(m)
T.equal(A.engaged(m), 3, "5.1 s below 1,500 ft: all three engaged")
T.equal(A.armed(m), 0, "no arms left")
T.equal(A.status(m), A.STATUS.LAND3, "LAND 3")
T.check(m.flare_arm and m.rollout_arm, "FLARE and ROLLOUT armed")
T.check(m.rwy_align, "4d: LAND 3 in LOC: runway align (ATA22 p.361; FCOM p.670)")
T.equal(select(2, A.roll_fma(m, app_inp())), A.ROLL_FMA.ROLLOUT, "the FMA's ROLLOUT armed")
T.equal(select(2, A.pitch_fma(m, app_inp())), A.PITCH_FMA.FLARE, "the FMA's FLARE armed")
-- the track 3 degrees off the course: not engaged
local mt = A.new()
A.update(mt, app_inp())
A.cmd(mt, "L", app_inp())
A.app(mt, app_inp())
for _ = 1, 80 do approach(mt, {course_err = 3}) end
T.equal(A.engaged(mt), 1, "the track 3 degrees off the course: not engaged")
for _ = 1, 51 do approach(mt, {course_err = 1.5}) end
T.equal(A.engaged(mt), 3, "within 2 degrees: engaged")
-- LAND 2: a sensor of each kind down to two, or two channels; NO AUTOLAND
-- with one sensor
T.equal((function() approach(m, {sensors = 2}); return A.status(m) end)(), A.STATUS.LAND2, "two sensors valid: LAND 2")
T.equal((function() approach(m, {power = 2}); return A.status(m) end)(), A.STATUS.LAND2, "two power sources: LAND 2")
-- one sensor of a kind left (two of the same failed) with LOC and G/S
-- captured: the multi-channel engagement removed, all three (step 5a;
-- ATA22 p.320, p.322), AUTOPILOT DISC; with no A/P the F/D's FD
local md = land3()
T.equal(A.engaged(md) .. A.status(md), "3" .. A.STATUS.LAND3, "(land3: LAND 3)")
approach(md, {sensors = 1})
T.check(A.engaged(md) == 0 and md.disc, "5a: a dual failure of an autoland sensor: all three disengaged, AUTOPILOT DISC")
T.check(not md.flare_arm and not md.rollout_arm and not md.rwy_align, "no FLARE or ROLLOUT arm, no runway align")
T.equal(A.status(md), A.STATUS.FD, "no A/P engaged: FD, not NO AUTOLAND")
approach(m)
T.equal(A.status(m), A.STATUS.LAND3, "back: LAND 3")
-- below 200 ft LAND 3 to LAND 2 not shown (FCOM p.662)
approach(m, {ra = 150, sensors = 2})
T.equal(A.status(m), A.STATUS.LAND3, "150 ft, a sensor lost: still LAND 3")
-- a channel's hydraulics lost: LAND 2; down to one: NO AUTOLAND
approach(m, {ra = 800, hyd = {3000, 0, 3000}})
T.equal(A.engaged(m) .. A.status(m), "2" .. A.STATUS.LAND2, "a channel lost (system 2): two engaged, LAND 2")
approach(m, {ra = 800, hyd = {0, 0, 3000}})
T.equal(A.engaged(m) .. A.status(m), "1" .. A.STATUS.NO_AUTOLAND, "down to one channel: NO AUTOLAND")
-- a multi-channel approach without LAND 3 or 2 by 600 ft: NO AUTOLAND
-- (FCOM p.653); above it CMD
local mn = A.new()
A.update(mn, app_inp())
A.cmd(mn, "L", app_inp())
A.app(mn, app_inp())
approach(mn, {ra = 700, course_err = 5})
T.equal(A.status(mn), A.STATUS.CMD, "armed, 700 ft, not engaged: CMD")
approach(mn, {ra = 550, course_err = 5})
T.equal(A.status(mn), A.STATUS.NO_AUTOLAND, "550 ft without LAND 3 or 2: NO AUTOLAND")
-- a single-channel approach (nothing armed: the other channels' hydraulics
-- out) stays CMD
local ms = A.new()
A.update(ms, app_inp())
A.cmd(ms, "L", app_inp())
A.app(ms, app_inp({hyd = {0, 0, 3000}}))
approach(ms, {ra = 300, hyd = {0, 0, 3000}})
T.equal(A.status(ms), A.STATUS.CMD, "a single-channel approach: CMD")
-- the arms end with the first channel's disengage (ATA22 p.314) and with
-- the approach's end (the second APP push)
local md = A.new()
A.update(md, app_inp())
A.cmd(md, "L", app_inp())
A.app(md, app_inp())
A.disengage(md)
A.update(md, app_inp())
T.equal(A.armed(md), 0, "the first channel disengaged: the arms end")
local mp = A.new()
A.update(mp, app_inp())
A.cmd(mp, "L", app_inp())
A.app(mp, app_inp())
A.app(mp, app_inp())
T.equal(A.armed(mp), 0, "APP's second push: the arms end")
-- a multi-channel G/A into another mode: the first channel only (ATA22
-- p.318)
local mg = A.new()
A.update(mg, app_inp())
A.cmd(mg, "C", app_inp())
A.app(mg, app_inp())
for _ = 1, 51 do approach(mg) end
T.equal(A.engaged(mg), 3, "multi-channel")
A.toga(mg, app_inp({ra = 300}))
A.update(mg, app_inp({ra = 400}))
T.equal(A.engaged(mg), 3, "G/A: all three stay")
A.update(mg, app_inp({ra = 1500}))
A.vs(mg, app_inp({ra = 1500}))
A.update(mg, app_inp({ra = 1500}))
T.check(mg.C and not mg.L and not mg.R, "V/S from G/A: C (the first in command) only")
T.equal(A.status(mg), A.STATUS.CMD, "CMD")

-- 4b: FLARE (ATA22 p.294, p.342; FCOM p.671): the flare height by the sink
-- rate; engaged armed at it; the FMA's FLARE; the retard at 25 ft; at the
-- touchdown FLARE off and NOSE LETDOWN until the A/P's disengage; no other
-- pitch mode from FLARE but G/A
T.equal(A.flare_height(8), 40, "sink 8 ft/s: 40 ft")
T.equal(A.flare_height(13.5), 50, "13.5 ft/s: 50 ft")
T.equal(A.flare_height(20), 60, "20 ft/s: 60 ft")
T.near(A.flare_height(10.5), 45, 1e-9, "10.5 ft/s: 45 ft (between, an estimate)")
local function landing_in(o)
    local st = A.new()
    A.update(st, app_inp())
    A.cmd(st, "L", app_inp())
    A.app(st, app_inp())
    for _ = 1, 51 do approach(st, {vs = -800}) end
    return st
end
local mf = landing_in()
T.check(A.status(mf) == A.STATUS.LAND3 and mf.flare_arm, "LAND 3, FLARE armed")
approach(mf, {ra = 60, gear_alt = 55, vs = -800})
T.equal(mf.pitch, "GS", "55 ft of gear altitude at 13.3 ft/s: still G/S")
approach(mf, {ra = 54, gear_alt = 49, vs = -800})
T.equal(mf.pitch, "FLARE", "49 ft: FLARE")
T.equal(select(1, A.pitch_fma(mf, app_inp())), A.PITCH_FMA.FLARE, "the FMA's FLARE")
T.equal(select(2, A.pitch_fma(mf, app_inp())), 0, "nothing armed in pitch")
T.check(not mf.retard, "not yet the retard")
approach(mf, {ra = 25, gear_alt = 20, vs = -300})
T.check(mf.retard, "25 ft: the retard")
T.equal(A.status(mf), A.STATUS.LAND3, "LAND 3 kept in the flare")
T.equal(A.vs(mf, app_inp({ra = 25})), nil, "no V/S from FLARE")
-- 4c: ROLLOUT below 5 ft RA (FCOM p.664)
T.equal(mf.roll, "LOC", "25 ft: LOC")
T.equal(select(2, A.roll_fma(mf, app_inp())), A.ROLL_FMA.ROLLOUT, "ROLLOUT armed")
T.check(mf.rwy_align, "runway align in the flare")
approach(mf, {ra = 6, gear_alt = 2, vs = -150})
T.equal(mf.roll, "LOC", "6 ft: still LOC")
approach(mf, {ra = 4.5, gear_alt = 1, vs = -120})
T.equal(mf.roll, "ROLLOUT", "4.5 ft: ROLLOUT")
T.check(not mf.rwy_align, "ROLLOUT ends runway align (p.361)")
T.equal(select(1, A.roll_fma(mf, app_inp())), A.ROLL_FMA.ROLLOUT, "the FMA's ROLLOUT")
T.equal(select(2, A.roll_fma(mf, app_inp())), 0, "nothing armed in roll")
approach(mf, {ra = 0, gear_alt = 0, vs = -90, ground = true})
T.check(mf.pitch == nil and mf.letdown and mf.retard, "touchdown: FLARE off, NOSE LETDOWN, the retard kept (the A/T's IDLE: FCOM p.671)")
T.equal(select(1, A.pitch_fma(mf, app_inp({ground = true}))), 0, "the FMA's pitch blank")
T.equal(A.status(mf), A.STATUS.LAND3, "LAND 3 kept on the ground")
T.equal(mf.roll, "ROLLOUT", "on the ground: ROLLOUT kept (the approach's modes end, not it)")
for _ = 1, 50 do approach(mf, {ra = 0, gear_alt = 0, vs = 0, ground = true, ias = 40}) end
T.equal(mf.roll, "ROLLOUT", "40 kt: ROLLOUT until the A/Ps are disengaged (FCOM p.671)")
A.disengage(mf)
A.update(mf, app_inp({ground = true, ra = 0}))
T.check(not mf.letdown and not mf.retard, "the A/P disengaged: NOSE LETDOWN and the retard end")
T.check(mf.roll ~= "ROLLOUT", "the A/P disengaged: ROLLOUT ends")
-- a low sink rate flares lower: 6 ft/s at 45 ft not yet, 39 ft FLARE
local ml = landing_in()
approach(ml, {ra = 50, gear_alt = 45, vs = -360})
T.equal(ml.pitch, "GS", "6 ft/s at 45 ft: still G/S")
approach(ml, {ra = 44, gear_alt = 39, vs = -360})
T.equal(ml.pitch, "FLARE", "39 ft: FLARE")
-- G/A from FLARE
T.check(A.toga(ml, app_inp({ra = 30})) and ml.pitch == "GA", "TO/GA from FLARE: G/A")
A.update(ml, app_inp({ra = 30}))
T.check(not ml.rwy_align, "G/A ends runway align (p.361)")
-- no FLARE without LAND 3 or 2 (a single channel approach)
local m1 = A.new()
A.update(m1, app_inp())
A.cmd(m1, "L", app_inp())
A.app(m1, app_inp({hyd = {0, 0, 3000}}))
for _ = 1, 51 do approach(m1, {vs = -800, hyd = {0, 0, 3000}}) end
approach(m1, {ra = 40, gear_alt = 35, vs = -800, hyd = {0, 0, 3000}})
T.equal(m1.pitch, "GS", "a single channel: no FLARE (G/S to the ground)")

-- 1b: the roll modes. HDG SEL, then HDG HOLD: annunciated at once, its
-- heading once the roll stays under 3 degrees for 2 s (ATA22 figure p.353)
local r = A.new()
A.update(r, inp({fdL = true}))
T.check(A.hdg_sel(r, inp({fdL = true})) and r.roll == "HDG_SEL", "HDG SEL")
T.equal(select(1, A.roll_fma(r, inp())), 6, "the FMA's HDG SEL (6)")
T.check(A.hdg_hold(r, inp({fdL = true})) and r.roll == "HDG_HOLD", "HDG HOLD at once")
T.equal(select(1, A.roll_fma(r, inp())), 7, "the FMA's HDG HOLD (7)")
for _ = 1, 15 do A.update(r, inp({fdL = true, bank = 10, hdg = 120})) end
T.equal(r.hold_hdg, nil, "rolling out at 10 degrees: no heading yet")
for _ = 1, 15 do A.update(r, inp({fdL = true, bank = 2, hdg = 131})) end
T.equal(r.hold_hdg, nil, "1.5 s under 3 degrees: not yet")
for _ = 1, 6 do A.update(r, inp({fdL = true, bank = 1, hdg = 132})) end
T.equal(r.hold_hdg, 132, "2 s under 3 degrees: the heading then held")
-- ATT: by default only, held until a new roll mode (figure p.353)
local at = A.new()
A.update(at, inp({fdL = true, bank = 15}))
A.update(at, inp({fdL = true, bank = 2}))
T.equal(at.roll, "ATT", "ATT stays at 2 degrees of bank (no automatic HDG HOLD)")
T.equal(select(1, A.roll_fma(at, inp())), 5, "the FMA's ATT (5)")
A.hdg_sel(at, inp({fdL = true}))
T.check(at.roll == "HDG_SEL" and at.att_bank == 0, "HDG SEL ends ATT")

-- LNAV (FCOM p.644; ATA22 p.354): armed by the first push, the previous
-- roll mode active; HDG SEL keeps the arm; the second push disarms; armed
-- it engages above 50 ft with the FMC's steering valid; a push while
-- active does nothing; HDG HOLD deactivates it
local l = A.new()
A.update(l, inp({fdL = true}))
A.hdg_sel(l, inp({fdL = true}))
A.lnav(l, inp({fdL = true}))
T.check(l.lnav_arm and l.roll == "HDG_SEL", "LNAV armed, HDG SEL still active")
local la, larm = A.roll_fma(l, inp())
T.check(la == 6 and larm == 2, "the FMA: HDG SEL, LNAV armed")
A.hdg_sel(l, inp({fdL = true}))
T.check(l.lnav_arm, "HDG SEL again: LNAV stays armed (the old code disarmed it)")
A.lnav(l, inp({fdL = true}))
T.check(not l.lnav_arm, "the second push disarms")
A.lnav(l, inp({fdL = true}))
A.update(l, inp({fdL = true, lnav_valid = true, ra = 40}))
T.check(l.lnav_arm and l.roll == "HDG_SEL", "below 50 ft: still armed")
A.update(l, inp({fdL = true, lnav_valid = false}))
T.check(l.lnav_arm, "the FMC's steering not valid: still armed")
A.update(l, inp({fdL = true, lnav_valid = true}))
T.check(not l.lnav_arm and l.roll == "LNAV", "valid above 50 ft: LNAV engaged")
T.equal(select(1, A.roll_fma(l, inp())), 2, "the FMA's LNAV (2)")
A.lnav(l, inp({fdL = true}))
T.check(l.roll == "LNAV" and not l.lnav_arm, "a push while active: nothing (the old code disengaged it)")
A.hdg_hold(l, inp({fdL = true}))
T.check(l.roll == "HDG_HOLD", "HDG HOLD deactivates LNAV")

-- LOC (1d): its request ends LNAV's arm (ATA22 p.354), its capture LNAV;
-- LNAV not armed while it is engaged; HDG SEL from it only before G/S is
-- active (table p.351)
local c = A.new()
A.update(c, inp({fdL = true}))
A.lnav(c, inp({fdL = true}))
A.loc(c, inp())
T.check(c.loc_arm and not c.lnav_arm, "the LOC request ends LNAV's arm")
c.roll = "LNAV"
A.update(c, inp({fdL = true, loc_detect = true, course_err = 30}))
T.check(c.roll == "LOC" and not c.loc_arm, "LOC captured: LNAV ends")
A.lnav(c, inp({fdL = true}))
T.check(not c.lnav_arm, "LNAV not armed with LOC engaged")
T.equal(select(1, A.roll_fma(c, inp())), 3, "the FMA's LOC (3)")
c.pitch = "GS"
T.equal(A.hdg_sel(c, inp()), false, "HDG SEL with LOC and G/S active: no")
T.equal(A.hdg_hold(c, inp()), false, "HDG HOLD with LOC and G/S active: no")
c.pitch = nil
T.equal(A.hdg_sel(c, inp()), true, "HDG SEL with LOC before G/S: yes")
-- G/A (a TO/GA push in the air, the flaps out of up): below 400 ft it
-- keeps its roll (table p.351); T/O allows the roll modes at any height
local t = A.new()
A.update(t, inp({fdL = true}))
T.equal(A.toga(t, inp({fdL = true, ra = 300})), true, "a TO/GA push in the air: G/A")
T.check(t.roll == "GA" and t.pitch == "GA", "G/A's roll and pitch")
T.equal(select(1, A.roll_fma(t, inp())), 1, "the FMA's TO/GA (1) over the F/D's HDG HOLD")
T.equal(A.hdg_sel(t, inp({ra = 300})), false, "HDG SEL in G/A below 400 ft: no")
A.lnav(t, inp({ra = 300}))
T.check(not t.lnav_arm, "LNAV in G/A below 400 ft: no")
local tk = A.new()
A.update(tk, inp({fdL = true, ground = true}))
T.equal(A.hdg_sel(tk, inp({ra = 300})), true, "HDG SEL in T/O below 400 ft: yes (table p.351)")
T.equal(A.hdg_sel(t, inp({ra = 600})), true, "HDG SEL in G/A above 400 ft: yes")
T.equal(select(1, A.roll_fma(t, inp())), 6, "the FMA's HDG SEL over G/A's roll")
A.toga(t, inp({fdL = true, ra = 600}))
T.equal(select(1, A.roll_fma(t, inp())), 1, "TO/GA again: G/A's roll again")
-- the HDG REF switch in HDG SEL: HDG HOLD by default (ATA22 p.352)
c.roll, c.pitch = "LOC", "GS"
T.equal(A.hdg_hold(c, inp(), true), true, "HDG HOLD by default: no conditions")

-- 1c: the pitch modes. V/S synced to the present vertical speed (100 fpm,
-- -8000..+6000), 000 after ALT or after TO/GA descending (ATA22 p.282)
local p = A.new()
A.update(p, inp({fdL = true, vs = 1234}))
T.equal(p.pitch, "VS", "the F/D's default: V/S in the model")
T.equal(select(1, A.pitch_fma(p, inp())), 7, "the FMA's V/S (7)")
T.equal(A.vs(p, inp({vs = 1234})), 1200, "V/S synced to 1,234 fpm: 1,200")
T.equal(A.vs(p, inp({vs = -9300})), -8000, "the window's -8,000 at most")
T.equal(A.vs(p, inp({vs = 7100})), 6000, "+6,000 at most")
T.check(A.alt_hold(p, inp({alt = 12345})) and p.pitch == "ALT" and p.hold_alt == 12345, "ALT HOLD: the altitude then")
T.equal(select(1, A.pitch_fma(p, inp())), 9, "the FMA's ALT (9)")
T.equal(A.vs(p, inp({vs = 800})), 0, "V/S after ALT: 000")
local pt = A.new()
A.update(pt, inp({fdL = true}))
A.toga(pt, inp({fdL = true}))
T.equal(select(1, A.pitch_fma(pt, inp())), 1, "G/A's pitch (1)")
T.equal(A.vs(pt, inp({vs = -500})), 0, "V/S from TO/GA descending: 000")
T.equal(select(1, A.pitch_fma(pt, inp())), 7, "V/S over TO/GA's pitch")
local pt2 = A.new()
A.update(pt2, inp({fdL = true}))
A.toga(pt2, inp({fdL = true}))
T.equal(A.vs(pt2, inp({vs = 1500})), 1500, "V/S from TO/GA climbing: synced")
-- the transitions (table p.335): G/A below 400 ft, the old G/S once LOC is
-- active, FLARE
local pg = A.new()
A.update(pg, inp({fdL = true}))
A.toga(pg, inp({fdL = true, ra = 300}))
T.equal(A.vs(pg, inp({ra = 300})), nil, "V/S in G/A below 400 ft: no")
T.equal(A.alt_hold(pg, inp({ra = 300})), false, "ALT HOLD in G/A below 400 ft: no")
T.equal(A.flch(pg, inp({ra = 300})), false, "FLCH in G/A below 400 ft: no")
pg.pitch, pg.roll = "GS", "LOC"
T.equal(A.vs(pg, inp()), nil, "V/S from G/S with LOC active: no")
pg.roll = "HDG_HOLD"
T.check(A.vs(pg, inp()) ~= nil, "V/S from G/S before LOC: yes")
pg.pitch = "FLARE"
T.equal(A.alt_hold(pg, inp()), false, "nothing from FLARE")
-- FLCH (FCOM p.646): the window open: as it is; blank: the FMC's target,
-- else the present speed; from TO/GA the higher of the present and the
-- selected
local pf = A.new()
A.update(pf, inp({fdL = true}))
local ok1, sp1 = A.flch(pf, inp({window_open = true, ias = 250, mcp_ias = 270}))
T.check(ok1 and pf.pitch == "FLCH" and sp1 == nil, "FLCH with the window open: its speed as it is")
T.equal(select(1, A.pitch_fma(pf, inp())), 8, "the FMA's FLCH SPD (8)")
local _, sp2 = A.flch(pf, inp({window_open = false, ias = 250, fmc_speed = 290}))
T.equal(sp2, 290, "the window blank: the FMC's target")
local _, sp3 = A.flch(pf, inp({window_open = false, ias = 250}))
T.equal(sp3, 250, "the window blank, no FMC target: the present speed")
local pf2 = A.new()
A.update(pf2, inp({fdL = true}))
A.toga(pf2, inp({fdL = true}))
local _, sp4 = A.flch(pf2, inp({window_open = true, ias = 175, mcp_ias = 160}))
T.equal(sp4, 175, "from TO/GA: the higher of the present 175 and the selected 160")
-- the capture of the MCP altitude from V/S and FLCH (the old window)
A.update(pf, inp({fdL = true, capture = true, capture_alt = 15000}))
T.check(pf.pitch == "ALT" and pf.hold_alt == 15000, "FLCH captures the MCP altitude: ALT at 15,000")
local pc = A.new()
A.update(pc, inp({fdL = true}))
A.alt_hold(pc, inp({alt = 9000}))
A.update(pc, inp({fdL = true, capture = true, capture_alt = 9500}))
T.equal(pc.hold_alt, 9000, "ALT HOLD is not a capture: still 9,000")
-- VNAV (FCOM p.645; ATA22 p.340): armed by the first push, the active mode
-- stays (the old arm forced ALT HOLD); the second push disarms; engaged by
-- the old VNAV; V/S ends it, not its arm; not armed with G/S active
local pv = A.new()
A.update(pv, inp({fdL = true}))
A.alt_hold(pv, inp({alt = 9000}))
A.vnav(pv, inp())
T.check(pv.vnav_arm and pv.pitch == "ALT", "VNAV armed, ALT still active")
local va, varm = A.pitch_fma(pv, inp())
T.check(va == 9 and varm == 4, "the FMA: ALT, VNAV armed")
A.vnav(pv, inp())
T.check(not pv.vnav_arm, "the second push disarms")
A.vnav(pv, inp())
A.update(pv, inp({fdL = true, vnav_engaged = true}))
T.check(pv.pitch == "VNAV" and not pv.vnav_arm, "the old VNAV engaged: VNAV")
T.equal(select(1, A.pitch_fma(pv, inp({vnav_fma = 6}))), 6, "the FMA: the old VNAV's VNAV PTH")
A.vnav(pv, inp())
T.equal(pv.pitch, "VNAV", "a push while active: nothing")
A.vnav(pv, inp())
T.check(not pv.vnav_arm, "and no arm either")
A.vs(pv, inp({vs = 0}))
T.equal(pv.pitch, "VS", "V/S ends VNAV")
local pv2 = A.new()
A.update(pv2, inp({fdL = true}))
pv2.pitch = "GS"
A.vnav(pv2, inp())
T.check(not pv2.vnav_arm, "VNAV not armed with G/S active")
pv2.pitch = "VS"
A.vnav(pv2, inp())
A.vs(pv2, inp({vs = 0}))
T.check(pv2.vnav_arm, "V/S keeps VNAV's arm")
-- VNAV ended by the old VNAV (no route): the old law's mode then
local pv3 = A.new()
A.update(pv3, inp({fdL = true}))
A.vnav(pv3, inp())
A.update(pv3, inp({fdL = true, vnav_engaged = true}))
A.update(pv3, inp({fdL = true, vnav_engaged = false, old_law = "ALT", alt = 31000}))
T.check(pv3.pitch == "ALT" and pv3.hold_alt == 31000, "the old VNAV ended: its ALT")
-- the SPD switch (FCOM p.642)
T.equal(A.spd_works(pv3, inp()), true, "SPD works in ALT")
A.flch(pv3, inp({window_open = true}))
T.equal(A.spd_works(pv3, inp()), false, "not in FLCH SPD")
T.equal(A.spd_works(pt2, inp()), true, "in V/S after TO/GA")
local pt3 = A.new()
A.update(pt3, inp({fdL = true}))
A.toga(pt3, inp({fdL = true}))
T.equal(A.spd_works(pt3, inp()), false, "not in TO/GA")
-- everything off clears the pitch
local po = A.new()
A.update(po, inp({fdL = true}))
A.vnav(po, inp())
A.update(po, inp())
T.check(not po.pitch and not po.vnav_arm, "everything off: no pitch mode, no VNAV arm")
-- the old VNAV ended into ALT: at the old law's altitude
local pv4 = A.new()
A.update(pv4, inp({fdL = true}))
A.vnav(pv4, inp())
A.update(pv4, inp({fdL = true, vnav_engaged = true}))
A.update(pv4, inp({fdL = true, vnav_engaged = false, old_law = "ALT", alt = 30950, old_hold_alt = 31000}))
T.check(pv4.pitch == "ALT" and pv4.hold_alt == 31000, "the old VNAV ended: ALT at its 31,000 (not the present 30,950)")
-- VNAV lost (no route for the old VNAV): the arm ends, the active mode stays
local pv5 = A.new()
A.update(pv5, inp({fdL = true}))
A.alt_hold(pv5, inp({alt = 9000}))
A.vnav(pv5, inp())
A.vnav_lost(pv5)
T.check(not pv5.vnav_arm and pv5.pitch == "ALT", "VNAV lost: the arm ends, ALT stays")
-- G/S captured ends the pitch mode (FCOM p.645)
local pg2 = A.new()
A.update(pg2, inp({fdL = true}))
A.alt_hold(pg2, inp({alt = 3000}))
A.app(pg2, inp())
A.update(pg2, inp({fdL = true, loc_detect = true, course_err = 10}))
A.update(pg2, inp({fdL = true, gs_detect = true, course_err = 10}))
T.check(pg2.pitch == "GS" and not pg2.hold_alt and not pg2.vnav_arm, "G/S captured: no other pitch mode, no VNAV arm")
T.equal(select(1, A.pitch_fma(pg2, inp())), 2, "the FMA's G/S (2)")
-- ALT HOLD by default in FLCH 8,000 ft away from the path to the MCP
-- altitude (ATA22 p.338), from the nearest point (an estimate)
local pa = A.new()
A.update(pa, inp({fdL = true}))
A.flch(pa, inp({window_open = true, alt = 20000}))
A.update(pa, inp({fdL = true, alt = 21000, capture_alt = 30000}))
A.update(pa, inp({fdL = true, alt = 14000, capture_alt = 30000}))
T.equal(pa.pitch, "FLCH", "FLCH 7,000 ft below the nearest 21,000: still FLCH")
A.update(pa, inp({fdL = true, alt = 12900, capture_alt = 30000}))
T.check(pa.pitch == "ALT" and pa.hold_alt == 12900, "8,100 ft away: ALT HOLD at 12,900 (the default)")
local pa2 = A.new()
A.update(pa2, inp({fdL = true}))
A.flch(pa2, inp({window_open = true, alt = 15000}))
A.update(pa2, inp({fdL = true, alt = 15000, capture_alt = 20000}))
A.update(pa2, inp({fdL = true, alt = 16000, capture_alt = 5000}))
T.equal(pa2.pitch, "FLCH", "the MCP altitude reset below, 1,000 ft on: FLCH")
A.update(pa2, inp({fdL = true, alt = 24100, capture_alt = 5000}))
T.equal(pa2.pitch, "ALT", "8,100 ft past the nearest: ALT HOLD")
-- G/A's pitch replaces the pitch mode (VNAV too: FCOM p.645), not VNAV's
-- arm (ATA22 p.340)
local pt4 = A.new()
A.update(pt4, inp({fdL = true}))
A.alt_hold(pt4, inp({alt = 3000}))
A.vnav(pt4, inp())
A.toga(pt4, inp({fdL = true}))
T.check(pt4.pitch == "GA" and not pt4.hold_alt and pt4.vnav_arm, "G/A: its pitch, VNAV still armed")
T.equal(select(1, A.pitch_fma(pt4, inp())), 1, "the FMA's TO/GA")
local pt5 = A.new()
A.update(pt5, inp({fdL = true}))
A.vnav(pt5, inp())
A.update(pt5, inp({fdL = true, vnav_engaged = true}))
A.toga(pt5, inp({fdL = true}))
T.check(pt5.pitch == "GA", "TO/GA ends VNAV")
-- VNAV from G/A at any height (table p.335: V/S, ALT HOLD and FLCH only
-- above 400 ft)
local pv6 = A.new()
A.update(pv6, inp({fdL = true}))
A.toga(pv6, inp({fdL = true, ra = 300}))
A.vnav(pv6, inp({ra = 300}))
T.check(pv6.vnav_arm, "VNAV armed in G/A below 400 ft")

-- 1d: the approach modes (ATA22 p.342-343, p.356-357; FCOM p.650-652).
-- LOC: armed, the second push disarms; LNAV's arm disarms a LOC only arm
local a = A.new()
A.update(a, inp({fdL = true}))
A.loc(a, inp())
T.check(a.loc_arm and not a.gs_arm, "LOC armed")
local ar, aa = A.roll_fma(a, inp())
T.check(ar == 7 and aa == 3, "the FMA: HDG HOLD, LOC armed")
A.loc(a, inp())
T.check(not a.loc_arm, "the second LOC push disarms")
A.loc(a, inp())
A.lnav(a, inp())
T.check(a.lnav_arm and not a.loc_arm, "LNAV's arm disarms a LOC only arm")
-- HDG SEL keeps LOC's arm (the figure p.357: FCOM's "another roll mode")
local a2 = A.new()
A.update(a2, inp({fdL = true}))
A.loc(a2, inp())
A.hdg_sel(a2, inp())
T.check(a2.loc_arm and a2.roll == "HDG_SEL", "HDG SEL keeps LOC's arm")
-- no LOC or APP from TO/GA (tables p.351, p.335)
local a3 = A.new()
A.update(a3, inp({fdL = true}))
A.toga(a3, inp({fdL = true}))
A.loc(a3, inp())
A.app(a3, inp())
T.check(not a3.loc_arm and not a3.gs_arm, "no LOC or APP from TO/GA")
-- the capture only with the track within 120 degrees of the course
local a4 = A.new()
A.update(a4, inp({fdL = true}))
A.loc(a4, inp())
A.update(a4, inp({fdL = true, loc_detect = true, course_err = 130}))
T.check(a4.loc_arm and a4.roll ~= "LOC", "no capture 130 degrees off the course")
A.update(a4, inp({fdL = true, loc_detect = true, course_err = -110}))
T.check(a4.roll == "LOC" and not a4.loc_arm, "captured 110 degrees off")
T.check(A.loc_engaged_now(a4) and not A.loc_engaged_now(a4), "the capture's event once (the MCP heading to the course)")
-- APP: both armed, its second push disarms both; LOC with APP armed: a
-- localizer approach; LNAV's or VNAV's arm disarms APP; APP ends theirs
local b = A.new()
A.update(b, inp({fdL = true}))
A.alt_hold(b, inp({alt = 3000}))
A.app(b, inp())
T.check(b.loc_arm and b.gs_arm, "APP: LOC and G/S armed")
local bp, ba = A.pitch_fma(b, inp())
T.check(bp == 9 and ba == 2, "the FMA: ALT, G/S armed")
A.app(b, inp())
T.check(not b.loc_arm and not b.gs_arm, "the second APP push disarms both")
A.app(b, inp())
A.loc(b, inp())
T.check(b.loc_arm and not b.gs_arm, "LOC with APP armed: a localizer approach")
A.app(b, inp())
A.lnav(b, inp())
T.check(b.lnav_arm and not b.loc_arm and not b.gs_arm, "LNAV's arm disarms APP")
A.app(b, inp())
T.check(not b.lnav_arm and b.loc_arm and b.gs_arm, "APP ends LNAV's arm")
A.vnav(b, inp())
T.check(b.vnav_arm and not b.loc_arm and not b.gs_arm, "VNAV's arm disarms APP")
A.app(b, inp())
T.check(not b.vnav_arm, "APP ends VNAV's arm")
-- G/S: the 109 (PW) and the 570 (GE) capture it either first (FCOM
-- p.669), within 80 degrees; a 405 only with LOC engaged (p.670: an input
-- no airplane sets)
local b4 = A.new()
for k, v in pairs(b) do b4[k] = v end
A.update(b4, inp({fdL = true, gs_detect = true, course_err = 20, gs_after_loc = true}))
T.check(b4.gs_arm and b4.pitch == "ALT", "a 405: no G/S before LOC")
local gp = A.new()
A.update(gp, inp({fdL = true}))
A.alt_hold(gp, inp({alt = 3000}))
A.app(gp, inp())
A.update(gp, inp({fdL = true, gs_detect = true, course_err = 20}))
T.check(gp.pitch == "GS" and gp.loc_arm, "PW (the 109): G/S first, LOC still armed")
local g = A.new()
A.update(g, inp({fdL = true, engine = 1}))
A.alt_hold(g, inp({alt = 3000, engine = 1}))
A.app(g, inp({engine = 1}))
A.update(g, inp({fdL = true, engine = 1, gs_detect = true, course_err = 20}))
T.check(g.pitch == "GS" and g.loc_arm, "GE: G/S first, LOC still armed")
T.equal(select(2, A.roll_fma(g, inp({engine = 1}))), 3, "the FMA: LOC armed")
local g2 = A.new()
A.update(g2, inp({fdL = true, engine = 1}))
A.app(g2, inp({engine = 1}))
A.update(g2, inp({fdL = true, engine = 1, gs_detect = true, course_err = 85}))
T.check(g2.gs_arm and g2.pitch ~= "GS", "no G/S 85 degrees off")
-- G/S engaged, LOC armed (570): a pitch mode other than VNAV ends LOC's arm
-- (FCOM p.652)
A.alt_hold(g, inp({alt = 2800, engine = 1}))
T.check(g.pitch == "ALT" and not g.loc_arm, "ALT HOLD after G/S: LOC's arm ends")
-- LOC engaged, G/S armed: HDG SEL ends G/S's arm (APP deselected); LOC
-- pushed: a localizer approach
A.update(b, inp({fdL = true, loc_detect = true, course_err = 20}))
T.check(b.roll == "LOC" and b.gs_arm, "LOC captured, G/S armed")
local bh = A.new()
for k, v in pairs(b) do bh[k] = v end
A.hdg_sel(bh, inp())
T.check(bh.roll == "HDG_SEL" and not bh.gs_arm, "HDG SEL after LOC: G/S's arm ends")
A.loc(b, inp())
T.check(b.roll == "LOC" and not b.gs_arm, "LOC pushed after LOC: a localizer approach")
-- LOC and G/S engaged: no HDG SEL, no V/S (tables); TO/GA ends them
local c2 = A.new()
A.update(c2, inp({fdL = true}))
A.alt_hold(c2, inp({alt = 3000}))
A.app(c2, inp())
A.update(c2, inp({fdL = true, loc_detect = true, course_err = 5}))
A.update(c2, inp({fdL = true, gs_detect = true, course_err = 5}))
T.check(c2.roll == "LOC" and c2.pitch == "GS", "LOC and G/S engaged")
local cp, ca = A.pitch_fma(c2, inp())
T.check(cp == 2 and ca == 0, "the FMA: G/S, nothing armed")
T.equal(A.hdg_sel(c2, inp()), false, "no HDG SEL after G/S")
T.equal(A.vs(c2, inp()), nil, "no V/S after LOC")
A.toga(c2, inp({fdL = true, flaps_up = true, ra = 600}))
T.check(c2.roll == "GA" and c2.pitch == "GA" and not c2.loc_arm and not c2.gs_arm,
    "TO/GA (G/S engaged, flaps up) ends LOC and G/S: G/A")
-- the A/P engaged with a F/D ON and LOC, G/S engaged: HDG HOLD with LOC
-- armed, V/S with G/S armed (ATA22 p.266)
local e = A.new()
A.update(e, inp({fdL = true}))
A.alt_hold(e, inp({alt = 3000}))
A.app(e, inp({fdL = true}))
A.update(e, inp({fdL = true, loc_detect = true, course_err = 5}))
A.update(e, inp({fdL = true, gs_detect = true, course_err = 5}))
local act = A.cmd(e, "L", inp({fdL = true}))
T.check(e.roll == "HDG_HOLD" and e.loc_arm and e.pitch == "VS" and e.gs_arm, "the A/P engaged: HDG HOLD, V/S, LOC and G/S armed")
T.check(act and act.pitch == "VS", "V/S asked for (synced)")
-- on the ground the approach modes end
A.update(e, inp({fdL = true, ground = true}))
T.check(not e.loc_arm and not e.gs_arm, "on the ground: no approach")
-- everything off clears them
local o2 = A.new()
A.update(o2, inp({fdL = true}))
A.app(o2, inp())
A.update(o2, inp())
T.check(not o2.loc_arm and not o2.gs_arm, "everything off: no approach")

-- 1e: TO/GA (ATA22 p.337, p.353, p.355; table p.335; FCOM p.656-657,
-- p.661, p.666, p.672-673). T/O's pitch reset by the A/T in SPD, its roll
-- kept until a roll mode
local to = A.new()
A.update(to, inp({fdL = true, ground = true}))
A.update(to, inp({fdL = true, ra = 200, at_spd = true}))
T.check(to.pitch == nil and to.roll == "TO", "T/O: the A/T in SPD ends its pitch, not its roll")
-- T/O's roll ends with LNAV above 50 ft (FCOM p.666), its pitch with VNAV
local to2 = A.new()
A.update(to2, inp({fdL = true, ground = true}))
A.lnav(to2, inp({ground = true}))
A.vnav(to2, inp({ground = true}))
T.check(to2.lnav_arm and to2.vnav_arm and to2.roll == "TO", "LNAV and VNAV armed on the ground in T/O")
A.update(to2, inp({fdL = true, ra = 40, lnav_valid = true}))
T.equal(to2.roll, "TO", "below 50 ft: T/O's roll")
A.update(to2, inp({fdL = true, ra = 60, lnav_valid = true}))
T.check(to2.roll == "LNAV" and to2.pitch == "TO", "above 50 ft: LNAV, T/O's pitch")
A.update(to2, inp({fdL = true, ra = 420, lnav_valid = true, vnav_engaged = true}))
T.equal(to2.pitch, "VNAV", "VNAV engaged: T/O's pitch ends")
-- the MCP altitude captured from T/O only above 800 ft RA (table p.335)
local tc = A.new()
A.update(tc, inp({fdL = true, ground = true}))
A.update(tc, inp({fdL = true, ra = 700, capture = true, capture_alt = 1000}))
T.equal(tc.pitch, "TO", "no capture from T/O at 700 ft")
A.update(tc, inp({fdL = true, ra = 900, capture = true, capture_alt = 1000}))
T.check(tc.pitch == "ALT" and tc.hold_alt == 1000, "above 800 ft: ALT at 1,000")
-- after the takeoff a TO/GA push with T/O's pitch: G/A's roll only, from
-- 50 ft (FCOM p.656)
local tg = A.new()
A.update(tg, inp({fdL = true, ground = true}))
A.lnav(tg, inp({ground = true}))
A.update(tg, inp({fdL = true, ra = 100, lnav_valid = true}))
T.equal(tg.roll, "LNAV", "LNAV at 100 ft")
T.equal(A.toga(tg, inp({fdL = true, ra = 30})), false, "a push below 50 ft: nothing")
T.equal(tg.roll, "LNAV", "LNAV kept")
T.equal(A.toga(tg, inp({fdL = true, ra = 200})), false, "a push at 200 ft: no G/A pitch")
T.check(tg.roll == "GA" and tg.pitch == "TO", "G/A's roll, T/O's pitch")
-- G/A's conditions: in the air, the flaps out of up or G/S engaged
local gc = A.new()
A.update(gc, inp({fdL = true}))
T.equal(A.toga(gc, inp({fdL = true, flaps_up = true})), false, "flaps up, no G/S: no G/A")
T.equal(gc.pitch, "VS", "the pitch mode kept")
T.equal(A.toga(gc, inp({fdL = true, ground = true})), false, "on the ground: no G/A")
-- the switches inhibited 2 s after the radio altitude goes below 5 ft,
-- enabled 3 s after it goes above (FCOM p.672); G/A stays through a
-- touchdown
local gi = A.new()
A.update(gi, inp({fdL = true, ra = 3, dt = 1.5}))
A.update(gi, inp({fdL = true, ra = 3, dt = 0.6}))
T.equal(A.toga(gi, inp({fdL = true, ra = 3})), false, "2 s below 5 ft: the switches inhibited")
A.update(gi, inp({fdL = true, ra = 20, dt = 2.5}))
T.equal(A.toga(gi, inp({fdL = true, ra = 20})), false, "2.5 s above 5 ft: still inhibited")
A.update(gi, inp({fdL = true, ra = 20, dt = 0.6}))
T.equal(A.toga(gi, inp({fdL = true, ra = 20})), true, "3 s above: G/A")
A.update(gi, inp({fdL = true, ra = 0, ground = true, dt = 3}))
T.equal(gi.pitch, "GA", "G/A kept through the touchdown")
-- G/A from no mode: the F/Ds shown with their switches OFF above 80 kt,
-- the flaps out of up (FCOM p.657, p.661); a switch cycled ON and OFF ends
-- it
local gn = A.new()
A.update(gn, inp())
T.check(A.toga(gn, inp({ias = 140})) and gn.roll == "GA" and gn.pitch == "GA" and A.fd_auto(gn),
    "no A/P or F/D: G/A, the F/Ds shown")
T.equal(A.update(gn, inp()), nil, "kept with both switches OFF")
T.equal(gn.pitch, "GA", "G/A kept")
A.update(gn, inp({fdL = true}))
T.check(gn.pitch == "GA" and gn.roll == "GA" and A.fd_auto(gn), "a switch ON: no defaults, G/A kept")
local go = A.update(gn, inp())
T.check(go and go.all_off and not gn.pitch and not A.fd_auto(gn), "and OFF: everything off")
local gs80 = A.new()
A.update(gs80, inp())
A.toga(gs80, inp({ias = 70}))
T.check(not A.fd_auto(gs80), "below 80 kt: not shown")
-- the A/P engaged with the F/Ds shown by TO/GA: G/A kept
local ge = A.new()
A.update(ge, inp())
A.toga(ge, inp({ias = 140}))
T.equal(A.cmd(ge, "L", inp()), nil, "the A/P engaged in G/A (the F/Ds shown)")
T.check(ge.roll == "GA" and ge.pitch == "GA", "G/A kept")
-- G/A keeps LNAV's arm (ATA22 p.354); LNAV engages from G/A only above
-- 400 ft (table p.351)
local gl = A.new()
A.update(gl, inp({fdL = true}))
A.lnav(gl, inp())
A.toga(gl, inp({fdL = true, ra = 300}))
T.check(gl.lnav_arm, "G/A keeps LNAV's arm")
A.update(gl, inp({fdL = true, ra = 300, lnav_valid = true}))
T.equal(gl.roll, "GA", "below 400 ft: G/A's roll")
A.update(gl, inp({fdL = true, ra = 450, lnav_valid = true}))
T.equal(gl.roll, "LNAV", "above 400 ft: LNAV")
-- the MCP altitude captured from G/A only above 800 ft RA (table p.335)
local gk = A.new()
A.update(gk, inp({fdL = true}))
A.toga(gk, inp({fdL = true, ra = 300}))
A.update(gk, inp({fdL = true, ra = 600, capture = true, capture_alt = 1500}))
T.equal(gk.pitch, "GA", "no capture from G/A at 600 ft")
A.update(gk, inp({fdL = true, ra = 1000, capture = true, capture_alt = 1500}))
T.equal(gk.pitch, "ALT", "above 800 ft: ALT")
T.check(gk.roll == "GA" and A.toga_active(gk), "G/A's roll kept: TO/GA still active")

-- 5a: the engage interlocks (ATA22 p.302-322; FCOM p.47). Each FCC's
-- power (AC and DC: p.191): to engage and to stay engaged
local e = A.new()
local noL, noC = {L = false, C = true, R = true}, {L = true, C = false, R = true}
T.equal(A.cmd(e, "L", inp({fcc = noL})), nil, "5a: L's FCC unpowered: CMD L does not engage")
T.check(not e.L, "L not engaged")
A.cmd(e, "C", inp({fcc = noL}))
T.check(e.C, "C's FCC powered: CMD C engages")
A.update(e, inp({fcc = noC}))
T.check(not e.C and e.disc, "C's FCC unpowered once engaged: disengaged, AUTOPILOT DISC")
-- the MCP (either of its channels: p.209, p.314)
e = A.new()
T.equal(A.cmd(e, "R", inp({mcp = false})), nil, "the MCP not valid: no engage")
A.cmd(e, "R", inp())
A.update(e, inp({mcp = false}))
T.check(not e.R and e.disc, "the MCP lost: disengaged")
-- the 28V DC STBY bus: needed to engage, not to stay engaged (p.304)
e = A.new()
T.equal(A.cmd(e, "L", inp({stby = false})), nil, "the 28V DC STBY bus off: no engage")
A.cmd(e, "L", inp())
A.update(e, inp({stby = false}))
T.check(e.L and not e.disc, "the 28V DC STBY bus lost once engaged: still engaged")
-- the inner loop sensors: a dual failure of the IRUs' attitude or the ADCs
-- (p.316, p.382)
e = A.new()
T.equal(A.cmd(e, "L", inp({iru = 1})), nil, "two IRUs failed: no engage")
T.equal(A.cmd(e, "L", inp({adc = 1})), nil, "two ADCs failed: no engage")
A.cmd(e, "L", inp({iru = 2, adc = 2}))
T.check(e.L, "one of each failed: engaged")
A.update(e, inp({iru = 2, adc = 1}))
T.check(not e.L and e.disc, "the second ADC failed: disengaged")
-- the autotrim valid: L FCC SRM L's, R SRM R's, C either (p.224); a single
-- channel disengages without it (p.318); both SRMs lost, no A/P engages
-- (FCOM p.47)
e = A.new()
local srmR = {L = false, R = true}
T.equal(A.cmd(e, "L", inp({trim = srmR})), nil, "SRM L not valid: CMD L does not engage")
A.cmd(e, "C", inp({trim = srmR}))
T.check(e.C, "CMD C engages on SRM R's autotrim valid")
A.update(e, inp({trim = srmR}))
T.check(e.C, "C stays engaged on SRM R's")
A.update(e, inp({trim = {L = false, R = false}}))
T.check(not e.C and e.disc, "both lost: the single channel disengaged")
for _, ch in ipairs(A.CHANNELS) do A.cmd(e, ch, inp({trim = {L = false, R = false}})) end
T.equal(A.engaged(e), 0, "both SRMs lost: no channel engages")
local mt3 = land3()
approach(mt3, {trim = {L = false, R = false}})
T.equal(A.engaged(mt3), 3, "multi-channel: the autotrim valid lost, three still engaged (single only: p.318)")
-- the control wheel past 25 degrees: no single channel's arm (p.314)
e = A.new()
T.equal(A.cmd(e, "L", inp({wheel = 30})), nil, "the wheel at 30 degrees: no engage")
A.cmd(e, "L", inp({wheel = -20}))
T.check(e.L, "at 20 degrees: engaged")
-- why a CMD push does not engage (for X-Plane's log): the first condition
-- missing, nil when it engages
local rf = A.new()
T.equal(A.refused(rf, "L", inp()), nil, "all there: not refused")
T.equal(A.refused(rf, "L", inp({hyd = {3000, 3000, 0}})), "hydraulics", "system 3 out: hydraulics")
T.equal(A.refused(rf, "L", inp({fcc = noL})), "FCC power", "L's FCC unpowered: FCC power")
T.equal(A.refused(rf, "L", inp({mcp = false})), "MCP", "the MCP")
T.equal(A.refused(rf, "L", inp({iru = 1})), "IRUs", "two IRUs failed: IRUs")
T.equal(A.refused(rf, "L", inp({adc = 1})), "ADCs", "two ADCs failed: ADCs")
T.equal(A.refused(rf, "L", inp({stby = false})), "28V DC STBY", "the battery bus off: 28V DC STBY")
T.equal(A.refused(rf, "L", inp({trim = srmR})), "autotrim valid", "SRM L lost: autotrim valid")
T.equal(A.refused(rf, "L", inp({wheel = 30})), "control wheel", "the wheel at 30 degrees: control wheel")
A.cmd(rf, "C", inp())
T.equal(A.refused(rf, "L", inp()), "engaged", "C engaged: engaged")
A.bar(rf, true)
T.equal(A.refused(rf, "L", inp()), "disengage bar", "the bar down: disengage bar")
-- the multi-channel arms: only valid channels (and the 28V DC STBY bus);
-- removed with a dual sensor failure once LOC and G/S are captured (p.316),
-- not before (X-Plane's ILS signal out of range)
local ma = A.new()
A.update(ma, app_inp())
A.cmd(ma, "L", app_inp())
A.app(ma, app_inp({fcc = noC}))
T.check(not ma.arm.C and ma.arm.R, "APP: C's FCC unpowered, only R armed")
local mb = A.new()
A.update(mb, app_inp())
A.cmd(mb, "L", app_inp())
A.app(mb, app_inp({stby = false}))
T.equal(A.armed(mb), 0, "APP without the 28V DC STBY bus: no arm")
A.app(mb, app_inp())
A.app(mb, app_inp())
T.equal(A.armed(mb), 2, "(APP again: C and R armed)")
A.update(mb, app_inp({sensors = 0}))
T.equal(A.armed(mb), 2, "before the captures no sensor counted: the arms kept")
approach(mb, {ra = 1600})
approach(mb, {ra = 1600, sensors = 1})
T.check(A.armed(mb) == 0 and A.engaged(mb) == 1, "captured, a dual sensor failure: the arms removed, L still engaged")
-- a single channel in FLARE disengaged under 5 ft RA (p.318); three go on
-- into NOSE LETDOWN
local mf = land3()
approach(mf, {ra = 60, gear_alt = 45, vs = -700})
T.equal(mf.pitch, "FLARE", "(LAND 3: FLARE at 45 ft for 11.7 ft/s)")
approach(mf, {ra = 4, gear_alt = 1, vs = -120})
T.equal(A.engaged(mf), 3, "three channels in FLARE under 5 ft: engaged")
mf = land3()
approach(mf, {ra = 60, gear_alt = 45, vs = -700})
approach(mf, {ra = 30, gear_alt = 26, vs = -400, hyd = {0, 0, 3000}})
T.check(A.engaged(mf) == 1 and mf.pitch == "FLARE", "C and R lost in FLARE: L alone, FLARE kept")
T.equal(A.status(mf), A.STATUS.NO_AUTOLAND, "NO AUTOLAND")
approach(mf, {ra = 4, gear_alt = 1, vs = -120, hyd = {0, 0, 3000}})
T.check(A.engaged(mf) == 0 and mf.disc, "a single channel in FLARE under 5 ft: disengaged, AUTOPILOT DISC")

-- 5b: the autoland capability's EICAS message (ATA22 p.373-374, p.384-386;
-- FCOM p.662, p.677): one failure of a kind NO LAND 3, two NO AUTOLAND
local function cap(o)
    local c = {}
    for k, v in pairs(A.CAP_FULL) do c[k] = v end
    for k, v in pairs(o or {}) do c[k] = v end
    return c
end
T.equal(A.capability(cap()), 3, "5b: all there: 3")
T.equal(A.capability(cap({iru = 2})), 2, "an IRU failed: 2 (NO LAND 3)")
T.equal(A.capability(cap({ra = 1})), 1, "two radio altimeters failed: NO AUTOLAND")
T.equal(A.capability(cap({srm = 1})), 2, "an SRM failed: NO LAND 3")
T.equal(A.capability(cap({srm = 0})), 1, "both SRMs: NO AUTOLAND (FCOM p.47)")
T.equal(A.capability(cap({channels = 2, ils = 2})), 2, "a channel and an ILS receiver: one of each kind, NO LAND 3")
T.equal(A.capability(nil), 3, "no inputs: whole")
-- in cruise (not multi-channel): advisories
local al = A.new()
A.update(al, inp({cap = cap({iru = 2})}))
T.check(al.alert == "NO_LAND3" and al.alert_level == "advisory", "cruise, an IRU failed: NO LAND 3, an advisory")
A.update(al, inp({cap = cap({iru = 1})}))
T.check(al.alert == "NO_AUTOLAND" and al.alert_level == "advisory", "the second: NO AUTOLAND, an advisory")
A.update(al, inp({cap = cap()}))
T.equal(al.alert, nil, "repaired: none")
-- with LAND 3 shown: a caution, kept while it stays
local am = land3()
approach(am, {cap = cap()})
T.equal(am.alert, nil, "(LAND 3: none)")
approach(am, {cap = cap({ra = 2}), sensors = 2})
T.check(am.alert == "NO_LAND3" and am.alert_level == "caution", "LAND 3, a radio altimeter failed: NO LAND 3, a caution")
T.equal(A.status(am), A.STATUS.LAND2, "and LAND 2")
-- below 200 ft only NO AUTOLAND comes; the rest after the touchdown
local an = land3()
approach(an, {ra = 150, cap = cap({fcu = 2})})
T.equal(an.alert, nil, "LAND 3 at 150 ft, an FCU failed: NO LAND 3 waits")
approach(an, {ra = 150, cap = cap({fcu = 1})})
T.check(an.alert == "NO_AUTOLAND" and an.alert_level == "caution", "a second: NO AUTOLAND comes, a caution")
local ao = land3()
approach(ao, {ra = 150, cap = cap({fcu = 2})})
approach(ao, {ra = 3, ground = true, cap = cap({fcu = 2})})
T.equal(ao.alert, "NO_LAND3", "on the ground: the NO LAND 3 that waited comes")

-- 5c: the mode failures and the AUTOPILOT caution (ATA22 p.254, p.382;
-- FCOM p.660). A single channel in LOC and G/S: the second localizer
-- receiver lost (NCD: no signal) fails LOC, the airplane held in its bank
-- of then, AUTOPILOT; one lost does nothing
local mx = A.new()
A.update(mx, app_inp())
A.cmd(mx, "L", app_inp({hyd = {0, 0, 3000}}))
A.app(mx, app_inp({hyd = {0, 0, 3000}}))
local single = {hyd = {0, 0, 3000}, ils_freq = 109900}
local function sgl(o)
    local t = {}
    for k, v in pairs(single) do t[k] = v end
    for k, v in pairs(o or {}) do t[k] = v end
    return t
end
approach(mx, sgl({ra = 2000}))
T.equal(mx.roll .. mx.pitch, "LOCGS", "(single channel: LOC and G/S)")
approach(mx, sgl({ra = 2000, loc_rx = 2, gs_rx = 2}))
T.check(not mx.roll_fail and not mx.pitch_fail and not A.caution(mx), "5c: one receiver lost: no failure")
approach(mx, sgl({ra = 2000, loc_rx = 1, gs_rx = 3, bank = 4, pitch_att = 1.5}))
T.check(mx.roll_fail and not mx.pitch_fail, "the second localizer lost: LOC failed, G/S not")
T.equal(mx.fail_bank, 4, "the bank then held")
T.equal(mx.roll, "LOC", "LOC stays on the FMA (with the amber line)")
T.check(A.caution(mx), "AUTOPILOT")
approach(mx, sgl({ra = 2000, loc_rx = 3, bank = 10}))
T.check(mx.roll_fail and mx.fail_bank == 4, "the signal back: still failed until a new mode (p.254)")
A.hdg_sel(mx, app_inp({hyd = {0, 0, 3000}}))
T.check(mx.roll == "LOC" and mx.roll_fail, "HDG SEL not taken with G/S captured (table p.351): LOC still failed")
-- G/S: the glide slope's second receiver lost; the pitch of then held
approach(mx, sgl({ra = 2000, gs_rx = 1, pitch_att = -2.5}))
T.check(mx.pitch_fail and mx.fail_pitch == -2.5 and A.caution(mx), "the second glide slope lost: G/S failed, its pitch held, AUTOPILOT")
A.toga(mx, app_inp({hyd = {0, 0, 3000}, ra = 2000}))
T.check(mx.roll == "GA" and mx.pitch == "GA" and not mx.roll_fail and not mx.pitch_fail and not A.caution(mx),
    "TO/GA: G/A's modes, no longer failed, no AUTOPILOT")
-- LOC alone (a localizer approach): HDG SEL ends its failure
local ml = A.new()
A.update(ml, app_inp())
A.cmd(ml, "L", app_inp(single))
A.loc(ml, app_inp(single))
approach(ml, sgl({ra = 2000, gs_detect = false}))
T.equal(ml.roll, "LOC", "(LOC alone)")
approach(ml, sgl({ra = 2000, loc_rx = 0}))
T.check(ml.roll_fail, "LOC's signal lost: failed")
A.hdg_sel(ml, app_inp({hyd = {0, 0, 3000}}))
T.check(ml.roll == "HDG_SEL" and not ml.roll_fail and not A.caution(ml), "HDG SEL: no longer failed, no AUTOPILOT")
A.disengage(ml, true)
approach(ml, sgl({ra = 2000}))
T.check(not A.caution(ml), "the A/P off: no AUTOPILOT")
-- the ILS's frequency changed after the capture
local mq = A.new()
A.update(mq, app_inp())
A.cmd(mq, "L", app_inp(single))
A.app(mq, app_inp(single))
approach(mq, sgl({ra = 2000}))
approach(mq, sgl({ra = 2000, ils_freq = 110300}))
T.check(mq.roll_fail and mq.pitch_fail, "the ILS retuned after the capture: LOC and G/S failed (p.382)")
-- the radio altimeters' second loss in LOC and G/S below 1,500 ft
local mr = A.new()
A.update(mr, app_inp())
A.cmd(mr, "L", app_inp(single))
A.app(mr, app_inp(single))
approach(mr, sgl({ra = 1800, ra_n = 1}))
T.check(not mr.roll_fail, "two radio altimeters lost above 1,500 ft: nothing")
approach(mr, sgl({ra = 1400, ra_n = 1}))
T.check(mr.roll_fail and mr.pitch_fail, "below 1,500 ft: LOC and G/S failed")
-- the IRUs: LNAV and LOC need two at NAV, HDG SEL and HDG HOLD two headings
local mi = A.new()
A.cmd(mi, "L", inp())
T.equal(mi.roll, "HDG_HOLD", "(HDG HOLD)")
A.update(mi, inp({iru_nav = 1}))
T.check(not mi.roll_fail, "HDG HOLD with two IRUs off NAV (ATT, a heading set): not failed")
A.update(mi, inp({iru_hdg = 1, bank = -6}))
T.check(mi.roll_fail and mi.fail_bank == -6, "without two headings: failed")
-- G/A with multi-channel: a selected ADC lost
local mg = land3()
A.toga(mg, app_inp({ra = 800}))
A.update(mg, app_inp({ra = 850, adc_sel = false}))
T.check(mg.pitch == "GA" and mg.pitch_fail and A.caution(mg), "multi-channel G/A, a selected ADC lost: G/A's pitch failed, AUTOPILOT")
-- a single channel in FLARE: AUTOPILOT (p.382)
local mf2 = land3()
approach(mf2, {ra = 60, gear_alt = 45, vs = -700})
approach(mf2, {ra = 30, gear_alt = 26, vs = -400, hyd = {0, 0, 3000}})
T.check(A.engaged(mf2) == 1 and A.caution(mf2), "a single channel in FLARE: AUTOPILOT")
-- multi-channel: the ILS's signal lost (NCD) is a mode failure, not the
-- dual failure that disengages (step 5a: failures only)
local mn2 = land3()
approach(mn2, {cap = cap(), sensors = 1, loc_rx = 1, gs_rx = 1})
T.check(A.engaged(mn2) == 3 and mn2.roll_fail and mn2.pitch_fail, "LAND 3, the signal lost: three still engaged, LOC and G/S failed")
approach(mn2, {cap = cap({ils = 1}), sensors = 1, loc_rx = 1, gs_rx = 1})
T.check(A.engaged(mn2) == 0 and mn2.disc, "two receivers failed: disengaged (p.320, p.322)")

-- 5d: ILS TUNE INHIBIT and RA TEST INHIBIT (ATA22 p.212; FCOM p.1305):
-- the A/P engaged with LOC or G/S captured; the F/Ds only with them
-- captured under 500 ft RA; ILS TUNE also on the ground with a localizer
-- alive, the heading within 45 degrees of its course, over 40 kt and LOC or
-- APP not selected
local ia = A.new()
A.update(ia, app_inp())
A.cmd(ia, "L", app_inp(single))
A.app(ia, app_inp(single))
T.check(not A.ils_inhibit(ia, app_inp()) and not A.ra_test_inhibit(ia, app_inp()), "5d: APP armed, nothing captured: no inhibit")
approach(ia, sgl({ra = 2000}))
T.check(A.ils_inhibit(ia, app_inp({ra = 2000})) and A.ra_test_inhibit(ia, app_inp({ra = 2000})), "the A/P with LOC and G/S: both inhibits")
local fi = A.new()
A.update(fi, app_inp())
A.app(fi, app_inp())
approach(fi, {ra = 2000})
T.check(fi.roll == "LOC" and A.engaged(fi) == 0, "(the F/D only in LOC and G/S)")
T.check(not A.ils_inhibit(fi, app_inp({ra = 600})), "the F/D only at 600 ft: no inhibit")
T.check(A.ils_inhibit(fi, app_inp({ra = 450})) and A.ra_test_inhibit(fi, app_inp({ra = 450})), "under 500 ft: both")
local gi = A.new()
local function gnd(o)
    local t = {ground = true, loc_alive = true, loc_hdg_err = 10, gs_kt = 60}
    for k, v in pairs(o or {}) do t[k] = v end
    return inp(t)
end
T.check(A.ils_inhibit(gi, gnd()), "the takeoff roll: a localizer alive, 10 degrees, 60 kt: ILS TUNE INHIBIT")
T.check(not A.ra_test_inhibit(gi, gnd()), "not RA TEST INHIBIT")
T.check(not A.ils_inhibit(gi, gnd({gs_kt = 30})), "30 kt: none")
T.check(not A.ils_inhibit(gi, gnd({loc_hdg_err = 50})), "50 degrees off the course: none")
T.check(not A.ils_inhibit(gi, gnd({loc_alive = false})), "no localizer: none")
A.loc(gi, gnd())
T.check(gi.loc_arm and not A.ils_inhibit(gi, gnd()), "LOC selected: none (ATA22)")

-- ELEC-18: the bus isolation request to BCU 1 from the approach's
-- multi-channel arm (ATA22 p.192), until every A/P is disengaged, TO/GA
-- above 100 ft RA, or APP disarmed (FCOM p.802); BUS ISOLATED needed for
-- LAND 3 (p.192); not isolated 4 s after the request: NO LAND 3 (p.384)
local bi = A.new()
A.update(bi, app_inp())
A.cmd(bi, "L", app_inp())
A.update(bi, app_inp())
T.check(not A.bus_isolate_request(bi), "ELEC-18: CMD L in cruise: no bus isolation request")
A.loc(bi, app_inp())
A.update(bi, app_inp())
T.check(bi.loc_arm and not A.bus_isolate_request(bi), "LOC armed alone: none")
A.app(bi, app_inp())
A.update(bi, app_inp({bus_isolated = false, cap = cap()}))
T.check(bi.gs_arm and A.armed(bi) == 2 and A.bus_isolate_request(bi), "APP, C and R armed: the request")
for _ = 1, 34 do A.update(bi, app_inp({bus_isolated = false, cap = cap()})) end
T.equal(bi.alert, nil, "3.5 s without BUS ISOLATED: nothing yet")
for _ = 1, 10 do A.update(bi, app_inp({bus_isolated = false, cap = cap()})) end
T.check(bi.alert == "NO_LAND3" and bi.alert_level == "advisory", "4.5 s: NO LAND 3, an advisory (the buses do not isolate)")
A.update(bi, app_inp({bus_isolated = true, cap = cap()}))
A.update(bi, app_inp({bus_isolated = true, cap = cap()}))
T.equal(bi.alert, nil, "isolated: gone")
A.app(bi, app_inp())
A.update(bi, app_inp({bus_isolated = true}))
T.check(not bi.gs_arm and not A.bus_isolate_request(bi), "APP pushed again (disarmed): the request ends")
-- a single channel's APP (the others invalid): none (estimate)
local hy3 = {hyd = {0, 0, 3000}}
local bs = A.new()
A.update(bs, app_inp(hy3))
A.cmd(bs, "L", app_inp(hy3))
A.app(bs, app_inp(hy3))
A.update(bs, app_inp(hy3))
T.check(bs.gs_arm and A.armed(bs) == 0 and not A.bus_isolate_request(bs), "a single channel's APP: no request")
-- LAND 3 needs BUS ISOLATED: without it LAND 2
local bl = A.new()
A.update(bl, app_inp())
A.cmd(bl, "L", app_inp())
A.app(bl, app_inp())
for _ = 1, 55 do approach(bl, {bus_isolated = false}) end
T.equal(A.engaged(bl) .. A.status(bl), "3" .. A.STATUS.LAND2, "three engaged, the buses not isolated: LAND 2")
approach(bl, {bus_isolated = true})
T.equal(A.status(bl), A.STATUS.LAND3, "isolated: LAND 3")
T.check(A.bus_isolate_request(bl), "multi-channel engaged: still requested")
approach(bl, {bus_isolated = false, ra = 150})
T.equal(A.status(bl), A.STATUS.LAND3, "150 ft, BUS ISOLATED gone (BCU 1 holds the BTBs): LAND 3 kept")
-- two channels lost: still requested until every A/P is disengaged
approach(bl, {bus_isolated = true, ra = 800, hyd = {0, 0, 3000}})
T.check(A.engaged(bl) == 1 and A.bus_isolate_request(bl), "down to one channel: still requested")
A.disengage(bl)
approach(bl, {bus_isolated = true, ra = 800})
T.check(A.engaged(bl) == 0 and not A.bus_isolate_request(bl), "every A/P disengaged: the request ends")
-- G/A: kept to 100 ft RA
local bg = land3()
T.check(A.bus_isolate_request(bg), "(LAND 3: requested)")
A.toga(bg, app_inp({ra = 80}))
A.update(bg, app_inp({ra = 80}))
T.check(bg.pitch == "GA" and A.bus_isolate_request(bg), "G/A at 80 ft: still requested")
A.update(bg, app_inp({ra = 120}))
T.check(bg.pitch == "GA" and not A.bus_isolate_request(bg), "above 100 ft: the request ends")
T.done()
