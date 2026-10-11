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
  SIZE 0; VNAV climb altitude intervention raising CRZ ALT; crew intervention
  and refused commands; the production ECON updater keeping the climb Mach,
  the CRZ page Mach and the cruise speed state on one ECON cruise Mach, with
  a selected cruise Mach preserved and DELETE restoring ECON, and the sensed
  headwind reaching the ECON targets only through its 60 s lag.
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
  descent, distances, T/D and climb targets, also with a missed approach
  whose vectors point X-Plane puts hundreds of NM away (left out after the
  arrival runway).
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
| STEP SIZE 0 with planned LEGS steps | STEP TO/AT show the planned step; no computed optimum step appears when none is planned. |

The ECON climb CAS curve and the LRC/MRC cruise Mach curve remain an
uncalibrated simulator approximation; the climb Mach is tied to that cruise
Mach as the FCTM describes, not to a Boeing performance database. The tests do
not establish engine-specific Boeing performance, full TO/GA/engine-out speed
logic, or closed-loop flight-model accuracy. Planned steps remain advisory;
this patch preserves native downstream predictions/constraints rather than
pretending to update the native vertical trajectory by changing display text.
