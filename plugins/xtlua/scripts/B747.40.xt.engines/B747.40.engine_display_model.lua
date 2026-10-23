-- 747-400 engine indications without X-Plane: the colour of each engine's
-- EGT indication (white, amber, red), the amber inhibit after a TO/GA push
-- and the EGT start limit line; N1, N2 and N3 red at their red lines and the
-- P&W EPR tape red at max EPR; the oil pressure, temperature and quantity
-- with their colours and messages; the vibration and its source. Logic and
-- sources: docs/overhaul/notes/ATA-70-80.md §3.2, §3.4, §4.9-§4.11 (FCOM
-- 7.10, 7.11, 7.20 p.833-838, p.843-850, p.872-873, p.879, p.890, p.901;
-- ATA70_80 p.356-357, p.395, p.522, p.524 for the CF6). The red boxes are
-- B747.40.exceedance_model.lua.
-- B747.40.xt.engine_display.lua feeds it and writes the panel's datarefs.
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

-- Oil limits (FCOM p.846-849, p.901). CF6-80C2: ATA70_80 p.395, p.522.
-- PW4056 and RB211: no source; the previous code's red line (70 psi) and the
-- panel's amber band and red line (160 and 175 °C), no low quantity.
--   press_red: the red line, psi, from min idle to 112 % N2; the CF6's rises
--     from 10 psi to 35 psi (ATA70_80 p.395)
--   press_amber: the CF6's amber band's top, from 15 psid at low idle to
--     34 psid at full power (ATA70_80 p.522; full power taken as 112 % N2,
--     an estimate)
--   switch: the CF6's low oil pressure switch: closes at 10 psid falling and
--     opens at 15 psid rising, ENG n OIL PRESS while closed (ATA70_80 p.522);
--     without it the message is the red line (FCOM p.901)
--   temp_amber: the amber band (ENG n OIL TEMP above it, FCOM p.901), °C
--   qty_low, qty_diff: the CF6's magenta quantities, US quarts: low, and in
--     cruise the lowest engine when it is that far below another (FCOM p.849,
--     p.890)
M.OIL = {
    GE = {press_red = {10, 35}, press_amber = {15, 34}, switch = {10, 15},
        temp_amber = 160, qty_low = 4, qty_diff = 6, quarts = true},
    PW = {press_red = {70, 70}, temp_amber = 160},
    RR = {press_red = {70, 70}, temp_amber = 160},
}
M.OIL_N2_IDLE = 61.6                        -- the CF6's min idle N2, % (ATA70_80 p.206)
M.OIL_N2_TOP = 112
-- Estimates (no source): the indications are X-Plane's oil pressure and
-- temperature, each engine a little apart (up to 1-6 psi and 1-10 °C at
-- 100 % N2, drawn at load). The tank shows 33-37 L with the engine stopped
-- and 7-11 L less once it turns (the oil in the engine; full at 15 % N1);
-- X-Plane's oil quantity ratio scales it. The CF6 shows US quarts (FCOM
-- p.848).
M.OIL_PRESS_SPREAD = {1, 6}
M.OIL_TEMP_SPREAD = {1, 10}
M.OIL_QTY_L = {33, 37}
M.OIL_GULP_L = {7, 11}
M.OIL_GULP_N1 = 15
M.QUARTS_PER_LITRE = 1 / 0.946353
-- Operating limits (red lines) of N1, N2 and N3, % (FCOM p.833-836,
-- p.843-844, p.873): the readout and the tape turn red there. CF6-80C2:
-- ATA70_80 p.395. PW4056 and RB211: no source, the panel's previous values
-- (the RB211's N3 tape 101.5 %; its readout used 111.4 %, P&W's).
M.RPM_RED = {
    GE = {n1 = 117.5, n2 = 112.5},
    PW = {n1 = 111.4, n2 = 111.4},
    RR = {n1 = 111.4, n2 = 109.5, n3 = 101.5},
}
-- The P&W EPR tape turns red when max EPR is reached (FCOM p.834, p.873);
-- the readout stays white (p.833). The EEC holds EPR within 0.002 of max EPR
-- at the forward stop, so red from 0.003 below it and white again 0.01
-- below (estimate). RR as P&W (no source).
M.EPR_RED_BELOW, M.EPR_WHITE_BELOW = 0.003, 0.01
-- Vibration (FCOM p.849-850): the source with the highest vibration and its
-- level; BB, the average, when the source is unknown (nothing here makes it
-- unknown). P&W: N1, N2; CF6: FAN, LPT, N2 (RR as P&W, no source). Estimate:
-- each source's level at 100 % of its rotor is drawn at load between 0.2 and
-- 1.2 units and goes with the square of the rotor speed (the CF6's high band
-- is 4.0 units, ATA70_80 p.395).
M.VIB_SOURCES = {PW = {"N1", "N2"}, GE = {"FAN", "LPT", "N2"}, RR = {"N1", "N2"}}
M.VIB_ROTOR = {N1 = "n1", FAN = "n1", LPT = "n1", N2 = "n2"}
M.VIB_UNITS = {0.2, 1.2}

local function four(v) return {v, v, v, v} end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function draw(range, random) return range[1] + (range[2] - range[1]) * random() end

-- a limit that goes from min idle to 112 % N2 (the CF6's oil pressure)
local function along(lim, n2)
    local f = clamp((n2 - M.OIL_N2_IDLE) / (M.OIL_N2_TOP - M.OIL_N2_IDLE), 0, 1)
    return lim[1] + (lim[2] - lim[1]) * f
end

function M.inputs()
    return {
        type = "PW",                        -- "PW", "GE" or "RR"
        egt = four(0),                      -- the displayed EGT, °C
        cutoff = four(true),                -- FUEL CONTROL at CUTOFF
        starting = four(false),             -- a start under way (the start model's phase is not off)
        running = four(false),              -- the engine runs (for the P&W ten minutes)
        toga = false,                       -- the TO/GA switch was pushed this frame
        n1 = four(0),                       -- the displayed N1, N2 and N3 (RB211), %
        n2 = four(0),
        n3 = four(0),
        epr = four(1),                      -- the displayed EPR and the EEC's max EPR (0: none)
        epr_max = four(0),
        oil_psi = four(0),                  -- X-Plane's oil pressure, psi
        oil_degc = four(15),                -- X-Plane's oil temperature, °C
        oil_ratio = four(1),                -- X-Plane's oil quantity ratio
        cruise = false,                     -- in the air with the flaps up (the CF6's oil differential)
    }
end

-- random: a function giving 0 to 1 (math.random if nil), for each engine's
-- oil and vibration spread
function M.new(random)
    random = random or math.random
    local s = {since_toga = nil}            -- seconds since the last TO/GA push; nil: none yet
    s.press_spread, s.temp_spread, s.qty_l, s.gulp_l = {}, {}, {}, {}
    s.vib_units = {}                        -- [n][source name]: level at 100 % of the rotor
    s.switch = four(true)                   -- the CF6's low oil pressure switch closed
    s.epr_red = four(false)
    for n = 1, 4 do
        s.press_spread[n] = draw(M.OIL_PRESS_SPREAD, random)
        s.temp_spread[n] = draw(M.OIL_TEMP_SPREAD, random)
        s.qty_l[n] = draw(M.OIL_QTY_L, random)
        s.gulp_l[n] = draw(M.OIL_GULP_L, random)
        s.vib_units[n] = {}
        for _, name in ipairs({"N1", "N2", "FAN", "LPT"}) do s.vib_units[n][name] = draw(M.VIB_UNITS, random) end
    end
    s.out = {white = four(true), amber = four(false), red = four(false), start_limit = four(true),
        inhibit = false,
        oil_psi = four(0), oil_red = four(false), oil_amber = four(false), oil_press_msg = four(false),
        oil_degc = four(15), oil_temp_msg = four(false),
        oil_qty = four(0), oil_qty_magenta = four(false),
        vib = four(0), vib_source = four(0),
        n1_red = four(false), n2_red = four(false), n3_red = four(false), epr_red = four(false)}
    return s
end

-- N1, N2 and N3 at their red lines; the P&W EPR tape at max EPR
local function rpm(s, inp, out)
    local lim = M.RPM_RED[inp.type] or M.RPM_RED.PW
    for n = 1, 4 do
        out.n1_red[n] = inp.n1[n] >= lim.n1
        out.n2_red[n] = inp.n2[n] >= lim.n2
        out.n3_red[n] = lim.n3 ~= nil and inp.n3[n] >= lim.n3
        local max = inp.epr_max[n]
        if inp.type == "GE" or max <= 0 then s.epr_red[n] = false
        elseif inp.epr[n] >= max - M.EPR_RED_BELOW then s.epr_red[n] = true
        elseif inp.epr[n] < max - M.EPR_WHITE_BELOW then s.epr_red[n] = false end
        out.epr_red[n] = s.epr_red[n]
    end
end

-- oil pressure, temperature and quantity (FCOM p.846-849, p.890, p.901)
local function oil(s, inp, out)
    local lim = M.OIL[inp.type] or M.OIL.PW
    for n = 1, 4 do
        local n2 = inp.n2[n]
        local f = clamp(n2 / 100, 0, 1)
        local p = math.max(0, inp.oil_psi[n] + s.press_spread[n] * f)
        out.oil_psi[n] = p
        -- white while the engine is shut down and during a start (FCOM p.846)
        local shown = not inp.cutoff[n] and not inp.starting[n]
        out.oil_red[n] = shown and p < along(lim.press_red, n2)
        out.oil_amber[n] = shown and not out.oil_red[n] and lim.press_amber ~= nil
            and p < along(lim.press_amber, n2)
        if lim.switch then
            if p <= lim.switch[1] then s.switch[n] = true
            elseif p >= lim.switch[2] then s.switch[n] = false end
            out.oil_press_msg[n] = s.switch[n]
        else
            out.oil_press_msg[n] = p < along(lim.press_red, n2)
        end
        local t = inp.oil_degc[n] + s.temp_spread[n] * f
        out.oil_degc[n] = t
        out.oil_temp_msg[n] = t > lim.temp_amber
        local litres = (s.qty_l[n] - s.gulp_l[n] * clamp(inp.n1[n] / M.OIL_GULP_N1, 0, 1)) * inp.oil_ratio[n]
        litres = math.max(0, litres)
        if lim.quarts then out.oil_qty[n] = litres * M.QUARTS_PER_LITRE else out.oil_qty[n] = litres end
    end
    -- magenta: low, or in cruise the lowest engine that far below another
    local lo, hi, lowest = math.huge, -math.huge, 1
    for n = 1, 4 do
        if out.oil_qty[n] < lo then lo, lowest = out.oil_qty[n], n end
        hi = math.max(hi, out.oil_qty[n])
    end
    for n = 1, 4 do
        local low = lim.qty_low ~= nil and out.oil_qty[n] <= lim.qty_low
        local diff = lim.qty_diff ~= nil and inp.cruise and n == lowest and hi - lo >= lim.qty_diff
        out.oil_qty_magenta[n] = low or diff
    end
end

-- vibration: the highest source (FCOM p.849-850)
local function vibration(s, inp, out)
    local sources = M.VIB_SOURCES[inp.type] or M.VIB_SOURCES.PW
    for n = 1, 4 do
        local best, which = 0, 0
        for k, name in ipairs(sources) do
            local rotor = clamp(inp[M.VIB_ROTOR[name]][n] / 100, 0, 1.2)
            local v = s.vib_units[n][name] * rotor * rotor
            if v > best then best, which = v, k end
        end
        out.vib[n], out.vib_source[n] = best, which
    end
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
    oil(s, inp, out)
    vibration(s, inp, out)
    rpm(s, inp, out)
    return out
end

return M
