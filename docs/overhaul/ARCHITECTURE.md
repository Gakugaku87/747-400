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
| `plugins/b747_fms_bridge` | C（MinGW-w64、Windows の `64/win.xpl`） | FMC の計画・現用点・表示中の点を X-Plane の FMS に、X-Plane のスレッドで（`laminar/B747/fms/xp/*`。2026-10-27：notes/ATA-34-61-FMC.md §23） |
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
| xtlua | B747.34.nav | 72 / 921 | 航法センサー。5-1 で新設（§4.17）。段 1 はエアデータ（ADC 3 台、AIR DATA の選択、OVERSPEED・DISAGREE・高度警報）、段 2 は IRS（アライン、位置の入力、ATT、電源、メッセージ）、段 4 は電波高度計と GPWS、段 5 はトランスポンダと TCAS、段 5c は気象レーダーの操作 | |
| xtlua | B747.35.fire | 99 / 653 | 火災探知と消火（エンジン、APU、貨物室） | |
| xtlua | B747.36.oxygen | 56 / 327 | 酸素（乗員・乗客・治療用、酸素圧、X-Plane の低酸素）。3-3 で新設（§4.13） | oxygen_system |
| xtlua | B747.40.engines | 106 / 2247 | エンジン始動・点火・燃料制御・逆推力・APU | |
| xtlua | B747.42.EEC | 67 / 4376 | EEC と推力制御。型式別の `EEC.PW` / `EEC.GE` / `EEC.RR`、表（`EEC.tbls`）、`pid.lua` | throttles |
| xtlua | B747.45.fltCtrls | 187 / 1370 | 操縦系統（フラップ、スポイラー・スピードブレーキ、トリム、代替フラップ）。4-1 段 1 でフラップの FCU のモデル（§4.15） | |
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
| xtlua_keysystems | B747.60.fltInst | 459 / 4716 | 飛行計器。`fltInst02` が PFD・EICAS・ND 補助、`03` が両席の時計（5-2 段 6a で `B747.60.clock_model.lua` のグルーに。`04` は畳み込んで削除）。表示器と EIU は 5-2 段 1 で `B747.60.display_model.lua`・`B747.60.xt.displays.lua`（§4.18） | |
| xtlua_keysystems | B747.68.fms | 199 / 13196 | FMC/CDU（3 台、詳細は §6） | |
| xtlua_keysystems | B747.70.autopilot | 274 / 5449 | AFDS（MCP、FMA、LNAV/VNAV）、autothrottle、監視（`monitor`。autoland は AFDS のモデル：段 4。前の `B747.autoland` は段 4c で外した） | throttles、fms_advance |
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
- P&W の表示の EPR（EEC と A/T が合わせる値）：EPR のモデル（`B747.42.epr_model.lua`、2026-10-30、ENG-33）が、1 発の推力・大気圧（`sim/weather/aircraft/barometer_current_pas`）・Mach（`sim/flightmodel/misc/machno`）から出す。`B747.42.xt.EEC.PW.lua` の `EPR_display_PW` が呼ぶ。N1・N2・EGT は前の式。
- RR は資料が無いので、前の推力の論理のまま。
- ALTN：EEC MODE スイッチ（`button_switch/position` [7]〜[10]、0 = ALTN）でそのエンジンを代替モードにする（EEC の故障が無いので自動の移行は無い）。指令は最大定格で頭打ちせず、その高度で一番大きい定格（表の角の値、抽気の補正なし）までレバーに比例する（全開で overboost がありうる）。ENG n EEC MODE（advisory 313〜316）、>ENG n LIM PROT（caution 75〜78）。代替モードに入ると A/T を切り（`engines/autothrottle_fail` = 1、`autothrottle_active` = 0）、GE は混在中、P&W はどれかが代替の間、A/T を使えなくする（`EEC_status` = 1 で `throttle_management` の A/T のモードを止める）。前の「ALTN にすると A/T を切るだけ」の処理は外した。ALTN の灯は照明モジュールのまま（スイッチの位置）。
- アイドル：エンジンごとに approach idle を選び（空中でそのエンジンの防氷、着陸フラップ、405・570 の CON、GE の逆推力。条件が終わって 5 秒・接地 5 秒後に minimum）、X-Plane のアイドル（`sim/aircraft2/engine/high_idle_ratio`、全エンジンで 1 つ）を、モデルの `M.idle_ratio` の値にする（変わったときだけ書く。2026-10-30 に X-Plane で測って決めた：空中の minimum は気圧高度ごとの表で FCOM の降下に合わせ、地上は 1.07、approach は空中の minimum ＋ 0.5。notes/AERO.md §3.7）。型式ごとの `engine_idle_control_*` は表示用の minimum idle の N1 を返すだけにした。ENG n LOW IDLE（advisory 309〜312、新設）と >IDLE DISAGREE（223）の判定もあるが、アイドルの故障が無いので出ない。
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

### 4.15 操縦系統（4-1）

段 1：フラップの FCU のモデル（`plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.fcu_model.lua`）を、グルー `B747.45.xt.fcu.lua`（`B747.45.xt.fltCtrls.lua` が読み、`after_physics` で `B747_fcu()`）が毎フレーム回す。中身は notes/ATA-27.md §4.3・§4.4・§10。後縁の位置は度（フラップ 25 は 22°。前と同じで、3D の `flt_ctrls/flaps` もこの角度）。

- 読むもの：フラップレバー（`sim/cockpit2/controls/flap_ratio`。スナップは前のまま fltCtrls）、油圧系統 1・4（`hydraulics/pressure_1`・`_4`）、ダクト圧 L・R、AC・DC の bus、機長の対気速度、ALTN FLAPS ARM（`button_switch/position[0]`）と選択器（`flt_ctrls/alt_flaps/sel_dial_pos`：−1 RET、0 OFF、+1 EXT）、PSEU の primary の空地、X-Plane の `prop_mode`（3 で逆推力）、脚の動作（`deploy_ratio`）、故障（新設、init `B747.45.fltCtrls`）`flt_ctrls/fail/fcu[3]`・`fail/te_primary[2]`・`te_secondary[2]`・`te_stuck[2]`・`le_primary[3]`・`le_secondary[3]` と X-Plane の `rel_flap_act`（後縁の油圧駆動）。開始から 3 秒はフラップをレバーの位置に置き直す（滑走路からの開始はレバー 10）。
- 書くもの（新設、init `B747.45.fltCtrls`）：`flt_ctrls/fcu/te_deg[4]`（L OB、L IB、R IB、R OB）・`fcu/slat[2]`（group A、B）・`fcu/le[6]`（各群の左右）・`fcu/te_mode[2]`・`fcu/le_mode[3]`（0 主、1 副、2 停止）・`fcu/te_moving`・`fcu/te_down`。前からの名前：`cablecontrols/flap_ratio`（FCU の指令。レバーの detent か荷重軽減の detent を 1/6 刻みで。エンジン・燃料・AFDS・FDR が読む）、`gauges/indicators/flap_deployed_ratio`・`1–4`、`flt_ctrls/flap/transition_status`、`flaps/EICAS1_display_status`（0 なし、1 通常、2 拡大）。EICAS：FLAPS CONTROL（caution 28）、FLAPS DRIVE（29）、FLAPS PRIMARY（30）、>FLAP RELIEF（advisory 142）、STATUS の TE FLAPS（81）、LE SINGLE DRIVE（82）、LE MULT DRIVE（83）、FLAP CONTROL L/C/R（84–86）、FLAP LOAD RELIEF（87）。
- 段 2a：SRM のモデル（`B747.45.srm_model.lua`）を、グルー `B747.45.xt.srm.lua` が FCU の次に回す（`B747_srm()`）。読むもの：機長・副操縦士の対気速度（`gauges/indicators/airspeed_kts_pilot`・`_copilot`）と Mach、X-Plane の ADC の故障（`rel_adc_comp`）、FCU の前縁（`fcu/le[0–3]`：group A）と FCU の故障、PSEU、AP の `autopilot/autoland`（1 で autoland）、故障（新設、init `B747.45.fltCtrls`）`flt_ctrls/fail/srm[2]`・`fail/lockout_actuator`・`fail/rrc[2]`。書くもの：`flt_ctrls/left_outer_aileron_lockout`（1 解除〜0 ロック）・`right_outer_aileron_lockout`（その負）、`rudder_ratio_upr`・`rudder_ratio_lwr`（新設、init `B747.19.hydraulicsmodel`。1 が 32°）と `rudder_ratio`（下の値）。どれも油圧のモジュールの controlObject の行の scaledref。EICAS：AILERON LOCKOUT（advisory 3）、RUD RATIO DUAL（261）・SNGL（262）、STATUS の AILERON LOCKOUT（88）、RUDDER RATIO（89）。油圧のモジュールはペダル（X-Plane の `yoke_heading_ratio`。`total_heading_ratio` は空中でトリムの 0.3 倍を含むので使わない）とラダートリムの和 `flt_ctrls/rudder_input`（−1〜1、トリムは 0.8 倍）を毎フレーム書き、controlObject の行がそれに上下の比をかける。
- 段 2b：同じモデルとグルーに安定板トリムを足した（中身は notes/ATA-27.md §4.5・§12）。読むもの：操縦輪のスイッチ（3D の `flt_ctrls/stab_trim_up/dn_capt`・`_fo`。機長側は X-Plane の `sim/flight_controls/pitch_trim_up/down` も押し続け、`.snd` のクリック音はそれで鳴る。X-Plane の `pitch_trim_up/down` は置き換えて機長のスイッチとして受ける）、ALTN（新設のコマンド `flt_ctrls/altn_stab_trim_up/dn` と dataref `flt_ctrls/stab_trim/altn_sw`：−1 機首下げ、0、1 機首上げ）、cutout スイッチ（新設のコマンド `flt_ctrls/stab_trim/cutout_2_up/dn`・`cutout_3_up/dn` と dataref `stab_trim/cutout_sw[2]`：[0] が 2、[1] が 3、−1 CUTOUT、0 AUTO、1 ON。3D に操作子が無い）、油圧系統 2・3、DC 2・3・電池バス・standby バス、ALL GR DN、FCU の前縁、操縦桿（`yoke_pitch_ratio`）、A/P の CMD L・C・R、FCC のトリム指令 `flt_ctrls/stab_trim/autotrim_cmd`（−1/0/1）と `stab_trim/frat`（新設、init `B747.19.hydraulicsmodel`。AFDS の `B747.19.xt.afds_control.lua` が書く）、故障（新設、init `B747.45.fltCtrls`）`flt_ctrls/fail/stab_actuator[2]`（[0] 系統 2、[1] 系統 3 の STCM が動かない）・`fail/stab_runaway[2]`（−1/1 で暴走）と X-Plane の `rel_trim_elv`（両 STCM）・`rel_elv_trim_run`（系統 3 の STCM が機首上げへ：推定）。書くもの：X-Plane の `sim/flightmodel2/controls/elevator_trim`（−1..1 が 0–15 units。安定板の角度は油圧のモジュールの controlObject がこれから作る）、`flt_ctrls/stab_trim/units`（新設、0–15）。フライトの開始から 3 秒と、グルーが書いた値でない X-Plane のトリムの変化は、モデルの位置を合わせる（直前 2 回の書き込みと比べる。X-Plane の暴走の故障の間は合わせず書き戻す）。EICAS：STAB TRIM UNSCHD（caution 60）、>STAB TRIM 2・3（advisory 274・275）、STATUS の STAB TRIM（90）・STAB TRIM UNSCHD（91）・STAB AUTO TRIM（92）。A/P 1 台で操縦輪のスイッチを使うと、新設のコマンド `autopilot/trim_disengage`（autopilot のモジュール。AUTOPILOT DISC を出す）を 1 回呼ぶ。
- 段 2c：SRM のモデルに speed trim を足した。書くもの：`flt_ctrls/stab_trim/speed_trim`（新設、init `B747.45.fltCtrls`。1 で engage）、STATUS STAB SPEED TRIM（93）。グリーンバンドのモデル（`B747.45.greenband_model.lua`）を fltCtrls のモジュールが読み、FMC の離陸トリム（`fmc/elevator_trim`）から帯を選んで、指示器の帯（`flt_ctrls/elevator_trim/mid/indicator`：3D の帯の中心が 0〜1 で 3.81〜8.12 units）を書き、CONFIG STAB（warning 7）の帯に使う。PSEU の GND と V1（`airspeed/V1`、999 は未設定）を読む。
- 段 3：スピードブレーキのモデル（`B747.45.speedbrake_model.lua`）を、グルー `B747.45.xt.speedbrake.lua`（fltCtrls のモジュールが読み、毎フレーム `B747_speedbrake()`）が回す。中身は notes/ATA-27.md §4.2・§14。読むもの：レバー（`flt_ctrls/speedbrake_lever`。3D とコマンドが書き、init の handler が detent にスナップする）、推力レバー（プラグインのレバー `engine/throttle` × 50°。3D と EEC と同じで、X-Plane の `throttle_ratio` はレバーが従う入力なので読まない）と `prop_mode`（3 が逆推力）、油圧系統 1・4、PSEU の primary（FCU のグルーと同じ）と alternate の地上、DC bus 1、機長の電波高度、FCU の後縁角、故障 `flt_ctrls/fail/auto_speedbrake`（新設、init `B747.45.fltCtrls`）。書くもの：アクチュエータが動かしている間のレバーと `B747DR/speedbrake/auto_extend`（1 の間は init の handler がスナップしない）、X-Plane の `sim/cockpit2/controls/speedbrake_ratio`（レバーから。−0.5 は書かない）、>SPEEDBRAKES EXT（caution 59）・SPEEDBRAKE AUTO（advisory 272）・SPEEDBRAKE ARMED（memo 45）・STATUS SPEEDBRAKE AUTO（94）。X-Plane の比が外から変わったら（スピードブレーキの軸）、レバーをそれに合わせる。init の handler は X-Plane の比も memo も書かなくなった。fltCtrls の前の同期（`B747_speedbrake_sync`）・逆推力の処理・>SPEEDBRAKES EXT は外し、空中の CONFIG SPOILERS は貨物機（`laminar/B747/freighter`）だけにした（`flt_ctrls/numLeverClimb` は上昇定格のレバー角 35° 以上の本数）。CONFIG GEAR の推力レバーもプラグインのレバーを読む。
- 段 4：横操縦のモデル（`plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.lateral_model.lua`）を、油圧のモジュール（keysystems）の `B747.19.xt.hydraulics_override.lua` が `pressure_input()` で回す（中身は notes/ATA-27.md §4.1・§4.2・§15）。controlObject は操縦輪の角度だけを `cablecontrols/wheel`（新設、init `B747.19.hydraulicsmodel`。度、右翼下げが正、`custom_roll_ratio` × 90）に出す。`custom_roll_ratio` は操縦輪・A/P・エルロントリム（0.5222 倍）の和で前のまま。グルーはエルロンのプログラマ（外側はロックアウトの値をかける）・スポイラーの横操縦とミキサー・スピードブレーキの段（レバー `flt_ctrls/speedbrake_lever` を find_dataref で読む）から指令を作り、前と同じ圧の門と速さを通して `flt_ctrls/l|r_aileron_inner|outer`・`flt_ctrls/spoilers[1–12]`（3D・パネルの名前のまま）と X-Plane の面に書く。X-Plane の面に `wing2l/r_spo1def`（スポイラー 4・9）と `speedbrake1_deg[0]`・`[1]`（6・7）を足した。前のケーブルの値（`cablecontrols/*_aileron`・`spoiler1–12`・`speedbrake12/34/58/67`）と controlObject の行 33 本は外した（どこからも読まれていなかった）。試験のモック（`tests/lib/xtlua.lua`）は controlObject の行を記録し、`rt:apply_control_objects()` で XTLua と同じ規則で回せる（呼んだ試験だけ）。
- 段 4 の後半：FLT CONTROL HYD POWER の遮断弁を油圧のモジュールのグルー `B747.19.xt.hydraulics_override.lua` に足した（`B747_fcsov()` を `pressure_input()` の最初に回す。中身は notes/ATA-27.md §16）。新設（init `B747.19.hydraulicsmodel`）：`flt_ctrls/hyd_power/wing_shut`・`tail_shut`（array[4]、1 が SHUT OFF）、`hyd_power/wing_valve_shut`・`tail_valve_shut`（array[4]、0 が全開）、コマンド `flt_ctrls/hyd_power/wing_1`〜`wing_4`・`tail_1`〜`tail_4`。舵面の圧の門は、系統の表（前は呼ぶたびに作っていた）を毎フレーム弁で絞った表 `fcsov_src` を使う。照明のモジュールは弁から VALVE CLOSED（`annunciator/brightness_ratio[80–87]`）、グルーが >FLT CONT VLVS（advisory 143）。ヨーダンパー：fltCtrls の `B747_yaw_damper()` がスイッチ・電源（`electrical/bus/stby_main`・`bat_main`・`bus/ac[0]`・`bus/dc[0]`）・IRU（`flt_mgmt/iru/status` と選択器）・故障 `flt_ctrls/fail/yaw_damper`（新設、init `B747.45.fltCtrls`、array[2]）から `flt_ctrls/yaw_damper_upr_on`・`lwr_on`（前からの名前）を作る。`B747.19.xt.yaw_damper.lua` は作動筒の油圧（`B747_fcsov_yaw_damper_hyd(n)`：系統 n と尾翼の弁）も見る。
- AFDS（`B747.19.xt.afds_control.lua`）はオートトリムの指令を出すだけにした（前は X-Plane のトリムを直接、1.2 秒に 1 フレーム分書いていた）。A/P が外れているときは A/P の昇降舵・補助翼の指令（`flt_ctrls/sim_pitch_ratio`・`sim_roll_ratio`）を毎秒 1 で 0 に戻す（`B747.19.xt.hydraulics_override.lua` が A/P の off の間も書く）。
- 油圧のモジュール（keysystems）は `fcu/te_deg` を `flt_ctrls/flaps[1–4]` と X-Plane の舵面（`wing1l/r_fla1def`、`wing3l/r_fla2def`、それに外側フラップの wing 2 の部分 `wing2l/r_fla2def`）に、`fcu/slat` を `slat1/2_deploy_ratio` に書くだけ。前の controlObject のフラップと表示の 36 行、900 psi の門と 0.667°/s の動き、`normal_slats` は外した。デマンドポンプは `fcu/te_moving`・`te_down` を読む（§4.4）。

### 4.16 脚（4-2）

段 1：脚の作動のモデル（`plugins/xtlua/scripts/B747.10.xt.gear/B747.10.gear_model.lua`）を、グルー `B747.10.xt.gear_act.lua`（脚のモジュール `B747.10.xt.gear.lua` が PSEU のグルーの次に読み、`after_physics` で PSEU とレバーのロックの次に `B747_gear_act()`）が回す。中身は notes/ATA-32.md §10。

- 読むもの：レバー（`actuator/gear_handle`、0 DN・1 OFF・2 UP の近い方）、系統 1・4（`hydraulics/pressure_1`・`_4`）、AC・DC bus 1〜4、ALTN GEAR EXTEND（`button_switch/position` [1] NOSE/BODY、[2] WING）、PSEU の air mode（`pri_air`・`alt_air`）、各脚の接地（`sim/flightmodel2/gear/on_ground`）とトラックの角度、故障（`gear/fail/*`、X-Plane の `rel_lagear1`〜`5`・`rel_gear_act`・`rel_gear_ind`）。
- 書くもの（新設、init `B747.10.gear`。配列は前脚、左胴体、右胴体、左翼、右翼の順）：`gear/position[5]`（0 UP でロック〜1 DN でロック）・`gear/door[5]`（0 閉〜1 開）・`gear/gear_position/annun_gear[5]`（展開形の箱：0 UP、1 DN、2 斜線、3 琥珀の X）・`gear/lever_lock`（1 でロック。脚のモジュールが書き、init のレバーのハンドラーが OFF で止める）、故障 `gear/fail/actuator`・`door`・`indication`・`truck_tilt`（[5]）。前からのもの：`gear_position/annun_status`（3 の空の箱を足した）、`EICAS1_display_status`（2 の展開形を足した）、caution 38 GEAR DISAGREE・39 GEAR TILT、advisory 180 GEAR DOOR。
- X-Plane へ：脚ごとの位置を `sim/aircraft/parts/acf_gear_deploy`（X-Plane の順：0 前脚、1 右胴体、2 左胴体、3 右翼、4 左翼）に毎フレーム書く（X-Plane は 1 本のハンドルの向きへ脚を動かし続ける）。X-Plane のハンドル `gear_handle_down` はグルーだけが書く（init のレバーのハンドラーは書かなくなった）。他の系統が読む `deploy_ratio` はこれに従う。
- 開始：グルーは最初の 3 秒は X-Plane の脚に合わせ、そのあとレバーを脚の位置に合わせる。脚のモジュールのフライト開始はレバーを動かさなくなった。
- 段 2（ブレーキ）：ブレーキのモデル（`B747.10.brake_model.lua`）を、グルー `B747.10.xt.brakes.lua`（作動のグルーの次に読み、`B747_brakes()`）が回す。中身は notes/ATA-32.md §11。ブレーキは脚のモジュールだけが持つ。
  - 読むもの：X-Plane の toe brake の軸（`joy_mapped_axis_avail`・`value` の 6・7：推定）、ブレーキのコマンド（置き換え）と `wingsweep_ratio`（乗員のペダル）、パーキングブレーキのレバー（`flt_ctrls/parking_brake_ratio`）、油圧のグルーが出す源と圧（新設 `hydraulics/brake_source`：0 accumulator・1・2・4、`hydraulics/brake_psi`）、電池バス（`electrical/bus/bat_main`）、DC bus 1〜4、PSEU の `pri_air`、輪止め（`gear/chocked`）、故障（新設 `gear/fail/antiskid[2]`・`brake_limiter`・`park_valve`）。
  - 書くもの：X-Plane の `override_toe_brakes`（常に 1）・`left/right_brake_ratio`・`parking_brake_ratio`（閉じ込めた圧の保持）・`acf_has_abs`、新設 `gear/brakes/park_valve`（0 開〜1 閉）、memo 26 PARK BRAKE SET、advisory 10 ANTISKID・11 ANTISKID OFF・45 BRAKE LIMITER。X-Plane の `park_brake_set`・`release`・`toggle` はレバーを動かす。
  - 油圧のグルーは、X-Plane のパーキングブレーキとブレーキの比の増えた分を accumulator の作動油の使用にする（源が accumulator のとき）。
- 段 3（オートブレーキ）：オートブレーキのモデル（`B747.10.autobrake_model.lua`）を、ブレーキのグルーがブレーキのモデルの前に回し、その指令の圧（X-Plane のブレーキの比で 0〜1）をブレーキのモデルの `auto` に渡す（ペダルとの大きい方を、源の圧で制限）。中身は notes/ATA-32.md §12。開始の 3 秒は回さない。
  - 読むもの：セレクター（`gear/autobrakes/sel_dial_pos`：0 RTO、1 OFF、2 DISARM、3〜6 で 1〜4、7 MAX AUTO）、推力レバー（`engine/throttle[4]`）、機長側の IRS（`flt_mgmt/iru/status[0]` が 2 で、`mode_sel_dial_pos[0]` が NAV 以上）、対地速度（`sim/flightmodel/position/groundspeed`）、スピードブレーキのレバー（`flt_ctrls/speedbrake_lever`）、PSEU の air と ground（pri・alt）、ブレーキの源（系統 4 なら正規）、正規の antiskid（故障と ANTISKID OFF）、故障（新設 `gear/fail/autobrake`）。
  - 書くもの：セレクター（DISARM・OFF に戻す）、memo 2〜6 AUTOBRAKES 1〜4・MAX と 7 AUTOBRAKES RTO、advisory 17 AUTOBRAKES、X-Plane の `auto_brake_level`（常に 1 の OFF）。X-Plane のオートブレーキのコマンド（`brakes_off_auto`・`rto_auto`・`1_auto`〜`3_auto`・`max_auto`・`up_auto`・`dn_auto`・`toggle_auto`）はセレクターを動かす。
  - 外した前の処理：脚のモジュールの RTO の線（スロットル軸 > 0.8）、セレクターのコマンドでの `auto_brake_level` の書き込み、`autobrake_check`、memo と advisory、fltCtrls の 30 kt での DISARM とその時計。セレクターを書くのはブレーキのグルー（モデルの戻りと X-Plane のコマンド）と、脚のモジュールのセレクターのコマンド（`sel_dial_up`・`dn`）とフライトの開始（OFF）だけになった。
- 段 4（ステアリング）：ステアリングのモデル（`B747.10.steering_model.lua`）を、グルー `B747.10.xt.steering.lua`（ブレーキのグルーの次に読み、`B747_steering()`）が回す。中身は notes/ATA-32.md §13。ステアリングは脚のモジュールだけが持つ（前は油圧のモジュール `B747.19.xt.hydraulics_override.lua` が IAS 20 kt で X-Plane と切り替えていた）。
  - 読むもの：X-Plane の tiller の軸（`joy_mapped_axis_avail`・`value` の 37：推定）か新設 `gear/steering/tiller`（-1〜1）、ペダルとラダートリム（`flt_ctrls/rudder_input`、油圧のモジュールが書く）、系統 1（`hydraulics/pressure_1`）と脚レバー（DN のとき）、PSEU の前脚圧縮・pri と alt の air と ground、対地速度、新設 `gear/steering/pedal_tiller`（実機ではない手当て：1 で、tiller の軸が無いときペダルを tiller に。機体の読み込み `aircraft_load` で 1）、故障（新設 `gear/fail/pedal_steering`・`body_steering`）。
  - 書くもの：X-Plane の `override_wheel_steer`（常に 1）・`tire_steer_command_deg`（0 前輪、1 右胴体、2 左胴体、3・4 翼脚は 0）、新設 `gear/steering/body_unlocked`（胴体脚のロックスイッチ。fltCtrls の CONFIG GEAR CTR と PSEU のグルーが読む）、advisory 43 >BODY GEAR STRG、STATUS 95 BODY GR STRG SYS・96 PEDAL STEERING。
- 段 5（ブレーキ温度・タイヤ圧）：ブレーキ温度のモデル（`B747.10.btms_model.lua`）とタイヤ圧のモデル（`B747.10.tpis_model.lua`）を、グルー `B747.10.xt.wheels.lua`（ステアリングのグルーの次に読み、`B747_wheels()`）が回す。中身は notes/ATA-32.md §14。
  - 読むもの：X-Plane の `brake_absorbed_J`（主脚トラックごと。増えた分を 4 個のブレーキで分ける）、外気温、PSEU の air と脚の位置（`gear/position`：脚下げの空中は風で冷える）、各脚の接地（`on_ground`）、X-Plane のタイヤ故障 `rel_tire1`〜`5`（脚 0〜4）、推力レバー（`engine/throttle`）、故障（新設 `gear/fail/btms`・`tpis`）。
  - 書くもの：`gear/brake_temp[18]`（°C。3D のブレーキの光と synoptic の色）・`brake_temp_ind[18]`（0〜9）・`tire_pressure[18]`（psi）、advisory 46 BRAKE TEMP・290 >TIRE PRESSURE、STATUS 97 BRAKE TEMP SYS・98 TIRE PRESS SYS。カスタム acf の GEAR synoptic のドアの箱は `gear/door` を読む。

### 4.17 航法センサー（5-1）

新しいモジュール `B747.34.xt.nav`（`plugins/xtlua`）。脚のモジュールと同じく、本体 `B747.34.xt.nav.lua` が系統ごとのグルーを読み、`after_physics` で回す。init `B747.34.nav` が dataref を作る。中身は notes/ATA-34.md §3・§4・§10・§11。

- 段 1（エアデータ）：エアデータのモデル（`B747.34.airdata_model.lua`）を、グルー `B747.34.xt.airdata.lua` が毎フレーム回す（`B747_airdata()`）。
  - 読むもの：X-Plane の機長側・standby・副操縦士側の速度・Mach・高度・昇降率・気圧設定（ADC L・C・R。C は standby の pitot-static で、Mach と昇降率は計算：推定）、ADC の故障（X-Plane の `rel_adc_comp`・`_2`、新設 `airdata/fail/adc[3]`）、電源（`electrical/bus/stby_main`・`xfr_capt`・`xfr_fo`）、AIR DATA の選択器（`flt_inst/air_data_src/capt`・`fo/sel_dial_pos`。0 L・1 R：推定）。高度警報のために MCP の高度（`autopilot/heading/altitude_dial_ft`）、A/P の CMD の灯、GS の捕捉（`autopilot/FMA/active_pitch_mode` が 2）、フラップレバー、PSEU の全脚 down と地上、パーキングブレーキのレバー。
  - 書くもの：各 PFD の速度 `gauges/indicators/airspeed_kts_pilot`・`_copilot`（選んだ ADC。30 kt が下限。EEC・SRM なども読む）。新設（init `B747.34.nav`）の `airdata/src_capt`・`src_fo`（1 L、2 C、3 R）・`valid[3]`（ADC ごと）・`valid_capt`・`valid_fo`（PFD の旗のため）・`alt_advise`（白枠）・`alt_alert`（琥珀枠）。EICAS：warning 22 OVERSPEED、caution 1 ALT DISAGREE・2 >ALTITUDE ALERT・44 IAS DISAGREE、advisory 267 >SOURCE SEL ADC・12 >AOA RIGHT。
  - 外した前の処理：fltInst02 の OVERSPEED（placard を含む Vmax）と >AOA RIGHT（左の AOA を見ていた）、各側の速度の書き込み（`fltInstsetASIs`）。fltInst02 の BARO の STD は、押す前の値を preselect に残すようにした（NAV-06）。
  - 段 1b：カスタム acf の PFD は、高度と Mach を新設の `airdata/alt_capt`・`alt_fo`（選んだ ADC、その席の気圧設定）・`mach_capt`・`mach_fo` から読み、`valid_capt`・`valid_fo` が 0 なら速度と高度の表示を消して SPD・ALT の旗、`alt_advise`・`alt_alert` で高度の白枠・琥珀枠を出す（ACF_DIFF.md §5）。グルーは最初の 3 秒（モデルの前）は X-Plane の各側の値と有効を書く。PFD の昇降率はまだ X-Plane の値。
- 段 2（IRS）：IRS のモデル（`B747.34.irs_model.lua`）を、グルー `B747.34.xt.irs.lua` が毎フレーム回す（`B747_irs()`）。中身は notes/ATA-34.md §12。
  - 読むもの：MSU（`flt_mgmt/iru/mode_sel_dial_pos`：0 OFF、1 ALIGN、2 NAV、3 ATT）、AC bus 3・1・2（IRU L・C・R）、APU hot battery bus、DC bus 3、ground service bus、PSEU の地上、X-Plane の位置・対地速度・磁方位、故障（X-Plane の `rel_lrn1`・`rel_lrn2`、新設 `irs/fail/iru[3]`）、FMC の入力（新設 `irs/pos_entry_seq`・`_lat`・`_lon`、`set_hdg_seq`・`set_hdg`：入力ごとに seq が一つ増える）、IRS 選択器（`flt_inst/irs_src/capt`・`fo/sel_dial_pos`：0 L、1 C、2 R）、simconfig の `irs_align_time`。
  - 書くもの：`flt_mgmt/iru/status`（0 OFF、1 アライン済みで ALIGN、2 NAV、3 ATT、4 アライン中、5 故障）、新設（init `B747.34.nav`）の `irs/mode`・`time_left`・`att_valid`・`hdg_valid`・`nav_valid`・`lat`・`lon`・`gs`・`hdg`（IRU ごと）、`irs/motion`・`set_pos`・`aligning`・`set_hdg_shown`・`on_bat`、`pfd/capt/irs`・`fo/irs`（その席の IRS 選択器の IRU の姿勢と方位）、memo 14〜16 IRS ALIGN MODE L/C/R、advisory 233 IRS MOTION・225〜227 >IRS AC・229〜231 >IRS DC・228/232/234 IRS C/L/R・270 >SOURCE SEL IRS、`fms/notification` の 12 ENTER IRS POSITION・5 CYCLE IRS OFF-NAV。コマンド `irs/align_now`（クイックスタート）。
  - GPS：GPS のモデル（`B747.34.gps_model.lua`）を、グルー `B747.34.xt.gps.lua` が IRS の次に回す（`B747_gps()`）。読むもの：AC standby bus（L）、AC bus 2（R）、X-Plane の `rel_gps`・`rel_gps2`、新設 `gps/fail[2]`。書くもの：新設 `gps/valid[2]`、advisory 182 >GPS・183 >GPS LEFT・184 >GPS RIGHT。
  - FMC（keysystems の `irs/irs_system.lua`）はモジュールの値を読み、POS INIT・POS REF・IRS MONITOR と ND の TIME TO ALIGN（`irs/line1`〜`4`）・更新の行（`irs_display_line`）を作り、位置と SET HDG の入力を渡す。fltMgmt は MSU だけ、ヨーダンパー（fltCtrls）は `irs/att_valid`、照明は `irs/on_bat` を読む。

- 段 4（電波高度計と GPWS）：電波高度計のモデル（`B747.34.ra_model.lua`）と GPWS のモデル（`B747.34.gpws_model.lua`）を、グルー `B747.34.xt.ra.lua`・`B747.34.xt.gpws.lua` が GPS の次に回す（`B747_ra()`、`B747_gpws()`）。中身は notes/ATA-34.md §14。
  - 電波高度計が読むもの：X-Plane の機長側・副操縦士側の RA（L は機長側、R は副操縦士側、C は機長側で、機長側が故障なら副操縦士側：推定。どれも 8 ft 引く）、AC bus 3・1・2（L・C・R）、故障（X-Plane の `rel_pil_radalt`・`rel_cop_radalt`、新設 `ra/fail[3]`）、EIU 選択器（`flt_inst/eiu_src/capt`・`fo/sel_dial_pos`。機長 0 L・1 AUTO・2 C・3 R、副操縦士 0 L・1 C・2 AUTO・3 R：推定）。書くもの：`efis/radio_altitude`（機長の PFD の数字、前のまま。EEC・fltMgmt・fltInst02 も読む）、新設の `efis/radio_altitude_fo`、`ra/capt`・`fo` の `show`（数字を出す）・`flag`（RA 旗）・`value`（丸めない値）、`ra/valid[3]`、`ra/gpwc`・`gpwc_valid`。GPWS へは関数 `B747_ra_gpwc()` で渡す（XTLua はグローバルの表を名前空間にする）。
  - GPWS が読むもの：GPWC の RA、L IRU の慣性昇降率と高度（`irs/nav_valid[0]`、無ければ L ADC）、ADC の CAS（`airdata/valid`）、NAV 1 の LOC・GS の偏位と表示（L ILS、AC standby bus）、NAV 1 の針路と磁気の航跡（back course）、L IRU の roll（`irs/att_valid[0]`）、脚レバー、FCU のフラップ（`flt_ctrls/fcu/te_deg` の最小が 21° 以上で 25 か 30）、PSEU の空中、GND PROX パネル（`button_switch/position[4]`〜`[6]`、G/S INHB は押した回数 `gpws/gs_inhb_pushes`：マニピュレーターが足す）、X-Plane の reactive windshear（`windshear_warning_systems` が 5）、機長の minimums（RADIO/BARO、`radio_altimeter_bug_ft_pilot`・`efis/baro_ref/capt`）、CDU の GPWS の音の設定（`fmod/options/gpws`：音のバンクの順）、GPS の有効、AC bus 3（GPWC）と新設 `gpws/fail`。
  - GPWS が書くもの（新設）：`gpws/voice`（繰り返す声、1 つずつ）・`callout`（1 回の声、0.3 秒）・`last_callout`（試験用）、`gnd_prox_light`（照明モジュールの灯 2 番）、`pull_up`・`windshear`（カスタム acf の PFD）、`warning`（警報モデルの master WARNING、TCAS へ）、`alert`、`gs_inhibited`。EICAS：advisory 6 >ALT CALLOUTS、181 GND PROX SYS、288 TERR POS、289 >TERR OVRD、298 WINDSHEAR SYS。`.snd`（`fmod/747-400_custom.snd` と手元の `747-400.snd`）の GPWS の音は `voice` と `callout` で鳴る。
  - minimums の表示（fltInst02 の `B747_minimums()`）：各席の RA と DH で、`dec_height/display_status`（機長、前のまま）と新設の `dec_height/display_status_fo`、`radio_alt/display_status`・新設 `_fo`。MINS RST は点滅のリセットだけ。前の `B747_radio_altitude()`（機長の RA − 8 ft を全員に）と、DH を 350 ft・BARO を 1,000 ft に書き換える RST、機長だけの DH と minimums の声は外した。

- 段 5（トランスポンダと TCAS）：トランスポンダと TCAS のモデル（`B747.34.tcas_model.lua`）を、グルー `B747.34.xt.tcas.lua` が GPWS の次に回す（`B747_tcas()`）。中身は notes/ATA-34.md §15・§16。X-Plane の TCAS が TA・RA を判定し（`sim/cockpit2/tcas/targets/threat`、`indicators/tcas_active_advisory`・`tcas_message`・`tcas_vs_bands`）、モデルが 747 の層を足す。
  - 読むもの：570 のパネル（`flt_mgmt/txpdr/mode_sel_pos`：0 STBY、1 ALT RPTG OFF、2 XPDR、3 TA ONLY、4 TA/RA。`flt_mgmt/transponder/sel_dial_pos`：0 L、1 R）、AC standby bus（L）・AC bus 2（R）・AC bus 3（TCAS）、故障（新設 `xpdr/fail[2]`・`tcas/fail`、X-Plane の `rel_xpndr` は L）、PSEU の地上、TCAS の RA（`B747_ra_tcas()`：L、無ければ R）、GPWS の `gpws/warning`・`windshear`・`voice`、表示器の電源（`display_has_power[0..3]`）、各 ND のモード・中心・レンジ、TFC スイッチの押した回数（新設 `nd/traffic/capt|fo/pushes`。fltInst02 のスイッチが数える）、X-Plane の TCAS の相手（63 機：threat、ssr_mode、距離、相対高度）、自機の昇降率・ピッチ・真対気速度。
  - 書くもの：X-Plane の `transponder_mode`（前は fltMgmt のノブが書いた）、新設 `tcas/voice`（`.snd`）・`last_voice`、`tcas/sym[64]`（相手ごとの ND の機影の種類：ND のモジュールが読む）、`tcas/operating`・`failed`・`ra_mode`・`traffic`、PFD の RA の値 `tcas/pfd/ra`・`lo_on`・`hi_on`・`vs_lo`・`vs_hi`・`pitch_lo`・`pitch_hi`（機体シンボルからの角度）・`vs_red`（段 5d から、カスタム acf の PFD の赤枠・VSI の赤帯・赤い VS ポインタが読む）、トランスポンダの操作盤のコード表示の電源 `xpdr/panel_on`（パネル）、各 ND の `nd/capt|fo/tfc`・`tcas_off`（パネル。前は fltInst02 が書いた）と新設 `tcas_fail`・`traffic`・`offscale`・`ta_only`・`tcas_show`。EICAS：advisory 279 >TCAS OFF、280 >TCAS RA CAPTAIN、281 >TCAS RA F/O、282 >TCAS SYSTEM、292 >TRANSPONDER L、293 >TRANSPONDER R（前は fltMgmt が 279 だけ書いた）。
  - ND の機影（`plugins/xtlua_nd` の `B747.61.xt.nd.lua`、段 5b）：`tcas/sym` と X-Plane の相手の位置（lat・lon・ele・vertical_speed・ssr_mode）から、各 ND の 30 のスロット（init `B747.61.nd` の `nd/capt|fo/tcas/show`・`heading`・`distance`・`sym`・`tag_color`・`tag_dy`・`tag0`〜`29`）を毎フレーム埋める。置き方はアイコンの `makeIcon` と同じ。前の TCAS のアイコン（白い菱形 1 種）は外した。カスタム acf の ND のスロットとメッセージは ACF_DIFF.md §5。
  - X-Plane の EFIS の地図の TCAS（`EFIS_tcas_on`）は使わない（fltInst02 が 0 に保つ。地図は `override_TCAS` の相手を描かなかった）。
  - X-Plane の TCAS が advisory を出さない相手（threat は TA・RA）は TA として出す（RA の値・声は無い）。X-Plane が advisory を出さなくなることがある（PROGRESS.md「気づいたこと」）。
- 段 5c（気象レーダー）：気象レーダーの操作のモデル（`B747.34.wxr_model.lua`）を、グルー `B747.34.xt.wxr.lua` が TCAS の次に回す（`B747_wxr()`）。中身は notes/ATA-34.md §17・§18。描画は X-Plane のレーダー。
  - 読むもの：570 のパネル（TFR・TEST・LR/T・RR/T はこのモジュールのコマンド `wxr/buttons/*`。TILT・MAP GAIN・WX・WX+T・MAP・GCS は X-Plane の `sim/instruments/EFIS_wxr_*` を `replace_command` で受ける）、X-Plane の `EFIS_weather_on`（各 EFIS の WXR）、各 ND のレンジ、AC bus 1・2（R/T：推定）、`rel_wxr_radar`、`irs/att_valid` と各席の IRS 選択。
  - 書くもの：X-Plane の `EFIS_weather_mode`・`_tilt`・`_gain`・`_gcs`・`_stab`（左右）と `sector_width`・`antenna_limit`、新設 `wxr/lamp/sel[2]`・`gcs[2]`・`test`・`rt`（照明のモジュールがパネルの灯に）、`wxr/nd_fail[2]`・`nd_fault[2]`・`nd_msg[2]`・`nd_gain[2]`（段 5d：各 ND の WXR FAIL、TEST の故障の源、WEAK・ATT、CAL・VAR）。読むものに新設の故障 `wxr/fail[3]`（アンテナ、操作盤、校正）。ND の注記は ND のモジュールが X-Plane の左右の値とこれらから 3 行と色（`nd/capt|fo/text/wxr`・`tilt`・`wxr3`、`wxr_color[3]`）に作る。

### 4.18 表示（5-2）

- 段 1（表示器と EIU）：モデル `B747.60.display_model.lua` を、グルー `B747.60.xt.displays.lua`（計器のモジュールに dofile）が毎フレーム回す（`B747_displays()`。前の `fltInstsetCRTs()` の代わり）。中身は notes/ATA-31.md §10・§11。
  - 読むもの：INBD・LWR の選択器（副操縦士は逆向き）、APU standby・main standby・captain transfer・F/O transfer bus と `any_ac`、新設の故障 `displays/fail[6]`（機長 outboard・機長 inboard・upper・lower・副操縦士 inboard・副操縦士 outboard）・`eiu/fail[3]`、各席と中央の EIU 選択器、PSEU の空地。
  - 書くもの：パネルとの約束の `flt_inst/display/*_pos`（内容の位置）と `electrical/display_has_power[0..5]`（内容の電源。6 か 0）、新設 `displays/content_unit[6]`（内容ごとの表示器：照明のモジュールが輝度のつまみに使う）・`eiu/used[3]`（機長・副操縦士・EICAS が使う EIU）、>EIU LEFT（advisory 91）。
- 段 3a（速度テープ）：同じモジュールの `B747.60.speedtape_model.lua` とグルー `B747.60.xt.speedtape.lua`（fltInst02 の後に dofile）が、フラップの機動速度 `airspeed/Vf0`〜`Vf30`（Vf25 は VREF25：CDU の APPROACH REF も読む）、新設 `airspeed/show_vf[7]`（パネルのバグ。約 20,000 ft より上は出さない）、`pfd/show_mins` を書く。
- 段 3b（最小速度）：同じグルーが `B747.60.minspeed_model.lua` も回し、`airspeed/Vs`（赤と黒の帯の上端：シェーカーか低速バフェットの速度）、新設 `airspeed/Vminm`（最小機動速度）、`airspeed/Vmaxm`（最大機動速度、出さないときは最大速度）、`sim/flightmodel/failures/stallwarning`（シェーカー）、AIRSPEED LOW（`CAS/caution_status[0]`）、`airspeed_window/min`、新設 `airspeed/tape_capt[4]`・`tape_fo[4]`（PFD の帯 4 本が読む「帯の速度−その席の速度」）を書く。入力は気圧高度（`sim/flightmodel2/position/pressure_altitude`）、エアデータ（機長側、無効なら副操縦士側）、荷重倍数（`g_nrml`）など。`airspeed/Vmc` は前の一次式のまま fltInst02 が書く（AFDS・A/T・VNAV・EEC・FMS の速度の下限用：6-3・6-4 まで）。fltInst02 の `B747_Vs` は X-Plane の TO/GA のピッチのために失速速度の表を引くだけ。
- 段 2（ソース選択の比較）：同じグルーが FLT DIR・NAV の選択器と新設の故障 `efis/fail[2]`・`dsp/fail` を読み、>SOURCE SEL EIU・F/D・NAV、>EFIS CONTROL L・R、>EFIS/EICAS C/P を書く。>ATTITUDE・>HEADING は航法センサーの IRS のグルー（X-Plane の両側の AHRS の差）、>SNGL SOURCE RA は電波高度計のグルー。
- 段 4a（PFD の姿勢・方位・昇降率の源と旗）：表示器と EIU のグルー（`B747.60.xt.displays.lua`）が `B747.60.pfd_model.lua` も回す。読むものは IRU の `irs/att_valid`・`hdg_valid`・`nav_valid`（航法センサーのモジュール）、各席の IRS 選択器、NAV の源（表示器のモデルと同じ）、`airdata/valid_capt`・`valid_fo`。書くものは新設 `pfd/capt/att`・`hdg`・`trk`・`vsi`・`vert`（`fo` も）。値は今までどおり X-Plane の pilot・copilot の AHRS（各席の選んだ IRU の代わり）で、パネルの方位目盛もその席の AHRS の方位で回す（前は ND の上の向き `nd/up/*`）。`pfd/capt/irs`・`fo/irs`（選んだ IRU の姿勢と方位がともに有効）は IRS のグルーが書き続ける（FMS・ND が読む）。
- 段 4b（気圧設定の琥珀の枠）：同じグルーが、各席の BARO STD（fltInst02 の `efis/baro_std/capt|fo/switch_pos`）、`airdata/alt_capt`・`alt_fo`、MCP 高度、FMC のデータ `fms/data`（JSON の文字列）の `transalt` を 2 秒ごとに読み、新設 `pfd/capt/baro_alert`・`fo/baro_alert` を書く（判定は `B747.60.pfd_model.lua` の `baro_alert`。遷移レベルは FMC にまだ無いので既定の FL180）。CDU の EFIS CONTROL の BARO SET の入力は FMS のモジュールの `B744.fms.baro.lua` が解き、ページの処理がその CDU の側（右の CDU は副操縦士、ほかは機長）だけに書く。STD は EFIS 操作パネルの STD のコマンドを使う（STD の前の値を覚える）。
- 段 4c（PLI と VR の R）：速度テープのグルーが最小速度のモデルに迎角（`sim/flightmodel/position/alpha`）も渡し、新設 `pfd/pli`（シェーカーまでの迎角の余裕：飛行機の記号から上へ何度）・`pfd/pli_show` と、V1・VR から新設 `airspeed/vr_r`（VR が V1 から 4 kt 以内）を書く。パネルの PLI はバンクで回るグループの中のポインター（RA のピッチの限界と同じ作り）。
- 段 4d（FPV と FPV・PITCH・ROLL の旗）：fltInst02 の FPV のスイッチのコマンドが新設 `efis/fpv/<席>/selected` を入れ切りし、表示器と EIU のグルーが X-Plane の `vpath`・`hpath`・`psi` とその席の AHRS の姿勢から、FPV の位置（新設 `pfd/<席>/fpv_x`・`fpv_y`：姿勢表示の中心からのピクセル）と `fpv_show`・`fpv_flag`（選んだ IRU が NAV か）、両席の姿勢の差から `pfd/pitch_flag`・`roll_flag` を書く。パネルの FPV は左右・上下の 2 段の移動グループの中で、本体はロールで回り、足は回らない。
- 段 4e（ILS の表示）：新しいモデル `B747.60.pfd_ils_model.lua` を表示器と EIU のグルーが回す（段 4a の航跡の結果も使う）。入るもの：各席の ILS 受信機（機長は X-Plane の NAV1 の pilot の HSI、副操縦士は NAV2 の copilot の HSI。故障は `rel_nav1`・`rel_nav2`・`rel_loc`・`rel_gls`、電源は AC standby bus と AC bus 2）、純正の同調の印 `autopilot/ils_dots`、その席の AHRS のロール・電波高度（`ra/<席>/value`・`flag`・`show`）・F/D のスイッチ、A/P の CMD、FMA のモード。書くもの：新設 `pfd/<席>/ils_show`・`loc_scale`・`loc_ptr`・`loc_flag`・`gs_scale`・`gs_ptr`・`gs_flag`・`rwy_show`（値の意味は init の注記）。点滅（4 Hz）はモデルが `SIM_PERIOD` で数え、`loc_ptr`・`gs_ptr` を消えた半分で 0 にする。パネルはこれらの値ごとに部品を出し分ける（`SHOW_EQUAL`）。
- 段 5a（ND の向き、方位・航跡、旗）：新しいモデル `B747.60.nd_model.lua` を表示器と EIU のグルーが回す（段 4a の方位・航跡の結果と、IRS の NAV を使う）。入るもの：各席の ND のモード（`nd/mode/<席>/sel_dial_pos`）、自席の方位・航跡（pilot・copilot の AHRS と航跡）・速度、風、MCP の方位、FMA のロールモード。書くもの：X-Plane の `map_mode`・`map_mode_copilot`（X-Plane の地図の層の向き）、新設 `nd/<席>/rose`・`trk_flag`・`hdg_flag`・`map_flag`・`vtk_flag`・`hdg_ptr`・`hdg_ptr_pln`・`hdg_bug`・`hdg_line`・`wind`・`wind_deg`。ND の目盛と記号の向き `nd/up/<席>` は nd.lua（`plugins/xtlua_nd`）が同じ規則（`nd_up`）で自席のモードと源から出す（記号の角度も同じ向きで計算するため、nd.lua に置いたまま）。
- 段 5b（PFD の ILS の受信機）：段 4e のグルーが、各席の受信機を使用中の EIU（`eiu/used`）から選ぶ（L は ILS L = X-Plane の NAV1、C は ILS C = NAV1 のデータで AC bus 1、R は ILS R = NAV2）。HSI の値はやめて `nav1_`・`nav2_` の偏位・信号・ID・周波数を直接読む。書くもの：新設 `pfd/<席>/ils_rx`（1〜3）・`loc_dots`・`gs_dots`（パネルのポインターと立ち上がる滑走路が読む）、文字列 `pfd/<席>/ils_ref`（ID、受けるまでは周波数。変わったときだけ書く）、caution 57 >SNGL SOURCE ILS（両席が同じ EIU）。パネルの DME とコースは `ils_rx` で NAV1・NAV2 を出し分ける。
- 段 5b-1b（ND の APP）：同じ ILS のモデルが ND の APP の値も出す（同じ受信機）。入るもの：段 5b-1a のものに、受信機の DME（`navN_has_dme`・`navN_dme_distance_nm`）と DME の故障（`rel_dme`）、CDU のコース（`nav_obs_deg_mag_pilot[0]`・`[1]`）。書くもの：新設 `nd/<席>/loc_scale`・`loc_ptr`・`loc_flag`・`gs_scale`・`gs_ptr`・`gs_flag`・`crs`（0 なし、1「---」、2 表示）・`crs_deg`・`dme`（0「DME ---」、1 距離、2 旗）・`dme_nm`、文字列 `nd/<席>/ils_ref`（同調前は「---」）と `nd/dashes`（パネルの「---」、一度だけ書く）。パネルの LOC のバーは X-Plane の `DEFLECT_SRC NAV1`・`NAV2` で振れる（ILS C は NAV1 の組）。
- 段 5b-2a（ND の VOR）：ND のモデル（段 5a の `B747.60.nd_model.lua`）に VOR モードを足した。基準 VOR は自席の側（機長 VOR L = X-Plane の NAV3、副操縦士 VOR R = NAV4：推定）。入るもの：その VOR の電源（AC standby bus、AC bus 2）、同調の状態（文字列 `radio/tuningmodes` の 2・3 文字目：M 以外は自動同調）、方位の信号（`nav_display_horizontal[2]`・`[3]`）、TO/FROM（`nav_flag_from_to_pilot`）、DME。書くもの：新設 `nd/<席>/vor_rx`（1・2）・`vor_flag`（0、1 VOR L、2 VOR R）・`vor_dev`・`vor_crs`（0 なし、1「---」、2 表示）・`vor_crs_deg`・`to_from`（0、1 TO、2 FROM）・`vor_dme`・`vor_dme_nm`、文字列 `nd/<席>/vor_ref`。ID か周波数の文字は ILS と同じ関数（`id_or_freq`）。
- 段 5b-2b（ND の VOR・ADF の針と左右下の欄）：ND のモデルに、各席の EFIS の VOR/ADF スイッチ（X-Plane の `EFIS_1/2_selection_pilot`・`copilot`：0 ADF、1 OFF、2 VOR）と、VOR L・R（NAV3・4）と ADF L・R（ADF 1・2：AC bus 3・2、`rel_adf1/2`）の電源・故障・受信（VOR は方位の信号、ADF は局の ID）・相対方位・DME を入れる。書くもの：新設 `nd/<席>/ptr_l`・`ptr_r`（0、1 VOR、2 ADF）・`brg_l`・`brg_r`（相対方位 + 自席の方位 − 表示の上）・`rad_l`・`rad_r`・`rad_l_flag`・`rad_r_flag`・`rad_l_dme`・`rad_r_dme`、両席共通の文字列 `nd/vor_l_ref`・`vor_r_ref`・`adf_l_ref`・`adf_r_ref`（受信機の故障で空）。パネルの DME の距離は X-Plane の `nav_dme_distance_nm[2]`・`[3]` のまま。
- 段 5c-1（CDU の EFIS CONTROL・OPTIONS、EFIS 操作パネルの故障）：計器のモジュール（`B747.60.xt.fltInst02.lua`）は、`efis/fail[0|1]` のあいだ、その席の EFIS 操作パネルの 50 個の操作のコマンドと、X-Plane の VOR/ADF セレクターのコマンド（`sim/instruments/EFIS_1|2_pilot|copilot_sel_up|dn` を `replace_command` で引き取る：上で VOR 2、下で ADF 0）を受け付けない。DATA・POS の押しボタンは新設 `nd/data/<席>/data`・`pos`（init `B747.60.fltInst`）を切り替える。CDU の STD と DH RESET は新設のコマンド `laminar/B747/efis/baro_std/<席>/cdu`・`laminar/B747/efis/dh/<席>/cdu_reset`（init で作る）で、パネルの押しボタンと同じ処理を故障のガードなしで呼ぶ。FMS のモジュール（`B744.fms.pages.lua`・`activepages/B744.fms.pages.efisctl.lua`）は、左の CDU を機長、右を副操縦士のパネルの代わりにして（中央はどちらでもない）、MENU の EFIS CP・EICAS CP の SELECT を `efis/fail`・`dsp/fail` のときだけ出し、EFIS CONTROL・OPTIONS をその CDU の側に効かせる（範囲は `nd/range/<席>/sel_dial_pos` と X-Plane の `map_range`・`map_range_copilot` に新しい値を書く。XTLua では同じフレームで書いた dataref を読み直すと古い値が返ることがある）。
- 段 5c-2a（ND の DATA）：FMS のモジュール（`B747.68.xt.fms.lua` の `B747_route_eta`）が、空中で 1 秒ごとに、現用点から先の各点の ETA を経路に沿った距離から現用点・次の点の ETA と同じ関数（`get_ETA_for_Distance`）で出し、新設の文字列 `laminar/B747/fms/route_eta`（init `B747.68.fms`）に`xtlua/fms` の各点の UTC の分（無いときは -1）の JSON の配列で書く（変わったときだけ）。ND のモジュール（`plugins/xtlua_nd` の `B747.61.xt.nd.lua`）は2 秒ごとにそれと FMC の遷移高度（`laminar/B747/fms/data` の `transalt`）を読み、経路の点が入る先頭の 20 枠に、その席の DATA（`nd/data/<席>/data`）が入っていれば高度（`xtlua/fms` の 9 番目：その点の高度）と ETA の 2 行を書く（新しい純粋なモジュール `B747.61.nd_data.lua`：遷移高度以上は FL、高度が無ければ ETA を 1 行目に）。新設 `nd/<席>/text/rdata_color`（20 枠、0 なし、1 白、2 マゼンタ）、`rdata1_<n>`・`rdata2_<n>`（init `B747.61.nd`）。試験キットの経路の道具：FlyWithLua の `tests/flight/fwl/B747_route.lua`（XPLM の FMS 関数を FFI で呼ぶ）と、シナリオの `route`・`route_clear` の手順。
- 段 5c-2b（ND の POS）：ND のモデル（`B747.60.nd_model.lua`）に、各席の POS（`nd/data/<席>/pos`）と範囲、IRU の NAV（`irs/nav_valid`）、GPS（`gps/valid`）、VOR L・R の DME の距離（`nav_dme_distance_nm[2]`・`[3]`）を足した。書くもの：新設 `nd/<席>/pos_iru`（3）・`pos_gps`、radial ごとに `pos_rad_l`・`_brg`（表示の上からの向き）・`_len`（px：DME の距離か画面の端）・`_end`（最後の 24 px の線分の位置）・`_tick`・`_tbrg`・`_tside`（文字の向きと線の左右）・`_text`（R-310）（`_r` も同じ。init `B747.60.fltInst`）。パネルの記号は地図の記号のグループ（`ND Text Center`：CTR で動く）の中、機体の位置（高度の到達の弧と同じ点）に置く。
- 段 5c-3a（ND の地図の記号）：ND のモジュール（`B747.61.xt.nd.lua` の `makeIcon`）は、記号と文字の色を決めてから、60 枠が空いていれば書き、埋まっていれば新設 `nd/<席>/excess_data`（init `B747.61.nd`）を 1 にする。STA の高高度の局は、起動後に `Custom Data/earth_nav.dat`（無ければ `Resources/default data/earth_nav.dat`）を 1 フレーム 500 行ずつ読んで作る ID ごとの位置の表（受信範囲 100 NM 以上：`B747.61.nd_data.lua` の `nav_line`）と照合する。FMS のモジュールの ND の GS の行（`nd/gs_tas_line` など）は GS だけ。
- 段 5c-3b（ND の出発・到着空港と滑走路）：ND のモジュールが、2 秒ごとに読み直す X-Plane の FMS の経路（`xtlua/fms`）の両端の空港と、その近くの RW の項目（`B747.61.nd_data.lua` の `route_ends`）から、出発・到着空港と選んだ滑走路を決め、反対側の端を空港の CIFP ファイル（`Custom Data/CIFP` か `Resources/default data/CIFP`、1 フレーム 500 行）から読む。毎フレーム、席ごとに新設 `nd/<席>/apt/*`（init `B747.61.nd`）に、空港の記号か滑走路の位置・向き・長さ・破線を書く。地図の記号の向きはモジュールの `nd_bearing` 1 つ（0.2 秒ごとの `makeIcon` と毎フレームの `updateIcon`、空港）。
- 段 5c-3c（ND のコースの線）：ND のモジュールが毎フレーム、`laminar/B747/radio/tuningmodes` で手動同調の VOR L・R の局（航法施設の一覧から 1 秒ごと）と CRS（NAV3・4 の OBS）から、新設 `nd/<席>/crs/*`（init `B747.61.nd`）に、線の機体に一番近い点・向き・破線のずらしと見える破線、局の位置とコース・反対の数字を書く（`B747.61.nd_data.lua` の `crs_line`）。
- 段 5d（HDG REF）：表示のグルー（`B747.60.xt.displays.lua`）が純粋なモデル `B747.60.hdg_ref_model.lua` で基準を決め、新設 `efis/hdg_ref/*`（`true`・`pfd_label`・`nd_label`・`nd_plan_label`）と両席の基準の方位・航跡 `pfd/<席>/hdg_deg`・`trk_deg`（init `B747.60.fltInst`）を毎フレーム書く。パネルの方位の計器、ND のモジュールのローズ（`nd/up`）、ND のモデル、FMC の風の数字、AFDS（`ap_hdg_target`・`ap_hdg_ref_hold`）がそれを読む。
- 段 5e（ND のトレンドベクトル）：ND のモデル（`B747.60.nd_model.lua` の `trend`）が対地速度と各席の傾きから 9 片の位置・向き・長さを出し、表示のグルーが新設 `nd/<席>/tv_*`（init `B747.60.fltInst`）に書く。
- MAP CTR（2026-10-28、notes §40）：選んだ範囲は全周のローズ（拡大の半分の 232.5 px）。ND のモジュールの `map_scale`（`B747.61.xt.nd.lua`）が各席の 1 NM あたりの単位を出し、記号・TCAS・空港・コースの線・高度の弧に使う。ND のモデルが POS の線と予測線を同じ縮尺で、`trk_line_ctr`（MAP CTR の航跡線）と X-Plane の地図の範囲 `xp_range`（MAP CTR は 1 段上）・`xp_half`（640 NM の MAP CTR）を出す。X-Plane の `map_range`・`map_range_copilot` を書くのは表示のグルーだけ（つまみと CDU は `nd/range/<席>/sel_dial_pos` だけ）。新設 `nd/<席>/trk_line_ctr`・`xp_map_half`（init `B747.60.fltInst`）。
- 段 6a（時計）：時計のモデル（`B747.60.clock_model.lua`）を時計のグルー（`B747.60.xt.fltInst03.lua`、両席）が動かす。fltInst02 の after_physics が `B747_clocks()`、flight_start が `B747_clocks_flight_start()` を呼ぶ。出力は新設 `fltInst/<席>/clock_on`・`clock_utc_hours`・`clock_utc_minutes`・`clock_day`・`clock_month`・`clock_et_show` と今までの時計の dataref（init `B747.60.fltInst`）。
- 段 6b-1（EICAS の部分表示と逸脱の印）：エンジンの表示モデルが逸脱の 3 群を新設 `engines/sec_exceed` に出し、EICAS の形式のモデル（`B747.60.eicas_format_model.lua`）を表示のグルー（`B747.60.xt.displays.lua` の `eicas_format`）が動かす。選んだ二次表示と表示器のモデルの主・二次 EICAS を入れ、新設 `eicas/*`（init `B747.60.fltInst`）を出す。電源投入時は `dsp/synoptic_display` に ENG を書く。
- 段 6b-2（EICAS の compact の形）：パネルだけ。主 EICAS の `GROUP Engine` が `eicas/compact` で通常の見出しとテープを隠し、新しい `GROUP Compact` が `eicas/cmp_rows` で二次の行（二次エンジンのページの数字の写し）を出す。
- 段 7（SHOW の条件の重なり）：パネルだけ。パネルの部品とグループは 1 つの dataref の条件しか見ないので、別々の dataref の条件は入れ子のグループで重ねる（道具 `panel_show_and.lua`。新しくパネルを書く道具も同じ形にする）。

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
- パネルの表示条件（`SHOW_EQUAL`・`SHOW_LESS`・`SHOW_GREATER`）は、計器かグループごとに 1 つの dataref だけが効く（同じ dataref の LESS と GREATER で範囲。違う dataref を 2 行書くと後ろの行だけが効く：2026-10-25、カスタム acf の PFD で確かめた）。条件を重ねるときはグループを入れ子にする。純正の計器にも違う dataref を 2 行持つものがある（例：PFD の NO V SPD は V1 の行だけが効く）。
- 計器の画像は `名前.png`（土台。大きさが計器の枠）と `名前-1.png`（動く絵や絵のコマ。tape は `-1` が塗り、`-2` が枠）の組。`CLIP` のある pointer・needle は、動く絵を土台の大きさの矩形（POS が中心）で切る。矩形は計器の座標なので、グループの回転・移動と一緒に動く（回転したグループの中では回った矩形で切る：2026-10-25、PFD の RA の赤枠を窓のマスクを外して確かめた）。動かす絵は動く範囲を含む大きさにする（PLI の最初の高さ 40 の絵は、9° 上に動かすと切られて出なかった。高さ 480 にした：段 4c）。純正の PFD の姿勢表示の上の空色は Bank Scale の絵（弧形の穴の空いた空色の帯）で、それより前に描いたものは上の方が隠れる。
- `KEY_FRAME` の範囲の外では、X-Plane は端の区間の線を延ばす（速度テープのバグのグループは 0〜60 kt の枠でどの速度でも動き、260〜380 kt の枠の最大速度の帯も 230 kt に出た）。`CLIP` のある `GROUP_ANIMATE_MODE TRANSLATE` のグループは、切り抜きの窓もグループと一緒に動く：純正の速度テープの帯のグループは速度で上下し、最小の側は 160 kt 付近でしか窓が重ならず、巡航の約 250 kt の最小機動速度は出なかった（2026-10-25）。グループを止め、帯の位置は「帯の速度−今の速度」の dataref（`airspeed/tape_capt`・`tape_fo`）で決めるようにした（`panel_speed_bands.lua`）。
- **制約**：表示の定義は acf の中にある。純正 acf は変えないので、表示を直すときは dataref の値で直すのが基本になる。計器の追加や変更はカスタム acf にしかできず、見た目に関わるので承認が要る。カスタム acf と純正 acf のパネル定義は、ADF の方位針 2 個の参照 index を除いて同じ。

## 6. FMC

- CDU は 3 台：`fms1`（左）、`fms2`（右）、`fms3`（中央）。キーはコマンド（例：`laminar/B747/fms1/ls_key/L1`、`.../func_key/legs`、`.../alphanum_key/A`）で、ループで作る。
- ページ：
  - `B744.fms.pages.lua`：共通部と多くのページ
  - `activepages/*.lua`：動くページ（PERF INIT、POS INIT、TAKEOFF、THRUST LIM、PROGRESS、VNAV、DOORS、EFIS/EICAS CTL、地上作業、乗客・貨物、ATC/CPDLC など）
  - `refonly/*.lua`：見た目だけのページ（`***` の雛形。REF NAV DATA、NAV RAD、DEP/ARR、HOLD、FIX など）
- `B744.createfms.lua` が CDU を作り、`B747.68.xt.fms.lua` がページ遷移・入力・データ（`getFMSData`）を扱う。
- CDU の枠組み（6-2 段 2）：純粋なモデル `B747.68.cdu_model.lua`（scratchpad のキー、CDU ごとの入力のメッセージ、FMC のメッセージの列、入力の形の解釈）。`keyDown` は自前のページの scratchpad のキーをモデルに、ほかを前の振り分け（`pageKey`）に渡す。ページは前と同じく `fmsO.scratchpad` を読み書きし、`fmsO.notify` に立てたメッセージはその CDU の列に移る。FMC のメッセージは `laminar/B747/fms/notification` の旗（系統が条件の間だけ立てる）から毎フレーム写し、alert で >FMC MESSAGE。CDU の電源は `electrical/display_has_power[8]`・`[7]`・`[6]`。
- 航法データベース（6-2 段 4）：FMS のモジュールが `B747.68.navdb.lua` で X-Plane の航法データ（Custom Data か `Resources/default data`）を 1 フレームに 32 KB ずつ読み、グローバル `B747_fmc_navdb`（メタテーブル付きの表）に持つ。ページは `B747_navdb.airport` などで引く。試験では `B747_NAVDB_FOLDER` で合成のデータ（`tests/fms/data/navdb/`）を指す。NAV DATA OUT OF DATE は `laminar/B747/fms/notification` の 55 番目。
- 経路（6-2 段 5a〜5c）：FMS のモジュールが `B747.68.route_model.lua` の経路をグローバル `B747_fmc_route`（メタテーブル付き）に持つ。RTE と LEGS のページ（`activepages/B744.fms.pages.rte.lua`・`legs.lua`）が変え、`B747_fmc_route_changed()` が RTE 1 の変化を FMC のデータ（`fltdep`・`fltdst`・`runway`・`transalt`）と X-Plane の FMS（`xtlua/loadtoFMS` に .fms v1100 の文字列）へ流す。X-Plane の FMS は ND の経路の線と AFDS の LNAV・VNAV（作り直すまで）が読む。
- 手続き（6-2 段 5d）：`B747.68.proc_model.lua`（`B747_fmc_route.P`）が CIFP の SID・STAR・進入を脚にし、経路のモデルの `set_departure`・`set_arrival` が経路に入れる。DEP/ARR のページは `activepages/B744.fms.pages.deparr.lua`、DEP ARR キーの行き先は `B747_cdu_deparr_page`。
- 現用点（6-2 段 5e）：`B747_fmc_route_sync()`（FMS のモジュールの毎フレーム）が、（段 6c からは LNAV が順送りした後の）FMC の現用点に AFDS の現用点（`laminar/B747/autopilot/ap_monitor/fmscurrentIndex`）を合わせ（通過した脚は `passed`、X-Plane の計画には残す）、新しい計画を流し込んだあとと空中のアクティブ化のあとは、X-Plane の FMS の現用点（`xtlua/currentFMSID`）と AFDS の現用点を FMC の現用点に合わせる。`to_fms` が返す行と脚の対応（`map`）を使う。DIRECT TO の始点は計画の DTOPOS（ND は点として描かない）。EXEC 灯は `B747_fmc_exec_lights()` が `laminar/B747/fms/exec_light_pilot`（左・中央の CDU）・`_copilot`（右）に書き、3D の物体 `Cockpit_Pedestal1.obj` が読む（2026-10-27：notes/ATA-34-61-FMC.md §25）。X-Plane の FMS へは、プラグイン `b747_fms_bridge` があれば `laminar/B747/fms/xp/plan`・`xp/current`（X-Plane のスレッド）、無ければ XTLua の `xtlua/loadtoFMS`・`xtlua/currentFMSID`（作業スレッドで排他なし：計画は経路が 1 秒変わらなくなってから、現用点は計画 1 回につき 2 回まで）。
- ND の PLAN の中心（6-2、2026-10-29：notes/ATA-34-61-FMC.md §42）：LEGS のページ（`activepages/B744.fms.pages.legs.lua`）が中心（`planCtr`：経路の番号と脚）を持ち、<CTR>・6R の STEP>（押した CDU で振り分ける `legsr6`）・LEGS キーと NEXT・PREV で動かす。`B747_cdu_plan_ctr_update()` が ND を PLN にしたときの中心を決め、`B747_cdu_plan_ctr()` が中心の経路・脚を返す。`B747_fmc_plan_ctr_sync()`（`after_physics` で `B747_fmc_route_sync()` の次）が中心の脚の X-Plane の計画の行を、プラグイン `b747_fms_bridge` の `laminar/B747/fms/xp/displayed`（1 から。XPLMSetDisplayedFMSEntry）に書く。ND は X-Plane の表示中の項目（`xtlua/xpFMSData` の [1]）を PLAN の記号の中心にする。プラグインが無ければ動かない（X-Plane の FMS のまま）。
- 経路の形（6-2 段 6a）：`B747.68.path_model.lua`（純粋、`B747_path_model`）が経路の脚ごとに形の要素（大円の線、コース、ヘディング、弧、無し）と、条件で終わる脚の終わりの予測、fly-by の旋回（`turn`）を作る。LNAV（段 6b）と ND の線（段 6d：`shape` を経路のモデルの `to_fms` が X-Plane の計画の行にする。条件の脚の終わりは名前の行、弧の点は「~」の行）が使う（notes/ATA-34-61-FMC.md §27・§30）。
- LNAV（6-2 段 6b）：`B747.68.lnav_model.lua`（純粋、`B747_lnav_model`）が経路の形と機体の状態から、XTK・希望トラック・順送り・捕捉の条件（valid）・ロールの指令・ヘディングの保持・メッセージを出す。順送りは経路のモデルの `sequence`（条件の脚の後は機体の位置を次の脚の始点 `start` に）。FMS のモジュールの `B747_fmc_lnav_update()` が毎フレーム回し（段 6c）、`laminar/B747/fms/lnav/valid`・`roll`・`mode`・`xtk`・`dtk`・`route` を出す。AFDS は arm 中に `valid` で LNAV を engage し、FD とサーボのロールの目標を `roll` にする（`B747.19.xt.afds_control.lua` の `ap_roll_assist`、PFD の FD は `B747_ap_fma`）。FMC がアクティブな経路を持つ間（`route` = 1）、AFDS の best track と前の LNAV の方位は使わない（notes/ATA-34-61-FMC.md §28・§29）。
- 離陸の V speeds（6-2 段 3b-1）：計器のモジュール（`fltInst02`）が FMC の重量（`laminar/B747/fms/data` の `grwt`）と TAKEOFF REF のフラップ・風から計算値を `airspeed/V1_ref`・`Vr_ref`・`V2_ref` に出し、FMC が選んだものを `airspeed/V1`・`Vr`・`V2`（PFD）に書く（999 は NO V SPD）。
- ACARS/CPDLC：`acars/*`（AutoATC と Hoppie の provider）。
- IRS：`irs/irs_system.lua`（アライン、位置）。`irs/rnav_system.lua`。
- ルート・航法：X-Plane の FMS（`xtlua/fms`）。LNAV のポイント切り替えは autopilot 側（`override_fms_advance`）。VNAV は `B744.fms.pages.vnav*.lua` と `B747.70.xt.autopilot.vnav*`。

## 6a. AFDS（6-3）

- 作り直しの段取りは notes/ATA-22.md §10。モードの論理を、自動操縦のモジュール（`B747.70.xt.autopilot`）の純粋なモデル `B747.70.afds_model.lua`（`B747_afds_model`）に段ごとに移す。移していないモードと制御則は前のコード（`B747.70.xt.autopilot.lua`・monitor・autoland と、油圧のモジュールの `B747.19.xt.afds_control.lua`）のまま。
- 段 1a（2026-10-27、notes §11）：モデルが A/P の engage の状態（L・C・R、解除バー）、AUTOPILOT DISC、F/D のスイッチと既定のモードを持つ。グルー（`B747.70.xt.autopilot.lua` の `afds_*`）は、CMD・解除バー・操縦輪のスイッチ・トリムによる解除のハンドラーからモデルを呼び、毎フレームの最初（`B747_afds_update()`）に F/D のスイッチ（`toggle_switch/position[23]`・`[24]`）と油圧を渡して、`autopilot/cmd_L_mode/status`・`cmd_C_…`・`cmd_R_…`、`autopilot/servos_on`（engage の時刻 `ap_monitor/servos_on_time`）、`CAS/warning_status[0]`（AUTOPILOT DISC）を書く。既定のモードは前のコードの状態（`vvi_status` と V/S の目標、X-Plane の `sim/autopilot/heading_hold`、`att_rate`、`TOGA_status`）に書く。前のコードの全チャンネル解除（`B747_ap_all_cmd_modes_off`）はモデルを警報なしで解除する。F/D のスイッチのハンドラー（`plugins/xtlua` の manipulators）はスイッチだけ。
- 段 1b（2026-10-27、notes §12）：モデルがロールのモード（HDG SEL・HDG HOLD・ATT・LNAV と LNAV の arm）を持ち、グルーが `autopilot/lnav_state`・`att_rate` と FMA のロールを書く。旋回は段 2a から新しいロールの則（下）、それまでは X-Plane の HDG SEL（`sim/cockpit/autopilot/heading_mag` に MCP の方位か保つ方位）。`sim/autopilot/heading_hold`（3D の HDG HOLD のボタン）は replace してモデルへ（X-Plane の heading hold は使わない）。前のコードの LOC と TO/GA はモデルの入力（段 1d・1e まで）。照明（`B747.90.xt.lighting.lua`）の HDG HOLD の灯は FMA のロールが HDG HOLD か ATT。
- 段 1c（2026-10-27、notes §13）：モデルがピッチのモード（V/S・ALT・FLCH・VNAV と VNAV の arm）を持ち、グルーが `autopilot/vnav_state`（arm の 1。engage 中は前の VNAV の 2・3）と、VNAV でないときの前の則のフラグ（`vvi_status`・`altitude_hold_status`・`speed_status`）と `altitude_hold_ft`、FMA のピッチを書く。前のピッチの則は段 3 まで FMA の数で枝を選んで飛ぶ。VNAV の engage とサブモードは前の VNAV（monitor の `VNAV_modeSwitch`）が `vnav_state` を 2 以上にしたとき（FMC の段 9 まで）。経路が無いときの前の VNAV の取り消しはモデルを通す（`B747_afds_vnav_lost`）。前のコードの G/S と TO/GA のピッチはモデルの入力（段 1d・1e まで）。照明の V/S・ALT HOLD・FLCH・SPD の灯は VNAV の engage（`vnav_state` が 2 以上）でだけ消える。
- 段 1d（2026-10-27、notes §14）：モデルが LOC と G/S（arm と engage）を持ち、グルーが `autopilot/approach_mode`・`nav_status`・`actual_nav_status`・`glideslope_status`・`actual_glideslope_status` を書く（前の則・灯・autoland・LAND 2/3 が読む）。捕捉の判定は前の条件をグルーが計算してモデルの入力にする（段 2・3 まで）。monitor の LOC の追従（X-Plane の HDG SEL の目標）は段 2 まで残し、その捕捉と arm に戻す処理は外した。`B747_ap_appr_mode` は他の A/P を入れる処理（段 4）と LNAV の X-Plane の HDG SEL だけ、`glideSlopeLOCProgress` は空。
- 段 1e（2026-10-27、notes §15）：モデルが T/O と G/A（ロールとピッチ）、TO/GA スイッチの着地後の抑止、F/D のスイッチ OFF のままの表示を持つ。TO/GA スイッチはエンジンのモジュール（`xtlua` のプラグイン）のコマンドが押した回数（新設 `autopilot/toga_pushes`、両方のプラグインの init・スクリプトで作る）を数え、グルーが増えたのを見てモデルに渡す。グルーは前のコードの `autopilot/TOGA_status` をモデルの状態から毎フレーム書き（前の則と A/T は FMA で枝を選ぶ）、G/A のピッチが入ったときに前の autoland の着陸復行（`autopilot/autoland` -2）を書く。新設 `autopilot/fd/capt/shown`・`fd/fo/shown`（init `B747.70.autopilot`：スイッチ ON か TO/GA の表示）をパネルの F/D のバーのグループと AFDS の表示（FD、モード変化の枠）、FMA を出す条件が見る。エンジンのモジュール・monitor・前のピッチ則（`afds_control`）・逆推力が `TOGA_status` を書いていた処理は外した。
- 段 2a（2026-10-27、notes §16）：純粋なモデル `B747.70.afds_roll_model.lua`（`B747_afds_roll_model`）が、AFDS のモデルのロールのモードから A/P と F/D のロールの指令（HDG SEL・HDG HOLD・ATT・LNAV・TO/GA の則と bank limit・HDG REF）を出す。グルーが `B747_afds_update()` の最後に毎フレーム回し、新設 `autopilot/roll_cmd`・`roll_law`・`roll_valid`（init `B747.70.autopilot`）を書く。油圧のモジュールの `afds_control` は `roll_law` が 1 なら `roll_cmd` を内側のループ（ロールの姿勢の PID）の目標にする。PFD の F/D のロールのバー（`capt_ap_roll`・`fo_ap_roll`）もその指令。X-Plane の HDG のモードは LOC の追従（monitor、段 2b まで）でだけ使う。
- 段 2b（2026-10-27、notes §17）：同じモデルが LOC の捕捉の判定（`loc_capture`：グルーが AFDS のモデルの `loc_detect` に渡す）と LOC の則を持つ。グルーの `afds_loc_inputs` が NAV1 のドット・両受信機の LOC・NAV1 のコース・磁航跡・対地速度・電波高度を渡す。monitor の LOC の追従は外し、X-Plane の HDG のモードはどこでも使わない。
- 段 3a（2026-10-28、notes §18）：純粋なモデル `B747.70.afds_pitch_model.lua`（`B747_afds_pitch_model`）が、AFDS のモデルのピッチのモードから A/P と F/D のピッチの指令（V/S・ALT とその捕捉、前の VNAV の V/S と高度）と MCP 高度の捕捉の判定（`capture`：グルーが AFDS のモデルの `capture` に渡す）を出す。グルーが `B747_afds_update()` でロールの則の後に回し、新設 `autopilot/pitch_cmd`・`pitch_law`（init `B747.70.autopilot`）を書く。油圧のモジュールの `afds_control` は `pitch_law` が 1 なら `pitch_cmd` を内側のループの目標と F/D のピッチにし、前の則の最後の指令と 10 点の平均をそれに合わせておく（G/S などで前の則に戻ったときのため。段 3a の時は FLCH も）。
- 段 3b（2026-10-28、notes §19）：同じピッチのモデルに、速度を昇降舵で保つ則（FLCH・前の VNAV の速度・T/O・G/A）と速度の保護を足した。グルーが速度の入力を渡す：IAS、MCP の窓の速度か前の VNAV の速度、速度テープの `airspeed/Vminm`・`Vmax`、`pfd/pli`（出ているときだけ）、フラップ、GPWS の `gpws/windshear`。計器のモジュール（fltInst02）で X-Plane の `TOGA_pitch_deg` を毎フレーム計算していた `B747_Vs` は外した。`afds_control` の TO/GA の古い分岐は、この則が指令を出さないときだけ X-Plane の値（飛行開始の 8°）を使う。
- A/P の姿勢のループ（2026-10-28、notes §20）：`afds_control` の自動トリムは、昇降舵のサーボの指令を X-Plane の昇降舵の動き（`sim/aircraft/controls/acf_elev_up`・`acf_elev_dn`）で度にし、0.4°（G/S 0.6°）で入れて 0.25° で切る。A/P が入っている間、X-Plane のトリム（`sim/flightmodel2/controls/elevator_trim`）の変化の 1.9 倍をピッチの PID の積分から差し引く（ATA22 p.333 の ELEV TRIM INTEG のスタビライザーの位置）。ピッチの角速度（`sim/flightmodel/position/Q`）の 0.03 倍を昇降舵の指令から引き（ATA22 p.330 の姿勢の変化率）、PID の比例ゲインは全高度で 0.1（`B747.19.xt.hydraulicsmodel.lua` の飛行開始：notes §21）。
- 段 3c（2026-10-30、notes §22）：同じピッチのモデルに G/S の則と捕捉の判定（`gs_capture`：グルーが AFDS のモデルの `gs_detect` に渡す）を足した。グルーの `afds_gs_inputs` が NAV1 の G/S のドット（X-Plane の `nav1_vdef_dots_pilot`、ビームの上が正）・両受信機の G/S と旗・電波高度・対地速度・慣性の昇降率を渡す。`afds_control` の G/S の古い則（`getGlideSlopeFPM`）は外した。A/P が外れている間、`afds_control` はピッチとロールの PID の積分を操縦輪の位置と A/P の指令の和に合わせ（ATA22 p.332、p.348）、`hydraulics_override` はサーボが入ってからの 2 秒の待ちをやめた（`autopilot/ap_monitor/servos_on_time` は書き続けるが、油圧のモジュールは読まない）。
- 段 4a（2026-10-30、notes §24）：AFDS のモデルが multi-channel の arm（`arm`）と engage、autoland の状態（`land`：LAND 3・LAND 2・NO AUTOLAND、`M.status` で状態表示の数）と FLARE・ROLLOUT の arm を持つ。グルーが FCC の電源（`electrical/bus/ac`・`dc`）とセンサー（`irs/nav_valid`・`ra/valid`・NAV1・NAV2 の信号）の数を渡し、状態表示と新設 `autopilot/cmd_armed`（init `B747.70.autopilot`）を書く。照明のモジュールが CMD 灯を `cmd_armed` でも点ける。前の `multi` と、前の autoland の FMA の arm の書き込みは外した。
- 段 4b（2026-10-30、notes §26）：AFDS のモデルが FLARE の engage（gear altitude と慣性の降下率：グルーの `afds_gear_alt` は電波高度 − 2.3 ft − 10 ft × sin ピッチ）、接地からの NOSE LETDOWN（`letdown`）と retard（`retard`：グルーが A/T の FMA を IDLE に）を持ち、ピッチのモデルが FLARE と NOSE LETDOWN の則を出す（`pitch_law` 1 のまま。`afds_control` は FMA のモードが無くても `pitch_law` が 1 なら内側のループを回す）。グルーの `B747_ap_fma` は LAND 3・2 で前の autoland の後に戻らず、ピッチと A/T の FMA を出す（ロールの FMA だけ前の autoland の ROLLOUT：段 4c まで）。前の autoland（`B747.autoland.lua`）の FLARE と A/T の FMA の書き込みは外した。`afds_control` の内側のピッチのループは、比例・積分・姿勢の変化率のゲインを X-Plane の IAS（`sim/cockpit2/gauges/indicators/airspeed_kts_pilot`）で (250 ÷ IAS)²、1〜3 倍にする。
- 段 4c（2026-10-30、notes §28）：AFDS のモデルが ROLLOUT（LOC から電波高度 5 ft の下で engage、A/P を外すまで）を持ち、ロールのモデルが ROLLOUT の則（翼を水平、方向舵の指令 `rudder`：LOC の中心線からの距離と滑走路を横切る速さ）を出す。グルーが 2 台以上のとき新設 `autopilot/rudder_cmd`（init `B747.70.autopilot`）に書き、油圧のモジュールの `hydraulics_override` がペダルとトリムに足して `flt_ctrls/rudder_input` にする（操向のモジュールがそれで前輪を切る）。`autopilot/autoland`（SRM の autoland）はグルーが AFDS のモデルの LAND 3・2 から書く（G/A の −2 は今のまま）。前の autoland（`B747.autoland.lua`）は外した：グルーの `B747_ap_fma` は毎フレームロールとピッチの FMA を出し、`afds_control` の前の則の autoland の枝も外した。

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
