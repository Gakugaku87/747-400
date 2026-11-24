-- A spec for tests/tools/mutate.lua (2026-11-24, D of the 2026-11-23 review:
-- AFDS-7): the A/T's GE lever gain (cd1763c9), its THR's protections, the
-- no-TO inhibit (with AFDS-2's takeoff-roll-only and the AFDS's inhibit
-- after a touchdown) and their glue, broken one place at a time: the
-- review's fourteen (its two not caught then, the glue's engine type and the
-- inhibit never reset on the ground, caught since this day's tests; the
-- latter on AFDS-2's line) and four on AFDS-2. Every one is caught by these
-- tests (run it after a change to that code or its tests):
--   luajit tests/tools/mutate.lua tests/tools/mutations/at_wiring.lua
local A = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua"
local G = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
return {
    file = A,
    tests = {
        "tests/autopilot/at_model_test.lua",
        "tests/autopilot/at_spd_gain_test.lua",
        "tests/autopilot/at_cruise_gust_test.lua",
        "tests/autopilot/afds_glue_test.lua",
        "tests/autopilot/at_flight_start_test.lua",
        "tests/autopilot/spd_gust_test.lua",
    },
    mutations = {
        {"M.GE_K = {{0.688, 1.15}, {0.371, 2.31}, {0.214, 3.82}}", "M.GE_K = {{0.688, 1.15}, {0.371, 2.31}, {0.214, 2.31}}", name = "GE_K top point 2.31"},
        {"M.GE_K = {{0.688, 1.15}, {0.371, 2.31}, {0.214, 3.82}}", "M.GE_K = {{0.688, 2.0}, {0.371, 2.31}, {0.214, 3.82}}", name = "GE_K low point 2.0"},
        {"if inp.engine == 1 then g = g * ge_k(d) end", "if inp.engine == 2 then g = g * ge_k(d) end", name = "GE_K for the RR"},
        {"if d >= t[1][1] then return t[1][2] end", "if d >= t[1][1] then return 1 end", name = "ge_k 1 low"},
        {"return b[2] + (d - b[1]) * (a[2] - b[2]) / (a[1] - b[1])", "return b[2]", name = "ge_k flat above the last point"},
        {"i.engine = B747DR_ap_engine_type", "i.engine = 0", file = G, name = "glue: no engine type to the servo (caught since 2026-11-24)"},
        {"rate = math.min(limit, speed_rate(inp.ias, inp.accel, vmax, k, inp.flaps_up))", "rate = limit", name = "THR REF without the limit speed"},
        {"if want > 0 and rate < 0 and not s.ga then rate = 0 end", "if want > 0 and rate < 0 then rate = 0 end", name = "G/A's THR not reduced above 2,000 fpm"},
        {"local want = s.ga and M.GA_VS or", "local want = s.ga and 4000 or", name = "G/A 4,000 fpm"},
        {"if s.engaged and s.ga then", "if s.engaged then", name = "second-push THR REF without a first"},
        {"if inp.cas < M.STOP_KT then s.no_to, s.from_air = false, false end", "if inp.cas < M.STOP_KT then s.from_air = false end",
            name = "no_to never reset on the ground (caught since 2026-11-24)"},
        {"if inp.ra > M.MIN_RA then s.no_to = false end", "if inp.ra > M.MIN_RA then s.no_to = s.no_to end", name = "no_to not reset at 400 ft"},
        {"if s.engaged and inp.reverse then disengage(s, not inp.ground) end", "if s.engaged and inp.reverse then disengage(s, true) end", name = "reverse on the ground latches DISC"},
        {"s.mode, s.retard = M.IDLE, true", "s.mode, s.retard = M.IDLE, false", name = "retard at the full rate"},
        -- AFDS-2 (2026-11-24): the no-TO inhibit the takeoff's roll's only,
        -- the AFDS's inhibit after a touchdown
        {"if not s.engaged and inp.cas >= M.TO_ARM_KT and not s.from_air then s.no_to = true end",
            "if not s.engaged and inp.cas >= M.TO_ARM_KT then s.no_to = true end", name = "AFDS-2: a landing's roll sets no_to"},
        {"if inp.cas < M.STOP_KT then s.no_to, s.from_air = false, false end", "if inp.cas < M.STOP_KT then s.no_to = false end",
            name = "AFDS-2: from_air never reset (the next takeoff without no_to)"},
        {"        s.from_air = true\n", "", name = "AFDS-2: from_air never set"},
        {"i.toga_inhibit = afds.inhibit == true", "i.toga_inhibit = false", file = G, name = "glue: the AFDS's inhibit not to the A/T"},
    },
}
