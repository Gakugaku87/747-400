-- 747-400 cabin pressure control without X-Plane: the cabin pressure
-- controllers (CPC A and B) with their modes and schedules, the landing
-- altitude, the two outflow valves (automatic and manual), the cabin
-- altitude limiter, the positive and negative pressure relief valves, the
-- cabin itself (the packs' air in, the valves, the leaks and the reliefs
-- out), the ECS card's cruise clamp for the packs, and the EICAS messages
-- of the system. Logic and sources: docs/overhaul/notes/ATA-21.md §2.4,
-- §3.2, §3.3, §3.5, §4.5 (FCOM 2.10, 2.30, 2.50, 11.43; ATA21 21-30).
--
--   local C = B747_press_model             -- in XTLua, after dofile
--   local C = dofile(".../B747.55.press_model.lua")   -- in the tests
--   local s = C.new()
--   local inp = C.inputs()                 -- fill it every frame
--   local out = C.update(s, inp, dt)       -- the same table every frame
--
-- Pressures are absolute, in psi; a cabin "climb" is the cabin pressure
-- falling. Rates in "sea-level fpm" are pressure rates: the rate of
-- pressure change of that many feet per minute at sea level.

local M = setmetatable({}, {})
B747_press_model = M

-- modes (out.mode)
M.GROUND, M.TAKEOFF, M.CLIMB, M.CRUISE, M.DESCENT, M.LANDED = 0, 1, 2, 3, 4, 5

-- the controllers (FCOM p.607-609; ATA21 p.412, p.424-442)
M.TAKEOFF_KT = 65               -- takeoff mode on the ground above 65 kt (ATA21 p.412, p.428)
M.PREPRESS_FT = 50              -- the cabin 50 ft below the field for takeoff and at touchdown
M.PREPRESS_FPM = 500            -- at 500 fpm (nominal)
M.CLIMB_FMC_FPM = 600           -- the climb schedule with FMC data: 600 sea-level fpm at most
M.CLIMB_INT_FPM = 1000          -- the internal schedule: 1,000 fpm at most
M.INT_CRUISE_FT = 39000         -- the internal schedule's cruise altitude
M.MAX_DP = 8.9                  -- ΔP at most (FCOM p.608; ATA21 p.424)
M.CRUISE_DP = 8.8               -- the schedule's ΔP: the cruise cabin as low as it can be (ATA21
                                -- p.424) with ΔP 8.8 (estimate: FCOM p.585 shows cabin 6,250 ft,
                                -- ΔP 8.8, which is FL390 at 8.8; 8.9 would show amber)
M.MAX_CABIN_FT = 8000           -- the cruise cabin altitude at most (FCOM p.608)
M.CRUISE_BAND_FT = 100          -- cruise: within 100 ft of the FMC cruise altitude,
M.LEVEL_FPM, M.LEVEL_S = 100, 45    -- or (internal) under 100 fpm for 45 s (ATA21 p.431)
M.DESCENT_FT = 1000             -- descent: 1,000 ft below the cruise altitude (ATA21 p.431)
M.DESCENT_INT_FPM = 300         -- the internal descent rate, 250-450 fpm (ATA21 p.431)
M.HOLD_FT, M.HOLD_S = 250, 120  -- a level-off in descent: within 250 ft for 2 min,
M.HOLD_EXIT_FT = 500            -- and out of it 500 ft away (ATA21 p.387, p.431)
M.LANDED_FPM, M.LANDED_S, M.LANDED_FAST_FPM = 500, 60, 2000   -- after touchdown (FCOM p.608; ATA21 p.432)
M.LDG_MIN_FT, M.LDG_MAX_FT, M.LDG_STEP_FT = -1000, 14000, 50   -- LDG ALT knob (FCOM p.573, p.608)
M.LDG_DEFAULT_FT = 2000         -- AUTO without an FMC landing altitude (FCOM p.608)
M.FMC_SWITCH_NM = 400           -- the FMC sends the destination after 400 NM, half way, T/C or T/D (FCOM p.1400)
M.CLAMP_FT = 25000              -- the cruise clamp for the packs only above 25,000 ft (ATA21 p.382)
M.TRANSFER_FPM, M.TRANSFER_DP = 2000, 9.07  -- the other controller takes over (ATA21 p.436),
M.POWER_LOSS_S = 2              -- or after 2 s without power
M.LIMITER_FT, M.LIMITER_OFF_FT = 11000, 750    -- the ICUs close the valves at 11,000 ft until 750 ft below (ATA21 p.406, p.442)
M.CABIN_WARN_FT = 10000         -- CABIN ALTITUDE (FCOM p.619)
M.RELIEF_DP = 9.25              -- positive relief (ATA21 p.462)
M.NEG_RELIEF_DP = {0.3, 1.0}    -- negative relief: opens from 0.2-0.4 psi, full at 1 psi (ATA21 p.472)

-- estimates: the sources give no numbers for these (notes/ATA-21.md §6)
M.CABIN_M3 = 1000               -- the pressurised volume
M.CABIN_K = 297                 -- the cabin air, 24 °C
M.PACK_KG_S = 1.2               -- one pack at high flow
M.VALVE_M2 = 0.1                -- one outflow valve fully open (effective area)
M.LEAK_M2 = 0.004               -- the fuselage
M.RELIEF_M2, M.RELIEF_FULL_DP = 0.05, 0.25  -- the positive relief valves, full open 0.25 psi above
M.NEG_RELIEF_M2 = 0.3           -- the negative relief doors
M.DEPRES_SLOW_M2, M.DEPRES_FAST_M2 = 0.01, 0.6  -- X-Plane's slow and fast decompression failures
M.AUTO_TRAVEL_S = 6             -- an outflow valve, closed to open, on its AC motor (automatic;
                                -- slower, the cabin bumps up at rotation)
M.MAN_TRAVEL_S = 20             -- on its DC motor (manual)
M.TRACK_S = 20                  -- the controller closes on its schedule this fast
M.DESCENT_FMC_FPM = 750         -- the cabin's descent on the FMC schedule at most
M.TRANSFER_S = 5                -- the rate fault holds this long before the other takes over
M.RATE_LAG_S = 1.0              -- the cabin rate display
M.INIT_S = 3                    -- a new flight's first seconds set the cabin to the airplane's
                                -- state, on the ground below 50 ft above it (XTLua's first reads
                                -- of the other modules' data are 0; the air/ground can be late)
M.INIT_AGL_FT = 50
M.AIR_START_FPM, M.AIR_START_S = 1000, 60   -- a flight started in the air: on until the airplane
                                -- settles (X-Plane's air start can drop it thousands of feet)

-- ======== the standard atmosphere (not in the sources; ATA21 p.425 checks it:
-- 0 ft 14.7, 10,000 ft 10.11, 30,000 ft 4.36, 45,000 ft 2.14 psia)
local P0, LAPSE, EXPN = 14.6959, 6.87559e-6, 5.25588
local H_TROP, P_TROP, H_SCALE = 36089.24, 3.28264, 20806.7
local PSI = 6894.757            -- Pa
local R_AIR, GAMMA = 287.05, 1.4

function M.p_of_ft(h)
    if h <= H_TROP then return P0 * (1 - LAPSE * h) ^ EXPN end
    return P_TROP * math.exp(-(h - H_TROP) / H_SCALE)
end

function M.ft_of_p(p)
    if p <= 0 then return 99999 end
    if p >= P_TROP then return (1 - (p / P0) ^ (1 / EXPN)) / LAPSE end
    return H_TROP - H_SCALE * math.log(p / P_TROP)
end

-- the pressure change of fpm feet per minute at sea level, psi per second
local SL_PSI_PER_FT = P0 * EXPN * LAPSE
local function sl_fpm(fpm) return fpm * SL_PSI_PER_FT / 60 end

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local function travel(pos, target, seconds, dt)
    local step = dt / seconds
    if pos < target then return math.min(target, pos + step) end
    return math.max(target, pos - step)
end

-- mass flow (kg/s) through an orifice of effective area a (m²) from the
-- cabin at pc to the outside at pa (psi): negative when the air comes in
local CHOKED = math.sqrt(GAMMA) * (2 / (GAMMA + 1)) ^ ((GAMMA + 1) / (2 * (GAMMA - 1)))
local SQRT_RT = math.sqrt(R_AIR * M.CABIN_K)
local function orifice(a, pc, pa)
    if a <= 0 or pc == pa then return 0 end
    local up, dn, sign = pc, pa, 1
    if pa > pc then up, dn, sign = pa, pc, -1 end
    local r = dn / up
    local k
    if r <= 0.5283 then k = CHOKED
    else k = math.sqrt(2 * GAMMA / (GAMMA - 1) * (r ^ (2 / GAMMA) - r ^ ((GAMMA + 1) / GAMMA))) end
    return sign * a * up * PSI * k / SQRT_RT
end

function M.inputs()
    return {
        p_amb = P0,                     -- outside static pressure, psi
        alt = 0,                        -- aircraft pressure altitude, ft
        vs = 0,                         -- vertical speed, fpm
        gs_kt = 0,                      -- ground speed
        on_ground = true,               -- the air/ground relays
        agl_ft = 0,                     -- height above the ground (a new flight's first seconds)
        baro_inhg = 29.92,              -- the captain's altimeter setting (FCOM p.608)
        -- the FMC (nil: none)
        fmc_crz_ft = nil,               -- cruise altitude
        fmc_dep_ft = nil,               -- departure and destination field elevations
        fmc_dest_ft = nil,
        from_dep_nm = 0,                -- distance flown from the departure and left to the destination
        to_dest_nm = 0,
        -- CABIN ALTITUDE panel (M181)
        ldg_auto = true,                -- LDG ALT AUTO (false: MAN)
        ldg_steps = 0,                  -- LDG ALT knob steps (50 ft) turned since the last frame
        auto_select = 0,                -- AUTO SELECT: 0 NORM, 1 A, 2 B
        man = {false, false},           -- MAN L, R
        man_cmd = 0,                    -- OPEN (1) or CLOSE (-1) held
        -- power (ATA21 p.437, p.449)
        dc = {true, true},              -- DC bus 1 (CPC A), DC bus 2 (CPC B)
        any_ac = true,                  -- the valves' AC motors (their buses are not in the sources)
        bat = true,                     -- battery bus (CABIN PRESS MAN)
        apu_hot_bat = true,             -- APU hot battery bus (the valves' DC motors)
        -- air
        pack_flow = 0,                  -- the packs' flow, in packs at high flow (the pack model)
        packs_selected = 3,             -- PACK selectors not OFF (PRESS RELIEF)
        extra_out_kg_s = 0,             -- other air overboard (equipment cooling OVRD)
        depres_slow = false,            -- X-Plane's decompression failures
        depres_fast = false,
        cpc_failed = {false, false},    -- failure: CPC A, B
    }
end

function M.new()
    local s = {t = 0, first = true, p_cab = P0, rate_fpm = 0, mode = M.GROUND,
        valve = {1, 1}, man_on = {false, false},
        norm_cpc = 1, cpc_fault = {false, false}, off_t = {0, 0}, rate_fault_t = 0, active = 1,
        -- the schedule's anchors
        p_start = P0, p_cab_start = P0, crz_ft = M.INT_CRUISE_FT, use_fmc = false, max_alt = 0,
        p_hold = P0, crz_ref = 0, p_des = P0, p_cab_des = P0, dp_des = 0, min_alt = 0,
        level_t = 0, hold = false, hold_alt = 0, hold_t = 0, landed_t = 0, reached_cruise = false,
        limiter = false, clamp = false, ldg_man = M.LDG_DEFAULT_FT, was_auto = true, last_gs = 0,
        air_start = false}
    s.out = {p_cab = P0, cabin_ft = 0, rate_fpm = 0, dp = 0, valve = {1, 1}, mode = M.GROUND,
        active = 1, ldg_ft = M.LDG_DEFAULT_FT, ldg_fmc = false, relief_open = false,
        neg_relief_open = false, cruise_clamp = false, limiter = false,
        cabin_alert = false, auto_alert = false, outflow_alert = {false, false},
        ldg_alert = false, relief_alert = false, cpc_alert = {false, false}}
    return s
end

-- the FMC's landing altitude: the departure field until 400 NM from it, half
-- way, T/C (the cruise reached) or T/D (the descent), then the destination
-- (FCOM p.1400, p.993). No approach is selected in this FMC, so the
-- destination is its field elevation.
local function fmc_landing(s, inp)
    if inp.fmc_dest_ft == nil then return inp.fmc_dep_ft end
    if inp.fmc_dep_ft == nil then return inp.fmc_dest_ft end
    if inp.from_dep_nm > M.FMC_SWITCH_NM or inp.from_dep_nm > inp.to_dest_nm
        or s.reached_cruise or s.mode == M.DESCENT then
        return inp.fmc_dest_ft
    end
    return inp.fmc_dep_ft
end

-- the cabin pressure of the cruise: the schedule's ΔP at the cruise
-- altitude, not below the fields, the cabin at 8,000 ft at most (FCOM
-- p.608; estimate: ATA21 p.424-425 give an example, not the table)
local function cruise_cabin(crz_ft, p_floor)
    local p = math.min(M.p_of_ft(crz_ft) + M.CRUISE_DP, p_floor)
    return math.max(p, M.p_of_ft(M.MAX_CABIN_FT))
end

-- the cabin's net outflow (kg/s) at cabin pressure pc, with the valves at
-- their areas, the leaks and the relief valves; the relief areas come back
-- in rel (positive, negative)
local function outflow(pc, pa, valve_m2, leak_m2, extra, rel)
    local dp = pc - pa
    local pos = M.RELIEF_M2 * clamp((dp - M.RELIEF_DP) / M.RELIEF_FULL_DP, 0, 1)
    local neg = M.NEG_RELIEF_M2 * clamp((-dp - M.NEG_RELIEF_DP[1]) / (M.NEG_RELIEF_DP[2] - M.NEG_RELIEF_DP[1]), 0, 1)
    if rel then rel[1], rel[2] = pos, neg end
    if dp <= 0 then extra = 0 end
    return orifice(valve_m2 + leak_m2 + pos + neg, pc, pa) + extra
end

local relief = {0, 0}

function M.update(s, inp, dt)
    local out = s.out
    if inp.p_amb < 1 then return out end    -- no air data yet
    s.t = s.t + dt
    if s.t <= M.INIT_S or (s.air_start and math.abs(inp.vs) > M.AIR_START_FPM and s.t < M.AIR_START_S) then
        s.first = true
    end
    local pa = inp.p_amb
    local vol = M.CABIN_M3 / (R_AIR * M.CABIN_K)    -- kg per Pa

    -- ======== landing altitude: AUTO from the FMC (2,000 ft without it),
    -- MAN from the knob in 50 ft steps; the knob starts from the AUTO value
    -- (estimate) (FCOM p.573, p.608)
    local fmc_ldg = fmc_landing(s, inp)
    if inp.ldg_auto then
        s.was_auto = true
        if fmc_ldg ~= nil then out.ldg_ft = fmc_ldg else out.ldg_ft = M.LDG_DEFAULT_FT end
    else
        if s.was_auto then s.ldg_man = math.floor(out.ldg_ft / M.LDG_STEP_FT + 0.5) * M.LDG_STEP_FT end
        s.was_auto = false
        s.ldg_man = clamp(s.ldg_man + inp.ldg_steps * M.LDG_STEP_FT, M.LDG_MIN_FT, M.LDG_MAX_FT)
        out.ldg_ft = s.ldg_man
    end
    out.ldg_fmc = inp.ldg_auto and fmc_ldg ~= nil
    -- the field's pressure from the captain's setting (FCOM p.608)
    local p_land = M.p_of_ft(out.ldg_ft + M.ft_of_p(inp.baro_inhg * 0.4911541))
    -- the FMC's data are used in AUTO only (FCOM p.608)
    local use_fmc = out.ldg_fmc and inp.fmc_crz_ft ~= nil

    -- ======== controllers: A on DC bus 1, B on DC bus 2; NORM changes over
    -- at each landing and starts with A at power up; the other takes over
    -- after 2 s without power, at 2,000 fpm with the airplane level, above
    -- 9.07 psi ΔP (ATA21 p.426, p.432, p.436-437; FCOM p.574)
    local ok = {}
    for c = 1, 2 do
        if inp.dc[c] then s.off_t[c] = 0 else s.off_t[c] = s.off_t[c] + dt end
        if s.off_t[c] > M.POWER_LOSS_S then s.cpc_fault[c] = false end     -- power off clears it
        ok[c] = s.off_t[c] <= M.POWER_LOSS_S and not inp.cpc_failed[c] and not s.cpc_fault[c]
    end
    if s.off_t[1] > M.POWER_LOSS_S and s.off_t[2] > M.POWER_LOSS_S then s.norm_cpc = 1 end
    local want = (inp.auto_select == 1 and 1) or (inp.auto_select == 2 and 2) or s.norm_cpc
    if ok[want] then s.active = want elseif ok[3 - want] then s.active = 3 - want else s.active = 0 end
    local both_man = inp.bat and inp.man[1] and inp.man[2]
    local auto = s.active > 0 and not both_man and inp.any_ac

    -- ======== modes (FCOM p.607-608; ATA21 p.412, p.428-436)
    local alt = inp.alt
    if math.abs(inp.vs) < M.LEVEL_FPM and not inp.on_ground then s.level_t = s.level_t + dt else s.level_t = 0 end
    local function enter_climb()
        s.mode = M.CLIMB
        s.p_start, s.p_cab_start, s.max_alt = pa, s.p_cab, alt
        s.use_fmc = use_fmc
        if use_fmc and inp.fmc_crz_ft > alt then s.crz_ft = inp.fmc_crz_ft
        else s.crz_ft = math.max(M.INT_CRUISE_FT, alt) end
    end
    local function enter_descent()
        s.mode = M.DESCENT
        s.p_des, s.p_cab_des, s.dp_des, s.min_alt = pa, s.p_cab, s.p_cab - pa, alt
        s.hold, s.hold_t, s.hold_alt = false, 0, alt
    end
    if s.first then
        if inp.agl_ft < M.INIT_AGL_FT then
            s.p_cab, s.mode, s.reached_cruise, s.clamp, s.air_start = pa, M.GROUND, false, false, false
        else
            -- a flight started in the air: the cabin as in cruise here (estimate)
            s.p_cab = math.min(cruise_cabin(alt, p_land), pa + M.CRUISE_DP)
            s.mode, s.crz_ref, s.p_hold, s.reached_cruise = M.CRUISE, alt, s.p_cab, true
            s.clamp, s.air_start = alt > M.CLAMP_FT, true
        end
    end
    local was = s.mode
    if s.first then
        -- no mode change while the flight starts
    elseif inp.on_ground then
        if was == M.CLIMB or was == M.CRUISE or was == M.DESCENT then
            s.mode, s.landed_t = M.LANDED, 0
            s.norm_cpc = 3 - s.norm_cpc
        end
        if s.mode == M.LANDED then
            -- until the cabin is down to the outside (what the packs' air
            -- holds through open valves is a few hundredths of a psi)
            s.landed_t = s.landed_t + dt
            if s.landed_t >= M.LANDED_S and math.abs(s.p_cab - pa) < 0.05 then s.mode = M.GROUND end
        end
        -- takeoff when accelerating through 65 kt (not on the landing roll)
        if s.mode == M.GROUND and inp.gs_kt > M.TAKEOFF_KT and s.last_gs <= M.TAKEOFF_KT then s.mode = M.TAKEOFF
        elseif s.mode == M.TAKEOFF and inp.gs_kt < M.TAKEOFF_KT then s.mode = M.GROUND end
        s.clamp = false
    else
        if was == M.GROUND or was == M.TAKEOFF or was == M.LANDED then
            s.reached_cruise = false
            enter_climb()
        elseif was == M.CLIMB then
            s.max_alt = math.max(s.max_alt, alt)
            local level = (s.use_fmc and math.abs(alt - s.crz_ft) < M.CRUISE_BAND_FT)
                or (not s.use_fmc and s.level_t >= M.LEVEL_S)
            if level then
                s.mode, s.crz_ref, s.p_hold, s.reached_cruise = M.CRUISE, alt, s.p_cab, true
            elseif alt < s.max_alt - M.DESCENT_FT then
                enter_descent()     -- a descent before the cruise (estimate)
            end
        elseif was == M.CRUISE then
            if alt > s.crz_ref + M.HOLD_EXIT_FT then enter_climb()
            elseif alt < s.crz_ref - M.DESCENT_FT then enter_descent() end
        elseif was == M.DESCENT then
            s.min_alt = math.min(s.min_alt, alt)
            if math.abs(alt - s.hold_alt) < M.HOLD_FT then s.hold_t = s.hold_t + dt
            else s.hold_t, s.hold_alt = 0, alt end
            if s.hold_t >= M.HOLD_S then s.hold = true end
            if s.hold and math.abs(alt - s.hold_alt) > M.HOLD_EXIT_FT then
                if alt > s.hold_alt then enter_climb() else enter_descent() end
            elseif not s.hold and alt > s.min_alt + M.HOLD_EXIT_FT then
                enter_climb()
            end
        end
        -- the ECS card's cruise clamp: the cruise (FMC altitude or 45 s
        -- level) above 25,000 ft, held through step climbs; off in descent
        -- until a level-off there (ATA21 p.382, p.386-387)
        if s.mode == M.DESCENT then
            s.clamp = s.hold
        elseif alt > M.CLAMP_FT and (s.mode == M.CRUISE or s.level_t >= M.LEVEL_S
            or (use_fmc and math.abs(alt - inp.fmc_crz_ft) < M.CRUISE_BAND_FT)) then
            s.clamp = true
        end
    end
    s.last_gs = inp.gs_kt
    out.mode = s.mode
    out.cruise_clamp = s.clamp

    -- ======== the schedule: a target cabin pressure and the rates to it
    local target, climb_lim, descent_lim = pa, sl_fpm(M.LANDED_FAST_FPM), sl_fpm(M.LANDED_FAST_FPM)
    if s.mode == M.TAKEOFF then
        target = M.p_of_ft(M.ft_of_p(pa) - M.PREPRESS_FT)
        climb_lim, descent_lim = sl_fpm(M.PREPRESS_FPM), sl_fpm(M.PREPRESS_FPM)
    elseif s.mode == M.LANDED then
        if s.landed_t < M.LANDED_S then climb_lim = sl_fpm(M.LANDED_FPM) end
    elseif s.mode == M.CLIMB then
        -- from the takeoff field to the cruise cabin as the airplane climbs;
        -- the cruise cabin not below the takeoff or the landing field
        local p_crz = M.p_of_ft(s.crz_ft)
        local progress = clamp((s.p_start - pa) / math.max(0.01, s.p_start - p_crz), 0, 1)
        target = s.p_cab_start + (cruise_cabin(s.crz_ft, math.max(p_land, s.p_start)) - s.p_cab_start) * progress
        if s.use_fmc then climb_lim = sl_fpm(M.CLIMB_FMC_FPM) else climb_lim = sl_fpm(M.CLIMB_INT_FPM) end
        descent_lim = climb_lim
    elseif s.mode == M.CRUISE then
        -- the cabin held (FCOM p.608)
        target = math.max(s.p_hold, M.p_of_ft(M.MAX_CABIN_FT))
        climb_lim, descent_lim = sl_fpm(M.CLIMB_INT_FPM), sl_fpm(M.CLIMB_INT_FPM)
    elseif s.mode == M.DESCENT then
        local p_cab_land = M.p_of_ft(M.ft_of_p(p_land) - M.PREPRESS_FT)
        if s.hold then
            -- on toward the landing field, but not past the ΔP of the descent's start
            target = math.min(p_cab_land, pa + math.max(0, s.dp_des))
        elseif use_fmc then
            -- with the airplane's descent, to the field at touchdown
            local progress = clamp((pa - s.p_des) / math.max(0.01, p_land - s.p_des), 0, 1)
            target = s.p_cab_des + (p_cab_land - s.p_cab_des) * progress
        else
            target = p_cab_land
        end
        if use_fmc then climb_lim, descent_lim = sl_fpm(M.DESCENT_FMC_FPM), sl_fpm(M.DESCENT_FMC_FPM)
        else climb_lim, descent_lim = sl_fpm(M.DESCENT_INT_FPM), sl_fpm(M.DESCENT_INT_FPM) end
    end
    if s.mode ~= M.GROUND and s.mode ~= M.LANDED and s.mode ~= M.TAKEOFF then
        target = clamp(target, pa, pa + M.CRUISE_DP)
    end
    local want_rate = clamp((target - s.p_cab) / M.TRACK_S, -climb_lim, descent_lim)   -- psi/s
    -- above the most ΔP the cabin climbs, and above the airplane it comes
    -- down, as fast as it must (estimate)
    if s.mode ~= M.GROUND and s.mode ~= M.LANDED then
        if s.p_cab - pa > M.MAX_DP then want_rate = math.min(want_rate, (pa + M.MAX_DP - s.p_cab) / 5) end
        if s.p_cab < pa then want_rate = math.max(want_rate, (pa - s.p_cab) / 5) end
    end

    -- ======== outflow valves: MAN on the battery bus stops the AC motor and
    -- moves the valve on its DC motor while OPEN/CLOSE is held; the
    -- controller sets the others to the area that gives its rate; the ICU's
    -- limiter closes them at 11,000 ft (FCOM p.574, p.608; ATA21 p.406,
    -- p.442, p.446-448)
    local cabin_ft = M.ft_of_p(s.p_cab)
    if cabin_ft > M.LIMITER_FT then s.limiter = true
    elseif cabin_ft < M.LIMITER_FT - M.LIMITER_OFF_FT then s.limiter = false end
    local leak_m2 = M.LEAK_M2
    if inp.depres_slow then leak_m2 = leak_m2 + M.DEPRES_SLOW_M2 end
    if inp.depres_fast then leak_m2 = leak_m2 + M.DEPRES_FAST_M2 end
    local m_in = inp.pack_flow * M.PACK_KG_S
    local man_m2, n_auto = 0, 0
    for v = 1, 2 do
        s.man_on[v] = inp.bat and inp.man[v]
        if s.man_on[v] then
            if inp.apu_hot_bat and inp.man_cmd ~= 0 then
                s.valve[v] = travel(s.valve[v], inp.man_cmd > 0 and 1 or 0, M.MAN_TRAVEL_S, dt)
            end
            man_m2 = man_m2 + s.valve[v] * M.VALVE_M2
        else
            n_auto = n_auto + 1
        end
    end
    if n_auto > 0 and auto then
        local pos
        if s.mode == M.GROUND then
            pos = 1
        elseif s.limiter then
            pos = 0
        else
            -- the outflow the rate needs, less what goes out elsewhere, over
            -- what one square metre of valve passes
            local need = m_in - vol * want_rate * PSI - outflow(s.p_cab, pa, man_m2, leak_m2, inp.extra_out_kg_s)
            local per_m2 = orifice(1, s.p_cab, pa)
            if math.abs(per_m2) < 1e-6 then pos = (need > 0) and 1 or 0
            else pos = clamp(need / per_m2 / (n_auto * M.VALVE_M2), 0, 1) end
        end
        for v = 1, 2 do
            if not s.man_on[v] then
                if s.first then s.valve[v] = pos else s.valve[v] = travel(s.valve[v], pos, M.AUTO_TRAVEL_S, dt) end
            end
        end
    end
    out.valve[1], out.valve[2] = s.valve[1], s.valve[2]
    out.limiter = s.limiter

    -- ======== the cabin: implicit step of p' = (in - out) / vol, solved by
    -- bisection (the outflow rises with the cabin pressure)
    local valve_m2 = (s.valve[1] + s.valve[2]) * M.VALVE_M2
    local p_old = s.p_cab
    local k = dt / (vol * PSI)      -- psi per kg
    local lo, hi = math.min(p_old, pa) - 1.5, math.max(p_old, pa) + 1.5
    for _ = 1, 30 do
        local mid = 0.5 * (lo + hi)
        local f = mid - p_old - k * (m_in - outflow(mid, pa, valve_m2, leak_m2, inp.extra_out_kg_s))
        if f > 0 then hi = mid else lo = mid end
    end
    s.p_cab = 0.5 * (lo + hi)
    outflow(s.p_cab, pa, valve_m2, leak_m2, inp.extra_out_kg_s, relief)
    out.relief_open = relief[1] > 0
    out.neg_relief_open = relief[2] > 0

    local new_ft = M.ft_of_p(s.p_cab)
    if dt > 0 then
        local rate = (new_ft - cabin_ft) / dt * 60
        if s.first then s.rate_fpm = 0
        else s.rate_fpm = s.rate_fpm + (rate - s.rate_fpm) * math.min(1, dt / M.RATE_LAG_S) end
        if math.abs(s.rate_fpm) < 0.01 then s.rate_fpm = 0 end
    end
    out.p_cab, out.cabin_ft, out.rate_fpm, out.dp = s.p_cab, new_ft, s.rate_fpm, s.p_cab - pa

    -- the controller's fault checks: the cabin at 2,000 fpm with the
    -- airplane level, or ΔP above 9.07 psi; the other takes over if it can
    -- (it keeps on when it sees the same: a leak, not a controller fault)
    if s.active > 0 and not inp.on_ground then
        if (math.abs(s.rate_fpm) > M.TRANSFER_FPM and math.abs(inp.vs) < 500) or out.dp > M.TRANSFER_DP then
            s.rate_fault_t = s.rate_fault_t + dt
        else
            s.rate_fault_t = 0
        end
        if s.rate_fault_t >= M.TRANSFER_S and ok[3 - s.active] then
            s.cpc_fault[s.active] = true
            ok[s.active] = false
            s.rate_fault_t = 0
        end
    else
        s.rate_fault_t = 0
    end
    out.active = s.active

    -- ======== messages (FCOM p.619-620; ATA21 p.444, p.451, p.454, p.470)
    out.cabin_alert = new_ft > M.CABIN_WARN_FT                       -- CABIN ALTITUDE
    out.auto_alert = s.active == 0 or both_man                       -- CABIN ALT AUTO
    for v = 1, 2 do                                                  -- OUTFLOW VLV L, R
        out.outflow_alert[v] = s.man_on[v] or s.active == 0 or not inp.any_ac
    end
    out.ldg_alert = not inp.ldg_auto or fmc_ldg == nil               -- LANDING ALT
    out.relief_alert = out.relief_open and inp.packs_selected == 3   -- PRESS RELIEF
    for c = 1, 2 do out.cpc_alert[c] = not ok[c] and not both_man end   -- STATUS CABIN ALT AUTO A, B

    s.first = false
    return out
end

return M
