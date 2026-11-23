-- Run from the repository root with LuaJIT: luajit tests/eec/ref_thrust_model_test.lua
-- The FMC's reference thrust limit (plugins/xtlua/scripts/B747.42.xt.EEC/
-- B747.42.ref_thrust_model.lua; 6-1/6-2 step 9g3, notes/ATA-34-61-FMC.md
-- §75) from the FCOM PI tables the EEC holds: TO the takeoff (go-around
-- table's) rating, TO 1 and TO 2 8 and 20 % less thrust (FCOM p.1314's
-- example), D-TO at the assumed temperature above the TAT, at most 25 % less
-- thrust than the (derated) rating (FCOM p.1273) (2026-11-24, ENG-2: the
-- P&W's from the FPPM's Takeoff EPR tables at the OAT), CLB the maximum climb
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

-- (2026-11-24, ENG-2 of the 2026-11-23 review) P&W's TO, TO 1 and TO 2: the
-- FPPM's Takeoff EPR tables (747-400F/PW4056, D632U002-RZ043) at the OAT,
-- every cell (the TAT 3 °C warmer: read at the OAT): p.44 (1.2.20), TO1 8 %
-- p.57 (1.3.11), TO2 20 % p.69 (1.3.23). Before, the go-around table at the
-- TAT (PI.10.37) and the derates by the EPR model's thrust: 0.026, 0.035 and
-- 0.042 over them on average (FAOR's 5,214 ft and 24 °C 1.590 for 1.563)
local F = false
local TO_ALT = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000}
local TO_OAT = {70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10}
local FPPM = {
    {mode = "TO", pct = 0, cells = 145, v = {                               -- p.44
        {1.25, 1.25, 1.25, F, F, F, F, F, F, F, F, F, F},
        {1.28, 1.28, 1.29, 1.29, 1.29, 1.29, F, F, F, F, F, F, F},
        {1.32, 1.32, 1.32, 1.32, 1.32, 1.32, 1.32, 1.32, F, F, F, F, F},
        {1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, F, F},
        {1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39},
        {1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.42, 1.42, 1.42, 1.42, 1.42},
        {1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46},
        {1.46, 1.48, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.49, 1.49, 1.49},
        {1.46, 1.48, 1.51, 1.52, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.59, 1.59, 1.59, 1.59, 1.59},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.60, 1.61, 1.62, 1.62, 1.62},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.60, 1.61, 1.62, 1.63, 1.65}}},
    {mode = "TO 1", pct = 8, cells = 145, v = {                             -- p.57
        {1.22, 1.22, 1.22, F, F, F, F, F, F, F, F, F, F},
        {1.25, 1.25, 1.26, 1.26, 1.26, 1.26, F, F, F, F, F, F, F},
        {1.29, 1.29, 1.29, 1.29, 1.29, 1.29, 1.29, 1.29, F, F, F, F, F},
        {1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, F, F},
        {1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35},
        {1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.37, 1.37, 1.37, 1.37, 1.37},
        {1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41},
        {1.41, 1.42, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.43, 1.43, 1.43},
        {1.41, 1.42, 1.45, 1.45, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.49, 1.49, 1.49, 1.49, 1.49},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.51, 1.51, 1.51, 1.51, 1.51},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.52, 1.53, 1.53, 1.53, 1.53},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.52, 1.53, 1.53, 1.54, 1.56}}},
    {mode = "TO 2", pct = 20, cells = 144, v = {                            -- p.69
        {1.21, 1.21, 1.21, F, F, F, F, F, F, F, F, F, F},
        {1.21, 1.21, 1.22, 1.22, 1.22, 1.22, F, F, F, F, F, F, F},
        {1.24, 1.24, 1.24, 1.24, 1.24, 1.24, 1.24, 1.24, F, F, F, F, F},
        {1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, F, F},
        {1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, F},
        {1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.30, 1.30, 1.30, 1.30, 1.30},
        {1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33},
        {1.33, 1.34, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.35, 1.35, 1.35},
        {1.33, 1.34, 1.36, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.41, 1.41, 1.41, 1.41},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.42, 1.43, 1.43, 1.43},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.42, 1.43, 1.43, 1.44}}},
}
for _, t in ipairs(FPPM) do
    local n, bad = 0, 0
    for i, oat in ipairs(TO_OAT) do
        for j, alt in ipairs(TO_ALT) do
            local f = t.v[i][j]
            if f then
                n = n + 1
                local v, r = R.reference(inp{mode = t.mode, to_pct = t.pct, alt = alt, oat = oat, tat = oat + 3})
                if math.abs(v - f) > 1e-9 or math.abs(r - t.pct) > 1e-9 then
                    bad = bad + 1
                    print(string.format("  %s at %d ft, OAT %d: %.3f (%.1f %%), the FPPM %.2f", t.mode, alt, oat, v, r, f))
                end
            end
        end
    end
    T.check(n == t.cells and bad == 0, string.format("%s: the FPPM's %d cells at the OAT, the reduction %d %% (%d off)", t.mode, n, t.pct, bad))
end
local to, red = R.reference(inp())
T.near(to, 1.51, 1e-9, "TO at sea level, OAT 15: 1.51 (p.44)")
T.near(red, 0, 1e-9, "no reduction")
local c5, c6 = 1.56 + 0.01 * 0.2, 1.56 + 0.03 * 0.2
T.near(R.reference(inp{alt = 5214, oat = 24, tat = 24}), c5 + (c6 - c5) * 0.214, 1e-9,
    "FAOR (5,214 ft, OAT 24): p.44 between 5,000 and 6,000 ft, 20 and 25 °C (before, the go-around table's 1.590)")
T.near(R.reference(inp{oat = -20, tat = -20, alt = 10000}), 1.65, 1e-9, "OAT -20 at 10,000 ft: the 10 & BELOW row's 1.65")
T.near(R.reference(inp{oat = 75, tat = 75, alt = 0}), 1.25, 1e-9, "OAT 75 at sea level: held at the 70 row's 1.25")
T.near(R.reference(inp{packs_on = 2}), to, 1e-9, "1 pack off: no adjustment (p.44)")
T.near(R.reference(inp{packs_on = 1}), to + 0.01, 1e-9, "2 packs off: +0.01 (p.44)")
T.near(R.reference(inp{packs_on = 0}), to + 0.02, 1e-9, "3 packs off: +0.02 (p.44)")
T.near(R.reference(inp{mode = "TO 2", to_pct = 20, packs_on = 0}), 1.38, 1e-9, "TO 2, 3 packs off: 1.36 + 0.02 (p.69)")
T.near(R.reference(inp{nai = true, wai = true}), to, 1e-9, "anti-ice: no adjustment (p.22 (1.1.4))")
-- another derate the operator sets (FCOM p.1272: PERF FACTORS): on the
-- thrust's points between the tables (estimate)
local to10, red10 = R.reference(inp{mode = "TO 1", to_pct = 10})
T.near(to10, 1.45 - (1.45 - 1.36) * 2 / 12, 1e-9, string.format("TO 1 at 10 %%: between p.57's 1.45 (8 %%) and p.69's 1.36 (20 %%), %.3f", to10))
T.near(red10, 10, 1e-9, "its reduction 10 %")
local to1 = R.reference(inp{mode = "TO 1", to_pct = 8})
-- D-TO: p.44 at the assumed temperature (p.22), at most 25 % less thrust:
-- p.22's minimum allowable EPR for the actual OAT's maximum (1.51: 1.326)
T.near(E.pw_to_min(1.51), 1.326, 1e-9, "p.22: MAX TAKEOFF EPR 1.51, MIN TAKEOFF EPR ALLOWED 1.326 (1.50 1.32, 1.55 1.35)")
local rows = {{1.31, 1.21}, {1.35, 1.23}, {1.40, 1.26}, {1.45, 1.29}, {1.50, 1.32}, {1.55, 1.35}, {1.60, 1.37}, {1.65, 1.40}, {1.70, 1.42}, {1.75, 1.44}}
local rowsOk = true
for _, r in ipairs(rows) do if math.abs(E.pw_to_min(r[1]) - r[2]) > 1e-9 then rowsOk = false end end
T.check(rowsOk, "p.22's ten rows")
local dto, redd = R.reference(inp{mode = "D-TO", sel = 50})
T.near(dto, 1.39, 1e-9, string.format("D-TO, SEL 50: p.44 at 50 °C, 1.39 (%.1f %% less)", redd))
T.check(redd > 8 and redd < 20, "between TO 1's and TO 2's thrust (1.45, 1.36)")
local dto55, redd55 = R.reference(inp{mode = "D-TO", sel = 55})
T.near(dto55, 1.35, 1e-9, string.format("D-TO, SEL 55: p.44's 1.35 (%.1f %% less: over the minimum 1.326)", redd55))
T.check(redd55 > 20 and redd55 < 25, "between TO 2's and the 25 %")
for _, sel in ipairs({60, 65, 70, 99}) do
    local v, r = R.reference(inp{mode = "D-TO", sel = sel})
    T.check(math.abs(v - 1.326) < 1e-9 and math.abs(r - 25) < 1e-9,
        string.format("D-TO, SEL %d: p.44's %s under p.22's minimum: 1.326, 25 %% (before, 1.38 and 21.3 %%: the go-around table held at 54)", sel, sel == 99 and "70" or tostring(sel)))
end
local dmax, redm = R.reference(inp{mode = "D-TO", sel = 70})
T.near(R.reference(inp{mode = "D-TO", sel = 70, alt = 10000, oat = 10, tat = 10}), 1.40, 1e-9,
    "D-TO at 10,000 ft, OAT 10, SEL 70: p.22's 1.40 for 1.65 (p.44 held at 50 °C's 1.39)")
R.SEL_MAX = 0.10
local _, redc = R.reference(inp{mode = "D-TO", sel = 50})
T.near(redc, 10, 1e-6, "(with the most at 10 %: SEL 50 held at 10 % less)")
R.SEL_MAX = 0.25
T.near(R.reference(inp{mode = "D-TO", sel = 10}), to, 1e-9, "SEL 10 under the OAT 15: TO's")
T.near(R.reference(inp{mode = "D-TO", sel = 16, oat = 15, tat = 18, alt = 9000}), 1.62 - 0.03 / 5, 1e-9,
    "9,000 ft, SEL 16 over the OAT 15 (under the TAT 18): p.44 at 16 (the OAT's, as the FMC's SEL; before, none: under the TAT)")
local dto1, redd1 = R.reference(inp{mode = "D-TO 1", to_pct = 8, sel = 99})
T.near(dto1, E.pw_to_min(1.45), 1e-9, string.format("D-TO 1, SEL 99: p.22's minimum on TO 1's 1.45 (estimate), %.3f", dto1))
T.near(redd1, 100 * (1 - 0.92 * (1 - redm / 100)), 1e-6, string.format("D-TO 1, SEL 99: SEL's from TO 1's: %.1f %% in all", redd1))
T.near(R.reference(inp{mode = "D-TO 1", to_pct = 8, sel = 40}), 1.41, 1e-9, "D-TO 1, SEL 40: p.57 at 40 °C, 1.41")
T.near(R.reference(inp{mode = "TO 1", to_pct = 8, sel = 50}), to1, 1e-9, "TO 1 without D-: SEL not used")
-- the thrust's points fall with the share everywhere (the hold, the blanks)
do
    local es, ss, ok = {}, {}, true
    for oat = -20, 75 do
        for alt = -2000, 10000, 250 do
            E.pw_to_points(oat, alt, es, ss)
            for k = 2, #es do
                if not (es[k] < es[k - 1] and ss[k] < ss[k - 1]) then
                    ok = false
                    print(string.format("  points not falling at OAT %d, %d ft: %d", oat, alt, k))
                end
            end
        end
    end
    T.check(ok, "the takeoff's points (EPR and thrust) fall strictly at every OAT -20 to 75 and -2,000 to 10,000 ft")
end
-- GA the go-around table at the TAT still; the GE's TO the go-around's
T.near(R.reference(inp{mode = "GA", alt = 2000, tat = 20, oat = 10}), E.lookup(PW.ga, 20, 2000), 1e-9, "GA: the go-around table at the TAT")
T.near(R.reference(inp{type = "GE", tat = 20, oat = 10}), E.lookup(GE.ga, 20, 0), 1e-9, "GE's TO: the go-around table at the TAT (ENG-3, ENG-4: not changed)")
T.check(R.is_takeoff("") and R.is_takeoff("TO") and R.is_takeoff("TO 2") and R.is_takeoff("D-TO 1")
    and not R.is_takeoff("GA") and not R.is_takeoff("CLB") and not R.is_takeoff("NONE"), "a takeoff's thrust limit: none, TO..., D-TO...")

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
local geClb12 = R.reference(inp{type = "GE", mode = "CLB", alt = 12500, tat = 5, mach = 0.6})
T.near((R.reference(inp{type = "GE", mode = "CLB 2", alt = 12500, tat = 5, mach = 0.6}) / geClb12) ^ 3, 0.90, 1e-6,
    "GE's CLB 2 at 12,500 ft: 10 % less (halfway from 10,000 to 15,000 ft)")
-- (2026-11-19) the 405 (a P&W freighter, laminar/B747/freighter) both at
-- 15,000 ft as the 570 (FCOM p.1273; before, the 109's as any P&W)
local clb12 = R.reference(inp{mode = "CLB", alt = 12500, tat = 5, mach = 0.6})
T.near(tr(clb12, R.reference(inp{mode = "CLB 2", alt = 12500, tat = 5, mach = 0.6, freighter = true}), 0.6), 0.90, 1e-6,
    "a P&W freighter's CLB 2 at 12,500 ft: 10 % less (halfway to 15,000 ft: the 405)")
T.near(tr(clb12, R.reference(inp{mode = "CLB 2", alt = 12500, tat = 5, mach = 0.6}), 0.6), 1 - 0.20 * 22.5 / 25, 1e-6,
    "a P&W passenger's CLB 2 at 12,500 ft: 18 % less (the 109's to 35,000 ft)")
T.near(R.reference(inp{mode = "CLB 1", alt = 15000, tat = 0, mach = 0.65, freighter = true}),
    R.reference(inp{mode = "CLB", alt = 15000, tat = 0, mach = 0.65}), 1e-9, "a P&W freighter's CLB 1 at 15,000 ft: CLB's")
T.near(R.reference(inp{mode = "CLB 2", alt = 20000, tat = -5, mach = 0.7, freighter = true}), clb20, 1e-9,
    "a P&W freighter's CLB 2 at 20,000 ft: CLB's (before, 12 % less)")
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
