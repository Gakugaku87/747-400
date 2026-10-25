-- 747-400 PFD speed tape (5-2 step 3a): the flap maneuvering speed bugs
-- (FCOM PI.10.3, p.972), VREF25 (FCOM PI.10.2) and when the minimum
-- maneuvering speed band shows (FCOM p.973). Logic and sources:
-- docs/overhaul/notes/ATA-31.md §13.
--
--   local S = B747_speedtape_model          -- in XTLua, after dofile
--   local S = dofile(".../B747.60.speedtape_model.lua")   -- in the tests
--   local s = S.new()
--   local inp = S.inputs()                  -- fill it every frame
--   local out = S.update(s, inp)            -- the same table every frame

local M = setmetatable({}, {})
B747_speedtape_model = M

-- the flap lever's detents (X-Plane's flap_ratio times 6)
M.UP, M.F1, M.F5, M.F10, M.F20, M.F25, M.F30 = 0, 1, 2, 3, 4, 5, 6
-- the flap maneuver speeds (FCOM PI.10.3): VREF30 plus these for UP to 20;
-- 25 is VREF25 and 30 is VREF30
local VREF30_PLUS = {[0] = 80, 60, 40, 20, 10}
-- VREF25 at sea level (FCOM PI.10.2): 1,000 kg, kt
local VREF25 = {{200, 132}, {220, 139}, {240, 146}, {260, 152}, {280, 158}, {300, 164},
    {320, 170}, {340, 176}, {360, 181}, {380, 187}, {400, 192}}
-- "Increase VREF 1 knot/4000 ft above sea level" (FCOM PI.10.2)
M.VREF_FT_PER_KT = 4000
-- the landing flaps selected on the CDU (laminar/B747/airspeed/VrefFlap)
M.LAND_NONE, M.LAND_25, M.LAND_30 = 0, 1, 2

function M.inputs()
    return {
        vref30 = 0,             -- kt: VREF30 for the weight and altitude
        weight_kg = 0,
        alt_ft = 0,             -- pressure altitude
        flap_ratio = 0,         -- the flap lever
        land_flap = M.LAND_NONE,
        air = false,            -- the PSEU's air mode
    }
end

function M.new()
    return {
        takeoff_detent = nil,   -- the lever on the ground before takeoff
        mins = nil,             -- the minimum maneuvering speed band shown (nil: not yet known)
        out = {
            vref25 = 0,
            vf = {[0] = 0, 0, 0, 0, 0, 0, 0},       -- each detent's maneuver speed
            show_vf = {[0] = false, false, false, false, false, false, false},
            show_mins = false,
        },
    }
end

-- VREF25 for a weight (held at the table's ends) and an altitude
function M.vref25(weight_kg, alt_ft)
    local t = weight_kg / 1000
    local v
    if t <= VREF25[1][1] then
        v = VREF25[1][2]
    elseif t >= VREF25[#VREF25][1] then
        v = VREF25[#VREF25][2]
    else
        for i = 2, #VREF25 do
            local a, b = VREF25[i - 1], VREF25[i]
            if t <= b[1] then
                v = a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
                break
            end
        end
    end
    return v + math.max(0, alt_ft) / M.VREF_FT_PER_KT
end

function M.update(s, inp)
    local out = s.out
    local d = math.max(M.UP, math.min(M.F30, math.floor(inp.flap_ratio * 6 + 0.5)))
    out.vref25 = M.vref25(inp.weight_kg, inp.alt_ft)
    for k = M.UP, M.F20 do out.vf[k] = inp.vref30 + VREF30_PLUS[k] end
    out.vf[M.F25] = out.vref25
    out.vf[M.F30] = inp.vref30
    -- the bugs for the current flap setting and the next lesser one (FCOM
    -- p.972); not the selected landing flap's, which the REF bug shows (the
    -- stock panel's rule)
    for k = M.UP, M.F30 do
        local shown = k == d or k == d - 1
        if (k == M.F25 and inp.land_flap == M.LAND_25) or (k == M.F30 and inp.land_flap == M.LAND_30) then
            shown = false
        end
        out.show_vf[k] = shown
    end
    -- the minimum maneuvering speed band from the first flap retraction after
    -- takeoff (FCOM p.973); a flight started in the air shows it (estimate)
    if s.mins == nil then s.mins = inp.air end
    if not inp.air then
        s.mins = false
        s.takeoff_detent = d
    elseif not s.mins and s.takeoff_detent ~= nil and d < s.takeoff_detent then
        s.mins = true
    end
    out.show_mins = s.mins
    return out
end

return M
