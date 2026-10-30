-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_roll_model_test.lua
-- The FCCs' roll laws, steps 2a and 2b (6-3: docs/overhaul/notes/ATA-22.md
-- §16, §17): plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_roll_model.lua.
-- The bank of a heading error, the bank limit (the selector, AUTO by TAS,
-- flaps and V2), HDG SEL's turn (the smaller error when selected before the
-- push, the knob's way after it, past 180 degrees too), HDG HOLD (wings
-- level, then the heading; kept through a change of the reference), ATT,
-- LNAV (only the V2 + 10 limit), T/O and G/A's track, no command without a
-- law (no mode, nothing engaged or shown), NCD in NORM's polar
-- areas, the rate. 2b: LOC's distance from the radio altitude, the
-- capture (closing at the turn's distance, the small deviation, no signal,
-- the polar areas), the law (onto the course, LOC TRACK and its limit, the
-- inertial path without a signal, wings level below 5 ft and on the ground,
-- NCD).
local T = dofile("tests/lib/check.lua")("afds_roll_model")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_roll_model.lua")

local DT = 0.1
local function inp(o)
    local i = R.inputs()
    i.active, i.tas, i.ias = true, 250, 230
    for k, v in pairs(o or {}) do i[k] = v end
    return i
end
local function run(s, i, seconds)
    local c
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do c = R.update(s, i, DT) end
    return c
end

-- the bank of an error: a turn of err / 8 degrees a second at the TAS
local tas = 250 * 1852 / 3600
T.near(R.bank_for(10, inp(), 25), math.deg(math.atan(tas * math.rad(10 / 8) / 9.80665)), 1e-6,
    "10 degrees at 250 kt: the bank of a 1.25 degree a second turn")
T.near(R.bank_for(10, inp(), 25), 15.97, 0.05, "about 16 degrees")
T.equal(R.bank_for(90, inp(), 25), 25, "a large error: the limit")
T.equal(R.bank_for(-90, inp(), 15), -15, "to the left too")

-- the bank limit (FCOM p.647; FCTM p.118)
T.equal(R.auto_limit(inp({tas = 250})), 25, "AUTO flaps up at 250 kt TAS: 25")
T.equal(R.auto_limit(inp({tas = 480})), 15, "at 480 kt: 15")
T.near(R.auto_limit(inp({tas = 390})), 20, 1e-9, "between: by TAS")
T.equal(R.auto_limit(inp({flaps_up = false, v2 = 160, ias = 165})), 15, "flaps out below V2 + 10: 15")
T.equal(R.auto_limit(inp({flaps_up = false, v2 = 160, ias = 175})), 25, "flaps out above V2 + 10: 25")
T.equal(R.auto_limit(inp({flaps_up = false, v2 = 999, ias = 140})), 25, "flaps out without a V2 (the approach): 25")
T.equal(R.limit("HDG_SEL", inp({selector = 3})), 15, "HDG SEL with the selector at 15")
T.equal(R.limit("HDG_SEL", inp({selector = 0, tas = 480})), 15, "HDG SEL in AUTO: AUTO")
T.equal(R.limit("HDG_HOLD", inp({selector = 1})), 25, "the selector is for HDG SEL only")

-- no law here
local s = R.new()
T.equal(R.update(s, inp({mode = nil}), DT), nil, "no mode")
T.equal(R.update(s, inp({mode = "HDG_SEL", active = false}), DT), nil, "nothing engaged or shown")

-- HDG SEL selected before the push: toward the smaller error, from the
-- bank there at 3 degrees a second
s = R.new()
local c = R.update(s, inp({mode = "HDG_SEL", hdg = 100, sel = 70, bank = 0}), DT)
T.near(c, -0.3, 1e-9, "selected 030 left: the command starts left from wings level")
c = run(s, inp({mode = "HDG_SEL", hdg = 100, sel = 70, bank = 0}), 0.9)
T.near(c, -3, 1e-9, "3 degrees a second")
c = run(s, inp({mode = "HDG_SEL", hdg = 100, sel = 70, bank = -20}), 10)
T.equal(c, -25, "then the limit")
s = R.new()
R.update(s, inp({mode = "HDG_SEL", hdg = 100, sel = 300, bank = 0}), DT)
T.near(s.err, -160, 1e-9, "200 right selected before: 160 left, the smaller")

-- turned after the push: the knob's way, past 180 too
s = R.new()
local i = inp({mode = "HDG_SEL", hdg = 100, sel = 100})
R.update(s, i, DT)
for k = 1, 20 do i.sel = (100 + 10 * k) % 360; R.update(s, i, DT) end
T.near(s.err, 200, 1e-9, "the knob 200 right after the push: 200 right, not 160 left")
T.check(s.cmd > 0, "turning right")
i.hdg = 250
R.update(s, i, DT)
T.near(s.err, 50, 1e-9, "the airplane's turn takes it down")
i.hdg = 302
R.update(s, i, DT)
T.near(s.err, -2, 1e-9, "past it: back the short way")
s = R.new()
i = inp({mode = "HDG_SEL", hdg = 100, sel = 40})
R.update(s, i, DT)
i.hdg, i.sel = 95, 45
R.update(s, i, DT)
T.near(s.err, -50, 1e-9, "5 right on the knob in a left turn: still 50 left")
s = R.new()
i = inp({mode = "HDG_SEL", hdg = 0, sel = 0})
R.update(s, i, DT)
for k = 1, 40 do i.sel = (10 * k) % 360; R.update(s, i, DT) end
T.check(math.abs(s.err) < 360 and (s.err - 40) % 360 == 0, "more than a round: within one round, the same angle")
c = run(s, inp({mode = "HDG_SEL", hdg = 0, sel = 90, selector = 1, bank = 0}), 5)
T.equal(c, 5, "the selector at 5: 5 degrees")

-- HDG HOLD: wings level, then the heading the AFDS model has
s = R.new()
c = run(s, inp({mode = "HDG_HOLD", hdg = 100, bank = 20}), 1)
T.near(c, 17, 1e-9, "rolling out at 3 degrees a second")
c = run(s, inp({mode = "HDG_HOLD", hdg = 100, bank = 0}), 10)
T.equal(c, 0, "wings level")
R.update(s, inp({mode = "HDG_HOLD", hdg = 104, held = true}), DT)
T.equal(s.hold, 104, "the heading when the model has it")
c = run(s, inp({mode = "HDG_HOLD", hdg = 106, held = true}), 1)
T.check(c < 0, "2 right of it: back left")
R.update(s, inp({mode = "HDG_HOLD", hdg = 113, held = true, ref_true = true}), DT)
T.near(s.hold, 111, 1e-9, "the reference true (7 more): the same heading")
c = run(s, inp({mode = "HDG_HOLD", hdg = 113, held = true, ref_true = true}), 1)
T.check(c < 0, "still 2 right of it")

-- ATT, LNAV
s = R.new()
c = run(s, inp({mode = "ATT", att_bank = 22, bank = 22}), 1)
T.equal(c, 22, "ATT: its bank")
s = R.new()
c = run(s, inp({mode = "LNAV", lnav_bank = 30, bank = 30, tas = 480}), 1)
T.equal(c, 30, "LNAV: the FMC's (30 in a hold), not AUTO's TAS limit")
s = R.new()
c = run(s, inp({mode = "LNAV", lnav_bank = 25, bank = 15, flaps_up = false, v2 = 160, ias = 165}), 1)
T.equal(c, 15, "LNAV with AUTO below V2 + 10: 15 (FCTM p.118)")
s = R.new()
c = run(s, inp({mode = "LNAV", lnav_bank = 25, bank = 25, flaps_up = false, v2 = 160, ias = 165, selector = 5}), 1)
T.equal(c, 25, "the selector at 25: no AFDS limit")

-- T/O: wings level on the ground, the lift-off's track
s = R.new()
c = run(s, inp({mode = "TO", ground = true, trk = 337, bank = 0}), 1)
T.equal(c, 0, "T/O on the ground: wings level")
R.update(s, inp({mode = "TO", trk = 337}), DT)
T.equal(s.trk_ref, 337, "the track at the lift-off")
c = run(s, inp({mode = "TO", trk = 341, flaps_up = false, v2 = 160, ias = 165}), 3)
T.check(c < 0 and c >= -15, "4 right of it: back left, within 15 below V2 + 10")
-- G/A: the track at its engagement
s = R.new()
R.update(s, inp({mode = "GA", trk = 90}), DT)
T.equal(s.trk_ref, 90, "G/A: the track then")
c = run(s, inp({mode = "GA", trk = 85}), 2)
T.check(c > 0, "5 left of it: right")
c = run(s, inp({mode = "GA", trk = 85, ground = true, bank = 0}), 10)
T.equal(c, 0, "G/A on the ground: wings level")

-- NORM's polar areas: no reference, NCD, the bank held
s = R.new()
c = run(s, inp({mode = "HDG_SEL", hdg = 100, sel = 140, bank = 10, hdg_valid = false}), 2)
T.check(not s.valid and c == 10, "HDG SEL without a reference: NCD, the bank held")
s = R.new()
run(s, inp({mode = "HDG_HOLD", hdg = 100, bank = 0, held = true, hdg_valid = false}), 1)
T.check(not s.valid and s.hold == nil, "HDG HOLD without a reference: no heading")
c = run(s, inp({mode = "LNAV", lnav_bank = 10, bank = 0, hdg_valid = false}), 1)
T.check(s.valid and math.abs(c - 3) < 1e-9, "LNAV has its reference (the FMC): on from the held command")

-- LOC (step 2b): the distance from the radio altitude (a 3 degree glide
-- slope, a 10,000 ft runway, the radio altimeter's 2,500 ft), the
-- deviation (X-Plane's 1.41 degrees a dot, plus to the beam's right)
T.near(R.loc_distance(0), 3048, 1e-6, "on the runway: 10,000 ft to the localizer")
T.near(R.loc_distance(1000), (1000 / math.tan(math.rad(3)) + 10000) * 0.3048, 1e-6, "1,000 ft: on the glide slope")
T.equal(R.loc_distance(5000), R.loc_distance(2500), "above the radio altimeter's range: 2,500 ft")
T.near(R.loc_dev(inp({loc_dots = 1})), -1.41, 1e-9, "1 dot, the beam right: 1.41 degrees left of it")
-- the capture: closing at 30 degrees from the left at 180 kt, 2,500 ft:
-- the turn at 25 degrees needs 251 m and the 4 s lead 185 m
local function loc_inp(o)
    local i = inp({loc_valid = true, course = 337, trk_mag = 7, gs = 180, ra = 2500, loc_dots = 1.5})
    for k, v in pairs(o or {}) do i[k] = v end
    return i
end
T.check(not R.loc_capture(loc_inp()), "1.5 dots left (649 m) closing at 30: not yet")
T.check(R.loc_capture(loc_inp({loc_dots = 1.0})), "1 dot (433 m): captured (436 m)")
T.check(not R.loc_capture(loc_inp({loc_dots = 1.0, trk_mag = 307})), "going away at 30: not")
T.check(R.loc_capture(loc_inp({loc_dots = 0.4, trk_mag = 307})), "within 0.7 degrees: captured whatever the closure")
T.check(R.loc_capture(loc_inp({loc_dots = 2.4, trk_mag = 67, gs = 220})), "closing at 90 at 220 kt from 2.4 dots: the turn needs it")
T.check(not R.loc_capture(loc_inp({loc_dots = 1.0, loc_valid = false})), "no localizer: no capture")
T.check(not R.loc_capture(loc_inp({loc_dots = 0.2, hdg_valid = false})), "NORM's polar areas: no capture (FCOM p.1046)")
-- the law: from the capture, turning onto the course
s = R.new()
i = loc_inp({mode = "LOC", loc_dots = 1.0, tas = 180, bank = 0})
c = run(s, i, 3)
T.check(c < -8, "left of the beam closing at 30: rolling left onto the course")
T.check(not s.loc_track, "not yet LOC TRACK")
-- on the centreline, parallel: LOC TRACK, its limit 15
i.loc_dots, i.trk_mag = 0.05, 336
c = run(s, i, 20)
T.check(s.loc_track, "LOC TRACK: on the centreline within 5 degrees")
i.loc_dots, i.trk_mag = -2.5, 337
c = run(s, i, 30)
T.check(c >= -15 and c < -10, "2.5 dots right in tracking: left, within the 15 of tracking")
-- the inertial path: no signal, the deviation's distance carried on the
-- cross runway velocity (the path held)
s = R.new()
i = loc_inp({mode = "LOC", loc_dots = 0, trk_mag = 337, tas = 180, bank = 0})
run(s, i, 1)
i.loc_valid, i.loc_dots, i.trk_mag = false, 2.5, 339
run(s, i, 10)
local drift = 180 * 1852 / 3600 * math.sin(math.rad(2)) * 10
T.near(s.loc_y, drift, 2, "no signal: the distance from the track (2 degrees right, 10 s), not the deviation")
-- wings level from 5 ft (ROLL DOWN: ATA22 p.348) and on the ground
s = R.new()
c = run(s, loc_inp({mode = "LOC", loc_dots = -1, trk_mag = 337, ra = 4, bank = 2}), 1)
T.equal(c, 0, "below 5 ft: wings level")
c = run(s, loc_inp({mode = "LOC", loc_dots = -1, trk_mag = 337, ground = true}), 1)
T.equal(c, 0, "on the ground: wings level")
-- 4d: LOC TRACK's track error integrated too (the roll attitude
-- integrator takes LOC's signal: figure p.359), not in the capture
s = R.new()
i = loc_inp({mode = "LOC", loc_dots = 0, trk_mag = 336, course = 337, tas = 152, gs = 150, ra = 1000, bank = 0})
local c2 = run(s, i, 2)
c = run(s, i, 10)
T.check(s.loc_track and c > c2 + 0.5, ("LOC TRACK, the track a degree off for 10 s: the bank grows (%.2f, then %.2f)"):format(c2, c))
s = R.new()
run(s, loc_inp({mode = "LOC", loc_dots = 1.0, tas = 180, bank = 0}), 3)
T.check(not s.loc_track and s.loc_int == 0, "the capture: no integral")
-- NORM's polar areas: NCD
s = R.new()
c = run(s, loc_inp({mode = "LOC", hdg_valid = false, bank = 4}), 1)
T.check(not s.valid and c == 4, "LOC in NORM's polar areas: NCD, the bank held")

-- 4c: ROLLOUT (ATA22 p.348, p.362): wings level; the rudder to the
-- centreline on LOC's distance and the cross runway velocity; none in the
-- other modes
s = R.new()
i = loc_inp({mode = "ROLLOUT", loc_dots = 0, trk_mag = 337, gs = 140, ra = 3, ground = true, bank = 1})
c = run(s, i, 1)
T.equal(c, 0, "ROLLOUT: wings level")
T.near(s.rudder, 0, 1e-9, "on the centreline along the course: no rudder")
s = R.new()
i.loc_dots = 0.05
c = run(s, i, 0.2)
T.check(s.rudder > 0, "left of the centreline (the beam right): right rudder")
s = R.new()
i.loc_dots, i.trk_mag = 0, 339
run(s, i, 0.2)
T.check(s.rudder < 0, "on it heading 2 degrees right of the course: left rudder")
i.trk_mag = 357
run(s, i, 0.2)
T.equal(s.rudder, -R.RUDDER_MAX, "a large error: within RUDDER_MAX")
run(s, loc_inp({mode = "LOC", loc_dots = 0, trk_mag = 337}), DT)
T.equal(s.rudder, nil, "LOC: no rudder")
-- closed on a ground run (the track's rate a degree a second for each
-- tenth of rudder, 1 s behind it; 140 kt slowing 5 kt a second, the
-- localizer 8,600 ft ahead): 20 ft left of the centreline, back within 3
-- ft in 20 s without crossing it by more than 3 ft
s = R.new()
local y, trk, gs, over, yr = -20 * 0.3048, 337, 140, 0, 0
local d = 8600 * 0.3048
for n = 1, 200 do
    local dev = math.deg(math.atan(y / d))
    local g = loc_inp({mode = "ROLLOUT", loc_dots = -dev / R.LOC_DOT_DEG, trk_mag = trk, gs = gs, ra = 2, ground = true})
    R.update(s, g, DT)
    yr = yr + (10 * s.rudder - yr) * DT
    trk = trk + yr * DT
    y = y + gs * 1852 / 3600 * math.sin(math.rad(trk - 337)) * DT
    d = d - gs * 1852 / 3600 * DT
    gs = math.max(gs - 5 * DT, 20)
    over = math.max(over, y / 0.3048)
end
T.check(math.abs(y / 0.3048) < 3, ("20 ft left: back within 3 ft in 20 s (%.1f)"):format(y / 0.3048))
T.check(over < 3, ("not past the centreline by more than 3 ft (%.1f)"):format(over))

-- 4d: runway align (ATA22 p.296, p.360-362; FCOM p.670). The decrab's
-- table: the crab at 500 ft taken down by what is past 5 (at most 5) below
-- 500 ft, by 5 (all under 5) below 200 ft
T.equal(R.decrab(12, 0), 0, "above 500 ft: none")
T.equal(R.decrab(12, 1), 5, "crab 12 below 500 ft: 5 (FCOM p.670)")
T.equal(R.decrab(12, 2), 5, "crab 12 below 200 ft: still 5, the most")
T.equal(R.decrab(8, 1), 3, "crab 8 below 500 ft: down to 5")
T.equal(R.decrab(8, 2), 5, "crab 8 below 200 ft: the rest of the 5")
T.equal(R.decrab(3, 1), 0, "crab 3 below 500 ft: none yet")
T.equal(R.decrab(3, 2), 3, "crab 3 below 200 ft: all of it")
local function al_inp(o)
    local i = loc_inp({mode = "LOC", rwy_align = true, loc_dots = 0, trk_mag = 337, course = 337, hdg_mag = 337,
        gs = 150, tas = 152, ra = 1000, bank = 0})
    for k, v in pairs(o) do i[k] = v end
    return i
end
-- the wings level (an engine out): the bank LOC's law asks for, and its
-- integral (the airplane's own bank brings the sideslip's roll in)
s = R.new()
run(s, al_inp({bank = 3}), 2)
T.near(s.rudder, 0, 1e-9, "on the centreline along the course: no rudder, whatever the bank")
run(s, al_inp({trk_mag = 335}), 1)
T.check(s.rudder > 0, "the track 2 degrees left (a left engine out): LOC banks right, right rudder")
local r1 = s.rudder
run(s, al_inp({trk_mag = 335}), 2)
T.check(s.rudder > r1, "integrated while LOC asks for the bank")
s = R.new()
run(s, al_inp({hdg_mag = 343, trk_mag = 335}), 3)
T.near(s.rudder, 0, 1e-9, "crab 6 (wind from the right), LOC banking right: upwind, left alone (FCOM p.670)")
run(s, al_inp({hdg_mag = 343, trk_mag = 339}), 2)
T.check(s.rudder < 0, "crab 6, LOC banking left (downwind): left rudder to level the wings")
run(s, al_inp({mode = "LOC", rwy_align = false}), DT)
T.equal(s.rudder, nil, "no runway align: no rudder")
-- the decrab: crab 8 at 500 ft, its target down at a degree a second; the
-- wings' integral kept
s = R.new()
run(s, al_inp({hdg_mag = 345, trk_mag = 339, ra = 600}), 2)
local eo = s.al_eo
T.check(eo < 0, "above 500 ft, LOC banking downwind: the wings' rudder")
run(s, al_inp({hdg_mag = 345, trk_mag = 339, ra = 450}), 1)
T.near(s.al_tgt, 7, 0.06, "below 500 ft: the crab's target from 8 toward 5 at a degree a second")
T.check(s.rudder < eo, "the nose to the left (toward the course): left rudder")
T.equal(s.al_eo, eo, "the wings' integral kept in the decrab")
c = run(s, al_inp({hdg_mag = 345, ra = 450}), 5)
T.near(s.al_tgt, 5, 1e-9, "crab 5 below 500 ft")
T.near(c - s.loc_int, R.ALIGN_BANK * 3, 0.1, "the decrab's roll: 0.54 a degree taken down, the upwind wing down (p.362; LOC's own part a few hundredths)")
run(s, al_inp({hdg_mag = 340, ra = 150}), 3)
T.near(s.al_tgt, 3, 1e-9, "below 200 ft: 3, the rest of the 5")
run(s, al_inp({hdg_mag = 340, ra = 600}), 1)
T.equal(s.al_stage, 2, "the stage kept going back up")
-- into ROLLOUT: its integral from runway align's rudder; G/A: none
local before = s.rudder
R.update(s, al_inp({mode = "ROLLOUT", rwy_align = false, hdg_mag = 340, ra = 4}), DT)
T.near(s.rudder, before, 0.02, "ROLLOUT goes on from runway align's rudder")
T.equal(s.al_stage, 0, "runway align's state reset")
R.update(s, al_inp({mode = "GA", rwy_align = false}), DT)
T.equal(s.rudder, nil, "G/A: no rudder (the pedals and trim)")

-- off and on: the command starts again from the bank there
s = R.new()
run(s, inp({mode = "ATT", att_bank = 20, bank = 20}), 1)
R.update(s, inp({mode = "ATT", active = false}), DT)
c = R.update(s, inp({mode = "HDG_HOLD", bank = -8}), DT)
T.near(c, -7.7, 1e-9, "from the bank when the law starts")

T.done()
