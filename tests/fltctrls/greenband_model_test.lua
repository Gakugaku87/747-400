-- Run from the repository root with LuaJIT: luajit tests/fltctrls/greenband_model_test.lua
-- The takeoff greenband model (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.greenband_model.lua)
-- against FCOM p.944 and ATA27 p.514, p.521 (docs/overhaul/notes/ATA-27.md
-- §4.6): the three bands, the selection from the FMC's takeoff trim
-- (estimate), and where the 3D's one band shows them.
local T = dofile("tests/lib/check.lua")("greenband_model")
local G = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.greenband_model.lua")

-- the bands (ATA27 p.521 figure)
T.check(G.within(G.MID, 3.35) and G.within(G.MID, 8.15), "mid band 3.35-8.15")
T.check(not G.within(G.MID, 3.3) and not G.within(G.MID, 8.2), "out of the mid band")
T.check(G.within(G.NOSE_UP, 3.35) and G.within(G.NOSE_UP, 10.15) and not G.within(G.NOSE_UP, 10.2),
    "nose up band 3.35-10.15 (the mid band and more nose up)")
T.check(G.within(G.NOSE_DOWN, 1.35) and G.within(G.NOSE_DOWN, 8.15) and not G.within(G.NOSE_DOWN, 1.3)
    and not G.within(G.NOSE_DOWN, 8.2), "nose down band 1.35-8.15 (the mid band and more nose down)")

-- the selection (estimate): the mid band when the FMC's trim is in it,
-- otherwise the band on its side; no takeoff trim: the mid band
T.equal(G.select(0), G.MID, "no takeoff trim: mid band")
T.equal(G.select(nil), G.MID, "nothing: mid band")
T.equal(G.select(6.0), G.MID, "6.0: mid band")
T.equal(G.select(8.15), G.MID, "8.15: still the mid band")
T.equal(G.select(9.2), G.NOSE_UP, "9.2 (forward CG): nose up band")
T.equal(G.select(2.6), G.NOSE_DOWN, "2.6 (aft CG): nose down band")

-- the 3D's band: 4.63 units long, its centre 3.81 + 4.31 x the indicator
local function centre(x) return G.IND_CENTER_0 + x * (G.IND_CENTER_1 - G.IND_CENTER_0) end
T.near(centre(G.indicator(G.MID, true)), 5.75, 1e-9, "mid band: centred (3.43-8.07)")
T.near(centre(G.indicator(G.NOSE_UP, true)) + G.IND_HALF, 10.15, 1e-9, "nose up band: its top at 10.15")
T.equal(G.indicator(G.NOSE_DOWN, true), 0, "nose down band: as low as the 3D goes (1.49-6.13)")
T.near(G.indicator(G.NOSE_UP, false), G.indicator(G.MID, true), 1e-9,
    "lights out (above V1, in the air): the painted mid band")

T.done()
