-- 747-400 FMC required time of arrival without X-Plane (RTA, the 109's and
-- 405's; 6-1/6-2 step 9h5a; docs/overhaul/notes/ATA-34-61-FMC.md §84): the
-- RTA PROGRESS page's entries (FCOM p.1383-1385; FMSPG p.3.4-52~55). A FIX
-- from the active or modified route makes a modification (boxes for the
-- time), the time (HHMM[.M], A at or after, B at or before) completes it,
-- EXEC makes it active; deleting the FIX or the time ends an active RTA
-- (ECON again) or drops a modification's FIX; ERASE drops the
-- modification; PRIOR RTA> the last active RTA again as a modification;
-- MAX SPD the crew's Mach (.100-.990) or .880. The speed it flies: step
-- 9h5b.
--
--   local R = B747_rta_model
--   local s = R.new()
--   R.enter_fix(s, "DENOH"); R.enter_time(s, R.parse_time("1740.0B"))
--   R.exec(s); R.erase(s); R.prior(s); R.terminate(s)

local M = setmetatable({}, {})
B747_rta_model = M

-- MAX SPD's default (FCOM p.1384)
M.DEFAULT_MAX = 0.880
-- MAX SPD's entries (FCOM p.1384: .100 to .99)
M.MAX_LO, M.MAX_HI = 0.100, 0.990

function M.new()
    return {active = nil,   -- the active RTA {fix, time (minutes of the day, UTC), suffix ("A", "B" or nil)}
        mod = nil,          -- the modification {fix, time (nil: boxes), suffix}
        prior = nil,        -- the last active RTA
        max = nil}          -- MAX SPD: the crew's Mach, or nil (DEFAULT_MAX)
end

local function copy(r) return r and {fix = r.fix, time = r.time, suffix = r.suffix} or nil end

-- the RTA's time from an entry: HHMM, a tenth of a minute optional
-- (.M), then A or B; 0000.0 to 2359.9 (FCOM p.1384). Minutes of the day
-- and the suffix, or nil
function M.parse_time(text)
    local hh, mm, frac, suffix = string.match(text or "", "^(%d%d)(%d%d)(%.?%d?)([AB]?)$")
    if not hh then return nil end
    -- the tenth only as .M ("1740." or "17400" not entries)
    if frac ~= "" and not string.match(frac, "^%.%d$") then return nil end
    hh, mm = tonumber(hh), tonumber(mm)
    if hh > 23 or mm > 59 then return nil end
    local t = hh * 60 + mm + (frac ~= "" and tonumber(string.sub(frac, 2)) / 10 or 0)
    return t, (suffix ~= "" and suffix or nil)
end

-- the time as the page shows it: HHMM.Mz and the suffix
function M.time_text(t, suffix)
    local tenths = math.floor(t * 10 + 0.5)
    local hh, rest = math.floor(tenths / 600), tenths % 600
    return string.format("%02d%02d.%dz%s", hh % 24, math.floor(rest / 10), rest % 10, suffix or "")
end

-- the RTA the page shows: the modification's, else the active one
function M.shown(s) return s.mod or s.active end

-- a FIX entered: a modification with it, boxes for the time (FCOM p.1383)
function M.enter_fix(s, fix)
    s.mod = {fix = fix, time = nil, suffix = nil}
end

-- the time entered: with the shown FIX; false without one
function M.enter_time(s, t, suffix)
    local r = M.shown(s)
    if not r then return false end
    s.mod = {fix = r.fix, time = t, suffix = suffix}
    return true
end

-- the active RTA ended: ECON again (FCOM p.1384), kept as the prior one
function M.terminate(s)
    if s.active then s.prior = copy(s.active) end
    s.active, s.mod = nil, nil
end

-- DELETE on the FIX: an active RTA ended, else the modification dropped
-- (FCOM p.1384)
function M.delete_fix(s)
    if s.active then M.terminate(s) else s.mod = nil end
end

-- DELETE on the time: an active RTA ended; a modification's time back to
-- boxes (FCOM p.1384)
function M.delete_time(s)
    if s.active then
        M.terminate(s)
    elseif s.mod then
        s.mod.time, s.mod.suffix = nil, nil
    end
end

-- the modification complete for EXEC: a FIX and a time
function M.ready(s) return s.mod ~= nil and s.mod.time ~= nil end

-- EXEC: the complete modification active; true when there was one
function M.exec(s)
    if not M.ready(s) then return false end
    s.active, s.mod = s.mod, nil
    return true
end

-- ERASE: the modification dropped; true when there was one
function M.erase(s)
    local had = s.mod ~= nil
    s.mod = nil
    return had
end

-- PRIOR RTA> (FCOM p.1384-1385): shown with no active RTA and a prior one
-- whose FIX is still in the route (in_route(fix)); its FIX and time as a
-- modification
function M.prior_shown(s, in_route)
    return s.active == nil and s.prior ~= nil and in_route(s.prior.fix)
end
function M.prior(s, in_route)
    if not M.prior_shown(s, in_route) then return false end
    s.mod = copy(s.prior)
    return true
end

-- MAX SPD: the crew's Mach, nil for the default
function M.set_max(s, mach) s.max = mach end
function M.max(s) return s.max or M.DEFAULT_MAX end

return M
