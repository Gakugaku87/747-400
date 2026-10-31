-- Run from the repository root with LuaJIT: luajit tests/fms/thrlim_model_test.lua
-- The FMC's thrust limit mode (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.thrlim_model.lua; 6-1/6-2 step 9g1, notes/
-- ATA-34-61-FMC.md §73): TO on the ground with the THRUST LIM page's
-- rating and the climb armed by the takeoff's reduction (FCOM p.1273,
-- p.1315-1316); the armed climb at the thrust reduction point with VNAV
-- (flaps 5 or a height: FCOM p.667), by the THR switch above 400 ft with
-- VNAV or FLCH (p.642), the derate gone with a TO/GA push before it
-- (p.667); VNAV's phase (the T/C's CRZ: ATA34_2 p.536), FLCH up from CRZ
-- (FCOM p.646); GA with the flaps extended, the landing flaps or G/S, held
-- there (p.672), the THR switch's CLB or CON after it (p.642), VNAV's
-- phase; the page's selections in the air (p.1339); an air start's CLB.
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
T.equal(L.update(s, inp{alt_agl = 1500, ra = 1500, flaps = F5, vnav = true}), "CLB 1", "the flaps at 5 with VNAV: CLB 1")
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
T.done()
