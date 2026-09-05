-- Pure 747-400 FMC performance calculations.
--
-- Boeing's FMC performance database is proprietary, but the documented
-- scheduling rules are public:
--   * ECON CLB is a fixed CAS/Mach schedule.
--   * CAS depends on predicted top-of-climb gross weight, cost index,
--     predicted top-of-climb wind and ISA deviation.
--   * CI 0 is the minimum-fuel schedule, CI 230 approximates LRC, and the
--     747-400 VNAV-generated target is limited to 349 KCAS.
--   * With FMC performance data unavailable, use 340 KCAS/.84 Mach.
--
-- The curves below are a simulator approximation, not a Boeing performance
-- database. The data-unavailable 340/.84 schedule and the LRC-equivalent CI
-- do not establish ECON climb calibration points. Current sensed wind and
-- temperature are proxies; engine-specific accuracy still needs validation.

local performance = {}

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function interpolate(start_value, end_value, fraction)
    return start_value + (end_value - start_value) * fraction
end

function performance.parse_cruise_altitude_ft(value)
    if value == nil then return nil end
    local text = tostring(value)
    local flight_level = string.match(text, "^%s*[Ff][Ll](%d+)%s*$")
    if flight_level ~= nil then return tonumber(flight_level) * 100 end
    return tonumber(text)
end

function performance.isa_temperature_c(altitude_ft)
    local altitude = math.max(0, tonumber(altitude_ft) or 0)
    if altitude >= 36089 then return -56.5 end
    return 15.0 - 0.0019812 * altitude
end

function performance.headwind_component_kts(wind_from_deg, wind_speed_kts, heading_deg)
    local direction = tonumber(wind_from_deg)
    local speed = tonumber(wind_speed_kts)
    local heading = tonumber(heading_deg)
    if direction == nil or speed == nil or heading == nil then return 0 end
    return speed * math.cos(math.rad(direction - heading))
end

local function pressure_ratio_at_altitude(altitude_ft)
    local altitude_m = math.max(0, tonumber(altitude_ft) or 0) * 0.3048
    if altitude_m <= 11000 then
        return (1.0 - 2.25577e-5 * altitude_m) ^ 5.25588
    end
    return 0.223361 * math.exp(-(altitude_m - 11000) / 6341.62)
end

function performance.mach_to_cas_kts(mach, altitude_ft)
    local mach_number = tonumber(mach)
    if mach_number == nil or mach_number <= 0 then return nil end
    local pressure_ratio = pressure_ratio_at_altitude(altitude_ft)
    local impact_pressure_ratio =
        pressure_ratio * ((1.0 + 0.2 * mach_number * mach_number) ^ 3.5 - 1.0)
    local cas_mps =
        340.294 * math.sqrt(5.0 * ((impact_pressure_ratio + 1.0) ^ (2.0 / 7.0) - 1.0))
    return cas_mps * 1.94384449
end

function performance.estimate_top_of_climb_weight_kg(input)
    input = input or {}
    local gross_weight = tonumber(input.gross_weight_kg)
    if gross_weight == nil or gross_weight <= 0 then return nil end

    local current_altitude = tonumber(input.current_altitude_ft) or 0
    local cruise_altitude = tonumber(input.cruise_altitude_ft) or current_altitude
    local altitude_remaining = math.max(0, cruise_altitude - current_altitude)
    if altitude_remaining == 0 then return gross_weight end

    -- Simulator fallback estimate, not an engine-specific performance table.
    -- Scale with remaining altitude/weight when trajectory data is unavailable.
    local standard_burn = 6000.0
        * clamp(altitude_remaining / 35000.0, 0, 1.25)
        * (clamp(gross_weight, 180000, 400000) / 330000.0) ^ 0.7
    local predicted_burn = standard_burn

    local fuel_flow = tonumber(input.total_fuel_flow_kg_sec)
    local distance_to_toc = tonumber(input.distance_to_toc_nm)
    local ground_speed = tonumber(input.ground_speed_kts)
    if fuel_flow ~= nil and fuel_flow > 0
        and distance_to_toc ~= nil and distance_to_toc > 0
        and ground_speed ~= nil and ground_speed > 100 then
        local live_burn = fuel_flow * 3600.0 * distance_to_toc / ground_speed
        predicted_burn = clamp(live_burn, standard_burn * 0.5, standard_burn * 1.75)
    end

    predicted_burn = clamp(predicted_burn, 0, math.min(12000, gross_weight * 0.04))
    return gross_weight - predicted_burn
end

function performance.econ_climb_speed_kcas(input)
    input = input or {}
    local weight_kg = tonumber(input.top_of_climb_weight_kg or input.gross_weight_kg)
    local cost_index = tonumber(input.cost_index)
    if weight_kg == nil or weight_kg <= 0 or cost_index == nil then
        return 340
    end

    local weight_tonnes = clamp(weight_kg / 1000.0, 180, 400)
    local ci = clamp(cost_index, 0, 9999)

    -- Heuristic zero-wind schedule. These coefficients have not been
    -- validated against the airplane's FMC performance database.
    local minimum_fuel_speed = 282.0 + 0.095 * weight_tonnes
    local lrc_equivalent_speed = 305.0 + 0.090 * weight_tonnes
    local speed
    if ci <= 230 then
        speed = interpolate(
            minimum_fuel_speed,
            lrc_equivalent_speed,
            (ci / 230.0) ^ 0.45)
    else
        speed = interpolate(
            lrc_equivalent_speed,
            349.0,
            ((ci - 230.0) / (9999.0 - 230.0)) ^ 0.5)
    end

    -- A headwind raises ECON climb CAS; a tailwind lowers it.  The asymmetric
    -- response follows the FMC schedule convention while the clamps prevent a
    -- sensed-wind proxy from overwhelming the base performance schedule.
    local headwind = tonumber(input.headwind_kts) or 0
    if headwind >= 0 then
        speed = speed + math.min(12, headwind * 0.10)
    else
        speed = speed + math.max(-10, headwind * 0.05)
    end

    -- Above the approximate engine flat-rating threshold, a positive ISA
    -- deviation reduces ECON climb CAS.
    local isa_deviation = tonumber(input.isa_deviation_c) or 0
    if isa_deviation > 10 then
        speed = speed - math.min(8, (isa_deviation - 10) * 0.25)
    end

    -- At a low selected cruise altitude, avoid an acceleration at T/C by
    -- raising climb CAS to the CAS equivalent of the ECON cruise Mach.
    local cruise_mach = tonumber(input.cruise_mach)
    local cruise_altitude = tonumber(input.cruise_altitude_ft)
    if cruise_mach ~= nil and cruise_mach >= 0.5 and cruise_mach <= 0.95
        and cruise_altitude ~= nil and cruise_altitude > 0 then
        local cruise_cas = performance.mach_to_cas_kts(cruise_mach, cruise_altitude)
        if cruise_cas ~= nil then speed = math.max(speed, cruise_cas) end
    end

    return math.floor(clamp(speed, 251, 349) + 0.5)
end

return performance
