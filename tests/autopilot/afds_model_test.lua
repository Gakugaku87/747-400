-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_model_test.lua
-- The FCCs' mode logic, step 1a (6-3: docs/overhaul/notes/ATA-22.md §10):
-- plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua.
-- The A/P's engage (CMD: the bar, the other channels, the servos'
-- hydraulics; on the ground too) and disengage (the bar, the control wheel
-- switches, automatically, the hydraulics), AUTOPILOT DISC and its reset,
-- the default modes on the A/P's engage and the first F/D ON (V/S with
-- HDG HOLD or ATT by the bank, PW and GE; TO/GA on the ground), everything
-- off with neither the A/P nor a F/D, the old approach's channels.
local T = dofile("tests/lib/check.lua")("afds_model")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua")

local HYD = {3000, 3000, 3000}
local function inp(o)
    o = o or {}
    return {fd = {L = o.fdL or false, R = o.fdR or false}, hyd = o.hyd or HYD, bank = o.bank or 0,
        engine = o.engine or 0, ground = o.ground or false, toga = o.toga or false}
end

-- engage with both F/Ds OFF: V/S and HDG HOLD (FCOM p.640; ATA22 p.266)
local s = A.new()
local act = A.cmd(s, "L", inp())
T.check(s.L and A.engaged(s) == 1, "CMD L engages the left channel")
T.check(act and act.roll == "HDG_HOLD" and act.pitch == "VS", "with both F/Ds OFF: V/S and HDG HOLD")
T.equal(A.cmd(s, "C", inp()), nil, "a second channel does not engage in cruise (ATA22 p.314, p.318)")
T.check(not s.C and A.engaged(s) == 1, "only the left channel")
T.equal(A.cmd(s, "L", inp()), nil, "its own CMD again: nothing")

-- the bank: ATT above 5 degrees on the PW (and RR), held to 30; HDG HOLD
-- on the GE 570 (FCOM p.640, p.663)
local function engage_bank(bank, engine)
    local s2 = A.new()
    return A.cmd(s2, "C", inp({bank = bank, engine = engine}))
end
local a1 = engage_bank(12, 0)
T.check(a1.roll == "ATT" and a1.bank == 12, "PW, 12 degrees of bank: ATT holding 12")
local a2 = engage_bank(-40, 0)
T.check(a2.roll == "ATT" and a2.bank == -30, "PW, 40 degrees left: ATT to 30 left")
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
T.check(fa and fa.pitch == "VS" and fa.roll == "HDG_HOLD", "the first F/D ON in the air: V/S and HDG HOLD")
T.equal(A.update(f, inp({fdL = true, fdR = true})), nil, "the second F/D ON: nothing")
T.equal(A.update(f, inp({fdL = true, fdR = true})), nil, "and nothing after")
local f2 = A.new()
local fb = A.update(f2, inp({fdR = true, bank = -20}))
T.check(fb.roll == "ATT" and fb.bank == -20, "the first F/D ON at 20 degrees left: ATT")
local f3 = A.new()
local fc = A.update(f3, inp({fdL = true, ground = true}))
T.check(fc and fc.toga and not fc.pitch, "the first F/D ON on the ground: TO/GA (ATA22 p.337)")
local f4 = A.new()
A.cmd(f4, "L", inp())
T.equal(A.update(f4, inp({fdL = true})), nil, "a F/D ON with the A/P engaged: the A/P's modes")

-- the A/P engaged with a F/D ON: its modes, but from the F/D's takeoff on
-- the ground HDG HOLD and V/S (ATA22 p.266)
local g = A.new()
A.update(g, inp({fdL = true, ground = true}))
local ga = A.cmd(g, "L", inp({fdL = true, ground = true, toga = true}))
T.check(ga and ga.roll == "HDG_HOLD" and ga.pitch == "VS" and ga.toga_off, "the F/D's T/O on the ground: HDG HOLD and V/S")
local g2 = A.new()
A.update(g2, inp({fdL = true}))
T.equal(A.cmd(g2, "L", inp({fdL = true, toga = true})), nil, "TO/GA in the air: the A/P in it")

-- everything off with neither the A/P nor a F/D (FCOM p.660)
local h = A.new()
A.update(h, inp({fdL = true}))
local ho = A.update(h, inp())
T.check(ho and ho.all_off, "both F/Ds OFF with no A/P: everything off")
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

T.done()
