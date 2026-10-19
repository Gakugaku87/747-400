-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The CLB thrust reference of the EEC modules (B747.42.xt.EEC.GE/PW/RR.lua) is the rated climb thrust at every
-- altitude and weight, as on the 747-400: the FMC's reference EPR/N1 from pressure altitude and TAT, held by the A/T
-- in THR REF, the climb rate the result (FCOM; cckit research_clb_thrust.md). Below 20,000 ft the modules took the
-- thrust their own drag model gave for a design climb rate (PW4056: 2,750 fpm below 10,000 ft) when that was less:
-- at 231 t the 747 climbed 1,560 fpm at 10,000 ft and 250 kt (the FCOM's max climb thrust gives about 4,000), and
-- in the acceleration to 290 kt there it fell to 30 fpm (p30-line1, 2026-10-19). Upstream e286c7da had made the GE
-- module use max climb above 20,000 ft, and the PW and RR modules followed (a light 747 crept up at 100-360 fpm in
-- the 20s). The PW4056's max climb EPR is tabled for the 340 kt / M.84 climb; slower, the rating is higher (the
-- Initial Climb table at 200 KIAS: 1.50 at 10,000 ft against 1.35): about 0.6 EPR per Mach below the schedule, from
-- 200 KIAS up. CLB 1 and CLB 2 take 10 and 20 % off the climb thrust to 10,000 ft and give it back linearly by
-- 15,000 ft (as an EPR above 1, or N1 to the power 0.4 for thrust about N1^2.5). Each module's CLB branch runs against
-- mocked ratings; this does not validate the engine model.
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
-- the shared helpers of B747.42.xt.EEC.lua from B747_rescale on to round_thrustcalc
local function helpers(env)
    local source = read(EEC.."lua")
    local first = assert(source:find("function B747_rescale(", 1, true))
    local last = assert(source:find("function round_thrustcalc(", first, true))
    setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
end

-- The CLB target bug of one module: altitude ft, Mach, CLB derate (0, 1, 2), a light aircraft (the design climb
-- rate's thrust below the rating) or a heavy one (above it), flaps up or out.
local RATING = {GE = 95.0, PW = 1.35, RR = 1.50}
local function clb_target(engine, altitude, mach, derate, light, flaps)
    local env = setmetatable({B747DR_ref_thr_limit_mode = "CLB", altitude_ft_in = altitude, mach = mach,
        simDR_altitude = altitude, B747DR_clbderate = derate, packs_adjustment_value = 0,
        engine_anti_ice_adjustment_value = 0, simDR_flap_ratio = flaps or 0, takeoff_TOGA_n1 = 100}, {__index = _G})
    helpers(env)
    if engine == "GE" then
        local actual = light and 80.0 or 97.0
        env.in_flight_N1_GE = function() return 0, actual, 0, 0, RATING.GE, 0, 0, 0 end
        env.N1_target_bug, env.display_N1_ref, env.display_N1_max = {}, {}, {}
        env.B747DR_display_N1_max, env.B747DR_display_N1_ref = {[0] = 0, 0, 0, 0}, {[0] = 0, 0, 0, 0}
    else
        local actual = light and 1.20 or 1.60
        env["in_flight_EPR_"..engine] = function() return actual, 1.40, RATING[engine] end
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
-- the PW's rating slower than its schedule: at 10,000 ft, 250 KIAS (M.452) 1.35 + 0.6 x (0.611 - 0.452) = 1.445
-- (the table at 240 KIAS: 1.46); at 200 KIAS (M.363) and slower 1.35 + 0.6 x 0.248 = 1.499 (the Initial Climb
-- table: 1.50); at M.84 at 25,000 ft nothing added
for _, case in ipairs({{10000, 0.452, 1.445}, {10000, 0.363, 1.499}, {10000, 0.30, 1.499}, {25000, 0.84, 1.35}}) do
    for _, light in ipairs({true, false}) do
        local got = clb_target("PW", case[1], case[2], 0, light)
        check(got and math.abs(got - case[3]) < 0.006, string.format("PW CLB at %d ft, M%.3f, %s: %s (%.3f)", case[1],
            case[2], light and "light" or "heavy", tostring(got), case[3]))
    end
end
-- CLB 1 and CLB 2: 10 and 20 % off to 10,000 ft, given back by 15,000 ft (at 12,500 ft half of it)
local function derated(engine, share)
    if engine == "GE" then return RATING.GE * share ^ 0.4 end
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
