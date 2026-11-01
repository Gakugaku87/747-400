-- Run from the repository root with LuaJIT: luajit tests/com/acp_model_test.lua
-- The audio control panels' model (B747.15.acp_model.lua; notes/ATA-23.md
-- §12; FCOM p.683-685; ATA23 p.28-31, p.54, p.71-72).
local T = dofile("tests/lib/check.lua")("acp_model")
local A = dofile("plugins/xtlua/scripts/B747.15.xt.com/B747.15.acp_model.lua")

local s = A.new()
T.check(s.seat.L.xmt == nil and s.seat.R.xmt == nil, "power-up: no transmitter (ATA23 p.30)")
A.xmt(s, "L", "vhf_L")
T.check(A.hears(s, "L", "vhf_L") and not A.hears(s, "R", "vhf_L"), "L's VHF L: L hears it, R not")
A.xmt(s, "L", "hf_L")
T.check(not A.hears(s, "L", "vhf_L") and A.hears(s, "L", "hf_L"), "one transmitter: HF L replaces VHF L")
-- receivers by hand
A.rcv(s, "L", "vhf_R")
T.check(s.seat.L.man.vhf_R and A.hears(s, "L", "vhf_R"), "VHF R pushed: on")
A.rcv(s, "L", "vhf_R")
T.check(not s.seat.L.man.vhf_R and not A.hears(s, "L", "vhf_R"), "pushed again: off")
A.rcv(s, "L", "hf_L")
A.rcv(s, "L", "hf_L")
T.check(s.seat.L.man.hf_L, "the transmitter's receiver: not off (FCOM p.685)")
A.rcv(s, "R", "vhf_L")
A.rcv(s, "R", "vhf_L", true)
T.check(s.seat.R.man.vhf_L, "a VHF on 121.5: not off")
T.check(A.hears(s, "C", "vhf_L", true), "121.5: heard without a receiver on")
-- the navigation audio
local sel = {vor_adf = 1, app = 2, filter = 1}
T.check(next(A.nav_audio(s, "L", sel)) == nil, "no VOR/ADF or APP receiver: nothing")
A.rcv(s, "L", "vor_adf")
A.rcv(s, "L", "app_mkr")
local na = A.nav_audio(s, "L", sel)
T.check(na.vor_R == "vor_adf" and na.ils_R == "app_mkr", "VOR R and APP R heard, each with its knob")
sel.filter = 0
na = A.nav_audio(s, "L", sel)
T.check(na.vor_R == nil and na.ils_R == nil, "filter V: the identifiers out")
sel.app = 3
na = A.nav_audio(s, "L", sel)
T.equal(na.mkr, "app_mkr", "MKR on filter V: the markers (not filtered)")
sel.filter, sel.vor_adf = 2, 2
na = A.nav_audio(s, "L", sel)
T.equal(na.adf_L, "vor_adf", "filter R: ADF L's identifier")
T.done()
