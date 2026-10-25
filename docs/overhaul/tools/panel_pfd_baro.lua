-- The custom acf's PFD barometric setting boxed in amber at the transition
-- (5-2 step 4b; FCOM p.995 (10.10.33); panel changes allowed anywhere since
-- 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_pfd_baro.lua <acf in> <acf out>
-- It prints every change. In each of the four PFD copies, GROUP Baro (or
-- Baro 2) held the green STD label, the white preselect and the green
-- setting with its IN./HPA label. Now:
--   GROUP Baro Normal  shown with pfd/<side>/baro_alert 0: the STD label and
--                      the setting as before
--   GROUP Baro Alert   shown with it 1: the same in amber (the stock amber
--                      LED font, the amber STD and IN./HPA images) with an
--                      amber box round STD or round the setting and units
--   GROUP Pre-Select   as before
-- An instrument obeys one condition, so the alert is a group round the
-- existing ones (their STD/not-STD conditions stay). The images come from
-- make_pfd_baro_images.ps1: the boxes are centred on the STD label and 23
-- to the right of, 1 below, the setting's digits (measured on a screenshot
-- of the Captain's outboard PFD). The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_baro.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function base(name) return (name:gsub(" 2$", "")) end
local function indent(block, by)
    local o = {}
    for k, l in ipairs(block) do o[k] = (l == "" and l) or (by .. l) end
    return o
end
local function append(dstt, block) for _, l in ipairs(block) do dstt[#dstt + 1] = l end end
-- a copy of a block with its first line renamed and lines changed by fn
-- (fn returns the line to keep, or nil to drop it)
local function copy(block, suffix, fn)
    local o = {}
    for k, l in ipairs(block) do
        if k == 1 then l = l .. suffix end
        if fn then l = fn(l) end
        if l then o[#o + 1] = l end
    end
    return o
end

local out, done = {}, 0
local i = 1
while i <= #lines do
    local l = lines[i]
    local ind, gname = l:match("^(%s*)GROUP (Baro.*)$")
    if ind and (gname == "Baro" or gname == "Baro 2") then
        -- the group's own lines and its children (blocks at one more indent)
        local props, children, cur = {}, {}, nil
        local j = i + 1
        while not lines[j]:match("^" .. ind .. "END_GROUP%s*$") do
            local l2 = lines[j]
            local ind2 = l2:match("^(%s*)")
            if #ind2 == #ind + 2 and (l2:match("^%s*gen_[%a_]+ ") or l2:match("^%s*GROUP ")) then
                cur = {name = base(l2:match("^%s*%S+ (.+)$")), lines = {l2}}
                children[cur.name] = cur
            elseif cur then
                cur.lines[#cur.lines + 1] = l2
            else
                props[#props + 1] = l2
            end
            j = j + 1
        end
        local std, pre, act = children["STD Label"], children["Pre-Select"], children["Active: Non-STD"]
        assert(std and pre and act, "GROUP " .. gname .. " near line " .. i .. ": unexpected children")
        local side = table.concat(std.lines, "\n"):match("laminar/B747/efis/baro_std/(%a+)/switch_pos")
        assert(side == "capt" or side == "fo", "no side near line " .. i)
        local sfx = gname == "Baro 2" and " 2" or ""
        local in2, in4 = ind .. "  ", ind .. "    "
        local alert = "laminar/B747/pfd/" .. side .. "/baro_alert"
        -- the STD label's and the setting's positions
        local sx, sy = table.concat(std.lines, "\n"):match("POS ([%d.%-]+) ([%d.%-]+)")
        local lx, ly = table.concat(act.lines, "\n"):match("gen_LED[^\n]*\n%s*POS ([%d.%-]+) ([%d.%-]+)")
        sx, sy, lx, ly = tonumber(sx), tonumber(sy), tonumber(lx), tonumber(ly)
        assert(sx and lx, "no positions near line " .. i)

        out[#out + 1] = l
        append(out, props)
        -- normal: the stock instruments
        out[#out + 1] = in2 .. "GROUP Baro Normal" .. sfx
        out[#out + 1] = in4 .. "SHOW_LESS 0.500000 " .. alert
        append(out, indent(std.lines, "  "))
        append(out, indent(act.lines, "  "))
        out[#out + 1] = in2 .. "END_GROUP"
        -- the alert: amber copies and the boxes
        out[#out + 1] = in2 .. "GROUP Baro Alert" .. sfx
        out[#out + 1] = in4 .. "SHOW_GREATER 0.500000 " .. alert
        append(out, indent(copy(std.lines, " A", function(x)
            return (x:gsub("IMAGE CRT Displays/PFD/Baro/STDlabel$", "IMAGE CRT Displays/PFD/Baro/STDlabelA"))
        end), "  "))
        append(out, indent(copy(std.lines, "", function(x)
            if x:match("^%s*gen_rotary ") then return (x:gsub("gen_rotary .*$", "gen_rotary STD Box A" .. sfx)) end
            if x:match("^%s*POS ") then return (x:gsub("POS .*$", string.format("POS %.6f %.6f", sx, sy + 0.5))) end
            return (x:gsub("IMAGE CRT Displays/PFD/Baro/STDlabel$", "IMAGE CRT Displays/PFD/Baro/BaroBoxStdA"))
        end), "  "))
        -- the setting's group: amber digits and units, then the box
        local a = copy(act.lines, " A", function(x)
            x = x:gsub("(IMAGE CRT Displays/LED/LED_2%.18R%.xx###0)%.green$", "%1.amber")
            return (x:gsub("IMAGE CRT Displays/PFD/Annunciators/BAROref$", "IMAGE CRT Displays/PFD/Annunciators/BAROrefA"))
        end)
        local box = copy(std.lines, "", function(x)
            if x:match("^%s*gen_rotary ") then return (x:gsub("gen_rotary .*$", "gen_rotary Baro Box A" .. sfx)) end
            if x:match("^%s*SHOW_") then return nil end
            if x:match("^%s*POS ") then return (x:gsub("POS .*$", string.format("POS %.6f %.6f", lx + 23, ly - 1))) end
            return (x:gsub("IMAGE CRT Displays/PFD/Baro/STDlabel$", "IMAGE CRT Displays/PFD/Baro/BaroBoxA"))
        end)
        -- the box goes before the group's END_GROUP
        local last = #a
        while not a[last]:match("^%s*END_GROUP") do last = last - 1 end
        local a2 = {}
        for k = 1, last - 1 do a2[#a2 + 1] = a[k] end
        append(a2, indent(box, "  "))
        for k = last, #a do a2[#a2 + 1] = a[k] end
        append(out, indent(a2, "  "))
        out[#out + 1] = in2 .. "END_GROUP"
        append(out, pre.lines)
        out[#out + 1] = lines[j]                -- the END_GROUP
        print(string.format("GROUP %s (%s, near line %d): Baro Normal (STD label, setting) and Baro Alert"
            .. " (amber copies, STD box at %.1f %.1f, setting box at %.1f %.1f) on %s",
            gname, side, i, sx, sy + 0.5, lx + 23, ly - 1, alert))
        done = done + 1
        i = j + 1
    else
        out[#out + 1] = l
        i = i + 1
    end
end
assert(done == 4, "changed " .. done .. " baro groups, expected 4")

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
