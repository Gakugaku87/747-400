-- 747-400 exterior lights without X-Plane (7-2b; docs/overhaul/notes/
-- ATA-33.md §12): each light on from its P5 switch, its power and, for
-- some, the gear lever or the ground mode (ATA33 p.318-358; FCOM p.450-452,
-- p.500):
--  - landing (OUTBD L, INBD L, INBD R, OUTBD R): R INBD on AC bus 1, R
--    OUTBD on AC bus 3 (ATA33 p.330-331; the left the same: estimate).
--    With the gear lever not DOWN, the INBD switch ON dims that side's
--    INBD and OUTBD to 70 % (R1042); with the INBD switch OFF the OUTBD is
--    bright whatever the lever (ATA33 p.328, p.330; the left the same:
--    estimate. Before, all four at 50 % with the lever not DOWN)
--  - runway turnoff L and R: the ground service bus, the ground mode only
--    (R7333: ATA33 p.334-335; the PSEU's primary ground relay: estimate)
--  - taxi: the ground mode only (FCOM p.451; its power not in the sources:
--    the ground service bus, estimate)
--  - nav, beacon (LWR or BOTH), strobe, logo, wing: the ground service bus
--    (ATA33 p.326, p.340, p.348, p.354, p.358)
-- Pure: the glue gives the switches (on or not), the buses and the PSEU's
-- ground, and writes X-Plane's lights.
--   local L = B747_light_model                     -- in XTLua, after dofile
--   local L = dofile(".../B747.90.light_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_light_model = M

M.LANDING_DIM = 0.7
-- the landing lights in X-Plane's order (landing_lights_switch[0..3]):
-- OUTBD L, INBD L, INBD R, OUTBD R; their AC buses (1-4) and their side's
-- INBD light
M.LANDING_BUS = {3, 1, 1, 3}
M.LANDING_INBD = {2, 2, 3, 3}

-- inp: sw = {landing = {OBL, IBL, IBR, OBR}, turnoff = {L, R}, taxi, beacon,
-- nav, strobe, wing, logo} (true: on), ac = {AC buses 1-4 powered}, gsb
-- (the ground service bus), ground (the PSEU's), gear_down (the lever
-- DOWN). Returns {landing = {4 ratios}, turnoff = {L, R}, taxi, beacon,
-- nav, strobe, wing, logo} (0 or 1)
function M.update(inp)
    local sw = inp.sw
    local out = {landing = {}, turnoff = {}}
    for i = 1, 4 do
        local lit = sw.landing[i] and inp.ac[M.LANDING_BUS[i]]
        local dim = not inp.gear_down and sw.landing[M.LANDING_INBD[i]]
        out.landing[i] = lit and (dim and M.LANDING_DIM or 1) or 0
    end
    local gsb = inp.gsb
    local function on(v) return v and 1 or 0 end
    for i = 1, 2 do out.turnoff[i] = on(sw.turnoff[i] and gsb and inp.ground) end
    out.taxi = on(sw.taxi and gsb and inp.ground)
    out.beacon = on(sw.beacon and gsb)
    out.nav = on(sw.nav and gsb)
    out.strobe = on(sw.strobe and gsb)
    out.wing = on(sw.wing and gsb)
    out.logo = on(sw.logo and gsb)
    return out
end

-- the emergency lights (7-2d; notes/ATA-33.md §14): P5's EMER LIGHTS
-- (OFF, ARMED, ON) and the cabin's switch (door 1L). Lit by the cabin's
-- switch, by ON, or ARMED when DC bus 4 fails (ATA33 p.264, p.266; FCOM
-- p.452-453, p.504); >EMER LIGHTS when P5 is not ARMED or the cabin's
-- switch lit them (FCOM p.547; ATA33 p.268). The packs' 15 minutes and
-- more (FCOM p.504) are not modelled
M.EMER_OFF, M.EMER_ARMED, M.EMER_ON = 0, 1, 2
-- sw: P5's position; cabin: the cabin's switch on; dc4: DC bus 4 powered.
-- Returns lit, the >EMER LIGHTS advisory
function M.emer(sw, cabin, dc4)
    local lit = cabin or sw == M.EMER_ON or (sw == M.EMER_ARMED and not dc4)
    return lit, sw ~= M.EMER_ARMED or cabin
end

return M
