-- Run from the repository root with LuaJIT: luajit tests/fms/to_trim_model_test.lua
-- The FMC's takeoff stabilizer trim (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.to_trim_model.lua; 2026-11-24, review FCTL-4 =
-- PERF-4, notes/ATA-34-61-FMC.md §179): the FPPM's Stab Trim Setting
-- tables by the takeoff's rating (747-400F/PW4056: TO p.44 (1.2.20), TO1
-- p.57 (1.3.11), TO2 p.69 (1.3.23)), every printed cell, linear between
-- them, the edge's value outside the table and in its blank cells
-- (estimate).
local T = dofile("tests/lib/check.lua")("to_trim_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.to_trim_model.lua")

-- the tables as printed (units; nil: blank), rows 400 down to 200 t as on
-- the pages, columns CG 9 to 33 % MAC
local PRINTED = {
    [0] = {
        {9.5, 9, 8, 7, 6, 5, 4}, {9.5, 8, 8, 7, 5.5, 5, 3.5}, {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5}, {9.5, 8.5, 7.5, 6.5, 5.5, 4, 3}, {9, 8, 7, 6, 5, 4, 3},
        {8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5}, {8, 7, 6, 5, 4, 3, 2}, {nil, 6, 5, 4.5, 3.5, 2.5, 2},
        {nil, 5, 4, 3.5, 3, 2, 2}, {nil, 4, 3.5, 3, 2.5, 2, 2},
    },
    [1] = {
        {9.5, 9, 8, 7, 6, 5, 4}, {9.5, 9, 8, 7, 5.5, 5, 3.5}, {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5}, {9.5, 8.5, 7.5, 6.5, 5.5, 4, 3}, {9, 8, 7, 6, 5, 4, 3},
        {8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5}, {8, 7, 6, 5, 4, 3, 2}, {nil, 6, 5, 4.5, 3.5, 2.5, 2},
        {nil, 5, 4, 3.5, 3, 2, 2}, {nil, 4, 3.5, 3, 2.5, 2, 2},
    },
    [2] = {
        {9.5, 9.5, 8.5, 7.5, 6, 5, 4}, {9.5, 9, 8, 7, 6, 5, 4}, {9.5, 9, 8, 7, 6, 5, 4},
        {9.5, 9, 8, 7, 6, 5, 4}, {9.5, 9, 7.5, 6.5, 5.5, 4.5, 3.5}, {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9, 8, 7, 6, 5, 4, 3}, {8.5, 7.5, 6.5, 6, 5, 4, 3}, {nil, 7, 6, 5.5, 4.5, 3.5, 3},
        {nil, 6.5, 6, 5, 4, 3, 2.5}, {nil, 6, 5, 4.5, 3.5, 3, 2},
    },
}
local CG = {9, 13, 17, 21, 25, 29, 33}
local NAME = {[0] = "TO (p.44)", "TO1 (p.57)", "TO2 (p.69)"}
for r = 0, 2 do
    local cells, bad = 0, {}
    for i, row in ipairs(PRINTED[r]) do
        local t = 400 - 20 * (i - 1)
        for j = 1, 7 do
            if row[j] then
                cells = cells + 1
                local v = M.trim(r, t, CG[j])
                if math.abs(v - row[j]) > 1e-9 then bad[#bad + 1] = string.format("%d t %d %%: %.2f (%.1f)", t, CG[j], v, row[j]) end
            end
        end
    end
    T.check(cells == 74 and #bad == 0, NAME[r] .. ": its 74 cells as printed: " .. table.concat(bad, ", "))
end
T.equal(M.trim(0, 380, 13), 8, "TO 380 t 13 %: p.44's 8 as printed")
T.equal(M.trim(1, 380, 13), 9, "TO1 380 t 13 %: p.57's 9")
-- linear between the rows and the columns
T.near(M.trim(0, 290, 19), (6.5 + 5.5 + 7 + 6) / 4, 1e-9, "TO 290 t 19 %: the four cells' mean")
T.near(M.trim(2, 230, 15), (6.5 + 6 + 7 + 6) / 4, 1e-9, "TO2 230 t 15 %")
T.near(M.trim(0, 340, 20), 6.75, 1e-9, "TO 340 t 20 %: 6.75")
-- the review's case (FCTL-4): 220 t, 17 %, TO 2: the table's 6 (the old curve 4.4)
T.equal(M.trim(2, 220, 17), 6, "TO2 220 t 17 %: 6")
-- blank cells: the row from its first value (estimate)
T.equal(M.trim(0, 220, 9), 5, "TO 220 t 9 % (blank): the row's 13 % value, 5")
T.near(M.trim(0, 250, 9), (6 + 8) / 2, 1e-9, "TO 250 t 9 %: between 240's 6 (its 13 %) and 260's 8")
T.near(M.trim(0, 200, 11), 4, 1e-9, "TO 200 t 11 %: 4")
-- outside the table: the edge's value (estimate)
T.near(M.trim(0, 180, 21), 3, 1e-9, "180 t: the 200 t row")
T.near(M.trim(0, 420, 21), 7, 1e-9, "420 t: the 400 t row")
T.equal(M.trim(0, 300, 0), 9, "CG 0 %: the 9 % column")
T.equal(M.trim(0, 300, 40), 3, "CG 40 %: the 33 % column")
T.check(M.trim(0, 150, 40) == 2 and M.trim(2, 450, 0) == 9.5, "the corners: 2 and 9.5")
-- other ratings TO's; numbers only
T.equal(M.trim(nil, 300, 21), 6, "no rating: TO's")
T.equal(M.trim(0, "300", "21"), 6, "numbers as text")
T.check(M.trim(0, nil, 21) == nil and M.trim(0, 300, "--") == nil, "no weight or CG: nil")
-- the range: always within the tables' 2 to 9.5 (in the green band range,
-- FCOM p.1320: the trim shown)
local lo, hi = 99, -99
for r = 0, 2 do
    for t = 150, 450, 5 do
        for cg = 0, 40 do
            local v = M.trim(r, t, cg)
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
    end
end
T.check(lo == 2 and hi == 9.5, string.format("0 to 40 %% and 150 to 450 t: %.2f to %.2f", lo, hi))
T.done()
