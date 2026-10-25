-- The radio altimeter model (B747.34.ra_model.lua) in the aircraft: reads
-- X-Plane's two radio altimeters (L = the pilot's, R = the copilot's, C =
-- the pilot's, or the copilot's when the pilot's has failed: estimate, X-Plane
-- has two), the buses (L: AC bus 3, C: AC bus 1, R: AC bus 2), X-Plane's
-- radio altimeter failures and laminar/B747/ra/fail[3], the EIU selectors;
-- writes what each PFD shows (laminar/B747/efis/radio_altitude for the
-- Captain, as before, and radio_altitude_fo; ra/capt|fo/show, flag, value)
-- and the GPWC's radio altitude (B747_ra_gpwc() for B747.34.xt.gpws.lua).
-- B747.34.xt.nav.lua loads it.

dofile("B747.34.ra_model.lua")
local RA = B747_ra_model

simDR_ra_pilot                  = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
simDR_ra_copilot                = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_copilot")
simDR_ra_fail_pilot             = find_dataref("sim/operation/failures/rel_pil_radalt")
simDR_ra_fail_copilot           = find_dataref("sim/operation/failures/rel_cop_radalt")
simDR_ra_time                   = find_dataref("sim/time/total_running_time_sec")
B747DR_ra_bus_ac                = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_ra_eiu_capt              = find_dataref("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos")
B747DR_ra_eiu_fo                = find_dataref("laminar/B747/flt_inst/eiu_src/fo/sel_dial_pos")
B747DR_ra_fail                  = find_dataref("laminar/B747/ra/fail")
B747DR_ra_valid                 = find_dataref("laminar/B747/ra/valid")
B747DR_ra_efis_capt             = find_dataref("laminar/B747/efis/radio_altitude")
B747DR_ra_efis_fo               = find_dataref("laminar/B747/efis/radio_altitude_fo")
B747DR_ra_capt_show             = find_dataref("laminar/B747/ra/capt/show")
B747DR_ra_capt_flag             = find_dataref("laminar/B747/ra/capt/flag")
B747DR_ra_capt_value            = find_dataref("laminar/B747/ra/capt/value")
B747DR_ra_fo_show               = find_dataref("laminar/B747/ra/fo/show")
B747DR_ra_fo_flag               = find_dataref("laminar/B747/ra/fo/flag")
B747DR_ra_fo_value              = find_dataref("laminar/B747/ra/fo/value")
B747DR_ra_gpwc                  = find_dataref("laminar/B747/ra/gpwc")
B747DR_ra_gpwc_valid            = find_dataref("laminar/B747/ra/gpwc_valid")
B747DR_ra_CAS_advisory          = find_dataref("laminar/B747/CAS/advisory_status")
local ADV_SNGL_SOURCE_RA = 266                  -- >SNGL SOURCE RA

-- X-Plane's radio altimeters read about 8 ft with the wheels on the ground;
-- the PFD has shown them less 8 ft (estimate: kept as the calibration)
local XP_OFFSET_FT = 8
local XP_FAILED = 6
-- the EIU selectors' positions: Captain L, AUTO, C, R; F/O L, C, AUTO, R
-- (estimate from their default positions, AUTO on both: fltInst02)
local EIU_CAPT = {[0] = "L", "AUTO", "C", "R"}
local EIU_FO = {[0] = "L", "C", "AUTO", "R"}
local INIT_S = 3                                -- the first reads are 0

local ra_state = RA.new()
local ra_inputs = RA.inputs()
local ra_t0 = nil
-- the GPWC's radio altitude (ft) and its validity, for the GPWS glue (a
-- function: XTLua turns a global table into a namespace)
function B747_ra_gpwc()
    local g = ra_state.out.gpwc
    return g.value, g.valid
end
-- the TCAS's radio altitude: the L radio altimeter, else the R (ATA34_2
-- p.17: it takes both; one is enough); value (ft), working, no computed data
function B747_ra_tcas()
    local o = ra_state.out
    local i = RA.L
    if not o.valid[i] then i = RA.R end
    return o.value[i], o.valid[i], o.ncd[i]
end

-- the PFD's increments: 2 ft below 100 ft, 10 ft below 500 ft, 20 ft above
-- (ATA34_2 p.95, FCOM p.981)
local function digits(v)
    local inc = 20
    if v < 100 then inc = 2 elseif v < 500 then inc = 10 end
    return math.floor(v / inc + 0.5) * inc
end

local function knob(v, names)
    return names[math.floor(v + 0.5)] or "AUTO"
end

function B747_ra()
    local now = simDR_ra_time
    if ra_t0 == nil then ra_t0 = now end
    if now - ra_t0 < INIT_S then return end

    local inp = ra_inputs
    local pilot_failed = simDR_ra_fail_pilot == XP_FAILED
    local copilot_failed = simDR_ra_fail_copilot == XP_FAILED
    local pilot = simDR_ra_pilot - XP_OFFSET_FT
    local copilot = simDR_ra_copilot - XP_OFFSET_FT
    inp.height[1] = pilot
    inp.height[3] = copilot
    if pilot_failed and not copilot_failed then inp.height[2] = copilot else inp.height[2] = pilot end
    inp.power[1] = B747DR_ra_bus_ac[2] > 0.5
    inp.power[2] = B747DR_ra_bus_ac[0] > 0.5
    inp.power[3] = B747DR_ra_bus_ac[1] > 0.5
    inp.fail[1] = pilot_failed or B747DR_ra_fail[0] > 0.5
    inp.fail[2] = B747DR_ra_fail[1] > 0.5
    inp.fail[3] = copilot_failed or B747DR_ra_fail[2] > 0.5
    inp.eiu_capt = knob(B747DR_ra_eiu_capt, EIU_CAPT)
    inp.eiu_fo = knob(B747DR_ra_eiu_fo, EIU_FO)
    local out = RA.update(ra_state, inp)

    for i = 1, 3 do B747_nav_put(B747DR_ra_valid, i - 1, B747_nav_flag(out.valid[i])) end
    -- the PFDs; with no radio altimeter working the digits keep their last value
    local c, f = out.capt, out.fo
    if c.valid then
        local d = digits(c.value)
        if B747DR_ra_efis_capt ~= d then B747DR_ra_efis_capt = d end
        if B747DR_ra_capt_value ~= c.value then B747DR_ra_capt_value = c.value end
    end
    if f.valid then
        local d = digits(f.value)
        if B747DR_ra_efis_fo ~= d then B747DR_ra_efis_fo = d end
        if B747DR_ra_fo_value ~= f.value then B747DR_ra_fo_value = f.value end
    end
    local v = B747_nav_flag(c.show)
    if B747DR_ra_capt_show ~= v then B747DR_ra_capt_show = v end
    v = B747_nav_flag(c.flag)
    if B747DR_ra_capt_flag ~= v then B747DR_ra_capt_flag = v end
    v = B747_nav_flag(f.show)
    if B747DR_ra_fo_show ~= v then B747DR_ra_fo_show = v end
    v = B747_nav_flag(f.flag)
    if B747DR_ra_fo_flag ~= v then B747DR_ra_fo_flag = v end
    local g = out.gpwc
    if g.valid and B747DR_ra_gpwc ~= g.value then B747DR_ra_gpwc = g.value end
    v = B747_nav_flag(g.valid)
    if B747DR_ra_gpwc_valid ~= v then B747DR_ra_gpwc_valid = v end
    -- >SNGL SOURCE RA: both PFDs on one radio altimeter (FCOM p.1197)
    B747_nav_put(B747DR_ra_CAS_advisory, ADV_SNGL_SOURCE_RA, B747_nav_flag(c.src ~= nil and c.src == f.src))
end

function B747_ra_flight_start()
    ra_state = RA.new()
    ra_t0 = nil
end
