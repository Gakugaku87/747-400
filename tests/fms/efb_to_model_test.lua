-- Run from the repository root with LuaJIT: luajit tests/fms/efb_to_model_test.lua
-- The EFB's takeoff performance (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.efb_to_model.lua; 2026-11-25, notes/
-- ATA-34-61-FMC.md §191): the derates' tables (FPPM p.47 (1.3.1), p.59
-- (1.3.13)) as printed, between them and past them; the pressure altitude;
-- the working (the least limit, the brake energy, the assumed temperature
-- search, the speeds, thrust and trim) on stand-in charts whose answers are
-- known, so that this test does not hang on the digitized charts' numbers
-- (their own tests: efb_field_model_test.lua, efb_limits_model_test.lua;
-- the real ones together: efb_to_real_test.lua).
local T = dofile("tests/lib/check.lua")("efb_to_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_to_model.lua")
dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.to_speeds_model.lua")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.to_trim_model.lua")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vref_model.lua")
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/"
dofile(EEC .. "B747.42.eec_model.lua")
dofile(EEC .. "B747.42.epr_model.lua")
dofile(EEC .. "B747.42.ge_n1_model.lua")
dofile(EEC .. "B747.42.rr_model.lua")
dofile(EEC .. "B747.42.ref_thrust_model.lua")

-- the derates' tables as printed (1000 kg): every cell
local PRINTED = {
    [8] = {
        field = {{460, 436.5}, {440, 417}, {420, 397}, {410, 384.5}, {400, 374}, {390, 366.5}, {380, 358},
            {360, 339.5}, {340, 321}, {320, 302}, {300, 283.5}, {280, 264.5}, {260, 246}},
        climb = {{460, 419.5}, {440, 401}, {420, 383}, {400, 364.5}, {380, 346}, {360, 327.5}, {340, 309},
            {320, 291}, {300, 272.5}, {280, 254}, {260, 235.5}},
        tire = {{460, 457}, {440, 437}, {420, 416.5}, {400, 396.5}, {390, 383.5}, {380, 376.5}, {360, 357},
            {340, 337}, {320, 317}, {300, 297}, {280, 277.5}, {260, 257.5}},
    },
    [20] = {
        field = {{460, 398.5}, {450, 384.5}, {440, 375}, {420, 357}, {400, 340}, {380, 325}, {360, 308},
            {340, 291.5}, {320, 275}, {300, 258}, {280, 241.5}},
        climb = {{460, 365}, {440, 348}, {420, 331}, {400, 314.5}, {380, 298.5}, {360, 281}, {340, 264},
            {320, 247}, {300, 230.5}, {280, 213.5}},
        tire = {{460, 452}, {440, 432}, {420, 411.5}, {410, 401.5}, {400, 383.5}, {390, 378.5}, {380, 371.5},
            {360, 352}, {340, 332.5}, {320, 313}, {300, 293.5}, {280, 274}},
    },
}
for pct, kinds in pairs(PRINTED) do
    for kind, cells in pairs(kinds) do
        local bad = 0
        for _, c in ipairs(cells) do
            if math.abs(P.derated(kind, c[1] * 1000, pct) - c[2] * 1000) > 0.01 then bad = bad + 1 end
        end
        T.equal(bad, 0, string.format("TO%s %s: every printed cell (%d)", pct == 8 and "1" or "2", kind, #cells))
    end
end
T.near(P.derated("obstacle", 400000, 8), 363500, 0.01, "TO1 obstacle 400 -> 363.5")
T.near(P.derated("obstacle", 400000, 20), 309500, 0.01, "TO2 obstacle 400 -> 309.5")
-- between the columns, the percentages, outside
T.near(P.derated("field", 370000, 8), (358 + 339.5) / 2 * 1000, 0.01, "TO1 field 370: halfway 358 and 339.5")
T.near(P.derated("climb", 300000, 0), 300000, 0, "0 %: the full rating's")
T.near(P.derated("climb", 300000, 4), (300 + 272.5) / 2 * 1000, 0.01, "4 %: halfway full and TO1")
T.near(P.derated("climb", 300000, 14), (272.5 + 230.5) / 2 * 1000, 0.01, "14 %: halfway TO1 and TO2")
T.near(P.derated("climb", 300000, 25), 230500, 0.01, "past 20 %: TO2's")
T.near(P.derated("field", 240000, 8), (246 - (264.5 - 246)) * 1000, 0.01, "TO1 field 240: the last step carried on")
T.near(P.derated("tire", 470000, 20), (452 + (452 - 432) / 2) * 1000, 0.01, "TO2 tire 470: the first step carried on")
T.check(P.derated("field", nil, 8) == nil, "nil stays nil")
for _, kind in ipairs({"field", "climb", "obstacle", "tire"}) do
    for _, pct in ipairs({5, 8, 15, 20}) do
        local prev = -1
        local up = true
        for w = 200, 470, 5 do
            local d = P.derated(kind, w * 1000, pct)
            if d < prev then up = false end
            if d > w * 1000 + 1e-6 then up = false end
            prev = d
        end
        T.check(up, string.format("%s %d %%: rises with the full weight, never above it", kind, pct))
    end
end

-- the pressure altitude (FPPM p.25: 1004 hPa about +250 ft)
T.near(P.pressure_altitude(0, 1013.25), 0, 1e-6, "standard: the elevation")
T.near(P.pressure_altitude(0, 1004), 250, 5, "1004 hPa: +250 ft (p.25)")
T.near(P.pressure_altitude(1000, 1023), 1000 - 268, 6, "1023 hPa: about -268 ft")
T.near(P.pressure_altitude(500, nil), 500, 0, "no QNH: the elevation")

-- the working on stand-in charts: field 420 t at 15 °C falling 2 t a
-- degree (8 t with the assumed temperature beyond 60 °C), climb 400 t
-- falling 1.5 t a degree, tire 450 t; VMBE 200 kt; the limit line 70 °C
local F, L = {}, {}
B747_efb_field_model, B747_efb_limits_model = F, L
local fieldAt15, climbAt15 = 420000, 400000
function F.limit_weight(flaps, t, pa, fla, slope, wind, assumed)
    if t > 50 and not assumed then return nil, "OAT ABOVE ENVIRONMENTAL LIMIT" end
    if t > 70 then return nil, "ABOVE ASSUMED TEMPERATURE LIMIT" end
    local w = fieldAt15 - 2000 * (t - 15)
    if t > 60 then w = w - 6000 * (t - 60) end
    return w
end
function F.bleed_adjust_kg(flaps, packs) return packs == 0 and 1800 or packs == 1 and 650 or 0 end
function F.atm_limit_c() return 70 end
function L.climb_limit(flaps, t, pa) return climbAt15 - 1500 * (t - 15) end
function L.climb_bleed_adjust_kg() return 0 end
function L.tire_limit() return 450000 end
local vmbeKt = 200
function L.vmbe() return vmbeKt end
function L.vmbe_check_needed() return true end
function L.vmbe_weight_per_kt() return 3000 end

local function inp(t)
    local i = {engine = 0, flaps = 20, rating = 0, to_pct = 0, atm = false, cond = 0, packs = 3, oat_c = 15,
        qnh_hpa = 1013.25, elev_ft = 0, fla_ft = 12000, slope_pct = 0, wind_kt = 0, tow_kg = 300000, cg_pct = 22,
        mtow_kg = 396893}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
local out = P.calc(inp{})
T.equal(out.lim.field, 420000, "the field limit")
T.equal(out.lim.climb, 400000, "the climb limit")
T.equal(out.max_kg, 396893, "the least: structural")
T.equal(out.limit, "struct", "the limit's name")
T.check(out.v1 and out.vr and out.v2 and out.v1 <= out.vr and out.vr < out.v2, string.format("speeds %d/%d/%d", out.v1, out.vr, out.v2))
local S = B747_to_speeds_model
local v1, vr, v2 = S.speeds({flaps = 20, weight_kg = 300000, hw = 0, slope = 0, oat_c = 15, pa_ft = 0, engine = 0, pct = 0})
T.check(out.v1 == v1 and out.vr == vr and out.v2 == v2, "the FMC's speeds for the weight at the OAT")
T.near(out.thrust, B747_ref_thrust_model.reference({type = "PW", mode = "TO", to_pct = 0, alt = 0, tat = 15, oat = 15,
    mach = 0, packs_on = 3, wai = false, nai = false}), 1e-9, "the FMC's reference EPR")
T.near(out.trim, B747_to_trim_model.trim(0, 300, 22), 1e-9, "the FMC's trim")
T.near(out.vref30, B747_vref_model.vref(30, 300000, 0), 1e-9, "the FMC's VREF 30")
T.check(out.sel_c == nil, "no assumed temperature unless asked")

-- the bleed adjustment: packs off +1,800 kg on the field limit
out = P.calc(inp{packs = 0, mtow_kg = 500000})
T.equal(out.lim.field, 421800, "packs off: the field limit +1,800 kg")
T.equal(out.limit, "climb", "then the climb limit is the least")

-- the brake energy: V1 above VMBE takes the weight down 3,000 kg a knot
vmbeKt = 150
out = P.calc(inp{mtow_kg = 500000})
local v1max = S.speeds({flaps = 20, weight_kg = 400000, hw = 0, slope = 0, oat_c = 15, pa_ft = 0, engine = 0, pct = 0})
T.near(out.lim.brake, 400000 - (v1max - 150) * 3000, 1e-6, string.format("brake energy: 400 t less (V1 %d - 150) x 3,000", v1max))
T.equal(out.limit, "brake", "the brake energy is the least")
vmbeKt = 200

-- too heavy: the reason, no speeds
out = P.calc(inp{tow_kg = 410000, mtow_kg = 500000})
T.equal(out.err, "WEIGHT ABOVE CLIMB LIMIT", "410 t over the climb's 400 t")
T.check(out.v1 == nil, "no speeds")

-- the assumed temperature: the field and climb limits cover 300 t up to
-- 15 + (400 - 300) / 1.5 = 81.7 °C (climb) and 15 + 120 / 2 = 75 (field),
-- the field's beyond 60 °C (8 t a degree) at 60 + (420 - 90 - 300) / 8 =
-- 63.75; the limit line 70; the 25 % of thrust where it comes
out = P.calc(inp{atm = true})
T.check(out.sel_c ~= nil, "an assumed temperature for 300 t")
local function hot_red(t)
    local _, red = B747_ref_thrust_model.reference({type = "PW", mode = "D-TO", to_pct = 0, sel = t, alt = 0, tat = 15,
        oat = 15, mach = 0, packs_on = 3, wai = false, nai = false})
    return red
end
local t25 = nil
for t = 16, 70 do if hot_red(t) > 24.95 then t25 = t break end end
local expect = math.min(63, t25 or 99)
T.equal(out.sel_c, expect, string.format("the assumed temperature: the field's 63 (63.75) or the 25 %% at %s", tostring(t25)))
T.check(out.thrust_red <= 25.0001, string.format("at most 25 %% less thrust (%.1f)", out.thrust_red))
local v1a, vra, v2a = S.speeds({flaps = 20, weight_kg = 300000, hw = 0, slope = 0, oat_c = 15, sel_c = out.sel_c, pa_ft = 0,
    engine = 0, pct = 0})
T.check(out.v1 == v1a and out.vr == vra and out.v2 == v2a, "the speeds at the assumed temperature")
-- held by the climb when it falls faster
climbAt15 = 360000
out = P.calc(inp{atm = true})
T.equal(out.sel_c, math.min(55, t25 or 99), "climb 360 t falling 1.5 t a degree: 300 t up to 55 °C")
if (t25 or 99) > 55 then T.equal(out.atm_why, "CLIMB", "held by the climb") end
climbAt15 = 400000
-- a wet runway: no assumed temperature (p.22); a stand-in contaminated
-- runway model (efb_contam_model_test.lua tests the real one): the field
-- limit 5 t less, the VMCG limit 380 t, V1 3 kt less
B747_efb_contam_model = {
    limit = function(kind, d, rev, pct, field) return math.min(field - 5000, 380000),
        {vmcg_kg = 380000, adjust_kg = -5000, vmcg_limited = field - 5000 > 380000} end,
    v1 = function(kind, d, rev, pct, w, v1) return v1 - 3, {} end,
}
out = P.calc(inp{atm = true, cond = 1})
T.check(out.sel_c == nil and out.atm_why == "RUNWAY NOT DRY", "not on a runway that is not dry")
T.equal(out.lim.field, 380000, "wet: the lesser of the adjusted field limit (420 t less 5 t) and the VMCG limit (380 t)")
T.check(out.contam and out.contam.vmcg_kg == 380000, "wet: the VMCG limit weight kept")
local v1w = S.speeds({flaps = 20, weight_kg = 300000, hw = 0, slope = 0, oat_c = 15, pa_ft = 0, engine = 0, pct = 0})
T.equal(out.v1, v1w - 3, "wet: V1 through the contaminated model")
B747_efb_contam_model = nil
out = P.calc(inp{cond = 2, depth_mm = 6})
T.equal(out.err, "NO CONTAMINATED RUNWAY DATA", "no contaminated model: a reason, not a dry answer")
-- V1 at the assumed temperature above VMBE: a cooler one
vmbeKt = v1a - 2
out = P.calc(inp{atm = true, mtow_kg = 500000})
T.check(out.sel_c == nil or out.sel_c < expect, "V1 above VMBE at the assumed temperature: cooler (" .. tostring(out.sel_c) .. ")")
vmbeKt = 200

-- a derate: the limits through the tables, TO 1's reference
out = P.calc(inp{rating = 1, to_pct = 8, mtow_kg = 500000})
T.near(out.lim.field, P.derated("field", 420000, 8), 1e-6, "TO 1: the field limit through p.47")
T.near(out.lim.climb, P.derated("climb", 400000, 8), 1e-6, "TO 1: the climb limit through p.47")
T.near(out.thrust, B747_ref_thrust_model.reference({type = "PW", mode = "TO 1", to_pct = 8, alt = 0, tat = 15, oat = 15,
    mach = 0, packs_on = 3, wai = false, nai = false}), 1e-9, "TO 1's reference EPR")
-- GE: N1
out = P.calc(inp{engine = 1})
T.check(out.thrust_n1 and out.thrust > 90 and out.thrust < 110, string.format("GE: %%N1 %.1f", out.thrust))
-- RR: the RB211's own EPR scale (B747_rr_model.display)
out = P.calc(inp{engine = 2})
T.check(not out.thrust_n1 and out.thrust > 1.2 and out.thrust < 2.0, string.format("RR: EPR %.3f", out.thrust))
-- off the charts: the reason
out = P.calc(inp{oat_c = 55})
T.equal(out.err, "OAT ABOVE ENVIRONMENTAL LIMIT", "the field chart's reason")
T.done()
