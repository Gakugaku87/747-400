-- The PFD speed tape models in the aircraft (notes/ATA-31.md §13, §14):
-- - B747.60.speedtape_model.lua (5-2 step 3a): reads VREF30 (fltInst02's
--   table), the weight, the altitude, the flap lever, the landing flaps
--   selected on the CDU and the PSEU's air mode; writes the flap maneuver
--   speeds (Vf0 to Vf30: Vf25 is VREF25, which the CDU's APPROACH REF page
--   shows too), which bugs show (airspeed/show_vf[7]; showVf25 and showVf30
--   kept), and when the minimum maneuvering speed band shows
--   (pfd/show_mins);
-- - B747.60.minspeed_model.lua (step 3b): reads the pressure altitude, the
--   captain's Mach and airspeed, the load factor, the trailing edge flaps,
--   the maximum speed and the radio altitude too; writes the minimum speed
--   (airspeed/Vs: the top of the red and black band, the stick shaker or low
--   speed buffet speed), the minimum maneuvering speed (new airspeed/Vminm),
--   the maximum maneuvering speed (airspeed/Vmaxm: the maximum speed when
--   not shown), the stick shaker (X-Plane's stall warning), AIRSPEED LOW and
--   the amber box (airspeed_window/min), and for the panel's band pointers
--   the four bands minus each PFD's airspeed (new airspeed/tape_capt[4] and
--   tape_fo[4]: the band groups no longer move with the airspeed).
--   Step 4c: with the angle of attack, the pitch limit indication (new
--   pfd/pli: degrees above the airplane symbol, pfd/pli_show).
-- Step 4c also: VR's "R" within 4 kt of V1 (new airspeed/vr_r).
-- dofile'd from B747.60.xt.fltInst.lua after fltInst02.

dofile("B747.60.speedtape_model.lua")
dofile("B747.60.minspeed_model.lua")
local SP = B747_speedtape_model
local MS = B747_minspeed_model

simDR_spd_air                   = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_spd_show_vf              = find_dataref("laminar/B747/airspeed/show_vf")
simDR_spd_press_alt             = find_dataref("sim/flightmodel2/position/pressure_altitude")
B747DR_spd_mach                 = find_dataref("laminar/B747/airdata/mach_capt")
B747DR_spd_mach_fo              = find_dataref("laminar/B747/airdata/mach_fo")
B747DR_spd_valid_capt           = find_dataref("laminar/B747/airdata/valid_capt")
B747DR_spd_valid_fo             = find_dataref("laminar/B747/airdata/valid_fo")
B747DR_spd_ias_fo               = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_copilot")
simDR_spd_nz                    = find_dataref("sim/flightmodel/forces/g_nrml")
B747DR_airspeed_Vminm           = find_dataref("laminar/B747/airspeed/Vminm")
B747DR_spd_tape_capt            = find_dataref("laminar/B747/airspeed/tape_capt")
B747DR_spd_tape_fo              = find_dataref("laminar/B747/airspeed/tape_fo")
-- step 4c: the PLI and VR's "R"
simDR_spd_alpha                 = find_dataref("sim/flightmodel/position/alpha")
B747DR_spd_pli                  = find_dataref("laminar/B747/pfd/pli")
B747DR_spd_pli_show             = find_dataref("laminar/B747/pfd/pli_show")
B747DR_spd_vr_r                 = find_dataref("laminar/B747/airspeed/vr_r")
-- VR shows "R" within 4 kt of V1 (FCOM p.972)
local VR_R_KT = 4

local spd_state = SP.new()
local spd_inputs = SP.inputs()
local ms_state = MS.new()
local ms_inputs = MS.inputs()

local function flag(v) return v and 1 or 0 end
local function put(i, v)
    if B747DR_spd_show_vf[i] ~= v then B747DR_spd_show_vf[i] = v end
end
local function tape_put(ref, ias, b0, b1, b2, b3)
    local v = b0 - ias
    if ref[0] ~= v then ref[0] = v end
    v = b1 - ias
    if ref[1] ~= v then ref[1] = v end
    v = b2 - ias
    if ref[2] ~= v then ref[2] = v end
    v = b3 - ias
    if ref[3] ~= v then ref[3] = v end
end

function B747_speedtape()
    local inp = spd_inputs
    inp.vref30 = B747DR_airspeed_Vref30
    inp.weight_kg = simDR_acf_weight_total_kg
    inp.alt_ft = simDR_altitude_ft_pilot
    inp.flap_ratio = simDR_flap_ratio_control
    inp.land_flap = math.floor(B747DR_airspeed_VrefFlap + 0.5)
    inp.air = simDR_spd_air > 0.5
    inp.ias = simDR_airspeed
    local out = SP.update(spd_state, inp, SIM_PERIOD)

    local vf = out.vf
    if B747DR_airspeed_Vf0 ~= vf[0] then B747DR_airspeed_Vf0 = vf[0] end
    if B747DR_airspeed_Vf1 ~= vf[1] then B747DR_airspeed_Vf1 = vf[1] end
    if B747DR_airspeed_Vf5 ~= vf[2] then B747DR_airspeed_Vf5 = vf[2] end
    if B747DR_airspeed_Vf10 ~= vf[3] then B747DR_airspeed_Vf10 = vf[3] end
    if B747DR_airspeed_Vf20 ~= vf[4] then B747DR_airspeed_Vf20 = vf[4] end
    if B747DR_airspeed_Vf25 ~= vf[5] then B747DR_airspeed_Vf25 = vf[5] end
    if B747DR_airspeed_Vf30 ~= vf[6] then B747DR_airspeed_Vf30 = vf[6] end
    for k = 0, 6 do put(k, flag(out.show_vf[k])) end
    local v = flag(out.show_vf[SP.F25])
    if B747DR_airspeed_showVf25 ~= v then B747DR_airspeed_showVf25 = v end
    v = flag(out.show_vf[SP.F30])
    if B747DR_airspeed_showVf30 ~= v then B747DR_airspeed_showVf30 = v end
    v = flag(out.show_mins)
    if B747DR_pfd_mode_show_mins ~= v then B747DR_pfd_mode_show_mins = v end

    -- the minimum speeds, the stick shaker and AIRSPEED LOW (step 3b)
    local mi = ms_inputs
    mi.weight_kg = simDR_acf_weight_total_kg
    mi.alt_ft = simDR_spd_press_alt
    -- the captain's air data, the first officer's when it is not valid;
    -- neither: no stick shaker and no AIRSPEED LOW (estimate)
    local capt = B747DR_spd_valid_capt > 0.5
    mi.air_data = capt or B747DR_spd_valid_fo > 0.5
    mi.mach = capt and B747DR_spd_mach or B747DR_spd_mach_fo
    mi.cas = capt and simDR_airspeed or B747DR_spd_ias_fo
    mi.nz = simDR_spd_nz
    mi.flap_deg = simDR_wing_flap1_deg[0]
    mi.vref30 = B747DR_airspeed_Vref30
    mi.vmax = B747DR_airspeed_Vmax
    mi.ra_ft = simDR_radio_alt_height_capt
    mi.air = inp.air
    mi.show_mins = out.show_mins
    mi.alpha_deg = simDR_spd_alpha
    local ms = MS.update(ms_state, mi, SIM_PERIOD)
    if B747DR_airspeed_Vs ~= ms.vss then B747DR_airspeed_Vs = ms.vss end
    if B747DR_airspeed_Vminm ~= ms.vmin_man then B747DR_airspeed_Vminm = ms.vmin_man end
    if B747DR_airspeed_Vmaxm ~= ms.vmax_man then B747DR_airspeed_Vmaxm = ms.vmax_man end
    -- the bands minus each PFD's airspeed, for the panel's band pointers
    tape_put(B747DR_spd_tape_capt, simDR_airspeed, ms.vss, ms.vmin_man, ms.vmax_man, B747DR_airspeed_Vmax)
    tape_put(B747DR_spd_tape_fo, B747DR_spd_ias_fo, ms.vss, ms.vmin_man, ms.vmax_man, B747DR_airspeed_Vmax)
    v = flag(ms.shaker)
    if simDR_stall_warning ~= v then simDR_stall_warning = v end
    v = flag(ms.airspeed_low)
    if B747DR_CAS_caution_status[0] ~= v then B747DR_CAS_caution_status[0] = v end
    if B747DR_airspeed_window_min ~= v then B747DR_airspeed_window_min = v end
    -- the PLI (step 4c): degrees above the airplane symbol, both PFDs
    if B747DR_spd_pli ~= ms.pli_deg then B747DR_spd_pli = ms.pli_deg end
    v = flag(ms.show_pli)
    if B747DR_spd_pli_show ~= v then B747DR_spd_pli_show = v end
    -- VR's "R" (step 4c): both selected (999 not), within 4 kt
    local v1, vr = B747DR_airspeed_V1, B747DR_airspeed_Vr
    v = flag(v1 < 900 and vr < 900 and math.abs(vr - v1) <= VR_R_KT)
    if B747DR_spd_vr_r ~= v then B747DR_spd_vr_r = v end
end

function B747_speedtape_flight_start()
    spd_state = SP.new()
    ms_state = MS.new()
end
