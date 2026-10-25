-- 747-400 display units and EIUs (5-2 step 1): the six display units' power
-- and failures, the INBD and LWR display selectors with the automatic
-- switching, the three EIUs (power, failures, each pilot's EIU source
-- selector and the centre EIU SEL), and which unit shows each display.
-- Logic and sources: docs/overhaul/notes/ATA-31.md §2.2, §3.2, §4.1, §10
-- (FCOM p.800, p.804, p.1044-1045, p.1071-1073, p.1199, p.1529).
--
--   local D = B747_display_model            -- in XTLua, after dofile
--   local D = dofile(".../B747.60.display_model.lua")  -- in the tests
--   local s = D.new()
--   local inp = D.inputs()                  -- fill it every frame
--   local out = D.update(s, inp)            -- the same table every frame

local M = setmetatable({}, {})
B747_display_model = M

-- the display units
M.U_CAPT_OUT, M.U_CAPT_IN, M.U_UPPER, M.U_LOWER, M.U_FO_IN, M.U_FO_OUT = 1, 2, 3, 4, 5, 6
-- the displays, in the order of electrical/display_has_power[0..5] (the panel)
M.C_PFD_CAPT, M.C_PFD_FO, M.C_ND_FO, M.C_ND_CAPT, M.C_PRI, M.C_SEC = 1, 2, 3, 4, 5, 6
-- the selectors, as positions per pilot (the knobs are mirrored in the glue)
M.INBD_EICAS, M.INBD_NORM, M.INBD_PFD = 0, 1, 2
M.LWR_PRI, M.LWR_NORM, M.LWR_ND = 0, 1, 2
-- the EIUs and their selectors
M.EIU_L, M.EIU_C, M.EIU_R = 1, 2, 3
M.SEL_AUTO = 0              -- or EIU_L, EIU_C, EIU_R
M.ON = 6                    -- display_has_power's "powered" (the old value)

-- each display's position as the panel takes it (flt_inst/display/*_pos) on
-- the units it can be shown on
M.POS = {
    [M.C_PFD_CAPT] = {[M.U_CAPT_OUT] = 0, [M.U_CAPT_IN] = 1},
    [M.C_PFD_FO]   = {[M.U_FO_OUT] = 0, [M.U_FO_IN] = 1},
    [M.C_ND_FO]    = {[M.U_FO_IN] = 0, [M.U_LOWER] = 1},
    [M.C_ND_CAPT]  = {[M.U_CAPT_IN] = 0, [M.U_LOWER] = 1},
    [M.C_PRI]      = {[M.U_UPPER] = 0, [M.U_LOWER] = 1, [M.U_CAPT_IN] = 2, [M.U_FO_IN] = 3},
    [M.C_SEC]      = {[M.U_LOWER] = 0, [M.U_FO_IN] = 1, [M.U_CAPT_IN] = 2, [M.U_CAPT_OUT] = 3,
                      [M.U_FO_OUT] = 4, [M.U_UPPER] = 5},
}

-- AUTO: the Captain's L, C, R, the F/O's R, C, L, EICAS L, C, R (FCOM p.1044, p.1529)
local AUTO_ORDER = {{M.EIU_L, M.EIU_C, M.EIU_R}, {M.EIU_R, M.EIU_C, M.EIU_L}, {M.EIU_L, M.EIU_C, M.EIU_R}}

local function six(v) return {v, v, v, v, v, v} end

function M.inputs()
    return {
        inbd = {M.INBD_NORM, M.INBD_NORM},  -- Captain, F/O
        lwr = {M.LWR_NORM, M.LWR_NORM},
        unit_power = six(true),     -- Captain's units: APU standby bus, upper: main
                                    -- standby bus, F/O's and lower: F/O transfer bus
        unit_fail = six(false),
        eiu_power = {true, true, true},     -- L main standby, C CAPT transfer, R F/O transfer bus
        eiu_fail = {false, false, false},
        eiu_sel = {M.SEL_AUTO, M.SEL_AUTO, M.SEL_AUTO},     -- Captain, F/O, EICAS (centre)
        standby_power = false,      -- no AC: the airplane on standby power
        on_ground = true,
    }
end

function M.new()
    return {
        out = {
            unit_ok = six(false),
            eiu_ok = {false, false, false},
            eiu = {0, 0, 0},        -- the EIU each of Captain, F/O, EICAS uses, 0 none
            shown_on = six(0),      -- the unit each display is on, 0 not shown
            pos = six(0),           -- flt_inst/display/*_pos
            power = six(0),         -- electrical/display_has_power[0..5]
            msg_eiu_left = false,
        },
    }
end

local function pick_eiu(sel, order, ok)
    if sel ~= M.SEL_AUTO then
        -- a selected EIU that fails is not replaced (FCOM p.1529)
        return ok[sel] and sel or 0
    end
    for _, e in ipairs(order) do
        if ok[e] then return e end
    end
    return 0
end

local SIDE_IN, SIDE_OUT = {M.U_CAPT_IN, M.U_FO_IN}, {M.U_CAPT_OUT, M.U_FO_OUT}
local SIDE_PFD, SIDE_ND = {M.C_PFD_CAPT, M.C_PFD_FO}, {M.C_ND_CAPT, M.C_ND_FO}

function M.update(s, inp)
    local out = s.out
    for e = 1, 3 do out.eiu_ok[e] = inp.eiu_power[e] and not inp.eiu_fail[e] end
    -- on standby power a failed left EIU takes all the displays (FCOM p.1529)
    local all_off = inp.standby_power and not out.eiu_ok[M.EIU_L]
    for u = 1, 6 do out.unit_ok[u] = inp.unit_power[u] and not inp.unit_fail[u] and not all_off end
    for k = 1, 3 do out.eiu[k] = pick_eiu(inp.eiu_sel[k], AUTO_ORDER[k], out.eiu_ok) end

    local shown, used = out.shown_on, {}
    for c = 1, 6 do shown[c] = 0 end
    local function put(c, u)
        if shown[c] == 0 and not used[u] and out.unit_ok[u] then
            shown[c], used[u] = u, true
            return true
        end
        return false
    end

    -- the lower unit: EICAS PRI before an ND, the Captain's ND before the
    -- F/O's (estimate: the manual does not say how the two LWR selectors combine)
    local lwr_pri = inp.lwr[1] == M.LWR_PRI or inp.lwr[2] == M.LWR_PRI
    local lwr_nd = (not lwr_pri) and ((inp.lwr[1] == M.LWR_ND and 1) or (inp.lwr[2] == M.LWR_ND and 2)) or nil
    local lwr_norm = not lwr_pri and lwr_nd == nil
    -- the PFDs: on the inboard unit with INBD PFD, else on the outboard unit,
    -- or the inboard one with INBD NORM when the outboard unit fails (FCOM p.1045)
    for i = 1, 2 do
        if inp.inbd[i] == M.INBD_PFD then
            if not put(SIDE_PFD[i], SIDE_IN[i]) then put(SIDE_PFD[i], SIDE_OUT[i]) end
        elseif not put(SIDE_PFD[i], SIDE_OUT[i]) and inp.inbd[i] == M.INBD_NORM then
            put(SIDE_PFD[i], SIDE_IN[i])
        end
    end
    -- primary EICAS: on the lower unit with LWR EICAS PRI, else on the upper
    -- unit, or the lower one with LWR NORM when the upper unit fails (FCOM p.1045, p.1072)
    if lwr_pri then put(M.C_PRI, M.U_LOWER) end
    put(M.C_PRI, M.U_UPPER)
    if lwr_norm then put(M.C_PRI, M.U_LOWER) end
    -- an ND on the lower unit with LWR ND
    if lwr_nd then put(SIDE_ND[lwr_nd], M.U_LOWER) end
    -- the inboard units: INBD EICAS, the primary if nothing else shows it,
    -- else the secondary; INBD NORM, the ND (FCOM p.1045)
    for i = 1, 2 do
        if inp.inbd[i] == M.INBD_EICAS then
            if not put(M.C_PRI, SIDE_IN[i]) then put(M.C_SEC, SIDE_IN[i]) end
        elseif inp.inbd[i] == M.INBD_NORM then
            put(SIDE_ND[i], SIDE_IN[i])
        end
    end
    -- the secondary EICAS on the lower unit with LWR NORM. A display selected
    -- elsewhere leaves its usual unit blank (estimate: the panel shows each
    -- display once; the manual shows the selectors with a failed unit only)
    if lwr_norm then put(M.C_SEC, M.U_LOWER) end

    -- the EIU each display needs: each pilot's for the PFD and ND, the
    -- centre's for EICAS (FCOM p.1044, p.1529)
    local need = {
        [M.C_PFD_CAPT] = out.eiu[1], [M.C_ND_CAPT] = out.eiu[1],
        [M.C_PFD_FO] = out.eiu[2], [M.C_ND_FO] = out.eiu[2],
        [M.C_PRI] = out.eiu[3], [M.C_SEC] = out.eiu[3],
    }
    for c = 1, 6 do
        if shown[c] ~= 0 and need[c] == 0 then shown[c] = 0 end
        out.power[c] = (shown[c] ~= 0) and M.ON or 0
        out.pos[c] = (shown[c] ~= 0) and M.POS[c][shown[c]] or 0
    end
    -- >EIU LEFT, inhibited in flight (FCOM p.1199)
    out.msg_eiu_left = (not out.eiu_ok[M.EIU_L]) and inp.on_ground
    return out
end

return M
