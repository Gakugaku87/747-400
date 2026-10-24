-- The IRS model (B747.34.irs_model.lua) in the aircraft: reads the IRU mode
-- selectors, the buses (each IRU's AC: L AC 3, C AC 1, R AC 2; the APU hot
-- battery bus; DC bus 3; the ground service bus), the PSEU, X-Plane's
-- position, ground speed and magnetic heading, its long-range navigation
-- failures (L rel_lrn1, R rel_lrn2) and laminar/B747/irs/fail/iru[3], the
-- FMC's position and SET HDG entries (laminar/B747/irs/pos_entry_*,
-- set_hdg_*), the IRS source selectors and the simconfig's alignment time;
-- writes each IRU's mode (laminar/B747/flt_mgmt/iru/status: 0 off,
-- 1 aligned and waiting at ALIGN, 2 NAV, 3 ATT, 4 aligning, 5 failed) and
-- laminar/B747/irs/... (time to align, validity, position, ground speed,
-- heading, the FMC's prompts, ON BAT), each PFD's attitude and heading
-- validity from its selected IRU (laminar/B747/pfd/capt/irs, fo/irs), the
-- EICAS messages and ENTER IRS POSITION, CYCLE IRS OFF-NAV.
-- B747.34.xt.nav.lua loads it.

dofile("B747.34.irs_model.lua")
local IR = B747_irs_model


--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_irs_lat                   = find_dataref("sim/flightmodel/position/latitude")
simDR_irs_lon                   = find_dataref("sim/flightmodel/position/longitude")
simDR_irs_gs                    = find_dataref("sim/flightmodel/position/groundspeed")
simDR_irs_mag_psi               = find_dataref("sim/flightmodel/position/mag_psi")
simDR_irs_fail_lrn1             = find_dataref("sim/operation/failures/rel_lrn1")
simDR_irs_fail_lrn2             = find_dataref("sim/operation/failures/rel_lrn2")
simDR_irs_time                  = find_dataref("sim/time/total_running_time_sec")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_irs_msu                  = find_dataref("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos")
B747DR_irs_status               = find_dataref("laminar/B747/flt_mgmt/iru/status")
B747DR_irs_src_capt             = find_dataref("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos")
B747DR_irs_src_fo               = find_dataref("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos")
B747DR_irs_bus_ac               = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_irs_bus_dc               = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_irs_bus_hot_bat          = find_dataref("laminar/B747/electrical/bus/hot_bat_apu")
B747DR_irs_bus_gnd_svc          = find_dataref("laminar/B747/electrical/bus/gnd_svc")
B747DR_irs_pri_gnd              = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_irs_simconfig            = find_dataref("laminar/B747/simconfig")
B747DR_irs_newsimconfig         = find_dataref("laminar/B747/newsimconfig")
B747DR_irs_pos_seq              = find_dataref("laminar/B747/irs/pos_entry_seq")
B747DR_irs_pos_lat              = find_dataref("laminar/B747/irs/pos_entry_lat")
B747DR_irs_pos_lon              = find_dataref("laminar/B747/irs/pos_entry_lon")
B747DR_irs_hdg_seq              = find_dataref("laminar/B747/irs/set_hdg_seq")
B747DR_irs_hdg_entry            = find_dataref("laminar/B747/irs/set_hdg")
B747DR_irs_fail                 = find_dataref("laminar/B747/irs/fail/iru")
B747DR_irs_mode                 = find_dataref("laminar/B747/irs/mode")
B747DR_irs_time_left            = find_dataref("laminar/B747/irs/time_left")
B747DR_irs_att_valid            = find_dataref("laminar/B747/irs/att_valid")
B747DR_irs_hdg_valid            = find_dataref("laminar/B747/irs/hdg_valid")
B747DR_irs_nav_valid            = find_dataref("laminar/B747/irs/nav_valid")
B747DR_irs_out_lat              = find_dataref("laminar/B747/irs/lat")
B747DR_irs_out_lon              = find_dataref("laminar/B747/irs/lon")
B747DR_irs_out_gs               = find_dataref("laminar/B747/irs/gs")
B747DR_irs_out_hdg              = find_dataref("laminar/B747/irs/hdg")
B747DR_irs_motion               = find_dataref("laminar/B747/irs/motion")
B747DR_irs_set_pos              = find_dataref("laminar/B747/irs/set_pos")
B747DR_irs_aligning             = find_dataref("laminar/B747/irs/aligning")
B747DR_irs_set_hdg_shown        = find_dataref("laminar/B747/irs/set_hdg_shown")
B747DR_irs_on_bat               = find_dataref("laminar/B747/irs/on_bat")
B747DR_irs_pfd_capt             = find_dataref("laminar/B747/pfd/capt/irs")
B747DR_irs_pfd_fo               = find_dataref("laminar/B747/pfd/fo/irs")
B747DR_irs_fmc_notify           = find_dataref("laminar/B747/fms/notification")
B747DR_irs_CAS_memo             = find_dataref("laminar/B747/CAS/memo_status")
B747DR_irs_CAS_advisory         = find_dataref("laminar/B747/CAS/advisory_status")

-- EICAS slots (B747.87.xt.warning.lua), in the order L, C, R
local MEMO_ALIGN = {14, 15, 16}                 -- IRS ALIGN MODE L, C, R
local ADV_AC = {226, 225, 227}                  -- >IRS AC LEFT, CENTER, RIGHT
local ADV_DC = {230, 229, 231}                  -- >IRS DC LEFT, CENTER, RIGHT
local ADV_FAIL = {232, 228, 234}                -- IRS LEFT, CENTER, RIGHT
local ADV_MOTION = 233                          -- IRS MOTION
local ADV_SOURCE_SEL_IRS = 270                  -- >SOURCE SEL IRS
-- the FMC's messages (laminar/B747/fms/notification: B744.notifications.lua + 1)
local FMC_CYCLE_IRS, FMC_ENTER_IRS_POS = 5, 12
local AC_BUS = {2, 0, 1}                        -- L: AC 3, C: AC 1, R: AC 2 (ATA34_2 p.272-275)
local MOVING_MPS = 0.5                          -- excessive motion for an alignment: about 1 kt (estimate)
local OFFSET_DEG = 0.001                        -- each IRU's position error, at most (as before)
local INIT_S = 3                                -- the first reads are 0

local irs_state = IR.new()
local irs_inputs = IR.inputs()
local irs_t0 = nil
local irs_started = false
local irs_offset = {{0, 0}, {0, 0}, {0, 0}}
local irs_was_nav = {false, false, false}

-- the simconfig's alignment time (SIM.irs_align_time, seconds)
local function align_time()
    local s = B747DR_irs_simconfig
    if type(s) == "string" then
        local v = tonumber(s:match('"irs_align_time"%s*:%s*([%d.]+)'))
        if v and v > 0 then return v end
    end
    return IR.ALIGN_S
end

-- a quick start (laminar/B747/irs/align_now): every IRU at NAV aligned, on
-- the next frame (the selectors may be turned in the same one)
local irs_align_pending = false
function B747_irs_align_now_CMDhandler(phase, duration)
    if phase == 0 then irs_align_pending = true end
end
B747CMD_irs_align_now           = deferred_command("laminar/B747/irs/align_now", "IRS: IRUs at NAV aligned at once (quick start)", B747_irs_align_now_CMDhandler)


--*************************************************************************************--
--** 				                 MAIN PROGRAM                 			    	 **--
--*************************************************************************************--

function B747_irs()
    local now = simDR_irs_time
    if irs_t0 == nil then irs_t0 = now end
    if now - irs_t0 < INIT_S then return end

    local inp = irs_inputs
    for i = 1, 3 do
        inp.msu[i] = math.floor(B747DR_irs_msu[i - 1] + 0.5)
        inp.ac[i] = B747DR_irs_bus_ac[AC_BUS[i]] > 0.5
    end
    inp.hot_bat = B747DR_irs_bus_hot_bat > 0.5
    inp.dc3 = B747DR_irs_bus_dc[2] > 0.5
    inp.gsb = B747DR_irs_bus_gnd_svc > 0.5
    inp.ground = B747DR_irs_pri_gnd == 1
    inp.moving = simDR_irs_gs > MOVING_MPS
    inp.lat, inp.lon = simDR_irs_lat, simDR_irs_lon
    inp.fail[1] = simDR_irs_fail_lrn1 == 6 or B747DR_irs_fail[0] > 0.5
    inp.fail[2] = B747DR_irs_fail[1] > 0.5
    inp.fail[3] = simDR_irs_fail_lrn2 == 6 or B747DR_irs_fail[2] > 0.5
    inp.pos_seq, inp.pos_lat, inp.pos_lon = B747DR_irs_pos_seq, B747DR_irs_pos_lat, B747DR_irs_pos_lon
    inp.hdg_seq, inp.hdg = B747DR_irs_hdg_seq, B747DR_irs_hdg_entry
    inp.mag_hdg = simDR_irs_mag_psi
    if not irs_started or B747DR_irs_newsimconfig == 1 then inp.align_s = align_time() end
    if not irs_started then
        -- the IRUs remember this place; a flight started with them at NAV
        -- (engines running, in the air) starts aligned
        irs_started = true
        IR.store(irs_state, inp.lat, inp.lon)
        IR.update(irs_state, inp, 0)
        irs_align_pending = true
    end
    if irs_align_pending then
        irs_align_pending = false
        IR.align_now(irs_state, inp)
    end
    local out = IR.update(irs_state, inp, SIM_PERIOD)

    local gs_kt = simDR_irs_gs * 1.943844
    for i = 1, 3 do
        local o = out.iru[i]
        local status = 0
        if o.mode == IR.M_ALIGN then status = o.aligned and 1 or 4
        elseif o.mode == IR.M_NAV then status = 2
        elseif o.mode == IR.M_ATT then status = 3
        elseif o.mode == IR.M_FAIL then status = 5 end
        B747_nav_put(B747DR_irs_status, i - 1, status)
        B747_nav_put(B747DR_irs_mode, i - 1, o.mode)
        B747_nav_put(B747DR_irs_time_left, i - 1, math.ceil(o.time_left))
        B747_nav_put(B747DR_irs_att_valid, i - 1, B747_nav_flag(o.att_valid))
        B747_nav_put(B747DR_irs_hdg_valid, i - 1, B747_nav_flag(o.hdg_valid))
        B747_nav_put(B747DR_irs_nav_valid, i - 1, B747_nav_flag(o.nav_valid))
        -- a new alignment: a new small position error (as before)
        if o.nav_valid and not irs_was_nav[i] then
            irs_offset[i][1] = (math.random() - 0.5) * 2 * OFFSET_DEG
            irs_offset[i][2] = (math.random() - 0.5) * 2 * OFFSET_DEG
        end
        irs_was_nav[i] = o.nav_valid
        if o.nav_valid then
            B747DR_irs_out_lat[i - 1] = inp.lat + irs_offset[i][1]
            B747DR_irs_out_lon[i - 1] = inp.lon + irs_offset[i][2]
            B747_nav_put(B747DR_irs_out_gs, i - 1, gs_kt)
        else
            B747_nav_put(B747DR_irs_out_lat, i - 1, 0)
            B747_nav_put(B747DR_irs_out_lon, i - 1, 0)
            B747_nav_put(B747DR_irs_out_gs, i - 1, 0)
        end
        B747_nav_put(B747DR_irs_out_hdg, i - 1, o.hdg_valid and o.hdg or 0)
        B747_nav_put(B747DR_irs_CAS_memo, MEMO_ALIGN[i], B747_nav_flag(o.align_memo))
        B747_nav_put(B747DR_irs_CAS_advisory, ADV_AC[i], B747_nav_flag(o.ac_fail))
        B747_nav_put(B747DR_irs_CAS_advisory, ADV_DC[i], B747_nav_flag(o.dc_fail))
        B747_nav_put(B747DR_irs_CAS_advisory, ADV_FAIL[i], B747_nav_flag(o.failed))
    end
    B747_nav_put(B747DR_irs_CAS_advisory, ADV_MOTION, B747_nav_flag(out.irs_motion))
    if B747DR_irs_motion ~= B747_nav_flag(out.irs_motion) then B747DR_irs_motion = B747_nav_flag(out.irs_motion) end
    if B747DR_irs_set_pos ~= B747_nav_flag(out.set_pos) then B747DR_irs_set_pos = B747_nav_flag(out.set_pos) end
    if B747DR_irs_aligning ~= B747_nav_flag(out.aligning) then B747DR_irs_aligning = B747_nav_flag(out.aligning) end
    if B747DR_irs_set_hdg_shown ~= B747_nav_flag(out.set_hdg) then B747DR_irs_set_hdg_shown = B747_nav_flag(out.set_hdg) end
    if B747DR_irs_on_bat ~= B747_nav_flag(out.on_bat) then B747DR_irs_on_bat = B747_nav_flag(out.on_bat) end
    B747_nav_put(B747DR_irs_fmc_notify, FMC_ENTER_IRS_POS, B747_nav_flag(out.enter_pos))
    B747_nav_put(B747DR_irs_fmc_notify, FMC_CYCLE_IRS, B747_nav_flag(out.cycle_irs))

    -- each PFD's attitude and heading from the IRU its IRS selector picks
    -- (0 L, 1 C, 2 R); >SOURCE SEL IRS with both on one IRU (FCOM p.1197)
    local sc = math.floor(B747DR_irs_src_capt + 0.5) + 1
    local sf = math.floor(B747DR_irs_src_fo + 0.5) + 1
    sc, sf = math.max(1, math.min(3, sc)), math.max(1, math.min(3, sf))
    local pc = B747_nav_flag(out.iru[sc].att_valid and out.iru[sc].hdg_valid)
    local pf = B747_nav_flag(out.iru[sf].att_valid and out.iru[sf].hdg_valid)
    if B747DR_irs_pfd_capt ~= pc then B747DR_irs_pfd_capt = pc end
    if B747DR_irs_pfd_fo ~= pf then B747DR_irs_pfd_fo = pf end
    B747_nav_put(B747DR_irs_CAS_advisory, ADV_SOURCE_SEL_IRS, B747_nav_flag(sc == sf))
end

function B747_irs_flight_start()
    irs_state = IR.new()
    irs_t0 = nil
    irs_started = false
    irs_align_pending = false
    irs_was_nav = {false, false, false}
end
