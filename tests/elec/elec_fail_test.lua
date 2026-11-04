-- Run from the repository root with LuaJIT: luajit tests/elec/elec_fail_test.lua
-- The electrical model's failures (2026-11-04; docs/overhaul/notes/ATA-24.md
-- §11): a generator power fault (LH24 p.102, p.106; FCOM p.798), an AC load
-- bus fault (LH24 p.102), the IDG drive (LH24 p.72-73; FCOM p.821), a TRU
-- (LH24 p.184), the battery chargers (LH24 p.196) and the SSB failed open
-- (FCOM p.822). Page numbers are PDF pages, as in the notes.
local T = dofile("tests/lib/check.lua")("elec_fail")
local E = dofile("plugins/xtlua/scripts/B747.03.xt.electrical/B747.03.elec_model.lua")

local function run(s, inp, seconds, dt)
    dt = dt or 1 / 30
    local out
    for _ = 1, math.max(1, math.floor(seconds / dt + 0.5)) do out = E.update(s, inp, dt) end
    return out
end

-- in flight, the four generators on line, BUS TIEs AUTO, UTILITY on
local function flying()
    local s, inp = E.new(), E.inputs()
    inp.battery = true
    inp.utility = {true, true}
    for n = 1, 4 do inp.n2[n] = 69 end
    inp.on_ground = false
    run(s, inp, 2)
    return s, inp
end

-- nothing failed: the inputs and the normal state
do
    local s, inp = flying()
    local out = run(s, inp, 0.5)
    T.check(out.gcb[1] and out.gcb[4] and out.btb[2] and out.ssb, "(normal: GCBs, BTBs and the SSB closed)")
    T.check(not out.cas.ssb_open and not out.status.tr_unit, "normal: no >ELEC SSB OPEN, no ELEC TR UNIT")
    T.check(not out.status.drive[1] and not out.status.bat_charger_main and not out.status.bat_charger_apu,
        "normal: no ELEC DRIVE or BAT CHARGER status")
end

-- a generator power fault: the GCR and GCB trip, the BTB recloses (auto
-- reclose), AC bus 2 from the sync bus; GEN OFF light and ELEC GEN OFF 2;
-- GEN CONT OFF and ON does not reset it while the fault stays; it does
-- after the fault is gone
do
    local s, inp = flying()
    inp.fail.gen[2] = true
    local out = run(s, inp, 0.5)
    T.check(not out.gcb[2], "generator 2 fault: GCB 2 open (LH24 p.102, p.106)")
    T.check(out.btb[2] and out.ac[2], "the BTB recloses: AC bus 2 from the sync bus (LH24 p.102; FCOM p.798)")
    T.check(out.lights.gen_off[2] and out.cas.gen_off[2], "GEN OFF 2 light, ELEC GEN OFF 2")
    T.check(not out.cas.ac_bus[2] and not out.lights.isln[2], "no ELEC AC BUS 2, no ISLN 2")
    T.check(out.gcb[1] and out.gcb[3] and out.gcb[4], "the other generators on line")
    inp.gen_cont[2] = false
    run(s, inp, 0.5)
    inp.gen_cont[2] = true
    out = run(s, inp, 0.5)
    T.check(not out.gcb[2], "GEN CONT 2 cycled with the fault: trips again (LH24 p.106)")
    inp.fail.gen[2] = false
    out = run(s, inp, 0.5)
    T.check(not out.gcb[2], "the fault gone: the GCR stays tripped until GEN CONT is cycled")
    inp.gen_cont[2] = false
    run(s, inp, 0.5)
    inp.gen_cont[2] = true
    out = run(s, inp, 0.5)
    T.check(out.gcb[2] and not out.cas.gen_off[2], "GEN CONT 2 cycled after the fault: back on line")
end

-- an AC load bus fault: the BTB latched open, the GCB tripped (estimate),
-- AC bus 3 dead (ELEC AC BUS 3, ELEC GEN OFF 3 and BUS ISLN 3 not shown);
-- BUS TIE OFF and AUTO with the fault: open again; after the fault: closed,
-- GEN CONT cycled: back on line
do
    local s, inp = flying()
    inp.fail.bus[3] = true
    local out = run(s, inp, 0.5)
    T.check(not out.btb[3] and not out.gcb[3], "bus 3 fault: BTB 3 and GCB 3 open (LH24 p.102)")
    T.check(not out.ac[3] and out.cas.ac_bus[3], "AC bus 3 dead: ELEC AC BUS 3")
    T.check(not out.cas.gen_off[3] and not out.cas.bus_isln[3], "ELEC GEN OFF 3 and BUS ISLN 3 not shown with AC BUS 3")
    T.check(out.lights.isln[3] and out.lights.gen_off[3], "ISLN 3 and GEN OFF 3 lights")
    T.check(out.ac[1] and out.ac[2] and out.ac[4], "the other AC buses powered")
    T.check(out.dc[3], "DC bus 3 from the DC tie bus (DCIR 3 closed)")
    inp.bus_tie[3] = false
    run(s, inp, 0.5)
    inp.bus_tie[3] = true
    out = run(s, inp, 0.5)
    T.check(not out.btb[3], "BUS TIE 3 cycled with the fault: open again")
    inp.fail.bus[3] = false
    out = run(s, inp, 0.5)
    T.check(not out.btb[3], "the fault gone: the BTB latch holds until BUS TIE is cycled (no auto reclose)")
    inp.bus_tie[3] = false
    run(s, inp, 0.5)
    inp.bus_tie[3] = true
    out = run(s, inp, 0.5)
    T.check(out.btb[3] and out.ac[3], "BUS TIE 3 cycled after the fault: BTB closed, AC bus 3 from the sync bus")
    inp.gen_cont[3] = false
    run(s, inp, 0.5)
    inp.gen_cont[3] = true
    out = run(s, inp, 0.5)
    T.check(out.gcb[3], "GEN CONT 3 cycled: generator 3 back on line")
end

-- the IDG drive: DRIVE light, ELEC DRIVE and its STATUS while running and
-- connected; the generator stays on line (109 before the SB); DRIVE DISC
-- replaces ELEC DRIVE by DRIVE DISC (FCOM p.797)
do
    local s, inp = flying()
    inp.fail.drive[4] = true
    local out = run(s, inp, 0.5)
    T.check(out.lights.drive[4] and out.cas.drive[4] and out.status.drive[4], "drive 4: DRIVE light, ELEC DRIVE 4, STATUS ELEC DRIVE 4")
    T.check(out.gcb[4] and out.ac[4], "drive 4: generator 4 still on line")
    T.check(not out.cas.drive[1] and not out.lights.drive[1], "drive 4: nothing on 1")
    inp.drive_disc[4] = true
    out = run(s, inp, 0.5)
    T.check(not out.idg_connected[4] and not out.gcb[4], "DRIVE DISC 4: the IDG disconnected, GCB 4 open")
    T.check(not out.cas.drive[4] and out.cas.drive_disc[4], "ELEC DRIVE 4 replaced by >DRIVE DISC 4")
    T.check(out.lights.drive[4], "the DRIVE light stays")
end

-- a TRU: DC bus 1 from the tie bus, ELEC TR UNIT with AC bus 1 powered;
-- with AC bus 1 dead too, no ELEC TR UNIT (LH24 p.184)
do
    local s, inp = flying()
    inp.fail.tru[1] = true
    local out = run(s, inp, 0.5)
    T.check(not out.tru[1] and out.dc[1], "TRU 1: no output, DC bus 1 from the DC tie bus")
    T.check(out.status.tr_unit, "TRU 1: STATUS ELEC TR UNIT (LH24 p.184)")
    inp.bus_tie[1] = false                     -- DCIR 1 opens with BUS TIE OFF (FCOM p.819)
    out = run(s, inp, 0.5)
    T.check(not out.dc[1], "TRU 1 and DCIR 1 open: DC bus 1 dead")
    inp.bus_tie[1] = true
    inp.fail.bus[1] = true
    out = run(s, inp, 0.5)
    T.check(not out.ac[1] and not out.status.tr_unit, "AC bus 1 dead: no ELEC TR UNIT")
end

-- a TRU as a generator channel for the autoland isolation (LH24 p.244):
-- TRU 2 failed, the request sets configuration C (channel 2 out)
do
    local s, inp = flying()
    inp.fail.tru[2] = true
    run(s, inp, 0.5)
    inp.autoland_req, inp.ra = true, 1000
    local out = run(s, inp, 0.5)
    T.check(out.btb[2] and not out.btb[1] and not out.btb[3] and out.btb[4],
        "TRU 2 failed: the isolation's configuration C (BTB 2 and 4 closed)")
    T.check(out.bus_isolated, "BUS ISOLATED")
end

-- the battery chargers: BAT CHARGER MAIN after the EIUs' delay with the GSB
-- powered; the main battery then discharges on the ground with the GSB lost
-- (the hot battery bus on the battery); not at STANDBY POWER BAT
do
    local s, inp = flying()
    inp.fail.charger[1] = true
    local out = run(s, inp, E.CHARGER_MSG_S - 1)
    T.check(not out.status.bat_charger_main, "charger: before the EIUs' delay, no BAT CHARGER MAIN")
    out = run(s, inp, 2)
    T.check(out.status.bat_charger_main and not out.status.bat_charger_apu, "charger: BAT CHARGER MAIN (LH24 p.196)")
    T.check(out.battery.main.amps >= 0, "the main battery not charged")
    T.check(out.battery.apu.amps <= 0 or out.battery.apu.ah >= E.BAT_AH, "the APU battery's charger works")
    inp.stby_power = 2
    out = run(s, inp, 0.5)
    T.check(not out.status.bat_charger_main, "STANDBY POWER BAT: no BAT CHARGER MAIN")
    inp.stby_power = 1
    inp.fail.charger[1] = false
    inp.fail.charger[2] = true
    out = run(s, inp, E.CHARGER_MSG_S + 1)
    T.check(out.status.bat_charger_apu and not out.status.bat_charger_main, "APU charger: BAT CHARGER APU")
end

-- the SSB failed open: >ELEC SSB OPEN while closing is commanded (in
-- flight, IDGs on both sides); the sides apart: each its own IDGs
do
    local s, inp = flying()
    inp.fail.ssb = true
    local out = run(s, inp, 0.5)
    T.check(not out.ssb and out.cas.ssb_open, "SSB failed: open, >ELEC SSB OPEN (FCOM p.822)")
    T.check(out.ac[1] and out.ac[2] and out.ac[3] and out.ac[4], "every AC bus powered by its side")
    inp.gen_cont[1], inp.gen_cont[2] = false, false
    out = run(s, inp, 0.5)
    T.check(not out.sync[1] and not out.ac[1] and not out.ac[2], "both left generators off and the SSB open: AC 1 and 2 dead")
    T.check(out.ac[3] and out.ac[4], "the right side powered")
    inp.fail.ssb = false
    out = run(s, inp, 0.5)
    T.check(out.ssb and out.ac[1] and not out.cas.ssb_open, "SSB back: the right side feeds the left")
end

T.done()
