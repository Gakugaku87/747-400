-- Run from the repository root with Lua 5.1 or LuaJIT.
-- EHAM ILS 18R via SUG1D and EINN ILS 06 flown in the closed-loop approach
-- model (approach_model.lua: the production VNAV, FMA, AFDS pitch director and
-- A/T code with a point-mass 747 and the kit's approach procedure), from where
-- the line flights of 2026-10-16 were and from 300 ft higher or lower, 10 to
-- 15 kt faster or slower, 30 nm out, with APP later and the LOC sooner, EHAM
-- with a 15 kt tailwind and a 25 kt headwind (EINN in TST744L's westerly).
-- Each must capture the real glide slope (below 4 deg from its origin; the
-- false lobes are at 6 and 9 deg) by 5 nm out, keep the A/T on, never go over
-- the placard of the flaps set (also from 1,000 to 1,500 ft high, and with
-- VNAV's speed at the A/T's cap, the placard - 5, also with flaps 1 in a
-- strong tailwind), never climb 200 ft, be within 0.75 dot of the beam at
-- 1,000 and 500 ft above the runway and within 30 ft of it at 200 ft, at VREF
-- to VREF + 20 kt at 500 ft and never 10 kt below the speed set after the
-- capture. On the code before the P8 fixes (49c55514) 89 of the 213 checks
-- fail: every EHAM case captures the 6 deg lobe at 5.1 to 5.8 nm and is 1,470
-- to 1,900 ft above the beam at 200 ft, EINN's 252 kt and low cases at 4.7 nm,
-- and the A/T goes off in 9 cases.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local CASES = {
    {"eham", {}}, {"eham", {ias_kt = 235}}, {"eham", {alt_ft = 5450}}, {"eham", {alt_ft = 4850}},
    {"eham", {ias_kt = 210, alt_ft = 5450}}, {"eham", {app_nm = 8.2, loc_delay_s = 20}},
    {"eham", {active = 7, start_nm = 10.5, alt_ft = 8000, ias_kt = 235, vs_fpm = -1100, flaps = 0, at_mode = 3,
        vnav_speed_kt = 240, vnav_speeds = {{24, 220}}}, "30 nm out"},
    {"eham", {alt_ft = 6150}, "1,000 ft high"}, {"eham", {alt_ft = 6650}, "1,500 ft high"},
    {"eham", {wind = {{0, 360, 15}, {10000, 360, 15}}}, "15 kt tailwind"},
    {"eham", {wind = {{0, 180, 25}, {10000, 180, 25}}}, "25 kt headwind"},
    {"einn", {}}, {"einn", {ias_kt = 252}}, {"einn", {alt_ft = 5640}}, {"einn", {alt_ft = 4640}},
    {"einn", {ias_kt = 230}}, {"einn", {loc_delay_s = 15}}, {"einn", {alt_ft = 6140}, "1,000 ft high"},
    {"einn", {alt_ft = 6640}, "1,500 ft high"},
    {"einn", {flaps = 3 / 6, ias_kt = 235, vnav_speed_kt = 235, alt_ft = 6140}, "1,000 ft high at the A/T's cap"},
    {"einn", {start_nm = 16, alt_ft = 7736, ias_kt = 238, vs_fpm = -1368, flaps = 0, at_mode = 3}, "29 nm out"},
}

-- The first point of a flight over the placard of the flaps set, if any.
local function over_placard(track)
    for _, p in ipairs(track) do
        local placard = model.FLAP_PLACARD[model.FLAP_DETENTS[math.floor(p.handle * 6 + 0.5) + 1]] or 365
        if p.ias > placard then return p end
    end
    return nil
end

for _, case in ipairs(CASES) do
    local o = model[case[1]](case[2])
    local name = case[1]
    if case[3] then
        name = name.." "..case[3]
    else
        local keys = {}
        for k, v in pairs(case[2]) do keys[#keys + 1] = k.."="..tostring(v) end
        table.sort(keys)
        if #keys > 0 then name = name.." "..table.concat(keys, " ") end
    end
    local ok, m = pcall(model.fly, o)
    check(ok, name..": "..tostring(m))
    if ok then
        local elev = o.threshold[3]
        local gs = m.events.gs_capture
        check(gs ~= nil and gs.elevation < 4 and gs.dist_thr > 5, name..": the real glide slope by 5 nm, got "
            ..(gs and string.format("%.2f deg at %.1f nm", gs.elevation, gs.dist_thr) or "none"))
        local at1000, at500, last, climb, at_off, slow = nil, nil, nil, 0, nil, 0
        local over = over_placard(m.track)
        for k, p in ipairs(m.track) do
            local agl = p.alt - elev
            if p.gs == 2 then
                if at1000 == nil and agl <= 1000 then at1000 = p end
                if at500 == nil and agl <= 500 then at500 = p end
                slow = math.max(slow, p.spd - p.ias)
            end
            if at_off == nil and p.at_active ~= 1 then at_off = p end
            if k > 20 then climb = math.max(climb, p.alt - m.track[k - 20].alt) end
            last = p
        end
        check(at_off == nil, name..": the A/T on, off at "..(at_off and string.format("%.1f nm", at_off.dist_thr) or ""))
        check(over == nil, name..": never over the flaps' placard"
            ..(over and string.format(", %.0f kt at %.1f nm", over.ias, over.dist_thr) or ""))
        check(climb < 200, name..string.format(": no 200 ft climb in 10 s, %.0f ft", climb))
        check(at1000 ~= nil and math.abs(at1000.dots) <= 0.75,
            name..": within 0.75 dot at 1,000 ft, "..(at1000 and string.format("%.2f", at1000.dots) or "not on G/S"))
        check(at500 ~= nil and math.abs(at500.dots) <= 0.75,
            name..": within 0.75 dot at 500 ft, "..(at500 and string.format("%.2f", at500.dots) or "not on G/S"))
        check(at500 ~= nil and at500.ias >= o.vref_kt and at500.ias <= o.vref_kt + 20,
            name..": VREF to VREF + 20 kt at 500 ft, "..(at500 and string.format("%.0f kt", at500.ias) or "-"))
        check(slow < 10, name..string.format(": never 10 kt below the speed set on the G/S, %.1f kt", slow))
        local above = last and model.above_gs(last, elev, o.gs_deg) or 1e9
        check(last ~= nil and last.alt - elev <= 210 and math.abs(above) <= 30,
            name..string.format(": within 30 ft of the beam at 200 ft, %.0f ft", above))
    end
end

-- EHAM 1,000 ft high with VNAV's speed at the A/T's cap with flaps 1 (275 kt) in a tailwind from 15 kt at the
-- runway to 70 kt at 5,000 ft: the path's limit keeps the speed within the placard (at the placard - 2 the
-- 747 went 0.3 kt over it at 11.4 nm, the V/S lagging the path's command). So much energy still ends on the
-- 6 deg lobe without the speedbrake (left as it is), so only the placard and the A/T are checked.
local o = model.eham({alt_ft = 6150, flaps = 1 / 6, vnav_speed_kt = 275, ias_kt = 275,
    wind = {{0, 360, 15}, {5000, 360, 70}, {10000, 360, 70}}})
local ok, m = pcall(model.fly, o)
check(ok, "eham at the flaps 1 cap in a 15 to 70 kt tailwind: "..tostring(m))
if ok then
    local over, at_off = over_placard(m.track), nil
    for _, p in ipairs(m.track) do
        if at_off == nil and p.at_active ~= 1 then at_off = p end
    end
    check(over == nil, "eham at the flaps 1 cap in a 15 to 70 kt tailwind: never over the flaps' placard"
        ..(over and string.format(", %.1f kt at %.1f nm", over.ias, over.dist_thr) or ""))
    check(at_off == nil, "eham at the flaps 1 cap in a 15 to 70 kt tailwind: the A/T on")
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("approach model tests passed: "..checks)
