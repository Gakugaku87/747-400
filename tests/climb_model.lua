-- A closed-loop longitudinal model of the 747 in the speed-on-pitch modes (VNAV SPD, FLCH SPD, TO/GA) for the tests
-- (not a test itself: the suites load it with dofile from the repository root).
--
-- Production code in its own namespace as XTLua runs it (its own globals, X-Plane's datarefs shared): the
-- hydraulics' AFDS pitch director and pitch loop (ap_pitch_assist: ap_director_pitch, its 10-sample mean
-- ap_director_pitch_integral, pid.lua's PID with hydraulicsmodel.lua's gains, the ratio moved by
-- B747_interpolate_value, doTrim; B747.19.xt.hydraulics_override.lua). The elevator surface follows the ratio a frame
-- later as pressure_output moves it (B747_interpolate_value over -22..17 deg in 0.75 s), against X-Plane's pitch
-- dynamics (approach_model's form):
--   dq/dt = s^2 (a0 + alpha x alpha + elevator x elevator + trim x trim) + q x s q,  s = IAS / 150 kt  (deg, deg/s)
-- with M.CLEAN_PITCH flaps up (output-error fit, the recorded F/D replayed through the loop at 25 fps: p35-line1's
-- climb resumption and acceleration at 8,950-12,000 ft, 250-290 kt, 2026-10-20: rms 0.036 deg; the fit at FL230 and
-- 288-316 kt gives about the same, rms 0.010) and approach_model's M.PITCH_DYNAMICS with the flaps out.
-- The aircraft: a point mass, the ISA, the IAS as the EAS; flaps up the lift and drag by Mach band fitted to the kit's
-- recordings (X-Plane's aero body forces, p35-line1 and p34-L1, 2026-10-20: CL rms 0.002-0.007), with the flaps out
-- approach_model's polar. The thrust is the scenario's (o.thrust: N an engine, e.g. a recording's), or M.thrust_n of
-- a throttle (fitted: (55.8 + 112.5 throttle) delta^0.6 (1 + 0.2 M) kN an engine, rms 5.2 kN) after o.spool_s of lag.
-- The VSI is 1 s behind the vertical speed; the elevation (sim/flightmodel/position/elevation) has no lag.
local AM = dofile("tests/approach_model.lua")
local M = {}

local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local G, KT, FT, S = 9.80665, 0.514444, 0.3048, 541.2
M.KT, M.FT = KT, FT

M.CLEAN_PITCH = {a0 = 2.5978, alpha = -0.2285, elevator = -0.1450, trim = 5.5112, q = -0.3287}

-- CL = cl0 + cla alpha (deg), CD = cd0 + k CL^2 by Mach band (the band's middle)
local CLEAN = {
    {0.375, 0.2194, 0.0634, 0.02211, 0.0681},
    {0.50, 0.2317, 0.0635, 0.02292, 0.0626},
    {0.60, 0.2376, 0.0679, 0.02367, 0.0564},
    {0.685, 0.2483, 0.0747, 0.02361, 0.0555},
    {0.75, 0.2640, 0.0758, 0.02314, 0.0577},
    {0.80, 0.2721, 0.0789, 0.02521, 0.0500},
    {0.84, 0.2710, 0.0790, 0.02030, 0.0770}}

local function clean_polar(mach)
    if mach <= CLEAN[1][1] then return {CLEAN[1][2], CLEAN[1][3], CLEAN[1][4], CLEAN[1][5]} end
    for i = 2, #CLEAN do
        if mach <= CLEAN[i][1] then
            local a, b = CLEAN[i - 1], CLEAN[i]
            local f = (mach - a[1]) / (b[1] - a[1])
            return {a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f, a[5] + (b[5] - a[5]) * f}
        end
    end
    local z = CLEAN[#CLEAN]
    return {z[2], z[3], z[4], z[5]}
end
M.clean_polar = clean_polar

-- ISA: temperature (K), pressure (Pa), density at a pressure altitude (ft)
function M.isa(alt_ft)
    if alt_ft < 36089 then
        local t = 288.15 - 0.0019812 * alt_ft
        local p = 101325 * (t / 288.15) ^ 5.2559
        return t, p, p / (287.05 * t)
    end
    local p = 22632 * math.exp(-(alt_ft - 36089) / 20806)
    return 216.65, p, p / (287.05 * 216.65)
end

-- thrust (N) an engine for a throttle at an altitude and Mach
function M.thrust_n(throttle, alt_ft, mach)
    local _, p = M.isa(alt_ft)
    return (55.8 + 112.5 * throttle) * 1000 * (p / 101325) ^ 0.6 * (1 + 0.2 * mach)
end

local sources = {}
local function read_source(path)
    if sources[path] == nil then
        local file = assert(io.open(path))
        sources[path] = file:read("*a")
        file:close()
    end
    return sources[path]
end
-- a production file's source from first_marker up to last_marker (the lines before it empty, for the file's line
-- numbers), with the experiment's patches ({file name, old text, new text}, the old text found once) applied
local function slice(path, first_marker, last_marker, patches)
    local source = read_source(path)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    local code = string.rep("\n", lines)..source:sub(first, last - 1)
    for _, patch in ipairs(patches or {}) do
        if path:sub(-#patch[1]) == patch[1] then
            local a, b = code:find(patch[2], 1, true)
            if a then
                code = code:sub(1, a - 1)..patch[3]..code:sub(b + 1)
                patch.applied = true
            end
        end
    end
    return code, "@"..path
end
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
local function run_in(ns, code, name)
    setfenv(assert(loadstring(code, name)), ns)()
end

-- the hydraulics' director and pitch loop in a namespace on datarefs; MODEL_init_director sets the director's state
-- to an attitude and an IAS as if it had been flying them
local function load_hydraulics(d, patches)
    local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
    local noop = function() end
    local hyd = namespace(d, {print = noop, B747_afds_controls = controls, debug_flight_directors = 0,
        lastTrimmed = 0, doCompute = 1})
    run_in(hyd, slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_rescale(",
        patches))
    run_in(hyd, slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on",
        patches))
    run_in(hyd, read_source(HYD.."pid.lua"), "@"..HYD.."pid.lua")
    local director, name = slice(HYD.."B747.19.xt.hydraulics_override.lua", "local director_pitchRecord={}",
        "local previous_simDR_AHARS_roll_heading_deg_pilot=0", patches)
    run_in(hyd, director..[[

function MODEL_init_director(pitch, ias)
    -- the director's first call a frame after this one (its first call after more than 5 s only resets)
    previous_pitchTime=simDRTime-SIM_PERIOD
    last_simDR_AHARS_pitch_heading_deg_pilot=pitch
    last_simDR_ind_airspeed_kts_pilot=ias
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
function MODEL_toga_state()
    return togaSpeedState
end
]], name)
    for _, patch in ipairs(patches or {}) do
        assert(patch.applied, "patch not applied: "..patch[1]..": "..patch[2]:sub(1, 60))
    end
    return hyd, controls
end

-- Fly. o = {
--   alt_ft, ias_kt, vs_fpm (0), weight_kg, flaps (handle ratio, 0), pitch_mode (4 VNAV SPD, 8 FLCH, 1 TO/GA),
--   target_kt (the AFDS speed), mcp_alt_ft (the MCP altitude, 37000), capture_window_ft (B747DR_alt_capture_window),
--   thrust = function(t, m) N an engine at time t (s from the start), or throttle = function(t, m) with
--   M.thrust_n after spool_s (2.5) of lag; dynamics (M.CLEAN_PITCH flaps up, AM.PITCH_DYNAMICS out);
--   seconds (120), dt (1/34), patches (production text replacements for an experiment),
--   setup = function(m) before the first frame, frame = function(m, t) each frame before the director (scenario
--   changes: m.d's datarefs, m.target_kt ...)}.
-- Returns m = {track = samples every 0.25 s, d = datarefs, hyd, state}.
function M.fly(o)
    local dt = o.dt or 1 / 34
    local d = {}
    local hyd, controls = load_hydraulics(d, o.patches)
    local weight = (o.weight_kg or 230000) * G
    local mass = weight / G
    local flaps = o.flaps or 0
    local dyn = o.dynamics or (flaps > 0 and AM.PITCH_DYNAMICS or M.CLEAN_PITCH)

    local state = {h = o.alt_ft, flap = flaps}
    local _, _, rho = M.isa(state.h)
    state.V = o.ias_kt * KT * math.sqrt(1.225 / rho)
    state.gamma = math.asin(math.max(-0.3, math.min(0.3, (o.vs_fpm or 0) * FT / 60 / state.V)))
    local function aero(mach)
        if state.flap > 0 then return AM.polar(state.flap) end
        return clean_polar(mach)
    end
    do
        local t = M.isa(state.h)
        local mach = state.V / math.sqrt(1.4 * 287.05 * t)
        local p = aero(mach)
        local q = 0.5 * rho * state.V ^ 2
        local alpha = (weight * math.cos(state.gamma) / (q * S) - p[1]) / p[2]
        state.theta = alpha + math.deg(state.gamma)
    end
    state.q, state.elevator, state.last_ratio = 0, 0, 0
    state.vsi = state.V * math.sin(state.gamma) / FT * 60
    state.thrust = o.thrust and o.thrust(0, {state = state}) or nil

    local values = {
        simDRTime = 1000, SIM_PERIOD = dt,
        simDR_autopilot_servos_on = 1, B747DR_switching_servos_on = -100, B747DR_ap_autoland = 0,
        B744DR_autolandPitch = 0, B747DR_ap_FMA_active_pitch_mode = o.pitch_mode or 4,
        B747DR_ap_AFDS_mode_box_status_pilot = 0, B747DR_ap_AFDS_mode_box_status_copilot = 0,
        B747DR_sim_pitch_ratio = 0, B747DR_custom_pitch_ratio = 0, simDR_electric_trim = 0,
        simDR_autopilot_airspeed_kts = o.target_kt or o.ias_kt, simDR_autopilot_airspeed_is_mach = 0,
        simDR_autopilot_altitude_ft = o.mcp_alt_ft or 37000, B747DR_autopilot_altitude_ft = o.mcp_alt_ft or 37000,
        B747DR_autopilot_altitude_ft_pfd = o.mcp_alt_ft or 37000,
        simDR_autopilot_hold_altitude_ft = o.mcp_alt_ft or 37000, B747DR_alt_capture_window = o.capture_window_ft or 300,
        simDR_autopilot_alt_hold_status = 0, simDR_autopilot_vs_status = 0,
        simDR_autopilot_flch_status = (o.pitch_mode == 8) and 2 or 0, simDR_autopilot_vs_fpm = 0,
        simDR_flight_director_pitch = 0, B747DR_flight_director_pitch = 0, simDR_autopilot_TOGA_pitch_deg = 8,
        B747DR_autopilot_TOGA_status = 0, B747DR_ap_flightPhase = 1, B747DR_ap_inVNAVdescent = 0,
        B747DR_airspeed_Vmc = o.vmc_kt or 150, B747DR_airspeed_Vmax = o.vmax_kt or 365,
        B747DR_flap_lever_detent = 0, simDR_glideslope1 = 3, simDR_hsi_vdef_dots_pilot = 0,
        simDR_AHARS_roll_heading_deg_pilot = 0, simDR_touchGround = 0}
    for key, value in pairs(values) do d[key] = value end
    local source = read_source(HYD.."B747.19.xt.hydraulicsmodel.lua")
    for _, key in ipairs({"PL", "PH", "D"}) do
        d["B747DR_pidPitch"..key] = assert(tonumber(source:match("\n%s*B747DR_pidPitch"..key.."%s*=%s*([%d%.]+)")))
    end
    d.simDR_elevator_trim = -(dyn.a0 + dyn.alpha * (state.theta - math.deg(state.gamma))) / dyn.trim
    hyd.MODEL_init_director(state.theta, o.ias_kt)

    local track = {}
    local m = {track = track, d = d, hyd = hyd, controls = controls, state = state, target_kt = o.target_kt or o.ias_kt}
    if o.setup then o.setup(m) end
    local t0 = d.simDRTime
    local next_sample = 0
    local seconds = o.seconds or 120
    local throttle = 0
    while d.simDRTime - t0 < seconds do
        local t = d.simDRTime - t0
        local temp, _, rho_now = M.isa(state.h)
        local mach = state.V / math.sqrt(1.4 * 287.05 * temp)
        local ias = state.V * math.sqrt(rho_now / 1.225) / KT
        local vs = state.V * math.sin(state.gamma) / FT * 60
        state.vsi = state.vsi + (vs - state.vsi) * math.min(1, dt / 1.0)
        local alpha = state.theta - math.deg(state.gamma)

        d.simDR_pressureAlt1, d.simDR_radarAlt1 = state.h, state.h
        d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot = ias, ias
        d.simDR_vvi_fpm_pilot = state.vsi
        d.simDR_elevation = state.h * FT
        d.simDR_local_vy = state.V * math.sin(state.gamma)
        d.simDR_groundspeed = state.V * math.cos(state.gamma)
        d.simDR_TAS_mps, d.simDR_alpha_deg = state.V, alpha
        d.simDR_AHARS_pitch_heading_deg_pilot = state.theta
        d.simDR_pitch_rate = state.q
        d.simDR_airspeed_mach = mach
        d.B747DR_flap_ratio, d.simDR_flap_ratio_control = state.flap, state.flap
        d.simDR_autopilot_airspeed_kts = m.target_kt
        if o.frame then o.frame(m, t) end

        local ratio = hyd.ap_pitch_assist()
        d.B747DR_sim_pitch_ratio, d.B747DR_custom_pitch_ratio = ratio, ratio
        local fd = d.B747DR_flight_director_pitch

        -- the thrust an engine
        local thrust
        if o.thrust then
            thrust = o.thrust(t, m)
        else
            throttle = o.throttle(t, m)
            local want = M.thrust_n(throttle, state.h, mach)
            state.thrust = (state.thrust or want) + (want - (state.thrust or want)) * math.min(1, dt / (o.spool_s or 2.5))
            thrust = state.thrust
        end

        -- the pitch: pressure_output moves the surface towards the last frame's ratio
        state.elevator = hyd.B747_interpolate_value(state.elevator, AM.elevator_deg(state.last_ratio), -22, 17, 0.75)
        state.last_ratio = ratio
        local s = ias / 150
        local qdot = s * s * (dyn.a0 + dyn.alpha * alpha + dyn.elevator * state.elevator + dyn.trim * d.simDR_elevator_trim)
            + dyn.q * s * state.q
        state.q = state.q + qdot * dt
        state.theta = state.theta + state.q * dt
        alpha = state.theta - math.deg(state.gamma)

        -- the point mass
        local p = aero(mach)
        local q = 0.5 * rho_now * state.V ^ 2
        local cl = p[1] + p[2] * alpha
        local cd = p[3] + p[4] * cl * cl
        local a = math.rad(alpha)
        local total = 4 * thrust
        local vdot = (total * math.cos(a) - q * S * cd - weight * math.sin(state.gamma)) / mass
        local gdot = (q * S * cl + total * math.sin(a) - weight * math.cos(state.gamma)) / (mass * state.V)
        state.V = state.V + vdot * dt
        state.gamma = state.gamma + gdot * dt
        state.h = state.h + state.V * math.sin(state.gamma) / FT * dt

        if t >= next_sample then
            next_sample = t + 0.25
            local raw = hyd.MODEL_director_state().raw
            track[#track + 1] = {t = t, alt = state.h, ias = ias, target = m.target_kt, vs = vs, vsi = state.vsi,
                theta = state.theta, fd = fd, raw = raw, alpha = alpha, gamma = math.deg(state.gamma),
                thrust = thrust, throttle = throttle, q = state.q, elevator = state.elevator,
                trim = d.simDR_elevator_trim, mode = d.B747DR_ap_FMA_active_pitch_mode, mach = mach,
                nz = gdot * state.V / G}
        end
        d.simDRTime = d.simDRTime + dt
    end
    return m
end

-- The track's sample nearest a time.
function M.at(m, t)
    local best, diff
    for _, p in ipairs(m.track) do
        if diff == nil or math.abs(p.t - t) < diff then best, diff = p, math.abs(p.t - t) end
    end
    return best
end

-- Summary of a track from t0 to t1 (the end when nil): the IAS's peak above and below the target (kt), the pitch
-- reversals of the F/D (direction changes of more than 0.2 deg: the F/D 0.2 deg below its highest since it last turned
-- up, or above its lowest since it last turned down; the first move of 0.2 deg sets the direction), the largest |nz|
-- increment (g) and pitch rate (deg/s).
function M.summary(m, t0, t1)
    local over, under, nz, rate = -math.huge, math.huge, 0, 0
    local reversals, dir, high, low = 0, 0, nil, nil
    for _, p in ipairs(m.track) do
        if p.t >= (t0 or 0) and p.t <= (t1 or math.huge) then
            over = math.max(over, p.ias - p.target)
            under = math.min(under, p.ias - p.target)
            nz = math.max(nz, math.abs(p.nz))
            rate = math.max(rate, math.abs(p.q))
            if high == nil then
                high, low = p.fd, p.fd
            else
                high, low = math.max(high, p.fd), math.min(low, p.fd)
                if dir >= 0 and p.fd < high - 0.2 then
                    if dir > 0 then reversals = reversals + 1 end
                    dir, low = -1, p.fd
                elseif dir <= 0 and p.fd > low + 0.2 then
                    if dir < 0 then reversals = reversals + 1 end
                    dir, high = 1, p.fd
                end
            end
        end
    end
    return {over = over, under = under, nz = nz, rate = rate, reversals = reversals}
end

return M
