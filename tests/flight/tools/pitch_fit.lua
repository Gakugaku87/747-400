-- Run from the repository root with LuaJIT:
--   luajit tests/flight/tools/pitch_fit.lua <session.csv> <t0> <t1> [lag_s]
-- The short period's dimensional derivatives from a kit recording with the
-- A/P off (2026-11-20, GAP N19-AERO-02, docs/overhaul/notes/AERO.md §3.24):
-- least squares over X-Plane's time t0..t1 of
--   q_dot     = Mq q + Ma (alpha - a0) + Mde (de - de0) + c      (1/s, 1/s2, 1/s2)
--   alpha_dot = Za (alpha - a0) + q + Zde (de - de0) + d  (constant speed)
-- with q in degrees a second, alpha and the elevator (the left inner, the
-- recorder's elev_deg; minus is trailing edge up) in degrees, q_dot and
-- alpha_dot from the 0.3 s smoothed q and alpha by central differences, the
-- elevator taken lag_s earlier (the surface to the moment; default 0). The
-- same units as NASA_HQ's table IX-4 (per radian), with M_alpha = U0 M_w:
-- the 747-100's FL400 M.80 Mq -0.339, M_alpha -0.813, Mde -1.16 (p.236).
-- Prints the fit, R2, the short period's undamped frequency and damping
-- from the q and alpha pair, and the steady elevator per g it implies.
local path, t0, t1, lag = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4] or "0")
assert(path and t0 and t1, "usage: pitch_fit.lua <session.csv> <t0> <t1> [lag_s]")
local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs{"sim_t", "q", "alpha", "elev_deg", "gload", "tas"} do assert(h[k], "no column " .. k) end
local T, Q, A, E, G, V = {}, {}, {}, {}, {}, {}
for line in f:lines() do
    local c, k = {}, 0
    for v in (line .. ","):gmatch("([^,]*),") do k = k + 1; c[k] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= t0 - 2 and t <= t1 + 2 then
        T[#T + 1], Q[#Q + 1], A[#A + 1], E[#E + 1], G[#G + 1], V[#V + 1] = t, c[h.q], c[h.alpha], c[h.elev_deg], c[h.gload], c[h.tas]
    end
end
f:close()
local N = #T
local function smooth(X, i, half)
    local s, m = 0, 0
    for j = i, 1, -1 do if T[i] - T[j] > half then break end s, m = s + X[j], m + 1 end
    for j = i + 1, N do if T[j] - T[i] > half then break end s, m = s + X[j], m + 1 end
    return s / m
end
local QS, AS = {}, {}
for i = 1, N do QS[i], AS[i] = smooth(Q, i, 0.15), smooth(A, i, 0.15) end
local function at(X, t)        -- linear interpolation in time
    if t <= T[1] then return X[1] end
    for i = 2, N do if T[i] >= t then
        local w = (t - T[i - 1]) / (T[i] - T[i - 1]); return X[i - 1] + w * (X[i] - X[i - 1]) end end
    return X[N]
end
-- the trim point: the 2 s before t0
local a0, de0 = 0, 0
do local s1, s2, m = 0, 0, 0
    for i = 1, N do if T[i] >= t0 - 2 and T[i] < t0 then s1, s2, m = s1 + A[i], s2 + E[i], m + 1 end end
    if m > 0 then a0, de0 = s1 / m, s2 / m end end
-- least squares by normal equations
local function solve(M, b, k)
    for i = 1, k do
        local p = i
        for r = i + 1, k do if math.abs(M[r][i]) > math.abs(M[p][i]) then p = r end end
        M[i], M[p] = M[p], M[i]; b[i], b[p] = b[p], b[i]
        for r = i + 1, k do
            local fct = M[r][i] / M[i][i]
            for cc = i, k do M[r][cc] = M[r][cc] - fct * M[i][cc] end
            b[r] = b[r] - fct * b[i]
        end
    end
    local x = {}
    for i = k, 1, -1 do
        local s = b[i]
        for cc = i + 1, k do s = s - M[i][cc] * x[cc] end
        x[i] = s / M[i][i]
    end
    return x
end
local function fit(rows)
    local k = #rows[1].x
    local M, b = {}, {}
    for i = 1, k do M[i] = {}; b[i] = 0; for j = 1, k do M[i][j] = 0 end end
    local ysum, yy, cnt = 0, 0, 0
    for _, r in ipairs(rows) do
        for i = 1, k do
            b[i] = b[i] + r.x[i] * r.y
            for j = 1, k do M[i][j] = M[i][j] + r.x[i] * r.x[j] end
        end
        ysum, yy, cnt = ysum + r.y, yy + r.y * r.y, cnt + 1
    end
    local x = solve(M, b, k)
    local ss, mean = 0, ysum / cnt
    local st = yy - cnt * mean * mean
    for _, r in ipairs(rows) do
        local p = 0
        for i = 1, k do p = p + x[i] * r.x[i] end
        ss = ss + (r.y - p) ^ 2
    end
    return x, 1 - ss / st, cnt
end
local rq, ra = {}, {}
local vsum, vm = 0, 0
for i = 2, N - 1 do
    if T[i] >= t0 and T[i] <= t1 then
        local dt = T[i + 1] - T[i - 1]
        if dt > 0 then
            local qd = (QS[i + 1] - QS[i - 1]) / dt
            local ad = (AS[i + 1] - AS[i - 1]) / dt
            local de = at(E, T[i] - lag) - de0
            local da = AS[i] - a0
            rq[#rq + 1] = {y = qd, x = {QS[i], da, de, 1}}
            ra[#ra + 1] = {y = ad - QS[i], x = {da, de, 1}}
            vsum, vm = vsum + V[i], vm + 1
        end
    end
end
local xq, r2q, nq = fit(rq)
local xa, r2a = fit(ra)
local Mq, Ma, Mde = xq[1], xq[2], xq[3]
local Za = xa[1]
print(string.format("%d samples %.1f..%.1f s, trim alpha %.2f elevator %.2f, TAS %.0f m/s, elevator lag %.2f s", nq, t0, t1, a0, de0, vsum / vm, lag))
print(string.format("q_dot = %.3f q %+.3f alpha %+.3f de %+.3f   (R2 %.3f)", Mq, Ma, Mde, xq[4], r2q))
print(string.format("alpha_dot - q = %.3f alpha %+.3f de %+.3f   (R2 %.3f)", Za, xa[2], xa[3], r2a))
-- the short period from [Mq Ma; 1 Za] (q, alpha)
local tr = Mq + Za
local det = Mq * Za - Ma
local wn = math.sqrt(math.max(det, 0))
local zeta = wn > 0 and -tr / (2 * wn) or 0/0
print(string.format("short period: wn %.3f rad/s, damping %.3f, period %.1f s", wn, zeta, wn > 0 and 2 * math.pi / (wn * math.sqrt(math.max(1 - zeta * zeta, 1e-6))) or 0/0))
-- the steady pull-up: q = g dn / V, alpha_dot = 0 -> alpha from the alpha
-- equation with the n term, q_dot = 0 -> the elevator
local V0 = vsum / vm
local q1 = 9.80665 / V0 * 57.2958          -- deg/s per g
-- alpha_dot - q = Za da + Zde de ; steady: -q = Za da + Zde de (q = g/V per g)
-- q_dot = 0 = Mq q + Ma da + Mde de
-- two equations in da, de for dn = 1, q = q1
local Zde = xa[2]
local a11, a12, b1 = Za, Zde, -q1
local a21, a22, b2 = Ma, Mde, -Mq * q1
local dd = a11 * a22 - a12 * a21
local da = (b1 * a22 - a12 * b2) / dd
local de = (a11 * b2 - b1 * a21) / dd
print(string.format("steady pull-up per g: alpha %+.2f deg, elevator %+.2f deg", da, de))
