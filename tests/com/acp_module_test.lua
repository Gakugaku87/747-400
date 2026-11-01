-- Run from the repository root with LuaJIT: luajit tests/com/acp_module_test.lua
-- The audio control panels in the communications module as XTLua runs it
-- (B747.15.xt.acp.lua on the panel model; notes/ATA-23.md §12): each seat
-- on its own, the receiver lights, 121.5, X-Plane's pilot's (the
-- Captain's panel) and copilot's (the F/O's) audio panels.
local T = dofile("tests/lib/check.lua")("acp_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.15.xt.com/B747.15.xt.com.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
for i = 0, 3 do rt:set("laminar/B747/electrical/bus/dc", i, 1) end
rt:set("sim/cockpit2/radios/actuators/com1_frequency_hz_833", 118100)
rt:set("sim/cockpit2/radios/actuators/com2_frequency_hz_833", 128800)
rt:callout("flight_start")
rt:frame(1 / 30)
rt:frame(1 / 30)

local function get(name, i) return rt:get(name, i) end
local function cmd(name) rt:command(name); rt:frame(1 / 30) end
local XA = "sim/cockpit2/radios/actuators/"
local function ap(seat, ch, what) return get("laminar/B747/ap_" .. seat .. "/" .. ch .. "/" .. what) end

-- the start: the Captain's VHF L transmitter (ATA23 p.30: none at power-up;
-- the flight start selects it, as before)
T.equal(ap("L", "vhf_L", "xmt_status"), 1, "start: L's VHF L MIC light")
T.check(ap("C", "vhf_L", "xmt_status") == 0 and ap("R", "vhf_L", "xmt_status") == 0, "start: C's and R's not selected (before, linked: COM-02)")
T.equal(get(XA .. "audio_selection_com1"), 1, "pilot: COM1 heard (the transmitter's receiver)")
T.equal(get(XA .. "audio_com_selection_man"), 6, "pilot: transmits on COM1")
T.equal(ap("L", "vhf_L", "audio_status"), 0, "L's VHF L receiver light out: on by the transmitter, not by hand (COM-13)")
T.equal(get(XA .. "audio_selection_com_auto"), 0, "pilot: X-Plane's automatic listening off")

-- each seat on its own (COM-02)
cmd("laminar/B747/ap_C/vhf_R/xmt_sel_switch")
T.check(ap("C", "vhf_R", "xmt_status") == 1 and ap("L", "vhf_L", "xmt_status") == 1 and ap("R", "vhf_R", "xmt_status") == 0,
    "C selects VHF R: only C's")
cmd("laminar/B747/ap_R/vhf_R/xmt_sel_switch")
T.equal(get(XA .. "audio_com_selection_man_copilot"), 7, "copilot (the F/O's panel): transmits on COM2")
T.equal(get(XA .. "audio_selection_com2_copilot"), 1, "copilot: COM2 heard")
T.equal(get(XA .. "audio_selection_com2"), 0, "pilot: COM2 not heard")

-- the receivers: on and off by hand, the light; not off while the
-- transmitter (FCOM p.685)
cmd("laminar/B747/ap_L/vhf_R/audio_sel_switch")
T.check(get(XA .. "audio_selection_com2") == 1 and ap("L", "vhf_R", "audio_status") == 1, "L's VHF R receiver on: heard, its light")
cmd("laminar/B747/ap_L/vhf_R/audio_sel_switch")
T.check(get(XA .. "audio_selection_com2") == 0 and ap("L", "vhf_R", "audio_status") == 0, "pushed again: off")
cmd("laminar/B747/ap_L/vhf_L/audio_sel_switch")
cmd("laminar/B747/ap_L/vhf_L/audio_sel_switch")
T.check(ap("L", "vhf_L", "audio_status") == 1 and get(XA .. "audio_selection_com1") == 1, "L's VHF L (its transmitter): not off")

-- 121.5 on VHF L: heard at every seat (ATA23 p.26)
T.equal(get(XA .. "audio_selection_com1_copilot"), 0, "copilot: COM1 not heard")
rt:set(XA .. "com1_frequency_hz_833", 121500)
rt:frame(1 / 30)
T.equal(get(XA .. "audio_selection_com1_copilot"), 1, "COM1 on 121.500: heard by the copilot too")
rt:set(XA .. "com1_frequency_hz_833", 118100)
rt:frame(1 / 30)

-- the navigation audio (COM-07): VOR L is X-Plane's NAV3 (before, NAV1:
-- the ILS), the filter V takes the identifier out, MKR not filtered
local L = "laminar/B747/ap_L/"
rt:set(L .. "vor_adf_rcvr/sel_dial_pos", 0)
rt:set(L .. "nav_filter/sel_dial_pos", 1)
rt:set(L .. "app_rcvr/sel_dial_pos", 0)
cmd("laminar/B747/ap_L/vor_adf/audio_sel_switch")
T.check(get(XA .. "audio_selection_nav3") == 1 and get(XA .. "audio_selection_nav1") == 0, "VOR L, filter B: X-Plane's NAV3 (not NAV1)")
cmd("laminar/B747/ap_L/vor_adf_rcvr/sel_dial_up")
cmd("laminar/B747/ap_L/vor_adf_rcvr/sel_dial_up")
cmd("laminar/B747/ap_L/vor_adf_rcvr/sel_dial_up")
T.check(get(XA .. "audio_selection_adf2") == 1 and get(XA .. "audio_selection_nav3") == 0, "ADF R: ADF2")
T.equal(get("laminar/B747/ap_C/vor_adf_rcvr/sel_dial_pos"), 0, "C's selector stays (before, all three turned: COM-02)")
cmd("laminar/B747/ap_L/app_mkr/audio_sel_switch")
T.equal(get(XA .. "audio_selection_nav1"), 1, "APP L: X-Plane's NAV1 (ILS L; before, the markers only)")
cmd("laminar/B747/ap_L/nav_filter/sel_dial_dn")
T.check(get(XA .. "audio_selection_adf2") == 0 and get(XA .. "audio_selection_nav1") == 0, "filter V: no identifiers")
rt:set(L .. "app_rcvr/sel_dial_pos", 3)
rt:frame(1 / 30)
T.equal(get(XA .. "audio_marker_enabled"), 1, "MKR with filter V: the markers (not filtered)")

-- the volume knobs: one seat's (COM-14)
local v0 = get(L .. "vhf_L/audio_vol")
local c0 = get("laminar/B747/ap_C/vhf_L/audio_vol")
cmd("laminar/B747/comm/ap_L/vhf_L_audio/vol_up")
T.equal(get(L .. "vhf_L/audio_vol"), v0 + 1, "L's VHF L volume up")
T.equal(get("laminar/B747/ap_C/vhf_L/audio_vol"), c0, "C's VHF L volume stays (before, linked)")
T.near(get(XA .. "audio_volume_com1"), (v0 + 1 - 30) / 300, 1e-6, "pilot: COM1's volume from L's knob")
T.done()
