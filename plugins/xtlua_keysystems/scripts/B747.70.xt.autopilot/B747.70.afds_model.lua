-- The FCCs' mode logic (6-3, being rebuilt in steps: the plan and sources
-- in docs/overhaul/notes/ATA-22.md §10). Steps 1a and 1b: the autopilot's
-- engage and disengage, AUTOPILOT DISC, the flight directors, the default
-- modes on the first F/D ON and on the A/P's engage, everything off; the
-- roll modes HDG SEL, HDG HOLD, ATT and LNAV. The approach modes (LOC,
-- G/S), TO/GA and the pitch modes are still the old code's (steps 1c-1e
-- move them here); the glue (B747.70.xt.autopilot.lua) applies the modes
-- asked for to it and tells the model which of those is active.
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
--  - The roll modes (step 1b; ATA22 p.351-355, figure p.353; FCOM p.644-
--    647, p.663), each a latch reset by the next roll mode: HDG SEL by its
--    request when the transition is enabled (table p.351: from the old
--    LOC only before G/S is active, from G/A only at 400 ft RA or above);
--    HDG HOLD likewise or by default, annunciated at once and holding the
--    heading reached once the roll has stayed under 3 degrees for 2
--    seconds; ATT by default only; LNAV armed by its first push (not with
--    LOC engaged, from G/A only at 400 ft), disarmed by the second push
--    while armed, a push while active does nothing (the old code
--    disengaged it); engaged armed above 50 ft with the FMC's steering
--    valid (6-1/6-2 step 6c). HDG SEL and HDG HOLD deactivate LNAV, not its
--    arm (the previous roll mode stays active while LNAV is armed: FCOM
--    p.644; ATA22 p.354 cancels the arm only by the second push, a LOC or
--    APP request and its engage).
-- Pure: the switches' events and the airplane's state in; the engage
-- state, the warning, the roll mode and the modes asked for out.
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
-- HDG HOLD's heading once the roll stays under LEVEL degrees LEVEL_TIME s
-- (figure p.353); LNAV above LNAV_RA ft; G/A's modes kept below GA_RA ft
M.LEVEL = 3
M.LEVEL_TIME = 2
M.LNAV_RA = 50
M.GA_RA = 400
-- the FMA's roll numbers (the init's)
M.ROLL_FMA = {TOGA = 1, LNAV = 2, LOC = 3, ROLLOUT = 4, ATT = 5, HDG_SEL = 6, HDG_HOLD = 7}

-- the state
function M.new()
    return setmetatable({L = false, C = false, R = false, bar = false, disc = false,
        fd = {L = false, R = false}, off = true,
        roll = nil, lnav_arm = false, hold_hdg = nil, level_t = 0, att_bank = 0, toga_roll_off = false, toga_seen = false}, {})
end

-- the channels engaged
function M.engaged(s)
    return (s.L and 1 or 0) + (s.C and 1 or 0) + (s.R and 1 or 0)
end
local function fd_on(s) return s.fd.L or s.fd.R end

-- a roll mode engaged (the latch of the one before reset)
local function set_roll(s, mode, bank)
    s.roll = mode
    s.hold_hdg, s.level_t = nil, 0
    s.att_bank = mode == "ATT" and bank or 0
    s.toga_roll_off = true
end

-- the roll mode by the bank: ATT (PW, RR) above ATT_MIN, held to ATT_MAX,
-- else HDG HOLD
local function roll_default(s, inp)
    local b = inp.bank or 0
    if inp.engine ~= M.ENGINE_GE and math.abs(b) > M.ATT_MIN then
        set_roll(s, "ATT", math.max(-M.ATT_MAX, math.min(M.ATT_MAX, b)))
    else
        set_roll(s, "HDG_HOLD")
    end
end

-- the last engaged channel gone: the warning
local function dropped(s, was)
    if was > 0 and M.engaged(s) == 0 then s.disc = true end
end

-- the old code's G/A below 400 ft RA (its single TO/GA flag; a go-around
-- by `inp.ga`: until step 1e). T/O allows the roll modes at any height
-- (table p.351)
local function ga_low(inp)
    return inp.old_roll == "TOGA" and inp.ga and not inp.ground and (inp.ra or 0) < M.GA_RA
end

-- a CMD switch pushed: channel ch. `inp`: {hyd = {[1] = psi, [2], [3]},
-- bank, engine, ground, toga (the F/D's takeoff/go-around active)}.
-- Returns the other modes asked for ({pitch, toga_off}) or nil
function M.cmd(s, ch, inp)
    if s.bar or s[ch] or M.engaged(s) > 0 then return nil end
    if ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then return nil end
    s[ch] = true
    s.disc = false
    s.off = false
    if not fd_on(s) then
        roll_default(s, inp)
        return {pitch = "VS"}
    end
    if inp.toga and inp.ground then
        set_roll(s, "HDG_HOLD")
        return {pitch = "VS", toga_off = true}
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

-- the HDG SEL switch (`inp`: old_roll, gs_active, ground, ra): true when
-- engaged
function M.hdg_sel(s, inp)
    if (inp.old_roll == "LOC" and inp.gs_active) or ga_low(inp) then return false end
    set_roll(s, "HDG_SEL")
    return true
end

-- the HDG HOLD switch; `default` (the HDG REF switch moved in HDG SEL:
-- ATA22 p.352) without the transition's conditions. True when engaged
function M.hdg_hold(s, inp, default)
    if not default and ((inp.old_roll == "LOC" and inp.gs_active) or ga_low(inp)) then return false end
    set_roll(s, "HDG_HOLD")
    return true
end

-- the LNAV switch
function M.lnav(s, inp)
    if s.lnav_arm then
        s.lnav_arm = false
    elseif s.roll ~= "LNAV" and inp.old_roll ~= "LOC" and not ga_low(inp) then
        s.lnav_arm = true
    end
end

-- the old LOC captured (until step 1d): LNAV off, its arm too (FCOM
-- p.645), the roll the old code's
function M.loc_captured(s)
    s.lnav_arm = false
    s.roll = nil
    s.hold_hdg, s.level_t = nil, 0
end

-- each frame: `inp` {fd = {L, R} the switches ON, hyd, bank, engine,
-- ground, ra, hdg (the heading HDG HOLD holds), lnav_valid, old_roll,
-- dt}. The channels without hydraulic pressure drop out; the F/D switched
-- ON first asks for its modes; everything off once neither the A/P nor a
-- F/D is on; HDG HOLD's heading, LNAV's engage. Returns the other modes
-- asked for ({pitch, toga} or {all_off = true}) or nil
function M.update(s, inp)
    local was = M.engaged(s)
    for _, ch in ipairs(M.CHANNELS) do
        if s[ch] and ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then s[ch] = false end
    end
    dropped(s, was)
    -- the old TO/GA begun: its roll until a roll mode replaces it
    local toga = inp.old_roll == "TOGA"
    if toga and not s.toga_seen then s.toga_roll_off = false end
    s.toga_seen = toga
    local first = not fd_on(s) and M.engaged(s) == 0 and (inp.fd.L or inp.fd.R)
    s.fd.L, s.fd.R = inp.fd.L and true or false, inp.fd.R and true or false
    if first then
        s.off = false
        if inp.ground then return {toga = true} end
        roll_default(s, inp)
        return {pitch = "VS"}
    end
    if M.engaged(s) == 0 and not fd_on(s) then
        if not s.off then
            s.off = true
            s.roll, s.lnav_arm, s.hold_hdg, s.level_t, s.att_bank = nil, false, nil, 0, 0
            return {all_off = true}
        end
        return nil
    end
    if s.roll == "HDG_HOLD" and not s.hold_hdg then
        if math.abs(inp.bank or 0) < M.LEVEL then
            s.level_t = s.level_t + (inp.dt or 0)
            if s.level_t >= M.LEVEL_TIME then s.hold_hdg = inp.hdg end
        else
            s.level_t = 0
        end
    end
    if s.lnav_arm and inp.lnav_valid and (inp.ra or 0) > M.LNAV_RA then
        s.lnav_arm = false
        set_roll(s, "LNAV")
    end
    return nil
end

-- the FMA's roll (the init's numbers): active and armed. The old code's
-- LOC, and its TO/GA until a roll mode replaced it, come first; the old
-- LOC's and ROLLOUT's arms after LNAV's (`inp.old_armed_roll`)
function M.roll_fma(s, inp)
    local active = 0
    if inp.old_roll == "LOC" then
        active = M.ROLL_FMA.LOC
    elseif inp.old_roll == "TOGA" and not s.toga_roll_off then
        active = M.ROLL_FMA.TOGA
    elseif s.roll then
        active = M.ROLL_FMA[s.roll]
    end
    local armed = s.lnav_arm and M.ROLL_FMA.LNAV or (inp.old_armed_roll or 0)
    return active, armed
end

return M
