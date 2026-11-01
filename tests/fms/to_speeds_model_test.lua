-- Run from the repository root with LuaJIT: luajit tests/fms/to_speeds_model_test.lua
-- The takeoff speed model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.to_speeds_model.lua, 6-1/6-2 step 3d;
-- notes/ATA-34-61-FMC.md §128) without X-Plane: the takeoff speed tables
-- and their region chart (the three broken cells and region B's line), the
-- FCOM's minimum control speeds (PW4056 PI.10.10, 10.19, 10.33-34;
-- CF6-80C2B1F PI.20.11, 20.20, 20.29) and the QRH's procedure on them
-- (FCOM PI.18.11): VR not below VRMIN with V2 from the V2 for VRMIN, V1 not
-- below VMCG nor above VR; an assumed temperature's region, the minimums at
-- the actual OAT (FAA AC 25-13 5.b).
local T = dofile("tests/lib/check.lua")("to_speeds_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.to_speeds_model.lua")

-- the tables: each row up with the weight, V2 not under VR (the three cells
-- broke these: flaps 10 region D's VR 93-111 kt at 320-420 t, flaps 20
-- region D's VR 97 at 220 t, flaps 20 region E's V2 149 at 380 t)
local rowsUp, v2OverVr = true, true
for _, flaps in ipairs({10, 20}) do
    for region = 1, 5 do
        for _, t in ipairs({M.V1, M.VR, M.V2}) do
            local row = t[flaps][region]
            if #row ~= 12 then rowsUp = false end
            for i = 2, #row do if row[i] < row[i - 1] then rowsUp = false end end
        end
        for i = 1, 12 do
            if M.V2[flaps][region][i] < M.VR[flaps][region][i] then v2OverVr = false end
        end
    end
end
T.check(rowsUp, "every V1, VR and V2 row up with the weight (12 weights)")
T.check(v2OverVr, "V2 not under VR in every cell")
T.equal(M.VR[10][4][7], 156, "flaps 10 region D VR at 320 t: 156 (read 93)")
T.equal(M.VR[10][4][12], 187, "flaps 10 region D VR at 420 t: 187 (read 111)")
T.equal(M.VR[20][4][2], 114, "flaps 20 region D VR at 220 t: 114 (read 97)")
T.equal(M.V2[20][5][10], 179, "flaps 20 region E V2 at 380 t: 179 (read 149)")
-- the region lines down from their tops (region B's at 36.84 C read
-- 26.84 C's 2,876 ft, rising back)
local linesDown = true
for _, line in ipairs(M.LINES) do
    local top = 1
    for i = 2, #line do if line[i][2] > line[top][2] then top = i end end
    for i = top + 1, #line do if line[i][2] > line[i - 1][2] then linesDown = false end end
end
T.check(linesDown, "each region line down from its top")

-- the regions
T.equal(M.region(15, 0), 1, "15 C at sea level: A")
T.equal(M.region(37, 2000), 3, "37 C at 2,000 ft: C (before, B: the line's 36.84 C point)")
T.equal(M.region(0, 1050.89), 2, "on region A's top: B, the higher")
T.equal(M.region(0, 9000), 5, "above region E's top (7,977 ft at 0 C): E (before, none: no speeds)")
T.equal(M.region(70, 0), 5, "hotter than the right edges: E")
T.equal(M.region(-70, -3000), 1, "below the chart's -60 C and -2,000 ft: A")

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
T.equal(mins(0, 0, 15, 0), "121/124", "PW TO, 15 C, sea level: 121/124 (PI.10.10)")
T.equal(mins(0, 0, 60, 10000), "87/89", "PW TO, 60 C, 10,000 ft: 87/89")
T.equal(mins(0, 8, 15, 0), "116/119", "PW TO 1 (8 %): 116/119 (PI.10.19)")
T.equal(mins(0, 15, 15, 0), "112/114", "PW TO 2 15 %: 112/114 (PI.10.33)")
T.equal(mins(0, 20, 15, 0), "108/111", "PW TO 2 20 %: 108/111 (PI.10.33)")
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
T.equal(s, "121/124/146", "PW TO, flaps 20, 200 t, 15 C, sea level: V1 to VMCG, VR to VRMIN, V2 for VRMIN (the table's 88/102/130)")
T.check(info.region == 1 and info.vmcg == 121 and info.vrmin == 124, "region A, VMCG 121, VRMIN 124")
T.equal(speeds({weight_kg = 300000}), "123/138/157", "300 t: the table's, over the minimums")
T.equal(speeds({weight_kg = 300000, hw = 20}), "125/138/157", "300 t, 20 kt headwind: V1 + 2")
T.equal(speeds({pct = 8}), "116/119/139", "TO 1 (8 %): its minimums")
T.equal(speeds({pct = 20}), "108/111/130", "TO 2 (20 %): its minimums, the table's V2 over its V2 for VRMIN (129)")
T.equal(speeds({engine = 1}), "126/126/148", "CF6 TO: its minimums (VMCG 125.1 up to 126)")
T.equal(speeds({weight_kg = 300000, sel_c = 45}), "128/142/157",
    "assumed 45 C, OAT 15 C, 300 t: region C's speeds (AC 25-13 5.c)")
s, info = speeds({sel_c = 45})
T.check(s == "121/124/146" and info.vmcg == 121, "assumed 45 C, 200 t: the minimums the full thrust's at the actual 15 C (AC 25-13 5.b): " .. s)
T.equal(speeds({sel_c = 10}), "121/124/146", "an assumed temperature under the OAT: none")
T.equal(speeds({flaps = 10, weight_kg = 340000, oat_c = 15, pa_ft = 5200}), "149/163/175",
    "flaps 10, 340 t, region D: VR 163 (before 97)")
s = speeds({pa_ft = 9000, oat_c = 0, weight_kg = 300000})
T.equal(s, "135/146/158", "9,000 ft, 0 C, 300 t: region E's (before, none)")
T.done()
