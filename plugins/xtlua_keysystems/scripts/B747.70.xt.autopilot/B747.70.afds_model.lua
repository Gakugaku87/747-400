-- The FCCs' mode logic (6-3, being rebuilt in steps: the plan and sources
-- in docs/overhaul/notes/ATA-22.md §10). Steps 1a-1c: the autopilot's
-- engage and disengage, AUTOPILOT DISC, the flight directors, the default
-- modes on the first F/D ON and on the A/P's engage, everything off; the
-- roll modes HDG SEL, HDG HOLD, ATT and LNAV; the pitch modes V/S, ALT,
-- FLCH SPD and VNAV. The approach modes (LOC, G/S) and TO/GA are still the
-- old code's (steps 1d and 1e move them here); the glue
-- (B747.70.xt.autopilot.lua) applies the modes asked for to it and tells
-- the model which of those is active.
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
--  - The pitch modes (step 1c; table p.335, figures p.337-341; FCOM p.642-
--    650, p.664-665), each a latch the next pitch mode resets, enabled
--    (table p.335) from the old G/S only before LOC is active and from G/A
--    only at 400 ft RA or above: V/S, its target synced to the present
--    vertical speed (100 fpm steps, -8000 to +6000), 000 after ALT or after
--    TO/GA descending (ATA22 p.282); ALT HOLD holding the altitude then
--    (FCOM p.650); the MCP altitude captured from V/S and FLCH (the old
--    capture window until step 3: ATA22 p.286 says 0.05 g); FLCH SPD, its
--    speed with the IAS/MACH window blank the FMC's target if valid, else
--    the present speed, from TO/GA the higher of the present and the
--    selected (FCOM p.646); VNAV armed by its first push (not with G/S
--    or FLARE active; from G/A at any height), disarmed by the second
--    push while armed, a push while active does nothing; engaged when the
--    old VNAV engages it (400 ft, its sub-modes: until the FMC's step 9);
--    V/S, ALT and FLCH end it, not its arm (ATA22 p.340: the second push,
--    an APP request and its engage). The SPD switch does nothing in VNAV,
--    FLCH SPD and TO/GA (FCOM p.642; the old one ended VNAV and FLCH into
--    V/S).
--    ALT HOLD by default in FLCH 8,000 ft away from the path to the MCP
--    altitude (ATA22 p.338; from the nearest point: an estimate). The old
--    G/S engaged ends the pitch mode and VNAV's arm (until step 1d).
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
-- the FMA's pitch numbers (the init's)
M.PITCH_FMA = {TOGA = 1, GS = 2, FLARE = 3, VNAV_SPD = 4, VNAV_ALT = 5, VNAV_PTH = 6, VS = 7, FLCH = 8, ALT = 9}
-- the MCP's V/S window (FCOM p.648)
M.VS_MIN = -8000
M.VS_MAX = 6000
-- ALT HOLD by default in FLCH this far away from the path to the MCP
-- altitude (ATA22 p.338)
M.FLCH_AWAY = 8000

-- the state
function M.new()
    return setmetatable({L = false, C = false, R = false, bar = false, disc = false,
        fd = {L = false, R = false}, off = true,
        roll = nil, lnav_arm = false, hold_hdg = nil, level_t = 0, att_bank = 0, toga_roll_off = false, toga_seen = false,
        pitch = nil, vnav_arm = false, hold_alt = nil, toga_pitch_off = false, togap_seen = false,
        flch_near = nil}, {})
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

-- a pitch mode engaged (the latch of the one before reset)
local function set_pitch(s, mode, alt)
    s.pitch = mode
    s.hold_alt = mode == "ALT" and alt or nil
    s.flch_near = nil
    s.toga_pitch_off = true
end
-- the pitch modes' transitions (table p.335): from the old G/S only before
-- LOC is active, from G/A only at 400 ft RA, none from FLARE
local function pitch_enabled(inp)
    if inp.old_pitch == "FLARE" then return false end
    if inp.old_pitch == "GS" and inp.old_roll == "LOC" then return false end
    return not (inp.old_pitch == "TOGA" and inp.ga and not inp.ground and (inp.ra or 0) < M.GA_RA)
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
        set_pitch(s, "VS")
        return {pitch = "VS"}
    end
    if inp.toga and inp.ground then
        set_roll(s, "HDG_HOLD")
        set_pitch(s, "VS")
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

-- the V/S switch (`inp`: vs the present vertical speed, old_pitch, old_roll,
-- ga, ground, ra): the target it synced, or nil when not engaged
function M.vs(s, inp)
    if not pitch_enabled(inp) then return nil end
    local sync = 0
    if not (s.pitch == "ALT" or (inp.old_pitch == "TOGA" and not s.toga_pitch_off and (inp.vs or 0) < 0)) then
        sync = math.floor((inp.vs or 0) / 100 + 0.5) * 100
        sync = math.max(M.VS_MIN, math.min(M.VS_MAX, sync))
    end
    set_pitch(s, "VS")
    return sync
end

-- the ALT HOLD switch (`inp.alt` the altitude): true when engaged
function M.alt_hold(s, inp)
    if not pitch_enabled(inp) then return false end
    set_pitch(s, "ALT", inp.alt)
    return true
end

-- the FLCH switch (`inp`: ias, mcp_ias, window_open, fmc_speed): true when
-- engaged, and the speed to set (nil: the window's as it is)
function M.flch(s, inp)
    if not pitch_enabled(inp) then return false end
    local speed
    if inp.old_pitch == "TOGA" and not s.toga_pitch_off then
        speed = math.max(inp.ias or 0, inp.mcp_ias or 0)
    elseif not inp.window_open then
        speed = inp.fmc_speed or inp.ias
    end
    set_pitch(s, "FLCH")
    return true, speed
end

-- the VNAV switch: armed, from G/A at any height (table p.335), not from
-- G/S or FLARE
function M.vnav(s, inp)
    if s.vnav_arm then
        s.vnav_arm = false
    elseif s.pitch ~= "VNAV" and inp.old_pitch ~= "GS" and inp.old_pitch ~= "FLARE" then
        s.vnav_arm = true
    end
end

-- the SPD switch works (not in VNAV, FLCH SPD, TO/GA: FCOM p.642)
function M.spd_works(s, inp)
    if inp.old_pitch == "TOGA" and not s.toga_pitch_off then return false end
    return s.pitch ~= "VNAV" and s.pitch ~= "FLCH"
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
    -- the old TO/GA's pitch starts (until step 1e): it replaces the pitch
    -- mode, VNAV too (FCOM p.645), not VNAV's arm (ATA22 p.340)
    local togap = inp.old_pitch == "TOGA"
    if togap and not s.togap_seen then
        s.toga_pitch_off = false
        s.pitch, s.hold_alt, s.flch_near = nil, nil, nil
    end
    s.togap_seen = togap
    local first = not fd_on(s) and M.engaged(s) == 0 and (inp.fd.L or inp.fd.R)
    s.fd.L, s.fd.R = inp.fd.L and true or false, inp.fd.R and true or false
    if first then
        s.off = false
        if inp.ground then return {toga = true} end
        roll_default(s, inp)
        set_pitch(s, "VS")
        return {pitch = "VS"}
    end
    if M.engaged(s) == 0 and not fd_on(s) then
        if not s.off then
            s.off = true
            s.roll, s.lnav_arm, s.hold_hdg, s.level_t, s.att_bank = nil, false, nil, 0, 0
            s.pitch, s.vnav_arm, s.hold_alt = nil, false, nil
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
    -- the old G/S engaged (until step 1d) ends the pitch mode, VNAV's arm
    -- with it (FCOM p.645: G/S deactivates VNAV; the arm goes with the APP
    -- request, ATA22 p.340, still the old code's)
    if inp.old_pitch == "GS" and (s.pitch or s.vnav_arm) then
        s.pitch, s.hold_alt, s.vnav_arm = nil, nil, false
    end
    -- the MCP altitude captured from V/S and FLCH (the old window: `inp.capture`
    -- with `inp.capture_alt`)
    if (s.pitch == "VS" or s.pitch == "FLCH") and inp.capture then
        set_pitch(s, "ALT", inp.capture_alt)
    end
    -- ALT HOLD by default in FLCH 8,000 ft away from the path to the MCP
    -- altitude (ATA22 p.338), measured from the nearest to it the airplane
    -- came in FLCH (an estimate: the source names no point)
    if s.pitch == "FLCH" and inp.alt and inp.capture_alt then
        local d = math.abs(inp.capture_alt - inp.alt)
        local near = s.flch_near and math.abs(inp.capture_alt - s.flch_near)
        if not near or d < near then
            s.flch_near = inp.alt
        elseif d > near + M.FLCH_AWAY then
            set_pitch(s, "ALT", inp.alt)
        end
    end
    -- VNAV: engaged by the old VNAV (`inp.vnav_engaged`); ended there (no
    -- route, its own end) into the old law's mode then (`inp.old_law`, ALT
    -- at the old law's altitude `inp.old_hold_alt`)
    if s.vnav_arm and inp.vnav_engaged then
        s.vnav_arm = false
        set_pitch(s, "VNAV")
    elseif s.pitch == "VNAV" and not inp.vnav_engaged then
        set_pitch(s, inp.old_law, inp.old_hold_alt or inp.alt)
    end
    return nil
end

-- VNAV lost (no route for the old VNAV: until the FMC's step 9): the arm
-- ends; VNAV active ends at the next update (above)
function M.vnav_lost(s)
    s.vnav_arm = false
end

-- the FMA's pitch (the init's numbers): active and armed. The old code's
-- FLARE, G/S, and its TO/GA until a pitch mode replaced it, come first;
-- VNAV the old VNAV's sub-mode (`inp.vnav_fma`); the arms VNAV, else the
-- old G/S's and FLARE's (`inp.old_armed_pitch`)
function M.pitch_fma(s, inp)
    local active = 0
    if inp.old_pitch == "FLARE" then
        active = M.PITCH_FMA.FLARE
    elseif inp.old_pitch == "GS" then
        active = M.PITCH_FMA.GS
    elseif inp.old_pitch == "TOGA" and not s.toga_pitch_off then
        active = M.PITCH_FMA.TOGA
    elseif s.pitch == "VNAV" then
        active = inp.vnav_fma or M.PITCH_FMA.VNAV_SPD
    elseif s.pitch then
        active = M.PITCH_FMA[s.pitch]
    end
    local armed = s.vnav_arm and M.PITCH_FMA.VNAV_SPD or (inp.old_armed_pitch or 0)
    return active, armed
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
