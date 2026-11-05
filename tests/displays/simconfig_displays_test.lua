-- Run from the repository root with LuaJIT: luajit tests/displays/simconfig_displays_test.lua
-- The SIM CONFIG's display selectors (plugins/xtlua/scripts/
-- B747.05.xt.simconfig/B747.05.xt.simconfig.lua, set_loaded_configs) as
-- XTLua runs it (tests/lib/xtlua.lua): each side's inboard and lower
-- display selectors from its own entries (capt_inbd, capt_lwr, fo_inbd,
-- fo_lwr). Review 2026-11-05: the F/O's inboard NORM and EICAS were read
-- from the Captain's capt_inbd.
local T = dofile("tests/lib/check.lua")("simconfig_displays")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
local sc = rt:load("plugins/xtlua/scripts/B747.05.xt.simconfig/B747.05.xt.simconfig.lua")
local FI = "laminar/B747/flt_inst/"
local function apply(ci, cl, fi, fl)
    local d = sc.ns.simconfig_values()
    d.SIM.capt_inbd, d.SIM.capt_lwr, d.SIM.fo_inbd, d.SIM.fo_lwr = ci, cl, fi, fl
    sc.ns.simConfigData["data"] = d
    sc.env.n = sc.ns
    sc.ns.set_loaded_configs()
end
local function sel(name) return rt:get(FI .. name .. "_display/sel_dial_pos") end

apply("NORM", "NORM", "PFD", "ND")
T.equal(sel("capt_inbd"), 1, "the Captain's inboard NORM")
T.equal(sel("capt_lwr"), 1, "the Captain's lower NORM")
T.equal(sel("fo_inbd"), 0, "the F/O's inboard PFD")
T.equal(sel("fo_lwr"), 0, "the F/O's lower ND")
apply("PFD", "ND", "EICAS", "EICAS PRI")
T.equal(sel("capt_inbd"), 2, "the Captain's inboard PFD")
T.equal(sel("capt_lwr"), 2, "the Captain's lower ND")
T.equal(sel("fo_inbd"), 2, "the F/O's inboard EICAS (before: not set, the Captain's PFD)")
T.equal(sel("fo_lwr"), 2, "the F/O's lower EICAS PRI")
apply("EICAS", "EICAS PRI", "NORM", "NORM")
T.equal(sel("capt_inbd"), 0, "the Captain's inboard EICAS")
T.equal(sel("capt_lwr"), 0, "the Captain's lower EICAS PRI")
T.equal(sel("fo_inbd"), 1, "the F/O's inboard NORM (before: the Captain's EICAS made it EICAS)")
T.equal(sel("fo_lwr"), 1, "the F/O's lower NORM")
T.done()
