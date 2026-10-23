-- 747-400 oxygen without X-Plane: the crew oxygen cylinder and masks, the
-- passenger oxygen (the flow control units: automatic and manual
-- actuation, reset), the therapeutic oxygen, the cylinder pressures on the
-- STATUS page, and the EICAS messages. Logic and sources: docs/overhaul/
-- notes/ATA-35.md §3-§4 (FCOM 1.30 p.455-463, 1.40 p.502, p.510-513,
-- 1.60 p.545-547; ATA30_32_35_36 35-11, 35-20, 35-21).
--
--   local O = B747_oxygen_model          -- in XTLua, after dofile
--   local O = dofile(".../B747.36.oxygen_model.lua")   -- in the tests
--   local s = O.new()
--   local inp = O.inputs()               -- fill it every frame
--   local out = O.update(s, inp, dt)     -- the same table every frame

local M = setmetatable({}, {})
B747_oxygen_model = M

M.AUTO_ALT_FT = 14000       -- the flow control units actuate at about 14,000 ft cabin altitude
                            -- (FCOM p.456; the aneroid 13,250-14,500 ft: ATA30_32_35_36 p.346)
M.RESET_MAX_ALT_FT = 12000  -- they do not reset above 12,000 ft (FCOM p.456; ATA30_32_35_36 p.346)
M.CREW_LOW_PSI = 500        -- >CREW OXY LOW at or below 500 psi (ATA30_32_35_36 p.340)
M.PASS_STATUS_S = 60        -- STATUS PASS OXYGEN ON 60 s after (ATA30_32_35_36 p.376)
M.FULL_PSI = 1850           -- a full cylinder: 1850 psig at 70°F (ATA30_32_35_36 p.316)
M.FULL_K = 294.26           -- 70°F
M.ATM_PSI = 14.7            -- psig to psia
-- estimates (no value in the sources)
M.CREW_USE_PSI_S = 0.06     -- the crew masks in use: about 6 L/min of the 114 ft³ (3,228 L) cylinder
M.PASS_USE_PSI_S = 1.0      -- the passenger cylinders while the flow control units are actuated:
                            -- full to empty in about 30 min
M.MASK_FELT_FT = 10000      -- on the crew masks the crew feel no more than 10,000 ft
M.CREW_MIN_PSI = 50         -- the masks get no oxygen below this pressure

function M.inputs()
    return {
        cabin_alt_ft = 0,
        pass_sw = 0,            -- PASS OXYGEN switch: -1 RESET, 0 NORM, 1 ON (both spring-loaded)
        therap_sw = 0,          -- THERAPEUTIC OXYGEN switch: -1 RESET (spring-loaded), 0 NORM, 1 ON
        crew_masks = false,     -- the crew masks out of their boxes (oxygen flows until RESET/TEST)
        dc = true,              -- power for the flow control units' solenoids (estimate: any DC bus)
        cylinder_c = 21.1,      -- the cylinders' temperature (forward cargo compartment)
        pass_failed_on = false, -- failure: the passenger oxygen actuated by itself
    }
end

function M.new()
    -- the cylinders' contents as their pressure at 70°F
    local s = {crew = M.FULL_PSI, pass = M.FULL_PSI, pass_on = false, therap_on = false, pass_t = 0}
    s.out = {crew_psi = M.FULL_PSI, pass_psi = M.FULL_PSI, pass_on = false, therap_on = false,
        crew_flow = false, felt_alt_ft = 0, crew_low_alert = false, pass_on_alert = false,
        pass_on_status = false, therap_memo = false}
    return s
end

-- a gauge pressure at 70°F at the cylinders' temperature (gas law)
local function at_temperature(psi70, c)
    if psi70 <= 0 then return 0 end
    return math.max(0, (psi70 + M.ATM_PSI) * (c + 273.15) / M.FULL_K - M.ATM_PSI)
end

function M.update(s, inp, dt)
    local out = s.out
    local alt = inp.cabin_alt_ft

    -- the passenger flow control units (FCOM p.456, p.511; ATA30_32_35_36
    -- p.346, p.368): the aneroid actuates them at about 14,000 ft, ON (its
    -- solenoids) at any altitude, X-Plane's failure too; RESET (the reset
    -- solenoid) turns them off below 12,000 ft only
    local auto = alt >= M.AUTO_ALT_FT
    if auto or (inp.pass_sw > 0 and inp.dc) or inp.pass_failed_on then
        s.pass_on = true
    elseif inp.pass_sw < 0 and inp.dc and alt < M.RESET_MAX_ALT_FT then
        s.pass_on = false
    end
    -- the therapeutic oxygen (FCOM p.457, p.513): ON, and with the
    -- passenger oxygen's automatic actuation; RESET below 12,000 ft
    if auto or (inp.therap_sw > 0 and inp.dc) then
        s.therap_on = true
    elseif inp.therap_sw < 0 and inp.dc and alt < M.RESET_MAX_ALT_FT then
        s.therap_on = false
    end
    out.pass_on = s.pass_on
    out.therap_on = s.therap_on
    if s.pass_on then s.pass_t = s.pass_t + dt else s.pass_t = 0 end

    -- the cylinders (estimate: the use)
    if s.pass_on then s.pass = math.max(0, s.pass - M.PASS_USE_PSI_S * dt) end
    out.crew_flow = inp.crew_masks and s.crew > M.CREW_MIN_PSI
    if inp.crew_masks then s.crew = math.max(0, s.crew - M.CREW_USE_PSI_S * dt) end
    out.crew_psi = at_temperature(s.crew, inp.cylinder_c)
    out.pass_psi = at_temperature(s.pass, inp.cylinder_c)

    -- the altitude the crew feel (X-Plane's hypoxia; estimate)
    if out.crew_flow then out.felt_alt_ft = math.min(alt, M.MASK_FELT_FT) else out.felt_alt_ft = alt end

    -- EICAS (FCOM p.545, p.547; ATA30_32_35_36 p.340, p.376)
    out.crew_low_alert = out.crew_psi <= M.CREW_LOW_PSI
    out.pass_on_alert = s.pass_on
    out.pass_on_status = s.pass_t >= M.PASS_STATUS_S
    out.therap_memo = s.therap_on
    return out
end

return M
