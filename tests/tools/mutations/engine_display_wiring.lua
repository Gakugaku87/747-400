-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- DSP-6 d): the engine indications' colours and the EICAS's thrust
-- reference line broken one place at a time, the review's five mutants that
-- passed the tests before this day's (its two on the STATUS memory's glue:
-- status_nvm_wiring.lua). Every one is caught by these tests (run it after a change
-- to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/engine_display_wiring.lua
local D = "plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_display_model.lua"
local F = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua"
local G = "plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engine_display.lua"
return {
    file = D,
    tests = {
        "tests/engines/engine_display_model_test.lua",
        "tests/engines/engine_display_module_test.lua",
        "tests/fms/takeoff_ref_test.lua",
    },
    mutations = {
        {'if s.mode == "TO" and s.d and sel then eicas', 'if s.mode == "TO" and sel then eicas', file = F, name = "the SEL without D-"},
        {"M.EPR_RED_BELOW, M.EPR_WHITE_BELOW = 0.003, 0.01", "M.EPR_RED_BELOW, M.EPR_WHITE_BELOW = 0.01, 0.003", name = "the EPR red's hysteresis swapped"},
        {"if out.n2_red[n] or out.n3_red[n] then out.exceed_n2 = true end", "if out.n2_red[n] then out.exceed_n2 = true end", name = "the RB211's N3 brings up no partial format"},
        {"inp.cutoff[n] = B747DR_fuel_control_toggle_switch_pos[i] <= 0.95", "inp.cutoff[n] = B747DR_fuel_control_toggle_switch_pos[i] <= 0.05", file = G, name = "glue: CUTOFF only with the switch fully down"},
        {"inp.cruise = B747DR_engines_pseu_pri_gnd == 0 and simDR_flap_deploy_ratio < 0.01", "inp.cruise = simDR_flap_deploy_ratio < 0.01", file = G, name = "glue: the CF6's oil differential on the ground too"},
    },
}
