-- 747-400 EFB takeoff performance without X-Plane (2026-11-25, the user's
-- takeoff and landing performance window "in X-Plane";
-- docs/overhaul/notes/ATA-34-61-FMC.md §191): the EFB's PERFORMANCE -
-- TAKEOFF page (FCOM p.1181-1182, 10.45.23-24, "Typical") worked as the
-- FPPM's simplified takeoff analysis (747-400F/PW4056, D632U002-RZ043 Rev 7,
-- p.19-22 (1.1.1-4)):
--  - the maximum brake release weight the least of the field length, climb,
--    tire speed, brake energy and structural limit weights (p.19). Not the
--    obstacle limit: no obstacle data (the charts are for use without an
--    airport analysis);
--  - the field length limit (p.27-28: B747.68.efb_field_model.lua), the
--    climb, tire speed and brake energy limits (p.29-34:
--    B747.68.efb_limits_model.lua), each with its notes' bleed adjustment;
--  - the derates TO1 (8 %) and TO2 (20 %): the full rating's limit weights
--    through p.47's (1.3.1) and p.59's (1.3.13) tables; other percentages
--    (the GE's 5 and 15 %: FCOM p.1314) between the tables, past 20 % the
--    TO2's, past the tables' lightest weights their last step carried on
--    (estimates);
--  - the brake energy: when outside the VMBE chart's shaded area or with a
--    tailwind, V1 above VMBE takes the weight down by the chart's amount a
--    knot (p.20);
--  - the assumed temperature (when asked, and only on a dry runway: p.22)
--    the highest whole degree above the OAT at which the field and climb
--    limit weights (with the derate) still cover the takeoff weight, up to
--    the field chart's ASSUMED TEMPERATURE LIMIT and 25 % less thrust than
--    the (derated) rating (p.22; FCOM p.1273), with V1 at that temperature
--    not above VMBE when it has to be checked. Estimate: the FPPM gives the
--    limit line and the 25 %, not this search; the tire speed and brake
--    energy taken at the OAT;
--  - V1, VR and V2 the FMC's (B747.60.to_speeds_model.lua: FPPM p.41-43,
--    54-56, 66-68, the minimum control speeds at the OAT), V1 then not
--    above VMBE (p.20);
--  - the takeoff EPR (P&W, the RB211's on its own scale) or N1 (GE) and the
--    thrust reduction the FMC's reference (B747.42.ref_thrust_model.lua:
--    FPPM p.44, 57, 69), the stabilizer trim the FMC's
--    (B747.68.to_trim_model.lua: FPPM p.44, 57, 69), VREF 30 for a return
--    the FMC's (B747.68.vref_model.lua: FCOM PI.10.2).
-- GE and RR on the PW4056 freighter's data (estimate, as the FMC's takeoff
-- speeds).
--
--   local P = B747_efb_to_model          -- in XTLua, after the models' dofile
--   local out = P.calc(inp)
-- inp: engine (0 PW, 1 GE, 2 RR), flaps (10, 20), rating (0 TO, 1 TO 1,
-- 2 TO 2), to_pct (its thrust reduction, %), atm (the assumed temperature
-- wanted), cond (0 dry), packs (3, 1 or 0 on), eng_ai, wing_ai (anti-ice
-- on), oat_c, qnh_hpa, elev_ft (the airport's), fla_ft (the field length
-- available), slope_pct (uphill +), wind_kt (headwind +), tow_kg (nil: the
-- limits only), cg_pct (nil: no trim), mtow_kg (the structural limit).
-- out: pa_ft; lim = {field, climb, tire, brake, struct} (kg; nil off the
-- charts); max_kg and limit (the least's name); err (a reason: then no
-- speeds); sel_c (the assumed temperature or nil) and atm_why (what held it);
-- v1, vr, v2, vmbe, vmbe_check; thrust (EPR or %N1), thrust_n1 (true for
-- N1), thrust_red (%); trim; vref30.
local M = setmetatable({}, {})
B747_efb_to_model = M

M.RATINGS = {[0] = "TO", [1] = "TO 1", [2] = "TO 2"}
M.SEL_MAX = 0.25        -- the assumed temperature's most thrust reduction (FPPM p.22, FCOM p.1273)

-- the pressure altitude (ft) of an elevation (ft) at a QNH (hPa): the
-- standard atmosphere (FPPM p.25's table: 1004 hPa about +250 ft)
function M.pressure_altitude(elev_ft, qnh_hpa)
    if not qnh_hpa or qnh_hpa <= 0 then return elev_ft end
    return elev_ft + 145442.16 * (1 - (qnh_hpa / 1013.25) ^ 0.190263)
end

-- the derates' limit weights (1000 kg) for the full rating's: {full rated
-- (descending), derated}. TO1 8 % FPPM p.47 (1.3.1), TO2 20 % p.59 (1.3.13)
M.DERATE = {
    [8] = {
        field = {{460, 440, 420, 410, 400, 390, 380, 360, 340, 320, 300, 280, 260},
            {436.5, 417, 397, 384.5, 374, 366.5, 358, 339.5, 321, 302, 283.5, 264.5, 246}},
        climb = {{460, 440, 420, 400, 380, 360, 340, 320, 300, 280, 260},
            {419.5, 401, 383, 364.5, 346, 327.5, 309, 291, 272.5, 254, 235.5}},
        obstacle = {{460, 440, 420, 400, 380, 360, 340, 320, 300, 280, 260},
            {418.5, 400.5, 382, 363.5, 345, 326, 307.5, 289, 270, 251.5, 233}},
        tire = {{460, 440, 420, 400, 390, 380, 360, 340, 320, 300, 280, 260},
            {457, 437, 416.5, 396.5, 383.5, 376.5, 357, 337, 317, 297, 277.5, 257.5}},
    },
    [20] = {
        field = {{460, 450, 440, 420, 400, 380, 360, 340, 320, 300, 280},
            {398.5, 384.5, 375, 357, 340, 325, 308, 291.5, 275, 258, 241.5}},
        climb = {{460, 440, 420, 400, 380, 360, 340, 320, 300, 280},
            {365, 348, 331, 314.5, 298.5, 281, 264, 247, 230.5, 213.5}},
        obstacle = {{460, 440, 420, 400, 380, 360, 340, 320, 300, 280},
            {356.5, 341, 325, 309.5, 293.5, 277.5, 260.5, 244, 227.5, 211}},
        tire = {{460, 440, 420, 410, 400, 390, 380, 360, 340, 320, 300, 280},
            {452, 432, 411.5, 401.5, 383.5, 378.5, 371.5, 352, 332.5, 313, 293.5, 274}},
    },
}

-- a table's derated weight (1000 kg) for a full rated one: linear between
-- the columns, the end steps carried on outside (estimate)
local function derate_cell(tab, w)
    local f, d = tab[1], tab[2]
    local n = #f
    local i = 1
    if w <= f[n] then
        i = n - 1
    elseif w < f[1] then
        while w < f[i + 1] do i = i + 1 end
    end
    return d[i] + (d[i + 1] - d[i]) * (w - f[i]) / (f[i + 1] - f[i])
end

-- a limit weight (kg) of the full rating with a thrust reduction (%): kind
-- "field", "climb", "obstacle" or "tire"; nil stays nil
function M.derated(kind, w_kg, pct)
    if not w_kg or not pct or pct <= 0 then return w_kg end
    local w = w_kg / 1000
    local d8 = derate_cell(M.DERATE[8][kind], w)
    if pct <= 8 then return 1000 * (w + (d8 - w) * pct / 8) end
    local d20 = derate_cell(M.DERATE[20][kind], w)
    if pct >= 20 then return 1000 * d20 end
    return 1000 * (d8 + (d20 - d8) * (pct - 8) / 12)
end

-- the field length and climb limit weights (kg, derated) at a temperature
-- (an assumed one with `assumed`); nil and the reason off the charts
local function field_climb(inp, t, assumed)
    local F, L = B747_efb_field_model, B747_efb_limits_model
    local f, fwhy = F.limit_weight(inp.flaps, t, inp.pa_ft, inp.fla_ft, inp.slope_pct, inp.wind_kt, assumed)
    if f then f = M.derated("field", f + F.bleed_adjust_kg(inp.flaps, inp.packs), inp.to_pct) end
    local c, cwhy = L.climb_limit(inp.flaps, t, inp.pa_ft)
    if c then
        c = M.derated("climb", c + L.climb_bleed_adjust_kg(inp.flaps, inp.packs, inp.eng_ai, inp.wing_ai), inp.to_pct)
    end
    return f, c, fwhy, cwhy
end

-- V1, VR, V2 (whole knots) for a weight at the OAT or an assumed temperature
local function speeds(inp, w, sel)
    return B747_to_speeds_model.speeds({flaps = inp.flaps, weight_kg = w, hw = inp.wind_kt, slope = inp.slope_pct,
        oat_c = inp.oat_c, sel_c = sel, pa_ft = inp.pa_ft, engine = inp.engine, pct = inp.to_pct})
end

-- VMBE (KIAS) for a weight at the OAT, and whether it must be checked: out
-- of the shaded area, or with a tailwind (p.20)
local function vmbe(inp, w)
    local L = B747_efb_limits_model
    local v = L.vmbe(w, inp.oat_c, inp.pa_ft, inp.slope_pct, inp.wind_kt)
    local need = (inp.wind_kt or 0) < 0 or L.vmbe_check_needed(w, inp.pa_ft)
    return v, need
end

-- the reference thrust (EPR or %N1) and its reduction (%) for the rating at
-- the OAT, or at an assumed temperature
local function thrust(inp, sel)
    local R = B747_ref_thrust_model
    local mode = (sel and "D-" or "") .. M.RATINGS[inp.rating or 0]
    local ge = inp.engine == 1
    local v, red = R.reference({type = ge and "GE" or "PW", mode = mode, to_pct = inp.to_pct or 0, sel = sel,
        alt = inp.pa_ft, tat = inp.oat_c, oat = inp.oat_c, mach = 0, kias = 0, packs_on = inp.packs,
        wai = inp.wing_ai and true or false, nai = inp.eng_ai and true or false, rr = inp.engine == 2})
    if inp.engine == 2 and B747_rr_model then v = B747_rr_model.display(v, 0) end
    return v, red
end

-- the hottest assumed temperature (whole °C) whose thrust is not more than
-- 25 % below the (derated) rating's, from the OAT up to `hi`; nil if none
local function sel_by_thrust(inp, hi)
    local floor = 100 * (1 - (1 - (inp.to_pct or 0) / 100) * (1 - M.SEL_MAX))
    local best
    for t = math.floor(inp.oat_c) + 1, math.floor(hi) do
        local _, red = thrust(inp, t)
        if red > floor - 0.05 then
            -- at the 25 % floor: this degree is where the thrust stops
            -- falling, the hottest worth having
            return t
        end
        best = t
    end
    return best
end

local function least(lim)
    local best, name
    for _, k in ipairs({"field", "climb", "tire", "brake", "struct"}) do
        local v = lim[k]
        if v and (not best or v < best) then best, name = v, k end
    end
    return best, name
end

-- the maximum takeoff and landing tailwind (kt): FCOM p.77 (L.10.1), 10 kt
-- the 570 (GE), 15 kt the 109 (P&W and RR)
function M.tailwind_max(engine)
    return engine == 1 and 10 or 15
end

function M.calc(inp)
    local out = {lim = {}}
    inp.pa_ft = M.pressure_altitude(inp.elev_ft or 0, inp.qnh_hpa)
    out.pa_ft = inp.pa_ft
    local tail = M.tailwind_max(inp.engine)
    if (inp.wind_kt or 0) < -tail - 1e-6 then
        out.err = "TAILWIND ABOVE " .. tail .. " KT"
        return out
    end
    local F, L = B747_efb_field_model, B747_efb_limits_model
    -- the limits at the OAT
    local f, c, fwhy, cwhy = field_climb(inp, inp.oat_c, false)
    local tire, twhy = L.tire_limit(inp.flaps, inp.oat_c, inp.pa_ft, inp.wind_kt)
    tire = M.derated("tire", tire, inp.to_pct)
    local lim = out.lim
    lim.field, lim.climb, lim.tire, lim.struct = f, c, tire, inp.mtow_kg
    if not f or not c or not tire then
        out.err = fwhy or cwhy or twhy or "OFF THE CHARTS"
        return out
    end
    local maxw, name = least(lim)
    -- the brake energy at that weight (p.20): V1 above VMBE takes the
    -- weight down by the chart's amount a knot
    local v1 = speeds(inp, maxw, nil)
    local vm, need = vmbe(inp, maxw)
    if vm and need and v1 > vm then
        -- a normal takeoff's (not improved climb's) weight a knot
        lim.brake = maxw - (v1 - vm) * L.vmbe_weight_per_kt(false)
        maxw, name = least(lim)
    end
    out.max_kg, out.limit = maxw, name
    local w = inp.tow_kg
    if not w then return out end
    if w > maxw + 0.5 then
        out.err = "WEIGHT ABOVE " .. string.upper(name) .. " LIMIT"
        return out
    end
    -- the assumed temperature
    local sel
    if inp.atm then
        if (inp.cond or 0) ~= 0 then
            out.atm_why = "RUNWAY NOT DRY"
        else
            local hi = F.atm_limit_c(inp.flaps, inp.pa_ft)
            out.atm_why = "LIMIT LINE"
            local by_thrust = sel_by_thrust(inp, hi)
            if by_thrust and by_thrust < math.floor(hi) then hi, out.atm_why = by_thrust, "25 % THRUST" end
            for t = math.floor(hi), math.floor(inp.oat_c) + 1, -1 do
                local ft, ct = field_climb(inp, t, true)
                if ft and ct and ft >= w and ct >= w then
                    local v1t = speeds(inp, w, t)
                    local vmt, needt = vmbe(inp, w)
                    if not (vmt and needt and v1t > vmt) then
                        sel = t
                        break
                    end
                    out.atm_why = "BRAKE ENERGY"
                else
                    out.atm_why = (ft and ft >= w) and "CLIMB" or "FIELD"
                end
            end
            if not sel then out.atm_why = out.atm_why or "NONE" end
        end
    end
    out.sel_c = sel
    -- the speeds, VMBE, thrust, trim
    out.v1, out.vr, out.v2 = speeds(inp, w, sel)
    out.vmbe, out.vmbe_check = vmbe(inp, w)
    if out.vmbe and out.vmbe_check and out.v1 > out.vmbe then out.v1 = math.floor(out.vmbe) end
    out.thrust, out.thrust_red = thrust(inp, sel)
    out.thrust_n1 = inp.engine == 1
    if inp.cg_pct then out.trim = B747_to_trim_model.trim(inp.rating or 0, w / 1000, inp.cg_pct) end
    out.vref30 = B747_vref_model.vref(30, w, inp.elev_ft or 0)
    return out
end

return M
