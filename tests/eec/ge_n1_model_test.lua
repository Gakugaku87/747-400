-- Run from the repository root with LuaJIT: luajit tests/eec/ge_n1_model_test.lua
-- The CF6-80C2B1F's N1 the EICAS shows in the air (plugins/xtlua/scripts/
-- B747.42.xt.EEC/B747.42.ge_n1_model.lua, ENG-33, 2026-11-10) against the
-- points it was fitted to: the FCOM's %N1 (747-400F/CF6-80C2B1F, PI.20.31
-- p.359 max climb %N1, PI.20.33 p.361 climb rates and level %N1, PI.20.34
-- p.362 holding and the terminal area) at the thrust the same flight needs
-- on the custom acf - the PW4056 FCOM's EPR at that weight and speed
-- (PI.10.38-10.39 p.264-265) through the EPR model (B747.42.epr_model.lua),
-- the climbs with the climb's power added (W g V/S / TAS).
local T = dofile("tests/lib/check.lua")("ge_n1_model")
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local Gm = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.ge_n1_model.lua")
local LBF, G0, KLB = 4.4482216, 9.80665, 0.45359237

local function isa(h)
    local t, d
    if h <= 36089 then t = 288.15 - 0.0019812 * h; d = (t / 288.15) ^ 5.25588
    else t = 216.65; d = 0.223361 * math.exp(-4.80637e-5 * (h - 36089)) end
    return t, d
end
local function mach_cas(cas, h)
    local _, d = isa(h)
    local qc = ((1 + 0.2 * (cas / 661.4786) ^ 2) ^ 3.5 - 1)
    return math.sqrt(5 * ((qc / d + 1) ^ (2 / 7) - 1))
end
local function climb_mach(h) return math.min(0.84, mach_cas(290, h)) end

-- PW4056 EPR (weights 1000 kg)
local W5 = {200, 250, 300, 350, 390}
local W6 = {200, 250, 300, 350, 400, 410}
local PW_CRUISE = {
    [40000] = {1.16, 1.31}, [35000] = {1.08, 1.14, 1.24, 1.43},
    [30000] = {1.02, 1.07, 1.13, 1.21, 1.32}, [20000] = {0.97, 0.99, 1.03, 1.07, 1.11},
    [10000] = {0.96, 0.98, 1.00, 1.02, 1.04}, [0] = {0.97, 0.98, 0.99, 1.00, 1.01},
}
local PW_HOLD = {1.01, 1.02, 1.03, 1.04, 1.04}
local PW_TERM0 = {1.01, 1.03, 1.04, 1.06, 1.07, 1.08}
local function by_weight(ws, row, t)
    local n = #row
    if t < ws[1] - 10 or t > ws[n] + 10 then return nil end
    for i = 1, n - 1 do
        if t <= ws[i + 1] or i == n - 1 then
            return row[i] + (row[i + 1] - row[i]) * (t - ws[i]) / (ws[i + 1] - ws[i])
        end
    end
end
-- CF6-80C2B1F (weights 1000 lb)
local G6 = {450, 550, 650, 750, 850, 870}
local GE_CRUISE = {
    [40000] = {88.4, 92.6}, [35000] = {85.8, 88.1, 90.9, 95.0},
    [30000] = {81.8, 84.4, 86.9, 89.9, 93.7, 94.6}, [20000] = {74.4, 76.6, 79.2, 81.8, 84.9, 85.5},
    [10000] = {67.1, 69.1, 71.4, 73.9, 76.8, 77.4}, [0] = {60.0, 61.9, 64.0, 66.3, 68.9, 69.5},
}
local GE_CLIMB = {
    [40000] = {1600, 900}, [35000] = {2900, 2000, 1300, 700},
    [30000] = {2900, 2100, 1600, 1100, 700, 600}, [20000] = {4300, 3300, 2600, 2100, 1600, 1500},
    [10000] = {5700, 4500, 3700, 3000, 2500, 2400}, [0] = {6500, 5200, 4300, 3500, 3000, 2900},
}
local GE_HOLD = {{59.7, 209}, {64.9, 224}, {69.3, 240}, {73.2, 261}, {76.8, 282}, {77.4, 284}}
local T6 = {400, 500, 600, 700, 800, 900}
local GE_TERM0 = {{54.3, 202}, {59.9, 217}, {64.8, 231}, {69.1, 244}, {72.9, 256}, {76.3, 268}}
-- the max climb %N1 at the table's altitudes (1000 ft) by TAT (deg C)
local MC_ALT = {0, 10, 20, 30, 35, 40}
local MC = {   -- TAT -> N1 at 0, 10, 20, 30, 35, 40 thousand ft (nil: blank)
    [30] = {99.0, 103.7, 102.6}, [25] = {98.2, 103.9, 103.2, 101.9}, [20] = {97.4, 103.2, 103.6, 102.7},
    [15] = {96.6, 102.4, 104.3, 103.6, 101.1, 100.9}, [10] = {95.8, 101.6, 104.1, 104.4, 101.9, 101.5},
    [5] = {95.0, 100.7, 103.3, 105.2, 102.7, 102.3}, [0] = {94.1, 99.9, 102.6, 106.3, 103.7, 103.2},
    [-5] = {93.3, 99.0, 101.7, 105.7, 104.6, 104.1}, [-10] = {92.5, 98.1, 100.8, 104.9, 105.6, 105.0},
    [-15] = {91.6, 97.2, 99.9, 104.0, 105.5, 105.4}, [-20] = {90.7, 96.3, 99.0, 103.0, 104.7, 104.6},
    [-25] = {89.9, 95.4, 98.1, 102.1, 103.9, 103.8}, [-30] = {89.0, 94.5, 97.1, 101.1, 102.9, 102.8},
}
local MC_TAT = {30, 25, 20, 15, 10, 5, 0, -5, -10, -15, -20, -25, -30}
local function max_climb_n1(tat, h)
    local j
    for k, a in ipairs(MC_ALT) do if a * 1000 == h then j = k end end
    for i = 1, #MC_TAT - 1 do
        local t0, t1 = MC_TAT[i], MC_TAT[i + 1]
        if tat <= t0 and tat >= t1 then
            local a, b = MC[t0][j], MC[t1][j]
            if a and b then return a + (b - a) * (t0 - tat) / (t0 - t1) end
        end
    end
end

-- the points: {thrust N, altitude ft, Mach, FCOM N1, kind}
local pts = {}
local function thrust(epr, h, m) local _, d = isa(h); return P.thrust(epr, d, m) * 1000 end
for h, row in pairs(GE_CRUISE) do
    for i, n1 in ipairs(row) do
        local w, m = G6[i] * KLB, climb_mach(h)
        local epr = by_weight(W5, PW_CRUISE[h], w)
        if epr then pts[#pts + 1] = {thrust(epr, h, m), h, m, n1, "level"} end
    end
end
for i, c in ipairs(GE_HOLD) do
    local w, m = G6[i] * KLB, mach_cas(c[2], 10000)
    local epr = by_weight(W5, PW_HOLD, w)
    if epr then pts[#pts + 1] = {thrust(epr, 10000, m), 10000, m, c[1], "holding"} end
end
for i, c in ipairs(GE_TERM0) do
    local w, m = T6[i] * KLB, mach_cas(c[2], 5000)
    local epr = by_weight(W6, PW_TERM0, w)
    if epr then pts[#pts + 1] = {thrust(epr, 5000, m), 5000, m, c[1], "terminal"} end
end
for h, row in pairs(GE_CLIMB) do
    for i, vs in ipairs(row) do
        local w, m = G6[i] * KLB, climb_mach(h)
        local epr = by_weight(W5, PW_CRUISE[h], w)
        local t = isa(h)
        local n1 = max_climb_n1(t * (1 + 0.2 * m * m) - 273.15, h)
        if epr and n1 then
            local tas = m * math.sqrt(1.4 * 287.053 * t)
            pts[#pts + 1] = {thrust(epr, h, m) + w * 1000 * G0 * (vs * 0.3048 / 60) / tas / 4, h, m, n1, "climb"}
        end
    end
end

-- each point within 2.3 % N1, the rms within 1.2
local e2, worst = 0, {0}
for _, p in ipairs(pts) do
    local t, d = isa(p[2])
    local e = Gm.n1(p[1], d, p[3], t / 288.15) - p[4]
    e2 = e2 + e * e
    if math.abs(e) > math.abs(worst[1]) then worst = {e, p} end
end
local rms = math.sqrt(e2 / #pts)
T.check(#pts == 71, string.format("the FCOM points: %d (level 30, holding 6, terminal 5, climb 30)", #pts))
T.check(rms < 1.2, string.format("the FCOM points: rms %.2f %% N1", rms))
T.check(math.abs(worst[1]) < 2.3, string.format("the worst point within 2.3 %% N1: %+.2f (%s at %d ft, M %.2f)", worst[1], worst[2][5], worst[2][2], worst[2][3]))
-- by kind: the climbs (the max climb thrust) and the level flight
for _, kind in ipairs({"level", "holding", "terminal", "climb"}) do
    local s, n = 0, 0
    for _, p in ipairs(pts) do
        if p[5] == kind then
            local t, d = isa(p[2])
            local e = Gm.n1(p[1], d, p[3], t / 288.15) - p[4]
            s, n = s + e * e, n + 1
        end
    end
    T.check(math.sqrt(s / n) < 1.5, string.format("%s: rms %.2f %% N1 over %d points", kind, math.sqrt(s / n), n))
end
-- the rated thrust standing at sea level: the go-around table's 103.8 %
T.near(Gm.n1(57160 * LBF, 1, 0, 1), 103.8, 0.5, "the rated 57,160 lbf standing at sea level, 15 C: about 103.8 % (estimate)")
-- the cruise of s280 (X-Plane 2026-11-10: FL370, M.851, 237.8 t, 39.2 kN
-- an engine): the FCOM's level %N1 (PI.20.33, 524,000 lb) about 89.1 at
-- M.84, a little more at .851
do
    local t, d = isa(37000)
    local n1 = Gm.n1(39203, d, 0.851, t / 288.15)
    T.check(n1 > 87.5 and n1 < 91.5, string.format("FL370 M.851 39.2 kN: %.1f %% (FCOM about 89.6-90.1)", n1))
end
-- rising with the thrust at every Mach; the zero thrust's N1 rising with
-- the Mach (the upstream's); above M_MAX the thrust's part held
local falls = 0
for m = 0, 0.95, 0.05 do
    for x = 0, 7, 0.05 do
        if Gm.n1c((x + 0.05) * 10000, m) <= Gm.n1c(x * 10000, m) then falls = falls + 1 end
    end
end
T.equal(falls, 0, "the N1 rises with the thrust from 0 to 70,000 lbf at M 0 to .95")
T.near(Gm.n1c(0, 0), 20.96, 1e-9, "zero thrust standing: the upstream's 20.96 %")
T.check(Gm.n1c(0, 0.8) > Gm.n1c(0, 0.4), "zero thrust: higher at a higher Mach")
T.near(Gm.n1c(40000, 0.95) - Gm.n1c(40000, 0.86), 36.93 * 0.09, 1e-9, "above M .86 only the zero thrust's Mach term moves")
T.near(Gm.n1(30000 * LBF, 0.5, 0.6, 0.8), Gm.n1c(60000, 0.6) * math.sqrt(0.8), 1e-9, "n1: the corrected thrust is F / delta, the N1 times sqrt(theta)")
T.done()
