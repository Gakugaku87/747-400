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
  re-entry, the CDU CRZ ALT entry (33000, 330 or FL330) sent as FL330, and
  the cruise climb 2 s after the ALT push skipped when CRZ ALT is back at the
  level flown or T/D is within 50 NM.
- `takeoff_ref_thrust_reduction_test.lua`: the TAKEOFF REF THR REDUCTION
  field - the 1500 FT default from PERF FACTORS, flap entries ("FLAPS 5",
  "10", "F20"), height entries, rejected entries, blank-line-select recall,
  DELETE, and the FLAP/ACCEL HT field beside it.
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
- `afds_alt_capture_test.lua`: ALT capture and ALT hold in the production
  flight-director pitch code - a FLCH or V/S push outside the capture window
  surviving the update that still shows the old ALT FMA, an ALT HOLD push
  surviving a stale FLCH, V/S or VNAV SPD FMA, capture at the MCP altitude
  inside the window and at the current altitude otherwise, and the ALT hold
  vertical speed limited to 2000 fpm, and to 500 fpm when descending 15 kt
  fast (or near Vmax) or climbing 15 kt slow (or near Vmc), using recorded
  TST744L cases.
- `hydraulics_dataref_binding_test.lua`: every `simDR_`/`B747DR_` name that the
  hydraulics override file writes is bound in the hydraulics script's XTLua
  namespace, with the FLCH and V/S requests bound to the datarefs the
  autopilot reads.
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
  constraint and the end of descent altitude (its route altitude or the
  destination elevation, not the navaid frequency in [3]) at 290 ft/nm, so
  the path into the IAF is 290 ft/nm; route altitudes before the T/D (an older
  CRZ ALT) and SID constraints nearer the departure are not descent
  constraints, and the T/D stays put as the constraints are passed. The
  remaining distance ends at the end of descent and then runs straight to the
  destination, without the leg after the end of descent, also with a missed
  approach whose vectors point X-Plane puts hundreds of NM away (left out
  after the arrival runway).
- `approach_capture_test.lua`: the APP switch, APP arming and approach monitor
  together - LOC capturing only within 2.0 dots while closing (or settled
  within 1.0 dot) on an intercept of 90 degrees or less, a saturated or
  diverging LOC staying armed, a previously captured LOC recapturing at once,
  G/S capturing only after LOC with LOC and G/S both within 1.5 dots and
  never in the LOC capture frame, APP leaving the MCP heading alone, and LNAV
  still steering (and reselecting the heading mode) while LOC is armed.
- `xtlua_warm_reads_test.lua`: XTLua gives 0 for the first read of a
  dataref in a script module, so the datarefs that a fix first reads at a
  critical moment are read every frame in the module's per-frame function
  (the "local refresh...=" reads): the native transition altitude and the CRZ
  ALT sync fault flag in the FMS after_physics, and the localizer and
  glideslope signals, flags and deviations of the LOC and G/S capture gates in
  the autopilot monitor (B747_monitorAP).
- `autoland_flare_test.lua`: the autoland flare law helpers (sink-rate
  command, pitch-target size and rate limits, the approach pitch when no
  steady sample was taken, derotation at 1 deg/s to -0.5 deg) and the
  production autoland logic flown from 300 ft RA to 8 s after touchdown
  against a simple point-mass model - four approaches and two pitch-loop
  responses, ground falling away 24 ft under the flare, a noisy VSI and a
  second autoland in the same session: touchdown sink -80 to -250 fpm with
  no float, FLARE to touchdown within 10 s (11 s with the terrain), no
  nose-down before main gear touchdown, a rate-limited derotation, and A/T
  IDLE no higher than 25 ft.
- `eec_flare_retard_test.lua`: EEC IDLE in the autoland flare - no low-speed
  thrust recovery below 50 ft RA, the retard from approach thrust to idle
  over about 2 s, and the IDLE low-speed recovery kept outside the autoland
  flare.
- The remaining suites cover AFDS helpers, planned-step editing/EXEC/ERASE,
  ECON calculations (CAS, and the climb Mach as the ECON cruise Mach for the
  cruise altitude at top-of-climb weight), ND waypoint selection, climb-speed
  semantics including the climb-Mach crossover and the cruise state flying
  the FMC cruise Mach, and the XTLua `dofile` loader (including the autopilot
  monitor loading the AFDS helpers exactly once).

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
