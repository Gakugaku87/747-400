-- 747-400 ND orientation, heading and track (5-2 step 5a): what each pilot's
-- ND shows from that side's sources (the Captain's and the F/O's X-Plane AHRS
-- standing for the IRUs, as on the PFD: step 4a): the display orientation
-- by mode, X-Plane's map mode (its own map layer, the weather radar returns,
-- turns with it), the compass rose shown, the TRK, HDG, MAP and VTK flags,
-- the current heading pointer, the selected heading bug and its dashed line
-- and the wind arrow. Logic and sources: docs/overhaul/notes/ATA-31.md §22
-- (FCOM p.1109-1110, p.1141-1143, p.1033-1034). Step 5b: the VOR mode's
-- reference VOR (§25: ATA34_1 p.356-369, FCOM p.1144-1146): its flag,
-- deviation, course, TO/FROM, frequency or identifier and DME; the VOR and
-- ADF bearing pointers and the lower corner blocks (§26: FCOM p.1038-1040,
-- p.1144-1146, p.1034).
--
--   local N = B747_nd_model                -- in XTLua, after dofile
--   local N = dofile(".../B747.60.nd_model.lua")   -- in the tests
--   local s = N.new()
--   local inp = N.inputs()                 -- fill it every frame
--   local out = N.update(s, inp, dt)       -- the same table every frame

local M = setmetatable({}, {})
B747_nd_model = M

M.CAPT, M.FO = 1, 2
-- the ND mode selector (laminar/B747/nd/mode/<side>/sel_dial_pos)
M.APP, M.VOR, M.MAP, M.PLN = 0, 1, 2, 3
-- X-Plane's map modes (sim/cockpit2/EFIS/map_mode): APP heading up, MAP
-- track up, PLN north up
M.XP_APP, M.XP_MAP, M.XP_PLN = 0, 2, 4
-- the dashed line from the selected heading bug: in MAP with LNAV, LOC or
-- ROLLOUT engaged, removed 10 s after the selected heading moved (FCOM
-- p.1142)
M.HDG_LINE_S = 10
-- the wind arrow from 100 kt (the stock's IAS threshold, kept: estimate)
M.WIND_KT = 100
-- the EFIS control panel's VOR/ADF switches, left (VOR L, ADF L) and right
-- (VOR R, ADF R)
M.SW_OFF, M.SW_VOR, M.SW_ADF = 0, 1, 2
-- the POS switch's VOR radials (step 5c) on the map's scale: the selected
-- range is 465 pixels (the map symbols': B747.61.xt.nd.lua's 640 units);
-- where no DME distance, to the display's edge (estimate: the expanded
-- map's range arc ahead, within the display's sides from the airplane
-- symbol, nothing behind it, as the map's symbols; the centred map's
-- symbols' 250 units)
M.PX_PER_RANGE = 465
M.RAD_ARC_PX = 465
M.RAD_LEFT_PX, M.RAD_RIGHT_PX = 329, 348
M.RAD_CTR_PX = 250 / 640 * 465
-- the position trend vector (step 5e, FCOM p.1147): MAP and MAP CTR, from
-- the airplane symbol along the track, the positions at the end of 30, 60
-- and 90 s at the ground speed and the turn of the bank angle (a radius of
-- the ground speed squared over g tan bank), one 30 s segment for 10 NM,
-- two for 20, three beyond; each segment a dash over 70 % of it (estimate:
-- FCOM's figure), drawn as 3 straight pieces (the panel image's frames:
-- 1.5 pixels a step, 40)
M.TV_SEG_S = 30
M.TV_SEGS = 3
M.TV_DASH = 0.7
M.TV_PIECES = 3
M.TV_FRAME_PX, M.TV_FRAMES = 1.5, 40
M.TV_N = M.TV_SEGS * M.TV_PIECES
local G = 9.80665
local KT_MS = 1852 / 3600

local function side_in()
    return {
        mode = M.MAP,       -- the ND mode selector
        hdg = 0,            -- that side's heading, magnetic
        trk = 0,            -- that side's track, magnetic
        hdg_valid = true,   -- the PFD model's heading (step 4a)
        trk_valid = true,   -- the PFD model's track
        ias = 0,            -- that side's airspeed, kt
        center = false,     -- the CTR (centred) display
        wxr = false,        -- WXR selected on that side's EFIS control panel
        tfc = false,        -- TFC selected
        -- the reference VOR (that side's: the glue picks it)
        vor_fail = false,   -- failed or unpowered: its bearing, frequency and course invalid
        vor_auto = false,   -- autotuned by the FMC (else manually tuned, with a course)
        vor_rx = false,     -- its bearing received (else no computed data)
        vor_to_from = 0,    -- X-Plane's indication: 0 none, 1 TO, 2 FROM
        vor_dme_rx = false, -- its DME distance received
        dme_fail = false,   -- the DME failed
        sw = {M.SW_OFF, M.SW_OFF}, -- that side's VOR/ADF switches, left and right
        pos = false,        -- POS selected on that side's EFIS control panel
        range_nm = 40,      -- that side's selected range
        roll_deg = 0,       -- that side's bank angle, right wing down positive
    }
end

function M.inputs()
    return {
        side = {side_in(), side_in()},
        -- the bearing receivers, left and right (VOR L and R, ADF L and R)
        vor_ok = {true, true},          -- powered (X-Plane has no NAV3/4 failure)
        adf_ok = {true, true},          -- powered and not failed
        vor_brg_rx = {false, false},    -- the bearing received
        adf_brg_rx = {false, false},    -- the station received (its identifier)
        vor_rel = {0, 0},               -- relative bearings, degrees (X-Plane's)
        adf_rel = {0, 0},
        vor_dme_rx = {false, false},    -- the VORs' DME distance received
        vor_dme_nm = {0, 0},            -- their DME distances
        iru_nav = {false, false, false}, -- the IRUs L, C, R in NAV (a position)
        gps_ok = false,                 -- a GPS position
        map_valid = true,   -- the FMC's position (an IRU in NAV: estimate)
        wind_from = 0,      -- the wind direction, magnetic
        hdg_sel = 0,        -- the MCP selected heading
        roll_mode = 0,      -- the AFDS's roll mode (FMA: 2 LNAV, 3 LOC, 4 ROLLOUT)
        -- MAP track up: the airplanes built, the 109 (PW; RR as PW) and the
        -- 570 (GE: the user's choice, 2026-10-27); false is a 405's heading
        -- up, which no airplane uses
        track_map = true,
        gs_kt = 0,          -- the ground speed
    }
end

local function side_out()
    return {
        up = 0,             -- the display's top: heading, track or 0 (north)
        xp_mode = M.XP_MAP, -- X-Plane's map mode
        rose = false,       -- the compass rose and the digital heading or track
        box = 1,            -- the box at the top: 1 HDG, 2 TRK; in PLAN 3 HDG, 4 TRK
        trk_flag = false,
        hdg_flag = false,
        map_flag = false,
        vtk_flag = false,
        hdg_ptr = false,    -- the current heading pointer (APP, VOR, MAP)
        hdg_ptr_pln = false, -- the PLN one, on the north-up rose
        hdg_bug = false,    -- the selected heading bug
        hdg_line = false,   -- its dashed line
        trk_line = false,   -- the expanded track line
        wind = false,       -- the wind arrow
        wind_deg = 0,       -- the wind arrow's direction on the display
        -- the VOR mode
        vor_flag = false,   -- the VOR flag
        vor_dev = false,    -- the deviation bar and scale
        vor_crs = 0,        -- 0 none, 1 dashes, 2 the course and its pointer
        vor_ref = 0,        -- 0 none, 2 the frequency or identifier
        to_from = 0,        -- 0 none, 1 TO, 2 FROM
        vor_dme = 0,        -- 0 dashes, 1 the distance, 2 the DME flag
        -- the bearing pointers and the lower corner blocks, left and right
        ptr = {0, 0},       -- the pointer: 0 none, 1 VOR, 2 ADF
        brg = {0, 0},       -- its direction on the display, degrees
        rad = {0, 0},       -- the block: 0 none, 1 VOR, 2 ADF
        rad_flag = {false, false}, -- the receiver's flag instead of its name
        rad_dme = {0, 0},   -- the VOR block's DME: 0 dashes, 1 the distance, 2 the DME flag
        -- the POS switch
        pos_iru = {false, false, false}, -- the IRUs' positions
        pos_gps = false,    -- the GPS position
        pos_rad = {false, false}, -- the VOR L and R radials
        pos_rad_brg = {0, 0}, -- their direction on the display, degrees
        pos_rad_len = {0, 0}, -- their length, pixels
        pos_rad_tick = {false, false}, -- the tick mark at the DME distance (the end)
        pos_rad_radial = {0, 0}, -- the radial, 1 to 360
        -- the position trend vector's pieces: shown, middle (pixels from the
        -- airplane symbol, up the display's top), direction (degrees from
        -- the top) and the image's frame
        tv_show = {}, tv_x = {}, tv_y = {}, tv_rot = {}, tv_frame = {},
    }
end

-- the trend vector's pieces into o (tv_*): along an arc from the airplane
-- symbol, or straight below half a degree of bank; it starts along the
-- track, dir_deg from the display's top (0 track up; a 405's heading up
-- MAP: the drift)
local function arc_point(a, r, sign)
    if r == nil then return 0, a end
    return sign * r * (1 - math.cos(a / r)), r * math.sin(a / r)
end
function M.trend(o, on, gs_kt, roll_deg, range_nm, dir_deg)
    dir_deg = dir_deg or 0
    local cd, sd = math.cos(math.rad(dir_deg)), math.sin(math.rad(dir_deg))
    local segs = (range_nm <= 10 and 1) or (range_nm <= 20 and 2) or M.TV_SEGS
    local gs = math.max(0, gs_kt) * KT_MS
    local r, sign = nil, roll_deg < 0 and -1 or 1
    if math.abs(roll_deg) >= 0.5 and gs > 0 then r = gs * gs / (G * math.tan(math.rad(math.abs(roll_deg)))) end
    local seg = gs * M.TV_SEG_S                     -- metres a segment
    local px_m = M.PX_PER_RANGE / (range_nm * 1852)
    local n = 0
    for k = 0, M.TV_SEGS - 1 do
        local a0 = k * seg
        local step = seg * M.TV_DASH / M.TV_PIECES
        for j = 0, M.TV_PIECES - 1 do
            n = n + 1
            local x1, y1 = arc_point(a0 + j * step, r, sign)
            local x2, y2 = arc_point(a0 + (j + 1) * step, r, sign)
            local dx, dy = (x2 - x1) * px_m, (y2 - y1) * px_m
            local len = math.sqrt(dx * dx + dy * dy)
            o.tv_show[n] = on and k < segs and len >= M.TV_FRAME_PX / 2
            local mx, my = (x1 + x2) / 2 * px_m, (y1 + y2) / 2 * px_m
            o.tv_x[n], o.tv_y[n] = mx * cd + my * sd, my * cd - mx * sd
            o.tv_rot[n] = math.deg(math.atan2(dx, dy)) + dir_deg
            o.tv_frame[n] = math.max(0, math.min(M.TV_FRAMES - 1, math.floor(len / M.TV_FRAME_PX + 0.5) - 1))
        end
    end
end

function M.new()
    return {out = {side_out(), side_out()}, line_t = M.HDG_LINE_S, last_sel = nil, last_roll = nil}
end

local function wrap(a) return (a + 180) % 360 - 180 end

-- a radial's length to the display's edge in its direction (degrees from
-- the display's top), centred or expanded
function M.edge_px(dir, center)
    if center then return M.RAD_CTR_PX end
    local d = wrap(dir)
    if math.abs(d) > 90 then return 0 end
    local s = math.abs(math.sin(math.rad(d)))
    local side = d < 0 and M.RAD_LEFT_PX or M.RAD_RIGHT_PX
    if s * M.RAD_ARC_PX > side then return side / s end
    return M.RAD_ARC_PX
end

-- the display's top (FCOM p.1109-1110): MAP track up on the 109 (PW; RR as
-- PW: an estimate) and the 570 (GE), `track_map` (a 405's heading up when
-- false); VOR and APP heading up; PLN north up (FCOM: true north; the stock
-- map and symbols are magnetic north up, kept until the heading
-- reference, step 5d)
function M.orientation(mode, hdg, trk, track_map)
    if mode == M.MAP and track_map then return trk end
    if mode == M.PLN then return 0 end
    return hdg
end

function M.update(s, inp, dt)
    dt = dt or 0
    -- the selected heading moved or the roll mode changed: the dashed line
    -- shows again for 10 s (the stock also restarted it on a roll mode change)
    if s.last_sel ~= nil and (inp.hdg_sel ~= s.last_sel or inp.roll_mode ~= s.last_roll) then s.line_t = 0 end
    s.last_sel, s.last_roll = inp.hdg_sel, inp.roll_mode
    s.line_t = s.line_t + dt
    local lnav_loc = inp.roll_mode >= 2 and inp.roll_mode <= 4
    for p = M.CAPT, M.FO do
        local i, o = inp.side[p], s.out[p]
        local mode = i.mode
        local track_map = inp.track_map
        o.up = M.orientation(mode, i.hdg, i.trk, track_map)
        o.xp_mode = (mode == M.MAP and (track_map and M.XP_MAP or M.XP_APP)) or (mode == M.PLN and M.XP_PLN) or M.XP_APP
        -- the box at the top and the orientation's source: MAP and PLAN the
        -- track (the 109 and the 570, FCOM p.1141: TRK), else the heading
        -- (a 405: HDG in all modes); PLN's rose is fixed, north up. Failed,
        -- the flag at the top (FCOM p.1033-1034: TRK in the MAP modes, HDG
        -- in VOR and APP; a 405's HDG)
        local map_modes = mode == M.MAP or mode == M.PLN
        local by_trk = map_modes and track_map
        o.box = (mode == M.PLN and 2 or 0) + (by_trk and 2 or 1)
        o.rose = mode == M.PLN or (by_trk and i.trk_valid) or (not by_trk and i.hdg_valid)
        o.trk_flag = by_trk and not i.trk_valid
        o.hdg_flag = not by_trk and not i.hdg_valid
        -- the map and vertical track flags: the FMC's map data (estimate:
        -- its position, which needs an IRU in NAV)
        o.map_flag = map_modes and not inp.map_valid
        o.vtk_flag = mode == M.MAP and not inp.map_valid
        -- the current heading pointer (FCOM p.1142): MAP, MAP CTR, PLAN; in
        -- VOR and APP it stays under the heading box (FCOM p.1024's figures)
        o.hdg_ptr = mode ~= M.PLN and o.rose and i.hdg_valid
        o.hdg_ptr_pln = mode == M.PLN and o.rose and i.hdg_valid
        -- the selected heading: all modes but PLAN (FCOM p.1142)
        o.hdg_bug = mode ~= M.PLN and o.rose
        o.hdg_line = o.hdg_bug and not (mode == M.MAP and lnav_loc and s.line_t >= M.HDG_LINE_S)
        -- the expanded track line (FCOM p.1143, 109): MAP; VOR and APP with
        -- WXR or TFC on (the stock's rule); with a track
        o.trk_line = not i.center and o.rose and i.trk_valid
            and (mode == M.MAP or ((mode == M.VOR or mode == M.APP) and (i.wxr or i.tfc)))
        -- the wind arrow with respect to the display orientation (FCOM
        -- p.1142): where the wind blows to
        o.wind = i.ias >= M.WIND_KT and o.rose
        o.wind_deg = wrap(inp.wind_from + 180 - o.up)

        -- the VOR mode (ATA34_1 p.356-369): a failed receiver (invalid
        -- bearing, frequency and course) shows the VOR flag and removes the
        -- deviation, the TO/FROM, the course and the frequency (p.360,
        -- p.366); autotuned, the course is dashed and its pointer, the
        -- deviation and the TO/FROM go (p.368-369); without the bearing (out
        -- of range: no computed data) the deviation and the TO/FROM go
        -- (p.358)
        o.vor_flag = i.vor_fail
        o.vor_crs = i.vor_fail and 0 or (i.vor_auto and 1 or 2)
        o.vor_ref = i.vor_fail and 0 or 2
        o.vor_dev = not i.vor_fail and not i.vor_auto and i.vor_rx
        o.to_from = o.vor_dev and i.vor_to_from or 0
        -- the DME as in APP (FCOM p.1033-1034)
        o.vor_dme = i.dme_fail and 2 or (i.vor_dme_rx and 1 or 0)

        -- the VOR/ADF switches (FCOM p.1040): VOR shows the VOR pointer,
        -- frequency or identifier and DME, ADF the ADF pointer and
        -- frequency or identifier, in all modes except PLAN (FCOM p.1144
        -- lists PLAN for the pointers and omits APP: p.1040 and p.1145, the
        -- blocks, followed); a failed receiver's flag in its block (FCOM
        -- p.1034), the pointer only with the bearing (ATA34_1 p.358) and
        -- the heading it is drawn from
        local shown = mode ~= M.PLN
        for k = 1, 2 do
            local sw = shown and i.sw[k] or M.SW_OFF
            local vor, adf = sw == M.SW_VOR, sw == M.SW_ADF
            local ok = (vor and inp.vor_ok[k]) or (adf and inp.adf_ok[k])
            local rx = (vor and inp.vor_brg_rx[k]) or (adf and inp.adf_brg_rx[k])
            o.rad[k] = sw
            o.rad_flag[k] = sw ~= M.SW_OFF and not ok
            o.rad_dme[k] = vor and (i.dme_fail and 2 or (inp.vor_dme_rx[k] and 1 or 0)) or 0
            o.ptr[k] = (ok and rx and o.rose and i.hdg_valid) and sw or M.SW_OFF
            -- the bearing from the side's heading, on the display's top
            o.brg[k] = wrap((adf and inp.adf_rel[k] or inp.vor_rel[k]) + i.hdg - o.up)
        end

        -- the POS switch (FCOM p.1040, p.1145, p.1150), in MAP and MAP CTR:
        -- the IRU positions (each IRU in NAV) and the GPS position, drawn
        -- relative to the FMC's position (here all three are X-Plane's
        -- position: at the airplane symbol); the VOR raw data radials from
        -- the airplane to the CDU-tuned VORs (VOR L and R, the bearing
        -- received, drawn from that side's heading) with the radial, to the
        -- DME distance and its tick mark, else to the display's edge
        local pos = i.pos and mode == M.MAP
        for k = 1, 3 do o.pos_iru[k] = pos and inp.iru_nav[k] end
        o.pos_gps = pos and inp.gps_ok
        for k = 1, 2 do
            local on = pos and inp.vor_ok[k] and inp.vor_brg_rx[k] and o.rose and i.hdg_valid
            local brg = inp.vor_rel[k] + i.hdg
            o.pos_rad_brg[k] = wrap(brg - o.up)
            local radial = math.floor((brg + 180) % 360 + 0.5)
            o.pos_rad_radial[k] = radial == 0 and 360 or radial
            local edge = M.edge_px(o.pos_rad_brg[k], i.center)
            local dme = inp.vor_dme_rx[k] and not i.dme_fail
            local dme_px = dme and inp.vor_dme_nm[k] * M.PX_PER_RANGE / i.range_nm or math.huge
            o.pos_rad[k] = on and edge > 0
            o.pos_rad_len[k] = o.pos_rad[k] and math.min(dme_px, edge) or 0
            o.pos_rad_tick[k] = o.pos_rad[k] and dme and dme_px <= edge
        end
        -- the position trend vector (step 5e), along the track on the
        -- display (a 405's heading up MAP: turned by the drift)
        M.trend(o, mode == M.MAP and o.rose and i.trk_valid, inp.gs_kt, i.roll_deg, i.range_nm, wrap(i.trk - o.up))
    end
    return s.out
end

return M
