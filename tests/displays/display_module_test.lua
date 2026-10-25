-- Run from the repository root with LuaJIT: luajit tests/displays/display_module_test.lua
-- The display units and EIUs glue (B747.60.xt.displays.lua, 5-2 step 1) in
-- the flight instruments module (B747.60.xt.fltInst) as XTLua runs it
-- (tests/lib/xtlua.lua): the INBD and LWR selectors (the F/O's mirrored),
-- the buses, the unit and EIU failures and the EIU selectors in; each
-- display's position and power for the panel, the unit showing it, the EIU
-- in use and >EIU LEFT out. Then the lighting module's brightness from the
-- unit's knob (DSP-30), and each PFD's sources and flags (step 4a). The
-- models are tested in display_model_test.lua and pfd_model_test.lua.
local T = dofile("tests/lib/check.lua")("display_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local FI, D = "laminar/B747/flt_inst/", "laminar/B747/flt_inst/display/"
local POWER = "laminar/B747/electrical/display_has_power"
local BUS = "laminar/B747/electrical/bus/"
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set(BUS .. b, 1) end
local function selectors(ci, cl, fi, fl)
    rt:set(FI .. "capt_inbd_display/sel_dial_pos", ci)
    rt:set(FI .. "capt_lwr_display/sel_dial_pos", cl)
    rt:set(FI .. "fo_inbd_display/sel_dial_pos", fi)
    rt:set(FI .. "fo_lwr_display/sel_dial_pos", fl)
    frames(0.1)
end
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 1)                      -- AUTO
rt:set(FI .. "eiu_src/fo/sel_dial_pos", 2)                        -- AUTO
rt:set(FI .. "eiu_src/ctr_pnl/sel_dial_pos", 1)                   -- AUTO
rt:callout("flight_start")
selectors(1, 1, 1, 1)
frames(1)

-- normal
for _, n in ipairs({"capt/pfd_pos", "fo/pfd_pos", "capt/nd_pos", "fo/nd_pos", "eicas_pos", "pri_eicas_pos"}) do
    T.equal(rt:get(D .. n), 0, "normal: " .. n .. " 0")
end
for c = 0, 5 do T.equal(rt:get(POWER, c), 6, "normal: display_has_power[" .. c .. "] 6") end
T.equal(rt:get("laminar/B747/displays/content_unit", 0), 1, "Captain's PFD on unit 1 (Captain outboard)")
T.equal(rt:get("laminar/B747/displays/content_unit", 5), 4, "secondary EICAS on unit 4 (lower)")
T.equal(rt:get("laminar/B747/eiu/used", 0), 1, "Captain's EIU L")
T.equal(rt:get("laminar/B747/eiu/used", 1), 3, "F/O's EIU R")

-- failures and automatic switching (FCOM p.1045, p.1072)
rt:set("laminar/B747/displays/fail", 0, 1)                         -- Captain outboard
rt:set("laminar/B747/displays/fail", 2, 1)                         -- upper
frames(0.1)
T.equal(rt:get(D .. "capt/pfd_pos"), 1, "the Captain's outboard unit fails: PFD inboard")
T.equal(rt:get(POWER, 3), 0, "the Captain's ND off")
T.equal(rt:get(D .. "pri_eicas_pos"), 1, "the upper unit fails: primary EICAS on the lower unit")
T.equal(rt:get(POWER, 5), 0, "the secondary EICAS off")
rt:set("laminar/B747/displays/fail", 0, 0)
rt:set("laminar/B747/displays/fail", 2, 0)

-- the selectors, the F/O's mirrored (INBD PFD NORM EICAS, LWR ND NORM EICAS PRI)
selectors(0, 1, 1, 1)
T.equal(rt:get(D .. "eicas_pos"), 2, "the Captain's INBD EICAS: the secondary on his inboard unit")
T.equal(rt:get(POWER, 3), 0, "the Captain's ND off")
selectors(1, 1, 2, 1)
T.equal(rt:get(D .. "eicas_pos"), 1, "the F/O's INBD at EICAS (position 2): the secondary on the F/O's inboard unit")
selectors(1, 1, 0, 1)
T.equal(rt:get(D .. "fo/pfd_pos"), 1, "the F/O's INBD at PFD (position 0): the PFD inboard")
selectors(1, 1, 1, 0)
T.equal(rt:get(D .. "fo/nd_pos"), 1, "the F/O's LWR at ND (position 0): the F/O's ND on the lower unit")
selectors(1, 0, 1, 1)
T.equal(rt:get(D .. "pri_eicas_pos"), 1, "the Captain's LWR EICAS PRI: the primary on the lower unit")
selectors(1, 1, 1, 1)

-- the EIUs (FCOM p.1044, p.1199, p.1529)
rt:set("laminar/B747/eiu/fail", 0, 1)
rt:set("laminar/B747/gear/air_ground/pri_air", 0)
frames(0.1)
T.equal(rt:get("laminar/B747/eiu/used", 0), 2, "the left EIU failed: the Captain's AUTO takes C")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 91), 1, ">EIU LEFT on the ground")
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
frames(0.1)
T.equal(rt:get("laminar/B747/CAS/advisory_status", 91), 0, ">EIU LEFT inhibited in flight")
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 0)                      -- L
frames(0.1)
T.equal(rt:get("laminar/B747/eiu/used", 0), 0, "the Captain's selector at L: no EIU")
T.equal(rt:get(POWER, 0) + rt:get(POWER, 3), 0, "the Captain's PFD and ND off")
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 1)
rt:set(BUS .. "any_ac", 0)
frames(0.1)
for c = 0, 5 do T.equal(rt:get(POWER, c), 0, "standby power, the left EIU failed: display " .. c .. " off") end
rt:set(BUS .. "any_ac", 1)
rt:set("laminar/B747/eiu/fail", 0, 0)
rt:set(BUS .. "stby_apu", 0)
frames(0.1)
T.equal(rt:get(POWER, 0) + rt:get(POWER, 3), 0, "no APU standby bus: the Captain's PFD and ND off (FCOM p.800)")
rt:set(BUS .. "stby_apu", 1)
frames(0.1)

-- the source selectors and the control panels (FCOM p.1043, p.1197-1199; step 2)
local ADV = "laminar/B747/CAS/advisory_status"
rt:set(FI .. "flt_dir_src/capt/sel_dial_pos", 0)                  -- L
rt:set(FI .. "flt_dir_src/fo/sel_dial_pos", 2)                    -- R
rt:set(FI .. "nav_src/capt/sel_dial_pos", 0)                      -- FMC L
rt:set(FI .. "nav_src/fo/sel_dial_pos", 3)                        -- FMC R
frames(0.1)
T.equal(rt:get(ADV, 268) + rt:get(ADV, 269) + rt:get(ADV, 271), 0, "normal positions: no >SOURCE SEL EIU, F/D, NAV")
rt:set(FI .. "flt_dir_src/fo/sel_dial_pos", 0)
frames(0.1)
T.equal(rt:get(ADV, 269), 1, "both FLT DIR at L: >SOURCE SEL F/D")
rt:set(FI .. "flt_dir_src/fo/sel_dial_pos", 2)
rt:set(FI .. "nav_src/capt/sel_dial_pos", 1)                      -- FMC R
frames(0.1)
T.equal(rt:get(ADV, 269), 0, "F/D apart")
T.equal(rt:get(ADV, 271), 1, "both NAV on FMC R: >SOURCE SEL NAV")
rt:set(FI .. "nav_src/capt/sel_dial_pos", 2)                      -- CDU L
rt:set(FI .. "nav_src/fo/sel_dial_pos", 0)                        -- CDU C
frames(0.1)
T.equal(rt:get(ADV, 271), 0, "both on CDUs: no >SOURCE SEL NAV")
rt:set(FI .. "nav_src/capt/sel_dial_pos", 0)
rt:set(FI .. "nav_src/fo/sel_dial_pos", 3)
rt:set(FI .. "eiu_src/fo/sel_dial_pos", 0)                        -- L
frames(0.1)
T.equal(rt:get(ADV, 268), 1, "both on EIU L: >SOURCE SEL EIU")
rt:set(FI .. "eiu_src/fo/sel_dial_pos", 2)
rt:set("laminar/B747/efis/fail", 0, 1)
frames(0.1)
T.equal(rt:get(ADV, 88), 1, "left EFIS control panel failed: >EFIS CONTROL L")
rt:set("laminar/B747/efis/fail", 1, 1)
rt:set("laminar/B747/dsp/fail", 1)
frames(0.1)
T.equal(rt:get(ADV, 90), 1, "both panels and the display select panel: >EFIS/EICAS C/P")
rt:set("laminar/B747/efis/fail", 0, 0)
rt:set("laminar/B747/efis/fail", 1, 0)
rt:set("laminar/B747/dsp/fail", 0)
frames(0.1)
T.equal(rt:get(ADV, 88) + rt:get(ADV, 89) + rt:get(ADV, 90), 0, "messages clear")

-- the lighting module: a display takes the knob of the unit it is on (DSP-30)
rt:load("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.xt.lighting.lua")
rt:callout("flight_start")
rt:set("sim/flightmodel2/lights/generic_lights_brightness_ratio", 63, 1)
local KNOB = "laminar/B747/switches/instrument_brightness_ratio"
selectors(2, 1, 1, 1)                                              -- the Captain's INBD PFD
frames(1)
T.equal(rt:get("laminar/B747/displays/content_unit", 0), 2, "the Captain's PFD on unit 2 (inboard)")
rt:set(KNOB, 0, 0.3)                                               -- the inboard knob
rt:set(KNOB, 2, 0.9)                                               -- the outboard knob
frames(20)
T.near(rt:get("sim/cockpit2/switches/instrument_brightness_ratio", 2), 0.3, 0.02,
    "the PFD (rheostat 2) on the inboard unit takes the inboard knob")
selectors(1, 1, 1, 1)
frames(20)
T.near(rt:get("sim/cockpit2/switches/instrument_brightness_ratio", 2), 0.9, 0.02,
    "back on the outboard unit: the outboard knob")

-- the PFD sources (step 4a, the PFD sources model): the IRUs, the IRS
-- selectors, the NAV source and the air data in; what each PFD shows out
local IRS, P = "laminar/B747/irs/", "laminar/B747/pfd/"
for i = 0, 2 do
    rt:set(IRS .. "att_valid", i, 1)
    rt:set(IRS .. "hdg_valid", i, 1)
    rt:set(IRS .. "nav_valid", i, 1)
end
rt:set("laminar/B747/airdata/valid_capt", 1)
rt:set("laminar/B747/airdata/valid_fo", 1)
rt:set(FI .. "irs_src/fo/sel_dial_pos", 2)                         -- the F/O's IRS R
frames(0.1)
for _, s in ipairs({"capt", "fo"}) do
    for _, n in ipairs({"att", "hdg", "trk", "vsi"}) do T.equal(rt:get(P .. s .. "/" .. n), 1, s .. ": " .. n .. " shown") end
    T.equal(rt:get(P .. s .. "/vert"), 0, s .. ": no VERT flag")
end
rt:set(IRS .. "nav_valid", 0, 0)                                    -- IRU L in ATT, a heading set
frames(0.1)
T.equal(rt:get(P .. "capt/vert"), 1, "IRU L in ATT: the Captain's VERT flag")
T.equal(rt:get(P .. "capt/hdg"), 1, "the heading through FMC L from IRU C (FCOM p.1228)")
rt:set(FI .. "nav_src/capt/sel_dial_pos", 2)                       -- the Captain's NAV CDU L
rt:set(IRS .. "hdg_valid", 0, 0)
frames(0.1)
T.equal(rt:get(P .. "capt/hdg"), 0, "NAV on CDU L, IRU L in ATT without a heading: the HDG flag")
T.equal(rt:get(P .. "fo/hdg"), 1, "the F/O's heading (IRU R) unaffected")
rt:set(FI .. "irs_src/capt/sel_dial_pos", 1)                       -- the Captain's IRS C
rt:set("laminar/B747/airdata/valid_capt", 0)
frames(0.1)
T.equal(rt:get(P .. "capt/hdg"), 1, "IRS C: the heading from IRU C")
T.equal(rt:get(P .. "capt/vsi"), 0, "the Captain's air data invalid: no vertical speed")
T.equal(rt:get(P .. "capt/vert"), 0, "and no VERT flag (ATA31 p.16)")

-- the barometric setting's amber box at the transition (step 4b, FCOM p.995)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 35000)
rt:set("laminar/B747/airdata/alt_capt", 18400)
rt:set("laminar/B747/airdata/alt_fo", 18200)
frames(0.1)
T.equal(rt:get(P .. "capt/baro_alert"), 1, "a setting set, climbing to FL350 at 18,400 ft: the Captain's boxed amber")
T.equal(rt:get(P .. "fo/baro_alert"), 0, "the F/O at 18,200 ft: not yet")
rt:command("laminar/B747/efis/baro_std/capt/switch")
frames(0.1)
T.equal(rt:get(P .. "capt/baro_alert"), 0, "the Captain sets STD: cleared")
rt:set("laminar/B747/fms/data", '{"crzalt":"FL350","transalt":"14000"}')
rt:set("laminar/B747/airdata/alt_fo", 14400)
frames(2.5)
T.equal(rt:get(P .. "fo/baro_alert"), 1, "the FMC's transition altitude 14,000 ft: the F/O's boxed at 14,400 ft")
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 10000)
rt:set("laminar/B747/airdata/alt_capt", 17600)
frames(0.1)
T.equal(rt:get(P .. "capt/baro_alert"), 1, "STD, descending to 10,000 ft at 17,600 ft (300 ft below FL180): boxed amber")

T.done()
