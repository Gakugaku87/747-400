-- Run from the repository root with LuaJIT: luajit tests/autopilot/flch_entry_test.lua
-- FLCH's climb entry (2026-11-07; docs/overhaul/notes/ATA-34-61-FMC.md
-- §152): the A/T's THR (B747.70.at_model.lua) and the pitch laws' speed law
-- (B747.70.afds_pitch_model.lua) closed on a lagged airplane, as s108's
-- 2026-11-07 run (270 t, 10,000 ft, 250 kt, FLCH 5,000 ft up): the
-- engines' thrust 222 kN a unit of lever (33 kN at 0.52, 122 at 0.92 in
-- the record), 3 s behind the levers; the attitude 2 s behind the command,
-- the path 3 s behind the attitude; the speed on the thrust's excess over
-- the level's less the climb's. With THR on the inertial V/S alone the
-- levers went on until the V/S, lagging the pitch-up, reached the 125 s
-- rate: 122 kN, and the speed +12 kt in X-Plane (+21 here). On the
-- energy's rate at the target speed (the elevator turns the excess speed
-- into climb) the thrust stops where the rate will be met: within +10 kt
-- here, the thrust under 100 kN, the V/S settling on the 125 s rate.
-- A speed selected higher (250 to 340 kt): the thrust to the limit as
-- before (the acceleration is wanted: the energy's rate does not count
-- under the target); a descent entry: the levers to the aft stop as before.
local T = dofile("tests/lib/check.lua")("flch_entry")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")
local KT, G, FT = 1852 / 3600, 9.80665, 0.3048
local DT = 0.05

-- the loop: opt.vs0 the V/S at the push, opt.target the speed selected,
-- opt.mcp the MCP altitude, opt.seconds; r.vmax/vmin the speed's extremes,
-- r.tmax the thrust's (a engine, N), r.vs_end, r.thr_end, r.ias_end, r.g
local function run(opt)
    local W = 270000
    local T_PER_LEVER, T0, LEVER0 = 222e3, 33e3, 0.52
    local tau_e, tau_t, tau_g = 3, 2, 3
    local alt0, mcp = 10100, opt.mcp or 15000
    local ias, tas_ratio = 250, 1.16
    local vs, alt = opt.vs0 or 0, alt0
    local gam = math.deg(math.asin(vs / 60 * FT / (ias * tas_ratio * KT)))
    local alpha = 4.4
    local pitch = alpha + gam
    local lever, thrust = LEVER0, T0 * 4
    local target = opt.target or 250
    local ps, pi = P.new(), P.inputs()
    pi.active, pi.mode, pi.spd_sel, pi.mcp_ias = true, "FLCH", target, target
    local as = A.new()
    A.update(as, {arm = true, ok = true, ground = false, cas = ias, ra = 10000, flaps_up = true, pitch = "FLCH", reverse = false})
    -- the EEC's EPR with the lever, its reference 1.5 (the limit the
    -- levers stop at: 0.83 of travel)
    local ai = {dt = DT, n1 = false, thrust_ref = 1.5, v_max = 365, v_min = 220, flaps_up = true, target = target}
    local last_ias, accel = ias, 0
    local r = {vmax = ias, vmin = ias, vsmax = 0, tmax = thrust, g = 0}
    local last_vs = vs
    for n = 1, math.floor((opt.seconds or 90) / DT + 0.5) do
        accel = accel + ((ias - last_ias) / DT - accel) * math.min(1, DT / 0.5)
        last_ias = ias
        ai.ias, ai.accel, ai.vs, ai.ivs, ai.alt, ai.mcp_alt, ai.lever = ias, accel, vs, vs, alt, mcp, lever
        ai.thrust = 1.0 + lever * 0.6
        ai.evs = A.target_vs(as, vs, ias * tas_ratio * KT, ias, false, DT)
        A.servo(as, ai)
        lever = as.cmd
        -- the thrust with the lever, not under idle (8 kN an engine)
        local want_t = math.max(T0 + (lever - LEVER0) * T_PER_LEVER, 8e3) * 4
        thrust = thrust + (want_t - thrust) * DT / tau_e
        pi.ias, pi.tas, pi.alt, pi.pitch, pi.vs = ias, ias * tas_ratio, alt, pitch, vs
        local cmd = P.update(ps, pi, DT)
        if cmd then pitch = pitch + (cmd - pitch) * DT / tau_t end
        gam = gam + ((pitch - alpha) - gam) * DT / tau_g
        local ax = (thrust - T0 * 4) / W - G * math.sin(math.rad(gam))
        ias = ias + ax / KT * DT
        vs = ias * tas_ratio * KT * math.sin(math.rad(gam)) / FT * 60
        alt = alt + vs / 60 * DT
        r.vmax, r.vmin = math.max(r.vmax, ias), math.min(r.vmin, ias)
        r.vsmax, r.tmax = math.max(r.vsmax, vs), math.max(r.tmax, thrust)
        r.g = math.max(r.g, math.abs(vs - last_vs) / 60 / DT / (G / FT))
        last_vs = vs
    end
    r.ias_end, r.vs_end, r.thr_end, r.lever_end, r.fma = ias, vs, thrust / 4, lever, A.fma(as)
    return r
end

-- the climb entry from level and from s108's -192 fpm
local want = 5000 / 125 * 60
for _, vs0 in ipairs({0, -192}) do
    local r = run({vs0 = vs0})
    T.check(r.vmax < 260, string.format("FLCH 5,000 ft up from %d fpm: the speed within +10 kt (%.1f; on the V/S alone: 266 to 267)", vs0, r.vmax))
    T.check(r.vmin > 246, string.format("  and not under -4 kt (%.1f)", r.vmin))
    T.check(r.tmax / 4 < 100e3, string.format("  the thrust under 100 kN an engine (%.0f; on the V/S alone: 103, the limit)", r.tmax / 4000))
    T.near(r.vs_end, want, 400, string.format("  the V/S settling on the 125 s rate (%.0f for %.0f; on the V/S alone: 3,080)", r.vs_end, want))
    T.check(r.g <= P.SPD_G * 1.1, string.format("  within SPD_G (%.2f)", r.g))
    T.near(r.ias_end, 250, 2, string.format("  on the speed at 90 s (%.1f)", r.ias_end))
end
-- 340 kt selected at the push (the climb 250/340: PERF's phase 2): the
-- thrust to the limit, the speed up without an overshoot
local r = run({target = 340, mcp = 35000, seconds = 150})
T.check(r.lever_end > 0.8, string.format("250 to 340 kt: the levers at the limit (%.2f)", r.lever_end))
T.check(r.vmax < 343, string.format("  no overshoot over 3 kt (%.1f)", r.vmax))
T.near(r.ias_end, 340, 2, string.format("  at 340 kt (%.1f)", r.ias_end))
T.check(r.vs_end > 500, string.format("  still climbing (%.0f fpm)", r.vs_end))
-- a descent entry: the levers back to the aft stop, HOLD, the speed held
r = run({mcp = 5000, seconds = 60})
T.equal(r.fma, A.HOLD, "FLCH 5,000 ft down: HOLD at the aft stop")
T.check(r.vmin > 244 and r.vmax < 253, string.format("  the speed within -6/+3 kt (%.1f..%.1f)", r.vmin, r.vmax))
T.check(r.vs_end < -800, string.format("  descending (%.0f fpm; the model's idle gives about -1,100)", r.vs_end))
T.done()
