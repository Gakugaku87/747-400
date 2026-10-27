-- A simple airplane for the LNAV tests (tests/fms/lnav_*_test.lua): its bank
-- after LNAV's command at 3 degrees a second at most, its turn from its
-- bank, the wind; the route sequenced as LNAV says.
--   local SIM = dofile("tests/lib/lnav_sim.lua")(N, R, P, L, VAR)
-- N, R, P, L the nav DB, route, path and LNAV models, VAR the magnetic
-- variation (degrees east).
return function(N, R, P, L, VAR)
    local RAD = math.pi / 180
    local M = {}
    local function var() return VAR end
    local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end

    -- an active route of `legs` starting at `start`
    function M.route(legs, start)
        local st = R.new(N, nil)
        st.rte.legs, st.rte.runway, st.active = legs, start, true
        return st
    end
    -- the airplane: {lat, lon, hdg (true), bank, tas (kt), alt, vs (fpm),
    -- wind_from (true), wind (kt), ground}
    function M.plane(t)
        t.bank, t.alt, t.vs, t.wind, t.wind_from = t.bank or 0, t.alt or 10000, t.vs or 0, t.wind or 0, t.wind_from or 0
        return t
    end
    function M.state(a)
        local vn = a.tas * math.cos(a.hdg * RAD) - a.wind * math.cos(a.wind_from * RAD)
        local ve = a.tas * math.sin(a.hdg * RAD) - a.wind * math.sin(a.wind_from * RAD)
        return {lat = a.lat, lon = a.lon, hdg = a.hdg, trk = (math.atan2(ve, vn) / RAD + 360) % 360,
            gs = math.sqrt(vn * vn + ve * ve), tas = a.tas, wind = a.wind, alt = a.alt, var = VAR, ground = a.ground or false}
    end
    -- fly `seconds` (steps of 0.1 s): the route sequenced as LNAV says;
    -- opts.engaged (default true), opts.armed, opts.engage_when_valid,
    -- opts.each(t, s, air, path) (true: stop), opts.path(st, path) LNAV's
    -- path from the route's (an offset's: step 7d).
    -- Returns the sequencing log
    function M.fly(st, s, a, seconds, opts)
        opts = opts or {}
        local engaged = opts.engaged ~= false
        local dt, log = 0.1, {}
        for k = 1, math.floor(seconds / dt + 0.5) do
            local r = st.rte
            local path = P.build(r.legs, R.leg_from(r, 1), {var = var, alt = a.alt})
            if opts.path then path = opts.path(st, path) end
            local air = M.state(a)
            local n = L.update(s, path, air, opts.armed or false, engaged)
            if opts.each and opts.each(k * dt, s, air, path) then break end
            -- the FCC engages an armed LNAV once its steering is valid
            if opts.engage_when_valid and not engaged and s.valid then engaged = true end
            if n > 0 then
                local e = path[1]
                local start = e.term ~= "fix" and {lat = a.lat, lon = a.lon} or nil
                if R.sequence(st, n, start) then
                    log[#log + 1] = {t = k * dt, lat = a.lat, lon = a.lon, alt = a.alt, e = e}
                end
            end
            local cmd = engaged and s.roll or 0
            a.bank = a.bank + clamp(cmd - a.bank, -3 * dt, 3 * dt)
            a.hdg = (a.hdg + 9.80665 * math.tan(a.bank * RAD) / (a.tas * 1852 / 3600) / RAD * dt) % 360
            local sa = M.state(a)
            local q = P.point(a, sa.trk, sa.gs * dt / 3600)
            a.lat, a.lon = q.lat, q.lon
            a.alt = a.alt + a.vs / 60 * dt
        end
        return log
    end
    return M
end
