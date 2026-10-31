-- 747-400 FMC engine-out mode without X-Plane (6-1/6-2 step 9h4a;
-- docs/overhaul/notes/ATA-34-61-FMC.md §81): ENG OUT> on the VNAV CLB or
-- CRZ page makes a modification with the engine-out data, EXEC makes it
-- active, ALL ENG> a modification back to all engines (on an ENG OUT
-- modification not yet executed: dropped), ERASE drops a modification
-- (FCOM p.1266, p.1341-1342, p.1350-1353; FMSPG p.3.3-6, p.3.4-5). The
-- data are for the engines sensed inoperative, one if none (FMSPG p.3.3-6:
-- a single outboard engine), two at most (the tables); a second failure
-- while active: two (FCOM p.1350: 2E/O). The speeds: in the climb the E/O
-- climb speed (FCOM p.1342) or a crew's; in the cruise E/O LRC, <E/O SPD's
-- minimum drag or a crew's (FCOM p.1352-1353).
--
--   local E = B747_eo_model
--   local s = E.new()
--   E.eng_out(s, sensed); E.all_eng(s); E.exec(s); E.erase(s)
--   E.update(s, sensed)                 -- every frame
--   if E.shown(s) then ... end          -- the pages' engine-out data

local M = setmetatable({}, {})
B747_eo_model = M

function M.new()
    return {active = false,    -- ENG OUT executed
        mod = nil,             -- "ENG OUT" or "ALL ENG" for EXEC
        n = 1, mod_n = 1,      -- the engines inoperative the data are for
        clb = nil,             -- the climb's speed: nil the E/O climb speed, else {cas} or {mach}
        crz = "LRC"}           -- the cruise's: "LRC", "EO" (minimum drag), or {cas} or {mach}
end

local function count(sensed) return math.max(1, math.min(2, sensed or 0)) end

-- ENG OUT> (shown while not active, or with ALL ENG's modification): the
-- modification; false when there is nothing to do
function M.eng_out(s, sensed)
    if s.active and s.mod ~= "ALL ENG" then return false end
    if s.active then s.mod = nil return true end
    s.mod, s.mod_n = "ENG OUT", count(sensed)
    s.clb, s.crz = nil, "LRC"           -- (the MOD page's entries kept by EXEC)
    return true
end

-- ALL ENG> (shown with the engine-out data)
function M.all_eng(s)
    if s.mod == "ENG OUT" and not s.active then s.mod = nil return true end
    if not s.active then return false end
    s.mod = "ALL ENG"
    return true
end

-- EXEC: the modification active; true when there was one ("ENG OUT" or
-- "ALL ENG" second)
function M.exec(s)
    local kind = s.mod
    if kind == "ENG OUT" then
        s.active, s.n = true, s.mod_n
    elseif kind == "ALL ENG" then
        s.active = false
    end
    s.mod = nil
    return kind ~= nil, kind
end

function M.erase(s)
    local had = s.mod ~= nil
    s.mod = nil
    return had
end

-- the pages' engine-out data: active (not to all engines), or ENG OUT's
-- modification
function M.shown(s) return (s.active and s.mod ~= "ALL ENG") or s.mod == "ENG OUT" end

-- the engines inoperative the shown data are for
function M.engines(s) return (s.mod == "ENG OUT") and s.mod_n or s.n end

-- every frame: a second engine failing while active, its data (FCOM p.1350)
function M.update(s, sensed)
    if s.active and (sensed or 0) > s.n then s.n = count(sensed) end
    if s.mod == "ENG OUT" and (sensed or 0) > s.mod_n then s.mod_n = count(sensed) end
end

return M
