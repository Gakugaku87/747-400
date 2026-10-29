-- The engines' idle in a flight-test recording, mark by mark, for tuning the
-- EEC's idle and the acf's idle fuel flow (PROGRESS.md 5f, the engines):
--   luajit tests/flight/tools/idle_sweep.lua <run folder> [window s]
-- The run folder holds session.csv and events.csv (tests/flight/measure/
-- aero_idle_ground.json, aero_idle_sweep.json). For the window (default
-- 20 s) after each mark: altitude, KIAS, Mach (standard atmosphere), TAT,
-- V/S, and the four engines' mean X-Plane N1 and N2, fuel flow (kg/s) and
-- thrust (POINT_thrust, kN), with the fuel flow per thrust (lb/lbf/h) when
-- the thrust is above 1 kN.
local dir, window = arg[1], tonumber(arg[2] or "20")
assert(dir, "usage: idle_sweep.lua <run folder> [window s]")
dir = dir:gsub("[/\\]$", "")

local function mach(cas, h)
    local d = (1 - 6.87559e-6 * h) ^ 5.25588   -- p / p0 below 36,089 ft
    if h > 36089 then d = 0.223361 * math.exp(-4.80637e-5 * (h - 36089)) end
    local qc = ((1 + 0.2 * (cas / 661.4786) ^ 2) ^ 3.5 - 1)  -- qc / p0
    return math.sqrt(5 * ((qc / d + 1) ^ (2 / 7) - 1))
end

local function read_csv(path)
    local f = assert(io.open(path, "rb"), "no " .. path)
    local col, n = {}, 0
    -- (the recorder writes CRLF on Windows: the last name would keep the CR)
    for name in (f:read("*l"):gsub("\r$", "")):gmatch("[^,]+") do n = n + 1; col[name] = n end
    local rows = {}
    for line in f:lines() do
        local v, k = {}, 0
        for x in (line .. ","):gmatch("([^,]*),") do k = k + 1; v[k] = tonumber(x) or x end
        if k >= n then rows[#rows + 1] = v end  -- a row cut short (the recording stopped) is left out
    end
    f:close()
    return col, rows
end
local col, rows = read_csv(dir .. "/session.csv")
local ecol, events = read_csv(dir .. "/events.csv")
local marks = {}
for _, e in ipairs(events) do
    if e[ecol.state] == "mark" then marks[#marks + 1] = tonumber(e[ecol.t]) end
end

print(string.format("%s: %d rows, %d marks, the %d s after each", dir, #rows, #marks, window))
print(" mark    alt  KIAS  Mach   TAT    V/S    N1    N2   FF kg/s  thrust kN  SFC")
for k, tm in ipairs(marks) do
    local s, n = {alt = 0, ias = 0, tat = 0, vs = 0, n1 = 0, n2 = 0, ff = 0, thrust = 0}, 0
    for _, v in ipairs(rows) do
        local t = v[col.t]
        if t >= tm and t <= tm + window then
            n = n + 1
            s.alt, s.ias, s.vs = s.alt + v[col.alt], s.ias + v[col.ias], s.vs + v[col.vs]
            s.tat = s.tat + (col.tat and v[col.tat] or 0)
            s.thrust = s.thrust + v[col.thrust]
            for e = 1, 4 do
                s.n1 = s.n1 + v[col["n1_" .. e]] / 4
                s.n2 = s.n2 + v[col["n2_" .. e]] / 4
                s.ff = s.ff + v[col["ff_" .. e]] / 4
            end
        end
    end
    if n > 0 then
        for c in pairs(s) do s[c] = s[c] / n end
        local m = s.ias > 30 and mach(s.ias, s.alt) or 0
        local thrust_kn = s.thrust / 1000
        local sfc = ""
        -- kg/s per kN -> lb/lbf/h: x 3600 (h) / 101.97 (kgf per kN)
        if thrust_kn > 1 then sfc = string.format("%.3f", s.ff * 3600 / (thrust_kn * 101.97)) end
        print(string.format("%5d %6.0f %5.0f %5.3f %5.1f %6.0f %5.1f %5.1f %8.3f %9.2f  %s",
            k, s.alt, s.ias, m, s.tat, s.vs, s.n1, s.n2, s.ff, thrust_kn, sfc))
    end
end
