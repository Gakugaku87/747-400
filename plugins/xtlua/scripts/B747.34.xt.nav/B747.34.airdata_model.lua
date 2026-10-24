-- 747-400 air data without X-Plane (5-1 step 1): the three ADCs, the
-- AIR DATA source selection and its relays, each pilot's air data, OVERSPEED,
-- IAS DISAGREE, ALT DISAGREE, >SOURCE SEL ADC and the altitude alert.
-- Logic and sources: docs/overhaul/notes/ATA-34.md §3.1-§3.3, §4.1-§4.3
-- (FCOM p.800, p.803, p.992, p.1043, p.1197-1198, p.1557, p.1559; ATA34_1
-- 34-12 p.98-152, 34-16 p.178-196).
--
--   local A = B747_airdata_model            -- in XTLua, after dofile
--   local A = dofile(".../B747.34.airdata_model.lua")   -- in the tests
--   local s = A.new()
--   local inp = A.inputs()               -- fill it every frame
--   local out = A.update(s, inp, dt)     -- the same table every frame
--
-- ADCs 1 L, 2 C, 3 R. Altitudes in feet: each ADC's pressure altitude
-- (uncorrected, 29.92 in), corrected here with each pilot's baro setting.

local M = setmetatable({}, {})
B747_airdata_model = M

M.L, M.C, M.R = 1, 2, 3
M.VMO, M.MMO = 365, 0.92                -- OVERSPEED: Vmo/Mmo only (ATA34_1 p.140-143, FCOM p.1557)
M.IAS_DISAGREE_KT = 5                   -- five knots or more (FCOM p.1198)
M.ALT_DISAGREE_FT = 200                 -- more than 200 ft, uncorrected (FCOM p.1197)
M.DISAGREE_S = 5                        -- for more than five seconds
M.ADVISE_FT, M.CAPTURE_FT = 900, 300    -- the altitude alert (FCOM p.1559; ATA34_1 p.183-191)
M.STD_INHG = 29.92126
-- estimates (no values in the sources): how long the selected altitude must
-- stay still before the alert works again (the card's rate detector)
M.SEL_STILL_S = 1

local function three(v) return {v, v, v} end

function M.inputs()
    return {
        power = three(true),        -- L: standby bus, C: Capt transfer bus, R: F/O transfer bus
        fail = three(false),        -- an ADC failed
        cas = three(0),             -- each ADC's computed airspeed, kt
        mach = three(0),
        alt_std = three(0),         -- each ADC's pressure altitude, ft
        vs = three(0),              -- each ADC's altitude rate, fpm
        sel_capt = M.L,             -- the AIR DATA selectors (L/C/R)
        sel_fo = M.R,
        baro_capt = 29.92,          -- each pilot's baro setting, in Hg
        baro_fo = 29.92,
        -- the altitude alert
        mcp_alt = 0,                -- the MCP selected altitude
        fcc_cmd = 0,                -- the FCC in command: 1 L, 2 C, 3 R, 0 none or several
        gs_capture = false,
        landing_flaps = false,
        gear_down = false,          -- all gear down and locked (PSEU)
        ground = false,
        park_brake = false,
    }
end

local function side() return {src = 1, cas = 0, mach = 0, alt = 0, alt_std = 0, vs = 0, valid = false} end

function M.new()
    local s = {capt_relay = false, fo_relay = false, ias_t = 0, alt_t = 0,
        sel_alt = nil, sel_still = 0, captured = false}
    s.out = {capt_relay = false, fo_relay = false, capt_bus = M.L, fo_bus = M.R,
        valid = three(false), capt = side(), fo = side(),
        overspeed = false, ias_disagree = false, alt_disagree = false, source_sel_adc = false,
        alt_advise = false, alt_alert = false}
    return s
end

-- the altitude for a baro setting from a pressure altitude (standard atmosphere)
function M.baro_alt(alt_std, baro)
    local p = M.STD_INHG * (1 - alt_std / 145442.16) ^ (1 / 0.190263)
    return 145442.16 * (1 - (p / baro) ^ 0.190263)
end
-- and back: the pressure altitude from an altitude and its baro setting
function M.pressure_alt(alt, baro)
    local p = baro * (1 - alt / 145442.16) ^ (1 / 0.190263)
    return 145442.16 * (1 - (p / M.STD_INHG) ^ 0.190263)
end

-- the Mach number from a computed airspeed (kt) and a pressure altitude (ft),
-- standard atmosphere (for an ADC without a Mach output of its own)
function M.mach_from(cas, alt_std)
    local p0, a0 = 29.92126, 661.4786
    local p
    if alt_std <= 36089 then p = p0 * (1 - 6.8755856e-6 * alt_std) ^ 5.2558797
    else p = 0.2233609 * p0 * math.exp(-(alt_std - 36089) / 20806) end
    local qc = p0 * ((1 + 0.2 * (cas / a0) ^ 2) ^ 3.5 - 1)
    return math.sqrt(5 * ((qc / p + 1) ^ (2 / 7) - 1))
end

local function fill(o, inp, src, baro)
    o.src = src
    o.valid = inp.power[src] and not inp.fail[src]
    o.cas, o.mach, o.vs = inp.cas[src], inp.mach[src], inp.vs[src]
    o.alt_std = inp.alt_std[src]
    o.alt = M.baro_alt(inp.alt_std[src], baro)
end

function M.update(s, inp, dt)
    local out = s.out
    for i = 1, 3 do out.valid[i] = inp.power[i] and not inp.fail[i] end

    -- the source select relays (DC bus 3, latching): C on one side only, the
    -- first to select it holds it (each relay is powered through the other's
    -- non-C contact: ATA34_1 p.98-100)
    if inp.sel_capt ~= M.C then s.capt_relay = false end
    if inp.sel_fo ~= M.C then s.fo_relay = false end
    if inp.sel_capt == M.C and not s.fo_relay then s.capt_relay = true end
    if inp.sel_fo == M.C and not s.capt_relay then s.fo_relay = true end
    out.capt_relay, out.fo_relay = s.capt_relay, s.fo_relay
    -- the relays' buses (FCC L and C, the EECs, SRM, FCU, CPC, FMC L, ATC L,
    -- GPWC... on the captain's; FCC R and the right side's on the first
    -- officer's: p.111, p.113)
    out.capt_bus = s.capt_relay and M.C or M.L
    out.fo_bus = s.fo_relay and M.C or M.R
    -- the displays: the EIUs take all three ADCs and show the selected one
    -- (p.113); each pilot's baro on his own side (p.146)
    fill(out.capt, inp, inp.sel_capt, inp.baro_capt)
    fill(out.fo, inp, inp.sel_fo, inp.baro_fo)
    out.source_sel_adc = inp.sel_capt == inp.sel_fo        -- both on one ADC (FCOM p.1197)

    -- OVERSPEED: Vmo/Mmo from the ADCs (p.108), not the flap and gear placards
    local over = false
    for _, o in ipairs({out.capt, out.fo}) do
        if o.valid and (o.cas > M.VMO or o.mach > M.MMO) then over = true end
    end
    out.overspeed = over

    -- the disagree messages, after five seconds; only with both sides valid
    local both = out.capt.valid and out.fo.valid
    if both and math.abs(out.capt.cas - out.fo.cas) >= M.IAS_DISAGREE_KT then s.ias_t = s.ias_t + dt else s.ias_t = 0 end
    if both and math.abs(out.capt.alt_std - out.fo.alt_std) > M.ALT_DISAGREE_FT then s.alt_t = s.alt_t + dt else s.alt_t = 0 end
    out.ias_disagree = s.ias_t > M.DISAGREE_S
    out.alt_disagree = s.alt_t > M.DISAGREE_S

    -- the altitude alert (the crew alerting card): the left bus (L or C) with
    -- the FCC L or C in command, the right one with R; with none or several,
    -- the captain's switch (p.186, p.190). Approaching: 900 to 300 ft away;
    -- within 300 ft it captures; departing then by 300 to 900 ft: the alert,
    -- until back within 300, past 900 or a new selected altitude. Inhibited
    -- with the glideslope captured or landing flaps and the gear down and
    -- locked, but not on the ground with the parking brake set (a test:
    -- p.183-184, p.191-192; FCOM p.1559)
    local right = inp.fcc_cmd == M.R or (inp.fcc_cmd == 0 and inp.sel_capt == M.R)
    local bus = right and out.fo_bus or out.capt_bus
    local baro = right and inp.baro_fo or inp.baro_capt
    local valid = inp.power[bus] and not inp.fail[bus]
    local alt = M.baro_alt(inp.alt_std[bus], baro)
    if s.sel_alt == nil or inp.mcp_alt ~= s.sel_alt then
        s.sel_alt, s.sel_still, s.captured = inp.mcp_alt, 0, false
    else
        s.sel_still = s.sel_still + dt
    end
    local dev = math.abs(alt - inp.mcp_alt)
    local inhibit = (inp.gs_capture or (inp.landing_flaps and inp.gear_down)) and not (inp.ground and inp.park_brake)
    local still = s.sel_still >= M.SEL_STILL_S
    if dev < M.CAPTURE_FT then s.captured = true elseif dev > M.ADVISE_FT then s.captured = false end
    out.alt_advise = valid and still and not s.captured and dev >= M.CAPTURE_FT and dev <= M.ADVISE_FT
    out.alt_alert = valid and still and s.captured and not inhibit and dev >= M.CAPTURE_FT and dev <= M.ADVISE_FT
    return out
end

return M
