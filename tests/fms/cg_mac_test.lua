-- Run from the repository root with LuaJIT: luajit tests/fms/cg_mac_test.lua
-- The FMC's CG in the airplane's % MAC (2026-11-20, GAP_ANALYSIS.md
-- N19-WB-01; TCDS A20WE p.14, p.22: MAC 327.8 in, LEMAC 1258.0 in aft of the
-- datum, the datum 90 in ahead of the nose) in the FMS module as XTLua runs
-- it (tests/lib/xtlua.lua): B747_fms_mac_pct's ends, the empty airplane at
-- the acf's reference CG (1243.32 in) 23.0 % (before, the acf's trapezoid
-- MAC and LEMAC: 25.0 %), and the takeoff trim of calc_stab_trim at 270 t
-- with the default loading's CG (about 22 %: 5.0 units in the FPPM's table
-- since 2026-11-24, before 4.8, where before the CG of about 31.6 % gave
-- 2.5).
local T = dofile("tests/lib/check.lua")("cg_mac")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new{}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:callout("flight_start")
for _ = 1, 30 do rt:frame(1 / 30) end
local ns = fms.ns

-- the % MAC's ends: the LEMAC 1168 in aft of the nose, the trailing edge of
-- the MAC 327.8 in aft of it
T.near(ns.B747_fms_mac_pct(1168.0), 0, 1e-9, "the LEMAC (BS 1258, 1168 in aft of the nose): 0 %")
T.near(ns.B747_fms_mac_pct(1168.0 + 327.8), 100, 1e-9, "the MAC's trailing edge: 100 %")
T.near(ns.B747_fms_mac_pct(1168.0 + 0.25 * 327.8), 25, 1e-9, "25 % MAC at BS 1340 (TCDS: 1340 in from the datum)")

-- the empty airplane at the acf's reference CG
rt:set("sim/aircraft/weight/acf_m_empty", 183500)
for i = 0, 7 do rt:set("sim/flightmodel/weight/m_fuel", i, 0) end
rt:frame(1 / 30)
ns.calc_CGMAC()
-- (2026-11-20, N19-WB-03) the FMC's CG (TAKEOFF REF shows it on the 405
-- only: tests/fms/wb_n19_test.lua)
T.equal(ns.B747_fms_wbs_cg(), 23, "the empty airplane at 1243.32 in: 23 % MAC (before 25)")
T.near(ns.wb.cg_mac, (1243.32 - 1168.0) / 3.278, 1e-6, "its CG to the decimal: " .. string.format("%.2f", ns.wb.cg_mac))

-- calc_stab_trim at 270 t and the default loading's CG of about 22 %
-- (2026-11-24, review FCTL-4 = PERF-4: the FPPM's table itself, 5.0 between
-- its 260 and 280 t rows; the curve before gave 4.8)
ns.calc_stab_trim(270000, 22)
T.near(ns.wb.stab_trim, 5.0, 1e-9, string.format("270 t, CG 22 %%: %.2f units (the FPPM p.44's table)", ns.wb.stab_trim))
ns.calc_stab_trim(270000, 31.6)
T.near(ns.wb.stab_trim, 2.6, 0.15, string.format("the same weight with X-Plane's 31.6 %% (before): %.2f units", ns.wb.stab_trim))
T.done()
