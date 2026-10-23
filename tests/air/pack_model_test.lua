-- Run from the repository root with LuaJIT: luajit tests/air/pack_model_test.lua
-- The pack model (plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.pack_model.lua)
-- against FCOM 2.10-2.50 and ATA21: the valves and 12 psi, normal and high
-- flow and the schedule, one change at a time, the relief valves and cargo
-- fire ARM, the controllers A and B, trips and PACK RST, the recirculation
-- fans, and the messages.
local T = dofile("tests/lib/check.lua")("pack_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.pack_model.lua")

local DT = 1 / 30
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = P.update(s, inp, DT) end
    return out
end
-- on the ground, three packs NORM, the ducts at 30 psi
local function parked()
    local s, inp = P.new(), P.inputs()
    inp.duct_psi = {30, 30, 30}
    return s, inp
end
local function count_high(out)
    local n = 0
    for p = 1, 3 do if out.high[p] then n = n + 1 end end
    return n
end

-- the valves: open with the selector on and 12 psi, high flow on the ground
-- (ATA21 p.42, p.86)
do
    local s, inp = parked()
    local out = run(s, inp, 1)
    T.equal(out.packs_operating, 3, "parked: three packs operating")
    T.check(out.high[1] and out.high[2] and out.high[3], "parked: high flow on the ground (ATA21 p.86)")
    T.near(out.flow[1], P.HIGH, 1e-9, "parked: a pack at high flow takes 1.0")
    inp.duct_psi[2] = 11
    out = run(s, inp, 0.5)
    T.check(out.valve[2] < 1 and out.valve[2] > 0, "centre duct at 11 psi: pack 2's valve closing")
    out = run(s, inp, 3)
    T.equal(out.valve[2], 0, "centre duct at 11 psi: pack 2 closed (needs 12 psi)")
    T.equal(out.packs_operating, 2, "centre duct low: two packs operating")
    inp.duct_psi[2] = 30
    out = run(s, inp, 0.5)
    T.check(out.valve[2] > 0 and out.valve[2] < 1, "centre duct back: valve opening (3 s, estimate)")
    out = run(s, inp, 3)
    T.equal(out.valve[2], 1, "centre duct back: pack 2 open")
    inp.selector[1] = 0
    out = run(s, inp, 4)
    T.equal(out.valve[1], 0, "PACK 1 OFF: valve closed")
    T.equal(out.flow[1], 0, "PACK 1 OFF: no flow")
end

-- the schedule: normal in the cruise clamp, one pack every 15 s; high with
-- fewer than three packs, with HI FLOW (FCOM p.558, p.588; ATA21 p.86,
-- p.386-387)
do
    local s, inp = parked()
    inp.on_ground = false
    run(s, inp, 20)
    inp.cruise_clamp = true
    local out = run(s, inp, 0.1)
    T.equal(count_high(out), 2, "cruise clamp: the first pack goes to normal at once")
    T.near(out.flow[1], P.NORMAL, 1e-9, "cruise clamp: pack 1 first, at 2/3 of high (estimate: the order)")
    out = run(s, inp, 14)
    T.equal(count_high(out), 2, "cruise clamp: the next pack waits 15 s")
    out = run(s, inp, 1.2)
    T.equal(count_high(out), 1, "cruise clamp: the second pack after 15 s")
    out = run(s, inp, 15.5)
    T.equal(count_high(out), 0, "cruise clamp: all three normal after 30 s")
    inp.hi_flow = true
    out = run(s, inp, 0.1)
    T.equal(count_high(out), 3, "HI FLOW: all packs high at once (FCOM p.558)")
    inp.hi_flow = false
    out = run(s, inp, 0.1)
    T.check(count_high(out) >= 2, "HI FLOW off: back to normal one pack at a time, not all at once")
    out = run(s, inp, 46)
    T.equal(count_high(out), 0, "HI FLOW off: all normal within 45 s")
    inp.selector[3] = 0
    out = run(s, inp, 35)
    T.check(out.high[1] and out.high[2] and not out.operating[3], "a pack off in the clamp: the other two high (ATA21 p.86)")
    inp.selector[3] = 1
    out = run(s, inp, 40)
    T.equal(count_high(out), 0, "three packs again: normal")
    -- a failed fan in cruise: upper fans set pack 2 high, lower 1 pack 1,
    -- lower 2 pack 3 (ATA21 p.141); two failed fans set all high
    inp.fan_failed[1] = true
    out = run(s, inp, 20)
    T.check(out.high[2] and not out.high[1] and not out.high[3], "upper fan 1 failed in cruise: pack 2 high")
    inp.fan_failed[1], inp.fan_failed[3] = false, true
    out = run(s, inp, 35)
    T.check(out.high[1] and not out.high[2] and not out.high[3], "lower fan 1 failed in cruise: pack 1 high")
    inp.fan_failed[4] = true
    out = run(s, inp, 35)
    T.equal(count_high(out), 3, "two fans failed: all packs high")
end

-- the clamp's normal flow waits while the cabin is more than 1°C off its
-- target, at most 20 min (ATA21 p.386); the lower fans with it (estimate)
do
    local s, inp = parked()
    inp.on_ground = false
    run(s, inp, 20)
    inp.cruise_clamp, inp.temp_settled = true, false
    local out = run(s, inp, 60)
    T.equal(count_high(out), 3, "clamp, cabin off its target: packs stay high")
    T.check(not out.fan[3] and not out.fan[4], "clamp, cabin off its target: lower fans stay off")
    inp.temp_settled = true
    out = run(s, inp, 31)
    T.equal(count_high(out), 0, "cabin at its target: normal flow")
    T.check(out.fan[3] and out.fan[4], "cabin at its target: four fans")
    inp.cruise_clamp = false
    run(s, inp, 40)
    inp.cruise_clamp, inp.temp_settled = true, false
    out = run(s, inp, 19 * 60)
    T.equal(count_high(out), 3, "a new clamp, cabin off its target 19 min: still high")
    out = run(s, inp, 61 + 30)
    T.equal(count_high(out), 0, "after 20 min: normal flow anyway")
end

-- the relief valves shut pack 2 and set 1 and 3 high, PACK 2; back when
-- they close (FCOM p.609, p.620; ATA21 p.94)
do
    local s, inp = parked()
    inp.on_ground, inp.cruise_clamp = false, true
    run(s, inp, 60)
    inp.relief_open = true
    local out = run(s, inp, 4)
    T.equal(out.valve[2], 0, "relief open: pack 2 shut")
    T.check(out.high[1] and out.high[3], "relief open: packs 1 and 3 high")
    T.check(out.pack_alert[2], "relief open: PACK 2")
    inp.relief_open = false
    out = run(s, inp, 4)
    T.equal(out.valve[2], 1, "relief closed: pack 2 back")
    T.check(not out.pack_alert[2], "relief closed: no PACK 2")
end

-- cargo fire ARM: pack 3 off, packs 1 and 2 high, the fans off (FCOM p.908;
-- ATA21 p.94, p.134, p.141)
do
    local s, inp = parked()
    inp.on_ground, inp.cruise_clamp = false, true
    run(s, inp, 60)
    inp.cargo_fire_arm = true
    local out = run(s, inp, 4)
    T.equal(out.valve[3], 0, "cargo fire ARM: pack 3 off")
    T.check(out.high[1] and out.high[2], "cargo fire ARM: packs 1 and 2 high")
    T.check(not (out.fan[1] or out.fan[2] or out.fan[3] or out.fan[4]), "cargo fire ARM: all recirculation fans off")
end

-- the controllers: NORM starts with A and changes at each touchdown; A or B
-- by the selector; TRIM AIR off keeps A; a lost controller hands over; none
-- for 30 s gives PACK n, all three PACK CONTROL (FCOM p.556, p.560, p.588,
-- p.620; ATA21 p.84, p.102)
do
    local s, inp = parked()
    local out = run(s, inp, 4)
    T.check(out.ptc[1] == 1 and out.ptc[2] == 1 and out.ptc[3] == 1, "NORM: controller A first")
    inp.on_ground = false
    run(s, inp, 1)
    inp.on_ground = true
    out = run(s, inp, 1)
    T.equal(out.ptc[1], 2, "NORM: B after the touchdown")
    inp.selector[2] = 2
    out = run(s, inp, 0.1)
    T.equal(out.ptc[2], 1, "PACK 2 at A: controller A")
    inp.selector[2], inp.trim_air = 3, false
    out = run(s, inp, 0.1)
    T.equal(out.ptc[2], 1, "TRIM AIR off: A, whatever the selector")
    inp.trim_air = true
    out = run(s, inp, 0.1)
    T.equal(out.ptc[2], 2, "PACK 2 at B: controller B")
    inp.dc[4] = false
    out = run(s, inp, 0.1)
    T.equal(out.ptc[2], 1, "B without DC bus 4: A takes over")
    inp.ptc_failed[1] = true
    out = run(s, inp, 29)
    T.check(out.ptc[1] == 0 and not out.pack_alert[1], "no controller: none, PACK 1 waits 30 s")
    T.check(out.operating[1], "no controller: the pack keeps running (FCOM p.589)")
    out = run(s, inp, 1.5)
    T.check(out.pack_alert[1] and out.pack_alert[2] and out.pack_alert[3], "no controller for 30 s: PACK 1-3")
    T.check(out.control_alert, "no controller for any pack: PACK CONTROL")
end

-- a trip latches until PACK RST with the overheat gone, or OFF; SYS FAULT
-- (FCOM p.560; ATA21 p.78, p.94)
do
    local s, inp = parked()
    run(s, inp, 1)
    inp.overheat[1] = true
    local out = run(s, inp, 4)
    T.equal(out.valve[1], 0, "overheat: pack 1 tripped")
    T.check(out.sys_fault and out.pack_alert[1], "overheat: SYS FAULT, PACK 1")
    inp.pack_rst = true
    out = run(s, inp, DT)
    inp.pack_rst = false
    out = run(s, inp, 1)
    T.check(out.sys_fault, "PACK RST with the overheat on: still tripped")
    inp.overheat[1] = false
    out = run(s, inp, 1)
    T.check(out.sys_fault, "overheat gone: still latched")
    inp.pack_rst = true
    out = run(s, inp, DT)
    inp.pack_rst = false
    out = run(s, inp, 4)
    T.check(not out.sys_fault and out.valve[1] == 1, "PACK RST: reset, pack 1 back")
    inp.overheat[1] = true
    run(s, inp, 1)
    inp.overheat[1] = false
    inp.selector[1] = 0
    out = run(s, inp, 0.1)
    T.check(not out.sys_fault and not out.pack_alert[1], "selector OFF resets the trip")
end

-- the recirculation fans: the upper pair on the ground and in climb, all
-- four in the clamp (5 s apart), a failed upper fan brings in the lower
-- one below it, four with a pack off, RECIRC switches (ATA21 p.138-141,
-- p.386-389; FCOM p.556)
do
    local s, inp = parked()
    local out = run(s, inp, 6)
    T.check(out.fan[1] and out.fan[2] and not out.fan[3] and not out.fan[4], "ground: upper fans on, lower off")
    inp.fan_failed[1] = true
    out = run(s, inp, 6)
    T.check(not out.fan[1] and out.fan[3] and not out.fan[4], "upper fan 1 failed: lower fan 1 on")
    inp.fan_failed[1] = false
    inp.selector[2] = 0
    out = run(s, inp, 20)
    T.check(out.fan[1] and out.fan[2] and out.fan[3] and out.fan[4], "a pack off: four fans")
    inp.selector[2] = 1
    out = run(s, inp, 20)
    T.check(not out.fan[3] and not out.fan[4], "three packs: lower fans off")
    inp.on_ground, inp.cruise_clamp = false, true
    out = run(s, inp, 0.1)
    T.check(out.fan[3] ~= out.fan[4], "cruise clamp: one lower fan at a time")
    out = run(s, inp, 6)
    T.check(out.fan[3] and out.fan[4], "cruise clamp: four fans after 5 s")
    inp.hi_flow = true
    out = run(s, inp, 12)
    T.check(not out.fan[3] and not out.fan[4], "HI FLOW with three packs high: two fans stop (the lower: estimate)")
    inp.hi_flow, inp.recirc_upr = false, false
    out = run(s, inp, 12)
    T.check(not out.fan[1] and not out.fan[2] and out.fan[3], "UPR RECIRC off: upper fans off")
end

T.done()
