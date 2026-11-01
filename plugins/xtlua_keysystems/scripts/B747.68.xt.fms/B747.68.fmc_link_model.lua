-- The two FMCs and the CDUs' connection to them (6-1/6-2 step 11d1;
-- notes/ATA-34-61-FMC.md §98). Logic and sources (FCOM p.1275, p.1421-1422,
-- p.1429, p.1434; ATA34_2 p.456, p.496, p.629):
--  - An FMC works with its power (the left on the Captain's transfer bus or
--    the APU standby bus, the right on the F/O's transfer bus: FCOM p.800,
--    p.804) and not failed.
--  - Each CDU works through one FMC: the left and centre CDUs the left FMC,
--    the right CDU the right FMC; the onside NAV source selector at the
--    offside FMC that one (ATA34_2 p.456, p.496). Its FMC failing: the CDU
--    shows the MENU page and TIMEOUT - RESELECT, the FMC no longer
--    connected (FCOM p.1275, p.1422; ATA34_2 p.629). In flight the loss of the FMC
--    the FMC master selector selects takes every CDU (p.1275).
--  - Connected again: its NAV source selector turned to an operative FMC
--    (p.1422); <FMC on the MENU page (p.1275): on the ground to an
--    operative FMC, in flight to the selected one while it works (p.1275:
--    after the selected FMC's loss the CDUs wait for the selector). The
--    MENU page has no <FMC without one (p.1275; ATA34_2 p.629).
--  - SINGLE FMC OPERATION while one FMC works (p.1275, p.1434); FMC LEFT,
--    RIGHT on the EICAS after a delay (p.1275, p.1429).
-- Estimates: the centre CDU on the right FMC while the left one fails; a
-- CDU without power reconnects to its FMC by itself when both have power
-- (no TIMEOUT - RESELECT: the MENU page at power-up, as before); SINGLE
-- FMC OPERATION on every connected CDU (FCOM: in flight on one); the
-- EICAS delay EICAS_DELAY_S.
--
--   local M = B747_fmc_link_model          -- in XTLua, after dofile
--   local s = M.new()
--   local out = M.update(s, inp, dt)       -- each frame

local M = setmetatable({}, {})
B747_fmc_link_model = M

M.L, M.R = 1, 2
M.CDUS = {"fmsL", "fmsC", "fmsR"}
M.EICAS_DELAY_S = 5
M.TIMEOUT = "TIMEOUT - RESELECT"

function M.new()
    return {ok = {true, true}, link = {fmsL = M.L, fmsC = M.L, fmsR = M.R}, src = {}, auto = {},
        down_t = {0, 0},
        out = {ok = {true, true}, lost = {}, eicas = {false, false}, single = false}}
end

-- the CDU's FMC by its NAV source selector (src: the FMC it selects, nil
-- at a CDU position: its normal one)
local function own(cdu, src, ok)
    if cdu == "fmsC" then return ok[M.L] and M.L or (ok[M.R] and M.R or M.L) end
    if src then return src end
    return cdu == "fmsR" and M.R or M.L
end

-- the FMC <FMC connects the CDU to, nil without one
local function pick(s, cdu, inp)
    if inp.ground then
        local f = own(cdu, inp.src[cdu], s.ok)
        if s.ok[f] then return f end
        return s.ok[3 - f] and 3 - f or nil
    end
    return s.ok[inp.master] and inp.master or nil
end

-- inp: power {L, R}, fail {L, R}, src {fmsL = 1|2|nil, fmsR = ...} (the
-- NAV source selectors), cdu_power {fmsL, fmsC, fmsR}, master (1|2), ground
function M.update(s, inp, dt)
    local out = s.out
    local m = inp.master
    local master_lost = not inp.ground and s.ok[m] and not (inp.power[m] and not inp.fail[m])
    for i = 1, 2 do
        s.ok[i] = inp.power[i] and not inp.fail[i] and true or false
        out.ok[i] = s.ok[i]
        s.down_t[i] = s.ok[i] and 0 or s.down_t[i] + (dt or 0)
        out.eicas[i] = s.down_t[i] >= M.EICAS_DELAY_S
    end
    for _, cdu in ipairs(M.CDUS) do
        out.lost[cdu] = nil
        local src = inp.src[cdu]
        local turned = src ~= s.src[cdu]
        s.src[cdu] = src
        if not inp.cdu_power[cdu] then s.auto[cdu] = true end
        if s.auto[cdu] then
            -- without power, and after it until connected: its FMC when
            -- that works
            local f = own(cdu, src, s.ok)
            s.link[cdu] = s.ok[f] and f or nil
            if s.link[cdu] and inp.cdu_power[cdu] then s.auto[cdu] = nil end
        else
            -- the selector turned to an operative FMC: connected to it
            if turned then
                local f = own(cdu, src, s.ok)
                if s.ok[f] then s.link[cdu] = f end
            end
            local f = s.link[cdu]
            if f and (not s.ok[f] or master_lost) then
                s.link[cdu] = nil
                out.lost[cdu] = true
            end
        end
    end
    out.single = s.ok[M.L] ~= s.ok[M.R]
    return out
end

-- <FMC on the MENU page: the CDU's FMC again (FCOM p.1275); the FMC or nil
function M.connect(s, cdu, inp)
    if s.link[cdu] then return s.link[cdu] end
    local f = pick(s, cdu, inp)
    if f then s.link[cdu], s.auto[cdu] = f, nil end
    return f
end

-- the FMC the CDU is connected to or <FMC would connect it to (the MENU
-- page's <FMC), nil without one
function M.available(s, cdu, inp)
    return s.link[cdu] or pick(s, cdu, inp)
end

-- the CDU connected to a working FMC
function M.linked(s, cdu)
    return s.link[cdu] ~= nil
end

return M
