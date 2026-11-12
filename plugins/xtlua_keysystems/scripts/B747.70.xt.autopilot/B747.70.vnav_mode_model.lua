-- VNAV's engagement and sub-modes (6-1/6-2 step 9i; docs/overhaul/notes/
-- ATA-34-61-FMC.md §150): what VNAV SPD, VNAV PTH and VNAV ALT the AFDS
-- shows and flies from the FMC's vertical guidance (B747.68.vnav_model.lua:
-- laminar/B747/fms/vnav/*) and the MCP altitude. Before (step 9a to 9e),
-- the autopilot's glue held these as afds_vnav_level and
-- afds_old_vnav_fma, VNAV ended into ALT HOLD when the FMC's data went
-- invalid and its arm was cancelled without it.
--  - The engage (ATA34_2 p.621, ATA22 p.340-341, FCOM p.645): VNAV armed
--    engages on FMC DATA VALID: the FMC's VNAV valid (its VNAV CONTROL: the
--    performance data entered, an active route, a path in the descent),
--    the master FMC working, and above 400 ft (FCOM p.645: "400 feet above
--    runway elevation"; the radio altitude here, as before: estimate). The
--    arm waits for it (it is not cancelled without the data: ATA22 p.340);
--    engaged, the latch holds until a new pitch mode (the AFDS model's).
--    PERF/VNAV UNAVAILABLE (FCOM p.645, p.1433) when a push arms VNAV
--    without the gross weight, the cost index or CRZ ALT, or in the
--    descent without a path (`unavailable`).
--  - Following the FMC (ATA22 p.279-280, ATA34_2 p.615-616): its VNAV SPD
--    on the speed law (FLCH's), its VNAV PTH on the V/S law (the descent's
--    path, the cruise descent) or the ALT law (the cruise, a level the FMC
--    holds), its A/T mode.
--  - The MCP altitude's new levels (VNAV ALT, its capture) only with it
--    settled (`inp.settled`, the glue's: the window unchanged a while or the
--    altitude selector pushed; the values the knob passes are not VNAV's:
--    B747.70.xt.autopilot.lua's afds_vnav_mcp_settled).
--  - The levels, each held until its own end, the A/T on SPD in all
--    (FCOM p.645: VNAV PTH and VNAV ALT with SPD):
--    "fmc" VNAV PTH at the FMC altitude, captured from VNAV SPD or the
--      cruise descent before the MCP altitude (ATA22 p.280: VNAV SPD
--      changes to VNAV PTH to capture the FMC altitude), the MCP's too when
--      they are the same (FCOM p.1256: VNAV ALT is for an MCP altitude not
--      in the FMC); over once the FMC altitude moves on, or at the T/D held
--      by the MCP altitude (below);
--    "mcp" VNAV ALT at the MCP altitude, captured before the FMC altitude
--      (ATA22 p.280), or here when the FMC's profile would leave it
--      (ATA22 p.280, p.338; ATA34_2 p.624; FMSPG p.34 (2-22): a climb or
--      descent to begin with the MCP at the present altitude, the T/D among
--      them); an MCP altitude behind the FMC's way is not gone back to more
--      than CAP_NEAR_FT: held where the airplane is (estimate, as "hold");
--    "hold" VNAV ALT at the altitude then, the MCP altitude behind the
--      FMC's way, more than AT_MCP_FT off (estimate: FCOM p.665, a conflict
--      levels the airplane in VNAV ALT, it maintains altitude, though p.645
--      has VNAV ALT keep the MCP altitude; FMSPG p.226-227 (4-15, 4-16),
--      the holding pattern's guidance: in the climb the FMC does not command
--      a descent, in the descent no climb, and with VNAV engaged beyond the
--      MCP altitude it levels where the airplane is);
--    "far" VNAV PTH at the altitude then, the FMC altitude behind its way:
--      the climb's constraint below the airplane (FMSPG p.128 (3.3-19): a
--      climb constraint entered below the airplane, level until its
--      waypoint), the descent's floor above it (FMSPG p.227 (4-16): below a
--      constraint when VNAV engages, the FMC levels; the FMC gives a floor
--      there, an AT OR BELOW as the lower of it and the path: its
--      des_target); ATA22 p.338's ALT HOLD default; over when the FMC
--      altitude moves on (the waypoint sequenced);
--    "invalid" VNAV PTH at the altitude then while the FMC's data is not
--      valid (estimate: ATA22 p.341's figure gates VNAV ENGAGE to the laws
--      with VNAV VALID, its annunciation latch stays; what the pitch does
--      then the sources do not say; FCOM p.1431's DESCENT PATH DELETED has
--      VNAV active; before, ALT HOLD).
--    VNAV ALT ("mcp", "hold") ends with the selector pushed once the MCP
--    altitude no longer conflicts (FCOM p.645, p.665, p.1256: reset the MCP
--    altitude and push), or, reset under the descent's path, when the path
--    comes down to the airplane (FCOM p.645, p.665; the reset judged when
--    the MCP altitude moves: LF2), or on approach with the MCP altitude
--    POS_APP_FT or more above (FCOM p.1261: VNAV continues to command a
--    descent); it becomes the FMC's VNAV PTH when the FMC holds the same
--    altitude (estimate; the ALT law, or the descent's path level at the
--    FMC altitude: fmc_holds, 2026-11-11 review). On approach an MCP
--    altitude POS_APP_FT or more above does not stop the descent (FCOM
--    p.1261).
--  - In the descent on a level part of the path (the FMC's V/S under
--    DES_FPM: no conflict, no FMC altitude's capture) the MCP altitude is
--    still captured from above (FMSPG p.227 (4-16): in the descent the FMC
--    always captures the MCP altitude descending from above it; steps 9a-9e
--    captured it on any law but ALT's too).
-- Pure: the FMC's guidance, the MCP and the airplane in; the FMA's sub-mode,
-- the law and its target, the A/T mode out. The captures are the AFDS's
-- (B747.70.afds_pitch_model.lua's capture), given as inputs.
--   local V = B747_vnav_mode_model                       -- in XTLua, after dofile
--   local V = dofile(".../B747.70.vnav_mode_model.lua")  -- in the tests
--   local s = V.new()
--   local out = V.update(s, inp)   -- each frame; inp: see update
local M = setmetatable({}, {})
B747_vnav_mode_model = M

-- the FMA's pitch numbers (the init's) and the A/T's SPD (the FMA's)
M.FMA = {SPD = 4, ALT = 5, PTH = 6}
M.AT_SPD = 3
-- the FMC's sub-mode and phase numbers (laminar/B747/fms/vnav/mode, phase)
M.MODE_SPD = 1
M.PHASE_CLB, M.PHASE_CRZ, M.PHASE_DES = 1, 2, 3
-- VNAV engages above ENGAGE_RA ft (FCOM p.645, p.1262)
M.ENGAGE_RA = 400
-- the FMC altitude the MCP's within SAME_FT; a held altitude moved more
-- than MOVED_FT (both as before: step 9a, 9d1)
M.SAME_FT = 50
M.MOVED_FT = 50
-- the airplane at the MCP altitude within AT_MCP_FT: VNAV ALT there, else
-- at the altitude then (estimate: the FMC's CHECK_BAND_FT); the FMC
-- altitude behind by more than FAR_FT (estimate)
M.AT_MCP_FT = 100
M.FAR_FT = 100
-- an MCP altitude behind the FMC's way gone back to within CAP_NEAR_FT
-- (the pitch laws' CAPTURE_NEAR: B747.70.afds_pitch_model.lua), farther
-- held where the airplane is (estimate)
M.CAP_NEAR_FT = 20
-- a descent of the FMC's V/S law: more than DES_FPM down (estimate: the
-- path's level segments ask near 0)
M.DES_FPM = 100
-- on approach the descent goes on with the MCP altitude POS_APP_FT or more
-- above (FCOM p.1261)
M.POS_APP_FT = 300

function M.new()
    return {level = false,   -- the level held ({kind, alt, mcp, tgt, dir, below}) or false
        pushes = false,      -- the selector's pushes counted the update before
        out = {fma = M.FMA.SPD, law = false, law_vs = 0, law_alt = 0, at = 0, level = false, kind = false, way = 0}}
end

-- VNAV's engage from its arm (FMC DATA VALID: ATA22 p.341; ATA34_2 p.621):
-- the FMC's VNAV valid, the master FMC working, in the air above ENGAGE_RA
function M.can_engage(valid, fmc_ok, ground, ra)
    return (valid and fmc_ok and not ground and (ra or 0) > M.ENGAGE_RA) and true or false
end

-- PERF/VNAV UNAVAILABLE for a push that arms VNAV (FCOM p.645, p.1433): the
-- performance data not entered (perf), or the descent without the FMC's
-- guidance (no end of descent: valid false in phase 3)
function M.unavailable(perf, valid, phase)
    return (not perf) or (phase == M.PHASE_DES and not valid)
end

-- the FMC's guidance: the law ("FLCH", "VS", "ALT"), its V/S, its
-- altitude, its way (1 up, -1 down, 0 level) and whether it levels at its
-- altitude (VNAV SPD's climb and descents, the cruise descent: the
-- descent's path goes on through its constraints)
local function guidance(inp)
    local tgt = inp.fmc_alt or inp.alt
    if inp.mode == M.MODE_SPD then
        return "FLCH", 0, tgt, inp.phase == M.PHASE_CLB and 1 or -1, true
    end
    local vs = inp.vs or 0
    if inp.phase == M.PHASE_DES then
        return "VS", vs, tgt, vs < -M.DES_FPM and -1 or 0, false
    end
    if inp.phase == M.PHASE_CRZ and vs ~= 0 then
        return "VS", vs, tgt, vs < 0 and -1 or 1, true
    end
    -- the FMC holding its altitude; past the T/D held by the MCP altitude
    -- its descent would begin (FMSPG p.34 (2-22))
    return "ALT", 0, tgt, inp.td_hold and -1 or 0, false
end

-- on approach in the descent with the MCP altitude POS_APP_FT or more above
-- (the missed approach's: FCOM p.1261, VNAV continues to command a descent)
local function app_above(inp)
    return inp.on_app and inp.phase == M.PHASE_DES and inp.mcp - inp.alt >= M.POS_APP_FT
end

-- the MCP altitude in conflict with the FMC's way (not ahead of it); on
-- approach not POS_APP_FT or more above in a descent (FCOM p.1261)
local function conflict(inp, dir)
    if dir == 0 then return false end
    if dir < 0 and app_above(inp) then return false end
    return (inp.mcp - inp.alt) * dir <= 0
end

-- (2026-11-11 review) the FMC holding the altitude a itself on the descent's
-- path: a level part of it (the V/S law shallower than DES_FPM) at a, the
-- FMC altitude a too (FCTM p.187's VNAV approach: the path level at the
-- FAF's constraint, the MCP set to it, the DA set before the FAF). There the
-- MCP altitude is the FMC's (FCOM p.1256: VNAV ALT is for an MCP altitude
-- not in the FMC): VNAV PTH, over once the FMC altitude moves on (the FAF
-- sequenced: on down with the DA set by then; the MCP left there, VNAV ALT).
-- Before, VNAV ALT, its end wanting the push from over the path: level past
-- the FAF. On a descending part the path goes on through the constraint:
-- the MCP's capture VNAV ALT as before (LF2)
local function fmc_holds(inp, tgt, dir, levels, a)
    return inp.phase == M.PHASE_DES and inp.mode ~= M.MODE_SPD and not levels and dir == 0
        and math.abs(tgt - a) <= M.SAME_FT
        and math.abs(inp.alt - (inp.path_dev or 0) - a) <= M.SAME_FT
end

-- a new level, or false
local function new_level(inp, tgt, dir, levels)
    if not inp.valid then return {kind = "invalid", alt = inp.alt} end
    -- the captures' way: the FMC's, in the descent down on a level part of
    -- its path too (FMSPG p.227 (4-16): the MCP altitude captured from
    -- above; no conflict there, nor the FMC altitude's capture)
    local way = dir
    if way == 0 and inp.phase == M.PHASE_DES then way = -1 end
    if way == 0 then return false end
    -- the MCP altitude's levels only with it settled (the glue's: not the
    -- knob's passing values; nil, as settled)
    local settled = inp.settled ~= false
    local dMcp = (inp.mcp - inp.alt) * way
    -- (2026-11-11 review) the MCP altitude captured where the FMC holds it
    -- itself (fmc_holds: the descent's path level at the FMC altitude, FCTM
    -- p.187's VNAV approach with the MCP at the FAF's): the FMC's level, VNAV
    -- PTH (FCOM p.1256: VNAV ALT is for an MCP altitude not in the FMC)
    if settled and fmc_holds(inp, tgt, dir, levels, inp.mcp)
        and inp.cap_mcp and dMcp >= -M.CAP_NEAR_FT and not app_above(inp) then
        return {kind = "fmc", alt = tgt}
    end
    if settled and dir ~= 0 and conflict(inp, dir) then
        if math.abs(inp.mcp - inp.alt) <= M.AT_MCP_FT then
            -- at the MCP altitude (FCOM p.645: VNAV ALT keeps it), not gone
            -- back against the way more than CAP_NEAR_FT (FMSPG p.226-227:
            -- no descent in the climb, no climb in the descent; estimate)
            return {kind = "mcp", alt = dMcp >= -M.CAP_NEAR_FT and inp.mcp or inp.alt}
        end
        return {kind = "hold", alt = inp.alt}
    end
    local dFmc = (tgt - inp.alt) * dir
    if dir ~= 0 and levels and dFmc < -M.FAR_FT then return {kind = "far", alt = inp.alt, tgt = tgt, dir = dir} end
    local capF = dir ~= 0 and levels and inp.cap_fmc and true or false
    local capM = settled and (not app_above(inp)) and inp.cap_mcp and dMcp >= -M.CAP_NEAR_FT and true or false
    local same = levels and math.abs(tgt - inp.mcp) <= M.SAME_FT
    if capF and capM and not same then
        -- both at once: the nearer on the way first (estimate)
        if dFmc <= dMcp then capM = false else capF = false end
    end
    if capF or (capM and same) then return {kind = "fmc", alt = tgt} end
    if capM then return {kind = "mcp", alt = inp.mcp} end
    return false
end

-- inp (each frame):
--   engaged      VNAV the AFDS's active pitch mode
--   valid        the FMC's VNAV valid (laminar/B747/fms/vnav/valid)
--   phase, mode  the FMC's (1 CLB, 2 CRZ, 3 DES; 1 SPD, 2 PTH)
--   fmc_alt      the FMC altitude (ft); vs the FMC's V/S (fpm, 0 none);
--                at its A/T mode; path_dev ft above its path (the descent)
--   td_hold      past the T/D, the cruise kept by the MCP altitude (the
--                FMC's: B747.68.vnav_model.lua)
--   on_app       the FMC on approach (FCOM p.1261)
--   mcp, alt     the MCP altitude, the airplane's (ft); settled false while
--                the MCP altitude is being set (no new level of it then)
--   pushes       the altitude selector's pushes, counted (a push ends VNAV
--                ALT when the MCP altitude no longer conflicts then)
--   cap_mcp, cap_fmc  the AFDS capturing the MCP altitude, the FMC's
-- out: fma (4 VNAV SPD, 5 VNAV ALT, 6 VNAV PTH), law ("FLCH", "VS",
-- "ALT"), law_vs (fpm), law_alt (ft), at (the A/T mode asked), level (true
-- while levelled: the A/T's SPD), kind (the level's or false), way (the
-- FMC's way while not levelled: 1 up, -1 down, 0 level; 2026-11-12, for
-- VNAV SPD's near-level path: B747.70.afds_pitch_model.lua's `way`)
function M.update(s, inp)
    local out = s.out
    local n = inp.pushes or 0
    local pushed = s.pushes ~= false and n ~= s.pushes
    s.pushes = n
    local law, vs, tgt, dir, levels = guidance(inp)
    local L = s.level
    if not inp.engaged then
        L = false
    elseif L then
        local k = L.kind
        if k == "invalid" then
            if inp.valid then L = false end
        elseif not inp.valid then
            -- (a level holds on while the data is lost)
        elseif k == "fmc" then
            if math.abs(tgt - L.alt) > M.MOVED_FT or inp.td_hold then L = false end
        elseif k == "far" then
            if math.abs(tgt - L.tgt) > M.MOVED_FT or dir ~= L.dir then L = false end
        else
            -- VNAV ALT
            local ok = not conflict(inp, dir)
            if app_above(inp) then
                L = false
            elseif law == "ALT" and dir == 0 and math.abs(tgt - L.alt) <= M.SAME_FT then
                L = false
            elseif fmc_holds(inp, tgt, dir, levels, L.alt) then
                -- (2026-11-11 review) captured on the way down, the path
                -- level at it now: the FMC's (new_level: VNAV PTH)
                L = false
            elseif ok and pushed then
                L = false
            elseif math.abs(inp.mcp - L.mcp) <= M.MOVED_FT then
                L.below = nil
            else
                if L.below == nil then
                    L.below = inp.phase == M.PHASE_DES and (inp.path_dev or 0) < 0
                end
                if L.below and ok and inp.phase == M.PHASE_DES and (inp.path_dev or 0) >= 0 then L = false end
            end
        end
    end
    if inp.engaged and not L then
        L = new_level(inp, tgt, dir, levels)
        if L then L.mcp = inp.mcp end
    end
    s.level = L
    if L then
        out.fma = (L.kind == "mcp" or L.kind == "hold") and M.FMA.ALT or M.FMA.PTH
        out.law, out.law_vs, out.law_alt = "ALT", 0, L.alt
        out.at, out.level, out.kind = M.AT_SPD, true, L.kind
        out.way = 0
    else
        out.fma = inp.mode == M.MODE_SPD and M.FMA.SPD or M.FMA.PTH
        out.law, out.law_vs, out.law_alt = law, vs, tgt
        out.at, out.level, out.kind = inp.at or 0, false, false
        out.way = dir
    end
    return out
end

return M
