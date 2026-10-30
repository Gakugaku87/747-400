-- The custom acf's aerodynamic changes from the comparison with the FCOM and
-- FCTM, and the engines' since 2026-10-30 (PROGRESS.md 5f, notes/AERO.md).
-- Run from the repository root:
--   luajit docs/overhaul/tools/acf_aero.lua <acf in> <acf out> [key=value ...]
-- It prints every change: the values in SET below (or given as
-- <key>=<value> arguments, for trying), each the whole "P <key> <value>"
-- line of the acf (e.g. acf/_flap1_cl, _wing/0/_incidence/0). A key given
-- with a trailing "/*" sets every index of that array (_wing/0/_incidence/*);
-- in SET, a list for an array key sets its indexes from 0 in order.
-- Already changed lines are left alone, so it can run again. The line
-- endings are kept. The shape (span, area, sweep, dihedral, position) is
-- never set here (notes/AERO.md).
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: acf_aero.lua <acf in> <acf out> [key=value ...]")
-- the changes kept
-- the main wing's incidence 1.0 deg lower at every station, the twist kept
-- (2026-10-29: the custom acf flew about 1.0 deg flatter than the FCOM's
-- attitudes, PI.10.38-10.40, clean; notes/AERO.md)
local INC = {
    [0] = {2.0, 2.0, 2.0, 2.0, 1.8, 1.6, 1.4, 1.2, 1.2, 1.2},
    [2] = {1.0, 1.0, 1.0, 1.0, 0.5, 0.3, 0.1, 0.0, -0.2, -0.2},
    [4] = {1.0, 0.9, 0.3, 0.1, 0.0, 0.3, 0.1, 0.0, -0.1, -0.2},
    [6] = {-0.2, -0.3, -0.5, -0.6, -0.7, -0.8, -0.9, -1.0, -1.0, -1.0},
}
-- the trailing edge flaps' last detent 40 -> 50 deg (both flap sets): X-Plane
-- grew their lift in proportion up to half the last detent and no more
-- (20 deg: 20, 25 and 30 gave the same), the FCOM's attitudes want it
-- growing to 30 (notes/AERO.md). The FCU writes the angles itself (the 3D
-- flaps follow laminar/B747/flt_ctrls/flaps), so no look changes.
-- 2026-10-30: the last detent 75 and the flaps' lift coefficient 1.35 ->
-- 1.62, which gave flaps 30 the FCOM's lift (within 0.05 deg of its
-- attitude); X-Plane's lift then hardly grows past 20 deg (notes/AERO.md
-- section 3.10), so the FCU gives X-Plane smaller angles at 5 to 25, a
-- correction the user allowed (B747.19.xt.hydraulics_override.lua)
-- the bodies' drag: the four nacelles (bodies 21-24) 0.1 -> 0.025 and the
-- wing to body fairing (body 1) 0.06 -> 0.03. Measured (aero_drag.json),
-- a unit of Cd on the four nacelles is 0.054 of the airplane's CD (wing
-- 541 m2), on the fairing 0.032, on the fuselage 0.071: the nacelles gave
-- 0.0054, about four times their outer skin's friction (estimate: the
-- engine model already has the inlet's ram drag in its net thrust); the
-- fuselage's 0.0060 is about its skin friction's and stays
local SET = {
    ["acf/_flap1_dn/6"] = 75,
    ["acf/_flap2_dn/6"] = 75,
    ["acf/_flap1_cl"] = 1.62,
    ["acf/_flap2_cl"] = 1.62,
    ["_body/1/_part_cd"] = 0.03,
    ["_body/21/_part_cd"] = 0.025,
    ["_body/22/_part_cd"] = 0.025,
    ["_body/23/_part_cd"] = 0.025,
    ["_body/24/_part_cd"] = 0.025,
    -- the engines' idle fuel flow (2026-10-30): X-Plane's jet idle burns this
    -- share whatever the idle thrust (measured: 0.01 gave 0.02 kg/s standing
    -- at sea level, about none in flight; aero_idle_ground.json). Aimed at
    -- about 0.13 kg/s at the 10.3 kN ground idle: the ICAO fuel flows at 30
    -- and 7 % of the rated thrust (0.647 and 0.188 kg/s, ICAO_EEDB 1PW041)
    -- carried on straight to 4 % (estimate). 0.062 gave 0.150 (s11), so 0.054
    ["acf/_ff_rat_idle_JET"] = 0.054,
    -- the tyres' rolling friction 0.025 -> 0.015 (2026-10-30, the user
    -- allowed it for the FCTM's taxi, p.76: idle keeps a taxi going in most
    -- conditions, a slightly higher thrust begins it). At 270 t on RJAA 34L
    -- with the 10.3 kN ground idle (aero_idle_taxi_roll.json): 0.020 slows
    -- from 23 kt, 0.015 holds 26 kt and does not start from a stop, 0.012
    -- starts from a stop
    ["acf/_roll_co"] = 0.015,
    -- the engines' fuel per thrust (lb/lbf/h) at X-Plane's four points
    -- (2026-10-30): the FCOM's holding (PI.11.6) and Long Range
    -- Cruise (PI.11.2) fuel flows at the thrust the custom acf needs there
    -- ask for about 0.52 at part power, X-Plane gave 0.41-0.47; takeoff
    -- matched ICAO (0.348 in the takeoff run, ICAO_EEDB 1PW041 0.343 standing).
    -- From the measured effect of each point (aero_sfc_sweep.json); trial
    -- 1 (takeoff 0.323, climb 0.481, low cruise 0.442, high cruise 0.510)
    -- gave the cruise 4-6 % short, holding 2-4 % over and the takeoff run
    -- 0.384 (the climb point reaches it). These (trial 2): the cruise
    -- within 2 %, holding 2-3 % over, the takeoff run 2.48 kg/s (ICAO 2.45
    -- standing)
    ["acf/_jet_SFC_takeoff"] = 0.300,
    ["acf/_jet_SFC_climb"] = 0.440,
    ["acf/_jet_SFC_locrz"] = 0.470,
    ["acf/_jet_SFC_hicrz"] = 0.535,
}
for w, v in pairs(INC) do
    SET["_wing/" .. w .. "/_incidence"] = v       -- left
    SET["_wing/" .. (w + 1) .. "/_incidence"] = v -- right
end
for i = 3, #arg do
    local k, v = arg[i]:match("^([%w_/%*]+)=([%-%d%.]+)$")
    assert(k, "bad argument " .. arg[i])
    SET[k] = tonumber(v)
end
local function wanted(key)
    if type(SET[key]) == "number" then return SET[key], key end
    local base, i = key:match("^(.*)/(%d+)$")
    if base and SET[base .. "/*"] then return SET[base .. "/*"], base .. "/*" end
    if base and type(SET[base]) == "table" then return SET[base][tonumber(i) + 1], base end
    return nil
end

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local changed, seen = 0, {}
for i, l in ipairs(lines) do
    local pk, pv = l:match("^P (%S+) (%S+)$")
    if pk and not pk:match("/count$") then
        local v, which = wanted(pk)
        if v then
            local new = string.format("%.9f", v)
            if pv ~= new then
                lines[i] = "P " .. pk .. " " .. new
                print(string.format("%s: %s -> %s", pk, pv, new))
                changed = changed + 1
            end
            seen[which] = true
        end
    end
end
for k in pairs(SET) do assert(seen[k], "no line for " .. k) end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print(string.format("%d line(s) changed; written %s", changed, dst))
