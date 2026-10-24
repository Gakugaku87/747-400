-- Run from the repository root with LuaJIT: luajit tests/nav/airdata_model_test.lua
-- The air data model (plugins/xtlua/scripts/B747.34.xt.nav/B747.34.airdata_model.lua)
-- against FCOM 10.50, 15.20 and ATA34_1 34-12, 34-16 (docs/overhaul/notes/ATA-34.md
-- §3.1-§3.3, §4.1-§4.3): the AIR DATA selectors and the source relays' interlock,
-- each pilot's air data and baro, the ADCs' power and failure, OVERSPEED at
-- Vmo/Mmo, IAS and ALT DISAGREE after five seconds, >SOURCE SEL ADC, and the
-- altitude alert: approach, capture, departure, reset, inhibits.
local T = dofile("tests/lib/check.lua")("airdata_model")
local M = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.airdata_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
local function level(inp, alt)
    for i = 1, 3 do inp.alt_std[i] = alt end
end

-- the baro conversions
T.near(M.baro_alt(0, 29.92126), 0, 0.5, "29.92: the pressure altitude")
T.near(M.baro_alt(0, 30.92), 920, 20, "one inch more: about 940 ft higher near sea level")
T.near(M.pressure_alt(M.baro_alt(5000, 29.5), 29.5), 5000, 0.01, "and back")
T.near(M.mach_from(250, 0), 0.378, 0.002, "250 kt at sea level: M0.378")
T.near(M.mach_from(280, 35000), 0.821, 0.003, "280 kt at FL350: M0.82")

-- the selection and the relays
local s, inp = M.new(), M.inputs()
for i = 1, 3 do inp.cas[i] = 250 end
inp.cas[1], inp.cas[2], inp.cas[3] = 250, 251, 252
local out = run(s, inp, 0.2)
T.equal(out.capt.src, M.L, "normal: the captain on L")
T.equal(out.fo.src, M.R, "the first officer on R")
T.equal(out.capt.cas, 250, "the captain's speed from L")
T.equal(out.capt_bus, M.L, "the captain's relay bus on L")
T.check(not out.source_sel_adc, "no >SOURCE SEL ADC")
inp.sel_capt = M.C
out = run(s, inp, 0.2)
T.equal(out.capt.cas, 251, "captain on C: C's speed")
T.equal(out.capt_bus, M.C, "the captain's relay: C")
inp.sel_fo = M.C
out = run(s, inp, 0.2)
T.equal(out.fo_bus, M.R, "the first officer on C too: his relay cannot latch (p.98-100)")
T.equal(out.fo.cas, 251, "but his display shows C (the EIUs take all three)")
T.check(out.source_sel_adc, "both on C: >SOURCE SEL ADC (FCOM p.1197)")
inp.sel_capt = M.L
out = run(s, inp, 0.2)
T.equal(out.capt_bus, M.L, "the captain back to L")
T.equal(out.fo_bus, M.C, "the first officer's relay latches C now")
inp.sel_capt, inp.sel_fo = M.R, M.R
out = run(s, inp, 0.2)
T.equal(out.capt.cas, 252, "captain on R: R's speed")
T.equal(out.capt_bus, M.L, "his relay stays on L (it switches L and C only)")
T.check(out.source_sel_adc, "both on R: >SOURCE SEL ADC")
inp.sel_capt, inp.sel_fo = M.L, M.R

-- each pilot's baro
level(inp, 5000)
inp.baro_capt, inp.baro_fo = 29.92126, 30.12
out = run(s, inp, 0.2)
T.near(out.capt.alt, 5000, 0.5, "the captain at 29.92: 5000 ft")
T.check(out.fo.alt > 5150 and out.fo.alt < 5250, "the first officer at 30.12: about 200 ft more (" .. out.fo.alt .. ")")
inp.baro_capt, inp.baro_fo = 29.92126, 29.92126

-- power and failure
inp.power[1] = false
out = run(s, inp, 0.2)
T.check(not out.capt.valid, "the standby bus lost: ADC L invalid, the captain's air data too")
T.check(out.fo.valid, "the first officer's fine")
inp.power[1] = true
inp.fail[3] = true
out = run(s, inp, 0.2)
T.check(not out.fo.valid, "ADC R failed")
inp.fail[3] = false

-- OVERSPEED: 365 kt or M0.92, not the placards
for i = 1, 3 do inp.cas[i], inp.mach[i] = 360, 0.60 end
out = run(s, inp, 0.2)
T.check(not out.overspeed, "360 kt: none")
inp.cas[1] = 366
out = run(s, inp, 0.2)
T.check(out.overspeed, "366 kt on the captain's: OVERSPEED")
inp.cas[1], inp.mach[3] = 300, 0.925
out = run(s, inp, 0.2)
T.check(out.overspeed, "M0.925 on the first officer's: OVERSPEED")
inp.mach[3] = 0.85
out = run(s, inp, 0.2)
T.check(not out.overspeed, "M0.85: none")

-- IAS DISAGREE: five knots or more, after five seconds
for i = 1, 3 do inp.cas[i] = 280 end
run(s, inp, 0.2)
inp.cas[3] = 285
out = run(s, inp, 4.5)
T.check(not out.ias_disagree, "5 kt for 4.5 s: not yet")
out = run(s, inp, 1)
T.check(out.ias_disagree, "after five seconds: IAS DISAGREE")
inp.cas[3] = 284
out = run(s, inp, 0.2)
T.check(not out.ias_disagree, "4 kt: gone")
-- ALT DISAGREE: more than 200 ft uncorrected; not the baro settings
level(inp, 10000)
inp.alt_std[3] = 10150
inp.baro_fo = 30.42
out = run(s, inp, 6)
T.check(not out.alt_disagree, "150 ft uncorrected (the corrected ones 600 ft apart): none")
inp.alt_std[3] = 10250
out = run(s, inp, 6)
T.check(out.alt_disagree, "250 ft for six seconds: ALT DISAGREE")
level(inp, 10000)
inp.baro_fo = 29.92126
run(s, inp, 0.2)

-- the altitude alert
s, inp = M.new(), M.inputs()
inp.mcp_alt = 12000
level(inp, 10000)
out = run(s, inp, 2)
T.check(not out.alt_advise and not out.alt_alert, "2000 ft below: nothing")
level(inp, 11200)
out = run(s, inp, 0.2)
T.check(out.alt_advise, "800 ft below: the white box (approaching)")
level(inp, 11800)
out = run(s, inp, 0.2)
T.check(not out.alt_advise and not out.alt_alert, "within 300 ft: captured, no box")
level(inp, 12350)
out = run(s, inp, 0.2)
T.check(out.alt_alert and not out.alt_advise, "350 ft above after the capture: ALTITUDE ALERT")
level(inp, 12100)
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "back within 300 ft: gone")
level(inp, 11600)
out = run(s, inp, 0.2)
T.check(out.alt_alert, "departing again: the alert")
level(inp, 11000)
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "past 900 ft: gone")
level(inp, 11300)
out = run(s, inp, 0.2)
T.check(out.alt_advise and not out.alt_alert, "coming back: approaching again, no alert")
level(inp, 12000)
run(s, inp, 0.2)
level(inp, 12400)
out = run(s, inp, 0.2)
T.check(out.alt_alert, "captured and departing: the alert")
inp.mcp_alt = 15000
out = run(s, inp, 0.5)
T.check(not out.alt_alert, "a new selected altitude: gone")
-- inhibits: the glideslope; landing flaps with the gear down
inp.mcp_alt = 3000
level(inp, 3000)
out = run(s, inp, 2)
level(inp, 2500)
inp.gs_capture = true
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "glideslope captured: inhibited")
inp.gs_capture = false
inp.landing_flaps, inp.gear_down = true, true
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "landing flaps and the gear down: inhibited")
inp.ground, inp.park_brake = true, true
out = run(s, inp, 0.2)
T.check(out.alt_alert, "on the ground with the parking brake: not inhibited (a test, p.191)")
inp.ground, inp.park_brake, inp.landing_flaps, inp.gear_down = false, false, false, false
-- the bus: the FCC in command, else the captain's switch
s, inp = M.new(), M.inputs()
inp.mcp_alt = 8000
level(inp, 8000)
run(s, inp, 2)
inp.alt_std[1], inp.alt_std[2], inp.alt_std[3] = 8000, 8000, 8500
inp.fcc_cmd = M.L
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "FCC L in command: the left bus (8000 ft), no alert")
inp.fcc_cmd = M.R
out = run(s, inp, 0.2)
T.check(out.alt_alert, "FCC R in command: the right bus (8500 ft), the alert")
inp.fcc_cmd = 0
out = run(s, inp, 0.2)
T.check(not out.alt_alert, "none in command: the captain's switch L: the left bus")
T.done()
