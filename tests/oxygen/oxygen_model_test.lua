-- Run from the repository root with LuaJIT: luajit tests/oxygen/oxygen_model_test.lua
-- The oxygen model (plugins/xtlua/scripts/B747.36.xt.oxygen/B747.36.oxygen_model.lua)
-- against FCOM 1.30-1.60 and ATA30_32_35_36 35-xx: the passenger oxygen's
-- automatic actuation, ON and RESET, the therapeutic oxygen, the cylinder
-- pressures and their temperature, >CREW OXY LOW, PASS OXYGEN ON and its
-- status message, and the altitude the crew feel on their masks.
local T = dofile("tests/lib/check.lua")("oxygen_model")
local M = dofile("plugins/xtlua/scripts/B747.36.xt.oxygen/B747.36.oxygen_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end

-- a new flight: full cylinders (1850 psig at 70°F: ATA30_32_35_36 p.316),
-- everything off
do
    local s, inp = M.new(), M.inputs()
    inp.cabin_alt_ft = 6000
    local out = run(s, inp, 1)
    T.near(out.crew_psi, 1850, 0.5, "70°F: crew cylinder 1850 psi")
    T.near(out.pass_psi, 1850, 0.5, "70°F: passenger cylinders 1850 psi")
    T.check(not out.pass_on and not out.therap_on, "NORM below 14,000 ft: passenger and therapeutic oxygen off")
    T.check(not out.pass_on_alert and not out.therap_memo and not out.crew_low_alert, "no oxygen message")
    T.equal(out.felt_alt_ft, 6000, "no mask: the crew feel the cabin altitude")
    -- the gas law: colder cylinders show less pressure
    inp.cylinder_c = 0
    out = run(s, inp, 0.1)
    T.near(out.crew_psi, (1850 + 14.7) * 273.15 / 294.26 - 14.7, 0.5, "0°C: about 1716 psi")
    T.check(out.crew_psi < 1730 and out.crew_psi > 1700, "0°C: between 1700 and 1730 psi")
end

-- the cabin climbs: the flow control units actuate at about 14,000 ft and
-- the therapeutic oxygen with them (FCOM p.456, p.513; ATA30_32_35_36 p.346)
do
    local s, inp = M.new(), M.inputs()
    inp.cabin_alt_ft = 13900
    local out = run(s, inp, 1)
    T.check(not out.pass_on, "13,900 ft: not yet")
    inp.cabin_alt_ft = 14000
    out = run(s, inp, 0.1)
    T.check(out.pass_on and out.pass_on_alert, "14,000 ft: passenger oxygen actuated, PASS OXYGEN ON")
    T.check(out.therap_on and out.therap_memo, "automatic actuation: therapeutic oxygen too, THERAP OXYGEN ON")
    T.check(not out.pass_on_status, "STATUS PASS OXYGEN ON: not at once")
    out = run(s, inp, 59.8)
    T.check(not out.pass_on_status, "STATUS PASS OXYGEN ON: not before 60 s")
    out = run(s, inp, 0.3)
    T.check(out.pass_on_status, "STATUS PASS OXYGEN ON after 60 s (ATA30_32_35_36 p.376)")
    -- the cabin comes down: still on until RESET
    inp.cabin_alt_ft = 13000
    out = run(s, inp, 1)
    T.check(out.pass_on, "13,000 ft: still on (no reset)")
    -- RESET above 12,000 ft does nothing
    inp.pass_sw = -1
    out = run(s, inp, 0.5)
    T.check(out.pass_on, "RESET at 13,000 ft: the units do not reset")
    inp.pass_sw, inp.therap_sw = 0, -1
    out = run(s, inp, 0.5)
    T.check(out.therap_on, "therapeutic RESET at 13,000 ft: does not reset")
    -- below 12,000 ft RESET works
    inp.cabin_alt_ft, inp.therap_sw = 11000, 0
    out = run(s, inp, 1)
    T.check(out.pass_on and out.therap_on, "11,000 ft in NORM: both still on")
    inp.pass_sw = -1
    out = run(s, inp, 0.2)
    T.check(not out.pass_on and not out.pass_on_alert and not out.pass_on_status, "RESET at 11,000 ft: passenger oxygen off, messages cleared")
    T.check(out.therap_on, "passenger RESET: the therapeutic oxygen has its own switch")
    inp.pass_sw, inp.therap_sw = 0, -1
    out = run(s, inp, 0.2)
    T.check(not out.therap_on and not out.therap_memo, "therapeutic RESET at 11,000 ft: off")
end

-- PASS OXYGEN ON by the switch at any altitude (its solenoids: DC power);
-- the therapeutic switch stays at ON (FCOM p.456-457; ATA30_32_35_36 p.368)
do
    local s, inp = M.new(), M.inputs()
    inp.cabin_alt_ft, inp.pass_sw = 7000, 1
    local out = run(s, inp, 0.2)
    T.check(out.pass_on and out.pass_on_alert, "PASS OXYGEN ON at 7,000 ft: actuated")
    T.check(not out.therap_on, "manual passenger ON: the therapeutic oxygen not with it")
    inp.pass_sw = 0
    out = run(s, inp, 1)
    T.check(out.pass_on, "switch back to NORM: still on")
    inp.pass_sw = -1
    out = run(s, inp, 0.2)
    T.check(not out.pass_on, "RESET: off")
    -- no DC: the switch does nothing
    inp.pass_sw, inp.dc = 1, false
    out = run(s, inp, 0.5)
    T.check(not out.pass_on, "no DC: ON does nothing (estimate: the solenoids on DC)")
    inp.dc = true
    out = run(s, inp, 0.2)
    T.check(out.pass_on, "DC back with the switch ON: actuated")
    -- no DC: RESET does nothing either, the aneroid does not need power
    inp.pass_sw, inp.dc = -1, false
    out = run(s, inp, 0.5)
    T.check(out.pass_on, "no DC: RESET does nothing")
    inp.pass_sw = 0
    -- the therapeutic switch ON
    inp.dc, inp.therap_sw = true, 1
    out = run(s, inp, 0.2)
    T.check(out.therap_on and out.therap_memo, "THERAPEUTIC OXYGEN ON: THERAP OXYGEN ON")
    inp.therap_sw = 0
    out = run(s, inp, 0.2)
    T.check(out.therap_on, "THERAPEUTIC back to NORM: still on")
    -- X-Plane's failure: actuated, no reset while it lasts
    local s2, inp2 = M.new(), M.inputs()
    inp2.cabin_alt_ft, inp2.pass_failed_on = 5000, true
    out = run(s2, inp2, 0.2)
    T.check(out.pass_on, "failure: passenger oxygen actuated")
    inp2.pass_sw = -1
    out = run(s2, inp2, 0.5)
    T.check(out.pass_on, "failure: RESET does not hold it off")
    inp2.pass_failed_on = false
    out = run(s2, inp2, 0.2)
    T.check(not out.pass_on, "failure gone: RESET")
end

-- the cylinders' use (estimate) and >CREW OXY LOW at 500 psi
do
    local s, inp = M.new(), M.inputs()
    inp.cabin_alt_ft, inp.pass_sw = 7000, 1
    local out = run(s, inp, 600)
    T.check(out.pass_psi < 1850 - 500 and out.pass_psi > 1850 - 700, "10 min actuated: about 600 psi used (estimate)")
    T.near(out.crew_psi, 1850, 0.5, "no crew mask: the crew cylinder not used")
    inp.crew_masks = true
    out = run(s, inp, 600)
    T.check(out.crew_flow, "crew masks out: oxygen flows")
    T.check(out.crew_psi < 1850 - 20 and out.crew_psi > 1850 - 60, "10 min on the crew masks: about 36 psi used (estimate)")
    s.crew = 520
    out = run(s, inp, 0.1)
    T.check(not out.crew_low_alert, "520 psi: no >CREW OXY LOW")
    s.crew = 500
    inp.crew_masks = false
    out = run(s, inp, 0.1)
    T.check(out.crew_low_alert, "500 psi: >CREW OXY LOW (ATA30_32_35_36 p.340)")
    s.crew = 1000
    inp.cylinder_c = -40
    out = run(s, inp, 0.1)
    T.check(out.crew_psi < 800 and out.crew_low_alert == false, "1000 psi at 70°F, -40°C: about 790 psi")
end

-- the crew masks and the altitude the crew feel (X-Plane's hypoxia; estimate)
do
    local s, inp = M.new(), M.inputs()
    inp.cabin_alt_ft = 30000
    local out = run(s, inp, 0.1)
    T.equal(out.felt_alt_ft, 30000, "30,000 ft without mask: the crew feel 30,000 ft")
    inp.crew_masks = true
    out = run(s, inp, 0.1)
    T.equal(out.felt_alt_ft, 10000, "on the masks: 10,000 ft")
    inp.cabin_alt_ft = 8000
    out = run(s, inp, 0.1)
    T.equal(out.felt_alt_ft, 8000, "on the masks at 8,000 ft: 8,000 ft")
    inp.cabin_alt_ft = 30000
    s.crew = 40
    out = run(s, inp, 0.1)
    T.check(not out.crew_flow, "an empty crew cylinder: no oxygen")
    T.equal(out.felt_alt_ft, 30000, "an empty crew cylinder: the cabin altitude")
end

-- the same over different frame rates
do
    local function after(dt)
        local s, inp = M.new(), M.inputs()
        inp.cabin_alt_ft = 20000
        inp.crew_masks = true
        local out
        for _ = 1, math.floor(120 / dt + 0.5) do out = M.update(s, inp, dt) end
        return out
    end
    local a, b = after(1 / 20), after(1 / 60)
    T.near(a.pass_psi, b.pass_psi, 0.1, "20 and 60 fps: the same passenger pressure")
    T.near(a.crew_psi, b.crew_psi, 0.1, "20 and 60 fps: the same crew pressure")
    T.check(a.pass_on_status == b.pass_on_status, "20 and 60 fps: the same STATUS")
end

T.done()
