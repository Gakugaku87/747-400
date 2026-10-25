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

-- the ILS (step 4e): the Captain's ILS L through the pilot's HSI (NAV1),
-- the F/O's ILS R (NAV2); tuned by the stock autopilot/ils_dots
local HSI = "sim/cockpit2/radios/indicators/hsi_"
rt:set(BUS .. "ac", 1, 1)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 0, "no ILS tuned: no approach reference")
T.equal(rt:get(P .. "capt/loc_scale"), 0, "no localizer scale")
rt:set("laminar/B747/autopilot/ils_dots", 1)
rt:set(HSI .. "display_horizontal_pilot", 1)
rt:set(HSI .. "display_vertical_pilot", 1)
rt:set(HSI .. "hdef_dots_pilot", 1.5)
rt:set(HSI .. "vdef_dots_pilot", -2.5)
frames(0.1)
T.equal(rt:get(P .. "capt/ils_show"), 1, "tuned: the Captain's approach reference and course")
T.equal(rt:get(P .. "capt/loc_scale"), 1, "the localizer scale")
T.equal(rt:get(P .. "capt/loc_ptr"), 1, "localizer 1.5 dots: filled")
T.equal(rt:get(P .. "capt/gs_ptr"), 2, "glideslope -2.5 dots: hollow")
T.equal(rt:get(P .. "fo/ils_show"), 1, "the F/O's ILS R tuned too")
T.equal(rt:get(P .. "fo/loc_ptr"), 0, "no signal on the copilot's HSI: no pointer")
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
rt:set(HSI .. "vdef_dots_pilot", 0.7)
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

-- the ND (step 5a): each ND from its own side and mode
local NDP = "laminar/B747/nd/"
rt:set(IRS .. "hdg_valid", 0, 1)                                   -- IRU L's heading back
rt:set(NDP .. "mode/capt/sel_dial_pos", 2)                         -- MAP
rt:set(NDP .. "mode/fo/sel_dial_pos", 1)                           -- VOR
rt:set("sim/cockpit2/EFIS/map_mode_copilot", 2)                   -- the stock's VOR (X-Plane's MAP)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 250)
rt:set("sim/cockpit2/gauges/indicators/wind_heading_deg_mag", 350)
frames(0.1)
T.equal(rt:get("sim/cockpit2/EFIS/map_mode"), 2, "the Captain's MAP: X-Plane's map mode 2 (track up)")
T.equal(rt:get("sim/cockpit2/EFIS/map_mode_copilot"), 0, "the F/O's VOR: X-Plane's heading-up mode 0")
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
T.equal(rt:get(NDP .. "capt/hdg_ptr_pln"), 1, "PLN's heading pointer")
T.equal(rt:get(NDP .. "capt/hdg_bug"), 0, "no selected heading in PLN")

T.done()
