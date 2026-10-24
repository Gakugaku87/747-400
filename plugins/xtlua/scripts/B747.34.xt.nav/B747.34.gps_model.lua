-- 747-400 GPS without X-Plane (5-1 step 2): the two GPS/MMRs' power, their
-- first fix and failures, and the messages. Logic and sources:
-- docs/overhaul/notes/ATA-34.md §4.6, §12 (ATA34_2 34-58 p.378-379,
-- p.386, p.411-412; FCOM p.1225, p.1286, p.1429).
--
--   local G = B747_gps_model                -- in XTLua, after dofile
--   local G = dofile(".../B747.34.gps_model.lua")   -- in the tests
--   local s = G.new()
--   local inp = G.inputs()               -- fill it every frame
--   local out = G.update(s, inp, dt)     -- the same table every frame
--   G.fix_now(s, inp)                    -- a start with the GPS working
--
-- GPS 1 L (115V AC standby bus), 2 R (AC bus 2: p.379).

local M = setmetatable({}, {})
B747_gps_model = M

M.L, M.R = 1, 2
M.FIX_S = 75        -- the first fix within 75 s of power-up, initialized by the IRUs' position (p.378)
-- estimates: the GPS/MMR's own memory of its last position initializes it
-- too, so the first fix is always within the 75 s (without any position it
-- "can take up to 10 minutes": p.378, not made)

local function two(v) return {v, v} end

function M.inputs()
    return {
        power = two(true),          -- L: the AC standby bus, R: AC bus 2
        fail = two(false),          -- a GPS/MMR failed
    }
end

function M.new()
    local s = {t = two(0)}
    s.out = {valid = two(false), failed = two(false), msg_l = false, msg_r = false, msg_both = false}
    return s
end

-- a start with the GPS already working (engines running, in the air)
function M.fix_now(s, inp)
    for i = 1, 2 do if inp.power[i] then s.t[i] = M.FIX_S end end
end

function M.update(s, inp, dt)
    local out = s.out
    for i = 1, 2 do
        if inp.power[i] and not inp.fail[i] then s.t[i] = s.t[i] + dt else s.t[i] = 0 end
        out.valid[i] = inp.power[i] and not inp.fail[i] and s.t[i] >= M.FIX_S
        -- no data to the FMCs: unpowered or failed (a first fix on the way is not a fault)
        out.failed[i] = not inp.power[i] or inp.fail[i]
    end
    -- >GPS: both; >GPS LEFT, RIGHT: one (FCOM p.1429)
    out.msg_both = out.failed[1] and out.failed[2]
    out.msg_l = out.failed[1] and not out.msg_both
    out.msg_r = out.failed[2] and not out.msg_both
    return out
end

return M
