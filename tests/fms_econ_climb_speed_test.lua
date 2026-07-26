local performance = dofile(
    "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.performance.lua")

local tests_run = 0

local function assert_equal(actual, expected, message)
    tests_run = tests_run + 1
    assert(actual == expected, (message or "values differ") .. ": expected "
        .. tostring(expected) .. ", got " .. tostring(actual))
end

local function assert_true(value, message)
    tests_run = tests_run + 1
    assert(value, message)
end

assert_equal(performance.econ_climb_speed_kcas({}), 340,
    "missing PERF INIT data uses the Boeing fallback")

local light_min_fuel = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 250000,
    cost_index = 0,
    cruise_altitude_ft = 35000
})
local heavy_min_fuel = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 380000,
    cost_index = 0,
    cruise_altitude_ft = 35000
})
assert_equal(light_min_fuel, 306, "light-weight CI 0 schedule")
assert_equal(heavy_min_fuel, 318, "heavy-weight CI 0 schedule")
assert_true(heavy_min_fuel > light_min_fuel,
    "ECON climb CAS must increase with gross weight")

local heavy_lrc = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 380000,
    cost_index = 230,
    cruise_altitude_ft = 35000
})
assert_equal(heavy_lrc, 339, "heavy-weight LRC-equivalent schedule")
assert_true(heavy_lrc > heavy_min_fuel,
    "ECON climb CAS must increase with cost index")

local minimum_time = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 300000,
    cost_index = 9999,
    cruise_altitude_ft = 35000
})
assert_equal(minimum_time, 349, "FMC-generated VNAV speed limit")

local zero_wind = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 300000,
    cost_index = 80,
    cruise_altitude_ft = 35000
})
local headwind = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 300000,
    cost_index = 80,
    headwind_kts = 80,
    cruise_altitude_ft = 35000
})
local tailwind = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 300000,
    cost_index = 80,
    headwind_kts = -80,
    cruise_altitude_ft = 35000
})
assert_true(headwind > zero_wind, "headwind must increase ECON climb CAS")
assert_true(tailwind < zero_wind, "tailwind must decrease ECON climb CAS")

local hot_day = performance.econ_climb_speed_kcas({
    top_of_climb_weight_kg = 300000,
    cost_index = 80,
    isa_deviation_c = 30,
    cruise_altitude_ft = 35000
})
assert_true(hot_day < zero_wind,
    "temperature above the flat-rating threshold must reduce ECON climb CAS")

local estimated_toc_weight = performance.estimate_top_of_climb_weight_kg({
    gross_weight_kg = 330000,
    current_altitude_ft = 0,
    cruise_altitude_ft = 35000
})
assert_equal(math.floor(estimated_toc_weight + 0.5), 324000,
    "standard climb burn is included in predicted T/C weight")

assert_equal(performance.parse_cruise_altitude_ft("FL350"), 35000,
    "flight level parsing")
assert_true(performance.mach_to_cas_kts(0.81, 10000)
        > performance.mach_to_cas_kts(0.81, 35000),
    "constant Mach CAS must decrease with altitude")

print("FMS ECON climb-speed tests passed: " .. tests_run)

