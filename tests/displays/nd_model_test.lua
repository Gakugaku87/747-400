-- Run from the repository root with LuaJIT: luajit tests/displays/nd_model_test.lua
-- The ND orientation model (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/
-- B747.60.nd_model.lua, 5-2 step 5a) without X-Plane: each ND's orientation
-- by mode from its own side, X-Plane's map mode, the TRK, HDG, MAP and VTK
-- flags, the heading pointer, the selected heading bug and line and the
-- wind arrow (FCOM p.1109-1110, p.1141-1143, p.1033-1034).
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
T.equal(oc.up, 106, "MAP: track up (109: FCOM p.1109)")
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

T.done()
