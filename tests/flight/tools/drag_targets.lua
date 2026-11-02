-- The flap and gear drag against the FCOM, three ways (notes/AERO.md §3.16):
--   luajit tests/flight/tools/drag_targets.lua      (from the repository root)
-- The FCOM's tables give EPR, N1 or the fuel flow; each becomes a thrust
-- (the EPR model B747.42.epr_model.lua; the PW N1 display formula
-- N1_display_PW turned around; the fuel flow over X-Plane's thrust specific
-- fuel consumption), then a drag (level: 4 x thrust along the path; the 3
-- degree glide path adds W sin 3) and a CD at the table's speed. X-Plane's
-- CD is the recorded one moved to the same CL with the induced drag 0.055 x
-- CL^2 (§3.4). The X-Plane figures are written in below from the runs named
-- (aero_compare.lua prints them); change them for new runs.
dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")
local P = B747_epr_model
local unpack = table.unpack or unpack
local S, G, K = 541.2, 9.80665, 0.055

local function isa(h_ft)
    local T = 288.15 - 0.0019812 * h_ft
    local delta = (T / 288.15) ^ 5.2559
    return T, delta, delta / (T / 288.15)
end
local function mach_cas(kcas, h_ft)
    local _, delta = isa(h_ft)
    local a0, p0 = 340.294, 101325
    local qc = p0 * ((1 + 0.2 * (kcas * 0.514444 / a0) ^ 2) ^ 3.5 - 1)
    return math.sqrt(5 * ((qc / (p0 * delta) + 1) ^ (2 / 7) - 1))
end
-- the PW N1 display formula (B747.42.xt.EEC.PW.lua) turned around: an
-- engine's thrust (N) for a displayed N1 above idle, engine running
local function n1_thrust(n1, h_ft, m)
    local T, _, sigma = isa(h_ft)
    local rpm = n1 / 100 * 3600 / math.sqrt(T / 288.15) - (-508 * m * m + 1792.2 * m + 1065.4)
    local a = 0.0136 * m * m - 0.00905 * m - 0.0107
    local b = -5.84 * m * m + 0.512 * m + 13.5
    local c = (-b + math.sqrt(b * b + 4 * a * rpm)) / (2 * a)
    return c / (-0.0811 * m * m + 0.2349 * m + 0.919) * 1000 * sigma
end

-- X-Plane: aero_flap_drag_check (2026-11-02 04:56, level at 5,000 ft):
-- name, KIAS, t, CL, CD; the FCOM row at that weight (PI.10.39-10.40):
-- KIAS, EPR, N1, pitch, the table's altitude (ft), path (deg)
local ROWS = {
    {"UP",  230.7, 269.7, 0.565, 0.0346, 229.9, 1.034, 59.5, 5.50, 5000, 0},
    {"1",   225.1, 269.1, 0.591, 0.0436, 209.7, 1.054, 62.0, 7.00, 5000, 0},
    {"5",   190.7, 268.7, 0.818, 0.0673, 189.6, 1.087, 65.4, 7.69, 5000, 0},
    {"10",  173.7, 268.3, 0.983, 0.0901, 169.5, 1.097, 65.6, 8.50, 5000, 0},
    {"20G", 166.4, 267.9, 1.069, 0.1334, 159.4, 1.144, 71.8, 7.50, 5000, 0},
    {"25G", 166.0, 267.7, 1.079, 0.1414, 164.6, 1.064, 56.5, 2.00, 1500, -3},
    {"30G", 159.8, 267.3, 1.160, 0.1703, 158.8, 1.097, 63.5, 1.00, 1500, -3},
}
print("X-Plane - FCOM at the table's CL (positive: X-Plane has more drag)")
print("cfg   CL     X-Plane | from EPR       | from N1")
for _, r in ipairs(ROWS) do
    local name, _, t, cl, cd, vt, epr, n1, pitch, h, gam = unpack(r)
    local m = mach_cas(vt, h)
    local _, delta = isa(h)
    local q = 0.7 * 101325 * delta * m * m
    local W = t * 1000 * G
    local cl_t = W * math.cos(math.rad(gam)) / (q * S)
    local cd_xp = cd + K * (cl_t ^ 2 - cl ^ 2)
    local alpha = math.rad(pitch - gam)
    local function cd_of(thrust)
        return (4 * thrust * math.cos(alpha) - W * math.sin(math.rad(gam))) / (q * S)
    end
    local ce = cd_of(P.thrust(epr, delta, m) * 1000)
    local cn = cd_of(n1_thrust(n1, h, m))
    print(string.format("%-4s %5.3f  %.4f | %.4f %+5.1f%% | %.4f %+5.1f%%   M%.3f", name, cl_t, cd_xp,
        ce, (cd_xp / ce - 1) * 100, cn, (cd_xp / cn - 1) * 100, m))
end

-- the gear: FCOM PI.16.3 (p.303), 10,000 ft, 270 t: EPR 1.14, M.4485, 3,630
-- kg/h an engine. X-Plane: aero_gear_down (2026-11-02 04:03, before the
-- correction): gear down 243.0 KIAS, CL 0.510, CD 0.0532, 68.08 kN and
-- 0.9250 kg/s an engine; gear up 244.2 KIAS, CL 0.506, CD 0.0311. X-Plane's
-- fuel flow is 2.7 % high in the holding at 10,000 ft (§3.9)
do
    local h, m, W = 10000, 0.4485, 270000 * G
    local _, delta = isa(h)
    local q = 0.7 * 101325 * delta * m * m
    local cl = W / (q * S)
    local cd_dn = 0.0532 + K * (cl ^ 2 - 0.510 ^ 2)
    local cd_up = 0.0311 + K * (cl ^ 2 - 0.506 ^ 2)
    local alpha = math.rad(5)
    local ce = 4 * P.thrust(1.14, delta, m) * 1000 * math.cos(alpha) / (q * S)
    local sfc = 0.9250 / 68076 / 1.027
    local cf = 4 * (3630 / 3600 / sfc) * math.cos(alpha) / (q * S)
    print(string.format("gear (CL %.3f): X-Plane %.4f (down %.4f, up %.4f) | from EPR %.4f (%+.4f) | from the fuel flow %.4f (%+.4f)",
        cl, cd_dn - cd_up, cd_dn, cd_up, ce - cd_up, ce - cd_dn, cf - cd_up, cf - cd_dn))
end

-- the FCOM against itself at 5,000 ft, flaps up, 270 t, about 230 KIAS:
-- holding (PI.11.6 p.272) EPR 1.02 at 280 t, 1.01 at 260 t; terminal area
-- (PI.10.39) 1.034
do
    local m = mach_cas(230.5, 5000)
    local _, delta = isa(5000)
    print(string.format("5,000 ft, 230 kt, flaps up: holding EPR 1.015 = %.1f kN, terminal area 1.034 = %.1f kN an engine",
        P.thrust(1.015, delta, m), P.thrust(1.034, delta, m)))
end
