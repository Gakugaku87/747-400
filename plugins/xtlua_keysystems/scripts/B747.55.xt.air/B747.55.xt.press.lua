-- The pressurization model (B747.55.press_model.lua) in the aircraft: reads
-- the outside pressure, the pressure altitude, the vertical and ground
-- speeds, the air/ground relays, the captain's altimeter setting, the FMC's
-- cruise altitude and route (the field elevations from X-Plane's
-- earth_aptmeta.dat), the CABIN ALTITUDE panel, the buses, the packs' air
-- and X-Plane's decompression failures; writes X-Plane's cabin altitude,
-- rate, differential pressure and outflow valve (the init script takes
-- over X-Plane's pressurization: override_pressurization), the outflow
-- valve gauges, the landing altitude, the ECS data block's display, CABIN
-- ALTITUDE, CABIN ALT AUTO, OUTFLOW VLV L/R, LANDING ALT, PRESS RELIEF and
-- the STATUS CABIN ALT AUTO A/B. B747.55.xt.air.lua loads it after the
-- pack glue.
dofile("B747.55.press_model.lua")
local C = B747_press_model

simDR_press_override            = find_dataref("sim/operation/override/override_pressurization")
simDR_press_cabin_alt_act       = find_dataref("sim/cockpit/pressure/cabin_altitude_actual_ft")
simDR_press_cabin_vvi_act       = find_dataref("sim/cockpit/pressure/cabin_vvi_actual_fpm")
simDR_press_dp_act              = find_dataref("sim/cockpit/pressure/cabin_pressure_differential_psi")
simDR_press_outflow_act         = find_dataref("sim/cockpit/pressure/outflow_valve")
simDR_press_baro_pas            = find_dataref("sim/weather/aircraft/barometer_current_pas")
simDR_press_pressure_alt        = find_dataref("sim/flightmodel2/position/pressure_altitude")
simDR_press_groundspeed         = find_dataref("sim/flightmodel/position/groundspeed")
simDR_press_agl                 = find_dataref("sim/flightmodel/position/y_agl")
simDR_press_baro_setting        = find_dataref("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot")
simDR_press_latitude            = find_dataref("sim/flightmodel/position/latitude")
simDR_press_longitude           = find_dataref("sim/flightmodel/position/longitude")
simDR_press_depres_slow         = find_dataref("sim/operation/failures/rel_depres_slow")
simDR_press_depres_fast         = find_dataref("sim/operation/failures/rel_depres_fast")
B747DR_press_fmc_crz            = find_dataref("laminar/B747/autopilot/dist/cruise_alt")
B747DR_press_fms_data           = find_dataref("laminar/B747/fms/data")     -- the FMC's route, JSON
B747DR_press_bat_main           = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_press_hot_bat_apu        = find_dataref("laminar/B747/electrical/bus/hot_bat_apu")
B747DR_press_mode               = find_dataref("laminar/B747/air/press/mode")
B747DR_press_cpc                = find_dataref("laminar/B747/air/press/cpc")
B747DR_press_relief_open        = find_dataref("laminar/B747/air/press/relief_open")
B747DR_press_cruise_clamp       = find_dataref("laminar/B747/air/press/cruise_clamp")
B747DR_press_valve_man          = find_dataref("laminar/B747/air/press/valve_man")
B747DR_press_status             = find_dataref("laminar/B747/CAS/status_status")
B747DR_press_pseu_alt_gnd       = find_dataref("laminar/B747/gear/air_ground/alt_gnd")

local SW_MAN = 34                   -- button_switch/position[34], [35]: MAN L, R
local TOGGLE_OPEN_CLOSE = 22        -- toggle_switch/position[22]: OPEN +1, CLOSE -1
-- EICAS slots (B747.87.xt.warning.lua)
local WARN_CABIN_ALT, CAUT_CABIN_AUTO = 1, 10
local ADV_LANDING_ALT, ADV_OUTFLOW, ADV_PRESS_RELIEF = 240, 249, 258    -- OUTFLOW VLV L, R: 249, 250
local STATUS_CABIN_AUTO = 29        -- STATUS CABIN ALT AUTO A, B: 29, 30
local STATUS_OUTFLOW = 31           -- OUTFLOW VLV L, R: 31, 32
local STATUS_RELIEF = 33            -- UPR, LWR PRESS RELIEF: 33, 34
local STATUS_AIR_GND = 35           -- CPCS AIR/GND
local KT_PER_MS = 1.943844
local SYN_ENG, SYN_ECS = 1, 5       -- dsp/synoptic_display

-- X-Plane's airport list: field elevation (ft) and position
local APTMETA = B747_AIR_APTMETA or {"Custom Data/earth_aptmeta.dat", "Resources/default data/earth_aptmeta.dat"}
local airports = {}                 -- ICAO -> {lat, lon, elev}, or false when not found

local function airport(icao)
    if icao == nil or #icao < 3 then return nil end
    local a = airports[icao]
    if a ~= nil then return a or nil end
    airports[icao] = false
    for _, path in ipairs(APTMETA) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                if line:sub(1, 6):find(icao, 1, true) then
                    local id, lat, lon, elev = line:match("^%s*(%S+)%s+%S+%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?%d+)")
                    if id == icao then
                        airports[icao] = {lat = tonumber(lat), lon = tonumber(lon), elev = tonumber(elev)}
                        break
                    end
                end
            end
            f:close()
            if airports[icao] then break end
        end
    end
    return airports[icao] or nil
end

local function nm(lat1, lon1, lat2, lon2)
    local r = math.pi / 180
    local a = math.sin((lat2 - lat1) * r / 2) ^ 2
        + math.cos(lat1 * r) * math.cos(lat2 * r) * math.sin((lon2 - lon1) * r / 2) ^ 2
    return 2 * 3440.065 * math.asin(math.min(1, math.sqrt(a)))
end

local press_state = C.new()
local press_inputs = C.inputs()
-- for the equipment cooling glue (ΔP): kept as the table itself (a
-- metatable; B747.55.xt.packs.lua)
B747_press_out = setmetatable(press_state.out, {})
local fms_str, fms_dep, fms_dest = nil, nil, nil
local knob_last = nil

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

-- the departure and destination from the FMC's route (fltdep, fltdst)
local function read_fms()
    local str = B747DR_press_fms_data
    if str == fms_str then return end
    fms_str = str
    fms_dep = airport(str:match('"fltdep"%s*:%s*"(%w+)"'))
    fms_dest = airport(str:match('"fltdst"%s*:%s*"(%w+)"'))
end

function B747_press_flight_start()
    press_state = C.new()
    B747_press_out = setmetatable(press_state.out, {})
    knob_last = nil
end

function B747_press()
    local inp = press_inputs
    inp.p_amb = simDR_press_baro_pas / 6894.757
    inp.alt = simDR_press_pressure_alt
    inp.vs = simDR_indicated_vvi_fpm_pilot
    inp.gs_kt = simDR_press_groundspeed * KT_PER_MS
    inp.on_ground = B747DR_pack_pseu_pri_gnd == 1
    inp.agl_ft = simDR_press_agl * 3.28084
    inp.baro_inhg = simDR_press_baro_setting

    -- the FMC
    read_fms()
    if B747DR_press_fmc_crz > 0 then inp.fmc_crz_ft = B747DR_press_fmc_crz else inp.fmc_crz_ft = nil end
    local lat, lon = simDR_press_latitude, simDR_press_longitude
    inp.fmc_dep_ft, inp.fmc_dest_ft = nil, nil
    if fms_dep then
        inp.fmc_dep_ft = fms_dep.elev
        inp.from_dep_nm = nm(fms_dep.lat, fms_dep.lon, lat, lon)
    end
    if fms_dest then
        inp.fmc_dest_ft = fms_dest.elev
        inp.to_dest_nm = nm(lat, lon, fms_dest.lat, fms_dest.lon)
    end

    -- CABIN ALTITUDE panel. The LDG ALT knob turns 1 degree for each step
    -- of its dataref; a step is 50 ft. It is moved back by whole turns
    -- before it reaches the ends of its range, so it looks the same.
    inp.ldg_auto = B747DR_landing_alt_button_pos > 0.5
    local rheo = B747DR_landing_alt_sel_rheo
    if knob_last == nil then knob_last = rheo end
    local d = rheo - knob_last
    local steps = (d >= 0) and math.floor(d) or math.ceil(d)
    knob_last = knob_last + steps
    inp.ldg_steps = steps
    if rheo < 720 then
        B747DR_landing_alt_sel_rheo = rheo + 1800
        knob_last = knob_last + 1800
    elseif rheo > 4280 then
        B747DR_landing_alt_sel_rheo = rheo - 1800
        knob_last = knob_last - 1800
    end
    inp.auto_select = math.floor(B747DR_cabin_alt_auto_sel_pos + 0.5)
    inp.man[1] = B747DR_button_switch_position[SW_MAN] > 0.5
    inp.man[2] = B747DR_button_switch_position[SW_MAN + 1] > 0.5
    local oc = B747DR_toggle_switch_position[TOGGLE_OPEN_CLOSE]
    inp.man_cmd = (oc > 0.5 and 1) or (oc < -0.5 and -1) or 0

    -- power (ATA21 p.437, p.449)
    inp.dc[1] = B747DR_bleed_elec_dc[0] > 0.5
    inp.dc[2] = B747DR_bleed_elec_dc[1] > 0.5
    inp.any_ac = B747DR_pack_elec_any_ac > 0.5
    inp.bat = B747DR_press_bat_main > 0.5
    inp.apu_hot_bat = B747DR_press_hot_bat_apu > 0.5

    -- air
    local flow, selected = 0, 0
    for p = 1, 3 do
        flow = flow + B747_pack_out.flow[p]
        if B747DR_pack_ctrl_sel_pos[p - 1] > 0.5 then selected = selected + 1 end
    end
    inp.pack_flow, inp.packs_selected = flow, selected
    inp.extra_out_kg_s = B747_eqcool_overboard_kg_s or 0    -- equipment cooling OVRD (last frame)
    inp.depres_slow = simDR_press_depres_slow == 6
    inp.depres_fast = simDR_press_depres_fast == 6

    local out = C.update(press_state, inp, SIM_PERIOD)
    B747_pack_relief_open = out.relief_open
    B747_pack_cruise_clamp = out.cruise_clamp

    -- X-Plane's cabin (computed into locals first: XTLua passes on only a
    -- value that differs from the one it holds, TESTING.md §1.2)
    if simDR_press_override ~= 1 then simDR_press_override = 1 end
    local cabin_ft, rate, dp, valve = out.cabin_ft, out.rate_fpm, out.dp, (out.valve[1] + out.valve[2]) / 2
    simDR_press_cabin_alt_act = cabin_ft
    simDR_press_cabin_vvi_act = rate
    simDR_press_dp_act = dp
    simDR_press_outflow_act = valve
    -- the gauges: -1 closed, +1 open
    B747DR_outflow_valve_pos_L = 2 * out.valve[1] - 1
    B747DR_outflow_valve_pos_R = 2 * out.valve[2] - 1
    local ldg = out.ldg_ft
    if B747DR_landing_altitude ~= ldg then B747DR_landing_altitude = ldg end
    local mode, cpc = out.mode, out.active
    if B747DR_press_mode ~= mode then B747DR_press_mode = mode end
    if B747DR_press_cpc ~= cpc then B747DR_press_cpc = cpc end
    local relief, clamp = flag(out.relief_open), flag(out.cruise_clamp)
    if B747DR_press_relief_open ~= relief then B747DR_press_relief_open = relief end
    if B747DR_press_cruise_clamp ~= clamp then B747DR_press_cruise_clamp = clamp end
    put(B747DR_press_valve_man, 0, flag(press_state.man_on[1]))
    put(B747DR_press_valve_man, 1, flag(press_state.man_on[2]))

    -- messages (FCOM p.619-620; ATA21 p.454)
    put(B747DR_CAS_warning_status, WARN_CABIN_ALT, flag(out.cabin_alert))
    put(B747DR_CAS_caution_status, CAUT_CABIN_AUTO, flag(out.auto_alert))
    put(B747DR_CAS_advisory_status, ADV_OUTFLOW, flag(out.outflow_alert[1]))
    put(B747DR_CAS_advisory_status, ADV_OUTFLOW + 1, flag(out.outflow_alert[2]))
    put(B747DR_CAS_advisory_status, ADV_LANDING_ALT, flag(out.ldg_alert))
    put(B747DR_CAS_advisory_status, ADV_PRESS_RELIEF, flag(out.relief_alert))
    put(B747DR_press_status, STATUS_CABIN_AUTO, flag(out.cpc_alert[1]))
    put(B747DR_press_status, STATUS_CABIN_AUTO + 1, flag(out.cpc_alert[2]))
    put(B747DR_press_status, STATUS_OUTFLOW, flag(out.outflow_alert[1]))
    put(B747DR_press_status, STATUS_OUTFLOW + 1, flag(out.outflow_alert[2]))
    put(B747DR_press_status, STATUS_RELIEF, flag(out.relief_open))         -- both valves open
    put(B747DR_press_status, STATUS_RELIEF + 1, flag(out.relief_open))     -- together (estimate)
    put(B747DR_press_status, STATUS_AIR_GND, flag(B747DR_pack_pseu_pri_gnd ~= B747DR_press_pseu_alt_gnd))

    -- the ECS data block on the primary EICAS: LDG ALT MAN, the cabin
    -- altitude or ΔP amber or red, the ECS or ENG synoptic (FCOM p.585);
    -- also CABIN ALT AUTO, OUTFLOW VLV, LANDING ALT, a duct below 11 psi,
    -- and the cabin climbing above 700 or descending above 500 fpm (ATA21
    -- p.451)
    local show = not inp.ldg_auto or cabin_ft >= 8500 or dp >= 8.85 or dp <= -0.45
        or B747DR_dsp_synoptic_display == SYN_ECS or B747DR_dsp_synoptic_display == SYN_ENG
        or out.auto_alert or out.outflow_alert[1] or out.outflow_alert[2] or out.ldg_alert
        or B747_duct_pressure_L < 11 or B747_duct_pressure_R < 11
        or rate > 700 or rate < -500
    local s = flag(show)
    if B747DR_pressure_EICAS1_display_status ~= s then B747DR_pressure_EICAS1_display_status = s end
end
