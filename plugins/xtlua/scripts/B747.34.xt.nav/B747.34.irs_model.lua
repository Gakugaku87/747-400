-- 747-400 inertial reference system without X-Plane (5-1 step 2): the three
-- IRUs and their mode selectors, full and fast alignment, the present
-- position entry and its checks, excessive motion, the attitude mode and its
-- heading, the power (AC, the APU hot battery bus backup, the center IRU's
-- five minutes) and the messages. Logic and sources: docs/overhaul/notes/
-- ATA-34.md §3.5, §4.5, §12 (FCOM p.194, p.1216-1217, p.1227-1228,
-- p.1285-1287, p.1429-1430; ATA34_2 34-21 p.272-275, p.286-288, p.294-300,
-- p.335-363).
--
--   local I = B747_irs_model                -- in XTLua, after dofile
--   local I = dofile(".../B747.34.irs_model.lua")   -- in the tests
--   local s = I.new()
--   I.store(s, lat, lon)                 -- the position the IRUs remember
--   local inp = I.inputs()               -- fill it every frame
--   local out = I.update(s, inp, dt)     -- the same table every frame
--   I.align_now(s, inp)                  -- a quick start: aligned at once
--
-- IRUs 1 L, 2 C, 3 R. Positions in degrees (north and east positive).

local M = setmetatable({}, {})
B747_irs_model = M

M.L, M.C, M.R = 1, 2, 3
-- the mode selectors (MSU)
M.OFF, M.ALIGN, M.NAV, M.ATT = 0, 1, 2, 3
-- an IRU's mode (out.iru[i].mode)
M.M_OFF = 0         -- off or unpowered: alignment lost
M.M_ALIGN = 1       -- aligning (full or fast), or aligned and waiting at ALIGN
M.M_NAV = 2         -- navigation
M.M_ATT = 3         -- attitude (in align mode for its first 30 s)
M.M_FAIL = 4        -- failed (IRS L/C/R): nothing valid

M.ALIGN_S = 600                 -- full alignment: about ten minutes (FCOM p.1227)
M.FAST_S = 30                   -- fast alignment: about 30 s (FCOM p.1227)
M.ATT_S = 30                    -- attitude mode: 30 s in align mode to relevel (FCOM p.1227)
M.MOTION_CLEAR_S = 30           -- IRS MOTION until 30 s after the motion stops (ATA34_2 p.350)
M.STORED_DEG = 1                -- the first entry against the stored position: 1° (p.342)
M.FAST_LAT_DEG, M.FAST_LON_DEG = 0.5, 1     -- a fast alignment's entry (p.352)
M.LAT_FAILS = 2                 -- the IRU fails after two latitude miscompares (p.346)
M.OFF_RESET_S = 30              -- a failed IRU is reset by 30 s off (p.346)
M.ON_BAT_S = 10                 -- ON BAT: an IRU on DC for 10 s on the ground (R7681: p.287)
M.C_DC_S = 300                  -- the center IRU on the hot battery bus without DC bus 3: 5 min (p.274)
-- estimates (no values in the sources): the IRU's own latitude against the
-- entered one at the end of the alignment ("varies with latitude": p.344)
M.LAT_CHECK_DEG = 1

local function three(v) return {v, v, v} end

function M.inputs()
    return {
        msu = three(M.OFF),         -- the mode selectors
        ac = three(true),           -- each IRU's AC bus (L: AC 3, C: AC 1, R: AC 2)
        hot_bat = true,             -- the APU hot battery bus (the DC backup)
        dc3 = true,                 -- DC bus 3 (the center IRU's DC disconnect relay)
        gsb = true,                 -- the ground service bus (the ON BAT light)
        ground = true,              -- the air/ground relay
        moving = false,             -- excessive motion for an alignment
        lat = 0, lon = 0,           -- the airplane's position
        fail = three(false),        -- an IRU failed
        pos_seq = 0,                -- the FMC's present position entries: a new one when this changes
        pos_lat = 0, pos_lon = 0,
        hdg_seq = 0,                -- the FMC's SET HDG entries (magnetic heading)
        hdg = 0,
        mag_hdg = 0,                -- the airplane's magnetic heading (for the attitude mode's heading)
        align_s = M.ALIGN_S,        -- the full alignment's time (the simconfig option)
    }
end

local function iru()
    return {mode = M.M_OFF, t = 0, fast = false, aligned = false, entered = false, lat_wrong = false,
        lat_fails = 0, failed = false, off_t = M.OFF_RESET_S, motion = false, still_t = M.MOTION_CLEAR_S,
        dc_t = 0, c_dc_t = 0, c_cut = false, hdg_set = false, hdg_off = 0,
        last_lat = nil, last_lon = nil, ent_lat = 0, ent_lon = 0}
end

local function out_iru()
    return {mode = M.M_OFF, aligned = false, time_left = 0, att_valid = false, hdg_valid = false, nav_valid = false,
        on_dc = false, ac_fail = false, dc_fail = false, failed = false, align_memo = false,
        motion = false, hdg = 0}
end

function M.new()
    local s = {iru = {iru(), iru(), iru()}, pos_seq = nil, hdg_seq = nil, rejected = nil, fast_rejects = 0}
    s.out = {iru = {out_iru(), out_iru(), out_iru()}, irs_motion = false, on_bat = false,
        enter_pos = false, cycle_irs = false, set_pos = false, aligning = false, set_hdg = false,
        all_nav = false}
    return s
end

-- the position each IRU remembers (its last navigation position)
function M.store(s, lat, lon)
    for i = 1, 3 do s.iru[i].last_lat, s.iru[i].last_lon = lat, lon end
end

-- a quick start: every powered IRU at NAV in navigation at once
function M.align_now(s, inp)
    for i = 1, 3 do
        local u = s.iru[i]
        if inp.msu[i] == M.NAV and not u.failed and not inp.fail[i] then
            u.mode, u.t, u.fast, u.aligned, u.entered, u.lat_wrong = M.M_NAV, 0, false, true, true, false
            u.motion, u.still_t = false, M.MOTION_CLEAR_S
            u.last_lat, u.last_lon = inp.lat, inp.lon
        end
    end
    s.rejected, s.fast_rejects = nil, 0
    s.out.enter_pos, s.out.cycle_irs = false, false
end

-- an IRU wanting a position: a full alignment without one (or with a
-- latitude that disagreed), or a fast alignment
local function wants(u)
    return u.mode == M.M_ALIGN and not u.aligned and (u.fast or not u.entered or u.lat_wrong)
end

-- a new present position entry: taken by every IRU that wants one, or
-- rejected (ENTER IRS POSITION; the same position entered again is taken:
-- p.342). A fast alignment takes it within 1/2° latitude and 1° longitude of
-- its own position; a second miss is CYCLE IRS OFF-NAV (p.352)
local function entry(s, inp, out)
    local lat, lon = inp.pos_lat, inp.pos_lon
    local full_ok, fast_ok, any = true, true, false
    for i = 1, 3 do
        local u = s.iru[i]
        if wants(u) then
            any = true
            if u.fast then
                if math.abs(lat - inp.lat) > M.FAST_LAT_DEG or math.abs(lon - inp.lon) > M.FAST_LON_DEG then fast_ok = false end
            elseif not u.lat_wrong and u.last_lat
                and (math.abs(lat - u.last_lat) >= M.STORED_DEG or math.abs(lon - u.last_lon) >= M.STORED_DEG) then
                full_ok = false
            end
        end
    end
    if not any then return end
    local again = s.rejected ~= nil and s.rejected[1] == lat and s.rejected[2] == lon
    if not full_ok and not again then
        s.rejected = {lat, lon}
        out.enter_pos = true
        return
    end
    if not fast_ok then
        s.fast_rejects = s.fast_rejects + 1
        if s.fast_rejects >= 2 then out.cycle_irs, out.enter_pos = true, false else out.enter_pos = true end
        return
    end
    s.rejected = nil
    out.enter_pos = false
    for i = 1, 3 do
        local u = s.iru[i]
        if wants(u) then u.entered, u.lat_wrong, u.ent_lat, u.ent_lon = true, false, lat, lon end
    end
end

function M.update(s, inp, dt)
    local out = s.out
    if s.pos_seq == nil then s.pos_seq, s.hdg_seq = inp.pos_seq, inp.hdg_seq end
    local new_pos = inp.pos_seq ~= s.pos_seq
    local new_hdg = inp.hdg_seq ~= s.hdg_seq
    s.pos_seq, s.hdg_seq = inp.pos_seq, inp.hdg_seq

    local on_bat = false
    for i = 1, 3 do
        local u, o = s.iru[i], out.iru[i]
        local msu = inp.msu[i]
        -- power: turned on inside the IRU by any mode but OFF; AC, or else the
        -- hot battery bus (p.272, p.274). The center IRU's DC goes 5 min after
        -- DC bus 3 while it is on DC, until DC bus 3 or AC comes back
        local dc_ok = inp.hot_bat
        if i == M.C then
            if inp.ac[i] or inp.dc3 or msu == M.OFF then u.c_dc_t, u.c_cut = 0, false
            else
                u.c_dc_t = u.c_dc_t + dt
                if u.c_dc_t >= M.C_DC_S then u.c_cut = true end
            end
            if u.c_cut then dc_ok = false end
        end
        local powered = msu ~= M.OFF and (inp.ac[i] or dc_ok)
        o.on_dc = powered and not inp.ac[i]
        o.ac_fail = msu ~= M.OFF and not inp.ac[i]
        o.dc_fail = msu ~= M.OFF and not dc_ok
        if o.on_dc then u.dc_t = u.dc_t + dt else u.dc_t = 0 end
        if inp.ground and u.dc_t >= M.ON_BAT_S then on_bat = true end
        if msu == M.OFF then u.off_t = u.off_t + dt else u.off_t = 0 end
        if u.off_t >= M.OFF_RESET_S then u.failed, u.lat_fails = false, 0 end

        if not powered then
            -- alignment lost (in flight the navigation mode is gone for the
            -- rest of it: no alignment in the air)
            if u.mode == M.M_NAV then u.last_lat, u.last_lon = inp.lat, inp.lon end
            u.mode, u.aligned, u.entered, u.fast, u.hdg_set, u.lat_wrong = M.M_OFF, false, false, false, false, false
        elseif u.failed or inp.fail[i] then
            if u.mode == M.M_NAV then u.last_lat, u.last_lon = inp.lat, inp.lon end
            u.mode = M.M_FAIL
        elseif msu == M.ATT or u.mode == M.M_ATT then
            -- the attitude mode: latched until OFF (ATA34_2 p.354)
            if u.mode ~= M.M_ATT then
                if u.mode == M.M_NAV then u.last_lat, u.last_lon = inp.lat, inp.lon end
                u.mode, u.t, u.hdg_set, u.aligned, u.entered, u.fast = M.M_ATT, 0, false, false, false, false
            else
                u.t = u.t + dt
            end
        elseif u.mode == M.M_OFF or u.mode == M.M_FAIL then
            -- OFF to ALIGN or NAV: a full alignment (it goes on only on the ground)
            u.mode, u.t, u.fast, u.aligned, u.entered, u.lat_wrong = M.M_ALIGN, 0, false, false, false, false
            u.motion, u.still_t = false, M.MOTION_CLEAR_S
        elseif u.mode == M.M_NAV then
            u.last_lat, u.last_lon = inp.lat, inp.lon
            if msu == M.ALIGN then
                -- parked: a fast alignment; otherwise out of NAV the alignment
                -- is lost (FCOM p.1227)
                local fast = inp.ground and not inp.moving
                u.mode, u.t, u.fast, u.aligned, u.entered = M.M_ALIGN, 0, fast, false, false
                if fast then s.fast_rejects = 0 end
            end
        end

        -- the alignment
        if u.mode == M.M_ALIGN then
            local need = u.fast and M.FAST_S or inp.align_s
            if not inp.ground then
                u.t = 0                                  -- not in flight (FCOM p.1227)
            elseif inp.moving then
                -- excessive motion: stopped, restarted when it stops (ATA34_2 p.350)
                u.motion, u.still_t, u.t, u.aligned = true, 0, 0, false
            else
                u.still_t = u.still_t + dt
                if u.still_t >= M.MOTION_CLEAR_S then u.motion = false end
                if not u.aligned then u.t = u.t + dt end
            end
            if not u.aligned and u.t >= need then
                if u.fast then
                    u.aligned = true                     -- the position is optional (FCOM p.1227)
                elseif u.entered and not u.lat_wrong then
                    -- its own latitude against the entered one (p.344, p.346)
                    if math.abs(u.ent_lat - inp.lat) > M.LAT_CHECK_DEG then
                        u.lat_fails = u.lat_fails + 1
                        if u.lat_fails >= M.LAT_FAILS then u.failed, u.mode = true, M.M_FAIL else u.lat_wrong = true end
                    else
                        u.aligned = true
                    end
                end
            end
            if u.aligned and msu == M.NAV then
                u.mode, u.fast, u.lat_fails = M.M_NAV, false, 0
                u.last_lat, u.last_lon = inp.lat, inp.lon
            end
        end
        if u.mode ~= M.M_ALIGN then u.motion = false end
    end

    -- the FMC's entries
    if new_pos then entry(s, inp, out) end
    -- SET HDG: the heading in ATT is the entered one plus the airplane's
    -- turns since, without drift (none in the sources: estimate)
    if new_hdg then
        for i = 1, 3 do
            local u = s.iru[i]
            if u.mode == M.M_ATT then u.hdg_set, u.hdg_off = true, inp.hdg - inp.mag_hdg end
        end
    end

    -- the outputs
    local motion, set_pos, aligning, set_hdg, all_nav, late = false, false, false, false, true, false
    for i = 1, 3 do
        local u, o = s.iru[i], out.iru[i]
        o.mode = u.mode
        o.aligned = u.mode == M.M_ALIGN and u.aligned          -- aligned, waiting at ALIGN
        o.failed = u.mode == M.M_FAIL
        o.nav_valid = u.mode == M.M_NAV
        o.att_valid = u.mode == M.M_NAV or (u.mode == M.M_ATT and u.t >= M.ATT_S)
        o.hdg_valid = u.mode == M.M_NAV or (o.att_valid and u.hdg_set)
        o.hdg = (inp.mag_hdg + (u.mode == M.M_ATT and u.hdg_off or 0)) % 360
        o.motion = u.motion
        -- IRS ALIGN MODE: in align mode, not while the airplane moves (p.350)
        o.align_memo = (u.mode == M.M_ALIGN and not (inp.moving and inp.ground)) or (u.mode == M.M_ATT and u.t < M.ATT_S)
        if u.mode == M.M_ALIGN and not u.aligned then
            o.time_left = math.max(0, (u.fast and M.FAST_S or inp.align_s) - u.t)
        else
            o.time_left = 0
        end
        if u.motion then motion = true end
        if wants(u) and not (u.fast and u.entered) then set_pos = true end
        if u.mode == M.M_ALIGN then aligning = true end
        if u.mode == M.M_ATT then set_hdg = true end
        if u.mode ~= M.M_NAV then all_nav = false end
        if u.lat_wrong then late = true end
        -- no position ten minutes on (p.348)
        if u.mode == M.M_ALIGN and not u.fast and not u.entered and u.t >= inp.align_s then late = true end
    end
    out.irs_motion = motion
    out.on_bat = on_bat and not inp.gsb
    out.set_pos = set_pos
    out.aligning = aligning
    out.set_hdg = set_hdg
    out.all_nav = all_nav
    -- ENTER IRS POSITION: a rejected entry (until a good one), a latitude
    -- miscompare, or no position after the alignment time (p.342-348)
    if late then out.enter_pos = true end
    if not set_pos then out.enter_pos = false end
    if all_nav then out.cycle_irs = false end
    return out
end

return M
