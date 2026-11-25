-- 747-400 EFB takeoff on contaminated runways without X-Plane (2026-11-25,
-- the takeoff and landing performance window): the FPPM's ADVISORY
-- INFORMATION for slush/standing water and slippery runway takeoffs
-- (747-400F/PW4056, D632U002-RZ043 Rev 7): the full rating p.36-40
-- (1.2.12-16), TO1 8 % p.48-53 (1.3.2-7), TO2 20 % p.60-65 (1.3.14-19),
-- 2 engine reverse thrust and no reverse thrust, worked as the FPPM's
-- method (p.20-21 (1.1.2-3)):
--  - the weight (p.20 steps 1-4): the field/obstacle limit weight (the
--    rating's own: the TO1 and TO2 tables are entered with the derate's,
--    their notes 1) plus the Weight Adjustment table's adjustment for the
--    depth (slippery: the reported braking action) at the pressure altitude;
--    the VMCG Limit Weight table's weight for the field length available,
--    the depth (braking action) and the pressure altitude, less the notes'
--    kg for flaps 10; the maximum allowable takeoff weight the lesser;
--  - V1 (p.21 steps 1-2): the normal V1 for the actual weight (the
--    caller's); VMCG limited: V1 = VMCG; else plus the V1 Adjustment
--    table's adjustment for the weight, depth (braking action) and pressure
--    altitude, plus the notes' kt for flaps 10, not below VMCG (not above
--    VR: the caller's);
--  - slush/standing water deeper than 0.50 in (13 mm) is not recommended
--    (p.20): nil, the reason. The assumed temperature method is not allowed
--    on contaminated runways (p.20, p.22): the caller's (these tables are
--    the full rating's and the derates').
-- Between the printed values: linear in the depth (p.20 permits it between
-- the depths shown), in the pressure altitude and along the rows.
-- Estimates (the FPPM does not give these):
--  - thrust reductions between 0, 8 and 20 % (the GE's 5 and 15 %: FCOM
--    p.1314): linear between the ratings' results;
--  - below sea level: the S.L. column;
--  - a field/obstacle limit weight above the table's heaviest printed row
--    (slush 440 t, but 420 t at 3 mm with 2 engine reverse: p.36, p.48 and
--    p.60 leave that 440 t cell blank; slippery 400 t): that row's
--    adjustment held (the adjustments change by 0 to 3 t a row there);
--    below the lightest row: nil;
--  - a VMCG Limit Weight column read past its printed cells (a staircase:
--    each column printed only over a band of weights) to interpolate
--    between columns: its end step carried on; past the heavy end the
--    weight is above every printed one (not limiting); past the light end
--    only while the result is not lighter than that column's lightest
--    printed weight (else nil: the field too short);
--  - p.48 (1.3.2) prints "28" for TO1 slush 2 engine reverse V1 adjustment
--    at 380 t, 3 mm, 4000 ft: every other cell of that table is negative,
--    its column runs -27, 28, -29: taken as -28 (M.MISPRINTS);
--  - p.64 (1.3.18) says to INCREASE the TO2 slippery no reverse VMCG limit
--    weight by 19000 kg for flaps 10 and poor braking action; every other
--    page decreases it (p.40 and p.52 by 18000 kg for the same case) and
--    flaps 10's higher speeds need more runway: taken as a decrease.
-- GE and RR on the PW4056 freighter's data (estimate, as the rest of the
-- EFB's takeoff). Pure: no datarefs.
--
--   local C = B747_efb_contam_model
--   local w, work = C.limit("SLUSH", 6, 2, 0, field_kg, fla_ft, pa_ft, flaps)
--   local v1, vw = C.v1("SLUSH", 6, 2, 0, tow_kg, v1_dry, vmcg, work.vmcg_limited, pa_ft, flaps)
-- kind "SLUSH" (slush/standing water: depth in mm, 3 to 13) or "SLIPPERY"
-- (reported braking action "GOOD", "MEDIUM", "POOR"); reversers 2 (2
-- engine reverse thrust) or 0 (none); rating_pct the thrust reduction (0,
-- 8, 20; between: estimate); flaps 10 or 20 (nil: 20, the tables' own).
local M = setmetatable({}, {})
B747_efb_contam_model = M

M.SLUSH_MAX_MM = 13            -- deeper not recommended (FPPM p.20 (1.1.2))
M.SLUSH_MIN_MM = 3             -- the tables' shallowest column

-- BEGIN GENERATED DATA (docs/overhaul/tools/fppm_contam.lua from
-- _ref/1059530115-74F-FPPM.pdf's text runs; do not edit by hand)
--
-- M.DATA[rating %][kind][reverse thrust engines] = {wa, vmcg, v1}, the
-- FPPM's ADVISORY INFORMATION tables (747-400F/PW4056, D632U002-RZ043):
--   wa    Weight Adjustment (1000 KG), rows the field/obstacle limit
--         weight (1000 kg; the derate's own for TO1 and TO2)
--   vmcg  VMCG Limit Weight (1000 KG), rows the field length available (ft)
--   v1    V1 Adjustment (KIAS), rows the (actual) weight (1000 kg)
-- A row as printed: {row, then 3 columns (S.L., 4000, 8000 ft pressure
-- altitude) for each of 3 mm, 6 mm, 13 mm slush/standing water depth or
-- GOOD, MEDIUM, POOR reported braking action}; false a blank cell.
-- f10: the notes' flaps 10 change as printed (vmcg kg, v1 kt; + an
-- increase), f10_cond the braking action it is for (nil: every column).
-- n: the table's printed cells.
M.TABLE_COUNT = 36
M.CELL_COUNT = 2733
M.DEPTH_MM = {3, 6, 13}            -- 0.12, 0.25, 0.50 INCHES
M.BRAKING_COLS = {GOOD = 1, MEDIUM = 2, POOR = 3}
M.ALT_FT = {0, 4000, 8000}         -- S.L., 4000, 8000
M.DATA = {
    [0] = {
        SLUSH = {
            [2] = {
                -- FPPM p.36 (1.2.12) Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 36, sec = "1.2.12", n = 78,
                    {440, false, false, false, -35, -35, -35, -52, -52, -52},
                    {420, -27, -27, -27, -34, -34, -34, -51, -51, -51},
                    {400, -25, -25, -25, -32, -32, -32, -50, -50, -50},
                    {380, -24, -24, -24, -31, -31, -31, -48, -48, -48},
                    {360, -22, -22, -22, -29, -29, -29, -47, -47, -47},
                    {340, -21, -21, -21, -28, -28, -28, -46, -46, -46},
                    {320, -19, -19, -19, -26, -26, -26, -45, -45, -45},
                    {300, -18, -18, -18, -25, -25, -25, -44, -44, -44},
                    {280, -16, -16, -16, -23, -23, -23, -42, -42, -42},
                },
                -- FPPM p.36 (1.2.12) Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 36, sec = "1.2.12", n = 81, f10 = -12000,
                    {8200, false, false, false, false, false, false, 222, false, false},
                    {8600, false, false, false, false, false, false, 244, false, false},
                    {9000, false, false, false, 230, false, false, 267, false, false},
                    {9400, 228, false, false, 253, false, false, 290, 220, false},
                    {9800, 252, false, false, 276, false, false, 312, 242, false},
                    {10200, 275, false, false, 299, 228, false, 335, 265, false},
                    {10600, 298, 226, false, 322, 251, false, 357, 287, 217},
                    {11000, 322, 250, false, 346, 274, false, 380, 310, 240},
                    {11400, 346, 273, false, 369, 297, false, 403, 333, 262},
                    {11800, 370, 296, 223, 392, 320, 249, false, 355, 285},
                    {12200, 394, 320, 247, 415, 343, 272, false, 378, 308},
                    {12600, 417, 344, 271, 438, 366, 295, false, 400, 330},
                    {13000, false, 367, 294, false, 389, 318, false, false, 353},
                    {13400, false, 391, 318, false, 412, 341, false, false, 375},
                    {13800, false, 415, 341, false, 436, 364, false, false, 398},
                    {14200, false, false, 365, false, false, 387, false, false, false},
                    {14600, false, false, 389, false, false, 410, false, false, false},
                },
                -- FPPM p.36 (1.2.12) Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 36, sec = "1.2.12", n = 63, f10 = -1,
                    {400, -31, -29, -27, -27, -25, -23, -16, -14, -12},
                    {380, -32, -30, -28, -28, -26, -24, -17, -15, -13},
                    {360, -33, -31, -29, -29, -27, -25, -19, -17, -15},
                    {340, -34, -32, -30, -30, -28, -26, -21, -19, -17},
                    {320, -35, -33, -31, -31, -29, -27, -23, -21, -19},
                    {300, -35, -33, -31, -32, -30, -28, -25, -23, -21},
                    {280, -35, -33, -31, -32, -30, -28, -26, -24, -22},
                },
            },
            [0] = {
                -- FPPM p.37 (1.2.13) Slush/Standing Water Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 37, sec = "1.2.13", n = 81,
                    {440, -32, -32, -32, -41, -41, -41, -64, -64, -64},
                    {420, -31, -31, -31, -39, -39, -39, -61, -61, -61},
                    {400, -29, -29, -29, -37, -37, -37, -58, -58, -58},
                    {380, -27, -27, -27, -35, -35, -35, -55, -55, -55},
                    {360, -25, -25, -25, -33, -33, -33, -52, -52, -52},
                    {340, -23, -23, -23, -30, -30, -30, -50, -50, -50},
                    {320, -21, -21, -21, -28, -28, -28, -47, -47, -47},
                    {300, -19, -19, -19, -26, -26, -26, -44, -44, -44},
                    {280, -18, -18, -18, -24, -24, -24, -41, -41, -41},
                },
                -- FPPM p.37 (1.2.13) Slush/Standing Water Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 37, sec = "1.2.13", n = 67, f10 = -14000,
                    {10200, false, false, false, false, false, false, 257, false, false},
                    {10600, false, false, false, false, false, false, 280, false, false},
                    {11000, false, false, false, false, false, false, 304, false, false},
                    {11400, false, false, false, 262, false, false, 327, 262, false},
                    {11800, false, false, false, 288, false, false, 351, 285, false},
                    {12200, 266, false, false, 314, 241, false, 374, 308, 243},
                    {12600, 294, false, false, 340, 267, false, 397, 332, 266},
                    {13000, 321, 245, false, 366, 293, false, 421, 355, 290},
                    {13400, 348, 272, false, 392, 320, 247, 444, 379, 313},
                    {13800, 375, 299, false, 418, 346, 273, 468, 402, 337},
                    {14200, 402, 326, 250, 444, 372, 299, false, 425, 360},
                    {14600, 430, 354, 277, 470, 398, 325, false, 449, 383},
                    {15000, 457, 381, 305, false, 424, 351, false, 472, 407},
                },
                -- FPPM p.37 (1.2.13) Slush/Standing Water Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 37, sec = "1.2.13", n = 63, f10 = -3,
                    {400, -39, -37, -34, -34, -31, -28, -21, -18, -15},
                    {380, -41, -38, -35, -35, -33, -30, -23, -20, -17},
                    {360, -42, -39, -36, -37, -34, -31, -24, -22, -19},
                    {340, -42, -39, -37, -38, -35, -32, -26, -24, -21},
                    {320, -43, -40, -37, -39, -36, -33, -29, -26, -23},
                    {300, -43, -40, -37, -39, -37, -34, -31, -28, -25},
                    {280, -43, -40, -38, -40, -38, -35, -33, -30, -27},
                },
            },
        },
        SLIPPERY = {
            [2] = {
                -- FPPM p.38 (1.2.14) Slippery Runway Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 38, sec = "1.2.14", n = 81,
                    {400, 0, 0, 0, -6, -6, -6, -18, -18, -18},
                    {380, 0, 0, 0, -7, -7, -7, -17, -17, -17},
                    {360, 0, 0, 0, -7, -7, -7, -16, -16, -16},
                    {340, 0, 0, 0, -6, -6, -6, -15, -15, -15},
                    {320, 0, 0, 0, -6, -6, -6, -14, -14, -14},
                    {300, 0, 0, 0, -6, -6, -6, -12, -12, -12},
                    {280, 0, 0, 0, -5, -5, -5, -11, -11, -11},
                    {260, 0, 0, 0, -4, -4, -4, -9, -9, -9},
                    {240, 0, 0, 0, -3, -3, -3, -7, -7, -7},
                },
                -- FPPM p.38 (1.2.14) Slippery Runway Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 38, sec = "1.2.14", n = 62, f10 = -10000, f10_cond = "POOR",
                    {6000, 236, false, false, false, false, false, false, false, false},
                    {6400, 279, 193, false, false, false, false, false, false, false},
                    {6800, 322, 236, false, false, false, false, false, false, false},
                    {7200, 365, 279, 193, false, false, false, false, false, false},
                    {7600, 408, 322, 236, false, false, false, false, false, false},
                    {8000, false, 365, 279, 211, false, false, false, false, false},
                    {8400, false, 408, 322, 246, false, false, false, false, false},
                    {8800, false, false, 365, 281, false, false, false, false, false},
                    {9200, false, false, 408, 317, 238, false, false, false, false},
                    {9600, false, false, false, 352, 273, false, false, false, false},
                    {10000, false, false, false, 387, 308, 230, false, false, false},
                    {10400, false, false, false, 422, 343, 265, false, false, false},
                    {10800, false, false, false, false, 379, 300, false, false, false},
                    {11200, false, false, false, false, 414, 335, 227, false, false},
                    {11600, false, false, false, false, false, 370, 250, false, false},
                    {12000, false, false, false, false, false, 406, 275, false, false},
                    {12400, false, false, false, false, false, false, 299, 230, false},
                    {12800, false, false, false, false, false, false, 323, 254, false},
                    {13200, false, false, false, false, false, false, 347, 279, false},
                    {13600, false, false, false, false, false, false, 372, 303, 234},
                    {14000, false, false, false, false, false, false, 396, 327, 258},
                    {14400, false, false, false, false, false, false, 420, 351, 282},
                    {14800, false, false, false, false, false, false, false, 376, 307},
                    {15200, false, false, false, false, false, false, false, 400, 331},
                    {15600, false, false, false, false, false, false, false, 424, 355},
                    {16000, false, false, false, false, false, false, false, false, 388},
                    {16400, false, false, false, false, false, false, false, false, 412},
                },
                -- FPPM p.39 (1.2.15) Slippery Runway Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 39, sec = "1.2.15", n = 81, f10 = 1, f10_cond = "GOOD",
                    {400, -6, -5, -4, -23, -19, -16, -43, -38, -33},
                    {380, -8, -7, -6, -25, -21, -18, -46, -41, -36},
                    {360, -9, -8, -7, -27, -23, -20, -48, -43, -38},
                    {340, -11, -10, -9, -29, -25, -22, -50, -45, -40},
                    {320, -13, -12, -11, -31, -27, -24, -52, -47, -42},
                    {300, -14, -13, -12, -32, -28, -25, -53, -48, -43},
                    {280, -15, -14, -13, -33, -29, -26, -54, -49, -44},
                    {260, -15, -14, -13, -34, -30, -27, -54, -49, -44},
                    {240, -15, -14, -13, -34, -30, -27, -54, -49, -44},
                },
            },
            [0] = {
                -- FPPM p.40 (1.2.16) Slippery Runway Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 40, sec = "1.2.16", n = 81,
                    {400, 0, 0, 0, -10, -10, -10, -21, -21, -21},
                    {380, 0, 0, 0, -9, -9, -9, -20, -20, -20},
                    {360, 0, 0, 0, -9, -9, -9, -19, -19, -19},
                    {340, 0, 0, 0, -9, -9, -9, -18, -18, -18},
                    {320, -1, -1, -1, -8, -8, -8, -16, -16, -16},
                    {300, -1, -1, -1, -7, -7, -7, -14, -14, -14},
                    {280, -1, -1, -1, -7, -7, -7, -13, -13, -13},
                    {260, 0, 0, 0, -6, -6, -6, -11, -11, -11},
                    {240, 0, 0, 0, -4, -4, -4, -9, -9, -9},
                },
                -- FPPM p.40 (1.2.16) Slippery Runway Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 40, sec = "1.2.16", n = 34, f10 = -18000, f10_cond = "POOR",
                    {6200, 210, false, false, false, false, false, false, false, false},
                    {6600, 258, false, false, false, false, false, false, false, false},
                    {7000, 306, 229, false, false, false, false, false, false, false},
                    {7400, 353, 277, 201, false, false, false, false, false, false},
                    {7800, 401, 325, 249, false, false, false, false, false, false},
                    {8200, false, 372, 296, false, false, false, false, false, false},
                    {8600, false, 420, 344, false, false, false, false, false, false},
                    {9000, false, false, 391, false, false, false, false, false, false},
                    {9400, false, false, 439, 224, false, false, false, false, false},
                    {9800, false, false, false, 269, false, false, false, false, false},
                    {10200, false, false, false, 314, 233, false, false, false, false},
                    {10600, false, false, false, 359, 278, false, false, false, false},
                    {11000, false, false, false, 404, 323, 242, false, false, false},
                    {11400, false, false, false, false, 368, 287, false, false, false},
                    {11800, false, false, false, false, 413, 332, false, false, false},
                    {12200, false, false, false, false, false, 377, false, false, false},
                    {12600, false, false, false, false, false, 422, false, false, false},
                    {13000, false, false, false, false, false, false, false, false, false},
                    {13400, false, false, false, false, false, false, false, false, false},
                    {13800, false, false, false, false, false, false, false, false, false},
                    {14200, false, false, false, false, false, false, 205, false, false},
                    {14600, false, false, false, false, false, false, 239, false, false},
                    {15000, false, false, false, false, false, false, 274, false, false},
                },
                -- FPPM p.40 (1.2.16) Slippery Runway Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 40, sec = "1.2.16", n = 81, f10 = 2, f10_cond = "GOOD",
                    {400, -8, -6, -5, -28, -24, -21, -54, -50, -46},
                    {380, -10, -8, -7, -30, -27, -23, -56, -52, -48},
                    {360, -12, -10, -9, -33, -29, -26, -59, -55, -51},
                    {340, -14, -12, -11, -35, -31, -28, -61, -57, -53},
                    {320, -16, -14, -12, -37, -34, -30, -63, -59, -55},
                    {300, -17, -16, -14, -39, -36, -32, -65, -61, -57},
                    {280, -19, -17, -16, -41, -37, -34, -66, -62, -58},
                    {260, -20, -18, -16, -42, -38, -34, -67, -63, -59},
                    {240, -20, -18, -16, -42, -38, -35, -67, -63, -59},
                },
            },
        },
    },
    [8] = {
        SLUSH = {
            [2] = {
                -- FPPM p.48 (1.3.2) TO1 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 48, sec = "1.3.2", n = 78,
                    {440, false, false, false, -34, -34, -34, -49, -49, -49},
                    {420, -27, -27, -27, -33, -33, -33, -48, -48, -48},
                    {400, -25, -25, -25, -31, -31, -31, -46, -46, -46},
                    {380, -24, -24, -24, -30, -30, -30, -45, -45, -45},
                    {360, -22, -22, -22, -28, -28, -28, -44, -44, -44},
                    {340, -20, -20, -20, -27, -27, -27, -43, -43, -43},
                    {320, -19, -19, -19, -25, -25, -25, -42, -42, -42},
                    {300, -17, -17, -17, -24, -24, -24, -40, -40, -40},
                    {280, -16, -16, -16, -22, -22, -22, -39, -39, -39},
                },
                -- FPPM p.48 (1.3.2) TO1 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 48, sec = "1.3.2", n = 74, f10 = -12000,
                    {7800, false, false, false, false, false, false, 222, false, false},
                    {8200, false, false, false, false, false, false, 246, false, false},
                    {8600, false, false, false, 233, false, false, 270, false, false},
                    {9000, 232, false, false, 257, false, false, 293, 220, false},
                    {9400, 257, false, false, 281, false, false, 317, 244, false},
                    {9800, 282, false, false, 306, 230, false, 341, 267, false},
                    {10200, 306, 230, false, 330, 255, false, 365, 291, 218},
                    {10600, 331, 255, false, 354, 279, false, 388, 315, 241},
                    {11000, 356, 279, false, 378, 303, 228, 412, 338, 265},
                    {11400, 381, 304, 227, 402, 327, 252, false, 362, 289},
                    {11800, 405, 329, 252, false, 352, 276, false, 386, 312},
                    {12200, false, 353, 277, false, 376, 301, false, 410, 336},
                    {12600, false, 378, 301, false, 400, 325, false, false, 360},
                    {13000, false, 403, 326, false, false, 349, false, false, 384},
                    {13400, false, false, 351, false, false, 373, false, false, 407},
                    {13800, false, false, 376, false, false, 398, false, false, false},
                },
                -- FPPM p.48 (1.3.2) TO1 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 48, sec = "1.3.2", n = 63, f10 = -1,
                    {400, -29, -27, -25, -24, -22, -20, -11, -9, -7},
                    {380, -30, 28, -26, -25, -23, -21, -12, -10, -8},
                    {360, -31, -29, -27, -26, -24, -22, -14, -12, -10},
                    {340, -32, -30, -28, -27, -25, -23, -17, -15, -13},
                    {320, -32, -30, -28, -28, -26, -24, -19, -17, -15},
                    {300, -33, -31, -29, -29, -27, -25, -21, -19, -17},
                    {280, -33, -31, -29, -29, -27, -25, -22, -20, -18},
                },
            },
            [0] = {
                -- FPPM p.49 (1.3.3) TO1 Slush/Standing Water Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 49, sec = "1.3.3", n = 81,
                    {440, -31, -31, -31, -39, -39, -39, -62, -62, -62},
                    {420, -29, -29, -29, -37, -37, -37, -59, -59, -59},
                    {400, -27, -27, -27, -35, -35, -35, -56, -56, -56},
                    {380, -26, -26, -26, -33, -33, -33, -53, -53, -53},
                    {360, -24, -24, -24, -31, -31, -31, -51, -51, -51},
                    {340, -22, -22, -22, -29, -29, -29, -48, -48, -48},
                    {320, -20, -20, -20, -27, -27, -27, -45, -45, -45},
                    {300, -19, -19, -19, -25, -25, -25, -42, -42, -42},
                    {280, -17, -17, -17, -23, -23, -23, -40, -40, -40},
                },
                -- FPPM p.49 (1.3.3) TO1 Slush/Standing Water Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 49, sec = "1.3.3", n = 73, f10 = -14000,
                    {9400, false, false, false, false, false, false, 241, false, false},
                    {9800, false, false, false, false, false, false, 266, false, false},
                    {10200, false, false, false, false, false, false, 290, false, false},
                    {10600, false, false, false, 248, false, false, 314, 246, false},
                    {11000, false, false, false, 274, false, false, 338, 270, false},
                    {11400, 253, false, false, 301, false, false, 362, 295, false},
                    {11800, 281, false, false, 328, 253, false, 387, 319, 251},
                    {12200, 309, false, false, 355, 280, false, 411, 343, 275},
                    {12600, 337, 259, false, 382, 307, false, 435, 367, 299},
                    {13000, 366, 287, false, 409, 334, 258, 459, 391, 324},
                    {13400, 394, 315, false, 436, 361, 285, false, 416, 348},
                    {13800, 422, 343, 264, 463, 388, 312, false, 440, 372},
                    {14200, 450, 371, 292, false, 415, 339, false, 464, 396},
                    {14600, 478, 399, 321, false, 441, 366, false, false, 420},
                    {15000, false, 427, 349, false, 468, 393, false, false, 445},
                },
                -- FPPM p.49 (1.3.3) TO1 Slush/Standing Water Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 49, sec = "1.3.3", n = 99, f10 = -3,
                    {400, -34, -31, -28, -28, -25, -22, -13, -10, -7},
                    {380, -36, -33, -30, -30, -27, -23, -15, -12, -9},
                    {360, -37, -34, -31, -31, -28, -25, -17, -14, -11},
                    {340, -38, -34, -31, -33, -29, -26, -20, -16, -13},
                    {320, -38, -35, -32, -34, -30, -27, -22, -19, -16},
                    {300, -38, -35, -32, -34, -31, -28, -24, -21, -18},
                    {280, -39, -36, -32, -36, -32, -29, -27, -24, -21},
                    {260, -38, -35, -32, -35, -32, -29, -29, -25, -22},
                    {240, -36, -33, -29, -34, -30, -27, -28, -25, -22},
                    {220, -35, -32, -29, -33, -30, -27, -29, -26, -23},
                    {200, -35, -32, -28, -33, -30, -27, -30, -27, -23},
                },
            },
        },
        SLIPPERY = {
            [2] = {
                -- FPPM p.50 (1.3.4) TO1 Slippery Runway Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 50, sec = "1.3.4", n = 90,
                    {400, 0, 0, 0, -4, -4, -4, -16, -16, -16},
                    {380, 0, 0, 0, -5, -5, -5, -16, -16, -16},
                    {360, 0, 0, 0, -6, -6, -6, -16, -16, -16},
                    {340, 0, 0, 0, -6, -6, -6, -15, -15, -15},
                    {320, 0, 0, 0, -6, -6, -6, -14, -14, -14},
                    {300, 0, 0, 0, -6, -6, -6, -12, -12, -12},
                    {280, 0, 0, 0, -5, -5, -5, -11, -11, -11},
                    {260, 0, 0, 0, -5, -5, -5, -9, -9, -9},
                    {240, 0, 0, 0, -4, -4, -4, -8, -8, -8},
                    {220, 0, 0, 0, -3, -3, -3, -6, -6, -6},
                },
                -- FPPM p.50 (1.3.4) TO1 Slippery Runway Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 50, sec = "1.3.4", n = 66, f10 = -10000, f10_cond = "POOR",
                    {5600, 216, false, false, false, false, false, false, false, false},
                    {6000, 258, false, false, false, false, false, false, false, false},
                    {6400, 301, 216, false, false, false, false, false, false, false},
                    {6800, 344, 258, false, false, false, false, false, false, false},
                    {7200, 387, 301, 216, false, false, false, false, false, false},
                    {7600, 429, 344, 258, 208, false, false, false, false, false},
                    {8000, false, 387, 301, 245, false, false, false, false, false},
                    {8400, false, 429, 344, 281, 201, false, false, false, false},
                    {8800, false, false, 387, 317, 237, false, false, false, false},
                    {9200, false, false, 429, 354, 274, 194, false, false, false},
                    {9600, false, false, false, 390, 310, 230, false, false, false},
                    {10000, false, false, false, 426, 346, 266, false, false, false},
                    {10400, false, false, false, false, 383, 303, 207, false, false},
                    {10800, false, false, false, false, 419, 339, 232, false, false},
                    {11200, false, false, false, false, false, 375, 258, false, false},
                    {11600, false, false, false, false, false, 412, 283, 212, false},
                    {12000, false, false, false, false, false, false, 308, 237, false},
                    {12400, false, false, false, false, false, false, 333, 263, false},
                    {12800, false, false, false, false, false, false, 357, 288, 217},
                    {13200, false, false, false, false, false, false, 382, 313, 242},
                    {13600, false, false, false, false, false, false, 408, 338, 268},
                    {14000, false, false, false, false, false, false, false, 363, 293},
                    {14400, false, false, false, false, false, false, false, 388, 318},
                    {14800, false, false, false, false, false, false, false, 413, 343},
                    {15200, false, false, false, false, false, false, false, false, 367},
                    {15600, false, false, false, false, false, false, false, false, 393},
                    {16000, false, false, false, false, false, false, false, false, 418},
                },
                -- FPPM p.51 (1.3.5) TO1 Slippery Runway Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 51, sec = "1.3.5", n = 90, f10 = 1, f10_cond = "GOOD",
                    {400, -4, -3, -2, -19, -15, -12, -39, -34, -29},
                    {380, -6, -5, -4, -22, -18, -15, -41, -36, -31},
                    {360, -8, -7, -6, -25, -21, -18, -44, -39, -34},
                    {340, -10, -9, -8, -27, -23, -20, -47, -42, -37},
                    {320, -11, -10, -9, -29, -25, -22, -49, -44, -39},
                    {300, -12, -11, -10, -31, -27, -24, -50, -45, -40},
                    {280, -13, -12, -11, -32, -28, -25, -50, -45, -40},
                    {260, -14, -13, -12, -32, -28, -25, -50, -45, -40},
                    {240, -14, -13, -12, -32, -28, -25, -50, -45, -40},
                    {220, -14, -13, -12, -32, -28, -25, -50, -45, -40},
                },
            },
            [0] = {
                -- FPPM p.52 (1.3.6) TO1 Slippery Runway Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 52, sec = "1.3.6", n = 90,
                    {400, 0, 0, 0, -7, -7, -7, -19, -19, -19},
                    {380, 0, 0, 0, -7, -7, -7, -18, -18, -18},
                    {360, 0, 0, 0, -7, -7, -7, -17, -17, -17},
                    {340, 0, 0, 0, -7, -7, -7, -16, -16, -16},
                    {320, 0, 0, 0, -7, -7, -7, -15, -15, -15},
                    {300, 0, 0, 0, -6, -6, -6, -14, -14, -14},
                    {280, 0, 0, 0, -6, -6, -6, -12, -12, -12},
                    {260, 0, 0, 0, -5, -5, -5, -10, -10, -10},
                    {240, 0, 0, 0, -4, -4, -4, -9, -9, -9},
                    {220, 0, 0, 0, -3, -3, -3, -7, -7, -7},
                },
                -- FPPM p.52 (1.3.6) TO1 Slippery Runway Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 52, sec = "1.3.6", n = 43, f10 = -18000, f10_cond = "POOR",
                    {5800, 197, false, false, false, false, false, false, false, false},
                    {6200, 243, false, false, false, false, false, false, false, false},
                    {6600, 289, 215, false, false, false, false, false, false, false},
                    {7000, 335, 261, 188, false, false, false, false, false, false},
                    {7400, 382, 307, 233, false, false, false, false, false, false},
                    {7800, 429, 354, 280, false, false, false, false, false, false},
                    {8200, false, 401, 326, false, false, false, false, false, false},
                    {8600, false, false, 373, 189, false, false, false, false, false},
                    {9000, false, false, 419, 233, false, false, false, false, false},
                    {9400, false, false, false, 277, 197, false, false, false, false},
                    {9800, false, false, false, 322, 242, false, false, false, false},
                    {10200, false, false, false, 367, 286, 206, false, false, false},
                    {10600, false, false, false, 411, 331, 251, false, false, false},
                    {11000, false, false, false, false, 375, 295, false, false, false},
                    {11400, false, false, false, false, 420, 340, false, false, false},
                    {11800, false, false, false, false, false, 384, false, false, false},
                    {12200, false, false, false, false, false, 429, false, false, false},
                    {12600, false, false, false, false, false, false, false, false, false},
                    {13000, false, false, false, false, false, false, false, false, false},
                    {13400, false, false, false, false, false, false, 197, false, false},
                    {13800, false, false, false, false, false, false, 233, false, false},
                    {14200, false, false, false, false, false, false, 269, 182, false},
                    {14600, false, false, false, false, false, false, 305, 218, false},
                    {15000, false, false, false, false, false, false, 341, 255, false},
                },
                -- FPPM p.53 (1.3.7) TO1 Slippery Runway Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 53, sec = "1.3.7", n = 90, f10 = 2, f10_cond = "GOOD",
                    {400, -5, -3, -1, -22, -18, -15, -46, -42, -37},
                    {380, -7, -5, -3, -25, -21, -17, -50, -45, -40},
                    {360, -9, -7, -5, -28, -24, -20, -53, -48, -44},
                    {340, -11, -9, -7, -30, -26, -22, -56, -51, -46},
                    {320, -12, -11, -9, -33, -29, -25, -58, -53, -49},
                    {300, -14, -12, -11, -35, -31, -27, -60, -55, -51},
                    {280, -16, -14, -12, -37, -33, -28, -62, -57, -52},
                    {260, -17, -15, -13, -38, -34, -30, -62, -58, -53},
                    {240, -17, -15, -13, -38, -34, -30, -62, -58, -53},
                    {220, -16, -15, -13, -38, -34, -29, -62, -57, -52},
                },
            },
        },
    },
    [20] = {
        SLUSH = {
            [2] = {
                -- FPPM p.60 (1.3.14) TO2 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 60, sec = "1.3.14", n = 78,
                    {440, false, false, false, -33, -33, -33, -46, -46, -46},
                    {420, -28, -28, -28, -32, -32, -32, -44, -44, -44},
                    {400, -26, -26, -26, -31, -31, -31, -43, -43, -43},
                    {380, -24, -24, -24, -29, -29, -29, -42, -42, -42},
                    {360, -23, -23, -23, -28, -28, -28, -41, -41, -41},
                    {340, -21, -21, -21, -26, -26, -26, -40, -40, -40},
                    {320, -20, -20, -20, -25, -25, -25, -38, -38, -38},
                    {300, -18, -18, -18, -23, -23, -23, -37, -37, -37},
                    {280, -16, -16, -16, -22, -22, -22, -36, -36, -36},
                },
                -- FPPM p.60 (1.3.14) TO2 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 60, sec = "1.3.14", n = 74, f10 = -12000,
                    {7000, false, false, false, false, false, false, 209, false, false},
                    {7400, false, false, false, false, false, false, 234, false, false},
                    {7800, false, false, false, 223, false, false, 260, false, false},
                    {8200, 223, false, false, 248, false, false, 285, 207, false},
                    {8600, 250, false, false, 274, false, false, 310, 232, false},
                    {9000, 276, false, false, 300, 220, false, 335, 257, false},
                    {9400, 302, 221, false, 326, 246, false, 361, 282, 204},
                    {9800, 329, 247, false, 352, 272, false, 386, 308, 229},
                    {10200, 355, 273, false, 377, 297, 217, 411, 333, 255},
                    {10600, 382, 299, 218, 403, 323, 243, false, 358, 280},
                    {11000, 407, 326, 245, false, 349, 269, false, 383, 305},
                    {11400, false, 352, 271, false, 375, 295, false, 409, 330},
                    {11800, false, 379, 297, false, 401, 321, false, false, 356},
                    {12200, false, 406, 323, false, false, 346, false, false, 381},
                    {12600, false, false, 350, false, false, 372, false, false, 406},
                    {13000, false, false, 376, false, false, 398, false, false, false},
                },
                -- FPPM p.60 (1.3.14) TO2 Slush/Standing Water Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 60, sec = "1.3.14", n = 63, f10 = -1,
                    {400, -24, -22, -20, -18, -16, -14, -3, -1, 0},
                    {380, -25, -23, -21, -20, -18, -16, -5, -3, -1},
                    {360, -27, -25, -23, -21, -19, -17, -7, -5, -3},
                    {340, -28, -26, -24, -22, -20, -18, -10, -8, -6},
                    {320, -28, -26, -24, -24, -22, -20, -12, -10, -8},
                    {300, -29, -27, -25, -25, -23, -21, -14, -12, -10},
                    {280, -29, -27, -25, -25, -23, -21, -17, -15, -13},
                },
            },
            [0] = {
                -- FPPM p.61 (1.3.15) TO2 Slush/Standing Water Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 61, sec = "1.3.15", n = 81,
                    {440, -34, -34, -34, -42, -42, -42, -64, -64, -64},
                    {420, -32, -32, -32, -40, -40, -40, -61, -61, -61},
                    {400, -30, -30, -30, -38, -38, -38, -58, -58, -58},
                    {380, -28, -28, -28, -36, -36, -36, -55, -55, -55},
                    {360, -26, -26, -26, -34, -34, -34, -53, -53, -53},
                    {340, -24, -24, -24, -31, -31, -31, -50, -50, -50},
                    {320, -23, -23, -23, -29, -29, -29, -47, -47, -47},
                    {300, -21, -21, -21, -27, -27, -27, -44, -44, -44},
                    {280, -19, -19, -19, -25, -25, -25, -41, -41, -41},
                },
                -- FPPM p.61 (1.3.15) TO2 Slush/Standing Water Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 61, sec = "1.3.15", n = 75, f10 = -15000,
                    {9000, false, false, false, false, false, false, 265, false, false},
                    {9400, false, false, false, false, false, false, 291, false, false},
                    {9800, false, false, false, 251, false, false, 317, 245, false},
                    {10200, false, false, false, 280, false, false, 343, 271, false},
                    {10600, 261, false, false, 309, false, false, 369, 297, false},
                    {11000, 291, false, false, 338, 257, false, 395, 322, 250},
                    {11400, 321, false, false, 367, 286, false, 421, 348, 276},
                    {11800, 351, 267, false, 396, 315, false, 447, 374, 302},
                    {12200, 382, 297, false, 424, 344, 263, 473, 400, 328},
                    {12600, 412, 327, 243, 453, 372, 292, false, 426, 354},
                    {13000, 442, 357, 273, false, 401, 321, false, 452, 380},
                    {13400, 472, 388, 303, false, 430, 349, false, 478, 405},
                    {13800, false, 418, 333, false, 459, 378, false, false, 431},
                    {14200, false, 448, 363, false, false, 407, false, false, 457},
                    {14600, false, 478, 394, false, false, 436, false, false, false},
                    {15000, false, false, 424, false, false, 465, false, false, false},
                },
                -- FPPM p.61 (1.3.15) TO2 Slush/Standing Water Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 61, sec = "1.3.15", n = 99, f10 = -3,
                    {400, -27, -23, -20, -20, -16, -12, -3, 1, 5},
                    {380, -29, -25, -21, -22, -18, -14, -5, -1, 2},
                    {360, -30, -26, -23, -23, -20, -16, -7, -4, 0},
                    {340, -31, -27, -23, -25, -21, -18, -10, -6, -3},
                    {320, -31, -27, -24, -26, -22, -19, -13, -9, -5},
                    {300, -31, -28, -24, -27, -23, -20, -16, -12, -8},
                    {280, -32, -29, -25, -29, -25, -21, -19, -15, -12},
                    {260, -32, -28, -25, -29, -25, -22, -21, -18, -14},
                    {240, -30, -26, -23, -27, -24, -20, -21, -18, -14},
                    {220, -29, -26, -22, -27, -24, -20, -22, -19, -15},
                    {200, -29, -26, -22, -28, -24, -20, -24, -20, -16},
                },
            },
        },
        SLIPPERY = {
            [2] = {
                -- FPPM p.62 (1.3.16) TO2 Slippery Runway Takeoff, 2 Engine Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 62, sec = "1.3.16", n = 90,
                    {400, 0, 0, 0, -7, -7, -7, -18, -18, -18},
                    {380, 0, 0, 0, -7, -7, -7, -16, -16, -16},
                    {360, 0, 0, 0, -6, -6, -6, -15, -15, -15},
                    {340, 0, 0, 0, -5, -5, -5, -14, -14, -14},
                    {320, 0, 0, 0, -5, -5, -5, -13, -13, -13},
                    {300, 0, 0, 0, -4, -4, -4, -11, -11, -11},
                    {280, 0, 0, 0, -4, -4, -4, -10, -10, -10},
                    {260, 0, 0, 0, -3, -3, -3, -9, -9, -9},
                    {240, 0, 0, 0, -2, -2, -2, -8, -8, -8},
                    {220, 0, 0, 0, -2, -2, -2, -7, -7, -7},
                },
                -- FPPM p.62 (1.3.16) TO2 Slippery Runway Takeoff, 2 Engine Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 62, sec = "1.3.16", n = 65, f10 = -10000, f10_cond = "POOR",
                    {5200, 211, false, false, false, false, false, false, false, false},
                    {5600, 253, false, false, false, false, false, false, false, false},
                    {6000, 294, 211, false, false, false, false, false, false, false},
                    {6400, 335, 253, false, false, false, false, false, false, false},
                    {6800, 377, 294, 211, false, false, false, false, false, false},
                    {7200, 418, 335, 253, 218, false, false, false, false, false},
                    {7600, false, 377, 294, 254, false, false, false, false, false},
                    {8000, false, 418, 335, 290, 210, false, false, false, false},
                    {8400, false, false, 377, 326, 247, false, false, false, false},
                    {8800, false, false, 418, 363, 283, 203, false, false, false},
                    {9200, false, false, false, 399, 319, 239, false, false, false},
                    {9600, false, false, false, false, 355, 275, 199, false, false},
                    {10000, false, false, false, false, 392, 312, 226, false, false},
                    {10400, false, false, false, false, 428, 348, 253, false, false},
                    {10800, false, false, false, false, false, 384, 281, 205, false},
                    {11200, false, false, false, false, false, 421, 307, 232, false},
                    {11600, false, false, false, false, false, false, 334, 259, false},
                    {12000, false, false, false, false, false, false, 361, 286, 210},
                    {12400, false, false, false, false, false, false, 388, 313, 237},
                    {12800, false, false, false, false, false, false, 414, 340, 264},
                    {13200, false, false, false, false, false, false, false, 366, 291},
                    {13600, false, false, false, false, false, false, false, 393, 318},
                    {14000, false, false, false, false, false, false, false, 420, 345},
                    {14400, false, false, false, false, false, false, false, false, 372},
                    {14800, false, false, false, false, false, false, false, false, 399},
                    {15200, false, false, false, false, false, false, false, false, 426},
                },
                -- FPPM p.63 (1.3.17) TO2 Slippery Runway Takeoff, 2 Engine Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 63, sec = "1.3.17", n = 90, f10 = 1, f10_cond = "GOOD",
                    {400, -1, 0, 1, -16, -12, -9, -30, -25, -20},
                    {380, -4, -3, -2, -17, -13, -10, -33, -28, -23},
                    {360, -6, -5, -4, -20, -16, -13, -37, -32, -27},
                    {340, -8, -7, -6, -23, -19, -16, -43, -38, -33},
                    {320, -10, -9, -8, -26, -22, -19, -43, -38, -33},
                    {300, -11, -10, -9, -28, -24, -21, -45, -40, -35},
                    {280, -12, -11, -10, -30, -26, -23, -46, -41, -36},
                    {260, -13, -12, -11, -31, -27, -24, -47, -42, -37},
                    {240, -13, -12, -11, -31, -27, -24, -47, -42, -37},
                    {220, -12, -11, -10, -30, -26, -23, -47, -42, -37},
                },
            },
            [0] = {
                -- FPPM p.64 (1.3.18) TO2 Slippery Runway Takeoff, No Reverse Thrust, Weight Adjustment (1000 KG)
                wa = {page = 64, sec = "1.3.18", n = 90,
                    {400, 0, 0, 0, -7, -7, -7, -19, -19, -19},
                    {380, 0, 0, 0, -7, -7, -7, -18, -18, -18},
                    {360, 0, 0, 0, -7, -7, -7, -17, -17, -17},
                    {340, 0, 0, 0, -7, -7, -7, -16, -16, -16},
                    {320, 0, 0, 0, -7, -7, -7, -15, -15, -15},
                    {300, 0, 0, 0, -6, -6, -6, -14, -14, -14},
                    {280, 0, 0, 0, -6, -6, -6, -13, -13, -13},
                    {260, 0, 0, 0, -5, -5, -5, -11, -11, -11},
                    {240, 0, 0, 0, -4, -4, -4, -9, -9, -9},
                    {220, 0, 0, 0, -4, -4, -4, -8, -8, -8},
                },
                -- FPPM p.64 (1.3.18) TO2 Slippery Runway Takeoff, No Reverse Thrust, VMCG Limit Weight (1000 KG)
                vmcg = {page = 64, sec = "1.3.18", n = 48, f10 = 19000, f10_cond = "POOR",
                    {5400, 200, false, false, false, false, false, false, false, false},
                    {5800, 243, false, false, false, false, false, false, false, false},
                    {6200, 287, 217, false, false, false, false, false, false, false},
                    {6600, 331, 261, 191, false, false, false, false, false, false},
                    {7000, 376, 305, 235, false, false, false, false, false, false},
                    {7400, 422, 349, 278, false, false, false, false, false, false},
                    {7800, false, 394, 322, false, false, false, false, false, false},
                    {8200, false, false, 367, 222, false, false, false, false, false},
                    {8600, false, false, 413, 266, 188, false, false, false, false},
                    {9000, false, false, false, 310, 231, false, false, false, false},
                    {9400, false, false, false, 354, 275, 196, false, false, false},
                    {9800, false, false, false, 398, 319, 240, false, false, false},
                    {10200, false, false, false, false, 363, 283, false, false, false},
                    {10600, false, false, false, false, 407, 327, false, false, false},
                    {11000, false, false, false, false, false, 372, false, false, false},
                    {11400, false, false, false, false, false, 416, false, false, false},
                    {11800, false, false, false, false, false, false, false, false, false},
                    {12200, false, false, false, false, false, false, false, false, false},
                    {12600, false, false, false, false, false, false, 218, false, false},
                    {13000, false, false, false, false, false, false, 256, false, false},
                    {13400, false, false, false, false, false, false, 294, 203, false},
                    {13800, false, false, false, false, false, false, 332, 240, false},
                    {14200, false, false, false, false, false, false, 370, 278, 187},
                    {14600, false, false, false, false, false, false, 408, 316, 225},
                    {15000, false, false, false, false, false, false, false, 354, 263},
                },
                -- FPPM p.65 (1.3.19) TO2 Slippery Runway Takeoff, No Reverse Thrust, V1 Adjustment (KIAS)
                v1 = {page = 65, sec = "1.3.19", n = 90, f10 = 2, f10_cond = "GOOD",
                    {400, 0, 0, 0, -14, -10, -6, -35, -29, -24},
                    {380, -2, -1, 0, -17, -13, -9, -40, -34, -28},
                    {360, -4, -3, -1, -20, -16, -12, -44, -38, -32},
                    {340, -6, -5, -3, -23, -19, -14, -50, -44, -37},
                    {320, -8, -7, -5, -26, -21, -17, -57, -51, -45},
                    {300, -10, -8, -7, -29, -24, -19, -65, -59, -53},
                    {280, -12, -10, -9, -31, -26, -22, -62, -56, -50},
                    {260, -14, -12, -10, -33, -28, -23, -59, -53, -47},
                    {240, -14, -12, -10, -34, -29, -24, -56, -51, -45},
                    {220, -14, -12, -10, -33, -28, -23, -56, -50, -44},
                },
            },
        },
    },
}
-- END GENERATED DATA

-- cells printed wrong, taken as `used` (see the header)
M.MISPRINTS = {
    {rating = 8, kind = "SLUSH", rev = 2, tbl = "v1", row = 380, col = 2, printed = 28, used = -28},
}

local EPS = 1e-6

------------------------------------------------------------------------
-- the columns: COLS[table][column 1-9] = {x = {...}, v = {...}}, the
-- printed cells only, x (the row) rising
------------------------------------------------------------------------
local COLS = {}
do
    for _, mp in ipairs(M.MISPRINTS) do mp.applied = false end
    for rating, kinds in pairs(M.DATA) do
        for kind, revs in pairs(kinds) do
            for rev, tbls in pairs(revs) do
                for name, t in pairs(tbls) do
                    local cols = {}
                    for j = 1, 9 do
                        local list = {}
                        for _, row in ipairs(t) do
                            local v = row[1 + j]
                            if v then
                                for _, mp in ipairs(M.MISPRINTS) do
                                    if mp.rating == rating and mp.kind == kind and mp.rev == rev and mp.tbl == name
                                        and mp.row == row[1] and mp.col == j and mp.printed == v then
                                        v = mp.used
                                        mp.applied = true
                                    end
                                end
                                list[#list + 1] = {row[1], v}
                            end
                        end
                        table.sort(list, function(a, b) return a[1] < b[1] end)
                        local c = {x = {}, v = {}}
                        for k, p in ipairs(list) do c.x[k], c.v[k] = p[1], p[2] end
                        cols[j] = c
                    end
                    COLS[t] = cols
                end
            end
        end
    end
end

-- a column's value at x: linear between its printed cells; outside them
-- nil and "below" or "above"
local function between(c, x)
    local xs, vs = c.x, c.v
    local n = #xs
    if n == 0 then return nil, "none" end
    if x < xs[1] - EPS then return nil, "below" end
    if x > xs[n] + EPS then return nil, "above" end
    if n == 1 then return vs[1] end
    local i = 1
    while i < n - 1 and x > xs[i + 1] do i = i + 1 end
    return vs[i] + (vs[i + 1] - vs[i]) * (x - xs[i]) / (xs[i + 1] - xs[i])
end

-- the end step carried on past the printed cells (estimate); nil with one cell
local function carried(c, x, side)
    local xs, vs = c.x, c.v
    local n = #xs
    if n < 2 then return nil end
    local i = side == "below" and 1 or n - 1
    return vs[i] + (vs[i + 1] - vs[i]) * (x - xs[i]) / (xs[i + 1] - xs[i])
end

------------------------------------------------------------------------
-- the arguments: the tables' columns and the ratings with their weights
------------------------------------------------------------------------
local ALT_NAME = {"S.L.", "4000 FT", "8000 FT"}

local function setup(kind, dob, reversers, rating_pct, pa_ft, flaps)
    local c = {est = {}}
    kind = type(kind) == "string" and kind:upper() or kind
    if kind ~= "SLUSH" and kind ~= "SLIPPERY" then return nil, "RUNWAY SLUSH OR SLIPPERY" end
    c.kind = kind
    -- the depth or braking action columns
    if kind == "SLUSH" then
        if type(dob) ~= "number" then return nil, "NO SLUSH DEPTH" end
        if dob > M.SLUSH_MAX_MM + EPS then return nil, "SLUSH OVER 13 MM NOT RECOMMENDED" end
        if dob < M.SLUSH_MIN_MM - EPS then return nil, "SLUSH UNDER 3 MM OFF THE TABLES" end
        local d = M.DEPTH_MM
        local i = 1
        while i < #d - 1 and dob > d[i + 1] do i = i + 1 end
        local f = math.max(0, math.min(1, (dob - d[i]) / (d[i + 1] - d[i])))
        c.groups = {{i, 1 - f}, {i + 1, f}}
    else
        local b = type(dob) == "string" and M.BRAKING_COLS[dob:upper()]
        if not b then return nil, "BRAKING ACTION GOOD, MEDIUM OR POOR" end
        c.groups = {{b, 1}}
        c.braking = dob:upper()
    end
    if reversers ~= 2 and reversers ~= 0 then return nil, "REVERSE THRUST 2 OR 0 ENGINES" end
    c.rev = reversers
    -- the ratings: 0, 8, 20 % (between: estimate)
    local p = rating_pct or 0
    if type(p) ~= "number" or p < -EPS or p > 20 + EPS then return nil, "THRUST REDUCTION OFF THE TABLES" end
    if math.abs(p) < EPS then c.ratings = {{0, 1}}
    elseif math.abs(p - 8) < EPS then c.ratings = {{8, 1}}
    elseif math.abs(p - 20) < EPS then c.ratings = {{20, 1}}
    elseif p < 8 then c.ratings = {{0, 1 - p / 8}, {8, p / 8}}
    else c.ratings = {{8, 1 - (p - 8) / 12}, {20, (p - 8) / 12}} end
    if #c.ratings > 1 then c.est[#c.est + 1] = "RATING BETWEEN TABLES" end
    -- the pressure altitude columns: S.L., 4000, 8000 (below S.L.: S.L.'s, estimate)
    if type(pa_ft) ~= "number" then return nil, "NO PRESSURE ALTITUDE" end
    if pa_ft > 8000 + EPS then return nil, "PRESSURE ALTITUDE ABOVE 8000 FT" end
    local a = M.ALT_FT
    if pa_ft <= 0 then
        c.alts = {{1, 1}}
        if pa_ft < -EPS then c.est[#c.est + 1] = "BELOW S.L." end
    else
        local i = pa_ft <= a[2] and 1 or 2
        local f = (pa_ft - a[i]) / (a[i + 1] - a[i])
        c.alts = {{i, 1 - f}, {i + 1, f}}
    end
    flaps = flaps or 20
    if flaps ~= 10 and flaps ~= 20 then return nil, "FLAPS 10 OR 20" end
    c.flaps = flaps
    -- the column pairs with weight, each column once
    c.cols = {}
    for _, g in ipairs(c.groups) do
        for _, al in ipairs(c.alts) do
            local w = g[2] * al[2]
            if w > EPS then c.cols[#c.cols + 1] = {j = (g[1] - 1) * 3 + al[1], w = w, alt = al[1]} end
        end
    end
    return c
end

local function note(c, s)
    for _, e in ipairs(c.est) do
        if e == s then return end
    end
    c.est[#c.est + 1] = s
end

-- the flaps 10 notes' change applies (slush: every column; slippery: the
-- braking action named)
local function f10_applies(c, t)
    return c.flaps == 10 and t.f10 ~= nil and (t.f10_cond == nil or t.f10_cond == c.braking)
end

------------------------------------------------------------------------
-- the three tables, one rating at a time
------------------------------------------------------------------------
-- the weight adjustment (1000 kg) for a field/obstacle limit weight (1000 kg)
local function wa_one(c, t, w)
    local sum = 0
    for _, col in ipairs(c.cols) do
        local cc = COLS[t][col.j]
        local v, side = between(cc, w)
        if not v then
            if side == "above" then
                -- the heaviest printed row's adjustment held (estimate)
                v = cc.v[#cc.v]
                note(c, "ADJUSTMENT HELD ABOVE TABLE")
            else
                return nil, "FIELD/OBSTACLE LIMIT WEIGHT BELOW THE TABLE"
            end
        end
        sum = sum + col.w * v
    end
    return sum
end

-- the VMCG limit weight (1000 kg) for a field length available (ft)
local function vmcg_one(c, t, fla)
    local sum, floor = 0, nil
    for _, col in ipairs(c.cols) do
        local cc = COLS[t][col.j]
        local v, side = between(cc, fla)
        if not v then
            if side == "none" then
                return nil, "NO VMCG LIMIT WEIGHT AT " .. ALT_NAME[col.alt]
            end
            v = carried(cc, fla, side)
            if not v then return nil, "FIELD LENGTH OFF THE VMCG TABLE" end
            note(c, "VMCG TABLE EXTENDED")
            if side == "below" then floor = math.max(floor or 0, cc.v[1]) end
        end
        sum = sum + col.w * v
    end
    if floor and sum < floor - EPS then return nil, "FIELD LENGTH TOO SHORT FOR THE VMCG TABLE" end
    if f10_applies(c, t) then
        -- a decrease on every page (p.64's "increase": see the header)
        sum = sum - math.abs(t.f10) / 1000
    end
    return sum
end

-- the V1 adjustment (kt) for a weight (1000 kg)
local function v1_one(c, t, w)
    local sum = 0
    for _, col in ipairs(c.cols) do
        local cc = COLS[t][col.j]
        local v = between(cc, w)
        if not v then
            return nil, string.format("WEIGHT OFF THE V1 TABLE (%d-%d T)", cc.x[1] or 0, cc.x[#cc.x] or 0)
        end
        sum = sum + col.w * v
    end
    if f10_applies(c, t) then sum = sum + t.f10 end
    return sum
end

-- one table's result blended over the ratings
local function by_rating(c, name, fn, x)
    local sum = 0
    for _, r in ipairs(c.ratings) do
        local t = M.DATA[r[1]][c.kind][c.rev][name]
        local v, why = fn(c, t, x)
        if not v then return nil, why end
        sum = sum + r[2] * v
    end
    return sum
end

------------------------------------------------------------------------
-- the steps
------------------------------------------------------------------------
-- the weight adjustment (kg, negative: to add to the field/obstacle limit
-- weight) for the field/obstacle limit weight (kg), FPPM p.20 step 2; nil
-- and the reason off the tables. Second result: the estimates used.
function M.weight_adjustment(kind, depth_or_braking, reversers, rating_pct, field_obstacle_limit_kg, pa_ft)
    local c, why = setup(kind, depth_or_braking, reversers, rating_pct, pa_ft, 20)
    if not c then return nil, why end
    if type(field_obstacle_limit_kg) ~= "number" then return nil, "NO FIELD/OBSTACLE LIMIT WEIGHT" end
    local v
    v, why = by_rating(c, "wa", wa_one, field_obstacle_limit_kg / 1000)
    if not v then return nil, why end
    return 1000 * v, c.est
end

-- the VMCG limit weight (kg) for the field length available (ft), FPPM
-- p.20 step 3 with the notes' flaps 10 decrease; nil and the reason off
-- the tables. Second result: the estimates used.
function M.vmcg_weight(kind, depth_or_braking, reversers, rating_pct, fla_ft, pa_ft, flaps)
    local c, why = setup(kind, depth_or_braking, reversers, rating_pct, pa_ft, flaps)
    if not c then return nil, why end
    if type(fla_ft) ~= "number" then return nil, "NO FIELD LENGTH" end
    local v
    v, why = by_rating(c, "vmcg", vmcg_one, fla_ft)
    if not v then return nil, why end
    return 1000 * v, c.est
end

-- the V1 adjustment (kt) for the actual weight (kg), FPPM p.21 step 2 with
-- the notes' flaps 10 change; nil and the reason off the tables. Second
-- result: the estimates used.
function M.v1_adjustment(kind, depth_or_braking, reversers, rating_pct, weight_kg, pa_ft, flaps)
    local c, why = setup(kind, depth_or_braking, reversers, rating_pct, pa_ft, flaps)
    if not c then return nil, why end
    if type(weight_kg) ~= "number" then return nil, "NO WEIGHT" end
    local v
    v, why = by_rating(c, "v1", v1_one, weight_kg / 1000)
    if not v then return nil, why end
    return v, c.est
end

-- the maximum allowable takeoff weight (kg) on the contaminated runway,
-- FPPM p.20 steps 1-4: the lesser of the field/obstacle limit weight (kg,
-- the rating's own) plus its adjustment and the VMCG limit weight for the
-- field length available (ft) at the pressure altitude (ft); nil and the
-- reason off the tables. work: adjust_kg (the weight adjustment), field_kg
-- (the adjusted field/obstacle limit weight), vmcg_kg (the VMCG limit
-- weight), limit ("FIELD" or "VMCG", the lesser), vmcg_limited (the VMCG
-- limit weight the lesser: p.21's "VMCG limited", V1 = VMCG), est (the
-- estimates used).
function M.limit(kind, depth_or_braking, reversers, rating_pct, field_obstacle_limit_kg, fla_ft, pa_ft, flaps)
    local adj, e1 = M.weight_adjustment(kind, depth_or_braking, reversers, rating_pct, field_obstacle_limit_kg, pa_ft)
    if not adj then return nil, e1 end
    local vm, e2 = M.vmcg_weight(kind, depth_or_braking, reversers, rating_pct, fla_ft, pa_ft, flaps)
    if not vm then return nil, e2 end
    local field = field_obstacle_limit_kg + adj
    local est = {}
    for _, l in ipairs({e1, e2}) do
        for _, s in ipairs(l) do
            local seen = false
            for _, e in ipairs(est) do seen = seen or e == s end
            if not seen then est[#est + 1] = s end
        end
    end
    local vl = vm < field
    return math.min(field, vm), {adjust_kg = adj, field_kg = field, vmcg_kg = vm,
        limit = vl and "VMCG" or "FIELD", vmcg_limited = vl, est = est}
end

-- V1 (kt) on the contaminated runway, FPPM p.21 steps 1-2: VMCG when VMCG
-- limited, else the normal V1 for the actual weight (kt, v1_dry) plus the
-- V1 adjustment, not below VMCG (kt); not above VR is the caller's. nil and
-- the reason off the tables (not when VMCG limited: V1 = VMCG needs no
-- table). work: adjust_kt (nil when VMCG limited), vmcg_limited, floored
-- (raised to VMCG), est.
function M.v1(kind, depth_or_braking, reversers, rating_pct, weight_kg, v1_dry, vmcg, vmcg_limited, pa_ft, flaps)
    local c, why = setup(kind, depth_or_braking, reversers, rating_pct, pa_ft, flaps)
    if not c then return nil, why end
    if type(vmcg) ~= "number" then return nil, "NO VMCG" end
    if vmcg_limited then return vmcg, {vmcg_limited = true, floored = false, est = c.est} end
    if type(v1_dry) ~= "number" then return nil, "NO V1" end
    local adj, est = M.v1_adjustment(kind, depth_or_braking, reversers, rating_pct, weight_kg, pa_ft, flaps)
    if not adj then return nil, est end
    local v = v1_dry + adj
    local floored = v < vmcg
    if floored then v = vmcg end
    return v, {adjust_kt = adj, vmcg_limited = false, floored = floored, est = est}
end

return M
