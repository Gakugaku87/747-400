-- Run from the repository root with LuaJIT: luajit tests/fms/vref_model_test.lua
-- The VREF model (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/
-- B747.68.vref_model.lua, 6-1/6-2 step 3d; notes/ATA-34-61-FMC.md §128)
-- without X-Plane: the FCOM's VREF table (PI.10.2) and its "1 knot/4000 ft
-- above sea level", against the FCOM's APPROACH REF figures (p.1409,
-- p.1411) and Air China's QRH (PI-QRH.10.5, 1,000 lb).
local T = dofile("tests/lib/check.lua")("vref_model")
local V = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vref_model.lua")
local function kt(flaps, kg, elev) return math.floor(V.vref(flaps, kg, elev) + 0.5) end
local LB = 0.45359237

T.near(V.vref(30, 300000, 0), 157, 1e-9, "300 t: VREF 30 157 (PI.10.2)")
T.near(V.vref(25, 300000, 0), 164, 1e-9, "300 t: VREF 25 164")
T.near(V.vref(25, 310000, 0), 167, 1e-9, "310 t: between 164 and 170")
T.near(V.vref(30, 300000, 4000), 158, 1e-9, "at 4,000 ft: 1 kt more")
T.near(V.vref(30, 300000, -500), 157, 1e-9, "below sea level: none less")
-- the FCOM's APPROACH REF: 240.8 t, 25 146 KT, 30 140 KT (109/405, p.1409);
-- 502.8 (1,000 lb), 142 and 136 (570, p.1411: the table's, not the
-- 747-400F CF6's PI.20.2, 141)
T.check(kt(25, 240800, 0) == 146 and kt(30, 240800, 0) == 140, "240.8 t: 146/140 as the FCOM's APPROACH REF")
T.check(kt(25, 502800 * LB, 0) == 142 and kt(30, 502800 * LB, 0) == 136, "502,800 lb: 142/136 as the FCOM's 570 APPROACH REF")
-- Air China's QRH (PW4056, 1,000 lb), every row within 1 kt
local QRH = {
    {900, 186, 194}, {850, 181, 188}, {800, 175, 182}, {750, 169, 176}, {700, 162, 169},
    {650, 156, 163}, {600, 150, 156}, {550, 143, 149}, {500, 136, 142}, {450, 129, 134},
}
local worst = 0
for _, r in ipairs(QRH) do
    local kg = r[1] * 1000 * LB
    worst = math.max(worst, math.abs(V.vref(30, kg, 0) - r[2]), math.abs(V.vref(25, kg, 0) - r[3]))
end
T.check(worst <= 1, string.format("the QRH's rows within 1 kt (worst %.2f), 900,000 lb (408 t) too", worst))
T.near(V.vref(30, 180000, 0), 127 - 6 * 20 / 20, 1e-9, "180 t: the first step carried on (estimate)")
T.done()
