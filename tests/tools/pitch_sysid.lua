-- Run from the repository root with LuaJIT:
--   luajit tests/tools/pitch_sysid.lua <session.csv> <t0> <t1> [lag_s] [fma]
-- Fits X-Plane's short period to a flight-test recording (the recorder's
-- session.csv, tests/flight/fwl/B747_flighttest.lua) between sim times t0
-- and t1 (only the rows with the FMA's pitch mode fma, if given): the
-- pitch acceleration and the alpha rate by least squares on the pitch rate,
-- alpha, the elevator ratio lag_s before (default 0.15), the trim ratio and
-- 1; prints the fits, R2, the mean IAS and the short period's frequency
-- and damping (6-3, after step 3b: docs/overhaul/notes/ATA-22.md §20).
local path, t0, t1 = arg[1], tonumber(arg[2]), tonumber(arg[3])
local LAG = tonumber(arg[4] or "0.15")
local FMA = arg[5]
local f = assert(io.open(path, "rb"))
local header = f:read("*l")
local h, n = {}, 0
for name in header:gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
local rows = {}
for line in f:lines() do
    local c = {}
    for v in line:gmatch("[^,]+") do c[#c + 1] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= t0 and t <= t1 and (FMA == nil or tostring(c[h.fma]) == FMA) then
        rows[#rows + 1] = {t = t, th = c[h.pitch], q = c[h.q], a = c[h.alpha], de = c[h.elevator_ratio],
            tr = c[h.trim], vs = c[h.vs], ias = c[h.ias], g = c[h.gload]}
    end
end
f:close()
print(("%d rows %.1f..%.1f s"):format(#rows, rows[1].t, rows[#rows].t))
-- resample to 0.05 s by linear interpolation
local DT = 0.05
local S = {}
local j = 1
local t = rows[1].t
while t <= rows[#rows].t do
    while rows[j + 1] and rows[j + 1].t < t do j = j + 1 end
    local r0, r1 = rows[j], rows[j + 1] or rows[j]
    local w = (r1.t > r0.t) and (t - r0.t) / (r1.t - r0.t) or 0
    local s = {t = t}
    for _, k in ipairs({"th", "q", "a", "de", "tr", "vs", "ias", "g"}) do s[k] = r0[k] + (r1[k] - r0[k]) * w end
    S[#S + 1] = s
    t = t + DT
end
-- least squares: y = X b
local function lsq(X, y)
    local m = #X[1]
    local A, B = {}, {}
    for i = 1, m do A[i] = {}; B[i] = 0; for k = 1, m do A[i][k] = 0 end end
    for r = 1, #X do
        for i = 1, m do
            B[i] = B[i] + X[r][i] * y[r]
            for k = 1, m do A[i][k] = A[i][k] + X[r][i] * X[r][k] end
        end
    end
    -- Gaussian elimination
    for i = 1, m do
        local p = i
        for r = i + 1, m do if math.abs(A[r][i]) > math.abs(A[p][i]) then p = r end end
        A[i], A[p] = A[p], A[i]; B[i], B[p] = B[p], B[i]
        for r = i + 1, m do
            local fct = A[r][i] / A[i][i]
            for k = i, m do A[r][k] = A[r][k] - fct * A[i][k] end
            B[r] = B[r] - fct * B[i]
        end
    end
    local b = {}
    for i = m, 1, -1 do
        local s = B[i]
        for k = i + 1, m do s = s - A[i][k] * b[k] end
        b[i] = s / A[i][i]
    end
    local ss, st, mean = 0, 0, 0
    for r = 1, #y do mean = mean + y[r] end
    mean = mean / #y
    for r = 1, #y do
        local yh = 0
        for i = 1, m do yh = yh + X[r][i] * b[i] end
        ss = ss + (y[r] - yh) ^ 2; st = st + (y[r] - mean) ^ 2
    end
    return b, 1 - ss / st
end
local lagn = math.floor(LAG / DT + 0.5)
local X, yq, ya = {}, {}, {}
for i = 1 + math.max(lagn, 2), #S - 2 do
    local s = S[i]
    local qd = (S[i + 1].q - S[i - 1].q) / (2 * DT)
    local ad = (S[i + 1].a - S[i - 1].a) / (2 * DT)
    X[#X + 1] = {s.q, s.a, S[i - lagn].de, s.tr, 1}
    yq[#yq + 1] = qd
    ya[#ya + 1] = ad
end
local bq, r2q = lsq(X, yq)
local ba, r2a = lsq(X, ya)
print(("lag %.2f s"):format(LAG))
print(("qdot = %.4f q + %.4f alpha + %.3f de + %.3f trim + %.4f   (R2 %.3f)"):format(bq[1], bq[2], bq[3], bq[4], bq[5], r2q))
print(("adot = %.4f q + %.4f alpha + %.3f de + %.3f trim + %.4f   (R2 %.3f)"):format(ba[1], ba[2], ba[3], ba[4], ba[5], r2a))
local ias, vs = 0, 0
for _, s in ipairs(S) do ias = ias + s.ias end
print(("mean IAS %.1f"):format(ias / #S))
-- the short period's roots
local a11, a12, a21, a22 = bq[1], bq[2], ba[1], ba[2]
local tr, det = a11 + a22, a11 * a22 - a12 * a21
local disc = tr * tr / 4 - det
if disc < 0 then
    local wd = math.sqrt(-disc)
    local wn = math.sqrt(det)
    print(("short period: wn %.3f rad/s, zeta %.3f, period %.1f s"):format(wn, -tr / 2 / wn, 2 * math.pi / wd))
else
    print(("short period: real roots %.3f %.3f"):format(tr / 2 + math.sqrt(disc), tr / 2 - math.sqrt(disc)))
end
