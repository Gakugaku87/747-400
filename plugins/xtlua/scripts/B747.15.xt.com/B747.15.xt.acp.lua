-- The audio control panels in the aircraft (7-1b;
-- docs/overhaul/notes/ATA-23.md §12) on B747.15.acp_model.lua: the panels'
-- commands (transmitter selectors, receivers, volume knobs, the receiver
-- selectors and the filter), their MIC and receiver lights, and X-Plane's
-- audio panels: the Captain's panel the pilot's, the F/O's the copilot's
-- (X-Plane has two; the observer's panel is not heard). Before, all three
-- panels moved together on VHF L and R, the volume knobs and the receiver
-- selectors (COM-02), the VOR audio opened X-Plane's NAV1 and NAV2 (the ILS
-- receivers; the VORs are NAV3 and NAV4: COM-07), the APP selector opened
-- the markers only, and some knobs moved another panel's (COM-14).
-- Handlers by name: the com module registers the commands with them.
dofile("B747.15.acp_model.lua")
local AM = B747_acp_model
local acpState = AM.new()
local NS = getfenv(1)
local btnTarget = {}
-- the com module's button animation targets (a local table there)
function B747_acp_bind(btn) btnTarget = btn end

local XPA = "sim/cockpit2/radios/actuators/"
local XP_NAMES = {"audio_selection_com1", "audio_selection_com2", "audio_volume_com1", "audio_volume_com2",
    "audio_selection_nav1", "audio_selection_nav2", "audio_selection_nav3", "audio_selection_nav4",
    "audio_volume_nav1", "audio_volume_nav2", "audio_volume_nav3", "audio_volume_nav4",
    "audio_selection_adf1", "audio_selection_adf2", "audio_volume_adf1", "audio_volume_adf2",
    "audio_marker_enabled", "audio_volume_mark", "audio_com_selection_man", "audio_selection_com_auto"}
local XP_SIDE = {L = "", R = "_copilot"}
for seat, sfx in pairs(XP_SIDE) do
    for _, n in ipairs(XP_NAMES) do NS["simDR_acp_" .. seat .. "_" .. n] = find_dataref(XPA .. n .. sfx) end
end
simDR_acp_com1_freq = find_dataref(XPA .. "com1_frequency_hz_833")
simDR_acp_com2_freq = find_dataref(XPA .. "com2_frequency_hz_833")
B747DR_acp_vhf_C_active = find_dataref("laminar/B747/comm/vhf_C/active_khz")
-- X-Plane's receivers: the ILS L and R NAV1 and NAV2, the VOR L and R NAV3
-- and NAV4 (notes/ATA-34.md), the ADFs ADF1 and ADF2; no ILS C
local XP_NAV = {ils_L = "nav1", ils_R = "nav2", vor_L = "nav3", vor_R = "nav4", adf_L = "adf1", adf_R = "adf2"}

-- 121.500 on a VHF: heard everywhere, its receiver not off
local function held121()
    return {
        vhf_L = math.abs(simDR_acp_com1_freq - 121500) < 1,
        vhf_R = math.abs(simDR_acp_com2_freq - 121500) < 1,
        vhf_C = math.abs(B747DR_acp_vhf_C_active - 121500) < 1,
    }
end

-- the volume knobs' animation (30 to 330, as before) as X-Plane's ratio
local VOL_MIN, VOL_MAX = 30, 330
local function ratio(v) return math.max(0, math.min(1, (v - VOL_MIN) / (VOL_MAX - VOL_MIN))) end

-- the handlers
local BTN_BASE = {L = 0, C = 10, R = 20}
for _, seat in ipairs(AM.SEATS) do
    local pre = "B747_ap_" .. seat .. "_"
    local dr = "B747DR_ap_" .. seat .. "_"
    for i, ch in ipairs(AM.XMT) do
        local b = BTN_BASE[seat] + i - 1
        NS[pre .. ch .. "_xmt_sel_switch_CMDhandler"] = function(phase, duration)
            if phase == 0 then
                btnTarget[b] = 1
                AM.xmt(acpState, seat, ch)
            elseif phase == 2 then
                btnTarget[b] = 0
            end
        end
    end
    for _, ch in ipairs(AM.RCV) do
        NS[pre .. ch .. "_audio_sel_switch_CMDhandler"] = function(phase, duration)
            if phase == 0 then AM.rcv(acpState, seat, ch, held121()[ch]) end
        end
        local key = dr .. ch .. "_audio_vol"
        local function vol(d)
            return function(phase, duration)
                if phase == 0 or (phase == 1 and duration > 0.5) then
                    NS[key] = math.max(VOL_MIN, math.min(VOL_MAX, NS[key] + d))
                end
            end
        end
        NS[pre .. ch .. "_audio_vol_up_CMDhandler"] = vol(1)
        NS[pre .. ch .. "_audio_vol_dn_CMDhandler"] = vol(-1)
    end
    for _, sel in ipairs({{"vor_adf_rcvr", 3}, {"nav_filter", 2}, {"app_rcvr", 3}}) do
        local key = dr .. sel[1] .. "_sel_dial_pos"
        NS[pre .. sel[1] .. "_sel_dial_up_CMDhandler"] = function(phase, duration)
            if phase == 0 then NS[key] = math.min(NS[key] + 1, sel[2]) end
        end
        NS[pre .. sel[1] .. "_sel_dial_dn_CMDhandler"] = function(phase, duration)
            if phase == 0 then NS[key] = math.max(NS[key] - 1, 0) end
        end
    end
end

-- a new flight: no receiver by hand (ATA23 p.30: no transmitter at
-- power-up; the flight starts with the Captain's VHF L, as before)
function B747_acp_reset()
    acpState = AM.new()
    AM.xmt(acpState, "L", "vhf_L")
end

-- every frame: the lights and X-Plane's audio panels
local function flag(v) return v and 1 or 0 end
local sel = {}
function B747_acp_update()
    local held = held121()
    for _, seat in ipairs(AM.SEATS) do
        local p = acpState.seat[seat]
        local dr = "B747DR_ap_" .. seat .. "_"
        for _, ch in ipairs(AM.XMT) do NS[dr .. ch .. "_xmt_status"] = flag(p.xmt == ch) end
        for _, ch in ipairs(AM.RCV) do NS[dr .. ch .. "_audio_status"] = flag(p.man[ch]) end
    end
    for seat in pairs(XP_SIDE) do
        local x = "simDR_acp_" .. seat .. "_"
        local dr = "B747DR_ap_" .. seat .. "_"
        NS[x .. "audio_selection_com_auto"] = 0
        NS[x .. "audio_selection_com1"] = flag(AM.hears(acpState, seat, "vhf_L", held.vhf_L))
        NS[x .. "audio_selection_com2"] = flag(AM.hears(acpState, seat, "vhf_R", held.vhf_R))
        NS[x .. "audio_volume_com1"] = ratio(NS[dr .. "vhf_L_audio_vol"])
        NS[x .. "audio_volume_com2"] = ratio(NS[dr .. "vhf_R_audio_vol"])
        local xmt = acpState.seat[seat].xmt
        if xmt == "vhf_L" then NS[x .. "audio_com_selection_man"] = 6
        elseif xmt == "vhf_R" then NS[x .. "audio_com_selection_man"] = 7 end
        sel.vor_adf = NS[dr .. "vor_adf_rcvr_sel_dial_pos"]
        sel.app = NS[dr .. "app_rcvr_sel_dial_pos"]
        sel.filter = NS[dr .. "nav_filter_sel_dial_pos"]
        local na = AM.nav_audio(acpState, seat, sel)
        for rcv, xp in pairs(XP_NAV) do
            local ch = na[rcv]
            NS[x .. "audio_selection_" .. xp] = flag(ch)
            if ch then NS[x .. "audio_volume_" .. xp] = ratio(NS[dr .. ch .. "_audio_vol"]) end
        end
        NS[x .. "audio_marker_enabled"] = flag(na.mkr)
        if na.mkr then NS[x .. "audio_volume_mark"] = ratio(NS[dr .. "app_mkr_audio_vol"]) end
    end
end
