-- Run from the repository root with LuaJIT: luajit tests/warning/status_nvm_model_test.lua
-- The EIUs' non-volatile memory of the EICAS STATUS messages
-- (plugins/xtlua/scripts/B747.87.xt.warning/B747.87.status_nvm_model.lua;
-- notes/ATA-31-warning.md §13): not latchable messages go with their
-- condition (LH_MAN p.52); NVM latches in the air or on the ground, NVM-A in
-- the air only, NVM-G on the ground only (LH_MAN p.78); a latched message
-- stays after its condition goes and through the EIUs' power loss, until
-- the CMC's ERASE (LH_MAN p.52, p.78; LH24 p.64), which also hides an
-- occurrence still there (LH24 p.64: DRIVE DISC with the IDG not reset);
-- the newest listed first (LH_MAN p.52: the model lists oldest first).
local T = dofile("tests/lib/check.lua")("status_nvm_model")
local N = dofile("plugins/xtlua/scripts/B747.87.xt.warning/B747.87.status_nvm_model.lua")

local MSGS = {
    {name = "HYDIM 1"},                                  -- not latchable
    {name = "HYD OVHT SYS 1", latch = "NVM-A"},
    {name = "DRIVE DISC 2", latch = "NVM"},
    {name = "TEST NVM-G", latch = "NVM-G"},
}
local function update(nvm, on, on_ground)
    local active = {}
    for i, m in ipairs(MSGS) do active[i] = on[m.name] == true end
    local shown = N.update(nvm, MSGS, active, on_ground)
    local copy = {}
    for i, n in ipairs(shown) do copy[i] = n end
    return copy
end
local function has(list, name)
    for _, n in ipairs(list) do if n == name then return true end end
    return false
end

-- the classes (LH_MAN p.78)
T.check(N.latches("NVM", true) and N.latches("NVM", false), "NVM latches on the ground and in the air")
T.check(not N.latches("NVM-A", true) and N.latches("NVM-A", false), "NVM-A latches in the air only")
T.check(N.latches("NVM-G", true) and not N.latches("NVM-G", false), "NVM-G latches on the ground only")
T.check(not N.latches(nil, true) and not N.latches(nil, false), "no class: never latches")

-- not latchable: goes with its condition (LH_MAN p.52)
do
    local nvm = N.new()
    local shown = update(nvm, {["HYDIM 1"] = true}, true)
    T.check(has(shown, "HYDIM 1"), "not latchable: shown with its condition")
    T.equal(N.state(nvm, "HYDIM 1"), N.SHOWN, "not latchable: state shown")
    shown = update(nvm, {}, true)
    T.check(not has(shown, "HYDIM 1"), "not latchable: gone with its condition")
    T.equal(N.state(nvm, "HYDIM 1"), N.NOT_SHOWN, "not latchable: state not shown")
end

-- NVM: latched on the ground, stays after the condition goes (LH24 p.64:
-- DRIVE DISC shown after the IDG reset), until ERASE
do
    local nvm = N.new()
    update(nvm, {["DRIVE DISC 2"] = true}, true)
    T.equal(N.state(nvm, "DRIVE DISC 2"), N.LATCHED, "NVM on the ground: latched")
    local shown = update(nvm, {}, true)
    T.check(has(shown, "DRIVE DISC 2"), "NVM: stays after its condition goes")
    shown = update(nvm, {}, false)
    T.check(has(shown, "DRIVE DISC 2"), "NVM: stays in the next flight")
    N.erase(nvm, "DRIVE DISC 2")
    shown = update(nvm, {}, true)
    T.check(not has(shown, "DRIVE DISC 2"), "NVM: ERASE removes it")
    T.equal(N.state(nvm, "DRIVE DISC 2"), N.NOT_SHOWN, "NVM: state after ERASE")
end

-- ERASE with the condition still there (LH24 p.64: the IDG not reset): gone,
-- and back (latched) only when the condition goes and comes again
do
    local nvm = N.new()
    update(nvm, {["DRIVE DISC 2"] = true}, true)
    N.erase(nvm, "DRIVE DISC 2")
    local shown = update(nvm, {["DRIVE DISC 2"] = true}, true)
    T.check(not has(shown, "DRIVE DISC 2"), "ERASE with the condition there: removed")
    shown = update(nvm, {["DRIVE DISC 2"] = true}, false)
    T.check(not has(shown, "DRIVE DISC 2"), "ERASE with the condition there: not latched again while it stays")
    update(nvm, {}, true)
    shown = update(nvm, {["DRIVE DISC 2"] = true}, true)
    T.check(has(shown, "DRIVE DISC 2"), "a new occurrence after ERASE: shown")
    T.equal(N.state(nvm, "DRIVE DISC 2"), N.LATCHED, "a new occurrence after ERASE: latched")
end

-- NVM-A: on the ground shown while there, not latched; in the air latched
-- (ATA29_32 p.100: HYD OVHT's STATUS in NVM in the air mode)
do
    local nvm = N.new()
    update(nvm, {["HYD OVHT SYS 1"] = true}, true)
    T.equal(N.state(nvm, "HYD OVHT SYS 1"), N.SHOWN, "NVM-A on the ground: shown, not latched")
    local shown = update(nvm, {}, true)
    T.check(not has(shown, "HYD OVHT SYS 1"), "NVM-A on the ground: gone with its condition")
    update(nvm, {["HYD OVHT SYS 1"] = true}, false)
    T.equal(N.state(nvm, "HYD OVHT SYS 1"), N.LATCHED, "NVM-A in the air: latched")
    shown = update(nvm, {}, false)
    T.check(has(shown, "HYD OVHT SYS 1"), "NVM-A in the air: stays after its condition goes")
    shown = update(nvm, {}, true)
    T.check(has(shown, "HYD OVHT SYS 1"), "NVM-A: still there after the landing")
    -- begun on the ground and still there after lift-off: latched in the air (estimate)
    nvm = N.new()
    update(nvm, {["HYD OVHT SYS 1"] = true}, true)
    update(nvm, {["HYD OVHT SYS 1"] = true}, false)
    T.equal(N.state(nvm, "HYD OVHT SYS 1"), N.LATCHED, "NVM-A: there at lift-off, latched in the air")
end

-- NVM-G: in the air not latched, on the ground latched
do
    local nvm = N.new()
    update(nvm, {["TEST NVM-G"] = true}, false)
    T.equal(N.state(nvm, "TEST NVM-G"), N.SHOWN, "NVM-G in the air: not latched")
    update(nvm, {}, false)
    T.equal(N.state(nvm, "TEST NVM-G"), N.NOT_SHOWN, "NVM-G in the air: gone with its condition")
    update(nvm, {["TEST NVM-G"] = true}, true)
    update(nvm, {}, true)
    T.equal(N.state(nvm, "TEST NVM-G"), N.LATCHED, "NVM-G on the ground: latched")
end

-- the EIUs' power loss: the NVM keeps the latched messages and their order,
-- the not latched ones are seen anew
do
    local nvm = N.new()
    update(nvm, {["DRIVE DISC 2"] = true}, false)
    update(nvm, {["DRIVE DISC 2"] = true, ["HYD OVHT SYS 1"] = true}, false)
    local shown = update(nvm, {["HYD OVHT SYS 1"] = true, ["HYDIM 1"] = true}, false)
    T.equal(table.concat(shown, ","), "DRIVE DISC 2,HYD OVHT SYS 1,HYDIM 1", "the list: oldest first")
    N.power_off(nvm)
    T.equal(N.state(nvm, "HYDIM 1"), N.NOT_SHOWN, "power off: the not latched message gone")
    shown = update(nvm, {}, true)
    T.equal(table.concat(shown, ","), "DRIVE DISC 2,HYD OVHT SYS 1", "power back: the latched ones in their order")
    -- an erasure outlives the power loss too (estimate)
    N.erase(nvm, "DRIVE DISC 2")
    update(nvm, {["DRIVE DISC 2"] = true}, true)
    N.power_off(nvm)
    shown = update(nvm, {["DRIVE DISC 2"] = true}, true)
    T.check(not has(shown, "DRIVE DISC 2"), "power back: an erased occurrence stays erased")
end

-- ERASE of what is not there does nothing
do
    local nvm = N.new()
    N.erase(nvm, "DRIVE DISC 3")
    local shown = update(nvm, {["DRIVE DISC 2"] = true}, true)
    T.equal(table.concat(shown, ","), "DRIVE DISC 2", "ERASE of another message: no effect")
end

T.done()
