-- Run from the repository root with LuaJIT: luajit tests/fms/efb_field_model_test.lua
-- The EFB's takeoff field length limit (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.efb_field_model.lua; 2026-11-25): the FPPM's
-- Takeoff Field Limit charts, flaps 10 FPPM p.27 (1.2.3) and flaps 20 FPPM
-- p.28 (1.2.4) (747-400F/PW4056), read from the PDF's drawing by
-- docs/overhaul/tools/fppm_field_limit.lua.
local T = dofile("tests/lib/check.lua")("efb_field_model")
local F = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_field_model.lua")

T.check(B747_efb_field_model == F and getmetatable(F) ~= nil, "the module's global, with a metatable")

-- the data as generated
for _, fl in ipairs({10, 20}) do
    local d = F.DATA[fl]
    T.check(d and #d.pa == 13 and d.pa_ft[1] == -2000 and d.pa_ft[13] == 10000, fl .. ": 13 pressure-altitude lines -2..10")
    T.equal(d.ref_ft, 10000, fl .. ": the REF LINE at 10,000 ft")
    T.near(d.min_ft, 5400, 5, fl .. ": the MINIMUM FIELD LENGTH REQUIRED line at 5,400 ft")
    local s = d.scale
    T.check(s.oat_lo == -50 and s.oat_hi == 80 and s.w_lo == 200 and s.w_hi == 460 and s.ft_lo == 4000
        and s.ft_hi == 18000 and s.head == 40 and s.tail == 15 and s.slope == 2, fl .. ": the scales' ends")
    local ok = true
    for i, g in ipairs(d.guide) do
        if i > 1 and g.ref <= d.guide[i - 1].ref then ok = false end
        if math.abs(g.ref - math.floor(g.ref / 20 + 0.5) * 20) > 0.1 then ok = false end
    end
    T.check(ok and d.guide[#d.guide].ref > 459.9, fl .. ": the guide lines at the REF LINE every 20 t up to 460 t")
    for _, k in ipairs({"wind", "slope"}) do
        local okk = #d[k] == 15
        for i, g in ipairs(d[k]) do
            if math.abs(g.ref - (3000 + 1000 * i)) > 5 then okk = false end
        end
        T.check(okk, fl .. ": the " .. k .. " chart's 15 guide lines at the REF LINE every 1,000 ft")
    end
end
T.equal(#F.DATA[10].guide, 14, "flaps 10: 14 guide lines (200 to 460 t)")
T.equal(#F.DATA[20].guide, 13, "flaps 20: 13 guide lines (220 to 460 t)")

-- the printed examples (the dashed lines with arrows), as read off the charts:
-- the OAT where the dashed line leaves the OAT scale, the pressure altitude
-- of the line it meets (both meet the 0 line, within 20 ft), the field length
-- where it leaves the field length scale, the slope and wind where its
-- diagonals end, and the weights where its horizontals meet the REF LINE
-- and the weight scale
local EX = {
    [10] = {oat = 35.9, pa = 0, fla = 9147, slope = 2, wind = 20,          -- FPPM p.27 (1.2.3)
        ref = 353110, l1 = 8228, lc = 8974, w = 335280},
    [20] = {oat = 31.0, pa = 0, fla = 8565, slope = 2, wind = 20,          -- FPPM p.28 (1.2.4)
        ref = 372380, l1 = 7816, lc = 8554, w = 346950},
}
for _, fl in ipairs({10, 20}) do
    local e, g = EX[fl], F.DATA[fl].example
    T.check(math.abs(g.oat_c - e.oat) < 0.1 and math.abs(g.pa_ft - e.pa) < 25 and math.abs(g.fla_ft - e.fla) < 2
        and math.abs(g.slope_pct - e.slope) < 0.02 and math.abs(g.wind_kt - e.wind) < 0.1
        and math.abs(g.w_t * 1000 - e.w) < 20, fl .. ": the generator read the same example")
    -- the whole chart: within 2,000 kg of the printed answer (see the steps)
    T.near(F.limit_weight(fl, e.oat, e.pa, e.fla, e.slope, e.wind), e.w, 2000, fl .. ": the example's answer")
    -- step by step
    T.near(F.ref_weight(fl, e.oat, e.pa), e.ref, 400, fl .. ": the example's REF LINE weight")
    T.near(F.corrected_length(fl, e.lc, 0, 0), e.lc, 3, fl .. ": no slope and no wind: the length itself")
    T.near(F.corrected_length(fl, e.l1, 0, e.wind), e.lc, 30, fl .. ": the example's wind step")
end
-- the slope step: flaps 10 as drawn; on p.28 the dashed line ends 83 ft
-- further along than the guide lines give (it runs nearly parallel to the
-- 8,000 ft line, not between it and the 9,000 ft line)
T.near(F.corrected_length(10, EX[10].fla, 2, 0), EX[10].l1, 20, "10: the example's slope step")
T.near(F.corrected_length(20, EX[20].fla, 2, 0), EX[20].l1, 100, "20: the example's slope step (drawn 83 ft long)")
-- the right part from the example's corrected length: flaps 20 as drawn; on
-- p.27 the dashed guide line is steeper than the guide lines beside it and
-- ends 1.3 t lower
T.near(F.limit_weight(20, EX[20].oat, -5, EX[20].lc, 0, 0), EX[20].w, 300, "20: the example's right part")
T.near(F.limit_weight(10, EX[10].oat, 19, EX[10].lc, 0, 0), EX[10].w, 1500, "10: the example's right part (drawn 1.3 t low)")

-- points read by eye off the page images' grids (_ref/text/img/FPPM)
T.near(F.ref_weight(10, -50, -2000), 423500, 1500, "p.27: the -2 line at -50 C, 423.5 t")
T.near(F.ref_weight(10, -50, 10000), 303000, 1500, "p.27: the 10 line at -50 C, 303 t")
T.near(F.ref_weight(20, -50, -2000), 438500, 1500, "p.28: the -2 line at -50 C, 438.5 t")
T.near(F.ref_weight(20, -50, 10000), 312500, 1500, "p.28: the 10 line at -50 C, 312.5 t")
T.near(F.ref_weight(10, 39.3, -2000), 371000, 1500, "p.27: the -2 line's corner near 39 C, 371 t")

-- at the REF LINE's length with no slope or wind the right part changes nothing
local same = true
for _, fl in ipairs({10, 20}) do
    for _, c in ipairs({{-30, -2000}, {0, 0}, {15, 3500}, {30, 8000}, {34, 10000}}) do
        local r, w = F.ref_weight(fl, c[1], c[2]), F.limit_weight(fl, c[1], c[2], 10000, 0, 0)
        if not (r and w and math.abs(r - w) <= 20) then same = false end
    end
end
T.check(same, "at 10,000 ft the limit weight is the REF LINE's")

-- the trends
for _, fl in ipairs({10, 20}) do
    local mono = true
    for _, pa in ipairs({-2000, -500, 0, 3500, 7200, 10000}) do
        local prev
        for t = -50, F.env_limit_c(fl, pa), 1 do
            local w = F.limit_weight(fl, t, pa, 11000, 0, 0)
            if not w or (prev and w > prev) then mono = false end
            prev = w
        end
    end
    T.check(mono, fl .. ": the weight falls as the OAT rises")
    mono = true
    local prev
    for pa = -2000, 10000, 500 do
        local w = F.limit_weight(fl, 15, pa, 11000, 0, 0)
        if not w or (prev and w >= prev) then mono = false end
        prev = w
    end
    T.check(mono, fl .. ": the weight falls with the pressure altitude")
    mono, prev = true, nil
    for l = 6000, 18000, 250 do
        local w = F.limit_weight(fl, 30, 2000, l, 0, 0)
        if not w or (prev and w <= prev) then mono = false end
        prev = w
    end
    T.check(mono, fl .. ": the weight rises with the field length (30 C, 2,000 ft)")
    mono, prev = true, nil
    for wind = -15, 40, 5 do
        local w = F.limit_weight(fl, 30, 2000, 9000, 0, wind)
        if not w or (prev and w <= prev) then mono = false end
        prev = w
    end
    T.check(mono, fl .. ": the weight rises with the headwind")
    mono, prev = true, nil
    for s = -2, 2, 0.5 do
        local w = F.limit_weight(fl, 30, 2000, 9000, s, 0)
        if not w or (prev and w >= prev) then mono = false end
        prev = w
    end
    T.check(mono, fl .. ": the weight falls with the uphill slope")
    T.check(F.corrected_length(fl, 9000, 0, -10) < 9000 and F.corrected_length(fl, 9000, 0, 10) > 9000
        and F.corrected_length(fl, 9000, 1, 0) < 9000 and F.corrected_length(fl, 9000, -1, 0) > 9000,
        fl .. ": headwind and downhill lengthen, tailwind and uphill shorten")
end
T.check(F.limit_weight(10, 15, 0, 8000, 0, 0) < F.limit_weight(20, 15, 0, 8000, 0, 0)
    and F.limit_weight(10, 40, 6000, 12000, 0, 0) < F.limit_weight(20, 40, 6000, 12000, 0, 0),
    "flaps 20 gets more weight off a field than flaps 10")

-- the limit lines (both pages alike)
for _, fl in ipairs({10, 20}) do
    T.near(F.env_limit_c(fl, -2000), 54.4, 0.05, fl .. ": environmental limit at -2,000 ft")
    T.near(F.env_limit_c(fl, 0), 54.4, 0.05, fl .. ": environmental limit at 0 ft (the line's vertical part)")
    T.near(F.env_limit_c(fl, 500), 53.4, 0.05, fl .. ": environmental limit at 500 ft")
    T.near(F.env_limit_c(fl, 5000), 44.5, 0.05, fl .. ": environmental limit at 5,000 ft")
    T.near(F.env_limit_c(fl, 10000), 34.6, 0.05, fl .. ": environmental limit at 10,000 ft")
    T.near(F.atm_limit_c(fl, -2000), 75.1, 0.05, fl .. ": assumed temperature limit at -2,000 ft")
    T.near(F.atm_limit_c(fl, 10000), 51.3, 0.05, fl .. ": assumed temperature limit at 10,000 ft")
    T.check(F.env_limit_c(fl, 10001) == nil and F.atm_limit_c(fl, -2001) == nil, fl .. ": limits outside the altitudes: nil")
    local env, atm = F.env_limit_c(fl, 3000), F.atm_limit_c(fl, 3000)
    T.check(F.ref_weight(fl, env, 3000) ~= nil, fl .. ": at the environmental limit")
    local w, why = F.ref_weight(fl, env + 0.2, 3000)
    T.check(w == nil and why == "above the environmental limit", fl .. ": past the environmental limit: nil")
    T.check(F.ref_weight(fl, env + 0.2, 3000, true) ~= nil and F.ref_weight(fl, atm, 3000, true) ~= nil,
        fl .. ": an assumed temperature up to the assumed temperature limit")
    w, why = F.ref_weight(fl, atm + 0.2, 3000, true)
    T.check(w == nil and why == "above the assumed temperature limit", fl .. ": past the assumed temperature limit: nil")
    T.check(F.ref_weight(fl, atm, 3000, true) < F.ref_weight(fl, env, 3000), fl .. ": less weight at a higher assumed temperature")
    -- between two pressure-altitude lines near the assumed temperature limit (the higher line carried on)
    local a95 = F.atm_limit_c(fl, 9500)
    T.check(a95 > F.atm_limit_c(fl, 10000) and F.limit_weight(fl, a95, 9500, 12000, 0, 0, true) ~= nil,
        fl .. ": 9,500 ft at its assumed temperature limit")
end

-- outside the charts
for _, fl in ipairs({10, 20}) do
    T.check(F.ref_weight(fl, 15, -2001) == nil and F.ref_weight(fl, 15, 10001) == nil, fl .. ": altitude outside -2,000..10,000 ft: nil")
    T.equal(F.ref_weight(fl, -70, 0), F.ref_weight(fl, -50, 0), fl .. ": below -50 C the -50 C value")
    T.check(F.limit_weight(fl, 15, 0, 10000, 2.1, 0) == nil and F.limit_weight(fl, 15, 0, 10000, -2.1, 0) == nil,
        fl .. ": slope beyond +/-2 %: nil")
    T.check(F.limit_weight(fl, 15, 0, 10000, 0, -15) ~= nil and F.limit_weight(fl, 15, 0, 10000, 0, -15.5) == nil,
        fl .. ": tailwind to 15 kt, not beyond")
    local w, why = F.limit_weight(fl, 15, 0, 3999, 0, 0)
    T.check(w == nil and why == "field length below the chart's 4,000 ft", fl .. ": field length below 4,000 ft: nil")
    w, why = F.limit_weight(fl, -40, -2000, 5300, 0, 0)
    T.check(w == nil and why == "corrected field length below the minimum field length required", fl .. ": below the minimum field length: nil")
    T.check(F.limit_weight(fl, -40, -2000, 5600, 0, 0) ~= nil, fl .. ": just above the minimum field length")
    T.check(F.limit_weight(fl, 15, 0, 6000, 0, 0) ~= nil and F.limit_weight(fl, 15, 0, 6000, 0, -10) == nil,
        fl .. ": a tailwind taking 6,000 ft below the minimum: nil")
    w, why = F.limit_weight(fl, 51, 10000, 7000, 0, 0, true)
    T.check(w == nil and why == "below the chart's 200,000 kg", fl .. ": hot, high and short: below the chart: nil")
    w, why = F.limit_weight(fl, -50, -2000, 18000, 0, 0)
    T.check(w == 460000 and why == "above the chart: 460,000 kg or more", fl .. ": cold, low and long: 460,000 kg and a note")
    local l, note = F.corrected_length(fl, 20000, 0, 0)
    T.check(math.abs(l - 18000) <= 5 and note == "field length taken as the chart's 18,000 ft", fl .. ": 20,000 ft taken as 18,000")
    l, note = F.corrected_length(fl, 9000, 0, 50)
    T.check(l == F.corrected_length(fl, 9000, 0, 40) and note == "headwind taken as the chart's 40 kt", fl .. ": 50 kt headwind taken as 40")
    T.check(F.corrected_length(fl, 4000, 2, 0) == nil, fl .. ": uphill from 4,000 ft off the chart: nil")
end
T.check(F.limit_weight(15, 15, 0, 10000, 0, 0) == nil and F.ref_weight(5, 15, 0) == nil, "no chart for flaps 15 or 5")
T.check(F.limit_weight(10, nil, 0, 10000) == nil and F.limit_weight(10, 15, 0, nil) == nil, "no OAT or field length: nil")
T.equal(F.limit_weight(10, "15", "0", "10000", "0", "0"), F.limit_weight(10, 15, 0, 10000, 0, 0), "numbers as text")
T.equal(F.limit_weight(10, 15, 0, 10000), F.limit_weight(10, 15, 0, 10000, 0, 0), "no slope or wind: none")

-- the notes below the charts
T.equal(F.bleed_adjust_kg(10, 0), 1800, "p.27: packs off +1,800 kg")
T.equal(F.bleed_adjust_kg(10, 1), 650, "p.27: 1 pack on +650 kg")
T.equal(F.bleed_adjust_kg(20, 0), 2000, "p.28: packs off +2,000 kg")
T.equal(F.bleed_adjust_kg(20, 1), 650, "p.28: 1 pack on +650 kg")
T.check(F.bleed_adjust_kg(10, 3) == 0 and F.bleed_adjust_kg(20, 3) == 0 and F.bleed_adjust_kg(20, nil) == 0,
    "3 packs (the charts' basis): 0")
T.equal(F.bleed_adjust_kg(10, 2), 0, "2 packs (not in the notes): 0")
T.check(F.bleed_adjust_kg(25, 0) == nil, "no chart for flaps 25: nil")

T.done()
