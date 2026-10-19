-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The CLB thrust reference of the EEC modules (B747.42.xt.EEC.GE/PW/RR.lua) is the rated climb thrust at every
-- altitude and weight, as on the 747-400: the FMC's reference EPR/N1 from pressure altitude and TAT, held by the A/T
-- in THR REF, the climb rate the result (FCOM; cckit research_clb_thrust.md). Below 20,000 ft the modules took the
-- thrust their own drag model gave for a design climb rate (PW4056: 2,750 fpm below 10,000 ft) when that was less:
-- at 231 t the 747 climbed 1,560 fpm at 10,000 ft and 250 kt (the FCOM's max climb thrust gives about 4,000), and
-- in the acceleration to 290 kt there it fell to 30 fpm (p30-line1, 2026-10-19). Upstream e286c7da had made the GE
-- module use max climb above 20,000 ft, and the PW and RR modules followed (a light 747 crept up at 100-360 fpm in
-- the 20s). The PW4056's max climb EPR is tabled for the 340 kt / M.84 climb; slower, the rating is higher, up to the
-- Initial Climb table's at 200 KIAS (1.49 at 10,000 ft on the cold side against 1.35, less on warm days): linear in
-- Mach between the two, the table's value below 11,000 ft, 0.6 EPR per Mach below the schedule above 12,000 ft (no
-- table). CLB 1 and CLB 2 take 10 and 20 % off the climb thrust to 10,000 ft and give it back linearly by 15,000 ft
-- (the PW and RR as their EPR above 1: CLB 1 about 0.04 EPR less, as crews see it; the GE as N1 to the power 1/3.1,
-- the EEC's N1 for thrust about N1^3.1). Each module's CLB branch runs against mocked ratings; this does not validate
-- the engine model.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC."

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
local function clb_branch(engine)
    local source = read(EEC..engine..".lua")
    local first = assert(source:find('elseif string.match(B747DR_ref_thr_limit_mode, "CLB") then', 1, true))
    local last = assert(source:find('elseif string.match(B747DR_ref_thr_limit_mode, "CRZ") then', first, true))
    return "if false then\n"..source:sub(first, last - 1).."end\n"
end
-- the shared helpers of B747.42.xt.EEC.lua from B747_rescale on to round_thrustcalc, and the EEC's tables
local function helpers(env)
    local source = read(EEC.."lua")
    local first = assert(source:find("function B747_rescale(", 1, true))
    local last = assert(source:find("function round_thrustcalc(", first, true))
    setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
    setfenv(assert(loadstring(read(EEC.."tbls.lua"))), env)()
end

-- The CLB target bug of one module: altitude ft, Mach, CLB derate (0, 1, 2), a light aircraft (the design climb
-- rate's thrust below the rating) or a heavy one (above it), flaps up or out, the outside air temperature (C; ISA
-- without), the max climb rating (RATING without).
local RATING = {GE = 95.0, PW = 1.35, RR = 1.50}
local function clb_target(engine, altitude, mach, derate, light, flaps, sat, max_climb)
    local env = setmetatable({B747DR_ref_thr_limit_mode = "CLB", altitude_ft_in = altitude, mach = mach,
        simDR_altitude = altitude, B747DR_clbderate = derate, packs_adjustment_value = 0,
        engine_anti_ice_adjustment_value = 0, simDR_flap_ratio = flaps or 0, takeoff_TOGA_n1 = 100,
        simDR_temperature = sat or 15 - 1.9812 * altitude / 1000}, {__index = _G})
    helpers(env)
    local rating = max_climb or RATING[engine]
    if engine == "GE" then
        local actual = light and 80.0 or 97.0
        env.in_flight_N1_GE = function() return 0, actual, 0, 0, rating, 0, 0, 0 end
        env.N1_target_bug, env.display_N1_ref, env.display_N1_max = {}, {}, {}
        env.B747DR_display_N1_max, env.B747DR_display_N1_ref = {[0] = 0, 0, 0, 0}, {[0] = 0, 0, 0, 0}
    else
        local actual = light and 1.20 or 1.60
        env["in_flight_EPR_"..engine] = function() return actual, 1.40, rating end
        env.EPR_target_bug, env.display_EPR_ref, env.display_EPR_max = {}, {}, {}
        env.B747DR_display_EPR_max, env.B747DR_display_EPR_ref = {[0] = 0, 0, 0, 0}, {[0] = 0, 0, 0, 0}
    end
    setfenv(assert(loadstring(clb_branch(engine))), env)()
    return tonumber(engine == "GE" and env.N1_target_bug[0] or env.EPR_target_bug[0])
end

-- The rating at every altitude and weight, flaps up or out: at the PW's schedule Mach (340 KIAS: M.59 at 8,000 ft,
-- M.61 at 10,000, M.64 at 12,500, M.67 at 15,000, M.81 at 25,000) or faster, the tabled max climb itself
local SCHEDULE = {[8000] = 0.590, [10000] = 0.611, [12500] = 0.639, [15000] = 0.669, [25000] = 0.84}
for _, engine in ipairs({"GE", "PW", "RR"}) do
    for _, altitude in ipairs({8000, 15000, 25000}) do
        for _, light in ipairs({true, false}) do
            for _, flaps in ipairs({0, 0.5}) do
                local got = clb_target(engine, altitude, SCHEDULE[altitude], 0, light, flaps)
                check(got and math.abs(got - RATING[engine]) < 0.006, string.format("%s CLB at %d ft, %s, flaps %.1f: "
                    .."%s (the rating %.2f)", engine, altitude, light and "light" or "heavy", flaps, tostring(got),
                    RATING[engine]))
            end
        end
    end
end
-- the PW's rating slower than its schedule, from its value at 200 KIAS down to the schedule's Mach. Below 11,000 ft
-- the value at 200 KIAS is the Initial Climb table's, entered with the altitude less 1,000 ft and the OAT plus 2 C:
-- at 10,000 ft (the table at 9,000 ft) 1.49 on the cold side (ISA), 1.43 at 20 C, 1.35 at 30 C; 250 KIAS (M.452)
-- is 64 % of the way from 200 KIAS (M.363) to 340 (M.611): 1.35 + 0.14 x 0.64 = 1.440 (the FCOM at 240 KIAS: 1.46),
-- 1.401 at 20 C. Above 12,000 ft (no table) 0.6 EPR per Mach below the schedule (the table's cold side), kept to the
-- table's warm-day share at its 10,000 ft row for the same ISA deviation: at 15,000 ft, 250 KIAS (M.497; M.669 at
-- 340) 1.453 at ISA (-14.7 C), 1.425 at ISA+20 (5.3 C: the row at 15.2 C reads 1.458, 72 % of the way from 1.35 to
-- 1.50), max climb itself at ISA+40 (25 C). On warm days 0.6 per Mach overshot the table by up to 0.15 (review 34),
-- above 12,000 ft by 0.03-0.15 (review 35). The ISA deviation is the same at the row only with the lapse stopped at
-- the tropopause: at 41,000 ft and ISA+15 (-41.5 C) M.75, 1.404 (the row at 10.2 C: 99 %; lapsed on above 36,089 ft
-- it read 19.9 C, 47 %: 1.375; review 37). Between 11,000 and 12,000 ft the two are blended: at 11,500 ft and ISA+40
-- (32.2 C) at 200 KIAS (M.373) the table and the share both give max climb. At M.84 nothing is added; and a rating so
-- raised is held to the table's top, 1.64: M.81 at 35,000 ft gave 1.66
for _, case in ipairs({{10000, 0.452, nil, 1.440}, {10000, 0.363, nil, 1.49}, {10000, 0.30, nil, 1.49},
        {10000, 0.363, 28, 1.35}, {10000, 0.452, 18, 1.401}, {15000, 0.4966, nil, 1.453}, {15000, 0.4966, 5.3, 1.425},
        {15000, 0.4966, 25, 1.35}, {41000, 0.75, -41.5, 1.404}, {11500, 0.3733, 32.2, 1.35}, {25000, 0.84, nil, 1.35},
        {35000, 0.81, nil, 1.64, 1.64}}) do
    for _, light in ipairs({true, false}) do
        local got = clb_target("PW", case[1], case[2], 0, light, 0, case[3], case[5])
        check(got and math.abs(got - case[4]) < 0.006, string.format("PW CLB at %d ft, M%.3f, %s C, %s: %s (%.3f)",
            case[1], case[2], tostring(case[3] or "ISA"), light and "light" or "heavy", tostring(got), case[4]))
    end
end
-- the Initial Climb table's 15 C column at 8,000 ft read 1.7 (1.46 at 7,000 ft, 1.47 at 9,000)
do
    local env = setmetatable({}, {__index = _G})
    helpers(env)
    local value = env.INITIAL_CLIMB_epr_PW4056[15][8000]
    check(value >= 1.46 and value <= 1.47, "the Initial Climb table at 15 C and 8,000 ft: "..value)
end
-- CLB 1 and CLB 2: 10 and 20 % off to 10,000 ft, given back by 15,000 ft (at 12,500 ft half of it). The GE's N1 as
-- the 1/3.1 power of the thrust kept, the EEC's N1 model (N1_display_GE: thrust about N1^3.1): to the 0.4 power the
-- thrust was 12-13 and 25-26 % less (review 34 MINOR 2)
local function derated(engine, share)
    if engine == "GE" then return RATING.GE * share ^ (1 / 3.1) end
    return 1 + (RATING[engine] - 1) * share
end
for _, engine in ipairs({"GE", "PW", "RR"}) do
    for _, case in ipairs({{1, 8000, 0.9}, {2, 8000, 0.8}, {1, 12500, 0.95}, {2, 12500, 0.9}, {1, 15000, 1.0},
            {2, 25000, 1.0}}) do
        local derate, altitude, share = case[1], case[2], case[3]
        local mach = SCHEDULE[altitude]
        local got = clb_target(engine, altitude, mach, derate, true)
        local want = derated(engine, share)
        check(got and math.abs(got - want) < 0.006 * (engine == "GE" and 10 or 1), string.format("%s CLB %d at %d "
            .."ft: %s (%.3f)", engine, derate, altitude, tostring(got), want))
    end
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("EEC climb thrust tests passed: "..checks)
