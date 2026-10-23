-- The pack model (B747.55.pack_model.lua) in the aircraft: reads the PACK
-- selectors, the duct pressures, HI FLOW, TRIM AIR, the RECIRC switches,
-- PACK RST, cargo fire ARM, the air/ground relays, the buses and the
-- pressurization model's relief valves and cruise clamp; writes the pack
-- valves, flows and controllers, the recirculation fans, the number of
-- packs operating (the EEC reads it), the PACK RST SYS FAULT light, PACK
-- 1-3, PACK CONTROL, the pack memos and PACKS HIGH FLOW. B747.55.xt.air.lua
-- loads it after the bleed glue; the bleed model takes the packs' flow
-- (B747_pack_out.flow) and the pressurization model their air.
dofile("B747.55.pack_model.lua")
local P = B747_pack_model

B747DR_pack_valve_pos           = find_dataref("laminar/B747/air/pack/valve_pos")
B747DR_pack_high_flow           = find_dataref("laminar/B747/air/pack/high_flow")
B747DR_pack_ptc                 = find_dataref("laminar/B747/air/pack/ptc")
B747DR_packs_operating          = find_dataref("laminar/B747/air/packs_operating")
B747DR_recirc_fan               = find_dataref("laminar/B747/air/recirc_fan")
B747DR_pack_light_sys_fault     = find_dataref("laminar/B747/air/light/pack_sys_fault")
B747DR_pack_pseu_pri_gnd        = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_pack_elec_any_ac         = find_dataref("laminar/B747/electrical/bus/any_ac")

local SW_TRIM_AIR, SW_RECIRC_UPR, SW_RECIRC_LWR, SW_HI_FLOW, SW_PACK_RST = 37, 38, 39, 41, 42
local SW_CARGO_ARM_FWD, SW_CARGO_ARM_AFT = 84, 85
-- EICAS slots (B747.87.xt.warning.lua)
local ADV_PACK_CONTROL, ADV_PACK = 251, 252          -- PACK 1-3: 252-254
local MEMO_PACK_OFF, MEMO_PACKS_12, MEMO_PACKS_13, MEMO_PACKS_23 = 18, 21, 22, 23
local MEMO_HIGH_FLOW, MEMO_PACKS_OFF = 24, 25

local pack_state = P.new()
local pack_inputs = P.inputs()
local rst_last = false
-- for the bleed and pressurization glue: with a metatable, XTLua's
-- namespace keeps the table itself (it copies a bare table, whose numbers
-- and flags would then not follow the model)
B747_pack_out = setmetatable(pack_state.out, {})
B747_pack_relief_open = false           -- the pressurization glue's last frame
B747_pack_cruise_clamp = false

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_packs_flight_start()
    pack_state = P.new()
    B747_pack_out = setmetatable(pack_state.out, {})
    rst_last = false
end

function B747_packs()
    local inp = pack_inputs
    for p = 1, 3 do inp.selector[p] = math.floor(B747DR_pack_ctrl_sel_pos[p - 1] + 0.5) end
    inp.duct_psi[1], inp.duct_psi[2], inp.duct_psi[3] = B747_duct_pressure_L, B747_duct_pressure_C, B747_duct_pressure_R
    inp.hi_flow = B747DR_button_switch_position[SW_HI_FLOW] > 0.5
    inp.trim_air = B747DR_button_switch_position[SW_TRIM_AIR] > 0.5
    inp.recirc_upr = B747DR_button_switch_position[SW_RECIRC_UPR] > 0.5
    inp.recirc_lwr = B747DR_button_switch_position[SW_RECIRC_LWR] > 0.5
    local rst = B747DR_button_switch_position[SW_PACK_RST] > 0.5    -- momentary: the push
    inp.pack_rst = rst and not rst_last
    rst_last = rst
    inp.cargo_fire_arm = B747DR_button_switch_position[SW_CARGO_ARM_FWD] > 0.5
        or B747DR_button_switch_position[SW_CARGO_ARM_AFT] > 0.5
    inp.relief_open = B747_pack_relief_open
    inp.cruise_clamp = B747_pack_cruise_clamp
    inp.on_ground = B747DR_pack_pseu_pri_gnd == 1
    for i = 1, 4 do
        inp.dc[i] = B747DR_bleed_elec_dc[i - 1] > 0.5
        inp.ac[i] = B747DR_bleed_elec_ac[i - 1] > 0.5
    end
    inp.any_ac = B747DR_pack_elec_any_ac > 0.5
    local out = P.update(pack_state, inp, SIM_PERIOD)

    for p = 1, 3 do
        local i = p - 1
        put(B747DR_pack_valve_pos, i, out.valve[p])
        put(B747DR_pack_high_flow, i, flag(out.high[p]))
        put(B747DR_pack_ptc, i, out.ptc[p])
        put(B747DR_CAS_advisory_status, ADV_PACK + i, flag(out.pack_alert[p]))
    end
    for f = 1, 4 do put(B747DR_recirc_fan, f - 1, flag(out.fan[f])) end
    local n, fault = out.packs_operating, flag(out.sys_fault)
    if B747DR_packs_operating ~= n then B747DR_packs_operating = n end
    if B747DR_pack_light_sys_fault ~= fault then B747DR_pack_light_sys_fault = fault end
    put(B747DR_CAS_advisory_status, ADV_PACK_CONTROL, flag(out.control_alert))

    -- memos: the selectors OFF, in the largest group that fits (FCOM p.622)
    local off = {inp.selector[1] == 0, inp.selector[2] == 0, inp.selector[3] == 0}
    local all = off[1] and off[2] and off[3]
    local p12 = not all and off[1] and off[2]
    local p13 = not all and off[1] and off[3]
    local p23 = not all and off[2] and off[3]
    put(B747DR_CAS_memo_status, MEMO_PACKS_OFF, flag(all))
    put(B747DR_CAS_memo_status, MEMO_PACKS_12, flag(p12))
    put(B747DR_CAS_memo_status, MEMO_PACKS_13, flag(p13))
    put(B747DR_CAS_memo_status, MEMO_PACKS_23, flag(p23))
    local pair = all or p12 or p13 or p23
    for p = 1, 3 do put(B747DR_CAS_memo_status, MEMO_PACK_OFF + p - 1, flag(off[p] and not pair)) end
    put(B747DR_CAS_memo_status, MEMO_HIGH_FLOW, flag(inp.hi_flow))    -- the HI FLOW switch (FCOM p.622)
end
