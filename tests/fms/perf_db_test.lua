-- Run from the repository root with LuaJIT: luajit tests/fms/perf_db_test.lua
-- The FMC's performance database (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.perf_db.lua; 6-1/6-2 step 8a, notes/ATA-34-61-FMC.md
-- §44) against the FCOM PI tables: PW4056 (PI.11, p.267-273) and
-- CF6-80C2B1F (the 747-400F's PI.21, p.363-369, in lb): the table's cells,
-- between them, at their ends; RR uses the PW tables (an estimate).
local T = dofile("tests/lib/check.lua")("perf_db")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

local pw, ge = P.tables(0), P.tables(1)
local KLB = 1000 * P.LB
T.check(P.tables(2) == pw, "RR: the PW tables (no source: an estimate)")

-- long range cruise control, PI.11.2 (p.268): 300 t at FL350 1.25, .861,
-- 295 kt, 2554 kg/h; between 320 t and 300 t, FL330 and FL350
local m, kias, ff, epr = P.lrc(pw, 300000, 35000)
T.check(m == .861 and kias == 295 and ff == 2554 and epr == 1.25, "PW LRC 300 t FL350: .861, 295 kt, 2554 kg/h, EPR 1.25")
m, kias, ff = P.lrc(pw, 310000, 34000)
T.near(m, (.859 + .861 + .850 + .861) / 4, 1e-9, "310 t FL340: the four cells' mean Mach")
T.near(ff, (2731 + 2743 + 2555 + 2554) / 4, 1e-9, "and fuel flow")
m, kias = P.lrc(pw, 400000, 41000)
T.check(m == .861 and kias == 322, "400 t at FL410: its highest altitude in the table, FL310")
m = P.lrc(pw, 450000, 27000)
T.equal(m, .852, "450 t: the heaviest row (400 t)")
m, kias, ff = P.lrc(pw, 200000, 20000)
T.check(m == .706 and ff == 1850, "200 t at FL200: the lowest altitude (FL270)")
-- GE: 720,000 lb at FL330 92.2 %N1, .850, 304 kt, 5967 lb/h
m, kias, ff, n1 = P.lrc(ge, 720 * KLB, 33000)
T.check(m == .850 and kias == 304 and n1 == 92.2, "GE LRC 720 klb FL330: .850, 304 kt, N1 92.2")
T.near(ff, 5967 * P.LB, 1e-6, "its fuel flow 5967 lb/h in kg/h")

-- the optimum and maximum altitudes, PI.11.1 (p.267)
T.equal(P.opt_alt(pw, 300000), 33900, "PW OPT 300 t: 33,900 ft")
T.equal(P.opt_alt(pw, 290000), (33900 + 35400) / 2, "290 t: between 300 t and 280 t")
T.equal(P.opt_alt(pw, 150000), 44600, "150 t: the lightest row's 44,600")
local a, lim = P.max_alt(pw, 300000, 0)
T.check(a == 38100 and not lim, "PW MAX 300 t ISA, 1.3 g: 38,100 ft")
a, lim = P.max_alt(pw, 300000, 0, 1.2)
T.check(a == 39200 and lim, "1.2 g: 39,200 ft, thrust limited")
a = P.max_alt(pw, 300000, 0, 1.25)
T.equal(a, 38900, "1.25 g: 38,900")
a, lim = P.max_alt(pw, 260000, 20, 1.25)
T.check(a == 41100 and lim, "260 t ISA+20, 1.25 g: 41,100, thrust limited")
a = P.max_alt(pw, 260000, 30, 1.25)
T.equal(a, 41100, "ISA+30: the ISA+20 table")
a = P.max_alt(pw, 320000, 12.5, 1.2)
T.equal(a, (38000 + 37900) / 2, "ISA+12.5: between ISA+10 and +15")
T.equal(P.opt_alt(ge, 640 * KLB), 36000, "GE OPT 640 klb: 36,000")
a, lim = P.max_alt(ge, 520 * KLB, 0, 1.2)
T.check(a == 44700 and lim, "GE MAX 520 klb 1.2 g: 44,700, thrust limited")

-- holding, PI.11.6 (p.272): 300 t at 10,000 ft 242 kt, 2440 kg/h
local hk, hf = P.hold(pw, 300000, 10000)
T.check(hk == 242 and hf == 2440, "PW holding 300 t 10,000 ft: 242 kt, 2440 kg/h")
hk, hf = P.hold(pw, 300000, 12500)
T.check(hk == 242 and hf == (2440 + 2350) / 2, "12,500 ft: halfway in fuel flow")
hk = P.hold(pw, 400000, 40000)
T.equal(hk, 322, "400 t at 40,000 ft: its highest (30,000 ft)")
hk, hf = P.hold(ge, 600 * KLB, 20000)
T.check(math.abs(hk - 249) < 1e-6 and math.abs(hf - 4510 * P.LB) < 1e-6, "GE holding 600 klb 20,000 ft: 249 kt, 4510 lb/h")

-- the .84/290/250 descent, PI.11.5 (p.271)
local nm, min = P.descent(pw, 35000)
T.check(nm == 124 and min == 23, "PW descent from FL350: 124 NM, 23 min")
nm = P.descent(pw, 36000)
T.equal(nm, (124 + 129) / 2, "FL360: between")
nm = P.descent(pw, 13500)
T.equal(nm, 96 / 2, "13,500 ft: half the FL270's (below the table, in proportion: an estimate)")
nm, min = P.descent(ge, 19000)
T.check(nm == 75 and min == 16, "GE descent from FL190: 75 NM, 16 min")

-- the wind-altitude trade, PI.11.5 (p.271)
T.equal(P.wind_factor(pw, 300000, 35000), 2, "PW wind factor 300 t FL350: 2 kt")
T.equal(P.wind_factor(pw, 300000, 39000), 42, "FL390: 42")
T.equal(P.wind_factor(pw, 400000, 41000), nil, "400 t at FL410: none (above its altitudes)")
T.equal(P.wind_factor(ge, 560 * KLB, 39000), 0, "GE 560 klb FL390: 0")

-- the weight at which the maximum altitude reaches an altitude (for the
-- step climb's point): 300 t for 38,100 ft (ISA, 1.3 g); beyond the
-- tables their ends
T.near(P.max_alt_weight(pw, 38100, 0), 300000, 1, "MAX reaches 38,100 ft at 300 t")
T.near(P.max_alt_weight(pw, 37000, 0), 300000 + 20000 * (38100 - 37000) / (38100 -36800), 1, "37,000 ft: between 320 t and 300 t")
T.equal(P.max_alt_weight(pw, 46000, 0), 180000, "46,000 ft: never (the lightest, 180 t)")
T.equal(P.max_alt_weight(pw, 20000, 0), 400000, "20,000 ft: always (the heaviest, 400 t)")


-- the cruise model (6-1/6-2 step 8b, notes §45; an estimate: a drag polar
-- and fuel consumption fitted to the tables by tests/tools/perf_fit.lua):
-- the atmosphere and speeds
local pa, tk = P.atmos(0)
T.check(pa == 101325 and tk == 288.15, "ISA sea level: 101,325 Pa, 15 C")
pa, tk = P.atmos(36089, 10)
T.near(pa, 22632, 1, "the tropopause (36,089 ft): 22,632 Pa")
T.near(tk, 226.65, 0.01, "ISA+10 there: -46.5 C")
T.near(P.atmos(45000), 14748, 1, "45,000 ft: 14,748 Pa")
T.near(P.mach_to_cas(0.84, 35000), 287.1, 0.1, "M.84 at FL350: 287 kt CAS")
T.near(P.cas_to_mach(290, 30000), 0.766, 0.001, "290 kt at FL300: M.766")
T.near(P.cas_to_mach(P.mach_to_cas(0.62, 12000), 12000), 0.62, 1e-9, "Mach to CAS and back")
T.near(P.tas(0.84, 35000), 484.2, 0.1, "M.84 at FL350 ISA: 484 kt TAS")
local lim, limcas = P.econ_limit(35000)
T.check(math.abs(lim - 0.879) < 0.001 and math.abs(limcas - (P.mach_to_cas(0.92, 35000) - 16)) < 1e-6,
    "the economy targets' limit at FL350: MMO less 16 kt, M.879 (FCOM p.1258)")
local _, cas250 = P.econ_limit(25000)
T.equal(cas250, 349, "at FL250 VMO less 16 kt: 349 kt")

-- the model against the tables: the long range cruise's fuel flow and Mach
-- and the thrust setting, every cell
for _, e in ipairs({{pw, "PW", 0.05, 0.02, 0.016, 0.035, 0.012}, {ge, "GE", 0.03, 0.013, 0.008, 1.2, 0.5}}) do
    local t = e[1]
    local mff, s2, mm, mset, s2set, n = 0, 0, 0, 0, 0, 0
    for _, w in ipairs(t.LRC_W) do
        for _, a in ipairs(t.LRC_ALT) do
            local c = t.LRC[w][a]
            if c then
                local kg, ft = w * 1000 * t.wf, a * 1000
                local r = P.cruise_ff(t, kg, ft, c[2]) / (c[4] * t.wf) - 1
                local ds = P.level_setting(t, kg, ft, c[2]) - c[1]
                mff, s2 = math.max(mff, math.abs(r)), s2 + r * r
                mm = math.max(mm, math.abs(P.lrc_model(t, kg, ft) - c[2]))
                mset, s2set = math.max(mset, math.abs(ds)), s2set + ds * ds
                n = n + 1
            end
        end
    end
    T.check(mff < e[3] and math.sqrt(s2 / n) < e[4], string.format("%s: the fuel flow at the tables' long range cruise within %.0f %% (%.1f %% rms)", e[2], 100 * e[3], 100 * math.sqrt(s2 / n)))
    T.check(mm < e[5], string.format("%s: the long range cruise Mach (1 %% less range than the most) within %.3f of the tables'", e[2], e[5]))
    T.check(mset < e[6] and math.sqrt(s2set / n) < e[7], string.format("%s: the thrust setting for level flight within %.3f (%.3f rms)", e[2], e[6], math.sqrt(s2set / n)))
end
T.near(P.level_setting(pw, 300000, 35000, 0.84), 1.24, 0.02, "PW .84 at FL350, 300 t: EPR 1.24 (PI.10.38)")
local n1 = P.level_setting(ge, 650 * KLB, 35000, 0.84)
T.near(n1, 90.9, 0.5, "GE .84 at FL350, 650 klb: N1 90.9 (PI.20.33)")
T.check(P.level_setting(ge, 650 * KLB, 35000, 0.84, 10) > n1 + 1.5, "ISA+10: more N1 (the temperature)")
T.near(P.level_setting(pw, 300000, 35000, 0.84, 10), P.level_setting(pw, 300000, 35000, 0.84), 1e-9, "EPR: the same")

-- the maximum range cruise and the economy cruise by the cost index (the
-- time's cost: 100 lb of fuel an hour per unit, the FMS pilot's guide
-- p.261), PW 300 t at FL350
local mrc = P.mrc(pw, 300000, 35000)
local lrcm = P.lrc_model(pw, 300000, 35000)
T.check(mrc > 0.80 and mrc < lrcm - 0.02, string.format("the maximum range cruise M%.3f below the long range cruise M%.3f", mrc, lrcm))
T.near(P.econ_cruise(pw, 300000, 35000, 0, 0), mrc, 1e-6, "cost index 0: the maximum range cruise (FCOM p.1257)")
local prev = mrc
for _, ci in ipairs({50, 100, 500, 1000, 2000, 4000}) do
    local m = P.econ_cruise(pw, 300000, 35000, ci, 0)
    T.check(m > prev and m < lim - 0.001, string.format("cost index %d: M%.3f, faster than a lower index, below the limit", ci, m))
    prev = m
end
T.near(P.econ_cruise(pw, 300000, 35000, 5000, 0), lim, 0.0015, "cost index 5000: the speed limit (FCTM p.4.7)")
T.near(P.econ_cruise(pw, 300000, 35000, 9999, 0), lim, 1e-9, "9999: the limit")
local m100 = P.econ_cruise(pw, 300000, 35000, 100, 0)
T.check(P.econ_cruise(pw, 300000, 35000, 100, 100) > m100 + 0.001, "a headwind: faster (FCTM p.4.7)")
T.check(P.econ_cruise(pw, 300000, 35000, 100, -100) < m100 - 0.005, "a tailwind: slower")
T.near(P.econ_cruise(pw, 300000, 35000, 0, -150), mrc, 1e-9, "but not below the still-air maximum range cruise")
T.check(P.econ_cruise(pw, 380000, 35000, 100, 0) > m100, "heavier: faster")
T.check(P.econ_cruise(ge, 300000, 35000, 100, 0) < m100, "GE (the 747-400F's polar): its own speed")

-- the economy climb and descent: CAS from the cost index's place (an
-- estimate): 0 the maximum range, 1 where the economy cruise is the long
-- range cruise (here about 270), 2 at 5000
local _, vmd = P.min_drag(pw, 300000, 10000)
T.check(vmd > 230 and vmd < 250, string.format("the minimum drag speed at 300 t: %.0f kt (about the flaps up maneuvering speed, VREF 30 + 80)", vmd))
T.check(select(2, P.min_drag(pw, 200000, 10000)) < vmd and select(2, P.min_drag(pw, 400000, 10000)) > vmd, "it goes with the weight")
local cas, mach = P.econ_climb(pw, 300000, 35000, 0)
T.check(math.abs(cas - (vmd + 60)) < 0.01 and mach == mrc, "climb at index 0: the minimum drag speed + 60 kt (FCTM p.4.4's maximum rate climb), the cruise Mach")
local lo, hi = 0, 5000
for _ = 1, 40 do
    local mid = (lo + hi) / 2
    if P.econ_cruise(pw, 300000, 35000, mid, 0) < lrcm then lo = mid else hi = mid end
end
T.check(hi > 150 and hi < 400, string.format("the long range cruise's cost index: %.0f", hi))
cas, mach = P.econ_climb(pw, 300000, 35000, hi + 0.01)
T.near(cas, 340, 0.5, "climb there: 340 kt (FCTM p.4.4)")
T.near(mach, P.econ_cruise(pw, 300000, 35000, hi + 0.01, 0), 1e-9, "at the economy cruise's Mach")
T.check(P.econ_climb(pw, 300000, 35000, 1000) > 340 and P.econ_climb(pw, 300000, 35000, 1000) < 360, "climb at 1000: between")
T.equal(P.econ_climb(pw, 300000, 35000, 5000), 360, "climb at 5000: 360 kt (an estimate)")
cas = P.econ_climb(pw, 300000, 20000, 100)
T.near(cas, P.mach_to_cas(P.econ_cruise(pw, 300000, 20000, 100, 0), 20000), 1e-6, "a low cruise altitude: the climb up to the cruise's CAS (FCTM p.4.3)")
local dm, dcas = P.econ_descent(pw, 300000, 35000, 0)
T.check(math.abs(dcas - vmd) < 0.01 and dm == mrc, "descent at index 0: the minimum drag speed, the cruise Mach")
dm, dcas = P.econ_descent(pw, 300000, 35000, hi + 0.01)
T.near(dcas, 290, 0.5, "the long range cruise's index: 290 kt (PI.11.5's .84/290)")
dm, dcas = P.econ_descent(pw, 300000, 35000, 5000)
T.equal(dcas, 349, "5000: 349 kt (VMO less 16 kt, FCOM p.1258)")
dm, dcas = P.econ_descent(pw, 300000, 35000, 9999)
T.equal(dcas, 349, "9999: not above")
T.done()
