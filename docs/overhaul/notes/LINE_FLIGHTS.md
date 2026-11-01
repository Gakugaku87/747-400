# 試験ラインフライト（通しの飛行）

離陸から着陸・停止までを一つの筋書きで飛び、系統どうしのつながりと、FCOM・FCTM の目安に合うかを見る。筋書きは `tests/flight/scenarios/`、記録は `tests/flight/runs/` と `Output/B747_flighttest/`。見つけたことは、直した段の notes と PROGRESS.md に移す。

## 1. s198：RJAA 34L → RJBB 06L（2026-11-01、1 回目）

- 筋書き（`s198_line_flight_rjaa_rjbb`）：RJAA 34L でエンジン運転中に始め、RTE（RJAA、RJBB、DIRECT XAC、DIRECT ATMUG）、ARR（STAR ATMUGA、ILS06LY、遷移 GATES）、PERF（ZFW 200、CRZ ALT FL250、COST INDEX 100）、TAKEOFF（フラップ 20、V 速度）。離陸、A/P CMD L、VNAV SPD・LNAV、フラップ上げ、11,000 ft の速度、FL250 の巡航、T/D の前に MCP 2,000 ft、降下、on approach の後の速度介入とフラップ、APP、LOC・G/S、LAND 3、フレア、接地、逆推力、ROLLOUT、停止。写真は PROGRESS の出発前、上昇と巡航の PFD・ND・PROGRESS、G/S の PFD。
- 結果：52/52（失敗・警告なし）。ただし途中で乗員の操作を 3 つ入れた（下の 4.）。Log.txt に Lua の誤りなし。
  - 離陸から巡航：VNAV SPD・LNAV、FL250 まで 642.9 s、巡航 35 分は FL250 の ±12 ft（7154 回の取得）。
  - 降下：T/D で相 3（VNAV PTH、A/T IDLE）、1 分後に -1,327 fpm。10,000 ft の下まで 556 s。
  - 進入と着陸：GATES の先で on approach、LOC 捕捉、G/S 捕捉、LAND 3、FLARE、接地は -454 fpm・151 kt・滑走路端から約 870 m、ROLLOUT で LOC のずれ 0.02〜0.04 ドット、スピードブレーキは接地で自動で UP、60 kt の後パーキング・ブレーキで停止。
- 見つけたこと（直す候補。記録 `Output/B747_flighttest/session.csv` の fvn_* の列で確かめた）：
  1. 10,000 ft を 291 kt で通過（VNAV の目標 240 kt）。FCOM p.1264 の 4 は「速度制限の高度の手前で目標速度にし、VNAV PTH のまま約 500 fpm で降りる」。今の経路（B747.68.pred_model.lua の descent_path）は制限の高度で水平に減速する（推定だった）。制限の高度を過ぎてから DRAG REQUIRED が出て、9,400 ft で水平にして減速した。
  2. T/D の水平の減速が無い。FCOM p.1264 の 2 は「T/D で降下の段に移り、ECON の降下速度へ高度を保って減速し、近づいてから降りる」。今は T/D で巡航の 333 kt のまま -2,700 fpm で降り始めた。
  3. T/D の直後、ATMUG での約 180° の旋回（バンク 25°、GS 420 kt）の間に、E/D までの距離（機体から今の点まで直線＋その先の残り：B747.68.xt.fms.lua の inp.d_ed）が 80.8 から 85.0 NM に増え、経路の下 2,000 ft として約 1 分水平に飛んだ。その後は経路の下約 360 ft を -1,650 fpm で降りた。旋回の弧を経路の距離に入れていないため（FMC は旋回に沿う）。経路そのもの（XAC から西の ATMUG へ行き、STAR で東へ折り返す）も、東から来る便には不自然。
  4. 進入で、VNAV の経路が G/S の約 0.6 ドット下を平行に降り、VNAV PTH のままでは G/S を捕捉しなかった。乗員の操作として V/S で G/S の下から近づけて捕捉した。
  5. 接地の -454 fpm はやや強い。停止後の EICAS に ENG 1〜4 REVERSER（逆推力の後で格納されていない）と >AUTOSTART OFF、FUEL PRESS CTR L・R。記録の始め（再読み込みの直後の約 2.6 秒）に EGT が 900〜2,566 になる値がある。いずれも原因はまだ調べていない。
  6. ND の S/C（ステップクライムの点）が巡航中に機体のすぐ前に出ていた（T/D まで 150 NM ほど）。
- 筋書きの誤り（次の回で直す）：
  - STAR ATMUGA は ATVID で終わり、ILS06LY の遷移 GATES とつながらず ROUTE DISCONTINUITY のまま降下した。RJBB の CIFP では ILS06LZ に ATVID の遷移がある（I06LZ）。今回は 17:02 に LEGS で DIRECT TO GATES（乗員の操作）を入れて続けた。
  - A/P を CMD L しか入れておらず、LAND 3 にならない。17:13 に CMD C と CMD R を入れた（FCOM の自動着陸の手順のとおり）。
  - 4. の V/S（17:11）。
- その後（2026-11-01、LF1：notes/ATA-34-61-FMC.md §123）：1. と 2. を直した（FCOM p.1264 の降下の減速と T/D の水平の減速）。4. は MCP の高度の手順（FCTM：G/S に乗ってからミスト・アプローチの高度。それまで MCP は会合高度か許可された高度）によるもので、VNAV の経路と X-Plane の G/S の約 0.6 ドットの差は、気圧（標準）と気温（ISA）では説明できず、まだ調べる。筋書きを 2 回目に向けて直した：ILS06LZ の遷移 ATVID（STAR とつながる）、MCP を T/D の前に STAR の 4,000 ft、on approach で ILS06LZ の会合高度 1,300 ft、G/S の捕捉でミスト・アプローチの 3,000 ft、APP の後に A/P CMD C・R。
