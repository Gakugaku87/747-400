-- luajit tests/flight/tools/ge_n1_fit.lua (from the repository root): the fit
-- of the GE display N1 (plugins/xtlua/scripts/B747.42.xt.EEC/
-- B747.42.ge_n1_model.lua, notes/ATA-70-80.md §17, 2026-11-10). The points:
-- the FCOM's %N1 (747-400F/CF6-80C2B1F: PI.20.31 p.359 max climb %N1,
-- PI.20.33 p.361 climb rates and level %N1, PI.20.34 p.362 holding, the
-- terminal area, the final approach) at the thrust the same flight needs on
-- the custom acf - the PW4056 FCOM's EPR at that weight and speed
-- (PI.10.38-10.40 p.264-266) through the EPR model (B747.42.epr_model.lua),
-- the climbs with the climb's power and its acceleration along the 290 KIAS / .84
-- schedule (m (g V/S / TAS + dTAS/dh V/S)). The form: N1c (N1 /
-- sqrt(theta static)) = n0(M) + k(M) x^(q0 + q1 M), x = F / delta in 10,000
-- lbf, n0 the model's (the upstream's zero-thrust N1), k cubic in the
-- Mach by least squares, q0 and q1 on a grid; fitted to the clean points
-- (level, holding, terminal flaps up, climbs) and the static anchor (the
-- rated 57,160 lbf at the go-around table's 103.8 %, estimate). Prints the
-- constants, the errors by kind (the extended flaps and the final approach
-- not fitted, kept to check) and the drag the terminal-area and final-
-- approach rows ask by each table (notes/ATA-70-80.md §19: the CF6 table's
-- flaps 10 and 20 do not fit its own other rows). Redo it
-- when the EPR model changes (the points' thrust comes from it); the same
-- points are tests/eec/ge_n1_model_test.lua's
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
local PW_TERM = {
    [0] = {1.01, 1.03, 1.04, 1.06, 1.07, 1.08}, [1] = {1.03, 1.05, 1.06, 1.08, 1.10, 1.10},
    [5] = {1.06, 1.08, 1.10, 1.12, 1.15, 1.15}, [10] = {1.07, 1.09, 1.11, 1.14, 1.16, 1.17},
    [20] = {1.10, 1.13, 1.17, 1.21, 1.25, 1.26},
}
local PW_FINAL = {[25] = {1.05, 1.06, 1.07, 1.08, 1.10, 1.10}, [30] = {1.07, 1.09, 1.11}}
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
local GE_TERM = {
    [0] = {{54.3, 202}, {59.9, 217}, {64.8, 231}, {69.1, 244}, {72.9, 256}, {76.3, 268}},
    [1] = {{56.6, 182}, {62.0, 197}, {66.9, 211}, {71.2, 224}, {75.0, 236}, {78.3, 248}},
    [5] = {{59.4, 162}, {65.5, 177}, {70.7, 191}, {75.1, 204}, {79.0, 216}, {82.4, 228}},
    [10] = {{66.5, 142}, {72.8, 157}, {78.2, 171}, {82.8, 184}, {86.7, 196}, {90.2, 208}},
    [20] = {{71.1, 132}, {77.6, 147}, {83.1, 161}, {87.7, 174}, {91.9, 186}, {95.5, 198}},
}
local GE_FINAL = {
    [25] = {{50.9, 136}, {56.3, 152}, {61.2, 166}, {65.2, 180}, {68.9, 193}, {72.2, 205}},
    [30] = {{56.6, 131}, {62.5, 146}, {67.5, 160}, {71.9, 173}, {75.8, 185}},
}
-- the max climb %N1 at the climbs' altitudes by TAT (deg C)
local MC_ALT = {0, 10, 20, 30, 35, 40}
local MC = {
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

-- the points: {fc lbf, Mach, N1c, kind, theta}
local pts = {}
local function add(kind, h, m, f, n1)
    local t, d = isa(h)
    pts[#pts + 1] = {fc = f / d / LBF, m = m, n1c = n1 / math.sqrt(t / 288.15), kind = kind, th = math.sqrt(t / 288.15)}
end
local function thrust(epr, h, m) local _, d = isa(h); return P.thrust(epr, d, m) * 1000 end
for h, row in pairs(GE_CRUISE) do
    for i, n1 in ipairs(row) do
        local w, m = G6[i] * KLB, climb_mach(h)
        local epr = by_weight(W5, PW_CRUISE[h], w)
        if epr then add("level", h, m, thrust(epr, h, m), n1) end
    end
end
for i, c in ipairs(GE_HOLD) do
    local w, m = G6[i] * KLB, mach_cas(c[2], 10000)
    local epr = by_weight(W5, PW_HOLD, w)
    if epr then add("holding", 10000, m, thrust(epr, 10000, m), c[1]) end
end
for flap, row in pairs(GE_TERM) do
    for i, c in ipairs(row) do
        local w, m = T6[i] * KLB, mach_cas(c[2], 5000)
        local epr = by_weight(W6, PW_TERM[flap], w)
        if epr then add("terminal" .. flap, 5000, m, thrust(epr, 5000, m), c[1]) end
    end
end
for flap, row in pairs(GE_FINAL) do
    for i, c in ipairs(row) do
        local w, m = T6[i] * KLB, mach_cas(c[2], 1500)
        local epr = by_weight(flap == 30 and {200, 250, 300} or W6, PW_FINAL[flap], w)
        if epr then add("final" .. flap, 1500, m, thrust(epr, 1500, m), c[1]) end
    end
end
-- the TAS (m/s) along the climb's schedule (290 KIAS, .84 above) and its
-- change with height (m/s a metre): at 290 KIAS the TAS grows as the airplane
-- climbs, and that acceleration takes thrust too (2026-11-10: left out at
-- first, the fit gave 6-7 kN too little at 30,000 ft and the GE climbed 15 %
-- slow there in X-Plane, s282; the PW4056 at the Max Climb EPR needs 75 kN
-- an engine at 30,000 ft for its FCOM rate, aero_climb_maxclb 2026-11-09)
local function climb_tas(h) local t = isa(h); return climb_mach(h) * math.sqrt(1.4 * 287.053 * t) end
local function climb_dvdh(h) return (climb_tas(h + 50) - climb_tas(h - 50)) / (100 * 0.3048) end
for h, row in pairs(GE_CLIMB) do
    for i, vs in ipairs(row) do
        local w, m = G6[i] * KLB, climb_mach(h)
        local epr = by_weight(W5, PW_CRUISE[h], w)
        local t = isa(h)
        local n1 = max_climb_n1(t * (1 + 0.2 * m * m) - 273.15, h)
        if epr and n1 then
            local vz = vs * 0.3048 / 60
            local climb = w * 1000 * (G0 * vz / climb_tas(h) + climb_dvdh(h) * vz) / 4
            add("climb", h, m, thrust(epr, h, m) + climb, n1)
        end
    end
end
local CLEAN = {level = true, holding = true, terminal0 = true, climb = true}
local fitted = {}
for _, p in ipairs(pts) do if CLEAN[p.kind] then fitted[#fitted + 1] = p end end
fitted[#fitted + 1] = {fc = 57160, m = 0, n1c = 103.8, kind = "anchor", th = 1, w = 3}

-- k(M), cubic in the Mach, for q0, q1 by least squares (4 x 4, Gaussian
-- elimination); the Mach as the points have it (all at .84 or under)
local NK = 4
local function solve(A, b)
    local n = #b
    for c = 1, n do
        local p = c
        for r = c + 1, n do if math.abs(A[r][c]) > math.abs(A[p][c]) then p = r end end
        A[c], A[p], b[c], b[p] = A[p], A[c], b[p], b[c]
        for r = c + 1, n do
            local f = A[r][c] / A[c][c]
            for k = c, n do A[r][k] = A[r][k] - f * A[c][k] end
            b[r] = b[r] - f * b[c]
        end
    end
    local x = {}
    for r = n, 1, -1 do
        local s = b[r]
        for k = r + 1, n do s = s - A[r][k] * x[k] end
        x[r] = s / A[r][r]
    end
    return x
end
local function n0(m) return Gm.N0[1] + Gm.N0[2] * m end
local function fit(q0, q1)
    local A, b = {}, {}
    for i = 1, NK do A[i] = {}; for j = 1, NK do A[i][j] = 0 end; b[i] = 0 end
    for _, p in ipairs(fitted) do
        local w = p.w or 1
        local xq = (p.fc / 10000) ^ (q0 + q1 * p.m)
        local bs = {xq, xq * p.m, xq * p.m ^ 2, xq * p.m ^ 3}
        for i = 1, NK do
            b[i] = b[i] + w * bs[i] * (p.n1c - n0(p.m))
            for j = 1, NK do A[i][j] = A[i][j] + w * bs[i] * bs[j] end
        end
    end
    local k = solve(A, b)
    local f = function(fc, m)
        return n0(m) + (k[1] + m * (k[2] + m * (k[3] + m * k[4]))) * (fc / 10000) ^ (q0 + q1 * m)
    end
    local e2, n = 0, 0
    for _, p in ipairs(fitted) do
        if p.kind ~= "anchor" then
            local e = (f(p.fc, p.m) - p.n1c) * p.th
            e2, n = e2 + e * e, n + 1
        end
    end
    return math.sqrt(e2 / n), k, f
end
local best
for q0 = 0.30, 1.2001, 0.01 do
    for q1 = -1.0, 1.0001, 0.02 do
        local rms, k, f = fit(q0, q1)
        if rms == rms and (not best or rms < best.rms) then best = {rms = rms, q0 = q0, q1 = q1, k = k, f = f} end
    end
end
print(string.format("q0 %.2f  q1 %.2f  k %.4f %.4f %.4f %.4f  (rms %.2f %% N1 over %d clean points)",
    best.q0, best.q1, best.k[1], best.k[2], best.k[3], best.k[4], best.rms, #fitted - 1))
print("the model now: q0 " .. Gm.Q[1] .. "  q1 " .. Gm.Q[2] .. "  k " .. table.concat(Gm.K, " "))
local groups, order = {}, {}
for _, p in ipairs(pts) do
    local g = groups[p.kind]
    if not g then g = {n = 0, e = 0, m = 0}; groups[p.kind] = g; order[#order + 1] = p.kind end
    local e = (best.f(p.fc, p.m) - p.n1c) * p.th
    g.n, g.e = g.n + 1, g.e + e * e
    if math.abs(e) > math.abs(g.m) then g.m = e end
end
table.sort(order)
for _, kind in ipairs(order) do
    local g = groups[kind]
    print(string.format("  %-10s %3d points: rms %5.2f  max %+6.2f %% N1%s", kind, g.n, math.sqrt(g.e / g.n), g.m, CLEAN[kind] and "" or "  (not fitted)"))
end

-- the drag each table's terminal-area (level) and final-approach (gear down,
-- 3 deg) rows ask, 2026-11-10 (notes/ATA-70-80.md §19): D = 4 F level, 4 F +
-- W sin 3 deg on the glide slope; F the PW4056's EPR through the EPR model or
-- the CF6's %N1 through the N1 model now turned around, both at the CF6
-- table's KIAS (the PW4056's within a knot). The two tables agree but at
-- flaps 10 and 20, where the CF6's asks about 40 % more and its flaps 20
-- (gear down, level) more than its own flaps 25 and 30 (gear down, 3 deg;
-- flaps 30 at the same VREF30+10): the opposite of more flap
local function ge_thrust(n1, h, m)
    local t, d = isa(h)
    local lo, hi = 0, 400000
    for _ = 1, 60 do
        local mid = (lo + hi) / 2
        if Gm.n1(mid, d, m, t / 288.15) < n1 then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end
local SIN3 = math.sin(math.rad(3))
print("the drag the rows ask (kN, the PW4056 / the CF6; 25 and 30 on the 3 deg glide slope):")
for i = 2, 3 do -- 500,000 and 600,000 lb: in both tables' weights
    local w = T6[i] * KLB
    local line, dd = {}, {}
    for _, flap in ipairs({0, 1, 5, 10, 20, 25, 30}) do
        local fin = flap >= 25
        local c = (fin and GE_FINAL or GE_TERM)[flap][i]
        local h = fin and 1500 or 5000
        local m = mach_cas(c[2], h)
        local epr = fin and by_weight(flap == 30 and {200, 250, 300} or W6, PW_FINAL[flap], w)
            or by_weight(W6, PW_TERM[flap], w)
        local slope = fin and w * 1000 * G0 * SIN3 or 0
        local dp, dg = 4 * thrust(epr, h, m) + slope, 4 * ge_thrust(c[1], h, m) + slope
        dd[flap] = {dp, dg}
        line[#line + 1] = string.format("%d %.0f/%.0f", flap, dp / 1000, dg / 1000)
    end
    print(string.format("  %d,000 lb: %s", T6[i], table.concat(line, "  ")))
    print(string.format("    flaps 20 (level) / flaps 25, 30 (3 deg), all gear down: the PW4056 %.2f, %.2f; the CF6 %.2f, %.2f",
        dd[20][1] / dd[25][1], dd[20][1] / dd[30][1], dd[20][2] / dd[25][2], dd[20][2] / dd[30][2]))
end
