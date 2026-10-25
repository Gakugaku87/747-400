-- 747-400 transponders and TCAS (Ver 7.0) on X-Plane's TCAS (5-1 step 5):
-- the 570 transponder panel, the two transponders, X-Plane's transponder
-- mode, the TCAS modes and failures, the RA inhibits, the ND's traffic
-- symbols and messages, TFC and its automatic display, the voices, the
-- PFD's RA guidance values and the EICAS messages. X-Plane's TCAS finds the
-- traffic advisories and the resolution advisories (threat levels, the
-- advisory, the vertical speed bands); this adds the 747's layer. Logic and
-- sources: docs/overhaul/notes/ATA-34.md §3.9-3.10, §4.10-4.11, §15
-- (FCOM p.1218, p.1231, p.1533-1537, p.1553, p.1560-1570, p.1582-1584,
-- p.1593, p.1600-1601, p.1605; ATA34_2 34-45 p.17-50).
--
--   local T = B747_tcas_model               -- in XTLua, after dofile
--   local T = dofile(".../B747.34.tcas_model.lua")  -- in the tests
--   local s = T.new()
--   local inp = T.inputs()                  -- fill it every frame
--   local out = T.update(s, inp, dt)        -- the same table every frame

local M = setmetatable({}, {})
B747_tcas_model = M

-- the 570 panel's mode selector (FCOM p.1218; the 3D knob has these five)
M.SEL_STBY, M.SEL_ALT_OFF, M.SEL_XPDR, M.SEL_TA_ONLY, M.SEL_TA_RA = 0, 1, 2, 3, 4
-- X-Plane's transponder_mode
M.XP_OFF, M.XP_STBY, M.XP_MODE_A, M.XP_ALT, M.XP_GND, M.XP_TA_ONLY, M.XP_TA_RA = 0, 1, 2, 3, 5, 6, 7
-- X-Plane's threat levels (sim/cockpit2/tcas/targets/threat)
M.THREAT_OTHER, M.THREAT_PROX, M.THREAT_TA, M.THREAT_RA = 0, 1, 2, 3
-- X-Plane's advisory (tcas_active_advisory) and its messages (tcas_message)
M.ADV_RA = 2
M.XM_CLIMB, M.XM_CLIMB_CROSS, M.XM_INC_CLIMB, M.XM_CLIMB_NOW, M.XM_CLEAR = 1, 2, 3, 4, 5
M.XM_DESCEND, M.XM_DESC_CROSS, M.XM_INC_DESC, M.XM_DESC_NOW = 6, 7, 8, 9
M.XM_MONITOR, M.XM_MAINTAIN, M.XM_MAINTAIN_CROSS, M.XM_LEVEL_OFF = 10, 11, 12, 13
-- the ND's symbols (FCOM p.1534): filled red square, filled amber circle,
-- filled white diamond, hollow white diamond
M.SYM_NONE, M.SYM_OTHER, M.SYM_PROX, M.SYM_TA, M.SYM_RA = 0, 1, 2, 3, 4
-- the voices (laminar/B747/tcas/voice for the .snd), Ver 7.0 (FCOM p.1553)
M.V_NONE, M.V_TRAFFIC = 0, 1
M.V_CLIMB, M.V_CLIMB_CROSS, M.V_INC_CLIMB, M.V_CLIMB_NOW = 2, 3, 4, 5
M.V_DESCEND, M.V_DESC_CROSS, M.V_INC_DESC, M.V_DESC_NOW = 6, 7, 8, 9
M.V_MONITOR, M.V_MAINTAIN, M.V_MAINTAIN_CROSS, M.V_ADJUST, M.V_CLEAR = 10, 11, 12, 13, 14
M.VOICE_HOLD_S = 0.5        -- out.voice holds a code this long, then 0
M.CLEAR_WAIT_S = 2          -- X-Plane's CLEAR OF CONFLICT may follow the advisory's end

-- the RA inhibits (FCOM p.1593, p.1600-1601): all RAs below about 1,000 ft
-- RA (TCAS then works as TA ONLY and the NDs show TA ONLY), DESCEND RAs
-- below about 1,100 ft, INCREASE DESCENT RAs below about 1,500 ft, the TA
-- voice below about 500 ft
M.RA_INHIBIT_FT, M.DESCEND_INHIBIT_FT, M.INC_DESC_INHIBIT_FT, M.TA_VOICE_INHIBIT_FT = 1000, 1100, 1500, 500
-- >TCAS OFF is inhibited on the ground and below 400 ft RA (FCOM p.1593, p.1601)
M.TCAS_OFF_MSG_FT = 400
-- other and proximate traffic within 2,700 ft above and below (ATA34_2 p.26:
-- the panel without ABOVE/BELOW, §3.9); proximate within 6 nm and 1,200 ft
-- (FCOM p.1561); the nearest 30 shown (ATA34_2 p.24)
M.WINDOW_FT, M.PROX_NM, M.MAX_SHOWN = 2700, 6, 30
-- X-Plane's transponder modes that report altitude (mode C and S)
M.SSR_ALT = 3
M.NO_BAND = 3e38            -- X-Plane's bands use +-FLT_MAX for "no limit"

local function pair(v) return {v, v} end

function M.inputs()
    return {
        sel = M.SEL_STBY,           -- the mode selector
        xpdr_r = false,             -- the XPDR switch at R
        xpdr_power = pair(true),    -- L: AC standby bus, R: AC bus 2 (§2)
        xpdr_fail = pair(false),
        power = true,               -- the TCAS computer: AC bus 3
        fail = false,
        on_ground = true,
        ra = 0, ra_valid = true, ra_ncd = false,    -- the TCAS's radio altitude (ft)
        gpws_warning = false,       -- GPWS warning (PULL UP and the like)
        windshear = false,          -- the GPWS's windshear warning
        gpws_voice = false,         -- a GPWS voice is sounding
        pfd_ok = pair(true),        -- each PFD can show RA guidance (Captain, F/O)
        nd_ok = pair(true),         -- each ND is shown
        nd_traffic_mode = pair(true),   -- MAP, MAP CTR, VOR or APP (not CTR VOR/APP, PLN)
        nd_range_nm = pair(40),
        tfc_pushes = pair(0),       -- each TFC switch's push count
        own_vs = 0,                 -- fpm
        pitch = 0, tas_kt = 0,      -- for the PFD's RA pitch regions
        -- X-Plane's TCAS: targets 1..n
        n = 0, threat = {}, ssr = {}, dist_nm = {}, rel_alt_ft = {},
        adv = 0, msg = 0,
        bands = {-M.NO_BAND, -M.NO_BAND, -M.NO_BAND, -M.NO_BAND, -M.NO_BAND, -M.NO_BAND},
    }
end

local function nd_side()
    return {tfc = false, show = false, off = false, fail = false, traffic = 0, offscale = 0, ta_only = false}
end

function M.new()
    local s = {
        tfc = pair(false), armed = pair(false), pushes = {nil, nil},
        prev_sym = {}, ra_was = false, ra_voice = M.V_NONE,
        voice_t = 0,
        out = {
            xp_mode = M.XP_STBY,
            xpdr_msg = pair(false),     -- >TRANSPONDER L, R
            failed = false, operating = false, ra_mode = false,
            sym = {}, n = 0,            -- each target's ND symbol
            ta = false, ra = false,     -- a TA / an RA is shown (the ND's TRAFFIC)
            voice = M.V_NONE,
            pfd_ra = false,             -- RA guidance on the PFDs
            vs_lo = nil, vs_hi = nil,   -- fpm: below vs_lo and above vs_hi is red (nil: no region)
            pitch_lo = nil, pitch_hi = nil, -- deg: the RA pitch regions' edges
            nd = {nd_side(), nd_side()},
            msg_tcas_off = false, msg_tcas_system = false, msg_ra = pair(false),
        },
    }
    return s
end

-- the voice of X-Plane's message, with CROSSING from the RA's sense and where
-- the threat is now: climbing toward traffic above, or descending toward
-- traffic below (estimate: X-Plane's crossing messages do not follow the
-- geometry, §15). LEVEL OFF (Ver 7.1) is Ver 7.0's ADJUST VERTICAL SPEED.
local function ra_voice(msg, rel_alt, own_vs)
    if msg == M.XM_CLIMB or msg == M.XM_CLIMB_CROSS then
        return rel_alt > 0 and M.V_CLIMB_CROSS or M.V_CLIMB
    elseif msg == M.XM_DESCEND or msg == M.XM_DESC_CROSS then
        return rel_alt < 0 and M.V_DESC_CROSS or M.V_DESCEND
    elseif msg == M.XM_INC_CLIMB then return M.V_INC_CLIMB
    elseif msg == M.XM_CLIMB_NOW then return M.V_CLIMB_NOW
    elseif msg == M.XM_INC_DESC then return M.V_INC_DESC
    elseif msg == M.XM_DESC_NOW then return M.V_DESC_NOW
    elseif msg == M.XM_MONITOR then return M.V_MONITOR
    elseif msg == M.XM_MAINTAIN or msg == M.XM_MAINTAIN_CROSS then
        if (own_vs > 0 and rel_alt > 0) or (own_vs < 0 and rel_alt < 0) then return M.V_MAINTAIN_CROSS end
        return M.V_MAINTAIN
    elseif msg == M.XM_LEVEL_OFF then return M.V_ADJUST
    end
    return M.V_NONE
end

local function descend_inhibited(msg, ra_ft)
    if (msg == M.XM_DESCEND or msg == M.XM_DESC_CROSS or msg == M.XM_DESC_NOW) and ra_ft < M.DESCEND_INHIBIT_FT then
        return true
    end
    return msg == M.XM_INC_DESC and ra_ft < M.INC_DESC_INHIBIT_FT
end

local cand = {}
local function by_priority(a, b)
    if a.sym ~= b.sym then return a.sym > b.sym end
    return a.dist < b.dist
end

function M.update(s, inp, dt)
    local out = s.out

    -- the transponders (FCOM p.1218, p.1231)
    local xpdr_ok1 = inp.xpdr_power[1] and not inp.xpdr_fail[1]
    local xpdr_ok2 = inp.xpdr_power[2] and not inp.xpdr_fail[2]
    out.xpdr_msg[1], out.xpdr_msg[2] = not xpdr_ok1, not xpdr_ok2
    local xpdr_ok = xpdr_ok1
    if inp.xpdr_r then xpdr_ok = xpdr_ok2 end

    -- the TCAS: TA ONLY or TA/RA; failed without its power, its inputs from
    -- the selected transponder or both radio altimeters (the last two: estimates)
    local sel = inp.sel
    local tcas_sel = sel == M.SEL_TA_ONLY or sel == M.SEL_TA_RA
    out.failed = not inp.power or inp.fail or not xpdr_ok or not inp.ra_valid
    local ra_ft = inp.ra
    if inp.ra_ncd or not inp.ra_valid then ra_ft = math.huge end
    -- neither PFD can show RAs: in TA/RA the NDs show TCAS FAIL and no traffic
    -- (ATA34_2 p.18); TA ONLY keeps working
    local no_pfd = not inp.pfd_ok[1] and not inp.pfd_ok[2]
    local fail_shown = out.failed or (sel == M.SEL_TA_RA and no_pfd)
    out.operating = tcas_sel and not fail_shown
    local low = inp.on_ground or ra_ft < M.RA_INHIBIT_FT
    out.ra_mode = out.operating and sel == M.SEL_TA_RA and not low
        and not inp.gpws_warning and not inp.windshear

    -- X-Plane's transponder: altitude in the air only; TA ONLY while RAs are
    -- inhibited; the transponder alone when the TCAS does not work. X-Plane's
    -- TCAS runs in mode 3 too: this layer decides what is shown.
    if not xpdr_ok then
        out.xp_mode = M.XP_OFF
    elseif sel == M.SEL_STBY then
        out.xp_mode = M.XP_STBY
    elseif sel == M.SEL_ALT_OFF then
        out.xp_mode = M.XP_MODE_A
    elseif sel == M.SEL_XPDR or not out.operating then
        out.xp_mode = inp.on_ground and M.XP_GND or M.XP_ALT
    elseif out.ra_mode then
        out.xp_mode = M.XP_TA_RA
    else
        out.xp_mode = M.XP_TA_ONLY
    end

    -- the RA now: X-Plane's resolution advisory, unless it is one the 747
    -- inhibits at this height (then the threat is shown as a TA: estimate)
    local ra_on = out.ra_mode and inp.adv == M.ADV_RA and not descend_inhibited(inp.msg, ra_ft)

    -- each target's symbol
    local n = inp.n
    out.n = n
    local ncand = 0
    local ra_rel, ra_threat, ra_dist = 0, -1, math.huge
    out.ta, out.ra = false, false
    for j = 1, n do
        local sym = M.SYM_NONE
        local th = inp.threat[j] or -1
        if out.operating and th >= 0 and (inp.ssr[j] or 0) >= 2 then
            local alt_known = inp.ssr[j] >= M.SSR_ALT
            local rel, dist = inp.rel_alt_ft[j], inp.dist_nm[j]
            if th >= M.THREAT_RA and ra_on then
                sym = M.SYM_RA
                if th > ra_threat or (th == ra_threat and dist < ra_dist) then
                    ra_rel, ra_threat, ra_dist = rel, th, dist
                end
            elseif th >= M.THREAT_TA then
                sym = M.SYM_TA
            elseif th == M.THREAT_PROX or (not alt_known and dist <= M.PROX_NM) then
                sym = M.SYM_PROX
            else
                sym = M.SYM_OTHER
            end
            if sym < M.SYM_TA and alt_known and math.abs(rel) > M.WINDOW_FT then sym = M.SYM_NONE end
            if sym ~= M.SYM_NONE then
                ncand = ncand + 1
                local c = cand[ncand]
                if c == nil then c = {}; cand[ncand] = c end
                c.j, c.sym, c.dist = j, sym, dist
            end
        end
        out.sym[j] = sym
    end
    for j = n + 1, #out.sym do out.sym[j] = nil end
    -- the nearest 30, TAs and RAs first
    if ncand > M.MAX_SHOWN then
        for k = ncand + 1, #cand do cand[k] = nil end
        table.sort(cand, by_priority)
        for k = M.MAX_SHOWN + 1, ncand do out.sym[cand[k].j] = M.SYM_NONE end
    end
    for j = 1, n do
        local sym = out.sym[j]
        if sym == M.SYM_RA then out.ra = true elseif sym == M.SYM_TA then out.ta = true end
    end

    -- the voices: TRAFFIC, TRAFFIC once for each new TA (not during an RA,
    -- not below 500 ft); the RA's voice at its start and when it changes;
    -- CLEAR OF CONFLICT when X-Plane ends it (its message may change a frame
    -- after the advisory: CLEAR_WAIT_S). None in windshear (FCOM p.1582);
    -- none while a GPWS voice sounds (estimate).
    local voice = M.V_NONE
    local new_alert = false
    if ra_on then
        local v = ra_voice(inp.msg, ra_rel, inp.own_vs)
        if not s.ra_was then new_alert = true end
        if v ~= M.V_NONE and (not s.ra_was or v ~= s.ra_voice) then voice = v end
        s.ra_voice = v
        s.clear_t = nil
    elseif s.ra_was and out.ra_mode and inp.adv ~= M.ADV_RA then
        s.clear_t = 0
    end
    if s.clear_t ~= nil then
        if inp.msg == M.XM_CLEAR then
            voice, s.clear_t = M.V_CLEAR, nil
        else
            s.clear_t = s.clear_t + dt
            if s.clear_t > M.CLEAR_WAIT_S or not out.ra_mode then s.clear_t = nil end
        end
    end
    if not ra_on then
        for j = 1, n do
            local prev = s.prev_sym[j] or M.SYM_NONE
            if out.sym[j] == M.SYM_TA and prev ~= M.SYM_TA and prev ~= M.SYM_RA then
                new_alert = true
                if voice == M.V_NONE and ra_ft >= M.TA_VOICE_INHIBIT_FT and not inp.on_ground then
                    voice = M.V_TRAFFIC
                end
            end
        end
    end
    s.ra_was = ra_on
    for j = 1, n do s.prev_sym[j] = out.sym[j] end
    for j = n + 1, #s.prev_sym do s.prev_sym[j] = nil end
    if inp.windshear or inp.gpws_voice then voice = M.V_NONE end
    if voice ~= M.V_NONE then
        out.voice, s.voice_t = voice, 0
    elseif out.voice ~= M.V_NONE then
        s.voice_t = s.voice_t + dt
        if s.voice_t >= M.VOICE_HOLD_S then out.voice = M.V_NONE end
    end

    -- the PFDs' RA guidance (FCOM p.1536-1537, p.1562): red outside X-Plane's
    -- bands; the pitch regions' edges from the vertical speed limits at the
    -- present speed (estimate: ATA34_2 p.46 says only "a function of the RA data")
    out.pfd_ra = ra_on
    out.vs_lo, out.vs_hi, out.pitch_lo, out.pitch_hi = nil, nil, nil, nil
    if ra_on then
        local b = inp.bands
        if b[2] > b[1] and b[2] < M.NO_BAND then out.vs_lo = b[2] end
        if b[6] > b[5] and b[5] > -M.NO_BAND then out.vs_hi = b[5] end
        local tas_fpm = math.max(inp.tas_kt, 60) * 6076.12 / 60
        if out.vs_lo then out.pitch_lo = inp.pitch + math.deg((out.vs_lo - inp.own_vs) / tas_fpm) end
        if out.vs_hi then out.pitch_hi = inp.pitch + math.deg((out.vs_hi - inp.own_vs) / tas_fpm) end
    end

    -- the NDs (FCOM p.1534-1535, p.1560-1563, p.1584; p.1042 for the switch)
    for i = 1, 2 do
        local p = inp.tfc_pushes[i]
        if s.pushes[i] ~= nil and p ~= s.pushes[i] then
            s.tfc[i] = not s.tfc[i]
            s.armed[i] = false
        end
        s.pushes[i] = p
        -- armed by an earlier TA or RA: shown when the ND comes to a traffic mode
        if s.armed[i] and inp.nd_traffic_mode[i] then s.tfc[i], s.armed[i] = true, false end
    end
    -- a new TA or RA with TFC shown on neither ND: TFC on each ND in a traffic
    -- mode, the other armed; not in windshear (FCOM p.1583)
    local shown1 = s.tfc[1] and inp.nd_traffic_mode[1]
    local shown2 = s.tfc[2] and inp.nd_traffic_mode[2]
    if new_alert and not inp.windshear and not shown1 and not shown2 then
        for i = 1, 2 do
            if inp.nd_traffic_mode[i] then s.tfc[i] = true else s.armed[i] = true end
        end
    end
    local no_ra = out.operating and not out.ra_mode
    for i = 1, 2 do
        local nd = out.nd[i]
        local mode_ok = inp.nd_traffic_mode[i]
        -- TCAS FAIL with traffic selected; TCAS OFF when the selector is not
        -- at TA ONLY or TA/RA, not with the TCAS failed (FCOM p.1153)
        nd.fail = s.tfc[i] and mode_ok and fail_shown
        nd.off = s.tfc[i] and mode_ok and not tcas_sel and not out.failed
        nd.tfc = s.tfc[i] and mode_ok and out.operating
        nd.show = nd.tfc and inp.nd_ok[i]
        nd.traffic = out.ra and 2 or (out.ta and 1 or 0)
        nd.ta_only = no_ra
        local off = 0
        if nd.show then
            for j = 1, n do
                local sym = out.sym[j]
                if sym >= M.SYM_TA and inp.dist_nm[j] > inp.nd_range_nm[i] then
                    if sym == M.SYM_RA then off = 2 elseif off == 0 then off = 1 end
                end
            end
        end
        nd.offscale = off
    end

    -- EICAS (FCOM p.1605, p.1570, p.1593, p.1601)
    out.msg_tcas_off = not tcas_sel and not inp.on_ground and ra_ft >= M.TCAS_OFF_MSG_FT
    out.msg_tcas_system = out.failed or (no_pfd and not inp.nd_ok[1] and not inp.nd_ok[2])
    out.msg_ra[1] = not out.failed and not inp.pfd_ok[1]
    out.msg_ra[2] = not out.failed and not inp.pfd_ok[2]
    return out
end

return M
