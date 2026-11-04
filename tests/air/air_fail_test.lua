-- Run from the repository root with LuaJIT: luajit tests/air/air_fail_test.lua
-- The air conditioning models' failures (2026-11-04; docs/overhaul/notes/
-- ATA-21.md §10): the pack overheat (its trip and STATUS PACK n), the pack
-- temperature controllers (STATUS PACK CONTROL A, B), the recirculation fans
-- (STATUS RECIRC FAN UPR/LWR L/R), and equipment cooling: the fans, the
-- overheat, the low flows, the smoke and the card (EQUIP COOLING, >E/E CLNG
-- CARD and their STATUS messages). ATA21 p.102, p.144, p.510, p.528-530,
-- p.578; FCOM p.619-620.
local T = dofile("tests/lib/check.lua")("air_fail")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.pack_model.lua")
local Q = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.eqcool_model.lua")

local DT = 1 / 30
local function run(M, s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
-- on the ground, three packs NORM, the ducts at 30 psi
local function parked()
    local s, inp = P.new(), P.inputs()
    inp.duct_psi = {30, 30, 30}
    run(P, s, inp, 5)
    return s, inp
end
local function pack_quiet(out)
    for p = 1, 3 do if out.st_pack[p] or out.pack_alert[p] then return false end end
    for c = 1, 2 do if out.st_ptc[c] then return false end end
    for f = 1, 4 do if out.st_fan[f] then return false end end
    return not out.sys_fault and not out.control_alert
end

-- nothing failed: no messages
do
    local s, inp = parked()
    local out = run(P, s, inp, 100)
    T.check(pack_quiet(out), "packs normal: no PACK, PACK CONTROL or RECIRC FAN messages")
end

-- a pack overheat trips the pack: PACK 2 and SYS FAULT (the existing trip),
-- STATUS PACK 2 after 75 s (ATA21 p.102); PACK RST with the overheat gone
-- resets it
do
    local s, inp = parked()
    inp.overheat[2] = true
    local out = run(P, s, inp, 1)
    T.check(out.pack_alert[2] and out.sys_fault and out.valve[2] < 1,
        "pack 2 overheat: PACK 2, SYS FAULT, the pack trips")
    out = run(P, s, inp, 72)
    T.check(not out.st_pack[2], "pack 2 overheat: STATUS not before 75 s")
    out = run(P, s, inp, 4)
    T.check(out.st_pack[2] and not out.st_pack[1] and not out.st_pack[3], "pack 2 overheat: STATUS PACK 2")
    inp.overheat[2] = false
    inp.pack_rst = true
    out = run(P, s, inp, DT)
    inp.pack_rst = false
    out = run(P, s, inp, 5)
    T.check(pack_quiet(out) and out.operating[2], "PACK RST with the overheat gone: pack 2 back, no messages")
end

-- a pack temperature controller: STATUS PACK CONTROL A after 10 s (ATA21
-- p.102); the packs hand over to B, no PACK n. Both: PACK n and PACK
-- CONTROL (FCOM p.620), the STATUS PACK n inhibited by both controllers
-- failed (ATA21 p.102)
do
    local s, inp = parked()
    inp.ptc_failed[1] = true
    local out = run(P, s, inp, 9)
    T.check(not out.st_ptc[1], "PTC A failed: not before 10 s")
    out = run(P, s, inp, 2)
    T.check(out.st_ptc[1] and not out.st_ptc[2], "PTC A failed: STATUS PACK CONTROL A")
    T.check(out.ptc[1] == 2 and out.ptc[2] == 2 and out.ptc[3] == 2, "PTC A failed: B controls the packs")
    T.check(not out.pack_alert[1] and not out.control_alert, "PTC A failed: no PACK 1, no PACK CONTROL")
    inp.ptc_failed[2] = true
    out = run(P, s, inp, 100)
    T.check(out.st_ptc[1] and out.st_ptc[2], "both PTCs failed: STATUS PACK CONTROL A and B")
    T.check(out.pack_alert[1] and out.control_alert, "both PTCs failed: PACK 1, PACK CONTROL (FCOM p.620)")
    T.check(not out.st_pack[1] and not out.st_pack[2] and not out.st_pack[3], "both PTCs failed: STATUS PACK n inhibited")
    inp.ptc_failed[1], inp.ptc_failed[2] = false, false
    out = run(P, s, inp, 1)
    T.check(pack_quiet(out), "PTCs repaired: no messages")
end

-- the recirculation fans: upper 10 s, lower 60 s (ATA21 p.144); fan 1
-- upper right, 2 upper left, 3 lower left, 4 lower right
do
    local s, inp = parked()
    inp.fan_failed[2] = true
    inp.fan_failed[4] = true
    local out = run(P, s, inp, 9)
    T.check(not out.st_fan[2], "upper left fan failed: not before 10 s")
    out = run(P, s, inp, 2)
    T.check(out.st_fan[2] and not out.st_fan[1], "upper left fan failed: STATUS RECIRC FAN UPR L")
    T.check(not out.fan[2], "upper left fan failed: not running")
    out = run(P, s, inp, 48)
    T.check(not out.st_fan[4], "lower right fan failed: not before 60 s")
    out = run(P, s, inp, 2)
    T.check(out.st_fan[4] and not out.st_fan[3], "lower right fan failed: STATUS RECIRC FAN LWR R")
    inp.fan_failed[2], inp.fan_failed[4] = false, false
    out = run(P, s, inp, 1)
    T.check(pack_quiet(out), "fans repaired: no messages")
end

-- equipment cooling (NORM, ground, overboard)
local function eq()
    local s, inp = Q.new(), Q.inputs()
    inp.skin_c = 20
    run(Q, s, inp, 2)
    return s, inp
end
local function eq_quiet(out)
    return not out.alert and not out.card_alert and not out.st_sup_fan and not out.st_exh_fan
        and not out.st_temp and not out.st_low_flow and not out.st_fd_low_flow and not out.st_smoke and not out.st_card
end
do
    local s, inp = eq()
    local out = run(Q, s, inp, 60)
    T.check(eq_quiet(out), "equipment cooling normal: no messages")
end

-- the supply fan: STATUS EE CLNG SUP FAN after 10 s and the closed loop
-- (ATA21 p.524, p.528); the exhaust fan: EE CLNG EXH FAN (p.530)
do
    local s, inp = eq()
    inp.fan_failed[1] = true
    local out = run(Q, s, inp, 9)
    T.check(not out.st_sup_fan, "supply fan failed: not before 10 s")
    out = run(Q, s, inp, 2)
    T.check(out.st_sup_fan and not out.st_exh_fan, "supply fan failed: STATUS EE CLNG SUP FAN")
    T.equal(out.config, Q.CLOSED_LOOP, "supply fan failed: the closed loop (ATA21 p.524)")
    inp.fan_failed[1], inp.fan_failed[2] = false, true
    out = run(Q, s, inp, 11)
    T.check(out.st_exh_fan and not out.st_sup_fan, "exhaust fan failed: STATUS EE CLNG EXH FAN")
end

-- the overheat and the low flows: EQUIP COOLING at once, their STATUS after
-- 40 s; FLT DK LOW FLOW inhibited by EQUIP LOW FLOW; the smoke: EQUIP
-- COOLING and EQUIPMENT SMOKE (ATA21 p.578; FCOM p.619)
do
    local s, inp = eq()
    inp.overheat = true
    local out = run(Q, s, inp, 1)
    T.check(out.alert and not out.st_temp, "overheat: EQUIP COOLING, STATUS not yet")
    out = run(Q, s, inp, 40)
    T.check(out.st_temp, "overheat: STATUS EQUIPMENT TEMP after 40 s")
    inp.overheat = false
    inp.fd_low_flow = true
    out = run(Q, s, inp, 1)
    T.check(out.alert and not out.st_temp, "flight deck low flow: EQUIP COOLING")
    out = run(Q, s, inp, 40)
    T.check(out.st_fd_low_flow, "flight deck low flow: STATUS FLT DK LOW FLOW")
    inp.low_flow = true
    out = run(Q, s, inp, 41)
    T.check(out.st_low_flow and not out.st_fd_low_flow, "both low flows: EQUIP LOW FLOW, FLT DK LOW FLOW inhibited")
    inp.low_flow, inp.fd_low_flow = false, false
    inp.smoke = true
    out = run(Q, s, inp, 0.1)
    T.check(out.alert and out.st_smoke, "smoke: EQUIP COOLING and STATUS EQUIPMENT SMOKE")
    inp.smoke = false
    out = run(Q, s, inp, 0.1)
    T.check(eq_quiet(out), "smoke gone: no messages")
end

-- the card: >E/E CLNG CARD on the ground only, the STATUS in the air too
-- (ATA21 p.510; FCOM p.619)
do
    local s, inp = eq()
    inp.card_failed = true
    local out = run(Q, s, inp, 0.1)
    T.check(out.card_alert and out.st_card, "card failed on the ground: >E/E CLNG CARD and STATUS")
    inp.on_ground = false
    out = run(Q, s, inp, 0.1)
    T.check(not out.card_alert and out.st_card, "card failed in flight: >E/E CLNG CARD inhibited, STATUS stays")
end

T.done()
