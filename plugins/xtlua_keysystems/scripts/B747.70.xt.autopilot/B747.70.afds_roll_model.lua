-- The FCCs' roll laws (6-3 step 2a; the plan and sources in
-- docs/overhaul/notes/ATA-22.md §10 and §16): the roll command, the bank
-- the A/P flies and the F/Ds show, out of the roll mode the AFDS model
-- (B747.70.afds_model.lua) has. X-Plane's heading modes and F/D are not
-- used.
--  - HDG SEL: the selected heading's error to the airplane's heading, both
--    in the heading reference (ATA22 p.358). Selected before the push, the
--    turn toward the smaller error; turned after the push, the turn the
--    way the knob turned (ATA22 p.274): from the push on the error follows
--    the knob unwrapped, so a turn past 180 degrees keeps its way (within
--    one round).
--  - HDG HOLD: wings level (ROLL DOWN, ATA22 p.348) until the AFDS model
--    has its heading (the roll under 3 degrees for 2 s: p.352-353), then
--    that heading; kept through a change of the heading reference.
--  - ATT: the bank the AFDS model holds (5-30 degrees: FCOM p.663).
--  - T/O: wings level on the ground (FCOM p.666), from the lift-off the
--    track there (p.663; ATA22 p.358); G/A: the track at its engagement
--    (FCOM p.663), wings level on the ground.
--  - LNAV: the FMC's steering (ATA22 p.358), at the rate below as before
--    (6-1/6-2 step 6c).
--  - LOC and ROLLOUT: not here (the old law until steps 2b and 4).
-- A heading or track error asks for a turn of error / TAU_S degrees a
-- second, the bank of that turn at the TAS, within the bank limit
-- (estimate: the sources give no gains); the command moves at most
-- ROLL_RATE degrees a second (estimate, as LNAV's) from the bank where the
-- law starts (the roll attitude integrator synchronized: ATA22 p.348).
-- The bank limit (FCOM p.647): in HDG SEL the MCP's selector, 5-25, or
-- AUTO; AUTO varies 15-25 with TAS, flaps and V2: 15 below V2 + 10 with
-- the flaps out (FCTM p.118), 25 with the flaps out above it, flaps up by
-- TAS (estimate: 25 to 300 kt, 15 from 480 kt). In LNAV with AUTO only
-- the 15 below V2 + 10 (FCTM p.118: the FMC's holds bank up to 30, FMSPG
-- p.164, p.226); HDG HOLD and TO/GA within AUTO (estimate). NORM's
-- reference in the polar areas gives HDG SEL and HDG HOLD no heading
-- (FCOM p.1046): no command (NCD), the bank held.
-- Pure: the airplane's state in, the command out.
--   local R = B747_afds_roll_model                      -- in XTLua, after dofile
--   local R = dofile(".../B747.70.afds_roll_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_afds_roll_model = M

-- a heading error's turn: error / TAU_S degrees a second (estimate)
M.TAU_S = 8
-- the command's rate, degrees a second (estimate)
M.ROLL_RATE = 3
-- AUTO's bank limit (FCOM p.647): 15 below V2 + V2_ADD with the flaps out
-- (FCTM p.118); flaps up AUTO_MAX to AUTO_TAS_LO kt TAS, AUTO_MIN from
-- AUTO_TAS_HI (estimate)
M.AUTO_MAX = 25
M.AUTO_MIN = 15
M.V2_ADD = 10
M.AUTO_TAS_LO = 300
M.AUTO_TAS_HI = 480
-- the selector's positions 1-5 (0 AUTO: FCOM p.647)
M.SELECTOR = {5, 10, 15, 20, 25}
-- the modes with a law here
M.LAW = {HDG_SEL = true, HDG_HOLD = true, ATT = true, LNAV = true, TO = true, GA = true}

local G = 9.80665
local KT = 1852 / 3600
local function wrap(a) return (a + 180) % 360 - 180 end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function M.new()
    return {cmd = nil, mode = nil, err = nil, hold = nil, trk_ref = nil, valid = false,
        last_sel = nil, last_hdg = nil, ref_true = nil}
end

function M.inputs()
    return {
        mode = nil,         -- the AFDS model's roll mode
        active = false,     -- an A/P engaged or a F/D shown
        ground = false,
        bank = 0,           -- the airplane's bank (right positive)
        hdg = 0,            -- its heading in the heading reference
        ref_true = false,   -- the reference is true north
        hdg_valid = true,   -- false: NORM in the polar areas (FCOM p.1046)
        trk = 0,            -- its track (true)
        sel = 0,            -- the MCP's heading (in the reference)
        held = false,       -- the AFDS model has HDG HOLD's heading
        att_bank = 0,       -- ATT's bank
        lnav_bank = 0,      -- the FMC's steering
        selector = 0,       -- the bank limit selector: 0 AUTO, 1-5
        tas = 0,            -- kt
        ias = 0,            -- kt
        flaps_up = true,
        v2 = 999,           -- the FMC's V2 (999: none)
    }
end

-- below V2 + 10 with the flaps out (FCTM p.118)
local function below_v2(inp)
    return not inp.flaps_up and inp.v2 < 900 and inp.ias < inp.v2 + M.V2_ADD
end

-- AUTO's bank limit (FCOM p.647; FCTM p.118)
function M.auto_limit(inp)
    if not inp.flaps_up then return below_v2(inp) and M.AUTO_MIN or M.AUTO_MAX end
    local f = clamp((inp.tas - M.AUTO_TAS_LO) / (M.AUTO_TAS_HI - M.AUTO_TAS_LO), 0, 1)
    return M.AUTO_MAX - f * (M.AUTO_MAX - M.AUTO_MIN)
end

-- the bank limit of a mode: HDG SEL's selector, else AUTO
function M.limit(mode, inp)
    if mode == "HDG_SEL" and inp.selector >= 1 then return M.SELECTOR[inp.selector] or M.AUTO_MAX end
    return M.auto_limit(inp)
end

-- the bank of a heading or track error: the turn of err / TAU_S degrees a
-- second at the TAS (100 kt at least), within the limit
function M.bank_for(err, inp, limit)
    local v = math.max(inp.tas, 100) * KT
    local b = math.deg(math.atan(v * math.rad(err / M.TAU_S) / G))
    return clamp(b, -limit, limit)
end

-- HDG SEL's error: the last one moved by the knob and the airplane's turn,
-- the same angle as sel - hdg within one round each way
local function sel_err(s, inp)
    if s.err == nil or s.last_sel == nil or s.ref_true ~= inp.ref_true then
        return wrap(inp.sel - inp.hdg)
    end
    local e = s.err + wrap(inp.sel - s.last_sel) - wrap(inp.hdg - s.last_hdg)
    local w = wrap(inp.sel - inp.hdg)
    local r = w + 360 * math.floor((e - w) / 360 + 0.5)
    if r >= 360 then r = r - 360 elseif r <= -360 then r = r + 360 end
    return r
end

-- the command (degrees of bank, right positive), or nil without a law here
-- (no mode, LOC, ROLLOUT); s.valid false for NCD
function M.update(s, inp, dt)
    dt = dt or 0
    local mode = inp.active and inp.mode or nil
    if not M.LAW[mode] then
        s.mode, s.cmd, s.valid, s.err, s.hold, s.trk_ref = mode, nil, false, nil, nil, nil
        s.last_sel, s.last_hdg, s.ref_true = inp.sel, inp.hdg, inp.ref_true
        return nil
    end
    if mode ~= s.mode then
        s.mode, s.err, s.hold, s.trk_ref = mode, nil, nil, nil
        if mode == "GA" and not inp.ground then s.trk_ref = inp.trk end
    end
    if s.cmd == nil then s.cmd = inp.bank end
    -- HDG HOLD keeps its heading through a change of the reference
    if s.hold and s.ref_true ~= nil and s.ref_true ~= inp.ref_true then
        s.hold = (s.hold + inp.hdg - s.last_hdg) % 360
    end
    local limit = M.limit(mode, inp)
    local target, valid = 0, true
    if mode == "HDG_SEL" then
        s.err = sel_err(s, inp)
        target, valid = M.bank_for(s.err, inp, limit), inp.hdg_valid
    elseif mode == "HDG_HOLD" then
        valid = inp.hdg_valid
        if valid and inp.held and not s.hold then s.hold = inp.hdg end
        if s.hold then target = M.bank_for(wrap(s.hold - inp.hdg), inp, limit) end
    elseif mode == "ATT" then
        target = inp.att_bank
    elseif mode == "LNAV" then
        target = inp.lnav_bank
        if inp.selector == 0 and below_v2(inp) then target = clamp(target, -M.AUTO_MIN, M.AUTO_MIN) end
    elseif inp.ground then
        -- T/O and G/A on the ground: wings level, the track from the lift-off
        s.trk_ref = nil
    else
        if s.trk_ref == nil then s.trk_ref = inp.trk end
        target = M.bank_for(wrap(s.trk_ref - inp.trk), inp, limit)
    end
    -- no reference: the bank held (NCD)
    if not valid then target = s.cmd end
    local step = M.ROLL_RATE * dt
    s.cmd = s.cmd + clamp(target - s.cmd, -step, step)
    s.valid = valid
    s.last_sel, s.last_hdg, s.ref_true = inp.sel, inp.hdg, inp.ref_true
    return s.cmd
end

return M
