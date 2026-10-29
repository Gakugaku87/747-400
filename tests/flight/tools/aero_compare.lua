-- Steady flight in a flight-test recording against the FCOM's Flight With
-- Unreliable Airspeed tables (PW4056: FCOM PI.10.38-10.40, p.264-266), for
-- comparing the custom acf's flight model (PROGRESS.md 5f):
--   luajit tests/flight/tools/aero_compare.lua <run folder> [window s] [t...]
-- The run folder holds session.csv and events.csv (tests/flight/measure/
-- aero_*.json). Level and glide path segments: the window (default 30 s)
-- after each mark (or after each recording time t given), read as the
-- table its flap lever, altitude and speed
-- point to: cruise (.84/290), holding (10,000 ft), terminal area (5,000 ft,
-- flaps UP to 20) or final approach (1,500 ft, 3 deg, flaps 25 and 30).
-- Climbs (290/.84, max climb thrust) and idle descents (.84/290) with the
-- flaps up: each table altitude crossed, averaged over 300 ft each side.
-- The tables give pitch, EPR and N1 (and the KIAS) by weight; the tool
-- interpolates in weight and altitude and prints measured minus FCOM.
local dir, window = arg[1], tonumber(arg[2] or "30")
assert(dir, "usage: aero_compare.lua <run folder> [window s]")
dir = dir:gsub("[/\\]$", "")

-- FCOM PI.10.38-10.40 (PW4056), weights in 1000 kg. Rows: pressure
-- altitude (ft) -> per weight {pitch, V/S} or {pitch, EPR, N1}; nil where
-- the table is empty
local W5 = {200, 250, 300, 350, 390}
local CLIMB = {  -- 290/.84, flaps up, max climb thrust: pitch, V/S
    [40000] = {{3.5, 1500}, {3.5, 700}},
    [35000] = {{4.5, 2900}, {4.0, 1900}, {4.0, 1200}, {3.5, 500}},
    [30000] = {{4.5, 2700}, {4.5, 1900}, {4.5, 1400}, {4.5, 900}, {5.0, 500}},
    [20000] = {{7.5, 4100}, {7.0, 3100}, {6.5, 2400}, {6.5, 1800}, {6.5, 1400}},
    [10000] = {{10.5, 5300}, {9.5, 4100}, {9.0, 3200}, {8.5, 2600}, {8.5, 2100}},
    [0] = {{13.0, 6100}, {11.5, 4700}, {10.5, 3800}, {10.5, 3000}, {10.0, 2600}},
}
local CRUISE = {  -- .84/290, flaps up, level: pitch, EPR, N1
    [40000] = {{2.0, 1.16, 83.2}, {2.5, 1.31, 88.0}},
    [35000] = {{1.0, 1.08, 80.6}, {2.0, 1.14, 83.0}, {2.5, 1.24, 86.3}, {3.0, 1.43, 92.2}},
    [30000] = {{1.0, 1.02, 77.3}, {2.0, 1.07, 79.8}, {3.0, 1.13, 82.6}, {3.5, 1.21, 85.7}, {4.0, 1.32, 89.3}},
    [20000] = {{1.5, 0.97, 70.5}, {2.5, 0.99, 72.7}, {3.0, 1.03, 75.3}, {4.0, 1.07, 78.1}, {4.5, 1.11, 80.8}},
    [10000] = {{1.5, 0.96, 64.3}, {2.5, 0.98, 66.3}, {3.5, 1.00, 68.7}, {4.5, 1.02, 71.1}, {5.0, 1.04, 73.3}},
    [0] = {{1.5, 0.97, 55.6}, {2.5, 0.98, 57.8}, {3.5, 0.99, 60.4}, {4.5, 1.00, 63.2}, {5.0, 1.01, 65.7}},
}
local DESCENT = {  -- .84/290, flaps up, idle: pitch, V/S
    [40000] = {{-1.5, -2800}, {-0.5, -2700}},
    [35000] = {{-3.5, -3800}, {-2.0, -3400}, {-1.5, -3200}, {-0.5, -3300}},
    [30000] = {{-2.0, -2600}, {-0.5, -2300}, {0.0, -2200}, {1.0, -2100}, {1.5, -2200}},
    [20000] = {{-2.0, -2500}, {-1.0, -2200}, {0.0, -2100}, {1.0, -2000}, {1.5, -2000}},
    [10000] = {{-2.5, -2200}, {-1.0, -1900}, {0.5, -1800}, {1.5, -1700}, {2.0, -1700}},
    [0] = {{-2.5, -1900}, {-1.0, -1700}, {0.5, -1500}, {1.5, -1500}, {2.0, -1500}},
}
-- holding, 10,000 ft, flaps up, level: pitch, EPR, N1, KIAS
local HOLDING = {{5.5, 1.01, 55.9, 208}, {6.0, 1.02, 61.4, 224}, {6.0, 1.03, 66.5, 242}, {5.5, 1.04, 70.5, 266},
                 {5.5, 1.04, 73.3, 283}}
local W6 = {200, 250, 300, 350, 400, 410}
-- terminal area, 5,000 ft, level (flaps 20 gear down): flap -> pitch, EPR,
-- N1, KIAS (VREF30 + 80, 60, 40, 20, 10)
local TERMINAL = {
    [0] = {{5.0, 1.01, 51.4, 208}, {5.5, 1.03, 57.5, 224}, {5.5, 1.04, 62.5, 239}, {6.0, 1.06, 67.1, 253},
           {6.5, 1.07, 70.8, 266}, {6.5, 1.08, 71.5, 269}},
    [1] = {{6.5, 1.03, 53.9, 188}, {7.0, 1.05, 60.2, 204}, {7.0, 1.06, 64.8, 219}, {7.5, 1.08, 68.9, 233},
           {7.5, 1.10, 72.7, 246}, {7.5, 1.10, 73.4, 249}},
    [5] = {{7.5, 1.06, 57.9, 168}, {7.5, 1.08, 63.6, 184}, {8.0, 1.10, 68.4, 199}, {8.0, 1.12, 72.7, 213},
           {8.0, 1.15, 76.5, 226}, {8.0, 1.15, 77.2, 229}},
    [10] = {{8.5, 1.07, 57.8, 148}, {8.5, 1.09, 63.8, 164}, {8.5, 1.11, 68.8, 179}, {9.0, 1.14, 73.1, 193},
            {9.0, 1.16, 77.0, 206}, {9.0, 1.17, 77.7, 209}},
    [20] = {{7.5, 1.10, 64.0, 138}, {7.5, 1.13, 69.9, 154}, {7.5, 1.17, 75.2, 169}, {7.5, 1.21, 79.9, 183},
            {7.5, 1.25, 83.7, 196}, {7.5, 1.26, 84.4, 199}},
}
-- final approach, 1,500 ft, gear down, EPR for a 3 deg glideslope: flap ->
-- pitch, EPR, N1, KIAS (VREF25 + 10, VREF30 + 10)
local FINAL = {
    [25] = {{2.0, 1.05, 48.8, 143}, {2.0, 1.06, 54.8, 159}, {2.0, 1.07, 59.7, 175}, {2.0, 1.08, 63.7, 189},
            {2.0, 1.10, 67.2, 203}, {2.0, 1.10, 67.9, 205}},
    [30] = {{0.5, 1.07, 55.8, 138}, {1.0, 1.09, 61.8, 154}, {1.0, 1.11, 66.8, 168}},
}

-- a row's entry at weight t (linear; nil outside the filled part)
local function by_weight(ws, row, t)
    for i = 1, #ws - 1 do
        if t >= ws[i] - 1e-6 and t <= ws[i + 1] + 1e-6 then
            local a, b = row[i], row[i + 1]
            if not (a and b) then return nil end
            local f = (t - ws[i]) / (ws[i + 1] - ws[i])
            local out = {}
            for k = 1, #a do out[k] = a[k] + (b[k] - a[k]) * f end
            return out
        end
    end
    return nil
end
-- a table by altitude rows at altitude h and weight t (linear in both)
local ALTS = {0, 10000, 20000, 30000, 35000, 40000}
local function by_alt(tbl, h, t)
    for i = 1, #ALTS - 1 do
        local h0, h1 = ALTS[i], ALTS[i + 1]
        if h >= h0 - 1 and h <= h1 + 1 then
            local a, b = by_weight(W5, tbl[h0], t), by_weight(W5, tbl[h1], t)
            local f = (h - h0) / (h1 - h0)
            if f < 0.02 then return a elseif f > 0.98 then return b end
            if not (a and b) then return nil end
            local out = {}
            for k = 1, #a do out[k] = a[k] + (b[k] - a[k]) * f end
            return out
        end
    end
    return nil
end

-- the standard atmosphere: Mach from calibrated airspeed (kt) and pressure
-- altitude (ft), and the table's speed (290 KIAS, .84 above the crossover)
local function mach(cas, h)
    local d = (1 - 6.87559e-6 * h) ^ 5.25588   -- p / p0 below 36,089 ft
    if h > 36089 then d = 0.223361 * math.exp(-4.80637e-5 * (h - 36089)) end
    local qc = ((1 + 0.2 * (cas / 661.4786) ^ 2) ^ 3.5 - 1)  -- qc / p0
    return math.sqrt(5 * ((qc / d + 1) ^ (2 / 7) - 1))
end
local function cas_of_mach(m, h)
    local lo, hi = 50, 400
    for _ = 1, 40 do
        local mid = (lo + hi) / 2
        if mach(mid, h) < m then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end
local function table_speed(h) return math.min(290, cas_of_mach(0.84, h)) end
-- the flight path angle (deg) of a V/S (fpm) at that CAS and altitude in
-- still air (ISA: the true airspeed from the Mach)
local function path_deg(vs, cas, h)
    local tas = mach(cas, h) * 661.4786 * math.sqrt(math.max(216.65, 288.15 - 0.0019812 * h) / 288.15)
    return math.deg(math.asin(math.max(-1, math.min(1, vs / (tas * 101.2686)))))
end

-- the recording
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
for _, c in ipairs({"t", "alt", "ias", "vs", "pitch", "flap", "weight", "alpha", "trim", "elevator_ratio",
                    "epr_1", "n1_1", "thro_1"}) do
    assert(col[c], "no column " .. c)
end
local marks = {}
for i = 3, #arg do marks[#marks + 1] = assert(tonumber(arg[i]), "a time: " .. arg[i]) end
if #marks == 0 then
    local ecol, events = read_csv(dir .. "/events.csv")
    for _, e in ipairs(events) do
        if e[ecol.state] == "mark" then marks[#marks + 1] = tonumber(e[ecol.t]) end
    end
end
assert(#rows > 30, "too few rows")

local DETENTS = {[0] = 0, 1, 5, 10, 20, 25, 30}
local function avg(r0, r1)
    local s, n = {}, 0
    local names = {"alt", "ias", "vs", "pitch", "flap", "weight", "alpha", "trim", "elevator_ratio"}
    for _, c in ipairs(names) do s[c] = 0 end
    s.epr, s.n1, s.thro = 0, 0, 0
    -- X-Plane's own forces (the recorder from v4), in the wind axes: the
    -- aerodynamic lift and drag and the engines' force along the path
    local forces = col.faxil_aero and col.fnrml_aero and col.faxil_prop and col.fnrml_prop
    s.lift, s.drag, s.prop = forces and 0, forces and 0, forces and 0
    for r = r0, r1 do
        local v = rows[r]
        for _, c in ipairs(names) do s[c] = s[c] + v[col[c]] end
        if forces then
            local a = math.rad(v[col.alpha])
            local fx, fn = v[col.faxil_aero], v[col.fnrml_aero]
            s.drag = s.drag + fx * math.cos(a) + fn * math.sin(a)
            s.lift = s.lift + fn * math.cos(a) - fx * math.sin(a)
            s.prop = s.prop - v[col.faxil_prop] * math.cos(a) - v[col.fnrml_prop] * math.sin(a)
        end
        -- the EPR and N1 the EICAS shows when recorded (v5: the EEC and the
        -- A/T hold these), else X-Plane's engine's
        for e = 1, 4 do
            s.epr = s.epr + v[col[(col.depr_1 and "depr_" or "epr_") .. e]] / 4
            s.n1 = s.n1 + v[col[(col.dn1_1 and "dn1_" or "n1_") .. e]] / 4
            s.thro = s.thro + v[col["thro_" .. e]] / 4
        end
        n = n + 1
    end
    for c, x in pairs(s) do s[c] = x / n end
    s.n, s.t0, s.t1 = n, rows[r0][col.t], rows[r1][col.t]
    s.detent = DETENTS[math.floor(s.flap * 6 + 0.5)]
    s.tons = s.weight / 1000
    return s
end

local function line(label, s, ref, ref_ias)
    print(string.format("%-22s t %6.0f-%-6.0f %6.0f ft  %5.1f kt (M%.3f)  %6.0f fpm (%+.2f deg)  %5.1f t  flaps %d",
        label, s.t0, s.t1, s.alt, s.ias, mach(s.ias, s.alt), s.vs, path_deg(s.vs, s.ias, s.alt), s.tons, s.detent))
    print(string.format("%22s pitch %5.2f  alpha %5.2f  EPR %5.3f  N1 %5.1f  lever %.2f  trim %+.3f  elevator %+.3f",
        "", s.pitch, s.alpha, s.epr, s.n1, s.thro, s.trim, s.elevator_ratio))
    if s.drag then
        local w = s.weight * 9.80665
        print(string.format("%22s X-Plane: lift/W %.3f  drag/W %.4f (L/D %.1f)  engines along the path/W %+.4f (%.0f kN each)",
            "", s.lift / w, s.drag / w, s.lift / s.drag, s.prop / w, s.prop / 4000))
        -- the coefficients on 541.2 m2 (the reference area: only the ratios
        -- matter) and the dynamic pressure from the CAS (low Mach)
        local qs = 0.5 * 1.225 * (s.ias * 0.514444) ^ 2 * 541.2
        print(string.format("%22s CL %.3f  CD %.4f", "", s.lift / qs, s.drag / qs))
    end
    if not ref then
        print(string.format("%22s FCOM: no value for this weight and altitude", ""))
        return
    end
    local parts = {string.format("pitch %5.2f (%+.2f)", ref.pitch, s.pitch - ref.pitch)}
    if ref.epr then parts[#parts + 1] = string.format("EPR %5.3f (%+.3f)", ref.epr, s.epr - ref.epr) end
    if ref.n1 then parts[#parts + 1] = string.format("N1 %5.1f (%+.1f)", ref.n1, s.n1 - ref.n1) end
    if ref.vs then parts[#parts + 1] = string.format("V/S %5.0f (%+.0f)", ref.vs, s.vs - ref.vs) end
    if ref_ias then parts[#parts + 1] = string.format("KIAS %5.1f (%+.1f)", ref_ias, s.ias - ref_ias) end
    print(string.format("%22s FCOM: %s", "", table.concat(parts, "  ")))
    -- the pitch less the flight path angle (the body's angle of attack in
    -- still air), which the thrust does not change: the FCOM's at its V/S
    -- (the glide path 3 deg) against the measured
    local fcom_path = ref.vs and path_deg(ref.vs, ref_ias or s.ias, s.alt) or (ref.glide and -3) or 0
    local here = s.pitch - path_deg(s.vs, s.ias, s.alt)
    print(string.format("%22s pitch - path: %5.2f, FCOM %5.2f (%+.2f)", "", here, ref.pitch - fcom_path,
        here - (ref.pitch - fcom_path)))
    -- an idle descent: (drag - idle thrust) / weight is the sine of the
    -- path's angle (its ratio to the FCOM's: the drag's, near enough)
    if ref.vs and ref.vs < 0 and s.vs < 0 then
        local a, b = math.sin(math.rad(-path_deg(s.vs, s.ias, s.alt))), math.sin(math.rad(-fcom_path))
        print(string.format("%22s (drag - thrust) / weight: %.4f, FCOM %.4f (x %.2f)", "", a, b, a / b))
    end
end

-- the rows of a time window
local function rows_between(t0, t1)
    local a, b
    for r = 1, #rows do
        local t = rows[r][col.t]
        if not a and t >= t0 then a = r end
        if t <= t1 then b = r end
    end
    return a, b
end

print(string.format("%s: %d rows, %.0f s, %d mark(s); FCOM PI.10.38-10.40 (PW4056); EPR and N1 %s", dir, #rows,
    rows[#rows][col.t] - rows[1][col.t], #marks, col.depr_1 and "as the EICAS shows them" or "X-Plane's engine's (recorder before v5)"))
print("level and glide path: the " .. window .. " s after each mark")
for k, tm in ipairs(marks) do
    local a, b = rows_between(tm, tm + window)
    if a and b and b > a then
        local s = avg(a, b)
        local label, ref, ref_ias
        if math.abs(s.vs) >= 300 and not (s.detent >= 25 and s.vs < -400) then
            label = "(not level nor a glide path)"
        elseif s.detent == 25 or s.detent == 30 then
            local e = by_weight(W6, FINAL[s.detent], s.tons)
            label = string.format("final approach %d", s.detent)
            if e then ref, ref_ias = {pitch = e[1], epr = e[2], n1 = e[3], glide = true}, e[4] end
        elseif s.detent > 0 or math.abs(s.alt - 5000) < 1500 then
            local e = TERMINAL[s.detent] and by_weight(W6, TERMINAL[s.detent], s.tons)
            label = string.format("terminal area %d", s.detent)
            if e then ref, ref_ias = {pitch = e[1], epr = e[2], n1 = e[3]}, e[4] end
        else
            local hold = math.abs(s.alt - 10000) < 1500 and by_weight(W5, HOLDING, s.tons)
            if hold and math.abs(s.ias - hold[4]) < math.abs(s.ias - table_speed(s.alt)) then
                label, ref, ref_ias = "holding", {pitch = hold[1], epr = hold[2], n1 = hold[3]}, hold[4]
            else
                local e = by_alt(CRUISE, s.alt, s.tons)
                label, ref_ias = "cruise", table_speed(s.alt)
                if e then ref = {pitch = e[1], epr = e[2], n1 = e[3]} end
            end
        end
        line(string.format("mark %d %s", k, label), s, ref, ref_ias)
    end
end

-- climbs and descents with the flaps up: each table altitude crossed
print("climbs and descents (flaps up): 300 ft each side of each table altitude crossed")
local HALF_FT = 300
for _, h in ipairs(ALTS) do
    if h > 0 then
        local r = 2
        while r <= #rows do
            local p, v = rows[r - 1], rows[r]
            if (p[col.alt] - h) * (v[col.alt] - h) <= 0 and p[col.alt] ~= v[col.alt] and v[col.flap] < 0.01 then
                local up = v[col.alt] > p[col.alt]
                local a, b = r, r
                while a > 1 and math.abs(rows[a - 1][col.alt] - h) <= HALF_FT do a = a - 1 end
                while b < #rows and math.abs(rows[b + 1][col.alt] - h) <= HALF_FT do b = b + 1 end
                local s = avg(a, b)
                if math.abs(s.vs) >= 500 and (s.vs > 0) == up then
                    local e = by_alt(up and CLIMB or DESCENT, h, s.tons)
                    line(string.format("%s %d", up and "climb" or "descent", h), s,
                        e and {pitch = e[1], vs = e[2]}, table_speed(h))
                end
                r = b + 1
            end
            r = r + 1
        end
    end
end
