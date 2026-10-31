-- 747-400 FMC required time of arrival without X-Plane (RTA, the 109's and
-- 405's; 6-1/6-2 step 9h5a; docs/overhaul/notes/ATA-34-61-FMC.md §84): the
-- RTA PROGRESS page's entries (FCOM p.1383-1385; FMSPG p.3.4-52~55). A FIX
-- from the active or modified route makes a modification (boxes for the
-- time), the time (HHMM[.M], A at or after, B at or before) completes it,
-- EXEC makes it active; deleting the FIX or the time ends an active RTA
-- (ECON again) or drops a modification's FIX; ERASE drops the
-- modification; PRIOR RTA> the last active RTA again as a modification;
-- MAX SPD the crew's Mach (.100-.990) or .880. (Step 9h5b) the cruise
-- Mach for its time (speed).
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

-- (step 9h5b) the time's tolerance (FCOM p.1269: within 30 s) and the
-- cruise Mach for an RTA r. inp: mach (the Mach the predictions flew, nil
-- the base's), base (the cruise's Mach without RTA: ECON, LRC or the
-- crew's), now (minutes of the day), t_fix (s to the FIX), t_cruise (s of
-- that in the cruise at the Mach: only the cruise's speed is RTA's, FCOM
-- p.1383), lo and hi (the Mach's bounds). The new Mach: the cruise's time
-- scaled for the error (a time inversely as the speed: one step a call),
-- A no faster than the base (at or after), B no slower (at or before),
-- within lo and hi; unable: more than the tolerance off with the Mach at
-- the bound it cannot pass, or no cruise left; and the error (minutes,
-- late positive)
M.TOL_MIN = 0.5
function M.speed(r, inp)
    local m = inp.mach or inp.base
    local d = ((inp.now + inp.t_fix / 60) - r.time + 720) % 1440 - 720
    local need = m
    local tc = inp.t_cruise / 60
    if tc > 0 then need = m * tc / math.max(tc - d, 0.1 * tc) end
    if r.suffix == "A" then need = math.min(need, inp.base) end
    if r.suffix == "B" then need = math.max(need, inp.base) end
    local new = math.max(inp.lo, math.min(inp.hi, need))
    local unable = (d > M.TOL_MIN and r.suffix ~= "A" and (tc <= 0 or m >= inp.hi - 1e-4))
        or (d < -M.TOL_MIN and r.suffix ~= "B" and (tc <= 0 or m <= inp.lo + 1e-4))
    return new, unable and true or false, d
end

return M
