-- Run from the repository root with LuaJIT: luajit tests/eec/egt_model_test.lua
-- The EGT the EICAS shows for the PW4056 and the CF6-80C2 (plugins/xtlua/
-- scripts/B747.42.xt.EEC/B747.42.egt_model.lua, ENG-33, 2026-11-10) against
-- the FCOM's primary EICAS figures (p.829-830, p.839-840) and the limits:
-- PW4056 EASA TCDS IM.E.050 p.9 (a web source, not in _ref: takeoff 654,
-- maximum continuous 629, ground start 535 °C), CF6-80C2 ATA70_80 p.395
-- (takeoff 960 °C); the start model's hot start (its START_LIMIT less
-- HOT_MARGIN: P&W 510, GE 725 °C). The takeoff and the hot day's climb and
-- maximum continuous thrust from the FCOM PI tables the EEC holds
-- (B747.42.eec_model.lua, B747.42.ref_thrust_model.lua).
local T = dofile("tests/lib/check.lua")("egt_model")
local G = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.egt_model.lua")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local R = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.ref_thrust_model.lua")
local S = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua")

local TO_LIMIT = {PW = 654, GE = 960}
local MCT_LIMIT = {PW = 629}
local HOT = {PW = S.START_LIMIT.PW - S.HOT_MARGIN, GE = S.START_LIMIT.GE - S.HOT_MARGIN}
local IDLE_X = {PW = G.IDLE.PW[1], GE = G.IDLE.GE[1]}
T.equal(HOT.PW, 510, "the start model's P&W hot start at 510 °C")
T.equal(HOT.GE, 725, "the start model's GE hot start at 725 °C")
T.equal(G.IDLE_N2, S.IDLE_MIN_N2, "the start ends at the start model's idle N2")
T.check(G.LIGHT_N2.PW == S.FUEL_ON_N2.PW and G.LIGHT_N2.GE == S.FUEL_ON_N2.GE, "the start's EGT from the autostart's fuel-on N2")

-- run one engine at fixed inputs for some seconds; the EGT at the end
local function run(s, inp, seconds, dt)
    dt = dt or 0.05
    local e
    for _ = 1, math.floor(seconds / dt + 0.5) do e = G.update(s, inp, dt) end
    return e
end
local function engine(kind, t)
    local inp = G.inputs()
    inp.kind = kind
    for k, v in pairs(t or {}) do inp[k] = v end
    return G.new(), inp
end
-- the TAT of an outside air temperature at a Mach
local function tat_of(oat, mach) return (oat + 273.15) * (1 + 0.2 * mach * mach) - 273.15 end

-- ======== the FCOM's figures (the cruise, and one engine shut down), running
local FIGS = {
    {"PW", 1.38, -14, 462, 3, "P&W CRZ, EPR 1.38 (FCOM p.830)"},
    {"PW", 1.51, -8, 490, 3, "P&W engine 4 shut down, EPR 1.51 (FCOM p.840)"},
    {"GE", 95.2, -14, 662, 5, "GE CRZ, N1 95.2 (FCOM p.829)"},
    {"GE", 99.2, -8, 714, 5, "GE engine 4 shut down, N1 99.2 (FCOM p.839)"},
}
for _, f in ipairs(FIGS) do
    local s, inp = engine(f[1], {burning = true, n2 = 90, x = f[2], tat = f[3], air = true})
    T.near(run(s, inp, 30), f[4], f[5], f[6] .. ": " .. f[4] .. " °C")
    T.near(G.steady(f[1], f[2], f[3]), f[4], 1e-6, f[6] .. ": the steady state through the point")
end
-- the corrected EGT (EGT in K over theta) at the figures, as the comments give them
T.near(G.CURVE.PW[2][2], 817.42, 0.01, "P&W 1.38: corrected EGT 817.4 K")
T.near(G.CURVE.PW[3][2], 829.35, 0.01, "P&W 1.51: corrected EGT 829.3 K")
T.near(G.CURVE.GE[2][1], 100.39, 0.01, "GE: corrected N1 100.4 at the CRZ figure")
T.near(G.CURVE.GE[2][2], 1039.80, 0.01, "GE: corrected EGT 1039.8 K there")
T.near(G.CURVE.GE[3][1], 103.41, 0.01, "GE: corrected N1 103.4 at the engine-out figure")
T.near(G.CURVE.GE[3][2], 1072.78, 0.01, "GE: corrected EGT 1072.8 K there")
-- the ground idle at ISA sea level (estimates), held below, the last slope above
T.near(G.steady("PW", 1.00, 15), 390, 1e-6, "P&W ground idle, ISA sea level: 390 °C (estimate)")
T.near(G.steady("GE", 25.9, 15), 500, 1e-6, "GE ground idle, ISA sea level: 500 °C (estimate)")
T.near(G.steady("PW", 0.70, 15), 390, 1e-6, "P&W below the idle's EPR (the in-flight idle at speed): held at the idle's")
local sl = (G.CURVE.PW[3][2] - G.CURVE.PW[2][2]) / (G.CURVE.PW[3][1] - G.CURVE.PW[2][1])
T.near(G.corrected("PW", 1.61), G.CURVE.PW[3][2] + 0.1 * sl, 1e-9, "P&W above 1.51: the 1.38-1.51 slope carried on")
local mono = true
for _, kind in ipairs({"PW", "GE"}) do
    local lo, hi, step = 0.6, 1.8, 0.01
    if kind == "GE" then lo, hi, step = 10, 120, 0.5 end
    local prev = -math.huge
    for x = lo, hi, step do
        local c = G.corrected(kind, x)
        mono = mono and c >= prev
        prev = c
    end
end
T.check(mono, "the corrected EGT never falls with the power")
T.check(G.steady("PW", 1.3, 30) > G.steady("PW", 1.3, 0), "the same EPR on a warmer day: a higher EGT (theta)")

-- ======== the takeoff (the go-around table's rating, the EEC's takeoff
-- rating): P&W at OAT 33 °C at sea level under its takeoff limit with a
-- margin; on the run (M.25) the TAT and the EGT are higher, the EEC's rating
-- from the TAT a little lower
local function ref(t)
    local i = {type = "PW", mode = "TO", to_pct = 0, alt = 0, tat = 15, mach = 0, packs_on = 3, wai = false, nai = false, kias = 0}
    for k, v in pairs(t) do i[k] = v end
    return (R.reference(i))
end
local function takeoff(kind, oat, mach, packs)
    local tat = tat_of(oat, mach)
    local x = ref({type = kind, tat = tat, mach = mach, packs_on = packs or 3})
    return G.steady(kind, x, tat), x, tat
end
local egt0, epr0 = takeoff("PW", 33, 0)
local egt1, epr1, tat1 = takeoff("PW", 33, 0.25)
T.near(epr0, 1.51, 1e-9, "P&W takeoff EPR at 33 °C standing: 1.51 (PI.10.37)")
T.check(TO_LIMIT.PW - egt1 >= 25 and TO_LIMIT.PW - egt1 <= 45,
    string.format("P&W takeoff at 33 °C on the run (M.25, TAT %.1f, EPR %.3f): %.1f °C, %.1f under 654", tat1, epr1, egt1, TO_LIMIT.PW - egt1))
T.check(TO_LIMIT.PW - egt0 >= 25 and egt0 < egt1,
    string.format("P&W takeoff at 33 °C standing (EPR 1.51): %.1f °C, %.1f under 654, below the run's", egt0, TO_LIMIT.PW - egt0))
local egtp = takeoff("PW", 33, 0.25, 0)
T.check(TO_LIMIT.PW - egtp >= 25, string.format("P&W takeoff at 33 °C, packs off (+0.02 EPR): %.1f °C", egtp))
T.check(takeoff("PW", 15, 0.25) < egt1 - 30, string.format("P&W takeoff at 15 °C: %.1f °C, cooler", takeoff("PW", 15, 0.25)))
for _, m in ipairs({0, 0.25}) do
    local egt, n1 = takeoff("GE", 33, m)
    T.check(egt < TO_LIMIT.GE - 50, string.format("GE takeoff at 33 °C (M%.2f, N1 %.1f): %.1f °C under 960", m, n1, egt))
end

-- the hot day's climb and maximum continuous thrust (P&W): the maximum climb
-- and maximum continuous tables (CLB, CON) from sea level to 40,000 ft, ISA
-- to ISA+35 up to 50 °C, 150-350 KIAS, packs on and off: under 629
local worst, where = -math.huge, ""
local n = 0
for _, h in ipairs({0, 1500, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000}) do
    local isa = 15 - 0.0019812 * math.min(h, 36089)
    local d = (1 - 6.87559e-6 * math.min(h, 36089)) ^ 5.25588
    for dev = 0, 35, 5 do
        local oat = isa + dev
        for _, kias in ipairs({150, 200, 250, 300, 350}) do
            local qc = (1 + 0.2 * (kias / 661.4786) ^ 2) ^ 3.5 - 1
            local m = math.sqrt(5 * ((qc / d + 1) ^ (1 / 3.5) - 1))
            if oat <= 50 and m <= 0.9 then
                local tat = tat_of(oat, m)
                for _, mode in ipairs({"CLB", "CON"}) do
                    for _, packs in ipairs({3, 0}) do
                        local epr = ref({mode = mode, alt = h, tat = tat, mach = m, kias = kias, packs_on = packs})
                        local egt = G.steady("PW", epr, tat)
                        n = n + 1
                        if egt > worst then
                            worst, where = egt, string.format("%s %d ft ISA+%d %d KIAS TAT %.1f EPR %.3f", mode, h, dev, kias, tat, epr)
                        end
                    end
                end
            end
        end
    end
end
T.check(n > 500 and worst < MCT_LIMIT.PW, string.format("P&W climb and maximum continuous on hot days (%d points): at most %.1f °C (%s) under 629", n, worst, where))

-- ======== the start: X-Plane's N2 up from 0 with the starter, the light-off
-- at the autostart's fuel-on N2 (the start model's FUEL_ON_N2), then N2 at
-- rate %/s to 68 % (X-Plane's ground idle about 70 %); the peak above the
-- idle's and under the hot start, the end at the idle's
local function start(kind, oat, rate, dt)
    local s, inp = engine(kind, {tat = oat, floor = oat, x = IDLE_X[kind]})
    dt = dt or 1 / 30
    local n2, burning, peak, t = 0, false, -math.huge, 0
    local light = S.FUEL_ON_N2[kind]
    while t < 150 do
        t = t + dt
        if not burning and n2 >= light then burning = true end
        if burning then n2 = math.min(68, n2 + rate * dt) else n2 = n2 + 0.85 * dt end
        inp.burning, inp.n2 = burning, n2
        local e = G.update(s, inp, dt)
        if e > peak then peak = e end
    end
    return peak, s.egt
end
for _, kind in ipairs({"PW", "GE"}) do
    for _, oat in ipairs({15, 40}) do
        local idle = G.steady(kind, IDLE_X[kind], oat)
        local top = G.start_target(kind, G.LIGHT_N2[kind] + G.PEAK_AT * (G.IDLE_N2 - G.LIGHT_N2[kind]), oat, oat)
        T.check(top < HOT[kind], string.format("%s start at %d °C: the target's peak %.1f under the hot start %d", kind, oat, top, HOT[kind]))
        for _, rate in ipairs({0.5, 1, 2}) do
            local peak, last = start(kind, oat, rate)
            T.check(peak < HOT[kind] and peak > idle + 5,
                string.format("%s start at %d °C, N2 %.1f %%/s: peak %.1f over the idle %.1f, under %d", kind, oat, rate, peak, idle, HOT[kind]))
            T.near(last, idle, 0.5, string.format("%s start at %d °C, N2 %.1f %%/s: settles at the idle", kind, oat, rate))
        end
    end
end
-- a warm engine lit again (30 s after a shutdown at idle): the start rises
-- from its EGT, no drop first
do
    local s, inp = engine("PW", {burning = true, n2 = 70, x = 1.0, tat = 15, floor = 15})
    run(s, inp, 30)
    inp.burning, inp.n2 = false, 20
    local warm = run(s, inp, 30)
    inp.burning = true
    local e1 = G.update(s, inp, 0.05)
    inp.n2 = 25
    local e2 = run(s, inp, 2)
    T.check(warm > 200 and e1 >= warm - 1e-6 and e2 > e1,
        string.format("lit again at %.1f °C: %.1f, then %.1f (no drop first)", warm, e1, e2))
end

-- ======== not burning: in the air toward the windmilling engine's (57 °C at
-- TAT -8, FCOM p.840 and p.839), on the ground toward the TAT, 60 s
do
    local s, inp = engine("PW", {burning = true, n2 = 90, x = 1.51, tat = -8, air = true, floor = -30})
    T.near(run(s, inp, 30), 490, 3, "windmill: running first at the FCOM's 490")
    inp.burning, inp.n2 = false, 25
    local e60 = run(s, inp, 60)
    T.near(e60, 57 + (490 - 57) * math.exp(-1), 2, string.format("windmill: a minute after the shutdown %.1f (the 60 s lag)", e60))
    T.near(run(s, inp, 600), 57, 1, "windmill: 57 °C at TAT -8 (FCOM p.840)")
    inp.tat = -40
    T.check(run(s, inp, 600) < 30, "windmill at TAT -40: colder")
end
do
    local s, inp = engine("PW", {burning = true, n2 = 70, x = 1.0, tat = 15, floor = 15})
    T.near(run(s, inp, 30), 390, 0.5, "ground idle at 15 °C")
    inp.burning = false
    local prev, falling = 390, true
    for _ = 1, 60 do
        local e = run(s, inp, 1)
        falling = falling and e <= prev
        prev = e
    end
    T.check(falling, "shut down on the ground: the EGT falls")
    T.near(prev, 15 + 375 * math.exp(-1), 3, string.format("a minute after the shutdown: %.1f", prev))
    T.near(run(s, inp, 900), 15, 0.5, "on the ground: down to the TAT")
    inp.tat, inp.floor = 15, 20
    T.near(run(s, inp, 0.1), 20, 1e-9, "never under the floor (the outside air temperature)")
end

-- ======== the lags: about 2 s up and 3 s down, in seconds (not frames)
do
    local s, inp = engine("PW", {burning = true, n2 = 90, x = 1.0, tat = 15, air = true})
    run(s, inp, 30)
    inp.x = 1.51
    local target = G.steady("PW", 1.51, 15)
    local e = run(s, inp, 2)
    T.near((e - 390) / (target - 390), 1 - math.exp(-1), 0.01, "a step up: 63 % in 2 s")
    run(s, inp, 30)
    inp.x = 1.0
    e = run(s, inp, 3)
    T.near((target - e) / (target - 390), 1 - math.exp(-1), 0.01, "a step down: 63 % in 3 s")
end

-- ======== the frame rate: the same 10 s at 50 and 10 frames a second (a
-- start's light-off and N2, then the levers forward with the EPR spooling
-- up over 4 s) within 1 °C at every second
local function ten_seconds(kind, dt)
    local s, inp = engine(kind, {tat = 20, floor = 20, air = false})
    local out = {}
    local steps = math.floor(10 / dt + 0.5)
    -- a start: light-off at 2 s at the fuel-on N2, N2 up 3 %/s
    for k = 1, steps do
        local t = k * dt
        inp.burning = t > 2 + 1e-9
        inp.n2 = S.FUEL_ON_N2[kind] + math.max(0, t - 2) * 3
        inp.x = IDLE_X[kind]
        G.update(s, inp, dt)
        if math.abs(t - math.floor(t + 0.5)) < 1e-9 then out[#out + 1] = s.egt end
    end
    -- running: the power from idle to the takeoff's over 4 s, held
    local x0, x1 = IDLE_X[kind], kind == "GE" and 105 or 1.51
    for k = 1, steps do
        local t = k * dt
        inp.burning, inp.n2 = true, 80
        inp.x = x0 + (x1 - x0) * math.min(1, t / 4)
        G.update(s, inp, dt)
        if math.abs(t - math.floor(t + 0.5)) < 1e-9 then out[#out + 1] = s.egt end
    end
    -- a shutdown, 10 s of cooling
    for k = 1, steps do
        local t = k * dt
        inp.burning, inp.n2 = false, 30
        G.update(s, inp, dt)
        if math.abs(t - math.floor(t + 0.5)) < 1e-9 then out[#out + 1] = s.egt end
    end
    return out
end
for _, kind in ipairs({"PW", "GE"}) do
    local a, b = ten_seconds(kind, 0.02), ten_seconds(kind, 0.1)
    local diff = 0
    for i = 1, math.min(#a, #b) do diff = math.max(diff, math.abs(a[i] - b[i])) end
    T.check(#a == 30 and #b == 30 and diff < 1,
        string.format("%s: 50 and 10 frames a second the same within 1 °C (at most %.3f over %d seconds)", kind, diff, #a))
end

-- ======== a new flight: the target at once while settling, then the lags
do
    local s, inp = engine("PW", {burning = true, n2 = 90, x = 1.38, tat = -14, air = true})
    G.settle(s, 2)
    T.near(G.update(s, inp, 0.05), 462, 3, "settling: the cruise's EGT at once")
    inp.x = 1.0
    T.near(run(s, inp, 1.95), G.steady("PW", 1.0, -14), 1e-6, "settling: still the target at once")
    inp.x = 1.38
    local e = G.update(s, inp, 0.2)
    T.check(e < 400, string.format("after the settling (2 s): the lag again (%.1f)", e))
end

-- ======== (2026-11-10) the failure window's HOT START (estimates): while
-- starting the target is HOT_START_C over the idle's, 650 (P&W) and 820 °C
-- (GE) at 15 °C; the EGT passes the start model's hot start a few seconds
-- after the light-off and the start limit (P&W 535, GE 750) with the fuel
-- left on; running (N2 55 %) the engine is normal. The start as above: the
-- light-off at the fuel-on N2, then N2 1 %/s to 68 %
local LIMIT = {PW = S.START_LIMIT.PW, GE = S.START_LIMIT.GE}
T.near(G.hot_target("PW", 15), 650, 1e-6, "HOT START: the P&W's target 650 °C at 15 °C")
T.near(G.hot_target("GE", 15), 820, 1e-6, "HOT START: the GE's target 820 °C at 15 °C")
-- a cold day: no lower than the 15 °C day's (on the corrected scaling alone
-- 506 °C for the P&W at -30 °C, under its hot start)
T.near(G.hot_target("PW", -30), 650, 1e-6, "HOT START at -30 °C: the P&W's target still 650 °C (over the start limit 535)")
T.near(G.hot_target("GE", -30), 820, 1e-6, "HOT START at -30 °C: the GE's target still 820 °C (over the start limit 750)")
T.check(G.hot_target("PW", 40) > 650, "HOT START at 40 °C: higher than the 15 °C day's")
local function hot_start(kind, oat, dt)
    local s, inp = engine(kind, {tat = oat, floor = oat, x = IDLE_X[kind], hot_start = true})
    dt = dt or 0.05
    local n2, burning, t, lit = 0, false, 0, nil
    local to_hot, to_limit, peak = nil, nil, -math.huge
    while t < 150 do
        t = t + dt
        if not burning and n2 >= S.FUEL_ON_N2[kind] then burning, lit = true, t end
        if burning then n2 = math.min(68, n2 + 1 * dt) else n2 = n2 + 0.85 * dt end
        inp.burning, inp.n2 = burning, n2
        local e = G.update(s, inp, dt)
        if lit and not to_hot and e >= HOT[kind] then to_hot = t - lit end
        if lit and not to_limit and e >= LIMIT[kind] then to_limit = t - lit end
        if e > peak then peak = e end
    end
    return to_hot, to_limit, peak, s.egt
end
for _, kind in ipairs({"PW", "GE"}) do
    for _, oat in ipairs({15, 40, 50}) do
        local to_hot, to_limit, peak, last = hot_start(kind, oat)
        T.check(to_hot and to_limit and to_hot < 6 and to_limit < 8 and peak > LIMIT[kind] + 50,
            string.format("HOT START, %s at %d °C: the hot start %d after %s s, the start limit %d after %s s, up to %.1f",
                kind, oat, HOT[kind], tostring(to_hot), LIMIT[kind], tostring(to_limit), peak))
        T.near(last, G.steady(kind, IDLE_X[kind], oat), 0.5, string.format("HOT START, %s at %d °C: running at idle, the idle's EGT", kind, oat))
    end
    local a, b = {hot_start(kind, 15, 0.02)}, {hot_start(kind, 15, 0.1)}
    T.check(math.abs(a[1] - b[1]) < 0.15 and math.abs(a[3] - b[3]) < 1,
        string.format("HOT START, %s: 50 and 10 frames a second alike (%.2f / %.2f s to the hot start)", kind, a[1], b[1]))
end

-- ======== (2026-11-10) EGT OVERTEMP (estimates): the excess grows 3 K/s
-- (corrected) while set and running, to 500 K, by the power's share, the
-- corrected N1 (0.25 at the EEC's minimum idle N1 25.9 and below, 1 at the
-- first FCOM figure's: P&W N1 91.2, GE 95.2 at TAT -14; at most 1.5);
-- cleared, it dies away in 30 s. In the cruise: the maximum continuous and
-- the takeoff limits within about 2 minutes (the QRH's Engine Limit,
-- QRH_CA p.124), also X-Plane's light, high cruise where the EPR is near 1
-- (s279 2026-11-10: EPR 1.15, N1 84.2, TAT -25.2; the first version's
-- share by the EPR stopped near 470 °C there). The lever at idle with the
-- excess at its most: under the continuous limit and steady, in the air
-- (FL370's minimum idle N1 50.8, B747.42.xt.EEC.PW.lua) and on the ground
-- at 15 and 50 °C; cleared: back to normal within about 2 minutes
local function seconds_to(s, inp, limits, seconds, dt)
    dt = dt or 0.05
    local t, at, e = 0, {}, nil
    for _ = 1, math.floor(seconds / dt + 0.5) do
        e = G.update(s, inp, dt)
        t = t + dt
        for i, l in ipairs(limits) do if not at[i] and e >= l then at[i] = t end end
    end
    return at, e
end
local function n1c(n1, tat) return n1 / math.sqrt(G.theta(tat)) end
T.near(G.excess_share("PW", n1c(91.2, -14)), 1, 1e-9, "EGT OVERTEMP: the share 1 at the P&W's FCOM cruise (N1 91.2, TAT -14: N1c 96.2)")
T.near(G.excess_share("GE", n1c(95.2, -14)), 1, 1e-9, "EGT OVERTEMP: the GE's share 1 at its FCOM cruise (N1 95.2, TAT -14: N1c 100.4)")
T.near(G.excess_share("PW", 25.9), 0.25, 1e-9, "EGT OVERTEMP: the share 0.25 at the minimum idle N1 and below")
T.near(G.excess_share("PW", 140), 1.5, 1e-9, "EGT OVERTEMP: the share at most 1.5")
T.check(G.excess_share("PW", n1c(84.2, -25.2)) > 0.9,
    string.format("EGT OVERTEMP: X-Plane's FL370 cruise (N1 84.2, TAT -25.2): share %.3f (by the EPR 1.15 it was 0.39)", G.excess_share("PW", n1c(84.2, -25.2))))
for _, c in ipairs({
    {"X-Plane's FL370 cruise (s279), EPR 1.15, N1 84.2, TAT -25.2", 1.15, 84.2, -25.2},
    {"the FCOM's cruise (p.830), EPR 1.38, N1 91.2, TAT -14", 1.38, 91.2, -14},
}) do
    local s, inp = engine("PW", {burning = true, n2 = 90, x = c[2], n1 = c[3], tat = c[4], air = true, floor = -55})
    local base = run(s, inp, 30)
    T.near(base, G.steady("PW", c[2], c[4]), 0.5, "EGT OVERTEMP: " .. c[1] .. ": first normal")
    inp.egt_high = true
    local at, e = seconds_to(s, inp, {629, 654}, 180)
    T.check(at[1] and at[2] and at[1] < at[2] and at[2] <= 150,
        string.format("EGT OVERTEMP, P&W, %s (%.1f °C): 629 after %s s, 654 after %s s (%.1f at 3 min)", c[1], base, tostring(at[1]), tostring(at[2]), e))
    T.check(at[1] and at[1] > 45, "EGT OVERTEMP: " .. c[1] .. ": not at once (629 after more than 45 s)")
    T.near(s.excess, G.EGT_HIGH_MAX, 1e-9, "EGT OVERTEMP: " .. c[1] .. ": the excess at its most (500 K) after 3 minutes")
    -- the lever to idle (the in-flight idle's EPR, under 1 at speed; the
    -- minimum idle N1 at FL370): under the limits, and steady with the
    -- excess at its most
    inp.x, inp.n1 = 0.95, 50.8
    local e1 = run(s, inp, 60)
    local e2 = run(s, inp, 60)
    T.check(e1 < 629 - 50 and math.abs(e2 - e1) < 0.5,
        string.format("EGT OVERTEMP at idle, %s: %.1f, a minute later %.1f (steady, under 629 by 50)", c[1], e1, e2))
    -- cleared at the cruise's power: back to normal
    inp.x, inp.n1 = c[2], c[3]
    local high = run(s, inp, 30)
    inp.egt_high = false
    local back = run(s, inp, 120)
    T.check(high > 654 and back - base < 10,
        string.format("EGT OVERTEMP cleared, %s (%.1f °C): 2 minutes later %.1f, %.1f over the normal", c[1], high, back, back - base))
    -- shut down with the failure set: the excess held; a new flight: gone
    inp.egt_high = true
    run(s, inp, 200)
    inp.burning, inp.n2 = false, 20
    run(s, inp, 60)
    T.near(s.excess, G.EGT_HIGH_MAX, 1e-9, "EGT OVERTEMP: the excess held while the engine does not run")
    G.settle(s, 2)
    T.equal(s.excess, 0, "EGT OVERTEMP: no excess left at a new flight")
end
for _, c in ipairs({{"PW", 15, 629}, {"PW", 50, 629}, {"GE", 15, 925}, {"GE", 50, 925}}) do
    -- on the ground at idle (the minimum idle N1) with the excess at its most
    local kind, oat, lim = c[1], c[2], c[3]
    local s, inp = engine(kind, {burning = true, n2 = 70, x = IDLE_X[kind], n1 = 25.9, tat = oat, floor = oat, egt_high = true})
    run(s, inp, 200)
    local e = run(s, inp, 60)
    T.check(e < lim and e > G.steady(kind, IDLE_X[kind], oat),
        string.format("EGT OVERTEMP at ground idle, %s %d °C, at its most: %.1f °C, under %d", kind, oat, e, lim))
end
do
    -- the GE in the cruise (N1 95.2, TAT -14): its maximum continuous 925 and
    -- its takeoff limit 960 (ATA70_80 p.395) within about 2 minutes
    local s, inp = engine("GE", {burning = true, n2 = 90, x = 95.2, n1 = 95.2, tat = -14, air = true})
    run(s, inp, 30)
    inp.egt_high = true
    local at = seconds_to(s, inp, {925, 960}, 180)
    T.check(at[1] and at[2] and at[1] < at[2] and at[2] <= 150,
        string.format("EGT OVERTEMP, GE N1 95.2, TAT -14: 925 after %s s, 960 after %s s", tostring(at[1]), tostring(at[2])))
end
do
    -- the frame rate: the same 3 minutes at 50 and 10 frames a second
    local function three_minutes(dt)
        local s, inp = engine("PW", {burning = true, n2 = 90, x = 1.15, n1 = 84.2, tat = -25.2, air = true})
        run(s, inp, 30, dt)
        inp.egt_high = true
        local e = run(s, inp, 150, dt)
        inp.egt_high = false
        return e, run(s, inp, 30, dt)
    end
    local a1, a2 = three_minutes(0.02)
    local b1, b2 = three_minutes(0.1)
    T.check(math.abs(a1 - b1) < 1 and math.abs(a2 - b2) < 1,
        string.format("EGT OVERTEMP: 50 and 10 frames a second alike (%.2f / %.2f, %.2f / %.2f)", a1, b1, a2, b2))
end

T.done()
