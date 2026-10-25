# 純正 acf とカスタム acf の差分（ACF_DIFF）

2026-10-23 調査。**どちらの acf も変更していない。** ここに書く差分は、もともと 2 つのファイルの間にあるもの。

## 1. 比べたファイル

| | ファイル | 形式 | Plane Maker の版（`acf/_file_writer_version`） | P 行の数 |
|---|---|---|---|---|
| 純正 | `747-400.acf`（本家 041c9ffa、git 管理） | I / 1200（XP12） | 123015 | 84,605 |
| カスタム | `747-400_custom.acf`（未追跡、2026-10-22 23:27 に配置） | I / 1200（XP12） | 123300 | 74,316 |

- カスタム acf がどの純正 acf から作られたかは、行の差分の数で見た。`747-400.acf` が 32,455 行と最も少なく、`747-400LCF.acf` は 34,428 行、`747-400_XP11.acf` は 155,625 行。
- そこで比較用の「純正 acf」は **`747-400.acf`** とする。前回の報告で `747-400_XP11.acf` を純正 acf と呼んだのは誤りだった。
- 方法：`P <キー> <値>` の行をキーで突き合わせた（同じキーで値が違う 10,724、カスタムだけにある 355、純正だけにある 10,644）。末尾に埋め込まれたパネル計器の定義は別に比べた。

## 2. 同じもの（システムの土台は共通）

- **重量・重心**：空虚重量 404,600 lb、最大 850,000 lb、燃料 381,552 lb。重心位置と前後限界も同じ。
- **燃料タンク**：9 個。容量比（0.300 / 0.078 / 0.220 / 0.220 / 0.078 / 0.023 / 0.023 / 0.058 / 0）も同じ。違いは役割だけ（§3.6）。
- **電源**：バッテリー、バス（`acf/_bus_*`）、発電機、`acf/_esys*` は全項目が同じ。
- **油圧**：`acf/_hyd*` は同じ（舵面ごとの系統割り当ては違う。§3.5）。
- **エンジン**：4 発、`JET_2SPOOL`、推力上限 63,000 lbf は同じ。違いは位置・燃費・定格（§3.2）。
- **速度**：Vso 110、Vs 216、Vfe 280 / 180、Vle 270 kt。
- **パネル計器**（acf 末尾の generic instrument 2,850 個）：ほぼ同じ。違うのは機長 ND の VOR L/R の針 2 個の参照先で、純正は `sim/cockpit2/radios/indicators/nav_relative_bearing_deg[2]`・`[3]`、カスタムは `[3]`・`[4]`。コードは VOR L/R を nav の 2・3 番に合わせているので、正しいのは純正、カスタムが 1 つずれている（notes/ATA-31.md）。

## 3. 違うもの

### 3.1 参照しているオブジェクト（見た目。変更対象外）

- 純正：41 スロット（40 種類）。カスタム：68 スロット（68 種類）。カスタムが参照するファイルはすべて実在する（大半は 2026-10-22 に入ったローカル一式。ARCHITECTURE.md §0）。
- カスタムだけにあるもの：
  - コクピット：`Cockpit_Flashboi`、`Cockpit_Glass_2`、`Cockpit_Headset`、`Cockpit_Main_2/_3`、`Cockpit_acu`〜`_acu_5`、`Cockpit_bolts`、`Cockpit_circuit_breaker`・`_breraker_2`、`Cockpit_escape`、`Cockpit_floor`、`Cockpit_sticker`、`cockpit_glareshield_panel`
  - 外部：`Exterior_Detail`・`_detail_2`、`Exterior_Fuselage2/3`、`Exterior_Glass2`、`Exterior_VStab`、`Exterior_Windshield`、`Exterior_Wings1`、`Exterior_Wiper`、`Exterior_cargo`、`Landing_lights`
  - エンジン：`NEW_engines/` の GE と PW のエンジン・パイロン・ステッカー
- 純正だけにあるもの：`747_cabin/Cabin_Main`・`Cabin_Seats`、`Cockpit_Pilots`、`Exterior_Engine_F`・`_F_GE`、`Exterior_Engines`・`_Engines_GE`・`_EnginesR_GE`、`Exterior_Wings`、`Exterior_WndwFrm`、`chocks`
- エンジンの外観は `laminar/B747/engines/type` で切り替わる。カスタムの `NEW_engines` は PW（type 0）と GE（type 1）だけで、**RR（type 2）を選ぶとエンジンが表示されない**。

### 3.2 エンジン（システムに関係）

| キー | カスタム | 純正 | メモ |
|---|---|---|---|
| `_engn/0,3/_part_y`・`_part_z`（外側） | -7.0 / 123.70 | -4.0 / 125.80 | 外側エンジンは前へ 2.1 ft、下へ 3 ft。`_blad`、ナセルの body 21・24 も同じだけ動いている |
| `_engn/1,2/_part_y`・`_part_z`（内側） | -11.2 / 96.48 | -10.2 / 102.88 | 内側エンジンは前へ 6.4 ft、下へ 1 ft。body 22・23 も同じ |
| `acf/_jet_SFC_takeoff` / `_climb` / `_locrz` / `_hicrz` | 0.323 / 0.323 / 0.313 / 0.571（2026-10-23 に純正と同じにした。前は 0.55 / 0.25 / 0.25 / 0.38） | 0.323 / 0.323 / 0.313 / 0.571 | 燃費。前のカスタムの値では巡航の燃料流量が約 25 % 少なかった（§5） |
| `acf/_n1_rated_thrust` | 95 | 100 | |
| `acf/_fadec_parameter` | 1 | 0 | |
| `acf/_inlet_max_KEAS` / `_face_jet` / `_exhaust_rat` | 950 / 37 / 0.3 | 750 / 47 / 0.5 | |

### 3.3 X-Plane の autopilot・保護機能の設定（システムに関係）

| キー | カスタム | 純正 |
|---|---|---|
| `acf/_fdir_needed_to_engage_servo` | 1 | 0 |
| `acf/_alt_always_armed` | 1 | 0 |
| `acf/_load_alt_presel_on_alt_hit`・`_load_presel_on_asi_hit`・`_load_presel_on_vvi_hit` | 1 | 0 |
| `acf/_vvi_but_adjusts_pitch` | 1 | 0 |
| `acf/_integrated_approach_navigation` | 1 | 0 |
| `acf/_auto_ptch_axis_defaults_free`・`_auto_roll_axis_defaults_free` | 1 | 0 |
| `acf/_ott_*`（X-Plane の AP / A/T の応答調整、16 項目） | 例：`_ott_the_deg_off_for_full_def` 5、`_ott_flare_begin` 10 / `_end` 3 | 例：90、15 / 5 |
| `acf/_flap_extend_protect`・`acf/_gear_extend_protect` | 1 | 0 |

- AFDS は X-Plane の autopilot の上に乗っている（ARCHITECTURE.md §3）。そのため、ここが違うと **2 つの acf で AFDS の動きが変わりうる**。

### 3.4 操縦系統・脚

| キー | カスタム | 純正 | メモ |
|---|---|---|---|
| `_gear/0/_steerdeg_lospeed` / `_hispeed` | 75 / 35 | 70 / 7 | 前輪ステアリングの角度。純正は tiller 70°、ペダル 7° の値（資料で要確認） |
| `_gear/0〜4` の位置、タイヤ径・幅、strut | 違う | — | 脚の位置は見た目（変更対象外）。タイヤと strut は物理 |
| `acf/_ailn1_v1`・`_v2` / `acf/_ailn2_v1`・`_v2` | 900・900 / 500・600 | 0・0 / 200・250 | X-Plane のエルロンの速度によるロックアウト |
| `acf/_ailn1_rat2` | 0.8 | 1.0 | |
| `acf/_ailn_def_time` / `_elev_def_time` | 0.35 / 0.2 s | 0.5 / 0.5 s | 舵面の動く速さ |
| `acf/_ailn_trim_time` / `_rudd_trim_time` / `_speedbrake_ext_time` | 12 / 13 / 1.5 s | 10 / 10 / 1.0 s | |
| `acf/_hdng_` / `_ptch_` / `_roll_max_full_def_KIAS` | 180 / 500 / 500 | 189 / 200 / 250 | 全舵角を使える速度 |
| `acf/_frc_*`（力のフィードバック、7 項目） | 値あり | 0 | ジョイスティックの力の帰還。システム外 |
| `acf/_cyclic_*_trim_rat`、`acf/_rrpm_trim_time` | 値あり | 0 | ヘリコプター用の項目 |

### 3.5 空力（翼・胴体。カスタムで変えてよい分類）

- **翼**（`_wing`）：
  - 違う 10,724 項目の大半は、Plane Maker が計算する形状点（`_geo_xyz`、`_chord_for_RIB`）。手で入れる値の違いは 103 項目。
  - 主翼の上反角：カスタム 7.1° / 7.6°、純正 8.1° / 12.6°。
  - 垂直尾翼：wing 11 の翼弦・位置・長さが違う。純正にだけ、見えない垂直翼面の wing 10 がある。
  - ウイングレット（wing 18・19）：上反角 65° と 61°、翼弦、位置、後退角が違う。
  - 小さな翼面（wing 12〜16）、パイロン（wing 32〜35）の位置と寸法も違う。
- **舵面の油圧系統の割り当て**（`_ailn1_hyd0123`、`_spoi1/2_hyd0123`、`_sbrk1_hyd0123`、`_rudd1/2_hyd0123`）：カスタムは値があり（1・2・5・6）、純正はすべて 0。X-Plane の油圧モデルがカスタムでだけ効いている可能性がある（§4）。
- **胴体**（`_body`）：どちらも全部「見えない」。カスタムには body 4・5・8・9・13・17 が無い（抵抗の計算が変わる）。body 10 の位置と、ナセルの 21〜24 も違う。
- `_sbrk`（スピードブレーキの形状点）にも違いがある。
- 計算値（`acf/_h_eqlbm`、`acf/_the_eqlbm`、`acf/_average_mac_acf`）も違う。

### 3.6 燃料・その他

| キー | カスタム | 純正 | メモ |
|---|---|---|---|
| `acf/_tank_role/7` | 0 | 1 | タンク 7（容量比 0.058、約 22,000 lb）。容量からみて stabilizer tank と推定 |
| `acf/_fixed_role/5`・`/6` | 0 | 1 | 固定重量の役割 |
| `acf/_pe_xyz/1`・`_pe_xyz_copilot/1` | 10.30 | 10.99 | 視点の高さ（見た目。変更対象外） |

## 4. システムとの食い違いの候補（GAP_ANALYSIS.md で扱う）

ここでは候補を挙げるだけにする。資料との照合と、コードが acf の値を使っているかの確認は GAP_ANALYSIS.md で行う。

1. 前輪ステアリング：カスタムはペダル 35°。ただし `override_wheel_steer` が使われているので、acf の値が効くかどうかを確認する。→ 4-2 段 4（2026-10-25）で、脚のモジュールが `override_wheel_steer` を常に入れて前輪と胴体脚を書くようにしたので、どちらの acf でも `_steerdeg_*` と胴体脚の 15° は効かない（acf は変えていない）。
2. `_fdir_needed_to_engage_servo` などの X-Plane AP 設定が acf で違い、AFDS の動きが acf によって変わる恐れ。
3. `_flap_extend_protect`・`_gear_extend_protect`：実機に無い保護。プラグインが動かすフラップと脚を X-Plane が止める恐れ。
4. 燃費（SFC）と `_n1_rated_thrust`・`_fadec_parameter`：燃料系統が `override_fuel_system` で X-Plane の燃料流量を使う場合、燃料の消費と FMC の予測がずれる。EEC の表が純正 acf の設定を前提に調整されているかも確認する。
5. タンク 7 の役割、舵面の油圧割り当て、エルロンのロックアウト（実機はフラップ位置で決まる）：自前のロジックと重ならないかを確認する。
6. 機長 ND の VOR L/R の針の index（カスタムが誤り。直すにはカスタム acf のパネル変更が要り、承認が必要）。
7. RR を選んだときに外部モデルのエンジンが出ない（カスタム acf）。

## 5. 作り直しの中でカスタム acf に入れた変更（2026-10-23 承認：PLAN.md §3）

パネル計器と、カスタム acf で変えてよい分類（重量・エンジン・空力・システム）の値だけを変える。純正 acf は変えない。変更前の acf は `D:\747-400-local-assets\acf_backup\` と git の履歴にある。新しい画像（2026-10-23 夕方、違和感のない範囲で作ってよいと利用者の答え）は `docs/overhaul/tools/make_synoptic_images.ps1` で純正の絵から作り、新しいファイル名で置く。純正 acf が使う画像は変えない。

| 日付・系統 | 項目 | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-23・燃料（FUEL-05） | エンジンの燃費 `acf/_jet_SFC_takeoff`・`_climb`・`_locrz`・`_hicrz` | 0.550000012・0.250000000・0.250000000・0.379999995 | 0.323000014・0.323000014・0.312999994・0.570999980（純正 acf と同じ） | 巡航の測定（`s07_cruise_ff`、FL350、269 t、ISA −1 ℃）：前のカスタムは Mach 0.791 で 1 発 1,612 kg/h、純正は Mach 0.756 で 2,167 kg/h、変更後のカスタムは Mach 0.788 で 2,134 kg/h。FCOM PI.11.2（PW4056、LRC）は 260 t・Mach .842 で 2,211、280 t・.854 で 2,378 kg/h。前の値は約 25 % 少なかった。離陸と上昇の値は資料と比べていない（エンジン 2-3 で上昇の燃料の表 PI.11 と比べる）。外観は変わらない（chase 視点で確認） |

パネル計器の変更：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-23・警報（WARN-09） | 主 EICAS のページ番号（`GROUP Page #`） | `SHOW_GREATER 2.000000 laminar/B747/CAS/num_msg_pages`（3 ページ以上でだけ PG） | `SHOW_GREATER 1.000000 …`（2 ページ目から PG） | FCOM p.1548 |
| 同 | 主 EICAS のメッセージ（warning・caution・advisory・memo の各グループ） | 1・2 ページ（`gen_<level>_msg_000`〜`021`）だけ | 3〜10 ページのグループを追加（2 ページ目の写し。`SHOW_EQUAL p laminar/B747/CAS/msg_page`、枠 `022`〜`109`）。4,320 行の追加 | 警報モデルは 10 ページまで書く（ARCHITECTURE.md §4.3） |
| 2026-10-23・空圧（PNEU-10） | 主 EICAS のダクト圧（`GROUP Duct Pressure`） | 琥珀 `SHOW_LESS 11.000000`、白 `SHOW_GREATER 11.010000`。右の白の数字が `duct_pressure_L` で出し入れ | 琥珀・白とも 11.5 で切り替え（数字は整数に丸めて出るので、12 以上が白・11 以下が琥珀になる）。右の白は `duct_pressure_R` で | FCOM p.585 |
| 同 | ECS synoptic のダクト圧 | 琥珀・白とも 12.000000 で切り替え（12.0 ちょうどでは出ない） | 11.5 で切り替え | FCOM p.578 |
| 2026-10-23・警報（WARN-17） | STATUS ページ（`GROUP STAT Synoptic` の中に `GROUP Status Messages` を追加） | メッセージの行もページ番号も無い（油圧・APU・酸素・バッテリーの値と舵面の図だけ） | 1〜10 ページのグループ（`SHOW_EQUAL p laminar/B747/STAT/msg_page`）に 11 行ずつの文字（`TXT.2.28.white`、x 1570、y 97 から 24 ずつ下、`CAS/gen_status_msg_NNN`）。2 ページ以上で PG とページ番号（`SHOW_GREATER 1.000000 laminar/B747/STAT/num_msg_pages`）。1,380 行ほどの追加 | FCOM p.1527-1528、LH24 p.65（配置） |
| 同 | 主 EICAS の `GROUP CAS Messages` | STATUS cue が無い | cyan の "STATUS"（`TXT.8.27.blue`、`CAS/status_cue_text`、`SHOW_EQUAL 1.000000 laminar/B747/CAS/status_cue`、POS 1977, 826.5：メッセージ 11 行目の下、PG の行） | FCOM p.1545、p.1549 |
| 2026-10-23・油圧（HYD-19） | HYD synoptic の demand pump（`GROUP dem indicator`） | AUTO（シアンの画像）は `dem_mode_n` = 1、OFF（白の画像）は `dem_mode_n` = 0（系統 4 は AUX（-1）で OFF、OFF（0）では何も出ない） | AUTO（シアンの画像）は `synoptic/dem[n-1]` = 3（AUTO で動いていない）。白の OFF の画像 4 個を外し、琥珀の gen_text "OFF"（`TXT.2.28.amber`、`synoptic/text_off`、`dem` = 4：セレクタ OFF、系統 4 の AUX）と "AUTO"（`text_auto`、`dem` = 2：AUTO で指令中に圧低）を丸の中心に。系統 4 の AUX の丸に白の OFF の画像（`synoptic/aux` = 0）。全体で約 130 行の追加 | ATA29_32 p.105-106、FCOM p.1486-1488 |
| 同 | HYD synoptic の EDP・SOV（`GROUP edp indication`） | SOV の開閉と EDP の OFF が同じ `valve_n`（供給遮断弁が開で ENGINE pump が ON のとき 1）で出し入れ | SOV の開は `synoptic/sov[n-1]` = 1、閉は = 0（火災スイッチ）。EDP OFF（琥珀の箱の画像）は `synoptic/edp[n-1]` = 4（ENGINE pump スイッチ OFF） | ATA29_32 p.105、FCOM p.1487、p.1490 |
| 2026-10-23・油圧（HYD-18） | HYD synoptic（`GROUP rsvr press` を追加） | RSVR PRESS の画像はあるが計器が無い | 各リザーバの右に RSVR PRESS の画像（`rsvr_press`、POS x = リザーバ + 58、y −72、`synoptic/rsvr_press[n-1]` = 1） | FCOM p.1488、p.1489、ATA29_32 p.38 |
| 2026-10-23・電源（ELEC-11 ほか） | ELEC synoptic の ISLN の枠（`isln1`〜`4`） | BUS TIE スイッチの位置（`button_switch/position[18]`〜`[21]` < 0.95）で出す | `electrical/breaker/btb[n-1]` = 0（BTB 開）で出す。自動で開いたときも出る | FCOM p.791 |
| 同 | ELEC synoptic の DRIVE の枠（`drive1_off`〜`4`） | エンジン滑油圧の `engines/EICAS2_oil_press_status[n-1]` > 0.1 で出す | `electrical/light/drive[n-1]` = 1（IDG の油圧低。P5 の DRIVE 灯と同じ条件）で出す | FCOM p.792、p.786 |
| 同 | STAT ページの MAIN BATT・APU BATT（`GROUP Main Batt`・`APU Batt`） | V-DC と A-DC は X-Plane のバッテリー（`battery_voltage_indicated_volts[0]`・`battery_amps[0]`）、APU の V-DC は `electrical/apu_volts`、A-DC は APU 発電機の電流（`generator_apu_amps`） | 電源モデルの `electrical/battery/volts[0]`・`[1]` と `battery/stat_amps[0]`・`[1]`（電流の符号なし） | FCOM p.793 |
| 2026-10-23・油圧（HYD-19 の残り、画像） | HYD synoptic の demand pump と AUX（`GROUP dem indicator`） | AUTO はシアンの文字の画像（`d_auto`）で丸は白のまま。OFF・AUTO の琥珀は gen_text（`TXT.2.28.amber`）で、AUTO は丸より広い。ON 琥珀・AUX の待機（シアン）・琥珀は出ない。AUX の OFF は文字だけの画像（`d_off`） | 丸ごと色を付けた画像に替えた（丸は中の表示と同じ色）：`syn_auto_cyan`（`dem` = 3）、`syn_auto_amber`（= 2）、`syn_off_amber`（= 4）、`syn_ring_amber`（= 1、ON 琥珀）、AUX は `syn_off_white`（`aux` = 0）、`syn_ring_cyan`（= 1）、`syn_ring_amber`（= 3）。丸は背景から切り出したので白の丸にぴったり重なる。POS は丸の中心（DEM 1419・1566・1712・1858、AUX 1995、y 80.5。前の `d_auto` は 1 px ずれていた）。gen_text の 8 個と `synoptic/text_off`・`text_auto` は外した | ATA29_32 p.105-106 |
| 同 | HYD synoptic の EDP（`GROUP edp indication`） | EDP OFF（`edp_off`）は POS y 140（箱より 1.5 px 上）、系統 3・4 は x も 1 px 右。ON 琥珀は出ない | `edp_off` の POS を箱に合わせた（1487.5・1634.5・1780.5・1926.5、y 138.5）。ON 琥珀（`edp` = 1）に琥珀の枠だけの画像 `syn_edp_amber`（中は空いていて流れ線が見える） | ATA29_32 p.105 |
| 同 | HYD synoptic の不作動項目（`hsys1`〜`hsys234`） | `pressure_n` < 2000 で各系統の絵（`fail1`〜`4`）、`pressure_13`・`23`・`24`・`234` で組の絵。組の絵の中身が負荷の組と合わない（`fail13` に 1+2 の項目、`fail24` に BRAKES、`fail234` は 3+4 の項目）。1+2 の絵は使われていない | 新しい絵（672 × 242、POS 1704, 327）に替えた：各系統の一覧 `inop1_ge`〜`inop4_pw`（`synoptic/inop[n-1]` = 1 は一覧、= 2 は THRUST REV つき（P&W））と、組 `inop12`・`inop13`・`inop23`・`inop24`・`inop34`・`inop124`（`synoptic/inop_set[k]` = 1）。組は負荷の割り当て（notes/ATA-29.md §2.4）から：1+2 L OUTBD AIL・L INBD ELEV、1+3 L INBD AIL・UPR RUDDER、2+3 ELEV FEEL・STAB TRIM、2+4 R INBD AIL・LWR RUDDER、3+4 R OUTBD AIL・R INBD ELEV、1+2+4 BRAKES。4 系統すべてで重ならない配置で、線が交わる 2 か所（1+3 と 2+4）は下の線に切れ目を入れた。文字は元の絵の字の帯（`text_failures.png`）から同じ間隔で描いた | FCOM p.1490 (13.20.2)、p.1487 (13.10.5)、p.1491 |
| 2026-10-23・電源（画像） | ELEC synoptic の UTILITY・GALLEY（`ubus1_off`〜`ubus4_on`） | UTILITY と GALLEY が 1 枚の画像（`busgreenl` など）で、色は utility bus だけで決まる（`utilityleft1` など）。バス 4 は ON と OFF で y が 2 px 違う | 母線ごとに `utility_l/r_green/amber` と `galley_l/r_green/amber` の 2 枚に分けた。`electrical/bus/utility[n-1]`・`bus/galley[n-1]` が 0.5 より大きければ緑、小さければ琥珀。GALLEY には母線までの自分の線を描き足した（FCOM の図のように UTILITY の線の内側）。POS は前と同じ（バス 4 は y 110.5 にそろえた） | FCOM p.790 (6.10.12) |
| 同（ELEC-16） | STAT ページの背景と CHG/DIS（`GROUP STAT Synoptic`・`Main Batt`・`APU Batt`） | 背景に固定のシアンの "DIS" が描いてあり、電流に関係なく出ている。APU BATT には無い | 背景を DIS を消した `background_nodis` に替えた。白の `bat_dis`・`bat_chg`（POS 1855, 181 と 1855, 135）を `electrical/battery/amps[0]`・`[1]`（+ 放電、− 充電）が 0.5 A より大きいとき DIS、−0.5 A より小さいとき CHG で出す（A-DC が 0 と出る間は空白） | FCOM p.793 (6.10.15) |
| 2026-10-23・エンジン（ENG-20） | 主 EICAS の EGT（P&W の `GROUP EGT Tape` と数字・枠、GE の `GROUP EGT Tape GE` と数字・枠） | P&W：赤は `SHOW_GREATER 654.000000 laminar/B747/engines/display_EGT[n]`、琥珀・白は `EGT/amber_on[n]`・`white_on[n]`。GE：赤 `SHOW_GREATER 960.000000 laminar/B747/engines/display_GE_EGT[n]`、琥珀 `SHOW_LESS 960.000000 …` と `SHOW_GREATER 925.000000 …`、白 `SHOW_LESS 925.000000 …`（TO/GA の抑止なし。始動中の赤も無い） | 赤・琥珀・白とも `SHOW_EQUAL 1.000000 laminar/B747/engines/EGT/red_on[n]`・`amber_on[n]`・`white_on[n]`（コードが型式ごとの限界、始動限界、TO/GA の後の琥珀の抑止で決める。GE の琥珀は 2 行の条件が 1 行になった） | FCOM p.837-838、p.872；ATA70_80 p.395 |
| 同 | EGT の始動限界の印（P&W と GE の `GROUP Start Limit Markers`） | `SHOW_LESS 55.000000 sim/cockpit2/engine/indicators/N2_percent[n]`（X-Plane の N2 が 55 % 未満で出す） | `SHOW_EQUAL 1.000000 laminar/B747/engines/EGT/start_limit_on[n]`（FUEL CONTROL が CUTOFF か、始動の途中。始動がアイドルで落ち着くまで） | FCOM p.838、p.879；ATA70_80 p.356-357 |
| 2026-10-24・エンジン（ENG-21） | 主 EICAS の N1（P&W・RR の `GROUP N1 Tape`・`N1 LED`、GE の `N1 Tape GE`・`N1 LED GE`）の帯・数字・枠 | 赤は `SHOW_GREATER 111.410004 laminar/B747/engines/display_N1[n]`（GE は 117.5）、P&W の枠は X-Plane の `sim/cockpit2/engine/indicators/N1_percent[n]` > 111.41 | 帯と数字は `SHOW_EQUAL 1.000000`（白は `0.000000`）`laminar/B747/engines/N1/red_on[n]`、枠は `N1/box_red[n]`（超過の後も赤のまま、CANC・RCL） | FCOM p.833-836、p.873 |
| 同 | 主 EICAS の EPR（`GROUP EPR Tapes PW`・`EPR Tapes RR`・`EPR LED`） | 帯・数字・枠とも `display_EPR[n]` > 1.9 で赤 | 帯は `EPR/red_on[n]`（最大 EPR で赤）。数字と枠は白のまま（赤の条件は `SHOW_GREATER 1.000000 EPR/red_on[n]` で出ない、白の条件 `SHOW_LESS 1.900000` は外した） | FCOM p.833-834、p.873 |
| 同 | 主 EICAS の EGT の枠（P&W の `GROUP EGT LED`、GE の `EGT LED GE`） | 赤の枠は GE が `EGT/red_on[n]`、P&W が X-Plane の EGT（`EGT_deg_C[n]` > 654。表示とは尺度が違い、表示が赤のときに枠が消えていた）。琥珀・白の枠は `amber_on`・`white_on` だけ | 赤の枠は `EGT/box_red[n]`。琥珀・白の枠に `SHOW_EQUAL 0.000000 EGT/box_red[n]` を足した（4 基 × P&W 2 個・GE 2 個） | FCOM p.873、ATA70_80 p.356 |
| 同 | 下の EICAS の N2・N3（`GROUP N2`・`N2 GE`・`N2 N3 RR`）の帯・数字・枠 | `display_N2[n]` > 111.4（GE 112.5、RR 109.5）。RR の N3 は帯が 101.5、数字と枠が 111.4 | 帯と数字は `N2/red_on[n]`・`N3/red_on[n]`、枠は `N2/box_red[n]`・`N3/box_red[n]` | FCOM p.843-844、p.873、ATA70_80 p.345 |

上の 4 行は `docs/overhaul/tools/panel_limit_flags.lua`（変更した条件を全部表示する）で書き換えた。192 か所。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261024_before_limit_flags`。
| 2026-10-24・エンジン（ENG-25） | 下の EICAS の油圧の数字（`GROUP Oil Pressure` の `LED`） | 赤は `SHOW_LESS 10.000000 [n]` かつ `EICAS2_oil_press_status[n]` = 1（赤線と 10 psi の間では数字が消えた）。白は status = 0 かつ `SHOW_GREATER 9.990000 [n]` | 赤は status = 1 だけ。白は status = 0 かつ `SHOW_EQUAL 0.000000 laminar/B747/engines/oil_press_amber[n]`。琥珀の数字（`gen_LED Engine n Amber`、`LED_3.26B.xx###0.amber`、status = 0 かつ amber = 1）を足した | FCOM p.846-847 |
| 同 | 下の EICAS の油圧の針（`GROUP Oil Pressure` の `Tape` の `Pointer > Normal`） | 白の針は status = 0 だけ | 白の針に `SHOW_EQUAL 0.000000 oil_press_amber[n]`、琥珀の針（`ptr_right_amber`・`ptr_left_amber`）を足した | FCOM p.846-847 |
| 同（ENG-26） | 下の EICAS の油温の数字（`GROUP Oil Temp` の `LED > Amber Hi`） | `SHOW_GREATER 150.009995`（150〜160 ℃ で白の数字と重なった） | `SHOW_GREATER 160.009995` | FCOM p.847-848、ATA70_80 p.524 |
| 同（ENG-27） | 下の EICAS の油量の数字（`GROUP Oil Qty` の `LED`） | 白だけ（条件なし） | 白に `SHOW_EQUAL 0.000000 oil_qty_magenta[n]`、マゼンタの数字（`LED_3.26B.xx###0.magenta`、`oil_qty_magenta[n]` = 1）を足した | FCOM p.849、p.890 |
| 同（ENG-29） | 下の EICAS の振動の音源（`GROUP VIB` の `Source`） | BB の絵（`vib_BB_label`）だけ、`vibration[n]` > 0.01 で出す | BB は `SHOW_EQUAL 0.000000 vib_source[n]` を足した。N1・N2・FAN・LPT の絵（`vib_N1_label` など、新しい絵、`docs/overhaul/tools/make_vib_labels.ps1`）を `vib_source[n]` = 1〜4 で出す計器を足した | FCOM p.849-850 |

上の 5 行は `docs/overhaul/tools/panel_oil_vib.lua` で書き換えた（24 か所、計器を 28 個足した）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261024_before_oil_vib`。

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-24・空調（AIR-15） | 下の EICAS の ECS synoptic（`GROUP ECS Synoptic`）の上半分 | 背景にゾーン・MASTER・FWD/AFT・外流弁の枠があるだけ（数字・針・MAN/AUTO・HI FLOW・EXT AIR なし） | 7 ゾーンの target（左、小さい `LED_2.18R.xx###0.white`、`SHOW_EQUAL 1 air/temp/target_shown`）と actual（右、`LED_3.26B.xxx#00.white`）、MASTER、FWD・AFT（`air/temp/zone_target`・`zone_actual`・`master`・`cargo`、℃）、TEMP の後ろに °C（`temp_c`）。外流弁の針（回転グループ、`air/outflow_valve_left|right/pos` の −1〜+1 を −64°〜+64°：CL と OP の目盛り。新しい絵 `outflow_pointer`）、弁ごとの MAN（琥珀、新しい絵 `press_mode_man_amber`）か AUTO（`air/press/valve_man[i]`）。パックの番号の上の HI FLOW（`air/pack/high_flow[i]`）、パック 2 の線の上の EXT AIR（`air/ext_air`） | FCOM p.576-578；ATA21 p.29・p.250（℃）、p.420（MAN は琥珀） |
| 同 | パックの OFF・A・B（`gen_rotary pack n off`・`A`・`B`） | 選択器の位置：OFF は 0、A は 1 < 値 < 2（NORM でも A でも出なかった）、B は 3 | OFF は弁が閉（`SHOW_LESS 0.5 air/pack/valve_pos[i]`）、A・B は弁が開で使用中の PTC（`air/pack/ptc[i]` が 1・2） | FCOM p.578 |
| 同（PNEU-11） | エンジンと APU からの流れ（`gen_rotary eng n`・`apu`） | エンジンの抽気圧が 11 psi 超（ENGINE BLEED OFF で弁が閉でも出た）、APU は中央ダクトの圧 | エンジンの抽気弁が開（`air/engineN/bleed_valve_pos` > 0.5）、APU 弁が開（`air/apu/bleed_valve_pos` > 0.5） | FCOM p.576（流れは弁・スイッチ・パックの状態から作る） |

上の 3 行は `docs/overhaul/tools/panel_ecs.lua` で書き換えた（33 か所。計器を 26 個と、針の回転グループを 2 つ足した）。新しい絵は `docs/overhaul/tools/make_ecs_images.ps1`。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261024_before_ecs_synoptic`。LED の `LED_ROWS` はフォントの書式に合わせる（`xxx#00` は 3、`xx###0` は 4。合わないと次の字の一部が数字に重なる）。外から見た写真で機体の見た目が変わらないことを確かめた（`s17` の後）。

| 日付・系統 | 項目 | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-24・酸素（OXY-03） | STAT ページの OXY PR（`GROUP Oxygen` の `gen_LED Pressure: Crew`・`Pressure: Psgr`） | `DATAREF [0]`（空で何も出ない）、`DIGITS 3`（1850 が出せない） | `DATAREF laminar/B747/oxygen/crew_press_psi`・`pass_press_psi`（酸素のモジュールの圧）、`DIGITS 4` | FCOM p.455 (1.30.21)、ATA30_32_35_36 p.338・p.374 |

変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261024_before_oxygen`。X-Plane のスクリーンショットで、CRW と PASS の 4 桁がほかの値と同じ右端にそろって出ることを確かめた（`s20_oxygen`）。純正 acf は変えていないので、STAT ページの酸素圧は出ないまま。外から見た写真で機体の見た目が変わらないことを確かめた（RJAA 34L、追従視点）。

承認の一覧（PLAN.md §3）に無いパネルの変更（2026-10-24、利用者の承認「2件とも入れて」）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-24・空調（AIR-18） | 主 EICAS の data block の客室高度の赤（`GROUP Pressure` の `GROUP Cabin Alt` の `gen_LED LED Red`、10,000 ft 以上で出る） | `POS 1568 491`、`LED_3.26B.xx###0.red`、`DIGITS 4`、`LED_ROWS 4`（先頭の桁が欠け、28,575 ft が「8575」） | `POS 1560 491`（1 桁ぶん左、右端は同じ）、`LED_3.26B.x####0.red`（新しい 5 桁のフォント）、`DIGITS 5`、`LED_ROWS 5`（下の LDG ALT と同じ 5 桁）。白（8,500 ft 未満）と琥珀（10,000 ft 未満）は 4 桁のまま | ATA21 p.451（赤は 10,000 ft 以上） |
| 同 | data block の LDG ALT（`GROUP Landing Alt`：`gen_LED LED` と `gen_rotary NEG Sign`） | 条件なし（数字）、`SHOW_LESS -0.01 landing_altitude`（負号） | どちらにも `SHOW_EQUAL 1.000000 laminar/B747/air/press/ldg_alt_shown` を足した（両 CPC 故障か両方 MAN で消える）。AUTO・MAN の字（`GROUP Mode Annun`）はそのまま | FCOM p.586 (2.10.34) |

上の 2 行は `docs/overhaul/tools/panel_data_block.lua` で書き換えた（6 か所）。赤の 5 桁のフォント（`cockpit_3d/generic/CRT Displays/LED/LED_3.26B.x####0.red-4.png` と透明の `.png`）は純正に無いので、`docs/overhaul/tools/make_led_fonts.ps1` で純正の 4 桁の赤のフォントから作った（字は純正のまま。行を 23 画素から 26 画素にして字の上に空きを足し、次の行の字の上端が数字の下ににじまないようにした）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261024_before_air18`。X-Plane のスクリーンショットで、赤の 5 桁が LDG ALT と同じ右端にそろい、LDG ALT の数字が両方 MAN と両 CPC 故障で消えることを確かめた（`s25_data_block`）。外から見た写真で機体の見た目が変わらないことを確かめた。純正 acf は変えていない。

脚（4-2 段 1、2026-10-25。GAP_ANALYSIS.md §4 の承認済みの「展開形の表示」）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・脚（GEAR-11） | 主 EICAS の脚の表示（`GROUP Gear`） | DOWN・斜線・UP の 3 つ（`gear_position/annun_status` 1・2・0） | 空の箱（全位置指示の故障、`annun_status` 3、`gear_annun_box`）を足した | FCOM p.1505 |
| 同 | 展開形（新しい `GROUP Gear Expanded`、`gear/EICAS1_display_status` 2） | なし | GEAR の字（1916, 739）と、脚ごとの箱（前脚 1916, 782、左胴体 1865, 695、右胴体 1967, 695、左翼 1843, 739、右翼 1989, 739）。箱は `gear_position/annun_gear[0]`〜`[4]`（前脚、左胴体、右胴体、左翼、右翼）で DN（緑）1、斜線（白）2、UP（白）0、琥珀の X 3。配置は FCOM の図を DOWN の箱の幅で縮め、胴体脚の箱がフラップの帯（上端 673）にかからないように上げた | FCOM p.1505–1506、ATA29_32 p.660 |

上の 2 行は `docs/overhaul/tools/panel_gear.lua` で書き換えた（計器を 22 個とグループを 1 つ足した）。新しい絵（`gear_box_dn`・`up`・`transit`・`x`、`gear_annun_box`）は `docs/overhaul/tools/make_gear_images.ps1` で純正の DOWN・UP・斜線の箱から字と縞を切り出して作った。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_gear_expanded`。

脚（4-2 段 5、2026-10-25。GAP_ANALYSIS.md §4 の承認済みの「synoptic のドアの箱、タイヤ圧の LED 3 個」）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・脚（GEAR-18、4-2 段 5） | GEAR synoptic のドアの箱（5 脚の CLOSED と斜線） | CLOSED は `SHOW_LESS 0.000000 sim/flightmodel2/gear/deploy_ratio[n]`、斜線は `SHOW_GREATER 0.010000 …deploy_ratio[n]`（X-Plane の脚 0〜4：前脚、右胴体、左胴体、右翼、左翼） | CLOSED は `SHOW_LESS 0.001000 laminar/B747/gear/door[m]`、斜線は `SHOW_GREATER 0.001000 …door[m]`（脚のモデルのドア：0 前脚、1 左胴体、2 右胴体、3 左翼、4 右翼。同じ箱が同じ脚を見る）。10 行 | FCOM p.1508 |
| 同 | GEAR synoptic のタイヤ圧（左胴体のタイヤ 7・8、右翼のタイヤ 16） | タイヤ 7（`tire_pressure[6]`）の琥珀（低）が `SHOW_LESS 100.000000 …tire_pressure[9]`。タイヤ 8（`[7]`）と 16（`[15]`）の白に表示条件が無い（琥珀と重なる） | 琥珀の条件を `[6]` に。白の 2 つに `SHOW_LESS 239.990005` と `SHOW_GREATER 100.010002`（ほかのタイヤと同じ）。3 か所（4 行の追加） | notes/ATA-32.md §6.5 |

上の 2 行は `docs/overhaul/tools/panel_gear_synoptic.lua` で書き換えた（15 の変更）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_gear_synoptic`。

脚の GEAR synoptic のブレーキ温度の色（4-2 段 5 の続き、2026-10-25。承認の一覧に無い変更で、利用者の承認「変えてよい」）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・脚（4-2 段 5） | GEAR synoptic のブレーキ温度の数字（ブレーキ 16 個の白と琥珀、前脚のグループの琥珀 1 個） | 白は `SHOW_LESS 484.000000 laminar/B747/gear/brake_temp[n]`、琥珀は `SHOW_GREATER 484.100006 …brake_temp[n]`（表示 5 になる 482 °C から 484 °C までは白） | 白は `SHOW_LESS 4.500000 laminar/B747/gear/brake_temp_ind[n]`、琥珀は `SHOW_GREATER 4.500000 …brake_temp_ind[n]`（表示 5 から琥珀） | ATA29_32 p.428（表示 5 で数字の色が変わる）、FCOM p.1521 |

上の行は `docs/overhaul/tools/panel_brake_temp.lua` で書き換えた（33 か所）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_brake_temp`。

航法センサー（5-1 段 1b、2026-10-25。GAP_ANALYSIS.md §4 の承認済みの DSP-02・04・12）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・エアデータ（NAV-01・05） | PFD の高度（テープ・現在高度・バグの群）と Mach（機長と副操縦士、外側と内側の 4 組） | `sim/cockpit2/gauges/indicators/altitude_ft_pilot`・`_copilot`（X-Plane の各側）、`sim/flightmodel/misc/machno`（真の Mach）。副操縦士の最初の高度テープの表示条件は機長の `altitude_ft_pilot` | `laminar/B747/airdata/alt_capt`・`alt_fo`（選んだ ADC、その席の気圧設定）、`mach_capt`・`mach_fo` | FCOM p.992（選んだ ADC の気圧高度）、ATA34_1 p.126–130 |
| 同（NAV-05、DSP-04） | PFD の速度表示（`GROUP Airspeed Display`）、高度テープの背景・`GROUP Tapes`・`Altitude Offset`・`Rolling Display` | 表示条件なし | `SHOW_EQUAL 1.000000 laminar/B747/airdata/valid_capt`（`valid_fo`）。新しい `GROUP CAPT AIR DATA FLAGS`（`FO …`）：速度テープと高度テープの中心に琥珀の SPD・ALT の旗（`Failure Flags/spdX`・`altX`）、`valid_*` が 0 のとき | FCOM p.1000 |
| 同（NAV-03、DSP-12） | PFD の現在高度の窓と選択高度 | なし | 現在高度の窓に白の強調の枠（`ALTrollingDigits/ALTcrntWndwHiW`、`alt_advise`）と琥珀の枠（`ALTcrntWndwHiA`、`alt_alert`）。2 つは新しい `GROUP Crnt Alt Boxes`（`valid_*` が 1）の中、選択高度に白の強調の枠（`Altimeter/SelAltBoxHiW`、`alt_advise`。高度テープの中心から上へ 268） | FCOM p.992、p.1559 |

上の 3 行は `docs/overhaul/tools/panel_pfd_airdata.lua` で書き換えた（各 PFD に 8 か所の挿入と、高度 54・Mach 2 の置き換え）。X-Plane は計器ごとに表示条件を 1 つ（1 つの dataref）しか見ないので、条件を重ねるところはグループに分けた（ARCHITECTURE.md §5）。旗と枠の絵は `docs/overhaul/tools/make_pfd_airdata_images.ps1` で作った（旗の字は純正の VERT の大きさと間隔に合わせ、Windows の Bahnschrift SemiBold SemiCondensed で描いた。枠は純正の現在高度の窓の 3 ピクセルの縁を外へ 3 ピクセル広げた形）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_pfd_airdata`。

航法センサー（5-1 段 4、2026-10-25。GAP_ANALYSIS.md §4 の承認済みの DSP-02・04・10）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・電波高度計（NAV-51・53） | PFD の RA の数字（`GROUP Radio Altitude`）と立ち上がる滑走路（`GROUP Rsng Rwy Offset`、機長と副操縦士、外側と内側の 4 組） | 表示条件 `SHOW_LESS 2500.000000 sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot`（副操縦士は `_copilot`）、滑走路の位置も X-Plane の RA | `SHOW_EQUAL 1.000000 laminar/B747/ra/capt/show`（`fo/show`：その席の RA が使えて 2,500 ft 以下）、滑走路の位置は `ra/capt/value`（`fo/value`） | ATA34_2 p.88–89、p.96 |
| 同（NAV-51、DSP-04） | RA 旗（新しい `GROUP CAPT RA FLAG`・`FO RA FLAG 2`、RA の数字のグループの後） | なし | 琥珀の RA 旗（`Failure Flags/raX`）を RA の数字の位置に、`ra/capt/flag`（`fo/flag`）が 1 のとき | ATA34_2 p.96 |
| 同（NAV-53、DSP-10） | 副操縦士の PFD の RA の数字と DH の警報 | `laminar/B747/efis/radio_altitude`、`dec_height/display_status`、`radio_alt/display_status`（機長の値） | `efis/radio_altitude_fo`、`dec_height/display_status_fo`、`radio_alt/display_status_fo` | FCOM p.981–982 |
| 同（NAV-54） | PFD の DH（`GROUP Decision Height`） | `SHOW_GREATER 0.000000 …radio_altimeter_bug_ft_pilot`（DH 0 で消える） | `SHOW_GREATER -0.500000`（0 ft は表示、0 未満で消える） | FCOM p.981 |
| 同（NAV-64） | PFD の PULL UP と WINDSHEAR | `SHOW_EQUAL 1.000000 sim/cockpit/warnings/annunciators/GPWS`、`sim/cockpit2/annunciators/windshear_warning` | `laminar/B747/gpws/pull_up`、`laminar/B747/gpws/windshear` | FCOM p.1531、ATA34_2 p.142 |

上の 5 行は `docs/overhaul/tools/panel_ra_gpws.lua` で書き換えた（22 の変更、各 PFD に RA 旗のグループ 1 つ）。条件が 2 行以上ある計器・グループの数は 371 のまま。RA 旗の絵は `docs/overhaul/tools/make_pfd_ra_images.ps1` で作った（純正の ATT 旗と同じ高さ 30・3 ピクセルの縁・字の大きさ、Windows の Bahnschrift SemiBold SemiCondensed）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_ra_gpws`。X-Plane のスクリーンショット（`s43_gpws`、`gpws_dive.ps1`）で、RA の数字が 2,500 ft 以下で出て RA 旗がその位置に出ること、DH の警報中も RA の数字が白で出ること、PULL UP が GPWS で出ることを確かめた。外から見た写真で機体の見た目が変わらないことを確かめた。純正 acf は変えていない。

航法センサー（5-1 段 5b、2026-10-25。GAP_ANALYSIS.md §4 の承認済みの DSP-18）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・TCAS（NAV-70、DSP-18） | 各 ND の `GROUP ND Text Center` の終わり | なし（TCAS の機影はアイコンの白い菱形 1 種、`nd/*/text/icon` の 22） | 新しい `GROUP ND TCAS0`〜`29`（アイコンと同じ回転・移動：`nd/capt/tcas/heading[n]`・`distance[n]`、`show[n]`）。中に記号（`tcas_symbols` 13 コマ、`tcas/sym[n]`）とデータタグ（`tcas/tag_dy[n]` で上下に動くグループの中の白・琥珀・赤の文字、`tcas/tag<n>`、`tag_color[n]` が 1・2・3）。副操縦士の ND は `fo` | FCOM p.1534、p.1152、ATA34_2 p.44 |
| 同（NAV-70、DSP-18） | 各 ND の `ND Text Center` の後（新しい `GROUP TCAS Messages`） | なし | 青の TA ONLY（`tcas_taonly`、`nd/capt/ta_only` が 1、TFC の上）。`map_center` で上へ動く `GROUP TCAS Alerts` の中に TRAFFIC と OFFSCALE（`tcas_traffic`・`tcas_offscale`、0 なし・1 琥珀・2 赤、`nd/capt/traffic`・`offscale`、右の中ほど） | FCOM p.1534–1535、p.1153、ATA34_2 p.44 |
| 同（NAV-78、DSP-18） | 各 ND の TCAS OFF（`TCAS X CAPT`・`TCAS X FO`）の後 | なし | 琥珀の TCAS FAIL（`tcas_fail`、`nd/capt/tcas_fail` が 1、TCAS OFF の文字の位置） | FCOM p.1153、p.1563 |
| 2026-10-25・TCAS の明るさ（DSP-18 の直し） | 上の TCAS のスロットの `LIGHT_RHEOSTAT` | 機長の ND の記号 30 は 2（PFD のつまみ。アイコンの写し）、副操縦士の ND のデータタグ 90 は 0（機長の ND のつまみ） | どちらもその ND のつまみ（機長 0、副操縦士 3：ほかの ND の要素と照明のモジュールと同じ）。120 行の値だけ | — |

上の 3 行（と明るさの直し）は `docs/overhaul/tools/panel_nd_tcas.lua` で足した（既存の行は変えていない。各 ND にスロット 30、メッセージのグループ 1、TCAS FAIL 1）。絵は `docs/overhaul/tools/make_nd_tcas_images.ps1`（記号は透明の地に、文字は純正の TFC の大きさ。色は純正の ND の琥珀・青、nd_icons の赤）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_nd_tcas`（明るさの直しの前は `…20261025_before_tag_rheostat`。直しも同じ変更前の acf から道具を流し直した）。

航法センサー（5-1 段 5d、2026-10-25。パネルの変更は全範囲で承認なしでよい：利用者、2026-10-25）：

| 日付・系統 | 場所（パネル） | 変更前 | 変更後 | 根拠 |
|---|---|---|---|---|
| 2026-10-25・TCAS の PFD の RA（NAV-71） | 各 PFD（機長と副操縦士、外側と内側の 4 組）の `GROUP Attitude Indicator` の `Bank Scale` の後 | なし（RA の値 `tcas/pfd/*` はあるが描かない） | 新しい `GROUP TCAS RA Pitch`（その PFD のロール `roll_AHARS_deg_pilot`・`_copilot` で姿勢と一緒に回る。中心は姿勢の POS）。中に赤枠の RA のピッチ領域 2 つの pointer（`Artificial Horizon/tcas_ra_up`・`tcas_ra_down`。`tcas/pfd/pitch_hi`・`pitch_lo` を 613 px / 90° で上下に、±232 px で止める。`hi_on`・`lo_on` が 1 のとき。CLIP で 464 px 四方に切る） | FCOM p.1536–1537、p.1562 |
| 同（NAV-71） | 各 PFD の `GROUP VSI Display` の `Sel VSI Ptr Mask` の後 | なし | 赤の RA の昇降率の範囲 2 つの pointer（`VSI/tcas_ra_vs_up`・`tcas_ra_vs_down`。目盛の刻みの列（幅 7 px、目盛の POS の 6.5 px 左）に、`tcas/pfd/vs_hi`・`vs_lo` を目盛の刻みの位置（0・500・1,000・1,500・2,000・4,000・6,000 fpm に 0・38.5・69・94.5・121・133.5・147 px）で。`hi_on`・`lo_on` が 1 のとき。CLIP で目盛の ±147 px に切る） | FCOM p.1536–1537 |
| 同（NAV-71） | 各 PFD の VS ポインタ（`gen_needle Needle`・`Needle 2`）の後 | 白だけ | 同じ形・同じ動きの赤のポインタ（`VSI/VSIspdPtrR`、`tcas/pfd/vs_red` が 1 のとき白の上に描く） | FCOM p.1537 |

上の 3 行は `docs/overhaul/tools/panel_pfd_tcas.lua` で足した（既存の行は変えていない。各 PFD に 128 行）。絵は `docs/overhaul/tools/make_pfd_tcas_images.ps1`（赤は純正の PULL UP・WINDSHEAR の 255, 0, 0。赤枠の形は FCOM p.1536 の図を純正のピッチ目盛（10° = 68 px）に縮め、線は 3 px。土台の透明の絵の大きさが切り抜きの四角）。変更前の acf は `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_pfd_tcas`。最初は赤枠をピッチ目盛の後に置いたが、純正の Bank Scale の絵（姿勢表示の上を覆う空色の帯）に上の方が隠れたので、Bank Scale の後に置き直した（同じ変更前の acf から道具を流し直した）。X-Plane のスクリーンショット（`s48_pfd_ra`）で、上下の赤枠・赤の範囲・VS ポインタの赤と白、副操縦士の PFD を確かめ、窓のマスクを外した試験用の acf で旋回中の回転と切り抜きを確かめた。外から見た写真で機体の見た目が変わらないことを確かめた。純正 acf は変えていない。
