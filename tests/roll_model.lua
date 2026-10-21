-- A closed-loop roll model of the 747's autopilot for the tests (not a test itself: the suites load it with dofile
-- from the repository root).
--
-- Production code, in the hydraulics script's namespace as XTLua runs it (its own globals, X-Plane's datarefs
-- shared): the director's roll filter (ap_director_roll, ap_director_roll_integral with adaptive_roll_filter), the
-- roll PID and its output's timing (ap_roll_assist, roll_output_response_sec, B747.19.xt.hydraulics_override.lua)
-- with the PID's gains as hydraulicsmodel.lua sets them, the PID computed when flight_controls_override's
-- computeRate (0.0333 s) has passed, as there; the roll surfaces as pressure_output moves them, towards the roll
-- ratio of `pre` frames before (the control overrides' rows sim_roll_ratio -> custom_roll_ratio -> the cables):
-- the inboard ailerons by B747_interpolate_value over +-20 deg in 0.75 s (53 deg/s, a tenth of the way a frame
-- within a step), reaching the flight model a frame later, the roll spoilers (45 deg at full ratio) by
-- B747_animate_value (a tenth of the way a frame), written straight to the flight model; the outboard ailerons
-- are locked out above 238 KIAS. The tenth of the way a frame is a lag of about 10 frames (0.38 s at 25 fps,
-- 0.53 s at 18 fps): the rudder's 0.40-0.45 s behind the yaw dampers' output in the recordings is the same.
-- The aircraft: roll only, the roll rate a first order lag of the surfaces' steady roll rate:
--   dp/dt = (gain x ((1 - share) x aileron / 20 deg + share x spoiler / 45 deg) - p) / tau,  dphi/dt = p
-- with gain (deg/s at full deflection), share (the spoilers' part of it) and tau (s), and an optional constant
-- disturbing roll acceleration (deg/s^2) for a time.
local M = {}

local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
M.HYD = HYD

local function read_source(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local function slice(path, first_marker, last_marker)
    local source = read_source(path)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1), "@"..path
end

local function is_dataref(key)
    return type(key) == "string" and (key:find("^simDR") ~= nil or key:find("^B74[47]DR") ~= nil
        or key == "SIM_PERIOD" or key == "simDRTime" or key == "doCompute")
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
    local chunk = assert(loadstring(code, name))
    setfenv(chunk, ns)
    chunk()
end

-- Text replacements in the production code for an experiment: {file name, old text, new text}.
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

-- The hydraulics' roll channel on a datarefs table; returns its namespace.
function M.load(datarefs, patches)
    active_patches = patches or {}
    local controls_code = patched(read_source(HYD.."B747.19.xt.hydraulics_afds_helpers.lua"),
        HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
    local controls = assert(loadstring(controls_code, "@"..HYD.."B747.19.xt.hydraulics_afds_helpers.lua"))()
    local hyd = namespace(datarefs, {print = function() end, B747_afds_controls = controls,
        debug_flight_directors = 0})
    local function run_slice(path, a, b)
        local code, name = slice(path, a, b)
        run_in(hyd, patched(code, path), name)
    end
    run_in(hyd, read_source(HYD.."pid.lua"), "@"..HYD.."pid.lua")
    run_slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_rescale(")
    run_slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")
    -- the director and the roll assist in one chunk, as in the file (ap_roll_assist calls the director's local
    -- B747_roll_approach_protected)
    local director = slice(HYD.."B747.19.xt.hydraulics_override.lua", "local director_pitchRecord={}",
        "local trimrate=25")
    local assist = slice(HYD.."B747.19.xt.hydraulics_override.lua",
        "local previous_simDR_AHARS_roll_heading_deg_pilot=0", "function flight_controls_override()")
    local path = HYD.."B747.19.xt.hydraulics_override.lua"
    run_in(hyd, patched(director:gsub("\n+$", "").."\n"..assist:gsub("^\n+", ""), path), "@"..path)
    for _, patch in ipairs(active_patches) do
        assert(patch.applied, "patch not applied: "..patch[1]..": "..patch[2]:sub(1, 60))
    end
    active_patches = {}
    return hyd
end

-- hydraulicsmodel.lua's roll gains
local GAINS = {}
do
    local source = read_source(HYD.."B747.19.xt.hydraulicsmodel.lua")
    for _, key in ipairs({"P", "I", "DL", "DH"}) do
        GAINS[key] = assert(tonumber(source:match("\n%s*B747DR_pidRoll"..key.."%s*=%s*([%d%.]+)")), key)
    end
end
M.GAINS = GAINS

-- Fly: o = {gain, tau, share (0), pre (1), fps (25), ias_kt, tas_kt, mcp_alt_ft, seconds, target(t) -> the AP's roll
-- target (deg), phi0, p0, disturb = {t0, t1, accel}, patches, datarefs}. Returns the track {t, phi, p, ratio,
-- aileron, spoiler, target, filtered} every sample_s (0.1 s).
function M.fly(o)
    local d = {}
    local hyd = M.load(d, o.patches)
    local fps = o.fps or 25
    local dt = 1 / fps
    local values = {
        simDRTime = 1000, SIM_PERIOD = dt, doCompute = 0,
        simDR_autopilot_servos_on = 1, B747DR_ap_FMA_active_roll_mode = o.roll_mode or 2,
        B747DR_ap_ATT = 0, simDR_autopilot_nav_status = 0, B747DR_autopilot_nav_status = 0, B747DR_ap_autoland = 0,
        B747DR_ap_target_roll = 0, B747DR_flight_director_roll = 0, B747DR_sim_roll_ratio = 0,
        B747DR_pidRollP = GAINS.P, B747DR_pidRollI = GAINS.I, B747DR_pidRollDL = GAINS.DL, B747DR_pidRollDH = GAINS.DH,
        B747DR_pidRollD = 0, B747DR_autopilot_altitude_ft_pfd = o.mcp_alt_ft or 37000,
        simDR_AHARS_roll_heading_deg_pilot = o.phi0 or 0, simDR_ias_pilot = o.ias_kt or 300,
        simDR_ind_airspeed_kts_pilot = o.ias_kt or 300, simDR_TAS_mps = (o.tas_kt or 480) * 0.514444,
        B747DR_ap_FMA_active_pitch_mode = 0, B747DR_afds_armed_roll_mode = 0, B747DR_afds_armed_pitch_mode = 0,
    }
    for k, v in pairs(values) do d[k] = v end
    for k, v in pairs(o.datarefs or {}) do d[k] = v end
    local share, pre = o.share or 0, o.pre or 1
    local phi, p = o.phi0 or 0, o.p0 or 0
    local aileron, spoiler, aileron_seen = 0, 0, 0
    local ratios = {}
    local last_compute = -1
    local track, next_sample = {}, 0
    local t, n = 0, 0
    while t < (o.seconds or 30) do
        n = n + 1
        -- the flight model's frame, with the ailerons pressure_output moved a frame before and the spoilers it wrote
        local accel = 0
        if o.disturb and t >= o.disturb[1] and t < o.disturb[2] then accel = o.disturb[3] end
        p = p + ((o.gain * ((1 - share) * aileron_seen / 20 + share * spoiler / 45) - p) / o.tau + accel) * dt
        phi = phi + p * dt
        -- after_physics: pressure_output on the cables (the roll ratio of pre frames before), then
        -- flight_controls_override with the PID when computeRate has passed
        d.simDRTime = 1000 + t
        d.B747DR_ap_target_roll = o.target and o.target(t) or 0
        local cable = ratios[n - pre] or 0
        aileron_seen = aileron
        aileron = hyd.B747_interpolate_value(aileron, 20 * cable, -20, 20, 0.75)
        spoiler = hyd.B747_animate_value(spoiler, 45 * cable, -100, 100, 10)
        if d.simDRTime - last_compute > 0.0333 then
            d.doCompute = 1
            last_compute = d.simDRTime
        else
            d.doCompute = 0
        end
        d.simDR_AHARS_roll_heading_deg_pilot = phi
        d.simDR_roll_rate = p
        d.B747DR_sim_roll_ratio = hyd.ap_roll_assist()
        ratios[n] = d.B747DR_sim_roll_ratio
        if t >= next_sample then
            next_sample = next_sample + (o.sample_s or 0.1)
            track[#track + 1] = {t = t, phi = phi, p = p, ratio = d.B747DR_sim_roll_ratio, aileron = aileron,
                spoiler = spoiler, target = d.B747DR_ap_target_roll, filtered = d.B747DR_flight_director_roll}
        end
        t = t + dt
    end
    return track
end

-- The largest |bank| and |roll rate| from t0 on, and the period from the bank's zero crossings there.
function M.summary(track, t0)
    local max_phi, max_p, crossings, last_sign, first_cross, last_cross = 0, 0, 0, 0, nil, nil
    for _, s in ipairs(track) do
        if s.t >= (t0 or 0) then
            max_phi = math.max(max_phi, math.abs(s.phi))
            max_p = math.max(max_p, math.abs(s.p))
            local sign = s.phi > 0.05 and 1 or (s.phi < -0.05 and -1 or 0)
            if sign ~= 0 then
                if last_sign ~= 0 and sign ~= last_sign then
                    crossings = crossings + 1
                    first_cross = first_cross or s.t
                    last_cross = s.t
                end
                last_sign = sign
            end
        end
    end
    local period = (crossings >= 3) and 2 * (last_cross - first_cross) / (crossings - 1) or nil
    return {max_phi = max_phi, max_p = max_p, crossings = crossings, period = period}
end

return M
