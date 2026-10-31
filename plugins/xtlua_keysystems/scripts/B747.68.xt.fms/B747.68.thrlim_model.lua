-- 747-400 FMC thrust limit mode without X-Plane (6-1/6-2 step 9g1;
-- docs/overhaul/notes/ATA-34-61-FMC.md §73, notes/ATA-22-AT.md §4.5-4.6):
-- the reference thrust limit's mode (the A/T's limit and the EICAS's and
-- the CDU's: ATA34_2 p.642) from the THRUST LIM page's selections and the
-- flight's events:
--   on the ground TO (the selected TO, TO 1 or TO 2: ATA34_2 p.535), the
--   climb's rating armed with it (by the takeoff's thrust reduction: under
--   5 % CLB, under 15 % CLB 1, else CLB 2, unless the crew chose one: FCOM
--   p.1273, p.1316);
--   the armed climb at the thrust reduction point (THR REDUCTION: flaps 5 or
--   a height above the airport) with VNAV engaged (FCOM p.667; FMSPG
--   p.105, p.111), or by the THR switch above 400 ft with VNAV or FLCH
--   (FCOM p.642); a TO/GA push before it: the takeoff's derate removed
--   (FCOM p.667);
--   with VNAV the FMC's phase's as it changes: CLB, at the T/C CRZ (CLB or
--   CRZ as set by maintenance: CRZ here, ATA34_2 p.536's PERF FACTORS,
--   FCOM p.1273); FLCH to a higher altitude from CRZ CLB (FCOM p.646);
--   GA in the air with the flaps extended out of UP, at the landing flaps or
--   with G/S captured, held at the landing flaps or with G/S (FCOM p.672);
--   from GA the THR switch CLB (CON if CON was selected: FCOM p.642), VNAV
--   the FMC's phase's;
--   the THRUST LIM page's selections in the air (GA, CON, CRZ, CLB, CLB 1,
--   CLB 2: FCOM p.1316, p.1339) over the automatic ones until the next;
--   (step 9h3) with an engine inoperative: failed in TO, the planned
--   thrust reduction inhibited and, with VNAV and the flaps up, CON at
--   VREF + 98 (FCOM p.1266, p.1272; failed above the reduction, the climb's
--   kept); the THR switch after takeoff and after GA CON (p.642); FLCH
--   pushed to a higher altitude CON (p.646); CON kept through VNAV's phase
--   changes (estimate; p.1268: the engine-out cruise stays in CON).
-- Not here: D-TO (the assumed temperature: step 9g3), the engine-out
-- VNAV's CON (ENG OUT> executed: step 9h4).
--
--   local L = B747_thrlim_model
--   local s = L.new()
--   L.select_to(s, n, pct)             -- on the ground: TO, TO 1, TO 2
--   L.select_clb(s, n, ground)         -- CLB, CLB 1, CLB 2
--   L.select(s, kind)                  -- in the air: "GA", "CON", "CRZ"
--   local mode = L.update(s, inp)      -- "TO", "TO 1", ..., "CLB 2", "CRZ", "CON", "GA"

local M = setmetatable({}, {})
B747_thrlim_model = M

-- the flap handle's ratio at flaps 5 and at the landing flaps (25: X-Plane's
-- detents 0, 1, 5, 10, 20, 25, 30 at sixths); the THR switch from 400 ft
-- (FCOM p.641)
M.FLAPS5, M.FLAPS_LAND = 2 / 6, 5 / 6
M.THR_RA = 400
-- (step 9h3) the engine-out takeoff's CON at VREF + EO_CON_ADD (FCOM p.1266)
M.EO_CON_ADD = 98
local TO_LABEL, CLB_LABEL = {"TO", "TO 1", "TO 2"}, {"CLB", "CLB 1", "CLB 2"}

function M.new()
    return {mode = "TO",                -- the active: "TO", "CLB", "CRZ", "CON", "GA"
        to = 0, clb = 0,                -- the takeoff's and the climb's ratings (0, 1, 2)
        clb_manual = false,             -- the climb's chosen on the ground
        con = false,                    -- CON selected (the THR switch after GA)
        d = false,                      -- (step 9g3) the assumed temperature's D- on TO
        no_sel = false,                 -- the assumed temperature removed (a TO/GA push)
        locked = false,                 -- GA held (the landing flaps, G/S)
        eo_to = false,                  -- (step 9h3) an engine failed in TO
        flaps_prev = nil, phase_prev = nil, vnav_prev = false, flch_prev = false}
end

-- the mode's text
function M.label(s)
    if s.mode == "TO" then return (s.d and "D-" or "") .. TO_LABEL[s.to + 1] end
    if s.mode == "CLB" then return CLB_LABEL[s.clb + 1] end
    return s.mode
end

-- the climb's rating for a takeoff thrust reduction of pct %
function M.auto_clb(pct)
    if (pct or 0) < 5 then return 0 end
    if pct < 15 then return 1 end
    return 2
end

-- TO, TO 1 or TO 2 (n 0 to 2) of pct % reduction, on the ground only
-- (FCOM p.1315): the climb's armed with it unless the crew chose one
function M.select_to(s, n, pct, ground)
    if not ground then return false end
    s.to = n
    if not s.clb_manual then s.clb = M.auto_clb(pct) end
    return true
end

-- CLB, CLB 1 or CLB 2: on the ground or while the takeoff's limit is
-- active armed (over the automatic one: ATA34_2 p.536, step 9g2), else
-- active (FCOM p.1316, p.1339); not while GA is held
function M.select_clb(s, n, ground)
    if ground or s.mode == "TO" then
        s.clb, s.clb_manual = n, true
        return true
    end
    if s.locked then return false end
    s.clb, s.mode, s.con = n, "CLB", false
    return true
end

-- GA, CON or CRZ in the air (FCOM p.1339-1340)
function M.select(s, kind)
    if s.locked and kind ~= "GA" then return false end
    s.mode, s.con = kind, kind == "CON"
    return true
end

-- inp:
--   ground       on the ground
--   alt_agl      the altitude above the takeoff airport (ft)
--   thr_red      THR REDUCTION: 5 (flaps 5) or the height (ft)
--   flaps        the flap handle's ratio (0 UP to 1)
--   gs           G/S captured; pitch the AFDS's pitch mode ("VNAV",
--                "FLCH", ...); vnav VNAV engaged; phase the FMC's ("CLB",
--                "CRZ", "DES")
--   flch_up      FLCH to an MCP altitude above the airplane
--   thr, toga    the THR switch, a TO/GA switch pushed since the last update
--   ra           the radio altitude (ft)
--   sel_up       (step 9g3) an assumed temperature above the OAT (FCOM p.1273)
--   to_red       the takeoff's thrust reduction (%: the EEC's) or nil
--   eo           (step 9h3) the engines inoperative (their number)
--   ias, vref    the airspeed and VREF 30 (kt)
--   eo_vnav      (step 9h4a) the engine-out VNAV active (ENG OUT executed:
--                CON kept as with an engine inoperative; not in TO)
-- returns the mode's text
function M.update(s, inp)
    local flaps = inp.flaps or 0
    local landing = flaps >= M.FLAPS_LAND - 0.01
    local eo = (inp.eo or 0) >= 1 or (s.mode ~= "TO" and inp.eo_vnav == true)
    local flchPush = inp.flch_up and not s.flch_prev
    s.flch_prev = inp.flch_up and true or false
    if inp.ground then
        -- on the ground TO, the selections kept (ATA34_2 p.535); the climb's
        -- by the takeoff's whole reduction unless chosen (FCOM p.1273)
        s.mode, s.locked, s.con, s.no_sel, s.eo_to = "TO", false, false, false, false
        s.flaps_prev, s.phase_prev, s.vnav_prev = flaps, inp.phase, inp.vnav
        if not s.clb_manual and inp.to_red then s.clb = M.auto_clb(inp.to_red) end
        s.d = inp.sel_up == true
        return M.label(s)
    end
    s.d = inp.sel_up == true and not s.no_sel
    -- an air start (no takeoff before): the climb's (estimate)
    if s.flaps_prev == nil then s.mode = "CLB" end
    local extended = s.flaps_prev ~= nil and s.flaps_prev <= 0.01 and flaps > 0.01
    s.flaps_prev = flaps
    -- VNAV's phase as it changes or as VNAV engages (FCOM p.1272)
    local byPhase = nil
    if inp.vnav and (not s.vnav_prev or inp.phase ~= s.phase_prev) then
        if inp.phase == "CLB" then byPhase = "CLB" elseif inp.phase == "CRZ" then byPhase = "CRZ" end
    end
    s.phase_prev, s.vnav_prev = inp.phase, inp.vnav
    local thr = inp.thr and (inp.ra or 0) > M.THR_RA
    if s.mode == "TO" then
        -- a TO/GA push before the climb's: the takeoff's derate and assumed
        -- temperature gone (FCOM p.667)
        if inp.toga then s.to, s.no_sel, s.d = 0, true, false end
        -- (step 9h3) an engine failed in TO: the planned reduction
        -- inhibited; CON with VNAV, the flaps up, at VREF + 98, or by the
        -- THR switch (FCOM p.642, p.1266, p.1272)
        if eo then s.eo_to = true end
        local thrSw = thr and (inp.pitch == "VNAV" or inp.pitch == "FLCH")
        if s.eo_to then
            local fast = inp.ias and inp.vref and inp.vref > 0 and inp.ias >= inp.vref + M.EO_CON_ADD
            if (inp.vnav and flaps <= 0.01 and fast) or thrSw then s.mode, s.con = "CON", true end
            return M.label(s)
        end
        local red = inp.thr_red or 5
        local atRed = (red == 5 and flaps <= M.FLAPS5 + 0.01) or (red >= 400 and (inp.alt_agl or 0) >= red)
        if (inp.vnav and atRed) or thrSw then s.mode = "CLB" end
        return M.label(s)
    end
    -- GA: the flaps extended out of UP, at the landing flaps or G/S (held
    -- there: FCOM p.672)
    s.locked = landing or inp.gs == true
    if extended or s.locked then s.mode = "GA" end
    if s.mode == "GA" then
        if not s.locked then
            if thr then
                -- (step 9h3) CON also with an engine inoperative (FCOM p.642)
                s.mode = (s.con or eo) and "CON" or "CLB"
            elseif byPhase then
                s.mode = byPhase
            end
        end
        return M.label(s)
    end
    if byPhase then
        -- (step 9h3) with an engine inoperative CON stays (estimate)
        if not (eo and s.mode == "CON") then s.mode, s.con = byPhase, false end
    elseif eo and flchPush then
        -- (step 9h3) FLCH pushed to a higher altitude with an engine
        -- inoperative: CON (FCOM p.646)
        s.mode, s.con = "CON", true
    elseif s.mode == "CRZ" and inp.flch_up and not eo then
        s.mode = "CLB"
    end
    return M.label(s)
end

return M
