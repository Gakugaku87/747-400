#!/bin/bash
# Runs every flight-test scenario (tests/flight/scenarios/*.json) one after
# the other with run_scenario.ps1 on the custom acf, for the major milestones
# (docs/overhaul/TESTING.md §4; CLAUDE.md: all scenarios only then), and
# writes each one's result line into tests/flight/runs/run_all_<time>.txt.
# The landing tool is not included (bash tests/flight/tools/landing.sh).
#
#   bash tests/flight/tools/run_all.sh [first scenario name to start from]
set -u
cd "$(dirname "$0")/../../.." || exit 2     # the aircraft folder
OUT="tests/flight/runs/run_all_$(date +%Y%m%d_%H%M%S).txt"
start=${1:-}
started=0
[ -z "$start" ] && started=1
for f in tests/flight/scenarios/*.json; do
  name=$(basename "$f" .json)
  [ $started = 0 ] && [ "$name" = "$start" ] && started=1
  [ $started = 0 ] && continue
  t0=$SECONDS
  res=$(powershell -NoProfile -ExecutionPolicy Bypass -File tests/flight/run_scenario.ps1 \
      -Scenario "$(cygpath -w "$f")" -Acf custom 2>&1 | sed -n 's/^result: .*  (\(pass .*\))$/\1/p')
  echo "$name ${res:-no result} $((SECONDS - t0)) s" | tee -a "$OUT"
done
echo "done: $OUT"
