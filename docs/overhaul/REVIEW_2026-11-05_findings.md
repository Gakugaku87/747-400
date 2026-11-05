# Fable review of the overhaul (2026-11-05) — raw findings as received

Reviewers: 1 FMC navigation, 2 FMC performance/VNAV, 3 FMC CDU/datalink, 4 AFDS/A/T, 5 displays/ND,
6 electrical/warnings/misc, 7 hydraulics/air/anti-ice, 8 engines/EEC/fuel/APU, 9 flight controls/gear/nav,
10 bridge plugin/loaders/kit. Paused at ~14:20; 1, 5, 6, 7, 10 stopped at their start by Fable's weekly limit
(reset 16:00 JST); 2, 3, 4, 8, 9 sent partial reports (below). Resumed 16:00.

## 4 AFDS / A/T (partial)
Tests: all nine tests/autopilot pass.
1. Medium/confirmed — A/T model and glue latches not reset at flight_start: B747.70.xt.autopilot.lua:1538-1542
   (B747_afds_reset) recreates afds/afdsRoll/afdsPitch only; not reset: atState (1004), vnavLevel (709),
   atIas/atAccel (1006), atSeen/atPush (1007-1008), afdsTogaPushes (961), atMaster/atMasterOK/atFmcLatch (1011),
   lastHdgRefSwitch (2263). A/T engaged at the end of a flight + new flight with ARM off → at_model.lua:189
   disengage(s,true) → AUTOTHROT DISC caution in the new flight (glue 3494-3495); to/ga/retard/idle_hold/thr_hold/
   flch_vs, acceleration filter, vnavLevel carry over. Fix: reset them in B747_afds_reset.
2. Medium/confirmed — afds_inp() runs 3x a frame, afds_pitch_inputs() 4x (glue 1124-1201 ~80 reads; called from
   B747_afds_update 1528, B747_afds_roll_fma 1443-1445, B747_afds_pitch_fma 1492-1494; afds_pitch_law 1411; and
   every switch handler). XTLua thread; ~3x input cost. Fix: fma functions take state + afds_old_vnav_fma() only;
   handlers reuse the frame's afdsIn.
3. Low/confirmed — at_model.lua:322-331: thrust_ref 0 with thrust>0 → cap/limit negative → SPD/THR drive levers
   aft. Ref 0 only right after aircraft_load (EEC clear_thrust_targets B747.42.xt.EEC.lua:577-583). Fix: ref<=0 →
   no reference (cap = limit = huge).
4. Low/confirmed path — B747.70.xt.autopilot.monitor.lua:476-485: vnav_state 0 and ap_inDescent 1 →
   setDescentVSpeed every 0.2 s (vnav.lua:48-124): decodes vnavProfile JSON, overwrites vnav_target_alt,
   fmstargetDistance, ap_vb, ap_fpa; at RA<=10 ft (dial >=600 ft below) writes autopilot_vs_fpm -250 and
   ap_thrust_mode 0. Fix: remove the call (FMC VNAV owns these).
Not found wrong: afds_model latches/arms, roll_model, pitch_model, at_model engage/mode, afds_at, after_physics order.
Not covered: reference checks (_ref), ATA-22.md etc., test contents, B747.19.xt.afds_control.lua (servo law NaN/limits),
init script plugins/xtlua_keysystems/init/scripts/B747.70.autopilot (main-thread handlers; toga_pushes reset),
old vnavspd/vnav code, FMA box timers (3154-3257), knob handlers' timer churn (2177-2223).

## 8 Engines / EEC / fuel / APU (partial)
1. Medium/confirmed — two full GCs per frame on the whole xtlua plugin heap: B747.25.xt.fuel.lua:1754 and
   B747.42.xt.EEC.lua:1158 collectgarbage("collect") at the top of after_physics; one Lua state per plugin
   (init.lua run_module_in_namespace), so each pass marks/sweeps every module's heap; both also allocate per frame
   (fuel model temp tables/closures; EEC column() tables, 4x B747_eec_reference, find_closest_* build+sort in CRZ
   B747.42.xt.EEC.PW.lua:566-567). PROGRESS.md:1197 already flags EEC. Fix: delete both (incremental GC), or a
   step every few seconds from one module.
2. Low-medium/confirmed — dead writes: B747.40.xt.engines.lua:494-496 and 774-776 assign B747DR_ap_vnav_state,
   B747DR_ap_inVNAVdescent, B747DR_ap_flightPhase, never bound in the engines module → plain namespace values;
   reverse never resets VNAV/flight phase as intended. Fix: bind or delete (A/T model owns it?).
3. Low/confirmed — B747.42.xt.EEC.lua:512-519 flight_coefficients: tas 0 → cL = cD = inf → NaN in in_flight_thrust
   (660), climb_angle asin(inf) (EEC.PW.lua:202, EEC.GE.lua:199); results overwritten by B747_eec_reference/max
   (PW 610-614, 644; GE 574-587) so dead computation + garbage. Fix: remove dead CLB/CRZ/GA branches or floor tas.
4. Likely (page unchecked) — engine_start_model.lua:144-151, 224: autostart opens the start valve only with RUN;
   with AUTOSTART ON, START pulled at CUTOFF → no motoring until RUN. Code cites FCOM p.862/879; needs checking.
Looked sound: fuel glue sequencing, fuel model, engine start glue, reverser, engine display, APU model/glue, eec_update,
thrlim decoding, rating tables read so far, idle N2 vs 60 % cull.
Not covered: eec_model.lua 667-841; EEC.tbls.lua (TOGA_N1_GE_adjustment keys -2000..10000 complete? missing → nil
arithmetic stops the plugin, EEC.GE.lua:457-467), EEC.RR.lua, pid.lua, exceedance_model.lua; APU parts of
elec_model; fuel refueling/balance; reference checks; tests (engines, eec, fuel, apu).

## 9 Flight controls / gear / nav (partial)
1. Medium/likely — SRM "outside change" detector (B747.45.xt.srm.lua:230-246) compares X-Plane's trim with the last two
   written values (TRIM_SAME 1e-4); at the fast rate (0.002/frame) a read lag >=3 iterations → stab_set snaps the
   model back and clears speed trim (srm_model.lua:181-186). Speedbrake same pattern but RATIO_SAME 0.01. Fix: longer
   history or band test.
2. Low/confirmed — brake temps start at 0 °C on the first flight: B747.10.xt.wheels.lua:74-78 BT.new(simDR_whl_oat) on
   the first after_physics frame (first read 0); 90-min relax. Fix: seed with OAT after INIT_S.
3. Low/confirmed — B747.45.xt.fltCtrls.lua:811-812, 889-914: config_gear_thrust/flaps/after_lo not reset in
   flight_start (1076-1081); air start inherits 140 s/800 ft inhibit. Fix: clear them.
4. Low/confirmed — B747.45.xt.fcu.lua:103-108 gear-in-transit checks gear 0..2 only (not wing gear 3,4). Fix: 0..4.
5. Low/perf — ~20-30 small tables/frame (fcu_model 354/360/368/486, tocw_model 380, srm_model 240/361/383,
   airdata_model 392 ipairs({...}), gpws_model 395-396/416/437).
Freeze: xt command handlers only set flags; handlers for IRS/gear lever/autobrake/speedbrake live in the init scripts
(main thread) — not yet opened; first place on resume.
Verified consistent: gear index maps, bus indices, trim unit mapping, FCU detents, PSEU arg order.
Not covered: init scripts (gear, fltCtrls, nav knob handlers); init array sizes (tcas/sym >=64, advisory_status >=302,
status_status >=154); reference checks (p.1513, 1515-1516, 958, 954, 1227, 1559, 1197-1198); tests; tiller latch
assumption (joy_mapped_axis_value[37] 0 without a tiller); autobrake vs FCOM; radio tuning; notes cross-check.

## 2 FMC performance / VNAV (partial)
1. Medium/confirmed — DES NOW predictions above CRZ ALT and overstated times: pred_model.lua:600-603, 662-673 startDes
   uses path_at_x(dp, lx[i]) and base path_at_x(dp,0); descent path built up to CEIL 45100 (132); glue passes
   phase "des" when vnavState.phase == "DES" (xt.fms.lua:1417-1419) which des_now sets while T/D ahead
   (vnav_model.lua:128-132) → e.g. FL451 at next waypoints. vnav_model:401 clamps for guidance; predict doesn't.
   Fix: clamp to min(path, s.alt); base at path_at_h(dp, s.alt).
2. Low/likely — unflyable step climb re-entered each cruise step (pred_model 627-641, 538-541): climb_to "unable"
   not handled → one sc per minute. Fix: remember and skip.
3. Low/confirmed — T/D level-decel cache keyed on altitude only (505-511), depends on kg. Key on weight band.
4. Low/confirmed — per-frame allocations: xt.fms.lua:2115 B747_fms_schedules every frame (1290-1328); :2138
   perf_db.hold() every frame in descent (perf_db 697-708); vnav_model:177 new s.to each frame on ground.
5. Low/likely — xt.fms.lua:1618 drops all predictions when CRZ ALT >= max_alt (1.3 g) — e.g. CRZ ALT = MAX.
   Real FMC refuses the entry. (ATA34_2 p.611 unchecked.)
6. Low/likely — predicted step climbs fly the climb schedule (pred_model 632) while VNAV flies cruise speed
   (vnav_model 461-463). (FCOM p.1257/1261 unchecked.)
7. Low/likely — vnav_model 410-425, 447: crz_last updated every frame; CRZ ALT lowered below the airplane during a
   cruise climb → no cruise descent: VNAV PTH with alt below and vs nil. Update crz_last only in CRZ.
Minor: perf_db 662 thrust-limited flag cells; update_econ every 5 s ~2,000 evaluations.
Sound: pred/vnav/perf_db/thrlim/wind/rta/fuel/eo/crz/ldgalt/vref/perf_factors models and glue sections read.
Not covered: all pages (vnav, desforecast, wind, takeoff, perfinit, thrustlim, approach, maintperffactor, progress);
perf_fuel_t nil at xt.fms.lua:1434?; update_takeoff, update_appr_ref, monitorCRZALT (pages.lua:536),
update_spd_trans (797), auto step climb; tests; reference checks; timing of predict/rta.

## 3 FMC CDU / datalink (partial)
1. Medium/confirmed — whole FMS data table JSON-encoded every frame: B747.68.xt.fms.lua:5965
   (B747DR_FMSdata=json.encode(...) in after_physics) and :782 (in setData on every field write; update_perf calls it
   when GR WT changes). ~125 fields, ~250 allocations + ~3 KB string + string dataref write per frame. Inherited from
   upstream (041c9ffa 690/715/1231). Fix: dirty flag; encode once per frame only when dirty.
2. Low/likely — setData latent errors: :772 string.len(self["data"][id]) for an unknown id → namespace missing-key
   stack overflow or string.len(nil) (stops the plugin); :768 writes nil; :773-774 truncates to 3 chars not to len.
   No current caller with an unknown id. Fix: rawget guard; truncate to len.
3. Low/likely — B744.fms.pages.lua:487-492 (custom2fmc), 509-515 (key2fmc): one :once() per character in one frame;
   repeated characters may be lost (TESTING.md §4.6 EDDF→EDF). Pages still using them unchecked.
4. Low/confirmed — acars.lua:254-255, 309, 325-333 read message fields directly on namespace tables (telex without
   title, cpdlc without rr) → draw error (under pcall: blank page). Fix: fld() rawget helper.
5. Low/confirmed — B747_fms_report_status (xt.fms.lua:4653) calls B747_fms_report_ctx() twice (posrep defaults + route
   text walks); if the ATC REPORT page calls it per entry per frame, ~18 route walks/frame. Compute once.
6. Low/confirmed — SimBrief answer parses the OFP XML synchronously in after_physics (xt.fms.lua:4992-5033;
   simbrief_model 128-165 eight whole-file matches); OFPs hundreds of KB → tens of ms; re-parsed for the wind
   request (5123-5132). Cache by name/mtime.
Sound: cdu_model, createfms (keyWait/keyQueue), ATC glue, fmc_link, simopts, the 2026-11-05 convenience.
Not covered: setdata (763-2581) other branches; 2581-2888 functions; INITREF/NAVRAD pages; which pages use
custom2fmc/key2fmc; all ATC pages, fmccomm, maint*, doors, efisctl, identpage, groundhandling, soundconfig,
acars.pages*, autoatcHoppieProvider; glue 200-600, 890-3643 parts, 3727-3895; per-key B747DR_fdr_log_json write
(createfms.lua:361-365); tests; references.

## 10 Bridge plugin / loaders / init scripts / kit (complete)
Static tests hitch_log, interfaces, modules_run, xt_bindings_created pass.
1. High (for the symptom)/likely — X-Plane FMS plan load on the main thread after every route edit:
   b747_fms_bridge.c:327-346 triggered by xt.fms.lua:2651 (1 s after the route last changed): loop of
   XPLMClearFMSEntry over every entry, XPLMLoadFMSFlightPlan, XPLMSetDestinationFMSEntry, all in the flight loop on
   the drawing thread; per-entry clears can each trigger re-sequencing. Plausible 0.2-1 s stall on a slow PC. The hitch
   log measures it. Fix: drop the clear loop (load replaces the plan; or clear entries beyond the new count after the
   load), longer debounce (3-5 s or only after EXEC), skip a load identical to the last.
2. Low/confirmed — loader timing wrappers preserve behaviour (all_timers keyed by the original; first result returned;
   nil before/after pass; errors propagate; do_callout re-raises). Only fragility: relative Output/ path (cwd).
3. Medium/likely — kit: run_scenario.ps1:157-171 Test-XPStuck: sim time not moving for 30 s = hung, but it stops while
   paused → s205 (pause at T/D) etc. falsely fail. Fix: check sim/time/paused.
4. Low/confirmed — kit: check/wait on an array dataref without an index: PowerShell -eq on arrays filters → passes when
   any element matches (run_scenario.ps1:129-143, xp.ps1:60-69). Fix: throw on arrays in Test-Op.
5. Low/confirmed (upstream) — B747.05.xt.simconfig.lua:313-319: F/O inboard display option tests SIM.capt_inbd
   instead of SIM.fo_inbd.
6. No defect — B747.95.xt.AI collectgarbage calls are load-time only (top level), not per frame.
7. Sound — init/xt binding names and types (static test + 16 checked).
C code sound: memory bounds, SimBrief thread isolation, SDK lifetimes, other main-thread costs negligible.
Mock gap: bridge-created datarefs unknown in the mock unless types passed → writes dropped silently.
Not covered: fwl/*.lua, tools beyond run_all.sh, acf-editing scripts, rest of AI/manipulators, init scripts line by line.

## 6 Electrical / warnings / com / fire / oxygen / safety / lighting (complete)
All 17 tests of these areas pass.
1. Medium/confirmed — ELEC UTIL BUS L/R and UTIL OFF lights follow the switch only: elec_model.lua:553
   (lt.util_off = not inp.utility[k]) and :588 (cas.util_bus = not inp.utility[k] and shed == 0). FCOM (109 message
   logic, text lines 42815-42818 and 41894-41896): one or more utility buses unpowered for any reason (fault, ELCU,
   AC bus lost) or switch OFF; inhibited during load shed (41546). Fix: unpowered per side, gated by shed == 0.
2. Medium/likely — electrical state never reset at flight start: B747.03.xt.electrical.lua:631-638; elec_state
   (elec_buses.lua:73) created once; battery Ah, gcr_trip, btb_fault, permits, idg_connected, shed, iso, apu start
   relay, charger timers persist across a new flight without reload (flat battery after a C&D on batteries; GCR
   tripped after a fire handle pull). Fix: B747_elec_reset() = E.new() called from B747_flight_start_electric.
3. Medium/confirmed (latent) — duplicate EICAS memo slots: B747.87.xt.warning.lua:575-577 and init
   B747.87.warning.lua:498-500: index 41 both ACARS CALL and ACARS VOICE; PRINTER MESSAGE at 28 and 42. No writer of 41
   today. Fix: ACARS VOICE its own index; drop one PRINTER MESSAGE; keep both tables identical.
4. Low-medium/confirmed — per-frame string building/dataref churn: B747.15.xt.acp.lua:150-185 builds ~100 dataref
   names by concatenation and writes all each frame; held121/nav_audio allocate; rtp.lua:149-150 5 tables/frame;
   com.lua:434/451 print in PTT handlers; elec_model M.update ~50 small tables/frame. GC pressure. Fix: precompute names.
5. Low/confirmed (upstream) — B747.90.xt.lighting.lua:898 for i = 0, 32 over array[32] (index 32 out of range); also
   :850-853. Test doesn't cover B747_cabin_lights. Fix: 0..31.
6. Low/confirmed — B747.35.xt.fire.lua:476 B747DR_smoke_evac_handle = 0 but never bound in the xt script (only the
   init script) → plain global; handle not reset at flight start. Fix: find_dataref.
7. Low/likely — lighting.lua:873-878 display power 6 as an animate target with max 1 → one-frame overshoot 1.14.
   Fix: target = power > 0.5 and 1 or 0.
8. Low/likely — >STBY POWER OFF (advisory 278) never raised; FCOM p.823 to be checked before adding.
9. Low/confirmed (latency) — alerts glue reads inputs every 0.1 s (alerts.lua:245-250) → up to ~200 ms late.
Freeze: nothing bursty on switch presses or bus power-up; first frame after load blanks 550 string slots once.
Sound: index bases, no Lua-error paths, EXT PWR logic, alert model, inhibits vs notes, fire/oxygen/acp/rtp models.
Not covered: B747_annunciators body (sampled), APU (excluded), FCOM page-by-page inhibit windows, tests audited.

## 7 Hydraulics / bleed / air conditioning & pressurization / ice and rain (complete)
tests/run.sh 212 pass.
1. Medium/confirmed — hydraulic quantity never clamped at 0; demand/AUX pumps ignore it: hyd_model.lua:279
   ss.qty -= qty_use (no floor); hyd_power.lua:121,127 keep feeding leaks after empty; only the EDP checks qty > 0
   (213); ADP/ACMP (232-243) and AUX (254) don't. With a leak in AUTO the demand pump holds ~2850 psi forever (no
   HYD PRESS SYS) contrary to ATA29_32 p.104 standpipe reserve and FCOM 13.20.2; res_n/restotal_n go negative and show
   on the synoptic. tests/hyd/hyd_model_test.lua:248 asserts the unbounded behaviour. Fix: clamp at 0; small reserve
   for demand/AUX (estimate), then 0 flow; adjust the test.
2. Medium/likely — simDR_startup_running first read inside flight_start/first after_physics (XTLua gives 0):
   hyd_power.lua:230, B747.20.xt.hydraulics.lua:372-380 (do_flight_start on the first frame → demand pumps OFF),
   B747.55.xt.air.lua:509-517, B747.50.xt.antiice.lua:353. On an engines-running start → demand selectors OFF, packs
   OFF (HYD PRESS DEM 1-4, PRESS lights). PROGRESS.md:1182 already records "the first flight after starting X-Plane
   begins cold & dark even when engines running is requested". Mock sets the value before flight_start. Fix: read it
   every frame first / defer the CD/ER choice past INIT_S; verify with an engines-running start.
3. Info — HYD PRESS DEM light/advisory logic matches FCOM 13.10.2 p.1484 and 15.20.
4. Low/confirmed (transient) — press_model.lua:233 p_land from the baro first read 0 for one frame; guarded by INIT_S.
5. Low/confirmed (cosmetic) — bleed.lua:151-155 ground-air auto-disconnect on pri_gnd's first read 0.
Freeze: handlers are one write each; per-frame cost small (press bisection ~100 pow, temp 7 exp, override one table).
Reference checks passed: ADP/ACMP AUTO logic, DEM/ENG inhibits, brake sources/accumulator, pack flow schedule,
engine-start packs vs APU capacity, WAI/NAI, windshield heat, probe heat.

## 4 AFDS / A/T — resumed, complete (new findings)
5. Medium/confirmed — A/T SPD and THR switches dead below 400 ft RA on approach: at_model.lua:236-247
   air = not ground and ra > MIN_RA (400) at every point of the flight; FCOM p.641-642: operative from 400 ft after
   takeoff until landing. Test at_model_test.lua:134 locks it in. Fix: latch airborne once above 400 ft after
   lift-off, cleared on the ground.
6. Low/confirmed — THR switch conditions differ from FCOM p.642 table (THR REF: CLB/CLB1/CLB2/CRZ/CON limit with
   ALT or V/S; GA limit with G/S or FLARE, or ALT/V/S with landing flaps). Model refuses THR REF on GA limit in
   G/S/FLARE (test at_model_test.lua:140 asserts it) and allows it with CLB limit in T/O, G/A or no pitch mode.
Sound: autopilot init script (main thread) only creates datarefs/commands, no handlers/per-frame work → the freezes
are not from the autopilot/A/T modules; toga_pushes never reset but no spurious push (finding 1's TO/GA part
dropped; A/T-state carry-over confirmed at at_model.lua:189,166-170, glue 3494-3495); afds_control servo laws (no
NaN path); FCOM p.656, 663, 646, 667, 641, ATA22 p.282 checks passed; old VNAV/monitor paths inert except finding 4;
timers fine; tests genuinely exercise the code (no test of a second flight_start).

## 8 Engines / EEC / fuel / APU — resumed, complete (new findings)
A. HIGH/confirmed (reproduced in LuaJIT) — P&W CRZ thrust limit → Lua error every frame → whole xtlua plugin stops:
   B747.42.xt.EEC.PW.lua:557-569 (CRZ branch) calls find_closest_weight/altitude(P85M_epr_PW4062) (EEC.lua:133-184);
   P85M_epr_PW4062 (EEC.tbls.lua:566) is [weight t][alt kft] = EPR but find_closest_weight collects inner keys (alts) →
   returns 45 for 270 t → nil row; find_closest_altitude iterates pairs on a number → "bad argument #1 to 'pairs'".
   Reachable: THRUST LIM page CRZ in the air (xt.fms.lua:2311 → thrlim 30 → eec_thrust.lua:177-181 "CRZ"), or PERF
   FACTORS THR/CRZ = CRZ at T/C (thrlim_model.lua:149-153; default CLB since §247). Inside EEC after_physics → stops
   every module of plugins/xtlua (fuel, electrical, gear, manipulators, engines, EEC). GE unaffected. Branch results
   dead anyway (overwritten 610-614, 644). Fix: delete the PW CRZ branch (and legacy TO/CLB/GA branches); add eec
   module tests per mode for types 0 and 1.
B. Correction — first report's finding 4 withdrawn: FCOM p.879/p.862 confirm autostart: START arms, RUN initiates.
C. Low/confirmed — EEC model allocates ~60-100 small tables a frame (eec_model.lua:777-780 out, overspeed 665,
   idle_selection 735, column 482-489 x2 per lookup, 4x eec_reference) then full GC sweeps the plugin heap.
Sound: TOGA_N1_GE_adjustment keys complete; eec_model 667-841; pid; exceedance; APU vs FCOM 7.30/7.40; fuel vs FCOM
12.20; syntax; tests (17 files, 1,156 checks pass; gap: EEC glue thrust-limit branches untested).
   [Coordinator check 16:2x] Confirmed by reading: P85M_epr_PW4062 = {[weight] = {[alt] = epr}}; find_closest_weight
   collects inner (alt) keys; find_closest_altitude does pairs() on the EPR numbers (error); set_engines() calls
   PW(simDR_altitude) for engine type 0 (and unknown types); thrlim code 30 → "CRZ" (eec_thrust.lua thrlim_mode).

## 2 FMC performance / VNAV — resumed, complete
Corrections: finding 1 (DES NOW) CONFIRMED BY RUNNING (scratchpad pred_check.lua): FL350, T/D ~130 NM ahead, phase
"des" → waypoint 30 NM ahead 45,250 ft and t = 0; destination 1,400 s instead of 2,181 s (13 min EARLY): x = 0 and the
near waypoints on the path's ceiling plateau (CEIL 45100). Test pred_model_test.lua:183-189 starts at 25,000 ft so
can't catch it. Finding 5 sourced: ATA34_2 p.611 (CRZ ALT >= MAX → fuel predictions not shown) but the code also drops
path, T/D, LEGS altitudes, descent VNAV validity, INSUFFICIENT FUEL; MAX ALT message only for > (pages.lua:1151) →
CRZ ALT = MAX silently no path. Keep low; keep the trajectory, blank ETA/fuel only. Finding 6: FCOM p.1257 silent;
keep low/likely. perf_fuel_t nil worry unfounded (fallback). GA on flap extension per FCOM p.672: fine.
New:
1. Low/confirmed — DES page SPD TRANS can't be deleted (pages.lua:1009-1019 destrans no DELETE branch → INVALID ENTRY)
   while CLB clbtrans allows it (FCOM p.1328); clbrest/destrans/desrest store the speed even when the altitude is
   invalid, no message; validAlt (567-577) old line fit from X-Plane weight, refuses < 2,000 ft.
2. Low/confirmed — update_spd_trans (xt.fms.lua:797-803) hard-codes 250 kt; FCOM p.1328: greater of the origin's
   transition speed (nav DB) or VREF+100; reads Vf30 each frame → creeps with fuel burn.
3. Info/measured — performance side can't cause hitches: predict 2.1-2.7 ms (5,000 NM, 40 legs, steps, wind) every
   10 s; econ 0.1 ms/5 s; page lookups 0.025 ms; json.encode of FMS data 0.08 ms/frame; CRZ ALT entry runs a predict
   (~3 ms) in the key handler. (LuaJIT outside XTLua.)
4. Low/confirmed — stale prediction indices one frame after sequencing (xt.fms.lua:1685-1687, progress.lua:268-270,
   :43-44): PROGRESS 1 s cache can show the passed waypoint's data under the next name for up to 1 s.
Overall: models pure and sourced, tests real; DES NOW prediction the one to fix soon.

## 1 FMC navigation (complete)
tests/run.sh 212 pass.
1. Medium/confirmed (coordinator confirmed) — POS INIT page reads a file every frame per CDU: posinit.lua:97 getPage
   page 1 → aircraft_last_pos("LOAD") (xt.fms.lua:5713-5724) io.open/io.read/io.close of <livery>/B747-400_lastpos.dat;
   createfms.lua:821-826 rebuilds pages every frame for each CDU. POS INIT is the page up during a C&D preflight. Also
   io.input(file) never restored. Inherited from upstream (041c9ffa). Fix: read once (load / page entry); drop io.input.
2. Medium/likely ("likely the freeze after CDU input") — CIFP parse and navdb grids built synchronously in the frame of
   a CDU entry: navdb.lua:449-497 M.cifp reads a whole CIFP/<ICAO>.dat (lines, 2 gmatch passes, a table per leg) on
   first use: ORIGIN/DEST entry (route_model 267, 1123), DEP ARR page (proc_model 71-133), REF NAV DATA, dest_ils/
   update_ldgalt (xt.fms 3379, 3473). Navigraph CIFP up to 410 KB (LFPG, LTAI, LTFM ~400 KB; KDFW 330 KB) → tens to
   hundreds of ms in one callout on a slower PC. M.variation (533-547) and M.radio_near (568-582) build 2° grids on
   first call over all db.n points (~290k lines) — first LEGS draw / route entry / first navperf scan. Navdb loader
   itself incremental (32 KB/frame). Fix: parse CIFP in blocks over frames (or pre-read origin/dest on ICAO entry);
   build the grids in finish() during loading. Hitch log should show >0.2 s callouts.
3. Medium/likely — routes >100 X-Plane plan rows stall the FMS sync for good: route_model.lua:1306-1309 to_fms drops
   arcs then passed legs, but >= ~96 legs still >100 rows; bridge loads as is (b747_fms_bridge.c:341-342); X-Plane keeps
   100; B747_fmc_route_sync returns every frame at xt.fms.lua:2664 (getn(fms) ~= routeMap.n) → fmscurrentIndex/
   xp/current never written; plan_ctr_sync returns at 2881. AFDS reads X-Plane's plan and fmscurrentIndex (autopilot
   2604-2764); ND PLAN centre uses the displayed entry. Long SimBrief oceanic routes (80-110 waypoints). Untested.
   Fix: cap in to_fms (drop far legs keeping ADES; keep map consistent) or compare against min(n,100).
4. Low/confirmed — nav pages heavy work 3x per frame per CDU (createfms 822-825 getNumPages/getPage/getSmallPage):
   DEP/ARR dep_columns/arr_columns, P.runways per SID (deparr 75-83; proc_model 111-133) — tens of thousands of
   iterations/frame for a big airport; LEGS variation 6-ring search for 5 legs twice (legs 122-128, 337); FIX INFO
   fix_path over the whole route + 3 crossings per render (fixinfo 150-176). Compute once per frame/route change.
5. Low/likely — turn caches keyed on raw wind speed (xt.fms 2399-2404, 2528-2537; nd_line_model 85-94): gusty wind →
   key flips → flyover_path/transition up to 600 LNAV steps per turn; 10-50 ms spikes. Round/filter the wind.
Sound: route model, path/LNAV geometry, hold entry sectors (FMSPG p.165), racetrack (p.224), PT, variation signs, navdb
decoding/airways/AIRAC/incremental load, procedures, tuning/navperf/altn models, FMS sync path. No Lua-error path.

## 9 Flight controls / gear / nav — resumed, complete (new)
1. Low/confirmed — autobrake keeps the landing setting armed after normal brake pressure loss
   (autobrake_model.lua:437-440, 452) per ATA29_32 p.518; FCOM p.1515-1516 lists loss of normal brake pressure as an
   immediate disarm (selector to DISARM). CLAUDE.md: FCOM for crew-visible behaviour. Test autobrake_model_test.lua:107
   locks the ATA behaviour. Fix: follow FCOM, or document the choice.
2. Low/confirmed — two memo tables disagree on IRS ALIGN MODE L/C (init B747.87.warning.lua:471-473 14=C,15=L; xt
   B747.87.xt.warning.lua:548-550 14=L,15=C); xt is the one shown; init only sizes the array. Swap in init.
3. Low/confirmed (coverage gap) — the mock's immediate reads mean INIT_S guards and outside-change detectors (srm,
   speedbrake) only run their trivial path in tests; suggest a lagged-read mode in the mock.
4. Freeze: main-thread work in gear/fltCtrls/nav init scripts trivial (gear lever 3 comparisons + 1 write; speedbrake
   lever snap + 1 timer); IRS/transponder/autobrake knobs in xt scripts; radio tuning uses X-Plane stby_com commands only.
5. Reference checks all consistent: tiller/pedals (14.10.2), RTO/landing autobrake/disarm list (p.1515-1516),
   >SPEEDBRAKES EXT (p.958), load relief (p.954), IRS (p.1227), altitude alert (p.1559), disagree thresholds
   (p.1197-1198); CAS slot names and array sizes OK.
6. Tiller latch assumption unverifiable offline (consistent with the user's log).
Overall: good shape; SRM trim-ownership detector the behavioural risk.

## 5 Displays (complete)
1. Medium/confirmed — nd_line.c:380-411 (ndl_side) and 417-461 (ndl_draw): every route leg subdivided (up to 64
   pieces of 60 px) and each piece projected (~25 transcendental calls) BEFORE any visibility test; ndl_draw runs in the
   gauges phase for render passes 0 and 2 (ndl_passes 5) → twice per frame per side. 10 NM range, 30-leg long-haul
   route → ~7,700 piece projections every frame on the MAIN thread, nearly all off-screen (+ circles 8x72). Constant
   load at short ranges with long routes. Fix: reject legs whose chord can't touch the visible circle before
   subdividing; subdivide only the visible t-range; or compute once per frame for both passes.
2. Medium/confirmed — ND module XTLua-side cost: collectgarbage("collect") per frame (~0.3-1 ms with its tables);
   updateNDLatLong json.decodes xtlua/xpFMSData every frame when not in PLAN (1368); updateIcons ~12 trig per slot up
   to 120; TCAS 63 reads + sort; read_fixes reads 26 lines/frame of earth_fix.dat continuously; newIcons every 0.2 s
   getDistance for every route entry/navaid/fix twice; decodeFlightPlan every 2 s json.decode of fmsJSON and
   route_eta unconditionally (string equality would skip); newIcons twice on the 2 s tick. Measured: route 150 entries
   0.3/0.6 ms; navaids 1,500 entries 2.8/5.6 ms. The 0.97 s first frame is NOT explained by the Lua work: likely
   XTLua's own first navaid scan (update_localNavData scans the whole nav DB on its first pass; reading xtlua/navaids
   re-enables scanning) — the Lua thread's first read of xtlua/navaids/fms may block on it (not confirmed).
   Suggest per-step os.clock timing in after_physics before changing; then: no per-frame collect, decode fms by string
   equality, decode xpFMSData only in PLAN, box-filter navaids before getDistance.
3. Medium-low/confirmed — WPT fixes stale and from the default AIRAC; missing file stops the plugin: read_fixes
   (1210-1265) 240,646 lines at 26/frame → a pass takes 2.6-5 min, then 10 s idle → WPT list lags up to a pass (20-40
   NM); opens only Resources/default data/earth_fix.dat while navclass and CIFP prefer Custom Data (Navigraph);
   fix_data_file:read right after io.open with no nil check → Lua error stops all xtlua_nd modules if absent.
   Fix: Custom Data first with nil check; index once into a 1° grid; no continuous re-reading.
4. Low/confirmed — F/O TCAS symbols use the Captain's track and true heading (632-637 tcasSide).
5. Low/confirmed (upstream) — fltInst02.lua:2303 200000.0 should be 20000.0 for Va (unused dataref).
6. Low — ND file-reading paths untested (tests set debug/nd -2).
Sound: updateIcons out-of-range read returns 0; TCAS gating vs FCOM p.1152-1153; STA/WPT/ARPT vs p.1040/1145; route
symbols p.1148-1149; display models; minspeed (p.972-973); displays glue write-on-change and indices; panel
generators; display tests real.
Not covered: to_speeds tables, clock, parts of fltInst02, init script, some panel generators, some tests.

## 3 FMC CDU / datalink — resumed, complete (new)
1. HIGH/confirmed — TAKEOFF REF CG entry before any GR WT/ZFW → Lua error → whole xtlua_keysystems stops (FMC, AFDS,
   displays): pages.lua:1529 calc_stab_trim(fmsModules["data"].grwt, ...) with the string "***.*   ";
   xt.fms.lua:486 GW * kgs_to_lbs → arithmetic on a string. Reachable on the ground: INIT/REF INDEX → TAKEOFF → R4 with a
   typed CG, or since the 11-05 convenience (default ON) R4 with an empty scratchpad. setdata has no pcall. Untested
   (takeoff_ref_test enters ZFW first). Fix: tonumber(grwt); skip calc_stab_trim (trim blank, FCOM p.1320) when nil;
   test "CG before any weight".
2. HIGH/confirmed — PAX/CARGO L1 fractional count (e.g. "30.5") → infinite repeat...until (x == 0) in the handler
   (pages.lua:1568-1606; x goes 0.5 → -0.5) → XTLua thread hangs forever. Upstream. Fix: until (x <= 0) or floor x.
3. Medium/confirmed (upstream) — ACARS INITIALIZE page never draws: acars.pages.lua:99-100 reads fmsJson (the global
   is fmsJSON) → string.len(nil) under pcall → blank page; when fixed, :98 re-posts CRUISE ALT NOT SET every frame.
4. Low/confirmed — VERIFY REPORT, ATC REPORT, EMERGENCY pages rebuild the report context up to ~8x per frame per CDU
   (atcreport.lua:110-131, emergency.lua:33/39/56/125; report_status calls report_ctx twice). Cache per frame.
5. Low/confirmed — invalid entry on ACARS WEATHER's ATC field logs off ATC COMM instead of INVALID ENTRY
   (weatherrequest.lua:53 → setdata atc → B747_fms_atc_logon_to glue:4016).
6. Low/confirmed (upstream) — ACARS message pages open at the wrong page number (pages.lua:2673-2733: targetpgNo).
7. Correction: custom2fmc/key2fmc reached only from setdata origin/fltdep/fltdst, which no page wires any more → dead.
Freeze: key path light (one string dataref write per key); route-editing keys → route_changed (LNAV rebuild,
preds, to_fms) → 1 s later the bridge's clear+XPLMLoadFMSFlightPlan on the render thread = prime suspect.
Reference checks consistent: FCOM p.1211, 1212-1213, 1290, 1320; FMSPG p.39, 278. 27 tests pass.
