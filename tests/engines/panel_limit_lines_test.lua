-- Run from the repository root with LuaJIT: luajit tests/engines/panel_limit_lines_test.lua
-- (2026-11-24, the stage 4 review's PNL-3) The engine tapes' fixed limit
-- lines in the custom acf's panel against the tapes' own scales: a tape's
-- fill reaches each line at the limit the line marks - where the
-- indication changes colour (B747.40.engine_display_model.lua: M.EGT,
-- M.RPM_RED). FCOM p.837-838 (7.10.9-10): the EGT red line is the takeoff
-- limit, the amber band the continuous limit, the start limit line shown
-- with the fuel control switch in CUTOFF until the N2 is up, the indication
-- changing colour as it reaches them; the figures draw the red line on the
-- top of the tape's box and the start line inside the tape. FCOM p.833-836
-- (7.10.5-8): the N1 red line the operating limit (also its figure: the top
-- of the box). The lines (images over the box's top) stay; the tapes' key
-- frames are bent so that the limits land on them. Before: the P&W's EGT red
-- and amber lines 26 °C low (628 and 603 on the tape against 654 and 629),
-- the GE's EGT red and amber 19 and 40 °C low, its start limit line 64 px
-- over the tape (between the N1 tape and the EGT box), the GE's N1 red line
-- at 116.0 % (117.5) and its N2 red line on the ENG page at 105.4 %
-- (112.5). RR: no source (its limits are past the P&W tape it shares).
local T = dofile("tests/lib/check.lua")("panel_limit_lines")
local P = dofile("tests/lib/panel.lua")
dofile("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_display_model.lua")
local D = B747_engine_display_model
local panel = P.load("747-400_custom.acf")

local function group(name, under)
    local g = P.find(panel, {kind = "GROUP", name = name, under = under})
    T.check(g ~= nil, "GROUP " .. name)
    return g
end

-- the tapes under g reading names that start with prefix: the same
-- ascending key frames for all; then each line group's four marks where the
-- tape in the same column reaches its limit
local function check_set(label, g, prefix, lines)
    if g == nil then return end
    local tapes = {}
    for _, e in ipairs(P.find_all(panel, {kind = "gen_tape", under = g})) do
        if e.dref and e.dref:sub(1, #prefix) == prefix then tapes[#tapes + 1] = e end
    end
    T.check(#tapes >= 8, label .. ": its tapes (" .. #tapes .. ")")
    local ref = tapes[1]
    for _, t in ipairs(tapes) do
        T.check(P.ascending(t), label .. ": line " .. t.line .. ": ascending key frames")
        T.check(t.y == ref.y and #t.kf == #ref.kf, label .. ": line " .. t.line .. ": the same POS and key frames as the others")
        for i = 1, math.min(#t.kf, #ref.kf) do
            T.check(t.kf[i][1] == ref.kf[i][1] and t.kf[i][2] == ref.kf[i][2], label .. ": line " .. t.line .. ": key frame " .. i)
        end
    end
    for _, l in ipairs(lines) do
        local lg = group(l[1], g)
        local marks = lg and P.find_all(panel, {kind = "gen_rotary", under = lg}) or {}
        T.equal(#marks, 4, label .. ": " .. l[1] .. ": four marks")
        for _, m in ipairs(marks) do
            local found = false
            for _, t in ipairs(tapes) do
                if not found and math.abs(t.x - m.x) < 0.01 then
                    found = true
                    local at = t.y + P.at(t, l[2])
                    T.near(m.y, at, 0.5, string.format("%s: %s (line %d, y %.1f) where the tape reaches %g (y %.2f)",
                        label, l[1], m.line, m.y, l[2], at))
                end
            end
            T.check(found, label .. ": " .. l[1] .. ": a tape under the mark of line " .. m.line)
        end
    end
    return tapes
end

local eng = group("Engine")
local egt_normal = group("EGT Tapes Normal", eng)
-- P&W (EPR engines' tape; the RR shares it: no source for the RB211)
check_set("P&W EGT", group("EGT Tape", egt_normal), "laminar/B747/engines/display_EGT[",
    {{"Redline Markers", D.EGT.PW.red}, {"Continuous  Limit", D.EGT.PW.amber}, {"Start Limit Markers", D.EGT.PW.start}})
-- GE
check_set("GE EGT", group("EGT Tape GE", egt_normal), "laminar/B747/engines/display_GE_EGT[",
    {{"Redline Markers", D.EGT.GE.red}, {"Continuous  Limit", D.EGT.GE.amber}, {"Start Limit Markers", D.EGT.GE.start}})
local n1 = group("N1", eng)
check_set("P&W N1", group("N1 Tape", n1), "laminar/B747/engines/display_N1[",
    {{"Redline Markers", D.RPM_RED.PW.n1}})
local ge_n1 = group("N1 Tape GE", n1)
local ge_tapes = check_set("GE N1", ge_n1, "laminar/B747/engines/display_N1[", {{"Redline Markers", D.RPM_RED.GE.n1}})
-- the ENG page's N2 (the lower EICAS)
local n2_rows = group("N2 Rows")
check_set("P&W N2", group("N2", n2_rows), "laminar/B747/engines/display_N2[", {{"Limit Marker", D.RPM_RED.PW.n2}})
check_set("GE N2", group("N2 GE", n2_rows), "laminar/B747/engines/display_N2[", {{"Limit Marker", D.RPM_RED.GE.n2}})

-- the GE's N1 marks on its tape (the reference, white and magenta, and the
-- maximum line) on the tape's scale
if ge_tapes then
    local tape = ge_tapes[1]
    local marks = {}
    for _, e in ipairs(P.find_all(panel, {kind = "gen_pointer"})) do
        local d = e.dref or ""
        if d:find("laminar/B747/engines/display_N1_ref[", 1, true) == 1 or d:find("laminar/B747/engines/display_N1_max[", 1, true) == 1 then
            marks[#marks + 1] = e
        end
    end
    T.equal(#marks, 12, "the GE's N1 reference (white, magenta) and maximum marks")
    for _, m in ipairs(marks) do
        for _, v in ipairs({20, 50, 80, 100, 110, 117.5}) do
            T.near(m.y + P.at(m, v), tape.y + P.at(tape, v), 0.01,
                string.format("line %d (%s): N1 %g on the tape's scale", m.line, m.name, v))
        end
    end
end

T.done()
