-- Run from the repository root with LuaJIT: luajit tests/fms/to_speeds_model_test.lua
-- The takeoff speed model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.to_speeds_model.lua, 6-1/6-2 step 3d;
-- notes/ATA-34-61-FMC.md §128) without X-Plane: the FPPM's takeoff speed
-- tables (747-400F/PW4056: FPPM p.41-42 the max takeoff rating, p.54-55 TO 1
-- 8 %, p.66-67 TO 2 20 %), their region chart, the slope/wind V1 and the
-- altitude adjustments, the FCOM's minimum control speeds (PW4056 PI.10.10,
-- 10.19, 10.33-34; CF6-80C2B1F PI.20.11, 20.20, 20.29) and the procedure on
-- them (FCOM PI.18.11; FPPM p.21 (1.1.3)): VR not below VRMIN with V2 from
-- the V2 for VRMIN, or with an assumed temperature V2 up by as much as VR;
-- V1 not below VMCG nor above VR; the minimums at the actual OAT (FAA AC
-- 25-13 5.b).
local T = dofile("tests/lib/check.lua")("to_speeds_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.to_speeds_model.lua")

-- the tables: three ratings, two flaps, 13 regions, 11 weights; each row up
-- with the weight; V1 not over VR, VR at least 3 kt under V2 (the printed
-- cells' smallest margin, kept by the filled ones)
local shape, rowsUp, order = true, true, true
for _, pct in ipairs({0, 8, 20}) do
    for _, flaps in ipairs({10, 20}) do
        local t = M.TABLES[pct] and M.TABLES[pct][flaps]
        if not t then shape = false break end
        for _, k in ipairs({"V1", "VR", "V2"}) do
            if #t[k] ~= 13 then shape = false end
            for r = 1, #t[k] do
                if #t[k][r] ~= 11 then shape = false end
                for i = 2, #t[k][r] do if t[k][r][i] < t[k][r][i - 1] then rowsUp = false end end
            end
        end
        for r = 1, 13 do
            for i = 1, 11 do
                if t.V1[r][i] > t.VR[r][i] or t.VR[r][i] > t.V2[r][i] - 3 then order = false end
            end
        end
    end
end
T.check(shape, "TO, TO 1 (8 %) and TO 2 (20 %), flaps 10 and 20: regions A to M by 200 to 400 t")
T.check(rowsUp, "every V1, VR and V2 row up with the weight")
T.check(order, "V1 not over VR, VR at least 3 kt under V2 in every cell")
local function cell(pct, flaps, region, t)
    local tab, i = M.TABLES[pct][flaps], (t - 200) / 20 + 1
    return tab.V1[region][i] .. "/" .. tab.VR[region][i] .. "/" .. tab.V2[region][i]
end
T.equal(cell(0, 10, 1, 400), "160/178/189", "TO flaps 10, region A, 400 t as printed (FPPM p.41)")
T.equal(cell(0, 10, 13, 200), "118/123/133", "TO flaps 10, region M, 200 t (p.41)")
T.equal(cell(0, 10, 8, 400), "169/184/189", "TO flaps 10, region H, 400 t (p.41)")
T.equal(cell(0, 20, 2, 300), "129/142/158", "TO flaps 20, region B, 300 t (p.42)")
T.equal(cell(8, 20, 2, 300), "133/144/158", "TO 1 flaps 20, region B, 300 t (p.55)")
T.equal(cell(20, 20, 2, 300), "138/147/158", "TO 2 flaps 20, region B, 300 t (p.67)")
T.equal(cell(20, 20, 2, 220), "109/118/136", "TO 2 flaps 20, region B, 220 t (p.67)")
-- the filled cells (estimates)
T.equal(cell(20, 20, 1, 340), "149/159.5/168.5", "TO 2 flaps 20's missing 340 t row: between 320 and 360 t (p.67)")
T.equal(cell(0, 10, 11, 400), "177/186/189",
    "TO flaps 10 region K's blank 400 t: J's 174/186/189 shifted by K - J at 380 t (3/1/0), VR then 3 under V2")
T.equal(cell(20, 20, 5, 200), "104/114/129", "TO 2 flaps 20 region E's blank 200 t: F's 106/114/129 shifted by E - F at 220 t")

-- the regions: each letter of the chart (FPPM p.41) in its own region
local letters = {
    {"A", 15.6, -915}, {"B", 15.6, 635}, {"C", 15.4, 2001}, {"D", 15.7, 3252}, {"E", 15.6, 4668},
    {"F", 15.7, 6391}, {"G", 15.4, 7729}, {"H", 18.7, 8461}, {"I", 23.8, 8832}, {"J", 31.5, 8904},
    {"K", 38.7, 8904}, {"L", 45.4, 8910}, {"M", 52.4, 8904},
}
local lettersOk = true
for _, l in ipairs(letters) do
    if M.REGIONS:sub(M.region(l[2], l[3]), M.region(l[2], l[3])) ~= l[1] then lettersOk = false end
end
T.check(lettersOk, "the chart's 13 letters each in its region")
T.equal(M.region(15, 0), 2, "15 C at sea level: B (A below -125 ft)")
T.equal(M.region(20, -125), 2, "on the A/B line: B, the higher")
T.equal(M.region(-30, 0), M.region(10, 0), "10 C and below: the chart's left edge")
T.equal(M.region(11, 10000), 8, "10,000 ft at 11 C: H (left of the H/I line's start at 12 C)")
T.equal(M.region(13, 10000), 9, "10,000 ft at 13 C: I")
T.equal(M.region(15, 12000), M.region(15, 10000), "above 10,000 ft: as at 10,000 ft (estimate)")
T.equal(M.region(15, -3000), 1, "below -2,000 ft: as at -2,000 ft, A (estimate)")
T.equal(M.region(90, 0), 13, "hotter than the right edge: M (estimate)")

-- the slope and wind V1 adjustments (FPPM p.41's table)
T.equal(M.wind_adjustment(400000, -15), -6, "15 kt tailwind: -6")
T.equal(M.wind_adjustment(400000, 10), 1, "400 t, 10 kt headwind: +1")
T.equal(M.wind_adjustment(350000, 10), 0, "350 t, 10 kt headwind: 0")
T.near(M.wind_adjustment(375000, 10), 0.5, 1e-9, "375 t, 10 kt: between the weights")
T.near(M.wind_adjustment(200000, 15), 0.5, 1e-9, "15 kt: between 10's 0 and 20's 1")
T.equal(M.wind_adjustment(300000, 60), 2, "beyond 40 kt: 40's")
T.equal(M.slope_adjustment(400000, -2), -5, "400 t, 2 % down: -5")
T.equal(M.slope_adjustment(400000, 2), 3, "400 t, 2 % up: +3")
T.equal(M.slope_adjustment(300000, 1), 1, "300 t, 1 % up: +1")
T.near(M.slope_adjustment(350000, -1.5), -3, 1e-9, "350 t, 1.5 % down: between -2 % (-4) and -1 % (-2)")
T.equal(M.slope_adjustment(300000, nil), 0, "no slope: 0")

-- the altitude adjustments: each chart's ADD 1 and ADD 2 labels in their
-- areas (FPPM p.41 flaps 10, p.42 flaps 20)
local function adj(flaps, t, ft) local a, b, c = M.altitude_adjustments(flaps, t * 1000, ft) return a .. "/" .. b .. "/" .. c end
local function one(flaps, k, t, ft) return ({M.altitude_adjustments(flaps, t * 1000, ft)})[k] end
T.equal(one(10, 1, 345.1, 6642), 1, "flaps 10 V1: its ADD 1 KT label")
T.equal(one(10, 2, 327.8, 5684), 1, "flaps 10 VR: ADD 1 KT")
T.equal(one(10, 2, 391.9, 9043), 2, "flaps 10 VR: ADD 2 KTS")
T.equal(one(10, 3, 342.8, 4310), 1, "flaps 10 V2: ADD 1 KT")
T.equal(one(10, 3, 382.0, 8652), 2, "flaps 10 V2: ADD 2 KTS")
T.equal(one(20, 1, 329.4, 7489), 1, "flaps 20 V1: ADD 1 KT")
T.equal(one(20, 2, 320.5, 6384), 1, "flaps 20 VR: ADD 1 KT")
T.equal(one(20, 2, 391.9, 9137), 2, "flaps 20 VR: ADD 2 KTS")
T.equal(one(20, 3, 329.2, 5090), 1, "flaps 20 V2: ADD 1 KT")
T.equal(one(20, 3, 389.8, 9020), 2, "flaps 20 V2: ADD 2 KTS")
T.equal(adj(10, 400, 0), "0/0/0", "sea level, 400 t: none")
T.equal(adj(10, 250, 8000), "0/0/0", "flaps 10, 250 t, 8,000 ft: left of the areas, none")
T.equal(adj(20, 220, 9500), "0/0/0", "flaps 20, 220 t, 9,500 ft: none")
T.equal(adj(10, 380, 8000), "1/2/2", "flaps 10, 380 t, 8,000 ft: V1 +1, VR and V2 +2")
T.equal(adj(10, 420, 8000), adj(10, 400, 8000), "over 400 t: as at 400 t (estimate)")

-- a derate between the tables: between their speeds (estimate)
local function ts(pct) local a, b, c = M.table_speeds(20, 2, 300000, 0, 0, 0, pct) return a .. "/" .. b .. "/" .. c end
T.equal(ts(4), "131/143/158", "4 %: half way between TO's 129/142 and TO 1's 133/144")
T.equal(ts(15), "136/146/158", "15 %: between TO 1 and TO 2 (138/147)")
T.equal(ts(25), "138/147/158", "over 20 %: TO 2's")

-- the FCOM's tables: VRMIN not under VMCG anywhere; cells as printed
local ok = true
for e = 0, 1 do
    for _, pct in ipairs(e == 0 and {0, 8, 15, 20} or {0, 5, 15}) do
        for oat = -55, 60, 5 do
            for _, pa in ipairs(M.PA) do
                local vmcg, vrmin = M.minimums(e, pct, oat, pa)
                if vrmin < vmcg - 1e-9 then ok = false end
            end
        end
    end
end
T.check(ok, "VRMIN not under VMCG in every table")
local function mins(e, pct, oat, pa) local a, b = M.minimums(e, pct, oat, pa) return a .. "/" .. b end
T.equal(mins(0, 0, 15, 0), "121/124", "PW TO, 15 C, sea level: 121/124 (PI.10.10; FPPM p.43 the same)")
T.equal(mins(0, 0, 60, 10000), "87/89", "PW TO, 60 C, 10,000 ft: 87/89")
T.equal(mins(0, 8, 15, 0), "116/119", "PW TO 1 (8 %): 116/119 (PI.10.19; FPPM p.56)")
T.equal(mins(0, 15, 15, 0), "112/114", "PW TO 2 15 %: 112/114 (PI.10.33)")
T.equal(mins(0, 20, 15, 0), "108/111", "PW TO 2 20 %: 108/111 (PI.10.33; FPPM p.68)")
T.equal(mins(0, 20, 0, 0), "108/111", "PW 20 %, 0 C (no row: between 10 C's and -55 C's): 108/111")
T.equal(mins(1, 0, 30, 0), "125/125", "CF6 TO, 86 F (30 C), sea level: 125/125 (PI.20.11)")
T.equal(mins(1, 0, 60, -2000), "112/113", "CF6 TO, 140 F, -2,000 ft: 112/113")
T.equal(mins(1, 5, 60, -2000), "110/110", "CF6 TO 1 (5 %): 110/110 (PI.20.20)")
T.equal(mins(1, 15, -55, 10000), "104/104", "CF6 TO 2 (15 %), -67 F, 10,000 ft: 104/104 (PI.20.29)")
T.equal(mins(2, 0, 15, 0), "121/124", "RB211: the PW4056's (no data: estimate)")
local vm, vr = M.minimums(0, 0, 10, 1000)
T.check(math.abs(vm - 119.5) < 1e-9 and math.abs(vr - 122.5) < 1e-9, "PW TO, 10 C, 1,000 ft: between the columns, 119.5/122.5")
vm, vr = M.minimums(0, 10, 15, 0)
T.check(math.abs(vm - (116 - 4 * 2 / 7)) < 1e-9 and math.abs(vr - (119 - 5 * 2 / 7)) < 1e-9,
    "PW 10 % (between TO 1's 8 and TO 2's 15 %): between their minimums (estimate)")
T.near(M.v2_for_vrmin(0, 0, 20, 200000, 124), 145.6, 1e-9, "PW TO flaps 20, 200 t, VR 124: V2 145.6 (PI.10.10)")
T.near(M.v2_for_vrmin(0, 8, 20, 200000, 119), 138.8, 1e-9, "PW TO 1, VR 119: 138.8 (PI.10.19)")
T.near(M.v2_for_vrmin(0, 20, 20, 200000, 111), 129, 1e-9, "PW TO 2 20 %, VR 111: 129 (PI.10.34)")
T.near(M.v2_for_vrmin(1, 0, 20, 200000, 126), 147.5 - 0.5 * (200 / M.LB_KG - 400) / 50, 1e-6,
    "CF6 TO, 200 t (440,925 lb), VR 126: between 400 and 450 (PI.20.11)")

-- the speeds
local function speeds(inp)
    local base = {flaps = 20, weight_kg = 200000, hw = 0, oat_c = 15, pa_ft = 0, engine = 0, pct = 0}
    for k, v in pairs(inp) do base[k] = v end
    local v1, vr, v2, info = M.speeds(base)
    return string.format("%d/%d/%d", v1, vr, v2), info
end
local s, info = speeds({})
T.equal(s, "121/124/146", "PW TO, flaps 20, 200 t, 15 C, sea level: V1 to VMCG, VR to VRMIN, V2 for VRMIN (the table's 92/105/130)")
T.check(info.region == 2 and info.vmcg == 121 and info.vrmin == 124, "region B, VMCG 121, VRMIN 124")
T.equal(speeds({weight_kg = 300000}), "129/142/158", "300 t: region B's (before, the add-on's 123/138/157)")
T.equal(speeds({weight_kg = 300000, hw = 20, slope = 2}), "131/142/158", "300 t, 20 kt headwind, 2 % up: V1 + 1 + 1")
T.equal(speeds({weight_kg = 300000, hw = -10, slope = -2}), "122/142/158", "300 t, 10 kt tailwind, 2 % down: V1 - 4 - 3")
T.equal(speeds({flaps = 10, weight_kg = 400000, slope = -2}), "156/179/189", "flaps 10, 400 t, 2 % down: B's 161 - 5")
T.equal(speeds({weight_kg = 300000, pct = 8}), "133/144/158", "TO 1 (8 %): its table")
T.equal(speeds({weight_kg = 300000, pct = 20}), "138/147/158", "TO 2 (20 %): its table")
T.equal(speeds({pct = 20}), "108/111/131", "TO 2, 200 t: V1 to its VMCG 108; VR the table's 111 (filled: estimate), V2 131")
T.equal(speeds({engine = 1}), "126/126/148", "CF6 TO: its minimums (VMCG 125.1 up to 126)")
T.equal(speeds({weight_kg = 300000, sel_c = 45}), "133/144/158", "assumed 45 C, OAT 15 C, 300 t: region E's (p.42)")
s, info = speeds({sel_c = 45})
T.check(s == "121/124/145" and info.vmcg == 121 and info.region == 5,
    "assumed 45 C, 200 t: VR from E's 108 to VRMIN 124 at the actual 15 C, V2 E's 129 + 16 (FPPM p.21 C, D): " .. s)
T.equal(speeds({sel_c = 10}), "121/124/146", "an assumed temperature under the OAT: none")
T.equal(speeds({flaps = 10, weight_kg = 340000, pa_ft = 5200}), "151/165/176",
    "flaps 10, 340 t, 5,200 ft: region E's 150/164/175, each + 1 for the altitude")
s, info = speeds({pa_ft = 9000, oat_c = 0, weight_kg = 300000})
T.check(s == "139/148/160" and info.region == 8,
    "9,000 ft, 0 C, 300 t: region H's 138/147/158 + 1/1/2 for the altitude (p.42): " .. s)
T.equal(speeds({flaps = 10, weight_kg = 410000}), speeds({flaps = 10, weight_kg = 400000}), "over 400 t: as at 400 t (estimate)")
T.done()
