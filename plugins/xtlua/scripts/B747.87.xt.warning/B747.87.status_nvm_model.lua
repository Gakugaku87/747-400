-- 747-400 EICAS STATUS messages and the EIUs' non-volatile memory (NVM),
-- without X-Plane. Logic and sources: docs/overhaul/notes/ATA-31-warning.md
-- §13.
--
-- A STATUS message is either not latchable (shown while its condition is
-- there) or latchable, of one of three classes (LH_MAN p.52, p.78):
--   NVM    latches whether it occurs in the air or on the ground
--   NVM-A  latches only if it occurs in the air
--   NVM-G  latches only if it occurs on the ground
-- A latched message stays after its condition goes, through the EIUs'
-- power loss, until the CMC's ERASE (LH_MAN p.52, p.78; LH24 p.64-65).
-- ERASE also hides the occurrence still there until its condition goes
-- (LH24 p.64: DRIVE DISC erases with the IDG not reset; estimate for the
-- others). The newest shown message is listed first, latched or not
-- (LH_MAN p.52): M.update gives the shown ones oldest first.
--
--   local N = B747_status_nvm_model             -- in XTLua, after dofile
--   local N = dofile(".../B747.87.status_nvm_model.lua")   -- in the tests
--   local nvm = N.new()
--   local shown = N.update(nvm, msgs, active, on_ground)
--       msgs: {{name = "...", latch = "NVM"|"NVM-A"|"NVM-G"|nil}, ...}
--       active: {true|false, ...}, the conditions raised now, as msgs
--       shown: the names to list, oldest first (a table reused each call)
--   N.state(nvm, name)   0 not shown, 1 shown and not latched, 2 latched
--   N.erase(nvm, name)   the CMC's ERASE
--   N.power_off(nvm)     the EIUs stop: what is not in the NVM goes

local M = setmetatable({}, {})
B747_status_nvm_model = M

M.NOT_SHOWN, M.SHOWN, M.LATCHED = 0, 1, 2

-- whether a message of a class latches in this phase (LH_MAN p.78)
function M.latches(class, on_ground)
    if class == "NVM" then return true end
    if class == "NVM-A" then return not on_ground end
    if class == "NVM-G" then return on_ground == true end
    return false
end

function M.new()
    local nvm = {
        -- name -> {latched, erased (this occurrence was erased), seq (the
        -- order it was shown in; 0 not shown)}
        rec = {},
        seq = 0,
        shown = {},
    }
    -- the list's order, made once (no garbage each update)
    nvm.order = function(a, b) return nvm.rec[a].seq < nvm.rec[b].seq end
    return nvm
end

function M.update(nvm, msgs, active, on_ground)
    local shown = nvm.shown
    for i = #shown, 1, -1 do shown[i] = nil end
    for i = 1, #msgs do
        local m, cond = msgs[i], active[i] == true
        local r = nvm.rec[m.name]
        if cond or r then
            if not r then
                r = {latched = false, erased = false, seq = 0}
                nvm.rec[m.name] = r
            end
            if not cond then r.erased = false end
            if cond and not r.erased and M.latches(m.latch, on_ground) then r.latched = true end
            if r.latched or (cond and not r.erased) then
                if r.seq == 0 then
                    nvm.seq = nvm.seq + 1
                    r.seq = nvm.seq
                end
                shown[#shown + 1] = m.name
            elseif not r.erased then
                nvm.rec[m.name] = nil
            else
                r.seq = 0
            end
        end
    end
    table.sort(shown, nvm.order)
    return shown
end

function M.state(nvm, name)
    local r = nvm.rec[name]
    if not r or r.seq == 0 then return M.NOT_SHOWN end
    if r.latched then return M.LATCHED end
    return M.SHOWN
end

-- ERASE: the latch goes; the occurrence still there stays hidden until its
-- condition goes (LH24 p.64). Takes effect at the next update.
function M.erase(nvm, name)
    local r = nvm.rec[name]
    if not r then return end
    r.latched, r.erased, r.seq = false, true, 0
end

-- the EIUs lose their power: the latched messages and the erasures stay
-- (non-volatile; the erasures: estimate), the rest is seen anew
function M.power_off(nvm)
    for name, r in pairs(nvm.rec) do
        if not r.latched and not r.erased then nvm.rec[name] = nil end
    end
end

return M
