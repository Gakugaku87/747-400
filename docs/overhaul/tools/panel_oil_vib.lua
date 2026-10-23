-- Rewrite the custom acf's secondary EICAS oil and vibration indications to
-- take their colours and labels from the engine indication model (2-3 step
-- 3, ENG-25-27, ENG-29). Run from the repository root:
--   luajit docs/overhaul/tools/panel_oil_vib.lua <acf in> <acf out>
-- It prints every change.
--   oil pressure readout: red while EICAS2_oil_press_status (it showed only
--     below 10 psi), white while not red and not amber, amber (new, the CF6's
--     band) while oil_press_amber (FCOM p.846-847)
--   oil pressure pointer: amber (new) while oil_press_amber
--   oil temperature readout: amber above 160 degC (it started at 150 and
--     overlapped the white readout; FCOM p.847-848, ATA70_80 p.524)
--   oil quantity readout: magenta (new) while oil_qty_magenta (FCOM p.849)
--   vibration source label: N1, N2, FAN, LPT (new images) by vib_source,
--     BB only for source 0 (FCOM p.849-850)
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_oil_vib.lua <acf in> <acf out>")
local F = "laminar/B747/engines/"

local lines = {}
for l in io.lines(src) do lines[#lines + 1] = l:gsub("\r$", "") end

-- the instrument blocks: start, end (inclusive), indent, group path, name
local blocks, groups = {}, {}
local i = 1
while i <= #lines do
    local ind, rest = lines[i]:match("^(%s*)(.*)$")
    local g = rest:match("^GROUP%s*(.*)$")
    if g then
        while #groups > 0 and groups[#groups].depth >= #ind do table.remove(groups) end
        groups[#groups + 1] = {name = g, depth = #ind}
    elseif rest == "END_GROUP" then
        while #groups > 0 and groups[#groups].depth >= #ind do table.remove(groups) end
    elseif rest:match("^gen_") then
        local j = i + 1
        while j <= #lines do
            local ind2 = lines[j]:match("^(%s*)")
            if #ind2 <= #ind or lines[j]:match("^%s*$") then break end
            j = j + 1
        end
        local p = {} for k = 1, #groups do p[k] = groups[k].name end
        blocks[#blocks + 1] = {s = i, e = j - 1, ind = ind, path = table.concat(p, " > "), name = rest}
    end
    i = i + 1
end

local changes = 0
local function note(b, what) changes = changes + 1; print(string.format("%d\t%s\t%s\t%s", b.s, b.path, b.name, what)) end
-- the engine index of a block, from its dataref or conditions
local function engine(b)
    for k = b.s, b.e do
        local n = lines[k]:match("oil_press_psi%[(%d)%]") or lines[k]:match("oil_qty_liters%[(%d)%]")
            or lines[k]:match("EICAS2_oil_press_status%[(%d)%]") or lines[k]:match("engines/vibration%[(%d)%]")
        if n then return n end
    end
end
-- a copy of a block's lines with edits
local function copy(b, name, image, cond_edit)
    local out = {}
    for k = b.s, b.e do
        local l = lines[k]
        if k == b.s then l = b.ind .. name
        elseif image and l:match("^%s*IMAGE ") then l = l:gsub("IMAGE .*$", "IMAGE " .. image)
        end
        out[#out + 1] = l
    end
    if cond_edit then out = cond_edit(out) end
    return out
end
-- insert a condition after the last SHOW_ line (or the DATAREF line)
local function add_cond(t, cond)
    local at
    for k = 1, #t do if t[k]:match("^%s*SHOW_") or t[k]:match("^%s*DATAREF") then at = k end end
    local ind = t[2]:match("^(%s*)")
    table.insert(t, at + 1, ind .. cond)
    return t
end

local edits = {}            -- [block start] = {replace = {lines}, after = {lines}}
for _, b in ipairs(blocks) do
    local n = nil
    if b.path:find("ENG Synoptic > Oil Pressure > LED > Lo Limit", 1, true) and b.name:match("^gen_LED Engine") then
        local t = copy(b, b.name:match("^%s*(.*)$"))
        for k = #t, 1, -1 do if t[k]:match("^%s*SHOW_LESS 10%.000000 %[%d%]$") then table.remove(t, k) end end
        edits[b.s] = {replace = t}; note(b, "red readout: dropped 'SHOW_LESS 10 [n]'")
    elseif b.path:find("ENG Synoptic > Oil Pressure > LED > Normal", 1, true) and b.name:match("^gen_LED Engine") then
        n = engine(b)
        local t = copy(b, b.name:match("^%s*(.*)$"))
        for k = 1, #t do
            if t[k]:match("^%s*SHOW_GREATER 9%.990000 %[%d%]$") then
                t[k] = t[k]:gsub("SHOW_GREATER 9%.990000 %[%d%]$", "SHOW_EQUAL 0.000000 " .. F .. "oil_press_amber[" .. n .. "]")
            end
        end
        local amber = copy(b, b.name:match("^%s*(.*)$") .. " Amber", "CRT Displays/LED/LED_3.26B.xx###0.amber", function(c)
            for k = #c, 1, -1 do if c[k]:match("^%s*SHOW_") and not c[k]:find("EICAS2_oil_press_status", 1, true) then table.remove(c, k) end end
            return add_cond(c, "SHOW_EQUAL 1.000000 " .. F .. "oil_press_amber[" .. n .. "]")
        end)
        edits[b.s] = {replace = t, after = amber}
        note(b, "white readout: 'SHOW_EQUAL 0 oil_press_amber[" .. n .. "]'; + amber readout")
    elseif b.path:find("Oil Pressure > Tape", 1, true) and b.path:find("> Pointer > Normal", 1, true) and b.name:match("^gen_pointer Engine") then
        n = engine(b)
        local t = add_cond(copy(b, b.name:match("^%s*(.*)$")), "SHOW_EQUAL 0.000000 " .. F .. "oil_press_amber[" .. n .. "]")
        local img
        for k = b.s, b.e do img = img or lines[k]:match("IMAGE (CRT Displays/EICAS Lower/ptr_%a+)$") end
        local amber = copy(b, b.name:match("^%s*(.*)$") .. " Amber", img .. "_amber", function(c)
            return add_cond(c, "SHOW_EQUAL 1.000000 " .. F .. "oil_press_amber[" .. n .. "]")
        end)
        edits[b.s] = {replace = t, after = amber}
        note(b, "white pointer: 'SHOW_EQUAL 0 oil_press_amber[" .. n .. "]'; + amber pointer")
    elseif b.path:find("ENG Synoptic > Oil Temp > LED", 1, true) and b.path:find("Amber Hi", 1, true) then
        local t = copy(b, b.name:match("^%s*(.*)$"))
        for k = 1, #t do t[k] = t[k]:gsub("SHOW_GREATER 150%.009995 ", "SHOW_GREATER 160.009995 ") end
        edits[b.s] = {replace = t}; note(b, "amber readout from 160 degC (150 before)")
    elseif b.path:find("ENG Synoptic > Oil Qty > LED", 1, true) and b.name:match("^gen_LED Engine") then
        n = engine(b)
        local t = add_cond(copy(b, b.name:match("^%s*(.*)$")), "SHOW_EQUAL 0.000000 " .. F .. "oil_qty_magenta[" .. n .. "]")
        local mag = copy(b, b.name:match("^%s*(.*)$") .. " Magenta", "CRT Displays/LED/LED_3.26B.xx###0.magenta", function(c)
            return add_cond(c, "SHOW_EQUAL 1.000000 " .. F .. "oil_qty_magenta[" .. n .. "]")
        end)
        edits[b.s] = {replace = t, after = mag}
        note(b, "white readout: 'SHOW_EQUAL 0 oil_qty_magenta[" .. n .. "]'; + magenta readout")
    elseif b.path:find("ENG Synoptic > VIB > Source", 1, true) and b.name:match("^gen_rotary BB%-%d") then
        n = engine(b)
        local t = add_cond(copy(b, b.name:match("^%s*(.*)$")), "SHOW_EQUAL 0.000000 " .. F .. "vib_source[" .. n .. "]")
        local after = {}
        for code, label in ipairs({"N1", "N2", "FAN", "LPT"}) do
            local c = copy(b, b.name:match("^%s*(.*)$"):gsub("BB", label), "CRT Displays/EICAS Lower/vib_" .. label .. "_label", function(x)
                return add_cond(x, "SHOW_EQUAL " .. string.format("%.6f", code) .. " " .. F .. "vib_source[" .. n .. "]")
            end)
            after[#after + 1] = ""
            for _, l in ipairs(c) do after[#after + 1] = l end
        end
        edits[b.s] = {replace = t, after = after}
        note(b, "BB only for 'vib_source[" .. n .. "] == 0'; + N1, N2, FAN, LPT labels")
    end
end

local out, k = {}, 1
local ends = {}
for _, b in ipairs(blocks) do ends[b.s] = b.e end
while k <= #lines do
    local e = edits[k]
    if e then
        for _, l in ipairs(e.replace) do out[#out + 1] = l end
        if e.after then
            if e.after[1] ~= "" then out[#out + 1] = "" end   -- a blank line between instruments, as the acf has
            for _, l in ipairs(e.after) do out[#out + 1] = l end
        end
        k = ends[k] + 1
    else
        out[#out + 1] = lines[k]
        k = k + 1
    end
end
local f = assert(io.open(dst, "wb"))
f:write(table.concat(out, "\n"), "\n")
f:close()
io.stderr:write(string.format("%d changes, %d -> %d lines\n", changes, #lines, #out))
