-- Run from the repository root with LuaJIT:
--   luajit tests/flight/tools/takeoff_trim.lua <run dir> [<run dir> ...]
-- The takeoff trim measures (tests/flight/measure/aero_takeoff_trim_*, 2026-11-20,
-- docs/overhaul/notes/AERO.md §3.23): from each run's result.md, the weight
-- and the real % MAC before the takeoff (TCDS A20WE p.14: (1243.31 +
-- cg_offset_z x 39.37 - 1168) / 3.278), and at 1,000 and 1,400 ft the
-- units the A/P's autotrim set, the elevator left (X-Plane's
-- elevator1_deg[8], minus is trailing edge up) and the balance, units less
-- the elevator over 2.5 degrees a unit (§3.23); against FPPM p.44's stab
-- trim setting (747-400F PW4056, max takeoff thrust; by the weight and the
-- centre of gravity, every flap), interpolated in both.
-- (2026-11-24) A second line from the recording (session.csv): the same
-- balance (the units less the left inner elevator over 2.5 degrees) as the
-- mean over the climb with the A/P on from 600 to 1,400 ft of radio
-- altitude at the takeoff's thrust, with its range there, the alpha, the
-- pitch, the IAS and the thrust an engine. The two snapshots alone moved
-- with the elevator (2026-11-20: up to 1.8 units between 1,000 and 1,400
-- ft in one run); the mean is the figure to fit by.
local RA_LO, RA_HI = 600, 1400
local function climb_mean(dir)
    local f = io.open(dir .. "/session.csv", "rb")
    if not f then return nil end
    local h, n = {}, 0
    for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; h[name:gsub("\r", "")] = n end
    for _, k in ipairs{"ra", "servos_on", "trim", "elev_deg", "alpha", "pitch", "ias", "thrust", "thro_1"} do
        if not h[k] then f:close() return nil end
    end
    local s = {u = 0, e = 0, a = 0, p = 0, v = 0, th = 0, n = 0, lo = math.huge, hi = -math.huge}
    for line in f:lines() do
        local c, k = {}, 0
        for v in (line .. ","):gmatch("([^,]*),") do k = k + 1; c[k] = tonumber(v) end
        local ra = c[h.ra]
        if ra and c[h.servos_on] == 1 and ra >= RA_LO and ra <= RA_HI and (c[h.thro_1] or 0) > 0.9 then
            local u = (c[h.trim] + 1) * 7.5
            local b = u - c[h.elev_deg] / 2.5
            s.u, s.e, s.a, s.p, s.v, s.th, s.n = s.u + u, s.e + c[h.elev_deg], s.a + c[h.alpha], s.p + c[h.pitch],
                s.v + c[h.ias], s.th + c[h.thrust], s.n + 1
            s.lo, s.hi = math.min(s.lo, b), math.max(s.hi, b)
        end
    end
    f:close()
    if s.n == 0 then return nil end
    return s
end
local CG = {9, 13, 17, 21, 25, 29, 33}
local FPPM = {   -- weight (1000 kg) -> units at CG
    {400, {9.5, 9, 8, 7, 6, 5, 4}},
    {380, {9.5, 8, 8, 7, 5.5, 5, 3.5}},
    {360, {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5}},
    {340, {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5}},
    {320, {9.5, 8.5, 7.5, 6.5, 5.5, 4, 3}},
    {300, {9, 8, 7, 6, 5, 4, 3}},
    {280, {8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5}},
    {260, {8, 7, 6, 5, 4, 3, 2}},
    {240, {nil, 6, 5, 4.5, 3.5, 2.5, 2}},
    {220, {nil, 5, 4, 3.5, 3, 2, 2}},
    {200, {nil, 4, 3.5, 3, 2.5, 2, 2}},
}
local function row_at(row, cg)
    cg = math.max(CG[1], math.min(CG[#CG], cg))
    for i = 1, #CG - 1 do
        if cg <= CG[i + 1] then
            local a, b = row[i], row[i + 1]
            if not a then return b end
            return a + (b - a) * (cg - CG[i]) / (CG[i + 1] - CG[i])
        end
    end
    return row[#CG]
end
local function fppm(t, cg)
    t = math.max(200, math.min(400, t))
    for i = 1, #FPPM - 1 do
        local hi, lo = FPPM[i], FPPM[i + 1]
        if t >= lo[1] then
            local a, b = row_at(lo[2], cg), row_at(hi[2], cg)
            return a + (b - a) * (t - lo[1]) / (hi[1] - lo[1])
        end
    end
    return row_at(FPPM[#FPPM][2], cg)
end
local function num(line, key)
    local v = line:match(key:gsub("([%[%]%.%-/])", "%%%1") .. "=([%-%d%.Ee]+)")
    return v and tonumber(v)
end
for _, dir in ipairs(arg) do
    local f = io.open(dir .. "/result.md", "rb")
    if f then
        local md = f:read("*a"); f:close()
        local name = md:match("# ([%w_]+)")
        local before = md:match("[^\n]*離陸の前の重さと重心[^\n]*")
        local t, cgz = before and num(before, "sim/flightmodel/weight/m_total"), before and num(before, "sim/flightmodel2/misc/cg_offset_z")
        local cg = cgz and (1243.31 + cgz * 39.37 - 1168) / 3.278
        local want = t and cg and fppm(t / 1000, cg)
        io.write(string.format("%-34s %5.1f t %5.1f %%  FPPM %4.1f", name or dir, (t or 0) / 1000, cg or 0, want or 0))
        for _, h in ipairs({"1,000 ft", "1,400 ft"}) do
            local line = md:match("[^\n]*| " .. h .. "[^\n]*") or md:match("[^\n]*" .. h .. "：[^\n]*")
            local u = line and num(line, "laminar/B747/flt_ctrls/stab_trim/units")
            local e = line and num(line, "sim/flightmodel2/wing/elevator1_deg[8]")
            if u then
                local bal = u - (e or 0) / 2.5
                io.write(string.format(" | %s: %.2f units, elev %+.2f, balance %.2f (%+.2f)", h, u, e or 0, bal, want and bal - want or 0))
            end
        end
        io.write("\n")
        local s = climb_mean(dir)
        if s then
            local bal = (s.u - s.e / 2.5) / s.n
            io.write(string.format("%-34s   RA %d-%d ft mean: %.2f units, elev %+.2f, balance %.2f (%+.2f) [%.2f..%.2f] | alpha %.1f, pitch %.1f, IAS %.0f, %.0f kN an engine\n",
                "", RA_LO, RA_HI, s.u / s.n, s.e / s.n, bal, want and bal - want or 0, s.lo, s.hi, s.a / s.n, s.p / s.n, s.v / s.n, s.th / s.n / 1000))
        end
    end
end
