-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- SYS-7): the demand pumps 1 and 4's flap signal (N19-HYD-01: pump 1 from
-- the right FCU, 4 from the left; ATA29_32 p.61-62) broken one place at a
-- time in the model and the glue. Every one is caught by these tests (run it
-- after a change to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/hyd_fcu_wiring.lua
local MODEL = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.hyd_model.lua"
local GLUE = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hyd_power.lua"
return {
    file = MODEL,
    tests = {"tests/hyd/hyd_model_test.lua", "tests/hyd/hyd_module_test.lua"},
    mutations = {
        {"local fcu = inp.flaps_fcu == nil or inp.flaps_fcu[n] ~= false", "local fcu = true", name = "model: the FCU's failure ignored"},
        {"flaps = fcu and inp.flaps_moving", "flaps = inp.flaps_moving", name = "model: on the ground the FCU ignored"},
        {"if fcu and inp.flaps_down then", "if inp.flaps_down then", name = "model: in the air the FCU ignored"},
        {"inp.flaps_fcu[1] = B747DR_hyd_fcu_fail[2] < 0.5", "inp.flaps_fcu[1] = B747DR_hyd_fcu_fail[0] < 0.5", file = GLUE, name = "glue: system 1 from the left FCU"},
        {"inp.flaps_fcu[4] = B747DR_hyd_fcu_fail[0] < 0.5", "inp.flaps_fcu[4] = B747DR_hyd_fcu_fail[2] < 0.5", file = GLUE, name = "glue: system 4 from the right FCU"},
        {"inp.flaps_fcu[1] = B747DR_hyd_fcu_fail[2] < 0.5", "inp.flaps_fcu[1] = B747DR_hyd_fcu_fail[1] < 0.5", file = GLUE, name = "glue: system 1 from the centre FCU"},
        {"inp.flaps_fcu[1] = B747DR_hyd_fcu_fail[2] < 0.5", "inp.flaps_fcu[1] = true", file = GLUE, name = "glue: system 1's FCU never failed"},
        {"inp.flaps_fcu[4] = B747DR_hyd_fcu_fail[0] < 0.5", "inp.flaps_fcu[4] = true", file = GLUE, name = "glue: system 4's FCU never failed"},
        {"inp.flaps_down = B747DR_fcu_te_down > 0.5", "inp.flaps_down = false", file = GLUE, name = "glue: flaps down never"},
        {"inp.flaps_moving = B747DR_fcu_te_moving > 0.5", "inp.flaps_moving = false", file = GLUE, name = "glue: flaps moving never"},
    },
}
