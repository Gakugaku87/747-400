-- The PFD speed tape model (B747.60.speedtape_model.lua, 5-2 step 3a;
-- notes/ATA-31.md §13) in the aircraft: reads VREF30 (fltInst02's table),
-- the weight, the altitude, the flap lever, the landing flaps selected on the
-- CDU and the PSEU's air mode; writes the flap maneuver speeds (Vf0 to Vf30:
-- Vf25 is VREF25, which the CDU's APPROACH REF page shows too), which bugs
-- show (new airspeed/show_vf[7]; showVf25 and showVf30 kept), and when the
-- minimum maneuvering speed band shows (pfd/show_mins). dofile'd from
-- B747.60.xt.fltInst.lua after fltInst02.

dofile("B747.60.speedtape_model.lua")
local SP = B747_speedtape_model

simDR_spd_air                   = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_spd_show_vf              = find_dataref("laminar/B747/airspeed/show_vf")

local spd_state = SP.new()
local spd_inputs = SP.inputs()

local function flag(v) return v and 1 or 0 end
local function put(i, v)
    if B747DR_spd_show_vf[i] ~= v then B747DR_spd_show_vf[i] = v end
end

function B747_speedtape()
    local inp = spd_inputs
    inp.vref30 = B747DR_airspeed_Vref30
    inp.weight_kg = simDR_acf_weight_total_kg
    inp.alt_ft = simDR_altitude_ft_pilot
    inp.flap_ratio = simDR_flap_ratio_control
    inp.land_flap = math.floor(B747DR_airspeed_VrefFlap + 0.5)
    inp.air = simDR_spd_air > 0.5
    local out = SP.update(spd_state, inp)

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
end

function B747_speedtape_flight_start()
    spd_state = SP.new()
end
