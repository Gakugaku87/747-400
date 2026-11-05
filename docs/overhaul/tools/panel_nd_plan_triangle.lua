-- docs/overhaul/tools/panel_nd_plan_triangle.lua (2026-11-05, notes/ATA-31.md
-- §46, ACF_DIFF.md §5): the expanded airplane triangle of both NDs not in
-- PLAN. The expanded group drew it at the map's origin, which in the CRT's
-- PLAN (pln_style 2, FCOM p.1029) is the centre waypoint, not the airplane
-- (the user's photo: the triangle at MOCOS); PLAN's airplane symbol is the
-- FMS bridge's at its position (FCOM p.1147). Run once from the repository
-- root on the acf before the change
-- (D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261105_before_plan_triangle):
--   luajit docs/overhaul/tools/panel_nd_plan_triangle.lua 747-400_custom.acf
local path = arg[1]
local lines = {}
for l in io.lines(path) do lines[#lines + 1] = l end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local done = 0
for _, s in ipairs({{name = "gen_rotary Aircraft Triangle", side = "fo"}, {name = "gen_rotary Aircraft Triangle 2", side = "capt"}}) do
    for n = 1, #lines do
        -- the expanded one (y -107; the centred one at 62.5 is MAP CTR's)
        if trim(lines[n]) == s.name and trim(lines[n + 1]):match("^POS [%d.]+ %-107%.000000$") then
            assert(trim(lines[n + 3]) == "DATAREF" and trim(lines[n + 4]) == "HIDE", "the block: " .. lines[n + 3])
            local ind = lines[n + 3]:match("^(%s*)")
            table.insert(lines, n + 4, ind .. "SHOW_LESS 2.500000 laminar/B747/nd/mode/" .. s.side .. "/sel_dial_pos")
            print(string.format("%d: %s: SHOW_LESS 2.500000 laminar/B747/nd/mode/%s/sel_dial_pos added", n + 4, s.name, s.side))
            done = done + 1
            break
        end
    end
end
assert(done == 2, "both NDs' triangles")
local f = assert(io.open(path, "wb"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
