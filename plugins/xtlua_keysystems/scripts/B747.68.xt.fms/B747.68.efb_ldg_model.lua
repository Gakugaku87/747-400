-- 747-400 EFB landing performance without X-Plane (2026-11-25, the EFB's
-- PERFORMANCE - LANDING page, FCOM p.1183 (10.45.25), "Typical": the
-- dispatch landing limit weights Normal / With Ice / Low Visibility with
-- their VREF 30, the quick turnaround weight and time, and for the
-- in-flight (enroute) part the landing distance and approach speed for a
-- weight):
--  - the in-flight landing distance: the FCOM's Normal Configuration
--    Landing Distance tables (advisory information), reference distance
--    at 250,000 kg plus its adjustments, flaps 30 and 25: 747-400/PW4056
--    FCOM p.275 (PI.12.1), p.276 (PI.12.2) (m, kg; the GOOD, MEDIUM and
--    POOR rows factored by 1.15); 747-400F/CF6-80C2B1F FCOM p.371
--    (PI.22.1), p.372 (PI.22.2) (ft, lb, actual distances). The FPPM's
--    (747-400F/PW4056) same tables (FPPM p.78-79 (1.4.8-9), ft, actual)
--    agree with the FCOM's PW4056 ones within 37 m (M.FPPM_DIST; the
--    test);
--  - the dispatch limit weights: the FPPM's Landing Field & Climb Limit
--    charts (747-400F/PW4056, D632U002-RZ043 Rev 7), flaps 25 FPPM p.71
--    (1.4.1), flaps 30 p.72 (1.4.2), anti-skid inoperative p.73 (1.4.3),
--    p.74 (1.4.4), read as FPPM p.23 (1.1.5) says: the field length
--    available corrected for the wind, the brakes and the runway along the
--    guide lines (between two by the fraction between them at the REF
--    LINE), up to the airport pressure altitude (linear between the 2,000
--    ft lines); the climb limit from the OAT and pressure altitude (linear
--    between the 1,000 ft curves), the packs and ice notes; "Low
--    Visibility" the CAT III autoland field length (FPPM p.24 (1.1.6): the
--    field length available / 1.15 with anti-skid operative and braking
--    medium or better, else / 1.3);
--  - the quick turnaround limit weight: FPPM p.76 (1.4.6), bilinear in the
--    table, its notes' slope, wind and brakes adjustments; the time to wait
--    the page's 70 minutes (the FCOM's EFB picture shows 65: "Typical").
-- The data block is written by docs/overhaul/tools/efb_ldg_data.lua from
-- the PDFs; the functions below it are by hand. As printed, also where
-- the pages look wrong: FPPM p.76 flaps 30 0 ft -10 C 328 (its neighbours
-- 341, 325: about 334 expected) and 8,000 ft -40 C 291 (306, 294: about
-- 300), both on the low (safe) side; FPPM p.79's flaps 25 column heading
-- "ABOVE VREF 30" (its note and the FCOM: VREF 25).
--
-- The charts outside their drawn range: below the field chart's 200 t or
-- shorter than its field length nil; a longer field length or a corrected
-- one past the chart's right edge, and a headwind past 40 kt, the chart's
-- edge (conservative, with a note); between a guide line family's first
-- or last two lines carried on (the wet lines of p.71 start at 6,000 ft,
-- p.73's tail lines at 11,000 ft: estimate); the climb chart below 0 C its
-- 0 C value, past a curve's end (its hottest OAT) nil.
--
-- Engines (as B747.68.efb_to_model.lua): 0 PW the FCOM's PW4056 tables; 1
-- GE the FCOM's CF6-80C2B1F tables; 2 RR no source: the PW4056's
-- (estimate). The FPPM's charts (field, climb, quick turnaround) are the
-- PW4056 freighter's for every engine (GE, RR, the passenger airplane:
-- estimate).
--
--   local L = B747_efb_ldg_model         -- in XTLua, after dofile
--   L.distance(engine, flaps, cond, brake, weight_kg, pa_ft, oat_c, wind_kt,
--              slope_pct, vapp_add_kt, reversers, manual_spoilers)
--       -> actual_m, fcom_m             (or nil, reason)
--   L.field_limit(flaps, lda_m, pa_ft, wind_kt, cond, antiskid_inop,
--                 two_brakes_inop, manual_spoilers) -> kg, note
--   L.climb_limit(flaps, oat_c, pa_ft, packs, icing) -> kg
--   L.quick_turnaround(flaps, pa_ft, oat_c, slope_pct, wind_kt,
--                      two_brakes_inop) -> kg, wait_min
--   L.approach_speed(flaps, weight_kg, elev_ft, add_kt) -> kt
--   L.dispatch{...} -> the EFB page's dispatch block (see there)
-- Units kg, m, ft, C, kt; wind + headwind, - tailwind; slope % + uphill.
-- flaps 25 or 30. Each returns nil and a reason when the tables or charts
-- give no answer.
--
-- distance():
--  - cond "DRY", or the reported braking action "GOOD", "MEDIUM", "POOR";
--    "WET" is taken as GOOD (FPPM p.24 (1.1.6): the "good" data are
--    consistent with wet runway testing);
--  - brake "MAX MANUAL", "MAX AUTO", or the autobrake setting "4", "3",
--    "2", "1" (a number, "AUTOBRAKES 3", "AB3" too); the slippery tables
--    have no AUTOBRAKE 2 and 1: nil;
--  - reversers: how many engines' reversers are used: 4 the reference
--    ("four engine max reverse"), 2 the "2 REV" column, 0 "NO REV"; 3 and
--    1 credit only the symmetric pair (3 as 2, 1 as none: estimate, the
--    tables give no odd counts; conservative); nil 4;
--  - vapp_add_kt: the approach speed above VREF 30 (VREF 25 for flaps 25)
--    for the "APP SPD ADJ" column; below VREF nil;
--  - manual_spoilers: MAX MANUAL with manual spoilers adds the note's 85 m
--    (PW) / 240 ft (GE); the autobrake rows hold for both;
--  - pa_ft the airport's pressure altitude: the ALT ADJ "per 1000 ft above
--    sea level" (none below sea level: estimate), the temperature against
--    the ISA there (15 C - 1.98 C/1000 ft);
--  - the first value the actual (unfactored) distance; the second the
--    FCOM table's figure: for the PW4056's GOOD, MEDIUM and POOR the table
--    has "distances and adjustments ... factored by 1.15" (FCOM p.275), so
--    its figure is 1.15 times the actual; otherwise the two are the same.
--    The 1.67 dispatch factor is not in either (FPPM p.24);
--  - nil outside: weight 150 to 400 t (estimate: the tables are linear from
--    250 t and state no range; the VREF table is 200 to 400 t), pressure
--    altitude -2,000 (estimate: the FPPM charts' lowest) to 10,000 ft and
--    runway slope +/-2 % (FCOM p.77 (L.10.1)), tailwind beyond 15 kt (PW
--    and RR, the 109) or 10 kt (GE, the 570) (FCOM p.77 (L.10.1)).
local M = setmetatable({}, {})
B747_efb_ldg_model = M

M.M_PER_FT = 0.3048
M.KG_PER_LB = 0.45359237
-- the table rows' columns (the generated data's order)
M.COL = {ref = 1, wt_above = 2, wt_below = 3, alt = 4, head = 5, tail = 6, down = 7, up = 8,
    isa_above = 9, isa_below = 10, app = 11, rev2 = 12, norev = 13}
M.WT_MIN, M.WT_MAX = 150000, 400000             -- kg (estimate, see above)
M.PA_MIN, M.PA_MAX = -2000, 10000               -- ft (FCOM p.77 (L.10.1); the low one estimate)
M.SLOPE_MAX = 2                                 -- % (FCOM p.77 (L.10.1))
M.TAILWIND_MAX = {[0] = 15, [1] = 10, [2] = 15} -- kt by engine (FCOM p.77 (L.10.1): 109 15, 570 10)
M.CAT3_DIV = {1.15, 1.3}                        -- FPPM p.24 (1.1.6): anti-skid and braking ok / not

-- BEGIN GENERATED DATA (docs/overhaul/tools/efb_ldg_data.lua: do not edit by hand)
-- Normal Configuration Landing Distance, a row a braking configuration:
-- ref, wt_above, wt_below, alt, head, tail, down, up, isa_above, isa_below, app, rev2, norev
-- (M.COL), in the table's units: the distance and its adjustments in
-- unit, the weight's in wt_unit per wt_step from ref_wt; factor: the
-- slippery runways' (GOOD, MEDIUM, POOR) figures already times it;
-- manual_spoilers: added to MAX MANUAL with manual spoilers; flare: the
-- distance from 50 ft included (approximately).
M.DIST = {
    [0] = {   -- 747-400/PW4056
        unit = "M", wt_unit = "KG", ref_wt = 250000, wt_step = 5000, factor = 1.15,
        manual_spoilers = 85, flare = 305,
        [30] = {   -- FCOM p.275 (PI.12.1)
            DRY = {
                ["MAX MANUAL"] = {1055, 20, -15, 30, -55, 180, 15, -15, 30, -30, 115, 25, 55},
                ["MAX AUTO"] = {1270, 20, -20, 40, -65, 215, 0, 0, 35, -35, 150, 0, 0},
                ["4"] = {1555, 30, -30, 50, -85, 280, 0, 0, 45, -45, 190, 0, 0},
                ["3"] = {1825, 35, -35, 60, -100, 340, 10, -15, 55, -55, 210, 5, 10},
                ["2"] = {2055, 40, -40, 70, -115, 395, 30, -40, 70, -65, 190, 30, 35},
                ["1"] = {2275, 45, -45, 80, -135, 460, 60, -70, 80, -70, 190, 145, 210},
            },
            GOOD = {
                ["MAX MANUAL"] = {1600, 30, -30, 50, -85, 310, 45, -40, 50, -45, 165, 85, 195},
                ["MAX AUTO"] = {1655, 30, -30, 50, -90, 315, 35, -30, 50, -45, 180, 85, 200},
                ["4"] = {1800, 35, -35, 55, -100, 335, 10, -5, 50, -50, 220, 10, 70},
                ["3"] = {2100, 40, -40, 70, -115, 390, 15, -15, 65, -65, 240, 5, 10},
            },
            MEDIUM = {
                ["MAX MANUAL"] = {2145, 40, -40, 75, -130, 490, 105, -85, 75, -65, 190, 220, 530},
                ["MAX AUTO"] = {2145, 40, -40, 75, -130, 490, 105, -75, 75, -65, 215, 215, 520},
                ["4"] = {2145, 45, -40, 75, -130, 490, 105, -75, 75, -65, 205, 220, 535},
                ["3"] = {2265, 45, -45, 75, -140, 500, 85, -55, 75, -70, 240, 150, 455},
            },
            POOR = {
                ["MAX MANUAL"] = {2770, 60, -60, 100, -195, 780, 275, -165, 105, -80, 215, 460, 1210},
                ["MAX AUTO"] = {2770, 60, -60, 100, -195, 775, 275, -160, 105, -80, 220, 465, 1225},
                ["4"] = {2770, 60, -60, 100, -195, 775, 275, -160, 105, -80, 220, 460, 1220},
                ["3"] = {2770, 60, -60, 100, -195, 785, 275, -150, 105, -80, 240, 465, 1230},
            },
        },
        [25] = {   -- FCOM p.276 (PI.12.2)
            DRY = {
                ["MAX MANUAL"] = {1120, 30, -20, 35, -55, 185, 20, -15, 30, -30, 115, 30, 60},
                ["MAX AUTO"] = {1360, 25, -25, 40, -65, 220, 0, 0, 40, -40, 155, 0, 0},
                ["4"] = {1670, 30, -30, 55, -85, 290, 0, 0, 50, -50, 200, 0, 0},
                ["3"] = {1985, 40, -40, 65, -105, 350, 5, -15, 60, -60, 225, 5, 10},
                ["2"] = {2250, 45, -45, 75, -120, 410, 20, -45, 75, -70, 210, 25, 25},
                ["1"] = {2495, 50, -50, 90, -140, 480, 65, -75, 90, -75, 210, 180, 220},
            },
            GOOD = {
                ["MAX MANUAL"] = {1695, 35, -30, 55, -90, 315, 45, -40, 50, -45, 165, 105, 230},
                ["MAX AUTO"] = {1750, 35, -35, 55, -90, 320, 40, -35, 55, -50, 180, 105, 235},
                ["4"] = {1930, 35, -35, 65, -105, 345, 10, -5, 55, -60, 230, 10, 75},
                ["3"] = {2285, 45, -45, 75, -120, 405, 5, -15, 70, -70, 260, 5, 10},
            },
            MEDIUM = {
                ["MAX MANUAL"] = {2305, 45, -45, 80, -140, 500, 120, -90, 80, -70, 200, 265, 655},
                ["MAX AUTO"] = {2305, 45, -45, 80, -140, 500, 115, -80, 80, -70, 220, 255, 645},
                ["4"] = {2305, 45, -45, 80, -140, 500, 110, -75, 80, -70, 220, 265, 650},
                ["3"] = {2450, 45, -45, 80, -145, 520, 80, -55, 80, -75, 260, 175, 565},
            },
            POOR = {
                ["MAX MANUAL"] = {2995, 65, -65, 110, -200, 805, 295, -185, 115, -85, 225, 560, 1530},
                ["MAX AUTO"] = {2995, 65, -55, 110, -200, 800, 300, -170, 115, -85, 225, 565, 1545},
                ["4"] = {2995, 65, -55, 110, -200, 800, 295, -170, 115, -85, 230, 565, 1545},
                ["3"] = {2995, 65, -55, 110, -200, 805, 285, -155, 115, -85, 255, 570, 1560},
            },
        },
    },
    [1] = {   -- 747-400F/CF6-80C2B1F
        unit = "FT", wt_unit = "LB", ref_wt = 550000, wt_step = 10000, factor = 1,
        manual_spoilers = 240, flare = 1000,
        [30] = {   -- FCOM p.371 (PI.22.1)
            DRY = {
                ["MAX MANUAL"] = {3310, 60, -50, 100, -170, 580, 50, -50, 90, -90, 360, 110, 250},
                ["MAX AUTO"] = {4160, 70, -70, 120, -210, 700, 0, -10, 120, -120, 470, 0, 0},
                ["4"] = {5090, 90, -90, 160, -270, 920, 0, -20, 150, -150, 600, 0, 0},
                ["3"] = {5900, 100, -100, 200, -320, 1100, 60, -90, 190, -180, 580, 70, 100},
                ["2"] = {6430, 120, -120, 220, -370, 1250, 140, -150, 220, -200, 570, 380, 410},
                ["1"] = {6950, 140, -140, 260, -420, 1440, 220, -230, 250, -210, 570, 760, 1190},
            },
            GOOD = {
                ["MAX MANUAL"] = {4300, 70, -70, 140, -240, 850, 110, -100, 130, -120, 440, 310, 720},
                ["MAX AUTO"] = {4530, 80, -80, 150, -250, 870, 90, -80, 140, -130, 460, 320, 750},
                ["4"] = {5120, 90, -90, 160, -280, 960, 20, -30, 150, -150, 600, 30, 200},
                ["3"] = {5900, 100, -100, 200, -320, 1100, 70, -90, 190, -180, 580, 70, 100},
            },
            MEDIUM = {
                ["MAX MANUAL"] = {5650, 100, -100, 190, -360, 1340, 270, -210, 180, -160, 500, 730, 1880},
                ["MAX AUTO"] = {5690, 110, -100, 200, -360, 1340, 250, -190, 190, -160, 540, 710, 1840},
                ["4"] = {5760, 110, -100, 200, -360, 1350, 210, -150, 190, -170, 600, 670, 1830},
                ["3"] = {6250, 110, -110, 210, -380, 1410, 200, -170, 200, -180, 580, 420, 1490},
            },
            POOR = {
                ["MAX MANUAL"] = {7170, 130, -130, 250, -530, 2180, 730, -400, 240, -190, 550, 1400, 4040},
                ["MAX AUTO"] = {7170, 140, -130, 250, -520, 2180, 720, -390, 240, -190, 560, 1400, 4100},
                ["4"] = {7170, 140, -130, 250, -520, 2180, 720, -390, 240, -190, 560, 1400, 4090},
                ["3"] = {7310, 140, -130, 260, -530, 2200, 700, -380, 250, -190, 580, 1300, 4030},
            },
        },
        [25] = {   -- FCOM p.372 (PI.22.2)
            DRY = {
                ["MAX MANUAL"] = {3480, 80, -50, 100, -170, 590, 50, -50, 100, -90, 360, 130, 280},
                ["MAX AUTO"] = {4450, 70, -70, 130, -220, 720, 0, -10, 130, -130, 500, 0, 0},
                ["4"] = {5460, 90, -90, 180, -280, 950, 0, -10, 170, -170, 640, 0, 0},
                ["3"] = {6410, 110, -110, 220, -340, 1150, 40, -100, 210, -200, 630, 80, 110},
                ["2"] = {7000, 130, -130, 250, -380, 1310, 140, -170, 240, -210, 610, 420, 440},
                ["1"] = {7550, 150, -150, 290, -430, 1500, 240, -260, 280, -230, 610, 960, 1320},
            },
            GOOD = {
                ["MAX MANUAL"] = {4560, 80, -80, 150, -250, 870, 120, -100, 140, -130, 440, 360, 850},
                ["MAX AUTO"] = {4780, 80, -80, 160, -250, 890, 90, -70, 150, -130, 490, 360, 870},
                ["4"] = {5490, 90, -90, 180, -290, 990, 20, -20, 170, -170, 640, 20, 210},
                ["3"] = {6410, 110, -110, 220, -340, 1150, 50, -100, 210, -200, 630, 80, 110},
            },
            MEDIUM = {
                ["MAX MANUAL"] = {6030, 110, -110, 210, -370, 1370, 280, -220, 200, -170, 520, 860, 2290},
                ["MAX AUTO"] = {6030, 110, -110, 210, -370, 1370, 270, -190, 200, -170, 570, 830, 2240},
                ["4"] = {6130, 110, -110, 210, -370, 1380, 220, -140, 200, -180, 650, 770, 2190},
                ["3"] = {6750, 120, -120, 230, -400, 1460, 180, -170, 220, -200, 630, 460, 1810},
            },
            POOR = {
                ["MAX MANUAL"] = {7690, 150, -140, 270, -540, 2250, 770, -420, 260, -200, 580, 1670, 5060},
                ["MAX AUTO"] = {7690, 150, -140, 280, -540, 2240, 770, -410, 260, -200, 600, 1680, 5130},
                ["4"] = {7690, 150, -140, 280, -540, 2240, 760, -410, 260, -200, 590, 1670, 5120},
                ["3"] = {7850, 150, -140, 280, -550, 2270, 720, -390, 270, -210, 630, 1550, 5040},
            },
        },
    },
}
-- the FPPM's tables (747-400F/PW4056, actual distances): not used by the
-- functions; the test holds the FCOM's PW4056 tables against them
M.FPPM_DIST = {
    unit = "FT", wt_unit = "KG", ref_wt = 250000, wt_step = 5000, factor = 1,
    manual_spoilers = 240, flare = 1000,
    [30] = {   -- FPPM p.78 (1.4.8)
        DRY = {
            ["MAX MANUAL"] = {3460, 70, -50, 100, -180, 590, 60, -50, 100, -100, 380, 80, 180},
            ["MAX AUTO"] = {4170, 70, -70, 120, -210, 700, 0, 0, 120, -120, 490, 0, 0},
            ["4"] = {5100, 90, -90, 160, -270, 920, 0, -10, 150, -150, 630, 0, 0},
            ["3"] = {5990, 100, -100, 200, -330, 1110, 40, -40, 190, -190, 690, 10, 30},
            ["2"] = {6750, 120, -120, 230, -380, 1290, 90, -140, 220, -210, 630, 100, 110},
            ["1"] = {7470, 140, -140, 270, -440, 1510, 200, -220, 260, -230, 630, 480, 700},
        },
        GOOD = {
            ["MAX MANUAL"] = {4550, 80, -80, 150, -250, 880, 130, -110, 140, -130, 470, 240, 550},
            ["MAX AUTO"] = {4720, 80, -80, 150, -260, 900, 110, -90, 150, -140, 510, 250, 570},
            ["4"] = {5140, 90, -90, 160, -280, 960, 30, -20, 160, -160, 630, 40, 190},
            ["3"] = {5990, 100, -100, 200, -330, 1110, 40, -40, 190, -190, 690, 10, 30},
        },
        MEDIUM = {
            ["MAX MANUAL"] = {6130, 110, -110, 210, -380, 1400, 320, -240, 210, -180, 550, 630, 1520},
            ["MAX AUTO"] = {6130, 110, -110, 210, -380, 1390, 300, -210, 210, -180, 610, 610, 1480},
            ["4"] = {6130, 110, -110, 210, -380, 1390, 290, -210, 210, -180, 600, 630, 1520},
            ["3"] = {6470, 110, -110, 220, -390, 1440, 250, -160, 210, -200, 690, 430, 1300},
        },
        POOR = {
            ["MAX MANUAL"] = {7910, 150, -140, 280, -560, 2230, 790, -470, 290, -230, 600, 1310, 3450},
            ["MAX AUTO"] = {7780, 150, -140, 280, -550, 2210, 800, -450, 290, -230, 630, 1320, 3490},
            ["4"] = {7800, 150, -140, 280, -550, 2210, 790, -450, 290, -230, 620, 1310, 3470},
            ["3"] = {7870, 150, -140, 280, -550, 2220, 790, -420, 290, -230, 680, 1330, 3510},
        },
    },
    [25] = {   -- FPPM p.79 (1.4.9)
        DRY = {
            ["MAX MANUAL"] = {3680, 80, -50, 110, -180, 600, 60, -50, 100, -100, 380, 90, 210},
            ["MAX AUTO"] = {4460, 70, -70, 130, -220, 720, 0, 0, 130, -130, 500, 0, 0},
            ["4"] = {5470, 90, -90, 180, -280, 950, 0, 0, 170, -170, 660, 0, 0},
            ["3"] = {6510, 110, -110, 210, -340, 1150, 20, -50, 200, -200, 730, 20, 30},
            ["2"] = {7370, 130, -130, 250, -400, 1340, 60, -150, 250, -230, 690, 80, 90},
            ["1"] = {8180, 160, -150, 300, -460, 1570, 210, -250, 300, -250, 690, 590, 720},
        },
        GOOD = {
            ["MAX MANUAL"] = {4840, 80, -80, 160, -260, 900, 140, -120, 150, -140, 470, 290, 660},
            ["MAX AUTO"] = {4990, 90, -80, 160, -260, 920, 110, -90, 160, -140, 510, 300, 680},
            ["4"] = {5510, 90, -90, 180, -290, 990, 30, -10, 170, -170, 660, 40, 210},
            ["3"] = {6510, 110, -110, 210, -340, 1150, 20, -40, 200, -200, 730, 20, 30},
        },
        MEDIUM = {
            ["MAX MANUAL"] = {6570, 120, -120, 230, -390, 1440, 340, -260, 230, -190, 570, 760, 1870},
            ["MAX AUTO"] = {6570, 120, -120, 230, -390, 1430, 320, -220, 230, -190, 620, 730, 1840},
            ["4"] = {6570, 120, -120, 230, -390, 1430, 320, -210, 230, -190, 630, 750, 1860},
            ["3"] = {6980, 120, -120, 240, -410, 1480, 230, -160, 230, -210, 730, 500, 1610},
        },
        POOR = {
            ["MAX MANUAL"] = {8550, 160, -160, 310, -580, 2300, 840, -500, 320, -250, 640, 1590, 4370},
            ["MAX AUTO"] = {8550, 160, -160, 310, -570, 2280, 850, -490, 320, -250, 640, 1610, 4410},
            ["4"] = {8550, 160, -160, 310, -570, 2280, 840, -490, 320, -250, 650, 1600, 4410},
            ["3"] = {8550, 160, -160, 310, -570, 2290, 820, -450, 320, -250, 710, 1620, 4450},
        },
    },
}
M.FIELD = {   -- Landing Field Limit, anti-skid operative
    [25] = {   -- FPPM p.71 (1.4.1)
        fla = {5000, 13000}, wt = {200, 400}, manual_spoilers = 460,
        -- the guide lines: {ft at the REF LINE, ft at the far edge}
        wind = {head = 40, tail = 15,
            head_lines = {
                {5000, 6295}, {5500, 6740}, {6001, 7350}, {6500, 7899}, {7000, 8460}, {7501, 9020},
                {8000, 9580}, {8500, 10151}, {8999, 10740}, {9501, 11280}, {10000, 11890},
                {10499, 12509}, {11001, 13158}, {11500, 13778}, {11999, 14485}, {12501, 15230}
            },
            tail_lines = {
                {5500, 4261}, {6001, 4582}, {6500, 5051}, {6999, 5500}, {7501, 5950}, {8000, 6391},
                {8500, 6830}, {8999, 7241}, {9501, 7650}, {10000, 8050}, {10499, 8449},
                {11001, 8839}, {11500, 9200}, {11999, 9559}, {12500, 9899}, {13000, 10239}
            },
        },
        brakes = {   -- NORMAL to TWO INOP
            {5500, 5124}, {6001, 5565}, {6500, 6001}, {7000, 6469}, {7501, 6901}, {8000, 7392},
            {8500, 7899}, {8999, 8319}, {9501, 8749}, {10000, 9099}, {10499, 9505}, {11001, 9888},
            {11500, 10271}, {11999, 10621}, {12501, 11110}, {13000, 11479}
        },
        wet = {   -- DRY to WET
            {6001, 5219}, {6500, 5653}, {7000, 6087}, {7501, 6521}, {8000, 6957}, {8500, 7390},
            {8999, 7826}, {9501, 8261}, {10000, 8695}, {10499, 9129}, {11001, 9570},
            {11500, 10000}, {11999, 10430}, {12501, 10871}, {13000, 11304}
        },
        -- the pressure altitude lines: {ft, 1000 kg}
        alt = {-2000, 0, 2000, 4000, 6000, 8000, 10000},
        lines = {
            {   -- -2000 ft
                {5000, 200}, {6011, 245.45}, {6406, 267.31}, {7043, 284.76}, {8034, 311.33},
                {9024, 336.67}, {10033, 361.02}, {11032, 384.22}, {11770, 400}
            },
            {   -- 0 ft
                {5271, 200}, {6758, 267.01}, {8034, 300.71}, {9028, 325.26}, {10023, 348.21},
                {11750, 386.98}, {12050, 390.85}, {12750, 400}
            },
            {   -- 2000 ft
                {5552, 200}, {7148, 268.11}, {8034, 290.47}, {10029, 334.96}, {11028, 357.87},
                {11850, 374.99}, {13000, 389.63}
            },
            {   -- 4000 ft
                {5861, 200}, {7469, 266.69}, {9032, 302.3}, {11025, 344.9}, {11949, 364},
                {13006, 376.79}
            },
            {   -- 6000 ft
                {6141, 200}, {7952, 268.06}, {12041, 351.44}, {13006, 363.03}
            },
            {   -- 8000 ft
                {6496, 200}, {8420, 267.98}, {11001, 319.34}, {12144, 339.99}, {13000, 351.06}
            },
            {   -- 10000 ft
                {6884, 200}, {8915, 268.53}, {11032, 306.5}, {12270, 330}, {13000, 338.48}
            },
        },
    },
    [30] = {   -- FPPM p.72 (1.4.2)
        fla = {5000, 13000}, wt = {200, 400}, manual_spoilers = 440, f30_vapp_max = 167,
        -- the guide lines: {ft at the REF LINE, ft at the far edge}
        wind = {head = 40, tail = 15,
            head_lines = {
                {5000, 6239}, {5499, 6790}, {5999, 7350}, {6501, 7890}, {6999, 8450}, {7500, 9080},
                {7998, 9629}, {8499, 10200}, {9000, 10761}, {9499, 11250}, {10000, 11969},
                {10500, 12580}, {10999, 13252}, {11500, 13908}, {11999, 14632}, {12499, 15393}
            },
            tail_lines = {
                {5499, 4116}, {5999, 4586}, {6501, 5051}, {6999, 5520}, {7500, 5960}, {7998, 6431},
                {8499, 6829}, {9000, 7250}, {9499, 7651}, {10000, 8049}, {10500, 8450},
                {10999, 8822}, {11500, 9170}, {11999, 9529}, {12499, 9880}, {13000, 10210}
            },
        },
        brakes = {   -- NORMAL to TWO INOP
            {5508, 5113}, {6000, 5564}, {6512, 6023}, {6987, 6513}, {7502, 6943}, {8003, 7337},
            {8486, 7828}, {9003, 8217}, {9482, 8669}, {10002, 9147}, {10514, 9528}, {10976, 9874},
            {11506, 10275}, {11973, 10688}, {12485, 11117}, {13000, 11453}
        },
        wet = {   -- DRY to WET
            {5986, 5222}, {6497, 5644}, {6991, 6084}, {7496, 6519}, {8005, 6951}, {8497, 7391},
            {9000, 7828}, {9487, 8260}, {9987, 8695}, {10509, 9135}, {10998, 9561}, {11495, 10005},
            {11996, 10439}, {12502, 10868}, {13007, 11298}
        },
        -- the pressure altitude lines: {ft, 1000 kg}
        alt = {-2000, 0, 2000, 4000, 6000, 8000, 10000},
        lines = {
            {   -- -2000 ft
                {5000, 213.3}, {6373, 283.33}, {8629, 350}, {10011, 386.25}, {10559, 400}
            },
            {   -- 0 ft
                {5000, 200.01}, {6731, 283.88}, {8349, 330}, {10000, 372.68}, {11136, 400}
            },
            {   -- 2000 ft
                {5241, 200.01}, {7074, 283.84}, {8821, 330}, {10999, 383.02}, {11379, 391.48},
                {11953, 400}
            },
            {   -- 4000 ft
                {5528, 200.01}, {7439, 283.29}, {10000, 346.63}, {10999, 368.9}, {11539, 380.09},
                {12023, 386.98}, {12950, 400}
            },
            {   -- 6000 ft
                {5820, 200.01}, {7930, 285.11}, {10000, 333.7}, {10999, 355.28}, {11620, 367.81},
                {13000, 386.7}
            },
            {   -- 8000 ft
                {6143, 200.01}, {8372, 285.33}, {10999, 342.31}, {11675, 355.24}, {13000, 372.9}
            },
            {   -- 10000 ft
                {6501, 200.01}, {8895, 285.66}, {10999, 329.01}, {11739, 343.26}, {13000, 359.06}
            },
        },
    },
}
M.FIELD_ASKID_INOP = {   -- Landing Field Limit, anti-skid inoperative
    [25] = {   -- FPPM p.73 (1.4.3)
        fla = {9000, 16000}, wt = {200, 300}, manual_spoilers = 0,
        -- the guide lines: {ft at the REF LINE, ft at the far edge}
        wind = {head = 40, tail = 15,
            head_lines = {
                {9000, 12261}, {9501, 12780}, {10001, 13281}, {10500, 13830}, {11001, 14381},
                {11500, 14950}, {12000, 15530}, {12501, 16111}, {13000, 16674}, {13499, 17271},
                {14001, 17764}, {14500, 18257}, {15000, 18771}, {15501, 19257}
            },
            tail_lines = {
                {11001, 7481}, {11500, 7972}, {12000, 8477}, {12501, 8849}, {13000, 9232},
                {13499, 9621}, {14001, 10021}, {14500, 10421}, {15000, 10850}, {15501, 11291},
                {16000, 11761}
            },
        },
        wet = {   -- DRY to WET
            {10500, 9131}, {11001, 9571}, {11500, 10001}, {12000, 10430}, {12501, 10871},
            {13000, 11300}, {13500, 11741}, {14001, 12171}, {14500, 12600}, {15000, 13041},
            {15501, 13480}, {16000, 13911}
        },
        -- the pressure altitude lines: {ft, 1000 kg}
        alt = {-2000, 0, 2000, 4000, 6000, 8000, 10000},
        lines = {
            {   -- -2000 ft
                {11205, 200}, {14440, 267.51}, {16000, 287.3}
            },
            {   -- 0 ft
                {11800, 200}, {15200, 267.51}, {16000, 277.31}
            },
            {   -- 2000 ft
                {12420, 200}, {16000, 267.51}
            },
            {   -- 4000 ft
                {13090, 200}, {16000, 252.01}
            },
            {   -- 6000 ft
                {13801, 200}, {16000, 237.01}
            },
            {   -- 8000 ft
                {14590, 200}, {16000, 222.22}
            },
            {   -- 10000 ft
                {15449, 200}, {16000, 208.82}
            },
        },
    },
    [30] = {   -- FPPM p.74 (1.4.4)
        fla = {9000, 16000}, wt = {200, 300}, manual_spoilers = 50, f30_vapp_max = 167,
        -- the guide lines: {ft at the REF LINE, ft at the far edge}
        wind = {head = 40, tail = 15,
            head_lines = {
                {9000, 10159}, {9501, 11470}, {10000, 12780}, {10501, 13530}, {10999, 14350},
                {11501, 15030}, {11999, 15619}, {12500, 16100}, {13001, 16486}, {13500, 16828},
                {14001, 17104}, {14500, 17419}, {15000, 17990}, {15499, 18578}
            },
            tail_lines = {
                {10501, 6698}, {10999, 7201}, {11501, 7698}, {11999, 8225}, {12500, 8722},
                {13001, 9170}, {13500, 9621}, {14001, 10070}, {14500, 10501}, {15000, 10940},
                {15499, 11381}, {16000, 11829}
            },
        },
        wet = {   -- DRY to WET
            {10501, 9130}, {10999, 9571}, {11501, 10000}, {11999, 10431}, {12500, 10870},
            {13001, 11301}, {13500, 11740}, {14001, 12171}, {14499, 12600}, {15000, 13041},
            {15499, 13480}, {16000, 13911}
        },
        -- the pressure altitude lines: {ft, 1000 kg}
        alt = {-2000, 0, 2000, 4000, 6000, 8000, 10000},
        lines = {
            {   -- -2000 ft
                {10130, 200}, {13700, 283.5}, {14851, 300}
            },
            {   -- 0 ft
                {10641, 200}, {14430, 283.5}, {15629, 300}
            },
            {   -- 2000 ft
                {11191, 200}, {15220, 283.5}, {16000, 294.49}
            },
            {   -- 4000 ft
                {11800, 200}, {16000, 283.5}
            },
            {   -- 6000 ft
                {12470, 200}, {16000, 266.49}
            },
            {   -- 8000 ft
                {13151, 200}, {16000, 250.49}
            },
            {   -- 10000 ft
                {13931, 200}, {16000, 235}
            },
        },
    },
}
M.CLIMB = {   -- Landing Climb Limit (the anti-skid inoperative pages repeat it)
    [25] = {   -- FPPM p.71 (1.4.1)
        pack1 = 3900, pack0 = 5900, ice = 21400, ice_below_c = 8,
        alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
        lines = {   -- {OAT C, 1000 kg}
            {   -- -2000 ft
                {0, 457.39}, {18.97, 457.23}, {32.87, 456.7}, {39.27, 456.28}, {41.75, 445.08},
                {48.05, 414.47}, {58.37, 363.13}
            },
            {   -- -1000 ft
                {0, 450.5}, {16.97, 450.34}, {37.27, 449.53}, {39.76, 438.69}, {45.34, 413.3},
                {56.37, 360.88}
            },
            {   -- 0 ft
                {0, 450.37}, {15.93, 450.21}, {33.29, 449.76}, {37.8, 431.74}, {43.35, 407.91},
                {54.42, 357.52}
            },
            {   -- 1000 ft
                {0, 441.5}, {13.94, 441.34}, {31.31, 440.85}, {35.81, 424.36}, {41.35, 401.91},
                {52.42, 353.44}
            },
            {   -- 2000 ft
                {0, 432.2}, {11.03, 432.13}, {29.35, 431.6}, {33.82, 416.6}, {39.4, 395.28},
                {45.53, 370.28}, {50.43, 349.52}
            },
            {   -- 3000 ft
                {0, 422.34}, {9.08, 422.28}, {27.36, 421.72}, {31.83, 407.91}, {37.4, 388.2},
                {42.95, 367.15}, {48.47, 344.69}
            },
            {   -- 4000 ft
                {0, 412.22}, {5.84, 412.19}, {25.36, 411.6}, {29.86, 398.94}, {35.41, 380.99},
                {40.97, 360.98}, {46.49, 339.64}
            },
            {   -- 5000 ft
                {0, 402.03}, {5.09, 402.01}, {23.4, 401.38}, {27.88, 389.73}, {33.43, 373.35},
                {39.6, 352.26}, {44.49, 334.44}
            },
            {   -- 6000 ft
                {0, 395.25}, {7.28, 395.09}, {15.96, 394.76}, {19.82, 394.53}, {25.88, 380.1},
                {31.46, 364.99}, {37.02, 347.63}, {42.54, 328.92}
            },
            {   -- 7000 ft
                {0, 385.03}, {16.12, 384.41}, {17.43, 384.57}, {23.93, 370.28}, {29.48, 356.31},
                {35.03, 340.32}, {40.54, 322.72}
            },
            {   -- 8000 ft
                {0, 375.02}, {14.95, 374.33}, {21.94, 360.72}, {27.48, 347.99}, {33.03, 333.4},
                {38.55, 316.62}
            },
            {   -- 9000 ft
                {0, 364.44}, {12.57, 363.85}, {19.68, 351.09}, {25.53, 338.82}, {31.04, 325.44},
                {36.56, 310}
            },
            {   -- 10000 ft
                {0, 354.15}, {10.18, 353.6}, {17.99, 340.71}, {23.53, 330.01}, {29.08, 317.7},
                {34.6, 303.66}
            },
        },
    },
    [30] = {   -- FPPM p.72 (1.4.2)
        pack1 = 2900, pack0 = 4100, ice = 17100, ice_below_c = 8,
        alt = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
        lines = {   -- {OAT C, 1000 kg}
            {   -- -2000 ft
                {0, 453.02}, {18.98, 452.95}, {33.97, 452.31}, {39.28, 451.89}, {41.76, 440.62},
                {46.97, 415.76}, {58.38, 358.96}
            },
            {   -- -1000 ft
                {0, 445.76}, {17, 445.69}, {37.3, 444.81}, {39.78, 434.36}, {45.34, 409.54},
                {56.39, 356.45}
            },
            {   -- 0 ft
                {0, 444.77}, {15.02, 444.7}, {33.29, 444.13}, {37.79, 427.24}, {43.36, 403.94},
                {54.4, 353.12}
            },
            {   -- 1000 ft
                {0, 435.63}, {13.03, 435.56}, {31.31, 434.99}, {35.81, 419.2}, {41.37, 397.67},
                {46.43, 376.24}, {52.43, 349.33}
            },
            {   -- 2000 ft
                {0, 426.08}, {11.05, 426.04}, {29.33, 425.47}, {33.83, 411.24}, {39.39, 391.27},
                {44.95, 369.34}, {50.44, 345.48}
            },
            {   -- 3000 ft
                {0, 416.48}, {9.07, 416.44}, {27.34, 415.88}, {31.84, 402.6}, {37.41, 384.08},
                {42.96, 363.5}, {48.45, 341.16}
            },
            {   -- 4000 ft
                {0, 406.7}, {6.94, 406.7}, {25.36, 406.13}, {29.86, 393.49}, {35.42, 376.43},
                {40.98, 357.26}, {46.47, 336.41}
            },
            {   -- 5000 ft
                {0, 396.43}, {5.09, 396.43}, {23.41, 395.83}, {27.88, 384.42}, {33.43, 368.74},
                {39, 351}, {44.53, 331.52}
            },
            {   -- 6000 ft
                {0, 388.22}, {3.11, 388.22}, {15.94, 387.79}, {19.8, 387.58}, {25.68, 374.41},
                {31.45, 359.11}, {37.01, 342.82}, {42.54, 324.69}
            },
            {   -- 7000 ft
                {0, 376.88}, {16.15, 376.43}, {17.42, 376.53}, {23.91, 362.69}, {29.47, 349.37},
                {35.03, 334.25}, {40.55, 317.5}
            },
            {   -- 8000 ft
                {0, 365.73}, {14.94, 365.23}, {21.68, 352.52}, {27.52, 339.73}, {33.05, 326.04},
                {38.58, 310.41}
            },
            {   -- 9000 ft
                {0, 354.26}, {12.58, 353.83}, {19.69, 341.4}, {25.53, 329.68}, {31.07, 316.9},
                {36.59, 302.66}
            },
            {   -- 10000 ft
                {0, 343}, {10.2, 342.64}, {17.99, 330.18}, {23.55, 319.98}, {29.08, 308.15},
                {34.61, 295.01}
            },
        },
    },
}
M.QT = {   -- Quick Turnaround Limit, FPPM p.76 (1.4.6): 1000 kg, false blank
    oat = {50, 40, 30, 20, 10, 0, -10, -20, -30, -40, -50},
    pa = {-2000, -1000, 0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000},
    [30] = {
        {312, 306, 301, 294, 289, 283, false, false, false, false, false, false, false},   -- 50 C
        {318, 311, 305, 300, 293, 288, 282, 276, 271, 265, 260, false, false},   -- 40 C
        {323, 317, 311, 304, 298, 292, 287, 282, 275, 270, 264, 259, 254},   -- 30 C
        {329, 322, 316, 310, 303, 297, 291, 286, 279, 274, 269, 263, 258},   -- 20 C
        {335, 328, 322, 316, 309, 303, 297, 291, 285, 279, 274, 268, 262},   -- 10 C
        {342, 335, 328, 322, 316, 309, 303, 296, 290, 285, 279, 273, 268},   -- 0 C
        {348, 341, 328, 325, 321, 315, 308, 302, 296, 290, 284, 278, 272},   -- -10 C
        {353, 346, 340, 333, 327, 320, 314, 308, 302, 295, 289, 283, 278},   -- -20 C
        {360, 352, 346, 339, 333, 326, 320, 313, 307, 301, 295, 289, 284},   -- -30 C
        {365, 359, 352, 345, 338, 332, 325, 319, 312, 306, 291, 294, 288},   -- -40 C
        {373, 366, 359, 352, 345, 338, 332, 325, 319, 312, 306, 300, 294},   -- -50 C
    },
    [25] = {
        {294, 288, 282, 277, 271, 266, false, false, false, false, false, false, false},   -- 50 C
        {299, 293, 287, 281, 276, 271, 265, 260, 255, 250, 245, false, false},   -- 40 C
        {304, 298, 292, 286, 281, 275, 270, 264, 259, 254, 249, 244, 239},   -- 30 C
        {309, 303, 297, 291, 286, 280, 274, 269, 263, 258, 253, 248, 243},   -- 20 C
        {315, 309, 303, 297, 291, 285, 279, 274, 268, 263, 257, 252, 247},   -- 10 C
        {321, 314, 308, 302, 296, 290, 285, 279, 273, 268, 262, 257, 252},   -- 0 C
        {326, 320, 314, 308, 302, 296, 290, 284, 278, 273, 267, 262, 257},   -- -10 C
        {331, 325, 319, 313, 307, 301, 295, 289, 284, 278, 272, 267, 261},   -- -20 C
        {337, 331, 324, 318, 312, 306, 300, 294, 289, 283, 277, 272, 266},   -- -30 C
        {342, 336, 330, 324, 318, 311, 305, 299, 294, 288, 282, 276, 271},   -- -40 C
        {349, 342, 336, 329, 323, 317, 311, 305, 299, 293, 287, 282, 276},   -- -50 C
    },
    up = 2700, down = 7300, head = 5700, tail = 42600, brakes = 23100, wait_min = 70,
}
-- END GENERATED DATA

local floor, max, min = math.floor, math.max, math.min

local function isa_c(pa_ft) return 15 - 0.0019812 * pa_ft end
M.isa_c = isa_c

local CONDS = {DRY = "DRY", GOOD = "GOOD", WET = "GOOD", MEDIUM = "MEDIUM", POOR = "POOR"}
local function cond_key(cond)
    return type(cond) == "string" and CONDS[cond:upper()] or nil
end

local function brake_key(brake)
    if type(brake) == "number" then brake = tostring(floor(brake)) end
    if type(brake) ~= "string" then return nil end
    local b = brake:upper():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if b == "MAX MANUAL" or b == "MAX AUTO" then return b end
    if b == "MAX AUTOBRAKES" or b == "MAX AB" then return "MAX AUTO" end
    local n = b:match("^AUTOBRAKES? ?(%d)$") or b:match("^AB ?(%d)$") or b:match("^(%d)$")
    return n
end
M.cond_key, M.brake_key = cond_key, brake_key

-- a table's distance (in its unit) and the parts it adds up from; tbl one
-- of M.DIST[e] or M.FPPM_DIST; nothing checked but the row's being there
function M.table_distance(tbl, flaps, cond, brake, weight_kg, pa_ft, oat_c, wind_kt, slope_pct, vapp_add_kt,
                          reversers, manual_spoilers)
    local ft = tbl[flaps]
    local c, b = cond_key(cond), brake_key(brake)
    local row = ft and c and b and ft[c][b]
    if not row then return nil, "no such row" end
    local w = weight_kg
    if tbl.wt_unit == "LB" then w = weight_kg / M.KG_PER_LB end
    local steps = (w - tbl.ref_wt) / tbl.wt_step
    local p = {ref = row[1]}
    p.wt = steps >= 0 and steps * row[2] or -steps * row[3]
    p.alt = max(0, pa_ft) / 1000 * row[4]
    p.wind = wind_kt >= 0 and wind_kt / 10 * row[5] or -wind_kt / 10 * row[6]
    p.slope = slope_pct >= 0 and slope_pct * row[8] or -slope_pct * row[7]
    local dev = oat_c - isa_c(pa_ft)
    p.temp = dev >= 0 and dev / 10 * row[9] or -dev / 10 * row[10]
    p.app = vapp_add_kt / 10 * row[11]
    local rev = reversers or 4
    p.rev = rev >= 4 and 0 or rev >= 2 and row[12] or row[13]
    p.spoilers = (manual_spoilers and b == "MAX MANUAL") and tbl.manual_spoilers or 0
    return p.ref + p.wt + p.alt + p.wind + p.slope + p.temp + p.app + p.rev + p.spoilers, p
end

function M.distance(engine, flaps, cond, brake, weight_kg, pa_ft, oat_c, wind_kt, slope_pct, vapp_add_kt,
                    reversers, manual_spoilers)
    if engine ~= 0 and engine ~= 1 and engine ~= 2 then return nil, "engine 0, 1 or 2" end
    local tbl = M.DIST[engine == 1 and 1 or 0]          -- RR on the PW4056's (estimate)
    if not tbl[flaps] then return nil, "flaps 25 or 30" end
    local c, b = cond_key(cond), brake_key(brake)
    if not c then return nil, "runway DRY, GOOD (WET), MEDIUM or POOR" end
    if not b then return nil, "braking MAX MANUAL, MAX AUTO or autobrake 1-4" end
    if not tbl[flaps][c][b] then return nil, "no autobrake " .. b .. " in the " .. c .. " table" end
    if type(weight_kg) ~= "number" or weight_kg < M.WT_MIN or weight_kg > M.WT_MAX then
        return nil, "weight outside 150 to 400 t"
    end
    if type(pa_ft) ~= "number" or pa_ft < M.PA_MIN or pa_ft > M.PA_MAX then
        return nil, "pressure altitude outside -2,000 to 10,000 ft"
    end
    if type(oat_c) ~= "number" then return nil, "no OAT" end
    wind_kt, slope_pct, vapp_add_kt = wind_kt or 0, slope_pct or 0, vapp_add_kt or 0
    if -wind_kt > M.TAILWIND_MAX[engine] then return nil, "tailwind beyond the limit" end
    if math.abs(slope_pct) > M.SLOPE_MAX then return nil, "runway slope beyond +/-2 %" end
    if vapp_add_kt < 0 then return nil, "approach speed below VREF" end
    reversers = reversers or 4
    if reversers < 0 or reversers > 4 then return nil, "reversers 0 to 4" end
    local d = M.table_distance(tbl, flaps, c, b, weight_kg, pa_ft, oat_c, wind_kt, slope_pct, vapp_add_kt,
        reversers, manual_spoilers)
    if tbl.unit == "FT" then d = d * M.M_PER_FT end
    local factor = c == "DRY" and 1 or tbl.factor
    return d / factor, d
end

-- VREF (B747.68.vref_model.lua, FCOM PI.10.2) plus the additive
function M.approach_speed(flaps, weight_kg, elev_ft, add_kt)
    local V = B747_vref_model
    if not V then return nil, "no VREF model" end
    return V.vref(flaps, weight_kg, elev_ft or 0) + (add_kt or 0)
end

------------------------------------------------------------------------
-- the FPPM's charts
------------------------------------------------------------------------
-- a family of guide lines ({ft at the REF LINE, ft at the far edge}): from
-- x at the REF LINE the fraction frac of the way to the far edge, between
-- two lines by the fraction between them at the REF LINE (past the first
-- or last line the nearest two carried on: estimate)
local function along(lines, x, frac)
    if frac == 0 then return x end
    local n = #lines
    local i = 1
    while i < n - 1 and x > lines[i + 1][1] do i = i + 1 end
    local a, b = lines[i], lines[i + 1]
    local f = (x - a[1]) / (b[1] - a[1])
    local far = a[2] + f * (b[2] - a[2])
    return x + (far - x) * frac
end
M.along = along

-- v at u on a list of {u, v} sorted by u: nil, "below" before its first
-- point, nil, "above" past its last
local function on_line(l, u)
    if u < l[1][1] - 1e-9 then return nil, "below" end
    for k = 2, #l do
        if u <= l[k][1] + 1e-9 then
            local a, b = l[k - 1], l[k]
            return a[2] + (u - a[1]) / (b[1] - a[1]) * (b[2] - a[2])
        end
    end
    return nil, "above"
end

-- between two of a family's lines by altitude: the bracket and the fraction
local function bracket(alts, pa)
    local n = #alts
    local i = 1
    while i < n - 1 and pa > alts[i + 1] do i = i + 1 end
    return i, (pa - alts[i]) / (alts[i + 1] - alts[i])
end

-- the field chart's weight (1000 kg) at a corrected field length x (ft)
local function field_weight(c, x, pa)
    local i, f = bracket(c.alt, pa)
    local w = {}
    local top = false
    for k = 0, 1 do
        if (k == 0 and f < 1) or (k == 1 and f > 0) then
            local l = c.lines[i + k]
            local v, why = on_line(l, x)
            if not v then
                if why == "below" then return nil, "field length too short: below the chart's " .. c.wt[1] .. " t" end
                -- past the line's end: it ends at the chart's top
                v, top = l[#l][2], true
            end
            w[k] = v
        else
            w[k] = 0
        end
    end
    return w[0] + (w[1] - w[0]) * f, top
end

function M.field_limit(flaps, lda_m, pa_ft, wind_kt, cond, antiskid_inop, two_brakes_inop, manual_spoilers)
    local c = (antiskid_inop and M.FIELD_ASKID_INOP or M.FIELD)[flaps]
    if not c then return nil, "flaps 25 or 30" end
    if antiskid_inop and two_brakes_inop then
        return nil, "anti-skid must be operative for two brakes inoperative"   -- FPPM p.71
    end
    local cd = type(cond) == "string" and cond:upper() or "DRY"
    if cd ~= "DRY" and cd ~= "WET" then return nil, "the field charts are for a dry or wet runway" end
    if type(lda_m) ~= "number" or type(pa_ft) ~= "number" then return nil, "no field length or altitude" end
    if pa_ft < M.PA_MIN or pa_ft > M.PA_MAX then return nil, "pressure altitude outside -2,000 to 10,000 ft" end
    wind_kt = wind_kt or 0
    if -wind_kt > c.wind.tail then return nil, "tailwind beyond the chart's 15 kt" end
    local note
    local x = lda_m / M.M_PER_FT
    if manual_spoilers then x = x - c.manual_spoilers end
    if x < c.fla[1] then return nil, "field length below the chart's " .. c.fla[1] .. " ft" end
    if x > c.fla[2] then
        x, note = c.fla[2], "field length beyond the chart: its longest taken"
    end
    local w = wind_kt
    if w > c.wind.head then w, note = c.wind.head, "headwind beyond the chart: its 40 kt taken" end
    if w > 0 then
        x = along(c.wind.head_lines, x, w / c.wind.head)
    elseif w < 0 then
        x = along(c.wind.tail_lines, x, -w / c.wind.tail)
    end
    if two_brakes_inop then x = along(c.brakes, x, 1) end
    if cd == "WET" then x = along(c.wet, x, 1) end
    if x > c.fla[2] then x, note = c.fla[2], "corrected field length beyond the chart: its longest taken" end
    if x < c.fla[1] then return nil, "field length too short: below the chart" end
    local t, top = field_weight(c, x, pa_ft)
    if not t then return nil, top end
    if top or t > c.wt[2] then t, note = min(t, c.wt[2]), "above the chart's " .. c.wt[2] .. " t" end
    return t * 1000, note
end

function M.climb_limit(flaps, oat_c, pa_ft, packs, icing)
    local c = M.CLIMB[flaps]
    if not c then return nil, "flaps 25 or 30" end
    if type(oat_c) ~= "number" or type(pa_ft) ~= "number" then return nil, "no OAT or altitude" end
    if pa_ft < M.PA_MIN or pa_ft > M.PA_MAX then return nil, "pressure altitude outside -2,000 to 10,000 ft" end
    -- below the chart's 0 C its 0 C value (the curves are flat there: estimate)
    local t = max(oat_c, 0)
    local i, f = bracket(c.alt, pa_ft)
    local w = {}
    for k = 0, 1 do
        if (k == 0 and f < 1) or (k == 1 and f > 0) then
            local v = on_line(c.lines[i + k], t)
            if not v then return nil, "OAT above the chart for the altitude" end
            w[k] = v
        else
            w[k] = 0
        end
    end
    local kg = (w[0] + (w[1] - w[0]) * f) * 1000
    packs = packs or 3
    if packs == 1 then kg = kg + c.pack1
    elseif packs == 0 then kg = kg + c.pack0 end       -- 2 packs: the chart's 3 (estimate)
    if icing and oat_c < c.ice_below_c then kg = kg - c.ice end
    return kg
end

function M.quick_turnaround(flaps, pa_ft, oat_c, slope_pct, wind_kt, two_brakes_inop)
    local Q = M.QT
    local tbl = Q[flaps]
    if not tbl then return nil, "flaps 25 or 30" end
    if type(oat_c) ~= "number" or type(pa_ft) ~= "number" then return nil, "no OAT or altitude" end
    if pa_ft < Q.pa[1] or pa_ft > Q.pa[#Q.pa] then return nil, "pressure altitude outside the table" end
    if oat_c > Q.oat[1] then return nil, "OAT above the table's 50 C" end
    local t = max(oat_c, Q.oat[#Q.oat])                -- colder than -50 C: its -50 C row (estimate)
    local r = 1
    while r < #Q.oat - 1 and t < Q.oat[r + 1] do r = r + 1 end
    local fr = (Q.oat[r] - t) / (Q.oat[r] - Q.oat[r + 1])
    local c, fc = bracket(Q.pa, pa_ft)
    local sum = 0
    for dr = 0, 1 do
        for dc = 0, 1 do
            local wgt = (dr == 0 and 1 - fr or fr) * (dc == 0 and 1 - fc or fc)
            if wgt > 0 then
                local v = tbl[r + dr][c + dc]
                if not v then return nil, "outside the table (hot and high)" end
                sum = sum + wgt * v
            end
        end
    end
    local kg = sum * 1000
    slope_pct, wind_kt = slope_pct or 0, wind_kt or 0
    kg = kg + (slope_pct >= 0 and Q.up * slope_pct or Q.down * slope_pct)
    kg = kg + (wind_kt >= 0 and Q.head * wind_kt / 10 or Q.tail * wind_kt / 10)
    if two_brakes_inop then kg = kg - Q.brakes end
    return kg, Q.wait_min
end

-- the EFB page's dispatch block (FCOM p.1183): p = {flaps, lda_m, pa_ft,
-- elev_ft, oat_c, wind_kt, slope_pct, cond ("DRY"/"WET"), packs (3, 2,
-- 1, 0), antiskid_inop, two_brakes_inop, manual_spoilers, mlw_kg (the
-- structural limit, optional), weight_kg and vref_add_kt (optional: the
-- flaps 30 approach speed check)}. Returns r with
--   r.field, r.field_lowvis, r.climb, r.climb_ice: kg; r.why[name] the
--     reason when nil, or the chart's note (e.g. "above the chart's 400 t":
--     the weight a lower bound)
--   r.normal, r.ice, r.lowvis: {kg, limit ("FIELD"/"CLIMB"/"STRUCT"),
--     vref (VREF for the flaps at kg)}, nil when a chart gave no answer:
--     - normal the least of the field, climb and structural limits
--     - ice: the climb limit less the ice note's (when the OAT is below
--       the note's 8 C; the EFB's "With Ice")
--     - lowvis: the field length / 1.15 or 1.3 (CAT III autoland), r.lowvis_div
--   r.qt_kg, r.qt_min: the quick turnaround limit and the time to wait
--   r.f25_advised: flaps 30 approach speed (VREF 30 + additive, at
--     weight_kg or else the normal limit weight) above the box's 167 KIAS
--     (FPPM p.72): schedule flaps 25
function M.dispatch(p)
    local flaps = p.flaps or 30
    if not M.FIELD[flaps] then return nil, "flaps 25 or 30" end
    local r = {why = {}}
    local cond = p.cond or "DRY"
    r.field, r.why.field = M.field_limit(flaps, p.lda_m, p.pa_ft, p.wind_kt, cond, p.antiskid_inop,
        p.two_brakes_inop, p.manual_spoilers)
    local div = (not p.antiskid_inop) and M.CAT3_DIV[1] or M.CAT3_DIV[2]
    r.lowvis_div = div
    r.field_lowvis, r.why.field_lowvis = M.field_limit(flaps, (p.lda_m or 0) / div, p.pa_ft, p.wind_kt, cond,
        p.antiskid_inop, p.two_brakes_inop, p.manual_spoilers)
    r.climb, r.why.climb = M.climb_limit(flaps, p.oat_c, p.pa_ft, p.packs, false)
    r.climb_ice, r.why.climb_ice = M.climb_limit(flaps, p.oat_c, p.pa_ft, p.packs, true)
    local elev = p.elev_ft or p.pa_ft or 0
    local function least(field, climb)
        if not field or not climb then return nil end
        local kg, limit = field, "FIELD"
        if climb < kg then kg, limit = climb, "CLIMB" end
        if p.mlw_kg and p.mlw_kg < kg then kg, limit = p.mlw_kg, "STRUCT" end
        return {kg = kg, limit = limit, vref = M.approach_speed(flaps, kg, elev, 0)}
    end
    r.normal = least(r.field, r.climb)
    r.ice = least(r.field, r.climb_ice)
    r.lowvis = least(r.field_lowvis, r.climb)
    r.qt_kg, r.qt_min = M.quick_turnaround(flaps, p.pa_ft, p.oat_c, p.slope_pct, p.wind_kt, p.two_brakes_inop)
    if not r.qt_kg then r.why.qt, r.qt_min = r.qt_min, nil end
    if flaps == 30 and M.FIELD[30].f30_vapp_max then
        local w = p.weight_kg or (r.normal and r.normal.kg)
        local v = w and M.approach_speed(30, w, elev, p.vref_add_kt or 0)
        r.f25_advised = v ~= nil and v > M.FIELD[30].f30_vapp_max
    end
    return r
end

return M
