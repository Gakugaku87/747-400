-- Run from the repository root with LuaJIT: luajit tests/fms/efb_ldg_model_test.lua
-- The EFB's landing performance (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.efb_ldg_model.lua; 2026-11-25, FCOM p.1183
-- (10.45.25)): the FCOM's Normal Configuration Landing Distance tables
-- (747-400/PW4056 FCOM p.275-276 (PI.12.1-2), 747-400F/CF6-80C2B1F FCOM
-- p.371-372 (PI.22.1-2)), the FPPM's (747-400F/PW4056) Landing Field &
-- Climb Limit charts (FPPM p.71-74 (1.4.1-4)) and Quick Turnaround Limit
-- (FPPM p.76 (1.4.6)).
local T = dofile("tests/lib/check.lua")("efb_ldg_model")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vref_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.efb_ldg_model.lua")
local V = B747_vref_model
local FT, LB = 0.3048, 0.45359237
local abs = math.abs

T.check(getmetatable(L) ~= nil and B747_efb_ldg_model == L, "the module: a table with a metatable in its global")

------------------------------------------------------------------------
-- the tables as printed (read off the page images, _ref/text/img/FCOM),
-- a row as on the page: REF, WT ADJ above/below, ALT, HEAD, TAIL, DOWN,
-- UP, ABV ISA, BLW ISA, APP SPD, 2 REV, NO REV
------------------------------------------------------------------------
local PRINTED = {
    [0] = {   -- 747-400/PW4056, m and kg
        [30] = {   -- FCOM p.275 (PI.12.1)
            DRY = {
                "MAX MANUAL 1055 20/-15 30 -55 180 15 -15 30 -30 115 25 55",
                "MAX AUTO 1270 20/-20 40 -65 215 0 0 35 -35 150 0 0",
                "4 1555 30/-30 50 -85 280 0 0 45 -45 190 0 0",
                "3 1825 35/-35 60 -100 340 10 -15 55 -55 210 5 10",
                "2 2055 40/-40 70 -115 395 30 -40 70 -65 190 30 35",
                "1 2275 45/-45 80 -135 460 60 -70 80 -70 190 145 210",
            },
            GOOD = {
                "MAX MANUAL 1600 30/-30 50 -85 310 45 -40 50 -45 165 85 195",
                "MAX AUTO 1655 30/-30 50 -90 315 35 -30 50 -45 180 85 200",
                "4 1800 35/-35 55 -100 335 10 -5 50 -50 220 10 70",
                "3 2100 40/-40 70 -115 390 15 -15 65 -65 240 5 10",
            },
            MEDIUM = {
                "MAX MANUAL 2145 40/-40 75 -130 490 105 -85 75 -65 190 220 530",
                "MAX AUTO 2145 40/-40 75 -130 490 105 -75 75 -65 215 215 520",
                "4 2145 45/-40 75 -130 490 105 -75 75 -65 205 220 535",
                "3 2265 45/-45 75 -140 500 85 -55 75 -70 240 150 455",
            },
            POOR = {
                "MAX MANUAL 2770 60/-60 100 -195 780 275 -165 105 -80 215 460 1210",
                "MAX AUTO 2770 60/-60 100 -195 775 275 -160 105 -80 220 465 1225",
                "4 2770 60/-60 100 -195 775 275 -160 105 -80 220 460 1220",
                "3 2770 60/-60 100 -195 785 275 -150 105 -80 240 465 1230",
            },
        },
        [25] = {   -- FCOM p.276 (PI.12.2)
            DRY = {
                "MAX MANUAL 1120 30/-20 35 -55 185 20 -15 30 -30 115 30 60",
                "MAX AUTO 1360 25/-25 40 -65 220 0 0 40 -40 155 0 0",
                "4 1670 30/-30 55 -85 290 0 0 50 -50 200 0 0",
                "3 1985 40/-40 65 -105 350 5 -15 60 -60 225 5 10",
                "2 2250 45/-45 75 -120 410 20 -45 75 -70 210 25 25",
                "1 2495 50/-50 90 -140 480 65 -75 90 -75 210 180 220",
            },
            GOOD = {
                "MAX MANUAL 1695 35/-30 55 -90 315 45 -40 50 -45 165 105 230",
                "MAX AUTO 1750 35/-35 55 -90 320 40 -35 55 -50 180 105 235",
                "4 1930 35/-35 65 -105 345 10 -5 55 -60 230 10 75",
                "3 2285 45/-45 75 -120 405 5 -15 70 -70 260 5 10",
            },
            MEDIUM = {
                "MAX MANUAL 2305 45/-45 80 -140 500 120 -90 80 -70 200 265 655",
                "MAX AUTO 2305 45/-45 80 -140 500 115 -80 80 -70 220 255 645",
                "4 2305 45/-45 80 -140 500 110 -75 80 -70 220 265 650",
                "3 2450 45/-45 80 -145 520 80 -55 80 -75 260 175 565",
            },
            POOR = {
                "MAX MANUAL 2995 65/-65 110 -200 805 295 -185 115 -85 225 560 1530",
                "MAX AUTO 2995 65/-55 110 -200 800 300 -170 115 -85 225 565 1545",
                "4 2995 65/-55 110 -200 800 295 -170 115 -85 230 565 1545",
                "3 2995 65/-55 110 -200 805 285 -155 115 -85 255 570 1560",
            },
        },
    },
    [1] = {   -- 747-400F/CF6-80C2B1F, ft and lb
        [30] = {   -- FCOM p.371 (PI.22.1)
            DRY = {
                "MAX MANUAL 3310 60/-50 100 -170 580 50 -50 90 -90 360 110 250",
                "MAX AUTO 4160 70/-70 120 -210 700 0 -10 120 -120 470 0 0",
                "4 5090 90/-90 160 -270 920 0 -20 150 -150 600 0 0",
                "3 5900 100/-100 200 -320 1100 60 -90 190 -180 580 70 100",
                "2 6430 120/-120 220 -370 1250 140 -150 220 -200 570 380 410",
                "1 6950 140/-140 260 -420 1440 220 -230 250 -210 570 760 1190",
            },
            GOOD = {
                "MAX MANUAL 4300 70/-70 140 -240 850 110 -100 130 -120 440 310 720",
                "MAX AUTO 4530 80/-80 150 -250 870 90 -80 140 -130 460 320 750",
                "4 5120 90/-90 160 -280 960 20 -30 150 -150 600 30 200",
                "3 5900 100/-100 200 -320 1100 70 -90 190 -180 580 70 100",
            },
            MEDIUM = {
                "MAX MANUAL 5650 100/-100 190 -360 1340 270 -210 180 -160 500 730 1880",
                "MAX AUTO 5690 110/-100 200 -360 1340 250 -190 190 -160 540 710 1840",
                "4 5760 110/-100 200 -360 1350 210 -150 190 -170 600 670 1830",
                "3 6250 110/-110 210 -380 1410 200 -170 200 -180 580 420 1490",
            },
            POOR = {
                "MAX MANUAL 7170 130/-130 250 -530 2180 730 -400 240 -190 550 1400 4040",
                "MAX AUTO 7170 140/-130 250 -520 2180 720 -390 240 -190 560 1400 4100",
                "4 7170 140/-130 250 -520 2180 720 -390 240 -190 560 1400 4090",
                "3 7310 140/-130 260 -530 2200 700 -380 250 -190 580 1300 4030",
            },
        },
        [25] = {   -- FCOM p.372 (PI.22.2)
            DRY = {
                "MAX MANUAL 3480 80/-50 100 -170 590 50 -50 100 -90 360 130 280",
                "MAX AUTO 4450 70/-70 130 -220 720 0 -10 130 -130 500 0 0",
                "4 5460 90/-90 180 -280 950 0 -10 170 -170 640 0 0",
                "3 6410 110/-110 220 -340 1150 40 -100 210 -200 630 80 110",
                "2 7000 130/-130 250 -380 1310 140 -170 240 -210 610 420 440",
                "1 7550 150/-150 290 -430 1500 240 -260 280 -230 610 960 1320",
            },
            GOOD = {
                "MAX MANUAL 4560 80/-80 150 -250 870 120 -100 140 -130 440 360 850",
                "MAX AUTO 4780 80/-80 160 -250 890 90 -70 150 -130 490 360 870",
                "4 5490 90/-90 180 -290 990 20 -20 170 -170 640 20 210",
                "3 6410 110/-110 220 -340 1150 50 -100 210 -200 630 80 110",
            },
            MEDIUM = {
                "MAX MANUAL 6030 110/-110 210 -370 1370 280 -220 200 -170 520 860 2290",
                "MAX AUTO 6030 110/-110 210 -370 1370 270 -190 200 -170 570 830 2240",
                "4 6130 110/-110 210 -370 1380 220 -140 200 -180 650 770 2190",
                "3 6750 120/-120 230 -400 1460 180 -170 220 -200 630 460 1810",
            },
            POOR = {
                "MAX MANUAL 7690 150/-140 270 -540 2250 770 -420 260 -200 580 1670 5060",
                "MAX AUTO 7690 150/-140 280 -540 2240 770 -410 260 -200 600 1680 5130",
                "4 7690 150/-140 280 -540 2240 760 -410 260 -200 590 1670 5120",
                "3 7850 150/-140 280 -550 2270 720 -390 270 -210 630 1550 5040",
            },
        },
    },
}
local CONDS = {"DRY", "GOOD", "MEDIUM", "POOR"}
local function parse_row(s)
    local name, rest = s:match("^(MAX %u+) (.*)$")
    if not name then name, rest = s:match("^(%d) (.*)$") end
    local v = {}
    for tok in rest:gmatch("%S+") do
        local a, b = tok:match("^(%-?%d+)/(%-?%d+)$")
        if a then v[#v + 1] = tonumber(a); v[#v + 1] = tonumber(b) else v[#v + 1] = tonumber(tok) end
    end
    return name, v
end

-- the data block holds the printed tables
for _, e in ipairs({0, 1}) do
    for _, flaps in ipairs({30, 25}) do
        for _, c in ipairs(CONDS) do
            local rows, n = PRINTED[e][flaps][c], 0
            for _, s in ipairs(rows) do
                local name, v = parse_row(s)
                local got = L.DIST[e][flaps][c][name]
                local same = got and #got == 13
                for i = 1, 13 do same = same and got[i] == v[i] end
                T.check(same, string.format("data: engine %d flaps %d %s %s as printed", e, flaps, c, name))
            end
            for _ in pairs(L.DIST[e][flaps][c]) do n = n + 1 end
            T.equal(n, #rows, string.format("data: engine %d flaps %d %s: no extra rows", e, flaps, c))
        end
    end
end
-- the pages' notes
T.equal(L.DIST[0].factor, 1.15, "PW4056: the slippery rows factored by 1.15 (FCOM p.275)")
T.equal(L.DIST[1].factor, 1, "CF6: actual distances (FCOM p.371)")
T.equal(L.DIST[0].manual_spoilers, 85, "PW4056: manual spoilers add 85 m")
T.equal(L.DIST[1].manual_spoilers, 240, "CF6: manual spoilers add 240 ft")
T.check(L.DIST[0].unit == "M" and L.DIST[0].wt_unit == "KG" and L.DIST[0].ref_wt == 250000 and L.DIST[0].wt_step == 5000,
    "PW4056: m, per 5,000 kg from 250,000 kg")
T.check(L.DIST[1].unit == "FT" and L.DIST[1].wt_unit == "LB" and L.DIST[1].ref_wt == 550000 and L.DIST[1].wt_step == 10000,
    "CF6: ft, per 10,000 lb from 550,000 lb")

------------------------------------------------------------------------
-- every printed reference distance and adjustment through distance():
-- the second value (the table's figure) in the table's unit
------------------------------------------------------------------------
local function fig(e, ...)
    local actual, figure = L.distance(e, ...)
    if not figure then return nil end
    return e == 1 and figure / FT or figure
end
local isa = L.isa_c
for _, e in ipairs({0, 1}) do
    local ref_kg = e == 1 and 550000 * LB or 250000
    local step_kg = e == 1 and 10000 * LB or 5000
    for _, flaps in ipairs({30, 25}) do
        for _, c in ipairs(CONDS) do
            for _, s in ipairs(PRINTED[e][flaps][c]) do
                local name, v = parse_row(s)
                local bad = {}
                local function at(what, want, ...)
                    local got = fig(e, flaps, c, name, ...)
                    if not got or abs(got - want) > 1e-6 then
                        bad[#bad + 1] = string.format("%s %s (%s)", what, tostring(got), tostring(want))
                    end
                end
                -- the reference: sea level, ISA, no wind or slope, VREF, four reversers
                at("ref", v[1], ref_kg, 0, 15, 0, 0, 0, 4)
                at("above", v[1] + v[2], ref_kg + step_kg, 0, 15, 0, 0, 0, 4)
                at("below", v[1] + v[3], ref_kg - step_kg, 0, 15, 0, 0, 0, 4)
                at("alt", v[1] + v[4], ref_kg, 1000, isa(1000), 0, 0, 0, 4)
                at("head", v[1] + v[5], ref_kg, 0, 15, 10, 0, 0, 4)
                at("tail", v[1] + v[6], ref_kg, 0, 15, -10, 0, 0, 4)
                at("down", v[1] + v[7], ref_kg, 0, 15, 0, -1, 0, 4)
                at("up", v[1] + v[8], ref_kg, 0, 15, 0, 1, 0, 4)
                at("abv isa", v[1] + v[9], ref_kg, 0, 25, 0, 0, 0, 4)
                at("blw isa", v[1] + v[10], ref_kg, 0, 5, 0, 0, 0, 4)
                at("app", v[1] + v[11], ref_kg, 0, 15, 0, 0, 10, 4)
                at("2 rev", v[1] + v[12], ref_kg, 0, 15, 0, 0, 0, 2)
                at("no rev", v[1] + v[13], ref_kg, 0, 15, 0, 0, 0, 0)
                T.check(#bad == 0, string.format("engine %d flaps %d %s %s: %s", e, flaps, c, name, table.concat(bad, ", ")))
            end
        end
    end
end
-- the actual distance: the PW4056's slippery figures / 1.15, the rest as the figure
do
    local a, f = L.distance(0, 30, "GOOD", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    T.near(f, 1600, 1e-9, "PW4056 flaps 30 GOOD MAX MANUAL: the table's 1600 m")
    T.near(a, 1600 / 1.15, 1e-9, "... actual 1600 / 1.15 = 1391.3 m")
    a, f = L.distance(0, 30, "DRY", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    T.check(a == f and a == 1055, "PW4056 DRY: actual = figure = 1055 m")
    a, f = L.distance(1, 30, "POOR", "3", 550000 * LB, 0, 15, 0, 0, 0, 4)
    T.near(a, 7310 * FT, 1e-9, "CF6 POOR autobrakes 3: actual 7310 ft = 2228.1 m")
    T.check(a == f, "CF6: actual = figure")
    -- WET as GOOD
    T.equal(L.distance(0, 30, "WET", "MAX AUTO", 250000, 0, 15, 0, 0, 0, 4), L.distance(0, 30, "GOOD", "MAX AUTO", 250000, 0, 15, 0, 0, 0, 4),
        "WET is the GOOD table")
    -- manual spoilers: MAX MANUAL only
    _, f = L.distance(0, 30, "DRY", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4, true)
    T.equal(f, 1055 + 85, "PW4056 MAX MANUAL, manual spoilers: + 85 m")
    _, f = L.distance(1, 25, "DRY", "MAX MANUAL", 550000 * LB, 0, 15, 0, 0, 0, 4, true)
    T.near(f / FT, 3480 + 240, 1e-6, "CF6 MAX MANUAL, manual spoilers: + 240 ft")
    _, f = L.distance(0, 30, "DRY", "MAX AUTO", 250000, 0, 15, 0, 0, 0, 4, true)
    T.equal(f, 1270, "autobrakes: no spoiler addition")
    -- odd reverser counts: the symmetric pair only (estimate)
    T.equal(fig(0, 30, "DRY", "1", 250000, 0, 15, 0, 0, 0, 3), 2275 + 145, "3 reversers as 2")
    T.equal(fig(0, 30, "DRY", "1", 250000, 0, 15, 0, 0, 0, 1), 2275 + 210, "1 reverser as none")
    T.equal(fig(0, 30, "DRY", "1", 250000, 0, 15, 0, 0, 0, nil), 2275, "nil reversers: four")
    -- below sea level no altitude adjustment (estimate)
    T.equal(fig(0, 30, "DRY", "3", 250000, -1000, isa(-1000), 0, 0, 0, 4), 1825, "below sea level: no ALT ADJ")
    -- the braking names
    T.equal(fig(0, 30, "DRY", 3, 250000, 0, 15, 0, 0, 0, 4), 1825, "autobrake 3 as a number")
    T.equal(fig(0, 30, "dry", "AUTOBRAKES 3", 250000, 0, 15, 0, 0, 0, 4), 1825, "AUTOBRAKES 3")
    T.equal(fig(0, 30, "DRY", "AB4", 250000, 0, 15, 0, 0, 0, 4), 1555, "AB4")
end

------------------------------------------------------------------------
-- worked examples by hand
------------------------------------------------------------------------
do
    -- PW4056 flaps 30, MEDIUM, autobrakes 3 (FCOM p.275: 2265 45/-45 75
    -- -140 500 85 -55 75 -70 240 150 455), 270,000 kg, 2,000 ft, 30 C, 10
    -- kt tailwind, 1 % downhill, VREF 30 + 10, two reversers:
    --   weight   (270 - 250) / 5 = 4 steps x 45           = 180
    --   altitude 2 x 75                                   = 150
    --   wind     tail 10 kt: 1 x 500                      = 500
    --   slope    1 % down: 1 x 85                         =  85
    --   temp     ISA at 2,000 ft 15 - 3.9624 = 11.0376 C,
    --            30 C is 18.9624 above: 1.89624 x 75      = 142.218
    --   app      10 kt: 1 x 240                           = 240
    --   reverse  2 REV                                    = 150
    --   2265 + 180 + 150 + 500 + 85 + 142.218 + 240 + 150 = 3712.218 m (the table's, factored by 1.15)
    --   actual 3712.218 / 1.15                            = 3228.016 m
    local a, f = L.distance(0, 30, "MEDIUM", "3", 270000, 2000, 30, -10, -1, 10, 2)
    T.near(f, 3712.218, 0.001, "worked example PW: the table's 3712.218 m")
    T.near(a, 3228.016, 0.001, "worked example PW: actual 3228.016 m")
    -- CF6 flaps 25, DRY, MAX AUTO (FCOM p.372: 4450 70/-70 130 -220 720 0
    -- -10 130 -130 500 0 0), 220,000 kg, 500 ft, 5 C, 15 kt headwind, 0.5 %
    -- uphill, VREF 25 + 5, four reversers:
    --   weight   220,000 kg = 485,017.0 lb: 6.49830 steps of 10,000 lb below
    --            550,000 x -70                            = -454.881
    --   altitude 0.5 x 130                                =   65
    --   wind     head 15 kt: 1.5 x -220                   = -330
    --   slope    0.5 % up: 0.5 x -10                      =   -5
    --   temp     ISA at 500 ft 14.0094 C, 5 C is 9.0094 below: 0.90094 x -130 = -117.122
    --   app      5 kt: 0.5 x 500                          =  250
    --   4450 - 454.881 + 65 - 330 - 5 - 117.122 + 250     = 3857.997 ft = 1175.917 m
    a, f = L.distance(1, 25, "DRY", "MAX AUTO", 220000, 500, 5, 15, 0.5, 5, 4)
    T.near(f / FT, 3857.997, 0.002, "worked example CF6: 3857.997 ft")
    T.near(a, 1175.917, 0.001, "worked example CF6: 1175.917 m")
    -- the parts
    local d, p = L.table_distance(L.DIST[0], 30, "MEDIUM", "3", 270000, 2000, 30, -10, -1, 10, 2)
    T.check(p.wt == 180 and p.alt == 150 and p.wind == 500 and p.slope == 85 and abs(p.temp - 142.218) < 0.001
        and p.app == 240 and p.rev == 150, "worked example PW: the parts")
end

------------------------------------------------------------------------
-- monotonicity
------------------------------------------------------------------------
do
    local bad = {}
    local function more(what, a, b)   -- a strictly longer than b
        if not (a and b and a > b) then bad[#bad + 1] = what .. string.format(" %s %s", tostring(a), tostring(b)) end
    end
    local function atleast(what, a, b)
        if not (a and b and a >= b - 1e-9) then bad[#bad + 1] = what .. string.format(" %s %s", tostring(a), tostring(b)) end
    end
    for _, e in ipairs({0, 1, 2}) do
        for _, flaps in ipairs({30, 25}) do
            for _, c in ipairs(CONDS) do
                for _, s in ipairs(PRINTED[e == 1 and 1 or 0][flaps][c]) do
                    local name = parse_row(s)
                    local function d(w, pa, oat, wind, slope, add, rev)
                        return (L.distance(e, flaps, c, name, w, pa, oat, wind, slope, add, rev))
                    end
                    local tag = string.format("%d/%d/%s/%s: ", e, flaps, c, name)
                    local base = d(260000, 1000, 15, 0, 0, 5, 4)
                    more(tag .. "heavier", d(280000, 1000, 15, 0, 0, 5, 4), base)
                    more(tag .. "lighter", base, d(220000, 1000, 15, 0, 0, 5, 4))
                    more(tag .. "higher", d(260000, 5000, 15, 0, 0, 5, 4), base)
                    more(tag .. "hotter", d(260000, 1000, 35, 0, 0, 5, 4), base)
                    more(tag .. "colder", base, d(260000, 1000, -10, 0, 0, 5, 4))
                    more(tag .. "tailwind", d(260000, 1000, 15, -10, 0, 5, 4), base)
                    more(tag .. "headwind", base, d(260000, 1000, 15, 20, 0, 5, 4))
                    atleast(tag .. "downhill", d(260000, 1000, 15, 0, -1, 5, 4), base)
                    atleast(tag .. "uphill", base, d(260000, 1000, 15, 0, 1, 5, 4))
                    more(tag .. "faster", d(260000, 1000, 15, 0, 0, 15, 4), base)
                    atleast(tag .. "two reversers", d(260000, 1000, 15, 0, 0, 5, 2), base)
                    atleast(tag .. "no reversers", d(260000, 1000, 15, 0, 0, 5, 0), d(260000, 1000, 15, 0, 0, 5, 2))
                end
                -- less braking longer: MAX MANUAL, MAX AUTO, 4, 3 (, 2, 1); on the
                -- slippery runways MAX MANUAL, MAX AUTO and 4 share the friction-
                -- limited reference and their adjustments differ by up to 10 per
                -- column (PW4056 MEDIUM MAX AUTO app 215, autobrakes 4 205): the
                -- order there within 10 m
                local order = c == "DRY" and {"MAX MANUAL", "MAX AUTO", "4", "3", "2", "1"} or {"MAX MANUAL", "MAX AUTO", "4", "3"}
                local tol = c == "DRY" and 0 or 10
                for _, cond_set in ipairs({{250000, 0, 15, 0, 0, 0, 4}, {280000, 2000, 25, 10, 0.5, 5, 4}, {220000, 0, 0, 0, -1, 10, 2}}) do
                    for i = 2, #order do
                        local a = L.distance(e, flaps, c, order[i], unpack(cond_set))
                        local b = L.distance(e, flaps, c, order[i - 1], unpack(cond_set))
                        atleast(string.format("%d/%d/%s: %s longer than %s", e, flaps, c, order[i], order[i - 1]), a and a + tol, b)
                    end
                end
            end
            -- a worse runway longer (actual distances): MAX MANUAL and MAX AUTO
            -- strictly; autobrakes 4 and 3 at least about as long (the good
            -- runway's autobrake 3 is the dry one's within 0.1 %)
            for _, name in ipairs({"MAX MANUAL", "MAX AUTO", "4", "3"}) do
                for i = 2, 4 do
                    local a = L.distance(e, flaps, CONDS[i], name, 250000, 0, 15, 0, 0, 0, 4)
                    local b = L.distance(e, flaps, CONDS[i - 1], name, 250000, 0, 15, 0, 0, 0, 4)
                    if name == "MAX MANUAL" or name == "MAX AUTO" or i > 2 then
                        more(string.format("%d/%d %s: %s longer than %s", e, flaps, name, CONDS[i], CONDS[i - 1]), a, b)
                    else
                        atleast(string.format("%d/%d %s: %s about as long as %s", e, flaps, name, CONDS[i], CONDS[i - 1]), a, b * 0.999)
                    end
                end
            end
        end
    end
    T.check(#bad == 0, "distance monotonic: " .. table.concat(bad, "; "))
    -- flaps 25 longer than flaps 30 at the same weight (the reference rows)
    local b2 = {}
    for _, e in ipairs({0, 1}) do
        for _, c in ipairs(CONDS) do
            for _, s in ipairs(PRINTED[e][30][c]) do
                local name = parse_row(s)
                local a30 = L.distance(e, 30, c, name, 250000, 0, 15, 0, 0, 0, 4)
                local a25 = L.distance(e, 25, c, name, 250000, 0, 15, 0, 0, 0, 4)
                if not (a25 >= a30) then b2[#b2 + 1] = string.format("%d %s %s", e, c, name) end
            end
        end
    end
    T.check(#b2 == 0, "flaps 25 at least as long as flaps 30: " .. table.concat(b2, ", "))
end

------------------------------------------------------------------------
-- nil outside
------------------------------------------------------------------------
do
    local function none(what, ...)
        local a, why = L.distance(...)
        T.check(a == nil and type(why) == "string", what .. ": nil and a reason, got " .. tostring(a))
    end
    none("engine 3", 3, 30, "DRY", "3", 250000, 0, 15, 0, 0, 0, 4)
    none("flaps 20", 0, 20, "DRY", "3", 250000, 0, 15, 0, 0, 0, 4)
    none("runway SLUSH", 0, 30, "SLUSH", "3", 250000, 0, 15, 0, 0, 0, 4)
    none("braking RTO", 0, 30, "DRY", "RTO", 250000, 0, 15, 0, 0, 0, 4)
    none("GOOD autobrakes 2 (not in the table)", 0, 30, "GOOD", "2", 250000, 0, 15, 0, 0, 0, 4)
    none("POOR autobrakes 1", 1, 25, "POOR", "1", 250000, 0, 15, 0, 0, 0, 4)
    none("weight 140 t", 0, 30, "DRY", "3", 140000, 0, 15, 0, 0, 0, 4)
    none("weight 410 t", 0, 30, "DRY", "3", 410000, 0, 15, 0, 0, 0, 4)
    none("10,500 ft", 0, 30, "DRY", "3", 250000, 10500, 15, 0, 0, 0, 4)
    none("-2,500 ft", 0, 30, "DRY", "3", 250000, -2500, 15, 0, 0, 0, 4)
    none("slope 2.5 %", 0, 30, "DRY", "3", 250000, 0, 15, 0, 2.5, 0, 4)
    none("slope -2.5 %", 0, 30, "DRY", "3", 250000, 0, 15, 0, -2.5, 0, 4)
    none("PW tailwind 16 kt", 0, 30, "DRY", "3", 250000, 0, 15, -16, 0, 0, 4)
    none("GE tailwind 11 kt", 1, 30, "DRY", "3", 250000, 0, 15, -11, 0, 0, 4)
    none("below VREF", 0, 30, "DRY", "3", 250000, 0, 15, 0, 0, -1, 4)
    none("5 reversers", 0, 30, "DRY", "3", 250000, 0, 15, 0, 0, 0, 5)
    T.check(L.distance(0, 30, "DRY", "3", 250000, 0, 15, -15, 0, 0, 4) ~= nil, "PW tailwind 15 kt: an answer")
    T.check(L.distance(1, 30, "DRY", "3", 250000, 0, 15, -10, 0, 0, 4) ~= nil, "GE tailwind 10 kt: an answer")
    T.check(L.distance(2, 30, "DRY", "3", 250000, 0, 15, -15, 0, 0, 4) ~= nil, "RR tailwind 15 kt: an answer")
end

------------------------------------------------------------------------
-- PW, RR and GE
------------------------------------------------------------------------
do
    local pw = L.distance(0, 30, "DRY", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    local rr = L.distance(2, 30, "DRY", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    local ge = L.distance(1, 30, "DRY", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    T.equal(rr, pw, "RR on the PW4056's tables (estimate)")
    -- GE: 3310 ft at 550,000 lb (249,476 kg) + 0.1156 x 60 ft for the 524 kg more
    T.near(ge, (3310 + (250000 / LB - 550000) / 10000 * 60) * FT, 1e-9, "GE: the CF6 table's 3310 ft (+ 7 ft for 250 t)")
    T.check(pw - ge > 40 and pw - ge < 50, string.format("GE's dry MAX MANUAL %.1f m shorter than the PW's 1055 m", pw - ge))
    -- autobrakes 3 at 200 t, dry, ISA sea level: PW 1825 - 350 = 1475 m; GE
    -- (5900 - 100 x (550000 - 440925) / 10000) ft = 4809.2 ft = 1465.9 m
    T.near(L.distance(0, 30, "DRY", "3", 200000, 0, 15, 0, 0, 0, 4), 1475, 1e-9, "PW autobrakes 3 at 200 t: 1475 m")
    T.near(L.distance(1, 30, "DRY", "3", 200000, 0, 15, 0, 0, 0, 4), (5900 - 100 * (550000 - 200000 / LB) / 10000) * FT, 1e-9,
        "GE autobrakes 3 at 200 t: 4809.2 ft")
    -- slippery: the GE's tables actual, the PW's factored: POOR MAX MANUAL
    -- at the reference PW 2770 / 1.15 = 2408.7 m, GE 7170 ft = 2185.4 m
    local pa, pf = L.distance(0, 30, "POOR", "MAX MANUAL", 250000, 0, 15, 0, 0, 0, 4)
    local ga, gf = L.distance(1, 30, "POOR", "MAX MANUAL", 550000 * LB, 0, 15, 0, 0, 0, 4)
    T.near(pa, 2408.696, 0.001, "PW POOR MAX MANUAL actual 2408.7 m")
    T.near(ga, 2185.416, 0.001, "GE POOR MAX MANUAL actual 2185.4 m")
end

------------------------------------------------------------------------
-- the FCOM's PW4056 (747-400) against the FPPM's (747-400F, FPPM p.78-79)
------------------------------------------------------------------------
do
    local worst_ref, worst_adj, where_ref, where_adj = 0, 0, "", ""
    for _, flaps in ipairs({30, 25}) do
        for _, c in ipairs(CONDS) do
            for name, a in pairs(L.DIST[0][flaps][c]) do
                local p = L.FPPM_DIST[flaps][c][name]
                local fac = c == "DRY" and 1 or 1.15
                for i = 1, 13 do
                    local dd = abs(a[i] / fac - p[i] * FT)
                    if i == 1 and dd > worst_ref then worst_ref, where_ref = dd, flaps .. " " .. c .. " " .. name end
                    if i > 1 and dd > worst_adj then worst_adj, where_adj = dd, flaps .. " " .. c .. " " .. name .. " col " .. i end
                end
            end
        end
    end
    -- the worst: flaps 30 POOR MAX AUTO, FCOM 2770 / 1.15 = 2408.7 m, FPPM 7780 ft = 2371.3 m
    T.check(worst_ref < 40, string.format("FCOM PW4056 / FPPM reference distances within 40 m: %.1f m (%s)", worst_ref, where_ref))
    T.check(worst_adj < 12, string.format("FCOM PW4056 / FPPM adjustments within 12 m: %.1f m (%s)", worst_adj, where_adj))
    -- dry: within the FCOM's 5 m rounding (+ 10 ft)
    local dry = 0
    for name, a in pairs(L.DIST[0][30].DRY) do dry = math.max(dry, abs(a[1] - L.FPPM_DIST[30].DRY[name][1] * FT)) end
    T.check(dry < 6, string.format("flaps 30 dry reference distances FCOM vs FPPM within 6 m: %.1f", dry))
end

------------------------------------------------------------------------
-- the FPPM's charts: the printed examples (the dashed lines, FPPM p.71)
------------------------------------------------------------------------
do
    -- field (flaps 25, anti-skid operative): field length 7,925 ft (2,416
    -- m: the line starts a little right of the 24 x 100 m tick), 20 kt
    -- headwind (to 8,718 ft), two brakes inoperative (8,107 ft), wet (7,052
    -- ft), the 2,000 ft line: 263.9 t (the lines as drawn, read with
    -- pdf_paths.lua). The model's steps within 30 ft of the drawing's, the
    -- weight within 1.5 t (0.6 %; it reads 262.9 t)
    local F = L.FIELD[25]
    local x1 = L.along(F.wind.head_lines, 7925, 20.1 / 40)
    T.near(x1, 8718, 30, "field example: the wind step")
    local x2 = L.along(F.brakes, 8718, 1)
    T.near(x2, 8107, 30, "field example: the brakes step")
    local x3 = L.along(F.wet, 8107, 1)
    T.near(x3, 7052, 30, "field example: the runway step")
    local w = L.field_limit(25, 7925 * FT, 2000, 20.1, "WET", false, true, false)
    T.near(w, 263870, 1500, "field example: 263.9 t")
    -- climb (flaps 25): 33.5 C at 2,000 ft: 417.1 t (the model 417.8)
    T.near(L.climb_limit(25, 33.46, 2000, 3, false), 417090, 1000, "climb example: 417.1 t")
end

------------------------------------------------------------------------
-- the field limit
------------------------------------------------------------------------
do
    local function fl(...) return (L.field_limit(...)) end
    -- along the 0 ft line of flaps 30 (FPPM p.72): dry, calm, normal brakes
    local base = fl(30, 2500, 0, 0, "DRY", false, false, false)
    T.check(base and base > 200000 and base < 400000, "flaps 30, 2,500 m, sea level: on the chart " .. tostring(base))
    T.check(fl(30, 2800, 0, 0, "DRY") > base, "longer runway heavier")
    T.check(fl(30, 2500, 4000, 0, "DRY") < base, "higher lighter")
    T.check(fl(30, 2500, 0, -10, "DRY") < base, "tailwind lighter")
    T.check(fl(30, 2500, 0, 20, "DRY") > base, "headwind heavier")
    T.check(fl(30, 2500, 0, 0, "WET") < base, "wet lighter")
    T.check(fl(30, 2500, 0, 0, "DRY", false, true) < base, "two brakes inoperative lighter")
    T.check(fl(30, 2500, 0, 0, "DRY", false, false, true) < base, "manual spoilers lighter")
    T.check(fl(30, 3500, 0, 0, "DRY", true) < fl(30, 3500, 0, 0, "DRY"), "anti-skid inoperative lighter")
    T.check(fl(25, 2500, 0, 0, "DRY") < base, "flaps 25 lighter than flaps 30 for the same field")
    -- between the altitude lines linear
    local a0, a2 = fl(30, 2500, 0, 0, "DRY"), fl(30, 2500, 2000, 0, "DRY")
    T.near(fl(30, 2500, 1000, 0, "DRY"), (a0 + a2) / 2, 1e-6, "1,000 ft halfway between the 0 and 2,000 ft lines")
    -- the manual spoilers' note: the field length less 440 ft (flaps 30)
    T.near(fl(30, 2500, 0, 0, "DRY", false, false, true), fl(30, 2500 - 440 * FT, 0, 0, "DRY"), 1e-6, "manual spoilers: 440 ft less")
    T.near(fl(25, 4000, 0, 0, "DRY", true, false, true), fl(25, 4000, 0, 0, "DRY", true), 1e-6,
        "flaps 25 anti-skid inoperative: valid for manual spoilers")
    -- nil outside
    local function none(what, ...)
        local w, why = L.field_limit(...)
        T.check(w == nil and type(why) == "string", what .. ": nil and a reason")
    end
    none("field length below 5,000 ft", 30, 1500, 0, 0, "DRY")
    none("anti-skid inoperative below 9,000 ft", 30, 2500, 0, 0, "DRY", true)
    none("anti-skid inoperative with two brakes inoperative", 30, 4000, 0, 0, "DRY", true, true)
    none("pressure altitude 12,000 ft", 30, 3000, 12000, 0, "DRY")
    none("tailwind 16 kt", 30, 3000, 0, -16, "DRY")
    none("a slippery runway", 30, 3000, 0, 0, "POOR")
    none("flaps 20", 20, 3000, 0, 0, "DRY")
    none("too short for 200 t at 10,000 ft", 30, 1600, 10000, 0, "DRY")
    -- a long runway: the chart's 13,000 ft, with a note
    local w, note = L.field_limit(30, 5000, 0, 0, "DRY")
    T.check(w and note, "5,000 m: the chart's longest, with a note")
end

------------------------------------------------------------------------
-- the climb limit
------------------------------------------------------------------------
do
    local c = L.climb_limit
    T.equal(L.CLIMB[25].ice, 21400, "flaps 25 ice 21,400 kg (FPPM p.71)")
    T.equal(L.CLIMB[30].ice, 17100, "flaps 30 ice 17,100 kg (FPPM p.72)")
    T.check(L.CLIMB[25].pack1 == 3900 and L.CLIMB[25].pack0 == 5900, "flaps 25 packs 3,900 / 5,900 kg")
    T.check(L.CLIMB[30].pack1 == 2900 and L.CLIMB[30].pack0 == 4100, "flaps 30 packs 2,900 / 4,100 kg")
    local base = c(30, 30, 2000, 3, false)
    T.near(c(30, 30, 2000, 1, false), base + 2900, 1e-6, "1 pack + 2,900 kg")
    T.near(c(30, 30, 2000, 0, false), base + 4100, 1e-6, "no packs + 4,100 kg")
    T.near(c(30, 30, 2000, 2, false), base, 1e-6, "2 packs: the 3 packs' (estimate)")
    T.near(c(30, 5, 2000, 3, true), c(30, 5, 2000, 3, false) - 17100, 1e-6, "icing below 8 C: - 17,100 kg")
    T.near(c(30, 10, 2000, 3, true), c(30, 10, 2000, 3, false), 1e-6, "icing at 10 C: no reduction")
    T.near(c(25, -20, 0, 3, false), c(25, 0, 0, 3, false), 1e-6, "below 0 C: the 0 C value (estimate)")
    -- monotonic within 0.2 t (the curves as drawn: the 7,000 ft one rises 0.16 t
    -- at 16-17 C; flaps 25's -1,000 and 0 ft curves lie on each other, 450.5 and
    -- 450.4 t flat, 0 ft's 0.03 t the higher at 30 C)
    local bad = {}
    for _, flaps in ipairs({25, 30}) do
        for pa = -2000, 10000, 500 do
            local prev
            for oat = 0, 60, 0.5 do
                local w = c(flaps, oat, pa, 3, false)
                if w and prev and w > prev + 200 then bad[#bad + 1] = flaps .. " " .. pa .. " " .. oat end
                if w then prev = w end
            end
        end
        for oat = 0, 30, 5 do
            local prev
            for pa = -2000, 10000, 250 do
                local w = c(flaps, oat, pa, 3, false)
                if w and prev and w > prev + 200 then bad[#bad + 1] = flaps .. " " .. pa .. " ft " .. oat end
                if w then prev = w end
            end
        end
    end
    T.check(#bad == 0, "climb limit falls with OAT and altitude: " .. table.concat(bad, ", "))
    T.check(c(25, 20, 0) > c(30, 20, 0), "flaps 25's climb limit above flaps 30's")
    local w, why = c(30, 45, 10000, 3, false)
    T.check(w == nil and why, "45 C at 10,000 ft: off the chart")
    w, why = c(30, 20, 11000, 3, false)
    T.check(w == nil and why, "11,000 ft: nil")
end

------------------------------------------------------------------------
-- the quick turnaround limit (FPPM p.76), every printed cell
------------------------------------------------------------------------
do
    local QT_PRINTED = {
        [30] = {
            "50 312 306 301 294 289 283",
            "40 318 311 305 300 293 288 282 276 271 265 260",
            "30 323 317 311 304 298 292 287 282 275 270 264 259 254",
            "20 329 322 316 310 303 297 291 286 279 274 269 263 258",
            "10 335 328 322 316 309 303 297 291 285 279 274 268 262",
            "0 342 335 328 322 316 309 303 296 290 285 279 273 268",
            "-10 348 341 328 325 321 315 308 302 296 290 284 278 272",
            "-20 353 346 340 333 327 320 314 308 302 295 289 283 278",
            "-30 360 352 346 339 333 326 320 313 307 301 295 289 284",
            "-40 365 359 352 345 338 332 325 319 312 306 291 294 288",
            "-50 373 366 359 352 345 338 332 325 319 312 306 300 294",
        },
        [25] = {
            "50 294 288 282 277 271 266",
            "40 299 293 287 281 276 271 265 260 255 250 245",
            "30 304 298 292 286 281 275 270 264 259 254 249 244 239",
            "20 309 303 297 291 286 280 274 269 263 258 253 248 243",
            "10 315 309 303 297 291 285 279 274 268 263 257 252 247",
            "0 321 314 308 302 296 290 285 279 273 268 262 257 252",
            "-10 326 320 314 308 302 296 290 284 278 273 267 262 257",
            "-20 331 325 319 313 307 301 295 289 284 278 272 267 261",
            "-30 337 331 324 318 312 306 300 294 289 283 277 272 266",
            "-40 342 336 330 324 318 311 305 299 294 288 282 276 271",
            "-50 349 342 336 329 323 317 311 305 299 293 287 282 276",
        },
    }
    for _, flaps in ipairs({30, 25}) do
        local cells, bad = 0, {}
        for _, s in ipairs(QT_PRINTED[flaps]) do
            local v = {}
            for tok in s:gmatch("%S+") do v[#v + 1] = tonumber(tok) end
            local oat = v[1]
            for k = 2, #v do
                local pa = -2000 + (k - 2) * 1000
                local w, min = L.quick_turnaround(flaps, pa, oat, 0, 0, false)
                cells = cells + 1
                if w ~= v[k] * 1000 or min ~= 70 then bad[#bad + 1] = string.format("%d C %d ft %s", oat, pa, tostring(w)) end
            end
            -- the blanks
            if #v < 14 then
                local pa = -2000 + (#v - 1) * 1000
                if L.quick_turnaround(flaps, pa, oat, 0, 0, false) ~= nil then bad[#bad + 1] = string.format("%d C %d ft blank", oat, pa) end
            end
        end
        T.check(cells == 6 + 11 + 9 * 13 and #bad == 0, string.format("quick turnaround flaps %d: its %d cells as printed: %s", flaps, cells,
            table.concat(bad, ", ")))
    end
    -- the printed oddities kept (flaps 30: 0 ft -10 C 328, between 335's
    -- and 325's neighbours; 8,000 ft -40 C 291 below 9,000 ft's 294)
    T.equal(L.quick_turnaround(30, 0, -10), 328000, "flaps 30 0 ft -10 C: 328 as printed")
    T.equal(L.quick_turnaround(30, 8000, -40), 291000, "flaps 30 8,000 ft -40 C: 291 as printed")
    -- between the cells bilinear
    T.near(L.quick_turnaround(30, 500, 15), (316 + 310 + 322 + 316) / 4 * 1000, 1e-6, "500 ft 15 C: the four cells' mean")
    -- the notes
    local b = L.quick_turnaround(30, 0, 20)
    T.near(L.quick_turnaround(30, 0, 20, 1), b + 2700, 1e-6, "1 % uphill + 2,700 kg")
    T.near(L.quick_turnaround(30, 0, 20, -1), b - 7300, 1e-6, "1 % downhill - 7,300 kg")
    T.near(L.quick_turnaround(30, 0, 20, 0, 10), b + 5700, 1e-6, "10 kt headwind + 5,700 kg")
    T.near(L.quick_turnaround(30, 0, 20, 0, -10), b - 42600, 1e-6, "10 kt tailwind - 42,600 kg")
    T.near(L.quick_turnaround(30, 0, 20, 0, 0, true), b - 23100, 1e-6, "two brakes deactivated - 23,100 kg")
    T.equal(L.QT.wait_min, 70, "wait at least 70 minutes")
    T.equal(L.quick_turnaround(30, 0, -60), L.quick_turnaround(30, 0, -50), "colder than -50 C: the -50 C row (estimate)")
    T.check(L.quick_turnaround(30, 3500, 45) == nil, "45 C at 3,500 ft: the blank cells")
    T.check(L.quick_turnaround(30, 0, 55) == nil, "55 C: nil")
    T.check(L.quick_turnaround(30, 10500, 0) == nil, "10,500 ft: nil")
    T.check(L.quick_turnaround(25, 0, 20) < b, "flaps 25 below flaps 30")
end

------------------------------------------------------------------------
-- the EFB page's dispatch block and approach speed
------------------------------------------------------------------------
do
    T.near(L.approach_speed(30, 200000, 0, 5), V.vref(30, 200000, 0) + 5, 1e-9, "approach speed VREF 30 + 5 (127 + 5)")
    T.equal(L.approach_speed(30, 200000, 0, 5), 132, "200 t: 132 kt")
    local p = {flaps = 30, lda_m = 2400, pa_ft = 0, elev_ft = 0, oat_c = 5, wind_kt = 0, slope_pct = 0, cond = "WET",
        packs = 3, mlw_kg = 302092}
    local r = L.dispatch(p)
    local field = L.field_limit(30, 2400, 0, 0, "WET")
    local climb = L.climb_limit(30, 5, 0, 3, false)
    T.near(r.field, field, 1e-6, "dispatch: the field limit")
    T.near(r.climb, climb, 1e-6, "dispatch: the climb limit")
    T.near(r.normal.kg, math.min(field, climb, 302092), 1e-6, "dispatch: normal the least")
    T.equal(r.normal.limit, "FIELD", "dispatch: 2,400 m wet: field limited")
    T.near(r.normal.vref, V.vref(30, r.normal.kg, 0), 1e-9, "dispatch: VREF 30 at the limit weight")
    T.near(r.climb_ice, climb - 17100, 1e-6, "dispatch: with ice at 5 C")
    T.check(r.ice.kg <= r.normal.kg, "dispatch: with ice no heavier")
    T.near(r.field_lowvis, L.field_limit(30, 2400 / 1.15, 0, 0, "WET"), 1e-6, "dispatch: low visibility / 1.15")
    T.check(r.lowvis.kg < r.normal.kg, "dispatch: low visibility lighter")
    T.near(r.qt_kg, L.quick_turnaround(30, 0, 5), 1e-6, "dispatch: the quick turnaround weight")
    T.equal(r.qt_min, 70, "dispatch: 70 minutes")
    T.equal(r.f25_advised, false, "dispatch: no flaps 25 advice at the limit weight")
    local long = L.dispatch{flaps = 30, lda_m = 4000, pa_ft = 0, oat_c = 15, cond = "DRY", packs = 3, mlw_kg = 302092}
    T.equal(long.normal.limit, "STRUCT", "dispatch: a long runway: the structural limit")
    local hot = L.dispatch{flaps = 30, lda_m = 4000, pa_ft = 8000, oat_c = 38, cond = "DRY", packs = 3, mlw_kg = 400000}
    T.equal(hot.normal.limit, "CLIMB", "dispatch: hot and high: climb limited")
    local heavy = L.dispatch{flaps = 30, lda_m = 4000, pa_ft = 0, oat_c = 15, cond = "DRY", weight_kg = 340000, vref_add_kt = 5}
    T.equal(heavy.f25_advised, true, "dispatch: 340 t, VREF 30 168 + 5 above 167 kt: flaps 25 (FPPM p.72)")
    local inop = L.dispatch{flaps = 30, lda_m = 4000, pa_ft = 0, oat_c = 15, cond = "DRY", antiskid_inop = true}
    T.equal(inop.lowvis_div, 1.3, "dispatch: anti-skid inoperative: / 1.3")
    T.check(L.dispatch{flaps = 20} == nil, "dispatch flaps 20: nil")
end

T.done()
