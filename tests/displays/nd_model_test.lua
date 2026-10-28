-- Run from the repository root with LuaJIT: luajit tests/displays/nd_model_test.lua
-- The ND orientation model (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/
-- B747.60.nd_model.lua, 5-2 step 5a) without X-Plane: each ND's orientation
-- by mode from its own side, X-Plane's map mode, the TRK, HDG, MAP and VTK
-- flags, the heading pointer, the selected heading bug and line and the
-- wind arrow (FCOM p.1109-1110, p.1141-1143, p.1033-1034); the VOR mode's
-- reference VOR (step 5b: ATA34_1 p.356-369); the bearing pointers and the
-- lower corner blocks (step 5b: FCOM p.1034, p.1038-1040, p.1144-1146).
-- The airplanes built, the 109 (PW; RR as PW) and the 570 (GE), are both
-- track up in MAP (the model's default, the checks below; the user's
-- choice, 2026-10-27); the last block checks the model's 405 (`track_map`
-- false: heading up in all modes with HDG in the box, FCOM p.1109, p.1141,
-- p.1033), which no airplane uses.
local T = dofile("tests/lib/check.lua")("nd_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.nd_model.lua")

local DT = 1 / 30
local s, inp, out
local function run(seconds)
    for _ = 1, math.max(1, math.floor((seconds or 0) / DT + 0.5)) do out = M.update(s, inp, DT) end
end

s, inp = M.new(), M.inputs()
local c, f = inp.side[M.CAPT], inp.side[M.FO]
c.hdg, c.trk, f.hdg, f.trk = 100, 106, 101, 107
c.mode, f.mode = M.MAP, M.VOR
run()
local oc, of = out[M.CAPT], out[M.FO]
T.equal(oc.up, 106, "MAP: track up (570 as 109: FCOM p.1109)")
T.equal(oc.box, 2, "the 570's MAP: TRK in the box (FCOM p.1141)")
T.equal(of.up, 101, "VOR: heading up from the F/O's own heading (FCOM p.1110)")
T.equal(oc.xp_mode, M.XP_MAP, "X-Plane's map mode for MAP")
T.equal(of.xp_mode, M.XP_APP, "VOR: X-Plane's heading-up mode (APP), not its MAP as before")
c.mode = M.APP
run()
T.equal(oc.up, 100, "APP: heading up")
c.mode = M.PLN
run()
T.equal(oc.up, 0, "PLN: north up (magnetic as the stock map: step 5d)")
T.equal(oc.xp_mode, M.XP_PLN, "X-Plane's PLN")

-- the flags (FCOM p.1034)
c.mode = M.MAP
c.trk_valid = false
run()
T.check(oc.trk_flag and not oc.rose, "MAP without a track: the TRK flag, no rose")
T.check(not oc.hdg_flag, "no HDG flag in MAP")
c.mode = M.VOR
run()
T.check(oc.rose and not oc.trk_flag, "VOR without a track but with a heading: the rose")
c.hdg_valid = false
run()
T.check(oc.hdg_flag and not oc.rose, "VOR without a heading: the HDG flag")
T.check(not oc.hdg_ptr and not oc.hdg_bug, "no heading pointer or bug")
c.hdg_valid, c.trk_valid = true, true
inp.map_valid = false
c.mode = M.MAP
run()
T.check(oc.map_flag and oc.vtk_flag, "no FMC position in MAP: MAP and VTK flags (estimate)")
T.check(oc.rose, "the rose stays (the track is good)")
c.mode = M.PLN
run()
T.check(oc.map_flag and not oc.vtk_flag, "PLN: the MAP flag, no VTK flag (MAP mode only)")
T.check(oc.rose, "PLN's rose is fixed")
c.mode = M.APP
run()
T.check(not oc.map_flag, "APP: no MAP flag")
inp.map_valid = true

-- the heading pointer (FCOM p.1142) and the selected heading bug
c.mode = M.MAP
run()
T.check(oc.hdg_ptr and not oc.hdg_ptr_pln, "MAP: the current heading pointer")
T.check(oc.hdg_bug, "the selected heading bug")
c.mode = M.PLN
run()
T.check(oc.hdg_ptr_pln and not oc.hdg_ptr, "PLN: the north-up rose's pointer")
T.check(not oc.hdg_bug and not oc.hdg_line, "PLN: no selected heading (FCOM p.1142)")

-- the dashed line: in MAP with LNAV, LOC or ROLLOUT, removed 10 s after the
-- selected heading moved
c.mode = M.MAP
inp.roll_mode = 6                                                 -- HDG SEL
run(1)
T.check(oc.hdg_line, "MAP in HDG SEL: the dashed line")
inp.roll_mode = 2                                                 -- LNAV
run(1)
T.check(oc.hdg_line, "LNAV engaged: still shown for 10 s")
run(9.5)
T.check(not oc.hdg_line, "10 s later: removed")
T.check(oc.hdg_bug, "the bug stays (before, it went with the line)")
inp.hdg_sel = 90
run()
T.check(oc.hdg_line, "the selected heading moved: back")
run(10.5)
T.check(not oc.hdg_line, "and removed 10 s later")
c.mode = M.VOR
run()
T.check(oc.hdg_line, "VOR: the line regardless of LNAV")

-- the wind arrow, with respect to the display orientation (FCOM p.1142)
inp.wind_from = 350
c.mode, c.hdg, c.trk, c.ias = M.MAP, 90, 100, 250
run()
T.near(oc.wind_deg, 70, 1e-9, "from 350 on a track-up display (100): blowing to 170, 70 right of the top")
T.check(oc.wind, "shown at 250 kt")
c.mode = M.VOR
run()
T.near(oc.wind_deg, 80, 1e-9, "heading up (90): 80 right")
c.mode = M.PLN
run()
T.near(oc.wind_deg, 170, 1e-9, "PLN (north up): blowing to 170")
c.ias = 80
run()
T.check(not oc.wind, "below 100 kt: no arrow")

-- the expanded track line (FCOM p.1143, 109)
c.mode, c.ias, c.center = M.MAP, 250, false
run()
T.check(oc.trk_line, "MAP expanded: the track line")
c.mode = M.VOR
run()
T.check(not oc.trk_line, "VOR without WXR or TFC: none")
c.wxr = true
run()
T.check(oc.trk_line, "VOR with WXR: the track line")
c.trk_valid = false
run()
T.check(not oc.trk_line, "no track: no line (the rose stays on the heading)")
T.check(oc.rose, "the rose")
c.trk_valid, c.center = true, true
run()
T.check(not oc.trk_line, "centred: not this one")
T.check(not oc.trk_line_ctr, "VOR CTR: no track line (FCOM p.1143: MAP CTR)")

-- MAP CTR (2026-10-28, the real airplane's; FCOM p.1009, p.1143): its
-- track line and range scale; X-Plane's map one range up (the half scale),
-- at 640 NM the panel's half-size map
c.mode, c.wxr = M.MAP, false
c.range_nm = 40
run()
T.check(oc.trk_line_ctr and not oc.trk_line, "MAP CTR: its own track line and range scale")
T.check(oc.xp_range == 3 and not oc.xp_half, "40 NM: X-Plane's map at 80 NM (half the scale)")
c.trk_valid = false
run()
T.check(not oc.trk_line_ctr, "no track: none")
c.trk_valid = true
c.range_nm = 640
run()
T.check(oc.xp_range == 6 and oc.xp_half, "640 NM: X-Plane's map at 640 NM, drawn at half size")
c.center = false
run()
T.check(oc.xp_range == 6 and not oc.xp_half and not oc.trk_line_ctr, "expanded MAP 640 NM: as selected")
c.range_nm = 10
run()
T.equal(oc.xp_range, 0, "10 NM: X-Plane's map range 0")
c.mode, c.center = M.PLN, true
run()
T.check(oc.xp_range == 0 and not oc.xp_half and not oc.trk_line_ctr, "PLN (centred): as selected")
c.mode = M.VOR
run()
T.equal(oc.xp_range, 0, "VOR CTR: as selected (no map)")
c.mode, c.center, c.range_nm = M.MAP, false, 40

-- the VOR mode (step 5b): autotuned, received
s, inp = M.new(), M.inputs()
c = inp.side[M.CAPT]
c.mode, c.vor_auto, c.vor_rx, c.vor_to_from, c.vor_dme_rx = M.VOR, true, true, 1, true
run()
oc = out[M.CAPT]
T.equal(oc.vor_crs, 1, "autotuned: the course dashes (ATA34_1 p.369)")
T.check(not oc.vor_dev, "no deviation (p.368)")
T.equal(oc.to_from, 0, "no TO/FROM")
T.equal(oc.vor_ref, 2, "the frequency or identifier")
T.equal(oc.vor_dme, 1, "the DME")
T.check(not oc.vor_flag, "no flag")
c.vor_auto = false
run()
T.equal(oc.vor_crs, 2, "manual: the course and its pointer")
T.check(oc.vor_dev, "the deviation bar and scale")
T.equal(oc.to_from, 1, "TO")
c.vor_to_from = 2
run()
T.equal(oc.to_from, 2, "FROM")
c.vor_rx = false
run()
T.check(not oc.vor_dev and oc.to_from == 0, "no bearing (NCD): no deviation, no TO/FROM (p.358)")
T.check(oc.vor_crs == 2 and not oc.vor_flag, "the course stays, no flag")
c.vor_rx = true
c.vor_fail = true
run()
T.check(oc.vor_flag, "the receiver failed: the VOR flag (p.360)")
T.check(not oc.vor_dev and oc.to_from == 0, "no deviation, no TO/FROM")
T.check(oc.vor_crs == 0 and oc.vor_ref == 0, "the course and the frequency removed (p.366)")
T.equal(oc.vor_dme, 1, "the DME is its own")
c.vor_fail = false
c.dme_fail = true
run()
T.equal(oc.vor_dme, 2, "the DME failed: its flag")
c.dme_fail, c.vor_dme_rx = false, false
run()
T.equal(oc.vor_dme, 0, "no DME: dashes")

-- the bearing pointers (step 5b): VOR L on the left switch, ADF R on the right
-- (and the POS switch below), on the 570's track up MAP
s, inp = M.new(), M.inputs()
c = inp.side[M.CAPT]
c.mode, c.hdg, c.trk = M.MAP, 100, 110
c.sw[1], c.sw[2] = M.SW_VOR, M.SW_ADF
inp.vor_brg_rx[1], inp.adf_brg_rx[2] = true, true
inp.vor_rel[1], inp.adf_rel[2] = 30, -50
inp.vor_dme_rx[1] = true
run()
oc = out[M.CAPT]
T.equal(oc.ptr[1], M.SW_VOR, "the left pointer: VOR L")
T.equal(oc.ptr[2], M.SW_ADF, "the right pointer: ADF R")
T.near(oc.brg[1], 20, 1e-9, "MAP (track up, 110): relative 30 from heading 100, 20 right of the top")
T.near(oc.brg[2], -60, 1e-9, "ADF R relative -50: 60 left")
T.check(oc.rad[1] == M.SW_VOR and oc.rad[2] == M.SW_ADF, "the corner blocks follow the switches")
T.equal(oc.rad_dme[1], 1, "VOR L's DME")
T.equal(oc.rad_dme[2], 0, "no DME line in an ADF block")
c.mode = M.VOR
run()
T.near(oc.brg[1], 30, 1e-9, "VOR (heading up): the relative bearing itself")
c.mode = M.APP
run()
T.equal(oc.ptr[1], M.SW_VOR, "APP too (FCOM p.1040: all modes except PLAN)")
c.mode = M.PLN
run()
T.check(oc.ptr[1] == 0 and oc.ptr[2] == 0, "PLN: no pointers")
T.check(oc.rad[1] == 0 and oc.rad[2] == 0, "nor blocks")
c.mode = M.MAP
inp.vor_brg_rx[1] = false
run()
T.equal(oc.ptr[1], 0, "no VOR bearing: no pointer")
T.equal(oc.rad[1], M.SW_VOR, "the block stays")
T.check(not oc.rad_flag[1], "no flag")
inp.vor_brg_rx[1] = true
inp.adf_ok[2] = false
run()
T.equal(oc.ptr[2], 0, "ADF R failed: no pointer")
T.check(oc.rad_flag[2], "its flag in the block (FCOM p.1034)")
inp.adf_ok[2] = true
c.dme_fail = true
run()
T.equal(oc.rad_dme[1], 2, "the DME failed: the DME flag")
c.dme_fail = false
c.hdg_valid = false
run()
T.equal(oc.ptr[1], 0, "no heading: no pointer (drawn from the heading)")
c.hdg_valid = true
c.sw[1] = M.SW_OFF
run()
T.check(oc.ptr[1] == 0 and oc.rad[1] == 0, "the switch OFF: nothing on the left")

-- the POS switch (step 5c: FCOM p.1040, p.1145, p.1150): the Captain's MAP
-- (track 106 up, heading 100), 40 NM; VOR L 20 NM at 10 degrees right of
-- the heading with its DME, VOR R 30 degrees left without a DME
T.check(not oc.pos_iru[1] and not oc.pos_gps and not oc.pos_rad[1], "POS off: none")
c.hdg, c.trk, c.trk_valid, c.center = 100, 106, true, false
c.pos, c.range_nm = true, 40
inp.iru_nav = {true, false, true}
inp.gps_ok = true
inp.vor_ok = {true, true}
inp.vor_brg_rx = {true, true}
inp.vor_rel = {10, -30}
inp.vor_dme_rx = {true, false}
inp.vor_dme_nm = {20, 0}
run()
T.check(oc.pos_iru[1] and not oc.pos_iru[2] and oc.pos_iru[3], "the IRU L and R positions (in NAV), not C")
T.check(oc.pos_gps, "the GPS position")
T.check(oc.pos_rad[1] and oc.pos_rad[2], "both VOR radials")
T.near(oc.pos_rad_brg[1], 4, 1e-6, "VOR L at 110 magnetic: 4 degrees right of the track-up top")
T.equal(oc.pos_rad_radial[1], 290, "the airplane on its radial 290")
T.near(oc.pos_rad_len[1], 20 * 465 / 40, 1e-6, "20 NM DME at 40 NM: 232.5 pixels")
T.check(oc.pos_rad_tick[1], "its tick mark at the DME distance")
T.near(oc.pos_rad_brg[2], -36, 1e-6, "VOR R at 070: 36 degrees left")
T.near(oc.pos_rad_len[2], 465, 1e-6, "no DME: to the edge (the range arc)")
T.check(not oc.pos_rad_tick[2], "no tick mark")
inp.vor_rel[2] = -75
run()
T.near(oc.pos_rad_len[2], 329 / math.sin(math.rad(81)), 1e-6, "81 degrees left: to the display's left side")
inp.vor_rel[2] = -130
run()
T.check(not oc.pos_rad[2], "behind the airplane on the expanded map: none (as the map's symbols)")
c.center = true
run()
T.near(oc.pos_rad_len[2], 225, 1e-6, "the centred map: to the centred mask's circle (the map symbols')")
T.near(oc.pos_rad_len[1], 20 * 232.5 / 40, 1e-6, "MAP CTR: 20 NM DME at 40 NM at half the scale, 116 pixels")
T.check(oc.pos_rad_tick[1], "its tick mark")
c.center = false
inp.vor_dme_nm[1] = 60
run()
T.near(oc.pos_rad_len[1], 465, 1e-6, "DME 60 NM beyond 40 NM: to the edge")
T.check(not oc.pos_rad_tick[1], "no tick mark")
c.dme_fail = true
inp.vor_dme_nm[1] = 20
run()
T.check(not oc.pos_rad_tick[1], "the DME failed: no tick mark")
c.dme_fail = false
inp.vor_brg_rx[1] = false
run()
T.check(not oc.pos_rad[1], "VOR L's bearing not received: no radial")
inp.vor_brg_rx[1] = true
c.mode = M.VOR
run()
T.check(not oc.pos_iru[1] and not oc.pos_gps and not oc.pos_rad[1], "VOR mode: none (MAP and MAP CTR only)")
c.mode = M.MAP
inp.vor_rel[1] = 80
run()
T.equal(oc.pos_rad_radial[1], 360, "the radial 360, not 0")
T.check(not of.pos_iru[1] and not of.pos_rad[1], "the F/O's POS off: none")

-- the model's 405 (no airplane uses it): heading up in all modes, HDG in
-- the box and the HDG flag (FCOM p.1109, p.1141, p.1033)
s, inp = M.new(), M.inputs()
inp.track_map = false
c = inp.side[M.CAPT]
c.hdg, c.trk, c.mode = 100, 106, M.MAP
run()
oc = out[M.CAPT]
T.equal(oc.up, 100, "405 MAP: heading up")
T.equal(oc.xp_mode, M.XP_APP, "405 MAP: X-Plane's heading-up map")
T.equal(oc.box, 1, "405 MAP: HDG in the box")
T.check(oc.trk_line and oc.hdg_ptr, "405 MAP: the track line and the heading pointer")
c.trk_valid = false
run()
T.check(oc.rose and not oc.trk_flag and not oc.hdg_flag, "405 MAP without a track: the rose, no flag")
c.trk_valid, c.hdg_valid = true, false
run()
T.check(oc.hdg_flag and not oc.rose and not oc.trk_flag, "405 MAP without a heading: the HDG flag")
c.hdg_valid = true
c.mode = M.PLN
run()
T.equal(oc.box, 3, "405 PLAN: HDG in PLAN's box")
inp.track_map = true
run()
T.equal(oc.box, 4, "570 PLAN: TRK in PLAN's box")
c.mode = M.VOR
run()
T.equal(oc.box, 1, "VOR: HDG")
T.done()
