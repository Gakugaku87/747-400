-- 747-400 thrust reversers without X-Plane: whether each reverser may move
-- (its power and its air/ground relay), and the ENG n REVERSER message.
-- X-Plane moves the reverser (prop mode 3 deploys it, 1 stows it) as the
-- reverse levers and commands ask; this decides when it can. Logic and
-- sources: docs/overhaul/notes/ATA-70-80.md §4.8 (FCOM p.893-894, p.901;
-- ATA70_80 p.442-475 for the CF6; ATA29_32 p.299 for the relays).
-- B747.40.xt.reverser.lua feeds it after the reverse lever logic.
--
--   local R = B747_reverser_model
--   local s = R.new()
--   local inp = R.inputs()                 -- fill it every frame
--   local out = R.update(s, inp, dt)       -- the same table every frame

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
-- (a bare table would be copied there before the functions are added)
local M = setmetatable({}, {})
B747_reverser_model = M

-- the power (FCOM p.893): GE (570) pneumatic, from its own engine's bleed
-- air, so not while that engine is stopped; P&W (109, 405) hydraulic, from
-- the related system (engine n, system n), so not without its pressure (the
-- hydraulic model's level at which a load has power, estimate). RR as P&W
-- (no source).
M.HYD_PSI = 1000
-- only on the ground: TR 1 and 4 on the PSEU's primary ground relays, TR 2
-- and 3 on the alternate (ATA29_32 p.299)
M.PRIMARY = {true, false, false, true}
-- ENG n REVERSER (FCOM p.901: a fault in the reverser system): the reverser
-- has not left its end the way it is asked to go for FAULT_S (the CF6's DPV
-- pressure against the command for 2 s, ATA70_80 p.473-475; P&W estimate),
-- or X-Plane fails it
M.FAULT_S = 2
-- an unpowered reverser stays where it is: deployed past this, else stowed
-- (estimate)
M.HELD_OUT = 0.5

local function four(v) return {v, v, v, v} end

function M.inputs()
    return {
        type = "PW",                        -- "PW", "GE" or "RR"
        want = four(false),                 -- the reverse lever logic puts the engine in reverse (X-Plane's prop mode 3)
        asked = four(false),                -- the levers or commands ask for reverse (also while it is kept in)
        position = four(0),                 -- X-Plane's reverser deploy ratio, 0 stowed to 1 deployed
        pri_gnd = true, alt_gnd = true,     -- PSEU ground relays
        hyd_psi = four(3000),               -- hydraulic systems 1-4
        running = four(true),               -- the engines run
        xp_fail = four(false),              -- X-Plane's reverser failure
    }
end

function M.new()
    local s = {t = four(0)}
    s.out = {reverse = four(false), powered = four(true), can_deploy = four(true), message = four(false)}
    return s
end

function M.update(s, inp, dt)
    local out = s.out
    for n = 1, 4 do
        local ground = inp.alt_gnd
        if M.PRIMARY[n] then ground = inp.pri_gnd end
        local powered
        if inp.type == "GE" then powered = inp.running[n]
        else powered = inp.hyd_psi[n] >= M.HYD_PSI end
        local want = inp.want[n] and ground
        local reverse = want
        if not powered then reverse = inp.position[n] > M.HELD_OUT end
        out.reverse[n], out.powered[n], out.can_deploy[n] = reverse, powered, powered and ground
        -- asked out and still locked in, or not in reverse and still fully out
        local asked = (inp.asked[n] or inp.want[n]) and ground
        local stuck = (asked and inp.position[n] < 0.01) or (not want and inp.position[n] > 0.99)
        if stuck then s.t[n] = s.t[n] + dt else s.t[n] = 0 end
        out.message[n] = s.t[n] >= M.FAULT_S or inp.xp_fail[n]
    end
    return out
end

return M
