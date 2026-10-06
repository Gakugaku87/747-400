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

-- ECON CLB is a CAS/Mach pair.  FCTM: the constant Mach of the ECON climb
-- is the economy cruise Mach calculated for the cruise altitude, at the
-- top-of-climb weight - the same schedule the cruise speed state flies.
assert_equal(performance.econ_climb_mach({}), 0.840,
    "missing PERF INIT data uses the 340/.84 fallback pair")
local function cruise_mach(cost_index, headwind_kts)
    return performance.econ_cruise_mach_thousandths({
        gross_weight_kg = 300000,
        altitude_ft = 35000,
        cost_index = cost_index,
        headwind_kts = headwind_kts
    })
end
assert_equal(cruise_mach(0), 827, "CI 0 cruise Mach is MRC (LRC - .020)")
assert_equal(cruise_mach(115), 837, "CI 115 blends MRC towards LRC")
assert_equal(cruise_mach(230), 847, "CI 230 cruise Mach is LRC")
assert_equal(cruise_mach(9999), 900, "CI 9999 cruise Mach is Mmo - .02")
assert_equal(cruise_mach(115, 50), 847, "a 50 kt headwind adds .010")
assert_equal(cruise_mach(115, -50), 827,
    "a 50 kt tailwind subtracts .020, floored at MRC")
assert_equal(performance.econ_cruise_mach_thousandths({
    gross_weight_kg = 350000, altitude_ft = 31000, cost_index = 100}), 836,
    "typical heavy cruise: CI 100 at 350 t/FL310")
assert_equal(performance.econ_cruise_mach({cost_index = 100}), nil,
    "no weight or altitude: no ECON cruise Mach")

local function climb_mach(cost_index, cruise_altitude_ft, headwind_kts)
    return performance.econ_climb_mach({
        top_of_climb_weight_kg = 300000,
        cruise_altitude_ft = cruise_altitude_ft or 35000,
        cost_index = cost_index,
        headwind_kts = headwind_kts
    })
end
assert_equal(climb_mach(0), 0.827, "CI 0 climb Mach")
assert_equal(climb_mach(115), 0.837, "CI 115 climb Mach")
assert_equal(climb_mach(230), 0.847, "LRC-equivalent climb Mach")
assert_equal(climb_mach(9999), 0.900, "minimum-time climb Mach")
assert_true(climb_mach(230) > climb_mach(0),
    "climb Mach must increase with cost index")
for _, cost_index in ipairs({0, 80, 230, 500, 9999}) do
    assert_equal(climb_mach(cost_index), cruise_mach(cost_index) / 1000,
        "climb Mach equals the ECON cruise Mach for the cruise altitude, CI "
        .. cost_index)
end
assert_equal(climb_mach(115, 29000), 0.790,
    "a lower cruise altitude lowers the climb Mach")
assert_equal(climb_mach(115, 15000), performance.econ_cruise_mach_thousandths({
    gross_weight_kg = 300000, altitude_ft = 15000, cost_index = 115}) / 1000,
    "climb and cruise Mach agree at a low cruise altitude too")

-- The ECON wind input follows the sensed headwind through a 60 s lag.
assert_equal(performance.smoothed_headwind_kts(nil, 40, nil), 40,
    "the first sample starts the lag")
assert_equal(performance.smoothed_headwind_kts(0, 60, 30), 30,
    "half the time constant moves half way")
assert_equal(performance.smoothed_headwind_kts(0, 60, 600), 60,
    "a long gap takes the new sample")
assert_equal(performance.smoothed_headwind_kts(20, -50, -5), -50,
    "time running backwards restarts the lag")
assert_equal(performance.smoothed_headwind_kts(20, -50, 0), 20,
    "no elapsed time holds the lagged value")
assert_equal(climb_mach(115, 35000, 50), 0.847,
    "a predicted headwind raises the climb Mach")
assert_equal(performance.econ_climb_mach({cost_index = 115}), 0.840,
    "no weight or altitude: fallback climb Mach")

assert_equal(performance.parse_cruise_altitude_ft("FL350"), 35000,
    "flight level parsing")
assert_true(performance.mach_to_cas_kts(0.81, 10000)
        > performance.mach_to_cas_kts(0.81, 35000),
    "constant Mach CAS must decrease with altitude")

print("FMS ECON climb-speed tests passed: " .. tests_run)

