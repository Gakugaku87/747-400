-- The custom acf's heading reference (5-2 step 5d; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_hdg_ref.lua <acf in> <acf out>
-- It prints every change. In both PFDs (each in its two groups) and both
-- NDs:
--  - the heading scales, roses, pointers, digits and track lines read each
--    side's heading and track in the heading reference (laminar/B747/pfd/
--    capt|fo/hdg_deg, trk_deg from B747.60.xt.displays.lua: magnetic, or
--    true in TRU) instead of X-Plane's magnetic ones (heading_AHARS_deg_mag
--    _pilot|copilot, ground_track_mag_pilot|copilot);
--  - the MAG labels show the reference: the PFDs' (CRT Displays/PFD/Heading
--    Track/hdg_ref_pfd, 2 frames) on laminar/B747/efis/hdg_ref/pfd_label,
--    the NDs' (EFIS/Maps/hdg_ref_nd, 5 frames) on nd_label, in PLN on
--    nd_plan_label (no box: FCOM p.1142).
-- Images from make_hdg_ref_images.ps1. The line endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_hdg_ref.lua <acf in> <acf out>")

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function ind(i) return #lines[i]:match("^(%s*)") end
local function group_end(i)
    local s = lines[i]:match("^(%s*)")
    local j = i + 1
    while not lines[j]:match("^" .. s .. "END_GROUP%s*$") do j = j + 1 end
    return j
end
local function gen_end(i)
    local n, j = ind(i), i + 1
    while lines[j] and not (lines[j]:match("%S") and ind(j) <= n) do j = j + 1 end
    return j - 1
end
-- the innermost group holding line i
local function group_of(i, top)
    local best
    for j = top, i - 1 do
        if lines[j]:match("^%s*GROUP ") and group_end(j) > i then best = j end
    end
    return best
end

local I = "sim/cockpit2/gauges/indicators/"
local TOPS = {
    {"GROUP Captain PFD", "capt", "pilot", "pfd"}, {"GROUP First Officer PFD", "fo", "copilot", "pfd"},
    {"GROUP Captain ND", "capt", "pilot", "nd"}, {"GROUP First Officer ND", "fo", "copilot", "nd"},
}
local changes = 0
for _, top in ipairs(TOPS) do
    local name, side, xp, kind = top[1], top[2], top[3], top[4]
    local map = {
        [I .. "heading_AHARS_deg_mag_" .. xp] = "laminar/B747/pfd/" .. side .. "/hdg_deg",
        [I .. "ground_track_mag_" .. xp] = "laminar/B747/pfd/" .. side .. "/trk_deg",
    }
    local found = 0
    for t, l in ipairs(lines) do
        if l == name then
            found = found + 1
            local e = group_end(t)
            for j = t + 1, e - 1 do
                local pre, ref = lines[j]:match("^(%s*DATAREF )(%S+)%s*$")
                if ref and map[ref] then
                    print(string.format("%s (line %d): DATAREF %s -> %s", name, j, ref, map[ref]))
                    lines[j] = pre .. map[ref]
                    changes = changes + 1
                end
                if lines[j]:match("^%s*gen_rotary MAG Label") then
                    local g = group_of(j, t)
                    local plan = g and lines[g]:match("^%s*GROUP PLN")
                    local image, dref, digits
                    if kind == "pfd" then
                        image, dref, digits = "CRT Displays/PFD/Heading Track/hdg_ref_pfd", "laminar/B747/efis/hdg_ref/pfd_label", 2
                    else
                        image = "EFIS/Maps/hdg_ref_nd"
                        dref = plan and "laminar/B747/efis/hdg_ref/nd_plan_label" or "laminar/B747/efis/hdg_ref/nd_label"
                        digits = 5
                    end
                    local keys = 0
                    for k = j + 1, gen_end(j) do
                        local p = lines[k]:match("^(%s*)")
                        local key = lines[k]:match("^%s*(%u[%u_]*)")
                        if key == "IMAGE" then
                            lines[k] = p .. "IMAGE " .. image
                        elseif key == "DATAREF" then
                            lines[k] = p .. "DATAREF " .. dref
                        elseif key == "KEY_FRAME" then
                            keys = keys + 1
                            lines[k] = p .. (keys == 1 and "KEY_FRAME 0.000000 0.000000 1.000000" or "KEY_FRAME 1.000000 1.000000")
                        elseif key == "DIGITS" then
                            lines[k] = p .. "DIGITS " .. digits
                        end
                    end
                    assert(keys == 2, "two key frames in the MAG label at line " .. j)
                    print(string.format("%s (line %d): %s -> %s on %s (%d frames)", name, j,
                        lines[j]:match("^%s*(.-)%s*$"), image, dref, digits))
                    changes = changes + 1
                end
            end
        end
    end
    assert(found == (kind == "pfd" and 2 or 1), "groups named " .. name .. ": " .. found)
end
print(changes .. " changes")

local w = assert(io.open(dst, "wb"))
w:write(table.concat(lines, nl), nl)
w:close()
print("written " .. dst)
