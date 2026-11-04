-- Run from the repository root with LuaJIT: luajit tests/nav/ils_ant_model_test.lua
-- The ILS antenna switching model (plugins/xtlua/scripts/B747.34.xt.nav/
-- B747.34.ils_ant_model.lua; 2026-11-04, for the failure window) against
-- ATA34_1 p.478, p.482-492 and FCOM p.1429: the VOR/LOC relay on the fin's
-- VOR antenna in the air outside APP/LOC, on the nose's localizer antenna
-- otherwise; the G/S relay on the capture antenna with the nose gear not
-- down and locked, on the track antenna when it is; a stuck relay: STATUS
-- LOC or G/S ANTENNA n, ILS ANTENNA for two or more of one kind.
local T = dofile("tests/lib/check.lua")("ils_ant_model")
local A = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.ils_ant_model.lua")

local function run(s, inp, frames)
    local out
    for _ = 1, frames or 1 do out = A.update(s, inp, 1 / 30) end
    return out
end
local function none(out)
    for n = 1, 3 do if out.loc_status[n] or out.gs_status[n] then return false end end
    return not out.ils_antenna
end

-- the relays follow their commands: no message through a flight
do
    local s, inp = A.new(), A.inputs()
    local out = run(s, inp)
    T.check(not out.loc_vor[1] and not out.gs_capture[1], "on the ground, gear down: the localizer and track antennas")
    T.check(none(out), "on the ground: no message")
    inp.on_ground, inp.nose_down = false, false
    out = run(s, inp)
    T.check(out.loc_vor[2] and out.gs_capture[2], "in the air, gear up: the VOR and capture antennas")
    T.check(none(out), "climb: no message")
    inp.fcc_app_loc = true
    out = run(s, inp)
    T.check(not out.loc_vor[3], "APP/LOC: the localizer antenna")
    inp.nose_down = true
    out = run(s, inp)
    T.check(not out.gs_capture[3], "gear down: the track antenna")
    T.check(none(out), "approach: no message")
end

-- stuck relays (failed in cruise): on the approach the localizer relays
-- stay on the VOR antenna, the G/S relays on the capture antenna
do
    local s, inp = A.new(), A.inputs()
    inp.on_ground, inp.nose_down = false, false
    run(s, inp)
    inp.loc_stuck[1] = true
    inp.gs_stuck[2], inp.gs_stuck[3] = true, true
    local out = run(s, inp)
    T.check(none(out), "stuck in cruise: nothing to switch yet, no message")
    inp.fcc_app_loc = true
    out = run(s, inp)
    T.check(out.loc_status[1] and not out.loc_status[2], "APP/LOC: STATUS LOC ANTENNA L")
    T.check(not out.ils_antenna, "one localizer relay: no ILS ANTENNA")
    inp.nose_down = true
    out = run(s, inp)
    T.check(out.gs_status[2] and out.gs_status[3] and not out.gs_status[1], "gear down: STATUS G/S ANTENNA C and R")
    T.check(out.ils_antenna, "two G/S relays: ILS ANTENNA")
    inp.gs_stuck[3] = false
    out = run(s, inp)
    T.check(not out.gs_status[3] and not out.gs_capture[3], "R freed: on the track antenna, no STATUS")
    T.check(not out.ils_antenna, "one G/S and one LOC: no ILS ANTENNA (two of one kind)")
    inp.loc_stuck[2] = true
    out = run(s, inp)
    T.check(not out.loc_status[2], "C stuck where it already is: no STATUS")
    inp.loc_stuck[1], inp.loc_stuck[2], inp.gs_stuck[2] = false, false, false
    out = run(s, inp)
    T.check(none(out), "all freed: no message")
end

-- two localizer relays stuck on the ground: in the air outside APP/LOC
-- they should go to the VOR antenna
do
    local s, inp = A.new(), A.inputs()
    run(s, inp)
    inp.loc_stuck[1], inp.loc_stuck[3] = true, true
    local out = run(s, inp)
    T.check(none(out), "stuck on the ground: no message yet")
    inp.on_ground, inp.nose_down = false, false
    out = run(s, inp)
    T.check(out.loc_status[1] and out.loc_status[3] and out.ils_antenna, "airborne: LOC ANTENNA L and R, ILS ANTENNA")
end

T.done()
