-- The sim's option "Auto fuel management" (2026-11-09 the user; Plugins >
-- 747-400 in plugins/b747_fms_bridge, kept in X-Plane's Output/preferences/
-- B747-400_options.prf; docs/overhaul/notes/ATA-28.md §13): a convenience
-- of the sim, not the airplane's. With it on, the fuel switches the Climb
-- and Cruise Procedure has the pilot monitoring set at the fuel messages
-- (FCOM NP.21.39-42 p.133-136) are set for the crew, one at a time, by the
-- switches' own commands:
--   FUEL LOW CTR L or R (about 3,200 kg in climb, 1,300 kg in cruise):
--     both CTR pumps OFF
--   FUEL OVD CTR L or R (1,800 kg or more in cruise): both CTR pumps ON
--   FUEL PMP STB L or R (500 kg or more): both STAB pumps ON
--   FUEL PRES STB L or R with 900 kg or less: both STAB pumps OFF; with
--     fuel still shown about 5 minutes later, both ON again, then OFF at
--     the first FUEL PRES STB (p.135)
--   FUEL TANK/ENG (main 2 <= main 1 or main 3 <= main 4): override 2 and 3
--     FWD and AFT OFF, crossfeed 1 and 4 OFF (p.133-136; FCOM p.1467,
--     ATA26_28 p.555 the same)
-- The messages' own conditions (B747.28.fuel_model.lua, FCOM p.1474-1478)
-- carry the quantities and the climb or cruise. Only in the air with the
-- flap lever UP: the procedure comes after the After Takeoff Checklist,
-- which follows the flap retraction (p.132-133). Nothing with the jettison
-- selector at A or B (the crew's jettison: p.1468-1469). Not the ground's
-- steps (the preflight and before start's pumps, a ground FUEL TANK/ENG,
-- the parking's pumps OFF: p.106, p.119-120, p.152), fuel balancing (SP.12.1
-- p.199 and FCTM p.295: the crew's, a leak considered first), jettison,
-- FUEL XFER MAIN 1 & 4, or the non-normal messages. A switch the pilot moves
-- in flight with the option on is left to the pilot until the next landing
-- (balancing, a non-normal procedure); the option turned off forgets them.
-- After the STAB pumps' OFF, FUEL PMP STB no longer turns them on (only the
-- 5 minutes' second try): a pump failed with fuel left would turn them on
-- and off again and again.
-- Ours (estimates: no source has them): the message held 5 s before the
-- step (the crew's response; FUEL PRESS CTR comes 60 s after FUEL LOW CTR),
-- a switch a second, a push not taken in 3 s pushed again, the second try
-- once, "fuel still shown" 50 kg (the synoptic's 0.1 t), the flap lever UP
-- below 0.05 of its travel (the detent 1 is 1/6).
-- Pure: the glue gives the state and pushes the switch it returns.
--   local A = B747_fuel_auto_model                   -- in XTLua, after dofile
--   local A = dofile(".../B747.28.fuel_auto_model.lua") -- in the tests
--   local s = A.new()
--   local id = A.update(s, inp)       -- every frame; a switch to push, or nil
local M = setmetatable({}, {})
B747_fuel_auto_model = M

M.HOLD_S = 5            -- a message shown this long before its step (ours)
M.PUSH_S = 1            -- between two pushes (ours)
M.CONFIRM_S = 3         -- a push not taken by then pushed again (ours)
M.RETRY_S = 300         -- the STAB pumps' second try, "approximately 5 minutes" (FCOM p.135)
M.STAB_SHOWN_KG = 50    -- fuel still shown in the stabilizer tank (ours: the synoptic's 0.1 t)
M.STAB_OFF_MAX = 900    -- FUEL PRES STB's step with this much or less (FCOM p.135)
M.FLAPS_UP_MAX = 0.05   -- the flap lever UP (laminar/B747/cablecontrols/flap_ratio; ours)

-- the switches it sets (the glue's commands and positions)
M.SWITCHES = {"ctr_l", "ctr_r", "stab_l", "stab_r", "oj2_fwd", "oj3_fwd", "oj2_aft", "oj3_aft", "x1", "x4"}

-- the steps in the order they are taken when several are due: the switches
-- each sets (in the procedure's order), on (true) or off, and the steps it
-- cancels (the same switches the other way)
M.STEPS = {
    {id = "ctr_off", sw = {"ctr_l", "ctr_r"}, on = false, cancels = "ctr_on"},
    {id = "ctr_on", sw = {"ctr_l", "ctr_r"}, on = true, cancels = "ctr_off"},
    {id = "stab_off", sw = {"stab_l", "stab_r"}, on = false, cancels = "stab_on"},
    {id = "stab_on", sw = {"stab_l", "stab_r"}, on = true, cancels = "stab_off"},
    {id = "tank_eng", sw = {"oj2_fwd", "oj3_fwd", "oj2_aft", "oj3_aft", "x1", "x4"}, on = false},
}

function M.new()
    return {
        t = 0,
        seen = {},          -- the switches as last seen (true on)
        pilot = {},         -- the switches the pilot moved in this flight
        held = {},          -- step -> seconds its message has been shown
        active = {},        -- step -> true: being done
        push = nil,         -- {id, on, t}: our push not taken yet
        last_push = nil,    -- the time of our last push
        stab_off_t = nil,   -- the STAB pumps' OFF (FUEL PRES STB) in this flight
        stab_retried = false,
        retry = false,      -- the second try's ON under way
    }
end

-- each step's message now. inp.cas: the fuel model's out.cas
local function due(s, inp, id)
    local c = inp.cas
    if id == "ctr_off" then return c.low_ctr_l or c.low_ctr_r end
    if id == "ctr_on" then return c.ovd_ctr_l or c.ovd_ctr_r end
    if id == "stab_off" then return (c.pres_stab_l or c.pres_stab_r) and inp.stab_kg <= M.STAB_OFF_MAX end
    if id == "stab_on" then
        -- FUEL PMP STB before the first OFF; after it only the second try
        if s.stab_off_t then return s.retry end
        return c.pmp_stab_l or c.pmp_stab_r
    end
    if id == "tank_eng" then return c.tank_eng end
    return false
end

-- the next switch of a step to push (not where the step sets it, not the
-- pilot's), or nil: the step is done
local function next_switch(s, inp, st)
    for _, id in ipairs(st.sw) do
        if inp.sw[id] ~= st.on and not s.pilot[id] then return id end
    end
    return nil
end

-- a step done (the second try's ON ends the try)
local function done(s, st)
    s.active[st.id], s.held[st.id] = nil, 0
    if st.id == "stab_on" and s.retry then s.retry, s.stab_retried = false, true end
end

-- inp: on (the option), air, flaps_up, jett (the jettison selector at A or
-- B), cas (the fuel model's messages), stab_kg (the stabilizer tank), sw
-- (switch -> true on, M.SWITCHES), dt (s, X-Plane's: 0 paused). Returns the
-- switch to push (one of M.SWITCHES) or nil.
function M.update(s, inp)
    s.t = s.t + inp.dt
    -- what moved: our push when it is the one we sent, else the pilot's
    -- (with the option on in the air)
    for _, id in ipairs(M.SWITCHES) do
        local was = s.seen[id]
        if was ~= nil and was ~= inp.sw[id] then
            if s.push and s.push.id == id and inp.sw[id] == s.push.on then
                s.push = nil
            elseif inp.on and inp.air then
                s.pilot[id] = true
            end
        end
        s.seen[id] = inp.sw[id]
    end
    if s.push and s.t - s.push.t >= M.CONFIRM_S then s.push = nil end
    -- (tables emptied only when they hold something: no new table a frame)
    if not inp.air then
        -- on the ground: the next flight's from the start
        if next(s.pilot) then s.pilot = {} end
        s.stab_off_t, s.stab_retried, s.retry = nil, false, false
    end
    if not inp.on and next(s.pilot) then s.pilot = {} end
    if not (inp.on and inp.air and inp.flaps_up and not inp.jett) then
        if next(s.held) then s.held = {} end
        if next(s.active) then s.active = {} end
        return nil
    end
    -- the 5 minutes' second try (once), with fuel still shown
    if s.stab_off_t and not s.stab_retried and not s.retry and s.t - s.stab_off_t >= M.RETRY_S
        and inp.stab_kg >= M.STAB_SHOWN_KG then
        s.retry = true
    end
    -- the messages held long enough start their steps
    for _, st in ipairs(M.STEPS) do
        if due(s, inp, st.id) then
            s.held[st.id] = (s.held[st.id] or 0) + inp.dt
            if not s.active[st.id] and s.held[st.id] >= M.HOLD_S - 1e-9 then
                s.active[st.id] = true
                if st.cancels then s.active[st.cancels] = nil end
                -- the STAB pumps' OFF: FUEL PMP STB from now on no longer
                -- turns them on, the 5 minutes counted from here
                if st.id == "stab_off" and not s.stab_off_t then s.stab_off_t = s.t end
            end
        else
            s.held[st.id] = 0
        end
    end
    -- the first step under way: its next switch, one at a time
    if s.push then return nil end
    for _, st in ipairs(M.STEPS) do
        if s.active[st.id] then
            local id = next_switch(s, inp, st)
            if id == nil then
                done(s, st)
            else
                if s.last_push and s.t - s.last_push < M.PUSH_S - 1e-9 then return nil end
                s.push, s.last_push = {id = id, on = st.on, t = s.t}, s.t
                return id
            end
        end
    end
    return nil
end

return M
