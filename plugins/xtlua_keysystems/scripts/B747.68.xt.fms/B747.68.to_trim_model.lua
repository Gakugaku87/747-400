-- 747-400 takeoff stabilizer trim without X-Plane (2026-11-24, review
-- FCTL-4 = PERF-4; docs/overhaul/notes/ATA-34-61-FMC.md §179): TAKEOFF
-- REF's TRIM (FCOM p.1320 (11.40.44): the FMC's from the CG, in 0.1 unit
-- steps) from the FPPM's Stab Trim Setting tables for the takeoff's rating
-- (747-400F/PW4056: TO p.44 (1.2.20), TO1 8 % p.57 (1.3.11), TO2 20 %
-- p.69 (1.3.23)), read from the pages' figures (_ref/text/img/FPPM);
-- ATA27 p.514: the MAWEA's band from the CG, the weight and the thrust
-- rating. Between the table's rows and columns linear; outside the
-- table's weights (200 to 400 t) and CGs (9 to 33 % MAC) and in its blank
-- cells (9 % at 200 to 240 t: each row's CGs from its first value) the
-- edge's value (estimate: the tables stop there). GE, RR and the
-- passenger airplanes take the P&W freighter's tables, a GE's TO 1 (5 %)
-- and TO 2 (15 %) the TO1's and TO2's (estimate). Before, one curve for
-- every rating (rms 0.31 units from the TO table, 1.07 at 200 t and 33 %,
-- 0.8 to 1.8 units nose down from the TO2 table at light weights).
--
--   local M = B747_to_trim_model
--   local units = M.trim(rating, t, cg)   -- rating 0 TO, 1 TO 1, 2 TO 2; t 1000 kg; cg % MAC

local M = setmetatable({}, {})
B747_to_trim_model = M

M.CG = {9, 13, 17, 21, 25, 29, 33}
M.W = {200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400}
-- units by rating, a row a weight (M.W's order), a column a CG (M.CG's);
-- false: blank in the table
M.TABLE = {
    [0] = {                                             -- TO (FPPM p.44)
        {false, 4, 3.5, 3, 2.5, 2, 2},                  -- 200
        {false, 5, 4, 3.5, 3, 2, 2},                    -- 220
        {false, 6, 5, 4.5, 3.5, 2.5, 2},                -- 240
        {8, 7, 6, 5, 4, 3, 2},                          -- 260
        {8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5},            -- 280
        {9, 8, 7, 6, 5, 4, 3},                          -- 300
        {9.5, 8.5, 7.5, 6.5, 5.5, 4, 3},                -- 320
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},            -- 340
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},            -- 360
        {9.5, 8, 8, 7, 5.5, 5, 3.5},                    -- 380 (13 %: 8 as printed; TO1's 9)
        {9.5, 9, 8, 7, 6, 5, 4},                        -- 400
    },
    [1] = {                                             -- TO1, 8 % (FPPM p.57)
        {false, 4, 3.5, 3, 2.5, 2, 2},
        {false, 5, 4, 3.5, 3, 2, 2},
        {false, 6, 5, 4.5, 3.5, 2.5, 2},
        {8, 7, 6, 5, 4, 3, 2},
        {8.5, 7.5, 6.5, 5.5, 4.5, 3.5, 2.5},
        {9, 8, 7, 6, 5, 4, 3},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4, 3},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 9, 8, 7, 5.5, 5, 3.5},
        {9.5, 9, 8, 7, 6, 5, 4},
    },
    [2] = {                                             -- TO2, 20 % (FPPM p.69)
        {false, 6, 5, 4.5, 3.5, 3, 2},
        {false, 6.5, 6, 5, 4, 3, 2.5},
        {false, 7, 6, 5.5, 4.5, 3.5, 3},
        {8.5, 7.5, 6.5, 6, 5, 4, 3},
        {9, 8, 7, 6, 5, 4, 3},
        {9.5, 8.5, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 9, 7.5, 6.5, 5.5, 4.5, 3.5},
        {9.5, 9, 8, 7, 6, 5, 4},
        {9.5, 9, 8, 7, 6, 5, 4},
        {9.5, 9, 8, 7, 6, 5, 4},
        {9.5, 9.5, 8.5, 7.5, 6, 5, 4},
    },
}

-- a row's value at cg: linear between its columns, its first and last
-- values outside them
local function row_at(row, cg)
    local CG = M.CG
    local first = 1
    while row[first] == false do first = first + 1 end
    if cg <= CG[first] then return row[first] end
    for i = first, #CG - 1 do
        if cg <= CG[i + 1] then
            local f = (cg - CG[i]) / (CG[i + 1] - CG[i])
            return row[i] + f * (row[i + 1] - row[i])
        end
    end
    return row[#CG]
end

-- the trim (units) for the rating (0 TO, 1 TO 1, 2 TO 2: others TO), the
-- weight t (1000 kg) and the CG (% MAC); nil without both numbers
function M.trim(rating, t, cg)
    t, cg = tonumber(t), tonumber(cg)
    if t == nil or cg == nil then return nil end
    local tab = M.TABLE[rating] or M.TABLE[0]
    local W = M.W
    if t <= W[1] then return row_at(tab[1], cg) end
    for i = 1, #W - 1 do
        if t <= W[i + 1] then
            local a, b = row_at(tab[i], cg), row_at(tab[i + 1], cg)
            return a + (t - W[i]) / (W[i + 1] - W[i]) * (b - a)
        end
    end
    return row_at(tab[#W], cg)
end

return M
