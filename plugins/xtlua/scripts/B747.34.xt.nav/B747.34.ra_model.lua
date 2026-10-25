-- 747-400 radio altimeters without X-Plane (5-1 step 4a): the three radio
-- altimeters' power and failures, the radio altitude each PFD shows (its
-- source by the EIU selector's order) and the one the GPWC uses. Logic and
-- sources: docs/overhaul/notes/ATA-34.md §4.8, §14 (ATA34_2 34-33 p.70,
-- p.76, p.88-89, p.95-96; 34-46 p.122; FCOM p.981).
--
--   local R = B747_ra_model                 -- in XTLua, after dofile
--   local R = dofile(".../B747.34.ra_model.lua")    -- in the tests
--   local s = R.new()
--   local inp = R.inputs()                  -- fill it every frame
--   local out = R.update(s, inp)            -- the same table every frame
--
-- RA 1 L (AC bus 3), 2 C (AC bus 1), 3 R (AC bus 2): p.70, p.76.

local M = setmetatable({}, {})
B747_ra_model = M

M.L, M.C, M.R = 1, 2, 3
M.MIN_FT = -20              -- the range is -20 to 2,500 ft (p.95)
M.MAX_FT = 2500             -- above it the return is too weak: no computed data, a blank display (p.96)
M.GPWC_AGREE_FT = 500       -- the GPWC compares the radio altitudes (34-46 p.122)

-- the order each PFD takes the radio altimeters in, by its EIU selector
-- (p.88-89): Captain L and AUTO L-C-R, C C-L-R, R R-L-C; F/O R and AUTO
-- R-C-L, C C-R-L, L L-R-C. The next one takes over when the shown one fails.
M.ORDER = {
    capt = {L = {1, 2, 3}, AUTO = {1, 2, 3}, C = {2, 1, 3}, R = {3, 1, 2}},
    fo   = {R = {3, 2, 1}, AUTO = {3, 2, 1}, C = {2, 3, 1}, L = {1, 3, 2}},
}

local function three(v) return {v, v, v} end

function M.inputs()
    return {
        height = three(0),          -- ft, the height each radio altimeter measures
        power = three(true),        -- L: AC bus 3, C: AC bus 1, R: AC bus 2
        fail = three(false),
        eiu_capt = "AUTO",          -- L, AUTO, C, R
        eiu_fo = "AUTO",
    }
end

-- what one PFD shows: the radio altimeter it takes (nil: none works), its
-- radio altitude, digits shown (it works and is below 2,500 ft) and the
-- amber RA flag (none works: p.96)
local function side() return {src = nil, value = 0, valid = false, show = false, flag = true} end

function M.new()
    local s = {}
    s.out = {
        valid = three(false),       -- the radio altimeter works (data, or no computed data)
        ncd = three(false),         -- above 2,500 ft: no computed data
        value = three(0),           -- ft, not below -20
        capt = side(), fo = side(),
        gpwc = {src = nil, value = 0, valid = false, ncd = false},
    }
    return s
end

local function take(out, order, sd)
    sd.src = nil
    for k = 1, 3 do
        if out.valid[order[k]] then sd.src = order[k]; break end
    end
    if sd.src then
        sd.value, sd.valid, sd.show, sd.flag = out.value[sd.src], true, not out.ncd[sd.src], false
    else
        sd.valid, sd.show, sd.flag = false, false, true
    end
end

local function agree(out, a, b)
    return out.valid[a] and out.valid[b] and math.abs(out.value[a] - out.value[b]) <= M.GPWC_AGREE_FT
end

function M.update(s, inp)
    local out = s.out
    for i = 1, 3 do
        out.valid[i] = inp.power[i] and not inp.fail[i]
        local h = inp.height[i]
        if h < M.MIN_FT then h = M.MIN_FT end
        out.value[i] = h
        out.ncd[i] = h > M.MAX_FT
    end
    take(out, M.ORDER.capt[inp.eiu_capt] or M.ORDER.capt.AUTO, out.capt)
    take(out, M.ORDER.fo[inp.eiu_fo] or M.ORDER.fo.AUTO, out.fo)

    -- the GPWC: L when it agrees with C or R within 500 ft, else C when it
    -- agrees with R, else L (p.122). A failed one agrees with nothing; when
    -- that leaves a failed L, the first one working (estimate: the source
    -- names L, which then gives no data).
    local g = out.gpwc
    if agree(out, 1, 2) or agree(out, 1, 3) then g.src = 1
    elseif agree(out, 2, 3) then g.src = 2
    elseif out.valid[1] then g.src = 1
    elseif out.valid[2] then g.src = 2
    elseif out.valid[3] then g.src = 3
    else g.src = nil end
    if g.src then
        g.value, g.valid, g.ncd = out.value[g.src], true, out.ncd[g.src]
    else
        g.valid, g.ncd = false, false
    end
    return out
end

return M
