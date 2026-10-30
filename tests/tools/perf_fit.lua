-- Run from the repository root with LuaJIT:
--   luajit tests/tools/perf_fit.lua [pw|ge]
-- The FMC's cruise model (6-1/6-2 step 8b, docs/overhaul/notes/
-- ATA-34-61-FMC.md §45): fits the drag polar and the fuel consumption of
-- B747.68.perf_db.lua's cruise model (POLAR: CD0, K, KW, MC0, MCL, T0, T1)
-- to the engine's FCOM PI tables, by Nelder-Mead:
--   - the long range cruise's fuel flow at the table's Mach (PI.11.2/21.2),
--   - the holding fuel flow at the table's KIAS less the racetrack's 5 %
--     (PI.11.6/21.6; cells near the thrust limit left out),
--   - the long range cruise's Mach: the model's (1 % less NM per kg than
--     the maximum range, FCTM p.4.7) against the table's,
--   - the drag: the idle descent's V/S at .84/290 (PI.10.39/20.33) with
--     the speed's change along it, the idle thrust taken as none (the fuel
--     flows alone leave the drag's scale free),
--   - the drag divergence (KD, MD): the tables' long range cruise stops at
--     about .861 whatever the weight, and the economy speed reaches the
--     speed limit at about cost index 5000 (FCTM p.4.7: thrust or speed
--     limits from 5000 or more).
-- Prints the fitted POLAR line for perf_db and the errors by cell, and the
-- model's optimum altitude and minimum drag speed against the tables'.
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

local which = (arg[1] or "pw"):lower()
local t = P.tables(which == "ge" and 1 or 0)
local NAMES = {"cd0", "k", "kw", "mc0", "mcl", "t0", "t1", "t2", "kd", "md"}

-- the cells
local lrc, hold = {}, {}
for _, w in ipairs(t.LRC_W) do
    for _, a in ipairs(t.LRC_ALT) do
        local c = t.LRC[w][a]
        if c then
            lrc[#lrc + 1] = {kg = w * 1000 * t.wf, ft = a * 1000, mach = c[2], ff = c[4] * t.wf, set = c[1]}
        end
    end
    for n, ft in ipairs(t.HOLD_ALT) do
        local c = t.HOLD[w][n]
        -- near the thrust limit (EPR 1.30 or 95 % N1 and up) left out
        if c and c[1] < (which == "ge" and 95 or 1.30) then
            hold[#hold + 1] = {kg = w * 1000 * t.wf, ft = ft, mach = P.cas_to_mach(c[2], ft), ff = c[3] * t.wf / 1.05, set = c[1]}
        end
    end
end
-- the .84/290 schedule's Mach at a pressure altitude (ft)
local function mach84(ft) return math.min(0.84, P.cas_to_mach(290, ft)) end
local function v_ms(ft) return P.tas(mach84(ft), ft) * 0.514444 end
local des = {}
for alt, row in pairs(t.U84_DES) do
    for n, vs in ipairs(row) do
        local v = v_ms(alt)
        local dvdh = (v_ms(alt + 500) - v_ms(alt - 500)) / (1000 * 0.3048)
        local dw = -(vs * 0.3048 / 60) / v * (1 + v / 9.80665 * dvdh)
        des[#des + 1] = {kg = t.U84_W[n] * 1000 * t.wf, ft = alt, mach = mach84(alt), dw = dw}
    end
end
print(string.format("%s: %d long range cruise cells, %d holding cells, %d descent cells", which, #lrc, #hold, #des))

local CI5000 = {{240000, 39000}, {300000, 35000}, {340000, 33000}, {380000, 31000}}
if which == "ge" then CI5000 = {{560 * 1000 * t.wf, 39000}, {680 * 1000 * t.wf, 35000}, {760 * 1000 * t.wf, 33000}, {840 * 1000 * t.wf, 31000}} end

local function set(x)
    local pol = {}
    for i, n in ipairs(NAMES) do pol[n] = x[i] end
    t.POLAR = pol
end

local function errors(x)
    set(x)
    local e = 0
    for _, c in ipairs(lrc) do
        local r = P.cruise_ff(t, c.kg, c.ft, c.mach) / c.ff - 1
        local dm = P.lrc_model(t, c.kg, c.ft) - c.mach
        e = e + (r / 0.01) ^ 2 + (dm / 0.003) ^ 2
    end
    for _, c in ipairs(hold) do
        local r = P.cruise_ff(t, c.kg, c.ft, c.mach) / c.ff - 1
        e = e + (r / 0.02) ^ 2
    end
    for _, c in ipairs(des) do
        local r = P.drag(t, c.kg, c.ft, c.mach) / (c.kg * 9.80665) / c.dw - 1
        e = e + (r / 0.03) ^ 2
    end
    -- the economy speed at cost index 5000 at the limit
    for _, c in ipairs(CI5000) do
        local _, m = P.econ_cruise(t, c[1], c[2], 5000, 0)
        e = e + ((m - P.econ_limit(c[2])) / 0.002) ^ 2
    end
    for i = 1, #x do if x[i] <= 0 then e = e + 1e9 end end
    return e
end

-- Nelder-Mead
local function nelder_mead(f, x0, step, iters)
    local n = #x0
    local s = {}
    for i = 1, n + 1 do
        local x = {}
        for j = 1, n do x[j] = x0[j] end
        if i > 1 then x[i - 1] = x[i - 1] + step[i - 1] end
        s[i] = {x = x, f = f(x)}
    end
    local function comb(a, xa, b, xb)
        local x = {}
        for j = 1, n do x[j] = a * xa[j] + b * xb[j] end
        return x
    end
    for _ = 1, iters do
        table.sort(s, function(p, q) return p.f < q.f end)
        local c = {}
        for j = 1, n do
            local sum = 0
            for i = 1, n do sum = sum + s[i].x[j] end
            c[j] = sum / n
        end
        local worst = s[n + 1]
        local xr = comb(2, c, -1, worst.x)
        local fr = f(xr)
        if fr < s[1].f then
            local xe = comb(3, c, -2, worst.x)
            local fe = f(xe)
            if fe < fr then s[n + 1] = {x = xe, f = fe} else s[n + 1] = {x = xr, f = fr} end
        elseif fr < s[n].f then
            s[n + 1] = {x = xr, f = fr}
        else
            local xc = comb(0.5, c, 0.5, worst.x)
            local fc = f(xc)
            if fc < worst.f then
                s[n + 1] = {x = xc, f = fc}
            else
                for i = 2, n + 1 do
                    local x = comb(0.5, s[1].x, 0.5, s[i].x)
                    s[i] = {x = x, f = f(x)}
                end
            end
        end
    end
    table.sort(s, function(p, q) return p.f < q.f end)
    return s[1].x, s[1].f
end

-- from several starts for the drag rise (mc0, mcl, kw)
local STARTS = {{0.80, 0.61, 0.28, 2000, 0.84}, {0.80, 0.61, 0.28, 500, 0.85}, {0.80, 0.61, 0.28, 8000, 0.83}, {0.84, 0.55, 0.6, 2000, 0.845}}
local best, fb
for _, st in ipairs(STARTS) do
    local x = {}
    for i, n in ipairs(NAMES) do x[i] = t.POLAR[n] end
    x[3], x[4], x[5] = st[3], st[1], st[2]
    x[9], x[10] = st[4], st[5]
    local fx
    for round = 1, 4 do
        local step = {}
        for i = 1, #x do step[i] = x[i] * 0.1 end
        x, fx = nelder_mead(errors, x, step, 1500)
    end
    print(string.format("start kd %.0f md %.3f: error %.1f (mc0 %.3f mcl %.3f kw %.3g kd %.4g md %.4f)", st[4], st[5], fx, x[4], x[5], x[3], x[9], x[10]))
    if not fb or fx < fb then best, fb = x, fx end
end
set(best)

local parts = {}
for i, n in ipairs(NAMES) do parts[#parts + 1] = string.format("%s = %.5g", n, best[i]) end
print(string.format("%s.POLAR = {%s}", which == "ge" and "GE" or "PW", table.concat(parts, ", ")))

print("long range cruise: weight t, FL, Mach table/model, fuel flow error %, L/D, CL")
local sum2, sumd = 0, 0
for _, c in ipairs(lrc) do
    local ff = P.cruise_ff(t, c.kg, c.ft, c.mach)
    local m = P.lrc_model(t, c.kg, c.ft)
    local d, cl = P.drag(t, c.kg, c.ft, c.mach)
    sum2 = sum2 + (ff / c.ff - 1) ^ 2
    sumd = sumd + (m - c.mach) ^ 2
    print(string.format("  %5.0f %3d  %.3f %.3f  %+5.1f  %5.2f %.3f", c.kg / 1000, c.ft / 100, c.mach, m,
        100 * (ff / c.ff - 1), c.kg * 9.80665 / d, cl))
end
print(string.format("  rms fuel flow %.2f %%, rms Mach %.4f", 100 * math.sqrt(sum2 / #lrc), math.sqrt(sumd / #lrc)))
print("holding: weight t, ft, Mach, fuel flow error %")
sum2 = 0
for _, c in ipairs(hold) do
    local ff = P.cruise_ff(t, c.kg, c.ft, c.mach)
    sum2 = sum2 + (ff / c.ff - 1) ^ 2
    print(string.format("  %5.0f %5d  %.3f  %+5.1f", c.kg / 1000, c.ft, c.mach, 100 * (ff / c.ff - 1)))
end
print(string.format("  rms fuel flow %.2f %%", 100 * math.sqrt(sum2 / #hold)))

print("idle descent at .84/290: weight t, ft, Mach, D/W table/model, error %")
sum2 = 0
for _, c in ipairs(des) do
    local dw = P.drag(t, c.kg, c.ft, c.mach) / (c.kg * 9.80665)
    sum2 = sum2 + (dw / c.dw - 1) ^ 2
    print(string.format("  %5.0f %5d  %.3f  %.4f %.4f  %+5.1f", c.kg / 1000, c.ft, c.mach, c.dw, dw, 100 * (dw / c.dw - 1)))
end
print(string.format("  rms D/W %.2f %%", 100 * math.sqrt(sum2 / #des)))

-- the optimum altitude: the least fuel per NM at the long range cruise
print("optimum altitude (LRC fuel per NM) table/model, minimum drag CAS at 10000 ft, MRC/LRC at FL350")
for _, w in ipairs(t.MAX_ALT_W) do
    local kg = w * 1000 * t.wf
    local function fpn(ft)
        local m = P.lrc_model(t, kg, ft)
        return P.cruise_ff(t, kg, ft, m) / P.tas(m, ft)
    end
    local opt = P.least(fpn, 20000, 47000, 10)
    local _, vmd = P.min_drag(t, kg, 10000)
    print(string.format("  %5.0f t  %5.0f %5.0f  %3.0f kt  %.3f %.3f", kg / 1000, P.opt_alt(t, kg), opt, vmd,
        P.mrc(t, kg, 35000), P.lrc_model(t, kg, 35000)))
end
