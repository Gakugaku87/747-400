-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- AFDS-7): LNAV's fly-by turns (989e7acb, notes/ATA-34-61-FMC.md §171), the
-- roll in's lead and the roll out, broken one place at a time: the review's
-- fifteen (its five not caught then, the turn's end and the roll out's
-- conditions, caught since this day's lnav_model_test) and three on AFDS-6's
-- flaps out lag (lnav_model_test, vnav_turns_test for its glue). Every one is caught
-- by these tests (run it after a change to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/lnav_flyby.lua
local L = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua"
local P = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua"
local F = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua"
return {
    file = L,
    tests = {
        "tests/fms/lnav_model_test.lua",
        "tests/fms/path_model_test.lua",
        "tests/fms/vnav_turns_test.lua",
        "tests/fms/nd_line_model_test.lua",
    },
    mutations = {
        {"M.ROLL_LAG = 0.9", "M.ROLL_LAG = 0", name = "ROLL_LAG 0"},
        {"M.ROLL_LAG = 0.9", "M.ROLL_LAG = 2.0", name = "ROLL_LAG 2.0"},
        {"M.ROLLOUT_END = 2", "M.ROLLOUT_END = 10", name = "ROLLOUT_END 10 (caught since 2026-11-24)"},
        {"/ (2 * M.ROLL_RATE) + roll_lag(air)", "/ (2 * M.ROLL_RATE)", name = "entry lead without the lag"},
        {"* sign * RAD <= out then u.rollout = true end", "* sign * RAD <= out * 2 then u.rollout = true end", name = "roll out twice as early"},
        {"* sign * RAD <= out then u.rollout = true end", "* sign * RAD <= out * 0.5 then u.rollout = true end", name = "roll out half as early"},
        {"over = u.rollout and math.abs(air.bank) <= M.ROLLOUT_END", "over = u.rollout", name = "turn over at the roll out's start (caught since 2026-11-24)"},
        {"if u and u.rollout then s.roll = 0 end", "if u and u.rollout then end", name = "no wings level in the roll out"},
        {"local phi = math.min(math.abs(air.bank), 60) * RAD", "local phi = math.min(math.abs(air.bank), 10) * RAD", name = "bank capped at 10 for the roll out"},
        {" + G / v * math.tan(phi) * roll_lag(air)", "", name = "roll out without the lag's turn"},
        -- (2026-11-24, AFDS-6) the flaps out's shorter lag, and its glue
        {"M.ROLL_LAG_FLAPS = 0.5", "M.ROLL_LAG_FLAPS = 0.9", name = "flaps out: FL370's lag (before AFDS-6)"},
        {"if air and air.flaps_up == false then return M.ROLL_LAG_FLAPS end", "", name = "flaps out: no lag of its own"},
        {"flaps_up=simDR_fms_vnav_flaps<0.01}", "flaps_up=true}", file = F, name = "glue: LNAV never told the flaps are out"},
        {"if over or not engaged or math.abs(cx) > 2 then", "if over or not engaged then", name = "no 2 nm end of the turn (caught since 2026-11-24)"},
        {"if u and engaged and air.bank and not u.rollout then", "if u and air.bank and not u.rollout then", name = "roll out without LNAV engaged (caught since 2026-11-24)"},
        {"if air.bank * sign > 0 and wrap180", "if wrap180", name = "roll out without the bank's side (caught since 2026-11-24)"},
        {"M.TURN_BANK = 23", "M.TURN_BANK = 25", file = P, name = "TURN_BANK 25"},
        {"M.TURN_BANK = 23", "M.TURN_BANK = 20", file = P, name = "TURN_BANK 20"},
    },
}
