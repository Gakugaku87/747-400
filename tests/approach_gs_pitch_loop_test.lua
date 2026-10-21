-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The glide slope flown in the approach model with the production pitch loop (approach_model.lua's pitch_loop:
-- ap_pitch_assist and pressure_output against X-Plane's pitch dynamics fitted to p32-line1's G/S) at 20 and 34 fps:
-- EHAM's ILS 18R as flown (160 kt to 4 nm), slowing from 175 kt at AM622 (also with local_vy tilted by 150 fpm, as
-- X-Plane's local frame is away from its reference point: the law takes the V/S from the elevation), in a 15 kt
-- tailwind, and EINN's ILS 06 captured from 1,500 ft above the path. From 1,500 to 200 ft above the runway each stays
-- within 0.75 dot of the beam, never climbs, and the pitch reverses at most 3 times (0.02 deg steps in the 0.5 s
-- track). The G/S law that moved the pitch by steps for the VSI's error hunted around the beam with the loop
-- (p32-line1: +-0.6 deg at 13-16 s; in the model 9-11 reversals) and fell 1.35 dots below slowing from 175 kt.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local CASES = {
    {"eham", {}, "EHAM as flown"},
    {"eham", {min_speeds = {{3.99, 175}}, vref_kt = 134}, "EHAM from 175 kt at AM622"},
    {"eham", {min_speeds = {{3.99, 175}}, vref_kt = 134, local_vy_bias_fpm = 150},
        "EHAM from 175 kt at AM622, local_vy tilted +150 fpm"},
    {"eham", {wind = {{0, 360, 15}, {10000, 360, 15}}}, "EHAM in a 15 kt tailwind"},
    {"einn", {alt_ft = 6640}, "EINN 1,500 ft high"},
}
for _, fps in ipairs({20, 34}) do
    for _, case in ipairs(CASES) do
        local name = string.format("%s at %d fps", case[3], fps)
        local o = model[case[1]](case[2])
        o.pitch_loop, o.dt, o.stop_agl_ft = true, 1 / fps, 150
        local ok, m = pcall(model.fly, o)
        check(ok, name..": "..tostring(m))
        if ok then
            local elev = o.threshold[3]
            local worst, worst_at, climb, reversals, last_dir, prev, seen = 0, nil, nil, 0, 0, nil, false
            for _, p in ipairs(m.track) do
                local agl = p.alt - elev
                if p.pitch_mode == 2 and agl < 1500 and agl > 200 then
                    seen = true
                    if math.abs(p.dots) > math.abs(worst) then worst, worst_at = p.dots, agl end
                    if p.vs > 0 and not climb then climb = p end
                    if prev then
                        local step = p.theta - prev.theta
                        local dir = step > 0.02 and 1 or (step < -0.02 and -1 or 0)
                        if dir ~= 0 then
                            if last_dir ~= 0 and dir ~= last_dir then reversals = reversals + 1 end
                            last_dir = dir
                        end
                    end
                    prev = p
                end
            end
            check(seen, name..": in G/S from 1,500 to 200 ft")
            check(math.abs(worst) <= 0.75, string.format("%s: within 0.75 dot from 1,500 to 200 ft, %+.2f at %.0f ft",
                name, worst, worst_at or -1))
            check(climb == nil, string.format("%s: no climb below 1,500 ft%s", name,
                climb and string.format(" (%+.0f fpm at %.0f ft)", climb.vs, climb.alt - elev) or ""))
            check(reversals <= 3, string.format("%s: the pitch reverses at most 3 times from 1,500 to 200 ft, %d",
                name, reversals))
        end
    end
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("approach G/S with the pitch loop tests passed: "..checks)
