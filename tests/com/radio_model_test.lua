-- Run from the repository root with LuaJIT: luajit tests/com/radio_model_test.lua
-- The radios and radio tuning panels (B747.15.radio_model.lua;
-- notes/ATA-23.md §11; FCOM p.685-688, p.714-715).
local T = dofile("tests/lib/check.lua")("radio_model")
local R = dofile("plugins/xtlua/scripts/B747.15.xt.com/B747.15.radio_model.lua")
local ALL = {L = true, C = true, R = true}

local s = R.new()
local out = R.panels(s, ALL)
T.check(out.L.show == R.SHOW.vhf_L and out.R.show == R.SHOW.vhf_R, "start: L shows VHF L (COM1), R VHF R (COM2)")
T.equal(out.C.show, R.SHOW.acars, "start: C shows VHF C in data mode (ACARS, 109)")
T.check(not out.L.offside and not out.C.offside and not out.R.offside, "start: no offside light")
T.check(R.vhf_c_data(s), "VHF C carries ACARS")

-- the offside light (FCOM p.686): a radio of another panel, and the panel
-- whose radio another tunes
R.select(s, "L", "vhf_R")
out = R.panels(s, ALL)
T.check(out.L.offside, "L tunes VHF R: L's offside light")
T.check(out.R.offside, "L tunes VHF R: R's offside light (its radio tuned by another)")
T.check(not out.C.offside, "L tunes VHF R: C's out")
T.equal(out.L.show, R.SHOW.vhf_R, "L shows VHF R")
R.select(s, "L", "hf_L")
out = R.panels(s, ALL)
T.check(not out.L.offside and not out.R.offside, "L tunes HF L (its own): no offside light")
T.equal(out.L.show, R.SHOW.hf_L, "L shows HF L")

-- the AM switch: the selected HF's mode, not a radio (before, COM-04)
R.am(s, "L")
T.check(s.radio.hf_L.am and s.rtp.L.sel == "hf_L", "AM on HF L: AM, HF L still selected")
R.select(s, "L", "vhf_L")
R.am(s, "L")
T.check(s.radio.hf_L.am and not s.radio.hf_R.am, "AM with VHF L selected: nothing")
R.select(s, "L", "hf_L")
R.am(s, "L")
T.check(not s.radio.hf_L.am, "AM again: USB")

-- the knobs and the transfer on a model radio (HF L): the standby, MHz and
-- kHz parts, the swap
s.radio.hf_L.standby = 11330
R.knob(s, "L", "MHz", 1)
T.equal(s.radio.hf_L.standby, 12330, "HF L: MHz up")
R.knob(s, "L", "kHz", -1)
T.equal(s.radio.hf_L.standby, 12329, "HF L: kHz down (1 kHz)")
local a0 = s.radio.hf_L.active
R.transfer(s, "L")
T.check(s.radio.hf_L.active == 12329 and s.radio.hf_L.standby == a0, "HF L: transfer swaps standby and active")
s.radio.hf_L.standby = 29999
R.knob(s, "L", "MHz", 1)
T.equal(s.radio.hf_L.standby, 2999, "HF L: MHz past 29 wraps to 2")

-- VHF L and R are X-Plane's: the glue tunes them
R.select(s, "L", "vhf_L")
local what, radio = R.knob(s, "L", "kHz", 1)
T.check(what == "xp" and radio == "vhf_L", "VHF L's knob: X-Plane's (the glue)")
what, radio = R.transfer(s, "L")
T.check(what == "xp" and radio == "vhf_L", "VHF L's transfer: X-Plane's")

-- VHF C: data and voice (FCOM p.686-687): ACARS in the active window; a
-- transfer puts the standby's voice frequency active and ACARS in the
-- standby window, a second transfer data again
R.select(s, "C", "vhf_C")
s.radio.vhf_C.standby = 131550
R.transfer(s, "C")
out = R.panels(s, ALL)
T.check(s.radio.vhf_C.active == 131550 and out.C.show == R.SHOW.vhf_C, "VHF C: transfer to voice, its frequency shown")
T.check(out.C.stby == R.SHOW.acars and not R.vhf_c_data(s), "VHF C voice: ACARS in the standby window")
R.transfer(s, "C")
out = R.panels(s, ALL)
T.check(R.vhf_c_data(s) and out.C.show == R.SHOW.acars and out.C.stby == R.SHOW.vhf_C, "VHF C: transfer back to data, its frequency in the standby window")
-- the knobs on VHF C: 25 kHz (109), wrapping the kHz; out of ACARS and
-- (estimate) below 118 to ACARS
s.radio.vhf_C.standby = 118975
R.knob(s, "C", "kHz", 1)
T.equal(s.radio.vhf_C.standby, 118000, "VHF C: 118.975 kHz up wraps to 118.000")
R.knob(s, "C", "MHz", -1)
T.equal(s.radio.vhf_C.standby, R.DATA, "VHF C: MHz down below 118: ACARS (estimate)")
R.knob(s, "C", "MHz", 1)
T.equal(s.radio.vhf_C.standby, 118000, "VHF C: from ACARS up: 118.000")
s.radio.vhf_C.standby = 136975
R.knob(s, "C", "MHz", 1)
T.equal(s.radio.vhf_C.standby, 118975, "VHF C: 136 MHz up wraps to 118")

-- OFF: disconnected (no tuning, blank windows), the OFF light
R.off(s, "C")
out = R.panels(s, ALL)
T.check(s.rtp.C.off and out.C.show == R.SHOW.blank and not out.C.offside, "C OFF: blank, no offside light")
local f0 = s.radio.vhf_C.standby
R.knob(s, "C", "MHz", 1)
R.select(s, "C", "vhf_L")
T.check(s.radio.vhf_C.standby == f0 and s.rtp.C.sel == "vhf_C", "C OFF: no tuning, no selection")
R.off(s, "C")
-- no power: blank, and another panel's radio not counted as tuned
out = R.panels(s, {L = true, C = true, R = false})
T.equal(out.R.show, R.SHOW.blank, "R without power: blank")
R.select(s, "R", "vhf_L")
out = R.panels(s, {L = true, C = true, R = false})
T.check(not out.L.offside, "R without power tuning VHF L: L's offside light out")
out = R.panels(s, ALL)
T.check(out.L.offside and out.R.offside, "R powered tuning VHF L: both offside lights")
T.done()
