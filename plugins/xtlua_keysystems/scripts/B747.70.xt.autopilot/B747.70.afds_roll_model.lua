-- The FCCs' roll laws (6-3 step 2a; the plan and sources in
-- docs/overhaul/notes/ATA-22.md §10 and §16): the roll command, the bank
-- the A/P flies and the F/Ds show, out of the roll mode the AFDS model
-- (B747.70.afds_model.lua) has. X-Plane's heading modes and F/D are not
-- used.
--  - HDG SEL: the selected heading's error to the airplane's heading, both
--    in the heading reference (ATA22 p.358). Selected before the push, the
--    turn toward the smaller error; turned after the push, the turn the
--    way the knob turned (ATA22 p.274): from the push on the error follows
--    the knob unwrapped, so a turn past 180 degrees keeps its way (within
--    one round).
--  - HDG HOLD: wings level (ROLL DOWN, ATA22 p.348) until the AFDS model
--    has its heading (the roll under 3 degrees for 2 s: p.352-353), then
--    that heading; kept through a change of the heading reference.
--  - ATT: the bank the AFDS model holds (5-30 degrees: FCOM p.663).
--  - T/O: wings level on the ground (FCOM p.666), from the lift-off the
--    track there (p.663; ATA22 p.358); G/A: the track at its engagement
--    (FCOM p.663), wings level on the ground.
--  - LNAV: the FMC's steering (ATA22 p.358), at the rate below as before
--    (6-1/6-2 step 6c).
--  - LOC (step 2b; ATA22 p.290, p.358, figure p.359): the deviation made a
--    distance from the beam's centre with the distance to the localizer
--    from the radio altitude (a 3 degree glide slope and a 10,000 ft
--    runway); blended with the cross runway velocity (the inertial path:
--    on through a lost signal); the track steered to the beam over a
--    lookahead; LOC TRACK (the final roll down on the centreline) within
--    the bank limit of tracking. Wings level from 5 ft (ROLL DOWN,
--    p.348). The capture (`loc_capture`, the AFDS model's input): the
--    turn onto the course at the capture bank needs the distance left, by
--    the ground speed, the intercept angle and the deviation (p.290), or
--    the deviation is small.
--  - ROLLOUT (step 4c; ATA22 p.296, p.348, p.362; FCOM p.659, p.671):
--    wings level, and a rudder command (s.rudder, the pedals' ratio) to
--    the centreline on LOC's distance from it and the cross runway
--    velocity, the distance to the localizer shortened by the ground run;
--    the A/P applies it with more than one channel (the glue: rudder and
--    nose wheel steering, FCOM p.659).
-- A heading or track error asks for a turn of error / TAU_S degrees a
-- second, the bank of that turn at the TAS, within the bank limit
-- (estimate: the sources give no gains); the command moves at most
-- ROLL_RATE degrees a second (estimate, as LNAV's) from the bank where the
-- law starts (the roll attitude integrator synchronized: ATA22 p.348).
-- The bank limit (FCOM p.647): in HDG SEL the MCP's selector, 5-25, or
-- AUTO; AUTO varies 15-25 with TAS, flaps and V2: 15 below V2 + 10 with
-- the flaps out (FCTM p.118), 25 with the flaps out above it, flaps up by
-- TAS (estimate: 25 to 300 kt, 15 from 480 kt). In LNAV with AUTO only
-- the 15 below V2 + 10 (FCTM p.118: the FMC's holds bank up to 30, FMSPG
-- p.164, p.226); HDG HOLD and TO/GA within AUTO (estimate). NORM's
-- reference in the polar areas gives HDG SEL, HDG HOLD and LOC no heading
-- (FCOM p.1046): no command (NCD), the bank held; no LOC capture.
-- LOC's numbers are estimates (the sources give the inputs, not the
-- gains): the capture bank 25 with a 4 s lead, captured within 0.7
-- degrees whatever the closure; a lookahead of 30 s; the deviation blended
-- with the inertial path over 5 s; LOC TRACK within 100 m and 5 degrees,
-- its bank limit 15 (25 in the capture). X-Plane's localizer deviation is
-- 1.41 degrees a dot (measured at RJAA 34L against the localizer's place
-- in X-Plane's nav data: 0.711 dots a degree).
-- Pure: the airplane's state in, the command out.
--   local R = B747_afds_roll_model                      -- in XTLua, after dofile
--   local R = dofile(".../B747.70.afds_roll_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_afds_roll_model = M

-- a heading error's turn: error / TAU_S degrees a second (estimate)
M.TAU_S = 8
-- the command's rate, degrees a second (estimate)
M.ROLL_RATE = 3
-- AUTO's bank limit (FCOM p.647): 15 below V2 + V2_ADD with the flaps out
-- (FCTM p.118); flaps up AUTO_MAX to AUTO_TAS_LO kt TAS, AUTO_MIN from
-- AUTO_TAS_HI (estimate)
M.AUTO_MAX = 25
M.AUTO_MIN = 15
M.V2_ADD = 10
M.AUTO_TAS_LO = 300
M.AUTO_TAS_HI = 480
-- the selector's positions 1-5 (0 AUTO: FCOM p.647)
M.SELECTOR = {5, 10, 15, 20, 25}
-- LOC (step 2b): X-Plane's deviation, degrees a dot (measured); the
-- distance to the localizer from the radio altitude (in its range) on a
-- GS_DEG glide slope with a RWY_FT runway beyond (ATA22 p.358)
M.LOC_DOT_DEG = 1.41
M.GS_DEG = 3
M.RWY_FT = 10000
M.RA_MAX = 2500
-- the capture (estimates): the turn onto the course at CAPTURE_BANK with
-- a CAPTURE_LEAD_S roll-in, or within CAPTURE_BAND degrees
M.CAPTURE_BANK = 25
M.CAPTURE_LEAD_S = 4
M.CAPTURE_BAND = 0.7
-- the law (estimates): the track to the beam over LOOK_S of ground speed,
-- the deviation blended with the inertial path over BLEND_S, LOC TRACK
-- within TRACK_M and TRACK_DEG, the bank limits in the capture and in
-- tracking, wings level below ROLL_DOWN_FT (ATA22 p.348)
M.LOOK_S = 30
M.BLEND_S = 5
M.TRACK_M = 100
M.TRACK_DEG = 5
M.LOC_LIMIT = 25
M.TRACK_LIMIT = 15
M.ROLL_DOWN_FT = 5
-- ROLLOUT (step 4c; estimates: the sources give the inputs, ATA22 p.362):
-- the cross runway velocity asked to close the distance in ROLLOUT_T_S,
-- the track within ROLLOUT_DEG of the course; the rudder RUDDER_K a degree
-- of the track's error and RUDDER_KR a degree a second of its rate, within
-- RUDDER_MAX; the distance to the localizer from ROLLOUT's engage less the
-- ground run, ROLLOUT_MIN_M at least
M.ROLLOUT_T_S = 8
M.ROLLOUT_DEG = 3
M.RUDDER_K = 0.15
M.RUDDER_KR = 0.3
M.RUDDER_MAX = 0.5
M.ROLLOUT_MIN_M = 300
-- the modes with a law here
M.LAW = {HDG_SEL = true, HDG_HOLD = true, ATT = true, LNAV = true, TO = true, GA = true, LOC = true,
    ROLLOUT = true}

local G = 9.80665
local KT = 1852 / 3600
local function wrap(a) return (a + 180) % 360 - 180 end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function M.new()
    return {cmd = nil, mode = nil, err = nil, hold = nil, trk_ref = nil, valid = false,
        last_sel = nil, last_hdg = nil, ref_true = nil, loc_y = nil, loc_track = false,
        rudder = nil, ro_dist = nil, last_trk = nil}
end

function M.inputs()
    return {
        mode = nil,         -- the AFDS model's roll mode
        active = false,     -- an A/P engaged or a F/D shown
        ground = false,
        bank = 0,           -- the airplane's bank (right positive)
        hdg = 0,            -- its heading in the heading reference
        ref_true = false,   -- the reference is true north
        hdg_valid = true,   -- false: NORM in the polar areas (FCOM p.1046)
        trk = 0,            -- its track (true)
        sel = 0,            -- the MCP's heading (in the reference)
        held = false,       -- the AFDS model has HDG HOLD's heading
        att_bank = 0,       -- ATT's bank
        lnav_bank = 0,      -- the FMC's steering
        selector = 0,       -- the bank limit selector: 0 AUTO, 1-5
        tas = 0,            -- kt
        ias = 0,            -- kt
        flaps_up = true,
        v2 = 999,           -- the FMC's V2 (999: none)
        -- LOC (step 2b)
        loc_dots = 0,       -- the localizer deviation (X-Plane's: plus with the beam to the right)
        loc_valid = false,  -- both receivers have the localizer
        course = 0,         -- the localizer course (magnetic)
        trk_mag = 0,        -- the track (magnetic)
        gs = 0,             -- the ground speed, kt
        ra = 0,             -- the radio altitude, ft
    }
end

-- the distance to the localizer (m) from the radio altitude: on the glide
-- slope with the runway beyond (ATA22 p.358)
function M.loc_distance(ra)
    local h = clamp(ra or M.RA_MAX, 0, M.RA_MAX)
    return (h / math.tan(math.rad(M.GS_DEG)) + M.RWY_FT) * 0.3048
end
-- the deviation, degrees right of the centreline, and the distance (m)
function M.loc_dev(inp) return -inp.loc_dots * M.LOC_DOT_DEG end
function M.loc_lateral(inp) return M.loc_distance(inp.ra) * math.tan(math.rad(M.loc_dev(inp))) end
-- the track's angle to the course (right plus), the cross runway velocity
local function loc_angle(inp) return wrap(inp.trk_mag - inp.course) end
local function cross_velocity(inp) return inp.gs * KT * math.sin(math.rad(loc_angle(inp))) end

-- LOC's capture (ATA22 p.290: by the ground speed, the intercept angle and
-- the deviation): closing on the beam with no more distance left than the
-- turn onto the course takes, or the deviation small
function M.loc_capture(inp)
    if not inp.loc_valid or not inp.hdg_valid then return false end
    if math.abs(M.loc_dev(inp)) <= M.CAPTURE_BAND then return true end
    local y, v = M.loc_lateral(inp), cross_velocity(inp)
    if y * v >= 0 then return false end
    local gs = inp.gs * KT
    local r = gs * gs / (G * math.tan(math.rad(M.CAPTURE_BANK)))
    return math.abs(y) <= r * (1 - math.cos(math.rad(loc_angle(inp)))) + math.abs(v) * M.CAPTURE_LEAD_S
end

-- below V2 + 10 with the flaps out (FCTM p.118)
local function below_v2(inp)
    return not inp.flaps_up and inp.v2 < 900 and inp.ias < inp.v2 + M.V2_ADD
end

-- AUTO's bank limit (FCOM p.647; FCTM p.118)
function M.auto_limit(inp)
    if not inp.flaps_up then return below_v2(inp) and M.AUTO_MIN or M.AUTO_MAX end
    local f = clamp((inp.tas - M.AUTO_TAS_LO) / (M.AUTO_TAS_HI - M.AUTO_TAS_LO), 0, 1)
    return M.AUTO_MAX - f * (M.AUTO_MAX - M.AUTO_MIN)
end

-- the bank limit of a mode: HDG SEL's selector, else AUTO
function M.limit(mode, inp)
    if mode == "HDG_SEL" and inp.selector >= 1 then return M.SELECTOR[inp.selector] or M.AUTO_MAX end
    return M.auto_limit(inp)
end

-- the bank of a heading or track error: the turn of err / TAU_S degrees a
-- second at the TAS (100 kt at least), within the limit
function M.bank_for(err, inp, limit)
    local v = math.max(inp.tas, 100) * KT
    local b = math.deg(math.atan(v * math.rad(err / M.TAU_S) / G))
    return clamp(b, -limit, limit)
end

-- HDG SEL's error: the last one moved by the knob and the airplane's turn,
-- the same angle as sel - hdg within one round each way
local function sel_err(s, inp)
    if s.err == nil or s.last_sel == nil or s.ref_true ~= inp.ref_true then
        return wrap(inp.sel - inp.hdg)
    end
    local e = s.err + wrap(inp.sel - s.last_sel) - wrap(inp.hdg - s.last_hdg)
    local w = wrap(inp.sel - inp.hdg)
    local r = w + 360 * math.floor((e - w) / 360 + 0.5)
    if r >= 360 then r = r - 360 elseif r <= -360 then r = r + 360 end
    return r
end

-- the command (degrees of bank, right positive), or nil without a law here
-- (no mode); s.valid false for NCD; in ROLLOUT s.rudder the rudder's
-- command (the pedals' ratio, right positive), else nil
function M.update(s, inp, dt)
    dt = dt or 0
    local mode = inp.active and inp.mode or nil
    if mode ~= "ROLLOUT" then s.rudder, s.ro_dist, s.last_trk = nil, nil, nil end
    if not M.LAW[mode] then
        s.mode, s.cmd, s.valid, s.err, s.hold, s.trk_ref = mode, nil, false, nil, nil, nil
        s.loc_y, s.loc_track = nil, false
        s.last_sel, s.last_hdg, s.ref_true = inp.sel, inp.hdg, inp.ref_true
        return nil
    end
    if mode ~= s.mode then
        -- (ROLLOUT goes on from LOC's distance)
        if not (mode == "ROLLOUT" and s.mode == "LOC") then s.loc_y, s.loc_track = nil, false end
        s.mode, s.err, s.hold, s.trk_ref = mode, nil, nil, nil
        if mode == "GA" and not inp.ground then s.trk_ref = inp.trk end
    end
    if s.cmd == nil then s.cmd = inp.bank end
    -- HDG HOLD keeps its heading through a change of the reference
    if s.hold and s.ref_true ~= nil and s.ref_true ~= inp.ref_true then
        s.hold = (s.hold + inp.hdg - s.last_hdg) % 360
    end
    local limit = M.limit(mode, inp)
    local target, valid = 0, true
    if mode == "HDG_SEL" then
        s.err = sel_err(s, inp)
        target, valid = M.bank_for(s.err, inp, limit), inp.hdg_valid
    elseif mode == "HDG_HOLD" then
        valid = inp.hdg_valid
        if valid and inp.held and not s.hold then s.hold = inp.hdg end
        if s.hold then target = M.bank_for(wrap(s.hold - inp.hdg), inp, limit) end
    elseif mode == "ATT" then
        target = inp.att_bank
    elseif mode == "LNAV" then
        target = inp.lnav_bank
        if inp.selector == 0 and below_v2(inp) then target = clamp(target, -M.AUTO_MIN, M.AUTO_MIN) end
    elseif mode == "LOC" then
        -- the distance from the beam's centre: on the cross runway velocity,
        -- to the deviation over BLEND_S while there is one (the inertial
        -- path holds without it)
        valid = inp.hdg_valid
        local th = loc_angle(inp)
        if s.loc_y == nil then s.loc_y = M.loc_lateral(inp) end
        s.loc_y = s.loc_y + cross_velocity(inp) * dt
        if inp.loc_valid then s.loc_y = s.loc_y + (M.loc_lateral(inp) - s.loc_y) * math.min(1, dt / M.BLEND_S) end
        if not s.loc_track and math.abs(s.loc_y) < M.TRACK_M and math.abs(th) < M.TRACK_DEG then s.loc_track = true end
        if not inp.ground and inp.ra >= M.ROLL_DOWN_FT then
            local want = -math.deg(math.atan(s.loc_y / (math.max(inp.gs, 100) * KT * M.LOOK_S)))
            target = M.bank_for(wrap(want - th), inp, s.loc_track and M.TRACK_LIMIT or M.LOC_LIMIT)
        end
    elseif mode == "ROLLOUT" then
        -- wings level (ROLL DOWN: ATA22 p.348); the rudder to the centreline
        -- on the distance from it and the cross runway velocity (p.362), the
        -- distance to the localizer shortened by the ground run
        valid = inp.hdg_valid
        local th = loc_angle(inp)
        if s.ro_dist == nil then s.ro_dist = M.loc_distance(inp.ra) end
        s.ro_dist = math.max(s.ro_dist - inp.gs * KT * dt, M.ROLLOUT_MIN_M)
        if s.loc_y == nil then s.loc_y = s.ro_dist * math.tan(math.rad(M.loc_dev(inp))) end
        s.loc_y = s.loc_y + cross_velocity(inp) * dt
        if inp.loc_valid then
            local y = s.ro_dist * math.tan(math.rad(M.loc_dev(inp)))
            s.loc_y = s.loc_y + (y - s.loc_y) * math.min(1, dt / M.BLEND_S)
        end
        local v = math.max(inp.gs, 20) * KT
        local lim = math.sin(math.rad(M.ROLLOUT_DEG))
        local want = -math.deg(math.asin(clamp(s.loc_y / M.ROLLOUT_T_S / v, -lim, lim)))
        local rate = (s.last_trk and dt > 0) and wrap(inp.trk_mag - s.last_trk) / dt or 0
        s.last_trk = inp.trk_mag
        s.rudder = clamp(M.RUDDER_K * wrap(want - th) - M.RUDDER_KR * rate, -M.RUDDER_MAX, M.RUDDER_MAX)
        if not valid then s.rudder = 0 end
    elseif inp.ground then
        -- T/O and G/A on the ground: wings level, the track from the lift-off
        s.trk_ref = nil
    else
        if s.trk_ref == nil then s.trk_ref = inp.trk end
        target = M.bank_for(wrap(s.trk_ref - inp.trk), inp, limit)
    end
    -- no reference: the bank held (NCD)
    if not valid then target = s.cmd end
    local step = M.ROLL_RATE * dt
    s.cmd = s.cmd + clamp(target - s.cmd, -step, step)
    s.valid = valid
    s.last_sel, s.last_hdg, s.ref_true = inp.sel, inp.hdg, inp.ref_true
    return s.cmd
end

return M
