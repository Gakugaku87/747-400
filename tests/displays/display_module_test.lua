-- Run from the repository root with LuaJIT: luajit tests/displays/display_module_test.lua
-- The display units and EIUs glue (B747.60.xt.displays.lua, 5-2 step 1) in
-- the flight instruments module (B747.60.xt.fltInst) as XTLua runs it
-- (tests/lib/xtlua.lua): the INBD and LWR selectors (the F/O's mirrored),
-- the buses, the unit and EIU failures and the EIU selectors in; each
-- display's position and power for the panel, the unit showing it, the EIU
-- in use and >EIU LEFT out. Then the lighting module's brightness from the
-- unit's knob (DSP-30), and each PFD's sources and flags (step 4a), the ILS
-- (step 4e) on the receiver of the EIU in use and each ND's APP mode (step
-- 5b), the ND's orientation (step 5a). The models are tested in
-- display_model_test.lua, pfd_model_test.lua, pfd_ils_model_test.lua and
-- nd_model_test.lua.
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
T.equal(rt:get(D .. "eicas_pos"), 2, "the Captain's INBD EICAS: the secondary on the Captain's inboard unit")
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

-- the flight path vector (step 4d): the FPV switch latches now; the IRU's
-- NAV data, else the FPV flag
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.pfd_model.lua")
for i = 0, 2 do rt:set(IRS .. "nav_valid", i, 1) end
rt:set(FI .. "irs_src/capt/sel_dial_pos", 0)
frames(0.1)
T.equal(rt:get(P .. "capt/fpv_show"), 0, "FPV not selected: none")
rt:command("laminar/B747/efis/fpv/capt/switch")
frames(0.1)
T.equal(rt:get("laminar/B747/efis/fpv/capt/selected"), 1, "the FPV switch: selected (it latches)")
T.equal(rt:get(P .. "capt/fpv_show"), 1, "the Captain's FPV shown")
T.equal(rt:get(P .. "fo/fpv_show"), 0, "the F/O's not")
rt:set("sim/flightmodel/position/vpath", -3)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot", 2)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)
rt:set("sim/flightmodel/position/hpath", 100)
rt:set("sim/flightmodel/position/psi", 98)
frames(0.1)
T.near(rt:get(P .. "capt/fpv_y"), -5 * PM.PX_PER_DEG, 1e-3, "flight path -3, pitch 2: 5 degrees below the airplane symbol")
T.near(rt:get(P .. "capt/fpv_x"), 2 * PM.PX_PER_DEG, 1e-3, "track 100, heading 98: 2 degrees right")
rt:set(IRS .. "nav_valid", 0, 0)
frames(0.1)
T.equal(rt:get(P .. "capt/fpv_show"), 0, "IRU L out of NAV: no FPV")
T.equal(rt:get(P .. "capt/fpv_flag"), 1, "the FPV flag")
rt:command("laminar/B747/efis/fpv/capt/switch")
frames(0.1)
T.equal(rt:get(P .. "capt/fpv_flag"), 0, "deselected: no flag")
-- the PITCH and ROLL flags: both attitudes shown and 3 degrees apart
rt:set(IRS .. "nav_valid", 0, 1)
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_copilot", 6)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_copilot", 0)
frames(0.1)
T.equal(rt:get(P .. "pitch_flag"), 1, "pitch 2 and 6: PITCH")
T.equal(rt:get(P .. "roll_flag"), 0, "roll alike: no ROLL")
rt:set("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_copilot", 2)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_copilot", 5)
frames(0.1)
T.equal(rt:get(P .. "pitch_flag"), 0, "pitch alike: no PITCH")
T.equal(rt:get(P .. "roll_flag"), 1, "roll 0 and 5: ROLL")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_copilot", 0)

-- the ILS (steps 4e, 5b): each PFD on the receiver of the EIU in use, the
-- Captain's EIU L ILS L (X-Plane's NAV1), the F/O's EIU R ILS R (NAV2);
-- tuned by the stock autopilot/ils_dots
local NAV = "sim/cockpit2/radios/indicators/nav"
rt:set(BUS .. "ac", 1, 1)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 0, "no ILS tuned: no approach reference")
T.equal(rt:get(P .. "capt/loc_scale"), 0, "no localizer scale")
rt:set("laminar/B747/autopilot/ils_dots", 1)
rt:set(NAV .. "1_display_horizontal", 1)
rt:set(NAV .. "1_display_vertical", 1)
rt:set(NAV .. "1_hdef_dots_pilot", 1.5)
rt:set(NAV .. "1_vdef_dots_pilot", -2.5)
rt:set("sim/cockpit2/radios/actuators/nav1_frequency_hz", 11190)
rt:set("sim/cockpit2/radios/actuators/nav2_frequency_hz", 10970)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 1, "tuned: the Captain's approach reference and course")
T.equal(rt:get(P .. "capt/ils_rx"), 1, "the Captain's EIU L: ILS L")
T.equal(rt:get(P .. "fo/ils_rx"), 3, "the F/O's EIU R: ILS R")
T.near(rt:get(P .. "capt/loc_dots"), 1.5, 1e-6, "the Captain's localizer deviation: NAV1's")
T.near(rt:get(P .. "capt/gs_dots"), -2.5, 1e-6, "the Captain's glideslope deviation: NAV1's")
T.equal(rt:get(P .. "capt/loc_scale"), 1, "the localizer scale")
T.equal(rt:get(P .. "capt/loc_ptr"), 1, "localizer 1.5 dots: filled")
T.equal(rt:get(P .. "capt/gs_ptr"), 2, "glideslope -2.5 dots: hollow")
T.equal(rt:get(P .. "fo/ils_show"), 1, "the F/O's ILS R tuned too")
T.equal(rt:get(P .. "fo/loc_ptr"), 0, "no signal on NAV2: no pointer")
T.equal(rt:get(P .. "capt/ils_ref"), "111.90", "no identification yet: the frequency (ATA34_1 p.466)")
rt:set(NAV .. "1_nav_id", "IYQ")
frames(0.1)
T.equal(rt:get(P .. "capt/ils_ref"), "IYQ", "then the identifier")
-- X-Plane keeps display_vertical at 1 on an ILS frequency without the
-- glideslope and raises its EFIS glideslope flag
rt:set(NAV .. "1_flag_glideslope", 1)
frames(0.1)
T.equal(rt:get(P .. "capt/gs_ptr"), 0, "no glideslope received: no pointer (NCD)")
T.equal(rt:get(P .. "capt/gs_flag"), 0, "and no G/S flag")
rt:set(NAV .. "1_flag_glideslope", 0)
frames(0.1)
T.equal(rt:get(P .. "capt/gs_ptr"), 2, "received again: the pointer")
T.equal(rt:get(P .. "fo/ils_ref"), "109.70", "the F/O's ILS R: NAV2's frequency")
T.equal(rt:get("laminar/B747/CAS/caution_status", 57), 0, "EIU L and R: no >SNGL SOURCE ILS")
-- the Captain's EIU selector at R: ILS R on both PFDs (FCOM p.1044)
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 3)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_rx"), 3, "the Captain's EIU R: ILS R")
T.equal(rt:get(P .. "capt/loc_ptr"), 0, "no signal on NAV2: no pointer")
T.equal(rt:get(P .. "capt/ils_ref"), "109.70", "NAV2's frequency")
T.equal(rt:get("laminar/B747/CAS/caution_status", 57), 1, ">SNGL SOURCE ILS (FCOM p.1430)")
rt:set(NAV .. "2_display_horizontal", 1)
rt:set(NAV .. "2_hdef_dots_pilot", -1.2)
frames(0.1)
T.near(rt:get(P .. "capt/loc_dots"), -1.2, 1e-6, "NAV2's deviation")
T.equal(rt:get(P .. "capt/loc_ptr"), 1, "and its pointer")
-- EIU C: ILS C, NAV1's data on AC bus 1 (estimate)
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 2)
rt:set(BUS .. "ac", 0, 1)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_rx"), 2, "the Captain's EIU C: ILS C")
T.near(rt:get(P .. "capt/loc_dots"), 1.5, 1e-6, "NAV1's deviation")
T.equal(rt:get("laminar/B747/CAS/caution_status", 57), 0, "no >SNGL SOURCE ILS")
rt:set(BUS .. "ac", 0, 0)
frames(0.1)
T.equal(rt:get(P .. "capt/loc_flag"), 1, "AC bus 1 unpowered: ILS C fails, the LOC flag")
rt:set(FI .. "eiu_src/capt/sel_dial_pos", 1)
rt:set(NAV .. "2_display_horizontal", 0)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_rx"), 1, "AUTO: EIU L, ILS L")
T.equal(rt:get(P .. "capt/loc_flag"), 0, "no LOC flag")
-- each ND in APP mode on the same receiver (step 5b)
local ND = "laminar/B747/nd/"
rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 0, 337.4)
rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 1, 151)
rt:set(NAV .. "1_has_dme", 1)
rt:set(NAV .. "1_dme_distance_nm", 10.3)
frames(0.1)
T.equal(rt:get(ND .. "dashes"), "---", "nd/dashes for the panel")
T.equal(rt:get(ND .. "capt/loc_scale"), 1, "the Captain's ND: the localizer scale")
T.equal(rt:get(ND .. "capt/loc_ptr"), 1, "1.5 dots: filled")
T.equal(rt:get(ND .. "capt/gs_ptr"), 2, "glideslope 2.5 dots: hollow")
T.equal(rt:get(ND .. "capt/crs"), 2, "the course")
T.near(rt:get(ND .. "capt/crs_deg"), 337.4, 1e-4, "NAV1's course from the CDU")
T.equal(rt:get(ND .. "capt/dme"), 1, "the DME distance")
T.near(rt:get(ND .. "capt/dme_nm"), 10.3, 1e-4, "NAV1's")
T.equal(rt:get(ND .. "capt/ils_ref"), "IYQ", "the identifier")
T.equal(rt:get(ND .. "fo/ils_ref"), "109.70", "the F/O's ND: NAV2's frequency")
T.near(rt:get(ND .. "fo/crs_deg"), 151, 1e-4, "and NAV2's course")
T.equal(rt:get(ND .. "fo/dme"), 0, "no NAV2 DME: dashes")
T.equal(rt:get(ND .. "fo/loc_ptr"), 0, "no NAV2 signal: no bar")
rt:set("sim/operation/failures/rel_dme", 6)
rt:set("sim/operation/failures/rel_loc", 6)
frames(0.1)
T.equal(rt:get(ND .. "capt/dme"), 2, "X-Plane's DME failure: the DME flag")
T.equal(rt:get(ND .. "capt/loc_flag"), 1, "X-Plane's localizer failure: the ND's LOC flag")
T.equal(rt:get(ND .. "capt/loc_scale"), 0, "instead of the scale")
rt:set("sim/operation/failures/rel_dme", 0)
rt:set("sim/operation/failures/rel_loc", 0)
rt:set("laminar/B747/autopilot/ils_dots", 0)
frames(0.1)
T.equal(rt:get(ND .. "capt/ils_ref"), "---", "parked: the frequency dashes")
T.equal(rt:get(ND .. "capt/crs"), 1, "the course dashes")
T.equal(rt:get(ND .. "capt/loc_ptr"), 0, "no bar")
rt:set("laminar/B747/autopilot/ils_dots", 1)
frames(0.1)
T.equal(rt:get(ND .. "capt/ils_ref"), "IYQ", "tuned again: the identifier")
rt:set("sim/operation/failures/rel_gls", 6)
frames(0.1)
T.equal(rt:get(P .. "capt/gs_flag"), 1, "X-Plane's glide slope failure: the G/S flag")
T.equal(rt:get(P .. "capt/gs_scale"), 0, "no glideslope scale")
T.equal(rt:get(P .. "capt/loc_flag"), 0, "no LOC flag")
rt:set("sim/operation/failures/rel_gls", 0)
rt:set("sim/operation/failures/rel_nav1", 6)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 0, "NAV1 (ILS L) failed: the Captain's approach reference blank")
T.check(rt:get(P .. "capt/loc_flag") == 1 and rt:get(P .. "capt/gs_flag") == 1, "the LOC and G/S flags")
T.equal(rt:get(P .. "fo/ils_show"), 1, "the F/O's ILS R still")
rt:set("sim/operation/failures/rel_nav1", 0)
rt:set(BUS .. "ac", 1, 0)
frames(0.1)
T.equal(rt:get(P .. "fo/loc_flag"), 1, "AC bus 2 unpowered: ILS R fails, the F/O's LOC flag")
T.equal(rt:get(P .. "capt/loc_flag"), 0, "not the Captain's")
rt:set(BUS .. "ac", 1, 1)
-- the glideslope warning: G/S engaged with the A/P, 400 ft, 0.7 dot
rt:set(NAV .. "1_vdef_dots_pilot", 0.7)
rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", 2)
rt:set("laminar/B747/ra/capt/value", 400)
frames(0.1)
T.equal(rt:get(P .. "capt/gs_scale"), 1, "no A/P or flight director: no warning")
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)
frames(0.1)
T.equal(rt:get(P .. "capt/gs_scale"), 2, "with the A/P: the glideslope scale amber")
local dark, lit = false, false
for _ = 1, 15 do
    rt:frame(1 / 30)
    local v = rt:get(P .. "capt/gs_ptr")
    dark, lit = dark or v == 0, lit or v == 1
end
T.check(dark and lit, "the pointer flashes")
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 0)
-- the rising runway below 2,500 ft with the localizer pointer
rt:set("laminar/B747/ra/capt/show", 1)
frames(0.1)
T.equal(rt:get(P .. "capt/rwy_show"), 1, "the rising runway")
-- beyond 53 degrees of roll
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 55)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 0, "roll 55 degrees: the ILS removed")
T.check(rt:get(P .. "capt/loc_scale") == 0 and rt:get(P .. "capt/gs_scale") == 0 and rt:get(P .. "capt/rwy_show") == 0,
    "the scales and the rising runway too")
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)

-- the ND (step 5a): each ND from its own side and mode; the 570 (GE) is
-- track up in MAP as the 109 (these checks and the ones after), the 405
-- (PW; RR as PW) heading up (the last block: the user's choice of the 405,
-- 2026-10-27)
local NDP = "laminar/B747/nd/"
rt:set("laminar/B747/engines/type", 1)                             -- the 570 (GE)
rt:set(IRS .. "hdg_valid", 0, 1)                                   -- IRU L's heading back
rt:set(NDP .. "mode/capt/sel_dial_pos", 2)                         -- MAP
rt:set(NDP .. "mode/fo/sel_dial_pos", 1)                           -- VOR
rt:set("sim/cockpit2/EFIS/map_mode_copilot", 2)                   -- the stock's VOR (X-Plane's MAP)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 250)
rt:set("sim/cockpit2/gauges/indicators/wind_heading_deg_mag", 350)
frames(0.1)
T.equal(rt:get("sim/cockpit2/EFIS/map_mode"), 2, "the Captain's MAP: X-Plane's map mode 2 (track up)")
T.equal(rt:get("sim/cockpit2/EFIS/map_mode_copilot"), 0, "the F/O's VOR: X-Plane's heading-up mode 0")
T.check(rt:get(NDP .. "capt/box") == 2 and rt:get(NDP .. "fo/box") == 1, "the boxes: the Captain's TRK, the F/O's HDG")
T.equal(rt:get(NDP .. "capt/rose"), 1, "the Captain's rose (track valid)")
T.equal(rt:get(NDP .. "capt/hdg_ptr"), 1, "the current heading pointer")
T.equal(rt:get(NDP .. "capt/hdg_bug"), 1, "the selected heading bug")
T.equal(rt:get(NDP .. "capt/wind"), 1, "the wind arrow at 250 kt")
T.equal(rt:get(NDP .. "capt/trk_line"), 1, "MAP expanded: the track line")
T.equal(rt:get(NDP .. "fo/trk_line"), 0, "the F/O's VOR without WXR or TFC: none")
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 100)
frames(0.1)
T.near(rt:get(NDP .. "capt/wind_deg"), 70, 1e-6, "wind from 350 on a track-up display (track 100): 70 right")
for i = 0, 2 do rt:set(IRS .. "nav_valid", i, 0) end
frames(0.1)
T.equal(rt:get(NDP .. "capt/map_flag"), 1, "no IRU in NAV: the MAP flag (estimate)")
T.equal(rt:get(NDP .. "capt/vtk_flag"), 1, "and VTK")
T.equal(rt:get(NDP .. "capt/trk_flag"), 1, "no track either: TRK")
T.equal(rt:get(NDP .. "capt/rose"), 0, "no rose")
T.equal(rt:get(NDP .. "fo/hdg_flag"), 0, "the F/O's VOR: the heading still good (IRU R in ATT)")
for i = 0, 2 do rt:set(IRS .. "nav_valid", i, 1) end
rt:set(NDP .. "mode/capt/sel_dial_pos", 3)                         -- PLN
frames(0.1)
T.equal(rt:get("sim/cockpit2/EFIS/map_mode"), 4, "PLN: X-Plane's 4")
T.equal(rt:get(NDP .. "capt/box"), 4, "the 570's PLN: TRK in PLAN's box")
T.equal(rt:get(NDP .. "capt/hdg_ptr_pln"), 1, "PLN's heading pointer")
T.equal(rt:get(NDP .. "capt/hdg_bug"), 0, "no selected heading in PLN")

-- the VOR mode's reference VOR (step 5b): the Captain's VOR L (NAV3), the
-- F/O's VOR R (NAV4); autotuned unless the CDU tuned it
local RAD = "sim/cockpit2/radios/"
rt:set(NDP .. "mode/capt/sel_dial_pos", 1)                         -- VOR
rt:set("laminar/B747/radio/tuningmodes", "AAAMM")
rt:set(RAD .. "actuators/nav_frequency_hz", 2, 11790)
rt:set(RAD .. "actuators/nav_frequency_hz", 3, 11360)
rt:set(RAD .. "indicators/nav_display_horizontal", 2, 1)
rt:set(RAD .. "indicators/nav_flag_from_to_pilot", 2, 1)
rt:set(RAD .. "indicators/nav_has_dme", 2, 1)
rt:set(RAD .. "indicators/nav_dme_distance_nm", 2, 14.2)
rt:set(RAD .. "actuators/nav_obs_deg_mag_pilot", 2, 330)
rt:set(RAD .. "indicators/nav3_nav_id", "NRE")
frames(0.1)
T.equal(rt:get(NDP .. "capt/vor_rx"), 1, "the Captain's reference: VOR L")
T.equal(rt:get(NDP .. "fo/vor_rx"), 2, "the F/O's: VOR R")
T.equal(rt:get(NDP .. "capt/vor_crs"), 1, "autotuned: the course dashes")
T.equal(rt:get(NDP .. "capt/vor_dev"), 0, "no deviation")
T.equal(rt:get(NDP .. "capt/vor_ref"), "NRE", "the identifier")
T.equal(rt:get(NDP .. "fo/vor_ref"), "113.60", "the F/O's VOR R: no identification, the frequency")
T.equal(rt:get(NDP .. "capt/vor_dme"), 1, "the DME")
T.near(rt:get(NDP .. "capt/vor_dme_nm"), 14.2, 1e-4, "NAV3's distance")
rt:set("laminar/B747/radio/tuningmodes", "AMAMM")
frames(0.1)
T.equal(rt:get(NDP .. "capt/vor_crs"), 2, "VOR L tuned on the CDU: the course")
T.near(rt:get(NDP .. "capt/vor_crs_deg"), 330, 1e-4, "the CDU's course")
T.equal(rt:get(NDP .. "capt/vor_dev"), 1, "the deviation bar and scale")
T.equal(rt:get(NDP .. "capt/to_from"), 1, "TO")
T.equal(rt:get(NDP .. "fo/vor_crs"), 1, "VOR R still autotuned")
rt:set(RAD .. "indicators/nav_flag_from_to_pilot", 2, 2)
frames(0.1)
T.equal(rt:get(NDP .. "capt/to_from"), 2, "FROM")
rt:set(BUS .. "stby_main", 0)
frames(0.1)
T.equal(rt:get(NDP .. "capt/vor_flag"), 1, "the AC standby bus unpowered: the VOR L flag")
T.equal(rt:get(NDP .. "capt/vor_ref"), "", "no frequency")
T.equal(rt:get(NDP .. "capt/vor_crs"), 0, "no course")
rt:set(BUS .. "stby_main", 1)
rt:set(BUS .. "ac", 1, 0)
frames(0.1)
T.equal(rt:get(NDP .. "fo/vor_flag"), 2, "AC bus 2 unpowered: the VOR R flag")
rt:set(BUS .. "ac", 1, 1)
frames(0.1)
T.equal(rt:get(NDP .. "fo/vor_flag"), 0, "powered again: no flag")

-- the bearing pointers (step 5b): X-Plane's EFIS switches (0 ADF, 1 OFF,
-- 2 VOR), the Captain's MAP
rt:set(NDP .. "mode/capt/sel_dial_pos", 2)                         -- MAP
rt:set("sim/cockpit2/EFIS/EFIS_1_selection_pilot", 2)              -- VOR L
rt:set("sim/cockpit2/EFIS/EFIS_2_selection_pilot", 0)              -- ADF R
rt:set("sim/cockpit2/EFIS/EFIS_1_selection_copilot", 1)            -- OFF
rt:set("sim/cockpit2/EFIS/EFIS_2_selection_copilot", 1)
rt:set(RAD .. "indicators/nav_relative_bearing_deg", 2, 30)
rt:set(RAD .. "indicators/adf2_relative_bearing_deg", -50)
rt:set(RAD .. "indicators/adf2_nav_id", "TY")
rt:set(RAD .. "actuators/adf1_frequency_hz", 334)
rt:set("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", 100)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 110)
rt:set(BUS .. "ac", 2, 1)
frames(0.1)
T.equal(rt:get(NDP .. "capt/ptr_l"), 1, "the Captain's left pointer: VOR L")
T.equal(rt:get(NDP .. "capt/ptr_r"), 2, "the right: ADF R")
T.near(rt:get(NDP .. "capt/brg_l"), 20, 1e-4, "on the track-up map (110): 30 from heading 100 is 20 right")
T.near(rt:get(NDP .. "capt/brg_r"), -60, 1e-4, "ADF R 60 left")
T.equal(rt:get(NDP .. "capt/rad_l"), 1, "the lower left block: VOR")
T.equal(rt:get(NDP .. "capt/rad_r"), 2, "the lower right: ADF")
T.equal(rt:get(NDP .. "fo/rad_l"), 0, "the F/O's switches OFF: nothing")
T.equal(rt:get(ND .. "vor_l_ref"), "NRE", "VOR L's identifier")
T.equal(rt:get(ND .. "adf_r_ref"), "TY", "ADF R's identifier")
T.equal(rt:get(ND .. "adf_l_ref"), "334", "ADF L without identification: its frequency in kHz")
rt:set("sim/operation/failures/rel_adf2", 6)
frames(0.1)
T.equal(rt:get(NDP .. "capt/ptr_r"), 0, "ADF R failed: no pointer")
T.equal(rt:get(NDP .. "capt/rad_r_flag"), 1, "its flag")
T.equal(rt:get(ND .. "adf_r_ref"), "", "no frequency")
rt:set("sim/operation/failures/rel_adf2", 0)

-- step 5c: DATA and POS latch; a failed EFIS control panel takes no input
-- (>EFIS CONTROL L, R: FCOM p.1198), and the CDU's STD and DH RESET still
-- work through their own commands (FCOM p.1060-1062)
local EF = "laminar/B747/efis/"
rt:command("laminar/B747/nd/data/capt/switch")
rt:command("laminar/B747/nd/pos/capt/switch")
T.check(rt:get(ND .. "data/capt/data") == 1 and rt:get(ND .. "data/capt/pos") == 1, "DATA and POS pushed: selected")
rt:command("laminar/B747/nd/data/capt/switch")
T.equal(rt:get(ND .. "data/capt/data"), 0, "DATA pushed again: removed")
rt:set(EF .. "fail", 0, 1)
local fpv = rt:get(EF .. "fpv/capt/selected")
local range = rt:get(ND .. "range/capt/sel_dial_pos")
rt:command(EF .. "fpv/capt/switch")
rt:command("laminar/B747/nd/pos/capt/switch")
rt:command("laminar/B747/nd/range/capt/sel_dial_up")
T.equal(rt:get(EF .. "fpv/capt/selected"), fpv, "the Captain's panel failed: its FPV switch does nothing")
T.equal(rt:get(ND .. "data/capt/pos"), 1, "nor POS")
T.equal(rt:get(ND .. "range/capt/sel_dial_pos"), range, "nor the range selector")
rt:command("laminar/B747/nd/data/fo/switch")
T.equal(rt:get(ND .. "data/fo/data"), 1, "the F/O's panel works: DATA selected")
local std = rt:get(EF .. "baro_std/capt/switch_pos")
rt:command(EF .. "baro_std/capt/switch")
T.equal(rt:get(EF .. "baro_std/capt/switch_pos"), std, "the failed panel's STD: nothing")
rt:command(EF .. "baro_std/capt/cdu")
T.equal(rt:get(EF .. "baro_std/capt/switch_pos"), 1 - std, "the CDU's STD entry: STD")
rt:command(EF .. "baro_std/capt/cdu")
T.equal(rt:get(EF .. "baro_std/capt/switch_pos"), std, "and back")
-- DH 200 ft: armed above 275 ft, the amber DH below 200 ft (FCOM p.981-982)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot", 200)
rt:set("laminar/B747/ra/capt/flag", 0)
rt:set("laminar/B747/ra/capt/value", 400)
frames(0.1)
rt:set("laminar/B747/ra/capt/value", 190)
frames(4)
T.equal(rt:get("laminar/B747/dec_height/display_status"), 1, "below DH: the amber DH")
rt:command(EF .. "dh/capt/reset_switch")
frames(0.1)
T.equal(rt:get("laminar/B747/dec_height/display_status"), 1, "the failed panel's MINS RST: still")
rt:command(EF .. "dh/fo/cdu_reset")
frames(0.1)
T.equal(rt:get("laminar/B747/dec_height/display_status"), 1, "the right CDU's DH RESET: the Captain's still")
rt:command(EF .. "dh/capt/cdu_reset")
frames(0.1)
T.equal(rt:get("laminar/B747/dec_height/display_status"), 0, "the left CDU's DH RESET: reset")
-- the VOR/ADF switches: X-Plane's selector commands, taken over (up towards
-- VOR 2, down towards ADF 0)
local SEL = "sim/cockpit2/EFIS/EFIS_"
rt:set(SEL .. "1_selection_pilot", 0)
rt:command("sim/instruments/EFIS_1_pilot_sel_up")
T.equal(rt:get(SEL .. "1_selection_pilot"), 0, "the failed panel's left VOR/ADF switch: nothing")
rt:set(SEL .. "2_selection_copilot", 1)
rt:command("sim/instruments/EFIS_2_copilot_sel_up")
rt:command("sim/instruments/EFIS_2_copilot_sel_up")
T.equal(rt:get(SEL .. "2_selection_copilot"), 2, "the F/O's right switch up: VOR, not beyond")
for _ = 1, 3 do rt:command("sim/instruments/EFIS_2_copilot_sel_dn") end
T.equal(rt:get(SEL .. "2_selection_copilot"), 0, "down: ADF, not beyond")
rt:set(EF .. "fail", 0, 0)
rt:command(EF .. "fpv/capt/switch")
T.equal(rt:get(EF .. "fpv/capt/selected"), 1 - fpv, "the panel back: its FPV switch works")
rt:command("sim/instruments/EFIS_1_pilot_sel_up")
T.equal(rt:get(SEL .. "1_selection_pilot"), 1, "and its left VOR/ADF switch: OFF")
rt:set(SEL .. "1_selection_pilot", 1)
rt:set(SEL .. "2_selection_copilot", 1)

-- step 5c: the POS switch's symbols (FCOM p.1040, p.1145, p.1150): the
-- Captain's MAP 40 NM, VOR L's bearing 30 right of heading 100 at 20 NM DME
rt:set(ND .. "mode/capt/sel_dial_pos", 2)
rt:set(ND .. "range/capt/sel_dial_pos", 2)
rt:set(ND .. "map_center/capt", 0)
rt:set(ND .. "data/capt/pos", 1)
for i = 0, 2 do rt:set(IRS .. "nav_valid", i, 1) end
rt:set("laminar/B747/gps/valid", 0, 1)
rt:set(RAD .. "indicators/nav_display_horizontal", 2, 1)
rt:set(RAD .. "indicators/nav_relative_bearing_deg", 2, 30)
rt:set(RAD .. "indicators/nav_has_dme", 2, 1)
rt:set(RAD .. "indicators/nav_dme_distance_nm", 2, 20)
rt:set("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", 100)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 110)
frames(0.1)
local PC = ND .. "capt/"
T.check(rt:get(PC .. "pos_iru", 0) == 1 and rt:get(PC .. "pos_iru", 2) == 1, "POS: the IRU positions")
T.equal(rt:get(PC .. "pos_gps"), 1, "the GPS position (GPS L)")
T.equal(rt:get(PC .. "pos_rad_l"), 1, "VOR L's radial")
T.near(rt:get(PC .. "pos_rad_l_brg"), 20, 1e-4, "at 130 magnetic: 20 right of the track-up top")
T.near(rt:get(PC .. "pos_rad_l_len"), 232.5, 1e-4, "to the DME distance: 232.5 pixels")
T.near(rt:get(PC .. "pos_rad_l_end"), 232.5 - 24, 1e-4, "the last segment ending there")
T.equal(rt:get(PC .. "pos_rad_l_tick"), 1, "the tick mark")
T.check(rt:get(PC .. "pos_rad_l_tside") == 1 and math.abs(rt:get(PC .. "pos_rad_l_tbrg") - (-70)) < 1e-4,
    "the label along the line, to its right")
T.equal(rt:get(PC .. "pos_rad_l_text"), "R-310", "R-310")
rt:set(ND .. "data/capt/pos", 0)
frames(0.1)
T.check(rt:get(PC .. "pos_rad_l") == 0 and rt:get(PC .. "pos_gps") == 0, "POS off: none")

-- the 405 (PW: engines/type 0; RR as PW): heading up in all modes, HDG in
-- the box (FCOM p.1109, p.1141; nd/up is nd.lua's: nd_orientation_test);
-- the Captain's MAP 40 NM, heading 100, track 110, 250 kt
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/flightmodel2/position/groundspeed", 128.6)
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 0)
frames(0.1)
T.equal(rt:get("sim/cockpit2/EFIS/map_mode"), 0, "the 405's MAP: X-Plane's heading-up map")
T.equal(rt:get(PC .. "box"), 1, "HDG in the box")
T.check(rt:get(PC .. "tv_show", 0) == 1 and math.abs(rt:get(PC .. "tv_rot", 0) - 10) < 1e-6,
    "the trend vector along the track, 10 right of the heading up")
rt:set(ND .. "mode/capt/sel_dial_pos", 3)
frames(0.1)
T.equal(rt:get(PC .. "box"), 3, "the 405's PLN: HDG in PLAN's box")
rt:set(ND .. "mode/capt/sel_dial_pos", 2)

T.done()
