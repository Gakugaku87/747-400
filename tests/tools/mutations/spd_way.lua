-- A spec for tests/tools/mutate.lua (2026-11-12): the speed law's near-level
-- path against its way (notes/ATA-22.md §62) broken one place at a time, in
-- the law, the VNAV mode model and the glue. Every one is caught by the
-- tests of the autopilot (run it after a change to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/spd_way.lua
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
return {
    file = AP .. "B747.70.afds_pitch_model.lua",
    tests = {
        "tests/autopilot/afds_pitch_model_test.lua",
        "tests/autopilot/flch_entry_test.lua",
        "tests/autopilot/spd_way_glue_test.lua",
        "tests/autopilot/vnav_mode_model_test.lua",
        "tests/autopilot/afds_glue_test.lua",
    },
    mutations = {
        -- the law
        {"M.SPD_LEVEL_FPM = 100", "M.SPD_LEVEL_FPM = 0", name = "near level: level flight"},
        {"M.SPD_LEVEL_FPM = 100", "M.SPD_LEVEL_FPM = 300", name = "near level: 300 fpm"},
        {"local way = toga and 0 or (inp.way or 0)", "local way = (inp.way or 0)", name = "the way in T/O and G/A too"},
        {"local way = toga and 0 or (inp.way or 0)", "local way = 0", name = "no way at all"},
        {"local fpm = inp.way_fpm or M.SPD_LEVEL_FPM", "local fpm = M.SPD_LEVEL_FPM", name = "the driftdown's rate not used"},
        {"local level = path(way * fpm, v) - gam", "local level = path(-way * fpm, v) - gam", name = "near level on the wrong side"},
        {"            if way > 0 then\n                local keep", "            if way < 0 then\n                local keep", name = "the climb's and the descent's sides exchanged"},
        {"dpath = math.max(dpath, math.min(level, math.max(hold - step, math.min(0, 2 * hold)) - gam))",
            "dpath = math.max(dpath, level)", name = "the climb: never past near level, thrust short or not"},
        {"dpath = math.max(dpath, math.min(level, math.max(hold - step, math.min(0, 2 * hold)) - gam))",
            "dpath = math.max(dpath, math.min(level, hold - step - gam))", name = "the climb: a descent for the speed with thrust for level flight"},
        {"dpath = math.min(dpath, math.max(level, math.min(hold + step, math.max(0, 2 * hold)) - gam))",
            "dpath = math.min(dpath, level)", name = "the descent: never past near level"},
        {"local keep = tr + math.max(0, M.protect(0, inp) - inp.ias) / M.SPD_TAU_S",
            "local keep = tr", name = "the climb: not back to the minimum speed at the law's own pace"},
        -- the VNAV mode model
        {"    if way == 0 and inp.phase == M.PHASE_DES then way = -1 end", "", file = AP .. "B747.70.vnav_mode_model.lua",
            name = "the descent's level parts: no way"},
        {"        out.way = dir", "        out.way = -dir", file = AP .. "B747.70.vnav_mode_model.lua", name = "VNAV SPD's way reversed"},
        -- the glue
        {"\t\tway = vo.way or 0", "\t\tway = 0", file = AP .. "B747.70.xt.autopilot.lua", name = "the glue: VNAV's way not passed"},
        {"then way_fpm = -B747DR_ap_fvn_vs end", "then way_fpm = nil end", file = AP .. "B747.70.xt.autopilot.lua",
            name = "the glue: the driftdown's rate not passed"},
        {"\t\tway = d > 0 and 1 or (d < 0 and -1 or 0)", "\t\tway = d > 0 and -1 or (d < 0 and 1 or 0)",
            file = AP .. "B747.70.xt.autopilot.lua", name = "the glue: FLCH's way reversed"},
        {"\tp.way, p.way_fpm = way, way_fpm", "\tp.way, p.way_fpm = 0, way_fpm", file = AP .. "B747.70.xt.autopilot.lua",
            name = "the glue: no way to the law"},
    },
}
