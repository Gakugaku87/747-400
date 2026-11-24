-- A spec for tests/tools/mutate.lua (2026-11-24, the 2026-11-23 review's
-- NAV-4): the ADC's baro correction, X-Plane's altimeters' straight line
-- (B747.34.airdata_model.lua's baro_alt and pressure_alt), broken one place
-- at a time. Every one is caught by these tests (run it after a change to
-- that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/airdata_baro.lua
return {
    file = "plugins/xtlua/scripts/B747.34.xt.nav/B747.34.airdata_model.lua",
    tests = {
        "tests/nav/airdata_model_test.lua",
        "tests/nav/airdata_module_test.lua",
    },
    mutations = {
        {"M.FT_PER_INHG = 915", "M.FT_PER_INHG = 1000", name = "a thousand feet an inch"},
        {"M.FT_PER_INHG = 915", "M.FT_PER_INHG = 905", name = "the standard atmosphere's first inch"},
        {"return alt_std + (baro - M.STD_INHG) * M.FT_PER_INHG", "return alt_std - (baro - M.STD_INHG) * M.FT_PER_INHG", name = "the setting the wrong way"},
        {"return alt - (baro - M.STD_INHG) * M.FT_PER_INHG", "return alt", name = "the pressure altitude uncorrected"},
        {"M.STD_INHG = 29.92126", "M.STD_INHG = 29.92", name = "29.92 for 1013.25 hPa"},
    },
}
