-- Run from the repository root with LuaJIT: luajit tests/com/rtp_module_test.lua
-- The radio tuning panels in the communications module as XTLua runs it
-- (B747.15.xt.rtp.lua on the radio model; notes/ATA-23.md §11): the
-- commands, the panels' lights and windows, VHF C's and the HF's
-- frequencies, X-Plane's COM1 and COM2 knobs and power.
local T = dofile("tests/lib/check.lua")("rtp_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.15.xt.com/B747.15.xt.com.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 1) end
rt:callout("flight_start")
rt:frame(1 / 30)
rt:frame(1 / 30)

local C = "laminar/B747/comm/"
local function get(name, i) return rt:get(name, i) end
local function cmd(name) rt:command(name); rt:frame(1 / 30) end
local function sent(name)
    for _, e in ipairs(rt.command_log) do if e.name == name then return true end end
    return false
end

T.equal(get(C .. "rtp_L/lcd_to_display"), 0, "start: L shows VHF L (COM1)")
T.equal(get(C .. "rtp_R/lcd_to_display"), 1, "start: R shows VHF R (COM2)")
T.equal(get(C .. "rtp_C/lcd_to_display"), 98, "start: C shows ACARS (VHF C in data mode)")
T.check(get(C .. "rtp_L/vhf_L_status") == 1 and get(C .. "rtp_C/vhf_C_status") == 1 and get(C .. "rtp_R/vhf_R_status") == 1,
    "start: each panel's own radio light")
T.equal(get(C .. "vhf_C/active_khz"), 0, "VHF C active: ACARS (0)")

-- the AM switch (COM-04): HF L selected stays, its AM light
cmd("laminar/B747/rtp_L/hf_L/sel_switch")
T.check(get(C .. "rtp_L/hf_L_status") == 1 and get(C .. "rtp_L/vhf_L_status") == 0, "L: HF L selected")
T.equal(get(C .. "rtp_L/lcd_to_display"), 3, "L shows HF L")
cmd("laminar/B747/rtp_L/am/sel_switch")
T.check(get(C .. "rtp_L/am_status") == 1 and get(C .. "rtp_L/hf_L_status") == 1, "AM: the AM light, HF L still selected")
T.equal(get(C .. "hf_L/am"), 1, "HF L in AM")
-- HF L's knobs and transfer in the model
local s0 = get(C .. "hf_L/standby_khz")
cmd("laminar/B747/rtp_L/freq_MHz/sel_dial_up")
T.equal(get(C .. "hf_L/standby_khz"), s0 + 1000, "HF L: MHz up")
T.equal(get(C .. "rtp_L/freq_MHz/sel_dial_pos"), 1, "the MHz knob turned")
local a0 = get(C .. "hf_L/active_khz")
cmd("laminar/B747/rtp_L/freq_txfr/sel_switch")
T.check(get(C .. "hf_L/active_khz") == s0 + 1000 and get(C .. "hf_L/standby_khz") == a0, "HF L: transfer")

-- the offside light (FCOM p.686)
cmd("laminar/B747/rtp_L/vhf_R/sel_switch")
T.check(get(C .. "rtp_L/offside_tuning_status") == 1 and get(C .. "rtp_R/offside_tuning_status") == 1, "L tunes VHF R: L's and R's offside lights")
cmd("laminar/B747/rtp_L/vhf_L/sel_switch")
T.check(get(C .. "rtp_L/offside_tuning_status") == 0 and get(C .. "rtp_R/offside_tuning_status") == 0, "L back on VHF L: out")

-- VHF L: X-Plane's COM1 commands; the 109 (PW) on 25 kHz
rt.command_log = {}
cmd("laminar/B747/rtp_L/freq_khz/sel_dial_up")
T.check(sent("sim/radios/stby_com1_fine_up") and not sent("sim/radios/stby_com1_fine_up_833"), "VHF L kHz up: COM1 by 25 kHz (109)")
cmd("laminar/B747/rtp_L/freq_MHz/sel_dial_dn")
T.check(sent("sim/radios/stby_com1_coarse_down"), "VHF L MHz down: COM1 coarse")
cmd("laminar/B747/rtp_L/freq_txfr/sel_switch")
T.check(sent("sim/radios/com1_standy_flip"), "VHF L transfer: COM1 flip")
rt:set("laminar/B747/engines/type", 1)
rt.command_log = {}
cmd("laminar/B747/rtp_R/freq_khz/sel_dial_dn")
T.check(sent("sim/radios/stby_com2_fine_down_833"), "the GE (570): VHF R kHz down by 8.33 kHz (COM-11: down is down)")
rt:set("laminar/B747/engines/type", 0)

-- VHF C: voice and back to data
cmd("laminar/B747/rtp_C/freq_txfr/sel_switch")
T.equal(get(C .. "rtp_C/lcd_to_display"), 2, "C: VHF C in voice, its frequency shown")
T.equal(get(C .. "rtp_C/stby_show"), 98, "C: ACARS in the standby window")
cmd("laminar/B747/rtp_C/freq_txfr/sel_switch")
T.check(get(C .. "rtp_C/lcd_to_display") == 98 and get(C .. "rtp_C/stby_show") == 2, "C: back to data, VHF C's frequency in the standby window")

-- OFF (COM-12): no tuning, blank, the OFF light; the radio lights out
cmd("laminar/B747/rtp_R/off_switch")
T.check(get(C .. "rtp_R/off_status") == 1 and get(C .. "rtp_R/lcd_to_display") == 90 and get(C .. "rtp_R/vhf_R_status") == 0,
    "R OFF: the OFF light, blank, its radio light out")
rt.command_log = {}
cmd("laminar/B747/rtp_R/freq_MHz/sel_dial_up")
T.check(not sent("sim/radios/stby_com2_coarse_up"), "R OFF: no tuning")
cmd("laminar/B747/rtp_R/off_switch")

-- X-Plane's COM1 and COM2 power by the buses (before, by a panel showing
-- them: COM-01)
local P = "sim/cockpit2/radios/actuators/"
cmd("laminar/B747/rtp_L/hf_L/sel_switch")
T.equal(get(P .. "com1_power"), 1, "L on HF L: COM1 still powered (VHF L on the main battery bus)")
rt:set("laminar/B747/electrical/bus/bat_main", 0)
rt:frame(1 / 30)
T.check(get(P .. "com1_power") == 0 and get(C .. "rtp_L/lcd_to_display") == 90, "no main battery bus: COM1 off, L blank")
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/dc", 1, 0)
rt:frame(1 / 30)
T.equal(get(P .. "com2_power"), 0, "no DC bus 2: COM2 off (estimate)")
T.done()
