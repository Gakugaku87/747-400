-- Departure reference shared by VNAV acceleration and thrust reduction.
-- Boeing 747-400 FCOM 4.20.9: record barometric altitude passing 100 KIAS;
-- VNAV captures the current airspeed on activation. TO/GA's own pitch and
-- engine-out speed schedules remain with the existing TO/GA controller.
local takeoff = {}

function takeoff.new()
    return {acceleration_complete=false, thrust_reduction_complete=false,
        vnav_active=false}
end

-- Express an indicated altitude using the takeoff altimeter setting. This
-- tropospheric altimeter relation keeps a QNH/STD knob change from looking
-- like a climb through an acceleration or thrust-reduction height.
function takeoff.reference_altitude(altitude, setting, reference_setting)
    if setting == nil or reference_setting == nil
        or setting == reference_setting
        or setting <= 0 or reference_setting <= 0 then return altitude end
    return 145442.16 - (145442.16 - altitude)
        * (setting / reference_setting) ^ 0.190263
end

function takeoff.height(state, altitude, setting)
    if state.reference_altitude_ft == nil then return nil end
    return takeoff.reference_altitude(altitude, setting, state.reference_setting)
        - state.reference_altitude_ft
end

function takeoff.update(state, input)
    local on_ground = input.on_ground == true
    local ias = tonumber(input.ias_kts) or 0
    local altitude = tonumber(input.altitude_ft)
    local setting = tonumber(input.baro_inhg)
    local active = input.vnav_active == true and not on_ground

    -- Rearm after a rejected takeoff or landing, not a high-speed gear bounce.
    if on_ground and ias < 80 then
        state.reference_altitude_ft = nil
        state.reference_setting = nil
        state.acceleration_complete = false
        state.thrust_reduction_complete = false
        state.vnav_speed_kts = nil
        state.vnav_active = false
    end
    if on_ground and altitude ~= nil then
        state.last_ground_altitude_ft = altitude
        state.last_ground_setting = setting
        if ias >= 100 and state.reference_altitude_ft == nil then
            state.reference_altitude_ft = altitude
            state.reference_setting = setting
        end
    elseif not on_ground and altitude ~= nil then
        if state.reference_altitude_ft == nil then
            if state.last_ground_altitude_ft ~= nil then
                -- Handles a missed sample at 100 KIAS; use the last ground
                -- observation, never the terrain below the airborne aircraft.
                state.reference_altitude_ft = state.last_ground_altitude_ft
                state.reference_setting = state.last_ground_setting
            else
                -- An airborne reload cannot reconstruct the departure datum.
                -- Do not re-enter the takeoff speed band from current RA.
                state.acceleration_complete = true
                state.thrust_reduction_complete = true
            end
        end
        local height = takeoff.height(state, altitude, setting)
        if height ~= nil then
            if height >= (tonumber(input.accel_height_ft) or 1500) then
                state.acceleration_complete = true
            end
            if height >= (tonumber(input.thrust_height_ft) or 1000) then
                state.thrust_reduction_complete = true
            end
        end
        if active and not state.vnav_active and not state.acceleration_complete then
            local v2 = tonumber(input.v2_kts) or 0
            if v2 > 0 and v2 < 900 then
                state.vnav_speed_kts = math.max(v2, ias)
            end
        end
    end
    state.vnav_active = active
    return state
end

return takeoff
