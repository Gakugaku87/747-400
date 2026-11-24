-- Run from the repository root with LuaJIT: luajit tests/fms/thrlim_model_test.lua
-- The FMC's thrust limit mode (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.thrlim_model.lua; 6-1/6-2 step 9g1, notes/
-- ATA-34-61-FMC.md §73): TO on the ground with the THRUST LIM page's
-- rating and the climb armed by the takeoff's reduction (FCOM p.1273,
-- p.1315-1316; every airplane: 2026-11-24, review FMC-1, §179); the armed climb at the thrust reduction point with VNAV
-- (flaps 5 or a height: FCOM p.667), by the THR switch above 400 ft with
-- VNAV or FLCH (p.642), the derate gone with a TO/GA push before it
-- (p.667); VNAV's phase (the T/C's CRZ: ATA34_2 p.536), FLCH up from CRZ
-- (FCOM p.646); GA with the flaps extended, the landing flaps or G/S, held
-- there (p.672), the THR switch's CLB or CON after it (p.642), VNAV's
-- phase; the page's selections in the air (p.1339); an air start's CLB.
-- Step 9h3 (§79): with an engine inoperative the reduction inhibited and
-- CON at VREF + 98 with VNAV and the flaps up (p.1266, p.1272), the THR
-- switch's and FLCH's CON (p.642, p.646), CON kept through VNAV's phases.
local T = dofile("tests/lib/check.lua")("thrlim_model")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.thrlim_model.lua")

local base = {ground = false, alt_agl = 2000, thr_red = 5, flaps = 0, gs = false, vnav = false, phase = "CLB",
    flch_up = false, thr = false, toga = false, ra = 2000}
local function inp(t)
    local i = {}
    for k, v in pairs(base) do i[k] = v end
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
local F10, F5, F20, F30 = 3 / 6, 2 / 6, 4 / 6, 1

-- on the ground: TO; TO 1 (8 %) arms CLB 1, TO 2 (20 %) CLB 2, TO CLB;
-- a climb's chosen on the ground over the automatic one
local s = L.new()
T.equal(L.update(s, inp{ground = true, flaps = F10}), "TO", "on the ground: TO (ATA34_2 p.535)")
T.check(L.select_to(s, 1, 8, true) and s.clb == 1, "TO 1 of 8 %: CLB 1 armed (5 to under 15 %: FCOM p.1273)")
T.equal(L.update(s, inp{ground = true, flaps = F10}), "TO 1", "TO 1")
L.select_to(s, 2, 20, true)
T.check(s.to == 2 and s.clb == 2, "TO 2 of 20 %: CLB 2 armed (15 % or more)")
L.select_to(s, 0, 0, true)
T.equal(s.clb, 0, "TO: CLB armed (under 5 %)")
T.check(L.select_clb(s, 2, true) and s.clb == 2 and L.update(s, inp{ground = true}) == "TO", "CLB 2 chosen on the ground: armed, TO still")
L.select_to(s, 1, 8, true)
T.equal(s.clb, 2, "then TO 1: the crew's CLB 2 kept (FCOM p.1316)")
T.check(not L.select_to(s, 0, 0, false), "TO in the air: not taken")

-- the takeoff: TO 1, flaps 10, THR REDUCTION flaps 5; VNAV engaged at 400
-- ft: TO 1 still; the flaps at 5: CLB 1 (the armed climb: FCOM p.667)
s = L.new()
L.select_to(s, 1, 8, true)
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 500, ra = 500, flaps = F10, vnav = true}), "TO 1", "400 ft with VNAV, flaps 10: TO 1")
T.check(L.select_clb(s, 2, false) and s.clb == 2 and L.update(s, inp{alt_agl = 600, ra = 600, flaps = F10, vnav = true}) == "TO 1",
    "(step 9g2) CLB 2 in the air while TO 1 is active: armed (ATA34_2 p.536)")
T.equal(L.update(s, inp{alt_agl = 1500, ra = 1500, flaps = F5, vnav = true}), "CLB 2", "the flaps at 5 with VNAV: the armed CLB 2")
-- THR REDUCTION 1,500 ft: at 1,500 ft above the airport with VNAV
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1400, flaps = F5, thr_red = 1500, vnav = true}), "TO", "1,400 ft (THR REDUCTION 1,500): TO")
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F5, thr_red = 1500, vnav = true}), "CLB", "1,500 ft: CLB")
-- without VNAV: TO at flaps 5; the THR switch with FLCH above 400 ft: CLB
-- (FCOM p.642); a TO/GA push before it: TO 1's derate gone (FCOM p.667)
s = L.new()
L.select_to(s, 1, 8, true)
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F5}), "TO 1", "without VNAV at flaps 5: TO 1 still")
T.equal(L.update(s, inp{alt_agl = 1600, flaps = F5, toga = true}), "TO", "a TO/GA push before the climb's: TO (the derate gone)")
T.equal(L.update(s, inp{alt_agl = 1700, flaps = F5, thr = true, pitch = "TO"}), "TO", "the THR switch in T/O's pitch: TO still")
T.equal(L.update(s, inp{alt_agl = 1800, flaps = F5, thr = true, pitch = "FLCH", ra = 300}), "TO", "under 400 ft RA: TO still")
T.equal(L.update(s, inp{alt_agl = 1900, flaps = F5, thr = true, pitch = "FLCH"}), "CLB 1", "with FLCH above 400 ft: CLB 1 (the armed)")

-- VNAV's phase: at the T/C CRZ (ATA34_2 p.536); a cruise climb CLB; FLCH
-- to a higher altitude from CRZ: CLB (FCOM p.646); the page's selections
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
L.update(s, inp{alt_agl = 1500, flaps = F5, vnav = true})
T.equal(L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ"}), "CRZ", "the T/C with VNAV: CRZ")
T.equal(L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CLB"}), "CLB", "a cruise climb: CLB")
L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ"})
T.equal(L.update(s, inp{alt_agl = 30000, phase = "CRZ", flch_up = true}), "CLB", "FLCH up from CRZ: CLB")
T.check(L.select(s, "CON"), "CON selected")
T.equal(L.update(s, inp{alt_agl = 30000, phase = "CRZ"}), "CON", "CON")
T.check(L.select_clb(s, 2, false) and L.update(s, inp{alt_agl = 30000, phase = "CRZ"}) == "CLB 2", "CLB 2 selected in the air: active")

-- (step 12c1) PERF FACTORS' THR/CRZ CLB: the T/C in CLB, the full climb's
-- (FMSPG p.267; FCOM p.1273)
s = L.new()
L.select_clb(s, 1, true)
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F5, vnav = true, crz_clb = true}), "CLB 1", "THR/CRZ CLB: the climb's CLB 1 as before")
T.equal(L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ", crz_clb = true}), "CLB", "THR/CRZ CLB: the T/C CLB, not CLB 1")
T.equal(L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ", crz_clb = true}), "CLB", "kept in the cruise")
T.equal(L.update(s, inp{alt_agl = 30000, phase = "CRZ", flch_up = true, crz_clb = true}), "CLB", "FLCH up: CLB still")

-- (2026-11-14) THR/CRZ CRZ (P&W's default): the climb's derate ends at the
-- T/C too, so a later cruise climb (VNAV's CLB phase to the new CRZ ALT) is
-- in the full climb's, and back in CRZ at the new CRZ ALT (ATA34_2 p.664)
s = L.new()
L.select_clb(s, 2, true)
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F5, vnav = true}), "CLB 2", "THR/CRZ CRZ: the climb's CLB 2")
T.equal(L.update(s, inp{alt_agl = 31000, vnav = true, phase = "CRZ"}), "CRZ", "the T/C: CRZ")
T.equal(L.update(s, inp{alt_agl = 31000, vnav = true, phase = "CLB"}), "CLB", "a cruise climb: CLB, not CLB 2 (before, the takeoff's CLB 2 came back)")
T.equal(L.update(s, inp{alt_agl = 33000, vnav = true, phase = "CRZ"}), "CRZ", "at the new CRZ ALT: CRZ again")
T.equal(L.update(s, inp{alt_agl = 33000, phase = "CRZ", flch_up = true}), "CLB", "FLCH up from CRZ: CLB (FCOM p.646), not CLB 2")

-- GA: the flaps extended out of UP (FCOM p.672); the THR switch: CLB; the
-- landing flaps, G/S: GA held (the THR switch, a selection nothing);
-- flaps 20 again: the THR switch CLB, CON if CON was selected (p.642)
s = L.new()
L.update(s, inp{alt_agl = 8000})
T.equal(L.update(s, inp{alt_agl = 8000}), "CLB", "an air start: CLB (estimate)")
T.equal(L.update(s, inp{alt_agl = 5000, flaps = 1 / 6}), "GA", "flaps 1 out of UP: GA")
T.equal(L.update(s, inp{alt_agl = 5000, flaps = 1 / 6, thr = true, pitch = "VNAV"}), "CLB", "the THR switch: CLB")
T.equal(L.update(s, inp{alt_agl = 4000, flaps = F30}), "GA", "the landing flaps: GA")
T.equal(L.update(s, inp{alt_agl = 4000, flaps = F30, thr = true}), "GA", "held: the THR switch nothing")
T.check(not L.select(s, "CON") and not L.select_clb(s, 0, false), "held: the page's selections nothing")
T.equal(L.update(s, inp{alt_agl = 2000, flaps = F20, gs = true}), "GA", "G/S at flaps 20: GA held")
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20, thr = true}), "CLB", "flaps 20 without G/S (a go-around): the THR switch CLB")
L.update(s, inp{alt_agl = 1500, flaps = F30})
L.update(s, inp{alt_agl = 1500, flaps = F20})
T.check(L.select(s, "CON") and L.update(s, inp{alt_agl = 1500, flaps = F20}) == "CON", "flaps 20: CON selected")
L.update(s, inp{alt_agl = 1500, flaps = F30})
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20, thr = true}), "CON", "after GA with CON selected: the THR switch CON")
-- the missed approach (step 9e3): GA in the descent stays as VNAV engages;
-- VNAV with the FMC's climb: CLB
s = L.new()
L.update(s, inp{alt_agl = 3000, vnav = true, phase = "DES"})
L.update(s, inp{alt_agl = 3000, vnav = true, phase = "DES", flaps = F5})
T.equal(L.update(s, inp{alt_agl = 2000, vnav = true, phase = "DES", flaps = F5}), "GA", "the approach with VNAV, flaps 5: GA")
T.equal(L.update(s, inp{alt_agl = 2200, phase = "CLB", flaps = F5}), "GA", "the go-around (VNAV off), the FMC's climb: GA")
T.equal(L.update(s, inp{alt_agl = 2500, vnav = true, phase = "CLB", flaps = F5}), "CLB", "VNAV engaged in the FMC's climb: CLB")
-- (step 9g3) D-: an assumed temperature over the OAT on TO (FCOM p.1314);
-- a TO/GA push before the climb's removes it with the derate (p.667); the
-- climb's by the takeoff's whole reduction on the ground (the EEC's)
s = L.new()
L.select_to(s, 1, 8, true)
T.equal(L.update(s, inp{ground = true, flaps = F10, sel_up = true, to_red = 27}), "D-TO 1", "SEL over the OAT with TO 1: D-TO 1")
T.equal(s.clb, 2, "27 % less thrust in all: CLB 2 armed (15 % or more)")
T.equal(L.update(s, inp{alt_agl = 500, flaps = F10, sel_up = true}), "D-TO 1", "in the air: D-TO 1")
T.equal(L.update(s, inp{alt_agl = 600, flaps = F10, sel_up = true, toga = true}), "TO", "a TO/GA push: TO (the derate and D- gone)")
T.equal(L.update(s, inp{alt_agl = 700, flaps = F10, sel_up = true}), "TO", "and stays TO")
-- (2026-11-24, review FMC-1) every airplane by the takeoff's whole
-- reduction (FCOM p.1273 (11.32.3): the paragraph has no effectivity, rule
-- 2 of p.11 (0.2.5); p.1315 (11.40.39)'s "Selecting TO 1 arms CLB 1" too).
-- From 2026-11-19 to this day the 405 and 570 (the input by_rating: a
-- freighter or GE) armed by the rating alone; the input is passed here as
-- the old glue did and must change nothing. GE's default derates 5/15 %
s = L.new()
T.equal(L.update(s, inp{ground = true, flaps = F10, by_rating = true, to_red = 0}), "TO", "a freighter/GE on the ground: TO")
T.check(L.select_to(s, 1, 5, true) and s.clb == 1, "GE's TO 1 of 5 %: CLB 1 armed (5 to under 15 %)")
L.select_to(s, 2, 15, true)
T.equal(s.clb, 2, "GE's TO 2 of 15 %: CLB 2 armed")
L.select_to(s, 1, 20, true)
T.equal(s.clb, 2, "TO 1 of 20 % (the operator's): CLB 2 (15 % or more), not the rating's CLB 1")
L.select_to(s, 0, 0, true)
T.equal(s.clb, 0, "TO: CLB")
T.equal(L.update(s, inp{ground = true, flaps = F10, by_rating = true, sel_up = true, to_red = 20}), "D-TO", "SEL over the OAT with TO: D-TO")
T.equal(s.clb, 2, "D-TO of 20 % less thrust: CLB 2 on a freighter/GE too (FCOM p.1273)")
T.equal(L.update(s, inp{ground = true, flaps = F10, by_rating = true, sel_up = true, to_red = 10}), "D-TO", "D-TO of 10 %")
T.equal(s.clb, 1, "D-TO of 10 %: CLB 1")
L.select_to(s, 1, 5, true)
T.equal(L.update(s, inp{ground = true, flaps = F10, by_rating = true, sel_up = true, to_red = 22}), "D-TO 1", "D-TO 1")
T.equal(s.clb, 2, "D-TO 1 of 22 % in all (the P&W freighter's 8 % and SEL): CLB 2")
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F5, vnav = true, by_rating = true}), "CLB 2", "the flaps at 5 with VNAV: the armed CLB 2")
s = L.new()
L.update(s, inp{ground = true, flaps = F10, by_rating = true, to_red = 0})
L.select_clb(s, 1, true)
L.select_to(s, 2, 15, true)
T.check(s.clb == 1 and L.update(s, inp{ground = true, flaps = F10, by_rating = true, to_red = 15}) == "TO 2" and s.clb == 1,
    "the crew's CLB 1 kept over TO 2's (FCOM p.1273: overridden after the takeoff's selection; p.1316)")
s = L.new()
L.update(s, inp{ground = true, flaps = F10, sel_up = true, to_red = 20})
T.equal(s.clb, 2, "without the input: D-TO of 20 % CLB 2 (FCOM p.1273)")
-- (step 9h3) an engine inoperative: failed in TO, the thrust reduction
-- inhibited; CON with VNAV and the flaps up at VREF + 98 (FCOM p.1266,
-- p.1272); the THR switch CON (p.642)
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 300, flaps = F10, eo = 1, ias = 180, vref = 150}), "TO", "an engine failed in TO: TO")
T.equal(L.update(s, inp{alt_agl = 1600, flaps = F5, vnav = true, eo = 1, ias = 200, vref = 150}), "TO",
    "flaps 5 (the thrust reduction point) with VNAV: TO kept (the reduction inhibited)")
T.equal(L.update(s, inp{alt_agl = 2500, flaps = 0, vnav = true, eo = 1, ias = 247, vref = 150}), "TO", "flaps up at VREF + 97: TO")
T.equal(L.update(s, inp{alt_agl = 2600, flaps = 0, vnav = true, eo = 1, ias = 248, vref = 150}), "CON", "flaps up at VREF + 98 with VNAV: CON")
T.equal(L.update(s, inp{alt_agl = 2700, flaps = 0, vnav = true, eo = 1, ias = 250, vref = 150, phase = "CRZ"}), "CON",
    "VNAV's phase to CRZ with the engine out: CON kept (estimate)")
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
L.update(s, inp{alt_agl = 300, flaps = F10, eo = 1, ias = 180, vref = 150})
T.equal(L.update(s, inp{alt_agl = 600, flaps = F10, eo = 1, ias = 260, vref = 150}), "TO", "VREF + 110 with the flaps out, no VNAV: TO")
T.equal(L.update(s, inp{alt_agl = 700, flaps = F10, eo = 1, pitch = "FLCH", thr = true, ra = 700}), "CON",
    "the THR switch with FLCH after takeoff, an engine out: CON (FCOM p.642)")
-- failed above the thrust reduction: the climb's kept (FCOM p.1266)
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1600, flaps = F5, vnav = true}), "CLB", "the thrust reduction with VNAV: CLB")
T.equal(L.update(s, inp{alt_agl = 3000, flaps = 0, vnav = true, eo = 1, ias = 260, vref = 150}), "CLB",
    "an engine failed above the reduction: CLB kept")
-- FLCH pushed to a higher altitude with an engine out: CON (FCOM p.646);
-- the crew's CLB after it kept while FLCH stays
T.equal(L.update(s, inp{alt_agl = 3000, eo = 1, pitch = "FLCH", flch_up = true}), "CON", "FLCH up with an engine out: CON")
L.select_clb(s, 0, false)
T.equal(L.update(s, inp{alt_agl = 3100, eo = 1, pitch = "FLCH", flch_up = true}), "CLB", "CLB chosen during FLCH: kept")
L.update(s, inp{alt_agl = 3200, eo = 1, pitch = "VS"})
T.equal(L.update(s, inp{alt_agl = 3300, eo = 1, pitch = "FLCH", flch_up = true}), "CON", "FLCH pushed again: CON")
s = L.new()
L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ"})
T.equal(L.update(s, inp{alt_agl = 30000, phase = "CRZ", pitch = "FLCH", flch_up = true}), "CLB", "all engines: FLCH up from CRZ CLB, as before")
-- after GA the THR switch: CON with an engine out (FCOM p.642)
s = L.new()
L.update(s, inp{alt_agl = 1500, flaps = 0})
L.update(s, inp{alt_agl = 1500, flaps = F20})
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20}), "GA", "flaps out: GA")
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20, thr = true, eo = 1}), "CON", "after GA the THR switch with an engine out: CON")
-- (step 9h4a) the engine-out VNAV active (ENG OUT executed) with all
-- engines running: CON kept through VNAV's phases, FLCH pushed CON; in TO
-- not (the sensed failure only)
s = L.new()
L.update(s, inp{alt_agl = 20000, vnav = true, phase = "CLB"})
L.select(s, "CON")
T.equal(L.update(s, inp{alt_agl = 25000, vnav = true, phase = "CRZ", eo_vnav = true}), "CON", "E/O VNAV active: CON through the T/C")
L.select_clb(s, 0, false)
T.equal(L.update(s, inp{alt_agl = 25000, eo_vnav = true, pitch = "FLCH", flch_up = true}), "CON", "FLCH pushed with E/O VNAV: CON")
s = L.new()
L.update(s, inp{ground = true, flaps = F10})
T.equal(L.update(s, inp{alt_agl = 1600, flaps = F5, vnav = true, eo_vnav = true}), "CLB", "E/O VNAV executed before the takeoff, all engines: the reduction to CLB as usual")

-- (2026-11-24, review FMC-7 (c)) a flight without VNAV and the THR switch
-- stays on the takeoff's limit; GA's conditions from TO too (FCOM p.672
-- (4.20.14): the flaps out of UP, the landing flaps, G/S). Before, TO
-- returned ahead of them and TO stayed into the approach
local function takeoff(n)
    local t = L.new()
    L.select_to(t, n or 1, 8, true)
    L.update(t, inp{ground = true, flaps = F20, ra = 0, ias = 0})
    L.update(t, inp{alt_agl = 1500, flaps = F20, ra = 1500})
    return t
end
s = takeoff()
T.equal(L.update(s, inp{alt_agl = 5000, flaps = 0, ra = 5000}), "TO 1", "no VNAV, no THR switch, the flaps up: TO 1 still (FCOM p.667)")
T.equal(L.update(s, inp{alt_agl = 3000, flaps = 1 / 6, ra = 3000}), "GA", "TO, the flaps out of UP: GA (it was TO 1)")
s = takeoff()
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F30, ra = 1500}), "GA", "TO, the landing flaps: GA, held")
T.check(s.locked, "held at the landing flaps")
s = takeoff()
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20, gs = true, ra = 1500}), "GA", "TO, G/S captured: GA")
s = takeoff()
T.equal(L.update(s, inp{alt_agl = 1500, flaps = F20, ra = 1500}), "TO 1", "TO at the takeoff's flaps (not out of UP): TO 1, as before")
-- (FMC-7 (a)) GA through a touchdown while the airplane rolls at 30 kt or
-- more (a go-around with the wheels on the runway, a touch and go: FCOM
-- p.672, p.673; estimate); then (FMC-7 (b)) TO without the takeoff's
-- derate and assumed temperature (estimate). Before, TO 1 with D- at once
s = takeoff()
L.update(s, inp{alt_agl = 5000, flaps = 0, ra = 5000})
L.update(s, inp{alt_agl = 1500, flaps = F30, ra = 1500})
T.equal(L.update(s, inp{ground = true, flaps = F30, ra = 0, ias = 140, sel_up = true}), "GA", "the touchdown at 140 kt: GA kept")
T.equal(L.update(s, inp{alt_agl = 20, flaps = F20, ra = 20, ias = 150}), "GA", "a touch and go's lift-off: GA (THR at TO/GA: FCOM p.673)")
T.check(not s.locked, "at flaps 20 off the ground: no longer held")
L.update(s, inp{alt_agl = 1500, flaps = F30, ra = 1500})
T.equal(L.update(s, inp{ground = true, flaps = F30, ra = 0, ias = 31, sel_up = true}), "GA", "the rollout at 31 kt: GA")
T.equal(L.update(s, inp{ground = true, flaps = F30, ra = 0, ias = 29, sel_up = true}), "TO", "under 30 kt: TO, not the takeoff's D-TO 1")
T.check(s.to == 0 and s.no_sel and not s.d, "the takeoff's TO 1 and its assumed temperature gone")
T.equal(L.update(s, inp{ground = true, flaps = 0, ra = 0, ias = 0, sel_up = true}), "TO", "and so while it stands (the SEL still entered)")
L.select_to(s, 1, 8, true)
T.equal(L.update(s, inp{ground = true, flaps = F20, ra = 0, ias = 0, sel_up = true}), "D-TO 1", "a new TO 1 for the next takeoff: D-TO 1 again")
s = takeoff()
L.update(s, inp{alt_agl = 30000, vnav = true, phase = "CRZ", ra = 30000})
T.equal(L.update(s, inp{ground = true, flaps = F30, ra = 0, ias = 140, sel_up = true}), "TO", "landing out of CRZ (not GA): TO at once, the takeoff's derate and D- gone")
-- a frame off the ground as the airplane is loaded is no flight (50 ft)
s = L.new()
L.select_to(s, 1, 8, true)
L.update(s, inp{alt_agl = 0, flaps = F20, ra = 0})
T.equal(L.update(s, inp{ground = true, flaps = F20, ra = 0, ias = 0, sel_up = true}), "D-TO 1", "a frame in the air at 0 ft: TO 1's D- kept")
T.done()
