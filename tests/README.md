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
  and refused commands; the production ECON updater's cruise-Mach input.
- `takeoff_ref_thrust_reduction_test.lua`: the TAKEOFF REF THR REDUCTION
  field - the 1500 FT default from PERF FACTORS, flap entries ("FLAPS 5",
  "10", "F20"), height entries, rejected entries, blank-line-select recall,
  DELETE, and the FLAP/ACCEL HT field beside it.
- `vnav_clb_page_test.lua`: CLB page titles ("ACT ECON CLB" / "ACT 230KT CLB"),
  the ECON/SEL SPD label, the CAS/Mach speed pair, and the blank SPD REST
  field.
- `vnav_speed_restriction_test.lua`: SPD REST on both the CLB and DES pages -
  the blank "---/-----" field skipping the restriction state, an entered
  restriction bringing it back and being left behind above it, the flap
  placard minus 5 kt limiting every descent target, and the CDU pair entry,
  rejection and DELETE.
- The remaining suites cover AFDS helpers, planned-step editing/EXEC/ERASE,
  ECON calculations (CAS and Mach), ND waypoint selection, climb-speed
  semantics including the climb-Mach crossover, and the XTLua `dofile` loader.

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
| ECON climb through the CAS/Mach crossover | Speed changes over at the CLB page Mach, and only accelerates to the cruise Mach at top of climb. |
| VNAV engaged at 400 ft at various weights | Initial climb holds V2 + 10 when slow and no more than V2 + 25 when fast, until the acceleration height. |
| Departure and arrival with SPD REST left blank, then entered | Blank holds SPD TRANS through the restriction band; an entered pair is honoured and released above/below it. |
| VNAV descent below 10000 FT with SPD REST blank, extending flaps 1 through 30 | Target never exceeds the flap placard minus 5 kt (275/255/235/225/200/175 kt). |
| VNAV climb (and VNAV ALT at an intermediate level) with MCP set above CRZ ALT, ALT selector pushed | CRZ ALT resets to the MCP altitude and VNAV climbs to it. |
| STEP SIZE 0 with planned LEGS steps | STEP TO/AT show the planned step; no computed optimum step appears when none is planned. |

ECON coefficients, CAS and Mach alike, remain an uncalibrated simulator
approximation. The tests do
not establish engine-specific Boeing performance, full TO/GA/engine-out speed
logic, or closed-loop flight-model accuracy. Planned steps remain advisory;
this patch preserves native downstream predictions/constraints rather than
pretending to update the native vertical trajectory by changing display text.
