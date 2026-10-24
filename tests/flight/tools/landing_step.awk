# One control step of tests/flight/tools/landing.sh, all the arithmetic in
# one awk call (a process per step: Git Bash starts processes slowly).
# in:  the runway (tla, tlo: threshold; crs: true course; elev: glideslope
#      elevation, ft; gsoff: NM from the threshold to abeam the glideslope
#      antenna), the airplane (la, lo, el in m, ra in ft, vs in fpm, gs in
#      m/s, psi true, th pitch), the controller (integ, tn, tprev in s, th0
#      the pitch at the flare, mv true minus magnetic)
# out: along cross (NM: + past the threshold, + right of the centerline),
#      alt path (ft MSL), am xm (the same in m), integ, h (heading dial),
#      vv (V/S dial), yp (flare yoke), yh (rollout rudder), then 0/1 flags:
#      flaps 20, gear and flaps 25, flaps 30, glideslope, flare, stopped;
#      the groundspeed in kt
BEGIN {
  pi = atan2(0, -1); c = crs * pi / 180
  dn = (la - tla) * 60; de = (lo - tlo) * 60 * cos(tla * pi / 180)
  along = dn * cos(c) + de * sin(c); cross = -dn * sin(c) + de * cos(c)
  alt = el * 3.28084; path = elev + 318.4 * (gsoff - along)    # 3 degrees: 318.4 ft/NM
  xm = cross * 1852; am = along * 1852
  # the centerline: heading from the cross-track with an integral term;
  # whole degrees (XTLua's double datarefs refuse fractions over the Web API)
  dt = tn - tprev; if (dt < 0 || dt > 2) dt = 0
  integ += cross * dt; if (integ > 3) integ = 3; if (integ < -3) integ = -3
  corr = -(60 * cross + 2 * integ); if (corr > 30) corr = 30; if (corr < -30) corr = -30
  h = int(crs + corr - mv + 360.5); while (h >= 360) h -= 360
  # the glideslope: V/S for the 3-degree path at this groundspeed, plus the error
  v = -gs * 1.94384 * 5.31 + 3 * (path - alt); if (v > -200) v = -200; if (v < -1500) v = -1500
  vv = int(v / 50) * 50
  # the flare: a pitch target from a sink-rate target falling with height
  vt = -(90 + 5 * ra); dp = 0.015 * (vt - vs); if (dp < 0) dp = 0; if (dp > 4.5) dp = 4.5
  yp = 0.1 + 0.07 * (th0 + dp - th); if (yp < -0.1) yp = -0.1; if (yp > 0.45) yp = 0.45
  # the rollout: rudder pedals on the centerline
  te = psi - crs; if (te > 180) te -= 360; if (te < -180) te += 360
  yh = -0.008 * xm - 0.04 * te; if (yh > 0.3) yh = 0.3; if (yh < -0.3) yh = -0.3
  printf "%.4f %.4f %.1f %.1f %.0f %.1f %.5f %d %d %.3f %.3f %d %d %d %d %d %d %.1f\n", along, cross, alt, path, am, xm, integ, h, vv, yp, yh, \
    (along > -12.5), (along > -10.5), (along > -8.5), (path < alt + 50 && along > -11), (ra < 40), (gs < 3), gs * 1.94384
}
