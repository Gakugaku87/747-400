-- luajit tests/flight/tools/at_gusts.lua <run folder> [<run folder> ...]
-- The A/T's SPD in the gusts (2026-11-10; notes/ATA-34-61-FMC.md §162),
-- from a run of s277_at_cruise_gusts (session.csv and events.csv): between
-- the scenario's three marks (level, the turn, the descent) the IAS's
-- error to the A/T's target (sim/cockpit2/autopilot/airspeed_dial_kts:
-- the Mach's knots in Mach), its mean, spread and the time over; the
-- levers' travel a minute on 0.6 s reads (lever_1, the 3D lever's 0..1);
-- EPR 1's extremes and its mean range a minute; the air's along-track
-- wind (TAS - GS) and its change over 5 s (rms): how gusty the run was.
local function split(line)
    local t = {}
    for x in (line .. ","):gmatch("([^,]*),") do t[#t + 1] = x end
    return t
end

local function report(dir)
    local marks = {}
    for line in io.lines(dir .. "/events.csv") do
        local f = split(line)
        if f[3] == "mark" then marks[#marks + 1] = tonumber(f[2]) end
    end
    local ix, rows = nil, {}
    for line in io.lines(dir .. "/session.csv") do
        local f = split(line)
        if not ix then
            ix = {}
            for k, name in ipairs(f) do ix[name] = k end
        else
            rows[#rows + 1] = f
        end
    end
    local function col(f, name) return tonumber(f[ix[name]]) end
    print(dir)
    if #marks < 3 then print(string.format("  %d marks (want 3)", #marks)) end
    local names = {"level", "turn", "descent"}
    for s = 1, 3 do
        local t0, t1 = marks[s], marks[s + 1] or math.huge
        if t0 then
            local n, sum, sq, over, lo, hi = 0, 0, 0, 0, 99, -99
            local travel, last_lever, next_read, first_t, last_t = 0, nil, nil, nil, nil
            local elo, ehi, min_t0, mlo, mhi, ranges, nmin = 9, 0, nil, 9, 0, 0, 0
            local w = {}
            for _, f in ipairs(rows) do
                local t = col(f, "t")
                if t and t >= t0 and t < t1 then
                    local e = col(f, "ias") - col(f, "tgt")
                    n, sum, sq = n + 1, sum + e, sq + e * e
                    if e > 0 then over = over + 1 end
                    lo, hi = math.min(lo, e), math.max(hi, e)
                    local lever = col(f, "lever_1")
                    first_t = first_t or t
                    last_t = t
                    if not next_read or t >= next_read then
                        if last_lever then travel = travel + math.abs(lever - last_lever) end
                        last_lever, next_read = lever, t + 0.6
                    end
                    local epr = col(f, "epr_1")
                    elo, ehi = math.min(elo, epr), math.max(ehi, epr)
                    min_t0 = min_t0 or t
                    mlo, mhi = math.min(mlo, epr), math.max(mhi, epr)
                    if t - min_t0 >= 60 then
                        ranges, nmin, min_t0, mlo, mhi = ranges + (mhi - mlo), nmin + 1, nil, 9, 0
                    end
                    w[#w + 1] = {t, col(f, "tas") * 1.943844 - col(f, "gs_kt")}
                end
            end
            if n > 0 then
                local mean = sum / n
                local sd = math.sqrt(math.max(0, sq / n - mean * mean))
                local span = math.max(last_t - first_t, 1)
                -- the wind's change over 5 s, rms
                local j, c, cn = 1, 0, 0
                for k = 1, #w do
                    while j < #w and w[j][1] < w[k][1] - 5 do j = j + 1 end
                    if w[k][1] - w[j][1] >= 4.5 then c, cn = c + (w[k][2] - w[j][2]) ^ 2, cn + 1 end
                end
                print(string.format("  %-7s %4.0f s: IAS - target %+.2f kt (sd %.2f, %.0f %% over, %+.1f..%+.1f); levers %.3f a minute; EPR %.3f..%.3f (%.3f a minute); wind's 5 s change %.2f kt rms",
                    names[s], span, mean, sd, 100 * over / n, lo, hi, travel / span * 60, elo, ehi,
                    nmin > 0 and ranges / nmin or ehi - elo, cn > 0 and math.sqrt(c / cn) or 0))
            end
        end
    end
end

for _, dir in ipairs(arg) do report(dir) end
