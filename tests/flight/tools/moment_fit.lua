-- Run from the repository root with LuaJIT:
--   luajit tests/flight/tools/moment_fit.lua <session.csv> <t0> <t1>
-- The pitching moments X-Plane's flight model has about the centre of
-- gravity, from a kit recording (the recorder's v14 columns m_aero, m_prop,
-- stab_deg; 2026-11-24, the 2026-11-23 review's FCTL-2:
-- docs/overhaul/notes/AERO.md §3.27). Over X-Plane's time t0..t1, with the
-- A/P off (the pitch measures' stabilizer steps, column steps and doublets:
-- tests/flight/measure/aero_pitch_*):
--  * least squares of the aerodynamic moment as a coefficient on the
--    747-400's 511 m2 and 8.32 m (TCDS A20WE p.14's MAC) and the dynamic
--    pressure of the true airspeed in the standard atmosphere's density at
--    the altimeter's altitude (the measures fly in ISA; the indicated
--    airspeed's would be 14 % too much at FL350 and M.84),
--      Cm = Cm0 + Cm_alpha alpha + Cm_q q + Cm_de de + Cm_ds ds
--    with alpha in degrees, q in degrees a second, de the left inner
--    elevator (degrees, minus is trailing edge up) and ds X-Plane's
--    stabilizer (degrees, leading edge up plus: the trim's angle and the
--    aerodynamic corrections'). Printed per degree, per radian for the
--    three angles, and as the moment a degree at the mean dynamic pressure.
--    No inertia and no differentiating come into it (pitch_fit.lua fits
--    the angular acceleration).
--  * the engines' moment over the four engines' thrust (m_prop / (4 x the
--    recorder's mean thrust)): the mean arm X-Plane gives the engines under
--    the centre of gravity, at the start and the end of the range, and the
--    slope between the moment and the thrust where the thrust changes.
-- The 747-100: Cm_de -1.34 /rad (power approach) to -1.40 (landing), the
-- stabilizer -0.054 a degree (-3.1 /rad) (NASA_HQ p.222-223 tables IX-1 and
-- IX-2; NASA_SIM p.127-129; -100 values); the engines' effective arms 8.3
-- ft inboard and 3.1 ft outboard in the air, 5.7 ft = 1.74 m on the mean
-- (NASA_SIM p.613 (19.0-2)).
local path, t0, t1 = arg[1], tonumber(arg[2]), tonumber(arg[3])
assert(path and t0 and t1, "usage: moment_fit.lua <session.csv> <t0> <t1>")
local S, C = 511, 8.32
local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs{"sim_t", "q", "alpha", "elev_deg", "alt", "tas", "thrust", "m_aero", "m_prop", "stab_deg"} do
    assert(h[k], "no column " .. k .. " (the recorder's v14)")
end
local rows = {}
for line in f:lines() do
    local c, k = {}, 0
    for v in (line .. ","):gmatch("([^,]*),") do k = k + 1; c[k] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= t0 and t <= t1 and c[h.m_aero] and c[h.stab_deg] then rows[#rows + 1] = c end
end
f:close()
assert(#rows > 20, "too few rows in the range")
-- the standard atmosphere's density (kg/m3) at a pressure altitude (ft)
local function isa_rho(ft)
    local h = ft * 0.3048
    if h <= 11000 then
        local t = 288.15 - 0.0065 * h
        return 1.225 * (t / 288.15) ^ 4.2559
    end
    return 0.36392 * math.exp(-(h - 11000) / 6341.6)
end
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
local k = 5
local M, b = {}, {}
for i = 1, k do M[i] = {}; b[i] = 0; for j = 1, k do M[i][j] = 0 end end
local ys, yy, qsum = 0, 0, 0
local lo, hi = {}, {}
local data = {}
for _, c in ipairs(rows) do
    local v = c[h.tas]
    local qbar = 0.5 * isa_rho(c[h.alt]) * v * v
    local y = c[h.m_aero] / (qbar * S * C)
    local x = {1, c[h.alpha], c[h.q], c[h.elev_deg], c[h.stab_deg]}
    data[#data + 1] = {y = y, x = x}
    for i = 1, k do
        b[i] = b[i] + x[i] * y
        for j = 1, k do M[i][j] = M[i][j] + x[i] * x[j] end
        lo[i], hi[i] = math.min(lo[i] or x[i], x[i]), math.max(hi[i] or x[i], x[i])
    end
    ys, yy, qsum = ys + y, yy + y * y, qsum + qbar
end
local x = solve(M, b, k)
local ss, mean = 0, ys / #data
for _, d in ipairs(data) do
    local p = 0
    for i = 1, k do p = p + x[i] * d.x[i] end
    ss = ss + (d.y - p) ^ 2
end
local r2 = 1 - ss / (yy - #data * mean * mean)
local qbar = qsum / #data
local R = 57.2958
print(string.format("%d rows %.1f..%.1f s, mean dynamic pressure %.0f Pa (q S c %.2fe6 N m); ranges: alpha %.2f..%.2f, q %.2f..%.2f, elevator %.2f..%.2f, stabilizer %.2f..%.2f",
    #data, t0, t1, qbar, qbar * S * C / 1e6, lo[2], hi[2], lo[3], hi[3], lo[4], hi[4], lo[5], hi[5]))
print(string.format("Cm = %.4f %+.5f alpha %+.5f q %+.5f de %+.5f ds   (per degree, degree a second; R2 %.3f)", x[1], x[2], x[3], x[4], x[5], r2))
print(string.format("per radian: Cm_alpha %.2f, Cm_de %.2f, Cm_ds %.2f; the stabilizer %.2f times the elevator; Cm_alpha / Cm_de %.2f",
    x[2] * R, x[4] * R, x[5] * R, x[5] / x[4], x[2] / x[4]))
print(string.format("moment a degree at this dynamic pressure: alpha %.0f, elevator %.0f, stabilizer %.0f kN m",
    x[2] * qbar * S * C / 1000, x[4] * qbar * S * C / 1000, x[5] * qbar * S * C / 1000))
-- the engines' moment over the thrust
local function arm(c) local t = 4 * c[h.thrust]; return t > 1000 and c[h.m_prop] / t or nil end
local a0, a1 = arm(rows[1]), arm(rows[#rows])
local st, sm, stt, stm = 0, 0, 0, 0
for _, c in ipairs(rows) do
    local t, m = 4 * c[h.thrust], c[h.m_prop]
    st, sm, stt, stm = st + t, sm + m, stt + t * t, stm + t * m
end
local nrow = #rows
local den = stt - st * st / nrow
print(string.format("engines: thrust %.0f -> %.0f kN in all, moment %.0f -> %.0f kN m; the mean arm %s -> %s m%s",
    4 * rows[1][h.thrust] / 1000, 4 * rows[#rows][h.thrust] / 1000, rows[1][h.m_prop] / 1000, rows[#rows][h.m_prop] / 1000,
    a0 and string.format("%.3f", a0) or "-", a1 and string.format("%.3f", a1) or "-",
    den > 1e6 * nrow and string.format("; slope %.3f m (%.2f ft)", (stm - st * sm / nrow) / den, (stm - st * sm / nrow) / den / 0.3048) or ""))
