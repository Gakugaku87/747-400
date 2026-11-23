# 2026-11-23 のフルレビュー（段 4）：担当の報告（原文）

[REVIEW_2026-11-23.md](REVIEW_2026-11-23.md) の元になった、担当 11 体（Fable 5.2、effort xhigh、読むだけ）の最後のメッセージをそのまま並べたもの。対象は `overhaul` の `807956a2`。担当の作業用フォルダー（スクリプトと出力）は `D:\b747_review\stage4\a01_cdu` 〜 `a11_nav_misc`（リポジトリの外）。

親のセッションが 1 件ずつ確かめた結果（判定）は REVIEW_2026-11-23.md の表にある。ここの文は担当の見立てのままで、確かめで変わった所（PERF-1 の一部、FMC-9）は直していない。

# 第 1 波 担当 1：CDU のページ（CDU-n）

## 担当 1（CDU のページ）報告

対象は overhaul の HEAD 807956a2、カスタム acf です。リポジトリは変えていません。スクリプトと出力は `D:\b747_review\stage4\a01_cdu\` にあり、リポジトリの直下で `luajit D:/b747_review/stage4/a01_cdu/<名前>.lua` で回せます（`h.lua` が共通の土台、`t02`・`t03` はページのダンプ）。X-Plane では確かめていません。写真は 2026-11-22 02:55 の `s79_fmc_fixes` の回（段 1〜3 の後）のものです。

### 指摘

#### CDU-1 行選択キーの表が 3 台で 1 つで、左の CDU のキーが右の CDU のページの働きになる（型：外）
- **場所**：`B744.createfms.lua:293-297`（`fmsFunctionsDefs[page][key]` を引く）、`:409-418`（待ちが無ければすぐ `doKey`）。表は各ページの `getPage` が書く（`vnav.lua:280-290, 398-411, 576-590`、`rte.lua:83-88, 140-141`、`progress.lua:64-67, 357-364`）。描く順は L→C→R（`B747.68.xt.fms.lua:6478-6480`）。
- **何が起きるか**：2 台が同じ種類のページの別のページ番号を出していると、機長側のキーは最後に描いた右（か中央）のページの働きになる。
  - 左 DES・右 CRZ で左の 5R（FORECAST>）→ ENG OUT の MOD ができる（`eo.mod=ENG OUT`、ページは DES のまま）。
  - 左 CLB・右 DES で左の 2L に 280 → 降下の SEL SPD が 280 になり（`desspd=280`、mode S）、上昇は ECON のまま。
  - 左 RTE 2/2・右 RTE 1/2 で左の 1R（TO）に ZZAA → DEST の入力になり MOD RTE 1。
  - 左 CRZ・右 DES で左の 6R（LRC>）と 1L（CRZ ALT 270）→ KEY/FUNCTION INOP。
  - 左 PROGRESS 1/3・右 3/3 で左の 6R（POS REF>）→ KEY/FUNCTION INOP。
- **確かめ方**：`t10_two_cdus.lua`、`t10b_two_cdus.lua`（出力 `t10_out.txt`、`t10b_out.txt`）。
- **根拠**：FMSPG p.39・p.49（左右の CDU は別々に操作できる。ノートから）。LEGS の 6R だけは §42 で同じ原因を直してある（`legsr6`）。
- **重さ**：危ない（意図しない ENG OUT・DEST の MOD、別の段階の速度の書き換え）。確か。1 人で飛ぶと右の CDU を別の VNAV ページに置いたままにしやすい。
- **シナリオ案**：地上で経路と PERF INIT を入れる。右の CDU（`laminar/B747/fms2/...`）で MENU・<FMC・VNAV・NEXT（CRZ）、左で VNAV・NEXT・NEXT（DES）、左の R5。合格は左の題が DESCENT FORECAST で、右の題に MOD・E/O が無く EXEC 灯が消えていること。
- **直す案**：キーを押した CDU の `getPage` を引く直前に呼ぶ。または行選択キーを必ずその CDU の次の描画の直後（`keysAfterDrawing`）に回す。

#### CDU-2 乗員が CG を入れた便の flight complete の後、TAKEOFF REF が全行空白のまま戻らない（型 J。e682bb80 で後戻り）
- **場所**：`takeoff.lua:172-181`（179 行の `string.format("%2.0f%%", tonumber(cg_mac))`）、`B747.68.xt.fms.lua:5780-5805`（`cg_mac` は既定に戻すが `cg_lineLg` は残る）、`:636-642`。
- **何が起きるか**：CG を入れた便の後、次の便で TAKEOFF REF が題も含めて空白になる。4R に手探りで CG を入れるまで戻らない。
- **確かめ方**：`t01_cg_flight_complete.lua`。
  - HEAD（`t01_out.txt`）：flight complete の後 `cg_mac=[--]`・`cg_lineLg=[28%]`、`getPage` は 179 行で「number expected, got nil」。ZFW 230 を入れても空白、CG 25 を入れると戻る。
  - e682bb80 の 1 つ前（`mirror_before` に取り出した。`t01_out_before_e682bb80.txt`）：flight complete の直後は同じく空白だが、次の便の ZFW で戻る。
  - 潜んでいたのは段 10d（11-01）からで、e682bb80 が 109・570 で ZFW による `cg_mac` の書き直しをやめたため、戻らなくなった。
- **根拠**：FCOM p.1320 (11.40.44)「Initially displays dashes」、ATA34_2 p.540（flight completion で消える）。
- **重さ**：乗員に見える誤り（ターンアラウンドで離陸のページが使えない）。確か。
- **試験の穴**：`flight_complete_test`（14 件）と `wb_n19_test` は、CG を入れてからの flight complete を見ていない。
- **シナリオ案**：`s163_flight_complete` の着陸前に `["RTE","R6","22","R4"]`（進入中は 6R が TAKEOFF>）を足す。完了後に INIT REF・<INDEX・<TAKEOFF で `fms3/Line01_L` に「TAKEOFF REF」、`Line09_S` に「--%」。
- **直す案**：`B747_fms_flight_complete` で `cg_lineLg = ""`。描画は `tonumber` が nil ならダッシュにする。

#### CDU-3 DES の「FPA V/B V/S」がいつも □.□ □.□ □□□□（型 H）
- **場所**：`vnav.lua:592-600, 658, 760`。条件の書き手は `B747.70.xt.autopilot.lua:1414-1436`。
- **何が起きるか**：値を出す条件は `vnav_state==2 and vvi_status==2` だが、VNAV の engage で `vvi_status` は 0 にされ、VNAV でなければ `vnav_state` は 0 か 1 なので、成り立つことが無い。全型式でいつも伏せ字になる。
- **確かめ方**：`t02_pw.txt`・`t02_ge.txt`・`t03_pw.txt` の DES の 9 行目。写真 `shot_53_cdu_des.png` にも箱が写っている。条件が成り立たないことは読んだだけ。
- **根拠**：FCOM p.1390 (11.43.2)：109・405 の図にこの行は無い。p.1391・p.1393-1394：570 は 3R に WPT/ALT、4R は「Initially displays dashes」で、WPT/ALT を入れた後に値を出す。
- **重さ**：乗員に見える誤り。確か。
- **シナリオ案**：既定の P&W で DES を開き、`fms3/Line08_S` に「FPA」が無く `Line09_L` に `*` が無いこと。GE では `Line09_L` がダッシュ。
- **直す案**：P&W・RR では行と見出しを出さない。GE はダッシュにする（WPT/ALT を作るまで）。見出しは「SPD RESTR」にする（CDU-14）。

#### CDU-4 RTE HOLD の FIX ETA・HOLD AVAIL・BEST SPEED が固定のダッシュ（型 H）
- **場所**：`hold.lua:149, 153, 155`（「----.- 」「-+--」「---  」）。
- **何が起きるか**：ホールドの間も 3 つとも出ない。§33 の「予測（段 8）までダッシュ（推定）」のまま、段 8 の後も残った。PROGRESS.md の「次にやること」にも無い。
- **確かめ方**：読んだだけ。`t03_pw.txt` の HOLD のページにも出ている。`B747_perf_db.hold`（待機の速さと燃料流量）は VNAV が使っている（`xt.fms.lua:2411`）。
- **根拠**：FCOM p.1415 (11.43.27) の図「1439.5z」「270KT」、p.1417 の図「2+45」「220KT」、p.1419 の 8・10・11。
- **重さ**：乗員に見える誤り。確か。
- **シナリオ案**：`s92_hold` に足す。ホールド中に HOLD を開き、`Line11_L` の右が 200〜280 の数、`Line05_L` の右が時刻。
- **直す案**：BEST SPEED は `B747_perf_db.hold`、FIX ETA は予測か 1 周の時間、HOLD AVAIL は（燃料 − RESERVES − 目的地までの予測の燃料）÷ 待機の燃料流量。

#### CDU-5 APPROACH REF の 4R が、重いときに FMC 自身の VREF を受け付けない（型 F）
- **場所**：`B744.fms.pages.lua:1513`（`vref<110 or vref>180`。本家からの値で出典なし）。
- **何が起きるか**：1R・2R で下ろした FLAPS/VREF を 4R に入れると INVALID ENTRY になり、PFD に VREF が出ない。
- **確かめ方**：`t11_vref_range.lua`（`t11_out.txt`）。

  | GROSS WT | VREF25 | 4R | VREF30 | 4R |
  |---|---|---|---|---|
  | 340.0 t | 176 | 入る | 168 | 入る |
  | 360.0 t | 181 | INVALID ENTRY | 174 | 入る |
  | 380.0 t | 187 | INVALID ENTRY | 179 | 入る |
  | 396.8 t | 191 | INVALID ENTRY | 183 | INVALID ENTRY |

  軽い側（150 t で 115・112）は入る。
- **根拠**：FCOM p.1412 (11.43.24)：有効な入力は XX/YYY・/YYY・YYY で、範囲の記載は無い（上限は資料なし）。
- **重さ**：乗員に見える誤り（離陸直後の引き返し・重量超過の着陸）。確か。
- **シナリオ案**：空中で GROSS WT 380.0 を 1L、1R、4R。`airspeed/Vref` が 187 で、スクラッチパッドに INVALID ENTRY が無いこと。
- **直す案**：上限を 110〜180 から広げる（例：100〜250）。

#### CDU-6 24 桁を超える行：PROGRESS の 7 文字の点名、DES の 1 行目（型 G の読み替え）
- **場所**：`progress.lua:285`（`"%-5s   %4d ..."`）、`:439-441`、`vnav.lua:652`。
- **何が起きるか**：
  - PROGRESS：緯度経度の点（N35E140 の形）が TO・NEXT だと行が 26 桁になる。DTG・ETA・燃料が 2 桁右へずれ、小さい字の Z が ETA の 3 桁目に重なる。
  - DES：E/D と、速度つきの高度の窓の制限が並ぶと 26 桁。「150 RW16R 250/11000AFL150B」の末尾 2 文字が 24 桁の外で、「FL15」と読める。
- **確かめ方**：`t06_longname.lua`（`t06_out.txt`：5・7 行目が 26 文字）、`t07_des_width.lua`（`t07_out.txt`：3 行目が 26 文字）。
- **根拠**：FCOM p.1371 (11.42.27) の図（点名、DTG、ETA、燃料の桁）。7 文字の点名は p.1415 の例。
- **重さ**：乗員に見える誤り（洋上の経路、窓の制限の多い STAR）。桁数は確か。26 桁目が X-Plane で見えるかは未確認（25 桁目までは見える：`shot_137_cdu_perf_init.png` の CRZ CG の %）。
- **シナリオ案**：LEGS の 1L に `N3530.0E14030.0` を入れて EXEC、PROGRESS を撮る。`Line05_L` が 24 文字以下。
- **直す案**：PROGRESS は `"%-7s %4d %s  %s"`。DES は 24 桁に収まらなければ E/D の点名との空きを詰める。

#### CDU-7 重量の単位が LBS のとき、PERF INIT に入れた値が違う数で出る（型 F）
- **場所**：`B744.fms.pages.lua:1537`（ZFW）、`:1559`（RESERVES）：0.1 t の文字で持つ。`perfinit.lua:29-36`。
- **確かめ方**：`t09_lbs.lua`（`t09_out.txt`）。14 件中 9 件が違う。例：RESERVES 10→9.9、25→24.9、55.5→55.6。ZFW 480→479.9、485.3→485.2、512.7→512.8。
- **根拠**：FCOM p.1309-1311：入力は XXX.X で、入れた値が出る。
- **重さ**：乗員に見える誤り（LBS のときだけ）。確か。
- **直す案**：kg を数で持つか、入力の文字を表示用にも持つ。

#### CDU-8 TAKEOFF REF の WIND/SLOPE と POS SHIFT（型 I・H）
- **場所**：`takeoff.lua:156-160, 189`、`B744.fms.pages.lua:1651-1674`、既定値 `xt.fms.lua:780-782`。
- **何が起きるか**：
  - WIND/SLOPE：入力まで大きい字の「---/----」。§15 の「入れるまでダッシュ」の出典は p.1319 の 1 文だけ。
  - POS SHIFT：GE でも「--00M」（`t02_ge.txt`）。滑走路が無いと「RW***」の箱。
- **根拠**：
  - FCOM p.1317・p.1318 (11.40.41-42) の図は、何も入れていない状態で小さい字の「H00/U0.0」（p.1317 を絵にして確かめた）。FMSPG p.106 (3.2-46)「default values of H00/U0.0 in SMALL font」。
  - FCOM p.1318 の 570 の図は「--00FT」、p.1321 は 570 が 100 ft 単位。FMSPG p.108：滑走路の番号が出たとき 00FT か 00M が付く、m の範囲は ±30。コードは ±99 を受ける。
- **重さ**：軽い。確か（POS SHIFT の滑走路なしの出方は、たぶん）。
- **直す案**：既定を小さい字の H00/U0.0 にする。GE は FT にする。滑走路が無ければ行を空白にする。

#### CDU-9 TAKEOFF REF の値の残り方が逆（型 J）
- **場所**：`takeoff.lua:89-92, 172-222`、`B747.60.xt.fltInst02.lua:2265-2267`。
- **何が起きるか**：空中でも TRIM と CG が残る（`t04_out.txt` の E3：8,000 ft で「5.5 22%」）。フラップと選んだ V 速度は電波高度 1,000 ft で消える。
- **根拠**：FMSPG p.107 (3.2-47)「Center of gravity values are blanked when airborne」。ATA34_2 p.540：TRIM は離陸の後に空白、ほかの欄は空中でも持ち、flight completion で消える。
- **重さ**：軽い。たぶん（2 つの資料の文の読み）。

#### CDU-10 APPROACH REF の滑走路：ORIGIN と DEST が同じだと、50 NM の内で出発の滑走路に戻る（型 J。7b62803b の残り）
- **場所**：`approach.lua:59-68`（毎フレームの判定で、切り替えを覚えない。`from > to` が同じ空港では成り立たない）。
- **確かめ方**：`t04_misc.lua` の E2。ZZAA→ZZAA、進入 ILS16R。77.8 NM で「ZZAA16R」、18.7 NM に戻ると「ZZAA34L」。
- **根拠**：FCOM p.1411 (11.43.23)「Displays length of departure runway until ...」（切り替わったら戻らない読み）。
- **重さ**：軽い（引き返し・周回の飛行）。確か。
- **直す案**：切り替えたことを経路の状態に覚える（経路か進入が変わるまで）。

#### CDU-11 PERF INIT の CRZ CG（型 J、軽い）
- **場所**：`perfinit.lua:108-114, 127, 154`、`B744.fms.pages.lua:1573-1586`。
- **何が起きるか**：flight complete の後、既定の 20.0 が大きい字のまま（`t04_out.txt` の E1：`crzcg=[20.0]`、`crzcg_lineLg=[ 20.0%]`）。行は 25 文字で、% が 25 桁目に出る（写真 `shot_137`：ICAO の右端より 1 桁右）。
- **根拠**：FCOM p.1311 (11.40.35)「Default value, 20.0, displays in small font」。
- **直す案**：flight complete で `crzcg_lineLg = ""`。書式を `%4.1f%%` にする。

#### CDU-12 出典の無い「出さない」2 件（型 I）
- **INIT/REF INDEX の <TAKEOFF**（`B744.fms.pages.lua:206-214`）：空中で消す。FMSPG p.68 (3.2-8) の図 3.2-8（空中）では <TAKEOFF は残り、消えるのは MAINT> だけ（絵で確かめた）。ノートのページの表に差異として書いてあるが、GAP の番号は無い。
- **ATC INDEX の 6L**（e2326a5d で空白にした）：FCOM p.726-727 (5.33.2-3) は <PRINT LOG を通常の行として出す。FMSPG p.366 (8-97) の表では、プリンターが使えないときは「PRINT FAIL」で、空白の状態は無い。
- **重さ**：軽い。確か。
- **直す案**：<TAKEOFF は空中でも出す。PRINT は「PRINT FAIL」の表示にそろえるか、利用者に聞く。

#### CDU-13 本家の `validAlt` が残っている（型 F、軽い）
- **場所**：`B744.fms.pages.lua:567-577`。使う所は TRANS ALT（`:1151-1156`）と SPD RESTR（`:583-589, 1160-1170, 1214-1223`）。
- **何が起きるか**（読んだだけ）：
  - 2,000 ft 未満を拒む。
  - 上限が機体の実重量からの式（58.16 − 0.0615 × t）で、395 t では 33,850 ft。
  - 「0900」は 90,000 ft と読んで拒む。
  - 表示は ft のままで、遷移高度の上でも FL にならない。
- **根拠**：FCOM p.1269 (11.31.35) の入力と表示の規則。
- **直す案**：`B747_cdu_model.parse_alt` と `format_alt` に替える。

#### CDU-14 見出し・書式の小さな違い（型 H、軽い。1 行ずつ）
- CLB・DES の見出しが「SPD REST」。FCOM p.1327・p.1390 の図は「SPD RESTR」で、ダッシュは「---/------」。
- CRZ の小さい見出しが、目的地なしで「**** ETA/FUEL」（`vnav.lua:481`：見出しに箱）。
- APPROACH REF：12 行目のダッシュが大小両方に書かれ重なる（`approach.lua:96, 119`）。「25°」「30°」は小さい字で、FCOM p.1409 の図は大きい字。
- ACARS PREFLIGHT：<UTC UPDATE の下が読み込み時の固定の「00:00:00」。<RETURN は表の 14 行目で出ない（`acars.pages.lua:54, 58`）。VHF CNTRL> は中身の無い空白のページ。
- ACARS WEATHER REQUEST：行が 25 桁（`acars.pages.weatherrequest.lua`）で、右端の「>」と見出しの末尾が 1 桁はみ出す。

### 段 1〜3 の直しを見た結果

| コミット | 結果 |
|---|---|
| 7b62803b | 指摘 CDU-10。ほかは問題なし：FCOM p.1409 の図・p.1411 と行ごとに照らした。`appr_ref_rwy_test` 55 件が通る |
| c5a0b227 | 問題なし：FCOM p.1332 の 5・7 どおり。速度だけ・高度だけ・両方・窓の制限・7 文字の点名を t03・t04・t06・t07 で見た。`pred_glue_test` 222 件が通る |
| e682bb80（ページの側） | 指摘 CDU-2（後戻り）。109 のダッシュと 405 の小さい字は FCOM p.1320 どおり。`wb_n19_test` 33 件が通る |
| e2326a5d | 応答の種類は、電文の例を約 25 通り読んで追い、誤りは見つからなかった。`atc_n19_test` 60 件が通る。ATC INDEX の 6L は指摘 CDU-12 |
| 202f4a88 | 問題なし：ACMS INDEX に MAINT> が無い（`t08_out.txt`）。`menu_fltno_test` 29 件が通る |
| 5999f88b（ae0849a3） | 読みと試験（`atc_load_model_test` 91 件、`atc_load_pages_test` 62 件）で問題は見つからなかった。X-Plane は未確認（AutoATC が無い） |
| 771923a5 の ATC-01・02・04・05、CDU-01 | 上の e2326a5d・202f4a88 と同じ。`atc_uplink_pages_test` 68 件が通る |

### 見て問題が無かった所
- PERF INIT の行と入力（FCOM p.1308-1312）。
- THRUST LIM の地上の形（p.1313-1314：P&W −8・−20 %、GE −5・−15 % と N1）。
- INIT/REF INDEX の地上、INIT REF キーの行き先。
- NAV RADIO の ILS の PARK の形（p.1303-1306）。
- CRZ のページ（p.1347 の図）、GE の PROGRESS 1/2・2/2。
- EMERGENCY REPORT（p.728-730）。
- 高度の入力と表示（p.1269）、LEGS の制限の入力（窓は両方の順を受ける）。
- flight complete で消える項目（CDU-2・11 を除く）。
- 緯度経度の点名：LEGS・RTE・RTE DATA・POS REPORT・SELECT DESIRED WPT。

### 範囲の外で気づいたこと
- 接地した瞬間から flight complete まで、EICAS の推力の基準が前の離陸の「D-TO 1 +45C」に戻る（`t04_out.txt` の E4）。実機でどうかは資料なし。
- LEGS の滑走路の点の予測の速さが 240 kt（FLAP/SPEED 未入力、地上）。担当 2 の範囲。
- IDENT の ENGINES はリバリーのファイルの文字のまま（`engines/type` ではない）。
- `flight_complete_test` の「31 秒」は境目ちょうどで、時計の丸めにより 31 フレームでは完了しないことがある（`t05_fc_debug.lua`）。

### 見られなかった所
- X-Plane での見え方（26 桁目、空白のページ）と、ATC のアップリンクの実通信。
- 次のページとファイルは、行ごとの突き合わせをしていない：
  - CMC・ACMS の中身。
  - SIM CONFIG・SOUND・PAX/CARGO・DOORS・GROUND HANDLING。
  - EFIS/EICAS CONTROL。
  - ALTN NAV、`irs/irs_system.lua`。
  - `B744.notifications.lua` の全メッセージ、`B747.68.cdu_model.lua`。
  - DEP/ARR・FIX INFO・WIND・DESCENT FORECAST・OFFPATH・RTE 2 の細部。
  - ATC の REQUEST・REPORT・WHEN CAN WE・LOG。
- 既知の一覧（CDU-14(5) の空白の DES、CDU-15 の LAST の ALT、CDU-26 など）は、残っていることを見ただけ。

# 第 1 波 担当 2：FMC の論理（FMC-n）

## 担当 2「FMC の論理」報告（段 4 フルレビュー、HEAD 807956a2）

指摘は 9 件です。すべて X-Plane なしで、本番の Lua を LuaJIT で読み込んで確かめました（X-Plane では未確認）。スクリプトと出力は `D:\b747_review\stage4\a02_fmc\` にあり、リポジトリの直下を作業ディレクトリにして `luajit D:/b747_review/stage4/a02_fmc/<名前>.lua` で回し直せます。作業ツリーと git は変えていません（`render_pdf_pages.ps1` で FCOM p.1273・p.1315 を絵にしただけ）。

### 指摘

#### FMC-1　a465b930 の有効番号の読み違い：GE・貨物機で、仮定温度の離陸が上昇の減格を待機させない（型：外＝直しの誤り、F に近い）
- 場所：`B747.68.thrlim_model.lua:85-88`（`armed_clb`）、`:153`。つなぎは `B747.68.xt.fms.lua:2656`（`by_rating`）。
- 何が起きるか：`by_rating`（GE か freighter）のとき、待機する上昇は離陸の rating だけで決まり、仮定温度の減らし方を数えない。
  - TO + SEL（減らし方 20 %）は CLB のまま。
  - D-TO 1（全体で 20〜22 %）は CLB 1。
  - 減推力点で CLB 2 でなく全開の CLB に上がる。
- どう確かめたか：`thrlim_check.lua` の 1（出力 `thrlim_check.out`）。

  | 離陸 | 減らし方で決める（a465b930 の前） | `by_rating`（今の GE・貨物機） |
  |---|---|---|
  | D-TO、10 % | CLB 1 | CLB |
  | D-TO、20 % | CLB 2 | CLB |
  | D-TO 1（GE 5 %）+ SEL、全体 20 % | CLB 2 | CLB 1 |
  | D-TO 1（P&W 貨物機 8 %）+ SEL、全体 22 % | CLB 2 | CLB 1 |

  TO・TO 1・TO 2 だけ（SEL なし）は両方同じです。
- 根拠（自分で開いた）：
  - FCOM p.11 (0.2.5) の決まり 2：有効番号は直後の段落とその下位の項目だけに掛かり、次の同じ段の段落には掛からない。
  - FCOM p.1273 (11.32.3)（絵で確認）：「109」は「Two fixed climb thrust derates…35,000 feet.」の段落だけ。次の「Use of an assumed temperature reduced thrust takeoff or takeoff derate affects automatic selection of climb derate…」は番号なしで、全機体に掛かる。
  - FCOM p.1315 (11.40.39)（絵で確認）：「405, 570」は「Takeoff thrust derate can be entered by uplink.」だけ。「Selecting TO 1 arms CLB 1.」は次の段落で全機体。
  - 既定の減格（GE 5・15 %、P&W 8・20 %）なら、減らし方の規則で TO 1→CLB 1、TO 2→CLB 2 になり、両方の文が同時に成り立つ。
  - この直しはクラウドのセッションで `_ref/` なしに notes の要約から作られた（§172 の冒頭）。
- 重さ：乗員に見える誤り（P&W の貨物機 ICL 4X-ICB で今出る）。GE は D- の N1 の既知の誤り（§172 の末尾）で EEC の減らし方が負になるので、そちらを直すまでは表に出にくい。確かさ：確か。
- シナリオの案：`s336_clb_arm_405` の形（ICL 4X-ICB、地上、OAT 15 ℃）で TO + SEL 50。`laminar/B747/engines/to_reduction` が 15 以上なら THRUST LIM の `<ARM>` は CLB 2（今は CLB）。
- 直す案：`armed_clb` を全機体で `auto_clb(pct)` に戻す（洗い出しの高度の有効番号分けはそのまま）。`thrlim_model_test` の 405・570 の 12 件のうち SEL の入る件、`takeoff_ref_test` の +4、s336 の期待値を直す。

#### FMC-2　flight complete が FMC の CRZ ALT の値を消さない（型 J）
- 場所：`B747.68.xt.fms.lua:5780-5810`（`FC_KEYS` の `crzalt` は文字だけ）。`B744.fms.pages.lua:535-544`（`monitorCRZALT` の `lastCrz`）、`:1334`。使う側は `B747.68.xt.fms.lua:2383`・`:2562-2563`。
- 何が起きるか：flight complete の後、PERF INIT の CRZ ALT は □ になるが、`laminar/B747/autopilot/dist/cruise_alt` は前の飛行の最後の値のまま（ステップ後の高度や、進入復行の高度）。
  1. 次の飛行で、前と同じ CRZ ALT を入れると PERF INIT は □ のまま（値が変わらないので書き直さない）。誤りの表示も出ず、プリフライトが終わらない。別の値を入れてから入れ直すと直る。
  2. CRZ ALT を入れなくても、経路・ZFW・CI だけで `fms/vnav/perf` と `valid` が 1 になり、VNAV が古い CRZ ALT で有効になる。
  3. 与圧も同じ dataref を読む（`B747.55.xt.press.lua:31`）。
- どう確かめたか：`fc_persist2.lua`（出力 `fc_persist2.out`）。
  - 飛行中に 37000 にした後：flight complete で文字は `*****`、dataref は 37000。
  - 次の飛行（CRZ ALT 未入力）：VNAV perf 1・valid 1。
  - 370 を入力：文字は `*****` のまま。350 の後に 370 を入れると FL370。
- 根拠：FMSPG p.97 (3.2-37)「The CRZ ALT display is cleared at flight completion」。FCOM p.1307 (11.40.31)「Entered values clear … at engine shutdown after flight」。FCOM p.1236 (11.31.2)。
- 重さ：乗員に見える誤り（同じ高度の折り返しで CRZ ALT が入らない）。確かさ：確か（オフライン）。
- シナリオの案：autoland のシナリオ（`s114` など）で着陸して停止し、燃料コントロール 4 本を CUTOFF にして 35 秒待つ。
  - `laminar/B747/autopilot/dist/cruise_alt` が 0（今は前の値）。
  - 同じ CRZ ALT を 1R に入れて `laminar/B747/fms/data` の `crzalt` が FLxxx（今は `*****`）。
- 直す案：`B747_fms_flight_complete` で `B747BR_cruiseAlt = 0` にする（`monitorCRZALT` が □ を書く）。`flight_complete_test` に dataref と同じ値の入れ直しを足す。

#### FMC-3　消した SPD TRANS（上昇・降下）が flight complete を越えて次の飛行に残る（型 J）
- 場所：`FC_KEYS`（`B747.68.xt.fms.lua:5780-5784`）に `transpd`・`destranspd`・`desspdtransalt` が無い。消す所は `B744.fms.pages.lua:1147`、`:1206-1207`、`B747.68.xt.fms.lua:2286`（巡航の降下のノブ）。`update_spd_trans`（`:909-915`）は `---` なら何もしない。
- 何が起きるか：乗員が DES の SPD TRANS を DELETE する（ATC の「速度制限なし」）か、巡航の降下で自動に消えると、機体を読み直すまで戻らない。次の飛行の降下は 10,000 ft で 240 kt に減速せず、ECON のまま降りる。上昇の SPD TRANS も同じ。
- どう確かめたか：`fc_persist.lua`・`fc_persist2.lua`。flight complete の後に既定と違う項目は `destranspd '---'`・`desspdtransalt '-----'`・`transpd '---'` の 3 つだけ。新しい経路を入れても同じ。
- 根拠：FCOM p.1236 (11.31.2)（一部の preflight の欄は既定に戻る）、p.1392 (11.43.4)（SPD TRANS は目的地ごとの値、無ければ 240/10000）、p.1328 (11.41.4)。flight complete で戻すと名指しした文は無いが、目的地・出発地ごとの値なので前の飛行の削除が残る根拠も無い。
- 重さ：乗員に見える誤り。確かさ：確か（オフライン）。
- シナリオの案：FMC-2 と同じ流れで、着陸の前に DES 3L を DELETE。flight complete の後に新しい経路を入れ、DES 3L が 240/10000、CLB 3L が xxx/10000 に戻ること。
- 直す案：`FC_KEYS` に 3 つを足す（`defaultFMSData` の値へ）。新しい目的地・出発地を入れたときに戻す方が自然なら、`B747_fmc_route_changed` で。

#### FMC-4　ILS の自動同調「A」が空中だけ：接地（か 40 kt 未満）で PARK になり、PFD の LOC・G/S の目盛が消える（型 J）
- 場所：`B747.68.xt.fms.lua:3748`（`auto=not ground and …`）、`:3762-3763`（`ils_dots`）。`B747.68.tune_model.lua` の `ils_update`。§88 の推定「A は空中だけ」「PARK の間は目盛だけ消す」の帰結です。
- 何が起きるか：
  - FCC の ILS TUNE INHIBIT が無い進入（A/P・F/D で捕まえていない手動の ILS・目視）：接地の瞬間に NAV RADIO が PARK、`ils_dots` 0。
  - 捕捉した進入・autoland：滑走の 40 kt 未満で同じ。
  - 受信機の周波数はそのまま。
  - 接地する着陸復行では、続く浮揚で「離陸後 10 分」が数え直され、2 回目の進入に ILS が自動で入らない。
- どう確かめたか：`ils_landing.lua`・`ils_landing2.lua`（`navrad_pages_test` の準備に着陸を足したもの。出力 `ils_landing.out`）。
  - 空中：`109.50/157 A`、`ils_dots` 1。
  - 接地（inhibit なし）：`PARK`、`ils_dots` 0、nav1 は 10950 のまま。
  - inhibit ありの接地：A のまま。inhibit を切ると PARK、`ils_dots` 0。
- 根拠：FCOM p.1307 (11.40.31)：A は「T/D の 50 NM 内、滑走路端の 150 NM 内、FMC が降下」のどれかで、空中の条件は無い。p.1306 (11.40.30) の PARK は電源投入・T/D の 200 NM より遠い・半分の手前だけ。p.987 (10.10.25)：目盛は周波数を同調したら出る。
- 重さ：乗員に見える誤り。確かさ：確か（オフライン）。
- シナリオの案：`s162_ils` の形で ILS を A にし、A/P・F/D を切って着陸。接地の 5 秒後に `laminar/B747/autopilot/ils_dots` が 1、NAV RADIO の ILS が A（今は 0・PARK）。`s114` では停止まで 1。
- 直す案：地上でも、飛行の後（空中から接地した後）は A を保つ。出発前の地上は今のまま PARK。

#### FMC-5　CLB の SPD RESTR が、その高度を過ぎても残る（型 J・I）
- 場所：`B744.fms.pages.lua:1157-1169`（書くだけで、消す所が無い）。`activepages/B744.fms.pages.vnav.lua:390`（CLB はいつも表示）。DES は `:644` で高度より下をダッシュにしている。速さは `B747.68.xt.fms.lua:1402-1404`、`B747.68.pred_model.lua:52-59`。
- 何が起きるか：
  - 240/8000 を入れて 8,000 ft を過ぎても、CLB の 4L は 240/8000 のまま（flight complete か乗員の DELETE まで）。
  - 後の上昇の段階（進入復行）で 8,000 ft より下に再び効き、目標が 240 kt 以下になる。
  - DES のページだけ「過ぎたらダッシュ」を作った非対称。
- どう確かめたか：`misc_check.lua` の 2（`misc_check.out`）。上昇の予定は 3,000 ft で 240、20,000 ft で 340、通過後もデータは `240`・`8000` のまま、後の上昇の 3,000 ft でまた 240。表示は読んだだけ。
- 根拠：ATA34_2 p.553（34-61 p.127）：「When the SPD RESTR segment is passed, it is replaced by dashes」。FCOM p.1328 (11.41.4) は「入力の前はダッシュ」だけ。
- 重さ：軽い〜乗員に見える誤り。確かさ：確か。
- シナリオの案：3,000 ft の上昇の空中開始で CLB 4L に 240/8000。8,500 ft を過ぎた後、CLB の 4L が `---/-----`、`laminar/B747/fms/data` の `clbrestspd` が `---`。
- 直す案：上昇の段階でその高度を過ぎたら `clbrestspd`・`clbrestalt` をダッシュに戻す。

#### FMC-6　ND の現用点の ETA と DATA の各点の ETA が、本家の式「距離 ÷ max(275 kt, GS)」のまま（型 F）
- 場所：`B747.68.xt.fms.lua:5947-5981`（`get_ETA_for_Distance`。注釈「the predictions come in step 8」のまま）、`:6025-6048`（`B747_route_eta`）、`:6050-6132`（`laminar/B747/nd/waypoint_eta`・`next_waypoint_eta`）。
- 何が起きるか：GS が 275 kt より低い所（進入、10,000 ft より下の上昇・降下）で、ND の ETA が早い。PROGRESS・LEGS は予測の時刻なので、ND と CDU が食い違う。275 kt より上でも今の GS で全部の点を割るので、降下・進入の先の点は早い。
- どう確かめたか：`misc_check.lua` の 1。

  | GS | 残り | ND の時間 | 距離 ÷ GS |
  |---|---|---|---|
  | 140 kt | 10 NM | 2.2 分 | 4.3 分 |
  | 180 kt | 20 NM | 4.4 分 | 6.7 分 |
  | 250 kt | 40 NM | 8.7 分 | 9.6 分 |
  | 300 kt 以上 | — | 一致 | 一致 |

- 根拠：FCOM p.1147 (10.40.39)（ND の現用点の ETA は FMC のもの）。PROGRESS は §48 で予測に替えた。notes/ATA-31.md の 555 行目は「ND の右上と必ず一致させ、FMC の予測を作り直せば ND も直るように」と書くが、替わっていない。
- 重さ：乗員に見える誤り（表示だけ）。確かさ：確か。
- シナリオの案：進入の 180 kt で、`laminar/B747/nd/waypoint_eta` と PROGRESS 1 の TO の ETA の差が 0.2 分以内（今は 20 NM で約 2 分）。
- 直す案：ETA を `B747_fms_preds().pts[i].t` から出す（予測が無いときだけ今の GS）。

#### FMC-7　離陸の推力制限（減格と SEL）が、接地と着陸復行で戻る・進入まで残る（型 J）
- 場所：`B747.68.thrlim_model.lua:147-156`（地上は前の `to` と SEL のまま TO）、`:180-198`（空中の TO は GA の判定の前で返る）。つなぎは `B747.68.xt.fms.lua:2626-2671`。
- 何が起きるか：
  - (a) 着陸復行で車輪が着くと、GA が「D-TO 2 +47C」（前の離陸の減格と仮定温度。EEC への番号 112）になる。TO/GA の押し直しが無いので、浮揚の後も VNAV の減推力点か THR まで続く。A/T の THR REF と EEC の基準が、減格した離陸の値になる。
  - (b) 通常の着陸でも、接地から flight complete まで EICAS は「D-TO 2 +47C」。87a34b56 の直しの残りです。
  - (c) 離陸の後に VNAV も THR も使わない飛行（場周など）では TO のまま。フラップ 30・G/S 捕捉でも GA にならず、進入の TO/GA で「TO」。
- どう確かめたか：
  - `ga_touch.lua`（FMS のモジュール。`ga_touch.out`）：GA（50）→ 車輪が着く →「D-TO 2 +47C」（112）→ 浮揚後 1,500 ft でも同じ。
  - `thrlim_check.lua` の 3・4：模型でも同じ。(c) はフラップ 30・G/S で「TO 1」。
- 根拠：
  - FCOM p.672 (4.20.14)：フラップが UP から出る・着陸位置・G/S 捕捉で GA。着陸位置か G/S で GA に固定。着陸復行は「接地してもモードが続く」。
  - p.656 (4.10.18)：進入の TO/GA は GA の制限で THR。
  - ATA34_2 p.535（34-61 p.109）：地上は TO を自動で選ぶ。
  - 地上で前の減格と SEL が残るか、接地した着陸復行の制限が何かは資料なし。
- 重さ：(a) は乗員に見える誤り（着陸復行の推力が減格の離陸の値）、(b)(c) は軽い。確かさ：コードの動きは確か。正しい動きは、(c) が p.672 から「たぶん」、(a)(b) が資料なし。
- シナリオの案：TO 2 + SEL 47 で離陸して進入（`s150` の形）。10 ft RA で TO/GA を押して車輪を着けてから上昇し、`laminar/B747/fms/thrlim/eicas` が GA のまま（今は D-TO 2 +47C）。通常の着陸の接地の後の表示も記録する。
- 直す案：空中から地上に来た後は、減格と SEL を使わない TO にする（利用者の判断）。空中の TO でも、フラップ着陸位置・G/S で GA にする。

#### FMC-8　加速高度・減推力高度の基準が出発空港の標高で、100 kt で記録した気圧高度でない（型 F）
- 場所：`B747.68.xt.fms.lua:2427`・`:2430`（`origin.elev + ACCEL HT`）、`:2627`（`alt_agl`）。`B747.68.vnav_model.lua:268`、`B747.68.thrlim_model.lua:195`。
- 何が起きるか：高度計の指示と航法データの空港の標高を比べるので、次の分だけずれる。
  1. 高度計の規正の誤り（約 27 ft/hPa。0.5 inHg で約 500 ft）。
  2. 空港の標高と滑走路の差。
- どう確かめたか：読んだだけ。`elev_diff.lua`（`elev_diff.out`）で、滑走路端が空港の標高より低い例を出した：KDEN RW26 −140 ft、KLAS RW26R −139、SEQM RW18 −134、LEMD RW32R −112、KDFW RW31R −98、KSEA RW34R −85。その分、加速と減推力が遅れる。
- 根拠：FCOM p.667 (4.20.9)：離陸で 100 kt を通るときの気圧高度を FMC が記録し、LNAV・VNAV の作動、フラップ上げの加速、上昇推力に使う。
- 重さ：軽い。確かさ：確か（コード）。
- シナリオの案：KDEN RW26 で離陸し、`laminar/B747/fms/vnav/cas` が V2+10〜25 から上がり始める電波高度を見る（期待は約 1,000 ft、今は約 1,140 ft）。規正を 0.5 inHg ずらした回も。
- 直す案：地上で IAS が 100 kt を越えたときの指示高度を覚え、3 か所の基準にする（覚えが無いときは今の標高）。

#### FMC-9　旧 AP の T/D（(CRZ ALT − E/D) ÷ 290 NM）が、COST INDEX の入力の窓と SIM CONFIG の PAUSE に残る（型 F、読んだだけ）
- 場所：`B744.fms.pages.lua:1565-1566`（`B747BR_tod`・`B747BR_totalDistance`）。書くのは `B747.70.xt.autopilot.lua:2991-2994`（`setDistances`）。`:3185-3187`（`ap_vnav_pause`）、`activepages/B744.fms.pages.maintsimconfig.lua:126`。
- 何が起きるか：「T/D の 10 NM 以内は COST INDEX が INVALID ENTRY」（FMSPG p.97）の T/D が、FMC の経路の T/D（`B747_fms_vnav_td()`）でなく旧 AP の 3:1 の式。風・減速・制限で数十 NM ずれる所に窓が開く。SIM CONFIG の「PAUSE AT T/D」も旧式の T/D で止まる（新しい便利機能は FMC の T/D）。
- 重さ：軽い。確かさ：未確認（`setDistances` がいま毎フレーム回っているかは確かめていない）。
- 直す案：両方を `B747_fms_vnav_td()` に替える。

### 段 1〜3 の直しを見た結果
- **a465b930（上昇の減格、`thrlim_model` の側）**：指摘 FMC-1。
- **87a34b56（EICAS の仮定温度）**：空中は問題なし（`ga_touch.lua` で D-TO 2 +47C → CLB 2 → CRZ → GA、温度が付くのは TO だけ）。残りは接地の後に「D-TO 2 +47C」が戻ること（FMC-7 の (b)。資料なし）。
- **c5a0b227（LEGS の予測の高度）**：問題なし（`pred_text` の条件と FCOM p.1332 (11.41.8) を読んだ。予測の側のコードは変わっていない。試験は回していない）。
- **59ba4c82（CIFP の欄）**：問題なし。`course_field`・`true_of`・fly-over の B・`navaid_kind`・PI の出航・`runway_length` を読み、ARINC424 p.79・p.85・p.200 の該当行を自分で確かめた。RWY レコードの欄、GS 角、LOC のコース、`dms` の単位も合う。X-Plane の確かめ（§175.6）はまだ。
- **5999f88b（ATC の LOAD 段 A、経路を変える側）**：問題なし（`atc_load_model` の要素・読み込みと、つなぎの `B747_fms_atc_load` を読んだ。UM46 がその点の速さの制限を消すのは LEGS の入力と同じ扱いで、資料なしの推定のまま）。
- **771923a5 の NAV-01・02・03・06・07・08**：問題なし（上と同じ）。
- **NAV-04・NAV-05 を残した理由**：妥当。FMSPG p.126 (3.3-17)・p.187 (3.5-3)、FCOM p.1332 を開いて、理由の文と合うのを確かめた。

### 見て問題が無かった所
- V 速度は空中で flapsRef が 0 になると消える。
- RTA は FIX が前に無くなると終わる。
- 進入復行の印（`vnavMissed`）、END OF DES、`desSpdS` は地上と上昇で消える。
- 着陸高度の切り替えとメッセージの抑止は flight complete で戻る。
- 燃料の CALC・FUEL USED の始まりと終わり。
- E/O のモデル、flight complete の 30 秒と「飛行の後だけ」。
- `THR REDUCTION` の 5 と高度の判定、TO/GA の空中の押しでの減格の解除。
- `B747.30.xt.fltMgmt` は IRU とトランスポンダの操作だけ。
- 橋渡しの C は計画の文字の受け渡しだけ（関数の並びを見た）。

### 範囲の外で気づいたこと
- 担当 8：制限が TO のまま進入すると、A/T の `limit_to`（`B747.70.xt.autopilot.lua:1115`）で、TO/GA が THR（2,000 fpm）でなく THR REF の道になる見込み（FMC-7 の (c)）。
- 担当 10：与圧が `autopilot/dist/cruise_alt` を読むので、flight complete の後は前の飛行の CRZ ALT（FMC-2）。
- 試験：`thrlim_model_test` の 405・570 の件と `s336` は、FMC-1 の読み違いを期待値にしている。
- `flight_complete_test` は `crzalt` の文字だけを見ている。

### 見られなかった所
- `pred_model`・`path_model`・`wind_model`・`navperf_model`・`altn_*`・`simbrief_model`・`nd_line_model` の中身（頭と一部だけ）。
- `route_model` の編集（`set_arrival`・`sequence`・ホールド・オフセット）。
- 目的地の変更とホールドの段階の移り。
- 降下から巡航・上昇へ戻る移り（資料に決まりが見つからなかった）。
- 変異の試験と、回帰の全体（`flight_complete`・`thrlim`・`navrad` の 3 本だけ回して通過）。
- X-Plane での確かめ全部。

# 第 1 波 担当 3：性能・重量重心（PERF-n）

## 担当 3「性能・重量重心」報告（PERF）

対象は HEAD 807956a2。リポジトリは変えていません（`git status` は開始時と同じ）。例外の道具で `_ref/text/img/FPPM/p0041.png` を 1 枚作りました。X-Plane は起動していません。

スクリプトは `D:\b747_review\stage4\a03_perf_wb\*.lua`、出力は同じ場所の `out\*.txt` です。どれもリポジトリ直下で `luajit D:/b747_review/stage4/a03_perf_wb/<名前>.lua` で回し直せます。

以下、行番号で `fms.lua` は `plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua`、`pages.lua` は同じフォルダーの `B744.fms.pages.lua`、`activepages/` もその下です。

---

### 指摘

#### PERF-1　FMC が X-Plane に書く重心のずれに燃料の分が入っていて、X-Plane が燃料を二重に数える（型 F）

- **場所**：`fms.lua:657-699`（`inflight_update_CG`、書き込みは 695）、`fms.lua:644`（`calc_CGMAC`）、`fms.lua:6262-6265`（開始時に 0、以後 60 秒ごと）、`pages.lua:771`（積むたび）。
- **何が起きるか**：
  - FMC は「OEW＋荷物＋燃料」の全体の重心のずれを `cgz_ref_to_default` に書く。X-Plane はその値を OEW＋荷物だけに掛け、燃料は自分でタンクの位置に足す。
  - 結果：X-Plane の重心 − FMC の重心 ＝ (燃料のモーメント × (OEW＋荷物) − 燃料 × 荷物のモーメント) ÷ 総重量²。燃料が多いほど、中央タンクが入るほど X-Plane の重心が前に出る。
  - 重量の窓と CDU の重心の自動入力は X-Plane の値を出すので、乗員には積んだ荷物より前の重心が見える。貨物機（405）の TAKEOFF REF の小さい字の CG と TRIM は FMC の値なので、X-Plane と合わない。
  - 荷物なしでも、開始の約 60 秒後に重心が前へ跳ぶ（既定の 270 t で CG 20.6 → 約 19 %、窓の ZFW CG 23.0 → 約 20.5 %）。notes §174 の「既定で CG 21 %・TRIM 5.1」は最初の 1 分だけの値。
- **どう確かめたか**：`cg_double_count.lua`。本番の FMS をモックで動かし、11-20 15:01–15:24 の `aero_takeoff_trim_*` 6 本の記録（result.md の地上の snapshot）と比べた。
  - 同じ重さの 2 本のあいだの傾き d(cg_offset_z)/d(ずれ) は 0.9104・0.8701・0.7791。(OEW＋荷物)/総重量 は 0.9092・0.8680・0.7824 で一致（OEW/総重量 の 0.83・0.66・0.54 ではない）。
  - モデルと記録の差は 0.2〜0.4 % MAC（記録が後ろ。タンクの実際の配分の差と見るが未確認）。

  | 記録 | FMC の重心 | X-Plane（記録） |
  |---|---|---|
  | 280 t・燃料 37 t（280_29） | 27.5 % | 26.2 % |
  | 340 t・燃料 74 t（340_29） | 27.4 % | 23.0 % |

  - 満席＋貨物 15 t で燃料を振った場合（モデル）：

  | 燃料 | FMC | X-Plane | 差 |
  |---|---|---|---|
  | 100 t | 24.2 % | 22.8 % | 1.4 |
  | 130 t | 20.3 % | 16.5 % | 3.8 |
  | 150 t | 16.8 % | 11.0 % | 5.8 |
  | 163 t | 14.7 % | 7.8 % | 6.9 |

  - 安定板タンク 10 t の効きは、正しくは +8.8 % MAC のところ +14.1 %。
  - AERO.md §3.23 の「280 t で 13 % と 29 % に積んだ 2 本がどちらも 21.5 %」は、このモデルで 21.2 % と出る。
  - 旧 `wb_window.c` の注記（安定板タンク 8 t で `cg_offset_z` +0.857 m）は、X-Plane が燃料を自分で正しく数えている証拠（計算 0.854 m）。
- **根拠**：重心の定義（資料なし）。AERO.md §3.23 の「気づいたこと」は「上書きする」までで、「その重心で飛ぶ」と書いているが、実際は飛んでいない。
- **重さ・確かさ**：乗員に見える誤り（離陸・巡航のトリム、重心の表示。満載の長距離ほど大きい）。確か。
- **シナリオ案**：s256 と同じ開始（地上、既定の 270 t、荷物なし、reload）。
  - 開始の 30 秒後と 150 秒後に `sim/flightmodel2/misc/zfw_cg_offset_z`・`cg_offset_z`・`sim/flightmodel/misc/cgz_ref_to_default` を読む。
  - 今の見込み：30 秒は 0／−0.198／0、150 秒は約 −0.2／約 −0.33／約 −0.2。
  - 合格：`zfw_cg_offset_z` が 0 ± 0.01 m のまま、`cg_offset_z` が 2 回で ±0.01 m。
  - 追加：重量の窓で満席＋貨物 15 t、燃料 150 t。`cg_offset_z` の % MAC が、荷物と燃料のモーメントの和 ÷ 総重量 の ±0.5 %。
- **直す案**：書く値を「荷物のモーメント ÷ (OEW＋荷物)」にする。上の表はこれで X-Plane と FMC が一致する。OEW とタンクの腕は dataref から読む（今は 1243.32 などの決め打ち）。

#### PERF-2　TAKEOFF REF の TRIM が、入り方で別の重さを使う（型 F。e682bb80 の直し残し）

- **場所**：`fms.lua:601-606`・`637-641`（`calc_CGMAC` が OEW＋燃料＋FMC の区画の和で計算）、`pages.lua:1734-1736`（CG の入力は CDU の GR WT で計算）。
- **何が起きるか**：
  - FMC の区画の和が CDU の GR WT と違うとき、同じ CG・同じ GR WT で、CG を入れた直後と ZFW／GR WT を入れ直した後の TRIM が変わる。
  - 違いが出るのは、荷物を X-Plane の Weight & Balance 画面やシナリオの `payload_weight_in_kilograms` で積んだとき、または乗員の ZFW がシムと違うとき。
- **どう確かめたか**：`trim_weight_paths.lua`。
  - X-Plane の荷物 60 t・区画は空・燃料 86.5 t：ZFW 243.5 → GR WT 330.0、CG 20 で TRIM 6.5、同じ ZFW を入れ直すと 5.3（270 t の値）。
  - 区画に 60 t 積んで ZFW 235.0：6.4 → 6.5。
  - `wb_n19_test` の「280 t のトリム」は OEW 180 t・ZFW 180 の組で、2 つの重さがたまたま同じ。
- **根拠**：FCOM p.1320 (11.40.44)：CG を入れると FMC がトリムを計算する。FMC の重さは PERF INIT の GR WT（p.1309 (11.40.33)）。
- **重さ・確かさ**：軽い〜乗員に見える（最大約 1.2 units）。確か。
- **シナリオ案**：地上で荷物 60 t を `payload_weight_in_kilograms` で積む。CDU の sim の値で ZFW、TAKEOFF 4R に 20、PERF INIT 3L をもう一度。Line09_S の TRIM が 2 回とも同じ（±0.1）なら合格。
- **直す案**：`calc_CGMAC` のトリムを `tonumber(fmsModules.data.grwt)` で計算する。

#### PERF-3　flight complete の後、TAKEOFF REF が空白のまま（型 J。e682bb80 で後戻り）

- **場所**：`activepages/B744.fms.pages.takeoff.lua:172-181`（179 行が `tonumber("--")` の nil を format に渡す）、`fms.lua:5780-5810`（`cg_mac`・`crzcg` は既定に戻すが、`cg_lineLg`・`crzcg_lineLg`・`laminar/B747/fmc/elevator_trim` は残る）、`activepages/B744.fms.pages.perfinit.lua:109-114`。
- **何が起きるか**：
  - 前の飛行で CG を入れていると、エンジン停止の 30 秒後から TAKEOFF REF の 13 行が全部空白になる。ページは pcall の中なのでプラグインは止まらず、エラーは `print` 1 回だけでログにも出ない。
  - 次の飛行で ZFW を入れても空白のまま。4R に見えないまま CG を入れると戻る。
  - e682bb80 の前は、ZFW の入力で `calc_CGMAC` が `cg_mac` を数字に書き直して戻っていた。109・570 ではその書き込みをやめたので、戻らなくなった。
  - PERF INIT の CRZ CG は既定の 20.0 が大きい字で出る（FCOM は小さい字）。
  - 緑の帯の選択は前の飛行のトリムのまま（380 t・CG 10 の 9.9 が残り、次の飛行も nose up の帯）。
- **どう確かめたか**：`flight_complete_cg.lua`。ZFW 240・CRZ CG 25.5・CG 22 の後に `B747_fms_flight_complete()`。
  - `getPage` が「takeoff.lua:179: bad argument #2 to 'format'」で失敗し、CDU の 13 行が空白。ZFW 230 の後も空白、4R に 24 で復帰。
  - `flight_complete_test`・s163 は CG を入れていない。
- **根拠**：FCOM p.1236（flight complete）、p.1320（最初はダッシュ）、p.1311 (11.40.35)（CRZ CG の既定は小さい字）。
- **重さ・確かさ**：乗員に見える誤り（X-Plane を続けて 2 便目を飛ぶと必ず）。確か（モックで。X-Plane は未確認）。
- **シナリオ案**：s163 に、着陸前の「TAKEOFF 4R に 22」「PERF INIT 4R に 25.5」を足す。完了の後に INIT REF → TAKEOFF で `fms3/Line01_L` が「TAKEOFF REF」、Line09_S に「--%」。PERF INIT の Line09_S に「20.0%」。
- **直す案**：`B747_fms_flight_complete` で `cg_lineLg`・`crzcg_lineLg` を空に、`B747DR_elevator_trim` を 0 に。179 行は数字でなければダッシュ。

#### PERF-4　`calc_stab_trim` を FPPM の表の全ますと比べた（型 F。既知の項目への新しい数字）

- **場所**：`fms.lua:533-559`。
- **何が起きるか**：notes §174 の「0.3 units 以内」は 5 点の比較。全 74 ますでは rms 0.31 で、隅で外れる。
  - 200 t・33 %：1.07（表 2.0。3 つの帯のどれにも入らない）。
  - 400 t・9 %：10.26（表 9½。nose up の帯の 10.15 を超える）。
  - 220 t・33 %：−0.54、260 t・9 %：−0.53。280〜320 t は全体に −0.3。
  - 表は 2〜9½ で止まるが、式は止まらない。CDU の入力範囲（0〜40 %）では 0.0〜12.7 が出る（300 t・CG 3 % 以下で 10.15 超、200 t・32 % 以上で 1.35 未満）。
- **どう確かめたか**：`trim_table_check.lua`。表は `_ref/text/img/FPPM/p0044.png` から読んだ。
- **根拠**：FPPM p.44 (1.2.20)。p.57 (1.3.11) の TO1 の表は同じ値で、380 t・13 % だけ 9（p.44 の 8 は誤植と見る）。FCOM p.1320：トリムは 0.1 unit 刻み。
- **重さ・確かさ**：軽い（普通の範囲では 0.45 以内）。確か。
- **直す案**：FPPM の表の補間に置き換え、2〜9½ の外は端の値。

#### PERF-5　APPROACH REF の FLAP/SPEED：重い機体の VREF を拒む、VREF より大きい入力でフラップの速度を上げない（型 F・I）

- **場所**：`pages.lua:1513`（110〜180 kt の外は INVALID ENTRY。出典なし）、`plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.speedtape_model.lua:61-63` と `B747.60.xt.speedtape.lua:83`（バグは FMC の VREF30 だけから）。
- **何が起きるか**：
  - (a) 357 t より重いと VREF25、385 t より重いと VREF30 が 180 kt を超える。離陸直後の引き返しで、FMC が 1R・2R で scratchpad に出した値を 4R が拒み、PFD に REF が出ない。
  - (b) VREF より大きい速さを入れても、フラップの機動速度のバグが動かない。
- **どう確かめたか**：
  - (a) `appr_ref_heavy.lua`：390 t で 1R →「25/190」→ 4R が INVALID ENTRY、2R →「30/182」も同じ。
  - (b) 読んだだけ（モデルの入力に選んだ VREF が無い）。
- **根拠**：FCOM p.1412 (11.43.24)：VREF より大きい速さの入力は、フラップの速度の予定の全体をその分だけ上げる。入力の範囲は FCOM・FMSPG p.205 に無い。FCTM p.243-245 の重量超過着陸はノートから。
- **重さ・確かさ**：軽い。(a) 確か、(b) たぶん。
- **シナリオ案**：地上で ZFW 240・燃料 150 t。APPROACH REF 1R → 4R で `fms/data` の flapspeed が「25/190」、`laminar/B747/airspeed/Vref` が 190。
- **直す案**：範囲を FMC の VREF が出る幅（例 100〜220）に。選んだ VREF と FMC の VREF の差（正のとき）を `vf[0..4]` に足す。

#### PERF-6　PERF INIT の ZFW の上限 270 t で、貨物機が行き止まり（型 I）

- **場所**：`pages.lua:1536`（ZFW 130〜270・GW 150〜400 t。出典なし）。
- **何が起きるか**：
  - 405・570 の最大零燃料重量は 276,691 kg なのに、270.1 t から INVALID ENTRY。
  - 貨物機で FREIGHT のページの「F」（満載 107,717 kg）を積むと、acf の OEW 183.5 t のため ZFW 291.2 t。sim の値の入力も拒まれ、PERF INIT が埋まらない（V 速度・VNAV が出ない）。
- **どう確かめたか**：`appr_ref_heavy.lua` の後半（燃料 50 t で 270.0 は通り、270.1・276.6 は INVALID。貨物機の満載も INVALID）。
- **根拠**：FCOM p.78 (L.10.2)。p.1310 (11.40.34)：入力の形は XXX か XXX.X だけ。
- **重さ・確かさ**：乗員に見える誤り（貨物機で重く積んだときだけ）。確か。
- **直す案**：上限を最大零燃料重量より上に（例 300）。満載が MZFW を超えること自体は acf の OEW（旅客機の値）の問題で別件。

#### PERF-7　高い所・重い機体で、琥珀の帯の上端がフラップ 10・20 のバグを超える（型 F。推定の外挿）

- **場所**：`plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.minspeed_model.lua:86-102`・`116`（10,000 ft の図に合わせた直線を、図の Mach の外へ延ばす）。
- **何が起きるか**：上端 − バグが、海面では全フラップ・全重量で負（−1.2 以下）。高い所では正になる。

  | 高度 | 重さ | F10 | F20 |
  |---|---|---|---|
  | 5,000 ft | 394.6 t | +0.6 | +0.4 |
  | 10,000 ft | 320 t | +0.2 | +1.0 |
  | 10,000 ft | 360 t | +1.5 | +1.4 |
  | 10,000 ft | 394.6 t | +3.0 | +2.2 |
  | 20,000 ft | 394.6 t | +9.8 | +7.4 |

  標高の高い空港（FAOR 5,558 ft）の重い離陸で、バグの速さを保つと AIRSPEED LOW が出うる。
- **どう確かめたか**：`minspeed_vs_bugs.lua`。図の値そのもの（10,000 ft・400 t の F10 の shaker 178.8 kt × √1.3 ＝ 203.9）はバグ 204 とちょうど同じで、超える分は外挿から出ている。
- **根拠**：FCTM p.34 (1.4)：フラップの速度の予定は全重量で stick shaker まで十分な余裕。FCOM p.973 (10.10.11)。
- **重さ・確かさ**：軽い。数字は確か、X-Plane で警報が出るかは未確認。
- **直す案**：1.3 g の限界を、図の Mach の上端より先は上端の値で止める。

#### PERF-8　小さいもの（e682bb80 の残り）

- **FREIGHT のページの見出し**：`activepages/B744.fms.pages.pax-cargo.lua:221`「(3P)」・`:229`「(1P)」が前のまま。ゾーン A は 2 枚まで、E は 1 枚入らない（型 H。読んだだけ）。
- **405 のトリムの空白**：FCOM p.1320 は「緑の帯の範囲の外なら空白」。コミットは「値が資料に無い」として省いたが、帯は `plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.greenband_model.lua:17` にある（1.35〜10.15）。今は 0.0 でも出る（型 I。読んだだけ）。

---

### 段 1〜3 の直しを見た結果

- **0dba427b（% MAC）**：式は資料どおり。TCDS_747 p.14（MAC 327.8 in、LEMAC は datum の 1258 in 後ろ、datum は機首の 90 in 前）を開いて確かめ、FMC・CDU・窓が同じ式。acf の原点＝機首の見立ては、前脚（TCDS の jack point BS 384.7、acf は BS 395 相当）と主脚（wheelbase 84 ft、acf 83.5 ft）から ±10 in（±3 % MAC）以内。ただし、そろえた 2 つの重心（FMC と X-Plane）が燃料の分だけ食い違う → 指摘 PERF-1。
- **e682bb80（WB-03・04・05）**：
  - WB-03 は FCOM p.1320 どおり。ただし指摘 PERF-2、PERF-3（後戻り）、PERF-8。
  - WB-04 は問題なし（NTSB_WBM p.32 の 725.5・1702.0・2014.6 を確かめた）。
  - WB-05 は問題なし（p.23 の 7,838・2,041 kg を確かめた）。見出しだけ PERF-8。
- **771923a5（マージ）の WB-03〜05**：問題なし。HEAD に e682bb80 の中身が入り、`wb_n19_test` 33・`cg_mac_test` 7・`takeoff_ref_test` 78 が通る。
- **2026-11-14 の離陸速度（FPPM）**：問題なし。
  - p.41・42・54・55・66 の印刷された速さを全部モデルの表と突き合わせ、不一致 0（`to_tables_check.lua`。p.67 を含めて 2,226 値中 22 が不一致と出るが、すべて既知の p.67 の欠けと余分な 270 t の行）。
  - 手順は p.21 (1.1.3) どおり。
  - 約 103 万通りの掃引で数でない値 0、V1 ≤ VR < V2 の崩れ 0（`to_speeds_sweep.lua`）。
- **同日の acf の最大重量**：問題なし（870,000 lb ＝ FCOM p.78 の 109 の 394,625 kg）。
- **同日の最大巡航 EPR**：見ていない（担当 5 の範囲）。

### 見て問題が無かった所

- **VREF**：FCOM p.228 (PI.10.2) と一致。GE の p.330 (PI.20.2、lb) とは 400〜900 klb で 1 kt 以内。p.1411 の例（502.8 klb で 142/136）も出る。
- **フラップの機動速度**：p.229 (PI.10.3)・p.331 (PI.20.3)。309 t 超の VREF+100 は FCOM を優先（既知）。
- **単位**：PERF INIT・APPROACH REF・PAX/CARGO・PROGRESS・RTE DATA・VNAV の kg/lb。`calc_stab_trim` は kg と千 kg のどちらで呼んでも合う。LBS の表示でも同じ TRIM。
- **perf_db**：P&W の最大高度（p.267）と LRC の 33,000 ft の列（p.268）、GE の 800 klb・最適高度（p.363–364）を抜き取りで確認。表の外は端の値で、数でない値は出ない。
- **最小速度**：海面では全フラップで琥珀の帯の上端がバグより下。VREF30 ÷ shaker は 1.17〜1.18。
- **回帰試験**：範囲の 11 本は HEAD で通る。

### 範囲の外で気づいたこと

- 旧 `setVmc`（`B747.60.xt.fltInst02.lua:2323`、本家の式）の「Vmc+10」を AFDS・A/T・VNAV の下限がまだ読む（EEC.lua:948、afds_control.lua:182、autopilot.lua:2760、vnavspd.lua:160）。フラップ UP・320 t 以上で琥珀の帯の上端より 10〜14 kt 低く、フラップ 30 では VREF30+4.5〜+10.4（200 t で +6.9）。`vmc_legacy.lua`。どの経路が今も効いているかは未確認。
- FCOM p.1311：CRZ CG は最大高度とバフェット余裕の計算に使う。コードは表示だけ（効きの数字は資料なし）。
- FCOM p.1319 の V1MIN（手で入れた V1 が下回ったときの表示）が見当たらない（既知の CDU-12 に含まれるかは未確認）。
- CDU のページのエラーは `print` 1 回だけで、ログにもエラーのファイルにも出ない（createfms.lua:843-847）。キットは PERF-3 の形を拾えない。
- FMC は acf の重心の範囲（`_cgZ_fwd`・`_cgZ_aft` ＝ 13.4〜33.1 % MAC）の外も書く（記録で −0.856 m、範囲は −0.800 m）。X-Plane は止めない。

### 見られなかった所

- `pred_model` の性能の計算（上昇・降下の積分、風、E/O）と `perf_db` の巡航モデルの当てはめ。性能計測（PERF_SIMBRIEF）の結果に任せた。
- 離陸速度の区分の図の境界の座標と、高度の補正の多角形。絵で大づかみに見ただけ。
- GE の表の全数の突き合わせ、RR（資料なし）。
- X-Plane での確認は全部。特に PERF-1 の「60 秒後の跳び」、PERF-3 の空白、PERF-7 の警報。
- `wb_window.c` は式を読んだだけ（組み直していない）。
- 記録の燃料のタンクごとの量（PERF-1 のモデルと記録の 0.2〜0.4 % MAC の差の原因）。

# 第 1 波 担当 4：カスタム acf のパネルと 3D が読む範囲（PNL-n）

## 担当 4 報告：カスタム acf のパネルと、3D が読む dataref の範囲（PNL）

リポジトリは変えていません（git は読むだけ）。例外の道具で FCOM p.939 を絵にしました（`_ref/text/img/FCOM/p0939.png`、git の管理外）。X-Plane には触っていません。スクリプトと出力は `D:\b747_review\stage4\a04_panel\` にあります。

- 計器の表：`panel_parse.lua` → `elements.tsv`（全 6,974 個）、`unflat.tsv`（端が平らでない 1,258 個）。
- 補助の走査：`kf_order.lua`（降順・非単調の key frame）、`show_gaps.lua`（SHOW の帯のすき間）、`and_groups.lua`（入れ子にした条件）、`multi_show.lua`、`kf_curve.lua`。
- 過去の写真の測り：`crop.ps1`・`col.ps1`・`line.ps1`（PowerShell ツールから `&` で呼ぶ）。写真はどれも段 1〜3 の後の回（2026-11-20〜23）。

### 指摘

#### PNL-1　F/D のピッチのバーが、指令どおりでも記号からずれ、ピッチ 10° で 12.5 px 跳ぶ（型 F・G）
- 場所：`747-400_custom.acf:75045-75071`・`79331-`（機長）、`83606-`・`87849-`（副操縦士）。値は `B747.19.xt.afds_control.lua:468, 615`。純正 acf も同じ（本家から）。
- 作り：
  - `GROUP Flt Dir Offset`（ピッチで上下）の key frame が降順で、真ん中が 0° でなく 1°（`10 → -68.5 / 1 → 0 / -10 → 68.5`）。
  - バーのポインターは `-10 → -68.5 / 0 → 0 / 10 → 68.5`。
  - バーの絵（`FDbarVertical-1.png` 171×19）は、線が中心より 6 px 下。
  - X-Plane は、降順の表の最初の点より上（ピッチ > 10°）では最後の区間（1 → −10）の線を延ばす。
- 何が起きるか（ピッチ＝指令のときのバーの位置。`fd_bar.lua` → `fd_bar.txt`）：

  | ピッチ | 2.5° | 5° | 7.5° | 9.99° | 10.01° | 12.5° | 15° | 17.5° |
  |---|---|---|---|---|---|---|---|---|
  | 記号から（px） | −0.3 | −2.2 | −4.1 | −6.0 | +6.5 | +8.0 | +9.6 | +11.1 |
  | 度に直すと | −0.04 | −0.32 | −0.60 | −0.88 | +0.95 | +1.18 | +1.40 | +1.63 |

  - 250 kt の上昇（7〜10°）では、A/P が指令どおりでもバーが翼の記号の下の縁まで下がる。
  - 10° をまたぐと 12.5 px（1.8°）跳ぶ。
  - 離陸の後（12〜17°）は上に 1.2〜1.6° ずれる。バーを真ん中に合わせて手で飛ぶと、指令 15° で 16.5° になる。
- どう確かめたか：`tests/flight/runs` の写真 5 枚を測り、その時刻の `session.csv` と比べた。

  | 回・写真 | ピッチ | 指令 | 測った px | この模型 | 最初の区間を延ばした場合 | 正しい位置 |
  |---|---|---|---|---|---|---|
  | s108 `shot_41`（20261120_222740） | 9.12 | 9.16 | −5.2 | −5.1 | −5.1 | +0.3 |
  | s198 `shot_92`（20261121_061714） | 9.75 | 10.06 | −3.0 | −3.7 | −3.7 | +2.1 |
  | s109 `shot_54`（20261122_101624） | 16.04 | 16.31 | +10.0 | +12.1 | −8.7 | +1.8 |
  | s104 `shot_80`（20261120_215919） | 14.5 | 12.92 | −1.5 | −1.6 | −20.2 | −10.8 |
  | s120 `shot_73`（20261120_234451） | 13.4 | 12.19 | −0.9 | +0.3 | −16.9 | −8.2 |

  s104 と s120 のピッチは写真の目盛から読んだ（写真は記録の時刻より約 1 秒早い）。
- 根拠：FCOM p.980 (10.10.18)「flight director pitch and roll steering commands」。
- 重さ：乗員に見える誤り（毎回の上昇と離陸）。確かさ：確か。
- シナリオ案：s108 と同じ FLCH の上昇を、ピッチ 5°・9.5°・11°・15° になる重さと速度で。A/P CMD で `pitch_AHARS_deg_pilot` と `flight_director_pitch_deg` の差が 0.1° 以内のときに PFD を寄せて撮る。合格はバーが記号の中心から ±1.5 px。10° をゆっくりまたいで跳ばないこと。
- 直す案：グループを昇順の 1 本の線に（`-30 → 204.33 / 30 → -204.33`）。ポインターは絵のずれの 6 px を足して `-30 → -198.33 / 30 → 210.33`。4 か所とも。

#### PNL-2　主 EICAS の ΔP の数字が 8.8〜8.9 psi で消える。巡航の ΔP がちょうどその境（型 G）
- 場所：`747-400_custom.acf:151975-152040`、`B747.55.press_model.lua:33-36`（`CRUISE_DP = 8.8`）、`B747.55.xt.press.lua:190`。
- 作り：数字は色ごとの 4 個で、白は −0.49〜8.8、琥珀は 8.9〜9.0、赤は 9.1 以上、低い側の琥珀は −0.5 以下。8.8〜8.9、9.0〜9.1、−0.5〜−0.49 はどれも出ない（`show_gaps.lua`）。
- 何が起きるか：
  - 巡航で ENG か ECS を出すと ECS のブロックが出る。ΔP は 8.8 の上と下を行き来するので、数字が出たり消えたりする。
  - ブロックを自動で出す条件は ΔP 8.85 以上なのに琥珀の数字は 8.9 から。8.85〜8.9 では数字の無いブロックが出る。
- どう確かめたか：`press_dp_gap.lua` → `press_dp_gap.txt`（与圧のモデルを離陸から回し、32 ビットの値で SHOW を判定）。
  - FL330〜450 の水平飛行：ΔP は 8.800002 に落ち着き、白の条件（8.8 以下）を外れる。
  - 高度が ±5 ft 揺れる（40 秒周期）：ΔP 8.7992〜8.8007、数字が消えるのは時間の 50 %。
  - ステップ上昇（FL350 → 390、800 fpm）：300 秒のあいだ 8.80〜8.84 で、ずっと消える。
  - X-Plane では未確認。空中開始の s280（20261122_124122）の写真は 8.8 が出ている。s15 の空中開始は 8.783〜8.786。
- 根拠：FCOM p.586 (2.10.34)「White - normal range. Amber - above normal range. Red - excessive」（出ない帯は無い）。ブロックの条件は p.585 (2.10.33)。
- 重さ：乗員に見える誤り（ふつうの巡航で ENG・ECS を出したとき）。確かさ：モデルでは確か、X-Plane は未確認。
- シナリオ案：地上から FL370 まで上昇して 10 分水平、ENG を押す。`pressure_diffential_psi` を 1 秒ごとに 3 分読み、10 秒ごとに主 EICAS を撮る。合格は全部の写真に ΔP の数字。
- 直す案：帯をつなぐ（白 −0.4999〜8.8499、琥珀 8.85〜9.0999、赤 9.1 以上）。境は Lua の 8.85 とそろえる。

#### PNL-3　EGT の限界の線が、テープの目盛の上で 19〜40 °C 低い所にある。GE の始動限界の線はテープの外（型 F）
- 場所：
  - P&W：テープ `747-400_custom.acf:145851-145990`（POS y 596.5、`0 → -55.5 / 690 → 55.5`）、線 `145996`（琥珀 y 638）・`146082`（始動 y 626）・`146168`（赤 y 642）。
  - GE：テープ `146252-`（POS y 670.5、`0 → -55.5 / 960 → 47.5`）、線 `146409`（y 710）・`146495`（y 781）・`146581`（y 716）。
  - 限界の値：`B747.40.engine_display_model.lua:28-32, 85-89`。純正 acf も同じ。
- 何が起きるか（`limit_lines.lua` → `limit_lines.txt`）：

  | テープ | 線 | 線の位置（テープの目盛で） | 色が変わる値 | ずれ |
  |---|---|---|---|---|
  | P&W EGT | 赤 | 628 °C | 654 | −26 °C（−4.2 px） |
  | P&W EGT | 琥珀 | 603 °C | 629 | −26 °C |
  | P&W EGT | 始動 | 528 °C | 535 | −7 °C（合っている） |
  | GE EGT | 赤 | 941 °C | 960 | −19 °C |
  | GE EGT | 琥珀 | 885 °C | 925 | −40 °C |
  | GE EGT | 始動 | テープの上端より 64 px 上 | 750 | テープの外 |
  | GE N1 | 赤 | 116.0 % | 117.5 | −1.5 % |
  | GE N2（ENG ページ、`153240`） | 赤 | 105.4 % | 112.5 | −7.1 % |

  - P&W の全開の離陸は TAT 33 °C で EGT 607 °C、40 °C で 622 °C（`egt_max.lua`）。白いバーが琥珀の線を越え、40 °C では赤線の 0.9 px 下まで来るが、数字は白のまま。
  - GE の始動限界の赤い線（y 781）は、N1 のテープの下端（y 793.5）と EGT の枠の上（y 772.5）のあいだに浮く。FUEL CONTROL が CUTOFF か始動中の間ずっと。
  - RR は P&W のテープを使い、限界 785・733・600 °C はテープの上端（634 °C）の外。資料なし。
- どう確かめたか：
  - テープの塗りの上端＝POS＋key frame を s279（20261123_210052）の写真で確かめた：N1 84.0 で +21.3 px（計算 +21.0）、EGT 348 で +1.5〜2.0（+0.5）。
  - 同じ写真のエンジン 1（EGT 659、限界を 5 °C 超え）は、赤いバーが赤線の 4.5〜5 px 上（計算 5.0。線が 654 にあれば 0.8）。
  - GE の位置は計算だけ（GE でエンジン停止中の写真が無い）。
- 根拠：FCOM p.838 (7.10.10)：赤線は takeoff EGT limit、琥珀の帯は continuous limit、表示は限界に届くと色が変わる。GE の値は ATA70_80 p.395（ノートから）。P&W の値は資料なし（前のコードの値）。
- 重さ：乗員に見える誤り（P&W は暑い日の離陸、GE は始動のたび）。確かさ：P&W の EGT は確か、GE はたぶん。
- シナリオ案：
  1. GE のリバリーで地上・エンジン停止（電源あり）、主 EICAS を寄せて撮る。合格は始動限界の赤い線が EGT のテープの上、不合格は N1 のテープと EGT の枠のあいだ。
  2. P&W、海面 40 °C で全開の離陸。`display_EGT` が 600〜628 のときに撮る。合格はバーが琥珀の線の下。
- 直す案：線の絵は動かさず、テープの key frame を線に合わせて折る。P&W は `0 → -55.5 / 535 → 29.5 / 629 → 41.5 / 654 → 45.5 / 700 → 52.9`、GE は `925 → 39.5 / 960 → 45.5`。GE の始動限界の線は y 695.5 へ、GE の N1・N2 の赤線は 117.5・112.5 の位置へ。

#### PNL-4　P&W・RR：逆推力のあいだ、指令 EPR の白い印が 4 発とも消える（型 I）
- 場所：`747-400_custom.acf:144471-144473`（RR）、`144537-144539`（P&W）：`GROUP Thrust Command EPR and 1` の `SHOW_LESS 0.9 sim/cockpit2/annunciators/reverser_deployed`。
- 経緯：
  - 純正 acf は 1 つのグループに `reverser_deployed` と `engines/type` の 2 行で、効くのは後ろの型式だけだった。
  - 5-2 段 7（41c7a9b9、`panel_show_and.lua`）が入れ子にして、眠っていた条件が効くようになった。
  - GE の組（`145775`）は FCOM どおり。
- 何が起きるか：P&W の着陸の滑走で逆推力を出すと、基準 EPR の線に加えて指令 EPR の印も消える。どれか 1 発の逆推力で 4 発とも。
- どう確かめたか：s340 `shot_51_eicas_reverse_full_close`（20261122_090845）に白い印が無い。前進推力の s279 の写真にはある。
- 根拠：FCOM p.832 (7.10.4)：570 は「command N1・reference N1 を出さない」、109・405 は「reference EPR is not displayed」だけ。p.833 (7.10.5) の図は、REV のエンジン（EPR 1.01）のバーの端に印がある。58a70e1d のコミットとノート §22 もこの図を挙げている。
- 重さ：乗員に見える誤り（毎回の着陸）。確かさ：確か。
- シナリオ案：s340 に足す。逆推力いっぱいで `engines/TRA[0..3]` と `display_EPR[0..3]` を読み、写真を撮る。合格は白い印が各バーの端（差 0.02 以内）。
- 直す案：P&W・RR の 2 組から外側のグループの条件を外す。あわせて EEC が逆推力の間の `TRA` に逆推力の指令の EPR を出すこと（今は前進のレバー＝アイドルの指令なので、外すだけでは印が目盛の下端に行く）。

#### PNL-5　GE：指令 N1 の印が 31 % で止まり、地上アイドルで N1 のバーの上に浮く。目盛もテープと違う（型 G・F）
- 場所：`747-400_custom.acf:145775-145840`（POS y 883.5、`-100 → -67 / 31 → -67 / 116 → 102 / 200 → 102`）、テープ `144799-`（POS y 890、`0 → -130 / 117.5 → 100`）、`B747.42.xt.eec_thrust.lua:39`（GE のアイドルの指令 25）。
- 何が起きるか（`limit_lines.txt`）：
  - 印は指令 31 % 以下で止まる。地上アイドルの N1 21.7 % のバーの端より 14 px（7 %）上、25.9 % なら 5.8 px 上。
  - 31 % より上では、印がテープより 1.6〜4.2 px（0.8〜2.1 %）低い。
  - テープの枠の下端は 17.1 % で、それ未満ではバーが出ない。
- どう確かめたか：s237 `shot_28`（20261121_104822、N1 21.7）で、白い印がバーの上に離れて浮いている（`s237_ge_n1_crop.png`）。s77 `shot_16`（20261122_025224、N1 14.4）ではバーが無く、印だけがある。
- 根拠：FCOM p.835 (7.10.7)、p.873 (7.20.3)「equals actual N1 RPM when the engine is stabilized」。
- 重さ：乗員に見える誤り（GE の地上アイドルで毎回）。確かさ：確か。58a70e1d の「GE は既に端で止まる」は 31 % と 116 % で、目盛の端ではない。
- シナリオ案：GE、地上アイドルで 30 秒おいて `TRA[0]` と `display_N1[0]` を読み、撮る。合格は印がバーの端から ±2 px。
- 直す案：印をテープと同じ POS と key frame に（y 890、`0 → -130 / 117.5 → 100`、両端を平らに）。EEC は表示用の指令をアイドルの N1 で下から止める。

#### PNL-6　PFD のスリップ／スキッドの印に端が無い。横風の滑走でバンクの針から 43 px 離れた（型 G）
- 場所：`747-400_custom.acf:74613`（機長）、`78899`・`83174`・`87417`：`sim/cockpit2/gauges/indicators/sideslip_degrees`、`-10 → -20 / 0 → 0 / 10 → 20` の 3 点だけ、CLIP なし。
- 何が起きるか：値に比例してどこまでも動く。20 kt の横風の滑走（133 kt）で、印（幅 26 px）がバンクの針の真下から 43 px（幅の 1.6 倍、バンクの目盛の 10° と 20° のあいだ）へ出た。
- どう確かめたか：s116 `shot_82_pfd_rollout_xwind`（20261120_232107）で、印の中心 x 1014.8、針の中心 x 968.5（`line.ps1`）。そのとき `flightmodel/position/beta` は −7.1°、`g_side` は 0.00〜0.03。印は β の約 3 倍ぶん動いている（X-Plane の値の決め方は不明）。s117（β −0.9°）は約 2 px。
- 低速は未確認：速度が落ちると β は増える（40 kt で 26°）。同じ比なら姿勢表示の外まで出る。
- 根拠：FCOM p.975 (10.10.13)「fills solid white when fully displaced」（動きに端がある）、p.977 (10.10.15)。端の幅は資料なし。
- 重さ：乗員に見える誤り（横風の着陸と地上走行）。確かさ：133 kt の 43 px は確か、低速はたぶん。
- シナリオ案：地上で機首から 90° の風 15 kt、10 kt で走行と停止。`sideslip_degrees` を読んで PFD を撮る。合格は印が針の下から印の幅 1 つ以内。
- 直す案：両端を平らに（例：±13 px）。値の倍率も合わせる。

#### PNL-7　STAT のラダーの針：目盛の端が 25° で、全舵角 32° では 23 px 外へ出て「RUD」の字に重なる（型 F・G）
- 場所：`747-400_custom.acf:157771-157797`（`-25 → -82 / 25 → 82` の 2 点）、`B747.19.xt.hydraulicsmodel.lua:412-416`（ペダルで ±32°、ヨーダンパー ±4°）、`B747.19.xt.hydraulics_override.lua:207-208`（上限なし）。
- 何が起きるか：地上でペダルいっぱいにすると針は ±105 px（目盛の端は ±83）。左いっぱいでは針が「RUD」の字の上と下に来る。ヨーダンパーが乗ると 118 px。
- どう確かめたか：計算（`limit_lines.txt`）。s24 `shot_23_stat_rudder_trim`（20261121_112608）は 25.6° で針が目盛の右端にある。32° の写真は無い。
- 根拠：FCOM p.939 (9.10.13)「Full pointer deflection indicates full control surface displacement」。ATA27 p.634・p.658（低速で 32°）、p.682（31.5 ± 1.5°）。
- 重さ：乗員に見える誤り（操縦系統の点検）。確かさ：確か（計算）。
- シナリオ案：s24 に足す。地上・油圧あり、ペダル左いっぱいで `rudder_upr_pos` が −31 以下になったら STAT を撮る。合格は針が目盛の左端。
- 直す案：`-32 → -82 / 32 → 82` にして両端を平らに。

#### PNL-8　STAT の HYD TEMP が巡航で負になる。数字に符号が無い（型 F・G）
- 場所：`B747.19.hyd_model.lua:66, 319-323`（油温＝外気温＋ポンプ運転で 30 °C、600 秒の遅れ）、`B747.19.xt.hyd_power.lua:155`、パネルの `gen_LED LED Temp 1〜4`（`747-400_custom.acf:157127-`、3 桁、符号の部品なし）。
- 何が起きるか：
  - 地上は 45 °C。FL350（外気 −54 °C）に上がると 10 分で 1 °C、20 分で −15 °C、40 分で −23 °C、落ち着いて −24 °C（`hyd_temp_cruise.lua`）。
  - パネルの数字は符号を描かない（TAT・燃料温度・客室昇降率には別に NEG の絵がある）。STAT は「24」前後と出るはず。
  - 同じ形：寒い空港の cold & dark では、油温・EGT・APU EGT も外気温の負の値がそのまま入る。
- 根拠：FCOM p.1485 (13.10.3)：HYD TEMP は °C、表示例は 50・50・50・108。負の値は資料なし。
- 重さ：乗員に見える誤り（巡航で STAT を出したとき）。確かさ：値は確か（モデルを回した）、符号なしで出るかはたぶん。
- シナリオ案：FL350 で 40 分巡航して STAT を押し、`hydraulics/temp_1` を読んで撮る。合格は表示が物理的にありうる正の温度。
- 直す案：系統の担当へ。油温の基準を外気温でなくタンクの燃料温度に（ノート ATA-29 §4.9 の方針どおり）。パネルは負の値に NEG の絵を足す。

#### PNL-9　STAT の左内側エルロンの針：key frame が「20・0・20」で、上げ側の点が無い（型 G、未確認）
- 場所：`747-400_custom.acf:157885-157897`（`20 → -73 / 0 → -0.5 / 20 → 72`。右は `20 / 0 / -20`）。純正 acf も同じ。
- 何が起きるか：負（上げ）の値はどの区間にも入らない。PNL-1 で見た延ばし方（最後の区間）だと、−20° でも −73 px（下げと同じ向き）へ行く。最初の区間を延ばすなら正しく上へ行く。
- どう確かめたか：読んだだけ。s33 は操縦輪を右へしか切っていない（左内側 +20° で針は下：写真のとおり）。
- 根拠：FCOM p.939 (9.10.13)。
- 重さ：軽い。確かさ：未確認。
- シナリオ案：s33 に足す。`yoke_roll_ratio = -0.5` で `l_aileron_inner` が −19.9 以下になったら撮る。合格は左内側の針が上端。
- 直す案：3 点目を `-20 → 72` に。

#### PNL-10　EGT の数字は 3 桁。EGT 高の故障で 1000 °C を超える（型 G、故障のときだけ）
- 場所：`747-400_custom.acf:146953-`（P&W）、`147425-`（GE）：`0 → 0 / 999 → 999`、DIGITS 3。`B747.42.egt_model.lua:151-167`。
- 何が起きるか：離陸推力で EGT 高の故障を続けると、P&W は 1137〜1206 °C、GE は 1391〜1523 °C（`egt_max.lua`）。X-Plane の LED は桁を超えると下の桁を出す（MCP 高度の下 3 桁がその作り）ので、「137」などと出るはず。
- 根拠：資料なし（1000 °C 以上の出方）。
- 重さ：軽い。確かさ：値は確か、出方はたぶん。
- シナリオ案：s279 の故障を離陸推力で 5 分続け、`display_EGT[0]` が 1000 を超えたら撮る。
- 直す案：`999 → 999 / 1000 → 999` を足して 999 で止める。

#### PNL-11　STAT の SPL の目盛に針が 2 本ずつ（FCOM の図は 1 本ずつ）（型 外）
- 場所：`747-400_custom.acf:157813`（`spoilers[6]`）、`157841`（`spoilers[7]`）。
- 何が起きるか：左の SPL にスポイラー 4 と 6、右に 7 と 12 の針が出て、蝶ネクタイの形になる（s24 `shot_33`、`s24_spl_crop.png`）。
- 根拠：FCOM p.939 (9.10.13) の図（絵にして確かめた）：左の SPL は右向きの針 1 本、右は左向きの針 1 本。FCTL-19 は外側をスポイラー 4・12 に直したが、内側の 2 本が残っている。
- 重さ：軽い。確かさ：確か。
- 直す案：内側の 2 本を消す。

### 段 1〜3 の直しを見た結果

- **58a70e1d**（EPR の指令の印を目盛の両端で止めた）：直しそのものは問題なし。
  - 8 本とも REF の印と同じ 4 点の形で、両端の傾きは 0。
  - `git diff 7b62803b^ 3a16a46c -- 747-400_custom.acf` のパネルの変更はこの 8 本だけ。純正 acf は変わっていない。
  - 残り：PNL-4（逆推力で印が消える）、PNL-5（GE の印は 31 % で止まり地上で浮く）。
- **dfbbf7d4**（安定板）・**c468736b**（ブレーキ）：問題なし。
  - acf の変更は `_stab_trim_up`、wing 8・9 の incidence、`_brake_co` だけで、パネルの行は無い。
  - 3D のトリムの指標は `elevator_trim` −1〜1 のままで、units の写し方は変わっていない。

### 見て問題が無かった所

- 端が平らでない計器のうち、値が範囲を出ないもの：
  - フラップのテープ（`fcu_model` が 0〜1 に収める）、エレベーター、外側・右内側エルロン。
  - 振動（最大 1.73）、F/D のロール（±25 で止める）、GE の N1 の REF・MAX、P&W・RR の EPR の REF・MAX。
- 速度テープと高度テープのバグは CLIP のあるグループの中。速度バグと高度バグは Lua が端に寄せる。20 ft のドラムは `KF_WRAP`。
- CLIP の無いテープ（N2・N3・フラップ）は範囲を出ない。
- 違う dataref の SHOW が 2 行残る部品は 0 個。入れ子にした 130 個は PNL-4 のほか FCOM と食い違わない。
- SHOW の帯のすき間は PNL-2 のほか 0.01 幅だけ（油温、客室高度、タイヤ圧）。
- 3D が読む値（スロットル、逆推力レバー、スピードブレーキ、フラップ、ブレーキ、ラダー）は key frame の範囲の内か、端が平ら。

### 範囲の外で気づいたこと

- 外装の安定板の 3D は `elevator_trim` −1〜1 で 0〜−6° しか回らない（飛行モデルは 15°）。
- バンクの針は ±45° で止まる（本家から。45° を超えたときの出方は資料なし）。
- 「NO V SPD」と V1・VR は電波高度 10 ft 未満で判定していて、フレアの 10 ft から出る。
- GE の EGT の白い数字は `display_N1 >= 0.03` のときだけ出る（本家から）。

### 見られなかった所

- ND の記号の位置（px を Lua が書く約 1,000 個）と ND の切り抜き。表示の担当の範囲と重なるので、key frame の形だけ見た。
- CDU と EICAS の文字（`gen_text` 1,555 個）の長さ。
- 絵のコマを選ぶ `gen_rotary` が、値がコマ数を超えたときにどうなるか。
- 負の値と桁あふれのときの LED の出方、負の高度の回転数字は X-Plane で見ていない（FCOM に記載なし）。
- FUEL・ELEC・ECS・HYD・DRS・GEAR の synoptic は、ポインターと LED の形だけ見た。
- RR の表示は PNL-3 の表だけ。時間加速は見ていない。

# 第 1 波 担当 5：EEC・エンジン（ENG-n）

## 担当 5（EEC・エンジン）報告：段 4 フルレビュー（HEAD 807956a2）

指摘は 7 件です。重いのは ENG-1（P&W の離陸・着陸復行の推力が FPPM より 9〜25 % 多い）と ENG-3（GE の D-TO の基準 N1 が TO より高くなる）です。

リポジトリは変えていません。X-Plane は起動していません。スクリプトと出力は `D:\b747_review\stage4\a05_eec\` にあります。リポジトリの直下を作業ディレクトリにして `luajit D:/b747_review/stage4/a05_eec/<名前>.lua` で回し直せます。`_ref/text/img/FPPM/` に p.29・p.30・p.75 の絵を足しました（許された道具）。

---

### 指摘

#### ENG-1　P&W の離陸・着陸復行の推力が、FPPM の上昇勾配の図から出る推力より 9〜25 % 多い（型 F）

- **場所**：`plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua:30-40`（`STATIONS`）、`:58-69`（`kq`）。
- **何が起きるか**：
  - EPR の式は、M 0（静止）と M 0.438（290 KIAS の水平と上昇、EPR 1.25 まで）の間を直線で補っている。離陸・着陸復行の EPR 1.46〜1.67 は外挿になる。
  - その結果、全開の離陸で 1 発の推力が 60 kt から浮揚後 188 kt まで 234〜236 kN のまま（静止の 93 %）で、速さで減らない。
  - 片発の上昇勾配、離陸の加速、初期上昇が実機より良すぎる。
  - 高い空港ほど開く（下の表）。
- **どう確かめたか**：
  - FPPM p.75 の図を画素で読んだ（切り出しは `fppm_p75_*.png`）。250 t の基準線の勾配と、重さの案内線の当てはめ「勾配 = A/W − B、B = 0.111（線により 0.105〜0.116）」。
  - 図の例（6,000 ft・28 °C の 9.6 % → 274 t で 7.74 %）は、この式で 7.79 % になる。
  - p.30 の上昇制限（海面・30 °C で 437.5 t）にこの式を当てると 3.2 %。第 2 区間の 3.0 % と合うので、読みは整合している。
  - `eo_gradient.lua` と `ga_thrust_models.lua`（出力は同名の `.out`）で、図が求める 1 発の推力と 2 つの式を比べた（着陸復行の定格、150 KIAS、OAT 10 °C）：

| 気圧高度 | 図の勾配（250 t） | 図からの推力 | P&W の EPR の式 | 比 | GE の N1 の式 | 比 |
|---|---|---|---|---|---|---|
| −2,000 ft | 14.51 % | 212.3 kN | 231.6 kN | 1.09 | 206.7 kN | 0.97 |
| 0 | 14.0 % | 208.1 | 235.2 | 1.13 | 202.8 | 0.98 |
| 2,000 | 12.93 % | 199.4 | 229.7 | 1.15 | 195.6 | 0.98 |
| 4,000 | 11.78 % | 190.0 | 223.6 | 1.18 | 186.7 | 0.98 |
| 6,000 | 10.79 % | 181.9 | 220.1 | 1.21 | 178.6 | 0.98 |
| 8,000 | 9.65 % | 172.6 | 212.8 | 1.23 | 170.1 | 0.99 |
| 10,000 | 8.50 % | 163.2 | 203.1 | 1.25 | 159.3 | 0.98 |

  - GE の空中の N1 の式は、どの高度でも図と 3 % 以内で合う。P&W の式だけが外れている。
  - X-Plane の記録でも同じ：`s326_eo_takeoff_accel_heavy_hot`（2026-11-22 10:43 の回。P&W、357.5 t、1,523 ft、海面 30 °C、フラップ 20、脚上げ、エンジン 2 停止）の 120〜140 秒。
    - 上昇 5.77 % ＋ 加速 2.20 % ＝ **7.97 %**。図は同じ重さ・高度で **5.7〜6.1 %**。
    - 推力の合計は 690 kN、揚抗比は 8.55（図の当てはめは 8.6〜9.5）。機体の抵抗は図と同じか多い側なので、差は推力の側。
    - 11-21 21:37 の回も 8.04 %。
  - `s109`（11-22 10:16、P&W、270 t）の全開の離陸は 188 kt で 1 発 235 kN。同じ条件の GE の `s325`（11-22 13:11）は 190 kt で 214.5 kN。
- **根拠**：FPPM p.75 (1.4.5)、FPPM p.30 (1.2.6)、FPPM p.19（上昇制限は第 2 区間で決まる）。第 2 区間の 3.0 %（4 発機）は資料の外の値（FAR 25.121）。FPPM は貨物機だが、エンジンは同じ PW4056。
- **重さ**：乗員に見える誤り（性能）。**確かさ**：たぶん（図は画素の読み、B の幅で勾配 ±0.2 %）。
- **シナリオの案**：
  - P&W、250 t、海面 15 °C、フラップ 20・脚上げ、1 発を CUTOFF、残り 3 発を全開、VREF30+5（約 150 KIAS）で 60 秒。
  - 見る値：高度の増え方 ÷ TAS ＋ 加速 ÷ g。図は 14.0 %（2,000 ft なら 12.9 %）、今の見込みは約 16.7 %。合否は図の ±0.7 %。
  - 6,000 ft の空港でも（図 10.8 %、見込み約 14.9 %）。
  - `s326` の記録は、そのまま `eo_gradient.lua` で確かめ直せる。
- **直す案**：`STATIONS` に M 0.22〜0.28 の点を足す（図の勾配と、その形態の機体の抵抗から出した推力）。静止の 252.4 kN・EPR 1.51 はそのまま。直すと、推力の上げ（`BOOST_MAX`）はほとんど要らなくなる見込み。

#### ENG-2　P&W の離陸の定格を着陸復行の表で代用している：FPPM の Takeoff EPR の表と平均 +0.026 EPR（型 F）

- **場所**：`B747.42.eec_model.lua:305-332`（注釈「the FCOM has no normal-mode takeoff table」と `TABLE.PW.ga`）、`:1079-1080`、`B747.42.ref_thrust_model.lua:82-92`・`:47-60`。
- **何が起きるか**：FPPM には通常モードの離陸 EPR の表がある（全推力、TO1 8 %、TO2 20 %）。コードは着陸復行の表を TAT ＝ OAT で読み、減格は EPR の式の静止の則で作るので、次のようにずれる。
  - 全推力（145 ます）：平均 +0.026、rms 0.037。
    - 海面 30 °C 以下は一致。
    - 海面 35〜50 °C で +0.01〜+0.02。
    - 5,000〜10,000 ft で +0.02〜+0.04（例：5,000 ft・25 °C は 1.59 対 1.56）。
    - FAOR（5,214 ft・24 °C）は EEC の最大 1.590、FPPM は約 1.563。
  - 仮定温度が 54 °C より上では減らない：表が TAT 54 で終わり、その値を保つため。
    - 海面で SEL 60・65・70 はコード 1.38 のまま、FPPM は 1.32・1.29・1.25。
    - 減り方は 21.3 % で止まり、25 % の上限に届かない。
  - TO 1：平均 +0.035（海面 1.460 対 1.45）。TO 2：平均 +0.042（海面 1.388 対 1.36、10,000 ft・15 °C で +0.07）。
  - FPPM の 3 つの表からは、静止の則は推力 ∝ (EPR−1)^0.55〜0.67。コードは 0.8136（地上アイドルの推定の点から）。
  - 乗員には、THRUST LIM と EICAS の離陸の基準 EPR・最大 EPR の線が、FPPM と 0.01〜0.07 違って見える。
- **どう確かめたか**：`to_epr_vs_fppm.lua`（`.out` に 3 つの表の全ます）。着陸復行の表を OAT+3 で読むと、FPPM の全推力の表と平均 +0.005 まで寄る（暑い側の差は、TAT と OAT の読み違いが主）。
- **根拠**：FPPM p.44 (1.2.20)、p.57 (1.3.11)、p.69。FCOM p.263 (PI.10.37)：着陸復行の表は TAT と REPORTED OAT の 2 列で、差は 3 °C。FCOM p.1273 (11.32.3)：仮定温度は最大 25 %。
- **重さ**：乗員に見える誤り（推力では 0〜+5 %）。**確かさ**：確か（表の突き合わせ。FPPM は貨物機の資料）。
- **シナリオの案**：オフラインで足りる。X-Plane なら、P&W の地上（FAOR 24 °C、RJAA 40 °C）で `display_EPR_max` と TO・TO 1・TO 2 の `display_EPR_ref` を FPPM の表の ±0.01 で見る。
- **直す案**：`TABLE.PW` に FPPM の離陸の 3 つの表を足し、地上の TO の系はそれを OAT で読む。空中は着陸復行の表へつなぐ。

#### ENG-3　GE の D-TO（仮定温度）の基準 N1 が TO より高い。TO 1・TO 2 の推力の減りも名目の 2/3（型 F）

- **場所**：`B747.42.ref_thrust_model.lua:87-90`（`hot` は SEL の温度の表の N1 をそのまま使う）、`:48-56`（GE の `less`・`ratio` は N1 の 3 乗）。
- **何が起きるか**：
  - GE の着陸復行の N1 の表は、角の温度（約 35 °C）まで温度とともに上がる。SEL の N1 を外気温へ換算していないので、D-TO の基準が TO より高くなる。
  - EEC の最大は TO のままなので、A/T は全開で止まり、推力は 1 % も減らない。
  - EICAS には「D-TO +45C」と、最大 N1 の線より上の基準が出る。FMC への「離陸の減り」は負になる。
- **どう確かめたか**：`ge_dto.lua` と、EEC のモジュールを試験のモックで動かす `ge_module_repro.lua`。海面・OAT 15 °C の GE：

| モード | 基準 N1 | EEC の最大 | FMC への減り |
|---|---|---|---|
| TO | 103.8 | 103.8 | 0 % |
| D-TO、SEL 30 | 106.4 | 103.8 | −7.7 % |
| D-TO、SEL 45 | 106.0 | 103.8 | −6.5 % |
| D-TO、SEL 50 | 105.3 | 103.8 | −4.4 % |
| TO 2（15 %） | 98.3 | 103.8 | +15.0 % |
| D-TO 2、SEL 45 | 100.4 | 103.8 | +9.5 % |

  - D-TO 2 に SEL を足すと、TO 2 だけより N1 が上がる。
  - OAT −10 °C・SEL 35 では 107.3（TO は 99.2）。
  - TO 1・TO 2 の基準（N1 × (1−x)^(1/3)）で実際に減る推力は、GE の N1 の式で −3.4 %・−10.3 %。FAOR の静止の回転上げの記録（`diag_hothigh_ge`、11-20）からは −3.1 %・−9.5 %。名目は −5 %・−15 %。
  - 回帰試験にもシナリオにも、GE の減格・D-TO の離陸は 1 本も無い。
- **根拠**：FCOM p.1273 (11.32.3)：実際より高い仮定温度を入れると離陸推力は減る、最大 25 %。GE の仮定温度の N1 の換算の表は _ref に無い（資料なし）。
- **重さ**：乗員に見える誤り（GE で仮定温度を使うと必ず出る）。**確かさ**：確か（基準が TO を超えること）。換算の正しい値は資料なし。
- **シナリオの案**：Saudia（GE）、RJAA 15 °C の地上で THRUST LIM に SEL 45。合否は `display_N1_ref[0]` が TO の値（103.8）以下。今は 106.0。そのまま TO/GA で離陸し、80 kt の `display_N1` が TO のときより低いこと。
- **直す案**：GE の `hot` を「SEL の表の N1 × √((OAT+273.15)/(SEL+273.15))」に（同じ修正 N1。推定と明記）。TO 1・TO 2 と減りの % は、GE の N1 の式の推力で。

#### ENG-4　GE の離陸の枝（X-Plane の N1 × 本家の係数）が空中の N1 の式とつながらない：TO を抜ける瞬間に表示が +4.5 % 跳ぶ（型 F・J）

- **場所**：`B747.42.xt.EEC.GE.lua:347-355`、`:504-513`・`:620`（`takeoff_TOGA_n1`）、`:66-114`（`take_off_N1_GE`）、`B747.42.xt.EEC.lua:609-676`（`take_off_thrust_corrected`）。
- **何が起きるか**：
  - 推力制限が TO の系（と地上の GA）の間だけ、表示の N1 は X-Plane の N1 × 本家の 3 次式の係数。ほかは FCOM に合わせた N1 の式。切り替えは 1 フレームで、ならしが無い。
  - 同じ推力で 2 つの値が違うので、推力減で CLB になった瞬間（接地からの着陸復行の浮揚でも）に N1 の数字が跳ぶ。最大 N1 の線も越える。
  - 同じ N1 で離陸の枝の推力は空中の枝より多い。
  - 既知の ENG-34（「段 3 の表示で」）には、この数字と跳びは無い。notes §15 の「跳ばない」は FAOR の B5F の 1 点で、そこではたまたま一致していた。
- **どう確かめたか**：
  - `ge_branch_gap.lua`：`s325`（11-22 13:11、Saudia B1F、RJAA）の記録の推力から、空中の式の N1 を出した。

| 条件 | 表示（離陸の枝） | 同じ推力の空中の式 | 差 |
|---|---|---|---|
| 95 kt | 103.6 | 109.7 | +6.1 |
| 161 kt | 104.1 | 110.0 | +5.9 |
| 1,180 ft・191 kt | 105.4 | 110.0 | +4.6 |
| FAOR 24 °C・静止（`diag_hothigh_ge`） | 109.3 | 109.1 | −0.2 |
| FAOR 24 °C・101 kt | 109.2 | 111.4 | +2.2 |

  - `ge_module_repro.lua`：`s325` の 89.6 秒の点をモックに入れて推力制限を変えると、TO は 105.5、CLB と GA は最初のフレームから 110.0（最大は 105.4）。
  - 推力：RJAA の 141〜161 kt で GE は 224〜227 kN、ENG-1 の図からは約 208 kN（+8〜9 %）。
  - 係数はリバリーの型式でも変わる（B1F 1.058、B5F 約 1.14）。
- **根拠**：FCOM p.873 (7.20.3)：最大 N1 は琥珀の線。指令は安定すれば実際と一致。離陸の枝の式の出典は無い（本家）。
- **重さ**：乗員に見える誤り。**確かさ**：跳びは確か（記録の値をモックで再現）。推力の差はたぶん。
- **シナリオの案**：Saudia、RJAA、270 t、全開の離陸から THR REDUCTION（か FLCH）で CLB へ。`display_N1[0]` を 20 Hz で記録し、合否は 1 フレームの変化が 1 % 未満。今の見込みは +4.5 %。
- **直す案**：離陸でも空中の N1 の式を使う（静止の錨は 57,160 lbf で 103.8 %）。ENG-1 を直した後に、GE の離陸の推力も図と比べる。

#### ENG-5　止めたエンジン（風車回転）と空中のアイドルの EPR が低すぎる：FCOM の図は 0.91、シムは 0.58〜0.80（型 F）

- **場所**：`B747.42.epr_model.lua:52-55`（`zero`）、`:80-89`（`epr`）、`:110-116`（`idle_command`）。表示は `B747.42.xt.EEC.PW.lua:399-407`。
- **何が起きるか**：
  - 式は、正味の推力 0 を「排気が外気圧（NPR 1）」に置くので、EPR は 1/(1+0.2M²)^3.5 まで下がる。
  - 止めたエンジンの EPR は、M.53 で 0.74〜0.80、M.745（FL250）で 0.58〜0.69、M.84 で 0.50〜0.63。
  - 空中のアイドルも 0.61〜0.68（利用者の 11-19 の写真の 0.62）。
  - 風車回転の N1 は 21〜23 %（X-Plane の値）。FCOM の図は 14.2 %。
- **どう確かめたか**：
  - `windmill_epr.lua`：式の値の表。
  - `s321`（11-21 20:47、全発停止）の記録：17,435 ft・268 KIAS で表示 0.737、式は 0.736。
- **根拠**：FCOM p.840 (7.10.12) の図（絵で確かめた）：巡航でエンジン 4 を止めた表示は、ほかの 3 発が EPR 1.51 のとき **0.91**、N1 14.2、EGT 57。EGT の 57 °C はモデルに使ってあるが、EPR の 0.91 は使っていない。アイドルの EPR は資料なし（燃えているアイドルが風車回転より低いことは考えにくい）。
- **重さ**：乗員に見える誤り（軽め）。**確かさ**：風車回転は確か、アイドルはたぶん。
- **シナリオの案**：P&W、FL250・M.745（TAT −8）で 3 発 EPR 1.51、エンジン 4 を CUTOFF して 2 分。`display_EPR[3]` が 0.91 ± 0.03、`display_N1[3]` が 14 ± 3。今の見込みは 0.6〜0.7 と 21〜23。
- **直す案**：水平飛行の点（EPR 0.96〜0.99）より下を、Mach によらず約 0.9 へ寄る単調な写しに。EEC のアイドルの端とレバーの不感帯も合わせ直す。

#### ENG-6　GE：22,000 ft より上で CON の基準が EEC の最大より上（既知の AT-10 の数字の追加）（型 J）

- **場所**：`B747.42.eec_model.lua:1085-1086`（`mct_share`）、`:1108-1114`。
- **何が起きるか**：1 発停止で CON にしても、全開のレバーが最大連続の表の N1 に届かない。
- **どう確かめたか**：`ref_vs_max.lua`。ISA で CON − 最大：

| 高度 | 200 KIAS | 240 KIAS | 280 KIAS |
|---|---|---|---|
| 25,000 ft | +5.4 % N1 | +4.9 | +2.2 |
| 31,000 ft | +3.2 | +3.3 | +2.4 |
| 35,000 ft | +1.8 | +1.8 | +0.1 |

  - 前のレビューの AT-10 は −0.1〜−1.25 %（軽い）としていた。遅い速さではもっと大きい。
- **根拠**：FCOM p.379–381 (PI.23.1–23.3) と ATA70_80 p.208 が食い違う（AT-10 のとおり、資料では決められない）。
- **重さ**：軽い〜乗員に見える誤り。**確かさ**：確か（数字）。
- **シナリオの案**：GE、FL310・240 KIAS、1 発停止、CON、全開。`display_N1` と `display_N1_ref` の差が 0.5 % 以内か（今の見込みは 3.3 % 届かない）。
- **直す案**：利用者の判断（乗員の見る値は FCOM を優先するなら、25,000 ft より上も最大連続の表を上限に）。

#### ENG-7　結果を使わない本家の計算が毎フレーム動く（型 外）

- **場所**：`B747.42.xt.EEC.PW.lua:503-596`、`B747.42.xt.EEC.GE.lua:504-578`、`B747.42.xt.EEC.lua:109-184`。
- **何が起きるか**：TO・CLB・CRZ・GA の枝の結果は、あとで `B747_eec_reference` と `B747_eec_max` に上書きされる。P&W は CRZ の間（飛行の大半）、毎フレーム、表を作って並べ替える処理を 2 回している。害は負荷とごみだけ。
- **どう確かめたか**：読んだだけ。
- **根拠**：CLAUDE.md「毎フレームの処理を重くしない」。
- **重さ**：軽い。**確かさ**：確か。
- **直す案**：枝ごと消す。GE の `takeoff_TOGA_n1` は ENG-4 と一緒に。

---

### 段 1〜3 の直しを見た結果

- **b134fbf1（逆推力のレバーの連動、P&W の逆推力 87 % N1）**：問題なし。
  - PW_PPM p.250 の表（「Selects N1 Mode、Schedules Idle Wf When Sleeves In Transit、Max Rev: 87% N1」）と p.197 の図を絵で確かめた。
  - `fwd_closed` の経路（全発・発ごとの hold、toggle）を読んだ。
  - `s340`（11-22 09:08）の写真で、逆推力の間は基準 EPR の数字と印が消え、REV が緑（FCOM p.832 のとおり。パネルの条件で消している）。
  - 残る端（軽い、未確認）：ハードのスロットルを前に残した A/T の着陸で、滑走中にそのレバーを動かすと、逆推力が格納に向かう。
- **16e396c8（P&W の全開の定格、折れ点、N2、fuel-on）**：問題なし。
  - PW_PPM p.196・p.204 を開いた（14,100 ft、72° と 82°、N1 111.4 %・N2 104 %）。
  - 折れ点 38° は p.196 の文のとおり。p.197 の図では最大上昇の点が 1 本の直線の上にあるので、折れの形は推定のまま。
  - 14,100 ft で最大 EPR の線が −0.21〜−0.27 段になる（`ref_vs_max.out`）。資料どおりだが、レバーが折れ点より前のときは指令も段になる。
  - CON の基準は、15,000〜43,000 ft の 612 点中 321 点で最大と同じ（EPR が赤になる）。今の規則どおり。
- **c30c5ef5（P&W の ALTN は N1 モード）**：問題なし。`eec_altn_test` 66 件が通る。lockup・ラッチ・ramp の分岐を読んだ。
- **77437918（`BOOST_MAX` 1.3）**：書いてあるとおりに動く。ただし、上げが要る根は ENG-1（指摘 ENG-1）。ALTN の全開は、海面では上限の 1.3 倍まで出る。
- **a465b930（上昇の減格の消え方）**：問題なし。FCOM p.1273 を開いた（405・570 は 10,000 ft まで保ち 15,000 ft で CLB、109 は 30,000・35,000 ft）。
  - `ref_thrust_model.lua:36-37` の注釈「estimate: the FCOM's 15,000 ft only」は、FCOM に 10,000 ft からと書いてあるので、推定ではない（注釈だけ）。
  - GE の CLB 1・CLB 2 の 3 乗根は、空中では N1 の式で −8.8 %・−18 % と合う（手計算）。
- **87a34b56（EICAS の仮定温度）**：問題なし。表示は TO の系で D- のときだけ。EEC の基準が SEL を使うのも TO の系だけ。GE の D-TO の値そのものは指摘 ENG-3。
- **df0378a8（`B747_epr_hold.lua` v4）**：問題なし。表は EEC の `PW.clb` と同じ。指令（TRA）で積分する。注意：防氷 ON やエンジンが指令に届かないとき、道具は気づかない。

### 見て問題が無かった所

- 表の写し（抜き取り）：
  - P&W の着陸復行（FCOM p.263、全部）、最大上昇と補正（p.262）、最大連続の補正（p.284）。
  - P&W の最大巡航の脚注（FPPM p.121・123・125・127）。
  - GE の着陸復行（p.360 の上 9 行）、GE の最大連続の暑い端の値（p.380 の 99.9・99.2・100.0 など）。
- アイドルの選択（FCOM p.877–878）、ALTN と A/T（p.876–877）。
- EGT のモデルの 4 点（p.840 の図の 490・57 を確かめた）。
- 逆推力の間の基準と指令の非表示（パネルの条件にある）。
- 始動のモデルとグルー、燃費の補正のグルー（読んだ）。
- `tests/run.sh eec`：9 本、806 件が通る。

### 範囲の外で気づいたこと

- 担当 2 向け：FCOM p.1314 (11.40.38) は「上限を超える SEL は、FMC が 25 % になる最大温度に書き換える」。CDU がそうしているかは見ていない。
- 担当 6 向け：`s326` の片発・フラップ 20・脚上げの揚抗比は 8.55。FPPM p.75 の当てはめは 8.6〜9.5（抵抗は図と同じか少し多い）。
- 試験の穴：GE の減格・D-TO の離陸、GE の離陸から推力減までの記録つきのシナリオ、暑い・高い空港の離陸 EPR を FPPM と比べる検査、片発の勾配を FPPM と比べる検査が無い。
- GE の巡航の燃料流量（未確認、1 点）：`s280`（FL370・M.851・237.8 t）は 1 発 2,054 kg/h。FCOM p.364 (PI.21.2) の 520,000 lb・FL370 は 4,318 lb/h（M.839）で、+2〜2.5 % ほど。燃費の補正は P&W だけ。

### 見られなかった所

- RR（`B747.42.xt.EEC.RR.lua` の全部。逆推力の間の EPR の赤も）。
- 表の全ますの写しの照合（抜き取りだけ）。
- オイル・振動の値、アイドルの推力の水準、B5F・B1F1 の型式の差。
- 始動のモデルの細部、変異の試験、X-Plane での確かめ。
- ENG-1 の全発の離陸の加速を、FPPM の滑走路長の図と比べること。

# 第 1 波 担当 6：操縦系統・空力・acf と換算（FCTL-n）

## 担当 6（操縦系統・空力・acf と換算）の報告

リポジトリと git には触っていません。スクリプトと出力は `D:\b747_review\stage4\a06_fctl_aero\` にあります。資料の絵は許された道具で `_ref\text\img\` に出しました。NASA_SIM の p0613・p0342 は読み取りのため解像度を上げて上書きし、FPPM の p0057・p0069 は新しく出しています。

指摘は 7 件です。重いのは FCTL-1（低い速さの縦の揺れ）と FCTL-2（推力の腕が改訂前の値）です。

### 指摘

#### FCTL-1　吹き下ろしの補正の後、低い速さ・高い迎角で A/P の縦の揺れが残っている（型 F）

- **場所**：`plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua:341-344`（DW_K 0.50）と、それを前提にする `plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.afds_control.lua:581-582, 654`（`AP_PITCH_RATE_K_MIN` 0.06）。
- **何が起きるか**：195〜240 kt・迎角 5.5〜8.6° で、A/P の縦が周期 4.3〜5.7 秒で揺れ続けます。
  - フラップ UP の機動速度の水平と降下、重い機体のフラップ 10→5 の加速で出ています。
  - PFD のピッチが ±0.5〜1°、荷重が ±0.06〜0.12 g 動きます。
  - f882eaee は巡航（notes/ATA-22.md §66 の回し直しは s263・s279・s215・s07・s53 など）で確かめた直しで、約 198 kt から上の利得を 0.06 にしただけです。220 kt では 0.044 → 0.06 にしかなりません。
- **どう確かめたか**：過去の記録を 8 秒ごとに区切って g の幅を見ました（`run_pitch_osc.sh`・`pitch_osc_scan2.awk` → `run_pitch_osc.out`）。

  | 回 | 状態 | 結果 |
  |---|---|---|
  | s198、11-03（段 3 の前） | 217 kt・UP・降下 | g の幅 0.000〜0.002 |
  | s198、11-21 06:17（c6f83604 の後、f882eaee の前） | 216 kt・UP・アイドルの降下 | 周期 4.35 秒、ピッチ 3.35〜5.31°、迎角 6.86〜8.73°、昇降舵 −2.90〜+0.72°、g 0.881〜1.116。38 区間のうち 37 で幅 0.08 超、フラップ 1 まで 4 分以上 |
  | s102、11-22 09:21（f882eaee 入り、38/0 で合格） | ALT HOLD・220 kt・UP・270 t | 周期 5.68 秒で振幅が一定：ピッチ 6.3〜7.45°、g 0.939〜1.052、ピッチの指令も 6.60〜7.03° で揺れる。140 秒以上 |
  | s326（382 t・片発・フラップ 10→5・200〜233 kt） | 11-13 → 11-22 06:16 → 11-22 10:43（f882eaee 入り、41/0 で合格） | g の幅 0.105（5 区間のうち 1）→ 0.394 → 0.267（周期 約 5.1 秒、g 0.86〜1.10） |

  - 230 kt・迎角 6.0° の降下（s206、11-22）は静かでした。
- **根拠**：資料に揺れの値はありません。段 3 の前の記録と比べました。
- **重さ**：乗員に見える誤り。到着のたびに通る速さです。**確かさ**：記録は確か。原因が吹き下ろしの補正と内側のループの組み合わせという点は「たぶん」（前後の比べから）。
- **シナリオの案**：
  - 270 t・3,000 ft・ALT HOLD・SPD 220 kt・UP で 120 秒、g の幅 0.03 以下とピッチの指令の幅 0.1° 以下。
  - 同じ形で `laminar/B747/debug/aero_dw_off` 1、`ap_pitch_rate_pct` 200 に切り替えて止まるかを見る。
  - 216 kt のアイドルの FLCH 降下、s326 のフラップ上げの区間（g の幅 0.1 以下）。
- **直す案**：変化率の利得の下限を速さの倍率にも掛ける（例：0.06 × g^1.5）か、250 kt から下で測って決め直す。ALT の則の CL の倍率（CL 0.60 以上で 1）も一緒に見る。利得は第 2 波の範囲です。

#### FCTL-2　推力の縦揺れの補正の腕が、資料の改訂前の値（型 F）

- **場所**：`B747.45.aero_corr_model.lua:364-383`（`TM_ARM_AIR`・`TM_ARM_GND`）、`tests/fltctrls/aero_corr_model_test.lua:73-76`、notes/AERO.md §3.25。
- **何が起きるか**：コードは NASA_SIM p.22 (1.1-3) の腕（内側 14.6／9.2 ft、外側 5.4／7.3 ft）を使っています。このページには「SEE SECTION 19 FOR REVISED DATA」の押印があります。
  - 改訂の p.613 (19.0-2) は、内側 8.3（空中）／8.5（地上）、外側 3.1／4.8 ft です（ΔZ_EO 1.7・ΔZ_EI 0.2 ft と合います）。
  - acf の腕（1.0・5.2 ft）との差は、空中でコードの 2.65 分の 1、地上で 1.45 分の 1 になります。
  - §3.26 の地面効果で決めた「19 章の改訂を先に見る」が、ここには当たっていません。
- **どう確かめたか**：p.22 と p.613 を絵で読みました（`nasa_sim_p0613_arms.png`）。数字は `thrust_arms.lua` → `thrust_arms.out`。

  | 状態 | コード | 改訂の腕 |
  |---|---|---|
  | 上昇の始め（210 kN・175 kt） | −1.84° | −0.70° |
  | 進入（60 kN・150 kt） | −0.72° | −0.27° |
  | 150 kt で 60 → 210 kN | −1.79° | −0.68° |

  - 着陸復行の機首上げは、X-Plane 自身の分を足して改訂の 1.75 倍です。
  - NASA_HQ p.219（図 IX-2）は推力線 WL 116・FRL WL 199.8（7.0 ft 下）で、改訂の平均 5.7 ft の方が形に合います。NASA_HQ の表 IX-4（p.236）の MDTH は腕 約 10 ft で、改訂前の値のままです。
- **根拠**：NASA_SIM p.613 (19.0-2)、p.612 (19.0-1)「Boeing が取り入れを勧める改訂」。どちらも -100 の値です。
- **重さ**：乗員に見える誤り（着陸復行・推力を変えたときの機首の動き、FLARE の絞りでの機首下げ）。**確かさ**：資料の食い違いは確か。X-Plane での効きは計算です。
- **シナリオの案**：
  - フラップ 20・150 kt・水平、A/P と A/T を切って 1 発 60 → 200 kN に上げ、5 秒のピッチと保つのに要る昇降舵を `aero_tm_off` 0／1 で比べる。
  - 腕を替えたら `aero_takeoff_trim_*`・s341・s263 を回し直す。
- **直す案**：腕を p.613 の値にし、`STAB_FLAP` を合わせ直す（見込み：10 は約 4.0、20 は約 5.0、30 は約 5.6）。notes §3.25 が検討していない acf の重心の高さ `_cgY`（−6.0 ft）を上げる案も、試して理由を残してください。

#### FCTL-3　フラップ 20 の補正は最大離陸推力の上昇だけで合わせてあり、水平飛行では -100 より約 2 units 機首上げ側（型 F）

- **場所**：`B747.45.aero_corr_model.lua:309`（`STAB_FLAP` の 10：5.2、20：6.2）。
- **何が起きるか**：フラップ 20・166 kt・256 t・重心 20.4 % の水平で、トリムが 8.6 units になります。
  - -100 は同じ形で 5.1 units（重心 25 %）。-100 の重心の傾き 約 0.3 units/% で直すと約 6.5 units です。
  - 30 にして 150 kt に落とすと、X-Plane は 7.1 へ機首下げ側に動きます。-100 は 7.8 へ機首上げ側です。
  - notes とコードの「7.3（256 t・150 kt・21 %、p.342）」は p.338 の 4.0.16（550,000 lb）からの値です。p.342 の図（564,000 lb）は 150 kt で 15 %：9.5、25 %：6.6 で、21 % は約 7.8 と読めます。どちらも水平飛行の値で、s341 は 3° の降下です。
- **どう確かめたか**：`aero_pitch_f20` の記録を読みました（`run_pitch_osc.out` の末尾）。この測りは NASA_HQ の FC2 に合わせて作ってあります。
  - 11-20 18:17 の回：8.61 units、昇降舵 +0.82°、迎角 5.49°、1 発 63 kN。補正を切った 14:29 の回は 4.52 units。
  - この回が最終の値（20：6.2、DW_K 0.50）だったかは、時刻の並びからの見込みです。
  - p.342 の図は `nasa_sim_p0342_top.png`。
- **根拠**：NASA_HQ p.223（表 IX-2：SL・165 KTAS・迎角 5.7°・δs −2.1°・CL 1.11）、NASA_SIM p.338 (14.1-13) の 4.0.13（8.5 units、15 %・159 kt）、p.342 (14.1-17)、ATA22 p.132。-100 の値です。
- **重さ**：軽い〜乗員に見える（進入のトリムの読みと、着陸フラップでの向き）。**確かさ**：たぶん。
- **シナリオの案**：5,000 ft・249.5 t・重心 15 % の水平で、フラップ 10／167 kt、20／159 kt、25／155 kt、30・脚下げ／150 kt のトリム（昇降舵を 0 に直した値）を読み、p.338 の 7.8・8.5・8.6・9.2 と比べる。
- **直す案**：FCTL-2 の後で、`STAB_FLAP` を離陸と水平飛行の両方に当てる。両立しなければ、差を notes に残す。

#### FCTL-4　CDU の TRIM が推力の定格（TO 2）を見ない（型 F。担当 3 と重なる）

- **場所**：`plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua:533-557`（`calc_stab_trim`：重さと重心だけ）。定格は `B744.fms.pages.lua:2761-2763` の `toderate`。
- **何が起きるか**：FPPM には TO 1・TO 2 の表が別にあります。
  - TO 1（8 %）は TO と同じです。
  - TO 2（20 %）は TO より +0.5（280〜360 t）、+1.0（240 t）、+1.5〜2.0 units（200〜220 t の前方重心）機首上げ側です。
  - 軽いときによく使う TO 2 で、CDU の値は表より 0.8〜1.8 units 機首下げ側になります。利用者の「軽いと機首が上がりにくい」と同じ向きです。
- **どう確かめたか**：p.44・p.57・p.69 を絵で読み、74 ますを式と比べました（`cdu_trim_vs_fppm_derate.lua` → `.out`、表の絵は `fppm_p0057_stab.png`・`fppm_p0069_stab.png`）。

  | 表 | 式 − 表の平均 | rms | 最大 |
  |---|---|---|---|
  | TO | −0.08 | 0.31 | +1.04（380 t・13 %） |
  | TO 2 | −0.68 | 0.83 | −1.78（200 t・13 %） |

- **根拠**：FPPM p.44 (1.2.20)、p.57 (1.3.11)、p.69 (1.3.23)。ATA27 p.514（MAWEA は CG・重さ・推力の定格で帯を選ぶ）。
- **重さ**：乗員に見える誤り。**確かさ**：確か。
- **シナリオの案**：220 t・重心 17 %・TO 2 で CDU の TRIM（今は 4.4、表は 6.0）を読み、浮揚の後の釣り合いも `takeoff_trim.lua` で見る。
- **直す案**：TRIM を定格ごとの FPPM の表に（GE・RR は推定と書く）。greenband の選びも同じ値から。

#### FCTL-5　空中でスピードブレーキを戻すと、X-Plane のスポイラーが 1 フレームで 2.5 倍に跳ねる（型 外）

- **場所**：`B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulics_override.lua:235-254`。
- **何が起きるか**：補正が、遅れて動く実際の角度から、レバーの位置の計画の角度の (1 − k) を引いています。
  - レバーを戻した瞬間、X-Plane のスポイラー 3 が 16.2° → 40.5° に跳ね、約 0.2 秒は定常より大きいままです。
  - 出すときは 9 フレームのあいだ 0° のままです。
  - 3D は正しく動きます。
- **どう確かめたか**：油圧のモジュールをモックで回しました（`sb_retract_spike.lua` → `.out`）。
- **根拠**：資料なし。補正の意図（空中は 0.36 倍：notes/AERO.md §3.15）と合いません。
- **重さ**：軽い（戻すたびに短い抗力と揚力の落ち込み）。**確かさ**：dataref の動きは確か。機体の揺れは未確認。
- **シナリオの案**：280 kt・FLIGHT DETENT から `speed_brakes_up_one`。毎フレームの記録で `sim/flightmodel/controls/wing3l_spo2def` が 16.2° を超えないことと、g の動きを見る。
- **直す案**：引く量を実際の角度から作る（例：実際の角度のうちスピードブレーキの分 × (1 − k)）。

#### FCTL-6　安定板の写しの 2 行目が、和を −10° で切る（型 G）

- **場所**：`B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulicsmodel.lua:445, 450`。
- **何が起きるか**：トリムの角度と補正の和が −10° で切られます。13 units から上では、負の補正が全部消えます。
  - 例：9 units と補正 −5° は −11° のはずが −10°。11.6 units と −5° は 3.6° 足りません。
  - 当たるのはフラップ UP・高い迎角・8 units 以上で、ふつうの飛行では当たりません。
- **どう確かめたか**：モックの `apply_control_objects` で回しました（`stab_rows.lua` → `.out`）。XTLua 本体のソースは手元に無いので、モックの規則が同じという前提です。
- **根拠**：ATA22 p.132（15 units ＝ −12°）。
- **重さ**：軽い。**確かさ**：たぶん。
- **直す案**：2 行目に `"min":-22,"max":13` を付ける。units と補正から安定板の角度までを見る試験も足す。

#### FCTL-7　試験のキットに 270 t で決めた離陸トリムが残る（型 F、試験）

- **場所**：`tests/flight/scenarios/s326_eo_takeoff_accel_heavy_hot.json:44`、`tests/flight/perf/auto_flight.ps1:875-876`、ほかの離陸のシナリオの「代替トリム 5.2 秒」。
- **何が起きるか**：どの重さでも約 4.9〜5.1 units です。s326（382 t）は FPPM の 5.5（25 %）〜7（21 %）より 0.5〜2 units 機首下げ側で飛んでいます。
- **どう確かめたか**：読んだだけ。
- **ほかの古い注記**：s217 の「0.26 + 308,800 ÷ IAS²」（式は 508d8f2b で替わった）。
- **重さ**：軽い。**確かさ**：確か。
- **直す案**：FPPM の表（`takeoff_trim.lua`）から秒数を出す。

### 段 1〜3 の直しを見た結果

| コミット | 結果 |
|---|---|
| dfbbf7d4 | 写し（−3〜12、scale −1）は ATA22 p.132 の表の全行（角度 ＝ 3 − units）と合う。units を読む所（SRM・greenband・離陸形態警報・3D の指針）に古い換算は無い。`STAB_FLAP` は指摘 3、和の切り方は指摘 6、キットは指摘 7 |
| c6f83604 | 吹き下ろしは指摘 1、推力は指摘 2。地面効果を外した判断は問題なし（改訂の図を使っている） |
| bdf580e1・508d8f2b | 問題なし。7 点を計算し直して最大 0.12 units（FL350・M.78）。`Qstatic` は notes の実測どおり Pa |
| a6aae1a5・1903e811 | `takeoff_trim.lua` の FPPM p.44 の写しは絵と全ます一致。p.44 の 380 t・13 % の 8 は、TO 1 の表では 9（誤植の見込み） |
| f882eaee の前提 | 巡航だけの確かめ。指摘 1 |

### 見て問題が無かった所

- エルロンのプログラマは ATA27 p.59 の図どおり。
- ラダーの 32°／5° は ATA27 p.634・p.658、ヨーダンパーの ±4° は p.656 と合う。
- FLIGHT DETENT で 5〜8 が中間、3・4・9・10 が全開は FCOM p.951 どおり。
- 抗力の補正が胴体の係数を 0 で止めるのは、M.87 以上・330 t 以上・340 kt 超だけ（失う CD は最大 0.00095：`fuse_cd_clamp.out`）。
- X-Plane のフラップ角を読む所は残っていない。
- 外装の安定板はトリムの比で動く。
- `tests/run.sh fltctrls` は 8 本・726 件合格。

### 範囲の外で気づいたこと

- CDU の TRIM は軽い・後方重心で FPPM の下限 2 を割る（200 t・33 % で 1.1。210 t 以下・32〜33 % で 1.35 未満：`cdu_trim_vs_fppm.out`）。
- NASA_SIM 19 章は、シェーカーの迎角（p.616）とスポイラーの計画（p.621–622）も改訂している。-100 の値を使う担当は確かめてください。
- notes/AERO.md §3.23 と `aero_corr_model.lua` の「p.342 の 7.3」は出典のページが違う（指摘 3）。

### 見られなかった所

- X-Plane での確かめ全部。
- XTLua 本体の controlObject のソース。
- 変異の試験。
- フラップの動く速さ（資料に値なし）。
- 横と方向の補正（`SB_XP` のロールへの効き）。
- フラップ 1・5・10 の水平飛行のトリム。
- `B747.20.xt.hydraulics.lua`。

# 第 2 波 担当 7：警報・地上と空中の判定・脚とブレーキ・GPWS（WARN-n）

## 担当 7（警報・地上と空中の判定・脚とブレーキ・スピードブレーキ・GPWS）報告

- 確かめ方は、模型とモックでの再現、資料のページの読み、過去の記録の再生です。X-Plane では何も動かしていません。
- 指摘は 7 件です。乗員に見えるものは WARN-1〜3、試験の穴が WARN-4、判断が要る軽いものが WARN-5〜7 です。
- スクリプトと出力は `D:\b747_review\stage4\a07_warn_gear\` にあります。リポジトリの直下で `luajit <スクリプト>` で回し直せます。

### 指摘

#### WARN-1　着陸・RTO の後、「1 段ずつ戻す」コマンドではスピードブレーキを下ろせない（型 J）

- **場所**：`plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.speedbrake_model.lua:94-96`（extend の間はレバーが UP より下なら毎回押し上げる）、`B747.45.xt.fltCtrls.lua:395-414`（`speed_brakes_up_one`）。
- **何が起きるか**：
  - 自動スピードブレーキが UP にした後（地上、推力レバー 1・3 がアイドル）、`sim/flight_controls/speed_brakes_up_one` はレバーを 0.53 に置くだけです。
  - レバーは 0.07 以上なので「武装」と読まれ、作動器が 0.5/s で UP へ押し戻します。次に押しても、0.53 より上にいるのでまた 0.53 です。何回押しても DN に届きません。
  - 3D のレバーをフライト・ディテントで離しても、UP に戻ります。
  - 下ろせるのは `speed_brakes_up_all`、トグル、推力レバー 1 か 3 を 14 %（7°）より前に出したときだけです。
  - この PC のキー設定（`Output/preferences/X-Plane Keys.prf`）は 3 が `speed_brakes_up_one`、4 が `speed_brakes_down_one` で、`up_all` の割り当てはありません。キーボードでは着陸後に下ろせません。
- **どう確かめたか**：`exp_speedbrake_stow.lua`（出力 `out_speedbrake_stow.txt`）。操縦系統のモジュールをモックで回しました。
  - 0.5 秒おきに 30 回押す：毎回「押した直後 0.530、0.5 秒後 0.780」、3 秒後 1.000。
  - 0.1 秒おきに 30 回押す：1.000。
  - 0.53 に置いて離す：3 秒後 1.000。
  - `speed_brakes_up_all`：0.000。推力レバー 1 を 0.2：4 秒後 0.000。
- **根拠**：
  - FCOM p.951 (9.20.11)：レバーは手で DN に戻せる。
  - FCOM p.149 (NP.21.55)：着陸の後、機長がレバーを DOWN にする。
  - ATA27 p.170 (27-60 p.34)：no-back brake は、作動器が前に入れた入力も今入れている入力も、手で完全に override できる。DN まで戻すと作動器が格納へ動く。
  - 伸びきった作動器が、手で動かしたレバーを押し戻すという記述は、どの資料にもありません。
- **重さ・確かさ**：乗員に見える誤り（キーで 1 段ずつ戻す人は、着陸のたび）。モックでは確か、X-Plane では未確認。
- **シナリオの案**：`s340` の格納の後に `speed_brakes_up_one` を 0.5 秒おきに 3 回（各 0.2 秒）、3 秒待つ。合格は `laminar/B747/flt_ctrls/speedbrake_lever` < 0.01 と `sim/cockpit2/controls/speedbrake_ratio` == 0。今は 1.0 に戻る見込みです。
- **直す案**：作動器が伸びきった後（`s.act >= 1`）は押し上げない。または、作動器が出ている地上では `up_one` を DN まで動かす。

#### WARN-2　RTO のオートブレーキ：AUTOBRAKES が出ず、一度働くと memo は RTO のまま二度と働かない（型 I・J）

- **場所**：`plugins/xtlua/scripts/B747.10.xt.gear/B747.10.autobrake_model.lua:132-153`（`rto_off`・`rto_latched`・`applying` はセレクターを RTO から外すまで戻らない）、`:166-167`（memo と AUTOBRAKES の条件）。
- **何が起きるか**：
  1. RTO が働いて止まった後、ペダル・推力レバー・スピードブレーキで外すと `rto_off` が立ちます。memo は AUTOBRAKES RTO のまま、AUTOBRAKES（advisory）は出ません。セレクターを触らずにもう一度 100 kt で中止すると、ブレーキは 0 のままです。
  2. 85 kt より上で、ペダルを踏んだまま推力レバーを閉じると、RTO は働かず、AUTOBRAKES も出ません。
- **どう確かめたか**：`exp_autobrake_rto.lua`（`out_autobrake_rto.txt`）。
  - (1) ペダルで外した後：memo 0（RTO）、AUTOBRAKES false、`rto_off` true。2 回目の中止：cmd 0.00。
  - (2) ペダル 0.8 でレバーを閉じる：cmd 0.00、AUTOBRAKES false。
  - 比べ：着陸のペダルでの disarm は、セレクター 2・AUTOBRAKES true。
- **根拠**：
  - FCOM p.1521 (14.30.1)：AUTOBRAKES は「RTO initiated above 85 knots and autobrake has not been applied」でも出る。
  - ATA29_32 p.530 (32-42 p.34)：「RTO initiated but manually overridden」「RTO initiated and autobrake system fault」。
  - ATA29_32 p.529 の図：disable は弁の電源だけを切り、セレクターは RTO のまま。
  - disable がいつ戻るかは資料なし。
- **既に書いてあること**：notes/ATA-32.md §12 の「作らなかったもの」に、理由「弁と圧のモデルが無い」で入っています。ただしモデルは必要な状態（`rto_off`、ペダルで適用されなかったこと）を既に持っています。2 回目に働かないことは、どこにも書いてありません。
- **重さ・確かさ**：乗員に見える誤り（RTO のときだけ）。模型で確か。
- **シナリオの案**：`s38_rto` の 1 回目の停止の後に `brakes_toggle_max` を押して離す。見るもの：`laminar/B747/CAS/advisory_status[17]`（資料どおりなら 1、今は 0）、`memo_status[7]`。セレクターはそのままで、もう一度 95 kt から中止し、`left_brake_ratio` を見る（今は 0）。
- **直す案**：`rto_off` の間と「ラッチ済み・アイドル・未適用」の間は AUTOBRAKES を出し、memo を消す。止まってレバーがアイドルに戻ったら disable を解く（推定と明記）。

#### WARN-3　推力レバーが原因の CONFIG GEAR：800 ft より上でも残る、しきい値、別のレバー（型 I・F、判断が要る）

- **場所**：`B747.45.xt.fltCtrls.lua:826-829`（閉 ＝ 0.05 未満）、`:915-919`（ラッチ）、`B747.87.alert_model.lua:388-393`（リセット）。
- **何が起きるか**：
  1. アイドルの降下で、脚上げのまま電波高度が一度 800 ft を切ると（尾根の上など）、メッセージが出ます。その後 3,000 ft に離れても、推力レバーを進めるまで残ります（master リセットしなければ siren も）。フラップが原因の方は、11-13 から ATA31 p.212 のとおり条件が去ると消えるので、片方だけの非対称です。
  2. しきい値は、資料では 55° TLRA です。ATA70_80 p.150 の換算（アイドル 34.88°〜最前方 85°）では、レバーの 40 % に当たります。コードは 5 % で、同じ換算を `speedbrake_model.lua` は既に使っています。notes/ATA-31-warning.md §4.6 は「換算は資料に無い」のままです。
  3. リセットの後に別のレバーを戻しても、新しい警報になりません（57cdcdc0 の直し残し）。
- **どう確かめたか**：`exp_config_gear.lua`（`out_config_gear.txt`）。
  - RA 700 ft を 2 秒 → CONFIG GEAR 1。RA 3,000 ft で 120 秒 → 1 のまま。レバー 0.3 → 0。
  - レバー 0.40・0.30・0.20・0.10・0.06 では出ず、0.04 で出る。
- **根拠**：
  - ATA31 p.214 (31-51 p.132)：止まる条件に「800 ft より上へ上がる」。全レバーが 55° より前で解除、別のレバーが 55° 以下で新しい警報。
  - ATA31 p.209、ATA27 p.735–736：55° TLRA（ATA27 の本文は 75°）。
  - FCOM p.1556・p.1558 は「idle／closed」「レバーを進めるか脚が下りるまで」で、今のコードは FCOM の文のとおりです。
- **重さ・確かさ**：軽い〜乗員に見える（山の上のアイドル降下で出たまま）。再現は確か。どちらの資料を採るかは利用者の判断です（フラップの側は 11-12 に ATA31 を採りました）。
- **シナリオの案**（N19-WARN-02 の X-Plane での確かめも兼ねる）：
  - 海の上 3,000 ft、脚上げ、フラップ 10、A/T なし。アイドルで RA 750 ft へ降りる。
  - `warning_status[3]`・`warning/warning_siren`・`flt_ctrls/config_gear_lever` が 1。
  - `button_switch/warn_caut_capt` を押すと siren 0、メッセージは 1。
  - フラップ 25 で siren 1。もう一度リセットしても 1。
  - V/S で RA 900 ft へ上げたときに消えるかを見る。
- **直す案**：レバーが原因の方も、RA が 800 ft を超えたら消す。しきい値と別のレバーは判断の後に。

#### WARN-4　段 1〜3 の直しの結線を見ている試験が無い、滑走の通しのシナリオの穴（試験の穴）

- **場所**：`B747.45.xt.fltCtrls.lua:845-868`、`B747.87.xt.alerts.lua:193`、`tests/fltctrls/`、`tests/warning/`、`tests/flight/scenarios/`。
- **どう確かめたか**：変異 33 個のうち 12 個が素通りしました（`mut_spec_stage123.lua`、`out_mut_stage123.txt`）。素通りした主なもの：
  - W3：`tw.lever[i] = 1`（N19-WARN-01 のレバーをつながない）。
  - W1・W2：逆推力の扉だけ、または prop mode だけを外す。
  - A2：`inp.config_gear_lever = false`（N19-WARN-02 を警報につながない）。
  - W4：離陸形態警報が空中でも地上扱い。W5：`lever_only` がフラップと重なっても 1。W7：140 秒の終わりなし。W9：ARM を「DN でない」に数えない。
  - G3・G4・G5：GPWS の minimums の +180 ft、リセットの 1,000 ft ちょうど、地上のコール。T9：レバーのしきい値。
- **X-Plane の側**：
  - `s341` は、レバーの条件か扉の条件のどちらか片方があれば通ります。2026-11-22 の記録では、格納の指令の時 N1 75.9、1.0 秒後 66.85、1.5 秒後 61.9 でした。
  - N19-WARN-02 を見るシナリオはありません。`s224` はフラップが原因の場合だけ、`s302` は復行だけです。
  - `s38_rto` は逆推力もスピードブレーキも使わず、警報も見ていません。`s340`・`s341` は、オートブレーキの適用と disarm、スピードブレーキの格納、停止を見ていません。
  - タッチ・アンド・ゴー、接地後の復行、バウンドのシナリオはありません。
- **重さ・確かさ**：試験の穴。確か。
- **シナリオの案**：
  - S-a（RTO の通し）：RJAA 34L、RTO を選び離陸推力。120 kt で caution を 1 つ立て（AC バスなど）、スロットルをアイドル、`thrust_reverse_hold` 10 秒。合格は次のとおり。
    - `speedbrake_lever` > 0.9（逆推力のレバー 2・4 で）。
    - `warning_status[2..7]` と `master_warning` が止まるまで 0。
    - `left_brake_ratio` > 0.98。
    - `master_caution` は 75 kt を切るまで 0 で、その後 1（FCOM p.1594）。
  - S-b（タッチ・アンド・ゴー）：接地後に A/P を外し、フラップ 20、スピードブレーキ DN、レバーを 0.5 に。フラップが動いている間に N1 が 66.5 を超えれば CONFIG FLAPS が出て（FCTM p.203 (5.57)）、20 に着くと消える。離陸の後 140 秒は CONFIG GEAR なし。
  - S-c（接地後の復行）：接地の 1 秒後にレバーを前へ。`speedbrake_lever` が 3 秒で 0、オートブレーキのセレクターが 2 で `advisory_status[17]` が 1（FCTM p.206）。
- **直す案**：`fltctrls_module_test` に、エンジン 2 の N1 80 で「レバー 0 → 出ない／0.3 → 出る／扉 0.5 → 出ない／prop mode 3 → 出ない」を足す。`alerts_module_test` に `config_gear_lever` の結線を足す。

#### WARN-5　離陸形態警報のメッセージと siren が V1 で消える（型 I、判断が要る）

- **場所**：`B747.45.tocw_model.lua:94-95`（`not can_arm` で消す）。試験 `tests/fltctrls/tocw_model_test.lua:73` の「at V1: gone」。読んだだけです。
- **何が起きるか**：V1 より前に出た CONFIG のメッセージ・siren・灯が、V1 に達した瞬間に消えます。
- **根拠**：資料が食い違っています。
  - FCOM p.1557 (15.20.11)：形態を直すか、「推力が離陸域の下、かつ V1 未満」になるまで残る。
  - FCOM p.1595 (15.20.49)：V1 の前に点いた灯と siren は、V1 を超えても続く。
  - ATA31 p.180 (31-51 p.98)：V1 で takeoff warning disarms。
  - ATA31 p.194 (p.112)：T/O WARN inhibit の開始で siren が止まる。
  - 今のコードは ATA31 の側です。乗員に見える挙動は FCOM を優先する決まりです。
- **重さ・確かさ**：軽い（警報が鳴ったまま V1 を超える場合だけ）。確かさは「たぶん」。
- **直す案**：利用者に聞く。FCOM を採るなら、V1 の後も、出ていたメッセージは形態を直すか離陸するまで残す。

#### WARN-6　30 分より短い飛行の後、STATUS cue の抑止がエンジン停止まで続く（型 J、軽い）

- **場所**：`B747.87.alert_model.lua:207-216`。`status_start` は空中でしか解かれず、`liftoff_at` は接地で消えます。
- **どう確かめたか**：`exp_alert_phases.lua`（`out_alert_phases.txt`）。20 分の飛行の後、離陸から 35 分・65 分たった地上走行でも inhibit true・cue false で、全 CUTOFF で cue が出ます。40 分の飛行では、30 分 10 秒で空中で解けます。
- **根拠**：FCOM p.1593 (15.20.47)：エンジン始動からリフトオフの 30 分後まで。
- **重さ・確かさ**：軽い。確か。
- **直す案**：離陸の時刻を接地で消さずに持ち、地上でも 30 分で解く。

#### WARN-7　小さい点（読んだだけ）

- **DOORS AUTO の memo の「離陸推力」**（`B747.85.xt.safety.lua:223, 236-239`）：X-Plane のスロットル（`throttle_ratio` ≥ 0.6）で見ています。A/T の離陸で X-Plane 側のスロットルが 0.6 未満のままだと、滑走中と離陸後 10 秒は memo が出たままの見込みです（未確認）。ATA38_51_52_56 p.304：離陸推力から着陸の 1 分後まで抑止。案：`laminar/B747/engine/throttle` で見る。
- **離陸形態警報の地上**（`B747.45.xt.fltCtrls.lua:845`）：primary だけを見ています。ATA27 p.730 は「primary か alternate のどちらかの ground mode」。空地の故障のときだけ違います。
- **CONFIG GEAR の離陸後の抑止が 2 か所で別の形**：
  - `alert_model.lua:186-187` は、機首のリフトオフから 140 秒の間、RA ≤ 800 ft なら隠し直します。`xt.fltCtrls.lua:905-913` は、PSEU の離地から数え、一度 800 ft を超えたら終わりです。
  - EIU が空中で起動し直すと、800 ft 未満で 140 秒隠れます（`exp_alert_phases.lua` の (3)）。
  - ATA27 p.736 では、抑止はレバーが原因の警報だけで、脚の down & locked が消えた時から始まり、3 本以上のレバーを戻すと効きません。
- **BODY GR STRG SYS のラッチ**（5012a8fb）：`steering_model.lua:110` の「指令あり」は系統 1 の圧も条件です。前輪を 20° より切ったまま系統 1 が落ちると、5 秒で >BODY GEAR STRG が出て、STATUS がラッチします（CMC の ERASE まで）。まれです。
- **GPWS mode 6**：ATA34_2 p.183 と p.185 の図では、脚レバーの位置が mode 6 の入力です。使い方は資料にありません。モデルは脚に関係なくコールします。

### 段 1〜3 の直しを見た結果

| コミット | 結果 |
|---|---|
| 4d92ef7a（離陸形態警報をエンジン 2・3 ごとに） | モデルは問題なし。AOM_JP p.10、ATA27 p.730、FCTM p.203（レバーが垂直の付近で鳴りうる）と合い、変異 T1〜T8・T10〜T13 は捕まる。結線は指摘 WARN-4。地上の判定は WARN-7。 |
| b2fd7116（10 秒を N1 が下がってから） | 問題なし。ATA27 p.730 を開いて確かめた。変異 T3・T5・T7・T8 が捕まる。 |
| 57cdcdc0（レバーが原因の CONFIG GEAR の siren） | 論理は FCOM p.1556 のとおり。結線の試験と X-Plane のシナリオが無い（WARN-4）。別のレバーの新しい警報が無い（WARN-3）。 |
| 5012a8fb（STATUS のラッチ） | 問題なし。モデルを読み、変異 N1〜N4 が捕まる。BODY GR STRG SYS の件は WARN-7。CMC のページは読んでいない。 |
| b90a9ba0（GPWS のコールの再武装） | 問題なし。ATA34_2 p.180・p.183 を開いて確かめた。推定の境（+180 ft、1,000 ft ちょうど）は試験が見ていない（WARN-4 の G3・G4）。 |
| c468736b（タイヤの摩擦 0.65） | 問題なし。比べたのは 1 点（245 t）だが、摩擦が重さによらなければ、重さによる伸びは VREF の 2 乗で決まる。手計算で 250 → 280 t は約 +115 m、FCOM PI.12 は +120 m。オートブレーキ 2 の実測は逆推力の前 5.5 ft/s²、格納の後 4.7 ft/s²（目標 5.0。`s341` の 11-22 の記録）。 |
| b134fbf1 の逆推力のレバーの側 | 警報と地上の論理から見て問題なし。逆推力の間は 747 のレバーが 0 に戻るので、オートブレーキの「前進」、スピードブレーキの格納、離陸形態警報のどれも働かない。 |

### 見て問題が無かった所

- **空地の判定**：
  - PSEU の式は ATA-32.md §4.1 のとおり。
  - 記録では、離陸の PSEU の air は脚の荷重が 0 になってから 0.77 秒後（`s109`）、接地は X-Plane の接地と同じ記録行（`s341`）。
  - 地上の機首下げは最大 −1.99°（手のブレーキいっぱい、245 t）で、傾きのしきい値 4° に余裕がある。
  - 生の電波高度は接地で 2.45 ft（補正は 3.3 ft）。
- **抑止**：離陸と着陸の抑止は、FCOM p.1593–1595・p.1600–1602 と 1 行ずつ合う。タッチ・アンド・ゴーで離陸の抑止が武装しないのは推定の作りで、資料なし。
- **オートブレーキの着陸**：ATA29_32 p.520・p.522、FCOM p.1515–1516 と合う。バウンド、接地後の復行、停止後の保持も資料どおり。
- **スピードブレーキ**：ATA27 p.172・p.176・p.182・p.184、FCOM p.951 と合う。SPEEDBRAKES EXT の 40° TLRA は ATA27 p.740。
- **離陸形態警報の場面**：RTO、タッチ・アンド・ゴー、接地後の復行、逆推力からの格納で、資料に無い武装はしない。
- **GPWS**：過去の記録を模型に流した（`gpws_replay.lua`、`out_gpws_replay.txt`）。
  - 離陸 4 本（`s141`・`s109`・`s326`・`s155`）と、脚下げの着陸 4 本（`s114`・`s341`・`s332`・`s116`）。
  - 声は、`s332` の空中開始の直後の SINK RATE だけ。
- **失速警報**：`s109` の離陸を最小速度のモデルに流し、シェーカーなし。空中でのシェーカーまでの荷重倍数の余裕は最小 1.45（`shaker_replay.lua`）。
- **BTMS**：FCOM PI.12.8 の 4 点（16・22・31・45 百万 ft-lb → 2・3・4・6）は手計算で合う。34 は 10 分で 5、15 分で 4。

### 範囲の外で気づいたこと

- `s109`（11-22）：脚の荷重が 0 になるのがピッチ 2.8°・163 kt。離地の姿勢が低い（担当 6）。
- A/T のサーボの間、ハードのスロットルが 0.01 以上動くと、747 のレバーが 1 秒間そちらへ動く（`B747.42.xt.EEC.lua:1102-1117`）。A/T 着陸でハードのレバーを前に残した人は、滑走中に推力が出うる（担当 5・8）。
- エンジンごとの逆推力の hold（`thrust_reverse_hold_1`〜`4`）を空中で押すと、そのエンジンの X-Plane のスロットルを 0 へ動かす（`B747.40.xt.engines.lua:362-364` ほか）。
- TO/GA のコマンドは、どの場面でも prop mode を 1 にする（逆推力の途中でも格納。`B747.40.xt.engines.lua:570-573`）。

### 見られなかった所

- X-Plane での確かめ全部（上の案のとおり）。
- `B747.10.xt.gear.lua`・`xt.gear_act.lua`（脚の作動、レバーのロック）、TPIS、ステアリングのグルーは流し読みだけ。
- 警報のモデルの並びと CANC・RCL、CMC の ERASE のページ、`B747.87.xt.warning.lua` のメッセージの表、init スクリプト。
- GPWS の mode 2・5 の数値と、G/S を使う場面（記録に G/S の列が無い）。
- AOM_JP・EICAS_WS・MMEL は、AOM_JP p.10 の文字層を読んだだけ。

### ファイル（`D:\b747_review\stage4\a07_warn_gear\`）

- 実験：`exp_speedbrake_stow.lua`、`exp_autobrake_rto.lua`、`exp_config_gear.lua`、`exp_alert_phases.lua`
- 出力：`out_speedbrake_stow.txt`、`out_autobrake_rto.txt`、`out_config_gear.txt`、`out_alert_phases.txt`
- 変異：`mut_spec_stage123.lua`、`out_mut_stage123.txt`（写しは `mut\`）
- 記録の再生：`gpws_replay.lua`、`shaker_replay.lua`、`csvcols.lua`、`out_gpws_replay.txt`

# 第 2 波 担当 8：AFDS・A/T・LNAV の操舵・ヨーダンパー（AFDS-n）

## 担当 8 報告：AFDS・A/T・LNAV の操舵・ヨーダンパー（HEAD 807956a2）

指摘は 7 件です。重いのは AFDS-1（着陸復行の水平飛行で速度の保護が無い）と AFDS-2（接地後の着陸復行で A/T が 400 ft まで入らない）の 2 件で、残りは軽いものと試験の穴です。段 1〜3 の直し 5 件に、直しそのものの誤りは見つかりませんでした。

リポジトリは変えていません。X-Plane にも触れていません。スクリプトと出力は `D:\b747_review\stage4\a08_afds_at\` にあります（どれもリポジトリ直下を作業ディレクトリにして `luajit <スクリプト>` で回せます）。

---

### 指摘

#### AFDS-1　G/A の後の水平飛行（ALT）で、A/T の THR に速度の保護が無く、フラップの placard を越える（型 J・I）

- **場所**：`plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua:658-697`（THR の枝。`vmax` は 628 行で作るが、使うのは THR REF の 634 行と SPD だけ）。
- **何が起きるか**：
  - TO/GA を 1 回押した G/A（A/T は THR、2,000 fpm）で MCP 高度を捕捉すると、ピッチは ALT、A/T は THR のまま残る。ここまでは FCOM どおり。
  - THR の則は「エネルギーの率 2,000 fpm」を保ち続けるので、水平飛行では約 1.5〜2 kt/s で加速し続ける。上限は推力制限だけ。
  - 乗員には、SPD を押すまで速度がフラップ 20 の 230 kt を越えて増え続けるのが見える。
  - 2 回目の押し（THR REF）には限界速度の則があり、placard − 5 で止まる。片方だけ作った非対称。
- **どう確かめたか**：`ga_leveloff.lua`（`tests/lib/energy_sim.lua` に本番の A/T とピッチの則。160 kt・フラップ 20・placard 230、1,000 ft から G/A、3,000 ft で捕捉）。
  - 1 回押し（THR）：捕捉の 60 秒後に 230 kt を越え、レバー 0.58 のまま加速が続く（余剰推力を 2,600 fpm にしても 61 秒後）。
  - 2 回押し（THR REF）：最大 232.4 kt、その後 225.0 kt で保持。
  - 模型の推力の余りは速度で変わらない。なので「越える」ことは示せるが、最終の速度は当てにならない。
  - X-Plane の記録 `tests/flight/runs/20261120_215919_s104_afds_ga`（`ga_record.lua`）：t 164.8 で ALT・A/T は THR、4 秒でレバー 0.728 → 0.779。シナリオはここで A/P を切るので、加速そのものは写っていない。
- **根拠**：
  - FCOM p.673 (4.20.15)「TO/GA level-off：A/T は SPD を選ぶまで THR か THR REF のまま。速度の保護が、最大運用・脚下げ・フラップ placard の速度を越えさせない」。
  - FCOM p.675 (4.20.17)「A/T と AFDS は、V/S と最大 E/O 高度より上のエンジン故障を除く全運用で、それぞれ速度の保護をする」。
  - ATA34_2 p.648 (34-61 p.222) は「GA では full GA thrust が指令されたときに保護」と書く。FCOM を優先。
- **重さ**：乗員に見える誤り（フラップの過速）。**確かさ**：確か（コードと模型）。X-Plane での加速の大きさは未確認。
- **シナリオの案**：s104 と同じ初期化（フラップ 20・160 kt・A/T SPD・CMD L）で、MCP 高度を RA 1,500 ft 相当にして TO/GA を 1 回。`FMA/active_pitch_mode` が 9 になってから 120 秒、A/P を切らずに記録する。
  - 合格：`laminar/B747/gauges/indicators/airspeed_kts_pilot` の最大が `laminar/B747/airspeed/Vmax` − 5 + 3 以下、`FMA/autothrottle_mode` は 4 のまま。
  - 今は約 1 分で 230 kt を越える見込み。
- **直す案**：G/A の THR（`s.ga`）のレバーの率を、THR REF と同じ `speed_rate(inp.ias, inp.accel, vmax, …)` との小さい方にする。FLCH・VNAV の THR はピッチが速度を持つので変えない。

#### AFDS-2　接地した後の着陸復行・タッチアンドゴーで、TO/GA を押しても A/T が RA 400 ft まで入らない（型 J）

- **場所**：`B747.70.at_model.lua:303-309`（`no_to`）、`:324-344`（TO/GA）。
- **何が起きるか**：
  - `no_to` は離陸の規則（50 kt までに TO/GA を押さなければ 400 ft まで A/T は入らない）のための印。
  - これが「地上・50 kt 以上・A/T が外れている」だけで立つので、手動着陸（A/T を外して接地）の接地の 1 フレームでも立つ。
  - その後に浮いて TO/GA を押すと、AFDS は G/A（ピッチ・ロール）に入るが、A/T は RA 400 ft を越えるまで入らず、FMA の A/T は空白のまま。推力は手で出すことになる。
  - 推力制限も、接地の瞬間に TO へ戻る（`B747.68.thrlim_model.lua:147-155`、担当 2 の範囲）。400 ft の上の TO/GA は THR ではなく「離陸の THR REF」になる。
- **どう確かめたか**：`touch_and_go.lua`（本番の `at_model`）。
  - A/T を外して接地（140 kt）→ 滑走路上 120 kt の TO/GA：off。
  - 浮いて 60 ft の TO/GA：**off**。450 ft の TO/GA：THR（制限 GA のとき）か THR REF（制限 TO のとき）。
  - A/T を SPD のまま接地した場合は、60 ft の TO/GA で THR に入る。
- **根拠**：
  - FCOM p.673 (4.20.15)「TO/GA は、rejected landing と touch and go のため、RA が 5 ft を上へ通過した 3 秒後に再び有効」「1 回目の押しで A/T は THR」。
  - FCOM p.657 (4.10.19)：フラップが出ていれば TO/GA で A/T は THR。
  - ATA34_2 p.674 (34-61 p.248)：G/A の条件は「A/T armed・空中・G/S かフラップ・制限が TO でない」で、400 ft の条件は無い。
  - 400 ft の規則は FCOM p.656 (4.10.18)・p.667 (4.20.9) の離陸の項にある。着陸の滑走に当てはめる記述は無い。
  - FCOM p.671 (4.20.13) の注（逆推力レバーを下げて 10 秒後からフラップ UP まで A/T は armed、TO/GA で THR REF）も作られていない。
- **重さ**：乗員に見える誤り（接地後の復行・バウンド・タッチアンドゴーのときだけ）。**確かさ**：たぶん。モデルの動きは確か。実機の動きは資料の読み合わせで、接地後の 400 ft を直接書いた文は無い。
- **シナリオの案**：
  - 回帰試験（`at_model_test`）：`ground=true, cas=140`（A/T off）の後、`ground=false, ra=60`・フラップ出・制限 GA・`toga` で THR を期待。HEAD は off。
  - X-Plane：A/T を外した進入で接地させ、逆推力なしでレバーを前へ、VREF で引き起こし、RA 5 ft 通過の 4 秒後に `sim/engines/TOGA_power`。RA 400 ft 未満で `FMA/autothrottle_mode` = 4（今は 0）。
- **直す案**：`no_to` を「離陸の滑走（制限 TO で TO/GA 待ち）」だけに立てる。または G/A の枝（制限が TO でない・空中）には `no_to` を掛けない。接地で制限が TO に戻る件は担当 2 と合わせる。

#### AFDS-3　A/P を入れたままの G/A が RA 1,500 ft 以下で水平になると、次の進入の LAND 3 で SRM の autoland が立たない（型 J、軽い）

- **場所**：`B747.70.xt.autopilot.lua:1664-1667`（G/A で `autoland = -2`）、`:1381-1384`（−2 の間は LAND 3/2 でも 1 を書かない）、`:2686-2689`（戻すのは RA が 1,500 ft を越えたとき）、`:3367-3369`（または A/P が全部外れたとき）。
- **何が起きるか**：−2 は前の作りの G/A の印で、今は誰も読まない。復行高度が低い（1,500 ft のパターンなど）と −2 のまま残り、次の進入で LAND 3 が出ても `laminar/B747/autopilot/autoland` は −2。SRM（`B747.45.srm_model.lua:314`・`:513`）は autoland として扱わず、オートトリムの 3.5 秒の遅れが残り、方向舵の ratio changer を全権限にしない（効くのは約 155 kt より上の進入だけ）。FMA には出ない。
- **どう確かめたか**：`autoland_after_ga.lua`（モックの上でグルーを通して）。
  - 1 回目の進入：LAND 3、印 1。TO/GA で −2。
  - RA 1,490 ft で ALT・HDG SEL にして再進入：LAND 3（3 チャンネル）で印 **−2**。
  - RA 2,000 ft まで上げた場合：印 1。
- **根拠**：コードの注（ATA27 p.636：autoland では RRC 全権限・オートトリムの遅れなし）。このページは自分では開いていない。
- **重さ**：軽い。**確かさ**：確か（グルーの挙動）。X-Plane は未確認。
- **シナリオの案**：s114 の進入で RA 200 ft の TO/GA、MCP 高度を標高 + 1,400 ft にして ALT の後、60 秒間 `laminar/B747/autopilot/autoland` が 0 に戻ること（今は −2 のまま）。
- **直す案**：−2 をやめる（読む所が無い）。または G/A のピッチが終わったら 0 に戻す。`afds_glue_test.lua:1065` は −2 を期待しているので、併せて直す。

#### AFDS-4　T/O の速度の記憶が、T/O を「全部切」で終えると次の離陸に残る（型 J、軽い）

- **場所**：`B747.70.afds_pitch_model.lua:513-516`（消すのは T/O 以外のモードへ移るときだけ）、`:598-603`（則なしの枝は `s.mode` を nil にするだけ）。
- **何が起きるか**：T/O のまま A/P なし・両 F/D OFF にすると（場周を手で飛ぶ訓練など）、`vrot`・`v2`・`to_target`・`to_eo` が残る。着陸の後に F/D ON で T/O に入ると「nil → TO」で消されず、前の離陸の目標速度と片発の扱いで F/D が出る。
- **どう確かめたか**：`to_stale.lua`。
  - 離陸 1（V2 181、空中で片発）→ 全部切 → 離陸 2（V2 140、全発）。
  - 空中の目標 **188.0 kt**（正しくは 150、上限 165）、`vrot` 170（正しくは 132）、`to_eo` 188（正しくは nil）。
  - 160 kt で 8 秒飛んでも 188 のまま。空中で V/S に移って終えた場合は消える。
- **根拠**：FCOM p.664 (4.20.6)・p.667 (4.20.9)（V2 + 10、引き起こしの速度 + 10、5 秒超過で現速度）。
- **重さ**：軽い（T/O のまま F/D を切った後の次の離陸だけ。ふつうの VNAV 400 ft では消える）。**確かさ**：確か。
- **シナリオの案**：回帰試験で足りる（`afds_pitch_model_test` に上の並び）。
- **直す案**：T/O に入るとき（`mode ~= s.mode` で `mode == "TO"`）と、則なしの枝でも、この 4 つを消す。

#### AFDS-5　F/D だけの間に巻き上がったロールの指令が、A/P を入れた瞬間に残る（型の外。2026-11-12 の AFDS-5 のロール側）

- **場所**：`B747.70.afds_roll_model.lua:358`（指令を今のバンクに置くのは則の始まりだけ）、`B747.70.xt.autopilot.lua:1501-1534`（`afds_roll_law` に同期が無い。ピッチは `:1545-1550` で `sync`）。
- **何が起きるか**：F/D だけで HDG SEL の方位を大きく回して、バーを追わずにいると、ロールの指令は限界（25°）まで行く。そこで CMD を押すと指令は 25° のまま始まり、A/P は 3°/s ではなくサーボいっぱいで回り込む。単一チャンネルなので操縦輪 25°（`AP_ROLL_SINGLE`）が上限。
- **どう確かめたか**：`roll_windup.lua`。F/D のみ・HDG SEL 60° ずれ・バンク 0 で 20 秒 → 指令 25.0°。engage の次のフレームも 25.0°（同期すれば 0.3° から）。ロールの則に `sync` は無い。X-Plane でのロールの速さは未確認。
- **根拠**：ATA22 p.348 (22-12 p.22)「ROLL ATT INTEG は、A/P が engage していない間、ロール姿勢に同期する」（ピッチは p.332 で同じ文。11-12 の案 3 でピッチだけ直した）。
- **重さ**：軽い〜乗員に見える。**確かさ**：確か（指令）、未確認（機体の動き）。
- **シナリオの案**：A/P なし・F/D ON、HDG SEL で方位を +60°、15 秒待って CMD L。その後 10 秒の `sim/flightmodel/position/P` の最大が 3.5°/s 以下（同期していれば 3°/s の傾き）。
- **直す案**：グルーで、A/P が 0 → 1 チャンネルになったフレームに、ロールの則の `s.cmd` を今のバンクに置く。

#### AFDS-6　LNAV の fly-by：低速（TAS 170 kt 以下）と小さい旋回で、目安（0.02 NM・1°・戻し 2°）を少し越える（型 F、軽い）

- **場所**：`plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua:563-617`（入りの先読みと戻し。`ROLL_LAG` 0.9 は FL370 の 1 点）。
- **何が起きるか**：TAS が低いと 23° の弧の半径が小さく、ロールの入りと戻し（各 約 8 秒）が旋回の大半を占める。旋回の後、脚の外側に 0.03〜0.08 NM、コースを 1.5〜3° 行き過ぎ、30〜40 秒で戻る。5〜15° の小さい旋回では、戻しで反対に 2〜6° 傾く。
- **どう確かめたか**：
  - `lnav_low.lua`（本番の LNAV と `tests/lib/lnav_sim.lua`）：
    - TAS 150 kt・遅れ 0.3 s：外 0.03〜0.05 NM、行き過ぎ 1.6〜2.2°。遅れ 0.9 s：0.05〜0.08 NM、2.0〜3.0°。
    - 170 kt・遅れ 0.3 s：0.02〜0.03 NM、0.5〜1.1°。190 kt 以上は目安の内。
    - 15° の旋回・190〜250 kt・遅れ 1.2 s：戻しのバンク 2.4〜6.0°。
  - `lnav_sweep.lua`：250〜497 kt の静穏は外 0.011〜0.021 NM。風 120 kt で 0.03〜0.06 NM。
  - 記録の遅れ（`roll_lag.lua`、11-21 の s271 と 11-22 の s206）：クリーン 0.80〜1.20 s（FL370 で 0.80〜1.05、5,000〜17,000 ft で 0.89〜1.20）、フラップが出ると 0.0〜0.5 s。
  - X-Plane の記録（`turns_in_record.lua`、直しの後の 11-21 の s271）：6° の旋回（FL370）で外 0.030 NM・戻し 2.1°、5° の旋回（13,000 ft・244 kt）で戻し 3.1°、40° の旋回（10,300 ft）で外 0.025 NM。
- **根拠**：資料なし（目安は利用者の 2026-11-20 の値。旋回の形は ATA34_2 p.615・p.626：ノートから）。
- **重さ**：軽い（ND では 0.0〜0.1 NM）。**確かさ**：模型は確か。150〜170 kt の X-Plane の記録は無い。
- **シナリオの案**：5,000 ft・フラップ 10・170 kt（TAS 約 185 kt）で 45° と 90° の fly-by。旋回の後 60 秒の `laminar/B747/fms/lnav/xtk` の外側の最大と、航跡の行き過ぎを記録する。
- **直す案**：入りの先読みと戻しを、旋回の角度が小さいとき・弧の旋回率が高いときに合わせ直す。急がない。

#### AFDS-7　試験の穴（変異で落ちない所と、飛ばしていない場面）

- **変異**（`mut_*.lua`・`mut_*.out`。`-m` を付けて回し、写しは消した）：

  | 対象 | 捕まった数 | 落ちなかった変異 |
  |---|---|---|
  | A/P の内側のループ（f882eaee） | 8/8 | なし |
  | ヨーダンパー（e61b9e51） | 9/10 | ADC なしのときの旋回協調の利得 |
  | A/T（cd1763c9 ほか） | 12/14 | グルーの `i.engine = B747DR_ap_engine_type` を 0 にしても落ちない（GE の直しが servo に届いているかをどの試験も見ていない）。地上 30 kt での `no_to` の解除 |
  | LNAV（989e7acb） | 10/15 | `ROLLOUT_END` 10、旋回の終わりを戻しの始まりにする、2 NM で旋回をやめる条件、engage していないときの戻し、戻しのバンクの向きの条件 |

- **飛ばしていない場面**：
  - GE のフラップ下げの A/T SPD（進入）。フラップ下げは利得の倍率が 1 で、P&W の 270 t で合わせた値のまま。GE の G は 10,000 ft で P&W の推定の 1.15 倍（`lever_gain_rerun.out`）。`tests/flight/measure/at_hold_f20.json` を GE のリバリーで 1 回流し、40 秒後のレバーの振れが 0.05 以下かを見る案。
  - G/A の後の水平飛行の速度（AFDS-1）。
  - 接地後の着陸復行（AFDS-2）。
  - 低高度の G/A の後の再進入（AFDS-3）。

---

### 段 1〜3 の直しを見た結果

- **989e7acb（LNAV の fly-by）**：直しそのものは問題なし。静穏・250〜497 kt・5〜130° で外 0.011〜0.021 NM、行き過ぎ 0.7° 以下。直しの後の X-Plane の記録でも 0.011〜0.030 NM。低速と小さい旋回は AFDS-6、試験の穴は AFDS-7。
- **e61b9e51（ヨーダンパーの旋回協調、マージ 7552f682）と測り fe54e26a**：問題なし。式・符号・権限の順（ATA22 p.86–87：ノートから）と、グルーの Q の読みを確かめた。変異 9/10。定常の旋回で 0、地上は指令なし、ピッチ 79° で頭打ち。
- **f882eaee（変化率の利得の下限 0.06、`AP_STAB_PER_ELEV` 0.95）**：問題なし。安定板の写し（`B747.19.xt.hydraulicsmodel.lua:445`：トリムの比 2 に対し 15°）と 1.9 → 0.95 が合う。変異 8/8。高い動圧（s139 の 346 kt）と進入（s114）は 11-22 の回し直しに入っている。FL410 より上・200〜250 kt のクリーンは飛ばしていない（下の「見られなかった所」）。
- **cd1763c9（GE の G）**：問題なし。記録を `lever_gain.lua` で回し直して同じ値（GE 3.47・5.29・7.50 kt/s、推定の 3.82・2.31・1.15 倍。P&W 1.21、1.38 倍）。GE の推力はレバーに対して下に凸（FL370 でレバー 0.55 → 0.63 の傾きが 157 → 182 kN/単位）だが、350 t・FL330 を手で見積もっても推定との差は約 1 割。試験の穴は AFDS-7。
- **f5bcbf0a（s109）と 84e7e0e4（決定）**：問題なし。FCOM p.641–642・p.667、ATA34_2 p.660・p.668 を開いて、A/T のモデルの SPD と THR の条件と合うことを確かめた。T/O からの捕捉で HOLD のまま、という動きは決定どおり。
- **s313（1016b430）**：新しい証拠なし。

### 見て問題が無かった所

- A/T の G/A の THR の利得（`K_VS_GA`）：余剰推力 2,200〜6,500 fpm × エンジンの遅れ 3・6 秒で、V/S の最大 2,036〜2,556、その後の最小 1,558〜1,951、2,000 に収まる（`ga_gain_sweep.out`）。
- 旋回の高度（versine は作っていない：ATA22 p.332）：s329・s215・s271 の記録で ±12 ft（`turn_alt.out`）。
- 最小機動速度の印（`pfd/show_mins`）は地上 100 kt 未満 5 秒で戻る。V2 は RA 1,000 ft の上で 999 になる。離陸の値が進入のバンク限界や T/O の保護に残らない。
- モードごとの状態（ロールの則、G/S・FLARE、ALT の捕捉、VNAV のレベル、A/T の HOLD と retard、AFDS の TO/GA の抑止、LAND の状態）は、AFDS-3・4 のほかは、モードの終わりで消える。
- 単位と換算（エネルギーの率、慣性の加速、V/S、レバー 50°、G/S・LOC の距離、TAS）。A/P の姿勢の P の利得は PL = PH = 0.1 で、MCP 高度による差は無い。
- 回帰試験：`bash tests/run.sh autopilot` 29 本・1,741 件、`lnav` 5 本とも合格。

### 範囲の外で気づいたこと

- 推力制限が接地の瞬間に TO へ戻る（`B747.68.thrlim_model.lua:147-155`）。FCOM p.672 (4.20.14) は「着陸フラップか G/S 捕捉で GA に固定」。AFDS-2 と組になる（担当 2）。
- T/O の地上のエンジン故障の目標：FCOM p.667 (4.20.9) は「V2 か離昇時の速度の大きい方」で上限が無い。コード（`afds_pitch_model.lua:552`、注は ATA22 p.264）は V2 + 10 で頭打ち。実害はほぼ無い。
- ATA34_2 p.658 は「A/P・F/D が無い G/A は THR REF」、FCOM p.657 の注は THR。コードは FCOM どおり。
- `afds_glue_test.lua:1065` は G/A で `autoland == -2` を期待している（AFDS-3 を直すと落ちる）。
- 短い脚（3〜6 NM）で大きい旋回をすると、弧の半径を脚の半分に切るので必要なバンクが 25° を越え、0.1〜0.6 NM 外へ出る（`path_model` の扱い。`lnav_sweep.out` の「short legs」）。

### 見られなかった所

- X-Plane での確かめ全部（シナリオの案として上に書いた）。
- A/P の内側のループの、FL410 より上と 200〜250 kt のクリーン（f882eaee の後に飛ばした記録が無い）。
- ROLLOUT・runway align・FLARE の則の、重さと速さの端（既存の模型の試験を読んだだけ）。
- 待機の入り・procedure turn・オフセットの LNAV（旋回の形だけを振った）。
- VNAV のモード（`vnav_mode_model`）の細かい組み合わせ（読んだだけ）。
- ロールの AUTO のバンク限界の TAS の表（`afds_roll_model.lua:91-95`、推定）：一次資料に値が無い。PMDG の資料に値があったと記憶するが、確かめていない。

# 第 2 波 担当 9：表示の論理（DSP-n）

## 担当 9：表示の論理（PFD・ND・EICAS）の報告

HEAD `807956a2` を読むだけで調べた。リポジトリも X-Plane も触っていない。スクリプトと出力は `D:\b747_review\stage4\a09_displays\` にある。過去の写真は 2026-11-20〜22 の全シナリオの回のもので、段 1〜3 の直しの後。

指摘は 5 件（DSP-1〜5）と、軽いものをまとめた DSP-6。

---

### DSP-1　P&W の EPR の指令の印が逆推力の間は消える（型 I・J）

- **場所**：
  - `747-400_custom.acf:144537-144540`（P&W の `GROUP Thrust Command EPR and 1`、`SHOW_LESS 0.9 sim/cockpit2/annunciators/reverser_deployed`）。RR は `:144471`。
  - REF の印は `:143912` ほか。この dataref を使う SHOW は 27 か所。
  - 値は `B747.42.xt.EEC.PW.lua:22-24`（`TRA` = `B747_eec_command`）と `B747.42.eec_model.lua:1206-1219`。
- **何が起きるか**：
  - P&W で逆推力を出すと、白い指令の印が 4 発とも消える。
  - この dataref は全エンジン共通（X-Plane の `DataRefs.txt:3936` では bitfield）。1 発だけ展開しても、4 発とも基準の印と指令の印が消える。基準の数字は発ごと（`thrust_reverser_deploy_ratio[n]`）なので、印と数字で食い違う。
  - 印を出しても、今の `TRA` は逆推力の間も前進レバーのアイドルの指令のまま。EPR 1.28 のバーの端には来ない。
- **どう確かめたか**：
  - パネルを読んだ。
  - 写真 `tests/flight/runs/20261122_090845_s340_rollout_reverse_747-400_custom/shot_51_eicas_reverse_full_close.png`：REV 緑、EPR 1.17。バーにあるのは琥珀の max の線だけで、白い印は無い。
- **根拠**：
  - FCOM p.832 (7.10.4)：109・405 は「reverse thrust activated のとき reference EPR は出ない」だけ。指令も消えるのは 570 の N1。
  - FCOM p.833 (7.10.5) の図：逆推力のエンジン 1（REV、1.01）のバーの端に指令の印がある。エンジン 2〜4 は基準の数字と印が残る。絵で確かめた。
- **重さ**：乗員に見える誤り（P&W の逆推力のたび。軽め）。**確かさ**：確か。逆推力の間に指令の印が指す値は資料なし。
- **シナリオの案**：`s340_rollout_reverse` の流れで、扉の比が 0.98 を超えて N1 が落ち着いた所。
  - `sim/cockpit2/annunciators/reverser_deployed` を読む（15 の見込み。transit の間の値も）。
  - `laminar/B747/engines/TRA[0..3]` と `display_EPR[0..3]` を読む（今は TRA がアイドルの値、EPR は約 1.28 の見込み）。
  - 直した後の合否：EICAS の寄せた写真で白い印がバーの端。`|TRA − display_EPR| ≤ 0.05`。
- **直す案**：
  - P&W・RR の指令の印から逆推力の条件を外す。
  - 基準の印は発ごとの `thrust_reverser_deploy_ratio[n]` で消す。
  - 逆推力の間の `TRA` は、逆推力の N1 の指令（`pw_reverse_n1`）を `epr_of_n1` で EPR にする（推定と明記）。

### DSP-2　ND の右上の現用点・距離・ETA が FMC の予測を使わず、地上では伏せ字（型 F・H・I）

- **場所**：`B747.68.xt.fms.lua`
  - `:5947-5981`（`get_ETA_for_Distance`：`:5953` の `default_speed = 275`、`:5955` の `distance / max(275, GS)`）
  - `:6025-6048`（`B747_route_eta`：DATA の ETA）
  - `:6050-6114`（`waypoint_eta_display`：`:6074` の `if simDR_onGround ~= 1`、`:6096-6099` の伏せ字）
- **何が起きるか**：
  1. ND の右上の ETA と DATA の各点の ETA は「直線距離 ÷ max(275 kt, 対地速度)」のまま。CDU の PROGRESS・LEGS・RTE DATA は段 8d から FMC の予測（`B744.fms.pages.progress.lua:257-367`）。対地速度が 275 kt 未満だと ND が早すぎ、同じ点で CDU と食い違う。
  2. 地上では、経路が有効でも ND は「----- / ------Z / ------NM」。DATA の ETA も出ない。CDU の PROGRESS は地上でも出す。
- **どう確かめたか**：
  - `dsp2_nd_eta.lua`（本番の式が HEAD に残っていることを assert してから計算）。出力 `dsp2_nd_eta.txt`：

    | 場面 | ND | 実際 | ND が早い分 |
    |---|---|---|---|
    | 最終進入 GS 150 kt・8 NM | 1.7 分 | 3.2 分 | 1.5 分 |
    | 向かい風で GS 120 kt・8 NM | 1.7 分 | 4.0 分 | 2.3 分 |
    | 離陸直後 GS 170 kt・20 NM | 4.4 分 | 7.1 分 | 2.7 分 |
    | 巡航 GS 480 kt | — | — | 差なし |

  - 写真：
    - `20261121_122048_s254_nd_plan_circles_747-400_custom/shot_61_capt_nd_map_after.png`（切り出し `crop_s254_nd_ground.png`）：RJAA の地上、ACT RTE 1 で ND は伏せ字。
    - `20261121_061714_s198_line_flight_rjaa_rjbb_747-400_custom/shot_49_cdu_progress_preflight.png`：地上の PROGRESS は「TO XAC 78 0112z」。
- **根拠**：FCOM p.1147 (10.40.39)：現用点、その距離、「FMS-calculated ETA」。MAP・MAP CTR・PLAN で、地上を除く条件は無い。p.1148 (10.40.40) の route data の ETA も同じ。実機が地上で出すかを直接書いた資料は見つけていない。
- **重さ**：乗員に見える誤り。**確かさ**：式と伏せ字は確か。「実機は地上でも出す」はたぶん。
- **既知との関係**：「ND の DATA の ETA は簡単な式のまま」は PROGRESS.md の推定の一覧にある。新しいのは、段 8d の後に同じ点の ETA が CDU と ND で食い違うようになったことと、地上の伏せ字。
- **シナリオの案**：
  - (a) `s254` の準備（RJAA 34L、ACT RTE）の後、`laminar/B747/nd/current_waypoint`・`waypoint_distance`・`waypoint_eta` を読む。直した後は XAC・約 78 NM・PROGRESS の TO の行と同じ ETA。
  - (b) 進入（`s272_nd_klax_final` など、GS 200 kt 未満）で、ND の ETA と PROGRESS の TO の ETA の差が 1 分以内。
- **直す案**：右上の 3 つと `route_eta` を、PROGRESS と同じ `B747_fms_preds()` の現用点から作る。予測が無い間だけ今の式にする。地上の条件を外す。

### DSP-3　着陸すると、前の離陸の「D-TO 1 +47C」が EICAS に戻る（型 J。87a34b56 の直し残しの疑い）

- **場所**：
  - `B747.68.thrlim_model.lua:147-155`（地上は `mode = "TO"`、`s.d = inp.sel_up`）
  - `B747.68.xt.fms.lua:2669-2671`（EICAS の行）
  - `B747.68.xt.fms.lua:5767-5782`（SEL を消すのは flight complete＝エンジン停止の 30 秒後）
  - `tests/fms/takeoff_ref_test.lua:303-306`
- **何が起きるか**：SEL を入れた離陸の後、空中では出なくなった。しかし接地した瞬間に推力制限が TO に戻り、SEL が目的地の外気温より高ければ、滑走からスポットインの間ずっと「D-TO 1 +47C」が出る。エンジンを止めて 30 秒後まで続く。
- **どう確かめたか**：`dsp4_sel_after_landing.lua`（本番の `thrlim_model` を通し、EICAS の行は `update_thrlim` の式が同じことを assert して写した）。出力：
  - ゲート「D-TO 1 +47C」→ 上昇「CLB 1」→ 巡航「CRZ」→ 進入「GA」→ 接地・滑走「D-TO 1 +47C」→ 地上滑走「D-TO 1 +47C」。
  - 回帰試験の 306 行は、この出方を期待値として固定している。
- **根拠**：
  - FCOM p.831 (7.10.3)：仮定温度は「for reduced thrust takeoff」。
  - ATA34_2 p.535：地上では TO を自動で選ぶ。
  - FCOM p.1236 (11.31.2)：flight complete はエンジン停止の 30 秒後。
  - SEL がいつ消えるかは**資料なし**。FMSPG p.101 は「TOGA で離陸を始めた後は入力できない」だけ。
- **重さ**：乗員に見える（減格離陸をした便の着陸のたび）。**確かさ**：動きは確か。誤りかどうかは未確認。利用者に聞く項目。
- **シナリオの案**：`s339_eicas_sel_climb`（RJAA 34L、SEL 50）を場周で着陸まで延ばす。接地の 5 秒後と地上滑走で `laminar/B747/fms/thrlim/eicas` を読む（今は「D-TO +50C」の見込み）。EICAS の行を着陸の後で見るシナリオは 1 本も無い。
- **直す案**（決まれば）：上昇の制限に移った時、または接地の時に SEL と離陸の減格を消し、着陸の後は「TO」だけにする。306 行の期待値も合わせる。

### DSP-4　GE（570）の PFD で、109 と違う 3 点が未実装で、残りの一覧にも無い（型 I）

- **場所**：
  - `747-400_custom.acf:75625-75767`（`GROUP V-Speeds`：V1・VR・NO V SPD だけ。パネル全体に `airspeed/V2` を読む計器が無い）
  - `:75640-75657`（REF は印だけ）
  - `B747.60.minspeed_model.lua:304`（`show_pli = not flaps_up ...` が型式によらない）
- **何が起きるか**：GE の機体でも P&W と同じ出方になる。
  1. 離陸の V2 の表示が無い。
  2. 着陸フラップと VREF の数字（「30/140」）が無い。
  3. フラップ上げの低速で PLI が出ない。
- **どう確かめたか**：読んだだけ（パネルの dataref の一覧 `show_conditions.txt`、FCOM の絵）。
- **根拠**：
  - FCOM p.970 (10.10.8) の図と p.972 (10.10.10)：570 は V1・VR・V2 を出し、V2 は上昇でフラップを上げ始めると消える。
  - p.973 (10.10.11)：570 は着陸フラップと VREF を出す。
  - p.975 (10.10.13)・p.977 (10.10.15)：PLI は 405・570 で「フラップが上がっていないとき、またはフラップ上げの低速」。
- **重さ**：軽い（GE だけ。利用者は GE でもラインを飛ぶ）。**確かさ**：確か。
- **既知との関係**：DIFFERENCES.md の残りにあるのは RADIO/BARO の minimums と ND の TAS。EFFECTIVITY_405.md は PLI を 405 の違いとしてだけ書いている。
- **直す案**：`engines/type` が 1 のときだけ、V2 の印（フラップ上げ開始で消す）、REF の横のフラップと速度、フラップ上げの PLI を出す。

### DSP-5　P&W の N1 モード（ALTN）の飛行中のアイドルで、指令の EPR が 0.5 になる（型 F。c30c5ef5）

- **場所**：`B747.42.xt.eec_thrust.lua:63-76`（`epr_of_n1`：0.5〜1.9 の二分法）、`:132-134`。
- **何が起きるか**：レバーがアイドルのときの N1 の指令は約 20 %。飛行中は EPR 0.9 でも N1 のモデルがそれより高いので、解が下の端の 0.5 に張り付く。印は 58a70e1d の止めで目盛の下端に行く。
- **どう確かめたか**：`dsp5_altn_cmd.lua`（`epr_of_n1` は local なので、同じ文が HEAD にあることを assert して写した）。出力 `dsp5_altn_cmd.txt`：
  - 3,000 ft・M.34：N1 モード 0.500（EPR モード 0.919、表示 0.951）で、印はバーの端の 15 px 下。
  - 地上の停止：1.021 で問題なし。
- **根拠**：FCOM p.834 (7.10.6)、p.873 (7.20.3)。ALTN での印の意味は資料なし（コードも推定と明記）。
- **重さ**：軽い（ALTN のアイドルだけ）。**確かさ**：確か（計算）。
- **直す案**：下の端に張り付いたら、EPR モードのアイドルの指令（`idle_command`）を下限にする。

### DSP-6　軽いもの（まとめ）

- **(a) 副操縦士の PFD が機長側の値を読む所**（`scan_cross_side.lua`、出力 `cross_side.txt`）：
  - NO V SPD の条件が機長の電波高度（`acf:85056`・`85084`・`89299`・`89327`）。
  - 昇降率の数字が機長の VVI を丸めた `laminar/B747/vsi/fpm`（`acf:85667`・`85684`、`fltInst02.lua:2165`）。針と SHOW は副操縦士側。
- **(b) 接地の前に NO V SPD が出る**：V1・VR・NO V SPD は X-Plane の電波高度 10 ft 以下で出る（`acf:75660`・`75698`・`75714`）。フレアの最後の 10 ft から出る。実機の条件は資料なし。
- **(c) 地上で出さない帯と印**：フラップの機動速度の印と最大速度の帯は電波高度 10 ft 未満で出ない（`acf:75424`・`75769`）。FCOM p.972 (10.10.10) に「地上では出さない」は無い。離陸の滑走の約 100 kt から浮揚までが違う。純正からの決めで、未確認。
- **(d) 試験の穴**（変異試験。`mut_engine_display.lua` は 15 本中 5 本、`mut_status_nvm.lua` は 15 本中 2 本を見逃し）：
  - EPR の赤の幅 0.003 と 0.01 を入れ替えても通る。
  - SEL を「D- なし」で出しても通る。
  - RB211 の N3 の部分表示、CUTOFF の閾値、CF6 の油量差の「空中」の条件。
  - STATUS は、電源断の `power_off` と ERASE の初回の読み。

---

### 段 1〜3 の直しを見た結果

| コミット | 結果 |
|---|---|
| 87a34b56 | 空中で温度が付かないことは問題なし（「どのモードでも SEL」に戻す変異は試験が検出）。着陸の後に戻る件は DSP-3。「D- なし」の穴は DSP-6 (d)。 |
| 58a70e1d | `TRA` の出し方は問題なし（アイドルの指令は s336 の記録で 0.612、パネルが下端で止める）。逆推力のときの SHOW の条件は DSP-1。 |
| b134fbf1 | P&W の逆推力の表示は問題なし（s340 の写真で EPR 1.17・N1 68.4、赤なし）。max EPR の赤の規則そのものは逆推力の間も働くままで、推力を下げて届かなくした形。RR は未確認（下）。 |
| 16e396c8 | N2 の赤線 105.5 は問題なし（古い値に戻す変異、「以上」を「超」にする変異とも検出）。EPR の赤の幅は試験が固定していない（DSP-6 (d)）。 |
| c30c5ef5 | DSP-5。全開側は 1.9 で止まり、パネルが上端で止めるので問題なし。 |
| 5012a8fb | 問題なし（NVM のモデルの変異 9 本は全部検出、グルーは 6 本中 4 本）。副作用は「範囲の外」の 2 つ目。 |

### 見て問題が無かった所

- **パネルの SHOW の重なり**：同じ計器に SHOW が 2 本以上あるのは 131 か所で、すべて同じ dataref の範囲。別々の dataref の重なりは 0（`scan_double_show.lua`）。
- **モデルと資料の突き合わせ**：
  - `hdg_ref_model`：FCOM p.1110 (10.40.2)・p.1046 (10.10.84) のとおり。
  - `pfd_ils_model` の偏位の警告：ATA34_1 p.468 のとおり。
  - 気圧の琥珀の枠：FCOM p.995 (10.10.33) の文字どおり。
  - DH の点滅と解除：p.981-982 のとおり。
  - `eicas_format_model`：p.872-875 のとおり。
  - EGT の琥珀の抑止（5 分・10 分）：p.872 のとおり。
  - VNAV の偏位の指針（降下だけ、±400 ft）：p.1149 のとおり。
  - 速度の傾向の線：10 秒先（6 kt/s で 60 kt）。
- **指令速度のバグ**：地上で上端に止まる（対気速度は 30 kt を下限にした値を読む。写真 `20261120_215805_s103_afds_to_747-400_custom/shot_28_pfd_to.png`）。
- **二次 EICAS の FF の枠**：X-Plane の N2 が 100 以下のときだけ出る条件。s10・s11 の記録の最大は 99.87 で、消えない。
- **回帰試験**：`tests/displays/` の 29 本と、エンジン表示・STATUS の 3 本は全部合格。

### 範囲の外で気づいたこと

- **アイドル降下の表示の EPR が目盛より下**（担当 4・5 向け）：P&W で 0.66〜0.85。FL350 から約 12,000 ft まで、パネルの目盛の下端 0.85 より下で、バーが空で数字だけになる。`dsp_cmd_idle.lua` で s273・s140・s198 の記録から出した（FL350・M.82 で 0.659）。EPR のモデルの当てはめの範囲（0.96〜1.43）の外。実機のアイドルの EPR の資料は見つけていない。
- **BODY GR STRG SYS がラッチしたまま残る**（担当 7・10 向け）：トラックが切れたまま油圧 1 が抜けると、5 秒で STATUS が NVM にラッチする。次の始動で中立に戻っても、CMC の ERASE まで残る。`side_body_gear_latch.lua` でモデルだけを通して確かめた。tiller を持ったまま油圧が抜けるときだけなので、まれ。
- **気圧の琥珀の枠の MCP 高度の比較**：降下でも CLB ページの TRANS ALT（出発地）を使う。TA の低い所から TL の高い所へ飛ぶと、MCP が出発地の TA を下回るまで出ない。FCOM の文字どおりで、降下で何を使うかは資料なし。
- **HPA のつまみ**：1 クリック 0.01 inHg のままなので、3 クリックで 1 hPa。刻みの資料なし。

### 見られなかった所

- 各系統の synoptic と STATUS ページの値（固定の文字や絵の総当たり）。
- 時計（`clock_model`、`fltInst03`）、TCAS・WXR の表示の細部、`nd_line.c`、空港とコースの線、CDU の EFIS 代替操作。
- FMA の緑の枠の時計（AFDS のモジュール側）は読んだだけ。
- RR の逆推力いっぱいの EPR：古い RR のコードは表示の EPR を max で頭打ちにするので、赤になりうる。資料なしで、X-Plane でしか確かめられない。
- `reverser_deployed` が transit の間に立つかどうか（DSP-1 のシナリオで読む）。
- LCD 型の PFD の違い。

# 第 2 波 担当 10：系統 A（SYS-n）

## 担当 10（系統 A）の報告：指摘 7 件（SYS-1〜7）

乗員に見える誤りが 2 件（SYS-1・2）、資料と合わない値が 1 件（SYS-3）、軽いもの 3 件、試験の穴 1 件です。X-Plane は触っていません。スクリプトと出力は `D:\b747_review\stage4\a10_systems\` にあります。

### 指摘

#### SYS-1　巡航の ΔP がパネルの色の境目ちょうどで、数字が消える（型 G）

- **場所**：`B747.55.press_model.lua:34`（`M.CRUISE_DP = 8.8`）、`:186-189`、`:371`。`747-400_custom.acf:151975-152040`（`GROUP Diff Press`）。
- **何が起きるか**：
  - FMC の巡航高度がある巡航（海面の空港なら約 FL250〜FL450）では、ΔP の目標がちょうど 8.800 psi になる。
  - パネルは白が −0.49〜8.8、琥珀が 8.9〜9.0、赤が 9.1 以上。8.8 を少しでも超えると 8.9 まで何も描かれない。
  - 主 EICAS の data block の「ΔP」の数字が、巡航中に出たり消えたりする。9.0〜9.1 と −0.5〜−0.49 にも同じ隙間がある。
- **どう確かめたか**：
  - `exp2_press_dp.lua`（本番のモデル、dt 0.02）：
    - 高度が ±10 ft 揺れると、60 分のうち約 50 % で空白（約 20 秒ごとに出入り）。
    - 水平になって最初の 1 分は 100 % 空白。
    - 揺れなしの FL350 は 8.80001 に落ち着き、60 分ずっと空白。
  - `exp3_panel_ranges.lua`：パネルの範囲を走査し、隙間 (8.8, 8.9)・(9, 9.1)・(−0.5, −0.49) を確認。
  - 過去の X-Plane の記録（どちらも古い回だが、パネルのこの定義と `CRUISE_DP` は当時から変わっていない）：
    - 2026-10-26 の `s25_data_block`：ΔP 8.8028 で、`shot_15_eicas_cruise.png` の ΔP の数字が空白。
    - 2026-10-25 の `s25`：ΔP 8.7875 で「8.8」が出ている。
- **根拠**：ATA21 p.452 (21-30 Page 60) は表示の値で「白 −0.4〜+8.8、琥珀 +8.9〜+9.0、赤 +9.1 以上」。小数 1 桁に丸めた値の範囲なので、生の値では 8.85・9.05・−0.45 が境。グルーの data block の自動表示は既に 8.85 を使っている（`B747.55.xt.press.lua:190`）。
- **重さ・確かさ**：乗員に見える誤り／確か。
- **シナリオの案**：FMC に巡航高度と目的地を入れた上昇で FL250 以上に水平。5 分間、10 秒ごとに `sim/cockpit2/pressurization/indicators/pressure_diffential_psi` を読み、ENG か ECS の synoptic を出して EICAS を 2〜3 枚撮る。合格は、8.80〜8.90 の値のときも数字が出ていること。
- **直す案**：パネルの範囲を、白 −0.449〜8.849、琥珀 8.85〜9.049、赤 9.05 以上、下の琥珀 −0.45 以下にする（PNEU-10 でダクト圧を 11.5 にしたのと同じ考え）。

#### SYS-2　tank to engine のラッチが接地で消え、着陸のたびにメッセージが戻りうる（型 J）

- **場所**：`B747.28.fuel_model.lua:459`・`:515`（`elseif inp.on_ground then s.tank_eng_reached = false`）、`:468`、`:528`。
- **何が起きるか**：
  - 2026-11-12 の FA-1 の直しで、tank to engine の条件は到達でラッチするようになった。
  - そのラッチが接地の瞬間に消える。
  - 着陸の時に主 2 > 主 1 かつ主 3 > 主 4（数 kg でも）なら、接地の 1 秒後に FUEL OVRD 2 AFT・2 FWD・3 AFT・3 FWD と >X FEED CONFIG の 5 つが出て、駐機まで残る。
  - 起きる条件は、CWT の残りのスカベンジが手順の後まで続いた飛行、外側エンジンの消費が少し多い飛行。FA-1 が空中で防いだものが地上で戻る形。
- **どう確かめたか**：`exp4_fuel_landing.lua`。手順の後、エンジン 1 の流量を +0.5 % にして 2 時間飛ばすと、主 2 − 主 1 が +24 kg、主 3 − 主 4 が +149 kg。空中はメッセージなし。接地 +1 秒で `oj2_aft oj2_fwd oj3_aft oj3_fwd xfeed_config`、地上滑走 10 分後も同じ。流量が等しい場合（主 2 ≤ 主 1）は出ない。
- **根拠**：FCOM p.1474 (12.30.2)「スイッチ OFF で tank-to-engine の構成の前に出る」、p.1479 (12.30.7)、p.1473 (12.30.1)「FUEL TANK/ENG の条件に達した後」。ラッチをいつ解くかは資料なし（今の「地上で解く」はコードに推定と書いてある）。
- **重さ・確かさ**：乗員に見える誤り／コードの動きは確か、ラインの飛行で起きる頻度はたぶん。
- **シナリオの案**：
  1. 最終進入の空中開始（autoland のシナリオ）で、OVRD 2・3 の 4 つを OFF、X FEED 1・4 を OFF。
  2. `m_fuel[1..4]` を 9000・8990・8990・9000 にして 5 秒待つ。
  3. `m_fuel[2]`・`[3]` を 9030 に書く（20 kg を超える外からの変更は取り込まれる）。
  4. 接地の 5 秒後に `CAS/advisory_status[155..158]` と `[299]` を読む。合格は全部 0。
- **直す案**：ラッチを解くのは、新しいフライト、地上で燃料が増えたとき（給油・W&B の窓）、全エンジン停止の後のいずれかにする。

#### SYS-3　APU の燃料消費 150 kg/h は、FPPM の半分（型 F）

- **場所**：`B747.28.fuel_model.lua:81`（`M.APU_KGH = 150`、「資料に値なし」の推定）、`:404`。試験 `tests/fuel/fuel_model_test.lua:426` も 150 を固定している。
- **何が起きるか**：APU 運転中の主 2 の減りが実機の半分。90 分の折り返しで 225 kg（FPPM なら 450 kg）。
- **どう確かめたか**：`exp1_models.lua` の C。主 2 が 1 時間で 36,000 → 35,850 kg。
- **根拠**：FPPM p.83 (2.1.1)「APU の平均の燃料流量は地上 300 kg/h、通常の運用高度で 270 kg/h」。FPPM p.107 (3.1.1) も「APU の分として 270 kg/h を足す」。GAP_ANALYSIS §7 と 2026-11-19 の資料の報告には無い。APU は全型式 PW901A（AC_SPECS p.1、ノートから）。
- **重さ・確かさ**：軽い（燃料の表示と残量）／確か。
- **シナリオの案**：不要（モデルの定数）。見るなら、地上で APU を 10 分回して `m_fuel[2]` が 50 kg 減ること。
- **直す案**：地上 300、空中 270 kg/h にし、推定の印を FPPM の出典に替え、試験の 150 も直す。

#### SYS-4　作動油の温度が巡航で −26 ℃ になる（型 F）

- **場所**：`B747.19.hyd_model.lua:66`・`:319-323`（外気温 + 30 ℃ を 600 秒で追う）、`B747.19.xt.hydraulicsmodel.lua:73`、`B747.19.xt.hyd_power.lua:155`。
- **何が起きるか**：
  - 2026-11-13 の HA-2 の直しで、基準が機体の位置の外気温（SAT）になった。
  - 地上 15 ℃ では 45 ℃（FCOM の例 50 ℃ に近い）だが、巡航では 4 系統とも約 −26 ℃ まで下がる。
  - STATUS と HYD synoptic の HYD TEMP の計器には負号の部品が無いので、おそらく「26」と出る（45 → 0 → 26 と動く）。
- **どう確かめたか**：`exp1_models.lua` の B。外気温 −56.5 ℃ で 10 分後 −0.2、30 分後 −22.9、60 分後 −26.3 ℃。−70 ℃ なら −39.8 ℃。45 ℃ の地上は 74.9 ℃（104 ℃ 未満）。X-Plane の記録は地上の 44.7 ℃ だけで、巡航の値は撮られていない。
- **根拠**：ATA29_32 p.100 (29 Page 98) は、測るのがポンプのケースドレン油（ポンプで温まった油）であること。p.76 (29 Page 74) は、冷やす先が各主タンクの中の熱交換器（燃料）であること。巡航の値そのものは資料なし（FCOM p.1485 (13.10.3) の例は 50）。
- **重さ・確かさ**：軽い／式の出す値は確か、実機との差はたぶん。
- **シナリオの案**：FL350 の空中開始で 30 分。`laminar/B747/hydraulics/temp_1..4` を読み、STAT のページを撮る（負の値の出方も分かる）。
- **直す案**：基準を燃料温度（燃料モデルの値）か TAT にし、「推定」と書く。負になりうるなら、パネルに負号を足す。

#### SYS-5　負の温度に符号が出ないと見られる：ECS synoptic のゾーン温度と貨物室温度（型 G）

- **場所**：`747-400_custom.acf:165685` 付近（`Zone ... Actual`、`DIGITS 2`）、`:165916`（`Aft Cargo Temp`）。値は `B747.55.temp_model.lua`。
- **何が起きるか**：寒い空港で駐機した機体はゾーンが外気温から始まる。−30 ℃ なら、暖まる間 −30 → 0 → 24 ℃ と動く。パネル全体で負号の部品は TAT・LDG ALT・客室昇降率・燃料温度の 4 つだけなので、「30、20、10、0、10、20」と読めるはず。後方貨物室も、寒い日の巡航で −3.5 ℃ から始まる。
- **どう確かめたか**：`exp5_temp.lua` で値を確認。計器が絶対値を出すことは、燃料温度のノート（notes/ATA-28.md の「数字は絶対値を丸める」）からの類推で、X-Plane では見ていない。
- **根拠**：資料なし（負の温度の表示例は無い）。客室高度に負号が無いことは PROGRESS に既にある。
- **重さ・確かさ**：軽い／未確認。
- **シナリオの案**：外気温 −20 ℃ の空港でコールド＆ダーク開始、電源を入れて ECS synoptic を撮る。`laminar/B747/air/temp/zone_actual[2]` が約 −20 のときの表示を見る。
- **直す案**：負号の部品を足す（パネルの計器は承認なしで変えられる）。

#### SYS-6　地上のエンジン始動で、IDG 2 台と APU（か外部電源）のときにギャレー 1・2・4 が落ちる（型 J）

- **場所**：`B747.03.elec_model.lua:493-500`（`if gens == 2 then target = 3`）。
- **何が起きるか**：負荷制限を IDG の台数だけで決めている。APU 発電機で始動してエンジン 4・3 が入った時点で、左側は APU が給電しているのにギャレー 1・4・2 が落ちる。3 台目が入るまで続く。見えるのは ELEC synoptic の GALLEY だけ（UTIL OFF 灯と ELEC UTIL BUS は抑止される）。
- **どう確かめたか**：`exp1_models.lua` の A。`gcb=0011 apb=10` で `shed=3 galley=0010`、60 秒後も同じ。エンジン 2 が入ると戻る。外部電源でも同じ。
- **根拠**：LH24 p.236・p.240 (24-50 Page 234・238) は、負荷制限は需要が容量を超えたときで、BCU は SSB・BTB・GCB・APB・XPC から構成を見るとしている。FCOM p.795 (6.20.1) も「負荷が使える電力（機体か外部）を超えたら」。SSB が開いて IDG 2 台が自分の 2 母線だけを持つなら、1 台あたりの負荷は 4 台のときと同じ。
- **重さ・確かさ**：軽い／確か（模型）。
- **シナリオの案**：地上で APU GEN 1・2 を入れ、エンジン 4・3 だけ始動。`laminar/B747/electrical/bus/galley[0..3]` と `load_shed` を読む。合格は全部 1 と 0。
- **直す案**：2 台のときの負荷制限を、EXT も APU もつながっていないときだけにする。

#### SYS-7　c12893e9 のつなぎ（どの FCU がどの系統か）を見る試験が無い（試験の穴）

- **場所**：`B747.19.xt.hyd_power.lua:149-154`、`tests/hyd/hyd_module_test.lua`。
- **何が起きるか**：FCU の L と R を取り違えても、試験は通る。
- **どう確かめたか**：`mut_hyd_fcu.lua`（出力 `mut_hyd_fcu.out`）。モデルの変異 3 個は捕まる。つなぎの変異は全部素通り：添字の入れ替え 3 個、常に正常 2 個、`flaps_down`・`flaps_moving` を常に false、外気温を 15 固定（HA-2 の直し）。X-Plane のシナリオ（s04・s241）も FCU の故障を入れていない。
- **根拠**：ATA29_32 p.61-62 (29 Page 59-60)、MMEL p.139 (27-3)。コードの添字は読んで資料どおり（`fcu[2]` = R → 系統 1、`fcu[0]` = L → 系統 4）。
- **重さ・確かさ**：軽い／確か。
- **シナリオの案**：
  1. 地上・エンジン運転・デマンド 1・4 AUTO で、`laminar/B747/flt_ctrls/fail/fcu[2] = 1`。
  2. フラップを 0 → 10 に動かす間、`hydraulics/dem_pressure_1` が 0、`dem_pressure_4` が 2,000 以上。
  3. `fcu[0]` で逆になること。
- **直す案**：`hyd_module_test` に、FCU の故障とフラップの信号を入れる試験を数件足す。

### 段 1〜3 の直しを見た結果

- **c12893e9（N19-HYD-01）**：直しそのものは問題なし。
  - ATA29_32 p.61-62、MMEL p.139、FCOM p.1483 (13.10.1) と照らした：右の FCU が系統 1、左が系統 4、ON は FCU に依らない、CUTOFF とデマンドの信号はそのまま、地上は動いている間・空中は出ている間 + 10 秒。
  - つなぎの試験が無い点は SYS-7。
  - ATA29_32 p.61 は「P&W と GE の機体では」と限っている。RR が違うかは資料なし。
- **5012a8fb の `B747.03.xt.elec_buses.lua`**：問題なし。変更は注釈だけ。DRIVE DISC を切り離しの間 STATUS に出し、リセット後も ERASE まで残す形は LH24 p.64 と合う。HYD OVHT SYS の NVM-A は ATA29_32 p.100 と合う。

### 見て問題が無かった所

- **与圧**（`exp1_models.lua` の D）：巡航高度 10,000〜45,000 ft、標高 0〜9,200 ft の空港、FMC なし、速い上昇・降下で確認。
  - 離陸の予圧は −44〜−50 ft、巡航の客室は FL390 で 6,278 ft（FCOM p.585 の例 6,250）、最大 8,000 ft、接地で空港の 48〜60 ft 下、着陸後に ΔP 0.02。
  - 標高 8,000 ft 超の離陸で客室が下がる動きも FCOM p.608 どおり。
  - 13,300 ft の着陸で 11,000 ft のリミッタが弁を閉じたままになるのは、ATA21 p.406（低高度側のスイッチだけ有効）どおり。
- **温度**（`exp5_temp.lua`）：−30 ℃ の駐機から 20 分で目標、45 ℃ は 3 パックで 30 分、巡航の comfort correction は +2.2 ℃ を 2 時間。
- **燃料**：しきい値は FCOM p.1464–1479 と一致。570 のポンド値との差は 1 % 以内。クロスフィード 2・3 の 40 秒と離陸範囲は ATA26_28 p.461-462 どおり。
- **そのほかモデルを読んだ所**：電源（切替・transfer bus・standby・air mode の N2）、APU、抽気、パック、機器冷却（FCOM p.605・p.619）、防氷のメッセージ（FCOM p.635）、火災、酸素（気体の法則：−30 ℃ で 1,526 psi）。

### 範囲の外・既知と重なること

- FPPM p.83 (2.1.1) に「地上滑走の燃料は約 45 kg/分」（4 発で 2,700 kg/h）がある。地上アイドルの燃料流量と比べられる（エンジン担当向け、未確認）。
- 客室高度の数字に負号が無い（既知：PROGRESS「気づいたこと」）。気圧の高い海面の空港では −400 ft 台が「400」と出るはず。
- HYD QTY は漏れの故障以外いつも 1.00（HYD-16 で決めた形）。FCOM p.1489 は「温度と作動で変動する」。notes/ATA-29.md §4.8 の「脚・ブレーキ・フラップで少し下がる」は入っていない。
- 始動に要る圧と APU の空中 15,000 ft の判定が、機長の高度計の指示高度（`B747.55.xt.bleed.lua:161`）。気圧高度の方が筋。軽い。
- バウンドした着陸では、CPC と PTC の交代が 2 回起きて元に戻る。軽い。
- 地上開始で 100 t 以下だと、X-Plane の比例配分（CWT と安定板タンクにも入る）のまま（既知：FUEL-21）。

### 見られなかった所

- X-Plane での確かめ全部（シナリオの案として返した）。パネルの LED が負の値をどう描くかは未確認（SYS-4・5 の前提）。
- グルーのうち `B747.35.xt.fire.lua`、`B747.55.xt.packs.lua`・`xt.eqcool.lua`、`B747.19.xt.hydraulics_override.lua`、`B747.20.xt.hydraulics.lua` の本体、各 `init/scripts` の定義は、行ごとには読んでいない。
- 系統のシナリオ（`tests/flight/scenarios/`）の中身は、s15・s25 のほかは見ていない。変異の試験は c12893e9 の周りだけ。
- MMEL・CB_BA・QRH_CA との突き合わせ、APU の EGT（X-Plane の値のまま）、X-Plane の抽気の損失の値（`engine_loss_from_bleed_air_ratio`）の効き方。

# 第 2 波 担当 11：系統 B（NAV-n）

## 担当 11（系統 B：航法センサー・無線と通信・照明・操作・AI・FDR・設定・橋渡し）の報告

指摘は 5 件です。乗員に見える誤りが 1 件（NAV-1）、段 1〜3 のキットの直しの穴が 1 件（NAV-2）、軽いものが 3 件（NAV-3〜5）。X-Plane は触っていません。リポジトリも変えていません（`git status` は始めと同じ）。スクリプトと出力は `D:\b747_review\stage4\a11_nav_misc\` にあります。

### 指摘

#### NAV-1　DOORS AUTO の memo と CALL のチャイムの抑止が、「離陸推力」を X-Plane のスロットルで見ている（型 J）

- **場所**：
  - `plugins/xtlua/scripts/B747.85.xt.safety/B747.85.xt.safety.lua:65`・`:223`・`:236-248`
  - `plugins/xtlua/scripts/B747.15.xt.com/B747.15.xt.acp.lua:67`・`:71-79`
- **何が起きるか**：どちらも `sim/cockpit2/engine/actuators/throttle_ratio` が 0.6 以上かで「離陸推力」を決める。これは利用者の手元のスロットルで、A/T は動かさない。
  - A/T が動かすのは `laminar/B747/engine/throttle` だけ（`B747.42.xt.EEC.lua:1102` の `at_servo_levers`。`:939`・`:1010` の書き込みは注釈）。`sim/engines/TOGA_power` も `replace_command` で置き換え済み。
  - 段 3 の b134fbf1 のコミット文にも「s340：X-Plane のスロットル 0.5、機体のレバー 0」とある。
  - TO/GA の A/T 離陸で、手元のスロットルが 0.6 未満だと、離陸滑走の間ずっと EICAS に DOORS AUTO が出たまま。消えるのは離陸の 10 秒後。
  - 着陸後に手元のスロットルを 0.6 以上に残すと、絞るまで DOORS AUTO が戻らない。
  - チャイムも同じで、滑走の 75 kt までは抑止されない。ただし CALL はコマンドでしか立たないので、影響は小さい。
- **どう確かめたか**：`doors_memo_at.lua`（試験のモックで safety のモジュールを回した）。出力は `doors_memo_at_out.txt`。

  | 場面 | DOORS AUTO |
  |---|---|
  | 滑走 30 秒、747 のレバー 0.92、X-Plane のスロットル 0.45 | 1（出たまま） |
  | 離陸の 9 秒後 | 1 |
  | 離陸の 11 秒後 | 0 |
  | 着陸後 180 秒、X-Plane のスロットル 0.70 のまま | 0（戻らない） |
  | スロットルをアイドルにして 61 秒後 | 1 |
  | 滑走で X-Plane のスロットル 0.90 | 0 |

  - s142 の 2026-11-22 の回では、67 kt で `engine/throttle[0]` が 0.96。キットは手元のスロットルを動かさない。
  - `tests/safety/safety_module_test.lua:85-87` も X-Plane のスロットルを 0.9 にして確かめているので、この場合を通らない。
- **根拠**：
  - DOORS AUTO は離陸推力が出てから着陸後 1 分まで抑止：ATA38_51_52_56 p.304（ATA 52-00 Page 96）。
  - チャイムは「いずれかのエンジンが離陸推力の範囲」から 400 ft RA まで抑止：FCOM p.1593 (15.20.47)。
  - 「離陸推力」の中身はどちらの資料にも無い（資料なし）。段 3 の離陸形態警報は内側エンジンの N1 表示（ATA27 p.730）にした（これはコミット文から）。
- **重さ**：乗員に見える誤り（軽い）。**確かさ**：確か（モジュールの動き）。実機で何を離陸推力とするかは推定。
- **シナリオの案**：
  - 開始：RJAA 34L、エンジン運転中、270 t、機体を読み直す。手元のスロットルは 0 のまま。
  - `laminar/B747/CAS/memo_status[9]` が 1 を確かめる。フラップ 20、F/D、A/T ARM、`sim/engines/TOGA_power`。
  - `laminar/B747/engine/throttle[1]` > 0.6 かつ `laminar/B747/engines/display_N1[1]` > 70 を待ち、`memo_status[9]` を見る。合格は 0（今は 1 のはず）。
  - 同じ所で `laminar/B747/comm/call/cab` を送り、`laminar/B747/comm/call_chime` が 0 のまま（今は 1 のはず）。
  - 離陸の 15 秒後に `memo_status[9]` が 0。
- **直す案**：離陸形態警報と同じ「離陸推力」（内側エンジンの N1 表示がしきい値より上で、逆推力は格納）を 1 か所で作り、ドアの memo とチャイムへ渡す。試験は機体のレバーと N1 で与える。

#### NAV-2　58224644 の `remove {path_dref}`：SimBrief の取得に失敗した回は、前からあるファイルを消す（型の外：直しの穴）

- **場所**：`tests/flight/run_scenario.ps1:692-709`、`tests/flight/scenarios/s218_simbrief_fetch.json:57-58`、`plugins/b747_fms_bridge/src/b747_fms_bridge.c:188-207`・`:262-263`
- **何が起きるか**：
  - `fms/company/fms_file`・`ofp_file` は「今回取ったファイル」ではなく、simbrief フォルダーのいちばん新しい `*.fms`・`*.xml` の名前。
  - s218 には `"stop": true` の手順が 1 つも無い。取得が失敗しても（回線なし、SimBrief の無応答）最後の 2 つの remove まで進む。
  - 失敗した回は、FMC がフォルダーのいちばん新しいファイルでアップリンクする（`simbrief/README.txt`）。途中の名前の check も、8 文字の名前なら通る。
  - その結果、その回が作っていないファイルを消す。直す前は `RJFFPANC.*` の決め打ちだったので、失敗しても何も消えなかった。
- **どう確かめたか**：`s218_remove_dryrun.ps1`（キットと同じ道筋の計算だけ。消さない）。出力は `s218_remove_dryrun_out.txt`。いま失敗すると消えるのは次の 2 つ。
  - `simbrief\KSEAKLAX.fms`（566 バイト。`tests/flight/data/simbrief` に写しあり）
  - `simbrief\KSEAKLAX.xml`（929,236 バイト、2026-11-09。git の管理外で、写しはどこにも無い）
  - `simbrief/_newest.txt` も同じ 2 つを指している。
  - `tests/flight/kit_offline_test.ps1` に `path_dref` の試験は無い（鍵の静的検査だけ）。
- **根拠**：資料なし（キットの作り）。
- **重さ**：軽い（試験が利用者のファイルを消しうる）。**確かさ**：確か。
- **X-Plane では見ない**。キットのオフライン試験に足す：偽の dataref が前からある古いファイルを指すとき、消さずに warn になること。
- **直す案**：「取れた（`simbrief_status` が 2）」の check に `"stop": true` を付ける。加えて、remove はシナリオの開始より後に書かれたファイルだけを消す。

#### NAV-3　チョークを入れる操作に、地上で止まっているかの守りが無い（型 J・I）

- **場所**：`plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.pages.lua:2718-2729`、`plugins/b747_fms_bridge/src/gh_window.c:41`、`plugins/xtlua/scripts/B747.10.xt.gear/B747.10.brake_model.lua:95`、`B747.10.xt.brakes.lua:194`
- **何が起きるか**：
  - Ground handling の窓の PLACE、CDU の GROUND HANDLING 2L、コマンド `laminar/B747/gear/chocks_toggle` は、どの速さでも `gear/chocked` を 1 にする。
  - ブレーキのモデルはそれだけで X-Plane のパーキングブレーキを 1.0 にする。地上走行でも滑走でも全ブレーキになり、PARK BRAKE SET の memo は出ない。
  - 同じ窓の GPU は「地上で止まっている」ときだけつながる（`B747.03.xt.electrical.lua:373`）。チョークだけ守りが無い。
  - 空中は `B747.45.xt.fltCtrls.lua:623-625` が毎フレーム 0 に戻すので残らない。
- **どう確かめたか**：`chocks_moving.lua`（ブレーキのモデル）。レバーを放した地上で chocked を入れると `park=1.00`、`PARK BRAKE SET=false`。出力は `chocks_moving_out.txt`。
  - 同じ出力の下 2 行（`chocks_new_flight.lua`）：C&D の開始のあと、機体を読み直さずにエンジン運転中で始めると chocked は 1 のまま（モックで）。X-Plane で機体が読み直されない場合に起きるかは未確認。
- **根拠**：資料なし（シムの便利機能）。
- **重さ**：軽い（押し間違いへの守り）。**確かさ**：確か。
- **シナリオの案**：RJAA の誘導路で対地 15 kt、`chocks_toggle` を 0.2 秒送る。合格は `laminar/B747/gear/chocked` が 0 のまま、`sim/cockpit2/controls/parking_brake_ratio` が 0 のまま（今は 1 になって止まるはず）。
- **直す案**：入れるのは PSEU の地上で対地速度が GPU と同じしきい値より下のときだけ。外すのはいつでも。

#### NAV-4　ADC の気圧補正の式が、高度計の則と形が違う（型 F。X-Plane の則は未確認）

- **場所**：`plugins/xtlua/scripts/B747.34.xt.nav/B747.34.airdata_model.lua:69-77`、`B747.34.xt.airdata.lua:129-131`
- **何が起きるか**：
  - `baro_alt`・`pressure_alt` は h = K(1 − (p/設定)^n) の形で、補正の量が高度で縮む（FL350 で 1 inHg あたり 688 ft）。
  - 高度計の補正は設定だけで決まる足し算（ISA で 1 inHg あたり 911 ft）で、高度によらない。
  - 自分の側の ADC を選んでいる間は、行って戻るだけなので誤差は出ない。
  - 左右の気圧設定が違うときだけ、X-Plane の 2 つの高度計から作る「未補正の高度」が食い違い、誤った ALT DISAGREE が出うる。機長が R を選んだときの PFD の高度も同じ量だけずれる。
- **どう確かめたか**：`baro_law.lua`（出力 `baro_law_out.txt`）。X-Plane の高度計が足し算の則だと仮定した場合の、モデルの未補正高度の左右差。

  | 条件 | ISA の足し算 | 1000 ft/inHg |
  |---|---|---|
  | FL350、差 1.0 inHg | −225 ft | −313 ft |
  | FL250、差 1.0 inHg | −163 ft | −251 ft |
  | 18,000 ft、差 1.0 inHg | +110 ft | +172 ft |
  | FL350、差 0.5 inHg | −112 ft | −153 ft |

  - ふつうの運用（遷移高度で片方が先に STD、差 0.9 inHg 以内、18,000 ft 以下）では 200 ft に届かない。
  - X-Plane の則は記録からは決められなかった。s243 の 2 回（RJAA、29.92 → 30.92 の 1.9 秒後に +895 ft）は高度計が追いつく途中で、3 つの則（+905・+911・+999）を分けられない。
- **根拠**：ALT DISAGREE は未補正の高度の差が 200 ft 超で 5 秒：FCOM p.1197 (10.50.1)。式そのものは資料なし（X-Plane との換算）。
- **重さ**：軽い。**確かさ**：未確認（X-Plane の則しだい。同じ則なら指摘なし）。
- **シナリオの案**：
  - 地上：RJAA で機長の気圧を 30.92 にして 15 秒待ち、`altitude_ft_pilot` を読む。+905 なら同じ則、+911 か +1000 なら足し算。
  - 空中：FL350 で副操縦士の気圧だけ 30.92 にして 10 秒。`altitude_ft_copilot − altitude_ft_pilot` が 688 ± 10 ft で、`laminar/B747/CAS/caution_status[1]` が 0 なら合格。差が 911〜1000 ft なら ALT DISAGREE が出るはず。
- **直す案**：X-Plane が足し算の則なら、`baro_alt`・`pressure_alt` を足し算の形にする。未補正の高度に `sim/flightmodel2/position/pressure_altitude` を使えるなら、そちらが簡単。

#### NAV-5　TCAS の RA の表示が、自機の昇降率を機長の静圧系だけから取る（型 I：機長側だけ）

- **場所**：`plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.tcas.lua:24`・`:130`、`B747.34.tcas_model.lua:309-313`
- **何が起きるか**：
  - `sim/flightmodel/position/vh_ind_fpm` は機長の静圧孔が詰まると 0 になる（s318 の 2026-11-21 の回で、2,500 fpm の降下中に 2.4E-44）。
  - その状態（故障の窓の STATIC CAPT BLOCKED）で RA が出ると、両席の PFD の赤いピッチ領域が昇降率 0 を基準に置かれ、V/S のポインタが赤になる。
  - 副操縦士の PFD（ADC R は正常）も同じ誤りになる。
- **どう確かめたか**：`tcas_own_vs.lua`（モデル。TAS 480 kt）。出力は `tcas_own_vs_out.txt`。

  | RA と実際の V/S | 正しい昇降率を渡す | 0 を渡す |
  |---|---|---|
  | DESCEND（−1,500 より上が赤）、実際 −2,500 fpm | ピッチの境 +1.18°、赤でない | −1.77°、赤 |
  | CLIMB（+1,500 より下が赤）、実際 +2,000 fpm | −0.59°、赤でない | +1.77°、赤 |

- **根拠**：V/S が赤い範囲の間ポインタが赤、は FCOM p.1537（コードの注釈から。このページは開いていない）。ピッチ領域の出し方は「RA のデータの関数」とだけ：ATA34_2 p.46（34-45 Page 44）。TCAS の昇降率の源は資料なし（p.17 には RA・IRU の方位・GPWC・脚・空地だけ）。
- **重さ**：軽い（静圧の故障と RA が重なったときだけ）。**確かさ**：確か（値の出どころ）。
- **シナリオの案**：既存の TCAS の RA のシナリオ（`traffic` の手順）を、−2,000 fpm の降下中に `sim/operation/failures/rel_static` を 6 にしてから RA を起こす形で流す。`laminar/B747/tcas/pfd/vs_red` と `pitch_hi` を、故障なしの回と比べる。
- **直す案**：自機の昇降率を IRS の慣性の昇降率（AFDS が 65b5caf7 から使っているもの）にする。

### 段 1〜3 の直しを見た結果

- **58224644（キットの `remove` の `path_dref`）**：指摘 NAV-2。道筋の守り（`GetFullPath` のあと simbrief フォルダーの内かを見る）と鍵の定義は正しい。
- **ほかの系統が変えた dataref を、範囲のモジュールが古い意味で読んでいないか**：
  - 安定板の units（dfbbf7d4）：AI・FDR・manipulators・照明は、安定板の dataref を読まない。問題なし。
  - 逆推力のレバー（b134fbf1・4d92ef7a）：manipulators の 3D のレバーの動き（`B747.01.xt.manipulators.lua:2346-2365`）は、前と同じ X-Plane の `throttle_jet_rev_ratio` を追うだけ。問題なし。同じ型（X-Plane のスロットルで推力を決める）が safety と ACP に残っていた：指摘 NAV-1。
  - STATUS のラッチ（5012a8fb）：ILS アンテナの STATUS（148〜153）はラッチの組に入っておらず、前のまま。問題なし。
  - GPWS のコール（b90a9ba0）：変わったのは `gpws_model` だけ。simconfig の GPWS の設定の添字は同じ。問題なし。
  - % MAC（0dba427b）：範囲のモジュールは CG を読まない。問題なし。

### 見て問題が無かった所

- **TCAS の抑止**：RA 1,000 ft、DESCEND 1,100 ft、INCREASE DESCENT 1,500 ft、TA の声 500 ft、>TCAS OFF 400 ft。FCOM p.1593 (15.20.47)・p.1600-1601 (15.20.54-55) を開いて確かめた。単位の換算（m → ft・NM、m/s → kt）も合っている。
- **WXR**：WX+T は 40 nm を超えると WX になる、両方の TFR で TEST：FCOM p.1223-1224 (11.10.17-18) どおり。
- **ADC**：ALT DISAGREE（未補正、200 ft 超、5 秒）と IAS DISAGREE（5 kt 以上、5 秒）：FCOM p.1197-1198 (10.50.1-2)。高度の警報（900・300 ft、抑止の条件）：p.1559 (15.20.13)。
- **IRS・GPS・ILS アンテナ**：故障の窓で故障を消したあとの戻り方は筋が通っている（IRU は空中では整列しない、ADC はすぐ、GPS は 75 秒）。`toDMS` は 10 分の 1 分で丸めてから度と分に分けるので「60.0 分」にならない。
- **無線**：kHz の持ち方、MHz・kHz のノブの折り返し、パネルの LED（kHz ÷ 1000、6 桁 3 小数）。VHF C の 25 kHz 刻みは既知の簡略化。
- **照明**：landing の減光、turnoff と taxi の地上だけ、サインの AUTO の条件（FCOM p.502 (1.40.4)）。570 の NO SMOKING 不作動は貨物機の項目で、今の扱い（freighter の旗）と矛盾しない。
- **manipulators**：位置を足し引きする所は min・max で挟んである。挟んでいないのは数える dataref だけ。RTP のノブは 3D が 1 単位 1° の回転（`Cockpit_Pedestal1.obj:39871`・`:39876`）で、止まりの無い回しノブ。
- **カスタム acf のパネル**：範囲の dataref を読む計器を `panel_keys.lua` で調べた（1,450 個）。TCAS の RA の 4 つは両端が平ら。端が開いているものは、数字・文字の 2 点の写しと高度テープの切り替えだけで、重なりの元は見つからなかった。
- **橋渡しの C**：`options.c`（使う値と保存する値の分け）、`simbrief_fetch.c`（ファイル名は英数字と `_-.` だけで、フォルダーの外へ出られない。.part から rename）、`failures_window.c` の状態・arm・REPAIR ALL。
- **回帰試験**（HEAD）：nav 16 本 766 件、com 4 本 113 件、lighting 3 本 287 件、fdr 1 本 14 件、safety 2 本 51 件、全部通る。

### 範囲の外で気づいたこと・小さいこと

- FDR の 30 秒ごとの記録：armed の roll の名前の表が 1 つずれている（5 を HDG SEL、6 を HDG HOLD。dataref は 5 ATT・6 HDG SEL・7 HDG HOLD）。armed に 5〜7 は来ないので害は無い。
- FDR：30 秒の記録の対地速度は m/s（`simDR_groundspeed`）、出来事の標本の `gs` は kt。`simDR_pressureAlt1` という名前の値は指示高度。
- FDR の「long frame」は地上の停止中にも多い（Saudia のリバリーの記録 60 件の多くが開始・移動の所）。
- 客室灯の自動（`B747.90.xt.lighting.lua:947-951`）の「15」は m/s（約 29 kt）。本家からの値で出典なし。
- IRS の位置の検査は経度の差をそのまま引くので、±180° をまたぐと 1° 以内でも外れる（`irs_model.lua:127-129`）。747 の空港では起きない。
- ACP のチャイムの抑止は、上昇か降下かを V/S の符号で分ける。進入の 400〜800 ft で一瞬でも V/S が 0 以上になると抑止が外れる。
- 故障の窓の THRUST REVERSER n（X-Plane の `rel_revers`）と、段 3 の P&W の逆推力の N1 の則（レバーで 87 %）の組み合わせ：展開しないリバーサーのエンジンが前進推力を出さないかは、エンジンの担当の範囲。未確認。
- 故障の窓で入れたモデルの故障と arm は、機体を読み直さない新しいフライトに残るはず。X-Plane では未確認。

### 見られなかった所

- **X-Plane を使う確かめ全部**（NAV-1・3・4・5 のシナリオ、X-Plane の高度計の則、新しいフライトで故障とチョークが残るか）。
- **manipulators**（2,387 行）：スロットルの動き、位置の足し引き、開始の手順だけ読んだ。個々のスイッチのハンドラーは読んでいない。
- **AI**（2,763 行）：auto board・auto start の各段は、作りと使う dataref・コマンドの一覧だけ。段ごとの中身は読んでいない。
- **照明の表示灯の表**（`B747_annunciators` の約 800 行）：前半だけ。**`xt.com`** のパネルのハンドラー、**`hitch_log.c`**、`failures_window.c` の描画と図も読んでいない。
- **3D の範囲**：INTERFACES.tsv に範囲の欄が無い。OBJ の key を全部当たることはしていない（RTP のノブだけ）。
- **変異の試験**は回していない。

