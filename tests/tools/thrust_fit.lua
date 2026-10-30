-- Run from the repository root with LuaJIT:
--   luajit tests/tools/thrust_fit.lua [pw|ge]
-- The thrust setting for level flight (the CRZ page's EPR or N1: 6-1/6-2
-- step 8b, docs/overhaul/notes/ATA-34-61-FMC.md §45): with the cruise
-- model's drag (B747.68.perf_db.lua's POLAR, perf_fit.lua) as an engine's
-- thrust F, fits by least squares
--   setting = C1 + C2 M + C3 M^2 + (C4 + C5 M) x + C6 x^2,  x = F / delta / 100 kN
-- to the EPR (PW) or the N1 over sqrt(theta_t2) (GE) of the FCOM PI tables'
-- cells: the long range cruise (PI.11.2/21.2), holding (PI.11.6/21.6) and
-- .84/290 level flight (PI.10.38/20.33). Prints perf_db's THRUST line and
-- the errors by cell.
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

local which = (arg[1] or "pw"):lower()
local t = P.tables(which == "ge" and 1 or 0)
local n1 = which == "ge"

-- the cells: weight (kg), pressure altitude (ft), Mach, setting
local cells = {}
local function add(kg, ft, mach, set, src)
    cells[#cells + 1] = {kg = kg, ft = ft, mach = mach, set = set, src = src}
end
for _, w in ipairs(t.LRC_W) do
    for _, a in ipairs(t.LRC_ALT) do
        local c = t.LRC[w][a]
        if c then add(w * 1000 * t.wf, a * 1000, c[2], c[1], "lrc") end
    end
    for n, ft in ipairs(t.HOLD_ALT) do
        local c = t.HOLD[w][n]
        if c then add(w * 1000 * t.wf, ft, P.cas_to_mach(c[2], ft), c[1], "hold") end
    end
end
for alt, row in pairs(t.U84_CRZ) do
    for n, c in ipairs(row) do
        add(t.U84_W[n] * 1000 * t.wf, alt, math.min(0.84, P.cas_to_mach(290, alt)), c[1], ".84")
    end
end

-- the regressors and the fitted value
local function terms(c)
    local p, temp = P.atmos(c.ft)
    local x = P.drag(t, c.kg, c.ft, c.mach) / 4 / (p / 101325) / 1e5
    local m = c.mach
    return {1, m, m * m, x, x * m, x * x}
end
local function target(c)
    if not n1 then return c.set end
    local _, temp = P.atmos(c.ft)
    return c.set / math.sqrt(temp / 288.15 * (1 + 0.2 * c.mach * c.mach))
end

-- least squares by the normal equations
local n = 6
local A, b = {}, {}
for i = 1, n do A[i] = {}; b[i] = 0; for j = 1, n do A[i][j] = 0 end end
for _, c in ipairs(cells) do
    local f, y = terms(c), target(c)
    for i = 1, n do
        b[i] = b[i] + f[i] * y
        for j = 1, n do A[i][j] = A[i][j] + f[i] * f[j] end
    end
end
for i = 1, n do
    local piv = i
    for r = i + 1, n do if math.abs(A[r][i]) > math.abs(A[piv][i]) then piv = r end end
    A[i], A[piv] = A[piv], A[i]; b[i], b[piv] = b[piv], b[i]
    for r = i + 1, n do
        local k = A[r][i] / A[i][i]
        for j = i, n do A[r][j] = A[r][j] - k * A[i][j] end
        b[r] = b[r] - k * b[i]
    end
end
local cf = {}
for i = n, 1, -1 do
    local s = b[i]
    for j = i + 1, n do s = s - A[i][j] * cf[j] end
    cf[i] = s / A[i][i]
end

local parts = {}
for i = 1, n do parts[i] = string.format("%.6g", cf[i]) end
print(string.format("%s.THRUST = {%s}  -- %s", which == "ge" and "GE" or "PW", table.concat(parts, ", "),
    n1 and "N1 / sqrt(theta_t2)" or "EPR"))

print("cells: source, weight t, ft, Mach, table, model, error")
local sums = {}
for _, c in ipairs(cells) do
    local f = terms(c)
    local v = 0
    for i = 1, n do v = v + cf[i] * f[i] end
    if n1 then
        local _, temp = P.atmos(c.ft)
        v = v * math.sqrt(temp / 288.15 * (1 + 0.2 * c.mach * c.mach))
    end
    local e = v - c.set
    local s = sums[c.src] or {n = 0, e2 = 0}
    s.n, s.e2 = s.n + 1, s.e2 + e * e
    sums[c.src] = s
    print(string.format("  %-4s %5.0f %5d %.3f  %6.2f %6.2f  %+5.2f", c.src, c.kg / 1000, c.ft, c.mach, c.set, v, e))
end
for src, s in pairs(sums) do print(string.format("  rms %s %.3f (%d cells)", src, math.sqrt(s.e2 / s.n), s.n)) end
