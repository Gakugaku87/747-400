-- Run from the repository root with LuaJIT: luajit tests/fms/efb_limits_model_test.lua
-- The EFB's takeoff limits (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/
-- B747.68.efb_limits_model.lua; 2026-11-25) from the 747-400F/PW4056 FPPM:
-- Takeoff Climb Limit p.29 (1.2.5) flaps 10 and p.30 (1.2.6) flaps 20, Tire
-- Speed Limit p.33 (1.2.9), Brake Energy Limit VMBE p.34 (1.2.10); the
-- methods p.19-20 (1.1.1-1.1.2) and p.22 (1.1.4). The data are written by
-- docs/overhaul/tools/fppm_takeoff_limits.lua from the PDF's drawings.
local T = dofile("tests/lib/check.lua")("efb_limits_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_limits_model.lua")

T.check(B747_efb_limits_model == M and getmetatable(M) ~= nil, "the module: a global with a metatable (XTLua namespaces)")

------------------------------------------------------------------------
-- the data's shape
------------------------------------------------------------------------
for _, f in ipairs({10, 20}) do
    local ch = M.CLIMB[f]
    T.equal(#ch.alt, 13, "climb flaps " .. f .. ": 13 altitudes")
    T.check(ch.alt[1] == -2 and ch.alt[13] == 10, "climb flaps " .. f .. ": -2,000 to 10,000 ft")
    T.equal(#ch.curve, 13, "climb flaps " .. f .. ": a curve an altitude")
    T.equal(#ch.env, 13, "climb flaps " .. f .. ": an environmental limit an altitude")
    for n, c in ipairs(ch.curve) do
        local ok = c[1] == 0 and #c % 2 == 0
        for k = 3, #c, 2 do ok = ok and c[k] > c[k - 2] end
        T.check(ok, "climb flaps " .. f .. " " .. ch.alt[n] .. ": OAT from 0 C, rising")
    end
end
T.equal(#M.TIRE.curve, 13, "tire: 13 altitude curves")
T.equal(#M.VMBE.oat, 12, "VMBE: 12 OAT lines (-50 to 60 C)")
T.equal(#M.VMBE.wt, 9, "VMBE: 9 weight lines (240 to 400 t)")

------------------------------------------------------------------------
-- the notes as printed
------------------------------------------------------------------------
T.equal(M.CLIMB[10].notes.packs_off, 4200, "p.29: packs off +4200 kg")
T.equal(M.CLIMB[10].notes.one_pack, 3000, "p.29: 1 pack +3000 kg")
T.equal(M.CLIMB[10].notes.apu_one_pack, 3800, "p.29: engine bleed off, APU 1 pack +3800 kg")
T.equal(M.CLIMB[20].notes.packs_off, 4500, "p.30: packs off +4500 kg")
T.equal(M.CLIMB[20].notes.one_pack, 3000, "p.30: 1 pack +3000 kg")
T.equal(M.CLIMB[20].notes.apu_one_pack, 4100, "p.30: engine bleed off, APU 1 pack +4100 kg")
T.equal(M.TIRE.notes.flaps20, 19000, "p.33: flaps 20 +19000 kg")
T.equal(M.TIRE.notes.head, 2200, "p.33: +2200 kg a knot headwind")
T.equal(M.TIRE.notes.tail, 3900, "p.33: -3900 kg a knot tailwind")
local VN = M.VMBE.notes
T.check(VN.up == 4 and VN.down == 8, "p.34: +4 kt a 1 % uphill, -8 kt a 1 % downhill")
T.check(VN.head == 3 and VN.head_per == 10 and VN.tail == 29 and VN.tail_per == 10,
    "p.34: +3 kt for 10 kt headwind, -29 kt for 10 kt tailwind")
T.equal(VN.brakes2, 24, "p.34: -24 kt for two brakes deactivated")
T.check(VN.per_kt == 1500 and VN.per_kt_ic == 500, "p.34: 1500 kg (normal), 500 kg (improved climb) a knot V1 over VMBE")

------------------------------------------------------------------------
-- Takeoff Climb Limit
------------------------------------------------------------------------
-- p.30's printed example (dashed, arrows): up from 30 C (the line is drawn
-- at 30.4 C) to the 0 ft curve, left to 437 t (drawn at 437.1 t)
T.near(M.climb_limit(20, 30, 0), 437100, 1000, "p.30 example: 30 C, 0 ft -> 437 t")
T.near(M.climb_limit(20, 30.42, 0), 437130, 500, "p.30 example as drawn: 30.4 C, 0 ft -> 437.1 t")

-- p.29 has no example: points read from the drawing's own (unthinned)
-- strokes, which the model's data overlay on the page image; within 0.5 t
local READ = {
    -- flaps, OAT C, 1000 ft, 1000 kg
    {10, 0, -2, 462.55}, {10, 0, 0, 455.30}, {10, 0, 2, 436.41}, {10, 0, 5, 406.20}, {10, 0, 10, 360.18},
    {10, 40, 0, 427.55}, {10, 30, 5, 388.46}, {10, 45, 2, 379.36}, {10, 50, 8, 283.55}, {10, 25, 10, 332.05},
    {10, 60, -1, 349.00}, {10, 20, 6, 398.25},
    {20, 40, 0, 411.46}, {20, 30, 5, 374.75}, {20, 45, 2, 365.90}, {20, 50, 8, 272.81}, {20, 25, 10, 318.82},
    {20, 60, -1, 335.90}, {20, 20, 6, 383.82},
}
for _, r in ipairs(READ) do
    T.near(M.climb_limit(r[1], r[2], r[3] * 1000), r[4] * 1000, 500,
        string.format("climb flaps %d, %d C, %d ft: the drawn curve", r[1], r[2], r[3] * 1000))
end
-- the flat parts as drawn: flaps 20's at 0 C
T.near(M.climb_limit(20, 0, -2000), 445900, 300, "climb flaps 20 -2,000 ft: 445.9 t below the break")
T.near(M.climb_limit(20, 0, 10000), 345700, 300, "climb flaps 20 10,000 ft: 345.7 t below the break")
-- 0 C and below: the 0 C value
T.equal(M.climb_limit(10, -20, 3000), M.climb_limit(10, 0, 3000), "climb: -20 C reads 0 C (\"0 AND BELOW\")")
-- between the curves: linear in altitude
do
    local a, b = M.climb_limit(10, 45, 3000), M.climb_limit(10, 45, 4000)
    T.near(M.climb_limit(10, 45, 3500), (a + b) / 2, 1e-6, "climb: 3,500 ft halfway between 3,000 and 4,000 ft")
end
-- the weight falls with OAT and with altitude (the flats rise by up to
-- 0.3 t as drawn: 0.5 t allowed)
for _, f in ipairs({10, 20}) do
    local ok_t, ok_a, worst = true, true, ""
    for pa = -2000, 10000, 250 do
        local prev
        for oat = 0, 75, 0.5 do
            local w = M.climb_limit(f, oat, pa)
            if w then
                if prev and w > prev + 500 then ok_t, worst = false, oat .. " C " .. pa .. " ft" end
                prev = w
                local up = M.climb_limit(f, oat, pa + 250)
                if pa < 10000 and up and up > w + 500 then ok_a, worst = false, oat .. " C " .. pa .. " ft" end
            end
        end
    end
    T.check(ok_t, "climb flaps " .. f .. ": weight falls as the OAT rises " .. worst)
    T.check(ok_a, "climb flaps " .. f .. ": weight falls as the altitude rises " .. worst)
end
-- the limits: environmental (54.4 C = 130 F to 0 ft, then 2 C a 1000 ft)
-- and assumed temperature (75.1 C at -2,000 ft, 51.3 C at 10,000 ft)
do
    local env, atl = M.climb_oat_limits(10, 0)
    T.near(env, 54.4, 0.1, "climb flaps 10, 0 ft: environmental limit 54.4 C")
    T.near(atl, 71.1, 0.1, "climb flaps 10, 0 ft: assumed temperature limit 71.1 C")
    env = M.climb_oat_limits(10, -2000)
    T.near(env, 54.4, 0.1, "climb flaps 10, -2,000 ft: environmental limit 54.4 C")
    env, atl = M.climb_oat_limits(20, 10000)
    T.near(env, 34.6, 0.1, "climb flaps 20, 10,000 ft: environmental limit 34.6 C")
    T.near(atl, 51.3, 0.1, "climb flaps 20, 10,000 ft: assumed temperature limit 51.3 C")
    env = M.climb_oat_limits(20, 5000)
    T.near(env, 44.5, 0.1, "climb flaps 20, 5,000 ft: environmental limit 44.5 C")
end
do
    local w, note = M.climb_limit(10, 50, 0)
    T.check(w and note == nil, "climb: 50 C at 0 ft inside the environmental limit, no note")
    w, note = M.climb_limit(10, 60, 0)
    T.check(w and type(note) == "string" and note:find("environmental"), "climb: 60 C at 0 ft right of the environmental limit: a note")
    T.near(w, M.climb_limit(10, 60, 0), 0, "climb: the weight there all the same")
    T.check(M.climb_limit(10, 72, 0) == nil, "climb: 72 C at 0 ft right of the assumed temperature limit: nil")
    T.check(M.climb_limit(10, 71, 0) ~= nil, "climb: 71 C at 0 ft just inside the assumed temperature limit")
end
-- outside the chart
T.check(M.climb_limit(10, 20, 10500) == nil, "climb: 10,500 ft: nil")
T.check(M.climb_limit(10, 20, -2500) == nil, "climb: -2,500 ft: nil")
T.check(M.climb_limit(5, 20, 0) == nil, "climb: flaps 5: nil")
T.check(M.climb_limit(10, nil, 0) == nil, "climb: no OAT: nil")
-- the notes' adjustments
T.equal(M.climb_bleed_adjust_kg(10, 3, false, false), 0, "climb flaps 10: 3 packs, the basis")
T.equal(M.climb_bleed_adjust_kg(10, 0, false, false), 4200, "climb flaps 10: packs off +4200 kg")
T.equal(M.climb_bleed_adjust_kg(10, 1, false, false), 3000, "climb flaps 10: 1 pack +3000 kg")
T.equal(M.climb_bleed_adjust_kg(10, 0, false, false, true), 3800, "climb flaps 10: APU 1 pack +3800 kg")
T.equal(M.climb_bleed_adjust_kg(20, 0, false, false), 4500, "climb flaps 20: packs off +4500 kg")
T.equal(M.climb_bleed_adjust_kg(20, 1, false, false), 3000, "climb flaps 20: 1 pack +3000 kg")
T.equal(M.climb_bleed_adjust_kg(20, 0, false, false, true), 4100, "climb flaps 20: APU 1 pack +4100 kg")
T.equal(M.climb_bleed_adjust_kg(20, 3, true, true), 0, "climb: anti-ice on changes nothing (\"anti-ice on or off\")")
T.equal(M.climb_bleed_adjust_kg(10, 1, true, true), 3000, "climb: anti-ice on with 1 pack: the pack's +3000 kg only")
T.equal(M.climb_bleed_adjust_kg(10, 2, false, false), 0, "climb: 2 packs, no increase (estimate)")
T.check(M.climb_bleed_adjust_kg(10, 4) == nil, "climb: 4 packs: nil")
T.check(M.climb_bleed_adjust_kg(15, 3) == nil, "climb: flaps 15: nil")

------------------------------------------------------------------------
-- Tire Speed Limit
------------------------------------------------------------------------
-- p.33 has no example: points read from the drawing's strokes, within 0.5 t
local TREAD = {
    {30, 0, 450.87}, {40, 5, 352.50}, {50, 2, 382.00}, {0, 8, 360.54},
    {-30, 10, 368.21}, {60, 3, 353.38}, {20, 6, 364.50}, {-10, 9, 357.61},
}
for _, r in ipairs(TREAD) do
    T.near(M.tire_limit(10, r[1], r[2] * 1000, 0), r[3] * 1000, 500,
        string.format("tire flaps 10, %d C, %d ft: the drawn curve", r[1], r[2] * 1000))
end
-- the step drawn in every curve (about 9.5 t within 1 C) at 0 ft: 66 to 67 C
T.near(M.tire_limit(10, 66, 0, 0) - M.tire_limit(10, 67, 0, 0), 9500, 300, "tire 0 ft: the drawn step from 66 to 67 C")
-- the notes
do
    local w10 = M.tire_limit(10, 40, 5000, 0)
    T.near(M.tire_limit(20, 40, 5000, 0) - w10, 19000, 1e-6, "tire: flaps 20 +19000 kg")
    T.near(M.tire_limit(10, 40, 5000, 10) - w10, 22000, 1e-6, "tire: 10 kt headwind +22000 kg")
    T.near(M.tire_limit(10, 40, 5000, -5) - w10, -19500, 1e-6, "tire: 5 kt tailwind -19500 kg")
    T.near(M.tire_limit(20, 40, 5000, -10) - w10, 19000 - 39000, 1e-6, "tire: flaps 20 and 10 kt tailwind")
end
-- falls with OAT and altitude
do
    local ok_t, ok_a, worst = true, true, ""
    for pa = -2000, 10000, 250 do
        local prev
        for oat = -50, 70, 0.5 do
            local w = M.tire_limit(10, oat, pa, 0)
            if w then
                if prev and w > prev + 1e-6 then ok_t, worst = false, oat .. " C " .. pa .. " ft" end
                prev = w
                local up = M.tire_limit(10, oat, pa + 250, 0)
                if pa < 10000 and up and up > w + 1e-6 then ok_a, worst = false, oat .. " C " .. pa .. " ft" end
            end
        end
    end
    T.check(ok_t, "tire: weight falls as the OAT rises " .. worst)
    T.check(ok_a, "tire: weight falls as the altitude rises " .. worst)
end
-- above the chart's top: the top as a lower bound with a note
do
    local w, note = M.tire_limit(10, 20, 0, 0)
    T.check(w == 460000 and type(note) == "string", "tire: 20 C at 0 ft above the chart: 460 t, a note")
    w, note = M.tire_limit(20, 20, 0, -10)
    T.check(w == 460000 + 19000 - 39000 and note, "tire: above the chart, then the notes")
    w, note = M.tire_limit(10, 40, 5000, 0)
    T.check(w and note == nil, "tire: inside the chart, no note")
end
-- outside the chart
T.check(M.tire_limit(10, -55, 8000, 0) == nil, "tire: -55 C: nil")
T.check(M.tire_limit(10, 70.5, 0, 0) == nil, "tire: 70.5 C: nil")
T.check(M.tire_limit(10, 62.5, 5000, 0) == nil, "tire: 62.5 C at 5,000 ft past the curve's end (62 C): nil")
T.check(M.tire_limit(10, 62, 5000, 0) ~= nil, "tire: 62 C at 5,000 ft, the curve's end")
T.check(M.tire_limit(10, 52, 10000, 0) == nil, "tire: 52 C at 10,000 ft under the chart: nil")
T.check(M.tire_limit(10, 20, 10500, 0) == nil, "tire: 10,500 ft: nil")
T.check(M.tire_limit(15, 20, 0, 0) == nil, "tire: flaps 15: nil")

------------------------------------------------------------------------
-- Brake Energy Limit VMBE
------------------------------------------------------------------------
-- p.34's printed example (dashed, arrows): 373 t (drawn at 373.4 t) up to
-- 400 ft (drawn at 402 ft), just outside the shaded area (its edge there
-- 367.5 t, where the entry line stops); right to 30 C (drawn at 29.7 C),
-- down to the weight, right: 186 kt (drawn at 186.0 kt). The lines there
-- give 184.9 kt (the drawn turn sits at 370.4 t between 360 and 380 t)
T.near(M.vmbe(373400, 30, 400, 0, 0), 186, 1.5, "p.34 example: 373.4 t, 400 ft, 30 C -> 186 kt")
T.near(M.vmbe(373400, 29.71, 402, 0, 0), 186, 1.5, "p.34 example as drawn -> 186 kt")
T.near(M.vmbe_shaded_max_kg(402), 367500, 300, "p.34 example: the shaded area's edge at 402 ft, 367.5 t")
T.equal(M.vmbe_check_needed(373400, 400), true, "p.34 example: outside the shaded area, check VMBE")
-- the shaded area (from 300 t at -2,000 to 10,000 ft, to 379.2 t at
-- -2,000 ft and 320.8 t at 10,000 ft)
T.near(M.vmbe_shaded_max_kg(-2000), 379200, 300, "shaded: 379.2 t at -2,000 ft")
T.near(M.vmbe_shaded_max_kg(10000), 320800, 300, "shaded: 320.8 t at 10,000 ft")
T.equal(M.vmbe_check_needed(360000, 400), false, "shaded: 360 t at 400 ft inside: no check")
T.equal(M.vmbe_check_needed(378000, -2000), false, "shaded: 378 t at -2,000 ft inside")
T.equal(M.vmbe_check_needed(381000, -2000), true, "shaded: 381 t at -2,000 ft outside")
T.equal(M.vmbe_check_needed(320000, 9000), false, "shaded: 320 t at 9,000 ft inside")
T.equal(M.vmbe_check_needed(330000, 9000), true, "shaded: 330 t at 9,000 ft outside")
T.equal(M.vmbe_check_needed(250000, 5000), false, "shaded: lighter than the chart (250 t): inside")
T.equal(M.vmbe_check_needed(300000, 11000), true, "shaded: above the chart's altitudes: check")
-- VMBE falls with weight, altitude and temperature
do
    local okw, oka, okt, worst = true, true, true, ""
    for _, pa in ipairs({-2000, 0, 2000, 5000, 8000, 10000}) do
        for oat = -50, 60, 5 do
            for wt = 240, 400, 10 do
                local v = M.vmbe(wt * 1000, oat, pa, 0, 0)
                local vw = wt < 400 and M.vmbe((wt + 10) * 1000, oat, pa, 0, 0)
                local va = pa < 10000 and M.vmbe(wt * 1000, oat, pa + 1000, 0, 0)
                local vt = oat < 60 and M.vmbe(wt * 1000, oat + 5, pa, 0, 0)
                if vw and vw > v + 1e-6 then okw, worst = false, wt .. " t " .. oat .. " C " .. pa .. " ft" end
                if va and va > v + 1e-6 then oka, worst = false, wt .. " t " .. oat .. " C " .. pa .. " ft" end
                if vt and vt > v + 1e-6 then okt, worst = false, wt .. " t " .. oat .. " C " .. pa .. " ft" end
            end
        end
    end
    T.check(okw, "VMBE falls as the weight rises " .. worst)
    T.check(oka, "VMBE falls as the altitude rises " .. worst)
    T.check(okt, "VMBE falls as the OAT rises " .. worst)
end
-- inside the lines: a hot, high, heavy case
do
    local v, note = M.vmbe(396000, 40, 5000, 0, 0)
    T.near(v, 161.5, 0.5, "VMBE 396 t, 40 C, 5,000 ft: 161.5 kt")
    T.check(note == nil, "VMBE inside the lines: no note")
    local a, b = M.vmbe(340000, 30, 8000, 0, 0), M.vmbe(360000, 30, 8000, 0, 0)
    T.near(M.vmbe(350000, 30, 8000, 0, 0), (a + b) / 2, 1e-9, "VMBE: 350 t halfway between the 340 and 360 t lines")
end
-- the table: slope, wind, brakes
do
    local v0 = M.vmbe(380000, 35, 3000, 0, 0)
    T.near(M.vmbe(380000, 35, 3000, 1, 0) - v0, 4, 1e-9, "VMBE: 1 % uphill +4 kt")
    T.near(M.vmbe(380000, 35, 3000, -1, 0) - v0, -8, 1e-9, "VMBE: 1 % downhill -8 kt")
    T.near(M.vmbe(380000, 35, 3000, -0.5, 0) - v0, -4, 1e-9, "VMBE: 0.5 % downhill -4 kt")
    T.near(M.vmbe(380000, 35, 3000, 0, 10) - v0, 3, 1e-9, "VMBE: 10 kt headwind +3 kt")
    T.near(M.vmbe(380000, 35, 3000, 0, -10) - v0, -29, 1e-9, "VMBE: 10 kt tailwind -29 kt")
    T.near(M.vmbe(380000, 35, 3000, 0, -5) - v0, -14.5, 1e-9, "VMBE: 5 kt tailwind -14.5 kt")
    T.near(M.vmbe(380000, 35, 3000, -1, -10) - v0, -37, 1e-9, "VMBE: downhill and tailwind together")
    T.near(M.vmbe(380000, 35, 3000, 0, 0, 2) - v0, -24, 1e-9, "VMBE: two brakes deactivated -24 kt")
    T.near(M.vmbe(380000, 35, 3000, 0, 0, 1) - v0, -24, 1e-9, "VMBE: one brake deactivated -24 kt (p.22)")
    T.check(M.vmbe(380000, 35, 3000, 0, 0, 3) == nil, "VMBE: three brakes deactivated: nil")
end
T.equal(M.vmbe_brakes_deactivated_kt(0), 0, "brakes: none deactivated, 0 kt")
T.equal(M.vmbe_brakes_deactivated_kt(1), 24, "brakes: one deactivated, 24 kt (p.22)")
T.equal(M.vmbe_brakes_deactivated_kt(2), 24, "brakes: two deactivated, 24 kt (p.34)")
T.check(M.vmbe_brakes_deactivated_kt(3) == nil, "brakes: three: nil")
T.equal(M.vmbe_weight_per_kt(), 1500, "V1 over VMBE: 1500 kg a knot (normal takeoff)")
T.equal(M.vmbe_weight_per_kt(true), 500, "V1 over VMBE: 500 kg a knot of climb weight improvement (improved climb)")
-- the chart's edges: lower bounds with a note
do
    local v, note = M.vmbe(250000, 0, 0, 0, 0)
    T.check(v == 210 and type(note) == "string", "VMBE: light and cold, above 210 kt: 210 kt, a note")
    -- 396 t at the lines' end: 380 t 188.6 kt, 400 t 183.0 kt
    v, note = M.vmbe(396000, -10, 0, 0, 0)
    T.check(v and type(note) == "string" and math.abs(v - 184.1) < 0.3, "VMBE: cold and low, right of the lines: the lines' end (184.1 kt), a note")
    v, note = M.vmbe(396000, -10, 0, 0, -10)
    T.check(v and math.abs(v - (184.1 - 29)) < 0.3 and note, "VMBE: a bound, then the tailwind")
    v, note = M.vmbe(220000, 50, 9000, 0, 0)
    T.check(v and type(note) == "string" and math.abs(v - M.vmbe(240000, 50, 9000, 0, 0)) < 1e-9,
        "VMBE: under 240 t: the 240 t line, a note")
end
-- outside the chart
T.check(M.vmbe(410000, 30, 0, 0, 0) == nil, "VMBE: 410 t: nil")
T.check(M.vmbe(380000, 61, 0, 0, 0) == nil, "VMBE: 61 C: nil")
T.check(M.vmbe(380000, -51, 0, 0, 0) == nil, "VMBE: -51 C: nil")
T.check(M.vmbe(380000, 30, 10500, 0, 0) == nil, "VMBE: 10,500 ft: nil")
T.check(M.vmbe(380000, 30, -2500, 0, 0) == nil, "VMBE: -2,500 ft: nil")

T.done()
