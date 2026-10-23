-- 747-400 cabin and cargo temperatures without X-Plane: the zone
-- temperature controller (ZTC) and the trim air of the seven zones, the
-- pack outlet temperature set by the zone that needs the coolest air, the
-- backup without trim air, the comfort correction, the zone duct
-- overheats and ZONE RST, the aft cargo heat and the forward cargo
-- heaters, and the EICAS messages and lights of the temperature control.
-- The zones and the cargo compartments are simple heat balances: the
-- sources give no dynamics, so all their numbers are estimates.
-- Logic and sources: docs/overhaul/notes/ATA-21.md §2.2, §2.3, §4.3, §4.4
-- (FCOM p.554-557, p.577, p.591-592, p.602, p.620-621; ATA21 21-40,
-- 21-60).
--
--   local T = B747_temp_model             -- in XTLua, after dofile
--   local T = dofile(".../B747.55.temp_model.lua")   -- in the tests
--   local s = T.new()
--   local inp = T.inputs()                -- fill it every frame
--   local out = T.update(s, inp, dt)      -- the same table every frame

local M = setmetatable({}, {})
B747_temp_model = M

local function c_of_f(f) return (f - 32) * 5 / 9 end
M.c_of_f = c_of_f

-- the zones: flight deck, upper deck, main deck A-E (FCOM p.587)
M.ZONES = {"F/D", "U/D", "A", "B", "C", "D", "E"}
M.NZ, M.FD = 7, 1
M.SEL_MIN_C, M.SEL_MAX_C = c_of_f(65), c_of_f(85)  -- PASS TEMP and FLT DECK TEMP, C to W (FCOM p.554)
M.PACK_MIN_C, M.PACK_MIN_HIGH_C = c_of_f(35), c_of_f(28)   -- the pack outlet: 35°F, 28°F above
M.PACK_MAX_C = c_of_f(135)                         -- 25,000 ft; 135°F at most (ATA21 p.38, p.90)
M.HIGH_FT = 25000
M.BIAS_MAX_C = 4 * 5 / 9        -- comfort correction: +2°F an hour for two hours (+4°F), the target
M.BIAS_C_S = M.BIAS_MAX_C / 7200    -- at most 85°F, with the cruise clamp above 25,000 ft; out
M.BIAS_OUT_S = 300              -- within 5 min of the descent detect, then not again (ATA21 p.382-384)
M.OVHT_C, M.OVHT_S = c_of_f(185), 10   -- a duct overheat switch closes the master trim air valve,
                                       -- latched (ATA21 p.348, p.360)
M.HOT_C, M.HOT_S = c_of_f(165), 30     -- a duct sensor: TEMP ZONE (ATA21 p.360)
M.BACKUP_VALVE = 0.1            -- the zone trim valves in the backup (ATA21 p.368)
M.BACKUP_C = c_of_f(75)         -- the backup's target without any setting (FCOM p.592)
M.FD_MAX_C = c_of_f(85)         -- the flight deck at most, in the backup (ATA21 p.368)
M.SETTLED_C = 1                 -- the cruise clamp's normal flow waits for the cabin within 1°C of its
                                -- target (ATA21 p.386; the pack model)
M.ZONE_TEMP_S = 70              -- STATUS ZONE TEMP (ATA21 p.350)
M.CARGO_OVHT_C = c_of_f(90)     -- the aft cargo overheat switch (ATA21 p.234, p.240-244)
M.FWD_ON_C, M.FWD_OFF_C = c_of_f(40), c_of_f(50)   -- the forward cargo heaters' switch (ATA21 p.254)
M.FWD_N2 = 50                   -- the heaters need two engines above 50% (ATA21 p.256)
-- estimates (no value in the sources)
M.AFT_SEL_C = c_of_f(40)        -- the aft cargo: its select switch (40 or 65°F) is in the bulk cargo
M.CARGO_BAND_C = 5 / 9          -- the aft cargo thermal switches: 1°F either side
M.CENTRE_MIN_PSI = 12           -- trim air and the aft cargo heat need the centre duct (as the FCSOV)
M.CP = 1.005                    -- air, kJ/kg/K
M.SHARE = {0.03, 0.10, 0.09, 0.17, 0.22, 0.22, 0.17}       -- a zone's share of the air, the skin and the
                                                           -- heat capacity
M.LOAD_SHARE = {0.033, 0.10, 0.08, 0.16, 0.22, 0.23, 0.177}    -- of the heat load
M.LOAD_KW = 70                  -- people, lights, galleys, equipment: in the air or an engine running
M.LOAD_GND_KW = 30              -- on the ground with AC power and the engines off
M.SKIN_KW_K = 0.8               -- through the skin
M.VENT_KW_K = 3                 -- the doors open: on the ground, the engines off, no pack air
M.CABIN_KJ_K = 5000             -- the cabin's air, furnishings and linings
M.TRIM_K = 120                  -- a zone's trim valve full open lifts its supply this much
M.GAIN = 3                      -- the ZTC: the supply's change per degree of zone error
M.SUPPLY_MAX_C = c_of_f(160)    -- the warmest supply the ZTC asks for (the duct sensors' range,
                                -- ATA21 p.360)
M.PACK_LAG_S = 20               -- the pack outlet temperature
M.DUCT_LAG_S = 10               -- the duct sensors and switches
M.RECIRC_KG_S = 0.7             -- one recirculation fan (1360 cfm, ATA21 p.386)
M.CARGO_KJ_K = 2000             -- a cargo compartment (the aft one with the bulk)
M.CARGO_CABIN_KW_K = 0.4        -- the floor to the cabin
M.CARGO_SKIN_KW_K = 0.3
M.EE_KG_S = 0.5                 -- the equipment cooling exhaust into the forward cargo
M.EE_RISE_C = 15                -- its rise over the cabin
M.FWD_HEATER_KW = 3             -- the two forward cargo heaters
M.AFT_HEAT_KW = 10              -- the aft cargo heat
M.INIT_AGL_FT = 50              -- a flight started with an engine running or in the air: the cabin at
                                -- its targets
M.INIT_S = 3                    -- the start values are set again for the first seconds (XTLua's first
                                -- reads of the other modules' datarefs, the buses, are 0)

local function seven(v) return {v, v, v, v, v, v, v} end

function M.inputs()
    return {
        pass_sel = 0.5,             -- PASS TEMP, C 0 .. W 1
        fd_sel = 0.5,               -- FLT DECK TEMP, C 0 .. W 1
        trim_air = true,            -- TRIM AIR switch
        zone_rst = false,           -- ZONE RST pushed (this frame)
        aft_heat = false,           -- AFT CARGO HT switch
        aft_fire_arm = false,       -- AFT cargo fire ARM
        pack_kg_s = 0,              -- the packs' air
        packs_operating = 0,
        ptc = true,                 -- a pack temperature controller controls an operating pack
        fans = 0,                   -- recirculation fans running
        centre_psi = 0,             -- the centre duct: trim air and the aft cargo heat (FCOM p.591, p.602)
        alt_ft = 0,                 -- pressure altitude (the CPC's)
        agl_ft = 0,                 -- for the start only
        on_ground = true,
        cruise_clamp = false,       -- the ECS card's (the pressurization model)
        descent = false,            -- descent detect (the pressurization model)
        skin_c = 15,                -- the outside of the skin (the total air temperature)
        engines = 0,                -- engines running
        engines_n2 = 0,             -- engines above 50% N2
        ee_exhaust = false,         -- the equipment cooling exhaust into the forward cargo
        ac = true,                  -- the ZTC, the trim valves, the cargo valves and heaters (estimate)
        dc = true,                  -- the master trim air valve's control power (ATA21 p.348; the bus:
                                    -- estimate)
        ztc_failed = false,         -- failure: critical ZTC failure
        trim_valve_failed = false,  -- failure: the master trim air valve failed closed
        zone_valve_open = seven(false),     -- failure: a zone trim air valve failed open
    }
end

function M.new()
    local s = {t = 0, zone = seven(20), duct = seven(20), req = seven(0), pack = 20,
        cargo = {20, 20}, bias = 0, bias_done = false, bias_out = 0, last_sel = nil,
        overheat = false, ztc_fault = false, ovht_t = seven(0), hot_t = seven(0), status_t = 0,
        backup_c = M.BACKUP_C, fwd_switch = false, aft_switch = false, aft_ovht = false}
    s.out = {zone_c = seven(20), target_c = seven(20), target_shown = false, master_c = 0,
        cargo_c = {20, 20}, pack_c = 20, duct_c = seven(20), trim = seven(0), trim_valve = false,
        backup = true, settled = true, sys_fault = false, trim_air_off = false, temp_zone = false,
        zone_temp = false, aft_heat = false, aft_temp_light = false, cargo_heat_alert = false,
        fwd_heaters = false}
    return s
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- a heat balance over the frame, exact for constant surroundings: heat q
-- (kW), capacity c (kJ/K), conductances g1-g3 (kW/K) to t1-t3
local function balance(t, q, c, dt, g1, t1, g2, t2, g3, t3)
    local g = g1 + g2 + g3
    if g <= 0 then return t + q * dt / c end
    local eq = (g1 * t1 + g2 * t2 + g3 * t3 + q) / g
    return eq + (t - eq) * math.exp(-dt * g / c)
end

-- the supply a zone (or the passenger zones together) needs: the heat
-- balance at the target, and the ZTC's correction of the error
local function needed(target, t, air, load, skin_g, skin_c)
    return target - (load + skin_g * (skin_c - target)) / (air * M.CP) - M.GAIN * (t - target)
end

function M.update(s, inp, dt)
    s.t = s.t + dt
    local out = s.out
    local nz, share, load_share = M.NZ, M.SHARE, M.LOAD_SHARE
    local zone, target = s.zone, out.target_c

    -- the selectors (FCOM p.554)
    local master = M.SEL_MIN_C + clamp(inp.pass_sel, 0, 1) * (M.SEL_MAX_C - M.SEL_MIN_C)
    out.master_c = master

    -- the comfort correction of the passenger zones' targets (ATA21
    -- p.382-384; FCOM p.591): reset on the ground; PASS TEMP turned while
    -- it works cancels it for the flight (estimate: the sources say a
    -- reselection overrides it)
    if s.last_sel and math.abs(inp.pass_sel - s.last_sel) > 0.001 and s.bias > 0 then
        s.bias, s.bias_done = 0, true
    end
    s.last_sel = inp.pass_sel
    if inp.on_ground then
        s.bias, s.bias_done = 0, false
    elseif inp.descent and not s.bias_done then
        s.bias_done, s.bias_out = true, s.bias / M.BIAS_OUT_S
    end
    if s.bias_done then
        s.bias = math.max(0, s.bias - s.bias_out * dt)
    elseif inp.cruise_clamp and inp.alt_ft > M.HIGH_FT then
        s.bias = math.min(s.bias + M.BIAS_C_S * dt, M.BIAS_MAX_C)
    end
    target[M.FD] = M.SEL_MIN_C + clamp(inp.fd_sel, 0, 1) * (M.SEL_MAX_C - M.SEL_MIN_C)
    for z = 2, nz do target[z] = math.min(master + s.bias, M.SEL_MAX_C) end

    -- a new flight: parked at the outside temperature, or with an engine
    -- running or in the air at the targets (estimate)
    local init = s.t <= M.INIT_S
    local start = init and (inp.engines > 0 or inp.agl_ft > M.INIT_AGL_FT)
    if init then
        for z = 1, nz do
            zone[z] = start and target[z] or inp.skin_c
            s.duct[z] = zone[z]
        end
    end

    -- the ZTC and the master trim air valve (FCOM p.555, p.591; ATA21
    -- p.346-348, p.368): open with TRIM AIR on and a pack operating; a duct
    -- overheat (latched) or a critical ZTC failure closes it; ZONE RST
    -- resets them when they are gone. Without trim air (also with the
    -- centre duct isolated) the PTC controls the cabin in the backup
    if inp.ztc_failed then s.ztc_fault = true end
    if inp.zone_rst then
        local hot = false
        for z = 1, nz do if s.duct[z] > M.OVHT_C then hot = true end end
        if not hot then s.overheat = false end
        if not inp.ztc_failed then s.ztc_fault = false end
    end
    local packs = inp.packs_operating > 0
    local cmd_on = inp.trim_air and not s.overheat and not s.ztc_fault
    local cmd = cmd_on and packs and inp.ac and inp.dc
    local open = cmd and not inp.trim_valve_failed and inp.centre_psi >= M.CENTRE_MIN_PSI
    local backup = not open
    out.trim_valve, out.backup = open, backup
    out.target_shown = packs and not backup     -- PASS TEMP is always AUTO (FCOM p.577)
    if inp.ac and not s.ztc_fault then s.backup_c = master end

    -- the air into the zones: the packs' and the recirculation fans' (at
    -- the cabin's mean temperature); the heat load and the skin
    local pk, rc = inp.pack_kg_s, inp.fans * M.RECIRC_KG_S
    local air = pk + rc
    local mean, pmean, pshare, pload = 0, 0, 0, 0
    for z = 1, nz do
        mean = mean + share[z] * zone[z]
        if z ~= M.FD then
            pmean, pshare, pload = pmean + share[z] * zone[z], pshare + share[z], pload + load_share[z]
        end
    end
    pmean = pmean / pshare
    local load = 0
    if not inp.on_ground or inp.engines > 0 then load = M.LOAD_KW elseif inp.ac then load = M.LOAD_GND_KW end
    local skin_g = M.SKIN_KW_K
    if inp.on_ground and inp.engines == 0 and pk <= 0 then skin_g = skin_g + M.VENT_KW_K end

    -- the pack outlet: the coolest supply the zones need, or in the backup
    -- the mean of the passenger zones at the PASS TEMP setting (the last
    -- one with the ZTC failed; FCOM p.592) and the flight deck at most
    -- 85°F; within 35°F (28°F above 25,000 ft) and 135°F (FCOM p.554,
    -- p.591-592; ATA21 p.38, p.90, p.362, p.368)
    local req = s.req
    local btarget = (inp.ac and not s.ztc_fault) and master or s.backup_c
    local cmd_c = s.pack
    if air > 0 then
        local demand
        if backup then
            demand = math.min(needed(btarget, pmean, air * pshare, load * pload, skin_g * pshare, inp.skin_c),
                needed(M.FD_MAX_C, zone[M.FD], air * share[M.FD], load * load_share[M.FD],
                    skin_g * share[M.FD], inp.skin_c))
        else
            for z = 1, nz do
                req[z] = needed(target[z], zone[z], air * share[z], load * load_share[z], skin_g * share[z], inp.skin_c)
                if not demand or req[z] < demand then demand = req[z] end
            end
        end
        if pk > 0 then
            local lo = inp.alt_ft > M.HIGH_FT and M.PACK_MIN_HIGH_C or M.PACK_MIN_C
            cmd_c = clamp((demand * air - rc * mean) / pk, lo, M.PACK_MAX_C)
        end
    end
    if init then
        s.pack = start and cmd_c or inp.skin_c
    elseif pk > 0 and inp.ptc then
        s.pack = s.pack + (cmd_c - s.pack) * (1 - math.exp(-dt / M.PACK_LAG_S))
    end
    out.pack_c = s.pack

    -- each zone's supply: the mixed air, and trim air from its valve (10%
    -- in the backup, no air with the master valve closed; ATA21 p.362,
    -- p.368); the duct sensors and the overheat switches (ATA21 p.360)
    local mix = mean
    if air > 0 then mix = (pk * s.pack + rc * mean) / air end
    local hot = false
    for z = 1, nz do
        local valve = M.BACKUP_VALVE
        if not backup then valve = clamp((req[z] - mix) / M.TRIM_K, 0, (M.SUPPLY_MAX_C - mix) / M.TRIM_K) end
        if inp.zone_valve_open[z] then valve = 1 end
        out.trim[z] = valve
        local supply = mix
        if open then supply = mix + valve * M.TRIM_K end
        if air <= 0 then supply = zone[z] end
        s.duct[z] = s.duct[z] + (supply - s.duct[z]) * (1 - math.exp(-dt / M.DUCT_LAG_S))
        out.duct_c[z] = s.duct[z]
        if s.duct[z] > M.OVHT_C then s.ovht_t[z] = s.ovht_t[z] + dt else s.ovht_t[z] = 0 end
        if s.ovht_t[z] >= M.OVHT_S then s.overheat = true end
        if s.duct[z] > M.HOT_C then s.hot_t[z] = s.hot_t[z] + dt else s.hot_t[z] = 0 end
        if s.hot_t[z] >= M.HOT_S then hot = true end
        zone[z] = balance(zone[z], load * load_share[z], M.CABIN_KJ_K * share[z], dt,
            air * share[z] * M.CP, supply, skin_g * share[z], inp.skin_c, 0, 0)
        out.zone_c[z] = zone[z]
    end

    -- the cargo compartments (FCOM p.557, p.602; ATA21 p.232-256). Forward:
    -- the equipment cooling exhaust, and two heaters on a 40/50°F switch
    -- with the exhaust valve open and two engines above 50%. Aft: the
    -- override valve opens with AFT CARGO HT unless above 90°F or AFT fire
    -- ARM; the control valve also needs an engine running and opens below
    -- the selected temperature
    local fwd, aft = s.cargo[1], s.cargo[2]
    if init then
        local ee = inp.ee_exhaust and M.EE_KG_S * M.CP or 0
        fwd = balance(fwd, 0, M.CARGO_KJ_K, math.huge, M.CARGO_CABIN_KW_K, mean, M.CARGO_SKIN_KW_K,
            inp.skin_c, ee, mean + M.EE_RISE_C)
        aft = balance(aft, 0, M.CARGO_KJ_K, math.huge, M.CARGO_CABIN_KW_K, mean, M.CARGO_SKIN_KW_K,
            inp.skin_c, 0, 0)
    end
    if fwd < M.FWD_ON_C then s.fwd_switch = true elseif fwd > M.FWD_OFF_C then s.fwd_switch = false end
    local heaters = s.fwd_switch and inp.ee_exhaust and inp.engines_n2 >= 2 and inp.ac
    if aft > M.CARGO_OVHT_C then s.aft_ovht = true
    elseif aft < M.CARGO_OVHT_C - M.CARGO_BAND_C then s.aft_ovht = false end
    if aft < M.AFT_SEL_C - M.CARGO_BAND_C then s.aft_switch = true
    elseif aft > M.AFT_SEL_C + M.CARGO_BAND_C then s.aft_switch = false end
    local override = inp.aft_heat and inp.ac and not inp.aft_fire_arm and not s.aft_ovht
    local aft_heat = override and inp.engines > 0 and s.aft_switch and inp.centre_psi >= M.CENTRE_MIN_PSI
    s.cargo[1] = balance(fwd, heaters and M.FWD_HEATER_KW or 0, M.CARGO_KJ_K, dt,
        M.CARGO_CABIN_KW_K, mean, M.CARGO_SKIN_KW_K, inp.skin_c,
        inp.ee_exhaust and M.EE_KG_S * M.CP or 0, mean + M.EE_RISE_C)
    s.cargo[2] = balance(aft, aft_heat and M.AFT_HEAT_KW or 0, M.CARGO_KJ_K, dt,
        M.CARGO_CABIN_KW_K, mean, M.CARGO_SKIN_KW_K, inp.skin_c, 0, 0)
    out.cargo_c[1], out.cargo_c[2] = s.cargo[1], s.cargo[2]
    out.fwd_heaters, out.aft_heat = heaters, aft_heat

    -- lights and messages (FCOM p.555, p.557, p.620-621; ATA21 p.244,
    -- p.252, p.350, p.360, p.380): >TRIM AIR OFF with the valve switched
    -- off or commanded closed, not with all packs off; TEMP ZONE with a
    -- duct overheat, a ZTC failure or the valve failed closed; ZONE SYS
    -- FAULT also with TRIM AIR off and with the valve closed while pack air
    -- flows; the aft cargo TEMP light (not on the ground) and TEMP CARGO
    -- HEAT with the heat operating
    out.trim_air_off = packs and not cmd_on
    out.temp_zone = s.overheat or s.ztc_fault or (cmd and inp.trim_valve_failed) or hot
    out.sys_fault = not inp.trim_air or s.overheat or s.ztc_fault or (packs and not open)
    local lru = s.ztc_fault or inp.trim_valve_failed
    for z = 1, nz do if inp.zone_valve_open[z] then lru = true end end
    if lru then s.status_t = s.status_t + dt else s.status_t = 0 end
    out.zone_temp = s.status_t >= M.ZONE_TEMP_S
    out.aft_temp_light = s.aft_ovht and not inp.on_ground
    out.cargo_heat_alert = s.aft_ovht and inp.aft_heat and inp.engines > 0

    -- the cabin at its target, for the pack model's cruise clamp (the
    -- passenger zones; estimate: each of them)
    local settled = true
    if packs and backup then settled = math.abs(pmean - btarget) <= M.SETTLED_C
    elseif packs then
        for z = 2, nz do if math.abs(zone[z] - target[z]) > M.SETTLED_C then settled = false end end
    end
    out.settled = settled
    return out
end

return M
