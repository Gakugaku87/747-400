-- Run from the repository root with LuaJIT:
--   luajit tests/tools/lat_sysid.lua <session.csv> <t0> <t1> [lag_s]
-- Fits X-Plane's lateral and directional motion to a flight-test recording
-- (the recorder's session.csv v6, tests/flight/fwl/B747_flighttest.lua)
-- between sim times t0 and t1 by least squares, for the A/P's rudder laws
-- (6-3 step 4d, runway align: docs/overhaul/notes/ATA-22.md §29):
--   the sideslip rate on the sideslip, the roll and yaw rates, the bank,
--   the rudder input and 1;
--   the roll and yaw accelerations on the sideslip, the roll and yaw rates,
--   the aileron ratio and the rudder input lag_s before (default 0.15)
--   and 1;
--   the bank's closed loop (the A/P's roll servo and X-Plane): the roll
--   acceleration on the roll command less the bank, the roll rate and 1.
-- X-Plane's signs: beta = heading - flown path (the nose right of the path
-- plus), P and R right plus, the rudder input right pedal plus. Prints the
-- fits, R2, the mean IAS and the steady sideslip and bank per rudder.
local path, t0, t1 = arg[1], tonumber(arg[2]), tonumber(arg[3])
local LAG = tonumber(arg[4] or "0.15")
local f = assert(io.open(path, "rb"))
local header = f:read("*l")
local h, n = {}, 0
for name in header:gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs({"beta", "p", "r", "roll", "rud_in", "roll_ratio", "roll_cmd", "ias", "sim_t"}) do
    assert(h[k], "no column " .. k .. " (the recorder v6)")
end
local rows = {}
for line in f:lines() do
    local c = {}
    for v in line:gmatch("[^,]+") do c[#c + 1] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= t0 and t <= t1 then
        rows[#rows + 1] = {t = t, b = c[h.beta], p = c[h.p], r = c[h.r], phi = c[h.roll], dr = c[h.rud_in],
            da = c[h.roll_ratio], rc = c[h.roll_cmd], ias = c[h.ias]}
    end
end
f:close()
print(("%d rows %.1f..%.1f s"):format(#rows, rows[1].t, rows[#rows].t))
-- resample to 0.05 s by linear interpolation
local DT = 0.05
local KEYS = {"b", "p", "r", "phi", "dr", "da", "rc", "ias"}
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
local lag = math.floor(LAG / DT + 0.5)
local Xb, Xpr, Xc, yb, yp, yr, yc = {}, {}, {}, {}, {}, {}, {}
local ias = 0
for i = lag + 2, #S - 1 do
    local s, d = S[i], S[i - lag]
    local db = (S[i + 1].b - S[i - 1].b) / (2 * DT)
    local dp = (S[i + 1].p - S[i - 1].p) / (2 * DT)
    local dr = (S[i + 1].r - S[i - 1].r) / (2 * DT)
    Xb[#Xb + 1] = {s.b, s.p, s.r, s.phi, s.dr, 1}; yb[#yb + 1] = db
    Xpr[#Xpr + 1] = {s.b, s.p, s.r, d.da, d.dr, 1}; yp[#yp + 1] = dp; yr[#yr + 1] = dr
    Xc[#Xc + 1] = {s.rc - s.phi, s.p, 1}; yc[#yc + 1] = dp
    ias = ias + s.ias
end
ias = ias / #Xb
print(("mean IAS %.1f kt, lag %.2f s, %d samples"):format(ias, lag * DT, #Xb))
local function show(name, b, r2, names)
    local t = {}
    for i, v in ipairs(b) do t[#t + 1] = ("%s %.4f"):format(names[i], v) end
    print(("%-6s R2 %.3f: %s"):format(name, r2, table.concat(t, ", ")))
end
local bb, rb = lsq(Xb, yb)
show("beta'", bb, rb, {"beta", "p", "r", "phi", "rud", "1"})
local bp, rp = lsq(Xpr, yp)
show("p'", bp, rp, {"beta", "p", "r", "ail", "rud", "1"})
local br, rr = lsq(Xpr, yr)
show("r'", br, rr, {"beta", "p", "r", "ail", "rud", "1"})
local bc, rc = lsq(Xc, yc)
show("phi''", bc, rc, {"cmd-phi", "p", "1"})
if bc[1] < 0 and bc[2] < 0 then
    local w = math.sqrt(-bc[1]); print(("bank loop: %.2f rad/s, damping %.2f"):format(w, -bc[2] / (2 * w)))
end
-- the closed loop's forms for tests/tools/align_sim.lua: the roll
-- acceleration on the roll command less the bank, the roll rate and the
-- sideslip; the yaw acceleration with the roll command less the bank in
-- place of the aileron; printed as tests/tools/lat_model_150kt.lua's table
local Xpc, Xrc = {}, {}
for i = lag + 2, #S - 1 do
    local s = S[i]
    Xpc[#Xpc + 1] = {s.rc - s.phi, s.p, s.b, 1}
    Xrc[#Xrc + 1] = {s.b, s.p, s.r, s.rc - s.phi, S[i - lag].dr, 1}
end
local bpc, rpc = lsq(Xpc, yp)
show("p'cl", bpc, rpc, {"cmd-phi", "p", "beta", "1"})
local brc, rrc = lsq(Xrc, yr)
show("r'cl", brc, rrc, {"beta", "p", "r", "cmd-phi", "rud", "1"})
print(("return {bb = %.4f, bp = %.4f, br = %.4f, bphi = %.4f, bd = %.4f,"):format(bb[1], bb[2], bb[3], bb[4], bb[5]))
print(("    pc = %.4f, pp = %.4f, pb = %.4f,"):format(bpc[1], bpc[2], bpc[3]))
print(("    rb = %.4f, rp = %.4f, rr = %.4f, rc = %.4f, rd = %.4f}"):format(brc[1], brc[2], brc[3], brc[4], brc[5]))
-- the steady straight sideslip per unit rudder input (p = r = 0): p' = 0
-- and r' = 0 give the sideslip and the aileron, beta' = 0 the bank
local det = bp[1] * br[4] - bp[4] * br[1]
if math.abs(det) > 1e-9 and bb[4] ~= 0 then
    local beta = (-bp[5] * br[4] + bp[4] * br[5]) / det
    local ail = (-bp[1] * br[5] + br[1] * bp[5]) / det
    local phi = -(bb[1] * beta + bb[5]) / bb[4]
    print(("steady per unit rudder input: sideslip %.2f deg, aileron %.3f, bank %.2f deg"):format(beta, ail, phi))
end
