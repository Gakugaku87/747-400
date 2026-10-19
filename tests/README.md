# Lua regression tests

Run from the repository root with LuaJIT (Lua 5.1 semantics):

```sh
for test in tests/*_test.lua; do
    luajit "$test" || exit 1
done
```

`lua5.1` can replace `luajit`. Each suite runs in its own interpreter. No
X-Plane installation is needed for these tests.

The audit regressions load production Lua code with mocked simulator interfaces:

- `takeoff_profile_test.lua`: 100-KIAS departure reference, the V2 + 10 to
  V2 + 25 initial-climb band, acceleration/thrust-reduction boundaries,
  changing terrain, QNH/STD changes, rearming and airborne reload. Also runs the production
  VNAV speed state machine and thrust monitor together.
- `fmc_audit_integration_test.lua`: native LEGS altitude fields and MOD title;
  step advisory through early LNAV sequencing, optional FlyWithLua automation
  and the actual ALT-selector handler; planned and STEP TO steps kept at STEP
  SIZE 0; VNAV climb altitude intervention raising CRZ ALT, and an ALT push
  for a climb within 50 NM of T/D not beginning the descent; crew intervention
  and refused commands; the production ECON updater keeping the climb Mach,
  the CRZ page Mach and the cruise speed state on one ECON cruise Mach, with
  a selected cruise Mach preserved and DELETE restoring ECON, and the sensed
  headwind reaching the ECON targets only through its 60 s lag.
- `crz_alt_sync_test.lua`: CRZ ALT handed from the 747 to a mock native FMS -
  sent as FL330 above the transition altitude (18000 FT when the native value
  is unset) and in feet below it, nothing sent for CRZ ALT 0, a leftover
  native entry and INVALID ENTRY cleared before typing, a refused value kept
  in the 747 with `laminar/B747/fms/crzalt_sync_fault` and a delayed CDU
  message instead of being put back, 31237 accepted as FL312 without
  re-entry, the CDU CRZ ALT entry (33000, 330 or FL330) sent as FL330, CRZ
  ALT not deleted (DELETE gives INVALID DELETE, an empty press copies it to
  the scratchpad), and
  the cruise climb 2 s after the ALT push skipped when CRZ ALT is back at the
  level flown or T/D is within 50 NM.
- `takeoff_ref_thrust_reduction_test.lua`: the TAKEOFF REF THR REDUCTION
  field - the 1500 FT default from PERF FACTORS, flap entries ("FLAPS 5",
  "10", "F20"), height entries, rejected entries, blank-line-select recall,
  DELETE, and the FLAP/ACCEL HT field beside it.
- `takeoff_speeds_test.lua`: the takeoff speeds (B747_setV1VrV2 on the
  PMDG-derived tables) keep the FCOM's minimums - V1 not below VMCG, VR not
  below VRMIN nor VMCG, V2 then not below the V2 for that VR, V1 not above
  VR; the PW4056's VMCG/VRMIN by pressure altitude and actual OAT, lower
  with TO 1 / TO 2: at 233 t, flaps 20, sea level 121/124/144 (the tables'
  101/114/139), at 6,000 ft 10 C 113/116, at 40 C 117/120, and 310 t
  unchanged at 126/141.5/159.5 (6 of the 19 checks failed before); the
  V1 wind correction goes by the headwind component, between the table's
  rows and weights (310 t: +2 for a 20 kt headwind, -2.5 for a 10 kt
  tailwind; as the tailwind component on the wind speed -3 and +1).
- `vnav_clb_page_test.lua`: CLB page titles ("ACT ECON CLB" / "ACT 230KT CLB"),
  the ECON/SEL SPD label, the CAS/Mach speed pair, the blank SPD REST
  field, and the CRZ page titles ("ACT ECON CRZ" / "ACT M.801 CRZ") with the
  FMC-kept ECON cruise Mach.
- `vnav_speed_restriction_test.lua`: SPD REST on both the CLB and DES pages -
  the blank "---/-----" field skipping the restriction state, an entered
  restriction bringing it back and being left behind above it, the flap
  placard minus 5 kt limiting every descent target, the CDU pair entry,
  rejection and DELETE, and DELETE returning a selected climb CAS or cruise
  Mach to ECON.
- `afds_pitch_limits_test.lua`: the flight director's pitch target limits -
  down to -10 deg in VNAV PTH, V/S, G/S and ALT (it stopped at -3.5 deg,
  where the 747 flies level with flaps 20 at 210 kt), up to +10 and +15 deg.
- `afds_glideslope_test.lua`: the flight director's G/S law - the glide
  slope's V/S at the ground speed, corrected by 0.25 x the radio altitude fpm
  a dot (the deviation in feet), at least 75 near the ground, at most
  1,000 fpm - and the director every 0.2 s in G/S (VNAV PTH as before, also
  right after G/S).
- `afds_alt_capture_test.lua`: ALT capture and ALT hold in the production
  flight-director pitch code - a FLCH or V/S push outside the capture window
  surviving the update that still shows the old ALT FMA, an ALT HOLD push
  surviving a stale FLCH, V/S or VNAV SPD FMA, capture at the MCP altitude
  inside the window and at the current altitude otherwise, and the ALT hold
  vertical speed limited to 2000 fpm, and to 500 fpm when descending 15 kt
  fast (or near Vmax) or climbing 15 kt slow (or near Vmc), using recorded
  TST744L cases.
- `ap_knob_push_test.lua`: the production MCP speed-knob and ALT-selector
  push handlers when the release of the previous push never arrives (XTLua
  does not pass the end phase of a command fired once): every push acts -
  the second speed-knob push ends the VNAV speed intervention and the second
  ALT push makes the new CRZ ALT and schedules the cruise climb - and with
  the releases the knobs go back out; and the VR controls' "use" click on
  those knobs (B747.99.VRcontrols.lua) as one held push: the speed
  intervention opens once, the ALT push waits for the scheduled cruise climb,
  and the knob goes out on the release even when the view has moved to
  another knob.
- `ap_pitch_loop_test.lua`: the AP pitch servo loop (ap_pitch_assist: the
  pitch PID with the gains flight_start sets, its altitude schedule and rate
  limit, and the stab trim) flying a longitudinal model fitted to the kit's
  2026-10-10 circuits (flaps 20 polar at 155 kt, pitch moment fitted to the
  recorded elevator, alpha and pitch rate at flaps 20 and 5), with
  flight_controls_override's 2 s before the command is applied - CMD 4.3 deg
  below the flight director as at the circuit's hand-off: no integral wind-up
  in the 2 s, no near-full nose-up command, a bounded overshoot; a 1 deg
  flight-director step with the AP on at flaps 20 and 5: no hunt (at most 4
  turning points beyond 5 % of the step, at most 10 % below it after the
  first overshoot); and AUTOLAND keeping the flare's 0.0002 derivative.
- `fpm_bias_test.lua`: the flap-movement vertical-speed bias of the flight
  director with the production interpolation and a 44 fps frame period - no
  bias at the first ALT/VNAV PTH update after a fresh load with flaps out, nor
  for handle moves made while the director did not run (a pause, or below
  3,000 ft RA), no bias carried across a pause, the pitch target at the
  recorded 10,000 ft capture with flaps 20, and the designed bias for a
  handle move above 3,000 ft RA in ALT hold and in a steady V/S (whose
  director updates come 1.0 s apart, driven at the frame rate).
- `hydraulics_dataref_binding_test.lua`: every `simDR_`/`B747DR_` name that the
  hydraulics override file writes is bound in the hydraulics script's XTLua
  namespace, with the FLCH and V/S requests bound to the datarefs the
  autopilot reads and the angle of attack, true airspeed and bank that the
  speed-on-pitch climb guard reads bound to X-Plane's.
- `vnav_ground_arm_test.lua`: VNAV pressed on the ground before the flight
  directors (and in TO/GA) only arms - no ALT HOLD, a stale MCP altitude hold
  and VNAV descent cleared - so the thrust monitor keeps TO/GA, engine TO/GA
  and the takeoff phase; an MCP altitude near the field is not captured as
  VNAV ALT on the ground or below 400 ft RA; LNAV ground arm, the airborne
  engage and the PERF/VNAV UNAVAILABLE refusal unchanged; and the VNAV button
  decision table.
- `vnav_route_eod_test.lua`: a route that starts and ends at the same
  airport - the end of descent on the arrival side (after the fix farthest
  from the airport, not at the departure fixes), the remaining distance and
  T/D on the ground, in cruise and on final, the VNAV path into the first
  descent constraint starting from CRZ ALT at the T/D (also once the T/D is
  behind), and VNAV climb targets judged by the along-route distance so the
  arrival constraints are not climbed to. Ordinary routes keep their end of
  descent and climb targets. On every route the T/D reaches each descent
  constraint (its altitude through its CIFP constraint: an IAF's 3000 above
  an at or below 2500 moves the T/D 1.7 nm out) and the end of descent
  altitude (its route altitude or the
  destination elevation, not the navaid frequency in [3]) at 290 ft/nm, so
  the path into the IAF is 290 ft/nm; route altitudes before the T/D (an older
  CRZ ALT) and SID constraints nearer the departure are not descent
  constraints, and the T/D stays put as the constraints are passed. The
  remaining distance ends at the end of descent and then runs straight to the
  destination, without the leg after the end of descent, also with a missed
  approach whose vectors point X-Plane puts hundreds of NM away (left out
  after the arrival runway; the runway is known by its name, RW and two
  digits, so a fix named RW... is no runway). A SID's altitude-terminated
  leg end ("(650)") is climbed through, not taken as the climb target.
- `lnav_altitude_leg_test.lua`: the production waypoint sequencing at the end
  of an altitude-terminated leg (CA, VA, FA: X-Plane's "(650)", which rides
  just ahead of the aircraft once its altitude is reached) - the next leg
  becomes active above the altitude (also when it is long passed), not below
  it nor on the ground nor below 400 ft above it (a misset altimeter), and
  only a name that is an altitude counts; the ENDE3J departure flown for 10
  minutes, the legs after "(650)" sequenced in order to ENDEQ whether X-Plane
  keeps that point moving with the aircraft or leaves it behind, and whether
  650 ft comes before or after DE28R (or DE28R is still active 2 NM past it
  at 3,000 ft); a SID turning back after its CA leg, and two altitude legs in
  a row, sequenced in order too; and EHAM 18R's runway kept on final above
  the missed approach's 500 ft, AM624 next on a go-around past the threshold.
- `approach_capture_test.lua`: the APP switch, APP arming and approach monitor
  together - LOC capturing only within 2.0 dots while closing (or settled
  within 1.0 dot) on an intercept of 90 degrees or less, a saturated or
  diverging LOC staying armed, a previously captured LOC recapturing at once,
  G/S capturing only after LOC with LOC and G/S both within 1.5 dots and
  never in the LOC capture frame, APP leaving the MCP heading alone, and LNAV
  still steering (and reselecting the heading mode) while LOC is armed.
- `eec_climb_thrust_test.lua`: the CLB thrust reference of the GE, PW and RR
  EEC modules is the rated climb thrust at every altitude, weight and flap
  setting, as on the 747-400 (the thrust for the EEC's design climb rate,
  taken below 20,000 ft where it was less, left a light 747 at 1,560 fpm at
  10,000 ft and 250 kt; 46 of the 62 checks failed before): the PW's max
  climb EPR is raised below its 340 kt / M.84 schedule up to its value at
  200 KIAS, linear in Mach - below 11,000 ft the FCOM's Initial Climb
  table's (1.49 at 10,000 ft on the cold side, 1.43 at 20 C, 1.35 at
  30 C; at 0.6 EPR per Mach warm days ran up to 0.15 over it), above
  12,000 ft 0.6 EPR per Mach kept to the table's warm-day share at its
  10,000 ft row for the same ISA deviation (15,000 ft, 250 KIAS: 1.453 at
  ISA, 1.425 at ISA+20, max climb at ISA+40; 0.03-0.15 over before), held
  to 1.64 (M.81 at 35,000 ft gave 1.66), the table's 1.7 at
  15 C and 8,000 ft read as 1.47 - and CLB 1 and CLB 2 take 10 and 20 % off
  the climb thrust to 10,000 ft and give it back by 15,000 ft: the PW and
  RR as their EPR above 1 (CLB 1 about 0.04 EPR less, as crews see it), the
  GE as N1 to the 1/3.1 power of the thrust kept, the EEC's N1 model (to
  the 0.4 power the thrust was 12-13 % less for CLB 1).
- `xtlua_warm_reads_test.lua`: XTLua gives 0 for the first read of a
  dataref in a script module, so the datarefs that a fix first reads at a
  critical moment are read every frame in the module's per-frame function
  (the "local refresh...=" reads): the native transition altitude and the CRZ
  ALT sync fault flag in the FMS after_physics, and the localizer and
  glideslope signals, flags and deviations of the LOC and G/S capture gates in
  the autopilot monitor (B747_monitorAP), the flight-path vertical speed
  and pitch rate of the autoland flare law in preLand_measure (every frame
  from 800 ft down to the flare height), the flap handle of the flight
  director's flap-change VS bias and the autoland pitch target in the
  hydraulics ap_pitch_assist, and the ground track, true heading, TAS, ground
  speed and bank limits of LNAV's fly-by turn anticipation in the autopilot
  after_physics.
- `autoland_flare_test.lua`: the autoland flare law helpers (flare height,
  sink-rate command, pitch-target size and rate limits, pitch-rate damping,
  the approach pitch when no steady sample was taken, derotation at 1 deg/s
  to -0.5 deg) and the production autoland logic flown from 300 ft RA to 8 s
  after touchdown against a point-mass model fitted to the kit's recordings
  of the 2026-10-10 circuits (flaps 30 polar, ground effect, the thrust
  spooling down after the retard, the VSI lagging the flight path by 1.2 s,
  and the attitude following the autoland target through the lightly
  damped, delayed AFDS pitch loop: damping 0.15, 0.8 rad/s, 0.8 s, and three
  other loops) - 220, 257 and 300 t on level ground and on ground falling
  25 ft under the flare as at EINN 06, a noisy VSI, noise on the law's own
  inputs (local_vy and Q, frame to frame and at 0.7 and 1.1 Hz), the vertical
  speed reading 0 at flare entry (XTLua's first read, seen in X-Plane) and a
  second autoland in the same session, judged as the flight-test kit judges
  a landing: touchdown VSI -300 fpm or less (and not a skim), float at most
  0.5 s, FLARE to touchdown within 11 s, touchdown within 900 m of the FLARE
  point, no climb in the flare (20 fpm and 0.5 s more room for the other
  loops), no nose-down before main gear touchdown, a rate-limited
  derotation, and A/T IDLE no higher than 25 ft.
- `mcp_alt_dial_test.lua`: the MCP altitude knob while it is dialled (item
  B-12), the production knob, VNAV, FMA, approach modes and pitch director
  in `mcp_alt_dial_model.lua`'s closed loop at the kit's 0.079 s a click -
  the knob writes no lastCommand; a VNAV or FLCH climb dialled up does not
  level at a passing altitude; T/D in a dial starts the descent at T/D;
  VNAV PTH's V/S target keeps changing in a dial; G/S captures on time; a
  V/S stop at 10,000 does not take the old 11,000; and guards: a stop climb
  (VNAV and FLCH, three cadences) and a stop descent level at the final
  value, ALT HOLD and VNAV ALT unchanged, T/D after a first click and a
  pause still descends.
- `eec_flare_retard_test.lua`: EEC IDLE in the autoland flare - no low-speed
  thrust recovery below 50 ft RA, the retard from approach thrust to idle
  over about 2 s, and the IDLE low-speed recovery kept outside the autoland
  flare.
- `eec_takeoff_thrust_test.lua`: the A/T setting takeoff thrust (THR REF on
  the takeoff roll) - PW from EPR 1.10 within 8 s at 20, 30 and 60 fps alike
  and without overshoot, from idle within 12 s (before HOLD at 65 kt), GE
  from 70% N1 within 8 s; from levers at 0.60, also after a landing that left
  the A/T at idle, no step back before takeoff thrust (the A/T's target from
  the levers when it takes them). A go-around in flight from approach thrust:
  GA thrust within 6 s at 20, 30, 45 and 60 fps alike (11.0 / 8.5 / 5.3 /
  5.4 s when the levers went the last step by a tenth of the way a frame).
- `afds_responsiveness_test.lua`: the AFDS helper calculations (turn
  anticipation, VNAV speed change reasons, VNAV energy guidance, pitch blend
  and roll filters) and the speed-on-pitch limiter - the severe underspeed
  threshold with the minimum safe speed capped at target - 5 kt, so an
  initial climb on V2 + 10 kt with takeoff flaps (Vmc + 10 kt above it)
  keeps the climb guard and only a real underspeed may pitch down; and the
  acceleration latch for a raised speed target (flap retraction, 250 to the
  ECON climb speed at 10,000 ft), which keeps the climb guard until the speed
  is within 5 kt of the target, also in the production flight director, while
  a real underspeed below the minimum safe speed is never latched, and a loss
  of 15 kt from the speed the acceleration started from counts as a severe
  underspeed while latched. Also the
  CAS to Mach conversion (the inverse of the FMC Mach to CAS) and the climb
  CAS/Mach crossover rule.
- `vnav_climb_speed_semantics_test.lua`: the climb speed states (SPD REST,
  SPD TRANS, ECON CLB), the crossover to the climb Mach judged on the CAS
  target at the current altitude (a climb through FL310 flies M.815 instead
  of a 326 kt target 26 kt above the speed, and does not flip between CAS
  and Mach as the Mach changes), and the cruise state flying the FMC cruise
  Mach, also through a step climb from the cruise phase (FL310 to FL330 at
  M.810, not the climb Mach .836) until the descent or the ground ends that
  phase, and after a descent in FLCH in cruise from 500 ft below the level
  the cruise was flown at (below it that Mach's CAS there: 301 kt for .810
  at FL310, not .810 at 342 KCAS at FL250; the change-over a boundary of
  VNAV's per-frame update; that CAS capped as the climb's own: 250 kt below
  10,000 ft, 301 from 10,100 ft, 270 under a 270 kt constraint); but ended
  even with VNAV off
  on the approach, in TOGA and below the transition altitude (a go-around
  climb in VNAV at 3,000 ft at 250 and 245 kt, not .81 or a stale 180 kt;
  the G/S and TOGA each alone above a transition altitude of 3,000 ft),
  and never entered with CRZ ALT deleted (326 kt at FL205 after deleting and
  entering it again). Every climb and descent speed state, the MCP IAS/MACH
  button and the
  automatic IAS/Mach changeover write the X-Plane autopilot target in the new
  unit together with the speed mode (a Mach target limited to Mmo - 0.01, a
  knots target converted to Mach at the current altitude by the button and
  the changeover), instead of leaving the old value in the new unit until
  the 0.25 s IAS update; the button and the changeover do so from the speed
  and unit they decide, also when the last-airspeed and is-Mach datarefs
  read back their old values in that frame.
- `afds_fma_none_pitch_memory_test.lua`: the production flight-director
  pitch target while no pitch mode is active (the FMA shows NONE for about
  0.5 s after an ALT selector push), using the recorded TST744L step climb -
  the attitude is held (limited to -3.5..15 degrees) instead of 0 degrees,
  so the following VNAV SPD, and VNAV PTH holding the altitude, continue from
  it.
- `vnav_climb_acceleration_test.lua`: the production flight director (from its
  pitch records through the 10-sample pitch integral) flying a simple
  point-mass climb model fitted to the X-Plane forces, alpha and
  flight-director pitch of a 2026-10-10 takeoff (flaps 20 polar, climb thrust
  against air density, a lightly damped attitude loop): the 156 to 182 kt VNAV
  target rise at the 1,500 ft acceleration height with flaps 20 is reached
  within 90 s keeping more than +1,000 fpm; with the kit's flap retraction the
  flaps are up below 6,500 ft and 250 kt is not passed by more than 6 kt; the
  250 to 326 kt rise at 10,000 ft is reached within 150 s without descending;
  the same with slower, more oscillatory or faster attitude loops and 15 %
  less or more thrust; and a step climb from FL330 with the M .829 target
  above M .816 (clean polar and thrust fitted above FL250 to the 2026-10-10
  TST744L flight, the fitted attitude loop) without descending, the attitude
  within 2 deg and the target reached within 120 s; and thrust lost 5 s into a
  step at FL310 (still accelerating to the raised target): the speed is not
  run down to the minimum safe speed (the climb guard held the aircraft up to
  202 kt) but kept above 265 kt and settles above 285 kt. Also the climb speed
  pitch step itself (the acceleration wanted, its band, the rate limit, the
  attitude interlock, the climb floor, and no change within 2 kt, level or
  descending). And a step climb from FL310 that starts in a 20 deg bank turn
  at a waypoint (the 2026-10-10 final-L1 step 1, with polar, thrust and
  attitude loop fitted to it and a short roll-spoiler lift loss): held at or
  above the attitude that flies level at the angle of attack once the VSI
  shows +100 fpm or less, it neither descends below -200 fpm nor zooms above
  +2,000 fpm, the attitude stays within 2 deg and no speed is lost (the
  VSI-driven guard: -550..+5,031 fpm, down to 280 kt); with the other attitude
  loops and 15 % less or more thrust within -200..+2,500 fpm, 2.5 deg and 5 kt
  of the starting speed. Climbs that thrust limits: into the thrust-limited
  ceiling the climb stops on speed (also while accelerating to a raised
  target), and an engine failure in the step neither zooms nor falls below 287
  kt. And that level attitude, its use by limit_speed_pitch_target and the
  bank the director passes to it.
- `engines_reverse_hold_test.lua`: the all-engine reverse-hold command, its
  reverse monitor and the auto-stow timers run frame by frame - releasing a
  hold of 0.5 s or more returns to reverse idle at once (fast or below
  65 KIAS), a shorter tap keeps full reverse latched, the timers still select
  reverse idle 5 s and stow 8 s after 65 KIAS (after the release when already
  slower), and a hold that never deployed (reverser lockout in the air) leaves
  the levers alone on release.
- `vnav_speedbrake_thrust_test.lua`: VNAV PTH energy thrust high on the path
  with pitch recovery limited - thrust allowed for the limited recovery stays
  in SPD until the limit clears or the speed is high, instead of switching
  IDLE/SPD with the speed trend; with the speedbrake beyond ARM (lever 0.15
  and up, not 0.125) the A/T holds IDLE (reason 5, speedbrake hold) until
  underspeed protection, whose thrust is then kept while the limit lasts;
  DRAG REQUIRED unchanged. Also runs the production `setDescentVSpeed`
  loaded through the XTLua `dofile`.
- `vnav_descent_thrust_hold_test.lua`: VNAV PTH descent thrust for a slow
  speed on or below the path kept until the speed is 2 kt past the target
  or the aircraft is above the path - a path idle cannot hold the speed on
  changes the A/T once (to SPD, 30 times in 300 s before) with the speed on
  the target; on a path steep enough at idle the thrust ends.
- `vnav_descent_thrust_hold_test.lua` D4: with the A/T's own speed loop, which
  overshoots, the thrust for a slow speed is released only with the levers at
  idle and the speed not falling (on a path idle cannot hold, SPD stays: at
  most 1 change in 600 s, at least 3 released at +2 kt alone).
- `vnav_descent_thrust_hold_test.lua` D5: the production vnav.lua with the
  EEC's speed law and engines fitted to p23-line1's spool-down (N1 down with
  a time constant of 35 s): the thrust for a slow speed is released only once
  X-Plane's N1 has stopped falling at idle (on paths 0.15-0.55 kt/s slower
  at idle, at most 1 change in 900 s: 14 and 3 with the levers at idle alone).
  D6: after a short SPD burst, with the levers at idle, the speed rising and
  X-Plane's N1 still falling, SPD stays though the EEC's display N1 sits flat
  (read from the display, the thrust ended 5 s after idle); with X-Plane's N1
  steady at idle the thrust ends.
- `vnav_descent_path_test.lua`: VNAV PTH's descent between the route's points
  follows the path (within 100 ft, mean within 40 ft, on the EHAM route from
  15 nm before LAMSO: it sat 150-225 ft below it aiming 250 ft below each
  point), and the vertical bearing is from the aircraft; approach_model.lua's
  closed loop.
- `vnav_descent_point_test.lua`: VNAV PTH's V/S in the last nm before a point
  of the FMC's profile is the path's own (within 15 %, on the path at 400 kt:
  it fell to -177 of -1,773 fpm at 0.1 nm) and steeper with the 747 100 ft
  above the path; the production setDescentVSpeed and energy mode.
- `vnav_descent_at_hold_test.lua`: the A/T's FMA in an idle VNAV PTH descent -
  IDLE while the levers come back, HOLD once they are at idle (only after
  IDLE), SPD when VNAV allows thrust; in that HOLD a pilot's lever movement
  stays (HOLD while VNAV wants idle; a HOLD from before the descent with the
  levers up goes IDLE first); the production `B747_ap_fma` through
  approach_model.lua's loader.
- `afds_toga_roll_test.lua`: the TO/GA roll annunciation - HDG SEL, HDG HOLD
  or LNAV in flight replacing TO/GA roll while TO/GA pitch stays, the roll
  FMA going straight from TO/GA to HDG SEL frame by frame, LOC capture,
  an airborne TO/GA press or TO/GA engaged again bringing TO/GA roll back
  (a press just before HDG SEL does not undo HDG SEL), and nothing being
  remembered on the ground: a HDG SEL press before liftoff, LNAV left
  active from the last flight, or a selection that outlived the landing; and
  LNAV armed in flight (LNAV ARM) under HDG SEL or HDG HOLD, which stays the
  active roll mode with LNAV armed (X-Plane's heading select left alone in HDG
  HOLD), as on the ground before, and the heading knob setting X-Plane's
  heading with APP armed while LNAV is only armed, not while it steers.
- `yaw_damper_test.lua`: the yaw dampers (item B-10) driven frame by frame
  through the production flight_controls_override with a Dutch-roll-like
  yaw motion wings level and at +-19 deg of bank (p9-L1's 5.1 s, yaw rate
  +-2.4 deg/s), a roll-in through 5 deg of bank and a steady 20 deg turn
  (the yaw rate X-Plane's body axes', g sin(bank) / TAS in a coordinated
  turn): the output opposes the yaw rate both ways at every bank, does not
  jump as the bank crosses 5 deg, puts no rudder into a coordinated roll-in
  to 30 deg at 160 kt (within 0.03), also at an angle of attack of 6 deg
  (the roll about the flight path, X-Plane's body axes yawing by its rate
  times sin(alpha)), keeps none on the ground (taxi turns
  of 1-5 deg/s at 15 kt, a heading correction on the takeoff roll at
  120 kt), fades out in the steady turn, stays a number within +-1 through
  a yaw rate that is NaN or infinite (either sign) for a frame and acts
  again after it, moves the rudder alike at 45, 50 and 60 fps through
  X-Plane's chain (the same output at 20 and 30 fps, where the chain leaves
  the law no lag of its own) and stays within +-1, both dampers alike; and in a Dutch
  roll model (5.1 s, bare damping 0.03, rudder effect 0.2-0.6 rad/s2 per
  rad) three cycles take 2 deg of sideslip below 35 % with the dampers and
  leave it above 70 % without. The 747's law (P25, NASA CR-2144 Fig IX-4):
  1.37 deg of rudder per deg/s of yaw rate at 0.9 rad/s within 10 % of 1.23
  flaps up at 180, 300 and 350 kt, twice that with the flaps out, and +-4 deg
  of rudder command per damper not scaled by the rudder ratio. Through
  X-Plane's chain to the rudder (the control override rows, pressure_input,
  pressure_output's tenth of the way a frame: 11 frames) the rudder per deg/s
  and its phase are CR-2144's law's (1.23, 8.5 deg ahead of the yaw rate)
  within 5 % and 2 deg at 45, 50 and 60 fps, and 7 deg at 30 fps (review 23).
- `afds_roll_rate_limit_test.lua`: the roll rate of HDG SEL and LNAV turns -
  the filtered roll command moving at most 3 deg/s outside the approach at
  20, 30 and 60 fps (a roll-in, a 6 deg change, a reversal and a roll-out),
  the approach keeping its 8 deg/s; and X-Plane's HDG SEL with the production
  filter and the bank response, both fitted to the kit's 2026-10-11
  recordings (FL310 and 5,000 ft), flying heading changes of 5, 20 and 90 deg
  and a +/-60 deg reversal within 4.5 deg/s (1 s mean), 1 deg of heading
  overshoot and a time bound.
- `lnav_turn_anticipation_test.lua`: LNAV fly-by turns - the anticipation
  (the arc at the bank limit, half the 3 deg/s roll-in, and in wind where the
  drifting turn ends on the outbound leg; beyond 150 deg a 150 deg turn's,
  nothing from 175 deg or with an implausible wind), and the production
  sequencing, LNAV steering and roll
  filter flying a lateral model fitted to the kit's 2026-10-11 recordings:
  EIDW's DW129 (+90 deg), EHAM's NETOM to AM608, TST744L's BEDRA and BILTO in
  a 96 kt wind and ELPOM, and 15-120 deg turns at 250 and 478 kt, each within
  0.3-0.4 nm of the fly-by path (1 nm for BILTO's 137 deg downwind), the fixes
  in order; and no anticipation from the origin airport, before a lat/lon point
  or VECTORS, more than 2 nm off the leg or after a direct-to; a turn LNAV
  flies by its path (item i-1b) sequenced at its bisector instead (one frame
  before and past it; BILTO's 137 deg at FL350 in a 355/96 wind from 58 nm out
  and 130 deg at 480 kt in a 040/90 wind, which the lead never sequenced), and
  a fix listed twice in a row (one turn, in order, at 250 and 480 kt), no
  bank below 400 ft after lift-off with a SID's turn 1.5 nm on, BEDRA in the
  westerly passed within 4.5 nm, the 747's own DIRECT TO flown direct to its
  fix (passed within 1 nm) after the steering's reset of the target, and the
  turns at the end of legs LNAV steers as before (DW129 after "(650)", a fix's
  turn after one flown direct from VECTORS) anticipated by the lead, within
  0.4 nm; on a leg flown by the path LNAV's heading mode following the fix
  flown to and UNABLE RNP set 1.5 nm off a leg near the destination (0.4 nm
  with APP armed), from the path's cross-track (none on a fly-by arc 0.59 nm
  inside the leg); and two turns the same way at the ends of a short leg
  turned the right way round (their arcs sharing the leg), but a 120 deg turn
  whose next fix, a short leg on, turns 2 deg keeping its arc (within 0.4 nm
  of the leg after it at 250 kt, 1 nm at 480 kt); and a 90 deg turn 10-15 nm
  after a turn-back entered rolling its way, no farther outside the leg after
  it than before i-1b (170 deg with 10 nm on passed abeam, its fly-by path not
  fitting before the 90 deg turn's arc, the leg between steered as before and
  the 747 not on it: 0.6 nm; 165 deg with 15 nm flown by: 0.1 nm), while a 747
  established on such a leg (from VECTORS)
  flies the next fix's arc from the hand-over also 0.4 nm into it in 000/40,
  0.5 nm off the leg the next leg's path, decided again when that fix is
  sequenced again after the one before was flown to. Turns of more than
  150 deg (item P15) flown by from where a 150 deg turn starts, on round the
  arc by up to 45 deg past the outbound course and back onto the outbound
  leg: 170 and -165 deg at 200 kt at most 0.4 nm farther outside the next leg
  than the path (2.18 and 1.64 nm; passed abeam 3.22 and 3.21), a 178 deg
  reversal passed abeam as before; 160, 170 and -170 deg at 480 kt and 165 deg
  in 270/96 turning from the path's start (34 and 50 nm before the fix),
  within 0.5 nm of the path, no farther outside the outbound leg than it
  (6.2-13.3 nm; passed abeam 18.1-24.3) and on that leg after the path joins
  it, the fixes in order; LNAV pushed 1 nm before a +165 deg fix at 250 kt
  after HDG SEL flew on past the turn's start, the turn passed abeam as before
  (at most 260 deg of turning and one bank reversal; round the path from there
  514-595 deg). Such a turn decided once as the 747 comes to the path's start:
  LNAV armed 1.5 nm inside the leg into +170 and +174 deg fixes 14 and 20 nm
  before them sequenced where the path crosses the bisector (6-9 nm before
  them), the path's fit at a TAS hunting 250 +-1.5 kt decided once (no bank
  reversal beyond 10 deg but the path's), the turn after a leg steered as
  before passed abeam (within 1 nm), and decided again once the 747 is back
  on the leg before the start with LNAV (flown, sequenced 6-9 nm before the
  fix); turns of 150 to about 159 deg, without a straight line between the
  arcs (+150.5, +153 and -158 deg at 250 kt), flown round without circling,
  also in head and tail winds (+153 and -151 deg at 250 kt with 80 kt behind,
  +150.1 deg at 480 kt with 100 kt ahead);
  a turn decided flown passed abeam once LNAV is let go past its start
  and the 747 is more than 2 nm off the path (pushed again 3 nm before the
  fix: 286 deg of turning, not 617; let go for 5 s 20 s into the path: on
  round it, the fix sequenced 7.7 nm before it);
  the decisions forgotten when the active fix moves back (put back 10 nm
  before a fix flown by: sequenced at the bisector, not in that frame);
  a capped turn's path sharing no leg with the arc before it until decided
  flown (+90 then +170 deg 38 nm on at 480 kt: 20 deg of bank held through
  the first turn, not down to -7.4);
  VNAV's held fix let go with its sequencing also at +174.6 deg (within
  5 s; kept until 13 nm past the fix while its bisector was taken abeam it).
  LNAV's wind filtered (item P18): TST744L's BILTO at FL350 with the nose
  swinging 0.3 deg off the air path at 3.5 s, the heading command within
  0.5 deg of its 10 s mean and the bank within 0.6 (4.8 and 2.6 with the wind
  taken frame by frame).
  The wind taken along the air path (the nose less beta cos(bank) + alpha
  sin(bank)): BILTO with an angle of attack of 2.65 deg 0.04 nm outside the
  path and 70 s at the bank limit (0.37 nm and 125 s along the nose).
  LNAV steering on through AP commands: BEDRA at FL310 with two commands
  0.55 s apart in the arc flies as without them (the heading command and the
  bank within 0.01 deg; 0.30 and 0.58 deg with the steering held 0.5 s after
  each). With X-Plane's HDG SEL off for 2 s in the arc, HDG SEL is sent at
  most once in 0.5 s and the heading command moves every frame.
  A turn's radius fixed where its arc starts (item P21): BILTO at FL350 with
  the TAS falling 11 kt through the turn at most 0.10 nm outside the path and
  30 s at the bank limit (0.14 nm and 98 s with the radius drawn every frame).
  BILTO listed twice, the same (2.44 nm and 118 s when the radius was let go
  at the duplicate). A turn accelerating from 230 kt to the target 280: at most
  0.10 nm outside and 25 s at the bank limit (0.39 nm and 59 s drawn for the
  TAS at the arc's start). Two 90 deg turns 6 nm apart with the target stepping
  from 250 to 325 kt in the first arc: at most 0.10 nm outside in it (0.32 nm
  when the share of the leg followed the next arc).
  LNAV's path guidance on the model: within 0.1 nm of the leg to DW124 90 and
  120 s after DW129, and back on a leg from 1, 3 and 10 nm off within 60, 120
  and 300 s at most 45 deg to it and not 0.2 nm through it. LNAV ARM: LNAV
  pushed 20 nm off a leg on a parallel heading still armed after 10 min on that
  heading; on 45 and 90 deg towards it engaged where the turn onto it begins
  (2.7-3.3 and 9.4-10 nm off at 480 kt) and onto it within 0.2 nm; 1 nm off
  engaged at once, also 1 nm off its line 10 nm before the leg's start; 85 deg
  towards its line 1 nm before its start as 1 nm past it (8.9 nm off) and onto
  it, 20 nm before its start also where the turn begins and onto the line;
  45 deg towards it crossing it 6 nm before its start 3.0 nm off and onto it,
  crossing it 1 nm past the active fix only 2.5 nm off (1 nm before it 3.0 nm
  off); 1 nm past a fly-by fix flown through in HDG SEL at once and onto the
  next leg, 12 nm off a leg 1 nm past its start at 90 deg towards it and 1 nm
  beside the leg into its start (that fix sequenced while LNAV was not engaged)
  onto the leg, not round that fix's arc, as also parallel to the leg into a
  +30 deg fix 2.6 nm inside at 480 kt, engaging as that fix is sequenced
  abeam (at most 0.1 nm through the leg after it, 45 deg of turning), and
  5 nm before a fix (480 kt, 1.5 nm
  off the leg to it, HDG SEL 000 or 345; not sequenced at its turn's lead, LNAV
  not engaged) at the push, as LNAV engaging at once flies it, but with that
  fix sequenced 10 nm past it on the line of the leg to it, flying away from
  the next leg, and 10 and 20 nm before it on that leg flying away, still armed
  (20 nm before it flying towards it engaged where the turn onto the next leg's
  line begins, 9.7 nm before it); at a dogleg's FIX (+90 deg onto a 3 nm leg,
  -90 deg at NEXT, 480 kt, NEXT not sequenced) engaged at the push and onto the
  leg after NEXT; at once on a leg flown direct (from VECTORS) or after the
  747's own DIRECT TO; armed on the runway, engaged above 50 ft, also 1 nm
  before the leg's start (armed on the ground for the takeoff). While LNAV is
  not engaged (off or armed) the active fix sequenced abeam it, past the
  perpendicular to its leg at the fix, within 21 nm of the leg: along the leg
  at the fix, 15 nm off abeam it and 25 nm off never (480 kt, +90 deg at the
  fix, its lead 9.7 nm); a leg flown direct to its fix
  (from VECTORS) from where the 747 was when the fix became active, so a fix
  passed 1.2 nm off is sequenced abeam it (not only within 0.3 or 0.5 nm),
  that start noted with the fix (again when a route edit puts another fix at
  the active index) and not at 0/0 (XTLua's first read after a reload).
- `lnav_xtk_error_test.lua`: LNAV's cross-track error every frame - the signed
  distance from the active leg (+ right) mid-leg on both sides and near its
  end, from the offset track while an offset is flown (not after a
  direct-to), from the fix before an altitude leg's end, from PPOS on native
  sequencing, 0 without a leg, and in a fly-by turn from its arc (the path
  LNAV flies) on it and outside it, but with LNAV off or armed past the
  turn's bisector before the fix is sequenced abeam from the leg to it (LNAV
  engaged: the fix sequenced, from its arc; 3.1 nm inside the arc the fix
  still active, from its arc); and PROGRESS page 2 showing L or R and the
  distance.
- `lnav_path_geometry_test.lua`: the lateral path at a fly-by fix for LNAV's
  path guidance (item i-1b) - the arc tangent to both legs R tan(turn / 2)
  from the fix, the element abeam the aircraft, the signed cross-track from
  the legs and from the arc (the fix outside it, a point inside it), the
  path's course, and the pure-pursuit aim point along the leg, round the arc
  and onto the next leg, at most 45 deg off a leg; 90 deg turns both ways, no
  turn, 150 deg, past turns of 120 and 150 deg the outbound leg (behind the
  arc's start in the inbound leg's frame: the turn's bisector parts the two
  legs' sides), whether the aircraft is past the bisector, the ground speed
  an arc is drawn for (the highest the wind gives across the turn), a capture
  look-ahead on the legs (the aim waiting at the arc's start until the
  look-ahead reaches it), and no path without a radius, courses or a
  look-ahead, or for a reversal (175 deg or more). Beyond 150 deg (item P15)
  the turn starting R tan(75) before the fix, where a 150 deg turn starts:
  for 170 deg R (1 - cos 170) - R tan(75) sin 170 outside the outbound leg on
  its course, 45 deg on, the straight line closing on the leg and where the
  path joins it, on the first arc, on the straight line and on the leg after
  it (cross-track, course, along), the left turn mirrored, 151 deg turning on
  just enough and back at once, and how far before and after the fix the
  path leaves and joins the legs; the element moving on only from the
  caller's last one (0.9 nm inside the inbound leg 10 nm before a 170 deg fix
  the inbound leg and not past the bisector, 1 nm inside the straight line
  not back to the inbound leg; just past the first arc's end of a 150.1 deg
  turn, which has no straight line, on at any radius) and the bisector the
  path's (where the first arc crosses the bisector line, 44 deg round it
  for 170 deg).
- `vnav_turn_hold_test.lua`: a fix LNAV sequences early for its turn keeping
  its altitude as VNAV's descent floor until the aircraft is past the turn's
  bisector - the bisector for straight fixes, 65-137 deg turns both ways and
  a reversal; EHAM's NIRSI (at or above FL055, 5563 ft) in its 65 deg turn with
  the production LNAV and VNAV_NEXT_ALT, its leg flown direct (from VECTORS):
  held from the switch 1.6 nm before through the turn, AM607's 4272 past the
  bisector; and no hold below the fix's altitude, in the climb, after a jump of
  the active fix or one from afar, at a straight fix once abeam, when vectored
  away, or for an altitude leg's end or the origin. Flown by its path (item
  i-1b), NIRSI itself is sequenced at the bisector: its 5563 without a hold
  until there.
- `vnav_held_fix_path_test.lua`: a fix LNAV sequences early for its turn stays
  the next point of VNAV's descent path (setDistances' profile) until its
  bisector - 1 nm before NETOM with NIRSI active and NETOM held,
  setDescentVSpeed aims at NETOM's 7849 on the path (it aimed at NIRSI's 5563,
  180 ft above that path), and past the bisector at NIRSI's.
- `vnav_profile_constraints_test.lua`: VNAV's descent path (setDistances'
  profile) crosses each point inside its CIFP constraint - the native FMS's
  altitude raised to the floor (NETOM's 6800 to FL070), lowered to the
  ceiling (SUGOL's 15000 to its window's FL140, 9500 to FL100), and
  setDescentVSpeed aims there; inside their constraints the points keep the
  native FMS's. A point without an altitude takes the straight path's
  between its neighbours inside its constraint (SUGOL about 11,830 in its
  window, LAMSO about 21,450 under an at or below FL230, FL200 under an at
  or below FL200, AM608 its floor 3400); it took the floor, else the
  ceiling. After a point in the cruise it takes the T/D's 290 ft/nm line
  back from the next point (LAMSO about 21,870 after DIBAL at FL370; the
  straight line from DIBAL took the ceiling 23000).
- `vnav_descent_points_test.lua`: VNAV PTH's descent through the route's
  points below the transition altitude, the production autopilot, VNAV,
  energy mode and A/T in approach_model.lua's closed loop on the EHAM route
  from 12 nm before SUGOL, the MCP at 2000 ft: the AFDS's altitude stays the
  MCP's, the energy mode stays on and the A/T's mode the same through SUGOL
  and NETOM, SUGOL is crossed inside its FL100-FL140 window and NETOM at or
  above FL070, each within 200 ft of its path, and the V/S stays at 500 fpm
  or more within 30 s of each (each point's altitude was the AFDS's
  level-off).
- `vnav_turn_path_test.lua`: VNAV's descent path through a fly-by turn is
  continuous and at the fix's altitude at the turn's bisector - the
  production LNAV (the hold of NETOM for its 86 deg turn and its release at
  the bisector), setDistances and setDescentVSpeed, the 747 flown along the
  inbound leg, the arc LNAV draws (and a tighter one) and the outbound leg:
  no step over 15 ft in 0.02 nm (the straight distance to the point dropped
  the path 480 ft at the release), NETOM's 7849 at the bisector, and the
  legs' paths as before away from the turn; so is the approach's path
  (B747_vnav_approach_path) through NIRSI's 65 deg turn (it stepped 168 ft).
  Both also with the turn sequenced at its bisector, as LNAV sequences a turn
  it flies by its path (with the turn known only from that sequence NETOM's
  path stepped 290 ft and NIRSI's was 59 ft high at the bisector).
- `vnav_turn_latch_test.lua`: the fly-by turn LNAV hands VNAV's path is the
  route's as it stands - the production LNAV (cross-track error, hold and
  turn), setDescentVSpeed and setDistances in the production order, the 747
  flown through the turns: after a route edit at the turn's fix or the next
  one (NIRSI moved 2.5 nm before NETOM, its turn 40 deg instead of 86) the
  turn goes out on the new course and the path is the new route's, with no
  step over 15 ft (the old turn, latched by its index, stepped the path
  +303 ft after the bisector); the turn is taken only while LNAV flies the
  turns (none with LNAV armed, flown straight past NETOM) and ends once
  the 747 is vectored 1 nm farther from the fix than where it was taken;
  in HDG SEL or a direct-to it stays while the 747 turns on round its arc
  (ended at the HDG SEL, the path stepped -740 to -820 ft where NETOM was
  sequenced abeam) and fades out of the path as the 747 goes off it - with
  LNAV's arc drawn for 324 kt and the 747 turning inside it, and flown
  straight on before a 110 deg turn, no step over 15 ft (ended 0.5 nm off
  LNAV's path it stepped +281 and +332 ft at once) - and has ended 2 nm
  past NETOM's abeam point flown straight on; where it ends before its own
  end (HDG SEL, the route edit) the
  path carries on, the step taken out over 2 nm, also turned back from the
  fix (the cut taken off was dropped at once: +77 ft);
  and on a leg too short for one turn to end before the next begins
  (AM607's 90 deg 2.0-4.0 nm after NIRSI's 64 deg, in 0.01 nm steps) the
  approach's path has no step against its slope over 8 ft (the next turn,
  taken only once the one before had ended, stepped it -375 ft with a
  2.6 nm leg; below 2.4 nm the step at AM607's bisector, over the blend's
  250 ft, was taken at once: +259 ft with 2.2 nm), also when the turn
  carried on ends with a route edit of its fix (NIRSI nudged 1 m: -94 ft
  at once); far from the
  fix (40 nm, the cruise) LNAV works the turn out every 5 s at most, not
  every frame. The turn's fade moves with the distance flown, so LNAV
  engaged again about 1 nm off the path (NETOM, a 110 deg turn) and HDG
  SEL with LNAV engaged 1 nm outside NETOM's turn leave no step over 15 ft
  (-86, -269 and +101 ft at once with the fade set from the distance off
  the path each frame); on a short leg the distance off the path is taken
  from the turn carried on too (on NIRSI's arc 2.6 nm before AM607 the
  747 is at most 0.05 nm off as LNAV takes it and the fade stays at most
  0.1; from AM607's path alone up to 0.27 nm, and 0.5 nm with arcs LNAV
  shares: faded 0.23); a change carries the step still being taken out
  on (HDG SEL 0.8 nm before NETOM's arc, the 747 at 15 deg of bank: no
  step against the path's slope over 15 ft; -503 ft at once at the turn's
  end), and a
  route edit's own step over 250 ft is taken at once (NETOM's 110 deg
  turn edited to straight on 3 nm before it: the new route's path at
  once; blended, 229 ft off it), the blend still being taken out with it
  (AM608 moved 1 nm back 0.05-0.8 nm after AM607's bisector on a 2.0 nm
  leg: the new route's path at once, as with the blend's state cleared at
  the edit; carried on, -265 ft at once and up to 265 ft off it). The
  turn carried on counts towards the
  distance off the path only up to its own outbound leg: flown straight on
  past AM607's arc in HDG SEL on the 2.6 nm leg, AM607's turn ends by
  8.3 nm (8.80 measured from that leg too).
- `vnav_mcp_push_test.lua`: after an ALT selector push in the descent (the
  MCP dialled down from VNAV ALT) the AFDS's altitude is the new MCP
  altitude at once (it was NETOM's 7849 above the cleared 7000 for 30 s),
  and VNAV ALT is set as soon as X-Plane holds it, also within 30 s of the
  push (VNAV_DES took the capture back every 0.2 s until the 30 s were up);
  a push where the 747 is levelled at the MCP altitude leaves VNAV ALT. In
  the climb too (VNAV_CLB_ALT on the EINN route): 25 s after a push the
  AFDS's altitude is the MCP's 11000 below VNAV's target (it was 33000),
  and VNAV ALT is set there at once.
- `vnav_spd_level_off_test.lua`: VNAV SPD's descent (FLCH: the IAS window
  open above SPD TRANS) still levels off at the STAR's constraints - SUGOL's
  floor FL100 (not its predicted 11315) with the MCP at 2000, also where it
  levelled off (X-Plane's ALT HOLD), the MCP where it is higher - while VNAV
  PTH, also with the window open below SPD TRANS, takes the MCP altitude
  alone (the production VNAV_DES_ALT).
- `xtlua_vnav_tables_test.lua`: VNAV's new global tables in XTLua's namespace
  (init.lua's create_namespace): LNAV's held turn (B747_lnav_vnav_turn) and
  the MCP altitude's conflict (B747_vnav_mcp_conflict) read as plain tables,
  a missing index nil (without a metatable XTLua copied them into a
  namespace whose missing-index read overflowed the stack).
- `vnav_mcp_above_test.lua`: the MCP altitude dialled above the 747 in a
  VNAV PTH descent (9000 to 13,000 at 12,000 ft): it levels off where it is
  and holds in VNAV ALT (FCOM 4.10.7), neither climbing nor going on
  descending to the next point (mcp_alt_dial_model.lua's closed loop).
- `vnav_spd_descent_test.lua`: VNAV SPD's descent in the closed loop
  (mcp_alt_dial_model.lua): from FL250 it levels at an at or above FL150 and
  holds it with one pitch-mode change until the fix (FLCH put back every
  0.2 s made the FMA flip every 0.6 s), then descends to the MCP without
  levelling at the next point's predicted altitude.
- `vnav_cifp_constraints_test.lua`: the SID, STAR and approach constraints read
  from X-Plane's CIFP (`B747.70.xt.autopilot.constraints.lua`) - records as
  X-Plane writes them (a CA leg, windows, flight levels, the glide slope
  kinds at the FACF and FAF, the final approach angle, the missed approach's
  start), and on made-up
  airports in that form the procedures found from the route's idents: the SID
  for the runway against one differing only in its last fix, another
  runway's, an enroute transition; the STAR and the approach transition at
  the same fix (the transition's constraint stands, as the native FMS keeps
  it), the ILS against an RNAV approach without its FAF, the final alone, a
  route back to the departure airport, no file, Custom Data before the
  default data; legs at one fix in a row (a hold after it), a SID's altitude
  leg before its first fix, a join where the later procedure has none; the
  files read a few lines a frame, kept for a new route to the same airports,
  an airport read in part read again, the file closed when the route goes,
  and the autopilot's per-frame update by route index.
  With `XPLANE_ROOT` set to an X-Plane 12 folder it also checks the real
  EIDW 28R ENDE3J, EHAM LAMS2A and ILS 18R via SUG1D, and EINN's ILS 06.
- `vnav_climb_constraints_test.lua`: VNAV's climb with the SID's constraints
  (EIDW 28R ENDE3J) - the target and the dial at the lowest ceiling of the
  fixes not passed yet (DW124's FL090 from DW129 on), no resume while
  levelled there, on to ENDEQ's FL230 once DW124 is passed and to CRZ ALT
  past ENDEQ, DW124 held while LNAV has sequenced it early, no level-off at an
  at or above, at an at's altitude and a window's top, a ceiling far below
  the aircraft let go, the MCP below the ceiling standing, and nothing
  without the constraints or in the descent.
- `vnav_descent_floors_test.lua`: VNAV's descent with the STAR's and the
  approach's constraints (EHAM LAMS2A, ILS 18R via SUG1D, and a made-up at or
  above FL200 above the transition altitude) - the highest floor of the
  fixes not passed yet as a level-off whatever its height, a fix held while
  LNAV has sequenced it early included, the native FMS's path altitude
  staying the target where it is higher (SUGOL's 11315, NIRSI's 5563), the
  floor where [9] is missing, no level-off above an aircraft already below
  the floor, and nothing without the constraints or in the climb.
- `vnav_approach_path_test.lua`: VNAV PTH in the approach (within 25 nm of the
  arrival runway along the route) on the path to the runway - the fixes'
  altitudes through their CIFP constraints (AM608's 3300 below its floor at
  3400), the arrival runway by its name (EHAM with its missed approach's far vectors leg, TST744L
  with its departure runway, not the departure end of a route back to the
  departure airport), only the fixes from the route's farthest point on (a
  circuit's way out left out, level beyond; after a DIRECT TO), no runway or
  pseudo fix, a runway without an altitude, the path
  from the runway's threshold crossing altitude up the final approach angle
  (3.0, 3.2 or 2.5 deg) to the glide slope intercept, through the route
  altitudes never climbing (EINN's ASGON 3,046 ft after ELPOM's 3,000) and up
  to CRZ ALT at 290 ft/nm, the V/S from its gradient and the path error (never
  a climb, at most 1,500 fpm of correction, kept within the flaps' placard - 2
  kt and Vmo - 11 kt by fading the correction and then shallowing); and the
  production setDescentVSpeed and setDistances on EHAM ILS 18R and EINN ILS
  06: the path error, V/S and V/B (to the next fix) on the path, above and
  below it, within 600 ft above the AP altitude, by a fix LNAV sequenced
  early, near the flaps 5 placard and Vmo, with EHAM's missed approach, with
  VNAV off (the path error only), into the approach at 25 nm and out of it
  beyond 27 nm (held by the runway's name and position, let go without a
  route or past the runway), and nothing beyond 25 nm from farther out.
- `vnav_approach_autothrottle_test.lua`: the A/T in the approach (EINN ILS 06,
  the IAS window open at idle 15.6 nm out) - VNAV_DES keeps it on and turns
  it back on, B747_ap_fma shows SPD at idle, and VNAV PTH stays with the
  window open above SPD TRANS (VNAV SPD 30 nm out), also from ALT HOLD; 30 nm
  out the descent's energy mode and IDLE as before, also near a level-off
  with the A/T off (the window open) or on (the window shut). It loads the
  production code with `approach_model.lua`.
- `approach_model_test.lua`: EHAM ILS 18R via SUG1D and EINN ILS 06 flown in
  the approach model from where the line flights of 2026-10-16 were, 300 ft
  (EINN 500 ft) higher or lower, faster or slower, 30 nm out, with APP later
  and the LOC sooner, 1,000 and 1,500 ft high (also with VNAV's speed at the
  A/T's cap, and so in a tailwind), in a tailwind and a headwind (EINN in
  TST744L's westerly): the real glide slope captured (below 4 deg, by 5 nm),
  never over the flaps' placard, the A/T on, no climb, within 0.75 dot at
  1,000 and 500 ft and 30 ft at 200 ft, VREF to VREF + 20 kt at 500 ft; and
  EHAM 1,000 ft high at the A/T's flaps 1 cap in a tailwind growing to 70 kt
  at most 0.5 kt over the placard with the A/T on (it ends on the false lobe,
  without the speedbrake).
- `approach_model.lua` (not a suite): a closed-loop longitudinal model of the
  final descent and ILS approach - the production autopilot (VNAV, the FMA,
  setDistances), AFDS pitch director and EEC throttle code, each script in
  its own namespace with the datarefs shared as in XTLua, replicas of LNAV's
  sequencing, the IAS window, the APP arming and G/S capture, the kit's
  approach procedure, and a point-mass 747 (lift, drag and thrust fitted to
  the kit's recordings), with EHAM ILS 18R and EINN ILS 06 as flown; its
  loader runs the production code for the suites' own scenarios.
- `vnav_speed_constraints_test.lua`: VNAV's speed with the route's speed
  constraints - in the climb (EIDW 28R ENDE3J) the speed allowed now
  (laminar/B747/autopilot/vnav/constraint_speed: 210 kt from the runway to
  DW129, DW129 held while LNAV has sequenced it early, 290 kt to ENDEQ, none
  after it, none for an at or above), and the climb's targets capped by it
  below and above 10,000 ft and where ECON would be the climb Mach, never
  below the manoeuvring speed of the flaps set, recalculated when it changes;
  in the descent (EHAM ILS 18R via SUG1D) NETOM's 250 and NIRSI's 220 from
  where the deceleration to them begins (at 0.5 kt/s plus 1 nm) and on after
  their fixes, NIRSI held, AM622's at or above 160 no limit, and the
  descent's targets capped by it below and above 10,000 ft, the descent Mach
  turned to the constraint's CAS, and the flaps' manoeuvring speed kept.
- `xtlua_route_constraints_test.lua`: the route constraints' code as XTLua runs
  it - every laminar/ dataref the xt autopilot binds created by an init
  script of one of the aircraft's XTLua plugins (in the xt autopilot
  deferred_dataref is find_dataref), and B747_update_route_constraints,
  B747_update_constraint_speed and VNAV_NEXT_ALT run in init.lua's namespace,
  where a global table without a metatable would be wrapped and its missing
  index read would overflow the stack.
- The remaining suites cover AFDS helpers, planned-step editing/EXEC/ERASE,
  ECON calculations (CAS, and the climb Mach as the ECON cruise Mach for the
  cruise altitude at top-of-climb weight), ND waypoint selection, and the
  XTLua `dofile` loader (including the autopilot monitor loading the AFDS
  helpers exactly once).

The standalone tests verify logic and interfaces. Before making the aircraft
release-ready, validate these scenarios in X-Plane with both flight directors
and the applicable autopilot/autothrottle modes:

| Scenario | Expected observation |
| --- | --- |
| Departure from sea level and an elevated runway | Capture activation IAS; reduce thrust and accelerate at separately selected heights above the departure barometric datum. |
| Terrain change or QNH/STD selection during initial climb | Terrain/knob movement alone does not trigger either height; acceleration cannot return to the V2 band. |
| Two planned steps with an early fly-by leg sequence | First unaccepted step remains NOW; ALT acceptance advances to the second. |
| Native route MOD and downstream altitude constraints | Native title/constraints remain visible; only explicit step waypoints receive S overlays. |
| Captain/FO MAP and PLAN, stepping the CDU view | Header identifier stays on the active waypoint and agrees with its ETA/distance; map centre can change. |
| Low cruise altitude with ECON, then manual SEL speed | Cruise Mach reaches the existing CAS-floor calculation; SEL speed is preserved. |
| THR REDUCTION left at 1500FT, then set to FLAPS 5 | Climb thrust is set at 1500 FT above the departure datum; with the flap schedule it is set at flap retraction instead, with no height backstop. |
| ECON climb through the CAS/Mach crossover | Speed changes over at the CLB page Mach, which equals the CRZ page ECON Mach; no acceleration at top of climb. With CI 100 at 350 t/FL310 expect about 32x/.836. |
| ECON cruise through a 90-180 degree turn in a strong wind | The CRZ page Mach and the cruise target drift over about a minute instead of stepping during the turn. |
| Cruise Mach entered on the CRZ page, then DELETE | Title reads ACT M.xxx CRZ and the selected Mach is flown; the CLB page Mach stays ECON; DELETE returns to ACT ECON CRZ and the ECON Mach. |
| VNAV engaged at 400 ft at various weights | Initial climb holds V2 + 10 when slow and no more than V2 + 25 when fast, until the acceleration height. |
| Departure and arrival with SPD REST left blank, then entered | Blank holds SPD TRANS through the restriction band; an entered pair is honoured and released above/below it. |
| VNAV descent below 10000 FT with SPD REST blank, extending flaps 1 through 30 | Target never exceeds the flap placard minus 5 kt (275/255/235/225/200/175 kt). |
| VNAV climb (and VNAV ALT at an intermediate level) with MCP set above CRZ ALT, ALT selector pushed | CRZ ALT resets to the MCP altitude and VNAV climbs to it. |
| Cruise step climb above the transition altitude with the ALT selector (MCP above CRZ ALT) | The native VNAV CRZ page shows the new FLxxx, `crzalt_sync_fault` stays 0, CRZ ALT is not put back and VNAV SPD follows without a recapture of the old level. |
| STEP SIZE 0 with planned LEGS steps | STEP TO/AT show the planned step; no computed optimum step appears when none is planned. |

The ECON climb CAS curve and the LRC/MRC cruise Mach curve remain an
uncalibrated simulator approximation; the climb Mach is tied to that cruise
Mach as the FCTM describes, not to a Boeing performance database. The tests do
not establish engine-specific Boeing performance, full TO/GA/engine-out speed
logic, or closed-loop flight-model accuracy. Planned steps remain advisory;
this patch preserves native downstream predictions/constraints rather than
pretending to update the native vertical trajectory by changing display text.
