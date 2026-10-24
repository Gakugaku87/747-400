-- Run from the repository root with LuaJIT: luajit tests/fltctrls/fcu_model_test.lua
-- The flap control unit model (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.fcu_model.lua)
-- against FCOM 9.20.13-15 and ATA27 27-50 (docs/overhaul/notes/ATA-27.md
-- §4.3-§4.4): the sequencing of the trailing and leading edge flaps, the
-- load relief, the change to the secondary (electric) drives and back, the
-- asymmetry stop, the alternate mode, the reverse auto retraction, the
-- messages and the indication state.
local T = dofile("tests/lib/check.lua")("fcu_model")
local M = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.fcu_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
local IB, OB = M.IB, M.OB
local A1, A2, B = M.LE_IB, M.LE_MID, M.LE_OB
local PRI_S = 30 / M.TE_PRI_DEG_S           -- primary, 0 to 30 degrees
local SEC_25_S = 22 / M.TE_SEC_DEG_S        -- secondary or alternate, 0 to flaps 25 (22 degrees)

-- UP to 1: group A (inboard and midspan) out in about 9 s, the TE stay up;
-- 1 to 5: TE 5 and group B (FCOM p.954; ATA27 p.363)
do
    local s, inp = M.new(), M.inputs()
    local out = run(s, inp, 1)
    T.check(not out.show, "all up for long: no indication")
    inp.lever = 1
    out = run(s, inp, 4)
    T.check(out.le[A1][1] > 0.3 and out.le[A1][1] < 0.6, "lever 1, 4 s: group A on its way")
    T.check(out.show and out.moving, "indication shown, lever mark magenta")
    T.near(out.tape, out.slat_a / 6, 1e-6, "group A moving: the tape between UP and 1")
    out = run(s, inp, 6)
    T.equal(out.le[A1][1], 1, "lever 1, 10 s: inboard group out")
    T.equal(out.le[A2][2], 1, "midspan group out")
    T.equal(out.le[B][1], 0, "outboard group still in")
    T.equal(out.te[IB][1], 0, "TE still up at flaps 1")
    T.near(out.tape, 1 / 6, 1e-6, "tape at 1")
    T.check(not out.moving, "all at the lever: mark green")
    inp.lever = 2
    out = run(s, inp, 10)
    T.equal(out.le[B][1], 1, "lever 5: outboard group out")
    T.near(out.te[IB][1], 5, 1e-6, "lever 5: TE 5")
    T.near(out.te_deg[1], 5, 1e-6, "TE panels at 5 degrees")
    T.near(out.tape, 2 / 6, 1e-6, "tape at 5")
    -- flaps 25 is 22 degrees on the panels (the stock tables and the 3D)
    inp.lever = 5
    out = run(s, inp, PRI_S)
    T.near(out.te_deg[2], 22, 1e-6, "lever 25: the panels at 22 degrees")
    T.check(not out.expanded, "normal indication")
    -- retraction: group B in once the IB TE are below 4.5 degrees at lever 1,
    -- group A once the OB TE are up at UP (ATA27 p.381)
    inp.lever = 1
    out = run(s, inp, (22 - 6) / M.TE_PRI_DEG_S)
    T.equal(out.le[B][1], 1, "lever 1, TE still above 4.5 degrees: outboard group still out")
    out = run(s, inp, 10 / M.TE_PRI_DEG_S + 2)
    T.equal(out.te[IB][1], 0, "lever 1: TE up")
    T.equal(out.le[B][1], 0, "TE below 4.5 degrees: outboard group in")
    T.equal(out.le[A1][1], 1, "group A stays out at lever 1")
    inp.lever = 0
    out = run(s, inp, 10)
    T.equal(out.le[A1][1], 0, "UP: group A in")
    T.check(out.show, "all up: indication for 10 s more")
    out = run(s, inp, 10.5)
    T.check(not out.show, "10 s after all up: indication gone (FCOM p.954)")
end

-- load relief: lever 30, 30->25 at 178 kt, 25->20 at 203; back at 195 and
-- 170; >FLAP RELIEF; the lever stays (FCOM p.954; ATA27 p.288-289)
do
    local s, inp = M.new(), M.inputs()
    inp.lever = 6
    M.set_to(s, inp)
    inp.ias_kt = 175
    local out = run(s, inp, 1)
    T.equal(out.cmd_detent, 6, "lever 30, 175 kt: 30")
    inp.ias_kt = 180
    out = run(s, inp, 13)
    T.equal(out.cmd_detent, 5, "180 kt: relieved to 25")
    T.check(out.relief, ">FLAP RELIEF")
    T.near(out.te[OB][2], 22, 1e-6, "the flaps went to 25 (22 degrees)")
    inp.ias_kt = 205
    out = run(s, inp, 6)
    T.equal(out.cmd_detent, 4, "205 kt: relieved to 20")
    inp.ias_kt = 197
    out = run(s, inp, 1)
    T.equal(out.cmd_detent, 4, "197 kt: still 20 (195 kt)")
    inp.ias_kt = 190
    out = run(s, inp, 1)
    T.equal(out.cmd_detent, 5, "190 kt: back to 25")
    inp.ias_kt = 165
    out = run(s, inp, 6)
    T.equal(out.cmd_detent, 6, "165 kt: back to 30")
    T.check(not out.relief, ">FLAP RELIEF gone")
    -- not in secondary (FCOM p.954): hydraulic system 4 lost
    inp.ias_kt = 190
    inp.hyd_psi[OB] = 0
    out = run(s, inp, 5)
    T.equal(s.te[OB].mode, M.SEC, "system 4 below 1400 psi for 4 s: OB TE in secondary")
    T.equal(out.cmd_detent, 6, "secondary: no load relief")
    T.check(not out.relief, "no >FLAP RELIEF")
end

-- the TE in secondary: low pressure (back when it returns), a primary
-- drive fault (secondary until fully up, then 10 s), the electric drive
-- not moving for 25 s (FLAPS DRIVE, TE FLAPS) (FCOM p.953; ATA27 p.284,
-- p.290-294)
do
    local s, inp = M.new(), M.inputs()
    inp.hyd_psi[IB] = 1300
    local out = run(s, inp, 10)
    T.equal(s.te[IB].mode, M.PRI, "1300 psi, flaps up and not commanded: stays primary")
    T.check(not out.flaps_primary, "no FLAPS PRIMARY at rest")
    inp.lever = 2
    out = run(s, inp, 3.8)
    T.equal(s.te[IB].mode, M.PRI, "commanded, 1300 psi under 4 s: primary")
    out = run(s, inp, 0.4)
    T.equal(s.te[IB].mode, M.SEC, "1300 psi for 4 s: inboard TE secondary")
    T.check(out.flaps_primary, "FLAPS PRIMARY")
    T.check(out.expanded, "secondary: expanded indication")
    out = run(s, inp, 10)
    T.near(out.te[IB][1], 10 * M.TE_SEC_DEG_S, 0.05, "secondary: slow")
    T.near(out.te[OB][1], 5, 1e-6, "outboard TE in primary at 5")
    inp.hyd_psi[IB] = 3000
    out = run(s, inp, 4.2)
    T.equal(s.te[IB].mode, M.PRI, "above 1600 psi for 4 s: back to primary")
    out = run(s, inp, 6)
    T.near(out.te[IB][1], 5, 1e-6, "primary again: at 5")
    T.check(not out.flaps_primary, "no FLAPS PRIMARY")
    -- between 1600 and 2000 psi the priority valve stays shut: no motion, 7 s
    inp.hyd_psi[OB] = 1800
    inp.lever = 3
    out = run(s, inp, 6.8)
    T.equal(s.te[OB].mode, M.PRI, "1800 psi, not moving under 7 s: primary")
    out = run(s, inp, 0.4)
    T.equal(s.te[OB].mode, M.SEC, "not moving for 7 s: outboard TE secondary")
    out = run(s, inp, 5 / M.TE_SEC_DEG_S + 1)
    T.near(out.te[OB][1], 10, 1e-6, "secondary takes it to 10")
    T.equal(s.te[OB].mode, M.SEC, "secondary with pressure: stays")
    inp.hyd_psi[OB] = 3000
    inp.lever = 0
    out = run(s, inp, 10 / M.TE_SEC_DEG_S + 1)
    T.equal(out.te[OB][1], 0, "secondary to up")
    T.equal(s.te[OB].mode, M.SEC, "just up: still secondary")
    out = run(s, inp, 10.5)
    T.equal(s.te[OB].mode, M.PRI, "10 s after fully up: primary (ATA27 p.292)")
    -- the 42 s with the gear moving
    inp.te_pri_fail[IB] = true
    inp.gear_moving = true
    inp.lever = 2
    out = run(s, inp, 20)
    T.equal(s.te[IB].mode, M.PRI, "gear moving, 20 s: still primary (42 s)")
    out = run(s, inp, 23)
    T.equal(s.te[IB].mode, M.SEC, "42 s: secondary")
    -- the electric drive fails too: 25 s not moving
    inp.te_sec_fail[IB] = true
    out = run(s, inp, 24)
    T.check(not out.flaps_drive, "secondary not moving under 25 s: no FLAPS DRIVE")
    out = run(s, inp, 1.5)
    T.check(out.flaps_drive, "25 s: FLAPS DRIVE (FCOM p.957)")
    T.check(out.st_te_flaps, "STATUS TE FLAPS")
end

-- asymmetry: a group's sides apart by 3.4 % (OB): that group stops, no
-- secondary; FLAPS DRIVE; the other group goes on (FCOM p.953)
do
    local s, inp = M.new(), M.inputs()
    inp.te_stuck[OB] = true
    inp.lever = 3
    local out = run(s, inp, 3)
    T.check(out.te[OB][2] < 30 * 0.034 + 0.2, "OB right side stopped just past 3.4 %")
    T.equal(out.te[OB][1], 0, "OB left side stuck")
    T.check(out.flaps_drive, "FLAPS DRIVE")
    T.check(out.expanded, "expanded indication")
    out = run(s, inp, 13)
    T.near(out.te[IB][1], 10, 1e-6, "IB TE go on to 10")
    T.check(s.te[OB].mode ~= M.SEC, "no secondary after an asymmetry")
end

-- the LE: a pneumatic drive that does not move goes electric after 30 s
-- (20-45 s), both wings; inboard and midspan together; pneumatic again
-- at the command; a duct lost on one wing: the other wing goes on first
-- (FCOM p.953)
do
    local s, inp = M.new(), M.inputs()
    inp.le_pri_fail[A2] = true
    inp.lever = 1
    local out = run(s, inp, 20)
    T.equal(out.le[A1][1], 1, "inboard group out in primary")
    T.equal(out.le[A2][1], 0, "midspan group stuck")
    T.check(not out.flaps_primary, "under 30 s: no FLAPS PRIMARY")
    out = run(s, inp, 10.5)
    T.equal(s.le[A2].mode, M.SEC, "30 s: midspan group electric")
    T.equal(s.le[A1].mode, M.SEC, "inboard group electric with it")
    T.check(out.flaps_primary, "FLAPS PRIMARY")
    T.check(out.st_le_mult, "STATUS LE MULT DRIVE")
    out = run(s, inp, M.LE_SEC_S + 1)
    T.equal(out.le[A2][1], 1, "electric: midspan out")
    T.equal(s.le[A2].mode, M.PRI, "at the command: pneumatic again")
    T.check(not out.flaps_primary, "no FLAPS PRIMARY")
    -- the left duct lost: the right wing's outboard group moves, then both electric
    inp.le_pri_fail[A2] = false
    inp.duct_psi[1] = 0
    inp.lever = 2
    out = run(s, inp, 10)
    T.equal(out.le[B][2], 1, "right wing's outboard group out")
    T.equal(out.le[B][1], 0, "left wing's: no pneumatic power")
    T.check(out.expanded, "LE apart: expanded indication")
    out = run(s, inp, 21)
    T.equal(s.le[B].mode, M.SEC, "outboard group electric")
    T.check(out.st_le_single, "STATUS LE SINGLE DRIVE")
    out = run(s, inp, M.LE_SEC_S + 1)
    T.equal(out.le[B][1], 1, "left wing out by the electric drive")
end

-- alternate: ALTN ARM takes the lever away (FLAPS CONTROL); EXT moves all
-- groups at once, the TE stop at 25; RET: the LE wait for the IB TE; no
-- load relief (FCOM p.935, p.954, p.957)
do
    local s, inp = M.new(), M.inputs()
    inp.altn_arm = true
    local out = run(s, inp, 1)
    T.check(out.flaps_control, "ALTN ARM: FLAPS CONTROL")
    T.check(out.expanded, "alternate: expanded indication")
    inp.lever = 6
    out = run(s, inp, 5)
    T.equal(out.te[IB][1], 0, "the lever does nothing")
    inp.altn_sel = 1
    out = run(s, inp, 10)
    T.check(out.te[IB][1] > 0 and out.le[B][1] > 0, "EXT: TE and LE start at once")
    out = run(s, inp, SEC_25_S + 5)
    T.near(out.te[IB][1], 22, 1e-6, "EXT: TE stop at flaps 25 (22 degrees)")
    T.equal(out.le[B][1], 1, "LE out")
    inp.ias_kt = 230
    out = run(s, inp, 2)
    T.check(not out.relief, "alternate: no load relief")
    inp.altn_sel = -1
    out = run(s, inp, 10 / M.TE_SEC_DEG_S)
    T.equal(out.le[A1][1], 1, "RET: LE wait while the IB TE are out")
    out = run(s, inp, 15 / M.TE_SEC_DEG_S + M.LE_SEC_S + 2)
    T.equal(out.te[IB][1], 0, "RET: TE up")
    T.equal(out.le[A1][1], 0, "then the LE in")
    -- disarmed: the FCUs take the flaps to the lever (30)
    inp.altn_arm, inp.altn_sel, inp.ias_kt = false, 0, 150
    out = run(s, inp, PRI_S + 10)
    T.check(not out.flaps_control, "disarmed: no FLAPS CONTROL")
    T.near(out.te[OB][2], 30, 1e-6, "disarmed: flaps to the lever (ATA27 p.302)")
end

-- all three FCUs failed: FLAPS CONTROL, the flaps stay (FCOM p.953)
do
    local s, inp = M.new(), M.inputs()
    inp.fcu_fail = {true, true, false}
    local out = run(s, inp, 1)
    T.check(not out.flaps_control, "one FCU left: no FLAPS CONTROL")
    T.check(out.st_fcu[1] and out.st_fcu[2], "STATUS FLAP CONTROL L, C")
    inp.fcu_fail[3] = true
    inp.lever = 2
    out = run(s, inp, 5)
    T.check(out.flaps_control, "all three: FLAPS CONTROL")
    T.equal(out.le[A1][1], 0, "no FCU: the flaps do not move")
end

-- reverse on the ground: group A in while engines 1 and 4 reverse, out
-- again after (ATA27 p.382; FCOM p.955)
do
    local s, inp = M.new(), M.inputs()
    inp.lever = 6
    M.set_to(s, inp)
    inp.reverse = {true, false, false, false}
    local out = run(s, inp, 2)
    T.equal(out.le[A1][1], 1, "engine 1 alone in reverse: group A stays")
    inp.reverse[4] = true
    out = run(s, inp, 10)
    T.equal(out.le[A1][1], 0, "engines 1 and 4 in reverse on the ground: group A in")
    T.equal(out.le[B][1], 1, "group B stays")
    T.check(out.moving, "the indication shows them moving")
    inp.reverse = {false, false, false, false}
    out = run(s, inp, 10)
    T.equal(out.le[A1][1], 1, "reverse over: group A out again")
    inp.on_ground = false
    inp.reverse = {true, true, true, true}
    out = run(s, inp, 10)
    T.equal(out.le[A1][1], 1, "in the air: no auto retraction")
end

-- a flight starting with the flaps out: set_to puts them at the lever
do
    local s, inp = M.new(), M.inputs()
    inp.lever = 3
    M.set_to(s, inp)
    local out = run(s, inp, 0.1)
    T.near(out.te[IB][1], 10, 1e-6, "started at flaps 10")
    T.equal(out.le[B][2], 1, "LE out")
    T.check(not out.moving and out.show, "shown, mark green")
end

T.done()
