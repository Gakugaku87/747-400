-- A closed-loop longitudinal model of the 747's final descent and ILS approach for the tests (not a test itself:
-- the suites load it with dofile from the repository root).
--
-- Production code, each script in its own namespace as XTLua runs it (its own globals, X-Plane's datarefs
-- shared):
--   the autopilot: VNAV_modeSwitch, VNAV_DES, VNAV_DES_ALT, VNAV_NEXT_ALT, B747_monitor_THR_REF_AT
--   (B747.70.xt.autopilot.monitor.lua), setDescentVSpeed and the VNAV energy mode (B747.70.xt.autopilot.vnav.lua,
--   through the XTLua dofile), setDistances, B747_ap_fma, fma_PitchModes, glideSlopeLOCProgress and the helpers
--   (B747.70.xt.autopilot.lua);
--   the hydraulics: the AFDS pitch director and its 10-sample integral (ap_director_pitch,
--   ap_director_pitch_integral: B747.19.xt.hydraulics_override.lua);
--   the EEC: the A/T's speed and idle throttle (ecc_throttle, spd_throttle: B747.42.xt.EEC.lua).
-- Replicas of what the aircraft's other code does each frame: LNAV's sequencing with the P5 turn anticipation and
-- the fix held for its turn (vnav_hold_index), the IAS window (B747_ap_ias_mach_mode) and VNAV's speed with it
-- shut (B747_vnav_speed), the altitude capture window (B747_ap_altitude), the APP arming, the G/S capture
-- (B747_updateApproachHeading with afds.gs_capture_ready), the V/S and FLCH commands (the manipulators' handlers),
-- B747DR_airspeed_Vmc (setVmc).
-- The kit's approach procedure (fullflight.py phase_approach, every 0.2 s): flaps by the route distance one detent
-- at a time inside the placard - 3 kt, slowing from flap_slow_lead_nm before a detent is due (flap_speed_action:
-- the IAS knob pushed in VNAV with the window shut, then the MCP to the placard - 10), gear at gear_down_nm or the
-- G/S capture, APP at app_nm (direct distance), the LOC captured loc_delay_s later (as flown), after the G/S
-- capture with landing flaps the MCP to an at or above speed ahead (AM622 +160) until its fix, then VREF + 5.
-- The aircraft: a point mass, lift and drag by flap ratio and gear fitted to the kit's recordings
-- (dev/cckit/p8/fit_aero.py, 5 flights), thrust per engine 7.9 kN + 154.8 kN x throttle with a 2.5 s spool lag,
-- the attitude following the flight director's pitch (1.5 s, at most 3 deg/s), the VSI 1 s behind, the flaps
-- 5 s per detent and the gear 10 s to travel; the route's legs flown as straight lines from fix to fix, with the
-- wind's component along them (o.wind by altitude: TST744L's westerly for EINN, EHAM's flights were calm).
-- The ILS G/S of gs_deg from 300 m past the threshold with its false lobes: the needle 0.30 deg per dot,
-- + above, reversing through 2 x and 3 x gs_deg as X-Plane 12 drew EHAM 18R's, at most 2.5 dots.
local M = {}

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/"
M.AP, M.HYD, M.EEC = AP, HYD, EEC

local sources = {}
local function read_source(path)
    if sources[path] == nil then
        local file = assert(io.open(path))
        sources[path] = file:read("*a")
        file:close()
    end
    return sources[path]
end
-- Text replacements in the production code for an experiment: {file name, old text, new text}, the old text
-- found once (plain) in the part loaded.
local active_patches = {}
local function patched(code, path)
    for _, patch in ipairs(active_patches) do
        if path:sub(-#patch[1]) == patch[1] then
            local first, last = code:find(patch[2], 1, true)
            if first then
                code = code:sub(1, first - 1)..patch[3]..code:sub(last + 1)
                patch.applied = true
            end
        end
    end
    return code
end
-- A production file's source from first_marker up to last_marker, with the lines before it as empty lines so
-- that errors give the file's line numbers.
local function slice(path, first_marker, last_marker)
    local source = read_source(path)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return patched(string.rep("\n", lines)..source:sub(first, last - 1), path), "@"..path
end
local function run_in(namespace, code, name)
    setfenv(assert(loadstring(code, name)), namespace)()
end

local G, KT, FT, NM, S = 9.80665, 0.514444, 0.3048, 1852, 541.2
M.KT, M.FT, M.NM = KT, FT, NM
-- lift (CL0, CL per deg of alpha) and drag (CD0, k: CD = CD0 + k CL^2) by flap detent, gear up; flaps 25 and 30
-- (fitted gear down) less the gear's 0.05 (flaps 20: 0.0586 up, 0.1135 down)
local POLAR = {
    {0.226, 0.0622, 0.0227, 0.0667},   -- up
    {0.248, 0.0589, 0.0147, 0.0995},   -- 1
    {0.344, 0.0712, 0.0256, 0.0804},   -- 5
    {0.546, 0.0708, 0.0360, 0.0757},   -- 10
    {0.792, 0.0710, 0.0586, 0.0600},   -- 20
    {0.841, 0.0617, 0.0438, 0.0474},   -- 25
    {0.896, 0.0666, 0.0511, 0.0519}}   -- 30
local GEAR_CD0 = 0.05
M.FLAP_DETENTS = {0, 1, 5, 10, 20, 25, 30}
M.FLAP_PLACARD = {[1] = 280, [5] = 260, [10] = 240, [20] = 230, [25] = 205, [30] = 180}

local function polar(ratio)
    local x = math.max(0, math.min(6, ratio * 6))
    local i = math.min(5, math.floor(x))
    local f = x - i
    local a, b = POLAR[i + 1], POLAR[i + 2]
    local out = {}
    for k = 1, 4 do out[k] = a[k] + (b[k] - a[k]) * f end
    return out
end
M.polar = polar

local function density(alt_ft)
    local t = 288.15 - 0.0019812 * alt_ft
    return 1.225 * (t / 288.15) ^ 4.2559
end

-- The flap angle (deg) of a flap ratio.
local function flap_deg(ratio)
    local x = math.max(0, math.min(6, ratio * 6))
    local i = math.min(5, math.floor(x))
    return M.FLAP_DETENTS[i + 1] + (M.FLAP_DETENTS[i + 2] - M.FLAP_DETENTS[i + 1]) * (x - i)
end

local function rescale(in1, out1, in2, out2, x)
    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)
end

-- B747DR_airspeed_Vmc as setVmc (B747.60.xt.fltInst02.lua) gives it.
function M.vmc(weight_kg, flaps_deg)
    local weight_factor = rescale(179000, 0, 396000, 61, weight_kg)
    if flaps_deg < 1 then return rescale(0, 179, 1, 166, flaps_deg) + weight_factor end
    if flaps_deg < 10 then return rescale(1, 166, 10, 137, flaps_deg) + weight_factor end
    return rescale(10, 137, 30, 118, flaps_deg) + weight_factor
end

-- The ILS needle (dots, + above the glide slope) at an elevation angle from the glide path origin.
function M.gs_dots(elevation_deg, angle_deg)
    local dots = (angle_deg / math.pi) * math.sin(math.pi * (elevation_deg - angle_deg) / angle_deg) / 0.30
    return math.max(-2.5, math.min(2.5, dots))
end

-- X-Plane's datarefs (and commands) are shared by the scripts; every other global is the script's own.
local function is_dataref(key)
    return type(key) == "string" and (key:find("^simDR") ~= nil or key:find("^simCMD") ~= nil
        or key:find("^B74[47]DR") ~= nil or key:find("^B747BR") ~= nil or key == "SIM_PERIOD")
end
local function namespace(datarefs, globals)
    local ns = {}
    for key, value in pairs(globals) do rawset(ns, key, value) end
    return setmetatable(ns, {
        __index = function(_, key)
            if is_dataref(key) then return datarefs[key] end
            return _G[key]
        end,
        __newindex = function(t, key, value)
            if is_dataref(key) then datarefs[key] = value else rawset(t, key, value) end
        end})
end

-- The production scripts. Returns the autopilot's, the hydraulics' and the EEC's namespaces and the helpers.
local function load_production(datarefs, stubs)
    local runtime = setmetatable({}, {__index = _G})
    local init = assert(loadfile("plugins/xtlua_keysystems/init.lua"))
    setfenv(init, runtime)
    init()
    runtime.XLuaGetCode = function(requested_path)
        local resolved_path = requested_path
        if not string.find(requested_path, "/", 1, true) then resolved_path = AP..requested_path end
        return assert(loadstring(patched(read_source(resolved_path), resolved_path), "@"..resolved_path))
    end
    local afds = runtime.XLuaGetCode(AP.."B747.70.xt.autopilot.afds_helpers.lua")()
    local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
    local json = dofile(AP.."json/json.lua")
    local noop = function() end

    -- the autopilot (its monitor and VNAV modules share its namespace); B747_afds_helpers is a local of the file
    local ap_globals = {print = noop, json = json, B747_afds_helpers = afds, apWasOn = 1,
        run_after_time = noop, fma_rollModes = noop, runAutoland = function() return false end,
        B747_ap_all_cmd_modes_off = noop, B747_takeoff_thrust_reduction_reached = function() return true end,
        toderate = 0, clbderate = 0, B744_fpm = 0}
    for key, value in pairs(stubs) do ap_globals[key] = value end
    local ap = namespace(datarefs, ap_globals)
    rawset(ap, "dofile", runtime.get_run_file_in_namespace(ap))
    ap.dofile(AP.."B747.70.xt.autopilot.vnav.lua")
    for _, part in ipairs({
            {AP.."B747.70.xt.autopilot.lua", "function B747_rescale(", "function getTriSpaceSolver("},
            {AP.."B747.70.xt.autopilot.lua", "local beganDescentAny = false", "--*****"},
            {AP.."B747.70.xt.autopilot.lua", "function B747_animate_value(", "local B747_afds_helpers = dofile"},
            {AP.."B747.70.xt.autopilot.lua", "function getHeading(lat1, lon1, lat2, lon2)", "local lastILSUpdate = 0"},
            {AP.."B747.70.xt.autopilot.lua", "function setDistances(fmsO)", "----- ALTITUDE SELECTED"},
            {AP.."B747.70.xt.autopilot.lua", "local lastGSProgress=0", "function ap_reset()"},
            {AP.."B747.70.xt.autopilot.monitor.lua", "function VNAV_NEXT_ALT(numAPengaged,fms)",
                "function VNAV_CLB_ALT(numAPengaged,fms)"},
            {AP.."B747.70.xt.autopilot.monitor.lua", "function VNAV_DES_ALT(numAPengaged,fms)",
                "function LNAV_modeSwitch()"}}) do
        run_in(ap, slice(part[1], part[2], part[3]))
    end

    -- the hydraulics' flight director (B747_afds_controls is a local of the file); MODEL_init_director sets the
    -- director's locals to an attitude, as if it had been flying it
    local hyd = namespace(datarefs, {print = noop, B747_afds_controls = controls, debug_flight_directors = 0})
    run_in(hyd, slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_rescale("))
    run_in(hyd, slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on"))
    local director, name = slice(HYD.."B747.19.xt.hydraulics_override.lua", "local director_pitchRecord={}",
        "local trimrate=25")
    run_in(hyd, director..[[

function MODEL_init_director(pitch)
    last_simDR_AHARS_pitch_heading_deg_pilot=pitch
    lastRetVal=pitch
    for i=1,10 do director_pitchRecord[i]=pitch end
    current_pitch_intregal=pitch*10
    directorLastRawPitch=pitch
    B747_afds_pitch_target_before_blend=pitch
    B747_afds_pitch_target_after_blend=pitch
end
function MODEL_director_state()
    return {raw=last_simDR_AHARS_pitch_heading_deg_pilot, sample_rate=directorSampleRate}
end
]], name)

    -- the EEC's A/T throttle; MODEL_init_eec sets its locals to a throttle held at a speed
    local eec = namespace(datarefs, {print = noop})
    run_in(eec, slice(EEC.."B747.42.xt.EEC.lua", "function B747_animate_value(", "function B747_setMaxThrust("))
    run_in(eec, slice(EEC.."B747.42.xt.EEC.lua", "function B747_interpolate_value(", "function round(x)"))
    local throttle, eec_name = slice(EEC.."B747.42.xt.EEC.lua", "local spd_target_throttle=0.5",
        "local previous_altitude = 0")
    run_in(eec, throttle..[[

function MODEL_init_eec(throttle, ias, mode)
    spd_target_throttle=throttle
    last_simDR_ind_airspeed_kts_pilot=ias
    lastMode=mode
    lastModeChange=-100
end
]], eec_name)
    rawset(eec, "throttle_resolver_angle_PW", function(i) return datarefs.B747DR_throttle[i] end)
    return ap, hyd, eec, afds
end

-- The production scripts in their namespaces on a datarefs table, for a suite's own scenario: the
-- autopilot's, the hydraulics' and the EEC's namespaces and the AFDS helpers. stubs: more of the
-- autopilot's globals (fmsData, B747_route_constraints, ...); patches as for M.fly.
function M.load(datarefs, stubs, patches)
    active_patches = patches or {}
    local ap, hyd, eec, afds = load_production(datarefs, stubs or {})
    active_patches = {}
    return ap, hyd, eec, afds
end

-- The datarefs of a descent in VNAV PTH with the autopilot and the A/T engaged, into d, and the V/S and FLCH
-- commands (the manipulators' handlers): the MCP at o.mcp_alt_ft, VNAV's speed o.vnav_speed_kt, o.active the
-- fix flown to, the throttles at throttle.
function M.set_datarefs(d, o, throttle, dt)
    local values = {
        simDRTime = 1000, SIM_PERIOD = dt or 0.05,
        -- the autopilot
        B747DR_ap_cmd_L_mode = 1, B747DR_ap_cmd_C_mode = 0, B747DR_ap_cmd_R_mode = 0,
        B747DR_toggle_switch_position = {[23] = 1, [24] = 1, [29] = 1},
        B747DR_autothrottle_fail = 0, B747DR_ap_autothrottle_armed = 1, B747DR_autothrottle_active = 1,
        B747DR_ap_vnav_state = 2, B747DR_ap_inVNAVdescent = 2, B747DR_ap_inDescent = 1, B747DR_ap_flightPhase = 3,
        B747DR_ap_lnav_state = 2, B747DR_mcp_hold = 0, B747DR_mcp_hold_pressed = -1000, B747DR_switchingIASMode = 0,
        B747DR_ap_VNAV_lastCommand = 0, B747DR_ap_lastCommand = 0, B747DR_ap_thrust_mode = 0,
        B747DR_ap_approach_mode = 0, B747DR_autopilot_gs_status = 0, B747DR_autopilot_nav_status = 0,
        simDR_autopilot_gs_status = 0, simDR_autopilot_nav_status = 0, simDR_autopilot_approach_status = 0,
        B747DR_ap_autoland = 0, B747DR_ap_active_land = 0, B747DR_autopilot_TOGA_status = 0,
        B747DR_engine_TOGA_mode = 0, simDR_autopilot_fms_vnav = 0, B747DR_switching_servos_on = 0,
        B747DR_ap_AFDS_status_annun_pilot = 0, B747DR_ap_vnav_pause = 0,
        B747DR_capt_ap_roll = 0, B747DR_fo_ap_roll = 0, B747DR_ap_target_roll = 0, simDR_capt_roll = 0,
        simDR_fo_roll = 0,
        simDR_autopilot_vs_status = 2, simDR_autopilot_flch_status = 0, simDR_autopilot_alt_hold_status = 0,
        simDR_autopilot_altitude_ft = o.mcp_alt_ft, B747DR_autopilot_altitude_ft = o.mcp_alt_ft,
        simDR_autopilot_hold_altitude_ft = o.mcp_alt_ft, simDR_autopilot_vs_fpm = o.vs_fpm or -1000,
        simDR_autopilot_airspeed_is_mach = 0, simDR_autopilot_airspeed_kts = o.vnav_speed_kt,
        B747DR_ap_ias_dial_value = o.vnav_speed_kt, B747DR_ap_ias_mach_window_open = 0,
        B747DR_ap_FMA_active_pitch_mode = 6, B747DR_ap_FMA_autothrottle_mode = o.at_mode or 3,
        B747DR_alt_capture_window = 600, B747DR_fmscurrentIndex = o.active, B747DR_fmstargetDistance = 0,
        B747DR_ap_vnav_target_alt = 0, B747DR_vnav_hold_index = 0,
        B747BR_totalDistance = 0, B747BR_tod = 0, B747BR_toc = -1, B747BR_cruiseAlt = o.cruise_alt_ft or 37000,
        B747BR_todLat = 0, B747BR_todLong = 0, B747BR_tocLat = 0, B747BR_tocLong = 0,
        B747BR_distance_to_dest = 0, B747BR_eod_index = 0, B747BR_nextDistanceInFeet = 0,
        B747BR_fpe = 0, B747BR_vnavProfile = "[]", B747DR_ap_vb = 0, B747DR_ap_fpa = 0,
        B747DR_speedbrake_lever = 0, B747DR_fmc_notifications = {}, simDR_override_throttles = 1,
        -- the aircraft
        simDR_onGround = 0, simDR_variation = 0, simDR_autopilot_servos_on = 1, B747DR_airspeed_Vmax = 365,
        B747DR_flap_lever_detent = 0, simDR_glideslope1 = o.gs_deg or 3.0, simDR_nav1_gs_flag = 0, simDR_nav2_gs_flag = 0,
        simDR_hsi_nav1_vertical_signal = 1, simDR_hsi_nav2_vertical_signal = 1,
        simDR_hsi_ldef_dots_nav1 = 0, simDR_hsi_ldef_dots_nav2 = 0,
        B744DR_autolandPitch = 0, simDR_flight_director_pitch = 0, B747DR_flight_director_pitch = 0,
        simDR_AHARS_roll_heading_deg_pilot = 0, simDR_autopilot_TOGA_pitch_deg = 8,
        -- the EEC
        B747DR_ref_thr_limit_mode = "CLB", B747DR_engineType = 0,
        B747DR_throttle = {[0] = throttle, throttle, throttle, throttle},
        simDR_engine_throttle_jet_all = throttle, simDR_allThrottle = throttle,
        B747DR_throttle_resolver_angle = {[0] = 0, 0, 0, 0},
        simDR_N1_target_bug = {[0] = 0, 0, 0, 0}, simDR_EPR_target_bug = {[0] = 1, 1, 1, 1},
        B747DR_display_EPR_max = {[0] = 1.5, 1.5, 1.5, 1.5}, B747DR_display_N1 = {[0] = 30, 30, 30, 30}}
    for key, value in pairs(values) do d[key] = value end
    local commands = {
        simCMD_autopilot_flch_mode = {once = function()
            d.simDR_autopilot_vs_status, d.simDR_autopilot_flch_status = 0, 2
            d.simDR_autopilot_alt_hold_status, d.B747DR_ap_thrust_mode = 0, 2
        end},
        simCMD_autopilot_vert_speed_mode = {once = function()
            d.simDR_autopilot_vs_status, d.simDR_autopilot_flch_status, d.simDR_autopilot_alt_hold_status = 2, 0, 0
        end},
        simCMD_ThrottleDown = {once = function() end}}
    for key, value in pairs(commands) do d[key] = value end
end

-- Fly an approach. o = {
--   route = the native FMS's entries {0, kind, 0, 0, lat, lon, 0, name, alt [9], active}, runway = its name in
--   the route, constraints = B747_route_constraints (indexes of route), threshold = {lat, lon, elev_ft},
--   gs_deg (3), active = the entry flown to at the start, start_nm = the distance before it,
--   alt_ft, ias_kt, vs_fpm, flaps (handle ratio), weight_kg, mcp_alt_ft, vnav_speed_kt (VNAV's speed with the
--   window shut; vnav_speeds = {{nm before the threshold, kt}} lowers it from there), cruise_alt_ft,
--   fms_data (getFMSData), at_mode (the A/T FMA at the start), tod_before = {index, nm} (the T/D's position),
--   app_nm (APP pressed at this direct distance to the threshold), loc_delay_s (the LOC captured this long after),
--   vref_kt (VREF30), min_speeds = {{nm before the threshold, kt}} (at or above speeds), flap_schedule =
--   {{detent, nm}}, flap_slow_lead_nm, gear_down_nm,
--   seconds (600), stop_agl_ft (200), dt (0.05), setup = function(m) called before the first frame}.
-- Returns m = {track = samples every 0.5 s, events = {list and first of each kind}, d = datarefs, ap, hyd, eec}.
function M.fly(o)
    local dt = o.dt or 0.05
    local d = {}
    local events, track = {}, {}
    local function event(kind, fields)
        fields = fields or {}
        fields.kind, fields.t = kind, d.simDRTime
        events[#events + 1] = fields
        if events[kind] == nil then events[kind] = fields end
    end
    local fms_data = o.fms_data or {desspdtransalt = "10000", destranspd = "240", desspd = "270",
        desrestspd = "---", desrestalt = "-----", transalt = "18000", crzalt = "FL370"}
    local stubs = {fmsData = fms_data, B747_route_constraints = o.constraints or setmetatable({}, {}),
        VNAV_CLB = function() event("vnav_clb") end, VNAV_CRZ = function() event("vnav_crz") end}
    active_patches = o.patches or {}
    local ap, hyd, eec, afds = load_production(d, stubs)
    for _, patch in ipairs(active_patches) do
        assert(patch.applied, "patch not applied: "..patch[1]..": "..patch[2]:sub(1, 60))
    end
    active_patches = {}

    local route = o.route
    local n = #route
    local runway
    for i = 1, n do
        if route[i][8] == o.runway then runway = i end
    end
    assert(runway, "the route has no "..tostring(o.runway))
    local cum = {0}
    for i = 2, n do cum[i] = cum[i - 1] + ap.getDistance(route[i - 1][5], route[i - 1][6], route[i][5], route[i][6]) end
    local function position(s)
        for i = 2, n do
            if s <= cum[i] or i == n then
                local f = math.max(0, math.min(1, (s - cum[i - 1]) / math.max(cum[i] - cum[i - 1], 1e-6)))
                return route[i - 1][5] + (route[i][5] - route[i - 1][5]) * f,
                    route[i - 1][6] + (route[i][6] - route[i - 1][6]) * f, i
            end
        end
    end
    -- the wind's component along the leg (kt, + a tailwind): o.wind = {{alt_ft, from_deg, kt}, ...} by altitude
    local leg_track = {}
    for i = 2, n do leg_track[i] = ap.getHeading(route[i - 1][5], route[i - 1][6], route[i][5], route[i][6]) end
    local function tailwind(alt_ft, leg)
        local layers = o.wind
        if layers == nil or #layers == 0 then return 0 end
        local from, kt = layers[1][2], layers[1][3]
        if alt_ft >= layers[#layers][1] then
            from, kt = layers[#layers][2], layers[#layers][3]
        else
            for k = 2, #layers do
                if alt_ft < layers[k][1] then
                    local f = math.max(0, (alt_ft - layers[k - 1][1]) / (layers[k][1] - layers[k - 1][1]))
                    from = layers[k - 1][2] + (layers[k][2] - layers[k - 1][2]) * f
                    kt = layers[k - 1][3] + (layers[k][3] - layers[k - 1][3]) * f
                    break
                end
            end
        end
        return kt * math.cos(math.rad(leg_track[leg] - (from + 180)))
    end
    local thr = o.threshold
    local gs_deg = o.gs_deg or 3.0
    local weight = (o.weight_kg or 222000) * G
    local mass = weight / G

    -- the start: trimmed on the flight path of vs_fpm at alt_ft and ias_kt
    local state = {s = cum[o.active] - o.start_nm, h = o.alt_ft, flap = o.flaps or 0, flap_handle = o.flaps or 0,
        gear = 0, active = o.active, hold = 0, manual_speed = false}
    local tas = o.ias_kt * KT * math.sqrt(1.225 / density(o.alt_ft))
    state.V = tas
    state.gamma = math.asin(math.max(-0.2, math.min(0.2, (o.vs_fpm or -1000) * FT / 60 / tas)))
    do
        local q = 0.5 * density(state.h) * state.V ^ 2
        local p = polar(state.flap)
        local alpha = (weight * math.cos(state.gamma) / (q * S) - p[1]) / p[2]
        state.theta = alpha + math.deg(state.gamma)
        local cd = p[3] + p[4] * (p[1] + p[2] * alpha) ^ 2
        state.thrust = math.max(7908, (q * S * cd + weight * math.sin(state.gamma)) / 4)
        state.throttle = math.max(0, math.min(1, (state.thrust - 7908) / 154802))
    end
    state.vsi = state.V * math.sin(state.gamma) / FT * 60

    M.set_datarefs(d, o, state.throttle, dt)
    -- the T/D, set by setDistances before it was passed: tod_before = {index, nm} along the route before that entry
    if o.tod_before then
        d.B747BR_todLat, d.B747BR_todLong = position(cum[o.tod_before[1]] - o.tod_before[2])
    end
    ap.B747_reset_vnav_energy()
    hyd.MODEL_init_director(state.theta)
    eec.MODEL_init_eec(state.throttle, o.ias_kt, d.B747DR_ref_thr_limit_mode)

    -- LNAV sequences a fix this far before it (the P5 turn anticipation at the start's speed)
    local lead = {}
    for i = 2, n - 1 do
        local course_in = ap.getHeading(route[i - 1][5], route[i - 1][6], route[i][5], route[i][6])
        local course_out = ap.getHeading(route[i][5], route[i][6], route[i + 1][5], route[i + 1][6])
        lead[i] = afds.lnav_turn_anticipation_nm(tas / KT, 0, 0, 25, course_in, course_out, 3, tas / KT)
    end

    local kit = {app = false, loc = false, gear = false, spd_set = false, pushes = 0, push_t = nil,
        blocked_since = nil, next_t = 0}
    local m = {track = track, events = events, d = d, ap = ap, hyd = hyd, eec = eec, afds = afds, kit = kit,
        state = state, cum = cum, runway = runway}
    if o.setup then o.setup(m) end

    local t0 = d.simDRTime
    local next_distances, next_sample = 0, 0
    local seconds = o.seconds or 600
    while d.simDRTime - t0 < seconds do
        local now = d.simDRTime
        local lat, lon, leg = position(state.s)
        local wind_ms = tailwind(state.h, leg) * KT
        local dist_thr = cum[runway] - state.s
        local direct = ap.getDistance(lat, lon, thr[1], thr[2])
        local rho = density(state.h)
        local ias = state.V * math.sqrt(rho / 1.225) / KT
        local vs = state.V * math.sin(state.gamma) / FT * 60
        state.vsi = state.vsi + (vs - state.vsi) * math.min(1, dt / 1.0)
        local agl = state.h - thr[3]
        local from_origin_ft = (dist_thr * NM + 300) / FT
        local elevation = math.deg(math.atan2(state.h - thr[3], from_origin_ft))
        local alpha = state.theta - math.deg(state.gamma)

        -- the simulator's values
        d.simDR_latitude, d.simDR_longitude = lat, lon
        d.simDR_pressureAlt1, d.simDR_radarAlt1 = state.h, agl
        d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot = ias, ias
        d.simDR_vvi_fpm_pilot = state.vsi
        d.simDR_groundspeed = state.V * math.cos(state.gamma) + wind_ms
        d.simDR_TAS_mps, d.simDR_alpha_deg = state.V, alpha
        d.simDR_AHARS_pitch_heading_deg_pilot = state.theta
        d.simDR_hsi_vdef_dots_pilot = M.gs_dots(elevation, gs_deg)
        d.B747DR_flap_ratio = state.flap
        d.B747DR_airspeed_Vmc = M.vmc(mass, flap_deg(state.flap))

        -- the autopilot script's frame (after_physics)
        d.simDR_allThrottle = math.max(d.B747DR_throttle[0], d.B747DR_throttle[1], d.B747DR_throttle[2],
            d.B747DR_throttle[3])
        -- LNAV: the next fix, or the one after it within its turn's anticipation; the fix sequenced early is held
        -- for VNAV until passed (its turn's bisector on the straight legs)
        local ahead = n
        for i = state.active, n do
            if cum[i] > state.s then ahead = i break end
        end
        if ahead < runway and lead[ahead] and cum[ahead] - state.s <= lead[ahead] then ahead = ahead + 1 end
        if ahead > state.active then
            if ahead == state.active + 1 and cum[state.active] > state.s then state.hold = state.active end
            state.active = ahead
            event("sequence", {index = ahead, name = route[ahead][8], dist_thr = dist_thr})
        end
        if state.hold > 0 and state.s >= cum[state.hold] then state.hold = 0 end
        for i = 1, n do route[i][10] = (i == state.active) end
        d.B747DR_fmscurrentIndex, d.B747DR_vnav_hold_index = state.active, state.hold
        -- B747_monitorAP: VNAV, then the approach's captures (B747_updateApproachHeading)
        ap.VNAV_modeSwitch(route)
        if d.simDR_autopilot_gs_status == 1 and now - d.B747DR_ap_lastCommand > 0.5 and afds.gs_capture_ready({
                loc_captured = (d.simDR_autopilot_nav_status == 2), nav1_dots = 0, nav2_dots = 0,
                gs_dots = d.simDR_hsi_vdef_dots_pilot, nav1_gs_flag = 0, nav2_gs_flag = 0,
                nav1_vertical_signal = 1, nav2_vertical_signal = 1}) then
            d.simDR_autopilot_gs_status = 2
            d.B747DR_ap_lastCommand = now
            event("gs_capture", {dist_thr = dist_thr, alt = state.h, elevation = elevation,
                dots = d.simDR_hsi_vdef_dots_pilot, ias = ias})
        end
        ap.B747_update_vnav_energy_mode_isolation()
        ap.B747_ap_fma(route)
        if now >= next_distances then                -- B747_fltmgmt_setILS
            next_distances = now + 2
            ap.setDistances(route)
        end
        -- the IAS window (B747_ap_ias_mach_mode), VNAV's speed with it shut (B747_vnav_speed)
        if d.B747DR_switchingIASMode == 0 and (d.B747DR_ap_vnav_state < 2 or state.manual_speed) then
            d.B747DR_ap_ias_mach_window_open = 1
        else
            d.B747DR_ap_ias_mach_window_open = 0
        end
        if d.B747DR_ap_vnav_state > 0 and not state.manual_speed then
            local vnav_speed = o.vnav_speed_kt
            if o.vnav_speeds then                     -- {{from nm before the threshold, kt}, ...}
                for _, vs_entry in ipairs(o.vnav_speeds) do
                    if dist_thr <= vs_entry[1] then vnav_speed = vs_entry[2] end
                end
            end
            d.simDR_autopilot_airspeed_kts = vnav_speed
            d.B747DR_ap_ias_dial_value = vnav_speed
        end
        -- B747_ap_altitude
        d.B747DR_alt_capture_window = rescale(0, 200, 3000, 1000, math.abs(d.simDR_vvi_fpm_pilot))

        -- the hydraulics' frame (ap_pitch_assist) and the EEC's (throttle_management)
        local fd = hyd.ap_director_pitch_integral()
        if d.B747DR_ap_autothrottle_armed == 1 and d.B747DR_ap_FMA_autothrottle_mode > 1 then
            eec.ecc_throttle()
        end
        local throttle = (d.B747DR_throttle[0] + d.B747DR_throttle[1] + d.B747DR_throttle[2]
            + d.B747DR_throttle[3]) / 4

        -- the kit (fullflight.py phase_approach), every 0.2 s
        if now >= kit.next_t then
            kit.next_t = now + 0.2
            local window_open = d.B747DR_ap_ias_mach_window_open == 1
            if not kit.app and direct <= o.app_nm then
                kit.app, kit.app_t = true, now
                d.B747DR_ap_approach_mode = 1
                d.simDR_autopilot_nav_status, d.simDR_autopilot_gs_status = 1, 1
                d.B747DR_ap_lastCommand = now
                event("app", {dist_thr = dist_thr, direct = direct, alt = state.h})
            end
            if kit.app and not kit.loc and now - kit.app_t >= (o.loc_delay_s or 10) then
                kit.loc = true
                d.simDR_autopilot_nav_status = 2
                d.B747DR_ap_lastCommand = now
                event("loc", {dist_thr = dist_thr, alt = state.h})
            end
            local current = M.FLAP_DETENTS[math.floor(state.flap_handle * 6 + 0.5) + 1]
            local soon, due = -1, -1
            for _, sched in ipairs(o.flap_schedule) do
                if dist_thr <= sched[2] + (o.flap_slow_lead_nm or 0) then soon = math.max(soon, sched[1]) end
                if dist_thr <= sched[2] then due = math.max(due, sched[1]) end
            end
            if soon > current then
                local k = 1
                while M.FLAP_DETENTS[k] ~= current do k = k + 1 end
                local next_detent = M.FLAP_DETENTS[k + 1]
                local limit = M.FLAP_PLACARD[next_detent] - 3
                local vnav = d.B747DR_ap_FMA_active_pitch_mode >= 4 and d.B747DR_ap_FMA_active_pitch_mode <= 6
                local blocked = kit.blocked_since and now - kit.blocked_since or 0
                local action
                if ias <= limit then
                    action = "flaps"
                elseif vnav and blocked < 20 and not (d.simDR_autopilot_airspeed_kts > limit) then
                    action = "wait"
                elseif window_open then
                    action = "dial"
                elseif vnav then
                    action = "push"
                else
                    action = "wait"
                end
                if action == "flaps" then
                    kit.blocked_since = nil
                    if due > current then
                        state.flap_handle = k / 6
                        event("flaps", {detent = next_detent, dist_thr = dist_thr, ias = ias})
                    end
                else
                    kit.blocked_since = kit.blocked_since or now
                    if action == "push" and d.B747DR_ap_vnav_state == 2 and kit.pushes < 2
                        and (kit.push_t == nil or now - kit.push_t >= 3) then
                        kit.pushes, kit.push_t = kit.pushes + 1, now
                        state.manual_speed = not state.manual_speed
                        event("spd_push", {for_flaps = next_detent, dist_thr = dist_thr, ias = ias,
                            vnav_kt = d.simDR_autopilot_airspeed_kts})
                    elseif action == "dial" then
                        local want = M.FLAP_PLACARD[next_detent] - 10
                        if d.B747DR_ap_ias_dial_value > want then
                            d.B747DR_ap_ias_dial_value, d.simDR_autopilot_airspeed_kts = want, want
                            event("mcp_speed", {kt = want, dist_thr = dist_thr})
                        end
                    end
                end
            end
            if not kit.gear and (dist_thr < (o.gear_down_nm or 10) or d.B747DR_ap_FMA_active_pitch_mode == 2) then
                kit.gear = true
                event("gear", {dist_thr = dist_thr})
            end
            if not kit.spd_set and d.B747DR_ap_FMA_active_pitch_mode == 2 and state.flap_handle >= 0.999
                and window_open then
                local floor
                for _, ms in ipairs(o.min_speeds or {}) do
                    if dist_thr > ms[1] and (floor == nil or ms[2] > floor) then floor = ms[2] end
                end
                local want = o.vref_kt + 5
                if floor and floor > want then
                    want = floor
                else
                    kit.spd_set = true
                end
                if d.B747DR_ap_ias_dial_value ~= want then
                    d.B747DR_ap_ias_dial_value, d.simDR_autopilot_airspeed_kts = want, want
                    event("mcp_speed", {kt = want, dist_thr = dist_thr})
                end
            end
        end

        -- the aircraft
        state.flap = state.flap + math.max(-dt / 30, math.min(dt / 30, state.flap_handle - state.flap))
        if kit.gear then state.gear = math.min(1, state.gear + dt / 10) end
        state.throttle = throttle
        state.thrust = state.thrust + (7908 + 154802 * throttle - state.thrust) * math.min(1, dt / 2.5)
        state.theta = state.theta + math.max(-3 * dt, math.min(3 * dt, (fd - state.theta) * dt / 1.5))
        alpha = state.theta - math.deg(state.gamma)
        local p = polar(state.flap)
        local q = 0.5 * rho * state.V ^ 2
        local cl = p[1] + p[2] * alpha
        local cd = p[3] + p[4] * cl * cl + GEAR_CD0 * state.gear
        local a = math.rad(alpha)
        local thrust = 4 * state.thrust
        local vdot = (thrust * math.cos(a) - q * S * cd - weight * math.sin(state.gamma)) / mass
        local gdot = (q * S * cl + thrust * math.sin(a) - weight * math.cos(state.gamma)) / (mass * state.V)
        state.V = state.V + vdot * dt
        state.gamma = state.gamma + gdot * dt
        state.h = state.h + state.V * math.sin(state.gamma) / FT * dt
        state.s = state.s + (state.V * math.cos(state.gamma) + wind_ms) / NM * dt

        if now >= next_sample then
            next_sample = now + 0.5
            track[#track + 1] = {t = now - t0, dist_thr = dist_thr, direct = direct, alt = state.h, ias = ias,
                vs = vs, vs_cmd = d.simDR_autopilot_vs_fpm, theta = state.theta, fd = fd, alpha = alpha,
                throttle = throttle, flap = state.flap, active = state.active, hold = state.hold,
                target = d.B747DR_ap_vnav_target_alt, ap_alt = d.simDR_autopilot_altitude_ft, fpe = d.B747BR_fpe,
                total = d.B747BR_totalDistance, pitch_mode = d.B747DR_ap_FMA_active_pitch_mode,
                at_mode = d.B747DR_ap_FMA_autothrottle_mode, at_active = d.B747DR_autothrottle_active,
                energy = d.B747DR_vnav_energy_active, vnav_state = d.B747DR_ap_vnav_state,
                gs = d.simDR_autopilot_gs_status, dots = d.simDR_hsi_vdef_dots_pilot, elevation = elevation,
                spd = d.simDR_autopilot_airspeed_kts, window = d.B747DR_ap_ias_mach_window_open,
                vs_status = d.simDR_autopilot_vs_status, alt_hold = d.simDR_autopilot_alt_hold_status,
                flch = d.simDR_autopilot_flch_status, vmc = d.B747DR_airspeed_Vmc}
        end
        if d.B747DR_ap_FMA_autothrottle_mode == 0 and not m.at_off_logged then
            m.at_off_logged = true
            event("at_off", {dist_thr = dist_thr, ias = ias, throttle = throttle})
        end
        d.simDRTime = now + dt
        if agl < (o.stop_agl_ft or 200) or state.V < 60 * KT or dist_thr < -1 then break end
    end
    m.end_dist_thr = cum[runway] - state.s
    m.end_alt = state.h
    return m
end

-- The track's sample nearest a distance before the threshold.
function M.at(m, dist_nm)
    local best, best_diff
    for _, p in ipairs(m.track) do
        local diff = math.abs(p.dist_thr - dist_nm)
        if best_diff == nil or diff < best_diff then best, best_diff = p, diff end
    end
    return best
end

-- Height above the glide slope (ft) of a sample.
function M.above_gs(p, threshold_elev_ft, gs_deg)
    return p.alt - threshold_elev_ft - (p.dist_thr * NM + 300) * math.tan(math.rad(gs_deg or 3)) / FT
end

-- A text table of the track every `step` s (for a look at a run).
function M.dump(m, step, from_nm)
    local lines = {string.format("%6s %6s %6s %5s %6s %6s %6s %3s %6s %5s %5s %3s %3s %3s %3s %4s %5s %5s %3s %5s",
        "t", "thr", "alt", "ias", "vs", "vscmd", "target", "act", "fpe", "theta", "fd", "pm", "at", "en", "win",
        "spd", "thro", "flap", "gs", "dots")}
    local last
    for _, p in ipairs(m.track) do
        if (from_nm == nil or p.dist_thr <= from_nm) and (last == nil or p.t - last >= (step or 5)) then
            last = p.t
            lines[#lines + 1] = string.format(
                "%6.1f %6.2f %6.0f %5.1f %6.0f %6.0f %6.0f %3d %6.0f %5.2f %5.2f %3d %3d %3d %3d %4.0f %5.2f %5.2f %3d %5.2f",
                p.t, p.dist_thr, p.alt, p.ias, p.vs, p.vs_cmd, p.target, p.active, p.fpe, p.theta, p.fd,
                p.pitch_mode, p.at_mode, p.energy or 0, p.window, p.spd, p.throttle, p.flap, p.gs, p.dots)
        end
    end
    return table.concat(lines, "\n")
end

-- The scenarios as flown.
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
M.entry = entry

-- EIDW -> EHAM (flight_EIDW_EHAM.json, LAMS2A, ILS 18R via SUG1D) from 2.4 nm before AM607 (17.2 nm from the
-- threshold), as p6-line1 (2026-10-16, t 4056: 5150 ft, 224 kt, -640 fpm, flaps 5, VNAV PTH, A/T IDLE).
function M.eham(overrides)
    local route = {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("DIBAL", 52.797217, 2.5, 26309),
        entry("LAMSO", 52.732889, 2.994361, 21438), entry("ETPOS", 52.585122, 3.414178, 16752),
        entry("SUGOL", 52.525511, 3.96735, 11315), entry("NETOM", 52.422444, 4.387917, 7849),
        entry("NIRSI", 52.583878, 4.513372, 5563), entry("AM607", 52.583889, 4.646889, 4272),
        entry("AM608", 52.539417, 4.728139, 3400), entry("AM621", 52.462694, 4.721111, 2000),
        entry("AM622", 52.426722, 4.717806, 1310), entry("RW18R", 52.360258, 4.711725, 37),
        entry("EHAM", 52.317497, 4.771616, -11, 1)}
    local constraints = setmetatable({
        [5] = {alt_desc = "B", floor = 10000, ceiling = 14000, fl = true, phase = "descent"},
        [6] = {alt_desc = "+", floor = 7000, fl = true, speed_desc = "-", speed = 250, phase = "descent"},
        [7] = {alt_desc = "+", floor = 5500, fl = true, speed_desc = "-", speed = 220, phase = "descent"},
        [9] = {alt_desc = "+", floor = 3400, phase = "descent"},
        [10] = {alt_desc = "J", floor = 2000, phase = "descent"},
        [11] = {alt_desc = "H", floor = 1310, speed_desc = "+", speed = 160, phase = "descent"},
        [12] = {alt_desc = "@", floor = 37, ceiling = 37, phase = "descent"}}, {})
    local o = {route = route, runway = "RW18R", constraints = constraints, threshold = {52.360258, 4.711725, -13},
        gs_deg = 3.0, active = 8, start_nm = 2.42, alt_ft = 5150, ias_kt = 224, vs_fpm = -640, flaps = 2 / 6,
        weight_kg = 223300, mcp_alt_ft = 2000, vnav_speed_kt = 220, cruise_alt_ft = 37000, at_mode = 2,
        app_nm = 9.8, loc_delay_s = 14.5, vref_kt = 135, min_speeds = {{3.99, 160}},
        flap_schedule = {{1, 22}, {5, 18}, {10, 15}, {20, 12}, {25, 10}, {30, 8}}, flap_slow_lead_nm = 1.0,
        gear_down_nm = 10}
    for key, value in pairs(overrides or {}) do o[key] = value end
    return o
end

-- TST744L's EINN ILS 06 (flight_EINN_TST744L.json; BILTO -> ELPOM, 92 deg left at ELPOM) from 7.2 nm before ELPOM
-- (20.2 nm from the threshold), as p6-L1 (2026-10-16, t 949: 5140 ft, 241 kt, -1260 fpm, flaps 1, A/T IDLE).
function M.einn(overrides)
    local route = {entry("EINN", 52.701992, -8.924772, 41, 1), entry("EMPER", 49, -9, 31000),
        entry("BEDRA", 49, -15, 33000), entry("ETARI", 55.5, -15, 35000), entry("BILTO", 56.5, -15, 35000),
        entry("ELPOM", 52.560306, -9.224111, 3000), entry("ASGON", 52.598444, -9.143917, 3046),
        entry("RW06", 52.693172, -8.943519, 101), entry("EINN", 52.701992, -8.924772, 41, 1)}
    local constraints = setmetatable({
        [6] = {alt_desc = "J", floor = 3000, phase = "descent"},
        [7] = {alt_desc = "H", floor = 3000, phase = "descent"},
        [8] = {alt_desc = "@", floor = 101, ceiling = 101, phase = "descent"}}, {})
    local o = {route = route, runway = "RW06", constraints = constraints, threshold = {52.693172, -8.943519, 46},
        gs_deg = 3.0, active = 6, start_nm = 7.2, alt_ft = 5140, ias_kt = 241, vs_fpm = -1260, flaps = 1 / 6,
        weight_kg = 279000, mcp_alt_ft = 3000, vnav_speed_kt = 240, cruise_alt_ft = 35000, at_mode = 2,
        tod_before = {6, (35000 - 3000) / 290},
        wind = {{1000, 270, 0}, {5000, 270, 20}, {10000, 270, 40}, {18000, 270, 60}},
        fms_data = {desspdtransalt = "10000", destranspd = "240", desspd = "270", desrestspd = "---",
            desrestalt = "-----", transalt = "18000", crzalt = "FL350"},
        app_nm = 11.0, loc_delay_s = 40, vref_kt = 153, min_speeds = {},
        flap_schedule = {{1, 22}, {5, 18}, {10, 15}, {20, 12}, {25, 10}, {30, 8}}, flap_slow_lead_nm = 1.0,
        gear_down_nm = 10}
    for key, value in pairs(overrides or {}) do o[key] = value end
    return o
end

return M
