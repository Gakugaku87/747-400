-- The PLI's lift curve (B747.60.minspeed_model.lua, PLI_CURVE) from a stall
-- measurement (tests/flight/measure/stall_*.json): the angle of attack
-- against B = n W / (delta M^2) (kg; the lift coefficient's measure in the
-- minimum speed model) as a straight line, alpha = a0 + k B, on the rows up
-- to the stall break (as stall_speed.lua: the first time past 8 deg AOA
-- that n, averaged +-1 s, falls below 0.88), above 1,000 ft RA, after the
-- first 10 s, and at most [alpha max] degrees (the straight part: 10 with
-- the flaps out, 9 flaps up; notes/AERO.md §3.13). n and IAS^2 averaged
-- +-1 s by time.
--   luajit tests/flight/tools/pli_fit.lua <run folder> [alpha max]
local dir, AMAX = arg[1], tonumber(arg[2] or "99")
local f = assert(io.open(dir .. "/session.csv", "rb"))
local col, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; col[name:gsub("\r", "")] = n end
local rows = {}
for line in f:lines() do
    local v = {}
    for x in line:gmatch("[^,]+") do v[#v + 1] = tonumber(x) or 0 end
    if #v >= col.gload then rows[#rows + 1] = v end
end
f:close()
local function delta(h) return (1 - 6.87559e-6 * h) ^ 5.25588 end
local function mach(cas, h)
    local qc = (1 + 0.2 * (cas / 661.4786) ^ 2) ^ 3.5 - 1
    return math.sqrt(5 * ((qc / delta(h) + 1) ^ (2 / 7) - 1))
end
local cut = #rows
for r = 1, #rows do if rows[r][col.ra] and rows[r][col.ra] < 1000 then cut = r - 1; break end end
local HALF = 1.0
local sn_, sv_ = {}, {}
do
    local a, b, sn, sv, cnt = 1, 0, 0, 0, 0
    for r = 1, cut do
        local t = rows[r][col.t]
        while b < cut and rows[b + 1][col.t] <= t + HALF do
            b = b + 1; sn = sn + rows[b][col.gload]; sv = sv + rows[b][col.ias] ^ 2; cnt = cnt + 1
        end
        while rows[a][col.t] < t - HALF do
            sn = sn - rows[a][col.gload]; sv = sv - rows[a][col.ias] ^ 2; cnt = cnt - 1; a = a + 1
        end
        sn_[r], sv_[r] = sn / cnt, sv / cnt
    end
end
local brk
for r = 1, cut do if rows[r][col.alpha] > 8 and sn_[r] < 0.88 then brk = r; break end end
local last = brk or cut
-- the lift limit's region: from where alpha starts rising steadily (the
-- deceleration) to the break; skip the first 10 s (the start's swings)
local sx, sy, sxx, sxy, m = 0, 0, 0, 0, 0
local t0 = rows[1][col.t] + 10
local amin, amax = 99, -99
for r = 1, last do
    local v = rows[r]
    if v[col.t] >= t0 and v[col.alpha] <= AMAX and v[col.ias] > 60 then
        local ias = math.sqrt(sv_[r])
        local M = mach(ias, v[col.alt])
        local B = sn_[r] * v[col.weight] / (delta(v[col.alt]) * M * M)
        sx, sy, sxx, sxy, m = sx + B, sy + v[col.alpha], sxx + B * B, sxy + B * v[col.alpha], m + 1
        amin, amax = math.min(amin, v[col.alpha]), math.max(amax, v[col.alpha])
    end
end
local k = (m * sxy - sx * sy) / (m * sxx - sx * sx)
local a0 = (sy - k * sx) / m
-- residual
local ss = 0
for r = 1, last do
    local v = rows[r]
    if v[col.t] >= t0 and v[col.alpha] <= AMAX and v[col.ias] > 60 then
        local ias = math.sqrt(sv_[r])
        local M = mach(ias, v[col.alt])
        local B = sn_[r] * v[col.weight] / (delta(v[col.alt]) * M * M)
        ss = ss + (v[col.alpha] - a0 - k * B) ^ 2
    end
end
local w = rows[last][col.weight]
print(string.format("%s: %d rows to the %s (alpha %.1f..%.1f), %.0f kg, flap lever %.3f: a0 %.2f deg, k %.3e deg/kg, rms %.2f deg",
    dir:match("[^/]+$"), m, brk and "break" or "end", amin, amax, w, rows[last][col.flap], a0, k, math.sqrt(ss / m)))
