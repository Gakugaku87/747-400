-- Run from the repository root with LuaJIT: luajit tests/fms/crz_model_test.lua
-- The cruise page's step climb (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.crz_model.lua; 6-1/6-2 step 8b2, notes/
-- ATA-34-61-FMC.md §46): the direction from the cruise altitude before
-- takeoff, ICAO's STEP TO above OPT (FCOM p.1349, FMSPG p.133), a step
-- size's, none; the optimum step point's weight (FCOM p.1257).
local T = dofile("tests/lib/check.lua")("crz_model")
local C = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.crz_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

-- the direction
T.check(C.east(29000) and C.east(33000) and C.east(37000) and C.east(41000) and C.east(27000), "east: FL270, 290, 330, 370, 410")
T.check(not C.east(28000) and not C.east(31000) and not C.east(35000) and not C.east(39000), "west: FL280, 310, 350, 390")
T.check(not C.east(32000) and not C.east(34000), "FL320, FL340 (RVSM's even levels): west (an estimate)")
T.check(C.east(33200), "33,200 ft: its thousand, FL330's: east")

-- ICAO: the FCOM's and the FMS pilot's guide's examples
T.equal(C.step_to(28000, 33700, "ICAO", C.east(28000)), 35000, "FL280 before takeoff, OPT FL337: FL350 (FCOM p.1349)")
T.equal(C.step_to(31000, 31100, "ICAO", C.east(31000)), 35000, "FL310, OPT FL311: FL350 (FMSPG p.133)")
T.equal(C.step_to(35000, 33700, "ICAO", C.east(28000)), nil, "CRZ ALT FL350 above OPT FL337: no step (FL350 is not above it)")
T.equal(C.step_to(35000, 36000, "ICAO", false), 39000, "west, OPT FL360 from FL350: FL390")
T.equal(C.step_to(33000, 33500, "ICAO", true), 37000, "east, OPT FL335 from FL330: FL370")
T.equal(C.step_to(25000, 26200, "ICAO", true), 27000, "below FL290 every 2,000 ft: east OPT FL262 from FL250: FL270")
T.equal(C.step_to(41000, 44000, "ICAO", true), 45000, "east OPT FL440: FL450")
T.equal(C.step_to(43000, 44000, "ICAO", false), nil, "west OPT FL440: FL470 is above the ceiling: none")
-- a step size
T.equal(C.step_to(33000, 34500, "2000", true), 35000, "2000 ft from FL330, OPT FL345: FL350")
T.equal(C.step_to(33000, 35500, 2000, true), 37000, "OPT FL355: FL370 (the first above OPT)")
T.equal(C.step_to(33000, 33000, 4000, true), 37000, "OPT at CRZ ALT: one step")
T.equal(C.step_to(33000, 36000, 0, true), nil, "size 0: constant altitude (FCOM p.1312)")

-- the optimum step point: the weight where OPT is halfway (PW, PI.11.1's OPT)
local pw = P.tables(0)
local function opt(kg) return P.opt_alt(pw, kg) end
local w = C.step_weight(35000, 39000, opt, 180000, 330000)
T.near(opt(w), 37000, 1, "FL350 to FL390: where OPT is FL370")
T.check(w > 240000 and w < 260000, string.format("at %.0f t (OPT FL386 at 240 t, FL369 at 260 t)", w / 1000))
T.equal(C.step_weight(35000, 39000, opt, 180000, 250000), 250000, "250 t (OPT above FL370 already): now, the weight as it is")
T.equal(C.step_weight(43000, 47000, opt, 180000, 300000), 180000, "OPT never at FL450: the lightest")

T.done()
