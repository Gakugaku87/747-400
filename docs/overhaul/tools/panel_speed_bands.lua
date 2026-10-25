-- The custom acf's PFD speed tape bands (5-2 step 3b; panel changes allowed
-- anywhere since 2026-10-25). Run from the repository root:
--   luajit docs/overhaul/tools/panel_speed_bands.lua <acf in> <acf out>
-- It prints every change. The four bands of each PFD copy sit in two
-- clipped groups (GROUP Max Speed and GROUP Min Speed, each with a GROUP Spd
-- Ofst Kts) that moved with the airspeed, and the clip window moved with
-- them: the maximum side showed only around 320 kt, the minimum side only
-- around 160 kt, so the minimum maneuvering speed at cruise (about 250 kt)
-- never showed. Now the groups stay put on the tape (their airspeed key
-- frames are 0 everywhere) and each band pointer reads the band's speed
-- minus that PFD's airspeed, which the speed tape glue writes:
--   laminar/B747/airspeed/tape_capt[0..3] (the captain's copies) or
--   tape_fo[0..3] (the first officer's, names ending in " 2"):
--   [0] Min Speed (Vs), [1] Min Maneuver (Vminm, it read the old Vmc),
--   [2] Max Maneuver (Vmaxm), [3] Max Speed (Vmax).
-- Each pointer keeps its old place on the tape (4 px per kt through the
-- point where the band speed equals the airspeed). The line endings are
-- kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: panel_speed_bands.lua <acf in> <acf out>")

-- pointer -> tape index and its key frame output where the speed is the airspeed
local POINTERS = {
    ["Min Speed"] = {index = 0, at_zero = -635.5},
    ["Min Maneuver"] = {index = 1, at_zero = -240.5},
    ["Max Maneuver"] = {index = 2, at_zero = 240.5},
    ["Max Speed"] = {index = 3, at_zero = 635},
}
local PX_PER_KT = 4

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local function base(name) return (name:gsub(" 2$", "")) end

-- replace the KEY_FRAME lines that start at or after line i; returns the next line index
local function replace_frames(out, i, frames)
    while not lines[i]:match("^%s*KEY_FRAME ") do out[#out + 1] = lines[i]; i = i + 1 end
    local ind = lines[i]:match("^(%s*)")
    local old = {}
    while lines[i] and lines[i]:match("^%s*KEY_FRAME ") do
        old[#old + 1] = lines[i]:match("KEY_FRAME (.*)$")
        i = i + 1
    end
    for k, fr in ipairs(frames) do
        out[#out + 1] = string.format("%sKEY_FRAME %.6f %.6f%s", ind, fr[1], fr[2], k < #frames and " 1.000000" or "")
    end
    return i, table.concat(old, " | ")
end

local out, i, groups, pointers = {}, 1, 0, 0
local parent, side = nil, nil
while i <= #lines do
    local l = lines[i]
    local kind, name = l:match("^%s*(%S+) (.+)$")
    if kind == "GROUP" and not name:match("^Spd Ofst Kts") then
        parent = (base(name) == "Max Speed" or base(name) == "Min Speed") and name or nil
    end
    if kind == "GROUP" and parent and base(name) == "Spd Ofst Kts" then
        -- the band group: find its airspeed (the side), then key frames 0
        out[#out + 1] = l
        i = i + 1
        local j = i
        while not lines[j]:match("^%s*DATAREF ") do j = j + 1 end
        local ref = lines[j]:match("DATAREF (%S+)")
        side = ref == "laminar/B747/gauges/indicators/airspeed_kts_pilot" and "capt"
            or ref == "laminar/B747/gauges/indicators/airspeed_kts_copilot" and "fo" or nil
        assert(side, "unexpected band group dataref " .. tostring(ref) .. " near line " .. j)
        local old
        i, old = replace_frames(out, i, {{0, 0}, {250, 0}, {500, 0}})
        print(string.format("%s / GROUP %s (%s): airspeed key frames %s -> 0 at every speed", parent, name, side, old))
        groups = groups + 1
    elseif kind == "gen_pointer" and parent and POINTERS[base(name)] then
        local p = POINTERS[base(name)]
        out[#out + 1] = l
        i = i + 1
        while not lines[i]:match("^%s*DATAREF ") do out[#out + 1] = lines[i]; i = i + 1 end
        local ind, ref = lines[i]:match("^(%s*)DATAREF (%S+)")
        local new_ref = string.format("laminar/B747/airspeed/tape_%s[%d]", side, p.index)
        out[#out + 1] = ind .. "DATAREF " .. new_ref
        i = i + 1
        local old
        i, old = replace_frames(out, i, {{-500, p.at_zero - 500 * PX_PER_KT}, {0, p.at_zero}, {500, p.at_zero + 500 * PX_PER_KT}})
        print(string.format("%s / gen_pointer %s: %s -> %s; key frames %s -> 4 px/kt through 0 at %.1f",
            parent, name, ref, new_ref, old, p.at_zero))
        pointers = pointers + 1
    else
        out[#out + 1] = l
        i = i + 1
    end
end
assert(groups == 8 and pointers == 16, string.format("changed %d groups and %d pointers, expected 8 and 16", groups, pointers))

local o = assert(io.open(dst, "wb"))
o:write(table.concat(out, nl), nl)
o:close()
print("written " .. dst)
