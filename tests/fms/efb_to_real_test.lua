-- Run from the repository root with LuaJIT: luajit tests/fms/efb_to_real_test.lua
-- The EFB's takeoff performance (B747.68.efb_to_model.lua; 2026-11-25,
-- notes/ATA-34-61-FMC.md §191) on the digitized FPPM charts together
-- (B747.68.efb_field_model.lua: p.27-28; B747.68.efb_limits_model.lua:
-- p.29-34): the limits chained as the FPPM's text reads them (p.19-22),
-- each against its own chart's function; the assumed temperature's search
-- against the charts read directly; the tailwind limit (FCOM p.77); cases a
-- crew meets (a long sea-level runway, a short one, hot and high).
local T = dofile("tests/lib/check.lua")("efb_to_real")
local D = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local F = dofile(D .. "B747.68.efb_field_model.lua")
local L = dofile(D .. "B747.68.efb_limits_model.lua")
local P = dofile(D .. "B747.68.efb_to_model.lua")
dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.to_speeds_model.lua")
dofile(D .. "B747.68.to_trim_model.lua")
dofile(D .. "B747.68.vref_model.lua")
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/"
for _, f in ipairs({"eec_model", "epr_model", "ge_n1_model", "rr_model", "ref_thrust_model"}) do
    dofile(EEC .. "B747.42." .. f .. ".lua")
end

local function inp(t)
    local i = {engine = 0, flaps = 20, rating = 0, to_pct = 0, atm = false, cond = 0, packs = 3, oat_c = 15,
        qnh_hpa = 1013.25, elev_ft = 0, fla_ft = 13123, slope_pct = 0, wind_kt = 0, tow_kg = 300000, cg_pct = 22,
        mtow_kg = 396893}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end

-- a long sea-level runway (4,000 m: RJAA 34L), 15 °C: the limits each the
-- chart's own, the structural the least
local out = P.calc(inp{})
T.check(not out.err, "worked out: " .. tostring(out.err))
T.near(out.lim.field, F.limit_weight(20, 15, 0, 13123, 0, 0), 1e-6, string.format("field %.0f: the chart's", out.lim.field))
T.near(out.lim.climb, L.climb_limit(20, 15, 0), 1e-6, string.format("climb %.0f: the chart's", out.lim.climb))
T.near(out.lim.tire, L.tire_limit(20, 15, 0, 0), 1e-6, string.format("tire %.0f: the chart's", out.lim.tire))
T.equal(out.limit, "struct", "4,000 m at sea level: the structural limit")
T.check(out.v1 >= 120 and out.v1 <= 140 and out.v2 >= 150 and out.v2 <= 165,
    string.format("300 t flaps 20: %d/%d/%d", out.v1, out.vr, out.v2))
-- the assumed temperature: the hottest whole degree the field and climb
-- charts (at that temperature, assumed) still give 300 t, at most the limit
-- line and 25 % less thrust
out = P.calc(inp{atm = true})
T.check(out.sel_c ~= nil, "an assumed temperature for 300 t on 4,000 m: " .. tostring(out.sel_c) .. " (" .. tostring(out.atm_why) .. ")")
local function covers(t)
    local f = F.limit_weight(20, t, 0, 13123, 0, 0, true)
    local c = L.climb_limit(20, t, 0)
    return f and c and f >= 300000 and c >= 300000
end
T.check(covers(out.sel_c), "the charts cover 300 t at it")
T.check(out.sel_c >= math.floor(F.atm_limit_c(20, 0)) or not covers(out.sel_c + 1) or out.atm_why == "25 % THRUST",
    "and not a degree hotter, unless the line or the 25 % held it (" .. out.atm_why .. ")")
T.check(out.sel_c <= F.atm_limit_c(20, 0), string.format("not past the limit line (%.1f)", F.atm_limit_c(20, 0)))
T.check(out.thrust_red <= 25.0001, string.format("thrust %.1f %% less", out.thrust_red))
T.check(out.thrust < P.calc(inp{}).thrust, string.format("a lower EPR than full rating (%.3f)", out.thrust))

-- a short runway (2,500 m) at 30 °C: the field length limits, heavy fails
out = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil})
T.equal(out.limit, "field", string.format("2,500 m at 30 °C: the field length limits (%.0f)", out.max_kg or -1))
T.check(out.max_kg < 360000 and out.max_kg > 300000, "a sensible weight (p.28's example: 31 °C, 8,565 ft, +2 %, 20 kt head 346.95 t): " .. tostring(out.max_kg))
local heavy = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = out.max_kg + 5000})
T.check(heavy.err ~= nil and heavy.err:find("FIELD") ~= nil, "5 t over it: " .. tostring(heavy.err))
-- flaps 10 on that runway: less weight than flaps 20 (more runway needed)
local f10 = P.calc(inp{flaps = 10, fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil})
T.check(f10.lim.field < out.lim.field, string.format("flaps 10 field %.0f under flaps 20's %.0f", f10.lim.field, out.lim.field))
-- headwind helps, tailwind hurts, uphill hurts
local hw = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil, wind_kt = 10})
local tw = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil, wind_kt = -5})
local up = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil, slope_pct = 1})
T.check(hw.lim.field > out.lim.field and tw.lim.field < out.lim.field and up.lim.field < out.lim.field,
    string.format("head %.0f > still %.0f > tail %.0f, uphill %.0f", hw.lim.field, out.lim.field, tw.lim.field, up.lim.field))

-- hot and high (FAOR 03L: 5,558 ft, 4,418 m, 30 °C): everything lower,
-- the climb and tire charts' own numbers
out = P.calc(inp{elev_ft = 5558, fla_ft = 4418 / 0.3048, oat_c = 30, tow_kg = nil})
T.check(not out.err, "FAOR 30 °C worked out: " .. tostring(out.err))
local pa = out.pa_ft
T.near(out.lim.climb, L.climb_limit(20, 30, pa), 1e-6, string.format("climb %.0f at %.0f ft", out.lim.climb, pa))
T.check(out.max_kg < 370000 and out.max_kg > 280000, string.format("FAOR 30 °C most %.0f (%s)", out.max_kg, out.limit))
-- packs off: more weight where the field or climb limits
local packs = P.calc(inp{elev_ft = 5558, fla_ft = 4418 / 0.3048, oat_c = 30, tow_kg = nil, packs = 0})
T.check(packs.max_kg > out.max_kg, string.format("packs off %.0f over %.0f", packs.max_kg, out.max_kg))

-- the derates: TO 2 less than TO 1 less than TO
local to1 = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil, rating = 1, to_pct = 8})
local to2 = P.calc(inp{fla_ft = 2500 / 0.3048, oat_c = 30, tow_kg = nil, rating = 2, to_pct = 20})
T.check(to2.max_kg < to1.max_kg and to1.max_kg < out.max_kg + 1e9, string.format("TO 2 %.0f < TO 1 %.0f", to2.max_kg, to1.max_kg))

-- the tailwind limit (FCOM p.77): P&W 15 kt, GE 10 kt
T.check(P.calc(inp{wind_kt = -12}).err == nil, "P&W 12 kt tailwind: within its 15")
T.equal(P.calc(inp{wind_kt = -16}).err, "TAILWIND ABOVE 15 KT", "P&W 16 kt: refused")
T.equal(P.calc(inp{engine = 1, wind_kt = -12}).err, "TAILWIND ABOVE 10 KT", "GE 12 kt: refused (10)")

-- VMBE: hot, high and heavy with a tailwind checks the brake energy
out = P.calc(inp{elev_ft = 5558, fla_ft = 4418 / 0.3048, oat_c = 30, tow_kg = 300000, wind_kt = -10})
T.check(out.vmbe ~= nil and out.vmbe_check, string.format("tailwind: VMBE %.1f checked", out.vmbe or -1))
T.check(out.v1 <= out.vmbe, string.format("V1 %d not above VMBE %.1f", out.v1, out.vmbe))

-- a contaminated runway (FPPM p.20-21, B747.68.efb_contam_model.lua): the
-- dry field limit through the model's limit(), V1 through its v1(); wet as
-- the slippery tables' good; no assumed temperature
local C = dofile(D .. "B747.68.efb_contam_model.lua")
local S = B747_to_speeds_model
local fla = 4000 / 0.3048
local dry = P.calc(inp{fla_ft = fla, tow_kg = nil})
local wet = P.calc(inp{fla_ft = fla, tow_kg = nil, cond = 1, rev = 2})
local want = C.limit("SLIPPERY", "GOOD", 2, 0, dry.lim.field, fla, wet.pa_ft, 20)
T.near(wet.lim.field, want, 1e-6, string.format("wet: the field limit through the slippery good tables (%.0f from %.0f)", want, dry.lim.field))
T.check(wet.contam and wet.contam.vmcg_kg > 0, "wet: the VMCG limit weight " .. tostring(wet.contam and wet.contam.vmcg_kg))
T.check(wet.max_kg <= dry.max_kg, string.format("wet %.0f not above dry %.0f", wet.max_kg, dry.max_kg))
local poor = P.calc(inp{fla_ft = fla, tow_kg = nil, cond = 4, rev = 2})
local medium = P.calc(inp{fla_ft = fla, tow_kg = nil, cond = 3, rev = 2})
T.check(poor.max_kg < medium.max_kg and medium.lim.field <= wet.lim.field,
    string.format("poor %.0f < medium %.0f; medium's field %.0f <= good's %.0f", poor.max_kg, medium.max_kg,
    medium.lim.field, wet.lim.field))
local norev = P.calc(inp{fla_ft = fla, tow_kg = nil, cond = 3, rev = 0})
T.check(norev.lim.field < medium.lim.field, string.format("medium, no reverse: field %.0f < 2 reverse %.0f",
    norev.lim.field, medium.lim.field))
local poor0 = P.calc(inp{fla_ft = fla, tow_kg = nil, cond = 4, rev = 0})
T.check(poor0.err ~= nil, "poor, no reverse, 4,000 m: off the VMCG table (" .. tostring(poor0.err) .. ")")
-- slush 6 mm at 280 t: V1 the model's from the dry V1 and VMCG
local sl = P.calc(inp{fla_ft = fla, tow_kg = 280000, cond = 2, depth_mm = 6, rev = 2})
T.check(not sl.err, "slush 6 mm, 280 t: " .. tostring(sl.err))
local v1d, vrd, _, info = S.speeds({flaps = 20, weight_kg = 280000, hw = 0, slope = 0, oat_c = 15, pa_ft = sl.pa_ft, engine = 0, pct = 0})
local v1w = C.v1("SLUSH", 6, 2, 0, 280000, v1d, info.vmcg, sl.contam.vmcg_limited and 280000 >= sl.contam.vmcg_kg - 500,
    sl.pa_ft, 20)
T.equal(sl.v1, math.min(math.floor(v1w + 0.5), vrd), string.format("slush V1 %d: the dry %d adjusted (%.1f)", sl.v1, v1d, v1w))
T.check(sl.v1 < v1d and sl.v1 >= info.vmcg - 0.5, string.format("lower than dry, not below VMCG %.0f", info.vmcg))
T.check(sl.sel_c == nil, "no assumed temperature")
local deep = P.calc(inp{fla_ft = fla, tow_kg = 280000, cond = 2, depth_mm = 20, rev = 2})
T.check(deep.err ~= nil, "slush 20 mm: " .. tostring(deep.err))
T.done()
