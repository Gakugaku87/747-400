# 進み具合（PROGRESS）

次のセッションは、ここと [PLAN.md](PLAN.md) を読んでから続きに入る。

最終更新：2026-10-24 午後（操縦系統 4-1 段 2a：外側エルロンのロックアウトとラダー比変換器。段 1：フラップの FCU。data block の客室高度の赤い数字の桁と LDG ALT の消去 AIR-18。操縦系統 4-1 の小さな修正。火災防護 3-4。酸素 3-3。防氷・防雨 3-2）

## いまどこか

- フェーズ0-A：完了。
- フェーズ0-B：完了。資料索引・コード構成・acf の比較・ATA 章ごとの notes（20 本）・GAP_ANALYSIS・PLAN・試験の方針・CLAUDE.md を書いた。
- フェーズ1：利用者の許可（2026-10-23 就寝前、「承認は自動でよい、X-Plane での試験も自由に」）により、PLAN.md を私（Claude）が承認して開始した。
- **段階 T（試験の土台）：完了**（コミット 27e8f854）。純正 acf とカスタム acf の両方で基準シナリオが通った。
- **段階 0**：
  - R-2（新しいコードの書き方）：完了（d8adfdd8、ARCHITECTURE.md §9a）。
  - R-1（AFDS のコードを油圧のファイルから切り出す）：完了（5af549c6）。X-Plane なしで全フレーム同じ出力、X-Plane で Lua の誤りなし。
  - R-3（早く効く小修正）：任意。LIGHT-02（サインの memo を選択器の位置で出す）を入れた（2026-10-24）。
- **段階 1**：
  - 1-1（電源）：モデル（4fb1fa46）と、機体への組み込み（f38d0baf。電源モジュール、P5 の灯、EICAS、表示器と時計の電源）まで。X-Plane でカスタム acf の `s02_elec_panel` 63/63・`s00` 64/64、純正 acf の `s02` 63/63・`s00` 64/64。残りは使う側の乗り換え（下）。
  - 1-2（空地判定、PSEU）：モデル・脚モジュールへの組み込み・公開 dataref まで。乗り換え済みは電源の BCU（air mode など）、脚レバーのロック、逆推力のロックアウト（前脚を含む全輪の接地 → 主脚左右の接地）。X-Plane で地上（`s02`、両 acf）と空中（`s01`、カスタム acf）の判定を確認。残りの系統は各作り直しで。
  - 1-3（警報の枠組み）：モデル（001f345e）と、機体への組み込みまで（警報モジュールの新しいグルー、fltInst02 の CANC/RCL と manipulators の master リセットは押した回数の dataref で渡す、メッセージ表のレベルと文言を FCOM に合わせた）。試験はモデル 94 件・モジュール 41 件、X-Plane の `s03_alerts`。STATUS ページと STATUS cue（WARN-17）も済（油圧・空圧・電源が status メッセージを立てる）。残りは下の「警報（1-3）の GAP の状態」。
  - 1-4（油圧）：モデル（0df481e3）と、機体への組み込みまで（油圧モジュールの圧・synoptic・accumulator 計、P5 の灯、EICAS、X-Plane の油圧に故障を書かない、X-Plane の漏れ故障を作動油量で受ける、舵面の系統の組の誤り HYD-06・07）。試験はモデル 94 件・モジュール 68 件、X-Plane の `s04_hydraulics`。残りは下の「油圧（1-4）の GAP の状態」。
  - 1-5（空圧）：モデルと、空調モジュールへの組み込みまで（エンジン 4 基の HPSOV・PRV・PRSOV・始動弁、3 区画のダクトと ISLN、APU 弁、需要に応じたダクト圧、P5 の SYS FAULT・VALVE 灯、EICAS）。前の抽気のコードは外した。試験はモデル 71 件・モジュール 19 件、X-Plane の `s05_bleed`（カスタム acf）。残りは下の「空圧（1-5）の GAP の状態」。
- **段階 2**：
  - 2-1（APU）：制御を 1 つのモデル（状態機械）にまとめ、電源モジュールの中のグルーで回す（ARCHITECTURE.md §4.6）。FCOM の START→ON で始動、ドア全開で starter、60 秒の無負荷 cooldown、自動停止（火災、主タンク 2 の燃料切れ、始動の失敗）と fault の保持、APU・APU DOOR・APU RUNNING、STATUS の N2・油量。試験はモデル 46 件・モジュール 28 件、X-Plane の `s00`（両 acf 69/69）。残りは下の「APU（2-1）の GAP の状態」。
  - 2-3（エンジン）：段 1（始動・点火・燃料弁）を、エンジンごとの状態機械のモデル（`plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua`）とグルー `B747.40.xt.engine_start.lua` で作り直した（ARCHITECTURE.md §4.8）：手動始動と autostart（燃料投入、light-off・hot・hung の検出、地上の再試行と中止、空中は中止せず）、50 % N2 の cutout、点火の条件（START、CON、フラップ、NAI、flameout）と AUTO・STBY IGNITION・電源、エンジン燃料弁（RUN と火災スイッチ、main battery bus）、START VLV・STARTER CUTOUT・FUEL VLV・ENG AUTOSTART・>AUTOSTART OFF・ENG IGNITION・ENG FAIL・>ENG SHUTDOWN。start valve の指令は抽気のグルーが `engines/start_valve_cmd` から読む。試験はモデル 77 件・モジュール 18 件、X-Plane の `s08_autostart`（カスタム acf 38/38。igniter の故障で 2 回目に中止）、`s00`（両 acf 69/69、手動始動）。段 2（EEC）は済（`plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua` とグルー `B747.42.xt.eec_thrust.lua`、ARCHITECTURE.md §4.9）：定格・レバーの指令・max N1/EPR の線、アイドルの選択、ALTN と A/T、推力の制御（実際の N1・EPR を指令に合わせる。前の PID を GE・P&W で置き換えた）、オーバースピード保護と >ENG RPM LIM、ENG-19。試験はモデル 122 件・モジュール 59 件、X-Plane の `s09_eec`・`s10_overspeed`・`s11_takeoff_thrust`（新設）と `s07_cruise_ff`、GE のリバリー（Saudia）でのレバーの段の応答。段 3（表示・逆推力）は済：EGT の色・抑止・始動限界の線、逆推力の電源・地上・ENG REVERSER、オイルと振動の値・赤・メッセージとパネル、小さな誤り（ENG-23・30・35・37）、超過の赤い枠と色（ENG-21）。表示値の作り方（ENG-33）と始動の空気（ENG-38）は推定が主になるので後回し（`B747.40.engine_display_model.lua`・`B747.40.exceedance_model.lua`・`B747.40.reverser_model.lua` とそのグルー、ARCHITECTURE.md §4.10。試験は表示のモデル 82 件・モジュール 46 件、赤い枠のモデル 16 件、逆推力のモデル 22 件・モジュール 21 件、X-Plane の `s08_autostart`・`s11_takeoff_thrust`・`s12_reverser`・`s13_oil`・`s13_oil_ge`）。
  - 2-2（燃料）：モデルまで（`plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua`。タンク・ポンプ・弁の表、FSMC（クロスフィード 2・3、O/J 2・3、予備・スカベンジ・水平安定板タンクの移送）、FJCC（ジェティソン）、マニフォールド（圧力の順位、クロスフィード、吸引供給、shared flow）、量、EICAS、頭上灯）。試験 117 件。燃料モジュールへの組み込みも済（`B747_fuel_system()`。ARCHITECTURE.md §4.7）：前のポンプ・弁・供給源・タンク量・EICAS の処理を外し、頭上の灯は照明モジュールがモデルの出力を読む。APU の DC 燃料ポンプと APU FUEL（APU-11）も。試験はモデル 124 件・モジュール 62 件・照明 37 件、X-Plane の `s06_fuel`（カスタム acf 42/42）、空中の予備・安定板タンクの移送とジェティソン、`s00`（両 acf 69/69）。カスタム acf の燃費（SFC）は、巡航の燃料流量を測って（`s07_cruise_ff`）純正と同じ値にした（前の値では約 25 % 少なかった。ACF_DIFF.md §5）。残りは下の「燃料（2-2）の GAP の状態」。
- **段階 3**：
  - 3-1（空調・与圧・機器冷却）：段 1〜3 まで（`B747.55.pack_model.lua`・`B747.55.press_model.lua`・`B747.55.eqcool_model.lua`・`B747.55.temp_model.lua` とグルー、ARCHITECTURE.md §4.11）。X-Plane の与圧を上書きし、客室はパックの空気と外流弁・漏れ・リリーフ弁の収支で計算する。CPC A/B とモード、FMC の経路からの着陸高度、リミッタ、手動、リリーフ、機器冷却、メッセージ。段 2 で 7 ゾーンの温度制御（トリム空気、backup、ダクト過熱と ZONE RST、comfort correction）と貨物室の温度・暖房。段 3 でカスタム acf の ECS synoptic（ゾーン温度、MASTER、貨物室、外流弁の針と MAN/AUTO、HI FLOW、EXT AIR、パックの OFF/A/B、流れの線）。試験はパックのモデル 61 件・与圧のモデル 99 件・機器冷却のモデル 21 件・温度のモデル 75 件・モジュール 73 件、X-Plane の `s14_press_ground`・`s15_press_cruise`・`s16_temp_ground`・`s17_ecs_synoptic`。段取りと残りは下の「空調（3-1）の段取りと GAP の状態」。
  - 3-2（防氷・防雨）：モデル `plugins/xtlua/scripts/B747.50.xt.antiice/B747.50.antiice_model.lua` とグルー `B747.50.xt.antiice.lua` で作り直した（ARCHITECTURE.md §4.12）。NAI 弁（PRV の下流の抽気で開く、28V DC、過熱のラッチ）、WAI 弁（空中でスイッチ ON、AC bus 2 のモーター、指令と比べる VALVE 灯）、窓の加熱（電源が無ければ INOP、故障のラッチと 10 秒の入れ直し）、プローブの加熱（エンジン運転中、TAT は空中）、氷検知（空中、AC bus 1・3）、ワイパー（28V DC）と、その P5 の灯・EICAS・STATUS。X-Plane の熱・氷検知・ワイパーへは左右別々に、変わったときだけ書く。試験はモデル 47 件・モジュール 174 件・照明 50 件、X-Plane の `s18_antiice_ground`・`s19_antiice_air`。残りは下の「防氷・防雨（3-2）の GAP の状態」。
  - 3-3（酸素）：新しいモジュール `B747.36.xt.oxygen`（モデル `B747.36.oxygen_model.lua` とグルー、ARCHITECTURE.md §4.13）。乗客酸素（約 14,000 ft の自動作動、ON、12,000 ft 未満の RESET、PASS OXYGEN ON と 60 秒の STATUS、サインの強制点灯）、治療用酸素（THERAP OXYGEN ON）、乗員・乗客の酸素圧（前方貨物室の温度で補正、>CREW OXY LOW）、乗員マスク。3D に操作子が無いのでコマンドで操作する。X-Plane の酸素系統を上書きし、乗員マスクで低酸素の効果を抑える。カスタム acf の STATUS ページに酸素圧を出した。試験はモデル 47 件・モジュール 63 件、X-Plane の `s20_oxygen`。残りは下の「酸素（3-3）の GAP の状態」。
  - 3-4（火災防護）：段 1（エンジンと APU）と段 2（貨物室・車輪格納部・ダクトリーク・煙・スクイブ試験）。モデル `B747.35.fire_model.lua` と、火災のモジュールを書き直したグルー（ARCHITECTURE.md §4.14）：双ループの検知（AND と単ループへの組替え、APU は OR、>DET、loop の status、FIRE/OVHT SYS）、エンジンの過熱、消火スイッチのロック（火災・CUTOFF・試験・override）、翼ごとの共用ボトルと squib、X-Plane の消火器、APU の停止と地上の自動放出、APU の消火スイッチ（コマンド）、FIRE/OVHT TEST（TEST IN PROG から 5 秒で PASS/FAIL）、メッセージと灯。段 2：下部貨物室の煙検知（電源投入と試験のときだけの組替え、venturi の吸引）と 2 段の放出（A・B 即時、C・D は 30 分後か接地）、DISCH の灯と >CGO BTL DISCH・>CARGO DET AIR、車輪格納部の火災、BLD DUCT LEAK、化粧室・クルーレストの煙、スクイブ試験。試験はモデル 122 件・モジュール 87 件、X-Plane の `s22_fire_engine_apu`・`s23_fire_cargo`。残りは下の「火災防護（3-4）の段取りと GAP の状態」。

## 次にやること

項目を終えるたびに、[DIFFERENCES.md](DIFFERENCES.md)（実機との違い、全分野。2026-10-23 に利用者の依頼で作った）の該当分野も直す。

1. 承認済みのパネル（カスタム acf）の変更：全部済。3-1 の ECS synoptic の上半分と流れの線（AIR-15、PNEU-11）が最後。PNEU-09（主 EICAS のダクト圧の表示条件）は 3-1 段 1 の data block の条件（FCOM p.585 と ATA21 p.451）で済。承認の一覧に無い 2 件（客室高度の赤い数字の桁、data block の LDG ALT の消去。AIR-18）も、2026-10-24 に利用者の承認を得て入れた。済：`.snd` の警報音、1-3 の PG と 3〜10 ページ、1-3 の STATUS ページと cue、1-4 の HYD synoptic（HYD-19。記号の色と不作動項目の絵は 2026-10-23 夕方に新しい画像で）と RSVR PRESS（HYD-18）、1-1 の synoptic の ISLN・DRIVE の枠・UTILITY と GALLEY の色、STAT のバッテリーの値と CHG/DIS、1-5 のダクト圧の色（PNEU-10）。変更の一覧は ACF_DIFF.md §5、画像は `docs/overhaul/tools/make_synoptic_images.ps1` で作る。
2. 3-1（空調・与圧・機器冷却）：段 1（パックと与圧、機器冷却と ER 開始のスイッチ）、段 2（温度制御と貨物室の温度・暖房）、段 3（ECS synoptic のパネル）は済。残りは故障の入れ方（パック・ファン・機器冷却・温度制御。X-Plane に相当する故障が無い。CPC は `air/fail/cpc` を足した）。AIR-18 のパネルの 2 件も済。
3. 3-2（防氷・防雨）：済（下の「防氷・防雨（3-2）の GAP の状態」）。残りは防氷の推力補正（ICE-11。EEC の補正表の作り直しで PNEU-13 と一緒に）、逆推力中の NAI 弁の閉（ICE-05）、ウォッシャー・防雨剤・WSHLD AIR（ICE-10。3D の操作子が要る）。3-3（酸素）：済（下の「酸素（3-3）の GAP の状態」）。
4. 3-4（火災防護）：段 1・2 は済。残りは M869（脚格納部の APU 火災パネル）と APU のホーンの音、クルーレストの煙での空調の停止、ダクトリークの抽気への影響（PNEU-03）、貨物機の主デッキ（FIRE-19）。
5. 4-1（操縦系統）：小さな修正（FCTL-04・14・19・23）、段 1（フラップの FCU：`B747.45.fcu_model.lua`）、段 2a（SRM のうち外側エルロンのロックアウトとラダー比変換器：`B747.45.srm_model.lua`）は済。次は段 2b（SRM の安定板トリム：手動・ALTN・cutout・制限・速さ・AP との関係・オートトリムの速さ。AP が外れても AP の昇降舵の指令が残る誤りも）、段 3（スピードブレーキ：自動展開と格納、SPEEDBRAKE AUTO、>SPEEDBRAKES EXT と CONFIG GEAR の着陸フラップの条件）。舵面への書き出し（controlObject）は残す。下の「操縦系統（4-1）の GAP の状態」。
6. 2-3（エンジン）の残り：段 1〜3 は済（下の「エンジン（2-3）の GAP の状態」）。後回し：表示値の作り方（ENG-33。EGT は X-Plane の EGT の比例では始動と離陸を両立できず、N1・N2 などから作り直す必要があるが、値は資料に無く推定になる。N1・EPR・N2 の式を変えると EEC の推力の制御の調整もやり直し）、始動の空気（ENG-38・PNEU-08。ダクト圧と starter の関係が資料に無い）、GE の油圧の目盛りと値（CF6 の値が資料に無い）、振動の high band。partial・compact 形式と exceedance cue（ENG-22）は 5-2 で。空中始動の範囲（ENG-24）は資料に値が無く作れない。燃費の離陸・上昇の値（純正と同じにした SFC）を PI.11 の上昇の燃料の表と比べるのも残り。A/T（6-4）との境界は、EEC がレバー → 指令・最大定格・推力の制御まで、FMC の推力基準と A/T のサーボ（レバーを動かす）は 6-4。
7. 1-5（空圧）の残り：故障の入れ方（過熱、過圧、HPSOV・PRV の固着、ダクトリーク）、地上空気の操作、スターターがダクト圧で回ること（エンジン 2-3）。
8. 1-4（油圧）の残り：脚・ブレーキ・ステアリング・逆推力・stab trim・ヨーダンパーの「油圧で動くか」（HYD-09・11・12）は、それぞれの作り直しで、モデルの負荷の表（`B747_hyd_model.LOADS`）を使って入れる。リザーバ与圧の表示（HYD-18）と STATUS のメッセージ（HYD-20）は済。
9. 1-1（電源）の残り：電源の有無を `bus_volts` で見ている系統を、バスごとの dataref（ARCHITECTURE.md §4.1）に乗り換える。どれも後の作り直し（空圧 1-5、空調 3-1、燃料 2-2、IRS と無線、照明、操縦系統 4-1）と絡むので、1-2 と同じく各系統の作り直しのときに行う（2026-10-23 に決めた。利用者の確認待ち）。
   - 済：表示器（fltInst02。機長 PFD・ND は APU standby、upper EICAS は main standby、ほかは F/O transfer）、EICAS の計算（warning。EIU のどれかに電源）、時計の計時（fltInst03・04。main hot battery bus）、ELEC パネルの灯（lighting）。
   - 燃料のポンプと弁も 2-2 で乗り換えた（AC・utility・main battery・hot battery・DC・APU battery・ground service bus）。
   - 残り：IRS と NAV RAD（fms）、表示灯の輝度（lighting：`bus_volts[0]`・`[2]`）、客室灯（lighting）、ヨーダンパー（fltCtrls：`battery_array_on`）。STAT ページのバッテリーはカスタム acf だけ済（純正 acf は X-Plane の値のまま）。
10. 1-2（空地判定）の残り：`onground_any` を読んでいるモジュール（autopilot、fms、fltInst02、fltCtrls、EEC、engines、fuel、hydraulicsmodel、gear の autobrake、manipulators、fdr、lighting など）を、PSEU の dataref（ARCHITECTURE.md §4.2）に乗り換える。どの信号（pri/alt の AIR・GND、前脚圧縮）を使うかは notes/ATA-32.md §4.1 の表。各系統の作り直しのときに行う。防氷（3-2）は乗り換えた（`pri_gnd`）。
11. 1-3 の残り：他のメッセージによる抑止（notes/ATA-31-warning.md §4.4.1）と時間遅れは、各系統の作り直しで表に足す。音（`.snd`）とパネル（PG・3 ページ目以降・STATUS）は済。
12. R-3 は、作り直しが先になる系統の害の大きい誤りだけ、合間に入れる。

## 段階 T の状態

| ID | 状態 | メモ |
|---|---|---|
| T-1 LuaJIT | 済 | `C:\Users\gakug\tools\luajit\bin\luajit.exe`（LuaJIT 2.1.1791988261、MSYS2 公式リポジトリの `mingw-w64-ucrt-x86_64-luajit-2.1.1791988261-1`。SHA256 `1e73f6eb…3e66` を packages.msys2.org と照合）。`tests/syntax_check.sh` で機体の Lua と試験がすべて通る |
| T-2 回帰試験の土台 | 済 | `tests/lib/`（判定、ソースの読み込み、XTLua の再現 `xtlua.lua`）、`tests/static/` の 3 本（26 モジュールすべてが X-Plane なしで読み込み・60 フレームを通ることを含む）、`tests/tools/same_behaviour.lua`（挙動を変えない変更の確認）、`tests/run.sh` |
| T-3 Web API | 済 | `tests/flight/xp.ps1`。名前→ID、読み書き（文字列の dataref は自動で復号）、コマンド、フライト開始、スクリーンショット |
| T-4 FlyWithLua の記録 | 済 | `tests/flight/fwl/B747_flighttest.lua`（版 3）。X-Plane の `Resources/plugins/FlyWithLua/Scripts/` に置いた。55 列（先頭 17 列は `tests_old/data` と同じ。列の出典は TESTING.md §4.2）、約 55 fps で記録できた |
| T-5 シナリオ実行と基準シナリオ | 済 | `tests/flight/run_scenario.ps1`、`s00_baseline_start.json`。カスタム acf・純正 acf とも 56 件すべて合格 |
| T-6 ベースライン | 済 | 下の「作り直し前のベースライン」。出力一式は `tests/flight/runs/`（git 管理外） |

## 作り直し前のベースライン（T-6、2026-10-23）

基準シナリオ `s00_baseline_start`（RJAA 34L、エンジン停止で開始。BATTERY → STANDBY POWER → FUEL CONTROL CUTOFF → APU → APU GEN → 抽気・燃料ポンプ → 4→3→2→1 の順に始動）。

| 項目 | カスタム acf | 純正 acf |
|---|---|---|
| 実行 | `20261023_021753_..._custom`（`-Reload` で読み直し） | `20261023_023824_..._747-400`（X-Plane を起動し直した直後） |
| 判定 | 合格 56・不合格 0・注意 0 | 合格 56・不合格 0・注意 0 |
| 開始時の状態 | BATTERY ON、STANDBY AUTO、FUEL CONTROL は 4 つとも RUN、`bus_volts[0]` 24.0 V（電池だけ） | 同じ（24.0 V） |
| APU 吸気ドアが 20 % 開くまで（selector ON から） | 5.7 s | 5.4 s |
| APU N1 95 % まで（START から） | 56.6 s | 55.9 s |
| 始動前のダクト圧（APU 抽気、L・C・R とも） | 40.6 psi | 40.0 psi |
| START → N2 20 % | 22.6 s（4 発とも） | 22.6 s（4 発とも） |
| N2 20 → 50 %（燃料投入から） | 2〜4 番 24.6 s、**1 番 7.0 s** | 同じ |
| 始動中の EGT の最大 | 2〜4 番 479 ℃、**1 番 301 ℃** | 同じ |
| idle（4 発、20 秒後） | N1 27.2 %、N2 69.7 %、EGT 280 ℃、EPR 1.023 | N1 27.2 %、N2 69.7 %、EGT 280 ℃、EPR 1.020、燃料流量 0.020 kg/s（約 72 kg/h） |
| Log.txt の Lua の誤り | 無し | 無し |

- 記録した値は X-Plane の dataref の値で、まだ資料と照らしていない。資料との比較は各系統の作り直しで行う（例：APU の始動時間は FCOM p.897、エンジン始動は FCOM の 7.30 章と ATA 70〜80）。
- EICAS（両 acf でほぼ同じ。読んだ瞬間による差がある）：
  - 電池だけ：HYD PRESS SYS 1・4（2・3 は出ない）、ELEC AC BUS 1〜4、>FUEL LOW CTR L・R、PARK BRAKE SET、PASS SIGNS ON、ACARS NO COMM。
  - APU 始動後：FUEL PRESS CTR L・R が加わる（純正 acf では >BAT DISCH MAIN も）。
  - APU GEN 投入後：ELEC AC BUS は 1〜2 秒遅れて消える。
  - 主燃料ポンプ ON の後：HYD PRESS SYS 4、>FUEL LOW CTR L・R、PACKS OFF、APU RUNNING。
  - 4 発始動後：FUEL PRESS CTR L・R、PARK BRAKE SET、PASS SIGNS ON、ACARS NO COMM、APU RUNNING、PACKS OFF。
  - FUEL PRESS CTR と >FUEL LOW CTR が場面ごとに入れ替わる（中央タンクのポンプのスイッチは触っていない）。燃料系の作り直しで確かめる。

## 夜の間に自分で決めたこと（利用者の確認待ち）

- PLAN.md を承認してフェーズ1に入った（利用者の許可による）。
- カスタム acf `747-400_custom.acf` と、その音の定義 `fmod/747-400_custom.snd` を `.git/info/exclude` で git の管理外にした。元に戻すのは簡単（exclude の行を消す）。コミットするかは利用者が決める。（朝、利用者の指示で git に入れた：936222b0）
- `fmod/747-400_custom.snd` は `fmod/747-400.snd` の複製（利用者の提案）。カスタム acf で X-Plane 標準の音になっていた問題への対処。機体を読み直すと機体の FMOD バンクが読まれることを Log.txt で確かめた。今後 `.snd` を変えるときは、複製も同じにする。
- LuaJIT を上記のとおり導入した（利用者の許可あり）。
- FlyWithLua の記録スクリプト `B747_flighttest.lua` を X-Plane の Scripts フォルダに置き、版を上げるたびに写した（版 3）。747 以外の機体では何もしない。
- FlyWithLua 付属の `please read the manual.lua` は、スクリーンショットに吹き出しを出すが、利用者のファイルなので消していない。要らなければ消してよい。（朝、利用者が消した）
- X-Plane を起動し、Web API で両方の acf のフライトを開始して試験した。X-Plane が「応答なし」で止まったとき、`Log.txt` を残してから強制終了し、起動し直した（下の「気づいたこと」）。
- `.gitattributes` を足し、`tests/*.sh` を常に LF で取り出すようにした（CRLF だと bash が動かない）。対象はこの 2 本だけ。
- git の作者：この PC には `user.name`／`user.email` が無いので、旧フォークと同じ作者をコミットごとに `-c` で渡している（設定は変えていない）。
- 1-1 の残り（電源を使う側の乗り換え）は、空圧・空調・燃料・IRS・照明・操縦系統の作り直しと絡むので、1-2 と同じく各系統の作り直しのときに行うことにした（次にやること 2）。
- 警報の組み込みで、CANC・RCL・master リセットを「押した回数」の dataref（新設 3 本）で警報モジュールに渡すことにした（プラグインやモジュールが別で、Lua の状態を共有できないため。ARCHITECTURE.md §4.3）。
- 油圧の組み込みでは、X-Plane 自身の油圧に故障を書かないことにした（notes/ATA-29.md §6.1 の推奨）。X-Plane の油圧はいつも加圧され、脚・ブレーキ・ステアリングの油圧による制限は、それぞれの作り直しでモデルの出力を使って入れる。X-Plane の故障メニューの漏れ（`rel_hydleak*`）は作動油量を減らす形で残した。
- 油圧の組み込みは作業用のローカルブランチ `wip/hyd-integration` で進め、X-Plane の試験が通ってから `overhaul` に 1 つのコミットにまとめて取り込んだ（朝に途中の状態の機体が読み込まれないように）。

## 決まったこと（2026-10-23 朝、利用者の回答）

PLAN.md §3 に書いた。要点：

- カスタム acf のパネルの変更（GAP_ANALYSIS.md §4）と `.snd` の警報音の結線の変更は承認。パネルは系統ごとの作業で、CLAUDE.md の手順（バックアップ、前後の値、外観のスクリーンショット）に従って直す。純正 acf は変えない。
- 機体側は 109 を基準、エンジン側はエンジン型式で選ぶ。`freighter` は貨物機の項目を 405・570 から。RR は PW と同じ扱いで残す。
- 推定で作った値（下の一覧）は承認。「推定」の印は残す。
- カスタム acf と `747-400_custom.snd` は git に入れた（936222b0）。`overhaul` は origin に push してよい。
- FlyWithLua の `please read the manual.lua` は利用者が消した。
- upstream（本家 mSparks43）には push しない。push は origin（Gakugaku87/747-400）だけ（利用者、2026-10-23 昼）。upstream の push 先は `no_push` にした（戻すときは `git remote set-url --push upstream https://github.com/mSparks43/747-400.git`）。
- push は origin の `overhaul` と `master`。`master` は `overhaul` と同じ中身にした（旧フォークの履歴を親に残すマージ。強制 push はしない）。本家に PR は作らない（利用者、2026-10-23 午後。CLAUDE.md）。
- PLAN の次の項目（フェーズ）に移るときは、承認を求めずに進める。区切りごとの結果の報告は続ける（利用者、2026-10-23 昼）。
- パネルの画像は、違和感のない範囲なら新しく作ったり直したりしてよい（利用者、2026-10-23 夕方。油圧・電源の synoptic の分を聞いたときの答え）。

## 推定で作った部分

- 試験の許容幅（`s00`・`s01` の数値の幅）は推定。シナリオに「推定」と書いてある。
- 電源モデル（1-1。`B747.03.elec_model.lua` に「estimate」と書いてある）：
  - バッテリーの負荷電流（main battery bus 12 A、main inverter 28 A、APU battery bus 8 A、APU inverter 15 A、APU starter 250 A など）。資料に値が無いので、バッテリー 1 個で standby bus を約 1 時間保つように決めた（FCOM p.804 は「最低 30 分」）。
  - BAT DISCH の表示までの遅れ 60 秒（FCOM p.181 は「最大 3 分」とだけ書く）。
  - バッテリー電圧の曲線（放電で 25→22 V）。
  - DRIVE 灯：IDG の回転が on line の回転未満で点く（油圧が回転で立つとみなした）。
  - DRIVE DISC：エンジン停止中に押しても切れない（実機は「不完全」）。
  - ELEC GEN OFF n を、同じ番号の ELEC AC BUS 表示中は出さない。
  - 中央 CDU の電源（資料に無い）：今までどおり F/O transfer bus。
- 空地判定（1-2。`B747.10.pseu_model.lua`・`B747.10.xt.pseu.lua` に「estimate」と書いてある）：
  - トラックの「傾き」：X-Plane の `eagle_claw_angle_deg` が 4° を超えたら傾き（X-Plane には傾きセンサーが無い）。この角度は胴体に対するトラックの角度で、空中は acf の 8°（胴体脚）・58°（翼脚）、地上は機体の機首下げの角度（駐機 0.85°、強いブレーキで 1.75°、機首上げで負。2026-10-24 に測った）。前の 1° では、滑走中の機首下げで AIR になっていた（「気づいたこと」）。
  - 前脚圧縮：前輪の接地（`on_ground[0]`）。実機は strut が 8 in を超えて縮んだとき。
  - HYDIM 1・4 の「高圧」：1,500 psi 以上（資料に値が無い）。
  - 胴体脚ステアリングの「ロック」：胴体脚の車輪の角度が 0。
- 乗員への警報（1-3。`B747.87.alert_model.lua`・`B747.87.xt.alerts.lua` に「estimate」と書いてある）：
  - モデルを回す周期 0.1 秒（資料に値が無い。前は約 2 秒ごと）。EIU が電源投入から 4 秒で動き出すのは前の値のまま。
  - 始動中の抑止の終わりの「アイドル到達」：N2 60 %（CF6 の min idle は 61.6 %：ATA70_80 p.206。PW の値は資料に無い）。
  - 離陸の抑止は、地上で 30 kt 未満になった後の離陸滑走でだけ働く（着陸滑走で 80 kt を逆向きに通るのを離陸と取らないため）。
  - CONFIG GEAR のサイレンは master リセットで止まらない方にした（原因がレバーかフラップかを、メッセージだけでは区別できない。FCOM p.1551）。
  - wailer は >AUTOPILOT DISC の表示中、最低 1 秒（表示を消すのは AP の側）。
  - beeper のある advisory（BLEED ISLN L・R、BLEED HP ENG）の beeper は、caution と同じ抑止（始動前・離陸・着陸など）で待たせる（FCOM に記載なし）。
  - STATUS cue の「エンジン始動から」の抑止は、地上で FUEL CONTROL のどれかが RUN になったときから。地上で全部 CUTOFF に戻ったら解く（FCOM は「エンジン始動からリフトオフ 30 分後まで」とだけ書く）。
  - STATUS ページのメッセージの文字は白（FCOM・LH24 の図は白黒で、色の記載が無い）。配置は LH24 p.65 の図（バッテリーの値の下、舵面の図の左）に合わせた。
  - 油圧の HYD PRESS DEM（status）は、そのエンジンの N2 が 50 % 以上のときだけ（資料は「エンジンが止まっている間は出さない」とだけ書く）。
  - 電源の DRIVE DISC n（status）は、IDG が切り離されている間だけ出す（実機の EIU は CMC で消すまで残す。CMC が無いので簡略化）。
  - HYD synoptic の記号：ATA29_32 p.105-106 の「ON（白）」は、空の記号（文字なし）にした（FCOM p.1486 と ATA29_32 p.107 の図は、圧を出しているポンプを文字なしで描く）。ON（琥珀）なども文字なしの色付きの記号と読んだ（2026-10-23 夕方に色付きの画像を作った）。
  - HYD synoptic の不作動項目：系統を「失った」とみなすのは系統圧低（HYD PRESS SYS と同じ、1,200 psi 未満が 2 秒。FCOM は「系統の故障」とだけ書く）。系統 1・4 の一覧の中身と順は純正の絵のまま（FCOM の図は系統 2・3 だけ）、THRUST REV は FCOM の図と同じく最後に置いた。組の項目は負荷の割り当てから出した（FCOM が例に描くのは 2+3 だけ）。ブレーキ（正規は系統 4、代替は 1、だめなら 2）は 3 系統の組 1+2+4 の「BRAKES」とした。RR の逆推力は資料が無いので GE と同じく THRUST REV を出さない。組の絵の置き場所（短い組を下、長い組を上）と、4 系統すべてを失ったときに交わる線の切れ目は自分で決めた。
  - HYD synoptic の圧の低（EDP の ON 琥珀、DEM の AUTO・ON 琥珀、AUX の状態）は、P5 の灯と同じく圧力スイッチが 2 秒続いてから（資料に記載なし）。EDP は資料どおりスイッチと圧だけで決めるので、エンジン停止中は ON 琥珀（空の記号）。
  - AUX の記号：資料は白と琥珀に同じ条件（AUX で EDP 圧低）を書いているので、AUX ポンプが動いていれば白、動けない（空中、ground handling bus なし）なら琥珀とした。系統 4 を AUX にしたとき、DEM の丸は OFF（琥珀）（FCOM p.1486 の図）。
  - RSVR PRESS の位置（各リザーバの右、上寄り）は FCOM p.1486 の図に合わせて目で決めた。
  - APU（2-1）：ドアの開く時間 12 秒、APU DOOR の 20 秒、ドアを閉じる N1 10 %、始動の打ち切り 120 秒、selector OFF で N1 95 % 超が続くときの APU の 10 秒、N2 = N1 × 0.926、油量 1.00/0.92、ドアにはバッテリーが要る、cooldown では発電機も使えない、主タンク 2 が空で燃料切れ（いずれも資料に数値・記載が無い）。
  - ELEC synoptic の DRIVE TEMP/PRESS の枠は、P5 の DRIVE 灯と同じ条件（IDG の油圧低。エンジン停止中と IDG を切り離した後も出る）。エンジン停止中の枠は資料に記載が無い（FCOM p.792 の条件「IDG の油温高か油圧低」をそのまま当てた）。
  - memo が最後のページに入りきらないときは、memo だけのページを作る（FCOM に記載なし）。
  - 火災ハンドルを「引いた」とみなすのは、動きの途中の値 `pos_arm` が 0.5 を超えたとき。
- 油圧（1-4。`B747.19.hyd_model.lua` に「estimate」と書いてある）：
  - 舵面などが「油圧で動く」とみなす圧 1000 psi（資料に無い。前のコードは 900 と 1000）。
  - demand pump の圧力スイッチの解除 1600 psi（EDP の値を流用）。ADP の 10 秒タイマーは「空中でフラップが上がってから 10 秒運転を続ける」とした（論理図からタイマーの種類が読めない）。
  - HYDIM-3・4 と ACMP 3 の制御の DC バス、ADP 1＝左ダクト・4＝右ダクト（資料の 1・2 系統の図からの対称）。
  - EDP の流量は N2 に比例。EDP を減圧するソレノイドは DC bus n（バスは資料に無い）で、DC が無いと加圧する。
  - 系統の漏れ 0.5 gpm、ADP のタービンが要るダクト圧 5〜15 psi、圧の立ち上がり 0.5 秒・減衰 4 秒、accumulator の充圧 1 秒。
  - 油温：ポンプが回っていれば外気温 ＋30 ℃ に 600 秒で近づく（FCOM の例が 50 ℃）。リザーバの与圧は抽気が無くなってから 300 秒で抜ける。
  - ブレーキ源の系統 2 の切替圧 1500 psi。accumulator の計器は予圧 750 psi より下がらない。HYD CONTROL 1・4 は HYDIM 1・4 の電源喪失で出す。
  - 組み込み（`B747.19.xt.hyd_power.lua`）：舵面が差し引いた圧（前からの作り）を流量に直す係数 0.03 gpm／(psi/s)、パーキングブレーキを 1 回掛けるのに accumulator から使う作動油 20 in³、フラップが「動いている」「出ている」とみなす角度 0.2°・0.5°。
  - エンジン始動中、EDP の圧は N2 が 10 % 前後で立ち、ENGINE PRESS 灯が消える（上の推定「流量は N2 に比例」「漏れ 0.5 gpm」の結果。どの回転で消えるかは資料に無い）。
- 空圧（1-5。`B747.55.bleed_model.lua` に「estimate」と書いてある。資料に式も値も無い部分）：
  - 流量は「パック 1 台＝1」の単位。エンジン 1 基が出せる量は N2 50 % で 0、90 % で 4.0（idle の 65 % で 1.5、70 % で 2.0。FCOM p.183 の「クロスブリード始動は供給側を 70 % N2 に」に合わせた）。APU は 42 psi・3.2（3 パックは賄えるが 3 パックと始動は賄えない：FCOM p.895）。地上空気 3.0。使う側はスターター 1.8、主翼防氷 0.5、ADP 0.3。
  - ダクト圧は、使う量が出せる量いっぱいのとき 30 % 下がり、超えると（出せる量／使う量）² で下がる。ダクト圧の遅れ 1 秒。
  - エンジン側の圧（PRV の下流）は N2 25 % で 0、65 % で 60 psi。PRSOV の調圧 45 psi は資料の値（LH36 p.64）。
  - 始動に要るダクト圧は、海面で 25 psi、1,000 ft ごとに 1 psi 下げる（FCOM p.183 の地上空気 30 psi から）。始動弁は、そのスターターの流量を足してもダクト圧がこれを満たすなら開き、始動の指令が終わるかダクト圧が 10 psi 未満になるまで開いたまま。スターターの流量は始動弁が開いているエンジンの分だけ数える（START を何本引いても、空気が足りる分だけ開く）。
  - ISLN と APU 弁が動く時間 2 秒。モーターの電源（AC）が無いと、その位置で止まる（LH36 p.86-87 に記載なし。GAP の推定のとおり）。APU 弁は、制御の DC bus 2 が無いと閉じる方へ動く（資料に記載なし）。
  - エンジンの HPSOV・PRV・PRSOV は、ASCTU の DC bus が無いと最後の位置のまま（ラッチ式のソレノイド。ATA30_32_35_36 p.20・p.66 の記載どおり）。電源が戻ったら、スイッチの位置に合わせて動く（実機の ASCTU はスイッチが変わったときにパルスを出すので、電源が無い間にスイッチを動かした場合は違いうる。簡略化）。
  - HPSOV は N2 85 % 未満で開（高圧段との切替の近似。ダクト圧には効かせていない）。
  - PRSOV と始動弁の動きの見かけ（アニメーションの速さ 20）は前のまま。
  - ECS synoptic の EXT AIR（3-1 段 3 で足した）：「ダクトに圧」は 5 psi 以上、「消えた後も少し」は 5 秒、「APU とエンジンが止まっている」は APU が回っていない・各エンジンが 50 % N2 未満。
- 燃料（2-2。`B747.28.fuel_model.lua`・`B747.25.xt.fuel.lua` に「estimate」と書いてある）：
  - 流量：予備タンクから主タンクへ 3,000 kg/h（各タンク、重力）、主 1・4 から 2・3 へ 4,000 kg/h、安定板タンクのポンプ 4,500 kg/h、ジェティソンはポンプ 1 台 22,000 kg/h（CWT 2・O/J 2・安定板 2 で約 130 t/h）、ジェティソン時間の最初の見積もり 120,000 kg/h、APU の消費 150 kg/h。
  - ポンプの電源：utility bus の番号と、ほかのポンプの AC バスの割り当て（資料は utility bus に載るポンプしか書かない）。
  - 圧力の順位で、CWT ポンプ 1 台と主ポンプ 1 台の比べ方（資料は主ポンプ 2 台に勝てないとだけ書く）。
  - xfeed 2・3 のフラップの離陸範囲（7.5〜22.5 units）を flap_ratio の 0.42〜0.75 に換算。
  - 安定板タンクのポンプが低圧で止まるまで 30 秒（FCOM は「短い遅れ」）。APU FUEL の弁の不一致は 10 秒（xfeed と同じ）。
  - 地上でスイッチ OFF のときも FUEL PUMP のメッセージを出す（低圧なので。資料に記載が無い）。
  - synoptic のエンジンへの流れは spar valve が閉なら出さない。安定板タンクの移送弁（モデルに無い）はポンプが回っているとき開と表示。
  - 外から変わったとみなすタンクの量 20 kg、フライト開始後に落ち着かせる 2 秒。
- エンジンの始動（2-3 段 1。`B747.40.engine_start_model.lua` に「estimate」と書いてある）：
  - PW の値：autostart の燃料投入 20 % N2、EGT の start limit 535 ℃・takeoff limit 654 ℃（前のコードの値。資料に無い）、ENG FAIL の 52 % N2・STARTER CUTOUT（54 % N2、5 秒）・START VLV（8 秒）・FUEL VLV（5 秒）は CF6 の値を PW にも使う。
  - hot start は EGT が start limit の 25 ℃ 手前、hung start は N2 の上がり方が 0.15 %/s 未満で 15 秒（CF6 の空中始動の値を地上にも）、始動の終わりは N2 55 % 以上で上がり方 0.15 %/s 未満が 5 秒。
  - 109 の AUTO IGNITION 1・2 は autostart ON のとき始動ごとに交代（FCOM は「交代」とだけ書く）。シムの AUTOSTART スイッチは 1 個で、全エンジンに効く（109 は 4 個）。405（PW の貨物機）には autostart が無いとした。
  - >ENG SHUTDOWN は地上では出さない。master CAUTION の灯を点けない扱い（FCOM）はまだ（警報モデルに属性が要る）。
  - X-Plane の starter は N2 60 % を超えたら放す（空気がまだ回していても）。
- EEC（2-3 段 2。`B747.42.eec_model.lua`・`B747.42.xt.eec_thrust.lua` に「estimate」と書いてある）：
  - 離陸の定格は FCOM PI の着陸復行の表で代用（FCOM に通常モードの離陸の表が無い。ALTN の離陸と着陸復行の表は同じ推力、PI.15.6）。表は 10,000 ft までなので、その上は 10,000 ft の値のまま。
  - 最大連続の定格（PI.13.1・PI.23.1。高度・速度・TAT の表）は入れず、最大上昇の値で代用。定格の切り替わりの幅（17,000〜18,000 ft、293〜300 kt、22,000〜25,000 ft）は ATA の数値の間を直線で混ぜた。P&W は CF6 と同じ論理とした（P&W の EEC は資料に無い）。
  - レバーのアイドル端の指令は前の値（GE は N1 25 %、P&W は EPR 0.95）。実際のアイドルより低くして、アイドルでは必ず X-Plane のアイドルに戻るようにした。
  - RR は資料が無いので、前の推力の論理のまま（EPR の目盛りが P&W と違うので P&W の表は使わない）。
  - ALTN：指令の上限は、その高度で一番大きい定格（表の角の値、抽気の補正なし。CF6 の hard reversionary が角の温度を使い気圧だけ補正する、ATA70_80 p.205・p.207 から）。P&W は CF6 と同じとし、制御量は EPR のまま（実機は N1 に替わる）。P&W の >ENG LIM PROT は指令が最大定格の 0.01 手前を超えたとき（FCOM は「近い」とだけ書く）。代替モードでも上の EICAS の最大線は normal の定格。
  - アイドル：空中で条件が終わったときも 5 秒保つ（CF6 の回路図から。FCOM は接地後の 5 秒だけ書く）。X-Plane のアイドルの値（approach 2.625、minimum は外気温の式）は前のコードのまま。空中の minimum idle も地上と同じ外気温の式（前は空中で値を変えなかった）。X-Plane のアイドルは全エンジンで 1 つなので、1 基だけ approach の条件でも全部 approach idle になる。着陸フラップはフラップレバーの 23° より先（ATA は実際のフラップ角）。
  - オーバースピード保護：赤線の手前 0.5 % で止める余裕、2 % の帯、制限ループのゲイン（GE は N2 1 % あたり N1 0.6 %、P&W は EPR 0.01）、RPM LIM を出す押さえ込みの量（GE は N1 0.2 %、P&W は EPR 0.005）。P&W の赤線（N1・N2 とも 111.4 %）は資料に無く、表示が赤くなる値（前のコードと acf の計器）に合わせた。
  - EGT の表示（2-3 段 3）：P&W と RR の限界（始動・連続・離陸）は資料に無く前のコードの値（P&W 535・629・654、RR 600・733・785 ℃）。RR の琥珀の抑止は P&W と同じとした。始動限界の線は「所定の N2 まで」（FCOM）を、始動モデルの始動完了（アイドルで N2 の変化が 0.15 %/秒未満で 5 秒）までとした（CF6 は ATA70_80 p.356-357 で min idle が安定するまで。前のコードの CF6 の始動限界 870 ℃ は使わない）。
  - 逆推力（2-3 段 3）：P&W の逆推力が動ける油圧は、油圧モデルの「負荷に油圧がある」1,000 psi に合わせた（資料に値なし）。RR は資料が無く P&W と同じ（油圧）とした。動けない逆推力を保つ位置の境目（展開 0.5 より先なら展開のまま）、ENG n REVERSER の 2 秒（CF6 は ATA70_80 p.473-475 の DPV 圧と指令の食い違い 2 秒。P&W は同じとした）。
  - オイルと振動（2-3 段 3）：P&W・RR の油圧の赤線 70 psi と油温の琥珀 160 ℃（前の値とパネルの値。資料なし）。GE の油圧の琥珀の上端が「全出力」で 34 psid になる N2 を 112 % とした。表示の油圧・油温は X-Plane の値にエンジンごとの差（100 % N2 で 1〜6 psi、1〜10 ℃）を足す。油量はタンクの 33〜37 L から運転中は 7〜11 L 引く（N1 15 % で全部。前の値）。巡航（GE の油量の差）は空中でフラップ上げ。振動は音源ごとに 100 % で 0.2〜1.2（読み込み時に決める）で回転の 2 乗。RR の振動の音源は P&W と同じ。
  - 小さな誤り（2-3 段 3）：地上の始動中だけ X-Plane のスプール時間を 26 秒にする（X-Plane のスプール時間は全エンジンで 1 つ。空中は EEC の推力の制御のため 5 秒のまま）。燃料投入の印の火災スイッチの条件は CF6 の資料（ATA70_80 p.346）で、P&W・RR も同じとした。
  - 超過の赤い枠と色（2-3 段 3）：P&W の EPR の帯が赤になるのは最大 EPR の 0.003 下から、白に戻るのは 0.01 下（EEC が最大 EPR の ±0.002 に保つため）。RR の EPR は P&W と同じ。P&W・RR の N1・N2・N3 の赤線はパネルの前の値（P&W は 111.4 %、RR は N2 109.5 %・N3 101.5 %。RR の N3 の数字は 111.4 % だったので帯にそろえた）。赤い枠の記録は新しいフライトで消す（実機は整備で消す）。CF6 の N2 の 20 秒は CF6 だけ（P&W は資料なし）。
  - 推力の制御：X-Plane のスロットルを燃料の計量とみなした作り。ゲイン（積分 2/秒、誤差の変化 3）、追う値の時定数 1.5 秒と速さの上限（P&W 0.15 EPR/秒、GE は上げ 15・下げ 5 %N1/秒。GE の下げを遅くしたのは X-Plane のエンジンが絞り切ったあと上げに転じるのに 3 秒ほどかかり、目標を 10 % 下回ったため）、表示値のスロットルに対する傾きの表（X-Plane で 8,000〜13,500 ft・M.42〜.49 で測った）。X-Plane のスプール時間は、エンジンのモジュールが 4 基運転中に 5 秒へ書き換えていて（ENG-35）、この値のもとで合わせた。ENG-35 を直すときは段の応答を測り直す。指令に届かないときに X-Plane の最大推力を足す仕組み（前のコード）は残し、条件を「スロットル 1 で目標より P&W 0.005・GE 0.2 % 低い」にした。
- パックと与圧（3-1 段 1。`B747.55.pack_model.lua`・`B747.55.press_model.lua`・`B747.55.xt.bleed.lua` に「estimate」と書いてある）：
  - 巡航の客室高度：FMC 巡航高度で ΔP 8.8 psi になる高度（上限 8,000 ft、下限は出発地と着陸地の場の高度の低い方）。FCOM p.585 の表示例（客室 6,250 ft、ΔP 8.8）が標準大気で FL390・ΔP 8.8 に一致するのと、ΔP 8.9 は表示が琥珀になることから。ATA21 は「最大 8.9 psid、できるだけ低く」とだけ書く。制御の上限は 8.9。
  - FMC の時間の情報が無いので、上昇の目標は離陸地から巡航の客室高度へ機体の上昇（気圧の比）に比例、降下の目標は降下の始まりから着陸地の 50 ft 下へ機体の降下に比例させた。FMC の降下の率の上限 750 sea-level fpm。sea-level fpm を全部の率（500、300、2,000 fpm）に使った。
  - 巡航の前に 1,000 ft 降りたら descent（ATA は巡航からの降下だけ書く）。降下中に 500 ft 上がったら climb。
  - 客室の容積 1,000 m³、客室の空気 24 ℃、パック 1 台の high flow 1.2 kg/s、外流弁 1 個の全開の有効面積 0.1 m²、胴体の漏れ 0.004 m²、正圧リリーフ弁の面積 0.05 m²（9.25 psid から 0.25 psi で全開）、負圧リリーフドア 0.3 m²、X-Plane の減圧の故障（slow 0.01 m²、fast 0.6 m²）。
  - 外流弁の速さ：自動（AC モーター）全行程 6 秒（10 秒では離陸の瞬間に客室が 50 ft 上がった）、手動（DC モーター）20 秒。目標へ近づく時定数 20 秒。
  - CPC の故障の判定（2,000 fpm で機体が水平）は 5 秒続いたら。他方も同じ状態なら引き継がない（減圧で両方が故障にならない）。故障は電源を切るまで残る。
  - LDG ALT の MAN は AUTO の値から始める。ノブの dataref の 1 は 50 ft。
  - 空中でフライトを始めたときは、その高度を巡航高度として客室を巡航のスケジュールに置き、機体が落ち着く（昇降率 1,000 fpm 未満、最長 60 秒）まで置き直す（X-Plane の空中開始は約 41,700 ft・速度ほぼ 0 で現れて 35,000 ft まで落ち、その降下を descent と取っていた）。フライトの最初の 3 秒は対地高度 50 ft 未満なら地上として客室を外気に合わせる（XTLua の最初の読み取りが 0、空地判定が遅れることがある）。
  - パックの流量の単位：high flow のパック 1 台＝1（抽気のモデルの地上での推定に合わせた）。normal は 2/3（ATA21 p.86）。パックの弁の全行程 3 秒。スケジュールの切替の順はパック 1・2・3。HI FLOW・リリーフ・火災などで high にするときと、スイッチ OFF・故障でファンを止めるときは間を置かない（資料が間を置くと書くのはスケジュールの切替だけ）。HI FLOW でパック 3 台が high のとき止める 2 基は下のファン。再循環ファンは AC のどれかで回る。
  - X-Plane へ：ダクトの空気＝ダクト圧 ÷ 27.5（上限 1.5。上書き前の X-Plane 自身の値に合わせた）、エンジンの抽気の損失＝出す流量 × 1 ℃（3 パック・4 基 idle での X-Plane 自身の値 0.7〜0.8 ℃ に合わせた）、APU は × 15 ℃（始動中の X-Plane 自身の値に合わせた）。
  - PRESS RELIEF は FCOM の「全パック運転中」を「パックの選択器が 3 つとも OFF でない」と読んだ（リリーフでパック 2 は止まるため）。UPR・LWR PRESS RELIEF（status）は 2 つの弁が同時に開くとした。
- 機器冷却（3-1 段 1。`B747.55.eqcool_model.lua` に「estimate」と書いてある）：OVRD の差圧スイッチ 1.0 psi（資料に値なし。地上では差圧が無いので OVRD で EQUIP COOLING が出る）、OVRD で客室から抜ける空気 0.25 kg/s（ΔP 8.8 psi のとき、差圧に比例）、ファンと弁のモーターはどれかの AC で動く（バスは資料に無い）、スキンの温度は外気温。ER 開始の EQUIP COOLING は NORM（FCOM の準備の手順の位置）。
- 温度（3-1 段 2。`B747.55.temp_model.lua` に「estimate」と書いてある。資料に動特性が無い部分）：
  - 熱のつり合い：客室の熱の負荷 70 kW（空中かエンジン運転中。地上で AC があればエンジン停止で 30 kW、AC が無ければ 0）、スキン 0.8 kW/K（外は TAT）、地上でエンジン停止・パックの空気なしならドアが開いているとして 3 kW/K を足す、客室の熱容量 5,000 kJ/K、空気 1.005 kJ/kg/K、パックの空気は与圧のモデルの 1.2 kg/s（high flow 1 台）、再循環ファン 1 基 0.7 kg/s（1360 cfm）。ゾーンの配分（空気・スキン・熱容量）F/D 0.03・U/D 0.10・A 0.09・B 0.17・C 0.22・D 0.22・E 0.17、熱の負荷の配分 0.033・0.10・0.08・0.16・0.22・0.23・0.177（F/D が最も冷たい空気を要し、A が最もトリム空気を使う）。
  - 制御：ZTC はゾーンの誤差 1 ℃ あたり供給を 3 ℃ 変える、供給の上限 160°F（ダクトのセンサーの範囲）、トリム空気の弁の全開で供給を 120 ℃ 上げる、パックの出口の遅れ 20 秒、ダクトのセンサーの遅れ 10 秒。中央ダクトが 12 psi 未満ならトリム空気と後方暖房は無い（メッセージは出さない）。ZTC は AC のどれか、master trim air valve は DC のどれかで動く。
  - 始め：エンジン停止の開始は客室・貨物室とも外気温（TAT）、エンジン運転中か空中（対地 50 ft 超）の開始は target と、貨物室はつり合いの温度。最初の 3 秒は置き直す（XTLua の最初の読み取りが 0 で、バスと機器冷却の排気が読めない）。X-Plane の空中開始は速度ほぼ 0（TAT が外気温に近い）から始まるので、貨物室は巡航のつり合いより冷たく始まり、30〜50 分で近づく。
  - comfort correction：働いている間に PASS TEMP を回すと 0 にして、その便ではもう使わない（資料は「選び直すと上書き」）。cruise clamp の normal flow を待つ「客室の温度」は U/D・A〜E のそれぞれ（backup は平均）。下の再循環ファンもパックと一緒に待つ。
  - 貨物室：熱容量 2,000 kJ/K、客室へ 0.4 kW/K、スキンへ 0.3 kW/K、機器冷却の排気 0.5 kg/s（客室より 15 ℃ 暖かい）、前方のヒーター 2 本で 3 kW、後方暖房 10 kW、後方の選択温度 40°F（スイッチは bulk 貨物室の中）、後方のサーモスタットと過熱スイッチの幅 1°F。後方暖房の「エンジン運転中」はどれか 1 基。
- 防氷・防雨（3-2。`B747.50.antiice_model.lua`・`B747.50.xt.antiice.lua` に「estimate」と書いてある）：
  - NAI 弁：開くのに要る抽気 12 psi（前のコードの値）、全行程 1 秒、ソレノイドはそのエンジンの DC バス。NAI ダクトの過熱は X-Plane の inlet heat の故障で受け、スイッチを切るまで閉じたまま（資料は「スイッチを一度切る」）。
  - WAI 弁：モーターの全行程 2.5 秒（資料は 3 秒未満）。地上でスイッチ ON のとき VALVE 灯は点かない（回路が指令と比べるため）。X-Plane の surface heat の故障で弁がその位置で止まる。
  - プローブ：左のプローブは AC bus 1、右は AC bus 2。X-Plane に AUX のプローブが無いので、L AUX を X-Plane の予備のピトー、R AUX を予備の静圧孔に当てた。地上の減電力（資料にある）は作っていない（X-Plane に違いが出ない）。
  - 窓：風防 L・R の 115V AC と 28V DC は bus 1・2。側窓は AC のどれかで加熱。
  - 氷検知：>NO ICING は、空中で氷を検知したあと検知しなくなり、防氷が入っている間、着陸まで（FCOM は「氷を検知しなくなった」とだけ書く）。X-Plane の氷検知の故障は 2 個とも。
  - ワイパー：28V DC は bus 1（L）・2（R）。速さは X-Plane の 50・100 %（acf の最大が毎秒 2 回なので、実機の LO 160・HI 250 回/分より遅い。acf は変えていない）。
- 酸素（3-3。`B747.36.oxygen_model.lua`・`B747.36.xt.oxygen.lua` に「estimate」と書いてある）：
  - フライトの開始で、ボンベは満充填（70°F で 1850 psig。資料に出発時の値が無い。FCOM p.455 の例は 1850 と 1850）。ボンベの温度は前方貨物室の温度とした。
  - 使う量：乗員マスクを出している間 0.06 psi/秒（2 人で約 6 L/分。114 ft³ のボンベで約 6 時間）、乗客酸素の作動中 1 psi/秒（満充填から約 30 分）。50 psi 未満では乗員マスクに酸素が来ない。
  - 乗員マスクを出していれば、X-Plane の低酸素の高度（`pilot_felt_altitude_ft`）を 10,000 ft までにする（客室 40,000 ft までは 100 % の酸素で 10,000 ft の空気と同じ程度）。マスクは機長・副操縦士をまとめて 1 つのコマンドで出し入れする。
  - 乗客酸素と治療用酸素のソレノイドの電源はどれかの DC バス（資料に記載なし）。アネロイドの自動作動は電源が要らない。X-Plane の `rel_pass_o2_on` の故障は作動として受ける。
  - ばね戻りのスイッチ（PASS OXYGEN の ON・RESET、THERAPEUTIC の RESET）は、コマンドの最後のイベントから 0.3 秒で NORM に戻す（XTLua が一瞬のコマンドの終わりを渡さないことがある）。
- 火災防護（3-4 段 1。`B747.35.fire_model.lua`・`B747.35.xt.fire.lua` に「estimate」と書いてある）：
  - squib が発火してからボトルが空になるまで 1.5 秒（資料に時間が無い。貨物の A・B は「瞬時」）。その間だけ X-Plane の消火器を入れる（X-Plane は 1 秒以内に火を消すことを確かめた）。
  - X-Plane のエンジン火災は火災の検知器の 2 ループだけが感じ、過熱の検知器には伝えない（資料に関係の記載なし）。過熱は失敗の dataref で起こす。
  - X-Plane に APU の消火の dataref が無いので、APU ボトルの放出で X-Plane の APU 火災（`rel_apu_fire`）を 0 に戻す。
  - FIRE/OVHT TEST の PASS は全部のループが応えたとき（片方のループの故障でも FAIL）。loop の status は、そのループが火災・過熱（試験は含めない）か故障のとき。
  - Fire Override のコマンドは「override を押してスイッチを引く」までを 1 つで行う（3D に override が無い）。APU の消火スイッチを引いたときの APU の停止は、火災の自動停止と同じ入力で APU のモデルへ渡す（APU の advisory が出ることがある）。
  - 貨物室（段 2）：煙は venturi の吸引が無いと検知器に届かない。吸引は中央ダクトの圧が 5 psi を超えるとき（資料は venturi の水柱 7/11 in）。貨物の検知の電源は APU battery bus（資料に記載なし）。2 区画とも ARM して DISCH したときは C・D を出さない（回路図からの読み）。剤が出た区画の煙の失敗を 0 に戻す。

- 操縦系統のフラップ（4-1 段 1。`B747.45.fcu_model.lua`・`B747.45.xt.fcu.lua` に「estimate」と書いてある）：
  - 後縁の主系統の速さは前のコードと同じ 30° を 45 秒（資料に時間が無い）。副系統と代替の速さはその 1/10（FCOM・FCTM は「ずっと遅い」とだけ書く。前縁の空気圧 9 秒と電動 90 秒の比を使った）。
  - 前縁の空気圧の不一致で電動にするまで 30 秒（FCOM は 20–45 秒）。前縁を空気圧で動かせるダクト圧は 10 psi 以上。前縁の制御と電動の電源は AC 1・3・4 のどれか（ATA27 p.413 の図は駆動ごとに AC 1・3・4）。電動の前縁が動かないと止まるまで 25 秒（後縁と同じ）。
  - 油圧が 1400 psi を下回ったときの副系統への切り替えは、その群に指令があるときだけ（資料は動かす場面を書いている。指令の無い地上で FLAPS PRIMARY を出さないため）。
  - FCU 自体の電源は資料に無いので作っていない（故障の dataref だけ）。X-Plane のフラップのアクチュエータの故障（`rel_flap_act`）は後縁の油圧駆動の故障として受ける（前は FLAPS CONTROL を出していた）。

- 操縦系統の SRM（4-1 段 2a。`B747.45.srm_model.lua` に「estimate」と書いてある）：
  - ロックアウトのアクチュエータがロックとロック解除の間を動く時間 2 秒。ラダー比変換器のアクチュエータの速さ 0.2 in/s、servo の誤差が 2 秒続くと監視が立つ。
  - ラダー比変換器の速度の表は p.637 の図から読んだ点（170 kt 0.2 in、195 kt 0.4、245 kt 0.6、310 kt 0.8、355 kt 0.9、420 kt 0.97）の間を直線で。延長と舵角の関係は直線（資料に無い。地上試験の 367 kt の位置で 6–8° に合う）。
  - 機能を持つ SRM は L から（実機は電源投入時にランダム）。ラダー比変換器の servo の監視は、エアデータが無いときも働く（160 kt 未満で止める条件が分からないため）。


## 電源（1-1）の GAP の状態

| ID | 状態 |
|---|---|
| ELEC-01 バス単位のモデル | 済（モデル） |
| ELEC-02 バス単位の公開 | dataref は済。使う側の乗り換えは 1-1 の次の段 |
| ELEC-03 電源切替 | 済（LH24 p.123 の表と FCOM p.796-797） |
| ELEC-04 GCB/BTB の自動制御 | 一部。許可ラッチと on line の回転は済。保護トリップ・3.5 秒の break power transfer・last source on は故障を入れるときに |
| ELEC-05 SSB | 一部。自動の開閉は済。手動の SSB スイッチと OPEN 灯は無し（3D に無い） |
| ELEC-06 standby | 済 |
| ELEC-07 表示器と CDU の電源 | 一部。CDU は済。upper EICAS（main standby）は fltInst02 の乗り換えで |
| ELEC-08 ELEC GEN OFF | 済（advisory、GCB 開で） |
| ELEC-09 ELEC AC BUS | 済 |
| ELEC-10 ELEC BUS ISLN | 済 |
| ELEC-11 DRIVE 灯 | 済。灯と ELEC DRIVE、カスタム acf の synoptic の DRIVE 枠（灯と同じ IDG の油圧低で。純正 acf はエンジン滑油圧のまま） |
| ELEC-12 DRIVE DISC | 済 |
| ELEC-13 GHB/GSB | 一部。ground service switch（客室のパネル）は無し |
| ELEC-14 ELCU と load shed | 済（発電機の台数で決める簡略版） |
| ELEC-15 DC とバッテリー母線 | 済 |
| ELEC-16 バッテリーの表示 | 済（カスタム acf）。APU バッテリーと BAT DISCH、STAT の V-DC・A-DC（モデルの値。APU BATT の A-DC は前は APU 発電機の電流だった）、CHG/DIS（2026-10-23 夕方。背景の固定の "DIS" を消した画像に替え、白の CHG・DIS を電流の向きで出す。0 A のときは空白）。純正 acf の STAT は X-Plane の値のまま |
| ELEC-17〜18、21〜22、24 | 未 |
| ELEC synoptic の ISLN・GALLEY | 済（カスタム acf）。ISLN は BTB 開で（前はスイッチ位置）。UTILITY と GALLEY（109）は 2026-10-23 夕方に画像を分け、それぞれの母線の通電で緑・琥珀（前は 1 枚の画像で utility bus の色）。GALLEY には FCOM の図のように母線までの自分の線を描いた。freighter（570）の galley 無しは電源モデルにまだ無い |
| ELEC-23 EICAS status | 一部。DRIVE DISC n は済（IDG が切り離されている間。実機は CMC で消すまで残る）。ELEC DRIVE、BAT CHARGER、ELEC TR UNIT、ELEC IDG VALVE は故障の仕組みが要る |
| ELEC-19 air mode | 済 |
| ELEC-20 故障 dataref の上書き | 済（書くのをやめた） |

## 警報（1-3）の GAP の状態

| ID | 状態 |
|---|---|
| WARN-01 CANC 後の新しいメッセージ | 済（メッセージごとの CANC 済みの印） |
| WARN-02 サイレンの結線 | 済。サイレンは `warning_siren`（リセットの可否つき）で鳴る（`747-400_custom.snd` と手元の `747-400.snd`）。音そのものは利用者が耳で確かめる |
| WARN-03 bell | 一部。ベルは `warning_bell` で鳴り、master リセットで止まる。FIRE/OVHT TEST のベルは試験ボタンのまま（火災の試験は火災 3-4 で警報モデルに入れる）。FIRE APU・CARGO などのメッセージ自体も火災（3-4）で |
| WARN-04 caution ごとの beeper | 一部。caution ごとの 1 秒の `master_caution_audio` は済（`747-400_XP11.snd` が使う）。beeper のある advisory（BLEED ISLN L・R、BLEED HP ENG。FCOM p.619）も同じ合図を出す（master CAUTION は点けない）。`.snd` の beeper もこの合図で鳴る（master CAUTION が点いたままでも次の caution で鳴る） |
| WARN-05 抑止 | 一部。始動前・始動中・離陸・着陸は済。他のメッセージによる抑止（notes/ATA-31-warning.md §4.4.1）と時間遅れは各系統で。STATUS cue はパネルが要る |
| WARN-06 表のレベル | 済（表の `level`） |
| WARN-07 文言・添字 | 一部。文言は済。memo の添字の重複（41）と init 側の表（配列の大きさを決めている）は残した |
| WARN-08 足りないメッセージ | 未（各系統の作り直しで） |
| WARN-09 ページ割り | 済。カスタム acf のパネルは 2 ページ目から PG を出し、10 ページまで描く（ACF_DIFF.md §5）。純正 acf は 2 ページまでのまま |
| WARN-10 更新の遅れ | 済（0.1 秒ごと） |
| WARN-11〜16、18〜21 | 未（形態警報・速度・高度警報・失速・GPWS などは、それぞれの作り直しで） |
| WARN-17 STATUS | 済。STATUS メッセージ（新しい順、11 行ずつ、STAT でページ送り）と STATUS cue（エンジン始動からリフトオフ 30 分後まで、着陸の RA 800 ft〜75 kt は出さない）。カスタム acf の STATUS ページにメッセージ行と PG、主 EICAS に cue（ACF_DIFF.md §5）。メッセージは資料に出てくる分から（油圧・空圧・電源）。secondary engine exceedance cue での抑止は未（その cue が無い） |
| WARN-22 警報系統の電源 | 一部。EIU は新しい電源のバス（1-1）。MAWEA とスピーカーの電源は分けていない |
| WARN-23 quick start の未定義の global | 未 |

## 油圧（1-4）の GAP の状態

| ID | 状態 |
|---|---|
| HYD-01 EDP の圧 | 済（圧力補償型、流量は N2 に比例、fire switch・SOV・スタンドパイプ） |
| HYD-02 demand pump の AUTO | 済（1400/1600 psi、0.3/14 秒、CUTOFF、系統 1・4 のフラップ） |
| HYD-03 demand pump の電源・抽気 | 済（DC の制御と HYDIM、AC bus 2・3、ダクト圧。電気の負荷は電源モデルに入れていない） |
| HYD-04 AUX | 済 |
| HYD-05 fire switch | 済（SOV 閉、EDP 減圧、demand pump 起動） |
| HYD-06・07 舵面の系統の組 | 済（upper rudder 1+3、L INBD AIL 1+3、R OUTBD AIL 3+4、spoiler 8） |
| HYD-08 漏れ故障の取り違え | 済（故障ごとに系統を 1 回だけ選ぶ） |
| HYD-09 ブレーキ源 | 一部。源の選択・accumulator・>BRAKE SOURCE は済。ブレーキの効きを源で制限するのは脚・ブレーキ（4-2）で |
| HYD-10 accumulator | 済（系統 4 だけが充圧、予圧 750 psi） |
| HYD-11 舵面以外の負荷 | 一部（P&W の逆推力は 2-3 段 3 で系統 n の圧 1,000 psi 以上のときだけ動く。脚・stab trim などは各系統の作り直しで、負荷の表を使う） |
| HYD-12 ステアリング | 未（脚・ブレーキで） |
| HYD-13 X-Plane の油圧への干渉 | 済（故障を書かない） |
| HYD-14 P5 の灯 | 済 |
| HYD-15 EICAS | 済（抑止を含む） |
| HYD-16 作動油量 | 済（乱数をやめ 1.00 から。RF は地上だけ） |
| HYD-17 油温 | 一部（ポンプ運転で上がる一次遅れ。燃料の冷却は無し） |
| HYD-18 リザーバ与圧 | 済（モデル、STATUS の HYD RSVR PRESS、カスタム acf の synoptic の RSVR PRESS。与圧の源はモデルでは 1 つ（左右のダクトの高い方）なので、4 つとも一緒に出る） |
| HYD-19 synoptic の表現 | 済（カスタム acf）。DEM の AUTO（シアン）・AUTO（琥珀）・OFF（琥珀。系統 4 の AUX も）・ON（琥珀）、AUX の OFF（白）・待機（シアン）・琥珀、EDP の OFF・ON（琥珀）、SOV を火災スイッチから。2026-10-23 夕方に、丸ごと色を付けた記号の画像（丸は中の表示と同じ色、ATA29_32 p.105）と、不作動項目の絵を作り直した：各系統の一覧（P&W は THRUST REV つき）と、負荷の割り当てから出した 6 つの組（1+2、1+3、2+3、2+4、3+4、1+2+4 の BRAKES）。系統を失ったとは系統圧低（HYD PRESS SYS と同じ条件）。組に BRAKES を置くこと、RR の THRUST REV を GE と同じに扱うことは推定（下の「推定で作った部分」） |
| HYD-20 STATUS メッセージ | 済（HYD PRESS ENG・HYD PRESS DEM・HYD OVHT SYS・HYD RSVR PRESS・HYDIM：ATA29_32 p.137） |
| HYD-21 スタンドパイプ | 済 |
| HYD-22 FLT CONTROL HYD POWER | 未 |
| HYD-23 カスタム acf の舵面別割り当て | 未（要確認） |

## 空圧（1-5）の GAP の状態

| ID | 状態 |
|---|---|
| PNEU-01 需要と供給 | 済（区画ごとに使う量と出せる量からダクト圧。値は推定） |
| PNEU-02 エンジンの弁 | 済（HPSOV・PRV・PRSOV、逆流防止、始動時の逆流、始動弁が閉じてから PRV が開くまで 15 秒、過熱ラッチとスイッチでのリセット、>BLEED n OFF は N2 50 % 以上）。高圧段との切替は近似 |
| PNEU-03 故障と警報 | 一部。過熱（SYS FAULT、BLD n OVHT/PRV）はモデルにあるが、つなぐ故障がまだ無い（X-Plane に相当する故障が無い）。過圧の BLEED n、BLEED HP ENG、BLD DUCT LEAK は未（故障の入れ方と、火災・過熱検知 3-4 で）。STATUS の BLEED ASCTU A・B（DC bus 1・3 が 20 秒無い）と BLEED ISLN L・R・APU は済 |
| PNEU-04 BLEED ISLN と VALVE 灯 | 済（弁は 2 秒で動く。VALVE 灯は移動中と不一致。10 秒の不一致で BLEED ISLN L・R、>BLEED ISLN APU）。BLEED ISLN の beeper は警報モデルの側で（下の「気づいたこと」） |
| PNEU-05 APU 弁 | 済（APU RUNNING＝N1 95 % ＋ 2 秒、セレクタ OFF で閉、AC bus 2 のモーター、DC bus 2 の制御）。APU の消火ハンドルは 3D に無い（火災 3-4 で） |
| PNEU-06 ISLN の電源 | 済（L は AC bus 1、R は AC bus 3。電源が無いと止まる） |
| PNEU-07 地上空気 | 一部（モデルに入力はある。つなぐ操作が無い。FMC の地上作業ページに足す案） |
| PNEU-08 始動の空気 | 一部。空気の側は済（APU で 3 パックのままでは始動できない、クロスブリードは供給側 70 % N2）。3-1 で X-Plane の与圧を上書きしたので、X-Plane のエアスターターはこちらのダクト圧で回る（`bleed_available` ＝ ダクト圧 ÷ 27.5、上限 1.5。上書き前の X-Plane 自身の値に合わせた推定）。圧と回り方の関係は X-Plane のもので資料に無い（ENG-38） |
| PNEU-09〜11 表示 | 済。PNEU-10（ダクト圧の色の境と右の数字）と PNEU-11（ECS synoptic のエンジンと APU の流れを弁から）はカスタム acf（ACF_DIFF.md §5）、PNEU-09（主 EICAS のダクト圧の表示条件）は空調 3-1 段 1 の data block の条件。PRSOV の琥珀の OFF と移動中の記号は絵が無いので無い |
| PNEU-12 GE の逆推力の抽気 | 一部（逆推力の側は 2-3 段 3 で、そのエンジンが運転中なら動く。逆推力のとき HPSOV・PRV がスイッチ OFF でも開く空圧の動きと、PRV が閉じたら逆推力が動かないことは未） |
| PNEU-13 EEC の抽気補正 | 一部（パックの数は運転中のパックの数（3-1、AIR-16）、パック OFF は着陸復行の表、防氷は上昇の表を使う。実際の抽気源（APU からパックへ、エンジン抽気 OFF）は見ない） |
| PNEU-14 X-Plane の抽気 | 済（3-1 で X-Plane の与圧を上書きしたので、X-Plane のダクトの空気 `bleed_available_*`（ダクト圧 ÷ 27.5）と抽気の損失（エンジンが出す流量 × 1 ℃、APU は × 15 ℃）を抽気のグルーが書く。値は推定。`bleed_air_mode` は前のまま 5/0 を書く） |

## APU（2-1）の GAP の状態

| ID | 状態 |
|---|---|
| APU-01 N2 の表示 | 済（N1 × 0.926：FCOM p.868 の図の値。推定） |
| APU-02 油量 | 一部（乱数をやめ、停止 1.00・運転 0.92 に一次遅れ：推定。消費と RF/LO は無し） |
| APU-03 APU DOOR | 済（ドアが指令の位置に 20 秒以上無いとき：推定） |
| APU-04 APU | 済（selector ON で自動停止した、または selector OFF で N1 95 % 超が cooldown の外で 10 秒：推定） |
| APU-05 APU RUNNING | 済（selector ON かつ N1 95 % 超） |
| APU-06 自動停止 | 一部（火災、主タンク 2 の燃料切れ、始動が 120 秒で 95 % に届かない。fault は selector OFF まで保持。抽気ダクト過熱の停止は入力が無い。限界値は資料に無い） |
| APU-07 ドア全開で starter | 済（ドアは約 12 秒で開く：推定） |
| APU-08 cooldown で抽気弁を閉じる | 済（1-5 で selector OFF なら閉じる。cooldown は発電機も無負荷：推定） |
| APU-09 始動電源と回数の制限 | 未（資料の表はあるが、電池の消耗と合わせて入れる） |
| APU-10 運用範囲 | 一部（発電機は地上だけ：電源モデル。高度の上限は資料が自動停止を書いていないので入れていない） |
| APU-11 燃料 | 済（2-2。APU 燃料弁は hot battery bus、DC 燃料ポンプは主 2 AFT が圧を出すまで APU battery bus で回る、APU FUEL はポンプの低圧か弁の不一致。消費は主 2 から 150 kg/h：推定。APU が止まるのは主 2 が空のときのまま） |
| APU-12 始動時の増風要求 | 未（CF6 の資料だけ。エンジン 2-3 で） |
| APU-13 START→ON で始動しない | 済（START に回すと保持する） |

## 燃料（2-2）の GAP の状態

| ID | 状態 |
|---|---|
| FUEL-01 吸引供給 | 済（自タンクのポンプ圧が無いと自タンクから吸う。FUEL PRESS ENG。エンジンは止まらない） |
| FUEL-02 マニフォールド | 済（開いた xfeed を通して CWT・O/J 2・3・他の主タンクから。圧力の順位、同じ圧なら同じ側、SP.12 の均衡手順） |
| FUEL-03 不均衡 | 済（1,360・2,720 kg、450 kg で消える。FUEL IMBALANCE は tank-to-engine の後の内外の差） |
| FUEL-04 CWT のメッセージ | 済（始動前・上昇・巡航をピッチで、ジェティソン中の抑止、FUEL PRESS CTR の 2 つの経路） |
| FUEL-05 消費と acf の燃費 | 済（消費は X-Plane の流量のまま、負は 0。カスタム acf の SFC を純正と同じにした：FL350・269 t で 1 発 1,612 → 2,134 kg/h、PI.11.2 の LRC は 260 t で 2,211、280 t で 2,378 kg/h。離陸・上昇の値は 2-3 で上昇の表と比べる） |
| FUEL-06 FUEL PUMP | 済（ポンプごとの低圧。FUEL PRESS ENG で抑止） |
| FUEL-07 xfeed 2・3 | 済（地上でフラップ 10〜20 に 40 秒で閉、空中はその範囲を出るまで保持、takeoff disagree は FUEL X FEED 2・3） |
| FUEL-08 頭上の灯 | 済（照明モジュールがモデルの `light/*` を読む） |
| FUEL-09 電源 | 済（ポンプはバスごと、弁は 4 秒で動き電源が無いとその位置に留まる） |
| FUEL-10 水平安定板タンク | 済（移送の条件、低圧で止まる、ジェティソンでは機外へ、FUEL STAB XFR・FUEL PRES STB・>FUEL PMP STB。貨物機の設定では使わない） |
| FUEL-11 予備移送 | 済（主 2 か 3 が 18,200 kg で 4 弁とも、空中だけ、接地で閉、FUEL RES XFR 2・3） |
| FUEL-12 ジェティソン | 済（FTR で停止、主 2・3 の均衡、主 1・4 の移送、CWT は約 1,185 kg まで、ノズル弁はスイッチ直結、時間の 90 秒後の更新、終了後の FUEL OVRD）。>FUEL JETT A・B は FJCC の故障が無いので出ない |
| FUEL-13 FMC の燃料 | 未（FMC で。FUEL USED の [4] はエンジンだけにした） |
| FUEL-14 スカベンジ | 済（ジェットポンプ 4 本で合計約 1,200 lb/h、主 2・3 のポンプで動く。>SCAV PUMP ON は 405 だけなので出さない） |
| FUEL-15 故障と不一致 | 一部。不一致（FUEL X FEED、>JETT NOZZLE、FUEL RES XFR）は済。ポンプ・弁の故障、FUEL TEMP SYS は未 |
| FUEL-16 FUEL OVRD | 済 |
| FUEL-17 O/J の起動 | 済（CWT ポンプ片方の低圧も。shared flow も） |
| FUEL-18 spar valve と火災スイッチ | 済 |
| FUEL-19 タンク容量 | 済（acf の比率と総容量から。GE の主 1・4 は acf が 1 つの値なので区別しない） |
| FUEL-20 燃料温度 | 未（TAT への一次遅れのまま。FUEL TEMP LOW は −37 ℃ 以下にした） |
| FUEL-21 開始時の配分と給油 | 一部。前の配分（地上で 100 t 超）と給油の順序は残した（資料で確かめられない）。配分で 1,428 kg 失われていたのと、給油が X-Plane の量と食い違うのは直した |
| FUEL-22 APU の消費 | 済（主 2 から。150 kg/h は推定） |
| FUEL-23 タンク 7 の役割 | 対応不要（override 中） |
| FUEL-24 synoptic の制約 | 未（パネル。ポンプの琥珀・主タンクの琥珀の条件、FTR の単位） |
| FUEL-25 EICAS の文言 | 済（1-3 で）。>FUEL WING ISOL はこの FCOM に無いので出さない |

## エンジン（2-3）の GAP の状態

段 1（始動・点火・燃料弁）の分。ほかは段 2・3 で。

| ID | 状態 |
|---|---|
| ENG-08 ENG FAIL | 済（caution の段階は 1-3。条件を空中・RUN・N2 52 % 未満にした。前は表示 N2 15 % 未満） |
| ENG-09 >ENG SHUTDOWN | 一部（火災スイッチを引いたか CUTOFF で、空中だけ。master CAUTION を点けない扱いは未） |
| ENG-10 STARTER CUTOUT | 済（start valve が開いたまま N2 54 % 超が 5 秒） |
| ENG-11 starter の cutout | 済（X-Plane の N2 50 %。starter はコマンドを放すだけで、燃料を切る shut_down は使わない） |
| ENG-12 autostart | 済（燃料投入、light-off・hot・hung、GE 3 回・109 2 回の再試行、30 秒 motoring、中止、空中は燃料を切って入れ直すだけ、auto-relight、ENG AUTOSTART、>AUTOSTART OFF。405 は無し） |
| ENG-13 AUTOSTART で燃料弁 | 済（エンジン燃料弁は RUN と火災スイッチだけで開閉。autostart の燃料は EEC の計量） |
| ENG-14 火災スイッチ | 済（エンジン燃料弁を閉じる。spar valve は燃料系 2-2 で） |
| ENG-15 ENG FUEL VLV | 済（エンジン燃料弁か spar valve の不一致 5 秒。advisory 305〜308 を足した） |
| ENG-16 igniter の状態 | 済（モデルの点火を X-Plane の igniter に書く。auto-ignite は切る） |
| ENG-17 AUTO・STBY IGNITION | 済（条件、交代、igniter 1 は AC bus 1・2 は AC bus 3、standby の切替。X-Plane の igniter は 1 本なので、どちらかが点けば点火） |
| ENG-18 ENG IGNITION | 済（CON、PW はフラップも、で点火していないとき） |
| ENG-37 fuel-on の印 | 未（段 3） |
| ENG-38 始動の空気 | 一部（start valve は抽気のモデルがダクト圧で開ける。スターターの回り方がダクト圧に依らないのは残り。資料にあるのは APU で 40〜50 psi、地上の空気は 30 psi が目安（最大 45 psi）、クロスブリードで 35〜47 psi まで（ATA70_80 p.549-550、FCOM SP.7.1）で、ダクト圧と starter の回り方の関係は無く、作るとほぼ推定なので後回し（PNEU-08 と一緒に）） |
| ENG-01 レバーと推力の指令 | 済（GE・P&W。アイドル端から EEC の最大定格までレバー角に比例し、離陸は 48°、25,000 ft より上の最大上昇は 35° で頭打ち。上昇中にレバーを止めれば指令の N1・EPR は変わらない。RR は前のまま） |
| ENG-02 Max N1・EPR の線 | 済（EEC の最大定格。前は FMC の推力基準） |
| ENG-03 推力の上限 | 済（上限は定格。推力の制御を作り直し、実際の N1・EPR が指令に ±0.002 EPR・±0.2 % N1 で合う。前の PID は最大定格を 0.02 超えたままだった。オーバースピード保護で N1・N2 を赤線の手前で止める。指令に届かないときに X-Plane の最大推力を足す前の仕組みは、条件を直して残した） |
| ENG-04 >ENG RPM LIM | 済（EEC が回転数で推力を押さえているとき。GE は N2、P&W は N1 か N2。前は表示 N1 が赤線を超えたら。RR は前のまま） |
| ENG-34 acf の値との依存 | 一部（推力を足す仕組みの条件から「X-Plane の N1 > 99.99 %」を外し、純正の `_n1_rated_thrust` に依らなくした。GE の離陸中の N1 表示が X-Plane の N1 に掛け算する件は段 3 の表示で） |
| ENG-19 N2 を 0 に書く | 済（地上で止まっているエンジンだけ。空中は風車回転を残す） |
| ENG-06 approach idle | 済（エンジンごとに選び、空中で条件が終わって 5 秒・接地 5 秒後に minimum。109 は CON を条件にしない。GE は逆推力でも。X-Plane のアイドルは全エンジンで 1 つなので、どれかが approach なら全部 approach） |
| ENG-07 LOW IDLE・IDLE DISAGREE | 判定は済（advisory 309〜312 を足した）。アイドルの故障が無いので出ない |
| ENG-05 ALTN | 済（手動の代替モード。指令は最大定格で頭打ちせず、同じレバーで normal 以上、全開で overboost。ENG EEC MODE・>ENG LIM PROT、A/T の切断と、GE は 4 基とも代替なら・P&W は全部 normal なら A/T をまた使える。EEC の故障と自動の移行は無い。P&W の制御量の N1 への切替は無い） |
| ENG-20 EGT の色と抑止 | 済（表示のモデル `B747.40.engine_display_model.lua`：型式ごとの限界で白・琥珀・赤、TO/GA を押してから 5 分は琥珀にしない（P&W はエンジンが止まれば 10 分）、始動限界の線は CUTOFF と始動の途中、その間は始動限界で赤。パネルは赤・琥珀・白・始動限界の線をコードのフラグで出す（GE の固定の閾値と、X-Plane の N2 55 % の条件をやめた）） |
| ENG-31 逆推力 | 一部（逆推力のモデル `B747.40.reverser_model.lua`：P&W は関係する油圧系統、GE はそのエンジンの運転（抽気）が無いと動かない、地上の判定は逆推力ごとの継電器、動けない逆推力はそのまま、ENG n REVERSER は要求と位置の食い違い 2 秒と X-Plane の故障。残り：CF6 の逆推力の 90 % の制限、auto-restow（シムに意図しない展開が無い）、REV INTERLOCK・REV POS（整備用の status）。X-Plane の逆推力は全開でも N1 68 % くらいで実機より弱い） |
| ENG-32 B747_prop_mode の未定義の i | 済（どれかのエンジンが逆推力か、で書き直した。動きは変わらない） |
| ENG-25 油圧 | 一部（表示のモデルで、赤は赤線の下で CUTOFF と始動中は白（FCOM p.846）、GE の赤線は N2 で 10〜35 psi（ATA70_80 p.395）、ENG n OIL PRESS（advisory 317〜320 を足した。GE は低圧スイッチ 10/15 psid、ATA70_80 p.522）。パネル：赤い数字を状態だけで出す（前は 10 psi 未満のときだけで、赤線と 10 psi の間では数字が消えた）、GE の琥珀の数字と針を足した。残り：GE の値と目盛り（X-Plane の油圧は P&W 向けの 150 psi 前後、パネルの針は 70〜300 psi で、CF6 の値（資料に無い）と動く赤線・琥珀の帯の絵が要る）） |
| ENG-26 油温 | 一部（ENG n OIL TEMP をモデルに移した（160 ℃ 超。P&W・RR は資料なし）。パネルの数字の琥珀を 160 ℃ からに直した（150 ℃ からで白と重なっていた）。閾値は型式に依らない（P&W は資料なし）） |
| ENG-27 油量 | 一部（エンジンごとの X-Plane の比を使う（前は全エンジンが 1 番の比）、GE は US quart（FCOM p.848）。量の作り方は前と同じ推定。マゼンタ（GE の low 4 qt と巡航中の差 6 qt）をパネルに足した。P&W の low は資料に無く出さない） |
| ENG-28 ENG OIL FILT | 未（X-Plane に相当する故障が無い） |
| ENG-29 振動 | 一部（音源ごとの値（推定）と一番大きい音源をモデルで出す。火災で振動を上げる前の処理（資料なし）は外した。パネルに音源の文字 N1・N2・FAN・LPT を足した（BB の絵にそろえて作った絵、`docs/overhaul/tools/make_vib_labels.ps1`）。残り：high band（CF6 は 4.0）、自動表示（partial 形式、5-2）） |
| ENG-23 二次エンジン表示の自動表示 | 済（空中で FUEL CONTROL を CUTOFF にしたときだけ（FCOM p.843、p.872）。前は地上でも RUN でも出た（コマンドのハンドラーと、init の `switch_target` の書き込みハンドラーの両方で）。最初の通電のときは前のまま（フライトの開始で ENG を選ぶ）） |
| ENG-30 型式の文字列 | 済（FMC の設定で選べる CF6-80C2-B1F1 と RB211-524H8T が、短い B1F・524H の分岐に先に入らないようにした） |
| ENG-35 スプール時間 | 済（地上で始動中（start valve が開いているか、始動モデルの燃料からアイドルまで）は 26 秒、それ以外は 5 秒。前はエンジンの運転数で決め、ほかのエンジンが回っていると始動が 3 倍速く、s00 では 1 番エンジンだけ RUN からアイドルまで 15 秒（ほかは 41 秒）だった。空中の始動は 5 秒のまま） |
| ENG-37 燃料投入の印 | 一部（CUTOFF で火災スイッチを引いていないとき（ATA70_80 p.346。P&W・RR も同じとした）。位置（N2 の目盛りの上）は固定の絵のまま、表示形式の項目で） |
| ENG-24 空中始動の範囲と X-BLD | 作れない（範囲の表は QRH の ENGINE IN-FLIGHT START にあり、手元の資料に無い。FCOM は表示の条件だけ（p.840、p.851、p.879）） |
| ENG-22 partial・compact 形式、exceedance cue | 未（表示の形式なので 5-2（EICAS の形式）で作る） |
| ENG-21 超過の赤い枠と色 | 済（N1・EGT・N2・N3 の数字の枠は、限界に達すると赤になり、戻っても赤のまま。EICAS の CANC で白（数字が白のときだけ）、RCL で記録した超過がまた赤（FCOM p.873、ATA70_80 p.345-346・p.356）。新しいフライトで消える。CF6 の N2 は赤線の上が 20 秒を超えると赤のまま（ATA70_80 p.345）。N1・N2・N3 の数字と帯の赤は表示のモデルの赤線（GE は ATA70_80 p.395、P&W・RR はパネルの前の値）。P&W の EPR は数字は白のまま、帯が最大 EPR で赤（FCOM p.833-834・p.873）。前はパネルの固定の値（EPR 1.9、P&W の N1 の枠は X-Plane の N1、P&W の EGT の枠は X-Plane の EGT）。新しいモデル `B747.40.exceedance_model.lua`） |
| ENG-33 表示値の作り方 | 後回し（推定が主になる。X-Plane の EGT は始動のピーク（約 479 ℃）が離陸（約 430 ℃）より高く、acf の最大 EGT 460 ℃ を超えるので、X-Plane の EGT を 1 本の比例で換算しても、始動限界（P&W 535 ℃）を始動で超えないことと、離陸で 600 ℃ くらいになることを両立できない。EGT は N1・N2・外気温などから作り直す必要があり、典型的な値は資料に無い。N1・EPR・N2 の式を変えると EEC の推力の制御（段 2）の調整もやり直しになる。気づいたことの「表示の式の癖」） |
| ENG-36 >ENG CONTROL・EEC MAINT POWER | 未（EEC の故障のモデルが無い） |

## 空調（3-1）の段取りと GAP の状態

段取り（2026-10-24 に決めた。notes/ATA-21.md §8 の案から）：
- 段 1（パネルの変更なし）
  - (a) パックと与圧：済。パックのモデル `B747.55.pack_model.lua`・与圧のモデル `B747.55.press_model.lua` とグルー（ARCHITECTURE.md §4.11）。X-Plane の与圧は上書きした。
  - (b) 機器冷却、貨物室火災 ARM の機器冷却 OVRD、ER 開始のスイッチの初期化：済。機器冷却のモデル `B747.55.eqcool_model.lua` とグルー `B747.55.xt.eqcool.lua`。後方貨物室暖房は温度が要るので段 2 に回した。
- 段 2：温度制御と後方・前方貨物室の温度と暖房：済。温度のモデル `B747.55.temp_model.lua` とグルー `B747.55.xt.temp.lua`（ゾーンと貨物室の熱のつり合い、パックの出口、トリム空気、backup、ダクト過熱と ZONE RST、comfort correction、TRIM AIR OFF・TEMP ZONE・TEMP CARGO HEAT・ZONE TEMP、ZONE SYS FAULT・TEMP の灯）。パックのモデルは cruise clamp の normal flow を客室の温度で待つ。ALTN・FLT DECK の MAN（3D のノブがその位置まで回らない）と客室乗務員の温度パネル（3D に無い）は作らない。パックの過熱は、温度のモデルの出口が 135°F 以下で原因が無いので、故障の入力のまま。グルーどうしで渡す出力の表がコピーになっていたのを、この段の試験で見つけて直した（別のコミット）。
- 段 3：カスタム acf の ECS synoptic：済。道具 `docs/overhaul/tools/panel_ecs.lua`（ACF_DIFF.md §5）で、7 ゾーンの target（小さく、`temp/target_shown`）と actual、MASTER、FWD・AFT、TEMP °C、外流弁の針（−1〜+1 を CL・OP の目盛りの ±64°）と弁ごとの MAN（琥珀）・AUTO、パックごとの HI FLOW、EXT AIR（抽気のモデルに `air/ext_air`）を足し、パックの OFF/A/B を弁と使用中の PTC で、エンジンと APU の流れを弁で出すようにした（PNEU-11）。新しい絵は `make_ecs_images.ps1`（針、琥珀の MAN）。data block の LDG ALT を消す条件と客室高度の赤い数字の桁（AIR-18）は、承認の一覧に無いので利用者に確かめ、2026-10-24 に承認を得て入れた（下の表）。

| ID | 状態 |
|---|---|
| AIR-01 パック弁 | 済（選択器、12 psi、トリップ、normal/high、流量は抽気のモデルへ） |
| AIR-02 与圧のスケジュール | 済（ground・takeoff・climb・cruise・descent・着陸後）。FMC の時間の情報（上昇時間、T/D）は FMC に無いので、上昇は機体の上昇に、降下は降下に比例させた。巡航の ΔP 8.8 は推定 |
| AIR-03 着陸高度 | 済（AUTO は FMC の出発地・目的地の標高と切替の条件、無ければ 2,000 と LANDING ALT。MAN はノブで 50 ft 刻み、−1,000〜14,000 ft）。進入を選んだときの滑走路の標高は無い（FMC に到着ページが無い） |
| AIR-04 手動 | 済（片側ずつ、DC モーター、battery bus と APU hot battery bus） |
| AIR-05 CABIN ALT AUTO | 済（両 CPC 故障か両方 MAN） |
| AIR-06 リミッタ | 済（自動のときだけ、11,000 ft で全閉、750 ft 下で解除） |
| AIR-07 CPC A/B | 済（NORM・A・B、着陸で交代、電源投入で A、引継ぎの 3 条件、DC bus 1・2）。CPC の故障の入れ方は無い |
| AIR-08 リリーフ | 済（正圧 9.25 psid でパック 2 停止と PRESS RELIEF、負圧 0.2〜0.4 psi から 1 psi で全開） |
| AIR-09 外流弁の計器 | 済（弁の位置。+1 が全開で、計器の針は OP を指すことを X-Plane のスクリーンショットで確かめた） |
| AIR-10 温度制御 | 済（7 ゾーンの target と温度、最も冷たいゾーンでパックの出口、トリム空気、master trim air valve、backup（PASS TEMP の値、ZTC の故障では最後の値、F/D は 85°F まで）、ダクト過熱 185°F・10 秒のラッチと ZONE RST、165°F・30 秒の TEMP ZONE、comfort correction、>TRIM AIR OFF・TEMP ZONE・ZONE SYS FAULT 灯・STATUS ZONE TEMP）。ALTN・FLT DECK の MAN は 3D のノブがその位置まで回らず、客室乗務員の温度パネルは 3D に無いので作らない。熱のつり合いの値は推定。ゾーン温度の表示は段 3（パネル） |
| AIR-11 流量のスケジュールとファン | 済（cruise clamp と descent detect、パック 15 秒・ファン 5 秒の順、故障時の表）。ファンの故障の入れ方は無い |
| AIR-12 パックの保護 | 一部（トリップ・PACK RST・SYS FAULT 灯・PACK n・PACK CONTROL・PTC の切替はモデルにある。過熱は温度のモデルに原因が無い（出口は 135°F 以下）ので、故障の入力のまま。入れる手段は無い） |
| AIR-13 機器冷却 | 済（NORM・STBY・OVRD の構成、地上は外気 45°F で機外か前方貨物室、各翼 1 基の運転で flight 構成、ファン故障の closed loop と OVRD 30 秒のリセット、OVRD の差圧不足 55 秒で EQUIP COOLING、OVRD の客室の空気の排出を与圧のモデルへ）。故障（過熱・低流量・煙・ファン）の入れ方は無い |
| AIR-14 後方貨物室暖房 | 済（AFT CARGO HT、override 弁と control 弁、エンジン運転中、選択温度のサーモスタット（40°F：推定）、90°F 超で閉じて TEMP 灯（地上では点かない）と TEMP CARGO HEAT、AFT の火災 ARM。前方貨物室は機器冷却の排気と 40/50°F のヒーター） |
| AIR-15 ECS synoptic | 済（ゾーン温度の target と actual、MASTER、FWD・AFT、TEMP °C、外流弁の針と MAN/AUTO、HI FLOW、EXT AIR、パックの OFF/A/B は弁と PTC。カスタム acf。EXT AIR は地上空気の操作が無いので出ない） |
| AIR-16 EEC のパック数 | 済（運転中のパック数。新しい EEC のグルーと旧い型式別の計算の両方） |
| AIR-17 貨物室火災 ARM | 済（パック 3 停止・パック 1/2 high・再循環ファン全停止・機器冷却の OVRD 構成（前方貨物室への排気と暖房も止まる）・AFT で後方暖房の停止） |
| AIR-18 data block | 済（自動表示の条件。LDG ALT の数字と負号は、両 CPC 故障か両方 MAN で消す：与圧のモデルの `air/press/ldg_alt_shown` とパネルの条件、FCOM p.586。AUTO・MAN の字は残す（FCOM が消すのは高度だけ）。客室高度の赤い数字（10,000 ft 以上）は 5 桁で、先頭の桁が欠けない（新しい赤の 5 桁のフォント）。白（8,500 ft 未満）と琥珀（10,000 ft 未満）は 4 桁で足りるので変えていない。どちらもカスタム acf のパネルの変更で、2026-10-24 に利用者の承認。右ダクト圧の白の条件は PNEU-10 で済） |
| AIR-19 初期状態 | 済（エンジン運転中の開始で TRIM AIR・UPR/LWR RECIRC ON、EQUIP COOLING NORM。manipulators は TRIM AIR の位置を [83] に書いていた）。`sim/cockpit2/Cooling/Packs_EXT`（誰も読まない）はそのまま |
| AIR-20 X-Plane の与圧 | 済（override。X-Plane のダクトの空気と抽気の損失は抽気のグルーが書く） |
| AIR-21 電源 | 一部（CPC・手動・PTC は済。外流弁の自動のモーター・パック弁の継電器・ファンのバスは資料に無い） |
| AIR-22 status メッセージ | 一部（CABIN ALT AUTO A/B、OUTFLOW VLV L/R、UPR/LWR PRESS RELIEF、CPCS AIR/GND、ZONE TEMP は済。パック・ファン・機器冷却の status は故障の入れ方と一緒に） |

## 防氷・防雨（3-2）の GAP の状態

パネル（acf）の変更なし。P5 の灯は照明のモジュールがモデルの出力（`antiice/light/*`）を読む。主 EICAS の NAI・WAI と ECS synoptic の流れは、今までどおり X-Plane の ice の dataref と `antiice/nacelle|wing/valve_pos` で出る。

| ID | 状態 |
|---|---|
| ICE-01 主翼防氷の X-Plane への渡し方 | 済（左右の dataref に別々に、変わったときだけ書く） |
| ICE-02 WAI 弁 | 済（空中でスイッチ ON と DC bus 2 の指令、AC bus 2 のモーターで 2.5 秒（推定）、ダクト圧は見ない。VALVE 灯は指令と比べる。WAI VALVE LEFT・RIGHT は 5 秒） |
| ICE-03 >ANTI-ICE | 済（防氷 ON、TAT 12°C 超、氷を検知していない） |
| ICE-04 NAI VALVE・WAI VALVE | 済（エンジン運転中に 3.5 秒、5 秒） |
| ICE-05 NAI 弁の条件 | 一部（PRV の下流の抽気（抽気のモデル：過熱ラッチ、始動弁閉の 15 秒後、火災スイッチ、ENGINE BLEED off でも NAI で PRV が開く）、28V DC、過熱のラッチ（X-Plane の inlet heat の故障で受ける）。逆推力中の閉（E&M）と NAI ダクトのリークは無い） |
| ICE-06 プローブの加熱 | 済（ピトー静圧・AOA はエンジン運転中、TAT は空中。X-Plane の AOA・TAT の加熱も書く。HEAT P/S CAPT・F/O・L AUX・R AUX、L/R AOA、L/R TAT（15 秒）。X-Plane の故障で受ける。NAV-09 もこれで済） |
| ICE-07 窓の加熱 | 済（L・R を別々に、電源が無い・スイッチ OFF・故障で INOP と HEAT WINDOW、故障は 10 秒切って入れ直すまで保持、側窓は AC で加熱）。STATUS の WINDOW HEAT 1L/1R/2L/2R は無い |
| ICE-08 氷検知 | 済（空中だけ、AC bus 1・3、>ICING・>NO ICING・>ICE DETECTORS（2 秒）・STATUS ICE DETECTOR L/R（12 秒））。氷の検知は X-Plane の ice の表示灯を使う |
| ICE-09 ワイパー | 済（LO・HI を X-Plane の 50・100 %、28V DC） |
| ICE-10 ウォッシャー・防雨剤・WSHLD AIR | 未（3D の操作子が無い） |
| ICE-11 防氷の推力補正 | 未（EEC の補正表の作り直しで PNEU-13 と一緒に） |
| ICE-12 init の型の括弧 | 済 |
| ICE-13 電源 | 済（バスの割り当ての一部は推定：上の「推定で作った部分」） |

ほかに：エンジン始動のモデルが点火の条件に使う NAI を、X-Plane の inlet heat からスイッチの位置に変えた（FCOM p.625、p.631）。ER 開始で WINDOW HEAT L・R を ON にした（FCOM p.106 (NP.21.12)）。

## 酸素（3-3）の GAP の状態

| ID | 状態 |
|---|---|
| OXY-01 乗客酸素 | 済（約 14,000 ft の自動作動、ON、12,000 ft 未満の RESET、PASS OXYGEN ON と 60 秒の STATUS、治療用の同時作動、サインの強制点灯）。客室灯・チャイムは無い |
| OXY-02 酸素圧と >CREW OXY LOW | 済（前方貨物室の温度で補正、500 psi 以下で >CREW OXY LOW。使う量は推定） |
| OXY-03 STATUS ページの OXY PR | 済（カスタム acf。純正 acf は出ないまま） |
| OXY-04 スイッチとマスクの操作 | 済（コマンド。3D の操作子は無い）。THERAP OXYGEN ON の memo も |
| OXY-05 X-Plane の低酸素 | 済（X-Plane の酸素系統を上書きし、乗員マスクで 10,000 ft まで。推定） |

ほかに：照明のモジュールのサインに乗客酸素の条件を足した（LIGHT-14 の酸素の部分。FCOM p.437、p.502）。準備の手順の乗員マスクの試験（RESET/TEST を押して圧を見る：FCOM p.110）は作っていない。

## 火災防護（3-4）の段取りと GAP の状態

段取り（2026-10-24 に決めた）：段 1 はエンジンと APU（検知、消火スイッチ、エンジンと APU のボトル、FIRE/OVHT TEST、メッセージ）。段 2 は下部貨物室、車輪格納部、主翼前縁・ストラットの過熱（BLD DUCT LEAK）、化粧室・クルーレストの煙、スクイブ試験。どちらも済。

| ID | 状態 |
|---|---|
| FIRE-01 検知のモデル | 済（エンジンの火災・過熱、APU、貨物室。貨物は電源投入と試験のときだけ組み替える） |
| FIRE-02 エンジンの過熱 | 済（OVHT ENG n NAC。過熱は失敗の dataref で起こす） |
| FIRE-03 APU 火災 | 済（FIRE APU、自動停止、地上の自動放出、APU ボトル、APU BTL DISCH、>BOTTLE LOW APU、APU の消火スイッチ（コマンド）、試験中は止めない）。M869 とホーンの音は無い |
| FIRE-04 APU の故障の enum | 済（6 で判定） |
| FIRE-05 下部貨物室 | 済（煙検知、FIRE CARGO FWD/AFT と灯、ARM・DISCH、A・B 即時と C・D の 30 分／接地、DISCH の灯、>CGO BTL DISCH、>CARGO DET AIR、status。ARM の空調への作用は 3-1 の AIR-17） |
| FIRE-06 火災ベル | 済（1-3 の警報のモデルと `.snd` の結線。FIRE メッセージを立てるようになって、エンジン・APU の火災で鳴り、master WARNING のリセットで止まる） |
| FIRE-07 離陸中の抑止 | 済（1-3 の警報のモデル） |
| FIRE-08 FIRE/OVHT TEST | 済（TEST IN PROG → PASS/FAIL、離すと消える、エンジン・APU・貨物の灯、解錠、地上のホーン、APU を止めない、貨物・車輪格納部・ダクトの検知器も含む）。FUEL CONTROL の赤灯は 3D の結線のため試験では点かない |
| FIRE-09 消火スイッチのロック | 済（火災・CUTOFF・試験・override、main hot battery bus） |
| FIRE-10 消火とボトル | 済（squib 1 回、共用ボトル、空のボトルでは消えない、X-Plane の消火器は剤が出ている間だけ） |
| FIRE-11 ボトル低圧のメッセージ | 済（>BTL LO L/R ENG A/B、>BOTTLE LOW APU、status） |
| FIRE-12 >ENG n SHUTDOWN | 済（2-3 のエンジン始動のモデル） |
| FIRE-13 引いたときの作用 | 済（燃料弁・spar valve・抽気弁・油圧・発電機の GCR は各系統が読む。電源のグルーが GCR トリップの入力を渡していなかったのを結線し、GCR をラッチ式にした：LH24 p.108） |
| FIRE-14 車輪格納部 | 済（単ループ、AC bus 2、FIRE WHEEL WELL。原因は失敗の dataref） |
| FIRE-15 ダクトリーク | 一部（BLD DUCT LEAK L/C/R と status、試験。抽気の系統への影響は PNEU-03 の残り） |
| FIRE-16 化粧室・クルーレストの煙 | 一部（>SMOKE LAVATORY、SMOKE DR 5 REST。クルーレストの給気弁とファンの停止は無い） |
| FIRE-17 スクイブ試験 | 済（コマンドの TEST 1・2、発火済みの squib は点かない、ARM で貨物 A・B を抑止） |
| FIRE-18 電源 | 済（検知は APU battery bus、解錠と squib は main hot battery bus、車輪格納部は AC bus 2、ダクトは DC bus 2 か main battery bus、FIRE/OVHT SYS。貨物の検知の電源は資料に無く APU battery bus とした：推定） |
| FIRE-19 貨物機の主デッキ | 未（3D に操作部が無い） |
| FIRE-20 CAS の更新の遅れ | 済（1-3 の警報のモデルは毎フレーム） |

## 操縦系統（4-1）の GAP の状態

| ID | 状態 |
|---|---|
| FCTL-04 ラダートリム | 済（controlObject にトリムの対応を足した：全行程の 80 %、比率変換器を通る。ATA27 p.612–614。X-Plane の `total_heading_ratio` にトリムが入らないことを確かめた） |
| FCTL-01 FCU | 済（段 1。後縁は内側・外側の群ごとに油圧の主系統と電動の副系統：指令して 1400 psi 未満が 4 秒で副系統、1600 psi 超が 4 秒で戻る、2000 psi の priority valve、動かない 7 秒（脚の動作中 42 秒）で副系統、圧があるのに副系統になった群は格納して 10 秒で戻る、副系統で 25 秒動かないと停止、左右の差 6.2 %・3.4 % で停止。前縁は内側・中央・外側の群ごとに空気圧（ダクト圧）と電動：動かないと 30 秒で両翼とも電動、内側と中央は一緒、指令の位置で空気圧に戻る、電動で動かないと停止。FLAPS PRIMARY・FLAPS DRIVE・STATUS の TE FLAPS・LE SINGLE DRIVE・LE MULT DRIVE。故障は `laminar/B747/flt_ctrls/fail/...` と X-Plane のフラップのアクチュエータ。逸走と moving away の保護は故障の源が無いので作っていない） |
| FCTL-02 代替フラップ | 済（段 1。ARM で FCU の制御を外し FLAPS CONTROL、レバーは効かない。EXT で全群が電動ですぐ動き、後縁はフラップ 25 で止まる。RET で前縁は内側の後縁が UP になってから。OFF で止まる。解除でレバーの位置へ） |
| FCTL-11 通常の表示 | 済（段 1。UP と 1 の間は group A の動き、1 から上は最も遅い後縁の群。マゼンタはレバーの位置に全部が着くまで。荷重軽減中もレバーと比べる。前は最も速い面で、レバーを 1 にした瞬間に 1 を示した） |
| FCTL-12 拡大・代替の表示のパネル | 未（パネルの変更が要る：前縁の 6 箱、琥珀、amber X、代替の目盛り。承認の一覧に無い。表示の状態 2 は副系統・停止・非対称・代替で出す） |
| FCTL-13 前縁の順序と自動格納 | 済（段 1。group A の格納は外側の後縁が UP、地上・空気圧で 1・4 か 2・3 の逆推力で group A を格納し、やめると出す） |
| FCTL-14 荷重軽減の速度 | 済（ヒステリシスを状態で持つ：レバー 30 で 178/203 kt、戻りは 195/170 kt。段 1 で、後縁が両方とも主系統のときだけにした） |
| FCTL-19 舵面位置のスポイラー | 済（スポイラー 4 と 12 の位置：ATA27 p.200、FCOM p.939） |
| FCTL-23 フラップのスナップのタイマー | 済（止める条件が逆だった。detent の名前のコメントも直した） |
| FCTL-21 メッセージと STATUS | 一部（段 1 でフラップの分：FLAPS CONTROL、FLAPS DRIVE、FLAPS PRIMARY、>FLAP RELIEF、STATUS の TE FLAPS・LE SINGLE DRIVE・LE MULT DRIVE・FLAP CONTROL L/C/R・FLAP LOAD RELIEF。段 2a で AILERON LOCKOUT、RUD RATIO SNGL・DUAL、STATUS の AILERON LOCKOUT・RUDDER RATIO） |
| FCTL-25 電源 | 一部（段 1 でフラップの分：後縁の input actuator は AC 1・DC 1、電動は内側 AC 4・外側 AC 3、前縁の制御と電動は AC 1・3・4 のどれか（推定）。FCU 自体の電源は資料に無い） |
| FCTL-05 外側エルロンのロックアウト | 済（段 2a。group A が入っていて 238 kt か M .53 を超えるとロック、group A が出るか 232 kt と M .51 を下回るとロックを外し、間は前の指令を保つ。FCU のフラップのデータを失えば速度と Mach だけ、両方の SRM を失えば空中ではロックを外す。指令から 45 秒でもう一方の SRM、さらに 45 秒で AILERON LOCKOUT と STATUS。アクチュエータの時間は推定） |
| FCTL-06 ラダー比変換器 | 済（段 2a。上下別々。p.637 の図の速度の表（155.5 kt まで 0 in、450 kt で 1.0 in。点の間は推定）で、舵角は 32° から 5°。エアデータを失うと上は 329 kt・下は 209 kt の位置、autoland では全権限、動かなくなった変換器はその位置のまま。160 kt 以上で servo の誤差が続くと RUD RATIO SNGL（両方で DUAL）と STATUS RUDDER RATIO。ヨーダンパーにも比をかけるのは前のまま（実機は下流で足す：推定）） |
| FCTL-27 ペダルとトリムの和の制限 | 済（段 2a。ペダル（X-Plane の `yoke_heading_ratio`）とラダートリム（全行程の 80 %）を足してから比変換器を通す。前はそれぞれに比をかけて和を制限しなかったので、450 kt でペダル 5°＋トリム 4° と 5° を超えた。また空中では X-Plane の `total_heading_ratio` にトリムの 0.3 倍が入るので、トリムが二重に効いていた（2026-10-24 に確かめた。地上では入らない）） |
| FCTL-26 外側フラップの wing 2 の部分 | 済（段 1。acf はフラップの組 2 を X-Plane の wing 2 と wing 3 に置いているが、wing 2 の舵角を誰も書かず、空力上 0° のままだった。外側の後縁と同じ角度を書く） |
| ほか（FCTL-03、07〜10、15〜18、20、22、24） | 未（段 2b・3 で） |

## 気づいたこと（作業の途中で）

- **全開にすると EPR が最大定格を一時超える**（2026-10-23、EEC 段 2 の試験）：地上で全開にすると、EPR はカスタム acf で 1.57、純正 acf で 1.58 まで上がってから最大定格（1.51〜1.53）に戻る。EEC の PID（`ecc_spd`、前からのもの）の応答で、実機は最大定格で止まる。→ 推力の制御の作り直し（2026-10-23 夜）で直った。前の PID は D 項が大きくスロットルが 0.9〜1.05 を往復し、積分が出力の上限 1.2 まで溜まって、空中の全開でも EPR が最大定格を 0.02 超えたままだった（ALTN の全開では N2 が赤線を超えた）。
- **表示の式の癖**（2026-10-23 夜、推力の制御の試験。段 3 の表示で見る）：
  - GE の N1 表示は推力から求める。空中でレバーをアイドルから出すと、アイドルの固定（`engine_idle_control_GE`）から推力の式に切り替わり、45.7 % → 20.5 % と一瞬下がる（空中のアイドルでは正味の推力がほぼ 0 のため）。離陸の基準（TO）では X-Plane の N1 に TO の係数を掛けた値で、式が違う。
  - P&W の EPR 表示は、フラップが出ていて GA でないとき最大定格で頭打ちにしてある（「離陸滑走でマッハ数とともに式の EPR が上がる」ための前の工夫）。制御はこの頭打ちの値を見るので、離陸滑走では表示が最大のまま推力がやや多くなりうる。
  - P&W の N2 表示は整数（`%3.0f`）。オーバースピード保護は丸める前の値を使う。
  - GE の地上アイドルの表示が低い（2026-10-24、オイルの試験）：Saudia（CF6）で地上アイドルの N2 表示が 57 %（開始の 10 秒後は 44 %。CF6 の min idle は N2 61.6 %：ATA70_80 p.206）。GE の N2 表示は表示 N1 の関数（ENG-33）。GE の油圧の赤線は N2 で上がるので、この表示のままではアイドルで 10 psi のまま。
  - 空中での推力 0 のあたり（M.45 でスロットル 0.4 くらいまで）は表示の N1・EPR がほとんど動かない。
  - EGT の表示値が低い（2026-10-23 夜、EGT の色の試験）：P&W の離陸推力（RJAA、15 ℃）で 294〜350 ℃（実機は 550〜620 ℃ くらいのはず。X-Plane の EGT に 654/960 を掛けて熱の遅れを足した値）。このため通常の運航では琥珀・赤にならない（色の論理は限界を一時的に下げた試験で確かめた）。ENG-33（表示値）で直す。
  - P&W の EGT の枠は赤の状態の絵が無く、赤になると枠が消える（GE には赤の枠がある）。超過の赤い枠（ENG-21）と一緒に足す。
- **空中の始動は地上より速い**（2026-10-24、スプール時間の修正）：X-Plane のスプール時間は全エンジンで 1 つで、空中は EEC の推力の制御に合わせた 5 秒のままにしたので、空中の始動（starter・風車回転）は地上の約 1 分より速く終わる。空中で 26 秒にすると、回っているエンジンの推力の制御が遅れて行き過ぎる（推力の制御は 5 秒で合わせた）。
- **FLCH が MCP の速度を保たない**（2026-10-23 夜、`s07_cruise_ff`）：空中開始の後、FLCH で 40,000 ft から 35,000 ft へ降りるとき、A/T が THR REF のアイドルのまま 170 kt 付近で降りた（MCP は 294 kt）。そのあと SPD で加速するのに 5 分ほどかかる。前に通ったのは空中開始の過渡が違っていたため。シナリオは 294 kt に近づくまで待つようにした。AFDS・A/T の作り直し（段階 6）で見る。
- **EEC モジュールが毎フレーム `collectgarbage("collect")` を呼ぶ**（`B747.42.xt.EEC.lua` の `after_physics`）。毎フレームの処理を重くしている。触る機会に外す。

- **同じ機体のまま新しいフライトを始めると、表示器と CDU が真っ暗になっていた**（2026-10-23、両 acf で再現。作り直し前からの不具合）：照明モジュールは、表示器と CDU の輝度に掛ける「電源」として X-Plane の汎用ライト 63（`sim/cockpit2/switches/generic_lights_switch[63]`）を `flight_start` で 1 にするが、機体を読み直さずにフライトを始めると、その後で X-Plane が 0 に戻す（機体を読み込むフライトでは 1 のまま）。電源のバスは生きていて、Web API で 1 を書くと 6 面と CDU が点いた。照明モジュールが毎フレーム読んで、0 なら 1 に戻すようにした（`B747_keep_light_power`、試験 `tests/lighting/`）。X-Plane で、読み直さない新しいフライトでも点灯することを確かめた。
- **エンジン停止の開始でも CTR ポンプのスイッチが ON**：Web API でエンジン停止のフライトを始めても、各モジュールは「エンジン運転中の開始」の設定をする（上の段階 T の注記のとおり）。そのため CWT が空でも CTR L・R のスイッチが ON で、燃料系は FCOM どおり FUEL PRESS CTR L・R（caution）と >FUEL LOW CTR を出す。前のコードも `s00` の最後に FUEL PRESS CTR を出していた。開始時のスイッチの設定（manipulators）を CWT の量に合わせるかは、quick start と一緒に考える。
- **XTLua の型の書き方の誤り**：エンジンの init スクリプトは配列の型を `"array[4)"` と書いているものが多い。XTLua は最後の 1 文字を捨てて数を読むので動く（X-Plane でも 4 要素の配列）。試験のモック（`tests/lib/xtlua.lua`）も同じ読み方にした（燃料の試験で `engines/fuel_valve_pos` を使うため）。
- **PROGRESS.md の日誌が一部消えていた**：HYD synoptic・ELEC・APU のコミットで、日誌の末尾に書き足したときに途中の行が切れ、05:2x〜13:4x の項目が消えて、壊れた UTF-8 の 1 バイトが残っていた。過去のコミットの版から戻した（HYD synoptic の項目の頭はコミットの説明から書き直した）。日誌への書き足しは Bash の `cat >>` か Edit で行う。
- 手元の `747-400.snd`（利用者の 3D 一式）と、その複製の `747-400_custom.snd` の 7,485 行目付近（雨の音）に `EVENT_START_END`（`EVENT_END_COND` の誤りとみられる）があり、機体を読み込むたびに X-Plane が `E/SOUN: Warning: unknown line` を出す。git の HEAD の `747-400.snd` には無い。音の中身は対象外なので触っていない。
- **X-Plane 自身の抽気の mode と isolation valve は連動している**：X-Plane（acf は `_has_full_bleed_air 0`）は、`bleed_air_mode` を 4（APU）にすると isolation valve を両方閉じ、5（auto）と 2 で両方開け、0 で両方閉じる。片方の弁を閉じると mode は 0 になる（Web API で確かめた）。1-5 の組み込みの最初の版は、APU だけのとき mode 4 を書いた。そのため X-Plane のエアスターターに APU の空気が届かず、カスタム acf の `s00` で 4 発とも回らなかった（モデルの始動弁は開いていた。X-Plane の弁を Web API で開けると回り出した）。前のコードも mode を書いていたが、読まずに書いていたので最初の 1 回しか届かず、毎フレーム読んで書いていた isolation valve の方が効いて、結果として弁が開いていた。グルーは mode だけを、ダクトに空気があれば 5、無ければ 0 にする。`s00`・`s05` に X-Plane の mode と弁の確認を足した。
- **XTLua は X-Plane の dataref への書き込みをキャッシュと比べる**：読むと次のフレームでキャッシュを X-Plane から読み直し、書くとキャッシュと違うときだけ次のフレームで 1 回 X-Plane に渡す（XTLua のソース xpmtdatarefs.cpp）。読まずに同じ値を書き続けると、X-Plane が値を変えた後は直らない（Web API で cross tie を 0 にすると、毎フレーム 1 を書いている電源のグルーが戻さなかった）→ X-Plane の dataref は毎フレーム読んで、違うときだけ書く（ARCHITECTURE.md §9a、TESTING.md §1.2）。電源のグルー（X-Plane の cross tie・バッテリー・GPU・APU 発電機・発電機）も同じに直した（Web API で cross tie を 0 にしても、すぐ 1 に戻る）。
- `s00` の始動は AUTOSTART OFF のままの手動始動（START を引き、N2 20 % で FUEL CONTROL を RUN）。AUTOSTART ON のときは、START を引くと始動弁は準備だけで、FUEL CONTROL を RUN にすると EEC が開く（FCOM p.879）。新しい空圧のモデルはこれに従う。AI の自動始動（B747.95.xt.AI）は AUTOSTART ON・パック OFF で「START → すぐ RUN」なので、この順で動く。
- **advisory なのに beeper が鳴るメッセージ**：FCOM p.619（2.50.1）の表では、BLEED ISLN L・R と BLEED HP ENG 1〜4 は「Advisory、Beeper」（改訂で足された行）。警報モデルは beeper を caution にしか鳴らさなかったので、advisory の beeper を足した（master CAUTION は点けない）。テキスト化した FCOM では、ほかにも「Advisory Beeper」に見える行（>CREW OXY LOW、ENG EEC MODE、ENG START VLV、IRS MOTION、UNABLE RNP）があるが、原本のページ（p.545、p.899、p.902、p.1430）では列のずれで、beeper は無い。
- **ピトー加熱がエンジンの抽気圧を見ている**：防氷モジュールは、どれかのエンジンの `bleed_air_psi` が 12 psi を超えることを「エンジン運転中」の代わりに使っている。新しい空圧では PRV が閉じると 0 になるので、4 基とも ENGINE BLEED が OFF（NAI も OFF）だとピトー加熱が切れる。始動のときも、始動弁が閉じてから PRV が開くまでの 15 秒だけ遅れる。防氷（3-2）で「エンジン運転中」に直した。
- **外部電源（試験のとき）**：XP12（12.0.12 以降）では、電源モジュールが X-Plane の GPU の電圧（`GPU_generator_volts`）が 24 V 未満のとき毎フレーム `electrical/ext_pwr1_avail`・`ext_pwr2_avail` を 0 にする（`B747.03.xt.electrical.lua` の `B747_external_power`）。Web API で 1 を書いても戻る。CDU の GROUND POWER の行も XP12 では出ない。`electrical/connect_power` のハンドラは phase を見ないので、押すと離すで 2 回切り替わる（XP11 向けの古いコマンド。今は害が無いので直していない）。試験で AC が要るときは APU 発電機を使う。
- P5 の抽気パネルは機長の目の位置から遠く、斜めにしか見えない。試験キットの視点に視野角を足し、`bleed`（pitch 19、heading 70、視野角 25°）で灯が読めるようにした。視野角は次の視点とシナリオの終わりで元に戻す。

- **EICAS に出るメッセージが増えた（1-3 の後）**：前の表示は実質 1 ページ（11 行）分しか正しく出せず、2 ページ目に回ったものが見えていなかった（WARN-09）。1-3 の後は、立っているものがすべて並ぶ。例：純正 acf の `s00` の APU 始動後に、HYD PRESS SYS 2・3（demand pump の OFF で系統 2・3 が無圧）、>BRAKE SOURCE（系統 1・2・4 が低圧）、>YAW DAMPER LWR・UPR（ヨーダンパーのスイッチ OFF）、>X FEED CONFIG が加わって 20 行・2 ページ。各系統が立てている状態は前と同じ。パネルは 2 ページ目の番号（PG）を出せないので、2 ページ目があることは画面では分からない（承認待ち）。
- **空中開始の試験（`s01`）は、機体の読み込み方で結果が変わる**：フライトの開始で機体が読み込まれたとき（03:45）は A/T が入り、A/P が機首上げを 13 秒ほどで立て直した。フライトを開始してから読み直したとき（04:59）は、読み直すまでの 20 秒に前の状態で飛んで失速し、急降下から始まった。読み直してからフライトを開始したとき（05:06）は A/T が入らず、ピッチ 35°・17,700 ft まで上がった。最後のものは古い油圧でも同じ（05:14）なので、油圧の組み込みとは関係ない。空中開始の AFDS の初期化（A/T と A/P のモード）の問題で、AFDS の作り直しで扱う。それまでは `s01` は X-Plane を起動し直した後の最初のフライト（機体が読み込まれる）で回す。
- 純正 acf として比べるのは `747-400.acf`（XP12）。カスタム acf はこれを元にしている（ACF_DIFF.md）。
- カスタム acf の新しい外部オブジェクトが参照するテクスチャ 4 枚（`Exterior_Wiper.png`・`Exterior_Detail.png`・`Exterior_Detail_2.png`・`Exterior_cargo.png`）が無い（Log.txt）。3D 一式の問題で対象外。
- Web API でフライトを開始しても、同じ機体なら機体は読み直されない（Log.txt に `Loading airplane` が出ない）。系統の状態は前のフライトから続く。試験で真っさらな状態が要るときは `-Reload`。
- Web API の `/flight` は、機体の読み込みに 2 分以上かかる間、応答しない。
- X-Plane のスクリーンショットは、シムが一時停止や読み込み中だと撮れず、動き出してからまとめて保存される。
- 今の機体を Web API の「エンジン停止」で開始すると、BATTERY は ON、STANDBY POWER は AUTO、燃料制御スイッチは RUN（エンジンは止まっている）になる。
- **X-Plane が止まった件（02:26 ごろ）**：カスタム acf から純正 acf へ Web API で切り替え、すぐ機体の読み直しを送った後、X-Plane が「応答なし」になった（CPU は約 2 コア分使い続け、sim の時計が止まり、Web API だけ答える）。10 分待っても戻らず、Log.txt を `runs/20261023_022542_..._747-400/Log_hung.txt` に残して強制終了した。起動し直した後は、純正 acf でもカスタム acf でも問題なく動いた。
  - 原因は分からない。Log.txt には誤りが出ていない。カスタム acf の読み込みでは、GPU のメモリ（RTX 3070、8 GB）の予算超過の警告が出ている（`Memory heap 0 has overstepped its budget`）。acf を何度も切り替えると、メモリが足りなくなるのかもしれない（推定）。
  - 対策：`-Reload` は Log.txt に新しい読み込みが出るのを待ち、出なければ送り直す。`run_scenario.ps1` は sim の時計が 30 秒動かなければやめる。acf を切り替えるときは、必要なら X-Plane を起動し直す。
  - **2 回目（03:42 ごろ）**：X-Plane を起動し直した直後の最初のフライト（カスタム acf を読み込み）で、`s01` の `"reload": true` により読み直しを送った直後に、同じく応答なしになった。Log.txt は機体の読み込み完了（state_Normal）で止まっている。2 回とも「読み込んだ直後の読み直し」が共通なので、`run_scenario.ps1` は、フライトの開始で機体が読み込まれたときは読み直さず、読み直すときも sim の時計が 20 秒進んでから送るようにした。その後の実行（`s01`・`s02`）では起きていない。
- **1 番エンジンだけ始動が速い**（両 acf で再現）：燃料投入から N2 50 % まで 7 秒（他は 25 秒）、EGT の山が出ない（301 ℃、他は 479 ℃）。ENG-16（スターターを止めるとき 2〜4 番が 1 番の igniter を切る）を記録で確かめたが、それだけでは説明できない。エンジンの作り直し（段階 2-3）で調べる。
- **始動中の燃料流量が負**：燃料系と EICAS が使う `sim/cockpit2/engine/indicators/fuel_flow_kg_sec` が、始動中に約 -0.08 kg/s になる。燃料系がそのまま引くと、始動のたびにタンクの量がわずかに増える（推定。燃料系の作り直しで確かめる）。
- idle の燃料流量が 1 発あたり約 72 kg/h と小さい（推定。資料の値と比べるのはエンジン・燃料の作り直しで）。
- **HDG HOLD が無い**：MCP の HDG HOLD のコマンド（`laminar/B747/autopilot/button_switch/hdg_hold_mode`）は init スクリプトでコメントアウトされていて存在しない。FCOM には HDG HOLD がある（notes/ATA-22.md、FCOM p.647・p.663）。AFDS-01 は HDG HOLD がある前提で書いてあるので、AFDS の作り直しで扱う。
- 空中開始（Web API の `lle_air_start`）では、A/P が既に入った状態で始まる（ピッチのモード 9、ロール 7、A/T 3）。
- XTLua の本体が持つ C の関数名は `XlLuaReplaceCommand`（綴りどおり）。init/init.lua の綴りは誤りではない。
- 同じ global に 2 回 `find_dataref` すると、2 回目の代入でその dataref に 0（文字列の dataref なら何も書かない）が書かれる（XTLua の名前空間の作り）。油圧モジュールの `altitude_hold_status` などで起きている。読み込み時だけなので今は害は小さい。
- **グルーどうしで渡したモデルの出力の表がコピーになっていた**（2026-10-24、3-1 段 2 の試験で見つけて直した）：空調のグルーは `B747_pack_out = pack_state.out` のように、メタテーブルの無い出力の表をグローバルに置いていた。XTLua の名前空間はこれをコピーするので、数と真偽の項目（`packs_operating`、`dp` など）は代入した時点の値で止まる（流量の配列のような中の表は同じものを指すので動いていた）。機器冷却は客室の ΔP を 0 と読んでいたので、飛行中に EQUIP COOLING を OVRD にすると、差圧があっても 55 秒後に EQUIP COOLING が出て、客室の空気も抜けなかった（推定。地上の試験 `s14` では差が出ない）。ARCHITECTURE.md §9a の決まり（グローバルの表にはメタテーブル）に、出力の表も入れた。
- 静的検査で見つかった既存の不具合：
  - `fltInst02` が、init スクリプトで作られていない時計の dataref 40 個と `electrical/oil` を使っている。
  - 3D の CHRONO スイッチが使う `glareshiled/*/chrono_switch_pos` は、xt スクリプトでしか宣言されていない。存在しない可能性がある。
  - いずれも `tests/static/` の既知の一覧に入れた。
- **空地判定が滑走中に AIR になっていた（1-2、2026-10-24 に直した）**：PSEU はトラックの傾きを X-Plane の `eagle_claw_angle_deg` が 1° を超えたかで見ていた。この角度は胴体に対するトラックの角度で、地上では機体の機首下げの角度そのもの（駐機で 0.85°、推力を出した滑走で 1.1°、強いブレーキで 1.75°）なので、滑走中・ブレーキ中に AIR（pri_gnd 0）になっていた。空調の `s14` で、離陸の中止の後に与圧が climb モードになって見つけた。空中の角度は acf の 8°（胴体脚）・58°（翼脚）なので、しきい値を 4° にした。PSEU を読む電源の BCU、逆推力のロックアウト、EEC のアイドル、始動、燃料なども、ブレーキ中に空中扱いになっていた可能性がある。
- **LuaJIT の `string.format("%6.0f")` が極小の値を誤って表示する**：1e-153 のような値で "500000000000000000" と出る（値は正しい）。与圧のモデルの昇降率の一次遅れが 0 に向かって極小になって見つけた。モデルは 0.01 fpm 未満を 0 にした。
- **FMC の RTE で出発地を変えると目的地が消える**（`s14`）。経路を入れ直す試験では目的地も入れ直す。
- **FMC のデータ文字列（`laminar/B747/fms/data`）は FMC が全体を書き直す**ので、Web API で書いてもすぐ戻る。試験で経路を入れるときは CDU のキー（`laminar/B747/fms1/alphanum_key/*`・`ls_key/*`）で入れる。
- **シナリオにリバリーの指定が無いと、前に使ったリバリー（エンジン型式）のまま**になる。`s13_oil_ge`（Saudia、GE）の後に `s00` を流すと GE で走る。始動の時間などを比べるときは注意。
- **照明のモジュールが X-Plane の読み取り専用の dataref に書いている**（2026-10-24、酸素のモジュールの試験で見つけた）：`simDR_OAT` を 2 回 `find_dataref` していて（B747.90.xt.lighting.lua の 163 行と 2010 行）、2 回目で `sim/weather/temperature_ambient_c` に 0 を書く（XTLua はグローバルへの代入を dataref への書き込みにする）。読み取り専用なので X-Plane は受け付けず、害は無い。照明（7-2）で直す。

- **FUEL CONTROL の赤灯は自前の検知に合わせられない**（2026-10-24、火災防護の段 1）：3D（`Cockpit_TQ.obj`）が X-Plane の読み取り専用の `sim/cockpit2/annunciators/engine_fires` に付いている。書き込める旧い `sim/cockpit/warnings/annunciators/engine_fires` に書いても X-Plane が毎フレーム上書きした。X-Plane のエンジン火災では点くが、FIRE/OVHT TEST やループの故障・単ループ運用には合わない。直すには OBJ の付け替え（3D は対象外）。

- data block の ΔP の数字の前に、値が正でも小さな「_」が出る（ΔP +0.02 で「_0.0」、巡航で「_8.8」。`s25` の写真）。純正 acf と同じ定義（`GROUP Diff Press`：`LED_3.26B.xxx#00`、`DIGITS 3`・`DECIMALS 1`・`LED_ROWS 3`）。フォントの 12 番目の字（負号か）らしいが、原因は調べていない。客室高度の数字には負号の計器が無い（白の範囲は −2,000 ft から：ATA21 p.451）。どちらも純正の定義のまま。
- 純正の LED のフォントは、1 行 23 画素（字 22・空き 1）で、行の上端から字が始まる。これを使う数字は、置き場所によって、次の行の字の上端が数字の下に薄い線としてにじむ（`s25` の 1 回目：客室高度の白を純正の 5 桁のフォント `x####0.white` にしたら「5095」の 5 と 9 の下に出た。同じフォントの LDG ALT には出ない）。純正のままの琥珀の客室高度（4 桁の `xx###0.amber`）にも出る（`s25` の 2 回目、「8608」の 6 の下。純正 acf も同じ定義）。新しいフォントは字の上に空きを足して作る（`make_led_fonts.ps1`）。琥珀を直すなら同じ作り方の 4 桁のフォントにするパネルの変更になる（承認の一覧に無い）。

- フラップの調べ（4-1 段 1、2026-10-24）で見つけたもの：`flt_ctrls/flap_lever_detent` は 3D の操作子と fltCtrls の両方が書く。autoland の基準速度がフラップ 20 で Vref25、25 で Vref30 になっている（AP `autoland.lua:176-180`、コメントと逆）。GPWS の too low flaps の音は条件がレバー UP だけで、END の条件が `=!` と書いてある（`.snd`）。CONFIG GEAR と >SPEEDBRAKES EXT は着陸フラップを `flap1_deg[0]` > 24.95 で見るので、フラップ 25（22°）を着陸フラップと見ない（段 3 で）。EEC の approach idle はレバーで決まり、荷重軽減中もそのまま。PFD の Vmax はフラップ 25 で約 220 kt（Vfe25 は 205）、失速速度はフラップ 1 を UP と同じに扱う（表示系 5-x で）。X-Plane の acf のフラップは 25 が 25°・30 が 40° のまま（プラグインが舵面を書くので効かない）。

- 安定板トリムなどの調べ（4-1 段 2、2026-10-24。Explore のエージェント）で見つけたもの：AP が外れたあとも AP の昇降舵と補助翼の指令（`flt_ctrls/sim_pitch_ratio`・`sim_roll_ratio`）がそのまま残る（`s01` で AP を外したあと `custom_pitch_ratio` が 1.000 のまま。段 2b で）。オートトリムの実際の速さは狙いの約 1/60（1.2 秒に 1 フレーム分しか動かない）で、電波高度 500 ft 未満ではトリムしない（段 2b で）。CONFIG STAB の帯（FMC のトリム ±2.25、FMC のトリムが無いと 0–4.5）は 3D のグリーンバンドと違い、FMC に重さを入れないまま地上開始のトリム 7.5 units で離陸推力にすると CONFIG STAB が出るはず（段 2b で）。安定板の角度の目盛りが 3 つある（プラグインは 1 unit 2°、acf の flying stab は ±10°、3D の外の安定板は 6°）。ラダートリムの指示器の keyframe が −1・1.0・1 で 0 が真ん中にない（3D、範囲外）。STATUS ページの左内側エルロンの keyframe が 20/0/20（パネル、−20 のはず）。X-Plane で確かめた（2026-10-24）：`flightmodel2` と `cockpit2` の `elevator_trim` は同じ値、安定板の角度はプラグインの −15 × トリムがそのまま入る、トリムのスイッチを押し続けると 0.30 units/s（対気速度に依らない）、ラダートリムのつまみは 1.0（舵面 25.6°）まで回る（acf の 0.3 は X-Plane の空力の効きで、回せる範囲ではない）、空中では X-Plane の `total_heading_ratio` がラダートリムの 0.3 倍を含む（地上では含まない。ペダルだけは `yoke_heading_ratio`）。

## 日誌

- 2026-10-22 23:27〜23:44：利用者が、別の 3D 一式（git に無い）とカスタム acf を作業ツリーに上書きコピー。
- 2026-10-23 00:0x：
  - 変更のあった追跡ファイル 110 個を `D:\747-400-local-assets\` に退避。
  - `archive/old-master`（45cce506）を push。
  - 本家を upstream に追加し、`overhaul`（041c9ffa）を作成。
  - 3D 一式の 72 ファイルを戻して skip-worktree を付けた。
- 2026-10-23 00:3x〜：PDF のテキスト化、REFERENCE_INDEX・ARCHITECTURE・ACF_DIFF・INTERFACES を作成。
- 2026-10-23 00:36〜02:xx：ATA 章ごとの 19 班で notes を作成。
- 2026-10-23 01:0x：利用者が `tests_old/` を置き、試験の方針を追加。TESTING.md と CLAUDE.md を更新。
- 2026-10-23 01:3x：LuaJIT を導入。X-Plane を起動し、Web API・FlyWithLua の記録・スクリーンショットを確認。
- 2026-10-23 01:58：基準シナリオ（カスタム acf）1 回目。APU が始動せず（APU-13）、手順を直した。
- 2026-10-23 02:17：カスタム acf で 2 回目、全項目合格。カスタム acf の FMOD バンクが読まれることを確認。
- 2026-10-23 02:25：純正 acf へ切り替えた直後に X-Plane が止まる。02:37 に起動し直した。
- 2026-10-23 02:38：純正 acf で全項目合格。XTLua の再現（`tests/lib/xtlua.lua`）と、挙動を変えない変更の確認の道具を作った。
- 2026-10-23 02:4x：R-1 の切り出し。X-Plane なしで、切り出し前と全フレーム同じ出力になることを確かめた。試験一式（27e8f854）、R-2（d8adfdd8）、APU-13（cc1a7ce2）をコミット。
- 2026-10-23 02:5x：R-1 の X-Plane での確認（`s01_ap_basic`、カスタム acf）。Lua の誤りなし。R-1 をコミット（5af549c6）。`s01` の 2 回目は機体を読み直さなかったため、低速の空中開始から地面に降りた（シナリオに `"reload": true` を足した、85092512）。
- 2026-10-23 03:0x：電源モデルと試験 115 件（4fb1fa46）。
- 2026-10-23 03:1x〜：電源モデルの組み込み。P5 の灯、EICAS、表示器・CDU・時計の電源、EICAS の計算の電源を乗り換え。カスタム acf で `s02_elec_panel` 59/59。
- 2026-10-23 03:30：電源の組み込みをコミット（f38d0baf）。X-Plane を起動し直し、純正 acf で `s00` 64/64、`s02` 63/63（PSEU の地上の確認を含む）。
- 2026-10-23 03:41：空地判定（PSEU）のモデルと組み込みをコミット（8a7632aa）。
- 2026-10-23 03:42：X-Plane が 2 回目の応答なし（上の「気づいたこと」）。`run_scenario.ps1` を直し、起動し直してカスタム acf で `s01` 15/15（PSEU の air、BCU の air mode を含む）。
- 2026-10-23 03:52：警報の枠組みのモデルと試験 69 件をコミット（001f345e）。カスタム acf で `s02` 63/63（PSEU の地上の確認を含む）。Lua の誤りなし。
- 2026-10-23 03:57：試験ランナーの読み直しの修正と進み具合をコミット（66ca7677）。
- 2026-10-23 04:0x〜：警報の組み込み（1-3 の 2 段目）。モデルに音の要求・caution ごとの beeper・CANC 済みの報告を足し、グルー `B747.87.xt.alerts.lua` を新設、古い待ち行列と表示を外した。CANC/RCL と master リセットは押した回数の dataref で渡す。表のレベルと文言を FCOM に合わせた。試験：モデル 94 件、モジュール 41 件。
- 2026-10-23 04:20〜：X-Plane で `s03_alerts`（新シナリオ）。1 回目は Web API の長さ 0 のコマンドで押しボタンが押されたままになり 25/26（TESTING.md §4.6）。0.2 秒押す形に直してカスタム acf 26/26、純正 acf 26/26。純正 acf の `s00` 64/64。
- 2026-10-23 04:4x：警報の組み込みをコミット（2e0b4cda）。カスタム acf の `s00` も 64/64。油圧（1-4）のモデルと試験 94 件。
- 2026-10-23 05:0x〜：油圧の組み込み（1-4 の 2 段目）を作業用ブランチ `wip/hyd-integration` で。カスタム acf で `s04_hydraulics`（新シナリオ）29/29。`s01` の機首上げを切り分け（上の「気づいたこと」）。
- 2026-10-23 05:2x〜05:4x：X-Plane を起動し直し、油圧の組み込みを両方の acf で確認。カスタム acf：`s01` 15/15（古い油圧の 03:45 とほぼ同じ飛び方）、`s00` 64/64。純正 acf：`s04` 29/29、`s00` 64/64。Lua の誤りなし。`overhaul` に 1 つのコミットで取り込み、作業用ブランチは消した。
- 2026-10-23 07:4x：利用者の回答（承認待ちの件）を PLAN.md §3・CLAUDE.md に記録（fc2635ed）。カスタム acf と `747-400_custom.snd` を git に入れた（936222b0）。`overhaul` を origin に push。
- 2026-10-23 07:5x〜：空圧（1-5）。モデルと試験、空調モジュールへの組み込み（前の抽気のコードを外した）、モジュールの試験。カスタム acf で `s05_bleed`（新シナリオ）41/41。試験キットの視点に視野角を足し、P5 の抽気パネルの VALVE 灯・OFF 灯を画像で確認。
- 2026-10-23 08:1x〜08:4x：カスタム acf の `s00` で 4 発とも回らず（46/60）。原因は X-Plane 自身の抽気の mode と isolation valve の連動（APU の mode で弁が閉じる）で、XTLua の書き込みのキャッシュの仕組みも XTLua のソースで確かめた（上の「気づいたこと」）。グルーは X-Plane に mode だけを書くようにした。見直しの中で、DC が切れたときの弁のラッチ（ATA30_32_35_36 の記載どおり）と、START を何本も引いたときにダクト圧が 10 psi の境目で揺れるのも直した。FCOM p.619 で BLEED ISLN の beeper を見つけた。
- 2026-10-23 08:4x〜09:0x：カスタム acf で `s05` 45/45、`s00` 67/67（始動の時間はベースラインと同じ）、`s04` 29/29。Lua の誤りなし。
- 2026-10-23 09:0x：1-5 をコミット（0f76a4fa）。BLEED ISLN の beeper を警報モデルに足し、`s05` に AC bus 1 なしで ISLN L を動けなくする場面を足してカスタム acf 62/62（aff02c60）。電源のグルーの X-Plane への書き込みを「読んでから、違うときだけ」に直した。
- 2026-10-23 09:1x：`.snd` の警報音（サイレン・ベル・wailer・beeper）を警報モデルの要求に結んだ。`747-400_custom.snd` を変え、手元の `747-400.snd`（skip-worktree、利用者の 3D 一式）も同じにした（git には入らない。元は `D:\747-400-local-assets\files\fmod\747-400.snd`）。カスタム acf で `s03` 26/26、Log.txt に新しい音の誤りなし。
- 2026-10-23 09:2x〜09:3x：純正 acf で `s00` 67/67、`s05` 64/64。`s05` の 1 回目は 60/62：純正 acf は中央タンクが 1,300 kg 以下でポンプが ON なので、燃料系が 60 秒後に FUEL PRESS CTR を出し、BLEED ISLN L の確認の間に master CAUTION を点けた。この確認の間は中央タンクのポンプを止めるようにした。Lua の誤りなし。
- 2026-10-23 09:3x〜09:4x：承認済みのパネルの変更の最初の分をカスタム acf に入れた（EICAS の PG を 2 ページ目から、3〜10 ページ、ダクト圧の色の境と右の数字。ACF_DIFF.md §5）。変更前の acf は `D:\747-400-local-assets\acf_backup\`。X-Plane で、外観（chase 視点）が変わらないこと、2 ページのときの PG 1、3 ページ目と PG 3、ダクト圧の琥珀 0・白 40（主 EICAS と ECS synoptic）を画像で確かめた。
- 2026-10-23 09:4x〜12:5x：STATUS（WARN-17）。警報モデルに STATUS メッセージの並び（新しい順、11 行ずつ）と STATUS cue（STATUS ページを出すと見たことになる。エンジン始動からリフトオフ 30 分後まで・着陸の RA 800 ft〜75 kt は出さない）を足し、グルーが STATUS ページの行・ページ数・cue を書く。status メッセージを立てる側：油圧（HYD PRESS ENG・DEM、HYD OVHT SYS、HYD RSVR PRESS、HYDIM）、空圧（BLEED ASCTU A・B、BLEED ISLN L・R・APU）、電源（DRIVE DISC 1〜4）。カスタム acf の STATUS ページにメッセージ行と PG、主 EICAS に cue（ACF_DIFF.md §5）。試験はすべて通る（13 本）。X-Plane（カスタム acf）：エンジン停止・バッテリーで 14 件・2 ページ・cue、STAT でページ送りと閉じる、cue が消える。エンジン運転中（読み直し後）は新しい順で cue は抑止。APU 発電機の給電で STATUS ページを画像で見て、1 行目が APU BATT の値に重なっていたので、行を 14 px 下げた。外観（chase 視点）は変わらない。Lua の誤りなし。
- 2026-10-23 13:0x〜13:3x：HYD synoptic（HYD-19 の一部）と RSVR PRESS（HYD-18）。油圧のグルーが synoptic の記号の状態（EDP の OFF・ON 琥珀、DEM の AUTO・AUTO 琥珀・ON 琥珀・OFF 琥珀、AUX の OFF・待機・運転・不能、火災スイッチの SOV、RSVR PRESS）を出し、カスタム acf の synoptic がそれで出し入れする（ACF_DIFF.md §5）。試験：モデル 132 件、モジュール 122 件。X-Plane（カスタム acf）：エンジン運転中に ENGINE 1 OFF（EDP OFF 琥珀）、DEMAND 2 OFF（OFF 琥珀）、DEMAND 4 AUX（DEM OFF、AUX 待機）、ADP 1 に空気なし（AUTO 琥珀）、火災スイッチ 4（SOV 閉）。エンジン停止で APU 発電機・APU 抽気なし（RSVR PRESS 4 つ、ADP の AUTO 琥珀、AUX OFF 白）、AUX にして AUX 運転。画像で位置と色を確かめた。外観は変わらない。Lua の誤りなし。
- 2026-10-23 13:4x：ELEC synoptic の ISLN の枠を BTB の状態で、DRIVE の枠を IDG の油圧低（P5 の DRIVE 灯と同じ）で、STAT ページのバッテリーの V-DC・A-DC を電源モデルの値で出すようにした（カスタム acf、ACF_DIFF.md §5）。試験：電源モジュール 72 件。X-Plane（カスタム acf）：エンジン運転中に BUS TIE 2 OFF で ISLN 2、DRIVE DISC 1 で GEN CONT 1 OFF と DRIVE 1。エンジン停止・APU GEN 1 で DRIVE 4 つ、ISLN なし、STAT の MAIN BATT 28 V・9 A（充電）、APU BATT 28 V・2 A。外観は変わらない。Lua の誤りなし。
- 2026-10-23 13:5x：本家 mSparks43/747-400 に、Gakugaku87/747-400 の `overhaul` からの PR #956 が開いているのに気づいた（07:59 に Gakugaku87 で作成。私の操作ではない。push のたびに更新されていた）。利用者が 13:59 に閉じた。fork の中で見るための比較元として、`overhaul` の土台（041c9ffa）に `overhaul-base` ブランチを作った（作り直しの差分＝`overhaul-base...overhaul`）。
- 2026-10-23 14:0x〜14:4x：APU（2-1）。制御を 1 つのモデルにまとめ、電源モジュールのグルーで回す。前の APU の処理（電源、エンジン）を外し、quick start の待ちを延ばした。`s00` の APU の手順を FCOM どおり（START に回して離す）に直した。試験：APU モデル 46 件・モジュール 28 件、電源モデル 119 件。X-Plane：START を離してもドア全開（12 秒）で starter、95 % で RUNNING と AVAIL、APU GEN、OFF で発電機が落ちて 60 秒後に停止、APU・APU DOOR は出ない。`s00` はカスタム acf・純正 acf とも 69/69。Lua の誤りなし。
- 2026-10-23 15:0x〜：燃料（2-2）。FCOM 12.20-12.30 と ATA26_28 から燃料モデルを書いた（試験 117 件）。値の無いところ（重力移送・水平安定板タンクのポンプ・ジェティソンの流量、APU の消費、ポンプの AC バスの割り当て、フラップの離陸範囲の換算など）は推定（コードに明記）。
- 2026-10-23 15:2x：利用者の質問（表示器が真っ暗）で調べ、同じ機体のまま新しいフライトを始めると X-Plane が汎用ライト 63 を 0 に戻し、表示器と CDU が消えることが分かった（両 acf）。照明モジュールが毎フレーム戻すようにした。
- 2026-10-23 15:3x〜16:4x：燃料（2-2）の組み込み。燃料モジュールの前の論理を外してモデルで回し、頭上の灯は新しい `fuel/light/*` を照明モジュールが読む。モデルに APU の DC 燃料ポンプと APU FUEL、FUEL RES XFR の左右を足した。試験：モデル 124 件、モジュール 62 件、照明 37 件。X-Plane（カスタム acf）：`s06_fuel`（新シナリオ）42/42、空中で予備移送（4 弁）・安定板タンクの移送・ジェティソン（約 2,200 kg/min、残り時間 17.9 分）、synoptic と頭上の灯を画像で確認。`s00` は純正 acf・カスタム acf とも 69/69。Lua の誤りなし。利用者の依頼で、全分野の実機との違いを DIFFERENCES.md にまとめた。
- 2026-10-23 16:4x〜17:1x：燃費（FUEL-05）。巡航の測定のシナリオ `s07_cruise_ff` を作った（FL350 で空中開始、空中開始で上がった高度から FLCH で 35,000 ft に戻して ALT と SPD。A/T は MCP の 294 kt に届かず、その手前で釣り合った）。前のカスタム acf は Mach 0.791 で 1 発 1,612 kg/h、純正 acf は Mach 0.756 で 2,167 kg/h（FCOM PI.11.2 の見込みに近い）だったので、カスタム acf の `_jet_SFC_*` 4 つを純正と同じにした（バックアップ `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261023_before_sfc`）。変更後は Mach 0.788 で 2,134 kg/h。外観は chase 視点で変わらない。ACF_DIFF.md の壊れていた 1 行（HYD synoptic の行の頭）も直した。
- 2026-10-23 17:1x〜17:5x：エンジン（2-3）段 1。始動・点火・燃料弁をエンジンごとの状態機械のモデルとグルーで作り直し、前の始動・starter・igniter・燃料弁の処理と ENG FAIL・>ENG SHUTDOWN・STARTER CUTOUT の判定を外した。抽気のモデルは start valve の指令を `engines/start_valve_cmd` から受ける。advisory に >AUTOSTART OFF と ENG FUEL VLV を足した。試験：モデル 77 件、モジュール 18 件、抽気モジュールの試験も合わせた。X-Plane：`s08_autostart`（新シナリオ）38/38（1 回目は始動の点火が idle まで続いたので、FCOM p.879 どおり cutout で止めた）、`s00` は両 acf 69/69。Lua の誤りなし。利用者から、違和感のない範囲ならパネルの画像を作ったり直したりしてよいと答え（「決まったこと」）。
- 2026-10-23 17:5x〜19:0x：パネルの画像（利用者が夕方に「違和感のない範囲なら作ってよい」と答えた分）。画像は `docs/overhaul/tools/make_synoptic_images.ps1` で純正の絵から作る（PowerShell と System.Drawing だけ）。HYD synoptic：記号を丸ごと色付きにした（DEM の AUTO シアン・AUTO 琥珀・OFF 琥珀・ON 琥珀、AUX の OFF 白・待機シアン・琥珀、EDP の ON 琥珀。背景の白い記号から切り出したので画素まで重なる。EDP OFF の位置のずれも直した）。不作動項目の絵を作り直した：各系統の一覧（P&W は THRUST REV つき）と、負荷の割り当てから出した組 6 つ（1+2・1+3・2+3・2+4・3+4・1+2+4）。油圧モデルが `synoptic/inop`・`inop_set` を出す（gen_text の `text_off`・`text_auto` は外した）。ELEC synoptic：UTILITY と GALLEY を母線ごとに別の画像にし、`bus/utility`・`bus/galley` で緑・琥珀。STAT：背景の固定の DIS を消し、白の CHG・DIS を `battery/amps` の向きで出す。試験：モデル 160 件、モジュール 136 件。X-Plane（カスタム acf）：通常（AUTO シアン、AUX OFF 白）、系統 1・3 を止めて系統 4 を AUX（OFF 琥珀、EDP OFF、AUX 待機シアン、一覧 1・3 と組 1+3）、4 系統すべて（全部の一覧と組、線の切れ目）、GEN CONT 1・2 OFF で galley の負荷制限（GALLEY 1・2・4 琥珀）、発電機を戻して CHG、APU 始動中に APU BATT の DIS。いずれも画像で位置と色を確かめた。外観は変わらない。Lua の誤りなし。
- 2026-10-23 19:0x〜19:5x：エンジン（2-3）段 2 の一部、EEC の定格とレバーの指令。新しいモデル `B747.42.eec_model.lua` に FCOM PI の表（PW4056 の着陸復行 EPR と最大上昇 EPR、CF6-80C2B1F の着陸復行 %N1 と最大上昇 %N1、抽気の補正）を入れ、全開のときの定格を高度と速度で選び（CF6 の論理）、レバー角をアイドル端から最大定格までの指令にした（48°・35° で頭打ち）。グルー `B747.42.xt.eec_thrust.lua` が TRA（推力の制御と A/T の目標）と上の EICAS の最大線を書く。FMC の推力基準と A/T のサーボは 6-4 へ残した。RR は前のまま。ENG-19（空中の N2 を 0 にしない）。upstream の表には写し間違いがあった（GE の最大上昇 %N1 の TAT 25・0 ft、補正の 30,000 ft など）ので、FCOM のページから入れ直した。試験：モデル 47 件、モジュール 15 件（新設）。X-Plane（カスタム acf）：地上の全開で EPR が最大定格 1.513 に収まる、`s07_cruise_ff` 5/5（A/T の SPD が FL350 で 291 kt まで加速。前は 267 kt で頭打ち）。純正 acf：`s00` 69/69、地上の全開で 1.533 に向かう。Lua の誤りなし。途中で、新しいグルーを `B747.42.xt.eec.lua` と名づけて既存の `B747.42.xt.EEC.lua` を上書きした（Windows は大文字小文字を区別しない）。git から戻した。
- 2026-10-23 19:5x〜20:0x：エンジン（2-3）段 2 の続き、アイドルの選択（ENG-06・07）。EEC のモデルがエンジンごとに approach idle を選び（空中でそのエンジンの防氷・着陸フラップ・405 と 570 の CON・GE の逆推力、条件が終わって 5 秒・接地 5 秒後に minimum）、グルーが X-Plane のアイドル（全エンジンで 1 つ）を書く（変わったときだけ）。型式ごとのアイドルの関数は表示用の N1 を返すだけにした（前は毎フレーム 4 回 X-Plane に書き、空中で approach から戻らなかった）。ENG n LOW IDLE（advisory 309〜312）と次の段で使う ENG n EEC MODE（313〜316）・>ENG n LIM PROT（caution 75〜78）を警報の表に足した。試験：モデル 63 件、モジュール 26 件。X-Plane：新シナリオ `s09_eec`（カスタム acf）15/15（NAI 1 で approach idle、閉じて約 5 秒で minimum、109 の CON では approach にならない）。Lua の誤りなし。
- 2026-10-23 20:0x：エンジン（2-3）段 2 の続き、EEC の ALTN（ENG-05）。EEC MODE スイッチで代替モードにすると、指令が最大定格で頭打ちせず、その高度で一番大きい定格（表の角の値、抽気の補正なし）までレバーに比例する（同じレバーで normal 以上、全開で overboost）。ENG n EEC MODE・>ENG n LIM PROT を出し、代替モードに入ると A/T を切る。GE は 4 基とも代替なら、P&W は全部 normal なら A/T をまた使える（前の「ALTN で A/T を切るだけ」の処理を置き換えた）。試験：モデル 82 件、モジュール 38 件。X-Plane：`s09_eec` に ALTN を足して 23/23（A/T の SPD 中に EEC MODE 2 を ALTN で ENG 2 EEC MODE、A/T が切れて FMA の A/T も消える、ALTN の間は A/T を入れ直せない、NORM で使える）。この高度と気温（10,000 ft、TAT 約 2 ℃）では P&W の表が角の値と同じなので、ALTN の指令は normal と同じだった（計算どおり）。Lua の誤りなし。
- 2026-10-23 20:1x〜22:3x：エンジン（2-3）段 2 の終わり、オーバースピード保護と >ENG RPM LIM（ENG-03・04）、推力の制御の作り直し。保護を X-Plane で試す（`s10_overspeed`、新設：10,000 ft・海面 50 ℃・4 基 ALTN の全開）と、前の PID の行き過ぎ（EPR が指令を 0.03 超えて十数秒、N2 表示 112 %）が保護より先に効いて赤線を超えた。前の PID は D 項が大きくスロットルが 0.9〜1.05 を往復し、積分が 1.2 まで溜まって通常モードでも最大定格を 0.02 超えていた。X-Plane で静特性（スロットル→表示 EPR・N1）と段の応答を測り、推力の制御を EEC のモデルに移した（速度形の PI、傾きの表でゲインを割る、追う値の時定数と速さの上限、アイドル端でスロットル 0）。途中で試した「レバーの割合を足す」「測った表を足す」は表の誤差を補正の積分が運び、悪くなった。GE は大きく絞ると目標を 10 % 下回った（X-Plane のエンジンは絞り切ると上げに転じるのに 3 秒ほどかかる）ので、下げの速さを 5 %/秒にした。指令に届かないときに X-Plane の最大推力を足す前の仕組みは、条件の「X-Plane の N1 > 99.99 %」が空中で成り立たず GE が高い定格に届かなかったので、スロットル 1 で判定するようにした。キットのシナリオでリバリー（エンジン型式）を選べるようにした（GE は Saudia）。試験：モデル 122 件、モジュール 59 件、全 22 本。X-Plane（カスタム acf、P&W）：`s10_overspeed` 22/22（ALTN の overboost で EPR が指令 1.67 に ±0.003、N2 107 %。N2 の赤線を一時的に 107 % に下げた確認では 106 % で止まり ENG 1・4 RPM LIM）、`s11_takeoff_thrust`（新設）7/7（6 秒で EPR 1.503、40 kt・80 kt で最大 1.513）、`s09_eec` 23/23、`s07_cruise_ff` 6/6（294 kt に届くまで待つようにした。空中開始の後の FLCH の降下が 170 kt で来るため：「気づいたこと」）。レバーの段（10,000 ft）：P&W は ±0.002 EPR で行き過ぎなし、GE は ±0.2 %、104→60 % の減速で 0.9 % 下回るだけ。GE の離陸 7/7（N1 104 % に追従）。純正 acf：`s00` 69/69。Lua の誤りなし。
- 2026-10-23 22:4x〜23:1x：エンジン（2-3）段 3 の始め、EGT の色・抑止・始動限界の線（ENG-20）。新しい表示のモデル `B747.40.engine_display_model.lua` とグルー `B747.40.xt.engine_display.lua` で、型式ごとの限界（CF6 は ATA70_80 p.395、P&W・RR は前の値）から白・琥珀・赤を決め、TO/GA スイッチを押してから 5 分（P&W はエンジンが止まれば 10 分）は琥珀にしない。始動限界の線は CUTOFF と始動の途中で出し、その間は始動限界で赤。前の処理（A/T の TOGA の保持に連動した抑止、帯の線を消す、4 基分の写し）は外し、スプール時間を書く部分だけ残した。パネル（カスタム acf）：EGT の帯・枠・数字の赤・琥珀・白を新しいフラグ（`EGT/red_on`・`amber_on`・`white_on`）で出し、始動限界の印を `EGT/start_limit_on` で出す（GE の固定の閾値と X-Plane の N2 55 % の条件をやめた。ACF_DIFF.md §5。バックアップ `acf_backup\747-400_custom.acf.20261023_before_egt_flags`。外観は chase 視点で変わらない）。試験：モデル 23 件、モジュール 13 件、全 24 本。X-Plane（カスタム acf）：`s08_autostart` 44/44（運転中は線なし、CUTOFF で線、RUN でも始動中は線、アイドルで落ち着くと消える。画像で確認）、`s11_takeoff_thrust` 9/9（TO/GA を押して離陸推力：EGT 294〜350 ℃ で白）。P&W の限界を一時的に下げた確認で、帯・枠・数字の琥珀と、帯・数字の赤を画像で確かめた（P&W の枠は赤の絵が無く消える：「気づいたこと」）。純正 acf：`s00` 69/69。Lua の誤りなし。
- 2026-10-23 23:1x〜23:5x：エンジン（2-3）段 3 の続き、逆推力（ENG-31 の一部・32）。新しいモデル `B747.40.reverser_model.lua` とグルー `B747.40.xt.reverser.lua`：P&W は関係する油圧系統（エンジン n は系統 n、1,000 psi 以上。RR も同じとした）、GE はそのエンジンの運転（抽気）が無いと逆推力が動かず、地上の判定は逆推力ごとの継電器（1・4 は PSEU primary、2・3 は alternate）。動けない逆推力は今の位置のまま。ENG n REVERSER（advisory 126〜129）は、乗員が求めているのに格納のまま、または逆推力でないのに展開のままが 2 秒続くか、X-Plane の故障。X-Plane で試すと、動けない逆推力にも X-Plane がフレームの間に書かれた逆推力のスロットルで動き始め（0.05 まで出た）、Web API のコマンドは phase 2 がすぐ届いて要求が残らなかったので、逆推力のコマンドは動けるエンジンにだけ prop mode 3 と逆推力スロットルを書き（全エンジンの保持は `throttle_jet_rev_ratio_all` でなくエンジンごと）、全エンジンの保持の要求は取り消しまで覚えるようにした。`B747_prop_mode` の未定義の `i`（ENG-32）も直した。試験：モデル 22 件、モジュール 21 件。X-Plane：`s12_reverser`（新設）19/19（カスタム acf で 4 基とも約 4 秒で展開して REV 緑、系統 1 の圧を抜くと逆推力 1 だけ動かず ENG 1 REVERSER。画像で確認）、`s11_takeoff_thrust` 9/9、純正 acf の `s00_baseline_start` 69/69。
- 2026-10-24 00:0x〜00:3x：エンジン（2-3）段 3 の続き、オイルと振動（ENG-25〜27・29 の Lua の部分）。表示のモデル `B747.40.engine_display_model.lua` にオイルと振動を足し、グルー `B747.40.xt.engine_display.lua` が `oil_press_psi`・`EICAS2_oil_press_status`・`oil_temp_degC`・`oil_qty_liters`・`vibration` と ENG n OIL PRESS（advisory 317〜320 を足した）・ENG n OIL TEMP を書く。前の処理（乱数を足すだけ、CUTOFF でも赤、油量は全エンジンが 1 番の比、火災で振動 2〜3）は外した。X-Plane のオイルポンプの故障（`rel_oilpmp0`）で油圧が 3 秒ほどで 0 になり、外すと戻ることを確かめて試験に使った。試験：モデル 66 件、モジュール 24 件。X-Plane：`s13_oil`（新設、カスタム acf）20/20（油圧 1 が赤と ENG 1 OIL PRESS、戻すと消える、地上の CUTOFF では白でメッセージも隠れる、油量はエンジンが止まると 27 L に戻る。画像で確認）、`s13_oil_ge`（新設、Saudia）10/10（赤線を切って赤、低圧スイッチ 10 psid で ENG 1 OIL PRESS、15 psid で消える）、`s08_autostart` 47/47（CUTOFF と始動中の油圧は 35 psi でも白）。パネル（GE の油圧の目盛りと琥珀、数字の色、油量のマゼンタ、振動の音源）は表示形式の項目で直す。
- 2026-10-24 00:3x〜01:0x：エンジン（2-3）段 3 の続き、小さな誤り（ENG-23・30・35・37）。スプール時間（ENG-35）：X-Plane のスプール時間（全エンジンで 1 つ）を、地上で始動中（start valve が開いているか、始動モデルの燃料からアイドルまで）は 26 秒、それ以外は 5 秒にした。前はエンジンの運転数で決めていて、ほかのエンジンが回っていると始動が 3 倍速く、純正 acf の s00 では 1 番エンジンだけ RUN からアイドルまで 15 秒（ほかは 41 秒）だった。最初は始動モデルの段階だけで判定したが、手動始動は RUN まで段階が off のままなので、最初のエンジンの motoring が速いままだった（start valve の指令も見るようにして直した）。二次エンジン表示（ENG-23）：コマンドのハンドラーだけ直すと、init の `switch_target` の書き込みハンドラーが地上でも表示を出していた（X-Plane の s08 で見つけた。テストのモックは init のハンドラーを動かさない）。燃料投入の印（ENG-37）は火災スイッチを引くと消える。型式の文字列（ENG-30）。試験：EEC モジュール 61 件、始動モジュール 27 件、燃料モジュール 66 件。X-Plane：カスタム acf と純正 acf の `s00_baseline_start` 69/69（4 基とも START から 20 % N2 まで約 23 秒、RUN からアイドルまで約 41 秒）、`s08_autostart` 55/56（二次エンジン表示・燃料投入の印・スプール時間は通った。落ちた 1 つは前提の確認で、CUTOFF の直後の油圧が 73 psi とまだ 70 psi を切っていなかった。待つ形に直した）、`s09_eec` 25/25（空中で CUTOFF にすると二次エンジン表示）。空中の始動は 5 秒のままで速い（気づいたこと）。試験の途中、待ち合わせの誤りで s08 と s09 が同時に始まり、X-Plane が内部エラー（`MACIBM_alert: spin_pwr_dg v=NaN`）で止まったので、起動し直した（TESTING.md §4.6）。
- 2026-10-24 01:5x〜02:xx：エンジン（2-3）段 3 の続き、超過の赤い枠と色（ENG-21）。表示のモデルに N1・N2・N3 の赤線と P&W の EPR の最大を足し、新しいモデル `B747.40.exceedance_model.lua` が N1・EGT・N2・N3 の枠を、限界に達すると赤、戻っても赤のまま、EICAS の CANC で白・RCL で赤にする（CF6 の N2 は 20 秒で赤のまま）。グルーが新しい flag（`N1/red_on`・`N1/box_red`・`N2/…`・`N3/…`・`EGT/box_red`・`EPR/red_on`）を書き、カスタム acf のパネルの条件 192 か所を道具 `docs/overhaul/tools/panel_limit_flags.lua` で置き換えた（ACF_DIFF.md §5）。前のパネルは EPR を 1.9 で赤、P&W の N1 の枠を X-Plane の N1、P&W の EGT の枠を X-Plane の EGT（尺度が違う）で赤にしていた。試験：表示のモデル 82 件、モジュール 40 件、赤い枠のモデル 16 件。X-Plane：`s11_takeoff_thrust` 12/12（全開で最大 EPR に届くと EPR の帯が赤、数字と枠は白、アイドルで白に戻る。画像で確認）。赤い枠は、今の値では実際の運転で超過が起きないので（表示の EGT が低い ENG-33、N1・N2 はオーバースピード保護で赤線の手前に止まる）、限界を一時的に下げた版（P&W の N1 25 %・N2 60 %・EGT の始動限界 200 ℃、コミットしない）で確かめた：N1・N2・EGT の数字・帯・枠が赤、CUTOFF で回転と EGT が下がると数字は白で枠は赤のまま、CANC で白、まだ赤い別のエンジンの枠は赤のまま（画像で確認）。GE（Saudia）も同じ（N1 15 %・N2 50 %・EGT の始動限界 200 ℃ に下げた版）で、N1 と EGT の数字・帯・枠、CUTOFF の後の枠、CANC を確かめた（N2 の最初の確認だけ、開始直後の GE の N2 表示が 44 % 前後で 50 % に届かず落ちた）。外観は chase 視点で変わらない。純正 acf の `s00_baseline_start` 69/69。hot start の故障で EGT を始動限界より上げるシナリオも作ったが、X-Plane の EGT は最高 478 ℃（表示で約 330 ℃）で届かず、やめた。
- 2026-10-24 02:3x〜03:xx：エンジン（2-3）段 3 の続き、オイルと振動のパネル（ENG-25〜27・29 の残り）。グルーが GE の油圧の琥珀（`oil_press_amber`）、油量のマゼンタ（`oil_qty_magenta`）、振動の音源（`vib_source`：0 BB、1 N1、2 N2、3 FAN、4 LPT）を書き、カスタム acf のパネルを道具 `docs/overhaul/tools/panel_oil_vib.lua` で書き換えた（24 か所、計器を 28 個足した。ACF_DIFF.md §5）：油圧の赤い数字は状態だけで出す（前は 10 psi 未満のときだけで、赤線と 10 psi の間では数字が消えた）、GE の琥珀の数字と針、油温の数字の琥珀は 160 ℃ から（前は 150 ℃ からで白と重なった）、油量のマゼンタの数字、振動の音源の文字。音源の文字の絵（N1・N2・FAN・LPT）は、BB の絵（17 px、白い太字、縁が柔らかい）にそろえて `docs/overhaul/tools/make_vib_labels.ps1` で作った。試験：モジュール 46 件。X-Plane：`s13_oil` 20/20（P&W。振動の音源は 4 基とも N2、オイルポンプ 1 の故障で油圧 1 が赤い数字と赤い針。画像で確認。振動の音源の確認はこの回の後に足した）、`s13_oil_ge` 11/11（Saudia。音源は N2。画像で確認）。外観は chase 視点で変わらない。
- 2026-10-24 04:2x：空地判定（1-2）のしきい値の修正。PSEU はトラックの傾きを X-Plane の `eagle_claw_angle_deg` が 1° を超えたかで見ていたが、この角度は地上では機体の機首下げの角度（駐機 0.85°、推力を出した滑走 1.1°、強いブレーキ 1.75°）で、滑走中とブレーキ中に AIR になっていた（空調の `s14` で、離陸の中止の後に与圧が climb モードになって見つけた。X-Plane で 50 kt からの急ブレーキを測った）。空中の角度は acf の 8°・58° なので、しきい値を 4° にした。試験：PSEU のモデル 20 件（強いブレーキと機首上げで地上のまま）・モジュール 12 件。X-Plane の `s14_press_ground` の離陸滑走と中止で、与圧のモードが takeoff → ground（空中扱いにならない）。
- 2026-10-24 03:0x〜05:xx：空調（3-1）段 1 (a)、パックと与圧。X-Plane の与圧の上書き（override_pressurization）を Web API で試し（書いた客室高度・昇降率・ΔP がそのまま計器に映る、X-Plane は客室を積分しない、ダクトの空気と抽気の損失も更新しなくなり、エアスターターは書いた値で回る）、上書きにした。新しいモデル 2 つ（`B747.55.pack_model.lua`：弁・normal/high・スケジュール・再循環ファン・PTC A/B・トリップ・メッセージ、`B747.55.press_model.lua`：客室の質量収支・CPC A/B・モード・着陸高度（FMC の経路の出発地・目的地の標高を X-Plane の earth_aptmeta.dat から）・リミッタ・手動・リリーフ・減圧の故障・メッセージ）とグルー（`B747.55.xt.packs.lua`・`B747.55.xt.press.lua`）。抽気のグルーが X-Plane のダクトの空気（ダクト圧 ÷ 27.5：上書き前の X-Plane 自身の値を `s00` の写しで測って合わせた）と抽気の損失を書き、抽気のモデルはパックの流量を使う。EEC は運転中のパック数（AIR-16）。巡航の ΔP 8.8 は FCOM p.585 の表示例から（8.9 は琥珀）。外流弁は 10 秒では離陸の瞬間に客室が 50 ft 上がったので 6 秒にした。X-Plane の試験で、空地判定のしきい値の誤り（上の 04:2x）、フライト開始直後の空地判定の遅れ（最初の 3 秒は対地高度で初期化）、空中開始の落下（落ち着くまで初期化）を直した。試験：パックのモデル 55 件、与圧のモデル 99 件、モジュール 54 件、抽気のモデル 77 件、EEC のモジュール 61 件、全 30 本。X-Plane（カスタム acf）：`s14_press_ground`（新設）、`s15_press_cruise`（新設）、外流弁計の針が OP を指すこと、data block の表示（写真）。
- 2026-10-24 05:1x：空調（3-1）段 1 (b)、機器冷却とエンジン運転中の開始のスイッチ。新しいモデル `B747.55.eqcool_model.lua` とグルー `B747.55.xt.eqcool.lua`：NORM・STBY・OVRD の構成（地上は外気 45°F で機外か前方貨物室、各翼 1 基の運転で flight 構成）、ファン故障の closed loop と OVRD 30 秒のリセット、OVRD の差圧不足 55 秒で EQUIP COOLING、OVRD で抜ける客室の空気を与圧のモデルへ、貨物室火災 ARM で OVRD の構成。前の `equipment_cooling()`（NORM で `equip_cooling/state` を 1 にするだけ）は外した。エンジン運転中の開始で TRIM AIR・RECIRC ON（manipulators は TRIM AIR の位置を [83] に書いていた）、EQUIP COOLING NORM（AIR-19）。後方貨物室暖房は温度が要るので段 2 に回した。試験：機器冷却のモデル 21 件、モジュール 59 件、全 31 本。X-Plane（カスタム acf）：`s14_press_ground` 66/66（開始の TRIM AIR・RECIRC・EQUIP COOLING と上のファン、地上の OVRD で 55 秒後に EQUIP COOLING、NORM で消える）。
- 2026-10-24 05:5x：空調（3-1）、グルーどうしで渡す出力の表の修正。パックと与圧のグルーが出力の表をメタテーブル無しでグローバルに置いていたため、XTLua の名前空間がコピーし、数と真偽の項目が止まっていた（機器冷却が客室の ΔP を 0 と読み、飛行中の OVRD で差圧があっても EQUIP COOLING が出た）。`setmetatable` を付けて同じ表を渡すようにし、空調モジュールの試験に名前空間の表の確認を足した（直す前の版で 2 件落ちることを確かめた）。段 2 の温度のグルーを結線したときに、パックの運転数が 0 のままで見つけた。
- 2026-10-24 05:2x〜06:3x：空調（3-1）段 2、温度制御と貨物室の温度・暖房。新しいモデル `B747.55.temp_model.lua` とグルー `B747.55.xt.temp.lua`：7 ゾーンの target と温度、最も冷たい空気が要るゾーンでパックの出口（35°F・28°F〜135°F）、トリム空気と master trim air valve（TRIM AIR ON・パック運転・中央ダクト）、backup（ゾーン弁 10 %、客室の平均を PASS TEMP の値に、ZTC の故障では最後の値、F/D は 85°F まで）、ダクト 185°F・10 秒のラッチと ZONE RST、165°F・30 秒の TEMP ZONE、comfort correction、>TRIM AIR OFF・TEMP ZONE・STATUS ZONE TEMP（新設）・ZONE SYS FAULT 灯、後方貨物室暖房（選択温度 40°F：推定、90°F で閉じて TEMP 灯と TEMP CARGO HEAT、AFT の火災 ARM）、前方貨物室（機器冷却の排気と 40/50°F のヒーター）。パックのモデルは cruise clamp の normal flow を客室の温度で待つ（最長 20 分）。熱のつり合いの値は資料に無く推定。試験：温度のモデル 75 件（新設）、パックのモデル 61 件、モジュール 73 件、32 本すべて通る。X-Plane（カスタム acf）：`s16_temp_ground`（新設）36/36、`s15_press_cruise` 41/41（巡航の温度と EQUIP COOLING OVRD を足した）、`s14_press_ground` 66/66。純正 acf の `s00` 69/69。最初の `s15` で前方貨物室が −6 ℃ だった（フライト開始の最初のフレームでバスと機器冷却の排気が 0 に読め、排気なしの初期値になった）ので、与圧のモデルと同じく最初の 3 秒は初期値を置き直すようにした。最初の `s16` は PASS TEMP を 0.5 に戻す書き込みが Web API に拒まれた（XTLua の double の dataref に小数を書けない。TESTING.md に既にある癖を 12.4.4 で確かめた）ので、W と C の両端で確かめる形にした。Log.txt に Lua の誤りは無い。
- 2026-10-24 06:3x〜07:0x：空調（3-1）段 3、ECS synoptic のパネル（AIR-15、PNEU-11）。道具 `docs/overhaul/tools/panel_ecs.lua` でカスタム acf の ECS synoptic に、7 ゾーンの target（小さく、`temp/target_shown`）と actual、MASTER、FWD・AFT、TEMP °C、外流弁の針（−1〜+1 を CL・OP の目盛りの ±64°）と弁ごとの MAN（琥珀）・AUTO、パックごとの HI FLOW、EXT AIR を足し、パックの OFF/A/B を弁と使用中の PTC で、エンジンと APU の流れを弁で出すようにした。抽気のモデルに EXT AIR（`air/ext_air`）を足した。新しい絵は `make_ecs_images.ps1`（針、琥珀の MAN）。INTERFACES.tsv にパネルが読む dataref を 10 個足した。最初の版は LED の `LED_ROWS` をダクト圧の計器（書式 `xxx#00`、3）から写したので、書式 `xx###0`（4）の字で次の字の一部が数字に重なった。針は最初 ±90° にしたが、全開・全閉で計器の縦の線と重なって見えないので、目盛りに合わせた。PNEU-09 は段 1 の data block の条件で済とした。試験：抽気のモデル 82 件、32 本すべて通る。X-Plane：`s17_ecs_synoptic`（新設）15/15（写真で数字・針・AUTO・HI FLOW・A、TRIM AIR OFF で target が消える、MAN L で琥珀の MAN と L の針、PACK 1 OFF、ENGINE BLEED 1 OFF の流れの線）、外から見た機体は変わらない、純正 acf の `s00` 69/69。Log.txt に Lua の誤りは無い。客室高度の赤い数字の桁と data block の LDG ALT の消去（AIR-18）は承認の一覧に無いので利用者に確認中。
- 2026-10-24 07:0x〜07:5x：防氷・防雨（3-2）。新しいモデル `B747.50.antiice_model.lua` と、防氷のモジュール `B747.50.xt.antiice.lua` をそのグルーに書き直した：NAI 弁（PRV の下流の抽気、28V DC、過熱のラッチ、VALVE 灯、NAI VALVE n）、WAI 弁（空中でスイッチ ON、モーター、指令と比べる VALVE 灯、WAI VALVE LEFT・RIGHT）、窓の加熱（INOP・HEAT WINDOW、10 秒の入れ直し）、プローブの加熱（HEAT …、X-Plane の AOA・TAT の加熱）、氷検知（>ICING・>NO ICING・>ICE DETECTORS・STATUS ICE DETECTOR L/R）、>ANTI-ICE、ワイパー（50・100 %、28V DC）。X-Plane へは左右別々に、変わったときだけ書く（前は左右共通のコマンドで、片側が違うと毎フレーム ON と OFF が入れ替わった：ICE-01）。照明のモジュールの P5 の灯はモデルの出力を読む。エンジン始動の点火の NAI はスイッチから、ER 開始で WINDOW HEAT ON。init の型の括弧の誤りも直した。試験：モデル 47 件、モジュール 174 件（モジュールが書く X-Plane の dataref がすべて書き込み可かも見る）、照明 50 件。X-Plane（カスタム acf）：新シナリオ `s18_antiice_ground` 91/91（NAI の灯と EICAS の NAI、inlet heat の故障で NAI VALVE 2、地上の WAI、窓の INOP とリセット、HEAT P/S CAPT、>ICE DETECTORS と STATUS、ワイパー）、`s19_antiice_air` 25/25（空中の TAT の加熱、WAI 弁が 2.7 秒で開き EICAS に WAI、HEAT R TAT）、`s05_bleed` 64/64。純正 acf の `s00` 69/69。Lua の誤りなし。P5 の VALVE・INOP 灯の位置はスクリーンショットで確かめた。
- 2026-10-24 08:0x〜08:3x：酸素（3-3）。新しいモジュール `B747.36.xt.oxygen`：モデル `B747.36.oxygen_model.lua`（乗客酸素の約 14,000 ft の自動作動・ON・12,000 ft 未満の RESET、治療用酸素、ボンベの圧を前方貨物室の温度で補正、>CREW OXY LOW、PASS OXYGEN ON と 60 秒の STATUS、THERAP OXYGEN ON、乗員マスクの低酸素の高度）、グルー、init（dataref・コマンド、X-Plane の酸素系統の上書き）。3D に操作子が無いので、スイッチとマスクはコマンド。照明のモジュールのサインに乗客酸素の条件、警報の表に STATUS PASS OXYGEN ON（39）。カスタム acf の STATUS ページの酸素圧（承認済みのパネル変更。ACF_DIFF.md §5）。Web API から長さ 0 で ON を送るとスイッチが ON のまま残った（XTLua が離したことを渡さない：TESTING.md §4.6）ので、ばね戻りはコマンドの最後のイベントから 0.3 秒で戻すようにした。試験：モデル 47 件、モジュール 63 件。X-Plane（カスタム acf）：新シナリオ `s20_oxygen` 38/38（STATUS ページの 1828・1828、PASS OXYGEN ON とサイン、60 秒の STATUS、RESET、THERAP OXYGEN ON、急減圧で自動作動と 12,000 ft より上の RESET 不可、乗員マスクで X-Plane の `pilot_felt_altitude_ft` が 10,000 ft）。純正 acf の `s00` 69/69。Lua の誤りなし。
- 2026-10-24 08:2x〜08:3x：R-3 の小修正、LIGHT-02（害の大きい誤り）。安全のモジュールのサインの memo（NO SMOKING ON・PASS SIGNS ON・SEATBELTS ON）を、サインの点灯ではなく選択器を手で ON にしたときに出すようにした（FCOM p.502、p.547、ATA33 p.211）。前は AUTO で脚が下りているとき（地上ではほぼ常に）と、3-3 で入れた乗客酸素の作動のときにも PASS SIGNS ON が出ていた。試験：新しい `tests/safety/safety_module_test.lua`（照明・酸素のモジュールと一緒に、10 件）。X-Plane（カスタム acf）：新シナリオ `s21_sign_memos` 19/19。Lua の誤りなし。
- 2026-10-24 08:3x〜09:0x：火災防護（3-4）段 1、エンジンと APU。新しいモデル `B747.35.fire_model.lua` と、火災のモジュール `B747.35.xt.fire.lua` をそのグルーに書き直した：双ループの検知（エンジンは AND と単ループへの組替え、APU は OR、APU battery bus、>DET FIRE/OHT n・>DET FIRE APU、loop の status と FIRE/OVHT SYS）、エンジンの過熱（OVHT ENG n NAC、失敗の dataref）、消火スイッチのロック（火災・CUTOFF・試験・Fire Override のコマンド、main hot battery bus）、翼ごとの共用ボトルと 1 回だけの squib、剤が出ている間だけ X-Plane の消火器、BTL DISCH と >BTL LO L/R ENG A/B、APU の停止（APU のグルーが `fire/apu_shutdown` を読む）と地上の自動放出（10 秒、95 % 未満）、APU の消火スイッチ（コマンド）と APU BTL DISCH・>BOTTLE LOW APU、FIRE/OVHT TEST（TEST IN PROG から 5 秒で PASS/FAIL）。STATUS の配列を 128 に広げた。電源のグルーが消火スイッチを GCR トリップに渡していなかったのを結線し、GCR をラッチ式にした（LH24 p.108）。X-Plane で、`fire_extinguisher_on` が 1 秒以内に火を消し `rel_engfir` も 0 に戻ることと、旧い火災表示灯の dataref は書いても X-Plane が上書きすること（FUEL CONTROL の赤灯は自前の検知に合わせられない）を確かめた。試験：モデル 70 件、モジュール 62 件、電源のモデル・モジュールに GCR の 7 件、APU のモジュールは火災のモジュールも読み込む。X-Plane（カスタム acf）：新シナリオ `s22_fire_engine_apu` 45/45。純正 acf の `s00` 69/69。Lua の誤りなし。P5 の BTL A DISCHARGE・APU BTL DISCHARGE の灯をスクリーンショットで確かめた。
- 2026-10-24 09:0x〜09:2x：火災防護（3-4）段 2。モデルに貨物室の 4 ゾーンとボトル A–D を足した：煙検知（電源投入と手動試験の完了時だけの組替え、venturi の吸引は中央ダクトの圧で推定）、FIRE CARGO FWD・AFT と灯、ARM・DISCH（マニピュレータのスイッチ位置）で A・B 即時、ARM が 1 区画なら C・D を 30 分後・接地・地上は即時（約 2 時間かけて調圧）、DISCH の灯、>CGO BTL DISCH、>CARGO DET AIR、剤で煙の失敗を消す（推定）。車輪格納部の火災（AC bus 2）、BLD DUCT LEAK L/C/R、>SMOKE LAVATORY・SMOKE DR 5 REST、FIRE/OVHT TEST に貨物・車輪格納部・ダクトを含めた、スクイブ試験（TEST 1・2 のコマンド、発火済みは暗い、ARM で貨物 A・B を抑止）。X-Plane に無い原因は新しい失敗の dataref。STATUS 64–80。試験：モデル 122 件、モジュール 87 件。X-Plane（カスタム acf）：新シナリオ `s23_fire_cargo` 27/27（FL350 で貨物の試験の灯と PASS、FIRE CARGO AFT とベル、ARM で pack 3 停止、DISCH で A・B 即時と C は待つ、空中の >CGO BTL DISCH、剤で煙が消える、FIRE WHEEL WELL、BLD DUCT LEAK L、煙）。純正 acf の `s00` 69/69。Lua の誤りなし。これで段階 3（3-1〜3-4）が済んだ。
- 2026-10-24 09:2x〜09:3x：操縦系統（4-1）の小さな修正。ラダートリムが舵面に入っていなかった（X-Plane の `total_heading_ratio` にトリムは入らないことを確かめた）ので、controlObject にトリムの対応（全行程の 80 %、比率変換器を通る：ATA27 p.612–614）をペダルの前に足した（FCTL-04）。フラップの荷重軽減を状態で持つようにした（レバー 30 で 20 に下がったあと 195 kt を待たずに 25 に戻っていた：FCTL-14）。舵面位置のスポイラーをスポイラー 4・12 にした（前は 1–5・8–12 の平均：FCTL-19）。フラップレバーのスナップのタイマーの条件の逆を直した（FCTL-23）。試験：新しい `tests/fltctrls/fltctrls_module_test.lua`（17 件）。X-Plane（カスタム acf）：新シナリオ `s24_fltctrls_fixes` 8/8（トリム最大で上下ラダー 25.6°、スポイラー 4・12 の表示、レバーのスナップ）。Lua の誤りなし。
- 2026-10-24 10:0x〜13:xx：data block（AIR-18）。承認の一覧に無いパネルの 2 件を、利用者の承認（「2件とも入れて」）で入れた。客室高度の赤い数字（10,000 ft 以上）を 5 桁にした（フォント `x####0.red`、`LED_ROWS 5`、1 桁ぶん左の x 1560 で右端は同じ）。赤の 5 桁のフォントは純正に無いので、`docs/overhaul/tools/make_led_fonts.ps1` で純正の 4 桁の赤のフォントから作った（字は純正のまま、行の間に空きを足した）。1 回目は白と琥珀も 5 桁にしたが、白の純正の 5 桁のフォントでは数字の下に次の行の字の上端がにじんだので、4 桁で足りる白と琥珀は元に戻した（承認も「赤い数字」だった）。LDG ALT の数字と負号は、与圧のモデルの新しい出力 `air/press/ldg_alt_shown`（controller があり、両方 MAN でないとき 1：FCOM p.586）が 1 のときだけ出す。パネルの書き換えは `docs/overhaul/tools/panel_data_block.lua`（6 か所）。CPC の故障は X-Plane に無いので `air/fail/cpc[0-1]` を足した。試験：与圧のモデル 109 件・空調のモジュール 83 件、40 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s25_data_block` 30/30（写真で、両方 MAN と両 CPC 故障で LDG ALT の数字だけ消えて AUTO は残る、10,000 ft 超の赤と急減圧の 2 万 ft 台の赤が 5 桁で右端がそろい、にじみの線が無い）。外から見た機体は変わらない。Lua の誤りなし。
- 2026-10-24 13:xx：利用者の依頼で、カスタム acf を `747-400.acf` にした版を、フォークの新しいブランチ `custom` として置くことにした（作業ツリーは overhaul のまま切り替えない）。`docs/overhaul/tools/update_custom_branch.sh` が、作業ツリー・index・HEAD を触らずに、overhaul の木で `747-400.acf` ← `747-400_custom.acf`、`fmod/747-400.snd` ← `fmod/747-400_custom.snd` としたコミットを作る（最初は overhaul を親に、以後は overhaul のマージ）。overhaul を push するたびに実行して `custom` も push する（CLAUDE.md）。カスタム acf が使う 3D ファイルは、フォークには置けない（GitHub ではフォークの LFS は本家の容量を使い、本家のネットワークに LFS が無ければ拒否される。`Cockpit_Main.dds` は 358 MB で LFS でないと 100 MB の上限を超える）ので、利用者が作る非公開リポジトリ `Gakugaku87/747-400-assets` に LFS で置く。手元の 3D 一式（変更 72・新規 195）を本家の 041c9ffa（本家の master は更新なし）と比べるとすべて違い、そのうちカスタム acf が使う 190 ファイル（約 2.06 GB：acf の 68 個のオブジェクト、それらの TEXTURE が指すテクスチャ、`747-400_vrconfig.txt`）だけを入れた。入れなかった 77 ファイル（貨物機の内装 `74F_interior` など）は手元の README に書いた。手元の作業コピーは `D:\747-400-assets`（未追跡だった 3D 一式のバックアップにもなる）。
- 2026-10-24 13:xx〜14:xx：操縦系統（4-1）段 1、フラップの FCU。モデル `plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.fcu_model.lua` とグルー `B747.45.xt.fcu.lua`（fltCtrls のモジュールが読む）を作った（ARCHITECTURE.md §4.15）。後縁と前縁の群ごとの主系統と副系統、保護、代替フラップ、順序、逆推力での group A の格納、荷重軽減（主系統のときだけ）、表示の状態、FLAPS CONTROL・DRIVE・PRIMARY と STATUS。FCU が舵面の角度とスラット比を `laminar/B747/flt_ctrls/fcu/...` に出し、油圧のモジュールはそれを X-Plane の舵面に書くだけにした（controlObject のフラップと表示の 36 行、900 psi の門、前縁の `normal_slats` を外した）。外側フラップの wing 2 の部分も書くようにした（FCTL-26：前は空力上 0°）。フラップ 25 は 22°（前と同じ。3D もこの角度）、主系統の速さは前と同じ 30° を 45 秒。調査は Explore のエージェントに任せた（今のコードの流れ）。試験：新しい `tests/fltctrls/fcu_model_test.lua`（105 件）、モジュールの試験を書き直した（48 件）、41 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s26_flaps` 54/54（1 回目は開始のレバーを 10 と見込んだ確かめが外れ、冒頭でレバーを 10 にして回し直した。写真で通常・拡大・代替の表示と、副系統で遅れる内側の 2 本、wing 2 の外側フラップの 10°）。純正 acf の `s00` 69/69。Lua の誤りなし。
- 2026-10-24 15:xx〜17:xx（途中で PC が止まり、再開した）：操縦系統（4-1）段 2a、SRM のうち外側エルロンのロックアウトとラダー比変換器。モデル `plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.srm_model.lua` とグルー `B747.45.xt.srm.lua`（fltCtrls のモジュールが FCU の次に回す）を作り、油圧のモジュールの直線の式（ロックアウトは 232→238 kt、比は 150→450 kt）を外した。ロックアウトはヒステリシス・Mach・前縁 group A・SRM の引継ぎと監視、ラダー比変換器は上下別々の速度の表・エアデータを失ったときの位置・autoland・故障で止まる・監視。controlObject のラダーの行を、ペダルとトリムの和（油圧のモジュールの `flt_ctrls/rudder_input`）に上下それぞれの比（`rudder_ratio_upr`・`_lwr`）をかける形にした（FCTL-27）。AILERON LOCKOUT、RUD RATIO SNGL・DUAL と STATUS。調査は Explore のエージェントに任せた。X-Plane で確かめたこと：上の「気づいたこと」の 2026-10-24 の項。試験：新しい `tests/fltctrls/srm_model_test.lua`（43 件）、モジュールの試験 60 件、42 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s27_srm` 19/19（266 kt・M .49 でロック、ラダー比 0.437 は表の値、トリムいっぱいで 11.0°、RUD RATIO SNGL と下の 209 kt の位置、90 秒後の AILERON LOCKOUT。空中開始の速度が 0〜255 kt とまちまちで、PC の停止もはさんで何回か回し、A/P と A/T で加速する手順にした）。Lua の誤りなし。
