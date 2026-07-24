-- Pure AFDS calculations shared by the autopilot implementation and tests.
-- Keep this file compatible with the Lua 5.1 runtime embedded in xtlua.

local afds = {}

local KNOT_TO_MPS = 0.514444
local METERS_PER_NM = 1852.0
local GRAVITY_MPS2 = 9.80665

function afds.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if type(speed_kts) ~= "number" or speed_kts <= 0 then return nil end
    if type(bank_angle_deg) ~= "number" or bank_angle_deg <= 0 or bank_angle_deg >= 89 then return nil end

    local speed_mps = speed_kts * KNOT_TO_MPS
    local radius_m = (speed_mps * speed_mps) / (GRAVITY_MPS2 * math.tan(math.rad(bank_angle_deg)))
    if radius_m <= 0 or radius_m ~= radius_m then return nil end
    return radius_m / METERS_PER_NM
end

function afds.turn_anticipation_nm(speed_kts, bank_angle_deg, turn_angle_deg, minimum_nm, maximum_nm)
    if type(turn_angle_deg) ~= "number" or turn_angle_deg < 0 or turn_angle_deg > 180 then return nil, nil end

    local radius_nm = afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if radius_nm == nil then return nil, nil end
    if turn_angle_deg <= 1 then return 0, radius_nm end
    if turn_angle_deg >= 175 then return nil, radius_nm end

    local anticipation_nm = radius_nm * math.tan(math.rad(turn_angle_deg * 0.5))
    if anticipation_nm ~= anticipation_nm or anticipation_nm < 0 then return nil, radius_nm end
    return afds.clamp(anticipation_nm, minimum_nm or 0, maximum_nm or anticipation_nm), radius_nm
end

function afds.signed_cross_track_nm(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon,
        aircraft_lat, aircraft_lon, distance_func, heading_func)
    if type(distance_func) ~= "function" or type(heading_func) ~= "function" then return nil end
    if type(leg_start_lat) ~= "number" or type(leg_start_lon) ~= "number"
        or type(leg_end_lat) ~= "number" or type(leg_end_lon) ~= "number"
        or type(aircraft_lat) ~= "number" or type(aircraft_lon) ~= "number" then
        return nil
    end

    local distance_nm = distance_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    local leg_heading = heading_func(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon)
    local aircraft_heading = heading_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    if type(distance_nm) ~= "number" or type(leg_heading) ~= "number" or type(aircraft_heading) ~= "number" then
        return nil
    end

    local earth_radius_nm = 3440.065
    local angular_distance = distance_nm / earth_radius_nm
    local cross_track = math.asin(math.sin(angular_distance)
        * math.sin(math.rad(aircraft_heading - leg_heading))) * earth_radius_nm
    if cross_track ~= cross_track then return nil end
    return cross_track
end

function afds.flap_speed_bucket(flap_ratio)
    if type(flap_ratio) ~= "number" or flap_ratio <= 0 then return 0 end
    if flap_ratio <= 0.168 then return 1 end
    if flap_ratio <= 0.34 then return 5 end
    if flap_ratio <= 0.5 then return 10 end
    if flap_ratio <= 0.668 then return 20 end
    if flap_ratio <= 0.84 then return 25 end
    return 30
end

function afds.climb_speed_key_for_state(state)
    if state == "aptres" then return "clbrestspd" end
    if state == "spcres" then return "transpd" end
    if state == "nores" then return "clbspd" end
    return nil
end

function afds.climb_speed_for_state(state, data_source)
    local key = afds.climb_speed_key_for_state(state)
    if key == nil then return nil end
    if type(data_source) == "function" then return tonumber(data_source(key)) end
    if type(data_source) == "table" then return tonumber(data_source[key]) end
    return nil
end

function afds.first_changed_value(previous, current, watched_values)
    if previous == nil or current == nil then return nil end
    for i = 1, #watched_values do
        local item = watched_values[i]
        if previous[item.key] ~= current[item.key] then
            return item.reason or item.key
        end
    end
    return nil
end

function afds.vnav_speed_change_reason(previous, current, conditions, watched_values)
    if previous == nil or current == nil then return nil end

    if conditions ~= nil and type(conditions.above) == "number" and conditions.above > 0
        and previous.pressure_alt_ft <= conditions.above and current.pressure_alt_ft > conditions.above then
        return conditions.above_reason or "crossed upper speed boundary"
    end
    if conditions ~= nil and type(conditions.below) == "number" and conditions.below > 0
        and previous.pressure_alt_ft >= conditions.below and current.pressure_alt_ft < conditions.below then
        return conditions.below_reason or "crossed lower speed boundary"
    end

    return afds.first_changed_value(previous, current, watched_values)
end

function afds.should_schedule_ias_update(timer_is_scheduled)
    return timer_is_scheduled ~= true
end

return afds
