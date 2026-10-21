-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P50] The flight director with the autopilot off (the servos off, the pilot flying by hand): its pitch bar shows the
-- director's command, as a 747-400's does whether or not an autopilot is engaged. ap_pitch_assist
-- (B747.19.xt.hydraulics_override.lua) reset the director every frame while the servos were off (B747_reset_pitch_transition,
-- directorLastPitchMode 0): each frame began a mode's transition from the attitude, so in FLCH, VNAV SPD, V/S, VNAV PTH and
-- ALT the bar sat on the attitude and gave no guidance (TO/GA and G/S, kept out of the transition, showed theirs). An
-- autopilot engaged then started from the attitude; it still does, the director reset once as the servos come on.
-- The production director and pitch loop in the climb model (tests/climb_model.lua): the servos off, the elevator left
-- where it is (the pilot holding the attitude, not following the bar).
local CM = dofile("tests/climb_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

-- The mean of the bar's offset from the attitude (deg, the bar above positive) from t0 to t1.
local function mean_offset(m, t0, t1)
    local sum, n = 0, 0
    for _, p in ipairs(m.track) do
        if p.t >= t0 and p.t <= t1 then sum, n = sum + (p.fd - p.theta), n + 1 end
    end
    return n > 0 and sum / n or 0
end

-- One run at 9,000 ft and 250 kt, 230 t, in the pitch mode given, the servos off until engage_at (never when nil); 46 kN
-- an engine about holds 250 kt level there (the model's clean polar), so the attitude stays about where it is.
-- m.frames: the bar and the attitude at every frame (the track has a sample every 0.25 s).
local function run(pitch_mode, o)
    local frames = {}
    local m = CM.fly({
        alt_ft = 9000, ias_kt = 250, target_kt = o.target_kt or 250, weight_kg = 230000, pitch_mode = pitch_mode,
        at_mode = o.at_mode or 5, mcp_alt_ft = o.mcp_alt_ft or 20000, seconds = o.seconds or 20, dt = 1 / 30,
        thrust = function() return o.thrust_n or 46000 end,
        setup = function(m)
            m.d.simDR_autopilot_servos_on = 0
            if o.vs_fpm then m.d.simDR_autopilot_vs_fpm = o.vs_fpm; m.d.simDR_autopilot_vs_status = 2 end
            if o.on_ground then m.d.simDR_touchGround = 1 end
            local assist = m.hyd.ap_pitch_assist
            m.hyd.ap_pitch_assist = function()
                local r = assist()
                frames[#frames + 1] = {t = m.d.simDRTime - 1000, fd = m.d.B747DR_flight_director_pitch,
                    theta = m.d.simDR_AHARS_pitch_heading_deg_pilot, servos = m.d.simDR_autopilot_servos_on}
                return r
            end
        end,
        frame = function(m, t)
            if o.on_ground then m.d.simDR_touchGround = 1 end      -- the director's view only: nothing rotates
            if o.engage_at and t >= o.engage_at and m.d.simDR_autopilot_servos_on == 0 then
                m.d.simDR_autopilot_servos_on = 1
                m.d.B747DR_switching_servos_on = m.d.simDRTime
            end
        end})
    m.frames = frames
    return m
end

-- FLCH SPD climbing (the MCP altitude above) 10 kt faster than its target: the bar above the attitude (pitch up to
-- slow down; climbing, the law does not descend to accelerate, so a slow speed asks for no pitch-down). The speed
-- law's integrator is kept within 2 deg of the attitude with the servos off (P43), so the bar leads by up to about
-- that, plus the proportional part.
local m = run(8, {target_kt = 240})
local offset = mean_offset(m, 5, 20)
check(offset >= 0.5, string.format("FLCH 10 kt fast, the autopilot off: the bar %+.2f deg from the attitude on "
    .."average over 5-20 s (at least +0.5)", offset))

-- VNAV SPD the same way
m = run(4, {target_kt = 240})
offset = mean_offset(m, 5, 20)
check(offset >= 0.5, string.format("VNAV SPD 10 kt fast, the autopilot off: the bar %+.2f deg from the attitude (at "
    .."least +0.5)", offset))

-- FLCH SPD descending (the MCP altitude below) 10 kt slow: the bar below the attitude (pitch down to accelerate)
m = run(8, {target_kt = 260, mcp_alt_ft = 3000, thrust_n = 20000})
offset = mean_offset(m, 5, 20)
check(offset <= -0.5, string.format("FLCH descending 10 kt slow, the autopilot off: the bar %+.2f deg from the "
    .."attitude (at most -0.5)", offset))

-- V/S at -1,500 fpm from level flight: the bar below the attitude (the V/S branch steps the pitch while the attitude
-- is within 0.5 deg of it, so the bar leads by up to about that)
m = run(7, {vs_fpm = -1500})
offset = mean_offset(m, 3, 20)
check(offset <= -0.2, string.format("V/S -1,500 fpm from level, the autopilot off: the bar %.2f deg from the "
    .."attitude (at most -0.2)", offset))

-- Engaging the autopilot after 15 s of FLCH by hand: its command starts from the attitude, as before, then goes over
-- to the director's. Frame by frame: the bar a degree or more ahead of the attitude on the last frame by hand (the
-- director's command), within 0.2 deg of the attitude over the autopilot's first 0.1 s (the reset: without it the
-- command started 2.3 deg off and stayed there), and a degree ahead again once the 0.7 s transition is over.
m = run(8, {target_kt = 240, engage_at = 15, seconds = 25})
local before, first, n, after = nil, 0, 0, nil
for i, f in ipairs(m.frames) do
    if f.servos == 1 then
        if before == nil and i > 1 then before = m.frames[i - 1].fd - m.frames[i - 1].theta end
        if f.t <= 15.1 + 1e-6 then first, n = math.max(first, math.abs(f.fd - f.theta)), n + 1 end
        if after == nil and f.t >= 15.7 - 1e-6 then after = f.fd - f.theta end
    end
end
check(before ~= nil and before >= 1.0, string.format("the autopilot engaged in FLCH: the bar %s deg from the attitude "
    .."on the last frame by hand (at least +1.0)", before and string.format("%+.2f", before) or "nil"))
check(n >= 3 and first <= 0.2, string.format("the autopilot engaged in FLCH: its command %.3f deg from the attitude "
    .."over its first 0.1 s, %d frames (at most 0.2, 3 frames or more)", first, n))
check(after ~= nil and after >= 1.0, string.format("the autopilot engaged in FLCH: the director's command 0.7 s on (the "
    .."bar %s deg from the attitude, at least +1.0)", after and string.format("%+.2f", after) or "nil"))

-- TO/GA on the ground with the servos off (the FD switch on before the takeoff roll): the bar goes to TO/GA's pitch at
-- 2 deg/s, as when the director ran every frame by hand. It runs every 0.1 s now, and stepped a frame's worth an update
-- the bar took four times as long at 30 fps (2.9 to 7.5 deg in 9.7 s frame by frame; review 56).
m = run(1, {on_ground = true, seconds = 12})
local t75
for _, f in ipairs(m.frames) do if t75 == nil and f.fd >= 7.5 then t75 = f.t end end
check(t75 ~= nil and t75 <= 4.0, string.format("TO/GA on the ground, the autopilot off: the bar from %.1f to 7.5 deg in "
    .."%s s (at most 4: 2 deg/s)", m.frames[1].fd, t75 and string.format("%.1f", t75) or "more than 12"))

if #failures > 0 then
    error(#failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"), 0)
end
print("AFDS flight director by hand tests passed: "..checks)
