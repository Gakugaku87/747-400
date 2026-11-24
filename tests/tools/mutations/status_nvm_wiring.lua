-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- DSP-6 d): the EIUs' STATUS memory (the NVM model, its glue in the alerts
-- module, the alert model's order) broken one place at a time, the review's
-- mutants. Every one is caught by these tests (run it after a change to that
-- code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/status_nvm_wiring.lua
-- Of the review's fifteen, one is left out as it cannot be told apart: "the
-- first look counts an erase" (count_erases' "if on and last ~= nil and v >
-- last" made "if on and v > (last or 0)"). The first look at the ERASE
-- counters is always in B747_alerts_off (the EIUs start 4 s after their
-- power, B747.87.xt.warning.lua's powered starts false) and stores them, so
-- every look with the EIUs running has its last value
local MODEL = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.status_nvm_model.lua"
local GLUE = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.alerts.lua"
local AMODEL = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.alert_model.lua"
return {
    file = MODEL,
    tests = {
        "tests/warning/status_nvm_model_test.lua",
        "tests/warning/status_nvm_module_test.lua",
        "tests/warning/cmc_erase_page_test.lua",
    },
    mutations = {
        {'if class == "NVM-A" then return not on_ground end', 'if class == "NVM-A" then return on_ground == true end', name = "NVM-A latches on the ground"},
        {'if class == "NVM-G" then return on_ground == true end', 'if class == "NVM-G" then return not on_ground end', name = "NVM-G latches in the air"},
        {"if not cond then r.erased = false end", "if not cond then r.erased = r.erased end", name = "an erased occurrence stays hidden after its condition went"},
        {"if cond and not r.erased and M.latches(m.latch, on_ground) then r.latched = true end",
            "if cond and M.latches(m.latch, on_ground) then r.latched = true end", name = "an erased occurrence latches again"},
        {"if r.latched or (cond and not r.erased) then", "if r.latched or cond then", name = "an erased occurrence still shown"},
        {"r.latched, r.erased, r.seq = false, true, 0", "r.latched, r.erased, r.seq = false, false, 0", name = "erase does not hide the occurrence"},
        {"if not r.latched and not r.erased then nvm.rec[name] = nil end", "if not r.latched then nvm.rec[name] = nil end",
            name = "power off forgets the erasures"},
        {"if not r.latched and not r.erased then nvm.rec[name] = nil end", "nvm.rec[name] = nil",
            name = "power off forgets the latched ones"},
        {"nvm.order = function(a, b) return nvm.rec[a].seq < nvm.rec[b].seq end", "nvm.order = function(a, b) return nvm.rec[a].seq > nvm.rec[b].seq end",
            name = "the list newest first (the alert model wants oldest first)"},
        -- the glue
        {"local nvm_list = N.update(status_nvm, status_messages, status_flags, B747DR_alert_pseu_air == 0)",
            "local nvm_list = N.update(status_nvm, status_messages, status_flags, B747DR_alert_pseu_air == 1)", file = GLUE,
            name = "glue: air and ground swapped"},
        {"    N.power_off(status_nvm)\n", "", file = GLUE, name = "glue: no power_off when the EIUs stop (caught since 2026-11-24)"},
        {"    count_erases(false)\n", "    count_erases(true)\n", file = GLUE, name = "glue: erases counted while the EIUs are off"},
        {"function B747_status_nvm_reset()\n    status_nvm = N.new()", "function B747_status_nvm_reset()\n    status_nvm = status_nvm", file = GLUE,
            name = "glue: a new flight keeps the NVM"},
        {"        return status_now[a] > status_now[b]", "        return status_now[a] < status_now[b]", file = AMODEL,
            name = "alert model: same-update messages in the other order"},
    },
}
