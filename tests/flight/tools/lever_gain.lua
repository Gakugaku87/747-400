-- luajit tests/flight/tools/lever_gain.lua <run folder> [<run folder> ...]
-- The A/T's G in X-Plane (2026-11-22): the acceleration a unit of lever
-- gives (kt/s of IAS), as B747.70.at_model.lua's lever_accel estimates it
-- for the SPD law's gain scale. From a run of tests/flight/measure/
-- at_lever_gain_*.json: the A/T off, the levers set by hand, the marks
-- L0, +0.04, 0, -0.04, 0, +0.08, 0 (40 s each). For each segment, the
-- means of its last LAST_S seconds (lever_1, the mean thrust of an engine
-- `thrust` in N, n1_1, thro_1, the IAS, the TAS) and the IAS's slope over
-- them; for each step from the segment before:
--   GF  the thrust's change, all four engines, over the weight, as kt/s of
--       IAS (dIAS/dTAS at the pressure altitude: the CAS of the Mach),
--   GV  the IAS slope's change,
-- both per unit of lever, and the model's G (lever_accel) at the step.
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")

local LAST_S = 15
local KT = 1852 / 3600

local function split(line)
    local t = {}
    for x in (line:gsub("\r", "") .. ","):gmatch("([^,]*),") do t[#t + 1] = x end
    return t
end

local function read_csv(path)
    local f = assert(io.open(path, "r"))
    local head = split(f:read("*l"))
    local col = {}
    for i, n in ipairs(head) do col[n] = i end
    local rows = {}
    for line in f:lines() do
        local r = split(line)
        if #r >= #head then rows[#rows + 1] = r end
    end
    f:close()
    return col, rows
end

-- the ISA's pressure ratio at a pressure altitude (ft)
local function delta_of(alt)
    if alt <= 36089 then return (1 - 6.8756e-6 * alt) ^ 5.2559 end
    return 0.22336 * math.exp(-(alt - 36089) / 20806)
end
-- the CAS (kt) of a Mach at a pressure ratio, and the Mach of a CAS
local function cas_of(m, d)
    local qc = d * ((1 + 0.2 * m * m) ^ 3.5 - 1)
    return 661.4786 * math.sqrt(5 * ((qc + 1) ^ (2 / 7) - 1))
end
local function mach_of(cas, d)
    local qc = (1 + 0.2 * (cas / 661.4786) ^ 2) ^ 3.5 - 1
    return math.sqrt(5 * ((qc / d + 1) ^ (2 / 7) - 1))
end

local function slope(ts, ys)
    local n, st, sy, stt, sty = #ts, 0, 0, 0, 0
    for i = 1, n do st, sy, stt, sty = st + ts[i], sy + ys[i], stt + ts[i] * ts[i], sty + ts[i] * ys[i] end
    local den = n * stt - st * st
    if n < 3 or math.abs(den) < 1e-9 then return 0 end
    return (n * sty - st * sy) / den
end

for _, dir in ipairs(arg) do
    local col, rows = read_csv(dir .. "/session.csv")
    local _, ev = read_csv(dir .. "/events.csv")
    local marks = {}
    for _, e in ipairs(ev) do if e[3] == "mark" then marks[#marks + 1] = tonumber(e[2]) end end
    local tEnd = tonumber(rows[#rows][col.t])
    print(("== %s (%d marks)"):format(dir, #marks))
    local segs = {}
    for i = 1, #marks do
        local t1 = marks[i + 1] or tEnd
        local t0 = t1 - LAST_S
        local s = {lever = 0, thrust = 0, n1 = 0, thro = 0, ias = 0, tas = 0, alt = 0, weight = 0, n = 0}
        local ts, ys = {}, {}
        for _, r in ipairs(rows) do
            local t = tonumber(r[col.t])
            if t >= t0 and t < t1 then
                s.n = s.n + 1
                s.lever = s.lever + tonumber(r[col.lever_1])
                s.thrust = s.thrust + tonumber(r[col.thrust])
                s.n1 = s.n1 + tonumber(r[col.n1_1])
                s.thro = s.thro + tonumber(r[col.thro_1])
                s.ias = s.ias + tonumber(r[col.ias])
                s.tas = s.tas + tonumber(r[col.tas])
                s.alt = s.alt + tonumber(r[col.alt])
                s.weight = s.weight + tonumber(r[col.weight])
                ts[#ts + 1], ys[#ys + 1] = t, tonumber(r[col.ias])
            end
        end
        for k, v in pairs(s) do if k ~= "n" then s[k] = v / math.max(1, s.n) end end
        s.dv = slope(ts, ys)
        segs[i] = s
        print(("  seg %d  lever %.3f  thro %.3f  N1 %.1f  thrust %.0f N  IAS %.1f (%.3f kt/s)  alt %.0f  %.1f t")
            :format(i, s.lever, s.thro, s.n1, s.thrust, s.ias, s.dv, s.alt, s.weight / 1000))
    end
    local sumF, sumV, sumM, n = 0, 0, 0, 0
    for i = 2, #segs do
        local a, b = segs[i - 1], segs[i]
        local dl = b.lever - a.lever
        if math.abs(dl) > 0.01 then
            local alt = 0.5 * (a.alt + b.alt)
            local d = delta_of(alt)
            local ias, tas_kt = 0.5 * (a.ias + b.ias), 0.5 * (a.tas + b.tas) / KT
            local m = mach_of(ias, d)
            local snd = tas_kt / m
            local dIdT = (cas_of(m + 0.001, d) - cas_of(m - 0.001, d)) / 0.002 / snd
            local w = 0.5 * (a.weight + b.weight)
            local gF = 4 * (b.thrust - a.thrust) / dl / w / KT * dIdT
            local gV = (b.dv - a.dv) / dl
            local gM = A.lever_accel{weight = w, mach = m, tas = tas_kt, ias = ias, alt = alt}
            print(("  step %d->%d  dlever %+.3f  dF %+6.0f N/eng  GF %.2f  GV %.2f  model %.2f  (GF/model %.2f, M %.3f, dIAS/dTAS %.3f)")
                :format(i - 1, i, dl, b.thrust - a.thrust, gF, gV, gM, gF / gM, m, dIdT))
            sumF, sumV, sumM, n = sumF + gF, sumV + gV, sumM + gM, n + 1
        end
    end
    if n > 0 then
        print(("  mean GF %.2f  GV %.2f  model %.2f  GF/model %.2f"):format(sumF / n, sumV / n, sumM / n, sumF / sumM))
    end
end
