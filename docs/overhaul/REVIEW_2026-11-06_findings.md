# Fable re-review of the changes after 02660613 (2026-11-06): raw findings as received

Two Fable (claude-fable-5-1) reviewers read `git diff 02660613..0b5a5aa2`. They only read files; nothing in the repository was changed. The Japanese summary, with what was checked and what was done, is [REVIEW_2026-11-06.md](REVIEW_2026-11-06.md). The reports are kept here as the reviewers wrote them, except for the formatting.

## 1 FMS bridge (C) and its Lua interface

1. **wb_window.c:319, 286-291, 309-324 — keyboard focus is kept after a click outside the window while a value is being entered.**
   - Trigger: click a LOAD value box (focus taken, `wb_edit >= 0`), then click in the 3D cockpit or anywhere outside the window, without Enter or Escape.
   - Nothing releases the focus: `wb_edit_end` runs only on Enter or Escape, a click inside the window, `wb_show(0)`, or leaving the ground.
   - Severity: wrong behaviour. Confidence: medium (traced; not verified in X-Plane).
   - Fix: end the edit when the mouse is outside the window.
   - **Checked in X-Plane: false. The edit ends on a click outside; the key went to X-Plane.**
2. **B744.fms.pages.lua:849-862 and B747.25.xt.fuel.lua:1520-1536 — two entries within two frames: the second is applied twice and the first is lost.**
   - Possible only from the Web API or another add-on; impossible from the keyboard.
   - Harmless for the current fields: they are absolute values, so applying one twice gives the same result.
   - Severity: minor. Confidence: high.
3. **gh_window.c:56, 142-148 — the button hover highlight never clears.**
   - The cursor callback runs only while the mouse is over the window.
   - Fix: age the hover by frames, as failures_window.c does.
   - Severity: minor (cosmetic).
4. **wb_window.c:121, 167-168 and gh_window.c:43-47, 75-91 — `XPLMFindDataRef` lookups every frame drawn.**
   - Four a frame for the W&B window and three for the ground handling window. Cheap, but avoidable.
   - Severity: minor.
5. **nd_line.c:433-438 — the dashes' phase jumps when a leg leaves the visible radius.**
   - A drawn leg adds its pieces' chords (about its projected arc); a culled leg adds its straight chord.
   - Fix: add the great-circle length in pixels for a culled leg.
   - Severity: minor (cosmetic, dashed styles only).
6. **nd_line.c:333-357 — the circles are projected whatever their visibility.**
   - 73 points a circle, up to 8 circles. Severity: minor (performance).
7. **wb_window.c:392, 260 — content is drawn past the window's bottom at small heights.**
   - The resizing limit allows 420 high. Only the tank rows stop at the bottom.
   - Severity: minor (cosmetic).
8. **B744.fms.pages.lua:855-858 and B747.25.xt.fuel.lua:1522-1526 — entries in about the first 30 frames after a module starts counting are silently taken as done.**
   - This is documented in the comments. Severity: minor.

Checked and sound:
- Memory safety:
  - `wb_buf` is bounded, and `wb_num`'s digits are guarded.
  - Box indices are constants within range.
  - `strtod` rejects "." and NaN.
  - Reads of the dataref arrays are bounded.
- Registration and cleanup:
  - All four new datarefs and both commands are unregistered in `XPluginStop`, and both windows are destroyed there.
  - GL culling is restored around both draws.
- No Lua error path from window input. Units are consistent (kg).

Further results:
- **nd_line.c numerics:** a harness compared `ndl_leg_near` with a brute-force minimum on 40,000 random legs. No leg was culled wrongly or kept wrongly, and the edge cases (NaN, poles, the antimeridian, near-antipodal legs) were sound.
- **Build:** no warnings. The committed `win.xpl` is identical to a build of the sources.
- **Commits:** 2e76b40a, 36562440, a3fec923 and a73d2ccc each do what their messages say.

## 2 FMC and ND (Lua)

All 123 regression tests in tests/fms and tests/displays pass.

1. **acars/acars.pages.lua:98 — INITIALIZE posts "CRUISE ALT NOT SET" at every draw. CLR cannot clear it, and the CDU's typing is swallowed while the page shows.**
   - Reproduced with a harness built from acars_pages_test.lua.
   - This is part 2 of the previous finding 3-3.
   - Fix: post the message once on page entry.
   - Severity: wrong behaviour.
2. **B744.fms.pages.lua:1785-1822 — PAX/CARGO payload entry can hang XTLua's thread.**
   - SIM CONFIG accepts a passenger weight of "0".
   - Then a payload entry of "0" gives `math.ceil(0 / 0)` = NaN, and `repeat … until (pax == 0)` never ends.
   - The previous finding 3-2 was only partly fixed.
   - Fix (as proposed): `until (pax <= 0)`, and refuse a weight of 0 or less. **That proposal does not end on NaN; `until not (pax > 0)` was used.**
   - Severity: hang.
3. **B747.68.xt.fms.lua:2149, 2172 — the previous finding 2-4 (allocations every frame) is not fixed and is not claimed in §0.**
   - `B747_fms_schedules` builds three tables and closures every frame, and `B747_perf_db.hold()` runs every frame in the descent.
   - Severity: minor.
4. **B747.68.xt.fms.lua:4677-4684 — the report context's frame cache is keyed on simDRTime.**
   - A page drawn again in the same frame as an entry shows the context from before the entry. One frame only.
   - Severity: minor.
5. **progress.lua:43-44, 268-270 — the previous resumed finding 2-4 is unchanged.**
   - For up to 1 s after sequencing, PROGRESS shows the passed waypoint's data under the next name.
   - Severity: minor.
6. **B747.68.xt.fms.lua:812-816 — VREF30+100 is read each frame, so the climb SPD TRANS creeps down with fuel burn.**
   - Fix (as proposed): freeze it at takeoff. **FCOM p.1328 does not say when the weight is taken.**
   - Severity: minor.
7. **acars/acars.lua:254-259, 309-345 — the previous finding 3p-4 is unchanged.**
   - Message fields are read directly on namespace tables.
   - A telex without `title` or `rr` overflows the stack under the draw's pcall, and the page is blank.
   - Severity: minor.

Checked and found sound:
- The CDU keys and data:
  - doKey's xpcall;
  - `fms_field`/`setData`;
  - the `calc_stab_trim` guard;
  - `pax_spread`.
- Routes and the X-Plane plan:
  - `cap_rows`;
  - the route changed on sequencing.
- Predictions and VNAV:
  - the DES NOW prediction;
  - removing steps;
  - CRZ ALT ≥ MAX;
  - deleting the SPD TRANS;
  - the altitude selector's push in a cruise climb.
- Caches and loading:
  - the turn caches;
  - the ND line cache;
  - POS INIT;
  - `B747_fms_wb_update`.
- The ND:
  - the F/O's TCAS;
  - the WPT grid;
  - decode on change;
  - the early return in `updateNDLatLong`;
  - no full garbage collection every frame.

### The previous findings in this area

| Finding | Fix commit | Status |
|---|---|---|
| 1-1 POS INIT file read every frame | 9241636d | fixed |
| 1-2 CIFP parse and navdb grids in the entry's frame | — (pending the user's hitch log) | not fixed (reason acceptable) |
| 1-3 routes over 100 X-Plane rows stall the sync | bbdb4e46 | fixed |
| 1-4 nav pages' heavy work 3x a frame | — | not fixed |
| 1-5 turn caches keyed on raw wind | dae531a0 | fixed |
| 2-1 DES NOW predictions above CRZ ALT | b183bfe6 | fixed |
| 2-2 unflyable step climb re-entered | 57b33c14 | fixed |
| 2-3 T/D deceleration cache keyed on altitude only | 266e6f2b | fixed |
| 2-4 allocations every frame (schedules, hold) | — | not fixed (finding 3) |
| 2-5 CRZ ALT ≥ MAX drops all predictions | ff28cf18 | fixed |
| 2-6 predicted steps fly the climb schedule | — (FCOM silent) | not fixed (acceptable) |
| 2-7 crz_last updated every frame | — | not fixed; the reported trigger traced to work |
| 2r-1 DES SPD TRANS not deletable | a5eab1d0 | fixed |
| 2r-2 update_spd_trans 250 kt, Vf30 each frame | — | 250 kt acceptable; Vf30 creep not fixed (finding 6) |
| 2r-4 PROGRESS stale indices after sequencing | — | not fixed (finding 5) |
| 3p-1 FMS data JSON every frame | — (measured 0.06 ms) | not fixed (reason acceptable) |
| 3p-2 setData latent errors | 5b175d63 | fixed |
| 3p-3 custom2fmc/key2fmc | — (dead code) | n/a |
| 3p-4 ACARS message fields on namespace tables | — | not fixed (finding 7) |
| 3p-5 report_ctx twice per status | 6df7ca73 | fixed |
| 3p-6 SimBrief OFP parsed synchronously | — | not fixed |
| 3-1 TAKEOFF REF CG before any weight | 1efcbf07 | fixed |
| 3-2 PAX/CARGO fractional count loops forever | e2d38679 | partly fixed (finding 2) |
| 3-3 ACARS INITIALIZE blank / re-posts its message | 29b535db | partly fixed (finding 1) |
| 3-4 report pages rebuild the context about 8x a frame | 6df7ca73 | fixed |
| 3-5 WEATHER's ATC field logs ATC off | 29b535db | fixed |
| 3-6 ACARS message page opens at the wrong page | 29b535db | fixed |
| 5-2 ND cost every frame | 734262e5, ebce20ee | fixed |
| 5-3 WPT fixes stale, default AIRAC, a missing file stops the plugin | 3e71c57b | fixed |
| 5-4 the F/O's TCAS uses the Captain's track | 4978bcee | fixed |
| 5-5 Va 200000 | 100683aa | fixed (not checked: outside these files) |
