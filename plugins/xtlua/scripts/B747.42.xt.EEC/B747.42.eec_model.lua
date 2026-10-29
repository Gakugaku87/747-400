-- 747-400 EEC without X-Plane: for each engine the maximum rated thrust for
-- the conditions (Max N1 for the CF6-80C2, Max EPR for the PW4056), the
-- command the thrust lever asks for between idle and that maximum, so that
-- full forward gives the maximum rated thrust in any phase (FCOM p.876),
-- the alternate mode, the overspeed protection and the idle selection.
-- Logic and sources:
-- docs/overhaul/notes/ATA-70-80.md §4.1, §4.2 and §4.4 (FCOM 7.20
-- p.873-878; ATA70_80 p.146-151 and p.202-211 for the CF6; FCOM PI for the
-- ratings).
-- B747.42.xt.eec_thrust.lua feeds it and gives the target to the engines'
-- thrust control.
--
--   local E = B747_eec_model
--   local s = E.new()
--   local inp = E.inputs()                 -- fill it every frame
--   local out = E.update(s, inp, dt)       -- a new table

-- a table with a metatable: XTLua keeps it as it is when it goes in a global
local M = setmetatable({}, {})
B747_eec_model = M

-- the full-forward rating (CF6, ATA70_80 p.208): takeoff below 17,000 ft and
-- 300 kt, maximum continuous from 18,000 to 22,000 ft or above 293 kt,
-- maximum climb above 25,000 ft with the levers past 35° (the normal climb
-- position). Between them the logic blends (bands from those figures,
-- estimate). P&W: no source, as the CF6 (estimate).
M.TO_ALT, M.MCT_ALT = 17000, 18000
M.TO_KIAS, M.MCT_KIAS = 300, 293
M.MCT_ALT_TOP, M.CLB_ALT = 22000, 25000
-- thrust lever angles, degrees from forward idle (ATA70_80 p.146-151): the
-- takeoff rating is reached at 48°, the forward stop is 50°; the climb
-- rating at 35° (ATA70_80 p.208)
M.TLA_STOP, M.TLA_TO, M.TLA_CLB = 50, 48, 35

-- idle (FCOM p.877-878): approach idle in the air while the engine's
-- nacelle anti-ice is on, the flaps are in a landing position or (570 and
-- 405, not 109) the CON IGNITION switch is ON; the CF6 (570) also while its
-- reverser works. It stays until 5 s after touchdown; 5 s also after the
-- conditions end in the air (the CF6's idle select circuit, ATA70_80 p.211,
-- estimate). Minimum idle otherwise.
M.APPROACH_HOLD_S = 5
M.LANDING_FLAPS_DEG = 23            -- trailing edge flaps past 23° (ATA70_80 p.211)

-- X-Plane's idle (sim/aircraft2/engine/high_idle_ratio) for the idle
-- selected: one ratio for all engines (X-Plane takes the larger of it and
-- low_idle_ratio and keeps idle_speed_ratio at high idle), so approach idle
-- on any engine raises all four. The ratio sets X-Plane's idle N2 (69.7 %
-- at 1.07, 84.4 % at 5, at any height and speed), and with it the idle
-- thrust. Measured with the custom acf (tests/flight/measure/
-- aero_idle_ground.json, aero_idle_sweep.json, aero_idle_taxi.json,
-- 2026-10-30; notes/AERO.md 3.7):
-- - minimum idle in the air, by pressure altitude: the net thrust that,
--   with the acf's drag, gives the FCOM's idle descents (PI.10.39, p.265:
--   290 KIAS, .84 above 30,000 ft), about +3 kN an engine at sea level,
--   +2 at 10,000 ft and 0 at 20,000-30,000 ft. The FCOM fixes drag less
--   idle thrust only, so the split is an estimate; above 30,000 ft the
--   ratio is carried on (estimate);
-- - minimum idle on the ground: the previous code's 15 °C value, 4 % of the
--   rated thrust standing at sea level (10.3 kN; the ICAO reference idle is
--   7 %, ICAO_EEDB 1PW041). With the acf's rolling friction lowered to fit
--   (_roll_co 0.015) it keeps a taxi going at 270 t and does not start one
--   from a stop (FCTM p.76) (estimate);
-- - approach idle: 0.5 above the minimum idle in the air, also on the
--   ground (a flight setting, held until 5 s after touchdown; near the
--   ground about the previous code's 2.625). No figures for the PW4056;
--   the CF6's is up to 73 % N2 against its 61.6 % minimum (ATA70_80
--   p.206-208) (estimate).
-- X-Plane's engine is the same for every engine type, so the CF6 has the
-- same ratios (the previous code gave it higher ones, estimates; its idle
-- N2 on the EICAS is the display model's, ENG-33).
M.IDLE = {
    alt = {0, 10000, 20000, 30000, 35000},
    air = {2.3, 2.5, 2.9, 4.1, 4.7},
    ground = 1.07,
    approach_step = 0.5,
}

-- alternate mode (FCOM p.876-877; ATA70_80 p.202-207), selected with the
-- EEC MODE switch (the sim has no EEC faults, so no automatic reversion).
-- It does not limit thrust at the maximum: the command is a fixed schedule
-- of lever angle and pressure altitude, as the CF6's hard reversionary mode
-- that uses its corner point temperature and corrects for pressure only
-- (ATA70_80 p.205, p.207): the rating at the TAT that gives the most thrust
-- at that altitude, without the bleed adjustments. The same lever then
-- gives at least normal-mode thrust, the maximum comes before full forward
-- and full forward can overboost (FCOM p.877). P&W: no source, as the CF6;
-- it keeps controlling EPR (the real one changes to N1; estimate).
-- >ENG n LIM PROT (FCOM p.900): GE when the command passes the maximum
-- rating, P&W when it comes near it (within LIM_PROT_EPR, estimate).
M.LIM_PROT_EPR = 0.01

-- overspeed protection (FCOM p.878; ATA70_80 p.205): above idle the EEC
-- keeps N1 and N2 from passing their operating limits (the red lines)
-- whatever the lever asks. A rotor's limit loop works once the rotor is
-- within RPM_BAND of its red line less RPM_MARGIN: it allows the controlled
-- value (N1 for GE, EPR for P&W) the present one plus RPM_GAIN for each
-- percent the rotor is short of that (less when past it). The thrust
-- control aims at the lowest of the command and the limits (target), so the
-- rotor settles RPM_MARGIN below its red line. The GE controls N1 itself:
-- its N1 limit caps the command. >ENG n RPM LIM while a limit holds the
-- engine (allows it no more than RPM_LIM_SHOW above its present value) more
-- than RPM_LIM_SHOW below the command (FCOM p.901: GE on N2, P&W on N1 or
-- N2). Red lines: CF6 ATA70_80 p.205; P&W those the displays turn red at
-- (no source). Margin, band, gains and threshold: estimates.
M.REDLINE = {GE = {n1 = 117.5, n2 = 112.5}, PW = {n1 = 111.4, n2 = 111.4}}
M.RPM_MARGIN = 0.5                          -- %
M.RPM_BAND = 2                              -- %
M.RPM_GAIN = {GE = 0.6, PW = 0.01}          -- N1 % or EPR for each % of the rotor
M.RPM_LIM_SHOW = {GE = 0.2, PW = 0.005}     -- N1 % or EPR

-- the thrust control (FCOM p.875-876): the EEC adjusts fuel flow until the
-- controlled value (N1 for GE, EPR for P&W) equals the target. In the sim
-- the fuel metering is X-Plane's throttle (0 to 1) and X-Plane's engine
-- gives the spool-up and spool-down. The value the control follows (ref)
-- closes on the target with a time constant of lag seconds and at no more
-- than up or down each second (the EEC's acceleration and deceleration
-- schedules; slower down, as X-Plane's engine is slow to turn from spooling
-- down to spooling up). The throttle moves by ki times the error each
-- second and kp times the error's change, both divided by the controlled
-- value's slope against the throttle at its present value (the displayed
-- EPR steepens fourfold towards full thrust), so that the loop answers
-- alike at any thrust. With the lever at its idle end the throttle is 0
-- (the EEC's idle). Gains, rates and slopes: estimates, the slopes measured
-- in X-Plane (8,000-13,500 ft, M.42-.49; near idle the displays hardly move).
-- The P&W slopes follow the displayed EPR: with the EPR model of 2026-10-30
-- (B747.42.epr_model.lua) they are the measured ones carried through the
-- two EPR formulas at 10,000 ft, M.45 (the same thrusts); above 1.42 (full
-- throttle there) carried on (estimate).
M.THRUST = {
    PW = {ki = 2.0, kp = 3.0, lag = 1.5, up = 0.15, down = 0.15,       -- EPR each second
        at = {0.97, 1.02, 1.09, 1.20, 1.26, 1.32, 1.37, 1.42, 1.71},
        slope = {0.3, 0.62, 0.82, 0.93, 1.03, 1.16, 1.17, 1.47, 1.8}}, -- EPR for each unit of throttle
    GE = {ki = 2.0, kp = 3.0, lag = 1.5, up = 15, down = 5,            -- N1 % each second
        at = {35, 45, 60, 75, 90, 100},
        slope = {20, 100, 112, 100, 80, 77}},                          -- N1 % for each unit of throttle
}

-- FCOM PI tables, 3 packs on, anti-ice off. Rows by TAT (°C, warm to cold),
-- columns by pressure altitude (ft); false where the table is blank (too
-- warm for that altitude). The go-around rating stands for the takeoff
-- rating: the FCOM has no normal-mode takeoff table, and its alternate-mode
-- takeoff and go-around tables give the same thrust (PI.15.6, estimate).
-- The maximum continuous tables (PI.13.1, PI.23.1) depend on speed as well
-- and are not in: the maximum climb rating stands for them (estimate).
local F = false
M.TABLE = {
    PW = {
        -- Go-around EPR, PW4056 (PI.10.37, FCOM p.263), airport pressure altitude
        ga = {
            alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
            tat = {54, 50, 45, 40, 35, 30, 25, 20, 15, 10},
            v = {
                {1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, 1.38, F},
                {1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, 1.41, F},
                {1.46, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.45, 1.44, 1.44, 1.44, 1.44},
                {1.46, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48, 1.48},
                {1.46, 1.48, 1.51, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52, 1.52},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56, 1.56},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.59, 1.59, 1.59, 1.59, 1.59},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.63, 1.63, 1.63},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.64, 1.65, 1.66},
                {1.46, 1.48, 1.51, 1.53, 1.54, 1.56, 1.57, 1.59, 1.61, 1.63, 1.64, 1.65, 1.67},
            },
            -- adjustments for engine bleed: 2 and 3 packs off (the same at every altitude)
            packs_off = {alt = {-2000, 10000}, [2] = {0.01, 0.01}, [3] = {0.02, 0.02}},
        },
        -- Max Climb EPR, PW4056 (PI.10.36, FCOM p.262), 340 KIAS / M.84
        clb = {
            alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
            tat = {60, 50, 40, 30, 20, 10, 0, -10, -20},
            v = {
                {1.19, 1.19, 1.18, F, F, F, F, F, F, F},
                {1.23, 1.23, 1.22, 1.21, F, F, F, F, F, F},
                {1.25, 1.29, 1.28, 1.27, 1.25, F, F, F, F, F},
                {1.25, 1.30, 1.35, 1.35, 1.33, 1.32, F, F, F, F},
                {1.25, 1.30, 1.35, 1.39, 1.42, 1.42, 1.42, 1.39, F, F},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.52, 1.48, 1.44, 1.41},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.58, 1.54, 1.51},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
                {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
            },
            -- engine anti-ice on, engine and wing anti-ice on
            nai = {alt = {0, 10000, 20000, 30000, 40000}, v = {-0.01, -0.02, -0.03, -0.04, -0.05}},
            nai_wai = {alt = {0, 10000, 20000, 30000, 40000}, v = {-0.03, -0.04, -0.06, -0.07, -0.08}},
        },
    },
    GE = {
        -- Go-around %N1, CF6-80C2B1F (PI.20.32, FCOM p.360), airport pressure altitude
        ga = {
            alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
            tat = {57, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0, -10, -20, -30, -40, -50},
            v = {
                {102.9, 103.0, 103.2, 103.4, 103.6, 103.6, 103.6, 103.9, 104.0, 104.0, 103.9, 103.9, 103.8},
                {104.0, 104.7, 105.3, 105.5, 105.1, 104.5, 104.0, 104.3, 104.5, 104.4, 104.4, 104.3, 104.3},
                {104.6, 105.3, 106.0, 106.2, 106.2, 106.1, 105.6, 105.4, 105.0, 104.7, 104.7, 104.6, 104.6},
                {105.2, 105.9, 106.6, 106.9, 107.0, 106.9, 106.7, 106.9, 106.9, 106.3, 105.6, 104.9, 104.8},
                {104.6, 105.9, 107.3, 107.7, 107.8, 107.7, 107.5, 107.8, 107.8, 107.8, 107.6, 106.9, 106.1},
                {103.7, 105.1, 106.4, 107.4, 108.4, 108.5, 108.4, 108.6, 108.7, 108.7, 108.6, 108.2, 107.8},
                {102.9, 104.2, 105.5, 106.6, 107.5, 108.3, 109.0, 109.3, 109.4, 109.5, 109.6, 109.2, 108.8},
                {102.0, 103.4, 104.7, 105.7, 106.6, 107.4, 108.1, 109.0, 109.8, 110.2, 110.3, 110.1, 109.8},
                {101.2, 102.5, 103.8, 104.8, 105.7, 106.5, 107.2, 108.0, 108.8, 109.6, 110.3, 110.8, 110.9},
                {100.3, 101.6, 102.9, 103.9, 104.8, 105.5, 106.2, 107.1, 107.9, 108.6, 109.3, 109.9, 110.4},
                {99.4, 100.7, 102.0, 103.0, 103.9, 104.6, 105.3, 106.2, 107.0, 107.7, 108.4, 108.9, 109.4},
                {98.5, 99.8, 101.1, 102.1, 103.0, 103.7, 104.4, 105.2, 106.0, 106.7, 107.4, 107.9, 108.5},
                {96.7, 98.0, 99.2, 100.2, 101.1, 101.9, 102.5, 103.4, 104.2, 104.8, 105.5, 106.0, 106.5},
                {94.9, 96.1, 97.3, 98.3, 99.2, 100.0, 100.6, 101.5, 102.2, 102.9, 103.6, 104.4, 104.6},
                {93.0, 94.2, 95.4, 96.4, 97.3, 98.0, 98.7, 99.5, 100.3, 100.9, 101.6, 102.1, 102.5},
                {91.1, 92.3, 93.5, 94.4, 95.3, 96.0, 96.7, 97.5, 98.3, 98.9, 99.5, 100.0, 100.5},
                {89.2, 90.3, 91.5, 92.4, 93.3, 94.0, 94.7, 95.5, 96.2, 96.9, 97.5, 97.9, 98.4},
            },
            packs_off = {alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
                [2] = {0.3, 0.3, 0.3, 0.3, 0.3, 0.4, 0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6},
                [3] = {0.5, 0.5, 0.5, 0.5, 0.5, 0.6, 0.7, 0.8, 0.8, 0.8, 0.8, 0.8, 0.9}},
            nai = {alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
                v = {-0.5, -0.5, -0.5, -0.5, -0.5, -0.6, -0.7, -0.7, -0.8, -0.8, -0.8, -0.7, -0.7}},
        },
        -- Max Climb %N1, CF6-80C2B1F (PI.20.31, FCOM p.359), 340 KIAS / M.84
        clb = {
            alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
            tat = {50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0, -5, -10, -15, -20, -25, -30, -35, -40},
            v = {
                {99.4, 100.8, F, F, F, F, F, F, F, F},
                {99.9, 101.3, 102.0, 101.1, F, F, F, F, F, F},
                {100.3, 101.9, 102.6, 101.6, F, F, F, F, F, F},
                {99.7, 102.5, 103.1, 102.1, 102.0, F, F, F, F, F},
                {99.0, 102.3, 103.7, 102.8, 102.6, F, F, F, F, F},
                {98.2, 101.6, 103.9, 103.4, 103.2, 103.2, 101.9, F, F, F},
                {97.4, 100.8, 103.2, 104.1, 103.6, 104.1, 102.7, F, F, F},
                {96.6, 99.9, 102.4, 103.5, 104.3, 104.9, 103.6, 101.1, 100.9, F},
                {95.8, 99.1, 101.6, 102.7, 104.1, 105.9, 104.4, 101.9, 101.5, 101.1},
                {95.0, 98.3, 100.7, 101.8, 103.3, 105.8, 105.2, 102.7, 102.3, 101.9},
                {94.1, 97.4, 99.9, 100.9, 102.6, 105.0, 106.3, 103.7, 103.2, 102.8},
                {93.3, 96.6, 99.0, 100.0, 101.7, 104.2, 105.7, 104.6, 104.1, 103.7},
                {92.5, 95.7, 98.1, 99.1, 100.8, 103.2, 104.9, 105.6, 105.0, 104.5},
                {91.6, 94.8, 97.2, 98.2, 99.9, 102.3, 104.0, 105.5, 105.4, 105.1},
                {90.7, 93.9, 96.3, 97.3, 99.0, 101.3, 103.0, 104.7, 104.6, 104.3},
                {89.9, 93.0, 95.4, 96.4, 98.1, 100.4, 102.1, 103.9, 103.8, 103.5},
                {89.0, 92.1, 94.5, 95.5, 97.1, 99.4, 101.1, 102.9, 102.8, 102.5},
                {88.1, 91.2, 93.6, 94.5, 96.2, 98.4, 100.1, 101.8, 101.8, 101.5},
                {87.2, 90.3, 92.6, 93.6, 95.2, 97.4, 99.0, 100.8, 100.8, 100.4},
            },
            nai = {alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
                v = {-0.5, -0.5, -0.6, -0.6, -0.7, -0.8, -0.9, -1.1, -1.6, -2.0}},
            nai_wai = {alt = {0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000},
                v = {-0.9, -1.0, -1.2, -1.1, -1.3, -1.5, -1.7, -2.0, -3.0, -4.0}},
        },
    },
}

local function clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end

-- linear interpolation in a row of breakpoints, held at the ends
local function interp(xs, ys, x)
    if x <= xs[1] then return ys[1] end
    for i = 2, #xs do
        if x <= xs[i] then
            return ys[i - 1] + (ys[i] - ys[i - 1]) * (x - xs[i - 1]) / (xs[i] - xs[i - 1])
        end
    end
    return ys[#ys]
end

-- one altitude column of a table at a TAT: between the rows that have a
-- value, held at the warmest and coldest of them
local function column(t, j, tat)
    local xs, ys = {}, {}
    for i = #t.tat, 1, -1 do                 -- cold to warm: rising TAT for interp
        local v = t.v[i][j]
        if v then xs[#xs + 1] = t.tat[i]; ys[#ys + 1] = v end
    end
    return interp(xs, ys, tat)
end

-- the largest value of a table at a pressure altitude, whatever the TAT
-- (the corner point of the flat rating)
function M.lookup_max(t, alt)
    local a = t.alt
    local function col(j)
        local m = nil
        for i = 1, #t.tat do
            local v = t.v[i][j]
            if v and (m == nil or v > m) then m = v end
        end
        return m
    end
    if alt <= a[1] then return col(1) end
    if alt >= a[#a] then return col(#a) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = col(j - 1), col(j)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- a table's value at a TAT and pressure altitude (held at the ends)
function M.lookup(t, tat, alt)
    local a = t.alt
    if alt <= a[1] then return column(t, 1, tat) end
    if alt >= a[#a] then return column(t, #a, tat) end
    for j = 2, #a do
        if alt <= a[j] then
            local v0, v1 = column(t, j - 1, tat), column(t, j, tat)
            return v0 + (v1 - v0) * (alt - a[j - 1]) / (a[j] - a[j - 1])
        end
    end
end

-- X-Plane's idle ratio (M.IDLE): approach idle, or minimum idle in the air
-- or on the ground, at a pressure altitude (ft)
function M.idle_ratio(air, alt, approach)
    local r = interp(M.IDLE.alt, M.IDLE.air, alt)
    if approach then return r + M.IDLE.approach_step end
    if air then return r end
    return M.IDLE.ground
end

-- the bleed adjustment of a rating: packs off (go-around tables), engine
-- anti-ice, and engine and wing anti-ice (climb tables; the go-around tables
-- have engine anti-ice for the CF6 only)
local function adjustment(t, inp, alt, nai)
    local d = 0
    local off = 3 - clamp(inp.packs_on, 0, 3)
    if t.packs_off and off >= 2 then d = d + interp(t.packs_off.alt, t.packs_off[off], alt) end
    if nai then
        if inp.wai and t.nai_wai then d = d + interp(t.nai_wai.alt, t.nai_wai.v, alt)
        elseif t.nai then d = d + interp(t.nai.alt, t.nai.v, alt) end
    end
    return d
end

function M.inputs()
    return {
        type = "PW",                         -- "PW" or "GE" (anything else: P&W)
        alt = 0,                             -- pressure altitude, ft
        tat = 15,                            -- °C
        kias = 0,
        packs_on = 3,                        -- packs operating (their valves open)
        nai = {false, false, false, false},  -- engine anti-ice valve open
        wai = false,                         -- wing anti-ice valve open
        lever = {0, 0, 0, 0},                -- forward thrust lever, 0 idle to 1 forward stop
        idle = {0, 0, 0, 0},                 -- the engine's idle N1 (GE) or EPR (P&W)
        air = false,                         -- air/ground: in the air
        flaps_deg = 0,                       -- trailing edge flaps
        con = false,                         -- CON IGNITION switch ON
        freighter = false,                   -- 405 or 570 (CON selects approach idle there)
        reverser = {false, false, false, false},   -- the engine's reverser not stowed
        at_approach = nil,                   -- {n} engine at approach idle; nil: as selected
        altn = {false, false, false, false}, -- EEC MODE switch at ALTN
        n1 = {0, 0, 0, 0},                   -- the engines' N1 and N2, %
        n2 = {0, 0, 0, 0},
        actual = {0, 0, 0, 0},               -- the controlled value now: N1 (GE) or EPR (P&W)
    }
end

-- the overspeed protection: the target of each engine's thrust control and
-- whether a rotor limit holds it back (>ENG n RPM LIM)
local function overspeed(inp, out)
    local key = inp.type == "GE" and "GE" or "PW"
    local red, gain, show = M.REDLINE[key], M.RPM_GAIN[key], M.RPM_LIM_SHOW[key]
    -- a rotor's limit loop: the controlled value it allows (nil while the
    -- rotor is short of its band)
    local function limit(rpm, redline, actual)
        local short = redline - M.RPM_MARGIN - rpm
        if short > M.RPM_BAND then return nil end
        return actual + gain * short
    end
    out.target, out.rpm_lim = {}, {}
    for n = 1, 4 do
        local actual, command = inp.actual[n], out.command[n]
        local lim = limit(inp.n2[n], red.n2, actual)
        if key == "GE" then
            command = math.min(command, red.n1 - M.RPM_MARGIN)
        else
            local lim1 = limit(inp.n1[n], red.n1, actual)
            if lim1 and (lim == nil or lim1 < lim) then lim = lim1 end
        end
        local target = command
        if lim and lim < target then target = lim end
        out.target[n] = target
        out.rpm_lim[n] = lim ~= nil and lim < command - show and lim <= actual + show
    end
end

function M.new()
    return {approach = {false, false, false, false}, hold = {0, 0, 0, 0},
        altn = {false, false, false, false}, throttle = {}, err = {}, ref = {}}
end

-- engine n's throttle for its target (key "GE" or "PW"; current: X-Plane's
-- throttle now, where the control starts from; idle: the lever's idle end
-- command)
function M.thrust_control(s, key, n, target, actual, current, idle, dt)
    local g = M.THRUST[key]
    if target <= idle then
        s.throttle[n], s.err[n], s.ref[n] = 0, nil, actual
        return 0
    end
    local ref = s.ref[n] or actual
    ref = ref + clamp((target - ref) * math.min(1, dt / g.lag), -g.down * dt, g.up * dt)
    local th = s.throttle[n] or clamp(current, 0, 1)
    local err = ref - actual
    local slope = interp(g.at, g.slope, actual)
    th = clamp(th + (g.ki * err * dt + g.kp * (err - (s.err[n] or err))) / slope, 0, 1)
    s.throttle[n], s.err[n], s.ref[n] = th, err, ref
    return th
end

-- the control starts again from X-Plane's throttle (engine stopped,
-- starting or in reverse)
function M.reset_thrust_control(s, n)
    s.throttle[n], s.err[n], s.ref[n] = nil, nil, nil
end

-- approach idle of each engine, and the idle messages: ENG n LOW IDLE
-- (approach idle selected, not reached) and >IDLE DISAGREE (an engine at
-- approach idle with minimum idle selected) (FCOM p.900, p.902; ATA70_80
-- p.230). The sim has no idle faults: without at_approach they stay off.
local function idle_selection(s, inp, dt, out)
    local con = inp.con and (inp.type == "GE" or inp.freighter)
    local landing = inp.air and (inp.flaps_deg > M.LANDING_FLAPS_DEG or con)
    out.approach, out.low_idle, out.idle_disagree = {}, {}, false
    for n = 1, 4 do
        local want = landing or (inp.air and inp.nai[n]) or (inp.type == "GE" and inp.reverser[n])
        if want then
            s.approach[n], s.hold[n] = true, M.APPROACH_HOLD_S
        elseif s.approach[n] then
            s.hold[n] = s.hold[n] - dt
            if s.hold[n] <= 0 then s.approach[n], s.hold[n] = false, 0 end
        end
        local at = s.approach[n]
        if inp.at_approach then at = inp.at_approach[n] end
        out.approach[n] = s.approach[n]
        out.low_idle[n] = s.approach[n] and not at
        out.idle_disagree = out.idle_disagree or (at and not s.approach[n])
    end
end

-- the share of the takeoff rating in the full-forward rating (1 takeoff,
-- 0 maximum continuous or climb), and the lever angle at which the rating
-- is reached
function M.rating_mix(alt, kias)
    local by_alt = clamp((M.MCT_ALT - alt) / (M.MCT_ALT - M.TO_ALT), 0, 1)
    local by_speed = clamp((M.TO_KIAS - kias) / (M.TO_KIAS - M.MCT_KIAS), 0, 1)
    local tla_full = M.TLA_TO + (M.TLA_CLB - M.TLA_TO) * clamp((alt - M.MCT_ALT_TOP) / (M.CLB_ALT - M.MCT_ALT_TOP), 0, 1)
    return by_alt * by_speed, tla_full
end

function M.update(s, inp, dt)
    local tables = M.TABLE[inp.type] or M.TABLE.PW
    local to_share, tla_full = M.rating_mix(inp.alt, inp.kias)
    -- the go-around tables stop at 10,000 ft: held above (estimate)
    local ga_alt = math.min(inp.alt, tables.ga.alt[#tables.ga.alt])
    local ga = M.lookup(tables.ga, inp.tat, ga_alt)
    local clb = M.lookup(tables.clb, inp.tat, inp.alt)
    -- the alternate mode's schedule: the corner point rating, no bleed adjustments
    local altn_max = to_share * M.lookup_max(tables.ga, ga_alt) + (1 - to_share) * M.lookup_max(tables.clb, inp.alt)
    local out = {max = {}, command = {}, altn = {}, lim_prot = {}, to_share = to_share, tla_full = tla_full,
        at_disconnect = false}
    local altn_count = 0
    for n = 1, 4 do
        local nai = inp.nai[n]
        local max = to_share * (ga + adjustment(tables.ga, inp, ga_alt, nai))
            + (1 - to_share) * (clb + adjustment(tables.clb, inp, inp.alt, nai))
        local tla = clamp(inp.lever[n], 0, 1) * M.TLA_STOP
        local altn = inp.altn[n]
        local top = max
        if altn then top = math.max(altn_max, max) end
        local idle = math.min(inp.idle[n], max)
        out.max[n] = max
        out.command[n] = idle + (top - idle) * clamp(tla / tla_full, 0, 1)
        out.altn[n] = altn
        if inp.type == "GE" then
            out.lim_prot[n] = altn and out.command[n] > max
        else
            out.lim_prot[n] = altn and out.command[n] > max - M.LIM_PROT_EPR
        end
        -- the A/T disconnects when an EEC goes to the alternate mode (FCOM p.877)
        if altn and not s.altn[n] then out.at_disconnect = true end
        s.altn[n] = altn
        if altn then altn_count = altn_count + 1 end
    end
    -- the A/T can be used again: GE with all four EECs in the alternate
    -- mode, P&W with all four back in the normal mode (FCOM p.877)
    if inp.type == "GE" then out.at_inhibit = altn_count > 0 and altn_count < 4
    else out.at_inhibit = altn_count > 0 end
    overspeed(inp, out)
    idle_selection(s, inp, dt, out)
    return out
end

return M
