-- Run from the repository root with LuaJIT: luajit tests/nav/gpws_model_test.lua
-- The GPWS model (plugins/xtlua/scripts/B747.34.xt.nav/B747.34.gpws_model.lua,
-- 5-1 step 4) without X-Plane: the air/ground logic, modes 1-7, the
-- callouts of the 405 and the minimums, bank angle, the GND PROX panel, the
-- voice priority, the lights and the EICAS messages. Sources: ATA34_2 34-46
-- p.122-210; FCOM p.1531-1539, p.1571-1583, p.1604-1605.
local T = dofile("tests/lib/check.lua")("gpws_model")
local G = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.gpws_model.lua")

local DT = 0.1
local s, inp, out
-- an airplane in the air: everything valid, clean, 250 kt, level at the
-- radio altitude given
local function fresh(ra)
    s, inp = G.new(), G.inputs()
    inp.ra, inp.ra_valid = ra, true
    inp.vs, inp.vs_valid = 0, true
    inp.alt, inp.alt_valid = ra, true
    inp.cas, inp.cas_valid = 250, true
    inp.roll_valid = true
    inp.relay_air = ra > 0
    out = G.update(s, inp, DT)
end
local function run(seconds, step)
    for _ = 1, math.floor(seconds / DT + 0.5) do
        if step then step() end
        out = G.update(s, inp, DT)
    end
end
-- descend: the radio altitude and altitude fall at fpm (closure = descent)
local function descend(fpm)
    return function()
        inp.vs = -fpm
        inp.ra = inp.ra - fpm / 60 * DT
        inp.alt = inp.alt - fpm / 60 * DT
    end
end

-- the air/ground logic (p.127, p.205-206)
fresh(0)
inp.relay_air = false
run(1)
T.check(not out.in_air, "on the ground")
inp.vs = -3000
inp.ra = 0
run(1)
T.equal(out.voice, G.V_NONE, "no alert on the ground")
inp.vs = 0
inp.relay_air, inp.ra = true, 3
run(0.2)
T.check(not out.in_air, "air relay but RA 3 ft: still the ground")
inp.ra = 6
run(0.2)
T.check(out.in_air and out.m3_armed, "RA 5 ft and up: in the air, mode 3 armed (lift-off)")
inp.ra, inp.cas = 0.5, 80
run(0.2)
T.check(out.in_air, "back down at 80 kt: still the air")
inp.cas = 55
run(0.2)
T.check(not out.in_air, "60 kt and RA 1 ft: the ground")

-- mode 1 (p.144): alert 998 fpm at 30 ft to 5,007 fpm at 2,450 ft
fresh(1000)
inp.vs = -2500
run(0.5)
T.equal(out.m1, 0, "1,000 ft, 2,500 fpm: inside (the line is 2,605 fpm)")
inp.vs = -2700
run(0.2)
T.equal(out.m1, 1, "2,700 fpm: SINK RATE")
T.equal(out.voice, G.V_SINK_RATE, "the voice SINK RATE")
T.check(out.gnd_prox_light and not out.pull_up, "GND PROX light, no PULL UP")
inp.vs = -4000
run(0.2)
T.equal(out.m1, 2, "4,000 fpm: the warning (estimated line 3,880 fpm)")
T.check(out.pull_up and out.warning and out.voice == G.V_PULL_UP, "PULL UP: PFD, warning, voice")
T.check(out.gnd_prox_light, "the alert's light stays")
inp.vs = -2800
inp.gs_dev, inp.gs_valid = -2, true
run(0.2)
T.equal(out.m1, 0, "2 dots above the glide slope: 300 fpm more allowed (p.144)")
inp.gs_valid = false
inp.ra = 2500
inp.vs = -6000
run(0.2)
T.equal(out.m1, 0, "above 2,450 ft: none")
inp.ra = 25
inp.vs = -3000
run(0.2)
T.equal(out.m1, 0, "below 30 ft: none")

-- mode 2A (p.151-153): 6,000 fpm closure, 250 kt, flaps up: from about 1,700 ft
fresh(2300)
inp.vs = -1000
local function closing(fpm) return function() inp.ra = inp.ra - fpm / 60 * DT end end
run(3, closing(6000))
T.equal(out.m2, 0, "above the curve: none")
local fired_at = nil
for _ = 1, 100 do
    run(0.1, closing(6000))
    if out.m2 > 0 then fired_at = inp.ra break end
end
T.check(fired_at and fired_at < 1710 and fired_at > 1600, "6,000 fpm: TERRAIN from about 1,700 ft (" .. tostring(fired_at) .. ")")
T.equal(out.voice, G.V_TERRAIN, "the voice TERRAIN")
T.check(out.gnd_prox_light and not out.pull_up, "the alert: GND PROX light")
run(1.7, closing(6000))
T.equal(out.m2, 2, "1.6 s later still closing: the warning (p.153)")
T.check(out.pull_up and out.voice == G.V_TERRAIN, "PULL UP on the PFD; the voice still TERRAIN (twice)")
run(1.2, closing(6000))
T.equal(out.voice, G.V_PULL_UP, "then the voice PULL UP")
-- the closure stops after more than 3 s of warning, gear up: the altitude gain function
run(2, closing(6000))
run(2.5)
T.equal(out.m2, 3, "closure stopped: the altitude gain function (p.152)")
T.check(out.gnd_prox_light and out.voice == G.V_NONE and not out.pull_up, "the light only")
inp.alt = inp.alt + 310
run(0.2)
T.equal(out.m2, 0, "300 ft gained: over")

-- mode 2B in landing configuration (p.154): only TERRAIN, between its floor and 789 ft
fresh(900)
inp.gear_down, inp.flaps_landing = true, true
inp.cas = 160
run(3, function() inp.vs = -1200; inp.ra = inp.ra - 3500 / 60 * DT end)
T.equal(out.m2, 1, "2B, 3,500 fpm closure, 1,200 fpm descent: TERRAIN below 789 ft")
run(2, function() inp.vs = -1200; inp.ra = inp.ra - 3500 / 60 * DT end)
T.check(out.m2 == 1 and out.voice == G.V_TERRAIN and not out.pull_up, "landing configuration: no warning")
run(2, function() inp.vs = -1200; inp.ra = inp.ra - 3500 / 60 * DT end)
T.equal(out.m2, 0, "below the 600 ft floor (1,000 fpm and more): none")

-- mode 3 (p.161-166, FCOM p.1576: DON'T SINK) after takeoff
fresh(0)
inp.relay_air = false
inp.cas = 170
run(0.5)
inp.relay_air = true
run(10, function() inp.vs = 2400; inp.ra = inp.ra + 40 * DT; inp.alt = inp.alt + 40 * DT end)
T.check(out.m3_armed and inp.ra > 390, "lift-off: mode 3 armed")
run(1, function() inp.vs = -900; inp.ra = inp.ra - 15 * DT; inp.alt = inp.alt - 15 * DT end)
T.check(not out.m3, "15 ft lost at 385 ft: less than 10 %")
run(2.5, function() inp.vs = -900; inp.ra = inp.ra - 15 * DT; inp.alt = inp.alt - 15 * DT end)
T.check(out.m3 and out.voice == G.V_DONT_SINK, "52 ft lost: DON'T SINK")
T.check(out.gnd_prox_light, "GND PROX light")
inp.vs = 300
run(0.2)
T.check(not out.m3, "stops losing altitude: over (p.161)")
run(20, function() inp.vs = 2000; inp.ra = inp.ra + 34 * DT; inp.alt = inp.alt + 34 * DT end)
T.check(not out.m3_armed, "above about 700 ft at 170 kt: mode 4 takes over")

-- mode 4 (p.168-172, FCOM p.1577); each case from its own radio altitude
-- (a jump would be a closure rate)
fresh(600)
inp.cas = 180
run(0.2)
T.equal(out.m4, G.V_NONE, "gear up, 180 kt, 600 ft: none")
fresh(480)
inp.cas = 180
run(0.2)
T.equal(out.m4, G.V_TOO_LOW_GEAR, "4A below 500 ft slow: TOO LOW GEAR")
T.equal(out.voice, G.V_TOO_LOW_GEAR, "the voice")
inp.gear_down = true
inp.cas = 150
run(0.2)
T.equal(out.m4, G.V_NONE, "4B: 480 ft above 245 ft")
fresh(240)
inp.gear_down = true
inp.cas = 150
run(0.2)
T.equal(out.m4, G.V_TOO_LOW_FLAPS, "4B below 245 ft slow: TOO LOW FLAPS")
inp.flap_ovrd = true
run(0.2)
T.equal(out.m4, G.V_NONE, "FLAP OVRD: inhibited")
fresh(700)
inp.gear_down = true
inp.cas = 220
run(0.2)
T.equal(out.m4, G.V_TOO_LOW_TERRAIN, "4B fast (220 kt): up to about 750 ft, TOO LOW TERRAIN")
inp.gear_down, inp.flaps_landing = false, true
run(0.2)
T.equal(out.m4, G.V_NONE, "4A with the flaps down: 500 ft at all speeds")
fresh(450)
inp.flaps_landing = true
inp.cas = 220
run(0.2)
T.equal(out.m4, G.V_TOO_LOW_GEAR, "TOO LOW GEAR below 500 ft")
inp.gear_ovrd = true
run(0.2)
T.equal(out.m4, G.V_NONE, "GEAR OVRD (gear down simulated, flaps down): landing configuration")
fresh(260)
inp.gear_down, inp.flaps_landing = true, true
inp.cas = 150
run(2, descend(700))
T.check(out.m3_armed, "through 245 ft in landing configuration: mode 3 armed (p.166)")

-- mode 5 (p.174-178)
fresh(1200)
inp.gear_down = true
inp.cas = 150
inp.loc_dev, inp.loc_valid = 0.3, true
inp.gs_dev, inp.gs_valid = 0, true
run(20, descend(800))
T.check(inp.ra < 1000 and inp.ra > 900, "below 1,000 ft")
inp.gs_dev = 1.5
run(0.2)
T.check(out.m5 and out.voice == G.V_GLIDE_SLOPE, "1.5 dots below: GLIDE SLOPE")
T.check(out.gnd_prox_light, "GND PROX light")
inp.gs_dev = 1.0
run(0.2)
T.check(not out.m5, "1.0 dot: none")
inp.gs_dev = 1.5
inp.back_course = true
run(0.2)
T.check(not out.m5, "back course: none")
inp.back_course = false
inp.gs_inhb_push = true
run(0.1)
inp.gs_inhb_push = false
run(0.2)
T.check(not out.m5 and out.gs_inhibited, "G/S INHB below 1,000 ft: inhibited")
run(60, descend(1000))
T.check(not out.gs_inhibited, "below 30 ft: the inhibit ends")
-- the localizer captured only below 500 ft: not armed
fresh(450)
inp.gear_down = true
inp.cas = 150
inp.loc_dev, inp.loc_valid = 0.3, true
inp.gs_dev, inp.gs_valid = 2.5, true
run(1, descend(700))
T.check(not out.m5, "localizer only below 500 ft: mode 5 not armed")

-- mode 6: the callouts of the 405 (FCOM p.1578)
fresh(3000)
inp.gear_down = true
inp.cas = 160
local heard = {}
local last = 0
run(240, function()
    inp.vs = -900
    inp.ra = inp.ra - 900 / 60 * DT
    if inp.ra < 0 then inp.ra = 0 end
    if out.callout ~= 0 and out.callout ~= last then heard[#heard + 1] = out.callout end
    last = out.callout
end)
T.equal(table.concat(heard, ","), "2500,1000,500,100,50,40,30,20,10", "each callout once, in order")
-- a callout turned off in the CDU
fresh(1200)
inp.callout_off[500] = true
heard, last = {}, 0
run(80, function()
    inp.ra = inp.ra - 900 / 60 * DT
    if out.callout ~= 0 and out.callout ~= last then heard[#heard + 1] = out.callout end
    last = out.callout
end)
T.equal(heard[1], 1000, "1,000")
T.equal(heard[2], 100, "500 off: next 100")
-- the minimums (FCOM p.1578): APPROACHING MINIMUMS at + 80 ft, MINIMUMS
fresh(1200)
inp.gear_down, inp.flaps_landing = true, true
inp.mins = 200
local function to_mins() inp.ra = inp.ra - 600 / 60 * DT; inp.mins_ref = inp.ra end
heard, last = {}, 0
run(125, function()
    to_mins()
    if out.callout ~= 0 and out.callout ~= last then heard[#heard + 1] = out.callout end
    last = out.callout
end)
T.equal(table.concat(heard, ","), "1000,500,1,2,100,50,40,30,20,10", "... 500, APPROACHING MINIMUMS, MINIMUMS, 100 ...")
T.equal(out.callout, 0, "the callout code falls back to 0")

-- bank angle (FCOM p.1577: 35, 40, 45 deg; low altitude from 10 deg)
fresh(2000)
inp.roll = 30
run(1)
T.equal(out.voice, G.V_NONE, "30 deg: none")
inp.roll = 36
run(0.2)
T.equal(out.voice, G.V_BANK_ANGLE, "35 deg: BANK ANGLE")
run(3)
T.equal(out.voice, G.V_NONE, "once")
inp.roll = -41
run(0.2)
T.equal(out.voice, G.V_BANK_ANGLE, "40 deg: again")
run(3)
inp.roll = 29
run(0.2)
inp.roll = 36
run(0.2)
T.equal(out.voice, G.V_BANK_ANGLE, "back below 30 deg, then 35 again: again")
fresh(50)
inp.gear_down, inp.flaps_landing = true, true
inp.roll = 16
run(0.2)
T.equal(out.voice, G.V_BANK_ANGLE, "50 ft: from 15 deg (10 deg at 30 ft to 40 deg at 150 ft, p.184)")
T.check(not out.gnd_prox_light, "mode 6 does not light GND PROX (p.183)")

-- mode 7 (p.186-190, FCOM p.1581-1582)
fresh(1000)
inp.vs = -3000
inp.windshear = true
run(0.2)
T.check(out.windshear and out.warning and out.voice == G.V_WINDSHEAR, "windshear: WINDSHEAR, warning, the voice")
T.check(not out.pull_up and not out.gnd_prox_light, "the other alerts inhibited")
inp.windshear = false
run(3)
T.check(out.windshear, "at least 5 s")
run(2.2)
T.check(not out.windshear, "then over")
T.equal(out.voice, G.V_SINK_RATE, "the sink rate comes back")
fresh(1600)
inp.windshear = true
run(0.2)
T.check(not out.windshear, "above 1,500 ft: none")

-- the voice priority (estimate below the windshear and the warnings)
fresh(450)
inp.cas = 180
inp.vs = -2000
run(0.2)
T.check(out.m1 == 1 and out.m4 == G.V_TOO_LOW_GEAR, "SINK RATE and TOO LOW GEAR together")
T.equal(out.voice, G.V_TOO_LOW_GEAR, "one voice: TOO LOW GEAR")
-- no callout during a warning voice
fresh(1200)
inp.gear_down, inp.flaps_landing = true, true
inp.cas = 160
run(44, descend(900))
heard, last = {}, 0
run(1.5, function()
    descend(3000)()
    if out.callout ~= 0 and out.callout ~= last then heard[#heard + 1] = out.callout end
    last = out.callout
end)
T.check(inp.ra < 500, "through 500 ft")
T.equal(out.voice, G.V_PULL_UP, "PULL UP")
T.equal(#heard, 0, "no 500 callout during PULL UP")

-- EICAS (FCOM p.1538, p.1604-1605)
fresh(3000)
run(0.2)
T.check(not out.msg_gnd_prox_sys and not out.msg_alt_callouts and not out.msg_windshear_sys, "all working: none")
inp.power = false
run(0.2)
T.check(out.msg_gnd_prox_sys and out.msg_alt_callouts and out.msg_windshear_sys, "GPWC unpowered: GND PROX SYS, >ALT CALLOUTS, WINDSHEAR SYS")
T.equal(out.voice, G.V_NONE, "and silent")
inp.power = true
inp.terr_ovrd = true
inp.gps_valid = false
run(0.2)
T.check(out.msg_terr_ovrd and out.msg_terr_pos, ">TERR OVRD, TERR POS (no GPS)")
inp.flap_ovrd = true
inp.cas = 260
run(59)
T.check(not out.msg_gnd_prox_sys, "FLAP OVRD above 250 kt: not yet")
run(2)
T.check(out.msg_gnd_prox_sys, "for more than 60 s: GND PROX SYS")
T.done()
