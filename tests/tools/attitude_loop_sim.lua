-- Run from the repository root with LuaJIT: luajit tests/tools/attitude_loop_sim.lua
-- The A/P's pitch attitude loop (B747.19.xt.afds_control.lua: its PID, the
-- elevator command's slew, the autotrim) under the altitude law
-- (B747.70.afds_pitch_model.lua) on a model of X-Plane's 747 at FL350 and
-- 288 KIAS (6-3, after step 3b: docs/overhaul/notes/ATA-22.md §20). The
-- model was fitted with tests/tools/pitch_sysid.lua to a recording of ALT
-- HOLD at FL350 (the custom acf): pitch acceleration and alpha rate on the
-- pitch rate, alpha, the elevator ratio (0.2 s later) and the trim ratio.
-- It reproduced X-Plane's swing (1.3 degrees, 740 fpm, 0.16 g every 17 s)
-- with the old autotrim, and showed it gone without the autotrim or with
-- the stabilizer given back by the integrator (ATA22 p.333).
--   cfg: kp, ki (the PID), kd (its derivative), kq (pitch rate), ff (the
--   elevator ratio given back per trim ratio), trim_on/trim_off (the
--   autotrim's band, elevator ratio), trim_delay, no_trim, offset (the
--   altitude held above the start), air (another model)
local P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")
local DT = 1 / 60
-- qdot = qq q + qa alpha + qe de(0.2 s before) + qt trim + q0 (deg/s/s)
-- alphadot = aq q + aa alpha + a0; v the TAS (m/s); the autotrim's rate
-- (trim ratio a second: 0.1 unit/s, B747.45.srm_model.lua)
local AIR = {qq = -0.142, qa = -1.458, qe = 10.15, qt = 17.2, q0 = 6.97,
             aq = 1.006, aa = -0.486, a0 = 0.746, lag = 0.2, v = 247, trim_rate = 0.0127}

local function run(cfg, seconds, verbose)
    local a = cfg.air or AIR
    -- the trim point
    local alpha0 = -a.a0 / a.aa
    local trim = cfg.trim0 or -0.26
    local de0 = (-(a.qa * alpha0) - a.q0 - a.qt * trim) / a.qe
    local st = {th = alpha0, q = 0, al = alpha0, de_srv = de0, trim = trim, alt = 35000}
    local de_hist = {}
    local I = de0
    local laste = 0
    local s = P.new()
    local inp = P.inputs()
    inp.active, inp.mode, inp.hold_alt, inp.tas, inp.ias = true, "ALT", 35000 + (cfg.offset or 100), a.v / 0.5144, 288
    local trim_cmd, trim_since, trim_on = 0, 0, false
    local lo, hi, glo, ghi, plo, phi = 1e9, -1e9, 9, -9, 99, -99
    local t, acc = 0, 0
    for n = 1, math.floor(seconds / DT) do
        t = n * DT
        -- the outer loop
        local gam = st.th - st.al
        local vs = a.v * math.sin(math.rad(gam)) / 0.3048 * 60
        inp.pitch, inp.vs, inp.alt = st.th, vs, st.alt
        local cmd = P.update(s, inp, DT)
        -- the inner loop at 30 Hz: the PID, the trim given back, the slew
        acc = acc + DT
        if acc >= 1 / 30 then
            local dt = acc; acc = 0
            local e = cmd - st.th
            I = math.max(-1, math.min(1, I + cfg.ki * e * dt - (cfg.ff or 0) * (st.trim - (st.trim_last or st.trim))))
            st.trim_last = st.trim
            local out = cfg.kp * e + I + (cfg.kd or 0.0002) * (e - laste) / dt - (cfg.kq or 0) * st.q
            laste = e
            out = math.max(-1, math.min(1, out))
            local spd = math.max(3, math.min(10, 3 + (math.abs(e) - 1) * 7 / 9))
            local step = 2 / spd * dt
            if math.abs(out - st.de_srv) <= step then st.de_srv = out else st.de_srv = st.de_srv + (out > st.de_srv and step or -step) end
            -- the autotrim: on out of the band, off within its inner edge
            local on, off = cfg.trim_on or 0.005, cfg.trim_off or cfg.trim_on or 0.005
            local want = 0
            local edge = trim_on and off or on
            if math.abs(st.de_srv) > edge then want = st.de_srv > 0 and 1 or -1 end
            trim_on = want ~= 0
            if want ~= trim_cmd then trim_cmd, trim_since = want, t end
        end
        if trim_cmd ~= 0 and t - trim_since >= (cfg.trim_delay or 3.5) and not cfg.no_trim then
            st.trim = st.trim + trim_cmd * a.trim_rate * DT
        end
        -- the elevator surface's lag
        de_hist[#de_hist + 1] = st.de_srv
        local de_s = de_hist[math.max(1, #de_hist - math.floor(a.lag / DT))]
        -- the airplane
        local qd = a.qq * st.q + a.qa * st.al + a.qe * de_s + a.qt * st.trim + a.q0
        local ad = a.aq * st.q + a.aa * st.al + a.a0
        st.q = st.q + qd * DT
        st.al = st.al + ad * DT
        st.th = st.th + st.q * DT
        st.alt = st.alt + vs / 60 * DT
        local g = 1 + (a.v * math.rad((st.q - ad)) / 9.80665)
        if t > seconds - 60 then
            lo, hi = math.min(lo, vs), math.max(hi, vs)
            glo, ghi = math.min(glo, g), math.max(ghi, g)
            plo, phi = math.min(plo, st.th), math.max(phi, st.th)
        end
        if verbose and n % math.floor(1 / DT) == 0 and t > seconds - 40 then
            print(("  t %5.1f vs %6.0f pitch %5.2f cmd %5.2f de %6.3f trim %7.4f"):format(t, vs, st.th, cmd, st.de_srv, st.trim))
        end
    end
    return ("last 60 s: vs %5.0f..%5.0f  g %.3f..%.3f  pitch %.2f..%.2f  alt err %.0f"):format(lo, hi, glo, ghi, plo, phi, st.alt - inp.hold_alt)
end

-- the autotrim's band of ATA22 p.149 in the elevator's ratio (22 degrees up)
local ON, OFF = 0.4 / 22, 0.25 / 22
local cases = {
    {"the old PID and autotrim", {kp = 0.044, ki = 0.044}},
    {"no autotrim", {kp = 0.044, ki = 0.044, no_trim = true}},
    {"the band 0.4/0.25", {kp = 0.044, ki = 0.044, trim_on = ON, trim_off = OFF}},
    {"pitch rate 0.04", {kp = 0.044, ki = 0.044, kq = 0.04}},
    {"a third of ki", {kp = 0.044, ki = 0.0147}},
    {"given back 1.2, the band", {kp = 0.044, ki = 0.044, ff = 1.2, trim_on = ON, trim_off = OFF}},
    {"given back 1.9, the band", {kp = 0.044, ki = 0.044, ff = 1.9, trim_on = ON, trim_off = OFF}},
    {"given back 2.2, the band", {kp = 0.044, ki = 0.044, ff = 2.2, trim_on = ON, trim_off = OFF}},
    {"given back 1.9, 300 ft off", {kp = 0.044, ki = 0.044, ff = 1.9, trim_on = ON, trim_off = OFF, offset = 300}},
}
for _, c in ipairs(cases) do print(("%-30s %s"):format(c[1], run(c[2], 300))) end
