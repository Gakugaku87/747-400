# Opus review of the changes after 50e116a1 (2026-11-11): raw findings as received

Four Opus (claude-opus-5-5) reviewers read the 130 commits `50e116a1..e9dbe14a`, one area each. They only read files and ran offline scripts in the session's scratch folder; nothing in the repository was changed. The Japanese summary, with what was checked and what was done, is [REVIEW_2026-11-11.md](REVIEW_2026-11-11.md). The labels there (FMC-1, AP-2, EEC-3 and so on) are the area and the finding's number below.

## FMC (performance, VNAV, predictions)

1. **Freeze: the climb-prediction loop never ends. This was already there at 50e116a1, but it sits in the level segment that 16390c67 reworked.**
   - Where: `B747.68.pred_model.lua:836-849` (the outer `while true`), `:750` (`if dx <= 0 then break end`) and `:697-705` (`td_x`).
   - The climb reaches a level-off constraint (`cap_ahead`), then `cruise_until(xcap, h, true)` runs. If the T/D for that altitude, `td_x(h) = xtd - td_decel`, is already at or behind `x`, then `dx <= 0`, the loop breaks and returns `"end"`. It never returns `"des"`, `x` does not move, and the outer `while true` has no exit and no guard check, so it repeats forever.
   - `td_decel` widens the window: it decelerates from the cruise Mach at the level-off altitude. M.85 at 5,000 ft is about 530 kt CAS.
   - Scenario (phase `clb`, from the ground): SID AT 5000 at 20 NM → 5 NM → RW 12 NM, CRZ 15000, LRC. `predict` never returns.
   - Also hangs: a 90-95 NM route with a SID AT OR BELOW FL150 at 50-60 NM and CRZ FL250. 3 of 400 random 60-260 NM SID routes hang, at both HEAD and 50e116a1.
   - Callers: `update_preds` (every 10 s, also at the gate) and `B747_fms_unable_crz`, synchronously on every CRZ ALT entry. The xtlua_keysystems Lua thread would stall, freezing the CDUs, the AFDS and every module of that plugin. Not tried in X-Plane.
   - Severity: crash/freeze. Confidence: confirmed by experiment (instrumented copy: x 5.25, cap 5000, xcap 25, td_x 3.55).
   - Fix: in `cruise_until`, return `"des"` when `lim` is `td_x` and `<= x`; break the climb loop when `cruise_until` makes no progress; use the climb speed for a climb level segment's T/D deceleration.

2. **Wrong VNAV path: an earlier AT / AT OR BELOW / window-top constraint is dropped once the idle path has risen past it.**
   - Where: `B747.68.pred_model.lua:199-217` (`descent_path`).
   - Only `cons[ci]`, the nearest constraint behind x, is ever tested. If the idle path back from a later constraint has already passed an earlier constraint's altitude by the time that constraint becomes `cons[ci]` (after a non-binding AT OR ABOVE or window in between), it is never anchored.
   - 6f97939b's new `level` rule only covers |a−h| ≤ 1.
   - Scenarios:
     - STAR A AT 11,000 → B AT OR ABOVE 6,000 (15 NM) → IAF AT 4,000 (30 NM) → FAF → RW (3° GP): A is planned and flown at 16,590 ft, and the T/D is 17 NM late.
     - IAF AT 7,000 → IF AT OR ABOVE 3,000 (5 NM) → FAF (16 NM): IAF at 8,512 ft, or 8,720 ft with a 210 kt IAF constraint.
   - The core is pre-existing (identical numbers at 50e116a1). FMC-08's constraint speeds aggravate it: slower speeds give a steeper idle path in ft/NM.
     - Differential fuzz of random monotonic STARs: adding the speed constraints turns compliant paths into skipped ATs in about 8 % of cases.
     - Examples: AT 4,600 crossed at 12,535 ft and AT 5,300 at 20,088 ft.
   - Severity: wrong for the crew (path, T/D, crossing altitudes). Confidence: confirmed by experiment.
   - Fix: carry a ceiling equal to the lowest upper bound of all constraints before x. Cap each step at it and go level back to the constraint holding it (generalise `level`).

3. **Minor: the rounded path crosses constrained waypoints off their altitude by Δg·l/8.**
   - Where: `B747.68.vnav_model.lua:226-239`, `:682` (`path_blend`). The rounding is centred on the breaks.
   - At the ends of a level segment between two AT 6,000 constraints (then 300 ft/NM down), VNAV PTH's target is:

     | Ground speed | GADDO (end of level, AT 6,000) | DAHJR (start of level, AT 6,000) |
     |---|---|---|
     | 210 kt | 5,934 ft | 6,070 ft |
     | 250 kt | 5,922 ft | 6,083 ft |
     | 300 kt | 5,906 ft | 6,100 ft |

   - An AT OR ABOVE at such a convex break is crossed low, by about 140-170 ft at 480 kt.
   - Severity: minor. Confidence: confirmed by experiment.
   - Fix: end the rounding at constrained waypoints, or clamp the mean to the constraint's bound there.

4. **Minor: LIM SPD title during a path deceleration with the flaps out.**
   - Where: `B747.68.vnav_model.lua:640-653`.
   - When `target_speed` already set `limited` (flap placard) and a deceleration lowers the target further, `limited` stays true.
   - Scenario: placard 230 kt (limit 225), deceleration to a 210 kt constraint. The target is 210, but the DES title reads "LIM SPD DES" instead of "210KT DES" (`spd_kt` is nil).
   - Severity: minor (CDU text). Confidence: confirmed by experiment.
   - Fix: clear `limited` when the deceleration's speed sets the target and is at or above the minimum speed + 5.

**Checked and fine**
- **`hasSimConfig` late path** (FMC and AFDS):
  - Waits 10 s of real time.
  - Takes the config only if it decodes to a table with PLANE; "null" and empty strings keep waiting.
  - No decoding per frame once taken; state is in locals; a later pulse still refreshes it.
  - JSON-error risk is the same as the existing pulse path.
- **`desSpdS`**:
  - `seen` survives EXEC (`copy_route` shares the passed legs' tables).
  - SID, missed-approach and after-runway legs are excluded; state resets on the ground and in CLB.
  - Cost per frame is O(1).
- **`behind` / `spd_behind`**: 3,000 random descent-phase cases, with no errors, no NaN, and x strictly decreasing.
- **New deceleration / `level` / `spd_back` logic in `descent_path`** (about 2,300 random STARs):
  - No errors or NaN; x strictly decreasing; at most 260 points; at most 8 ms per call.
  - Planned CAS at every speed waypoint is within its constraint.
- **`vnav_model.update`** with 200,000 random inputs (2-point and duplicate-e paths, gs 0, nil crz_alt / vmin / vref, no transition): no Lua errors, no NaN.
- **`path_blend`**:
  - Guards l ≤ 1e-6 and applies the cap.
  - Extrapolation past the E/D is symmetric, and d_ed stays ≥ 0 until the E/D is sequenced.
  - The T/D window narrows only once it is clear of the corner, so there is no jump.
- **`pre` vs the T/D-based features**:
  - The DES NOW prompt, altitude-selector push, RESET MCP ALT and pause-before-T/D are consistent: the 120 s pause precedes the ≤ ~50 s `pre`.
  - td_hold (VNAV ALT) now starts up to `pre` before the displayed T/D, which is by design.
- **Climb-constraint helpers**: `clb_last`, `clb_keep`, `clb_target`, the `g.clb_end` loop and `des_e` via `g.rem` are fine. AFDS VNAV PTH does not capture `des_target`.
- **`path_model` `nav_var`** sign conventions are correct: LOC encoded as 360·mag+true; VOR slaved variation, east positive.
- **LNAV roll-out lead** is bounded (r > 0); about 0.56 NM at 480 kt with 25° bank.
- **`B747_fms_cargo_spread`**: BULK never goes negative or over its limit. In LBS each hold can lose 1 kg to the existing truncation in `setdata`.
- **VNAV, PROGRESS and SIM CONFIG pages**: line widths, title precedence and the auto fuel toggle logic are fine.
- **XTLua pitfalls**: no new global tables, no timer re-arms, no rebound dataref globals; the FMC chunk compiles; `luajit -bl` shows no stray globals in the models.
- **Tests**: `tests/fms`, 102 files, all pass.

Scratch harnesses are in `C:\Users\gakug\AppData\Local\Temp\claude\f3f9aa09e674da4c\80836fa6-339c-473e-8a70-7cb22d473d59\scratchpad\`:
- `hang3.lua`, `fuzz5.lua`: finding 1
- `star_skip.lua`, `iaf2.lua`, `fuzz2.lua`: finding 2
- `blend_at.lua`: finding 3
- `limspd.lua`: finding 4

## AP (AFDS, A/T)

### Findings (most severe first)

**1. Resuming the descent from VNAV ALT at the T/D deletes the next descent constraint.** Severity: wrong for the crew. Confidence: confirmed (each link separately).
- Where:
  - `plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vnav_model.lua:581-596`
  - `B747.68.xt.fms.lua:2136-2153`
  - `B747.70.vnav_mode_model.lua:238-254`
- Defect: at the T/D, VNAV ALT (`td_hold`) needs a selector push to end. By the time of that push the FMC has already switched to DES, so `B747_fms_alt_sel_push` takes its descent branch and deletes a constraint.
- Scenario:
  - ATC delays the descent. The airplane passes the T/D with the MCP still at FL350 and goes into VNAV ALT. That part is correct (FMSPG p.34).
  - The crew sets the MCP to 6,000 ft for a "descend via". The FMC goes to DES at once (`mcpBelow`).
  - The AFDS stays in VNAV ALT, because the airplane is above the path and `L.below` is false.
  - The crew pushes, as FCOM p.645/665 require. In DES, the FMC deletes the first STAR constraint between the airplane and 6,000 ft.
- FCOM p.649: in cruise in VNAV PTH or ALT, a push only starts the descent.
- How it was confirmed:
  - The DES switch on an MCP reset after `td_hold` is already asserted in `tests/fms/vnav_model_test.lua` (lines 69-86).
  - I ran a push in DES on a copy of the `pred_glue_test` harness: ALPHA 11000 vanished from the active route.
- Fix: keep the FMC in CRZ after `td_hold` until the push, or treat the first push after `td_hold` as a cruise push (no deletion).

**2. An MCP altitude equal to the FMC constraint on the descent path gives VNAV ALT instead of VNAV PTH.** Severity: wrong for the crew (a missed final-approach descent). Confidence: confirmed by experiment.
- Where: `B747.70.vnav_mode_model.lua:188-198` and `247-253`.
- Defect: on the descent path `levels` is false, so neither the "fmc" capture nor the `same` test applies. The MCP capture (`CAPTURE_NEAR` 20 ft) therefore always gives "mcp" (VNAV ALT). After that, the descent resumes without a push only if `path_dev < 0` at the first frame the MCP moves. That flag is judged once and never re-evaluated.
- Scenario (the FCTM p.187 VNAV approach):
  - The MCP is set to the FAF constraint, 2,000 ft, and the path is level there. The FMA shows VNAV ALT; FCOM p.1256 and FCTM say it should be VNAV PTH.
  - About 2 NM before the FAF the crew sets DA 600 ft.
  - Model run 4 ft below the path: VNAV PTH, descending at the FAF.
  - Model run 4 ft above the path: still VNAV ALT, level at 2,000 ft past the FAF, 600 ft above the path and growing.
  - Only a push recovers, and in DES that push also deletes the next step-down constraint (as in item 1).
- Fix: on the path, treat an MCP capture with `|fmc_alt - mcp| <= SAME_FT` as an FMC-altitude level (VNAV PTH), or re-judge `below` continuously with a tolerance.

**3. No IAS/MACH changeover with VNAV speed intervention.** Severity: wrong for the crew. Confidence: confirmed by experiment.
- Where: `B747.70.xt.autopilot.lua:2576, 2590, 2602` (`B747DR_ap_vnav_state < 2`).
- Defect: with VNAV engaged and the window open, nothing switches the units. `afds_fmc_vnav` also returns early when the window is open.
- Experiment results:
  - Climb: VNAV with intervention at 320 kt, M.86, +1,500 fpm. The window stays IAS.
  - Descent: intervention at M.84, FL270, dial 330 kt, −2,000 fpm. The window stays Mach.
- Consequence:
  - In the descent, the Mach's CAS rises to the cap (Vmo−10 = 355 kt) instead of switching to about 310 kt.
  - In the climb, 320 kt is held up to the protection limit (Vmax−5, about M.90 at FL350).
- FCOM p.643 states the window rule without exception. This gap predates the review range; the 11-07 fix (finding 4) only added "armed".
- Fix: use the window-open condition, `(vnav_state < 2 or manualVNAVspd == 1)`.

**4. The 1 s NCD confirmation covers mode failures only.** Severity: minor. Confidence: confirmed by reading.
- Where:
  - `B747.70.xt.autopilot.lua:883-896` (`afds_sensors`)
  - `B747.70.afds_model.lua:674-691` (`land_status`)
- Defect: the same one-frame NAV 1 G/S flag still gives sensors = 1.
- Effect for that frame:
  - LAND 3 → NO AUTOLAND.
  - FLARE/ROLLOUT arm and runway align drop.
  - `B747DR_ap_autoland` goes 1→0→1.
  - `B747_ap_afds_fma_mode_change` restarts a 10 s box around LAND 3.
- Fix: give `land_status` the confirmed ILS count.

**5. The SEL switch's conversion can leave the window outside the MCP range.** Severity: minor. Confidence: confirmed by computation with `ap_mach_cas`/`ap_cas_mach`.
- Where: `B747.70.xt.autopilot.lua:2054-2068`.
- Defect: only the input is range-checked, not the result (FCOM p.643: 100–399 kt, .400–.950).
- Examples:
  - M.80 at 15,000 ft gives 410 kt.
  - 320 kt at FL370 gives .96.
- Fix: clamp the converted value.

**6. The gust complement drifts under time acceleration.** Severity: minor. Confidence: plausible (reasoning; not run in X-Plane).
- Where:
  - `B747.70.at_model.lua:387-388`
  - `B747.70.xt.autopilot.lua:963-964`
- Defect: `accel_in` is per sim second but `dt` is real time (SIM_PERIOD stays real time at sim_speed k). The complement under-counts TAS change, and the 20 s blend leaves a steady error of about (k−1)·GUST_TAU·dTAS/dt.
- Example: at 4× in a 2,000 fpm V/S descent at constant IAS, the error is about 15 kt TAS (about 9 kt IAS). The A/T SPD settles about 9 kt slow. Level cruise is unaffected.
- Fix: scale by sim speed, or bypass the complement when sim_speed ≠ 1.

### Checked and fine
- `hasSimConfig` late path:
  - Lagged reads: the first read is "", the config arrives the next frame.
  - The decode is guarded by `type == "table"` and `PLANE`.
  - State is kept in a local table, and a later pulse still updates the config.
- XTLua pitfalls:
  - New dataref globals are bound once in the module (no rebind).
  - Model tables carry metatables, so they are not wrapped as namespaces.
  - The module still loads, so the 200-local limit is not hit.
  - No new self-rearming timers.
  - Every knob press does its work without depending on the release.
- `mode_failures` timers:
  - Counted in sim-time dt.
  - Reset by any good frame.
  - A capture needs both receivers, so a stale timer cannot fail a fresh capture.
  - Frequency, RA and IRU failures still fail at once.
- Logging is in pcall and rate-limited.
- Mach cap (d9e6aa0e): the ISA conversions are correct, and `maxkts` has no readers.
- Pitch speed-law target feedforward:
  - `k` is the filter gain defined earlier in the function.
  - Reset on a law change or a step, and bounded by SPD_ACCEL.
  - `Vminm` is not g-dependent, so no noise is fed forward.
- ALT-law gain by CL: Qstatic is in Pa, and it is nil-safe.
- FLCH energy blend:
  - The energy rate is invariant to the pitch trading speed for height.
  - Climb only; no levers back.
- The SPD floor at Vmin with flaps up matches FCOM p.675.
- Gust complement:
  - Unbiased in steady flight and in turns (projected on the air-relative velocity).
  - Fades near the limits and resets with flaps.
  - `local_a*` is kinematic, as the s277 V/S results confirm.
- `vnav_mode_model` is nil-safe. The removed functions (`vnav_lost`, `old_law`, `vnavLevel`) have no remaining callers.
- `afds_control`: the old director runs only without a pitch law, so holding the MCP's altitude there is harmless.
- The VrefFlap and steering-draw removals are fine.
- All 19 `tests/autopilot` files pass.

Experiment scripts are in `C:\Users\gakug\AppData\Local\Temp\claude\f3f9aa09e674da4c\80836fa6-339c-473e-8a70-7cb22d473d59\scratchpad\`:
- `exp_des_push.lua`
- `exp_vnav_faf.lua`
- `exp_vnav_level_segment.lua`
- `exp_intervention_changeover.lua`
- `exp_intervention_descent.lua`
- `exp_vnav_model.lua`
- `exp_conv.lua`

## EEC (engines, EEC, EGT, SFC)

1. **The GE's in-air N1 and the EEC's GE thrust depend on the captain's altimeter (baro setting and static port) and indicated TAS.** Location: `B747.42.xt.EEC.GE.lua:279-281` (new `B747_ge_n1_of_thrust`) and `B747.42.xt.eec_thrust.lua:283`. Both feed `B747_ge_n1_model.n1` with the module's `pressure_ratio` and `mach`. Those come from `atmosphere(simDR_altitude)` and `flight_coefficients(..., simDR_tas_pilot)` (`B747.42.xt.EEC.lua:1181-1182`), and `simDR_altitude` is `altitude_ft_pilot` (`:194`). The P&W EPR model uses the true `barometer_current_pas` and `machno` instead.
   - **Static failure:** the failure window's "STATIC CAPT BLOCKED" in a GE climb. With the altimeter frozen at 10,000 ft while at FL350, 45 kN shows 69.4 % N1 instead of 91.9 %. The EEC holds the shown N1 at its command, so the throttle goes to 1. `B747_eec_thrust_short` then adds 200 N of `acf_tmax` every frame without a cap (`GE.lua:558-559`) until about 132 kN an engine shows the true N1, roughly 3x the thrust. In a descent with a frozen static the error goes the other way.
   - **Crew impact:** this breaks the Unreliable Airspeed N1 procedure, whose tables the model was fitted to.
   - **Normal flights:** about 0.04 % N1 per hPa away from 1013 below the transition altitude (0.8 % at QNH 990), with a step when the crew sets STD. A pitot error changes the Mach input (M.84 to 0 gives -13 % N1).
   - Severity: wrong for the crew (wrong thrust). Confidence: confirmed by reading, numbers offline with the model.
   - Fix: use `simDR_epr_ambient_pa/101325` and `simDR_epr_mach` in `B747_ge_n1_of_thrust`, and cap the thrust_short boost.

2. **The GE thrust control's slope estimate has no ceiling and jumps near zero net thrust.** Location: `eec_thrust.lua:283,291`; `ge_n1_model.lua:56`; `GE.lua:308-310`.
   - The N1 term x^0.61 has an infinite derivative at zero thrust, and the GE display treats negative thrust as zero, so it is flat below zero.
   - At FL250 M.72 the estimate is 15 (the floor) at F ≤ -0.5 kN, 1,100 at -0.49 kN, 245 at 0 and 90 at 2 kN. The measured GE plant is 109-127.
   - Scenario: a level-off or A/T SPD thrust increase from flight idle in a 280-300 kt descent, where X-Plane's idle net thrust is near or below zero.
   - Offline result, using a stand-in plant built from the commit's measured lags and thrust per throttle:
     - X-Plane's idle at -1 to -3 kN: an 8 kN step peaks at 15-19 kN, and a 15 kN step at 22-23 kN.
     - X-Plane's idle at -0.3 to +0.5 kN: 20-28 s to 90 % of the step.
     - The P&W on the same plant: 3-5 s with little overshoot.
   - No GE descent or level-off scenario is among the runs listed in the commits.
   - Severity: wrong thrust (surge or crawl). Confidence: plausible.
   - Fix: evaluate dN1/dF at a thrust floor of a few kN, cap the slope near the measured range, and give the GE display a continuous response below zero thrust (as the P&W EPR got on 11-05).

3. **The EGT model's 60 s cooling lag after FUEL CONTROL CUTOFF from high power gives a spurious red EGT and a latched red box.** Location: `egt_model.lua:204,263`, together with `engine_display_model.lua:259-263` (red at the start limit whenever CUTOFF shows the line) and the exceedance latch.
   - Scenario: the engine-fire memory items after takeoff (lever closed, then CUTOFF 1-3 s later).
   - Offline with the model:
     - P&W at EPR 1.48, TAT 35 °C (611 °C): the EGT stays at or above 535 °C for 7-10 s.
     - P&W at EPR 1.51, TAT 18 °C: 1-4 s.
     - GE at N1 106, TAT 33 °C (860 °C): at or above 750 °C for 4-9 s.
   - The box then stays red until CANC. Before, the filtered X-Plane EGT fell within about a second.
   - Severity: minor, wrong for the crew. Confidence: confirmed by reading and offline; that the real EGT falls in seconds is my judgement.
   - Fix: a short lag while windmilling or just after a shutdown (60 s only for a ground soak), or no start-limit red until a start begins.

4. **The GE's in-air N1 jumps when the command leaves idle, and the lever has a dead band.** Location: `GE.lua:323` vs `:334-338`.
   - Below `engine_idle_control_GE`'s value the display is pinned to it; above, it is the model, which since 80682102 includes 36.93 M.
   - At 5,000 ft and 250 kt: pinned 31.6 %, model 35.6 % at zero thrust and 40.0 % at 2 kN. At 10,000 ft M.54: 36.5 vs 39.5/44.1.
   - The display jumps 4-8 % up, and commands between the two values give throttle 0 (about 10 % of the lever's travel). Before the Mach fix the jump was downward and the thrust came in smoothly.
   - Severity: minor. Confidence: confirmed by reading and offline.
   - Fix: pin to the model's idle N1 (model at X-Plane's idle thrust), or blend the two.

5. **The SFC correction compounds after XTLua's "Reload Scripts".** Location: `B747.42.xt.sfc_corr.lua:47-53`.
   - The acf's SFCs are captured once after load. A script reload does not reset X-Plane's `jet_SFC_*`, so the corrected values are captured as the acf's own.
   - Each reload multiplies the fuel flow again: about +4 % at FL410 cruise. `sfc_corr_off` then "restores" the corrected values.
   - Severity: minor (needs a reload). Confidence: confirmed by reading; the menu item exists in `win.xpl`.
   - Fix: take the acf values from constants or from storage that survives a reload, or divide out the last factor written.

**Checked and fine:**
- **EGT model:** the lag is exact for a ramp target; no division by zero; the target steps on a state change; settle; floor. The FCOM's four figures are reproduced. Normal start peaks stay under the hot-start trigger: P&W about 493 °C, GE about 661 °C at 50 °C. Run/start switching at N2 55 is continuous. Reverse thrust is fine (`thrust_dry_n` is positive in reverse, per notes §8).
- **Engine start:** igniter order 1,2,1,2 (109) and 1,1,2,2 (GE SINGLE) per FCOM p.863. A failed igniter is removed from X-Plane's ignition only. The igniter indexes 0-3 and 4-7 match `failures.txt`. The HOT START retry and abort paths work, and the GE start glue now reads `display_GE_EGT`.
- **thrust_control:** the velocity form is clamped with no windup. The rate is zeroed at saturation and cleared at idle, reset and new flight. KI is continuous at KI_DELTA_REF, and delta is clamped to 0.1-1. A GE takeoff with the ramp gave no overshoot on a stand-in plant.
- **plant_slope:** the NaN/inf guard and the f ≤ -0.5 case are handled; the P&W uses the negative EPR branch.
- **ge_n1_model:** k(M) > 0 (minimum 21.7 at M.86) and q > 0. Thrust is clamped at zero, so there is no negative base to a fractional power. Continuous at M_MAX.
- **take_off_N1_GE's local Mach:** the other readers of the module's Mach are cD (computed earlier in the frame) and in_flight_N1_GE (its results are overwritten).
- **SFC correction:** nil and low-pressure guards; P&W only; the Mach fade.
- **N2 hold:** `B747_eec_hold_stopped_n2` has the same condition and frame as before and also covers the RB211.
- **XTLua pitfalls:** each new global is bound once; state is in locals or metatable tables; no run_after_time; per-frame cost is small.
- **Offline tests:** tests/eec (8 files) and tests/engines (8 files) all pass.

My offline scripts are in `C:\Users\gakug\AppData\Local\Temp\claude\f3f9aa09e674da4c\80836fa6-339c-473e-8a70-7cb22d473d59\scratchpad\` (`ge_air.lua`, `spool_cmp2.lua`, `egt_cut.lua`, `ge_idle.lua`).

## FUEL, AERO, BRIDGE (APU, fuel, drag correction, weight and balance window)

(The labels: 1 FUEL-1, 2 AERO-2, 3 BRIDGE-3, 4 FUEL-4.)

1. **plugins/xtlua/scripts/B747.03.xt.electrical/B747.03.xt.apu.lua:68-73 (commit 1ae8f091). The APU fuel-valve wait uses the wrong clock.**
   - **Defect:** the wait counts XTLua's `SIM_PERIOD`, which is real time and keeps running while X-Plane is paused or in slow motion. The valve it watches is moved by the fuel model in X-Plane's time (`fuel_frame_dt`), which is 0 while paused.
   - **Scenario:** select APU START. X-Plane's starter goes to 2 and the valve is 0.25 open, 1 s into its 4 s travel. The user pauses for 6 s or more. `apu_valve_wait` passes 6 s, `inp.fuel` becomes false, and the APU model shuts down with a fault and shows the APU advisory.
   - **After unpausing:** the start does not resume until the selector is turned OFF.
   - **Experiment:** a scratch probe on the mock (C:\Users\gakug\AppData\Local\Temp\claude\f3f9aa09e674da4c\80836fa6-339c-473e-8a70-7cb22d473d59\scratchpad\apu_pause_probe.lua) gave "after 7 s paused: starter 0 valve 0.25 APU advisory 1", unchanged 60 s after the pause.
   - **Low frame rates:** the same should happen below about 7 fps, where X-Plane runs in slow motion. Example: the start-up hitches noted in e9dbe14a, which is when a cold & dark APU start happens. This part is plausible, not tested.
   - **Severity:** wrong for the crew (an aborted APU start and an APU advisory).
   - **Confidence:** confirmed by experiment for the pause case.
   - **Fix:** count the wait in X-Plane time (`total_running_time_sec` differences, as the fuel module does), or hold it while `sim/time/paused`.

2. **plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.xt.aero_corr.lua:19-25. The drag correction can be applied twice after a script reload.**
   - **Defect:** the acf's base value `fuse_cd_acf` is read from the live `acf_fuse_cd`, which this module itself overwrites every frame.
   - **When it bites:** XTLua has a "Reload Scripts" command (`xtlua/reload_all_scripts`; the strings are in plugins/xtlua/64/win.xpl). It restarts the Lua state without reloading the acf, so the corrected value becomes the new base and the correction is applied on top of it again.
   - **Cruise case:** at 180 t, FL410, M.87 the module writes 0.0236 (the acf has 0.085). After a reload, the next frames subtract the 0.0614 again and clamp at 0. Drag falls by about CD 0.0016 more for that case, and up to about 0.0056 at heavier weights and higher Mach, until the aircraft is reloaded.
   - **Ground case:** with the gear down the gear term stacks: 0.085, then 0.151, then 0.217.
   - **History:** this existed with the gear term (11-02); v4-v7 made the Mach term much larger.
   - **Severity:** wrong drag after a developer or user action.
   - **Confidence:** the code path is confirmed by reading. That XTLua's reload leaves the acf values untouched is plausible.
   - **Fix:** write `fuse_cd_acf` back in an unload/stop callout, or keep the base outside the Lua state (for example a float dataref owned by the native bridge, or read once from the .acf).

3. **plugins/b747_fms_bridge/src/wb_window.c:204-210 (commit fccf014c). The new row pushes a tank off the default window.**
   - **Defect:** the "Cargo (total)" row adds one line to a fixed default height of 760 px.
   - **Effect:** the 11-06 comment gives about 22 px a row ("about 25 rows, 550"). At that size, FUEL BY TANK now shows only CTR and MAIN 1-3 by default. MAIN 4 was pushed off; RES 2, RES 3 and STAB were already cut.
   - **Minimum height:** at the 600 px minimum, the passenger layout's last CG row ("Zero fuel weight CG") now sits exactly on the bottom edge.
   - **Severity:** minor (UI).
   - **Confidence:** plausible; it depends on X-Plane's proportional font height.
   - **Fix:** raise the default height by about 22-90 px and the minimum by about 22.

4. **plugins/xtlua/scripts/B747.25.xt.fuel/B747.25.xt.fuel.lua:631-655. Fuel temperature is never re-initialised at flight start (existed before; the code was touched in be2ff8ec).**
   - **Defect:** `B747_fuel_temp_init_flag` and `fuel_temp_c` are never reset in `flight_start` / `B747_fuel_system_start`.
   - **Scenario:** a new flight or flight-test scenario without an aircraft reload starts with the previous flight's cruise-soaked temperature, for example −25 °C on a warm ramp. It then creeps toward TAT with a time constant of about 10,000 s, both in the displayed value and in `inp.temp`.
   - **Consequence:** FUEL TEMP LOW can carry over into the next flight if the last one ended at −37 °C or below.
   - **Severity:** minor.
   - **Confidence:** confirmed by reading; existed before this change.
   - **Fix:** clear the init flag in `B747_flight_start_fuel()`.

No crash/freeze defect found in the reviewed changes.

**Checked and fine**
- **Auto fuel model (B747.28.fuel_auto_model.lua):**
  - The cas keys it reads match the fuel model's names: `low_ctr_*`, `ovd_ctr_*`, `pmp_stab_*`, `pres_stab_*`, `tank_eng`.
  - The step and cancel pairs work, and the stab retry happens only once with no cycling, even with a failed STAB pump.
  - Pilot-move detection works, and a push is confirmed before its 3 s timeout even at 16x and 20 fps.
  - Pilot flags and the retry state are cleared on the ground, and the option's OFF clears pilot flags.
  - Steps act only in the air, with flaps UP and the jettison selector OFF.
  - The steps match the FCOM text on p.134-135.
  - No table is allocated per frame except on a push.
- **Fuel glue:**
  - The auto step runs only after settling, never in replay, and the option is read every frame.
  - `AUTO_SWITCH` indexes 48, 51, 52-55 and 64-67 match the manipulators' phase-0 toggle handlers.
  - The X-Plane-time dt (clamped 0-1 s) drives the model, the burn and FUEL USED.
  - The synoptic OJ, manifold and jettison statuses now come only from the model, with no stale writers left in the std/jett synoptic functions.
  - The W&B field 11 is ignored by the fuel handler, which takes only field 10.
  - Top-level locals: 59.
- **XTLua pitfalls:**
  - The new global model tables have metatables, so they are not namespace-wrapped.
  - No new self-rearming `run_after_time`.
  - No dataref rebinding clashes (grepped each new name per module).
  - The cross-plugin reads (the option, `gen_field_open`, `breaker/ssb`, `display_has_power`) are read every frame.
- **aero_corr model:**
  - Swept 150-397 t, sea level to FL450, M.10-.95: no NaN, no jumps.
  - The q < 1000 Pa gate is continuous.
  - `aero_corr_off` removes every term.
  - Inside VMO/MMO the clamp at 0 is reached only at 330 t or more, FL230-300, M.865-.87. It saturates there, which is benign.
- **Electrical:**
  - `out.gcr` is filled on every update before `write_buses`, with no early return.
  - FIELD OFF and SSB OPEN have the right sense (`breaker/ssb` 1 = closed).
  - CDU lighting indexes [7] (F/O transfer bus) and [8] (main standby bus) match elec_buses.
- **Manipulators:**
  - The only other callers of the replaced `sim/autopilot/vertical_speed` and `level_change` are in the autopilot monitor's `VNAV_CLB` and `VNAV_DES`. That code is dead, because `VNAV_modeSwitch` returns for every `vnav_state`, so no VNAV-to-FLCH loop.
  - The old generator handlers re-issued their own replaced commands; that is now fixed.
  - No other callers of the generator commands.
- **Bridge (C):**
  - Builds with `-Wall -Wextra` with no warnings, byte-identical to the committed win.xpl.
  - The in-use and kept option values are split correctly: the menu and toggle commands keep, a dataref write does not, and the Pilot ID save writes only kept values.
  - Menu item indexes are unaffected by `NOPTS` 4.
  - `wb_box[WBF_N=12]` and the edit buffer stay in bounds.
  - The FMC's cargo spread sums to the total within each hold's limit.
- **failures.txt:**
  - `igniter[0..7]`, `hot_start[0..3]` and `egt_high[0..3]` are created with matching sizes.
  - Igniter 2 is `[n+3]`, consistent with the engine start glue.
- **Regression suite:** 248/248 pass.

