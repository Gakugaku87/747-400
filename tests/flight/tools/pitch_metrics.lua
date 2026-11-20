-- Run from the repository root with LuaJIT:
--   luajit tests/flight/tools/pitch_metrics.lua <session.csv> <pull_t0> <push_t0> <doublet_end>
-- (2026-11-20, GAP N19-AERO-02, docs/overhaul/notes/AERO.md §3.24; the measure
-- tests/flight/measure/aero_pitch_fl350.json).
-- AERO-02's pitch measure: the elevator per g from a steady pull or push
-- and the short period after a doublet, from a kit recording (session.csv,
-- sim_t). usage:
--   luajit pitch_metrics.lua session.csv <pull_t0> <push_t0> <doublet_end>
-- pull_t0 / push_t0: the column's step (sim time); the steady part is from
-- 4 to 8 s (push 3 to 6 s) after it, the base the 4 s before it.
local path, t_pull, t_push, t_dbl = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4])
local f = assert(io.open(path, "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs{"sim_t", "gload", "elev_deg", "q", "alpha", "tas", "trim", "pitch"} do assert(h[k], "no column " .. k) end
local R = {}
for line in f:lines() do
    local c, k = {}, 0
    for v in (line .. ","):gmatch("([^,]*),") do k = k + 1; c[k] = tonumber(v) end
    if c[h.sim_t] then R[#R + 1] = {t = c[h.sim_t], g = c[h.gload], e = c[h.elev_deg], q = c[h.q], a = c[h.alpha], v = c[h.tas], tr = c[h.trim], th = c[h.pitch]} end
end
f:close()
local function mean(t0, t1, key)
    local s, m = 0, 0
    for _, r in ipairs(R) do if r.t >= t0 and r.t <= t1 and r[key] then s, m = s + r[key], m + 1 end end
    return m > 0 and s / m or 0/0, m
end
local function step(name, t0, a, b)
    local g0, e0, q0, al0 = mean(t0 - 4, t0 - 0.1, "g"), mean(t0 - 4, t0 - 0.1, "e"), mean(t0 - 4, t0 - 0.1, "q"), mean(t0 - 4, t0 - 0.1, "a")
    local g1, e1, q1, al1 = mean(t0 + a, t0 + b, "g"), mean(t0 + a, t0 + b, "e"), mean(t0 + a, t0 + b, "q"), mean(t0 + a, t0 + b, "a")
    local v = mean(t0 - 4, t0, "v")
    print(string.format("%s at %.1f: base n %.3f elev %.2f q %.2f alpha %.2f; %g-%g s: n %.3f elev %.2f q %.2f alpha %.2f; dn %.3f delev %.2f deg -> %.2f deg/g (dq/dn %.2f deg/s per g; TAS %.0f m/s: g/V %.2f)",
        name, t0, g0, e0, q0, al0, a, b, g1, e1, q1, al1, g1 - g0, e1 - e0, (e1 - e0) / (g1 - g0), (q1 - q0) / (g1 - g0), v, 9.80665 / v * 57.2958))
end
if t_pull then step("pull", t_pull, 4, 8) end
if t_push then step("push", t_push, 3, 6) end
if t_dbl then
    -- q's extremes after the doublet, the damping from successive opposite
    -- peaks (a heavily damped short period: one or two overshoots)
    local ext, prev, pprev = {}, nil, nil
    local S = {}
    for _, r in ipairs(R) do if r.t >= t_dbl and r.t <= t_dbl + 15 then S[#S + 1] = r end end
    for i = 3, #S - 2 do
        local y = (S[i - 2].q + S[i - 1].q + S[i].q + S[i + 1].q + S[i + 2].q) / 5
        S[i].qs = y
    end
    for i = 4, #S - 3 do
        local a, b, c = S[i - 1].qs, S[i].qs, S[i + 1].qs
        if a and b and c and ((b > a and b >= c) or (b < a and b <= c)) then
            if #ext == 0 or S[i].t - ext[#ext].t > 0.8 then ext[#ext + 1] = {t = S[i].t, q = b} end
        end
    end
    io.write("doublet end " .. t_dbl .. ": q extremes ")
    for _, e in ipairs(ext) do io.write(string.format("%.1f:%+.3f ", e.t - t_dbl, e.q)) end
    print()
    for i = 1, #ext - 1 do
        local r = math.abs(ext[i + 1].q / ext[i].q)
        if ext[i].q * ext[i + 1].q < 0 and r < 1 and r > 0 then
            local dl = -math.log(r)   -- half-cycle decrement
            local z = dl / math.sqrt(math.pi ^ 2 + dl * dl)
            print(string.format("  half cycle %.1f -> %.1f s: ratio %.3f, damping %.3f, period %.1f s", ext[i].t - t_dbl, ext[i + 1].t - t_dbl, r, z, 2 * (ext[i + 1].t - ext[i].t)))
        end
    end
end
