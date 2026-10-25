-- 747-400 GPWS without X-Plane (5-1 step 4b): the GPWC's modes 1-7 (no
-- look-ahead terrain, no terrain clearance floor: no terrain data base), the
-- GND PROX panel, the voices one at a time, the altitude callouts of the 405,
-- the lights and the EICAS messages. Logic and sources:
-- docs/overhaul/notes/ATA-34.md §3.8, §4.9, §14 (ATA34_2 34-46 p.122-210;
-- FCOM p.1531-1539, p.1555, p.1571-1583, p.1604-1605).
--
--   local G = B747_gpws_model               -- in XTLua, after dofile
--   local G = dofile(".../B747.34.gpws_model.lua")  -- in the tests
--   local s = G.new()
--   local inp = G.inputs()                  -- fill it every frame
--   local out = G.update(s, inp, dt)        -- the same table every frame
--
-- The voices follow the FCOM (405): mode 3 DON'T SINK, mode 4 TOO LOW GEAR,
-- TOO LOW FLAPS, TOO LOW TERRAIN (the E&M's older GPWC says SINK RATE and
-- TERRAIN). The .snd plays out.voice (repeated while it lasts) and
-- out.callout (once each time it changes).

local M = setmetatable({}, {})
B747_gpws_model = M

-- voices, highest priority first in M.PRIORITY. FCOM p.1582-1583: the
-- immediate windshear alert inhibits all other GPWS alerts, warning voices
-- inhibit new caution voices; the order among the cautions is an estimate
-- (the sources give no full table: ATA34_2 p.124 names only mode 7 first).
M.V_NONE, M.V_SINK_RATE, M.V_PULL_UP, M.V_TERRAIN, M.V_DONT_SINK = 0, 1, 2, 3, 4
M.V_TOO_LOW_GEAR, M.V_TOO_LOW_FLAPS, M.V_TOO_LOW_TERRAIN = 5, 6, 7
M.V_GLIDE_SLOPE, M.V_BANK_ANGLE, M.V_WINDSHEAR = 8, 9, 10
M.PRIORITY = {M.V_WINDSHEAR, M.V_PULL_UP, M.V_TERRAIN, M.V_TOO_LOW_TERRAIN, M.V_TOO_LOW_GEAR,
    M.V_TOO_LOW_FLAPS, M.V_SINK_RATE, M.V_DONT_SINK, M.V_GLIDE_SLOPE, M.V_BANK_ANGLE}

-- callouts (mode 6): the radio altitudes of the 405 (FCOM p.1578), and
-- APPROACHING MINIMUMS, MINIMUMS at the captain's minimums + 80 ft and at
-- them (FCOM p.1578). out.callout holds the code CALLOUT_HOLD_S.
M.CALLOUTS = {2500, 1000, 500, 100, 50, 40, 30, 20, 10}
M.C_APPROACHING_MINIMUMS, M.C_MINIMUMS = 1, 2
M.CALLOUT_HOLD_S = 0.3
M.APPROACHING_MINIMUMS_FT = 80
-- each callout once; again after climbing above 1,000 ft (p.180, p.183).
-- estimates: 100 ft above max(1,000 ft, the callout) so that flying level
-- near 1,000 or 2,500 ft does not repeat it; the minimums ones 100 ft above
-- the minimums (the source only says "above 1,000 ft")
M.CALLOUT_REARM_FT = 100

-- the air/ground logic (p.127, p.205-206): to the air with the air/ground
-- relay in air (or CAS 90 kt and up) and RA 5 ft and up; to the ground with
-- CAS 60 kt and below and RA 1 ft and below. No alert on the ground.
M.AIR_RA_FT, M.AIR_CAS_KT, M.GND_CAS_KT, M.GND_RA_FT = 5, 90, 60, 1

-- mode 1, excessive descent rate (p.144): 30-2,450 ft; the alert from
-- 998 fpm at 30 ft to 5,007 fpm at 2,450 ft. The warning line is an
-- estimate (no figures: "follows when the descent rate becomes severe",
-- FCOM p.1576): 1,710 fpm at 30 ft to 7,125 fpm at 2,450 ft. Above the
-- glide slope both lines move up to 300 fpm (2 dots above).
M.M1_LOW_FT, M.M1_HIGH_FT = 30, 2450
M.M1_ALERT = {998, 5007}
M.M1_WARN = {1710, 7125}
M.GS_RELAX_FPM_PER_DOT, M.GS_RELAX_MAX_DOTS = 150, 2

-- mode 2, excessive closure rate (closure = the radio altitude's rate, p.151,
-- p.154, p.157). The curve, closure fpm against ft: (2,253, 200), (3,000,
-- 789), (5,733, 1,650), (9,800, 2,450) from the sources; (2,038, 30) carries
-- the 2B line down to the 30 ft floor, and 2A on the same curve below 789 ft,
-- are estimates. 2A tops out at 1,650 ft at 220 kt and below, 2,450 ft at
-- 310 kt and up (linear between: estimate); 2B at 789 ft, its floor with the
-- flaps down 200 ft at 400 fpm descent and less to 600 ft at 1,000 fpm and
-- more, with the flaps up 30 ft.
M.M2_CURVE = {{2038, 30}, {2253, 200}, {3000, 789}, {5733, 1650}, {9800, 2450}}
M.M2A_TOP = {220, 1650, 310, 2450}
M.M2B_TOP_FT = 789
M.M2B_FLOOR = {400, 200, 1000, 600}
M.M2_LOW_FT = 30
M.M2_CLOSURE_TAU_S = 1.0     -- estimate: the closure rate is the RA's rate, smoothed
-- the warning follows TERRAIN, TERRAIN while the closure goes on: 1.6 s in
-- the figure of p.153; with the gear and flaps down (2B) only TERRAIN
-- repeated (p.154). The TERRAIN voice lasts TERRAIN_TWICE_S before PULL UP
-- (estimate: the sound repeats every 2 s, so it says TERRAIN twice)
M.M2_WARN_AFTER_S = 1.6
M.TERRAIN_TWICE_S = 2.8
-- the altitude gain function (2A, gear up, after more than 3 s of warning):
-- GND PROX light without voice until 300 ft gained, 45 s or gear down (p.152)
M.M2_GAIN_AFTER_S, M.M2_GAIN_FT, M.M2_GAIN_MAX_S = 3, 300, 45

-- mode 3, altitude loss after takeoff or go-around, not in landing
-- configuration (p.161-166, FCOM p.1576: DON'T SINK). Armed at lift-off and
-- below 245 ft in landing configuration (or at 30 ft) on approach; mode 4
-- takes over above about 700 ft at 190 kt and below to about 1,350 ft at
-- 250 kt and above (p.163; linear between: estimate). The loss allowed is
-- roughly 10 % of the radio altitude (p.161); estimate: not less than 10 ft.
M.M3_TOP = {190, 700, 250, 1350}
M.M3_LOW_FT = 30
M.M3_LOSS_FRACTION, M.M3_LOSS_MIN_FT = 0.10, 10

-- mode 4, terrain clearance not in landing configuration (p.168-172, FCOM
-- p.1577): 4A gear up 500 ft to 190 kt (TOO LOW GEAR), 4B gear down 245 ft to
-- 159 kt (TOO LOW FLAPS); faster, up to 1,000 ft at 250 kt (TOO LOW
-- TERRAIN); 4A with the flaps down 500 ft at all speeds; floor 30 ft. After
-- an excessive closure rate the top is 800 ft for 60 s (taken as a mode 2
-- alert: estimate).
M.M4A = {190, 500}
M.M4B = {159, 245}
M.M4_FAST = {250, 1000}
M.M4_LOW_FT = 30
M.M4_AFTER_M2_FT, M.M4_AFTER_M2_S = 800, 60

-- mode 5, below the glide slope (p.174-178): armed below 1,000 ft with the
-- gear down and the localizer within 2 dots before 500 ft; 1,000-30 ft;
-- more than 1.3 dots (half volume), below 300 ft more than 2 dots (normal
-- volume: the sound cannot change its volume, so both sound the same).
-- G/S INHB below 1,000 ft inhibits it until below 30 ft or above 1,000 ft.
-- No alert on a back course (runway heading and track more than 90 deg apart).
M.M5_TOP_FT, M.M5_ARM_LOW_FT, M.M5_LOW_FT = 1000, 500, 30
M.M5_LOC_DOTS, M.M5_SOFT_DOTS, M.M5_HARD_DOTS, M.M5_HARD_FT = 2, 1.3, 2, 300

-- bank angle (FCOM p.1577, 405): 35, 40 and 45 deg; at low altitude down to
-- 10 deg. The low-altitude line is the E&M's (10 deg at 30 ft to 40 deg at
-- 150 ft, p.184), here not above the first step. Estimates: each step again
-- after the bank falls 5 deg below it; the voice lasts BANK_VOICE_S (BANK
-- ANGLE twice with the sound's 2 s repetition).
M.BANK_STEPS = {35, 40, 45}
M.BANK_LOW = {30, 10, 150, 40}
M.BANK_REARM_DEG = 5
M.BANK_VOICE_S = 2.8

-- mode 7, reactive windshear (p.186-190, FCOM p.1581): below 1,500 ft from
-- rotation (estimate: in the air), at least 5 s; it inhibits all other GPWS
-- alerts. The windshear itself is X-Plane's reactive detection (estimate:
-- the GPWC's own thresholds are not given); the stick shaker margin that
-- also keeps it on is not made (no such AOA here).
M.M7_TOP_FT, M.M7_MIN_S = 1500, 5

-- GND PROX SYS with FLAP OVRD above 250 kt or GEAR OVRD above 290 kt for more
-- than 60 s (FCOM p.1538)
M.FLAP_OVRD_KT, M.GEAR_OVRD_KT, M.OVRD_SPEED_S = 250, 290, 60

function M.inputs()
    return {
        power = true,               -- the GPWC: AC bus 3
        ra = 0, ra_valid = false,   -- ft, the GPWC's radio altitude (above 2,500 ft: just large)
        vs = 0, vs_valid = false,   -- fpm, inertial vertical speed (L IRU), else baro rate (L ADC)
        alt = 0, alt_valid = false, -- ft, inertial or baro altitude
        cas = 0, cas_valid = false, -- kt (L or R ADC)
        gs_dev = 0, gs_valid = false,   -- dots, + = below the glide slope (L ILS)
        loc_dev = 0, loc_valid = false, -- dots
        back_course = false,        -- runway heading and track more than 90 deg apart
        roll = 0, roll_valid = false,   -- deg (L IRU)
        gear_down = false,          -- gear lever down
        flaps_landing = false,      -- flaps 25 or 30 (FCU)
        relay_air = false,          -- the air/ground relay in air
        gs_inhb_push = false,       -- G/S INHB pushed this frame
        flap_ovrd = false, gear_ovrd = false, terr_ovrd = false,
        windshear = false,          -- X-Plane's reactive windshear
        mins_ref = 0, mins = 0,     -- the captain's minimums: the altitude it compares and the setting
        callout_off = {},           -- [code] = true: the CDU's sound option turns it off
        gps_valid = true,           -- any GPS navigating (TERR POS)
    }
end

function M.new()
    local s = {
        t = 0, in_air = false, started = false,
        prev_ra = nil, closure = 0,
        m2_on = false, m2_since = 0, m2_warn = false, m2_warn_since = nil,
        m2_gain = false, m2_gain_alt = 0, m2_gain_since = 0, m2_last_alert = nil,
        m3_armed = false, m3_max_alt = 0,
        m5_armed = false, gs_inhibited = false,
        armed = {}, mins_armed = {false, false},
        bank_step_done = {false, false, false}, bank_until = 0,
        m7_on = false, m7_since = 0,
        callout = 0, callout_until = 0, last_callout = 0,
        flap_ovrd_s = 0, gear_ovrd_s = 0,
    }
    for _, v in ipairs(M.CALLOUTS) do s.armed[v] = false end
    s.out = {
        voice = M.V_NONE, callout = 0,
        last_callout = 0,           -- the last callout, held (for the tests)
        gnd_prox_light = false, pull_up = false, windshear = false,
        warning = false,            -- PULL UP or WINDSHEAR: master WARNING, TCAS to TA ONLY
        alert = false,              -- any GPWS alert or warning (to TCAS: inhibits advisories)
        in_air = false,
        -- the modes, for the tests
        m1 = 0, m2 = 0, m3 = false, m4 = M.V_NONE, m5 = false, m7 = false, m3_armed = false,
        gs_inhibited = false,
        -- EICAS advisories
        msg_alt_callouts = false, msg_gnd_prox_sys = false, msg_terr_ovrd = false,
        msg_terr_pos = false, msg_windshear_sys = false,
    }
    return s
end

-- y on the line through (x1, y1), (x2, y2), held at the ends
local function lerp(x, x1, y1, x2, y2)
    if x <= x1 then return y1 end
    if x >= x2 then return y2 end
    return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
end

-- the height the mode 2 curve reaches at a closure rate
local function m2_height(closure)
    local c = M.M2_CURVE
    if closure < c[1][1] then return -1 end
    for k = 2, #c do
        if closure <= c[k][1] then return lerp(closure, c[k - 1][1], c[k - 1][2], c[k][1], c[k][2]) end
    end
    return c[#c][2]
end

-- the air/ground logic
local function air_ground(s, inp)
    local ra = inp.ra_valid and inp.ra or 0
    local cas = inp.cas_valid and inp.cas or 0
    if not s.started then
        -- a flight started in the air
        s.started = true
        s.in_air = inp.relay_air and ra >= M.AIR_RA_FT
        return false
    end
    if not s.in_air then
        if (inp.relay_air or cas >= M.AIR_CAS_KT) and ra >= M.AIR_RA_FT then
            s.in_air = true
            return true                       -- lift-off
        end
    elseif cas <= M.GND_CAS_KT and ra <= M.GND_RA_FT then
        s.in_air = false
    end
    return false
end

function M.update(s, inp, dt)
    local out = s.out
    s.t = s.t + dt
    local t = s.t
    local liftoff = air_ground(s, inp)
    out.in_air = s.in_air

    local ra, vs = inp.ra, inp.vs
    local descent = -vs
    local gear_dn = inp.gear_down or inp.gear_ovrd          -- GEAR OVRD: gear down simulated
    local flaps_ld = inp.flaps_landing or inp.flap_ovrd     -- FLAP OVRD: flaps 25 simulated
    local landing = gear_dn and flaps_ld
    local on = inp.power and s.in_air and inp.ra_valid

    -- the closure rate from the radio altitude
    if inp.ra_valid and s.prev_ra and dt > 0 then
        local rate = (s.prev_ra - ra) / dt * 60
        local k = math.min(1, dt / M.M2_CLOSURE_TAU_S)
        s.closure = s.closure + (rate - s.closure) * k
    else
        s.closure = 0
    end
    local prev_ra = s.prev_ra
    s.prev_ra = inp.ra_valid and ra or nil

    -- G/S relax for modes 1 (above the glide slope)
    local relax = 0
    if inp.gs_valid and inp.gs_dev < 0 then
        relax = math.min(-inp.gs_dev, M.GS_RELAX_MAX_DOTS) * M.GS_RELAX_FPM_PER_DOT
    end

    -- mode 7: windshear
    local ws_enabled = inp.power and s.in_air and inp.ra_valid and ra < M.M7_TOP_FT and inp.roll_valid
    if ws_enabled and inp.windshear then
        if not s.m7_on then s.m7_on, s.m7_since = true, t end
    elseif s.m7_on and (t - s.m7_since >= M.M7_MIN_S or not inp.power) then
        s.m7_on = false
    end
    if not inp.power then s.m7_on = false end
    local ws = s.m7_on
    out.m7 = ws

    -- mode 1
    local m1 = 0
    if on and inp.vs_valid and ra >= M.M1_LOW_FT and ra <= M.M1_HIGH_FT then
        local a = lerp(ra, M.M1_LOW_FT, M.M1_ALERT[1], M.M1_HIGH_FT, M.M1_ALERT[2]) + relax
        local w = lerp(ra, M.M1_LOW_FT, M.M1_WARN[1], M.M1_HIGH_FT, M.M1_WARN[2]) + relax
        if descent >= w then m1 = 2 elseif descent >= a then m1 = 1 end
    end
    out.m1 = m1

    -- mode 2
    local in2 = false
    if on and ra >= M.M2_LOW_FT then
        local is2b = flaps_ld or (inp.gs_valid and math.abs(inp.gs_dev) <= 2)
        local top, floor
        if is2b then
            top = M.M2B_TOP_FT
            if flaps_ld then
                floor = lerp(inp.vs_valid and descent or 0, M.M2B_FLOOR[1], M.M2B_FLOOR[2], M.M2B_FLOOR[3], M.M2B_FLOOR[4])
            else
                floor = M.M2_LOW_FT
            end
        else
            top = inp.cas_valid and lerp(inp.cas, M.M2A_TOP[1], M.M2A_TOP[2], M.M2A_TOP[3], M.M2A_TOP[4]) or M.M2A_TOP[2]
            floor = M.M2_LOW_FT
        end
        in2 = ra <= top and ra >= floor and ra <= m2_height(s.closure)
    end
    if in2 then
        if not s.m2_on then s.m2_on, s.m2_since, s.m2_gain = true, t, false end
        s.m2_last_alert = t
        local warn = not landing and t - s.m2_since >= M.M2_WARN_AFTER_S
        if warn and not s.m2_warn then s.m2_warn_since = t end
        s.m2_warn = warn
    else
        if s.m2_on then
            -- out of the envelope: the altitude gain function after a long warning, gear up
            if s.m2_warn and s.m2_warn_since and t - s.m2_warn_since > M.M2_GAIN_AFTER_S and not gear_dn
                    and inp.alt_valid then
                s.m2_gain, s.m2_gain_alt, s.m2_gain_since = true, inp.alt, t
            end
        end
        s.m2_on, s.m2_warn, s.m2_warn_since = false, false, nil
    end
    if s.m2_gain and (not on or gear_dn or t - s.m2_gain_since >= M.M2_GAIN_MAX_S
            or not inp.alt_valid or inp.alt - s.m2_gain_alt >= M.M2_GAIN_FT) then
        s.m2_gain = false
    end
    -- 2: warning, 1: alert, 3: altitude gain (light only)
    out.m2 = s.m2_on and (s.m2_warn and 2 or 1) or (s.m2_gain and 3 or 0)

    -- modes 3 and 4: one or the other
    local m3_top = inp.cas_valid and lerp(inp.cas, M.M3_TOP[1], M.M3_TOP[2], M.M3_TOP[3], M.M3_TOP[4]) or M.M3_TOP[2]
    if not s.in_air then
        s.m3_armed = false
    elseif liftoff then
        s.m3_armed, s.m3_max_alt = true, inp.alt
    elseif s.m3_armed then
        if inp.ra_valid and ra > m3_top then s.m3_armed = false end
    elseif inp.ra_valid and prev_ra then
        -- on approach: through 245 ft in landing configuration, else at 30 ft
        if (landing and prev_ra >= M.M4B[2] and ra < M.M4B[2]) or (prev_ra >= M.M4_LOW_FT and ra < M.M4_LOW_FT) then
            s.m3_armed, s.m3_max_alt = true, inp.alt
        end
    end
    out.m3_armed = s.m3_armed
    -- the altitude lost counts from the highest point since the climb began
    -- (estimate: the reference starts again in landing configuration, so a
    -- go-around starts it at the go-around)
    if landing or not inp.alt_valid then s.m3_max_alt = inp.alt end
    if inp.alt > s.m3_max_alt then s.m3_max_alt = inp.alt end
    local m3 = false
    if on and s.m3_armed and not landing and inp.alt_valid and inp.vs_valid
            and ra >= M.M3_LOW_FT and ra <= m3_top and vs < 0 then
        local loss = s.m3_max_alt - inp.alt
        m3 = loss >= math.max(M.M3_LOSS_MIN_FT, M.M3_LOSS_FRACTION * ra)
    end
    out.m3 = m3

    local m4 = M.V_NONE
    if s.m2_last_alert and t - s.m2_last_alert > M.M4_AFTER_M2_S then s.m2_last_alert = nil end
    if on and not s.m3_armed and not landing and inp.cas_valid and ra >= M.M4_LOW_FT then
        local cas = inp.cas
        local slow, top, slow_voice
        if not gear_dn then
            slow, top, slow_voice = M.M4A[1], M.M4A[2], M.V_TOO_LOW_GEAR
        else
            slow, top, slow_voice = M.M4B[1], M.M4B[2], M.V_TOO_LOW_FLAPS
        end
        local limit, voice = top, slow_voice
        if not (not gear_dn and flaps_ld) and cas > slow then
            -- 4A with the flaps down stays at 500 ft
            limit = lerp(cas, slow, top, M.M4_FAST[1], M.M4_FAST[2])
            voice = M.V_TOO_LOW_TERRAIN
        end
        if s.m2_last_alert then limit = math.min(limit, M.M4_AFTER_M2_FT) end
        if ra < limit then m4 = voice end
    end
    out.m4 = m4

    -- mode 5
    if not inp.ra_valid or ra > M.M5_TOP_FT or ra < M.M5_LOW_FT or not gear_dn then s.m5_armed = false end
    if inp.ra_valid and ra <= M.M5_TOP_FT and ra >= M.M5_ARM_LOW_FT and gear_dn and inp.loc_valid
            and math.abs(inp.loc_dev) <= M.M5_LOC_DOTS then
        s.m5_armed = true
    end
    if inp.gs_inhb_push and inp.power and inp.ra_valid and ra < M.M5_TOP_FT then s.gs_inhibited = true end
    if not inp.ra_valid or ra < M.M5_LOW_FT or ra > M.M5_TOP_FT then s.gs_inhibited = false end
    out.gs_inhibited = s.gs_inhibited
    local m5 = on and s.m5_armed and not s.gs_inhibited and not inp.back_course and inp.gs_valid
        and ra >= M.M5_LOW_FT and ra <= M.M5_TOP_FT and inp.gs_dev > M.M5_SOFT_DOTS
    out.m5 = m5

    -- mode 6: the radio altitude callouts and minimums
    local new_callout = nil
    local m6 = inp.power and inp.ra_valid
    if m6 then
        for _, v in ipairs(M.CALLOUTS) do
            if ra > math.max(1000, v) + M.CALLOUT_REARM_FT then s.armed[v] = true end
            if s.armed[v] and prev_ra and prev_ra > v and ra <= v then
                s.armed[v] = false
                if s.in_air and not inp.callout_off[v] then new_callout = v end
            end
        end
        if inp.mins > 0 then
            local marks = {inp.mins + M.APPROACHING_MINIMUMS_FT, inp.mins}
            local codes = {M.C_APPROACHING_MINIMUMS, M.C_MINIMUMS}
            for k = 1, 2 do
                if inp.mins_ref > inp.mins + M.APPROACHING_MINIMUMS_FT + M.CALLOUT_REARM_FT then
                    s.mins_armed[k] = true
                end
                if s.mins_armed[k] and inp.mins_ref <= marks[k] then
                    s.mins_armed[k] = false
                    if s.in_air and not inp.callout_off[codes[k]] then new_callout = codes[k] end
                end
            end
        end
    end

    -- bank angle
    local roll = math.abs(inp.roll)
    if m6 and s.in_air and inp.roll_valid then
        local first = M.BANK_STEPS[1]
        if ra < M.BANK_LOW[3] then
            first = math.min(first, lerp(ra, M.BANK_LOW[1], M.BANK_LOW[2], M.BANK_LOW[3], M.BANK_LOW[4]))
        end
        local steps = {first, M.BANK_STEPS[2], M.BANK_STEPS[3]}
        for k = 1, 3 do
            if s.bank_step_done[k] and roll < steps[k] - M.BANK_REARM_DEG then s.bank_step_done[k] = false end
            if not s.bank_step_done[k] and roll > steps[k] then
                s.bank_step_done[k] = true
                s.bank_until = t + M.BANK_VOICE_S
            end
        end
    else
        s.bank_until = 0
    end

    -- lights
    local alert = m1 > 0 or s.m2_on or s.m2_gain or m3 or m4 ~= M.V_NONE or m5
    out.pull_up = not ws and (m1 == 2 or (s.m2_on and s.m2_warn))
    out.windshear = ws
    out.warning = out.pull_up or ws
    out.gnd_prox_light = not ws and alert
    out.alert = alert or ws

    -- the voice: each mode's request, the highest priority one
    local want = {}
    if ws then want[M.V_WINDSHEAR] = true end
    if not ws then
        if m1 == 2 then want[M.V_PULL_UP] = true elseif m1 == 1 then want[M.V_SINK_RATE] = true end
        if s.m2_on then
            if s.m2_warn and t - s.m2_since >= M.TERRAIN_TWICE_S then want[M.V_PULL_UP] = true
            else want[M.V_TERRAIN] = true end
        end
        if m3 then want[M.V_DONT_SINK] = true end
        if m4 ~= M.V_NONE then want[m4] = true end
        if m5 then want[M.V_GLIDE_SLOPE] = true end
        if t < s.bank_until then want[M.V_BANK_ANGLE] = true end
    end
    local voice = M.V_NONE
    for _, v in ipairs(M.PRIORITY) do
        if want[v] then voice = v; break end
    end
    out.voice = voice

    -- the callout: replaced by a newer one; none while a warning voice sounds
    if new_callout and voice ~= M.V_PULL_UP and voice ~= M.V_WINDSHEAR then
        s.callout, s.callout_until, s.last_callout = new_callout, t + M.CALLOUT_HOLD_S, new_callout
    end
    if t >= s.callout_until then s.callout = 0 end
    out.callout = s.callout
    out.last_callout = s.last_callout

    -- EICAS (FCOM p.1538, p.1604-1605)
    if inp.flap_ovrd and inp.cas_valid and inp.cas > M.FLAP_OVRD_KT then s.flap_ovrd_s = s.flap_ovrd_s + dt
    else s.flap_ovrd_s = 0 end
    if inp.gear_ovrd and inp.cas_valid and inp.cas > M.GEAR_OVRD_KT then s.gear_ovrd_s = s.gear_ovrd_s + dt
    else s.gear_ovrd_s = 0 end
    -- estimates: which lost inputs stop which alerts (FCOM p.1581 gives no list)
    out.msg_alt_callouts = not inp.power or not inp.ra_valid
    out.msg_gnd_prox_sys = not inp.power or not inp.ra_valid or not inp.vs_valid or not inp.cas_valid
        or s.flap_ovrd_s > M.OVRD_SPEED_S or s.gear_ovrd_s > M.OVRD_SPEED_S
    out.msg_terr_ovrd = inp.terr_ovrd
    out.msg_terr_pos = inp.power and not inp.gps_valid
    out.msg_windshear_sys = not inp.power or not inp.ra_valid or not inp.roll_valid or not inp.cas_valid
    return out
end

return M
