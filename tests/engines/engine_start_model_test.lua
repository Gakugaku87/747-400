-- Run from the repository root with LuaJIT: luajit tests/engines/engine_start_model_test.lua
-- The engine start model (plugins/xtlua/scripts/B747.40.xt.engines/
-- B747.40.engine_start_model.lua) against FCOM 7.13, 7.20, 7.40 (p.859-902)
-- and ATA70_80: manual and auto starts, the autostart's light-off, hot and
-- hung start checks, retries and aborts, in-flight starts, ignition and its
-- power, the engine fuel valve and the start messages. A stand-in engine
-- (N2, EGT, light-off) answers the starter, the fuel and the igniters.
local T = dofile("tests/lib/check.lua")("engine_start_model")
local S = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua")

local DT = 0.1
-- the stand-in engine: the starter turns N2 at 0.85 %/s (as X-Plane's did in
-- s00), fuel and a powered igniter light it above 10 % N2, then it
-- accelerates to about 68 % idle; faults: no light-off, hot, hung
local function engine()
    return {n2 = 0, egt = 15, burning = false, fault = nil}
end
local function step(e, starter, fuel, igniter, dt)
    if fuel and e.burning then
        -- keeps burning
    elseif fuel and igniter and e.n2 > 10 and e.fault ~= "no_light" then
        e.burning = true
    elseif not fuel then
        e.burning = false
    end
    if e.burning then
        local target = (e.fault == "hung") and 40 or 68
        local rate = e.n2 < 50 and 1.2 or 0.6
        if e.n2 < target then e.n2 = math.min(target, e.n2 + rate * dt) end
        local egt_target = (e.fault == "hot") and 800 or ((e.n2 < 50) and 480 or 320)
        e.egt = e.egt + (egt_target - e.egt) * math.min(1, dt / 3)
    else
        if starter then e.n2 = math.min(30, e.n2 + 0.85 * dt)
        else e.n2 = math.max(0, e.n2 - 1.0 * dt) end
        e.egt = e.egt + (15 - e.egt) * math.min(1, dt / 10)
    end
end

-- powered on the ground, PW unless told
local function setup(kind)
    local s, inp = S.new(), S.inputs()
    inp.type = kind or "PW"
    inp.ac1, inp.ac3, inp.ac_stby, inp.main_bat, inp.apu_bat = true, true, true, true, true
    return s, inp
end
-- run engine 1 for some seconds; the start valve follows its command (a
-- bleed system with enough air) unless told
local function run(s, inp, e, seconds, valve_stuck)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = S.update(s, inp, DT)
        local o = out.eng[1]
        if valve_stuck ~= nil then inp.start_valve[1] = valve_stuck else inp.start_valve[1] = o.start_cmd end
        if o.release_start_sw then inp.start_sw[1] = false end
        step(e, o.starter, o.fuel, o.ignition, DT)
        inp.n2[1], inp.egt[1], inp.burning[1] = e.n2, e.egt, e.burning
        inp.spar_valve[1] = inp.fuel_control[1] and 1 or 0
    end
    return out
end

-- manual start, AUTOSTART OFF (FCOM p.882, p.185): START pulled motors; RUN
-- at the fuel-on speed gives fuel and an igniter; 50 % cuts the starter out
do
    local s, inp = setup("PW")
    inp.autostart = false
    inp.auto_sel = S.AUTO_1
    local e = engine()
    inp.start_sw[1] = true
    local out = run(s, inp, e, 10)
    T.check(out.eng[1].start_cmd and out.eng[1].starter, "manual: START pulled opens the start valve, the starter turns")
    T.check(not out.eng[1].fuel and not out.eng[1].ignition, "manual: no fuel or ignition before RUN")
    T.check(out.msg.autostart_off, "AUTOSTART OFF: >AUTOSTART OFF (109, FCOM p.899)")
    run(s, inp, e, 14)                                -- about 20 % N2
    inp.fuel_control[1] = true
    out = run(s, inp, e, 1)
    T.check(out.eng[1].fuel and out.eng[1].ignition, "manual: RUN gives fuel and ignition")
    T.check(out.eng[1].igniter1 and not out.eng[1].igniter2, "manual, AUTOSTART OFF, AUTO IGNITION 1: igniter 1 only")
    out = run(s, inp, e, 30)
    T.check(e.n2 > 50 and not inp.start_sw[1], "manual: the START switch drops at 50 % N2")
    T.check(not out.eng[1].starter and not out.eng[1].start_cmd, "manual: start valve and starter off after the cutout")
    T.check(not out.eng[1].ignition, "manual: the start ignition ends at the cutout")
    out = run(s, inp, e, 40)
    T.equal(out.eng[1].phase, S.OFF, "manual: the start ends at idle")
    T.check(out.eng[1].fuel, "manual: fuel stays on")
    for _, k in ipairs({"start_vlv", "starter_cutout", "fuel_vlv", "autostart", "fail", "shutdown"}) do
        T.check(not out.msg[k][1], "manual: no " .. k .. " message")
    end
end

-- ENG AUTOSTART with AUTOSTART OFF: RUN below the fuel-on speed (FCOM p.899)
do
    local s, inp = setup("PW")
    inp.autostart = false
    local e = engine()
    inp.start_sw[1] = true
    run(s, inp, e, 5)                                 -- about 4 % N2
    inp.fuel_control[1] = true
    local out = run(s, inp, e, 1)
    T.check(out.msg.autostart[1], "AUTOSTART OFF and RUN below the fuel-on N2: ENG 1 AUTOSTART")
end

-- autostart (FCOM p.879): START arms, RUN starts; the EEC motors, puts fuel
-- and ignition on at the fuel-on speed, cuts out at 50 % and ends at idle
for _, kind in ipairs({"GE", "PW"}) do
    local s, inp = setup(kind)
    local e = engine()
    inp.start_sw[1] = true
    local out = run(s, inp, e, 3)
    T.check(not out.eng[1].start_cmd, kind .. " autostart: START alone only arms (no valve before RUN)")
    inp.fuel_control[1] = true
    out = run(s, inp, e, 2)
    T.check(out.eng[1].start_cmd and out.eng[1].phase == S.MOTOR, kind .. " autostart: RUN opens the start valve, motoring")
    T.check(not out.eng[1].fuel and not out.eng[1].ignition, kind .. " autostart: no fuel while motoring")
    T.equal(out.eng[1].fuel_valve, 1, kind .. " autostart: the engine fuel valve (HPSOV) opens with RUN")
    out = run(s, inp, e, S.FUEL_ON_N2[kind] / 0.85 - 1)
    T.check(out.eng[1].fuel and out.eng[1].ignition, kind .. " autostart: fuel and ignition at " .. S.FUEL_ON_N2[kind] .. " % N2")
    out = run(s, inp, e, 40)
    T.check(not inp.start_sw[1] and not out.eng[1].start_cmd, kind .. " autostart: cutout at 50 % N2")
    T.check(not out.eng[1].ignition, kind .. " autostart: the start ignition ends at the cutout (FCOM p.879)")
    out = run(s, inp, e, 40)
    T.equal(out.eng[1].phase, S.OFF, kind .. " autostart: complete at idle")
    T.check(out.eng[1].fuel and not out.msg.autostart[1], kind .. " autostart: running, no ENG AUTOSTART")
    T.check(not out.msg.autostart_off, kind .. " autostart: no >AUTOSTART OFF with the switch ON")
end

-- no light-off: 30 s motoring and a retry with both igniters; GE gives up
-- after 3 tries (motoring 30 s, then the valves close), 109 after 2 without
-- motoring (FCOM p.880-881)
for _, kind in ipairs({"GE", "PW"}) do
    local s, inp = setup(kind)
    local e = engine()
    e.fault = "no_light"
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out = run(s, inp, e, S.FUEL_ON_N2[kind] / 0.85 + S.LIGHT_OFF_S[kind][1] + 1)
    T.equal(out.eng[1].phase, S.DRY, kind .. " no light-off: dry motoring after the first window")
    T.check(not out.eng[1].fuel and not out.eng[1].ignition and out.eng[1].starter, kind .. " no light-off: fuel and ignition off, still motoring")
    out = run(s, inp, e, S.DRY_MOTOR_S + 1)
    T.check(out.eng[1].phase == S.LIGHT and out.eng[1].igniter1 and out.eng[1].igniter2, kind .. " no light-off: retry with both igniters")
    out = run(s, inp, e, 200)
    T.equal(out.eng[1].phase, S.ABORTED, kind .. " no light-off: aborted after " .. S.ATTEMPTS[kind] .. " tries")
    T.check(not inp.start_sw[1] and not out.eng[1].start_cmd and not out.eng[1].fuel, kind .. " abort: START released, valve closed, no fuel")
    T.check(out.msg.autostart[1], kind .. " abort: ENG 1 AUTOSTART (caution)")
    inp.fuel_control[1] = false
    out = run(s, inp, e, 1)
    T.check(not out.msg.autostart[1] and out.eng[1].phase == S.OFF, kind .. " abort: CUTOFF clears it")
end

-- hot start before the cutout: GE cuts the fuel and puts it back, 3 tries;
-- 109 motors 30 s and retries, 2 tries (FCOM p.880-881)
do
    local s, inp = setup("GE")
    local e = engine()
    e.fault = "hot"
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out
    local saw_dry, saw_retry = false, false
    for _ = 1, 600 do
        out = run(s, inp, e, 0.1)
        if out.eng[1].phase == S.DRY and out.eng[1].attempt == 2 then saw_dry = true end
        if out.eng[1].attempt == 2 and out.eng[1].phase == S.LIGHT then saw_retry = true end
        if out.eng[1].phase == S.ABORTED then break end
    end
    T.check(saw_dry and saw_retry, "GE hot start: fuel cut briefly and put back")
    T.check(out.msg.autostart[1], "GE hot start: aborted after 3 tries, ENG 1 AUTOSTART")
end
do
    local s, inp = setup("PW")
    local e = engine()
    e.fault = "hung"
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out = run(s, inp, e, 100)
    T.equal(out.eng[1].phase, S.ABORTED, "109 hung start: aborted at once (no motoring, no retry)")
    T.equal(out.eng[1].attempt, 1, "109 hung start: one try only")
end

-- in the air the autostart never aborts: a hung start gets the fuel cut and
-- put back, and goes on until idle or CUTOFF (FCOM p.881)
do
    local s, inp = setup("GE")
    inp.on_ground = false
    local e = engine()
    e.fault = "hung"
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out = run(s, inp, e, 300)
    T.check(out.eng[1].phase ~= S.ABORTED and not out.msg.autostart[1], "in-flight start: no abort, no ENG AUTOSTART")
    T.check(out.eng[1].igniter1 and out.eng[1].igniter2 or out.eng[1].phase == S.DRY, "in-flight start: both igniters")
    T.check(out.msg.fail[1], "in-flight start below 52 % N2: ENG 1 FAIL (caution)")
    -- (the FMC's step 9h3) the engine inoperative for the FMC, the AFDS and
    -- the A/T: below the ENG FAIL speed, on the ground too
    T.check(out.eng[1].inop, "below 52 % N2: inoperative")
    inp.n2[1], inp.burning[1] = 80, true
    out = S.update(s, inp, 0.1)
    T.check(not out.eng[1].inop, "80 % N2: not inoperative")
    inp.on_ground = true
    inp.n2[1], inp.burning[1] = 20, false
    out = S.update(s, inp, 0.1)
    T.check(out.eng[1].inop and not out.msg.fail[1], "on the ground at 20 % N2: inoperative (ENG FAIL inhibited there)")
end

-- ignition conditions and power (FCOM p.862-864, p.882-883)
do
    local s, inp = setup("PW")
    inp.fuel_control[1] = true
    local e = engine()
    e.n2, e.burning = 68, true
    inp.n2[1], inp.burning[1] = 68, true
    local out = run(s, inp, e, 1)
    T.check(not out.eng[1].ignition, "running: no ignition without a condition")
    inp.con = true
    out = run(s, inp, e, 1)
    T.check(out.eng[1].ignition and out.msg.con_memo, "CON ON: ignition, CON IGNITION ON memo")
    inp.con = false
    inp.flaps_out = true
    out = run(s, inp, e, 1)
    T.check(out.eng[1].ignition, "TE flaps out of UP: ignition")
    inp.flaps_out = false
    inp.nai[1] = true
    out = run(s, inp, e, 1)
    T.check(out.eng[1].ignition and not out.eng[2].ignition, "NAI 1 ON: ignition on engine 1 only (engine 2 is CUTOFF)")
    inp.nai[1] = false
    inp.con = true
    inp.ac1, inp.ac3, inp.ac_stby = false, false, false
    out = run(s, inp, e, 1)
    T.check(not out.eng[1].ignition and out.msg.eng_ignition and not out.msg.con_memo, "CON ON without power: ENG IGNITION, no memo")
    inp.ac_stby = true
    out = run(s, inp, e, 1)
    T.check(out.eng[1].igniter1 and not out.eng[1].igniter2, "PW, no AC, STBY NORM: the standby feeds igniter 1")
    inp.type = "GE"
    out = run(s, inp, e, 1)
    T.check(out.eng[1].igniter1 and out.eng[1].igniter2, "GE, no AC, STBY NORM: the standby feeds both igniters")
    inp.type = "PW"
    inp.con = false
    inp.ac1, inp.ac3 = true, true
    inp.stby_sel = S.STBY_2
    out = run(s, inp, e, 1)
    T.check(out.eng[1].igniter2 and out.msg.stby_memo, "STBY 2: igniter 2 continuously, STBY IGNITION ON memo")
    inp.fuel_control[1] = false
    out = run(s, inp, e, 1)
    T.check(not out.eng[1].ignition, "CUTOFF: no ignition at all")
end

-- the engine fuel valve: RUN and the fire switch in, on the main battery bus
-- and latching; FUEL VLV after 5 s in disagreement (FCOM p.860, p.886, p.900)
do
    local s, inp = setup("PW")
    inp.autostart = false
    local e = engine()
    inp.fuel_control[1] = true
    local out = run(s, inp, e, 1)
    T.equal(out.eng[1].fuel_valve, 1, "fuel valve open with RUN")
    inp.main_bat = false
    inp.fuel_control[1] = false
    out = run(s, inp, e, 1)
    T.equal(out.eng[1].fuel_valve, 1, "no main battery bus: the valve stays open")
    out = run(s, inp, e, 5)
    T.check(out.msg.fuel_vlv[1], "valve not closing: ENG 1 FUEL VLV after 5 s")
    inp.main_bat, inp.fuel_control[1] = true, true
    run(s, inp, e, 1)
    inp.fire_out[1] = true
    out = run(s, inp, e, 1)
    T.equal(out.eng[1].fuel_valve, 0, "fire switch: fuel valve closed")
end

-- start valve messages (FCOM p.902, ATA70_80 p.558-559)
do
    local s, inp = setup("PW")
    inp.autostart = false
    local e = engine()
    inp.start_sw[1] = true
    local out = run(s, inp, e, 9, false)          -- no air: the valve stays closed
    T.check(out.msg.start_vlv[1], "start valve not opening: ENG 1 START VLV after 8 s")
    local s2, inp2 = setup("PW")
    inp2.autostart = false
    local e2 = engine()
    e2.n2, e2.burning = 60, true
    inp2.fuel_control[1] = true
    inp2.n2[1], inp2.burning[1] = 60, true
    out = run(s2, inp2, e2, 6, true)              -- the valve stuck open above 54 %
    T.check(out.msg.starter_cutout[1], "start valve stuck open: STARTER CUTOUT 1 after 5 s")
end

-- the START switch hold-in solenoid needs the APU battery bus (ATA70_80 p.554)
do
    local s, inp = setup("PW")
    inp.apu_bat = false
    local e = engine()
    inp.start_sw[1] = true
    local out = S.update(s, inp, DT)
    T.check(out.eng[1].release_start_sw, "no APU battery bus: the START switch does not stay out")
end

-- >ENG SHUTDOWN in the air with CUTOFF; 405 has no autostart (FCOM p.861, p.902)
do
    local s, inp = setup("PW")
    inp.on_ground = false
    local out = S.update(s, inp, DT)
    T.check(out.msg.shutdown[1], "air, CUTOFF: >ENG 1 SHUTDOWN")
    inp.on_ground = true
    out = S.update(s, inp, DT)
    -- (2026-11-12 review SF-3) on the ground too (FCOM p.902, p.1586-1587;
    -- ATA70_80 p.230); before, not on the ground (an estimate)
    T.check(out.msg.shutdown[1], "ground, CUTOFF: >ENG 1 SHUTDOWN too")
    inp.fuel_control[1] = true
    out = S.update(s, inp, DT)
    T.check(not out.msg.shutdown[1], "ground, RUN: no >ENG 1 SHUTDOWN")
    inp.fuel_control[1] = false
    inp.autostart_installed, inp.autostart = false, false
    out = S.update(s, inp, DT)
    T.check(not out.msg.autostart_off, "405 (no autostart): no >AUTOSTART OFF")
end

-- ======== (2026-11-10) the failure window's igniter failures
-- (laminar/B747/engines/fail/igniter, inp.ign_fail1/2): a failed igniter
-- does not fire, so X-Plane's ignition (o.ignition) comes only from a
-- working one; igniter1/igniter2 stay the selected and powered ones. With
-- one igniter selected for a ground start (AUTO IGNITION 1 or 2, GE SINGLE)
-- and that one failed, no light-off: the autostart's no EGT rise, 30 s of
-- motoring and the retry with both igniters (FCOM p.880-881 (7.20.10-11),
-- p.863 (7.13.5))

-- one start of engine 1 (START and RUN together), to its end or the abort;
-- the try it lit on, and for each try the igniters selected while it waited
-- for the light-off ("1", "2" or "12")
local function autostart_once(s, inp, e, seconds)
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out, lit_attempt
    local tries = {}
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = run(s, inp, e, DT)
        local o = out.eng[1]
        if e.burning and not lit_attempt then lit_attempt = o.attempt end
        if o.phase == S.LIGHT then
            tries[o.attempt] = (o.igniter1 and "1" or "") .. (o.igniter2 and "2" or "")
        end
        if o.phase == S.ABORTED or (o.phase == S.OFF and e.burning) then break end
    end
    return out, lit_attempt, tries
end
-- CUTOFF and spooled down
local function shut_down(s, inp, e)
    inp.fuel_control[1] = false
    run(s, inp, e, 80)
end

-- 109, AUTO IGNITION 1 with the autostart: the EEC alternates the igniters
-- every ground start (FCOM p.863), igniter 1 on the first (2026-11-10:
-- before, igniter 2 on the first, e.starts counted with the start under way)
do
    local s, inp = setup("PW")
    inp.auto_sel = S.AUTO_1
    inp.ign_fail1[1] = true
    local e = engine()
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out = run(s, inp, e, S.FUEL_ON_N2.PW / 0.85 + 1)
    local o = out.eng[1]
    T.check(o.phase == S.LIGHT and o.fuel and o.igniter1 and not o.igniter2 and not o.ignition and not e.burning,
        "109 SINGLE, igniter 1 failed: the first ground start selects igniter 1, fuel on, no spark, no light-off")
    out = run(s, inp, e, S.LIGHT_OFF_S.PW[1])
    o = out.eng[1]
    T.check(o.phase == S.DRY and not o.fuel and not o.ignition and o.starter and not e.burning,
        "109 SINGLE, igniter 1 failed: no light-off in 20 s, fuel and ignition off, motoring")
    out = run(s, inp, e, S.DRY_MOTOR_S - 1)
    T.check(out.eng[1].phase == S.DRY and not e.burning, "109 SINGLE, igniter 1 failed: still motoring after 29 s")
    out = run(s, inp, e, 2)
    o = out.eng[1]
    T.check(o.attempt == 2 and o.igniter1 and o.igniter2 and o.ignition and e.burning,
        "109 SINGLE, igniter 1 failed: after 30 s of motoring the retry with both igniters lights (igniter 2)")
    out = run(s, inp, e, 80)
    T.check(out.eng[1].phase == S.OFF and e.burning and not out.msg.autostart[1],
        "109 SINGLE, igniter 1 failed: the start completes at idle, no ENG AUTOSTART")
    shut_down(s, inp, e)
    local lit
    out, lit = autostart_once(s, inp, e, 150)
    T.check(out.eng[1].phase == S.OFF and e.burning and lit == 1,
        "109 SINGLE, igniter 1 failed: the second ground start (igniter 2) lights on the first try")
end
-- 109, AUTO IGNITION 1, igniter 2 failed: the first ground start (igniter 1)
-- lights on the first try
do
    local s, inp = setup("PW")
    inp.auto_sel = S.AUTO_1
    inp.ign_fail2[1] = true
    local e = engine()
    local out, lit = autostart_once(s, inp, e, 200)
    T.check(out.eng[1].phase == S.OFF and e.burning and lit == 1 and not out.msg.autostart[1],
        "109 SINGLE, igniter 2 failed: the first ground start (igniter 1) lights on the first try, completes")
end
-- both igniters of engine 1 failed: no light-off on either try; 109 aborts
-- after 2 without motoring, GE after 3 with 30 s of motoring; ENG 1
-- AUTOSTART (caution, FCOM p.899)
for _, kind in ipairs({"PW", "GE"}) do
    local s, inp = setup(kind)
    inp.auto_sel = S.AUTO_1
    inp.ign_fail1[1], inp.ign_fail2[1] = true, true
    local e = engine()
    local out, lit, tries = autostart_once(s, inp, e, 400)
    local o = out.eng[1]
    T.check(o.phase == S.ABORTED and o.attempt == S.ATTEMPTS[kind] and not lit and not e.burning,
        kind .. " both igniters failed: aborted after " .. S.ATTEMPTS[kind] .. " tries, never lit")
    local first = "1"
    T.check(#tries == S.ATTEMPTS[kind] and tries[1] == first and tries[2] == "12" and (tries[3] or "12") == "12",
        kind .. " both igniters failed: the first try on igniter " .. first .. ", the retries on both (" .. table.concat(tries, ", ") .. ")")
    T.check(out.msg.autostart[1], kind .. " both igniters failed: ENG 1 AUTOSTART")
    T.check(not o.fuel and not o.start_cmd and not inp.start_sw[1], kind .. " both igniters failed: fuel and start air off, START released")
    local n2 = e.n2
    run(s, inp, e, 5)
    T.check(e.n2 < n2 - 3, string.format("%s both igniters failed: no motoring after the abort (N2 %.1f to %.1f)", kind, n2, e.n2))
end
-- GE SINGLE (AUTO IGNITION 1 or 2): the EEC alternates after every second
-- ground start (FCOM p.863), igniter 1 on the first; igniter 1 failed
do
    local s, inp = setup("GE")
    inp.auto_sel = S.AUTO_1
    inp.ign_fail1[1] = true
    local e = engine()
    inp.start_sw[1], inp.fuel_control[1] = true, true
    local out = run(s, inp, e, S.FUEL_ON_N2.GE / 0.85 + 1)
    local o = out.eng[1]
    T.check(o.phase == S.LIGHT and o.igniter1 and not o.igniter2 and not o.ignition and not e.burning,
        "GE SINGLE, igniter 1 failed: the first ground start on igniter 1, no light-off")
    out = run(s, inp, e, S.LIGHT_OFF_S.GE[1] + S.DRY_MOTOR_S + 1)
    o = out.eng[1]
    T.check(o.attempt == 2 and o.igniter1 and o.igniter2 and e.burning,
        "GE SINGLE, igniter 1 failed: 20 s, 30 s of motoring, the retry with both igniters lights")
    out = run(s, inp, e, 80)
    T.check(out.eng[1].phase == S.OFF and e.burning and not out.msg.autostart[1], "GE SINGLE, igniter 1 failed: the start completes")
end
-- manual start (AUTOSTART OFF), AUTO IGNITION 1, igniter 1 failed: RUN gives
-- fuel and selects igniter 1, nothing lights, the EGT stays at the outside
-- air's (the crew's abort: no EGT rise in 20 s, FCOM p.185 (SP.7.3)); the
-- selector to 2 lights it
do
    local s, inp = setup("PW")
    inp.autostart = false
    inp.auto_sel = S.AUTO_1
    inp.ign_fail1[1] = true
    local e = engine()
    inp.start_sw[1] = true
    run(s, inp, e, 40)                                -- the maximum motoring, 30 %
    inp.fuel_control[1] = true
    local out = run(s, inp, e, 30)
    local o = out.eng[1]
    T.check(o.fuel and o.igniter1 and not o.igniter2 and not o.ignition and not e.burning,
        "manual, igniter 1 failed and selected: fuel on, no spark, no light-off in 30 s")
    T.near(e.egt, 15, 0.01, "manual, igniter 1 failed: the EGT stays at the outside air's")
    T.check(not out.msg.autostart[1] and o.phase == S.LIGHT, "manual, igniter 1 failed: no message, the model waits (the crew's abort)")
    inp.auto_sel = S.AUTO_2
    out = run(s, inp, e, 1)
    T.check(out.eng[1].igniter2 and out.eng[1].ignition and e.burning, "manual, igniter 1 failed: AUTO IGNITION 2 lights it")
end
-- ENG IGNITION watches the selection and the power, not the plugs: CON ON
-- with both igniters failed, no ignition reaches X-Plane, and no message
-- (FCOM p.900; estimate); the CON IGNITION ON memo stays
do
    local s, inp = setup("PW")
    inp.fuel_control[1] = true
    local e = engine()
    e.n2, e.burning = 68, true
    inp.n2[1], inp.burning[1] = 68, true
    inp.con = true
    inp.ign_fail1[1], inp.ign_fail2[1] = true, true
    local out = run(s, inp, e, 1)
    local o = out.eng[1]
    T.check(o.igniter1 and o.igniter2 and not o.ignition, "CON ON, both igniters failed: selected and powered, none firing")
    T.check(not out.msg.eng_ignition and out.msg.con_memo, "CON ON, both igniters failed: no ENG IGNITION, the CON IGNITION ON memo")
    inp.ign_fail2[1] = false
    out = run(s, inp, e, 1)
    T.check(out.eng[1].ignition, "CON ON, igniter 1 failed: igniter 2 fires")
end

T.done()
