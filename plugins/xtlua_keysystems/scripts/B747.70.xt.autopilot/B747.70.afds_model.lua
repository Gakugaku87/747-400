-- The FCCs' mode logic (6-3, being rebuilt in steps: the plan and sources
-- in docs/overhaul/notes/ATA-22.md §10). Steps 1a-1e: the autopilot's
-- engage and disengage, AUTOPILOT DISC, the flight directors, the default
-- modes on the first F/D ON and on the A/P's engage, everything off; the
-- roll modes HDG SEL, HDG HOLD, ATT and LNAV; the pitch modes V/S, ALT,
-- FLCH SPD and VNAV; the approach modes LOC, G/S and APP; TO/GA (T/O and
-- G/A). The glue (B747.70.xt.autopilot.lua) applies the modes asked for to
-- the old code (its laws until steps 2 and 3) and tells the model which of
-- those is active.
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
--    ON with both off and no A/P engaged: on the ground T/O (roll and
--    pitch: TO/GA), in the air V/S and HDG HOLD, or ATT above 5 degrees of
--    bank (the PW airplanes 109 and 405; the GE 570 none; RR as PW:
--    estimate). With the A/P engaged a F/D shows the A/P's modes.
--  - The A/P engaged (ATA22 p.266, p.338, p.352; FCOM p.640): with a F/D
--    ON in its modes, but from the F/D's takeoff on the ground HDG HOLD
--    and V/S; with both F/Ds OFF V/S and HDG HOLD, or ATT above 5 degrees
--    (as the F/Ds').
--  - All modes off once the A/P is disengaged and both F/Ds are OFF (FCOM
--    p.660), not while a TO/GA push shows the F/Ds with their switches OFF
--    (above 80 kt, flaps out of up: FCOM p.661), until a F/D switch is
--    cycled ON and OFF.
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
--    altitude (ATA22 p.338; from the nearest point: an estimate).
--  - The approach modes (step 1d; ATA22 p.342-343, p.356-357, p.266;
--    FCOM p.650-652, p.669-670): LOC armed by the LOC or APP request (table
--    p.351: from HDG HOLD, HDG SEL, LNAV and ATT, not from T/O or G/A); a
--    LOC only arm disarmed by the second LOC push or LNAV's arm (FCOM's
--    "selecting another roll mode": the figure p.357 has LNAV's arm only);
--    engaged armed at its capture (the old detector until step 2) with the
--    track within 120 degrees of the course, a latch the next roll mode
--    resets (from LOC only before G/S is active). G/S armed by the APP
--    request (table p.335: from V/S, ALT, FLCH, VNAV, not from T/O, G/A or
--    FLARE), engaged armed at its capture (the old detector until step 3)
--    within 80 degrees, either first (the 109 and the 570: FCOM p.669; a
--    405's only with LOC engaged, p.670, by an input no airplane sets: the
--    user's choice of the 109 and the 570); a latch the next pitch mode resets
--    (from G/S only before LOC is active). APP armed (both armed) is
--    disarmed by its second push, a LOC request (G/S's arm only: a
--    localizer approach), LNAV's or VNAV's arm; with LOC engaged a new roll
--    mode ends G/S's arm, with G/S engaged a new pitch mode LOC's (FCOM
--    p.652). The LOC and APP requests end LNAV's arm (p.354), APP VNAV's
--    (p.340). G/A ends them all (FCOM p.660); on the ground they end
--    (ROLLOUT and NOSE LETDOWN go on: step 4). The A/P engaged with a F/D
--    ON and LOC or G/S engaged: HDG HOLD with LOC armed, V/S with G/S armed
--    (ATA22 p.266).
--  - TO/GA (step 1e; ATA22 p.336-337, p.353, p.355; FCOM p.656-657,
--    p.663-668, p.672-673): T/O (pitch and roll, a latch each) by the
--    first F/D switched ON on the ground with no A/P engaged; its pitch
--    reset by the A/P engaged on the ground (HDG HOLD and V/S), the A/T in
--    SPD or a new pitch mode, its roll by a new roll mode (LNAV at 50 ft).
--    G/A (pitch and roll) by a TO/GA switch in the air with the flaps out
--    of up or G/S engaged, from any pitch mode but T/O (table p.335); with
--    T/O's pitch still active (after the takeoff) the push selects only
--    G/A's roll, from 50 ft (FCOM p.656). The switches are inhibited 2 s
--    after the radio altitude goes below 5 ft and enabled 3 s after it goes
--    above (FCOM p.672). G/A ends LOC, G/S, VNAV active and the approach
--    arms, not the LNAV and VNAV arms; it stays through a touchdown. From
--    G/A the roll modes and V/S, ALT HOLD and FLCH only at 400 ft RA, the
--    MCP altitude's capture from T/O or G/A only above 800 ft (table
--    p.335); below 400 ft G/A ends only with the A/P disengaged and both
--    F/Ds OFF (FCOM p.673).
--  - Multi-channel (step 4a; ATA22 p.250, p.256, p.288, p.314, p.318; FCOM
--    p.653, p.662, p.671): the approach selected with a channel engaged
--    arms the others with hydraulic pressure (their CMD lights on); they
--    engage MULTI_S s into LOC and G/S captured below MULTI_RA ft RA with
--    the track within MULTI_TRK degrees of the course (the runway's: the
--    FCC's adjustment of the ILS's heading by up to 5 degrees not made).
--    The arms end with the first channel's disengage or the approach's
--    end (estimate). Below MULTI_RA with two or three channels engaged the
--    autoland status replaces the AFDS status: LAND 3 with three engaged
--    and triple power sources and autoland sensors, LAND 2 with at least
--    two of each (channels and sensors), else NO AUTOLAND; NO AUTOLAND
--    too when a multi-channel approach has no LAND 3 or 2 by NO_LAND_RA
--    ft; LAND 3 to LAND 2 not shown below LAND2_RA ft. FLARE and ROLLOUT
--    armed with LAND 3 or 2. From a multi-channel G/A into another mode
--    only the first channel stays engaged.
--  - FLARE (step 4b; ATA22 p.294, p.332, p.342; FCOM p.671): engaged armed
--    from G/S at the flare height for the sink rate (FLARE_HEIGHT, of gear
--    altitude); the retard at RETARD_RA ft RA; at the touchdown FLARE ends
--    (its annunciation off) into NOSE LETDOWN, until the A/P's disengage
--    or a G/A. No pitch mode from FLARE but G/A.
--  - ROLLOUT (step 4c; FCOM p.664, p.671; ATA22 p.360): engaged armed from
--    LOC below ROLLOUT_RA ft RA; kept on the ground until the A/Ps are
--    disengaged or a G/A.
--  - Runway align (step 4d; ATA22 p.360, figure p.361; FCOM p.670): with
--    LAND 3 or 2 in LOC (multi-channel; G/A and ROLLOUT end it with LOC):
--    the roll law's rudder, no annunciation.
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
-- the MCP altitude captured from T/O or G/A only above CAPT_RA ft (table
-- p.335); after the takeoff a TO/GA push selects G/A's roll from TO_ROLL_RA
-- ft (FCOM p.656)
M.CAPT_RA = 800
M.TO_ROLL_RA = 50
-- the TO/GA switches inhibited INHIBIT_S s after the radio altitude goes
-- below SWITCH_RA ft, enabled ENABLE_S s after it goes above (FCOM p.672)
M.SWITCH_RA = 5
M.INHIBIT_S = 2
M.ENABLE_S = 3
-- a TO/GA push shows the F/Ds with their switches OFF above FD_AUTO_KT
-- (FCOM p.661)
M.FD_AUTO_KT = 80
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
-- LOC captures with the track within LOC_COURSE degrees of the localizer
-- course, G/S within GS_COURSE (FCOM p.650-651; ATA22 p.356)
M.LOC_COURSE = 120
M.GS_COURSE = 80
-- multi-channel (step 4a): engaged MULTI_S s into the conditions below
-- MULTI_RA ft RA, the track within MULTI_TRK degrees of the course (ATA22
-- p.288, p.318); NO AUTOLAND by NO_LAND_RA ft without LAND 3 or 2 (FCOM
-- p.653); no LAND 3 to LAND 2 below LAND2_RA ft (FCOM p.662)
M.MULTI_S = 5
M.MULTI_RA = 1500
M.MULTI_TRK = 2
M.NO_LAND_RA = 600
M.LAND2_RA = 200
-- the AFDS status (the init's numbers)
M.STATUS = {FD = 1, CMD = 2, LAND2 = 3, LAND3 = 4, NO_AUTOLAND = 5}
-- FLARE (step 4b): its height (ft of gear altitude) by the sink rate (ft/s)
-- (ATA22 p.342: 40 under 8.5, 50 from 12.5 to 14.5, 60 over 18; between
-- them straight: an estimate); the retard RETARD_RA ft RA (p.294)
M.FLARE_HEIGHT = {{8.5, 40}, {12.5, 50}, {14.5, 50}, {18, 60}}
M.RETARD_RA = 25
-- ROLLOUT (step 4c): engaged below ROLLOUT_RA ft RA (FCOM p.664, p.671;
-- ATA22 p.360's 2 ft is about X-Plane's main gear height there: its radio
-- altitude reads about 3.3 ft as the main gear touches)
M.ROLLOUT_RA = 5

-- the state
function M.new()
    return setmetatable({L = false, C = false, R = false, bar = false, disc = false,
        fd = {L = false, R = false}, off = true,
        roll = nil, lnav_arm = false, hold_hdg = nil, level_t = 0, att_bank = 0,
        pitch = nil, vnav_arm = false, hold_alt = nil,
        flch_near = nil, loc_arm = false, gs_arm = false, loc_new = false,
        fd_auto = false, inhibit = false, ra_low = false, ra_t = 0,
        arm = {L = false, C = false, R = false}, first = nil, multi_t = 0, multi_app = false,
        land = nil, flare_arm = false, rollout_arm = false, was_ga = false,
        letdown = false, retard = false, rwy_align = false}, {})
end

-- the flare height (ft of gear altitude) for a sink rate (ft/s)
function M.flare_height(sink)
    local t = M.FLARE_HEIGHT
    if sink <= t[1][1] then return t[1][2] end
    for i = 2, #t do
        if sink <= t[i][1] then
            local a, b = t[i - 1], t[i]
            return a[2] + (b[2] - a[2]) * (sink - a[1]) / (b[1] - a[1])
        end
    end
    return t[#t][2]
end

-- the channels engaged
function M.engaged(s)
    return (s.L and 1 or 0) + (s.C and 1 or 0) + (s.R and 1 or 0)
end
-- the channels armed for multi-channel (step 4a)
function M.armed(s)
    return (s.arm.L and 1 or 0) + (s.arm.C and 1 or 0) + (s.arm.R and 1 or 0)
end
local function disarm(s)
    s.arm.L, s.arm.C, s.arm.R = false, false, false
    s.multi_t = 0
end
local function fd_on(s) return s.fd.L or s.fd.R end
-- the F/Ds shown: a switch ON, or TO/GA's display with them OFF
local function fd_shown(s) return fd_on(s) or s.fd_auto end
local function toga(mode) return mode == "TO" or mode == "GA" end

-- a roll mode engaged (the latch of the one before reset)
local function set_roll(s, mode, bank)
    s.roll = mode
    s.hold_hdg, s.level_t = nil, 0
    s.att_bank = mode == "ATT" and bank or 0
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

-- G/A's roll below 400 ft RA (table p.351: the roll modes from G/A only
-- above it; from T/O at any height)
local function ga_low(s, inp)
    return s.roll == "GA" and not inp.ground and (inp.ra or 0) < M.GA_RA
end

-- a pitch mode engaged (the latch of the one before reset)
local function set_pitch(s, mode, alt)
    s.pitch = mode
    s.hold_alt = mode == "ALT" and alt or nil
    s.flch_near = nil
end
-- the pitch modes' transitions (table p.335): from G/S only before LOC is
-- active, from G/A only at 400 ft RA, none from FLARE
local function pitch_enabled(s, inp)
    if s.pitch == "FLARE" then return false end
    if s.pitch == "GS" and s.roll == "LOC" then return false end
    return not (s.pitch == "GA" and not inp.ground and (inp.ra or 0) < M.GA_RA)
end
-- a pitch mode replacing G/S ends LOC's arm (109/570: FCOM p.652; ATA22
-- p.357), a roll mode replacing LOC G/S's arm (ATA22 p.343)
local function gs_replaced(s)
    if s.pitch == "GS" then s.loc_arm = false end
end
local function loc_replaced(s)
    if s.roll == "LOC" then s.gs_arm = false end
end
-- into LOC (table p.351): from HDG HOLD, HDG SEL, LNAV, ATT (not in the
-- table: as HDG HOLD, an estimate) or none; not from T/O or G/A
local function loc_enabled(s, inp)
    return s.roll ~= "LOC" and not toga(s.roll)
end
-- into G/S (table p.335): from V/S, ALT, FLCH, VNAV or none; not from
-- T/O, G/A or FLARE
local function gs_enabled(s, inp)
    if s.pitch == "GS" or s.pitch == "FLARE" then return false end
    return not toga(s.pitch)
end
-- the 109 and the 570 capture G/S either first (FCOM p.669), a 405 only
-- with LOC engaged (p.670): `inp.gs_after_loc`, which no airplane sets (the
-- airplanes built are the 109, PW and RR as PW, and the 570, GE: the
-- user's choice, 2026-10-27)
local function gs_after_loc(inp)
    return inp.gs_after_loc == true
end

-- a CMD switch pushed: channel ch. `inp`: {hyd = {[1] = psi, [2], [3]},
-- bank, engine, ground}. Returns the other modes asked for ({pitch}) or nil
function M.cmd(s, ch, inp)
    if s.bar or s[ch] or M.engaged(s) > 0 then return nil end
    if ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then return nil end
    s[ch] = true
    s.first = ch
    s.disc = false
    s.off = false
    if not fd_shown(s) then
        roll_default(s, inp)
        set_pitch(s, "VS")
        return {pitch = "VS"}
    end
    -- the A/P engaged on the ground ends T/O (ATA22 p.337): HDG HOLD and V/S
    if s.pitch == "TO" and inp.ground then
        set_roll(s, "HDG_HOLD")
        set_pitch(s, "VS")
        return {pitch = "VS"}
    end
    local act
    if s.roll == "LOC" then
        set_roll(s, "HDG_HOLD")
        s.loc_arm = true
    end
    if s.pitch == "GS" then
        set_pitch(s, "VS")
        s.gs_arm = true
        act = {pitch = "VS"}
    end
    return act
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
-- without the warning
function M.disengage(s, quiet)
    local was = M.engaged(s)
    s.L, s.C, s.R = false, false, false
    if not quiet then dropped(s, was) end
end

-- the HDG SEL switch (`inp`: old_roll, gs_active, ground, ra, hdg_valid):
-- true when engaged. HDG SEL valid needed (ATA22 p.352): NORM's reference
-- in the polar areas gives it no heading (FCOM p.1046; step 2a)
function M.hdg_sel(s, inp)
    if inp.hdg_valid == false then return false end
    if (s.roll == "LOC" and s.pitch == "GS") or ga_low(s, inp) then return false end
    loc_replaced(s)
    set_roll(s, "HDG_SEL")
    return true
end

-- the HDG HOLD switch; `default` (the HDG REF switch moved in HDG SEL:
-- ATA22 p.352) without the transition's conditions. True when engaged
function M.hdg_hold(s, inp, default)
    if not default and ((s.roll == "LOC" and s.pitch == "GS") or ga_low(s, inp)) then return false end
    loc_replaced(s)
    set_roll(s, "HDG_HOLD")
    return true
end

-- the LNAV switch
function M.lnav(s, inp)
    if s.lnav_arm then
        s.lnav_arm = false
    elseif s.roll ~= "LNAV" and s.roll ~= "LOC" and not ga_low(s, inp) then
        s.lnav_arm = true
        -- LOC's arm ends, G/S's with it (APP disarmed: ATA22 p.343, p.357)
        if s.loc_arm then s.loc_arm, s.gs_arm = false, false end
    end
end

-- the V/S switch (`inp`: vs the present vertical speed, ground, ra): the
-- target it synced, or nil when not engaged
function M.vs(s, inp)
    if not pitch_enabled(s, inp) then return nil end
    gs_replaced(s)
    local sync = 0
    if not (s.pitch == "ALT" or (toga(s.pitch) and (inp.vs or 0) < 0)) then
        sync = math.floor((inp.vs or 0) / 100 + 0.5) * 100
        sync = math.max(M.VS_MIN, math.min(M.VS_MAX, sync))
    end
    set_pitch(s, "VS")
    return sync
end

-- the ALT HOLD switch (`inp.alt` the altitude): true when engaged
function M.alt_hold(s, inp)
    if not pitch_enabled(s, inp) then return false end
    gs_replaced(s)
    set_pitch(s, "ALT", inp.alt)
    return true
end

-- the FLCH switch (`inp`: ias, mcp_ias, window_open, fmc_speed): true when
-- engaged, and the speed to set (nil: the window's as it is)
function M.flch(s, inp)
    if not pitch_enabled(s, inp) then return false end
    gs_replaced(s)
    local speed
    if toga(s.pitch) then
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
    elseif s.pitch ~= "VNAV" and s.pitch ~= "GS" and s.pitch ~= "FLARE" then
        s.vnav_arm = true
        -- APP armed: disarmed (ATA22 p.343, p.357)
        if s.loc_arm and s.gs_arm then s.loc_arm, s.gs_arm = false, false end
    end
end

-- the SPD switch works (not in VNAV, FLCH SPD, TO/GA: FCOM p.642)
function M.spd_works(s, inp)
    return s.pitch ~= "VNAV" and s.pitch ~= "FLCH" and not toga(s.pitch)
end

-- the LOC switch: a LOC only arm, the second push disarms; with G/S armed,
-- the LOC request ends G/S's arm (a localizer approach: FCOM p.652; ATA22
-- p.343); else LOC armed when enabled, LNAV's arm ends (p.354)
function M.loc(s, inp)
    if s.loc_arm and not s.gs_arm then
        s.loc_arm = false
    elseif s.gs_arm then
        s.gs_arm = false
    elseif loc_enabled(s, inp) then
        s.loc_arm = true
        s.lnav_arm = false
    end
end

-- the APP switch: APP armed (both), the second push disarms; else LOC and
-- G/S armed (each unless engaged) when both are enabled or engaged; the
-- arms of LNAV (p.354) and VNAV (p.340) end. With a channel engaged the
-- others with hydraulic pressure arm for multi-channel (step 4a; ATA22
-- p.314)
function M.app(s, inp)
    if s.loc_arm and s.gs_arm then
        s.loc_arm, s.gs_arm = false, false
        disarm(s)
        return
    end
    if not (loc_enabled(s, inp) or s.roll == "LOC") or not (gs_enabled(s, inp) or s.pitch == "GS") then return end
    if s.roll ~= "LOC" then s.loc_arm = true end
    if s.pitch ~= "GS" then s.gs_arm = true end
    s.lnav_arm, s.vnav_arm = false, false
    if M.engaged(s) > 0 and not s.bar then
        for _, ch in ipairs(M.CHANNELS) do
            if not s[ch] and ((inp.hyd or {})[M.HYD[ch]] or 0) >= M.HYD_MIN then s.arm[ch] = true end
        end
    end
end

-- a TO/GA switch pushed (`inp`: ground, ra, flaps_up, ias): G/A in the air
-- (not while the switches are inhibited after a touchdown) with the flaps
-- out of up or G/S engaged (ATA22 p.337), from any pitch mode but T/O
-- (table p.335; from none too: FCOM p.657); with T/O's pitch active only
-- G/A's roll, from 50 ft (FCOM p.656). G/A ends LOC, G/S and their arms
-- (FCOM p.660), not LNAV's or VNAV's arm (ATA22 p.340, p.354). Shown with
-- the F/D switches OFF above 80 kt with the flaps out of up (FCOM p.661).
-- True when G/A's pitch engaged (the glue's go-around for the old code)
function M.toga(s, inp)
    if inp.ground or s.inhibit then return false end
    if inp.flaps_up and s.pitch ~= "GS" then return false end
    local pitch = s.pitch ~= "TO"
    if not pitch and (inp.ra or 0) < M.TO_ROLL_RA then return false end
    if pitch then set_pitch(s, "GA") end
    if s.roll ~= "TO" then set_roll(s, "GA") end
    s.loc_arm, s.gs_arm = false, false
    s.off = false
    if not fd_on(s) and M.engaged(s) == 0 and (inp.ias or 0) > M.FD_AUTO_KT and not inp.flaps_up then
        s.fd_auto = true
    end
    return pitch
end

-- TO/GA active (the old code's TOGA_status: until steps 2 and 3)
function M.toga_active(s)
    return toga(s.roll) or toga(s.pitch)
end

-- the F/Ds shown with their switches OFF (TO/GA's display)
function M.fd_auto(s)
    return s.fd_auto
end

-- LOC engaged since the last call (the glue sets the MCP heading to the
-- course: ATA22 p.290)
function M.loc_engaged_now(s)
    local n = s.loc_new
    s.loc_new = false
    return n
end

-- the autoland status (step 4a; ATA22 p.250, p.256; FCOM p.653, p.662):
-- below MULTI_RA in an approach with two or three channels engaged, LAND 3
-- with three and triple power sources and sensors (`inp.power`,
-- `inp.sensors`: how many of each are valid), LAND 2 with at least two
-- sensors, else NO AUTOLAND; NO AUTOLAND too in a multi-channel approach
-- down to one channel after a status, or without one by NO_LAND_RA; LAND 3
-- kept below LAND2_RA. FLARE and ROLLOUT armed with LAND 3 or 2
-- (FCOM p.671), FLARE and ROLLOUT until they engage (steps 4b and 4c),
-- the status kept through the flare, the nose let down and the rollout;
-- runway align with LAND 3 or 2 in LOC (step 4d: p.361)
local function land_status(s, inp)
    local n = M.engaged(s)
    local approach = s.loc_arm or s.gs_arm or s.roll == "LOC" or s.pitch == "GS" or s.pitch == "FLARE"
        or s.letdown or s.roll == "ROLLOUT"
    if not approach then s.multi_app = false end
    if approach and n >= 2 then s.multi_app = true end
    local ra = inp.ra or 9999
    local land
    if approach and n >= 2 and ra < M.MULTI_RA then
        local sensors, power = inp.sensors or 3, inp.power or 3
        if n >= 3 and sensors >= 3 and power >= 3 then
            land = "LAND3"
        elseif sensors >= 2 then
            land = "LAND2"
        else
            land = "NO_AUTOLAND"
        end
        if land == "LAND2" and s.land == "LAND3" and ra < M.LAND2_RA then land = "LAND3" end
    elseif approach and s.multi_app and ra < M.MULTI_RA and (s.land or ra < M.NO_LAND_RA) then
        land = "NO_AUTOLAND"
    end
    s.land = land
    local landing = land == "LAND3" or land == "LAND2"
    s.flare_arm = landing and s.pitch == "GS"
    s.rollout_arm = landing and s.roll == "LOC"
    s.rwy_align = landing and s.roll == "LOC"
end

-- each frame: `inp` {fd = {L, R} the switches ON, hyd, bank, engine,
-- ground, ra, hdg (the heading HDG HOLD holds), lnav_valid, at_spd (the
-- A/T in SPD), dt}. The channels without hydraulic pressure drop out; the
-- TO/GA switches' inhibit; the F/D switched ON first asks for its modes;
-- everything off once neither the A/P nor a F/D is on; HDG HOLD's heading,
-- LNAV's engage. Returns the other modes asked for ({pitch} or
-- {all_off = true}) or nil
function M.update(s, inp)
    local was = M.engaged(s)
    for _, ch in ipairs(M.CHANNELS) do
        if s[ch] and ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then s[ch] = false end
    end
    dropped(s, was)
    -- the TO/GA switches: inhibited 2 s after the radio altitude goes below
    -- 5 ft, enabled 3 s after it goes above (FCOM p.672)
    local low = (inp.ra or 0) < M.SWITCH_RA
    if low ~= s.ra_low then s.ra_low, s.ra_t = low, 0 end
    s.ra_t = s.ra_t + (inp.dt or 0)
    if low and s.ra_t >= M.INHIBIT_S then s.inhibit = true end
    if not low and s.ra_t >= M.ENABLE_S then s.inhibit = false end
    -- TO/GA's display with the F/D switches OFF ends when a switch is
    -- cycled ON and OFF (FCOM p.661)
    if s.fd_auto and ((s.fd.L and not inp.fd.L) or (s.fd.R and not inp.fd.R)) then s.fd_auto = false end
    local first = not fd_shown(s) and M.engaged(s) == 0 and (inp.fd.L or inp.fd.R)
    s.fd.L, s.fd.R = inp.fd.L and true or false, inp.fd.R and true or false
    if first then
        s.off = false
        -- on the ground T/O (ATA22 p.337; its roll with it: p.353)
        if inp.ground then
            set_roll(s, "TO")
            set_pitch(s, "TO")
            return nil
        end
        roll_default(s, inp)
        set_pitch(s, "VS")
        return {pitch = "VS"}
    end
    if M.engaged(s) == 0 and not fd_shown(s) then
        if not s.off then
            s.off = true
            s.roll, s.lnav_arm, s.hold_hdg, s.level_t, s.att_bank = nil, false, nil, 0, 0
            s.pitch, s.vnav_arm, s.hold_alt = nil, false, nil
            s.loc_arm, s.gs_arm = false, false
            disarm(s)
            s.land, s.flare_arm, s.rollout_arm, s.multi_app = nil, false, false, false
            s.rwy_align = false
            s.letdown, s.retard = false, false
            return {all_off = true}
        end
        return nil
    end
    -- T/O's pitch reset by the A/T in SPD (ATA22 p.337)
    if s.pitch == "TO" and inp.at_spd then s.pitch = nil end
    if s.roll == "HDG_HOLD" and not s.hold_hdg then
        if math.abs(inp.bank or 0) < M.LEVEL then
            s.level_t = s.level_t + (inp.dt or 0)
            if s.level_t >= M.LEVEL_TIME then s.hold_hdg = inp.hdg end
        else
            s.level_t = 0
        end
    end
    if s.lnav_arm and inp.lnav_valid and (inp.ra or 0) > M.LNAV_RA and not ga_low(s, inp) then
        s.lnav_arm = false
        set_roll(s, "LNAV")
    end
    -- FLARE (step 4b; ATA22 p.342; FCOM p.671): armed (LAND 3 or 2, G/S
    -- engaged), engaged at the flare height for the sink rate (`inp.gear_alt`,
    -- the inertial `inp.ivs`, else `inp.vs`); the retard RETARD_RA ft RA
    -- into it (ATA22 p.294), kept through the touchdown (the A/T's IDLE
    -- stays: FCOM p.671); at the touchdown FLARE ends and the nose comes
    -- down (NOSE LETDOWN: p.294, p.332) until the A/P is disengaged or a G/A
    if s.flare_arm and s.pitch == "GS" and not inp.ground and inp.gear_alt
        and inp.gear_alt <= M.flare_height(-(inp.ivs or inp.vs or 0) / 60) then
        set_pitch(s, "FLARE")
        s.flare_arm = false
    end
    if s.pitch == "FLARE" and inp.ground then
        s.pitch, s.letdown = nil, true
    end
    if s.letdown and (M.engaged(s) == 0 or toga(s.pitch)) then s.letdown = false end
    s.retard = (s.pitch == "FLARE" and (inp.ra or 9999) <= M.RETARD_RA) or (s.retard and s.letdown)
    -- ROLLOUT (step 4c; FCOM p.664, p.671): armed (LAND 3 or 2, LOC
    -- engaged), engaged below ROLLOUT_RA ft RA, until the A/Ps are
    -- disengaged (FCOM p.671) or a G/A
    if s.rollout_arm and s.roll == "LOC" and (inp.ra or 9999) < M.ROLLOUT_RA then
        set_roll(s, "ROLLOUT")
        s.rollout_arm = false
    end
    if s.roll == "ROLLOUT" and M.engaged(s) == 0 then s.roll = nil end
    -- on the ground the approach modes end (ROLLOUT and NOSE LETDOWN go on)
    if inp.ground and (s.loc_arm or s.gs_arm or s.roll == "LOC" or s.pitch == "GS") then
        s.loc_arm, s.gs_arm = false, false
        if s.roll == "LOC" then s.roll = nil end
        if s.pitch == "GS" then s.pitch = nil end
    end
    -- LOC captured (`inp.loc_detect`: the old detector until step 2) with the
    -- track within 120 degrees of the course (`inp.course_err`): LNAV and its
    -- arm end (FCOM p.645)
    local err = math.abs(inp.course_err or 180)
    if s.loc_arm and inp.loc_detect and err < M.LOC_COURSE then
        s.loc_arm, s.lnav_arm = false, false
        set_roll(s, "LOC")
        s.loc_new = true
    end
    -- G/S captured (`inp.gs_detect`: the old detector until step 3) within
    -- 80 degrees (a 405: only with LOC engaged)
    if s.gs_arm and inp.gs_detect and err < M.GS_COURSE and (s.roll == "LOC" or not gs_after_loc(inp)) then
        s.gs_arm, s.vnav_arm = false, false
        set_pitch(s, "GS")
    end
    -- multi-channel (step 4a): the arms end with the first channel's
    -- disengage (ATA22 p.314), a channel's hydraulics or the approach's end
    -- (estimate); the armed channels engage MULTI_S s into LOC and G/S below
    -- MULTI_RA with the track along the course (p.288, p.318)
    if s.first and not s[s.first] then disarm(s) end
    if not (s.loc_arm or s.gs_arm or s.roll == "LOC" or s.pitch == "GS") then disarm(s) end
    for _, ch in ipairs(M.CHANNELS) do
        if s.arm[ch] and ((inp.hyd or {})[M.HYD[ch]] or 0) < M.HYD_MIN then s.arm[ch] = false end
    end
    if M.armed(s) > 0 then s.multi_app = true end
    if M.armed(s) > 0 and s.roll == "LOC" and s.pitch == "GS" and (inp.ra or 9999) < M.MULTI_RA and err <= M.MULTI_TRK then
        s.multi_t = s.multi_t + (inp.dt or 0)
        if s.multi_t >= M.MULTI_S then
            for _, ch in ipairs(M.CHANNELS) do
                if s.arm[ch] then s[ch] = true end
            end
            disarm(s)
        end
    else
        s.multi_t = 0
    end
    -- the MCP altitude captured from V/S and FLCH, from T/O and G/A above
    -- 800 ft RA (table p.335) (the old window: `inp.capture` with
    -- `inp.capture_alt`)
    local from_toga = toga(s.pitch) and (inp.ra or 0) > M.CAPT_RA
    if (s.pitch == "VS" or s.pitch == "FLCH" or from_toga) and inp.capture then
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
    -- from a multi-channel G/A into another mode, roll or pitch, the first
    -- channel only (ATA22 p.318)
    local ga = toga(s.roll) and toga(s.pitch)
    if s.was_ga and not ga and M.engaged(s) >= 2 then
        local keep = s.first and s[s.first] and s.first
        for _, ch in ipairs(M.CHANNELS) do
            if not keep and s[ch] then keep = ch end
            if ch ~= keep then s[ch] = false end
        end
        s.first = keep
    end
    s.was_ga = ga
    land_status(s, inp)
    return nil
end

-- the AFDS status (the init's numbers): the autoland status, else CMD
-- with a channel engaged, FD with a F/D shown
function M.status(s)
    if s.land then return M.STATUS[s.land] end
    if M.engaged(s) > 0 then return M.STATUS.CMD end
    if fd_shown(s) then return M.STATUS.FD end
    return 0
end

-- VNAV lost (no route for the old VNAV: until the FMC's step 9): the arm
-- ends; VNAV active ends at the next update (above)
function M.vnav_lost(s)
    s.vnav_arm = false
end

-- the FMA's pitch (the init's numbers): active and armed. T/O and G/A
-- TO/GA; VNAV the old VNAV's sub-mode (`inp.vnav_fma`); FLARE (step 4b);
-- the arms G/S, else VNAV, else FLARE (step 4a: with LAND 3 or 2)
function M.pitch_fma(s, inp)
    local active = 0
    if toga(s.pitch) then
        active = M.PITCH_FMA.TOGA
    elseif s.pitch == "VNAV" then
        active = inp.vnav_fma or M.PITCH_FMA.VNAV_SPD
    elseif s.pitch then
        active = M.PITCH_FMA[s.pitch]
    end
    local armed = s.flare_arm and M.PITCH_FMA.FLARE or 0
    if s.gs_arm then
        armed = M.PITCH_FMA.GS
    elseif s.vnav_arm then
        armed = M.PITCH_FMA.VNAV_SPD
    end
    return active, armed
end

-- the FMA's roll (the init's numbers): active and armed. T/O and G/A
-- TO/GA; the arms LNAV, LOC, else ROLLOUT (step 4a: with LAND 3 or 2)
function M.roll_fma(s, inp)
    local active = 0
    if toga(s.roll) then
        active = M.ROLL_FMA.TOGA
    elseif s.roll then
        active = M.ROLL_FMA[s.roll]
    end
    local armed = s.rollout_arm and M.ROLL_FMA.ROLLOUT or 0
    if s.lnav_arm then
        armed = M.ROLL_FMA.LNAV
    elseif s.loc_arm then
        armed = M.ROLL_FMA.LOC
    end
    return active, armed
end

return M
