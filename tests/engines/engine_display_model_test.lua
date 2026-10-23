-- Run from the repository root with LuaJIT: luajit tests/engines/engine_display_model_test.lua
-- The engine indication model (plugins/xtlua/scripts/B747.40.xt.engines/
-- B747.40.engine_display_model.lua) against FCOM p.837-838, p.846-850,
-- p.872, p.879, p.890, p.901 and ATA70_80 p.356-357, p.395, p.522: the EGT
-- colours, the amber inhibit after a TO/GA push (5 minutes; P&W 10 with an
-- engine out) and the start limit line; the oil pressure, temperature and
-- quantity, their colours and messages; the vibration and its source.
local T = dofile("tests/lib/check.lua")("engine_display_model")
local D = dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_display_model.lua")

local DT = 0.1
local function run(s, inp, seconds)
    local out
    for _ = 1, math.floor(seconds / DT + 0.5) do
        out = D.update(s, inp, DT)
        inp.toga = false
    end
    return out
end
local function all(t, v)
    for n = 1, 4 do if t[n] ~= v then return false end end
    return true
end

-- the limits: CF6-80C2 from ATA70_80 p.395
T.equal(D.EGT.GE.red, 960, "CF6 EGT takeoff limit 960 °C")
T.equal(D.EGT.GE.amber, 925, "CF6 EGT continuous limit 925 °C")
T.equal(D.EGT.GE.start, 750, "CF6 EGT start limit 750 °C")

-- running engines: white below the amber band, amber in it, red at the red line
do
    local s, inp = D.new(), D.inputs()
    inp.type = "GE"
    inp.cutoff = {false, false, false, false}
    inp.running = {true, true, true, true}
    inp.egt = {800, 925, 959, 960}
    local o = D.update(s, inp, DT)
    T.check(all(o.start_limit, false), "running: no start limit line")
    T.check(o.white[1] and not o.amber[1] and not o.red[1], "EGT 800: white")
    T.check(o.amber[2] and not o.white[2], "EGT 925 (the continuous limit): amber")
    T.check(o.amber[3], "EGT 959: amber")
    T.check(o.red[4] and not o.amber[4] and not o.white[4], "EGT 960 (the takeoff limit): red")
    -- TO/GA pushed: amber held off for 5 minutes, red is not
    inp.toga = true
    o = run(s, inp, 1)
    T.check(o.inhibit, "TO/GA: inhibit on")
    T.check(o.white[2] and o.white[3], "TO/GA: white in the amber band")
    T.check(o.red[4], "TO/GA: still red at the red line")
    o = run(s, inp, 298)
    T.check(o.white[2], "TO/GA: white just before 5 minutes")
    o = run(s, inp, 2)
    T.check(o.amber[2] and not o.inhibit, "amber again 5 minutes after the TO/GA push")
    -- GE: an engine out does not lengthen it
    inp.toga = true
    inp.running[4] = false
    run(s, inp, 1)
    o = run(s, inp, 300)
    T.check(o.amber[2], "GE: 5 minutes even with an engine out")
end

-- P&W: 10 minutes with an engine failed or shut down
do
    local s, inp = D.new(), D.inputs()
    inp.type = "PW"
    inp.cutoff = {false, false, false, false}
    inp.running = {true, true, true, true}
    inp.egt = {640, 640, 640, 640}
    local o = D.update(s, inp, DT)
    T.check(all(o.amber, true), "P&W EGT 640: amber (continuous limit 629)")
    inp.toga = true
    o = run(s, inp, 100)
    inp.running[2] = false                 -- engine 2 fails during the takeoff
    o = run(s, inp, 250)
    T.check(o.white[1] and o.inhibit, "P&W, engine out: still white after 6 minutes")
    o = run(s, inp, 260)
    T.check(o.amber[1] and not o.inhibit, "P&W, engine out: amber after 10 minutes")
    -- a second push starts the window again
    inp.toga = true
    o = run(s, inp, 1)
    T.check(o.white[1], "a second TO/GA push holds amber off again")
end

-- the start limit line (FCOM p.838, p.879): at CUTOFF and until the start
-- settles at idle; the EGT turns red at the start limit while it shows
do
    local s, inp = D.new(), D.inputs()
    inp.type = "PW"
    local o = D.update(s, inp, DT)
    T.check(all(o.start_limit, true), "CUTOFF: start limit line shown")
    inp.egt = {534, 535, 20, 20}
    o = D.update(s, inp, DT)
    T.check(o.white[1] and o.red[2], "start limit 535: red from 535 (P&W)")
    inp.cutoff[1], inp.starting[1] = false, true   -- RUN, the start under way
    inp.egt[1] = 540
    o = D.update(s, inp, DT)
    T.check(o.start_limit[1] and o.red[1], "RUN during the start: the line stays, red past the start limit")
    inp.starting[1], inp.running[1] = false, true  -- the start settled at idle
    inp.egt[1] = 540
    o = D.update(s, inp, DT)
    T.check(not o.start_limit[1] and o.white[1], "after the start: no line, 540 is white")
    inp.type = "GE"
    inp.egt = {760, 760, 760, 760}
    inp.cutoff = {false, true, true, true}
    o = D.update(s, inp, DT)
    T.check(o.white[1] and o.red[2], "GE: 760 is white running, red at the 750 start limit")
end

-- the oil and vibration spreads at their lowest (0) or highest (1)
local function fixed(v) return function() return v end end
local function running(inp, n2)
    for n = 1, 4 do
        inp.cutoff[n], inp.starting[n], inp.running[n] = false, false, true
        inp.n1[n], inp.n2[n] = 90, n2
    end
end

-- the CF6's oil limits: ATA70_80 p.395, p.522
T.equal(D.OIL.GE.press_red[1], 10, "CF6 oil pressure red line 10 psi at idle")
T.equal(D.OIL.GE.press_red[2], 35, "CF6 oil pressure red line 35 psi at 112 % N2")
T.equal(D.OIL.GE.press_amber[1], 15, "CF6 oil pressure amber 15 psid at low idle")
T.equal(D.OIL.GE.press_amber[2], 34, "CF6 oil pressure amber 34 psid at full power")
T.equal(D.OIL.GE.switch[1], 10, "CF6 low oil pressure switch closes at 10 psid")
T.equal(D.OIL.GE.switch[2], 15, "CF6 low oil pressure switch opens at 15 psid")
T.equal(D.OIL.GE.temp_amber, 160, "CF6 oil temperature amber 160 °C")
T.equal(D.OIL.GE.qty_low, 4, "CF6 oil quantity low 4 US qt")
T.equal(D.OIL.GE.qty_diff, 6, "CF6 oil quantity difference 6 US qt")

-- P&W oil pressure: X-Plane's value with each engine a little apart; red
-- below the red line while running, white when shut down and during a start
-- (FCOM p.846); ENG n OIL PRESS below the red line (FCOM p.901)
do
    local s, inp = D.new(fixed(0)), D.inputs()
    running(inp, 100)
    inp.oil_psi = {150, 60, 150, 150}
    local o = D.update(s, inp, DT)
    T.near(o.oil_psi[1], 151, 1e-9, "the indication: X-Plane's 150 psi and 1 psi at 100 % N2")
    T.check(not o.oil_red[1] and o.oil_red[2], "P&W: 60 psi below the 70 psi red line is red, 151 is not")
    T.check(o.oil_press_msg[2] and not o.oil_press_msg[1], "ENG 2 OIL PRESS")
    T.check(not o.oil_amber[2], "P&W: no amber band")
    inp.cutoff[2] = true
    o = D.update(s, inp, DT)
    T.check(not o.oil_red[2], "shut down: stays white")
    T.check(o.oil_press_msg[2], "shut down: the message is still asked (EICAS hides it on the ground, FCOM p.1586)")
    inp.cutoff[2], inp.starting[2] = false, true
    o = D.update(s, inp, DT)
    T.check(not o.oil_red[2], "during a start: stays white")
    s = D.new(fixed(1))
    o = D.update(s, inp, DT)
    T.near(o.oil_psi[1], 156, 1e-9, "the widest spread: 6 psi at 100 % N2")
end

-- CF6 oil pressure: the red line and the amber band's top rise with N2
-- (ATA70_80 p.395, p.522); the message follows the low pressure switch
do
    local s, inp = D.new(fixed(0)), D.inputs()
    inp.type = "GE"
    running(inp, 65)
    -- at 65 % N2: red line 11.7 psi, amber to 16.3 psi; the spread adds 0.65
    inp.oil_psi = {20, 13, 10, 60}
    local o = D.update(s, inp, DT)
    T.check(not o.oil_red[1] and not o.oil_amber[1], "65 % N2, 20.65 psi: white")
    T.check(o.oil_amber[2] and not o.oil_red[2], "65 % N2, 13.65 psi: amber")
    T.check(o.oil_red[3], "65 % N2, 10.65 psi: red")
    -- at 100 % N2 the red line is 29 psi: 20 psi is red
    running(inp, 100)
    inp.oil_psi[1] = 20
    o = D.update(s, inp, DT)
    T.check(o.oil_red[1], "100 % N2, 21 psi: red (red line 29 psi)")
    -- the switch: open at 15 psid rising, closed at 10 falling
    for n = 1, 4 do inp.n2[n] = 0 end
    inp.oil_psi = {50, 50, 50, 50}
    o = D.update(s, inp, DT)
    T.check(not o.oil_press_msg[1], "50 psid: switch open, no message")
    inp.oil_psi[1] = 12
    o = D.update(s, inp, DT)
    T.check(not o.oil_press_msg[1], "12 psid falling: still open")
    inp.oil_psi[1] = 10
    o = D.update(s, inp, DT)
    T.check(o.oil_press_msg[1], "10 psid: closed, ENG 1 OIL PRESS")
    inp.oil_psi[1] = 14
    o = D.update(s, inp, DT)
    T.check(o.oil_press_msg[1], "14 psid rising: still closed")
    inp.oil_psi[1] = 15
    o = D.update(s, inp, DT)
    T.check(not o.oil_press_msg[1], "15 psid: open again")
end

-- oil temperature: ENG n OIL TEMP above the amber band, 160 °C (FCOM p.901)
do
    local s, inp = D.new(fixed(0)), D.inputs()
    running(inp, 90)
    inp.oil_degc = {158, 160, 100, 100}
    local o = D.update(s, inp, DT)
    T.near(o.oil_degc[1], 158.9, 1e-9, "the indication: X-Plane's 158 °C and 1 °C at 100 % N2 (0.9 at 90 %)")
    T.check(not o.oil_temp_msg[1] and o.oil_temp_msg[2], "ENG 2 OIL TEMP at 160.9 °C, not ENG 1 at 158.9")
end

-- oil quantity: the oil in the engine leaves the tank once it turns; each
-- engine its own X-Plane ratio; the CF6 in US quarts (FCOM p.848)
do
    local s, inp = D.new(fixed(0)), D.inputs()
    inp.oil_ratio = {1, 0.5, 1, 1}
    for n = 1, 4 do inp.n1[n] = 0 end
    local o = D.update(s, inp, DT)
    T.near(o.oil_qty[1], 33, 1e-9, "stopped: 33 L")
    T.near(o.oil_qty[2], 16.5, 1e-9, "engine 2's own ratio")
    inp.n1 = {20, 7.5, 0, 0}
    o = D.update(s, inp, DT)
    T.near(o.oil_qty[1], 26, 1e-9, "running: 7 L in the engine")
    T.near(o.oil_qty[2], 14.75, 1e-9, "7.5 % N1: half of it")
    T.check(not o.oil_qty_magenta[2], "P&W: no magenta (no low limit in the manuals)")
    inp.type = "GE"
    inp.oil_ratio = {1, 1, 1, 0.75}
    inp.n1 = {20, 20, 20, 20}
    o = D.update(s, inp, DT)
    T.near(o.oil_qty[1], 26 / 0.946353, 1e-9, "CF6: 26 L shows as 27.5 US qt")
    T.check(not o.oil_qty_magenta[4], "6.9 qt below the others, not in cruise: white")
    inp.cruise = true
    o = D.update(s, inp, DT)
    T.check(o.oil_qty_magenta[4] and not o.oil_qty_magenta[1], "in cruise, the lowest 6 qt or more below: magenta (FCOM p.890)")
    inp.cruise = false
    inp.oil_ratio[4] = 0.1
    o = D.update(s, inp, DT)
    T.check(o.oil_qty_magenta[4], "2.7 qt: low, magenta")
end

-- vibration: the highest source and its level (FCOM p.849-850)
do
    local s, inp = D.new(fixed(0)), D.inputs()
    local o = D.update(s, inp, DT)
    T.check(all(o.vib, 0) and all(o.vib_source, 0), "stopped: 0, no source (BB)")
    s.vib_units[1] = {N1 = 1.0, N2 = 0.5, FAN = 0.8, LPT = 0.3}
    inp.n1[1], inp.n2[1] = 50, 100
    o = D.update(s, inp, DT)
    T.near(o.vib[1], 0.5, 1e-9, "P&W: N2 0.5 at 100 % above N1 1.0 at 50 % (0.25)")
    T.equal(D.VIB_SOURCES.PW[o.vib_source[1]], "N2", "P&W: source N2")
    inp.n1[1] = 100
    o = D.update(s, inp, DT)
    T.equal(D.VIB_SOURCES.PW[o.vib_source[1]], "N1", "P&W: source N1 at 100 % N1")
    inp.type = "GE"
    o = D.update(s, inp, DT)
    T.near(o.vib[1], 0.8, 1e-9, "CF6: FAN 0.8")
    T.equal(D.VIB_SOURCES.GE[o.vib_source[1]], "FAN", "CF6: source FAN")
end

T.done()
