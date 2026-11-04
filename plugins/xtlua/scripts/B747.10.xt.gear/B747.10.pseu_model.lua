-- 747-400 air/ground sensing (PSEU, ATA 32-09) without X-Plane: the primary
-- and alternate air and ground signals from the main gear truck tilt, the
-- nose gear compression, and the discretes the PSEU gives other systems.
-- Logic and sources: docs/overhaul/notes/ATA-32.md §2.3, §4.1, §6.1
-- (Boeing ATA 29/32 training manual "ATA29_32", PDF pages).
--
--   local P = B747_pseu_model             -- in XTLua, after dofile
--   local P = dofile(".../B747.10.pseu_model.lua")   -- in the tests
--   local inp = P.inputs()               -- fill it every frame
--   local out = P.update(inp)

local M = setmetatable({}, {})
B747_pseu_model = M

-- Main gears in the order of the formula: left wing, left body, right body,
-- right wing.
M.LWG, M.LBG, M.RBG, M.RWG = 1, 2, 3, 4
M.TILT_DEG = 4.0           -- estimate: a truck tilted more than this is "tilted". X-Plane's
                           -- truck angle (eagle_claw_angle_deg) is against the fuselage: in
                           -- the air the acf's 8 deg (body) and 58 deg (wing); on the ground
                           -- the airplane's nose-down pitch, 0.85 deg parked and 1.75 deg in
                           -- hard braking (measured 2026-10-24), negative nose up
M.HYD_HIGH_PSI = 1500      -- estimate: HYDIM 1/4 pressure high (no figure in the sources)
M.DOWN_LOCKED = 0.99       -- gear extension ratio taken as down and locked
M.DISAGREE_S = 10          -- (2026-11-04) STATUS A/G DISAGREE: 10 s (ATA29_32 p.338)

function M.inputs()
    return {
        tilt_deg = {0, 0, 0, 0},       -- truck angle of LWG, LBG, RBG, RWG
        down = {1, 1, 1, 1},           -- extension ratio of LWG, LBG, RBG, RWG
        nose_down = 1,                 -- nose gear extension ratio
        nose_on_ground = true,         -- nose strut compressed (estimate: the wheel on the ground)
        hyd_psi = {0, 0, 0, 0},        -- hydraulic system 1-4 pressure
        body_steering_locked = true,   -- body gear steering actuators locked (centred)
        -- (2026-11-04) failure: the primary, alternate landing gear
        -- subsystem failed to the air position (notes/ATA-32.md §17)
        failed_air = {false, false},
        power = true,                  -- battery bus, AC bus 2 and 4 (A/G DISAGREE's inhibit)
    }
end

-- (2026-11-04) the state for the messages' time delay (optional: without
-- it M.update gives the outputs and AIR/GND SYSTEM only)
function M.new()
    return {disagree_t = 0}
end

-- One evaluation of the formula of ATA29_32 p.322 (figure p.323), for one
-- subsystem (primary and alternate are the same without failures):
--   AIR = (LWG tilted and LBG tilted) or (RWG tilted and RBG tilted)
--   GND = [(LWG level and H4 high) or (LBG down and LBG level and H1 high)]
--     and [(RWG level and H4 high) or (RBG down and RBG level and H1 high)]
--     or [(H1 low or H4 low) and nose gear compressed]
-- One main gear side on the ground leaves AIR set; both sides make GND.
local function subsystem(inp)
    local tilted, level, body_down = {}, {}, {}
    for i = 1, 4 do
        tilted[i] = inp.tilt_deg[i] > M.TILT_DEG
        level[i] = not tilted[i]
        body_down[i] = inp.down[i] >= M.DOWN_LOCKED
    end
    local h1 = inp.hyd_psi[1] >= M.HYD_HIGH_PSI
    local h4 = inp.hyd_psi[4] >= M.HYD_HIGH_PSI
    local air = (tilted[M.LWG] and tilted[M.LBG]) or (tilted[M.RWG] and tilted[M.RBG])
    local left = (level[M.LWG] and h4) or (body_down[M.LBG] and level[M.LBG] and h1)
    local right = (level[M.RWG] and h4) or (body_down[M.RBG] and level[M.RBG] and h1)
    local gnd = (left and right) or ((not h1 or not h4) and inp.nose_on_ground)
    local all_tilted = tilted[1] and tilted[2] and tilted[3] and tilted[4]
    return air, gnd, all_tilted
end

function M.update(inp, s, dt)
    local air, gnd, all_tilted = subsystem(inp)
    local all_down = inp.nose_down >= M.DOWN_LOCKED
    for i = 1, 4 do
        if inp.down[i] < M.DOWN_LOCKED then all_down = false end
    end
    -- (2026-11-04) a subsystem failed to the air position gives air whatever
    -- its sensors say: on the ground the systems it drives work as in
    -- flight (QRH 14.1: no reversers, no auto speedbrakes, no autobrakes
    -- with both)
    local pri_air, pri_gnd, alt_air, alt_gnd = air, gnd, air, gnd
    local f = inp.failed_air
    if f[1] then pri_air, pri_gnd = true, false end
    if f[2] then alt_air, alt_gnd = true, false end
    local out = {
        pri_air = pri_air, pri_gnd = pri_gnd,
        alt_air = alt_air, alt_gnd = alt_gnd,
        ng_compressed = inp.nose_on_ground,        -- separate output, ATA29_32 p.310, p.320
        all_gear_down = all_down,                  -- ALL GR DN to the warning (CONFIG GEAR), p.320
        nose_not_down = inp.nose_down < M.DOWN_LOCKED,
        -- LG LVR UNLK: all four trucks tilted and the body gear steering locked
        -- (FCOM p.1512, ATA29_32 p.224-225)
        lever_unlock = all_tilted and inp.body_steering_locked,
        -- (2026-11-04) AIR/GND SYSTEM: a subsystem failed to air (FCOM
        -- p.1521), found by the PSEU's monitors on the ground and in flight
        -- (estimate: either subsystem, at once; ATA29_32 p.325-328)
        air_gnd_alert = f[1] or f[2],
        ag_disagree = false,
    }
    -- STATUS A/G DISAGREE: the primary and alternate outputs disagree for
    -- 10 s; not without the battery bus or AC bus 2 or 4 (ATA29_32 p.338,
    -- p.341)
    if s then
        if pri_air ~= alt_air or pri_gnd ~= alt_gnd then s.disagree_t = s.disagree_t + dt else s.disagree_t = 0 end
        out.ag_disagree = s.disagree_t >= M.DISAGREE_S and inp.power
    end
    return out
end

return M
