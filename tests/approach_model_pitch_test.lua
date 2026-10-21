-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The approach model's pitch loop (approach_model.lua's o.pitch_loop) against p32-line1's G/S (2026-10-20, EHAM
-- ILS 18R from 2,300 to 400 ft above it, flaps 30, 169 to 133 kt; tests/data/p32-line1_gs_pitch.csv, from the
-- kit's session.csv): the recorded flight director's pitch replayed at 34 fps through the pitch loop as that
-- flight flew it (ap_pitch_assist on 9de57915: pid.lua with kp = ki = kd = 0.07, its output taken to the elevator's
-- ratio by B747_interpolate_value in B747_rescale(1, 3, 10, 10, |error|) s over the range; the surface moved by
-- pressure_output's B747_interpolate_value a frame later) against M.PITCH_DYNAMICS, with the recorded flight path
-- (pitch - alpha), trim and IAS, gives the recorded attitude within 0.08 deg rms (0.042) and 0.3 deg (0.16) and
-- the elevator's ratio within 0.07 rms (0.047); the model flies EHAM's approach to 200 ft with the loop at 20 and
-- 34 fps, the attitude within 1 deg of the FD on the G/S (0.43 and 0.41).
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

check(type(model.PITCH_DYNAMICS) == "table" and type(model.pitch_acceleration) == "function"
    and type(model.elevator_deg) == "function", "the model's pitch dynamics")

-- the recording
local rows, header = {}, nil
local file = assert(io.open("tests/data/p32-line1_gs_pitch.csv"))
for line in file:lines() do
    if not header then
        header = {}
        for name in line:gmatch("[^,]+") do header[#header + 1] = name end
    else
        local row, k = {}, 0
        for value in line:gmatch("[^,]+") do
            k = k + 1
            row[header[k]] = tonumber(value)
        end
        rows[#rows + 1] = row
    end
end
file:close()
check(#rows >= 800, "the recording's rows: "..#rows)
local function at(t, key)
    local lo, hi = 1, #rows
    if t <= rows[1].t then return rows[1][key] end
    if t >= rows[#rows].t then return rows[#rows][key] end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if rows[mid].t <= t then lo = mid else hi = mid end
    end
    local a, b = rows[lo], rows[hi]
    return a[key] + (b[key] - a[key]) * (t - a.t) / (b.t - a.t)
end

if model.PITCH_DYNAMICS then
    -- the pitch loop as p32-line1 flew it, on the hydraulics' pid.lua, B747_interpolate_value and B747_rescale
    local dt = 1 / 34
    local d = {simDRTime = 0, SIM_PERIOD = dt}
    local _, hyd = model.load(d)
    local pid = hyd.newPid()
    pid.kp, pid.ki, pid.kd, pid.minout, pid.maxout = 0.07, 0.07, 0.07, -1, 1
    local first = rows[1]
    local theta, q, ratio = first.pitch, first.q, first.elevator_ratio
    local surface, last_ratio = model.elevator_deg(ratio), ratio
    pid.input, pid.target, pid.output = theta, first.fd, ratio
    pid:compute(true)
    pid._lasterr = first.fd - first.pitch
    local t, k = 0, 2
    local sse, sse_ratio, n, worst, worst_t = 0, 0, 0, 0, 0
    while t < rows[#rows].t do
        local fd = at(t, "fd")
        d.simDRTime = t + dt
        pid.input, pid.target = theta, fd
        pid:compute()
        ratio = hyd.B747_interpolate_value(ratio, pid.output, -1, 1, hyd.B747_rescale(1, 3, 10, 10, math.abs(fd - theta)))
        surface = hyd.B747_interpolate_value(surface, model.elevator_deg(last_ratio), -22, 17, 0.75)
        last_ratio = ratio
        local gamma = at(t, "pitch") - at(t, "alpha")
        local qdot = model.pitch_acceleration(at(t, "ias"), theta - gamma, surface, at(t, "trim"), q)
        q = q + qdot * dt
        theta = theta + q * dt
        t = t + dt
        while k <= #rows and rows[k].t <= t do
            local e = theta - rows[k].pitch
            sse, sse_ratio, n = sse + e * e, sse_ratio + (ratio - rows[k].elevator_ratio) ^ 2, n + 1
            if math.abs(e) > math.abs(worst) then worst, worst_t = e, rows[k].t end
            k = k + 1
        end
    end
    local rms, rms_ratio = math.sqrt(sse / n), math.sqrt(sse_ratio / n)
    check(rms <= 0.08, string.format("p32-line1's G/S replayed: the attitude within 0.08 deg rms, %.3f", rms))
    check(math.abs(worst) <= 0.3, string.format("p32-line1's G/S replayed: the attitude within 0.3 deg, %+.2f at %.0f s",
        worst, worst_t))
    check(rms_ratio <= 0.07, string.format("p32-line1's G/S replayed: the elevator's ratio within 0.07 rms, %.3f",
        rms_ratio))

    -- EHAM's approach with the pitch loop at 20 and 34 fps
    for _, fps in ipairs({20, 34}) do
        local name = string.format("eham with the pitch loop at %d fps", fps)
        local o = model.eham({pitch_loop = true, dt = 1 / fps})
        local ok, m = pcall(model.fly, o)
        check(ok, name..": "..tostring(m))
        if ok then
            local elev, last, apart, apart_at = o.threshold[3], nil, 0, nil
            for _, p in ipairs(m.track) do
                if p.pitch_mode == 2 then
                    if math.abs(p.theta - p.fd) > apart then apart, apart_at = math.abs(p.theta - p.fd), p end
                    last = p
                end
            end
            check(last ~= nil and last.alt - elev <= 210, name..": to 200 ft on the G/S")
            check(apart <= 1, string.format("%s: the attitude within 1 deg of the FD on the G/S, %.2f at %.0f ft",
                name, apart, apart_at and apart_at.alt - elev or -1))
            check(m.track[#m.track].elevator ~= nil and m.track[#m.track].trim ~= nil,
                name..": the elevator and trim in the track")
        end
    end
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("approach model pitch loop tests passed: "..checks)
