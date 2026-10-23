-- 747-400 engine exceedance boxes without X-Plane. The box around a digital
-- engine indication turns red when the parameter reaches its operating limit
-- and stays red as a reminder after the parameter is back in the normal
-- range: the exceedance is stored. CANC turns a box white once its readout
-- is white again; RCL turns the stored ones red again (FCOM p.873; the
-- CF6's EIU: ATA70_80 p.345-346, p.355-356, where the box shows a maximum
-- exceedance stored in the engine exceedance memory). A CF6 N2 above its red
-- line for more than 20 s stays red (ATA70_80 p.345). A new flight clears
-- what is stored (on the aircraft the memory is erased in maintenance).
--
--   local X = B747_exceedance_model
--   local s = X.new()
--   local inp = X.inputs()                 -- fill it every frame
--   local out = X.update(s, inp, dt)       -- the same table every frame

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
-- (a bare table would be copied there before the functions are added)
local M = setmetatable({}, {})
B747_exceedance_model = M

-- the boxed indications that have an operating limit (FCOM p.872-873;
-- fuel flow is boxed but has no limit). N3: the RB211 (no source).
M.PARAMS = {"n1", "egt", "n2", "n3"}
M.N2_HOLD_S = 20                    -- the CF6's N2 stays red after 20 s above its red line

local function four(v) return {v, v, v, v} end

function M.inputs()
    local inp = {
        type = "PW",                -- "PW", "GE" or "RR"
        cancel = 0,                 -- CANC pushes since the last update
        recall = 0,                 -- RCL pushes since the last update
        red = {},                   -- [param][n]: the readout at its limit now (the display model's colour)
    }
    for _, p in ipairs(M.PARAMS) do inp.red[p] = four(false) end
    return inp
end

function M.new()
    local s = {stored = {}, cancelled = {}, n2_over = four(0), n2_held = four(false)}
    s.out = {box_red = {}, red = {}}
    for _, p in ipairs(M.PARAMS) do
        s.stored[p], s.cancelled[p] = four(false), four(false)
        s.out.box_red[p], s.out.red[p] = four(false), four(false)
    end
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    for n = 1, 4 do
        -- the CF6's N2: more than 20 s above the red line keeps it red
        if inp.type == "GE" and inp.red.n2[n] then
            s.n2_over[n] = s.n2_over[n] + dt
            if s.n2_over[n] > M.N2_HOLD_S then s.n2_held[n] = true end
        else
            s.n2_over[n] = 0
        end
    end
    for _, p in ipairs(M.PARAMS) do
        local stored, cancelled = s.stored[p], s.cancelled[p]
        for n = 1, 4 do
            local red = inp.red[p][n] or (p == "n2" and s.n2_held[n])
            out.red[p][n] = red
            if red then stored[n], cancelled[n] = true, false end
            -- CANC: white once the readout is white; RCL: the stored ones red again
            if inp.cancel > 0 and stored[n] and not red then cancelled[n] = true end
            if inp.recall > 0 and stored[n] then cancelled[n] = false end
            out.box_red[p][n] = red or (stored[n] and not cancelled[n])
        end
    end
    return out
end

return M
