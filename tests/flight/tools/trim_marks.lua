-- Run from the repository root with LuaJIT:
--   luajit tests/flight/tools/trim_marks.lua <run dir> [seconds]
-- The balance at each mark of a kit recording (2026-11-24, the 2026-11-23
-- review's FCTL-3; tests/flight/measure/aero_trim_flaps,
-- docs/overhaul/notes/AERO.md §3.29): the mean over the seconds (20) before
-- the mark of the stabilizer's units (the recorder's trim ratio: units =
-- (trim + 1) x 7.5), the left inner elevator (degrees, minus is trailing
-- edge up) and the balance, units less the elevator over 2.5 degrees a unit
-- (§3.23), with the units' and the elevator's range there, the alpha, the
-- pitch, the IAS, the thrust an engine, the flight model's vertical speed
-- and the weight.
local dir, win = arg[1], tonumber(arg[2] or "20")
assert(dir, "usage: trim_marks.lua <run dir> [seconds]")
local marks = {}
for line in io.lines(dir .. "/events.csv") do
    local st, state = line:match("^([%d%.]+),[%d%.]+,(%w+)")
    if state == "mark" then marks[#marks + 1] = tonumber(st) end
end
local f = assert(io.open(dir .. "/session.csv", "rb"))
local h, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
for _, k in ipairs{"sim_t", "trim", "elev_deg", "alpha", "pitch", "ias", "thrust", "vs_i", "weight"} do assert(h[k], "no column " .. k) end
local rows = {}
for line in f:lines() do
    local c, k = {}, 0
    for v in (line .. ","):gmatch("([^,]*),") do k = k + 1; c[k] = tonumber(v) end
    if c[h.sim_t] then rows[#rows + 1] = c end
end
f:close()
for i, tm in ipairs(marks) do
    local s = {u = 0, e = 0, a = 0, p = 0, v = 0, th = 0, vs = 0, n = 0}
    local emin, emax, umin, umax = 1e9, -1e9, 1e9, -1e9
    local w
    for _, c in ipairs(rows) do
        local t = c[h.sim_t]
        if t >= tm - win and t <= tm then
            local u = (c[h.trim] + 1) * 7.5
            s.u, s.e, s.a, s.p, s.v, s.th, s.vs, s.n = s.u + u, s.e + c[h.elev_deg], s.a + c[h.alpha], s.p + c[h.pitch],
                s.v + c[h.ias], s.th + c[h.thrust], s.vs + c[h.vs_i], s.n + 1
            emin, emax, umin, umax = math.min(emin, c[h.elev_deg]), math.max(emax, c[h.elev_deg]), math.min(umin, u), math.max(umax, u)
            w = c[h.weight]
        end
    end
    if s.n > 0 then
        print(string.format("mark %d (t %.0f): units %.2f [%.2f..%.2f] elevator %+.2f [%+.2f..%+.2f] balance %.2f | alpha %.2f pitch %.2f IAS %.1f thrust %.1f kN V/S %+.0f fpm, %.1f t",
            i, tm, s.u / s.n, umin, umax, s.e / s.n, emin, emax, s.u / s.n - s.e / s.n / 2.5, s.a / s.n, s.p / s.n, s.v / s.n,
            s.th / s.n / 1000, s.vs / s.n, w / 1000))
    end
end
