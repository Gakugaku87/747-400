-- X-Plane's 747 at 150 kt, flaps 30, the gear down: its lateral and
-- directional motion fitted by tests/tools/lat_sysid.lua to
-- s115_rudder_steps (2026-10-30, sim time 1110 to 1222: the rudder steps
-- and the 10 degree turns; R2 0.999 for the sideslip, 0.88 roll, 0.96 yaw;
-- the yaw damper as it is, B747.19.xt.yaw_damper.lua, inside). Degrees and
-- seconds; X-Plane's signs: beta = heading - flown path (the nose right of
-- the path plus), P and R right plus, da the A/P's aileron ratio (right
-- plus, lag seconds behind), dr the rudder input (right pedal plus).
--   beta' = bb b + bp p + br r + bphi phi + bd dr
--   p'    = lb b + lp p + lr r + la da + ld dr
--   r'    = nb b + np p + nr r + na da + nd dr
return {bb = -0.0977, bp = -0.1078, br = 0.9788, bphi = -0.1189, bd = 0.5627,
    lb = 1.8173, lp = -0.8977, lr = 0.3936, la = 32.3421, ld = -3.7539,
    nb = -0.4216, np = 0.0349, nr = -0.2503, na = -0.4466, nd = 7.0881, lag = 0.15}
