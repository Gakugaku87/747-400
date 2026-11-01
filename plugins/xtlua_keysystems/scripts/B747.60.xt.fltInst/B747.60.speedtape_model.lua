-- 747-400 PFD speed tape (5-2 step 3a): the flap maneuvering speed bugs
-- (FCOM PI.10.3, p.972) from the FMC's VREF 25 and 30 (6-1/6-2 step 3d:
-- B747.68.vref_model.lua; before, VREF25 worked out here by the present
-- altitude) and when the minimum maneuvering speed band shows (FCOM
-- p.973). Logic and sources: docs/overhaul/notes/ATA-31.md §13.
--
--   local S = B747_speedtape_model          -- in XTLua, after dofile
--   local S = dofile(".../B747.60.speedtape_model.lua")   -- in the tests
--   local s = S.new()
--   local inp = S.inputs()                  -- fill it every frame
--   local out = S.update(s, inp, dt)        -- the same table every frame

local M = setmetatable({}, {})
B747_speedtape_model = M

-- the flap lever's detents (X-Plane's flap_ratio times 6)
M.UP, M.F1, M.F5, M.F10, M.F20, M.F25, M.F30 = 0, 1, 2, 3, 4, 5, 6
-- the flap maneuver speeds (FCOM PI.10.3): VREF30 plus these for UP to 20;
-- 25 is VREF25 and 30 is VREF30
local VREF30_PLUS = {[0] = 80, 60, 40, 20, 10}
-- the landing flaps selected on the CDU (laminar/B747/airspeed/VrefFlap)
M.LAND_NONE, M.LAND_25, M.LAND_30 = 0, 1, 2
-- "Not displayed above approximately 20,000 feet altitude" (FCOM p.972)
M.BUGS_MAX_FT = 20000

function M.inputs()
    return {
        vref30 = 0,             -- kt: the FMC's VREF 30
        vref25 = 0,             -- kt: the FMC's VREF 25
        alt_ft = 0,             -- altitude (the bugs' 20,000 ft)
        flap_ratio = 0,         -- the flap lever
        land_flap = M.LAND_NONE,
        air = false,            -- the PSEU's air mode
        ias = 0,                -- kt
    }
end
-- on the ground for the minimum maneuvering band only below this airspeed
-- and for this long (estimates): an air start, or the aircraft reloaded in
-- the air, can read ground, and 0 kt, for a moment
M.GROUND_KT = 100
M.GROUND_S = 5

function M.new()
    return {
        takeoff_detent = nil,   -- the lever on the ground before takeoff
        mins = nil,             -- the minimum maneuvering speed band shown (nil: not yet known)
        ground_t = 0,           -- s on the ground below GROUND_KT
        out = {
            vref25 = 0,
            vf = {[0] = 0, 0, 0, 0, 0, 0, 0},       -- each detent's maneuver speed
            show_vf = {[0] = false, false, false, false, false, false, false},
            show_mins = false,
        },
    }
end

function M.update(s, inp, dt)
    local out = s.out
    local d = math.max(M.UP, math.min(M.F30, math.floor(inp.flap_ratio * 6 + 0.5)))
    out.vref25 = inp.vref25
    for k = M.UP, M.F20 do out.vf[k] = inp.vref30 + VREF30_PLUS[k] end
    out.vf[M.F25] = out.vref25
    out.vf[M.F30] = inp.vref30
    -- the bugs for the current flap setting and the next lesser one, not
    -- above about 20,000 ft (FCOM p.972; step 3b); not the selected landing
    -- flap's, which the REF bug shows (the stock panel's rule)
    for k = M.UP, M.F30 do
        local shown = (k == d or k == d - 1) and inp.alt_ft <= M.BUGS_MAX_FT
        if (k == M.F25 and inp.land_flap == M.LAND_25) or (k == M.F30 and inp.land_flap == M.LAND_30) then
            shown = false
        end
        out.show_vf[k] = shown
    end
    -- the minimum maneuvering speed band from the first flap retraction after
    -- takeoff (FCOM p.973); a flight started in the air shows it (estimate).
    -- On the ground only below GROUND_KT for GROUND_S (step 3b: an air start
    -- and a reload in the air read ground for a moment, and the band and
    -- AIRSPEED LOW stayed off)
    local ground = not inp.air and inp.ias < M.GROUND_KT
    s.ground_t = ground and s.ground_t + (dt or 0) or 0
    if s.ground_t >= M.GROUND_S then
        s.mins = false
        s.takeoff_detent = d
    elseif s.takeoff_detent == nil then
        if not ground then s.mins = true end    -- not on the ground yet: started in the air
    elseif inp.air and not s.mins and d < s.takeoff_detent then
        s.mins = true
    end
    out.show_mins = s.mins == true
    return out
end

return M
