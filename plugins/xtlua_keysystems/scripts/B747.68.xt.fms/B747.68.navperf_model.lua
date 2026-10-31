-- The FMC's position updating and navigation performance (6-1/6-2 step
-- 10a; notes/ATA-34-61-FMC.md §86): the sensor that updates the FMC
-- position, the ACTUAL navigation performance (ANP), the required (RNP),
-- UNABLE RNP and the messages. Logic and sources:
--  - the priority (FCOM p.1241): LOC and GPS, LOC and DME-DME, LOC and
--    VOR/DME, LOC, GPS, DME-DME, VOR/DME, IRS. GPS: a GPS's valid data,
--    not inhibited by POS REF's GPS NAV, its ACTUAL not twice the RNP
--    (FCOM p.1368-1369). LOC updating's conditions (FCOM p.1241). The FMC
--    needs the IRS (FCOM p.1240): no FMC position without it.
--  - DME-DME: two DMEs whose bearings are 30-150 degrees apart; below
--    12,500 ft the best pair, above it the one nearest 90 degrees
--    (FMSPG p.26-27); in reach by the database's range (its figure of
--    merit: FMSPG p.27). VOR/DME: a tuned VOR and its DME (FCOM p.1240).
--  - POS REF 2/3's source in its 1L title, NAV STA (FCOM p.1368-1369;
--    ATA34_2 p.517); the ND's update lines (FCOM p.1150).
--  - RNP: takeoff 1.00, oceanic/remote 12.00, domestic 2.00, terminal
--    1.00, approach .50 nm (ATA34_2 p.517); an entry 0.01-99.9, the
--    default back with DELETE (FCOM p.1368); VERIFY RNP ENTRY: the entry
--    over the default or under the ANP (FCOM p.1436); VERIFY RNP: the
--    default changes with an entry over the new one (FCOM p.1435).
--  - UNABLE RNP: the ANP over the RNP; an advisory outside the approach, a
--    caution in it; not in the polar region (FCOM p.1430; LH3460 p.114).
--  - PURGE: CONFIRM replaces the FMC position with the mixed IRS position,
--    the updating goes on (FCOM p.1368; FMSPG p.75).
--  - polar operation (FCOM p.1241-1242): from 84 degrees north or south,
--    split IRS (SPLIT IRS OPERATION) without radio updating, until back
--    within 83.5; GPS updating stops from 88.5 until back within 88.0.
-- Estimates (none in the sources): guidance flies X-Plane's position (the
-- IRUs do not drift: B747.34.xt.irs.lua), so the FMC position is that and
-- this is what the FMC would show for it. The ANP: GPS 0.05 nm (FCOM
-- p.1367's page); a DME's error (one sigma) sqrt(0.05^2 + max(0.085,
-- 0.00125 d)^2) nm and a VOR's 1 degree, the ANP two sigmas, DME-DME's
-- over the sine of the stations' angle; with no better source the ANP
-- grows at 10 nm in six hours in the air (FCTM p.61: an FMC without GPS
-- meets RNP 10 six hours after its last radio update), from 0.10 nm when
-- the IRS starts navigating; a better source's at once. A DME in reach:
-- the database's range, the radio horizon, not over 45 degrees above;
-- VOR/DME within 25 nm. The RNP's phases: approach on the approach
-- (B747.68.xt.fms.lua's on_approach), takeoff on the ground, terminal
-- within 30 nm of the origin or the destination, oceanic/remote with no
-- VOR or DME within 200 nm, domestic else. PURGE: no updating for 10 s.
-- Not made: the back course's LOC updating (12 nm), VERIFY POSITION and
-- PURGE UPDATES (no position disagrees), the TO/GA position update (the
-- ANP does not grow on the ground), IRS NAV ONLY (an RNP option FMC).
--
--   local M = B747_navperf_model          -- in XTLua, after dofile
--   local s = M.new()
--   local out = M.update(s, inp)          -- about once a second

local M = setmetatable({}, {})
B747_navperf_model = M

-- the update sources, in FCOM p.1241's order
M.LOC_GPS, M.LOC_DD, M.LOC_VD, M.LOC = "LOC_GPS", "LOC_DD", "LOC_VD", "LOC"
M.GPS, M.DD, M.VD, M.IRS = "GPS", "DD", "VD", "IRS"
-- the RNP's phases and their defaults (ATA34_2 p.517)
M.TAKEOFF, M.OCEANIC, M.DOMESTIC, M.TERMINAL, M.APPROACH = "TAKEOFF", "OCEANIC", "DOMESTIC", "TERMINAL", "APPROACH"
M.RNP = {TAKEOFF = 1.00, OCEANIC = 12.00, DOMESTIC = 2.00, TERMINAL = 1.00, APPROACH = 0.50}
M.RNP_MIN, M.RNP_MAX = 0.01, 99.9           -- an entry (FCOM p.1368)
M.GPS_STOP = 2                              -- no GPS updating with its ACTUAL twice the RNP (FCOM p.1368)
M.DD_ANGLE_MIN, M.DD_ANGLE_MAX = 30, 150    -- FMSPG p.26
M.DD_LOW_FT = 12500
M.POLAR_IN, M.POLAR_OUT = 84, 83.5          -- FCOM p.1241-1242
M.GPS_POLAR_OFF, M.GPS_POLAR_ON = 88.5, 88.0
-- estimates
M.ANP_GPS = 0.05
M.ANP_ALIGN = 0.10
M.IRS_RATE = 10 / 6                         -- nm an hour in the air
M.VOR_SIGMA = 1                             -- degrees
M.VD_MAX_NM = 25
M.LOS_K = 1.23                              -- nm per sqrt(ft): the radio horizon
M.TERMINAL_NM = 30
M.OCEANIC_NM = 200
M.PURGE_HOLD_S = 10

function M.new()
    return {
        anp = nil,              -- the FMC's (nil: no FMC position)
        irs_anp = nil,          -- the mixed IRS position's
        src = nil, gps = nil,   -- the source, GPS's side ("L", "R")
        rnp_man = nil,          -- the crew's RNP
        dflt = nil, phase = nil,
        verify = false,         -- VERIFY RNP
        gps_inhibit = false,    -- POS REF's GPS NAV
        purge = false,          -- PURGE pushed, CONFIRM showing
        hold = 0,               -- seconds without updating after CONFIRM
        polar = false, gps_polar = false,
        out = {},
    }
end

function M.inputs()
    return {
        dt = 1,                 -- seconds since the last update
        ground = true,
        lat = 0,
        irs = false,            -- an IRU navigating
        gps_l = false, gps_r = false,
        dd = nil,               -- the DME-DME pair (M.dd_pair)
        vd = nil,               -- the VOR/DME: {ident, dist, anp}
        loc = false,            -- LOC updating's conditions (M.loc_ok)
        approach = false,       -- on the approach
        d_term = nil,           -- nm to the nearer of the origin and the destination
        navaid_near = true,     -- a VOR or DME within M.OCEANIC_NM
    }
end

-- the angle between two bearings, 0-180
local function angle(a, b) return math.abs((a - b + 180) % 360 - 180) end
M.angle = angle

-- a DME's range error, one sigma (estimate)
local function dme_sigma(d)
    local air = math.max(0.085, 0.00125 * d)
    return math.sqrt(0.05 * 0.05 + air * air)
end
-- the ANP of DME-DME with the stations d1 and d2 nm away, their bearings
-- `ang` degrees apart, and of a VOR/DME d nm away (estimates)
function M.anp_dd(d1, d2, ang)
    local s1, s2 = dme_sigma(d1), dme_sigma(d2)
    return 2 * math.sqrt(s1 * s1 + s2 * s2) / math.sin(math.rad(ang))
end
function M.anp_vd(d)
    local s, v = dme_sigma(d), d * math.sin(math.rad(M.VOR_SIGMA))
    return 2 * math.sqrt(s * s + v * v)
end

-- a DME in reach: `d` nm away, its database range, the airplane at `alt`
-- ft and the station at `elev` ft (estimates)
function M.dme_ok(d, range, alt, elev)
    local h = math.max(alt or 0, 0)
    local e = math.max(elev or 0, 0)
    if range and d > range then return false end
    if d > M.LOS_K * (math.sqrt(h) + math.sqrt(e)) then return false end
    return d >= math.max(h - e, 0) / 6076.12
end

-- the DME-DME pair from the stations in reach ({ident, dist, brg}, the
-- bearing from the airplane): their bearings 30-150 degrees apart; below
-- 12,500 ft the least ANP, above it the angle nearest 90 degrees (FMSPG
-- p.26). {a, b, angle, anp} or nil
function M.dd_pair(cands, alt)
    local best, key
    local low = (alt or 0) < M.DD_LOW_FT
    for i = 1, #cands - 1 do
        local a = cands[i]
        for j = i + 1, #cands do
            local b = cands[j]
            local ang = angle(a.brg, b.brg)
            if ang >= M.DD_ANGLE_MIN and ang <= M.DD_ANGLE_MAX then
                local anp = M.anp_dd(a.dist, b.dist, ang)
                local k = low and anp or (math.abs(ang - 90) + anp * 1e-3)
                if not key or k < key then best, key = {a = a, b = b, angle = ang, anp = anp}, k end
            end
        end
    end
    return best
end

-- LOC updating (FCOM p.1241): `l` = {dest_rwy (the tuned localizer's the
-- destination runway's), alt_above (ft above the localizer), dist (nm
-- from it), brg_from (the bearing from it to the airplane), crs (its
-- course), track (the airplane's)}, all true
function M.loc_ok(l)
    if not (l and l.dest_rwy) then return false end
    if l.alt_above >= 6000 or l.dist >= 20 then return false end
    if angle(l.brg_from, l.crs + 180) >= 25 then return false end
    return angle(l.track, l.crs) < 45
end

-- the RNP's phase (estimates)
function M.phase(inp)
    if inp.approach then return M.APPROACH end
    if inp.ground then return M.TAKEOFF end
    if inp.d_term and inp.d_term <= M.TERMINAL_NM then return M.TERMINAL end
    if not inp.navaid_near then return M.OCEANIC end
    return M.DOMESTIC
end

function M.rnp(s) return s.rnp_man or s.dflt or M.RNP.TAKEOFF end

-- an RNP entry: "ok", "verify" (accepted, VERIFY RNP ENTRY) or "invalid";
-- DELETE the default back (FCOM p.1368, p.1436)
function M.enter_rnp(s, text)
    if text == "DELETE" then
        if not s.rnp_man then return "invalid" end
        s.rnp_man = nil
        return "ok"
    end
    if not (string.find(text, "^%d*%.?%d*$") and string.find(text, "%d")) then return "invalid" end
    local v = tonumber(text)
    if not v or v < M.RNP_MIN - 1e-9 or v > M.RNP_MAX + 1e-9 then return "invalid" end
    v = math.floor(v * 100 + 0.5) / 100
    s.rnp_man = v
    local dflt = s.dflt or M.RNP.TAKEOFF
    if v > dflt + 1e-9 or (s.anp and v < s.anp) then return "verify" end
    return "ok"
end

-- POS REF 2/3's GPS NAV (INHIBIT> and ENABLE>), PURGE and CONFIRM
function M.gps_nav(s) s.gps_inhibit = not s.gps_inhibit end
function M.purge(s) s.purge = true end
function M.purge_cancel(s) s.purge = false end
function M.confirm(s)
    if not s.purge then return end
    s.purge = false
    if s.irs_anp then s.anp = s.irs_anp end
    s.hold = M.PURGE_HOLD_S
end

local TITLE = {LOC_GPS = "LOC-GPS", LOC_DD = "LOC-DD", LOC_VD = "LOC-VD", LOC = "LOC",
    GPS = "GPS", DD = "RADIO", VD = "RADIO", IRS = "INERTIAL"}
local ND = {LOC_GPS = "LOCGPS", LOC_DD = "LOC DD", LOC_VD = "LOC VD", LOC = "LOC",
    GPS = "GPS", DD = "DD", VD = "VD", IRS = ""}

function M.update(s, inp)
    local out = s.out
    local dt = inp.dt or 0
    local grow = inp.ground and 0 or M.IRS_RATE * dt / 3600

    -- polar operation
    local alat = math.abs(inp.lat or 0)
    local wasPolar = s.polar
    if alat > M.POLAR_IN then s.polar = true elseif alat < M.POLAR_OUT then s.polar = false end
    if alat > M.GPS_POLAR_OFF then s.gps_polar = true elseif alat < M.GPS_POLAR_ON then s.gps_polar = false end
    out.split_event = s.polar and not wasPolar

    -- the RNP: VERIFY RNP when the default changes under an entry
    local phase = M.phase(inp)
    local dflt = M.RNP[phase]
    if s.dflt and dflt ~= s.dflt and s.rnp_man and s.rnp_man > dflt + 1e-9 then s.verify = true end
    if s.verify and not (s.rnp_man and s.rnp_man > dflt + 1e-9) then s.verify = false end
    s.dflt, s.phase = dflt, phase
    local rnp = M.rnp(s)

    -- the sensors: radio computation (with the IRS) goes on under GPS and
    -- after PURGE
    local radio = inp.irs and not s.polar
    local dd = radio and inp.dd or nil
    local vd = (radio and not dd) and inp.vd or nil
    if s.hold > 0 then s.hold = math.max(0, s.hold - dt) end
    local upd = inp.irs and s.hold <= 0
    local gps = nil
    if upd and not s.gps_inhibit and not s.gps_polar then
        if inp.gps_l then gps = "L" elseif inp.gps_r then gps = "R" end
        if gps and M.ANP_GPS >= M.GPS_STOP * rnp - 1e-9 then gps = nil end
    end
    local loc = upd and inp.loc
    local src, best = M.IRS, math.huge
    if gps then src, best = loc and M.LOC_GPS or M.GPS, M.ANP_GPS
    elseif upd and dd then src, best = loc and M.LOC_DD or M.DD, dd.anp
    elseif upd and vd then src, best = loc and M.LOC_VD or M.VD, vd.anp
    elseif loc then src = M.LOC end

    -- the ANPs: the IRS's from its start, the FMC's no better than its
    -- last and growing in the air, a better source's at once
    if inp.irs then
        s.irs_anp = (s.irs_anp or M.ANP_ALIGN - grow) + grow
        s.anp = math.min((s.anp or M.ANP_ALIGN - grow) + grow, best)
        s.src, s.gps = src, gps
    else
        s.irs_anp, s.anp, s.src, s.gps = nil, nil, nil, nil
        s.purge = false
    end

    out.src, out.anp, out.irs_anp = s.src, s.anp, s.irs_anp
    out.rnp, out.rnp_man, out.phase = rnp, s.rnp_man ~= nil, phase
    local t = s.src and TITLE[s.src] or ""
    if s.gps then t = t .. " " .. s.gps end
    out.title = t
    out.nd = s.src and ND[s.src] or ""
    if dd then
        out.sta_title, out.sta = "DME-DME", dd.a.ident .. " " .. dd.b.ident
    elseif vd then
        out.sta_title, out.sta = "VOR-DME", vd.ident
    else
        out.sta_title, out.sta = "NAV STA", ""
    end
    out.unable = s.anp ~= nil and s.anp > rnp + 1e-9 and not s.polar
    out.caution = out.unable and phase == M.APPROACH
    out.advisory = out.unable and phase ~= M.APPROACH
    out.verify = s.verify
    out.polar = s.polar
    return out
end

-- the CDU's numbers: 2.00, 12.00 (ATA34_2 p.517), the ANP 0.05 (FCOM p.1367)
function M.text(v)
    if not v then return "" end
    return string.format("%.2f", math.min(v, 99.99))
end

return M
