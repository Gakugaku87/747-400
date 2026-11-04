-- 747-400 ILS antenna switching without X-Plane (2026-11-04, for the
-- failure window): the localizer and glide slope antenna relays of the three
-- ILS receivers and the EIUs' watch on them: STATUS G/S ANTENNA L, C, R and
-- LOC ANTENNA L, C, R, and the caution ILS ANTENNA for two or more. Logic
-- and sources: docs/overhaul/notes/ATA-34.md §22 (ATA34_1 p.478,
-- p.482-492; FCOM p.1429).
--
--   local A = B747_ils_ant_model           -- in XTLua, after dofile
--   local A = dofile(".../B747.34.ils_ant_model.lua")   -- in the tests
--   local s = A.new()
--   local inp = A.inputs()                 -- fill it every frame
--   local out = A.update(s, inp, dt)       -- the same table every frame

local M = setmetatable({}, {})
B747_ils_ant_model = M

function M.inputs()
    return {
        on_ground = true,
        -- the FCC in approach or localizer mode (the sim has one AFDS for
        -- the three FCCs: the same for each receiver, estimate)
        fcc_app_loc = false,
        nose_down = true,                       -- the nose gear down and locked
        -- failures: the relay of receiver L, C, R does not move
        loc_stuck = {false, false, false},      -- the VOR/LOC antenna relay
        gs_stuck = {false, false, false},       -- the G/S antenna relay
    }
end

function M.new()
    local s = {first = true, loc_vor = {false, false, false}, gs_capture = {false, false, false}}
    s.out = {loc_vor = {false, false, false}, gs_capture = {false, false, false},
        loc_status = {false, false, false}, gs_status = {false, false, false}, ils_antenna = false}
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    -- what each relay is told (ATA34_1 p.482-492): the VOR/LOC relay
    -- actuated (the fin's VOR antenna) in the air with the FCC not in APP
    -- or LOC, relaxed (the nose's localizer antenna) otherwise; the G/S
    -- relay energized (the capture antenna in the nose) with the nose gear
    -- not down and locked, relaxed (the track antenna on the nose gear door)
    -- when it is. A stuck relay stays where it was
    local vor = not inp.on_ground and not inp.fcc_app_loc
    local capture = not inp.nose_down
    local nl, ng = 0, 0
    for n = 1, 3 do
        if s.first or not inp.loc_stuck[n] then s.loc_vor[n] = vor end
        if s.first or not inp.gs_stuck[n] then s.gs_capture[n] = capture end
        out.loc_vor[n], out.gs_capture[n] = s.loc_vor[n], s.gs_capture[n]
        -- the EIUs compare each relay's position discrete with what it
        -- should be (ATA34_1 p.482, p.488). The receiver keeps working on
        -- the other antenna (how much worse is not in the sources: no
        -- effect here, estimate)
        out.loc_status[n] = s.loc_vor[n] ~= vor
        out.gs_status[n] = s.gs_capture[n] ~= capture
        if out.loc_status[n] then nl = nl + 1 end
        if out.gs_status[n] then ng = ng + 1 end
    end
    -- ILS ANTENNA: two or more glide slope, or two or more localizer
    -- antennas not switched (ATA34_1 p.478)
    out.ils_antenna = nl >= 2 or ng >= 2
    s.first = false
    return out
end

return M
