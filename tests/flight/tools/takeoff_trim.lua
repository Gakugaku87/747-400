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
    end
end
