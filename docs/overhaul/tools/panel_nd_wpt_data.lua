-- panel_nd_wpt_data.lua <acf>: the NDs' active waypoint ETA and distance
-- (6-1/6-2 step 11d2b; docs/overhaul/ACF_DIFF.md §5): in the four
-- "Waypoints" groups (each ND's MAP and PLAN) the two instruments wrapped in
-- a group shown with laminar/B747/nd/<side>/wpt_data (0 while the FMC the
-- NAV source selector selects is failed: ATA34_2 p.633). Run once on the
-- custom acf, 2026-11-01.
local P = arg[1]
local f = assert(io.open(P, "rb")); local s = f:read("*a"); f:close()
assert(not s:find("\r", 1, true), "not LF")
assert(not s:find("/wpt_data", 1, true), "already done")
local lines = {}
for l in (s .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end
local GROUPS = {
    ["GROUP Waypoints FO CENTER"] = {"fo", "Wpt Data FO CEN"},
    ["GROUP Waypoints FO EXPAND"] = {"fo", "Wpt Data FO EXP"},
    ["GROUP Waypoints CAPT CENT"] = {"capt", "Wpt Data CAPT CEN"},
    ["GROUP Waypoints CAPT EXPA"] = {"capt", "Wpt Data CAPT EXP"},
}
local out, done = {}, 0
local i = 1
while i <= #lines do
    local l = lines[i]
    local g = GROUPS[l:match("^%s*(GROUP .-)%s*$") or ""]
    out[#out + 1] = l
    i = i + 1
    if g then
        local gind = l:match("^(%s*)")
        local cind = gind .. "  "
        -- to the ETA instrument as it is
        while not lines[i]:match("^%s*gen_text Waypoint ETA") do
            assert(not lines[i]:match("^%s*END_GROUP"), "no ETA in " .. l)
            out[#out + 1] = lines[i]
            i = i + 1
        end
        out[#out + 1] = cind .. "GROUP " .. g[2]
        out[#out + 1] = cind .. "  SHOW_GREATER 0.500000 laminar/B747/nd/" .. g[1] .. "/wpt_data"
        out[#out + 1] = cind .. "  LOCKED"
        -- the ETA and the distance two spaces in, to the group's end
        while not (lines[i]:match("^%s*END_GROUP") and lines[i]:match("^(%s*)") == gind) do
            local x = lines[i]
            out[#out + 1] = x == "" and x or ("  " .. x)
            i = i + 1
        end
        out[#out + 1] = cind .. "END_GROUP"
        done = done + 1
    end
end
assert(done == 4, "groups wrapped: " .. done)
local w = assert(io.open(P, "wb")); w:write(table.concat(out, "\n") .. "\n"); w:close()
print("wrapped " .. done .. " groups; lines " .. #lines .. " -> " .. #out)
