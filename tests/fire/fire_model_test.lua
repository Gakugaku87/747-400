-- Run from the repository root with LuaJIT: luajit tests/fire/fire_model_test.lua
-- The fire protection model (plugins/xtlua/scripts/B747.35.xt.fire/B747.35.fire_model.lua)
-- against FCOM 8.10-8.30 and ATA26_28 26-11 to 26-27: the dual loop
-- detectors and their single loop operation, the fire switches' lock, the
-- shared engine bottles, the APU shutdown and automatic discharge, the
-- FIRE/OVHT TEST, the cargo smoke detection and discharge sequence, the
-- wheel well, duct leak and smoke detectors, and the squib test.
local T = dofile("tests/lib/check.lua")("fire_model")
local M = dofile("plugins/xtlua/scripts/B747.35.xt.fire/B747.35.fire_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
        out = M.update(s, inp, DT)
        -- the commands last one frame
        for n = 1, 4 do inp.eng_toggle[n], inp.eng_override[n], inp.eng_rotate[n] = false, false, 0 end
        inp.apu_toggle, inp.apu_override, inp.apu_rotate = false, false, 0
    end
    return out
end
local FIRE1, OVHT1, APU = M.ENG_FIRE + 1, M.ENG_OVHT + 1, M.APU

-- a new flight: nothing detected, full bottles, the switches locked in
do
    local s, inp = M.new(), M.inputs()
    local out = run(s, inp, 1)
    T.check(not out.alarm[FIRE1] and not out.eng_light[1] and not out.apu_light, "no fire: no alarm, no light")
    for b = 1, M.APU_BTL do T.equal(out.btl_psi[b], 600, "bottle " .. b .. ": 600 psi (ATA26_28 p.60)") end
    for b = M.CGO_A, M.CGO_A + 3 do T.equal(out.btl_psi[b], 360, "cargo bottle " .. b .. ": 360 psi (ATA26_28 p.170)") end
    T.check(not out.unlocked[1], "no fire, RUN: fire switch 1 locked (FCOM p.905)")
    inp.eng_toggle[1] = true
    out = run(s, inp, 0.1)
    T.check(not out.pulled[1], "locked: pulling does nothing")
    T.check(not out.test_in_prog and not out.test_pass and not out.test_fail, "no test message")
end

-- an engine fire: both loops alarm; FIRE ENG 1, the light, the switch
-- unlocked; pulled and rotated to A, bottle L A empties into engine 1;
-- engine 2's squib on the same bottle finds it empty (FCOM p.905, p.916;
-- ATA26_28 p.64, p.70-76)
do
    local s, inp = M.new(), M.inputs()
    inp.eng_fire_heat[1] = true
    local out = run(s, inp, 0.1)
    T.check(out.alarm[FIRE1] and out.fire[FIRE1], "engine 1 fire: detected (both loops)")
    T.check(out.eng_light[1], "engine 1 fire: fire switch and FUEL CONTROL light")
    T.check(not out.fire[M.ENG_FIRE + 2], "engine 2: nothing")
    T.check(out.unlocked[1] and not out.unlocked[2], "fire switch 1 unlocked, 2 locked")
    inp.eng_toggle[1] = true
    out = run(s, inp, 0.1)
    T.check(out.pulled[1], "fire switch 1 pulled")
    inp.eng_rotate[1] = -1   -- engine 1: counterclockwise to A
    out = run(s, inp, 0.1)
    T.equal(out.rot[1], -1, "fire switch 1 rotated to A")
    T.check(out.extinguish[1], "bottle L A discharging into engine 1")
    T.check(out.btl_psi[1] < 600 and out.btl_psi[1] > 0, "bottle L A emptying")
    out = run(s, inp, 2)
    T.check(not out.extinguish[1], "1.5 s: the agent is out")
    T.equal(out.btl_psi[1], 0, "bottle L A empty")
    T.check(out.btl_low[1] and not out.btl_low[2], "BTL DISCH L A, not L B")
    -- engine 2 on the same (empty) bottle A, then bottle B
    inp.fuel_cutoff[2] = true
    out = run(s, inp, 0.1)
    T.check(out.unlocked[2], "FUEL CONTROL 2 CUTOFF: fire switch 2 unlocked (FCOM p.916)")
    inp.eng_toggle[2] = true
    run(s, inp, 0.1)
    inp.eng_rotate[2] = 1    -- engine 2: clockwise to A
    out = run(s, inp, 0.1)
    T.check(not out.extinguish[2], "engine 2 to A: bottle L A already empty")
    inp.eng_rotate[2] = -1
    out = run(s, inp, 0.1)
    T.equal(out.rot[2], 0, "fire switch 2 back to the middle")
    inp.eng_rotate[2] = -1
    out = run(s, inp, 0.1)
    T.check(out.extinguish[2], "engine 2 to B: bottle L B into engine 2")
    out = run(s, inp, 2)
    T.check(out.btl_low[2] and not out.btl_low[3], "BTL DISCH L B; the right wing's bottles full")
    -- a switch rotated cannot be pushed in; centred it can
    inp.eng_toggle[2] = true
    out = run(s, inp, 0.1)
    T.check(out.pulled[2], "rotated: the switch stays out")
    inp.eng_rotate[2] = 1
    run(s, inp, 0.1)
    inp.eng_toggle[2] = true
    out = run(s, inp, 0.1)
    T.check(not out.pulled[2], "centred: pushed back in")
    -- the fire out: the detector stops, the switch stays out
    inp.eng_fire_heat[1] = false
    out = run(s, inp, 0.1)
    T.check(not out.alarm[FIRE1] and not out.eng_light[1] and out.pulled[1], "fire out: light out, switch 1 still out")
end

-- the Fire Override unlocks a locked switch; no main hot battery bus: no
-- unlock and no squib
do
    local s, inp = M.new(), M.inputs()
    inp.eng_override[3] = true
    local out = run(s, inp, 0.1)
    T.check(out.pulled[3], "Fire Override 3: switch 3 pulled without a fire (FCOM p.906)")
    inp.hot_bat = false
    inp.eng_rotate[3] = -1
    out = run(s, inp, 0.1)
    T.check(not out.extinguish[3] and out.btl_psi[3] == 600, "no hot battery bus: the squib does not fire")
    inp.eng_fire_heat[4] = true
    out = run(s, inp, 0.1)
    T.check(not out.unlocked[4] and out.eng_light[4], "no hot battery bus: fire 4 lit but switch 4 locked")
end

-- single loop operation and >DET FIRE/OHT (FCOM p.914, p.919, p.921;
-- ATA26_28 p.25-26, p.34, p.46)
do
    local s, inp = M.new(), M.inputs()
    inp.loop_failed_a[FIRE1] = true
    local out = run(s, inp, 1)
    T.check(not out.det_failed[FIRE1], "loop A failed: no >DET (loop B left)")
    inp.eng_fire_heat[1] = true
    out = run(s, inp, 0.1)
    T.check(out.fire[FIRE1], "loop A failed: loop B alone detects the fire")
    inp.loop_failed_b[FIRE1] = true
    out = run(s, inp, 0.1)
    T.check(not out.fire[FIRE1] and out.det_failed[FIRE1], "both loops failed: no detection, >DET FIRE/OHT 1")
    -- STATUS loop messages after 20 s
    inp.eng_fire_heat[1] = false
    inp.loop_failed_b[FIRE1] = false
    s = M.new()
    out = run(s, inp, 19.5)
    T.check(not out.lp_a[FIRE1], "STATUS ENG 1 FIRE LP A: not before 20 s")
    out = run(s, inp, 1)
    T.check(out.lp_a[FIRE1] and not out.lp_b[FIRE1], "STATUS ENG 1 FIRE LP A after 20 s (ATA26_28 p.46)")
    -- an overheat with one loop: OVHT, the overheat detector
    inp.eng_ovht_heat[1] = true
    out = run(s, inp, 0.1)
    T.check(out.fire[OVHT1] and not out.fire[FIRE1], "engine 1 overheat: the overheat detector only")
end

-- the APU (FCOM p.897, p.907, p.913-914; ATA26_28 p.93-94, p.104-111,
-- p.124): either loop; the APU shuts down; on the ground the bottle
-- discharges by itself 10 s after the APU is below 95 %
do
    local s, inp = M.new(), M.inputs()
    inp.loop_failed_a[APU] = true
    inp.apu_fire_heat = true
    inp.apu_n1 = 100
    local out = run(s, inp, 0.1)
    T.check(out.fire[APU] and out.apu_light, "APU fire with loop A failed: loop B detects it")
    T.check(out.apu_shutdown, "APU fire: APU shutdown")
    T.check(out.apu_horn, "on the ground: the APU fire horn")
    out = run(s, inp, 15)
    T.check(not out.apu_extinguish and out.btl_psi[M.APU_BTL] == 600, "APU at 100 %: no automatic discharge")
    inp.apu_n1 = 90
    out = run(s, inp, 9.8)
    T.check(out.btl_psi[M.APU_BTL] == 600, "below 95 %: not before 10 s")
    out = run(s, inp, 0.3)
    T.check(out.apu_extinguish, "10 s below 95 %: the APU bottle discharges by itself")
    out = run(s, inp, 2)
    T.check(out.btl_low[M.APU_BTL], "APU BTL DISCH")
    -- in flight: no automatic discharge
    local s2, inp2 = M.new(), M.inputs()
    inp2.on_ground, inp2.apu_fire_heat = false, true
    out = run(s2, inp2, 15)
    T.check(out.apu_shutdown and out.btl_psi[M.APU_BTL] == 600, "in flight: shutdown, no automatic discharge")
    T.check(not out.apu_horn, "in flight: no horn")
    -- the APU fire switch: unlocked by the fire, pulled (horn off), rotated
    T.check(out.apu_unlocked, "APU fire: APU fire switch unlocked")
    inp2.apu_toggle = true
    out = run(s2, inp2, 0.1)
    T.check(out.apu_pulled, "APU fire switch pulled")
    inp2.apu_rotate = 1
    out = run(s2, inp2, 0.1)
    T.check(out.apu_extinguish, "rotated: the APU bottle discharges")
    -- the APU fire switch pulled without a fire shuts the APU down
    local s3, inp3 = M.new(), M.inputs()
    inp3.apu_override = true
    out = run(s3, inp3, 0.1)
    T.check(out.apu_pulled and out.apu_shutdown, "APU Fire Override: switch out, APU shutdown")
    -- both APU loops failed
    inp3.loop_failed_a[APU], inp3.loop_failed_b[APU] = true, true
    out = run(s3, inp3, 0.1)
    T.check(out.det_failed[APU], ">DET FIRE APU")
end

-- FIRE/OVHT TEST (FCOM p.910, p.919; ATA26_28 p.30, p.42, p.94, p.124):
-- every detector alarms (lights, switches unlocked), no FIRE detected,
-- TEST IN PROG, after 5 s PASS (or FAIL with a loop failed); released, all
-- clear; the test does not shut the APU down or discharge
do
    local s, inp = M.new(), M.inputs()
    inp.test = true
    local out = run(s, inp, 0.1)
    for n = 1, 4 do T.check(out.eng_light[n] and out.unlocked[n], "test: fire switch " .. n .. " lit and unlocked") end
    T.check(out.apu_light and out.apu_unlocked, "test: APU light, APU switch unlocked")
    T.check(not out.fire[FIRE1] and not out.fire[APU], "test: no fire detected (no FIRE message)")
    T.check(not out.apu_shutdown, "test: the APU keeps running")
    T.check(out.apu_horn, "test on the ground: the APU horn")
    T.check(out.test_in_prog and not out.test_pass, "TEST IN PROG")
    out = run(s, inp, 4.8)
    T.check(out.test_in_prog, "4.9 s: still TEST IN PROG")
    out = run(s, inp, 0.3)
    T.check(out.test_pass and not out.test_in_prog and not out.test_fail, "5 s: FIRE TEST PASS")
    inp.test = false
    out = run(s, inp, 0.1)
    T.check(not out.test_pass and not out.eng_light[1], "released: all clear")
    -- a loop failed: FAIL
    inp.loop_failed_b[M.ENG_OVHT + 3] = true
    inp.test = true
    out = run(s, inp, 5.2)
    T.check(out.test_fail and not out.test_pass, "a loop failed: FIRE TEST FAIL (FCOM p.919)")
    T.check(out.alarm[M.ENG_OVHT + 3], "the overheat detector 3 still answers on loop A")
    -- released before 5 s: the test ends without completing
    inp.test = false
    run(s, inp, 0.1)
    inp.loop_failed_b[M.ENG_OVHT + 3] = false
    inp.test = true
    out = run(s, inp, 2)
    inp.test = false
    out = run(s, inp, 0.1)
    T.check(not out.test_in_prog and not out.test_pass and not out.test_fail, "released at 2 s: no result")
    -- no detection power: no alarm, FAIL, STATUS FIRE/OVHT SYS after 20 s
    inp.det_power, inp.test = false, true
    out = run(s, inp, 5.2)
    T.check(not out.eng_light[1] and out.test_fail, "no detection power: no light, FIRE TEST FAIL")
    inp.test = false
    out = run(s, inp, 15)
    T.check(out.sys_power, "STATUS FIRE/OVHT SYS after 20 s without power (ATA26_28 p.34)")
    T.check(not out.det_failed[FIRE1], "no power: no >DET")
end

-- the same discharge over different frame rates
do
    local function after(dt)
        local s, inp = M.new(), M.inputs()
        inp.eng_override[4] = true
        M.update(s, inp, dt)
        inp.eng_override[4] = false
        inp.eng_rotate[4] = 1    -- engine 4: clockwise to A (bottle R A)
        M.update(s, inp, dt)
        inp.eng_rotate[4] = 0
        local out
        for _ = 1, math.floor(0.8 / dt + 0.5) do out = M.update(s, inp, dt) end
        return out.btl_psi[3]
    end
    T.near(after(1 / 20), after(1 / 60), 25, "20 and 60 fps: the same bottle pressure after 0.8 s")
end

-- the lower cargo compartments (FCOM p.908, p.914, p.917, p.921; ATA26_28
-- p.140-198): smoke in a zone with both detectors; FIRE CARGO FWD, the
-- light; armed and DISCH, A and B at once and C and D 30 min later in
-- flight; the DISCH light; >CGO BTL DISCH in flight with A and B
-- discharged
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    run(s, inp, 0.1)
    inp.cargo_smoke[2] = true
    local out = run(s, inp, 0.1)
    T.check(out.cargo_fire[1] and out.cargo_light[1], "smoke in zone 2: FIRE CARGO FWD and the FWD light")
    T.check(not out.cargo_fire[2], "no FIRE CARGO AFT")
    -- no airflow through the detectors: the smoke is not drawn in (estimate)
    inp.cargo_airflow = false
    out = run(s, inp, 0.1)
    T.check(not out.cargo_fire[1], "no venturi airflow: the smoke is not detected")
    T.check(out.cargo_det_air, "two engines running, no airflow: >CARGO DET AIR (ATA26_28 p.144)")
    inp.engines_running = 1
    out = run(s, inp, 0.1)
    T.check(not out.cargo_det_air, "one engine running: >CARGO DET AIR inhibited")
    inp.cargo_airflow, inp.engines_running = true, 4
    -- DISCH without ARM: nothing
    inp.cargo_disch = true
    run(s, inp, 0.1)
    inp.cargo_disch = false
    out = run(s, inp, 0.1)
    T.check(out.btl_psi[M.CGO_A] == 360, "DISCH without ARM: no bottle")
    -- ARM FWD, DISCH: A and B into the forward compartment
    inp.cargo_arm[1] = true
    inp.cargo_disch = true
    out = run(s, inp, 0.1)
    T.check(out.cargo_agent[1] and not out.cargo_agent[2], "ARM FWD, DISCH: agent into the forward compartment")
    inp.cargo_disch = false
    out = run(s, inp, 2)
    T.check(out.btl_low[M.CGO_A] and out.btl_low[M.CGO_A + 1], "A and B discharged at once")
    T.check(not out.btl_low[M.CGO_A + 2] and not out.btl_low[M.CGO_A + 3], "C and D not yet")
    T.check(out.cargo_disch_light, "CARGO FIRE DISCH light (FCOM p.908)")
    T.check(out.cgo_btl_disch, "in flight, A and B discharged: >CGO BTL DISCH (FCOM p.921)")
    out = run(s, inp, 1795)
    T.check(out.btl_psi[M.CGO_A + 2] == 360, "29 min 57 s: C not yet")
    out = run(s, inp, 10)
    T.check(out.btl_psi[M.CGO_A + 2] < 360, "30 min: C and D metering into the forward compartment")
    out = run(s, inp, 1200)
    T.check(out.btl_psi[M.CGO_A + 3] > 0 and out.btl_psi[M.CGO_A + 3] < 300, "20 min later: D low, still metering (2 h)")
end
-- landing before 30 min: C and D at touchdown; on the ground all four at once
do
    local s, inp = M.new(), M.inputs()
    inp.on_ground = false
    inp.cargo_arm[2], inp.cargo_disch = true, true
    run(s, inp, 0.1)
    inp.cargo_disch = false
    local out = run(s, inp, 600)
    T.check(out.btl_psi[M.CGO_A + 2] == 360, "10 min in flight: C not yet")
    inp.on_ground = true
    out = run(s, inp, 0.5)
    T.check(out.btl_psi[M.CGO_A + 2] < 360, "touchdown: C and D discharge")
    local s2, inp2 = M.new(), M.inputs()
    inp2.cargo_arm[1], inp2.cargo_disch = true, true
    out = run(s2, inp2, 0.5)
    T.check(out.btl_psi[M.CGO_A] < 360 and out.btl_psi[M.CGO_A + 2] < 360, "on the ground: A, B, C, D at once")
    out = run(s2, inp2, 2)
    T.check(out.cgo_btl_disch, "on the ground: >CGO BTL DISCH with a bottle low")
    -- both compartments armed: A and B into both, no lock-in (estimate)
    local s3, inp3 = M.new(), M.inputs()
    inp3.on_ground = false
    inp3.cargo_arm[1], inp3.cargo_arm[2], inp3.cargo_disch = true, true, true
    out = run(s3, inp3, 0.1)
    T.check(out.cargo_agent[1] and out.cargo_agent[2], "both armed: agent into both compartments")
    inp3.cargo_disch = false
    out = run(s3, inp3, 2000)
    T.check(out.btl_psi[M.CGO_A + 2] == 360, "both armed: C and D not released")
    -- a second DISCH with the bottles empty: no agent
    inp3.cargo_disch = true
    out = run(s3, inp3, 0.1)
    T.check(not out.cargo_agent[1], "A and B empty: a second DISCH gives no agent")
end
-- the cargo detectors reconfigure only at power-up and after a test
-- (ATA26_28 p.154, p.162): a loop failing in flight leaves the zone in dual
-- operation (no detection) until a test
do
    local s, inp = M.new(), M.inputs()
    run(s, inp, 0.1)
    local z = M.CARGO + 3
    inp.loop_failed_a[z] = true
    inp.cargo_smoke[3] = true
    local out = run(s, inp, 0.1)
    T.check(not out.cargo_fire[2], "loop A of zone 3 failed after power-up: still dual, no detection")
    inp.test = true
    out = run(s, inp, 5.2)
    T.check(out.test_fail, "the test finds it: FIRE TEST FAIL")
    inp.test = false
    out = run(s, inp, 0.1)
    T.check(out.cargo_fire[2], "after the test: single loop B, FIRE CARGO AFT")
    T.check(not out.cargo_det_status[2], "one loop: no CARGO DET AFT")
    inp.loop_failed_b[z] = true
    out = run(s, inp, 21)
    T.check(out.cargo_det_status[2], "both loops of zone 3: STATUS CARGO DET AFT after 20 s")
    -- power cycled: configured again
    local s2, inp2 = M.new(), M.inputs()
    inp2.det_power = false
    run(s2, inp2, 0.1)
    inp2.loop_failed_b[M.CARGO + 1] = true
    inp2.det_power = true
    inp2.cargo_smoke[1] = true
    out = run(s2, inp2, 0.1)
    T.check(out.cargo_fire[1], "power-up with loop B failed: single loop A detects")
end
-- the wheel well loop (AC bus 2), the duct leak switches, the lavatory and
-- crew rest smoke (FCOM p.613, p.619, p.922-923; ATA26_28 p.270-320)
do
    local s, inp = M.new(), M.inputs()
    inp.wheel_well_heat = true
    local out = run(s, inp, 0.1)
    T.check(out.wheel_well_fire, "FIRE WHEEL WELL")
    inp.wheel_well_power = false
    out = run(s, inp, 0.1)
    T.check(not out.wheel_well_fire, "no AC bus 2: no detection")
    inp.wheel_well_heat, inp.wheel_well_power = false, true
    inp.duct_leak[1] = true
    out = run(s, inp, 0.1)
    T.check(out.duct_leak[1] and not out.duct_leak[3], "BLD DUCT LEAK L")
    out = run(s, inp, 60)
    T.check(out.duct_leak_status[1] and not out.duct_leak_status[2], "STATUS BLD DUCT LEAK L after 60 s (ATA26_28 p.286)")
    inp.lav_smoke, inp.rest_smoke = true, true
    out = run(s, inp, 0.1)
    T.check(out.lav_smoke and out.rest_smoke, ">SMOKE LAVATORY, SMOKE DR 5 REST")
    -- the test without AC bus 2: FAIL
    inp.wheel_well_power, inp.test = false, true
    out = run(s, inp, 5.2)
    T.check(out.test_fail, "wheel well card without power: FIRE TEST FAIL")
    inp.wheel_well_power = true
    inp.test = false
    run(s, inp, 0.1)
    inp.test = true
    out = run(s, inp, 0.1)
    T.check(out.cargo_light[1] and out.cargo_light[2], "test: the cargo FWD and AFT lights")
    T.check(not out.wheel_well_fire and not out.cargo_fire[1], "test: no FIRE WHEEL WELL, no FIRE CARGO")
end
-- the squib test (FCOM p.187-188; ATA26_28 p.80-82, p.132-134, p.196-198)
do
    local s, inp = M.new(), M.inputs()
    inp.squib_test[1] = true
    local out = run(s, inp, 0.1)
    for i = 1, 9 do T.check(out.squib_light[i], "TEST 1: squib light " .. i) end
    -- engine 1's bottle A squib fired: its light stays dark on TEST 1
    inp.squib_test[1] = false
    inp.eng_override[1] = true
    run(s, inp, 0.1)
    inp.eng_rotate[1] = -1
    run(s, inp, 0.1)
    inp.squib_test[1] = true
    out = run(s, inp, 0.1)
    T.check(not out.squib_light[1] and out.squib_light[2], "squib L A for engine 1 fired: light 1 dark, light 2 lit")
    inp.squib_test[1], inp.squib_test[2] = false, true
    out = run(s, inp, 0.1)
    T.check(out.squib_light[1], "TEST 2: engine 1's bottle B squib lit")
    -- cargo armed: A and B not tested
    inp.cargo_arm[1] = true
    out = run(s, inp, 0.1)
    T.check(not out.squib_light[6] and not out.squib_light[7] and out.squib_light[8], "cargo armed: A, B not tested, C tested")
    inp.hot_bat = false
    out = run(s, inp, 0.1)
    T.check(not out.squib_light[3], "no main hot battery bus: no squib light")
end

T.done()
