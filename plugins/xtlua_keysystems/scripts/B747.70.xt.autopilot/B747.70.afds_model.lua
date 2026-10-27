-- The FCCs' mode logic (6-3, being rebuilt in steps: the plan and sources
-- in docs/overhaul/notes/ATA-22.md §10). Step 1a: the autopilot's engage
-- and disengage, AUTOPILOT DISC, the flight directors and the default
-- modes on the first F/D ON and on the A/P's engage, everything off. The
-- other modes are still the old code's (steps 1b-1d move them here); the
-- glue (B747.70.xt.autopilot.lua) applies the defaults asked for to it.
--  - Engage (FCOM p.640; ATA22 p.302-318): a CMD switch engages its
--    channel when the disengage bar is up, no other channel is engaged (a
--    second channel only by the approach's multi-channel arm: ATA22 p.314,
--    p.318) and its servos have hydraulic pressure (L system 3, C 1, R 2:
--    ATA22 p.10-12; 1000 psi as the old code: estimate). On the ground
--    too (the old code's 400 ft is in no source; 250 ft after takeoff is
--    an operating limit: FCOM p.80).
--  - Disengage: the bar (all; no engage while it is down), either control
--    wheel switch, automatically (the channel's hydraulics; the stab trim
--    switches with one A/P: FCOM p.945). AUTOPILOT DISC (warning) when the
--    last engaged channel disengages, by hand or automatically; reset by an
--    engage or by a control wheel switch pushed with no A/P engaged (the
--    second push after a manual disengage, the first after an automatic
--    one: FCOM p.655; ATA22 p.254, p.380). Lifting the bar does not reset
--    it (it did in the old code).
--  - The F/Ds (FCOM p.639-640; ATA22 p.337, p.352-353): the first switched
--    ON with both off and no A/P engaged: on the ground TO/GA (roll and
--    pitch), in the air V/S and HDG HOLD, or ATT above 5 degrees of bank
--    (the PW airplanes 109 and 405; the GE 570 none; RR as PW: estimate).
--    With the A/P engaged a F/D shows the A/P's modes.
--  - The A/P engaged (ATA22 p.266, p.338, p.352; FCOM p.640): with a F/D
--    ON in its modes, but from the F/D's takeoff on the ground HDG HOLD
--    and V/S; with both F/Ds OFF V/S and HDG HOLD, or ATT above 5 degrees
--    (as the F/Ds').
--  - All modes off once the A/P is disengaged and both F/Ds are OFF (FCOM
--    p.660).
-- Pure: the switches' events and the airplane's state in; the engage
-- state, the warning and the modes asked for out.
--   local A = B747_afds_model                      -- in XTLua, after dofile
--   local A = dofile(".../B747.70.afds_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_afds_model = M

M.CHANNELS = {"L", "C", "R"}
-- the hydraulic system of each channel's servos (ATA22 p.10-12)
M.HYD = {L = 3, C = 1, R = 2}
-- servo pressure for an engaged channel (psi; the old code's: estimate)
M.HYD_MIN = 1000
-- ATT above this bank, held to at most ATT_MAX (FCOM p.663)
M.ATT_MIN = 5
M.ATT_MAX = 30
-- the engine types (laminar/B747/engines/type: the simconfig's)
M.ENGINE_GE = 1

-- the state
function M.new()
    return setmetatable({L = false, C = false, R = false, bar = false, disc = false,
        fd = {L = false, R = false}, off = true}, {})
end

-- the channels engaged
function M.engaged(s)
    return (s.L and 1 or 0) + (s.C and 1 or 0) + (s.R and 1 or 0)
end
local function fd_on(s) return s.fd.L or s.fd.R end

-- the roll mode by the bank: ATT (PW, RR) above ATT_MIN, held to ATT_MAX,
-- else HDG HOLD; the bank to hold
local function roll_default(inp)
    local b = inp.bank or 0
    if inp.engine ~= M.ENGINE_GE and math.abs(b) > M.ATT_MIN then
        return "ATT", math.max(-M.ATT_MAX, math.min(M.ATT_MAX, b))
    end
    return "HDG_HOLD", 0
end

-- the last engaged channel gone: the warning
local function dropped(s, was)
    if was > 0 and M.engaged(s) == 0 then s.disc = true end
end

-- a CMD switch pushed: channel ch. `inp`: {hyd = {[1] = psi, [2], [3]},
-- bank, engine, ground, toga (the F/D's takeoff/go-around active)}.
-- Returns the modes asked for ({roll, bank, pitch}) or nil
function M.cmd(s, ch, inp)
    if s.bar or s[ch] or M.engaged(s) > 0 then return nil end
    if ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then return nil end
    s[ch] = true
    s.disc = false
    s.off = false
    if not fd_on(s) then
        local roll, bank = roll_default(inp)
        return {roll = roll, bank = bank, pitch = "VS"}
    end
    if inp.toga and inp.ground then
        return {roll = "HDG_HOLD", bank = 0, pitch = "VS", toga_off = true}
    end
    return nil
end

-- the old approach's channels (until step 4): engaged together without
-- the single-channel rule, those with hydraulic pressure
function M.multi(s, inp)
    if s.bar or M.engaged(s) == 0 then return end
    for _, ch in ipairs(M.CHANNELS) do
        if ((inp.hyd or {})[M.HYD[ch]] or 0) >= M.HYD_MIN then s[ch] = true end
    end
end

-- the disengage bar moved: down disengages all (by hand)
function M.bar(s, down)
    s.bar = down
    if down then
        local was = M.engaged(s)
        s.L, s.C, s.R = false, false, false
        dropped(s, was)
    end
end

-- a control wheel A/P disengage switch pushed
function M.wheel(s)
    if M.engaged(s) > 0 then
        s.L, s.C, s.R = false, false, false
        s.disc = true
    else
        s.disc = false
    end
end

-- disengaged automatically (the stab trim switches with one A/P); `quiet`
-- without the warning (the old autoland's disconnect on the rollout: until
-- step 4)
function M.disengage(s, quiet)
    local was = M.engaged(s)
    s.L, s.C, s.R = false, false, false
    if not quiet then dropped(s, was) end
end

-- each frame: `inp` {fd = {L, R} the switches ON, hyd, bank, engine,
-- ground}. The channels without hydraulic pressure drop out; the F/D
-- switched ON first asks for its modes; everything off once neither the
-- A/P nor a F/D is on. Returns the modes asked for ({roll, bank, pitch,
-- toga} or {all_off = true}) or nil
function M.update(s, inp)
    local was = M.engaged(s)
    for _, ch in ipairs(M.CHANNELS) do
        if s[ch] and ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then s[ch] = false end
    end
    dropped(s, was)
    local first = not fd_on(s) and M.engaged(s) == 0 and (inp.fd.L or inp.fd.R)
    s.fd.L, s.fd.R = inp.fd.L and true or false, inp.fd.R and true or false
    if first then
        s.off = false
        if inp.ground then return {toga = true} end
        local roll, bank = roll_default(inp)
        return {roll = roll, bank = bank, pitch = "VS"}
    end
    if M.engaged(s) == 0 and not fd_on(s) and not s.off then
        s.off = true
        return {all_off = true}
    end
    return nil
end

return M
