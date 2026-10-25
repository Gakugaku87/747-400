-- 747-400 ND orientation, heading and track (5-2 step 5a): what each pilot's
-- ND shows from that side's sources (the Captain's and the F/O's X-Plane AHRS
-- standing for the IRUs, as on the PFD: step 4a): the display orientation
-- by mode, X-Plane's map mode (its own map layer, the weather radar returns,
-- turns with it), the compass rose shown, the TRK, HDG, MAP and VTK flags,
-- the current heading pointer, the selected heading bug and its dashed line
-- and the wind arrow. Logic and sources: docs/overhaul/notes/ATA-31.md §22
-- (FCOM p.1109-1110, p.1141-1143, p.1033-1034). Step 5b: the VOR mode's
-- reference VOR (§25: ATA34_1 p.356-369, FCOM p.1144-1146): its flag,
-- deviation, course, TO/FROM, frequency or identifier and DME.
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
    }
end

function M.inputs()
    return {
        side = {side_in(), side_in()},
        map_valid = true,   -- the FMC's position (an IRU in NAV: estimate)
        wind_from = 0,      -- the wind direction, magnetic
        hdg_sel = 0,        -- the MCP selected heading
        roll_mode = 0,      -- the AFDS's roll mode (FMA: 2 LNAV, 3 LOC, 4 ROLLOUT)
    }
end

local function side_out()
    return {
        up = 0,             -- the display's top: heading, track or 0 (north)
        xp_mode = M.XP_MAP, -- X-Plane's map mode
        rose = false,       -- the compass rose and the digital heading or track
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
    }
end

function M.new()
    return {out = {side_out(), side_out()}, line_t = M.HDG_LINE_S, last_sel = nil, last_roll = nil}
end

local function wrap(a) return (a + 180) % 360 - 180 end

-- the display's top (FCOM p.1109-1110, 109): MAP track up, VOR and APP
-- heading up, PLN north up (FCOM: true north; the stock map and symbols
-- are magnetic north up, kept until the heading reference, step 5d)
function M.orientation(mode, hdg, trk)
    if mode == M.MAP then return trk end
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
        o.up = M.orientation(mode, i.hdg, i.trk)
        o.xp_mode = (mode == M.MAP and M.XP_MAP) or (mode == M.PLN and M.XP_PLN) or M.XP_APP
        -- the orientation's source: the track in MAP, the heading in VOR and
        -- APP (PLN's rose is fixed, north up); failed, the flag at the
        -- top (FCOM p.1034: TRK in the MAP modes, HDG in VOR and APP)
        local track_up = mode == M.MAP or mode == M.PLN
        o.rose = (mode == M.MAP and i.trk_valid) or mode == M.PLN or (not track_up and i.hdg_valid)
        o.trk_flag = track_up and not i.trk_valid
        o.hdg_flag = not track_up and not i.hdg_valid
        -- the map and vertical track flags: the FMC's map data (estimate:
        -- its position, which needs an IRU in NAV)
        o.map_flag = track_up and not inp.map_valid
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
    end
    return s.out
end

return M
