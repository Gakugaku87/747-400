-- Run from the repository root with LuaJIT:
--   luajit tests/tools/dr_damping.lua <session.csv> <t0> <t1>
-- The dutch roll's damping in a flight-test recording (the recorder's
-- session.csv) between sim times t0 and t1, after a rudder doublet: the
-- sideslip's successive extremes (beta smoothed over 0.2 s), each pair of
-- the same sign giving a damping ratio from its decrement, and the period
-- (6-3 step 6b, the yaw dampers: docs/overhaul/notes/ATA-22.md §40).
local path, t0, t1 = arg[1], tonumber(arg[2]), tonumber(arg[3])
assert(path and t0 and t1, "usage: dr_damping.lua <session.csv> <t0> <t1>")
local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
local T, B, RU = {}, {}, {}
for line in f:lines() do
    local c = {}
    for v in line:gmatch("[^,]+") do c[#c + 1] = tonumber(v) end
    local t = c[h.sim_t]
    if t and t >= t0 and t <= t1 then
        T[#T + 1], B[#B + 1] = t, c[h.beta]
        RU[#RU + 1] = h.rud_upr and (c[h.rud_upr] + c[h.rud_lwr]) / 2 or 0
    end
end
f:close()
-- smooth over 0.2 s
local S = {}
for i = 1, #B do
    local sum, k = 0, 0
    for j = i, 1, -1 do
        if T[i] - T[j] > 0.1 then break end
        sum, k = sum + B[j], k + 1
    end
    for j = i + 1, #B do
        if T[j] - T[i] > 0.1 then break end
        sum, k = sum + B[j], k + 1
    end
    S[i] = sum / k
end
local ext = {}
for i = 2, #S - 1 do
    if (S[i] > S[i - 1] and S[i] >= S[i + 1]) or (S[i] < S[i - 1] and S[i] <= S[i + 1]) then
        if math.abs(S[i]) > 0.02 and (#ext == 0 or T[i] - ext[#ext].t > 1.0) then ext[#ext + 1] = {t = T[i], v = S[i]} end
    end
end
local rud = 0
for i = 1, #RU do rud = math.max(rud, math.abs(RU[i])) end
print(("%d samples %.1f..%.1f s, the rudders up to %.2f deg"):format(#T, T[1], T[#T], rud))
for i, e in ipairs(ext) do io.write(("%.1f:%+.3f "):format(e.t, e.v)) end
print()
for i = 1, #ext - 2 do
    local a, c = ext[i], ext[i + 2]
    if a.v * c.v > 0 and math.abs(c.v) < math.abs(a.v) then
        local dl = math.log(math.abs(a.v) / math.abs(c.v))
        print(("extremes %.1f and %.1f s: period %.1f s, damping %.3f"):format(a.t, c.t, c.t - a.t, dl / math.sqrt(4 * math.pi ^ 2 + dl * dl)))
    end
end
