-- Run from the repository root with LuaJIT: luajit tests/nav/ra_model_test.lua
-- The radio altimeter model (plugins/xtlua/scripts/B747.34.xt.nav/
-- B747.34.ra_model.lua, 5-1 step 4) without X-Plane: power and failures,
-- each PFD's source by its EIU selector, the RA flag, no computed data above
-- 2,500 ft, the GPWC's comparison. Sources: ATA34_2 p.88-89, p.95-96, p.122.
local T = dofile("tests/lib/check.lua")("ra_model")
local R = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.ra_model.lua")

local s, inp = R.new(), R.inputs()
local out
local function run() out = R.update(s, inp) end
inp.height = {500, 510, 520}
run()
T.equal(out.capt.src, 1, "Captain AUTO: L")
T.equal(out.fo.src, 3, "F/O AUTO: R")
T.check(out.capt.show and not out.capt.flag, "digits shown, no flag")
T.equal(out.capt.value, 500, "the L radio altitude")
T.equal(out.fo.value, 520, "the R radio altitude")

-- the EIU selectors (p.88-89)
inp.eiu_capt, inp.eiu_fo = "C", "C"
run()
T.check(out.capt.src == 2 and out.fo.src == 2, "C on both: C")
inp.eiu_capt, inp.eiu_fo = "R", "L"
run()
T.check(out.capt.src == 3 and out.fo.src == 1, "Captain R: R, F/O L: L")
inp.eiu_capt, inp.eiu_fo = "AUTO", "AUTO"

-- failures: the next one in the order takes over
inp.fail[1] = true
run()
T.equal(out.capt.src, 2, "L failed: the Captain's AUTO takes C")
T.equal(out.fo.src, 3, "the F/O keeps R")
inp.power[2] = false
run()
T.equal(out.capt.src, 3, "L failed, C unpowered: R")
inp.fail[3] = true
run()
T.check(out.capt.flag and not out.capt.show and not out.capt.valid, "none working: the RA flag (p.96)")
T.check(out.fo.flag, "the F/O's too")
inp.fail = {false, false, false}
inp.power = {true, true, true}
inp.eiu_capt = "C"
inp.fail[2] = true
run()
T.equal(out.capt.src, 1, "Captain C with C failed: C-L-R gives L")
inp.eiu_capt = "R"
inp.fail[2], inp.fail[3] = false, true
run()
T.equal(out.capt.src, 1, "Captain R with R failed: R-L-C gives L")
inp.eiu_fo = "C"
inp.fail[3], inp.fail[2] = false, true
run()
T.equal(out.fo.src, 3, "F/O C with C failed: C-R-L gives R")
inp.fail = {false, false, false}
inp.eiu_capt, inp.eiu_fo = "AUTO", "AUTO"

-- no computed data above 2,500 ft; not below -20 ft
inp.height = {2600, 2600, 2600}
run()
T.check(out.capt.valid and not out.capt.show and not out.capt.flag, "above 2,500 ft: blank, no flag (p.96)")
T.check(out.ncd[1], "no computed data")
inp.height = {-40, -40, -40}
run()
T.equal(out.capt.value, -20, "not below -20 ft (p.95)")
T.check(out.capt.show, "shown on the ground")

-- the GPWC (34-46 p.122)
inp.height = {1000, 1200, 1900}
run()
T.equal(out.gpwc.src, 1, "L agrees with C: L")
inp.height = {1000, 1900, 1950}
run()
T.equal(out.gpwc.src, 2, "L disagrees with both, C agrees with R: C")
inp.height = {1000, 1600, 2200}
run()
T.equal(out.gpwc.src, 1, "no two agree: L")
inp.fail[1] = true
run()
T.equal(out.gpwc.src, 2, "L failed and C, R disagree: the first one working, C (estimate)")
inp.fail = {true, true, true}
run()
T.check(not out.gpwc.valid, "none working: the GPWC has no radio altitude")
T.done()
