-- 747-400 EEC without X-Plane: for each engine the maximum rated thrust for
-- the conditions (Max N1 for the CF6-80C2, Max EPR for the PW4056), the
-- command the thrust lever asks for between idle and that maximum, so that
-- full forward gives the maximum rated thrust in any phase (FCOM p.876),
-- the alternate mode, the overspeed protection and the idle selection.
-- Logic and sources:
-- docs/overhaul/notes/ATA-70-80.md §4.1, §4.2 and §4.4 (FCOM 7.20
-- p.873-878; ATA70_80 p.146-151 and p.202-211 for the CF6; FCOM PI for the
-- ratings).
-- B747.42.xt.eec_thrust.lua feeds it and gives the target to the engines'
-- thrust control.
--
--   local E = B747_eec_model
--   local s = E.new()
--   local inp = E.inputs()                 -- fill it every frame
--   local out = E.update(s, inp, dt)       -- a new table

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
local M = setmetatable({}, {})
B747_eec_model = M

-- the full-forward rating (CF6, ATA70_80 p.208): takeoff below 17,000 ft and
-- 300 kt, maximum continuous from 18,000 to 22,000 ft or above 293 kt,
-- maximum climb above 25,000 ft with the levers past 35° (the normal climb
-- position). Between them the logic blends (bands from those figures,
-- estimate). P&W: no source, as the CF6 but for the maximum climb: its
-- full-forward rating stays the maximum continuous above 22,000 ft
-- (estimate, 2026-11-02: the P&W's EPR turns red at the maximum EPR, FCOM
-- p.834, and with the CF6's maximum climb above 25,000 ft every climb at
-- CLB thrust showed red; maximum thrust is the full forward lever's in any
-- phase, p.876; the PW4056's maximum continuous EPR is over its maximum
-- climb's to 35,000 ft, PI.13.1, PI.10.36). The maximum continuous rating
-- is its table's (the FMC's step 9h1; before, the maximum climb's), not
-- under the maximum climb's (estimate: the table is for one engine
-- inoperative, more bleed on each engine).
M.TO_ALT, M.MCT_ALT = 17000, 18000
M.TO_KIAS, M.MCT_KIAS = 300, 293
M.MCT_ALT_TOP, M.CLB_ALT = 22000, 25000
-- (2026-11-13; the 2026-11-12 review AT-1, AT-2, B2) The P&W (and the RR,
-- on its data): the full-forward rating (the maximum EPR) the go-around's at
-- every speed and altitude, not the CF6's steps to the maximum continuous
-- and climb ratings (FCOM p.876: maximum EPR the maximum rated thrust,
-- thrust limited to it at the full forward lever in any phase; the
-- Lufthansa PW4000 training, 71-80 p.260: a function of the ambient and
-- total pressures and TAT). Above its table (10,000 ft) the table's held, or
-- the maximum continuous plus PW_MAX_OVER_MCT when higher: an estimate (no
-- source gives the rating up there; the go-around over the maximum
-- continuous by 0.14 to 0.19 at 0 to 10,000 ft, FCOM PI.10.37 and PI.13.1;
-- the NTSB's FDR of a PW4056 747-400, Delta 276 at FL320, two steady
-- lever-EPR points on a line to about 1.75 at 48 degrees). Before: the CF6's
-- steps (the maximum continuous from 293-300 kt and 17,000-18,000 ft): the
-- climb's reference was the maximum EPR in most climbs (the digits red,
-- FCOM p.873), and passing 300 kt the lever's command fell 0.04 EPR (thrust
-- -6 %, the levers ran forward some 15 degrees: s285)
M.PW_MAX_OVER_MCT = 0.16
-- (2026-11-20, GAP_ANALYSIS.md N19-ENG-01) The P&W's full-forward rating
-- (about 82 degrees TRA) is the takeoff rating below about 14,100 ft and
-- the maximum continuous above (PW_PPM p.196): above PW_TO_ALT the maximum
-- continuous table's (with its adjustments), not under the maximum climb's
-- plus PW_MCT_OVER_CLB (estimate: the FCOM's maximum continuous tables are
-- the engine inoperative's, more bleed on each engine, and dip under the
-- climb's when hot, at 41,000 ft or at 300 kt; the EICAS turns the EPR red
-- 0.003 under the maximum and white again 0.01 under it, so the climb at
-- its reference stays white, with a little over: 0.012). Below it as
-- before (the go-around's, above its table the higher of the table's
-- held and the climb's or the maximum
-- continuous plus PW_MAX_OVER_MCT). Before, that at every altitude: the
-- full forward lever gave up to 0.16 EPR over the maximum continuous in
-- the climb and the cruise. RR as P&W (no source: estimate)
M.PW_TO_ALT, M.PW_MCT_OVER_CLB = 14100, 0.012
-- thrust lever angles, degrees from forward idle (ATA70_80 p.146-151): the
-- takeoff rating is reached at 48°, the forward stop is 50°; the climb
-- rating at 35° (ATA70_80 p.208). (2026-11-13, B2) The lever's line: the
-- CF6's from forward idle to the maximum climb N1 at the CLIMB position
-- (TLA_CLB) whatever the rating, from there to the full-forward rating at
-- TLA_TO (ATA70_80 p.209, the 73-21 figure); the P&W's one line from idle to
-- its maximum EPR at TLA_TO (estimate: no figure; the FDR's points above lie
-- on such a line, and P&W's operating instructions are quoted for a linear
-- EPR against the lever's angle). Before, one line to the full-forward
-- rating for both, so a change of the rating moved the whole line (AT-2)
M.TLA_STOP, M.TLA_TO, M.TLA_CLB = 50, 48, 35
-- (2026-11-11) the flat idle: a forward TLA from 0 to 2° commands idle
-- (ATA70_80 p.151, the TLA critical points: FLAT IDLE UPPER LIMIT 2°; the
-- CF6's, the P&W's the same: an estimate), the rating reached at the same
-- angles as before. Before, the command rose from idle at 0°, so the A/T's
-- idle (the lever at 0.12°) stood over idle (EPR 0.0013 at sea level, about
-- 0.003 at FL250) and the thrust
-- control worked the throttle down with its loop (target <= idle: idle at
-- once, not taken): with the gains fitted to X-Plane's engines on
-- 2026-11-10 that took 25 s at FL250, and s202's level deceleration at the
-- T/D started its descent at 316 kt (before the fit the throttle was at
-- idle in 2 s: 308 kt)
M.TLA_FLAT_IDLE = 2
-- (2026-11-20, GAP_ANALYSIS.md N19-ENG-04) the P&W's maximum climb rating
-- is reached at about 72 degrees TRA, forward idle being about 36 and the
-- full-forward rating about 82 (PW_PPM p.196): on this lever, whose rating
-- is reached at TLA_TO from the flat idle, 2 + 46 x (72 - 36) / (82 - 36)
-- = 38 degrees (estimate: the TRAs straight along the lever). The P&W's
-- line runs to the maximum climb EPR there, then to the full-forward
-- rating at TLA_TO (as the CF6's at its CLIMB position). Before (B2,
-- 2026-11-13) one line from idle to the full-forward rating: with the
-- maximum continuous over 14,100 ft (N19-ENG-01) the A/T's climb sat the
-- levers near the forward stop (0.95, s317)
M.PW_TLA_CLB = M.TLA_FLAT_IDLE + (M.TLA_TO - M.TLA_FLAT_IDLE) * (72 - 36) / (82 - 36)

-- idle (FCOM p.877-878): approach idle in the air while the engine's
-- nacelle anti-ice is on, the flaps are in a landing position or (570 and
-- 405, not 109) the CON IGNITION switch is ON; the CF6 (570) also while its
-- reverser works. It stays until 5 s after touchdown; 5 s also after the
-- conditions end in the air (the CF6's idle select circuit, ATA70_80 p.211,
-- estimate). Minimum idle otherwise.
M.APPROACH_HOLD_S = 5
M.LANDING_FLAPS_DEG = 23            -- trailing edge flaps past 23° (ATA70_80 p.211)

-- X-Plane's idle (sim/aircraft2/engine/high_idle_ratio) for the idle
-- selected: one ratio for all engines (X-Plane takes the larger of it and
-- low_idle_ratio and keeps idle_speed_ratio at high idle), so approach idle
-- on any engine raises all four. The ratio sets X-Plane's idle N2 (69.7 %
-- at 1.07, 84.4 % at 5, at any height and speed), and with it the idle
-- thrust. Measured with the custom acf (tests/flight/measure/
-- aero_idle_ground.json, aero_idle_sweep.json, aero_idle_taxi.json,
-- 2026-10-30; notes/AERO.md 3.7):
-- - minimum idle in the air, by pressure altitude: the net thrust that,
--   with the acf's drag, gives the FCOM's idle descents (PI.10.39, p.265:
--   290 KIAS, .84 above 30,000 ft), about +3 kN an engine at sea level,
--   +2 at 10,000 ft and 0 at 20,000-30,000 ft. The FCOM fixes drag less
--   idle thrust only, so the split is an estimate; above 30,000 ft the
--   ratio is carried on (estimate);
-- - minimum idle on the ground: the previous code's 15 °C value, 4 % of the
--   rated thrust standing at sea level (10.3 kN; the ICAO reference idle is
--   7 %, ICAO_EEDB 1PW041). With the acf's rolling friction lowered to fit
--   (_roll_co 0.015) it keeps a taxi going at 270 t and does not start one
--   from a stop (FCTM p.76) (estimate);
-- - approach idle: 0.5 above the minimum idle in the air, also on the
--   ground (a flight setting, held until 5 s after touchdown; near the
--   ground about the previous code's 2.625). No figures for the PW4056;
--   the CF6's is up to 73 % N2 against its 61.6 % minimum (ATA70_80
--   p.206-208) (estimate).
-- X-Plane's engine is the same for every engine type, so the CF6 has the
-- same ratios (the previous code gave it higher ones, estimates; its idle
-- N2 on the EICAS is the display model's, ENG-33).
M.IDLE = {
    alt = {0, 10000, 20000, 30000, 35000},
    air = {2.3, 2.5, 2.9, 4.1, 4.7},
    ground = 1.07,
    approach_step = 0.5,
}

-- alternate mode (FCOM p.876-877; ATA70_80 p.202-207), selected with the
-- EEC MODE switch (the sim has no EEC faults, so no automatic reversion).
-- It does not limit thrust at the maximum: the command is a fixed schedule
-- of lever angle and pressure altitude, as the CF6's hard reversionary mode
-- that uses its corner point temperature and corrects for pressure only
-- (ATA70_80 p.205, p.207): the rating at the TAT that gives the most thrust
-- at that altitude, without the bleed adjustments. The same lever then
-- gives at least normal-mode thrust, the maximum comes before full forward
-- and full forward can overboost (FCOM p.877). P&W: below (PW_ALTN); the RR
-- (no sources) as the CF6, controlling EPR (estimate).
-- >ENG n LIM PROT (FCOM p.900): GE when the command passes the maximum
-- rating, P&W when the thrust comes near it (within LIM_PROT_EPR,
-- estimate; since N19-ENG-05 the EPR measured, the command being N1).
M.LIM_PROT_EPR = 0.01
-- (2026-11-20, GAP_ANALYSIS.md N19-ENG-05; notes/ATA-70-80.md §25) The
-- PW4000's alternate mode is its N1 mode (PW_PPM p.196, p.204): the EEC
-- schedules N1 from the thrust lever angle alone, biased by Tt2 (a
-- corrected N1, n1c, times the square root of Tt2 / 288.15 K; Tt2 the TAT),
-- not limited at the maximum EPR: the redline's (N1, N2 or Pb) at the
-- forward stop (p.197), the overspeed protection holding it (p.204). The
-- schedule (estimates): from the flat idle's idle end rising steeply, then
-- flatter (the shape of the N1 line, p.197, p.205), at least the normal
-- mode's corrected N1 at the same lever (FCOM p.877; by 0.45 or more at
-- every lever from 12 degrees, where the normal mode's is 70 % or more,
-- over 0-43,000 ft, ISA-25 to +35, the speeds flown, packs and anti-ice:
-- tests/eec/eec_altn_test.lua), the highest full-forward rating's (105.05:
-- FL370, ISA-25, packs off) by 44 degrees (TRA about 78, p.197: the
-- maximum power available before the forward stop; FCOM p.877, PI.18.11),
-- 118 at 49 (TRA about 83, the redline's flat: 1.15 of the idle-to-maximum
-- span, as p.197). The lever's TRA as N19-ENG-04's (TLA = TRA - 34). At a
-- sea level takeoff the rating (n1c 100.7) comes at about 32 degrees.
-- The automatic reversion's lockup keeps the thrust (p.198): the N1 the
-- schedule gives less the difference (delta) between it and the N1 at the
-- reversion, held, so the thrust follows the lever from there (p.197:
-- "delta N1 maintained"); manual selection removes the lockup, delta ramped
-- out at about 100 rpm a second (p.198: 100 % N1 is 3,600 rpm, p.204), also
-- from the EPR mode (FCOM p.877: the thrust increases). Back to the EPR mode
-- with the switch at NORM once the fault is gone (p.198): an automatic
-- reversion stays (latched) until the switch is used. Estimates: delta in
-- % N1, none below 0 (the schedule is over the EPR mode's, p.197) and none
-- taken under run_n2 % N2 (an engine not running); the idle end n1c.
M.PW_ALTN = {
    tla = {2, 6, 10, 12, 15, 20, 25, 30, 38, 44, 49},
    n1c = {20, 52, 66, 72, 81.5, 90.8, 95, 99, 104.5, 105.6, 118},
    ramp = 100 / 36,        -- % N1 a second (100 rpm/s)
    run_n2 = 50,            -- % N2
}

-- overspeed protection (FCOM p.878; ATA70_80 p.205): above idle the EEC
-- keeps N1 and N2 from passing their operating limits (the red lines)
-- whatever the lever asks. A rotor's limit loop works once the rotor is
-- within RPM_BAND of its red line less RPM_MARGIN: it allows the controlled
-- value (N1 for GE, EPR for P&W) the present one plus RPM_GAIN for each
-- percent the rotor is short of that (less when past it). The thrust
-- control aims at the lowest of the command and the limits (target), so the
-- rotor settles RPM_MARGIN below its red line. The GE controls N1 itself:
-- its N1 limit caps the command. >ENG n RPM LIM while a limit holds the
-- engine (allows it no more than RPM_LIM_SHOW above its present value) more
-- than RPM_LIM_SHOW below the command (FCOM p.901: GE on N2, P&W on N1 or
-- N2). Red lines: CF6 ATA70_80 p.205; P&W its EEC's (PW_PPM p.204: below).
-- Margin, band, gains and threshold: estimates.
-- (2026-11-20, N19-ENG-02) the P&W EEC's own limits, N1 111.4 % (4,010
-- rpm) and N2 104 % (10,300 rpm), under the N2 red line 105.5 (PW_PPM
-- p.204); before, N2 at the display's 111.4
M.REDLINE = {GE = {n1 = 117.5, n2 = 112.5}, PW = {n1 = 111.4, n2 = 104}}
-- (2026-11-25, the RB211's rebuild) the RB211 on the P&W's scale (inp.rr):
-- its N1 at the TCDS's maximum take-off LP speed, 110.5 % (TCDS_RB211 p.18,
-- 5 min) of 3,900 rpm (p.10), the shown N1's scale since the same day
-- (B747.42.xt.EEC.RR.lua's N1_TCDS: GAP_ANALYSIS.md N19-ENG-23); no N2 (its
-- N2 the IP spool's, only shown). Estimate: no source has the RB211's EEC;
-- before, its own PID cut the thrust over a shown N1 of 110.1 %, then
-- (the rebuild's first version) 111.5 % on the upstream's 3,600 rpm scale,
-- which a takeoff at FAOR on a 30 C day nearly reached (111.0 %, s432)
M.REDLINE.RR = {n1 = 110.5, n2 = 1000}
M.RPM_MARGIN = 0.5                          -- %
M.RPM_BAND = 2                              -- %
-- (N19-ENG-05) PWN1: the P&W in its N1 mode, controlling N1 as the GE (its
-- N1 limit caps the target, shown as RPM LIM; the GE's gains: estimates)
M.RPM_GAIN = {GE = 0.6, PW = 0.01, PWN1 = 0.6}          -- N1 % or EPR for each % of the rotor
M.RPM_LIM_SHOW = {GE = 0.2, PW = 0.005, PWN1 = 0.2}     -- N1 % or EPR

-- the thrust control (FCOM p.875-876): the EEC adjusts fuel flow until the
-- controlled value (N1 for GE, EPR for P&W) equals the target. In the sim
-- the fuel metering is X-Plane's throttle (0 to 1) and X-Plane's engine
-- gives the spool-up and spool-down. The value the control follows (ref)
-- closes on the target with a time constant of lag seconds and at no more
-- than up or down each second (the EEC's acceleration and deceleration
-- schedules; slower down, as X-Plane's engine is slow to turn from spooling
-- down to spooling up). The throttle moves by ki times the error each
-- second and kp times the error's change, both divided by the controlled
-- value's slope against the throttle at its present value (the displayed
-- EPR steepens fourfold towards full thrust), so that the loop answers
-- alike at any thrust. With the lever at its idle end the throttle is 0
-- (the EEC's idle). Gains, rates and slopes: estimates, the slopes measured
-- in X-Plane (8,000-13,500 ft, M.42-.49; near idle the displays hardly move).
-- The P&W slopes follow the displayed EPR: with the EPR model of 2026-10-30
-- (B747.42.epr_model.lua) they are the measured ones carried through the
-- two EPR formulas at 10,000 ft, M.45 (the same thrusts); above 1.42 (full
-- throttle there) carried on (estimate).
M.THRUST = {
    PW = {lag = 1.5, up = 0.15, down = 0.15,                            -- EPR each second
        at = {0.97, 1.02, 1.09, 1.20, 1.26, 1.32, 1.37, 1.42, 1.71},
        slope = {0.3, 0.62, 0.82, 0.93, 1.03, 1.16, 1.17, 1.47, 1.8}}, -- EPR for each unit of throttle
    GE = {lag = 1.5, up = 15, down = 5,                                 -- N1 % each second
        at = {35, 45, 60, 75, 90, 100},
        slope = {20, 100, 112, 100, 80, 77}},                          -- N1 % for each unit of throttle
    -- (N19-ENG-05) the P&W in its N1 mode (PW_ALTN), on the shown N1: the
    -- GE's rates and slopes (estimate: no P&W figures; the glue gives the
    -- slope from the EPR model's N1)
    PWN1 = {lag = 1.5, up = 15, down = 5,
        at = {35, 45, 60, 75, 90, 100},
        slope = {20, 100, 112, 100, 80, 77}},
}
-- (2026-11-10) the loop for the plant measured in X-Plane (PROGRESS.md
-- "next" 20; the open-loop test: tests/flight/measure/eec_steps_*.json,
-- tests/flight/tools/eec_steps.lua). The throttle drives X-Plane's thrust
-- through two lags and a short dead time, slower with height (11,000 ft 2.9
-- and 1.3 s, FL250 3.2 and 1.8 s, FL390 5.8 and 2.1 s: about 1 / sqrt of the
-- pressure ratio delta), and the shown EPR (and the GE's N1 in the air)
-- come from the thrust over delta, so their slope against the throttle
-- grows as delta falls (P&W: 0.81 EPR a unit of throttle at 11,000 ft, 1.65
-- at FL250, 3.67 at FL390, where the tables above gave 0.36, 0.49, 0.91).
-- With the tables and ki 2, kp 3 the phase margin was 12 degrees at 11,000
-- ft, 3 at FL250 and -11 at FL390: in gusts at FL390 the throttle swung
-- 0.76 to 0.94 with a 5.6 s period (s277). Now the glue gives each engine's
-- slope (its display formula's slope against the thrust times X-Plane's
-- thrust for each unit of throttle: B747.42.xt.eec_thrust.lua) and delta;
-- the gains KP and KI are for the slope, KI times (delta /
-- KI_DELTA_REF)^KI_POWER: above KI_DELTA_REF's height the square root, with
-- the plant's lags (the phase margin 55 to 60 degrees at the measured
-- heights, a 0.05 EPR step within 0.003 in 5 to 8 s); below it more, so
-- that the takeoff brings the EPR to the takeoff rating about as fast as
-- the previous law (within 0.005 in about 10 s; the first version with
-- the square root down to sea level took 14.5 s in s11 2026-11-10): KI
-- 1.06 at sea level, the phase margin 46 degrees or more. Without a slope
-- (the GE's N1 from X-Plane's on the takeoff) the tables' (estimates: the
-- gains, the scaling)
M.KP, M.KI = 2.0, 0.5
M.KI_DELTA_REF = 0.66               -- about 11,000 ft
M.KI_POWER = {0.5, 1.8}             -- below KI_DELTA_REF (higher up), above it (lower down)
-- (2026-11-10) the takeoff roll: X-Plane's thrust at a steady throttle falls
-- as the speed grows, so holding the EPR needs the throttle to rise (s11, 270
-- t: 0.0024 a second at about 6.3 kt a second), and the PI lags that ramp by
-- its rate x slope / KI: the full-forward EPR settled 0.0028 under the
-- maximum (the previous law 0.0016), where the EICAS shows it red from 0.003
-- under (B747.40.engine_display_model.lua, an estimate; FCOM p.873: red when
-- the maximum is reached), so a lighter, quicker takeoff could stay white.
-- On the roll (the glue's `roll`: on the ground above 30 kt, so not with the
-- brakes held) the control learns that rate while its reference has
-- settled and its error is small, and adds it (a second integral, RAMP_W x
-- KI); otherwise the learned rate fades out in RAMP_FADE seconds (in the air
-- the ramps are about a hundred times slower: 0.9 to 1.0 over a climb). A
-- higher KI alone would not do (1.47 at sea level: 0.0020 under, the phase
-- margin 50 to 40 degrees). Offline (tests/eec/eec_model_test.lua's
-- takeoff with the lapse): at 270 t 0.0010 under at 80 kt, at most 0.0003
-- over after; at 215 t (s281: 7.9 kt a second, 0.0032 a second) 0.0010
-- under at 110 kt. The first gain, 0.05, left 0.0027 at 110 kt in X-Plane's
-- 215 t roll (s281 2026-11-10: it learns from about 9 s after TO/GA, the
-- spool's tail first). Estimates: the gate, the gain, the bands
M.RAMP_W = 0.08
M.RAMP_SETTLED = {PW = 0.002, GE = 0.2, PWN1 = 0.2}    -- |target - reference| (EPR, N1 %) to learn
M.RAMP_BAND = {PW = 0.02, GE = 2, PWN1 = 2}             -- |error| (EPR, N1 %) to learn
M.RAMP_MAX = 0.01                           -- throttle a second
M.RAMP_FADE = 5                             -- s

-- FCOM PI tables, 3 packs on, anti-ice off. Rows by TAT (°C, warm to cold),
-- columns by pressure altitude (ft); false where the table is blank (too
-- warm for that altitude). The go-around rating stands for the takeoff
-- rating: the FCOM has no normal-mode takeoff table, and its alternate-mode
-- takeoff and go-around tables give the same thrust (PI.15.6, estimate).
-- (2026-11-24, ENG-2) The P&W's takeoff rating in the takeoff the FPPM's
-- Takeoff EPR tables (TABLE.PW.to, below); the CF6's the go-around's still.
-- The maximum continuous tables (mct, below) depend on speed as well.
local F = false
M.TABLE = {
    PW = {
        -- Go-around EPR, PW4056 (PI.10.37, FCOM p.263), airport pressure altitude
        ga = {
            alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
            tat = {54, 50, 45, 40, 35, 30, 25, 20, 15, 10},
            v = {
                {1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, F},
                {1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, F},
                {1.46, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.44, 1.44, 1.44, 1.44},
                {1.46, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48},
                {1.46, 1.48, 1.51, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.59, 1.59, 1.59, 1.59, 1.59},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.63, 1.63, 1.63},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.64, 1.65, 1.66},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.64, 1.65, 1.67},
            },
            -- adjustments for engine bleed: 2 and 3 packs off (the same at every altitude)
            packs_off = {alt = {-2000, 10000}, [2] = {0.01, 0.01}, [3] = {0.02, 0.02}},
        },
        -- Max Climb EPR, PW4056 (PI.10.36, FCOM p.262), 340 KIAS / M.84
        clb = {
            alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
            tat = {60, 50, 40, 30, 20, 10, 0, -10, -20},
            v = {
                {1.19, 1.19, 1.18, F, F, F, F, F, F, F},
                {1.23, 1.23, 1.22, 1.21, F, F, F, F, F, F},
                {1.25, 1.29, 1.28, 1.27, 1.25, F, F, F, F, F},
                {1.25, 1.30, 1.35, 1.35, 1.33, 1.32, F, F, F, F},
                {1.25, 1.30, 1.35, 1.39, 1.42, 1.42, 1.42, 1.39, F, F},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.52, 1.48, 1.44, 1.41},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.58, 1.54, 1.51},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
            },
            -- engine anti-ice on, engine and wing anti-ice on
            nai = {alt = {0, 10000, 20000, 30000, 40000}, v = {-0.01, -0.02, -0.03, -0.04, -0.05}},
            nai_wai = {alt = {0, 10000, 20000, 30000, 40000}, v = {-0.03, -0.04, -0.06, -0.07, -0.08}},
        },
    },
    GE = {
        -- Go-around %N1, CF6-80C2B1F (PI.20.32, FCOM p.360), airport pressure altitude
        ga = {
            alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
            tat = {57, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0, -10, -20, -30, -40, -50},
            v = {
                {102.9, 103.0, 103.2, 103.4, 103.6, 103.6, 103.6, 103.9, 104.0, 104.0, 103.9, 103.9, 103.8},
                {104.0, 104.7, 105.3, 105.5, 105.1, 104.5, 104.0, 104.3, 104.5, 104.4, 104.4, 104.3, 104.3},
                {104.6, 105.3, 106.0, 106.2, 106.2, 106.1, 105.6, 105.4, 105.0, 104.7, 104.7, 104.6, 104.6},
                {105.2, 105.9, 106.6, 106.9, 107.0, 106.9, 106.7, 106.9, 106.9, 106.3, 105.6, 104.9, 104.8},
                {104.6, 105.9, 107.3, 107.7, 107.8, 107.7, 107.5, 107.8, 107.8, 107.8, 107.6, 106.9, 106.1},
                {103.7, 105.1, 106.4, 107.4, 108.4, 108.5, 108.4, 108.6, 108.7, 108.7, 108.6, 108.2, 107.8},
                {102.9, 104.2, 105.5, 106.6, 107.5, 108.3, 109.0, 109.3, 109.4, 109.5, 109.6, 109.2, 108.8},
                {102.0, 103.4, 104.7, 105.7, 106.6, 107.4, 108.1, 109.0, 109.8, 110.2, 110.3, 110.1, 109.8},
                {101.2, 102.5, 103.8, 104.8, 105.7, 106.5, 107.2, 108.0, 108.8, 109.6, 110.3, 110.8, 110.9},
                {100.3, 101.6, 102.9, 103.9, 104.8, 105.5, 106.2, 107.1, 107.9, 108.6, 109.3, 109.9, 110.4},
                {99.4, 100.7, 102.0, 103.0, 103.9, 104.6, 105.3, 106.2, 107.0, 107.7, 108.4, 108.9, 109.4},
                {98.5, 99.8, 101.1, 102.1, 103.0, 103.7, 104.4, 105.2, 106.0, 106.7, 107.4, 107.9, 108.5},
                {96.7, 98.0, 99.2, 100.2, 101.1, 101.9, 102.5, 103.4, 104.2, 104.8, 105.5, 106.0, 106.5},
                {94.9, 96.1, 97.3, 98.3, 99.2, 100.0, 100.6, 101.5, 102.2, 102.9, 103.6, 104.4, 104.6},
                {93.0, 94.2, 95.4, 96.4, 97.3, 98.0, 98.7, 99.5, 100.3, 100.9, 101.6, 102.1, 102.5},
                {91.1, 92.3, 93.5, 94.4, 95.3, 96.0, 96.7, 97.5, 98.3, 98.9, 99.5, 100.0, 100.5},
                {89.2, 90.3, 91.5, 92.4, 93.3, 94.0, 94.7, 95.5, 96.2, 96.9, 97.5, 97.9, 98.4},
            },
            packs_off = {alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
                [2] = {0.3, 0.3, 0.3, 0.3, 0.3, 0.4, 0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6},
                [3] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.6, 0.7, 0.8, 0.8, 0.8, 0.8, 0.8, 0.9}},
            nai = {alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
                v = {-0.5, -0.5, -0.5, -0.5, -0.5, -0.6, -0.7, -0.7, -0.8, -0.8, -0.8, -0.7, -0.7}},
        },
        -- Max Climb %N1, CF6-80C2B1F (PI.20.31, FCOM p.359), 340 KIAS / M.84
        clb = {
            alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
            tat = {50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0, -5, -10, -15, -20, -25, -30, -35, -40},
            v = {
                {99.4, 100.8, F, F, F, F, F, F, F, F},
                {99.9, 101.3, 102.0, 101.1, F, F, F, F, F, F},
                {100.3, 101.9, 102.6, 101.6, F, F, F, F, F, F},
                {99.7, 102.5, 103.1, 102.1, 102.0, F, F, F, F, F},
                {99.0, 102.3, 103.7, 102.8, 102.6, F, F, F, F, F},
                {98.2, 101.6, 103.9, 103.4, 103.2, 103.2, 101.9, F, F, F},
                {97.4, 100.8, 103.2, 104.1, 103.6, 104.1, 102.7, F, F, F},
                {96.6, 99.9, 102.4, 103.5, 104.3, 104.9, 103.6, 101.1, 100.9, F},
                {95.8, 99.1, 101.6, 102.7, 104.1, 105.9, 104.4, 101.9, 101.5, 101.1},
                {95.0, 98.3, 100.7, 101.8, 103.3, 105.8, 105.2, 102.7, 102.3, 101.9},
                {94.1, 97.4, 99.9, 100.9, 102.6, 105.0, 106.3, 103.7, 103.2, 102.8},
                {93.3, 96.6, 99.0, 100.0, 101.7, 104.2, 105.7, 104.6, 104.1, 103.7},
                {92.5, 95.7, 98.1, 99.1, 100.8, 103.2, 104.9, 105.6, 105.0, 104.5},
                {91.6, 94.8, 97.2, 98.2, 99.9, 102.3, 104.0, 105.5, 105.4, 105.1},
                {90.7, 93.9, 96.3, 97.3, 99.0, 101.3, 103.0, 104.7, 104.6, 104.3},
                {89.9, 93.0, 95.4, 96.4, 98.1, 100.4, 102.1, 103.9, 103.8, 103.5},
                {89.0, 92.1, 94.5, 95.5, 97.1, 99.4, 101.1, 102.9, 102.8, 102.5},
                {88.1, 91.2, 93.6, 94.5, 96.2, 98.4, 100.1, 101.8, 101.8, 101.5},
                {87.2, 90.3, 92.6, 93.6, 95.2, 97.4, 99.0, 100.8, 100.8, 100.4},
            },
            nai = {alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
                v = {-0.5, -0.5, -0.6, -0.6, -0.7, -0.8, -0.9, -1.1, -1.6, -2.0}},
            nai_wai = {alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
                v = {-0.9, -1.0, -1.2, -1.1, -1.3, -1.5, -1.7, -2.0, -3.0, -4.0}},
        },
    },
}

-- (the FMC's step 9h1) the maximum continuous tables, one engine
-- inoperative, 3 packs on, anti-ice off: the CON reference thrust limit
-- and the full-forward rating's maximum continuous band.
-- Max Continuous EPR, PW4056 (PI.13.1-13.2, FCOM p.283-284): by pressure
-- altitude (ft) the EPR, MAX TAT (°C) and EPR CORR of each column, the five
-- KIAS then the five Mach (false where blank); above MAX TAT the EPR less
-- EPR CORR for every 10 °C. The packs' adjustment by the packs off (1, 2).
M.TABLE.PW.mct = {
    alt = {0, 1500, 5000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000,
        25000, 27000, 29000, 31000, 33000, 35000, 37000, 39000, 41000, 43000, 45000},
    kias = {150, 200, 250, 300, 350},
    mach = {0.70, 0.75, 0.80, 0.85, 0.90},
    v = {
        {{1.37, 1.35, 1.32, 1.28, 1.24, F, F, F, F, F}, {33, 36, 39, 43, 47, F, F, F, F, F},
            {0.05, 0.05, 0.05, 0.05, 0.05, F, F, F, F, F}},                                     -- 0
        {{1.38, 1.37, 1.33, 1.29, 1.25, F, F, F, F, F}, {31, 33, 37, 41, 45, F, F, F, F, F},
            {0.05, 0.05, 0.05, 0.05, 0.05, F, F, F, F, F}},                                     -- 1500
        {{1.43, 1.41, 1.38, 1.33, 1.28, F, F, F, F, F}, {25, 27, 30, 34, 40, F, F, F, F, F},
            {0.06, 0.06, 0.06, 0.06, 0.06, F, F, F, F, F}},                                     -- 5000
        {{1.51, 1.48, 1.44, 1.38, 1.33, F, F, F, F, F}, {16, 18, 22, 27, 33, F, F, F, F, F},
            {0.08, 0.08, 0.08, 0.07, 0.07, F, F, F, F, F}},                                     -- 10000
        {{1.54, 1.51, 1.46, 1.40, 1.35, F, F, F, F, F}, {11, 15, 19, 24, 30, F, F, F, F, F},
            {0.08, 0.08, 0.08, 0.08, 0.07, F, F, F, F, F}},                                     -- 12000
        {{1.57, 1.54, 1.49, 1.43, 1.36, 1.34, F, F, F, F}, {8, 11, 15, 21, 27, 30, F, F, F, F},
            {0.09, 0.09, 0.09, 0.08, 0.08, 0.08, F, F, F, F}},                                  -- 14000
        {{1.60, 1.56, 1.51, 1.45, 1.38, 1.38, F, F, F, F}, {4, 8, 12, 18, 25, 25, F, F, F, F},
            {0.09, 0.09, 0.09, 0.09, 0.08, 0.08, F, F, F, F}},                                  -- 16000
        {{1.63, 1.59, 1.54, 1.47, 1.39, 1.41, 1.38, F, F, F}, {0, 4, 9, 15, 23, 21, 24, F, F, F},
            {0.08, 0.09, 0.09, 0.09, 0.08, 0.08, 0.09, F, F, F}},                               -- 18000
        {{1.65, 1.61, 1.56, 1.48, 1.40, 1.44, 1.41, F, F, F}, {-3, 1, 6, 13, 20, 17, 20, F, F, F},
            {0.08, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, F, F, F}},                               -- 20000
        {{1.67, 1.64, 1.58, 1.50, 1.43, 1.48, 1.45, 1.41, F, F}, {-7, -3, 4, 11, 18, 12, 16, 20, F, F},
            {0.07, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, F, F}},                            -- 22000
        {{1.68, 1.66, 1.61, 1.52, 1.45, 1.52, 1.49, 1.46, 1.41, F}, {-10, -5, 0, 8, 16, 8, 11, 15, 19, F},
            {0.07, 0.08, 0.09, 0.09, 0.10, 0.09, 0.09, 0.10, 0.10, F}},                         -- 24000
        {{1.68, 1.67, 1.62, 1.53, 1.45, 1.54, 1.52, 1.48, 1.43, F}, {-10, -6, -1, 7, 15, 6, 9, 13, 17, F},
            {0.07, 0.08, 0.09, 0.09, 0.10, 0.09, 0.09, 0.10, 0.10, F}},                         -- 25000
        {{1.69, 1.69, 1.64, 1.56, 1.47, 1.58, 1.56, 1.52, 1.48, 1.43}, {-12, -9, -4, 4, 13, 1, 5, 9, 13, 17},
            {0.06, 0.07, 0.08, 0.09, 0.10, 0.09, 0.09, 0.10, 0.10, 0.10}},                      -- 27000
        {{F, 1.71, 1.65, 1.58, 1.49, 1.62, 1.60, 1.57, 1.53, 1.48}, {F, -14, -6, 3, 12, -3, 0, 4, 8, 12},
            {F, 0.06, 0.08, 0.09, 0.10, 0.08, 0.09, 0.10, 0.10, 0.10}},                         -- 29000
        {{F, 1.72, 1.66, 1.61, 1.52, 1.65, 1.64, 1.61, 1.57, 1.53}, {F, -16, -8, 1, 8, -7, -4, 0, 4, 8},
            {F, 0.06, 0.08, 0.10, 0.10, 0.08, 0.09, 0.09, 0.10, 0.10}},                         -- 31000
        {{F, 1.71, 1.67, 1.62, F, 1.67, 1.66, 1.64, 1.61, 1.57}, {F, -18, -11, -2, F, -12, -8, -4, -1, 3},
            {F, 0.05, 0.08, 0.10, F, 0.08, 0.09, 0.09, 0.10, 0.10}},                            -- 33000
        {{F, 1.70, 1.67, 1.61, F, 1.68, 1.67, 1.66, 1.63, 1.59}, {F, -18, -12, -4, F, -16, -13, -9, -6, -2},
            {F, 0.05, 0.08, 0.10, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                            -- 35000
        {{F, 1.69, 1.66, 1.58, F, 1.68, 1.67, 1.65, 1.62, 1.59}, {F, -24, -14, -4, F, -19, -15, -12, -8, -4},
            {F, 0.04, 0.09, 0.10, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                            -- 37000
        {{F, 1.67, 1.63, 1.53, F, 1.66, 1.65, 1.64, 1.61, 1.57}, {F, -22, -12, 0, F, -19, -15, -12, -8, -4},
            {F, 0.05, 0.09, 0.10, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                            -- 39000
        {{F, 1.64, 1.59, 1.48, F, 1.64, 1.63, 1.62, 1.59, 1.55}, {F, -20, -9, 3, F, -19, -15, -12, -8, -4},
            {F, 0.06, 0.09, 0.10, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                            -- 41000
        {{F, 1.62, 1.55, 1.43, F, 1.62, 1.62, 1.60, 1.57, 1.53}, {F, -18, -7, 7, F, -19, -15, -12, -8, -4},
            {F, 0.07, 0.09, 0.10, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                            -- 43000
        {{F, 1.61, 1.52, F, F, 1.61, 1.61, 1.59, 1.56, 1.52}, {F, -16, -4, F, F, -19, -15, -12, -8, -4},
            {F, 0.08, 0.10, F, F, 0.07, 0.08, 0.09, 0.10, 0.10}},                               -- 45000
    },
    packs_off = {alt = {0, 45000}, [1] = {0.01, 0.01}, [2] = {0.02, 0.02}},
    nai = {alt = {0, 10000, 20000, 30000, 40000, 45000}, v = {-0.01, -0.02, -0.03, -0.04, -0.05, -0.05}},
    nai_wai = {alt = {0, 10000, 20000, 30000, 40000, 45000}, v = {-0.03, -0.04, -0.06, -0.07, -0.08, -0.08}},
}
-- (2026-11-14, notes/ATA-34-61-FMC.md §169) Max Cruise EPR, PW4056, all
-- engines, normal engine bleed for 3 packs on (FPPM p.107, 3.1.1), anti-ice
-- off: the FPPM's (Boeing D632U002-RZ043, 747-400F/PW4056, FAA) under its
-- Long Range Cruise tables (p.120-127, 3.2.12-3.2.19; the .85M tables' on
-- p.128-131 the same within 0.01 EPR and 1 °C): by pressure altitude (ft)
-- the LIMIT EPR, its MAX TAT (°C) and its decrease for every 10 °C of TAT
-- hotter than that (each page's: corr); colder the LIMIT EPR (the FPPM has
-- no colder adjustment, as the FCOM's maximum continuous tables). The
-- anti-ice decreases each page's: engine 0.03 (6,000-20,000 and 38,000-
-- 45,000 ft) or 0.04 (22,000-37,000 ft), engine and wing 0.06 (6,000-20,000
-- ft) or 0.08; between the pages linear (estimate). The CRZ reference thrust
-- limit (B747.42.ref_thrust_model.lua; before, the maximum climb table:
-- estimate, §129). The cruise tables' speeds only: the FPPM's gear-down
-- tables (p.171-177, slower) give a higher limit, not used
M.TABLE.PW.crz = {
    alt = {6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000,
        22000, 23000, 24000, 25000, 26000, 27000, 28000, 29000,
        30000, 31000, 32000, 33000, 34000, 35000, 36000, 37000,
        38000, 39000, 40000, 41000, 42000, 43000, 44000, 45000},
    epr = {1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.27,      -- p.126-127
        1.28, 1.29, 1.29, 1.30, 1.33, 1.35, 1.38, 1.42,         -- p.124-125
        1.44, 1.46, 1.48, 1.51, 1.52, 1.53, 1.55, 1.54,         -- p.122-123
        1.53, 1.52, 1.51, 1.50, 1.50, 1.49, 1.49, 1.49},        -- p.120-121
    mt = {38, 35, 33, 30, 28, 25, 23, 21,
        19, 18, 17, 15, 13, 11, 9, 7,
        5, 5, 3, 0, -2, -4, -6, -7,
        -7, -7, -7, -7, -7, -7, -7, -7},
    corr = {0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06, 0.06,
        0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08,
        0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10,
        0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12},
    nai = {alt = {20000, 22000, 37000, 38000}, v = {-0.03, -0.04, -0.04, -0.03}},
    nai_wai = {alt = {20000, 22000}, v = {-0.06, -0.08}},
}

-- (2026-11-24, ENG-2 of the 2026-11-23 review) the P&W's takeoff EPR, the
-- FPPM's (Boeing D632U002-RZ043, 747-400F/PW4056, FAA): Takeoff EPR p.44
-- (1.2.20), TO1 Takeoff EPR, 8 % thrust reduction p.57 (1.3.11), TO2
-- Takeoff EPR, 20 % thrust reduction p.69 (1.3.23). Rows by airport OAT
-- (°C, hot to cold; the last "10 & BELOW"), columns by airport pressure
-- altitude (ft); false where blank (too hot for the altitude; TO2 at 50 °C
-- and 10,000 ft too). For engine bleed with 3 packs on and anti-ice on or
-- off: no anti-ice adjustment (p.22 (1.1.4)); 2 packs off +0.01, 3 packs
-- off +0.02 (each page). Read at the OAT (the tables' `tat`), held at the
-- ends: the FMC's TO reference (B747.42.ref_thrust_model.lua) and the
-- EEC's maximum while the thrust limit is a takeoff's (M.update's
-- inp.takeoff). Before, the go-around table at the TAT stood for the
-- takeoff rating (above: "the FCOM has no normal-mode takeoff table"):
-- 0.026 EPR over p.44 on average (0.01-0.04 at 5,000-10,000 ft and at 35
-- to 50 °C, held from 54 °C), TO 1 and TO 2 (by the EPR model's thrust)
-- 0.035 and 0.042 over p.57 and p.69
do
    local alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000}
    local oat = {70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10}
    local packs = {alt = {-2000, 10000}, [2] = {0.01, 0.01}, [3] = {0.02, 0.02}}
    M.TABLE.PW.to = {alt = alt, tat = oat, packs_off = packs, v = {      -- p.44
        {1.25, 1.25, 1.25, F, F, F, F, F, F, F, F, F, F},
        {1.28, 1.28, 1.29, 1.29, 1.29, 1.29, F, F, F, F, F, F, F},
        {1.32, 1.32, 1.32, 1.32, 1.32, 1.32, 1.32, 1.32, F, F, F, F, F},
        {1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, F, F},
        {1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39},
        {1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.43, 1.42, 1.42, 1.42, 1.42, 1.42},
        {1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46},
        {1.46, 1.48, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.50, 1.49, 1.49, 1.49},
        {1.46, 1.48, 1.51, 1.52, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53, 1.53},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.59, 1.59, 1.59, 1.59, 1.59},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.60, 1.61, 1.62, 1.62, 1.62},
        {1.46, 1.48, 1.51, 1.52, 1.54, 1.55, 1.56, 1.57, 1.60, 1.61, 1.62, 1.63, 1.65},
    }}
    M.TABLE.PW.to1 = {alt = alt, tat = oat, packs_off = packs, v = {     -- p.57
        {1.22, 1.22, 1.22, F, F, F, F, F, F, F, F, F, F},
        {1.25, 1.25, 1.26, 1.26, 1.26, 1.26, F, F, F, F, F, F, F},
        {1.29, 1.29, 1.29, 1.29, 1.29, 1.29, 1.29, 1.29, F, F, F, F, F},
        {1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, F, F},
        {1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35, 1.35},
        {1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.37, 1.37, 1.37, 1.37, 1.37},
        {1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41},
        {1.41, 1.42, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.44, 1.43, 1.43, 1.43},
        {1.41, 1.42, 1.45, 1.45, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46, 1.46},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.49, 1.49, 1.49, 1.49, 1.49},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.51, 1.51, 1.51, 1.51, 1.51},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.52, 1.53, 1.53, 1.53, 1.53},
        {1.41, 1.42, 1.45, 1.45, 1.47, 1.48, 1.49, 1.49, 1.52, 1.53, 1.53, 1.54, 1.56},
    }}
    M.TABLE.PW.to2 = {alt = alt, tat = oat, packs_off = packs, v = {     -- p.69
        {1.21, 1.21, 1.21, F, F, F, F, F, F, F, F, F, F},
        {1.21, 1.21, 1.22, 1.22, 1.22, 1.22, F, F, F, F, F, F, F},
        {1.24, 1.24, 1.24, 1.24, 1.24, 1.24, 1.24, 1.24, F, F, F, F, F},
        {1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, 1.26, F, F},
        {1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, 1.28, F},
        {1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.31, 1.30, 1.30, 1.30, 1.30, 1.30},
        {1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33, 1.33},
        {1.33, 1.34, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.36, 1.35, 1.35, 1.35},
        {1.33, 1.34, 1.36, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37, 1.37},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39, 1.39},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.41, 1.41, 1.41, 1.41},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.42, 1.43, 1.43, 1.43},
        {1.33, 1.34, 1.36, 1.37, 1.38, 1.39, 1.39, 1.40, 1.41, 1.42, 1.43, 1.43, 1.44},
    }}
end
-- the takeoff's thrust of each table, a share of the full rating's (p.57:
-- 8 %, p.69: 20 % thrust reduction); and FPPM p.22 (1.1.4): the minimum
-- allowable EPR for an assumed temperature's reduced thrust, "based on 25%
-- takeoff thrust reduction", by the MAX TAKEOFF EPR FOR ACTUAL OAT
M.PW_TO_SHARE = {1, 0.92, 0.80}
M.PW_TO_MIN = {less = 0.25,
    max = {1.31, 1.35, 1.40, 1.45, 1.50, 1.55, 1.60, 1.65, 1.70, 1.75},
    min = {1.21, 1.23, 1.26, 1.29, 1.32, 1.35, 1.37, 1.40, 1.42, 1.44}}
-- Max Continuous %N1, CF6-80C2B1F (PI.23.1-23.3, FCOM p.379-381), 5,000 to
-- 39,000 ft (held below 5,000: estimate): by pressure altitude the KIAS
-- rows and the TAT columns (°C, cold to warm) of N1. The packs' adjustment
-- (PACKS OFF) taken for all three packs off (estimate).
M.TABLE.GE.mct = {
    alt = {5000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000, 25000,
        27000, 29000, 31000, 33000, 35000, 37000, 39000},
    by_tat = true,
    rows = {
        {kias = {200, 240, 280, 320, 360}, tat = {-10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45}, v = {   -- 5000
            {97.3, 98.2, 99.1, 99.9, 100.8, 101.6, 102.3, 102.1, 101.5, 100.9, 100.3, 99.7},
            {96.9, 97.7, 98.6, 99.5, 100.3, 101.2, 101.9, 102.4, 101.8, 101.2, 100.6, 100.1},
            {96.4, 97.2, 98.1, 99.0, 99.8, 100.7, 101.4, 102.2, 102.2, 101.6, 101.0, 100.4},
            {95.8, 96.7, 97.5, 98.4, 99.2, 100.1, 100.9, 101.6, 102.3, 102.3, 102.1, 101.5},
            {95.2, 96.0, 96.9, 97.7, 98.6, 99.4, 100.2, 101.0, 101.8, 102.5, 102.0, 101.4}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40}, v = {  -- 10000
            {99.3, 100.2, 101.1, 102.0, 102.8, 103.6, 103.7, 103.1, 102.6, 102.0, 101.4, 100.9},
            {98.8, 99.7, 100.6, 101.4, 102.3, 103.1, 103.9, 103.5, 103.0, 102.4, 101.8, 101.3},
            {98.2, 99.1, 99.9, 100.8, 101.7, 102.5, 103.3, 103.9, 103.4, 102.8, 102.3, 101.7},
            {97.5, 98.4, 99.3, 100.1, 101.0, 101.9, 102.7, 103.4, 103.9, 103.3, 102.8, 102.2},
            {96.1, 97.0, 97.9, 98.8, 99.6, 100.5, 101.3, 102.1, 102.9, 103.2, 102.7, 102.2}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35}, v = { -- 12000
            {99.2, 100.1, 101.0, 102.0, 102.8, 103.7, 104.2, 103.6, 103.0, 102.3, 101.8, 101.2},
            {98.7, 99.6, 100.5, 101.4, 102.3, 103.1, 103.9, 104.0, 103.4, 102.8, 102.2, 101.6},
            {98.0, 98.9, 99.8, 100.7, 101.6, 102.5, 103.3, 104.1, 103.9, 103.3, 102.7, 102.1},
            {97.3, 98.2, 99.1, 100.0, 100.9, 101.7, 102.6, 103.4, 104.2, 103.8, 103.2, 102.6},
            {95.6, 96.5, 97.4, 98.3, 99.2, 100.0, 100.9, 101.7, 102.5, 103.3, 102.9, 102.3}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35}, v = { -- 14000
            {100.0, 100.9, 101.8, 102.7, 103.6, 104.4, 103.9, 103.3, 102.6, 102.1, 101.5, 100.8},
            {99.4, 100.3, 101.2, 102.1, 103.0, 103.9, 104.4, 103.8, 103.1, 102.5, 101.9, 101.4},
            {98.7, 99.6, 100.5, 101.4, 102.3, 103.2, 104.0, 104.3, 103.7, 103.0, 102.4, 101.9},
            {97.7, 98.6, 99.5, 100.4, 101.3, 102.1, 103.0, 103.8, 104.0, 103.4, 102.8, 102.1},
            {95.9, 96.8, 97.7, 98.6, 99.4, 100.3, 101.2, 102.0, 102.8, 103.1, 102.5, 101.9}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30}, v = { -- 16000
            {101.5, 102.4, 103.4, 104.3, 105.2, 106.0, 106.0, 105.4, 104.8, 104.2, 103.6, 102.9},
            {100.2, 101.1, 102.0, 103.0, 103.9, 104.7, 105.6, 105.2, 104.6, 104.0, 103.4, 102.8},
            {98.8, 99.7, 100.6, 101.5, 102.4, 103.3, 104.2, 105.0, 104.4, 103.8, 103.2, 102.7},
            {97.3, 98.2, 99.1, 100.0, 100.9, 101.8, 102.7, 103.5, 104.3, 103.8, 103.2, 102.6},
            {95.8, 96.7, 97.6, 98.5, 99.4, 100.3, 101.1, 102.0, 102.8, 103.6, 103.3, 102.7}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30}, v = { -- 18000
            {103.0, 103.9, 104.8, 105.7, 106.6, 107.2, 106.5, 106.0, 105.5, 104.8, 104.1, 102.6},
            {101.1, 102.1, 103.0, 103.9, 104.8, 105.7, 105.9, 105.3, 104.8, 104.2, 103.6, 102.8},
            {99.4, 100.4, 101.3, 102.2, 103.1, 104.0, 104.8, 104.9, 104.3, 103.9, 103.3, 102.7},
            {97.9, 98.8, 99.7, 100.6, 101.5, 102.4, 103.2, 104.1, 104.3, 103.7, 103.2, 102.7},
            {96.4, 97.3, 98.2, 99.1, 100.0, 100.9, 101.7, 102.6, 103.4, 103.9, 103.2, 102.8}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30}, v = { -- 20000
            {104.0, 104.9, 105.9, 106.7, 107.4, 106.8, 106.2, 105.7, 105.1, 104.4, 103.8, 99.9},
            {102.1, 103.1, 104.0, 104.9, 105.7, 106.3, 105.6, 105.1, 104.5, 103.9, 103.2, 102.7},
            {100.3, 101.2, 102.1, 103.0, 103.9, 104.7, 105.3, 104.6, 104.1, 103.6, 102.9, 102.3},
            {98.4, 99.3, 100.3, 101.2, 102.1, 102.9, 103.7, 104.4, 103.7, 103.2, 102.7, 102.1},
            {97.0, 97.9, 98.8, 99.7, 100.6, 101.4, 102.3, 103.0, 103.8, 103.4, 102.9, 102.4}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25}, v = { -- 22000
            {104.5, 105.5, 106.4, 107.3, 108.1, 108.0, 107.2, 106.5, 105.8, 105.0, 104.4, 102.0},
            {102.5, 103.5, 104.5, 105.4, 106.2, 107.1, 106.7, 106.0, 105.3, 104.6, 103.9, 103.2},
            {100.5, 101.4, 102.4, 103.3, 104.2, 105.1, 105.9, 105.6, 104.9, 104.2, 103.5, 102.8},
            {98.4, 99.4, 100.3, 101.3, 102.2, 103.1, 103.9, 104.7, 104.8, 104.0, 103.3, 102.7},
            {97.0, 97.9, 98.9, 99.8, 100.7, 101.6, 102.5, 103.3, 104.1, 104.6, 103.8, 103.2}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25}, v = { -- 24000
            {104.7, 105.8, 106.8, 107.9, 108.9, 108.1, 107.3, 106.4, 105.6, 104.8, 103.9, 99.2},
            {103.7, 104.7, 105.7, 106.6, 107.4, 107.8, 106.9, 106.0, 105.2, 104.4, 103.6, 103.0},
            {101.3, 102.3, 103.2, 104.2, 105.1, 105.9, 106.5, 105.5, 104.7, 103.9, 103.1, 102.3},
            {99.3, 100.3, 101.3, 102.2, 103.2, 104.1, 104.9, 105.7, 104.9, 104.1, 103.3, 102.5},
            {97.9, 98.8, 99.8, 100.7, 101.6, 102.5, 103.4, 104.3, 105.1, 104.9, 104.1, 103.3}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20}, v = { -- 25000
            {103.6, 104.7, 105.8, 106.8, 107.9, 108.9, 108.1, 107.2, 106.3, 105.4, 104.7, 102.6},
            {103.2, 104.2, 105.2, 106.2, 107.1, 108.0, 107.8, 106.8, 105.9, 105.1, 104.2, 103.5},
            {100.6, 101.6, 102.6, 103.6, 104.5, 105.4, 106.3, 106.4, 105.4, 104.5, 103.6, 102.8},
            {98.8, 99.8, 100.7, 101.7, 102.7, 103.6, 104.5, 105.3, 105.9, 104.9, 104.1, 103.2},
            {97.3, 98.3, 99.2, 100.2, 101.1, 102.1, 103.0, 103.9, 104.7, 105.5, 105.0, 104.1}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20}, v = { -- 27000
            {103.6, 104.7, 105.8, 106.8, 107.9, 108.9, 108.1, 107.2, 106.3, 105.5, 104.9, 100.0},
            {103.6, 104.7, 105.8, 106.8, 107.9, 108.8, 107.8, 106.9, 106.0, 105.1, 104.3, 103.7},
            {101.6, 102.6, 103.6, 104.6, 105.6, 106.4, 107.3, 106.4, 105.5, 104.6, 103.8, 102.9},
            {99.5, 100.5, 101.5, 102.5, 103.4, 104.4, 105.2, 106.1, 105.8, 104.9, 104.0, 103.2},
            {97.5, 98.5, 99.5, 100.4, 101.4, 102.3, 103.2, 104.1, 104.9, 105.5, 104.5, 103.7}}},
        {kias = {200, 240, 280, 320, 360}, tat = {-40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15}, v = { -- 29000
            {102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 108.9, 108.0, 107.1, 106.2, 105.5, 102.3},
            {102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 108.6, 107.6, 106.8, 105.9, 105.0, 104.2},
            {101.5, 102.5, 103.5, 104.5, 105.5, 106.4, 107.3, 107.4, 106.3, 105.5, 104.6, 103.8},
            {98.7, 99.8, 100.8, 101.7, 102.7, 103.7, 104.6, 105.4, 106.3, 105.2, 104.4, 103.5},
            {96.5, 97.5, 98.5, 99.5, 100.5, 101.4, 102.4, 103.3, 104.1, 104.9, 104.9, 103.9}}},
        {kias = {200, 240, 280, 320}, tat = {-45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10}, v = {    -- 31000
            {101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 108.3, 107.4, 106.5, 105.7, 104.4},
            {101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 107.9, 107.0, 106.1, 105.3, 104.4},
            {100.6, 101.6, 102.7, 103.7, 104.7, 105.7, 106.5, 107.4, 106.5, 105.6, 104.8, 103.9},
            {97.5, 98.6, 99.6, 100.6, 101.6, 102.6, 103.5, 104.4, 105.2, 105.4, 104.3, 103.5}}},
        {kias = {200, 240, 280, 320}, tat = {-45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10}, v = {    -- 33000
            {101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 107.2, 106.3, 105.4, 104.7, 100.9},
            {101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 107.9, 106.9, 106.0, 105.0, 104.2, 103.5},
            {100.3, 101.4, 102.4, 103.5, 104.5, 105.4, 106.2, 106.5, 105.4, 104.6, 103.6, 102.8},
            {97.5, 98.5, 99.5, 100.5, 101.5, 102.5, 103.5, 104.3, 105.1, 104.6, 103.7, 102.8}}},
        {kias = {200, 240, 280}, tat = {-50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5}, v = {         -- 35000
            {100.4, 101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 106.9, 106.0, 105.1, 104.3, 102.7},
            {100.4, 101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 106.7, 105.7, 104.7, 103.9, 103.1},
            {98.8, 99.9, 100.9, 102.0, 103.0, 104.0, 104.9, 105.6, 105.2, 104.3, 103.3, 102.4}}},
        {kias = {200, 240, 280}, tat = {-50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5}, v = {         -- 37000
            {100.4, 101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 106.0, 105.1, 104.3, 103.6, 101.4},
            {100.4, 101.5, 102.6, 103.6, 104.7, 105.8, 106.4, 105.6, 104.7, 103.7, 102.9, 102.1},
            {97.7, 98.7, 99.7, 100.8, 101.8, 102.8, 103.6, 104.4, 104.2, 103.4, 102.5, 101.5}}},
        {kias = {200, 240, 280}, tat = {-50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5}, v = {         -- 39000
            {100.4, 101.5, 102.6, 103.6, 104.7, 105.8, 106.8, 106.0, 105.0, 104.2, 103.4, 102.9},
            {100.0, 101.1, 102.1, 103.2, 104.2, 105.0, 105.8, 105.5, 104.7, 103.7, 102.8, 102.1},
            {96.8, 97.8, 98.9, 99.9, 100.9, 102.0, 102.9, 103.6, 104.3, 103.8, 102.9, 101.9}}},
    },
    packs_off = {alt = {5000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000, 25000, 27000, 29000, 31000, 33000, 35000, 37000, 39000},
        [3] = {0.2, 0.2, 0.3, 0.3, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.5, 0.6, 0.6}},
    nai = {alt = {5000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000, 25000, 27000, 29000, 31000, 33000, 35000, 37000, 39000},
        v = {-0.5, -0.6, -0.6, -0.6, -0.6, -0.6, -0.7, -0.7, -0.7, -0.8, -0.8, -0.8, -0.9, -1.0, -1.1, -1.3, -1.5}},
    nai_wai = {alt = {5000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000, 25000, 27000, 29000, 31000, 33000, 35000, 37000, 39000},
        v = {-1.0, -1.2, -1.2, -1.2, -1.2, -1.2, -1.4, -1.4, -1.4, -1.6, -1.6, -1.6, -1.8, -1.9, -2.1, -2.5, -2.9}},
}

-- the calibrated airspeed (kt) of a Mach at a pressure altitude (ft), ISA
local function mach_cas(mach, alt)
    local delta
    if alt <= 36089 then delta = (1 - 6.87559e-6 * alt) ^ 5.25588
    else delta = 0.223361 * math.exp(-4.80634e-5 * (alt - 36089)) end
    local qc = delta * ((1 + 0.2 * mach * mach) ^ 3.5 - 1)
    return 661.4786 * math.sqrt(5 * ((qc + 1) ^ (2 / 7) - 1))
end

-- the P&W table's cells of each altitude by airspeed: the KIAS columns and
-- the Mach columns at their CAS there, sorted
do
    local t = M.TABLE.PW.mct
    t.rows = {}
    for j = 1, #t.alt do
        local cells = {}
        for c = 1, #t.kias + #t.mach do
            local epr = t.v[j][1][c]
            if epr then
                local cas = c <= #t.kias and t.kias[c] or mach_cas(t.mach[c - #t.kias], t.alt[j])
                cells[#cells + 1] = {cas, epr, t.v[j][2][c], t.v[j][3][c]}
            end
        end
        table.sort(cells, function(a, b) return a[1] < b[1] end)
        local r = {cas = {}, epr = {}, mt = {}, corr = {}}
        for i, cell in ipairs(cells) do
            r.cas[i], r.epr[i], r.mt[i], r.corr[i] = cell[1], cell[2], cell[3], cell[4]
        end
        t.rows[j] = r
    end
end

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end

-- linear interpolation in a row of breakpoints, held at the ends
local function interp(xs, ys, x)
    if x <= xs[1] then return ys[1] end
    for i = 2, #xs do
        if x <= xs[i] then
            return ys[i - 1] + (ys[i] - ys[i - 1]) * (x - xs[i - 1]) / (xs[i] - xs[i - 1])
        end
    end
    return ys[#ys]
end

-- one altitude column of a table at a TAT: between the rows that have a
-- value, held at the warmest and coldest of them
local function column(t, j, tat)
    local xs, ys = {}, {}
    for i = #t.tat, 1, -1 do                 -- cold to warm: rising TAT for interp
        local v = t.v[i][j]
        if v then xs[#xs + 1] = t.tat[i]; ys[#ys + 1] = v end
    end
    return interp(xs, ys, tat)
end

-- the largest value of a table at a pressure altitude, whatever the TAT
-- (the corner point of the flat rating)
function M.lookup_max(t, alt)
    local a = t.alt
    local function col(j)
        local m = nil
        for i = 1, #t.tat do
            local v = t.v[i][j]
            if v and (m == nil or v > m) then m = v end
        end
        return m
    end
    if alt <= a[1] then return col(1) end
    if alt >= a[#a] then return col(#a) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = col(j - 1), col(j)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- a table's value at a TAT and pressure altitude (held at the ends)
function M.lookup(t, tat, alt)
    local a = t.alt
    if alt <= a[1] then return column(t, 1, tat) end
    if alt >= a[#a] then return column(t, #a, tat) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = column(t, j - 1, tat), column(t, j, tat)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- (the FMC's step 9h1) one altitude row of a maximum continuous table at a
-- KIAS and TAT: P&W each cell's EPR less its correction above its MAX TAT,
-- then along the airspeeds; GE each KIAS row along the TATs, then along the
-- KIAS; held at the ends
local function pw_cell(r, i, tat)
    return r.epr[i] - r.corr[i] * math.max(0, tat - r.mt[i]) / 10
end
local function mct_row(t, j, kias, tat)
    local r = t.rows[j]
    if t.by_tat then
        local ks, n = r.kias, #r.kias
        if kias <= ks[1] then return interp(r.tat, r.v[1], tat) end
        if kias >= ks[n] then return interp(r.tat, r.v[n], tat) end
        for i = 2, n do
            if kias <= ks[i] then
                local a, b = interp(r.tat, r.v[i - 1], tat), interp(r.tat, r.v[i], tat)
                return a + (b - a) * (kias - ks[i - 1]) / (ks[i] - ks[i - 1])
            end
        end
    end
    local cs, n = r.cas, #r.cas
    if kias <= cs[1] then return pw_cell(r, 1, tat) end
    if kias >= cs[n] then return pw_cell(r, n, tat) end
    for i = 2, n do
        if kias <= cs[i] then
            local a, b = pw_cell(r, i - 1, tat), pw_cell(r, i, tat)
            local d = cs[i] - cs[i - 1]
            if d <= 0 then return b end
            return a + (b - a) * (kias - cs[i - 1]) / d
        end
    end
end

-- (the FMC's step 9h1) a maximum continuous table's value at a TAT, pressure
-- altitude (ft) and KIAS (held at the ends)
function M.lookup_mct(t, tat, alt, kias)
    local a = t.alt
    if alt <= a[1] then return mct_row(t, 1, kias, tat) end
    if alt >= a[#a] then return mct_row(t, #a, kias, tat) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = mct_row(t, j - 1, kias, tat), mct_row(t, j, kias, tat)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- (2026-11-14) the maximum cruise table's value at a TAT and pressure
-- altitude (ft): each altitude's LIMIT EPR less its decrease above its MAX
-- TAT (as a maximum continuous cell), linear between the altitudes, held at
-- the ends (estimate: under 6,000 and over 45,000 ft)
function M.lookup_crz(t, tat, alt)
    local a = t.alt
    if alt <= a[1] then return pw_cell(t, 1, tat) end
    if alt >= a[#a] then return pw_cell(t, #a, tat) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = pw_cell(t, j - 1, tat), pw_cell(t, j, tat)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- (2026-11-24, ENG-2) y at x on points (xs, ys; xs rising or falling):
-- linear between them, on the end segments' lines beyond
local function on_points(xs, ys, x)
    local n = #xs
    local up = xs[n] > xs[1]
    local i = 2
    while i < n and ((up and x > xs[i]) or (not up and x < xs[i])) do i = i + 1 end
    local d = xs[i] - xs[i - 1]
    if d == 0 then return ys[i] end
    return ys[i - 1] + (ys[i] - ys[i - 1]) * (x - xs[i - 1]) / d
end

-- (ENG-2) FPPM p.22 (1.1.4): the minimum allowable takeoff EPR (25 % less
-- thrust) for a MAX TAKEOFF EPR: linear between its rows, on its end rows'
-- lines beyond them (estimate: the hot rows' EPRs under 1.31, and the
-- derated EPRs below)
function M.pw_to_min(e)
    return on_points(M.PW_TO_MIN.max, M.PW_TO_MIN.min, e)
end

-- (ENG-2) the P&W's takeoff thrust (a share of the full rating's) against
-- its EPR at an OAT (°C) and pressure altitude (ft), for 3 packs on: the
-- three FPPM tables at 1, 0.92 and 0.80 (PW_TO_SHARE), and each one's 25 %
-- less thrust by p.22's table at 0.75, 0.69 and 0.60 (the TO1's and TO2's
-- an estimate: p.22's is the full rating's), the EPRs falling. Filled into
-- es and ss, the caller's tables (no new ones a frame). Between the points
-- linear, beyond them on the end segments' lines (estimates): pw_to_epr
-- for a share (a derate the operator sets other than 8 and 20 %, 25 % less
-- than a derate), pw_to_share for an EPR (an assumed temperature's)
function M.pw_to_points(oat, alt, es, ss, rr)
    local T, s, q = M.TABLE.PW, M.PW_TO_SHARE, 1 - M.PW_TO_MIN.less
    local rt = rr and M.rr_to_table()
    if rt then
        -- (2026-11-25, the RB211's rebuild) its own takeoff table on the
        -- PW4056's scale; TO 1, TO 2 and each one's 25 % less as shares of
        -- that thrust on the EPR model standing (estimate: no RB211 source
        -- for its derates; the FPPM's 8 and 20 % taken)
        local P = B747_epr_model
        local e0 = M.lookup(rt, oat, alt)
        local f0 = P.thrust(e0, 1, 0)
        for i = 1, 3 do
            es[i] = i == 1 and e0 or P.epr(f0 * s[i], 1, 0)
            es[i + 3] = P.epr(f0 * s[i] * q, 1, 0)
            ss[i], ss[i + 3] = s[i], s[i] * q
        end
        return es, ss
    end
    local e0, e1, e2 = M.lookup(T.to, oat, alt), M.lookup(T.to1, oat, alt), M.lookup(T.to2, oat, alt)
    es[1], es[2], es[3] = e0, e1, e2
    es[4], es[5], es[6] = M.pw_to_min(e0), M.pw_to_min(e1), M.pw_to_min(e2)
    ss[1], ss[2], ss[3] = s[1], s[2], s[3]
    ss[4], ss[5], ss[6] = s[1] * q, s[2] * q, s[3] * q
    return es, ss
end

-- (2026-11-25, the RB211's rebuild: GAP_ANALYSIS.md §8, notes/ATA-70-80.md
-- §40) the RB211's takeoff EPR table (TOGA_epr_RR, B747.42.xt.EEC.tbls.lua:
-- the upstream's, its source not given; laid out as an FCOM's, flat to 30 C
-- at sea level as TCDS_RB211 p.15's ISA+15) on the PW4056's scale (B747_
-- rr_model.pw_of_display standing), in TABLE.PW.to's form: the EEC's and
-- the FMC's takeoff limit for the RB211 (the EEC runs on the P&W's scale).
-- Built once; nil without the table or the RR model (the tests that load
-- neither)
local rr_to = nil
function M.rr_to_table()
    if rr_to then return rr_to end
    local R, src = B747_rr_model, TOGA_epr_RR
    if not (R and src) then return nil end
    local base = M.TABLE.PW.to
    local oat = {70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5}
    local v = {}
    for j, t in ipairs(oat) do
        local row = {}
        for i, a in ipairs(base.alt) do
            local e = src[t] and src[t][a]
            row[i] = e and R.pw_of_display(e, 0) or F
        end
        v[j] = row
    end
    rr_to = {alt = base.alt, tat = oat, packs_off = base.packs_off, v = v}
    return rr_to
end
function M.pw_to_epr(es, ss, share) return on_points(ss, es, share) end
function M.pw_to_share(es, ss, epr) return on_points(es, ss, epr) end

-- X-Plane's idle ratio (M.IDLE): approach idle, or minimum idle in the air
-- or on the ground, at a pressure altitude (ft)
function M.idle_ratio(air, alt, approach)
    local r = interp(M.IDLE.alt, M.IDLE.air, alt)
    if approach then return r + M.IDLE.approach_step end
    if air then return r end
    return M.IDLE.ground
end

-- the bleed adjustment of a rating: packs off (go-around and maximum
-- continuous tables: the table's for that many packs off, or the most it
-- has under that), engine anti-ice, and engine and wing anti-ice (climb and
-- maximum continuous tables; the go-around tables have engine anti-ice for
-- the CF6 only)
local function adjustment(t, inp, alt, nai)
    local d = 0
    local off = 3 - clamp(inp.packs_on, 0, 3)
    if t.packs_off then
        for k = off, 1, -1 do
            local p = t.packs_off[k]
            if p then
                d = d + interp(t.packs_off.alt, p, alt)
                break
            end
        end
    end
    if nai then
        if inp.wai and t.nai_wai then d = d + interp(t.nai_wai.alt, t.nai_wai.v, alt)
        elseif t.nai then d = d + interp(t.nai.alt, t.nai.v, alt) end
    end
    return d
end
-- (ENG-2) for the P&W's takeoff reference (B747.42.ref_thrust_model.lua)
M.adjustment = adjustment

-- (the FMC's step 9g3) a table's rating with its bleed adjustments at a TAT
-- and pressure altitude: the reference thrust limit's (B747.42.
-- ref_thrust_model.lua); inp as M.inputs's (packs_on, wai)
function M.rating(t, inp, tat, alt, nai)
    return M.lookup(t, tat, alt) + adjustment(t, inp, alt, nai)
end

-- (the FMC's step 9h1) the maximum continuous rating with its bleed
-- adjustments at a TAT, pressure altitude (ft) and KIAS
function M.rating_mct(t, inp, tat, alt, kias, nai)
    return M.lookup_mct(t, tat, alt, kias) + adjustment(t, inp, alt, nai)
end

-- (2026-11-14) the maximum cruise rating with its anti-ice adjustments at a
-- TAT and pressure altitude (ft): the CRZ reference thrust limit's (no
-- packs' adjustment: the FPPM gives none)
function M.rating_crz(t, inp, tat, alt, nai)
    return M.lookup_crz(t, tat, alt) + adjustment(t, inp, alt, nai)
end

function M.inputs()
    return {
        type = "PW",                         -- "PW" or "GE" (anything else: P&W)
        alt = 0,                             -- pressure altitude, ft
        tat = 15,                            -- °C
        -- (2026-11-24, ENG-2) the OAT (°C; nil: the TAT's) and a takeoff's
        -- thrust limit (the FMC's TO, TO 1, TO 2 or D-): the P&W's maximum
        -- then the FPPM's Takeoff EPR at the OAT (TABLE.PW.to)
        oat = nil,
        takeoff = false,
        kias = 0,
        packs_on = 3,                        -- packs operating (their valves open)
        nai = {false, false, false, false},  -- engine anti-ice valve open
        wai = false,                         -- wing anti-ice valve open
        lever = {0, 0, 0, 0},                -- forward thrust lever, 0 idle to 1 forward stop
        idle = {0, 0, 0, 0},                 -- the engine's idle N1 (GE) or EPR (P&W)
        air = false,                         -- air/ground: in the air
        flaps_deg = 0,                       -- trailing edge flaps
        con = false,                         -- CON IGNITION switch ON
        freighter = false,                   -- 405 or 570 (CON selects approach idle there)
        reverser = {false, false, false, false},   -- the engine's reverser not stowed
        at_approach = nil,                   -- {n} engine at approach idle; nil: as selected
        altn = {false, false, false, false}, -- EEC MODE switch at ALTN
        -- (2026-11-04) failures (notes/ATA-70-80.md §10): the EEC cannot
        -- keep the normal mode and reverts to the alternate by itself; an
        -- EEC system fault (degraded, without its full redundancy)
        fail_altn = {false, false, false, false},
        fault = {false, false, false, false},
        -- (2026-11-04) the idle selection's faults (notes/ATA-70-80.md §12):
        -- the engine stays at minimum idle (ENG n LOW IDLE when approach
        -- idle is selected) or at approach idle (>IDLE DISAGREE)
        idle_min = {false, false, false, false},
        idle_approach = {false, false, false, false},
        n1 = {0, 0, 0, 0},                   -- the engines' N1 and N2, %
        n2 = {0, 0, 0, 0},
        actual = {0, 0, 0, 0},               -- the controlled value now: N1 (GE) or EPR (P&W)
        -- (N19-ENG-05) the RR (type "PW" for the tables): its alternate mode
        -- as before, on EPR (no sources); the P&W's is the N1 mode (PW_ALTN)
        rr = false,
    }
end

-- (N19-ENG-05) the P&W N1 mode's schedule: the N1 (%) for a lever angle
-- (degrees, M.TLA_STOP forward) and the TAT (°C, as Tt2)
function M.pw_altn_n1(tla, tat_c)
    local A = M.PW_ALTN
    return interp(A.tla, A.n1c, tla) * math.sqrt(math.max((tat_c or 15) + 273.15, 200) / 288.15)
end

-- (N19-ENG-05) the P&W's N1 mode of engine n (PW_ALTN): nil (the EPR
-- mode), "lock" (reverted by itself: the lockup holds delta) or "hard" (the
-- EEC MODE switch at ALTN: delta ramped out). Delta is taken as the mode is
-- entered from the EPR mode or as the lockup starts again (the switch back
-- at NORM with the fault still there)
local function pw_n1_mode(s, inp, n, tla, dt)
    local mode = s.n1_mode[n]
    local function lockup()
        local d = 0
        if inp.n2[n] > M.PW_ALTN.run_n2 then d = math.max(0, M.pw_altn_n1(tla, inp.tat) - inp.n1[n]) end
        s.n1_delta[n] = d
    end
    if inp.altn[n] then
        if mode == nil then lockup() end
        mode = "hard"
    elseif inp.fail_altn[n] then
        if mode ~= "lock" then lockup() end
        mode = "lock"
    elseif mode == "hard" then
        mode = nil              -- NORM and no fault: the EPR mode (p.198)
    end                         -- "lock" and no fault: kept until the switch is used
    if mode == "hard" then
        s.n1_delta[n] = math.max(0, (s.n1_delta[n] or 0) - M.PW_ALTN.ramp * dt)
    elseif mode == nil then
        s.n1_delta[n] = nil
    end
    s.n1_mode[n] = mode
    return mode
end

-- the overspeed protection: the target of each engine's thrust control and
-- whether a rotor limit holds it back (>ENG n RPM LIM)
local function overspeed(inp, out)
    local key = inp.type == "GE" and "GE" or "PW"
    local red = (key == "PW" and inp.rr) and M.REDLINE.RR or M.REDLINE[key]
    -- a rotor's limit loop: the controlled value it allows (nil while the
    -- rotor is short of its band)
    local function limit(rpm, redline, actual, gain)
        local short = redline - M.RPM_MARGIN - rpm
        if short > M.RPM_BAND then return nil end
        return actual + gain * short
    end
    out.target, out.rpm_lim = {}, {}
    for n = 1, 4 do
        -- (N19-ENG-05) the P&W in its N1 mode: on N1, as the GE
        local n1m = out.n1_mode[n]
        local k = n1m and "PWN1" or key
        local gain, show = M.RPM_GAIN[k], M.RPM_LIM_SHOW[k]
        local actual, command = inp.actual[n], out.command[n]
        if n1m then actual = inp.n1[n] end
        local lim = limit(inp.n2[n], red.n2, actual, gain)
        if key == "GE" then
            command = math.min(command, red.n1 - M.RPM_MARGIN)
        elseif n1m then
            -- its N1 limit caps the target; RPM LIM on N1 or N2 (FCOM p.901)
            local cap = red.n1 - M.RPM_MARGIN
            if lim == nil or cap < lim then lim = cap end
        else
            local lim1 = limit(inp.n1[n], red.n1, actual, gain)
            if lim1 and (lim == nil or lim1 < lim) then lim = lim1 end
        end
        local target = command
        if lim and lim < target then target = lim end
        out.target[n] = target
        out.rpm_lim[n] = lim ~= nil and lim < command - show and lim <= actual + show
    end
end

function M.new()
    return {approach = {false, false, false, false}, hold = {0, 0, 0, 0},
        altn = {false, false, false, false}, throttle = {}, err = {}, ref = {},
        rate = {},          -- (2026-11-10) the roll's learned throttle rate (RAMP_W)
        soft_top = {},      -- (2026-11-04) the schedule an automatic reversion keeps
        soft_clb = {},      -- (2026-11-13, B2) and the CF6's line's CLIMB point
        n1_mode = {},       -- (N19-ENG-05) the P&W's N1 mode: nil, "lock" or "hard"
        n1_delta = {}}      -- and its delta N1 (%)
end

-- the gains for the pressure ratio delta (nil: KI_DELTA_REF's)
function M.thrust_gains(delta)
    local d = clamp(delta or M.KI_DELTA_REF, 0.1, 1)
    local p = d < M.KI_DELTA_REF and M.KI_POWER[1] or M.KI_POWER[2]
    return M.KP, M.KI * (d / M.KI_DELTA_REF) ^ p
end

-- engine n's throttle for its target (key "GE" or "PW"; current: X-Plane's
-- throttle now, where the control starts from; idle: the lever's idle end
-- command; slope: the controlled value's for each unit of throttle, nil for
-- the tables'; delta: the pressure ratio; roll: on the takeoff roll, where
-- the throttle's rate is learned: M.RAMP_W)
function M.thrust_control(s, key, n, target, actual, current, idle, dt, slope, delta, roll)
    local g = M.THRUST[key]
    if target <= idle then
        s.throttle[n], s.err[n], s.ref[n], s.rate[n] = 0, nil, actual, nil
        return 0
    end
    local ref = s.ref[n] or actual
    ref = ref + clamp((target - ref) * math.min(1, dt / g.lag), -g.down * dt, g.up * dt)
    local th = s.throttle[n] or clamp(current, 0, 1)
    local err = ref - actual
    if not slope or slope <= 0 then slope = interp(g.at, g.slope, actual) end
    local kp, ki = M.thrust_gains(delta)
    local rate = s.rate[n] or 0
    th = clamp(th + (ki * err * dt + kp * (err - (s.err[n] or err))) / slope + rate * dt, 0, 1)
    if not roll then
        rate = rate * math.max(0, 1 - dt / M.RAMP_FADE)
    elseif math.abs(target - ref) < M.RAMP_SETTLED[key] and math.abs(err) < M.RAMP_BAND[key] then
        rate = clamp(rate + M.RAMP_W * ki * err * dt / slope, -M.RAMP_MAX, M.RAMP_MAX)
    end
    -- at full or no throttle the rate cannot help: no winding up
    if th >= 1 and rate > 0 or th <= 0 and rate < 0 then rate = 0 end
    s.throttle[n], s.err[n], s.ref[n], s.rate[n] = th, err, ref, rate
    return th
end

-- the control starts again from X-Plane's throttle (engine stopped,
-- starting or in reverse)
function M.reset_thrust_control(s, n)
    s.throttle[n], s.err[n], s.ref[n], s.rate[n] = nil, nil, nil, nil
end

-- (ENG-31) the CF6's reverse thrust: with the reverser not stowed the ECU
-- commands reverse thrust as a direct function of TLA, at full reverse with
-- both cowls deployed 90 % of the maximum rated thrust; idle while they
-- move (ATA70_80 p.206, p.208-209: N1 straight up from REV IDLE to MAX
-- REV). As X-Plane's throttle, the share of the engine's maximum thrust
-- (the maximum rated, B747_setMaxThrust): REV_SHARE at full reverse,
-- straight with `lever` (0 reverse idle, 1 full) (estimate: X-Plane's
-- thrust as its throttle). P&W: below. RR: no sources (X-Plane's as before)
M.REV_SHARE = 0.9
function M.reverse_throttle(lever)
    return M.REV_SHARE * clamp(lever, 0, 1)
end

-- (2026-11-20, GAP_ANALYSIS.md N19-ENG-03) the PW4000's reverse thrust:
-- the EEC in the N1 mode (its EPR sensing is not accurate in reverse: PW_PPM
-- p.196, p.204), the N1 a direct function of the lever (p.204) biased by Tt2
-- (p.196), MAX REV 87 % N1 (p.250); idle fuel flow while the sleeves move,
-- more reverse thrust only once they are deployed, forward thrust only
-- once they are stowed (p.250, p.550-552: the glue). The N1 for `lever` (0
-- reverse idle, 1 full): straight from idle_n1 to max_n1, as the corrected
-- speed (times the square root of Tt2 / 288.15 K) (estimates: the line,
-- idle_n1, the bias's form). Before, X-Plane's throttle the lever's: the
-- shown N1 99 % and EPR 1.45 at full reverse, near the max EPR's red
-- (s341, 2026-11-20: notes/ATA-70-80.md §23)
M.PW_REV = {max_n1 = 87, idle_n1 = 25}
-- its loop (thrust_control's key "PWREV", on the shown N1): the GE's N1
-- loop's slopes at 0.35 (about three times the gains) with the reference
-- rising 30 % a second through a 0.8 s lag: on a stand-in engine (the
-- shown N1 22 + 95 x the throttle through 1.2 s and 0.3 s lags, about
-- X-Plane's on the ground: s341) 86 % in about 4.5 s from reverse idle
-- without overshoot, where the GE's own took 9.6 s (estimates)
M.THRUST.PWREV = {lag = 0.8, up = 30, down = 15,
    at = {35, 45, 60, 75, 90, 100},
    slope = {7, 35, 39.2, 35, 28, 26.95}}                          -- N1 % for each unit of throttle
function M.pw_reverse_n1(lever, tt2_c)
    local n1 = M.PW_REV.idle_n1 + (M.PW_REV.max_n1 - M.PW_REV.idle_n1) * clamp(lever, 0, 1)
    return n1 * math.sqrt(math.max((tt2_c or 15) + 273.15, 200) / 288.15)
end

-- approach idle of each engine, and the idle messages: ENG n LOW IDLE
-- (approach idle selected, not reached) and >IDLE DISAGREE (an engine at
-- approach idle with minimum idle selected) (FCOM p.900, p.902; ATA70_80
-- p.230). The sim has no idle faults of its own: at_approach, or (2026-11-04)
-- the failure window's idle_min and idle_approach. X-Plane's idle is one
-- for all engines: the faults give the messages only.
local function idle_selection(s, inp, dt, out)
    local con = inp.con and (inp.type == "GE" or inp.freighter)
    local landing = inp.air and (inp.flaps_deg > M.LANDING_FLAPS_DEG or con)
    out.approach, out.low_idle, out.idle_disagree = {}, {}, false
    for n = 1, 4 do
        local want = landing or (inp.air and inp.nai[n]) or (inp.type == "GE" and inp.reverser[n])
        if want then
            s.approach[n], s.hold[n] = true, M.APPROACH_HOLD_S
        elseif s.approach[n] then
            s.hold[n] = s.hold[n] - dt
            if s.hold[n] <= 0 then s.approach[n], s.hold[n] = false, 0 end
        end
        local at = s.approach[n]
        if inp.at_approach then at = inp.at_approach[n] end
        if inp.idle_min[n] then at = false elseif inp.idle_approach[n] then at = true end
        out.approach[n] = s.approach[n]
        out.low_idle[n] = s.approach[n] and not at
        out.idle_disagree = out.idle_disagree or (at and not s.approach[n])
    end
end

-- the share of the takeoff rating in the full-forward rating (1 takeoff,
-- 0 maximum continuous or climb), and the lever angle at which the rating
-- is reached
function M.rating_mix(alt, kias)
    local by_alt = clamp((M.MCT_ALT - alt) / (M.MCT_ALT - M.TO_ALT), 0, 1)
    local by_speed = clamp((M.TO_KIAS - kias) / (M.TO_KIAS - M.MCT_KIAS), 0, 1)
    local tla_full = M.TLA_TO + (M.TLA_CLB - M.TLA_TO) * clamp((alt - M.MCT_ALT_TOP) / (M.CLB_ALT - M.MCT_ALT_TOP), 0, 1)
    return by_alt * by_speed, tla_full
end

function M.update(s, inp, dt)
    local tables = M.TABLE[inp.type] or M.TABLE.PW
    local to_share, tla_full = M.rating_mix(inp.alt, inp.kias)
    -- the go-around tables stop at 10,000 ft: held above (estimate)
    local ga_alt = math.min(inp.alt, tables.ga.alt[#tables.ga.alt])
    -- (2026-11-24, ENG-2) the P&W's (not the RB211's) takeoff rating while
    -- the thrust limit is a takeoff's: the FPPM's Takeoff EPR at the OAT
    -- (FPPM p.44, p.22: the Max Takeoff EPR; TABLE.PW.to, also to 10,000
    -- ft), not the go-around table at the TAT (0.026 EPR over it on average).
    -- In the go-around and the other limits the go-around table's as before
    -- (the two are the same rating, PW_PPM p.196; which table at which mode
    -- change: estimate, so the TO reference stays under the maximum after
    -- the liftoff, where the TAT rises over the OAT)
    -- (2026-11-25, the RB211's rebuild) the RB211's own takeoff table on the
    -- P&W's scale (M.rr_to_table); before, the go-around table's (its own
    -- branches set its limits)
    local ga_t = tables.ga
    if inp.takeoff and inp.type ~= "GE" then
        local t = (inp.rr and M.rr_to_table()) or (not inp.rr and tables.to)
        if t then ga_t = t end
    end
    local ga = M.lookup(ga_t, ga_t == tables.ga and inp.tat or (inp.oat or inp.tat), ga_alt)
    local clb = M.lookup(tables.clb, inp.tat, inp.alt)
    -- (the FMC's step 9h1) the maximum continuous band: the table's, not
    -- under the maximum climb's, at every altitude. (2026-11-24, the
    -- 2026-11-23 review's ENG-6) on the CF6 too: FCOM p.379-381 (the 570's
    -- PI.23.1-23.3) has its Max Continuous %N1 above 18,000 ft (to 27,000 ft
    -- and over, p.380), against ATA70_80 p.208's maximum climb above
    -- 25,000 ft; the crew's FCOM taken, as the P&W's (see the top). The
    -- lever angle of the full-forward rating as before (35 degrees above
    -- 25,000 ft: estimate). Before, the CF6's band gone from 22,000 to
    -- 25,000 ft, so its CON reference stood over the maximum there
    local mct_share = 1
    local mct = (mct_share > 0 and to_share < 1) and M.lookup_mct(tables.mct, inp.tat, inp.alt, inp.kias) or nil
    -- (B2) the P&W's maximum continuous at every speed (its full-forward
    -- rating above the go-around table's 10,000 ft)
    local mct_pw = (inp.type ~= "GE" and inp.alt > ga_alt) and M.lookup_mct(tables.mct, inp.tat, inp.alt, inp.kias) or nil
    -- the alternate mode's schedule: the corner point rating, no bleed adjustments
    local altn_max = to_share * M.lookup_max(tables.ga, ga_alt) + (1 - to_share) * M.lookup_max(tables.clb, inp.alt)
    -- (B2) the P&W's full-forward rating at TLA_TO always; the alternate
    -- mode's line as before (tla_mix)
    local tla_mix = tla_full
    if inp.type ~= "GE" then tla_full = M.TLA_TO end
    local out = {max = {}, command = {}, altn = {}, lim_prot = {}, to_share = to_share, tla_full = tla_full,
        at_disconnect = false,
        -- (2026-11-04) the ALTN light, >ENG n CONTROL, >ENG CONTROLS
        altn_light = {}, control_alert = {}, controls_alert = false,
        -- (N19-ENG-05) the P&W's N1 mode: command and target in N1 (%)
        n1_mode = {}}
    -- (N19-ENG-05) the PW4000's alternate mode is its N1 mode (PW_ALTN)
    local pw_n1 = inp.type ~= "GE" and not inp.rr
    local altn_count, manual_count, degraded = 0, 0, 0
    for n = 1, 4 do
        local nai = inp.nai[n]
        local clb_n = clb + adjustment(tables.clb, inp, inp.alt, nai)
        local cont = clb_n
        if mct then
            cont = cont + mct_share * math.max(0, mct + adjustment(tables.mct, inp, inp.alt, nai) - cont)
        end
        local max
        if inp.type == "GE" then
            max = to_share * (ga + adjustment(tables.ga, inp, ga_alt, nai)) + (1 - to_share) * cont
        else
            -- (B2) the P&W's: the go-around's, above its table the higher
            -- of the table's held and the maximum continuous plus
            -- PW_MAX_OVER_MCT (estimate). (ENG-2) In a takeoff the FPPM's
            -- Takeoff EPR (ga_t)
            max = ga + adjustment(ga_t, inp, ga_alt, nai)
            if inp.alt > ga_alt then
                local mct_n = mct_pw and (mct_pw + adjustment(tables.mct, inp, inp.alt, nai)) or clb_n
                if inp.alt > M.PW_TO_ALT then
                    -- (N19-ENG-01) the maximum continuous (PW_PPM p.196)
                    max = math.max(mct_n, clb_n + M.PW_MCT_OVER_CLB)
                else
                    max = math.max(max, math.max(clb_n, mct_n) + M.PW_MAX_OVER_MCT)
                end
            end
        end
        local tla = clamp(inp.lever[n], 0, 1) * M.TLA_STOP
        local manual = inp.altn[n]
        local auto = inp.fail_altn[n] and not manual
        -- (N19-ENG-05) the P&W's N1 mode (PW_ALTN): an automatic reversion
        -- latched until the switch is used (PW_PPM p.198); the control
        -- starts again from X-Plane's throttle as the controlled value
        -- changes (EPR, N1)
        local n1m = nil
        if pw_n1 then
            local was = s.n1_mode[n]
            n1m = pw_n1_mode(s, inp, n, tla, dt)
            auto = n1m == "lock"
            if (was == nil) ~= (n1m == nil) then M.reset_thrust_control(s, n) end
        end
        local altn = manual or auto
        local top = max
        if n1m then
            -- (its N1 schedule: below)
        elseif manual then top = math.max(altn_max, max)
        elseif auto then
            -- (2026-11-04) the automatic (soft) reversion keeps the last
            -- valid schedule: the thrust does not change then, and the
            -- changes of the ambient are no longer followed (FCOM p.876-877;
            -- ATA70_80 p.204, p.207). Selecting ALTN makes it the hard one
            if s.soft_top[n] == nil then s.soft_top[n] = max end
            top = s.soft_top[n]
        end
        if not auto then s.soft_top[n], s.soft_clb[n] = nil, nil end
        if manual then manual_count = manual_count + 1 end
        -- the ALTN light: the alternate mode, for the GE's automatic one by
        -- the ECU's reversionary mode contact above 50 % N2 (ATA70_80
        -- p.202-203, p.245); (N19-ENG-05) the P&W's the same, its EEC's EPR
        -- MODE FAIL through the N2 > 50 % contact (PW_PPM p.199; before, at
        -- any N2: estimate); the RR's at any N2 (estimate)
        out.altn_light[n] = manual or (auto and ((inp.type ~= "GE" and not pw_n1) or inp.n2[n] > 50))
        -- >ENG n CONTROL: an EEC system fault, also the one that reverted it;
        -- inhibited in flight (FCOM p.899)
        local faulty = inp.fault[n] or inp.fail_altn[n]
        out.control_alert[n] = faulty and not inp.air
        if faulty then degraded = degraded + 1 end
        local idle = math.min(inp.idle[n], max)
        out.max[n] = max
        -- (B2) the lever's line (TLA_CLB's comment): the CF6's to the
        -- maximum climb N1 at the CLIMB position, then to the full-forward
        -- rating; the P&W's one line to its maximum EPR at TLA_TO. The
        -- crew's ALTN (the hard reversion: the corner point schedule): the
        -- P&W's single line as before, the CF6's the same knee with its
        -- CLIMB point raised by the corner point's excess over the rating
        -- (estimate: so ALTN never gives less than the normal mode at a
        -- lever, FCOM p.877); the automatic reversion keeps the CLIMB point
        -- with the rest of the last valid schedule. (N19-ENG-05) The P&W in
        -- its N1 mode: the N1 schedule less delta, not under its idle end
        -- (the RR's ALTN the single EPR line as before)
        if n1m then
            out.command[n] = math.max(M.pw_altn_n1(tla, inp.tat) - (s.n1_delta[n] or 0), M.pw_altn_n1(0, inp.tat))
        elseif manual and inp.type ~= "GE" then
            out.command[n] = idle + (top - idle) * clamp((tla - M.TLA_FLAT_IDLE) / (tla_mix - M.TLA_FLAT_IDLE), 0, 1)
        elseif manual then
            local c = math.max(math.min(clb_n + math.max(0, top - max), top), idle)
            if tla <= M.TLA_CLB then
                out.command[n] = idle + (c - idle) * clamp((tla - M.TLA_FLAT_IDLE) / (M.TLA_CLB - M.TLA_FLAT_IDLE), 0, 1)
            else
                out.command[n] = c + (top - c) * clamp((tla - M.TLA_CLB) / (M.TLA_TO - M.TLA_CLB), 0, 1)
            end
        elseif inp.type == "GE" then
            local cl = clb_n
            if auto then
                if s.soft_clb[n] == nil then s.soft_clb[n] = clb_n end
                cl = s.soft_clb[n]
            end
            local c = math.max(math.min(cl, top), idle)
            if tla <= M.TLA_CLB then
                out.command[n] = idle + (c - idle) * clamp((tla - M.TLA_FLAT_IDLE) / (M.TLA_CLB - M.TLA_FLAT_IDLE), 0, 1)
            else
                out.command[n] = c + (top - c) * clamp((tla - M.TLA_CLB) / (M.TLA_TO - M.TLA_CLB), 0, 1)
            end
        else
            -- (N19-ENG-04) the P&W's knee at its maximum climb (PW_TLA_CLB):
            -- the automatic reversion keeps that point as the CF6's
            local cl = clb_n
            if auto then
                if s.soft_clb[n] == nil then s.soft_clb[n] = clb_n end
                cl = s.soft_clb[n]
            end
            local c = math.max(math.min(cl, top), idle)
            if tla <= M.PW_TLA_CLB then
                out.command[n] = idle + (c - idle) * clamp((tla - M.TLA_FLAT_IDLE) / (M.PW_TLA_CLB - M.TLA_FLAT_IDLE), 0, 1)
            else
                out.command[n] = c + (top - c) * clamp((tla - M.PW_TLA_CLB) / (M.TLA_TO - M.PW_TLA_CLB), 0, 1)
            end
        end
        out.altn[n] = altn
        out.n1_mode[n] = n1m ~= nil
        if inp.type == "GE" then
            out.lim_prot[n] = altn and out.command[n] > max
        elseif n1m then
            -- (N19-ENG-05) the thrust approaching the maximum rating (FCOM
            -- p.900): the EPR measured, the command being N1
            out.lim_prot[n] = inp.actual[n] > max - M.LIM_PROT_EPR
        else
            out.lim_prot[n] = altn and out.command[n] > max - M.LIM_PROT_EPR
        end
        -- the A/T disconnects when an EEC goes to the alternate mode (FCOM p.877)
        if altn and not s.altn[n] then out.at_disconnect = true end
        s.altn[n] = altn
        if altn then altn_count = altn_count + 1 end
    end
    -- the A/T can be used again: GE with all four EECs selected to the
    -- alternate mode, P&W with all four back in the normal mode (FCOM p.877)
    if inp.type == "GE" then out.at_inhibit = altn_count > 0 and manual_count < 4
    else out.at_inhibit = altn_count > 0 end
    -- (2026-11-04) >ENG CONTROLS: three or four EECs degraded; inhibited in
    -- flight (FCOM p.899)
    out.controls_alert = degraded >= 3 and not inp.air
    overspeed(inp, out)
    idle_selection(s, inp, dt, out)
    return out
end

return M
