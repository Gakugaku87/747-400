-- Run from the repository root with LuaJIT: luajit tests/eec/ref_thrust_model_test.lua
-- The FMC's reference thrust limit (plugins/xtlua/scripts/B747.42.xt.EEC/
-- B747.42.ref_thrust_model.lua; 6-1/6-2 step 9g3, notes/ATA-34-61-FMC.md
-- §75) from the FCOM PI tables the EEC holds: TO the takeoff (go-around
-- table's) rating, TO 1 and TO 2 8 and 20 % less thrust (FCOM p.1314's
-- example), D-TO at the assumed temperature above the TAT, at most 25 % less
-- thrust than the (derated) rating (FCOM p.1273), CLB the maximum climb
-- table, CLB 1 and CLB 2 washed out from 10,000 ft to 30,000 and 35,000 ft
-- (the 109; GE 15,000 ft), GA the go-around table, CRZ and CON the maximum
-- climb's (estimates), the packs' adjustment as the EEC's maximum.
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
-- GA the go-around table (held above 10,000 ft); CRZ and CON the maximum climb's
T.near(R.reference(inp{mode = "GA", alt = 2000, tat = 20}), E.lookup(PW.ga, 20, 2000), 1e-9, "GA: the go-around table")
T.near(R.reference(inp{mode = "GA", alt = 15000, tat = 0}), E.lookup(PW.ga, 0, 10000), 1e-9, "GA above 10,000 ft: held at 10,000")
T.near(R.reference(inp{mode = "CRZ", alt = 30000, tat = -20, mach = 0.8}), clb30, 1e-9, "CRZ: the maximum climb's (estimate)")
T.near(R.reference(inp{mode = "CON", alt = 30000, tat = -20, mach = 0.8}), clb30, 1e-9, "CON: the maximum climb's (estimate, step 9h)")
-- GE in N1: TO 1 at 5 % less thrust as N1 x 0.95^(1/3)
local ge = R.reference(inp{type = "GE"})
T.near(R.reference(inp{type = "GE", mode = "TO 1", to_pct = 5}), ge * 0.95 ^ (1 / 3), 1e-9, string.format("GE TO 1: %.1f %% N1 from %.1f", ge * 0.95 ^ (1 / 3), ge))
T.done()
