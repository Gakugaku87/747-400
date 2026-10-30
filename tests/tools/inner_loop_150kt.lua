-- Run from the repository root with LuaJIT: luajit tests/tools/inner_loop_150kt.lua
-- The A/P's inner pitch loop (B747.19.xt.afds_control.lua: its PID, the
-- attitude rate, the elevator command's slew) on a model of X-Plane's 747
-- at 150 kt and flaps 30 on the glide slope (6-3 step 4b:
-- docs/overhaul/notes/ATA-22.md §26). The model was fitted with
-- tests/tools/pitch_sysid.lua to s114's third run (2026-10-30), where the
-- gains scaled g = (250 / IAS)^2 times on all three terms swung the pitch
-- 0.11 degree every 3.3 s; the model swings at that period. Against the
-- airspeed's g it prints, for the attitude rate's gain g to a power and the
-- integral's g to a power: a 1 degree step's overshoot and the swing left
-- after 10 s, and the flare's lag (the command ramping a degree a second
-- for 4 s with a nose-down moment coming in as the retard and the ground
-- effect: 0.3 of the elevator over 2 s from 1.5 s) 2 s and 4 s into the
-- ramp and 2 s after it.
-- qdot = qq q + qa alpha + qe de(lag before); alphadot = aq q + aa alpha + ae de
local A = {qq = -0.8451, qa = -0.2904, qe = 12.347, aq = 0.8371, aa = -0.0480, ae = 1.730, lag = 0.15}
local DT = 1 / 60

local function sim(cfg, cmd_of, dist_of, seconds)
    local th, q, al, de_srv, I, laste, acc, hist = 0, 0, 0, 0, 0, 0, 0, {}
    local trace = {}
    for n = 1, math.floor(seconds / DT) do
        local t = n * DT
        local cmd = cmd_of(t)
        -- the inner loop at 30 Hz: the PID, the attitude rate, the slew
        acc = acc + DT
        if acc >= 1 / 30 then
            local dt = acc; acc = 0
            local e = cmd - th
            I = math.max(-1, math.min(1, I + cfg.ki * e * dt))
            local out = math.max(-1, math.min(1, cfg.kp * e + I + 0.0002 * (e - laste) / dt - cfg.kq * q))
            laste = e
            local spd = math.max(3, math.min(10, 3 + (math.abs(e) - 1) * 7 / 9))
            local step = 2 / spd * dt
            if math.abs(out - de_srv) <= step then de_srv = out else de_srv = de_srv + (out > de_srv and step or -step) end
        end
        hist[#hist + 1] = de_srv
        local de = hist[math.max(1, #hist - math.floor(A.lag / DT))] - dist_of(t)
        local qd = A.qq * q + A.qa * al + A.qe * de
        local ad = A.aq * q + A.aa * al + A.ae * de
        q, al = q + qd * DT, al + ad * DT
        th = th + q * DT
        trace[n] = {t = t, th = th, cmd = cmd}
    end
    return trace
end

local function step(cfg)
    local tr = sim(cfg, function(t) return t > 1 and 1 or 0 end, function() return 0 end, 30)
    local over, swing = 0, 0
    for _, p in ipairs(tr) do
        if p.t > 1 then over = math.max(over, p.th - 1) end
        if p.t > 10 then swing = math.max(swing, math.abs(p.th - 1)) end
    end
    return over, swing
end

local function flare(cfg)
    local tr = sim(cfg, function(t) return math.min(math.max(t - 1, 0), 4) end,
        function(t) return 0.3 * math.min(math.max((t - 2.5) / 2, 0), 1) end, 8)
    local function lag(at) for _, p in ipairs(tr) do if p.t >= at then return p.cmd - p.th end end end
    return lag(3), lag(5), lag(7)
end

print("g     rate ^  integral ^ | step: overshoot  swing after 10 s | flare's lag: 2 s, 4 s into the ramp, 2 s after")
for _, g in ipairs({1, 2.78}) do
    for _, c in ipairs({{1, 1}, {1.5, 1}, {2, 1}, {1.5, 0.5}}) do
        local cfg = {kp = 0.1 * g, ki = 0.1 * g ^ c[2], kq = 0.03 * g ^ c[1]}
        local o, s = step(cfg)
        local l3, l5, l7 = flare(cfg)
        print(("%.2f  %.1f     %.1f       |       %.3f        %.4f        |  %.2f  %.2f  %.2f"):format(g, c[1], c[2], o, s, l3, l5, l7))
    end
end
