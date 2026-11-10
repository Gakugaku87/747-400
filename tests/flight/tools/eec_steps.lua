-- luajit tests/flight/tools/eec_steps.lua <run folder> [<run folder> ...]
-- X-Plane's engine without the EEC's loop (2026-11-10; PROGRESS.md "next"
-- 20, the EEC's throttle swinging at high altitude): from a run of
-- tests/flight/measure/eec_steps_*.json, each throttle step of the EEC's
-- open-loop test (laminar/B747/engines/eec/test_open, test_step_pm). The
-- scenario's marks: the open loop held, then +0.04, 0, -0.04, 0, +0.08, 0,
-- -0.08, 0 (20 s each), then the closed loop again. For each step, engine
-- 1's throttle to X-Plane (thro_1) and the answers of the shown EPR
-- (depr_1), X-Plane's N1 (n1_1), the shown N1 (dn1_1: the GE's controlled
-- value) and the mean thrust (thrust, kN): the best
-- first-order fit with a dead time, y = y0 + K du (1 - exp(-(t - t0 - d) /
-- tau)) + a drift, and the best two lags in series (tau1, tau2), with R².
-- K is per unit of throttle.
local function split(line)
    local t = {}
    for x in (line .. ","):gmatch("([^,]*),") do t[#t + 1] = x end
    return t
end

local DT = 0.05             -- s, the resampling
local SPAN = 19             -- s of each step fitted
local STEPS = {"+0.04", "0", "-0.04", "0", "+0.08", "0", "-0.08", "0"}

local function median(v)
    local c = {}
    for i = 1, #v do c[i] = v[i] end
    table.sort(c)
    return c[math.floor((#c + 1) / 2)]
end

-- least squares of y on two columns (a, b): returns the coefficients and
-- the residual sum of squares
local function fit2(y, a, b)
    local saa, sab, sbb, say, sby = 0, 0, 0, 0, 0
    for i = 1, #y do
        saa, sab, sbb = saa + a[i] * a[i], sab + a[i] * b[i], sbb + b[i] * b[i]
        say, sby = say + a[i] * y[i], sby + b[i] * y[i]
    end
    local det = saa * sbb - sab * sab
    if math.abs(det) < 1e-12 then return 0, 0, math.huge end
    local ca = (say * sbb - sby * sab) / det
    local cb = (saa * sby - sab * say) / det
    local sse = 0
    for i = 1, #y do local r = y[i] - ca * a[i] - cb * b[i]; sse = sse + r * r end
    return ca, cb, sse
end

local TAUS = {}
for i = 0, 39 do TAUS[#TAUS + 1] = 0.2 * (40 / 0.2) ^ (i / 39) end   -- 0.2 to 40 s

local function fit_step(t, y, t0, du)
    local ys, ts = {}, {}
    local y0, n0 = 0, 0
    for i = 1, #t do
        if t[i] >= t0 - 2 and t[i] < t0 then y0, n0 = y0 + y[i], n0 + 1 end
    end
    y0 = y0 / math.max(1, n0)
    for i = 1, #t do
        if t[i] >= t0 and t[i] <= t0 + SPAN then ys[#ys + 1], ts[#ts + 1] = y[i] - y0, t[i] - t0 end
    end
    local sst, mean = 0, 0
    for i = 1, #ys do mean = mean + ys[i] end
    mean = mean / #ys
    for i = 1, #ys do sst = sst + (ys[i] - mean) ^ 2 end
    local drift = {}
    for i = 1, #ts do drift[i] = ts[i] end
    local best1, best2
    local x = {}
    for d = 0, 3, 0.05 do
        for _, tau in ipairs(TAUS) do
            for i = 1, #ts do
                local s = ts[i] - d
                x[i] = s > 0 and (1 - math.exp(-s / tau)) or 0
            end
            local a, b, sse = fit2(ys, x, drift)
            if not best1 or sse < best1.sse then best1 = {d = d, tau = tau, K = a / du, drift = b, sse = sse} end
        end
    end
    for d = 0, 2, 0.1 do
        for i1, t1 in ipairs(TAUS) do
            for i2 = 1, i1 - 1 do
                local t2 = TAUS[i2]
                for i = 1, #ts do
                    local s = ts[i] - d
                    x[i] = s > 0 and (1 - (t1 * math.exp(-s / t1) - t2 * math.exp(-s / t2)) / (t1 - t2)) or 0
                end
                local a, b, sse = fit2(ys, x, drift)
                if not best2 or sse < best2.sse then best2 = {d = d, tau1 = t1, tau2 = t2, K = a / du, sse = sse} end
            end
        end
    end
    best1.r2 = 1 - best1.sse / sst
    best2.r2 = 1 - best2.sse / sst
    return best1, best2
end

local function report(dir)
    local marks = {}
    for line in io.lines(dir .. "/events.csv") do
        local f = split(line)
        if f[3] == "mark" then marks[#marks + 1] = tonumber(f[2]) end
    end
    local ix, raw = nil, {}
    for line in io.lines(dir .. "/session.csv") do
        local f = split(line)
        if not ix then
            ix = {}
            for k, name in ipairs(f) do ix[name] = k end
        else
            local t = tonumber(f[ix.t])
            if t then
                raw[#raw + 1] = {t = t, u = tonumber(f[ix.thro_1]), epr = tonumber(f[ix.depr_1]),
                    n1 = tonumber(f[ix.n1_1]), dn1 = tonumber(f[ix.dn1_1]), thrust = tonumber(f[ix.thrust]) / 1000,
                    alt = tonumber(f[ix.alt]), mach = tonumber(f[ix.tas]) or 0}
            end
        end
    end
    -- resample at DT
    local T, U, Y = {}, {}, {epr = {}, n1 = {}, dn1 = {}, thrust = {}}
    local j = 1
    for t = raw[1].t, raw[#raw].t, DT do
        while j < #raw and raw[j + 1].t <= t do j = j + 1 end
        T[#T + 1], U[#U + 1] = t, raw[j].u
        Y.epr[#T], Y.n1[#T], Y.dn1[#T], Y.thrust[#T] = raw[j].epr, raw[j].n1, raw[j].dn1, raw[j].thrust
    end
    print(dir)
    print(string.format("  %d marks (want 10); altitude %.0f ft", #marks, raw[1].alt))
    for k = 1, #STEPS do
        local tm = marks[k + 1]
        if not tm then break end
        local before, after = {}, {}
        for i = 1, #T do
            if T[i] >= tm - 3 and T[i] < tm - 0.2 then before[#before + 1] = U[i] end
            if T[i] >= tm + 2 and T[i] < tm + SPAN then after[#after + 1] = U[i] end
        end
        local u0, u1 = median(before), median(after)
        local du = u1 - u0
        local t0
        for i = 1, #T do
            if T[i] >= tm - 0.5 and math.abs(U[i] - u0) > math.abs(du) / 2 then t0 = T[i - 1] or T[i]; break end
        end
        print(string.format("  step %-6s at %.1f s: throttle %.3f -> %.3f (%+.3f)", STEPS[k], t0 or tm, u0, u1, du))
        if t0 and math.abs(du) > 0.01 then
            for _, out in ipairs({"epr", "n1", "dn1", "thrust"}) do
                local a, b = fit_step(T, Y[out], t0, du)
                print(string.format("    %-6s 1st: d %.2f s, tau %5.2f s, K %8.3f, R2 %.4f | 2 lags: d %.1f s, tau %5.2f + %5.2f s, K %8.3f, R2 %.4f",
                    out, a.d, a.tau, a.K, a.r2, b.d, b.tau1, b.tau2, b.K, b.r2))
            end
        end
    end
end

for _, dir in ipairs(arg) do report(dir) end
