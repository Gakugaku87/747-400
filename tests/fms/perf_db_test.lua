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
T.equal(P.wind_factor(ge, 560 * KLB, 39000), 0, "GE 560 klb FL390: 0")-- the weight at which the maximum altitude reaches an altitude (for the
-- step climb's point): 300 t for 38,100 ft (ISA, 1.3 g); beyond the
-- tables their ends
T.near(P.max_alt_weight(pw, 38100, 0), 300000, 1, "MAX reaches 38,100 ft at 300 t")
T.near(P.max_alt_weight(pw, 37000, 0), 300000 + 20000 * (38100 - 37000) / (38100 -36800), 1, "37,000 ft: between 320 t and 300 t")
T.equal(P.max_alt_weight(pw, 46000, 0), 180000, "46,000 ft: never (the lightest, 180 t)")
T.equal(P.max_alt_weight(pw, 20000, 0), 400000, "20,000 ft: always (the heaviest, 400 t)")

T.done()
