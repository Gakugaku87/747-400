-- Run from the repository root with LuaJIT: luajit tests/tools/roll_loop_150kt.lua
-- The A/P's inner roll loop (B747.19.xt.afds_control.lua: the aileron
-- trim integrator of ATA22 p.348-349 on the roll command less the bank,
-- the roll rate and the yaw rate; the aileron command's slew) on a model
-- of X-Plane's 747 at 150 kt, flaps 30 and the gear down (6-3 step 4d:
-- docs/overhaul/notes/ATA-22.md §29). The model was fitted with
-- tests/tools/lat_sysid.lua to s115_rudder_steps (2026-10-30: the rudder
-- steps and the 10 degree turns, R2 0.88 to 0.999). For the gains as
-- they were (a PID, 0.05 a degree, almost no integral, the error's
-- derivative) and the loop here it prints: a turn's roll-in (the command
-- at 3 degrees a second to 10) and its error 2 s after; the bank error
-- with the wings held level against rudder steps of 0.1 and 0.3 (the
-- sideslip's roll: the decrab's 5 degrees take about 0.3), the most and
-- after 10 s.
-- (the model: tests/tools/lat_model_150kt.lua)
local A = dofile("tests/tools/lat_model_150kt.lua")
local DT = 1 / 60

-- cfg: kp, ki (a degree-second), kd (the error's derivative, the old
-- PID's), kpr (a degree a second of roll rate), kyr (of yaw rate), ff
-- (true: the roll rate's term on the command's rate less the roll rate),
-- hold (the integral held while the command moves faster than this, and
-- for `after` seconds more)
local function sim(cfg, cmd_of, dr_of, seconds)
    local b, p, r, phi = 0, 0, 0, 0
    local srv, I, laste, acc, hist, lastc, still, cr = 0, 0, 0, 0, {}, 0, 99, 0
    local trace = {}
    for n = 1, math.floor(seconds / DT) do
        local t = n * DT
        local cmd = cmd_of(t)
        acc = acc + DT
        if acc >= 1 / 30 then
            local dt = acc; acc = 0
            local e = cmd - phi
            -- the command's rate smoothed over 0.3 s (afds_control)
            cr = cr + ((cmd - lastc) / dt - cr) * math.min(1, dt / 0.3)
            lastc = cmd
            local moving = cfg.hold and math.abs(cr) > cfg.hold
            if moving then still = 0 else still = still + dt end
            if not moving and still >= (cfg.after or 0) then
                I = math.max(-1, math.min(1, I + cfg.ki * e * dt))
            end
            local crf = cfg.ff and cr or 0
            local out = cfg.kp * e + I + cfg.kd * (e - laste) / dt + cfg.kpr * (crf - p) - cfg.kyr * r
            out = math.max(-1, math.min(1, out))
            laste = e
            -- the slew: full travel in 3 s at 0.1 degree of error, 5 s at 10
            local spd = math.max(3, math.min(5, 3 + (math.abs(e) - 0.1) * 2 / 9.9))
            local step = 2 / spd * dt
            if math.abs(out - srv) <= step then srv = out else srv = srv + (out > srv and step or -step) end
        end
        hist[#hist + 1] = srv
        local da = hist[math.max(1, #hist - math.floor(A.lag / DT))]
        local dr = dr_of(t)
        local db = A.bb * b + A.bp * p + A.br * r + A.bphi * phi + A.bd * dr
        local dp = A.lb * b + A.lp * p + A.lr * r + A.la * da + A.ld * dr
        local drr = A.nb * b + A.np * p + A.nr * r + A.na * da + A.nd * dr
        b, p, r = b + db * DT, p + dp * DT, r + drr * DT
        phi = phi + p * DT
        trace[n] = {t = t, phi = phi, cmd = cmd, da = srv}
    end
    return trace
end

local function at(tr, t) return tr[math.max(1, math.floor(t / DT + 0.5))] end
local function report(name, cfg)
    -- the turn: 10 degrees at 3 a second from 1 s
    local turn = sim(cfg, function(t) return math.min(10, math.max(0, (t - 1) * 3)) end, function() return 0 end, 20)
    local over = 0
    for _, s in ipairs(turn) do over = math.max(over, s.phi - 10) end
    local e2 = 10 - at(turn, 6.33).phi
    local row = {("%-34s turn: overshoot %5.2f, error 2 s after %5.2f"):format(name, over, e2)}
    for _, rud in ipairs({0.1, 0.3}) do
        local tr = sim(cfg, function() return 0 end, function(t) return t > 1 and rud or 0 end, 25)
        local most = 0
        for _, s in ipairs(tr) do most = math.max(most, math.abs(s.phi)) end
        row[#row + 1] = (" | rudder %.1f: most %5.2f, 10 s %5.2f, 20 s %5.2f, aileron %5.2f"):format(rud, most,
            at(tr, 11).phi, at(tr, 21).phi, at(tr, 21).da)
    end
    print(table.concat(row))
end

report("as it was (PID 0.05, 0.0003, d 0.05)", {kp = 0.05, ki = 0.0003, kd = 0.05, kpr = 0, kyr = 0})
for _, c in ipairs({
    {kp = 0.05, ki = 0.025, kd = 0, kpr = 0.03, kyr = 0.01, ff = true, hold = 0.5},
    {kp = 0.05, ki = 0.02, kd = 0, kpr = 0.04, kyr = 0.01, ff = true, hold = 1, after = 2},
}) do
    report(("kp %.3f ki %.3f rate %.3f yaw %.3f%s%s"):format(c.kp, c.ki, c.kpr, c.kyr, c.ff and " ff" or "",
        c.hold and (" hold %g +%gs"):format(c.hold, c.after or 0) or ""), c)
end
