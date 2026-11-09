-- Run from the repository root with LuaJIT: luajit tests/engines/start_egt_test.lua
-- (2026-11-10) The engine start model (plugins/xtlua/scripts/B747.40.xt.
-- engines/B747.40.engine_start_model.lua) with the EGT model (plugins/xtlua/
-- scripts/B747.42.xt.EEC/B747.42.egt_model.lua) and a stand-in engine (its
-- N2 and light-off, as engine_start_model_test.lua's; the EGT the EGT
-- model's, as the EICAS shows it and the start model reads it): the failure
-- window's HOT START on the ground. The autostart cuts the fuel at its hot
-- start (the start limit less HOT_MARGIN: P&W 510, GE 725 °C) before the
-- starter cutout and tries again; P&W 30 s of motoring and 2 tries, GE the
-- fuel off FUEL_CUT_S and 3 tries, then the abort and ENG n AUTOSTART (FCOM
-- p.880-881 (7.20.10-11), p.899). A manual start is the crew's to abort
-- (FCOM p.185 (SP.7.3)): nothing cuts the fuel and the EGT passes the start
-- limit (P&W 535, GE 750). Without the failure a start stays under the hot
-- start at 15, 40 and 50 °C.
local T = dofile("tests/lib/check.lua")("start_egt")
local S = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua")
local G = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.egt_model.lua")

local DT = 0.05
local HOT = {PW = S.START_LIMIT.PW - S.HOT_MARGIN, GE = S.START_LIMIT.GE - S.HOT_MARGIN}
local LIMIT = {PW = S.START_LIMIT.PW, GE = S.START_LIMIT.GE}
T.check(HOT.PW == 510 and HOT.GE == 725 and LIMIT.PW == 535 and LIMIT.GE == 750,
    "the start model's hot start 510 / 725 °C and start limit 535 / 750 °C")

-- the stand-in engine: the starter turns N2 at 0.85 %/s up to 30 %; fuel and
-- a working igniter light it above 10 % N2; burning, N2 rises 1.2 %/s below
-- 50 % and 0.6 %/s above, to 68 % (idle); no fuel puts it out
local function step_engine(e, starter, fuel, igniter, dt)
    if fuel and e.burning then
        -- keeps burning
    elseif fuel and igniter and e.n2 > 10 then
        e.burning = true
    elseif not fuel then
        e.burning = false
    end
    if e.burning then
        local rate = e.n2 < 50 and 1.2 or 0.6
        if e.n2 < 68 then e.n2 = math.min(68, e.n2 + rate * dt) end
    elseif starter then
        e.n2 = math.min(30, e.n2 + 0.85 * dt)
    else
        e.n2 = math.max(0, e.n2 - 1.0 * dt)
    end
end

-- engine 1 on the ground at an outside air temperature, powered, the
-- AUTOSTART switch as told, the HOT START failure as told
local function rig(kind, oat, autostart, hot_start)
    local r = {kind = kind, t = 0, lights = {}, cuts = {}, max_egt = -math.huge}
    r.s, r.inp = S.new(), S.inputs()
    local inp = r.inp
    inp.type = kind
    inp.autostart = autostart
    inp.ac1, inp.ac3, inp.ac_stby, inp.main_bat, inp.apu_bat = true, true, true, true, true
    r.e = {n2 = 0, burning = false}
    r.g, r.gi = G.new(), G.inputs()
    r.gi.kind, r.gi.tat, r.gi.floor, r.gi.air = kind, oat, oat, false
    r.gi.x = G.IDLE[kind][1]                 -- the EPR or N1 shown at idle
    r.gi.hot_start = hot_start
    r.egt = G.update(r.g, r.gi, DT)          -- a cold engine: the outside air's
    for n = 1, 4 do inp.egt[n] = r.egt end
    return r
end

-- one frame: the start model, the start valve as commanded, the START
-- switch released when the model lets it go, the stand-in engine, the EGT
-- model; notes the light-offs (with the igniters firing then), the fuel
-- cuts, the first crossings of the hot start and the start limit after
-- each light-off (time from it, N2 then) and the highest EGT
local function frame(r)
    local inp = r.inp
    local out = S.update(r.s, inp, DT)
    local o = out.eng[1]
    inp.start_valve[1] = o.start_cmd
    if o.release_start_sw then inp.start_sw[1] = false end
    local was_burning = r.e.burning
    step_engine(r.e, o.starter, o.fuel, o.ignition, DT)
    r.t = r.t + DT
    if r.e.burning and not was_burning then
        r.lights[#r.lights + 1] = {t = r.t, n2 = r.e.n2, both = o.igniter1 and o.igniter2, attempt = o.attempt}
    end
    if was_burning and not r.e.burning then r.cuts[#r.cuts + 1] = {t = r.t, phase = o.phase} end
    r.gi.burning, r.gi.n2 = r.e.burning, r.e.n2
    r.egt = G.update(r.g, r.gi, DT)
    inp.n2[1], inp.egt[1], inp.burning[1] = r.e.n2, r.egt, r.e.burning
    inp.spar_valve[1] = inp.fuel_control[1] and 1 or 0
    if r.egt > r.max_egt then r.max_egt = r.egt end
    if out.msg.autostart[1] and not r.caution_t then r.caution_t = r.t end
    local l = r.lights[#r.lights]
    if l then
        if not l.hot and r.egt >= HOT[r.kind] then l.hot, l.hot_n2 = r.t - l.t, r.e.n2 end
        if not l.limit and r.egt >= LIMIT[r.kind] then l.limit = r.t - l.t end
    end
    return out
end
local function run(r, seconds, until_fn)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = frame(r)
        if until_fn and until_fn(out) then break end
    end
    return out
end

-- an autostart: START and RUN together (FCOM p.879), to the abort or the idle
local function autostart(kind, oat, hot_start)
    local r = rig(kind, oat, true, hot_start)
    r.inp.start_sw[1], r.inp.fuel_control[1] = true, true
    local out = run(r, 400, function(o)
        local e = o.eng[1]
        return e.phase == S.ABORTED or (e.phase == S.OFF and r.e.burning)
    end)
    return r, out
end
-- a manual start (AUTOSTART OFF): START pulled, RUN at the maximum motoring
-- (P&W, FCOM p.185 (SP.7.3): the stand-in's 30 %, 5 s after it stops
-- rising) or at the fuel-on N2 (GE, FCOM p.882 (7.20.12)), then 90 s
local function manual(kind, oat, hot_start)
    local r = rig(kind, oat, false, hot_start)
    r.inp.start_sw[1] = true
    if kind == "GE" then
        run(r, 60, function() return r.e.n2 >= S.FUEL_ON_N2[kind] end)
    else
        run(r, 60, function() return r.e.n2 >= 30 - 1e-9 end)
        run(r, 5)
    end
    r.inp.fuel_control[1] = true
    local fuel_always, burning_always = true, true
    local out
    for _ = 1, math.floor(90 / DT + 0.5) do
        out = frame(r)
        fuel_always = fuel_always and out.eng[1].fuel
        burning_always = burning_always and (r.e.burning or #r.lights == 0)
    end
    return r, out, fuel_always, burning_always
end

local function fmt(v) return v and string.format("%.2f", v) or "never" end

-- ======== P&W autostart with HOT START (109, FCOM p.881): the hot start
-- before the starter cutout, fuel and ignition off, 30 s of motoring, a
-- second try with both igniters, hot again: aborted (2 tries), no motoring,
-- ENG 1 AUTOSTART
do
    local r, out = autostart("PW", 15, true)
    local o = out.eng[1]
    local l1, l2 = r.lights[1], r.lights[2]
    T.check(l1 and l1.hot and l1.hot < 6 and l1.hot_n2 < S.CUTOUT_N2,
        string.format("P&W hot start: 510 °C %s s after the light-off, N2 %.1f %% (before the cutout at 50 %%)", fmt(l1 and l1.hot), l1 and l1.hot_n2 or -1))
    T.check(r.cuts[1] and l1 and l1.hot and math.abs(r.cuts[1].t - l1.t - l1.hot) < 3 * DT,
        "P&W hot start: the fuel cut the frame after (" .. fmt(r.cuts[1] and l1 and r.cuts[1].t - l1.t) .. " s after the light-off)")
    T.check(l2 and r.cuts[1] and l2.t - r.cuts[1].t >= S.DRY_MOTOR_S - DT and l2.t - r.cuts[1].t < S.DRY_MOTOR_S + 1,
        "P&W hot start: 30 s of motoring before the second try (" .. fmt(l2 and r.cuts[1] and l2.t - r.cuts[1].t) .. " s)")
    T.check(l2 and l2.both and l2.attempt == 2, "P&W hot start: the second try with both igniters")
    T.check(l2 and l2.hot and l2.hot < 6 and l2.hot_n2 < S.CUTOUT_N2,
        string.format("P&W hot start: hot again %s s after the second light-off", fmt(l2 and l2.hot)))
    T.equal(#r.lights, 2, "P&W hot start: two tries (FCOM p.881)")
    T.equal(o.phase, S.ABORTED, "P&W hot start: the autostart aborted")
    T.equal(o.attempt, 2, "P&W hot start: aborted on the second try")
    T.check(out.msg.autostart[1], "P&W hot start: ENG 1 AUTOSTART (caution, FCOM p.899)")
    T.check(not o.fuel and not o.ignition and not o.start_cmd and not r.inp.start_sw[1],
        "P&W hot start abort: fuel, ignition and start air off, START released")
    T.check(r.max_egt < LIMIT.PW, string.format("P&W hot start under the autostart: at most %.1f °C, under the start limit 535", r.max_egt))
    T.check(r.caution_t and l2 and r.caution_t - l2.t < 3, "P&W hot start: ENG 1 AUTOSTART at the second hot start (" .. fmt(r.caution_t) .. " s)")
    local n2_abort = r.e.n2
    run(r, 10)
    T.check(not r.e.burning and r.e.n2 < n2_abort - 5, string.format("P&W hot start abort: the engine does not motor (N2 %.1f, 10 s after %.1f)", r.e.n2, n2_abort))
    r.inp.fuel_control[1] = false
    out = run(r, 1)
    T.check(not out.msg.autostart[1] and out.eng[1].phase == S.OFF, "P&W hot start: CUTOFF clears ENG 1 AUTOSTART")
    print(string.format("  P&W 15 °C autostart, HOT START: light-off at %.1f s (N2 %.1f), 510 after %.2f s (N2 %.1f), 2nd light-off %.1f s later, 510 after %.2f s, abort at %.1f s, max %.1f °C",
        l1.t, l1.n2, l1.hot, l1.hot_n2, l2.t - l1.t, l2.hot, r.caution_t, r.max_egt))
end

-- ======== GE autostart with HOT START (570, FCOM p.880): the fuel cut,
-- the schedule adjusted and the fuel back (FUEL_CUT_S, ATA70_80 p.566-569),
-- 3 tries, then aborted with 30 s of motoring before the valves close
do
    local r, out = autostart("GE", 15, true)
    local o = out.eng[1]
    T.equal(#r.lights, 3, "GE hot start: three tries (FCOM p.880)")
    local all_hot, gaps_ok = true, true
    for i, l in ipairs(r.lights) do
        all_hot = all_hot and l.hot ~= nil and l.hot < 6 and l.hot_n2 < S.CUTOUT_N2
        if i > 1 then
            local gap = l.t - r.cuts[i - 1].t
            gaps_ok = gaps_ok and gap >= S.FUEL_CUT_S and gap < S.FUEL_CUT_S + 1
        end
    end
    T.check(all_hot, "GE hot start: each try hot (725 °C) a few seconds after its light-off, before the cutout")
    T.check(gaps_ok and #r.cuts >= 2, "GE hot start: the fuel off " .. S.FUEL_CUT_S .. " s between the tries")
    T.check(r.lights[2] and r.lights[2].both and r.lights[3] and r.lights[3].both, "GE hot start: the retries with both igniters")
    T.equal(o.phase, S.ABORTED, "GE hot start: aborted after the third")
    T.check(out.msg.autostart[1], "GE hot start: ENG 1 AUTOSTART (caution)")
    local last = r.lights[#r.lights]
    local cut = r.cuts[#r.cuts]
    T.check(cut and r.t - cut.t >= S.DRY_MOTOR_S - DT and r.t - cut.t < S.DRY_MOTOR_S + 1,
        "GE hot start abort: 30 s of motoring before the valves close (" .. fmt(cut and r.t - cut.t) .. " s)")
    T.check(not o.fuel and not o.start_cmd and not r.inp.start_sw[1], "GE hot start abort: fuel and start air off, START released")
    T.check(r.max_egt < LIMIT.GE, string.format("GE hot start under the autostart: at most %.1f °C, under the start limit 750", r.max_egt))
    T.check(r.caution_t and cut and math.abs(r.caution_t - cut.t) < 3 * DT, "GE hot start: ENG 1 AUTOSTART at the third hot start (" .. fmt(r.caution_t) .. " s)")
    print(string.format("  GE 15 °C autostart, HOT START: light-off at %.1f s, 725 after %.2f / %.2f / %.2f s from the light-offs, abort at %.1f s, valves closed at %.1f s, max %.1f °C",
        r.lights[1].t, r.lights[1].hot, r.lights[2].hot, last.hot, r.caution_t, r.t, r.max_egt))
end

-- ======== a manual start with HOT START: no EEC watching (FCOM p.882), the
-- crew's abort (FCOM p.185: the EGT quickly nears or exceeds the start
-- limit). Left alone the EGT passes the start limit and the fuel stays on;
-- at idle (N2 55 %) the engine is normal again
for _, kind in ipairs({"PW", "GE"}) do
    local r, out, fuel_always, burning_always = manual(kind, 15, true)
    local l = r.lights[1]
    T.check(l and l.hot and l.limit and l.limit < 8,
        string.format("%s manual start, HOT START: %d °C after %s s, the start limit %d after %s s",
            kind, HOT[kind], fmt(l and l.hot), LIMIT[kind], fmt(l and l.limit)))
    T.check(fuel_always and burning_always and #r.lights == 1, kind .. " manual start, HOT START: nothing cuts the fuel")
    T.check(r.max_egt > LIMIT[kind] + 50, string.format("%s manual start, HOT START: up to %.1f °C", kind, r.max_egt))
    T.equal(out.eng[1].phase, S.OFF, kind .. " manual start, HOT START: still ends at idle")
    T.near(r.egt, G.steady(kind, G.IDLE[kind][1], 15), 2, kind .. " manual start, HOT START: running, the idle's EGT again")
    print(string.format("  %s 15 °C manual start, HOT START: %d after %.2f s, %d after %.2f s, max %.1f °C",
        kind, HOT[kind], l.hot, LIMIT[kind], l.limit, r.max_egt))
end

-- ======== without the failure: autostarts and manual starts at 15, 40 and
-- 50 °C stay under the hot start and end at idle on the first try
for _, kind in ipairs({"PW", "GE"}) do
    local peaks = {}
    for _, oat in ipairs({15, 40, 50}) do
        local r, out = autostart(kind, oat, false)
        local o = out.eng[1]
        T.check(r.max_egt < HOT[kind] and o.phase == S.OFF and o.attempt == 1 and #r.lights == 1 and not out.msg.autostart[1],
            string.format("%s autostart at %d °C: at most %.1f °C, under %d; one try, at idle", kind, oat, r.max_egt, HOT[kind]))
        local r2, out2 = manual(kind, oat, false)
        T.check(r2.max_egt < HOT[kind] and out2.eng[1].phase == S.OFF and #r2.lights == 1,
            string.format("%s manual start at %d °C: at most %.1f °C, under %d", kind, oat, r2.max_egt, HOT[kind]))
        peaks[#peaks + 1] = string.format("%d °C %.1f/%.1f", oat, r.max_egt, r2.max_egt)
    end
    print(string.format("  %s starts without the failure, autostart/manual peaks: %s (hot start %d)", kind, table.concat(peaks, ", "), HOT[kind]))
end

T.done()
