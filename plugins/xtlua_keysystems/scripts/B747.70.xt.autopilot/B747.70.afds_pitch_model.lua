-- The FCCs' pitch laws (6-3 steps 3a to 3c; the plan and sources in
-- docs/overhaul/notes/ATA-22.md §10, §18, §19 and §22): the pitch command,
-- the attitude the A/P flies and the F/Ds show, of V/S, ALT (the hold and
-- the MCP altitude's capture), the speed laws (FLCH, T/O, G/A), G/S and
-- its capture, and the old VNAV's laws, out of the pitch mode the AFDS
-- model (B747.70.afds_model.lua) has.
--  - V/S: the MCP's vertical speed against the IRUs' inertial one (ATA22
--    p.344); 000 holds the altitude where it was set (ATA22 p.282, p.338:
--    the FMA stays V/S).
--  - ALT: the altitude the AFDS model holds (the push's, or the MCP
--    altitude from its capture: ATA22 p.346), its error made a vertical
--    speed, at most the one that levels off at the capture's 0.05 g
--    (ATA22 p.286), the altitude taken ANTICIPATE_S ahead; closing on it,
--    never more than when the law started until the level-off asks for
--    less. The capture starts (`capture`, the AFDS model's input: before,
--    the old window) when the airplane, closing on the MCP altitude, is no
--    farther than that level-off and CAPTURE_LAG_S of its vertical speed.
--  - FLCH SPD, the old VNAV's speed (step 3b; ATA22 p.344): the speed
--    through the elevator, to the MCP's (the old VNAV's), within the speed
--    protection (FCOM p.675: the minimum maneuvering speed, 5 kt above it
--    with the flaps out, and the maximum less 5 kt).
--  - T/O (FCOM p.664, p.666): 8 degrees on the ground; in the air the
--    speed, the higher of V2 + 10 and the rotation's speed + 10 (pitch
--    over 2 degrees), the speed then once above it 5 s (up to V2 + 25),
--    the MCP's when set higher; V2 the IAS/MACH window's (FCOM's note);
--    not over the PLI. In a windshear as G/A (ATA22 p.344). (The FMC's
--    step 9h3b) An engine failure (ATA22 p.264; FCOM p.666): the speed
--    then within V2 and V2 + 10 (failed on the ground, the lift-off's),
--    the MCP's when set higher, no more raising; the blend from 0 to 600
--    fpm.
--  - G/A (FCOM p.664, p.674; ATA22 p.344): the higher of the MCP's and the
--    speed then, the speed then once above it 5 s (up to MCP + 25, or the
--    start's speed when it was more); from 600 to 1,200 fpm of climb
--    from the attitude (15 degrees, or 1 below the PLI) to the speed.
--    (Step 9h3b) With an engine out up to MCP + 10 and the blend from 0
--    to 600 fpm (ATA22 p.298).
--  - VNAV: the old VNAV's laws by its flags (until the FMC's step 9).
--  - G/S (step 3c; ATA22 p.346): the deviation made a distance from the
--    beam's centre (G/S DEV ALT) with the distance to the transmitter from
--    the radio altitude on an assumed 3 degree glide slope; blended into
--    the inertial vertical speed against the beam's (the inertial path
--    control: on through a lost signal, the path held); the beam's
--    vertical speed at the ground speed less GS_K of the distance. The
--    capture (`gs_capture`, the AFDS model's input; ATA22 p.292: the
--    distance from the beam's centre and the deviation's rate): closing
--    on the beam no farther than the change of path at G_LIMIT and
--    GS_LEAD_S of the closing take, or within GS_BAND.
--  - FLARE (step 4b; ATA22 p.294, p.346): from where it engages on the
--    gear altitude, the sink rate then until a steady deceleration of
--    FLARE_DECEL down to TD_SINK ft/s at the touchdown asks for less (the
--    deceleration's change of path fed forward), followed at K_FLARE
--    within FLARE_G, not raised under FLARE_HOLD_FT; then NOSE LETDOWN
--    on the ground (p.294, p.332): the command from the attitude down
--    LETDOWN_RATE degrees a second to LETDOWN_PITCH.
-- A vertical speed asks for its flight path; the command moves at
-- K_PATH times the flight path's error a second, the path flown taken
-- LEAD_S ahead on the inertial vertical acceleration (damping: ATA22
-- p.346), at most the G_LIMIT's, from the attitude where the law starts
-- (the pitch attitude integrator synchronized: ATA22 p.332). The numbers
-- are estimates (the sources give the inputs, not the gains), tuned on a
-- lagged airplane that flies as X-Plane's 747 did in s107's first run
-- (the attitude 2 s behind the command, the path 3 s behind the
-- attitude): there the level-offs had overshot 200 ft; tuned for the path
-- 1.5 times as slow too (s107's second run had overshot 74 ft).
-- The speed laws (step 3b) ask for the acceleration that closes the speed
-- error in SPD_TAU_S (at most SPD_ACCEL): the flight path that would make
-- the difference from the acceleration now, against the path flown LEAD_S
-- ahead (as above), K_PATH again (less below SPD_K_KT); FLCH and VNAV
-- within SPD_G, T/O and G/A at most TOGA_RATE. Estimates too, tuned on the
-- lagged airplane with a speed (the thrust's excess less the climb):
-- undamped without the lead (250 to 280 kt overshot 18 kt); within SPD_G =
-- 0.05 a FLCH climb's entry overshot 14 kt (0.1: 9 kt); T/O and G/A slower
-- than TOGA_RATE overshot more and raised the target. In X-Plane at 170 kt
-- (s109) the A/P's attitude loop, less damped there, and the full K_PATH
-- swung the pitch 3.6 degrees every 12 s; on an attitude loop as damped
-- (zeta 0.3) 0.17 left 0.6 degrees.
-- (2026-11-12; notes/ATA-22.md §62) FLCH's and VNAV SPD's flight path while
-- the speed is changed against their way (`way`: 1 a climb, -1 a descent)
-- goes no further than near level: gaining on the target in a climb the
-- path is not under SPD_LEVEL_FPM of climb, slowing to it in a descent not
-- over as much of descent (`way_fpm` another rate: the driftdown's 300
-- fpm). FCTM p.118 (3.30): with an engine inoperative VNAV commands a
-- near-level climb segment for the acceleration and FLCH's F/D a near
-- level one, the acceleration what the thrust gives; FCOM p.1268: slowing
-- to the E/O speed in the driftdown the rate of descent decreases to a
-- minimum of 300 fpm. The climb's figure is an estimate (the sources give
-- none). With little thrust to spare (near level would leave the speed
-- less than SPD_LEVEL_FPM of path for its gain) the path goes on to level
-- flight at the most: while the thrust holds level flight at the speed,
-- no altitude is given for a gain of speed. Short of that the speed still
-- comes first: the path goes past level flight to the one that keeps the
-- speed in step with its target (ATA22 p.338: FLCH can take the airplane
-- away from the MCP altitude; FCOM p.646: the pitch holds the selected
-- speed) and, for a slow gain, as far again as that is past level, at most
-- SPD_LEVEL_FPM (an estimate); and as far as the way back within the speed
-- protection's limits asks (FCOM p.675). What the law asks within about a
-- knot of its target is as before, and so are T/O and G/A (their blend
-- from the attitude).
-- Before, the law took all the acceleration asked for (up to SPD_ACCEL)
-- from the path: at 347.5 t VNAV SPD's step to the ECON climb speed at
-- 10,000 ft (272 to 340 kt, THR REF) asked for 1.5 kt/s where the climb
-- thrust's excess, about 2,100 fpm, gives 0.93 to 1.07 kt/s in level
-- flight, and the airplane went down some 300 ft in 35 s (-839 fpm in the
-- record: the user's flight, 2026-11-12). On the lagged airplane with that
-- excess (1.0 kt/s): down to -968 fpm and 514 ft lost before, not under
-- 100 fpm since, within a knot of 340 kt after 85 s (62 s before).
-- Pure: the airplane's state in, the command out.
--   local P = B747_afds_pitch_model                       -- in XTLua, after dofile
--   local P = dofile(".../B747.70.afds_pitch_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_afds_pitch_model = M

-- the command's rate: K_PATH degrees a second for each degree of flight
-- path error, the normal acceleration within G_LIMIT (the capture's 0.05
-- g, ATA22 p.286, for all: estimate)
M.K_PATH = 0.25
M.G_LIMIT = 0.05
-- (2026-11-07) the ALT law's K_PATH by the lift coefficient, CL = W / (q S)
-- with the dynamic pressure q and the gross weight W (WING_AREA the
-- 747-400's reference wing area, 5,500 ft2): PATH_K_LO of it up to
-- PATH_CL_LO, all of it from PATH_CL_HI, between them in proportion
-- (estimates: the sources give the inputs, not the gains, ATA22 p.330,
-- p.346). The flight path follows the attitude on the lift slope over the
-- lift flown, CL_alpha / CL, so the lighter the airplane for its dynamic
-- pressure the faster the path answers the attitude: the path's lag
-- against the loop's period (10 to 13 s) grows with CL, and with it the
-- gain the loop stands; under PATH_CL_LO the lag is short against the
-- period and the gain the loop stands is the same. (The attitude loop,
-- B747.19.xt.afds_control.lua, keeps its gains above 250 kt.) At 238 t and
-- FL350 to FL390 at M.85 (CL 0.38 to 0.46) the altitude hold swung every
-- 10.5 to 11.5 s by 75 to 140 fpm with all of K_PATH, at 306 t and FL350
-- (0.49) by 66 fpm, while at 306 t and FL370 (0.51 to 0.53) and at 10,000
-- ft and 250 kt (0.5 to 0.57, s107, s108) all of it held. Sweeps of the
-- gain in X-Plane (notes/ATA-22.md §53): at CL 0.31 (FL250, 334 kt, 270 t)
-- and 0.42 (FL370, 238 t) 0.8 decayed slowly and 0.7 held, at 0.45 (FL310,
-- 306 t) 0.9 and 0.8, at 0.49 (FL350, 306 t) 0.85 and 0.75. Before
-- (2026-11-02, §44): (290 / IAS) ^ 3.5 above 290 KIAS, from the same swing
-- at FL250 and 334 KIAS at 270 t (0.61 there), which left the light, high
-- cruise under 290 KIAS with all of it. The speed laws climbed steadily at
-- 340 kt. The V/S law (V/S, the old VNAV's path) keeps all of it
-- (2026-11-03: with less the high-speed VNAV descent fell 900 ft above its
-- path, s206)
M.PATH_CL_LO, M.PATH_CL_HI, M.PATH_K_LO = 0.45, 0.60, 0.7
M.WING_AREA = 511
function M.path_gain(inp)
    local q, w = inp and inp.q, inp and inp.weight
    if not (q and w and q > 0 and w > 0) then return 1 end
    local cl = w * 9.80665 / (q * M.WING_AREA)
    if cl >= M.PATH_CL_HI then return 1 end
    if cl <= M.PATH_CL_LO then return M.PATH_K_LO end
    return M.PATH_K_LO + (1 - M.PATH_K_LO) * (cl - M.PATH_CL_LO) / (M.PATH_CL_HI - M.PATH_CL_LO)
end
-- ALT: the altitude error's vertical speed, K_ALT of the error a second
-- (estimate), at most the capture's level-off
M.K_ALT = 0.1
-- the capture starts this much earlier than the level-off needs (the
-- command's and the airplane's lag: estimate), or within CAPTURE_NEAR ft
M.CAPTURE_LAG_S = 10
M.CAPTURE_NEAR = 20
-- the command's limits (estimate)
M.PITCH_MIN = -10
M.PITCH_MAX = 20
-- damping (ATA22 p.346: the inertial vertical speed for damping): the
-- flight path taken LEAD_S ahead on the inertial vertical acceleration
-- (filtered over ACCEL_S), ALT's altitude ANTICIPATE_S ahead on the
-- vertical speed (estimates)
M.LEAD_S = 3.5
M.ACCEL_S = 1
M.ANTICIPATE_S = 8
-- the speed laws (step 3b, estimates): the speed error closed over
-- SPD_TAU_S, at most SPD_ACCEL kt a second; FLCH's and VNAV's normal
-- acceleration within SPD_G; the speed protection's margin (FCOM p.675:
-- the FMC's 5 kt)
M.SPD_TAU_S = 15
M.SPD_ACCEL = 1.5
M.SPD_G = 0.1
M.SPD_MARGIN = 5
-- (2026-11-08) the target's own rate fed forward (kt a second, filtered
-- over ACCEL_S): a Mach held in a climb or a descent moves its IAS target
-- (M.84 climbing at 2,800 fpm about 0.33 kt a second down). Before, the
-- closing in SPD_TAU_S lagged a moving target by its rate times 15 s: FLCH
-- climbed at M.851-.854 for M.840 (the perf session's phase 2, 238 t at
-- 2,600-3,100 fpm; FCOM p.646: the pitch holds the selected speed). A
-- change of more than SPD_STEP_KT in a frame (a new speed selected, the
-- protection's limit) is a step, no rate (estimate)
M.SPD_STEP_KT = 0.5
-- (2026-11-12) FLCH's and VNAV SPD's near-level path (the header's): this
-- much climb (fpm) gaining speed in a climb, as much descent slowing in a
-- descent; and the most of path the speed's gain takes past level flight
-- where the thrust is short of it. Estimates: FCTM p.118 has the
-- acceleration segment near level and still a climb, the sources give no
-- figure
M.SPD_LEVEL_FPM = 100
-- the speed laws' K_PATH times the IAS over SPD_K_KT, from SPD_K_MIN to all
-- of it (150 kt: 0.15, 170 kt: 0.17, 250 kt up: 0.25; estimate)
M.SPD_K_KT = 250
M.SPD_K_MIN = 0.6
-- (2026-11-13; the 2026-11-12 review AFDS-3, B3) the speed laws' rate of
-- the speed in the air's gusts, as the A/T's SPD (B747.70.at_model.lua's
-- GUST_TAU, 2026-11-10). Estimates: the sources give no filter (ATA22
-- p.344: the speed reference less the ADC's speed). With the flaps up the
-- TAS complemented over GUST_TAU s by the inertial acceleration along the
-- air path (`inp.accel_in`, kt/s: the IRU's flight path acceleration,
-- ATA34_2 p.280), back in IAS by the IAS/TAS ratio over GUST_RATIO_S; the
-- rate of that speed (over ACCEL_S, as the IAS's was) is the law's. In
-- still air it is the IAS's own rate; a gust or a shear comes in over
-- GUST_TAU. The IAS's rate within GUST_FADE_KT of the speed limits (the
-- maximum less SPD_MARGIN, the minimum maneuvering speed: FCTM p.301), with
-- the flaps out (T/O, G/A, the approach: their low speeds' margins; the
-- A/T keeps the IAS there too, FCTM p.43) and under the time acceleration
-- (`inp.time_accel`: the acceleration is per X-Plane's second, the frames'
-- time XTLua's). The law flies that speed, its error and its rate, as the
-- A/T's SPD does. Before, the IAS and its rate over a second: a knot a
-- second of it is 3 degrees of path, and in X-Plane's real weather 0.4 to
-- 1.0 kt rms of IAS kept VNAV SPD's climbs swinging 1.0 to 1.8 degrees of
-- pitch and 480 to 760 fpm (the KSEA-KLAX records; 0.1 degree in still
-- air). On tests/lib/energy_sim.lua's climb (300 t, 10,000 ft to FL330) the
-- gust's share of the pitch 0.23 to 0.28 degree with 0.5 kt rms (0.78 to
-- 0.97 before), 0.60 to 0.70 with 1.3 kt (1.22 to 1.30); a 10 kt shear over
-- 10 s 10.6 kt slow at the most and back within 2 kt in 32 s (9.3 kt and 22
-- s before; the A/T's GUST_TAU the same trade, 2026-11-10)
M.GUST_TAU, M.GUST_FADE_KT, M.GUST_RATIO_S = 20, 10, 2
-- T/O (FCOM p.664, p.666): the ground's 8 degrees, the rotation over
-- ROT_DEG, V2 + TO_ADD up to V2 + TO_MAX_ADD; above the target ABOVE_S
M.TO_PITCH = 8
M.ROT_DEG = 2
M.TO_ADD = 10
M.TO_MAX_ADD = 25
M.ABOVE_S = 5
-- G/A (FCOM p.664, p.674): up to MCP + GA_MAX_ADD; the attitude ATT_DEG or
-- ATT_PLI below the PLI ("slightly": estimate), blended into the speed from
-- BLEND_LO to BLEND_HI fpm of climb (ATA22 p.344), the attitude at K_ATT of
-- its error a second (estimate); TO/GA's command at most TOGA_RATE degrees
-- a second (estimate)
M.GA_MAX_ADD = 25
M.ATT_DEG = 15
M.ATT_PLI = 1
M.BLEND_LO = 600
M.BLEND_HI = 1200
-- (the FMC's step 9h3b) with an engine out (ATA22 p.264, p.298): G/A up to
-- MCP + GA_EO_ADD, the blend from EO_BLEND_LO to EO_BLEND_HI fpm
M.GA_EO_ADD = 10
M.EO_BLEND_LO, M.EO_BLEND_HI = 0, 600
M.K_ATT = 0.5
M.TOGA_RATE = 3
-- G/S (step 3c): the distance to the transmitter from the radio altitude
-- (in its range, GS_RA_MAX) on GS_DEG (ATA22 p.346); estimates: the
-- deviation blended over GS_BLEND_S, the beam's vertical speed corrected
-- GS_KB fpm a second a foot of the difference near the beam (with the
-- blend, a filter critically damped over some 10 s), GS_K fpm a foot of
-- distance (within GS_VS_MAX of the beam's), the capture GS_LEAD_S ahead
-- or within GS_BAND degrees. Tuned on the lagged airplane (the attitude 2
-- s behind the command, the path 3 s behind it, 140 kt down a 3 degree
-- ILS): from below 6 ft through the beam, from above 8 ft, a 3.2 degree
-- beam within 3 ft. X-Plane's glide slope deviation is GS_DOT_DEG a dot, plus
-- above the beam (measured at RJAA 34L against the transmitter's place
-- in X-Plane's nav data, flat: 3.67 dots a degree; gs_scale.json)
M.GS_DEG = 3
M.GS_RA_MAX = 2500
M.GS_BLEND_S = 5
M.GS_KB = 0.6
M.GS_K = 3
M.GS_VS_MAX = 1000
M.GS_LEAD_S = 6
M.GS_BAND = 0.1
M.GS_DOT_DEG = 0.272
M.GS_DOTS_MAX = 2.45
-- FLARE and NOSE LETDOWN (step 4b): the touchdown's sink rate (ATA22 p.294,
-- p.346); estimates (the sources give the touchdown, 450 ft past the G/S
-- transmitter, not the law): the sink rate held, then a steady deceleration
-- of FLARE_DECEL g to it, followed at K_FLARE with a FLARE_LEAD_S lead, the
-- command's rate within FLARE_G, not raised under FLARE_HOLD_FT of gear
-- altitude (the 5 ft of NOSE LETDOWN's logic, p.294: raised to the
-- touchdown, the nose was still coming up a degree a second with the
-- elevator 0.5 up, which the A/P's servo takes most of a second to take
-- off, and X-Plane's 747 skipped 2 s). On a model of X-Plane's 747 about
-- 1.5 to 2.5 ft/s 250 to 850 ft past the transmitter at 130 to 170 kt over
-- the ground; in X-Plane (s114, 150 kt) about 1 ft/s 340 to 360 ft past it
-- (notes/ATA-22.md §26). Under FLARE_HOLD_FT, the sink predicted (the
-- lead's) under TD_SINK lowers the command at K_FLOAT a second of its path
-- error (the ground effect's float, estimate: in a 20 kt crosswind's decrab
-- X-Plane's 747 stopped sinking at 1.4 ft of gear altitude with the nose
-- at 6.9 degrees, rose to 11 ft as K_FLARE took the nose down 0.6 degree a
-- second, and came down at 2.2 g: s116, 2026-10-30). FLARE never takes
-- the nose down under a landing attitude, FLARE_FLOOR degrees over the
-- attitude where it began (FCTM p.222-223: about 2 degrees on the approach,
-- 4 to 5 at the touchdown; a float or a bounce: "hold or re-establish a
-- normal landing attitude", fly it onto the runway; the 2 degrees an
-- estimate): rising to it from under it is not limited. Without it, after
-- a 3 ft float the float's rate took the nose to 0.0 degree at the
-- touchdown (s114, 2026-11-02), and after LF6's 14.6 ft float to -0.2.
-- Under FLARE_HOLD_FT the command no more than HOLD_LEAD over the attitude
-- (2026-11-02, estimate): the nose stops coming up there. In X-Plane it
-- went on rising 0.9 degree past 5 ft (the command a degree ahead on the
-- A/P's lag, 4.46 to 5.36 degrees) and the 747 met the runway still
-- pulling 1.14 g: it rose 6 ft and floated (s114, 2026-11-02 11:14).
-- NOSE LETDOWN: the command from the attitude at the touchdown down
-- LETDOWN_RATE degrees a second to LETDOWN_PITCH, the pitch-down command
-- that holds the nose gear firmly on the runway once under 2 degrees
-- (ATA22 p.294: under 5 ft of RA after the flare's command is under 2
-- degrees; p.332: on the ground under 2 degrees of pitch); the rate and
-- the pitch estimates. 2026-11-04: no more a step of a degree under the
-- attitude at the touchdown, nor a jump to LETDOWN_PITCH under 2 degrees.
-- The step (from 2026-10-30, while FLARE still raised the nose to the
-- touchdown) pushed the elevator 0.3 to 0.5 down as the main gear met the
-- runway; the nose came down 1.5 to 2.4 degrees a second, the main gear
-- lifted off for 0.2 to 0.8 s (s114, s117), and the jump under 2 degrees
-- brought the nose gear down at 3 to 4 degrees a second (s117). Since
-- FLARE_HOLD_FT and HOLD_LEAD the elevator is near 0 at the touchdown.
-- The rate 2 (1 at first: the nose gear came down 4.3 s after the main
-- gear and in a 20 kt crosswind the rollout went 0.25 dot off the LOC,
-- s116). Lowered only on the ground: off the runway again (a skip) the
-- command is held (FCTM p.222-223: hold or re-establish a normal landing
-- attitude); lowered on in the air, the gear came back at 1.7 degrees and
-- the nose gear met the runway at 4 degrees a second (s114, s117).
M.TD_SINK = 1.5
M.FLARE_DECEL = 0.045
M.FLARE_G = 0.2
M.K_FLARE = 0.5
M.FLARE_LEAD_S = 0.8
M.FLARE_HOLD_FT = 5
M.K_FLOAT = 2
M.FLARE_FLOOR = 2
M.HOLD_LEAD = 0.2
M.LETDOWN_RATE = 2
M.LETDOWN_PITCH = -1

local G = 9.80665
local FT = 0.3048
local KT = 1852 / 3600
local FPM_KT = 1852 / FT / 60    -- fpm a knot
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function a_ft() return M.G_LIMIT * G / FT end   -- the limit, ft/s/s
-- the flight path (degrees) of a vertical speed (fpm) at v (m/s)
local function path(fpm, v) return math.deg(math.asin(clamp(fpm * FT / 60 / v, -1, 1))) end

-- (B3) the speed whose rate the speed laws take (GUST_TAU): the IAS
-- complemented by the inertial acceleration, else the IAS; and whether the
-- rate is to start again (the complement just left: no step from its
-- speed to the IAS)
local function rate_speed(s, inp, dt)
    local tas = inp.tas or 0
    if inp.time_accel or not (inp.flaps_up and inp.accel_in and tas > 50 and inp.ias > 30 and dt > 0) then
        local was = s.gust_v ~= nil
        s.gust_v = nil
        return inp.ias, was
    end
    if not s.gust_v then
        s.gust_v, s.gust_r = tas, inp.ias / tas
        return inp.ias, false
    end
    -- the acceleration's step, then the TAS's share of what is left
    s.gust_v = s.gust_v + inp.accel_in * dt
    s.gust_v = s.gust_v + (tas - s.gust_v) * math.min(1, dt / M.GUST_TAU)
    s.gust_r = s.gust_r + (inp.ias / tas - s.gust_r) * math.min(1, dt / M.GUST_RATIO_S)
    local hi = (inp.v_max or 0) > 0 and inp.v_max - M.SPD_MARGIN - inp.ias or math.huge
    local lo = (inp.v_min or 0) > 0 and inp.ias - inp.v_min or math.huge
    local w = clamp(math.min(hi, lo) / M.GUST_FADE_KT, 0, 1)
    return inp.ias + w * (s.gust_v * s.gust_r - inp.ias), false
end

function M.new()
    return {cmd = nil, vs0_alt = nil, law = nil, target = nil, cap_vs = nil,
        last_ias = nil, ias_rate = 0, above = 0, mode = nil,
        v2 = nil, vrot = nil, to_target = nil, ga_target = nil, ga_cap = nil}
end

function M.inputs()
    return {
        mode = nil,         -- the AFDS model's pitch mode
        vnav_law = nil,     -- the old VNAV's law by its flags: "VS", "ALT", "FLCH"
        active = false,     -- an A/P engaged or a F/D shown
        ground = false,
        pitch = 0,          -- the pitch attitude, degrees
        vs = 0,             -- the inertial vertical speed, fpm
        tas = 0,            -- kt
        alt = 0,            -- the barometric altitude, ft
        vs_sel = 0,         -- the MCP's vertical speed, fpm
        hold_alt = nil,     -- ALT's altitude (the AFDS model's)
        vnav_vs = 0,        -- the old VNAV's vertical speed
        vnav_alt = 0,       -- and altitude
        -- the speed laws (step 3b)
        ias = 0,            -- the indicated airspeed, kt
        q = nil,            -- the dynamic pressure, Pa (ALT's gain; nil: all of K_PATH)
        weight = nil,       -- the gross weight, kg (the same)
        spd_sel = 0,        -- FLCH's and the old VNAV's speed, kt
        way = 0,            -- FLCH's and VNAV SPD's way: 1 a climb, -1 a descent
                            -- (the near-level path), 0 none
        way_fpm = nil,      -- that path's rate, fpm (nil: SPD_LEVEL_FPM)
        mcp_ias = 0,        -- the IAS/MACH window (T/O's V2, G/A's), kt
        v_min = 0,          -- the minimum maneuvering speed (0: none)
        v_max = 0,          -- the maximum speed (0: none)
        pli = nil,          -- the PLI, degrees above the pitch (nil: none)
        flaps_up = true,
        windshear = false,
        accel_in = nil,     -- (B3) the inertial acceleration along the air path, kt/s of TAS (nil: the IAS's rate)
        time_accel = false, -- (B3) X-Plane's time accelerated (the IAS's rate)
        eo = false,         -- (the FMC's step 9h3b) an engine inoperative
        -- G/S (step 3c)
        gs_dots = 0,        -- the glide slope deviation, dots, plus above the beam
        gs_valid = false,   -- both receivers' glide slope
        ra = 0,             -- the radio altitude, ft
        gs = 0,             -- the ground speed, kt
        -- FLARE and NOSE LETDOWN (step 4b)
        gear_alt = 0,       -- the gear altitude, ft
        letdown = false,    -- NOSE LETDOWN (the AFDS model's)
    }
end

-- the vertical speed (fpm) that levels off from dh ft at the limit
function M.level_off_vs(dh)
    return math.sqrt(2 * a_ft() * math.abs(dh)) * 60
end

-- the MCP altitude's capture (ATA22 p.286): closing on it no farther than
-- the level-off at G_LIMIT and CAPTURE_LAG_S of the vertical speed, or
-- within CAPTURE_NEAR
function M.capture(inp, target)
    if target == nil then return false end
    local dh = target - inp.alt
    if math.abs(dh) <= M.CAPTURE_NEAR then return true end
    local vs = inp.vs / 60
    if dh * vs <= 0 then return false end
    return math.abs(dh) <= vs * vs / (2 * a_ft()) + math.abs(vs) * M.CAPTURE_LAG_S
end

-- ALT's vertical speed (fpm) to the altitude: K_ALT of the error, at most
-- the level-off's
function M.alt_vs(target, alt)
    local dh = target - alt
    local v = math.min(M.K_ALT * math.abs(dh) * 60, M.level_off_vs(dh))
    return dh >= 0 and v or -v
end

-- the speed protected (FCOM p.675): from the minimum maneuvering speed (5
-- kt above it with the flaps out) to the maximum less 5 kt
function M.protect(v, inp)
    if inp.v_max > 0 then v = math.min(v, inp.v_max - M.SPD_MARGIN) end
    if inp.v_min > 0 then v = math.max(v, inp.v_min + (inp.flaps_up and 0 or M.SPD_MARGIN)) end
    return v
end

-- G/S's deviation (degrees above the beam) and G/S DEV ALT (ft above the
-- beam's centre): the distance to the transmitter from the radio altitude
-- on GS_DEG (ATA22 p.346)
function M.gs_dev(inp) return inp.gs_dots * M.GS_DOT_DEG end
function M.gs_dev_alt(inp)
    local h = clamp(inp.ra or M.GS_RA_MAX, 0, M.GS_RA_MAX)
    return h / math.tan(math.rad(M.GS_DEG)) * math.tan(math.rad(M.gs_dev(inp)))
end
-- the beam's vertical speed (fpm) at the ground speed on GS_DEG
function M.beam_vs(inp) return -inp.gs * FPM_KT * math.tan(math.rad(M.GS_DEG)) end

-- G/S's capture (ATA22 p.292: the distance from the beam's centre and the
-- deviation's rate): closing on the beam no farther than the change of path
-- at G_LIMIT and GS_LEAD_S of the closing take, or within GS_BAND; none at
-- the end of the scale (GS_DOTS_MAX: X-Plane's deviation stops at 2.5 dots,
-- the distance then unknown; an estimate. s102 and s112 had captured 2.5
-- dots below climbing back after an air start's sink)
function M.gs_capture(inp)
    if not inp.gs_valid or math.abs(inp.gs_dots) >= M.GS_DOTS_MAX then return false end
    if math.abs(M.gs_dev(inp)) <= M.GS_BAND then return true end
    local d = M.gs_dev_alt(inp)
    local v = (inp.vs - M.beam_vs(inp)) / 60
    if d * v >= 0 then return false end
    return math.abs(d) <= v * v / (2 * a_ft()) + math.abs(v) * M.GS_LEAD_S
end

-- T/O's and G/A's speed: once above it ABOVE_S, the speed then up to the
-- cap; the IAS/MACH window when set higher
local function ratchet(s, inp, target, cap, dt)
    if inp.mcp_ias > target then target = inp.mcp_ias end
    if inp.ias > target then s.above = s.above + dt else s.above = 0 end
    if s.above >= M.ABOVE_S then
        target = math.max(target, math.min(inp.ias, cap))
        s.above = 0
    end
    return target
end

-- the law of the mode: "VS" with its vertical speed, "ALT" with its
-- altitude, "SPD" with its speed (and whether it blends from the
-- attitude), "GS", "TOGND" (8 degrees), "ATT" with the pitch a failed
-- mode holds (`inp.att_pitch`: 6-3 step 5c), or nil (not here)
local function law_of(s, inp, dt)
    local mode = inp.mode
    if mode ~= s.mode then
        s.mode, s.above = mode, 0
        if mode ~= "TO" then s.vrot, s.v2, s.to_target, s.to_eo = nil, nil, nil, nil end
        s.ga_eo = nil
        if mode == "GA" then
            s.ga_target = math.max(inp.mcp_ias, inp.ias)
            s.ga_cap = math.max(inp.mcp_ias + M.GA_MAX_ADD, inp.ias)
        end
    end
    if inp.att_pitch then return "ATT", inp.att_pitch end
    if mode == "VS" then
        if inp.vs_sel ~= 0 then s.vs0_alt = nil; return "VS", inp.vs_sel end
        -- 000: the altitude where it was set (ATA22 p.282)
        if s.vs0_alt == nil then s.vs0_alt = inp.alt end
        return "ALT", s.vs0_alt
    end
    s.vs0_alt = nil
    if mode == "ALT" and inp.hold_alt then return "ALT", inp.hold_alt end
    if mode == "VNAV" and inp.vnav_law == "VS" then return "VS", inp.vnav_vs end
    if mode == "VNAV" and inp.vnav_law == "ALT" then return "ALT", inp.vnav_alt end
    if mode == "VNAV" and inp.vnav_law == "FLCH" then return "SPD", M.protect(inp.spd_sel, inp) end
    if mode == "FLCH" then return "SPD", M.protect(inp.spd_sel, inp) end
    if mode == "GS" then return "GS" end
    if mode == "FLARE" then return "FLARE" end
    if mode == nil and inp.letdown then return "LETDOWN" end
    if mode == "TO" then
        if inp.ground then
            -- the rotation's speed; V2 the IAS/MACH window's
            if s.vrot == nil and inp.pitch > M.ROT_DEG then s.vrot = inp.ias end
            s.v2 = inp.mcp_ias
            return "TOGND", M.TO_PITCH
        end
        if s.to_target == nil then
            local v2 = s.v2 or inp.mcp_ias
            s.v2 = v2
            s.to_target = math.max(v2 + M.TO_ADD, (s.vrot or 0) + M.TO_ADD)
        end
        -- (step 9h3b) an engine failure: the speed then (in the air) within
        -- V2 and V2 + 10, the MCP's when set higher (ATA22 p.264)
        if inp.eo and not s.to_eo then s.to_eo = clamp(inp.ias, s.v2, s.v2 + M.TO_ADD) end
        if s.to_eo then
            s.to_target = math.max(s.to_eo, inp.mcp_ias)
        else
            s.to_target = ratchet(s, inp, s.to_target, s.v2 + M.TO_MAX_ADD, dt)
        end
        -- (2026-11-12 review AFDS-4, B1) the blend from the attitude to the
        -- speed with an engine out too, from 0 to 600 fpm (ATA22 p.264: the
        -- engine-out takeoff is the same with the blend from 0 to 600 fpm;
        -- p.344; FCOM p.674), as this file's head says; before, in a
        -- windshear only: with little excess thrust the speed law paid
        -- height for the speed (482 fpm of excess: -354 fpm, 65 ft lost)
        return "SPD", M.protect(s.to_target, inp), inp.windshear or s.to_eo ~= nil
    end
    if mode == "GA" then
        -- (step 9h3b) an engine out: up to MCP + 10 (ATA22 p.298)
        if inp.eo and not s.ga_eo then
            s.ga_eo = true
            s.ga_cap = math.max(inp.mcp_ias + M.GA_EO_ADD, s.ga_target or inp.mcp_ias)
        end
        s.ga_target = ratchet(s, inp, s.ga_target or inp.mcp_ias, s.ga_cap or inp.mcp_ias + M.GA_MAX_ADD, dt)
        return "SPD", M.protect(s.ga_target, inp), true
    end
    return nil
end

-- the command (degrees of pitch), or nil without a law here
-- (2026-11-12 review AFDS-5) an A/P's engagement: the pitch attitude
-- integrator synchronizes to the pitch attitude while the A/P is
-- disengaged and takes the command inputs once it is engaged (ATA22 p.332),
-- so the law's command starts again from the attitude (the next update
-- takes it: the laws' start). Before, the command an F/D-only flight had
-- wound up with nobody following the bars stayed (30 s of V/S +1,000: 6
-- degrees above the attitude; the engagement pitched up at 1.8 g)
function M.sync(s)
    s.cmd = nil
end

function M.update(s, inp, dt)
    dt = dt or 0
    local law, target, blend
    if inp.active and (not inp.ground or inp.mode == "TO" or inp.mode == "GA" or inp.letdown) then
        law, target, blend = law_of(s, inp, dt)
    end
    if law ~= "GS" then s.gs_d = nil end
    if law ~= "FLARE" then s.flare_s, s.flare_pitch = nil, nil end
    if law == nil then
        s.cmd, s.law, s.target, s.cap_vs, s.last_vs, s.vs_rate = nil, nil, nil, nil, nil, 0
        s.last_ias, s.ias_rate, s.mode = nil, 0, inp.active and inp.mode or nil
        s.gust_v, s.rias = nil, nil
        if not (inp.active and inp.mode == "VS") then s.vs0_alt = nil end
        return nil
    end
    -- the inertial vertical acceleration (fpm a second) and the speed's
    -- (kt a second), filtered
    local k = math.min(1, dt / M.ACCEL_S)
    if s.last_vs and dt > 0 then s.vs_rate = (s.vs_rate or 0) + ((inp.vs - s.last_vs) / dt - (s.vs_rate or 0)) * k end
    -- (B3) the speed's on the speed complemented in the gusts (GUST_TAU),
    -- that speed the speed laws' (s.rias)
    local rias, restart = rate_speed(s, inp, dt)
    if restart then s.last_ias = nil end
    if s.last_ias and dt > 0 then s.ias_rate = s.ias_rate + ((rias - s.last_ias) / dt - s.ias_rate) * k end
    s.last_vs, s.last_ias, s.rias = inp.vs, rias, rias
    if law == "LETDOWN" then
        -- the nose lowered to the runway from the attitude at the
        -- touchdown (FCOM p.671), on to the pitch-down command that holds
        -- it there (ATA22 p.294, p.332); held while the airplane is off
        -- the runway again (FCTM p.222-223)
        if s.law ~= "LETDOWN" then s.cmd = math.min(s.cmd or inp.pitch, inp.pitch) end
        if inp.ground then s.cmd = math.max(s.cmd - M.LETDOWN_RATE * dt, M.LETDOWN_PITCH) end
        s.law, s.target = law, nil
        return s.cmd
    end
    if law == "TOGND" or law == "ATT" then
        -- T/O on the ground: the F/D's 8 degrees (FCOM p.666); a failed
        -- mode: the attitude of then held (step 5c; FCOM p.660)
        s.cmd, s.law, s.target = target, law, target
        return s.cmd
    end
    if s.cmd == nil or s.law == "TOGND" then s.cmd = inp.pitch end
    local v = math.max(inp.tas, 100) * KT
    local lim = math.deg(M.G_LIMIT * G / v)
    local rate
    if law == "SPD" then
        -- (2026-11-08) the target's own rate: its change since the frame
        -- before, filtered as the speed's; none for a step (SPD_STEP_KT)
        -- or at the law's start
        local tr = 0
        if s.law == "SPD" and s.target and dt > 0 and math.abs(target - s.target) <= M.SPD_STEP_KT then
            s.tgt_rate = (s.tgt_rate or 0) + ((target - s.target) / dt - (s.tgt_rate or 0)) * k
            tr = s.tgt_rate
        else
            s.tgt_rate = 0
        end
        -- the acceleration that closes the error in SPD_TAU_S on the
        -- target's rate, the flight path of the difference
        -- (B3) on the speed complemented in the gusts (GUST_TAU)
        local want = clamp((target - (s.rias or inp.ias)) / M.SPD_TAU_S + tr, -M.SPD_ACCEL, M.SPD_ACCEL)
        local lead = path(inp.vs + (s.vs_rate or 0) * M.LEAD_S, v) - path(inp.vs, v)
        local k = M.K_PATH * clamp(inp.ias / M.SPD_K_KT, M.SPD_K_MIN, 1)
        -- the flight path's change that makes that acceleration
        local dpath = math.deg((s.ias_rate - want) * KT / G)
        local toga = inp.mode == "TO" or inp.mode == "GA"
        -- (2026-11-12) FLCH and VNAV SPD against their way: the path no
        -- further than near level (`level`: the change to it from the path
        -- flown, `gam`). Where that would leave the speed less than near
        -- level's own angle (`step`) of path for its gain, on to level
        -- flight at the most; past level flight only where the thrust is
        -- short of it: then to the path that keeps the speed (`hold`: in step
        -- with its target, and back within the speed protection's limit,
        -- FCOM p.675) and as far again as that is past level, at most `step`
        local way = toga and 0 or (inp.way or 0)
        if way ~= 0 then
            local fpm = inp.way_fpm or M.SPD_LEVEL_FPM
            local gam = path(inp.vs, v)
            local level = path(way * fpm, v) - gam
            local step = path(M.SPD_LEVEL_FPM, v)
            if way > 0 then
                local keep = tr + math.max(0, M.protect(0, inp) - inp.ias) / M.SPD_TAU_S
                local hold = gam + math.deg((s.ias_rate - keep) * KT / G)
                dpath = math.max(dpath, math.min(level, math.max(hold - step, math.min(0, 2 * hold)) - gam))
            else
                local keep = tr + math.min(0, M.protect(math.huge, inp) - inp.ias) / M.SPD_TAU_S
                local hold = gam + math.deg((s.ias_rate - keep) * KT / G)
                dpath = math.min(dpath, math.max(level, math.min(hold + step, math.max(0, 2 * hold)) - gam))
            end
        end
        rate = k * (dpath - lead)
        if blend then
            -- from the attitude to the speed between 600 and 1,200 fpm
            local att = M.ATT_DEG
            if inp.pli then att = math.min(att, inp.pitch + inp.pli - M.ATT_PLI) end
            -- (step 9h3b) with an engine out from 0 to 600 fpm (ATA22 p.264, p.298)
            local lo, hi = M.BLEND_LO, M.BLEND_HI
            if inp.eo then lo, hi = M.EO_BLEND_LO, M.EO_BLEND_HI end
            local w = clamp((inp.vs - lo) / (hi - lo), 0, 1)
            rate = (1 - w) * M.K_ATT * (att - s.cmd) + w * rate
        end
        lim = toga and M.TOGA_RATE or math.deg(M.SPD_G * G / v)
        s.cap_vs = nil
    else
        local want, ff = target, 0
        if law == "ALT" then
            -- a new altitude: closing on it, no more than the vertical speed
            -- now until the level-off asks for less; the altitude
            -- ANTICIPATE_S ahead
            if s.law ~= "ALT" or s.target ~= target then
                local closing = (target - inp.alt) * inp.vs > 0
                s.cap_vs = closing and math.abs(inp.vs) or nil
            end
            want = M.alt_vs(target, inp.alt + inp.vs / 60 * M.ANTICIPATE_S)
            if s.cap_vs then
                if math.abs(want) < s.cap_vs then s.cap_vs = nil else want = want > 0 and s.cap_vs or -s.cap_vs end
            end
        elseif law == "FLARE" then
            -- the sink rate where FLARE began, held until a steady
            -- deceleration of FLARE_DECEL to TD_SINK at the touchdown asks
            -- for less; the deceleration's change of path fed forward
            local sink = -inp.vs / 60
            if s.flare_s == nil then s.flare_s, s.flare_pitch = math.max(sink, M.TD_SINK), inp.pitch end
            local a = M.FLARE_DECEL * G / FT
            local prof = math.sqrt(M.TD_SINK * M.TD_SINK + 2 * a * math.max(inp.gear_alt or 0, 0))
            if prof < s.flare_s then
                want = -prof * 60
                ff = math.deg(a * FT / v) * clamp(sink / prof, 0, 2)
            else
                want = -s.flare_s * 60
            end
        elseif law == "GS" then
            -- the distance from the beam's centre and the beam's vertical
            -- speed: on the inertial vertical speed against the beam's, to
            -- G/S DEV ALT over GS_BLEND_S while there is a signal, the
            -- difference also correcting the beam's (an angle not 3
            -- degrees, the wind); without a signal the path is held
            if s.gs_d == nil then s.gs_d, s.gs_b = inp.gs_valid and M.gs_dev_alt(inp) or 0, 0 end
            local beam = M.beam_vs(inp) + s.gs_b
            s.gs_d = s.gs_d + (inp.vs - beam) / 60 * dt
            if inp.gs_valid then
                local r = M.gs_dev_alt(inp) - s.gs_d
                s.gs_d = s.gs_d + r * math.min(1, dt / M.GS_BLEND_S)
                -- near the beam only, where the distance from the radio
                -- altitude makes G/S DEV ALT true to scale
                if math.abs(M.gs_dev(inp)) <= M.GS_BAND then s.gs_b = s.gs_b - M.GS_KB * r * dt end
            end
            want = beam - clamp(M.GS_K * s.gs_d, -M.GS_VS_MAX, M.GS_VS_MAX)
        end
        local flown = inp.vs + (s.vs_rate or 0) * (law == "FLARE" and M.FLARE_LEAD_S or M.LEAD_S)
        local kp = law == "FLARE" and M.K_FLARE or M.K_PATH * (law == "ALT" and M.path_gain(inp) or 1)
        rate = kp * (path(want, v) - path(flown, v)) + ff
        if law == "FLARE" and (inp.gear_alt or 0) < M.FLARE_HOLD_FT then
            rate = math.min(rate, 0)
            if -flown / 60 < M.TD_SINK then
                rate = math.min(rate, M.K_FLOAT * (path(-M.TD_SINK * 60, v) - path(flown, v)))
            end
        end
    end
    s.law, s.target = law, target
    if law == "FLARE" then lim = math.deg(M.FLARE_G * G / v) end
    local cmd = s.cmd + clamp(rate, -lim, lim) * dt
    -- FLARE: not down under the landing attitude (FLARE_FLOOR)
    if law == "FLARE" and cmd < s.cmd then
        cmd = math.max(cmd, math.min(s.cmd, s.flare_pitch + M.FLARE_FLOOR))
    end
    -- FLARE under FLARE_HOLD_FT: no more than HOLD_LEAD over the attitude
    if law == "FLARE" and (inp.gear_alt or 0) < M.FLARE_HOLD_FT and M.HOLD_LEAD then
        cmd = math.min(cmd, math.max(inp.pitch + M.HOLD_LEAD, s.flare_pitch + M.FLARE_FLOOR))
    end
    s.cmd = clamp(cmd, M.PITCH_MIN, M.PITCH_MAX)
    -- T/O and G/A not over the PLI (FCOM p.664)
    if (inp.mode == "TO" or inp.mode == "GA") and inp.pli then
        s.cmd = math.min(s.cmd, inp.pitch + inp.pli)
    end
    return s.cmd
end

return M
