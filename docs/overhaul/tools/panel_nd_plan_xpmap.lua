-- panel_nd_plan_xpmap.lua <acf>: no X-Plane map on the NDs in PLAN (6-1/6-2
-- step 6d2; docs/overhaul/ACF_DIFF.md §5): in each ND's centred map group
-- (MAP CTR and PLAN) X-Plane's map (EFIS_map_s_HM, full and half) wrapped in
-- a group shown unless the ND's mode selector is at PLN (FCOM p.1039: no
-- weather radar nor TCAS in PLN; X-Plane's map drew its own airplane symbol
-- from its own PLN centre, the plan's last row since step 6d2). CRLF kept.
-- Run once on the custom acf, 2026-11-02.
local path = arg[1]
local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close()
assert(s:find("\r\n", 1, true))
s = s:gsub("\r\n", "\n")
local ind = string.rep(" ", 10)
local function wrap(side)
    local full = ind .. "GROUP XP Map Full\n" .. ind .. "  SHOW_LESS 0.500000 laminar/B747/nd/" .. side .. "/xp_map_half\n"
    local half = ind .. "GROUP XP Map Half\n" .. ind .. "  SHOW_GREATER 0.500000 laminar/B747/nd/" .. side .. "/xp_map_half\n"
    local i = s:find(full, 1, true)
    assert(i, side .. ": XP Map Full not found")
    assert(not s:find(full, i + 1, true), side .. ": XP Map Full twice")
    local h = s:find(half, i, true)
    assert(h, side .. ": XP Map Half not found")
    local e1, e2 = s:find("\n" .. ind .. "END_GROUP\n", h, true)
    assert(e1, side .. ": its END_GROUP not found")
    local block = s:sub(i, e1)          -- from GROUP XP Map Full to the line before the last END_GROUP
    local last = ind .. "END_GROUP\n"   -- XP Map Half's END_GROUP
    -- the two groups two spaces in
    local inner = (block .. last):gsub("([^\n]*)\n", function(l) return (l == "" and "" or "  " .. l) .. "\n" end)
    local new = ind .. "GROUP XP Map not PLAN\n"
        .. ind .. "  SHOW_LESS 2.500000 laminar/B747/nd/mode/" .. side .. "/sel_dial_pos\n"
        .. ind .. "  HIDE\n"
        .. inner
        .. ind .. "END_GROUP\n"
    s = s:sub(1, i - 1) .. new .. s:sub(e2 + 1)
    print(side .. ": wrapped " .. select(2, block:gsub("\n", "")) + 1 .. " lines")
end
wrap("fo")
wrap("capt")
s = s:gsub("\n", "\r\n")
f = assert(io.open(path, "wb")); f:write(s); f:close()
print("ok")
