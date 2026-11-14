-- Run from the repository root with LuaJIT: luajit tests/eec/ref_thrust_model_test.lua
-- The FMC's reference thrust limit (plugins/xtlua/scripts/B747.42.xt.EEC/
-- B747.42.ref_thrust_model.lua; 6-1/6-2 step 9g3, notes/ATA-34-61-FMC.md
-- §75) from the FCOM PI tables the EEC holds: TO the takeoff (go-around
-- table's) rating, TO 1 and TO 2 8 and 20 % less thrust (FCOM p.1314's
-- example), D-TO at the assumed temperature above the TAT, at most 25 % less
-- thrust than the (derated) rating (FCOM p.1273), CLB the maximum climb
-- table, CLB 1 and CLB 2 washed out from 10,000 ft to 30,000 and 35,000 ft
-- (the 109; GE 15,000 ft), GA the go-around table, CRZ (2026-11-14,
-- notes/ATA-34-61-FMC.md §169) P&W the FPPM's Max Cruise EPR (747-400F/
-- PW4056, p.120-127) and GE the maximum climb's (estimate), CON the maximum
-- continuous table at the airspeed (step 9h1), the packs' adjustment as the
-- EEC's maximum.
local T = dofile("tests/lib/check.lua")("ref_thrust_model")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local R = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.ref_thrust_model.lua")
local PW, GE = E.TABLE.PW, E.TABLE.GE

local function inp(t)
    local i = {type = "PW", mode = "TO", to_pct = 0, sel = nil, alt = 0, tat = 15, mach = 0, packs_on = 3, wai = false, nai = false}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
-- the thrust ratio of two EPRs at a Mach (the EPR model's)
local function tr(a, b, mach) return P.thrust(b, 1, mach or 0) / P.thrust(a, 1, mach or 0) end

-- TO: the go-around table's rating, no reduction; packs off: +0.02 (the
-- go-around table's adjustment)
local to, red = R.reference(inp())
T.near(to, E.lookup(PW.ga, 15, 0), 1e-9, string.format("TO at sea level, TAT 15: the go-around table's %.2f", to))
T.near(red, 0, 1e-9, "no reduction")
T.near(R.reference(inp{packs_on = 0}), to + 0.02, 1e-9, "3 packs off: +0.02")
-- TO 1, TO 2: 8 and 20 % less thrust
local to1, red1 = R.reference(inp{mode = "TO 1", to_pct = 8})
T.check(math.abs(tr(to, to1) - 0.92) < 1e-6 and math.abs(red1 - 8) < 1e-6, string.format("TO 1: 8 %% less thrust, EPR %.3f", to1))
local to2, red2 = R.reference(inp{mode = "TO 2", to_pct = 20})
T.check(math.abs(tr(to, to2) - 0.80) < 1e-6 and math.abs(red2 - 20) < 1e-6, string.format("TO 2: 20 %% less thrust, EPR %.3f", to2))
-- D-TO: the rating at SEL; at most 25 % less; SEL under the TAT nothing
local dto, redd = R.reference(inp{mode = "D-TO", sel = 50})
T.near(dto, E.lookup(PW.ga, 50, 0), 1e-9, string.format("D-TO, SEL 50: the table at 50, %.3f (%.1f %% less)", dto, redd))
T.check(redd > 0 and redd < 25, "less than the 25 %")
local dmax, redm = R.reference(inp{mode = "D-TO", sel = 99})
T.near(dmax, E.lookup(PW.ga, 54, 0), 1e-9, string.format("SEL 99: the table's warmest row (54), %.3f, %.1f %% less", dmax, redm))
R.SEL_MAX = 0.10
local _, redc = R.reference(inp{mode = "D-TO", sel = 50})
T.near(redc, 10, 1e-6, "(with the most at 10 %: SEL 50 held at 10 % less)")
R.SEL_MAX = 0.25
T.near(R.reference(inp{mode = "D-TO", sel = 10}), to, 1e-9, "SEL 10 under the TAT 15: TO's")
local _, redd1 = R.reference(inp{mode = "D-TO 1", to_pct = 8, sel = 99})
T.near(redd1, 100 * (1 - 0.92 * (1 - redm / 100)), 1e-6, string.format("D-TO 1, SEL 99: SEL's from TO 1's: %.1f %% in all", redd1))
T.near(R.reference(inp{mode = "TO 1", to_pct = 8, sel = 50}), to1, 1e-9, "TO 1 without D-: SEL not used")

-- CLB: the maximum climb table; CLB 1 and CLB 2 washed out (the 109)
local clb30 = R.reference(inp{mode = "CLB", alt = 30000, tat = -20, mach = 0.8})
T.near(clb30, E.lookup(PW.clb, -20, 30000), 1e-9, string.format("CLB at 30,000 ft, TAT -20: the table's %.2f", clb30))
local clb5 = R.reference(inp{mode = "CLB", alt = 5000, tat = 10, mach = 0.45})
T.near(tr(clb5, R.reference(inp{mode = "CLB 1", alt = 5000, tat = 10, mach = 0.45}), 0.45), 0.90, 1e-6, "CLB 1 at 5,000 ft: 10 % less thrust")
T.near(tr(clb5, R.reference(inp{mode = "CLB 2", alt = 5000, tat = 10, mach = 0.45}), 0.45), 0.80, 1e-6, "CLB 2 at 5,000 ft: 20 % less")
local clb20 = R.reference(inp{mode = "CLB", alt = 20000, tat = -5, mach = 0.7})
T.near(tr(clb20, R.reference(inp{mode = "CLB 1", alt = 20000, tat = -5, mach = 0.7}), 0.7), 0.95, 1e-6, "CLB 1 at 20,000 ft: 5 % less (halfway to 30,000)")
T.near(tr(clb20, R.reference(inp{mode = "CLB 2", alt = 20000, tat = -5, mach = 0.7}), 0.7), 1 - 0.20 * 15 / 25, 1e-6, "CLB 2 at 20,000 ft: 12 % less (to 35,000)")
T.near(R.reference(inp{mode = "CLB 1", alt = 30000, tat = -20, mach = 0.8}), clb30, 1e-9, "CLB 1 at 30,000 ft: CLB's")
T.near(R.reference(inp{type = "GE", mode = "CLB 1", alt = 20000, tat = -5, mach = 0.7}), E.lookup(GE.clb, -5, 20000), 1e-9,
    "GE's CLB 1 at 20,000 ft: CLB's (washed out at 15,000 ft: the 570)")
-- GA the go-around table (held above 10,000 ft); CON (step 9h1) the
-- maximum continuous table at the airspeed
T.near(R.reference(inp{mode = "GA", alt = 2000, tat = 20}), E.lookup(PW.ga, 20, 2000), 1e-9, "GA: the go-around table")
T.near(R.reference(inp{mode = "GA", alt = 15000, tat = 0}), E.lookup(PW.ga, 0, 10000), 1e-9, "GA above 10,000 ft: held at 10,000")
-- (2026-11-14) CRZ: P&W the FPPM's Max Cruise EPR (D632U002-RZ043, the
-- Long Range Cruise tables' foot, p.120-127 (3.2.12-3.2.19)): the LIMIT EPR
-- up to its MAX TAT, then less its page's decrease every 10 °C hotter;
-- between the altitudes linear, held at the ends; the anti-ice decreases
local function crz(alt, tat, t) return (R.reference(inp{mode = "CRZ", alt = alt, tat = tat, mach = 0.85,
    nai = t and t.nai, wai = t and t.wai, packs_on = t and t.packs_on})) end
local C = PW.crz
T.check(#C.alt == 32 and #C.epr == 32 and #C.mt == 32 and #C.corr == 32, "the table: 32 altitudes, 6,000 to 45,000 ft, four columns")
T.near(crz(35000, -23), 1.53, 1e-9, "FL350, TAT -23 (colder than its MAX TAT -4): 1.53 (p.122)")
T.near(crz(35000, 6), 1.43, 1e-9, "FL350, TAT 6 (10 °C hotter): 1.53 - 0.10 = 1.43 (p.122: 0.10 every 10 °C)")
T.near(crz(39000, -7), 1.52, 1e-9, "FL390, TAT -7: 1.52 (p.120)")
T.near(crz(39000, 3), 1.40, 1e-9, "FL390, TAT 3: 1.52 - 0.12 = 1.40 (p.120: 0.12)")
T.near(crz(28000, -14), 1.38, 1e-9, "FL280, TAT -14: 1.38 (p.124; FCOM p.830's CRZ figure: TAT -14C, CRZ 1.38)")
T.near(crz(10000, 43), 1.17, 1e-9, "10,000 ft, TAT 43: 1.23 - 0.06 (p.126: 0.06)")
T.near(crz(34500, -23), 1.525, 1e-9, "34,500 ft: between FL340 and FL350, 1.525")
T.near(crz(21000, 22), (1.27 - 0.006 + 1.28 - 0.024) / 2, 1e-9, "21,000 ft, TAT 22: each altitude's (20,000 1 °C, 22,000 3 °C over its MAX TAT), then between")
T.near(crz(3000, 20), 1.21, 1e-9, "3,000 ft: held at 6,000 ft's 1.21 (estimate)")
T.near(crz(47000, -30), 1.49, 1e-9, "47,000 ft: held at 45,000 ft's 1.49")
T.near(crz(35000, -23, {nai = true}), 1.49, 1e-9, "FL350, engine anti-ice: -0.04 (p.122)")
T.near(crz(35000, -23, {nai = true, wai = true}), 1.45, 1e-9, "FL350, engine and wing anti-ice: -0.08 (p.122)")
T.near(crz(39000, -7, {nai = true}), 1.49, 1e-9, "FL390, engine anti-ice: -0.03 (p.120)")
T.near(crz(39000, -7, {nai = true, wai = true}), 1.44, 1e-9, "FL390, engine and wing anti-ice: -0.08 (p.120)")
T.near(crz(10000, 20, {nai = true}), 1.20, 1e-9, "10,000 ft, engine anti-ice: -0.03 (p.126)")
T.near(crz(10000, 20, {nai = true, wai = true}), 1.17, 1e-9, "10,000 ft, engine and wing anti-ice: -0.06 (p.126)")
T.near(crz(37500, -23, {nai = true}), 1.535 - 0.035, 1e-9, "37,500 ft, engine anti-ice: between FL370's -0.04 and FL380's -0.03 (estimate)")
T.near(crz(35000, -23, {wai = true}), 1.53, 1e-9, "wing anti-ice alone: none (the FPPM's: engine, or engine and wing)")
T.near(crz(35000, -23, {packs_on = 0}), 1.53, 1e-9, "packs off: none (the FPPM gives none)")
-- below the maximum climb's everywhere (at each altitude's MAX TAT and
-- 10 °C hotter): FL350 0.11 under (before, CRZ was the maximum climb's)
local under = true
for j, a in ipairs(C.alt) do
    for _, d in ipairs({0, 10}) do
        local c, l = crz(a, C.mt[j] + d), E.lookup(PW.clb, C.mt[j] + d, a)
        if not (c < l) then under = false; print(string.format("  CRZ %.3f not under CLB %.3f at %d ft, TAT %d", c, l, a, C.mt[j] + d)) end
    end
end
T.check(under, "CRZ under CLB at every altitude (its MAX TAT and 10 °C hotter)")
T.near(E.lookup(PW.clb, -23, 35000) - crz(35000, -23), 0.11, 1e-9, "FL350, TAT -23: CLB 1.64, CRZ 0.11 under")
T.near(R.reference(inp{type = "GE", mode = "CRZ", alt = 30000, tat = -20, mach = 0.8}), E.lookup(GE.clb, -20, 30000), 1e-9,
    "GE's CRZ: the maximum climb's (estimate: no maximum cruise table for the CF6)")
T.near(R.reference(inp{mode = "CON", alt = 25000, tat = 0, mach = 0.7, kias = 300}), 1.53, 1e-9, "CON at 25,000 ft, 300 KIAS, TAT 0: the maximum continuous table's 1.53")
T.near(R.reference(inp{mode = "CON", alt = 25000, tat = -5, mach = 0.6, kias = 250}), 1.62, 1e-9, "CON at 250 KIAS, TAT -5: 1.62")
T.near(R.reference(inp{mode = "CON", alt = 25000, tat = 0, mach = 0.6, kias = 250}), 1.611, 1e-9, "CON at 250 KIAS, TAT 0: 1 °C over its MAX TAT -1, 1.611")
T.near(R.reference(inp{mode = "CON", alt = 25000, tat = 0, mach = 0.7, kias = 300, nai = true}), 1.495, 1e-9, "CON with engine anti-ice: -0.035")
T.near(R.reference(inp{mode = "CON", alt = 25000, tat = 0, mach = 0.7, kias = 300, packs_on = 2}), 1.54, 1e-9, "CON with a pack off: +0.01")
T.near(R.reference(inp{type = "GE", mode = "CON", alt = 35000, tat = -30, mach = 0.75, kias = 260}), 103.85, 1e-9, "GE CON at 35,000 ft, 260 KIAS, TAT -30: 103.85 % N1")
-- GE in N1: TO 1 at 5 % less thrust as N1 x 0.95^(1/3)
local ge = R.reference(inp{type = "GE"})
T.near(R.reference(inp{type = "GE", mode = "TO 1", to_pct = 5}), ge * 0.95 ^ (1 / 3), 1e-9, string.format("GE TO 1: %.1f %% N1 from %.1f", ge * 0.95 ^ (1 / 3), ge))
T.done()
