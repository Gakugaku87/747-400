# 進み具合（PROGRESS）

次のセッションは、ここと [PLAN.md](PLAN.md) を読んでから続きに入る。

最終更新：2026-10-23 夜（EEC 段 2 の終わり：推力の制御とオーバースピード保護）

## いまどこか

- フェーズ0-A：完了。
- フェーズ0-B：完了。資料索引・コード構成・acf の比較・ATA 章ごとの notes（20 本）・GAP_ANALYSIS・PLAN・試験の方針・CLAUDE.md を書いた。
- フェーズ1：利用者の許可（2026-10-23 就寝前、「承認は自動でよい、X-Plane での試験も自由に」）により、PLAN.md を私（Claude）が承認して開始した。
- **段階 T（試験の土台）：完了**（コミット 27e8f854）。純正 acf とカスタム acf の両方で基準シナリオが通った。
- **段階 0**：
  - R-2（新しいコードの書き方）：完了（d8adfdd8、ARCHITECTURE.md §9a）。
  - R-1（AFDS のコードを油圧のファイルから切り出す）：完了（5af549c6）。X-Plane なしで全フレーム同じ出力、X-Plane で Lua の誤りなし。
  - R-3（早く効く小修正）：任意。まだ手を付けていない。
- **段階 1**：
  - 1-1（電源）：モデル（4fb1fa46）と、機体への組み込み（f38d0baf。電源モジュール、P5 の灯、EICAS、表示器と時計の電源）まで。X-Plane でカスタム acf の `s02_elec_panel` 63/63・`s00` 64/64、純正 acf の `s02` 63/63・`s00` 64/64。残りは使う側の乗り換え（下）。
  - 1-2（空地判定、PSEU）：モデル・脚モジュールへの組み込み・公開 dataref まで。乗り換え済みは電源の BCU（air mode など）、脚レバーのロック、逆推力のロックアウト（前脚を含む全輪の接地 → 主脚左右の接地）。X-Plane で地上（`s02`、両 acf）と空中（`s01`、カスタム acf）の判定を確認。残りの系統は各作り直しで。
  - 1-3（警報の枠組み）：モデル（001f345e）と、機体への組み込みまで（警報モジュールの新しいグルー、fltInst02 の CANC/RCL と manipulators の master リセットは押した回数の dataref で渡す、メッセージ表のレベルと文言を FCOM に合わせた）。試験はモデル 94 件・モジュール 41 件、X-Plane の `s03_alerts`。STATUS ページと STATUS cue（WARN-17）も済（油圧・空圧・電源が status メッセージを立てる）。残りは下の「警報（1-3）の GAP の状態」。
  - 1-4（油圧）：モデル（0df481e3）と、機体への組み込みまで（油圧モジュールの圧・synoptic・accumulator 計、P5 の灯、EICAS、X-Plane の油圧に故障を書かない、X-Plane の漏れ故障を作動油量で受ける、舵面の系統の組の誤り HYD-06・07）。試験はモデル 94 件・モジュール 68 件、X-Plane の `s04_hydraulics`。残りは下の「油圧（1-4）の GAP の状態」。
  - 1-5（空圧）：モデルと、空調モジュールへの組み込みまで（エンジン 4 基の HPSOV・PRV・PRSOV・始動弁、3 区画のダクトと ISLN、APU 弁、需要に応じたダクト圧、P5 の SYS FAULT・VALVE 灯、EICAS）。前の抽気のコードは外した。試験はモデル 71 件・モジュール 19 件、X-Plane の `s05_bleed`（カスタム acf）。残りは下の「空圧（1-5）の GAP の状態」。
- **段階 2**：
  - 2-1（APU）：制御を 1 つのモデル（状態機械）にまとめ、電源モジュールの中のグルーで回す（ARCHITECTURE.md §4.6）。FCOM の START→ON で始動、ドア全開で starter、60 秒の無負荷 cooldown、自動停止（火災、主タンク 2 の燃料切れ、始動の失敗）と fault の保持、APU・APU DOOR・APU RUNNING、STATUS の N2・油量。試験はモデル 46 件・モジュール 28 件、X-Plane の `s00`（両 acf 69/69）。残りは下の「APU（2-1）の GAP の状態」。
  - 2-3（エンジン）：段 1（始動・点火・燃料弁）を、エンジンごとの状態機械のモデル（`plugins/xtlua/scripts/B747.40.xt.engines/B747.40.engine_start_model.lua`）とグルー `B747.40.xt.engine_start.lua` で作り直した（ARCHITECTURE.md §4.8）：手動始動と autostart（燃料投入、light-off・hot・hung の検出、地上の再試行と中止、空中は中止せず）、50 % N2 の cutout、点火の条件（START、CON、フラップ、NAI、flameout）と AUTO・STBY IGNITION・電源、エンジン燃料弁（RUN と火災スイッチ、main battery bus）、START VLV・STARTER CUTOUT・FUEL VLV・ENG AUTOSTART・>AUTOSTART OFF・ENG IGNITION・ENG FAIL・>ENG SHUTDOWN。start valve の指令は抽気のグルーが `engines/start_valve_cmd` から読む。試験はモデル 77 件・モジュール 18 件、X-Plane の `s08_autostart`（カスタム acf 38/38。igniter の故障で 2 回目に中止）、`s00`（両 acf 69/69、手動始動）。段 2（EEC）は済（`plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua` とグルー `B747.42.xt.eec_thrust.lua`、ARCHITECTURE.md §4.9）：定格・レバーの指令・max N1/EPR の線、アイドルの選択、ALTN と A/T、推力の制御（実際の N1・EPR を指令に合わせる。前の PID を GE・P&W で置き換えた）、オーバースピード保護と >ENG RPM LIM、ENG-19。試験はモデル 122 件・モジュール 59 件、X-Plane の `s09_eec`・`s10_overspeed`・`s11_takeoff_thrust`（新設）と `s07_cruise_ff`、GE のリバリー（Saudia）でのレバーの段の応答。段 3（表示・逆推力）は EGT の色・抑止・始動限界の線、逆推力の電源・地上・ENG REVERSER、オイルと振動の値・赤・メッセージまで（`B747.40.engine_display_model.lua`・`B747.40.reverser_model.lua` とそのグルー、ARCHITECTURE.md §4.10。試験は表示のモデル 66 件・モジュール 24 件、逆推力のモデル 22 件・モジュール 21 件、X-Plane の `s08_autostart`・`s11_takeoff_thrust`・`s12_reverser`・`s13_oil`・`s13_oil_ge`）。
  - 2-2（燃料）：モデルまで（`plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_model.lua`。タンク・ポンプ・弁の表、FSMC（クロスフィード 2・3、O/J 2・3、予備・スカベンジ・水平安定板タンクの移送）、FJCC（ジェティソン）、マニフォールド（圧力の順位、クロスフィード、吸引供給、shared flow）、量、EICAS、頭上灯）。試験 117 件。燃料モジュールへの組み込みも済（`B747_fuel_system()`。ARCHITECTURE.md §4.7）：前のポンプ・弁・供給源・タンク量・EICAS の処理を外し、頭上の灯は照明モジュールがモデルの出力を読む。APU の DC 燃料ポンプと APU FUEL（APU-11）も。試験はモデル 124 件・モジュール 62 件・照明 37 件、X-Plane の `s06_fuel`（カスタム acf 42/42）、空中の予備・安定板タンクの移送とジェティソン、`s00`（両 acf 69/69）。カスタム acf の燃費（SFC）は、巡航の燃料流量を測って（`s07_cruise_ff`）純正と同じ値にした（前の値では約 25 % 少なかった。ACF_DIFF.md §5）。残りは下の「燃料（2-2）の GAP の状態」。

## 次にやること

項目を終えるたびに、[DIFFERENCES.md](DIFFERENCES.md)（実機との違い、全分野。2026-10-23 に利用者の依頼で作った）の該当分野も直す。

1. 承認済みのパネル（カスタム acf）の変更の残り：1-5 のダクト圧の表示条件（PNEU-09。空調 3-1 と一緒に）。済：`.snd` の警報音、1-3 の PG と 3〜10 ページ、1-3 の STATUS ページと cue、1-4 の HYD synoptic（HYD-19。記号の色と不作動項目の絵は 2026-10-23 夕方に新しい画像で）と RSVR PRESS（HYD-18）、1-1 の synoptic の ISLN・DRIVE の枠・UTILITY と GALLEY の色、STAT のバッテリーの値と CHG/DIS、1-5 のダクト圧の色（PNEU-10）。変更の一覧は ACF_DIFF.md §5、画像は `docs/overhaul/tools/make_synoptic_images.ps1` で作る。
2. 2-3（エンジン）の残り：段 3。EGT の色・抑止・始動限界の線（ENG-20）と逆推力の電源・地上・ENG REVERSER（ENG-31 の一部・32）、オイルと振動の値・赤・メッセージ（ENG-25〜27・29 の Lua の部分）は済。残りは次の順で：小さな誤り（ENG-23・30・35・37。fuel-on の印）、超過の赤い枠と表示形式とオイル・振動のパネル（ENG-21・22・24、ENG-25〜27・29 の残り：GE の油圧の目盛りと琥珀の帯、油圧・油温の数字の色、油量のマゼンタ、振動の音源と high band。パネルの作業が主）、表示値の作り方（ENG-33。EGT が低い、N1・EPR・N2 の式の癖：下の「気づいたこと」）。燃費の離陸・上昇の値（純正と同じにした SFC）を PI.11 の上昇の燃料の表と比べる。空中開始の試験は AFDS の動き（「気づいたこと」）に気をつける。段 1（始動・点火・燃料弁）と段 2（EEC）は済（下の「エンジン（2-3）の GAP の状態」）。A/T（6-4）との境界は、EEC がレバー → 指令・最大定格・推力の制御まで、FMC の推力基準と A/T のサーボ（レバーを動かす）は 6-4。
3. 1-5（空圧）の残り：故障の入れ方（過熱、過圧、HPSOV・PRV の固着、ダクトリーク）、地上空気の操作、スターターがダクト圧で回ること（エンジン 2-3）。
4. 1-4（油圧）の残り：脚・ブレーキ・ステアリング・逆推力・stab trim・ヨーダンパーの「油圧で動くか」（HYD-09・11・12）は、それぞれの作り直しで、モデルの負荷の表（`B747_hyd_model.LOADS`）を使って入れる。リザーバ与圧の表示（HYD-18）と STATUS のメッセージ（HYD-20）は済。
5. 1-1（電源）の残り：電源の有無を `bus_volts` で見ている系統を、バスごとの dataref（ARCHITECTURE.md §4.1）に乗り換える。どれも後の作り直し（空圧 1-5、空調 3-1、燃料 2-2、IRS と無線、照明、操縦系統 4-1）と絡むので、1-2 と同じく各系統の作り直しのときに行う（2026-10-23 に決めた。利用者の確認待ち）。
   - 済：表示器（fltInst02。機長 PFD・ND は APU standby、upper EICAS は main standby、ほかは F/O transfer）、EICAS の計算（warning。EIU のどれかに電源）、時計の計時（fltInst03・04。main hot battery bus）、ELEC パネルの灯（lighting）。
   - 燃料のポンプと弁も 2-2 で乗り換えた（AC・utility・main battery・hot battery・DC・APU battery・ground service bus）。
   - 残り：装備冷却（air：DC bus。抽気弁は 1-5 で乗り換えた）、IRS と NAV RAD（fms）、表示灯の輝度（lighting：`bus_volts[0]`・`[2]`）、客室灯（lighting）、ヨーダンパー（fltCtrls：`battery_array_on`）。STAT ページのバッテリーはカスタム acf だけ済（純正 acf は X-Plane の値のまま）。
6. 1-2（空地判定）の残り：`onground_any` を読んでいる 16 モジュール（autopilot、fms、fltInst02、antiice、fltCtrls、EEC、engines、fuel、hydraulicsmodel、gear の autobrake、manipulators、fdr、lighting など）を、PSEU の dataref（ARCHITECTURE.md §4.2）に乗り換える。どの信号（pri/alt の AIR・GND、前脚圧縮）を使うかは notes/ATA-32.md §4.1 の表。各系統の作り直しのときに行う。
7. 1-3 の残り：他のメッセージによる抑止（notes/ATA-31-warning.md §4.4.1）と時間遅れは、各系統の作り直しで表に足す。音（`.snd`）とパネル（PG・3 ページ目以降・STATUS）は済。
8. R-3 は、作り直しが先になる系統の害の大きい誤りだけ、合間に入れる。

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
  - トラックの「傾き」：X-Plane の `eagle_claw_angle_deg` が 1° を超えたら傾き（X-Plane には傾きセンサーが無い）。
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
  - 推力の制御：X-Plane のスロットルを燃料の計量とみなした作り。ゲイン（積分 2/秒、誤差の変化 3）、追う値の時定数 1.5 秒と速さの上限（P&W 0.15 EPR/秒、GE は上げ 15・下げ 5 %N1/秒。GE の下げを遅くしたのは X-Plane のエンジンが絞り切ったあと上げに転じるのに 3 秒ほどかかり、目標を 10 % 下回ったため）、表示値のスロットルに対する傾きの表（X-Plane で 8,000〜13,500 ft・M.42〜.49 で測った）。X-Plane のスプール時間は、エンジンのモジュールが 4 基運転中に 5 秒へ書き換えていて（ENG-35）、この値のもとで合わせた。ENG-35 を直すときは段の応答を測り直す。指令に届かないときに X-Plane の最大推力を足す仕組み（前のコード）は残し、条件を「スロットル 1 で目標より P&W 0.005・GE 0.2 % 低い」にした。


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
| PNEU-08 始動の空気 | 一部。空気の側は済（APU で 3 パックのままでは始動できない、クロスブリードは供給側 70 % N2）。スターターの回り方がダクト圧に依らないのはエンジン（2-3、ENG-38）で |
| PNEU-09〜11 表示 | 一部。PNEU-10（ダクト圧の色の境と右の数字）はカスタム acf で済（ACF_DIFF.md §5）。PNEU-09（表示条件。空調 3-1 と一緒に）と PNEU-11（ECS synoptic の流れ）は未 |
| PNEU-12 GE の逆推力の抽気 | 一部（逆推力の側は 2-3 段 3 で、そのエンジンが運転中なら動く。逆推力のとき HPSOV・PRV がスイッチ OFF でも開く空圧の動きと、PRV が閉じたら逆推力が動かないことは未） |
| PNEU-13 EEC の抽気補正 | 一部（2-3 段 2：パックの数は選択器が OFF でない台数で数え、パック OFF は着陸復行の表、防氷は上昇の表を使う。実際の抽気源（APU からパックへ、エンジン抽気 OFF）は見ない） |
| PNEU-14 X-Plane の抽気 | 一部（X-Plane には `bleed_air_mode` だけを書く：ダクトに空気があれば 5、無ければ 0。X-Plane の isolation valve は mode に連動するので書かない。抽気による推力の損失は X-Plane の計算のまま） |

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
| ENG-38 始動の空気 | 一部（start valve は抽気のモデルがダクト圧で開ける。スターターの回り方がダクト圧に依らないのは残り） |
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
| ENG-25 油圧 | 一部（表示のモデルで、赤は赤線の下で CUTOFF と始動中は白（FCOM p.846）、GE の赤線は N2 で 10〜35 psi（ATA70_80 p.395）、ENG n OIL PRESS（advisory 317〜320 を足した。GE は低圧スイッチ 10/15 psid、ATA70_80 p.522）。残り：GE の値と目盛り（X-Plane の油圧は P&W 向けの 150 psi 前後、パネルの針は 70〜300 psi）、GE の琥珀の帯、数字の色（パネルは赤い数字を 10 psi 未満でしか出さない）はパネルの項目で） |
| ENG-26 油温 | 一部（ENG n OIL TEMP をモデルに移した（160 ℃ 超。P&W・RR は資料なし）。パネルの数字の琥珀が 150 ℃ からで白と重なる、型式に依らない閾値はパネルの項目で） |
| ENG-27 油量 | 一部（エンジンごとの X-Plane の比を使う（前は全エンジンが 1 番の比）、GE は US quart（FCOM p.848）。量の作り方は前と同じ推定。マゼンタ（GE の low 4 qt と巡航中の差 6 qt）はモデルで出すが、パネルの項目で表示） |
| ENG-28 ENG OIL FILT | 未（X-Plane に相当する故障が無い） |
| ENG-29 振動 | 一部（音源ごとの値（推定）と一番大きい音源をモデルで出す。火災で振動を上げる前の処理（資料なし）は外した。音源の表示（今は BB の絵）、high band、自動表示はパネルの項目で） |
| ENG-21〜24、30、33〜36 | 未（段 3） |

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
- **ピトー加熱がエンジンの抽気圧を見ている**：防氷モジュールは、どれかのエンジンの `bleed_air_psi` が 12 psi を超えることを「エンジン運転中」の代わりに使っている。新しい空圧では PRV が閉じると 0 になるので、4 基とも ENGINE BLEED が OFF（NAI も OFF）だとピトー加熱が切れる。始動のときも、始動弁が閉じてから PRV が開くまでの 15 秒だけ遅れる。防氷（3-2）で「エンジン運転中」に直す。
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
- 静的検査で見つかった既存の不具合：
  - `fltInst02` が、init スクリプトで作られていない時計の dataref 40 個と `electrical/oil` を使っている。
  - 3D の CHRONO スイッチが使う `glareshiled/*/chrono_switch_pos` は、xt スクリプトでしか宣言されていない。存在しない可能性がある。
  - いずれも `tests/static/` の既知の一覧に入れた。

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
