-- Run from the repository root with LuaJIT: luajit tests/fltctrls/aero_corr_model_test.lua
-- The drag corrections (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua,
-- 補正) against FCOM PI.16.3 (p.303) and the custom acf's gear
-- (docs/overhaul/notes/AERO.md §3.16).
local T = dofile("tests/lib/check.lua")("aero_corr_model")
local A = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua")

-- the gear: X-Plane's CD 0.0219 to the FCOM's 0.0260 (EPR) and 0.0265 (fuel flow)
T.near(0.0219 + A.CD_GEAR, 0.02625, 0.0003, "X-Plane's gear and the correction: between the EPR's and the fuel flow's")

-- the fuselage's drag coefficient (the custom acf's 0.085)
T.equal(A.fuse_cd(0.085, 0), 0.085, "gear up: the acf's own")
T.near(A.fuse_cd(0.085, 1), 0.085 + 0.0044 / 0.0664, 1e-12, "gear down: + CD 0.0044 over 0.0664 a unit")
T.near(A.fuse_cd(0.085, 1), 0.1513, 0.0001, "gear down: 0.151")
T.near((A.fuse_cd(0.085, 1) - 0.085) * A.CD_PER_FUSE_CD, 0.0044, 1e-12, "the CD added: 0.0044")
T.near(A.fuse_cd(0.085, 0.5) - 0.085, (A.fuse_cd(0.085, 1) - 0.085) / 2, 1e-12, "half out: half")
T.near(A.fuse_cd(0.1, 1) - 0.1, A.fuse_cd(0.085, 1) - 0.085, 1e-12, "the same increment on another acf's value")

T.done()
