-- Run from the repository root with LuaJIT: luajit tests/autopilot/fd_alone_test.lua
-- (2026-11-26) The F/Ds alone, no A/P engaged (the pitch model's FD_S;
-- docs/overhaul/notes/ATA-22.md §72): the pitch attitude integrator is
-- synchronized to the pitch attitude while the A/P is disengaged (ATA22
-- p.332) and the F/D's command is made from the command sections' output
-- and the pitch attitude, not from the integrator (p.333, the pitch axis's
-- diagram), so the F/D's command is the attitude and FD_S seconds of the
-- law's rate. The user's flight (2026-11-25): before CMD the pitch F/D was
-- off after the lift-off; in s109 (2026-11-22) it stood 4 to 6 degrees
-- under the airplane for 6 s while the law asked for more pitch. (Their
-- descent after the acceleration height was on the A/P: spd_flap_ramp_
-- test.lua.) On
-- plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua:
--  - the command: V/S +1,000 not followed for 30 s, the attitude and FD_S
--    of the law's rate (not wound up), the integrator at the attitude; with
--    an A/P the integrator's command as before; the law satisfied, the bar
--    on the attitude; the A/P's engagement from the attitude;
--  - the lift-off and the rotation on to 15 degrees (FCTM p.95: 2.5 degrees
--    a second, the F/D's command not used for the rotation, after the
--    lift-off the F/D the primary pitch reference), the speed over the
--    target: the command at or over the attitude (before, 4 to 6 under);
--  - a pilot holding the bar on the airplane symbol (the attitude 2 s
--    behind the F/D's command, as the A/P's on the lagged airplane): a
--    takeoff to the target, a level-off without an overshoot and within the
--    0.05 g, as the A/P's (afds_pitch_model_test.lua);
--  - a heavy takeoff flown by hand (2.8 kt/s of excess in level flight
--    at the takeoff thrust) held at 15 degrees from the rotation (FCTM p.95)
--    to the acceleration height (VNAV SPD from 400 ft on the speed then,
--    225 kt at 1,000 ft: FCOM p.667), the bar flown from there by a pilot
--    (the column on the bar's error, the pitch rate behind it): climbing
--    all the way (before, the command wound 15 degrees under the airplane by
--    then and the airplane went down at 1,466 fpm); 2.4 kt/s the same
--    (before, down at 3,611 fpm);
--  - not over the PLI in T/O; FLARE (the A/Ps' LAND 2 and 3) as with them.
local T = dofile("tests/lib/check.lua")("fd_alone")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")

local DT, G, KT, FT = 0.1, 9.80665, 1852 / 3600, 0.3048
local G_FT = G / FT
local function inp(o)
    local i = P.inputs()
    i.active, i.tas, i.alt, i.pitch = true, 250, 9000, 2
    for k, v in pairs(o or {}) do i[k] = v end
    return i
end
-- the command's rate at a normal acceleration (degrees a second) at a TAS
local function rate_at(tas, g) return math.deg(g * G / (tas * KT)) end

T.equal(P.FD_S, 2, "FD_S: 2 s of the law's rate (estimate: the A/P's attitude 2 s behind its command)")

-- V/S +1,000 from level at 250 kt of TAS, nobody following (the attitude
-- 2): the law's rate at its 0.05 g (0.219 degree a second), the command
-- 0.44 over the attitude after 30 s as at the first second
local s = P.new()
local i = inp({mode = "VS", vs_sel = 1000, vs = 0, fd_only = true})
local c = P.update(s, i, DT)
local first = c
for _ = 1, math.floor(30 / DT) do c = P.update(s, i, DT) end
T.near(c, 2 + P.FD_S * rate_at(250, P.G_LIMIT), 1e-6,
    ("V/S +1,000 not followed for 30 s: the attitude and FD_S of the law's rate (%.3f; at the first frame %.3f)"):format(c, first))
T.equal(s.cmd, 2, "the integrator at the attitude (ATA22 p.332)")
-- with an A/P (fd_only false) the integrator's command, as before: here
-- nobody follows, so it went on
local sa = P.new()
local ia = inp({mode = "VS", vs_sel = 1000, vs = 0})
for _ = 1, math.floor(30 / DT) do c = P.update(sa, ia, DT) end
T.check(c > 6, ("with an A/P: the integrator's command as before (%.2f after 30 s)"):format(c))
-- V/S +1,000 flown (the law satisfied): the bar on the attitude
s = P.new()
i = inp({mode = "VS", vs_sel = 1000, vs = 1000, pitch = 4, fd_only = true})
for _ = 1, 30 do c = P.update(s, i, DT) end
T.near(c, 4, 1e-6, "V/S +1,000 flown: the F/D's command on the attitude")
-- 500 fpm short: over the attitude, by FD_S of the law's rate
i.vs = 500
for _ = 1, 30 do c = P.update(s, i, DT) end
T.check(c > 4.1 and c <= 4 + P.FD_S * rate_at(250, P.G_LIMIT) + 1e-6, ("500 fpm short: the command over the attitude (%.3f)"):format(c))
-- the A/P engaged there (the glue's sync): from the attitude, at the law's rate
P.sync(s)
i.fd_only = false
c = P.update(s, i, DT)
T.check(c > 4 and c - 4 <= rate_at(250, P.G_LIMIT) * DT + 1e-9, ("the A/P engaged: from the attitude at the law's rate (%.4f)"):format(c))

-- the rotation from VR (150 kt; V2 160 in the window: the target 170 kt)
-- on to 15 degrees at 2.5 degrees a second (FCTM p.95), the lift-off at 5
-- degrees (the AFDS's first frame in the air: s109's at 4 to 10), the
-- thrust's excess 4.5 kt/s in level flight (the speed over the target from
-- the lift-off's third second: s109's 172 to 184 kt): the F/D's command from 2 s after the
-- lift-off on (FCTM p.95: not used for the rotation) no more than half a
-- degree under the attitude, over it as the law asks for more pitch; before
-- (the integrator from the lift-off's attitude) 2 to 3 under here, 4 to 6
-- in s109
local function liftoff(fd_only)
    local st = P.new()
    local x = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 0, vs = 0, alt = 0, tas = 153, fd_only = fd_only})
    local gam, t, lo, hi, air = 0, 0, 99, -99, nil
    for _ = 1, math.floor(12 / DT + 0.5) do
        local cmd = P.update(st, x, DT)
        if air and t - air >= 2 - 1e-9 then lo, hi = math.min(lo, cmd - x.pitch), math.max(hi, cmd - x.pitch) end
        x.pitch = math.min(15, x.pitch + 2.5 * DT)
        if x.ground and x.pitch >= 5 then x.ground, air = false, t end
        if not x.ground then gam = math.max(0, gam + ((x.pitch - 5) - gam) * DT / 3) end
        x.ias = x.ias + (4.5 - G * math.sin(math.rad(gam)) / KT) * DT
        x.tas = x.ias * 1.02
        x.vs = x.tas * KT * math.sin(math.rad(gam)) / FT * 60
        x.alt = x.alt + x.vs / 60 * DT
        t = t + DT
    end
    return lo, hi, x, st
end
local lo1, hi1, x1, s1 = liftoff(true)
T.check(s1.target > 170 and s1.target < 185, ("  (the target from V2 + 10 on to the speed then: %.1f, the speed %.1f)"):format(s1.target, x1.ias))
T.check(lo1 > -0.5, ("the lift-off and the rotation to 15 degrees, the F/Ds alone: the command %+.2f to %+.2f from the attitude"):format(lo1, hi1))
T.check(hi1 > 0.5, "  over it as the law asks for more pitch (the speed over the target)")
local lo0 = liftoff(false)
T.check(lo0 < -2, ("  before (the integrator from the lift-off's attitude): %.2f under"):format(-lo0))

-- a pilot holding the bar on the airplane symbol: the attitude 2 s behind
-- the F/D's command, the path 3 s behind the attitude less the angle of
-- attack, the speed's rate the thrust's excess less the climb's (as
-- afds_pitch_model_test.lua's lagged airplane for the A/P)
local function fly_pilot(st, x, seconds, thrust, alpha, cb)
    alpha = alpha or 2
    local gam = x.gam or (x.pitch - alpha)
    local t, g, last = 0, 0, x.vs
    local r = {vmin = x.ias, vmax = x.ias, pmax = x.pitch}
    for _ = 1, math.floor(seconds / DT + 0.5) do
        local cmd = P.update(st, x, DT)
        if cmd then x.pitch = x.pitch + (cmd - x.pitch) * DT / 2 end
        gam = gam + ((x.pitch - alpha) - gam) * DT / 3
        if thrust then
            x.ias = x.ias + (thrust(t) - G * math.sin(math.rad(gam)) / KT) * DT
            x.tas = x.ias * (x.tas_ratio or 1.16)
        end
        x.vs = x.tas * KT * math.sin(math.rad(gam)) / FT * 60
        x.alt = x.alt + x.vs / 60 * DT
        g = math.max(g, math.abs(x.vs - last) / 60 / DT / G_FT)
        last = x.vs
        r.vmin, r.vmax, r.pmax = math.min(r.vmin, x.ias), math.max(r.vmax, x.ias), math.max(r.pmax, x.pitch)
        t = t + DT
        if cb then cb(t, x, cmd) end
    end
    x.gam, r.g = gam, g
    return r
end
-- a takeoff flown so (the A/P's: afds_pitch_model_test.lua): lift-off at
-- 165 kt and 9 degrees, the thrust's excess 2.4 kt/s
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150, fd_only = true})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.gam, i.tas_ratio = false, 165, 9, 1, 1.02
local r = fly_pilot(s, i, 60, function() return 2.4 end, 7)
T.check(r.vmax < 178, ("a takeoff on the F/D: within V2 + 18 (%.1f)"):format(r.vmax))
T.check(math.abs(i.ias - s.target) < 1.5, ("  on the target after a minute (%.1f, %.1f)"):format(i.ias, s.target))
T.check(r.pmax < 20, ("  the pitch under 20 degrees (%.1f)"):format(r.pmax))
-- a level-off: V/S 2,000 fpm to 10,000 ft, the capture by `capture`
s = P.new()
i = inp({mode = "VS", vs_sel = 2000, alt = 8000, vs = 2000, fd_only = true})
i.pitch = 2 + math.deg(math.asin(2000 / 60 * FT / (250 * KT)))
local top = i.alt
r = fly_pilot(s, i, 150, nil, 2, function(_, x)
    if x.mode == "VS" and P.capture(x, 10000) then x.mode, x.hold_alt = "ALT", 10000 end
    top = math.max(top, x.alt)
end)
T.check(top < 10030, ("a level-off on the F/D: no overshoot over 30 ft (%.0f)"):format(top))
T.near(i.alt, 10000, 10, "  level at 10,000 ft")
T.check(r.g <= P.G_LIMIT * 1.1, ("  within the 0.05 g (%.3f)"):format(r.g))

-- a heavy takeoff flown by hand, held at 15 degrees to the acceleration
-- height, the bar flown from there (the column 0.5 a degree of the bar's
-- error, the pitch rate behind it over 1 s: a pilot), the path 3 s behind
-- the attitude less 5 degrees; with fd_only false the integrator's command
-- is the bar (the F/D before 2026-11-26)
local function heavy(fd_only, excess)
    local st = P.new()
    local x = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 0, vs = 0, alt = 0, tas = 153, fd_only = fd_only})
    local gam, q, follow, accel, lo, under = 0, 0, false, false, 1e9, 0
    local dt = 0.05
    for _ = 1, math.floor(120 / dt) do
        local bar = P.update(st, x, dt)
        if follow and bar then
            q = q + (0.5 * (bar - x.pitch) - q) * dt
            x.pitch = x.pitch + q * dt
        else
            x.pitch = math.min(15, x.pitch + 2.5 * dt)
        end
        if x.ground and x.pitch >= 5 then x.ground = false end
        if not x.ground then gam = gam + ((x.pitch - 5) - gam) * dt / 3 end
        x.ias = x.ias + (excess - G * math.sin(math.rad(gam)) / KT) * dt
        x.tas = x.ias * 1.02
        x.vs = x.tas * KT * math.sin(math.rad(gam)) / FT * 60
        x.alt = math.max(0, x.alt + x.vs / 60 * dt)
        if x.mode == "TO" and not x.ground and x.alt >= 400 then
            x.mode, x.vnav_law, x.way, x.spd_sel = "VNAV", "FLCH", 1, math.floor(x.ias + 0.5)
        end
        if not accel and x.alt >= 1000 then
            accel, follow, x.spd_sel = true, true, 225
            under = bar - x.pitch
        end
        if accel then lo = math.min(lo, x.vs) end
    end
    return lo, under, x
end
local h1, u1, hx = heavy(true, 2.8)
local h0, u0 = heavy(false, 2.8)
T.check(h1 > 1000 and hx.ias > 220, ("a heavy takeoff (2.8 kt/s) held at 15 degrees to the acceleration height, the F/D flown from there: climbing all the way (%.0f fpm at the least, %.1f kt after 2 minutes)"):format(h1, hx.ias))
T.check(u1 > -1.5, ("  the bar there %.2f from the attitude (the law asking for less pitch: the speed under the target)"):format(u1))
T.check(h0 < -1000 and u0 < -12, ("  before: the command %.1f under the airplane there, down at %.0f fpm"):format(-u0, -h0))
local g1, g0 = heavy(true, 2.4), heavy(false, 2.4)
T.check(g1 > 500 and g0 < -3000, ("  2.4 kt/s: %.0f fpm at the least (before %.0f)"):format(g1, g0))

-- T/O: not over the PLI (FCOM p.664)
s = P.new()
i = inp({mode = "TO", ground = true, mcp_ias = 160, ias = 150, pitch = 3, vs = 0, alt = 0, tas = 150, fd_only = true})
P.update(s, i, DT)
i.ground, i.ias, i.pitch, i.pli = false, 200, 10, 0.5
for _ = 1, 20 do c = P.update(s, i, DT) end
T.check(c <= 10.5 + 1e-9, ("T/O, 30 kt over the target: not over the PLI (%.2f)"):format(c))
-- FLARE: as with the A/Ps (its LAND 2 and 3: FCOM p.671)
local function flare(fd_only)
    local st = P.new()
    local x = inp({mode = "FLARE", pitch = 2.5, vs = -700, tas = 145, ias = 145, gear_alt = 50, alt = 50, fd_only = fd_only})
    local out = {}
    for n = 1, 30 do
        out[n] = P.update(st, x, DT)
        x.gear_alt = x.gear_alt + x.vs / 60 * DT
    end
    return out
end
local fa, fb = flare(true), flare(false)
local same = true
for n = 1, 30 do if fa[n] ~= fb[n] then same = false end end
T.check(same, "FLARE: the same command with the F/Ds alone as with the A/Ps")

T.done()
