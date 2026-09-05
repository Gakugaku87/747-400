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

- `takeoff_profile_test.lua`: 100-KIAS departure reference, VNAV airspeed
  capture, acceleration/thrust-reduction boundaries, changing terrain,
  QNH/STD changes, rearming and airborne reload. Also runs the production
  VNAV speed state machine and thrust monitor together.
- `fmc_audit_integration_test.lua`: native LEGS altitude fields and MOD title;
  step advisory through early LNAV sequencing, optional FlyWithLua automation
  and the actual ALT-selector handler; crew intervention and refused commands;
  the production ECON updater's cruise-Mach input.
- The remaining suites cover AFDS helpers, planned-step editing/EXEC/ERASE,
  ECON calculations, ND waypoint selection, climb-speed semantics and the
  XTLua `dofile` loader.

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

ECON coefficients remain an uncalibrated simulator approximation. The tests do
not establish engine-specific Boeing performance, full TO/GA/engine-out speed
logic, or closed-loop flight-model accuracy. Planned steps remain advisory;
this patch preserves native downstream predictions/constraints rather than
pretending to update the native vertical trajectory by changing display text.
