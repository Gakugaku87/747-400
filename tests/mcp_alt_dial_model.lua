-- Model for the MCP altitude knob tests (mcp_alt_dial_test.lua): the production ALT knob, VNAV, the FMA, the ALT
-- selector, the thrust monitors and the approach modes (the autopilot's namespace) and the AFDS pitch director (the
-- hydraulics namespace), loaded as tests/approach_model.lua does, flying a kinematic vertical model (the V/S follows
-- the mode) while the knob is clicked at the kit's cadence (0.079 s a click in p18-line1). Timers (run_after_time)
-- run on the model's clock. Logic only; this does not validate flight dynamics.
local model = dofile("tests/approach_model.lua")   -- set_datarefs and the route helpers

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"

local sources = {}
local function read_source(path)
    if sources[path] == nil then
        local f = assert(io.open(path)); sources[path] = f:read("*a"); f:close()
    end
    return sources[path]
end
local function slice(path, first_marker, last_marker)
    local source = read_source(path)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = last_marker and assert(source:find(last_marker, first + 1, true), last_marker) or (#source + 1)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1), "@"..path
end
local function run_in(ns, code, name) setfenv(assert(loadstring(code, name)), ns)() end
local function is_dataref(key)
    return type(key) == "string" and (key:find("^simDR") ~= nil or key:find("^simCMD") ~= nil
        or key:find("^B74[47]DR") ~= nil or key:find("^B747BR") ~= nil or key == "SIM_PERIOD")
end
local function namespace(d, globals)
    local ns = {}
    for k, v in pairs(globals) do rawset(ns, k, v) end
    return setmetatable(ns, {
        __index = function(_, k) if is_dataref(k) then return d[k] end return _G[k] end,
        __newindex = function(t, k, v) if is_dataref(k) then d[k] = v else rawset(t, k, v) end end})
end

local M = {model = model}
-- XTLua's run_after_time / is_timer_scheduled / stop_timer on the model's clock
local function new_timers(d)
    local T = {list = {}}
    function T.run_after_time(f, s) T.list[f] = d.simDRTime + s end
    function T.is_timer_scheduled(f) return T.list[f] ~= nil end
    function T.stop_timer(f) T.list[f] = nil end
    function T.process()
        local due = {}
        for f, t in pairs(T.list) do if d.simDRTime >= t - 1e-9 then due[#due + 1] = f end end
        for _, f in ipairs(due) do T.list[f] = nil; f() end
    end
    return T
end

function M.load(d)
    local runtime = setmetatable({}, {__index = _G})
    local init = assert(loadfile("plugins/xtlua_keysystems/init.lua"))
    setfenv(init, runtime); init()
    runtime.XLuaGetCode = function(requested)
        local p = requested
        if not string.find(requested, "/", 1, true) then p = AP..requested end
        return assert(loadstring(read_source(p), "@"..p))
    end
    local afds = runtime.XLuaGetCode(AP.."B747.70.xt.autopilot.afds_helpers.lua")()
    local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
    local json = dofile(AP.."json/json.lua")
    local noop = function() end
    local T = new_timers(d)
    local prints = {}
    local function cap_print(s) prints[#prints + 1] = string.format("%.2f %s", d.simDRTime, tostring(s)) end
    local fdr = {once = noop}
    local ap_globals = {print = cap_print, json = json, B747_afds_helpers = afds, apWasOn = 1,
        run_after_time = T.run_after_time, is_timer_scheduled = T.is_timer_scheduled, stop_timer = T.stop_timer,
        fma_rollModes = noop, runAutoland = function() return false end, B747_lnav_engage_armed = noop,
        B747_ap_all_cmd_modes_off = noop, B747_takeoff_thrust_reduction_reached = function() return true end,
        toderate = 0, clbderate = 0, B744_fpm = 0, B747_lnav_path_track = function() return nil end,
        B747_route_constraints = setmetatable({}, {}),
        B747CMD_fdr_log_spd = fdr, B747CMD_fdr_log_spdmod = fdr, B747CMD_fdr_log_altmod = fdr,
        B747CMD_fdr_log_flch = fdr, B747CMD_fdr_log_vs = fdr, B747CMD_fdr_log_alt = fdr, B747CMD_fdr_log_app = fdr,
        B747CMD_fdr_log_loc = fdr,
        B747_ap_button_switch_position_target = setmetatable({}, {__index = function() return 0 end}),
        B747_updateIASWindow = noop}
    local ap = namespace(d, ap_globals)
    rawset(ap, "dofile", runtime.get_run_file_in_namespace(ap))
    ap.dofile(AP.."B747.70.xt.autopilot.vnav.lua")
    local A, MON = AP.."B747.70.xt.autopilot.lua", AP.."B747.70.xt.autopilot.monitor.lua"
    for _, part in ipairs({
            {A, "function B747_rescale(", "function getTriSpaceSolver("},
            {A, "local beganDescentAny = false", "--*****"},
            {A, "function B747_animate_value(", "local B747_afds_helpers = dofile"},
            {A, "function autothrottle_reengage()", "function B747_ap_switch_cmd_L_CMDhandler("},
            {A, "function B747_updateIAS()", "-- After a knots/Mach swap"},
            {A, "function setSimAlt()", "--[[function B747CMD_ap_heading_up_CMDhandler"},
            {A, "function getHeading(lat1, lon1, lat2, lon2)", "local lastILSUpdate = 0"},
            {A, "function B747_ternary(", "----- ANIMATION UNILITY"},
            {A, "function B747_ap_altitude(fms)", "--OLD button functions"},
            {A, "function B747_ap_appr_mode()", "----- FLIGHT MODE ANNUNCIATORS"},
            {A, "local lastGSProgress=0", "function ap_reset()"},
            {MON, "function VNAV_NEXT_ALT(numAPengaged,fms)", "function LNAV_modeSwitch()"},
            {MON, "function LNAV_modeSwitch()", nil}}) do
        run_in(ap, slice(part[1], part[2], part[3]))
    end
    local hyd = namespace(d, {print = noop, B747_afds_controls = controls, debug_flight_directors = 0})
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
]], name)
    return ap, hyd, afds, controls, T, prints
end

M.FMS_DATA = {accelht = "1000", clbrestalt = nil, clbrestspd = nil, spdtransalt = "10000", clbspd = "320",
    transpd = "250", transalt = "18000", crzspd = "840", clbmach = "840", costindex = "80", desspdmach = "840",
    desspd = "290", destranspd = "240", desspdtransalt = "10000", desrestspd = nil, desrestalt = nil,
    crzalt = "FL370", thrredht = "1000", thrredflap = "", stepto = "*****"}

local entry = model.entry
-- a route north along 0 E from 50 N: fixes {name, nm from the start, alt, kind}; the last an airport (kind 1)
function M.route_north(fixes)
    local r = {entry("ORIG", 50.0, 0.0, 0, 1)}
    for _, f in ipairs(fixes) do r[#r + 1] = entry(f[1], 50.0 + f[2] / 60.0, 0.0, f[3] or 0, f[4]) end
    return r
end

-- the datarefs for an aircraft at o.alt, o.vs in the modes of o.d
function M.base(o)
    local d = {}
    model.set_datarefs(d, {mcp_alt_ft = o.mcp, vnav_speed_kt = o.ias or 290, active = o.active or 2,
        cruise_alt_ft = o.cruise or 37000, at_mode = 3, vs_fpm = o.vs_cmd or 0}, 0.6, 0.05)
    local v = {
        simDR_version = 120012, simDR_autopilot_autothrottle_enabled = 0, simDR_autopilot_autothrottle_on = 0,
        B747DR_display_N1 = {[0] = 90, 90, 90, 90}, B747DR_ap_lnav_state = 0, B747DR_ap_lnavHeading_mode = 0,
        B747DR_ap_approach_mode = 0, simDR_pressureAlt1 = o.alt, simDR_radarAlt1 = o.alt - 50,
        simDR_elevation = o.alt * 0.3048,
        simDR_vvi_fpm_pilot = o.vs, simDR_ind_airspeed_kts_pilot = o.ias or 290,
        simDR_autopilot_airspeed_kts = o.ias or 290, simDR_airspeed_mach = o.mach or 0.78,
        simDR_autopilot_airspeed_kts_mach = o.ias or 290, B747DR_airspeed_Vmc = 150, B747DR_airspeed_Vmax = 365,
        B747DR_airspeed_Vmo = 365, B747DR_airspeed_Mms = 0.92, simDR_groundspeed = 240, simDR_alpha_deg = 2.5,
        simDR_TAS_mps = 240, simDR_AHARS_roll_heading_deg_pilot = 0, simDR_AHARS_pitch_heading_deg_pilot = 2.5,
        B747DR_flap_ratio = 0, simDR_flap_ratio_control = 0, B747DR_flap_lever_detent = 0, B747DR_airspeed_V2 = 160,
        simDR_altimeter_baro_inHg = 29.92, simDR_altimeter_baro_inHg_fo = 29.92, B747DR_lastap_dial_airspeed = 290,
        simDR_latitude = 50.0, simDR_longitude = 0.0, B747DR_vnav_constraint_speed = 0, B747DR_ap_vs_window_open = 0,
        simDR_autopilot_heading_status = 2, simDR_autopilot_heading_hold_status = 0, simDR_AHARS_heading_deg_pilot = 0,
        simDR_radio_nav_obs_deg = {[0] = 0}, simDR_hsi_nav1_horizontal_signal = 0, simDR_hsi_nav2_horizontal_signal = 0,
        simDR_hsi_vdef_dots_pilot = 0, simDR_nav1_gs_flag = 0, simDR_nav2_gs_flag = 0,
        B747DR_ap_FMA_armed_pitch_mode = 0, B747DR_ap_FMA_armed_roll_mode = 0, B747DR_ap_FMA_active_roll_mode = 6,
        B747DR_efis_baro_std_capt_switch_pos = 1, B747DR_efis_baro_std_fo_switch_pos = 1,
        simDR_autopilot_vs_fpm = o.vs_cmd or 0, B747DR_autopilot_vs_fpm = o.vs_cmd or 0, B747DR_ap_vvi_fpm = 0,
        B747DR_ap_target_altitude = -1, B747DR_ap_ATT = 0, B747DR_ap_heading_deg = 0, simDR_autopilot_heading_deg = 0,
        B747DR_FMSdata = "", B747DR_fms_setCurrent = 0, B747DR_vnav_energy_drag_required = 0,
        B747DR_flight_director_pitch = 2.5, simDR_flight_director_pitch = 2.5, B747DR_ap_target_vertspeed = -1,
        simDR_autopilot_TOGA_pitch_deg = 8, B747DR_ap_vnav_system = 2, B747DR_ap_ias_dial_value = o.ias or 290,
        B747DR_hyd_sys_pressure_1 = 3000, B747DR_hyd_sys_pressure_2 = 3000, B747DR_hyd_sys_pressure_3 = 3000,
        B747DR_ils_dots = 0, simDR_radio_nav1_bearing_deg = 0, simDR_radio_nav2_bearing_deg = 0,
        B747DR_ND_Wind_Bearing = 0, simDR_wind_speed_kts = 0, simDR_variation = 0,
        simDR_hsi_nav1_vertical_signal = 0, simDR_hsi_nav2_vertical_signal = 0, simDR_nav1_radio_course_deg = 0,
    }
    for k, val in pairs(v) do d[k] = val end
    d.simCMD_autopilot_heading_select = {once = function() d.simDR_autopilot_heading_status = 2 end}
    d.simCMD_ATOff, d.simCMD_ATOffXP11 = {once = function() end}, {once = function() end}
    d.simCMD_ThrottleUp, d.simCMD_pause = {once = function() end}, {once = function() end}
    for k, val in pairs(o.d or {}) do d[k] = val end
    return d
end

-- n clicks of dir from t0, dt_click apart (the kit: 0.079 s)
function M.dial(t0, n, dir, dt_click)
    local c = {}
    for i = 0, n - 1 do c[#c + 1] = {t = t0 + i * (dt_click or 0.079), dir = dir} end
    return c
end

local CLIMB_FPM, DESC_FPM = 2000, -2500
-- Flies scenario scn ({setup, clicks, seconds, each}): returns the end state and a sample every frame
-- ({t, alt, vs, alt_hold, hold, fma, at, inDes, vs_cmd, gs, afds, mcp, lastCommand}).
function M.run(scn)
    local o = scn.setup()
    local d = M.base(o)
    local ap, hyd, afds, controls, T, prints = M.load(d)
    rawset(ap, "fmsData", o.fms_data or M.FMS_DATA)
    d.B747DR_FMSdata = ap.json.encode(o.fms_data or M.FMS_DATA)
    hyd.MODEL_init_director(2.5)
    local fms = o.route
    local dt, t0 = 0.05, d.simDRTime
    local clicks, ci = scn.clicks or {}, 1
    local vs, alt = o.vs, o.alt
    local samples = {}
    local seconds = scn.seconds or 40
    while d.simDRTime - t0 < seconds do
        local t = d.simDRTime - t0
        T.process()
        while clicks[ci] and clicks[ci].t <= t + 1e-9 do
            local c = clicks[ci]
            if c.dir > 0 then ap.B747_ap_altitude_up_CMDhandler(c.phase or 0, c.dur or 0)
            else ap.B747_ap_altitude_down_CMDhandler(c.phase or 0, c.dur or 0) end
            ci = ci + 1
        end
        if scn.each then scn.each(d, t, ap) end
        d.simDR_pressureAlt1, d.simDR_radarAlt1 = alt, alt - (o.elev or 50)
        d.simDR_elevation = alt * 0.3048     -- m: the G/S director takes its V/S from the elevation's rate
        d.simDR_vvi_fpm_pilot = vs
        d.simDR_allThrottle = math.max(d.B747DR_throttle[0], d.B747DR_throttle[1], d.B747DR_throttle[2],
            d.B747DR_throttle[3])
        for i = 1, #fms do fms[i][10] = (i == (o.active or 2)) end
        d.B747DR_fmscurrentIndex = o.active or 2
        ap.B747_monitorAP(fms)
        ap.B747_update_vnav_energy_mode_isolation()
        ap.B747_ap_fma(fms)
        ap.B747_ap_altitude(fms)
        ap.B747_vnav_speed()
        ap.B747_ap_appr_mode()
        hyd.ap_director_pitch_integral()
        samples[#samples + 1] = {t = t, alt = alt, vs = vs, alt_hold = d.simDR_autopilot_alt_hold_status,
            hold = d.simDR_autopilot_hold_altitude_ft, fma = d.B747DR_ap_FMA_active_pitch_mode,
            at = d.B747DR_ap_FMA_autothrottle_mode, inDes = d.B747DR_ap_inVNAVdescent, vs_cmd = d.simDR_autopilot_vs_fpm,
            gs = d.simDR_autopilot_gs_status, afds = d.simDR_autopilot_altitude_ft, mcp = d.B747DR_autopilot_altitude_ft,
            lastCommand = d.B747DR_ap_lastCommand - t0, mcp_hold = d.B747DR_mcp_hold}
        -- kinematics: the V/S follows the mode
        local pm = d.B747DR_ap_FMA_active_pitch_mode
        local tgt
        if d.simDR_autopilot_alt_hold_status == 2 then
            tgt = controls.altitude_hold_target_fpm(d.simDR_autopilot_hold_altitude_ft, alt,
                d.simDR_ind_airspeed_kts_pilot, d.simDR_autopilot_airspeed_kts, 160, 365)
        elseif pm == 2 then tgt = -800
        elseif d.simDR_autopilot_vs_status == 2 and (pm == 6 or pm == 7 or pm == 4) then tgt = d.simDR_autopilot_vs_fpm
        elseif d.simDR_autopilot_flch_status == 2 or pm == 4 or pm == 8 then
            tgt = (d.simDR_autopilot_altitude_ft > alt) and (o.climb_fpm or CLIMB_FPM) or (o.desc_fpm or DESC_FPM)
        else tgt = vs end
        vs = vs + (tgt - vs) * math.min(1, dt / 3)
        alt = alt + vs / 60 * dt
        if o.gs_ms then
            d.B747BR_totalDistance = d.B747BR_totalDistance - o.gs_ms / 1852 * dt
            d.simDR_latitude = d.simDR_latitude + o.gs_ms / 1852 / 60 * dt
        end
        d.simDRTime = d.simDRTime + dt
    end
    return {alt = alt, vs = vs, d = d, samples = samples, prints = prints}
end

return M
