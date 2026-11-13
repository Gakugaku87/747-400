-- Run from the repository root with LuaJIT: luajit tests/gear/gear_model_test.lua
-- The landing gear actuation model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.gear_model.lua)
-- against FCOM 14.10-14.20 and ATA29_32 32-00, 32-09, 32-61
-- (docs/overhaul/notes/ATA-32.md §3.2, §3.4, §4.3-§4.5): the sequence with
-- the doors, the systems moving each gear, the alternate extension, the
-- monitoring messages and the EICAS indication.
local T = dofile("tests/lib/check.lua")("gear_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.gear_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
local N, LB, RB, LW, RW = M.NOSE, M.LB, M.RB, M.LW, M.RW
local function airborne(inp)
    for i = 1, 5 do inp.on_ground[i] = false end
    inp.air = true
end
local function gear_up(s, inp)
    airborne(inp)
    inp.lever = M.UP
    return run(s, inp, 25)
end

-- retraction in the air: the doors open in 2 s, then the gear travels, then
-- the doors close in 5 s (ATA29_32 p.242, p.248); the transit box, UP, and
-- UP blank 10 s later (FCOM p.1505)
do
    local s, inp = M.new(), M.inputs()
    airborne(inp)
    local out = run(s, inp, 1)
    T.equal(out.annun, M.IND_DOWN, "down and locked: DOWN")
    T.equal(out.display, M.DISPLAY_NORMAL, "the normal display")
    inp.lever = M.UP
    out = run(s, inp, 1.5)
    T.check(out.door[LW] > 0.5 and out.door[LW] < 1 and out.pos[LW] == 1, "1.5 s: the doors opening, the gear still down")
    T.equal(out.annun, M.IND_DOWN, "doors opening, the gear not moving yet: still DOWN")
    out = run(s, inp, 2 + M.GEAR_S[LW] - 1.5 - 0.3)
    T.check(out.pos[LW] > 0 and out.pos[LW] < 0.1, "the wing gear nearly up")
    out = run(s, inp, 0.4)
    T.check(out.uplocked[LW] and out.uplocked[RW], "wing gear up and locked after 2 + 7 s")
    T.check(not out.uplocked[N], "the nose gear still travelling (12 s)")
    out = run(s, inp, 5)
    T.check(out.uplocked[N] and out.uplocked[LB] and out.uplocked[RB], "all up and locked after 2 + 12 s")
    T.equal(out.annun, M.IND_UP, "UP")
    T.check(out.door[LW] < 1, "the wing gear doors closing")
    out = run(s, inp, 5)
    T.equal(out.door[N], 0, "the doors closed 5 s after the gear locked up")
    T.equal(out.display, M.DISPLAY_NORMAL, "UP shown, under 10 s")
    out = run(s, inp, 6)
    T.equal(out.display, M.DISPLAY_OFF, "UP blanks 10 s after all locked up")
    T.check(not out.gear_disagree and not out.gear_door, "a normal retraction: no message")
    -- extension: blank while the doors open with the gear up and locked (the
    -- UP symbol only for 10 s: ATA29_32 p.658), stripes once a gear leaves its
    -- uplock, DOWN after the slowest gear
    inp.lever = M.DN
    out = run(s, inp, 0.5)
    T.equal(out.display, M.DISPLAY_OFF, "lever DN, doors opening, all up and locked: still blank")
    out = run(s, inp, 2)
    T.equal(out.display, M.DISPLAY_NORMAL, "a gear leaving its uplock: the indication back")
    T.equal(out.annun, M.IND_TRANSIT, "stripes")
    out = run(s, inp, M.GEAR_S[N])
    T.check(out.all_down, "all down and locked after 2 + 12 s")
    T.equal(out.annun, M.IND_DOWN, "DOWN")
    out = run(s, inp, 5)
    T.equal(out.door[LB], 0, "the doors closed after the extension")
end

-- on the ground a gear carrying weight does not come up (the lever lock is the
-- PSEU's; with LOCK OVRD the actuators cannot lift the airplane: estimate)
do
    local s, inp = M.new(), M.inputs()
    inp.lever = M.UP
    local out = run(s, inp, 20)
    T.check(out.all_down, "lever UP on the ground: the gear stays down")
    T.check(out.door[N] == 0, "and the doors stay closed")
end

-- the systems: nose and body gear on system 1, wing gear on system 4 (FCOM
-- p.1511). System 4 lost with the gear up: the wing gear stays up; GEAR
-- DISAGREE after 30 s and the expanded display (ATA29_32 p.662, p.660)
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.hyd_psi[2] = 0
    inp.lever = M.DN
    local out = run(s, inp, 2 + M.GEAR_S[N] + 1)
    T.check(out.downlocked[N] and out.downlocked[LB] and out.downlocked[RB], "system 1: the nose and body gear down")
    T.check(out.uplocked[LW] and out.uplocked[RW], "no system 4: the wing gear stays up and locked")
    T.equal(out.annun, M.IND_TRANSIT, "not all down, not all up: the transit box")
    T.check(not out.gear_disagree, "15 s: no GEAR DISAGREE yet")
    out = run(s, inp, 30 - 15 + 0.2)
    T.check(out.gear_disagree, "30 s after the lever: GEAR DISAGREE")
    T.equal(out.display, M.DISPLAY_EXPANDED, "the expanded display")
    T.equal(out.gear[LW], M.IND_UP, "wing gear boxes UP")
    T.equal(out.gear[LB], M.IND_DOWN, "body gear boxes DN")
    -- WING alternate extension: the motor opens the doors, the uplock goes past
    -- 45 degrees, about 20 s up to down (p.250, p.272); the doors stay open
    inp.altn_wing = true
    out = run(s, inp, 0.5)
    T.check(out.door[LW] > 0 and out.uplocked[LW], "ALTN WING: the door opening, the uplock still holds")
    out = run(s, inp, 10)
    T.check(not out.uplocked[LW] and not out.downlocked[LW], "10 s: the wing gear falling")
    out = run(s, inp, 10)
    T.check(out.downlocked[LW] and out.downlocked[RW], "about 20 s: the wing gear down and locked")
    T.equal(out.door[LW], 1, "the doors remain open (FCOM p.1513)")
    T.check(not out.gear_disagree, "all down with the lever DN: GEAR DISAGREE goes")
    T.equal(out.display, M.DISPLAY_EXPANDED, "the alternate extension used: the expanded display stays")
    out = run(s, inp, 40)
    T.check(not out.gear_door, "doors open after an alternate extension: no GEAR DOOR")
    inp.altn_wing = false
    out = run(s, inp, 40)
    T.equal(out.door[RW], 1, "switch back: the doors still open")
    T.check(not out.gear_door, "and still no GEAR DOOR")
    T.equal(out.display, M.DISPLAY_EXPANDED, "and the expanded display")
    -- a flight start clears it
    M.set_to(s, {1, 1, 1, 1, 1})
    out = run(s, inp, 0.1)
    T.equal(out.display, M.DISPLAY_NORMAL, "set_to: the normal display")
    T.equal(out.door[LW], 0, "set_to: doors closed")
end

-- the alternate extension needs its motor's power: WING AC bus 1, NOSE/BODY
-- AC bus 4 with DC bus 4 (ATA29_32 p.270-272); with it the nose and body gear
-- fall without system 1
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.hyd_psi[1], inp.hyd_psi[2] = 0, 0
    inp.ac[1] = false
    inp.altn_wing = true
    local out = run(s, inp, 25)
    T.check(out.uplocked[LW] and out.door[LW] == 0, "ALTN WING without AC bus 1: nothing moves")
    inp.ac[4] = false
    inp.altn_nose_body = true
    out = run(s, inp, 25)
    T.check(out.uplocked[N], "ALTN NOSE/BODY without AC bus 4: nothing moves")
    inp.ac[4] = true
    out = run(s, inp, 1)
    T.check(not out.uplocked[N] and not out.uplocked[LB], "AC bus 4 back: the nose and body gear fall")
    T.check(out.uplocked[LW], "the wing gear still up")
    out = run(s, inp, M.GEAR_S[N])
    T.check(out.downlocked[N] and out.downlocked[LB] and out.downlocked[RB], "nose and body gear down and locked, no hydraulics")
    T.equal(out.door[N], 1, "their doors open")
end

-- lever OFF holds the gear where it is (the gear hydraulics depressurized)
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.lever = M.OFF
    local out = run(s, inp, 40)
    T.check(out.all_up, "lever OFF after a retraction: the gear stays up")
    T.check(not out.gear_disagree, "OFF and up and locked: no GEAR DISAGREE")
end

-- failures: a stuck gear gives GEAR DISAGREE; a door that stays open, GEAR DOOR
do
    local s, inp = M.new(), M.inputs()
    airborne(inp)
    inp.stuck[RB] = true
    inp.lever = M.UP
    local out = run(s, inp, 29)
    T.check(not out.gear_disagree, "29 s: not yet")
    out = run(s, inp, 1.2)
    T.check(out.gear_disagree, "the right body gear does not come up: GEAR DISAGREE at 30 s")
    T.equal(out.gear[RB], M.IND_DOWN, "its box DN")
    T.equal(out.gear[LB], M.IND_UP, "the others UP")
    T.equal(out.display, M.DISPLAY_EXPANDED, "expanded")
end
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.lever = M.DN
    local out = run(s, inp, 2.5)
    T.equal(out.door[LW], 1, "the doors open")
    inp.door_stuck[LW] = true
    out = run(s, inp, 20)
    T.check(out.all_down, "all down")
    T.equal(out.door[LW], 1, "the left wing gear door stays open")
    T.equal(out.door[RW], 0, "the right one closed")
    out = run(s, inp, 7)
    T.check(not out.gear_door, "29.5 s with the door open: no GEAR DOOR")
    out = run(s, inp, 0.7)
    T.check(out.gear_door, "30 s: GEAR DOOR")
    T.check(not out.gear_disagree, "the gear is down: no GEAR DISAGREE")
end

-- GEAR TILT: a main gear truck not tilted in air mode for 15 s; inhibited with
-- system 1 or 4 low (ATA29_32 p.336-337, p.341)
do
    local s, inp = M.new(), M.inputs()
    airborne(inp)
    inp.tilted[LW] = false
    local out = run(s, inp, 14.8)
    T.check(not out.gear_tilt, "14.8 s: not yet")
    out = run(s, inp, 0.4)
    T.check(out.gear_tilt, "15 s: GEAR TILT")
    inp.hyd_psi[2] = 1000
    out = run(s, inp, 0.1)
    T.check(not out.gear_tilt, "system 4 low: inhibited")
    inp.hyd_psi[2] = 3000
    inp.air = false
    out = run(s, inp, 20)
    T.check(not out.gear_tilt, "ground mode: no GEAR TILT")
end

-- the indication lost: one gear's box an amber X (expanded); all of them, the
-- empty box (FCOM p.1505-1506)
do
    local s, inp = M.new(), M.inputs()
    inp.ind_fail[N] = true
    local out = run(s, inp, 0.1)
    T.equal(out.gear[N], M.IND_FAIL, "nose indication lost: its box X")
    T.equal(out.annun, M.IND_DOWN, "the others: the normal display still DOWN")
    for i = 1, 5 do inp.ind_fail[i] = true end
    out = run(s, inp, 0.1)
    T.equal(out.annun, M.IND_FAIL, "all lost: the empty box")
end

-- (2026-11-13; the 2026-11-12 review FG-7) after an alternate extension's
-- cycle (no recycling needed: ATA29_32 p.276-278) the lever moved to UP in
-- the air gives the gear back to the normal system: it retracts and its
-- doors close (estimate). Before, the gear stayed down for the flight
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.lever = M.OFF
    inp.altn_nose_body, inp.altn_wing = true, true
    local out = run(s, inp, 25)
    T.check(out.all_down, "ALTN with the lever OFF: all down and locked")
    inp.altn_nose_body, inp.altn_wing = false, false
    out = run(s, inp, 1)
    T.equal(out.door[N], 1, "switches back: the doors still open (FCOM p.1513)")
    inp.lever = M.UP
    out = run(s, inp, 2 + M.GEAR_S[N] + 0.5)
    T.check(out.all_up, "the lever moved to UP: the normal system retracts the gear (estimate; before, it stayed down)")
    out = run(s, inp, M.DOOR_CLOSE_S + 0.5)
    T.equal(out.door[N] + out.door[LB] + out.door[LW], 0, "and closes the doors")
    T.equal(out.display, M.DISPLAY_NORMAL, "the normal display again")
    T.check(not out.gear_door and not out.gear_disagree, "no GEAR DOOR, no GEAR DISAGREE")
    -- a new push: a new cycle
    inp.altn_wing = true
    out = run(s, inp, 25)
    T.check(out.downlocked[LW] and out.downlocked[RW], "ALTN WING pushed again: a new cycle, the wing gear down")
    T.check(out.uplocked[N], "the nose gear stays up")
end
-- the lever UP all along: the gear stays down (the lever not moved to UP);
-- moved DN and UP, the gear comes up with the switch still pushed (no new
-- cycle without a new push)
do
    local s, inp = M.new(), M.inputs()
    gear_up(s, inp)
    inp.altn_wing = true
    local out = run(s, inp, 40)
    T.check(out.downlocked[LW] and out.downlocked[RW], "ALTN WING with the lever UP all along: the wing gear down and it stays")
    inp.lever = M.DN
    out = run(s, inp, 0.5)
    inp.lever = M.UP
    out = run(s, inp, 2 + M.GEAR_S[LW] + 0.5)
    T.check(out.uplocked[LW] and out.uplocked[RW], "the lever moved DN and UP: the wing gear retracts, the switch still pushed")
end
-- pushed on the ground and back (the doors open): after the takeoff the
-- gear comes up (before, the nose and body gear stayed down)
do
    local s, inp = M.new(), M.inputs()
    inp.altn_nose_body = true
    local out = run(s, inp, 1)
    T.equal(out.door[N], 1, "ALTN NOSE/BODY on the ground: the doors open")
    inp.altn_nose_body = false
    out = run(s, inp, 1)
    T.check(out.all_down, "the gear down")
    airborne(inp)
    inp.lever = M.UP
    out = run(s, inp, 2 + M.GEAR_S[N] + 0.5)
    T.check(out.all_up, "after the takeoff, the lever UP: all up and locked")
end

-- (2026-11-13; the 2026-11-12 review HA-1, 案 26) the gear's flow: with less
-- flow from systems 1 and 4 than the moving gears and doors need (18 gpm a
-- system), they move slower in proportion (estimates; FCTM p.286 (8.8): up
-- to two and a half minutes on windmilling engine pumps); what they take
do
    local s, inp = M.new(), M.inputs()
    local out = gear_up(s, inp)
    T.equal(out.hyd_gpm[1] + out.hyd_gpm[2], 0, "up and locked, doors closed: no flow")
    -- all engines windmilling at about 10 % N2: 3.75 gpm a pump, 3.25 after the leakage
    inp.spare_gpm[1], inp.spare_gpm[2] = 3.25, 3.25
    inp.lever = M.DN
    out = run(s, inp, 1)
    T.check(math.abs(out.hyd_gpm[1] - 3.25) < 1e-9 and math.abs(out.hyd_gpm[2] - 3.25) < 1e-9,
        "the gear takes what systems 1 and 4 give (3.25 gpm each)")
    out = run(s, inp, 2 + M.GEAR_S[N])
    T.check(not out.all_down and not out.downlocked[LW], "15 s: not down (the normal time 14 s)")
    -- the wing gear: (2 + 7 s) x 18 / 3.25 = 49.8 s; the nose gear, the
    -- body gear's doors closing meanwhile: (2 + 12 s) x 18 / 3.25 = 77.5 s
    out = run(s, inp, 49 - 15)
    T.check(not out.downlocked[LW], "49 s: the wing gear not yet")
    out = run(s, inp, 1.5)
    T.check(out.downlocked[LW] and out.downlocked[RW], "50.5 s: the wing gear down and locked")
    out = run(s, inp, 76 - 50.5)
    T.check(not out.downlocked[N], "76 s: the nose gear not yet")
    out = run(s, inp, 3)
    T.check(out.all_down, "79 s: all down and locked (up to 150 s: FCTM p.286)")
    -- an engine pump at flight idle (about 60 % N2: 22.5 gpm, 22 after the
    -- leakage): the normal times
    local s2, inp2 = M.new(), M.inputs()
    gear_up(s2, inp2)
    inp2.spare_gpm[1], inp2.spare_gpm[2] = 22, 22
    inp2.lever = M.DN
    out = run(s2, inp2, 1)
    T.equal(out.hyd_gpm[1], 18, "an engine pump at flight idle: the gear takes its 18 gpm")
    out = run(s2, inp2, 2 + M.GEAR_S[N] - 1 + 0.3)
    T.check(out.all_down, "and comes down in the normal 14 s")
    out = run(s2, inp2, M.DOOR_CLOSE_S + 0.3)
    T.equal(out.hyd_gpm[1] + out.hyd_gpm[2], 0, "doors closed: no flow")
    -- no flow at all: the gear holds where it is, with pressure
    local s3, inp3 = M.new(), M.inputs()
    gear_up(s3, inp3)
    inp3.spare_gpm[1], inp3.spare_gpm[2] = 0, 0
    inp3.lever = M.DN
    out = run(s3, inp3, 30)
    T.check(out.all_up and out.door[N] == 0, "no flow: nothing moves")
    -- the alternate extension takes none (electric motors, gravity)
    inp3.altn_nose_body, inp3.altn_wing = true, true
    out = run(s3, inp3, 25)
    T.check(out.all_down, "no flow, ALTN: all down")
    T.equal(out.hyd_gpm[1] + out.hyd_gpm[2], 0, "the alternate extension takes no flow")
end

-- a flight start with the gear up (an air start): UP is not shown
do
    local s, inp = M.new(), M.inputs()
    airborne(inp)
    inp.lever = M.UP
    M.set_to(s, {0, 0, 0, 0, 0})
    local out = run(s, inp, 0.1)
    T.check(out.all_up, "set_to up: all up and locked")
    T.equal(out.display, M.DISPLAY_OFF, "no UP box after the start")
end

T.done()
