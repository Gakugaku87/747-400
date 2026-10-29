-- An engine failure on the takeoff run (tests/flight/measure/aero_vmcg*.json)
-- for comparing the custom acf's directional control with VMCG (FCOM p.236
-- (PI.10.10); PROGRESS.md 5f, notes/AERO.md):
--   luajit tests/flight/tools/aero_vmcg.lua <run folder>
-- From the first mark (the failure): the IAS there, the heading's largest
-- swing from the heading at the failure and when, the heading 10 s on, and
-- the lateral path from the groundspeed and the heading (still air: the
-- track is the heading) up to 10 s and its largest deviation. The
-- certification's deviation limit is not in the sources: printed only.
local dir = arg[1]
assert(dir, "usage: aero_vmcg.lua <run folder>")
dir = dir:gsub("[/\\]$", "")

local function read_csv(path)
    local f = assert(io.open(path, "rb"), "no " .. path)
    local col, n = {}, 0
    for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; col[name] = n end
    local rows = {}
    for line in f:lines() do
        local v, k = {}, 0
        for x in (line .. ","):gmatch("([^,]*),") do k = k + 1; v[k] = tonumber(x) or x end
        rows[#rows + 1] = v
    end
    f:close()
    return col, rows
end
local col, rows = read_csv(dir .. "/session.csv")
for _, c in ipairs({"t", "ias", "hdg_mag", "gs_kt", "roll", "on_ground"}) do assert(col[c], "no column " .. c) end
local ecol, events = read_csv(dir .. "/events.csv")
local marks = {}
for _, e in ipairs(events) do
    if e[ecol.state] == "mark" then marks[#marks + 1] = tonumber(e[ecol.t]) end
end
assert(#marks >= 1, "no mark (the failure)")
local tf = marks[1]

local function wrap(d) return (d + 180) % 360 - 180 end
local r0
for r = 1, #rows do
    if rows[r][col.t] >= tf then r0 = r; break end
end
assert(r0, "the failure is after the recording")
local h0 = rows[r0][col.hdg_mag]
local worst, worst_t, side, side_max, last_h = 0, 0, 0, 0, nil
local h10, ias10
for r = r0 + 1, #rows do
    local v, p = rows[r], rows[r - 1]
    local t = v[col.t] - tf
    if t > 10 then break end
    local d = wrap(v[col.hdg_mag] - h0)
    if math.abs(d) > math.abs(worst) then worst, worst_t = d, t end
    local dt = v[col.t] - p[col.t]
    side = side + v[col.gs_kt] * 1.68781 * math.sin(math.rad(d)) * dt  -- ft
    if math.abs(side) > math.abs(side_max) then side_max = side end
    h10, ias10 = d, v[col.ias]
end
print(string.format("%s: engine failure at t %.1f s, IAS %.1f kt, heading %.1f", dir, tf, rows[r0][col.ias], h0))
if marks[2] then print(string.format("rudder %.1f s after the failure", marks[2] - tf)) end
print(string.format("heading swing: largest %+.1f deg at %.1f s; %+.1f deg at 10 s (IAS %.1f kt)", worst, worst_t,
    h10 or 0, ias10 or 0))
print(string.format("lateral path (+ right): largest %+.0f ft; %+.0f ft at 10 s", side_max, side))
print("FCOM p.236 (PI.10.10): VMCG 121 KIAS at sea level, 15 C, max takeoff thrust (the deviation limit is not in the sources)")
