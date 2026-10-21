-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The takeoff speeds the 747 shows (B747_setV1VrV2, B747.60.xt.fltInst02.lua, from the tables of
-- B747.60.xt.fltInst.lua: the PMDG 747-400 AOM's "PW 4062" dry-runway pages) are the FCOM's: V1 not below VMCG, VR
-- not below VRMIN (nor VMCG), and V2 not below the "V2 for VRMIN" where VR was raised (FCOM PI.18.2; the PW4056's
-- VMCG/VRMIN by pressure altitude and the actual OAT, PI.10.10; cckit research_vspeeds.md). At 233 t, flaps 20, sea
-- level the tables gave 101/114/139 (the 747 rotated at 114 kt on the EIDW-EHAM line flights) against 121/124/144.
-- The production functions run against mocked datarefs in XTLua's namespace (init.lua's create_namespace), where a
-- global table without a metatable is copied into a namespace of its own that reads a missing index by recursing
-- until the stack overflows and has no length (B747_VMCG_VRMIN_DERATE[0] stopped the instruments, the FMC and the
-- autopilot at the flaps entry: p32, 2026-10-20); this does not validate the tables' own figures.
local DIR = "plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
-- the source of fltInst02.lua from one marker to the next, at its own line numbers
local function slice(first_marker, last_marker)
    local source = read(DIR.."B747.60.xt.fltInst02.lua")
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1)
end

-- XTLua's script runtime, for its namespaces
local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()

-- The production V speeds in XTLua's namespace for a weight (kg), flaps (10, 20), airport altitude (ft, the
-- altimeter's), OAT (C), wind (from, kt), runway heading, takeoff derate (0, 1, 2), the altimeter setting (inHg; 29.92
-- without); run(env) is one frame of fltInst02's after_physics for them (nil if it failed: the error kept for a check)
local frame_error
local function run(env)
    local ok, err = pcall(function()
        env.B747_setTempAltRegion()
        env.B747_V1_wind_adjustment()
        env.B747_setV1VrV2()
    end)
    if not ok then
        frame_error = frame_error or err
        return nil
    end
    return env.B747DR_airspeed_V1, env.B747DR_airspeed_Vr, env.B747DR_airspeed_V2
end
local function load(weight, flaps, altitude, oat, wind_from, wind_kt, heading, derate, baro)
    local env = runtime.create_namespace()
    for name, value in pairs({simDR_acf_weight_total_kg = weight, B747DR_airspeed_flapsRef = flaps,
            B747DR_radio_altitude = 0, simDR_OAT_degC = oat, simDR_altitude_ft_pilot = altitude,
            simDR_wind_heading_deg = wind_from or 0, simDR_wind_speed_kts = wind_kt or 0,
            simDR_position_mag_psi = heading or 0, simDR_all_wheels_on_ground = 1, simDR_airspeed = 0,
            B747DR_airspeed_V1 = 0, B747DR_airspeed_Vr = 0, B747DR_airspeed_V2 = 0, B747DR_toderate = derate or 0,
            lastFlaps = -1, simDR_altimeter_baro_inHg = baro or 29.92}) do
        env[name] = value
    end
    -- the tables (fltInst.lua up to its dofile of the other parts)
    local tables = read(DIR.."B747.60.xt.fltInst.lua")
    tables = tables:sub(1, assert(tables:find('dofile("B747.60.xt.fltInst02.lua")', 1, true)) - 1)
    setfenv(assert(loadstring(tables)), env)()
    -- the flaps reference's find_dataref gives the mocked value back
    env.find_dataref = function() return env.B747DR_airspeed_flapsRef end
    for _, part in ipairs({{"function B747_rescale(", "function roundUp(x)"},
            {"function recipAngle(angle)", "----- CLOCK (CAPTAIN)"},
            {"local regions = {}", "    -- crazytimtimtim V1 callout"}}) do
        local code = slice(part[1], part[2])
        if part[1] == "local regions = {}" then code = code.."end\n" end
        setfenv(assert(loadstring(code)), env)()
    end
    return env
end
-- V1, VR and V2 after one frame
local function speeds(...)
    return run(load(...))
end
local function near(got, want, tolerance) return got and math.abs(got - want) <= tolerance end

-- the minimum tables as XTLua holds them: plain tables (a metatable keeps the namespace from copying them), a missing
-- index nil (full thrust's derate 0, flaps 30), the rows' count 7
do
    local env = load(233100, 20, 0, 15)
    local ok, got = pcall(function() return env.B747_VMCG_VRMIN_DERATE[0] end)
    check(ok and got == nil, "B747_VMCG_VRMIN_DERATE[0] in XTLua's namespace: "..tostring(got).." (nil)")
    ok, got = pcall(function() return env.B747_V2_FOR_VRMIN[30] end)
    check(ok and got == nil, "B747_V2_FOR_VRMIN[30] in XTLua's namespace: "..tostring(got).." (nil)")
    check(#env.B747_VMCG_VRMIN == 7, "#B747_VMCG_VRMIN in XTLua's namespace: "..#env.B747_VMCG_VRMIN.." (7)")
end
local function show(v1, vr, v2) return string.format("%.1f/%.1f/%.1f", v1 or -1, vr or -1, v2 or -1) end

-- light: V1 at VMCG, VR at VRMIN, V2 the "V2 for VRMIN" (flaps 20: VR 120 -> 140/140/139/139 at 200/220/240/260 t,
-- VR 125 -> 147/146/145/145)
local v1, vr, v2 = speeds(233100, 20, 200, 15)
check(v1 == 121 and vr == 124 and v2 == 144, "233 t, flaps 20, sea level, 15 C: "
    ..show(v1, vr, v2).." (121/124/144: VMCG and VRMIN rounded up, the V2 for that VR, 144.1, rounded)")
-- heavy enough: the tables' own speeds (126/141.5/159.5 at 310 t)
v1, vr, v2 = speeds(309700, 20, 20, 15)
check(v1 == 126 and vr == 141 and v2 == 159, "310 t, flaps 20, sea level, 15 C: "
    ..show(v1, vr, v2).." (the tables' 125.9/141.4/159.4, rounded)")
-- flaps 10 at 200 t: V2 for VRMIN 142 + 7 x 0.8 = 147.6 at VR 124
v1, vr, v2 = speeds(200000, 10, 0, 15)
check(v1 == 121 and vr == 124 and v2 == 148, "200 t, flaps 10, sea level, 15 C: "
    ..show(v1, vr, v2).." (121/124/148)")
-- VMCG/VRMIN lower at altitude and on hot days: 6,000 ft at 10 C 113/116 (region D's VR there 118.6: 119); sea level
-- at 40 C 117/120
v1, vr = speeds(233100, 20, 6000, 10)
check(v1 == 113 and vr == 119, "233 t, flaps 20, 6,000 ft, 10 C: "..show(v1, vr).." (113: VMCG; 119: the table)")
v1, vr = speeds(233100, 20, 0, 40)
check(v1 == 117 and vr == 120, "233 t, flaps 20, sea level, 40 C: "..show(v1, vr).." (117/120)")
-- and with the takeoff derated (TO 1 10 %, TO 2 20 %): sea level 116/119 and 108/111 (VR then the table's 114.2)
v1, vr = speeds(233100, 20, 0, 15, 0, 0, 0, 1)
check(v1 == 116 and vr == 119, "233 t, flaps 20, sea level, TO 1: "..show(v1, vr).." (116/119)")
v1, vr = speeds(233100, 20, 0, 15, 0, 0, 0, 2)
check(v1 == 108 and vr == 114, "233 t, flaps 20, sea level, TO 2: "..show(v1, vr)
    .." (108/114: VMCG, and the table's VR above VRMIN 111)")
-- the V1 wind correction by the headwind component (the table's +10..+40 kt rows add 1-4 kt, its -5..-15 kt tailwind
-- rows take 1-6 off), between its rows and weights: at 310 t (V1 125.9 calm) on a runway heading 280, wind from 280
-- at 20 kt +2, from 100 at 10 kt -2.5 (the -10 kt row: -2 at 300 t, -3 at 320 t). Taken as the tailwind component
-- and interpolated on the wind speed, a 40 kt headwind took 3 kt off (review 36)
v1 = speeds(309700, 20, 20, 15, 280, 20, 280)
check(v1 == 128, "310 t, flaps 20, runway 280, wind 280/20 (headwind): V1 "..show(v1).." (127.9: 128)")
v1 = speeds(309700, 20, 20, 15, 100, 10, 280)
check(v1 == 123, "310 t, flaps 20, runway 280, wind 100/10 (tailwind): V1 "..show(v1).." (123.4: 123)")
-- each row between its weights: at 302 t the -10 kt row is -2.1 (124.4 - 2.1: 122), not the 320 t cell's -3 (121;
-- review 38)
v1 = speeds(302000, 20, 20, 15, 100, 10, 280)
check(v1 == 122, "302 t, flaps 20, runway 280, wind 100/10 (tailwind): V1 "..show(v1).." (122.3: 122)")
-- beyond the chart's regions the nearest: above region E's top (about 8,000 ft at 0 C) region E (flaps 20, 300 t:
-- V1 135); no region at all left the lookup on a nil index (review 36)
local ok, high_v1 = pcall(speeds, 300000, 20, 9000, 0)
check(ok and high_v1 == 135, "300 t, flaps 20, 9,000 ft, 0 C (above region E): V1 "..tostring(high_v1)
    .." (135, region E)")
-- and colder than its left edge (-60 C) at sea level region A (300 t: 123, as at 15 C; review 38)
local cold_ok, cold_v1 = pcall(speeds, 300000, 20, 0, -62)
check(cold_ok and cold_v1 == 123, "300 t, flaps 20, sea level, -62 C (left of the chart): V1 "..tostring(cold_v1)
    .." (123, region A)")
-- colder than the chart its left edge at the airport's altitude: -62 C at 9,000 ft region E (V1 135, not A's 123);
-- and a point on the line between two regions in the higher one: at 0 C on region A's top (1,050.89 ft) 360 t is
-- region B's 143/160/173, between A's 140/158/173 below and B above (strict edges left it in no region, then E:
-- 152/166/174; review 38)
local cold_high_ok, cold_high_v1 = pcall(speeds, 300000, 20, 9000, -62)
check(cold_high_ok and cold_high_v1 == 135, "300 t, flaps 20, 9,000 ft, -62 C: V1 "..tostring(cold_high_v1)
    .." (135, region E)")
-- region B's top at 36.84 C is about 1,300 ft on the AOM's chart (research_vspeeds.md; the table repeated 26.84 C's
-- 2,876 ft there, so that on hot days region B rose back over 1,300-2,900 ft): at 37 C and 2,000 ft 360 t is region
-- C's 146 (B's 143; review 39)
v1 = speeds(360000, 20, 2000, 37)
check(v1 == 146, "360 t, flaps 20, 2,000 ft, 37 C: V1 "..show(v1).." (146, region C)")
-- and below its bottom on its bottom: -1,240 ft with QNH 30.92 (a pressure altitude of -2,240 ft) region A
local low_ok, low_v1 = pcall(speeds, 300000, 20, -1240, 15, 0, 0, 0, 0, 30.92)
check(low_ok and low_v1 == 123, "300 t, flaps 20, -1,240 ft, QNH 30.92: V1 "..tostring(low_v1).." (123, region A)")
v1, vr, v2 = speeds(360000, 20, 1050.89, 0)
check(v1 == 143 and vr == 160 and v2 == 173, "360 t, flaps 20, 0 C on region A's top (1,050.89 ft): "
    ..show(v1, vr, v2).." (143/160/173, region B)")
-- by pressure altitude, as the FCOM's tables: at a sea level airport with QNH 28.92 inHg (pressure altitude 939 ft)
-- VMCG/VRMIN 119.6/122.6, not the altimeter's sea level 121/124 (review 36)
v1, vr = speeds(233100, 20, 0, 15, 0, 0, 0, 0, 28.92)
check(v1 == 120 and vr == 123, "233 t, flaps 20, sea level, QNH 28.92: "..show(v1, vr)
    .." (119.6/122.6 at a pressure altitude of 939 ft: 120/123)")
-- and the chart's regions: a 1,000 ft airport at 15 C is in region A by its altimeter (360 t, flaps 20: 140/158/173)
-- but in region B at the pressure altitude of 1,932 ft that QNH 28.92 gives (143/160/173; review 38)
v1, vr, v2 = speeds(360000, 20, 1000, 15, 0, 0, 0, 0, 28.92)
check(v1 == 143 and vr == 160 and v2 == 173, "360 t, flaps 20, 1,000 ft, 15 C, QNH 28.92: "..show(v1, vr, v2)
    .." (143/160/173, region B)")
-- the pressure altitude by the standard atmosphere's altimeter relation (as autopilot.takeoff.lua), not 1,000 ft per
-- inHg: at 180 ft with QNH 28.92 it is 1,118 ft, under region A's top at 15 C (1,137 ft; 1,000 ft per inHg gave
-- 1,180 ft, region B's 143/160/173), and a setting read as 0 (XTLua's first read) leaves the altimeter's altitude
-- (review 38)
v1, vr, v2 = speeds(360000, 20, 180, 15, 0, 0, 0, 0, 28.92)
check(v1 == 140 and vr == 158 and v2 == 173, "360 t, flaps 20, 180 ft, 15 C, QNH 28.92: "..show(v1, vr, v2)
    .." (140/158/173, region A)")
v1, vr, v2 = speeds(233100, 20, 200, 15, 0, 0, 0, 0, 0)
check(v1 == 121 and vr == 124 and v2 == 144, "233 t, flaps 20, sea level, the setting read as 0: "
    ..show(v1, vr, v2).." (121/124/144)")
-- a takeoff thrust rating changed once the speeds are set: the FMC deletes them with the flaps entry
-- (fmc_takeoff_rating_test) and, entered again, they are worked out for the new rating: TO 2's 108, then full
-- thrust's VMCG 121 (review 36)
do
    local env = load(233100, 20, 0, 15, 0, 0, 0, 2)
    local first = run(env)
    env.B747DR_toderate, env.B747DR_airspeed_flapsRef = 0, 0
    local deleted = run(env)
    env.B747DR_airspeed_flapsRef = 20
    local again = run(env)
    check(first == 108 and deleted == 999 and again == 121, string.format("233 t, flaps 20, TO 2 then TO: V1 %.1f, "
        .."then %.1f (999: deleted), entered again %.1f (108, 999, 121)", first or -1, deleted or -1, again or -1))
end
-- between the minimum tables' rows and on their slopes (review 36: changes that dropped the altitude interpolation,
-- the VR in the V2 for VRMIN or the V1 <= VR clamp still passed): 1,000 ft 13 C 119.5/122.5/142.3 (120/123/143),
-- 3,000 ft 9 C 116.5/119.5/138.7 (117/120/139), sea level 35 C 119.8/122.8/142.7 (120/123/143); and rounded up, not
-- to the nearest knot: 400 ft 15 C 120.4/123.4 (121/124/144, not 120/123/143; review 38)
for _, case in ipairs({{1000, 13, 120, 123, 143}, {3000, 9, 117, 120, 139}, {0, 35, 120, 123, 143},
        {400, 15, 121, 124, 144}}) do
    v1, vr, v2 = speeds(233100, 20, case[1], case[2])
    check(v1 == case[3] and vr == case[4] and v2 == case[5], string.format("233 t, flaps 20, %d ft, %d C: %s "
        .."(%d/%d/%d)", case[1], case[2], show(v1, vr, v2), case[3], case[4], case[5]))
end
-- and V1 brought down to VR when the wind correction takes it above (a +30 kt correction on the 40 kt row)
do
    local env = load(309700, 20, 20, 15, 280, 40, 280)
    env.V1windAdj[40][300000], env.V1windAdj[40][320000] = 30, 30
    v1, vr = run(env)
    check(v1 == vr and vr == 141, "310 t, flaps 20, a +30 kt V1 correction: V1 "..show(v1, vr).." (= VR, 141)")
end
-- the tables as the PMDG AOM's pages they were copied from (research_vspeeds.md; reviews 36 and 38): flaps 10 region
-- D VR at 320-420 t read 93-111 (rotating 40-65 kt early at a 5,500 ft airport), flaps 20 region D VR at 220 t 97,
-- flaps 20 region E V2 at 380 t 149 (V2 under VR at 360-400 t, in the region now taken above E's top), and 15 cells
-- of the wind table 1 kt off
do
    local env = load(233100, 20, 0, 15)
    for _, c in ipairs({
            {env.B747_Vr[10][4], {[320000] = 156, [340000] = 163, [360000] = 170, [380000] = 176, [400000] = 181,
                [420000] = 187}, "flaps 10 region D VR"},
            {env.B747_Vr[20][4], {[220000] = 114}, "flaps 20 region D VR"},
            {env.B747_V2[20][5], {[380000] = 179}, "flaps 20 region E V2"},
            {env.V1windAdj[-15], {[380000] = -5}, "wind -15 kt"},
            {env.V1windAdj[10], {[300000] = 1, [340000] = 1, [400000] = 1}, "wind +10 kt"},
            {env.V1windAdj[30], {[260000] = 2, [280000] = 2, [300000] = 2, [320000] = 2, [340000] = 2}, "wind +30 kt"},
            {env.V1windAdj[40], {[260000] = 3, [280000] = 3, [300000] = 3, [320000] = 3, [340000] = 3, [360000] = 3},
                "wind +40 kt"}}) do
        for w, want in pairs(c[2]) do
            check(c[1][w] == want, string.format("%s at %d t: %s (%s)", c[3], w / 1000, tostring(c[1][w]), want))
        end
    end
end
for _, w in ipairs({360000, 380000, 400000}) do
    v1, vr, v2 = speeds(w, 20, 9000, 0)
    check(v1 and v2 and v1 <= vr and vr < v2, string.format("%d t, flaps 20, 9,000 ft, 0 C (region E): %s "
        .."(V1 <= VR < V2)", w / 1000, show(v1, vr, v2)))
end
-- V1 never above VR
for _, w in ipairs({200000, 233100, 260000, 300000, 360000, 400000}) do
    for _, f in ipairs({10, 20}) do
        v1, vr, v2 = speeds(w, f, 0, 15)
        check(v1 and v2 and v1 <= vr + 1e-6 and vr < v2, string.format("%d t, flaps %d: V1 <= VR < V2 (%s)",
            w / 1000, f, show(v1, vr, v2)))
    end
end

check(frame_error == nil, "a frame failed: "..tostring(frame_error))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("Takeoff speed tests passed: "..checks)
