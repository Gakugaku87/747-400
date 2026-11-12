-- The FDR's event recording (2026-11-13; the 2026-11-12 review's FDR, the
-- user's "FDRは欲しい"): one compact sample a second kept for the last
-- PRE_S seconds; at an event, those samples and then one a second for
-- POST_S seconds go to the file (some 9 KB an event), besides the full
-- record every 30 s. The events: a change of an FMA mode (pitch, roll,
-- A/T), the A/P disconnected, a vertical speed changed by VS_STEP_FPM or
-- more within VS_STEP_S, the load factor G_DEV or more off 1, a frame of
-- more than FRAME_S of real time (X-Plane stood still: the jumps after
-- stalls, REVIEW_2026-11-12.md D-1). Each but the frame's counts when it
-- begins (a turn's steady 1.15 g is one event). The thresholds: estimate
-- (ours: what the 2026-11-12 review looked for in recordings).
--   local s = M.new()
--   local lines = M.update(s, inp)   -- every frame; a list of tables to write, or nil
-- inp: t (sim time, s), clock (real time, s), fma {pitch, roll, at}, ap
-- (an A/P engaged), vs (fpm), g (load factor), sample (a function giving
-- the sample: built only when one is due)
local M = setmetatable({}, {})      -- (a table of its own: XTLua makes a plain global table a namespace)
B747_fdr_model = M

M.SAMPLE_S, M.PRE_S, M.POST_S = 1, 20, 60
M.VS_STEP_FPM, M.VS_STEP_S, M.G_DEV, M.FRAME_S = 500, 5, 0.15, 0.25

function M.new()
    return {ring = {}, last_sample_t = nil, burst_until = nil, fma = nil, ap = nil, last_clock = nil,
        g_out = false, vs_out = false, events = 0}
end

local function vs_ago(s, t, ago)
    -- the sample nearest to `ago` seconds before t (the ring is in time order)
    for i = #s.ring, 1, -1 do
        local r = s.ring[i]
        if t - r.t >= ago - 0.5 then return r.vs end
    end
    return nil
end

function M.update(s, inp)
    local out = nil
    local function emit(x)
        out = out or {}
        out[#out + 1] = x
    end
    local why = nil
    if s.fma and (inp.fma[1] ~= s.fma[1] or inp.fma[2] ~= s.fma[2] or inp.fma[3] ~= s.fma[3]) then why = "FMA" end
    if s.ap and not inp.ap then why = "A/P disconnect" end
    local g_out = math.abs((inp.g or 1) - 1) >= M.G_DEV
    if g_out and not s.g_out then why = why or "load factor" end
    s.g_out = g_out
    local before = vs_ago(s, inp.t, M.VS_STEP_S)
    local vs_out = before ~= nil and math.abs((inp.vs or 0) - before) >= M.VS_STEP_FPM
    if vs_out and not s.vs_out then why = why or "vertical speed" end
    s.vs_out = vs_out
    if s.last_clock and inp.clock - s.last_clock > M.FRAME_S then why = why or "long frame" end
    s.fma = {inp.fma[1], inp.fma[2], inp.fma[3]}
    s.ap, s.last_clock = inp.ap, inp.clock
    local in_burst = s.burst_until ~= nil and inp.t <= s.burst_until
    if why then
        s.events = s.events + 1
        local e = {event = why, t = inp.t}
        if not in_burst then
            local pre = {}
            for i, r in ipairs(s.ring) do pre[i] = r end
            e.before = pre
        end
        emit(e)
        s.burst_until = inp.t + M.POST_S
        in_burst = true
    end
    -- one a second by the next one's time (a frame's step does not drift it)
    local back = s.last_sample_t ~= nil and inp.t < s.last_sample_t
    if s.next_sample_t == nil or inp.t >= s.next_sample_t - 1e-6 or back then
        local smp = inp.sample()
        smp.t = smp.t or inp.t
        if s.next_sample_t == nil or back or inp.t - s.next_sample_t > M.SAMPLE_S then
            s.next_sample_t = inp.t + M.SAMPLE_S
        else
            s.next_sample_t = s.next_sample_t + M.SAMPLE_S
        end
        s.last_sample_t = inp.t
        s.ring[#s.ring + 1] = smp
        while #s.ring > 0 and inp.t - s.ring[1].t > M.PRE_S do table.remove(s.ring, 1) end
        if in_burst and not why then emit({sample = smp}) end
    end
    if s.burst_until and inp.t > s.burst_until then s.burst_until = nil end
    return out
end

return M
