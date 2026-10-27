-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_roll_model_test.lua
-- The FCCs' roll laws, step 2a (6-3: docs/overhaul/notes/ATA-22.md §16):
-- plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_roll_model.lua.
-- The bank of a heading error, the bank limit (the selector, AUTO by TAS,
-- flaps and V2), HDG SEL's turn (the smaller error when selected before the
-- push, the knob's way after it, past 180 degrees too), HDG HOLD (wings
-- level, then the heading; kept through a change of the reference), ATT,
-- LNAV (only the V2 + 10 limit), T/O and G/A's track, no command without a
-- law (LOC, no mode, nothing engaged or shown), NCD in NORM's polar areas,
-- the rate.
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
T.equal(R.update(s, inp({mode = "LOC"}), DT), nil, "LOC: the old law")
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

-- off and on: the command starts again from the bank there
s = R.new()
run(s, inp({mode = "ATT", att_bank = 20, bank = 20}), 1)
R.update(s, inp({mode = "ATT", active = false}), DT)
c = R.update(s, inp({mode = "HDG_HOLD", bank = -8}), DT)
T.near(c, -7.7, 1e-9, "from the bank when the law starts")

T.done()
