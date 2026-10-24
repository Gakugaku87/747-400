# コード構成（ARCHITECTURE）

対象は `overhaul` ブランチの出発点＝本家 mSparks43/747-400 master `041c9ffa`（2026-09-10、「Release XP12.4.3-2026/09/10 milestone」の直後）。2026-10-23 に調べた。行数はコメント込み。

## 0. 前提

- 機体は Sparky744（本家 README：CC BY-NC 4.0）。この PC の X-Plane は 12.4.4-b5（Log.txt、2026-10-22）。
- フォルダの acf：
  - `747-400.acf`：XP12 形式の純正 acf。**比較用。変更しない**
  - `747-400_XP11.acf`：XP11 形式
  - `747-400LCF.acf`：Dreamlifter
  - `747-400_custom.acf`：利用者のカスタム acf（未追跡。開発と試験の基準）
  - 違いは [ACF_DIFF.md](ACF_DIFF.md) にまとめた。
- 作業ツリーには、git に無いローカルの 3D 一式がある。72 ファイルは skip-worktree を付けてあり、`git ls-files -v | grep "^S "` で一覧できる。退避先は `D:\747-400-local-assets\`（README.txt 参照）。新しいオブジェクト約 200 個は未追跡のまま。

## 1. プラグイン

| フォルダ | 種類 | 役割 |
|---|---|---|
| `plugins/xtlua` | XTLua（1つめ） | 一般系統：スイッチ類、電源、ギア、無線、燃料、火災、エンジン、EEC、操縦系統、防氷、EICAS 警報、quick start |
| `plugins/xtlua_keysystems` | XTLua（2つめ） | 油圧、air（空調・抽気・与圧）、飛行計器、FMC/CDU、AFDS・autothrottle、照明 |
| `plugins/xtlua_nd` | XTLua（3つめ） | ND の地図データ |
| `plugins/xtlua_fdr` | XTLua（4つめ） | flight data recorder（解析用の記録） |
| `plugins/AutoATC` | 設定のみ | AutoATC の音声コマンド定義（`voice commands/voice_control.json`）。AutoATC 本体は別途インストール |

- XTLua の各インスタンスは同じ構成になっている。
  - `64/{win,lin,mac}.xpl`：本体。4つとも同じバイナリで、**手を入れない**。
  - `init.lua`・`init/init.lua`：グルーコード。
  - `init/scripts/<モジュール>/`：dataref とコマンドを**作る**側。`deferred_dataref`・`deferred_command` で、XLua の API を呼ぶ。
  - `scripts/<モジュール>/`：ロジック側。ファイル名に `.xt.` が入る。
- ロジック側は `find_dataref`・`deferred_dataref`・`replace_command`・`wrap_command` と、`run_timer` などのタイマーを使う。コールバックは `aircraft_load`・`flight_start`・`livery_load`・`before_physics`・`after_physics`・`aircraft_unload`。
- XTLua の仕組み（README：https://github.com/mSparks43/XTLua 、2026-10-23 確認）：
  - XLua を改造したもので、`before_physics` と `after_physics` をワーカースレッドで実行する。
  - `create_dataref` と `create_command` は `init/scripts/` の中でしか使えない。
  - dataref は flight model の 1 フレームに 1 回、X-Plane と同期する。読みは使った dataref だけ取りに行き、書きは X-Plane に**非同期で**反映される。書いた値をすぐ判定に使うときは、いったんローカル変数に入れる。
  - コマンドの handler は phase（0 押下、1 保持、2 解放）と duration を受け取る。`start()` には必ず `stop()` を対にする。
  - `after_physics` は、ポーズ中とリプレイ中以外の毎フレーム呼ばれる。
  - `print()` は Log.txt に `LUA:` 付きで出る。Developer メニューからスクリプトを再読み込みできる。
  - global のテーブルで不具合が出ることがある（XTLua issue #4）。旧フォークでも、メタテーブルなしの global テーブルで止まる事例があった（OLD_FORK_NOTES.md §14）。
- XTLua 本体が出す特別な dataref：`xtlua/fms`（X-Plane の FMS の飛行計画を JSON で）、`xtlua/navaids`、`xtlua/fltpln`、`xtlua/loadtoFMS`、`xtlua/currentFMS`、`xtlua/currentFMSID`、`xtlua/xpFMSData`、`xtlua/controlObject`。
- 外部との連携：
  - AutoATC と Hoppie（ACARS・CPDLC）
  - Avitab（`B747.xt.Avitab`）
  - Terrain Radar（`*.acf.terrain_radar_descr`）
  - librain（`objects/librain`）
  - FMOD（`fmod/*.bank`・`*.snd`）
- FlyWithLua NG+ 2.8.19 は、2026-10-23 に利用者が X-Plane に導入した（`Resources/plugins/FlyWithLua/`）。機体はこれに依存しない。飛行試験キットだけが使う（TESTING.md）。

## 2. スクリプト一覧（モジュール単位）

行数は「init 側 / ロジック側」。override は X-Plane の `sim/operation/override/*` のうち、そのモジュールが取るもの。

| プラグイン | モジュール | 行数 | 内容 | override |
|---|---|---|---|---|
| xtlua | B747.01.manipulators | 400 / 2419 | 操縦室のスイッチ・ボタン・ノブのコマンド（`button_switch`、`toggle_switch`）。防護カバー、ドアハンドルなど | |
| xtlua | B747.03.electrical | 164 / 1065 | 電源。init 側ヘッダの説明（4 つの main bus はすべての bus tie が閉じたときだけ同時に通電）は古い。今のコードは X-Plane の `cross_tie` を毎フレーム 1 にして全バスを一体で扱い、バスごとの状態は表示用のフラグしかない（notes/ATA-24.md） | GPU_volts |
| xtlua | B747.05.simconfig | 55 / 567 | 機体設定（エンジン型式、単位、音など）。リバリーごとの `B747-400_simconfig.dat`（JSON）を読み書きする。`version.lua` を含む | |
| xtlua | B747.10.gear | 165 / 1061 | 脚の上げ下げ、ブレーキ、オートブレーキ | toe_brakes |
| xtlua | B747.15.com | 565 / 3862 | 無線。ACP（`ap_L/C/R`）、RTP（`rtp_L/C/R`）、VHF/HF、call panel など | |
| xtlua | B747.25.fuel | 405 / 3720 | 燃料系統（タンク、ポンプ、クロスフィード、移送、ジェティソン、搭載量） | fuel_system |
| xtlua | B747.35.fire | 99 / 653 | 火災探知と消火（エンジン、APU、貨物室） | |
| xtlua | B747.36.oxygen | 56 / 327 | 酸素（乗員・乗客・治療用、酸素圧、X-Plane の低酸素）。3-3 で新設（§4.13） | oxygen_system |
| xtlua | B747.40.engines | 106 / 2247 | エンジン始動・点火・燃料制御・逆推力・APU | |
| xtlua | B747.42.EEC | 67 / 4376 | EEC と推力制御。型式別の `EEC.PW` / `EEC.GE` / `EEC.RR`、表（`EEC.tbls`）、`pid.lua` | throttles |
| xtlua | B747.45.fltCtrls | 187 / 1370 | 操縦系統（フラップ、スポイラー・スピードブレーキ、トリム、代替フラップ） | |
| xtlua | B747.50.antiice | 86 / 663 | 防氷・防雨（主翼・ナセル防氷、ウインドウ・プローブ加熱、ワイパー） | |
| xtlua | B747.85.safety | 79 / 378 | サイン類（No Smoking、Seat Belts）、チェックリストの印 | |
| xtlua | B747.87.warning | 649 / 1163 | EICAS メッセージ（`laminar/B747/CAS/gen_{warning,caution,advisory,memo}_msg_NNN`）、master warning/caution、警報音 | |
| xtlua | B747.95.AI | 0 / 2709 | quick start（系統ごとの `laminar/B747/ai/*_quick_start`）。旧 B738 の流用 | |
| xtlua | B747.99.VRcontrols | 375 / 0 | VR 用の操作（init 側のみ） | |
| xtlua | Avionics・B747.Avitab | 5 / 130 | 補助（発電機の電流など）、Avitab の連携 | |
| xtlua_keysystems | B747.19.hydraulicsmodel | 186 / 2116 | 油圧 4 系統のモデル、舵面の駆動とステアリング（`hydraulics_override`）。同じ名前空間に AFDS の制御則（`afds_control`）・ヨーダンパー（`yaw_damper`）・スラット（`slats`）。R-1 で `hydraulics_override` から分けた（§2.1） | control_surfaces、wheel_steer |
| xtlua_keysystems | B747.20.hydraulics | 92 / 555 | 油圧パネルと表示 | |
| xtlua_keysystems | B747.30.fltMgmt | 112 / 452 | IRU のモードセレクタ、トランスポンダのパネル | |
| xtlua_keysystems | B747.55.air | 170 / 1220 | 空調パック、抽気、与圧、温度 | |
| xtlua_keysystems | B747.60.fltInst | 459 / 4716 | 飛行計器。`fltInst02` が PFD・EICAS・ND 補助・表示切替（`dsp`）、`03`・`04` が時計 | |
| xtlua_keysystems | B747.68.fms | 199 / 13196 | FMC/CDU（3 台、詳細は §6） | |
| xtlua_keysystems | B747.70.autopilot | 274 / 5449 | AFDS（MCP、FMA、LNAV/VNAV）、autothrottle、autoland（`B747.autoland`）、監視（`monitor`） | throttles、fms_advance |
| xtlua_keysystems | B747.90.lighting | 215 / 2403 | 照明（計器、フラッド、外部灯）、気象レーダーの表示操作（`wxr`） | |
| xtlua_nd | B747.61.nd | 532 / 1314 | ND の地図。ウェイポイント、航法施設、シンボル（`laminar/B747/nd/*`、633 個） | |
| xtlua_fdr | B747.01.fdr | 34 / 1038 | flight data recorder。モード変化のマーカー（`laminar/B747/fdr/*`）、解析用の記録 | |

### 2.1 R-1 で動かしたコードの行番号

notes と GAP_ANALYSIS.md の行番号は R-1 の前（041c9ffa）のもの。`B747.19.xt.hydraulics_override.lua` の行は、次のとおり移った（フォルダは `plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/`。中身は変えていない）。

| 元の行 | 移った先（行） | 中身 |
|---|---|---|
| 1–17 | `hydraulics_override` 1–17 | 先頭のコメント |
| 18 | `hydraulicsmodel` の `dofile` の並び | `dofile("pid.lua")` |
| 20–21 | `afds_control` 6–7 | AFDS のモード枠の dataref |
| 22–341 | `hydraulics_override` 18–337（元 − 4） | 油圧の消費、舵面の出力 |
| 342–368 | `slats` 4–30（元 − 338） | スラット |
| 369–391、399–403、405–425 | `afds_control` 8–30、31–35、36–56 | トリムの変数、FD の記録、ロール指令 |
| 393–398、404、426–432 | `yaw_damper` 5–10、11、12–18 | ヨーの記録、ヨーの入力 |
| 433–835 | `afds_control` 57–459（元 − 376） | ピッチ指令（FLCH・ALT・V/S・G/S・TO/GA）、ロールの平均 |
| 836–899 | `yaw_damper` 19–82（元 − 817） | ヨーダンパーの入力の平均 |
| 900–1040 | `afds_control` 460–600（元 − 440） | ピッチの平均、autotrim、ピッチ・ロールのサーボ（PID） |
| 1041–1103 | `yaw_damper` 83–145（元 − 958） | ヨーダンパーの則（PID） |
| 1104–1154 | `hydraulics_override` 338–388（元 − 766） | `flight_controls_override`（毎フレームの呼び出し、ステアリング） |

## 3. X-Plane 本体の機能との関係

- **自前で置き換えているもの**（コメントを除いて確認）：燃料系統、推力（スロットルを EEC が設定）、舵面（油圧モデルが操縦入力と AP の指令から舵角を決める）、前輪ステアリング、ブレーキ、FMS のポイント切り替え（LNAV）、GPU 電圧。`override_joystick_*` と `override_artstab` はコメントにあるだけで、使われていない。
- **X-Plane の機能を土台にしているもの**：
  - 電源：X-Plane のバスをすべて 1 つにつないだ簡略モデル。ほかのモジュールは「電源があるか」を `sim/cockpit2/electrical/bus_volts[0] > 0` で判定しており、これはバッテリーだけでも真になる（notes/ATA-24.md）。
  - エンジン：acf は `JET_2SPOOL`。始動・燃料・推力の指令は自前。
  - AFDS：X-Plane の autopilot の dataref（`sim/cockpit2/autopilot/*`。heading、airspeed、VS、alt hold・nav・G/S の status、servos）を書き、その上にモードロジックを乗せている。
  - FMC：X-Plane の FMS の飛行計画と航法データベース（`xtlua/fms`、`xtlua/navaids`、`sim/FMS/*` コマンド、`sim/cockpit2/radios/indicators/fms_*`）。
  - 空調・与圧：X-Plane の与圧 dataref も使う。
- 実機に近づけるときは、X-Plane の機能のどこまでを土台に残すかを系統ごとに決める必要がある。特に電源の簡略化は、実機の bus tie・split system breaker の論理と合わない。系統ごとの評価は GAP_ANALYSIS.md に書く。

## 4. 主要な dataref とコマンド

Lua が作る名前の数：dataref 1617 個、コマンド 628 個。静的に拾える分だけで、ループで作る名前は含まない。

| 名前空間 `laminar/B747/…` | dataref 数 | 主に作るモジュール |
|---|---|---|
| nd | 633 | 61.nd、60.fltInst、68.fms |
| fuel | 216 | 25.fuel |
| autopilot | 211 | 70.autopilot（42.EEC、19.hydraulicsmodel なども） |
| flt_ctrls | 137 | 45.fltCtrls、19.hydraulicsmodel |
| ap_L / ap_C / ap_R | 各 98 | 15.com（audio control panel） |
| hydraulics | 97 | 19.hydraulicsmodel |
| engines / engine | 84 / 27 | 40.engines、42.EEC、05.simconfig |
| airspeed | 84 | 60.fltInst、70.autopilot |
| comm | 74 | 15.com、68.fms |
| efis / air | 各 66 | 60.fltInst / 55.air |
| cablecontrols | 63 | 19.hydraulicsmodel（舵面ごとの指令） |
| electrical | 58 | 03.electrical |
| fltInst・flt_inst / clock | 52・48 / 40 | 60.fltInst |
| light / wxr | 46 / 26 | 90.lighting |
| fire / CAS / warning | 38 / 20 / 11 | 35.fire / 87.warning |
| gear / dsp / fmod / misc / flt_mgmt | 19 / 22 / 21 / 14 / 14 | 10.gear / 60.fltInst / 各所 / 01.manipulators / 30.fltMgmt |

- コマンドの多い名前空間：`button_switch`（185）、`comm`（156）、`toggle_switch`（88）、`flt_inst`（62）、`ap_L/C/R`（各 62）、`nd`（52）、`efis`（48）、`ai`（34）、`fdr`（30）、`autopilot`（30）。
- 名前を変えてはいけないものの一覧：[INTERFACES.tsv](INTERFACES.tsv)。3D オブジェクト・パネル計器（`DATAREF` 行と表示条件 `SHOW_EQUAL/LESS/GREATER`）・FMOD サウンド・AutoATC が参照する `laminar/*` の名前が 2029 個あり、内訳は dataref 1072、コマンド 537、実行時に作られる名前（または未定義）420。
- 機体設定のよりどころ：`laminar/B747/simconfig`（JSON 文字列）と `laminar/B747/newsimconfig`（更新フラグ）。エンジン型式は `laminar/B747/engines/type`（§7）。

### 4.1 電源の公開 dataref（1-1 で新設）

電源モデル（`plugins/xtlua/scripts/B747.03.xt.electrical/B747.03.elec_model.lua`）の出力。init スクリプト `B747.03.electrical` で作り、`B747.03.xt.elec_buses.lua` が毎フレーム書く。他の系統は、電源の有無をここで判定する（`sim/cockpit2/electrical/bus_volts` はバッテリーだけでも真になるので使わない）。値は 1 が通電・閉、0 が非通電・開。配列の添字は 0 始まり。中身は notes/ATA-24.md。

| 名前 `laminar/B747/electrical/…` | 型 | 中身 |
|---|---|---|
| `bus/ac` | array[4] | AC 1-4 |
| `bus/dc` | array[4] | DC 1-4 |
| `bus/utility`・`bus/galley` | array[4] | utility 1-4・galley 1-4（109。L UTILITY が 1・2、R が 3・4） |
| `bus/sync` | array[2] | 同期バス 左・右 |
| `bus/any_ac` | number | AC 1-4 のどれかに電源 |
| `bus/xfr_capt`・`bus/xfr_fo` | number | CAPT・F/O transfer bus |
| `bus/stby_main`・`bus/stby_apu` | number | main・APU standby bus |
| `bus/bat_main`・`bus/bat_apu` | number | main・APU battery bus |
| `bus/hot_bat_main`・`bus/hot_bat_apu` | number | main・APU hot battery bus |
| `bus/dc_tie` | number | DC tie bus |
| `bus/gnd_svc`・`bus/gnd_svc_util` | number | ground service bus・ground service utility bus |
| `bus/gnd_hdlg`・`bus/gnd_hdlg_dc` | number | ground handling bus・DC ground handling bus |
| `breaker/gcb`・`breaker/btb`・`breaker/dcir` | array[4] | GCB・BTB・DCIR 1-4 |
| `breaker/xpc`・`breaker/apb` | array[2] | XPC 1/2（EXT）・APB 1/2（APU GEN） |
| `breaker/ssb` | number | split system breaker |
| `idg_connected` | array[4] | IDG の drive が接続 |
| `air_mode`・`load_shed` | number | BCU の air mode・負荷制限の実行中 |
| `battery/volts`・`battery/amps` | array[2] | main [0]・APU [1] バッテリーの電圧と電流（+ 放電、− 充電） |
| `battery/stat_amps` | array[2] | 同じ電流の符号なし（カスタム acf の STAT ページの A-DC、2026-10-23） |
| `light/ext_avail`・`light/apu_avail`・`light/util_off` | array[2] | P5 の AVAIL・UTILITY OFF 灯 |
| `light/isln`・`light/gen_off`・`light/drive` | array[4] | P5 の ISLN・GEN CONT OFF・DRIVE 灯 |

- 前からある名前（`bus1hot`〜`bus4hot`、`topleftbus`・`toprightbus`、`ssb`、`utilityleft1/2`・`utilityright1/2`、`ext_pwr1_on`・`apu_pwr1_on` など、`laminar/B747/rel_esys`〜`rel_esys4`、`capt_display_power`・`fo_display_power`、`display_has_power[6-8]`、`apu_volts`）も、同じモデルから意味を保って書く（notes/ATA-24.md §6）。
- カスタム acf の ELEC synoptic は ISLN の枠を `breaker/btb`、DRIVE の枠を `light/drive`（IDG の油圧低）で、STAT ページのバッテリーは `battery/volts`・`battery/stat_amps` で出す（ACF_DIFF.md §5）。純正 acf は前のまま（スイッチ位置、エンジン滑油圧、X-Plane のバッテリー）。
- X-Plane の電気系統は代理として残す：`cross_tie` は 1、`battery_on[0]` は BATTERY スイッチ、`gpu_on` は XPC のどれか、`APU_generator_on` は APB のどれか、`generator_on[n]` は GCB n。

### 4.2 空地判定（PSEU）の公開 dataref（1-2 で新設）

空地のモデル（`plugins/xtlua/scripts/B747.10.xt.gear/B747.10.pseu_model.lua`）の出力。init スクリプト `B747.10.gear` で作り、`B747.10.xt.pseu.lua` が毎フレーム書く。他の系統は、空地をここで判定する（`sim/flightmodel/failures/onground_any` はどれか 1 輪の接地で真になる）。値は 1 が真。中身は notes/ATA-32.md §4.1。

| 名前 `laminar/B747/gear/air_ground/…` | 中身 |
|---|---|
| `pri_air`・`pri_gnd` | primary の AIR・GND（ATA29_32 p.322 の式。片側の主脚だけの接地では AIR のまま、左右とも接地で GND） |
| `alt_air`・`alt_gnd` | alternate の AIR・GND（故障を入れるまでは primary と同じ） |
| `ng_compressed` | 前脚圧縮（主脚とは別の信号。ペダルのステアリング、離陸警報、失速警報が使う） |
| `all_gear_down`・`nose_not_down` | ALL GR DN（5 本ともダウンロック）・前脚がダウンロックでない |
| `lever_unlock` | LG LVR UNLK（主脚トラック 4 本とも傾き、かつ胴体脚ステアリングがロック：FCOM p.1512） |

- 乗り換え済み：電源の BCU（air mode・APU 発電機・地上ハンドリングバス）、脚レバーのロック。ほかの系統は、それぞれの作り直しで乗り換える（PROGRESS.md）。

### 4.3 乗員への警報（1-3）

警報のモデル（`plugins/xtlua/scripts/B747.87.xt.warning/B747.87.alert_model.lua`）を、グルー `B747.87.xt.alerts.lua` が警報モジュール（`B747.87.xt.warning.lua`）の中で 0.1 秒ごとに回す。中身は notes/ATA-31-warning.md §3・§4。

- 入口は今までどおり：各系統は `laminar/B747/CAS/{warning,caution,advisory,memo}_status[n]` に 0/1 を書く。添字は変えていない。
- 表示のレベルはメッセージ表（`B747.87.xt.warning.lua` の先頭）で決まる。`level` があれば、配列とは別のレベルで出す（例：ENG FAIL は warning の配列に書かれるが caution）。
- 出口（名前と意味は変えていない）：

| dataref | 書くもの | 読むもの |
|---|---|---|
| `CAS/gen_{warning,caution,advisory,memo}_msg_NNN` | ページ p の n 行目を NNN = 11(p−1)+n−1 に、その行のレベルの名前の方に書く（他のレベルは空白 1 字） | パネル（カスタム acf は 000〜109 の 10 ページ分、純正 acf は 000〜021 の 2 ページ分。ACF_DIFF.md §5） |
| `CAS/msg_page`・`num_msg_pages` | 見ているページ、ページ数 | パネル（PG はカスタム acf で 2 ページ目から、純正 acf は `num_msg_pages > 2` のときだけ） |
| `CAS/caut_adv_display` | 0＝CANC で隠した caution/advisory がある（RCL で 1） | なし |
| `warning/master_warning`・`master_caution` | master 灯 | 3D |
| `warning/master_caution_audio` | master CAUTION を点けた caution、beeper のある advisory ごとに 1 秒 | `.snd` の beeper（`747-400_custom.snd`・手元の `747-400.snd`・`747-400_XP11.snd`） |
| `warning/warning_bell`・`warning_siren`・`warning_wailer` | FCOM の音の要求（リセットの可否を含む） | `.snd` のベル・サイレン・wailer（`747-400_custom.snd`・手元の `747-400.snd`。FIRE/OVHT TEST のベルは試験ボタンのまま） |

- 押した回数（1-3 で新設、init スクリプト `B747.87.warning02`）：別のプラグイン・モジュールにあるスイッチを、警報モジュールに渡す。値は押すたびに 1 増える。

| 名前 | 増やす側 | 意味 |
|---|---|---|
| `laminar/B747/CAS/canc_count` | fltInst02 の CANC（`laminar/B747/dsp/canc_switch`、CDU の EICAS CTL ページからも） | ページ送り、最後のページで caution/advisory を隠す |
| `laminar/B747/CAS/rcl_count` | fltInst02 の RCL（`laminar/B747/dsp/rcl_switch`） | 隠したものを戻して 1 ページ目。RECALL の表示（`CAS/recall_ind`）は今までどおり fltInst02 |
| `laminar/B747/warning/master_reset_count` | manipulators の master リセット（`button_switch/warn_caut_capt`・`_fo`） | 両方の master 灯を消す。灯は manipulators もその場で消す |
- STATUS（WARN-17、2026-10-23）：各系統は `laminar/B747/CAS/status_status[n]`（64 個）に 0/1 を書く。名前の表は `B747.87.xt.warning.lua` の `B747_CASstatusMsg`。枠の割り当て：0〜19 油圧（HYD PRESS ENG・DEM、HYD OVHT SYS、HYD RSVR PRESS、HYDIM）、20〜24 空圧（BLEED ASCTU A・B、BLEED ISLN L・R・APU）、25〜28 電源（DRIVE DISC 1〜4）。
  - グルーが書くもの：STATUS ページの行を `CAS/gen_status_msg_NNN`（NNN = 11(p−1)+n−1、新しいものが先頭）、ページ数を `STAT/num_msg_pages`（fltInst02 の STAT スイッチがこれでページを送り、最後のページで閉じる）、cue を `CAS/status_cue`、cue の文字を `CAS/status_cue_text`（"STATUS"）。STATUS ページ（`dsp/synoptic_display` = 2）を出すと、そのとき出ているメッセージは「見た」になり、cue が消える。
  - パネル：カスタム acf だけが STATUS ページの行・PG と主 EICAS の cue を描く（ACF_DIFF.md §5）。

### 4.4 油圧（1-4）

油圧のモデル（`plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.hyd_model.lua`）を、グルー `B747.19.xt.hyd_power.lua` が油圧モジュール（`B747.19.xt.hydraulicsmodel.lua`）の中で毎フレーム回す。中身は notes/ATA-29.md §2〜§4。

- 毎フレームの順：`B747_hyd_power()`（モデル）→ `pressure_input()`（舵面が使える圧＝モデルの系統圧）→ `flight_controls_consumption()`（舵面が動くたびに圧を差し引き、900 psi 未満の系統しか無い舵面は止まる。前からの作り）→ `pressure_output()`（残りを `pressure_n` に書き、差し引いた量を次のフレームのモデルの需要にする）。舵面とモデルの受け渡しは同じ Lua の状態の関数（`B747_hyd_power_psi`・`B747_hyd_power_left`）で、dataref の読み直しはしない。
- 書く dataref（名前と意味は前と同じ。notes/ATA-29.md §6.2）：`hydraulics/pressure_1〜4`（系統圧、psi）、`edp_pressure_n`・`dem_pressure_n`・`aux_pressure`（ポンプの出口圧）、`dem_mode_n`（セレクタ。-1 AUX、0 OFF、1 AUTO、2 ON）、`valve_n`（1＝供給遮断弁が開で EDP が ON）、`pressure_13`・`23`・`24`・`234`（synoptic の不作動の絵）、`res_n`・`restotal_n`（作動油量。正規量 1.00 の比）、`temp_n`（℃）、`indicators/hydraulic_pressure_1_2_4`（ブレーキ accumulator 計）、`EICAS2/stat/RF`・`LO`（[1]〜[4]）。
- 新設（1-4、init スクリプト `B747.19.hydraulicsmodel`）：`laminar/B747/hydraulics/light/eng_press`・`dem_press`・`sys_fault`（[0]〜[3]＝系統 1〜4）、`light/brake_source`。照明モジュールが P5 の ENGINE PRESS・DEMAND PRESS・SYS FAULT と機長側の BRAKE SOURCE の灯に使う。
- EICAS：caution 9（>BRAKE SOURCE）、40〜43（HYD PRESS SYS）、advisory 200・201（HYD CONTROL 1・4）、202〜205（HYD OVHT SYS）、206〜209（HYD PRESS DEM）、210〜213（HYD PRESS ENG）、218〜221（>HYD QTY LOW）。
- カスタム acf の HYD synoptic 用（HYD-18・19、2026-10-23、init スクリプト `B747.19.hydraulicsmodel`）：`hydraulics/synoptic/edp`・`dem`（[0]〜[3]。記号の状態 0 ON（空の記号）、1 ON 琥珀、2 AUTO 琥珀、3 AUTO シアン、4 OFF 琥珀。EDP は 0・1・4 だけ）、`synoptic/aux`（0 OFF 白、1 待機（シアン）、2 運転（白）、3 琥珀）、`synoptic/sov`（[0]〜[3]、1＝開）、`synoptic/rsvr_press`（[0]〜[3]、1＝RSVR PRESS）、`synoptic/inop`（[0]〜[3]、不作動項目の一覧。0 なし、1 一覧、2 THRUST REV つきの一覧（P&W））、`synoptic/inop_set`（[0]〜[5]、`M.SYN_SETS` の組 1+2・1+3・2+3・2+4・3+4・1+2+4 の共通項目、1＝出す）。状態はモデルの `M.SYN_*`。系統を失ったとは、系統圧低（HYD PRESS SYS と同じ条件）。純正 acf は前からの `valve_n`・`dem_mode_n`・`pressure_13` などを使い続ける。パネルの画像は `docs/overhaul/tools/make_synoptic_images.ps1` で作る（ACF_DIFF.md §5）。
- X-Plane の油圧は「常に加圧、故障を書かない」（notes/ATA-29.md §6.1）。`B747.20` はポンプの故障（`rel_hydpmp*`）を書かなくなった。X-Plane の漏れ故障（`rel_hydleak*`）は、グルーが作動油量を減らす形で受ける。

### 4.5 空圧（1-5）

抽気のモデル（`plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.bleed_model.lua`）を、グルー `B747.55.xt.bleed.lua` が空調モジュール（`B747.55.xt.air.lua`）の中で毎フレーム回す（`after_physics` の最初、`B747_bleed()`）。中身は notes/ATA-36.md §2〜§4。前の抽気のコード（源の最大値を取る作り、乱数の上限）は外した。パックと与圧は §4.11。

- 読むもの：P5 の抽気パネル（`button_switch/position` の [75] ISLN L、[76] ISLN R、[77]〜[80] ENGINE BLEED 1〜4、[81] APU）、NAI（[68]〜[71]）、START（`toggle_switch/position` [16]〜[19]）、AUTOSTART（`button_switch/position` [45]）、FUEL CONTROL、エンジン火災スイッチ（`pos_arm`）、N2（`engines/display_N2`）、APU の N1 とセレクタ、AC・DC バス（`electrical/bus/ac`・`dc`）、パックの流量（パックのモデルの前のフレームの値、§4.11）、主翼防氷弁、demand pump 1・4（ADP）の出口圧、高度計の高度、X-Plane の故障 `rel_APU_press`（APU が空気を出さない）。
- 書く dataref（名前と意味は前と同じ）：`air/engineN/bleed_air_psi`（PRV の下流の圧。ナセル防氷とピトー加熱が読む）、`engineN/bleed_valve_pos`（PRSOV。ENGINE BLEED の OFF 灯と synoptic）、`engineN/bleed_start_valve_pos`（始動弁。エンジンが読んでスターターを回す）、`isolation_valve_L_pos`・`R_pos`、`apu/bleed_valve_pos`、`duct_pressure_L`・`C`・`R`（主翼防氷、ADP、EICAS のダクト圧）。
- X-Plane へ（3-1 で変えた）：X-Plane の与圧を上書きした（§4.11）ので、X-Plane は自分のダクトと抽気の損失を計算しない。代わりに `bleedair/indicators/bleed_available_left`・`center`・`right` にダクト圧 ÷ 27.5（上限 1.5）を書く（X-Plane のエアスターターはこれで回る。上書き前の X-Plane 自身の値に合わせた推定）。`engine_loss_from_bleed_air_ratio[n]` にそのエンジンが出す流量 × 1 ℃、`APU_loss_from_bleed_air_ratio` に APU の流量 × 15 ℃（推定）。`bleed_air_mode`（ダクトに空気があれば 5 auto、無ければ 0 off）は前のまま書く（`.snd` のパックの音が `sim/cockpit/pressure/bleed_air_on` を見る）。
- 新設（1-5、init スクリプト `B747.55.air`）：`laminar/B747/air/light/sys_fault`（[0]〜[3]）、`light/isln_valve`（[0] L、[1] R）、`light/apu_valve`。照明モジュールが P5 の SYS FAULT・VALVE 灯に使う（`brightness_ratio` の [118]〜[121]、[72]・[73]、[74]）。3-1 段 3 で `air/ext_air`（ECS synoptic の EXT AIR：APU とエンジンが止まっているのに、パックが運転かダクトに 5 psi 以上、消えて 5 秒まで。FCOM p.578）を足した。
- EICAS（advisory）：22〜25（BLD n OVHT/PRV）、34（>BLEED ISLN APU）、35・36（BLEED ISLN L・R）、39〜42（>BLEED n OFF）。
- 流量は「high flow のパック 1 台＝1」の単位で数え（normal は 2/3）、ダクト圧は源の圧から使う量に応じて下げる。値の多くは推定（PROGRESS.md「推定で作った部分」）。過熱の入力はモデルにあるが、つなぐ故障がまだ無い。

### 4.6 APU（2-1）

APU の制御のモデル（`plugins/xtlua/scripts/B747.03.xt.electrical/B747.49.apu_model.lua`）を、グルー `B747.03.xt.apu.lua` が電源モジュールの中で毎フレーム回す（`B747_apu()`、電源のグルーの前）。中身は notes/ATA-49.md §3〜§4。前の APU の処理（電源モジュールの `B747_apu`、EICAS の APU 3 つ、エンジンモジュールの APU N2・油量）は外した。回転と EGT は X-Plane の APU のまま。

- 状態：OFF → STARTING（ドア全開で starter）→ RUNNING（N1 95 %）→ COOLDOWN（selector OFF から 60 秒、発電機と抽気なし）→ STOPPING → OFF。START に回すと始動を保持する（selector の up のハンドラが `B747_apu_start_pushed` を立てる）。
- 読むもの：`electrical/apu/sel_dial_pos`、BATTERY スイッチ（`button_switch/position[13]`）、X-Plane の `APU_N1_percent`・`APU_running`、`rel_apu_fire`（6 で火災）、主タンク 2 の燃料（`m_fuel[2]`）、PSEU（`gear/air_ground/pri_air`）。
- 書くもの（名前と意味は前と同じ）：X-Plane の `APU_starter_switch`（2 始動、1 運転、0 停止。読んで違うときだけ書く）、`electrical/apu_inlet_door`（3D のドア）、`electrical/apu_pwr1_avail`・`apu_pwr2_avail`（APU GEN スイッチが受け付ける。運転中で selector ON、地上）、`apu/n2`・`apu/oil`（STATUS ページ）、advisory 13（APU）・14（APU DOOR）、memo 1（APU RUNNING）。
- 電源モデルの入力 `apu_gen_ok`（`B747_apu_gen_ready()`）：APU の発電機が使えるのは運転中で selector ON のときだけ（cooldown は無負荷）。電源モデルの AVAIL と APB はこれも見る。
- quick start（B747.95.xt.AI）の APU の手順は、待ちを 30 秒から 120 秒にした（ドアが先に開き、X-Plane の APU は 95 % まで約 1 分）。

### 4.7 燃料（2-2）

燃料のモデル（`plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua`）を、燃料モジュール（`B747.25.xt.fuel.lua`）の `B747_fuel_system()` が毎フレーム回す（`after_physics` の最初）。中身は notes/ATA-28.md §2〜§4。前のポンプ・弁・供給源・流量・タンク量・EICAS の処理は外した。synoptic の状態コード（`B747_fuel_*_synoptic`）、燃料温度、給油、表示単位、tank helper は前のまま（給油はモデルの量を書く）。

- 読むもの：ポンプのスイッチ（`button_switch/position` の [52]〜[67]）、X FEED（[48]〜[51]）、FUEL XFER MAIN 1 & 4（[43]）、NOZZLE（[46]・[47]）、ジェティソン選択器、FTR、FUEL CONTROL（`toggle_sw_pos`）、火災スイッチ（`pos_arm`）、バス（`electrical/bus/ac`・`utility`・`dc`・`bat_main`・`hot_bat_main`・`gnd_svc`・`bat_apu`）、PSEU（`pri_air`）、フラップレバー（`flap_ratio`）、ピッチ、X-Plane のエンジンの燃料流量と運転状態、APU の starter（`APU_starter_switch` が 1 以上で APU が燃料を使う）、燃料温度、タンク容量（acf の `acf_tank_rat`×`acf_m_fuel_tot`）、貨物機の設定（`laminar/B747/freighter`。1 なら水平安定板タンクの論理を止める：FCOM p.1453）。
- タンクの量はモデルが持つ。X-Plane の `m_fuel` には毎フレーム書き、前のフレームに書いた値から 20 kg を超えて変わったタンクは外からの変更（重量の画面、リプレイ）として取り込む。給油（`B747_refueling`）と地上で 100 t を超えるときの前の配分（`initial_load`）は、モデルの量を直接変える（`fuel_qty`）。
- フライトの開始から 2 秒は「落ち着かせる」時間：X-Plane の量を取り込み（XTLua の最初の読みは 0 のことがある）、弁を指令の位置に置き、運転中のエンジンには燃料を出し続け、メッセージは出さない。
- 書く dataref（名前と意味は前と同じ）：ポンプの `*_on`（モーターが回っていれば 1。スカベンジの `scvg_pump_*` はジェットポンプに流れがあるとき）、弁の `*_pos` と xfeed の `target_pos`、`engine1〜4_status`（1 自タンク、2 マニフォールド、0 なし。spar valve が閉なら 0）、`jett_vlv_status`、`jettison_time`、`stab_pump_L/R/pressure_low`、`totaliser`（[4] はエンジン 4 発の流量だけ）、X-Plane の `m_fuel` と `has_fuel_flow_before_mixture`（モデルの供給とエンジン燃料弁。読んで違うときだけ書く）。
- 新設（2-2、init スクリプト `B747.25.fuel`）：`laminar/B747/fuel/light/pump_press`（[0]〜[15]、`B747_fuel_model.PUMPS` の順）、`light/xfeed_valve`（[0]〜[3]）、`light/nozzle_valve`（[0] L、[1] R）。照明モジュールが頭上の PRESS・VALVE 灯に使う（`brightness_ratio` の [38]〜[59]）。
- EICAS：caution 31（FUEL JETT SYS）、32〜35（FUEL PRESS ENG）、36（FUEL QTY LOW）、37（FUEL STAB XFR）、67・68（FUEL PRES STB L・R、advisory）、69・70（FUEL PRESS CTR）。advisory 15（APU FUEL）、114〜117（ENG n FUEL FILT：X-Plane のフィルター故障）、148〜150（IMBALANCE、IMBAL 1-4・2-3）、153・154（>FUEL OVD CTR）、155〜158（FUEL OVRD）、159・160（>FUEL PMP STB）、161〜168（FUEL PUMP）、169・170（FUEL RES XFR 2・3）、171（>FUEL TANK/ENG）、172（FUEL TEMP LOW）、175〜178（FUEL X FEED）、179（>FUEL XFER 1+4）、235〜239（>JETT NOZ ON・L・R、>JETT NOZZLE L・R）、299（>X FEED CONFIG）、302・303（>FUEL LOW CTR）。
- 消費は X-Plane の燃料流量（acf の SFC で決まる）を、モデルが決めた供給タンクから引く。始動中に負になる流量は 0 として扱う。

### 4.8 エンジンの始動・点火・燃料弁（2-3 段 1）

始動のモデル（`plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua`）を、グルー `B747.40.xt.engine_start.lua` がエンジンモジュール（`B747.40.xt.engines.lua`）の中で毎フレーム回す（`before_physics` の `B747_engine_start()`）。中身は notes/ATA-70-80.md §3〜§4。前の始動・starter・igniter・燃料弁の処理と、X-Plane の auto-ignite で起動時に点火していた処理、ENG FAIL・>ENG SHUTDOWN・STARTER CUTOUT・CON IGNITION ON の判定は外した。

- 読むもの：START（`toggle_switch/position` [16]〜[19]）、FUEL CONTROL（`toggle_sw_pos`）、火災スイッチ（`pos_arm`）、AUTOSTART（`button_switch/position[45]`）、CON（[44]）、`electrical/auto_ignit/sel_dial_pos`（0 = 1、1 = BOTH、2 = 2）・`stby_ignit/sel_dial_pos`（0 = 1、1 = NORM、2 = 2）、バス（`electrical/bus/ac`[0]・[2]、`stby_main`、`bat_main`、`bat_apu`）、PSEU（`pri_gnd`）、フラップレバー、X-Plane のエンジン別の nacelle heat、X-Plane の N2（`ENGN_N2_`）と `engine_is_burning_fuel`、表示の EGT（`engines/display_EGT`）、start valve（抽気の `air/engineN/bleed_start_valve_pos`）、spar valve（燃料の `fuel/spar_vlvN_pos`）、エンジン型式（`engines/type`）と貨物機（`freighter`）。
- 書くもの：`laminar/B747/engines/start_valve_cmd`（新設 [0]〜[3]、1 = 開の指令。抽気のグルーが読み、ダクト圧が足りれば start valve を開ける）、X-Plane の starter（`sim/starters/engage_starter_n` を start valve が開いている間だけ保持）、`igniter_on`、`auto_ignite_on`（常に 0）、`mixture_ratio`（読んで違うときだけ書く）、`engines/fuel_valve_pos`（エンジン燃料弁と EEC の計量の両方が開いているとき 1。燃料のグルーが読む）、START switch の release（`toggle_switch/engine_startN_off`）。
- EICAS：warning 28〜31（ENG FAIL、caution の段階）、caution 19〜22（ENG AUTOSTART）・23〜26（>ENG SHUTDOWN）・61〜64（STARTER CUTOUT）、advisory 109（ENG IGNITION）・138〜141（ENG START VLV）・304（>AUTOSTART OFF、新設）・305〜308（ENG FUEL VLV、新設）、memo 8（CON IGNITION ON）。STBY IGNITION ON（memo 34）は電源モジュールのまま。
- フライトの開始から 2 秒は、FUEL CONTROL どおりに燃料弁を置き、燃えているエンジンには燃料を出し続け、メッセージは出さない（燃料のグルーと同じ）。

### 4.9 EEC（2-3 段 2）

EEC のモデル（`plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua`）を、グルー `B747.42.xt.eec_thrust.lua` が EEC モジュール（`B747.42.xt.EEC.lua`）の `after_physics` で毎フレーム回す（`B747_eec_update()`。型式ごとの `GE()`・`PW()` の前）。中身は notes/ATA-70-80.md §4.1。

- 最大定格（Max N1・Max EPR）：FCOM PI の表（PW4056 は着陸復行 EPR と最大上昇 EPR、CF6-80C2B1F は着陸復行 %N1 と最大上昇 %N1）を TAT と気圧高度で引き、パックとエンジン・翼の防氷で補正する。全開のときの定格は、17,000 ft と 300 kt より下で離陸、上は最大上昇（間は混ぜる。ATA70_80 p.208 の CF6 の論理。P&W は同じとした）。
- レバーの指令：アイドル端（GE は N1 25 %、P&W は EPR 0.95。前の値）から最大定格まで、レバー角に比例。離陸の定格は 48°、25,000 ft より上の最大上昇は 35° で頭打ち（ATA70_80 p.146-151、p.208）。
- 書くもの：`laminar/B747/engines/TRA`（指令。A/T もこれで目標に合わせる）、`display_N1_max`（GE）・`display_EPR_max`（P&W）（上の EICAS の最大線。前は FMC の推力基準だった）。FMC の推力基準（`display_*_ref`、target bug）と A/T のサーボは前のまま（PLAN.md の 6-4）。
- 推力の制御（FCOM p.875-876：EEC は燃料流量を調整して実際の N1・EPR を指令に合わせる）：GE・P&W は、`ecc_spd` が X-Plane のスロットル（`ENGN_thro_use`）を `B747_eec_throttle(i)` で決める（エンジン運転中・正推力・始動中でないとき。ほかのときは `B747_eec_reset_throttle(i)`）。追う値は指令（target）へ 1.5 秒の時定数と速さの上限（P&W 0.15 EPR/秒、GE は上げ 15・下げ 5 %N1/秒）で近づけ、スロットルは誤差の積分と誤差の変化に比例して動かす（速度形の PI。ゲインは表示値のスロットルに対する傾き＝ X-Plane で測った表で割る）。レバーがアイドル端ならスロットル 0。前の PID（D 項が大きく、出力 1.2 まで積分が溜まり、スロットルが 0.9〜1.05 を往復、EPR が最大定格を 0.02 超えたまま）は RR だけに残した。スロットルが 1 なのに指令に届かないエンジンがあれば、型式ごとのファイルが X-Plane の最大推力を少しずつ足す（前の仕組み。条件を `B747_eec_thrust_short()` に替えた。前の条件は X-Plane の N1 が 99.99 % 超えで、空中では働かなかった）。
- オーバースピード保護（FCOM p.878、p.901；ATA70_80 p.205）：N1・N2 が赤線から 0.5 % の手前の 2 % の帯に入ると、その回転の制限ループが制御量の許す値を出し、推力の制御は指令と制限の小さい方（target、`B747_eec_target(i)`）を追う。赤線は CF6 が N1 117.5・N2 112.5 %（ATA70_80 p.205）、P&W は表示が赤くなる 111.4 %（資料なし）。GE は N1 を直接制御するので N1 の制限は指令の頭打ち。>ENG n RPM LIM（advisory 134〜137）は GE が N2、P&W が N1 か N2 で押さえているとき（前は表示 N1 が赤線を超えたら。RR はその処理のまま `B747.40.xt.engines.lua`）。N2 は表示の丸め前の値を型式ごとのファイルから `B747_eec_set_n2(i, n2)` で受ける（P&W の表示は整数）。前の P&W の「表示 N1 110.1 % で燃料を絞る」処理は外した（RR は残した）。
- RR は資料が無いので、前の推力の論理のまま。
- ALTN：EEC MODE スイッチ（`button_switch/position` [7]〜[10]、0 = ALTN）でそのエンジンを代替モードにする（EEC の故障が無いので自動の移行は無い）。指令は最大定格で頭打ちせず、その高度で一番大きい定格（表の角の値、抽気の補正なし）までレバーに比例する（全開で overboost がありうる）。ENG n EEC MODE（advisory 313〜316）、>ENG n LIM PROT（caution 75〜78）。代替モードに入ると A/T を切り（`engines/autothrottle_fail` = 1、`autothrottle_active` = 0）、GE は混在中、P&W はどれかが代替の間、A/T を使えなくする（`EEC_status` = 1 で `throttle_management` の A/T のモードを止める）。前の「ALTN にすると A/T を切るだけ」の処理は外した。ALTN の灯は照明モジュールのまま（スイッチの位置）。
- アイドル：エンジンごとに approach idle を選び（空中でそのエンジンの防氷、着陸フラップ、405・570 の CON、GE の逆推力。条件が終わって 5 秒・接地 5 秒後に minimum）、X-Plane のアイドル（`sim/aircraft2/engine/high_idle_ratio`、全エンジンで 1 つ）を、どれかが approach なら 2.625、ほかは外気温による minimum の値にする（前の値。変わったときだけ書く）。型式ごとの `engine_idle_control_*` は表示用の minimum idle の N1 を返すだけにした。ENG n LOW IDLE（advisory 309〜312、新設）と >IDLE DISAGREE（223）の判定もあるが、アイドルの故障が無いので出ない。
- 読むもの：レバー（`laminar/B747/engine/throttle`）、`sim/flightmodel2/position/pressure_altitude`、TAT、IAS、パックのセレクタ、エンジン防氷弁（`antiice/nacelle/valve_pos`）、翼防氷弁（`antiice/wing/valve_pos`）、エンジン型式、PSEU（`gear/air_ground/pri_gnd`）、フラップレバー（`sim/cockpit2/controls/flap_ratio`、0・1・5・10・20・25・30 の等間隔）、CON（`button_switch/position[44]`）、貨物機（`freighter`）、逆推力の展開（`thrust_reverser_deploy_ratio`）、外気温、表示の N1・EPR（`display_N1`・`display_EPR`）と丸め前の N2。

### 4.10 エンジンの表示（2-3 段 3）

エンジンの表示のモデル（`plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_display_model.lua`）を、グルー `B747.40.xt.engine_display.lua` がエンジンのモジュールの `after_physics` で毎フレーム回す（`B747_engine_display()`）。中身は notes/ATA-70-80.md §3.2・§3.4・§4.9〜§4.11。

- EGT の色：表示の EGT（GE は `display_GE_EGT`、P&W・RR は `display_EGT`。値は EEC のモジュールが作る）を型式ごとの限界（CF6 は ATA70_80 p.395 の 750・925・960 ℃、P&W・RR は前のコードの値）と比べ、`laminar/B747/engines/EGT/white_on`・`amber_on`・`red_on`（新設）を書く。パネル（カスタム acf）の帯・枠・数字はこの 3 つで色を出す（前は P&W の赤と GE の全色がパネルの固定の閾値だった）。
- 琥珀の抑止：TO/GA スイッチ（エンジンのモジュールが置き換えている `sim/engines/TOGA_power`・`sim/autopilot/take_off_go_around`）を押してから 5 分は、琥珀の帯でも白（P&W・RR はエンジンが 1 基止まっていれば 10 分）。前は A/T の TOGA の保持（`TOGA_mode`）に連動し、帯の線も消していた。帯（`EGT/amber_inhibit`）はいつも出す。
- 始動限界の線：FUEL CONTROL が CUTOFF か、始動の途中（始動モデルの phase が off でない：`B747_engine_start_phase(i)`、始動のグルーが出す）なら `EGT/start_limit_on`（新設）を 1 にし、その間は EGT が始動限界で赤。始動はアイドルで落ち着いて終わる（始動モデル）。前はパネルが X-Plane の N2 55 % 未満で出していた。
- N1・N2・N3・EPR の赤と、超過の赤い枠：表示のモデルが N1・N2・N3 の赤線（`M.RPM_RED`）と P&W の EPR の最大（`display_EPR_max`、EEC の定格）から赤を決め、赤い枠のモデル（`B747.40.exceedance_model.lua`）が、限界に達した数字の枠（N1・EGT・N2・N3）を赤にして、戻っても赤のまま残す。EICAS の CANC・RCL（`CAS/canc_count`・`rcl_count` の増え方）で、数字が白の枠を白に、記録した超過の枠を赤に戻す。新しいフライトで消す。CF6 の N2 は 20 秒を超えると赤のまま。グルーが `engines/N1/red_on`・`N1/box_red`・`N2/red_on`・`N2/box_red`・`N3/red_on`・`N3/box_red`・`EGT/box_red`・`EPR/red_on`（新設、init `B747.40.engines`）を書き、パネル（カスタム acf）の数字・帯・枠はこれで色を出す（前はパネルの固定の値）。P&W の EPR の数字と枠は白のまま（FCOM p.833）。
- オイル：同じモデルが、X-Plane の油圧・油温（`sim/cockpit2/engine/indicators/oil_pressure_psi`・`oil_temperature_deg_C`）にエンジンごとの少しの差（読み込み時に決める）を足して `oil_press_psi`・`oil_temp_degC` に書く。油圧の赤（`EICAS2_oil_press_status`。パネルは赤い針）は赤線（P&W・RR は前の値の 70 psi、GE は N2 で 10〜35 psi）の下で、CUTOFF と始動の途中は白のまま（FCOM p.846）。ENG n OIL PRESS（advisory 317〜320、新設）は P&W・RR が赤線の下、GE が低圧スイッチ（10 psid で閉、15 psid で開。ATA70_80 p.522）。地上の CUTOFF と始動中は警報のモデルが隠す（FCOM p.1586-1587）。ENG n OIL TEMP（118〜121）は 160 ℃ 超。油量（`oil_qty_liters`）はタンクの量からエンジンに入った分を引き、エンジンごとの X-Plane の比（`oil_quantity_ratio`）を掛ける。GE は US quart で書く（FCOM p.848。dataref の名前は前のまま）。GE の琥珀の帯（油圧）とマゼンタ（油量の low・巡航中の差）は `oil_press_amber`・`oil_qty_magenta`（新設）に書き、パネル（カスタム acf）の数字と針がこれで色を出す。油圧の赤い数字は `EICAS2_oil_press_status` だけで出す。前の処理（乱数を足すだけ、赤は 70 psi 固定で CUTOFF でも赤、油量は全エンジンが X-Plane の 1 番の比）は外した。
- 振動：同じモデルが、音源（P&W・RR は N1・N2、GE は FAN・LPT・N2）ごとの値（読み込み時に決める 100 % での値 × 回転の 2 乗）から一番大きいものを `vibration` に書く。音源は `vib_source`（新設。0 BB、1 N1、2 N2、3 FAN、4 LPT）に書き、パネルが音源の文字の絵（BB の絵にそろえて作った N1・N2・FAN・LPT）を出す。エンジンの 3D の揺れ（`engine/vibration_position`）は前のまま、表示の振動から作る。火災で振動を 2〜3 にする前の処理（資料なし）は外した。
- X-Plane のスプール時間（`acf_spooltime_turbine`。全エンジンで 1 つ）は `B747_engine_spool_time()` が書く：地上でどれかのエンジンが始動中（`engines/start_valve_cmd` が 1 か、始動モデルの phase が off・aborted でない）なら 26 秒、それ以外は 5 秒（EEC の推力の制御を合わせた値）。前はエンジンの運転数で決めていた（4 基で 5 秒、0 基で 26 秒、その間は前の値。ENG-35）。
- 燃料投入の印（`fuel_on_indicator_status`）は FUEL CONTROL が CUTOFF で、火災スイッチを引いていないとき（ATA70_80 p.346）。二次エンジン表示（`dsp/synoptic_display` = 1）は、空中で FUEL CONTROL を CUTOFF にしたとき燃料のモジュールが出す（FCOM p.843、p.872。コマンドのハンドラーと、init スクリプトの `fuel/switch_target` の書き込みハンドラー）。
- 逆推力：逆推力のモデル（`B747.40.reverser_model.lua`）を、グルー `B747.40.xt.reverser.lua` が `B747_prop_mode()`（前からのレバーとコマンドの処理。X-Plane の prop mode 3 で展開、1 で格納）の直後に毎フレーム回す（`B747_reverser()`）。逆推力が動けるのは、P&W・RR は関係する油圧系統（エンジン n は系統 n、`hydraulics/pressure_n` が 1,000 psi 以上。RR は資料なし）、GE はそのエンジンが運転中（抽気）で、地上のとき（逆推力 1・4 は PSEU の primary、2・3 は alternate の継電器）。動けない逆推力は今の位置に保つ（格納なら prop mode 1 のまま、展開なら 3 のまま）。逆推力のコマンドは、`B747_reverser_can_deploy(i)` が真のエンジンにだけ prop mode 3 と逆推力スロットルを書く（X-Plane はフレームの間に書かれた値でも逆推力を動かし始めるため。全エンジンの保持は `throttle_jet_rev_ratio_all` でなくエンジンごとに書く）。ENG n REVERSER（advisory 126〜129）は、乗員が逆推力を求めている（`B747_reverse_asked(i)`：トグルのラッチ、保持中、全エンジンの保持は取り消しまで）のに格納のまま、または逆推力でないのに展開のままが 2 秒続くか、X-Plane の故障。前は X-Plane の故障だけだった。

### 4.11 パック、与圧、機器冷却、温度（3-1 段 1・2）

パックのモデル（`plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.pack_model.lua`）、与圧のモデル（`B747.55.press_model.lua`）、機器冷却のモデル（`B747.55.eqcool_model.lua`）、温度のモデル（`B747.55.temp_model.lua`）を、グルー `B747.55.xt.packs.lua`・`B747.55.xt.press.lua`・`B747.55.xt.eqcool.lua`・`B747.55.xt.temp.lua` が空調モジュールの `after_physics` で、抽気（§4.5）の次に毎フレーム回す（`B747_packs()`、`B747_press()`、`B747_eqcool()`、`B747_temp()`）。中身は notes/ATA-21.md §2.1〜§2.5・§4.1〜§4.6。グルーどうしは出力の表（`B747_pack_out`・`B747_press_out`・`B747_eqcool_out`。メタテーブル付き：§9a）と、前のフレームの値のグローバル（リリーフ弁、cruise clamp、OVRD で抜ける空気、客室が target か）で受け渡す。前の与圧（X-Plane の actuator に min(8,000 ft, 高度) を書く作り）、着陸高度（AUTO は 2,000 固定）、data block、CABIN ALTITUDE などのメッセージとパックの memo の処理は外した。

- X-Plane の与圧は上書きする：init スクリプト `B747.55.air` が `aircraft_load` で `sim/operation/override/override_pressurization` を 1、`aircraft_unload` で 0 にする（グルーも毎フレーム 1 を保つ）。グルーが `sim/cockpit/pressure/cabin_altitude_actual_ft`・`cabin_vvi_actual_fpm`・`cabin_pressure_differential_psi`・`outflow_valve`（0〜1）を書き、X-Plane の `sim/cockpit2/pressurization/indicators/cabin_altitude_ft`・`cabin_vvi_fpm`・`pressure_diffential_psi` はこれを映す（パネルの data block、照明のサイン、火災のモジュールはこちらを読む）。X-Plane のダクトと抽気の損失は抽気のグルーが書く（§4.5）。X-Plane の減圧の故障（`rel_depres_slow`・`fast`）は客室の漏れとして受ける。
- パック：選択器（`air/pack_ctrl/sel_dial_pos`）、ダクト圧（12 psi で弁が開く）、HI FLOW（[41]）、TRIM AIR（[37]）、RECIRC（[38]・[39]）、PACK RST（[42]）、貨物室火災 ARM（[84]・[85]）、与圧のモデルのリリーフ弁と cruise clamp、温度のモデルの「客室が target の 1 ℃ 以内」（cruise clamp の normal flow を最長 20 分待つ：ATA21 p.386）、PSEU、バスを読む。流量（high flow のパック 1 台＝1、normal は 2/3）は抽気のモデルが使う。書くもの（新設、init `B747.55.air`）：`air/pack/valve_pos[0-2]`、`pack/high_flow[0-2]`、`pack/ptc[0-2]`（0 なし、1 A、2 B）、`packs_operating`（EEC が推力の補正に読む。AIR-16）、`recirc_fan[0-3]`（上右・上左・下左・下右）、`light/pack_sys_fault`（照明が PACK RST の SYS FAULT 灯 [71] に使う）。EICAS：PACK CONTROL（advisory 251）、PACK 1〜3（252〜254）、memo の PACK n OFF・PACKS 1+2/1+3/2+3 OFF・PACKS OFF（18〜23、25）、PACKS HIGH FLOW（24）。
- 与圧：外気圧（`sim/weather/aircraft/barometer_current_pas`）、気圧高度（`sim/flightmodel2/position/pressure_altitude`）、機長の昇降計（`vvi_fpm_pilot`）、対地速度、PSEU の primary の空地、機長の高度計の規正値、FMC の巡航高度（`laminar/B747/autopilot/dist/cruise_alt`）と経路（`laminar/B747/fms/data` の `fltdep`・`fltdst`。標高と位置は X-Plane の `Custom Data/earth_aptmeta.dat`、無ければ `Resources/default data/earth_aptmeta.dat` から引く）、CABIN ALTITUDE パネル（LDG ALT の `landing_alt/button_pos` とノブ `land_alt_sel/rheostat`、AUTO SELECT、MAN L/R [34]・[35]、OPEN/CLOSE の toggle [22]）、DC bus 1・2（CPC A・B）と CPC の故障（`air/fail/cpc[0-1]`。X-Plane に無いので新設）、AC、main battery bus と APU hot battery bus（手動）、パックの流量を読む。客室はパックの空気と外流弁・漏れ・リリーフ弁の流れの収支で計算する（値は推定）。
- 書くもの：外流弁の計器 `air/outflow_valve_left/pos`・`right/pos`（−1 全閉〜+1 全開。前は客室の昇降率から作っていた）、`landing_altitude`、`pressurization/EICAS1_display_status`（data block）。新設（init `B747.55.air`）：`air/press/mode`（0 ground、1 takeoff、2 climb、3 cruise、4 descent、5 着陸後）、`press/cpc`（0 なし、1 A、2 B）、`press/relief_open`、`press/cruise_clamp`、`press/valve_man[0-1]`、`press/ldg_alt_shown`（data block の LDG ALT を出すとき 1。両 CPC 故障か両方 MAN で 0：FCOM p.586。カスタム acf のパネルが読む）。EICAS：CABIN ALTITUDE（warning 1）、CABIN ALT AUTO（caution 10）、LANDING ALT（advisory 240）、OUTFLOW VLV L・R（249・250）、PRESS RELIEF（258）、STATUS の CABIN ALT AUTO A・B（29・30）、OUTFLOW VLV L・R（31・32）、UPR・LWR PRESS RELIEF（33・34）、CPCS AIR/GND（35）。
- LDG ALT のノブ：3D のノブは dataref 1 につき 1° 回り、範囲は 0〜5,000。グルーは dataref の増え方を 50 ft の段として数え、範囲の端に近づいたら 1,800（5 周）ずらして戻す（ノブの見た目は変わらない）。MAN は AUTO の値から始める（推定）。
- フライトの開始：最初の 3 秒は、対地高度（`sim/flightmodel/position/y_agl`）が 50 ft 未満なら地上、以上なら巡航として客室を置き直し、モードを変えない（XTLua の最初の読み取りが 0、空地判定が遅れることがある）。空中開始では、機体が落ち着く（昇降率 1,000 fpm 未満、最長 60 秒）まで置き直す。パックの制御器の交代も最初の 3 秒は数えない。
- 機器冷却：EQUIP COOLING の選択器（`air/equip_cooling/sel_dial_pos`：0 STBY、1 NORM、2 OVRD）、PSEU、エンジンの運転、外気温（スキンの温度）、貨物室火災 ARM、与圧のモデルの ΔP（`B747_press_out`）、AC と main battery bus を読み、`air/equip_cooling/state`（ファンが運転で 1。前は NORM で 1 を書くだけで誰も読まない）と EQUIP COOLING（caution 27）を書く。OVRD で客室から抜ける空気は、与圧のモデルの外へ出る流れに足す。エンジン運転中の開始で EQUIP COOLING は NORM（空調モジュール）、TRIM AIR・UPR/LWR RECIRC は ON（manipulators）。
- 温度：PASS TEMP と FLT DECK TEMP のノブ（`air/pass_temp_ctrl/rheostat`・`flt_deck_temp_ctrl/rheostat`、0〜1 で 65〜85°F）、TRIM AIR（[37]）、ZONE RST（[36]、押した瞬間）、AFT CARGO HT（[40]）、AFT の貨物室火災 ARM（[85]）、パックのモデルの出力（流量・運転数・PTC・再循環ファン）、中央ダクトの圧、気圧高度・対地高度、PSEU、与圧のモデルの cruise clamp と descent、TAT（`sim/weather/aircraft/temperature_leadingedge_deg_c`。スキンの外の温度）、エンジンの運転と N2 表示、機器冷却の排気が前方貨物室へ出ているか、AC と DC を読む。7 ゾーンと前方・後方貨物室の温度を熱のつり合いで計算する（値は推定）。フライトの開始から 3 秒は、初期値（エンジン停止は外気温、エンジン運転中か空中は target、貨物室はつり合いの温度）を置き直す（XTLua の最初の読み取りが 0）。書くもの（新設、init `B747.55.air`、単位は ℃）：`air/temp/zone_actual[0-6]`・`zone_target[0-6]`（F/D、U/D、A〜E）、`temp/target_shown`（パック運転中で backup でないとき 1。synoptic の target の表示条件：FCOM p.577）、`temp/master`（PASS TEMP の設定値）、`temp/cargo[0-1]`（FWD、AFT）、`temp/pack_outlet`、`temp/trim_air_valve`（master trim air valve が開で 1）、`light/zone_sys_fault`・`light/aft_cargo_temp`（照明が ZONE SYS FAULT 灯 [69] と AFT CARGO の TEMP 灯 [70] に使う。前は TRIM AIR が off で 69 を点けるだけ、70 は常に 0）。EICAS：TEMP CARGO HEAT（advisory 284）、TEMP ZONE（287）、>TRIM AIR OFF（294）、STATUS ZONE TEMP（36、新設）。カスタム acf の ECS synoptic（3-1 段 3、ACF_DIFF.md §5）がこれらを ℃ で出し、パックの OFF/A/B を `pack/valve_pos`・`pack/ptc`、HI FLOW を `pack/high_flow`、外流弁の MAN/AUTO を `press/valve_man` で出す。

### 4.12 防氷・防雨（3-2）

防氷・防雨のモデル（`plugins/xtlua/scripts/B747.50.xt.antiice/B747.50.antiice_model.lua`）を、防氷のモジュール `B747.50.xt.antiice.lua`（グルーに書き直した）が `after_physics` で毎フレーム回す（`B747_antiice()`）。中身は notes/ATA-30.md §4・§10。前の処理（NAI・WAI の弁の開条件、X-Plane のコマンドでの切り替え、窓とピトーの加熱、>ICING と HEAT … の一部）は外した。ワイパーのコマンド、AI の quick start と `ice/init_CD`、`debug/antiice` は残した。

- 読むもの：`button_switch/position` [68–71] NAI、[72] WAI、[73–74] WINDOW HEAT L・R、ワイパーの選択器（`antiice/wndshlsd_wiper_L|R/sel_dial_pos`）、各エンジンの `air/engineN/bleed_air_psi`（抽気のモデルの PRV の下流の圧：§4.5）、`sim/flightmodel/engine/ENGN_running`、PSEU の `gear/air_ground/pri_gnd`（最初の 3 秒は対地高度 15 ft 未満を地上とする：XTLua の最初の読み取りが 0）、TAT（`sim/weather/aircraft/temperature_leadingedge_deg_c`）、X-Plane の ice の表示灯（`sim/cockpit2/annunciators/ice`）、X-Plane の防氷の故障（notes/ATA-30.md §10）、AC・DC bus 1〜4。
- 書くもの：`antiice/nacelle/valve_pos[0-3]`・`wing/valve_pos[0-1]`（EEC・抽気・ECS synoptic が読む）、新設の P5 の灯（init `B747.50.antiice`）`antiice/light/nai_valve[0-3]`・`light/wai_valve`・`light/window_inop[0-1]`（1 で点灯。照明が annunciator 60〜66 に出す）。X-Plane には、読んで違うときだけ書く：`sim/cockpit2/ice/ice_inlet_heat_on_per_engine`（NAI 弁が半分以上開）、`ice_surfce_heat_left_on`・`right_on`（WAI 弁。主 EICAS の NAI・WAI はこの 2 つを acf が見る）、`ice_window_heat_on_window[0-3]`（風防 L・R、側窓 L・R）、ピトー・静圧・AOA・TAT の加熱、`ice_detect_on`、`sim/cockpit2/switches/wiper_speed_switch[0-1]`（XP11 は `wiper_speed`）。前は `sim/ice/*` のコマンドで切り替えていた（主翼は左右共通で、片側だけ違うと毎フレーム入れ替わった：ICE-01）。
- EICAS：>ICING（caution 45）、>ANTI-ICE（advisory 7）、HEAT L AOA・L TAT・P/S CAPT・P/S F/O・P/S L AUX・P/S R AUX・R AOA・R TAT・WINDOW L・WINDOW R（186〜195）、>ICE DETECTORS（222）、NAI VALVE 1〜4（242〜245）、>NO ICING（247）、WAI VALVE LEFT・RIGHT（296・297）、STATUS ICE DETECTOR L・R（37・38、新設）。遅れ（3.5 秒、5 秒、15 秒、2 秒、12 秒）はモデルが持つ。
- ほかのモジュールの変更：エンジン始動のグルーは点火の条件の NAI を X-Plane の inlet heat からスイッチの位置に変えた（§4.8）。manipulators は ER 開始で WINDOW HEAT L・R を ON にする。

### 4.13 酸素（3-3）

新しいモジュール `B747.36.xt.oxygen`（`plugins/xtlua`）。init `B747.36.oxygen` が dataref とコマンドを作り、`aircraft_load` で X-Plane の `sim/operation/override/override_oxygen_system` を 1、`aircraft_unload` で 0 にする（グルーも毎フレーム 1 を保つ）。グルー `B747.36.xt.oxygen.lua` が酸素のモデル（`B747.36.oxygen_model.lua`）を `after_physics` で毎フレーム回す（`B747_oxygen()`）。中身は notes/ATA-35.md §4・§10。前は酸素の処理が何も無かった。

- 読むもの：客室高度（`sim/cockpit2/pressurization/indicators/cabin_altitude_ft`。与圧のモデルが X-Plane に書く値：§4.11）、前方貨物室の温度（`air/temp/cargo[0]`。ボンベの温度）、DC bus 1〜4、X-Plane の `sim/operation/failures/rel_pass_o2_on`（作動として受ける）、自分のスイッチとマスクの dataref。
- 書くもの（新設、init `B747.36.oxygen`）：`oxygen/crew_press_psi`・`pass_press_psi`（整数の psi。カスタム acf の STATUS ページが出す）、`oxygen/pass_oxy_on`・`therap_oxy_on`（照明のモジュールがサインに使う）。EICAS：>CREW OXY LOW（advisory 53）、PASS OXYGEN ON（256）、STATUS PASS OXYGEN ON（39、新設）、THERAP OXYGEN ON（memo 36）。X-Plane には、読んで違うときだけ `sim/cockpit2/oxygen/indicators/pilot_felt_altitude_ft`（低酸素の効果。マスクなしは客室高度、乗員マスクで 10,000 ft まで）、`o2_bottle_pressure_psi`、`sim/cockpit2/oxygen/actuators/o2_valve_on` を書く。
- 操作（3D に操作子が無いのでコマンド）：`oxygen/pass_oxy_sw_on`・`pass_oxy_sw_reset`（押している間、`pass_oxy_sw_pos` が 1・−1。ばねで 0 に戻る）、`therap_oxy_sw_up`・`therap_oxy_sw_dn`（`therap_oxy_sw_pos`：ON は保持、RESET は押している間）、`crew_masks_toggle`（`crew_mask_on`）。ばね戻りの位置は、コマンドの最後のイベントから 0.3 秒で 0 に戻す（XTLua は一瞬のコマンドの終わりを渡さないことがある：TESTING.md §4.6）。一瞬の押しでもモデルには 1 フレーム届く。
- ほかのモジュールの変更：照明のモジュールのサイン（NO SMOKING・FASTEN SEAT BELTS）に「乗客酸素が作動中なら選択器にかかわらず点灯」を足した（FCOM p.437、p.502）。

### 4.14 火災防護（3-4）

火災防護のモデル（`plugins/xtlua/scripts/B747.35.xt.fire/B747.35.fire_model.lua`）を、火災のモジュール `B747.35.xt.fire.lua`（グルーに書き直した）が `after_physics` で毎フレーム回す（`B747_fire()`）。中身は notes/ATA-26.md §4・§10・§11（段 1 はエンジンと APU、段 2 は貨物室・車輪格納部・ダクトリーク・煙・スクイブ試験）。コマンドの名前と、消火スイッチのアニメーションの dataref（`fire/engine0N/ext_switch/pos_arm`・`pos_disch`）、ボトルの圧（`fire/engine01_02A/ext_bottle/psi` など）、試験ボタン（`fire/fire_ovht/button_pos`）、AI の quick start と `fire/init_CD`、`debug/fire` は残した。前の処理（X-Plane の火災表示の素通し、ロックの無いスイッチ、回している間ずっと入る X-Plane の消火器）は外した。

- 読むもの：X-Plane の `sim/flightmodel2/engines/is_on_fire`（エンジン火災）と `sim/operation/failures/rel_apu_fire`（6 で APU 火災）、新しい失敗の dataref（init `B747.35.fire`）`fire/fail/eng_ovht[4]`・`fire/fail/loop_a[13]`・`fire/fail/loop_b[13]`（ゾーンの順：ENG 1–4 FIRE、ENG 1–4 OVHT、APU、CARGO 1–4）、FUEL CONTROL（`fuel/fuel_control/toggle_sw_pos`）、試験ボタン、PSEU（最初の 3 秒は対地高度）、APU の N1、APU battery bus（検知）と main hot battery bus（解錠と squib）。
- 書くもの：消火スイッチのアニメーション、ボトルの圧、新設（init `B747.35.fire`）の `fire/apu/ext_bottle/psi`、`fire/apu/ext_switch/pos_arm`・`pos_disch`、`fire/apu_shutdown`（APU のグルー `B747.03.xt.apu.lua` が APU の停止に使う。前は X-Plane の APU 火災の故障を直接読んでいた）、`fire/apu_horn`、`fire/light/btl_disch[5]`（L ENG A・B、R ENG A・B、APU。照明が annunciator 113–117 に出す）、消火スイッチと APU の灯 `annunciators/engine_fires[0-4]`、X-Plane の `sim/cockpit2/engine/actuators/fire_extinguisher_on`（剤が出ている間だけ）と、APU ボトルの放出で `rel_apu_fire` を 0。EICAS：FIRE APU（warning 8）、FIRE ENG 1–4（11–14）、>FIRE TEST FAIL・PASS（19・20）、>TEST IN PROG（24）、OVHT ENG 1–4 NAC（caution 79–82、新設）、>BOTTLE LOW APU（advisory 44）、>BTL LO L ENG A・B（47・48、名前を直した）・R ENG A・B（321・322、新設）、>DET FIRE APU（58）、>DET FIRE/OHT 1–4（59–62）、STATUS 40–63（新設）。STATUS の配列は 64 から 128 に広げた（init `B747.87.warning02.lua`）。
- 操作：3D の消火スイッチは前と同じコマンド（`ext_switch_arm` で引く・押し戻す、`ext_switch_A`・`_B` で回す）。新しいコマンド（3D に操作子が無い）：`fire/engine0N/ext_switch_override`（Fire Override を押して引く）、`fire/apu/ext_switch_arm`・`ext_switch_rotate_L`・`ext_switch_rotate_R`・`ext_switch_override`。コマンドは 1 フレームの入力としてモデルへ渡す。
- 段 2 で読むもの：失敗の dataref `fire/fail/cargo_smoke[4]`・`fail/wheel_well`・`fail/duct_leak[3]`・`fail/lav_smoke`・`fail/rest_smoke`（init `B747.35.fire`）、CARGO FIRE ARM FWD・AFT・DISCH（`button_switch/position[84–86]`。空調も ARM を読む：§4.11）、中央ダクトの圧（`air/duct_pressure_C`。貨物の検知器の venturi）、エンジンの運転、AC bus 2・DC bus 2・main battery bus、スクイブ試験のボタン（新しいコマンド `fire/squib_test_1`・`_2` と `fire/squib_test/button_pos[2]`）。書くもの：`fire/light/cargo[3]`（FWD、AFT、DISCH。照明が annunciator 35–37 に）、`fire/light/squib[9]`（照明が annunciator 95–103 に）、`fire/cargo/ext_bottle/psi[4]`、剤が出た区画の `fail/cargo_smoke` を 0。EICAS：FIRE CARGO AFT・FWD（warning 9・10）、FIRE WHEEL WELL（21）、BLD DUCT LEAK C・L・R（caution 6–8）、SMOKE DR 5 REST（52）、>CARGO DET AIR（advisory 49）、>CGO BTL DISCH（51）、>SMOKE LAVATORY（264）、STATUS 64–80。
- 引いた消火スイッチの他系統への作用は、各系統のモジュールが `pos_arm` > 0.5 で読む（エンジン始動のモデル、燃料、抽気、油圧、電源のグルー `B747.03.xt.elec_buses.lua`。電源のモデルの GCR はラッチ式で、GEN CONT の OFF→ON で戻る）。

## 5. 表示系（PFD・ND・EICAS・CDU）

- 描画は、各 acf の末尾（`P` 行の後ろ）に埋め込まれた X-Plane の generic instrument で行う。数は 2850 個で、内訳は rotary 1164、text 709、pointer 293、needle 122、tape 85、rolling 24。
  - パネルのテクスチャ `cockpit_3d/-PANELS-/panel.png` に描き、3D コクピットの画面に貼る。
  - 画像は `cockpit_3d/generic/`（CRT Displays 1014 枚、EFIS、FMS Displays、Clocks、Radios）。
- 計器が読む laminar 系の dataref は、`DATAREF` 行と表示条件（`SHOW_EQUAL` 1622 か所、`SHOW_GREATER` 1700 か所、`SHOW_LESS` 1102 か所）を合わせて 1008 個（重複を除く）。`DATAREF` 行では ND が 1005 か所、engines が 281、CAS が 89、gear が 87 など。
- synoptic の色や状態は、表示条件として acf に直接書かれていることが多い（例：燃料量が 900 kg 未満で amber）。故障による表示の変化が出せないときは、パネルを直す必要がある場合がある。
- データを作る側：
  - PFD・EICAS の数値は主に `B747.60.xt.fltInst02`。
  - エンジン計器は `B747.40.xt.engines`・`B747.42.xt.EEC`。
  - EICAS メッセージは `B747.87.xt.warning`。表示行は `CAS/gen_*_msg_NNN` に文字列で出す。
  - ND は `xtlua_nd`（地図）と `fltInst02`（モード・レンジ）。
  - CDU は `B747.68.xt.fms` が `laminar/B747/fms1〜3/*` に行の文字列を出す。
- **制約**：表示の定義は acf の中にある。純正 acf は変えないので、表示を直すときは dataref の値で直すのが基本になる。計器の追加や変更はカスタム acf にしかできず、見た目に関わるので承認が要る。カスタム acf と純正 acf のパネル定義は、ADF の方位針 2 個の参照 index を除いて同じ。

## 6. FMC

- CDU は 3 台：`fms1`（左）、`fms2`（右）、`fms3`（中央）。キーはコマンド（例：`laminar/B747/fms1/ls_key/L1`、`.../func_key/legs`、`.../alphanum_key/A`）で、ループで作る。
- ページ：
  - `B744.fms.pages.lua`：共通部と多くのページ
  - `activepages/*.lua`：動くページ（PERF INIT、POS INIT、TAKEOFF、THRUST LIM、PROGRESS、VNAV、DOORS、EFIS/EICAS CTL、地上作業、乗客・貨物、ATC/CPDLC など）
  - `refonly/*.lua`：見た目だけのページ（`***` の雛形。REF NAV DATA、NAV RAD、DEP/ARR、HOLD、FIX など）
- `B744.createfms.lua` が CDU を作り、`B747.68.xt.fms.lua` がページ遷移・入力・データ（`getFMSData`）を扱う。
- ACARS/CPDLC：`acars/*`（AutoATC と Hoppie の provider）。
- IRS：`irs/irs_system.lua`（アライン、位置）。`irs/rnav_system.lua`。
- ルート・航法：X-Plane の FMS（`xtlua/fms`）。LNAV のポイント切り替えは autopilot 側（`override_fms_advance`）。VNAV は `B744.fms.pages.vnav*.lua` と `B747.70.xt.autopilot.vnav*`。

## 7. エンジン型式

- 機体設定 `engines` の選択肢：PW4056 / PW4060 / PW4062、CF6-80C2-B1F / B5F / B1F1、RB211-524G / H / H8T。既定は PW4056。
- thrust ref は PW と RR が EPR、GE が N1。
- `laminar/B747/engines/type`：0=PW、1=GE（CF6）、2=RR。表示の切替用に `hidePW`・`hideGE`・`hideRR` もある。
- 設定はリバリーフォルダの `B747-400_simconfig.dat` に保存する。リバリーごとにエンジン型式が変わりうる。
- EEC は型式別のファイル（`B747.42.xt.EEC.{PW,GE,RR}.lua`）。
- 資料との対応：
  - PW：FCOM、LH24、LH36 がある。
  - CF6：FCOM、ATA70_80 がある。
  - RR：資料が無い。
- カスタム acf のエンジンモデル（`NEW_engines`）は PW と GE だけ。RR を選ぶと外部モデルにエンジンが出ない（ACF_DIFF.md）。

## 8. その他

- サウンド：`fmod/747-400.snd` と bank 群（FMOD）、`sounds/alert/*.wav`（コールアウトなど）。
- `documentation/`：`LNAV.VNAV.md`、試験飛行の手順と解析スクリプト（R）、FMC ページのテキスト（`fms pages/`）など。
- `build.sh`：リリース zip の作成。`add.sh`：版数を書いて README.pdf を作る。`test.lua`：作者の試し書き。

## 9a. 新しいコードの書き方（PLAN.md の R-2）

作り直す系統のコードは、次の取り決めで書く。XTLua の `init.lua`（4 つのプラグインで同じ）を読んで決めた。

- **ロジックとグルーを分ける**：
  - 系統の論理は、X-Plane に触らない純粋なモジュール（`<系統>.model.lua` など）に置く。入力の表と経過時間 dt を受け取り、状態と出力の表を返す形にする。
  - dataref とコマンドとの受け渡しは、xt スクリプト（グルー）だけが行う。
  - こうすると、モジュールは LuaJIT の回帰試験（`tests/<系統>/`）で X-Plane なしに試せる。グルーを含むモジュール全体も、`tests/lib/xtlua.lua` で X-Plane なしに回せる（TESTING.md §3）。
- **モジュールの読み込み**：
  - XTLua の `dofile`（`get_run_file_in_namespace`）は、読んだチャンクの戻り値を捨てる。
  - そこでモジュールは、表をスクリプトの名前空間のグローバルに置き（例：`B747_elec_model = M`）、同時に `return M` もする。
  - xt スクリプトはグローバルから使い、試験は `dofile` の戻り値を使う。
- **グローバルの表には必ずメタテーブルを付ける**（`local M = setmetatable({}, {})`）。
  - XTLua の名前空間（`namespace_write`）は、メタテーブルの無い表を代入すると、その時点の中身を別の表にコピーする。
  - そのため、あとで元の表を書き換えても反映されない。コピーの側で無いキーを読むと、`parent` を探す処理が自分を呼び続けてスタックが溢れる（旧フォークで計器・FMC・AP が止まった原因）。
  - コピーの側の `#`・`ipairs`・`pairs` は `__len` などのメタメソッドに頼る。手元の LuaJIT 2.1（回帰試験）はこれを無視して 0 件になる。XTLua の LuaJIT 2.1.0-beta3 がどうかは確かめていない。どちらでも同じに動くよう、新しいコードはコピーされた表を数えたり回したりしない。
  - ファイルの `local` の表を、`dofile` した別のチャンク（グルー）に渡すときは、メタテーブル付きの表に入れてグローバルに置く（例：`B747_alert_messages`）。
  - モデルの出力の表（`s.out`）をグルーどうしで渡すときも同じで、メタテーブルを付けてから置く（`B747_pack_out = setmetatable(pack_state.out, {})`）。コピーされると、数と真偽の項目は代入した時点の値で止まる（中の表は同じものを指すので、そちらは動く）。3-1 段 1 の機器冷却は、与圧のモデルの ΔP をこのコピーから読んで 0 のままだった（2026-10-24 に直した。`tests/air/air_module_test.lua` が名前空間の表を確かめる）。
- **dataref**：
  - 新しい公開 dataref は init スクリプト（`init/scripts/<モジュール>/`）で作る。xt スクリプトの `deferred_dataref` は探すだけで、作らない。`tests/static/xt_bindings_created_test.lua` がこれを検査する。
  - 名前は既存の名前空間（`laminar/B747/<系統>/…`）に置く。INTERFACES.tsv の名前と意味は変えない（`tests/static/interfaces_test.lua`）。
  - 判定に使う dataref は毎フレーム読む（最初の読みが 0 になる問題への対策。TESTING.md §1.2）。
  - 書いた値は X-Plane に非同期で反映されるので、同じフレームで読み直して判定しない。
  - X-Plane 自身の dataref（`sim/…`）に書くときは、毎フレーム読んでから、違うときだけ書く。XTLua は前に書いた値と同じ値を X-Plane に渡さないので、X-Plane が自分で値を変えた後（フライトの読み込みなど）は、読まない限り直らない（XTLua の xpmtdatarefs.cpp。TESTING.md §1.2）。
- **時間**：経過時間は dt として受け取り、フレームレートに頼らない（例：「1 フレームに 0.005 動かす」は使わない）。

## 9. 開発・試験の環境（2026-10-23 時点）

- Lua の構文チェックと回帰試験：LuaJIT 2.1 を用意した（PLAN の T-1。TESTING.md §3・§6）。
- FlyWithLua：NG+ 2.8.19 が導入済み。`Scripts/` に飛行試験の記録スクリプトを置いた（TESTING.md §4）。
- 試験の仕組み（旧フォークの試験 `tests_old/`、新しい回帰試験、飛行試験キット）：TESTING.md。
- X-Plane の Web API（localhost:8086）：飛行試験キットで使っている（TESTING.md §4。気をつけることは §4.6）。公式の説明（https://developer.x-plane.com/article/x-plane-web-api/ 、2026-10-23 確認）の要点：
  - X-Plane 12.4.0 以降は v3 が使える。REST は `http://localhost:8086/api/v3/…`、WebSocket は `ws://localhost:8086/api/v3`。`GET /api/capabilities` で対応版を確かめられる。
  - dataref：`GET /datarefs`（`filter[name]` で名前から ID を引く）、`GET /datarefs/{id}/value`、`PATCH /datarefs/{id}/value`（本体は `{"data": 値}`。配列の要素は `index` で指定）。
  - コマンド：`POST /command/{id}/activate`（本体は `{"duration": 秒}`、0 は押してすぐ離す）。
  - フライト：`POST /flight` で開始、`PATCH /flight` で更新（v3）。
  - 設定の Network タブで「Disable Incoming Traffic」が入っていると、すべて 403 になる。
  - 旧フォークでは、XTLua が作った double 型の dataref に Web API で小数を書くと HTTP 400 で拒否された（OLD_FORK_NOTES.md §14）。
- PDF のテキスト化には、Git for Windows 同梱の xpdf `pdftotext` 4.06 を使った。Python は入っていない。
