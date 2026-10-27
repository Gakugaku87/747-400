-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_model_test.lua
-- The FCCs' mode logic, steps 1a and 1b (6-3: docs/overhaul/notes/ATA-22.md
-- §10): plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua.
-- 1a: the A/P's engage (CMD: the bar, the other channels, the servos'
-- hydraulics; on the ground too) and disengage (the bar, the control wheel
-- switches, automatically, the hydraulics), AUTOPILOT DISC and its reset,
-- the default modes on the A/P's engage and the first F/D ON (V/S with
-- HDG HOLD or ATT by the bank, PW and GE; TO/GA on the ground), everything
-- off with neither the A/P nor a F/D, the old approach's channels.
-- 1b: the roll modes HDG SEL, HDG HOLD (its heading after 2 s under 3
-- degrees), ATT, LNAV (arm, second push, engage, kept armed by HDG SEL),
-- the transitions from the old LOC and G/A, the FMA's roll.
local T = dofile("tests/lib/check.lua")("afds_model")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua")

local HYD = {3000, 3000, 3000}
local function inp(o)
    o = o or {}
    return {fd = {L = o.fdL or false, R = o.fdR or false}, hyd = o.hyd or HYD, bank = o.bank or 0,
        engine = o.engine or 0, ground = o.ground or false, toga = o.toga or false, ra = o.ra or 9000,
        hdg = o.hdg or 100, lnav_valid = o.lnav_valid or false, old_roll = o.old_roll,
        gs_active = o.gs_active or false, old_armed_roll = o.old_armed_roll, dt = o.dt or 0.1, ga = o.ga or false}
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
T.check(fc and fc.toga and not fc.pitch and not f3.roll, "the first F/D ON on the ground: TO/GA (ATA22 p.337)")
local f4 = A.new()
A.cmd(f4, "L", inp())
T.equal(A.update(f4, inp({fdL = true})), nil, "a F/D ON with the A/P engaged: the A/P's modes")

-- the A/P engaged with a F/D ON: its modes, but from the F/D's takeoff on
-- the ground HDG HOLD and V/S (ATA22 p.266)
local g = A.new()
A.update(g, inp({fdL = true, ground = true}))
local ga = A.cmd(g, "L", inp({fdL = true, ground = true, toga = true}))
T.check(ga and ga.pitch == "VS" and ga.toga_off and g.roll == "HDG_HOLD", "the F/D's T/O on the ground: HDG HOLD and V/S")
local g2 = A.new()
A.update(g2, inp({fdL = true}))
T.equal(A.cmd(g2, "L", inp({fdL = true, toga = true})), nil, "TO/GA in the air: the A/P in it")

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

-- the old approach's channels (until step 4)
local m = A.new()
A.multi(m, inp())
T.equal(A.engaged(m), 0, "the approach's channels need one engaged")
A.cmd(m, "C", inp())
A.multi(m, inp({hyd = {3000, 0, 3000}}))
T.check(m.L and m.C and not m.R, "the approach's channels with hydraulic pressure: L and C, not R (system 2)")

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

-- the old LOC (until step 1d): LNAV not armed while it is engaged, its
-- capture ends LNAV; HDG SEL from it only before G/S is active (table
-- p.351)
local c = A.new()
A.update(c, inp({fdL = true}))
A.lnav(c, inp({fdL = true, old_roll = "LOC"}))
T.check(not c.lnav_arm, "LNAV not armed with LOC engaged")
A.lnav(c, inp({fdL = true}))
A.loc_captured(c)
T.check(not c.lnav_arm and not c.roll, "the LOC's capture: LNAV's arm gone, the roll the old code's")
T.equal(select(1, A.roll_fma(c, inp({old_roll = "LOC"}))), 3, "the FMA's LOC (3)")
T.equal(A.hdg_sel(c, inp({old_roll = "LOC", gs_active = true})), false, "HDG SEL with LOC and G/S active: no")
T.equal(A.hdg_hold(c, inp({old_roll = "LOC", gs_active = true})), false, "HDG HOLD with LOC and G/S active: no")
T.equal(A.hdg_sel(c, inp({old_roll = "LOC"})), true, "HDG SEL with LOC before G/S: yes")
-- the old TO/GA (until step 1e): G/A below 400 ft keeps its roll; above,
-- a roll mode replaces its roll in the FMA
local t = A.new()
A.update(t, inp({fdL = true}))
A.update(t, inp({fdL = true, old_roll = "TOGA"}))
T.equal(select(1, A.roll_fma(t, inp({old_roll = "TOGA"}))), 1, "the FMA's TO/GA (1) over the F/D's HDG HOLD")
T.equal(A.hdg_sel(t, inp({old_roll = "TOGA", ga = true, ra = 300})), false, "HDG SEL in G/A below 400 ft: no")
A.lnav(t, inp({old_roll = "TOGA", ga = true, ra = 300}))
T.check(not t.lnav_arm, "LNAV in G/A below 400 ft: no")
local tk = A.new()
A.update(tk, inp({fdL = true}))
T.equal(A.hdg_sel(tk, inp({old_roll = "TOGA", ra = 300})), true, "HDG SEL in T/O below 400 ft: yes (table p.351)")
T.equal(A.hdg_sel(t, inp({old_roll = "TOGA", ga = true, ra = 600})), true, "HDG SEL in G/A above 400 ft: yes")
T.equal(select(1, A.roll_fma(t, inp({old_roll = "TOGA"}))), 6, "the FMA's HDG SEL over TO/GA's roll")
A.update(t, inp({fdL = true}))
A.update(t, inp({fdL = true, old_roll = "TOGA"}))
T.equal(select(1, A.roll_fma(t, inp({old_roll = "TOGA"}))), 1, "TO/GA again: its roll again")
-- the HDG REF switch in HDG SEL: HDG HOLD by default (ATA22 p.352)
T.equal(A.hdg_hold(c, inp({old_roll = "LOC", gs_active = true}), true), true, "HDG HOLD by default: no conditions")

T.done()
