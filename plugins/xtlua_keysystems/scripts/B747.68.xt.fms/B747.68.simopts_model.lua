-- The sim's options (2026-11-01 the user; notes/ATA-34-61-FMC.md §126):
-- conveniences of the sim, not the airplane's, turned on and off in
-- X-Plane's Plugins > 747-400 menu (plugins/b747_fms_bridge, Windows):
--  - step: the automatic step climb. At the CRZ page's step point (STEP
--    TO's AT NOW: FCOM p.1348-1349) with VNAV engaged in the cruise, the
--    crew's actions for the cruise climb are done for them: the MCP
--    altitude set to STEP TO, then the altitude selector pushed (CRZ ALT
--    the MCP's: FCOM p.649, p.1257). Not with the MCP altitude set below
--    CRZ ALT (the descent's).
--  - pause: the sim paused once in the cruise two minutes before the T/D,
--    when the FMC's RESET MCP ALT would show (FCOM p.1433); again only once
--    the T/D is three minutes away.
-- Ours (no source: the airplane has none of it): the push a second after
-- the MCP altitude (XTLua's modules see another's write a frame later), a
-- step tried again after 30 s, the re-arm's three minutes.
-- Pure: the glue gives the FMC's state and does the actions.
--   local O = B747_simopts_model                   -- in XTLua, after dofile
--   local O = dofile(".../B747.68.simopts_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_simopts_model = M

M.PAUSE_S = 120     -- RESET MCP ALT's two minutes (FCOM p.1433)
M.REARM_S = 180     -- the pause armed again with the T/D this far (ours)
M.PUSH_S = 1        -- the push after the MCP altitude (ours)
M.RETRY_S = 30      -- a step not taken tried again after this (ours)
M.MIN_GS_KT = 100   -- no time to the T/D below this ground speed (as RESET MCP ALT)
M.FT = 50           -- altitudes this close the same

function M.new() return {to = nil, t = 0, pushed = nil, paused = false} end

-- the automatic step climb's action: "mcp" and the altitude to set, "push"
-- (the altitude selector), or nil. inp: on (the option), air, vnav
-- (engaged), crz (the cruise, no cruise climb or descent), crz_alt, mcp
-- (the MCP altitude), to (STEP TO, nil: none), now (its AT NOW), t (s)
function M.step(s, inp)
    local ok = inp.on and inp.air and inp.vnav and inp.crz and inp.to and inp.now and inp.crz_alt
        and inp.crz_alt > 0 and inp.to > inp.crz_alt + M.FT and inp.mcp >= inp.crz_alt - M.FT
    if not ok then
        s.to, s.pushed = nil, nil
        return nil
    end
    if s.to ~= inp.to then
        s.to, s.t, s.pushed = inp.to, inp.t, nil
        return "mcp", inp.to
    end
    if s.pushed == nil then
        if inp.t - s.t < M.PUSH_S then return nil end
        s.pushed = inp.t
        return "push"
    end
    -- the push did not change CRZ ALT (still the cruise below STEP TO):
    -- once more from the MCP altitude
    if inp.t - s.pushed >= M.RETRY_S then s.to, s.pushed = nil, nil end
    return nil
end

-- true: pause the sim now. inp: on (the option), air, crz (the FMC's
-- cruise phase), td (NM to the T/D, negative past it; nil: none), gs (kt)
function M.pause(s, inp)
    if not inp.air then
        s.paused = false
        return false
    end
    if not (inp.crz and inp.td and inp.gs and inp.gs > M.MIN_GS_KT) then return false end
    local secs = inp.td / inp.gs * 3600
    if secs > M.REARM_S then s.paused = false end
    if inp.on and not s.paused and secs <= M.PAUSE_S then
        s.paused = true
        return true
    end
    return false
end

return M
