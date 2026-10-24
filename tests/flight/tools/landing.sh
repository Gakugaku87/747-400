#!/bin/bash
# A scripted approach and landing on RJAA 34L for the flight-test kit
# (docs/overhaul/TESTING.md §4.2). The A/P's APP does not capture the
# localizer yet (AFDS, PLAN 6-3), so the script flies by geometry through the
# Web API: HDG SEL on the cross-track from the runway centerline (apt.dat),
# V/S on the 3-degree glideslope (earth_nav.dat), flaps, gear and speedbrake
# ARM on the way, a hand flare from 40 ft RA (A/P and A/T off, thrust levers
# to idle), then reverse thrust for 8 s (X-Plane's reverse hold; let go,
# the 747's reverse levers stay at reverse idle, and the script puts them to
# forward idle 10 s after the reverse began, which stows them), regular brakes
# (X-Plane's toggle command: the gear module owns the brake ratios) and
# rudder on the centerline until the airplane stops. It starts the flight
# itself with landing_setup.json (run_scenario.ps1: 22 NM out at 3,000 ft and
# 190 kt, A/P CMD L) and writes landing.log and landing_result.txt into that
# run's folder.
#
#   bash tests/flight/tools/landing.sh [custom|stock|<acf path from the X-Plane folder>]
#   AUTOBRAKE=4 bash tests/flight/tools/landing.sh      (1-4 or MAX: the
#       autobrakes set on the approach, no manual brakes on the rollout; the
#       deceleration from 60 to 30 kt, with the reversers stowed, is checked
#       against the level's: ATA29_32 p.503. With reverse thrust the
#       deceleration is more than levels 1-2 ask for: FCOM p.1515)
#
# The checks at the end: no >SPEEDBRAKES EXT (FCOM p.958) or CONFIG GEAR
# (FCOM p.1603) at the flare, the speedbrake lever to UP after touchdown
# (FCOM p.951; within 4 s: the lever's actuator takes 2 s, an estimate), the
# touchdown and the stop on the runway. The touchdown limits are the
# script's, not the airplane's (estimates).
set -u
cd "$(dirname "$0")/../../.." || exit 2     # the aircraft folder
T=tests/flight/tools
API=http://localhost:8086/api/v2
# RJAA 34L: the threshold (apt.dat) and the glideslope (earth_nav.dat: IYQ
# 111.90, LOC 337 magnetic / 329.622 true, GS antenna at 139 ft abeam
# 0.181 NM past the threshold); the runway is 4,002 m long and 59.74 m wide
RWY="-v tla=35.7433335 -v tlo=140.3907120 -v crs=329.622 -v elev=139 -v gsoff=0.181"
RWY_LEN=4002; RWY_HALF=29
# the autobrakes: the selector (3-7 for 1-4 and MAX) and the deceleration, ft/s²
AB=${AUTOBRAKE:-}; AB_DIAL=; AB_DECEL=
case "$AB" in 1) AB_DIAL=3; AB_DECEL=4.0;; 2) AB_DIAL=4; AB_DECEL=5.0;; 3) AB_DIAL=5; AB_DECEL=6.0;;
  4) AB_DIAL=6; AB_DECEL=7.5;; MAX) AB_DIAL=7; AB_DECEL=11.0;; "") ;; *) echo "AUTOBRAKE: 1-4 or MAX"; exit 2;; esac

# ---- the start: run_scenario.ps1 prints "result: <run folder>  (pass ...)" last
res=$(powershell -NoProfile -ExecutionPolicy Bypass -File tests/flight/run_scenario.ps1 \
    -Scenario "$(cygpath -w "$T/landing_setup.json")" -Acf "${1:-custom}" | tee /dev/stderr | sed -n 's/^result: \(.*\)  (pass.*/\1/p')
[ -n "$res" ] || { echo "landing: the start scenario gave no result"; exit 1; }
RUN=$(cygpath -u "$res"); LOG="$RUN/landing.log"; : > "$LOG"

did() { curl -s -m 3 "$API/datarefs?filter%5Bname%5D=$1&fields=id" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
cid() { curl -s -m 3 "$API/commands?filter%5Bname%5D=$1&fields=id" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
g() { curl -s -m 2 "$API/datarefs/$1/value" | sed 's/{"data"://; s/}$//'; }
# writes by id, in parallel: pw id value [id value ...]
pw() { local a=(-Z) n=0; while [ $# -ge 2 ]; do [ $n = 0 ] || a+=(--next); n=1
    a+=(-s -m 2 -o /dev/null -X PATCH -H "Content-Type: application/json" -d "{\"data\":$2}" "$API/datarefs/$1/value"); shift 2; done; curl "${a[@]}"; }
ci() { curl -s -m 3 -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"duration\":${2:-0}}" "$API/command/$1/activate"; }
log() { echo "[${SECONDS}s] $*" | tee -a "$LOG"; }
for v in IAS:laminar/B747/gauges/indicators/airspeed_kts_pilot RA:sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot \
 LAT:sim/flightmodel/position/latitude LON:sim/flightmodel/position/longitude EL:sim/flightmodel/position/elevation \
 PSI:sim/flightmodel/position/psi TH:sim/flightmodel/position/theta VS:sim/flightmodel/position/vh_ind_fpm \
 GND:laminar/B747/gear/air_ground/pri_gnd SB:laminar/B747/flt_ctrls/speedbrake_lever GS:sim/flightmodel/position/groundspeed \
 MPSI:sim/flightmodel/position/mag_psi SERVO:laminar/B747/autopilot/servos_on CAUT:laminar/B747/CAS/caution_status \
 WARN:laminar/B747/CAS/warning_status HSEL:laminar/B747/autopilot/heading/degrees VSEL:sim/cockpit2/autopilot/vvi_dial_fpm \
 VSEL2:laminar/B747/cockpit2/autopilot/vvi_dial_fpm ALTD:laminar/B747/autopilot/heading/altitude_dial_ft IASD:laminar/B747/autopilot/ias_dial_value \
 FLAP:sim/cockpit2/controls/flap_ratio YP:sim/cockpit2/controls/yoke_pitch_ratio YH:sim/cockpit2/controls/yoke_heading_ratio \
 THR:sim/cockpit2/engine/actuators/throttle_ratio_all PARK:laminar/B747/flt_ctrls/parking_brake_ratio \
 TJR:sim/cockpit2/engine/actuators/throttle_jet_rev_ratio_all \
 ABS:laminar/B747/gear/autobrakes/sel_dial_pos MEMO:laminar/B747/CAS/memo_status; do eval "ID_${v%%:*}=$(did ${v#*:})"; done
for v in YD:laminar/B747/autopilot/button_switch/yoke_disengage_capt ATD:laminar/B747/authrottle_disarm \
 VSM:laminar/B747/autopilot/button_switch/vs_mode GEAR:sim/flight_controls/landing_gear_down \
 SBD1:sim/flight_controls/speed_brakes_down_one REV:sim/engines/thrust_reverse_hold \
 BRK:sim/flight_controls/brakes_toggle_regular; do eval "C_${v%%:*}=$(cid ${v#*:})"; done
# the reads in parallel (X-Plane answers about one request per frame on a
# connection), each to its own file
mkdir -p "$RUN/rd"; RDA=(); k=0
for i in $ID_IAS $ID_RA $ID_LAT $ID_LON $ID_EL $ID_PSI $ID_TH $ID_VS $ID_GND $ID_SB $ID_GS; do RDA+=(-o "$RUN/rd/$k" "$API/datarefs/$i/value"); k=$((k+1)); done
rd() { local k x; curl -s -m 2 -Z --parallel-max 16 "${RDA[@]}"; V=()
    for k in 0 1 2 3 4 5 6 7 8 9 10; do x=$(<"$RUN/rd/$k"); x=${x#\{\"data\":}; V+=("${x%\}}"); done; }

SECONDS=0; state=lateral; last=-5; cfg=0; ttd=-1; integ=0; th0=0; tprev=$EPOCHREALTIME
servo=$(g $ID_SERVO); sbext=-; cfggear=-; vs_td=-; am_td=-; xm_td=-; t_up=-; am_stop=-; xm_stop=-; ab_memo=-; t_rev=; t60=; ab_decel=-
mv=$(awk -v a="$(g $ID_PSI)" -v b="$(g $ID_MPSI)" 'BEGIN{d=a-b; if (d > 180) d -= 360; if (d < -180) d += 360; print d}')
log "start: A/P servos $servo, true - magnetic $mv"
pw $ID_FLAP 0.5 $ID_IASD 180; log "-> flaps 10, 180 kt"
while [ $SECONDS -lt 1200 ]; do
  rd 2>/dev/null; tn=$EPOCHREALTIME
  ias=${V[0]}; ra=${V[1]}; la=${V[2]}; lo=${V[3]}; el=${V[4]}; psi=${V[5]}; th=${V[6]}; vs=${V[7]}; gnd=${V[8]}; sb=${V[9]}; gs=${V[10]}
  read along cross alt path am xm integ h vv yp yh f20 f25 f30 fgs ffl fst gskt <<< "$(awk $RWY -v la=$la -v lo=$lo -v el=$el -v ra=$ra -v vs=$vs \
    -v gs=$gs -v psi=$psi -v th=$th -v integ=$integ -v tn=$tn -v tprev=$tprev -v th0=$th0 -v mv=$mv -f $T/landing_step.awk)"; tprev=$tn
  if [ $SECONDS -ge $((last + 5)) ] || [ $state = flare ]; then
    log "$state ias ${ias:0:5} ra ${ra:0:6} alt $alt path $path along $along NM cross $xm m psi ${psi:0:5} vs ${vs:0:6} pitch ${th:0:5} sb ${sb:0:5} gnd $gnd"; last=$SECONDS; fi
  case $state in
  lateral|descend)
    if [ $state = descend ]; then pw $ID_HSEL $h $ID_VSEL $vv $ID_VSEL2 $vv; else pw $ID_HSEL $h; fi
    if [ $cfg = 0 ] && [ $f20 = 1 ]; then pw $ID_FLAP 0.6667 $ID_IASD 170; cfg=1; log "-> flaps 20, 170 kt"; fi
    if [ $cfg = 1 ] && [ $f25 = 1 ]; then ci $C_GEAR; pw $ID_FLAP 0.8333 $ID_IASD 160; cfg=2; log "-> gear down, flaps 25, 160 kt"; fi
    if [ $cfg = 2 ] && [ $f30 = 1 ]; then pw $ID_FLAP 1.0 $ID_IASD 150; ci $C_SBD1; cfg=3; sleep 0.5; log "-> flaps 30, 150 kt, speedbrake ARM (lever $(g $ID_SB))"
      if [ -n "$AB" ]; then pw $ID_ABS $AB_DIAL; log "-> autobrakes $AB"; fi; fi
    # the MCP altitude at its minimum, 0 ft: at 100 ft the A/P began to
    # capture it some 200 ft above, over the threshold, and the airplane floated
    if [ $state = lateral ] && [ $fgs = 1 ]; then
      pw $ID_ALTD 0; sleep 0.3; ci $C_VSM; sleep 0.5; pw $ID_VSEL -800 $ID_VSEL2 -800; state=descend; log "-> descend at along $along NM"; fi
    if [ $state = descend ] && [ $ffl = 1 ]; then
      ci $C_YD; ci $C_ATD; pw $ID_THR 0; th0=$th; state=flare
      sbext=$(g $ID_CAUT | tr -d '[]' | cut -d, -f60); cfggear=$(g $ID_WARN | tr -d '[]' | cut -d, -f4)
      [ -n "$AB" ] && ab_memo=$(g $ID_MEMO | tr -d '[]' | cut -d, -f$AB_DIAL)     # memo AUTOBRAKES 1-4, MAX: slots 2-6
      log "-> flare at RA $ra vs $vs pitch $th; >SPEEDBRAKES EXT $sbext CONFIG GEAR $cfggear${AB:+; autobrakes memo $ab_memo}"; fi;;
  flare)
    pw $ID_YP $yp
    if [ "$gnd" = "1.0" ] || [ "$gnd" = "1" ]; then
      pw $ID_YP 0; ci $C_YD; state=touchdown; ttd=$SECONDS; vs_td=$vs; am_td=$am; xm_td=$xm
      log "-> touchdown vs $vs ias $ias: $am m past the threshold, $xm m from the centerline (+ right)"; fi;;
  touchdown|rollout)
    pw $ID_YH $yh
    if [ "$t_up" = - ] && awk -v s=$sb 'BEGIN{exit !(s >= 0.99)}'; then t_up=$((SECONDS - ttd)); log "speedbrake lever UP $t_up s after touchdown"; fi
    if [ $state = touchdown ] && [ $SECONDS -ge $((ttd + 2)) ]; then
      if [ -n "$AB" ]; then ci $C_REV 8; log "-> reverse 8 s, the autobrakes"
      else ci $C_REV 8; ci $C_BRK; log "-> reverse 8 s and regular brakes"; fi
      t_rev=$SECONDS; state=rollout; fi
    # the reverse levers to forward idle: the reversers stow
    if [ $state = rollout ] && [ -n "$t_rev" ] && [ $SECONDS -ge $((t_rev + 10)) ]; then
      pw $ID_TJR 0; t_rev=; log "-> reverse levers to forward idle at ${gskt} kt"; fi
    # the deceleration from 60 to 30 kt, the reversers stowed
    if [ $state = rollout ] && [ -z "$t_rev" ] && [ -z "$t60" ] && awk -v g=$gskt 'BEGIN{exit !(g <= 60)}'; then t60=$tn; fi
    if [ $state = rollout ] && [ -n "$t60" ] && [ "$ab_decel" = - ] && awk -v g=$gskt 'BEGIN{exit !(g <= 30)}'; then
      ab_decel=$(awk -v a=$t60 -v b=$tn 'BEGIN{printf "%.2f", 30 * 1.68781 / (b - a)}'); log "deceleration 60-30 kt: $ab_decel ft/s²"; fi
    if [ $state = rollout ] && [ $fst = 1 ]; then
      if [ -n "$AB" ]; then pw $ID_ABS 1 $ID_PARK 1 $ID_YH 0; else ci $C_BRK; pw $ID_PARK 1 $ID_YH 0; fi
      am_stop=$am; xm_stop=$xm
      log "stopped: speedbrake lever $sb, $am m past the threshold, $xm m from the centerline"; break; fi;;
  esac
  sleep 0.1
done
log "end: state $state"

# ---- the checks
pass=0; fail=0
check() { if awk "BEGIN{exit !($2)}" 2>/dev/null; then echo "PASS $1"; pass=$((pass + 1)); else echo "FAIL $1"; fail=$((fail + 1)); fi; }
{
  check "A/P CMD L at the start (servos $servo)" "\"$servo\" == \"1.0\" || \"$servo\" == \"1\""
  check "no >SPEEDBRAKES EXT at the flare, lever ARM (FCOM p.958) ($sbext)" "\"$sbext\" == \"0.0\" || \"$sbext\" == \"0\""
  check "no CONFIG GEAR at the flare, gear down (FCOM p.1603) ($cfggear)" "\"$cfggear\" == \"0.0\" || \"$cfggear\" == \"0\""
  check "touchdown on the runway: 150-1500 m past the threshold, within 20 m of the centerline (estimate) ($am_td m, $xm_td m)" \
    "\"$am_td\" != \"-\" && $am_td + 0 >= 150 && $am_td + 0 <= 1500 && ($xm_td + 0 <= 20 && $xm_td + 0 >= -20)"
  check "touchdown sink under 600 fpm (estimate) ($vs_td fpm)" "\"$vs_td\" != \"-\" && $vs_td + 0 > -600"
  check "speedbrake lever UP within 4 s of touchdown (FCOM p.951) ($t_up s)" "\"$t_up\" != \"-\" && $t_up + 0 <= 4"
  check "stopped on the runway ($am_stop m, $xm_stop m)" \
    "\"$am_stop\" != \"-\" && $am_stop + 0 < $RWY_LEN && ($xm_stop + 0 <= $RWY_HALF && $xm_stop + 0 >= -$RWY_HALF)"
  if [ -n "$AB" ]; then
    check "autobrakes $AB armed at the flare: the memo (ATA29_32 p.530) ($ab_memo)" "\"$ab_memo\" == \"1.0\" || \"$ab_memo\" == \"1\""
    check "the deceleration from 60 to 30 kt, reversers stowed, within 1.5 ft/s² of $AB_DECEL (ATA29_32 p.503; the margin an estimate) ($ab_decel)" \
      "\"$ab_decel\" != \"-\" && $ab_decel + 0 >= $AB_DECEL - 1.5 && $ab_decel + 0 <= $AB_DECEL + 1.5"
  fi
  echo "landing: pass $pass, fail $fail"
} | tee "$RUN/landing_result.txt"
grep -q "fail 0$" "$RUN/landing_result.txt"
