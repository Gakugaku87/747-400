-- The custom acf's PFD attitude, heading and vertical speed and their flags
-- (5-2 step 4a; panel changes allowed anywhere since 2026-10-25). Run from
-- the repository root:
--   luajit docs/overhaul/tools/panel_pfd_sources.lua <acf in> <acf out>
-- It prints every change. In each of the four PFD copies (GROUP Captain PFD
-- and GROUP First Officer PFD, outboard and inboard) the stock panel hid the
-- attitude, the heading and the vertical speed together on one IRS flag
-- (laminar/B747/pfd/capt/irs or fo/irs) and turned the heading scale by the
-- ND's up direction (laminar/B747/nd/up/*: the track in MAP, north in PLN).
-- Now, from the PFD sources model (B747.60.pfd_model.lua), per side (capt
-- or fo):
--   pfd/<side>/att    the attitude (else the ATT flag and the fixed airplane
--                     symbol of the IRS OFF group)
--   pfd/<side>/hdg    the heading scale and bug (else the HDG flag)
--   pfd/<side>/trk    the track indicator
--   pfd/<side>/vsi    the vertical speed scale and pointer
--   pfd/<side>/vert   the VERT flag
-- and the heading scale turns by X-Plane's AHRS heading of that side (what
-- the IRS glue compares for >HEADING). The IRS flag also hid the DH, MDA and
-- radio altitude digits and the AFDS status (FD, CMD, LAND 3): an instrument
-- obeys one condition, the last, so their own conditions were lost; those
-- lines are removed. The glideslope scale stays on it for step 4e, and the
-- NDs for step 5. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_pfd_sources.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function base(name) return (name:gsub(" 2$", "")) end
-- what an item hidden on the IRS flag now shows on
local ON = {
    ["Attitude Indicator"] = "att", ["Artificial Horizon"] = "att", ["Pitch Scale"] = "att",
    ["Bank Scale"] = "att", ["Bank Pointer"] = "att", ["Slip/Skid Offset"] = "att",
    ["Rsng Rwy Offset"] = "att",
    ["Hdg/Track Display"] = "hdg", ["Heading Bug"] = "hdg",
    ["VSI Display"] = "vsi",
}
-- items whose IRS line goes (their own conditions come back)
local DROP = {["AFDS Status Annun"] = true, ["DH Annun"] = true, ["DH Label"] = true, ["DH LED"] = true,
    ["LED"] = true, ["MDA Label"] = true, ["MDA LED"] = true}
-- the IRS OFF group's children and what they show on (below that value)
local OFF_CHILD = {["Airplane Symbol"] = "att", ["ATT X"] = "att", ["HDG X"] = "hdg"}
local AHRS = {capt = "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot",
    fo = "sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_copilot"}

local out, counts = {}, {}
local function count(k) counts[k] = (counts[k] or 0) + 1 end
local top, item, kind, off_group, off_indent = nil, nil, nil, nil, nil
local pending = nil         -- a SHOW line to insert after this item's DATAREF line
for _, l in ipairs(lines) do
    local ind = l:match("^(%s*)")
    local k, name = l:match("^%s*(GROUP) (.+)$")
    if not k then k, name = l:match("^%s*(gen_[%a_]+) (.+)$") end
    if k == "GROUP" and #ind == 0 then top = name end
    local in_pfd = top and (top:match("^Captain PFD") or top:match("^First Officer PFD"))
    local side = in_pfd and (top:match("^Captain") and "capt" or "fo")
    if k then
        item, kind = name, k
        pending = nil
        if off_group and #ind <= off_indent then off_group = nil end
        if in_pfd and off_group and k ~= "GROUP" then
            for prefix, what in pairs(OFF_CHILD) do
                if base(name):sub(1, #prefix) == prefix then
                    pending = string.format("SHOW_LESS 0.500000 laminar/B747/pfd/%s/%s", side, what)
                end
            end
        end
        if in_pfd and k == "gen_needle" and base(name) == "Track Indicator" then
            pending = string.format("SHOW_GREATER 0.500000 laminar/B747/pfd/%s/trk", side)
        end
        out[#out + 1] = l
    elseif in_pfd and l:match("^%s*SHOW_%u+ %S+ laminar/B747/pfd/%a+/irs$") then
        local b = base(item)
        if ON[b] then
            local new = string.format("%sSHOW_GREATER 0.500000 laminar/B747/pfd/%s/%s", ind, side, ON[b])
            print(string.format("%s / %s %s: %s -> %s", top, kind, item, l:match("^%s*(.*)$"), new:match("^%s*(.*)$")))
            out[#out + 1] = new
            count(ON[b])
        elseif b:match("^VERT X") then
            local new = string.format("%sSHOW_GREATER 0.500000 laminar/B747/pfd/%s/vert", ind, side)
            print(string.format("%s / %s %s: %s -> %s", top, kind, item, l:match("^%s*(.*)$"), new:match("^%s*(.*)$")))
            out[#out + 1] = new
            count("vert")
        elseif kind == "GROUP" and b:match("IRS OFF PFD$") then
            print(string.format("%s / GROUP %s: %s removed (its flags get their own conditions)", top, item, l:match("^%s*(.*)$")))
            off_group, off_indent = item, #ind - 2
            count("off group")
        elseif DROP[b] then
            print(string.format("%s / %s %s: %s removed", top, kind, item, l:match("^%s*(.*)$")))
            count("dropped")
        else
            out[#out + 1] = l       -- the glideslope scale (step 4e)
            count("kept")
        end
    elseif in_pfd and l:match("^%s*DATAREF laminar/B747/nd/up/%a+$") then
        local new = ind .. "DATAREF " .. AHRS[side]
        print(string.format("%s / %s %s: %s -> %s", top, kind, item, l:match("^%s*(.*)$"), new:match("^%s*(.*)$")))
        out[#out + 1] = new
        count("rose")
    elseif pending and l:match("^%s*DATAREF") then
        out[#out + 1] = l
        out[#out + 1] = ind .. pending
        print(string.format("%s / %s %s: + %s", top, kind, item, pending))
        count(pending:match("/(%a+)$") .. " added")
        pending = nil
    else
        out[#out + 1] = l
    end
end
local keys = {}
for key in pairs(counts) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do print(string.format("%-12s %d", key, counts[key])) end
-- per copy: 6 or 7 attitude items (the F/O's rising runway too), 2 heading,
-- 1 V/S, 1 VERT, 2 rose, 1 track, the IRS OFF group and its 3 flags
assert(counts.att == 26 and counts.hdg == 8 and counts.vsi == 4 and counts.vert == 4, "unexpected attitude/heading/VS changes")
assert(counts.rose == 8 and counts["trk added"] == 4 and counts["off group"] == 4, "unexpected rose/track/group changes")
assert(counts["att added"] == 8 and counts["hdg added"] == 4, "unexpected IRS OFF flag changes")

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
