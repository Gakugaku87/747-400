-- Run from the repository root with Lua 5.1 or LuaJIT.
-- XTLua gives 0 for the first read of a dataref in a script module: the
-- value only arrives on a later frame (X-Plane 2026-10-10: the autoland's
-- first read of vh_ind_fpm, at FLARE engagement, was 0). The modules keep
-- the datarefs they need at once fresh by reading them every frame
-- ("local refresh...=<dataref>" in the per-frame function). This suite checks
-- that the datarefs the fixes first read at a critical moment are among
-- those reads.
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

-- The text of a top-level function: from "function <name>(" to the first
-- line that is just "end".
local function function_body(path, name)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("\nfunction "..name.."(", 1, true), path..": no function "..name)
    local last = assert(source:find("\nend", first + 1, true), path..": no end of "..name)
    return source:sub(first, last)
end

-- Whether the body reads the dataref variable on its own: "= <name>" not
-- followed by more of an identifier.
local function reads(body, name)
    local start = 1
    while true do
        local a, b = body:find("=%s*"..name, start)
        if not a then return false end
        local after = body:sub(b + 1, b + 1)
        if not after:match("[%w_]") then return true end
        start = b + 1
    end
end

local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local cases = {
    -- [d] the CRZ ALT entry for the native FMS (B744.fms.step.lua
    -- native_cruise_altitude_entry) is formatted with the native transition
    -- altitude, read only at a CRZ ALT entry or change; a 0 fell back to
    -- 18000 ft for the first one of the session. The sync fault flag is read
    -- 0.5 s after its write, for the CDU message.
    {file=FMS.."B747.68.xt.fms.lua", func="after_physics",
        names={"simDR_fms_transition_alt", "B747DR_crzalt_sync_fault"}},
    -- [e] the LOC and G/S capture gates (B747_updateApproachHeading) read
    -- the localizer and glideslope signals, flags and deviations only once
    -- the approach is armed: LOC took a 0 as its first 1 s sample, and G/S
    -- was safe only because all its inputs read 0 together on that frame.
    {file=AP.."B747.70.xt.autopilot.monitor.lua", func="B747_monitorAP",
        names={"simDR_hsi_nav1_horizontal_signal", "simDR_hsi_nav2_horizontal_signal",
            "simDR_hsi_ldef_dots_nav1", "simDR_hsi_ldef_dots_nav2", "simDR_hsi_vdef_dots_pilot",
            "simDR_nav1_gs_flag", "simDR_nav2_gs_flag",
            "simDR_hsi_nav1_vertical_signal", "simDR_hsi_nav2_vertical_signal"}},
    -- [f] the flare law reads the flight-path vertical speed and the pitch
    -- rate from FLARE engagement on (start_flare and doPitch,
    -- B747.autoland.lua); preLand_measure runs every frame from 800 ft to the
    -- 50 ft flare height, so they are read there first.
    {file=AP.."B747.autoland.lua", func="preLand_measure",
        names={"simDR_local_vy", "simDR_pitch_rate_deg_sec"}},
    -- the hydraulics flight director's flap-change VS bias (get_FPM_bias)
    -- reads the flap handle only while it runs ALT, V/S, VNAV PTH or G/S; a 0
    -- as the reference would be taken as a whole flap extension at the next
    -- call of a V/S run (1.0 s later, after its first 0.5 s).
    {file="plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulics_override.lua",
        func="ap_pitch_assist", names={"B747DR_flap_ratio", "B747DR_flap_lever_detent"}},
}

for _, case in ipairs(cases) do
    local body = function_body(case.file, case.func)
    for _, name in ipairs(case.names) do
        check(reads(body, name), case.func.." in "..case.file.." does not read "..name.." every frame")
    end
end

-- The helpers themselves.
check(reads("  local refresh=simDR_x\n", "simDR_x"), "a refresh read is found")
check(not reads("  local refresh=simDR_x_y\n", "simDR_x"), "a longer name is not taken for the dataref")
check(not reads("  simDR_x=1\n", "simDR_x"), "a write is not a read")

print("XTLua warm read tests passed: "..checks)
