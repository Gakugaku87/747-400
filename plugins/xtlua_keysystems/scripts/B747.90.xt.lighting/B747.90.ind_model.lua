-- 747-400 indicator lights' master dim and test without X-Plane (7-2c;
-- docs/overhaul/notes/ATA-33.md §13): the level of a lit indicator light
-- and of the TEST (ATA33 p.52, p.64-68; FCOM p.441, p.501):
--  - IND LTS BRT: 28 V, bright. DIM: the dim relays put the dimmer cards'
--    12 V on the lights. TEST: the test relays light every tested light
--    bright at once; held 10 s, the time delay relay dims them (and every
--    lit light) by the dim relays (ATA33 p.67; before, TEST 1.0 while held,
--    brighter than BRT)
--  - STORM: every lit light bright, on DIM too (FCOM p.501; the circuit is
--    not in the sources)
--  - power: the battery bus, DC bus 1 or DC bus 3 (estimate: ATA33 p.69's
--    figure gives no light's circuit); the dim, test and time delay relays
--    DC bus 1 or 3 (estimate): without them, bright and no TEST
-- Pure: the glue gives the switch, STORM, the time and the buses, and
-- multiplies each light's condition by the level.
--   local I = B747_ind_model                     -- in XTLua, after dofile
--   local I = dofile(".../B747.90.ind_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_ind_model = M

-- the levels the cockpit's lights take (as before: BRT 0.8, DIM 0.4). DIM
-- is 12 V of 28 V; its brightness is not in the sources (estimate)
M.BRT = 0.8
M.DIM = 0.4
M.TEST_DIM_S = 10 -- ATA33 p.67

function M.new() return {test_t = nil} end

-- s: from M.new(); inp: sel (the IND LTS switch: -1 DIM, 0 BRT, 1 TEST),
-- storm (STORM on), t (seconds), bat, dc1, dc3 (the buses powered).
-- Returns {lit = the level of a lit light (0 without power), test = the
-- level the TEST puts on every tested light (nil: no TEST), dim = true
-- while the dim relays are on, own = the level of a light on its own power
-- (EXT PWR and APU AVAIL: BRT or DIM)}
function M.update(s, inp)
    local relays = inp.dc1 or inp.dc3
    local testing = relays and inp.sel > 0.5
    if testing then s.test_t = s.test_t or inp.t else s.test_t = nil end
    local dim = relays and not inp.storm
        and (inp.sel < -0.5 or (testing and inp.t - s.test_t >= M.TEST_DIM_S)) or false
    local level = dim and M.DIM or M.BRT
    local out = {dim = dim, own = level, lit = 0, test = nil}
    if inp.bat or relays then
        out.lit = level
        if testing then out.test = level end
    end
    return out
end

return M
