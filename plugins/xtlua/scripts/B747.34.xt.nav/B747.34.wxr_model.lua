-- 747-400 weather radar control (5-1 step 5c): the 570 weather radar panel
-- (each pilot's TILT, MAP GAIN and mode switches TFR, WX, WX+T, MAP, GCS; the
-- R/T switches LR/T and RR/T; TEST), the selected R/T and its power, the
-- antenna stabilization from the IRUs, and what each ND shows. X-Plane's
-- radar draws the returns; this decides its mode, tilt, gain, ground clutter
-- suppression and stabilization for each ND. Logic and sources:
-- docs/overhaul/notes/ATA-34.md §3.11, §4.12, §17 (FCOM p.1040, p.1155,
-- p.1223-1224; ATA34_1 34-43 p.210-263).
--
--   local W = B747_wxr_model                -- in XTLua, after dofile
--   local W = dofile(".../B747.34.wxr_model.lua")   -- in the tests
--   local s = W.new()
--   W.mode(s, side, W.SEL_WX)               -- the panel's switches, as pushed
--   local inp = W.inputs()                  -- fill it every frame
--   local out = W.update(s, inp)            -- the same table every frame

local M = setmetatable({}, {})
B747_wxr_model = M

-- each pilot's mode switch, the last one pushed (FCOM p.1223)
M.SEL_WX, M.SEL_WXT, M.SEL_MAP, M.SEL_TFR = 1, 2, 3, 4
-- X-Plane's EFIS_weather_mode
M.XP_OFF, M.XP_TEST, M.XP_WX, M.XP_WXT, M.XP_MAP = 0, 1, 2, 3, 4
M.RT_L, M.RT_R = 1, 2
M.IRU_L, M.IRU_C, M.IRU_R = 1, 2, 3
-- the IRS selectors (flt_inst/irs_src): 0 L, 1 C, 2 R
M.SRC_L, M.SRC_R = 0, 2
M.TILT_MAX = 15             -- deg up and down (FCOM p.1223, ATA34_1 p.222)
-- the steps of X-Plane's own tilt and gain commands, kept for the 3D knobs
-- (estimate: the panel's knobs are continuous)
M.TILT_STEP, M.GAIN_STEP = 0.1, 0.1
-- X-Plane's calibrated gain is the MAP GAIN knob's clockwise stop; the knob
-- turns it down to 0 (estimate: the manual gives no range)
M.GAIN_CAL = 1
M.WXT_MAX_NM = 40           -- turbulence up to 40 nm, beyond it WX (FCOM p.1224)
-- the ND's fault annunciations (FCOM p.1155, amber): the fault source, shown
-- in TEST in the tilt field (FCOM p.1224); ATT and WEAK also outside TEST
M.FAULT_NONE, M.FAULT_ANT, M.FAULT_ATT, M.FAULT_WEAK, M.FAULT_CONT, M.FAULT_RT = 0, 1, 2, 3, 4, 5
-- the ND's gain annunciation in MAP: CAL at the MAP GAIN knob's calibrated
-- stop (FCOM p.1155), VAR below it (ATA34_1 p.244); none with the automatic
-- gain of WX and WX+T (FCOM p.1013 shows WXR and the tilt only). Estimate:
-- FCOM lists CAL without saying when, ATA34_1 describes VAR for another panel.
M.GAIN_NONE, M.GAIN_SHOW_CAL, M.GAIN_SHOW_VAR = 0, 1, 2

local function pair(v) return {v, v} end
local function other(i) return 3 - i end

function M.inputs()
    return {
        on = pair(false),           -- each EFIS control panel's WXR (X-Plane's weather on)
        range_nm = pair(40),        -- each EFIS control panel's range
        power = pair(true),         -- R/T L and R
        failed = false,             -- X-Plane's radar failure (taken as the R/T's)
        fail_ant = false,           -- the antenna (wxr/fail[0])
        fail_cont = false,          -- the control panel (wxr/fail[1])
        fail_weak = false,          -- the receiver's calibration, AGC (wxr/fail[2])
        att_valid = {true, true, true},     -- IRU L, C, R
        irs_src = {0, 2},           -- each pilot's IRS selector
    }
end

function M.new()
    return {
        sel = pair(M.SEL_WX),
        tilt = pair(0),
        gain = pair(M.GAIN_CAL),    -- the MAP GAIN knobs, 0 to 1 (1 = CAL)
        gcs = pair(false),
        rt = M.RT_L,                -- unpowered, the waveguide switch is at L (ATA34_1 p.256)
        test = pair(false),         -- TEST shown on this side's ND
        out = {
            operating = false,      -- the selected R/T is on
            stab = true,            -- its IRU gives attitude
            xp_mode = pair(M.XP_OFF),
            tilt = pair(0), gain = pair(M.GAIN_CAL), gcs = pair(false),
            lamp_sel = pair(0),     -- the lit mode switch (SEL_*), 0 none
            lamp_gcs = pair(false),
            lamp_test = false,
            lamp_rt = 0,            -- RT_L or RT_R, 0 none
            fault = M.FAULT_NONE,   -- the radar's fault, the first of RT, ANT, CONT, WEAK, ATT
            nd_fail = pair(false),  -- WXR FAIL on this side's ND
            nd_fault = pair(M.FAULT_NONE),  -- the fault source in TEST
            nd_msg = pair(M.FAULT_NONE),    -- WEAK or ATT outside TEST
            nd_gain = pair(M.GAIN_NONE),    -- CAL or VAR in MAP
        },
    }
end

-- the panel's switches
function M.mode(s, side, sel)
    s.sel[side] = sel
    -- another mode ends the test, on this side only (FCOM p.1224; estimate:
    -- the manual does not say whether the other ND stays in TEST)
    s.test[side] = false
end

-- TEST on both NDs, from the operating R/T only (estimate)
function M.test(s)
    if s.out.operating then s.test[1], s.test[2] = true, true end
end

function M.select_rt(s, rt) s.rt = rt end

function M.tilt(s, side, dir)
    local t = s.tilt[side] + dir * M.TILT_STEP
    s.tilt[side] = math.max(-M.TILT_MAX, math.min(M.TILT_MAX, t))
end

function M.gain(s, side, dir)
    local g = s.gain[side] + dir * M.GAIN_STEP
    s.gain[side] = math.max(0, math.min(M.GAIN_CAL, g))
end

function M.toggle_gcs(s, side) s.gcs[side] = not s.gcs[side] end

-- the stabilization source: the onside IRU, or C when the onside IRS
-- selector is away from it (ATA34_1 p.242)
local function stab_iru(rt, irs_src)
    if rt == M.RT_L then
        return (irs_src[1] == M.SRC_L) and M.IRU_L or M.IRU_C
    end
    return (irs_src[2] == M.SRC_R) and M.IRU_R or M.IRU_C
end

local XP_OF_SEL = {[M.SEL_WX] = M.XP_WX, [M.SEL_WXT] = M.XP_WXT, [M.SEL_MAP] = M.XP_MAP}

function M.update(s, inp)
    local out = s.out
    -- either EFIS panel's WXR turns on the selected R/T (FCOM p.1040, ATA34_1 p.253)
    local rt_ok = inp.power[s.rt] and not inp.failed
    out.operating = (inp.on[1] or inp.on[2]) and rt_ok
    out.stab = inp.att_valid[stab_iru(s.rt, inp.irs_src)]
    -- the faults (ATA34_1 p.246): the R/T (the selected one unpowered or
    -- failed: estimate), the antenna or the control panel stop the returns
    -- (WXR FAIL); the calibration (WEAK) and the stabilization attitude (ATT)
    -- leave them, WEAK before ATT
    local fault = M.FAULT_NONE
    if not rt_ok then fault = M.FAULT_RT
    elseif inp.fail_ant then fault = M.FAULT_ANT
    elseif inp.fail_cont then fault = M.FAULT_CONT
    elseif inp.fail_weak then fault = M.FAULT_WEAK
    elseif not out.stab then fault = M.FAULT_ATT end
    out.fault = fault
    local no_returns = fault == M.FAULT_RT or fault == M.FAULT_ANT or fault == M.FAULT_CONT
    for i = 1, 2 do
        -- WX+T beyond 40 nm becomes WX (FCOM p.1224)
        if s.sel[i] == M.SEL_WXT and inp.range_nm[i] > M.WXT_MAX_NM then s.sel[i] = M.SEL_WX end
        -- the WXR selected off on this side ends its test
        if not inp.on[i] then s.test[i] = false end
    end
    local both_tfr = s.sel[1] == M.SEL_TFR and s.sel[2] == M.SEL_TFR
    for i = 1, 2 do
        -- TFR shows the other side's display: its mode, tilt, gain and GCS;
        -- both TFR is TEST (FCOM p.1223: "both at the same time", taken as
        -- both selected: estimate)
        local src = (s.sel[i] == M.SEL_TFR) and other(i) or i
        local mode
        if not out.operating then
            mode = M.XP_OFF
        elseif s.test[i] or both_tfr then
            mode = M.XP_TEST
        elseif no_returns then
            mode = M.XP_OFF
        else
            mode = XP_OF_SEL[s.sel[src]]
        end
        out.xp_mode[i] = mode
        out.tilt[i] = s.tilt[src]
        -- the gain is automatic but in MAP (FCOM p.1223, ATA34_1 p.260)
        out.gain[i] = (mode == M.XP_MAP) and s.gain[src] or M.GAIN_CAL
        -- the ND's annunciations (with this side's WXR selected)
        out.nd_fail[i] = inp.on[i] and no_returns and mode ~= M.XP_TEST
        out.nd_fault[i] = (mode == M.XP_TEST) and fault or M.FAULT_NONE
        out.nd_msg[i] = M.FAULT_NONE
        if mode == M.XP_WX or mode == M.XP_WXT or mode == M.XP_MAP then
            if fault == M.FAULT_WEAK or fault == M.FAULT_ATT then out.nd_msg[i] = fault end
        end
        out.nd_gain[i] = M.GAIN_NONE
        if mode == M.XP_MAP then
            out.nd_gain[i] = (out.gain[i] >= M.GAIN_CAL - 1e-6) and M.GAIN_SHOW_CAL or M.GAIN_SHOW_VAR
        end
        out.gcs[i] = s.gcs[src]
        -- the panel is powered by the operating R/T (ATA34_1 p.210)
        out.lamp_sel[i] = out.operating and s.sel[i] or 0
        out.lamp_gcs[i] = out.operating and s.gcs[i]
    end
    out.lamp_test = out.operating and (s.test[1] or s.test[2] or both_tfr)
    out.lamp_rt = out.operating and s.rt or 0
    return out
end

return M
