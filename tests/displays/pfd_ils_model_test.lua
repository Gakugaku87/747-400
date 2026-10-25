-- Run from the repository root with LuaJIT: luajit tests/displays/pfd_ils_model_test.lua
-- The PFD ILS model (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/
-- B747.60.pfd_ils_model.lua, 5-2 step 4e) without X-Plane: the approach
-- reference, the localizer and glideslope scales and pointers, the LOC and
-- G/S flags, the deviation warnings and the rising runway (ATA34_1
-- p.466-470, ATA31 p.13, FCOM p.987-989).
local T = dofile("tests/lib/check.lua")("pfd_ils_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.pfd_ils_model.lua")

local DT = 1 / 30
local s, inp, out
local function run(seconds)
    for _ = 1, math.max(1, math.floor((seconds or 0) / DT + 0.5)) do out = M.update(s, inp, DT) end
end
-- the pointer's states over half a second (the flash: some frames dark)
local function states(p, key)
    local seen = {}
    for _ = 1, 15 do out = M.update(s, inp, DT); seen[out[p][key]] = true end
    return seen
end

s, inp = M.new(), M.inputs()
local c = inp.side[M.CAPT]
run()
local o = out[M.CAPT]
T.check(not o.ils and o.loc_scale == 0 and o.gs_scale == 0 and not o.loc_flag and not o.gs_flag,
    "no ILS tuned: nothing, no flags")

-- tuned, no signal: the scales without pointers (no computed data)
c.tuned = true
run()
T.check(o.ils, "tuned: the approach reference and course")
T.equal(o.loc_scale, 1, "no localizer signal: the scale")
T.equal(o.loc_ptr, 0, "no pointer")
T.equal(o.gs_scale, 1, "no glideslope signal: the scale")
T.equal(o.gs_ptr, 0, "no pointer")

-- signals: filled within 2 1/3 dots, hollow beyond; the expanded localizer
c.loc_rx, c.gs_rx = true, true
c.loc_dots, c.gs_dots = 1.5, -2
run()
T.equal(o.loc_ptr, 1, "localizer 1.5 dots: filled")
T.equal(o.loc_scale, 1, "the normal scale")
T.equal(o.gs_ptr, 1, "glideslope -2 dots: filled (either side)")
c.loc_dots, c.gs_dots = -2.4, 2.5
run()
T.equal(o.loc_ptr, 2, "localizer -2.4 dots: hollow (the left side too)")
T.equal(o.gs_ptr, 2, "glideslope 2.5 dots: hollow")
c.loc_dots = -0.4
run()
T.equal(o.loc_scale, 3, "within 1/2 dot: the expanded scale")
T.equal(o.loc_ptr, 3, "its pointer")
c.trk = false
run()
T.equal(o.loc_ptr, 0, "no track: no localizer pointer (ATA34_1 p.467)")
T.equal(o.loc_scale, 1, "the normal scale without a pointer")
c.trk = true

-- the rising runway: the localizer pointer in view below 2,500 ft
c.ra_show = true
run()
T.check(o.rwy, "the rising runway below 2,500 ft")
c.loc_rx = false
run()
T.check(not o.rwy, "no localizer pointer: no rising runway")
c.loc_rx = true

-- failures: the flag replaces the scale and pointer
c.gs_fail = true
run()
T.check(o.gs_flag and o.gs_scale == 0 and o.gs_ptr == 0, "glideslope invalid: the G/S flag, no scale or pointer")
T.check(o.ils and not o.loc_flag and o.loc_scale > 0, "the localizer and the approach reference stay")
c.gs_fail, c.loc_fail = false, true
run()
T.check(o.loc_flag and o.loc_scale == 0 and o.loc_ptr == 0 and not o.rwy, "localizer invalid: the LOC flag only")
c.loc_fail, c.rx_fail = false, true
run()
T.check(o.loc_flag and o.gs_flag and not o.ils, "the receiver failed: both flags, the reference and course blank")
c.rx_fail = false

-- beyond 53 degrees of roll: all removed, no flag
c.roll = -54
c.gs_fail = true
run()
T.check(not o.ils and o.loc_scale == 0 and o.gs_scale == 0 and not o.gs_flag, "roll 54 degrees: all removed")
c.roll, c.gs_fail = 10, false
run()
T.check(o.ils and o.loc_scale > 0 and o.gs_scale > 0, "roll 10 degrees: back")
T.check(not inp.side[M.FO].tuned and out[M.FO].loc_scale == 0, "the F/O's ILS not tuned: nothing on the F/O's PFD")

-- the glideslope warning: G/S engaged with the A/P or F/D, 100-500 ft,
-- beyond 5/8 dot (ATA34_1 p.468)
c.loc_dots, c.gs_dots = 0, 0.7
c.ra, c.ra_valid, c.guidance = 400, true, true
inp.gs_active = true
run()
T.equal(o.gs_scale, 2, "G/S, 400 ft, 0.7 dot: the scale amber")
local seen = states(M.CAPT, "gs_ptr")
T.check(seen[0] and seen[1], "the pointer flashes (4 Hz)")
c.gs_dots = 0.6
run()
T.equal(o.gs_scale, 1, "0.6 dot: within 5/8")
T.equal(o.gs_ptr, 1, "steady")
c.gs_dots, c.ra = 0.7, 550
run()
T.equal(o.gs_scale, 1, "550 ft: no warning")
c.ra = 90
run()
T.equal(o.gs_scale, 1, "90 ft: no warning")
c.ra, c.guidance = 400, false
run()
T.equal(o.gs_scale, 1, "no A/P or flight director: no warning (FCOM p.987)")
c.guidance, inp.gs_active = true, false
run()
T.equal(o.gs_scale, 1, "G/S not engaged: no warning")
inp.gs_active = true
c.ra_valid = false
run()
T.equal(o.gs_scale, 1, "no radio altitude: no warning")
c.ra_valid, c.gs_dots = true, 0

-- the localizer warning: LOC engaged, below 500 ft, beyond 1/4 dot for 1 s
inp.loc_active = true
c.loc_dots = 0.3
run(0.9)
T.equal(o.loc_scale, 3, "0.3 dot for 0.9 s: not yet")
run(0.2)
T.equal(o.loc_scale, 4, "for 1 s: the expanded scale amber")
seen = states(M.CAPT, "loc_ptr")
T.check(seen[0] and seen[3], "the pointer flashes")
c.loc_dots = 0.2
run()
T.equal(o.loc_scale, 3, "within 1/4 dot: no warning")
c.loc_dots = 0.8
run(1.1)
T.equal(o.loc_scale, 2, "0.8 dot: the normal scale amber")
c.ra = 600
run()
T.equal(o.loc_scale, 1, "600 ft: no warning")
c.loc_dots = 0
inp.loc_active = false

-- LOC capture fail: LNAV engaged and LOC armed below 950 ft; reset at
-- 1,050 ft or by the capture
inp.lnav_active, inp.loc_armed = true, true
c.loc_dots, c.ra = 1.2, 1000
run()
T.equal(o.loc_scale, 1, "LNAV, LOC armed, 1,000 ft: no warning")
c.ra = 940
run()
T.equal(o.loc_scale, 2, "below 950 ft not captured: the scale amber (LOC capture fail)")
c.ra = 1000
run()
T.equal(o.loc_scale, 2, "back to 1,000 ft: held")
c.ra = 1060
run()
T.equal(o.loc_scale, 1, "1,060 ft: reset")
c.ra = 900
run()
T.equal(o.loc_scale, 2, "900 ft again")
inp.loc_armed, inp.loc_active, inp.lnav_active = false, true, false
c.loc_dots = 0.1
run()
T.equal(o.loc_scale, 3, "captured: reset (and within 1/4 dot)")

-- the F/O's side alone
local f = inp.side[M.FO]
f.tuned, f.loc_rx, f.gs_rx, f.loc_dots, f.gs_dots = true, true, true, 1, 1
run()
T.check(out[M.FO].ils and out[M.FO].loc_ptr == 1 and out[M.FO].gs_ptr == 1, "the F/O's ILS R: shown")
T.equal(out[M.FO].gs_scale, 1, "the F/O's radio altitude not valid: no warning on that side")

T.done()
