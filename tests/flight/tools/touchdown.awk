# The flare and the touchdown of a flight-test recording (session.csv of
# B747_flighttest.lua, v11 for every figure; older ones leave some empty).
#   awk -F, -f tests/flight/tools/touchdown.awk <run>/session.csv
# FLARE: where it engaged (the pitch FMA 3), the pitch's lag behind the
# AFDS's command. Touchdown: the first frame on the ground (onground_any)
# under 20 ft of RA, the vertical speed (the flight model's), the pitch and
# its rate, the most g. After it: lift-offs (all wheels off the ground)
# within 5 s, the most nose-down pitch rate, the nose gear's arrival (the
# pitch under 0.5 degree), the PSEU's ground, the speedbrakes over half.
NR == 1 {
    for (i = 1; i <= NF; i++) col[$i] = i
    next
}
function v(name) { return (name in col) ? $(col[name]) : "" }
{
    n++
    t[n] = v("t") + 0; ra[n] = v("ra") + 0; pitch[n] = v("pitch") + 0; q[n] = v("q") + 0
    g[n] = v("gload") + 0; gnd[n] = v("on_ground") + 0; fma[n] = v("fma") + 0
    cmd[n] = v("pitch_cmd"); vsi[n] = v("vs_i"); sb[n] = v("sb_ratio"); pri[n] = v("pri_gnd")
    elev[n] = v("elevator_ratio") + 0
}
END {
    for (i = 2; i <= n; i++) if (gnd[i] == 1 && gnd[i - 1] == 0 && ra[i] < 20) { td = i; break }
    if (!td) { print "no touchdown"; exit 1 }
    for (i = 2; i <= td; i++) if (fma[i] == 3 && fma[i - 1] != 3) fl = i
    if (fl) {
        printf "FLARE   %.2f s before the touchdown, RA %.1f ft, pitch %.2f, VS %s fpm\n", t[td] - t[fl], ra[fl], pitch[fl], vsi[fl]
        lagmax = -99; lagsum = 0; k = 0
        for (i = fl; i < td; i++) if (cmd[i] != "") {
            d = cmd[i] - pitch[i]; lagsum += d; k++; if (d > lagmax) lagmax = d
        }
        if (k) printf "        command - pitch: mean %.2f, most %.2f degrees\n", lagsum / k, lagmax
    }
    gmax = 0
    for (i = td; i <= n && t[i] <= t[td] + 1; i++) if (g[i] > gmax) gmax = g[i]
    # the RA's rate over the last quarter second
    for (i = td; i > 1 && t[i] > t[td] - 0.25; i--) ;
    rarate = (t[td] > t[i]) ? (ra[td] - ra[i]) / (t[td] - t[i]) : 0
    printf "TOUCH   pitch %.2f (command %s), q %.2f deg/s, VS %s fpm, RA rate %.1f ft/s, most g %.2f (1 s)\n", pitch[td], cmd[td], q[td], vsi[td], rarate, gmax
    off = 0; offs = 0; offmax = 0; qmin = 0; nose = 0; prit = ""; sbt = ""; elevmin = 0
    for (i = td + 1; i <= n && t[i] <= t[td] + 8; i++) {
        dt = t[i] - t[i - 1]
        if (t[i] <= t[td] + 5) {
            if (gnd[i] == 0) { off += dt; if (gnd[i - 1] == 1) offs++; if (ra[i] > offmax) offmax = ra[i] }
        }
        if (q[i] < qmin) qmin = q[i]
        if (elev[i] < elevmin) elevmin = elev[i]
        if (!nose && pitch[i] < 0.5) { nose = i }
        if (prit == "" && pri[i] == 1 && pri[td] != 1) prit = t[i] - t[td]
        if (sbt == "" && sb[i] != "" && sb[i] + 0 > 0.5) sbt = t[i] - t[td]
    }
    printf "AFTER   lift-offs %d (%.2f s, RA up to %.2f ft) in 5 s; most nose-down %.2f deg/s; elevator down to %.2f\n", offs, off, offmax, qmin, elevmin
    if (nose) printf "        nose gear (pitch < 0.5) %.2f s after, q %.2f deg/s\n", t[nose] - t[td], q[nose]
    printf "        PSEU ground %s s after; speedbrakes over half %s s after\n", (prit == "" ? "-" : sprintf("%.2f", prit)), (sbt == "" ? "-" : sprintf("%.2f", sbt))
}
