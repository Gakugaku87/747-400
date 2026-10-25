-- 747-400 PFD ILS indications (5-2 step 4e): what each pilot's PFD shows of
-- its ILS receiver (the receiver of the EIU in use, chosen by the display
-- glue: FCOM p.1044, step 5b): the approach reference and course, the
-- localizer and glideslope
-- scales and pointers, the LOC and G/S flags, the deviation warnings (the
-- scale amber, the pointer flashing at 4 Hz) and the rising runway; and
-- what the same side's ND shows of it in APP mode (step 5b: FCOM p.1044,
-- the EIU selector picks both): the deviation bars and scales, the LOC and
-- G/S flags, the course, the frequency or identifier and the DME.
-- Logic and sources: docs/overhaul/notes/ATA-31.md §20 (ATA34_1 p.466-470,
-- ATA31 p.13, FCOM p.987-989, p.999).
--
--   local I = B747_pfd_ils_model             -- in XTLua, after dofile
--   local I = dofile(".../B747.60.pfd_ils_model.lua")   -- in the tests
--   local s = I.new()
--   local inp = I.inputs()                   -- fill it every frame
--   local out = I.update(s, inp, dt)         -- the same table every frame

local M = setmetatable({}, {})
B747_pfd_ils_model = M

M.CAPT, M.FO = 1, 2
-- the scales and pointers removed beyond 53 degrees of roll (ATA34_1 p.466-467)
M.ROLL_MAX_DEG = 53
-- the pointer filled within 2 1/3 dots, hollow beyond (FCOM p.987)
M.FILLED_DOTS = 7 / 3
-- the expanded localizer scale (a rectangle 1/2 dot) close to the centreline
-- (FCOM p.988, 109); "close" as the stock panel's 1/2 dot (estimate)
M.EXPANDED_DOTS = 0.5
-- the deviation warnings (ATA34_1 p.468): the glideslope beyond about 5/8
-- dot between 100 and 500 ft; the localizer beyond about 1/4 dot for 1 s
-- below 500 ft; LOC capture fail with LNAV and LOC armed below 950 ft, reset
-- at 1,050 ft or by the capture
M.GS_ALERT_DOTS = 5 / 8
M.GS_ALERT_LOW_FT, M.GS_ALERT_HIGH_FT = 100, 500
M.LOC_ALERT_DOTS = 1 / 4
M.LOC_ALERT_FT = 500
M.LOC_ALERT_S = 1
M.CAPTURE_FAIL_FT, M.CAPTURE_FAIL_RESET_FT = 950, 1050
M.FLASH_HZ = 4
-- the ND's deviation pointers filled within 2 1/2 dots (FCOM p.1144);
-- X-Plane holds its deviations at 2.5 dots beyond, so "within" is below 2.49
M.ND_FILLED_DOTS = 2.49

local function side_in()
    return {
        tuned = false,      -- an ILS frequency tuned (not parked)
        rx_fail = false,    -- the receiver failed or unpowered: no frequency, course or deviation
        loc_fail = false,   -- the localizer deviation invalid
        gs_fail = false,    -- the glideslope deviation invalid
        loc_rx = false,     -- the localizer received (else no computed data)
        gs_rx = false,      -- the glideslope received
        loc_dots = 0,       -- the deviations, dots
        gs_dots = 0,
        roll = 0,           -- that side's IRU roll, degrees
        trk = true,         -- that side's track (FMC or IRU) valid
        ra = 0,             -- that side's radio altitude, ft
        ra_valid = false,
        ra_show = false,    -- its digits shown (valid and below 2,500 ft)
        guidance = false,   -- an autopilot engaged or that side's flight director on
        dme_rx = false,     -- the receiver's DME distance received
        dme_fail = false,   -- the DME failed
    }
end

function M.inputs()
    return {
        side = {side_in(), side_in()},
        loc_active = false, -- the AFDS: LOC (or ROLLOUT) engaged
        gs_active = false,  -- G/S engaged
        lnav_active = false,
        loc_armed = false,
    }
end

local function side_out()
    return {
        ils = false,        -- the approach reference and course
        loc_scale = 0,      -- 0 none, 1 the scale, 2 amber, 3 the expanded scale, 4 amber
        loc_ptr = 0,        -- 0 none (or the flash's dark half), 1 filled, 2 hollow, 3 on the expanded scale
        loc_flag = false,
        gs_scale = 0,       -- 0 none, 1 the scale, 2 amber
        gs_ptr = 0,         -- 0 none (or the flash's dark half), 1 filled, 2 hollow
        gs_flag = false,
        rwy = false,        -- the rising runway (FCOM p.989)
        loc_alert = false,
        gs_alert = false,
        -- the ND in APP mode
        nd_loc_scale = false,
        nd_loc_ptr = 0,     -- 0 none, 1 filled, 2 hollow
        nd_loc_flag = false,
        nd_gs_scale = false,
        nd_gs_ptr = 0,
        nd_gs_flag = false,
        nd_crs = 0,         -- 0 none (the course data failed), 1 dashes (no runway course), 2 the course
        nd_ref = 0,         -- 0 none (the frequency data failed), 1 dashes, 2 the frequency or identifier
        nd_dme = 0,         -- 0 dashes (no distance), 1 the distance, 2 the DME flag
    }
end

function M.new()
    return {flash_t = 0, loc_t = {0, 0}, low = {false, false}, out = {side_out(), side_out()}}
end

function M.update(s, inp, dt)
    dt = dt or 0
    local period = 1 / M.FLASH_HZ
    s.flash_t = (s.flash_t + dt) % period
    local lit = s.flash_t < period / 2
    for p = M.CAPT, M.FO do
        local i, o = inp.side[p], s.out[p]
        -- nothing when no frequency is tuned or beyond 53 degrees of roll
        -- (the flags gone too beyond 53 degrees: estimate); the frequency
        -- and course blank when the receiver fails
        local shown = i.tuned and math.abs(i.roll) <= M.ROLL_MAX_DEG
        o.ils = shown and not i.rx_fail
        -- a failed deviation: its scale and pointer replaced by the flag
        -- (ATA31 p.13, ATA34_1 p.470)
        local loc_bad, gs_bad = i.rx_fail or i.loc_fail, i.rx_fail or i.gs_fail
        o.loc_flag = shown and loc_bad
        o.gs_flag = shown and gs_bad
        local loc_on, gs_on = shown and not loc_bad, shown and not gs_bad
        -- no computed data (no signal; for the localizer also no track):
        -- the scale without its pointer (ATA34_1 p.467)
        local loc_seen = loc_on and i.loc_rx and i.trk
        local gs_seen = gs_on and i.gs_rx
        local loc_abs, gs_abs = math.abs(i.loc_dots), math.abs(i.gs_dots)

        -- the warnings: with the autopilot or that side's flight director
        -- (FCOM p.987); ATA34_1's "approach mode operational" read as the
        -- AFDS's G/S or LOC engaged (estimate)
        local ra = i.ra_valid and i.ra
        local gs_alert = gs_seen and inp.gs_active and i.guidance and ra
            and ra >= M.GS_ALERT_LOW_FT and ra <= M.GS_ALERT_HIGH_FT and gs_abs > M.GS_ALERT_DOTS
        local loc_off = loc_seen and inp.loc_active and i.guidance and ra
            and ra <= M.LOC_ALERT_FT and loc_abs > M.LOC_ALERT_DOTS
        s.loc_t[p] = loc_off and s.loc_t[p] + dt or 0
        s.low[p] = (ra and not inp.loc_active
            and (ra <= M.CAPTURE_FAIL_FT or (s.low[p] and ra < M.CAPTURE_FAIL_RESET_FT))) and true or false
        local capture_fail = inp.lnav_active and inp.loc_armed and s.low[p]
        local loc_alert = loc_on and (s.loc_t[p] >= M.LOC_ALERT_S or capture_fail)
        o.gs_alert = gs_alert and true or false
        o.loc_alert = loc_alert and true or false

        o.gs_scale = gs_on and (o.gs_alert and 2 or 1) or 0
        o.gs_ptr = 0
        if gs_seen and (lit or not o.gs_alert) then o.gs_ptr = gs_abs <= M.FILLED_DOTS and 1 or 2 end
        local expanded = loc_seen and loc_abs <= M.EXPANDED_DOTS
        o.loc_scale = loc_on and ((expanded and 3 or 1) + (o.loc_alert and 1 or 0)) or 0
        o.loc_ptr = 0
        if loc_seen and (lit or not o.loc_alert) then
            o.loc_ptr = expanded and 3 or (loc_abs <= M.FILLED_DOTS and 1 or 2)
        end
        -- the rising runway: below 2,500 ft with the localizer pointer in view
        o.rwy = loc_seen and i.ra_show and true or false

        -- the ND in APP mode (ATA34_1 p.473-476, ATA31 p.20-21): the scale
        -- and pointer only with valid data; invalid data shows the flag
        -- instead, no computed data (no signal, or the receiver parked)
        -- removes both, as the ND's VOR displays do (ATA34_1 p.358; the
        -- PFD keeps its scale: ATA31 p.13); without a runway course (parked)
        -- the course and the frequency are dashes and the course pointer
        -- goes; a failed receiver removes them
        o.nd_loc_flag, o.nd_gs_flag = loc_bad, gs_bad
        local nd_loc = not loc_bad and i.tuned and i.loc_rx
        local nd_gs = not gs_bad and i.tuned and i.gs_rx
        o.nd_loc_scale, o.nd_gs_scale = nd_loc, nd_gs
        o.nd_loc_ptr = nd_loc and (loc_abs < M.ND_FILLED_DOTS and 1 or 2) or 0
        o.nd_gs_ptr = nd_gs and (gs_abs < M.ND_FILLED_DOTS and 1 or 2) or 0
        local course = i.rx_fail and 0 or (i.tuned and 2 or 1)
        o.nd_crs, o.nd_ref = course, course
        -- the DME: its flag when failed (FCOM p.1034), dashes without a
        -- distance (FCOM p.1033) or with the receiver parked
        o.nd_dme = i.dme_fail and 2 or ((i.tuned and i.dme_rx) and 1 or 0)
    end
    return s.out
end

return M
