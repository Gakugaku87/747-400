-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- WARN-4): the takeoff configuration warning's and CONFIG GEAR's wiring (the
-- flight controls' glue, the warning's glue and model) broken one place at a
-- time; the review's nine wiring mutants (seven of them passed the tests
-- before this day's) and four on WARN-3's change. Every one is caught by
-- these tests (run it after a change to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/config_gear_wiring.lua
local TOCW = "plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.tocw_model.lua"
local FLT = "plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.xt.fltCtrls.lua"
local ALERTS = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.alerts.lua"
local AM = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.alert_model.lua"
return {
    file = TOCW,
    tests = {
        "tests/fltctrls/tocw_model_test.lua",
        "tests/fltctrls/fltctrls_module_test.lua",
        "tests/warning/alert_model_test.lua",
        "tests/warning/alerts_module_test.lua",
    },
    mutations = {
        {"M.LEVER_CLOSED = 0.05", "M.LEVER_CLOSED = 0.5", name = "T9 lever threshold 0.5"},
        {"tw.reverser[i] = simDR_sb_prop_mode[i - 1] == 3 or simDR_tocw_rev_deploy[i - 1] > 0.01", "tw.reverser[i] = simDR_sb_prop_mode[i - 1] == 3", file = FLT, name = "W1 sleeves not looked at"},
        {"tw.reverser[i] = simDR_sb_prop_mode[i - 1] == 3 or simDR_tocw_rev_deploy[i - 1] > 0.01", "tw.reverser[i] = simDR_tocw_rev_deploy[i - 1] > 0.01", file = FLT, name = "W2 prop mode not looked at"},
        {"tw.lever[i] = B747DR_sb_thrust_lever[i - 1]", "tw.lever[i] = 1", file = FLT, name = "W3 lever not wired"},
        {"tw.on_ground = B747DR_fcu_pri_gnd == 1", "tw.on_ground = true", file = FLT, name = "W4 on the ground always"},
        {"local lever_only = (config_gear_thrust and not config_gear_flaps) and (1 + config_gear_more) or 0", "local lever_only = config_gear_thrust and (1 + config_gear_more) or 0", file = FLT, name = "W5 lever_only with the flaps too"},
        {"if config_gear_after_lo >= 140 or simDR_radio_alt_height_capt > 800.0 then config_gear_after_lo = nil end", "if simDR_radio_alt_height_capt > 800.0 then config_gear_after_lo = nil end", file = FLT, name = "W7 no 140 s end"},
        {"tw.speedbrake_not_down = B747DR_speedbrake_lever > 0.01", "tw.speedbrake_not_down = B747DR_speedbrake_lever > 0.2", file = FLT, name = "W9 ARMED not taken as not DOWN"},
        {"inp.config_gear_lever = B747DR_alert_cfg_gear_lever >= 1", "inp.config_gear_lever = false", file = ALERTS, name = "A2 cause not wired to the alerts"},
        {"inp.config_gear_lever_n = math.floor(B747DR_alert_cfg_gear_lever + 0.5)", "inp.config_gear_lever_n = 1", file = ALERTS, name = "N1 (WARN-3) the count not wired to the alerts"},
        {"config_gear_thrust = any_thrust_lever_closed == 1 and simDR_radio_alt_height_capt < 800.0", "config_gear_thrust = any_thrust_lever_closed == 1", file = FLT, name = "N2 (WARN-3) no 800 ft"},
        {"config_gear_more = config_gear_more + 1", "config_gear_more = config_gear_more + 0", file = FLT, name = "N3 (WARN-3) no count"},
        {"rec.new, rec.silenced = true, false", "rec.new = rec.new", file = AM, name = "N4 (WARN-3) no new alert"},
    },
}
