-- Fix the custom acf's FUEL synoptic and the fuel to remain (FUEL-24; panel
-- instruments may change without approval since 2026-10-25). Run from the
-- repository root:
--   luajit docs/overhaul/tools/panel_fuel_synoptic.lua <acf in> <acf out>
-- It prints every change and keeps the file's line ends.
-- - The pump symbols (GROUP Pumps): each by laminar/B747/fuel/synoptic/pump[i]
--   from the fuel model (0 white, 1 cyan armed, 2 green, 3 amber low,
--   4 magenta, 5 magenta with flow), in place of the pump's run dataref with
--   its tank's quantity (amber only under 10 kg; the main 2 O/J AFT jettison
--   group read "blaminar/...", and its low pressure symbol could never show).
--   The groups' own conditions go. FCOM p.1447-1449, ATA26_28 p.421.
-- - The main tank boxes (GROUP Tanks): amber by synoptic/main_amber[n] (low
--   or an imbalance of the pair: ATA26_28 p.421), in place of under 900 kg.
-- - The CWT pumps' flow into the manifold (Std Flow): with their pressure
--   (synoptic/pump 2, green), in place of over 900 kg in the CWT.
-- - Suction feed (ATA26_28 p.422): the engine symbols and the main tank to
--   engine flow bars white/green with synoptic/suction[n] 0, an amber copy
--   (images from make_fuel_images.ps1) with 1.
-- - The fuel to remain on the primary EICAS: in the display's units
--   (fuel_to_remain/display); magenta with fuel_to_remain/state 0, a white
--   copy with 1 (2 is the flash's dark half; FCOM p.1449).
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_fuel_synoptic.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n")):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end

local changes = 0
local function note(i, old, new)
    changes = changes + 1
    print(string.format("%d: %s\n    -> %s", i, (old or ""):gsub("^%s+", ""), (new or "(removed)"):gsub("^%s+", "")))
end
local function indent(l) return l:match("^(%s*)") end
local function group_name(l) return l:match("^%s*GROUP (.-)%s*$") end
-- the END_GROUP of the GROUP at line i
local function group_end(i)
    local depth = 0
    for j = i, #lines do
        if group_name(lines[j]) then depth = depth + 1
        elseif lines[j]:match("^%s*END_GROUP%s*$") then
            depth = depth - 1
            if depth == 0 then return j end
        end
    end
    error("no END_GROUP for line " .. i)
end
local function find_group(name, from, to)
    for i = from or 1, to or #lines do
        if group_name(lines[i]) == name then return i end
    end
    error("no GROUP " .. name)
end
-- an instrument's block: its gen_ line to its last property line (the blank
-- line after it ends it)
local function block_end(i)
    local j = i + 1
    while lines[j] ~= nil and lines[j]:match("%S") and not lines[j]:match("^%s*gen_")
        and not group_name(lines[j]) and not lines[j]:match("^%s*END_GROUP") do j = j + 1 end
    return j - 1
end
local function prop(i, key)
    for j = i + 1, block_end(i) do
        local v = lines[j]:match("^%s*" .. key .. " (.*)$")
        if v then return v, j end
    end
end

local SYN = "laminar/B747/fuel/synoptic/"
local syn_from = find_group("FUEL Synoptic")
local syn_to = group_end(syn_from)

-- ======== the pump symbols
local PUMP_GROUPS = {["Main1 FWD"] = 0, ["Main 1 Aft"] = 1, ["Main 2 FWD"] = 2, ["Main 2 AFT"] = 3,
    ["Main 3 FWD"] = 4, ["Main 3 Aft"] = 5, ["Main 4 FWD"] = 6, ["Main 4 AFT"] = 7,
    ["Main 2 OJ FWD"] = 8, ["Main 2 OJ AFT"] = 9, ["Main 3 OJ FWD"] = 10, ["Main 3 OJ AFT"] = 11,
    ["Center OJ Left"] = 12, ["Center OJ RIght"] = 13, ["Stabilizer XJ Left"] = 14, ["Stabilizer XJ Right"] = 15}
local CODE = {["pump-OFF_white"] = 0, ["pumpOJ-OFF_white"] = 0, ["pumpOJ-STBY_cyan"] = 1,
    ["pump-ON_green"] = 2, ["pumpOJ-ON_green"] = 2, ["pump-ON_amber"] = 3, ["pumpOJ-LP_amber"] = 3,
    ["pumpOJ-JETT_magenta"] = 4, ["pumpOJ-JETT_magentaF"] = 5}
local remove = {}
local pumps_from = find_group("Pumps", syn_from, syn_to)
local pumps_to = group_end(pumps_from)
local seen, instruments, group_conditions = {}, 0, 0
local i = pumps_from + 1
while i < pumps_to do
    local name = group_name(lines[i])
    if name then
        local idx = PUMP_GROUPS[name]
        assert(idx, "unknown pump group " .. name .. " at " .. i)
        seen[idx] = true
        local last = group_end(i)
        for j = i, last do
            if group_name(lines[j]) then
                -- the group's own conditions: the lines right after it
                local k = j + 1
                while lines[k]:match("^%s*SHOW_") do
                    remove[k] = true
                    note(k, lines[k], nil)
                    group_conditions = group_conditions + 1
                    k = k + 1
                end
            elseif lines[j]:match("^%s*gen_rotary ") then
                local image = assert(prop(j, "IMAGE"), "no IMAGE at " .. j)
                local code = CODE[image:match("([^/]+)$")]
                assert(code, "unknown pump image " .. image .. " at " .. j)
                local count = 0
                for k = j + 1, block_end(j) do
                    if lines[k]:match("^%s*SHOW_") then
                        local new = string.format("%sSHOW_EQUAL %d.000000 %spump[%d]", indent(lines[k]), code, SYN, idx)
                        note(k, lines[k], new)
                        lines[k] = new
                        count = count + 1
                    end
                end
                assert(count == 1, "expected one condition in the instrument at " .. j)
                instruments = instruments + 1
            end
        end
        i = last + 1
    else
        i = i + 1
    end
end
for idx = 0, 15 do assert(seen[idx], "pump " .. idx .. " not found") end
assert(instruments == 70, "expected 70 pump symbols, found " .. instruments)
assert(group_conditions == 38, "expected 38 pump group conditions, found " .. group_conditions)

-- ======== the main tank boxes
local tanks_from = find_group("Tanks", syn_from, syn_to)
local tanks_to = group_end(tanks_from)
local boxes = 0
for j = tanks_from, tanks_to do
    local ind, op, n = lines[j]:match("^(%s*)SHOW_(%u+) 900%.0%d+ sim/flightmodel/weight/m_fuel%[([1-4])%]$")
    if ind then
        local amber = op == "LESS"
        local new = string.format("%sSHOW_EQUAL %d.000000 %smain_amber[%d]", ind, amber and 1 or 0, SYN, tonumber(n) - 1)
        note(j, lines[j], new)
        lines[j] = new
        boxes = boxes + 1
    end
end
assert(boxes == 8, "expected 8 main tank box conditions, found " .. boxes)

-- ======== the CWT pumps' flow into the manifold
local flows = 0
for name, idx in pairs({["Ctr OJ Pump L ON"] = 12, ["Ctr OJ Pump R ON"] = 13}) do
    local g = find_group(name, syn_from, syn_to)
    for j = g, group_end(g) do
        local ind = lines[j]:match("^(%s*)SHOW_GREATER 900%.010010 sim/flightmodel/weight/m_fuel%[0%]$")
        if ind then
            local new = string.format("%sSHOW_EQUAL 2.000000 %spump[%d]", ind, SYN, idx)
            note(j, lines[j], new)
            lines[j] = new
            flows = flows + 1
        end
    end
end
assert(flows == 2, "expected 2 CWT flow conditions, found " .. flows)

-- ======== suction feed and the fuel to remain: a condition after the
-- instrument's DATAREF line, and an amber/white copy after its block
local inserts = {}           -- [line] = lines to insert after it
local function condition_and_copy(j, show, copy_name, copy_image, copy_show)
    local _, d = prop(j, "DATAREF")
    assert(d, "no DATAREF at " .. j)
    assert(not prop(j, "SHOW_%u+"), "the instrument at " .. j .. " already has a condition")
    local ind = indent(lines[d])
    local cond = ind .. show
    inserts[d] = {cond}
    note(d, nil, cond)
    local copy = {""}
    for k = j, block_end(j) do
        local l = lines[k]
        if k == j then l = l:gsub("^(%s*gen_%a+ ).*$", "%1" .. copy_name)
        elseif l:match("^%s*IMAGE ") then l = indent(l) .. "IMAGE " .. copy_image end
        copy[#copy + 1] = l
        if k == d then copy[#copy + 1] = ind .. copy_show end
    end
    inserts[block_end(j)] = copy
    print(string.format("%d: + %s (%s, %s)", block_end(j), copy[2]:gsub("^%s+", ""), copy_image, copy_show))
    changes = changes + 1
end
local engines_from = find_group("Engines", syn_from, syn_to)
local symbols = 0
for j = engines_from, group_end(engines_from) do
    local n = lines[j]:match("^%s*gen_rotary #([1-4])%s*$")
    if n then
        assert(prop(j, "IMAGE") == "CRT Displays/EICAS Lower/FUEL/engine", "engine " .. n .. " image")
        local s = SYN .. "suction[" .. (tonumber(n) - 1) .. "]"
        condition_and_copy(j, "SHOW_EQUAL 0.000000 " .. s, "#" .. n .. " Suction",
            "CRT Displays/EICAS Lower/FUEL/engine_amber", "SHOW_EQUAL 1.000000 " .. s)
        symbols = symbols + 1
    end
end
assert(symbols == 4, "expected 4 engine symbols, found " .. symbols)
local bars = 0
for n = 1, 4 do
    local g = find_group("Main " .. n .. " to Eng " .. n, syn_from, syn_to)
    for j = g, group_end(g) do
        if lines[j]:match("^%s*gen_rotary Flow Bar%s*$") then
            assert(prop(j, "IMAGE") == "CRT Displays/EICAS Lower/FUEL/flow_std/MnToEng", "flow bar " .. n .. " image")
            local s = SYN .. "suction[" .. (n - 1) .. "]"
            condition_and_copy(j, "SHOW_EQUAL 0.000000 " .. s, "Flow Bar Suction",
                "CRT Displays/EICAS Lower/FUEL/flow_std/MnToEng_amber", "SHOW_EQUAL 1.000000 " .. s)
            bars = bars + 1
        end
    end
end
assert(bars == 4, "expected 4 tank to engine flow bars, found " .. bars)
-- the fuel to remain (primary EICAS, outside the synoptic)
local ftr = 0
for j = 1, #lines do
    if lines[j]:match("^%s*DATAREF laminar/B747/fuel/fuel_to_remain/rheostat%s*$") then
        local g = j
        while not lines[g]:match("^%s*gen_LED ") do g = g - 1 end
        local new = indent(lines[j]) .. "DATAREF laminar/B747/fuel/fuel_to_remain/display"
        note(j, lines[j], new)
        lines[j] = new
        condition_and_copy(g, "SHOW_EQUAL 0.000000 laminar/B747/fuel/fuel_to_remain/state", "LED White",
            "CRT Displays/LED/LED_3.26B.xx###0.white", "SHOW_EQUAL 1.000000 laminar/B747/fuel/fuel_to_remain/state")
        ftr = ftr + 1
    end
end
assert(ftr == 1, "expected 1 fuel to remain figure, found " .. ftr)

local out = {}
for j, l in ipairs(lines) do
    if not remove[j] then out[#out + 1] = l end
    if inserts[j] then for _, a in ipairs(inserts[j]) do out[#out + 1] = a end end
end
f = assert(io.open(dst, "wb"))
f:write(table.concat(out, nl), nl)
f:close()
print(changes .. " changes")
