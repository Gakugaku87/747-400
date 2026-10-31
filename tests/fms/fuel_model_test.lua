-- Run from the repository root with LuaJIT: luajit tests/fms/fuel_model_test.lua
-- The FMC's fuel monitoring (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/
-- B747.68.fuel_model.lua; 6-1/6-2 step 11a, notes/ATA-34-61-FMC.md §90;
-- FCOM p.1273-1274, p.1310, p.1378-1382, p.1432): CALCULATED before and
-- after the start, FUEL USED, MANUAL, a leak's FUEL DISAGREE and the USE
-- choices, the jettison, the shutdown, INSUFFICIENT FUEL.
local T = dofile("tests/lib/check.lua")("fuel_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.fuel_model.lua")

local s = M.new()
local used = {100, 100, 100, 100, 400}       -- the fuel system's totaliser since the load
local inp = {fqis = 150000, used = used, ff = {0, 0, 0, 0}}
local o = M.update(s, inp)
T.check(o.calc == 150000 and o.source == "CALC" and o.fmc == 150000, "before the start: the totalizer's, CALC")
T.check(o[5] == 400, "FUEL USED before any start: the totaliser's")

-- the start: FUEL USED from zero, CALCULATED the quantity at the start less it
inp.ff = {1, 1, 1, 1}
o = M.update(s, inp)
T.check(o[5] == 0 and o.calc == 150000, "the start: FUEL USED 0, CALCULATED 150 t")
for n = 1, 4 do used[n] = used[n] + 2500 end
used[5] = used[5] + 10000
inp.fqis = 140000
o = M.update(s, inp)
T.check(o[1] == 2500 and o[5] == 10000 and o.calc == 140000 and not o.disagree, "10 t burnt: FUEL USED 2.5 t each, 10 t, CALCULATED 140 t")

-- a leak: the totalizer 5 t lower, FUEL DISAGREE and the prompts
inp.fqis = 135000
o = M.update(s, inp)
T.check(o.disagree and o.calc == 140000 and o.fqis == 135000, "5 t apart (4,080 kg or more): FUEL DISAGREE")
T.check(M.choose(s, "TOTALIZER"), "USE TOTALIZER")
o = M.update(s, inp)
T.check(o.source == "SENSED" and o.fmc == 135000 and not o.show_calc and o.show_totalizer and not o.disagree,
    "SENSED: the totalizer's, CALCULATED and FUEL USED blank (FCOM p.1381)")
T.equal(M.enter(s, 120000, inp.fqis, used), false, "no entry when SENSED (FCOM p.1310)")

-- the shutdown: back to the totalizer, the choice gone, FUEL USED kept
inp.ff = {0, 0, 0, 0}
o = M.update(s, inp)
T.check(o.source == "CALC" and o.calc == 135000 and o[5] == 10000, "shut down: CALC, the totalizer's, FUEL USED kept")
T.check(not M.choose(s, "CALCULATED"), "no choice without the disagreement")

-- MANUAL before the next start: the entry, down with the flow from the start
T.check(M.enter(s, 130000, inp.fqis, used), "130 t entered")
o = M.update(s, inp)
T.check(o.source == "MANUAL" and o.calc == 130000 and not o.show_totalizer, "MANUAL 130 t, TOTALIZER blank (FCOM p.1378)")
inp.ff = {1, 1, 1, 1}
o = M.update(s, inp)
T.equal(o[5], 0, "the next start: FUEL USED from zero")
used[5] = used[5] + 4000
o = M.update(s, inp)
T.check(o.calc == 126000 and o.source == "MANUAL", "MANUAL less the flow: 126 t")
T.check(o.disagree, "the totalizer's 135 t and 126 t: FUEL DISAGREE")
T.check(M.choose(s, "CALCULATED"), "USE CALCULATED")
o = M.update(s, inp)
T.check(o.fmc == 126000 and not o.disagree and o.show_calc, "the calculated kept, no message again (estimate)")
T.check(M.enter(s, nil, inp.fqis, used), "DELETE of the entry")
o = M.update(s, inp)
T.check(o.source == "CALC" and o.calc == 135000, "back to CALC from the totalizer's (estimate)")
T.equal(M.enter(s, nil, inp.fqis, used), false, "DELETE without an entry: not allowed")

-- a jettison: the totalizer's, then down from its end
inp.jett, inp.fqis = true, 120000
o = M.update(s, inp)
T.equal(o.calc, 120000, "during the jettison: the totalizer's")
inp.jett = false
used[5] = used[5] + 1000
o = M.update(s, inp)
T.equal(o.calc, 119000, "after it: from its end less the flow")

-- INSUFFICIENT FUEL
inp.pred_dest, inp.reserves = 8000, 10000
o = M.update(s, inp)
T.check(o.insufficient, "8 t predicted at the destination, RESERVES 10 t: INSUFFICIENT FUEL")
inp.pred_dest = 12000
o = M.update(s, inp)
T.check(not o.insufficient, "12 t: none")
T.done()
