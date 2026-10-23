-- 747-400 engine indications without X-Plane: the colour of each engine's
-- EGT indication (white, amber, red), the amber inhibit after a TO/GA push
-- and the EGT start limit line. Logic and sources:
-- docs/overhaul/notes/ATA-70-80.md §3.2, §3.4 and §4.11 (FCOM 7.10, 7.20
-- p.837-838, p.872, p.879; ATA70_80 p.356-357, p.395 for the CF6).
-- B747.40.xt.engine_display.lua feeds it and writes the panel's flags.
--
--   local D = B747_engine_display_model
--   local s = D.new()
--   local inp = D.inputs()                 -- fill it every frame
--   local out = D.update(s, inp, dt)       -- the same table every frame

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
-- (a bare table would be copied there before the functions are added)
local M = setmetatable({}, {})
B747_engine_display_model = M

-- EGT limits, °C (FCOM p.837-838): the start limit (red line while it is
-- shown), the continuous limit (the amber band) and the takeoff limit (the
-- red line). CF6-80C2: ATA70_80 p.395. PW4056 and RB211: no source, the
-- previous code's values (the PW start and takeoff limits are also the start
-- model's).
M.EGT = {
    GE = {start = 750, amber = 925, red = 960},
    PW = {start = 535, amber = 629, red = 654},
    RR = {start = 600, amber = 733, red = 785},
}
-- the indication stays white in the amber band for 5 minutes after the
-- TO/GA switch is pushed; P&W 10 minutes if an engine fails or is shut down
-- (FCOM p.838, p.872). RR as P&W (no source).
M.INHIBIT_S = 300
M.INHIBIT_ENG_OUT_S = 600

local function four(v) return {v, v, v, v} end

function M.inputs()
    return {
        type = "PW",                        -- "PW", "GE" or "RR"
        egt = four(0),                      -- the displayed EGT, °C
        cutoff = four(true),                -- FUEL CONTROL at CUTOFF
        starting = four(false),             -- a start under way (the start model's phase is not off)
        running = four(false),              -- the engine runs (for the P&W ten minutes)
        toga = false,                       -- the TO/GA switch was pushed this frame
    }
end

function M.new()
    local s = {since_toga = nil}            -- seconds since the last TO/GA push; nil: none yet
    s.out = {white = four(true), amber = four(false), red = four(false), start_limit = four(true),
        inhibit = false}
    return s
end

function M.update(s, inp, dt)
    local lim = M.EGT[inp.type] or M.EGT.PW
    if inp.toga then s.since_toga = 0
    elseif s.since_toga then s.since_toga = s.since_toga + dt end
    local engine_out = false
    for n = 1, 4 do engine_out = engine_out or not inp.running[n] end
    local window = M.INHIBIT_S
    if inp.type ~= "GE" and engine_out then window = M.INHIBIT_ENG_OUT_S end
    local out = s.out
    out.inhibit = s.since_toga ~= nil and s.since_toga < window
    for n = 1, 4 do
        -- the start limit line: shown at CUTOFF and until the start has settled
        -- at idle (the CF6 shows it until min idle: ATA70_80 p.356-357)
        out.start_limit[n] = inp.cutoff[n] or inp.starting[n]
        local egt = inp.egt[n]
        local red_at = lim.red
        if out.start_limit[n] then red_at = lim.start end
        out.red[n] = egt >= red_at
        out.amber[n] = not out.red[n] and egt >= lim.amber and not out.inhibit
        out.white[n] = not out.red[n] and not out.amber[n]
    end
    return out
end

return M
