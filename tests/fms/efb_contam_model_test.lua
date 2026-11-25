-- Run from the repository root with LuaJIT: luajit tests/fms/efb_contam_model_test.lua
-- The EFB's takeoff on contaminated runways (plugins/xtlua_keysystems/
-- scripts/B747.68.xt.fms/B747.68.efb_contam_model.lua; 2026-11-25): the
-- FPPM's ADVISORY INFORMATION slush/standing water and slippery runway
-- tables (747-400F/PW4056: TO p.36-40 (1.2.12-16), TO1 p.48-53
-- (1.3.2-7), TO2 p.60-65 (1.3.14-19)) as printed, the method of p.20-21
-- (1.1.2-3) worked by hand, the trends the tables show, nil off them.
local T = dofile("tests/lib/check.lua")("efb_contam_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_contam_model.lua")

local BRAKING = {"GOOD", "MEDIUM", "POOR"}
local function colval(kind, g) return kind == "SLUSH" and M.DEPTH_MM[g] or BRAKING[g] end

------------------------------------------------------------------------
-- the tables: count, every printed cell through the model's functions
------------------------------------------------------------------------
local ntab, ncell = 0, 0
for _, rating in ipairs({0, 8, 20}) do
    for _, kind in ipairs({"SLUSH", "SLIPPERY"}) do
        for _, rev in ipairs({2, 0}) do
            for _, name in ipairs({"wa", "vmcg", "v1"}) do
                local t = M.DATA[rating][kind][rev][name]
                ntab = ntab + 1
                local cells, bad = 0, {}
                for _, row in ipairs(t) do
                    for j = 1, 9 do
                        local want = row[1 + j]
                        if want then
                            cells = cells + 1
                            local g, a = math.floor((j - 1) / 3) + 1, (j - 1) % 3 + 1
                            local dob, pa = colval(kind, g), M.ALT_FT[a]
                            local got
                            if name == "wa" then
                                got = M.weight_adjustment(kind, dob, rev, rating, row[1] * 1000, pa)
                                want = want * 1000
                            elseif name == "vmcg" then
                                got = M.vmcg_weight(kind, dob, rev, rating, row[1], pa, 20)
                                want = want * 1000
                            else
                                got = M.v1_adjustment(kind, dob, rev, rating, row[1] * 1000, pa, 20)
                                for _, mp in ipairs(M.MISPRINTS) do
                                    if mp.rating == rating and mp.kind == kind and mp.rev == rev and mp.tbl == name
                                        and mp.row == row[1] and mp.col == j then want = mp.used end
                                end
                            end
                            if got ~= want then
                                bad[#bad + 1] = string.format("row %d col %d: %s (%s)", row[1], j, tostring(got), tostring(want))
                            end
                        end
                    end
                end
                ncell = ncell + cells
                T.check(cells == t.n and #bad == 0, string.format("p.%d %s: its %d cells as printed (%d read): %s",
                    t.page, name, t.n, cells, table.concat(bad, ", ")))
            end
        end
    end
end
-- the extraction's counts (docs/overhaul/tools/fppm_contam.lua's run)
T.equal(ntab, 36, "the tables")
T.equal(M.TABLE_COUNT, 36, "the script's table count")
T.equal(ncell, 2733, "the printed cells")
T.equal(M.CELL_COUNT, 2733, "the script's cell count")
T.check(M.MISPRINTS[1].applied, "p.48's misprint found where it is printed")

------------------------------------------------------------------------
-- this test's own transcription from the page images: two rows of every
-- table (row label, 9 cells, nil blank), the rows' range and count, the
-- notes' flaps 10 change as printed
------------------------------------------------------------------------
local _ = nil
local OWN = {
    -- page, rating, kind, rev, table, first row, last row, rows, {row, cells}, {row, cells}, f10, f10_cond
    {36, 0, "SLUSH", 2, "wa", 440, 280, 9, {440, _, _, _, -35, -35, -35, -52, -52, -52}, {280, -16, -16, -16, -23, -23, -23, -42, -42, -42}},
    {36, 0, "SLUSH", 2, "vmcg", 8200, 14600, 17, {9400, 228, _, _, 253, _, _, 290, 220, _}, {12600, 417, 344, 271, 438, 366, 295, _, 400, 330}, -12000},
    {36, 0, "SLUSH", 2, "v1", 400, 280, 7, {400, -31, -29, -27, -27, -25, -23, -16, -14, -12}, {280, -35, -33, -31, -32, -30, -28, -26, -24, -22}, -1},
    {37, 0, "SLUSH", 0, "wa", 440, 280, 9, {440, -32, -32, -32, -41, -41, -41, -64, -64, -64}, {280, -18, -18, -18, -24, -24, -24, -41, -41, -41}},
    {37, 0, "SLUSH", 0, "vmcg", 10200, 15000, 13, {12200, 266, _, _, 314, 241, _, 374, 308, 243}, {15000, 457, 381, 305, _, 424, 351, _, 472, 407}, -14000},
    {37, 0, "SLUSH", 0, "v1", 400, 280, 7, {400, -39, -37, -34, -34, -31, -28, -21, -18, -15}, {280, -43, -40, -38, -40, -38, -35, -33, -30, -27}, -3},
    {38, 0, "SLIPPERY", 2, "wa", 400, 240, 9, {400, 0, 0, 0, -6, -6, -6, -18, -18, -18}, {240, 0, 0, 0, -3, -3, -3, -7, -7, -7}},
    {38, 0, "SLIPPERY", 2, "vmcg", 6000, 16400, 27, {7200, 365, 279, 193, _, _, _, _, _, _}, {14400, _, _, _, _, _, _, 420, 351, 282}, -10000, "POOR"},
    {39, 0, "SLIPPERY", 2, "v1", 400, 240, 9, {400, -6, -5, -4, -23, -19, -16, -43, -38, -33}, {240, -15, -14, -13, -34, -30, -27, -54, -49, -44}, 1, "GOOD"},
    {40, 0, "SLIPPERY", 0, "wa", 400, 240, 9, {320, -1, -1, -1, -8, -8, -8, -16, -16, -16}, {240, 0, 0, 0, -4, -4, -4, -9, -9, -9}},
    {40, 0, "SLIPPERY", 0, "vmcg", 6200, 15000, 23, {11000, _, _, _, 404, 323, 242, _, _, _}, {15000, _, _, _, _, _, _, 274, _, _}, -18000, "POOR"},
    {40, 0, "SLIPPERY", 0, "v1", 400, 240, 9, {400, -8, -6, -5, -28, -24, -21, -54, -50, -46}, {240, -20, -18, -16, -42, -38, -35, -67, -63, -59}, 2, "GOOD"},
    {48, 8, "SLUSH", 2, "wa", 440, 280, 9, {440, _, _, _, -34, -34, -34, -49, -49, -49}, {280, -16, -16, -16, -22, -22, -22, -39, -39, -39}},
    {48, 8, "SLUSH", 2, "vmcg", 7800, 13800, 16, {11400, 381, 304, 227, 402, 327, 252, _, 362, 289}, {13800, _, _, 376, _, _, 398, _, _, _}, -12000},
    {48, 8, "SLUSH", 2, "v1", 400, 280, 7, {380, -30, 28, -26, -25, -23, -21, -12, -10, -8}, {280, -33, -31, -29, -29, -27, -25, -22, -20, -18}, -1},
    {49, 8, "SLUSH", 0, "wa", 440, 280, 9, {440, -31, -31, -31, -39, -39, -39, -62, -62, -62}, {280, -17, -17, -17, -23, -23, -23, -40, -40, -40}},
    {49, 8, "SLUSH", 0, "vmcg", 9400, 15000, 15, {13000, 366, 287, _, 409, 334, 258, 459, 391, 324}, {15000, _, 427, 349, _, 468, 393, _, _, 445}, -14000},
    {49, 8, "SLUSH", 0, "v1", 400, 200, 11, {360, -37, -34, -31, -31, -28, -25, -17, -14, -11}, {200, -35, -32, -28, -33, -30, -27, -30, -27, -23}, -3},
    {50, 8, "SLIPPERY", 2, "wa", 400, 220, 10, {400, 0, 0, 0, -4, -4, -4, -16, -16, -16}, {220, 0, 0, 0, -3, -3, -3, -6, -6, -6}},
    {50, 8, "SLIPPERY", 2, "vmcg", 5600, 16000, 27, {9200, _, _, 429, 354, 274, 194, _, _, _}, {12800, _, _, _, _, _, _, 357, 288, 217}, -10000, "POOR"},
    {51, 8, "SLIPPERY", 2, "v1", 400, 220, 10, {400, -4, -3, -2, -19, -15, -12, -39, -34, -29}, {220, -14, -13, -12, -32, -28, -25, -50, -45, -40}, 1, "GOOD"},
    {52, 8, "SLIPPERY", 0, "wa", 400, 220, 10, {400, 0, 0, 0, -7, -7, -7, -19, -19, -19}, {220, 0, 0, 0, -3, -3, -3, -7, -7, -7}},
    {52, 8, "SLIPPERY", 0, "vmcg", 5800, 15000, 24, {7000, 335, 261, 188, _, _, _, _, _, _}, {15000, _, _, _, _, _, _, 341, 255, _}, -18000, "POOR"},
    {53, 8, "SLIPPERY", 0, "v1", 400, 220, 10, {400, -5, -3, -1, -22, -18, -15, -46, -42, -37}, {220, -16, -15, -13, -38, -34, -29, -62, -57, -52}, 2, "GOOD"},
    {60, 20, "SLUSH", 2, "wa", 440, 280, 9, {420, -28, -28, -28, -32, -32, -32, -44, -44, -44}, {280, -16, -16, -16, -22, -22, -22, -36, -36, -36}},
    {60, 20, "SLUSH", 2, "vmcg", 7000, 13000, 16, {10200, 355, 273, _, 377, 297, 217, 411, 333, 255}, {13000, _, _, 376, _, _, 398, _, _, _}, -12000},
    {60, 20, "SLUSH", 2, "v1", 400, 280, 7, {400, -24, -22, -20, -18, -16, -14, -3, -1, 0}, {280, -29, -27, -25, -25, -23, -21, -17, -15, -13}, -1},
    {61, 20, "SLUSH", 0, "wa", 440, 280, 9, {440, -34, -34, -34, -42, -42, -42, -64, -64, -64}, {280, -19, -19, -19, -25, -25, -25, -41, -41, -41}},
    {61, 20, "SLUSH", 0, "vmcg", 9000, 15000, 16, {12200, 382, 297, _, 424, 344, 263, 473, 400, 328}, {15000, _, _, 424, _, _, 465, _, _, _}, -15000},
    {61, 20, "SLUSH", 0, "v1", 400, 200, 11, {400, -27, -23, -20, -20, -16, -12, -3, 1, 5}, {200, -29, -26, -22, -28, -24, -20, -24, -20, -16}, -3},
    {62, 20, "SLIPPERY", 2, "wa", 400, 220, 10, {400, 0, 0, 0, -7, -7, -7, -18, -18, -18}, {220, 0, 0, 0, -2, -2, -2, -7, -7, -7}},
    {62, 20, "SLIPPERY", 2, "vmcg", 5200, 15200, 26, {8800, _, _, 418, 363, 283, 203, _, _, _}, {12000, _, _, _, _, _, _, 361, 286, 210}, -10000, "POOR"},
    {63, 20, "SLIPPERY", 2, "v1", 400, 220, 10, {400, -1, 0, 1, -16, -12, -9, -30, -25, -20}, {220, -12, -11, -10, -30, -26, -23, -47, -42, -37}, 1, "GOOD"},
    {64, 20, "SLIPPERY", 0, "wa", 400, 220, 10, {400, 0, 0, 0, -7, -7, -7, -19, -19, -19}, {220, 0, 0, 0, -4, -4, -4, -8, -8, -8}},
    -- p.64's note prints an increase (the model takes it as a decrease)
    {64, 20, "SLIPPERY", 0, "vmcg", 5400, 15000, 25, {9400, _, _, _, 354, 275, 196, _, _, _}, {14200, _, _, _, _, _, _, 370, 278, 187}, 19000, "POOR"},
    {65, 20, "SLIPPERY", 0, "v1", 400, 220, 10, {400, 0, 0, 0, -14, -10, -6, -35, -29, -24}, {220, -14, -12, -10, -33, -28, -23, -56, -50, -44}, 2, "GOOD"},
}
T.equal(#OWN, 36, "the transcription covers every table")
for _, o in ipairs(OWN) do
    local page, rating, kind, rev, name = o[1], o[2], o[3], o[4], o[5]
    local t = M.DATA[rating][kind][rev][name]
    local what = string.format("p.%d %s", page, name)
    T.equal(t.page, page, what .. ": page")
    T.check(t[1][1] == o[6] and t[#t][1] == o[7] and #t == o[8],
        string.format("%s: rows %d to %d, %d (data %d to %d, %d)", what, o[6], o[7], o[8], t[1][1], t[#t][1], #t))
    for _, own in ipairs({o[9], o[10]}) do
        local row
        for _, r in ipairs(t) do
            if r[1] == own[1] then row = r end
        end
        local same = row ~= nil
        for j = 1, 9 do
            if row and (row[1 + j] or nil) ~= own[1 + j] then same = false end
        end
        T.check(same, string.format("%s: row %d as transcribed", what, own[1]))
    end
    T.equal(t.f10, o[11], what .. ": the flaps 10 note")
    T.equal(t.f10_cond, o[12], what .. ": the flaps 10 note's braking action")
end

------------------------------------------------------------------------
-- worked examples, by hand per FPPM p.20-21's steps
------------------------------------------------------------------------
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- A. TO, slush 6 mm, 2 engine reverse (p.36), field/obstacle limit 350 t,
-- 11,000 ft available, 2,000 ft pressure altitude, flaps 20:
--   step 2: 6 mm at 350 t between 360 t (-29) and 340 t (-28) = -28.5 t
--           -> 350 - 28.5 = 321.5 t
--   step 3: 6 mm at 11,000 ft: S.L. 346, 4000 ft 274 -> 2000 ft 310 t
--   step 4: the lesser: 310 t, VMCG limited
local w, work = M.limit("SLUSH", 6, 2, 0, 350000, 11000, 2000, 20)
T.check(near(w, 310000), "A: 310 t: " .. tostring(w))
T.check(near(work.adjust_kg, -28500) and near(work.field_kg, 321500) and near(work.vmcg_kg, 310000),
    "A: the working -28.5 t, 321.5 t, 310 t")
T.check(work.limit == "VMCG" and work.vmcg_limited == true and #work.est == 0, "A: VMCG limited, no estimate")
-- V1 (p.21 step 2): VMCG limited, V1 = VMCG
local v1, vw = M.v1("SLUSH", 6, 2, 0, 310000, 150, 120, work.vmcg_limited, 2000, 20)
T.check(v1 == 120 and vw.vmcg_limited and vw.adjust_kt == nil, "A: VMCG limited: V1 = VMCG 120")
-- not VMCG limited at 310 t: 6 mm S.L. 320 t -31, 300 t -32 -> -31.5;
-- 4000 ft -29, -30 -> -29.5; 2000 ft -30.5: 150 - 30.5 = 119.5 kt
v1, vw = M.v1("SLUSH", 6, 2, 0, 310000, 150, 115, false, 2000, 20)
T.check(near(v1, 119.5) and near(vw.adjust_kt, -30.5) and not vw.floored, "A: V1 150 - 30.5 = 119.5: " .. tostring(v1))
v1, vw = M.v1("SLUSH", 6, 2, 0, 310000, 150, 125, false, 2000, 20)
T.check(v1 == 125 and vw.floored, "A: 119.5 below VMCG 125: V1 = VMCG")

-- B. TO, slush 4.5 mm (between 3 and 6 mm: p.20 allows it), no reverse
-- (p.37), 400 t, 13,400 ft, S.L., flaps 10:
--   step 2: 3 mm -29, 6 mm -37 -> -33 t -> 367 t
--   step 3: 3 mm 348, 6 mm 392 -> 370 t; flaps 10 (note 2): -14 t -> 356 t
--   step 4: 356 t, VMCG limited
w, work = M.limit("SLUSH", 4.5, 0, 0, 400000, 13400, 0, 10)
T.check(near(w, 356000) and near(work.field_kg, 367000) and work.vmcg_limited, "B: 356 t: " .. tostring(w))
-- V1 adjustment at 356 t: 3 mm 360 t -42, 340 t -42 -> -42; 6 mm -37,
-- -38 -> -37.2; 4.5 mm -39.6; flaps 10 (note 2): 3 kt more -> -42.6
T.check(near(M.v1_adjustment("SLUSH", 4.5, 0, 0, 356000, 0, 10), -42.6), "B: V1 adjustment -42.6 kt")
T.check(near(M.v1_adjustment("SLUSH", 4.5, 0, 0, 356000, 0, 20), -39.6), "B: flaps 20 -39.6 kt")

-- C. TO, slippery MEDIUM, no reverse (p.40), 300 t, 6,000 ft:
--   step 2: MEDIUM at 300 t -7 t -> 293 t
--   step 3, 11,000 ft: 4000 ft 323, 8000 ft 242 -> 282.5 t (VMCG limited)
w, work = M.limit("SLIPPERY", "MEDIUM", 0, 0, 300000, 11000, 6000, 20)
T.check(near(w, 282500) and near(work.field_kg, 293000) and work.limit == "VMCG", "C: 282.5 t: " .. tostring(w))
--   10,800 ft: 4000 ft 278 + (323 - 278) / 2 = 300.5; 8000 ft printed from
--   11,000 ft (242, then 287): its step carried on, 242 - 45 / 2 = 219.5
--   (estimate) -> 260 t, not below 242 t: kept
w, work = M.limit("SLIPPERY", "MEDIUM", 0, 0, 300000, 10800, 6000, 20)
T.check(near(w, 260000) and work.est[1] == "VMCG TABLE EXTENDED", "C: 10,800 ft 260 t, extended: " .. tostring(w))
--   10,400 ft: 4000 ft 255.5, 8000 ft 242 - 45 * 1.5 = 174.5 -> 215 t,
--   lighter than the 8000 ft column's lightest printed 242 t: off the table
w, work = M.limit("SLIPPERY", "MEDIUM", 0, 0, 300000, 10400, 6000, 20)
T.check(w == nil and work == "FIELD LENGTH TOO SHORT FOR THE VMCG TABLE", "C: 10,400 ft too short: " .. tostring(work))

-- D. TO1 (8 %), slippery POOR, 2 engine reverse (p.50, p.51), the TO1
-- field/obstacle limit 330 t, 12,000 ft, S.L., flaps 10:
--   step 2: POOR 340 t -15, 320 t -14 -> -14.5 -> 315.5 t
--   step 3: POOR S.L. 308 t; flaps 10 and poor (note 2): -10 t -> 298 t
w, work = M.limit("SLIPPERY", "POOR", 2, 8, 330000, 12000, 0, 10)
T.check(near(w, 298000) and near(work.field_kg, 315500) and work.vmcg_limited, "D: 298 t: " .. tostring(w))
-- V1 adjustment at 298 t: POOR S.L. 300 t -50, 280 t -50 -> -50; the flaps
-- 10 note is for good braking only
T.check(near(M.v1_adjustment("SLIPPERY", "POOR", 2, 8, 298000, 0, 10), -50), "D: V1 adjustment -50 kt")

-- E. TO2 (20 %), slippery GOOD, 2 engine reverse (p.63), 390 t, S.L.,
-- flaps 10: GOOD 400 t -1, 380 t -4 -> -2.5; flaps 10 and good: +1 -> -1.5
v1, vw = M.v1("SLIPPERY", "GOOD", 2, 20, 390000, 150, 130, false, 0, 10)
T.check(near(v1, 148.5) and near(vw.adjust_kt, -1.5), "E: V1 150 - 1.5 = 148.5: " .. tostring(v1))
T.check(near(M.v1_adjustment("SLIPPERY", "MEDIUM", 2, 20, 390000, 0, 10), -16.5), "E: MEDIUM no flaps 10 change: -16.5")

-- F. 5 % (between TO and TO1: estimate), slush 13 mm, 2 engine reverse,
-- 380 t, 12,000 ft, S.L.: 3/8 of TO's and 5/8 of TO1's
--   step 2: TO -48 (p.36), TO1 -45 (p.48) -> -46.125 -> 333.875 t
--   step 3: 12,000 ft is past both columns' printed cells (TO's to
--   11,400 ft, TO1's to 11,000 ft): their steps carried on (estimate):
--   TO 403 + 23 * 1.5 = 437.5, TO1 412 + 24 * 2.5 = 472 -> 459.0625 t
--   step 4: 333.875 t, field limited
w, work = M.limit("SLUSH", 13, 2, 5, 380000, 12000, 0, 20)
T.check(near(w, 333875) and near(work.vmcg_kg, 459062.5) and work.limit == "FIELD", "F: 333.875 t: " .. tostring(w))
local est = table.concat(work.est, ",")
T.check(est:find("RATING BETWEEN TABLES", 1, true) and est:find("VMCG TABLE EXTENDED", 1, true), "F: the estimates named: " .. est)
-- 14 % (between TO1 and TO2), slush 6 mm, 340 t, S.L.: TO1 -27 (p.48),
-- TO2 -22 (p.60) -> -24.5 kt
T.check(near(M.v1_adjustment("SLUSH", 6, 2, 14, 340000, 0, 20), -24.5), "F: 14 % V1 adjustment -24.5")

-- G. TO2 slippery POOR, no reverse (p.64), 13,800 ft, S.L.: 332 t; flaps 10:
-- the note's 19000 kg taken off (printed as an increase: see the model)
T.check(near(M.vmcg_weight("SLIPPERY", "POOR", 0, 20, 13800, 0, 20), 332000), "G: 332 t")
T.check(near(M.vmcg_weight("SLIPPERY", "POOR", 0, 20, 13800, 0, 10), 313000), "G: flaps 10 332 - 19 = 313 t")
T.check(near(M.vmcg_weight("SLIPPERY", "MEDIUM", 0, 20, 9400, 0, 10), 354000), "G: MEDIUM: no flaps 10 change")
-- slush: every depth (p.61: 15000 kg): 3 mm S.L. 12,200 ft 382 t -> 367 t
T.check(near(M.vmcg_weight("SLUSH", 3, 0, 20, 12200, 0, 10), 367000), "G: TO2 slush flaps 10 382 - 15 = 367 t")

-- H. Above the table's heaviest printed row: that row's adjustment held
-- (estimate). p.36 3 mm: 440 t blank, 420 t -27 -> 430 t: -27 t
local adj, e = M.weight_adjustment("SLUSH", 3, 2, 0, 430000, 0)
T.check(near(adj, -27000) and e[1] == "ADJUSTMENT HELD ABOVE TABLE", "H: 3 mm 430 t: -27 t held")
adj, e = M.weight_adjustment("SLUSH", 3, 2, 0, 410000, 0)
T.check(near(adj, -26000) and #e == 0, "H: 410 t between 400 (-25) and 420 (-27): -26 t")
adj = M.weight_adjustment("SLUSH", 13, 0, 0, 470000, 4000)
T.check(near(adj, -64000), "H: p.37 13 mm 470 t: 440 t's -64 t held")

-- I. p.48's misprint: 380 t, 3 mm, 4000 ft printed 28, used -28
T.check(near(M.v1_adjustment("SLUSH", 3, 2, 8, 380000, 4000, 20), -28), "I: p.48 380 t 3 mm 4000 ft -28")
T.check(near(M.v1_adjustment("SLUSH", 3, 2, 8, 390000, 4000, 20), -27.5), "I: 390 t between -27 and -28")

-- the derates' own tables: 13 mm at 400 t, S.L.: TO -50 (p.36), TO1 -46
-- (p.48), TO2 -43 (p.60)
T.check(near(M.weight_adjustment("SLUSH", 13, 2, 0, 400000, 0), -50000), "TO p.36 13 mm 400 t -50 t")
T.check(near(M.weight_adjustment("SLUSH", 13, 2, 8, 400000, 0), -46000), "TO1 p.48 13 mm 400 t -46 t")
T.check(near(M.weight_adjustment("SLUSH", 13, 2, 20, 400000, 0), -43000), "TO2 p.60 13 mm 400 t -43 t")
-- 4 % halfway between TO's and TO1's: -48 t
T.check(near(M.weight_adjustment("SLUSH", 13, 2, 4, 400000, 0), -48000), "4 %: -48 t")
-- below sea level: the S.L. column (estimate)
adj, e = M.weight_adjustment("SLUSH", 13, 2, 0, 400000, -500)
T.check(near(adj, -50000) and e[1] == "BELOW S.L.", "below S.L.: S.L.'s -50 t")

------------------------------------------------------------------------
-- the trends the tables show (sampled through the model)
------------------------------------------------------------------------
local function each(fn)
    for _, rating in ipairs({0, 8, 20}) do
        for _, kind in ipairs({"SLUSH", "SLIPPERY"}) do
            for _, rev in ipairs({2, 0}) do fn(rating, kind, rev) end
        end
    end
end
local ALTS = {0, 1000, 2500, 4000, 6000, 8000}
local SLUSH_D = {3, 4, 5, 6, 8, 10, 13}

-- the adjusted field/obstacle limit weight rises with the limit weight
local bad = {}
each(function(rating, kind, rev)
    local dobs = kind == "SLUSH" and SLUSH_D or BRAKING
    for _, dob in ipairs(dobs) do
        local last
        for wt = 280, 480, 2.5 do
            local a = M.weight_adjustment(kind, dob, rev, rating, wt * 1000, 3000)
            if a and last and wt * 1000 + a <= last then bad[#bad + 1] = string.format("%d %s %d %s %.1f t", rating, kind, rev, dob, wt) end
            last = a and wt * 1000 + a or last
        end
    end
end)
T.check(#bad == 0, "adjusted weight rising with the limit weight: " .. table.concat(bad, "; "))

-- deeper slush, worse braking: the adjusted weight lower; the VMCG limit
-- weight higher in slush (the slush's drag helps the stop), lower on
-- slippery runways; the V1 adjustment higher in slush, lower on slippery
bad = {}
each(function(rating, kind, rev)
    local dobs = kind == "SLUSH" and SLUSH_D or BRAKING
    for _, pa in ipairs(ALTS) do
        for k = 2, #dobs do
            local a, b = dobs[k - 1], dobs[k]
            for wt = 280, 400, 10 do
                local x = M.weight_adjustment(kind, a, rev, rating, wt * 1000, pa)
                local y = M.weight_adjustment(kind, b, rev, rating, wt * 1000, pa)
                if x and y and y > x + 1e-6 then bad[#bad + 1] = string.format("wa %d %s %d %s>%s %d", rating, kind, rev, a, b, wt) end
                x = M.v1_adjustment(kind, a, rev, rating, wt * 1000, pa, 20)
                y = M.v1_adjustment(kind, b, rev, rating, wt * 1000, pa, 20)
                if x and y and ((kind == "SLUSH" and y < x - 1e-6) or (kind == "SLIPPERY" and y > x + 1e-6)) then
                    bad[#bad + 1] = string.format("v1 %d %s %d %s>%s %d t %d ft", rating, kind, rev, a, b, wt, pa)
                end
            end
            for fla = 5000, 17000, 200 do
                local x = M.vmcg_weight(kind, a, rev, rating, fla, pa, 20)
                local y = M.vmcg_weight(kind, b, rev, rating, fla, pa, 20)
                if x and y and ((kind == "SLUSH" and y < x - 1e-6) or (kind == "SLIPPERY" and y > x + 1e-6)) then
                    bad[#bad + 1] = string.format("vmcg %d %s %d %s>%s %d ft %d ft", rating, kind, rev, a, b, fla, pa)
                end
            end
        end
    end
end)
T.check(#bad == 0, "deeper / worse braking trends: " .. table.concat(bad, "; "))

-- the VMCG limit weight rises with the field length, falls with the
-- pressure altitude; the V1 adjustment rises with the pressure altitude
bad = {}
each(function(rating, kind, rev)
    local dobs = kind == "SLUSH" and SLUSH_D or BRAKING
    for _, dob in ipairs(dobs) do
        for _, pa in ipairs(ALTS) do
            local last
            for fla = 5000, 17000, 100 do
                local v = M.vmcg_weight(kind, dob, rev, rating, fla, pa, 20)
                if v and last and v <= last then bad[#bad + 1] = string.format("fla %d %s %d %s %d ft", rating, kind, rev, dob, fla) end
                last = v or last
            end
        end
        for fla = 5000, 17000, 400 do
            for k = 2, #ALTS do
                local x = M.vmcg_weight(kind, dob, rev, rating, fla, ALTS[k - 1], 20)
                local y = M.vmcg_weight(kind, dob, rev, rating, fla, ALTS[k], 20)
                if x and y and y >= x then bad[#bad + 1] = string.format("alt %d %s %d %s %d ft", rating, kind, rev, dob, fla) end
            end
        end
        for wt = 200, 400, 10 do
            for k = 2, #ALTS do
                local x = M.v1_adjustment(kind, dob, rev, rating, wt * 1000, ALTS[k - 1], 20)
                local y = M.v1_adjustment(kind, dob, rev, rating, wt * 1000, ALTS[k], 20)
                if x and y and y < x - 1e-6 then bad[#bad + 1] = string.format("v1 alt %d %s %d %s %d t", rating, kind, rev, dob, wt) end
            end
        end
    end
end)
T.check(#bad == 0, "field length and altitude trends: " .. table.concat(bad, "; "))

-- no reverse thrust: the adjusted weight not higher than with 2 engine
-- reverse (but p.37's 13 mm 280 t row, printed -41 against p.36's -42:
-- below 300 t the 13 mm comparison is skipped); the VMCG limit weight not
-- higher in slush and at MEDIUM and POOR braking, within the printed cells
-- (GOOD's no reverse columns rise faster with the field length and cross
-- the 2 engine reverse ones: p.40 against p.38 at 8000 ft, 8,800 ft:
-- 367.5 t against 365 t; carried on past the cells the lines cross too);
-- the V1 adjustment lower for the full rating (p.36/37, p.39/40). The
-- derates' tables do not show it: at heavy weights their no reverse V1
-- adjustment is up to 5 kt higher (p.60/61 13 mm 400 t 8000 ft: 0, +5)
bad = {}
each(function(rating, kind, rev)
    if rev ~= 2 then return end
    local dobs = kind == "SLUSH" and SLUSH_D or BRAKING
    for _, dob in ipairs(dobs) do
        for _, pa in ipairs(ALTS) do
            for wt = 280, 440, 10 do
                local skip = kind == "SLUSH" and dob > 6 and wt < 300 and rating == 0
                local x = M.weight_adjustment(kind, dob, 2, rating, wt * 1000, pa)
                local y = M.weight_adjustment(kind, dob, 0, rating, wt * 1000, pa)
                if not skip and x and y and y > x + 1e-6 then bad[#bad + 1] = string.format("wa %d %s %s %d t", rating, kind, dob, wt) end
                if rating == 0 and wt <= 400 then
                    x = M.v1_adjustment(kind, dob, 2, rating, wt * 1000, pa, 20)
                    y = M.v1_adjustment(kind, dob, 0, rating, wt * 1000, pa, 20)
                    if x and y and y > x + 1e-6 then bad[#bad + 1] = string.format("v1 %d %s %s %d t %d ft", rating, kind, dob, wt, pa) end
                end
            end
            for fla = 5000, 17000, 200 do
                local x, ex = M.vmcg_weight(kind, dob, 2, rating, fla, pa, 20)
                local y, ey = M.vmcg_weight(kind, dob, 0, rating, fla, pa, 20)
                if x and y and #ex == 0 and #ey == 0 and dob ~= "GOOD" and y > x + 1e-6 then
                    bad[#bad + 1] = string.format("vmcg %d %s %s %d ft %d ft", rating, kind, dob, fla, pa)
                end
            end
        end
    end
end)
T.check(#bad == 0, "no reverse trends: " .. table.concat(bad, "; "))
T.check(near(M.vmcg_weight("SLIPPERY", "GOOD", 2, 0, 8800, 8000, 20), 365000)
    and near(M.vmcg_weight("SLIPPERY", "GOOD", 0, 0, 8800, 8000, 20), 367500),
    "GOOD 8000 ft 8,800 ft: 2 engine reverse 365 t (p.38), no reverse 367.5 t (p.40), as printed")
T.check(M.weight_adjustment("SLUSH", 13, 0, 0, 280000, 0) > M.weight_adjustment("SLUSH", 13, 2, 0, 280000, 0),
    "p.36/37 13 mm 280 t: no reverse -41 above 2 engine reverse -42, as printed")

------------------------------------------------------------------------
-- off the tables: nil and the reason
------------------------------------------------------------------------
local function off(why, want, ...)
    local v, r = ...
    T.check(v == nil and r == want, why .. ": " .. tostring(v) .. " " .. tostring(r))
end
off("slush 14 mm", "SLUSH OVER 13 MM NOT RECOMMENDED", M.limit("SLUSH", 14, 2, 0, 350000, 11000, 0, 20))
off("slush 2 mm", "SLUSH UNDER 3 MM OFF THE TABLES", M.limit("SLUSH", 2, 2, 0, 350000, 11000, 0, 20))
off("slush 14 mm V1", "SLUSH OVER 13 MM NOT RECOMMENDED", M.v1("SLUSH", 14, 2, 0, 300000, 150, 120, true, 0, 20))
off("8,500 ft", "PRESSURE ALTITUDE ABOVE 8000 FT", M.limit("SLUSH", 6, 2, 0, 350000, 11000, 8500, 20))
off("25 %", "THRUST REDUCTION OFF THE TABLES", M.limit("SLUSH", 6, 2, 25, 350000, 11000, 0, 20))
off("1 reverser", "REVERSE THRUST 2 OR 0 ENGINES", M.limit("SLUSH", 6, 1, 0, 350000, 11000, 0, 20))
off("braking NIL", "BRAKING ACTION GOOD, MEDIUM OR POOR", M.limit("SLIPPERY", "NIL", 2, 0, 350000, 11000, 0, 20))
off("ice", "RUNWAY SLUSH OR SLIPPERY", M.limit("ICE", 6, 2, 0, 350000, 11000, 0, 20))
off("flaps 25", "FLAPS 10 OR 20", M.limit("SLUSH", 6, 2, 0, 350000, 11000, 0, 25))
off("field limit 270 t", "FIELD/OBSTACLE LIMIT WEIGHT BELOW THE TABLE", M.limit("SLUSH", 6, 2, 0, 270000, 11000, 0, 20))
off("no field limit", "NO FIELD/OBSTACLE LIMIT WEIGHT", M.limit("SLUSH", 6, 2, 0, nil, 11000, 0, 20))
-- p.36 3 mm S.L. printed from 9,400 ft (228 t): 9,000 ft carried on gives
-- 204 t, lighter than 228 t
off("3 mm 9,000 ft", "FIELD LENGTH TOO SHORT FOR THE VMCG TABLE", M.limit("SLUSH", 3, 2, 0, 350000, 9000, 0, 20))
-- p.40 POOR no reverse: only the S.L. column printed
T.check(near(M.vmcg_weight("SLIPPERY", "POOR", 0, 0, 14600, 0, 20), 239000), "p.40 POOR S.L. 14,600 ft 239 t")
off("p.40 POOR 2,000 ft", "NO VMCG LIMIT WEIGHT AT 4000 FT", M.limit("SLIPPERY", "POOR", 0, 0, 300000, 14600, 2000, 20))
-- the V1 tables: p.36 280-400 t, p.39 240-400 t
off("V1 270 t slush", "WEIGHT OFF THE V1 TABLE (280-400 T)", M.v1("SLUSH", 6, 2, 0, 270000, 150, 120, false, 0, 20))
off("V1 410 t", "WEIGHT OFF THE V1 TABLE (240-400 T)", M.v1("SLIPPERY", "GOOD", 2, 0, 410000, 150, 120, false, 0, 20))
-- VMCG limited needs no table: V1 = VMCG at 270 t too
T.equal(M.v1("SLUSH", 6, 2, 0, 270000, 150, 120, true, 0, 20), 120, "V1 270 t VMCG limited: VMCG")
off("no VMCG", "NO VMCG", M.v1("SLUSH", 6, 2, 0, 300000, 150, nil, false, 0, 20))
-- the edges themselves are on the tables: 3 and 13 mm, 8000 ft, 20 %
T.check(M.limit("SLUSH", 13, 2, 20, 350000, 13000, 8000, 20) ~= nil, "13 mm, 8000 ft, 20 %: on the tables")
T.check(M.limit("slush", 3, 2, 0, 350000, 12600, 0, nil) ~= nil, "3 mm, lower case, flaps nil (20)")

T.done()
