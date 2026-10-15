-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The CLB thrust reference of the EEC modules (B747.42.xt.EEC.GE/PW/RR.lua):
-- the climb target is the thrust the EEC computes for its design climb rate
-- at the aircraft's weight (N1_actual / EPR_actual), or max climb when that is
-- more. Upstream e286c7da ("fix GE climb thrust", 2022-12-26) made the GE
-- module use max climb above 20,000 ft as well; the PW and RR modules kept the
-- weight-based target there. With PW4056 engines at 232 t the 747 climbed at
-- 100-360 fpm at FL265-285 on the first SimBrief line flight (2026-10-10,
-- throttle 0.47) and needed 45 minutes to FL285. Each module's CLB branch runs
-- against mocked values; this does not validate the engine model.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC."

local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local function clb_branch(engine)
    local file = assert(io.open(EEC..engine..".lua"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find('elseif string.match(B747DR_ref_thr_limit_mode, "CLB") then', 1, true))
    local last = assert(source:find('elseif string.match(B747DR_ref_thr_limit_mode, "CRZ") then', first, true))
    return "if false then\n"..source:sub(first, last - 1).."end\n"
end

-- The CLB target bug of one module at an altitude, with the weight-based
-- target below max climb (a light aircraft) or above it (a heavy one).
local function clb_target(engine, altitude, light)
    local env = setmetatable({B747DR_ref_thr_limit_mode = "CLB", altitude_ft_in = altitude,
        packs_adjustment_value = 0, engine_anti_ice_adjustment_value = 0,
        simDR_flap_ratio = 0, takeoff_TOGA_n1 = 100}, {__index = _G})
    if engine == "GE" then
        local actual, max_climb = light and 80.0 or 97.0, 95.0
        env.in_flight_N1_GE = function() return 0, actual, 0, 0, max_climb, 0, 0, 0 end
        env.N1_target_bug, env.display_N1_ref, env.display_N1_max = {}, {}, {}
        env.B747DR_display_N1_max, env.B747DR_display_N1_ref = {[0] = 0, 0, 0, 0}, {[0] = 0, 0, 0, 0}
    else
        local actual, initial, max_climb = light and 1.20 or 1.55, 1.40, 1.50
        env["in_flight_EPR_"..engine] = function() return actual, initial, max_climb end
        env.EPR_target_bug, env.display_EPR_ref, env.display_EPR_max = {}, {}, {}
        env.B747DR_display_EPR_max, env.B747DR_display_EPR_ref = {[0] = 0, 0, 0, 0}, {[0] = 0, 0, 0, 0}
    end
    setfenv(assert(loadstring(clb_branch(engine))), env)()
    return tonumber(engine == "GE" and env.N1_target_bug[0] or env.EPR_target_bug[0])
end

-- Above 20,000 ft every module climbs at max climb; below it a light aircraft
-- keeps the weight-based target, and a heavy one is held at max climb (or the
-- initial climb EPR when that is more).
for _, case in ipairs({{"GE", 80.0, 95.0, 95.0}, {"PW", 1.20, 1.50, 1.50}, {"RR", 1.20, 1.50, 1.50}}) do
    local engine, light_below, light_above, heavy = case[1], case[2], case[3], case[4]
    local got = clb_target(engine, 15000, true)
    check(math.abs(got - light_below) < 1e-6, string.format("%s CLB, light, FL150: %.2f (the weight-based %.2f)",
        engine, got, light_below))
    got = clb_target(engine, 25000, true)
    check(math.abs(got - light_above) < 1e-6, string.format("%s CLB, light, FL250: %.2f (max climb %.2f)",
        engine, got, light_above))
    got = clb_target(engine, 15000, false)
    check(math.abs(got - heavy) < 1e-6, string.format("%s CLB, heavy, FL150: %.2f (max climb %.2f)", engine, got, heavy))
end

print("EEC climb thrust tests passed: "..checks)
