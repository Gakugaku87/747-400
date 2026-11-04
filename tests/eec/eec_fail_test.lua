-- Run from the repository root with LuaJIT: luajit tests/eec/eec_fail_test.lua
-- The EEC model's failures (2026-11-04; docs/overhaul/notes/ATA-70-80.md
-- §10): the automatic (soft) reversion to the alternate mode keeps the
-- thrust and the last valid schedule (FCOM p.876-877; ATA70_80 p.204,
-- p.207), ENG n EEC MODE, the A/T disconnect, the ALTN light (ATA70_80
-- p.202-203, p.245); an EEC system fault: >ENG n CONTROL, three or four:
-- >ENG CONTROLS, both on the ground only (FCOM p.899).
local T = dofile("tests/lib/check.lua")("eec_fail")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")

local DT = 0.1
local function cruise(kind)
    local st, i = E.new(), E.inputs()
    i.type, i.alt, i.tat, i.kias, i.air = kind, 31000, -25, 280, true
    if kind == "GE" then i.idle = {25, 25, 25, 25} else i.idle = {0.95, 0.95, 0.95, 0.95} end
    i.lever = {0.5, 0.5, 0.5, 0.5}       -- below the full rating
    i.n2 = {95, 95, 95, 95}
    return st, i
end

-- nothing failed: no messages
for _, kind in ipairs({"GE", "PW"}) do
    local st, i = cruise(kind)
    local o = E.update(st, i, DT)
    T.check(not o.altn[2] and not o.altn_light[2] and not o.control_alert[2] and not o.controls_alert,
        kind .. " normal: no alternate mode, no messages")
end

-- the automatic reversion of engine 2 in cruise: the same command at once
-- (the thrust does not change), ENG 2 EEC MODE, the A/T disconnects and is
-- inhibited, the ALTN light; the schedule held while the ambient changes
for _, kind in ipairs({"GE", "PW"}) do
    local st, i = cruise(kind)
    local o = E.update(st, i, DT)
    local before = o.command[2]
    i.fail_altn[2] = true
    o = E.update(st, i, DT)
    T.near(o.command[2], before, 1e-9, kind .. " automatic reversion: the command does not change")
    T.check(o.altn[2] and not o.altn[1], kind .. " automatic reversion: engine 2 in the alternate mode (ENG 2 EEC MODE)")
    T.check(o.at_disconnect and o.at_inhibit, kind .. " automatic reversion: the A/T disconnects, no A/T")
    T.check(o.altn_light[2], kind .. " automatic reversion: the ALTN light")
    T.check(not o.control_alert[2], kind .. " in flight: >ENG 2 CONTROL inhibited")
    -- the ambient changes: the normal engines follow, engine 2 keeps the old
    -- schedule (the last valid values)
    i.tat = 20
    o = E.update(st, i, DT)
    T.check(math.abs(o.command[1] - before) > 1e-6, kind .. " warmer: the normal engines' command moves")
    T.near(o.command[2], before, 1e-9, kind .. " warmer: engine 2 keeps the last valid schedule")
    -- the crew selects ALTN: the hard reversion, the corner point schedule
    i.altn[2] = true
    o = E.update(st, i, DT)
    T.check(o.command[2] >= o.command[1] - 1e-9 and math.abs(o.command[2] - before) > 1e-6,
        kind .. " ALTN selected: the hard reversion's schedule (the corner point, not below the normal)")
    -- repaired and back to NORM: the normal mode
    i.altn[2], i.fail_altn[2] = false, false
    o = E.update(st, i, DT)
    T.check(not o.altn[2] and not o.altn_light[2] and not o.at_inhibit, kind .. " repaired: normal mode")
    T.near(o.command[2], o.command[1], 1e-9, kind .. " repaired: the normal schedule again")
end

-- the GE's ALTN light for the automatic reversion needs 50 % N2 (the ECU's
-- reversionary mode contact); the A/T with all four switches at ALTN
do
    local st, i = cruise("GE")
    i.n2 = {20, 20, 20, 20}
    i.fail_altn[3] = true
    local o = E.update(st, i, DT)
    T.check(o.altn[3] and not o.altn_light[3], "GE below 50 % N2: alternate mode, no ALTN light")
    i.altn = {true, true, true, false}
    o = E.update(st, i, DT)
    T.check(o.at_inhibit, "GE, three switches at ALTN and one reverted by itself: no A/T")
    i.altn[4] = true
    i.altn[3] = true
    o = E.update(st, i, DT)
    T.check(not o.at_inhibit, "GE, all four switches at ALTN: the A/T can be used again (FCOM p.877)")
end

-- an EEC system fault: >ENG n CONTROL on the ground; three: >ENG CONTROLS;
-- in flight neither (FCOM p.899)
do
    local st, i = cruise("PW")
    i.air = false
    i.fault[1] = true
    local o = E.update(st, i, DT)
    T.check(o.control_alert[1] and not o.control_alert[2], "EEC 1 fault on the ground: >ENG 1 CONTROL")
    T.check(not o.altn[1], "a fault alone: still the normal mode")
    T.check(not o.controls_alert, "one fault: no >ENG CONTROLS")
    i.fault[2], i.fail_altn[3] = true, true
    o = E.update(st, i, DT)
    T.check(o.controls_alert, "three EECs degraded (one reverted): >ENG CONTROLS")
    T.check(o.control_alert[3], "the reverted EEC: >ENG 3 CONTROL")
    i.air = true
    o = E.update(st, i, DT)
    T.check(not o.controls_alert and not o.control_alert[1], "in flight: >ENG CONTROLS and >ENG 1 CONTROL inhibited")
end

T.done()
