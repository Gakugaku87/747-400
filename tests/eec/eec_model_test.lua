-- Run from the repository root with LuaJIT: luajit tests/eec/eec_model_test.lua
-- The EEC model (plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua)
-- against the FCOM PI tables (PW4056 p.262-263, CF6-80C2B1F p.359-360) and
-- the CF6 thrust management (ATA70_80 p.146-151, p.208-209): the maximum
-- rated thrust, its bleed adjustments, the full-forward rating by altitude
-- and speed, and the lever command between idle and the maximum.
local T = dofile("tests/lib/check.lua")("eec_model")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")

local PW, GE = E.TABLE.PW, E.TABLE.GE
local DT = 0.1
local s = E.new()

-- table values at their grid points (read off the FCOM pages)
T.near(E.lookup(PW.clb, 0, 30000), 1.57, 1e-9, "PW max climb EPR, TAT 0, 30,000 ft")
T.near(E.lookup(PW.clb, 20, 35000), 1.39, 1e-9, "PW max climb EPR, TAT 20, 35,000 ft")
T.near(E.lookup(PW.clb, -20, 45000), 1.58, 1e-9, "PW max climb EPR, TAT -20, 45,000 ft")
T.near(E.lookup(PW.ga, 15, 0), 1.51, 1e-9, "PW go-around EPR, TAT 15, sea level")
T.near(E.lookup(PW.ga, 10, 10000), 1.67, 1e-9, "PW go-around EPR, TAT 10, 10,000 ft")
T.near(E.lookup(PW.ga, 45, -2000), 1.46, 1e-9, "PW go-around EPR, TAT 45, -2,000 ft")
T.near(E.lookup(GE.clb, -10, 35000), 105.6, 1e-9, "GE max climb N1, TAT -10, 35,000 ft")
T.near(E.lookup(GE.clb, 25, 0), 98.2, 1e-9, "GE max climb N1, TAT 25, sea level (the old table had 98.8)")
T.near(E.lookup(GE.clb, -40, 20000), 95.2, 1e-9, "GE max climb N1, TAT -40, 20,000 ft (the old table had 95.5)")
T.near(E.lookup(GE.ga, 15, 0), 103.8, 1e-9, "GE go-around N1, TAT 15, sea level")
T.near(E.lookup(GE.ga, 57, 10000), 103.8, 1e-9, "GE go-around N1, TAT 57, 10,000 ft")

-- between grid points, and where the table is blank (too warm for the altitude)
T.near(E.lookup(PW.clb, 5, 30000), 1.545, 1e-9, "PW max climb EPR between TAT 0 and 10")
T.near(E.lookup(PW.clb, 0, 32500), 1.575, 1e-9, "PW max climb EPR between 30,000 and 35,000 ft")
T.near(E.lookup(PW.clb, 30, 35000), 1.39, 1e-9, "PW max climb EPR held at the warmest row of a column")
T.near(E.lookup(PW.clb, -40, 0), 1.25, 1e-9, "PW max climb EPR held below -20")
T.near(E.lookup(PW.ga, 54, 10000), 1.44, 1e-9, "PW go-around EPR held where TAT 54 and 50 are blank")
T.near(E.lookup(GE.ga, 20, 20000), 109.8, 1e-9, "GE go-around N1 held above 10,000 ft")

-- the full-forward rating by altitude and speed (ATA70_80 p.208)
local share, tla = E.rating_mix(0, 150)
T.equal(share, 1, "takeoff rating at sea level, 150 kt")
T.equal(tla, 48, "takeoff rating reached at 48° TLA")
share = E.rating_mix(17500, 250)
T.near(share, 0.5, 1e-9, "half way to maximum continuous at 17,500 ft")
share = E.rating_mix(10000, 296.5)
T.near(share, 0.5, 1e-9, "half way to maximum continuous at 296.5 kt")
share, tla = E.rating_mix(20000, 280)
T.equal(share, 0, "no takeoff rating at 20,000 ft")
T.equal(tla, 48, "maximum continuous: reached at 48° below 22,000 ft")
share, tla = E.rating_mix(23500, 300)
T.near(tla, 41.5, 1e-9, "the lever angle for the rating moves from 48° to 35° between 22,000 and 25,000 ft")
share, tla = E.rating_mix(30000, 280)
T.equal(tla, 35, "climb rating reached at 35° above 25,000 ft")

-- P&W at sea level, 15 °C: full forward gives the takeoff (go-around) EPR
local inp = E.inputs()
inp.type, inp.alt, inp.tat, inp.kias = "PW", 0, 15, 0
inp.idle = {1.0, 1.0, 1.0, 1.0}
inp.lever = {1.0, 0.96, 0.48, 0}
local out = E.update(s, inp, DT)
for n = 1, 4 do T.near(out.max[n], 1.51, 1e-9, "PW max EPR at sea level, engine " .. n) end
T.near(out.command[1], 1.51, 1e-9, "full forward commands the max EPR")
T.near(out.command[2], 1.51, 1e-9, "48° TLA commands the max EPR")
T.near(out.command[3], 1.255, 1e-9, "24° TLA commands half way from idle")
T.near(out.command[4], 1.0, 1e-9, "idle lever commands idle")

-- bleed: three packs off adds 0.02 to the go-around EPR; engine anti-ice on one
-- engine changes only that engine's climb EPR
inp.packs_on = 0
out = E.update(s, inp, DT)
T.near(out.max[1], 1.53, 1e-9, "PW max EPR with 3 packs off")
inp.packs_on = 3
inp.alt, inp.tat, inp.kias = 30000, -20, 280
inp.nai = {true, false, false, false}
inp.lever = {0.7, 0.7, 0.35, 1.0}
out = E.update(s, inp, DT)
T.near(out.max[2], 1.57, 1e-9, "PW max climb EPR at 30,000 ft, TAT -20")
T.near(out.max[1], 1.53, 1e-9, "engine anti-ice on engine 1: -0.04 at 30,000 ft")
T.near(out.command[2], 1.57, 1e-9, "35° TLA reaches the climb rating above 25,000 ft")
T.near(out.command[4], 1.57, 1e-9, "full forward gives the climb rating above 25,000 ft")
T.near(out.command[3], 1.285, 1e-9, "17.5° TLA commands half way from idle")
inp.wai = true
out = E.update(s, inp, DT)
T.near(out.max[1], 1.50, 1e-9, "engine and wing anti-ice: -0.07 at 30,000 ft")
T.near(out.max[2], 1.57, 1e-9, "wing anti-ice alone does not change an engine without engine anti-ice")
inp.wai, inp.nai = false, {false, false, false, false}

-- a type the model does not know runs on the P&W data (the glue keeps RR,
-- which has no source, on its previous thrust logic)
inp.type = "RR"
out = E.update(s, inp, DT)
T.near(out.max[1], 1.57, 1e-9, "an unknown type falls back to the P&W tables")

-- GE at sea level, 15 °C, then climbing through the blend to the climb rating
inp.type, inp.alt, inp.tat, inp.kias = "GE", 0, 15, 150
inp.idle = {25, 25, 25, 25}
inp.lever = {1, 1, 1, 1}
inp.nai = {false, true, false, false}
out = E.update(s, inp, DT)
T.near(out.max[1], 103.8, 1e-9, "GE max N1 at sea level, TAT 15")
T.near(out.max[2], 103.3, 1e-9, "GE engine anti-ice: -0.5 at sea level")
inp.nai = {false, false, false, false}
inp.alt, inp.tat, inp.kias = 17500, -5, 290
out = E.update(s, inp, DT)
local ga = E.lookup(GE.ga, -5, 10000)
local clb = E.lookup(GE.clb, -5, 17500)
T.near(out.max[1], 0.5 * ga + 0.5 * clb, 1e-9, "GE half way between the takeoff and the climb rating at 17,500 ft")
inp.alt = 26000
out = E.update(s, inp, DT)
T.near(out.max[1], E.lookup(GE.clb, -5, 26000), 1e-9, "GE climb rating at 26,000 ft")
inp.lever = {0, 0, 0, 0}
inp.idle = {120, 120, 120, 120}
out = E.update(s, inp, DT)
T.near(out.command[1], out.max[1], 1e-9, "an idle above the maximum is held at the maximum")

-- idle selection (FCOM p.877-878, ATA70_80 p.210-211): approach idle in the
-- air with nacelle anti-ice, landing flaps or (405, 570) CON; held 5 s after
-- the conditions end and after touchdown; the CF6 also during reverser
-- operation
local function run(st, i, seconds)
    local o
    for _ = 1, math.floor(seconds / DT + 0.5) do o = E.update(st, i, DT) end
    return o
end
local function all(t, v)
    for n = 1, 4 do if t[n] ~= v then return false end end
    return true
end
do
    local st, i = E.new(), E.inputs()
    i.type, i.idle = "PW", {0.95, 0.95, 0.95, 0.95}
    i.nai, i.flaps_deg = {true, false, false, false}, 30
    local o = run(st, i, 1)
    T.check(all(o.approach, false), "idle: minimum idle on the ground, even with anti-ice and landing flaps")
    i.air, i.nai = true, {false, false, false, false}
    o = run(st, i, 0.1)
    T.check(all(o.approach, true), "idle: approach idle in the air with landing flaps")
    i.flaps_deg = 20
    o = run(st, i, 4.8)
    T.check(all(o.approach, true), "idle: approach idle kept for 5 s after the flaps leave the landing position")
    o = run(st, i, 0.3)
    T.check(all(o.approach, false), "idle: then minimum idle")
    i.nai = {false, true, false, false}
    o = run(st, i, 0.1)
    T.check(o.approach[2] and not o.approach[1] and not o.approach[3], "idle: nacelle anti-ice selects approach idle for its own engine")
    i.nai = {false, false, false, false}
    run(st, i, 6)
    i.con = true
    o = run(st, i, 0.1)
    T.check(all(o.approach, false), "idle: CON does not select approach idle on the 109 (P&W passenger)")
    i.freighter = true
    o = run(st, i, 0.1)
    T.check(all(o.approach, true), "idle: CON selects approach idle on the 405 (P&W freighter)")
    i.con, i.freighter = false, false
    i.flaps_deg = 30
    run(st, i, 1)
    i.air = false                            -- touchdown
    o = run(st, i, 4.8)
    T.check(all(o.approach, true), "idle: approach idle kept until 5 s after touchdown")
    o = run(st, i, 0.3)
    T.check(all(o.approach, false), "idle: minimum idle 5 s after touchdown")
    T.check(all(o.low_idle, false) and not o.idle_disagree, "idle: no idle messages without idle faults")
    -- the messages, with the engines' idle given: one stays at minimum while
    -- approach is selected, one stays at approach while minimum is selected
    i.air = true
    o = run(st, i, 0.1)
    i.at_approach = {false, true, true, true}
    o = run(st, i, 0.1)
    T.check(o.low_idle[1] and not o.low_idle[2], "ENG 1 LOW IDLE: approach idle selected, not reached")
    T.check(not o.idle_disagree, "no >IDLE DISAGREE while every engine reached what is selected or less")
    i.air, i.flaps_deg = false, 0
    run(st, i, 6)
    i.at_approach = {false, false, true, false}
    o = run(st, i, 0.1)
    T.check(o.idle_disagree, ">IDLE DISAGREE: an engine at approach idle with minimum idle selected")
    T.check(all(o.low_idle, false), "no LOW IDLE with minimum idle selected")
    -- the CF6 selects approach idle during reverser operation, also on the ground
    i.at_approach = nil
    i.type, i.idle = "GE", {25, 25, 25, 25}
    i.reverser = {true, false, false, false}
    o = run(st, i, 0.1)
    T.check(o.approach[1] and not o.approach[2], "idle: GE reverser operation selects approach idle")
    i.type = "PW"
    run(st, i, 6)
    o = run(st, i, 0.1)
    T.check(all(o.approach, false), "idle: the P&W reverser does not")
end

-- alternate mode (FCOM p.876-877, p.900; ATA70_80 p.205-207): the corner
-- point schedule without bleed adjustments, no limit at the maximum, LIM
-- PROT, and the A/T rules
T.near(E.lookup_max(PW.ga, 0), 1.51, 1e-9, "PW go-around EPR's corner point at sea level")
T.near(E.lookup_max(PW.clb, 30000), 1.57, 1e-9, "PW climb EPR's corner point at 30,000 ft")
T.near(E.lookup_max(GE.ga, 0), 107.3, 1e-9, "GE go-around N1's corner point at sea level (TAT 35)")
do
    local st, i = E.new(), E.inputs()
    i.type, i.alt, i.tat, i.kias = "GE", 0, -10, 150
    i.idle = {25, 25, 25, 25}
    i.lever = {1, 1, 0.96 * 0.5, 0}
    local o = E.update(st, i, DT)
    local max = E.lookup(GE.ga, -10, 0)
    T.near(o.max[1], max, 1e-9, "GE normal mode: max N1 at TAT -10")
    T.near(o.command[1], max, 1e-9, "GE normal mode: full forward is the max N1")
    T.check(not o.at_disconnect and not o.at_inhibit, "normal mode: no A/T disconnect")
    i.altn = {true, false, false, false}
    o = E.update(st, i, DT)
    T.check(o.altn[1] and not o.altn[2], "ALTN: engine 1 in the alternate mode")
    T.near(o.command[1], 107.3, 1e-9, "ALTN: full forward gives the corner point N1, above the max (overboost)")
    T.near(o.max[1], max, 1e-9, "ALTN: the max N1 is still worked out")
    T.check(o.lim_prot[1] and not o.lim_prot[2], ">ENG 1 LIM PROT: GE command above the max N1")
    T.check(o.at_disconnect, "ALTN: the A/T disconnects when an EEC goes to the alternate mode")
    T.check(o.at_inhibit, "ALTN: GE with some EECs in the alternate mode: no A/T")
    o = E.update(st, i, DT)
    T.check(not o.at_disconnect, "ALTN: the disconnect is the change only")
    i.lever[1] = 0.96 * 0.5
    o = E.update(st, i, DT)
    T.check(o.command[1] > o.command[3], "ALTN: the same lever gives more than the normal mode")
    T.check(not o.lim_prot[1], "no LIM PROT below the max")
    i.altn = {true, true, true, true}
    o = E.update(st, i, DT)
    T.check(not o.at_inhibit, "ALTN: GE with all four EECs in the alternate mode can use the A/T again")
    -- P&W: LIM PROT near the max, A/T only with all four in the normal mode
    i.type, i.tat = "PW", 15
    i.idle = {0.95, 0.95, 0.95, 0.95}
    i.lever = {1, 1, 1, 1}
    o = E.update(st, i, DT)
    T.check(o.at_inhibit, "ALTN: P&W with any EEC in the alternate mode: no A/T")
    T.check(o.lim_prot[1], ">ENG 1 LIM PROT: P&W command near the max EPR (corner day: at the max)")
    i.altn = {false, false, false, false}
    o = E.update(st, i, DT)
    T.check(not o.at_inhibit and not o.lim_prot[1], "P&W: back in the normal mode")
end

-- overspeed protection (FCOM p.878, p.901; ATA70_80 p.205): the target is the
-- command until a rotor comes within the band of its red line less the
-- margin; then each limit loop allows the present value plus the gain for
-- each percent short (less when past), so the rotor settles at the red line
-- less the margin. RPM LIM: GE on N2, P&W on N1 or N2, while a limit holds
-- the engine below the command
do
    local st, i = E.new(), E.inputs()
    local M_, B = E.RPM_MARGIN, E.RPM_BAND
    i.type, i.alt, i.tat, i.kias = "GE", 0, 15, 0
    i.idle = {25, 25, 25, 25}
    i.lever = {1, 1, 1, 1}
    i.n1, i.n2, i.actual = {100, 100, 100, 100}, {100, 100, 100, 100}, {100, 100, 100, 100}
    local o = E.update(st, i, DT)
    local red, g, show = E.REDLINE.GE, E.RPM_GAIN.GE, E.RPM_LIM_SHOW.GE
    T.near(red.n1, 117.5, 1e-9, "CF6 N1 limit 117.5 % (ATA70_80 p.205)")
    T.near(red.n2, 112.5, 1e-9, "CF6 N2 limit 112.5 % (ATA70_80 p.205)")
    for n = 1, 4 do T.near(o.target[n], o.command[n], 1e-9, "GE: rotors far from their limits: target " .. n .. " is the command") end
    T.check(all(o.rpm_lim, false), "GE: no RPM LIM far from the limits")
    -- in the band: the loop allows more than the present N1, less than the command
    i.n2[2], i.actual[2] = red.n2 - M_ - 1, 100
    o = E.update(st, i, DT)
    T.near(o.target[2], 100 + g, 1e-9, "GE: N2 1 % short of the limit less the margin: target the present N1 plus the gain")
    T.check(not o.rpm_lim[2], "GE: no RPM LIM while the engine still accelerates")
    -- just short of the band: no limit
    i.n2[2] = red.n2 - M_ - B - 0.01
    o = E.update(st, i, DT)
    T.near(o.target[2], o.command[2], 1e-9, "GE: N2 short of the band: target the command")
    -- at the limit less the margin: the loop holds the present N1
    i.n2[2] = red.n2 - M_
    o = E.update(st, i, DT)
    T.near(o.target[2], 100, 1e-9, "GE: N2 at the limit less the margin: target the present N1")
    T.check(o.rpm_lim[2] and not o.rpm_lim[1], ">ENG 2 RPM LIM: GE thrust limited by N2")
    -- past it: the target falls below the present N1
    i.n2[2] = red.n2 - M_ + 1
    o = E.update(st, i, DT)
    T.near(o.target[2], 100 - g, 1e-9, "GE: N2 1 % past: target the present N1 less the gain")
    -- holding by less than the threshold below the command: no message
    i.actual[2] = o.command[2] - show / 2
    i.n2[2] = red.n2 - M_
    o = E.update(st, i, DT)
    T.near(o.target[2], o.command[2] - show / 2, 1e-9, "GE: the target still follows the N2 loop")
    T.check(not o.rpm_lim[2], "GE: no RPM LIM when the hold-back is below the threshold")
    -- the GE's own N1 past its limit: the command is capped there, no message
    -- (the GE shows N2 limiting only); the red line lowered to reach it
    i.n2[2], i.actual[2] = 100, 100
    local saved = red.n1
    red.n1 = 100
    o = E.update(st, i, DT)
    T.near(o.target[1], 100 - M_, 1e-9, "GE: the N1 limit caps the command at the limit less the margin")
    T.check(not o.rpm_lim[1], "GE: no RPM LIM for N1")
    red.n1 = saved

    -- P&W: limited by N1 or N2, both with messages
    i.type, i.idle = "PW", {0.95, 0.95, 0.95, 0.95}
    i.n1, i.n2, i.actual = {100, 100, 100, 100}, {100, 100, 100, 100}, {1.40, 1.40, 1.40, 1.40}
    o = E.update(st, i, DT)
    red, g, show = E.REDLINE.PW, E.RPM_GAIN.PW, E.RPM_LIM_SHOW.PW
    for n = 1, 4 do T.near(o.target[n], o.command[n], 1e-9, "P&W: rotors far from their limits: target " .. n .. " is the command") end
    T.check(all(o.rpm_lim, false), "P&W: no RPM LIM far from the limits")
    i.n1[1] = red.n1 - M_ + 2
    o = E.update(st, i, DT)
    T.near(o.target[1], 1.40 - 2 * g, 1e-9, "P&W: N1 2 % past the limit less the margin: target the present EPR less twice the gain")
    T.check(o.rpm_lim[1], ">ENG 1 RPM LIM: P&W thrust limited by N1")
    i.n2[4] = red.n2 - M_ + 1
    o = E.update(st, i, DT)
    T.near(o.target[4], 1.40 - g, 1e-9, "P&W: N2 1 % past: target the present EPR less the gain")
    T.check(o.rpm_lim[4] and not o.rpm_lim[2], ">ENG 4 RPM LIM: P&W thrust limited by N2")
    i.n1[4] = red.n1 - M_ + 3
    o = E.update(st, i, DT)
    T.near(o.target[4], 1.40 - 3 * g, 1e-9, "P&W: both rotors past: the lower limit wins")
    -- the lever at idle: the command is below any limit, no message
    i.lever = {0, 0, 0, 0}
    o = E.update(st, i, DT)
    T.near(o.target[1], o.command[1], 1e-9, "P&W: idle lever: the target is the command (below the limit)")
    T.check(all(o.rpm_lim, false), "P&W: no RPM LIM at idle")
end

-- the thrust control (FCOM p.875-876): X-Plane's throttle that brings the
-- controlled value to the target. Tried here on a stand-in engine: the
-- displayed value follows the throttle through the X-Plane maps (the slope
-- tables), with a one-second lag.
local function engine_map(g, th)
    -- the controlled value at a throttle: the slope table integrated from its first point
    local y, t = g.at[1], 0
    for k = 2, #g.at do
        local dth = (g.at[k] - g.at[k - 1]) / ((g.slope[k] + g.slope[k - 1]) / 2)
        if th <= t + dth then return y + (th - t) * (g.at[k] - g.at[k - 1]) / dth end
        y, t = g.at[k], t + dth
    end
    return y + (th - t) * g.slope[#g.slope]
end
local function fly(key, target, seconds, s, y0)
    local g = E.THRUST[key]
    s = s or E.new()
    local th, eff = 0, nil
    local y = y0 or g.at[1]
    local peak, low = y, y
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        th = E.thrust_control(s, key, 1, target, y, th, key == "GE" and 25 or 0.95, DT)
        eff = eff or th
        eff = eff + (th - eff) * DT / 1.0
        y = engine_map(g, eff)
        peak, low = math.max(peak, y), math.min(low, y)
    end
    return y, th, peak, low, s
end
do
    local y, th, peak = fly("PW", 1.50, 30)
    T.near(y, 1.50, 0.005, "thrust control: P&W reaches the target EPR from idle")
    T.check(peak < 1.50 + 0.02, "thrust control: P&W does not overshoot (peak " .. string.format("%.3f", peak) .. ")")
    local s
    y, th, peak, _, s = fly("GE", 95, 30, nil, 40)
    T.near(y, 95, 0.3, "thrust control: GE reaches the target N1")
    T.check(peak < 95 + 1, "thrust control: GE does not overshoot (peak " .. string.format("%.1f", peak) .. ")")
    local low
    y, th, _, low = fly("GE", 60, 30, s, y)
    T.near(y, 60, 0.3, "thrust control: GE comes down to the target N1")
    T.check(low > 60 - 1, "thrust control: GE does not undershoot (low " .. string.format("%.1f", low) .. ")")
    -- the value followed moves no faster than the schedules: one frame after
    -- a big step the throttle has hardly moved
    s = E.new()
    local th0 = E.thrust_control(s, "PW", 1, 1.20, 1.20, 0.7, 0.95, DT)
    local th1 = E.thrust_control(s, "PW", 1, 1.60, 1.20, 0.7, 0.95, DT)
    -- (0.06 a 0.1 s step at the P&W slope of the 2026-10-30 EPR model, 0.93 at 1.20)
    T.check(th1 - th0 < 0.06, "thrust control: a lever slam moves the throttle gradually")
    T.near(th0, 0.7, 1e-9, "thrust control: it starts from X-Plane's throttle")
    -- the lever at its idle end: the EEC's idle
    T.equal(E.thrust_control(s, "PW", 1, 0.95, 1.40, 0.9, 0.95, DT), 0, "thrust control: idle lever, throttle 0")
    -- it never asks for more than full throttle
    s = E.new()
    for _ = 1, 300 do th = E.thrust_control(s, "PW", 1, 1.60, 1.00, 1.0, 0.95, DT) end
    T.equal(th, 1, "thrust control: an engine short of its target stays at full throttle")
    E.reset_thrust_control(s, 1)
    T.near(E.thrust_control(s, "PW", 1, 1.60, 1.00, 0.4, 0.95, DT), 0.4, 0.05, "thrust control: after a reset it starts from X-Plane's throttle")
end

-- X-Plane's idle ratio (M.IDLE, measured in X-Plane against the FCOM's idle
-- descents): minimum idle in the air by pressure altitude, one value on the
-- ground, approach idle 0.5 above the air's
T.near(E.idle_ratio(true, 10000, false), 2.5, 1e-9, "idle ratio: minimum idle in the air at 10,000 ft")
T.near(E.idle_ratio(true, 25000, false), 3.5, 1e-9, "idle ratio: between 20,000 and 30,000 ft")
T.near(E.idle_ratio(true, 41000, false), 4.7, 1e-9, "idle ratio: held above 35,000 ft")
T.near(E.idle_ratio(false, 0, false), 1.07, 1e-9, "idle ratio: minimum idle on the ground")
T.near(E.idle_ratio(false, 5000, false), 1.07, 1e-9, "idle ratio: the same on a high airport")
T.near(E.idle_ratio(true, 0, true), 2.8, 1e-9, "idle ratio: approach idle in the air near the ground")
T.near(E.idle_ratio(false, 0, true), 2.8, 1e-9, "idle ratio: approach idle on the ground (after touchdown, CF6 reversers)")
do
    local above = true
    for h = -1000, 45000, 500 do
        above = above and E.idle_ratio(true, h, true) > E.idle_ratio(true, h, false)
            and E.idle_ratio(true, h, false) > E.idle_ratio(false, h, false)
    end
    T.check(above, "idle ratio: approach idle above minimum idle in the air, that above the ground's, at every height")
end

T.done()
