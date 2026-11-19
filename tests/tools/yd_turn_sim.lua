-- Run from the repository root with LuaJIT:
--   luajit tests/tools/yd_turn_sim.lua <session.csv> <fit_t0> <fit_t1> <turn_t0> <turn_t1> [TC ...]
-- The yaw dampers' turn coordination (GAP N19-AFDS-03, docs/overhaul/notes/
-- ATA-22.md §64): fits X-Plane's lateral and directional motion with the
-- yaw dampers OFF between sim times fit_t0 and fit_t1 of a flight-test
-- recording (the recorder's session.csv v7), as tests/tools/yd_design.lua
-- does (with the constants), then flies the stretch turn_t0..turn_t1 again
-- in that model with the recorded aileron (the A/P's roll ratio, corrected
-- to fly the recorded bank: the A/P flew the same roll command) and the
-- yaw damper model itself (B747.19.yd_model.lua, both modules in the
-- flight mode) on the rudders: once with no yaw damper, once with the
-- damping alone (TC_REF 0: the law of step 6b) and once for each TC (the
-- turn coordination's gain at 150 kt, rudder degrees per degree a second;
-- default 0.69, the 747-100's: NASA_SIM p.279). Prints the sideslip's
-- extremes, its value every second and the rudder's most; TRACE=1 also
-- the rudder and the bank every second. Degrees and seconds; X-Plane's
-- signs (beta = heading - flown path, the nose right of the path plus;
-- P, R and the rudder right plus).
-- 2026-11-20 on 20261103_193413_s125 (fit 1082 1190) and
-- 20261103_023047_s126 (fit 1172 1280): notes/ATA-22.md §64.
local path = arg[1]
local f0, f1, t0, t1 = tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5])
assert(path and f0 and f1 and t0 and t1, "usage: yd_turn_sim.lua <session.csv> <fit_t0> <fit_t1> <turn_t0> <turn_t1> [TC ...]")
local TCS = {}
for i = 6, #arg do TCS[#TCS + 1] = tonumber(arg[i]) end
if #TCS == 0 then TCS = {0.69} end
local Y = dofile("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.yd_model.lua")
local TAU = tonumber(os.getenv("TAU") or "") or 0.17   -- the rudder surface lag (as yd_design.lua)
local RATE = 4 * 2 / 0.3                               -- the glue's actuator: the ratio's 2 in 0.3 s (B747_interpolate_value), degrees a second
local DT = 0.05
local TRACE = os.getenv("TRACE") == "1"
-- PILOT=1: the recorded rudder added to the yaw damper's (the pedals and the
-- trim: only on a stretch flown with the yaw dampers OFF, the doublets)
local PILOT = os.getenv("PILOT") == "1"
-- the bank's tracking (aileron ratio per degree, per degree a second):
-- with the fitted roll power about 2.4 rad/s, damping 0.6; KPHI=0 KP=0 in
-- the environment replays the recorded aileron alone
local KPHI = tonumber(os.getenv("KPHI") or "") or 0.2
local KP = tonumber(os.getenv("KP") or "") or 0.1

local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs({"beta", "p", "r", "roll", "rud_upr", "rud_lwr", "roll_ratio", "ias", "tas", "alpha", "pitch", "sim_t"}) do
    assert(h[k], "no column " .. k .. " (the recorder v7)")
end
local rows = {}
local lo, hi = math.min(f0, t0), math.max(f1, t1)
for line in f:lines() do
    local c = {}
    for v in line:gmatch("[^,]+") do c[#c + 1] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= lo - 1 and t <= hi + 1 then
        rows[#rows + 1] = {t = t, b = c[h.beta], p = c[h.p], r = c[h.r], phi = c[h.roll],
            d = (c[h.rud_upr] + c[h.rud_lwr]) / 2, a = c[h.roll_ratio], ias = c[h.ias], tas = c[h.tas],
            alpha = c[h.alpha], pitch = c[h.pitch]}
    end
end
f:close()
assert(#rows > 100, "too few rows")
local KEYS = {"b", "p", "r", "phi", "d", "a", "ias", "tas", "alpha", "pitch"}
-- the recording at a time, linearly
local j = 1
local function at(t)
    if t < rows[j].t then j = 1 end
    while rows[j + 1] and rows[j + 1].t < t do j = j + 1 end
    local r0, r1 = rows[j], rows[j + 1] or rows[j]
    local w = (r1.t > r0.t) and math.max(0, math.min(1, (t - r0.t) / (r1.t - r0.t))) or 0
    local s = {t = t}
    for _, k in ipairs(KEYS) do s[k] = r0[k] + (r1[k] - r0[k]) * w end
    return s
end

-- the fit (yd_design.lua's least squares)
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
    return b
end
local S = {}
for t = f0, f1, DT do S[#S + 1] = at(t) end
local Xb, Xpr, yb, yp, yr = {}, {}, {}, {}, {}
for i = 2, #S - 1 do
    local s = S[i]
    Xb[#Xb + 1] = {s.b, s.p, s.r, s.phi, s.d, 1}
    Xpr[#Xpr + 1] = {s.b, s.p, s.r, s.a, s.d, 1}
    yb[#yb + 1] = (S[i + 1].b - S[i - 1].b) / (2 * DT)
    yp[#yp + 1] = (S[i + 1].p - S[i - 1].p) / (2 * DT)
    yr[#yr + 1] = (S[i + 1].r - S[i - 1].r) / (2 * DT)
end
local B, P, R = lsq(Xb, yb), lsq(Xpr, yp), lsq(Xpr, yr)
print(("fit %.1f..%.1f s: bb %.4f bp %.4f br %.4f bphi %.4f bd %.4f | lb %.4f lp %.4f lr %.4f la %.4f ld %.4f | nb %.4f np %.4f nr %.4f na %.4f nd %.4f"):format(
    f0, f1, B[1], B[2], B[3], B[4], B[5], P[1], P[2], P[3], P[4], P[5], R[1], R[2], R[3], R[4], R[5]))

-- one run: tc nil = no yaw damper; else TC_REF = tc
local G = Y.G
local function fly(tc)
    local saved = Y.TC_REF
    if tc then Y.TC_REF = tc end
    local s0 = at(t0)
    local x = {b = s0.b, p = s0.p, r = s0.r, phi = s0.phi, d = 0, dc = 0}
    local st, inp = Y.new(), Y.inputs()
    inp.switch[1], inp.switch[2], inp.power[1], inp.power[2] = true, true, true, true
    inp.air, inp.iru, inp.iru_nav, inp.adc = true, 3, 3, 2
    for _ = 1, 300 do Y.update(st, inp, 0.02) end        -- into the flight mode, at rest
    local h = 0.005
    local bmin, bmax, dmax = x.b, x.b, 0
    local every, rud, bank = {}, {}, {}
    local cmd = 0
    local t, k = t0, 0
    while t < t1 do
        local s = at(t)
        local tth = math.tan(math.rad(s.pitch))
        local q = x.r * math.tan(math.rad(x.phi))          -- a level turn's pitch rate
        local pilot = PILOT and s.d or 0
        local db = B[1] * x.b + B[2] * x.p + B[3] * x.r + B[4] * x.phi + B[5] * (x.d + pilot) + B[6]
        if k % 4 == 0 and tc then
            -- the yaw damper's inputs; the lateral load factor that makes its
            -- kinematic sideslip rate the model's
            local a, th, ph = math.rad(s.alpha), math.rad(s.pitch), math.rad(x.phi)
            inp.cas, inp.tas, inp.gs = s.ias, s.tas, s.tas
            inp.alpha, inp.pitch, inp.roll = s.alpha, s.pitch, x.phi
            inp.p, inp.q, inp.r = x.p, q, x.r
            inp.ny = (s.tas * (math.rad(x.r) * math.cos(a) - math.rad(x.p) * math.sin(a) - math.rad(db)) - G * math.cos(th) * math.sin(ph)) / G
            local out = Y.update(st, inp, 0.02)
            cmd = (out.cmd[1] + out.cmd[2]) / 2
        end
        -- the glue's rate, then the surface's lag
        x.dc = x.dc + math.max(-RATE * h, math.min(RATE * h, cmd - x.dc))
        -- the A/P's aileron: the recorded one, corrected to hold the recorded
        -- bank and roll rate (the A/P flew the same roll command each time)
        local ail = s.a + KPHI * (s.phi - x.phi) + KP * (s.p - x.p)
        local dp = P[1] * x.b + P[2] * x.p + P[3] * x.r + P[4] * ail + P[5] * (x.d + pilot) + P[6]
        local dr = R[1] * x.b + R[2] * x.p + R[3] * x.r + R[4] * ail + R[5] * (x.d + pilot) + R[6]
        x.b, x.p, x.r = x.b + db * h, x.p + dp * h, x.r + dr * h
        x.phi = x.phi + (x.p + (q * math.sin(math.rad(x.phi)) + x.r * math.cos(math.rad(x.phi))) * tth) * h
        x.d = x.d + (x.dc - x.d) / TAU * h
        bmin, bmax, dmax = math.min(bmin, x.b), math.max(bmax, x.b), math.max(dmax, math.abs(x.d))
        k = k + 1
        t = t0 + k * h
        if k % 200 == 0 then every[#every + 1] = ("%5.2f"):format(x.b); rud[#rud + 1] = ("%5.2f"):format(x.d); bank[#bank + 1] = ("%5.1f"):format(x.phi) end
    end
    Y.TC_REF = saved
    return bmin, bmax, dmax, table.concat(every, " "), table.concat(rud, " "), table.concat(bank, " ")
end

-- the recording itself
do
    local bmin, bmax, every = math.huge, -math.huge, {}
    local k = 0
    for t = t0, t1, 0.005 do
        local s = at(t)
        bmin, bmax = math.min(bmin, s.b), math.max(bmax, s.b)
        k = k + 1
        if k % 200 == 1 and k > 1 then every[#every + 1] = ("%5.2f"):format(s.b) end
    end
    print(("recorded          beta %5.2f .. %5.2f | %s"):format(bmin, bmax, table.concat(every, " ")))
end
local function show(name, tc)
    local bmin, bmax, dmax, every, rud, bank = fly(tc)
    print(("%-17s beta %5.2f .. %5.2f, rudder up to %.2f | %s"):format(name, bmin, bmax, dmax, every))
    if TRACE then print(("%-17s rudder %s"):format("", rud)); print(("%-17s bank   %s"):format("", bank)) end
end
show("no yaw damper", nil)
show("damping (6b)", 0)
for _, tc in ipairs(TCS) do show(("TC %.2f at 150 kt"):format(tc), tc) end
