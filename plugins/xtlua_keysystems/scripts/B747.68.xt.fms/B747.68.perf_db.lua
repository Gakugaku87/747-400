-- 747-400 FMC performance database without X-Plane (6-1/6-2 step 8a;
-- docs/overhaul/notes/ATA-34-61-FMC.md §43, §44): the FCOM's Performance
-- Inflight tables for the airplane's engines and their interpolation: the
-- long range cruise (Mach, KIAS, fuel flow), the optimum and maximum
-- altitudes, holding, the .84/290/250 descent and the wind-altitude trade.
-- PW4056 (the 109; RR, without a source, uses it: an estimate): FCOM PI.11
-- p.267-273. CF6-80C2B1F (the 570, a 747-400F; weights and fuel in lb):
-- PI.21 p.363-369. Read off the rendered pages.
--
--   local P = B747_perf_db                 -- in XTLua, after dofile
--   local P = dofile(".../B747.68.perf_db.lua")   -- in the tests
--   local t = P.tables(engine_type)        -- laminar/B747/engines/type: 0 PW, 1 GE, 2 RR
--   local mach, kias, ff = P.lrc(t, weight_kg, altitude_ft)

local M = setmetatable({}, {})
B747_perf_db = M

M.LB = 0.45359237           -- kg per lb
M.MARGIN_G = 1.3            -- the maneuver margin the FMC's maximum altitude uses by default (an estimate: 1.20-1.30, FMC notes §2)

-- a value's place in a list sorted either way: i, j and the fraction from
-- list[i] to list[j], within the list's ends
local function bracket(list, x)
    local n = #list
    if n == 1 then return 1, 1, 0 end
    local up = list[n] > list[1]
    if (up and x <= list[1]) or (not up and x >= list[1]) then return 1, 1, 0 end
    if (up and x >= list[n]) or (not up and x <= list[n]) then return n, n, 0 end
    for k = 1, n - 1 do
        local a, b = list[k], list[k + 1]
        if (up and x >= a and x <= b) or (not up and x <= a and x >= b) then
            return k, k + 1, (x - a) / (b - a)
        end
    end
    return n, n, 0
end
M.bracket = bracket

local function lerp(a, b, f) return a + (b - a) * f end

-- PW4056, weights in 1000 kg, fuel flows in kg/h
local PW = {wf = 1}
-- PI.11.1 (p.267) Long Range Cruise Maximum Operating Altitude, max climb
-- thrust: by weight the optimum altitude, and the maximum altitude by the
-- margin to initial buffet (g: 1.20, 1.25, 1.30, 1.40, 1.50; bank 33, 36,
-- 39, 44, 48 degrees) for ISA+10 and below, ISA+15, ISA+20; thrust-limited
-- entries (100 fpm residual climb) marked as negative numbers here
PW.MAX_ALT_W = {400, 380, 360, 340, 320, 300, 280, 260, 240, 220, 200, 180}
PW.OPT_ALT = {27600, 28800, 30000, 31200, 32500, 33900, 35400, 36900, 38600, 40400, 42400, 44600}
PW.MARGIN_G = {1.20, 1.25, 1.30, 1.40, 1.50}
PW.MAX_ALT = {
    [10] = {
        {-33300, 32900, 32100, 30500, 28900},
        {-34500, 34000, 33200, 31600, 30100},
        {-35700, 35100, 34300, 32700, 31300},
        {-36800, 36300, 35500, 34000, 32500},
        {-38000, 37600, 36800, 35200, 33800},
        {-39200, 38900, 38100, 36600, 35100},
        {-40400, 40400, 39600, 38000, 36600},
        {-41800, -41800, 41100, 39600, 38100},
        {-43300, -43300, 42800, 41200, 39800},
        {45000, 45000, 44600, 43000, 41600},
        {45000, 45000, 45000, 45000, 43600},
        {45000, 45000, 45000, 45000, 45000},
    },
    [15] = {
        {-33300, 32900, 32100, 30500, 28900},
        {-34500, 34000, 33200, 31600, 30100},
        {-35700, 35100, 34300, 32700, 31300},
        {-36800, 36300, 35500, 34000, 32500},
        {-37900, 37600, 36800, 35200, 33800},
        {-39100, 38900, 38100, 36600, 35100},
        {-40400, 40400, 39600, 38000, 36600},
        {-41800, -41800, 41100, 39600, 38100},
        {-43300, -43300, 42800, 41200, 39800},
        {45000, 45000, 44600, 43000, 41600},
        {45000, 45000, 45000, 45000, 43600},
        {45000, 45000, 45000, 45000, 45000},
    },
    [20] = {
        {-32400, -32400, 32100, 30500, 28900},
        {-33700, -33700, 33200, 31600, 30100},
        {-35000, -35000, 34300, 32700, 31300},
        {-36200, -36200, 35500, 34000, 32500},
        {-37300, -37300, 36800, 35200, 33800},
        {-38500, -38500, 38100, 36600, 35100},
        {-39800, -39800, 39600, 38000, 36600},
        {-41100, -41100, 41100, 39600, 38100},
        {-42600, -42600, -42600, 41200, 39800},
        {-44300, -44300, -44300, 43000, 41600},
        {45000, 45000, 45000, 45000, 43600},
        {45000, 45000, 45000, 45000, 45000},
    },
}

-- PI.11.2 (p.268) Long Range Cruise Control: by weight and pressure
-- altitude (1000 ft) {EPR, Mach, KIAS, fuel flow per engine kg/h}
PW.LRC_ALT = {27, 29, 31, 33, 35, 37, 39, 41, 43, 45}
PW.LRC_W = {400, 380, 360, 340, 320, 300, 280, 260, 240, 220, 200}
PW.LRC = {
    [400] = {[27] = {1.19, .852, 347, 3467}, [29] = {1.25, .862, 337, 3466}, [31] = {1.36, .861, 322, 3513}},
    [380] = {[27] = {1.16, .844, 343, 3286}, [29] = {1.21, .858, 335, 3274}, [31] = {1.29, .861, 323, 3284},
             [33] = {1.42, .860, 308, 3375}},
    [360] = {[27] = {1.13, .834, 339, 3116}, [29] = {1.18, .850, 332, 3092}, [31] = {1.24, .861, 323, 3092},
             [33] = {1.34, .861, 309, 3124}, [35] = {1.48, .860, 295, 3256}},
    [340] = {[27] = {1.11, .824, 334, 2950}, [29] = {1.15, .840, 328, 2920}, [31] = {1.20, .855, 320, 2907},
             [33] = {1.27, .862, 309, 2912}, [35] = {1.39, .860, 295, 2973}},
    [320] = {[27] = {1.09, .811, 329, 2787}, [29] = {1.13, .829, 323, 2758}, [31] = {1.17, .846, 316, 2735},
             [33] = {1.22, .859, 308, 2731}, [35] = {1.31, .861, 295, 2743}, [37] = {1.45, .860, 282, 2850}},
    [300] = {[27] = {1.08, .797, 323, 2622}, [29] = {1.10, .816, 318, 2597}, [31] = {1.14, .834, 311, 2572},
             [33] = {1.18, .850, 304, 2555}, [35] = {1.25, .861, 295, 2554}, [37] = {1.35, .861, 282, 2598}},
    [280] = {[27] = {1.06, .782, 316, 2463}, [29] = {1.08, .802, 311, 2437}, [31] = {1.11, .821, 306, 2413},
             [33] = {1.15, .838, 300, 2391}, [35] = {1.20, .854, 293, 2378}, [37] = {1.28, .862, 282, 2391},
             [39] = {1.39, .860, 269, 2472}},
    [260] = {[27] = {1.04, .765, 309, 2303}, [29] = {1.06, .786, 304, 2278}, [31] = {1.09, .805, 300, 2255},
             [33] = {1.12, .825, 294, 2233}, [35] = {1.16, .842, 288, 2211}, [37] = {1.22, .857, 281, 2218},
             [39] = {1.30, .861, 269, 2252}, [41] = {1.43, .860, 257, 2341}},
    [240] = {[27] = {1.03, .745, 300, 2144}, [29] = {1.05, .767, 297, 2119}, [31] = {1.07, .788, 292, 2096},
             [33] = {1.10, .808, 288, 2075}, [35] = {1.13, .827, 282, 2054}, [37] = {1.17, .845, 276, 2049},
             [39] = {1.23, .859, 269, 2074}, [41] = {1.32, .861, 257, 2102}, [43] = {1.46, .860, 245, 2196}},
    [220] = {[27] = {1.01, .726, 291, 1991}, [29] = {1.03, .746, 288, 1960}, [31] = {1.05, .768, 284, 1937},
             [33] = {1.07, .789, 280, 1917}, [35] = {1.10, .810, 276, 1896}, [37] = {1.13, .829, 270, 1890},
             [39] = {1.18, .846, 264, 1901}, [41] = {1.24, .860, 257, 1921}, [43] = {1.34, .861, 245, 1943}},
    [200] = {[27] = {1.00, .706, 283, 1850}, [29] = {1.01, .724, 279, 1810}, [31] = {1.03, .745, 275, 1785},
             [33] = {1.05, .767, 272, 1759}, [35] = {1.07, .789, 268, 1738}, [37] = {1.10, .810, 263, 1733},
             [39] = {1.14, .829, 258, 1740}, [41] = {1.18, .846, 252, 1755}, [43] = {1.25, .860, 245, 1760},
             [45] = {1.34, .861, 234, 1775}},
}

-- PI.11.5 (p.271) Long Range Cruise Wind-Altitude Trade: wind factor (kt)
-- by pressure altitude (1000 ft) and cruise weight; the break-even wind at
-- a new altitude = the present wind + (new factor - present factor)
PW.TRADE_W = {400, 380, 360, 340, 320, 300, 280, 260, 240, 220, 200}
PW.TRADE = {
    [45] = {nil, nil, nil, nil, nil, nil, nil, nil, 75, 34, 10},
    [43] = {nil, nil, nil, nil, nil, nil, nil, 66, 30, 9, 1},
    [41] = {nil, nil, nil, nil, nil, nil, 54, 25, 8, 1, 2},
    [39] = {nil, nil, nil, nil, 74, 42, 19, 6, 0, 2, 10},
    [37] = {nil, nil, 88, 55, 30, 13, 3, 0, 3, 10, 22},
    [35] = {nil, 63, 38, 20, 8, 2, 0, 4, 11, 22, 36},
    [33] = {43, 25, 12, 4, 0, 1, 5, 13, 23, 36, 51},
    [31] = {14, 6, 1, 0, 2, 7, 15, 25, 37, 51, 66},
    [29] = {2, 0, 1, 4, 10, 18, 27, 39, 51, 65, 80},
    [27] = {0, 3, 7, 13, 21, 30, 41, 53, 66, 79, 94},
    [25] = {5, 11, 17, 25, 34, 44, 55, 67, 79, 93, 106},
}
-- PI.11.5 (p.271) Descent at .84/290/250: from pressure altitude (1000 ft)
-- the distance (NM) and time (min) to the end of descent (1,500 ft? see
-- the PI text, PI.18)
PW.DESCENT_ALT = {27, 29, 31, 33, 35, 37, 39, 41, 43, 45}
PW.DESCENT_NM = {96, 103, 110, 117, 124, 129, 134, 140, 145, 150}
PW.DESCENT_MIN = {19, 20, 21, 22, 23, 23, 24, 25, 25, 26}

-- PI.11.6 (p.272) Holding, flaps up: by weight and pressure altitude (ft)
-- {EPR, KIAS, fuel flow per engine kg/h}; includes 5 % for the racetrack
PW.HOLD_ALT = {1500, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000}
PW.HOLD = {
    [400] = {{1.02, 286, 3360}, {1.03, 286, 3290}, {1.05, 286, 3200}, {1.08, 286, 3170}, {1.09, 313, 3270}, {1.16, 317, 3340}, {1.30, 322, 3550}},
    [380] = {{1.02, 280, 3190}, {1.03, 280, 3130}, {1.04, 280, 3030}, {1.07, 280, 3000}, {1.08, 306, 3090}, {1.14, 310, 3130}, {1.25, 314, 3270}},
    [360] = {{1.02, 271, 3020}, {1.02, 271, 2970}, {1.04, 271, 2880}, {1.06, 271, 2820}, {1.07, 297, 2910}, {1.12, 300, 2920}, {1.21, 305, 3040}},
    [340] = {{1.02, 261, 2840}, {1.02, 261, 2810}, {1.03, 261, 2730}, {1.05, 261, 2650}, {1.06, 288, 2740}, {1.10, 291, 2730}, {1.19, 295, 2820}, {1.48, 302, 3480}},
    [320] = {{1.02, 251, 2670}, {1.02, 251, 2640}, {1.03, 251, 2590}, {1.05, 251, 2490}, {1.05, 279, 2560}, {1.09, 282, 2550}, {1.16, 286, 2620}, {1.31, 291, 2830}},
    [300] = {{1.01, 242, 2500}, {1.02, 242, 2480}, {1.03, 242, 2440}, {1.05, 242, 2350}, {1.04, 270, 2390}, {1.08, 272, 2380}, {1.14, 276, 2420}, {1.25, 281, 2550}},
    [280] = {{1.01, 233, 2340}, {1.02, 233, 2310}, {1.03, 233, 2280}, {1.04, 233, 2210}, {1.03, 260, 2230}, {1.07, 262, 2220}, {1.12, 266, 2230}, {1.21, 270, 2330}},
    [260] = {{1.01, 228, 2170}, {1.01, 228, 2150}, {1.02, 228, 2130}, {1.03, 228, 2060}, {1.03, 251, 2060}, {1.05, 253, 2050}, {1.10, 255, 2050}, {1.17, 259, 2130}, {1.37, 264, 2430}},
    [240] = {{1.01, 221, 2010}, {1.01, 221, 2000}, {1.02, 221, 1980}, {1.03, 221, 1920}, {1.02, 240, 1900}, {1.04, 242, 1890}, {1.08, 244, 1880}, {1.14, 248, 1920}, {1.27, 252, 2100}},
    [220] = {{1.00, 215, 1860}, {1.01, 215, 1850}, {1.01, 215, 1840}, {1.02, 215, 1780}, {1.02, 229, 1760}, {1.03, 231, 1750}, {1.07, 234, 1740}, {1.12, 236, 1740}, {1.22, 240, 1870}},
    [200] = {{1.00, 208, 1710}, {1.00, 208, 1700}, {1.01, 208, 1690}, {1.01, 208, 1650}, {1.01, 219, 1620}, {1.02, 220, 1600}, {1.05, 222, 1600}, {1.09, 224, 1600}, {1.17, 228, 1660}, {1.34, 233, 1850}},
}

-- PI.10.38-39 (p.264-265) Flight With Unreliable Airspeed, flaps up at
-- .84/290: by weight and pressure altitude (ft) the thrust for level flight
-- {EPR, %N1 (alt mode)} and the idle descent's V/S (ft/min)
PW.U84_W = {200, 250, 300, 350, 390}
PW.U84_CRZ = {
    [40000] = {{1.16, 83.2}, {1.31, 88.0}},
    [35000] = {{1.08, 80.6}, {1.14, 83.0}, {1.24, 86.3}, {1.43, 92.2}},
    [30000] = {{1.02, 77.3}, {1.07, 79.8}, {1.13, 82.6}, {1.21, 85.7}, {1.32, 89.3}},
    [20000] = {{0.97, 70.5}, {0.99, 72.7}, {1.03, 75.3}, {1.07, 78.1}, {1.11, 80.8}},
    [10000] = {{0.96, 64.3}, {0.98, 66.3}, {1.00, 68.7}, {1.02, 71.1}, {1.04, 73.3}},
    [0] = {{0.97, 55.6}, {0.98, 57.8}, {0.99, 60.4}, {1.00, 63.2}, {1.01, 65.7}},
}
PW.U84_DES = {
    [40000] = {-2800, -2700},
    [35000] = {-3800, -3400, -3200, -3300},
    [30000] = {-2600, -2300, -2200, -2100, -2200},
    [20000] = {-2500, -2200, -2100, -2000, -2000},
    [10000] = {-2200, -1900, -1800, -1700, -1700},
    [0] = {-1900, -1700, -1500, -1500, -1500},
}


-- CF6-80C2B1F (747-400F), weights in 1000 lb, fuel flows in lb/h
local GE = {wf = M.LB}
-- PI.21.1 (p.363) Long Range Cruise Maximum Operating Altitude, max climb
-- thrust: thrust-limited entries (100 fpm residual) negative
GE.MAX_ALT_W = {880, 840, 800, 760, 720, 680, 640, 600, 560, 520, 480, 440}
GE.OPT_ALT = {29200, 30200, 31300, 32400, 33600, 34800, 36000, 37400, 38800, 40400, 42000, 43800}
GE.MARGIN_G = {1.20, 1.25, 1.30, 1.40, 1.50}
GE.MAX_ALT = {
    [10] = {
        {33800, 33000, 32100, 30500, 29000},
        {34800, 33900, 33100, 31500, 30000},
        {35800, 35000, 34100, 32600, 31100},
        {36900, 36000, 35200, 33700, 32200},
        {38000, 37200, 36400, 34800, 33300},
        {39200, 38400, 37500, 36000, 34500},
        {40500, 39600, 38800, 37300, 35800},
        {41800, 41000, 40100, 38600, 37200},
        {43200, 42400, 41600, 40000, 38600},
        {-44700, 43900, 43100, 41600, 40100},
        {45000, 45000, 44800, 43200, 41800},
        {45000, 45000, 45000, 45000, 43600},
    },
    [15] = {
        {-33100, 33000, 32100, 30500, 29000},
        {-34200, 33900, 33100, 31500, 30000},
        {-35400, 35000, 34100, 32600, 31100},
        {-36400, 36000, 35200, 33700, 32200},
        {-37600, 37200, 36400, 34800, 33300},
        {-38800, 38400, 37500, 36000, 34500},
        {-40000, 39600, 38800, 37300, 35800},
        {-41300, 41000, 40100, 38600, 37200},
        {-42600, 42400, 41600, 40000, 38600},
        {-44000, 43900, 43100, 41600, 40100},
        {45000, 45000, 44800, 43200, 41800},
        {45000, 45000, 45000, 45000, 43600},
    },
    [20] = {
        {-32000, -32000, -32000, 30500, 29000},
        {-33200, -33200, 33100, 31500, 30000},
        {-34400, -34400, 34100, 32600, 31100},
        {-35600, -35600, 35200, 33700, 32200},
        {-36700, -36700, 36400, 34800, 33300},
        {-37900, -37900, 37500, 36000, 34500},
        {-39200, -39200, 38800, 37300, 35800},
        {-40500, -40500, 40100, 38600, 37200},
        {-41800, -41800, 41600, 40000, 38600},
        {-43200, -43200, 43100, 41600, 40100},
        {-44800, -44800, 44800, 43200, 41800},
        {45000, 45000, 45000, 45000, 43600},
    },
}

-- PI.21.2 (p.364) Long Range Cruise Control: by weight (1000 lb) and
-- pressure altitude (1000 ft) {%N1, Mach, KIAS, fuel flow per engine lb/h}
GE.LRC_ALT = {27, 29, 31, 33, 35, 37, 39, 41, 43, 45}
GE.LRC_W = {880, 840, 800, 760, 720, 680, 640, 600, 560, 520, 480, 440}
GE.LRC = {
    [880] = {[27] = {92.9, .846, 344, 7487}, [29] = {94.3, .851, 332, 7445}, [31] = {96.2, .853, 319, 7501},
             [33] = {99.3, .853, 305, 7707}},
    [840] = {[27] = {91.8, .841, 342, 7145}, [29] = {93.1, .849, 331, 7084}, [31] = {94.7, .852, 319, 7063},
             [33] = {97.1, .853, 305, 7192}, [35] = {101.0, .853, 292, 7451}},
    [800] = {[27] = {90.7, .833, 339, 6803}, [29] = {91.9, .846, 330, 6740}, [31] = {93.3, .851, 318, 6692},
             [33] = {95.2, .853, 305, 6731}, [35] = {98.2, .853, 292, 6887}},
    [760] = {[27] = {89.6, .822, 334, 6450}, [29] = {90.8, .840, 328, 6412}, [31] = {92.1, .849, 317, 6350},
             [33] = {93.6, .852, 305, 6317}, [35] = {96.0, .853, 292, 6395}, [37] = {100.2, .853, 279, 6684}},
    [720] = {[27] = {88.5, .809, 328, 6110}, [29] = {89.7, .830, 323, 6076}, [31] = {90.9, .844, 316, 6025},
             [33] = {92.2, .850, 304, 5967}, [35] = {94.0, .853, 292, 5968}, [37] = {97.3, .853, 279, 6144}},
    [680] = {[27] = {87.3, .796, 322, 5785}, [29] = {88.5, .817, 318, 5731}, [31] = {89.7, .837, 312, 5708},
             [33] = {90.9, .847, 303, 5643}, [35] = {92.4, .852, 292, 5597}, [37] = {95.0, .853, 279, 5678},
             [39] = {99.4, .853, 266, 5953}},
    [640] = {[27] = {86.0, .782, 316, 5462}, [29] = {87.3, .803, 312, 5406}, [31] = {88.4, .824, 307, 5371},
             [33] = {89.6, .842, 301, 5337}, [35] = {90.9, .849, 291, 5272}, [37] = {93.0, .852, 279, 5277},
             [39] = {96.5, .853, 266, 5443}},
    [600] = {[27] = {84.6, .766, 309, 5145}, [29] = {85.9, .788, 305, 5087}, [31] = {87.1, .809, 301, 5039},
             [33] = {88.3, .830, 296, 5019}, [35] = {89.5, .845, 289, 4963}, [37] = {91.3, .851, 278, 4937},
             [39] = {94.1, .853, 266, 5013}, [41] = {98.1, .853, 254, 5203}},
    [560] = {[27] = {83.1, .750, 302, 4828}, [29] = {84.4, .771, 298, 4771}, [31] = {85.7, .793, 295, 4717},
             [33] = {86.9, .814, 290, 4681}, [35] = {88.1, .835, 285, 4657}, [37] = {89.7, .847, 277, 4622},
             [39] = {92.1, .852, 266, 4637}, [41] = {95.2, .853, 254, 4740}, [43] = {99.6, .853, 243, 4958}},
    [520] = {[27] = {81.4, .730, 293, 4494}, [29] = {82.9, .754, 291, 4460}, [31] = {84.2, .775, 287, 4396},
             [33] = {85.5, .798, 284, 4354}, [35] = {86.6, .819, 279, 4322}, [37] = {88.2, .839, 274, 4318},
             [39] = {90.3, .848, 265, 4314}, [41] = {92.8, .852, 254, 4339}, [43] = {96.1, .853, 243, 4454}},
    [480] = {[27] = {79.6, .706, 283, 4156}, [29] = {81.1, .732, 282, 4134}, [31] = {82.5, .756, 280, 4083},
             [33] = {83.8, .778, 276, 4029}, [35] = {85.1, .801, 272, 3996}, [37] = {86.6, .823, 268, 3991},
             [39] = {88.7, .841, 262, 4007}, [41] = {90.8, .849, 253, 4006}, [43] = {93.4, .852, 243, 4037},
             [45] = {96.9, .853, 232, 4158}},
    [440] = {[27] = {77.7, .683, 273, 3835}, [29] = {79.1, .707, 272, 3800}, [31] = {80.6, .733, 270, 3759},
             [33] = {82.0, .758, 268, 3713}, [35] = {83.3, .780, 264, 3675}, [37] = {84.9, .803, 261, 3665},
             [39] = {86.9, .825, 257, 3683}, [41] = {89.0, .843, 251, 3697}, [43] = {91.1, .850, 242, 3695},
             [45] = {93.8, .852, 232, 3728}},
}

-- PI.21.5 (p.367) Long Range Cruise Wind-Altitude Trade (kt) by pressure
-- altitude (1000 ft) and cruise weight (1000 lb)
GE.TRADE_W = {880, 840, 800, 760, 720, 680, 640, 600, 560, 520, 480, 440}
GE.TRADE = {
    [45] = {nil, nil, nil, nil, nil, nil, nil, nil, nil, 39, 16, 3},
    [43] = {nil, nil, nil, nil, nil, nil, nil, 60, 32, 13, 2, 0},
    [41] = {nil, nil, nil, nil, nil, nil, 45, 23, 9, 1, 0, 4},
    [39] = {nil, nil, nil, nil, 55, 32, 16, 5, 0, 0, 5, 13},
    [37] = {nil, nil, 59, 37, 21, 9, 2, 0, 1, 6, 15, 26},
    [35] = {59, 39, 23, 12, 4, 0, 0, 3, 8, 16, 27, 40},
    [33] = {24, 13, 6, 1, 0, 1, 5, 11, 19, 29, 41, 55},
    [31] = {6, 2, 0, 0, 3, 7, 14, 22, 32, 43, 55, 69},
    [29] = {0, 0, 2, 6, 11, 18, 26, 35, 46, 57, 70, 83},
    [27] = {2, 5, 9, 15, 22, 30, 39, 49, 60, 71, 83, 96},
    [25] = {9, 14, 20, 27, 34, 43, 52, 63, 73, 85, 96, 108},
}
-- PI.21.5 (p.367) Descent at .84/290/250: distance (NM) and time (min)
GE.DESCENT_ALT = {19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45}
GE.DESCENT_NM = {75, 82, 89, 97, 104, 112, 119, 126, 133, 138, 144, 149, 155, 159}
GE.DESCENT_MIN = {16, 17, 18, 19, 21, 22, 23, 23, 24, 25, 26, 26, 27, 28}

-- PI.21.6 (p.368) Holding, flaps up: by weight (1000 lb) and pressure
-- altitude (ft) {%N1, KIAS, fuel flow per engine lb/h}; 5 % for the racetrack
GE.HOLD_ALT = {1500, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000}
GE.HOLD = {
    [880] = {{70.9, 286, 6770}, {73.7, 286, 6710}, {77.7, 286, 6710}, {81.8, 286, 6750}, {85.9, 304, 6890}, {90.1, 308, 7100}, {94.5, 312, 7470}},
    [840] = {{69.6, 280, 6460}, {72.4, 280, 6400}, {76.4, 280, 6380}, {80.5, 280, 6400}, {84.6, 297, 6520}, {88.8, 300, 6680}, {93.1, 305, 6980}, {100.7, 279, 7560}},
    [800] = {{68.2, 272, 6140}, {70.9, 272, 6080}, {75.0, 272, 6060}, {79.1, 272, 6060}, {83.3, 289, 6140}, {87.4, 292, 6290}, {91.7, 297, 6540}, {97.6, 279, 6920}},
    [760] = {{66.9, 263, 5830}, {69.5, 263, 5770}, {73.5, 263, 5740}, {77.7, 263, 5740}, {81.9, 282, 5790}, {86.0, 285, 5910}, {90.2, 289, 6110}, {95.4, 279, 6420}},
    [720] = {{65.3, 255, 5520}, {68.0, 255, 5460}, {72.0, 255, 5430}, {76.2, 255, 5420}, {80.5, 274, 5450}, {84.5, 277, 5550}, {88.8, 280, 5710}, {93.4, 279, 5990}},
    [680] = {{63.6, 246, 5220}, {66.5, 246, 5160}, {70.5, 246, 5120}, {74.7, 246, 5100}, {78.9, 266, 5130}, {83.0, 268, 5190}, {87.3, 272, 5320}, {91.7, 276, 5580}},
    [640] = {{61.9, 238, 4930}, {64.8, 238, 4870}, {68.8, 238, 4820}, {73.0, 238, 4790}, {77.3, 258, 4810}, {81.4, 260, 4850}, {85.7, 263, 4940}, {90.0, 267, 5150}, {98.2, 249, 5610}},
    [600] = {{60.2, 231, 4640}, {63.0, 231, 4580}, {67.1, 231, 4520}, {71.2, 231, 4480}, {75.6, 249, 4510}, {79.8, 251, 4520}, {83.9, 254, 4570}, {88.3, 257, 4740}, {95.3, 249, 5110}},
    [560] = {{58.5, 226, 4360}, {61.2, 226, 4300}, {65.4, 226, 4230}, {69.4, 226, 4180}, {73.8, 240, 4210}, {78.0, 242, 4210}, {82.2, 245, 4230}, {86.5, 248, 4350}, {92.8, 249, 4690}},
    [520] = {{56.5, 219, 4090}, {59.3, 219, 4020}, {63.4, 219, 3950}, {67.4, 219, 3890}, {71.8, 231, 3920}, {76.1, 233, 3910}, {80.3, 235, 3890}, {84.6, 238, 3980}, {90.7, 242, 4250}, {100.7, 222, 4750}},
    [480] = {{54.6, 214, 3830}, {57.3, 214, 3750}, {61.3, 214, 3680}, {65.4, 214, 3610}, {69.8, 222, 3630}, {74.0, 223, 3630}, {78.3, 226, 3570}, {82.5, 228, 3630}, {88.6, 231, 3840}, {96.2, 222, 4170}},
    [440] = {{52.6, 207, 3570}, {55.2, 207, 3490}, {59.2, 207, 3410}, {63.3, 207, 3340}, {67.5, 212, 3350}, {71.8, 214, 3340}, {76.0, 215, 3270}, {80.3, 218, 3290}, {86.3, 221, 3450}, {93.1, 222, 3730}},
}

-- PI.20.33 (p.361) Flight With Unreliable Airspeed, flaps up at .84/290: by
-- weight (1000 lb) and pressure altitude (ft) the %N1 for level flight and
-- the idle descent's V/S (ft/min)
GE.U84_W = {450, 550, 650, 750, 850, 870}
GE.U84_CRZ = {
    [40000] = {{88.4}, {92.6}},
    [35000] = {{85.8}, {88.1}, {90.9}, {95.0}},
    [30000] = {{81.8}, {84.4}, {86.9}, {89.9}, {93.7}, {94.6}},
    [20000] = {{74.4}, {76.6}, {79.2}, {81.8}, {84.9}, {85.5}},
    [10000] = {{67.1}, {69.1}, {71.4}, {73.9}, {76.8}, {77.4}},
    [0] = {{60.0}, {61.9}, {64.0}, {66.3}, {68.9}, {69.5}},
}
GE.U84_DES = {
    [40000] = {-3000, -2900},
    [35000] = {-3600, -3300, -3100, -3200},
    [30000] = {-2500, -2200, -2100, -2100, -2100, -2100},
    [20000] = {-2200, -2000, -1900, -1800, -1800, -1800},
    [10000] = {-2000, -1800, -1700, -1600, -1600, -1600},
    [0] = {-1600, -1400, -1300, -1300, -1300, -1300},
}


-- the tables for an engine type (laminar/B747/engines/type: 0 PW, 1 GE, 2 RR)
function M.tables(engine_type)
    if engine_type == 1 then return GE end
    return PW
end

-- a row of cells keyed by the list's values, some missing: the value at x
-- among the present ones (within them), as a table of the cells' fields
local function row_at(list, cells, x)
    local keys = {}
    for _, k in ipairs(list) do if cells[k] then keys[#keys + 1] = k end end
    if #keys == 0 then return nil end
    local i, j, f = bracket(keys, x)
    local a, b = cells[keys[i]], cells[keys[j]]
    local v = {}
    for n = 1, #a do v[n] = lerp(a[n], b[n], f) end
    return v
end

-- the weight in the tables' unit (1000 kg or 1000 lb)
local function tw(t, kg) return kg / 1000 / t.wf end

-- long range cruise at a weight (kg) and pressure altitude (ft): Mach,
-- KIAS, fuel flow per engine (kg/h) and the thrust setting (EPR for PW,
-- %N1 for GE); within the tables (the heaviest weights' highest altitudes
-- are their maximum)
function M.lrc(t, kg, ft)
    local w, a = tw(t, kg), ft / 1000
    local i, j, f = bracket(t.LRC_W, w)
    local r1 = row_at(t.LRC_ALT, t.LRC[t.LRC_W[i]], a)
    local r2 = row_at(t.LRC_ALT, t.LRC[t.LRC_W[j]], a)
    local v = {}
    for n = 1, 4 do v[n] = lerp(r1[n], r2[n], f) end
    return v[2], v[3], v[4] * t.wf, v[1]
end

-- the optimum altitude (ft) at a weight (kg), PI.11.1
function M.opt_alt(t, kg)
    local i, j, f = bracket(t.MAX_ALT_W, tw(t, kg))
    return lerp(t.OPT_ALT[i], t.OPT_ALT[j], f)
end

-- the maximum altitude (ft) at a weight (kg), the ISA deviation (degrees C,
-- the tables' ISA+10 and below, +15, +20: beyond them their ends) and the
-- margin to initial buffet (g, default MARGIN_G), PI.11.1; and whether it
-- is thrust limited there (100 fpm residual climb)
function M.max_alt(t, kg, isa_dev, margin)
    local w = tw(t, kg)
    local wi, wj, wf = bracket(t.MAX_ALT_W, w)
    local mi, mj, mf = bracket(t.MARGIN_G, margin or M.MARGIN_G)
    local function at(tbl)
        local function cell(r, c) return tbl[r][c] end
        local lim = cell(wi, mi) < 0 or cell(wj, mj) < 0
        local a = lerp(lerp(math.abs(cell(wi, mi)), math.abs(cell(wi, mj)), mf),
            lerp(math.abs(cell(wj, mi)), math.abs(cell(wj, mj)), mf), wf)
        return a, lim
    end
    local d = isa_dev or 0
    local a1, l1, a2, l2, f
    if d <= 10 then
        a1, l1 = at(t.MAX_ALT[10]); return a1, l1
    elseif d <= 15 then
        a1, l1 = at(t.MAX_ALT[10]); a2, l2 = at(t.MAX_ALT[15]); f = (d - 10) / 5
    elseif d <= 20 then
        a1, l1 = at(t.MAX_ALT[15]); a2, l2 = at(t.MAX_ALT[20]); f = (d - 15) / 5
    else
        a1, l1 = at(t.MAX_ALT[20]); return a1, l1
    end
    return lerp(a1, a2, f), (f < 0.5 and l1 or l2)
end

-- the heaviest weight (kg) at which the maximum altitude reaches ft, by
-- bisection within the tables' weights (their lightest if none does)
function M.max_alt_weight(t, ft, isa_dev, margin)
    local w = t.MAX_ALT_W
    local lo, hi = w[#w] * 1000 * t.wf, w[1] * 1000 * t.wf
    if M.max_alt(t, lo, isa_dev, margin) < ft then return lo end
    if M.max_alt(t, hi, isa_dev, margin) >= ft then return hi end
    for _ = 1, 40 do
        local mid = (lo + hi) / 2
        if M.max_alt(t, mid, isa_dev, margin) >= ft then lo = mid else hi = mid end
    end
    return lo
end

-- holding (flaps up) at a weight (kg) and pressure altitude (ft): KIAS and
-- fuel flow per engine (kg/h, the racetrack's 5 % in), PI.11.6
function M.hold(t, kg, ft)
    local w = tw(t, kg)
    -- (the holding tables' weights are the long range cruise's)
    local i, j, f = bracket(t.LRC_W, w)
    local function row(wr)
        local cells = {}
        for n, alt in ipairs(t.HOLD_ALT) do cells[alt] = t.HOLD[wr][n] end
        return row_at(t.HOLD_ALT, cells, ft)
    end
    local r1, r2 = row(t.LRC_W[i]), row(t.LRC_W[j])
    return lerp(r1[2], r2[2], f), lerp(r1[3], r2[3], f) * t.wf
end

-- the .84/290/250 descent from a pressure altitude (ft): distance (NM) and
-- time (min) to its end, PI.11.5 (below the table's lowest altitude in
-- proportion to it: an estimate)
function M.descent(t, ft)
    local a = ft / 1000
    local lo = t.DESCENT_ALT[1]
    if a < lo then
        local k = math.max(0, a) / lo
        return t.DESCENT_NM[1] * k, t.DESCENT_MIN[1] * k
    end
    local i, j, f = bracket(t.DESCENT_ALT, a)
    return lerp(t.DESCENT_NM[i], t.DESCENT_NM[j], f), lerp(t.DESCENT_MIN[i], t.DESCENT_MIN[j], f)
end

-- the wind-altitude trade's wind factor (kt) at a weight (kg) and pressure
-- altitude (ft), PI.11.5; nil where the table has none (above the weight's
-- altitudes)
function M.wind_factor(t, kg, ft)
    local w, a = tw(t, kg), ft / 1000
    local alts = {}
    for k in pairs(t.TRADE) do alts[#alts + 1] = k end
    table.sort(alts)
    local ai, aj, af = bracket(alts, a)
    local function at(alt)
        local cells = {}
        for n, wt in ipairs(t.TRADE_W) do cells[wt] = t.TRADE[alt][n] and {t.TRADE[alt][n]} end
        local wi, wj = bracket(t.TRADE_W, w)
        if not (cells[t.TRADE_W[wi]] and cells[t.TRADE_W[wj]]) then return nil end
        return row_at(t.TRADE_W, cells, w)[1]
    end
    local v1, v2 = at(alts[ai]), at(alts[aj])
    if not (v1 and v2) then return nil end
    return lerp(v1, v2, af)
end

-- ---------------------------------------------------------------------------
-- The cruise model (6-1/6-2 step 8b; notes/ATA-34-61-FMC.md §45), an
-- estimate: a drag polar and a fuel consumption fitted to the tables' long
-- range cruise (Mach and fuel flow) and holding (fuel flow) by
-- tests/tools/perf_fit.lua:
--   CL = W / (q S), CD = CD0 + K CL^2 + KW (M - MC)^4 above MC = MC0 - MCL CL
--        + KD (M - MD)^4 above MD (the drag divergence)
--   fuel flow = (T0 + T1 M) (1 + T2 100 kN / (F / delta)) sqrt(theta) F
--   (F an engine's thrust, the drag over 4: kg/h per N; T2 the part power's
--   higher consumption)
-- The drag's scale from the idle descents' V/S at .84/290 (PI.10.39/20.33,
-- the idle thrust taken as none); the drag divergence from the tables' long
-- range cruise stopping at about .861 whatever the weight and the economy
-- speed reaching the speed limit at a cost index of about 5000 (FCTM p.4.7).
-- From it the fuel flow at any Mach, the maximum range cruise, the minimum
-- drag speed, the thrust setting for level flight and the economy speeds
-- for a cost index: the FMS pilot's guide (p.261) defines the index as the
-- time's cost per hour over the fuel's in cents per pound, so a unit is
-- 100 lb of fuel an hour.

local G, RAIR, P0, T0K, A0_KT, KT = 9.80665, 287.053, 101325, 288.15, 661.4786, 0.514444
M.S = 541.16                -- wing area (m2), 5,825 sq ft
M.VMO, M.MMO = 365, 0.92
M.ECON_CLB_KT = 340         -- the economy climb without the FMC's data, 340/.84 (FCTM p.4.3; PI.10.36's climb EPR too)
M.ECON_DES_KT = 290         -- the .84/290/250 descent (PI.11.5)
M.ECON_CLB_MAX = 360        -- an estimate: the FMS pilot's guide's climb page shows 358/.853 (p.112)
M.ECON_DES_MAX = 349        -- VMO/MMO less 16 kt (FCOM p.1258)
M.ECON_CI_LIMIT = 5000      -- where the economy speeds reach their limits (FCTM p.4.7)

-- (perf_fit.lua: PW the long range cruise's fuel flow 1.7 % rms and Mach
-- 0.0025, holding 1.3 %, the descent's drag 5.6 %; GE 1.1 %, 0.0015, 1.3 %,
-- 6.5 %)
PW.POLAR = {cd0 = 0.016338, k = 0.047216, kw = 0.25926, mc0 = 0.78895, mcl = 0.59575, t0 = 0.047924, t1 = 0.014737, t2 = 0.045172, kd = 5819.7, md = 0.8483}
GE.POLAR = {cd0 = 0.015534, k = 0.042486, kw = 0.20291, mc0 = 0.79383, mcl = 0.63214, t0 = 0.051024, t1 = 0.015894, t2 = 0.015392, kd = 1579.6, md = 0.83273}
-- the thrust setting for level flight (tests/tools/thrust_fit.lua): EPR (PW,
-- 0.01 rms) or N1 / sqrt(theta_t2) (GE, 0.4-0.9 % rms) = C1 + C2 M + C3 M^2
-- + (C4 + C5 M) x + C6 x^2, x an engine's thrust / delta / 100 kN
PW.THRUST = {1.12261, -0.881672, 0.58381, 0.473007, -0.47932, 0.0810096}
GE.THRUST = {29.6446, 32.3389, 16.5883, 69.155, -62.4791, -0.284529}
GE.N1 = true

-- the ISA atmosphere at a pressure altitude (ft): static pressure (Pa) and
-- the temperature (K) with an ISA deviation (degrees C)
function M.atmos(ft, isa_dev)
    local h = ft * 0.3048
    local t, p
    if h <= 11000 then
        t = T0K - 0.0065 * h
        p = P0 * (t / T0K) ^ 5.255877
    else
        t = 216.65
        p = 22632.06 * math.exp(-G * (h - 11000) / (RAIR * 216.65))
    end
    return p, t + (isa_dev or 0)
end

-- Mach and calibrated airspeed (kt) at a pressure altitude (ft)
function M.cas_to_mach(kt, ft)
    local qc = P0 * ((1 + 0.2 * (kt / A0_KT) ^ 2) ^ 3.5 - 1)
    return math.sqrt(5 * ((qc / M.atmos(ft) + 1) ^ (2 / 7) - 1))
end
function M.mach_to_cas(mach, ft)
    local qc = M.atmos(ft) * ((1 + 0.2 * mach * mach) ^ 3.5 - 1)
    return A0_KT * math.sqrt(5 * ((qc / P0 + 1) ^ (2 / 7) - 1))
end

-- the true airspeed (kt)
function M.tas(mach, ft, isa_dev)
    local _, t = M.atmos(ft, isa_dev)
    return mach * math.sqrt(1.4 * RAIR * t) / KT
end

-- the drag (N) and the lift coefficient in level flight at a weight (kg),
-- pressure altitude (ft) and Mach
function M.drag(t, kg, ft, mach)
    local c = t.POLAR
    local q = 0.7 * M.atmos(ft) * mach * mach
    local cl = kg * G / (q * M.S)
    local cd = c.cd0 + c.k * cl * cl
    local dm = mach - (c.mc0 - c.mcl * cl)
    if dm > 0 then cd = cd + c.kw * dm ^ 4 end
    if mach > c.md then cd = cd + c.kd * (mach - c.md) ^ 4 end
    return q * M.S * cd, cl
end

-- the fuel flow per engine (kg/h) in level flight there
function M.cruise_ff(t, kg, ft, mach, isa_dev)
    local c = t.POLAR
    local p, temp = M.atmos(ft, isa_dev)
    local f = M.drag(t, kg, ft, mach) / 4
    return (c.t0 + c.t1 * mach) * (1 + c.t2 * 1e5 / (f / (p / P0))) * math.sqrt(temp / T0K) * f
end

-- the x in [a, b] where f is least (golden section: f unimodal there)
local function least(f, a, b, tol)
    local r = (math.sqrt(5) - 1) / 2
    local c, d = b - r * (b - a), a + r * (b - a)
    local fc, fd = f(c), f(d)
    while b - a > (tol or 1e-4) do
        if fc < fd then
            b, d, fd = d, c, fc
            c = b - r * (b - a); fc = f(c)
        else
            a, c, fc = c, d, fd
            d = a + r * (b - a); fd = f(d)
        end
    end
    return (a + b) / 2
end
M.least = least

local MACH_LO, MACH_HI = 0.40, 0.95

-- the fuel (kg) per NM in still air, all engines
local function per_nm(t, kg, ft, mach, isa_dev)
    return 4 * M.cruise_ff(t, kg, ft, mach, isa_dev) / M.tas(mach, ft, isa_dev)
end

-- the maximum range cruise Mach: the least fuel per NM in still air
function M.mrc(t, kg, ft, isa_dev)
    return least(function(m) return per_nm(t, kg, ft, m, isa_dev) end, MACH_LO, MACH_HI)
end

-- the model's long range cruise Mach, above the maximum range cruise with
-- 1 % less NM per kg (FCTM p.4.7): to check the fit against the tables
function M.lrc_model(t, kg, ft, isa_dev)
    local lo = M.mrc(t, kg, ft, isa_dev)
    local target = per_nm(t, kg, ft, lo, isa_dev) / 0.99
    local hi = MACH_HI
    if per_nm(t, kg, ft, hi, isa_dev) < target then return hi end
    for _ = 1, 40 do
        local mid = (lo + hi) / 2
        if per_nm(t, kg, ft, mid, isa_dev) < target then lo = mid else hi = mid end
    end
    return (lo + hi) / 2
end

-- the minimum drag speed at a weight (kg) and pressure altitude (ft): the
-- Mach and CAS (kt)
function M.min_drag(t, kg, ft)
    local m = least(function(x) return (M.drag(t, kg, ft, x)) end, 0.2, MACH_HI)
    return m, M.mach_to_cas(m, ft)
end

-- the economy targets' limit, VMO/MMO less 16 kt (FCOM p.1258), at a
-- pressure altitude (ft): Mach and CAS (kt)
function M.econ_limit(ft)
    local cas = math.min(M.VMO, M.mach_to_cas(M.MMO, ft)) - 16
    return M.cas_to_mach(cas, ft), cas
end

-- the economy cruise Mach at a weight (kg), pressure altitude (ft), cost
-- index and headwind (kt, a tailwind negative): the least cost per NM over
-- the ground, (fuel + 100 CI lb an hour) / ground speed; not below the
-- still-air maximum range cruise (FCTM p.4.7) nor above the limit
function M.econ_cruise(t, kg, ft, ci, headwind, isa_dev)
    local hw = headwind or 0
    local c = (ci or 0) * 100 * M.LB
    local function cost(m)
        local gs = M.tas(m, ft, isa_dev) - hw
        if gs < 50 then return math.huge end
        return (4 * M.cruise_ff(t, kg, ft, m, isa_dev) + c) / gs
    end
    local m = least(cost, MACH_LO, MACH_HI)
    return math.max(M.mrc(t, kg, ft, isa_dev), math.min(M.econ_limit(ft), m)), m
end

-- the thrust setting for level flight at a weight (kg), pressure altitude
-- (ft), Mach and ISA deviation: EPR (PW; RR too) or %N1 (GE), the CRZ
-- page's (FCOM p.1348)
function M.level_setting(t, kg, ft, mach, isa_dev)
    local c = t.THRUST
    local p, temp = M.atmos(ft, isa_dev)
    local x = M.drag(t, kg, ft, mach) / 4 / (p / P0) / 1e5
    local v = c[1] + c[2] * mach + c[3] * mach * mach + (c[4] + c[5] * mach) * x + c[6] * x * x
    if t.N1 then v = v * math.sqrt(temp / T0K * (1 + 0.2 * mach * mach)) end
    return v
end

-- the cost index's place at a weight and cruise altitude, an estimate (no
-- table): from 0 at the still-air maximum range cruise to 1 where the
-- still-air economy cruise is the long range cruise (the index CI_L), then
-- to 2 with the log of the index from CI_L to 5000, where the limits come
-- (FCTM p.4.7); and the economy cruise Mach. The economy climb's and
-- descent's speeds follow it.
local function econ_index(t, kg, ft, ci, isa_dev)
    local mrc = M.mrc(t, kg, ft, isa_dev)
    local lrc = M.lrc_model(t, kg, ft, isa_dev)
    local m = M.econ_cruise(t, kg, ft, ci, 0, isa_dev)
    local r = (m - mrc) / math.max(lrc - mrc, 0.005)
    if r < 1 then return math.max(0, r), m end
    if ci >= M.ECON_CI_LIMIT then return 2, m end
    local lo, hi = 0, ci
    for _ = 1, 30 do
        local mid = (lo + hi) / 2
        if M.econ_cruise(t, kg, ft, mid, 0, isa_dev) < lrc then lo = mid else hi = mid end
    end
    local cil = math.max(hi, 1)
    return 1 + math.log(math.max(ci, cil) / cil) / math.log(M.ECON_CI_LIMIT / cil), m
end
M.econ_index = econ_index

-- a speed by the index: v0 at 0, v1 at 1, v2 at 2
local function by_index(r, v0, v1, v2)
    if r <= 1 then return v0 + (v1 - v0) * r end
    return v1 + (v2 - v1) * (r - 1)
end

-- the economy climb at a weight (kg), cruise altitude (ft) and cost index:
-- CAS (kt) and Mach. The Mach is the economy cruise's at the cruise
-- altitude (FCTM p.4.3). The CAS, an estimate, from about the maximum rate
-- climb at index 0 (the minimum drag speed + 60 kt, as the FCTM's flaps up
-- maneuvering speed + 60, p.4.3) through 340 kt at 1 to 360 kt at 2; for a
-- low cruise altitude up to the cruise's CAS (FCTM p.4.3).
function M.econ_climb(t, kg, crz_ft, ci, isa_dev)
    local r, mach = econ_index(t, kg, crz_ft, ci, isa_dev)
    local _, vmd = M.min_drag(t, kg, 10000)
    local cas = by_index(r, vmd + 60, M.ECON_CLB_KT, M.ECON_CLB_MAX)
    return math.min(M.ECON_CLB_MAX, math.max(cas, M.mach_to_cas(mach, crz_ft))), mach
end

-- the economy descent at a weight (kg), cruise altitude (ft) and cost index:
-- Mach (the economy cruise's) and CAS (kt), an estimate: from the minimum
-- drag speed at index 0 (the best glide) through 290 kt at 1 to 349 kt at
-- 2 (FCOM p.1258)
function M.econ_descent(t, kg, crz_ft, ci, isa_dev)
    local r, mach = econ_index(t, kg, crz_ft, ci, isa_dev)
    local _, vmd = M.min_drag(t, kg, 10000)
    return mach, math.min(M.ECON_DES_MAX, by_index(r, vmd, M.ECON_DES_KT, M.ECON_DES_MAX))
end

return M
