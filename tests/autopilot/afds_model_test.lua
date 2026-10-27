-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_model_test.lua
-- The FCCs' mode logic, steps 1a-1d (6-3: docs/overhaul/notes/ATA-22.md
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
-- 1c: the pitch modes V/S (synced: 000 after ALT and TO/GA descending),
-- ALT HOLD, the capture, FLCH (its speed), VNAV (arm, second push, the old
-- VNAV's engage and end), the transitions, the SPD switch, the FMA's pitch.
-- 1d: the approach modes LOC, G/S and APP (arms, second pushes, the mutual
-- disarms with LNAV and VNAV, captures within 120 and 80 degrees, 405 and
-- 570, deselects, TO/GA, the A/P's engage with LOC and G/S engaged).
local T = dofile("tests/lib/check.lua")("afds_model")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua")

local HYD = {3000, 3000, 3000}
local function inp(o)
    o = o or {}
    return {fd = {L = o.fdL or false, R = o.fdR or false}, hyd = o.hyd or HYD, bank = o.bank or 0,
        engine = o.engine or 0, ground = o.ground or false, toga = o.toga or false, ra = o.ra or 9000,
        hdg = o.hdg or 100, lnav_valid = o.lnav_valid or false, old_roll = o.old_roll,
        gs_active = o.gs_active or false, old_armed_roll = o.old_armed_roll, dt = o.dt or 0.1, ga = o.ga or false,
        vs = o.vs or 0, alt = o.alt or 10000, old_pitch = o.old_pitch, window_open = o.window_open,
        ias = o.ias or 250, mcp_ias = o.mcp_ias or 250, fmc_speed = o.fmc_speed, capture = o.capture or false,
        capture_alt = o.capture_alt, vnav_engaged = o.vnav_engaged or false, vnav_fma = o.vnav_fma,
        old_law = o.old_law, old_armed_pitch = o.old_armed_pitch, old_hold_alt = o.old_hold_alt,
        loc_detect = o.loc_detect, gs_detect = o.gs_detect, course_err = o.course_err}
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
A.update(pt, inp({fdL = true, old_pitch = "TOGA"}))
T.equal(select(1, A.pitch_fma(pt, inp({old_pitch = "TOGA"}))), 1, "the old TO/GA's pitch (1)")
T.equal(A.vs(pt, inp({vs = -500, old_pitch = "TOGA"})), 0, "V/S from TO/GA descending: 000")
T.equal(select(1, A.pitch_fma(pt, inp({old_pitch = "TOGA"}))), 7, "V/S over TO/GA's pitch")
local pt2 = A.new()
A.update(pt2, inp({fdL = true}))
A.update(pt2, inp({fdL = true, old_pitch = "TOGA"}))
T.equal(A.vs(pt2, inp({vs = 1500, old_pitch = "TOGA"})), 1500, "V/S from TO/GA climbing: synced")
-- the transitions (table p.335): G/A below 400 ft, the old G/S once LOC is
-- active, FLARE
local pg = A.new()
A.update(pg, inp({fdL = true}))
T.equal(A.vs(pg, inp({old_pitch = "TOGA", old_roll = "TOGA", ga = true, ra = 300})), nil, "V/S in G/A below 400 ft: no")
T.equal(A.alt_hold(pg, inp({old_pitch = "TOGA", ga = true, ra = 300})), false, "ALT HOLD in G/A below 400 ft: no")
T.equal(A.flch(pg, inp({old_pitch = "TOGA", ga = true, ra = 300})), false, "FLCH in G/A below 400 ft: no")
pg.pitch, pg.roll = "GS", "LOC"
T.equal(A.vs(pg, inp()), nil, "V/S from G/S with LOC active: no")
pg.roll = "HDG_HOLD"
T.check(A.vs(pg, inp()) ~= nil, "V/S from G/S before LOC: yes")
T.equal(A.alt_hold(pg, inp({old_pitch = "FLARE"})), false, "nothing from FLARE")
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
A.update(pf2, inp({fdL = true, old_pitch = "TOGA"}))
local _, sp4 = A.flch(pf2, inp({old_pitch = "TOGA", window_open = true, ias = 175, mcp_ias = 160}))
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
T.equal(A.spd_works(pt2, inp({old_pitch = "TOGA"})), true, "in V/S after TO/GA")
local pt3 = A.new()
A.update(pt3, inp({fdL = true}))
A.update(pt3, inp({fdL = true, old_pitch = "TOGA"}))
T.equal(A.spd_works(pt3, inp({old_pitch = "TOGA"})), false, "not in TO/GA")
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
-- the old TO/GA's pitch replaces the pitch mode (VNAV too: FCOM p.645), not
-- VNAV's arm
local pt4 = A.new()
A.update(pt4, inp({fdL = true}))
A.alt_hold(pt4, inp({alt = 3000}))
A.vnav(pt4, inp())
A.update(pt4, inp({fdL = true, old_pitch = "TOGA"}))
T.check(not pt4.pitch and not pt4.hold_alt and pt4.vnav_arm, "the old TO/GA: no pitch mode, VNAV still armed")
T.equal(select(1, A.pitch_fma(pt4, inp({old_pitch = "TOGA"}))), 1, "the FMA's TO/GA")
local pt5 = A.new()
A.update(pt5, inp({fdL = true}))
A.vnav(pt5, inp())
A.update(pt5, inp({fdL = true, vnav_engaged = true}))
A.update(pt5, inp({fdL = true, vnav_engaged = true, old_pitch = "TOGA"}))
T.check(not pt5.pitch, "TO/GA ends VNAV")
-- VNAV from G/A at any height (table p.335: V/S, ALT HOLD and FLCH only
-- above 400 ft)
local pv6 = A.new()
A.update(pv6, inp({fdL = true}))
A.vnav(pv6, inp({old_pitch = "TOGA", old_roll = "TOGA", ga = true, ra = 300}))
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
A.update(a3, inp({fdL = true, old_roll = "TOGA", old_pitch = "TOGA"}))
A.loc(a3, inp({old_roll = "TOGA", old_pitch = "TOGA"}))
A.app(a3, inp({old_roll = "TOGA", old_pitch = "TOGA"}))
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
-- G/S: the 405 (PW) captures only with LOC engaged, the 570 (GE) either
-- first, within 80 degrees
A.update(b, inp({fdL = true, gs_detect = true, course_err = 20}))
T.check(b.gs_arm and b.pitch == "ALT", "PW: no G/S before LOC")
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
A.update(c2, inp({fdL = true, old_roll = "TOGA", old_pitch = "TOGA"}))
T.check(not c2.roll and not c2.pitch and not c2.loc_arm and not c2.gs_arm, "TO/GA ends LOC and G/S")
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
T.done()
