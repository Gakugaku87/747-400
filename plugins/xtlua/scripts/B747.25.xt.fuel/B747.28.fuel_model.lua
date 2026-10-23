-- 747-400 fuel system without X-Plane: the tanks, the pumps and valves (as
-- tables), the fuel system management (FSMC: crossfeed 2 and 3, override/
-- jettison pumps 2 and 3, reserve, scavenge and stabilizer transfer), the
-- jettison control (FJCC), the manifold that decides which tank feeds which
-- engine (pressure order, crossfeed valves, suction feed), the quantities,
-- and what the crew sees (EICAS messages, overhead lights, pump and valve
-- states for the synoptic). Logic and sources: docs/overhaul/notes/ATA-28.md
-- (FCOM 12.10-12.30 p.1439-1480, airplane 109; ATA26_28 28-xx).
--
--   local F = B747_fuel_model              -- in XTLua, after dofile
--   local F = dofile(".../B747.28.fuel_model.lua")   -- in the tests
--   local s = F.new()
--   local inp = F.inputs()                 -- fill it every frame
--   s.qty.m1 = ...                         -- the tank quantities live in the state
--   local out = F.update(s, inp, dt)       -- the same table every frame

local M = setmetatable({}, {})
B747_fuel_model = M

M.TANKS = {"ctr", "m1", "m2", "m3", "m4", "r2", "r3", "stab"}
M.MAIN = {"m1", "m2", "m3", "m4"}
M.OJ = {"oj2_fwd", "oj2_aft", "oj3_fwd", "oj3_aft"}

-- values from the sources (kg, airplane 109)
M.STANDPIPE_OJ = 3200            -- override/jettison pumps 2 and 3 (FCOM p.1454)
M.CTR_PUMP_MIN = 1185            -- CWT pumps, about 390 gal (ATA26_28 p.335, p.443)
M.OUTBD_XFER_MIN = 3200          -- main 1 and 4 transfer down to (FCOM p.1464)
M.RES_XFER_AT = 18200            -- main 2 or 3 (FCOM p.1464, p.1467)
M.JETT_MAIN14_AT = 9072          -- main 2 or 3 during jettison (FCOM p.1464, p.1469)
M.JETT_BALANCE = 1814            -- main 2 and 3, 4,000 lb (ATA26_28 p.540)
M.STAB_XFER_CTR_MAX = 36470      -- (FCOM p.1466)
M.SCAV_MAIN_AT = 27200           -- jet pump scavenge into main 2 or 3 (FCOM p.1454)
M.SCAV_CTR_BELOW = 1814          -- the CWT float valve, about 4,000 lb (ATA26_28 p.512)
M.SCAV_KGH = 136                 -- each of the 4 jet pumps: about 1,200 lb/h in all (ATA26_28 p.512)
M.SHARED_CTR, M.SHARED_FF_KGH = 2300, 6800   -- shared flow (FCOM p.1466)
M.XFEED_TO_DELAY_S = 40          -- flaps in the takeoff range on the ground (ATA26_28 p.461)
M.DISAGREE_S = 10                -- crossfeed and reserve valves (ATA26_28 p.462, p.498)
M.VALVE_TRAVEL_S = 4             -- 3-5 s (ATA26_28 p.464)
-- EICAS values (FCOM p.1473-1479)
M.IMBAL14, M.IMBAL23, M.IMBAL_CLEAR = 1360, 2720, 450
M.CTR_LOW_PRESTART, M.CTR_LOW_CLIMB, M.CTR_LOW_CRUISE = 7700, 3200, 1300
M.CTR_OVD_GROUND, M.CTR_OVD_CRUISE = 7700, 1800
M.CTR_PRESS_DELAY_S, M.CTR_JETT_INHIBIT = 60, 900
M.STB_PMP_CRUISE = 500
M.QTY_LOW = 900
M.TANK_ENG_GROUND = 500          -- on the ground, FQIS BLK B (FCOM p.1478)
M.CLIMB_PITCH = 5                -- climb or cruise by pitch (FCOM NP p.133-134)
M.TEMP_LOW = -37
-- the flap lever range of flaps 10 and 20 (7.5-22.5 units: ATA26_28 p.461;
-- as flap_ratio, where 10 = 0.5 and 20 = 0.667: estimate)
M.FLAP_TO_MIN, M.FLAP_TO_MAX = 0.42, 0.75
-- estimates (no values in the sources)
M.RES_XFER_KGH = 3000            -- each reserve tank, by gravity
M.MAIN14_XFER_KGH = 4000         -- each outboard main tank, by gravity
M.STAB_PUMP_KGH = 4500           -- each stabilizer pump
M.JETT_PUMP_KGH = 22000          -- each pump through the jettison nozzles
M.APU_KGH = 150                  -- the APU's burn
M.STAB_LOW_OFF_S = 30            -- the stabilizer pump stops after low pressure (FCOM p.1455: "brief delay")
M.JETT_EST_KGH = 120000          -- preprogrammed jettison rate (FCOM p.1468)
M.JETT_UPDATE_S = 90             -- (FCOM p.1468)
-- pressure classes (FCOM p.1454): both CWT pumps above override/jettison 2
-- and 3 above main pumps; one CWT pump does not override them or an
-- outboard tank with both main pumps (against one main pump: estimate)
M.P_CTR2, M.P_OJ, M.P_MAIN2, M.P_CTR1, M.P_MAIN1 = 3.0, 2.0, 1.1, 1.05, 1.0

-- the pumps: tank, kind and power. Main pumps 2 and 3 FWD, override 2 and 3
-- FWD and CTR L are on the utility buses (FCOM p.801, p.795); which utility
-- bus, and the AC buses of the others, are estimates (no source).
M.PUMPS = {
    {id = "m1_fwd", tank = "m1", kind = "main", bus = "ac", n = 1},
    {id = "m1_aft", tank = "m1", kind = "main", bus = "ac", n = 1},
    {id = "m2_fwd", tank = "m2", kind = "main", bus = "util", n = 2},
    {id = "m2_aft", tank = "m2", kind = "main", bus = "ac", n = 2},
    {id = "m3_fwd", tank = "m3", kind = "main", bus = "util", n = 3},
    {id = "m3_aft", tank = "m3", kind = "main", bus = "ac", n = 3},
    {id = "m4_fwd", tank = "m4", kind = "main", bus = "ac", n = 4},
    {id = "m4_aft", tank = "m4", kind = "main", bus = "ac", n = 4},
    {id = "oj2_fwd", tank = "m2", kind = "oj", bus = "util", n = 1},
    {id = "oj2_aft", tank = "m2", kind = "oj", bus = "ac", n = 2},
    {id = "oj3_fwd", tank = "m3", kind = "oj", bus = "util", n = 4},
    {id = "oj3_aft", tank = "m3", kind = "oj", bus = "ac", n = 3},
    {id = "ctr_l", tank = "ctr", kind = "ctr", bus = "util", n = 2},
    {id = "ctr_r", tank = "ctr", kind = "ctr", bus = "ac", n = 3},
    {id = "stab_l", tank = "stab", kind = "stab", bus = "ac", n = 2},
    {id = "stab_r", tank = "stab", kind = "stab", bus = "ac", n = 3},
}
M.VALVES = {"x1", "x2", "x3", "x4", "s1", "s2", "s3", "s4", "res2a", "res2b", "res3a", "res3b",
    "xfer1", "xfer4", "jett_ctr_l", "jett_ctr_r", "jett_m2", "jett_m3", "noz_l", "noz_r", "apu"}
M.SIDE = {m1 = "L", m2 = "L", m3 = "R", m4 = "R", ctr = "C"}

local function flags(keys, v)
    local t = {}
    for _, k in ipairs(keys) do t[k] = v end
    return t
end
local PUMP_IDS = {}
for i, p in ipairs(M.PUMPS) do PUMP_IDS[i] = p.id end

function M.inputs()
    return {
        has_stab = true,                       -- the stabilizer tank (109)
        cap = {ctr = 52167, m1 = 13622, m2 = 38132, m3 = 38132, m4 = 13622, r2 = 4018, r3 = 4018, stab = 10030},
        sw = flags(PUMP_IDS, false),           -- pump switches ON (override, CTR, STAB too)
        xfeed = {true, true, true, true},      -- X FEED switches ON
        xfer_main14 = false,                   -- FUEL XFER MAIN 1 & 4 ON
        jett_sel = 0,                          -- 0 OFF, 1 A, 2 B
        nozzle = {false, false},               -- jettison NOZZLE L, R ON
        ftr = 0,                               -- fuel to remain, kg
        fuel_control = {false, false, false, false},  -- RUN
        fire_out = {false, false, false, false},
        ac = {false, false, false, false}, util = {false, false, false, false},
        dc = {false, false, false, false},
        main_bat = false, hot_bat = false, gs_bus = false,
        apu_bat = false,                       -- APU battery bus (the APU DC fuel pump)
        on_ground = true, flap_lever = 0, pitch = 0,
        ff = {0, 0, 0, 0},                     -- engine fuel flow, kg/s
        running = {false, false, false, false},  -- engine running
        apu_fuel = false,                      -- the APU wants fuel (starting or running)
        temp = 15,                             -- fuel temperature, °C
    }
end

function M.new()
    local s = {t = 0, first = true, qty = {}, valve = {}, cmd = {},
        xfeed_to_t = 0, xfeed_close = false, disagree_t = {}, res_open = false,
        stab_low_t = {stab_l = 0, stab_r = 0}, stab_tripped = {stab_l = false, stab_r = false},
        ctr_low_t = {0, 0}, imbal = {}, tank_eng_reached = false,
        jett_active = false, jett_done = false, jett_t = 0, jett_start_qty = 0,
        ovrd_after_jett = flags(M.OJ, false)}
    for _, t in ipairs(M.TANKS) do s.qty[t] = 0 end
    for _, v in ipairs(M.VALVES) do s.valve[v], s.disagree_t[v] = 0, 0 end
    s.out = {qty = s.qty, valve = s.valve, cmd = s.cmd, pump = {}, low = {}, feed = {{}, {}, {}, {}},
        suction = {false, false, false, false}, has_fuel = {false, false, false, false},
        cas = {}, light = {}, flow = {}, total = 0}
    return s
end

-- a motor-driven valve moves only with power and holds its place without
-- (ATA26_28 p.454, p.464)
local function move(s, name, open, powered, dt)
    s.cmd[name] = open
    if powered then
        local step = dt / M.VALVE_TRAVEL_S
        if open then s.valve[name] = math.min(1, s.valve[name] + step)
        else s.valve[name] = math.max(0, s.valve[name] - step) end
    end
    if s.valve[name] == (open and 1 or 0) then s.disagree_t[name] = 0
    else s.disagree_t[name] = s.disagree_t[name] + dt end
end

-- put every valve where it is commanded (a new flight, or the quick start)
function M.settle(s, inp)
    M.update(s, inp, 0)
    for _, v in ipairs(M.VALVES) do
        s.valve[v], s.disagree_t[v] = s.cmd[v] and 1 or 0, 0
    end
end

local function bus_on(inp, p)
    if p.bus == "util" then return inp.util[p.n] end
    return inp.ac[p.n]
end

local function total_of(q)
    local total = 0
    for _, t in ipairs(M.TANKS) do total = total + q[t] end
    return total
end

function M.update(s, inp, dt)
    s.t = s.t + dt
    local out, q, cap, sw = s.out, s.qty, inp.cap, inp.sw
    local flaps_to = inp.flap_lever >= M.FLAP_TO_MIN and inp.flap_lever <= M.FLAP_TO_MAX
    local total = total_of(q)

    -- ======== jettison control (FJCC; FCOM p.1441, p.1468-1470; ATA26_28 p.538-546)
    local armed = inp.jett_sel > 0
    local nozzle_on = inp.nozzle[1] or inp.nozzle[2]
    if not armed then
        s.jett_done = false
        for _, id in ipairs(M.OJ) do s.ovrd_after_jett[id] = false end
    elseif s.jett_active and total <= inp.ftr then
        -- terminated at the fuel to remain: the pumps that ran keep their
        -- FUEL OVRD until the selector is OFF (FCOM p.1469)
        s.jett_done = true
        for _, id in ipairs(M.OJ) do if out.pump[id] then s.ovrd_after_jett[id] = true end end
    end
    local jett = armed and nozzle_on and not s.jett_done and total > inp.ftr
    s.jett_active = jett
    if jett then s.jett_t = s.jett_t + dt else s.jett_t, s.jett_start_qty = 0, total end
    -- the override/jettison pumps of main 2 and 3 run in the tanks with fuel,
    -- and the low tank's stop until they balance (FCOM p.1469, ATA26_28 p.540)
    local jett_oj = {m2 = jett and q.m2 > M.STANDPIPE_OJ, m3 = jett and q.m3 > M.STANDPIPE_OJ}
    if jett_oj.m2 and jett_oj.m3 then
        if q.m2 - q.m3 >= M.JETT_BALANCE then jett_oj.m3 = false
        elseif q.m3 - q.m2 >= M.JETT_BALANCE then jett_oj.m2 = false end
    end

    -- ======== fuel system management (FSMC)
    -- crossfeed 2 and 3: closed on the ground after 40 s with the flaps in the
    -- takeoff range, held in the air until the flaps leave it (ATA26_28 p.461-463)
    if flaps_to then s.xfeed_to_t = s.xfeed_to_t + dt else s.xfeed_to_t = 0 end
    local inhibit = (not flaps_to) or s.xfeed_to_t < M.XFEED_TO_DELAY_S
    s.xfeed_close = (inp.on_ground or s.xfeed_close) and not inhibit
    -- override/jettison 2 and 3: with both CTR switches OFF, or a CWT pump low
    -- with its switch ON; not while both CWT pumps give pressure (FCOM p.1467,
    -- ATA26_28 p.528-535; last frame's pressures). With the jettison selector
    -- at A or B the jettison control runs them instead (ATA26_28 p.542).
    local ctr_l_low = out.low.ctr_l ~= false
    local ctr_r_low = out.low.ctr_r ~= false
    local oj_cmd = ((not sw.ctr_l and not sw.ctr_r) or (sw.ctr_l and ctr_l_low) or (sw.ctr_r and ctr_r_low))
        and not (sw.ctr_l and sw.ctr_r and not ctr_l_low and not ctr_r_low)
    -- reserve transfer: in the air at 18,200 kg in main 2 or 3, all four
    -- valves; closed on the ground (FCOM p.1464, p.1467; ATA26_28 p.498-500, p.555)
    if inp.on_ground then s.res_open = false
    elseif q.m2 <= M.RES_XFER_AT or q.m3 <= M.RES_XFER_AT then s.res_open = true end
    -- main 1 and 4 transfer: the switch, or the jettison at 9,072 kg in main 2 or 3 (FCOM p.1464)
    local xfer14 = inp.xfer_main14 or (jett and (q.m2 <= M.JETT_MAIN14_AT or q.m3 <= M.JETT_MAIN14_AT))
    -- stabilizer transfer (109): in flight, flaps out of 10-20, CWT 36,470 kg or less (FCOM p.1466)
    local stab_enable = inp.has_stab and not inp.on_ground and not flaps_to and q.ctr <= M.STAB_XFER_CTR_MAX

    -- ======== pumps: motor running and outlet pressure
    local pump, low = out.pump, out.low
    local apu_auto = inp.apu_fuel and inp.gs_bus     -- main 2 and 3 AFT run for the APU (FCOM p.1465)
    for _, p in ipairs(M.PUMPS) do
        local id, t = p.id, p.tank
        local cmd
        if p.kind == "main" then
            cmd = sw[id] or (apu_auto and (id == "m2_aft" or id == "m3_aft"))
        elseif p.kind == "oj" then
            if armed then cmd = sw[id] and jett_oj[t] else cmd = sw[id] and oj_cmd end
        elseif p.kind == "ctr" then
            cmd = sw[id] and not s.jett_done
        else
            cmd = sw[id] and inp.has_stab and not s.stab_tripped[id] and not s.jett_done
                and ((stab_enable and q.ctr < cap.ctr) or jett)
        end
        s.cmd[id] = cmd
        local run = cmd and bus_on(inp, p)
        local minimum = 0
        if p.kind == "oj" then minimum = M.STANDPIPE_OJ elseif p.kind == "ctr" then minimum = M.CTR_PUMP_MIN end
        pump[id] = run or false
        low[id] = not (run and q[t] > minimum)
        -- the stabilizer pump stops itself after a while at low pressure
        -- unless switched off (FCOM p.1455)
        if p.kind == "stab" then
            if not sw[id] then s.stab_tripped[id], s.stab_low_t[id] = false, 0
            elseif cmd and low[id] then
                s.stab_low_t[id] = s.stab_low_t[id] + dt
                if s.stab_low_t[id] >= M.STAB_LOW_OFF_S then s.stab_tripped[id] = true end
            else s.stab_low_t[id] = 0 end
        end
    end
    -- the APU DC fuel pump in main 2: from the APU start until main 2 AFT
    -- gives pressure (about 7 psi), on the APU battery bus (ATA26_28 p.478-480,
    -- FCOM p.820)
    s.cmd.apu_dc = inp.apu_fuel and low.m2_aft
    pump.apu_dc = (s.cmd.apu_dc and inp.apu_bat) or false
    low.apu_dc = not (pump.apu_dc and q.m2 > 0)

    -- ======== valves
    for n = 1, 4 do
        local open = inp.xfeed[n]
        if n == 2 or n == 3 then open = open and not s.xfeed_close end
        move(s, "x" .. n, open, inp.main_bat, dt)          -- main battery bus (FCOM p.819)
        move(s, "s" .. n, inp.fuel_control[n] and not inp.fire_out[n], inp.hot_bat, dt)   -- hot battery (FCOM p.820)
    end
    for _, v in ipairs({"res2a", "res2b", "res3a", "res3b"}) do move(s, v, s.res_open, inp.dc[1], dt) end   -- ATA26_28 p.500
    move(s, "xfer1", xfer14, inp.dc[1], dt)                -- ATA26_28 p.502
    move(s, "xfer4", xfer14, inp.dc[1], dt)
    local main_dc = inp.dc[1] or inp.dc[2] or inp.dc[3] or inp.dc[4]
    move(s, "jett_ctr_l", jett, main_dc, dt)               -- jettison valves (FCOM p.819)
    move(s, "jett_ctr_r", jett, main_dc, dt)
    move(s, "jett_m2", jett_oj.m2, main_dc, dt)
    move(s, "jett_m3", jett_oj.m3, main_dc, dt)
    move(s, "noz_l", inp.nozzle[1], main_dc, dt)           -- the nozzle valves follow their switches (ATA26_28 p.546)
    move(s, "noz_r", inp.nozzle[2], main_dc, dt)
    move(s, "apu", inp.apu_fuel, inp.hot_bat, dt)          -- APU fuel valve (FCOM p.820)

    -- ======== the manifold: which tank feeds which engine (FCOM p.1454-1455)
    local main_p = {}
    for _, t in ipairs(M.MAIN) do
        local n = (low[t .. "_fwd"] and 0 or 1) + (low[t .. "_aft"] and 0 or 1)
        main_p[t] = (n == 2) and M.P_MAIN2 or ((n == 1) and M.P_MAIN1 or 0)
    end
    local ctr_n = (low.ctr_l and 0 or 1) + (low.ctr_r and 0 or 1)
    local manifold = {}                                    -- sources on the crossfeed manifold
    if ctr_n > 0 then manifold[#manifold + 1] = {tank = "ctr", p = (ctr_n == 2) and M.P_CTR2 or M.P_CTR1} end
    if not (low.oj2_fwd and low.oj2_aft) then manifold[#manifold + 1] = {tank = "m2", p = M.P_OJ} end
    if not (low.oj3_fwd and low.oj3_aft) then manifold[#manifold + 1] = {tank = "m3", p = M.P_OJ} end
    local open = {}
    for n = 1, 4 do open[n] = s.valve["x" .. n] > 0.5 end
    local total_ff = 0
    for n = 1, 4 do total_ff = total_ff + math.max(0, inp.ff[n]) end
    for n = 1, 4 do
        local own = M.MAIN[n]
        local feed = out.feed[n]
        for k in pairs(feed) do feed[k] = nil end
        local best, best_p = {}, 0
        local function offer(tank, p)
            if p > best_p then best, best_p = {tank}, p
            elseif p == best_p then best[#best + 1] = tank end
        end
        if open[n] then
            for _, src in ipairs(manifold) do offer(src.tank, src.p) end
            for k = 1, 4 do
                if k ~= n and open[k] and main_p[M.MAIN[k]] > 0 then offer(M.MAIN[k], main_p[M.MAIN[k]]) end
            end
        end
        out.suction[n] = false
        if main_p[own] > 0 and main_p[own] >= best_p then
            feed[own] = 1                                  -- at equal pressure each its own tank (FCTM p.295)
        elseif best_p > 0 then
            -- several at the same pressure: the same side first, else shared
            local side = (n <= 2) and "L" or "R"
            local same = {}
            for _, t in ipairs(best) do if M.SIDE[t] == side then same[#same + 1] = t end end
            if #same == 0 then same = best end
            for _, t in ipairs(same) do feed[t] = (feed[t] or 0) + 1 / #same end
        elseif q[own] > 0 then
            feed[own] = 1                                  -- suction feed (FCOM p.1455)
            out.suction[n] = true
        end
        -- shared flow: a low CWT no longer fully overrides the outboard
        -- main pumps (FCOM p.1466)
        if feed.ctr == 1 and (n == 1 or n == 4) and main_p[own] > 0 and q.ctr < M.SHARED_CTR
            and total_ff * 3600 > M.SHARED_FF_KGH then
            feed.ctr, feed[own] = 0.5, 0.5
        end
        local fuel = false
        for t, share in pairs(feed) do if share > 0 and q[t] > 0 then fuel = true end end
        out.has_fuel[n] = fuel and s.valve["s" .. n] > 0.5
    end

    -- ======== quantities
    local flow = out.flow
    for k in pairs(flow) do flow[k] = nil end
    local function move_fuel(from, to, kgh)
        local kg = math.min(kgh * dt / 3600, q[from])
        if to then kg = math.min(kg, math.max(0, cap[to] - q[to])) end
        if kg <= 0 then return end
        q[from] = q[from] - kg
        if to then q[to] = q[to] + kg end
        flow[from .. ">" .. (to or "out")] = true
    end
    if not s.first then
        for n = 1, 4 do
            local kg = math.max(0, inp.ff[n]) * dt          -- X-Plane's flow goes negative in a start
            for t, share in pairs(out.feed[n]) do q[t] = math.max(0, q[t] - kg * share) end
        end
        if inp.apu_fuel and s.valve.apu > 0.5 then move_fuel("m2", nil, M.APU_KGH) end   -- main 2 (FCOM p.1464-1465)
        -- by gravity (FCOM p.1464)
        if s.valve.res2a > 0.5 or s.valve.res2b > 0.5 then move_fuel("r2", "m2", M.RES_XFER_KGH) end
        if s.valve.res3a > 0.5 or s.valve.res3b > 0.5 then move_fuel("r3", "m3", M.RES_XFER_KGH) end
        if s.valve.xfer1 > 0.5 and q.m1 > M.OUTBD_XFER_MIN then move_fuel("m1", "m2", M.MAIN14_XFER_KGH) end
        if s.valve.xfer4 > 0.5 and q.m4 > M.OUTBD_XFER_MIN then move_fuel("m4", "m3", M.MAIN14_XFER_KGH) end
        -- scavenge: two jet pumps into each of main 2 and 3, driven by that
        -- tank's pumps, through the float valves (ATA26_28 p.512, FCOM p.1454)
        if q.ctr < M.SCAV_CTR_BELOW then
            for _, t in ipairs({"m2", "m3"}) do
                local n = t:sub(2)
                local pumped = not (low[t .. "_fwd"] and low[t .. "_aft"] and low["oj" .. n .. "_fwd"] and low["oj" .. n .. "_aft"])
                if q[t] <= M.SCAV_MAIN_AT and pumped then move_fuel("ctr", t, 2 * M.SCAV_KGH) end
            end
        end
        -- jettison overboard through the nozzles (the stabilizer fuel goes
        -- out from the manifold, not into the CWT: ATA26_28 p.519)
        local nozzles = s.valve.noz_l > 0.5 or s.valve.noz_r > 0.5
        local stab_n = (low.stab_l and 0 or 1) + (low.stab_r and 0 or 1)
        if jett and nozzles then
            if s.valve.jett_ctr_l > 0.5 or s.valve.jett_ctr_r > 0.5 then move_fuel("ctr", nil, ctr_n * M.JETT_PUMP_KGH) end
            for _, t in ipairs({"m2", "m3"}) do
                local n = t:sub(2)
                local oj_n = (low["oj" .. n .. "_fwd"] and 0 or 1) + (low["oj" .. n .. "_aft"] and 0 or 1)
                if s.valve["jett_" .. t] > 0.5 then move_fuel(t, nil, oj_n * M.JETT_PUMP_KGH) end
            end
            move_fuel("stab", nil, stab_n * M.JETT_PUMP_KGH)
        elseif stab_n > 0 then
            move_fuel("stab", "ctr", stab_n * M.STAB_PUMP_KGH)
        end
    end
    s.first = false
    total = total_of(q)

    -- ======== EICAS (FCOM p.1473-1479)
    local c = out.cas
    local climb = inp.pitch >= M.CLIMB_PITCH
    local any_running = inp.running[1] or inp.running[2] or inp.running[3] or inp.running[4]
    local tank_eng_q = q.m2 <= q.m1 or q.m3 <= q.m4
    for n = 1, 4 do c["press_eng" .. n] = out.suction[n] and inp.running[n] end
    for _, p in ipairs(M.PUMPS) do
        if p.kind == "main" then c[p.id] = low[p.id] and not c["press_eng" .. p.tank:sub(2)] end
    end
    -- FUEL OVRD: low pressure while the logic runs the pump, or the switch
    -- OFF before the tank-to-engine configuration; after a jettison
    for _, id in ipairs(M.OJ) do
        c[id] = (s.cmd[id] and low[id]) or (not sw[id] and not tank_eng_q) or s.ovrd_after_jett[id]
    end
    -- the CWT: low before start, in climb and in cruise; on with fuel left;
    -- the pressure caution 60 s after the low message or a low pump
    for k, id in ipairs({"ctr_l", "ctr_r"}) do
        local low_q
        if inp.on_ground then low_q = not any_running and q.ctr < M.CTR_LOW_PRESTART
        elseif climb then low_q = q.ctr <= M.CTR_LOW_CLIMB
        else low_q = q.ctr <= M.CTR_LOW_CRUISE end
        c["low_" .. id] = sw[id] and low_q and not armed
        if c["low_" .. id] then s.ctr_low_t[k] = s.ctr_low_t[k] + dt else s.ctr_low_t[k] = 0 end
        local ovd
        if inp.on_ground then ovd = q.ctr >= M.CTR_OVD_GROUND
        else ovd = not climb and q.ctr >= M.CTR_OVD_CRUISE end
        c["ovd_" .. id] = not sw[id] and ovd
        local press = s.ctr_low_t[k] >= M.CTR_PRESS_DELAY_S or (sw[id] and low[id])
        if armed and q.ctr >= M.CTR_JETT_INHIBIT then press = false end
        c["press_" .. id] = press
    end
    -- the stabilizer tank (109)
    c.stab_xfr = inp.has_stab and stab_enable and q.ctr < cap.ctr and q.stab > 0 and (sw.stab_l or sw.stab_r)
        and low.stab_l and low.stab_r and not s.jett_done
    for _, id in ipairs({"stab_l", "stab_r"}) do
        local pmp = (inp.on_ground and sw[id]) or (not inp.on_ground and not climb and q.stab >= M.STB_PMP_CRUISE and not sw[id])
        c["pmp_" .. id] = inp.has_stab and pmp and not c.stab_xfr
        c["pres_" .. id] = inp.has_stab and s.cmd[id] and low[id]
    end
    -- quantity, imbalance, tank to engine
    c.qty_low = q.m1 <= M.QTY_LOW or q.m2 <= M.QTY_LOW or q.m3 <= M.QTY_LOW or q.m4 <= M.QTY_LOW
    local function imbal(key, diff, set)
        if diff >= set then s.imbal[key] = true elseif diff < M.IMBAL_CLEAR then s.imbal[key] = false end
        return s.imbal[key] or false
    end
    c.imbal14 = imbal("14", math.abs(q.m1 - q.m4), M.IMBAL14)
    c.imbal23 = imbal("23", math.abs(q.m2 - q.m3), M.IMBAL23)
    local margin = inp.on_ground and M.TANK_ENG_GROUND or 0
    local tank_eng = (q.m2 <= q.m1 + margin or q.m3 <= q.m4 + margin) and (open[1] or open[4])
    c.tank_eng = tank_eng and not armed
    if tank_eng_q then s.tank_eng_reached = true elseif inp.on_ground then s.tank_eng_reached = false end
    c.imbalance = s.tank_eng_reached and imbal("inout", math.abs((q.m2 + q.m3) - (q.m1 + q.m4)), M.IMBAL23)
    -- valves not where they were sent
    for n = 1, 4 do c["xfeed" .. n] = s.disagree_t["x" .. n] >= M.DISAGREE_S end
    c.res_xfr2 = s.disagree_t.res2a >= M.DISAGREE_S or s.disagree_t.res2b >= M.DISAGREE_S
    c.res_xfr3 = s.disagree_t.res3a >= M.DISAGREE_S or s.disagree_t.res3b >= M.DISAGREE_S
    -- APU FUEL: the DC pump low while commanded, or the APU fuel valve not
    -- where it was sent (FCOM p.902; the 10 s of the crossfeed valves: estimate)
    c.apu_fuel = (s.cmd.apu_dc and low.apu_dc) or s.disagree_t.apu >= M.DISAGREE_S
    c.xfer14 = inp.xfer_main14 and (inp.on_ground or (q.m2 + q.m3) > (q.m1 + q.m4))
    c.xfeed_config = ((not s.cmd.x1 or not s.cmd.x4) and not tank_eng_q)
        or ((not s.cmd.x2 or not s.cmd.x3) and not flaps_to)
    -- jettison
    c.jett_noz = s.valve.noz_l > 0.5 and s.valve.noz_r > 0.5
    c.jett_noz_l = s.valve.noz_l > 0.5 and not c.jett_noz
    c.jett_noz_r = s.valve.noz_r > 0.5 and not c.jett_noz
    c.jett_nozzle_l = s.disagree_t.noz_l >= M.DISAGREE_S
    c.jett_nozzle_r = s.disagree_t.noz_r >= M.DISAGREE_S
    c.jett_sys = armed and total < inp.ftr and (s.valve.noz_l > 0.5 or s.valve.noz_r > 0.5)
    c.temp_low = inp.temp <= M.TEMP_LOW

    -- ======== overhead lights (FCOM p.1439-1441, p.1465; ATA26_28 p.414)
    local l = out.light
    for _, p in ipairs(M.PUMPS) do
        if p.kind == "main" then l[p.id] = low[p.id]                       -- whenever there is power
        elseif p.kind == "ctr" then l[p.id] = sw[p.id] and low[p.id]       -- with the switch ON
        else l[p.id] = (s.cmd[p.id] and low[p.id]) or false end            -- while the logic runs it
    end
    for n = 1, 4 do l["x" .. n] = s.valve["x" .. n] ~= (s.cmd["x" .. n] and 1 or 0) end
    l.noz_l = s.valve.noz_l ~= (inp.nozzle[1] and 1 or 0)
    l.noz_r = s.valve.noz_r ~= (inp.nozzle[2] and 1 or 0)

    out.total = total
    out.jett, out.jett_done, out.armed = jett, s.jett_done, armed
    out.xfeed_close, out.res_open, out.xfer14 = s.xfeed_close, s.res_open, xfer14
    out.stab_enable, out.oj_cmd = stab_enable, oj_cmd
    -- the jettison time: the preprogrammed rate, then the actual one from
    -- 90 s (FCOM p.1468)
    local rate = M.JETT_EST_KGH
    if s.jett_t >= M.JETT_UPDATE_S and s.jett_start_qty > total then
        rate = (s.jett_start_qty - total) / s.jett_t * 3600
    end
    out.jett_min = (armed and total > inp.ftr) and (total - inp.ftr) / rate * 60 or 0
    return out
end

return M
