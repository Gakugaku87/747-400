-- The EGT the EICAS shows for the PW4056 and the CF6-80C2 (ENG-33,
-- 2026-11-10), without X-Plane: from one engine's state (burning or not,
-- X-Plane's N2, the shown EPR or N1), the TAT and air/ground. It replaced
-- X-Plane's EGT scaled (P&W x 654/960, GE 1:1) and filtered by a divisor a
-- frame (egt_thermal_profile, B747.42.xt.EEC.lua): X-Plane's EGT tops out
-- near the custom acf's maximum EGT (460 °C), so the P&W showed about 250 °C
-- in the cruise; it peaks higher on a start than on the takeoff, so one scale
-- could not give both (PROGRESS.md, ENG-33); and it spikes (739, 1951, 705 °C
-- in 3 s on a lever advance). The RB211 keeps the previous path (no sources).
-- B747.42.xt.egt.lua feeds it. Two failures of the failure window act here
-- (2026-11-10): HOT START and EGT OVERTEMP (HOT_START_C, EGT_HIGH_*).
--
--   local G = B747_egt_model
--   local s = G.new()                  -- one engine's state
--   local inp = G.inputs()             -- fill it every frame
--   local egt = G.update(s, inp, dt)   -- °C, dt in seconds
--
-- Limits it is checked against (tests/eec/egt_model_test.lua): PW4056 from
-- the EASA TCDS IM.E.050 (PW4000-94) p.9, a web source, not in _ref:
-- takeoff 654 °C (5 min), maximum continuous 629, ground start 535,
-- in-flight start 650. CF6-80C2: ATA70_80 p.395: takeoff 960, continuous
-- 925, start 750. The red line on the panel is its fixed art.

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
-- (a bare table would be copied there before the functions are added)
local M = setmetatable({}, {})
B747_egt_model = M

local K0 = 273.15           -- °C to K
local T_STD = 288.15        -- K, the standard day at sea level

-- theta: the total air temperature (the engine inlet's, °C) over the
-- standard day's
function M.theta(tat)
    return (tat + K0) / T_STD
end

-- Running (burning, N2 at or above IDLE_N2): the corrected EGT C (K), the
-- EGT in kelvin over theta, is a function of the engine's power: the shown
-- EPR (P&W) or the corrected N1, N1 / sqrt(theta) (GE). It goes through the
-- FCOM's primary EICAS figures (all engines in the cruise, and the other
-- engines with one shut down) and a ground idle at ISA sea level; linear
-- between them. Below the idle point it is held (estimate: the in-flight
-- idle's EPR, below 1 at speed, and the GE's idle N1 taken at the ground
-- idle's corrected EGT), above the last point carried on with the last two
-- points' slope (estimate).
-- The figures: the shown EPR (P&W) or N1 % (GE), the TAT (°C), the EGT (°C)
M.FCOM = {
    PW = {{1.38, -14, 462},     -- FCOM p.830 (7.10.2): CRZ, N1 91.2 (109, PW4056)
          {1.51, -8, 490}},     -- FCOM p.840 (7.10.12): engine 4 shut down, N1 94.3
    GE = {{95.2, -14, 662},     -- FCOM p.829 (7.10.1): CRZ (570, CF6-80C2)
          {99.2, -8, 714}},     -- FCOM p.839 (7.10.11): engine 4 shut down
}
-- the ground idle at ISA sea level, EPR (P&W) or N1 % (GE) and EGT (°C):
-- estimates, no source gives an idle EGT. The GE's N1 the EEC's minimum idle
-- on the ground (engine_idle_control_GE, B747.42.xt.EEC.GE.lua)
M.IDLE = {PW = {1.00, 390}, GE = {25.9, 500}}

-- the curve's points {x, C}: x the EPR (P&W) or the corrected N1 (GE)
M.CURVE = {}
for kind, figs in pairs(M.FCOM) do
    local idle = M.IDLE[kind]
    local pts = {{idle[1], idle[2] + K0}}
    for _, f in ipairs(figs) do
        local th = M.theta(f[2])
        local x = f[1]
        if kind == "GE" then x = x / math.sqrt(th) end
        pts[#pts + 1] = {x, (f[3] + K0) / th}
    end
    M.CURVE[kind] = pts
end

-- the corrected EGT (K) at x (the EPR, or the GE's corrected N1)
function M.corrected(kind, x)
    local p = M.CURVE[kind] or M.CURVE.PW
    if x <= p[1][1] then return p[1][2] end
    for i = 2, #p do
        if x <= p[i][1] then
            local a, b = p[i - 1], p[i]
            return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
        end
    end
    local a, b = p[#p - 1], p[#p]
    return b[2] + (b[2] - a[2]) * (x - b[1]) / (b[1] - a[1])
end

-- the running engine's EGT (°C) at the shown EPR (P&W) or N1 (GE) and TAT
function M.steady(kind, x, tat)
    local th = M.theta(tat)
    if kind == "GE" then x = x / math.sqrt(th) end
    return th * M.corrected(kind, x) - K0
end

-- Starting (burning, N2 below IDLE_N2): from the EGT at the light-off (the
-- inlet's temperature on a cold engine) up to a peak START_PEAK above the
-- idle's (corrected), then down to the idle's as N2 reaches IDLE_N2, by the
-- way N2 has come from LIGHT_N2, the autostart's fuel-on N2 (the start
-- model's FUEL_ON_N2: CF6 ATA70_80 p.564-565, P&W estimate); the peak
-- PEAK_AT of that way. By N2 alone, not the N2 seen at the light-off: that
-- one comes a frame late, by more at a lower frame rate, and the rise
-- after it is steep. An engine lit above LIGHT_N2 (a windmill or a late
-- manual start) rises at once toward the target there (estimates: no
-- source gives a start's EGT. The peak stays under the start model's hot
-- start, its START_LIMIT less HOT_MARGIN, P&W 510 and GE 725 °C, at 15 and
-- 40 °C; B747.40.engine_start_model.lua)
M.IDLE_N2 = 55                      -- X-Plane's N2, %: the start model's IDLE_MIN_N2 (estimate there)
M.LIGHT_N2 = {PW = 20, GE = 15}     -- X-Plane's N2, %
M.START_PEAK = {PW = 20, GE = 60}   -- K, corrected, over the idle's
M.PEAK_AT = 0.4

-- the start's EGT (°C) at X-Plane's N2, the TAT and the EGT at the
-- light-off (°C)
function M.start_target(kind, n2, tat, lit_egt)
    local th = M.theta(tat)
    local c_idle = (M.CURVE[kind] or M.CURVE.PW)[1][2]     -- the idle point's
    local idle = th * c_idle - K0
    local peak = th * (c_idle + (M.START_PEAK[kind] or M.START_PEAK.PW)) - K0
    local light = M.LIGHT_N2[kind] or M.LIGHT_N2.PW
    local p = math.max(0, math.min(1, (n2 - light) / (M.IDLE_N2 - light)))
    if p < M.PEAK_AT then return lit_egt + (peak - lit_egt) * p / M.PEAK_AT end
    return peak + (idle - peak) * (p - M.PEAK_AT) / (1 - M.PEAK_AT)
end

-- (2026-11-10) HOT START, the failure window's (laminar/B747/engines/fail/
-- hot_start, the EEC's init script): while starting (burning, N2 below
-- IDLE_N2) the target is HOT_START_C over the idle's (corrected) instead of
-- the start's shape, 650 °C (P&W) and 820 °C (GE) at 15 °C: the EGT passes
-- the start model's hot start (510, 725 °C) a few seconds after the
-- light-off and the start limit (535, 750 °C) if the fuel stays on. Running
-- (N2 at or above IDLE_N2) the engine is normal. What acts on it: the
-- ground autostart cuts the fuel and tries again, then aborts (FCOM p.880-881
-- (7.20.10-11)); in a manual start the crew aborts when the EGT quickly nears
-- or exceeds the start limit (FCOM p.185 (SP.7.3)); in the air, an EGT
-- rising rapidly toward the takeoff limit: FUEL CONTROL CUTOFF, then RUN
-- again (QRH_CA p.122 (7.4)). The values are estimates: no source gives a
-- hot start's EGT
M.HOT_START_C = {PW = 260, GE = 320}    -- K, corrected, over the idle's (estimates)
-- and at least the 15 °C day's target: on a cold day the corrected scaling
-- alone kept it under the hot start (P&W 506 °C at -30 °C; estimate)
M.HOT_START_MIN = {PW = 650, GE = 820}  -- °C

-- the hot start's EGT target (°C) at the TAT
function M.hot_target(kind, tat)
    local c_idle = (M.CURVE[kind] or M.CURVE.PW)[1][2]
    local t = M.theta(tat) * (c_idle + (M.HOT_START_C[kind] or M.HOT_START_C.PW)) - K0
    return math.max(t, M.HOT_START_MIN[kind] or M.HOT_START_MIN.PW)
end

-- (2026-11-10) EGT OVERTEMP, the failure window's (laminar/B747/engines/
-- fail/egt_high, the EEC's init script): an excess (K, corrected) grows by
-- EGT_HIGH_RATE a second while the failure is set and the engine runs, up to
-- EGT_HIGH_MAX; it is held while the engine does not run, and dies away
-- with EGT_HIGH_TAU once the failure is cleared (gone at a new flight). The
-- running EGT gets theta x the excess x a share by the power, the corrected
-- N1 (N1 / sqrt(theta), both types): (N1c - SHARE_IDLE_N1) / (the first FCOM
-- figure's N1c - SHARE_IDLE_N1), within EGT_HIGH_SHARE. So in the cruise
-- the EGT passes the maximum continuous and the takeoff limits in about two
-- minutes, and at idle it stays under them: the crew's QRH Engine Limit or
-- Surge or Stall (QRH_CA p.124-125 (7.6-7.7)) retards the thrust lever until
-- the EGT is within limits, then shuts the engine down if it keeps rising,
-- or runs it at reduced thrust if it is stable or falling. All the values
-- are estimates: no source gives such a failure's EGT.
-- Not by the P&W's EPR (the first version, X-Plane 2026-11-10 s279): in
-- thin air the cruise's EPR is near 1 (1.15 at FL370, M.85, 238 t, N1 84 %),
-- so its share was 0.4 and the EGT stopped near 470 °C, under 629; with
-- the corrected N1 that cruise's share is 0.92
M.EGT_HIGH_RATE = 3             -- K/s, corrected (estimate)
M.EGT_HIGH_MAX = 500            -- K, corrected (estimate)
M.EGT_HIGH_TAU = 30             -- s, after the failure is cleared (estimate)
M.EGT_HIGH_SHARE = {0.25, 1.5}  -- the share's least and most (estimates)
-- the share's points: the EEC's minimum idle N1 at sea level, both types
-- (engine_idle_control_PW and _GE, B747.42.xt.EEC.PW.lua and .GE.lua), and
-- the first FCOM figure's N1 and TAT (p.830 (7.10.2) P&W, p.829 (7.10.1) GE)
M.SHARE_IDLE_N1 = 25.9
M.SHARE_REF = {PW = {91.2, -14}, GE = {95.2, -14}}

-- the excess's share at the corrected N1 (%)
function M.excess_share(kind, n1c)
    local r = M.SHARE_REF[kind] or M.SHARE_REF.PW
    local ref = r[1] / math.sqrt(M.theta(r[2]))
    local share = (n1c - M.SHARE_IDLE_N1) / (ref - M.SHARE_IDLE_N1)
    return math.max(M.EGT_HIGH_SHARE[1], math.min(M.EGT_HIGH_SHARE[2], share))
end

-- the EGT (K, the same in °C) the excess (K, corrected) adds to the running
-- engine's at the shown N1 (%) and TAT
function M.excess_egt(kind, n1, tat, excess)
    local th = M.theta(tat)
    return th * excess * M.excess_share(kind, n1 / math.sqrt(th))
end

-- Not burning: toward the TAT on the ground, toward the windmilling engine's
-- in the air: FCOM p.840 (7.10.12, P&W at N1 14.2) and p.839 (7.10.11, GE at
-- N1 11.1) both show 57 °C at TAT -8, taken as a corrected EGT at any TAT
-- and windmilling speed (estimate)
M.WINDMILL = {-8, 57}               -- TAT, EGT (°C)
local C_WINDMILL = (M.WINDMILL[2] + K0) / M.theta(M.WINDMILL[1])
function M.windmill(tat)
    return M.theta(tat) * C_WINDMILL - K0
end

-- the first-order lags' time constants (s, estimates): running or starting,
-- the EGT rising and falling; not burning, cooling (or warming) either way
M.TAU_UP, M.TAU_DOWN, M.TAU_COOL = 2, 3, 60

function M.new()
    return {egt = nil, u = nil, mode = nil, burning = false, lit_egt = 0, settle = 0, excess = 0}
end

function M.inputs()
    return {
        kind = "PW",        -- "PW" or "GE"
        burning = false,    -- the engine burns fuel
        n2 = 0,             -- X-Plane's N2, %
        x = 0,              -- the shown EPR (P&W) or N1 % (GE)
        n1 = 0,             -- the shown N1 %, both types (the EGT OVERTEMP's share)
        tat = 15,           -- °C
        air = false,        -- in the air
        floor = nil,        -- °C: the EGT shown no lower (the outside air temperature)
        hot_start = false,  -- the HOT START failure (HOT_START_C)
        egt_high = false,   -- the EGT OVERTEMP failure (EGT_HIGH_*)
    }
end

-- for the next seconds the EGT is the target at once (a new flight: no
-- lag from the last flight's or from 0, and no EGT OVERTEMP excess left)
function M.settle(s, seconds)
    s.settle = seconds
    s.excess = 0
end

-- the EGT OVERTEMP's excess after this frame: grows while the failure is set
-- and the engine runs, held while it does not run, dies away once cleared
local function grow_excess(s, inp, dt)
    if inp.egt_high then
        if inp.burning and inp.n2 >= M.IDLE_N2 then
            s.excess = math.min(M.EGT_HIGH_MAX, s.excess + M.EGT_HIGH_RATE * dt)
        end
    elseif s.excess > 0 then
        s.excess = s.excess * math.exp(-dt / M.EGT_HIGH_TAU)
        if s.excess < 0.01 then s.excess = 0 end
    end
end

-- the target (°C), the lags (s) up and down and the state's name for this
-- frame; notes the light-off
local function target(s, inp, kind)
    if inp.burning and not s.burning then
        s.lit_egt = math.max(inp.tat, s.egt or inp.tat)
    end
    s.burning = inp.burning
    if inp.burning then
        if inp.n2 >= M.IDLE_N2 then
            local u = M.steady(kind, inp.x, inp.tat)
            if s.excess > 0 then u = u + M.excess_egt(kind, inp.n1, inp.tat, s.excess) end
            return u, M.TAU_UP, M.TAU_DOWN, "run"
        end
        -- HOT START: its own state, so that the failure set or cleared
        -- during a start steps the target at the frame's start
        if inp.hot_start then return M.hot_target(kind, inp.tat), M.TAU_UP, M.TAU_DOWN, "hot" end
        return M.start_target(kind, inp.n2, inp.tat, s.lit_egt), M.TAU_UP, M.TAU_DOWN, "start"
    end
    if inp.air then return M.windmill(inp.tat), M.TAU_COOL, M.TAU_COOL, "windmill" end
    return inp.tat, M.TAU_COOL, M.TAU_COOL, "cool"
end

-- one frame of dt seconds: the EGT shown (°C). The lag is exact for a target
-- that moves in a straight line over the frame (from the last frame's to
-- this one's), and for one that steps at the frame's start where the state
-- changes (the light-off, idle reached, the shutdown, air/ground), so the
-- frame rate does not change the EGT
function M.update(s, inp, dt)
    local kind = inp.kind == "GE" and "GE" or "PW"
    if dt < 0 then dt = 0 end
    grow_excess(s, inp, dt)
    local u, up, down, mode = target(s, inp, kind)
    if mode ~= s.mode then s.u = u end
    s.mode = mode
    local y
    if s.egt == nil or s.settle > 0 then
        y = u
    elseif dt > 1e-6 then
        local tau = up
        if u < s.egt then tau = down end
        local q = math.exp(-dt / tau)
        y = u + (s.egt - s.u) * q - (u - s.u) * (tau / dt) * (1 - q)
    else
        y = s.egt
    end
    if inp.floor and y < inp.floor then y = inp.floor end
    s.settle = math.max(0, s.settle - dt)
    s.egt, s.u = y, u
    return y
end

return M
