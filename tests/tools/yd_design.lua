-- Run from the repository root with LuaJIT:
--   luajit tests/tools/yd_design.lua <session.csv> <t0> <t1> [K ...]
-- The yaw dampers' law (6-3 step 6b, docs/overhaul/notes/ATA-22.md §40):
-- fits X-Plane's lateral and directional motion with the yaw dampers OFF
-- between sim times t0 and t1 of a flight-test recording (the recorder's
-- session.csv v7: the rudders in degrees, rud_upr and rud_lwr), with the
-- rudder in degrees (the two rudders' mean) and the A/P's aileron ratio as
-- the inputs:
--   beta' = bb b + bp p + br r + bphi phi + bd rud
--   p'    = lb b + lp p + lr r + la ail + ld rud
--   r'    = nb b + np p + nr r + na ail + nd rud
-- (degrees and seconds; X-Plane's signs: beta = heading - flown path, the
-- nose right of the path plus; P, R and the rudder right plus). Then it
-- closes the loop with a sideslip-rate damper on both rudders, rud =
-- -K beta' through a first-order actuator of TAU s, no aileron, and
-- prints for each K (degrees of rudder per degree per second; default a
-- range) the dutch roll's period and damping ratio from an initial 2
-- degrees of sideslip, and the rudder per degree of bank that holds a
-- steady level turn without sideslip (the turn coordination).
-- With CLOSED=1 in the environment the input is the pedals' and trim's
-- (rud_in, a ratio) instead of the rudders: fitted on a stretch with the
-- yaw dampers ON, K 0's line is then the closed loop's dutch roll (the
-- input through the rudders' lag, TAU, as they follow it).
local path, t0, t1 = arg[1], tonumber(arg[2]), tonumber(arg[3])
assert(path and t0 and t1, "usage: yd_design.lua <session.csv> <t0> <t1> [K ...]")
local KS = {}
for i = 4, #arg do KS[#KS + 1] = tonumber(arg[i]) end
if #KS == 0 then KS = {0, 0.5, 1, 1.5, 2, 3, 4, 6} end
local TAU = tonumber(os.getenv("TAU") or "") or 0.17   -- the rudder surface lag (B747_animate_value at 60 fps: 0.1 a frame)
local DT = 0.05
local CLOSED = os.getenv("CLOSED") == "1"

local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs({"beta", "p", "r", "roll", "rud_upr", "rud_lwr", "roll_ratio", "ias", "tas", "sim_t"}) do
    assert(h[k], "no column " .. k .. " (the recorder v7)")
end
local rows = {}
local din, tprev = 0, nil
for line in f:lines() do
    local c = {}
    for v in line:gmatch("[^,]+") do c[#c + 1] = tonumber(v) end
    local t = c[h.sim_t]
    if t and c[h.rud_in] then
        if tprev then din = din + (c[h.rud_in] - din) * math.min(1, (t - tprev) / TAU) end
        tprev = t
    end
    if t and t >= t0 and t <= t1 then
        rows[#rows + 1] = {t = t, b = c[h.beta], p = c[h.p], r = c[h.r], phi = c[h.roll],
            d = CLOSED and din or (c[h.rud_upr] + c[h.rud_lwr]) / 2, a = c[h.roll_ratio], ias = c[h.ias], tas = c[h.tas]}
    end
end
f:close()
assert(#rows > 100, "too few rows")
-- resample to DT
local KEYS = {"b", "p", "r", "phi", "d", "a", "ias", "tas"}
local S = {}
local j = 1
local t = rows[1].t
while t <= rows[#rows].t do
    while rows[j + 1] and rows[j + 1].t < t do j = j + 1 end
    local r0, r1 = rows[j], rows[j + 1] or rows[j]
    local w = (r1.t > r0.t) and (t - r0.t) / (r1.t - r0.t) or 0
    local s = {t = t}
    for _, k in ipairs(KEYS) do s[k] = r0[k] + (r1[k] - r0[k]) * w end
    S[#S + 1] = s
    t = t + DT
end
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
    local mean = 0
    for r = 1, #y do mean = mean + y[r] end
    mean = mean / #y
    local ss, sr = 0, 0
    for r = 1, #y do
        local e = y[r]
        for i = 1, m do e = e - X[r][i] * b[i] end
        ss = ss + (y[r] - mean) ^ 2; sr = sr + e * e
    end
    return b, 1 - sr / ss
end
local Xb, Xpr, yb, yp, yr = {}, {}, {}, {}, {}
local ias, tas = 0, 0
for i = 2, #S - 1 do
    local s = S[i]
    Xb[#Xb + 1] = {s.b, s.p, s.r, s.phi, s.d, 1}
    Xpr[#Xpr + 1] = {s.b, s.p, s.r, s.a, s.d, 1}
    yb[#yb + 1] = (S[i + 1].b - S[i - 1].b) / (2 * DT)
    yp[#yp + 1] = (S[i + 1].p - S[i - 1].p) / (2 * DT)
    yr[#yr + 1] = (S[i + 1].r - S[i - 1].r) / (2 * DT)
    ias, tas = ias + s.ias, tas + s.tas
end
ias, tas = ias / #Xb, tas / #Xb
local B, rb = lsq(Xb, yb)
local P, rp = lsq(Xpr, yp)
local R, rr = lsq(Xpr, yr)
print(("%d samples, IAS %.1f kt, TAS %.1f m/s"):format(#Xb, ias, tas))
print(("beta' R2 %.3f: bb %.4f bp %.4f br %.4f bphi %.4f bd %.4f"):format(rb, B[1], B[2], B[3], B[4], B[5]))
print(("p'    R2 %.3f: lb %.4f lp %.4f lr %.4f la %.4f ld %.4f"):format(rp, P[1], P[2], P[3], P[4], P[5]))
print(("r'    R2 %.3f: nb %.4f np %.4f nr %.4f na %.4f nd %.4f"):format(rr, R[1], R[2], R[3], R[4], R[5]))
print(("return {ias = %.1f, tas = %.1f, bb = %.4f, bp = %.4f, br = %.4f, bphi = %.4f, bd = %.4f,"):format(ias, tas, B[1], B[2], B[3], B[4], B[5]))
print(("    lb = %.4f, lp = %.4f, lr = %.4f, la = %.4f, ld = %.4f,"):format(P[1], P[2], P[3], P[4], P[5]))
print(("    nb = %.4f, np = %.4f, nr = %.4f, na = %.4f, nd = %.4f}"):format(R[1], R[2], R[3], R[4], R[5]))

-- the closed loop: x = {b, p, r, phi, d}
local function deriv(x, K)
    local b, p, r, phi, d = x[1], x[2], x[3], x[4], x[5]
    local db = B[1] * b + B[2] * p + B[3] * r + B[4] * phi + B[5] * d
    local cmd = -K * db
    return {db, P[1] * b + P[2] * p + P[3] * r + P[5] * d, R[1] * b + R[2] * p + R[3] * r + R[5] * d, p, (cmd - d) / TAU}
end
local function sim(K)
    local x = {2, 0, 0, 0, 0}
    local h = 0.01
    local peaks, prev, prev2 = {}, nil, nil
    local maxd = 0
    for i = 1, 6000 do
        local k1 = deriv(x, K)
        local x2 = {}; for q = 1, 5 do x2[q] = x[q] + 0.5 * h * k1[q] end
        local k2 = deriv(x2, K)
        local x3 = {}; for q = 1, 5 do x3[q] = x[q] + 0.5 * h * k2[q] end
        local k3 = deriv(x3, K)
        local x4 = {}; for q = 1, 5 do x4[q] = x[q] + h * k3[q] end
        local k4 = deriv(x4, K)
        for q = 1, 5 do x[q] = x[q] + h / 6 * (k1[q] + 2 * k2[q] + 2 * k3[q] + k4[q]) end
        maxd = math.max(maxd, math.abs(x[5]))
        -- the extremes of the sideslip
        if prev2 and math.abs(prev) >= math.abs(prev2) and math.abs(prev) > math.abs(x[1]) and math.abs(prev) > 0.002 then
            peaks[#peaks + 1] = {t = (i - 1) * h, v = prev}
        end
        prev2, prev = prev, x[1]
    end
    -- the damping from successive extremes of the same sign
    local z, per = nil, nil
    for q = 1, #peaks - 2 do
        local a, c = peaks[q], peaks[q + 2]
        if a.v * c.v > 0 and math.abs(c.v) < math.abs(a.v) then
            local dl = math.log(math.abs(a.v) / math.abs(c.v))
            z = dl / math.sqrt(4 * math.pi ^ 2 + dl * dl)
            per = c.t - a.t
            break
        end
    end
    return z, per, maxd, #peaks
end
-- the closed loop's eigenvalues: the characteristic polynomial by
-- Faddeev-LeVerrier, its roots by Durand-Kerner (complex as {re, im})
local function matrix(K)
    local t = TAU
    return {
        {B[1], B[2], B[3], B[4], B[5]},
        {P[1], P[2], P[3], 0, P[5]},
        {R[1], R[2], R[3], 0, R[5]},
        {0, 1, 0, 0, 0},
        {-K * B[1] / t, -K * B[2] / t, -K * B[3] / t, -K * B[4] / t, (-K * B[5] - 1) / t},
    }
end
local function charpoly(A)
    local m = #A
    local function mul(X, Y)
        local Z = {}
        for i = 1, m do Z[i] = {}; for k = 1, m do local s = 0; for q = 1, m do s = s + X[i][q] * Y[q][k] end; Z[i][k] = s end end
        return Z
    end
    local c = {[m] = 1}         -- c[k]: the coefficient of s^k
    local M = {}
    for i = 1, m do M[i] = {}; for k = 1, m do M[i][k] = 0 end end
    for k = 1, m do
        local AM = mul(A, M)
        for i = 1, m do AM[i][i] = AM[i][i] + c[m - k + 1] end
        M = AM
        local AMk = mul(A, M)
        local tr = 0
        for i = 1, m do tr = tr + AMk[i][i] end
        c[m - k] = -tr / k
    end
    return c
end
local function roots(c, m)
    local function cmul(a, b) return {a[1] * b[1] - a[2] * b[2], a[1] * b[2] + a[2] * b[1]} end
    local function csub(a, b) return {a[1] - b[1], a[2] - b[2]} end
    local function cdiv(a, b) local d = b[1] ^ 2 + b[2] ^ 2; return {(a[1] * b[1] + a[2] * b[2]) / d, (a[2] * b[1] - a[1] * b[2]) / d} end
    local function eval(z)
        local v = {c[m], 0}
        for k = m - 1, 0, -1 do v = cmul(v, z); v[1] = v[1] + c[k] end
        return v
    end
    local z = {}
    for k = 1, m do z[k] = {math.cos(2 * math.pi * k / m + 0.4) * 0.9, math.sin(2 * math.pi * k / m + 0.4) * 0.9} end
    for _ = 1, 500 do
        for k = 1, m do
            local den = {c[m], 0}
            for q = 1, m do if q ~= k then den = cmul(den, csub(z[k], z[q])) end end
            z[k] = csub(z[k], cdiv(eval(z[k]), den))
        end
    end
    return z
end
for _, K in ipairs(KS) do
    local z, per, maxd = sim(K)
    local ev = roots(charpoly(matrix(K)), 5)
    local dr
    for _, e in ipairs(ev) do
        if e[2] > 0.05 and (not dr or e[2] > dr[2]) then dr = e end
    end
    local txt = "no dutch roll pair"
    if dr then
        local w = math.sqrt(dr[1] ^ 2 + dr[2] ^ 2)
        txt = ("dutch roll %.3f rad/s, damping %.3f, period %.1f s"):format(w, -dr[1] / w, 2 * math.pi / dr[2])
    end
    local others = {}
    for _, e in ipairs(ev) do if math.abs(e[2]) <= 0.05 then others[#others + 1] = ("%.3f"):format(e[1]) end end
    print(("K %.2f: %s; real %s; the rudder up to %.2f deg for 2 deg of sideslip"):format(K, txt, table.concat(others, " "), maxd))
end
-- the turn coordination: a steady level turn at 1 degree of bank, no
-- sideslip: r = 57.3 g sin(phi) / TAS, then beta' = 0 gives the rudder
local g = 9.80665
local r1 = math.deg(g * math.sin(math.rad(1)) / tas)
local d1 = -(B[3] * r1 + B[4] * 1) / B[5]
print(("turn coordination: %.4f deg of rudder per degree of bank (yaw rate %.3f deg/s per degree); r' then %.4f, p' %.4f"):format(
    d1, r1, R[3] * r1 + R[5] * d1, P[3] * r1 + P[5] * d1))
