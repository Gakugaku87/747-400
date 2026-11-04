-- Run from the repository root with LuaJIT: luajit tests/bleed/bleed_fail_test.lua
-- The bleed air model's failures (2026-11-04; docs/overhaul/notes/ATA-36.md
-- §10): the overpressure (the PRV's regulation), the HPSOV and the PRV
-- failed closed or open, the overheat's STATUS message, with the engine
-- running. Advisories and SYS FAULT: FCOM p.575, p.619; the ASCTU: LH36
-- p.96-102; the STATUS messages and their delays: ATA30_32_35_36 p.58, p.72,
-- p.90.
local T = dofile("tests/lib/check.lua")("bleed_fail")
local B = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.bleed_model.lua")

local DT = 1 / 30
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = B.update(s, inp, DT) end
    return out
end
-- four engines at idle, bleed switches ON, isolation valves open
local function idle()
    local s, inp = B.new(), B.inputs()
    for n = 1, 4 do inp.n2[n], inp.fuel_run[n] = 65, true end
    inp.air, inp.altitude = true, 10000
    run(s, inp, 20)
    return s, inp
end
local function quiet(e)
    return not e.sys_fault and not e.bleed_alert and not e.hp_alert and not e.ovht_alert
        and not e.st_hp and not e.st_ovpress and not e.st_prv and not e.st_ovht
end

-- nothing failed: no messages; the HP port at idle
do
    local s, inp = idle()
    local out = run(s, inp, 130)
    for n = 1, 4 do
        T.check(quiet(out.eng[n]), "normal: no bleed messages, engine " .. n)
        T.check(out.eng[n].hpsov_open and out.eng[n].prv_open and out.eng[n].prsov_open, "normal: valves open, engine " .. n)
    end
    T.check(math.abs(out.eng[1].psi - B.ENG_FULL_PSI) < 0.01, "normal: full bleed pressure at idle")
end

-- the HPSOV failed closed: BLEED HP ENG 1 after 5 s (FCOM p.619), no SYS
-- FAULT; the IP stage alone gives less at idle (estimate); at high power
-- the HPSOV is commanded closed and the message goes
do
    local s, inp = idle()
    inp.fail.hpsov_closed[1] = true
    local out = run(s, inp, 4)
    T.check(not out.eng[1].hp_alert, "HPSOV 1 failed closed: not before 5 s")
    out = run(s, inp, 2)
    T.check(out.eng[1].hp_alert, "HPSOV 1 failed closed: BLEED HP ENG 1")
    T.check(not out.eng[1].sys_fault and not out.eng[1].bleed_alert, "HPSOV 1 failed closed: no SYS FAULT, no BLEED 1")
    T.check(not out.eng[1].hpsov_open, "HPSOV 1 failed closed: valve closed")
    T.check(out.eng[1].psi > 25 and out.eng[1].psi < 35, "HPSOV 1 failed closed: the IP stage alone at idle")
    out = run(s, inp, 70)
    T.check(not out.eng[1].st_hp, "HPSOV 1 failed closed: no STATUS BLEED HP ENG 1 (that is failed open)")
    inp.n2[1] = 90
    out = run(s, inp, 1)
    T.check(not out.eng[1].hp_alert, "HPSOV 1 failed closed, high power (commanded closed): no BLEED HP ENG 1")
    T.check(math.abs(out.eng[1].psi - B.ENG_FULL_PSI) < 0.01, "high power: full pressure from the IP port")
    inp.fail.hpsov_closed[1] = false
    inp.n2[1] = 65
    out = run(s, inp, 1)
    T.check(quiet(out.eng[1]) and out.eng[1].hpsov_open, "HPSOV 1 repaired: open, no messages")
end

-- the HPSOV failed open at high power: BLEED 2 and SYS FAULT after 5 s
-- (FCOM p.575, p.619); STATUS BLEED HP ENG 2 after 60 s (ATA30_32_35_36 p.58)
do
    local s, inp = idle()
    inp.n2[2] = 90
    local out = run(s, inp, 2)
    T.check(quiet(out.eng[2]) and not out.eng[2].hpsov_open, "high power: HPSOV 2 closed, no messages")
    inp.fail.hpsov_open[2] = true
    out = run(s, inp, 4)
    T.check(not out.eng[2].bleed_alert and not out.eng[2].sys_fault, "HPSOV 2 failed open: not before 5 s")
    out = run(s, inp, 2)
    T.check(out.eng[2].bleed_alert and out.eng[2].sys_fault, "HPSOV 2 failed open: BLEED 2, SYS FAULT")
    T.check(not out.eng[2].hp_alert and not out.eng[2].ovht_alert, "HPSOV 2 failed open: no BLEED HP ENG 2, no BLD 2 OVHT/PRV")
    out = run(s, inp, 52)
    T.check(not out.eng[2].st_hp, "HPSOV 2 failed open: STATUS not before 60 s")
    out = run(s, inp, 3)
    T.check(out.eng[2].st_hp, "HPSOV 2 failed open: STATUS BLEED HP ENG 2")
    inp.n2[2] = 65
    out = run(s, inp, 1)
    T.check(quiet(out.eng[2]), "HPSOV 2 failed open, idle (commanded open): no messages")
    T.check(quiet(out.eng[1]) and quiet(out.eng[3]) and quiet(out.eng[4]), "HPSOV 2: the other engines quiet")
end

-- the PRV failed closed: BLD 3 OVHT/PRV after 5 s without SYS FAULT (FCOM
-- p.575, p.619); no air from engine 3, engine 4 keeps the right duct;
-- STATUS BLEED PRV ENG 3 after 125 s (ATA30_32_35_36 p.72)
do
    local s, inp = idle()
    inp.fail.prv_closed[3] = true
    local out = run(s, inp, 4)
    T.check(not out.eng[3].ovht_alert, "PRV 3 failed closed: not before 5 s")
    out = run(s, inp, 2)
    T.check(out.eng[3].ovht_alert, "PRV 3 failed closed: BLD 3 OVHT/PRV")
    T.check(not out.eng[3].sys_fault and not out.eng[3].bleed_alert, "PRV 3 failed closed: no SYS FAULT, no BLEED 3")
    T.check(out.eng[3].psi == 0 and not out.eng[3].prsov_open and out.eng[3].flow == 0, "PRV 3 failed closed: no air from engine 3")
    T.check(out.duct[3] > 30, "PRV 3 failed closed: engine 4 keeps the right duct")
    out = run(s, inp, 117)
    T.check(not out.eng[3].st_prv, "PRV 3 failed closed: STATUS not before 125 s")
    out = run(s, inp, 3)
    T.check(out.eng[3].st_prv, "PRV 3 failed closed: STATUS BLEED PRV ENG 3")
    inp.fail.prv_closed[3] = false
    out = run(s, inp, 2)
    T.check(quiet(out.eng[3]) and out.eng[3].prsov_open, "PRV 3 repaired: air again, no messages")
end

-- the PRV failed open with ENGINE BLEED 4 OFF: >BLEED 4 OFF stays (the
-- PRSOV closes), and BLEED 4 and SYS FAULT after 5 s (FCOM p.575, p.619);
-- STATUS BLEED PRV ENG 4 after 125 s
do
    local s, inp = idle()
    inp.bleed_on[4] = false
    local out = run(s, inp, 2)
    T.check(out.eng[4].off_alert and quiet(out.eng[4]), "bleed 4 OFF: >BLEED 4 OFF, PRV closed as commanded")
    inp.fail.prv_open[4] = true
    out = run(s, inp, 6)
    T.check(out.eng[4].prv_open and not out.eng[4].prsov_open, "PRV 4 failed open: PRV open, PRSOV closed")
    T.check(out.eng[4].bleed_alert and out.eng[4].sys_fault, "PRV 4 failed open: BLEED 4, SYS FAULT")
    T.check(out.eng[4].off_alert, "PRV 4 failed open: >BLEED 4 OFF too")
    out = run(s, inp, 120)
    T.check(out.eng[4].st_prv, "PRV 4 failed open: STATUS BLEED PRV ENG 4")
    inp.bleed_on[4] = true
    out = run(s, inp, 1)
    T.check(quiet(out.eng[4]) and not out.eng[4].off_alert, "bleed 4 ON (commanded open): no messages")
end

-- the overpressure: BLEED 1, SYS FAULT and STATUS BLEED OVPRESS 1 after
-- 5 s; the valves stay open (LH36 p.96, p.102). ENGINE BLEED 1 OFF closes
-- the PRV and ends it (QRH 2.6)
do
    local s, inp = idle()
    inp.fail.ovpress[1] = true
    local out = run(s, inp, 4)
    T.check(not out.eng[1].bleed_alert, "overpressure 1: not before 5 s")
    out = run(s, inp, 2)
    T.check(out.eng[1].bleed_alert and out.eng[1].sys_fault and out.eng[1].st_ovpress,
        "overpressure 1: BLEED 1, SYS FAULT, STATUS BLEED OVPRESS 1")
    T.check(not out.eng[1].ovht_alert and not out.eng[1].hp_alert, "overpressure 1: no BLD 1 OVHT/PRV, no BLEED HP ENG 1")
    T.check(out.eng[1].prv_open and out.eng[1].prsov_open, "overpressure 1: the valves stay open")
    inp.bleed_on[1] = false
    out = run(s, inp, 1)
    T.check(quiet(out.eng[1]) and out.eng[1].off_alert, "bleed 1 OFF: PRV closed, no overpressure; >BLEED 1 OFF")
end

-- the overheat: SYS FAULT and BLD 1 OVHT/PRV after 5 s (the existing
-- latch), STATUS BLEED 1 OVHT 60 s later (ATA30_32_35_36 p.90); the valves
-- it closes give no valve messages
do
    local s, inp = idle()
    inp.overheat[1] = true
    local out = run(s, inp, 6)
    T.check(out.eng[1].sys_fault and out.eng[1].ovht_alert, "overheat 1: SYS FAULT, BLD 1 OVHT/PRV")
    T.check(not out.eng[1].bleed_alert and not out.eng[1].hp_alert, "overheat 1: the closed valves give no BLEED 1 or BLEED HP ENG 1")
    out = run(s, inp, 58)
    T.check(not out.eng[1].st_ovht, "overheat 1: STATUS not before 60 s")
    out = run(s, inp, 3)
    T.check(out.eng[1].st_ovht, "overheat 1: STATUS BLEED 1 OVHT")
    inp.overheat[1] = false
    inp.bleed_on[1] = false
    run(s, inp, 1)
    inp.bleed_on[1] = true
    out = run(s, inp, 1)
    T.check(quiet(out.eng[1]), "overheat gone, switch off and ON: reset, no messages")
end

-- an engine not running (no air to work the valves) or the ASCTU without
-- its DC bus: no valve or pressure monitoring
do
    local s, inp = idle()
    inp.n2[2] = 30
    inp.fail.hpsov_closed[2], inp.fail.prv_closed[2] = true, true
    local out = run(s, inp, 10)
    T.check(quiet(out.eng[2]), "engine 2 below 50 % N2: no valve messages")
    inp.fail.hpsov_closed[2], inp.fail.prv_closed[2] = false, false
    inp.dc[3] = false
    inp.fail.ovpress[3] = true
    out = run(s, inp, 10)
    T.check(quiet(out.eng[3]), "DC bus 3 lost: no overpressure message from engine 3")
    inp.dc[3] = true
    out = run(s, inp, 6)
    T.check(out.eng[3].bleed_alert, "DC bus 3 back: BLEED 3")
end

-- (2026-11-04; PNEU-03) a duct leak takes air from its section (estimate:
-- M.LEAK_FLOW); isolated as QRH 2.2 (ISLN R OFF, ENGINE BLEED 3 and 4 OFF)
-- the right duct has no air left to blow out, the left side keeps its own
do
    local s, inp = idle()
    inp.pack_flow = {2 / 3, 2 / 3, 2 / 3}
    local before = run(s, inp, 5).duct[3]
    inp.leak[3] = true
    local out = run(s, inp, 5)
    T.check(out.duct[3] < before - 0.5, "leak R: the ducts a little lower")
    T.check(out.duct[3] > 25, "leak R: the packs still have air")
    inp.isln_on[2] = false
    inp.bleed_on[3], inp.bleed_on[4] = false, false
    out = run(s, inp, 10)
    T.check(out.duct[3] < 1, "leak R isolated: no air in the right duct")
    T.check(out.duct[1] > 30 and out.duct[2] > 30, "leak R isolated: the left and centre keep their air")
end

T.done()
