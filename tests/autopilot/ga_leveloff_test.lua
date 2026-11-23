-- Run from the repository root with LuaJIT: luajit tests/autopilot/ga_leveloff_test.lua
-- (2026-11-23 review AFDS-1) G/A's level-off: at the MCP altitude the pitch
-- goes to ALT and the A/T stays in THR (or THR REF) until SPD is selected;
-- the speed protection keeps the speed under the maximum operating, gear
-- extended or flap placard speed (FCOM p.673 (4.20.15), p.675 (4.20.17)).
-- Before, G/A's THR (the first push) held its 2,000 fpm energy rate in
-- level flight: on this model the speed passed the flaps 20 placard (230
-- kt) 60 s after the capture and went on to 384 kt; X-Plane's v07
-- (2026-11-23) 163 to 238 kt in 69 s. THR REF (the second push) had the
-- limit speed's law already. On tests/lib/energy_sim.lua (the A/T's and the
-- pitch laws' own models): 160 kt at flaps 20, G/A from 1,000 ft, the
-- capture of 3,000 ft (the review's ga_leveloff.lua). The model's excess
-- thrust does not change with the speed: the speed it settles at is the
-- protection's, not X-Plane's.
local T = dofile("tests/lib/check.lua")("ga_leveloff")
local Sim = dofile("tests/lib/energy_sim.lua")
local A, P = Sim.A, Sim.P

local PLACARD = 230                  -- flaps 20 (laminar/B747/airspeed/Vmax)
local LIMIT = PLACARD - A.LIMIT_MARGIN

-- the G/A and its level-off: the IAS's most after the capture, the A/T's
-- FMA through it, the IAS at the end
local function fly(second_push, ps_ref)
    local m = Sim.new{alt = 1000, ias = 160, ps_ref = ps_ref, ps_idle = -1500, lever = 0.35}
    m.at_inp.flaps_up = false
    m.at_inp.limit_to, m.at_inp.limit_ga = false, true
    m.at_inp.ra = 1000
    m.servo_inp.flaps_up = false
    m.servo_inp.v_max, m.servo_inp.v_min = PLACARD, 140
    m.servo_inp.mcp_alt = 3000
    m.pitch_inp.flaps_up = false
    m.pitch_inp.v_max, m.pitch_inp.v_min = PLACARD, 140
    m.target = {ias = 160}
    -- the approach's SPD, then the TO/GA push (a second for THR REF)
    m.at_inp.pitch = "GS"
    m.pitch_inp.mode, m.pitch_inp.vs_sel = "VS", -700
    m.vs = -700
    m.at_inp.spd = true
    m:run(1)
    m.at_inp.toga, m.at_inp.pitch, m.pitch_inp.mode = true, "GA", "GA"
    m:run(0.05)
    if second_push then m.at_inp.toga = true m:run(0.05) end
    local r = {ias_max = 0, fma_min = 9, fma_max = 0}
    m:run(240, function(mm)
        mm.at_inp.ra = mm.alt
        if not r.t_cap and mm.alt > 800 and P.capture(mm.pitch_inp, 3000) then
            r.t_cap = mm.t
            mm.pitch_inp.mode, mm.pitch_inp.hold_alt = "ALT", 3000
            mm.at_inp.pitch = "ALT"
        end
        if r.t_cap then
            r.ias_max = math.max(r.ias_max, mm.ias)
            r.fma_min, r.fma_max = math.min(r.fma_min, mm.fma), math.max(r.fma_max, mm.fma)
        end
    end)
    r.ias_end, r.alt_end = m.ias, m.alt
    return r
end

-- the first push (THR), 3,500 fpm of excess at the reference (a 260 t
-- airplane, the review's estimate) and a heavier one's 2,600
for _, ps in ipairs({3500, 2600}) do
    local r = fly(false, ps)
    T.check(r.t_cap ~= nil, string.format("THR, excess %d fpm: 3,000 ft captured", ps))
    T.check(r.fma_min == A.THR and r.fma_max == A.THR,
        string.format("THR, excess %d fpm: the A/T in THR through the level-off (FCOM p.673)", ps))
    -- the limit speed the placard less 5: the FMC's margin against the
    -- overshoots (FCOM p.675); THR REF's law (the same) goes 6 to 7 kt
    -- over it here (the engines' 3 s)
    T.check(r.ias_max <= PLACARD, string.format(
        "THR, excess %d fpm: the IAS after the capture at most %.1f kt, not over the placard %d (FCOM p.673; before over it in 60 s, 384 kt at 240 s)",
        ps, r.ias_max, PLACARD))
    T.check(math.abs(r.ias_end - LIMIT) < 2, string.format(
        "THR, excess %d fpm: 240 s on held at the limit speed (%.1f kt for %d)", ps, r.ias_end, LIMIT))
    T.check(math.abs(r.alt_end - 3000) < 20, string.format("THR, excess %d fpm: ALT held (%.0f ft)", ps, r.alt_end))
end
-- the second push (THR REF): its limit speed's law as before
local r2 = fly(true, 3500)
T.check(r2.fma_min == A.THR_REF and r2.fma_max == A.THR_REF, "THR REF: kept through the level-off")
T.check(r2.ias_max <= PLACARD + 3, string.format("THR REF: the IAS at most %.1f kt (232.4 before: unchanged)", r2.ias_max))
T.check(math.abs(r2.ias_end - LIMIT) < 2, string.format("THR REF: held at the limit speed (%.1f kt)", r2.ias_end))

T.done()
