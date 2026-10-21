-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The autopilot's roll channel at a high true airspeed (tests/roll_model.lua: the production director filter, roll
-- PID and output timing, and the roll surfaces as pressure_output moves them, against a roll-only aircraft).
-- Light (about 225 t) at FL300, M.81, 305 KIAS (TAS 480 kt) in the climb, p33-line1 and its re-fly (2026-10-20) went
-- into a roll oscillation that grew from a roll rate of +-0.3 deg/s at about 1.4 s to +-25-30 deg/s and +-30-38 deg
-- of bank at about 4.8 s, the inboard ailerons swinging +-16-20 deg against the bank (read live): the kit gave up
-- the climb. p32-line1 at the same point had the start of it (0.14 -> 0.34 deg/s rms). X-Plane ran at 18-27 fps.
-- The roll ratio reaches the surfaces' effect late: the output timing and pressure_output each go a tenth of the
-- way a frame (about 10 frames, more time at a lower frame rate). With the D gain doubled from a 30,000 ft MCP
-- altitude (0.05 -> 0.1) and no gain change with the airspeed, the model at 18, 20 and 25 fps over 96 aircraft
-- each (aileron and spoiler power 40-100 deg/s, the spoilers' share 0-0.8, roll mode 0.3-1 s, the cables 1-2 frames
-- behind) keeps a cycle of 10 deg or more 45 s after a kick in 39 of the 288 and more than 1 deg in 106 (the small
-- one at 1.3-1.5 s), all 48 of the most powerful rolling out from 30 deg of bank, and 68 of 108 over 5 deg after
-- rolling at 28 deg/s at wings level. The D gain now stays 0.05 and the PID's gains fall as the true airspeed rises
-- above 340 kt (x 340 / TAS, at least 0.7: 0.7 at FL300's 480 kt): after a kick or the roll-out from 30 deg no case
-- keeps more than 1 deg of bank (the kit warns of a roll oscillation from 2 deg peak to peak; the D gain alone leaves
-- 8 of the 288 over 1 deg, the scale alone 29), after rolling at 28 deg/s none more than 5 deg (the margin ends near
-- 120 deg/s at 18-20 fps); the 5 deg step at 270 kt reaches 90 % in 3.35 s with the MCP at 5,000 ft and at FL370
-- (3.15 and 3.95 s before: D was 0.1 at FL370).
local model = dofile("tests/roll_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

-- 1. FL300, TAS 480 kt, MCP at FL370: after a roll kick (5 deg/s^2 for 0.3 s), the bank within 1 deg from 45 s on
local kept = {}
for _, fps in ipairs({18, 20, 25}) do
    for _, pre in ipairs({1, 2}) do
        for _, share in ipairs({0, 0.5, 0.8}) do
            for _, gain in ipairs({40, 60, 80, 100}) do
                for _, tau in ipairs({0.3, 0.5, 0.75, 1.0}) do
                    local name = string.format("%d fps, cables %d frames, spoilers %.1f, %d deg/s, %.2f s", fps, pre,
                        share, gain, tau)
                    local ok, track = pcall(model.fly, {gain = gain, tau = tau, share = share, pre = pre, fps = fps,
                        tas_kt = 480, mcp_alt_ft = 37000, seconds = 60, disturb = {2, 2.3, 5}})
                    if not ok then
                        kept[#kept + 1] = name..": "..tostring(track)
                    else
                        local late = model.summary(track, 45)
                        if late.max_phi > 1 then kept[#kept + 1] = string.format("%s: +-%.1f deg", name, late.max_phi) end
                    end
                end
            end
        end
    end
end
check(#kept == 0, #kept.." of 288 aircraft at FL300 (TAS 480 kt) keep more than 1 deg of bank 45 s after a kick: "
    ..table.concat(kept, "; "))

-- 2. the roll-out from 30 deg of bank to wings level (the director's target filtered down from the bank at 3 deg/s),
-- the most powerful spoilers and ailerons
local from30 = {}
for _, fps in ipairs({18, 20, 25}) do
    for _, share in ipairs({0.5, 0.8}) do
        for _, gain in ipairs({80, 100}) do
            for _, tau in ipairs({0.3, 0.5, 0.75, 1.0}) do
                local name = string.format("%d fps, spoilers %.1f, %d deg/s, %.2f s", fps, share, gain, tau)
                local ok, track = pcall(model.fly, {gain = gain, tau = tau, share = share, pre = 2, fps = fps,
                    tas_kt = 480, mcp_alt_ft = 37000, seconds = 60, phi0 = 30})
                if not ok then
                    from30[#from30 + 1] = name..": "..tostring(track)
                else
                    local late = model.summary(track, 45)
                    if late.max_phi > 1 then from30[#from30 + 1] = string.format("%s: +-%.1f deg", name, late.max_phi) end
                end
            end
        end
    end
end
check(#from30 == 0, #from30.." of 48 aircraft at FL300 keep more than 1 deg of bank 45 s after 30 deg: "
    ..table.concat(from30, "; "))

-- 3. an upset: wings level rolling at 28 deg/s (the p33 cycle's peak roll rate), surface power 60-100 deg/s, the
-- cables 2 frames behind: the bank within 5 deg from 45 s on (the margin ends near 120 deg/s at 18-20 fps)
local upset = {}
for _, fps in ipairs({18, 20, 25}) do
    for _, share in ipairs({0, 0.5, 0.8}) do
        for _, gain in ipairs({60, 80, 100}) do
            for _, tau in ipairs({0.3, 0.5, 0.75, 1.0}) do
                local name = string.format("%d fps, spoilers %.1f, %d deg/s, %.2f s", fps, share, gain, tau)
                local ok, track = pcall(model.fly, {gain = gain, tau = tau, share = share, pre = 2, fps = fps,
                    tas_kt = 480, mcp_alt_ft = 37000, seconds = 60, p0 = 28})
                if not ok then
                    upset[#upset + 1] = name..": "..tostring(track)
                else
                    local late = model.summary(track, 45)
                    if late.max_phi > 5 then upset[#upset + 1] = string.format("%s: +-%.1f deg", name, late.max_phi) end
                end
            end
        end
    end
end
check(#upset == 0, #upset.." of 108 aircraft at FL300 keep more than 5 deg of bank 45 s after rolling at 28 deg/s: "
    ..table.concat(upset, "; "))

-- 3. the 5 deg step at TAS 270 kt with the MCP at 5,000 ft and at FL370, aileron power 40 deg/s, roll mode 0.5 s:
-- within 4.5 deg in 3.5 s, at most 5 % over
for _, mcp in ipairs({5000, 37000}) do
    local ok, track = pcall(model.fly, {gain = 40, tau = 0.5, share = 0.5, pre = 1, fps = 20, tas_kt = 270,
        mcp_alt_ft = mcp, seconds = 25, target = function(t) return t >= 2 and 5 or 0 end})
    local t90, peak = nil, 0
    if ok then
        for _, s in ipairs(track) do
            if s.t >= 2 then
                if not t90 and s.phi >= 4.5 then t90 = s.t - 2 end
                peak = math.max(peak, s.phi)
            end
        end
    end
    check(ok and t90 ~= nil and t90 <= 3.5 and peak <= 5.25, string.format(
        "5 deg step at TAS 270 kt, MCP %d ft: 4.5 deg after %s s (<= 3.5), peak %.2f (<= 5.25)%s", mcp, tostring(t90),
        peak, ok and "" or " "..tostring(track)))
end

-- 4. the gains' scale: 1 up to 340 kt, 340 / TAS above, at least 0.7, 1 for a TAS that is not a number
local controls = dofile(model.HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
local KT = 0.514444
for _, case in ipairs({{150, 1}, {270, 1}, {340, 1}, {400, 0.85}, {480, 0.7083}, {600, 0.7}, {0, 1}}) do
    local ok, value = pcall(controls.roll_gain_scale, case[1] * KT)
    check(ok and value and math.abs(value - case[2]) < 0.001, string.format("roll gain scale at %d kt: %s (%.4f)",
        case[1], tostring(value), case[2]))
end
for _, case in ipairs({{0 / 0, "NaN"}, {nil, "nil"}, {math.huge, "inf"}}) do
    local ok, value = pcall(controls.roll_gain_scale, case[1])
    local want = case[2] == "inf" and 0.7 or 1
    check(ok and value == want, string.format("roll gain scale for %s: %s (%.1f)", case[2], tostring(value), want))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS roll at high TAS tests passed: "..checks)
