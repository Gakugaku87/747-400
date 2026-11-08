# ATA 34-61 FMC（航法・性能・誘導）調査メモ

2026-10-23 調査。対象コードは `overhaul`（041c9ffa）。出典の書き方は REFERENCE_INDEX.md に従う。

## 1. 概要

- 対象：FMC の航法（FMC 位置、IRS/GPS/無線の混合、ANP/RNP、無線の自動同調、航法 DB）、経路（RTE 1/2、ACT/MOD と EXEC、discontinuity、オフセット、direct-to・intercept、ホールド、手続きのレグ）、LNAV（経路の組立て、旋回、シーケンス、捕捉）、VNAV（上昇・巡航・降下、速度・高度制限、T/C・T/D・E/D、パス降下と速度降下、早期降下、ステップ、進入パス、ミスト進入）、性能（CI と ECON、予測、OPT/MAX、燃料監視、風）、それらの FMC メッセージ、FMC 二重系と CDU の代替航法。
- 対象外：CDU ページの体裁・入力書式（別担当）、A/T・推力制限・エンジントリム（別担当）、離陸速度・VREF・トリムの表、IRS 本体（アライン・IRU 故障）、ATC/AOC データリンク。取り合いは §5。
- 資料
  - FCOM 11.30–11.32 p.1233–1275、11.40–11.43 の機能部分 p.1277–1419、11.50 p.1421–1428、11.60 p.1429–1436。補助：4.10 p.643–649・4.20 p.663–667（MCP と LNAV/VNAV の作動）、10.40 p.1149（ND の VNAV パス）、PI.18 p.316–318・p.323（FMC と同じ前提の性能表の説明）。
  - ATA34_2 p.427–707（E&M 34-61）。図は p.603、p.607、p.617、p.619、p.621 を描画して見た。
  - LH3460 p.3–116。大半は ATA34_2 と同文。時刻源、UNABLE RNP の段階、FMC の割り当て（p.90–93）だけ追加で使った。
  - FMSPG 2 章 p.15–55、4 章 p.212–237、7.1 p.261–262、補助に p.164・p.266。FMSPG は 1996 年版で、FCOM（2009 年改訂）と値が違う箇所は FCOM を採った（§9）。
- effectivity：FCOM の 109＝PW 旅客機、405＝PW 改造貨物機、570＝GE 貨物機（FCOM p.5 (0.1.1)）。シムは旅客機なので 109 を採る（推定。ATA-36.md と同じ扱い）。RR の性能資料は無い。
- コードの略号（以下 `略号:行`）
  - FMS＝`plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua`、CRE・PG・NOTI＝同フォルダの `B744.createfms.lua`・`B744.fms.pages.lua`・`B744.notifications.lua`
  - VPG・PRG・PINIT・LEGS＝同 `activepages/B744.fms.pages.{vnav,progress,perfinit,legs}.lua`、IRS・RNAV＝同 `irs/{irs_system,rnav_system}.lua`
  - AP＝`plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua`、MON・VN・VS＝同 `B747.70.xt.autopilot.{monitor,vnav,vnavspd}.lua`
- OLD_FORK_NOTES.md §4–6・§8 は参照だけ（移植しない）。

## 2. 構成

### 2.1 機器・電源・データベース

| 項目 | 内容 | 根拠 |
|---|---|---|
| FMC ×2 | SDP-185×2、不揮発メモリ（OP program、nav DB、perf DB、APF）、A/T サーボカード。左右とも全計算を行い intersystem bus で突き合わせる | ATA34_2 p.434, p.456, p.484; LH3460 p.8 |
| CDU ×3 | L・C は通常 L FMC、R は R FMC につながる。C は FMC へ入力できない。FMC 両系故障で代替航法・代替同調 | ATA34_2 p.433, p.456 |
| button push master | 通常 L FMC。両 CDU のキーを L FMC が順番づけて R へ渡す。経路変更は同時に 1 件 | FCOM p.1233; FMSPG p.24, p.49 |
| FMC master switch（P2）・master relay ×3 | L で消磁＝L FMC が FCC 誘導、航法無線同調、EEC トリム、MCP、A/T を受け持つ。switch と relay が不一致なら A/T を ARM できない | ATA34_2 p.452, p.496 |
| 電源 | L FMC：APU standby bus（115V AC）、R FMC：F/O transfer bus、警報回路：battery bus、master relay：28V DC bus 1、CDU：standby・captain transfer・F/O transfer bus（どの CDU がどれかは資料に記載なし） | ATA34_2 p.450, p.452, p.454 |
| nav DB | 2 組（各 28 日）。地上でのみ切替、切替で経路データを消す。飛行中に失効しても着陸まで使う。未有効側は該当日 0901Z から有効 | FCOM p.1271, p.1284 |
| perf DB・係数 | 抗力・エンジン模型、最大・最適高度、最大・最小速度。保守ページで drag/FF 係数、MNVR MARGIN 1.20–1.30（包囲線とバンク限界）、MIN CRZ TIME（OPT 計算）、最大高度の残余上昇率（CLB/CRZ 推力、0–500 fpm、既定 100） | FCOM p.1271; ATA34_2 p.678–679; FMSPG p.266 |
| 機能ブロック | FMC：入出力、航法と同調、性能、誘導、推力管理、EFIS、DB、BITE。CDU：EFIS 地図、代替航法、代替同調、ARINC 739 | ATA34_2 p.596–598 |

### 2.2 入力と源の選び方

| 入力 | 使い方・選び方 | 根拠 |
|---|---|---|
| IRU ×3 | 位置・速度は 3 台を混合（§4.2）。姿勢・方位・トラックは作動中の AP/FD チャンネルで L・C・R を選ぶ | ATA34_2 p.459 |
| ADC | 作動中の AP チャンネル（無ければ L ADC 選択信号）で選ぶ | ATA34_2 p.459 |
| GPS L/R | 位置、HFOM・HIL・SAT FAIL（ANP と RNP の比較に使う）、時刻 | LH3460 p.32 |
| 航法無線 | L FMC：L・R VOR、L DME、L ILS。R FMC：R・L VOR、R DME、R ILS。DME は自側無効なら他側 | ATA34_2 p.458 |
| 時計 | GPS L → GPS R → 機長時計 → F/O 時計（ATA34_2 p.458 は機長 → F/O の旧仕様） | LH3460 p.30 |
| FQIS・EIU | 総燃料（L FMC は出力 A、R は B）、FF、ジェティソン、Vmin/Vmax、フラップ・脚位置、エンジンデータ、電波高度。低速データは L → C → R | ATA34_2 p.458, p.462 |
| MCP・FCC | 選択高度・方位・速度、ボタン、介入、TO/GA、A/T ARM。FCC からの ILS 同調禁止 | ATA34_2 p.470 |
| その他 | EFIS CP（CDU 経由）、HDG REF、air/ground（DB 書込み許可と飛行段階）、WBS（405 のみ） | ATA34_2 p.462, p.477–478 |

## 3. 操作と表示

### 3.1 操作（FMC に関わる部分）

| 操作 | 働き | 根拠 |
|---|---|---|
| LNAV スイッチ | arm/選択/解除。滑走路標高 +50 ft 以上で、アクティブレグから 2.5 NM 以内、またはそれ以遠でも切込みヘディングならレグ接近で作動。切込まないなら NOT ON INTERCEPT HEADING。HDG HOLD・HDG SEL・LOC 捕捉・FMC 両系故障で解除 | FCOM p.644–645, p.663 |
| VNAV スイッチ | arm/選択/解除。滑走路標高 +400 ft で作動。データ不足（GW 無効、降下で E/D 無し等）なら PERF/VNAV UNAVAILABLE。TO/GA・FLCH・V/S・ALT・G/S・FMC 両系故障で解除 | FCOM p.645, p.664–665 |
| IAS/MACH セレクター押し | VNAV 中に窓を開閉。開＝速度介入。VNAV PTH 降下中に開くと VNAV SPD（制限高度に掛かると VNAV PTH）。on approach 中は VNAV PTH のまま A/T が速度 | FCOM p.643; ATA34_2 p.623 |
| 高度セレクター押し | ①上昇・降下中、機体と MCP 高度の間の次の高度制限を 1 個削除 ②上昇中で制限が無く MCP > CRZ ALT なら CRZ ALT＝MCP ③巡航中は CRZ ALT＝MCP、VNAV PTH/ALT なら上昇・降下開始 ④T/D 50 NM 以内で MCP < CRZ ALT なら減率降下 | FCOM p.649; ATA34_2 p.623–624 |
| BANK LIMIT | HDG SEL のときだけ（AUTO は TAS・フラップ・V2 で 15–25°）。LNAV には効かない | FCOM p.647 |
| TO/GA | 地上：takeoff 段階開始。GPS 更新が無いとき FMC 位置を滑走路端（POS SHIFT 入力時はその点）へ。空中：ミスト進入 | FCOM p.1240, p.1262, p.1321, p.1325 |
| FMC master selector（P2） | master FMC を選ぶ（§2.1） | ATA34_2 p.496 |
| NAV source selector | FMC L / FMC R / CDU L(R) / CDU C。ND・PFD の源と CDU の接続先。CDU は ND の地図だけ | ATA34_2 p.456, p.496; LH3460 p.90 |
| HDG REF（NORM/TRUE） | 地図と誘導の基準方位。高緯度では自動で真方位 | FCOM p.1242; ATA34_2 p.477 |
| EXEC キー | ACTIVATE や MOD（経路・性能モードの変更）で点灯、押すと有効化 | FCOM p.1238; FMSPG p.42 |

### 3.2 表示（FMC が出すもの）

| 表示 | 内容 | 根拠 |
|---|---|---|
| PFD 速度テープ | 最小機動速度（amber、FMC が制御に使う下限）、高速バフェット（amber、上限）、V1・VR・VREF・フラップ機動速度、VNAV 中の目標速度（magenta、離陸時は V2）。A/T FMA は master FMC、ドリフト角は選択 FMC、着陸高度は master FMC（無効なら CPCS） | ATA34_2 p.501–502 |
| ND 経路 | active：マゼンタ実線、非 active：シアン破線、activate 済み未 EXEC：シアン/白の交互破線、変更：白破線、変更点：白、実行済みオフセット：マゼンタ破線 | FCOM p.1251 |
| ND 点と数値 | アクティブ点（マゼンタ、通過で白）、ETA・距離、T/C・T/D・S/C・E/D（緑の円）、高度到達弧、トレンドベクター（30/60/90 s）、風（TAS > 100 kt かつ風 > 5 kt）、更新モード（LOC GPS、LOC DD、LOC VD、LOC、GPS、DD、VD、IRS(3/L/C/R)。IRS(3) との切替で 10 s 緑枠） | ATA34_2 p.504–506; LH3460 p.72 |
| ND VNAV パス | 降下中だけ。目盛 ±400 ft、超えると数値（ATA34_2 は ±420 ft・50 ft 刻み・最大 9,999 ft。FCOM を採る） | FCOM p.1149; ATA34_2 p.505 |
| ND ホールド | 小記号（レンジ > 80 NM か保持点が TO 点でない）、大記号（保持点が TO 点かつ ≤ 80 NM。風・速度で大きさが変わる） | FMSPG p.223 |
| CDU 灯 | MSG、DSPY（表示ページがアクティブなレグ/モードでない）、FAIL（空中で master FMC 故障か NAV 選択の FMC 故障）、OFST（オフセット中）。CDU は GS > 100 kt か GS 無効で空中とみなす | LH3460 p.56; FMSPG p.40–41 |

### 3.3 EICAS メッセージ

| メッセージ | レベル | 条件 | 根拠 | 現状 |
|---|---|---|---|---|
| FMC LEFT, RIGHT | advisory | その FMC の故障（内部故障、センサー無効、ARINC バス）。30 s 後 | FCOM p.1429; LH3460 p.116; ATA34_2 p.702 | adv[144]/[146] は定義だけ |
| >FMC MESSAGE | advisory | CDU に FMC の alert メッセージがある（alert だけ） | FCOM p.1430; ATA34_2 p.635 | adv[145]。どのメッセージでも点く（FMS:1110-1136） |
| UNABLE RNP | advisory（beeper） | approach 以外で ANP > RNP。極域で抑止 | FCOM p.1430; LH3460 p.116 | adv[295] 未使用 |
| UNABLE RNP | caution（beeper） | approach 段階で ANP > RNP。極域で抑止 | FCOM p.1430; LH3460 p.116 | caution[66] を XTK から出す（AP:2220-2232） |
| FMC LEFT/RIGHT（status） | status | FMC 故障 60 s でラッチ | ATA34_2 p.702 | 無し |
| >PILOT RESPONSE | advisory | 乗員操作が一定時間無い（巡航 FL200 超 54 分、降下 5 分。APF の設定） | ATA34_2 p.480; LH3460 p.116 | 表に定義だけ |

GPS・IRS の EICAS は各担当（FCOM p.1429–1430）。

### 3.4 FMC メッセージ（航法・誘導・性能。データリンク系は除く）

△＝一部・不正確、×＝無し（仕様どおりに実装されたものは無い）。

| メッセージ | 種別 | 条件 | 根拠 | 現状 |
|---|---|---|---|---|
| CHECK ALT TGT | alert | VNAV が MCP 高度と FMC 目標高度の間で作動、水平を保つ | FCOM p.1431 | × |
| DESCENT PATH DELETED | alert | VNAV 中に降下パスを決める高度制限が全部消えた | FCOM p.1431 | × |
| DISCONTINUITY | alert | LNAV 中に discontinuity に入った。AFDS は最後のヘディング | FCOM p.1431 | × |
| DRAG REQUIRED | alert | VNAV 中に抵抗が必要、または A/T OFF で推力減が必要 | FCOM p.1431 | △ AP:3400-3413 |
| END OF OFFSET / END OF ROUTE | alert | オフセット終点の 5 NM 手前 / 経路終点を通過（最後のヘディング保持） | FCOM p.1431 | × |
| ENTER IRS POSITION | alert | 入力位置が IRS 比較に不合格、または NAV 移行可能なのに位置未入力 | FCOM p.1431 | △ IRS:102-126 |
| FUEL DISAGREE - PROG 2 | alert | TOTALIZER と CALCULATED の差 4,080 kg 以上（570 は 9,000 lb） | FCOM p.1432 | × |
| ILS TUNE INHIBITED - MCP | alert | FCC の同調禁止中に手動同調か新しい ILS 進入を activate | FCOM p.1432 | × |
| INSUFFICIENT FUEL | alert | 目的地予測燃料 < RESERVES | FCOM p.1432 | × |
| IRS POS/ORIGIN DISAGREE | alert | IRS 位置が出発空港と違う | FCOM p.1433 | × |
| LIMIT ALT FLXXX | alert | VNAV 中で CRZ ALT が VNAV 制限高度より上 | FCOM p.1433 | × |
| NAV DATA OUT OF DATE | alert | 日付が active DB の有効期間外 | FCOM p.1433 | × ネイティブのものを自動で消す（CRE:520） |
| NAV INVALID-TUNE AAA | alert | 進入に必要な局の信号が無い | FCOM p.1433 | × |
| NO ACTIVE ROUTE | alert | active 経路が無いのに LNAV 選択 | FCOM p.1433 | × |
| PERF/VNAV UNAVAILABLE | alert | GW・CI・CRZ ALT 未入力で VNAV 選択 | FCOM p.1433 | △ CRZ ALT だけ（AP:1025-1028） |
| PURGE UPDATES - POS 2 | alert | FMC 位置の誤りで無線データが DME 妥当性検査で棄却 | FCOM p.1433 | × |
| RESET MCP ALT | alert | VNAV 中、T/D の 2 分前に MCP が巡航高度のまま | FCOM p.665, p.1433 | △ 約 1 分前（MON:451-467） |
| RESYNCING OTHER FMC / RESYNC FAIL / SINGLE FMC OPERATION | alert | §4.12 | FCOM p.1433–1434 | × |
| RTA FIX DELETED / UNABLE RTA / UNABLE FLXXX AT RTA FIX | alert | RTA 点の削除、到着時刻・高度が達成不能 | FCOM p.1434 | × |
| RW/ILS FREQ ERROR / RW/ILS CRS ERROR | alert | 選択 ILS の周波数・コースが目的地滑走路と不一致 | FCOM p.1434 | CRS だけ誤用（AP:2397-2402） |
| SET CLOCK TO UTC TIME | alert | GPS の UTC と機長時計の差 > 12 s | FCOM p.1434 | × |
| SPLIT IRS OPERATION | alert | 極域か IRU 間の大差で単一 IRU 更新 | FCOM p.1434 | × |
| THRUST REQUIRED | alert | VNAV 中、A/T 切断で推力が必要 | FCOM p.1434 | × |
| UNABLE NEXT ALT | alert | VNAV の上昇が次の高度制限に間に合わない | FCOM p.1434 | × |
| VERIFY POSITION | alert | 更新センサーと FMC 位置、または左右 FMC の位置が違う | FCOM p.1435 | × |
| VERIFY RNP - POS REF 2 | alert | 既定 RNP が段階で変わり手入力 RNP が新既定を超える（APF） | FCOM p.1435 | × |
| ARR N/A FOR RUNWAY / RUNWAY N/A FOR SID | advisory | 滑走路と手続きが合わない | FCOM p.1435 | ネイティブ次第 |
| CRS REVERSAL AT FA FIX | advisory | procedure turn 無しで FA 点に course reversal | FCOM p.1435 | × |
| MAX ALT FLNNN / UNABLE CRZ ALT | advisory | CRZ ALT > 最大高度 / 上昇が降下パスと交差か巡航時間が最小未満 | FCOM p.1435–1436 | × |
| NOT ON INTERCEPT HEADING | advisory | LNAV 選択時に捕捉条件外で切込まない | FCOM p.1435 | × |
| ROUTE FULL | advisory | 変更で 120 点を超える | FCOM p.1435 | × |
| VERIFY RNP ENTRY | advisory | 手入力 RNP が既定を超えるか ANP 未満 | FCOM p.1436 | × |

## 4. 内部ロジック

### 4.1 飛行段階

| 段階 | 始まり → 終わり | 根拠 |
|---|---|---|
| preflight | 電源投入 → TO/GA | FCOM p.1235 |
| takeoff | TO/GA → 上昇推力への減推力 | FCOM p.1236, p.1325 |
| climb | 減推力 → T/C（PERF INIT の CRZ ALT 到達） | FCOM p.1236 |
| cruise | T/C → T/D（ステップ上昇・途中降下を含む） | FCOM p.1236 |
| descent | T/D、または VNAV DES ページが active（早期降下） → approach | FCOM p.1236, p.1389 |
| approach | 手続きの最初の点を通過、または滑走路がアクティブ点で残り 25 NM 未満 → 着陸。ゴーアラウンドで climb | FCOM p.1236, p.1389 |
| flight complete | エンジン停止 30 s 後。active 経路と搭載データを消し、一部を既定値へ | FCOM p.1236 |

- 段階は VNAV の推力基準、VNAV キーで出るページ、RNP 既定値、到着ページ、CPCS への値に使われる（FCOM p.1272, p.1400; ATA34_2 p.517, p.552）。
- 電源断から復帰すると FMC は再起動し、PERF INIT は再入力、経路が残っていれば activate が要る。LNAV の前に direct-to か intercept が要る（FCOM p.1274–1275。FMSPG p.23 は「完全に復帰」と書くが FCOM を採る）。

### 4.2 位置の計算

- 源の優先：LOC+GPS > LOC+DME-DME > LOC+VOR/DME > IRS+LOC > IRS+GPS > IRS+DME-DME > IRS+VOR/DME > IRS。POS REF の表題/ND 表示：LOC-GPS/LOC GPS、LOC-RADIO/LOC DD、LOC-RADIO/LOC VD、LOC/LOC、GPS L・GPS R/GPS、RADIO/DD、RADIO/VD、INERTIAL/IRS(X)（FCOM p.1241）。FMC は IRS の位置を必ず要し、他の源は IRS 位置と照合する。地上は IRS と GPS（FCOM p.1240）。FMC は IRS を更新しない（FMSPG p.28）。
- LOC 更新の条件：目的地滑走路の LOC、LOC 局の標高 +6,000 ft 未満、局から 20 NM 未満（back course 12 NM）、入航コースの 25° 扇内、トラックとコースの差 < 45°（FCOM p.1241）。LOC は横方向、縦方向は GPS か DME/VOR で補う（FMSPG p.26）。
- GPS：完全性監視で有効ならそのまま位置に使い、完全性を失っても他センサーと整合すれば使い続ける（FMSPG p.25）。GPS の ACTUAL が RNP の 2 倍以上で GPS 更新をやめる（FCOM p.1368）。GPS NAV INHIBIT/ENABLE は電源断でも保持、flight complete で既定（使用）に戻る（FCOM p.1369）。POS INIT の GPS POS は HIL ≤ 0.5 NM の側（L 優先）（LH3460 p.81）。
- 無線：DME の斜距離を水平距離にし、2 円の交点のうち IRS に近い方（ATA34_2 p.601）。VOR/DME は方位と距離。誤差見積り ET（1–30 NM）の内側の無線位置だけ使う（ATA34_2 p.606）。NAVAID INHIBIT（VOR/DME/VORTAC/DME を 2 局）、VOR ONLY INHIBIT（2 局）、VOR/DME NAV INHIBIT（全 VOR/DME、DME-DME は残る）。flight complete で消える（FCOM p.1356–1357; ATA34_2 p.548）。
- IRS の混合：3 台有効なら重み付き平均。1 台が平均から 30 NM 超が 5 s 続くとその飛行中は使わない。速度は 3 台の N/E 成分の平均、1 台が 20 kt 超ずれて 5 s で除外。DME-DME で速度も補正。2 台なら各 FMC が 1 台（L FMC は L か C、R FMC は C か R）、2 台の差が閾値を超えると VERIFY POSITION。1 台なら両 FMC がそれを使う（ATA34_2 p.601–602; FMSPG p.28）。高度は慣性と ADC の合成（ATA34_2 p.602）。
- ANP/RNP：ANP は 95% の円。RNP 既定は段階別：離陸 1.0、洋上 12.0、国内 2.0、ターミナル 1.0、進入 0.5 NM。手入力 0.01–99.9（ATA34_2 p.517; FCOM p.1368）。ANP > RNP で UNABLE RNP（FCOM p.1430）。
- PURGE：FMC 位置を混合 IRS 位置に置き換え、局があれば無線更新を再開（FCOM p.1368）。TO/GA で滑走路端（＋POS SHIFT）へ更新（GPS 更新が無いとき。FCOM p.1240, p.1321）。
- 極域：FMC 位置が 84° を超えると split IRS（各 FMC が 1 台、L FMC は L→C→R、R FMC は R→C→L。互いに最も近い 2 台を選ぶ）、SPLIT IRS OPERATION、無線補正は消え、IRU 位置へ徐々に移す。GPS 更新は 88.5° まで続き、88.0° 未満で再開。両 FMC が 83.5° 未満で 3 台混合へ戻る。UNABLE RNP は抑止。89° 超で IRS 故障なら即 IRU 位置（FCOM p.1241–1242; FMSPG p.219–220）。
- 真方位：82°N（80°W–130°W は 70°N）以北、82°S（120°E–160°E は 60°S）以南で FMC と IRU は真方位（FCOM p.1242）。

### 4.3 無線の自動同調

- VOR の状態：P（出発・到着手続きの局）、R（経路上の直前の VOR か、前方 250 NM 以内の VOR）、A（位置計算に最良の局）、M（手動）。手動は自動より優先、削除で自動へ。VOR を手動にすると VOR の自動同調は止まるが DME-DME の同調は続く（FCOM p.1240, p.1303–1304; ATA34_2 p.605）。
- DME：走査型。master FMC が 5 チャンネルを指定：1–2＝幾何が最良の組、3–4＝次の組か P/M/R 局、5＝ILS DME。候補は nav DB から EFIS の最大レンジ内を探し、条件と幾何で絞り、15 局の背景走査で確認（ATA34_2 p.605）。12,500 ft 未満は交差角 30–150° に最も近い組、以上は 90° に最も近い組（FMSPG p.26）。局の種別と到達距離・高度の figure of merit を使う（FMSPG p.27）。
- VOR 進入：IAF/FAF の通過で VOR を P 同調、滑走路点があれば入航コースを入れる（FCOM p.1304）。
- ILS：初期 PARK（PFD の表示を消す）。ILS/LOC/BC か ILS 滑走路への VOR・滑走路・VFR 進入を選ぶと、「T/D まで 200 NM 未満」か「経路の半分を過ぎた」（目的地に近い方）で周波数/コース＋PARK（小文字）、「T/D まで 50 NM 未満」か「滑走路端まで 150 NM 未満」か「降下段階」で A（同調）（FCOM p.1306–1307。ATA34_2 p.586 は 200 NM と書く。FCOM を採る）。
- ILS の禁止：離陸後 10 分と手動中は自動同調しない（目的地滑走路の変更で解除）。自動・手動とも禁止：AP 作動で LOC か G/S 捕捉、FD のみで捕捉かつ 500 ft RA 未満、地上で LOC 受信・ヘディングが前コースの 45° 以内・GS > 40 kt（FCC の信号）。手動の許可：TO/GA を押す、または AP 解除で両 FD OFF（FCOM p.1305; ATA34_2 p.470）。
- ADF は手動のみ（FCOM p.1303）。master FMC が故障（空中）か両系故障（地上）なら CDU が自側の無線を手動同調（ATA34_2 p.468）。

### 4.4 経路と EXEC

- RTE 1 と RTE 2、片方が active。非 active 側の ACTIVATE で EXEC 点灯、EXEC で active。active を変えると MOD・ERASE・EXEC 点灯。性能モードの変更も同じ（FCOM p.1238, p.1290）。最小の経路は出発・到着空港と 1 レグ（FCOM p.1278）。
- 地上で ORIGIN を入れ直すと経路を消す。空中は非 active 側だけ。滑走路は最初の点を通過で消す（FCOM p.1288–1289）。エアウェイは TO 点と前の TO 点を含むか前のエアウェイと交差すること。連続 2 本で交点（XJ52）を作り、120 点を超える変更は拒否（FCOM p.1250, p.1297）。
- SID 等の選択は discontinuity を生むことがあり、RTE/LEGS で解消（FCOM p.1236）。滑走路を変えると選択済み手続きを消す（FCOM p.1302）。到着ページは「出発地から 400 NM 超」「経路の半分超」「T/C 後で T/D の 2 分前」「T/D 通過」のどれかで目的地、それまでは出発地（FCOM p.1400）。上昇中に出発地まで 400 NM 未満かつ出発地が近ければ DEP ARR で出発地の到着（FCOM p.1343）。
- DIRECT TO/INTC CRS：アクティブ点の行へ入力。EXEC 前は到着コース、後は現在の要求トラック。大円。経路にない点は intercept コースを入力。ABEAM PTS で飛ばした点の真横に点（FCOM p.1237, p.1333–1334）。同じ点が経路に 2 回あれば direct-to・HOLD は最初の方（FCOM p.1237）。
- 定義点：lat/lon、PBD・PB/PB（SEA01。RTE 1 は 01–49、RTE 2 は 51–99）、along-track（discontinuity を作らない、隣の点までの距離未満）、緯度・経度の報告点（W060-10）。条件点は手入力不可（FCOM p.1249–1251; FMSPG p.212–215）。
- オフセット：空中、SID・STAR・transition 上でないとき。L/R 1–99 NM。STAR・進入・進入 transition・discontinuity・経路終点・135° 超の経路変化・ホールドまで。削除・0・direct-to で解除。LNAV 中の EXEC で捕捉旋回（FCOM p.1298–1299）。END OF OFFSET は 5 NM 手前（FCOM p.1431）。
- シーケンス：オフセットでなく経路から 21 NM 超離れているとアクティブ点を進めない。21 NM 超のオフセットへの出入りは 200 NM まで許す。VECTORS は終点の無い線で、先へは direct-to か intercept（FCOM p.1237, p.1298）。

### 4.5 レグ種別と手続き

- LNAV は通常、点間の大円。手続きでは FMC がヘディング、トラック、DME arc を指令（FCOM p.1245）。LEGS の脚方向：計算コース、手続きのコース/トラック、arc（半径・L/R）、HDG、TRK、HOLD AT、PROC TURN、PROC HOLD（FCOM p.1331）。570 は constant radius to fix（例：1.9 ARC R）（FCOM p.1247）。
- 条件点：高度通過、ヘディングで radial/DME まで、コース切込み、ヘディングでベクター。高度と切込みは括弧表示。例 (1000)：180° を 1,000 ft まで保持、その後 140°（FCOM p.1249; FMSPG p.215）。手続き上の無名の旋回点は lat/lon 点になる（FCOM p.1248）。
- 進入：transition 無しなら FAF の 4–8 NM 外（チャートの点か CFxxx）から直線進入。transition 選択で FAF intercept（PELLY INTC 等）に置き換え。INTC で進入コースを入航コースとするアクティブ点（FCOM p.1404–1405）。GP 角（ILS、B/C、GPS、LOC、RNV、NDB、VOR 進入、STAR にもある）を LEGS に出し、VNAV PTH はその角で誘導（FCOM p.1262, p.1405）。
- VFR 進入：滑走路から 8 NM の FAxxx（170 kt／滑走路 +2,000 ft）→ 滑走路 50 ft。FPA 既定 3.0°（2.4–3.7）。RWY EXT 1.0–25.0 NM。パスに乗るまで水平（FCOM p.1407–1408）。
- fly-by と fly-over の区別、通常の旋回のバンクと旋回開始点：資料に記載なし。資料にあるのは「区間の間は曲線でつなぐ」（ATA34_2 p.615）、「EFIS は全点を滑らかにつなぐ」（ATA34_2 p.626）、「捕捉は最大 25° で滑らかに」（ATA34_2 p.618）だけ。

### 4.6 ホールド

| 項目 | 内容 | 根拠 |
|---|---|---|
| 旋回半径 | 保持点が TO 点になった時に計算。性能初期化済みなら現在 GS＋風の大きさ、未初期化なら TAS＋風で、25° バンク。以後は保持点通過ごとに「保持速度の TAS＋風」で再計算。FAA/ICAO の保護空域内に制限 | FMSPG p.224; FCOM p.1413 |
| 保持速度 | 速度介入中は MCP。制限速度があれば min(制限, best hold)、無ければ best hold（Vgmin が下限）。best hold は最大航続時間速度とフラップ機動速度の大きい方 | FMSPG p.224; FCOM p.1419, PI p.318 |
| 脚長 | LEG TIME（≤ 14,000 ft 1.0 分、> 14,000 ft 1.5 分）か LEG DIST（排他）。時間なら 時間/60 ×（保持 TAS＋入航方向の風）。比較高度：上昇・降下中はホールドの制限高度（窓は上限）→ 直前の脚の制限 → 1 分、巡航中は CRZ ALT。VNAV 中に 14,000 ft を通過し SPD/TGT ALT が大文字なら自動切替 | FCOM p.1417–1418; FMSPG p.222–224 |
| 進入 | 保持点通過時のトラックで parallel/teardrop/direct。最初の外側脚は計算距離。parallel：入航に平行な脚（半径 × 2.41）と保持点側への 180°。teardrop：入航の逆から 40° の脚（半径 × 2.95）と 180°。direct：区間なし | FCOM p.1413; FMSPG p.225 |
| バンク | ホールドと進入は最大 30° | FCOM p.1413; FMSPG p.164 |
| 終了 | 高度終了（AT OR ABOVE、上昇のみ。到達で exit armed、既に上なら飛ばない）、点終了（1 周）、手動（EXIT HOLD → EXIT ARMED → 保持点で離脱）。exit armed で最短で保持点へ戻る形に変える。direct-to で即離脱。HOLD AT 点の削除・飛ばしで次の点へ直行。PROC HOLD は入航で保持点に着いたら出る | FCOM p.1416, p.1419; FMSPG p.221–222 |
| 作成 | HOLD キー：経路にホールドが無ければ LEGS に HOLD AT 枠と PPOS（EXEC 時の位置）。入航コース既定は前の脚のコース、右旋回。手で作れるのは手動終了型だけ。変更は次の保持点通過で有効 | FCOM p.1413–1416; FMSPG p.222 |
| 減速・縦 | 上昇・巡航は事前に保持速度へ減速、降下はホールドに高度制限があるときだけ。上昇中は降下指令を、降下中は上昇指令を出さない（制限種別ごとの目標は FMSPG） | FMSPG p.225–227 |
| 予測 | FIX ETA、EFC TIME（下流の ETA・燃料に反映）、HOLD AVAIL（予備燃料を使わずに待てる時間）、BEST SPEED | FCOM p.1419 |

### 4.7 LNAV

- 作動（ATA34_2 p.619 の図）：FMC 側は「software monitor valid、IRS valid、ADC valid、active route、50 ft 超、捕捉条件、LNAV ARM/OPERATE」の AND で横誘導指令の SSM を NCD → valid にし、FCC が SSM を見て arm（白）→ engaged（緑）。捕捉条件：アクティブレグから 2.5 NM 以内、またはトラックがレグに交わり最大 25° バンクで滑らかに乗れる（ATA34_2 p.618）。作動高度は滑走路標高 +50 ft、標高は 100 kt 通過時の気圧高度（FCOM p.644, p.667）。ゴーアラウンド後は 400 ft RA 超（FCOM p.1262）。
- 現ヘディング保持：最終点、discontinuity 手前の点、オフセット最終点の通過。経路の activate やエアウェイ切込みで捕捉条件外のとき（FCOM p.644）。
- 誘導：前後の点の位置と現在位置からクロストラック誤差を作り、横の誘導指令を FCC へ（ATA34_2 p.615, p.617）。バンクは捕捉 25°、ホールド 30°。通常の旋回の限界は資料に記載なし（推定：25° と予測 GS の半径で旋回開始を決める）。
- 解除：HDG HOLD、HDG SEL、LOC 捕捉、FMC 両系故障（FCOM p.644–645）。

### 4.8 VNAV

- 作動（ATA34_2 p.621 の図）：共通 AND＝software monitor valid、sensor data valid、PERF ページ入力済み、400 ft 超、VNAV ARM/OPERATE。VNAV SPD＝(climb 段階 OR step descent)、VNAV ALT＝MCP 高度を横切る、VNAV PTH＝active route AND (cruise OR descent 段階)。性能解は GW・CI・目標高度・経路が揃って初めて出る（FMSPG p.30）。
- 誘導の 4 形態（ATA34_2 p.615–616）：speed/thrust（ピッチで速度、推力は目標値。上昇・早期降下・driftdown）、path/speed（ピッチでパス、推力で速度。巡航・浅い降下）、path/idle（ピッチでパス、推力アイドル。基本の降下）、speed/hold（ピッチで速度、A/T HOLD。step descent）。FMA は VNAV SPD/PTH/ALT（FCOM p.645, p.664–665）。

上昇（FCOM p.1255, p.1326, p.667）：

| 区間 | 目標速度 | 根拠 |
|---|---|---|
| 離陸〜400 ft | V2+10〜V2+25（回転の速さで決まる）。VNAV 作動までは目標を現速度に合わせ続ける | FCOM p.1255, p.1325 |
| ACCEL HT かフラップ上げ開始 | 現フラップのプラカード −5 kt。格納ごとに次のプラカード −5 kt | FCOM p.1255, p.667 |
| 減推力点（400–9,999 ft HAA か flaps 5） | 推力基準を armed CLB（CLB/CLB 1/CLB 2）へ | FCOM p.1255, p.1272, p.1319 |
| フラップ格納後（か AFDS 捕捉高度） | max(VREF+100, 出発地の速度移行値)、形態で制限 | FCOM p.1255, p.667 |
| SPD TRANS 高度通過 | ECON 上昇速度（CAS → Mach）を巡航まで | FCOM p.1326 |

- 制限：手続きの速度制限、点の速度制限、SPD RESTR、選択速度。点の速度制限は VREF+100 か移行速度より大きいときに優先。制限と性能速度の遅い方。高度制限での一時水平は指令速度の VNAV PTH。届かなければ UNABLE NEXT ALT（速度介入で遅くするか CLB 減格を消す）。CLB ページの ERROR：制限点で 200 ft 以上低いか 1 NM 以上遠いとき（FCOM p.1255, p.1326, p.1329; ATA34_2 p.553）。
- 上昇 SPD TRANS：出発地の nav DB 値、または max(出発地の移行速度, VREF+100)（例 272/10000）。移行高度より上は出さない、削除可（FCOM p.1328）。ATA34_2 p.552 は既定を「10,000 ft まで 250 kt、以後 ECON」の 2 区間と書く。SPD RESTR：CRZ ALT 未満の点に結びつかない制限（例 240/8000）、入力前はダッシュ、通過でダッシュ（FCOM p.1328; ATA34_2 p.553）。TRANS ALT：出発地の nav DB、無ければ 18,000 ft。CDU の表示を FL にするだけ（FCOM p.1329）。
- T/C：CRZ ALT に達する点、緑の円。MCP 高度で一時水平すると VNAV ALT、ノブを押すと VNAV SPD で上昇再開（FCOM p.1256）。

巡航：

- 速度：ECON（CI）、LRC、E/O、選択、RTA。CI 0＝最大航続（燃料最小）、9999＝包囲線最大、範囲 0–9999。CI の変更は T/D の 10 NM 手前まで（FCOM p.1238, p.1257, p.1311）。ECON は重量・高度・温度・CI（と風）の関数（FMSPG p.261–262; ATA34_2 p.610）。
- 巡航上昇・降下：MCP を CRZ ALT と違う値にしてノブ → CRZ ALT＝MCP、ACT ECON CRZ CLB/DES（ノブ経由は MOD を作らない）。降下は T/D の 50 NM より手前のとき。MCP が SPD TRANS/RESTR 高度より下なら両者を消す（乗員が守る）。降下パスを捕捉しないことがある（FCOM p.1257, p.1261, p.1348）。降下率は資料に記載なし（E/O では約 1,250 fpm：FCOM p.1269）。
- ステップ：STEP SIZE 0–9000（1000 刻み）か ICAO（既定）。0 は一定高度で予測。STEP TO は OPT より上。ICAO は「離陸前の CRZ ALT で決まる飛行方向」の OPT 直上の高度（FL280・OPT FL337 → FL350）、数値は CRZ ALT＋n×STEP SIZE の OPT 直上。LEGS の S 付き高度が優先。ステップ点は OPT が 2 高度の中間になる重量の点。AT（ECON は運航費、他は燃料が最小の点）→ NOW。MAX 不足なら AVAIL AT。T/D 200 NM 以内は TO T/D で STEP TO 空白（FCOM p.1257, p.1332, p.1348–1349）。予測はステップを予定どおり行う前提、点を過ぎたら即上昇の前提（FMSPG p.234）。
- OPT/MAX：OPT は ECON なら運航費、LRC・選択速度なら燃料が最小。MAX は総重量・作動エンジン数・速度モード・残余上昇率（既定 100 fpm）で、制限は無視（FCOM p.1349–1350）。予定上昇速度と巡航速度が包囲線内（ATA34_2 p.611）。CRZ CG（既定 20.0%、8.5–33.0%）を最大高度とバフェット余裕に使う（FCOM p.1311）。性能表の前提は「推力とバフェットの厳しい方、OPT は 1.5 g 以上の余裕、上限 45,000 ft」（FCOM PI p.316–317）。CRZ ALT ≥ MAX なら燃料予測を出さない（ATA34_2 p.611）。
- RTA（109/405）：指定点に ±30 s、巡航のみ、E/O 不可、MAX SPD 既定 M.880、不能で UNABLE RTA（FCOM p.1269, p.1383–1384）。

降下：

- E/D：到着・進入手続きを入れると作る。滑走路点の 50 ft 上、VOR 進入は MAP。巡航中に下流の点へ高度制限を入れても作る。DES ページの E/D は降下段階の最も低い高度制限。無ければ DES ページは空白（FCOM p.1258, p.1389, p.1392）。
- T/D とパス：最初の制限までのパスはアイドル推力・スピードブレーキ収納・予報風と巡航風・防氷の予測・目標速度で作る。最初の制限より後は点間の直線。浅すぎる区間は A/T SPD で速度、昇降舵でパス（FCOM p.1258）。図の順序：T/D で水平減速（VNAV PTH）→ 降下 → 速度制限高度の手前で目標速度へ減速（VNAV PTH、約 500 fpm）→ 目標速度で降下・進入（FCOM p.1263–1264）。
- 速度：ECON か手入力の Mach/CAS。ECON は 349 kt（VMO/MMO −16）、手入力は 354 kt（−11）を超えない。移行高度で減速し、目標は移行速度の 10 kt 下（FCOM p.1258）。降下 SPD TRANS は目的地の制限速度 −10 kt（無ければ 240）/nav DB の高度（無ければ 10,000 ft）、高度未満で空白。SPD RESTR は E/D より高い点に結びつかない制限（CAS）（FCOM p.1392; ATA34_2 p.564）。既定の降下は「ECON で 10,000 ft まで、以後 240 kt」（ATA34_2 p.563）。

| パスと速度の許容（FCOM p.1259–1260） | 最初の速度制限より上 | 最初の速度制限より下 |
|---|---|---|
| 遅い | 目標 −15 kt 超で A/T を IDLE/HOLD → SPD（A/T 不作動なら THRUST REQUIRED）。最小機動速度まで許し、その後パスの下へ。150 ft 以内に保てなければ VNAV SPD に反転、目標 max(best hold, 最小機動)+5 kt、THRUST REQUIRED 再表示 | 目標 −10 kt 超で同様。反転時の目標は目的地移行速度 −10 kt（最小機動以上） |
| 速い | 349 kt 超で DRAG REQUIRED。354 kt まで加速を許し、パスの上 150 ft まで。保てなければ VNAV SPD に反転、目標 349 kt | 目標 +10 kt 超で DRAG REQUIRED。目標 +15 kt まで（移行高度以下は移行速度 +5 kt、フラップ時はプラカード −5 kt まで）、150 ft 上まで。反転時は移行速度 −10 kt |

- 早期降下：DES NOW（T/D があり降下段階でないとき）、または T/D 50 NM 以内で MCP ノブ、あるいは MCP を最も高い降下制限より下にしてノブ → 降下段階。約 1,250 fpm、現在の降下速度スケジュール、A/T は THR → HOLD（レバーで率を調整可）、VNAV SPD。アイドルパスに交わったら VNAV PTH（FCOM p.1260–1261, p.1389, p.1393, p.665）。DES DIR/CLB DIR：機体と MCP 高度の間の高度制限を全部削除、CRZ ALT は変えない（FCOM p.1329, p.1393）。
- MCP 高度との関係：VNAV のプロファイルと MCP 高度が衝突すると水平になり VNAV ALT。高度を変えてノブ、またはパスより下ならパスとの交差で降下継続。T/D の 2 分前に MCP が巡航高度のままなら RESET MCP ALT（FCOM p.645, p.665）。VNAV 作動時に MCP と FMC 目標の間にいれば CHECK ALT TGT（FCOM p.1431）。
- 進入（FCOM p.1261–1262）：on approach になるのは VFR 進入で FAxxx を通過、RWyyy へ direct/intercept で滑走路端 25 NM 以内、計器進入の最初の点を通過。抜けるのは TOGA、着陸、最終点を越えて ACT END OF DES。on approach 中は IAS/MACH 窓を開けても VNAV PTH のまま、MCP を機体より 300 ft 以上上に設定しても降下継続。フラッププラカードの 5 kt 以内かつパスの上 150 ft 超で VNAV SPD。GP 角の脚は VNAV PTH でその角、その手前の点を過ぎたらパスに交わるまで水平。
- ミスト進入（FCOM p.1262–1264）：TOGA。LNAV/VNAV は 400 ft RA 超でのみ。機体より下の降下制限を消す（点は残す）。手続きの最高高度を新しい CRZ ALT にして descent → climb。巡航段階の速度目標は min(移行速度, best hold, ECON 巡航)。VNAV SPD で上昇し、ミスト進入高度で VNAV PTH。
- E/O（FCOM p.1265–1269, p.1341–1342, p.1350–1353）：VNAV 作動後で E/O 加速高度・減推力点より下で故障 → VNAV SPD で V2+10、TO 推力維持。加速高度かフラップ上げで VREF+100 へ加速（ACT VREF+100 CLB）、VREF+98 で TO → CON（フラップ全上げ時）。ENG OUT> を EXEC：E/O 上昇、上昇の移行・制限を削除、CON。E/O MAX より上なら E/O LRC driftdown（MCP を E/O MAX 以下にして EXEC、CON、最小 300 fpm、E/O MAX を捕捉して E/O LRC 巡航）。2 発故障で 2E/O。降下に E/O 専用ページは無い（FCOM p.1400）。

### 4.9 性能と予測

- 性能機能の出力（ATA34_2 p.609–612）：重量・燃料、速度包囲線（フラップ・荷重倍数・脚で最小・最大）、最適 VNAV 速度（最小移行上昇、ECON 上昇・巡航・降下、最大角上昇、LRC、E/O LRC、E/O 最小抗力、best hold）、軌跡予測、最大・最適高度、推力目標（巡航の目標推力、水平到達時の推力）、離陸速度・トリム、VREF。どれかが無効になると全速度目標を無効にし CDU から消す（ATA34_2 p.610）。
- 軌跡予測の入力：必須は GW、CI、CRZ ALT、目的地、点、緯度経度、作動中の誘導、高度、燃料、2 点以上の横経路、E/D。任意は点ごとの風・温度、降下の着氷予報、FF 係数、上昇減格、抗力係数。降下データが無いと降下パスも T/D も作らず、T/C 以後を巡航の続きで予測（ATA34_2 p.610–611）。GW は ZFW から計算（または GW から ZFW）。全性能計算は GW が要る（FCOM p.1309–1310; ATA34_2 p.609）。
- 予測の出力：目的地の ETA・燃料（ステップ前提）、各点の ETA・燃料（RTE DATA、discontinuity は直行で計算）、T/C・T/D・S/C・E/D・LEVEL AT までの時間・距離、DEST の代わりに代替地（DIR TO ALTERNATE）や経路上の点（EN ROUTE WPT）（FCOM p.1349, p.1363, p.1372–1373）。脚・フラップを出したままの飛行は予測に入らない（FCOM p.1274, PI p.323）。
- 風（FCOM p.1364–1366; FMSPG p.228–233）：点ごとに 4 高度。ある高度の最初の入力は全点（前後）へ、以後の入力は下流へ次の入力まで伝搬。OAT は標準減率で他高度へ。巡航高度が入力の間なら補間。全入力が巡航高度より上なら最低入力から出発地（上昇）・目的地（巡航）の高度で 0 へ、全部下なら最高入力を巡航高度まで延長。降下予報（4 高度、TRANS LVL 既定 FL180、TAI ON 高度）は巡航風と混ぜる（FCOM p.1395–1397）。計測風との混合：機位で 100%、前方 200 NM（上昇・降下は 5,000 ft）で 50/50、その先はほぼ予報。
- その他：OFFPATH DES の clean/drag circle（FCOM p.1398–1399）、FIX INFO の交点の ETA・距離・高度と PRED ETA-ALT（FCOM p.1358–1359）。

### 4.10 燃料監視

- CALC：始動前は FQIS 値、FF 信号で切り離して FF で減算。ジェティソン中は FQIS に合わせ、終了後に再び減算。全エンジン停止後に FQIS へ戻す。MANUAL：乗員入力を FF で減算（TOTALIZER 表示を消す）。SENSED：始動後に FF が無効になったら FQIS（PROG は TOTALIZER）（FCOM p.1273–1274, p.1310, p.1379; ATA34_2 p.531 は FF 無効 2 分超）。
- FUEL USED：FF からエンジンごと。flight complete まで保持し、エンジン始動か地上の長時間電源断で消える。始動後 2 分超の FF 無効か地上で無効なら空白（FCOM p.1274）。
- FUEL DISAGREE - PROG 2：差 4,080 kg 以上（109/405）で、PROG 2 の USE（TOTALIZER/CALCULATED）で選ぶ。FF 公差で 25–40 kg/h の差は普通（FCOM p.1381–1382）。ATA34_2 p.569 は 9,000 lb が 5 分続いたとき。
- INSUFFICIENT FUEL：目的地の予測燃料 < RESERVES（FCOM p.1274, p.1432）。

### 4.11 メッセージの扱い

- alert と advisory、どちらも MSG 灯。alert だけが EICAS の FMC MESSAGE（level C）。alert は advisory より優先して上書き、新しい alert が来ると古いものはスタックへ。CLR で上から 1 件ずつ（押し続けても連続で消えない）。原因が解消すれば消える。滑走路が経路にある進入中の 500 ft AGL 未満は alert を出さず、flight complete か 1,000 ft AGL 上昇通過で出す。advisory は条件が起きた CDU だけ、入力誤りの advisory が一般 advisory より優先（ATA34_2 p.635–636; FCOM p.1430）。

### 4.12 二重系・故障・代替航法

- resync：比較で差が出た、または内部試験失敗で再起動したとき。master が経路・性能データを送る（約 15 s）。その間相手 CDU は故障表示、他方に RESYNCING OTHER FMC。失敗で一方を停止（FCOM p.1277; ATA34_2 p.632）。
- 単一故障：resync、active 経路が非 active、性能データ喪失、LNAV/VNAV 喪失がありうる。地上はどちらでも SINGLE FMC OPERATION。空中で非選択側が故障：その CDU に TIMEOUT - RESELECT、他に SINGLE FMC OPERATION。選択側（master）が故障：両 CDU に TIMEOUT - RESELECT、3 台の FAIL 灯、その FMC を源とする ND が消え、遅れて FMC LEFT/RIGHT。selector を回すと復帰（FCOM p.1275）。故障 FMC は出力を止め、PFD の A/T FMA 空白、ND に MAP（30 s 後）と VTK 旗（ATA34_2 p.630）。両系故障：LNAV・VNAV・A/T 不可（FCOM p.1275）。LH3460 p.90–93 に正常時と片系故障時の割り当て図。
- 代替航法（FCOM p.1421–1428; ATA34_2 p.589–592）：CDU は自側 IRU で計算。FMC の active 経路を常にコピーし、故障時は条件点・オフセット・ホールド以外を保持。新しい点は lat/lon だけ。大円、active 点の変更は「現在位置から直行」だけ。CDU ごとに独立。L CDU は機長 ND、R は F/O ND、C は切替（F/O ND でレンジが機長と違うと MAP RANGE DISAGREE）。active 点だけ磁方位、以後は真方位。無線は各 CDU で手動（L：L VOR/DME/ADF/ILS、R：右側、C：C ILS）。故障時 autotune 中の ILS はコピー。ページは IRS LEGS、IRS PROGRESS（LAST/TO/NEXT/DEST の DTG・TTG、IRS 位置、XTK、DTK、TK、GS）、ALTN NAV RADIO。

## 5. 他系統とのつながり

| 相手 | FMC への入力 | FMC からの出力 | 根拠 |
|---|---|---|---|
| AFDS（MCP・FCC。ATA 22） | 選択値・ボタン・介入・TO/GA・A/T ARM、ILS 同調禁止 | LNAV/VNAV の誘導指令、V/S 指令、速度制限、MCP の窓表示・モード | ATA34_2 p.470 |
| A/T・EEC（別担当） | エンジンデータ（EIU） | VNAV の推力モード要求と目標推力 | ATA34_2 p.615–617 |
| IRS・GPS・航法無線・ADC | 位置・速度・方位・距離・偏位・高度・温度 | POS INIT 位置、SET HDG、無線の周波数・コース | ATA34_2 p.458–459, p.468, p.478 |
| 表示（EIU/IDU） | EFIS CP | PFD 速度テープ・A/T FMA、ND 地図、GW など | ATA34_2 p.462–466, p.501–506 |
| CPCS（ATA 21） | — | 着陸高度、上昇・降下のプロファイル（T/D など） | FCOM p.1400; ATA34_2 p.477 |
| GPWC・失速警報（MAWEA） | — | 位置・トラック（L FMC）／GW・CG | ATA34_2 p.477–478 |
| 燃料（ATA 28） | 総燃料・FF・ジェティソン | 予測、FUEL DISAGREE、INSUFFICIENT FUEL | FCOM p.1273–1274 |

- 現コードの実際：AP が `laminar/B747/fms/data`（JSON）の速度・高度・CI を読む（VS:168, VS:204, VS:233 など）。EEC と FDR も同じ JSON を読む（`B747.42.xt.EEC.lua:318, 411`）。ND は `autopilot/dist/top_of_descent_lat` などと `xtlua/fms` を読む（`B747.61.xt.nd.lua:27-34, 69`）。CPCS の着陸高度は FMC から来ず 2,000 ft の既定値（`B747.55.xt.air.lua:881`、ATA-21.md と対）。PFD の速度帯（Vmc/Vmo）は計器モジュールが計算（`B747.60.xt.fltInst02.lua:2861-2956`）。

## 6. 実装上の注意

### 6.1 ネイティブ FMS に頼ることの限界

- 受け取れるもの：XTLua の本体（`plugins/xtlua_keysystems/64/win.xpl`）が使う SDK は旧来の FMS API だけ（バイナリ内の名前：XPLMCountFMSEntries、XPLMGetFMSEntryInfo、XPLMGetDisplayedFMSEntry、XPLMGetDestinationFMSEntry、XPLMSetDestinationFMSEntry、XPLMSetFMSEntryLatLon、XPLMClearFMSEntry、XPLMLoadFMSFlightPlan）。この API の 1 点は「種類・ID・航法施設・高度 1 つ・緯経度」で、`xtlua/fms` はこれに active 印を足した配列（推定）。コードが使うのは [2] 種類（1＝空港、2048＝lat/lon）、[5][6] 緯経度、[8] ID（"latlon"、"VECTOR"、"(1000)"、"PPOS"）、[9] 高度、[10] active（AP:1670, AP:2186, AP:2323, MON:38, FMS:845）。

| 欠ける情報 | できない・難しいこと | GAP |
|---|---|---|
| 脚の種類、旋回方向、arc の中心・半径 | HDG/TRK 脚、コース → 高度、radial/DME まで、INTC、VECTORS、DME arc、RF、PROC TURN を本物どおりに飛ぶこと。条件点の位置はネイティブが置いた点を使うしかない | FMC-01 |
| fly-over 印 | fly-over 点（DER・MAP など）での旋回の遅らせ | FMC-01, 04 |
| ホールドの定義 | 形・進入・出口・HOLD AVAIL | FMC-02 |
| 高度制限の種類（AT/A/B/窓/S） | at or above の通過、窓、ステップ点、UNABLE NEXT ALT、E/D（最も低い制限） | FMC-07, 12 |
| 速度制限 | SID/STAR の速度と減速区間の計画 | FMC-08 |
| 手続きの区切り（SID/STAR/進入/ミスト）、FAF・MAP、GP 角、滑走路端標高 | approach 段階、on approach、GP 角の VNAV PTH、VOR 進入の E/D、ミスト進入の CRZ ALT、オフセットの終了、到着ページ・CPCS の切替 | FMC-16, 34, 37 |
| 空港の移行高度・制限速度 | SPD TRANS、TRANS ALT/LVL | FMC-10 |
| RTE 2、ACT/MOD の区別、discontinuity（入るか未確認） | 非 active 経路、RTE COPY、MOD の白破線、性能変更を含む EXEC、DISCONTINUITY での保持 | FMC-06, 34 |

- 副作用：3 台の CDU が同じネイティブ CDU（`cdu1`、`sim/FMS/`）を写すので、ネイティブのページを左右で別に出せない（CRE:313-328, FMS:808, FMS:817, FMS:826）。EXEC 灯と MOD はネイティブのもので、自前のページ（CRZ ALT・速度）は MOD を作らない。CRZ ALT はネイティブの VNAV ページ 2 に打ち込んで読み戻している（PG:618-654, PG:1187-1209）。ND の経路線はネイティブの EFIS 地図が描く（`747-400.acf:98958`、`:99872`）。自前の描画に変えるにはパネル定義の変更が要る（純正 acf は不可、カスタム acf は承認が要る：ARCHITECTURE.md §5）。
- 選択肢（どちらも推定）
  - A：ネイティブを経路入力に残し、CIFP（Custom Data 優先）を自前で読み、選ばれた手続きの脚・制限・速度・fly-over・GP 角を点列に対応づける。工数は小さいが、乗員が LEGS を編集すると対応が崩れやすく、ホールド・RTE 2・MOD は解決しない。
  - B：経路を自前で持つ（nav DB を X-Plane のデータファイルと CIFP から読み、RTE/LEGS/DEP-ARR/HOLD/EXEC を実装）。ネイティブには ND の線のためだけに緯経度を流すか、ND を自前の記号で描く。FCOM どおりにするにはこれしかないが L 規模で、CDU 担当と重なる。§8 で B を段階的に勧める。

### 6.2 AFDS・推力との境界

- 今の LNAV は X-Plane の HDG SEL と X-Plane の FD ロール（`sim/cockpit2/autopilot/flight_director_roll_deg`：AP:225、`B747.19.xt.hydraulics_override.lua:408-425`）を使い、バンク限界は X-Plane の `bank_angle_mode`（AP:1362-1382, AP:3454）。VNAV は自前の `vvi_status`・`speed_status`・`altitude_hold_status` を切り替え、油圧モジュールにピッチを作らせている（MON:136-175, MON:238-330）。作り直しでは FMC が「ロール指令（か目標トラックと XTK）」「目標速度」「目標パス（高度・FPA）」「A/T モード要求」を出し、AFDS がそれを使う形に分ける。ATA 22 の作り直しと一緒に決める。
- 推力の値（CLB/CON/GA、減格）は別担当。VNAV から渡すのはモード要求（THR REF、THR、IDLE、HOLD、SPD）と目標だけ。

### 6.3 簡略化してよいもの・いけないもの

- よい：FMC 2 台は「1 つの計算＋master・故障の状態」で表し、resync は表示と遅延だけ。BITE・データローダー・クロスロード。nav DB の 2 サイクル（X-Plane のサイクルを表示）。FMC 位置はシムの真値＋更新モードに応じた ANP と IRS ドリフトの簡易模型（ANP の式は資料に記載なし、推定）。DME-DME は仮想でよいが、VOR/ILS の同調と P/R/A/M 表示は残す。性能 DB は FCOM PI の表から作る（PW4056：p.223–324、CF6-80C2B1F：p.325–412。RR は資料が無いので PW で代用、推定）。ECON の CI 依存は資料に表が無いので推定。
- いけない：高度・速度制限を守ること、T/D・E/D とアイドルパス・減速区間、パスと速度の許容と反転、MCP の高度・速度ノブとの関係、LNAV の捕捉とシーケンス（21 NM）、ホールドの進入と出口、乗員の行動を促すメッセージ（UNABLE NEXT ALT、DRAG/THRUST REQUIRED、RESET MCP ALT、DISCONTINUITY、END OF ROUTE、INSUFFICIENT FUEL、UNABLE RNP）。
- 速度の上限は ECON 降下 349 kt、手入力 354 kt（FCOM p.1258）。保持速度は max(最大航続時間速度, フラップ機動速度)（FCOM PI p.318）。

### 6.4 XTLua と負荷

- `xtlua/fms` は変わったときだけ decode する（今は毎フレーム：AP:3535、FMS:936、VPG:69）。`collectgarbage("collect")` を毎フレーム呼ばない（AP:3504）。
- m/s と kt、NM と m の混在が誤りを生んでいる（FMC-15, FMC-21）。単位を変数名に付ける。グローバルの表は metatable 付き（ARCHITECTURE.md §1）。

## 7. 現状実装との比較（GAP 候補）

現状の作り（要約）：
- 経路は X-Plane のネイティブ FMS が持つ。RTE の 2 ページ目以降と LEGS はネイティブ CDU の行を写してキーを `sim/FMS/` へ送るだけ（PG:96-177, LEGS:1-52）。
- LNAV：`override_fms_advance`=1 で自前にアクティブ点を選び（`xtlua/currentFMSID` に書く）、その点への方位に風補正をして X-Plane の HDG SEL に入れる（AP:2183-2316, MON:789-863）。
- VNAV：T/D・E/D・パスは 290 ft/NM、上昇は FLCH、降下は計算した V/S、巡航は ALT HOLD（AP:2014-2171, MON:26-357, VN:16-124）。速度は高度帯の状態機械（VS:101-494）。
- 予測：OPT/MAX は GW の一次式、燃料は現在の FF × 時間か 51.6 lb/NM（VPG:190-310, PRG:64-119）。位置はシムの真値（IRS:29-63）。

| ID | 種別 | 重要度 | 規模 | 内容 | 根拠 | 該当コード |
|---|---|---|---|---|---|---|
| FMC-01 | 欠落 | 高 | L | 経路モデルが無い。ネイティブの点列（種類・ID・緯経度・高度 1 つ・active）だけで、レグ種別（HDG/TRK、コース → 高度、radial/DME まで、INTC、VECTORS、DME arc、RF、PROC TURN）、fly-over、手続きの区切りを知らず、全レグを点間の直線で扱う | FCOM p.1245, p.1247, p.1249, p.1331; ATA34_2 p.615 | AP:3534-3537, AP:2183-2316, MON:789-863 |
| FMC-02 | 欠落 | 高 | L | ホールドが無い（形、進入、30° バンク、種類別の出口、EXIT HOLD、HOLD AVAIL・BEST SPEED・EFC、減速区間）。HOLD キーはネイティブの HOLD ページを出すだけで、自前の LNAV はホールドを飛べない | FCOM p.1413–1419; FMSPG p.164, p.221–227; ATA34_2 p.573–574 | CRE:94-99, MON:789-863 |
| FMC-03 | 挙動の誤り | 高 | M | LNAV は arm 後、電波高度 50 ft で無条件に作動。2.5 NM・切込み・25° で乗れるかの判定、active route の確認、NOT ON INTERCEPT HEADING が無い。基準も滑走路標高 +50 ft（100 kt で記録した気圧高度）でない | FCOM p.644, p.663, p.667; ATA34_2 p.618–619; FMSPG p.21 | AP:1058-1074, AP:2877-2880 |
| FMC-04 | 挙動の誤り | 高 | M | 横誘導が無く、アクティブ点への方位（残り 10 NM 超ならレグ上 5 NM 先）を HDG SEL に入れるだけ。旋回の曲線遷移が無く、旋回開始は方位変化と GS の経験式（1–8 NM）。バンクは BANK LIMIT（HDG SEL 用）と X-Plane の FD ロールに依存し、acf の AP 設定（ACF_DIFF §3.3）でも変わりうる | ATA34_2 p.615, p.617–618, p.626; FCOM p.647, p.1413 | MON:789-863, AP:2272-2285, AP:1362-1382, AP:3454 |
| FMC-05 | 挙動の誤り | 中 | S | シーケンスに 21 NM の制限が無い（100 NM まで次のレグを探す）、オフセット移行の 200 NM も無い。重複点の「最初の方」規則が無い。RA 1,000 ft 未満かつ V/S 500 fpm 未満では止まる | FCOM p.1237, p.1298 | AP:2185, AP:2194, AP:2267 |
| FMC-06 | 欠落 | 高 | M | 経路終点・discontinuity・オフセット終点で現ヘディングを保持しない（最後の点へ向け続ける）。DISCONTINUITY・END OF ROUTE・END OF OFFSET を出さない | FCOM p.644, p.1431 | MON:778-863, NOTI:10-13 |
| FMC-07 | 欠落 | 高 | L | 高度制限の種類（AT/A/B/窓/S）が無い。上昇は「次に高度を持つ点」で水平（at or above でも止まる）、降下は移行高度より下の高度だけ使う。CRZ ALT 未満の検査、UNABLE NEXT ALT、CLB DIR/DES DIR、DESCENT PATH DELETED が無い | FCOM p.1253, p.1255, p.1329, p.1332, p.1393 | MON:26-101 |
| FMC-08 | 欠落 | 高 | L | 点・手続きの速度制限が無い（ネイティブの点に速度が無い）。「制限と性能速度の遅い方」「VREF+100/移行速度より大きい制限を優先」も無い | FCOM p.1326, p.1329, p.1332 | なし（VS:101-129 は SPD RESTR/TRANS だけ） |
| FMC-09 | 挙動の誤り | 高 | S | 上昇速度の取り違え：SPD TRANS 高度未満は `clbspd`（250、ECON SPD 欄）、以上は `transpd`（272、SPD TRANS の速度）を飛び、ECON 上昇 CAS が無いまま 272 kt で Mach 移行まで上がる。VREF+100 は計算せず固定 272。離陸後は 100 ft AGL まで V2、すぐ SPD RESTR へ。ACCEL HT とフラップ格納中の「プラカード −5 kt」が無い（フラップ位置ごとの上限 `modFlapSpeed` で代用） | FCOM p.1255, p.1326, p.1328, p.667 | VS:37-39, VS:156-229, FMS:612-618 |
| FMC-10 | 挙動の誤り | 中 | S | 既定値：上昇 SPD RESTR 250/5000・降下 180/5000 が最初から入る（本来ダッシュ）。上昇 SPD TRANS、TRANS ALT（18,000 固定）、降下の制限速度を出発地・目的地の nav DB から取らない | FCOM p.1328–1329, p.1392, p.1396 | FMS:612-626 |
| FMC-11 | 挙動の誤り | 中 | M | CI を使うのは巡航 Mach の経験式だけ（LRC＝388+0.62·GW[t]+7.8·高度[kft] の千分率、CI 230＝LRC）。ECON 上昇・降下（.805/270）は固定、349/354 kt の上限なし。CI を入れると乗員の巡航速度入力が無視される。CRZ ページの ECON SPD は保存値で飛んでいる Mach と違う | FCOM p.1238, p.1258, p.1311, p.1348; FMSPG p.29, p.261–262 | VS:230-309, VPG:321 |
| FMC-12 | 挙動の誤り | 高 | L | E/D は「目的地 10 NM 以内の最初の点」、T/D は E/D から (CRZ ALT − 高度)/290 ft/NM。パスは 290 ft/NM かネイティブの高度間の直線。アイドルパス（速度・風・防氷）、T/D の水平減速と速度制限前の減速、RW+50 ft・VOR は MAP の E/D、巡航中の制限入力での E/D 生成が無い。EOD の高度に `fms[eod][3]` を使う（他所の高度は [9]。[3] の意味は未確認） | FCOM p.1258, p.1263–1264, p.1392; ATA34_2 p.563, p.610–611 | AP:2103-2109, AP:2161-2170, VN:48-72 |
| FMC-13 | 挙動の誤り | 高 | M | VNAV PTH 降下は「目標高度までの差 ÷ 時間」の V/S（−2,500〜+1,500 fpm）。パス許容（15/10 kt、上下 150 ft）、VNAV SPD への反転、THRUST REQUIRED が無い。DRAG REQUIRED は「MCP 速度 +10 kt 超で増速中・V/S 中・推力アイドル」の近似 | FCOM p.1258–1260, p.1431, p.1434; ATA34_2 p.615–616 | VN:16-124, MON:218-357, AP:3400-3413 |
| FMC-14 | 欠落 | 中 | M | 早期降下：T/D 50 NM 以内の MCP ノブで、約 1,250 fpm・THR → HOLD の VNAV SPD を経ずにパス追従へ入る。50 NM より手前の巡航降下が無い（元の CRZ ALT へ戻る、SPD TRANS/RESTR を消さない）。DES NOW と「最も高い降下制限より下」の条件が無い | FCOM p.1257, p.1260–1261, p.1389, p.1393; ATA34_2 p.623–624 | AP:660-716, MON:469-530 |
| FMC-15 | 欠落 | 中 | S | MCP 高度ノブで制限を 1 個ずつ消す機能、CHECK ALT TGT が無い。RESET MCP ALT は NM ÷ m/s の比較で T/D の約 1 分前に出る（本来 2 分） | FCOM p.649, p.665, p.1431, p.1433 | AP:660-716, MON:451-467 |
| FMC-16 | 欠落 | 高 | M | approach 段階・on approach（速度介入中も VNAV PTH、MCP を 300 ft 上でも降下継続）、GP 角の VNAV PTH、VFR 進入、ミスト進入（下の制限削除、最高高度を CRZ ALT、climb へ、400 ft RA 以上で作動）が無い。15 NM 未満は空港標点へ 290 ft/NM | FCOM p.1236, p.1261–1264, p.1405–1408 | AP:2161-2165 |
| FMC-17 | 挙動の誤り | 中 | M | 飛行段階を MCP のボタンで決める（FLCH/V/S は MCP と現高度の大小で climb/descent、ALT HOLD で cruise）。T/C・T/D・approach・flight complete（停止 30 s 後の消去）の論理が無く、VNAV ページの ACT 表示もこれに従う | FCOM p.1235–1236, p.1325 | AP:591-595, AP:751-755, AP:781-785, AP:822, MON:380-414, VPG:157 |
| FMC-18 | 挙動の誤り | 中 | S | VNAV の作動条件は CRZ ALT と、地上で T/D まで 10 NM 未満かだけ（GW・CI・active route・降下時の E/D を見ない）。終点が空港でない経路では LNAV/VNAV を切り、Boeing に無い DESTINATION NOT SET を出す | FCOM p.645, p.1433; ATA34_2 p.620–621; FMSPG p.30 | AP:1020-1057, AP:2376-2384, NOTI:56 |
| FMC-19 | 挙動の誤り | 中 | M | OPT/MAX は GW の一次式（速度モード・温度・残余上昇率・CRZ CG・エンジン数なし）。STEP TO は常に CRZ+2,000 ft（STEP SIZE・ICAO 無視）、ステップ点は MAX から逆算、予測に入らない。MAX ALT・LIMIT ALT・UNABLE CRZ ALT が無い | FCOM p.1257, p.1311–1312, p.1348–1350, p.1433–1436, PI p.316–317; ATA34_2 p.611 | VPG:190-256 |
| FMC-20 | 欠落 | 高 | L | 軌跡予測が無い。PROGRESS の燃料は現在の FF × 時間、CRZ の目的地燃料・ETA は 51.6 lb/NM などの経験式で、風・ステップ・降下・制限を考えない。RTE DATA も無い | FCOM p.1274, p.1349, p.1360–1363, p.1372–1373; ATA34_2 p.610–611 | PRG:64-119, VPG:258-310 |
| FMC-21 | バグ | 中 | S | ETA の速度下限が `275 * 1.944`（534.6 kt）で、GS がそれ未満なら ETA が早すぎる（ND の ETA、PROGRESS、燃料予測）。T/C 距離も `250 * 1.944`（486 kt）を下限にする | FCOM p.1372–1373 | FMS:870-872, PRG:74-82, AP:2022-2025 |
| FMC-22 | 欠落 | 中 | M | CALCULATED が無い（TOTALIZER と CALCULATED の両方がタンク合計）。MANUAL/SENSED、FUEL DISAGREE、USE の選択、INSUFFICIENT FUEL（RESERVES は入力できるが未使用）が無い | FCOM p.1273–1274, p.1310–1311, p.1378–1382, p.1432; ATA34_2 p.531, p.569 | PRG:146-150, PRG:189, PINIT:22 |
| FMC-23 | 挙動の誤り | 中 | S | ACF_DIFF §3.2・§4-4：予測は X-Plane の FF（acf の `_jet_SFC_*` で決まる）を直接使うので、カスタム（巡航 0.25/0.38）と純正（0.313/0.571）で予測が変わる。コードは acf 値に依存する | ACF_DIFF §3.2; ATA-28.md; FCOM p.1274 | FMS:13, PRG:64-118, VPG:230, VPG:287 |
| FMC-24 | 挙動の誤り | 低 | S | 性能の GW はシムの真の総重量。乗員の ZFW・GW 入力が VNAV と予測に効かない | FCOM p.1309–1310; ATA34_2 p.609 | PINIT:18-30, VS:241, VPG:190 |
| FMC-25 | 欠落 | 中 | M | 点ごとの風（4 高度）、伝搬・補間・計測風との混合、DESCENT FORECAST（TRANS LVL、TAI ON 高度）が無い（ページも読み込まれていない） | FCOM p.1364–1366, p.1395–1397; FMSPG p.228–233 | PG:279-309 |
| FMC-26 | 欠落 | 中 | L | E/O の VNAV（V2+10 維持、VREF+100、E/O CLB/CRZ・E/O SPD・E/O MAX ALT、LRC driftdown 最小 300 fpm、2E/O）が無い。ENG OUT> は表示だけ | FCOM p.1265–1269, p.1341–1342, p.1350–1353 | VPG:172, VPG:328 |
| FMC-27 | 欠落 | 低 | M | RTA（109/405）が無い（ページは固定文字） | FCOM p.1269, p.1354, p.1383–1385 | PRG:193-212 |
| FMC-28 | 欠落 | 中 | M | FMC 位置はシムの真値。IRS は真値＋整列時の固定乱数（±0.001°）でドリフトなし。GPS/無線/LOC 更新、IRS 混合・棄却、ANP、RNP、GPS INHIBIT、PURGE、TO/GA 更新、split IRS、VERIFY POSITION が無い。ND の更新モードは IRS の整列状態だけ | FCOM p.1240–1245, p.1367–1370; ATA34_2 p.517, p.601–602, p.606; FMSPG p.25–28 | IRS:29-63, IRS:178-190, FMS:253-254 |
| FMC-29 | 挙動の誤り | 高 | S | UNABLE RNP：目的地 40 NM 以内で LNAV のクロストラック > 1 NM（APP 中 0.3 NM）なら caution、40 NM を出ても消さない。ANP と RNP の比較でなく、approach 以外は advisory のはず。ベクター中に誤警報 | FCOM p.1430; LH3460 p.116 | AP:2220-2232 |
| FMC-30 | 挙動の誤り | 中 | M | VOR の自動同調は 10 s ごとに最寄りの VOR 2 局を入れるだけ。P/R 同調、DME-DME の組（30–150°/90°）、局の禁止、手動との関係、VOR 進入の同調が無い。2 番目の局の選び方にバグ（最寄り更新時の旧値しか入らない） | FCOM p.1240, p.1303–1304, p.1355–1357; ATA34_2 p.605–606; FMSPG p.26–27 | RNAV:24-89, RNAV:65-70 |
| FMC-31 | 挙動の誤り | 中 | M | ILS は目的地 45 NM 以内で、経路点と近くの ILS の幾何から推定して同調（選んだ進入と無関係）。PARK → 小文字 → A の距離条件は NAV RAD の表示だけ、離陸後 10 分と FCC の禁止、ILS TUNE INHIBITED、RW/ILS FREQ ERROR が無い。RW/ILS CRS ERROR を「ILS 未同調で APP/LOC を押した」に流用 | FCOM p.1305–1307, p.1432, p.1434; ATA34_2 p.470, p.586 | AP:1621-1806, AP:2397-2402, AP:2430-2435, PG:428-453 |
| FMC-32 | 挙動の誤り | 中 | S | メッセージは 54 件の表のうち 6 件だけ（DRAG REQUIRED、ENTER IRS POSITION、PERF/VNAV UNAVAILABLE、RESET MCP ALT、RW/ILS CRS ERROR〔誤用〕、DESTINATION NOT SET〔Boeing に無い〕）。10 s ごとに 1 件、どれでも FMC MESSAGE。alert/advisory の区別、スタック、進入中 500 ft 未満の抑止が無い。ネイティブの NAV DATA OUT OF DATE を消す | FCOM p.1430–1436; ATA34_2 p.635–636 | FMS:1110-1136, NOTI:2-77, CRE:520 |
| FMC-33 | 挙動の誤り | 中 | S | VNAV 上昇中に TRANS ALT を越えると両 EFIS の気圧を STD・29.92 に自動で切り替える。FMC にこの機能は無い | FCOM p.1329 | VS:420-434 |
| FMC-34 | 欠落 | 中 | L | 経路管理（RTE 2、RTE COPY、ABEAM PTS、INTC CRS など）はネイティブ任せで、自前の FMC は経路を持たない。性能変更（CRZ ALT・速度）は MOD/EXEC を経ずに即時有効。オフセットは L/R 入力と平行線だけで、終了条件・END OF OFFSET・direct-to での解除が無い | FCOM p.1238, p.1287–1299, p.1333–1334, p.1431 | PG:96-177, PG:1124-1145, PG:1187-1209, MON:823-852, LEGS:1-52 |
| FMC-35 | 挙動の誤り | 中 | M | ND の経路線はネイティブの EFIS 地図が描き、機体は自前 LNAV の別の経路を飛ぶ（旋回・ホールドの見た目と実際が一致しない）。T/C・T/D の位置は自前計算 | ATA34_2 p.626; FCOM p.1251 | `747-400.acf:98958`, `747-400.acf:99872`, AP:2083-2101 |
| FMC-36 | 欠落 | 中 | L | 二重 FMC（master 選択、resync、単一 FMC 運用、FMC 故障時の FMC LEFT/RIGHT・TIMEOUT - RESELECT・LNAV/VNAV/A/T 喪失・ND の旗）と代替航法（IRS LEGS/PROGRESS、ALTN NAV RADIO）が無い。FMC master selector は X-Plane の AP 源を切り替えるだけ、代替航法のページは読み込まれていない | FCOM p.1275, p.1421–1428; ATA34_2 p.456, p.468, p.496, p.589–592, p.629–632 | `B747.60.xt.fltInst02.lua:660-664`, PG:279-309 |
| FMC-37 | 欠落 | 低 | S | CPCS へ着陸高度（到着ページの切替点で目的地・進入の値）を送らない。CPCS は 2,000 ft の既定値。ATA-21.md と対 | FCOM p.1400; ATA34_2 p.477 | `B747.55.xt.air.lua:881` |
| FMC-38 | バグ | 低 | S | PROGRESS 2 の XTK は常に "L"（符号なしの値）、VTK ERROR は "+**FT" 固定 | FCOM p.1377–1378 | PRG:175-181, AP:2292 |
| FMC-39 | 欠落 | 低 | S | nav DB の 2 サイクル切替・失効の扱い、ROUTE FULL（120 点）が無い | FCOM p.1250, p.1271, p.1284, p.1435 | CRE:520 |
| FMC-40 | バグ | 中 | S | AP が毎フレーム `xtlua/fms` の JSON を decode し `collectgarbage("collect")` を呼ぶ。FMS の ETA 表示と VNAV ページも毎回 decode | ARCHITECTURE.md §1 | AP:3504, AP:3535, FMS:936, VPG:69 |

件数：高 13（01, 02, 03, 04, 06, 07, 08, 09, 12, 13, 16, 20, 29）、中 22、低 5。合計 40。

## 8. 作り直しか部分修正か

- 推奨：**作り直し**。FMC の航法・経路・LNAV・VNAV・性能の中核を新しいモジュールにする。CDU ページの体裁は CDU 担当の作業と合わせる。
- 理由
  1. 経路モデルが無い（FMC-01）ので、ホールド、制限、速度制限、E/D、進入、オフセット、メッセージのほぼ全部の土台が無い。部分修正は「ネイティブの点列に推測を足す」方向にしか進めない。旧フォークは 33,000 行規模の修正で CIFP の読込みまで足したが、FCOM の挙動には届いていない（OLD_FORK_NOTES.md 冒頭・§4–8。参照のみ）。
  2. LNAV/VNAV が AFDS のモジュール（MON）の中で X-Plane の HDG SEL・FLCH・V/S・ALT HOLD を切り替える状態機械になり、FMC の段階・目標と AFDS のモードが混ざっている（FMC-17）。ATA 22 の作り直しと同時に「FMC → FCC の誘導指令」の境界を作るほうが安全。
  3. 数値の大半が資料に根拠の無い経験式（290 ft/NM、GW の一次式、51.6 lb/NM、534 kt など）で、個別に直しても全体の整合が取れない。
- 構成案（推定）：nav DB 読込み（X-Plane のデータファイル・CIFP）→ 経路モデル（RTE 1/2、ACT/MOD/EXEC、discontinuity、ホールド、オフセット、制限）→ 経路形状（脚種別、fly-by/fly-over、旋回半径）→ LNAV（捕捉、シーケンス、ロール指令）→ 性能 DB（FCOM PI の表）→ 軌跡予測（上昇・巡航・アイドル降下・減速・風）→ VNAV（モード、目標、許容、メッセージ）→ 航法センサー（位置・ANP/RNP・同調）→ メッセージ管理。ネイティブ FMS は ND の線のためだけに使うか、使わない（§6.1 の B）。
- 進め方：①先に入れてよい小修正（S）＝FMC-21、FMC-09 の速度の取り違え、FMC-10、FMC-33、FMC-29、FMC-30 の 2 番目の局、FMC-15 の RESET MCP ALT、FMC-40。②経路モデルと LNAV（ホールド・オフセット・メッセージを含む）。③性能 DB・軌跡予測・VNAV。④燃料監視・無線同調・二重系・代替航法。
- 残す名前：INTERFACES.tsv の `laminar/B747/fms1〜3/*`（行とキー）、`nd/current_waypoint`・`waypoint_distance`・`waypoint_eta`・`gs_tas_line*`・`range_display_*`・`wind_line`・`wind_bearing`・`toc/*`、`irs/gps_display_line`・`irs_display_line`・`irs/line1〜4`、`autopilot/dist/flight_path_error`、`autopilot/vnav/after_tod`、`autopilot/ils_dots`、`autopilot/button_switch/LNAV`・`VNAV`、`flt_inst/fmc_master_src/ctr_pnl/*`、FMA 系（ATA 22 と共通）。内部の `laminar/B747/fms/data`（EEC・FDR が読む）、`autopilot/dist/*`（ND が読む）、`fms/notification` は互換で残すか、読む側を同時に直す。

## 9. 未確認事項

- `xtlua/fms` の要素の意味（[1][3][4][7]）、discontinuity・ホールド・条件点（"(1000)"、"VECTOR"）がどう入るか、at or above・at or below・窓がどの高度値で来るか（旧フォークは「上昇の at-or-below は 0」と記録。参照のみ）、点数の上限。XTLua のソースか実機で確かめる。
- XP 12.4 の SDK に脚種別・制限種別を読む API があるか（XTLua が使うのは旧 API だけ）。ネイティブの EFIS 地図がホールド・arc・オフセットを描くか。
- `sim/flightmodel/position/magnetic_variation` の符号と、コードが真方位に加算していること（MON:860, PG:390）の整合。
- ACF_DIFF §3.3（`_ott_*` など）が X-Plane の FD ロール、つまり今の LNAV の旋回にどれだけ効くか。
- 資料の食い違い（採った方）：RNP 既定値（ATA34_2 p.517：1.0/12.0/2.0/1.0/0.5、FMSPG p.25：12.0/2.8/1.7/0.5 → ATA）、真方位への切替範囲（FCOM p.1242：82° 等、ATA34_2 p.577・FMSPG p.219：73°N/60°S → FCOM）、ILS が A になる距離（FCOM p.1307：150 NM、ATA34_2 p.586：200 NM → FCOM）、FUEL DISAGREE（FCOM：4,080 kg、ATA34_2 p.569：9,000 lb が 5 分 → 量は FCOM、持続時間は要判断）、ND の VNAV 目盛（FCOM ±400 ft、ATA ±420 ft → FCOM）、電源断後の性能データ（FCOM p.1274：再入力、FMSPG p.23：完全復帰 → FCOM）、到着ページの切替（FCOM p.1400 と ATA34_2 p.527 → FCOM）。
- 資料に記載なし：fly-by/fly-over の扱い、通常の旋回のバンクと旋回開始点、ANP の計算式、ECON 速度の CI 依存（FCOM PI に表が無い）、最小機動速度の作り方、VNAV の推力目標の値、CDU と電源 bus の対応、DME-DME の更新式。
- 実機で見ること：ネイティブで STAR・進入を選んだときの `xtlua/fms` の中身、ND の ETA（534 kt の影響）、ベクター中の UNABLE RNP、VNAV 上昇の速度（250/272）、ネイティブの HOLD を入れたときの LNAV の動き。
- 乗員応答監視（PILOT RESPONSE）は APF のオプション（ATA34_2 p.480）。入れるかはユーザーの判断。

## 10. 段階 6-1・6-2 の段取り（2026-10-26）

- 方式：§6.1 の B（経路を自前で持つ）。PLAN.md 6-1 の「自前の経路モデル（段階的に）」のとおり。ネイティブ FMS は、自前の経路の点を流して ND の線を描かせるのと、作り直していない読み手（AP の LNAV・VNAV、ND の地図）のためだけに残す。流し方（`xtlua/fltpln` か `xtlua/loadtoFMS`）は段 5 で確かめる。
- 6-1（FMC）と 6-2（CDU）は 1 本の段取りで進める。CDU のページは FMC のモデルと組で動くので、ページは中身のモデルと同じ段で作る（CDU のノート §8 の進め方を、この表に溶かした）。
- AFDS（6-3）は段 6（LNAV）の後に、A/T（6-4）は段 9（VNAV）と並べて入れる。FMC から FCC への誘導の指令（目標トラックとロール、目標速度、目標パス、A/T のモードの要求）の境界は、AFDS の作り直しで決める（§6.2）。それまでの LNAV・VNAV は、今の AP のしくみ（HDG SEL・FLCH・V/S）に指令を渡す。
- 新しい純粋なモジュールは `plugins/xtlua_keysystems/scripts/B747.68.xt.fms/` に置く（CDU、nav DB、経路、経路の形、LNAV、性能、VNAV など。名前は作るときに決める）。試験は `tests/fms/`。
- どの段の後でも機体は飛べるようにする。古いコードは、置き換えるまで動かしておく。
- 負荷：航法データは、ND の読み方（1 フレームに決まった行数）と同じく分けて読む。JSON の decode は変わったときだけ。ページの描画は文字列を組むだけにし、計算はモデルで行う。
- 表示灯 MSG・DSPY・OFST・FAIL（CDU-22）は 3D に参照が無いので対象外のまま。

| 段 | 内容 | GAP | 主な資料 |
|---|---|---|---|
| 1 | 小修正（局所で害の大きいもの）：空中の THRUST LIM（<GA・<CON・<CRZ を正しく選び、離陸の減格を GA 推力に掛けない）、EMERGENCY REPORT の DIVERT TO で目的地を書き換えない、CRZ CG の検査と描画の保護、APPROACH REF の 4R、VNAV の上昇中に気圧を自動で STD にしない、XTK による UNABLE RNP をやめる（ANP と RNP の比較は段 10）、`xtlua/fms` の decode を変わったときだけにして毎フレームの `collectgarbage` をやめる、ETA の速度の下限、上昇の速度（SPD TRANS の高度より下は SPD TRANS の速度＝制限速度と VREF30+100 の大きい方、上は ECON。CI の表は資料に無いので PI の 340/.84：推定）、SPD RESTR の既定をダッシュに、TRANS ALT を nav DB（`earth_aptmeta.dat`）から、RESET MCP ALT を T/D の 2 分前に、VOR の自動同調の 2 番目の局 | CDU-09, 10, 28, 33；FMC-09, 10, 15, 21, 29（一部）, 30（一部）, 33, 40 | FCOM p.1326, p.1328–1329, p.1337–1340, p.1409–1412, p.1430, p.1433；PI p.316 |
| 2 | CDU の枠組み：CDU ごとの状態（3 台が別々）、キーの規則（CLR の 1 字消しと長押しの全消し、DEL、+/−、メッセージを出している間の打鍵）、メッセージの列（alert と advisory、優先、CLR、条件が消えたら消す）、項目の定義と検査（高度・速度・重量・CRZ ALT の共通の検査、INVALID ENTRY・INVALID DELETE、伏せ字を写さない）、描画（大字と小字、ページ番号、NEXT の循環、`pcall` の保護、ページを変えたときの 0.5 秒の空白をやめる）、電源（表示とキー）と BRT | CDU-01, 05（自前のページ）, 07, 08, 09, 20, 21, 23 | FCOM p.1210–1214, p.1269–1270, p.1430–1436；FMSPG p.39–49 |
| 3 | 地上準備のページ（3a：PERF INIT と INIT REF のキー、3b：THRUST LIM と TAKEOFF REF、3c：APPROACH REF・IDENT・MENU・FLT NO。nav DB に依る IDENT の NAV DATA と POS INIT の REF AIRPORT は段 4、TAKEOFF REF の滑走路は段 5）：IDENT、POS INIT・POS REF、PERF INIT（検査、CI、RESERVES、ZFW と GW を性能に）、THRUST LIM（地上の SEL・減格・CLB の自動の ARM）、TAKEOFF REF（V speeds の計算 → 選択の流れ、選ぶまで NO V SPD、ACCEL HT・E/O ACCEL HT・THR REDUCTION、WIND/SLOPE、PRE-FLT）、APPROACH REF、MENU、INIT REF キーの行き先、FLT NO | CDU-06（一部）, 11, 12, 13, 24, 26, 27（一部）, 28, 29；FMC-24 | FCOM p.1282–1324, p.1409–1412 |
| 4 | nav DB：X-Plane の航法データ（Custom Data を優先）を分けて読む。fix・航法施設・airway・空港（`earth_aptmeta.dat`：位置、標高、遷移高度と遷移レベル）・CIFP（滑走路、SID・STAR・進入、制限）・ホールド（`earth_hold.dat`）。識別子が重なるときの選択（SELECT DESIRED WPT）、版と有効期間（IDENT、NAV DATA OUT OF DATE） | FMC-10（残り）, 32（一部）, 39 | FCOM p.1271, p.1284, p.1433；X-Plane のデータの書式 |
| 5 | 経路モデルと RTE・LEGS・DEP ARR：RTE 1（出発地・目的地・滑走路・airway・direct・discontinuity・120 点）、ACT/MOD/EXEC/ERASE（性能の変更も）、手続き（SID・STAR・進入と transition、高度と速度の制限）、LEGS（並べ替え、削除、direct-to、制限の入力）、EXEC 灯、ネイティブ FMS への写し（ND の線と、作り直していない読み手）、各点の ETA。飛行試験キットの経路の入れ方を CDU の操作に変える | FMC-01（モデル）, 06（一部）, 34（一部）；CDU-02, 03, 04, 05（残り）, 06（RTE・DEP ARR）, 17, 18（一部） | FCOM p.1238, p.1245–1251, p.1285–1301, p.1331–1336；FMSPG 3 章 |
| 6 | 経路の形と LNAV：脚の種類ごとの形（IF・TF・CF・DF・FA・FC・FD・FM・CA・CD・CI・CR・VA・VD・VI・VM・VR・AF・RF・PI・HA・HF・HM）、fly-by の旋回と fly-over、シーケンス（21 NM、重複点）、捕捉（2.5 NM、切込み、NOT ON INTERCEPT HEADING、NO ACTIVE ROUTE）、XTK と誘導の指令、DISCONTINUITY・END OF ROUTE でのヘディングの保持、ND の線を形どおりに | FMC-01, 03, 04, 05, 06, 35；DSP-23（一部） | FCOM p.644–647, p.663, p.1237, p.1245–1249, p.1298, p.1431；ATA34_2 p.615–619, p.626 |
| 7 | ホールド・オフセット・残りの経路の操作：ホールド（形、進入、30° のバンク、出口、EXIT HOLD、HOLD AVAIL・BEST SPEED・EFC、nav DB のホールド）、オフセット（END OF OFFSET、direct-to で解除）、FIX INFO、REF NAV DATA、RTE 2・RTE COPY、ABEAM PTS、INTC CRS、ND のホールドの記号 | FMC-02, 34；CDU-18；DSP-23（一部） | FCOM p.1287–1299, p.1333–1334, p.1413–1419；FMSPG p.164, p.221–227 |
| （6-3） | AFDS：FCC の状態機械、ロールとピッチの則（LNAV の指令を使う）。ATA 22 のノートの段取りで | AFDS-01〜 | notes/ATA-22.md |
| 8 | 性能 DB と予測：FCOM PI の表（PW4056 p.223–324、CF6-80C2B1F p.325–412。LRC の制御・最大運用高度・区間の燃料と時間、降下 .84/290/250、待機、最大上昇 EPR）、ECON の CI（資料に表が無いので推定）、OPT・MAX、ステップ、軌跡の予測（上昇・巡航・アイドル降下・減速・風。上昇の表は資料に無いので推定の模型）、T/C・T/D・E/D・S/C、PROGRESS・RTE DATA、燃料と時刻の予測、点ごとの風と DESCENT FORECAST | FMC-11, 12（計算）, 19, 20, 21, 23, 25；CDU-14（表示）, 15；DSP-23（一部） | FCOM p.1257–1264, p.1272–1274, p.1311, p.1348–1366, p.1371–1378；PI p.268–272, p.316 |
| 9 | VNAV（6-4 の A/T と並べて）：飛行段階（T/C・T/D・approach・flight complete）、高度と速度の制限、パスと許容、VNAV SPD・PTH・ALT、早期降下・DES NOW、MCP の高度と速度のノブ、approach の段階とミスト進入、E/O、RTA、メッセージ | FMC-07, 08, 12, 13, 14, 15, 16, 17, 18, 26, 27；CDU-14 | FCOM p.643–649, p.664–667, p.1253–1269, p.1325–1330, p.1341–1354, p.1383–1408 |
| 10 | 航法センサーと同調（5-1 段 3 を含む）：FMC の位置（IRS の混合、GPS と無線の更新、ANP と RNP、UNABLE RNP、PURGE、GPS NAV INHIBIT、VERIFY POSITION）、VOR・DME・ILS の自動同調（P/R、PARK・A、離陸後 10 分、ILS TUNE INHIBITED）、NAV RADIO のページ、ND の更新の表示、ILS の同調の印 | FMC-28, 29, 30, 31；CDU-16, 27；DSP-14 | FCOM p.1240–1245, p.1303–1307, p.1355–1357, p.1367–1370, p.1430；ATA34_2 p.586, p.601–606 |
| 11 | 燃料の監視・二重系・メッセージの残り：CALCULATED と TOTALIZER（MANUAL・SENSED・USE）、FUEL DISAGREE、INSUFFICIENT FUEL、FMC 2 台（master、故障、FMC LEFT・RIGHT、SINGLE FMC、RESYNC）、代替航法（IRS LEGS・IRS PROGRESS・ALTN NAV RADIO）、CPCS への着陸高度、PROGRESS 2 の XTK と VTK、>FMC MESSAGE を alert だけに | FMC-22, 32, 36, 37, 38；CDU-19 | FCOM p.1273–1275, p.1378–1382, p.1400, p.1421–1436；ATA34_2 p.569, p.589–592 |
| 12 | 残りのページとデータリンク：自動のページ変更、保守のページ、データリンク（109 は KEY/FUNCTION INOP、simconfig で入切）、ATC と会社のデータリンクの残り | CDU-30, 31, 32–42 | FCOM p.725–776, p.1211；FMSPG 8・9 章 |

## 11. 段 1 の実装（2026-10-26：小修正）

- FMC-40：AP の after_physics が毎フレーム `collectgarbage("collect")` を呼び、FMC のデータ（`laminar/B747/fms/data`）と X-Plane の飛行計画（`xtlua/fms`）を毎フレーム decode していた。GC をやめ、文字列が変わったときだけ decode する（AP はファイルの local に持つ。グローバルの表は XTLua が写すので）。FMC の ND の ETA の処理と VNAV ページの decode も、変わったときだけの `fms_route()` に。nav DB（段 4、約 40 MB）を同じ XTLua に置く前に要る（毎フレームの完全な GC がそれも全部たどるため）。
- FMC-21：ETA と T/C の距離の速度の下限が、kt の値に m/s → kt の係数を掛けていた（275 × 1.944 ＝ 534.6 kt、250 × 1.944 ＝ 486 kt）。kt の 275・250 に（推定のまま。予測は段 8）。
- FMC-33：VNAV の上昇中に遷移高度で両席の気圧を STD・29.92 にしていたのをやめた（FCOM p.1329：FMC にこの機能は無い。気圧は乗員が替え、PFD は琥珀の枠を出す：5-2 段 4b）。
- FMC-29：LNAV のクロストラック（目的地の 40 NM 以内で 1 NM、進入中 0.3 NM）で UNABLE RNP の caution を出していたのをやめた。ANP と RNP の比較は段 10。
- FMC-15：RESET MCP ALT を、NM ÷ m/s の比較（約 1 分前）から、時間（NM ÷ kt）で T/D の 2 分前に（FCOM p.665, p.1433）。
- FMC-30：VOR の自動同調の 2 番目の局は、最寄りが替わったときの前の最寄りしか入らなかった。2 番目に近い局に。
- FMC-09：上昇の速度の取り違え。SPD TRANS の高度より下は SPD TRANS の速度（前は ECON SPD の欄の 250）、上は ECON（前は SPD TRANS の 272）。SPD TRANS の速度は、出発地の制限速度（250 kt。nav DB からは段 4）と VREF30 + 100 kt の大きい方（FCOM p.1328：例 272/10000。VREF が VREF30 なのは推定）を FMC が毎フレーム出し、入力はできず削除だけ（削除すると制限なし）。ECON の上昇 CAS は 340 kt（CI の表は資料に無いので、FCOM PI p.316 の通常の上昇速度 340/.84：推定。CI による値は段 8）。上昇から巡航の Mach へ移る判定の CAS も ECON に。
- FMC-10：上昇と降下の SPD RESTR の既定をダッシュに（前は 250/5000 と 180/5000：FCOM p.1328, p.1392）。削除でダッシュに戻る。制限が無いとき、上昇は次の速度へ進み、降下の制限は遷移（SPD TRANS）と同じとして扱う（AP の降下の処理が制限の高度と速度を使うため）。TRANS ALT を nav DB から取るのは段 4。
- 速度の入力の範囲：CAS 130–300 kt を 100–400 kt に（FCOM p.1269–1270。CDU-08 の一部。ECON 340 を入れ直せるように）。
- CDU-10：空中の THRUST LIM の <GA・<CON・<CRZ が TO・TO 1・TO 2 の処理を呼び、CLB と離陸の減格を替えていた（TO 1・TO 2 なら GA 推力が 10・20 % 下がった）。空中では KEY/FUNCTION INOP（GA・CON・CRZ の選択は推力管理 6-4 で）。EEC は離陸の減格を離陸のモード（TO 1・TO 2、地上）でだけ掛ける。
- CDU-33：ATC の EMERGENCY REPORT の DIVERT TO（2L）が `fltdst`（経路の目的地）に入り、X-Plane の FMS へ送っていた。自分の値（`acarsEMERDIVERT`、15 字まで）にし、無ければ目的地を出す（FCOM p.729）。削除で目的地に戻る。経路は変わらない。
- CDU-09：CRZ CG に数でない文字が入り、PERF INIT の描画が `string.format` の nil で止まっていた。8.5–33.0 % に（FCOM p.1311）、削除で既定の 20.0（小さい字）。
- CDU-28：APPROACH REF の FLAP/SPEED：空の scratchpad で 4R を押すと VREF が消えていた。値を写す。入力は XX/YYY・/YYY・YYY（フラップは 25 か 30。フラップの無い入力は前の値か 30：推定）、削除で VREF を PFD から消す（FCOM p.1412）。既定はダッシュ（--/---：FCOM p.1410–1411 の図。前はボックス）。
- 試験：`tests/fms/fmc_fixes_test.lua`（41 件：FMS のモジュールを XTLua のモックで動かし、CLB・DES ページ、THRUST LIM、APPROACH REF、CRZ CG、DIVERT TO を CDU のキーで確かめる。直す前のコードでは CRZ CG の入力で描画が止まった）。全体 92 本。X-Plane の `s79_fmc_fixes`（31 件合格：銚子沖の空中で、CLB ページの ECON SPD 340、SPD TRANS 252/10000（VREF30 152＋100）で入力は INVALID ENTRY・削除でダッシュ、SPD RESTR は上昇・降下ともダッシュ、空中の THRUST LIM の <GA は KEY/FUNCTION INOP で離陸の減格はそのまま、APPROACH REF の /150・25/155・空の scratchpad での複写・削除、CRZ CG の A と 40 は INVALID ENTRY で 25.5 と削除の 20.0、DIVERT TO は経路の目的地（fltdst）を書き換えない、VOR の自動同調は L 117.90（48 NM）・R 113.30（59 NM）、現用点まで 33.3 NM・GS 278 kt の ETA は 0308.9z（GS どおり。前の下限 534.6 kt なら 0305.5z）。Lua の誤りなし。CDU を撮った）。

## 12. 段 2 の実装（2026-10-26：CDU の枠組み）

- 新しい純粋なモジュール `B747.68.cdu_model.lua`（CDU のノート §3.1・§3.2・§4.1）：
  - scratchpad：24 字まで、左から入る。メッセージが出ている間は打鍵を受け付けない（FMSPG p.39, p.41）。+/- は 1 回目が -、続けて押すと + と - を交互に（FCOM p.1212）。CLR は出ているメッセージ、無ければ最後の 1 字。1 秒押し続けると全部（FCOM p.1213; FMSPG p.43）。DEL は空でメッセージの無いときだけ DELETE（FCOM p.1213）。前は CLR が全部消し、DEL が 1 字消し、+/- はいつも -、メッセージの下に打鍵が溜まった（CDU-01）。
  - メッセージ：CDU ごとの入力のメッセージ（INVALID ENTRY など）と、FMC の全 CDU に出るメッセージ。FMC のメッセージはどの CDU の CLR でも全部から消える（FMSPG p.39）。条件のメッセージは条件が消えると消え、CLR で消したものは条件がもう一度起きるまで出ない（FCOM p.1430）。alert があれば >FMC MESSAGE（FCOM p.1429）、どれかのメッセージがあれば MSG（灯は 3D に無い：CDU-22）。表示の順は、その CDU の入力のメッセージ、alert、advisory、それぞれ来た順（推定：FCOM は「重要度の順」としか書かない）。
  - 入力の形（段 3 からのページで使う）：高度（XXX、XXXX は 9,994 ft まで、XXXXX、FLXXX、10 ft に丸め、-1,000 ft まで。遷移高度までは ft、上は FL：FCOM p.1269–1270）、速度（CAS 3 桁、Mach は小数点と 1–3 桁）、対の値（内側だけなら / が要る）、重量（XXX・XXX.X）、整数。
- 組み込み（`B744.createfms.lua`）：キーを `keyDown` の新しい入口で受け、自前のページでは scratchpad のキー（英数字・/・.・SP・+/-・DEL・CLR）をモデルに、それ以外（機能キー・LSK・NEXT・PREV・EXEC と X-Plane のページのキー）を前の振り分けに渡す。ページが立てた `notify` は、その CDU の入力のメッセージに移す（ページの描画中に立てたものも）。X-Plane の CDU の scratchpad のメッセージ（RTE・LEGS の入力）もその CDU のメッセージに。CLR は押した瞬間と押し続け（1 秒）の両方を受ける（前は押した瞬間だけ）。
- FMC のメッセージ（`laminar/B747/fms/notification` の旗、B744.notifications.lua + 1）：毎フレーム写す（前は 10 秒ごとに最初の 1 件を 3 台の notify に入れ、CLR は旗を 0 に戻した）。旗は各系統が条件の間だけ立てる。一度だけ立てる出来事（PERF/VNAV UNAVAILABLE、DESTINATION NOT SET、TAKEOFF SPEEDS DELETED）は、写したら旗を 0 に戻して次も出るように。TAKEOFF SPEEDS DELETED は advisory、ほかは alert（FCOM p.1431–1435）。名前を FCOM に（DISCONTINUITY、FUEL DISAGREE - PROG 2、ILS TUNE INHIBITED - MCP、PURGE UPDATES - POS 2、RESYNC FAIL - SINGLE FMC、VERIFY RNP - POS REF 2）。
- ページの切替：自前のページはすぐ切り替える（前は 0.5 秒、3 台とも画面全体が空白：CDU-23）。X-Plane のページは前のとおり 0.5 秒待つ。NEXT は最後のページから 1 ページ目へ（FMSPG p.42）。
- 描画：ページの描画を `pcall` で守り、誤りはページを空白にして Log.txt に 1 回だけ（CDU-09 の類が全体を止めないように）。
- 電源：左の CDU は main standby bus、右は F/O transfer bus（FCOM p.800, p.804）、中央は F/O transfer bus（推定）。`electrical/display_has_power[8]`・`[7]`・`[6]`（パネルの画面と同じ）。電源の無い CDU はキーを受けず描かず、電源が戻ると MENU（FMSPG p.53。CDU-20 の一部）。
- 試験：`tests/fms/cdu_model_test.lua`（80 件：モデル）、`tests/fms/cdu_framework_test.lua`（33 件：FMS のモジュールで、キー、メッセージ、FMC のメッセージ、NEXT、電源、即時のページ切替）。`tests/displays/cdu_efis_test.lua` は CDU の電源を入れるように。全体 92 本。X-Plane の `s80_cdu_framework`（28 件合格：銚子沖の空中で、MENU が 0.2 秒で出る（前は 0.5 秒の空白）、CLR は 1 字（FL35 → FL3）、1.5 秒の押し続けで全部、+/- の 2 回目で 1+、データがあると DEL は効かない、空で DELETE、INVALID ENTRY は左の CDU だけで、その間の打鍵は入らず CLR で scratchpad の A に戻る、RESET MCP ALT の旗で左右の CDU に出て >FMC MESSAGE、右の CDU の CLR で両方から消え 11 秒たっても再び出ない、PERF/VNAV UNAVAILABLE の旗は写したら 0 に戻る、VNAV の 3 ページ目の NEXT で CLB へ、STANDBY POWER の OFF で左の CDU の電源が切れてキーが効かず、AUTO に戻すと MENU。Lua の誤りなし。CDU を撮った）。
- 手直し（2026-10-26 午後）：X-Plane の CDU の scratchpad（独自のページで RTE などの入力を X-Plane の CDU に打ち込む `custom2fmc`・`key2fmc` の結果）をこの CDU のメッセージにするのは、FMC が打ち込んだキー（DEL・CLR・文字・行選択キー）が入り終わった後（キーの数 + 5 フレームかつ 0.3 秒）で、打ち込んだ文字そのものでないときだけにした。X-Plane の scratchpad は空でも角括弧が付く（「[　　　]」）ので、角括弧ではメッセージと打ち込み中の文字を区別できない。段 2 ではメッセージの間は打鍵を受けないので、打ち込み中の文字がメッセージになると次の入力が入らなかった（`s14_press_ground` で出発地の入力が入らず 1〜3 件失敗。前は文字を出すだけで打鍵を止めなかった）。

## 13. 段 3a の実装（2026-10-26：PERF INIT と INIT REF のキー）

- 段 3 は 3 つに分けた：3a（PERF INIT と INIT REF のキー）、3b（THRUST LIM と TAKEOFF REF：V speeds の計算 → 選択の流れ）、3c（APPROACH REF・IDENT・MENU・FLT NO）。nav DB に依る IDENT の NAV DATA と POS INIT の REF AIRPORT は段 4、TAKEOFF REF の滑走路と POS SHIFT は段 5。
- PERF INIT（FCOM p.1307–1312）：
  - GR WT か ZFW のどちらかを入れ、もう一方は FUEL の行から出る。入れた GR WT は、そのときの FUEL を引いた ZFW として持つので、燃料が減ると GR WT も減る。入れた方を大きい字、出した方を小さい字（推定：計算値は小さい字の決まりから）。前は描画のたびに FMC のデータを書き換え、`"***.*"` の型の文字のパターンで判定していた。
  - FUEL：トータライザーの値（CALC）か入力（MANUAL。削除で CALC に戻る、CALC は削除できない：FCOM p.1310）。SENSED は使わない。
  - 重量の入力は XXX・XXX.X（表示の単位の千）、範囲は ZFW 130–270 t・GR WT 150–400 t・FUEL と RESERVES 180 t まで（推定：最大地上走行重量 397 t、最大零燃料重量 243 t、燃料 約 174 t）。GR WT・ZFW・RESERVES・COST INDEX・CRZ ALT の削除は INVALID DELETE。
  - COST INDEX：0–9999（FCOM p.1311）。空中で T/D の 10 NM 以内は INVALID ENTRY（FMSPG p.97）。
  - CRZ ALT：入力の形（XXX・XXXX・XXXXX・FLXXX）で、最大認定高度 45,100 ft を超えると INVALID ENTRY、地上では機体より上（FMSPG p.97）、空中の PERF INIT ではボックスのときだけ（変えるのは CLB・CRZ ページ）。MAX ALT FLXXX（性能の上限を超えるとき）は段 8。FMC が持つ（`autopilot/dist/cruise_alt`）：前は左の CDU のキーで X-Plane の FMS の VNAV ページに打ち込み、0.5 秒後に読み戻していた（CDU-02 の一部）。MCP の高度ノブなどで巡航高度が変わると、表示（ft か FL）をそこから作る。
  - 表示：109 は「GR WT」（405 の WBS の「GR WT ADV」と `<` は使わない）、FUEL の値と CALC/MANUAL、6 行目の破線。
- INIT REF のキー（FCOM p.1285, p.1308, p.1409）：IRU が ATT か、地上で IRS の位置がまだなら POS INIT、地上で位置が入っていれば PERF INIT、空中は APPROACH REF（前はいつも INIT/REF INDEX：CDU-06 の一部）。INIT/REF INDEX は各ページの <INDEX から。
- 試験：`tests/fms/perf_init_test.lua`（29 件：INIT REF のキー、GR WT と ZFW、燃料の消費、FUEL の MANUAL と削除、RESERVES、COST INDEX、CRZ ALT と MCP からの変更、空中の制限、ポンドの表示）。段 1・2 の試験とシナリオは、INIT REF の後に <INDEX を押すように。`s79_fmc_fixes` の scratchpad を空にする CLR は押し続けに（段 2 から CLR は 1 字消しなので、段 2 の後の s79 は 6 件失敗した）。X-Plane：`s81_perf_init` 16 件合格（RJAA 34L の地上で、INIT REF で PERF INIT、ZFW 220.0 で GR WT 306.5（燃料 86.5）が小さい字、GR WT 330.0 で ZFW 243.5、FUEL 95.0 MANUAL と削除で CALC、RESERVES 12.5、COST INDEX 120、CRZ ALT 460 は INVALID ENTRY、FL350 で FMC の巡航高度 35,000 ft と CLB ページ）、`s79_fmc_fixes` 31 件合格（INIT REF の後の <INDEX と CLR の押し続けに直して。直す前は 6 件失敗）、`s80_cdu_framework` 28 件合格。Lua の誤りなし。CDU を撮った。

## 14. 段 3b-1 の実装（2026-10-26：TAKEOFF REF の V speeds）

- 段 3b は 2 つに分けた：3b-1（V speeds の計算 → 選択の流れ）、3b-2（THRUST LIM の地上と TAKEOFF REF のほかの欄）。
- 計算（計器のモジュール `B747.60.xt.fltInst02.lua`）：新しい dataref `airspeed/V1_ref`・`Vr_ref`・`V2_ref` に、TAKEOFF REF のフラップ（10 か 20）、FMC の重量（PERF INIT の GR WT。`laminar/B747/fms/data` の `grwt`）、温度と高度の領域、TAKEOFF REF の風（`towind`。入れるまで無風）から出す。フラップか重量が無いとき、IRU が 1 台も整列していないときは 999（ダッシュ：FCOM p.1319）。前は機体の真の重量と X-Plane の風で、フラップを入れたときだけ直接 PFD の V1・VR・V2 に書いていた。V1 の風の補正は、表の重量と向かい風の間を両方向に内挿（前は全風速で内挿し、重量の下と上の列を取り違えていた）。V1 は VR を超えない（推定）。
- 選択（FMC の `B744.fms.pages.takeoff.lua`）：計算値は小さい字で見出しが REF V1 と >（FCOM p.1319）。R1〜R3 を空の scratchpad で押すと選び、数を入れると（100–300 kt：FMSPG p.107）乗員の値、どちらも大きい字で見出しの REF が消え、PFD の V1・VR・V2 に出る（選ぶまでは 999：NO V SPD）。DELETE で計算値に戻る。
- 削除（FCOM p.1309–1310, p.1319–1320）：選んだ後にフラップ・GR WT・ZFW を入れると、選んだ速度を消して TAKEOFF SPEEDS DELETED（FMC の advisory として全 CDU に。`laminar/B747/fms/notification` の出来事の旗）。3 発目の始動の後は、計算値が選んだときから 1 kt を超えて変わると同じく消す。GR WT・ZFW の入力はフラップを残す（前はフラップを 0 にしていた）。1,000 ft を超えると（計器のモジュールがフラップを 0 にする）、選んだ速度は黙って消える（前と同じく飛行中は出さない）。
- 試験：`tests/fms/takeoff_speeds_test.lua`（22 件：計器と FMS の 2 つのモジュールを XTLua のモックで動かし、計算値、選択、入力、削除、3 発目の始動の後の変化、IRU の整列）。X-Plane：`s82_takeoff_speeds` 14/14（RJAA の地上で、フラップが無いと計算値は 999、フラップ 10 で計算値 V1 130 が小さい字で > つき、選ぶまで PFD は NO V SPD、R1〜R3 で選ぶと PFD に V1 130・V2 165、見出しの REF が消え、フラップ 20 で TAKEOFF SPEEDS DELETED と PFD の V1 が消える）。Lua の誤りなし。CDU と PFD を撮った。

## 15. 段 3b-2 の実装（2026-10-26：THRUST LIM の地上と TAKEOFF REF の欄）

- THRUST LIM（地上、FCOM p.1314–1316）：SEL は 0–99 °C（XX・XXC）か 32–210 °F（XXF・XXXF）、°C で持ち、°F で入れると OAT も °F（前は検査なし）。SEL は大きい字、OAT と離陸の EPR/N1 は小さい字。EPR/N1 の行は表示だけ（前は入力できた）。選んだ後に SEL か離陸の定格（TO・TO 1・TO 2）を替えると、選んだ V speeds を消して TAKEOFF SPEEDS DELETED（FCOM p.1314–1315）。仮定温度による推力の減少と「D」の表示は推力管理（6-4）で（EEC の仮定温度の処理はコメントアウトされたまま）。
- TAKEOFF REF（FCOM p.1318–1321）：
  - FLAP/ACCEL HT：XX（10 か 20）、/YYYY（空港上 400–9999 ft）、XX/YYYY。新しいフラップは選んだ速度を消す。
  - E/O ACCEL HT：400–9999 ft。THR REDUCTION：5（FLAPS 5）か 400–9999 ft、後ろに ARM の上昇の定格。既定は ACCEL HT・E/O ACCEL HT が 1000 ft、THR REDUCTION が FLAPS 5（FCOM の図。小さい字）、入れると大きい字。削除で既定に（推定）。値は VNAV（段 9）と推力管理（6-4）で使う。
  - WIND/SLOPE：HXX・XX（向かい風）・TXX と UX.X・X.X（上り）・DX.X（0.0–2.0：FMSPG p.106）。入れるまでダッシュ（「乗員の入力の後に出す」：FCOM p.1319）。風は V1 の計算に入る。替えると選んだ速度を消す（性能データの変化）。
  - TRIM/CG：整数 0–40 % MAC（109）、トリムを出す（前は PAX/CARGO のページで CG が出た後でしか入らなかった）。削除でダッシュ。
  - POS SHIFT：±X・XX（100 m 単位、109）。滑走路は経路の段 5 で（今は RW***）。TO/GA で位置を移すのは段 10。
  - PRE-FLT：POS INIT（IRS の位置）、ROUTE（出発地と目的地）、PERF INIT（GR WT、CRZ ALT、COST INDEX、RESERVES）の最初の未了のページを見出し PRE-FLT と 6R に出し、押すとそのページへ。終わっていれば破線と THRUST LIM>（前は POS INIT> の固定）。
- 試験：`tests/fms/takeoff_ref_test.lua`（37 件）。X-Plane：`s83_takeoff_ref` 18/18（RJAA の地上で、THRUST LIM の SEL 26°C と 75°F（OAT も °F）と削除、TAKEOFF REF の既定 1000FT・FLAPS 5（小さい字）、10/1500・E/O ACCEL HT 1200・THR REDUCTION 1500、WIND/SLOPE H40/U1.0 で V1 の計算値が 130 から 134、CG 25 でトリム 4.8、POS SHIFT +0300M、PRE-FLT の ROUTE> で RTE へ。1 回目は SEL の空白の確かめ方の誤り（空白 24 文字の行を "" と比べた）で 17/18、直して流し直した）。Lua の誤りなし。CDU を撮った。

## 16. 段 3c の実装（2026-10-26：MENU の <FMC と FLT NO）

- 段 3c は小さくした。APPROACH REF の GROSS WT と滑走路は到着の滑走路が要るので経路（段 5）と、IDENT の NAV DATA と ACTIVE の入れ替えは nav DB（段 4）と一緒にする。
- MENU の <FMC（FCOM p.1323）：その CDU で最後に出ていた FMC のページへ、最初は IDENT（前は常に IDENT）。FMC のページかどうかは、最後の MENU の後に FMC の機能キー（INIT REF・RTE・DEP ARR・ATC・VNAV・FIX・LEGS・HOLD・FMC COMM・PROG・NAV RAD）か <FMC を押したかで決める（ACARS・ACMS・CMC・EFIS/EICAS CP・シムのページを挟んでも、戻るのは FMC のページ）。X-Plane の CDU を使うページ（RTE・LEGS・DEP ARR・FIX・HOLD）は、X-Plane の CDU も合わせるためにそのキーで戻す（1 ページ目）。
- FLT NO（RTE 1 ページ。ATC LOGON/STATUS と ACARS の INITIALIZE も同じ欄）：1〜8 文字の英数字、DELETE は INVALID DELETE（FMSPG p.79, p.278）。FMC の便名（`laminar/B747/fms/data` の `fltno`）になり、ACARS・ATC のログオン・PROGRESS が使う（FCOM p.1289；LH3460 p.85。前は RTE ページの入力を X-Plane の RTE ページに送るだけで、表示も X-Plane の行の末尾 7 文字：CDU-29）。RTE ページは FMC の便名を右寄せで出す。9 文字以上は前は 3 文字に切られていた。
- PROGRESS の 1・2 ページの題名に便名（「TBC12345 PROGRESS」：FCOM p.1371, p.1374, p.1376）。便名が無いときは今までの題名。
- 便名が電源投入と飛行の終わりで消えること（ATA34_2 p.521）は、飛行の終わりの処理（段 10）で。
- 試験：`tests/fms/menu_fltno_test.lua`（26 件）。X-Plane：`s84_menu_fltno` 13/13（RJAA の地上で、最初の <FMC は IDENT、INIT REF → PERF INIT → THRUST LIM の後の MENU → <FMC は THRUST LIM、ACMS を挟んでも THRUST LIM、右の CDU は IDENT から。RTE の FLT NO JL123 が FMC の便名になって右寄せで出る、9 文字は INVALID ENTRY、DELETE は INVALID DELETE、PROGRESS の題名に JL123）。Lua の誤りなし。CDU を撮った（RTE ページの下の行には X-Plane の RTE ページの行がまだ透けて出て、そこにも FLT NO の欄がある：段 5b で RTE を自前にして消える）。

## 17. 段 4 の実装（2026-10-26：航法データベース）

- 新しい純粋なモジュール `B747.68.navdb.lua`：X-Plane の航法データの書式（`earth_aptmeta.dat`・`earth_nav.dat`・`earth_fix.dat`・`earth_awy.dat`・`earth_hold.dat`、空港ごとの `CIFP/<ICAO>.dat`）を、1 回に決まったバイト数ずつ読む（`load`）。空港（位置・標高・遷移高度と遷移レベル）、VOR・NDB・DME・ILS・LOC（周波数・標高・範囲・偏差・名前、ILS のグライドスロープ）、fix（エンルートは識別子で、ターミナルは空港ごと）、airway（区間と経路の点の列）、ホールド、CIFP（滑走路と手続き：手続きの脚は段 5 で読む）。識別子が重なるときは近い順に返す（SELECT DESIRED WPT は経路の入力の段 5 で）。周期：ファイルの見出しの AIRAC 周期から、AIRAC 2001（2020-01-02）からの 28 日ごとで初日と最終日（FCOM p.1271, p.1284）。
- FMS のモジュール：Custom Data に航法データがあればそれ（Navigraph の周期）、無ければ X-Plane の既定のデータ（`Resources/default data`）。1 フレームに 32 KB（この PC の Custom Data で約 850 フレーム、1 回の平均 0.6 ms 程度。読み終わるまでは航法データを要る入力に STANDBY ONE）。航法データのライセンスにより、リポジトリには合成の試験データ（`tests/fms/data/navdb`）だけを置く。
- IDENT（FCOM p.1283–1284）：NAV DATA に周期（「AIRAC 2610」：データに部品番号が無いので推定）、ACTIVE に周期の初日と次の周期の初日（「OCT01OCT29/26」。前は X-Plane の IDENT ページの文字から）。データは 1 組なので、2 つ目の期間の行は空（推定）。DRAG/FF を 3 行目、CO DATA を 5 行目に（前は 5 行目に並べていた）。
- NAV DATA OUT OF DATE（FMC の alert：FCOM p.1433）：時計の日付（機長の時計、切れていれば副操縦士の時計：FCOM p.1285）が周期の最終日を過ぎると。`laminar/B747/fms/notification` の 55 番目（FCOM の表に合わせて追加）。CLR で全 CDU から消え、条件が続く間は再び出ない。X-Plane の CDU 自身の NAV DATA OUT OF DATE は今までどおり黙って消す。
- POS INIT の REF AIRPORT（FCOM p.1285）：航法データの空港の ICAO 4 文字、その位置を行に出す（前は ND の航法施設の一覧から引き、無くても受け付けた）。無い空港は NOT IN DATA BASE、4 文字の英字でなければ INVALID ENTRY。DELETE で GATE も消す（前は REF AIRPORT に GATE の既定を入れていた）。離陸で REF AIRPORT と GATE を消す（FCOM p.1285–1286）。
- CLB ページの TRANS ALT（FCOM p.1329）：ORIGIN を入れると、その空港の遷移高度（`earth_aptmeta.dat`）、無ければ 18,000 ft（前は 18,000 固定：FMC-10 の残り）。乗員の入力は今までどおり。遷移レベル（DESCENT FORECAST、FCOM p.1396：到着の手続きか FL180）は DESCENT FORECAST のページ（段 8）と到着の手続き（段 5）で。
- 試験：`tests/fms/navdb_test.lua`（モジュール：合成のデータと、この PC にあれば本物のデータ）、`tests/fms/navdb_fmc_test.lua`（32 件：FMS のモジュールを XTLua のモックで）。X-Plane：`s85_navdb` 22/22（RJAA の地上で、航法データ（Custom Data の AIRAC 2610）を IDENT を開いてから 6.5 秒以内に読み終え、NAV DATA AIRAC 2610 と ACTIVE OCT01OCT29/26、日付を 11 月にすると NAV DATA OUT OF DATE と >FMC MESSAGE（両方の CDU）、CLR で全部から消え、10 月に戻すと条件が消える、ORIGIN RJAA で TRANS ALT 14000（CLB ページにも）、IRS を入れ直したアライン中に REF AIRPORT の ZZZZ は NOT IN DATA BASE、RJAA は N35°45.9 E140°23.1）。Lua の誤りなし。CDU を撮った。

## 18. 段 5 の段取り（2026-10-26：経路モデルと RTE・LEGS・DEP ARR）

- 段 5 は 6 つに分ける。どの小段の後でも、今の読み手（AFDS の LNAV・VNAV、ND の地図、ETA）が X-Plane の FMS の経路で動くように、FMC の経路を `xtlua/loadtoFMS`（X-Plane の .fms の書式の文字列。XTLua は XPLMLoadFMSFlightPlan で読み込ませる）で流し込む。

| 小段 | 中身 | 主な資料 |
|---|---|---|
| 5a | 経路のモデル（新しい純粋なモジュール）：RTE 1 の出発地・目的地・出発滑走路、区間（VIA：DIRECT・airway、TO：点）、airway の展開、airway の交点、discontinuity、120 点（ROUTE FULL）、ACT と MOD（EXEC・ERASE）、ACTIVATE、点の候補（SELECT DESIRED WPT）、X-Plane の .fms の書式 | FCOM p.1238, p.1287–1298, p.1335, p.1435；FMSPG p.79–91 |
| 5b | RTE のページ：1 ページ目（ORIGIN・DEST・RUNWAY・FLT NO・CO ROUTE・ACTIVATE>/PERF INIT>/TAKEOFF>）、2 ページ目以降（VIA/TO を 5 組ずつ）、題名（RTE 1・ACT RTE 1・MOD RTE 1）、6L の ERASE、SELECT DESIRED WPT のページ、X-Plane の FMS への流し込み。X-Plane の RTE ページの透かしをやめる | FCOM p.1287–1298, p.1335 |
| 5c | RTE LEGS のページ：点・針路・距離・制限（大字）、削除・挿入・並べ替え・discontinuity をつなぐ、direct-to と INTC CRS、ABEAM PTS、制限の入力（A・B・窓）、PLAN の CTR と STEP。予測（小字）は段 8 | FCOM p.1331–1334 |
| 5d | CIFP の手続き：SID・STAR・進入と transition の脚（種類・高度と速度の制限・fly-over・針路・距離）。DEP/ARR INDEX・DEPARTURES・ARRIVALS のページ（選択 → MOD）、DEP ARR キーの行き先 | FCOM p.1299–1303, p.1343, p.1400–1405 |
| 5e | X-Plane の FMS への流し込みの確かめ：手続きの点、条件点、AFDS の現用点（`xtlua/currentFMSID`）との整合、ND の線と出発・到着の滑走路、各点の ETA | X-Plane の .fms 書式（v1100） |
| 5f | 飛行試験キット：経路の入れ方を CDU の操作に（`B747_route.lua` は残す）、シナリオの経路の見直し | TESTING.md |

- 手続きの脚の形（旋回、条件点）と LNAV の誘導は段 6、ホールドと RTE 2 は段 7、予測（小字の速度と高度、RTE DATA）は段 8。
- 順序：5b は 5e の流し込みと一緒に入れる（RTE を FMC のものにすると、X-Plane の FMS へは流し込みでしか経路が入らない）。5d までは X-Plane の DEP ARR のページ（X-Plane の FMS に直接入る）が残り、そこで選んだ手続きは FMC の経路が次に変わると上書きされる（暫定）。
- EXEC 灯：3D の物体（`Cockpit_Pedestal1.obj` の `ATTR_light_level`）は X-Plane の `sim/cockpit2/radios/indicators/fms_exec_light_pilot`・`_copilot` を見ていて、これは書き込めない（DataRefs.txt）。FMC の MOD に合わせて灯すには 3D の物体の変更が要る（3D は対象外なので利用者に確かめる：PROGRESS.md「利用者に確かめたいこと」）。それまでは CDU の題名の MOD と 6L の ERASE で示す。→ 2026-10-27 に利用者の承認で作り直した（§25）。
- CO ROUTE：会社の経路の DB が無いので、入力は NOT IN DATA BASE（FCOM p.1290：名前が DB に無ければその旨を出す）。

## 19. 段 5a の実装（2026-10-26：経路のモデル）

- 新しい純粋なモジュール `B747.68.route_model.lua`（まだ機体からは読まない：5b で使う）。経路は脚の列で持つ：`{via, fix}`（via は DIRECT・airway・手続きの名前、fix は nav DB の点）、`{via, pending}`（TO の無い airway：RTE ページの箱）、`{disc}`（ROUTE DISCONTINUITY：FMSPG p.91）。RTE ページの区間（ATC の形）は脚から作る（同じ airway・手続きの続く脚、DIRECT の各脚、discontinuity）。
- RTE 1 ページ目：ORIGIN（nav DB の空港。地上で新しい出発地は経路を消す：FCOM p.1288。目的地も消す：前の FMC の動きのまま、推定）、DEST、RUNWAY（出発地の CIFP の滑走路、16R・RW16R の形：FCOM p.1289）。
- 区間（FCOM p.1296–1298；FMSPG p.82–83）：終わりのダッシュの TO は DIRECT、VIA の airway は前の TO を含むこと（含まなければ INVALID ENTRY、DB に無ければ NOT IN DATA BASE）、その TO（箱）は airway 上の点で、間の点を脚に展開（一方通行は逆に入らない）。TO の無い airway の次に airway を入れると、2 本の交わる点を前の airway の TO にする（INTC）。最初の VIA の airway（前の TO が無い：airway intercept）はまだ作らず INVALID ENTRY（推定）。120 点を超える変更は ROUTE FULL で入れない（FCOM p.1435）。
- ACT と MOD（FCOM p.1238, p.1290）：非アクティブの経路は直接変わる。ACTIVATE（出発地と目的地のあるとき：推定）と EXEC でアクティブ。アクティブの経路への変更は MOD（写し）に入り、EXEC で反映、ERASE で取り消し。題名の ACT・MOD。
- 点の候補（SELECT DESIRED WPT：FCOM p.1335）：同じ識別子の点・航法施設・空港と、出発地・目的地のターミナルの点を、指定の位置から近い順に（nav DB の `find`）。
- X-Plane の .fms（v1100）の書式：出発地・目的地は空港（1）、各点は位置で fix（11）・NDB（2）・VOR/DME（3）、via は DRCT か airway。手続きの見出しは書かない（FMC 自身の脚：X-Plane に自分の手続きを展開させない）。
- 試験：`tests/fms/route_model_test.lua`（63 件：合成のデータの airway Z1・Z2）。X-Plane では未使用（5b で）。

## 20. 段 5b・5c の実装（2026-10-26：RTE と LEGS のページ、X-Plane の FMS への流し込み）

- 5b と 5c は 1 つにまとめた（どちらも経路のモデルのページで、RTE を自前にすると LEGS も X-Plane のページを透かせない）。
- RTE のページ（`activepages/B744.fms.pages.rte.lua`、FCOM p.1287–1298）：1 ページ目は ORIGIN・DEST（箱）、RUNWAY、FLT NO、CO ROUTE（会社の経路の DB が無いので NOT IN DATA BASE）、6R は ACTIVATE>（非アクティブの間。押しても EXEC までは残る）、PERF INIT>（性能データが未完。TAKEOFF REF の PRE-FLT と同じ判定）、TAKEOFF>（FCOM p.1290）。2 ページ目以降は VIA と TO を 5 組ずつ、終わりにダッシュ、TO の無い airway に箱、discontinuity に箱。入力は終わりのダッシュと箱だけ（ほかの行の変更は LEGS で：推定）、空の scratchpad で行の識別子を写す（airway は VIA から：FMSPG p.82）。題名は RTE 1・ACT RTE 1・MOD RTE 1、MOD のとき 6L に ERASE（FCOM p.1238）。前は X-Plane の RTE ページの行を透かし、下の行に X-Plane の FLT NO の欄が出ていた。
- TAKEOFF REF の PRE-FLT の ROUTE は、RTE 1 をアクティブにするまで出す（FCOM p.1290：アクティブ化で経路の準備が終わる。前は ORIGIN と DEST が入っていれば済）。POS SHIFT の滑走路は RTE 1 の出発滑走路（FCOM p.1321。選ぶまでは RW***）。
- SELECT DESIRED WPT（FCOM p.1335）：同じ識別子が 2 つ以上なら、前の点から近い順に識別子・種類・周波数・位置を出し、選ぶと元のページの入力を終える。機能キーで選ばずに抜ける。題名は中央で、1 ページならページ番号を出さない（FCOM の図）。
- airway の交点の点の名前を X＋2 本目の airway 名にした（FCOM p.1250：J70 の後に J52 で XJ52。段 5a では交わる点の名前だった）。
- RTE LEGS のページ（`activepages/B744.fms.pages.legs.lua`、FCOM p.1330–1334）：5 点ずつ。見出しの行に前の点からの針路（磁方位：nav DB の近くの VOR の偏差、無ければ真方位に T：推定）と距離（アクティブな経路の最初の点は機体から）、点の行に識別子と速度・高度の制限（大字。予測の小字は段 8）。discontinuity は THEN と箱、次の点の見出しが「-- ROUTE DISCONTINUITY -」（FCOM p.1333）、終わりにダッシュ。
- LEGS の入力（FMSPG p.82, p.91, p.125–128, p.141–144；資料に無い規則は推定）：経路の先にある点を入れると、その間の点が消えて直行。無い点は挿入され、その後に ROUTE DISCONTINUITY。箱に次の点を入れると閉じる。DELETE は前後をつなぐ（推定。空中のアクティブな点は INVALID DELETE、discontinuity は消せない）。アクティブな経路の最初の行への入力は DIRECT TO（MOD）で、6R に INTC CRS（経路上の点なら経路のコースと >、無ければ箱：FMSPG p.144）。速度・高度の制限は右の LSK に「XXX/」「XXX/高度」「/高度」「高度」（A・B、窓は 220A240B）、速度は CAS 100–400 kt、速度だけは高度の制限の上だけ、CRZ ALT 未満、新しい制限で古い速度は消える、DELETE は両方を消す。
- まだ無いもの：RTE 2・RTE COPY（段 7）、RTE DATA（段 8）、ABEAM PTS、PLAN の CTR と STEP（5e）、LEGS の予測（段 8）、点の種類の増え（PBD、緯経度など：FMSPG p.82–83、5e 以降）。
- X-Plane の FMS への流し込み：RTE 1（アクティブなら EXEC 後の経路、MOD は入れない）が変わると、X-Plane の .fms（v1100）の文字列を `xtlua/loadtoFMS` に書く（XTLua が XPLMLoadFMSFlightPlan で読み込ませる）。出発の滑走路は出発地の次に、名前のついた位置の点（閾値、高度は閾値の標高）として書く（X-Plane の DEP ARR が入れるのと同じ形で、ND はそこで出発の滑走路を見つける）。目的地が入るまでは流さない（X-Plane は目的地の無い飛行計画を受け付けず、画面にエラーを出す：X-Plane での試験で見つけた）。X-Plane の FMS は ND の線と、作り直していない読み手（AFDS の LNAV・VNAV）のため。FMC のデータの `fltdep`・`fltdst`・`runway` も合わせ、新しい出発地で TRANS ALT（FCOM p.1329）。RTE と LEGS のキー、ほかのページから RTE へ行くプロンプト（POS INIT と TAKEOFF REF の ROUTE>、FMC COMM の L1）は、もう X-Plane のキーを押さない。X-Plane の DEP ARR のページ（段 5d まで）で選んだ手続きは X-Plane の FMS にだけ入り、FMC の経路が次に変わると上書きされる。
- EXEC 灯は FMC の MOD に合わせられない（§18）。→ §25 で作り直した。
- 試験：`tests/fms/route_model_test.lua`（101 件）、`rte_pages_test.lua`（52 件）、`legs_pages_test.lua`（40 件）。X-Plane：`s86_rte_pages` 18/18（ORIGIN RJAA・DEST RJBB・RUNWAY 34L、DIRECT SPENS、Y71 で XAC、AKAGI の SELECT DESIRED WPT、ACTIVATE と EXEC、X-Plane の FMS の RTE に RJAA と RJBB、ND が出発滑走路 34L を見つける）、`s87_legs_pages` 21/21、RTE ページに入力する `s14` 66/66・`s83` 18/18・`s84` 13/13・`s85` 22/22。CDU と ND の写真（RTE の 1・2 ページ、SELECT DESIRED WPT、LEGS の discontinuity と DIRECT TO、ND の経路と出発滑走路）。目的地の前の流し込みで X-Plane が画面にエラーを出していたのを直し、直した後の s86・s87 ではエラー 0。Lua の誤りなし。

## 21. 段 5d の実装（2026-10-26：手続きと DEP/ARR のページ）

- 新しい純粋なモジュール `B747.68.proc_model.lua`：空港の CIFP（X-Plane の書式、ARINC 424 の欄）の SID・STAR・進入を経路の脚にする。部分は列 2 の経路の種類で分ける：SID の滑走路の遷移（1・4・F・T）・共通部分（2・5・M）・エンルートの遷移（3・6・S・V）、STAR のエンルートの遷移（1・4・7・F）・共通部分（2・5・8・M）・滑走路の遷移（3・6・9・S）、進入の遷移（A）と最終進入（種類の文字）、ミストアプローチ（記述符号の 3 文字目の M の脚から）。滑走路の部分の遷移名は RW16R、平行の両方の RW16B、ALL。2 つの部分の継ぎ目の点は 1 回。
- 脚：パスターミネーター、終わりの点（滑走路の threshold も。条件の脚は無し）、旋回の向き、fly-over、推奨の航法施設と θ・ρ、コース、距離、高度の制限（+ 以上、- 以下、B は窓、C は 2 つ目以上。グライドスロープの符号は推定で以上か一致）、速度（以下）、降下角、高度で終わる脚、FAF・MAP・ミスト。条件の脚の名前は FCOM p.1249 の形：(1000)、(INTC)、VECTORS、NRE180（radial）、NRE/20（DME）。nav DB は記述符号を前後の空白を残して持つ（位置に意味がある）。
- 経路のモデル：`set_departure`（SID を経路の前に。SID の最後の点が経路にあればそこからつなぎ、無ければ ROUTE DISCONTINUITY。SID の通らない滑走路に替えると SID を消す）、`set_arrival`（STAR と進入を経路の後に、同じつなぎ方。STAR と進入が会わなければ間に discontinuity）。手続きが経路の点でつながったときはその経路の脚を覚えておき、手続きを外すと元に戻す（同じ手続きを選び直すと同じ点でまたつながる。滑走路を後から選んだときに切れ目ができていたのを X-Plane の s88 で見つけた。戻し方は資料に無く推定）。新しい目的地は前の目的地の手続きを消す（FMSPG p.79。その前の discontinuity も一緒に消すのは推定）。X-Plane の .fms では手続きの点を DRCT で、到着の滑走路は出発の滑走路と同じく名前のついた位置（閾値の標高）で、DESRWY を書き、条件の脚とミストアプローチは書かない（5e で）。
- DEP/ARR INDEX・DEPARTURES・ARRIVALS（`activepages/B744.fms.pages.deparr.lua`、FCOM p.1299–1302, p.1400–1405）：一覧を 5 行ずつ、選ぶと <SEL> が付いて同じ種類のほかが消え、遷移は TRANS の見出しの下に（見出しは最初の遷移の行の上：FCOM p.1403）、EXEC で <ACT>、ページを開き直すと全部の選択肢に戻る。6L は ERASE（MOD のとき）か INDEX、6R は ROUTE>。進入は CDU の呼び名（I34L は ILS34L、R06L は RNV06L、D06L は VOR06L。FCOM に無い文字は推定）。DEP ARR キーは、アクティブな経路が無ければ INDEX、地上では DEPARTURES、空中では ARRIVALS（出発地の近くで出発地の到着を出す規則は未）。INDEX の OTHER、RTE 2、VFR の進入（ARRIVALS の RUNWAYS）、PROF DES、INTC はまだ。
- LEGS：条件の脚の名前、手続きのコース、針路は「337° HDG」の形で（FM の脚はコースなので HDG なし：FCOM p.1249）、ホールドは HOLD AT、条件の点に距離を出さない（FCOM p.1331；FMSPG p.119）。
- 合成の CIFP（ZZAA）に条件の脚（VA・VI）、STAR の脚、最終進入とミストアプローチを足した。
- 試験：`tests/fms/proc_model_test.lua`（58 件。選び直し、アクティブな経路の MOD と ERASE も）、`deparr_pages_test.lua`（38 件）。X-Plane：`s88_deparr` 26/26（DEP ARR キーで DEP/ARR INDEX、DEPARTURES で AKAGI4 と 34L の <SEL>（ほかは消える）、SID が AKAGI で経路につながる（RTE の VIA AKAGI4 TO AKAGI、続いて DIRECT ATMUG）、LEGS に SID の点 D337F・条件点 NRE001 /3000A・「100° HDG」、ARRIVALS で ATMUGA・ILS06LY・遷移 GATES、ACT RTE 1、開き直した DEPARTURES の AKAGI4<ACT>、X-Plane の FMS に RJBB）。1 回目は、滑走路より先に SID を選ぶと AKAGI4 の後に discontinuity ができて 25/1（経路の点を戻すように直して 26/26）。`s86_rte_pages` 18/18・`s87_legs_pages` 21/21。CDU と ND の写真（DEPARTURES・LEGS・ARRIVALS）。Lua の誤りなし。

## 22. 段 5e の実装（2026-10-26：現用点と X-Plane の FMS）

- 調べ（X-Plane、空中）：経路を X-Plane の FMS に流し込むと、X-Plane は計画を最初の点（出発地）から始める（XTLua の `xtlua/loadtoFMS` は全部消してから読み込む：XTLua のソース xpmtdatarefs.cpp）。自動操縦（AFDS）の現用点（`laminar/B747/autopilot/ap_monitor/fmscurrentIndex`。自分の best track で選び、変わったときだけ `xtlua/currentFMSID` に書く）は前の番号のまま残るので、空中で経路を変えて EXEC したり、空中で経路をアクティブにしたりすると、ND の右上の現用点と各点の ETA が出発地を指したままだった。DIRECT TO は「出発地→目標点」の脚になり、機体は現在位置からでなく、その脚に乗りに行っていた。
- 現用点（FCOM p.1331：アクティブな経路の LEGS の 1 行目が現用の脚。FMSPG p.119：通過した点は LEGS から消える）：LNAV が自分で順送りするまで（段 6）、AFDS の現用点を現用点とし、その前の脚を「通過した脚」にする（経路のモデルの `sequence`。修正中の経路も、同じ脚で始まるなら一緒に送る）。通過した脚は X-Plane の FMS の計画に残す（ND の線と AFDS の脚は直前の点から始まる）ので、順送りでは計画は変わらない。飛行中に新しい計画を流し込んだあとと、空中で経路をアクティブにしたときは、X-Plane が計画を持ったのを `xtlua/fms` で確かめてから（新しい計画は `xtlua/fms` が変わるまで、最大 1 秒待つ：行数も現用点の位置も同じ修正では、古い計画が既に現用点を示していることがある）、X-Plane の FMS の現用点（`xtlua/currentFMSID`、1 から）と AFDS の現用点を FMC の現用点に合わせる。地上では送らない（離陸後は AFDS の best track から）。
- DIRECT TO（FMSPG p.141–144）：始点は EXEC の時の機体の位置（資料に時刻が無いので推定）。X-Plane の FMS には目標点の前に位置の点 DTOPOS（実在の点に無い名前）として書く（初めは X-Plane 自身の direct-to と同じ PPOS にしたが、§23 の理由で変えた）。INTC CRS のときは、そのコースの線上で、目標点から機体と同じ距離の点を始点にする（推定：AFDS がその線に乗りに行く）。ND は DTOPOS を点として描かない（LEGS にも出ない：FMSPG p.142–143 の図）。
- 修正の EXEC では、修正の写しの通過した脚を、経路の今のものにそろえる（写したあとに順送りした分）。
- `xtlua/currentFMSID` を書くグローバルは `B747DR_fms_currentID`。FMS のモジュールでは `B747DR_fms_setCurrent` が既に `xtlua/currentFMS`（名前で選ぶ）に結び付いていて、XTLua は一度データ参照に結び付けたグローバルを結び直さない（書いた値は前の dataref に行く）。
- まだ無いもの：PLAN の CTR と STEP（FCOM p.1333；FMSPG p.124）。ND の PLAN の中心は X-Plane の FMS の表示中の点（XPLMGetDisplayedFMSEntry）で、XTLua からは書けない（`xtlua/xpFMSData` の書き込みは INOP：XTLua のソース）。X-Plane の CDU のキーを裏で押して動かすか、プラグインで XPLMSetDisplayedFMSEntry を呼ぶかを決めてから（PROGRESS.md「利用者に確かめたいこと」）。条件の点（VA・VI など）は X-Plane の計画に書かない（段 6 で形を作るとき）。
- 試験：`tests/fms/route_model_test.lua`（123 件：行と脚の対応、順送り、修正の順送り、DIRECT TO の PPOS、INTC CRS の始点）、新しい `route_sync_test.lua`（25 件：空中の ACTIVATE、順送り、修正の EXEC（行数も現用点の位置も同じ修正を含む）、DIRECT TO、地上では送らない）、`legs_pages_test.lua`（DIRECT TO の EXEC の後の計画に PPOS）。X-Plane：`s89_route_sync` 26/26（空中の ACTIVATE と EXEC で X-Plane の FMS・AFDS・ND の現用点が XAC、ETA は XAC から。LNAV で XAC を過ぎ、50 秒で LEGS の 1 行目が SPENS（ND と ETA も SPENS）。ATMUG を消して EXEC しても SPENS のまま。DIRECT TO AKAGI の EXEC で現用点 AKAGI（X-Plane の FMS の 4 番目：RJAA・XAC・PPOS・AKAGI…）、55 秒で機体が AKAGI へ向く。ND の線は PPOS から AKAGI で、PPOS に記号なし）、`s86_rte_pages` 19/19、`s87_legs_pages` 21/21、`s88_deparr` 26/26。CDU と ND の写真。直す前の下調べの飛行では、空中の EXEC と ACTIVATE の後に ND の現用点と ETA が出発地のままで、DIRECT TO は出発地からの脚に乗りに行った。途中で X-Plane が 1 回落ちた（0xc0000409、機体の読み直し約 12 回目の s88 の計画の読み込みのとき。起動し直した X-Plane では同じシナリオが合格）。Lua の誤りなし。
- 追記（2026-10-26 夜、段 5f の試験で見つけた）：X-Plane の FMS に流す各点の高度を、その点の高度の制限（LEGS で入力したもの、手続きのもの）にした（FCOM p.1148：ND の DATA は、入力した、または手続きの高度を各点に出す。AFDS の VNAV も各点の高度を読む）。段 5b から 0 で流していたので、ND の DATA に高度が出ず、VNAV にも制限が渡っていなかった（X-Plane の DEP ARR を使っていた頃は手続きの高度が入っていた）。窓（A と B）は最初の高度（推定）。滑走路は前どおり閾値の標高。試験：`route_model_test.lua`（125 件）。X-Plane：`s67_nd_data` 25/25（経路を CDU で入れる形にした版：段 5f）で、ND の DATA に FR の 5000 と TAU の FL200 が出る。Lua の誤りなし。

## 23. FMS ブリッジ（2026-10-27：X-Plane の FMS を X-Plane のスレッドで）

- 何が起きたか：段 5e の試験中に X-Plane が 3 回落ちた（2026-10-26 22:29 は X-Plane.exe の中で 0xc0000409、23:01 は C++ の例外で、次の起動で「PLUGIN CRASH … XTLua 2.4.1」、27 日 0:06 は ntdll のヒープ破損 0xc0000374）。どれも FMC が X-Plane の FMS に計画を流し込むか、現用点を設定した直後。XTLua の `xtlua/loadtoFMS` と `xtlua/currentFMSID` は、XTLua の作業スレッドから X-Plane の FMS をそのまま呼び、X-Plane 側との排他が無い（XTLua のソース xpmtdatarefs.cpp：loadtoFMS は全部消して読み込み、currentFMSID は X-Plane のスレッドが書く FMS の JSON を毎回 json::parse し、例外を捕まえない）。X-Plane の SDK は主スレッド以外からの呼び出しを認めていない。段 5b から経路を変えるたびに読み込み、段 5e では確認が取れるまで毎フレーム現用点を書いていた。
- まず回数を減らした（プラグインが無いときの道として残す）：新しい計画は経路が 1 秒変わらなくなってから流す（続けての編集は 1 回の読み込み）。X-Plane の現用点は、直前の読み込みが `xtlua/fms` に出てから 1 回書き、2 秒たっても示さなければもう 1 回だけ（AFDS の現用点は XTLua の dataref なので、合うまで毎フレーム）。読み込みの直後に空中で経路をアクティブにすると、X-Plane が計画を持つ前に書いた現用点が読み込みに消されていた（s67 で 1 回）ので、`xtlua/fms` が新しい計画を示すまで待つ。DIRECT TO の始点の名前を PPOS から DTOPOS に変えた：PPOS の後では AFDS が X-Plane の現用点に従うが、それは currentFMSID でしか直せない。DTOPOS なら AFDS の best track がほかの脚と同じに扱う。それでもヒープ破損で 1 回落ちた。
- 新しいプラグイン `plugins/b747_fms_bridge`（C。MinGW-w64 の GCC と X-Plane SDK 4.3.0 で `docs/overhaul/tools/build_fms_bridge.sh` が作る `64/win.xpl`、15 KB。機体のフォルダーにあり、機体と一緒に読み込まれる）：dataref `laminar/B747/fms/xp/plan`（.fms の文字列。先頭に私たちの行 `CURRENT n` があれば、読み込みの直後にその番号を現用点にする）、`.../current`（現用点、1 から）、`.../displayed`（表示中の点、ND の PLAN の中心：PLAN の STEP 用）、`.../loads`、`.../bridge`（1：プラグインがある）。XTLua は普通の dataref への書き込みを X-Plane のスレッドで反映するので、FMS の操作はすべてプラグインの毎フレームの処理の中で、X-Plane のスレッドで行われる。
- FMC と AFDS：`laminar/B747/fms/xp/bridge` が 1 なら、FMC は計画を `xp/plan` に（空中でアクティブなら `CURRENT n` つき）、現用点を `xp/current` に書き、AFDS の順送りの書き込み（`B747_set_fms_current`）も `xp/current` に。プラグインが無ければ（Mac・Linux など）上の XTLua の道。
- 採用の理由（CLAUDE.md の決まり、利用者の承認 2026-10-27 未明）：XTLua だけでは、X-Plane の FMS を X-Plane のスレッドで操作する手段が無い（`xtlua/` の FMS の dataref はどれも作業スレッドで即時に呼ぶ。XTLua 本体には手を入れない）。ほかの案：(1) 呼ぶ回数を減らす（上：それでも落ちた）、(2) X-Plane の FMS を使わない（ND の経路の線は X-Plane の地図の層が、AFDS の LNAV・VNAV は X-Plane の FMS の点を読むので、段 6 以降まで無理）、(3) FlyWithLua（利用者の環境にしか無い）、(4) XLua（FMS の関数が無い）。影響：Windows だけ（ほかは XTLua の道）。X-Plane の FMS は最大 100 点（SDK の説明）。ソースと作り方はリポジトリに、コンパイラー（w64devkit 2.10.0）と SDK は外（`C:\Users\gakug\tools`）。
- 試験：新しい `tests/fms/route_bridge_test.lua`（13 件：地上は CURRENT なし、空中のアクティブ化は `xp/current`、修正の EXEC は CURRENT つき、DIRECT TO、XTLua の FMS の dataref を使わない）、`route_sync_test.lua`（31 件：プラグインが無いときの道。続けての編集は 1 回の読み込み、現用点は 2 回まで、読み込み直後のアクティブ化）、RTE・LEGS・DEP/ARR のページの試験は読み込みを待つ。X-Plane：プラグイン入りで `s89_route_sync` 26/26（作り直したプラグインでもう一度）、`s67_nd_data` 25/25（空中の ACTIVATE と EXEC の直後から現用点が FR）、`s70_nd_airports` 39/39、`s88_deparr` 26/26、`s86_rte_pages` 19/19、`s87_legs_pages` 21/21 で、X-Plane は落ちなかった。プラグインは機体の読み直しのたびに読み込まれる（Log.txt の Loaded）。Lua の誤りなし。

## 24. 段 5f の実装（2026-10-27：飛行試験キットの経路を CDU で）

- 実行器（`tests/flight/run_scenario.ps1`）の新しい手順 `cdu`：CDU のキーを FCOM の名前（RTE・LEGS・DEPARR・MENU・INITREF・PROG・NAVRAD・PREV・NEXT・EXEC・DEL・CLR）、行選択キー（L1〜R6）、打つ文字で並べる。`?SEL` は SELECT DESIRED WPT が出ていればいちばん近い候補を選ぶ。文字は 1 つずつ 70 ms 空けて打つ（同じキーが同じフレームに 2 回届くと 1 回になり、EDDF が EDF になった）。
- `s67`（ND の DATA）と `s70`（ND の空港と滑走路）は、FlyWithLua で X-Plane の FMS に直接入れていた経路を、CDU で FMC に入れる形にした（`s67`：EDDF→EDDF、DIRECT FR・TAU、LEGS で FR に 5000、TAU に FL200、空中で ACTIVATE と EXEC。`s70`：EDDF の 25C から EDDM、ARRIVALS で ILS26R）。FMC が流す計画（滑走路の行、高度の制限、現用点）で ND が描けることを確かめる。これで流し込みに高度が無いこと（上の §22 の追記）と、ND の遷移高度の書式（notes/ATA-31.md §28 の追記）が見つかった。
- `s79`（FMC の小修正）は、緯度経度の点（FMC はまだ受け付けない）を使うので FlyWithLua の経路のまま。`s86`〜`s89` は初めから CDU。`B747_route.lua` は残す。
- X-Plane：`s67_nd_data` 25/25、`s70_nd_airports` 39/39（どちらも経路を CDU で入れる）。ND の写真（DATA の現用点 FR のマゼンタと高度・ETA、TAU の FL200、26R の滑走路の絵）。

## 25. EXEC 灯（2026-10-27：利用者の承認で 3D の物体も）

- FMC の新しい dataref `laminar/B747/fms/exec_light_pilot`・`_copilot`（init スクリプト `B747.68.fms`）：経路の修正（MOD）か ACTIVATE の実行待ち（FCOM p.1238、p.1290）、または X-Plane のページ（HOLD・FIX：まだ X-Plane の CDU の上）の実行待ち（X-Plane の `fms_exec_light_pilot`）で 1。その CDU の電源が無ければ 0（左・中央の灯りは左の CDU の電源、右は右の CDU の電源：電源の割り当ては B744.createfms.lua の推定のとおり）。`B747_fmc_exec_lights()` が毎フレーム、変わったときだけ書く。
- 3D の物体 `objects/747_cockpit/Cockpit_Pedestal1.obj` の `ATTR_light_level` 2 行だけ、見る dataref を X-Plane 標準から上の 2 つに替えた（明るさの範囲 0〜1 とほかの記述はそのまま）。頂点の左右の位置で、`pilot` の組が左と中央の CDU、`copilot` の組が右の CDU と確かめた。手元の 3D 一式と非公開リポジトリ（Gakugaku87/747-400-assets）の変更で、変更前の物体は `D:\747-400-local-assets\backup_20261027_exec_light\` に控えた。物体を変えたら X-Plane を起動し直して読ませる（絵ごとの読み直し `sim/operation/reload_aircraft` では X-Plane が固まった：TESTING.md）。
- AutoATC の CDU の写し（`acars/autoatcProvider.lua`）も右の CDU の灯り（`exec_light_copilot`）を読む。INTERFACES.tsv に 2 行を足した。
- 試験：`legs_pages_test.lua`（42 件：DIRECT TO の修正で 2 つとも 1、EXEC で 0）。X-Plane：`s87_legs_pages` 29/29（ACTIVATE と DIRECT TO の修正で左・中央と右の灯りが 1、EXEC で 0。写真で、MOD の間は CDU の EXEC キーの上の灯りが光り、EXEC で消える）。X-Plane を起動して最初のフライトでは交流の母線に電気が来ておらず、右の CDU の灯りが 0 だった（電源の割り当てのとおり。2 回目のフライトで合格）。Lua の誤りなし。

## 26. 段 6 の段取り（2026-10-27：経路の形と LNAV）

- 資料から決まること（§4.5・§4.7 の続き）：
  - LNAV は点の間の大円。手続きでは FMC がヘディング、トラック、DME arc を指令する（FCOM p.1245）。RF は一定半径の弧（FCOM p.1247；FCTM p.61）。区間の間は曲線でつなぐ（ATA34_2 p.615）。ND の線も全点を滑らかにつなぐ（ATA34_2 p.626）。
  - 誘導：次と前の点の位置と機体の位置からクロストラック誤差を作り、横の steering 指令を FCC へ（ATA34_2 p.617 の図）。FCC は LNAV の steering を FD と ROLL ATT INTEG に入れる。指令は希望トラックからの偏差に基づく（ATA22 p.358、p.348）。
  - 作動：arm 中に、FMC が「software monitor・IRS・ADC が有効、アクティブな経路、50 ft 超、捕捉の条件、LNAV ARM/OPERATE」の AND で横の指令を valid にし、FCC が engage（ATA34_2 p.618–619；ATA22 p.270）。捕捉の条件：アクティブな脚から 2.5 NM 以内、またはトラックが脚に交わり、最大 25° のバンクで滑らかに乗れる（ATA34_2 p.618；FCOM p.644、p.663）。
  - 今のヘディングを保持：経路の最終点、discontinuity の手前の点、オフセットの最終点の通過と、捕捉の条件の外での activate（FCOM p.644）。メッセージは DISCONTINUITY・END OF ROUTE（FCOM p.1431）、NO ACTIVE ROUTE（p.1433）、NOT ON INTERCEPT HEADING（p.1435）。
  - 順送り：オフセットでなく経路から 21 NM 超離れていると進めない（FCOM p.1237）。VECTORS は終点の無い線で、先へは DIRECT TO か INTC（FCOM p.1237；FMSPG p.215）。条件点（FCOM p.1249；FMSPG p.215）。
  - AUTO のバンク制限は LNAV にも効き、離陸フラップで V2+10 未満は 15°（FCTM p.118）：AFDS（6-3）の側。
- 資料に無いこと（推定で作る）：fly-by の旋回の半径（25° のバンクと今の対地速度）と旋回の始め（方向の変化 Δ に対し R·tan(Δ/2) 手前）、点の順送りは旋回の二等分線（fly-over は点の真横）、135° を超える方向の変化は fly-over として扱う、誘導の則（交角の上限、先読みの距離、ゲイン）、コースの脚（C で始まる脚）は始点からその方位の線に乗る、DF の始点は前の脚が終わった位置、高度で終わる脚の終わりの予測（上昇の勾配）。
- 分け方：

| 段 | 内容 |
|---|---|
| 6a | 経路の形のモデル（新しいモジュール `B747.68.path_model.lua`）：脚の種類ごとの形（IF・TF・CF・DF・直行・DIRECT TO、CA・CD・CI・CR、FA・FC・FD・FM、VA・VD・VI・VM・VR、AF・RF）、fly-by と fly-over の旋回、ND に描く点列。手続きのモデルが RF の中心と半径を読む。まだ機体からは使わない |
| 6b | LNAV のモデル（`B747.68.lnav_model.lua`）：アクティブな脚、XTK と希望トラック、順送り（21 NM）、捕捉の条件、steering（ロールの指令）、ヘディングの保持、メッセージ。試験は簡単な機体の運動で閉ループにする |
| 6c | 組み込み：FMC が毎フレーム順送りと LNAV を回す。AFDS の LNAV は FMC の valid で engage し、FMC のロールの指令を FD とサーボへ（AFDS の作り直し 6-3 までのつなぎ）。X-Plane の FMS の現用点は FMC から（AFDS の best track をやめる）。メッセージ |
| 6d | ND の線を経路の形どおりに（X-Plane の FMS に旋回と弧の点を足す。X-Plane の FMS の点の数の上限を確かめる） |

- ホールドと procedure turn（HA・HF・HM・PI）は段 7（ホールドの形・進入・出口と一緒に）。段 6 では保持点への線として飛んで順送りする（推定、段 7 まで）。

## 27. 段 6a の実装（2026-10-27：経路の形のモデル）

- 新しい純粋なモジュール `B747.68.path_model.lua`（まだ機体からは読まない：6b・6c で使う）。経路の脚ごとに形の要素を作る：
  - 線（大円）：TF・DF・IF・CF と FMC 自身の脚（DIRECT・airway・DIRECT TO）。CF は前の点の真横から、その方位の線（推定）。
  - コース：CA・CD・CI・CR は前の脚の終わりから、FA・FC・FD・FM はその点から、真方位の線（FCOM p.1245 の「トラック」）。
  - ヘディング：VA・VD・VI・VM・VR（終わりの予測は風なし）。
  - 弧：RF（中心と半径。手続きのモデルが CIFP の 31〜34 番目と 18 番目の欄から読む）、AF（航法施設のまわりの DME の弧。境界の radial から点まで）。
  - 条件で終わる脚の終わりの予測（FCOM p.1249）：高度（前の高度から 500 ft/nm の上昇：推定）、DME の距離、radial、次の脚への切込み（CF の方位、FA・FC・FD・FM の方位、AF の弧）、距離（FC）。VECTORS（VM・FM）は終わりが無く、ND には 10 nm の線（推定）。
  - discontinuity の後と、終わりを予測できない脚の後は、次の点への線が無い（none）。
- fly-by の旋回（推定）：半径は対地速度と 25° のバンクから（250 kt で 1.95 nm）、点の R·tan(Δ/2) 手前から始める。どちらかの脚の半分を超えない（超えるなら半径を小さく）。fly-over の点、135° を超える方向の変化、手続きの旋回の向きと逆、ヘディングの脚へ、点から始まらない脚へは、点の上を飛ぶ。
- 地球は半径 3440.065 nm の球（経路のモデルと同じ）。端末の幾何（交点、弧）は点のまわりの平面で近似する。真方位は磁方位＋偏差（nav DB の近い VOR の偏差：段 5c と同じ）。
- 試験：`tests/fms/path_model_test.lua`（78 件。合成のデータに ZZBB の RNAV 進入 R09：IF・RF（中心 ZBRF1、半径 3.0 nm）・TF を足した）、`proc_model_test.lua`（58 件のまま）。X-Plane では未使用（6c で）。
- 6b で、discontinuity と TO の無い airway にも要素（`disc`）を置くようにした（LNAV が経路の終わりと区別するため）。

## 28. 段 6b の実装（2026-10-27：LNAV のモデル）

- 新しい純粋なモジュール `B747.68.lnav_model.lua`（まだ機体からは読まない：6c で）。経路の形（§27）と機体の状態（位置、トラック、機首方位、対地速度・真対気速度・風速、高度、偏差、地上か）を毎フレーム受け、次を出す。
  - XTK（右が正）、希望トラック、トラック角の誤差、アクティブな点までの距離。
  - 順送り（FCOM p.1237）：地上では進めない（推定）。脚から 21 nm 超では進めない。fly-by の点は旋回の二等分線で、fly-over の点は真横で（推定）。条件の脚は、高度（以上）、DME の距離・radial を越えたとき、次の脚へ切込む旋回を始める所で（FCOM p.1249）。VECTORS は進めない（FCOM p.1237）。条件の脚の次の脚は、その時の機体の位置から始まる（経路のモデルの `start`）。
  - 捕捉（ATA34_2 p.618；FCOM p.644）：アクティブな脚から 2.5 nm 以内、または脚に交わるトラック（交角 90° まで：推定）で、25° のバンクの旋回を始める所（半径 r と交角 θ から r(1−cos θ)、ロールに入る 4 秒分を足す：推定）。ヘディングの脚はすぐ。このとき steering が valid（FCC が LNAV を engage する条件：ATA34_2 p.619）。
  - NOT ON INTERCEPT HEADING：arm 中に空中で、捕捉の外で、トラックが脚に交わらないとき（FCOM p.1435）。地上では出さない（推定）。
  - steering（ATA22 p.348、p.358：希望トラックからの偏差に基づく。則は推定）：XTK と 25 秒先の距離から決めた交角（45° まで）で経路へ戻るトラックへのバンク（トラックの誤差の 2.5 倍）と、弧（RF・AF・fly-by の旋回）ではその弧のバンク。25° まで（ATA34_2 p.618）。ヘディングの脚は磁方位のヘディングへ。
  - 旋回の半径は真対気速度＋風速から（旋回の中の最大の対地速度。ホールドの半径の作り方 FMSPG p.164 にならった推定）。旋回は 4 秒早く始める（ロールに入る分：推定）。
  - 今のヘディングを保持（FCOM p.644、p.1431）：経路の最終点の通過（END OF ROUTE）、discontinuity（DISCONTINUITY）、EXEC などで新しくなったアクティブな脚が捕捉の外のとき（捕捉するまで：`reset`）。
- 経路のモデル：`sequence` が新しいアクティブな脚の始点（`start`：条件の脚が終わったときの機体の位置）を受け、`leg_from` が返す。LEGS で DIRECT にした脚からは消す。
- 試験：`tests/fms/lnav_model_test.lua`（54 件。経路・形・LNAV のモデルを、簡単な機体（ロールは 3°/s まで、旋回はバンクから、風）と閉ループで回す）：2 nm 外からの捕捉（行き過ぎなし）、90° の fly-by（経路から 0.09 nm 以内、点の 0.8 nm 内側の二等分線で順送り。西から 40 kt の風で 0.11 nm）、fly-over（点の上 0.01 nm を通り、次の脚に戻る）、RF の弧（0.01 nm）、DME の弧（0.003 nm）、離陸後の 600 ft までのヘディングと DF、045 のヘディングから 090 のコースへの切込み（行き過ぎ 0.007 nm）、捕捉の条件（250 kt の 45° は 2.5 nm、450 kt の 90° は 6.9 nm）、NOT ON INTERCEPT HEADING、21 nm、discontinuity と経路の終わり、新しい脚を捕捉するまでの保持、地上、VECTORS。X-Plane では未使用（6c で）。

## 29. 段 6c の実装（2026-10-27：LNAV の組み込み）

- FMS のモジュール：アクティブな経路の形（§27）を、経路が変わるたびと順送りのたびに作り直し、毎フレーム LNAV のモデル（§28）を回す。入れるもの：機体の位置、真のトラック（`sim/flightmodel/position/hpath`）と真方位、対地速度・真対気速度・風速、高度、偏差（X-Plane の `magnetic_variation` は西が正なので符号を変える）、地上か、AFDS の LNAV の状態（`laminar/B747/autopilot/lnav_state`：1 arm、2 engage）。
- 順送りは FMC 自身（段 5e の AFDS の best track をやめた）。順送りのたびに、X-Plane の FMS の現用点と AFDS の現用点（`fmscurrentIndex`：古い VNAV が読む）を FMC のアクティブな点に合わせる（5 秒ごとにも確かめる）。X-Plane の FMS は自分で進めない（`override_fms_advance`）。条件の脚の次の脚はその時の位置から（§28）。LNAV が engage したとき、アクティブな脚が DF ならその時の位置から（推定：離陸後は滑走路の端が後ろになる）。
- DIRECT TO（INTC CRS の無いもの）と DF は、機体のいる所から飛ぶ：旋回の間は機体から点へのコース、そのコースに乗ったら（3° 以内）そこからの大円（FCOM p.1237：EXEC の後のコースは点への今のコース。旋回は推定）。X-Plane の 1 回目の `s90_lnav` で、後ろの点への DIRECT TO が EXEC の時の位置からの線へ戻ろうとして大回りした（線から 5.5 nm）ので直した（経路の形のモデルの `direct`、LNAV のモデルの `direct()`）。
- 出すもの（新しい dataref）：`laminar/B747/fms/lnav/valid`（FCC が LNAV を engage する条件）・`roll`（バンクの指令、度）・`mode`（1 経路、2 ヘディングの脚、3 ヘディングの保持）・`xtk`（nm、右が正）・`dtk`（真）・`route`（FMC がアクティブな経路を自分で順送りする）。
- AFDS（6-3 の作り直しまでのつなぎ）：LNAV は arm 中に電波高度 50 ft 超（前のまま）で FMC の valid のときに engage（ATA34_2 p.619；ATA22 p.270）。engage 中は FD のロールとサーボの目標を FMC のバンクの指令にする（ATA22 p.358。X-Plane の HDG SEL の FD ロールの 10 点の移動平均を通さず、3°/s で追う：推定）。PFD の FD のバー（`capt_roll_ref`・`fo_roll_ref`）も。前の LNAV（AFDS の best track と、現用点への方位を X-Plane の HDG SEL に入れるしくみ）は FMC のアクティブな経路が無いときだけ。
- AFDS の FMA の直し（LNAV が空中で arm のままになるようになったため）：arm 中も前のロールモード（HDG SEL・HDG HOLD）が active のまま（FCOM p.644。前は HDG SEL が NONE になってサーボが離れ、HDG HOLD は arm を消していた）。arm 中に X-Plane の HDG SEL を入れない（engage してから）。
- メッセージ：DISCONTINUITY・END OF ROUTE（alert：FCOM p.1431）、NO ACTIVE ROUTE（alert：アクティブな経路が無いのに LNAV を arm：FCOM p.1433）、NOT ON INTERCEPT HEADING（advisory：FCOM p.1435。フラグの無いメッセージは CDU のグルーの `B747_cdu_fmc_condition`）。LNAV のフラグは条件が変わったときだけ書く。
- PROGRESS 2 の XTK ERROR：FMC の XTK で、L か R と NM（FCOM p.1377。前は常に L：FMC-38 の XTK の分）。
- まだ無いもの：オフセット（前の LNAV のオフセットは、段 7 まで効かない）、ホールド（段 7）、ND の線を経路の形どおりに（段 6d）。
- 試験：`tests/fms/lnav_glue_test.lua`（19 件：経路が無いときの NO ACTIVE ROUTE、脚の上の valid、平行に 10 nm 離れた NOT ON INTERCEPT HEADING、右 1 nm で左へのバンク、PROGRESS 2 の R 1.0NM、discontinuity での保持と DISCONTINUITY）、`lnav_model_test.lua`（58 件：後ろの点への DIRECT TO が近い向きに回り、大回りしない）、`path_model_test.lua`（81 件：`direct`）、`route_sync_test.lua`・`route_bridge_test.lua`（機体の位置で LNAV が順送りする形に書き直した）、`cdu_framework_test.lua`（37 件のまま）。飛行試験キットの `run_scenario.ps1` に `watch`（dataref を 0.25 秒ごとに見て、条件までの最大・最小を判定）を足した。X-Plane：`s90_lnav` 30/30（脚の右 6 nm で平行に arm：engage せず NOT ON INTERCEPT HEADING、ロールモードは HDG SEL のまま。30° 向けると 2.49 nm で engage して脚に乗る。XAC の右 54° の fly-by の旋回で、経路から前半 0.10 nm・後半 0.22 nm 以内、バンクは指令の 25° に 24.3〜24.8°。後ろの XAC への DIRECT TO は近い向きに回り、飛んだ経路から 0.01 nm 以内（直す前は EXEC の時の位置からの線に戻ろうとして 5.5 nm の大回り）。XAC を過ぎるとヘディングを保持し DISCONTINUITY）、`s89_route_sync` 26/26（FMC 自身の順送りで XAC の次が SPENS、DIRECT TO AKAGI）、`s67_nd_data` 25/25、`s70_nd_airports` 39/39、`s86_rte_pages` 19/19、`s87_legs_pages` 29/29、`s88_deparr` 26/26。Lua の誤りなし。
- 6c の続き（2026-10-27）：手続きの旋回の向き（CIFP の 10 番目の欄 L・R）を、ヘディングの脚と、点へのコースに乗るまでの DF・DIRECT TO の旋回に効かせる（遠回りでも。旋回が終わる（10° 以内）まで：推定）。切込みの脚（CI・VI）の終わりは、交角 90° を超えても（150° まで）その角の旋回の始まりで（前は 90° で頭打ちで、123° の切込みで旋回が遅れる）。試験：`lnav_model_test.lua`（63 件：右回りの指定で左が近くても右へ、123° の切込みの行き過ぎなし）。X-Plane：新しい `s91_lnav_sid` 23/23（RJAA 34L の SAKUR5：CF で D337F を真上で過ぎ、手続きの右回りでヘディング 100、NRE の radial 001・036 で順送り、ヘディング 160 から 283 のコースへの 123° の旋回はコースの 3.2 nm 手前で始まり、行き過ぎ 0.19 nm。NRE・TETRA を経て経路の終わりでヘディングを保持し END OF ROUTE。バンクは指令の 25° に 23.7〜24.7°）、`s90_lnav` 30/30。Lua の誤りなし。

## 30. 段 6d の実装（2026-10-27：ND の線を経路の形に）

- ND の経路の線は、FMC が流し込んだ X-Plane の FMS を X-Plane の地図の層が描く（行から行へ直線で、全部の行を通る）。経路の形（§27）を、その行で表せる範囲で計画に入れる（ATA34_2 p.626：全点を滑らかにつなぐ）：
  - 条件の脚（CA・VA・VR・VI・CD・VD・CR・CI・FA・FC・FD）の終わり：経路の形のモデルが予測する所に、その名前（(600)・NRE001・(INTC) など：FCOM p.1249）の位置の行（型 28、高度 0：古い VNAV の制限にしない）。ND はその名前の記号を描く（推定：資料に ND の条件点の描き方は無い）。アクティブな条件の脚はその行が X-Plane の FMS の現用点（ND の右上も）。
  - VECTORS（VM・FM）：ヘディングかコースの 10 nm 先（推定）。X-Plane の線は次の点へつながってしまう（実機は終点の無い線：FCOM p.1237）。
  - RF・DME の弧：15° ごとの点（推定）を名前「~」の位置の行で弧の点の前に（ND は記号を描かない）。
  - 通過した条件の脚は、終わった所（順送りの時の位置 `end_at`）の行で残す（アクティブな点の行の番号を変えないため）。
  - fly-by の旋回の曲線は描けない（X-Plane の線は点の行を必ず通り、点の行は現用点の対応に要る）。
  - X-Plane の FMS は 100 行まで（SDK の XPLMNavigation.h）：超えたら弧の点をやめ、まだ超えたら通過した脚を最後の 1 つにする（前は超えた分が X-Plane で切られ、現用点の対応が外れていた）。
- ND の右上のアクティブな点（FCOM p.1147：名前・距離・ETA）は、条件の点も名前と、予測した点への距離・ETA で出す（前は括弧のある名前のとき「-----」）。VECTORS は名前だけ（終わりが無い：FCOM p.1237）。
- 予測の限り（推定）：ヘディングやコースの脚の終わりは、前の脚の終わりから旋回なしの直線で予測するので、実際の旋回の分だけずれる（`s91` の写真で、D337F の後の NRE001 は機体の右後ろに描かれた）。
- 経路の形は RTE 1 が変わるたびに（非アクティブの経路でも）作り直す（`B747_fmc_lnav_build`）。予測は作った時の高度から。経路の形のモデル `shape`、経路のモデル `to_fms(r, cycle, shape)`、ND のモジュールは「~」の記号を描かない。
- 試験：`path_model_test.lua`（87 件：`shape`）、`route_model_test.lua`（136 件：条件の脚の行、弧の点、通過した条件の脚、100 行）、`deparr_pages_test.lua`（38 件：X-Plane の計画に (600) と (INTC)。前は「条件の脚は書かない」を確かめていた）。X-Plane：`s91_lnav_sid` 27/27（ND の現用点が D337F・NRE001・(INTC)：X-Plane の計画の条件の点の行。20 nm の ND の写真で、マゼンタの線が NRE001・NRE036（ヘディング 100）、(INTC)（ヘディング 160）、NRE（283 のコース）を通り、条件の点に名前）、`s88_deparr` 26/26、`s89_route_sync` 26/26、`s90_lnav` 30/30、`s87_legs_pages` 29/29、`s86_rte_pages` 19/19、`s67_nd_data` 25/25、`s70_nd_airports` 39/39。Lua の誤りなし。

## 31. 段 7 の段取り（2026-10-27：ホールド・オフセット・残りの経路の操作）

- 資料から決まること（§4.6 の続き）：
  - ホールドの形：一定の半径の旋回と直線の脚（FCOM p.1413）。半径は 25° のバンクと「対地速度（性能の初期化がまだなら真対気速度）＋風速の大きさ」から、保持点が TO の点になった時に計算し、以後は保持点を通るたびに保持の指令速度で計算し直す（FMSPG p.224）。脚の長さは LEG TIME（14,000 ft 以下 1.0 分、超 1.5 分。比べる高度は FMSPG p.222–223）× 入航方向の対地速度、または LEG DIST（排他：FCOM p.1417–1418）。
  - 誘導：LNAV は 30° までのバンク（FCOM p.1413；FMSPG p.164、p.226–227）。
  - 進入：保持点を通る時のトラックで決める（FCOM p.1413）。parallel（入航コースに平行な脚 2.41R の後、180° 回って入航コースへ）、teardrop（入航コースの逆から 40° の脚 2.95R の後、入航コースへ）、direct（type I・II：区間なし、入航コースか出航脚に乗る）（FMSPG p.225）。領域（FMSPG p.165 の図：入航コースから 5° 傾けた線で分け、右回りなら direct 75°＋105°、parallel 105°、teardrop 75°）。
  - 種類と出口（FMSPG p.221–222；FCOM p.1416）：高度で終わる（HA：AT OR ABOVE に着いたら exit armed。保持点で既に上なら飛ばない）、点で終わる（HF：入ってから最初の保持点の通過で出る）、手動（HM：EXIT HOLD → EXIT ARMED → 保持点で出る）。exit armed で最短で保持点へ戻る形にする。DIRECT TO で即座に出る。手続きの PROC HOLD は入航で保持点に着いたら出る。
  - 作り方（FCOM p.1413–1416；FMSPG p.157–163、p.222）：HOLD キー。経路にホールドが無ければ RTE LEGS の HOLD AT の箱（6L）と PPOS>（6R）、あれば RTE HOLD のページ（NEXT PAGE で次、<NEXT HOLD で箱）。手で作れるのは手動のものだけ。既定は入航コース＝前の脚のコース、右回り。RTE HOLD のページ：FIX、QUAD/RADIAL、INBD CRS/DIR、LEG TIME、LEG DIST、SPD/TGT ALT、FIX ETA、EFC TIME、HOLD AVAIL、BEST SPEED、EXIT HOLD/EXIT ARMED、ERASE/NEXT HOLD。保持中の変更は次の保持点の通過から。
  - ND（FMSPG p.223）：保持点が TO の点で範囲 80 nm 以下なら大きさの変わる記号、それ以外は小さい記号。
  - オフセット（§4.4、FCOM p.1298–1299、p.1431）：空中で SID・STAR・遷移の上でないとき、RTE ページで L/R 1–99 nm。ND は修正中の白破線、実行後はマゼンタの破線（元の経路は実線のまま）。END OF OFFSET は 5 nm 手前。21 nm 超のオフセットへの出入りは 200 nm まで順送り。
- 分け方：

| 段 | 内容 |
|---|---|
| 7a | ホールドのモデルと LNAV：経路のホールドの脚（手で作る HM と手続きの HA・HF・HM）、形（半径・脚の長さ）、進入（領域と parallel・teardrop・direct）、周回、出口（EXIT ARMED、高度、点、DIRECT TO）、30° のバンク。閉ループの試験 |
| 7b | ホールドの CDU：HOLD キー、RTE LEGS の HOLD AT と PPOS、RTE HOLD のページ（MOD・ACT、EXIT HOLD）、LEGS の HOLD AT の行。ND のホールドの形（計画の点）。X-Plane で試験 |
| 7c | procedure turn（PI）と手続きのホールドの進入・PROC HOLD |
| 7d | オフセット（RTE ページ、LNAV、ND の線、END OF OFFSET） |
| 7e | 残りの経路の操作：FIX INFO、REF NAV DATA、ABEAM PTS、RTE 2 と RTE COPY |

- 予測（FIX ETA、HOLD AVAIL、BEST SPEED）と保持の指令速度は性能（段 8）の後。それまでは今の対地速度・真対気速度で形を作り、予測の欄はダッシュ（推定）。

## 32. 段 7a の実装（2026-10-27：ホールドのモデルと LNAV）

- 経路の形のモデル（§27）：
  - HM・HA・HF の脚をホールドの要素（`hold`）にする：保持点、入航コース（真方位）、旋回の向き（L のほかは右）、脚の時間か距離、終わり方（HM 手動・HA 高度・HF 点：FMSPG p.221–222）、HA の高度、EXIT（乗員の EXIT HOLD：段 7b で CDU から）。手続きのモデルが脚の時間（CIFP の 22 番目の欄 `T010`：分と 10 分の 1）を読む（前は距離として読み、時間は捨てていた）。
  - 大きさ（`hold_size`、FMSPG p.224）：旋回の半径は 25° のバンクと「真対気速度＋風速の大きさ」（性能の初期化の前の式。保持の指令速度は性能の段 8 の後）。脚の長さは時間 ×（真対気速度＋入航コースに沿った風）、または距離。時間も距離も無ければ制限の高度で 14,000 ft 以下 1 分、超えれば 1.5 分（FMSPG p.222–223。巡航の高度での区別は段 7b のページで）。
  - 形（`racetrack`）：保持点の旋回の中心（保持点からホールドの側へ r）、出航脚の始まり（2r）と終わり（出航方向に脚の長さ）、戻りの旋回の中心、入航脚の始まり。
  - ND の線（`shape(path, kt)`、§30）：保持点から 30° ごとに回る点、出航脚の両端、戻りの旋回、入航脚の始まりの 13 点を「~」の行に（保持点の行の前）。大きさは経路を作った時の真対気速度＋風（地上では 250 kt：推定）。
  - ホールドに入る脚に fly-by の旋回は作らない（保持点の上を通る：FMSPG p.225）。
- LNAV のモデル（§28）：
  - 保持点から 1 nm 超でホールドがアクティブな脚になったら、まず保持点へ（FMSPG p.225：保持点を通ってから進入の誘導。1 nm は推定）。普通は保持点への脚の順送り（保持点の上）でそのまま進入する。
  - 進入は保持点を通る時のトラックで決める（FCOM p.1413；FMSPG p.165 の図：保持点を通る、入航コースから 5° と 70° の 2 本の線で分け、右回りなら direct は 75°（型 I）と 105°（型 II）、parallel 105°、teardrop 75°。左回りは鏡写し）。
    - direct（区間なし：FMSPG p.225）：保持点で今のトラックに接する、ホールドの半径の円をホールドの向きに回り、出航脚を捕まえるトラックになったら出航脚へ（推定。FMSPG p.165 の型 II の図は、保持点からそのまま右へ回って出航脚に乗る。入航コースのまま来れば保持点の旋回そのもの）。
    - teardrop：出航コースからホールドの側へ 40° の脚を 2.95r、ホールドの向きに回って入航コースを捕まえる。
    - parallel：出航コース（入航の逆）を 2.41r（横の位置は保持点からの旋回で決まる：FMSPG p.225）、逆向きに回って入航コースを捕まえる。
  - 周回：保持点の旋回、出航脚（戻りの旋回は 4 秒早く：§28 と同じ）、戻りの旋回、入航脚。旋回の終わりは、次の脚を捕まえるトラック（5° 以内）になった所。保持点を通るたびに大きさを計算し直す（FMSPG p.224）。保持中に変えたホールド（入航コースなど）は次の通過から（FCOM p.1416）。
  - 出口（FMSPG p.221–222）：EXIT ARMED（EXIT HOLD、HA の高度以上）で、保持点へ最短で戻る形に変える（保持点の旋回中なら出航脚なし、出航脚の途中ならそこから戻りの旋回）。次に保持点を通ったら次の脚へ順送り。HF は進入の後の最初の通過で出る（形はそのまま）。HA は保持点で既に高度以上なら飛ばない。DIRECT TO では即座に出る（アクティブな脚が変わるので `reset` でホールドの状態を消す）。経路の最後のホールドを出たら END OF ROUTE。
  - バンクは 30° まで（FMSPG p.164、p.226–227。ほかの脚は 25° のまま）。円と線の誘導はほかの脚と同じ操舵則（XTK から 45° までの切込み、円のバンクを足す）。
- 試験：新しい `tests/fms/lnav_hold_test.lua`（65 件。経路・形・LNAV のモデルを閉ループで。簡単な機体は `lnav_model_test.lua` と共通の `tests/lib/lnav_sim.lua` に出した）。250 kt・無風で、入航コースからの direct：1 周 296 秒前後（旋回 88 秒 ×2 と 2 分）、半径 1.95 nm・脚 4.17 nm の形の ±0.3 nm に収まり、保持点を入航コースから 0.15 nm 以内で通る。teardrop（150 から）、parallel（240 から：反対側の脚と左の戻り）、direct の型 II（030：すぐ右へ）、100 から、型 I（300）、左回り（210・120・330）、正面の風 30 kt（半径 2.45 nm、脚は 220 kt の 1 分）、横風 30 kt、遅くなった時の次の通過での大きさ、保持中の変更、出航脚の途中の EXIT HOLD（そこで戻る）、保持点の旋回中の EXIT HOLD（出航脚なし）、HA（11,000 ft で出る、上なら飛ばない）、HF（1 周）、遠くからの保持点への脚、DIRECT TO。`path_model_test.lua`（115 件：ホールドの要素・大きさ・形・ND の点）、`proc_model_test.lua`（59 件：ZZAA の進入復行のホールドを `T010` にし、1.0 分を読む）。
- X-Plane：`s90_lnav` 30/30、`s91_lnav_sid` 27/27、`s89_route_sync` 26/26（ホールドの無い経路で、LNAV の捕捉・順送り・旋回と経路の同期が前と同じ。操舵則の切込みの角を関数に分けた）。Lua の誤りなし。
- ホールドを X-Plane で飛ぶ試験は段 7b（HOLD のページで作る）。ND のホールドの記号（保持点が TO の点で 80 nm 以下なら大きさの変わる形、ほかは小さい記号：FMSPG p.223）も 7b。

## 33. 段 7b の実装（2026-10-27：ホールドの CDU と ND）

- HOLD キー（CDU の `dep_arr` のコマンド）：経路にホールドがあれば RTE 1 HOLD の 1 ページ目（最初のホールド：FCOM p.1416；FMSPG p.222）、無ければ RTE LEGS HOLD AT（FCOM p.1413–1414）。前は X-Plane の HOLD ページ。
- RTE LEGS HOLD AT（LEGS のページの 6 行目に HOLD AT の線、6L の箱、6R の PPOS>：FCOM p.1414；FMSPG p.157–158）：
  - 6L に経路の点：その点への脚の後にホールド（間の脚はそのまま：FMSPG p.158）。MOD RTE 1 HOLD へ。
  - 経路に無い点：スクラッチパッドに HOLD AT XXXXX。LEGS の行に入れると、その前に点とホールド、後ろに ROUTE DISCONTINUITY（点の挿入と同じ：推定）。アクティブな点（1 行目）には入れられない（FCOM p.1414）。
  - 6R PPOS>：アクティブな経路の先頭に、EXEC の時の位置を点とするホールド（FCOM p.1415）。点の名前は整数の度で N47W120 の形。入航コースは EXEC の時のトラック（磁方位：推定）。ホールドの後は元のアクティブな点へ（推定）。
  - 既定（FMSPG p.160、p.222–223）：右回り、入航コースは前の脚の保持点へのコース（磁方位）、LEG TIME は保持の制限の高度・前の脚の制限・巡航高度の順に見て 14,000 ft を超えれば 1.5 分、ほかは 1.0 分（巡航高度を使うのは推定：飛行段階は VNAV の段 9 で）。
- RTE 1 HOLD（ホールドごとに 1 ページ：FCOM p.1415–1419；FMSPG p.159–162）：
  - 題名は ACT・MOD・無印の RTE 1 HOLD とページ番号。NEXT・PREV PAGE で次・前のホールド。
  - 1L FIX（手続きの HF は PROC HOLD、HA は HOLD AT：FCOM p.1416）：ここでは変えられない（FMSPG p.159）。
  - 2L QUAD/RADIAL：NW/330・NW330・/330・330。象限は radial から直す（FMSPG p.159 の境）。入航コースはその逆向き。消せない。
  - 3L INBD CRS/DIR：XXX、XXX/L（XXXL）、/L・L。入れると QUAD/RADIAL はダッシュ（FMSPG p.160）。
  - 4L LEG TIME（XXX.X 分）と 5L LEG DIST（XX.X nm）：どちらかを入れると他方はダッシュ（FCOM p.1417–1418）。
  - 1R SPD/TGT ALT：ホールドの脚の制限（LEGS の行と同じ。速度は高度の制限があるときだけ、巡航高度より下：FCOM p.1418）。
  - 3R EFC TIME：XXXX（時と分）、DELETE で消す（予測に使うのは段 8。修正にはしない：推定）。
  - 2R FIX ETA・4R HOLD AVAIL・5R BEST SPEED：予測（段 8）までダッシュ（推定）。
  - 単位（FIX ETA と EFC TIME の Z、MIN、NM、KT）は小字（FCOM p.1415 の図）。
  - 表示中にホールドが無くなったら（出た、消した）RTE LEGS HOLD AT に替える（HOLD キーと同じ：推定）。
  - 6L <NEXT HOLD（修正の間は <ERASE）。6R EXIT HOLD>（アクティブな経路の先頭のホールドで、出口が armed でないとき：FMSPG p.162）を押すと EXIT ARMED（修正。EXEC で LNAV へ：FCOM p.1419）。HA の高度に達したときと HF の進入の後も EXIT ARMED（FMSPG p.162）。
- LEGS：ホールドの行の上に HOLD AT（HF は PROC HOLD：FCOM p.1331）。飛んでいるホールドは DELETE できる：次の点へ機体のいる所から直行（FCOM p.1416）。DIRECT TO や次の点の入力で通り越すのは前のまま。
- 経路のモデル：ホールドの脚（HM・HA・HF）は点への脚とは別の脚（順送りの修正の比較や LNAV の脚の鍵で区別）。RTE の区間はホールドをその点の区間に含める（自分の区間を作らない）。点の検索（DIRECT TO・点の入力）はホールドを飛ばす。
- X-Plane の計画（ND の線：§30）：ホールドは点の行の後に、形の 13 点（「~」）と点に戻る行（X-Plane の線は現用点から先を描く：ホールドの間も前に形が出るのを X-Plane で確かめた）。TO の点のホールド（保持点がアクティブな点、またはアクティブなホールド）は LNAV の形（保持点が TO の点になった時に作り、保持点を通るたびに作り直す：FMSPG p.224）。ほかは決まった大きさ（210 kt とその脚の時間：小さい記号の代わり。推定）。LNAV が形を作り直したら（2 % か 0.05 nm を超えて変われば）計画を作り直す。地上では全部決まった大きさ。範囲 80 nm を超えると小さい記号にすること（FMSPG p.223）と、画面の上で大きさの決まった記号はまだ無い（X-Plane の線は nm で描く）。
- LNAV：保持点が TO の点になった時に形を作り（`s.ahead`）、進入はその形で飛ぶ（FMSPG p.224。段 7a は保持点で作っていた）。ホールドを出て次の脚へは保持点の上から回る（ホールドは線の要素でないので fly-by にしない：推定）。X-Plane の `s92_hold` で、XAC の入航コース 037 から SPENS への 270 へ左に 127° 回ると、旋回の半径（2.6 nm）の約 1.6 倍の 4.7 nm はみ出してから 45° で切込んで戻った。
- 新しい dataref（試験と確認のため）：`laminar/B747/fms/lnav/hold_phase`（0 なし、1 保持点へ、2 direct、3 teardrop、4 parallel、5 進入の戻りの旋回、6 保持点の旋回、7 出航脚、8 戻りの旋回、9 入航脚）、`hold_loops`（保持点を通った回数）、`hold_exit`（EXIT ARMED）。
- 飛行試験キット：CDU のキー名に HOLD（`run_scenario.ps1`）。
- 試験：新しい `tests/fms/hold_pages_test.lua`（78 件：HOLD キー、RTE LEGS HOLD AT、BRAVO に HOLD AT と各欄、X-Plane の計画の行、HOLD AT ZZD、PROC HOLD、空中の PPOS と EXIT HOLD と DELETE、LNAV の dataref、ホールドが無くなった時の RTE LEGS HOLD AT）、`route_model_test.lua`（173 件：ホールドの作成・既定・入力・計画の行・EXIT・DELETE・PPOS）。
- X-Plane：新しい `s92_hold` 47/47（RJAA→XAC の脚の上で LNAV、HOLD キーで RTE LEGS HOLD AT、XAC に HOLD AT して INBD CRS 044 で EXEC：XAC の上で teardrop、teardrop の脚と右への戻りのバンク最大 29.7°、1 周を形から 0.23 nm 以内、保持点を入航コースの 0.01 nm 以内で通る。2 周目の出航脚で EXIT HOLD と EXEC：すぐ戻りの旋回、XAC で出て SPENS へ（127° の旋回で 4.7 nm はみ出してから戻る）、ホールドが無くなった RTE HOLD のページは RTE LEGS HOLD AT に。PPOS で N34E139、その場で右へ（LNAV の指令 30°）、DELETE で SPENS へ直行。ND（20 nm）の写真で、XAC の手前は XAC の先のホールドの側に LNAV の大きさの形、ホールド中は前方に出航脚・戻りの旋回・入航脚）、`s87_legs_pages` 29/29、`s86_rte_pages` 19/19、`s90_lnav` 30/30、`s89_route_sync` 26/26。Lua の誤りなし。初めの 3 回の `s92` の不合格は試験の作り（ND の範囲を dataref だけで変えて X-Plane の地図の範囲が別のまま：TESTING.md の注意のとおり、つまみのコマンドで変える。旋回中の PPOS。脚に乗る前の確認）で、シナリオを直した。

## 34. 段 7c の実装（2026-10-27：procedure turn と手続きのホールド）

- 手続きのホールド：HF（procedure turn の代わりのホールド）は、LEGS と RTE HOLD の 1L に PROC HOLD（FCOM p.1331、p.1416）、入航で保持点に着いたら自動で出る（EXIT HOLD は要らない。続けるなら新しいホールドを作る：FCTM p.4.20）。HA は高度で出る（SID のホールド：FCOM p.1416）。どちらも段 7a・7b で入っている。
- procedure turn（PI）：LEGS の行の上に PROC TURN（FCOM p.1331）。FMC が描き飛ぶ形（45° の脚の長さ、180° の旋回、制限の内側に収める：FCTM p.150 は「空域の制限に収まる」「大きさは IAF での対地速度で決まる」とだけ書く）は手元の資料に無いので、作らない（推測で作らない）。今の LNAV は PI の脚をその点で順送りし、次の脚（最終進入の IF・CF）へ進む（ND の線もそのとおり。ND の procedure turn の記号：FCOM p.1149、FMSPG p.51 も無い）。作るなら推定（手元に無い PANS-OPS の 45°/180° の形など）になる。
- CRS REVERSAL AT FA FIX（advisory：FCOM p.1435）：表示中の経路が最終進入点（FAF）に最終進入のコースと逆向きで来て（前の点からのコースと FAF からのコースが 90° を超えて違う：推定）、その前に FAF での procedure turn もホールドも無いとき。経路が変わるたびに確かめ、条件の間は CDU のメッセージ（CLR で消え、条件が一度消えるまで出ない）。
- 試験：`route_model_test.lua`（178 件：逆向きで来る・来ない、procedure turn やホールドがあれば出ない）、`hold_pages_test.lua`（82 件：PROC TURN、CRS REVERSAL AT FA FIX と CLR、procedure turn があれば出ない）。
- X-Plane：`s88_deparr` 26/26（DEPARTURES・ARRIVALS で手続きを入れても CRS REVERSAL AT FA FIX は出ない）、`s87_legs_pages` 29/29。Lua の誤りなし。

## 35. 段 7d の実装（2026-10-27：オフセット）

- 経路のモデル：オフセットは経路の値（`offset`、nm、右が正。修正の写しにも入る）。
  - OFFSET の入力（FCOM p.1298；FMSPG p.155–156）：アクティブな経路で空中、アクティブな脚がオフセットのかかる脚（SID・STAR・進入とその遷移の上でない）のとき、L か R の 1–99 nm。修正になり EXEC で有効。L0・0・R0・DELETE で消す（無いのに消すと INVALID DELETE：推定）。
  - DIRECT TO で消える（FCOM p.1299；FMSPG p.156）。PPOS のホールドで消える（FMSPG p.158）。
  - かかる脚（FMSPG p.155；FCOM p.1299）：アクティブな脚から、経路の終わり、discontinuity、STAR・進入（とその遷移）の最初の脚、DME の弧、ヘディングの脚、ホールド、135° 以上のコースの変化の手前まで。点へまっすぐの脚（FMC 自身の DIRECT と airway、DIRECT TO の脚、TF）だけ（推定）。最後の脚を順送りしたらオフセットは終わって消える（推定）。DIRECT TO の後もその脚に新しいオフセットを入れられる（FCOM p.1298：SID・STAR・遷移の上でなければ出す）。
- 経路の形のモデル `offset(path, d, n)`：かかる脚を d nm 右（左は負）の平行な線にする。線と線は二つのオフセットの線の交点（角：旋回の二等分線の上）でつなぐので、fly-by の旋回と順送りは経路と同じ作りのまま。最初の線は脚の始まりの横から、最後の線は点の横まで。その後は元の経路。経路そのものの要素は変えない（ND の線は元の経路）。
- LNAV：オフセットの線を飛ぶ（EXEC で捕捉の旋回：FCOM p.1298。今までの操舵則の切込み）。
  - 21 nm を超えるオフセットでは、その線と後の脚（戻り）の順送りの制限を 200 nm に（FCOM p.1298）。
  - 最後の線の終わりの 5 nm 手前から END OF OFFSET（alert：FCOM p.1431；FMSPG p.155）。
  - オフセットの線の誘導中は CDU の OFST 灯（新しい dataref `laminar/B747/fms/ofst_light`：FCOM p.1210。3D の CDU にはつないでいない：見た目の変更は承認が要る）。
  - オフセットが終わったら、次の脚（元の経路）へ切込んで戻る（戻り方は推定：資料に無い）。
  - PROGRESS 2 の XTK ERROR はオフセットの線から。
- RTE ページ：空中でオフセットのかかる脚の上なら、全ページの 6R に OFFSET（6L の上の線の右端に小字の OFFSET、値は R20・L5、無ければダッシュ：FCOM p.1298 の図）。1 ページ目では PERF INIT>・TAKEOFF> の代わり（推定）。
- ND：X-Plane の線は 1 本なので、元の経路（マゼンタの実線）だけを描く。オフセットの線（修正中は白の破線、実行後はマゼンタの破線：FCOM p.1298）は描かない。
- 前の LNAV のオフセット（`lnoffs` と `laminar/B747/autopilot/lnav/xtk_target`）は、どのページからも使われていない（段 6c から効かない）。そのまま残す。
- 試験：新しい `tests/fms/lnav_offset_test.lua`（16 件：R5 で右へ回り 150 秒以内に捕捉、25° まで、経路の 5 nm 右、角の二等分線で順送り、5 nm 手前で END OF OFFSET、オフセットの終わりで消えて D へ戻る、40 nm のオフセットで B を線から 21 nm を超えて順送り）、`path_model_test.lua`（126 件：オフセットの線と角、wide）、`route_model_test.lua`（199 件：かかる脚の範囲、入力と消え方）、`rte_pages_test.lua`（63 件：空中の 6R の OFFSET、R20・L0・X5・DELETE、地上では出ない）、`lnav_glue_test.lua`（24 件：R5 で XTK が 4 nm 左、右へのバンク、OFST 灯、L0 で戻る）。試験用の機体（`tests/lib/lnav_sim.lua`）が LNAV の経路を変える関数を受ける。
- X-Plane：新しい `s93_offset` 25/25（RJAA→XAC の脚の上で LNAV、空中の RTE の 6R に OFFSET と小字の見出し、R5 で EXEC：XTK がオフセットの線から 5.1 nm 左、右へのバンクの指令、OFST 灯、オフセットの線を捕まえて XAC の角を 0.14 nm 以内で回り、SPENS の横（経路の終わり）の手前で END OF OFFSET、DIRECT TO SPENS で OFST 灯が消え、RTE の OFFSET はダッシュ、SPENS へ直行。CDU と ND の写真：RTE の OFFSET R5、ND は元の経路の線で機体はその 5 nm 右）、`s86_rte_pages` 19/19、`s90_lnav` 30/30、`s89_route_sync` 26/26。Lua の誤りなし。初めの 2 回の `s93` の不合格は、シナリオの作り（LEGS を出さずに現用点を待った）と、DIRECT TO の脚にオフセットを入れられなかったこと（直した）。

## 36. 段 7e1 の実装（2026-10-27：REF NAV DATA）

- 段 7e は 4 つに分けて 1 つずつ入れる：7e1 REF NAV DATA、7e2 DIRECT TO の ABEAM PTS、7e3 FIX INFO、7e4 RTE 2 と RTE COPY。
- 資料：FCOM p.1355–1357（乗員から見える挙動）、FMSPG p.170–176、ATA34_2 p.547–548（保守マニュアル）。
- 行き方：INIT/REF INDEX の 1R の NAV DATA>（ここからだけ：FCOM p.1281）。前は X-Plane の DATABASE ページを見せていた。新しいページ `activepages/B744.fms.pages.refnavdata.lua`。
- IDENT（1L）：ページを選ぶたびにダッシュ（FCOM p.1355；FMSPG p.171）。ウェイポイント（出発地・目的地のターミナルの点も）・航法施設・空港・目的地の滑走路（RW06R の形：FMSPG p.171；ATA34_2 p.547）。同じ識別子が 2 つ以上なら SELECT DESIRED WPT（飛行機に近い順：FCOM p.1335；FMSPG p.175–176）。ほかの入力は NOT IN DATA BASE（ATA34_2 p.547）。DELETE は INVALID DELETE（FMSPG p.171）。IDENT は CDU ごと。
- 表示（FCOM p.1355–1356；FMSPG p.171–172；ATA34_2 p.547–548）：
  - FREQ：航法施設だけ。VOR・DME・LOC は 117.90 の形、NDB は kHz の整数（推定）。
  - LATITUDE・LONGITUDE：滑走路は閾値、空港は標点。
  - MAG VAR：航法施設。VOR は局の偏差（earth_nav.dat の slaved variation）、NDB・DME 単独・LOC はそこの偏差（最寄りの VOR の値：推定。FMC の偏差の表はデータに無い）。E15・W7 の形（推定）。
  - LENGTH：滑走路。CIFP に長さが無いので、閾値から反対側の閾値までの距離に両方の移設分を足す（推定：navdb の `runway_length`）。反対側が CIFP に無ければ空白。X-Plane のデータで RJAA 16R は 13,129 ft（実際は 4,000 m＝13,123 ft）。
  - ELEVATION：航法施設・空港・滑走路の閾値。ウェイポイントは見出しごと空白（FMSPG p.172）。FT は小字（FCOM p.1355 の図）。LENGTH も ft で FT を小字（推定）。
  - IDENT の下の見出し（FREQ・LATITUDE など）は点を入れたときだけ、IDENT のダッシュは 5 つ（推定）。
- NAVAID INHIBIT（4L・4R）：VOR・VOR/DME・VORTAC・DME を 2 局。VOR ONLY INHIBIT（5L・5R）：VOR を 2 局。上書きか DELETE で前の局の抑止を外す（FCOM p.1356；FMSPG p.172–173）。同じ識別子が 2 つ以上なら、種類の合うものだけで SELECT DESIRED WPT。ほかの種類（NDB など）は INVALID ENTRY、ダッシュの DELETE は INVALID DELETE（推定）。
- VOR/DME NAV（6R）：INHIBIT> で VOR/DME の位置の更新を抑止して ENABLE>、5L・5R に小字の ALL（VOR ONLY の入力は消える）。ENABLE> で戻り、5L・5R はダッシュ（FCOM p.1357；FMSPG p.173–174）。ALL の間の VOR ONLY の入力は INVALID ENTRY（推定）。
- 抑止は両方の FMC のもの（どの CDU でも同じ）。`B747_fmc_nav_inhibits()` で読める。
- 効き目と消し方は後の段：無線の位置の更新（段 10。今の FMC の位置は X-Plane の位置そのままなので、抑止は何も変えない）、飛行の終わり（段 9 の飛行段階）と長い電源断（段 11）で消すこと。資料の食い違い：ATA34_2 p.548 は VOR/DME NAV の状態が飛行の終わりと電源断を越えて残ると書き、FCOM p.1357・FMSPG p.173 は飛行の終わりで INHIBIT> に戻ると書く。乗員から見える挙動なので FCOM を採る（段 9 で入れる）。
- 緯度と経度の表示（`toDMS`）を、分の 1/10 の切り捨てから四捨五入にした（35.3 が N35`17.9 になっていた）。POS INIT・SELECT DESIRED WPT などにも効く。
- `B747_fmc_with_point` は候補の一覧も受ける（抑止の行は VOR・DME だけ）。シナリオの `op` に正規表現の `matches` を足した。
- 試験：新しい `tests/fms/refnavdata_pages_test.lua`（78 件：NAV DATA>、見出しとダッシュ、DME・VOR・NDB・LOC・ウェイポイント・空港・目的地の滑走路、SELECT DESIRED WPT、NOT IN DATA BASE、INVALID DELETE、選び直してダッシュ、抑止の入力・上書き・DELETE、VOR/DME NAV、右の CDU で同じ抑止）、`navdb_test.lua`（63 件：滑走路の長さ、X-Plane のデータの RJAA 16R）。
- X-Plane：新しい `s94_refnavdata` 38/38（成田の地上：INIT/REF INDEX の NAV DATA> で FMC の REF NAV DATA、NRE の FREQ 117.90・N35`46.9 E140`21.8・W7・153 ft、AKAGI は SELECT DESIRED WPT で近い方、目的地が無いと RW06R は NOT IN DATA BASE、RTE で RJBB を入れて選び直すと IDENT はダッシュ、RW06R の LENGTH 11,478 ft（3,500 m の滑走路）と ELEVATION 5 ft、NAVAID INHIBIT に NRE、VOR ONLY INHIBIT に XAC、INHIBIT> で小字の ALL と ENABLE>、右の CDU にも同じ抑止でそこから ENABLE>、左で DELETE。CDU の写真で配置と大字・小字を確かめた）、`s86_rte_pages` 19/19、`s85_navdb` 22/22。Lua の誤りなし。初めの `s94` の写真は操縦輪が CDU の左を隠していたので、隠して撮り直した。

## 37. 段 7e2 の実装（2026-10-27：DIRECT TO の ABEAM PTS）

- 資料：FCOM p.1333–1334、FMSPG p.136–139（ABEAM PTS）、FCOM p.1250（place/bearing/distance の点の名前）。
- 経路のモデル：
  - DIRECT TO の修正に ABEAM PTS>。ほかの変更（INTC CRS を含む）をすると消える（FCOM p.1334）。変更を `st.edits`（`M.edit` と INTC CRS で 1 つ増える）で数え、DIRECT TO の時の値 `st.dto_offer` と比べる。
  - 押すと（FMSPG p.136–137）：アクティブな経路の、現用点から DIRECT TO の点の前までの点を、直行の線（飛行機の位置から DIRECT TO の点への大圏）の上の真横に移し、DIRECT TO の点の前に、線に沿った順に入れる。横の距離が 700 nm を超える点は作らない。手続きの点は作らない（出発の手続きの最後の点と、到着の手続きの最初の脚の前の点は作る）。滑走路・ホールド・条件の脚からは作らない（推定）。真横が飛行機の後ろか DIRECT TO の点の先になる点は作らない（推定）。DIRECT TO の点が経路に無い（後ろに discontinuity）ときは、飛ばした点が無いので何も作らずに SELECTED（推定）。
  - 名前（FMSPG p.136；FCOM p.1250）：航法データの点の真横は、その点からの place/bearing/distance の点（頭 3 文字と 2 桁の番号：XAC01）。緯度経度の点の真横は緯度経度の点（N47W008 の形）。place/bearing/distance の点の真横は、その場所からの新しい点。番号は RTE 1 の 01–49 のうち、経路（アクティブと修正、通過した点も）に無い一番小さいもの（推定）。高度と速度の制限は持たない（FMSPG p.137）。風はまだ入力が無いので持たない（100 nm 以内なら持つ：FMSPG p.137）。
  - 最初の abeam の点の脚が DIRECT TO の脚（始点は EXEC の時の位置）になり、DIRECT TO の点は普通の DIRECT の脚になる。押した後は INTC CRS が無い（FMSPG p.139 の図では 6R が RTE DATA>：RTE DATA は段 8）。
  - X-Plane の FMS には緯度経度の行（28）で名前をつけて流す。ND の線と名前はそれ。
- LEGS ページ（FCOM p.1333；FMSPG p.138–139 の図）：DIRECT TO の修正の 1 ページ目の 4R（4 番目の点の制限の場所）に、上の行の右の破線（15–24 桁）と ABEAM PTS>。押した後は小字の ABEAM PTS と SELECTED。ほかの変更で消える。2 ページ目以降には出さない（推定）。
- LEGS の各点の見出しの距離を 14 桁目で終わるようにした（FCOM p.1330・p.1333、FMSPG p.137–139 の図。前は 17 桁目で右の制限の列に入り、ABEAM PTS の破線と重なる）。
- RTE COPY>（5R）は段 7e4（RTE 2 と一緒に）。
- 試験：`route_model_test.lua`（222 件：飛ばした点の真横、名前と番号、直行の線の上と直角、制限なし、押した後の INTC CRS の不可、EXEC の始点、X-Plane の行、ほかの変更と INTC CRS で消える、経路に無い点への DIRECT TO、手続きの点、緯度経度の点、700 nm）、`legs_pages_test.lua`（56 件：破線と ABEAM PTS>、押すと CHA01、SELECTED、INTC CRS が消える、EXEC、X-Plane の FMS、ほかの変更で消える、距離の位置）。
- X-Plane：新しい `s95_abeam` 23/23（RJAA→XAC の脚の上で LNAV、経路 XAC・KOUGA・SPENS・SAGRA。DIRECT TO SAGRA の 4R に破線と ABEAM PTS>、INTC CRS 279°>。押すと XAC01（9 nm）・KOU02・SPE03・SAGRA と ABEAM PTS SELECTED、INTC CRS が消える。EXEC で LNAV が直行の線を飛び（XTK 0.02 nm 以内）、XAC01 を順送りして ND の現用点が KOU02。CDU と ND の写真：LEGS の距離の位置、4R の表示、ND の線の上の KOU02・SPE03）、`s87_legs_pages` 29/29。Lua の誤りなし。

## 38. 段 7e3a の実装（2026-10-27：自分で作る点の入力）

- 段 7e3（FIX INFO）は 2 つに分ける：7e3a 自分で作る点の入力、7e3b FIX INFO のページ。FIX INFO で作る点を経路に入れる（FCOM p.1359）には、RTE と LEGS のページが乗員の定義する点を受ける必要がある（FCOM p.1245：緯度経度、place/bearing/distance、place bearing/place bearing で入れられる）。
- 緯度経度（FCOM p.1250）：N47W008（度だけ）か N4715.4W00803.4（分を 1/10 まで）。緯度と経度は別々にどちらの形でもよい。名前は度の 7 文字（N47W008）。
- place/bearing/distance：SEA330/10、ABC180.0/026.4（FIX INFO の写しの形：FCOM p.1359）。place bearing/place bearing：SEA240/OLM320。
  - 方位は磁方位で、場所の偏差（最寄りの VOR の値）で真方位にする（推定）。000–360、小数 1 桁まで。距離は 0 より大きく 999.9 nm まで（推定）。
  - 場所は航法データの点。1 つ目は SELECT DESIRED WPT（前の点の近い順）、2 つ目は 1 つ目に近いもの（推定）。2 本の方位線が前で交わらなければ INVALID ENTRY（推定）。
  - 名前は場所の頭 3 文字と番号（SEA01：FCOM p.1250。番号は段 7e2 の abeam の点と同じ、経路に無い一番小さいもの）。
- 経路にある乗員の点は、その名前で入れ直せる（SEA01、N47W008：候補に経路の点を足した）。
- REF NAV DATA の IDENT と FIX INFO の FIX は航法データの点だけ（FCOM p.1355、p.1358）なので、これらの形は受けない。
- 試験：`route_model_test.lua`（237 件：緯度経度の形、PBD・PB/PB の形と不可の入力、点の位置、番号、名前で入れ直す、方位線の交点、交わらない方位線）、`legs_pages_test.lua`（63 件：N3700.0E14100.0、ALPHA097/10（ALPHA が 2 つあるので場所の SELECT DESIRED WPT）、ALP02 を名前で、データに無い場所、交わらない方位線）。
- X-Plane：`s95_abeam` 26/26（段 7e2 の確認の後、LEGS の経路の終わりの後に N3442.0E13800.0 で N34E138、SPENS180/10 で SPE04（XAC01・KOU02・SPE03 の次の番号）、ERASE。CDU の写真で確かめた）、`s86_rte_pages` 19/19。Lua の誤りなし。

## 39. 段 7e3b の実装（2026-10-27：FIX INFO）

- 資料：FCOM p.1358–1359、FMSPG p.166–169。
- FIX キーで FMC の FIX INFO（前は X-Plane の FIX ページ）。2 ページ（NEXT・PREV）に FIX をひとつずつ。データは FMC のもので、両方の CDU で同じ（推定）。新しいページ `activepages/B744.fms.pages.fixinfo.lua`、経路との交点は経路のモデル（`fix_path`・`fix_radial`・`fix_circle`・`fix_abeam`）。
- FIX（1L）：航法データの空港・航法施設・ウェイポイント（FCOM p.1358）。箱、SELECT DESIRED WPT（飛行機に近い順）、NOT IN DATA BASE。DELETE は不可（消すのは <ERASE FIX だけ：FMSPG p.167）。空の scratchpad で FIX を写す。新しい FIX で BRG/DIS と ABEAM は消える（推定）。
- BRG/DIS FR（1R）：飛行機の FIX からの方位と距離。
- BRG/DIS（2L–4L）：方位 XXX（000–360）、距離 /YYY（1–999）、両方 XXX/YYY（FCOM p.1358–1359）。
  - 方位：FIX からの線がアクティブな経路と FIX から 512 nm 以内で交われば、その距離を / の後に小字で（FMSPG p.167）。
  - 距離：円が経路と交われば、近い方の交点の方位を / の前に小字で（FCOM p.1358 の図）。
  - DTG：飛行機から経路に沿った交点までの距離、通り過ぎたら負（FMSPG p.168）。方位と距離の両方を入れたものは交点を出さない（FCOM p.1359）。
  - 空の scratchpad で、その place/bearing/distance を写す（ABC180.0/026.4 の形：FCOM p.1359 の図）。RTE・LEGS に点として入れられる（段 7e3a）。DELETE でダッシュに戻る。
- <ABEAM（5L）：経路の一番近い区間に直角な点の方位と距離、DTG。無ければ INVALID ENTRY（FMSPG p.168）。もう一度押すと place/bearing/distance を写す（FCOM p.1359）。DELETE でプロンプトに戻る。
- <ERASE FIX（6L）：そのページの FIX と線を消す。PRED ETA-ALT は残す（FMSPG p.168）。FIX が無いときは出さない。
- PRED ETA-ALT（6R）：時刻 hhmmZ か高度を入れて表示（FMSPG p.169）。予測の距離は段 8 の後。
- 経路の形はアクティブな脚の始まりから、点の大圏を discontinuity まで（条件の脚とホールドは入れない：推定）。交点が二つ以上なら、飛行機に経路に沿って一番近いもの（推定）。
- 方位は磁方位：VOR はその偏差、ほかは最寄りの VOR の値（推定）。極地方の真方位（FMSPG p.166）は段 10。
- 後の段と推定：ETA・ALT と PRED ETA-ALT の距離は予測（段 8）まで空白。ND に FIX の円・方位線・距離の円を描かない（X-Plane の地図は経路だけ）。距離に交点が無いと方位を出さない、FIX が無いと BRG/DIS の行を出さない（推定）。
- 試験：`route_model_test.lua`（251 件：経路の形、ABEAM、方位線、距離の円、届かない・交わらないもの、通り過ぎた交点の負の DTG）、新しい `tests/fms/fixinfo_pages_test.lua`（46 件：FIX キー、箱と見出し、FIX の入力と写し、BRG/DIS FR、方位線と距離の円の交点と DTG、両方の入力、不可の入力、DELETE、写しを LEGS に入れて ZB001、ABEAM と写し、ERASE FIX、PRED ETA-ALT、2 ページ目、右の CDU）。
- X-Plane：新しい `s96_fixinfo` 25/25（RJAA→XAC の脚の上で LNAV、経路 XAC・SPENS・SAGRA。FIX キーで FIX INFO、FIX に KOUGA：BRG/DIS FR 032/35、方位 360 の線と XAC→SPENS の脚との交点（小字の 22 nm、DTG）、距離 /30 の近い方の交点（小字の方位 029、DTG）、<ABEAM で 007/22 と DTG、もう一度押して KOUGA007.5/021.9 の写し、LEGS の経路の終わりの後に入れて KOU01、PRED ETA-ALT の 1234Z、<ERASE FIX で箱（PRED ETA-ALT は残る）、2 ページ目の箱。CDU の写真で小字と配置を確かめた）、`s94_refnavdata` 38/38。Lua の誤りなし。初めの `s96` の 1 件の不合格は、scratchpad の行の末尾に空白があるとしたシナリオの正規表現の誤り（値は正しかった）。

## 40. 段 7e4 の実装（2026-10-27：RTE 2 と RTE COPY）

- 資料：FCOM p.1287–1294、p.1296、p.1299–1300、p.1330、p.1334、FMSPG p.134–136、FCOM p.1250（番号）。
- 経路の状態を二つにした：RTE 1 と RTE 2（`num` 1・2）。結線の `B747_fmc_route` はいつもアクティブな経路（アクティブが無ければ RTE 1）、もう一つが `B747_fmc_route2`。もう一つの経路を ACTIVATE して EXEC すると、二つの中身を入れ替え（`swap`）、その経路がアクティブ、前の経路はアクティブでなくなる（FCOM p.1290）。LNAV・X-Plane の FMS（ND の線）・HOLD・FIX INFO・REF NAV DATA は `B747_fmc_route`（アクティブな経路）を見るので、そのまま。`B747_fmc_route_num(n)` で RTE n の状態を引く。
- EXEC：アクティブな経路の修正か ACTIVATE、無ければもう一つの経路の ACTIVATE（`exec_both`）。EXEC 灯はどちらかに実行待ちがあれば点く。
- RTE ページ（FCOM p.1287–1296）：RTE1・RTE2 の二つのページを同じコードで作る。題名 RTE n・ACT RTE n・MOD RTE n。6L は修正中は <ERASE、それ以外はもう一つの経路の <RTE 2・<RTE 1（全ページ：FCOM p.1289、p.1296 の図）。1 ページ目の破線は 8 行目（FCOM p.1288・p.1293 の図。前は 6L の上）、2 ページ目以降は 6L の上（p.1296 の図。前は空白）。アクティブでない経路は直接変わる（MOD にならない）。空中の ORIGIN はアクティブでない経路だけ（FCOM p.1288）。
- RTE COPY（FCOM p.1289）：アクティブな経路の 1 ページ目の 5L に <RTE COPY。押すと、アクティブな経路（修正でないもの）をもう一つの経路に写し（前の中身は消える）、COMPLETE（その上に小字の RTE COPY：推定）。アクティブな経路が次に変わるまで COMPLETE（推定）。
- LEGS ページ：LEGS・LEGS2 を同じコードで。題名 RTE n LEGS。6L は修正中は <ERASE、それ以外は <RTE 2 LEGS・<RTE 1 LEGS（FCOM p.1330 の図）。DIRECT TO・ABEAM PTS・INTC CRS・HOLD AT はアクティブな経路のページだけ。DIRECT TO の修正の 1 ページ目の 5R に RTE COPY>（FCOM p.1334；FMSPG p.135）。押すと写して、小字の RTE COPY と COMPLETE（FMSPG p.136 の図）。ほかの変更で消える。ABEAM PTS> は残る（図）。
- RTE・LEGS・DEP ARR キーと ROUTE>（POS INIT・FMC COMM・TAKEOFF REF・DEPARTURES・ARRIVALS）はアクティブな経路のページへ（FCOM p.1287：RTE 2 がアクティブでも同じ）。HOLD の題名は RTE n HOLD。
- DEP/ARR（FCOM p.1299–1300）：INDEX に RTE 1 と RTE 2 の行（DEP は出発地、ARR は目的地。アクティブな方に (ACT)）。DEPARTURES・ARRIVALS は INDEX で選んだ経路（DEP ARR キーではアクティブな経路）のもの、題名の小字に RTE n。出発地の ARR（離陸後の引き返し）と OTHER はまだ。
- place/bearing/distance の点の番号：RTE 2 は 51–99（FCOM p.1250）。
- 古いコードの X-Plane の RTE 2 ページへの切り替え（setpage の RTE2 で X-Plane の DIR INTC キー）を外した。
- 試験：新しい `tests/fms/rte2_pages_test.lua`（46 件：<RTE 2・<RTE 1、RTE 2 の入力、<RTE 2 LEGS、RTE COPY と COMPLETE、RTE 2 だけの変更、RTE 2 の ACTIVATE と EXEC、X-Plane の FMS、RTE・LEGS キー、DIRECT TO の RTE COPY>、ALP51、DEP/ARR INDEX の RTE 2）、`rte_pages_test.lua`（63 件：1 ページ目の破線の位置）。
- X-Plane：新しい `s97_rte2` 31/31（成田の地上：RTE 1 の 1 ページ目の破線が 8 行目、<RTE 2 と ACTIVATE>、RTE 1 を有効にして 5L の <RTE COPY で COMPLETE、<RTE 2 で写した RJAA→RJBB、RTE 2 にだけ SAGRA（題名は RTE 2 のまま）、ACTIVATE で EXEC 灯、EXEC で ACT RTE 2 と EXEC 灯の消灯、RTE 1 は ACTIVATE> に戻る、RTE・LEGS キーは ACT RTE 2 へ、<RTE 1 LEGS、DIRECT TO SPENS の 5R の RTE COPY> で COMPLETE、写された RTE 1 に SAGRA、DEP ARR キーで RTE 2 の DEPARTURES、INDEX の RTE 2 (ACT) の行。CDU の写真で確かめた）、`s86_rte_pages` 19/19、`s87_legs_pages` 29/29、`s88_deparr` 26/26、`s93_offset` 25/25（1 ページ目の破線の確かめを 8 行目に）。Lua の誤りなし。

## 41. 段 7f の実装（2026-10-27：procedure turn の形・推定）

- 利用者の依頼（2026-10-27「後でprocedure turnも推定で作ってよ」）。§34 で資料に形が無いので作らなかった procedure turn（PI）の形を、推定で作る。FCTM p.150（空域の制限に収まる、大きさは対地速度で決まる）に合わせる。
- 形（推定：PANS-OPS の 45°/180° の procedure turn）：
  - PI の点から入航コースの逆（出航コース）へ出る。出航コースは PI の脚のコース（ARINC 424 の PI の outbound course＝45° の脚のコース）から、旋回の向きと反対へ 45°。例：RJSM の ILS28-Z の GABII（PI 058°、右旋回、15 nm）は出航 103°、入航 283°。
  - 出航から 45° の脚への 45° の角は、旋回と同じ半径の fly-by の弧で回る（角の前後 r·tan 22.5° で接する）。
  - 45° の脚（PI の脚のコース）を 1 分 15 秒（PANS-OPS の category C–E）。
  - PI の旋回の向きに 180°（25° のバンクの半径）。
  - 45° の脚の逆のコースで戻り、入航コースへ 45° で切込む。
  - 出航の長さは、180° の旋回の一番遠い所が PI の距離（ARINC 424 の route distance＝"remain within"。無ければ 10 nm）の 1 nm 内側に収まる長さ（0 以上）。
- 経路の形のモデル：PI の要素（`pturn`）。形は `M.pturn(e, kt)`。要素の終わり（次の脚の始まり）は 210 kt（ND の記号と同じ速度）の形の、戻りの脚と入航コースの交点（推定）。
- LNAV：PI の前の脚は PI の点を fly-over（fly-by にしない）。PI の点を通った時の速度（TAS＋風）で形を作り、出航・角の弧・45° の脚・180° の旋回・戻りの順に誘導する（ホールドと同じ作り。角の弧と 180° の旋回は、ホールドの旋回と同じくロールの 4 秒だけ早く始める）。戻りの脚で、入航コースへの 45° の旋回を始める所（旋回の先行距離＋ロールの 4 秒）で順送りし、次の脚（CF など）が捕捉して入航コースに乗る。段階は新しい dataref `laminar/B747/fms/lnav/pturn_phase`（0 無し、1 出航、2 角の弧と 45° の脚、3 180° の旋回、4 戻り）。
- ND の線：PI の点の後に形の点（出航の終わり、45° の脚の終わり、旋回の 30° ごとの点、旋回の終わり、入航コースとの交点）。LNAV が飛んでいる間はその形、ほかは 210 kt の形。
- 試験：`path_model_test.lua`（134 件：PI の要素の 45° の脚・出航コース・制限、形の一番遠い点、交点、左右、ND の点）、新しい `tests/fms/lnav_pturn_test.lua`（17 件：閉ループで段階の順、10 nm の内側、右と左の旋回、25° まで、出航・角・45° の脚と 180° の旋回で形から 0.2 nm 以内、入航 270 に乗って CF へ、0.3 nm 以内、X-Plane の行、15 nm で長い出航）。
- X-Plane：新しい `s98_pturn`（三沢の西で RJSS→RJSM、ILS28-Z の遷移 GABII：PI 058°・右・15 nm、DIRECT TO GABII と LNAV）。1 回目 15/16：出航から 45° の脚への角に旋回の先行が無く、XTK が最大 0.71 nm 外へふくらんだ（閉ループの試験でも 0.62）。角を fly-by の弧にし、角と 180° の旋回をロールの 4 秒だけ早めて直した。2 回目 16/16：XTK は出航〜45° の脚で最大 0.055 nm、180° の旋回で 0.148 nm、戻りの脚で 0.14 nm、入航コースで 0.031 nm 以内、DTK 275（真）。許容は 0.3・0.3・0.5・0.3 nm に締めた。`s90_lnav` 30/30。Lua の誤りなし。

## 42. LEGS の PLAN の CTR と STEP（2026-10-28〜29：ND の PLAN の中心）

- 資料：FCOM p.1333 の 9・10（ND が PLAN のとき、PLAN の中心の点の横に <CTR>。6R の STEP（ACTIVATE・RTE DATA の代わり）で <CTR> が次の点へ進み、PLAN の中心が移る）、p.1039（ND の PLAN）、p.1330 の図（`BANDR   <CTR>`：<CTR> は 9 桁目から、区切り線の端に小字の MAP CTR）、FMSPG p.124（ACT RTE LEGS で ND が PLN のとき 6R に STEP>。LEGS キー・PREV PAGE・NEXT PAGE で、表示したページの最初の点が中心。PLN でないときのアクティブでない LEGS は 6R が ACTIVATE>）。
- 作り方は利用者の決定（2026-10-28、(b)）：FMS ブリッジ（§23）の `laminar/B747/fms/xp/displayed`（X-Plane の FMS の項目、1 から）に中心の点の行を書き、プラグインが XPLMSetDisplayedFMSEntry を X-Plane のスレッドで呼ぶ。プラグインは変えていない。ND（`B747.61.xt.nd.lua` の `updateNDLatLong`）は X-Plane の表示中の項目（`xtlua/xpFMSData` の [1]：XTLua の xpmtdatarefs.cpp で表示中の項目 + 1、ブリッジの `displayed` と同じ数え方）を PLAN の記号の中心にし、X-Plane の地図の層も同じ点を中心に描くので、両方がそろう。前は X-Plane の表示中の項目を動かす手段が無く（`xtlua/xpFMSData` への書き込みは INOP）、中心は X-Plane の FMS のまま動かなかった。
- CDU と ND の組：右の CDU は副操縦士の ND、左と中央の CDU は機長の ND（EFIS CONTROL のページと同じ）。その ND が PLN（つまみ 3）のときだけ <CTR> と STEP> を出す。
- 中心は FMC に 1 つで、ある経路（番号）の脚を指す（`legs.lua` の `planCtr`）。X-Plane の表示中の項目は 1 つなので、両席の ND の PLAN は同じ中心になる（実機は CDU ごと：DIFFERENCES に書いた）。
- LEGS のページ：
  - <CTR> は 9 桁目から（8 文字以上の名前は 1 字あけて）。制限の文字が長くて入らないとき（FL のある block の制約）は出さない（推定）。
  - 6R の STEP>：ACTIVATE と RTE DATA の代わり（RTE DATA は未実装で、前から空き）。区切り線を 17 桁目までにし、その端に小字の MAP CTR。DIRECT TO の INTC CRS がある間は INTC CRS のまま（推定）。RTE LEGS HOLD AT のページは変えない。
  - 6R の振り分け（`legsr6`）：ページのキーの表は 3 台の CDU で共用なので、押した CDU に合わせてその場で INTC CRS・STEP・ACTIVATE に振り分ける（前は最後に描いた CDU で表が書き換わっていた）。どれにも当たらなければ前と同じ KEY/FUNCTION INOP。
- 中心の動き（`legs.lua`）：
  - STEP：次の点へ進め、ページもついていく（推定）。最後の点では動かない（推定）。discontinuity と未確定の脚は飛ばす。VECTORS の脚は中心にできる（FMSPG p.124 の図）。
  - LEGS キー・NEXT PAGE・PREV PAGE：表示したページの最初の点が中心（FMSPG p.124）。ページに点が無ければ（経路の終わりの破線だけのページ）、中心は動かない（推定）。NEXT は最後のページで 1 ページ目へ（前と同じ）。6L の <RTE x LEGS では中心を動かさない。
  - ND を PLN にしたとき（`B747_cdu_plan_ctr_update`、毎フレーム）：その CDU に LEGS が出ていれば、そのページの最初の点（推定。副操縦士の側でも中心を動かす）。中心がまだ無ければ、アクティブな経路の最初の点。
  - 中心の点が通過や削除で消えたら、その位置からの次の点（推定）。修正（MOD）の写しや、修正が消えたあとは同じ点（経路のモデルの `same_leg` を外に出した）。
- X-Plane の行（`B747.68.xt.fms.lua` の `B747_fmc_plan_ctr_sync`、`after_physics` で `B747_fmc_route_sync` の次）：中心の脚の行（`routeMap.row`）。MOD やもう一つの経路の中心では、X-Plane の計画（アクティブな経路）にある同じ点の行を使い、無ければそのまま。進入復行の脚と、終点を予測していない条件の脚には行が無い（§22：X-Plane の計画に書かない）ので、それを中心にしても ND の PLAN の中心は前の点のまま（違い）。ND のどちらかが PLN で、ブリッジがあり、最後に流した計画を X-Plane が持っているときだけ書く。違うときだけ書き、同じ値の書き直しは 1 秒あける。
- 試験：新しい `tests/fms/legs_plan_ctr_test.lua`（63 件：MAP では前のまま・X-Plane に書かない、副操縦士の PLN で現用の経路の最初の点、機長の PLN で表示中のページの最初の点、PREV で 1 ページ目、9 桁目の <CTR>・STEP>・17 桁目までの区切り線・小字の MAP CTR、右の CDU はそのまま、STEP で次の点と表示中の行、ページ送り、最後の点、NEXT と LEGS キー、制限つきの <CTR>、block の制約、両席の PLN で 1 つの中心と右の STEP、機長の MAP、空中で右の CDU から ACTIVATE と EXEC、DIRECT TO の INTC CRS と修正の中の中心、ERASE、現用点の順送り）。`tests/run.sh` は 120 ファイルとも合格。
- X-Plane（2026-10-29）：新しい `s111_legs_plan_ctr`（s110 と同じ EDDM 26R の進入路の上、EDDF 25C から EDDM・ILS26R を EXEC）。1 回目 46/47：この経路は 5 点（FI26R・RW26R・D261A・(1900)・MIQ）で 2 ページ目が終わりの破線だけになり、NEXT で中心が動かないのを作りどおりと確かめた（シナリオの期待の誤り。点の無いページの扱いを推定として書いた）。2 回目 51/51：MAP では <CTR> も STEP> も無い、機長の ND を PLN にすると X-Plane の地図が PLN、`FI26R   <CTR>     /5000A`・STEP>・17 桁目までの区切り線と小字の MAP CTR、表示中の点は現用点の行 4、STEP で RW26R と行 5、もう一度の STEP で進入復行の D261A（行は 5 のまま）、NEXT で 2 ページ目（中心は動かない）、PREV と LEGS キーで FI26R と行 4、副操縦士の ND を PLN にして右の CDU にも <CTR> と STEP>、右の STEP で両方の CDU の <CTR> が RW26R へ、ND を MAP に戻すと STEP> が消える。ND の写真で、PLAN の中心が FI26R、STEP の後は RW26R に移り、点の記号と X-Plane の地図の経路の線がそろうことを確かめた。CDU の写真は FCOM p.1330 の図の配置。`s87_legs_pages` 29/29、`s89_route_sync` 26/26、`s95_abeam` 26/26、`s97_rte2` 31/31、`s110_nd_map_ctr` 45/45、`s70_nd_airports` 39/39。Lua の誤りなし。

## 43. 段 8 の段取り（2026-10-31：性能 DB と予測）

- 今のコード（2026-10-31 の調べ）：
  - ECON：CI を使うのは巡航 Mach の経験式だけ（AP `B747.70.xt.autopilot.vnavspd.lua` の `clb_crz_setSpd`：LRC＝388.2＋0.6203·GW[t]＋7.806·高度[kft] の千分率、CI 230 で LRC）。上昇・降下の速度は既定の文字列（.805/270 など）。MCP の Mach を書くだけで、CRZ の ECON SPD は変わらない（FMC-11）。
  - OPT・MAX：重量の一次式（`B744.fms.pages.vnav.lua` の CRZ と `vnav.lrc.lua`）。STEP は常に CRZ＋2,000 ft、STEP SIZE は表示が "ICAO" の文字だけ（FMC-19）。
  - T/C・T/D・E/D：AP の `setDistances`（約 2 秒ごと）。T/C は今の V/S から、E/D は目的地 10 NM 以内の最初の点、T/D は E/D から 290 ft/NM（FMC-12）。前の VNAV の降下（`vnav.lua`）と監視（`monitor.lua`）がそれを読む。
  - 燃料と ETA：ETA は距離 ÷ max(275 kt, GS)、CRZ の目的地の燃料は 51.6 lb/NM の経験式、PROGRESS は今の燃料流量 × 時間（FMC-20）。LRC のページの T/D の時刻は PC の時計（`os.date("%H%I")`、%I は時）。
  - LEGS の小字の予測、RTE DATA、DESCENT FORECAST、点ごとの風は無い（`refonly/` の型紙だけ：FMC-25）。
  - 性能のページは X-Plane の重量（`m_total`）を使い、PERF INIT の GR WT を使わない。
- 資料：
  - PW4056（109。RR は資料が無いので PW を使う：推定）：PI.11.1〜11.6（p.267–273）の最大運用高度と最適高度（重量 × ISA 偏差 × buffet の余裕）、LRC の制御（重量 × 高度ごとの EPR・Mach・KIAS・燃料流量）、区間の燃料と時間（計画用）、風と高度の交換、.84/290/250 の降下の距離と時間、待機（重量 × 高度ごとの EPR・KIAS・燃料流量）。
  - CF6-80C2B1F：PI.21（p.363–369）は 747-400F（FAA）の表で、重量は 1000 lb。GE は 570（貨物機）なので、そのまま使う。
  - 上昇の表は無い（PI.10.38 の速度計が使えないときの上昇の姿勢と V/S だけ：`tests/flight/tools/aero_compare.lua`）。ECON の CI の表も無い。最大上昇 EPR は EEC のモデルにある。
  - FCOM p.1257–1264（VNAV の性能）、p.1311（CRZ の高度）、p.1348–1366（CLB・CRZ・DES・RTE DATA・DESCENT FORECAST）、p.1371–1378（PROGRESS）。
- 方針：純粋なモデルを 2 つ作る。性能 DB（`B747.68.perf_db.lua`：PI の表と補間）と予測（`B747.68.pred_model.lua`：経路に沿った上昇・巡航・降下の軌跡）。前の VNAV（AP の `setDistances` と降下の則）は段 9 で置き換え、段 8 の予測が段 9 の降下パスの元になる。重量は FMC のもの（PERF INIT の ZFW＋燃料。入れる前は X-Plane の重量）。
- 小段：
  - 8a：性能 DB。PI の表を型式ごとに（PW4056、CF6 は lb を kg に）、補間（重量と高度の双線形、表の外は端で止める）：LRC（Mach・KIAS・燃料流量）、最適高度、最大高度（ISA 偏差・buffet の余裕 1.3 g が既定）、待機（KIAS・燃料流量）、.84/290/250 の降下の距離と時間、風と高度の交換。CRZ・LRC のページの OPT・MAX をこれに（FMC-19 の一部）。
  - 8b：ECON の速度（CI → 上昇・巡航・降下の速度：表が無いので LRC を元にした推定）、CRZ のページ（ECON SPD、LRC、OPT・MAX・RECMD、STEP TO と STEP SIZE、UNABLE CRZ ALT）、CLB・DES の ECON（FMC-11、FMC-19）。
  - 8c：軌跡の予測。上昇（PI.10.38 の V/S と最大上昇 EPR からの推定の模型）、巡航（LRC の表の燃料流量、Mach が LRC から外れたときは推定）、降下（.84/290/250 の表、アイドルの燃料流量は推定）、高度と速度の制限、T/C・T/D・E/D・S/C、点ごとの高度・速度・ETA・燃料（FMC-12 の予測の側、FMC-20）。
  - 8d：表示。LEGS の小字の予測、RTE DATA、PROGRESS（点と目的地の ETA・燃料、TO T/C・T/D）、ND の T/C・T/D（S/C・E/D の記号は DSP-23 の残り）。
  - 8e：点ごとの風（RTE DATA の入力、伝搬と補間）と DESCENT FORECAST、それを予測に。
- 推定になるもの：ECON の CI と速度の関係、上昇の燃料と時間、LRC から外れた Mach の燃料流量、降下の燃料、RR に PW の表、FL450 より上と表の外の重量。各小段で X-Plane の記録（カスタム acf）と比べる。

## 44. 段 8a の実装（2026-10-31：性能 DB）

- 性能 DB（新設の `B747.68.perf_db.lua`、純粋なモデル）：FCOM PI の表を描いた頁から読んで打ち込んだ。
  - PW4056（109。RR は資料が無いので PW の表：推定）：PI.11.1 最大運用高度と最適高度（p.267：重量 12 段 × buffet の余裕 1.20〜1.50 g × ISA+10 以下・+15・+20、推力で決まる値の印）、PI.11.2 LRC の制御（p.268：重量 11 段 × FL270〜450 の EPR・Mach・KIAS・1 発の燃料流量 kg/h）、PI.11.5 風と高度の交換と .84/290/250 の降下の距離と時間（p.271）、PI.11.6 待機（p.272：EPR・KIAS・燃料流量、racetrack の 5 % 込み）。
  - CF6-80C2B1F（570）：PI.21 は 747-400F（FAA）の表で、重量と燃料が lb（p.363、p.364、p.367、p.368）。kg に直して使う。推力の値は %N1。
  - 補間：重量と高度の双線形。表の外は端で止める（重い重量の高い高度は、その重量の表の最も高い所）。降下の表より低い所は、表の最も低い高度の値に比例（推定）。最大高度の ISA 偏差は +10 以下・+15・+20 の間を直線で、+20 より上は +20。buffet の余裕は既定 1.3 g（推定：FMC の保守のページの MNVR MARGIN 1.20〜1.30）。最大高度が届く重さ（`max_alt_weight`）は二分探索。
  - 区間の燃料と時間の表（p.269–270）は計画用なので入れていない（8c の予測の確かめに使う）。
- FMC（`B747.68.xt.fms.lua`）：性能 DB を読み込み、型式（`laminar/B747/engines/type`）の表を選ぶ `B747_fms_perf()` と、気圧高度の外気の ISA 偏差 `B747_fms_isa_dev()`。
- CRZ のページ（`vnav.lua` の 2 頁）：OPT・MAX を表から（前は FCOM p.1576 に合わせた重量の一次式、ISA+10 以下だけ）。STEP の点の「MAX が STEP の高度に届く重さ」も表から。%N1 と STEP の作り直しは 8b。
- LRC のページ（`vnav.lrc.lua`）：LRC の Mach を巡航高度と重量で表から（前は一次式）、先頭の 0 を出さない（.861）。OPT・MAX も表から。T/D の時刻は X-Plane の UTC から（前は PC の時計で、`%I` を分の代わりに使っていた）。
- 重量は今までどおり X-Plane の `m_total`（FMC の重量にするのは 8b・8c）。
- 試験：
  - 回帰（LuaJIT）：新設の `tests/fms/perf_db_test.lua` 36 件（表の升と升の間と端、PW と GE、RR は PW、最大高度の推力で決まる印と ISA 偏差と余裕、待機、降下、風の係数、最大高度が届く重さ）。全 123 本。
  - X-Plane（カスタム acf）：新設の `s128_fmc_perf_db`（空中、10,000 ft）5/5：CRZ のページの OPT・MAX が FL361・FL403、CRZ ALT を FL350 にした LRC のページの Mach が .848、T/D の時刻が X-Plane の UTC（0100）。どれも、その時の重量（270 t）と外気温（ISA 偏差 0°）から性能 DB で求めた値と同じ。Lua の誤りなし。

## 45. 段 8b1 の実装（2026-10-31：ECON の速さ）

- 段 8b を 2 つに分けた。8b1：巡航の模型、ECON の速さ、SEL SPD と <ECON・LRC>、CLB・DES のページ、自動操縦が FMC の速さで飛ぶこと。8b2：CRZ のページ（EPR/N1、STEP SIZE・STEP TO・AT、ECON の OPT、MAX ALT のメッセージ）。
- 資料：
  - CI：時間の費用（$/h）÷ 燃料の値段（¢/lb）。1 につき燃料 100 lb/h（FMSPG p.261）。CI 0 は最大航続（FCOM p.1257）。
  - ECON 巡航は重量・巡航高度・CI・向かい風で変わる。向かい風で速く、追い風で遅く、ただし無風の最大航続より遅くしない。LRC は最大の 99 % の燃費で、風の補正なし。CI 5000 以上でおおむね推力か速度の上限に当たる（FCTM p.4.7）。
  - ECON 上昇は CAS 一定・Mach 一定。Mach は巡航高度での ECON 巡航の Mach、CAS は重量・CI など。巡航高度が低ければ巡航の速さまで上げる（FCTM p.4.3）。FMC が使えないときの ECON 上昇は 340 kt/.84、最大上昇率はおよそフラップ上げの maneuver + 60 kt（FCTM p.4.4）。PI.10.36 の最大上昇 EPR の表も 340/.84。
  - 降下：ECON の目標は 349 kt（VMO/MMO − 16 kt）まで、乗員の速さは 354 kt（− 11 kt）まで（FCOM p.1258）。標準の降下は .84/290/250（PI.11.5）。
  - ページ：CLB の ECON SPD は CAS/Mach（FMSPG p.113 の例 358/.853）。入力は CAS 100〜400、Mach（小数点と 1〜3 桁、.100〜.990）、CAS/Mach か Mach/CAS。乗員の入力で SEL SPD、<ECON（5L）で戻す。CRZ は ECON SPD・SEL SPD・LRC SPD（CAS か Mach：FCOM p.1348）、<ECON（5L）、LRC>（6R）。DES は Mach/CAS、SEL SPD と <ECON（5L：FMSPG p.192–193）。表題は ECON・XXXKT・M.XXX・LRC（FCOM p.1327、p.1347、p.1391）、上昇は SPD TRANS・RESTR の下ではその速さ（FMSPG p.112：ACT 250KT CLB）。
- 巡航の模型（`B747.68.perf_db.lua` に足した、推定）：
  - CD = CD0 + K CL² + KW (M − MC)⁴（MC = MC0 − MCL CL、その上で）+ KD (M − MD)⁴（抗力発散、MD の上で）。燃料流量 = (T0 + T1 M)(1 + T2 · 100 kN ÷ (F/δ)) √θ · F（F は 1 発の推力、T2 は部分推力で消費率が上がる分）。
  - 合わせ込み（新設の `tests/tools/perf_fit.lua`、Nelder–Mead、型式ごと）：LRC の燃料流量（表の Mach で）、待機の燃料流量（racetrack の 5 % を除く。推力の上限近くの升は除く）、LRC の Mach（模型の最大航続の 99 % の燃費の速さ）。燃料流量だけでは抗力と消費率の比が決まらないので、抗力の大きさは速度計が使えないときの .84/290 のアイドル降下の V/S（PI.10.39・PI.20.33。速さの変化の分を補正し、アイドルの推力は 0 とみなした）から。抗力発散は、表の LRC が重さによらず .860〜.862 で頭打ちになることと、CI 5000 で ECON が速度の上限に届くこと（FCTM p.4.7）から。
  - 結果：PW は LRC の燃料流量 rms 1.7 %（最大 4.5 %）、LRC の Mach の差は最大 0.014、待機 1.3 %、アイドル降下の抗力 5.6 %。GE は 1.1 %（2.6 %）、0.007、1.3 %、6.5 %。模型の最適高度は表と 500 ft（PW）・900 ft（GE）ほど。LRC から .88 で燃料流量 +24 %（PW 300 t・FL350）。
  - 水平飛行の推力（8b2 の CRZ のページの EPR・N1 用）：1 発の推力 ÷ δ と Mach の 2 次式を、LRC・待機・.84/290 の巡航（PI.10.38・PI.20.33）の EPR（PW）・N1 ÷ √θt2（GE）に最小二乗で（新設の `tests/tools/thrust_fit.lua`）。EPR 0.01 rms（表の刻み）、N1 0.4〜0.9 %。RR は PW の EPR。
- ECON（推定）：
  - 巡航：対地の 1 NM あたりの費用（燃料 + CI × 100 lb/h）が最小の Mach。無風の最大航続より遅くせず、VMO/MMO − 16 kt を超えない。PW 300 t・FL350 で CI 0 は .822、100 は .854、約 270 で LRC 相当の .859、1000 は .866、5000 で上限 .879。CI 100 で向かい風 100 kt は .857、追い風 100 kt は .844。
  - 上昇・降下の CAS：表が無いので、CI の位置（0 は最大航続、1 は ECON 巡航が LRC になる CI、2 は CI 5000：1 と 2 の間は CI の対数）で、上昇は「最小抗力の速さ + 60 kt」（FCTM の maneuver + 60 に当たる）→ 340 → 360 kt、降下は「最小抗力の速さ」（最良滑空）→ 290 → 349 kt。Mach はどちらも巡航の ECON。上昇は低い巡航高度で巡航の CAS まで上げる。上昇の上限 360 kt は FMSPG の例（358）からの推定。重量は今のもの（T/C・T/D の予測重量は 8c）。
  - MAX ANGLE：その高度と重量の最小抗力の速さ（前は V2 + 80 か 100）。
- FMC（`B747.68.xt.fms.lua`）：5 秒ごと（CI・CRZ ALT の入力、<ECON・LRC> ですぐ）に、CI、FMC の重量（PERF INIT の ZFW＋燃料、入れる前は X-Plane の重量：`B747_fms_gw_kg`）、CRZ ALT、巡航高度の ±2,000 ft では今の向かい風（予報は 8e）、ISA 偏差から ECON を計算し、ECON のモードの速さに書く（2 kt・.002 未満の変化は書かない：自動操縦はどの変化も新しい目標として取り直すため）。LRC のモードは表の LRC。FMC のデータに速さのモード（clbspdmode・crzspdmode・desspdmode：E・S・L）、上昇の Mach（clbspdmach、空欄は巡航の Mach）、巡航の CAS（crzcas）を足した。CI を入れる前は前と同じ既定値（340、.810、.805/270）。
- 自動操縦（`B747.70.xt.autopilot.vnavspd.lua`）：巡航は FMC の Mach か乗員の CAS（前は CI から重量と高度の一次式で Mach を作り、乗員の巡航速度を上書きしていた：FMC-11）。上昇の Mach は FMC の上昇の Mach。降下の目標は VMO/MMO − 11 kt まで（CAS と、MMO の側の Mach）。FMC の速さのどれかが変われば目標を取り直す。前の式のための dataref（重量・TAS・GS）は外した。
- 古い LRC のページ（`vnav.lrc.lua`：TGT SPD・TURB N1・FUEL AT DEST など、2009 年版の FCOM に無い）は外し、CRZ のページの LRC のモードに置き換えた。s128 も CRZ のページで LRC を確かめるように直した。
- 残り：8b2（上の通り）。VNAV のページの入力は今もすぐ効き、MOD と EXEC が無い（FMC-34）。速さの表題の LIM SPD・MCP SPD・E/O は無い。
- 試験：
  - 回帰（LuaJIT）：`tests/fms/perf_db_test.lua` 84 件（模型の 48 件を足した：大気と速さの換算、表の全升の燃料流量・LRC の Mach・推力の設定、最大航続と ECON の CI・風・重量での動き、上昇・降下の CAS の位置）。新設の `tests/fms/vnav_pages_test.lua` 52 件（FMS のモジュールを通しで：CI の前の既定値、CI と CRZ ALT で ECON、CLB・CRZ・DES の表示と SEL SPD・<ECON・LRC>、誤った入力、MAX ANGLE、CI の変更と重量の減りへの追従、24 文字）と `tests/autopilot/vnav_speed_test.lua` 9 件（巡航は FMC の Mach か CAS で CI に左右されない、上昇の Mach、降下の 354 kt と MMO − 11 kt）。全 125 本。
  - X-Plane（カスタム acf）：新設の `s129_fmc_econ`（FL350 の空中開始）18/18。270 t・CI 100・ISA で CRZ の ECON SPD .853、DES .853/294、LRC .848、MAX ANGLE 229 kt（その高度）が、記録の重量と外気温から性能 DB で求めた値と同じ。CLB は 341 kt のところ既定値の 340 が残った（2 kt 未満の変化を書かない処理のため）ので、入力の後の最初の値は必ず書くように直した（X-Plane を起動し直した 2 回目も 18/18、CLB 341/.853。CDU の写真で ACT ECON CRZ、ACT M.840 CRZ と SEL SPD と <ECON、LRC> を確かめた）。s128 5/5（LRC> を CRZ のページの LRC のモードで）。Lua の誤りなし。CDU の写真の視点が違っていたので直した（the −34、psi 22、fov 16）。

## 46. 段 8b2 の実装（2026-10-31：CRZ のページ）

- 資料：CRZ のページ（FCOM p.1346–1350、FMSPG p.131–134）、STEP（FCOM p.1257、p.1312、p.1349、FMSPG p.98、p.133、FCTM p.4.8）、メッセージ（FCOM p.1435、FMSPG p.131）。
- STEP TO（新設の純粋なモデル `B747.68.crz_model.lua`）：
  - ICAO：出発前に入れた CRZ ALT の向きの、OPT より上の最初の高度（FCOM p.1349）。高度の割り振りは RVSM の前のもの（FL290 の下は奇数千 ft が東・偶数が西、FL290 から上は FL290＋4,000 ft の倍数が東・FL310＋4,000 ft の倍数が西）。FCOM の例（FL280 で出発、OPT FL337 → FL350）と FMSPG の例（FL310、OPT FL311 → FL350）がこの割り振りで、FCTM p.4.8 も「FMC の STEP の既定は RVSM の空域に合わないことがある」と書く。FL300 から上の偶数千（RVSM の高度）は西とした（推定）。飛行中に CRZ ALT を変えても向きは変えない。出発前の CRZ ALT が無い空中開始は今の CRZ ALT の向き。
  - STEP SIZE が数字なら CRZ ALT にその倍数を足した OPT より上の最初の高度、0 は STEP なし（FCOM p.1312）。どちらも CRZ ALT より上で 45,000 ft まで、でなければ空欄。
  - 乗員の STEP TO：CRZ ALT より上で 45,100 ft まで、新しい CRZ ALT まで残る（FMSPG p.133）。DELETE で FMC のものに。
  - 有効な経路が無いときと、T/D の 200 NM の内は空欄（FCOM p.1349）。
- AT（FCOM p.1349、FMSPG p.133）：最適な STEP の点は OPT が CRZ ALT と STEP TO の中間になる重さ（FCOM p.1257）。その重さで MAX が STEP TO に届かなければ、MAX が届く重さまで待ち、見出しは AVAIL AT。燃やす燃料を巡航の模型の燃料流量（指令の速さ、CRZ ALT、間の重さ）で割って時間、真対気速度から向かい風を引いて距離、ETA は X-Plane の UTC から。過ぎていれば NOW。T/D の 200 NM の内は TO T/D（T/D までの距離と、今の対地速度での ETA）。T/D は今も AP の `setDistances` のもの（8c で作り直す）。最適な点は燃料と重さからで、ECON の費用の最小ではない（推定）。
- EPR・N1（FCOM p.1348、FMSPG p.132）：CRZ ALT で指令の速さを保つ水平飛行の推力の設定を、巡航の模型の抗力と回帰の式で（§45。PW・RR は EPR、GE は N1）。動いているページ（巡航の段階）だけに出す。前は重量だけの一次式の N1 を、どの型式にも出していた。
- OPT・MAX：FMC の重量で（前は X-Plane の重量）。OPT は ECON でも表の LRC の燃料最小のまま：模型の ECON の最適高度は CI が小さいうちは上がり、大きいと下がって、FCTM p.4.6（ECON の OPT は CI が小さいほど高い）と食い違ったので作らなかった。MAX は速さのモードで変えない。
- MAX ALT FLXXX（FMSPG p.131、FCOM p.1435）：性能の最大高度より上の CRZ ALT は通し、メッセージを出す（45,100 ft より上は今までどおり INVALID ENTRY）。
- STEP SIZE：CRZ のページの 4L でも入れられる（FMSPG p.132）。DELETE で ICAO（FMSPG p.98）。PERF INIT と同じ。
- 残り：目的地の ETA/FUEL と STEP を含む予測、UNABLE CRZ ALT（8c）。CRZ CLB・CRZ DES の表題と MOD/EXEC（FMC-34）。LEGS の STEP の入力。
- 試験：
  - 回帰（LuaJIT）：新設の `tests/fms/crz_model_test.lua` 20 件（向き、ICAO の FCOM と FMSPG の例、STEP SIZE、0、天井、最適な点の重さ）。`tests/fms/vnav_pages_test.lua` に CRZ のページの 17 件を足して 69 件（経路が無ければ空欄、ICAO の FL390 と AT、EPR と動いていないページで空欄、STEP SIZE 2000・0・DELETE、乗員の STEP TO と INVALID ENTRY、AVAIL AT、NOW、TO T/D、MAX ALT FLXXX）。`tests/fms/perf_init_test.lua` は地上の FL370 で MAX ALT FL367 が出ることを足して 30 件。全 126 本。
  - X-Plane（カスタム acf）：新設の `s130_fmc_crz_step`（FL350 の空中開始、RJAA→PHNL を ACTIVATE と EXEC）13/13。270 t・CI 100 で STEP TO FL390、AT 0214z/599NM、EPR 1.18、OPT FL361・MAX FL403、STEP SIZE 2000 で FL370 は NOW、乗員の FL410 で AT 1,252 NM、CRZ ALT FL450 で MAX ALT FL403。どれも記録の重量・外気温・風から性能 DB と STEP のモデルで求めた値と同じ（FL410 の距離は風の変化で 3 NM 違う）。s129 18/18。Lua の誤りなし。CDU の写真で CRZ のページの並びを確かめた。

## 47. 段 8c の実装（2026-10-31：軌跡の予測）

- 資料：
  - 整備マニュアル（ATA34_2 p.610–611）：軌跡の予測は運動方程式と機体・エンジンの模型で計画の軌跡を模擬し、アイドルの時間を長くし、高度と速度の制限を守る。要る入力は重量・CI・巡航高度・目的地・点・経路・E/D・燃料。E/D の降下の情報が無ければ降下の経路も T/D も無く、T/C より先の点は巡航が続くと予測する。CRZ ALT が MAX 以上なら燃料の予測を出さない。
  - FCOM p.1258：E/D は滑走路の threshold の 50 ft 上（VOR 進入は MAP）、巡航中に先の点に高度の制限を入れても E/D ができる。T/D から最初の制限までの経路はアイドル・FMC の風・目標の速さ、その先の制限の間は点と点の直線。速度の遷移の高度で減速する。
  - PI.18.5–18.6：区間の燃料と時間の表（PI.11.3・11.4）は LRC と .84/290/250 の降下で目的地まで、降下の表（PI.11.5）はアイドルの .84/290/250 で外側マーカーでの直進進入の分を含む。FCTM p.4.8：4,000 ft の途中の上昇で 225〜300 kg 多い。
- 性能 DB に足したもの（推定）：
  - 最大上昇推力：PI.10.38・PI.20.33 の上昇（290/.84、最大上昇推力）の V/S から、模型の抗力と速さの変化の分で推力を逆算。重さによらず 2〜3 % でまとまったので、高度ごとの平均の推力 ÷ δ を直線でつなぐ。Mach と温度の影響は入れない。
  - アイドルの燃料流量：ICAO の排出データの 7 % の燃料流量（海面静止、PW4056 0.188、CF6-80C2B1F 0.205 kg/s。利用者が置いた `_ref/ICAO_EEDB/`）を入口の修正した条件（δt2 √θt2）で空中へ。FL350・M.84 で 1 発 235 kg/h。
  - 推力からの燃料流量（`thrust_ff`）：巡航の模型の燃料消費率をそのまま。
- 予測（新設の純粋なモデル `B747.68.pred_model.lua`）：
  - 上昇：最大上昇推力で上昇の速さ（SPD RESTR・SPD TRANS の下はその速さ、上は CAS から Mach）、速さの変化の分を入れた経路角、10,000 ft の水平の加速（推定）。上昇の脚（SID）の AT・AT OR BELOW・窓の上で水平にして、その点の後に上昇を続ける。降下の経路に当たれば T/C なしで降下へ（短い飛行）。
  - 巡航：巡航の速さ（ECON・SEL の Mach か CAS、LRC は重さと高度で表から）、巡航の模型の燃料流量。STEP：段 8b2 の STEP TO と最適な点の重さ（`steps` 関数）で上昇、T/D の 200 NM の内ではしない。
  - 降下：E/D から後ろへ作る。E/D と、守らないといけない制限（AT、窓、外れる AT OR ABOVE・AT OR BELOW）の間は直線、いちばん上の制限より上はアイドル（模型の抗力から、推力はアイドル分を引いたもの）。遷移と制限の速さへは水平のアイドルの減速（推定）。浅い直線にはアイドルより上の推力の燃料。降下の重さは 1 回目の予測の T/D の重さ（2 回まわす）。
  - 出すもの：点ごとの高度・時刻・燃料、T/C・T/D・E/D・S/C、目的地の時刻と燃料、最後の巡航高度。風は相の向かい風だけ（今は巡航の今の風、予報は 8e）。
  - PI と比べた結果：降下の FL270→FL350 の増分 26 NM・3.4 分（PI.11.5 は 28 NM・4 分）、FL350→FL410 の増分 15 NM（16 NM）。FL350 から 1,500 ft までは 107 NM・18 分で、表の 124 NM・23 分との差は表の直進進入の分。区間（300 t、LRC と降下）：3,000 NM・FL330 で 56.3 t・6:17（PI.11.4：56.3 t・6:20）、FL370 で 55.4 t・6:11（55.2 t・6:13）、5,000 NM・FL290 で 94.7 t・10:58（95.0 t・11:01）。4,000 ft の STEP の上昇で、その 50 NM 先までに多く使う燃料は FCTM の 225〜300 kg の幅に入る。計算は 1 回 1 ms ほど。
- FMC（`B747.68.xt.fms.lua`）：10 秒ごと（CRZ ALT の入力ですぐ）に、有効な経路の先の脚（大円の距離。条件の脚の先も直前の点から：推定。discontinuity の先も直前の点からの直行：FCOM p.1363 の注で確かめた（§49））、高度の制限（AT・A・B・窓）、E/D（進入の滑走路の 50 ft 上、その後の進入復行は使わない。無ければ上昇の脚の後の最後の制限の点）、上昇の脚（SID の最後）、FMC の速さ・重量・燃料（PERF INIT の FUEL）・STEP・巡航の風で予測（`B747_fms_preds()`）。CRZ ALT が MAX 以上なら予測しない。
- CRZ のページ：目的地の ETA/FUEL を予測から（前は 51.6 lb/NM などの経験式）、目的地の名前を FMC の経路から、T/D の 200 NM の内の判定と TO T/D の距離を予測の T/D から（前は AP の `setDistances` の T/D）。
- UNABLE CRZ ALT（FCOM p.1436）：上昇の相で、入れた CRZ ALT への上昇が降下の経路に先に当たる（予測に T/C が無い）とき、CRZ ALT の入力でメッセージを出す（巡航の最短時間の条件は資料に値が無いので入れていない）。
- 残り：LEGS の小字の予測・RTE DATA・PROGRESS・ND の T/C・T/D（8d）、点ごとの風と DESCENT FORECAST（8e）、VNAV の経路と指令に予測を使うこと（段 9。今の VNAV の降下は前の `setDistances` の 290 ft/NM のまま）、待機・オフセット・速度の制限の点（FMC-08）は予測に入れていない。
- 試験：
  - 回帰（LuaJIT）：新設の `tests/fms/pred_model_test.lua` 38 件（速さの予定、最大上昇推力とアイドル、PI.11.5 の降下の増分、PI.11.4 の区間の燃料と時間 3 つ、上昇の AT OR BELOW での水平、降下の AT、T/C・T/D・E/D、STEP 2 回と FCTM の STEP の燃料、短い飛行、降下中から、E/D 無し）と `tests/fms/pred_glue_test.lua` 35 件（合成の CIFP の ZZAA：経路が無ければ予測なし、脚・距離・E/D・SID、390 t で FL320 は UNABLE CRZ ALT、FL100 で T/C と T/D、CRZ のページの目的地の ETA/FUEL と名前、MAX の上で予測なし）。`vnav_pages_test.lua` は TO T/D と目的地を予測から確かめる形にして 70 件。全 128 本。
  - X-Plane（カスタム acf）：新設の `s131_fmc_pred` 9/9。FL350 の空中開始で RJAA→RJBB（DIRECT AKAGI、STAR ATMUGA、ILS06LY・遷移 GATES）を ACTIVATE、目的地の ETA/FUEL が予測から 0158z/80.2（残り 426 NM を指令の M.853 で 58 分、6.3 t：風はほぼ無し）。T/D は約 300 NM 先なので AT のまま（1 回目は T/D が 200 NM の内と見込んで試験の方が外れた）。s130 13/13。Lua の誤りなし。

## 48. 段 8d1 の実装（2026-10-31：PROGRESS と LEGS の予測）

- 段 8d を分けた：8d1 は PROGRESS と LEGS、8d2 は RTE DATA、8d3 は ND の T/C・T/D。
- 資料：PROGRESS 1/3（FCOM p.1371–1373）：TO・NEXT・DEST の DTG・ETA・FUEL、SEL SPD の見出しは速さのモード、5R は T/C・STEP CLB・T/D・E/D の ETA と距離。LEGS（FCOM p.1332）：点の速さと高度の予測は小さい字、降下の経路を作る前（高度の制限が巡航高度より下に無い）の降下の区域はダッシュ。
- 予測（§47）に、点ごとの速さ（T/C の前は上昇の、T/D の後は降下の予定、間は巡航の）、T/C・T/D・S/C・E/D の時刻、E/D の脚の番号を加えた。経路が変わる（LNAV の順送りも）と、すぐ予測し直す（ページは予測を脚の番号で読むため）。
- PROGRESS 1/3：TO（有効な点）、NEXT（その次の点のある脚）、DEST の距離・ETA・燃料を予測から（前は ND の距離を 275 kt と対地速度の大きい方で割り、今の燃料流量を掛けていた：FMC-20・21）。5R は上昇中なら TO T/C、次に STEP CLB、TO T/D、E/D（前は AP の T/D）。5L の見出しは今の相の速さのモード（ECON SPD・LRC SPD・SEL SPD）。予測が無い（有効な経路が無い）ときは前のまま。
- LEGS：有効な経路（変更中でない）の点に、予測の速さ（Mach の区間は .853、ほかは CAS）と高度（遷移高度より上は FL、下は 10 ft 単位）を小さい字で右寄せ。高度だけの制限の点は大きい字の「/」の前に速さだけ、速さの制限のある点には出さない。到着（STAR・進入）の脚は E/D が無ければダッシュ。E/D の後（進入復行）には出さない。ABEAM PTS>・RTE COPY> の行には出さない。
- 試験：
  - 回帰：`pred_model_test.lua` 46 件（点の速さ、事象の時刻）、`pred_glue_test.lua` 45 件（PROGRESS の TO・NEXT・DEST と TO T/C・ECON SPD、LEGS の (600) の速さ、(INTC) の速さ/高度、速さと高度の制限の ZZV には無し、滑走路の速さ、進入復行には無し）。全 128 本。
  - X-Plane：`s131_fmc_pred` に LEGS と PROGRESS を足して 14/14。LEGS：AKAGI .853/FL360、ATMUG 294/FL243、SAKVA 294/FL143、ATVID（/4000A）の前に 294、進入の遷移の点に 240。PROGRESS：TO AKAGI 47 NM・0106・85.6、NEXT ATMUG 341・0143・80.7、DEST RJBB 433・0158・80.2、ECON SPD と TO T/D 0138z/303NM。Lua の誤りなし。
- 推定・残り：条件の脚（VA・CA など）は距離を 0 とした（その間の予測は前の点のまま）。予測は今の高度から（巡航高度とずれた空中開始は今の高度で巡航）。RTE DATA と ND は 8d2・8d3。

## 49. 段 8d2 の実装（2026-10-31：RTE DATA）

- 資料：FCOM p.1360–1363（RTE DATA）。有効な経路だけのページで、ACT RTE x LEGS の点ごとの ETA と、FMC が計算した残りの燃料（入力はできない）、WIND のページへの「>」（風を入れた点は「W>」）。ETA と燃料の計算は discontinuity をまっすぐ飛ぶとする（p.1363 の注：§47 の推定のうち discontinuity の分はこれで資料どおり）。109 は 6R が LEGS>（p.1362）。405・570 は 6L が <LEGS、6R がデータリンクの REQUEST SEND>（データリンクが使えて降下・進入の相でないとき）と、風のアップリンクの LOAD・ERASE（p.1361、p.1363–1364）。LEGS の 6R の RTE DATA>（p.1332）。
- 図（p.1361・p.1362）からの配置：ETA（小さい字）が 1〜5 桁、WPT（大きい字）が 7 桁目から、FUEL（小さい字）が 15〜19 桁、WIND の「>」（大きい字）が 24 桁目。見出しは「ETA WPT FUEL WIND」（小さい字）。discontinuity は点の行に「-- ROUTE DISCONTINUITY -」（小さい字）。5 行目と 6 行目の間の線は、109 が左の 14 字、570 が左の 16 字と REQUEST。
- 作ったもの（新設 `activepages/B744.fms.pages.rtedata.lua`）：
  - 有効な経路の LEGS のページ（変更中でないとき）の 6R に RTE DATA>（前は空き）。押すと RTE DATA。点は LEGS のページと同じ 5 点ずつ（ページの番号も同じ）。
  - 各点の ETA と燃料は予測（§47）から（燃料は表示の単位）。E/D の後（進入復行）と予測が無いとき（CRZ ALT が MAX 以上など）は空き（LEGS と同じ）。
  - 109（PW・RR）は 6R に LEGS>、570（GE：`laminar/B747/engines/type`）は 6L に <LEGS。570 の REQUEST SEND> は、風のアップリンクを作っていないので出さない（推定：データリンクが使えないときの形とした）。
  - WIND の「>」は出すが、まだ押しても何もしない（WIND のページと点ごとの風は 8e）。
  - FMC COMM の <RTE DATA（570）はつないでいない（データリンクのページは別の項目）。
- 試験：
  - 回帰：`pred_glue_test.lua` に RTE DATA を足して 58 件（LEGS の 6R の RTE DATA>、見出し、(600) の名前と「>」の位置、ETA と燃料の位置と値、ZZV の燃料、109 の線、2 ページ目の discontinuity、570 の <LEGS と 6R の無反応、LEGS> で LEGS へ）。全 128 本。
  - X-Plane：`s131_fmc_pred` に RTE DATA を足して 21/21。AKAGI 0106z・85.6、discontinuity、ATMUG 0143z・80.8、SAKVA 0147z・80.6、ATVID 0149z・80.6（PROGRESS の TO・NEXT と同じ値）、14 字の線と LEGS>。画面の写真で配置と字の大きさを確かめた。Lua の誤りなし。
- 残り：ND の T/C・T/D・S/C・E/D（8d3）、WIND のページと W>（8e）。

## 50. 段 8d3 の実装（2026-10-31：ND の T/C・S/C・T/D・E/D と減速点）

- 資料：FCOM p.1149（altitude profile point and identifier、緑：MAP と MAP CTR で、FMC が計算した T/C・S/C・T/D・E/D の位置に丸と名前。減速点は名前なし。FIX のページの予測の高度/ETA の点は別：段 10 以降）。FMSPG p.51（記号と色：緑）、p.153（S/C は巡航の上昇を始める位置。T/D の 200 NM の内には予測しない）。
- 前：ND のモジュール（`plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua`）が、AP の `setDistances` の T/D と T/C の位置（`laminar/B747/autopilot/dist/top_of_*`）に緑の丸（記号 8）と名前を描いていた。T/D は電波高度 5,000 ft の上だけ。S/C・E/D・減速点は無かった。
- 作ったもの：
  - 予測のモデル（`B747.68.pred_model.lua`）：降下の経路を E/D から作るときに、水平の減速（遷移と制限の速さへ：推定）の始まりを記録し（`dp.decel`）、T/D（降下中は今）より先・E/D まで・巡航高度より下のものを `decel` で出す。
  - FMC（`B747.68.xt.fms.lua`）：予測のたびに（10 秒ごと、経路の変更や CRZ ALT の入力ですぐ）、T/C、次の S/C、T/D、E/D、減速点の、経路に沿った距離を、予測と同じ脚の大円（直前の点から点へ）の上の緯度経度にして、新設の `laminar/B747/fms/profile/kind`・`lat`・`lon`（各 8 個。kind は 1 T/C、2 S/C、3 T/D、4 E/D、5 減速点、0 無し）に出す。後ろの点と、予測が無いとき（有効な経路が無い、CRZ ALT が MAX 以上）は出さない。経路のモデルの `course_point` を外から使えるようにした。
  - ND：前の AP の T/C・T/D の代わりにこの点を、両席の MAP（MAP CTR も）で、選んだ範囲の内に、緑の丸と名前（減速点は名前なし。同じ名前を一度しか描かない仕組みは、空の名前の "latlong" で避けた）で描く。PLAN・VOR・APP では描かない（FCOM p.1149）。ND の AP の距離の dataref と電波高度は使わなくなったので外した。
- 推定：S/C は次の 1 つだけ（FMSPG p.153 の書き方から）。減速点は降下の遷移と制限の速さへの水平の減速だけ（点の速度制限は予測に入っていない：FMC-08）。点は予測の時の経路の上の位置なので、通り過ぎた点は次の予測（10 秒の内）まで残る（拡大の MAP では後ろは描かない）。VNAV の降下は前の AP のままなので、ND の T/D と、AP が降下を始める所は段 9 まで一致しない。
- 試験：
  - 回帰：`pred_model_test.lua` 49 件（10,000 ft の減速点が T/D の後・制限の点の手前に 1 つ、降下中にも、E/D が無ければ無し）、`pred_glue_test.lua` 63 件（経路が無ければ点も無し、FL100 で T/C・T/D・E/D、STEP SIZE 0 で S/C 無し、E/D は滑走路の threshold、T/D と T/C はその脚の大円の上の予測の距離）、新設の `tests/displays/nd_profile_test.lua` 10 件（ND の MAP 40 NM に T/C・T/D と減速点 2 つ（名前なし）、90 NM の E/D は 160 NM で、後ろの S/C は無し、kind 0 で消える、PLAN と VOR では無し）。全 129 本。
  - X-Plane：新設の `s132_nd_profile` 10/10（FL250 から FLCH で上昇。最初の点は T/C、PROGRESS の TO T/C 51NM と同じ所、AKAGI の 3 NM 先。160 NM の ND で経路の線の上に緑の丸と T/C、PLAN では無し）、新設の `s133_nd_profile_des` 11/11（ATMUG の手前 FL350 の巡航。点は T/D・E/D・減速点の順、T/D は PROGRESS の TO T/D 78NM の所。80 NM の ND で T/D は経路の線の上、E/D は RJBB 06L の threshold、160 NM で ATVID と GATES の間に減速点）。Lua の誤りなし。

## 51. 段 8e1 の実装（2026-10-31：WIND のページと点ごとの風）

- 段 8e を分けた：8e1 は WIND のページと点ごとの風・気温の入力と伝わり方、8e2 は DESCENT FORECAST のページ、8e3 は予測が風と気温を使うこと（測った風との混ぜ方を含む）。
- 資料：
  - FCOM p.1363（RTE DATA の W> と >）、p.1364–1366（WIND のページ：XXXXX WINDS、ALT・OAT・DIR/SPD、1L に高度を入れると並べ替えて 1〜4 行に、4 つあれば先に消す、DIR/SPD は方向と速さ、最初の入力は前後に・ほかは先へ伝わり、伝わった値は小さい字、ALT/OAT は標準の減率で他の高度へ、入力は大きい字・計算は小さい字、6R RTE DATA>）。入力した風は予測で測った風と混ぜる（p.1364：8e3）。
  - FMSPG p.121–124（FOOTS WINDS の例：4 つの高度はすべての点で共通、高度を消すとすべての点のその風も消える、入力が無ければ風は 0、OAT は −80℃ から、海面 55℃・45,100 ft −40℃ の線まで、入力の無いときは標準大気、OAT を入れたページの気温は大きい字・ほかのページは小さい字、RTE DATA> はその点の RTE DATA へ、W> は風の入力のある点）、p.228–232（伝わり方の例：図 4.6-1・4.6-2、点を消したときの伝わり直し、通過した点からも伝わる、10.2 の前後の違い）。
- 作ったもの：
  - 純粋なモデル `B747.68.wind_model.lua`（新設、`B747_wind_model`）：経路に高度（`r.windAlts`、4 つまで、高い順）、脚に風（`l.wind[ft] = {dir, kt}`）と気温（`l.oat = {ft, c}`）。点の風は、その点の入力、無ければ前の最後の入力（通過した点も）、無ければ後ろの最初の入力。気温も同じ伝わり方で、ほかの高度は標準大気からの差のまま（圏界面の上は一定）。高度を消すとすべての点のその風も消す。
  - 経路のモデル：複製（MOD・RTE COPY）で高度の一覧を写し、脚の複製に元の脚（`orig`）を持たせる（WIND の入力を、有効な経路と MOD の同じ脚に入れるため。fix の無い条件の脚もあるので fix では対応できない）。ORIGIN の入力で高度の一覧も消す。
  - WIND のページ（新設 `activepages/B744.fms.pages.wind.lua`）：RTE DATA の 1R–5R から、その点のページ。1 ページ 1 点で、NEXT・PREV PAGE は経路に沿って進む（"9/13"）。配置は FCOM p.1365 の図：ALT は 1〜5 桁、OAT は 8〜11 桁と小さい「C」、DIR/SPD は 15〜22 桁と小さい「KT」、高度は下に詰めて、4 つ未満なら 1L はダッシュ。ALT/OAT は 5R（小さい見出し、小さい「C」）、6R は RTE DATA>（その点のある RTE DATA のページへ）。字の大きさ：その点の入力は大きく、伝わった値は小さく、風の無い高度はダッシュ。OAT はその点で入力したなら大きく（FMSPG p.122）、ほかは小さく。
  - 入力：1L に高度（4 つあれば INVALID ENTRY、高度のある行への入力も INVALID ENTRY：先に消す）、高度の行の DELETE でその高度。1R–4R に DIR/SPD（000–360/0–250）、DELETE でその点の入力。5R に ALT/OAT（範囲の外は INVALID ENTRY）、DELETE。入力はすぐ効き、有効な経路と MOD の両方に入る。
  - RTE DATA：風の入力のある点は W>、1R–5R でその点の WIND のページ（discontinuity の行は何もしない）。
- 推定：気温の伝わり方（資料は伝わるとだけ）、風の速さの上限 250 kt、入力がすぐ効く（EXEC の要る MOD にしない）、点を消すとその点の入力も消える（10.2 より前の FMC の扱い：FMSPG p.231）。予測が風を使うのは 8e3（今の予測は巡航の今の風だけ）。データリンクの風の要求（570）は無い。
- 試験：
  - 回帰：新設の `tests/fms/wind_model_test.lua` 34 件（4 つの高度と並べ方、FMSPG の図 4.6-1 の伝わり方を高度ごとに全点、図 4.6-2 の点を消したとき、通過した点からも伝わる、高度を消す、その点の風を消す、MOD の写しは別の表、気温：FCOM の図の FL330 −53℃ から FL270 −41℃、前後への伝わり、圏界面の上、範囲）、新設の `tests/fms/wind_page_test.lua` 42 件（合成の ZZAA：RTE DATA の 1R から、見出しと配置、FL350 と 270/50、次の点の小さい字、FL300/−40 と FL350 の −50、範囲の外、4 つ目まで・5 つ目と重ねた入力は INVALID ENTRY、DELETE、361 は INVALID ENTRY、RTE DATA> と W>、MOD の脚にも入り EXEC の後も残る）。全 131 本。
  - X-Plane：新設の `s134_fmc_winds` 16/16（AKAGI の WIND のページ 1/13、FL350 の行と DIR/SPD のダッシュ、標準大気 −54℃ の小さい字、270/50、次の ATMUG で小さい字、FL300/−40 で FL350 は −50、RTE DATA で AKAGI が W>）。写真で配置と字の大きさを確かめた。Lua の誤りなし。

## 52. 段 8e2 の実装（2026-10-31：DESCENT FORECAST）

- 資料：FCOM p.1393（DES のページの FORECAST>）、p.1395–1397（DESCENT FORECAST：降下の 4 つの高度の風と、防氷を入れる高度を入れて降下の経路を正しくする。TRANS LVL は到着の手続きで決まることがあり既定は FL180、FL と ft の表示の切り替えに使う。ALT は順不同で並べ替えない。TAI/ON ALT は降下で防氷を最初に入れる高度。WIND DIR/SPD の最初の入力は方向と速さ、後は片方でよい。405/570 はデータリンクの SEND・LOAD・PURGE と DES>）、FMSPG p.230（降下予報の風は巡航の風と混ぜて滑らかに移す。巡航の風が無ければ最も高い降下の風を巡航高度まで、最も低い降下の風は目的地の標高で 0 へ：8e3）。
- 作ったもの（新設 `activepages/B744.fms.pages.desforecast.lua`）：
  - DES のページの 5R の FORECAST> から（前は押しても何も無かった。CLB と CRZ のページの 5R は何もしないままにした）。
  - 配置は FCOM p.1396 の図（109）：DESCENT FORECAST、小さい見出し TRANS LVL・TAI/ON ALT、1L に TRANS LVL（既定 FL180）、1R に TAI/ON ALT（ダッシュか高度）、小さい見出し ALT・WIND DIR/SPD、2〜5 行目に高度（無ければダッシュ）と風（15〜22 桁と小さい「KT」、無ければ ---°/---）。6 行目は、109 は図のとおり <OFFPATH DES と DES DIR>（DES のページと同じく、まだ働かない）、570 は DES>（DES のページへ。データリンクの SEND・LOAD・PURGE は作らない：推定）。
  - 高度の表示は TRANS LVL の上が FL（FCOM p.1396）。
  - 入力（FMSPG p.178–179）：1L TRANS LVL（高度か FL。既定は目的地の遷移高度（航法データの earth_aptmeta.dat）、無ければ FL180。乗員の入力が優先。DELETE は INVALID DELETE）、1R TAI/ON ALT（DELETE でダッシュ）、2L〜5L ALT（順不同、ほかの行と同じ高度は INVALID ENTRY、DELETE でその行の高度と風）、2R〜5R WIND DIR/SPD（方向は真方位の 3 桁で 360 まで、速さは 0〜250 kt。最初は ddd/sss、後は ddd/ か /sss でもよい。その行に高度があるとき：推定。DELETE）。WIND のページの DIR/SPD も同じ書き方（方向 3 桁）にした（推定：FMSPG はこのページについて書いている）。
  - 予報（`B747_fms_des_forecast()`）と遷移高度（`B747_fms_trans_lvl()`）をほかから読めるようにした。予測が使うのは 8e3。
- 残り：OFFPATH DES と DES DIR（VNAV の段 9 以降）、TAI/ON ALT を降下の経路に使うこと（資料に値があれば）、DES のページなどほかのページの FL と ft（LEGS 以外は TRANS ALT のまま）。
- 追記（2026-10-31、8e3 の後）：TRANS LVL の既定に到着の手続きの値を足した（FMSPG p.178：目的地か到着の手続きに記録された値で変わる）。CIFP の手続きの行の 26 番目の欄（遷移高度）を手続きのモデルが脚の `ta` に持ち、乗員の入力、到着（STAR・進入）の脚の値、目的地の空港の値、FL180 の順に使う。LEGS のページは、到着の脚と（有効な経路の）予測の T/D の後の脚の高度（制限と小さい字の予測）を TRANS LVL の上で FL に、ほかは TRANS ALT の上で FL にした（FCOM p.1396：どの脚が降下かは推定）。試験：`wind_page_test.lua` 49 件（試験の CIFP の STAR に 13,000 ft を入れ、TRANS LVL が 13,000、STAR の ZZV に 13500 で FL135、SID の ZZV では 13500）、全 132 本。
- 試験：
  - 回帰：新設の `tests/fms/des_forecast_test.lua` 44 件（CLB と CRZ の 5R は何もしない、DES の 5R の FORECAST>、配置、FCOM の図の 3 つの風、/80 と 140/、高度の無い行・最初の片方・251 kt・2 桁の方向・同じ高度は INVALID ENTRY、目的地が無ければ FL180、TRANS LVL 4000 で 5000 が FL050、DELETE は INVALID DELETE、TAI/ON ALT、行の DELETE、570 の DES>）、`wind_page_test.lua` 45 件（2 桁の方向・251 kt、目的地 ZZAA の遷移高度 FL140）。全 132 本。
  - X-Plane：新設の `s135_fmc_des_forecast` 11/11（DES の 5R から、FL180 とダッシュ、FCOM の図の 3 つの風、/80、TAI/ON ALT FL150 は 15000）。写真で配置を確かめた。Lua の誤りなし。この試験の後に、FMSPG に合わせた入力の検査（TRANS LVL の DELETE、同じ高度、3 桁の方向、目的地の遷移高度）を足した（回帰試験で確かめ、X-Plane では次の起動し直しの後に s135 をもう一度）。

## 53. 段 8e3 の実装（2026-10-31：予測の風と気温）

- 資料：FCOM p.1364（入力した風は予測で測った風と混ぜる：機体から遠い所は入力した風、近い所は測った風、間は混ぜる）、FMSPG p.230（点と点の間・高度の間で補間。すべての入力が巡航高度より上なら最も低い入力から出発地（上昇）か目的地（巡航）の標高で 0 へ、すべて下なら最も高い入力を巡航高度まで。降下予報の風は巡航の風と混ぜて滑らかに移し、巡航の風が無ければ最も高い降下の風を巡航高度まで、最も低い降下の風は目的地の標高で 0 へ）、p.233（測った風の割合は機体で 100 %、200 NM で 50 %、その先は少しずつ減ってほぼ 0。上昇と降下では 200 NM の代わりに 5,000 ft、距離の代わりに高度：図 4.6-3）、p.234（入力した風と気温は燃料と ETA の予測に使う）、p.122（OAT の入力が無ければ標準大気）。
- 作ったもの：
  - 風のモデルに「場」（`B747_wind_model.field`）：経路の風は点と点の間で直線、点ごとに高度の間で直線、最も高い高度の上はその値、最も低い高度の下は出発地（上昇）か目的地（巡航・降下）の標高で 0 へ。降下では DESCENT FORECAST の風（あれば）：最も高い予報の上は巡航高度の経路の風へ直線で（経路の風が無ければ最も高い予報のまま）、最も低い予報の下は目的地の標高で 0 へ。予報が無ければ降下も経路の風。気温は点の（伝わった）標準大気からの差を点と点の間で直線、入力が無ければ 0（標準大気）。
  - 測った風（真方位：X-Plane の磁方位の風を、機首の磁方位と真方位の差で直した）と測った気温を、図 4.6-3 から読んだ割合（0 NM 1、100 NM 0.82、200 NM 0.5、300 NM 0.32、400 NM 0.2、500 NM 0.11、600 NM 0.04、750 NM から 0）で混ぜる。機体が巡航なら前方の距離で、上昇・降下なら高度の差（5,000 ft を 200 NM として）で。
  - 向かい風は、その脚の大円の進路への成分（条件の脚は前か後の脚の進路）。
  - 予測のモデル：入力に `field` があれば、上昇・巡航・降下の各段で、その場所と高度の向かい風と ISA からの差を使う（前は相ごとの一定の向かい風で上昇と降下は 0、巡航は今の風、ISA からの差は今の値を全体に）。
  - ECON の巡航の風（`B747_fms_crz_headwind`）：最後の予測の場の、今の位置・巡航高度の値（前は巡航高度の ±2,000 ft なら今の風、ほかは 0）。予測が無いうちは前のまま。
- 推定：図 4.6-3 の読み取り。割合を距離と高度のどちらで決めるかは機体の今の相とした。気温にも同じ割合を使う。最初の点の手前は最初の点の値。降下予報から巡航高度へのつなぎは直線。予報が無いときの降下は経路の風。TAI/ON ALT（防氷）は予測にまだ使っていない（防氷のアイドルの増分の値が手元の資料に無い）。
- 試験：
  - 回帰：`wind_model_test.lua` 60 件（入力の書き方、測った風の割合 1・0.5・0.2・0、点の間と高度の間の補間、最も高い高度の上、最も低い高度の下は目的地と出発地の標高で 0、降下予報とその上の巡航の風へのつなぎ、経路の風が無いとき、測った風の割合を巡航は距離・上昇は高度の差で、気温の差と標準大気）、`pred_model_test.lua` 53 件（場で一定の向かい風と ISA+5 なら前の相ごとの値と同じ、50 kt の追い風で 1,000 NM が 10 分より早い、降下の低い所だけの向かい風で到着が遅れ T/D はほぼ動かない）、`pred_glue_test.lua` 65 件（WIND のページの FL100 の入力が最も長い脚の中ほどで、地上からの高度の差の割合だけ減った向かい風になる、予測の到着が変わる）。全 132 本。
  - X-Plane：新設の `s136_fmc_pred_winds` 10/10。FL350 の巡航で、風なしの目的地 0158z/80.2 t が、AKAGI に FL350 の 250/100（ほぼ向かい風、全点に伝わる）を入れると 0201z/79.7 t（3 分遅れ、0.5 t 減。近くは測った無風が混ざるので、100 kt だけの計算より小さい）。PROGRESS の ATMUG は 0143z→0146z、TO T/D は 0138z→0141z。DESCENT FORECAST の FL200 250/080 では分の単位では変わらなかった（経路の FL350 の風が下へ 0 まで伸びた値と近い）。`s135_fmc_des_forecast` を FMSPG の入力の検査を足した版で 11/11。Lua の誤りなし。

## 54. 段 9 の段取り（2026-10-31：VNAV と 6-4 の A/T）

- 下調べ（2026-10-31、資料とコードを下調べ役 2 つで）：
  - 資料：VNAV は FMC の誘導の機能で、縦の形を「性能の脚」のつながりとして持ち、脚ごとに昇降舵が速度か経路を持つ。経路を昇降舵が持つ間は速度の指令は推力管理へ（ATA34_2 p.597）。4 つの制御：速度/推力（上昇・早期降下・E/O の driftdown）、経路/速度（巡航・浅い降下）、経路/アイドル（ふつうの降下）、速度/ホールド（段の降下）（ATA34_2 p.615–616）。FMC から FCC へ：目標の対気速度・Mach・高度、縦の steering とその rate、離散信号（ATA22 p.206、ATA34_2 p.470）。FCC は VNAV の engage 中だけ縦の steering を姿勢の積分に足す（ATA22 p.332、p.347）。FCC の速度の則は TO・GA・FLCH だけ（ATA22 p.344）なので、VNAV の速度と経路のループは FMC 側と読める（推定）。engage は FMC の VNAV CONTROL（監視・センサ・PERF の入力・400 ft の上・ARM）と FCC の ARM・ENGAGE の latch（ATA34_2 p.621、ATA22 p.279、p.340–341）。サブモードの移り方（ATA22 p.279–280、ATA34_2 p.624）、MCP のノブ（ATA34_2 p.623–624）、FCOM の許容（経路 150 ft、速度 15 kt と 10 kt、349・354 kt、DES NOW 約 1,250 fpm、T/D の 2 分前の RESET MCP ALT、50 NM の早期降下：FCOM p.1258–1262、p.645、p.665）。
  - 推力管理（ATA34_2 p.638–675）：engage の論理、モード（THR REF・THR・SPD・IDLE・HOLD）とピッチのモードからの選び方、速度・V/S（FLCH は 125 s で MCP 高度へ、GA は 2,000 fpm）・推力の各則、servo（0〜10°/s の積分、flare 5°/s、FLCH の 8° の override で HOLD）、推力制限と自動の切り替え。ゲインと時定数は資料に無い。
  - コード：今の VNAV は前の AP の `VNAV_modeSwitch`・`setDistances`（X-Plane の FMS の JSON から 290 ft/NM の T/D）・`setDescentVSpeed`（幾何の V/S）・速度の状態機械（`vnavspd.lua`）で、FMC の経路と段 8 の予測を使っていない。AFDS（6-3 で作り直し）は VNAV のサブモードを前のフラグから推し、則は前のフラグ（FLCH → 速度の則、V/S → V/S の則）で飛ぶ。A/T は前の AP の if の連鎖が FMA の値を毎フレーム作り、servo は EEC（別のプラグイン）にある（ATA-22-AT.md §7 の ATHR-01〜20）。
  - 下調べの指摘：作り直した AFDS の則に VNAV の高度の捕捉が無く、VNAV の上昇が MCP の高度を行き過ぎるおそれ（s137 で確かめる）。
- 方針：
  - VNAV は FMC の純粋なモデル（`B747.68.vnav_model.lua`、新設）で、飛行の段階、サブモードの要求（SPD・PTH・ALT）、目標の速度・高度、経路（段 8 の予測の降下の経路を E/D までの距離で地上に固定）、経路の偏差と V/S の指令、A/T のモードの要求、メッセージを出す。受け渡しは LNAV と同じく dataref（`laminar/B747/fms/vnav/*`）。AFDS が arm・engage・逆戻りを決め、則を飛ぶ（ATA-22.md §8 の取り決め）。
  - A/T は推力管理を 1 つのモジュールにまとめて作り直す（ATA-22-AT.md §8）。A/T の状態と FMA の値の持ち主を 1 つにする。servo は EEC から移し、EEC は TRA から EPR/N1 だけ。
  - `flightPhase`（多くの読み手：EEC の推力制限、CDU のページ、予測）の持ち主も FMC の VNAV の段階にする。
  - 3D・表示・音の名前（`FMA/active_pitch_mode`・`autothrottle_mode` の値の意味、`ias_dial_value` など：INTERFACES.tsv）は変えない。
- 段（それぞれ、純粋なモデルの回帰試験と X-Plane の試験を付ける）：

| 段 | 内容 | GAP |
|---|---|---|
| 9a | （s137 で行き過ぎなら）今の VNAV の高度の捕捉の応急の修正 | — |
| 9b | VNAV のモデル（純粋）：段階（CLB・CRZ・DES）、目標の速度（上昇・巡航・降下の予定、SPD TRANS・RESTR、点の速度制限、フラップの placard、最小・最大）と高度、降下の経路（予測から、地上に固定）、偏差と V/S の指令、サブモードと A/T の要求。FMS に組み込み dataref に出すが、AFDS はまだ前のまま（影の動き：X-Plane で前の VNAV と並べて比べる） | FMC-07, 08, 12, 13, 17, 18 |
| 9c | AFDS が新しい VNAV で飛ぶ：engage は FMC の有効、SPD は FMC の目標速度、PTH は V/S の指令と FMC の高度の捕捉、ALT は MCP の高度、FMA はサブモードから。A/T は VNAV の要求に従う（つなぎ）。前の VNAV（`VNAV_modeSwitch`・`setDistances` の T/D・`vnav.lua`・`vnavspd.lua`）を外す。`flightPhase` の持ち主を FMC に | AFDS-08 |
| 9d | MCP の操作と早期降下：ALT ノブ（制限を 1 つずつ消す、CRZ ALT、巡航の上昇・降下、T/D 50 NM の内の早期降下）、SPD ノブ（速度介入）、DES NOW、RESET MCP ALT、CRZ のページの見出し | FMC-14, 15 |
| 9e | 降下の許容と進入：経路 150 ft、速度の閾値と逆戻り、THRUST REQUIRED・DRAG REQUIRED、on approach、END OF DES、進入復行（CRZ ALT は進入復行の最も高い高度）、離陸の VNAV（400 ft、V2+10〜25、加速高度、VREF+100） | FMC-16 |
| 9f | 推力管理 1（6-4）：A/T のモードの状態機械、engage と disconnect（AUTOTHROT DISC）、モードの則（SPD、THR の V/S、THR REF、IDLE・HOLD）、servo（10°/s、5°/s、8° の override）、EEC から servo を移す | ATHR-06〜16, 19, 20 |
| 9g | 推力管理 2（6-4）：推力制限（TO・CLB・CRZ・CON・GA、CLB 1/2、derate と assumed temp、自動の切り替え）、EICAS の reference・target・max、THRUST LIM のページ | ATHR-01〜05, 17 |
| 9h | E/O の VNAV と RTA（109） | FMC-26, 27 |

- 順は 9a → 9b → 9c → 9f → 9d → 9e → 9g → 9h（A/T の IDLE・HOLD・THR が要る所の前に 9f）。

## 55. 段 9a の実装（2026-10-31：VNAV の水平の応急の修正）

- 見つけたこと：下調べで、6-3 で作り直した AFDS の則が、前の VNAV（`VNAV_modeSwitch`）の FLCH・V/S のフラグのまま VNAV を飛び、高度を捕捉しないおそれが分かった（AFDS のモデルの捕捉は V/S・FLCH・TO/GA のピッチのモードだけ。前の VNAV が高度を保つフラグを立てるのは CRZ ALT と engage の時だけ）。X-Plane の新設の `s137_vnav_level_off` で確かめると、10,000 ft から MCP 13,000 ft へ VNAV SPD で上がり、13,000 ft を越えて 16,870 ft でもまだ 1,760 fpm で上がっていた（FMA は VNAV SPD のまま、中の目標高度は 35,000 ft に書き換わっていた）。
- 直し方（AP のつなぎ `B747.70.xt.autopilot.lua`、段 9c で新しい VNAV に置き換えるまで）：AFDS のピッチが VNAV の間、MCP の高度と前の VNAV の目標高度を、V/S・FLCH と同じ捕捉（`B747_afds_pitch_model.capture`）で捕らえ、その高度を ALT の則で保つ。MCP の高度なら FMA は VNAV ALT（FCOM p.645：VNAV と MCP の高度が食い違えば水平にして VNAV ALT）、前の VNAV の目標なら VNAV PTH（ATA22 p.280：FMC の高度の捕捉で PTH）。その高度が動いたら（新しい MCP の高度、前の VNAV の次の目標）離す。水平の間、A/T は THR REF でなく SPD（FCOM p.645：VNAV ALT・PTH の A/T は SPD）。
- 推定：MCP の高度を動かせば上昇・降下を続ける（実機は MCP の高度を変えてノブを押す：段 9d で）。
- 試験：
  - 回帰：`tests/autopilot/afds_glue_test.lua` 186 件（VNAV SPD で MCP の高度の 60 ft 下を上昇中に VNAV ALT、A/T は THR REF でない、MCP を上げると VNAV SPD）。全 132 本。
  - X-Plane：新設の `s137_vnav_level_off` 12/12（直す前は 13,000 ft を越えて 16,870 ft まで上がった。直した後は 13,003 ft で水平・VNAV ALT・A/T SPD・340 kt、MCP 15,000 ft で VNAV SPD に戻り 15,003 ft で VNAV ALT）。Lua の誤りなし。

## 56. 段 9b の実装（2026-10-31：FMC の VNAV のモデル、影の動き）

- 資料：§54 の下調べ（ATA34_2 p.597、p.610–617、p.621、ATA22 p.206、p.279–280、FCOM p.645、p.1253–1262）。
- 作ったもの：
  - 純粋なモデル `B747.68.vnav_model.lua`（新設、`B747_vnav_model`）：
    - 段階：上昇から巡航へは CRZ ALT の 50 ft 内、巡航から上昇へは CRZ ALT が 500 ft より上（FCOM p.1257 の cruise climb）、上昇・巡航から降下へは T/D を過ぎて（地上に固定した降下の経路の、今の位置の高度が機体の高度以下：巡航から経路に当たる T/D も、T/C の無い短い飛行の上昇が経路に当たる所も同じ）、MCP の高度が 200 ft より下にあるとき（MCP が巡航高度のままなら高度を保つ：FCOM p.665 の RESET MCP ALT）。地上と有効な経路が無いときは上昇。予測の T/D（予測の時の段階で変わる）は使わない。
    - 予測の段階（上昇・巡航・降下の始め方）は、前の AP の `flightPhase` でなく、この VNAV の段階から取る（X-Plane の s138 の 1 回目で、T/D を過ぎた所の空中開始で前の段階のまま予測が T/D を出さず、VNAV が上昇のままだった）。
    - サブモードと A/T の要求（ATA34_2 p.615–616 の 4 つの制御）：上昇は VNAV SPD と THR REF（速度/推力）、巡航は VNAV PTH と SPD（経路/速度）、降下は VNAV PTH と IDLE（経路/アイドル）。ただし降下で経路の区間がアイドルには浅い（予測の印 "spd"：FCOM p.1258）か、経路の 200 ft より下にいる間は SPD。
    - 目標の速度：上昇・巡航・降下の予定（予測と同じ関数）、MCP の速度介入、フラップの placard の 5 kt 下（FCOM p.1255）、最小機動速度の 5 kt 上（FCOM p.663）。
    - FMC の高度：上昇は先の AT・AT OR BELOW・窓の上限のうち、上昇の脚（SID の脚、無ければ E/D までの道のりの半分まで：予測と同じ）にあって、今の高度の 100 ft 下より上で CRZ ALT より下の最初のもの、無ければ CRZ ALT。巡航は CRZ ALT。降下は次の制限、無ければ E/D の高度。
    - 降下の経路：予測の降下の経路（`dp`）を E/D までの距離の表にしたもの（予測のモデルに、点ごとの区間の種類 "idle"・"spd" を足した）。今の E/D までの距離（今の位置から最初の点までの大円と、その先の脚の距離の和）で、経路の高度・勾配・区間の種類を引く（地上に固定した経路：ATA34_2 p.563）。
    - V/S の指令：経路の V/S（勾配と対地速度から）から、経路より上の偏差 1 ft につき 3 fpm 急にする（K_PATH）。上へは指令しない（経路より下なら水平で経路を待つ）、経路より 1,500 fpm を超えて急にしない。
    - valid：有効な経路、CRZ ALT、総重量（PERF INIT の ZFW の入力：FCOM p.645 の PERF/VNAV UNAVAILABLE）、降下では経路があること。
  - FMC（`B747.68.xt.fms.lua`）：毎フレーム入力を組んでモデルを回し、新設の `laminar/B747/fms/vnav/*`（valid、phase、mode、cas、mach、mach_mode、alt、vs、path_dev、at）に出す。速度の予定は予測と同じ関数（`B747_fms_schedules`）。予測のたびに、経路の表、最初の点と E/D までの脚の距離、上昇と降下の制限の表を作り直す（`vnav_geo_set`）。
  - AFDS と A/T はまだ前の VNAV で飛ぶ（影の動き。段 9c で切り替える）。
- 推定：段階の切り替えの閾値（50 ft、500 ft、200 ft）、K_PATH と 1,500 fpm、上昇の制限の選び方（SID の脚、無ければ道のりの半分）、経路の 200 ft 下からの SPD。
- 試験：
  - 回帰：新設の `tests/fms/vnav_model_test.lua` 39 件（上昇の VNAV SPD・THR REF・250 kt と 340 kt と M.84・FMC の高度、placard・最小機動速度・速度介入、CRZ ALT で巡航の VNAV PTH・SPD・M.85、高い CRZ ALT で上昇へ、T/D を過ぎても MCP が巡航高度なら巡航、MCP が下で降下の VNAV PTH・IDLE、経路の V/S、経路の上・下・ずっと下・ずっと上、浅い区間の SPD、240 kt、valid、短い飛行、経路の引き方）、`pred_glue_test.lua` 72 件（地上：ZFW が無ければ無効、ZFW 210 で有効・上昇・VNAV SPD・THR REF・CRZ ALT・250 kt）。全 133 本。
  - X-Plane：新設の `s138_vnav_shadow` 8/8（T/D を過ぎた FL314 で降下・VNAV PTH・IDLE、目標 287 kt、FMC の高度 4,000 ft（ATVID の制限）、経路の 1,710 ft 上で V/S の指令 −3,322 fpm（経路より 1,500 fpm 急の上限））。1 回目は予測の T/D に頼った段階の切り替えで上昇のまま（上の直し）、2 回目は確かめる時機が T/D の手前だった。Lua の誤りなし。

## 57. 段 9c の実装（2026-10-31：AFDS が FMC の VNAV で飛ぶ）

- 資料：§54 の下調べ（ATA22 p.279–280、p.338、p.341、FCOM p.645、p.1149、p.1255、p.1433）。
- 作ったもの（AP のつなぎ `B747.70.xt.autopilot.lua`・`B747.70.xt.autopilot.monitor.lua`、FMS の `B747.68.xt.fms.lua`・`B747.68.vnav_model.lua`）：
  - engage：VNAV の arm から、FMC の valid（ATA22 p.341 の FMC DATA VALID）で 400 ft の上（FCOM p.645）。engage の後は valid の間続き、valid が消えると今の高度の ALT HOLD（ATA22 p.338）。arm も valid が無いと消える（前は前の VNAV の経路が無いとき）。
  - PERF/VNAV UNAVAILABLE：VNAV スイッチで、総重量・COST INDEX・CRZ ALT のどれかが無いとき（FCOM p.1433。FMC の新しい `laminar/B747/fms/vnav/perf`。前は CRZ ALT だけ）。
  - 則：VNAV SPD は速度の則（FLCH と同じ）で FMC の目標速度、巡航の VNAV PTH は FMC の高度を ALT の則で、降下の VNAV PTH は FMC の V/S の指令を V/S の則で。上昇では MCP の高度と FMC の高度（上昇の制限、CRZ ALT）を捕捉して水平（VNAV ALT・VNAV PTH：段 9a の捕捉の目標を、前の VNAV の目標から FMC の高度に）。
  - FMA：水平の間は 9a のまま（MCP の高度で VNAV ALT、FMC の高度で VNAV PTH）、そうでなければ FMC のサブモード（SPD → VNAV SPD、PTH → VNAV PTH）。
  - 速度：VNAV の engage 中で IAS/MACH の窓が閉じている間（速度介入でない間）、FMC の目標速度を速度のダイアルへ。Mach は Mach×100 で、ダイアルの単位も FMC に合わせて切り替える（前の VNAV と同じく 0.25 秒）。X-Plane のダイアル（速度の則と A/T の基準）と速度の bug は今までどおりダイアルから。
  - 離陸（FCOM p.1255。§54 の 9e から前倒し：前の VNAV の V2 の扱いを外すため）：地上から VNAV の engage まで、目標速度は今の速度を V2 + 10〜V2 + 25 に収めたもの。engage の後はその値のまま、加速高度（TAKEOFF REF の ACCEL HT を出発空港の標高に足す）かフラップを上げ始めるまで。そのあとは上昇の予定（フラップの placard の 5 kt 下、SPD TRANS の 250 kt）。V2 が無い（999）ときと空中開始は、はじめから上昇の予定。
  - A/T：engage の時に A/T ARM が ON なら A/T を active にする（FCOM p.645）。TO/GA の推力の状態と前の則のフラグは消す。VNAV の間の A/T のモードは FMC の要求（上昇 THR REF、巡航 SPD、降下 IDLE、経路の 200 ft 下と浅い区間は SPD）、水平（VNAV ALT と捕捉の VNAV PTH）は SPD。
  - `flightPhase`：VNAV の間は FMC の段階（EEC の推力の基準：CLB・CRZ）。ただし離陸（0）の間は電波高度 1,000 ft までそのまま（前の THR REF と同じ。段 9f の THR REDUCTION までの推定）。
  - ND の経路の指針：`vnav/after_tod` と `dist/flight_path_error` を、FMC の降下の段階と経路の偏差から（FCOM p.1149：降下の間だけ。VNAV の engage によらない）。前は前の VNAV の幾何。
  - DRAG REQUIRED（前の判定のまま）は VNAV の降下の経路の上でも出る（前は前の V/S のフラグで判定）。段 9e で作り直す。
  - 前の VNAV：`VNAV_modeSwitch` の上昇・巡航・降下（`VNAV_CLB`・`VNAV_CRZ`・`VNAV_DES`）、毎フレームの `B747_vnav_speed`、arm の時の前の VNAV の始め方を外した（関数は残してある。段 9d・9e で RESET MCP ALT と DES のページを作り直すときに消す）。RESET MCP ALT（前の `checkMCPAlt`）は VNAV の巡航・降下で今までどおり（段 9d まで）。DES のページの FPA・V/B（前の `setDescentVSpeed`）は VNAV が engage していない間だけ更新される（段 9e で FMC から）。
  - engage で IAS/MACH の窓を閉じる：前の速度介入（SPD ノブの押し）の状態を消す（速度介入の作り直しは段 9d）。
  - FMC の新しい `laminar/B747/fms/vnav/dist`（経路を引く E/D までの距離、NM：試験と記録 v8 の `fvn_dist` のため）。
  - E/D までの距離（経路を引く所）：予測の時に点ごとの E/D までの残りの距離を表にし、毎フレーム、有効な経路の最初の点（LNAV が順送りした後はその次の点）までの大円にその残りを足す（経路の脚の表は順送りでも同じ表のまま残るので、点で引ける）。前は予測の時の最初の点からで、その点を過ぎると次の予測（10 秒ごと）まで距離が増え、経路が上へ逃げた（s140 の 2 回目：ATMUG の旋回の後 12 秒で経路の 700 ft 下）。
  - 経路の戻し（§56 の K_PATH・VS_STEEPER）を 1 ft につき 3 fpm・1,500 fpm から 1 fpm・1,000 fpm に下げた：X-Plane の s140 の 1 回目で、経路の 1,424 ft 上から 3 分で 860 ft 下まで行き過ぎた（AFDS の V/S の則は巡航の速さで昇降率を毎秒 50 fpm ほどしか変えない：0.05 g の制限と遅れ。戻しの時定数 20 秒ではそれより速い）。1 分の時定数にした（推定）。
- 推定：離陸の推力の基準を 1,000 ft まで保つこと、A/T を active にするのは engage の時だけ（あとで A/T を外せば戻さない）、フラップを上げ始めた判定（地上の角度から 0.02 の比）、経路の戻しの強さ。
- 残り：経路の上下 150 ft の許容、速度の許容（目標 + 15 kt など）と速度の逆戻り（VNAV SPD）、THRUST REQUIRED・DRAG REQUIRED（FCOM p.1259–1260）は段 9e。今は経路から大きく外れると、遠い間は経路の V/S から 1,000 fpm 急に（上）か水平（下）で戻す。
- 残り（予測から来るもの）：予測の脚の距離は点と点の大円で、旋回の弧を入れない（段 8c）。折り返しに近い旋回では実際の道のりが予測より長く、旋回の間に経路の下に出る（s140 の 2〜4 回目：ATMUG の上で SAKVA へ約 150° 折り返し、E/D までの距離が旋回の間 0.1 NM/s で増え −850 ft。VNAV の追従そのものは ATMUG で +69 ft）。実機の経路は旋回を含む横の経路に沿う。
- 試験：
  - 回帰：`afds_glue_test.lua` 216 件（PERF/VNAV UNAVAILABLE、arm・2 回目・FMC の valid で engage、VNAV SPD・前の則のフラグを消す・A/T が active で THR REF・窓を閉じダイアルに 300 kt・X-Plane のダイアルも・段階 1、MCP の高度で VNAV ALT と A/T SPD、FMC の高度で VNAV PTH、巡航の VNAV PTH・SPD・Mach .845 のダイアル、降下の VNAV PTH・IDLE・−2,000 fpm で指令が下へ・280 kt・after_tod と偏差、valid が消えると ALT HOLD・指針が消える・arm が消える、engage 中の押しは何もしない、V/S で終わる）、`vnav_model_test.lua` 51 件（離陸の目標速度：地上で V2 + 10、速度に合わせる、V2 + 25 まで、engage の時の値を保つ、加速高度で placard の 5 kt 下、フラップを上げ始めると上昇の予定、V2 が無いときと空中開始は上昇の予定）、`pred_glue_test.lua` 80 件（perf、TAKEOFF REF の V2 160 で地上の目標 170 kt、ZZV を順送りして次の点までの間にいるときの E/D までの距離：前の引き方では 253.1 NM、正しくは 229.9 NM）。全 133 本。
  - X-Plane（1 回目、経路の戻しを下げる前）：新設の `s139_vnav_climb_crz` 18/18（10,000 ft から VNAV SPD・THR REF で上がり、FL170 で VNAV PTH・A/T SPD・巡航、行き過ぎなし）、`s137_vnav_level_off` 12/12（ZFW を入れるように直した。13,000 ft で VNAV ALT、15,000 ft でも）、新設の `s140_vnav_descent` 15/16（T/D の手前の FL300 から VNAV PTH で降下に入り、A/T IDLE、ND の指針。3 分後の偏差が −860 ft で外れた：上の直し）。Lua の誤りなし。
  - X-Plane（2 回目、X-Plane を起動し直し、記録 v8 で FMC の VNAV の列も）：新設の `s141_vnav_takeoff` 37/37（RJAA 34L から V2 を選んで離陸、400 ft の上で VNAV SPD、目標は V2 + 10〜25 で加速高度まで保ち、その後フラップ 20 の placard の 5 kt 下、フラップを上げて 250 kt、9,000 ft で VNAV ALT・A/T SPD）、`s101_afds_pitch` 33/33（ZFW と CI を入れるように直した）、`s140_vnav_descent` 15/16（経路の 1,596 ft 上から V/S の指令に 50〜100 fpm で付いて 55 ft まで滑らかに戻った。そのあと ATMUG の旋回で −700 ft）。Lua の誤りなし。
  - X-Plane（3〜5 回目）：E/D までの距離を点で引くように直した後も、同じ所で −806 ft（3 回目）。E/D までの距離と位置を記録して（4 回目）、ATMUG の真上（34.5583、134.1274）を通ってから SAKVA へ折り返していて、その道のりが予測に無いためと分かった（上の残り）。s140 を ATMUG の約 30 NM 西（STAR の入り口の側）からの開始に直し（5 回目）16/16：T/D（開始から約 48 秒）で VNAV PTH・A/T IDLE、速さが足りない間は A/T が推力を足し、偏差は最大 +188 ft から 200 秒で +11 ft、230 秒で −5 ft、300 kt（目標 294 kt）。Lua の誤りなし。

## 58. 段 9f の段取り（2026-10-31：推力管理 1、A/T のモードと servo）

- 下調べ（2026-10-31、資料：ATA34_2 p.644–648、p.654、p.660–675、FCOM p.641–642、p.656–657、p.662–674、p.677。コード：下調べ役で今のコードの地図）：
  - 今の A/T の状態（`engines/autothrottle_active`・`autothrottle_fail`・`TOGA_mode`・`autopilot/thrust_mode`・FMA の値）は AP・monitor・vnavspd・engines・manipulators・EEC・EEC の ALTN の 7 か所から書かれ、FMA は AP の `B747_ap_fma` の if の連鎖が毎フレーム作る。THR（4）は一度も出ない。monitor（`B747_monitorAT`）が ALT・V/S・G/S で A/T を勝手に active にする。
  - >AUTOTHROT DISC は `autothrottle_fail` そのもの：reverse を使う着陸のたびに出る（engines が reverse で fail を 1 に）、A/T が active でないときの disconnect の押しでも出る、disconnect は fail を反転するだけ（ATHR-13・14）。
  - レバーの servo は EEC（`ecc_throttle`・`spd_throttle`）：1 フレームごとの刻みでフレームの速さに依る、IDLE は 1 秒で全行程、SPD はほぼ対称、手のレバー（3D・ハードウェア）は A/T の間は捨てる（override なし：ATHR-09・10・20）。
- 方針：A/T を AP のモジュールの純粋なモデル（新設 `B747.70.at_model.lua`）にまとめる。engage の論理と AUTOTHROT DISC の latch（ATA34_2 p.644）、モードの選び方と移り方（p.647、p.654、p.660–675）。状態の持ち主は A/T のつなぎだけにし、ほかは読むだけか、イベント（ARM スイッチ、disconnect の押し、TO/GA の押しの数、SPD・THR の押し、reverse）を渡す。守る名前：FMA の値 0–5、`autothrottle_active`、`laminar/B747/autothrottle/armed`、コマンド名。
- 段：
  - 9f1：モデルのモードの論理と engage・disconnect（AUTOTHROT DISC は engage から外れたときだけ、地上の reverse では出さない、disconnect の 1 回目で外し 2 回目か再 engage で消す：FCOM p.657、p.677。ARM OFF で外す。TO/GA は地上で 50 kt 未満・フラップ UP でない・TO の limit で THR REF、65 kt で HOLD、VNAV か別のモードまで HOLD（前は 50 ft で THR REF に戻った）、50 kt までに押さなければ 400 ft まで engage しない：FCOM p.656、p.667。VNAV・FLCH・TO/GA・SPD・THR で engage、ARM を入れたとき VNAV・FLCH なら engage：FCOM p.641。VNAV・FLCH から ALT・V/S・G/S へ移ると SPD、TO/GA のピッチからの水平では変えない：ATA34_2 p.654、FCOM p.673。VNAV の IDLE はレバーが後ろの stop に着くと HOLD：p.666。flare retard の IDLE、reverse で外す（メッセージなし））。AP のつなぎ（FMA の連鎖と monitor の自動 engage を置き換え、engines・manipulators・EEC の A/T の書き込みを外す）。推力の則とレバーはまだ EEC（FLCH と G/A は今の THR REF）。
  - 9f2：制御則と servo をモデルへ（SPD は増が速く減が遅い、THR の V/S 則：FLCH は 125 秒で MCP 高度、G/A の 1 回目は 2,000 fpm で THR を出す、THR REF は limit speed と thrust limit、IDLE、誤差率の積分で 10°/s・flare 5°/s：p.646–648、p.472）、EEC の `ecc_throttle`・`spd_throttle` を外して指令位置を EEC が当てる。pilot override（FLCH で 8° 離れると HOLD、ほかは手を離すと戻る。ハードウェアの軸の扱いは推定）。
  - 9f3：interlock と表示：2 発以上停止、EEC の ALTN（PW は全部 NORM、GE は全部 ALTN で再 engage：FCOM p.877）、電源（FMC・servo・DC bus）、SPD・THR スイッチの条件（400 ft、ピッチのモード：FCOM p.641–642、ATA34_2 p.668、p.672）、THRUST REQUIRED（ATHR-19）。

## 59. 段 9f1 の実装（2026-10-31：A/T のモードの論理と engage・disconnect）

- 資料：§58（ATA34_2 p.644、p.647–648、p.654、p.660–674、FCOM p.641–642、p.656–657、p.667、p.673、p.677）。
- 作ったもの：
  - 純粋なモデル `B747.70.at_model.lua`（新設、`B747_at_model`）：
    - engage：A/T ARM と interlock（3 発以上運転：N1 15 % 超、A/T の fail＝EEC の ALTN）があり、モードで engage する。VNAV・FLCH が engage したとき（と、その間に ARM を入れたとき）、TO/GA（地上で 50 kt 未満・フラップ UP でない・TO の limit なら TO の THR REF、空中でフラップ UP でないか G/S で TO の limit でなければ G/A の THR REF、離陸後の TO の limit なら THR REF）、SPD スイッチ（400 ft の上、TO の limit でない、VNAV・FLCH・T/O・G/A でない）、THR スイッチ（400 ft の上、TO・GA の limit でない、VNAV・FLCH でない）。地上で 50 kt までに TO/GA を押さなければ 400 ft まで engage しない。
    - 外れる：ARM OFF、interlock を失う、disconnect の押し、reverse。>AUTOTHROT DISC は engage から外れたときだけ latch（地上の reverse では出さない）、disconnect の押しか次の engage で消える。
    - モード：TO の THR REF、65 kt で HOLD、VNAV の engage か別のモードの選択まで HOLD。VNAV は FMC の要求（水平で SPD）、IDLE はレバーが後ろの stop に着くと HOLD（要求が IDLE の間はそのまま）。FLCH・G/A は THR REF（THR とその V/S 則は 9f2）。VNAV・FLCH から ALT・V/S・G/S へ移ると SPD（T/O・G/A からの水平では変えない）。flare retard の IDLE を reverse まで。
  - AP のつなぎ（`afds_at`、毎フレーム AFDS の後）：入力を組み、`engines/autothrottle_active`・FMA の A/T・`engines/TOGA_mode`（TO の THR REF 0.9・HOLD 1：古い読み手のため）・>AUTOTHROT DISC（caution 5）を書く。SPD・THR・disconnect のスイッチと TO/GA の押しの数をイベントで渡す。
  - 外したもの：FMA の if の連鎖、monitor の自動 engage（ALT・V/S・G/S・FLCH・捕捉の窓）と 2 発停止・fail の処理、AFDS の V/S・ALT HOLD・VNAV の engage と A/P の解除の後の再 engage、SPD スイッチの A/T、THR スイッチの解除、disconnect の fail の反転、engines の TO/GA（TOGA_mode 0.9 と A/T active）と reverse（fail 1：着陸のたびの >AUTOTHROT DISC）、manipulators の TO/GA（ARM OFF でも active）と ARM の active、EEC の A/T の解除、EEC の SPD の 25 ft の IDLE（autoland でなくても：ATHR-12）、vnavspd の自動 engage。
- 推定：運転中のエンジンの判定（N1 15 %：前の monitor のまま）、地上で止まりかけ（30 kt 未満）で 50 kt の禁止を解くこと。
- 残り（9f2・9f3）：レバーは EEC の servo のまま（モードごとの今の動き）。THR と V/S 則、servo の速さと override、FLCH・G/A の THR、interlock の残り（電源、ALTN の再 engage の規則）、SPD・THR スイッチの THR の推力制限の機能。
- X-Plane で見つけて直したもの：EEC の「IDLE で遅いときに推力を足す」（minimum maneuvering 由来の Vmc + 10 か MCP − 5 kt より遅いと SPD の則）が、autoland の flare retard の IDLE でも推力を足した（s114 の 1 回目：25 ft の IDLE の後に EEC の出力が 0.29 から 0.53 へ、浮いて跳ね、スピードブレーキが出ず A/P が外れた）。前は SPD の 25 ft の IDLE（手の着陸でも）が止めていた。電波高度 100 ft の上だけにした（推定。FCOM p.1259 の目標より遅いときの SPD は段 9e）。
- 試験：
  - 回帰：新設の `tests/autopilot/at_model_test.lua` 44 件（TO の THR REF と 65 kt の HOLD、300 ft でも HOLD、VNAV で THR REF・SPD・水平の SPD、50 kt の禁止と 400 ft、disconnect と >AUTOTHROT DISC と 2 回目、ARM OFF・ON、VNAV の中の ARM ON、VNAV の IDLE と HOLD、V/S への SPD、FLCH と捕捉の SPD、G/A と水平、SPD・THR スイッチの条件、interlock、flare retard、地上の reverse、離陸後の TO/GA）、`afds_glue_test.lua` 224 件（ARM の dataref、VNAV の IDLE がレバーの stop で HOLD、V/S への SPD、disconnect で外れ caution 5、2 回目で消える、SPD スイッチ）、`eec_module_test.lua` 60 件（ALTN は fail だけ：active はモデルの）。全 134 本。
  - X-Plane（起動し直した 08:48 の後）：新設の `s142_at_takeoff` 31/31（TO/GA で THR REF、65 kt で HOLD（64〜80 kt）、300 ft でも HOLD、VNAV で THR REF、disconnect で外れ >AUTOTHROT DISC、2 回目で消え、ARM の入れ直しで VNAV の中の A/T が engage）、`s141_vnav_takeoff` 37/37、`s114_autoland` 20/0・WARN 1（2 回目：上の直しの後、retard で EEC の出力 0。WARN は前からの接地の後の小さな跳ね）、`s01_ap_basic` 14/0・WARN 1（空中開始の揺れで ALT HOLD が 10,750 ft から：A/T は SPD）。`s09_eec` 22/3 は approach idle の確かめ（minimum idle を 1.5 未満とする）が 10-30 のアイドルの表（高度で変わる）の後の古い期待値で、A/T とは関係ない（残り）。Lua の誤りなし。

## 60. 段 9f2 の設計（2026-10-31：A/T の制御則と servo）

- 受け渡し：A/T のモデル（AP）が servo の指令位置 `laminar/B747/autothrottle/lever_cmd`（0〜1）と励磁 `laminar/B747/autothrottle/servo`（1 で servo がレバーを動かす。HOLD・外れ・override で 0）を出す（AP の init で作る）。EEC はレバーの持ち主のまま、励磁中は `engine/throttle` を指令位置に（`ecc_throttle`・`spd_throttle` は使わない）、手の入力（ハードウェアか 3D の軸が A/T の間に 0.01 より動いた）があればその間は手に従い、手が止まって `OVR_S` 秒で指令位置へ戻す（推定。資料：他のモードは手を離すと戻る、ATA34_2 p.648）。EEC は A/T の間に自分で `throttle_jet_rev_ratio_all` を書かない（書くと手の入力に見える）。
- servo（ATA34_2 p.648、p.472）：各則がレバーの速さ（誤差率）を出し、servo が積分して指令位置にする。速さは 10°/s まで（3D のレバーの全行程 50° で 0.2/s：推定）、flare retard は 5°/s（0.1/s）。
- 則（ゲインは資料に無い：推定、X-Plane で合わせる）：
  - SPD：目標（MCP か FMC の速さ：X-Plane のダイアル）との差と加速度から（PD を積分）。増は速く減は遅い（FCTM p.43：減は増の半分）。thrust limit を越えない（推力が基準以上なら増やさない）。速度の保護（最大は Vmax − 5、最小は FCC の最小 + 5：FCOM p.675）。
  - THR：V/S の則（ATA34_2 p.646–647、p.670）。FLCH は 125 秒で MCP 高度に着く V/S、G/A の 1 回目は 2,000 fpm。上昇で V/S が足りなければ増やし、多くても減らさない。降下では減らし、レバーが後ろの stop なら IDLE から HOLD（FCOM p.662、ATA34_2 p.654）。thrust limit を越えない。FLCH でレバーが指令から 8°（0.16）離れたら HOLD（p.648）。
  - THR REF：推力の基準（EEC の EPR・N1 の bug）へ。限界の速さ（Vmax）を越えそうなら速さで減らす（p.672）。
  - IDLE：後ろの stop へ 10°/s（flare 5°/s）、着いたら HOLD（VNAV・FLCH。flare retard は IDLE のまま）。
  - HOLD：励磁なし（レバーは手で）。
- FMA：FLCH と G/A の 1 回目は THR（4）、G/A の 2 回目は THR REF。
- 実装（2026-10-31）：上の設計どおり（`B747.70.at_model.lua` の `servo`、AP の `afds_at` が入力を組んで `autothrottle/servo`・`lever_cmd` を出し、EEC の `at_servo_levers` が当てる）。推力は EEC の TRA（レバーの指令の EPR・N1：エンジンの遅れが無い）で見る。ゲイン（推定）：SPD は 1 kt につき 0.002/s と加速度 1 kt/s につき 0.06（減は半分）、THR は 1 fpm につき 1.2e-5/s、THR REF は 1 EPR につき 0.33/s・1 % N1 につき 0.003/s。初めの 0.006・0.05 は s01 の 250 kt で、レバーがアイドルと 0.3 の間を 30 秒ごとに振れた（X-Plane のエンジンはアイドル近くでレバーに 7 秒ほど遅れ、レバー 0〜0.1 では推力がほぼ変わらない。この遅れと不感帯を入れた模擬でも同じ）。
- FMC の VNAV に FCOM p.1259–1260 の「目標より 15 kt（速度の遷移の下では 10 kt）遅いと A/T は IDLE・HOLD から SPD、5 kt まで戻ると IDLE」を前倒しで入れた（9e の一部。前は EEC が IDLE のまま推力を足していたが、9f1 から VNAV の降下は stop で HOLD になり、s140 で目標 294 kt に 246〜262 kt のまま降りた）。
- 試験：
  - 回帰：`at_model_test.lua` 64 件（servo を足した）、`eec_module_test.lua` 66 件（servo の受け渡しと手の入力）、`vnav_model_test.lua` 56 件（遅いときの SPD）。全 134 本。
  - X-Plane（09:35 と 10:08 に起動し直した）：`s01_ap_basic` 14/0・WARN 1（空中開始の高度：前から）、`s140_vnav_descent` 16/16（IDLE で 10°/s に後ろの stop、HOLD）、`s101_afds_pitch` 33/33（初めのゲインの回では V/S の +1,500 fpm で 800 fpm に 30 秒で届かなかった）、`s142_at_takeoff` 31/31（TO の THR REF を TRA で）、`s114_autoland` 20/0・WARN 1（flare retard は 5°/s。WARN は flare の浮き：回により出る）。Lua の誤りなし。
- 残り：SPD の速さの戻りが遅い（s01：空中開始の 288 kt から 250 kt へ、2 分で 5 kt の内、3 分で 3 kt。もっと速くするとエンジンの遅れで揺れる）。アイドル近くの不感帯は EEC のレバーと推力の関係（段 9g の推力制限と一緒に見る）。ハードウェアのスロットルで FLCH の 8° の override を確かめていない。

## 61. 段 9f3 の実装（2026-10-31：A/T の interlock と THRUST REQUIRED）

- 資料：ATA34_2 p.450（電源）、p.644–645（engage の条件）、FCOM p.666、p.1259、p.1434。
- 作ったもの（AP のつなぎ `afds_at`）：
  - engage の interlock に電源を足した：servo の励磁の F/O transfer bus（FMC R の電源でもあるので、これがあれば FMC も 1 台は動く）と、駆動の DC bus 1 か 2（どちらか：推定。資料は bus 1・bus 2）。失えば外れて >AUTOTHROT DISC（engage から外れたとき：段 9f1 のとおり）、戻るまで engage しない。3 発以上の運転と EEC の ALTN（`autothrottle_fail`：P&W は全部 NORM、GE は全部 ALTN で戻す規則は EEC のモデル）は段 9f1 から。
  - THRUST REQUIRED（FMC のメッセージの旗 45）：VNAV の降下で FMC が A/T に SPD を求め（浅い区間、経路の下、15 kt 遅い）、A/T が engage していないとき（FCOM p.1259、p.1434）。
- 推定：DC はどちらか 1 本で足りること。
- 残り：FMC の両方の故障と FMC の master の切り替え（FMC の故障の模型が無い）、servo loop monitor（閾値が資料に無い）。SPD・THR スイッチの条件は段 9f1 から（400 ft、TO の limit、ピッチのモード）。THR スイッチの推力制限の機能と DRAG REQUIRED の作り直しは段 9e・9g。
- 試験：`afds_glue_test.lua` 230 件（F/O transfer bus を失うと外れ >AUTOTHROT DISC、SPD スイッチも効かない、戻すと SPD で engage しメッセージが消える、THRUST REQUIRED が A/T OFF の SPD の求めで出て IDLE の求めで消える）。全 134 本。X-Plane：Web API で F/O transfer bus・APU standby bus・DC bus が 1（電源の入った機体で engage を妨げない）。

## 62. 段 9d の段取り（2026-10-31：MCP の操作と早期降下）

- 資料：FCOM p.649（MCP の高度のノブの押し）、p.645・p.665・p.1256（VNAV ALT：MCP の高度を変えてノブを押すと続ける、経路の下なら MCP を下げて経路に当たれば続ける）、p.1257（cruise climb・cruise descent と CRZ のページの見出し）、p.1260–1261（早期降下：DES NOW、T/D の 50 NM の内のノブ、50 NM より前は cruise descent）、p.643（IAS/MACH のノブの押し：速度介入。PTH の降下は VNAV SPD に、高度の制限で PTH に戻る。進入中は PTH のまま）、p.665・p.1433（RESET MCP ALT：T/D の 2 分前に MCP が巡航高度のまま）。
- 今：MCP の高度を 50 ft より動かすと VNAV ALT・PTH の水平を離す（段 9a：押しなし）。ALT のノブは前の VNAV のコード（CRZ ALT より上なら CRZ ALT を MCP に、2 秒後に前の VNAV の再開）。SPD のノブは前の `manualVNAVspd` を切り替え（窓が開いて MCP の速さで飛ぶが、FMC のサブモードは変わらない）。RESET MCP ALT は前の `checkMCPAlt`（前の VNAV の T/D の距離）。早期降下と DES NOW は無い。
- 段：
  - 9d1：ALT のノブの押し。AP がノブの押しの数を `laminar/B747/autopilot/alt_sel_pushes` に出し、FMS が押しごとに：上昇・降下で、機体の高度と MCP の高度の間の次の制限を消す（有効な経路の脚の高度の制限）。上昇で制限が無く MCP が CRZ ALT より上なら CRZ ALT を MCP に。巡航で MCP が CRZ ALT と違えば CRZ ALT を MCP に（下で T/D の 50 NM の内なら 9d2 の早期降下）。AFDS の VNAV ALT の水平はノブの押しで離す（MCP の高度の変化だけでは離さない。降下で経路の下は経路に当たれば：p.645）。RESET MCP ALT を FMC で（T/D まで 2 分の内、MCP が CRZ ALT 以上：予測の T/D と対地速度から）。
  - 9d2：早期降下・cruise descent・DES NOW（DES のページの 6R）。VNAV のモデルに、降下を経路の前に始める型（VNAV SPD で降下の速さ、約 1,250 fpm、A/T は THR から HOLD、経路に当たると PTH：p.1260）と cruise descent（新しい CRZ ALT へ VNAV SPD で降り、水平で巡航：p.1261。降下率は推定）。A/T の THR は VNAV の V/S の目標で。CRZ のページの見出しの CRZ CLB・CRZ DES（p.1257）。2 つに分ける（2026-10-31）：
    - 9d2a：誘導とノブ。早期降下（ノブで T/D の 50 NM の内か、MCP が降下の最も高い制限より下：p.1389）、cruise climb・descent の誘導、A/T の THR から HOLD（FMSPG p.3.5-5：その率に達すると）、計画の経路（CRZ ALT で頭打ち）と T/D、CDU の ACT の見出しを FMC の段階で（CRZ CLB・CRZ DES）。
    - 9d2b：DES のページの 6R の DES NOW>（MOD と EXEC：FMSPG p.3.5-5。上昇と巡航の制限も消す）と DES DIR>、CLB のページの CLB DIR>（機体と MCP の高度の間の制限を全部消す、CRZ ALT は変えない：FCOM p.1329、p.1393、FMSPG p.3.5-5 の図）。
  - 9d3：速度介入の VNAV SPD（PTH の降下で窓を開くと VNAV SPD、高度の制限で PTH：p.643）。

## 63. 段 9d1 の実装（2026-10-31：MCP の高度のノブの押しと RESET MCP ALT）

- 資料：§62（FCOM p.645、p.649、p.665、p.1256–1257、p.1433）。
- 作ったもの：
  - AP：高度のノブの押し（`laminar/B747/button_switch/press_altitude`）を `laminar/B747/autopilot/alt_sel_pushes` に数える（前は前の VNAV の CRZ ALT と再開のコード）。AFDS の VNAV ALT（MCP の高度での水平）は、MCP の高度が変わってノブが押されたら続ける（前は変わっただけで続けた：段 9a）。経路の下で水平になっていて MCP を下げたなら、経路が降りてきて当たれば押さずに続ける（p.645）。FMC の高度での VNAV PTH は今までどおり FMC の次の高度で。
  - FMS（`B747_fms_alt_sel_push`）：押しごとに、上昇（地上を含む）・降下で、機体の高度と MCP の高度の間の次の高度の制限を有効な経路から直接消す（MOD を作らない：経路のモデルの新しい `delete_alt_active`。速度の制限は残す）。上昇は予測の上昇の脚（予測の最後の上昇の点まで）だけ、降下はその先だけを見る。上昇で制限が無く MCP が CRZ ALT より上、か巡航で MCP が CRZ ALT より上なら CRZ ALT を MCP に（cruise climb：p.1257）。巡航で MCP が下（cruise descent と早期降下）は 9d2。
  - RESET MCP ALT（旗 33）：FMC が、VNAV の巡航で T/D（経路が CRZ ALT に達する所：VNAV のモデルの新しい `path_e_at`）まで 2 分の内か過ぎて、MCP が CRZ ALT から下がっていないとき（前は前の VNAV の T/D の距離で、前の monitor が出した）。過ぎても出し続けるのは推定。
  - AFDS：FMC の高度（上昇の制限か CRZ ALT）が MCP の高度と同じ（50 ft 以内）なら、水平は VNAV PTH（FCOM p.645：VNAV ALT は経路と MCP の高度が食い違うとき。前は MCP の捕捉が先で VNAV ALT：X-Plane の s139 の巡航上昇で、MCP と同じ CRZ ALT FL190 に VNAV ALT で水平になった）。FMC の高度が先へ動けば離し、MCP の高度に居ればその捕捉（VNAV ALT）に移る。
  - VNAV のモデル：FMC の降下の始めは、T/D を過ぎて MCP が CRZ ALT（と機体の低い方）より 200 ft 下のとき（FCOM p.665：MCP が巡航高度のままなら RESET MCP ALT で保つ。前は機体より下：X-Plane の s143 で、空中開始の揺れで機体が MCP より 250 ft 上がり、T/D を過ぎた所で FMC が降下に入って戻らなかった）。
- 試験：
  - 回帰：`afds_glue_test.lua` 235 件（MCP を上げただけでは VNAV ALT のまま、ノブの押しで VNAV SPD、押しの数、FMC と MCP の高度が同じなら VNAV PTH）、`pred_glue_test.lua` 86 件（地上の上昇で押すと上昇の制限が 1 つずつ有効な経路から消え MOD は無い、CRZ ALT はその間そのまま、上昇の制限が無くなると CRZ ALT が MCP の 37,000 ft に、降下の制限は残る）、`vnav_model_test.lua` 62 件（`path_e_at`、CRZ ALT より上で MCP が CRZ ALT なら巡航のまま）、`cdu_framework_test.lua` 37 件（FMC のメッセージの試験の旗を DRAG REQUIRED の 9 に：33 は FMS が毎フレーム書く）。全 134 本。
  - X-Plane（11:05 と 12:12 に起動し直した）：`s128` 5/5（起動し直しの後の捨て）、`s137` 13/13（押さなければ VNAV ALT のまま、押すと上昇を続け 15,000 ft で水平）、`s139` 27/27（巡航上昇：MCP FL190 で押すと CRZ ALT が FL190、FMC は上昇、FL190 で VNAV PTH・A/T SPD、行き過ぎなし。捕捉は約 600 ft 手前から）、新設の `s143` 15/15（T/D の 2 分の内に RESET MCP ALT、30 秒後も残る、MCP を 10,000 ft にすると消えて降下）。12:12 の起動し直しの後の最初のフライト（s143）は A/P の CMD L が入らず捨て（空中開始の初期化の CMD L の押し直しが約 5 秒で尽きる：別に直す）。s139 の初めの回も同じく CMD L が入らなかった。

## 64. 段 9d2a の実装（2026-10-31：早期降下と cruise climb・descent の誘導、CRZ のページの見出し）

- 資料：FCOM p.649（ノブの押し：巡航で MCP が CRZ ALT と違えば CRZ ALT を MCP に、T/D の 50 NM の内で下なら減らした率の降下）、p.1257（cruise climb・cruise descent：ACT ECON CRZ CLB・CRZ DES、MCP が DES のページの SPD TRANS・SPD RESTR の高度より下なら消す）、p.1260–1261（早期降下：VNAV が減らした率で降り、アイドルの経路に交わるまで。A/T は THR から HOLD、ピッチは VNAV SPD。50 NM より前は cruise descent で、目標の速さは巡航の ECON）、p.1347（CRZ のページの見出し）、p.1389（ノブで DES NOW の働き：50 NM の内か、MCP が降下の最も高い制限より下）、p.1393（DES NOW：約 1,250 fpm、降下の速さの予定、レバーで率を変えられる、経路で移る、降下段階に）、p.665（早期降下の後の経路で VNAV SPD から PTH）。ATA34_2 p.615（VNAV の speed/thrust：上昇・早期降下・E/O の drift down）、p.616（speed/HOLD：step descent）、p.624（巡航のノブ、50 NM の内で DES NOW）、p.658・p.666（VNAV の降下の A/T）。FMSPG p.3.5-5・3.5-6（DES NOW：EXEC が要る、上昇と巡航の制限を消す、約 1,250 fpm、その率に達すると THR HOLD、経路に交わると捕捉）。
- 作ったもの：
  - VNAV のモデル（`B747.68.vnav_model.lua`）：
    - 早期降下（`des_now`）：降下でない段階から降下段階に。VNAV SPD（降下の速さの予定）、A/T に THR と V/S −1,250 fpm（`EARLY_VS`）。経路の下に 100 ft（`EARLY_BELOW`：推定）出て、経路が機体まで下がると VNAV PTH・IDLE。T/D を過ぎて経路の上なら、すぐ経路へ（VNAV PTH）。遅い時の SPD（FCOM p.1259）は早期降下の間は無い（エレベーターが速さを保つ）。
    - cruise climb・descent（`crz_chg`）：巡航で CRZ ALT が 500 ft より上か、機体より 500 ft 下に下げられた（前の更新の CRZ ALT より下：ノブの押しか CDU の入力。機体が CRZ ALT より上にいるだけでは始めない：X-Plane の s144・s145 で空中開始の揺れで機体が 1,200 ft 上にいて、FMC が始めから cruise descent に入った）。上は上昇の段階（誘導と推力は上昇の：THR REF、上昇の推力の基準は段 9g まで推定）で目標の速さは巡航の。下は巡航の段階のまま VNAV SPD で、A/T に THR と −1,250 fpm（率は推定：資料に無い）、目標の速さは巡航の（FCOM p.1261）。新しい CRZ ALT の 50 ft の内で巡航（VNAV PTH・SPD）。
    - 計画の経路と T/D：予測の降下の経路（`dp`）は E/D から天井（45,100 ft）まで延び、CRZ ALT の上へも続く。VNAV のモデルは、これを CRZ ALT で頭打ちにした計画の経路（T/D まで CRZ ALT で水平）で偏差を見て、T/D は経路が CRZ ALT に達する所（`path_e_at`）とする。前は延びた経路のままで、早期降下は CRZ ALT の上の経路に当たりに行った（X-Plane の s144 で、経路が機体の 13,000 ft 上になり、当たらないまま MCP の 10,000 ft まで降りた）。降下段階の始めの判定（T/D を過ぎて経路が機体以下、MCP が CRZ ALT と機体より下）は頭打ちの経路と T/D で行う（延びた経路では T/D より前は経路が機体の上なので、前も T/D の手前では降下に入らなかった）。
  - A/T のモデル（`B747.70.at_model.lua`）：VNAV の THR は FMC の V/S へ（前は FLCH の 125 秒の則）。則は目標の速さでのエネルギーの率（`evs`：慣性の V/S と、目標の速さの測り方（IAS か Mach）の変化から求める、速さを目標に保てば出る V/S。A/T のモデルの `target_vs`。ATA34_2 p.647 の「FMC の基準推力」に、定常の飛行で一致する閉ループで近づける：推定。真対気速度の変化で見た版は、IAS を保つ降下では真対気速度が下がる分だけ V/S が約 260 fpm 浅くなり、HOLD の二つの帯に同時に入れなかった：16:50 の s146・s144）で、効きは FLCH の 1/2（`K_VS_VNAV`：この則の遅れはエンジンだけ。s146 のエンジン（無駄時間 2 秒と遅れ 4〜7 秒）の模擬で、25 秒で 100 fpm の内。FLCH の効きでは揺れる）。HOLD は、慣性の V/S とエネルギーの率が FMC の値の 100 ft/min 以内で、速さが目標の 5 kt 以内に 5 秒とどまったとき（`REACH_S`。どれも推定）か、aft stop か、手の 8°（FMSPG p.3.5-5：その率に達すると THR HOLD）。試してやめた案：計器の速さの変化でエネルギーの率を見る（計器の速さは遅れ、上昇しても下がるので ±1,500 fpm 揺れ、8 秒落ち着く判定が満たせなかった。X-Plane の真対気速度なら、s146 の減速中の +1,500 fpm の上昇でも −100 fpm となめらか）、表示の EPR（`display_EPR`）でエンジンの遅れを見込む（表示の EPR が X-Plane の EPR より速く動き、遅れを表さなかった）。FMC が THR を求める間は HOLD のまま、FMC の段階が変われば THR から（cruise descent の後の早期降下）。X-Plane で順に分かったこと：初めの版（計器の V/S が率を一度越えたら HOLD）は、s144・s145 で目標より 50 kt 遅いうちに HOLD になり、−3,600 fpm まで行った後、目標の速さでそのレバーのまま水平や上昇になった（FLCH の降下でも推力が多ければ上がるのは実機どおり：ATA22 p.338 の 8,000 ft の ALT HOLD）。次の版（慣性の V/S で 8 秒）は、目標の速さに着いた後の機首上げの間の −230 fpm を見てレバーを aft stop まで下げ、アイドルで −2,600 fpm になった。三つ目の版（効きを 1/4 にして、率と速さに達した瞬間に HOLD）は、s144・s145・s146 とも、押した時がまだ空中開始の行き過ぎ（約 2,000 ft 上）を VNAV PTH が戻す降下（−2,800 fpm）の途中で、VNAV SPD のピッチが目標の速さを取って水平へ戻る間に V/S が率を 1 秒ほどで通った所で HOLD になった。レバーは巡航に近い推力のまま（0.12〜0.19）で、s144・s145 は水平から上昇に戻り、早期降下も cruise descent も進まなかった（s146 は HOLD で終わる試験だったので見えなかった）。そこで率と速さに 5 秒とどまる条件を足し、3 本のシナリオは押す前に FL300 の水平の巡航を待つようにした（s146 には HOLD の 30 秒後の V/S の確かめも足した）。四つ目の版（慣性の V/S で 5 秒）は、s146・s145 で、押した時の速さ（306 kt）が新しい目標（降下の 294 kt、cruise descent の M.784 の 297 kt）より速く、VNAV SPD が速さを落とすために +1,200〜1,500 fpm で上昇した。V/S を見る A/T はその間もレバーを絞り続けて aft stop で HOLD（アイドル）になり、その後は −2,600〜−3,300 fpm で降りた。その上昇の間のエネルギーの率は −100〜−200 fpm で、推力は要る分だけ絞ればよかったので、則をエネルギーの率に直した。その版の X-Plane（16:00〜16:23、起動し直した後）：s146 27/29、s145 25/26、s144 22/28。落ちたのはどれも HOLD の時とその後の V/S で、原因は A/T でなく EEC の推力の隙間：EEC は表示の EPR（`B747.42.epr_model.lua`）をレバーの指令に合わせるようスロットルを閉ループで動かすが、表示の EPR は 0.97 で頭打ち（`IDLE_EPR`：推定）で、FL300・M.78 ではそれが片発約 34 kN（目標の速さでエネルギーの率 −540 fpm）に当たる。指令がそれより下がるとスロットルは 0（アイドル、約 −2,800 fpm）まで落ち、−1,250 fpm に要る片発約 26 kN は作れない。s145 では A/T と EEC が振れ合い（X-Plane のスロットルが 0 と 0.7〜1.0 の間、V/S が −600 と −2,400 fpm の間を約 35 秒ごと）、s146・s144 は 40 秒ほどでレバーが aft stop に着いて HOLD（アイドル）になった。cruise descent そのものは FL240 で VNAV PTH・SPD になった（s145）。s144 はアイドルで降りたので経路の 5,500 ft 下のまま当たらず、MCP の 10,000 ft で VNAV ALT。直すのは次の項目（EEC のレバーのアイドルの端の指令と表示の EPR の下限：FCOM p.876、EEC はアイドルから最大までの EPR を計算する）。また s145 の一つ前の版では、FL240 の捕捉の直前に X-Plane の長いフレーム（20 fps を切るとシムの時刻は 0.05 秒しか進まない）で XTLua の SIM_PERIOD が実時間の数秒になり、AFDS の F/D のピッチの指令（−2.5°）と SRM のトリムが同じフレームで一度に動き、1,000 ft 行き過ぎた（30 本の記録で 1 回。制御のループの時間の刻みの上限も別の項目で）。性能のモデルの推力（CRZ のページの EPR）を目標にする案は、モデルの EPR が X-Plane の EPR と合わない（FL310 の水平でモデル 1.12、X-Plane 1.29）のでやめた。IDLE・THR の HOLD の掛け金は、FMC が別のモードを求めるか水平（VNAV ALT・PTH）で外す（前は IDLE の掛け金が水平の後も残り、降下を続けるとすぐ HOLD）。
  - AFDS（AP のつなぎ）：FMC の高度の捕捉は VNAV SPD のとき（前は上昇の段階だけ）：cruise descent の新しい CRZ ALT、早期降下の次の制限。A/T の servo に FMC の V/S。
  - FMS（`B747_fms_alt_sel_push`）：巡航で MCP が CRZ ALT より下の押し：T/D の 50 NM の内か、MCP が降下の最も高い制限より下なら早期降下（`B747_fms_des_now`：T/D の前の脚の高度の制限を有効な経路から消す）。それ以外は cruise descent（CRZ ALT を MCP に、DES のページの SPD TRANS・SPD RESTR の高度が MCP より上なら消す）。T/D を過ぎていれば何もしない（MCP が CRZ ALT より下なら FMC が自分で降下に入る）。T/D までの距離（`B747_fms_vnav_td`：経路が CRZ ALT に達する所、無ければ頂き）は RESET MCP ALT とも共通。
  - CDU（`B744.fms.pages.vnav.lua`）：ACT の見出しは FMC の段階（`B747_fms_vnav_page`：地上と有効な経路が無いときは無し。前は AP の前の `flightPhase`）。cruise climb・descent の間は CRZ のページが ACT で、見出しが CRZ CLB・CRZ DES（FCOM p.1347）。
- 残り：DES NOW の 6R（MOD と EXEC：9d2b）、DES DIR・CLB DIR（9d2b）、CRZ ALT の CDU での入力の MOD（今は入れるとすぐ効く）、PROGRESS のページはまだ前の `flightPhase`。
- 試験：
  - 回帰：`vnav_model_test.lua` 100 件（T/D の手前で MCP を下げても巡航、CRZ ALT の上へ延びた経路を頭打ちにした計画の経路で早期降下が当たる、機体が CRZ ALT より上にいるだけでは cruise descent にならない、DES NOW の早期降下と経路での VNAV PTH、T/D を過ぎて経路の上の DES NOW はすぐ PTH、上昇中の DES NOW、cruise climb・descent と 50 ft の内の巡航）、`at_model_test.lua` 93 件（VNAV の THR はエネルギーの率で FMC の V/S へ FLCH の 1/2 の効きで（減速しながら上昇する間は、エネルギーの率の誤差だけ絞る）、V/S とエネルギーの率がその率に目標の速さで 5 秒とどまれば HOLD（V/S だけでは THR のまま）、率を 2 秒で通るだけなら THR のまま、間に速さが外れるか SPD を挟めば数え直し、30 kt 遅ければ THR のまま、計器の V/S が率でも慣性の V/S が違えば THR、aft stop・手で HOLD、HOLD のまま、段階が変われば THR から、IDLE でやり直し、水平で掛け金が外れる）、`afds_glue_test.lua` 242 件（cruise descent の VNAV SPD・THR、手で HOLD、新しい CRZ ALT の捕捉で VNAV PTH・SPD）、`pred_glue_test.lua` 104 件（巡航のノブ：80 NM で cruise descent と SPD RESTR の削除、30 NM で早期降下、MCP が最も高い制限より下で早期降下、CRZ のページの ACT ... CRZ DES と DES のページの ACT）、`vnav_pages_test.lua` 75 件（ACT は FMC の段階、CRZ CLB・CRZ DES の見出し）。全 134 本。シナリオのランナーの CDU のキーに VNAV（`func_key/des`）を足した（前は文字として打ち込まれた）。

## 65. 段 9d2b の実装（2026-10-31：VNAV のページの 6R の DES NOW>・DES DIR>・CLB DIR>）

- 資料：FCOM p.1329（CLB DIR：機体と CRZ ALT の間に上昇の高度の制限があるとき、押すと機体と MCP の高度か CRZ ALT の低い方の間の制限を全部消す、CRZ ALT は変えない）、p.1393（DES NOW：T/D があり降下段階でないとき。押すと約 1,250 fpm の降下と降下段階。DES DIR：降下段階で機体と E/D の間に制限があるとき、押すと機体と MCP の高度の間の制限を全部消す）。FMSPG p.116（CLB DIR：MCP の高度にある制限は残す）、p.3.5-4〜3.5-6（DES DIR と DES NOW は押すと EXEC の灯、EXEC で働く。DES NOW は上昇と巡航の制限を消す）。ATA34_2 p.558、p.564（6L の ERASE：修正が待っている間）。
- 作ったもの：
  - FMS（`B747.68.xt.fms.lua`）：`B747_fms_vnav_prompt`（ページごとの 6R：CLB のページは ACT で機体と CRZ ALT の間に上昇の制限があれば CLB DIR>、DES のページは ACT なら機体と E/D の間に降下の制限があれば DES DIR>、ACT でなく T/D が先にあれば DES NOW>）、`B747_fms_vnav_select`（押し：有効な経路の修正を作り、CLB DIR は機体と MCP の高度か CRZ ALT の低い方の間、MCP の高度にあるものは残す、DES DIR は機体と MCP の高度の間、DES NOW は T/D の前の脚の高度の制限を消す。速さの制限は残す：ノブの押しと同じ）、`B747_fms_vnav_exec`（EXEC の後：DES NOW なら VNAV のモデルの早期降下）、`B747_fms_vnav_erase`。修正が無くなれば（よそで EXEC・ERASE）VNAV の分も消す。制限を持つ脚を上昇と降下に分けて回す `vnav_con_legs` に、ノブの押し（段 9d1）もまとめた。
  - CDU（`B744.fms.pages.vnav.lua`）：6R の表示と押し、修正の間は見出しが MOD（そのページの 6R の修正：CLB のページは CLB DIR、DES のページは DES NOW・DES DIR）、6L は ERASE（3 ページとも：修正が待っている間）、VNAV のページの EXEC は経路の EXEC（前は X-Plane の FMS へ）。`B744.fms.pages.rte.lua` の EXEC と ERASE が VNAV の分も扱う。
- 推定：DES DIR の後の誘導は、制限が消えた予測の経路をふつうの降下で飛ぶ（FMSPG p.3.5-5 の図の「MCP の高度へまっすぐ降りる、スロットルは HOLD」は作らない）。修正の間の MOD の見出しは、6R で作ったページだけ（経路だけの修正では ACT のまま）。
- 試験：`pred_glue_test.lua` 130 件（CLB DIR：MCP の上と MCP の高度の制限は残り、間のものが修正の上で消え、ERASE で戻り、EXEC で有効な経路に。DES NOW：DES のページの DES NOW>、押すと MOD ... DES と EXEC の灯、EXEC の前は巡航、EXEC で降下段階の VNAV SPD・THR。DES DIR：降下段階で DES DIR>、EXEC で MCP の高度より上の制限が消え下は残る）。全 134 本。新設の X-Plane の `s146_vnav_des_now`。

## 66. 段 9d3 の実装（2026-10-31：速度介入）

- 資料：FCOM p.643（IAS/MACH のノブ：VNAV のとき押すごとに窓を開け閉めする。閉じれば FMC の目標速度、開けば速度介入で、ノブの速さが目標。VNAV PTH の降下中ならピッチのモードが VNAV SPD になり、高度の制限を捕捉して VNAV PTH になるまでピッチで速さを保つ。進入中は VNAV PTH のまま A/T が速さを取る。窓が開くのは FLCH SPD・V/S・TO/GA・ALT・G/S のとき）、p.1255（上昇で低い速さにして急な上昇）、p.1327・p.1347・p.1391（CLB・CRZ・DES のページの見出しの MCP SPD）。ATA34_2 p.623（ノブの押しは FMC への discrete。窓が開いて今の FMC の目標速度を示し、FMC はその速さを目標にする。もう一度押すと普段に戻る）、p.557・p.563（ACT MCP SPD CRZ・DES）、p.568（PROGRESS の 5L の MCP SPD）。
- 今まで：ノブの押しで AP の前の `manualVNAVspd` が切り替わり、窓が開いて MCP の速さで飛ぶが、FMC は知らない（ピッチのモードも見出しも変わらない）。閉じるとき前の VNAV の速さを一度書いていた。
- 作ったもの：
  - AP：VNAV で窓が開いている間 `laminar/B747/autopilot/spd_intervention` を 1 に（init で作る。ATA34_2 p.623 の discrete。IAS/MACH の切り替えで窓が 0.25 秒閉じる間も落とさない）。閉じるときの前の VNAV の速さの書き込みはやめた（FMC の目標速度は `afds_fmc_vnav` が書く）。
  - FMS：介入の間、MCP の速さ（`autopilot/ias_dial_value`：kt、Mach は ×100）を VNAV のモデルの `spd_int` に（目標速度は前からそれを使う）。`B747_fms_spd_int` をページに。
  - VNAV のモデル：降下段階で介入なら VNAV SPD（ノブの速さをピッチで）、A/T は IDLE（その後 HOLD）、FMC の高度は次の制限（AFDS が VNAV SPD で捕捉して VNAV PTH で水平、制限の先で FMC の高度が下がると VNAV SPD に戻る）。経路の偏差は ND のために出す。窓を閉じれば経路の降下（VNAV PTH）に戻る。早期降下と cruise descent は介入でも THR のまま（目標がノブの速さ）。上昇・巡航は目標速度が替わるだけ（前から）。
  - CDU：有効なページの見出しを MCP SPD に（ACT MCP SPD CLB・CRZ・DES）。PROGRESS の 5L は介入で MCP SPD、ほかは FMC の段階の速さの型（前は AP の前の `flightPhase`）。PROGRESS の TO T/C も FMC の段階で。
- 試験の道具で分かったこと：ノブの押しの処理は、ノブの絵が押し込みのままなら次の押しを離しとして捨てる（前からの守り：高度のノブも同じ）。Web API の長さ 0 のコマンドでは離し（phase 2）が XTLua に届かず、s147 の初めの版は 2 回目の押しが捨てられた。実際の押し（マウス・ボタン）は押しと離しが別に来るので起きない。シナリオではノブを 0.2 秒押して離す。
- 推定・残り：進入中（on approach：FCOM p.1261 の条件）の VNAV PTH のままの介入は段 9e。介入の間の予測（DES のページの速さの行、T/D や E/D の時刻）はまだ FMC の予定の速さ。PROGRESS の予測の無いときの古い経路は前の `flightPhase` のまま。
- 試験：`vnav_model_test.lua` 110 件（降下の介入で VNAV SPD・IDLE、ノブの 270 kt と M.82、FMC の高度は次の制限、40 kt 遅くても IDLE のまま、閉じれば VNAV PTH、早期降下は THR のまま）、`afds_glue_test.lua` 251 件（VNAV でノブを押すと `spd_intervention` 1・窓が開いて FMC の 300 kt、ノブを 280 に、もう一度押すと 0・窓が閉じて FMC の 300 kt）、`pred_glue_test.lua` 137 件（介入で FMC の目標がノブの 270 kt・M.805、ACT MCP SPD DES、PROGRESS の 5L の MCP SPD、閉じれば FMC の目標と ECON）、`vnav_pages_test.lua` 79 件（ACT MCP SPD CRZ・CLB、有効でないページはそのまま）。全 134 本。新設の X-Plane の `s147_vnav_spd_intervention`。

## 67. 段 9e の段取り（2026-10-31：降下の許容と進入）

- 資料：FCOM p.1258（降下の目標速度の上限：ECON 349 kt＝VMO/MMO −16、乗員の入力 354 kt＝−11）、p.1259–1260（経路を保つ間の速さの許容と速度の逆戻り、THRUST REQUIRED・DRAG REQUIRED）、p.1261–1262（on approach の条件と働き、glide path angle、進入復行）、p.1391（END OF DES の見出し）、p.1431・p.1434（DRAG REQUIRED・THRUST REQUIRED の文言）、FMSPG p.3.5-17 の図（限界の速さで経路を離れて VNAV SPD、経路に戻って VNAV PATH）。
- 今：VNAV PTH の降下は経路へ K_PATH で戻すだけで、速さは成り行き（遅いときの A/T の SPD と THRUST REQUIRED は 9f2・9f3 で済）。DRAG REQUIRED は AP の前の判定（ダイヤルより 10 kt 速く増えていて、レバーがアイドル）。on approach・END OF DES・進入復行は無い。
- 段：
  - 9e1：降下の速さの許容と速度の逆戻り。ECON の目標の上限 349 kt・入力 354 kt。経路を保つ間の速さの幅：最初の速さの制限の上は、遅い側 15 kt で A/T の SPD、速い側 349 kt で DRAG REQUIRED・354 kt まで。下は、遅い側 10 kt、速い側 +10 kt で DRAG REQUIRED・+15 kt まで（遷移の高度の下では遷移の速さ +5、フラップがあれば placard −5 まで）。その先は経路から 150 ft まで離れて速さの変化を止め、それも超えると速度の逆戻り（VNAV SPD。目標は速い側が 349 kt か遷移の速さ −10、遅い側が最良の待機速度と最小の機動速度の高い方 +5 か遷移の速さ −10）と、そのメッセージをもう一度。経路に戻れば VNAV PTH（推定：FMSPG の図）。DRAG REQUIRED は FMC の判定に（前の AP の判定は使わない）。
  - 9e2：on approach（条件：公表の進入を有効な経路に入れて最初の点を過ぎたか、VFR の進入で FAxxx を過ぎたか RWxx へ 25 NM の内。外れる：TO/GA、着陸、最後の点の先で END OF DES）。働き：速度介入でも VNAV PTH のまま A/T が速さ（段 9d3 の残り）、MCP の高度が 300 ft 以上上でも降下を続ける、placard の 5 kt の内まで速くなって 150 ft 上なら VNAV SPD。END OF DES の見出し（E/D を過ぎて上昇の脚が続かないとき）。
  - 9e3：進入復行（TO/GA で、降下の制限のうち機体より下を消す、CRZ ALT を進入復行の最も高い高度に、上昇の段階へ、400 ft の上で VNAV・LNAV）。glide path angle の脚は、航法データに角度があるかを見て決める。

## 68. 段 9e1 の実装（2026-10-31：降下の速さの許容と速度の逆戻り）

- 資料：§67 の FCOM p.1258–1260、p.1431、FMSPG p.3.5-17。最良の待機速度は性能の DB の待機の表（PI.11.6：`B747_perf_db.hold`）。
- 作ったもの（VNAV のモデル、経路の降下：早期降下と速度介入のときは除く）：
  - 速さの限界（`speed_limits`）：最初の速さの制限（ここでは速さの遷移の高度）の上は、DRAG REQUIRED が VMO/MMO −16（349 kt：性能の DB の `econ_limit`）、経路を保つのは −11（354 kt）まで。下は、DRAG REQUIRED が目標 +10、保つのは目標 +15 まで、遷移の速さ（SPD TRANS の速さ +10）+5 とフラップの placard −5 を超えない。遅い側は最小の機動速度まで（それより前は 9f2 の A/T の SPD）。
  - その先は経路を 150 ft（`PATH_TOL`）まで譲る：速すぎれば浅く（速さの超過 1 kt に 100 fpm：`SPD_VS`、推定）、遅すぎれば深く降りる。150 ft を超えても速さが戻らなければ速度の逆戻り（`reversion`）：VNAV SPD、A/T は IDLE。目標は、速い側が 349 kt（上）か SPD TRANS の速さ（下）、遅い側が最良の待機速度と最小の機動速度の高い方 +5（上）か SPD TRANS の速さ（最小の機動速度より下にしない：下）。経路に戻れば（速い側は上から、遅い側は下から）VNAV PTH と予定の速さ（推定：FMSPG の図）。
  - メッセージ（`out.msg`、FMS が `laminar/B747/fms/vnav/msg` に：1 THRUST REQUIRED、2 DRAG REQUIRED）：DRAG REQUIRED はその速さを超えると出て、2 kt 下で消す（推定）。逆戻りの間は、速い側が DRAG REQUIRED、遅い側が THRUST REQUIRED。AP がそれで FMC のメッセージの旗（9 DRAG REQUIRED、45 THRUST REQUIRED）を立てる（THRUST REQUIRED の、A/T が切れていて FMC が SPD を求める条件は 9f3 のまま）。前の AP の DRAG REQUIRED の判定（ダイヤルより 10 kt 速く、増えていて、レバーがアイドル）は使わない。
  - FMS：降下の間、最良の待機速度をモデルに（`hold_cas`）。
- 推定：経路を譲る量の決め方（速さの超過に比例して浅く・深く）、DRAG REQUIRED の 2 kt の戻り、逆戻りの終わり（経路に戻ったとき）。「最初の速さの制限」を速さの遷移の高度に代えたこと（SPD RESTR や点の速さの制限がもっと上にあっても見ない）。
- 試験：`vnav_model_test.lua` 125 件（349 を超えて DRAG REQUIRED・経路は保つ、354 を超えて浅く、150 ft を超えて逆戻りで 349 の VNAV SPD・IDLE・DRAG REQUIRED、経路に戻って PTH と予定の 290、下では 250 を超えて DRAG・255 を超えて 240 の逆戻り、遅い側は深く・150 ft の下で待機速度 +5 の逆戻りと THRUST REQUIRED・下から戻って PTH、速度介入で逆戻りが消える）、`afds_glue_test.lua` 254 件（FMC のメッセージで旗 9・45）。全 134 本。新設の X-Plane の `s148_vnav_speed_reversion`。

## 69. 段 9e2 の実装（2026-10-31：on approach と END OF DES）

- 資料：§67 の FCOM p.1261–1262（on approach の条件と働き）、p.643（進入中の速度介入は VNAV PTH のまま A/T が速さ）、p.1258（E/D は滑走路の 50 ft 上：VOR の進入は MAP）、p.1391（END OF DES）。
- 作ったもの：
  - FMS：on approach（`laminar/B747/fms/vnav/on_app`）は、有効な経路で進入の脚（`APPR`）の点が過ぎた側にあり、空中で、E/D を過ぎる前（公表の進入の最初の点を過ぎた：FCOM p.1261）。END OF DES は E/D の点（`vnav_geo_set` の `ed_p`）を過ぎたときに立て、新しい E/D が前に来るか地上に降りるまで保つ。予測の入力は、進入の滑走路の脚を過ぎた後の進入の脚（進入復行）の制限を E/D にしない（前はそれが新しい E/D になった）。
  - VNAV のモデル：on approach では、速度介入でも VNAV PTH のまま A/T が SPD でノブの速さ（p.643、p.1261）。フラップが出ていれば経路を保つのはフラップの placard −5 まで、その先 150 ft 上で VNAV SPD（目標の速さのまま：p.1262 は名を挙げない、推定）。END OF DES（`end_des`）は水平（V/S 0）で A/T は SPD、経路が無くても VNAV は有効（推定：資料はこれ以上を書かない）。
  - CDU：DES のページの見出しは、E/D を過ぎると ACT END OF DES。
- X-Plane で分かったこと：経路より下から空中開始すると、FMC は降下でなく上昇の段階のまま（降下に入るのは経路が機体以下のとき：初めの s149 は 4,500 ft から FL300 へ上昇した）。速度介入で目標を下げても、経路を降りる間は A/T がアイドルで減速できず、速さは経路の降下で決まる（DRAG REQUIRED が出て、水平になって減速する：二つ目の s149。この進入の BERRY・BOLAL の 4,000 ft は「以上」なので経路はそこで水平にならず、MCP の 2,000 ft の VNAV ALT で減速した：三つ目）。
- 推定・残り：VFR の進入（FAxxx、RWxx の 25 NM）の on approach は作っていない（VFR の進入の作り方が無い）。MCP を機体より 300 ft 以上上にしても降下を続けるのは、今は on approach に限らない（MCP の高度と経路の食い違い（FCOM p.645 の VNAV ALT）は、MCP が下で降下が当たるときだけ）。glide path angle の脚（航法データの −3.00 などの角度：CIFP にはある）は 9e3 で決める。TO/GA で on approach を出るのは 9e3。
- 試験：`vnav_model_test.lua` 131 件（on approach の速度介入は VNAV PTH・A/T の SPD、外なら VNAV SPD、placard −5 の内は PTH・超えて 150 ft 上で目標のままの VNAV SPD、END OF DES は水平・A/T の SPD・経路なしでも有効）、`pred_glue_test.lua` 144 件（進入の最初の点を過ぎて on approach、滑走路を過ぎて END OF DES と on approach の終わり、DES のページの ACT END OF DES、予測の後も END OF DES と VNAV の有効のまま）。全 134 本。新設の X-Plane の `s149_vnav_on_approach`。

## 70. 段 9e3 の実装（2026-10-31：進入復行）

- 資料：FCOM p.1261–1262（Missed Approach：TO/GA で。VNAV と LNAV は 400 ft RA より上でだけ入る、降下の高度の制限のうち機体より下を消して点は残す、進入復行の最も高い高度を新しい巡航高度に、降下から上昇の段階へ、巡航の段階では目標が SPD TRANS・最良の待機速度・ECON 巡航の最も厳しいもの。TO/GA で on approach を出る）、p.1264（進入復行で選ぶと VNAV SPD、進入復行の高度で VNAV PATH）、FMSPG p.97（CRZ ALT は進入復行に移ると変わる）、ATA34_2 p.472（FMC はスラスト・レバーの TO/GA のスイッチでなく、AFDS の go-around の状態を使う）。
- 作ったもの：
  - FMS：AFDS の G/A（FMA のピッチが空中で TO/GA になった時：`laminar/B747/autopilot/FMA/active_pitch_mode`。T/O は地上でなる）で、FMC が降下の段階か on approach か END OF DES なら進入復行（`B747_fms_missed_approach`）。有効な経路の、進入復行の脚（CIFP の記述の 3 文字目の M から：`l.missed`）より前の脚で、機体より下の高度の制限を消す（点は残す：`delete_alt_active`）。進入復行の脚の最も高い高度を CRZ ALT に（無ければそのまま：推定）。上昇の段階へ、END OF DES を終える。そのときの進入の脚（通過済みと前：経路の変更の複製は元の脚で見る）を覚え（`vnavMissed`）、それらは on approach・END OF DES の判定にも予測の E/D にも使わない（前の滑走路が E/D にならない。入れ直した進入の新しい脚は使う）。地上で終わる。
  - VNAV のモデル：`M.missed`（上昇の段階へ、降下の状態を消す）。進入復行の CRZ ALT のままの巡航（`missed`）では、目標を SPD TRANS（降下の、目的地の：その高度より下）・最良の待機速度・ECON 巡航の最も低いものにし、最小の機動速度 +5 より下にしない。上昇の目標は上昇の予定の速さ（SPD TRANS とフラップの placard −5 まで）。
  - 400 ft RA の条件は AFDS にある（G/A からの LNAV は 400 ft 以上で、VNAV は 400 ft RA より上で engage：段 1e・9c）。
- X-Plane で分かったこと：初めの s150 は、MCP の 2,000 ft の捕捉の途中（2,255 ft）で G/A した。上昇の段階にした同じフレームで、古い降下の経路の T/D の先で MCP が 200 ft 以上下にあるため、降下の段階に戻った。次の予測で経路が消え、VNAV は無効になった。FMC は進入復行の時に古い経路をすぐ捨てるように直した（`vnavGeo`、同じフレームの `update_vnav` でも使わない）。G/A からの MCP 高度の捕捉は前の則の目標（`laminar/B747/autopilot/altitude_dial_ft`：つまみで写る）を見るので、シナリオでは両方を書く（s104 と同じ。初めの s150 は G/A のまま 4,500 ft へ上がった）。
- 推定：進入復行に最高高度が無いときに CRZ ALT を変えない。SPD TRANS を降下の（目的地の）ものとしたこと。上昇の目標速度（資料は名を挙げない）。進入復行を、FMC が降下の段階・on approach・END OF DES のときに限ったこと（FCOM は「降下から上昇へ」とだけ書く）。
- glide path angle の脚（段 9e2 から持ち越し）：CIFP に角度がある（RJBB の ILS06LY の BOLAL・RW06L に −3.00）ので作る。予測の経路をその角度にすること、LEGS の表示、その脚の前の点を過ぎてから経路に乗るまで水平にすること（FCOM p.1262）がある。範囲が広いので段 9e4 に分ける。
- 試験：`vnav_model_test.lua` 140 件（END OF DES から進入復行で上昇・VNAV SPD・THR REF・CRZ ALT 3,000 へ、上昇の目標は placard −5、3,000 ft で巡航・VNAV PTH・A/T の SPD、目標は最良の待機の 228、待機が 255 なら SPD TRANS の 240、最小の機動が 230 なら 235、速度介入は MCP の速さ、進入復行の後でなければ ECON の M.85、10,000 ft より上では待機の 255）、`pred_glue_test.lua` 168 件（END OF DES の 1,500 ft で G/A：上昇・VNAV SPD・THR REF、CRZ ALT は進入復行の最高の 4,000、END OF DES の終わり、VNAV は有効。進入を入れ直すと、前の進入の通過済みの脚では on approach にならず、新しい進入の最初の点で on approach、3,500 ft・MCP 1,000 ft で経路の降下。そこで G/A：そのフレームから上昇の段階のまま（経路が消える）、on approach を出る、3,500 ft より下の制限を消し、上のものと進入復行のものは残す、滑走路の点は残るが E/D にならない。滑走路を過ぎても END OF DES にならず、4,000 ft の巡航は VNAV PTH・SPD で、目標は SPD TRANS と最良の待機速度の低い方。巡航で G/A をもう一度押しても何もしない。地上で終わり ECON 巡航に戻る）。全 134 本。新設の X-Plane の `s150_vnav_missed_approach`：二つ目（20:35〜20:44、同じ起動の 6 回目の読み直し）は 33 件中 31 件。ILS06LY を VNAV で降り、MCP の 2,000 ft の捕捉の途中（2,255 ft）で TO/GA した。FMC は上昇の段階になり、CRZ ALT は 3,000（LILAC）、on approach を出て、RW06L の 63 ft の制限が消えた。LNAV と VNAV を押すと VNAV SPD（A/T は THR REF）、3,000 ft で VNAV PTH・巡航の段階になった。目標は 235.7 kt（FMC の重さ 286 t の最良の待機速度：SPD TRANS の 240 より低い）で、A/T の SPD でそこへ。RW06L を過ぎても巡航・VNAV PTH のまま。落ちた 2 件はシナリオの作りと前からの差：VNAV PTH の表示が 2,255 ft から出た（G/A の上昇率で 3,000 ft の捕捉が早く始まる。シナリオは高度が着くのを待つ形に直した）、VNAV キーがいつも CLB のページを開く（ATA34_2 p.552：空中では有効なページ。次のコミットで直す）。初め（20:18〜20:31）は 33 件中 19 件：上の降下の段階への戻り（直した）と、G/A の捕捉が見る前の則の目標を書いていなかったこと（シナリオ）

## 71. VNAV キーのページ（2026-10-31：CDU-06 の残り）

- 資料：ATA34_2 p.552（FMCS - CLIMB PAGES：空中で VNAV キーを押すと有効な性能モード（CLB・CRZ・DES）のページ、地上では CLB のページ。ほかのページへは 1/3・2/3・3/3 の番号で）、FCOM p.1327（CLB のページは VNAV キーで選ぶ 3 ページの 1 枚目）。
- 前：VNAV キーはいつも CLB のページ（1/3）を開いた（GAP_ANALYSIS の CDU-06 の残り。二つ目の s150 は、進入復行の後の巡航でも CLB のページが出た：§70）。
- 作ったもの：VNAV キーは、空中で有効な経路があれば FMC の段階のページ（`B747_fms_vnav_page`：CLB 1、CRZ 2（cruise climb・descent も）、DES 3）、地上と有効な経路が無いときは CLB のページ。
- 推定：空中で有効な経路が無いときを CLB のページとしたこと（FMC の段階が無い）。
- 試験：`pred_glue_test.lua` 169 件（巡航で VNAV キーと NEXT 1 回で DES のページ、降下では VNAV キーだけで ACT ECON DES・ACT END OF DES、進入復行の後の 4,000 ft の巡航で ACT … CRZ）、`vnav_pages_test.lua` 79 件（補助関数は VNAV キーが開いたページから NEXT で数える）。地上で押す試験（`vnav_pages_test`・`fmc_fixes_test`・`des_forecast_test`）は CLB のページのまま。シナリオ s144〜s147 の VNAV キーの押し方を直した（巡航の CRZ・降下の DES は VNAV だけ、巡航から DES は NEXT 1 回）。X-Plane：s150（20:57〜21:06、起動し直した後の 2 回目の読み直し）33/33。進入復行の後の 3,000 ft の巡航で VNAV キーを押すと ACT ECON CRZ のページ（二つ目の s150 は ECON CLB）。9e3 の残りも確かめた：MCP の 2,000 ft の捕捉の途中の G/A で上昇の段階・CRZ ALT 3,000・on approach を出る、VNAV SPD（A/T は THR REF）から 3,000 ft で VNAV PTH・巡航、目標 235.7 kt を A/T の SPD で、RW06L を過ぎても巡航のまま。Log.txt に Lua の誤りなし

## 72. 段 9e4 の実装（2026-10-31：進入の glide path angle）

- 資料：FCOM p.1262（glide path angle の付いた脚は LEGS に出て、VNAV はその角度で VNAV PTH の誘導。その脚の前の点を過ぎると、経路に乗るまで水平。STAR の脚にもありうる）、p.1405（LEGS の見出しの行の右に「GP 3.00°」。航法データの GP の角度で、ILS・B/C・GPS・LOC・RNV・NDB・VOR の進入。VNAV PTH のときその角度で誘導）。CIFP の欄 29（垂直の角度、0.01 度単位：RJBB の ILS06LY は BOLAL（FAF）と RW06L に −3.00）。
- 角度の付く脚：ある点の記録の角度は、その点で終わる脚のもの（FCOM p.1405 の図：滑走路 RW32R の角度が RW32R へ入る脚の行に出る）。
- 作ったもの：
  - 予測：降下の経路を E/D から後ろへ組むとき、GP の角度のある脚では、その脚の終わりの点（そこまでの経路の高度）から、地面に対してその角度の直線で後ろへ上がる（`descent_path` の `gps`）。脚の始まりの点に、直線より低い AT・AT OR BELOW・窓の上限があれば、直線がその高度に着いた所から始まりの点まで水平にする（FCOM p.1262 の「経路に乗るまで水平」）。その脚では減速しない。直線に推力が要れば A/T は SPD（"spd"）、要らなければ "idle"。
  - FMS：予測の入力の脚に CIFP の角度（`gp`、下りの度）を渡す。
  - CDU：LEGS の見出しの行の右（24 桁目まで）に「GP  3.00`」（FCOM p.1405）。
  - 誘導（VNAV のモデル）は変えない：経路の下では上がらず水平で待つ（`K_PATH` と「上がらない」：段 9b）ので、経路に乗るまで水平になる。
- 推定：直線の終わりの点の高度は、それより後の脚が作る経路の高度とした（終わりの点の制限がそれより上でも直線を優先。データが整っていれば一致する。試験の ZZAA の I16R は FAF の 3,000 A と 3 度の線が合わないので、予測の FAF は 1,190 ft）。始まりの点の制限が直線より上（AT OR ABOVE など）のときも直線を優先した（資料に無い）。GP の脚の速さは降下の予定の速さとした。
- 試験：`pred_model_test.lua` 61 件（二つの 3 度の脚は一本の線で、FAF の 4,000 A の上、IF もその線の上、その前はアイドルの経路。IF の AT 5,000 が線より下なら、IF から線に着くまで 5,000 ft の水平（A/T の SPD）、その先は線）、`pred_glue_test.lua` 173 件（ZZAA の I16R の FAF と滑走路の脚に GP 3.00、予測の FAF は滑走路からの 3 度の線の上、LEGS の FAF と滑走路の行の見出しに「GP  3.00`」）。全 134 本。新設の X-Plane の `s151_vnav_gp_angle`：20/20（21:16〜21:24、起動し直した後の 3 回目の読み直し）。LEGS の BOLAL へ入る脚の見出しは「059` 5NM GP 3.00`」、RW06L へは「059` 12NM GP 3.00`」。BOLAL の先の最終進入（2,868 ft）は VNAV PTH で経路から 6 ft、FMC の V/S −1,396 fpm・実際 −1,413 fpm（対地速度 262 kt の 3 度の分 1,390 fpm）、MCP の 1,000 ft で VNAV ALT。Log.txt に Lua の誤りなし

## 73. 段 9g の段取りと 9g1 の実装（2026-10-31：推力制限のモード）

- 資料：FCOM p.641–642（THR スイッチ：離陸の後は VNAV か FLCH のとき待機中の上昇の制限に、エンジン不作動なら CON。着陸復行の後は CLB、エンジン不作動か CON を選んでいれば CON。着陸フラップか G/S の間は GA のまま。400 ft から着陸まで）、p.646（FLCH で上の高度：CRZ なら CLB、エンジン不作動なら CON）、p.667（離陸：CLB へ変わる前の TO/GA は離陸の derate を外す。thrust reduction の点（高度かフラップ 5）で待機中の上昇の制限に）、p.672（フラップを UP から出す、着陸の位置にする、G/S を捕捉する、で GA。着陸フラップと G/S の間は GA に固定）、p.1271–1273（推力制限の種類、VNAV のときは段階で変わる、derate、assumed temp、CLB 1/2、離陸の減らし方による上昇の自動選択）、p.1313–1316・p.1338–1340（THRUST LIM）、ATA34_2 p.535–536（地上は TO が自動、待機中の上昇は thrust reduction の高さで、400 ft より上なら THR でも。GA は進入中に自動。CRZ は PERF FACTORS の設定で、VNAV の T/C で自動）、p.539（THR REDUCTION）、p.642（最大推力と推力制限の 2 つ）、FMSPG p.105・p.111（VNAV と A/T が engage なら自動、無ければ THR ボタン、エンジン故障なら CON）。意図した動きの表は notes/ATA-22-AT.md §4.5・§4.6。
- 前：推力制限のモードは EEC が AP の flightPhase（0 で TO 系、1 で CLB 系、2 以上で CRZ、G/A の autoland −2 で GA）から作り、flightPhase は多くの操作が書いた（ATHR-01）。THR REDUCTION は保存されるだけ。CON と D-TO は無い。値（ATHR-03〜05）、THRUST LIM のページ（ATHR-02）、EICAS（ATHR-17）も実機と違う。
- 段取り：
  - 9g1：推力制限のモード（この段）。
  - 9g2：THRUST LIM のページ（地上と空中：見出しのモードと値、<SEL>・<ARM>、空中の <GA・<CON・<CRZ、derate の %：ATHR-02）。
  - 9g3：reference の値（PI の表の最大上昇・GA・最大連続、TO の定格と derate、assumed temp の D-TO と最大 25 %、109 の CLB 1/2 の戻し方、CRZ：ATHR-03〜05）。D-TO のモードと、その減らし方による上昇の自動選択も。
  - 9g4：EICAS（reference の数字、「D-TO 1 +38C」の assumed temp、紫の target：ATHR-17）。
  - エンジン不作動の CON（VNAV・フラップ UP・VREF+98、THR、FLCH）は段 9h。
- 9g1 で作ったもの：
  - `B747.68.thrlim_model.lua`（純粋、`B747_thrlim_model`）。地上は TO（THRUST LIM の TO・TO 1・TO 2）。上昇の制限は離陸の減らし方で待機（5 % 未満 CLB、15 % 未満 CLB 1、それ以上 CLB 2。地上で乗員が選べばそれ）。空中では、VNAV で THR REDUCTION（フラップ 5 か空港からの高さ）に来るか、400 ft RA より上で VNAV か FLCH のときの THR スイッチで、待機中の上昇へ。その前の TO/GA は離陸の derate を外す。VNAV の段階が変わったときと VNAV の engage のとき、段階の CLB か CRZ（T/C の CRZ は整備の設定：CRZ とした）。FLCH で上へなら CRZ から CLB。空中でフラップを UP から出す、着陸フラップ、G/S で GA（着陸フラップと G/S の間は固定）。GA から THR スイッチで CLB（CON を選んでいれば CON）、VNAV の段階。空中の THRUST LIM の CLB・CLB 1・CLB 2 の選択（GA・CON・CRZ の選択の関数も用意し、ページは段 9g2）。
  - FMS：毎フレーム、モデルの文字を `laminar/B747/engines/ref_thr_limit_mode` に、離陸と上昇の rating を `laminar/B747/engine/derate/TO`・`CLB`（EEC の値が読む）に書く。THRUST LIM の TO・CLB のキーはモデルの選択を呼ぶ（前は TO n が両方の derate を書いた）。離陸の derate の % は FCOM p.1314 の例（P&W と RR は TO 1 8・TO 2 20、GE は 5・15：運航者の設定）。
  - AP：THR スイッチの押しを数える `laminar/B747/autopilot/thr_pushes`（init にも）。EEC：`ecc_mode_set`（flightPhase からのモード）を外した。
- 推定：空中開始（離陸を経ない）は CLB から。T/C の CRZ（整備の設定）。FLCH の上昇は「FLCH で MCP 高度が機体より上」。VNAV の段階は変わったとき（と engage のとき）だけ見る（乗員の選択は次の変化まで残る）。FMSPG p.105 の「A/T も engage」の条件は使っていない（FCOM p.667 に無い）。
- 試験：`thrlim_model_test.lua` 36 件（地上の選択と上昇の自動選択、乗員の上書き。フラップ 5 と VNAV、1,500 ft の高さ、VNAV なしは TO のまま、THR は FLCH で 400 ft より上、TO/GA で derate が外れる。T/C の CRZ、cruise climb の CLB、FLCH の上昇、CON と CLB 2 の選択。空中開始の CLB、フラップ 1 の GA、THR で CLB、着陸フラップと G/S で固定、フラップ 20 の THR で CLB・CON を選んでいれば CON。進入の GA は VNAV の engage でも、FMC の上昇の段階の VNAV で CLB）、`takeoff_ref_test.lua` 44 件（CDU の TO 1 で「TO 1」と CLB 1 の待機、空中のフラップ 20 の VNAV で TO 1、フラップ 5 で CLB 1、UP から 1 で GA、THR で CLB 1、地上で TO 1）、`fmc_fixes_test.lua` 41 件（TO 1 をモデルで）。全 135 本。シナリオ：s79 は空中開始の CLB を見る形に、s141 に推力制限の確認を足した。X-Plane：起動し直した後の 4〜6 回目の読み直し（21:52〜22:03）で、s141 40/40（RJAA 34L の VNAV の離陸：VNAV の engage の後も TO、フラップ 5 にして 0.6 秒で CLB、フラップ UP でも CLB）、s79 31/31（空中開始の CLB が、空中の <GA（INOP）の後も CLB）、s142 31/31（A/T の離陸：TO）。Log.txt に Lua の誤りなし

## 74. 段 9g2 の実装（2026-10-31：THRUST LIM のページ）

- 資料：FCOM p.1313–1316（地上の THRUST LIM：SEL と OAT、見出しの右にモード（D- は assumed temp）と制限の値、<TO、TO 1・TO 2 の derate の %、<SEL>・<ARM>、CLB・CLB 1・CLB 2、INDEX、TAKEOFF）、p.1338–1340（空中：有効なモードと値、<GA・<CON・<CRZ、CLB・CLB 1・CLB 2、<SEL>、INDEX、APPROACH）、ATA34_2 p.535–536（地上か TO のモードのあいだは地上の形。CLB の選択は TO のあいだは待機）。
- 前：見出しは「TO-1」の形で D も出ず、値は A/T の target の印（降下では 0.90）。空中はモードも値も無く OAT だけ。<GA・<CON・<CRZ は離陸の TO 系のキーにつながり、段 1 から KEY/FUNCTION INOP（ATHR-02、CDU-10）。TO 1・TO 2 は「10%」「20%」の固定の表示。
- 作ったもの：
  - 地上か、離陸の制限（TO のモード）のあいだ：SEL（大きい字）、見出しの行の「SEL  OAT」と右に「TO 1 EPR」（GE は N1）、その下に OAT と制限の値（小さい字：段 3b のまま）。行は「<TO   <SEL> <ARM>   CLB>」「<-8 % <SEL> <ARM> CLB 1>」の形（FCOM p.1314：小さい字の見出し TO 1・TO 2 の下に derate の %、`B747_fms_thrlim_pct`）。<SEL> は選んだ離陸の rating、<ARM> は待機中の上昇。キーは L1 SEL、L2〜L4 TO・TO 1・TO 2（空中は INOP：CDU-10）、R2〜R4 CLB・CLB 1・CLB 2、R6 TAKEOFF。
  - 空中でそれより後：見出しの右に有効なモードと「EPR」、その下に値。行は「<GA  …  CLB>」「<CON  … CLB 1>」「<CRZ  … CLB 2>」で、<SEL> は有効なものに。キーは L2〜L4 GA・CON・CRZ（段 9g1 のモデルの選択：GA の固定の間は何もしない）、R2〜R4 CLB 系、R6 APPROACH。
  - 値は EEC の reference（`laminar/B747/engines/display_EPR_ref`・`display_N1_ref` の 1 番：FMC のモードの制限の値）。前の target の印ではない。
  - モデル：TO のモードのあいだの CLB 系の選択は待機（ATA34_2 p.536。段 9g1 では空中なら有効にしていた）。
- 推定：OAT と値の字の大きさ（段 3b の小さい字のまま）。TO 2 を選んだときの「<-20 %<SEL>」の詰まり（幅 24 字に収めた）。
- 試験：`takeoff_ref_test.lua` 51 件（地上の見出しの「TO 1 EPR」、「<-8 % <SEL> <ARM> CLB 1>」と見出し TO 1・TO 2、空中の「CLB 1 EPR」と「<CON        <SEL> CLB 1>」、<CON・<CRZ で選び、CLB 1> で戻る）、`thrlim_model_test.lua` 37 件（TO のあいだの CLB 2 は待機し、フラップ 5 で CLB 2）、`fmc_fixes_test.lua` 41 件（空中の <GA で GA）。全 135 本。シナリオ：s79 は空中の <GA で GA・CLB> で CLB、s141 に地上と空中の THRUST LIM の確認を足した。X-Plane：起動し直した後（22:10）の s128（捨て）に続いて、s141 46/46（地上の THRUST LIM は見出し「SEL OAT TO EPR」、OAT と値「15`C 1.52」、「<TO   <SEL> <ARM>   CLB>」、見出し TO 1 の下の「<-8 %」。フラップ 5 の CLB の後は空中の形「CLB EPR」と「<GA         <SEL>   CLB>」）、s79 32/32（空中の <GA で GA「<GA   <SEL>」、CLB> で CLB）。Log.txt に Lua の誤りなし

## 75. 段 9g3 の実装（2026-10-31：reference の値）

- 資料：FCOM p.1271–1273（推力制限の種類、TO 1・TO 2 は運航者の %、assumed temp は最大 25 %、CLB 1/2 は 109 で 10,000 ft まで 10・20 %、30,000・35,000 ft で CLB に。405・570 は 15,000 ft）、p.1314（TO 1 −8 %・TO 2 −20 % の例：109・405。570 は −5・−15 %）、PI.10.36–10.37（PW4056 の最大上昇と GA の EPR の表）、PI.20.31–20.32（CF6 の %N1）、ATA34_2 p.642（reference はモードの値、最大は derate で下げない）、p.651（SEL は TAT より高いときだけ使う）。
- 前：EEC の型式ごとの分岐で、TO は古い 3 次式（離陸後は固定）、CLB は固定の上昇率に要る推力（初期上昇・最大上昇の式で頭打ち）、CRZ は M.85 の巡航の表（引き方も誤り）、GA は近似式、CON と D-TO は前の値のまま（ATHR-03・04）。TO 1/2 は推力 ×0.9・0.8（10・20 %）、CLB 1/2 は要る推力 ×0.9・0.8 で全型式 10,000→15,000 ft で戻した（ATHR-05）。SEL は使っていなかった（コメントアウト）。
- 作ったもの：
  - `B747.42.ref_thrust_model.lua`（純粋、`B747_ref_thrust_model`、EEC の表を使うので EEC のフォルダに）：TO 系は離陸の定格（GA の表：EEC の最大と同じ）、TO 1・TO 2 はその推力の derate の % 減（EPR のモデルで推力から EPR に）、D- は SEL での定格（GA の表を TAT＝SEL で引く：TAT より高いときだけ）で、derate した推力から最大 25 % 減まで。CLB は最大上昇の表、CLB 1・CLB 2 は 10・20 % 減を 10,000 ft まで、そこから 109（P&W・RR）は 30,000・35,000 ft、570（GE）は 15,000 ft で 0 に。GA は GA の表（10,000 ft より上はそこで止める）。CRZ と CON は最大上昇の表（推定）。抽気の補正は EEC の最大と同じ。離陸の推力の減り方（%）も返す。
  - EEC：`M.rating`（表と抽気の補正）。つなぎ（`B747.42.xt.eec_thrust.lua`）の `B747_eec_reference(engine)` が、EEC の入力（気圧高度、TAT、Mach、パック、防氷）と FMS のモード・derate の %・SEL でモデルを回し、離陸の減り方を `laminar/B747/engines/to_reduction` に書く。PW・GE のファイルは、A/T の target の印と EICAS の reference（`display_EPR_ref`・`display_N1_ref`）をこの値に（前の分岐の値は使わない）。RR は資料が無いので前のまま。
  - FMS：SEL（`laminar/B747/fms/thrlim/sel`、°C、無ければ −99）と離陸の derate の %（`fms/thrlim/to_pct`）を書く。SEL が OAT より高ければ TO に D-（FCOM p.1314：「D-TO 1」）。上昇へ変わる前の TO/GA は SEL も外す。地上の上昇の自動選択は、derate の % と EEC の減り方（SEL の分を含む）の大きい方で。
- 推定：CRZ と CON の値（FCOM に最大巡航の表が無い。最大連続の表は段 9h）。GE の derate（N1 × 推力の比の 1/3 乗）。D- の条件（SEL が OAT より高い：FCOM の言い方）。SEL での定格は GA の表を TAT＝SEL で引く（表の一番暑い行で止まるので、海面では最大 21 % 減）。25 % を超える SEL を 25 % の温度に書き換えること（FCOM p.1314）は作っていない。
- 残り：EICAS（段 9g4：降下で 0.90・25 にする target の印、「D-TO 1 +38C」の assumed temp、紫）、TO/GA の後の SEL の入力の禁止、最大連続の表（段 9h）。
- 試験：`ref_thrust_model_test.lua` 24 件（新設：TO は GA の表、パック 3 つ止めで +0.02、TO 1・TO 2 は推力 8・20 % 減、D-TO は SEL 50 で表の値、SEL 99 は表の一番暑い行、上限を 10 % にすると 10 % で止まる、SEL が TAT より低ければ TO、D-TO 1 は TO 1 の推力から、CLB は表、CLB 1・2 は 5,000 ft で 10・20 % 減、20,000 ft で 5・12 % 減、30,000 ft で CLB、GE の CLB 1 は 20,000 ft で CLB、GA は表で 10,000 ft より上は止める、CRZ・CON は CLB、GE の TO 1 は N1 × 0.95 の 1/3 乗）、`eec_module_test.lua` 72 件（地上の TO の reference と target の印が 1.51、30,000 ft の CLB が 1.57、CLB 2 は少し下）、`takeoff_ref_test.lua` 55 件（SEL 26 で D-TO、見出しの D-TO EPR、EEC への SEL、消すと TO と −99）、`thrlim_model_test.lua` 42 件（D-TO 1、減り方 27 % で CLB 2、TO/GA で TO）。全 136 本。X-Plane：起動し直した後の 4・5 回目の読み直し（22:43〜22:52）で、s141 46/46（RJAA の地上の THRUST LIM の値は 1.51：GA の表の TO。フラップ 5 の CLB の後、2,551 ft・TAT 17°C で reference と target の印が 1.551：最大上昇の表（訂正：GA の表の値だった。EEC が FMS のモードの文字を読めていなかった：§76）、A/T がそこへ上げて毎分 3,600 ft、9,000 ft の捕捉の行き過ぎは許容の内）、s142 31/31（A/T の離陸：TO、HOLD で EPR 1.47）。Log.txt に Lua の誤りなし

## 76. 段 9g4 の実装（2026-10-31：EICAS の推力の表示）

- 資料：ATA34_2 p.651–652・LH3460 p.96（EICAS の推力の表示：推力制限は数字と緑のカーソル。target のカーソルは VNAV の上昇で紫、VNAV のほかの段階で緑、VNAV のアイドルの降下で防氷のとき紫、A/T ARM が OFF のとき紫（手の推力の目安）。SEL で TO の制限が下がればモードの前に D）、FCOM p.831（「TAT +15C D-TO 1 +38C」：モードと assumed temp）、p.834（reference の数字と緑の印、FMC の target は紫）。
- 前（ATHR-17）：数字は target の印で、降下の THR REF・IDLE では 0.90（GE は 25）にした。紫は A/T が THR REF で巡航の前のときだけ、パネルも FMA の THR REF を条件にしていたので、紫の旗が立って THR REF でないときはカーソルがどちらも出なかった。assumed temp の表示は無い。
- 作ったもの：
  - target の印（A/T の THR REF の目標、EICAS の数字、CDU の THRUST LIM の値）はいつも推力制限の値（降下の 0.90・25 を外した：A/T の SPD・THR は印で頭打ちにするので、0.90 だと降下で抑えられた）。
  - 紫の旗（`display_ref_line_magenta`）は EEC のつなぎの `B747_eec_cursor` が ATA34_2 p.652 の規則で：VNAV の上昇、VNAV のアイドルの降下で防氷（どれかのナセルか翼）、A/T ARM が OFF。カーソル（`display_EPR_ref`・`display_N1_ref`）は、アイドルの降下で防氷のときはアイドルの EPR・N1（推定：FMC の target）、ほかは推力制限。
  - FMS：EICAS の行の文字 `laminar/B747/fms/thrlim/eicas`（モードと、D- のときは SEL の「+50C」）。
  - EEC へのモードの受け渡し（訂正）：FMS（xtlua_keysystems のプラグイン）が書く文字の dataref（`ref_thr_limit_mode`）は、EEC（xtlua のプラグイン）からは見えなかった（数の dataref は見える）。初めの s152 では D-TO が EEC では TO のままで、reference が下がらなかった。段 9g1 から X-Plane の EEC は空のモードを見ていて、reference は TO の値のまま（上昇でも A/T の THR REF の目標が TO の推力）。段 9g3 の s141 の CLB の後の 1.551 は、最大上昇の表の値ではなく GA の表の値だった（同じ所の最大上昇は 1.276）。FMS がモードを数の符号 `laminar/B747/fms/thrlim/code`（10 × TO 1・CLB 2・CRZ 3・CON 4・GA 5 ＋ rating、D- で ＋100）にも書き、EEC のつなぎ（`B747_eec_thrlim_mode`）が文字に戻してモデルに渡し、EEC の側の文字の dataref もそろえる（RR の分岐も読む）。パネルとほかのモジュール（xtlua_keysystems）は FMS の文字を読める（s152 の写真の「D-TO 1 +50C」）。
  - カスタム acf のパネル（ACF_DIFF.md §5）：紫のカーソル 12 個の「FMA が THR REF」の条件を外した（紫の旗だけで緑と切り替え）。モードの文字の部品の DATAREF を `fms/thrlim/eicas` に。バックアップ `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261031_before_thrust_display`、書き換えは `docs/overhaul/tools/panel_thrust_ref.lua`。
- 推定：アイドルの降下の紫のカーソルの位置（アイドルの端）。A/T OFF の紫のカーソルの位置（推力制限：FMC が手の推力に出す target の作り方は資料に無い）。
- 試験：`eec_module_test.lua` 79 件（モードの符号 22 で EEC の CLB 2、A/T ARM が OFF で紫、ARM で VNAV なしは緑、VNAV の上昇で紫、アイドルの降下は防氷なしで緑・ありで紫でカーソルはアイドル、印は reference のまま、降下の THR REF でも印は reference）、`takeoff_ref_test.lua` 59 件（EICAS の行の D-TO +26C と TO、符号 110 と 11）。全 136 本。新設の X-Plane の `s152_eicas_thrust_ref` と、s141 に VNAV の上昇の紫：起動し直した後（23:02）の s128（捨て）に続き、初めの s152 は 12 件中 11 件（D-TO でも reference が TO の 1.51：EEC が FMS のモードの文字を読めていなかった。上の訂正）、s141 47/47（VNAV の上昇でカーソルが紫）。数の符号で渡した後（23:19〜23:27）は s152 12/12（SEL 50 の D-TO：reference 1.41、減り方 16.6 %、最大の線は 1.513 のまま、THRUST LIM は「D-TO EPR」と 1.41、A/T ARM OFF で紫・ARM で緑、TO 1 で「D-TO 1 +50C」、SEL を消すと「TO 1」で 8 % 推力の分低い。写真で EICAS の「TAT +15c D-TO +50C」、数字 1.41、紫のカーソルとその上の琥珀の最大の線）、s141 47/47（フラップ 5 の CLB の後の reference は 1.276：最大上昇の表、最大の線 1.552 とは別）。Log.txt に Lua の誤りなし

## 77. 段 9h の段取りと 9h1 の実装（2026-10-31：最大連続の表）

- 段 9h（E/O の VNAV と RTA：FMC-26・27）の資料：FCOM p.1265–1269（離陸と上昇の E/O：V2+10、E/O の加速高度かフラップ上げで VREF+100、VREF+98 で CON、ENG OUT> で E/O CLB、E/O MAX ALT の上は driftdown、E/O CRZ と CRZ DES、RTA は E/O では使えない）、p.1272（VNAV・エンジン故障・フラップ上げで VREF+98 で CON、推力の切り替え点は禁止）、p.1341–1342（E/O CLB のページ）、p.1350–1353（CRZ の ENG OUT>、E/O CRZ のページと題、2E/O）、p.1354、p.1383–1385（RTA）、FMSPG p.3.3-2〜3.3-7・3.4-1〜3.4-5・3.4-19・3.4-52〜3.4-55、PI.13・14（PW）・PI.23・24（GE）、PI.18.8–18.9（本文：表の最大高度から 1,000 ft（2 発停止は 2,000 ft）引いた値は FMC の論理と同じ）、ATA70_80 p.208–209（CF6 の全開の定格）。エンジン故障の検知の条件は FMC の資料に無い（ENG FAIL の条件 N2 52 % を使う：推定、段 9h3）。
- 小分け：

| 段 | 内容 | GAP |
|---|---|---|
| 9h1 | 最大連続の表：CON の reference の値、EEC の全開の最大連続の帯 | ATHR-03 の残り |
| 9h2 | E/O の性能のデータ（PI の表：driftdown の速さと level off の高度、LRC の高度の能力、LRC の Mach・KIAS・EPR/N1・燃料流量。1 発・2 発停止） | FMC-26 |
| 9h3 | エンジン故障の検知と離陸の E/O（V2+10、E/O ACCEL HT かフラップ上げで VREF+100、VREF+98 で CON、CLB のページの題） | FMC-26 |
| 9h4 | E/O の CLB・CRZ のページと誘導（ENG OUT> の MOD、ALL ENG>、E/O SPD、E/O MAX ALT、CRZ ALT を下げる、CON、driftdown、E/O CRZ と CRZ DES、PROGRESS の LEVEL AT、2E/O） | FMC-26 |
| 9h5 | RTA（109） | FMC-27 |

- 9h1 の資料：PI.13.1–13.2（PW4056 の最大連続の EPR、1 発停止・パック 3 つ：高度ごとに KIAS 5 列と Mach 5 列の EPR・MAX TAT・EPR CORR、MAX TAT を 10 °C 超えるごとに EPR CORR を引く、抽気の補正）、PI.23.1–23.3（CF6 の %N1：5,000〜39,000 ft の高度ごとに KIAS の行と TAT の列）、PI.18.8（最大連続は主に非常用で、続けて使える最大）、ATA70_80 p.208–209（CF6 の全開の定格：18,000〜22,000 ft か 293 kt を超えると最大連続、25,000 ft より上はレバー 35° を越えて最大上昇。図では CLIMB の位置から全開までが最大連続〜最大上昇の移り変わり）。
- 前：CON の reference は最大上昇の表（段 9g3 の推定）。EEC の全開の最大連続の帯も最大上昇の表（推定）で、E/O で CON にしても A/T がそこまで出せなかった（20,000 ft・280 KIAS で最大連続 1.51 に対し 1.43）。
- 作ったもの：
  - EEC のモデル（`B747.42.eec_model.lua`）：最大連続の表（`TABLE.PW.mct`・`TABLE.GE.mct`）と引き方 `M.lookup_mct`・`M.rating_mct`。P&W は高度ごとに KIAS の列と Mach の列（その高度の CAS に直す）を速さの順に並べ、各セルの EPR から MAX TAT を超えた分の補正を引いて速さで補間し、高度で補間。GE は KIAS の行ごとに TAT で補間して KIAS で補間。表の外は端の値（GE は 5,000 ft より下も 5,000 ft の値：推定）。抽気：P&W はパック 1 つ・2 つ止め（3 つ止めは 2 つの値：推定）と防氷、GE は「PACKS OFF」を 3 つとも止めたときに（推定）と防氷。
  - CON の reference（`B747.42.ref_thrust_model.lua`）：最大連続の表をそのときの KIAS で（1 発停止の表を全発でも：推定）。つなぎ（`B747_eec_reference`）が KIAS を渡す。CRZ は最大上昇の表のまま（推定）。
  - EEC の全開の定格：最大連続の帯（22,000 ft まで、25,000 ft で 0 へ。293 kt を超えた所も）を最大連続の表の値に（最大上昇の表より下にはしない：推定。表は 1 発停止で 1 発あたりの抽気が多い）。25,000 ft より上は最大上昇のまま（ATA70_80 p.208–209）。
- 推定：全発の CON にも 1 発停止の表、GE の 5,000 ft より下、パックの補正の当てはめ方、帯で最大上昇の表を下限にすること。
- 残り：25,000 ft より上では EEC の全開が最大上昇の表（340 KIAS・M.84 の値で速さの影響なし）なので、遅い速さの CON（最大連続の表の方が高い）に届かないことがある（高い所の driftdown：段 9h4 で見る）。
- 試験：`eec_model_test.lua` 151 件（PW の表：25,000 ft・300 KIAS・TAT 0 で 1.53、MAX TAT を 10 °C 超えて 1.44、高度の間 1.545、速さの間 1.512、M.85 の列、海面。GE の表：35,000 ft・240 KIAS・TAT −30 で 104.7、KIAS の間、寒い端、5,000 ft の下。抽気：防氷 −0.035、パック 1 つ止め +0.01、3 つ +0.02、GE のパック止め +0.5、1 つは 0、防氷と翼の防氷 −2.1。全開の定格：GE の 17,500 ft は TO と最大連続の半分、23,500 ft は最大連続と最大上昇の半分、26,000 ft は最大上昇、PW の 20,000 ft・280 KIAS は最大連続の 1.512、360 KIAS は最大上昇（最大連続の方が低い））、`ref_thrust_model_test.lua` 29 件（CON は 25,000 ft・300 KIAS で 1.53、250 KIAS・TAT −5 で 1.62、TAT 0 で 1.611、防氷 1.495、パック 1 つ止め 1.54、GE は 103.85）、`eec_module_test.lua` 79 件。全 136 本。新設の X-Plane の `s153_eicas_con_ref`：17/17（起動し直した後の 6 回目の読み直し、23:50。成田の近くの空中 17,000 ft から VNAV の上昇と速度介入 250 kt、18,738 ft・250 KIAS・TAT −7.7 °C で CLB の reference 1.420・EPR 1.419。<CON で FMS の符号 40、EEC のモードと EICAS の行は CON、reference 1.552（表で約 1.55）、EEC の全開の最大も 1.552（前の作りでは CLB の値で頭打ち）、A/T THR REF で EPR 1.545・毎分 3,270 ft。CLB> で符号 20 に戻る。EICAS の写真で CON、緑の 1.55、紫のカーソル。N1 の読みの枠が赤かったのは超過の記憶（今の赤は 0、記録の N1 は赤線 111.4 % より十分下：記録の前の空中開始のときとみて、次の起動で確かめる）。Log.txt に Lua の誤りなし）

## 78. 段 9h2 の実装（2026-11-01：E/O の性能のデータ）

- 資料：PI.13.3–13.4（PW4056、1 発停止・最大連続推力：driftdown の速さと level off の高度、LRC の高度の能力、LRC の EPR・Mach・KIAS・燃料流量）、PI.14.1・14.3–14.4（2 発停止）、PI.23.4–23.5・PI.24.1–24.3（CF6、lb）、PI.18.8–18.9（本文：level off の高度と LRC の高度の能力は最大高度から 1,000 ft（2 発停止は 2,000 ft）引いた値で、FMC の論理と同じ。LRC の高度の能力は LRC の速さと最大連続推力で保てる最大高度）、FCOM p.1342（E/O CLB の MAX ALT は E/O の上昇の速さと巡航の速さでの最大高度の低い方）、p.1352–1353（E/O の題：E/O は最小抗力の速さ、E/O LRC。MAX は全発と同じ基準）、ATA34_2 p.610（VNAV の速さに engine out long range cruise と engine out minimum drag）。
- 作ったもの（`B747.68.perf_db.lua`。まだどこからも使わない：段 9h3・9h4 で使う）：
  - 表：`PW.EO`・`GE.EO` の [1]（1 発停止）と [2]（2 発停止）に DD（driftdown）、CAP（LRC の高度の能力）、AI（防氷の補正：PW 1,800・3,500 ft、GE 1,300・2,400 ft。2 発停止は表に無いので 1 発停止の値：推定）、DCD（下）、LRC（LRC の制御）。
  - `P.eo_max_alt(t, n, kg, isa, ai)`：LRC での最大高度（CAP）と driftdown の速さでの最大高度（DD の level off の高度を level off の重さで引く）。ISA+10 以下・+15・+20 の間は補間、+20 の先はその値（推定）、表の空欄（GE の 2 発停止 900,000 lb の ISA+20）は 0。3 発以上の停止は 2 発の表。表の重さの外は端の値（推定）。
  - `P.eo_min_drag(t, n, kg)`：E/O の最小抗力の速さ（KIAS）＝表の最適 driftdown の速さを driftdown の始めの重さで（推定：FMC の engine out minimum drag をこの速さとした）。
  - `P.eo_lrc(t, n, kg, ft)`：E/O LRC の Mach・KIAS・運転中の 1 発あたりの燃料流量・EPR/N1（表。表の外は `P.lrc` と同じく端の値）。
  - `P.eo_drag`：止まったエンジンの風車と trim の抗力を、抗力係数の増し分 DCD（PW 0.00136・0.00156、GE 0.00059・0.00062）として足す（推定：E/O LRC の表の燃料流量に平均で合わせた。新設の `tests/tools/eo_drag_fit.lua`）。
  - `P.eo_cruise_ff`・`P.eo_level_setting`：E/O の水平飛行の 1 発あたりの燃料流量と推力の設定は、その重さと高度の E/O LRC の表の値に、モデルでその Mach までの変わり方を掛け（足し）たもの（推定）。全発の表で合わせたモデルだけでは、E/O の 1 発あたりの推力の高い所で燃料流量が 10,000 ft で 5〜9 % 多く、上限の近くで最大 10 % 少なく、EPR は最大 0.14 低いため。
- 試験：`perf_db_test.lua` 115 件（PW 1 発停止 300 t・ISA の LRC の高度 32,000 ft、driftdown の level off 32,626 ft（level off の重さ 313・294 t の間）、ISA+12.5 は 31,950、ISA+25 は ISA+20 の値、防氷 −1,800・−3,500、395 t は間、180 t は 200 t の値。2 発停止 300 t は 16,500・19,400 ft、3 発停止は 2 発の表。GE 600,000 lb は 35,000 ft、防氷 −1,300、2 発停止 900,000 lb・ISA+17.5 は 1,150 ft。最小抗力の速さ 267・263・259・255 kt。E/O LRC は表の値、間の補間、400 t の 25,000 ft は 20,000 ft の値、2 発停止、GE の lb。抗力の増し分、燃料流量と EPR/N1 は E/O LRC で表の値、速いと多い）。全 136 本。X-Plane：s128_fmc_perf_db 5/5（X-Plane を起動し直した後の 1 回目、0:07：表を足した perf_db を XTLua が読み込み、PERF と CRZ のページは前どおり）。Log.txt に Lua の誤りなし。あわせて、s153 の写真の N1 の赤い枠（超過の記憶）を確かめた：s128 の空中開始（10,000 ft）の後は付かない。s153 の CON の上昇の間の N1 は表示で 103 %（赤線 111.4 %）で、記録の前（17,000 ft の空中開始の直後）に付いたもの

## 79. 段 9h3a の実装（2026-11-01：エンジン故障の検知と推力制限の E/O の規則）

- 段 9h3 を 9h3a（検知、推力制限、A/T）と 9h3b（VNAV と AFDS の離陸の E/O の速さ）に分けた。
- 資料：FCOM p.1266（離陸でエンジン故障を感じたら：減らす点の前は TO のまま、VREF + 98 で CON。減らす点の後の故障は今の上昇推力のまま）、p.1272（VNAV・エンジン故障・フラップ全上げで VREF + 98 で CON、予定の減らす点は禁止）、p.642（THR スイッチ：離陸後に VNAV か FLCH で待機中の上昇、エンジン不作動なら CON。go-around の後は CLB、エンジン不作動か CON の選択なら CON）、p.646（FLCH を高い高度へ：CRZ なら CLB、エンジン不作動なら CON）、p.641（A/T ARM：2 発以上の不作動で切れる）、p.1268（E/O の巡航は CON のまま）、p.899 と ATA70_80 p.230（ENG FAIL：故障か flameout、CF6 は N2 52 %）。FMC・AFDS・A/T がエンジン故障をどう感じるかの値は資料に無い。
- 作ったもの：
  - エンジン（`B747.40.engine_start_model.lua`）：各エンジンの inoperative（N2 が ENG FAIL の 52 % の下：故障、flameout、停止。地上でも：推定）。新しい `laminar/B747/engines/inop`（array[4]、エンジンの init で作る）に書き、FMC・AFDS・A/T が読む。
  - 推力制限（`B747.68.thrlim_model.lua`）：エンジン不作動（FMS の `B747_fms_eng_out`：空中の inop の数）を TO のあいだに感じたら、減らす点（THR REDUCTION）を禁止し、VNAV・フラップ UP・VREF 30 + 98 で CON（VREF は SPD TRANS と同じ VREF 30：推定）、THR スイッチ（VNAV か FLCH）で CON。減らす点の後の故障は CLB のまま。GA の後の THR スイッチは CON。FLCH を高い高度へ押したら CON（押した時だけ：その後の乗員の選択は保つ：推定）。VNAV の段階の変わり目でも CON を保つ（推定：p.1268）。
  - A/T（`B747.70.xt.autopilot.lua`）：interlock の 3 発運転を inop から数える（前は N1 15 % 超で、風車の N1 で数えることがある）。2 発以上の不作動で切れて >AUTOTHROT DISC（FCOM p.641）。
- 推定：上のとおり。
- 試験：`thrlim_model_test.lua` 57 件（TO で故障：TO、フラップ 5 の減らす点で VNAV でも TO、フラップ UP で VREF + 97 は TO・+98 で CON、VNAV の CRZ でも CON、VNAV なしのフラップ 10 の VREF + 110 は TO、THR スイッチ（FLCH）で CON。減らす点の後の故障は CLB のまま、FLCH を押すと CON、その後の乗員の CLB は保つ、押し直すと CON、全発では CRZ から CLB のまま。GA の後の THR スイッチは CON）、`engine_start_model_test.lua` 80 件（52 % の下で inop、80 % で inop でない、地上の 20 % でも inop で ENG FAIL は出ない）、`engine_start_module_test.lua` 30 件（始動前は inop、アイドルで inop でない）、`afds_glue_test.lua` 258 件（inop が 1 発では A/T はそのまま、2 発（N1 は 90 % のまま）で切れて >AUTOTHROT DISC、戻すと SPD）。全 136 本。新設の X-Plane の `s154_eo_takeoff_thrlim`：42/42（起動し直した後の 2 回目、0:21。RJAA 34L のフラップ 20 の離陸、V2 153、VNAV の engage の後の電波高度 600 ft で FUEL CONTROL 2 を CUTOFF：約 10 秒で N2 47 % になり inop、A/T は THR REF のまま。推力制限はフラップ 5 でも TO（減らす点の禁止）。フラップ UP の 248.5 kt（VREF 30 150 + 98 の上）で CON、FMS の符号 40、reference 1.351（最大連続の表の 3,100 ft・253 KIAS の値）、3 発で毎分 2,900 ft。EICAS の写真で CON、緑の 1.35、紫のカーソル、エンジン 2 の 0.89、>ENG 2 SHUTDOWN。Log.txt に Lua の誤りなし）

## 80. 段 9h3b の実装（2026-11-01：離陸の E/O の速さ）

- 資料：FCOM p.1265–1266（VNAV：離陸の後にエンジン故障を感じたら V2 + 10。E/O の加速高度かフラップを上げ始めたら VREF + 100 へ、フラップの placard まで、CLB のページは ACT VREF + 100 CLB。図の注：目標がフラップの placard で抑えられるときは LIM SPD CLB）、FMSPG p.3.3-3（題：VREF+100 は離陸でエンジン故障、ENG OUT を選ばず、LIM SPD に抑えられないとき。LIM SPD はフラップの placard などの制限の速さのとき）、p.3.4-19、FCOM p.666（AFDS の T/O：地上の故障は浮いたときの V2 か浮いたときの速さの大きい方。浮いた後は V2 の下なら V2、V2〜V2 + 10 はその速さ、上なら V2 + 10）、ATA22 p.264（同じく、そのときの速さを V2〜V2 + 10 に、MCP が高ければそれ。姿勢と速さの混ぜは 0〜600 fpm）、p.298（G/A：エンジン故障なら混ぜは 0〜600 fpm、最大は MCP + 10）。
- 作ったもの：
  - VNAV のモデル（`B747.68.vnav_model.lua`）：離陸の段階で故障を感じたら V2 + 10。E/O ACCEL HT（TAKEOFF REF の 2L、出発地の標高に足す）かフラップを上げ始めたら VREF 30 + 100 で、その上昇のあいだ（ENG OUT は段 9h4）。離陸の目標もフラップの placard の 5 kt 下で頭打ち。新しい出力 `title`：フラップの placard か最小の速さで目標を抑えたら LIM SPD、ほかは VREF + 100（速度介入のときは無し）。段階が CLB でなくなれば離陸の状態を消す。全発の加速高度の後でも E/O の加速高度の下の故障は E/O の離陸（FCOM p.1266 の条件は E/O の加速高度の下：初めの X-Plane の再試験では、燃料を切ってから感じるまでの 7.5 秒で全発の加速高度を過ぎ、上昇の予定になっていた）。両方の上の故障は上昇の予定のまま。
  - CDU の CLB のページの題（`B747_fms_vnav_title`）：VREF + 100、速度介入の MCP SPD、その上に LIM SPD（全発の離陸のフラップの placard でも出る：前は 250KT など）。
  - AFDS のピッチの則（`B747.70.afds_pitch_model.lua`）：T/O でエンジン故障なら目標をそのときの速さで V2〜V2 + 10（地上の故障は浮いたときの速さ）、MCP が高ければそれ、5 秒の引き上げは無し。G/A は MCP + 10 まで。混ぜは 0〜600 fpm。入力 `eo` はエンジンの inop（段 9h3a）から。試験のため速さの則の目標を新しい `laminar/B747/autopilot/pitch_target`（kt、無ければ 0）に書く。
- 推定：VREF は VREF 30。VREF + 100 の続く間（その上昇のあいだ）。LIM SPD に最小の速さの頭打ちも入れたこと（FMSPG の ALPHA limit）。G/A で途中から故障したときの上限（その時の目標と MCP + 10 の大きい方）。
- 残り：CRZ と DES のページの LIM SPD（VMO・MMO・フラップ）。
- 試験：`vnav_model_test.lua` 160 件（E/O の加速高度が全発より高いとき、間の故障は V2 + 10、E/O の加速高度で VREF + 100 と LIM SPD、両方の上は 250 kt。全発は engage の時の 182 kt、故障で V2 + 10、E/O の加速高度の下は V2 + 10、加速高度でフラップの placard の 5 kt 下の 230 kt と LIM SPD、フラップ UP で VREF + 100 と題 VREF + 100、速度の移り変わりの上でも、エンジンが戻っても VREF + 100、加速高度の前のフラップ上げで VREF + 100、加速の後の故障は 250 kt で題は無し、全発のフラップの placard で LIM SPD）、`afds_pitch_model_test.lua` 128 件（178 kt の故障で V2 + 10、引き上げ無し、MCP が高ければそれ、165 kt で 165、156 kt で V2、地上の故障は浮いたときの 163 kt、700 fpm で全発は姿勢に寄り故障は速さ、G/A は MCP + 10、途中の故障でも MCP + 10）、`afds_glue_test.lua` 259 件（FLCH の目標 200 kt が pitch_target に）。全 136 本。新設の X-Plane の `s155_eo_takeoff_speeds`：38/38（起動し直した後の 5 回目の読み直し、0:46。V2 153 を MCP の窓に、E/O ACCEL HT 1,500 ft、VNAV は arm せずに離陸、電波高度 550 ft で T/O の目標は V2 + 25 の 178。FUEL CONTROL 2 を CUTOFF、7.5 秒で inop（1,276 ft）：T/O の目標は 165.4（V2 + 10 の 163 を速度の保護の最小機動速度 160.4 + 5 が上げた）。VNAV を押すと 1,286 ft で V2 + 10 の 163（全発の加速高度 1,141 ft の後、E/O の 1,641 ft の下）。1,700 ft で VREF + 100 をフラップ 20 の placard の 5 kt 下の 229.9 に抑え、題は ACT LIM SPD CLB。フラップ UP で VREF 30 150.3 + 100 の 250.3、題は ACT VREF + 100 CLB、VREF + 98 で CON、速さ 253 kt。Log.txt に Lua の誤りなし。その前の 2 回は試験の作りの誤り：MCP の窓に V2 を入れず AFDS の V2 が 200 kt、と、燃料を切ってから感じるまでに全発の加速高度を過ぎて上昇の予定になった（モデルを直した））

## 81. 段 9h4a の実装（2026-11-01：E/O のモードと E/O の CLB・CRZ のページ）

- 段 9h4 を 9h4a（E/O のモード、ENG OUT>・ALL ENG> の変更と実行、E/O の CLB・CRZ のページ、CRZ ALT の引き下げ、CON、VNAV の E/O の速さ）と 9h4b（driftdown の則、E/O の予測、PROGRESS の LEVEL AT）に分けた。
- 資料：FCOM p.1266（ENG OUT> を選んで実行すると E/O の性能のデータ、E/O SPD を選べる、実行で E/O の上昇と CON。E/O の最大高度の上では D/D の変更）、p.1268（E/O の巡航は CON のまま）、p.1341–1342（E/O CLB のページ：CRZ ALT は MAX ALT より上なら MAX ALT、E/O SPD は E/O の上昇の速さで XXX か 0.XXX、MAX ALT は E/O の上昇の速さと巡航の速さでの最大高度の低い方で入力できない、ALL ENG>、実行で CON）、p.1350–1353（CRZ の ENG OUT>：E/O CRZ のページ、MAX の上なら CRZ ALT を変える、速さを E/O LRC に、実行で CON。題：E/O（最小抗力）、E/O LIM SPD、E/O MCP SPD、E/O XXXKT、E/O M.XXX、E/O LRC D/D（MAX の上）、E/O LRC、E/O CRZ CLB/DES。2 発目が止まれば 2E/O。LRC SPD・SEL SPD・E/O SPD、<E/O SPD、OPT・MAX、ALL ENG>、LRC>）、FMSPG p.3.3-4（ENG OUT> で巡航高度を E/O の最大高度に下げる）、p.3.3-6（全発運転なら外側の 1 発停止で計算、ALL ENG> で全発）、p.3.4-5（CRZ の ENG OUT>：E/O LRC CRZ・CRZ DES・CRZ CLB・LRC D/D、巡航高度を下げる、E/O LRC の速さ）。
- 作ったもの：
  - `B747.68.eo_model.lua`（新設、純粋）：E/O のモード（実行済み、変更（ENG OUT・ALL ENG）、データのエンジン数、上昇と巡航の速さの選び方）。ENG OUT> で変更（感じたエンジン数、無ければ 1、最大 2）、EXEC で実行、ALL ENG> で全発への変更（実行前の ENG OUT の変更は取り消し）、ERASE で取り消し。実行中に 2 発目が止まれば 2 発のデータ。
  - FMS のつなぎ：E/O の最大高度（防氷の弁で補正）、最適高度（`P.eo_opt_alt`：E/O LRC の表の NM/kg が最大の高度を最大高度まで：推定）、最小抗力の速さ、E/O LRC、E/O の推力の設定。EXEC（`B747_fms_eo_exec`）：ENG OUT なら CRZ ALT を E/O の最大高度（上昇の段階では低い方、ほかは E/O LRC の）に下げ、推力制限を CON。EXEC の灯と、EXEC（`rteexec`）・ERASE（`rteerase`、6L の <ERASE）に E/O の変更を足した（経路の変更とは別の性能の変更）。実行中は VNAV と予測の上昇の速さを E/O の上昇の速さ（最小抗力：推定）か乗員の値（SPD TRANS・SPD REST なし：推定）に、巡航の速さを E/O LRC（高度と重さで）・最小抗力・乗員の値に。推力制限は E/O の実行中も CON を保つ（全発運転でも、TO を除く）。
  - CDU（`B744.fms.pages.vnav.lua`）：全発の CLB・CRZ のページの 5R ENG OUT> が働く（前は表示だけ）。E/O CLB のページ（題 E/O CLB・E/O XXXKT CLB・2E/O、MOD・ACT、1L CRZ ALT は MAX ALT まで、2L E/O SPD、3R TRANS ALT、4R MAX ALT、5R ALL ENG>、6R CLB DIR>）。E/O CRZ のページ（題 E/O LRC CRZ・E/O LRC D/D・E/O CRZ・E/O XXXKT CRZ・E/O CRZ DES など、1L CRZ ALT、1R STEP TO（MAX まで）、2L LRC SPD・E/O SPD・SEL SPD、3L EPR/N1（E/O）、3R ETA/FUEL、4C・4R OPT・MAX（E/O）、5L <E/O SPD、5R ALL ENG>、6R LRC>）。2L の入力は XXX（100〜400 kt）か .XXX（.100〜.990）、DELETE で E/O の上昇の速さか E/O LRC。
- 推定：E/O の上昇の速さを最小抗力の速さに、E/O の最適高度、E/O の上昇で SPD TRANS・SPD REST を使わないこと、上昇の段階の EXEC で CLB のページの MAX ALT（低い方）まで CRZ ALT を下げること、ALL ENG の後の推力制限（次の選択か段階の変わり目まで CON）。
- 残り（段 9h4b）：driftdown の則（CON、E/O LRC、最小 300 fpm）、AT の driftdown の時間と距離、PROGRESS の LEVEL AT、E/O の予測（燃料流量）。段 9h4a では、E/O の最大高度の上で実行すると VNAV は巡航の降下（約 1,250 fpm）として E/O LRC で降りる。
- 試験：`eo_model_test.lua` 21 件（新設：変更と取り消し、全発でも 1 発のデータ、EXEC、MOD のページの速さの選択を保つ、2 発目、ALL ENG の変更と実行、実行前の ENG OUT の変更への ALL ENG）、`eo_pages_test.lua` 34 件（新設：FL350・300 t・ISA で CLB の 5R から MOD E/O CLB、CRZ ALT と MAX ALT は FL320、E/O SPD 267、ラベル、ALL ENG>、<ERASE、EXEC の灯。EXEC で CRZ ALT 32,000 ft と CON、E/O CLB。CRZ のページは E/O LRC D/D、LRC SPD、OPT と MAX、<E/O SPD で 267 と E/O CRZ、280 で E/O 280KT CRZ、.78 で E/O M.780 CRZ、450 は INVALID ENTRY、LRC> で戻る、ALL ENG> の MOD と EXEC で全発、2 発停止で MOD 2E/O と 2 発の MAX、ERASE）、`perf_db_test.lua` 118 件（E/O の最適高度）、`thrlim_model_test.lua` 60 件（E/O の実行中の CON の保持と FLCH、TO では使わない）、`des_forecast_test.lua` 45 件（CLB・CRZ の 5R は ENG OUT> の変更、ERASE で戻る）。全 138 本。新設の X-Plane の `s156_eo_pages`：23/24（起動し直した後の 6 回目の読み直し、1:03。FL350 の巡航・270 t（ZFW 200）・VNAV PTH で CRZ のページの ENG OUT>：MOD E/O LRC D/D、CRZ ALT FL330、LRC SPD .827、OPT FL310・MAX FL331、<E/O SPD・ALL ENG>、<ERASE、EXEC の灯（CDU の写真で FCOM p.1351 の形）。EXEC で CRZ ALT 33,000 ft、CON（符号 40）、ACT E/O LRC D/D、灯は消え、VNAV の目標 M.827、A/T THR。CLB のページは E/O CLB、E/O SPD 262、MAX ALT FL330。ALL ENG> で MOD ECON CRZ DES、EXEC で ACT ECON CRZ DES と ENG OUT>。落ちた 1 件は試験の作りの誤り：MCP FL300 を押してから 20 秒で −200 fpm を求めたが −104 fpm（全発運転のまま E/O を実行したので、前からの巡航の降下の則の A/T の THR が CON から推力をゆっくり下げる途中：s145 は落ち着くまで 180 秒待つ）。待つ形に直し、段 9h4b の driftdown の則で再試験する。空中開始の直後に N1 の超過の記憶が付くこと（s153 の赤い枠）も、この回の開始直後の値で確かめた（推力を変える前）。Log.txt に Lua の誤りなし）

## 82. 段 9h4b の実装（2026-11-01：driftdown、LEVEL AT、E/O の予測）

- 資料：FCOM p.1268（driftdown の実行。条件 1：MCP 高度を E/O の MAX 以下にして実行すると、A/T が運転中のエンジンを CON に進め、VNAV が driftdown と E/O LRC SPD を指令し、E/O の MAX が 1L の CRZ ALT になり、それを捉えて E/O LRC の巡航。降下率は最小 300 fpm に制御、D/D の時間と距離を 2R に。条件 2：先に実行すると MCP 高度で VNAV ALT、CON、E/O LRC SPD。高度のノブを押すと 1L のクリアランス高度へ driftdown、速さが E/O LRC SPD より落ちていれば降下率を増やして取り戻す。条件 3：先に巡航の降下（全発の ECON、約 1,250 fpm、CLB/CRZ）を始め、E/O の MAX の上で実行すると E/O LRC SPD と CON、降下率は最小 300 fpm まで減る）、FCTM p.4.11（VNAV SPD で E/O LRC か E/O SPD を保って降りる、2 発停止では A/T は残らない）、FMSPG p.3.4-2（題の LRC D/D は E/O を選び機体が E/O の MAX ALT の上）、p.3.4-19（PROGRESS の 5R は D/D の誘導中 LEVEL AT）、FCOM p.1353（E/O CRZ の AT：driftdown 中は CRZ ALT に着く時刻と距離）、p.1372（PROGRESS の速さの見出し：EO SPD）、p.1373（LEVEL AT：driftdown 中の水平までの時刻と距離）。
- 作ったもの：
  - VNAV（`B747.68.vnav_model.lua`）：ENG OUT の実行中（つなぎが CRZ のページの MAX を毎秒 `eo_max` で渡す）、巡航の降下（CRZ ALT が機体の下）で機体が MAX + 200 ft（ページの D/D の題と同じ `EO_DD_ABOVE`）より上なら driftdown：VNAV SPD、A/T の THR、目標 −300 fpm（`EO_DD_VS`：最小）、目標の速さは CRZ ALT での巡航の速さ（E/O LRC を Mach で：2L の LRC SPD）。始めたときの MAX を床として持ち、CRZ ALT に着くか床の 50 ft 下で終わる（その下は巡航の降下の則：E/O CRZ DES、推定）。新設の `laminar/B747/fms/vnav/dd` で A/T に知らせる。
  - A/T（`B747.70.at_model.lua`）：driftdown の始まりで THR に戻す（巡航の降下の HOLD からも：条件 3）。driftdown 中は目標の降下率に達しても HOLD にしない（THR のまま、推力は reference の CON で頭打ち：降下率は最小 300 fpm、推力が足りなければもっと降りる）。後ろの止めと手の介入の HOLD はそのまま。
  - A/T の巻き上がりの防止（X-Plane の s157 の初めの版で見つけた）：25,000 ft より上の EEC の全開の定格は最大上昇（レバー 35° から先は推力が同じ：段 9h1 の推定）で CON の reference より低いので、driftdown の初め（速さが足りず −2,400 fpm）に A/T の THR がレバーを全開まで進め、推力が要らなくなってもレバーが 35° に戻るまで約 8 分推力が減らず、降下率が −130 fpm まで浅くなった。reference を EEC の全開の定格（`laminar/B747/engines/display_EPR_max`、GE は `display_N1_max`）以下に抑え、SPD と THR はその手前 `REF_NEAR`（EPR 0.05、N1 2.5 %：推定）の中で進める速さを絞り、そこで止める（THR REF と同じ考え）。reference が無いとき（0）は前のまま。
  - 予測（`B747.68.pred_model.lua`）：入力 `eo`（E/O の抗力、運転中の 4 − eo 発の燃料。巡航は表の E/O の燃料流量、上昇は上昇推力のその割合（CON をそれとみなす：推定）、降下の経路も E/O の抗力とアイドル）。入力 `crz_des`：巡航の降下（1,250 fpm、要る推力、アイドル以上）か driftdown（CRZ ALT での速さの Mach、CON の頭打ち、最小 300 fpm。CON は上昇推力の割合を CRZ ALT の抗力に比例で合わせる：そこで水平になる、推定）を先に計算して水平になる点（`lvl`・`lvl_t`・`lvl_dd`）。前は巡航の降下中も今の高度で巡航するとしていた。E/O では段の上昇を計算しない（推定）。CRZ ALT が E/O の MAX より上なら予測を出さない。
  - CDU：E/O CRZ のページの 2R は driftdown 中 AT（予測の水平の時刻と距離）、題 E/O LRC D/D は VNAV の driftdown の間も（燃料が減って MAX が機体の上に上がっても）。PROGRESS の 5L は E/O の実行中 E/O SPD（FCOM p.1372 は EO SPD、FMSPG は E/O SPD）、5R は driftdown 中 LEVEL AT（TO を付けない：推定）。予測は driftdown の始まりと終わりですぐ作り直す（s157 の初めの版は EXEC の時の予測が driftdown の前で、AT が 10 秒出なかった）。PROGRESS の 5R は見出しの点が無ければ空白（前は前の見出しが残り、水平の後も LEVEL AT のままだった）。5L の Mach を .XXX に（FCOM p.1371：前は 0.827）。
  - `perf_db.eo_lrc`：表の高度の外は端の速さを保つ（下は KIAS、上は Mach。燃料流量と設定は端の値：推定）。
  - つなぎの直し：LRC（全発・E/O）の速さの関数に重さが無いとき（FMC の重量が未入力の VNAV）は FMC か X-Plane の重さ。前は Lua の誤りで FMS が止まった（結合試験で見つけた）。
- 推定：driftdown の A/T の FMA（THR：資料に記述なし）、床の下の巡航の降下の則、予測の CON（上昇推力の割合を CRZ ALT で合わせる）、E/O で段の上昇なし、LEVEL AT に TO を付けないこと、A/T の `REF_NEAR`。
- 資料との食い違い（次の段 9h4c で直す）：FCOM p.1268（条件 3）と p.1269（E/O の後の巡航の降下）は、巡航の降下では A/T が巡航の速さ（E/O LRC）を保ち約 1,250 fpm で降りると書く。段 9d2a の巡航の降下の則（VNAV SPD と A/T の THR、率に達すると HOLD：早めの降下の FMSPG p.3.5-5 を流用した推定）とは違う。
- 試験：`vnav_model_test.lua` 176 件（driftdown の始まりと終わり、床の下の巡航の降下、条件 3、MAX + 200 の中、MAX が下がれば再び）、`at_model_test.lua` 110 件（driftdown の始まりで THR、目標の降下率で HOLD にならない、CON で頭打ち、後ろの止めの HOLD、終われば巡航の降下の HOLD、全開の定格で止まる・手前で絞る・定格が分からなければ前のまま・reference が無ければ前のまま）、`pred_model_test.lua` 73 件（巡航の降下の水平の点、driftdown の LEVEL AT と時間、高いほど始めが急、E/O LRC の三発の燃料、E/O の降下の経路と上昇）、`perf_db_test.lua` 119 件（表の外の E/O LRC）、新設の `eo_dd_test.lua` 27 件（ZZAA の経路で 33,500 ft・300 t、CLB のページの ENG OUT> と EXEC で CRZ ALT 32,000 ft、dd・VNAV SPD・THR・−300 fpm・CRZ ALT の E/O LRC の Mach、CON、EXEC の 1 秒後に予測の LEVEL AT、CRZ のページの ACT E/O LRC D/D と AT、PROGRESS の E/O SPD と LEVEL AT、水平で E/O LRC CRZ と予測の作り直し、5R は次の点か空白、5L の Mach は .827）。全 139 本。X-Plane：起動し直した後（1:35）の s128（捨て）に続き、新設の `s157_eo_driftdown` の初めの版は 29/32。driftdown 自体は動いた（FL370・270 t でエンジン 2 を止め、CRZ のページの ENG OUT> で MOD E/O LRC D/D、CRZ ALT FL330、LRC SPD .827、MAX FL331。MCP FL300 で EXEC：dd、CON、ACT E/O LRC D/D、VNAV SPD、A/T THR、目標 M.827、PROGRESS に E/O SPD と LEVEL AT 0114z/93NM、FL330 で水平して ACT E/O LRC CRZ と A/T SPD）。落ちた 3 件は、EXEC の 3 秒後に 2R の AT が無い（予測が driftdown の前のもの）が 2 件と、水平の後も LEVEL AT（T/D の無い経路で前の見出しが残る）。また 5,000 ft に 17.5 分かかった。記録では、初め（−2,400 fpm で速さを取る間）に A/T がレバーを全開まで進め、25,000 ft より上の全開の帯（CON の reference より低い最大上昇）を戻る約 8 分の間、推力が減らずに −130 fpm まで浅くなっていた。`s156_eo_pages` は 24/25（押したとき空中開始の揺れで上昇中で、120 秒で −183 fpm）。直した後（2:16〜2:49）は s157 34/34：driftdown は 5,000 ft を 14.6 分、VNAV SPD の間の平均 −277 fpm（−226〜−340：目標の 300 fpm よりやや浅いのは A/T の THR の則の遅れ、推定）、EPR は 1.580 から 1.531 へなめらかに下がり、5 分後も THR で −278 fpm。EXEC の 3 秒後に 2R の AT 0116z/116NM、水平の後は 5R が空白。写真で CRZ のページの ACT E/O LRC D/D・AT・MAX FL331、PROGRESS の E/O SPD と LEVEL AT（5L の Mach の頭の 0 はこの後に直した）、水平の後の ACT E/O LRC CRZ を確かめた。s156 25/25、A/T の変更の確かめに s108（FLCH）21/21。Log.txt に Lua の誤りなし

## 83. 段 9h4c の実装（2026-11-01：巡航の降下の則を FCOM に合わせる）

- 資料：FCOM p.1268（条件 3：全発の巡航の降下は ECON の巡航の速さで約 1,250 fpm、推力制限は CLB/CRZ、A/T が巡航の速さを保つ）、p.1269（E/O の後の巡航の降下：約 1,250 fpm、E/O LRC の速さ、推力制限は CON のまま、A/T が E/O LRC の速さを保つ、MCP の高度が E/O CRZ のページの CRZ ALT に）。早めの降下（DES NOW、T/D の 50 NM 内の高度のノブ）は FCOM p.1258 と FMSPG p.3.5-5 のとおり VNAV SPD で A/T は THR から HOLD のまま。
- 前（段 9d2a）：巡航の降下も早めの降下と同じ VNAV SPD と A/T の THR（1,250 fpm に達すると HOLD）にしていた（資料が無いとした推定。段 9h4b で FCOM p.1268–1269 の記述に気づいた）。
- 作ったもの：VNAV（`B747.68.vnav_model.lua`）の巡航の降下（CRZ ALT を機体の下に）は VNAV PTH（FMC の要求 2）で −1,250 fpm、A/T は SPD（巡航の速さ、E/O では E/O LRC）。AFDS（`B747.70.xt.autopilot.lua`）は、FMC の段階が巡航で V/S が 0 でなければ VS の則（前は降下の段階だけ）にし、FMC の高度（CRZ ALT）をその VNAV PTH でも捉える（前は VNAV SPD だけ）。driftdown の床の下（E/O CRZ DES：段 9h4b）も同じ則。予測（段 9h4b の巡航の降下：1,250 fpm で要る推力）はもとからこの形。
- 推定：FMA のピッチを VNAV PTH にすること（資料は降下率と A/T が速さを保つことだけを書く。ピッチが率を持つので PTH）。
- 試験：`vnav_model_test.lua` 177 件（巡航の降下は VNAV PTH と SPD、driftdown の床の下も）、`afds_glue_test.lua` 263 件（巡航の段階で FMC が V/S を求めると VNAV PTH で VS の則：水平から指令が下がる、A/T SPD、CRZ ALT の 60 ft 上を 1,200 fpm で降りると捉えて指令が上がる。前の巡航の降下の試験は、巡航の段階の VNAV SPD と THR（driftdown の形）の試験として残した）、`pred_glue_test.lua` 173 件（押した後の FMC の要求は PTH と SPD）。全 139 本。`s145_vnav_cruise_descent` を新しい則に直した（FMC の要求 PTH・−1,250 fpm・SPD、FMA は VNAV PTH、約 1,250 fpm、A/T は SPD のまま、巡航の Mach を保つ、FL240 で水平）。X-Plane：起動し直した後（3:00）の s128（捨て）に続き、直した `s145_vnav_cruise_descent` の初めの版は 29/30：MCP FL240 を押すと FMC の要求は PTH・−1,250 fpm・SPD、FMA は VNAV PTH、約 25 秒で −1,220〜−1,260 fpm に落ち着き、A/T は SPD のまま FL240 の ECON の Mach（.784：CRZ ALT が変わって ECON がその高度の値に）へ減速、IAS は目標の約 4 kt 下で追い（定まった Mach で降りるので IAS の目標が増える）、FL240 で滑らかに水平して ACT ECON CRZ。落ちた 1 件はシナリオの比べ方（押した時の FL300 の ECON .833 と比べた）で、降下中の目標と比べるように直した後（3:20）は 30/30（−1,255 fpm、Mach .796 で目標 .784 へ減速中）。`s156_eo_pages` 25/25（driftdown の床の下は E/O CRZ DES の新しい則）。Log.txt に Lua の誤りなし

## 84. 段 9h5 の段取りと 9h5a の実装（2026-11-01：RTA PROGRESS のページ）

- 資料：FCOM p.1269（RTA：VNAV が巡航の速さで指定の点に ±30 秒で着く、できなければ UNABLE RTA、E/O では使えない）、p.1354（RTA CRZ のページ：題 ACT RTA CRZ、2L RTA SPD、5L <ECON、6L <RTA PROGRESS か <ERASE）、p.1383–1385（RTA PROGRESS 3/3：作ると PROGRESS と CRZ の題に RTA、巡航のみ。1L FIX は現用か変更の経路の点、入れると 1R に箱と見出し RTA、2R の見出し ALT/ETA、RTA が有効なら FIX の DELETE で終わり ECON、変更なら変更を消す、経路があれば箱、E/O では空白。2L RTA SPD は FMC の計算、FIX か時刻が無ければ空白。3L MAX SPD は .100〜.99 の大きい字、DELETE で .880 の小さい字。6L ERASE。1R RTA は 0000.0〜2359.9（.0 は省略可）、A は以後、B は以前、DELETE で RTA を終えて ECON。2R ALT/ETA は予測の高度と時刻、性能のデータが無ければ空白。6R PRIOR RTA は前の RTA があるとき、押すと前の点と時刻の変更、実行で有効）、p.1375（570 の PROGRESS は 1/2：RTA なし）、p.1434（RTA FIX DELETED・UNABLE FLXXX AT RTA FIX・UNABLE RTA は 109・405）、FMSPG p.3.4-52〜55（PROGRESS 1/3 から PREV か 2/3 から NEXT で RTA PROGRESS、FIX は空中で E/O でないとき、5L MAX SPD（FCOM は 3L：FCOM を採る））。
- 小分け：9h5a（RTA PROGRESS のページ、RTA の変更・EXEC・ERASE・PRIOR RTA、MAX SPD、570 は無し、E/O では空白で ENG OUT の実行で終わる）、9h5b（RTA の速さ：予測で到着時刻を合わせる巡航の Mach、MAX SPD と下限、A・B、VNAV と予測がそれで飛ぶ、ACT RTA CRZ と RTA SPD、PROGRESS の RTA SPD、UNABLE RTA、RTA FIX DELETED、ECON・LRC・SEL・点の通過で終わる）。
- 作ったもの：
  - `B747.68.rta_model.lua`（新設、純粋）：有効な RTA（点、時刻（UTC の 1 日の分）、A・B）、変更（時刻が無ければ箱）、前の RTA、MAX SPD。FIX で変更、時刻で完成、EXEC で有効、ERASE、FIX・時刻の DELETE（有効なら終わって前の RTA に、変更なら FIX は変更ごと・時刻は箱に）、PRIOR RTA（有効なものが無く前の点が経路にあるとき）、時刻の入力の読み（HHMM、.M、A・B、範囲）と表示（1740.0zB）。
  - PROGRESS のページ（`B744.fms.pages.progress.lua`）：3/3 を RTA PROGRESS に（前は固定の文字）。題に ACT・MOD、1L FIX（経路があれば箱、E/O では空白）、1R RTA（FIX の後に箱、見出し RTA）、2R ALT/ETA（予測の現用の経路の FIX の高度：遷移高度から上は FL、時刻は 0.1 分）、3L MAX SPD、6L <ERASE（変更があるとき）、6R PRIOR RTA>。入力：FIX は経路の点（無ければ INVALID ENTRY：推定、E/O でも）、時刻は FIX の後、MAX SPD は .100〜.990。NEXT・PREV は FMC のページ送り（最後の NEXT は最初、最初の PREV は最後：FMSPG p.3.4-52。前は X-Plane の CDU のキーで、1/3 の PREV は 0 ページに）、EXEC は FMC の（`rteexec`）。570 は 2 ページ（1/2・2/2）。2L RTA SPD の速さは段 9h5b。
  - つなぎ：RTA の変更を EXEC（`rteexec`）・ERASE（`rteerase`）・EXEC の灯（完成したとき）に足した。570（`laminar/B747/engines/type` 1）と ENG OUT の実行中は使えず、ENG OUT の実行で有効な RTA を終える（FCOM p.1269）。CRZ のページの 6L <RTA PROGRESS は PROGRESS 3/3 へ（前は 1/3）、570 では出さない。`setpage_no` の PROGRESS を FMC の PROGRESS（PROG キーと同じ）の指定のページに（前は X-Plane の CDU の PROGRESS の 1 ページ目）。
- 推定：経路に無い FIX の INVALID ENTRY、変更の EXEC の灯を時刻まで入れたときに、MAX SPD の入力をすぐ効かせる（変更にしない）、PRIOR RTA を FIX・時刻の DELETE と ENG OUT の実行で残すこと。
- 試験：`rta_model_test.lua` 37 件（新設：時刻の入力と表示、変更と箱、EXEC、ERASE、DELETE、PRIOR RTA、MAX SPD）、`rta_pages_test.lua` 45 件（新設：ZZAA の経路で PROGRESS 1/3 の PREV で 3/3、箱、経路に無い点、DELTA の MOD と箱・見出し・ERASE、時刻の誤りと 1740.0zB、EXEC の灯、ALT/ETA、EXEC で ACT、MAX SPD、時刻の DELETE と PRIOR RTA>・ERASE・再び EXEC、FIX の DELETE、CRZ のページの <RTA PROGRESS で 3/3、ENG OUT で空白と終わり、570 の 1/2・2/2 と <RTA PROGRESS なし）、`cdu_framework_test.lua` 37 件（X-Plane の CDU へキーを送る試験を、PROGRESS の NEXT の代わりにその定義を一時 `custom2fmc` にして）。全 141 本。新設の X-Plane の `s158_rta_pages`：初めの版（3:45）は 16/25：RTA PROGRESS 3/3（PROGRESS 1/3 の PREV）、1L の箱、MAX SPD .880 の小さい字、経路に無い点の INVALID ENTRY、CRZ のページの <RTA PROGRESS で 3/3 までは通ったが、落ちた 9 件はシナリオの誤り（INVALID ENTRY の後の CLR 1 回では通知が消えるだけで NOFIX が書き込み行に戻り、続けて打った SPENS が NOFIXSPENS になって以後の入力がつながった）。CLR を 7 回にした後（3:48）は 26/26：SPENS で MOD RTA PROGRESS と 1R の箱、1740.0B で 1740.0zB と EXEC の灯、EXEC で ACT RTA PROGRESS と ALT/ETA（FL361/0114.5z）、MAX SPD .850 の大きい字と DELETE で .880、CRZ のページの <RTA PROGRESS で 3/3、時刻の DELETE で終わり PRIOR RTA>、それで前の SPENS 1740.0zB の変更、ERASE。写真で題がページ番号の 3/3 とくっついていたので、ほかのページと同じく題を番号の手前の 22 文字で中央に直した（LuaJIT の試験で確かめた）。Log.txt に Lua の誤りなし

## 85. 段 9h5b の実装（2026-11-01：RTA の速さ）

- 資料：FCOM p.1269（VNAV が巡航の速さで指定の点に ±30 秒で着く、できなければ UNABLE RTA、E/O では使えない）、p.1354（RTA CRZ：題 ACT RTA CRZ、2L RTA SPD は FMC が計算した巡航の速さ、5L <ECON は RTA SPD のときも出て押すと ECON CRZ、その実行で RTA を終える）、p.1372（PROGRESS の 5L に RTA SPD）、p.1383–1384（RTA は巡航のみ、RTA SPD は FMC の計算、MAX SPD は既定 .880、A は以後・B は以前、FIX・時刻の DELETE で ECON に戻る）、p.1434（UNABLE RTA：許容の到着時刻に着けない。RTA FIX DELETED：変更した経路から RTA の点が消えた）。
- 作ったもの：
  - `B747.68.rta_model.lua` の `speed`：予測の FIX の時刻の誤差から巡航の Mach を一歩直す（巡航の時間は速さに反比例：推定）。A は元の速さより速くせず（以後でよい）、B は遅くせず（以前でよい）、下限と上限の内。上限か下限で 30 秒より外れていれば（巡航が残っていなくても）UNABLE。
  - つなぎ（`rta_update`、予測ごと 10 秒）：元の巡航の速さ（RTA なしの ECON・LRC・乗員の速さ、CRZ ALT の Mach）、下限は最小抗力と最小機動速度 + 5 kt の大きい方、上限は MAX SPD と VMO/MMO − 16 kt（FCOM p.1258）の小さい方（推定）、巡航の時間は T/C（巡航中は今）から FIX か T/D まで（降下中はなし）。一歩ごとに予測し直して最大 3 歩。UNABLE RTA（旗 48）、RTA FIX DELETED（旗 39：経路の変更に FIX が無い間）。FIX が現用の経路の先に無くなれば（通過か、変更の実行で消えた）RTA を終える（推定）。`B747_fms_schedules` は有効な RTA の Mach を巡航の速さに（VNAV と予測）。
  - CDU：CRZ のページは RTA の間 ACT RTA CRZ、2L に RTA SPD とその見出し、5L <ECON。<ECON と LRC> と乗員の速さの入力で RTA を終える（すぐに：推定。FCOM は ECON の実行で終える）。PROGRESS の 5L は巡航中 RTA SPD、RTA PROGRESS の 2L に RTA SPD（有効な RTA の）。FIX・時刻の DELETE で終えると ECON に戻す（FCOM p.1384）。
- 推定：速さの下限と上限、予測ごとに一歩直すこと、RTA の時刻を前後 12 時間の近い方の日とみなすこと、ECON・LRC・乗員の速さですぐ終えること、FIX の通過・削除で終えること、変更中の RTA SPD を空白にすること、巡航が残っていないときの UNABLE。作っていないもの：UNABLE FL___ AT RTA FIX（旗 46）。
- 試験：`rta_model_test.lua` 51 件（速さ：時刻どおり、1 分早いと遅く（9 分の巡航を 10 分に）、遅いと速く上限で止まる、上限で 1 分遅いと UNABLE、30 秒の内は出ない、下限で早いと UNABLE で B なら元の速さ、A で遅いと元の速さ・早いと遅く、日付をまたぐ、巡航なし）、新設の `rta_speed_test.lua` 24 件（ZZAA の経路の FL350・270 t の巡航で DELTA に予測の 1 分後の RTA：ECON M.853 から M.803 で予測の誤差 0.00 分、VNAV の目標、RTA PROGRESS・CRZ（ACT RTA CRZ、RTA SPD、<ECON）・PROGRESS の表示、5 分早いと上限 M.879 で UNABLE RTA と書き込み行の通知、<ECON で終わり通知も消える、乗員の速さで終わる、時刻の DELETE で ECON）。全 142 本。新設の X-Plane の `s159_rta_speed`：起動し直した後（4:02）の s128（捨て）に続き、初めの s159 は 16/18：EXEC の 12 秒後に RTA SPD .803（ECON .854）で予測の SPENS 0115.5z と RTA どおり、0110.0 で UNABLE RTA と上限 .879 が出たが、LNAV を入れていなかったので機首 340° のまま経路から離れ、予測の時刻が遅れ続けて 2.5 分後には上限でも 3.3 分遅れ（シナリオの誤り）。s158 は 22/26（RTA 1740.0B は今 01:02z から ±12 時間の見方で 7.6 時間遅れの UNABLE RTA になり、書き込み行の通知が後の入力を邪魔した：0120.0B に直した後（4:21）は 26/26、RTA SPD は B で早いので ECON の .854、ALT/ETA FL363/0114.5z）。LNAV（XAC へ DIRECT TO）を入れた s159 は 19/20：予測の時刻は EXEC の後も 2.5 分後も 0115.5z のまま、ただ LNAV の XAC への約 140° の旋回（2 分）は予測の距離に入らず、その遅れを RTA が速さを .820 から .866 に上げて取り戻したので、ECON より遅いはずという確認が落ちた。その時の RTA の Mach と比べる確認に直した後（4:24）は 20/20（.866 で機体 .874、0110.0 で UNABLE RTA と .879）。写真で CRZ のページの ACT RTA CRZ、RTA SPD .820、<ECON、<RTA PROGRESS（FCOM p.1354 の形）。Log.txt に Lua の誤りなし

## 86. 段 10 の段取りと 10a の実装（2026-11-01：位置の更新と航法性能）

- 段取り（FMC-28〜31、CDU-16・27、DSP-14）：
  - 10a：FMC の位置の更新と航法性能（更新の源、ANP、RNP、UNABLE RNP、POS REF 2/3・3/3、ND の更新の表示、REF NAV DATA の抑止を効かせる）。
  - 10b：VOR・DME の同調（P・R・A・M、DME-DME の局と VOR の自動同調、手動との関係：FCOM p.1240、p.1303–1304；ATA34_2 p.605–606）と NAV RADIO の VOR・ADF（CDU-16）。
  - 10c：ILS の同調（経路の進入から、PARK・A の条件、離陸後 10 分などの禁止、ILS TUNE INHIBITED、RW/ILS FREQ・CRS ERROR：FCOM p.1305–1307）、PFD の ILS 表示（DSP-14）、LOC 更新の X-Plane での確認。
  - 10d：flight complete（エンジン停止の 30 秒後：FCOM p.1236）で経路・搭載データ・便名（ATA34_2 p.521）・REF NAV DATA の抑止・GPS NAV・RNP の入力を消す。
- 決めたこと：誘導は今までどおり X-Plane の位置で飛ぶ（IRU にドリフトが無い：B747.34.xt.irs.lua）。FMC の位置もそれとし、更新の源と ANP を資料どおりに見せる（推定・簡略）。
- 資料：FCOM p.1240–1245（GPS・無線・IRS、優先順位、LOC 更新の条件、POS REF と ND の表示の表、ANP と RNP、極地方）、p.1367–1370（POS REF 2/3・3/3）、p.1150（ND の FMC-IRS・FMC-radio・FMC-GPS の更新の表示）、p.1430（UNABLE RNP：approach の外は advisory、approach では caution、極地方では出さない）、p.1435–1436（VERIFY RNP、VERIFY RNP ENTRY）、p.1356–1357（REF NAV DATA の抑止）。ATA34_2 p.517（RNP の既定：離陸 1.00、洋上・遠隔 12.00、国内 2.00、ターミナル 1.00、進入 .50 NM、入力は 0.01–99.9 の大字）、p.601–602（IRS の混合：3 台の平均、2 台なら FMC-L は L か C、1 台ならそれ）、p.605（ILS の DME は DME のチャネル 5）。FMSPG p.25–28（DME-DME の組：12,500 ft の下は 30–150° で最良、上は 90° に近いもの。データベースの到達距離）、p.74–76（POS REF）。FCTM p.61（GPS なしでも最後の無線の更新から 6 時間は RNP 10）。LH3460 p.114（UNABLE RNP）。
- 作ったもの：
  - `B747.68.navperf_model.lua`（新）：更新の源を FCOM p.1241 の順（LOC と GPS、LOC と DME-DME、LOC と VOR/DME、LOC、GPS、DME-DME、VOR/DME、IRS）で選ぶ。GPS は有効で GPS NAV で抑止されておらず、ACTUAL が RNP の 2 倍以上なら使わない（FCOM p.1368）。IRS が無ければ FMC の位置は無い（FCOM p.1240）。ANP、段階ごとの RNP の既定と入力、VERIFY RNP ENTRY・VERIFY RNP、UNABLE RNP、PURGE と CONFIRM、GPS NAV、極地方（84° から split IRS：無線の更新なしで SPLIT IRS OPERATION、88.5° から GPS なし、UNABLE RNP を出さない）。DME の到達、DME-DME の組、LOC 更新の条件。
  - `B747.68.navdb.lua` の `radio_near`：近くの VOR・DME・LOC（2° の升目を初めに作る）。
  - つなぎ（`B747.68.xt.fms.lua` の `update_navperf`、1 秒ごと）：IRS（`B747_fms_irs_pos`）、GPS、FMC のデータベースの DME（10 秒ごとに探す。NAVAID INHIBIT の局と ILS の DME は除く）からの組、VOR L・R が受けている VOR/DME（VOR ONLY INHIBIT の局と VOR/DME NAV の抑止中は除く）、ILS L の LOC（経路の進入の滑走路のもの）、段階（進入中・地上・出発地か目的地の 30 NM 内・200 NM 内に局なし）。ND の更新の行（`gps_display_line`：GPS・LOCGPS・DD・VD・LOC・LOC DD・LOC VD、`irs_display_line`：IRS (3)・(L)・(C)・(R)：FCOM p.1150）、UNABLE RNP（caution 66、advisory 295）、VERIFY RNP・SPLIT IRS OPERATION（変わったときだけ書くので CLR で消せる）。前は ND の IRS の行を IRU の整列で出し、GPS の行は IRU が無いときだけ GPS、UNABLE RNP は AP が 0 を書くだけ（段 1 で XTK の誤警報をやめた後）だった。
  - POS REF 2/3：1L FMC POS（源を見出しに：GPS L・GPS R・LOC-GPS L・LOC-DD・LOC-VD・LOC・RADIO・INERTIAL）と GS、2L IRS(X)、3L RNP/ACTUAL（既定は小字、入力は大字、NM は小字）、3R DME-DME・VOR-DME・NAV STA と局、5L <PURGE・<CONFIRM、5R GPS NAV の INHIBIT>・ENABLE>、6R BRG/DIST>・LAT/LON>（IRS の行を FMC の位置からの方位/距離に：FCOM p.1244 の 150°/3.7）。POS REF 3/3：IRS L・C・R、GPS L・R（無効なら空白、GPS は抑止中も空白）と BRG/DIST。INIT/REF INDEX の <POS は、空中で IRU が ATT でなければ POS REF 2/3（FCOM p.1367）。前は固定の文字（RNP/ACTUAL は 2.00/0.05 か 0.15、PURGE・GPS NAV・BRG/DIST は効かない）。
- 推定：ANP の模型（GPS 0.05 NM、DME の誤差の 1σ は √(0.05² + max(0.085, 0.00125 d)²) NM、VOR は 1°、ANP は 2σ、DME-DME は 2 局の角度の sin で割る。より良い源の ANP にはすぐなり、悪くなるときは空中で 6 時間に 10 NM の割合で増える（FCTM p.61 から）。IRS は航法を始めたとき 0.10 NM。地上では増えない）、DME の到達（データベースの距離、電波の見通し 1.23(√h + √e) NM、45° より上は使わない）、VOR/DME は 25 NM 内、段階の決め方（ターミナルは 30 NM、洋上・遠隔は 200 NM 内に VOR も DME も無いとき）、PURGE の後 10 秒は更新しない、BRG/DIST の方位は磁方位で NM は小字、CONFIRM の間の見出し（PURGE、FMC POS に源を付けない）。
- 作っていないもの：VERIFY POSITION と PURGE UPDATES（位置の食い違いが起きない）、TO/GA の位置の更新（地上で ANP が増えないので見た目が変わらない）、IRS NAV ONLY（RNP の選択の無い FMC のもの）、LOC の back course、ND の IRS (3) からの変化の 10 秒の枠、IRU の棄却（30 NM・20 kt：ドリフトが無い）、POS REF の位置を書き込み行に写すこと。
- 試験：新しい `navperf_model_test.lua`（89 件：ANP の模型、DME の到達、DME-DME の組の選び方（12,500 ft の上と下、30–150°）、LOC 更新の条件、RNP の段階、源の順と見出しと ND の文字、GPS の抑止で DME-DME（ANP は 0.05 から増えて組のものに）、VOR/DME・LOC・LOC-GPS、RNP の入力と VERIFY RNP ENTRY・INVALID・DELETE、RNP 0.02 で GPS を使わない、VERIFY RNP、IRS だけの ANP の増え方と UNABLE RNP（advisory と進入の caution、地上では増えない）、PURGE と CONFIRM、極地方）、新しい `pos_ref_pages_test.lua`（54 件：ZZAA の近くの地上で ND の GPS と IRS (3)、POS REF 2/3 の行、DME-DME の局、RNP の入力、GPS NAV で RADIO と ND の DD、3/3、BRG/DIST とページを離れて戻る、PURGE と CONFIRM と 10 秒後の GPS L、NAVAID INHIBIT で NAV STA、空中で <POS から 2/3、洋上の 12.00、UNABLE RNP の advisory、VERIFY RNP、ZZAA の ILS16R の経路で LOC-DD・LOC-GPS L と ND の LOCGPS、航跡が 60° ずれると GPS L だけ、ILS L が別の局なら LOC 更新なし）、`navdb_test.lua`（68 件：`radio_near`）。試験用の航法データに DME を 2 局（ZZE・ZZW）。全 144 本。X-Plane：新しい `s160_pos_ref`：起動し直した後（5:28）の s128（捨て）に続き、新しい s160 は 35/35：ND は GPS と IRS (3)、空中の INIT/REF INDEX の <POS で POS REF 2/3、FMC POS (GPS L)・IRS(3)・RNP/ACTUAL は 2.00（小字）/0.05・DME-DME は TNT GTC。GPS NAV の INHIBIT> で ENABLE>・RADIO・ND の DD。RNP .01 で VERIFY RNP ENTRY と EICAS の UNABLE RNP（advisory）、DELETE で 2.00 に戻り消えた。BRG/DIST> で IRS の行が 000°/0.0 など、3/3 の IRS L・C・R（GPS は抑止中で空白）。<PURGE で見出しの PURGE・<CONFIRM と IRS の ACTUAL 0.12、CONFIRM で INERTIAL、10 秒後に GPS L。初めの回（5:34）の写真は操縦輪が CDU の左を隠し、3/3 と PURGE は EICAS のまま撮ったので、操縦輪を隠して視点を戻し撮り直した（5:38、35/35）。写真で配置と大字・小字を FCOM p.1367・p.1370 と比べた。Log.txt に Lua の誤りなし

## 87. 段 10b の実装（2026-11-01：VOR・ADF の同調と NAV RADIO）

- 資料：FCOM p.1303–1304（NAV RADIO：VOR の P・R・A・M、R は前の VOR か下流の 250 NM 内の VOR、手動は識別子・周波数・周波数/コースで DELETE なら自動に戻る、CRS は自動の間は空白で手動はダッシュかコース、ADF の A（ANT）・B（BFO））、p.1240（FMC が VOR・DME・ILS を自動で同調し、選び方は現用の経路と手順による。VOR を手動にしても DME-DME の組は同調し続ける）、FMSPG p.206–207（状態の文字は小字、手動の DELETE でコースも消える、RADIAL は受けている radial、ADF の入力と DELETE）、ATA34_2 p.605–606（同調の 4 つの方法：手動・手順（出発・到着の手順が指定する航法施設）・経路・自動。自動以外は指定の局、自動は位置の計算に一番よい局）、p.586（ADF）。
- 作ったもの：
  - `B747.68.tune_model.lua`（新）：VOR・CRS・ADF の入力と DELETE、FMC の局の選び方。
  - つなぎ（`B747.68.xt.fms.lua` の `update_tuning`、1 秒ごと）：手動でない VOR L・R に、現用の脚の手順の航法施設（SID・STAR、進入は進入に入ってから。進入では滑走路の脚のコースも：FCOM p.1304）、経路の下流の VOR と前の VOR（250 NM 内）、DME-DME の組の局（無ければ届く近い局）の順で入れる。X-Plane の NAV 3・4 の周波数とコース、同調の文字（`laminar/B747/radio/tuningmodes`：VOR は P・R・A・M、ADF は M・A（ANT）・B（BFO）。ND と表示は M 以外を自動とみる）。前は `irs/rnav_system.lua` が 10 秒ごとに近い VOR を 2 局入れるだけだった（消した）。
  - NAV RADIO：VOR の行（周波数、小字の状態、識別子）、CRS（自動は空白、手動はダッシュかコース）、RADIAL（受けている VOR から：X-Plane の局への方位 + 180。前は局への方位を出していた）、ADF（周波数、小字の ANT・BFO、無ければダッシュ）。入力は VOR の識別子（VOR か、ILS のでない DME）・周波数・/コース、CRS、ADF の XXX.X・XXXX.X と A・B（FCOM p.1304）。
  - 表示：ADF の ANT では ND の方位の針を出さない（`B747.60.xt.displays.lua`）。周波数の表示は残す。
- 推定：VOR L と R の分け方（VOR L は手順・下流・前・位置の局の順の最初、VOR R はその次で VOR L と違う局）、A の局（DME-DME の組の 2 局、無ければ届く近い局）、局が無い間は前の局のまま、同じ識別子が 2 つ以上なら一番近いもの、周波数の範囲（VOR は 108.00–117.95 の 50 kHz、ADF は 190–1750 kHz）、手順の航法施設は現用の脚のもの。
- 作っていないもの：ILS の行（段 10c）、PERF FACTORS の R の入切（FMSPG p.206）、BFO の音。PRESELECT は前のまま。
- GAP：NAV-34（RADIAL が局への方位、自動同調中に OBS へ同じ値）、NAV-35（最寄りの VOR だけの自動同調、R・P・抑止・手動の扱いが無い）、NAV-36（2 番目の局の探し方の誤り）はこれで解消。NAV-43 のうち手動の VOR のコースの線は前から（5-2 段 5c）、ほかは残る。
- 試験：新しい `tune_model_test.lua`（55 件：周波数とコースの形、VOR の入力（識別子、周波数/コース、NOT IN DATA BASE、INVALID ENTRY、DELETE と INVALID DELETE）、CRS、ADF（BFO、ANT、DELETE、範囲）、局の選び方（P・R・A の順、手動の局を避ける、局が無ければそのまま））、新しい `navrad_pages_test.lua`（28 件：ZZAA の近くの地上で経路なしの A（DME-DME の組の局）、16R の ZULU1 の経路で P の ZZV と A、ZZD の手動と CRS のダッシュ、045、113.00/090、NOT IN DATA BASE、NDB の INVALID ENTRY、DELETE で P に戻りコースが消える、自動の間の CRS は INVALID ENTRY、RADIAL 262、ADF の 350.0・1304.5 BFO・ANT・DELETE、同調の文字）。全 146 本。X-Plane：新しい `s161_navrad`：新しい s161 は 25/25：経路なしで VOR L・R は A（CVT 113.60 と OSE 109.85）。RJAA→RJBB の経路で VOR L は R の XAC 113.10（NAV 3 も 11310）、VOR R は A。NRE を 1R で M の 117.90、CRS R はダッシュ、180 で受信機のコース 180、RADIAL は XAC 033・NRE 341（NRE への方位 161 + 180）、ND の MAP に NRE を通る手動のコースの線（緑の破線）。ADF L 350.0、ADF R 1304.5 と小字の BFO（ADF 2 は 1304）、A で ANT（同調の文字の 5 番目が A）、DELETE で ADF。VOR R の DELETE で A に戻り CRS は空白。写真で配置と小字を FCOM p.1303 と比べた。Log.txt に Lua の誤りなし

## 88. 段 10c の実装（2026-11-01：ILS の同調と PFD の ILS の目盛）

- 資料：FCOM p.1304–1307（NAV RADIO の ILS の行：PARK、目的地の滑走路の ILS の周波数/コースを小字で PARK と、A、M。表示の条件（PARK は電源の入った時・T/D の 200 NM より遠い・半分の手前、小字は T/D の 200 NM 内か半分を過ぎた方の目的地に近い方、A は T/D の 50 NM 内・閾値の 150 NM 内・降下中）、入力（XXX.XX/YYY、/YYY）、離陸後 10 分と手動の間は自動同調しない・目的地の滑走路を変えればその 10 分は解ける、FCC の禁止（A/P で LOC か G/S を捕まえた、F/D だけで 500 ft 未満、地上の滑走）、TOGA か A/P と両 F/D を切れば手動に戻せる）、p.987（PFD の LOC・G/S の目盛は周波数を同調したら出る）、p.1432（ILS TUNE INHIBITED - MCP：FCC の禁止の間に手で触るか新しい到着の ILS の進入を有効にした）、p.1434（RW/ILS FREQ ERROR、RW/ILS CRS ERROR）。FMSPG p.208（同じ条件。A は二つの距離の大きい方）、ATA34_2 p.470（FCC の tune inhibit）、p.586（A の閾値の距離は 200 NM と書く：乗員から見える FCOM の 150 NM を採る）。
- 作ったもの：
  - `B747.68.tune_model.lua` に ILS：入力（XXX.XX/YYY、周波数が出ていれば /YYY、小字の行の選択で手動、DELETE で FMC に戻す）、FMC の状態（PARK、STBY、A、M。FCC の禁止の間は保持し、その間の目的地の ILS の変化を印にする）、RW/ILS FREQ・CRS ERROR。
  - つなぎ（`B747.68.xt.fms.lua` の `update_ils`、1 秒ごと）：有効な経路の進入の滑走路の LOC（FMC の航法データ）、STBY・A の条件、浮揚の後 10 分は A にしない（目的地の滑走路を変えれば解く。空中開始では数えない）、FCC の ILS TUNE INHIBIT（`laminar/B747/autopilot/ils_tune_inhibit`）で保持。X-Plane の NAV 1・2 の周波数とコース、PFD の目盛（`laminar/B747/autopilot/ils_dots`：同調した ILS があれば 1。DSP-14：前は目的地の 50 NM 内だけ）、同調の文字の 1 文字目（A、M、P）、ILS TUNE INHIBITED - MCP（出来事の通知）、RW/ILS CRS ERROR（旗 40）、RW/ILS FREQ ERROR（通知の旗の表に無いので条件の通知）。
  - NAV RADIO の ILS の行（FCOM p.1306 の 4 つの形）。前は見出しが ILS - MLS で、T/D からの距離だけで PARK と自動を分け、手動は X-Plane の航法施設の一覧から探していた（`findILS`：消した）。
  - 自動操縦の `B747_fltmgmt_setILS`（目的地の 45 NM 内で X-Plane の飛行計画の幾何から ILS を探して同調）を消した。
- 推定：STBY の「半分」を出発地と目的地への直線距離で比べること、A は空中だけ、RW/ILS の ERROR は FMC が自動で同調する条件のときだけ比べること、コースの差 5°、PARK の間は受信機の周波数を変えず目盛だけ消すこと。作っていないもの：back course の進入（滑走路の LOC だけ）、MLS。
- GAP：FMC-31、CDU-16 の ILS の部分、DSP-14 はこれで解消。
- 試験：`tune_model_test.lua` 80 件（ILS の周波数の形、PARK・STBY・離陸後 10 分・A、FCC の禁止で保持と変化の印、入力と FREQ・CRS ERROR、DELETE、小字の行の選択）、`navrad_pages_test.lua` 46 件（ZZAA の ILS16R：地上は PARK、浮揚の後 10 分は小字の 109.50/157 と PARK、その後 A で NAV 1・2 とコース 157・ils_dots、手動の 110.30/120 と RW/ILS FREQ ERROR、DELETE、/150 で CRS ERROR、FCC の禁止で ILS TUNE INHIBITED - MCP と同調の保持）。全 146 本。X-Plane：起動し直した後（6:22）の s128（捨て）に続き、新しい s162 は 31/31：経路なしの ILS は PARK で PFD の目盛なし。RJBB→RJAA に ILS34L を入れて ACTIVATE と EXEC の 3 秒後に A の 111.90/337（NAV 1・2 は 11190、コース 337.3、ils_dots 1、同調の文字 A）、PFD に IYQ の DME 10.3 と LOC・G/S の目盛（写真）、POS REF は FMC POS (LOC-GPS L) と進入の RNP 0.50、ND の右下は LOCGPS と IRS (3)（写真）。手動の 110.30/120 で M と RW/ILS FREQ ERROR（NAV 1 も 11030）、CLR と DELETE で A の 111.90 に戻る、/330 で M の 111.90/330 と RW/ILS CRS ERROR の旗、DELETE で消えてコース 337 に戻る。APP で LOC を捕まえて ILS TUNE INHIBIT、110.30/120 は ILS TUNE INHIBITED - MCP で 111.90 の A のまま（写真で FCOM p.1306 の形）。初めの回（6:16）は通知の出ている間に DEL を押したので DELETE が入らず（実機どおり：シナリオの誤り）、後が連鎖して 10 件落ちた。期待値を直した s121 は 14/14（手動の入力は ILS TUNE INHIBITED - MCP）。Log.txt に Lua の誤りなし

## 89. 段 10d の実装（2026-11-01：flight complete）

- 資料：FCOM p.1236（エンジン停止の 30 秒後の flight complete で、有効な飛行計画と搭載データを消し、一部の飛行前のデータを既定に戻す）、p.1290・p.1294（FLT NO は flight complete で空白）、p.1307（PERF INIT の入力は電源断か飛行後のエンジン停止で消える）、p.1356–1357（REF NAV DATA の抑止は flight complete で消え、VOR/DME NAV は INHIBIT> に）、p.1369（GPS NAV は flight complete で INHIBIT> に）、p.1411（APPROACH REF の滑走路長）。FMSPG p.78（有効な経路はエンジン停止の flight complete で消える）、p.97（CRZ ALT）。ATA34_2 p.540（TAKEOFF REF のデータ）、p.569（FUEL USED は flight complete の後も残り、エンジン始動で消える）。
- 作ったもの：
  - `B747.68.route_model.lua` の `clear`：有効な経路（RTE 1 の中身）とその変更を消す。
  - つなぎ（`B747.68.xt.fms.lua` の `update_flight_complete`、毎フレーム）：空中を経た後、地上で 4 発とも N2 が ENG FAIL の速さの下（`laminar/B747/engines/inop`）になって 30 秒で一度だけ `B747_fms_flight_complete`：有効な経路（`B747_fmc_route_changed` で予測なども）、FLT NO、PERF INIT（GR WT・FUEL・ZFW・RESERVES・COST INDEX・CRZ ALT・CRZ CG・STEP SIZE）、TAKEOFF REF（フラップ、V 速度の選択、加速高度、推力を減らす高度、風、勾配、POS SHIFT、CG、トリム）、APPROACH REF のフラップと VREF、THRUST LIM の選択、VNAV のページの速さと制限、RTA、ENG OUT、REF NAV DATA の抑止、GPS NAV、RNP の入力。前は飛行の後も何も消えなかった。
- 推定：APPROACH REF・THRUST LIM・VNAV の選択・RTA・ENG OUT・RNP の入力を消すこと（FCOM の「一部の飛行前のデータを既定に」の中身は資料に無い）、エンジン停止の判定（ENG FAIL の速さ）、RTE 2 は残すこと、NAV RADIO の手動の同調は残すこと。X-Plane の飛行計画（ND の線）は残る（目的地の無い計画を X-Plane は受けない）。作っていないもの：IRS MONITOR のドリフト率（ATA34_2 p.682）。
- 試験：新しい `flight_complete_test.lua`（14 件：ZZAA で経路・PERF INIT・FLT NO・離陸のフラップ・抑止・GPS NAV・RNP を入れ、飛行の前はエンジンを止めても消えない、着陸後にエンジン 1 発が回る間は消えない、4 発が止まって 29 秒はまだ、31 秒で消える、その後の新しい経路は飛行が無いので残る）。全 147 本。X-Plane：新しい `s163_flight_complete`：新しい s163 は 29/29：RJAA 34L の進入路から、FMC に RJBB→RJAA（FLT NO TEST123、ILS34L：ILS は FMC の A で 111.90）、PERF INIT（ZFW 220、COST INDEX 100、CRZ ALT FL350）、NAVAID INHIBIT の NRE、GPS NAV INHIBIT を入れて自動着陸、止まって 4 発を CUTOFF（N2 は約 3 秒で ENG FAIL の速さの下）。その 22 秒後は経路が残り、34 秒後には RTE の ORIGIN と DEST が箱・FLT NO がダッシュ・COST INDEX と CRZ ALT が箱・NAVAID INHIBIT がダッシュ・GPS NAV が INHIBIT>・ILS は PARK で目盛なし。写真で PERF INIT の GR WT・ZFW・RESERVES・COST INDEX・CRZ ALT が箱、CRZ CG 20.0%・STEP SIZE ICAO（FUEL は計測の 85.9 のまま）。初めの 2 回（6:37、6:43）は 28/29：進入中に入れた CRZ ALT の UNABLE CRZ ALT が書き込み行に残り（通知の間は文字が入らない：実機どおり）NRE が入らなかった（シナリオの誤り）。Log.txt に Lua の誤りなし

## 90. 段 11 の段取りと 11a の実装（2026-11-01：燃料の監視と PROGRESS 2）

- 段取り（FMC-22、32、36、37、38；CDU-19）：
  - 11a：燃料の監視と PROGRESS 2（FMC-22、FMC-38）。
  - 11b：与圧系への着陸高度（FMC-37：進入を選べば滑走路の閾値の標高。今は目的地の空港の標高）。
  - 11c：メッセージの残り（FMC-32：まだ出していない alert・advisory の条件、進入中の 500 ft 未満の抑止：ATA34_2 p.635–636）。
  - 11d：FMC 2 台（FMC-36、CDU-19：master、故障、FMC LEFT・RIGHT、SINGLE FMC OPERATION、TIMEOUT - RESELECT、FAIL 灯、resync）。
  - 11e：代替航法（両 FMC の故障の ALTN NAV LEGS・PROGRESS・RADIO：FCOM p.1275、p.1421–1428）。
- 資料：FCOM p.1273–1274（燃料の監視：CALC は始動前は計量値、始動の正の燃料流量から切り離して流量で減る、投棄の間は計量値、MANUAL は入力が計量値に代わって流量で減る、流量が無効なら SENSED、FUEL USED は flight complete の後も残り次の始動で消える、FUEL DISAGREE-PROG 2、INSUFFICIENT FUEL）、p.1310（PERF INIT の FUEL：SENSED は入力できない、CALC は入力できる、MANUAL は TOTALIZER を空白にし CALCULATED の下に出る、消せるのは入力だけ）、p.1377–1382（PROGRESS 2：H/WIND・T/WIND、WIND は真方位、X/WIND、XTK ERROR、VTK ERROR は降下中だけ、TAS、FUEL USED、SAT、<USE（TOTALIZER：CALCULATED と FUEL USED を空白、PERF INIT は SENSED）と USE>（CALCULATED：TOTALIZER を空白）は 4,080 kg（9,000 lb）の差で、CALCULATED は全エンジン停止か投棄の後に計量値へ戻る）、p.1432（FUEL DISAGREE - PROG 2、INSUFFICIENT FUEL）。ATA34_2 p.569（FUEL USED）。
- 作ったもの：
  - `B747.68.fuel_model.lua`（新）：FMC の燃料の量（CALC・MANUAL・SENSED）、始動からの FUEL USED、TOTALIZER と CALCULATED、FUEL DISAGREE と USE の選択、INSUFFICIENT FUEL。
  - つなぎ（`B747.68.xt.fms.lua` の `update_fuel`、毎フレーム）：計量値（X-Plane の燃料の合計：推定）、燃料系の totaliser（`laminar/B747/fuel/totaliser`）、各エンジンの燃料流量、投棄（ノズルの弁）、予測の目的地の燃料と RESERVES。FMC の量（`perf_fuel_t`：PERF INIT と予測）、FUEL DISAGREE - PROG 2（旗 15）と INSUFFICIENT FUEL（旗 17、有効な経路のとき）。
  - PERF INIT の FUEL：FMC の量と CALC・MANUAL・SENSED、入力は MANUAL で流量で減る、SENSED では入力できない。前は CALC が計量値そのもので、MANUAL は減らなかった。
  - PROGRESS 2（FCOM p.1380 の形）：H/WIND・T/WIND と真方位の WIND と X/WIND、XTK ERROR（有効な経路が無ければ空白）と VTK ERROR（VNAV の降下の経路からの偏差、降下でなければ空白：`B747_fms_vtk`）、TAS・FUEL USED・SAT、各エンジンの FUEL USED、FUEL DISAGREE のときだけ <USE と USE>、TOTALIZER と CALCULATED。KT・NM・FT・C と TOT は小字。前は KT と NM が大字、VTK ERROR は「+**FT」の固定、FUEL USED は読み込みからの合計、二つの量はどちらも計量値、<USE と USE> はいつも出ていた。
- 推定：計量値は X-Plane の燃料の合計、USE の選択は全エンジン停止まで保ち（FUEL DISAGREE を出し直さない）、MANUAL を消すと計量値から CALC に戻る、燃料流量はいつも有効（乗員の選択なしに SENSED にならない）、FUEL DISAGREE はエンジンが回っている間だけ。
- 試験：新しい `fuel_model_test.lua`（24 件）と `fuel_pages_test.lua`（22 件：PERF INIT の CALC、始動と FUEL USED、風・TAS・SAT の行、漏れの FUEL DISAGREE と <USE、SENSED と入力の拒否、停止で CALC、MANUAL と TOTALIZER の空白）。`lnav_glue_test.lua` の PROGRESS 2 の確認を新しい形に、`rte_pages_test.lua` に燃料 40 t を置いた（燃料 0 に RESERVES 12.5 t を入れると INSUFFICIENT FUEL が正しく出て、後の入力を妨げた）。全 149 本。X-Plane：新しい `s164_fuel`：17/17（2026-11-01、再起動後の 1 便目の s128 は捨て 5/5）。PROGRESS 2/3 は H/WIND、KT・TOT が小字、FUEL USED TOT 0.1、TOTALIZER 86.5 と CALCULATED 86.4、<USE なし、PERF INIT は CALC。予備タンク 2・3（3.1 t ずつ）を外から空にすると、FUEL DISAGREE - PROG 2（旗 15）と <USE・USE>。<USE で CALCULATED と FUEL USED が空白（TOTALIZER 80.2 だけ）、PERF INIT は 80.2 SENSED。Log.txt に Lua の誤りなし。初回は主タンク 2 を外から 2 t にしたが、エンジンに送っている主タンクは燃料系の部（B747.25.xt.fuel）が毎フレーム書くので、外からの値が同じフレームで上書きされたとみられ、量が変わらず 6 件失敗した。使っていない予備タンクに変えた

## 91. 11b の実装（2026-11-01：与圧系への着陸高度）

- 資料：FCOM p.1400（到着ページの切替点：出発空港から 400 NM、有効な経路の半分、T/C の後で T/D の 2 分以内、T/D の後。その点を過ぎると FMC は着陸高度を与圧系に送り、進入を有効な経路に入れるまでは目的地空港の標高）、p.993–994（PFD の接地帯：目的地の滑走路か空港の着陸高度。400 NM か目的地までの半分までは出発の滑走路か空港の着陸高度）、p.608（FMC から来ず MAN でもなければ LANDING ALT と 2,000 ft）。ATA34_2 p.477（CPC は有効な飛行計画の着陸高度と垂直の情報を FMC から受ける）。
- 作ったもの：
  - `B747.68.ldgalt_model.lua`（新）：切替点（上の 4 つ。空中で有効な経路のときだけ見て、一度過ぎたら flight complete か新しい飛行まで保つ）と、その前後の値（前：出発滑走路の閾値の標高か出発空港の標高。後：有効な経路の進入の滑走路の閾値の標高か目的地空港の標高）。
  - つなぎ（`B747.68.xt.fms.lua` の `update_ldgalt`、1 秒ごと）：有効な経路の出発地と目的地（earth_aptmeta.dat の標高）、出発滑走路と進入の滑走路（CIFP の閾値の標高）、出発地からと目的地までの直線距離、VNAV の段階と T/D までの距離、対地速度。`laminar/B747/fms/landing_alt`（ft）と `landing_alt_valid`（値があれば 1）に書く（新設、FMS の init）。flight complete と新しい飛行で切替を戻す。
  - 与圧系（`B747.55.xt.press.lua`）は FMC の値を読むだけにした。前は `laminar/B747/fms/data` の fltdep・fltdst から X-Plane の空港の一覧の標高を自分で引き、自分の巡航・降下でも切り替えていた（巡航に入っただけで目的地に切り替わり、FCOM の「T/C の後で T/D の 2 分以内」と違った。進入の滑走路の標高も無かった）。与圧のモデルから切替（`FMC_SWITCH_NM`、`reached_cruise`）を外した。
- 推定：経路の半分は出発地からと目的地までの直線距離で比べる（§88 の ILS の待機と同じ）。切替は空中で有効な経路のときだけ見て、flight complete か新しい飛行まで保つ。要る空港が無ければ値なし（LANDING ALT）。滑走路で終わらない進入（周回進入）は空港の標高。
- 試験：新しい `ldgalt_model_test.lua`（19 件）と `ldgalt_glue_test.lua`（16 件：経路なしで値なし、ZZAA の 100 ft から DEPARTURES の RW34L で 98 ft、離陸の後もそのまま、半分を過ぎて ZZBB の 50 ft、進入 R09 で滑走路の 42 ft（試験の中で閾値を空港と別の値にした）、出発地の近くに戻っても保つ、flight complete で値なし、新しい経路で出発側に戻る）。`press_model_test.lua` と `air_module_test.lua` は FMC の値を入力にした（切替の試験は FMS 側へ移した。試験用の空港の一覧 `tests/air/data/aptmeta_test.dat` は消した）。全 151 本。X-Plane：新しい `s165_ldg_alt_dep` と `s166_ldg_alt_dest`：s165 12/12・s166 14/14（2026-11-01）。s165（RJAA 34L の地上）：経路なしは FMC の値なし・与圧系 2,000 ft・LANDING ALT、RJAA→RJBB の EXEC で 135 ft（与圧系も 135、LANDING ALT は消える）、DEPARTURES の 34L で 139 ft。s166（RJAA の西南西 40 NM の FL150）：経路なしは同じ、RJBB→RJAA の EXEC で 135 ft、ARRIVALS の ILS34L で 139 ft。EICAS の data block に LDG ALT 139 AUTO（画像で確認）。Log.txt に Lua の誤りなし
- GAP：FMC-37 は済。AIR-03 の残り（進入の滑走路の標高）も済。

## 92. 経路の点としての滑走路（2026-11-01）

- 資料：FMSPG p.82（表 4.1-1：航法データベースの点として RTE と LEGS に入れられるものに滑走路。例 RW30R）。
- 前は、出発地や目的地の滑走路の識別子（RW34L）を RTE・LEGS に入れると NOT IN DATA BASE だった（航法データの検索が、空港については terminal の点しか見ていなかった）。11c1 の X-Plane 試験（s167）で、進入の滑走路へ DIRECT TO しようとして分かった。
- 作ったもの：`B747.68.navdb.lua` の `find` が、経路の出発地と目的地（どの空港を見るかは前から推定）の滑走路を、CIFP の閾値の位置と標高で返す。手続きの滑走路の点と同じ形なので、経路の中の同じ滑走路と一致し、そこへの DIRECT TO になる。
- 試験：`navdb_test.lua`（空港を渡さなければ無い、渡せば ZZBB の RW09 を閾値の位置で、無い滑走路は無い）、`legs_pages_test.lua`（RW09 へ DIRECT TO、RW27 は NOT IN DATA BASE）。X-Plane：s167（2026-11-01）で、RJBB→RJAA の ILS34L の経路に LEGS の 1L から RW34L を入れて DIRECT TO にでき、現用点が RW34L（19 NM）になった。直す前の s167 の 1 回目は NOT IN DATA BASE で、現用点は GIINA のままだった。Log.txt に Lua の誤りなし

## 93. 11c の段取りと 11c1 の実装（2026-11-01：メッセージの表示の規則）

- 段取り（FMC-32 の残り。FCOM p.1430–1436 の一覧と今のコードを照らした。データリンク（405・570 だけ）は段 12、FMC 2 台の分（FMC L/R OUTPUT DATA LOSS、RESYNC、SINGLE FMC OPERATION、TIME OUT - RESELECT）は 11d）：
  - 11c1：表示の規則（ATA34_2 p.635–636：警告がどのメッセージより上、最新が上の積み重ね、進入の段階で 500 ft AGL 未満の抑止）。Boeing に無い DESTINATION NOT SET を FMC の警告から外す。
  - 11c2：VNAV と RTA の警告（CHECK ALT TGT、DESCENT PATH DELETED、LIMIT ALT FLXXX、UNABLE NEXT ALT、UNABLE FLXXX AT RTA FIX）。
  - 11c3：航法の警告（IRS POS/ORIGIN DISAGREE、VERIFY POSITION、PURGE UPDATES - POS 2、NAV INVALID-TUNE AAA、SET CLOCK TO UTC TIME）。
  - 11c4：advisory の残り（ARR N/A FOR RUNWAY、RUNWAY N/A FOR SID、VERIFY TAIL NUMBER、STANDBY ONE の確かめ）。
- 資料：ATA34_2 p.635（警告は advisory より上で、書き込み行のどのメッセージより上。警告の表示中に新しい警告が来れば新しい方が出て、前のは積み重ねに入る。CLR で上から順に消える。進入中、有効な経路に滑走路があれば 500 ft AGL 未満では全部の警告の表示を抑え、その間の警告は flight complete か 1,000 ft AGL を上へ越えたときに出す）、p.636（入力の誤りの advisory は基本の advisory より上）、FCOM p.1236（進入の段階：手続きの最初の点を通過、または滑走路が現用点で残り 25 NM 未満）、p.1430（CLR か条件が直ると次のメッセージ）。
- 作ったもの：
  - CDU のモデル（`B747.68.cdu_model.lua`）：表示の順を、FMC の警告（最新が上）、その CDU の入力のメッセージ（最新が上）、FMC の advisory（最新が上）にした。CLR はいちばん上を消す。出来事のメッセージがもう一度来れば上に戻る。`fmc_inhibit` で警告を抑える（書き込み行に出さず、>FMC MESSAGE と MSG 灯も警告の分は出さない。advisory と入力のメッセージは出る）。前は入力のメッセージが FMC の警告より上で、どの種類も古い順だった。
  - つなぎ（`B747.68.xt.fms.lua` の `update_msg_inhibit`、毎フレーム）：空中で電波高度 500 ft 未満、有効な経路に滑走路（進入の滑走路か滑走路の点）があり、進入の段階なら抑え、1,000 ft を上へ越えるか flight complete で戻す（新しい飛行でも戻す）。`B744.createfms.lua` に `B747_cdu_fmc_inhibit`。
  - DESTINATION NOT SET を FMC の出来事のメッセージから外した（旗は立たない。ACARS のページが自分の入力のメッセージとして使う同じ文字は、段 12 で見直す）。
- 推定：入力のメッセージと advisory の積み重ねは警告と同じ（最新が上）。経路の滑走路は進入の滑走路か滑走路の点。advisory は今まで通り全部の CDU に出す（ATA34_2 p.636 の「条件の CDU だけ」は、NOT ON INTERCEPT HEADING のように CDU に結びつかない advisory の扱いが分からないので見送り）。
- 試験：`cdu_model_test.lua`（91 件：警告が入力のメッセージより上、入力のメッセージが advisory より上、積み重ね、出来事の再送、抑止の間の advisory、解除で最新の警告）、新しい `fmc_msg_inhibit_test.lua`（14 件：離陸の後は抑えない、進入の最初の点の通過のあと 500 ft 未満で抑え FMC MESSAGE も出ない、入力のメッセージは出る、800 ft ではまだ、1,000 ft を越えて出る、次の進入でまた抑え、着陸の後も、flight complete で出る）。全 152 本。X-Plane：新しい `s167_fmc_msg_inhibit`：15/15（2026-11-01、再起動後の 2 便目）。経路なしでは警告（UNABLE NEXT ALT の旗）が書き込み行と FMC MESSAGE に出る。V/S で 480 ft 未満に下げ、RJBB→RJAA の ILS34L で RW34L へ DIRECT TO（19 NM：進入の段階）した後は、警告も FMC MESSAGE も出ない（画像でも書き込み行は空）。FLCH で 1,000 ft を越えると出る。LIMIT ALT FLXXX の旗が新しく来ると上に出て、CLR で UNABLE NEXT ALT に戻る（積み重ね）。Log.txt に Lua の誤りなし。1〜3 回目は試験の組み方の誤りで 500 ft 未満にならず、抑止の 3 件が成り立たなかった（空中開始の後に 800 ft 近くまで上がる、V/S の目標の dataref の取り違え）。積み重ねと 1,000 ft の解除はその 3 回とも通った

## 94. 11c2a の実装（2026-11-01：予測からの VNAV と RTA の警告）

- 11c2 を 11c2a（予測から決まる 4 件）と 11c2b（CHECK ALT TGT：VNAV の engage の振る舞いも変わる）に分けた。
- 資料：FCOM p.1431（DESCENT PATH DELETED）、p.1433（LIMIT ALT FLXXX）、p.1434（UNABLE FLXXX AT RTA FIX、UNABLE NEXT ALT）、p.1255（上昇の形が制限に届かないと UNABLE NEXT ALT）、FMSPG p.117（次の制限に届かないとき。図では 18000A に ECON で届かず、その前の 6000 を過ぎると出る）、ATA34_2 p.611（最大高度：上昇の速さと巡航の速さが速度の範囲に入る高度）、FMSPG p.131（MAX ALT より上の CRZ ALT は MAX ALT FLXXX のまま入る）。
- 作ったもの（`B747.68.xt.fms.lua`）：
  - UNABLE NEXT ALT（旗 47）：予測のたびに、T/C より前の次の AT・AT OR ABOVE・窓の制限（AT OR BELOW は低くて届かないことが無いので見ない）の点の予測の高度が、その高度（窓は下）より低いか。VNAV が engage で上昇の段階のとき出す（旗は値が変わったときだけ書く）。
  - LIMIT ALT FLXXX：1 秒ごとに、VNAV が engage で CRZ ALT が最大高度（CRZ のページの MAX、ENG OUT 中は片発の最大）より上なら、その FL で出す。
  - UNABLE FLXXX AT RTA FIX：RTA の速さを求めたあと、RTA の点の到着が許容（±30 秒。AFTER・BEFORE は向きの片側だけ）の内で、その点の高度制限（窓は下）より予測の通過高度が低いとき、その制限の FL で出す。
  - DESCENT PATH DELETED（旗 6、出来事）：予測のたびに、VNAV が engage で、前の予測に降下の経路があり、今度は経路も E/D も無い（経路を決める制限が全部消えた）とき。進入の滑走路を過ぎた後と着陸復行の後は出さない。
  - 高度の入る文字のメッセージは、数字が変われば古い文字を消してから新しい文字を出す（`B747_cdu_fmc_condition`）。
- 推定：低いとみなす差 10 ft。RTA の点の FLXXX はその点の制限（無ければ出さない）。VNAV の limit altitude は最大高度とした（資料に定義が無い。VNAV の上昇を最大高度で止めることはしていない）。DESCENT PATH DELETED を出さない場合（滑走路の後、着陸復行）。
- 試験：新しい `vnav_msgs_test.lua`（20 件：ALPHA に FL250A で UNABLE NEXT ALT と CDU、VNAV を切ると消え入れると出る、ALPHA に予測の時刻で RTA を入れると UNABLE FL250 AT RTA FIX が上に出て時刻を消すと消える、8000A で消える、CLB のページの CRZ ALT FL450 で LIMIT ALT FL411、VNAV を切ると下の MAX ALT が見える、FL350 で消える、BOKJO の 10000 だけで作った経路をその制限ごと消すと DESCENT PATH DELETED、CLR で消える）。全 153 本。X-Plane：新しい `s168_vnav_msgs`：13/13（2026-11-01）。XAC に FL330A で VNAV を engage すると、すぐ UNABLE NEXT ALT の旗が立ち、書き込み行と FMC MESSAGE に出た。CLB のページで CRZ ALT を FL450 にすると LIMIT ALT FL391（画像：CLB のページの CRZ ALT FL450 と書き込み行）、FL350 に戻すと消えた。XAC の制限を消すと UNABLE NEXT ALT は消え、BOKJO の 10000 を入れてから消すと DESCENT PATH DELETED が出た（VNAV は engage のまま）。Log.txt に Lua の誤りなし

## 95. 11c2b の実装（2026-11-01：CHECK ALT TGT）

- 資料：FCOM p.1431（CHECK ALT TGT：VNAV が、機体が MCP 高度と FMC の目標高度の間にいるときに作動すると、水平を保つ）、FMSPG（同じ：VNAV holds level flight）。FCOM p.645 の注（VNAV のプロファイルと MCP 高度がぶつかれば水平で VNAV ALT）は engage 中の話で、今まで通り AFDS の VNAV ALT が受け持つ。
- 作ったもの：VNAV のモデル（`B747.68.vnav_model.lua`）が、engage した時（engage の立ち上がり）に機体が MCP 高度と FMC の目標高度（その時の FMC altitude）の間にいれば（両方とも 100 ft 以上離れて反対側）、その時の高度で VNAV PTH の水平（A/T は速度）にして `check_alt` を出す。MCP 高度か FMC の目標が片側にそろえば、ふつうのプロファイルに戻る。engage 中に MCP 高度が反対側へ回っても出さない（作動した時だけ）。つなぎ（`update_vnav`）が CHECK ALT TGT の旗（4）を書く（値が変わった時だけ）。前は、間にいても上昇（降下）を続けた（AFDS の捕捉は離れていく向きでは働かない）。
- 推定：間とみなす 100 ft、水平の高度（engage した時の高度）、戻る条件（片側にそろった時）。
- 試験：`vnav_model_test.lua`（184 件：engage しなければ出ない、間で engage すると水平と CHECK ALT TGT、engage の高度を保つ、MCP 高度を上にすると上昇に戻る、engage 中に下へ戻しても出ない、両方上なら上昇、帯の内なら間でない）、`vnav_msgs_test.lua`（26 件：MCP 高度 1,000 ft で engage すると旗と VNAV PTH の 2,000 ft と CDU、20,000 ft で消える。試験の初めの MCP 高度を 36,000 ft にした：模擬の既定の 0 だと機体の下で、engage がいつも CHECK ALT TGT になる）。全 153 本。X-Plane：新しい `s169_check_alt_tgt`：13/14（2026-11-01、再起動から 6 便目）。MCP 高度 8,000 ft で VNAV を engage すると、すぐ CHECK ALT TGT の旗と書き込み行、FMC の VNAV は PTH、FMA は VNAV PTH。保つ高度は engage した時の 10,425 ft で、20 秒後も同じ。MCP 高度を 20,000 ft にすると旗は消え、VNAV SPD で上がり始めた。Log.txt に Lua の誤りなし。1 件の失敗は試験の判定：engage の時、機体は空中開始の後の ALT HOLD の揺れで −1,120 fpm で降りていて、10,264 ft で止まってから保つ高度へ戻る途中だった（20 秒後は +358 fpm で、±300 を外れた）。シナリオは、水平になってから engage するように直した（直した形は次の X-Plane で回す）

## 96. 11c3 の実装（2026-11-01：航法の警告）

- 資料：FCOM p.1433（IRS POS/ORIGIN DISAGREE：有効な IRS の位置が有効な出発空港と違う。NAV INVALID-TUNE AAA：進入の手続きに要る航法施設の電波が受からない。PURGE UPDATES - POS 2：FMC の位置が誤っていて、DME の妥当性の検査で電波が捨てられる）、p.1434（SET CLOCK TO UTC TIME：GPS の UTC が機長の時計（機長のが故障なら副操縦士の）と 12 秒より多く違う）、p.1435（VERIFY POSITION：更新に使う電波・GPS の位置と FMC の位置が違う、または左右の FMC の位置が違う）、ATA34_2 p.602（IRU 2 台の位置の差が変わる閾値を超えると VERIFY POSITION）。
- 作ったもの：
  - 時計（`B747.60.clock_model.lua`、`B747.60.xt.fltInst03.lua`）：時計の UTC から X-Plane（GPS）の UTC を引いた秒と、動いているか（main hot battery bus）を、新設の `fltInst/<席>/clock_utc_offset`・`clock_valid`（init `B747.60.fltInst`）に出す。
  - つなぎ（`B747.68.xt.fms.lua` の `update_nav_msgs`、1 秒ごと）：SET CLOCK TO UTC TIME（旗 41：GPS が有効で、機長の時計（動いていなければ副操縦士の）が 12 秒より多くずれる）、IRS POS/ORIGIN DISAGREE（旗 23：地上で IRS の位置が有効で、有効な経路の出発地から 10 NM より離れる）、NAV INVALID-TUNE AAA（進入中（その手続きの点を通過した後）に、進入の脚の推奨航法施設の VOR を、VOR L・R のどちらも受けない状態が 5 秒続く）。
  - VERIFY POSITION と PURGE UPDATES - POS 2 は作らない：この機体の FMC の位置は X-Plane の位置そのもので、更新に使う装置と食い違うことが無い（IRS の流れや位置の誤差を模していない）。
- 推定：10 NM（資料に無い）、IRS の位置は FMC の混ぜた位置（`B747_fms_irs_pos`）、5 秒、進入の VOR は脚の推奨航法施設（LOC と NDB は見ない）。
- 試験：新しい `nav_msgs_test.lua`（15 件：出発地から 18 NM で IRS POS/ORIGIN DISAGREE と CDU、3 NM で消える、機長の時計 5 秒は出ず 20 秒で出る、機長の時計が止まれば副操縦士の 3 秒で消え 30 秒で出る、GPS が無ければ出ない、進入中に VOR が受かれば出ず、受からなくて 4 秒ではまだ、5 秒で NAV INVALID-TUNE、VOR R で受かると消える。試験の航法データに VOR の進入が無いので、R09 の脚に ZZV を推奨航法施設として置いた）、`clock_test.lua`（70 件：ずれと有効の出力）。全 154 本。X-Plane：新しい `s170_nav_msgs_gnd`・`s171_nav_invalid_tune`：s170 11/11・s171 8/8（2026-11-01、再起動の後）。s170（RJAA 34L の地上）：出発地 RJBB の経路を EXEC すると 0.6 秒で IRS POS/ORIGIN DISAGREE（書き込み行も）、出発地を RJAA に入れ直して EXEC すると消えた。機長の時計の SET を HLD に 20 秒置いて RUN に戻すと、ずれ −21.7 秒で SET CLOCK TO UTC TIME。s171（VOR16R の KONAN の手前）：LNAV で KONAN を過ぎ（46 秒）TENAG が現用点、NRE を受けている間は出ず、VOR L・R を XAC にすると 5.9 秒で NAV INVALID-TUNE NRE、VOR L の手動を消すと消えた。Log.txt に Lua の誤りなし。s170 の 1 回目は 10/11：有効な経路の出発地を変えた後に 6R（有効な経路では PERF INIT>）を押したので変更が EXEC されず、IRS POS/ORIGIN DISAGREE が消えなかった（試験の手順の誤り。EXEC を RTE のページで押すように直した）

## 97. 11c4 の実装（2026-11-01：手続きの advisory）

- 資料：FCOM p.1435（ARR N/A FOR RUNWAY：選んだ滑走路・進入が選んだ到着と合わない。RUNWAY N/A FOR SID：滑走路が SID と合わない）、FMSPG p.79（RTE の 2L RUNWAY が 2 ページ目の 1L の SID と合わなければ、書き込み行に RUNWAY N/A FOR SID が出て入力は捨てられる）。残りの advisory のうち、VERIFY TAIL NUMBER（FCOM p.1436）は ATC LOGON/STATUS のページ（データリンク：FCOM p.757 の TAIL NO）の話なので段 12 で、STANDBY ONE は航法データを読む間に出している（段 4）。
- 作ったもの：
  - RUNWAY N/A FOR SID（`B747.68.route_model.lua` の `set_runway`）：SID が選ばれていれば、その SID の滑走路でなければ入力を捨ててこのメッセージ。
  - ARR N/A FOR RUNWAY（`activepages/B744.fms.pages.deparr.lua` の ARRIVALS）：STAR と進入がそろうとき、STAR がその進入の滑走路を使わなければ（STAR の滑走路の transition に無い。ALL なら合う）、選んだ方を捨ててこのメッセージ。進入の滑走路は脚の滑走路の点、無ければ進入の名前から（VOR16R（D16R）は進入復行点が VOR の NRE で、脚に滑走路が無い）。滑走路の無い進入（周回）はどの STAR とも合うとした（推定）。
- 試験：新しい `proc_msgs_test.lua`（YANKE1（16R だけ）で RTE の RUNWAY 34L が RUNWAY N/A FOR SID で捨てられ 16R は入る、ILS16R の後の BRAVO1（34L だけ）と BRAVO1 の後の ILS16R が ARR N/A FOR RUNWAY で捨てられ、ALPHA1（全部の滑走路）は入る）。試験の航法データの ZZAA に YANKE1 と BRAVO1 を足し、手続きの一覧を見る 3 本（`deparr_pages_test.lua`・`navdb_test.lua`・`proc_model_test.lua`）の期待を合わせた。全 155 本。X-Plane：新しい `s172_proc_msgs`：9/9（2026-11-01、3 回目）。DEPARTURES の AKAGI4 に RTE の RUNWAY 34R を入れると RUNWAY N/A FOR SID で RUNWAY は空のまま、34L は RW34L と入った。ARRIVALS で VOR16R の後に BINKSA（34L だけ）を選ぶと ARR N/A FOR RUNWAY で BINKSA は選ばれない（画像）。Log.txt に Lua の誤りなし。1 回目は 5/9：捨てられた 34R が書き込み行に残り（CLR 1 回ではメッセージだけ消える）、後の入力が崩れた（試験の手順の誤り。CLR を増やした）。2 回目は 7/9：VOR16R の脚は滑走路でなく NRE（進入復行点）で終わるので、滑走路なしでどの STAR とも合うと判断していた。進入の名前から滑走路を取るように直した

## 98. 11d の段取りと 11d1 の実装（2026-11-01：FMC 2 台の故障と CDU の接続）

- 段取り：
  - 11d1：FMC の故障と電源、CDU の接続・切断（MENU と TIMEOUT - RESELECT、<FMC、NAV ソース選択）、SINGLE FMC OPERATION、EICAS の FMC LEFT・RIGHT。
  - 11d2：master FMC（故障した FMC の LNAV・VNAV・A/T の喪失、FMC の選択を回したときの A/T の解除：FCOM p.1215、故障した FMC を選んだ ND の地図の喪失：p.1275）。
  - 11d3：resync（RESYNCING OTHER FMC、RESYNC FAIL - SINGLE FMC：p.1434、故障の後に有効な経路や性能の値が消えうる：p.1275）。
- 資料：FCOM p.1275（FMC 1 台の故障：CDU に MENU と TIMEOUT - RESELECT が出れば FMC はつながっていない、MENU の <FMC でつなぐ。地上ではどちらの故障でも SINGLE FMC OPERATION。飛行中は FMC の選択で選んでいない方の故障で SINGLE FMC OPERATION は 1 台の CDU だけ、故障した側の CDU は TIMEOUT - RESELECT。選んでいる方の故障では両 CDU に TIMEOUT - RESELECT、FMC の選択を動いている方に回すと CDU から使え、FMC のページを出すと SINGLE FMC OPERATION。FMC LEFT・RIGHT は遅れて出る。両方の故障では MENU の 1 行目に <FMC が無い）、p.1422（FMC の故障で CDU は MENU と TIMEOUT-RESELECT、NAV ソース選択を動いている FMC に回すと CDU と ND が戻る）、p.1429（EICAS の FMC LEFT・RIGHT：advisory）、p.1434（SINGLE FMC OPERATION：alert）、p.800・p.804（左 FMC は機長側の transfer bus か APU の standby bus、右 FMC は副操縦士側の transfer bus）。ATA34_2 p.456（左と中央の CDU は左 FMC、右の CDU は右 FMC、NAV ソース選択を反対側の FMC にするとその FMC）、p.496（NAV ソース選択が CDU の使う FMC も選ぶ）、p.629（故障すると CDU は MENU で <FMC が消え、FAIL 灯と TIMEOUT - RESELECT、EICAS に FMC LEFT・RIGHT）。
- 作ったもの：
  - `B747.68.fmc_link_model.lua`（新）：FMC 2 台の動作（電源と故障）、各 CDU のつながる FMC、切れた CDU、<FMC のつなぎ先（地上は動いている方、飛行中は選択した FMC が動いていればそれ）、NAV ソース選択を動いている FMC に回すとつながる、飛行中に選択した FMC が落ちると全部の CDU が切れる、SINGLE FMC OPERATION、FMC LEFT・RIGHT の遅れ（5 秒）。
  - つなぎ（`B747.68.xt.fms.lua` の `update_fmc_link`、毎フレーム）：母線（`electrical/bus/xfr_capt`・`stby_apu`・`xfr_fo`）、故障の注入（新設の `laminar/B747/fms/fail[0]`・`[1]`）、CDU の電源、NAV ソース選択、FMC の選択。新設の `fms/fmc_ok`（2 台）と `fms/cdu_link`（左・中央・右の CDU の FMC：0 なし、1 左、2 右）を出す。SINGLE FMC OPERATION（旗 42）、EICAS の FMC LEFT（[144]）・FMC RIGHT（[146]）。>FMC MESSAGE は FMC が無ければ出さない。
  - CDU（`B744.createfms.lua`）：切れた CDU は MENU と TIMEOUT - RESELECT（その FMC のページを <FMC のために覚える）、FMC の機能キーと EXEC は何もしない、FMC のメッセージは出さず自分の入力のメッセージだけ。MENU の 1 行目は、つながっていれば <FMC <ACT>、つなげる FMC があれば <FMC だけ、無ければ空白。<FMC はつないでから前の FMC のページへ。
- 推定：中央の CDU は左 FMC が落ちている間は右 FMC、電源の無い CDU は FMC と電源がそろえば自分の FMC に自然につながる（電源投入は今までどおり MENU で、TIMEOUT - RESELECT は出さない）、SINGLE FMC OPERATION はつながっている全部の CDU に出す（FCOM は飛行中は 1 台）、EICAS の遅れ 5 秒、NAV ソース選択が CDU の位置なら CDU のいつもの FMC。CDU の FAIL 灯は 3D に無いので作らない。
- 試験：新しい `fmc_link_model_test.lua`（59 件）と `fmc_link_glue_test.lua`（51 件：地上で左 FMC の故障、左と中央の CDU は MENU と TIMEOUT - RESELECT、<FMC に <ACT> なし、INIT REF・LEGS は効かない、右の CDU に SINGLE FMC OPERATION と >FMC MESSAGE、5 秒で FMC LEFT、<FMC で右 FMC の IDENT、左 FMC を戻すとメッセージが消え CDU はそのまま、機長の NAV ソース選択で左 FMC、飛行中の左（選択）FMC の故障で 3 台とも切れ <FMC が無く、FMC の選択を R にすると <FMC、電源を落として入れ直すと MENU でつながり TIMEOUT - RESELECT なし）。CDU を使う既存の 36 本に、CDU の電源と並べて FMC の母線の電源を入れた（入れないと FMC が動かず CDU が切れる）。全 157 本。X-Plane：新しい `s173_fmc_fail`：23/23（2026-11-01）。RJAA 34L の地上で左 FMC を故障させると、1 秒で左と中央の CDU が MENU と TIMEOUT - RESELECT、左の MENU は <ACT> の無い <FMC、右の CDU は IDENT のまま SINGLE FMC OPERATION、>FMC MESSAGE が出た（画像）。INIT REF では MENU のまま。故障から 5.3 秒で EICAS に FMC LEFT（画像）。CLR と <FMC で右 FMC の IDENT と SINGLE FMC OPERATION（画像）。左 FMC を戻すと FMC LEFT が消えて CDU は右 FMC のまま、機長の NAV ソース選択を FMC R から FMC L に回すと左 FMC につながった。Log.txt に Lua の誤りなし。

## 99. 11d2 の段取りと 11d2a の実装（2026-11-01：master FMC の故障の AFDS・A/T・無線）

- 段取り：11d2 を 11d2a（AFDS の LNAV・VNAV、A/T、無線の自動同調、FMC LEFT・RIGHT の遅れの訂正）と 11d2b（ND の VTK・MAP の旗と現用点の ETA・DTG。パネルの変更を含む）に分けた。
- 資料：
  - ATA22 p.202・p.206（三つの FCC は、FMC の選択で選んだ FMC の LNAV・VNAV を使う。選んだ方が落ちても、もう一方には切り替えない）、p.382（master FMC が LNAV・VNAV の間に落ちると、作動中のモードに線と AUTOPILOT の caution）、p.338（VNAV で MCP 高度にいて master FMC が落ちると ALT HOLD）。
  - ATA34_2 p.633（master の左 FMC の故障の図）：両 PFD のロールとピッチの FMA がモード故障、A/T の FMA が空白、>A/T DISC、F/D バーが消える、VNAV は MCP 高度の近くなら ALT HOLD。FMC の選択を R にすると、LNAV と VNAV が普通に戻り、F/D バーも戻る。A/T DISC は残り、A/T のスイッチを切って入れると戻る。
  - ATA34_2 p.629（FMC の故障で、A/T が engage なら >AUTOTHROT DISC）、p.496（FMC の選択が、FCC の操舵・A/T・無線の同調・EEC の調整の FMC を選ぶ）。FCOM p.666（両方の FMC が落ちると A/T は切れて戻らない。FMC の選択を回すと切れるが、戻せる）、p.1215（同じ）。
  - ATA34_1 p.332・p.350（master FMC が落ちると VOR・ILS は最後の周波数のまま、選択を回すと自動同調が戻る）。
  - LH3460 p.114・p.116（FMC LEFT・RIGHT の advisory は、FMC が内部の故障を見つけて 30 秒後）。
- 作ったもの：
  - AFDS（`B747.70.afds_model.lua` の `mode_failures`）：`inp.fmc_ok`（FMC の選択で選んだ FMC が動いている）が偽の間、LNAV と VNAV はモード故障（その時のバンクとピッチを保ち、FMA の線、AUTOPILOT、F/D バーを消す：段 5c の仕組み）。センサーの故障（新しいモードまで残る）と違い、FMC が戻れば新しいモードを選ばなくても LNAV と VNAV に戻る。VNAV で MCP 高度から 100 ft 内なら ALT HOLD。間にセンサーも落ちれば、新しいモードまで残る。
  - つなぎ（`B747.70.xt.autopilot.lua`）：`fms/fmc_ok` と FMC の選択から master FMC の動作（`fmc_master_ok`）。LNAV の捕捉と、arm からの VNAV の engage は master FMC が動いているときだけ。
  - A/T：連動条件に master FMC の動作を足した。master FMC の故障で切れて AUTOTHROT DISC、FMC が戻っても ARM スイッチを切って入れるまで engage しない。FMC の選択を回すと 1 フレームだけ条件を外して切る（すぐ戻せる）。
  - 無線：master FMC が動いていない間は自動同調（`update_tuning`）を止め、周波数を保つ。
  - FMC LEFT・RIGHT の遅れを、5 秒（11d1 の推定）から 30 秒（LH3460 p.116）に直した。
- 推定：MCP 高度の「近く」を 100 ft にした。A/T の ARM スイッチの入れ直しは、故障の時に engage していなくても要るとした。
- 作らないもの：EEC の調整（PW は資料に無い）、FCC の自前の最小・最大速度（FCOM p.675）。PFD の NO V SPD・SPD LIM は両方の故障（11e）で扱う。
- 試験：`afds_model_test.lua`（+11 件：LNAV と VNAV の故障と戻り、バンクとピッチの保持、HDG SEL で解ける、MCP 高度で ALT HOLD、間に IRU が落ちれば残る）、`afds_glue_test.lua`（+12 件：LNAV の故障と R での戻り、A/T の切断と ARM の入れ直し、選択を回しての切断）。自動操縦のモジュールだけを読む `afds_glue_test.lua` に FMC の動作を入れた。`fmc_link_model_test.lua`・`fmc_link_glue_test.lua`・`s173_fmc_fail` の遅れを 30 秒に。全 157 本。X-Plane：新しい `s174_fmc_master_fail`：26/26（2026-11-01、2 回目。1 回目も 26/26 だったが、視点が ND で PFD が写っていなかったので撮り直した）。成田の北の 3,100 ft で、LNAV・VNAV SPD・A/T（THR REF）の上昇中に左 FMC を故障させると、1 秒で LNAV と VNAV SPD に琥珀の線、A/T の FMA が空白、F/D バーが消え（画像）、>AUTOPILOT と >AUTOTHROT DISC、3 台の CDU に TIMEOUT - RESELECT、右の MENU に <FMC なし。故障から約 32 秒で FMC LEFT。FMC の選択を R にすると線が消えて LNAV と VNAV SPD のまま、A/T は切れたまま。ARM スイッチを切って入れると THR REF で戻り、F/D バーも戻った（画像）。右の CDU の <FMC で右 FMC につながり SINGLE FMC OPERATION。Log.txt に Lua の誤りなし。

## 100. 11d2b の実装（2026-11-01：FMC の故障の ND の旗）

- 資料：
  - ATA34_2 p.630（FMC の故障で、ND の VTK 旗はすぐ、MAP 旗は 30 秒後）。
  - ATA34_2 p.633（master の左 FMC の故障の図）：機長の ND（NAV ソース選択が左 FMC）に VTK 旗、現用点の ETA と DTG が消える。再同期に 35 秒で失敗すると MAP 旗。NAV ソース選択を右 FMC にすると普通の表示。
  - LH3460 p.114（ND の MAP・VTK 旗は 30 秒後）、FCOM p.1422（NAV ソース選択を動いている FMC に回すと CDU と ND が戻る）、p.1033–1034（MAP 旗は MAP と PLAN、VTK は MAP モード）。
- 作ったもの：
  - ND のモデル（`B747.60.nd_model.lua`）：各側の入力に `fmc_ok`（NAV ソース選択で選んだ FMC が動いている。CDU の位置なら真）。落ちていれば、VTK 旗はすぐ（MAP モード）、MAP 旗は 30 秒後（MAP と PLAN）、現用点の ETA と距離（`wpt_data`）を消す。動いている FMC に回すとすぐ戻る。
  - つなぎ（`B747.60.xt.displays.lua`）：`fms/fmc_ok` と NAV ソース選択から各側の `fmc_ok`。新設の `nd/capt/wpt_data`・`nd/fo/wpt_data`（init `B747.60.fltInst`）。
  - パネル（カスタム acf）：両 ND の現用点の ETA と距離を、`wpt_data` の入れ子のグループに入れた（ACF_DIFF.md §5）。
  - FMS は `update_fmc_link` を systems の warm-up の前から回す（読み込みの直後から `fmc_ok` を出して、旗が一瞬出ないように）。
- 推定：現用点の ETA と距離は、FMC の位置（IRU の NAV）が無いときも消す。MAP 旗の 30 秒は、再同期を作るまで（11d3）は故障からの時間。
- 作らないもの：MAP 旗の後の経路や点の消去（X-Plane の地図の層は気象レーダーや TFC と一緒なので、FMC の分だけは消せない）。両方の故障の CDU の地図（11e）。
- 試験：`nd_model_test.lua`（+9 件）、`display_module_test.lua`（+9 件。FMC の動作を入れた）。全 157 本。X-Plane：新しい `s175_nd_fmc_fail`：17/17（2026-11-01、X-Plane を立ち上げ直した後の 2 便目。1 便目の s128 は捨て、5/5）。成田の北の 3,000 ft で XAC へ DIRECT の後、機長の ND（MAP、FMC L）の右上に XAC・0116.7Z・86.9NM。左 FMC を故障させると、1 秒で VTK 旗が出て ETA と距離が消え（XAC は残る）、副操縦士の ND（FMC R）はそのまま。故障から約 32 秒で MAP 旗（画像）。機長の NAV ソース選択を FMC R にすると、旗が消えて ETA と距離が戻り（0116.2Z・89.2NM）、左の CDU も右 FMC につながった。Log.txt に Lua とパネルの誤りなし。

## 101. 11d3 の実装（2026-11-01：FMC の再同期）

- 資料：
  - FCOM p.1277（再同期は約 15 秒。その間、その FMC の CDU は故障の表示で、もう一方の CDU に RESYNCHING OTHER FMC。キーを押さない）。
  - FCOM p.1433（RESYNC FAIL - SINGLE FMC：再同期が失敗して FMC が 1 台止まった）、p.1434（RESYNCING OTHER FMC：同期中。どちらも alert の一覧）。
  - ATA34_2 p.632（再同期は、二つの FMC の計算が合わないとき master が他方を、または FMC が内部の試験に落ちて再起動したとき。内部の試験に落ちると出力のバスが止まり、再起動の後に再同期が要る。slave が master を再同期できる。約 15 秒、その間 master は普通に働く。master の再同期で LNAV・VNAV・A/T が engage なら、EICAS・PFD・ND は master を失った表示）。
  - ATA34_2 p.633（master の左 FMC が内部の試験に落ちた図：左の CDU は表示が止まり、右の CDU は SINGLE FMC OPERATION の後 RESYNCING OTHER FMC。35 秒で再同期に失敗すると、左の CDU は MENU と FAIL 灯、>FMC-L、MAP 旗）。
- 作ったもの：
  - `B747.68.fmc_link_model.lua`：FMC の状態を「動作」「再同期」「故障」に分けた。故障の注入（`laminar/B747/fms/fail`）に 2（内部の試験の失敗：再同期して戻る）と 3（再同期の失敗：35 秒で止まる）を足した。再同期の間、その FMC の出力は止まる（`fmc_ok` 0：AFDS・A/T・ND は 11d2 の故障の扱い）。つながっている CDU は切れずに表示が止まる。もう一方の FMC が動いていれば 15 秒で戻る。3 は 35 秒で故障になり、その CDU は MENU と TIMEOUT - RESELECT（飛行中の master なら全部の CDU：FCOM p.1275）。
  - メッセージ：RESYNCING OTHER FMC（旗 36、再同期の 2 フレーム目から：SINGLE FMC OPERATION の後に出す）、RESYNC FAIL - SINGLE FMC（旗 35、再同期に失敗して止まっている間）。
  - CDU（`B744.createfms.lua`）：再同期中の FMC の CDU は描き直さず（表示が止まる）、キーを受けない。
- 推定：再同期は、もう一方の FMC が動いていないと待つ。電源の回復や故障（1）からの戻りでは再同期しない（資料は内部の試験の後の再起動と、計算の食い違いだけを書く）。FMC LEFT・RIGHT は再同期の間も 30 秒で出る（15 秒で戻る 2 では出ない）。
- 試験：`fmc_link_model_test.lua`（+25 件）、`fmc_link_glue_test.lua`（+18 件）。全 157 本。X-Plane：新しい `s176_fmc_resync`：29/29（2026-11-01、立ち上げ直した後の 3 便目）。成田の北の 3,100 ft で、LNAV・VNAV SPD・A/T の上昇中に master の左 FMC が内部の試験に落ちる（注入 2）と、1 秒で fmc_ok[0] 0、左の CDU はつながったまま LEGS で止まり RTE が効かず、右の CDU に RESYNCING OTHER FMC、LNAV と VNAV SPD に琥珀の線、A/T の FMA が空白、F/D バーが消えた（画像）。約 16 秒で戻り、LNAV・VNAV SPD のまま線が消え、RESYNCING も消え、左の CDU の RTE が効いた。A/T は ARM スイッチの入れ直しで戻った。次に右 FMC の再同期の失敗（注入 3）で、左の CDU に RESYNCING OTHER FMC（AFDS はそのまま）、約 32 秒で FMC RIGHT、約 37 秒で右の CDU が MENU と TIMEOUT - RESELECT、左の CDU に RESYNC FAIL - SINGLE FMC（画像）。Log.txt に Lua の誤りなし。

## 102. 11e の段取りと 11e1 の実装（2026-11-01：代替航法と IRS LEGS）

- 段取り：
  - 11e1：CDU の経路の写しと IRS LEGS（つなげる FMC が無いときの LEGS キー、CDU ごとの順送り、入力・削除・MOD・EXEC）。
  - 11e2：IRS PROGRESS（LAST・TO・NEXT・DEST、IRS の位置、GS、XTK ERROR、DTK、TK）。
  - 11e3：ALTN NAV RADIO と CDU ごとの無線の同調（左の CDU は左の VOR・DME・ADF・ILS、右は右、中央は ILS C）。
  - 両方の FMC の故障の ND の地図（CDU L・C・R の表示、MAP RANGE DISAGREE：FCOM p.1151、p.1421–1422）は、パネルの変更が要るので、11e3 の後で考える。
- 資料：
  - FCOM p.1275（MENU の 1 行目に <FMC が無ければ、LEGS で ALTN NAV LEGS、PROG で ALTN NAV PROGRESS、NAV RAD で ALTN NAV RADIO）。
  - FCOM p.1421–1424（両方の FMC が落ちると CDU が代替航法をする：LNAV・VNAV・A/T は無い。CDU は自分の IRU で計算し、性能と航法のデータベースを持たない。FMC の有効な経路を写し続け、条件の点・オフセット・ホールドは残さない。新しい点は緯度経度だけ。経路の変更は FMC とほぼ同じ。点の間は大圏。現用の点を変えると現在位置から直行。1 台の CDU の変更は他を変えない。IRS LEGS の行：針路（M か T、現用の脚は磁方位も、以降は真方位）、点、距離、座標）。
  - FMSPG p.247–249（FMC は有効な経路の変更（順送り、ACTIVATE、EXEC）のたびに CDU へ送る。1L–5L に入れられるのは経路の点と緯度経度だけ：無ければ INVALID ENTRY。現用の針路は MAG/TRUE の選択に従い、以降は真方位。距離は前の点からで、現用の脚には無い）。ATA34_2 p.589（IRS LEGS と IRS PROGRESS のページの出し方）。
- 作ったもの：
  - `B747.68.altn_nav_model.lua`（新）：CDU の経路の写し（FMC の有効な経路の点と不連続。条件の点とホールドを除き、オフセットは写さない。目的地）。大圏の針路・距離・沿う距離と横の距離。順送り（現用の点を横に過ぎたら：推定）と LAST の点と高度。IRS LEGS の入力（後の経路の点：その前の点を消して DIRECT、緯度経度：その行の前に入れて後に不連続、1 行目は現在位置から直行）、削除（点は前後をつなぐ、不連続と現用の点は INVALID DELETE：推定、FMC の LEGS と同じ）、MOD・EXEC・ERASE。
  - つなぎ（`B747.68.xt.fms.lua` の `update_altn_nav`、1 秒ごと）：FMC が動いている間は 3 台の CDU の写しを有効な経路から作り直す。両方が落ちていれば、各 CDU の経路を自分の IRU（左・中央・右）の位置で順送り。`B747_fms_altn`・`B747_fms_altn_pos`。CDU の IRS LEGS の変更でその CDU の EXEC 灯（左・右）。
  - CDU：`activepages/B744.fms.pages.altnnav.lua`（新）の ACT IRS LEGS（MOD IRS LEGS）：5 点ずつ、小字に針路（現用は方位基準で M か T、以降は T）と距離（現用の脚は無し）、点と座標、不連続の箱と THEN、6L に <ERASE（MOD のとき）、区切りの線。`B744.createfms.lua` の pageKey：つながっていない CDU で、つなげる FMC も無ければ、LEGS で IRS LEGS、IRS LEGS での EXEC は CDU の変更。
- 推定：順送りは現用の点を横に過ぎたとき。現用の点の削除と不連続の削除は INVALID DELETE。長い識別子（緯度経度の点）では座標の間の空白を詰める。磁方位は X-Plane の磁気偏差で。
- 試験：新しい `altn_nav_model_test.lua`（43 件）と `altn_nav_glue_test.lua`（28 件）。全 159 本。X-Plane：新しい `s177_irs_legs`：17/17（2026-11-01、立ち上げ直した後の 4 便目）。成田の北の 3,000 ft で RJAA→RJBB（XAC・SPENS・BOKJO）を作り XAC へ DIRECT の後、両方の FMC を故障させると、左の CDU は MENU で <FMC が無く、LEGS で ACT IRS LEGS 1/1：216°M、XAC N34°42.7 E139°24.8、271°T 20NM、SPENS、251°T 32NM、BOKJO、終わりの破線と区切りの線（画像）。2L に N3610.0E14010.0 を入れると MOD IRS LEGS 1/2 で N36E140、THEN と箱、ROUTE DISCONTINUITY、<ERASE、左の EXEC 灯だけが点き（画像）、EXEC で ACT に戻って灯が消えた。右の CDU の IRS LEGS は 2 行目が SPENS のまま。Log.txt に Lua の誤りなし。

## 103. 11e2 の実装（2026-11-01：IRS PROGRESS）

- 資料：
  - FCOM p.1425–1426（IRS PROGRESS の行：LAST、TO、NEXT、DEST、IRS の位置、XTK ERROR、ALT、TTG、DTG、GS、TK、DTK。DEST の入れ方で ENROUTE WPT と DIR TO ALTERNATE）。
  - FMSPG p.250–251：
    - LAST の点と、それを過ぎた時の高度。TO の DTG は経路沿いで、経路を外れていれば真横の点から。TTG は対地速度で、速度や位置が無効なら空白。NEXT の DTG は TO の DTG に二点の大圏の距離を足す。
    - DEST の見出し：DEST、MOD（変更中は変更した経路で）、DIR TO ALTERNATE（経路に無い点：現在位置から直行。ページを離れるか経路の変更で消える）、ENROUTE WPT（経路の点：経路沿いで、その点を過ぎると目的地に戻る。二度ある点は初めの方）。
    - IRS の見出しに使う IRU（L・C・R）、GS、XTK ERROR、DTK、TK（方位基準の M か T）。
- 作ったもの：
  - `B747.68.altn_nav_model.lua`：`progress`（TO・NEXT・DEST の DTG、横の距離、真横の点での脚の針路）、`set_alternate`（4L の入力：経路の点で ENROUTE WPT、緯度経度で DIR TO ALTERNATE、他は INVALID ENTRY）。経路の変更・EXEC・ERASE と、ENROUTE WPT の点を過ぎたときに代替を消す。
  - `activepages/B744.fms.pages.altnnav.lua` の IRS PROGRESS：LAST と ALT（遷移高度の上は FL）、TO・NEXT・DEST の距離と時間、IRS L・C・R の位置と GS、XTK ERROR（L・R と NM）、DTK と TK（方位基準）。4L の入力。ページを離れると代替を消す（前のフレームに描かれていなければ離れたとする）。PROG キーでこのページ。
  - つなぎ：各 CDU の IRU の名前と航跡（`B747_fms_altn_iru`・`B747_fms_altn_track`）、フレームの数（`B747_fms_frame_no`）。FMS の主のチャンクの局所変数が 200 を超えたので、11d と 11e のつなぎを 1 つの `do ... end` にまとめ、`>FMC MESSAGE` で使う `B747_fms_any_fmc` だけを大域にした。
- 推定：TK は X-Plane の対地航跡（IRS に航跡の dataref が無い。右の CDU は副操縦士側）、TTG は 1 kt 未満で空白、経路の不連続は前後をつないで数える、4L の DELETE は INVALID DELETE。
- 試験：`altn_nav_model_test.lua`（+20 件：63 件）、`altn_nav_glue_test.lua`（+16 件：44 件）。全 159 本。X-Plane：新しい `s178_irs_progress`：13/13（2026-11-01、立ち上げ直した後の 5 便目）。成田の北の 3,000 ft で RJAA→RJBB（XAC・SPENS・BOKJO）を作り XAC へ DIRECT の後、両方の FMC を故障させると、左の CDU の PROG で IRS PROGRESS：TO XAC 87NM 00:16、NEXT SPENS 107NM 00:20、DEST RJBB 296NM 00:55（321 kt で計算が合う）、IRS L の位置と GS、XTK ERROR R 0.7NM、DTK 216°M、TK 348°M（画像）。4L の SPENS で ENROUTE WPT、LEGS へ行って戻ると DEST。右の CDU は IRS R。Log.txt に Lua の誤りなし。

## 104. 11e3 の実装（2026-11-01：ALTN NAV RADIO）

- 資料：
  - FCOM p.1422：代替航法では無線を各 CDU で手で同調する。左の CDU は左の VOR・DME・ADF・ILS、右は右、中央は ILS C。
  - FCOM p.1427–1428、FMSPG p.252–254（ALTN NAV RADIO の行。自動同調は無い）：
    - VOR：周波数か周波数/針路で M。DME も同調する。DELETE で破線。中央の CDU では空白。
    - CRS：針路か周波数/針路。DELETE で消える。
    - ADF：周波数、A（ANT）か B（BFO）を後ろに、またはそれだけ。DELETE で破線。
    - ILS-MLS：周波数、周波数/針路、針路だけ（周波数があるとき）。周波数だけなら針路は有効な経路の滑走路の針路、無ければ前の針路か 000。DELETE で PARK。自動同調だった ILS は FMC の故障の時に写る。
    - PRESELECT：どの行の入力も入れておけ、書き込み行に下ろしてから入れる。
    - FMC は同調を変えるたびに CDU へ送るので、CDU は FMC が同調していた局から始まる。
  - ATA34_2 p.592（地上で両方の FMC が落ちたとき、または空中で master FMC が落ちたとき、NAV RAD キーでこのページ。ADF も中央の CDU では空白）。
- 作ったもの：
  - `B747.68.altn_radio_model.lua`（新）：CDU ごとの VOR（周波数・針路）、ADF（周波数・ANT/BFO）、ILS（周波数・針路、PARK）、PRESELECT 2 つ、FMC の同調の写し。入力の解析は FMC の同調のモデル（`B747.68.tune_model.lua`）の VOR・ILS の周波数と針路の関数を使う。
  - つなぎ（`B747.68.xt.fms.lua`）：master FMC が動いている間は、毎秒、各 CDU の側の同調を写す（VOR は X-Plane の周波数と FMC の針路、ADF は周波数と ANT/BFO、ILS は FMC が A か M で同調していればその周波数/針路）。`B747_fms_altn_tune`：CDU の入力でその側の無線をすぐ同調する（左：NAV3・ADF 1・NAV1、右：NAV4・ADF 2・NAV2）。同調のモードの文字（`radio/tuningmodes`：ILS・VOR の M、ADF の A・B・M）と、PFD の ILS の目盛（`autopilot/ils_dots`）も。
  - CDU：`activepages/B744.fms.pages.altnnav.lua` の ALTN NAV RADIO（1L VOR と小字の M、2L CRS、3L ADF と小字の ANT・BFO、4L ILS-MLS か PARK、6L・6R の PRESELECT）。VOR・CRS・ADF は中央の CDU では空白で入力も受けない。つなげる FMC の無い CDU の NAV RAD キーでこのページ。
- 推定：中央の CDU の ILS C は X-Plane に無いので同調しない（入力は持つ）。ILS の周波数だけのときの針路は FMC の ILS の同調が持っていた目的地の滑走路の ILS の針路。VOR の行の針路だけの入力は INVALID ENTRY。PRESELECT の DELETE で消す。
- 試験：新しい `altn_radio_model_test.lua`（54 件）、`altn_nav_glue_test.lua`（+21 件：65 件）。全 160 本。X-Plane：新しい `s179_altn_nav_radio`：15/15（2026-11-01、立ち上げ直した後の 6 便目）。成田の北の 3,000 ft で両方の FMC を故障させると、左の CDU の NAV RAD で ALTN NAV RADIO。1L の 114.50/270 で VOR L（NAV3）が 11450 に、4L の 109.50/157 で ILS L（NAV1）が 10950 と PFD の ILS の目盛（ils_dots 1）、3L の 1304.5B で ADF L 1304 と BFO、6L に 110.90/128 を入れて書き込み行へ下ろし 4L へ入れると ILS L が 11090（CDU の画像：VOR 114.50M、CRS 270、ADF 1304.5BFO、ILS-MLS 109.50/157、PRESELECT 110.90/128）。PFD の画像では ILS の識別子（ITJ）と DME が出た。Log.txt に Lua の誤りなし。同じ PFD の画像で FMA の HDG HOLD にモード故障の線が出ていた（FMC を戻しても残る。IRS の方位は有効）。FMC の故障は LNAV・VNAV しか故障にしないので、空中開始の直後に IRU の方位が有効になる前に A/P が HDG HOLD で入った競合とみられ、別に調べる。

## 105. 段 12 の段取りと 12a の実装（2026-11-01：FMC のデータリンクの有無）

- 段取り（段 12：残りのページとデータリンク。CDU-30〜42、FCOM p.725–776、p.1211、FMSPG 7〜9 章）：
  - 12a：FMC のデータリンクの有無（CDU-32）。109（PW・RR）は ATC と FMC COMM のキーが KEY/FUNCTION INOP、570（GE）はデータリンクのページ。simconfig の新しい項目で入切（シムの機能）。
  - 12b：自動のページ変更（CDU-30）。VNAV の CLB→CRZ（T/C）、CRZ CLB・CRZ DES→CRZ（新しい巡航高度）、CRZ→DES（T/D）、E/O の D/D→E/O CRZ（FCOM p.1345、p.1350）、570 の TAKEOFF REF→VNAV CLB（フラップを上げ始めたとき：FCOM p.1325）。DSPY 灯は 3D に無いので対象外（CDU-22）。
  - 12c：保守のページ（CDU-31）。地上だけ（FMSPG p.263）、MAINTENANCE INDEX の <INDEX は INIT/REF INDEX（FCOM p.1239）、PERF FACTORS（6R にコードを入れてから入力。DRAG/F-F は予測と性能へ、TO 1/TO 2・MNVR MARGIN・MIN CRZ TIME・THR RED・ACCEL HT：FMSPG p.265–269）、IRS MONITOR、CROSS LOAD・BITE。
  - 12d：データリンクの小さな直し：送信文を CDU ごとに（CDU-34）、EICAS（405・570 の ATC MESSAGE のメモとチャイム、ACARS MESSAGE は ACARS だけ、FCOM に無い ACARS NO COMM のメモをやめる、>DATALINK LOST・AVAIL・SYS：CDU-37、FCOM p.775–776）、CDU-42 の残り、DESTINATION NOT SET の見直し（§97 の後始末）、VERIFY TAIL NUMBER（LOGON/STATUS の TAIL NO と FMC の登録記号：FCOM p.757、p.1436）。
  - 12e：ATC のログオン（CDU-36）：ATC キーの振り分け、LOGON/STATUS の手順（SEND・SENT・ACCEPTED・REJECTED・RESEND、SELECT OFF、ATC COMM ESTABLISHED・TERMINATED：FCOM p.752–758、p.1431、p.1433、FMSPG p.277–285）。
  - 12f：ATC のアップリンク（CDU-35）：XXXXz ATC UPLINK、ACCEPT・REJECT・STANDBY、VERIFY RESPONSE、REJECT DUE TO、LOAD（経路の MOD）、UNABLE TO LOAD・PARTIAL CLEARANCE LOADED（FCOM p.753–765、FMSPG p.288–297）。
  - 12g：ATC の残り（CDU-39）：ATC LOG、REQUEST の要素と制限、REPORT と ARM、POS REPORT、EMERGENCY（CANCEL、FUEL REMAINING）（FCOM p.728–754、p.766–770、FMSPG p.298–363）。
  - 12h：会社のデータリンク（CDU-40）、ADS（CDU-41）、Hoppie（CDU-38）。範囲は 12g の後で決める。
  - データリンクは AutoATC か Hoppie のプロバイダーを通る。この PC の X-Plane には AutoATC が無いので、X-Plane では切れている側（NO COMM）しか試せない。プロバイダーの dataref は X-Plane なしの試験で模す。
  - 11e の残り（両方の FMC が落ちたときの ND の地図：CDU L・C・R、MAP RANGE DISAGREE：FCOM p.1151、p.1421–1422）はパネルの変更が要るので、段 12 の後で。
- 資料（12a）：
  - FCOM p.1211：109 は ATC と FMC COMM のキーで CDU に KEY/FUNCTION INOP。405・570 は ATC で ATC のページ、FMC COMM でデータリンクのページと状態。
  - FCOM p.725：ATC のデータリンクの章（5.33）は 405・570 だけ。
  - ACARS（MENU の <ACARS：FCOM p.714、p.1323）は型式の印が無く全機にあるので、変えない。
- 作ったもの：
  - `B744.createfms.lua`：`B747_fms_datalink()`：simconfig の `SIM.fmc_datalink` が ON なら有り、OFF なら無し、AUTO（か項目が無い）なら型式で、`laminar/B747/engines/type` が 1（GE、570）なら有り、0（PW）・2（RR）なら無し（RR は PW と同じ 109：推定、RR の資料は無い）。`B747_fms_datalink_cfg()` は設定を simconfig の JSON の文字から読む（リバリーのファイルにはこの項目が無いので、表を引かない）。ATC（`func_key/crz`）と FMC COMM（`func_key/hold`）のキーは、無ければ KEY/FUNCTION INOP でページはそのまま。
  - simconfig の既定に `fmc_datalink = "AUTO"`（`B747.05.xt.simconfig.lua`）。
  - SIM CONFIG の 2 ページ目（MENU の 6R、NEXT）の 4L：<FMC DATALINK と設定（押すたびに AUTO→ON→OFF→AUTO）、小字に今の有無（ATC, FMC COMM の ACTIVE か INOP）。リバリーへの保存は 6R の SAVE（今までどおり）。2 ページ目では 1 ページ目の 5L・1R〜5R を外した（前は押すと 1 ページ目の項目が変わった）。
  - 試験キット：シナリオの `cdu` の手順のキーの名前に ATC と FMCCOMM。
- 試験：新しい `tests/fms/datalink_keys_test.lua`（18 件：PW・RR で ATC と FMC COMM が KEY/FUNCTION INOP でページはそのまま、GE で ATC INDEX と FMC COMM、PW でも ON なら ATC INDEX、GE でも OFF なら INOP、SIM CONFIG の 2 ページ目の 4L で AUTO・ON・OFF と simconfig の文字、2 ページ目の 1R は何もしない）。ATC・FMC COMM のキーを押す `fmc_fixes_test`（EMERGENCY REPORT）と `rte_pages_test`（FMC COMM の 1L）は、機体を 570 にした。全 162 本。
  - X-Plane：新しい `s181_datalink_keys` 12/12（RJAA の地上、PW の機体。ATC と FMC COMM で KEY/FUNCTION INOP、ページは IDENT のまま。SIM CONFIG の 2 ページ目の 4L は AUTO・小字 INOP、押すと ON・ACTIVE で simconfig に `"fmc_datalink":"ON"`、ATC で ATC INDEX、4L を 2 回で AUTO に戻る。CDU の写真 4 枚）。`s79_fmc_fixes`（EMERGENCY REPORT の前に SIM CONFIG で ON、後で AUTO に戻す手順を足した）34/34。どちらも Log.txt に Lua の誤りなし。

## 106. 12b の実装（2026-11-01：自動のページ変更）

- 資料：
  - FCOM p.1345：CLB のページは T/C で CRZ に、CRZ CLB と CRZ DES のページは新しい巡航高度で CRZ に、CRZ のページは T/D で DES に変わる。
  - FCOM p.1350：E/O LRC D/D のページは E/O LRC CRZ のページに変わる（どちらも CRZ のページで、見出しが変わる：段 9h4b）。
  - FCOM p.1325：570 は、離陸の段階でフラップのレバーを格納のために動かすと、TAKEOFF REF のページが VNAV CLB のページに変わる。離陸の段階は、FMC が上昇の推力を指令すると上昇の段階になる。
  - FCOM p.1210 の DSPY 灯（表示が有効な脚や性能のモードと関係ないとき）は、3D の操縦席に無いので対象外のまま（CDU-22）。
- 作ったもの：`B744.createfms.lua` の `B747_cdu_page_changes`（FMS のモジュールが毎フレーム、VNAV と推力制限を更新した後、CDU を描く前に呼ぶ）。
  - VNAV：FMC の段階のページ（`B747_fms_vnav_page`：1 CLB、2 CRZ、3 DES。地上と有効な経路が無いときは 0）が 1→2（T/C）か 2→3（T/D）に変わったとき、変わる前の有効なページを出している CDU だけが新しいページへ。有効でない VNAV のページや LEGS などはそのまま。CRZ CLB・CRZ DES・E/O の D/D は CRZ のページのまま見出しが変わる。資料に無い変わり方（進入復行の DES→CLB、CLB から直接 DES、0 からの段階）では変えない。
  - 570（`engines/type` 1）：空中で、推力制限が TO（離陸の段階：THR REDUCTION の前）の間に、フラップのレバー（`sim/cockpit2/controls/flap_ratio`）が上がり始めたら、TAKEOFF REF を出している CDU が VNAV CLB のページへ。109 は変えない。
- 推定：早期降下（DES NOW など）で CRZ から DES に移るときも T/D と同じに変える（FCOM は「T/D で」とだけ書く）。離陸の段階の終わりを、推力制限が TO でなくなるときとした（FCOM p.1325 の「FMC が上昇の推力を指令すると」）。
- 試験：新しい `tests/fms/page_auto_test.lua`（24 件：T/C で CLB から CRZ、LEGS の CDU はそのまま、NEXT・PREV、T/D で CRZ から DES、有効でない CLB のページはそのまま、DES→CLB と CLB→DES では変えない、CRZ CLB の間と後は CRZ、0 からは変えない、109 の離陸は TAKEOFF REF のまま、570 はフラップを上げ始めると VNAV CLB、レバーを下げても何もしない。直す前のコードでは 6 つ落ちる）。全 163 本。X-Plane：新しい `s182_page_auto_tc` 10/10（s139 と同じ上昇：T/C で左の CDU が ACT ECON CLB から ACT ECON CRZ へ、右の LEGS はそのまま）、`s183_page_auto_td` 12/12（s140 と同じ巡航：T/D で ACT ECON CRZ から ACT ECON DES へ、右の有効でない CLB はそのまま。1 回目は空中開始のやり直しの後に右の CDU の電源が無く、A/P も経路も入らず 1/12：原因は未確認、記録を足した 2 回目で通った）、`s184_page_auto_570_takeoff` 20/20（GE（Saudia）の離陸：TAKEOFF REF のまま浮き、推力制限 TO の間にフラップを 20 から 10 にすると ACT LIM SPD CLB）。Log.txt に Lua の誤りなし。
- 見つけたこと：CLB のページの AT XXXXX と ERROR、DES のページの E/D AT と AT XXXXX は、前のコードのまま X-Plane の FMS の脚と高度から作っていて、制限の無い点に FL001、DES では箱を出す（s182・s183・s184 の写真）。12b2 で作り直す（§107）。

## 107. 12b2 の実装（2026-11-01：VNAV のページの点）

- 見つけたこと：CLB のページの AT XXXXX と ERROR、DES のページの E/D AT と AT XXXXX は、旧フォークのコードのまま X-Plane の FMS の脚と高度（`fms_route()`）と前の AP の E/D（`autopilot/dist/eod_index`）から作っていた。制限の無い点に FL001 や箱が出ていた（s182・s183・s184 の写真）。
- 資料：
  - FCOM p.1328：CLB のページの AT XXXXX は、点 XXXXX の次の速度と高度の制限（HOLD AT XXXXX のこともある）。
  - FCOM p.1329：ERROR は、点での高度の差と、その高度に達するまでに点を過ぎる距離。誤差が無ければ空白。p.1327 の図は「350LO 2LONG」。
  - FCOM p.1392：DES のページの E/D AT は降下の終わりの高度と点（降下の段階の最も低い高度の制限の点。無ければ空白）、AT XXXXX は RTE LEGS の次の点の制限。p.1391 の図は「2800 PELLY」「240/ 6000」。
- 作ったもの：
  - FMS のつなぎ（`B747.68.xt.fms.lua`）の `B747_fms_vnav_wpts`：有効な経路の脚（`B747_fmc_route.rte.legs`）と予測（`predResult`、脚と同じ番号）から、clb＝T/C より前の、点のある脚で速度か高度の制限のある最初の脚、des＝T/D より後の最初の脚（予測に T/D が無いときは、降下の段階か、T/C も無く E/D がある（予測がここから降下を始める）ならすぐ先の。s186 の 1 回目は T/D のすぐ手前で予測の T/D が無く、空白だった）、ed＝予測の E/D の脚（`ed_i`）の点と高度（滑走路は閾値の 50 ft 上：FCOM p.1258、窓は下の高度）。予測が無いときは FMC の段階（CLB・DES）で決める。clb の ERROR：その脚で予測の高度が AT・AT OR ABOVE・窓の下の高度より 10 ft（UNABLE NEXT ALT と同じ）を超えて低いとき、低い ft と、予測でその高度に達する所（次の脚との間を直線で）までの NM。
  - VNAV のページ（`activepages/B744.fms.pages.vnav.lua`）：CLB の 1R に制限（LEGS の表示と同じ書き方で、高度は 5 けた：FCOM の「250/ 2500」。CLB のページの TRANS ALT の上は FL）、小字に AT と点の名前、2R に ERROR（ft は 10 単位、NM は 1 単位で最小 1：推定）と小字の ERROR（誤差のあるときだけ）。DES の 1L に E/D の高度と点、1R に次の制限（TRANS LVL の上は FL）、小字に E/D AT（E/D のあるときだけ）と AT と点の名前。前のコード（`fms_route()` の読み、前の AP の E/D、使わなくなった変数）は外した。E/O の CLB のページも同じ。
- 推定：制限の高度の 5 けたの書き方は A・B・窓でも LEGS と同じ（FCOM の図は AT の制限だけ）。HOLD AT XXXXX は作っていない（経路のホールドは点の名前で出る）。ERROR の丸め。
- 試験：新しい `tests/fms/vnav_wpts_test.lua`（23 件：pred_glue_test と同じ ZZAA の経路で、地上の CLB のページが AT ZZV と 230/3000A で ERROR なし、DES のページの E/D AT が滑走路と閾値の 50 ft 上、AT ALPHA と窓（TRANS LVL の上は FL）、LEGS で ZZV に 20000A を入れると FL200A と ERROR の xxxLO yyLONG（予測から計算した値と同じ）、予測に T/C も T/D も無く E/D があれば DES の AT はすぐ先の制限、有効な経路が無ければ空白）。全 164 本。X-Plane：新しい `s186_vnav_wpts_des` 14/14（2 回目。DES のページに E/D AT「59 RW06L」と AT ATVID「/4000A」。1 回目は T/D のすぐ手前で予測に T/D が無く AT が空白だったので、上の「T/C も T/D も無く E/D がある」を足した）、新しい `s185_vnav_wpts_clb` は 9/13：制限の無い経路で CLB の AT と ERROR が空白（前の AT XAC FL001 は消えた）は合格。制限を入れた後の AT・ERROR は出なかった：1・2 回目は XAC（大島、約 85 NM 先）が予測の T/C の後で上昇の制限でなく（正しい）、3・4 回目（約 20 NM 先の SULPU に 30000A）は、SID の無い経路なので予測の入力がその制限を E/D にしていた（PROGRESS の TO T/D 15NM、ND の点に T/C が無い）。前からの予測の誤りで、次のコミットで直す（§108）。Log.txt に Lua の誤りなし。

## 108. 予測の E/D の選び方（2026-11-01：SID の無い経路の上昇の制限）

- 見つけたこと（12b2 の s185）：SID の無い経路で、上昇中に約 20 NM 先の点（SULPU）に 30000A を入れると、予測の入力（`B747_fms_pred_input`）がその制限を E/D にし、T/D がその手前になっていた（PROGRESS の TO T/D 15NM、ND の点に T/C が無い）。E/D は「進入の滑走路、無ければ SID の最後の脚より後の最後の制限」で、SID が無いと経路のどこの制限でも E/D になった。予測のモデル（`B747.68.pred_model.lua`）は、SID が無いときの上昇の制限を「E/D か経路の終わりまでの半分より前」としていて（推定）、入力の側がこれと合っていなかった。VNAV の降下の経路もこの E/D を使う。
- 資料：FCOM p.1392（E/D は降下の段階の最も低い高度の制限の点）。上昇と降下の制限の分け方は資料に無い。
- 直したこと：SID が無く上昇の段階のときは、経路の先の距離の半分より後の制限だけを E/D の候補にする（予測のモデルの上昇の分け方と同じ：推定）。巡航と降下の段階では前と同じく先のどの制限でも。SID がある経路、進入の滑走路は前のまま。
- 試験：新しい `tests/fms/pred_ed_test.lua`（12 件：合成のデータの ZZAA→ZZBB を BRAVO・CHARL・DELTA で、上昇中に BRAVO（約 18 NM 先、前半）の 30000A は E/D でなく T/C は BRAVO の後・T/D 無し、CLB のページに AT BRAVO と /FL300A と ERROR、巡航（FL350）では BRAVO の制限が E/D、後半の DELTA の 10000 は E/D。直す前のコードでは 6 つ落ちる）。全 165 本。X-Plane：`s185_vnav_wpts_clb` 13/13（上の巡航・降下の場合分けを足す前のコード：上昇の段階なので同じ）。CLB のページに AT SULPU、/FL300A、ERROR「13710LO 75LONG」（10,800 ft から FL300 に SULPU の 75 NM 先で届く）。Log.txt に Lua の誤りなし。

## 109. 12c1 の実装（2026-11-01：MAINTENANCE INDEX と PERF FACTORS）

- 前のコード：保守のページは固定の文字。MAINTENANCE INDEX の <INDEX は ACMS を開き、プロンプトは「<CROS LOAD」「<PERF FACTOR」。PERF FACTORS は値が固定（R/C CLB 300、TO-1/TO-2 10/20、MNVR MARGIN 1.3、THR RED 1500、ACCEL HT 1500 など）で入力できず、TAKEOFF REF・THRUST LIM の値とも別だった。
- 資料：
  - FCOM p.1239：MAINTENANCE INDEX のプロンプトは地上でだけ使う。<CROSS LOAD・BITE>・<PERF FACTORS・<IRS MONITOR、<INDEX（INIT/REF INDEX へ）の上に線。
  - FMSPG p.263–268：保守のページは地上だけ。PERF FACTORS の形（PERF CODE 1111、OPTION CODE、DRAG/F-F、TO 1/TO 2、MNVR MARGIN、MIN CRZ TIME、R/C CLB、THR/CRZ、THR RED、ACCEL HT、6R の ---）。6R にコードを入れるまで静的で、ページを出るとコードは消える。各欄の形と範囲、何も入れていない FMC の値（1.20、1、100、CLB/100、1500、1500/1500）。
  - ATA34_2 p.678–679：入力は性能の係数を変え、関係する値は飛行の終わりか長い電源断の後に TAKEOFF REF に出る。DRAG/F-F は性能の予測に使い、IDENT にも出る。TO 1/TO 2 は 0–30 % の derate で、THRUST LIMIT にも出る。MNVR MARGIN は包囲線とバンクの制限の計算、MIN CRZ TIME は最適高度、R/C CLB・THR/CRZ（CLB か CRZ。入力が無ければ CLB）は最大高度に使う。6R は ARM を書き込み行に入れて押す（H/W と S/W の option code 以外を変えられる）。p.681 の図の機体：MNVR MARGIN 1.30、R/C CLB 300、THR/CRZ CRZ/100、THR RED FLAPS 5、MIN CRZ TIME 5、ACCEL HT 1000 / 1000、6R に ARM。
  - FCOM p.969・p.973：PFD の最大機動速度と、20,200 ft より上の最小機動速度は、buffet まで 1.3 g（または整備が設定した値）。p.1272：TO 1・TO 2 は運航者の %（1 % 刻み）。p.1273：巡航の推力の基準は整備の設定で CLB か CRZ。p.1314：TO 1 −8 %・TO 2 −20 %（109）、570 は −5・−15 %。p.1317–1318：TAKEOFF REF の既定は FLAPS 5・1000FT・1000FT。p.1350：MAX の残余上昇率は航空会社の設定（0–500 fpm、既定 100）。
- 作ったもの：
  - `B747.68.perf_factors_model.lua`（新しい純粋なモデル）：値（入力が無ければ ATA34_2 p.681 の機体の値。FCOM の TAKEOFF REF の既定、1.3 g、100 fpm と合う。derate はエンジン型式ごとの FCOM の値）、入力の形と範囲、ページの文字。
  - FMS のつなぎ（`B747.68.xt.fms.lua`）：値はリバリーの simconfig の `FMC.PERF`（SIM CONFIG の保存で残る。FMC が最後の入力を覚えることに当たる）。読むのは simconfig の JSON の文字列から（XTLua の名前空間の表の無いキーを読まないため）。
    - DRAG/F-F → IDENT の DRAG/FF（`FMC.INIT.drag_ff` も合わせる）と、性能のデータの燃料流量（`B747_perf_db.FF_F` はすべての燃料流量、`DRAG_F` は水平飛行の燃料流量に掛ける）。
    - TO 1/TO 2 → THRUST LIM の derate（`B747_fms_thrlim_pct`。EEC の reference へ）。
    - MNVR MARGIN → 最大高度の buffet の余裕（`B747_perf_db.MARGIN_G`）と、PFD の buffet の機動速度（新しい `laminar/B747/fms/mnvr_margin` を `B747.60.xt.speedtape.lua` が読み、`B747.60.minspeed_model.lua` の最大機動速度と、20,200 ft より上のフラップ上げの最小機動速度に使う。下と、フラップを出したときは 1.3 g のまま）。
    - THR/CRZ → CLB なら T/C で CLB のまま（CLB 1・2 は外す）、CRZ なら前のとおり CRZ（`B747.68.thrlim_model.lua` の `crz_clb`）。
    - THR RED・ACCEL HT → TAKEOFF REF の既定。飛行の始まり（`do_flight_start`）と flight complete で取り込み、乗員が入れていない欄に入れる。TAKEOFF REF の DELETE で戻る値も（前は 1000 と FLAPS 5 の決め打ち）。
    - MIN CRZ TIME・R/C CLB・R/C CRZ は表示と保存だけ（FCOM の表の最大高度は 100 fpm で、短い飛行の最適高度は FMC に無い）。
  - ページ：MAINTENANCE INDEX（FCOM の見出しと線、地上だけプロンプト、<INDEX は INIT/REF INDEX）。PERF FACTORS（FMSPG の形。6R は ARM の前 ---、後 ARM。ARM の前の入力は INVALID ENTRY、DELETE は INVALID DELETE、PERF CODE と OPTION CODE は入力できない）。ARM は CDU ごとで、ページを出ると消える。
  - CDU の枠組み（`B744.createfms.lua`）：CDU が描くページが変わったら、前のページの `onLeave` を呼ぶ。`createPage` が全ページに空の `onLeave` を持たせる（XTLua の名前空間の表は無いキーを読むとスタックがあふれる）。
- 推定：空中の MAINTENANCE INDEX はプロンプトを出さない。ARM の後の 6R の表示（ATA34_2 の図は ARM、FMSPG の図は --- なので、入力の前と後と読んだ）。DELETE はすべての欄で INVALID DELETE（資料は TO 1/TO 2 だけ）。DRAG の係数は水平飛行の燃料流量だけに掛け、上昇と降下の経路は変えない。derate の変更はすぐに THRUST LIM へ（飛行の終わりを待つのは TAKEOFF REF の値と読んだ）。OPTION CODE の値は FMSPG の図のもの。
- 使わないもの：MNVR MARGIN のバンクの制限の計算（ATA34_2 p.678）は、この FMC の LNAV にバンクの制限の計算が無いので使わない。
- 試験：新しい `tests/fms/perf_factors_model_test.lua`（125 件：入力の無いときの値とエンジン型式の derate、保存した値と型の違う値、各欄の形と範囲、文字）、新しい `tests/fms/perf_factors_pages_test.lua`（61 件：INIT/REF INDEX の MAINT> で MAINTENANCE INDEX と <INDEX、PERF FACTORS の FMSPG の形と値、ARM の前の INVALID ENTRY、ARM、各欄の入力と simconfig の FMC.PERF・drag_ff、性能のデータの係数と `fms/mnvr_margin`、PERF CODE・OPTION CODE・DELETE、ページを出ると ---、IDENT の DRAG/FF、THRUST LIM の <-25 %、TAKEOFF REF は飛行の終わりまで FLAPS 5 と 1000FT で、終わると 1200FT・800FT・/1500FT、DELETE で 1200FT、空中のプロンプト）、`perf_db_test.lua` +6（係数と既定の余裕）、`thrlim_model_test.lua` +4（THR/CRZ CLB の T/C）、`minspeed_model_test.lua` +4（1.20 g で 20,200 ft より上の帯が動き、下とフラップは 1.3 g のまま）、`speedtape_module_test.lua` +2（`fms/mnvr_margin` の 1.20 で最大機動速度が上がる、範囲の外は 1.3 g）、`navdb_fmc_test.lua` の IDENT の DRAG/FF の期待値を +0.0/+0.0 に（前は simconfig の +0.0/-0.0）。全 167 本。X-Plane：新しい `s188_perf_factors` 28/28（2026-11-01、X-Plane を起動し直した後の 2 便目。RJAA の地上で MAINTENANCE INDEX と <INDEX、PERF FACTORS の形と値、ARM の前の INVALID ENTRY、ARM、MNVR MARGIN 1.25 と `fms/mnvr_margin`、TO 2 25、DRAG/F-F +1.5/-2.0 と simconfig の FMC.PERF、IDENT の DRAG/FF、THRUST LIM の <-25 %、元の値へ戻す。CDU の写真 5 枚）。1 回目（起動し直す前の 6 便目）は 19/28：試験の作りの誤りで、INVALID ENTRY の後の CLR が 2 回だけで書き込み行に「1.2」が残り、ARM が入らなかった。Log.txt に Lua の誤りなし。

## 110. 12c2 の実装（2026-11-01：IRS MONITOR、NAV DATA CROSSLOAD、BITE REPORT）

- 前のコード：IRS MONITOR は各 IRU の整列の状態の文字、NAV DATA CROSSLOAD と BITE REPORT は固定の文字（CROSSLOAD は 6R に ARM が常に出ていた）。
- 資料：
  - FMSPG p.269：IRS MONITOR は飛行の終わりに、各 IRS の位置の誤差の率（NM/HR）を出す。FMC の位置から IRS の位置までの、離陸から飛行の終わりまでに生じた距離を、飛行の時間で割る。飛行の終わりに計算し、空中で消える。図は「IRS L」の小字の下に「1.1NM/HR」（NM/HR は小字）、<INDEX の上に線。
  - ATA34_2 p.682：エンジンを全部止めて約 45 秒後に出る。空中か電源の入れ直しで消える。
  - ATA34_2 p.676–677：NAV DATA CROSSLOAD は、一方の FMC の航法データを他方へ写す。2L は IDENT と同じ航法データの識別、3L の TRANSMIT を一方の CDU で、3R の RECEIVE を他方の CDU で押す（6R に ARM を入れてあれば）。4L・4R は転送の前は空白、転送中は TRANSFER IN PROGRESS、終わりに TRANSFER COMPLETE、途中で終われば TRANSFER ABORTED。6R は ---、ARM を入れて押す。別のページへ行くと ARM は消える。FMSPG p.264 の図は <INDEX の上に線。
  - ATA34_2 p.684–685：BITE REPORT は FMC の BITE の記録を data loader へ出す。DATA LOADER のキャレットは、地上で、data loader の選択スイッチがその FMC で、data loader に電源とディスクがあるときだけ。図の題は「FMC L BITE REPORT」、<INDEX の上に線。
- 作ったもの：
  - FMS のつなぎ（`B747.68.xt.fms.lua`）：離陸のときに各 IRU の位置の FMC の位置（X-Plane の位置：この FMC の位置）からのずれを取り、flight complete で、そのずれの変化の距離を飛行の時間（離陸から）で割る。flight complete（30 秒）からさらに 15 秒で出す（約 45 秒）。空中と、FMC がどちらも動いていないとき（電源の入れ直しに当たる：推定）に消える。
  - IRS MONITOR：IRS L・C・R の小字と、率（大字の「2.0」と小字の「NM/HR」）。<INDEX の上に線。
  - NAV DATA CROSSLOAD：2L に IDENT と同じ識別（AIRAC と cycle）、3L <TRANSMIT と 3R RECEIVE>、6R は ARM の前 ---、後 ARM（CDU ごと、ページを出ると消える）。ARM した CDU の TRANSMIT の後に、ARM した別の CDU の RECEIVE で転送が始まり、4 行目の中ほどに TRANSFER IN PROGRESS、30 秒後に TRANSFER COMPLETE、途中で FMC が動かなくなれば TRANSFER ABORTED。
  - BITE REPORT：題は CDU の FMC（<FMC がつなぐもの。無ければ L）、data loader は無いので「DATA LOADER」にキャレットを付けず、1L は何もしない。
- 推定：IRU が離陸か飛行の終わりのどちらかで航法のモードでなければ、その IRU は空白。FMC の電源の入れ直しを「FMC が両方とも動かない」とした。転送の時間（30 秒）、状態の文字を行の中ほどに。キャレットの無い DATA LOADER の位置。この機体の FMC は X-Plane の航法データを共有するので、転送で何も写さない。IRU の位置の誤差は整列ごとに小さく固定（`B747.34.xt.irs.lua`）で時間で増えないので、率はふつう 0.0。
- 試験：新しい `tests/fms/maint_pages_test.lua`（30 件：飛行の前の IRS MONITOR の見出しと空白の率、1 時間の飛行の後に IRU L が 2 NM 北・C が 1 NM 東で 2.0 と 1.0（小字の NM/HR）、R は航法のモードでないので空白、flight complete の 30 秒ではまだ出ない、空中で消える。BITE REPORT の FMC L・FMC R と DATA LOADER、1L は何もしない。CROSSLOAD の識別と見出し、ARM の無い TRANSMIT と RECEIVE は何もしない、ARM、両方の CDU に TRANSFER IN PROGRESS、30 秒で COMPLETE、ページを出ると ---、右の FMC の故障で ABORTED）。全 168 本。X-Plane：新しい `s189_maint_pages` 19/19（2026-11-01、X-Plane を起動し直した後の 3 便目。RJAA の地上で IRS MONITOR の見出しと空白、左 FMC L・右 FMC R の BITE REPORT、CROSSLOAD の AIRAC 2610・ARM・TRANSMIT・RECEIVE で両方に TRANSFER IN PROGRESS、31 秒後に TRANSFER COMPLETE。CDU の写真 4 枚）。Log.txt に Lua の誤りなし。

## 111. 12d の分け方と 12d1 の実装（2026-11-01：データリンクの EICAS の表示）

- 分け方：12d を 12d1（EICAS のデータリンクの表示：CDU-37）と 12d2（送信文を CDU ごとに：CDU-34、CDU-42 の残り、VERIFY TAIL NUMBER）に分けた。DESTINATION NOT SET（ACARS のページが自分の入力の確かめに使う文字）の見直しは、ATC のログオンを作り直す 12e で行う（ログオンの前提の確かめと一緒に）。
- 前のコード：ACARS のプロバイダーがつながっている間、未読のメッセージ（ATC のアップリンクも会社の ACARS も）があれば ACARS MESSAGE のメモ。つながっていないときは、中央の RTP が ON なら ACARS NO COMM のメモ（FCOM に無い。この PC のように AutoATC が無いと常に出ていた）。ATC MESSAGE のメモ、チャイム、>DATALINK の advisory は無かった。
- 資料：
  - FCOM p.725：ATC のアップリンクは、EICAS のメモ ATC MESSAGE と低い音のチャイムで知らせる。
  - FCOM p.775–776：advisory の >DATALINK AVAIL（一時的な喪失の後に ACARS の能力が戻った）、>DATALINK LOST（通信の喪失で ACARS が使えない）、>DATALINK SYS（ACARS の系統の故障）。メモの ACARS MESSAGE（ACARS を CDU で見る必要があるか、CDU で見るメッセージが来た）、405・570 の ATC MESSAGE（ATC のアップリンクが来た）。ACARS NO COMM は無い。
  - ATA23 の手元の資料は ACARS の EICAS の表示を扱っていない。
- 作ったもの：
  - FMS のつなぎ（`B747.68.xt.fms.lua` の `B747_fms_datalink_eicas`）：毎フレーム、ACARS の受信の一覧の未読を数える。FMC のデータリンクがある機体（12a の `B747_fms_datalink`：570 か simconfig の ON）では、ATC のアップリンク（`cpdlc`）を ATC MESSAGE（新しい memo_status[46]）、会社の ACARS（`telex`）を ACARS MESSAGE に。未読の ATC のアップリンクが増えたとき、新しい `laminar/B747/fms/atc_chime` を 1 秒 1 にする。データリンクの無い機体（109）は、前のとおりどの未読も ACARS MESSAGE。ACARS NO COMM のメモ（[40]）は出さない。
  - >DATALINK LOST（advisory_status[56]）：プロバイダーが一度つながった後に切れている間。>DATALINK AVAIL（[55]）：切れた後につながり直してから 60 秒。
  - EICAS の一覧（`B747.87.warning.lua`（init）と `B747.87.xt.warning.lua`）：メモに ATC MESSAGE（46）。init の一覧に無かった SPEEDBRAKE ARMED（45）も足し、配列の大きさを xt と同じにした。
  - 音（`fmod/747-400_custom.snd` と手元の `747-400.snd`、同じ内容）：`atc_chime` が 1 で操縦室のチャイム（`Warnings/ding_cockpit`、外部電源などと同じ音）を鳴らす。変更の前のバックアップは `D:\747-400-local-assets\backup_20261101_atc_chime\`。
- 推定：チャイムの音（資料は「低い音のチャイム」だけ）。>DATALINK LOST を一度つながった後の喪失に限った（つながる前の起動直後や、AutoATC の無い X-Plane で常に出ないように。FCOM は「通信の喪失で使えない」とだけ書く）。>DATALINK AVAIL の 60 秒。>DATALINK SYS は出さない（ACARS の故障の模型が無い）。
- 試験：新しい `tests/fms/datalink_eicas_test.lua`（22 件：AutoATC の dataref を模す。一度もつながっていなければ >DATALINK LOST なし、ACARS NO COMM はいつも 0。570 の未読の ATC のアップリンクで ATC MESSAGE とチャイム（1 秒）、ACARS MESSAGE は出ない、会社の ACARS で ACARS MESSAGE（チャイムなし）、読むと消える。109 は ATC のメッセージも ACARS MESSAGE で ATC MESSAGE とチャイムなし。つながってから切れると >DATALINK LOST、戻ると消えて >DATALINK AVAIL が 60 秒）。全 169 本。X-Plane：新しい `s190_datalink_eicas` 7/7（2026-11-01、X-Plane を起動し直した後の 4 便目。AutoATC の無いこの PC で、中央の RTP が ON でも ACARS NO COMM が出ない、>DATALINK LOST・AVAIL、ACARS MESSAGE、ATC MESSAGE、チャイムはどれも 0。上の EICAS の写真でもメモは PARK BRAKE SET だけ）。Log.txt に Lua と音の誤りなし。AutoATC が無いので、つながる側（ATC MESSAGE、チャイムの音、>DATALINK の advisory）は X-Plane で確かめていない。

## 112. 12d2 の実装（2026-11-01：MENU の <ACARS と ACARS の小さな直し）と段取りの直し

- 段取りの直し：12d2 に予定した残りは、作り直すページと一緒にやる方が二度手間にならないので移した。送信文を CDU ごとに（CDU-34）は、REQUEST・REPORT・EMERGENCY・POS REPORT のページを作り直す 12g へ。VERIFY TAIL NUMBER（LOGON/STATUS の TAIL NO）は 12e へ。CDU-42 のうち FMC COMM 2/2 の 1L と、AutoATC の接続中に ACP の MIC の選択を書き換える件は、会社のデータリンクの 12h へ。
- 資料：FCOM p.1323（MENU の <ACARS <REQ>：条件の印は無い）。
- 前のコード：MENU の <ACARS（と <REQ>）は ACARS がつながっていて中央の RTP が ON のときだけ出て、L2 もそのときだけ効いた（AutoATC の無いこの PC では出なかった）。POSTFLIGHT の LOGON のキーの名前が小文字の "l1" で、1L が効かなかった。AutoATC の `sendCompany` は未定義の大域の `fmsO` を使い、FLT NO などが無いと Lua の誤りになっていた。
- 作ったもの：
  - MENU（`B744.fms.pages.lua`）：<ACARS をいつも出し、L2 で ACARS のページ。<REQ> は未読の会社の ACARS のメッセージがあるとき（12d1 の ACARS MESSAGE のメモと同じ条件：`B747_fms_acars_unread`）。
  - POSTFLIGHT（`acars/acars.pages.lua`）：LOGON のキーを "L1" に。
  - `sendCompany`（`acars/autoatcProvider.lua`）：送る CDU を引数で受ける（`acars/acars.lua` の `acarsSystemSend` が渡す）。
- 推定：<REQ> の条件（FCOM は図に出すだけ）。
- 試験：`tests/fms/datalink_eicas_test.lua` に 8 件（MENU の <ACARS がつながっていなくても出る、未読の ACARS で <REQ>、読むと消える、<ACARS で ACARS-MAIN MENU、POSTFLIGHT の 1L で LOGON/STATUS、FLT NO の無い送信で誤りにならず NOT SET のメッセージ）。全 169 本。X-Plane：新しい `s191_menu_acars` 4/4（2026-11-01、X-Plane を起動し直した後の 5 便目。MENU に <ACARS で <REQ> なし、<ACARS で ACARS-MAIN MENU、POSTFLIGHT の 1L で ATC LOGON/STATUS。CDU の写真 2 枚）。Log.txt に Lua の誤りなし。

## 113. 12e の実装（2026-11-01：ATC のログオン）

- 前のコード：ATC キーはいつも ATC INDEX。LOGON/STATUS の 1L に施設を入れると、すぐに AutoATC へ REQUEST LOGON を送り（SEND の手順が無い）、FLT NO・出発地・目的地が無ければ FLT NO NOT SET・DEPARTURE NOT SET・DESTINATION NOT SET（Boeing に無い）。1R はプロバイダーの言葉（N/A、READY、ACCEPTED）、6R は OFFLINE・READY・ACTIVE、TAIL NO・ATC COMM の SELECT OFF・ADS は固定の文字で効かず、ATC COMM ESTABLISHED などの FMC のメッセージは出なかった。
- 資料：
  - FCOM p.755–757：LOGON/STATUS の形（1L LOGON TO・1R LOGON SEND>、2L FLT NO、3L TAIL NO・3R ACT CTR、4L ATC COMM・4R NEXT CTR、5L ADS・5R ADS EMERG、6L <INDEX・6R DATALINK）。LOGON TO は初め箱、4 文字の施設、施設と FLT NO があり datalink が READY なら 1R に SEND、削除で箱、ATC COMM の確立で dashes。FLT NO は RTE の。ATC COMM は確立中だけ SELECT OFF（押すと ATC DL の接続を切る）。ADS (ARM)・(ACT)・(OFF) と SELECT OFF・ARM、ADS EMERG の SELECT ON・OFF。SEND で SENT、ネットワークの応答が無ければ RESEND、ATC の応答で ACCEPTED か REJECTED。ACT CTR・NEXT CTR。DATALINK は READY・NO COMM・VOICE・FAIL。TAIL NO は FMC の登録記号、入力は 1〜7 文字。
  - FCOM p.1211：405・570 の ATC キーは ATC/ADS STATUS のページ。p.1431：ATC COMM ESTABLISHED（ATC COMM が使える、または新しい施設へ移った）、ATC COMM TERMINATED。p.1433：RE-LOGON TO ATC COMM。p.1436：VERIFY TAIL NUMBER（入れた登録記号が FMC の database と違う）。
  - FMSPG p.277–280：ATC キーはログオンが済むまで LOGON/STATUS。LOGON TO は位置か登録記号が無効なら空白、ACCEPTED と接続の要求が来るまで施設、その後は dashes、施設のあるときだけ削除できる。FLT NO は無効なら 8 個の箱、削除できず、接続中に新しい FLT NO を入れると ATC COMM とログオン中の AFN が切れる。ATC COMM SELECT OFF はログオン中のものは止めない。SEND・RESEND で AFN を送り、SENDING、ネットワークの応答で SENT、応答が無いか AFN の時間切れで RESEND、ACCEPTED（接続の要求が来るまで）、REJECTED。ACT CTR は接続のある間、NEXT CTR は分かるとき。ADS EMERG は ADS が ARM か ACT のとき。p.286：ログオンが済み、待ちのアップリンクが無ければ ATC キーで ATC INDEX。p.258：RE-LOGON TO ATC COMM は、時間内に応答が無い、否定の応答、NO COMM が 16 分続いて別の施設へ移らずに切れた、ログオン中の FLT NO の変更。
- 作ったもの：
  - `B747.68.atc_logon_model.lua`（新しい純粋なモデル）：LOGON TO の入力と削除、SEND の出る条件、SENDING・SENT・RESEND・ACCEPTED・REJECTED、接続と終わり、NEXT CTR、時間（ネットワークの応答 60 秒、AFN の応答 120 秒：推定、NO COMM 16 分）、FLT NO の変更、ADS の ARM・OFF と EMERG、ページの欄。
  - FMS のつなぎ（`B747.68.xt.fms.lua`）：AutoATC の取り決め（`acars/autoatcProvider.lua`）はそのまま。SEND で REQUEST LOGON を送り（`fmsModules` の "atc" はログオンか ATC COMM の間だけその施設、ほかは "****"）、プロバイダーがつながっていればネットワークの応答とする（推定）。受信の一覧の LOGON ACCEPTED で ACCEPTED と接続（AutoATC は 1 通：推定）、ATC COMM ESTABLISHED。LOGON REJECTED か UNABLE でログオン中なら REJECTED と RE-LOGON TO ATC COMM（推定）。SERVICE TERMINATED は ATC COMM の終わり（プロバイダーが NEXT CTR へ移る間は何も出さず、新しい接続で ATC COMM ESTABLISHED）。SELECT OFF は LOGOFF を送り ATC COMM TERMINATED。FLT NO の変更（RTE と LOGON/STATUS）は ATC COMM とログオン中のものを止める。ほかのページとプロバイダーのログオン（`acarsLogonATC`）もこのモデルを通す（4 文字でなければログオフ）。出発地と目的地はもう要らない。TAIL NO は X-Plane の登録記号（`sim/aircraft/view/acf_tailnum` の英数字）、入力が違えば VERIFY TAIL NUMBER。位置は IRU か GPS が航法のモードなら有効。
  - FMC のメッセージ（`B744.createfms.lua`）：出来事のメッセージを文字で出す `B747_cdu_fmc_event`（ATC COMM TERMINATED は旗の一覧に無い）。
  - ATC キー（`B744.createfms.lua`）：ATC COMM が無ければ LOGON/STATUS、あれば ATC INDEX（待ちのアップリンクのページは 12f）。
  - LOGON/STATUS（`activepages/atc/B744.fms.pages.atclogonstatus.lua`）：FCOM p.755 の形。
- 推定：時間の長さ（60 秒、120 秒）。ACT CTR・NEXT CTR・ATC COMM の見出しは欄が空白なら空白。TAIL NO の削除はできない（INVALID DELETE）。AutoATC の言葉の当てはめ（LOGON ACCEPTED を AFN の受け入れと接続の要求の両方、LOGON REJECTED・UNABLE を否定の応答）。ADS は状態の表示と切り替えだけ（ADS の接続と報告は 12h）。
- 試験：新しい `tests/fms/atc_logon_model_test.lua`（53 件：LOGON TO の入力・削除・箱・空白、SEND の条件、SENDING・SENT・ACCEPTED・接続・dashes・ACT CTR・NEXT CTR・TERMINATED、60 秒の RESEND、120 秒の RE-LOGON、REJECTED、NO COMM 16 分、READY で数え直し、FLT NO の変更、接続中の新しい施設、ADS）、新しい `tests/fms/atc_logon_pages_test.lua`（48 件：AutoATC を模す。ATC キーで LOGON/STATUS、各行、NO COMM では SEND> なし、READY で SEND>、SEND で "atc" と SENT、LOGON ACCEPTED で dashes・ACT CTR・<SELECT OFF・ATC COMM ESTABLISHED、NEXT CTR、ATC キーで ATC INDEX、SELECT OFF で ATC COMM TERMINATED と "****"、プロバイダーの NEXT CTR への移りで TERMINATED を出さず新しい ESTABLISHED、新しい FLT NO で切れる、LOGON REJECTED で REJECTED と RE-LOGON、120 秒の RESEND> と RE-LOGON、TAIL NO の VERIFY TAIL NUMBER と INVALID ENTRY、ADS）、`datalink_keys_test.lua` と `fmc_fixes_test.lua` は ATC キーが LOGON/STATUS を開く形に。全 171 本。X-Plane：新しい `s192_atc_logon` 14/14（2026-11-01、起動し直す前の 6 便目。AutoATC の無いこの PC で、SIM CONFIG の FMC DATALINK ON のとき ATC キーで LOGON/STATUS、箱、TAIL NO は X-Plane の登録記号 N721PC、NO COMM、RJJJ と TEST123 で SEND> なし、JA8071 で VERIFY TAIL NUMBER、ADS の切り替え、<INDEX で ATC INDEX。CDU の写真 2 枚）。ATC キーの手順を直した `s181_datalink_keys` 12/12、`s79_fmc_fixes` 34/34（起動し直した後）。Log.txt に Lua の誤りなし。AutoATC が無いので、つながる側（SEND から ESTABLISHED まで）は X-Plane で確かめていない。

## 114. 12f の実装（2026-11-01：ATC のアップリンク）

- 前のコード：ATC のアップリンクは ACARS の汎用の表示（ACARS-MESSAGE、REPLY> で返信の文を書く）で見ていた。XXXXZ ATC UPLINK・VERIFY RESPONSE のページは無く、REJECT DUE TO は固定の文字で読み込まれていなかった。ATC キーはいつも ATC INDEX（12e で LOGON/STATUS を足した）。
- 資料：
  - FCOM p.758–761：XXXXZ ATC UPLINK（題は受信の時刻、1/X の 1R に STATUS、2〜5 行に本文、続くなら CONTINUED、6R に LOG（報告などの要求があれば REPORT）。最後のページに STANDBY（応答が要る間）、REJECT（UNABLE か NEGATIVE が有効な間）、ACCEPT（WILCO・ROGER・AFFIRM が有効な間）、LOAD（読み込めるデータ）、ARM（報告の待機）、PRINT）。ATC キーは、新着か待ちのアップリンクが 1 通だけならそのページ。
  - FCOM p.752–754：ATC LOG の状態（アップリンク：NEW・OLD・OPEN・ACCEPTED・REJECTED・ABORTED）。ATC キーは新着が 2 通以上か、新着が無く待ちが 2 通以上なら ATC LOG。
  - FCOM p.762–765：REJECT DUE TO（DUE TO PERFORMANCE・WEATHER は初め小字、押すとその要素を入れる、2〜5 行の自由文、<UPLINK、VERIFY>）。VERIFY RESPONSE（1L に ROGER・WILCO・AFFIRM・UNABLE・NEGATIVE・STANDBY、2〜5 行に自由文、6L は UPLINK か REJECT DUE TO、STATUS ACCEPTED は ATC が受け取ったとき、RESPONSE SEND で SENDING、ネットワークの応答が無ければ RESEND、データリンクが READY で ATC の接続が無ければ NO ATC COM、故障なら DATA LINK の見出しと NO COMM など）。
  - FMSPG p.286–291：ログオン後で待ちのアップリンクが無ければ ATC キーで ATC INDEX。ATC LOG の右の LSK、VERIFY RESPONSE・REJECT DUE TO の UPLINK からもこのページ。STANDBY の送信はアップリンクを閉じない。REJECT を選ぶと LOAD を消す。
  - 応答の種類を決める FANS のメッセージの要素の属性（W/U、A/N、R）は資料に無い。
- 作ったもの：
  - `B747.68.atc_uplink_model.lua`（新しい純粋なモデル）：本文の言葉からの応答の種類（指示は WILCO/UNABLE、CAN YOU などの問いは AFFIRM/NEGATIVE、ATC の答え（UNABLE、STANDBY、REQUEST DEFERRED など）は応答なし、ほか（EXPECT、REPORT、自由文）は ROGER：推定）、状態（NEW・OLD・OPEN・ACCEPTED・REJECTED・ABORTED）、24 文字での折り返し、ページ割り（1 ページ目は本文 8 行と CONTINUED、間のページは 10 行、最後は 6 行と応答、4 行に収まれば 1 ページ：推定）、ATC キーの行き先。
  - FMS のつなぎ（`B747.68.xt.fms.lua`）：プロバイダーの受信の一覧の ATC のメッセージ（cpdlc。ログオンの LOGON ACCEPTED などは除く）を、一覧の場所で状態を持つ。見たら reviewed（12d1 の ATC MESSAGE のメモと同じ read）。応答はプロバイダーへ前のとおり（cpdlc、RT にアップリンクの ID）、プロバイダーがつながっていればネットワークの応答とする（推定）。ATC COMM が終われば待ちのものは ABORTED。CDU ごとの VERIFY RESPONSE の応答と REJECT DUE TO の理由・自由文。メッセージの欄は名前空間の表の無いキーを読まないように読む。
  - ページ（`activepages/atc/B744.fms.pages.atcuplink.lua`、`B744.fms.pages.atcrejectdueto.lua` を作り直して読み込む）：XXXXZ ATC UPLINK、VERIFY RESPONSE、REJECT DUE TO。
  - ATC キー（`B744.createfms.lua`）：ATC COMM が無ければ LOGON/STATUS、新着か待ちが 1 通だけならそのアップリンク、多ければ ATC LOG、ほかは ATC INDEX。ATC LOG とメッセージの一覧からの選択（`showmessage`）も、FMC のデータリンクのある機体の ATC のアップリンクならこのページへ。
  - 前の ATC LOG（`acars/acars.lua`）：メッセージの欄を安全に読むように（"rr" の無い ATC のアップリンクでページが空白になっていた）。ATC LOG の作り直しは 12g。
- 推定：応答の種類の言葉、ページの行の割り付け、STATUS ACCEPTED の位置、PRINT は出さない（プリンターの模型が無い）、新着 1 通とほかの待ちがあるときは新着のページ。まだ作っていないもの：<REQUEST、LOAD、ARM、REPORT（12g の後）。
- 試験：新しい `tests/fms/atc_uplink_model_test.lua`（49 件：応答の種類、ACCEPT と REJECT の言葉、状態の移り、STANDBY は OPEN のまま、折り返し、ページ割り、ATC キーの行き先）、新しい `tests/fms/atc_uplink_pages_test.lua`（47 件：AutoATC を模してログオンし、CLIMB TO の新着で ATC MESSAGE、ATC キーで 1428Z ATC UPLINK、STATUS OPEN、本文、STANDBY・REJECT・ACCEPT、LOG>、見ると ATC MESSAGE が消える。ACCEPT で VERIFY RESPONSE の WILCO と SEND>、SEND でプロバイダーへ WILCO と RT、SENT と STATUS ACCEPTED、アップリンクは ACCEPTED で応答なし、ATC キーで ATC INDEX。CAN YOU の REJECT で REJECT DUE TO、PERFORMANCE と自由文、VERIFY で NEGATIVE と理由、送ると REJECTED。EXPECT は ROGER だけ、STANDBY で OPEN のまま。新着 2 通で ATC LOG。長い本文は 1/2 と CONTINUED、2 ページ目に応答。ATC COMM が終わると ABORTED）。全 173 本。X-Plane：新しい `s193_atc_uplinks` 6/6（2026-11-01、起動し直した後の 4 便目。AutoATC の無いこの PC で、FMC DATALINK ON のとき ATC キーで LOGON/STATUS、ATC INDEX の <LOG で ATC LOG が描ける、<INDEX で ATC INDEX）。Log.txt に Lua の誤りなし。アップリンクが届く側は X-Plane で確かめていない（AutoATC が無い）。

## 115. 12g の分け方と 12g1 の実装（2026-11-01：ATC LOG）

- 分け方：12g（ATC の残り）を、12g1（ATC LOG）、12g2（REQUEST のページ：要素、VERIFY REQUEST、送信）、12g3（REPORT・POS REPORT・ARM・WHEN CAN WE）、12g4（EMERGENCY）に分ける。送信文を CDU ごとに（CDU-34）は、それぞれのページを作り直すときに入れる。
- 前のコード：ATC INDEX の <LOG と ATC キーの LOG は ACARS の一覧（会社のメッセージも、送ったものも混ぜ、状態は REPLY REQUIRED・NEW・OLD など）を開いた。
- 資料：
  - FCOM p.752–754：ATC LOG は記録したアップリンクとダウンリンク。本文は長ければ 2 つのピリオドで省く。左の LSK の DELETE でその記録を消す。題（見出し）は受信か送信の時刻。状態はアップリンク 6 つ・ダウンリンク 7 つ。ERASE LOG で閉じた（待ちでない）記録を消す準備をして CONFIRM、離れると取り消す。
  - FMSPG p.357–362：新しい順に 1 ページ目の 1 行目から。時刻は左の見出し、上か下の矢印、本文の先頭 19〜21 文字、状態は右の見出し。右の LSK で対応するページ。6L <INDEX、6R ERASE LOG>・CONFIRM>（閉じた記録が無いか印刷中なら空白）。記録はアップリンク 10 通（待ち 5・待ちでない 5）とダウンリンク 5 通まで、満ちれば古いものから消える。
  - FCOM p.765：RESPONSE SEND は送った応答を ATC LOG に記録する。
- 作ったもの：
  - `B747.68.atc_log_model.lua`（新しい純粋なモデル）：消したものを除いた新しい順、5 件ずつのページ、データ行（21 文字まで、長ければ 19 文字と ".."、右端に >）、見出し（時刻 HHMMZ と状態）、ERASE LOG の出る条件。
  - FMS のつなぎ（12f のアップリンクのつなぎ）：アップリンクは初めて見た順、ダウンリンク（ここから送った応答）は送った順の番号を持ち、ATC LOG の記録にする。応答の状態は SENDING から、ネットワークの応答で SENT（応答の要らないダウンリンク：FCOM p.754）、ATC COMM の終わりで送りかけは ABORTED。記録の削除と、待ちでないものの消去。消したアップリンクは ATC キーの行き先からも除く。
  - ATC LOG のページ（`activepages/atc/B744.fms.pages.atclog.lua`）。ATC INDEX の <LOG、ATC キーの LOG、アップリンクのページの LOG> をこのページへ。
- 推定：上下の矢印を出さない（CDU の字に無いため）。ダウンリンクは今はここから送った応答だけ（要求・報告は 12g2・12g3 で足す）、その右の LSK はまだどこへも行かない。記録の数の上限と自動の削除は作っていない。
- 試験：新しい `tests/fms/atc_log_model_test.lua`（13 件：消したものを除く、新しい順、21 文字と 19 文字＋".."、見出しの時刻と状態、ERASE LOG の条件、5 件ずつのページ）、`tests/fms/atc_uplink_pages_test.lua` に 17 件（待ちが多いとき ATC キーで ATC LOG、新しい順、省いた本文と >、時刻と状態、2 ページ、WILCO の応答が SENT のダウンリンク、右の LSK でアップリンクのページと LOG> で戻る、DELETE で 1 件消える、ERASE LOG・CONFIRM、ページを離れると ERASE LOG に戻る、待ちでないものが消え、消すものが無ければ空白）。全 174 本。X-Plane：`s193_atc_uplinks` 6/6（ATC INDEX の <LOG で新しい ATC LOG。起動し直した後の 5 便目）。Log.txt に Lua の誤りなし。

## 116. 12g2 の分け方と 12g2a の実装（2026-11-01：ATC の要求）

- 分け方：12g2（REQUEST）を、12g2a（高度・速度・オフセット・DIRECT TO・HEADING・GROUND TRACK の要求、ATC INDEX の CLEARANCE と VOICE、VERIFY REQUEST、送信、XXXXZ ATC REQUEST）と 12g2b（ROUTE REQUEST の RTE 1・RTE 2 と DEP/ARR）に分ける。WHEN CAN WE の VERIFY REQUEST は 12g3。
- 前のコード：要求のページは FMS のデータの欄（acarsREQALT など）に書いて読むだけで、入力の確かめが無かった（速度は "." を付けて表示するだけ、高度は上昇か降下かを VERIFY の描画のたびに決めた）。VERIFY REQUEST は描画のたびに共有の送信文 `acarsMessage` に書き、3 台の CDU が毎フレーム描くので、最後に描いた CDU の文が送られた（CDU-34）。ATC INDEX の CLEARANCE> と VOICE> は同じ VERIFY REQUEST（要求のページの文）を開いた。
- 資料：
  - FCOM p.736–747：ATC REQUEST（ALTITUDE・SPEED・OFFSET、<ROUTE REQUEST、<ERASE REQUEST、<INDEX、VERIFY>）。ATC ALT/SPEED/OFFSET/ROUTE REQUEST 1/4〜4/4 の欄と選択（押すと大きい字）。VERIFY REQUEST（要素の行と自由文、REQUEST SEND：SENDING、RESEND、DATA LINK の NO COMM、NO ATC COMM。6L は来たページにより REQUEST・INDEX・WHEN CAN WE）。XXXXZ ATC REQUEST（送った時刻、1L <UPLINK、1R STATUS、本文、応答の時刻の行、LOG>）。オフセットは「L（R）XX、または XX だけ」（p.737）。
  - FMSPG p.298–327：要素は 5 つまで（MSG LIMIT EXCEEDED）。高度の範囲（フィート 0〜25,000、FL030〜最大運用高度、メートル 0〜16,000）、ブロックはフィートか FL。入力の時点の高度との差で水平（150 ft 以内）・CLIMB TO・DESCENT TO・BLOCK の要素を選ぶ。STEP AT は上昇か降下の単一高度で CRZ CLB の前だけ、CRZ CLB は 150 ft より上の単一高度で STEP AT が無いときだけ。高度・速度・オフセットを消すとその理由も消える。速度は IAS 100〜380（10 kt に丸め）か Mach .61〜.91（.01 に丸め）。OFFSET AT と DUE TO WEATHER（WEATHER DEVIATION UP TO）は一方だけ。位置はフィックス・航法援助施設・空港・緯度経度・PBD（重複は SELECT DESIRED WPT）、時刻は hhmm。HEADING・GROUND TRACK は 000〜360。SENDING の間は欄を変えられない。ネットワークの受け取りで VERIFY REQUEST から XXXXZ ATC REQUEST へ。5R の状態の表（p.365：要素が無ければ空白、NO ATC COMM、NO COMM、RESEND>（時間切れで変更なし）、SEND>、SENDING）。図：p.301・306・310・313・324・326、CLEARANCE と VOICE は p.299–300（自由文の行は「<」、要素の後から 4 行目まで、見出し FREE TEXT）。
  - FCOM p.753–754：ダウンリンクの状態（SENDING、NO ACK、SENT、OPEN、DEFERRED、RESPONSE RCVD、ABORTED）。FCOM p.759：アップリンクのページの 1L <REQUEST（要求への応答のとき）。
- 作ったもの：
  - `B747.68.atc_request_model.lua`（新しい純粋なモデル）：要求のデータ（REQUEST・CLEARANCE・VOICE の 3 種）、入力の確かめと丸め、選択と DELETE（従うものも消す）、5 要素の上限、要素の文と行（固定の語は見出しの小さい字、値は大きい字、2 つ目からの要素は "/"）、自由文の行の数、送る文、VERIFY REQUEST と送ったページの行とページ分け。
  - FMS のつなぎ：要求は FMC に 1 つずつ（どちらの CDU でも同じものを見て変える）。送る文は SEND の時点でデータから組み立てる（CDU-34 の直し）。プロバイダへ cpdlc・RR Y で送り、ATC LOG に記録。ネットワークの受け取りは、プロバイダが実際に送り出したとき（キューは 15 秒に 1 通）。そこで OPEN にし、その要求の VERIFY REQUEST を出している CDU を XXXXZ ATC REQUEST へ、要求のデータは消す。60 秒（ログオンの ACK_S）で受け取りが無ければ NO ACK、変えていなければ RESEND>。ATC の応答（RT が要求の ID）で、STANDBY は OPEN のまま、REQUEST DEFERRED は DEFERRED、ほかは RESPONSE RCVD。ATC COMM の終わりで待ちの要求（SENDING・OPEN・DEFERRED）は ABORTED。
  - ページ（`activepages/atc/B744.fms.pages.request.lua` を作り直し）：ATC REQUEST、ATC ALT/SPEED/OFFSET/ROUTE REQUEST（NEXT と PREV で回る）、VERIFY REQUEST（CONTINUED、自由文、5R の状態）、XXXXZ ATC REQUEST。ATC INDEX の CLEARANCE> と VOICE> はそれぞれの VERIFY REQUEST（6L <INDEX）。アップリンクのページに 1L <REQUEST、ATC LOG の要求の右の LSK はその XXXXZ ATC REQUEST へ。
- 推定：
  - 値の無い要素の行の分け方（AT PILOTS DISCRETION は見出しだけ、MAINTAIN OWN SEPARATION AND VMC は見出し 2 行、WEATHER DEVIATION UP TO は見出し 2 行で値は 2 行目）。ブロックは REQUEST BLOCK と TO の 2 行。
  - 送る文は要素の語を空白でつないだもの（前の AutoATC 向けの略語 CLB・DES・HDG・TRK はやめた。AutoATC が受け付けるかはこの PC では確かめられない）。速度は IAS が 350KT、Mach が .86。時刻は 1234Z。
  - ネットワークの受け取りをプロバイダの送り出しとした。送った要求のデータは受け取りで消す。RESEND は同じ ATC LOG の記録を使う。NO ACK の時間はログオンと同じ 60 秒。
  - 選べないときの CRZ CLB の LSK は何もしない（STEP AT の入力は INVALID ENTRY）。ブロックは低い方が先。自由文は 1 行 24 文字まで、入れた行は「<」を出さない。自由文は 5 要素の数に入れない。
  - PRINT は出さない（プリンタが無い。アップリンクのページと同じ）。位置は入れた文字のまま送る（緯度経度・PBD も）。
- まだのもの：RTE 1・RTE 2・DEP/ARR の要求（12g2b）、WHEN CAN WE からの VERIFY REQUEST（12g3）。
- 試験：新しい `tests/fms/atc_request_model_test.lua`（94 件：入力の形と範囲と丸め、入力の時点の高度による要素、STEP AT と CRZ CLB、OFFSET AT と WEATHER、DELETE で従うものも消える、5 要素の上限、FCOM p.744 と FMSPG p.324 の例の行、CLEARANCE と VOICE、自由文の行の数、送ったページのページ分け）、新しい `tests/fms/atc_request_pages_test.lua`（128 件：4 つのページの表示と入力、データベースの位置と SELECT DESIRED WPT、MSG LIMIT EXCEEDED、NEXT と PREV、VERIFY REQUEST の行と CONTINUED と自由文、SEND とプロバイダの送り出しでの受け取り、XXXXZ ATC REQUEST、応答の RESPONSE RCVD と <UPLINK・<REQUEST、ATC LOG の右の LSK、CLEARANCE と VOICE、STANDBY と REQUEST DEFERRED、ABORTED、NO ATC COMM、NO COMM、NO ACK と RESEND>）。全 176 本が通る。X-Plane の新しい `s194_atc_requests` 23/23（AutoATC の無いこの PC で、ページの表示と入力、VERIFY REQUEST の行と CONTINUED、DATA LINK NO COMM、ERASE REQUEST、VOICE。CDU の写真は FMSPG の図と同じ配置）、Log.txt に Lua の誤りなし。

## 117. 12g2b の実装（2026-11-01：経路の要求）

- 資料：
  - FCOM p.742–743：ATC ROUTE REQUEST 4/4 の REQUEST RTE 1・RTE 2（保留の修正があればその経路を要求）と DEP/ARR（DEP/ARR のページの選択か入力、押すと大きい字で要素を選ぶ、消せる）。
  - FMSPG p.315–318：REQUEST ROUTE CLEARANCE（RTE 1 か RTE 2 の飛行計画のデータ）、片方を選ぶともう一方は空白。DEP/ARR は地上では DEPARTURES で選んだ出発の手続き（と遷移）、空中では ARRIVALS で選んだ到着か進入（と遷移）を prompt つきで出し、それを押すか手続きを入れると REQUEST [procedure name]、選んでいなければ dashes。SENDING の間は 3L・5L・3R を変えられない。図は p.316（REQUEST <RTE 1・RTE 2>、REQUEST DEP/ARR）。
- 作ったもの：
  - `B747.68.atc_request_model.lua`：RTE 1 と RTE 2 の選択（一方だけ、経路の文を持つ）、DEP/ARR の手続き、手続きの名前の形、要素の文と行（REQUEST ROUTE CLEARANCE の見出しの行に経路の文の 1 行目、続きはその下の行）。
  - FMS のつなぎ：経路の文（出発地、滑走路、SID と遷移、各区間の航空路と TO の点（DIRECT は点だけ。手続きの脚、不連続、TO の無い航空路は除く）、STAR と遷移、進入（CDU の名前）と遷移、目的地。修正があれば修正の経路）。VERIFY と SEND のときに、選んだ経路の文を今の経路で作り直す。DEP/ARR の既定（地上は SID、空中は STAR、無ければ進入）。入れた手続きの確かめ（アクティブな経路の出発地の SID、目的地の STAR と進入、遷移は enroute の遷移）。
  - ページ：ATC ROUTE REQUEST 4/4 の 3L・3R（小さい字と caret、選ぶと大きい字、もう一方は見出しごと空白）、5L（既定は小さい字と caret、入れたものと押したものは大きい字、無ければ dashes）。
- 推定：経路の文の形（FANS の route clearance のデータを文にしたもの。航空路の名前と点を並べ、DIRECT は書かない）、空中で STAR と進入の両方を選んでいるときは STAR、dashes の数（5）、手続きの名前の長さ（7 文字、遷移 5 文字）、出発地と目的地に無い手続きは NOT IN DATA BASE、要素の並び（DIRECT TO、経路、手続き、HEADING、GROUND TRACK）、空の RTE 2 を押しても何もしない。
- 試験：`tests/fms/atc_request_model_test.lua` に 17 件（RTE 1 と RTE 2 の排他、経路の文と行、今の経路への作り直し、DELETE、手続きの形、REQUEST [procedure name]、要素の並び）、`tests/fms/atc_request_pages_test.lua` に 23 件（4/4 の見出しと prompt、空の RTE 2、RTE 1 の選択と RTE 2 の空白、SID の既定、無い遷移の NOT IN DATA BASE、押して大きい字、VERIFY REQUEST の REQUEST ROUTE CLEARANCE と今の経路の文、/REQUEST ZULU1.ALPHA、送る文、受け取りで消える、手続きの入力と DELETE）。RESEND の受け取りはプロバイダのキュー（15 秒に 1 通）の分だけ遅れるので、試験の待ちを 31 秒にした。全体の試験はすべて通る。X-Plane：新しい `s195_atc_route_request` 15/15（RTE 1 に RJAA から RJBB、4/4 の REQUEST <RTE 1・RTE 2> と DEP/ARR の dashes、RTE 1 の選択と RTE 2 の空白、VERIFY REQUEST の REQUEST ROUTE CLEARANCE と RJAA RJBB、DATA LINK NO COMM、ERASE REQUEST。CDU の写真は FMSPG p.316 の図と同じ配置）、Log.txt に Lua の誤りなし

## 118. 12g3 の分け方と 12g3a の実装（2026-11-01：WHEN CAN WE EXPECT）

- 分け方：12g3 を 12g3a（WHEN CAN WE EXPECT）、12g3b（POS REPORT）、12g3c（ATC REPORT・VERIFY REPORT・ARM、報告と確認の要求への応答）に分ける。
- 前のコード：WHEN CAN WE EXPECT のページは FMS のデータの欄（acarsWCW*）に書くだけで入力の確かめが無く、速度は "." を付けて出した。HIGHER ALT・LOWER ALT・BACK ON RTE は押すとすぐ専用の VERIFY のページへ行き、そのページは描画のたびに共有の送信文に書いた（CDU-34）。文の語も CRUISE ALTITUDE・DESCEND TO・HIGHER ALT と FANS の語と違った。
- 資料：
  - FCOM p.769–770：1L CRZ CLB TO・2L CLIMB TO・3L DESCENT TO（XXX・FLXXX・XXXXX・XXXXXm の高度）、4L SPEED（IAS か Mach）、5L ERASE WHEN CAN WE、6L INDEX、2R HIGHER ALT、3R LOWER ALT、4R BACK ON RTE、6R VERIFY。FCOM p.745：VERIFY REQUEST の 6L は WHEN CAN WE から来たら <WHEN CAN WE。
  - FMSPG p.319–323：文は WHEN CAN WE EXPECT CRUISE CLIMB TO [altitude]・CLIMB TO [altitude]・DESCENT TO [altitude]・[speed]・HIGHER ALTITUDE・LOWER ALTITUDE・BACK ON ROUTE。1L〜3L・2R・3R は一つだけで、ほかは空白。高度と速度の範囲は ATC REQUEST と同じ。ERASE WHEN CAN WE は何かあるときだけ。SENDING の間は変えられない。
- 作ったもの：
  - `B747.68.atc_request_model.lua`："WCW" の種類（欄、縦の問いの排他、文と VERIFY REQUEST の行）。
  - FMS のつなぎ：WCW の下書き（FMC に 1 つ、送る文は SEND の時点で組み立てる：CDU-34）。送信・受け取り・応答の状態は ATC の要求と同じ。
  - ページ：WHEN CAN WE EXPECT を作り直した（`activepages/atc/B744.fms.pages.whencanwe.lua`）。VERIFY REQUEST の 6L を来たページ（REQUEST・INDEX・WHEN CAN WE）に。
- 推定：VERIFY REQUEST の行の分け方（WHEN CAN WE EXPECT を見出しに、問いをその下の行に、速度は同じ行）、IAS の KT を小さい字で。
- 試験：`tests/fms/atc_request_model_test.lua` に 13 件（縦の問いの排他、ブロックは不可、文と行、DELETE で戻る、ERASE）、`tests/fms/atc_request_pages_test.lua` に 18 件（ページの形、CLIMB TO で CRZ CLB TO と HIGHER ALT が消える、SPEED と BACK ON RTE、ERASE の prompt、VERIFY REQUEST の行と <WHEN CAN WE、送る文、受け取りで消える、<WHEN CAN WE で戻る）。全体の試験はすべて通る。X-Plane：新しい `s196_atc_whencanwe` 17/17（ATC INDEX の WHEN CAN WE> でページ、CLIMB TO の入力で CRZ CLB TO と HIGHER ALT が消える、SPEED と BACK ON RTE、VERIFY REQUEST の WHEN CAN WE EXPECT と 6L <WHEN CAN WE、DATA LINK NO COMM、ERASE WHEN CAN WE。CDU の写真は FCOM p.769 の形）、Log.txt に Lua の誤りなし

## 119. 12g3b の実装（2026-11-01：POS REPORT）

- 前のコード：POS REPORT のページは描画のたびに共有の送信文に書き（CDU-34）、点は前の ND の dataref から取り、SEND> は ATC REPORT のページへ行くだけで送らなかった。COMPANY の <SEND は無かった。
- 資料：
  - FCOM p.766–768：題は便名と POS REPORT。LAST・ATA・ALT・SPD・TO・ETA・NEXT・DEST ETA・TEMP・WIND・FUEL。TO・NEXT・SPD・ETA・DEST ETA は入力で上書きし、DELETE で既定へ、SPD はページを離れても既定へ。ATC SEND と COMPANY SEND（会社へは既定の値）、SENDING・RESEND・NO ATC COMM・DATA LINK の NO COMM。FUEL は LAST の点での CALCULATED と TOTALIZER の小さい方。
  - FMSPG p.340–343：入力は ATC への報告だけに効く。FUEL は ATC への報告に入らない。SPD は速度テープの Mach の目標。オフセット中は DEVIATING [offset] OF ROUTE、MCP の高度が 150 ft より離れていれば CLIMBING TO か DESCENDING TO [altitude] を足す。
- 作ったもの：
  - `B747.68.atc_posrep_model.lua`（新しい純粋なモデル）：入力と既定の重ね合わせ、DELETE、ページを離れたときの SPD、ページの文字、ATC と会社への報告の文。
  - FMS のつなぎ：既定の値（LAST と ATA は PROGRESS 1/3 と同じ、TO・NEXT とその ETA・DEST ETA はアクティブな経路と予測、ALT は CDU の高度の形、SPD は A/P の速度の目標、TEMP は SAT、WIND は真方位、FUEL は CALCULATED と TOTALIZER の小さい方）。ATC への報告は応答の要らない cpdlc で ATC LOG に記録し、プロバイダが送り出したら SENT。会社への報告は telex（プロバイダが FLT NO などで断ればそのメッセージ）。60 秒で NO ACK と RESEND。
  - ページ：XXXX POS REPORT を作り直した（`activepages/atc/B744.fms.pages.posreport.lua`）。TO・NEXT の入力は RTE と同じ確かめ（B747_fmc_with_fix）。
- 推定：報告の文の語と並び（FANS の位置通報のデータを文にしたもの）、IAS を 290KT と出す、WIND の列、DATA LINK の見出しを出さない（6 行目の見出しに COMPANY と ATC があるため）、会社への報告は ATC LOG に入れない（FCOM p.768 は COMPANY SEND でも ATC LOG の記録と書くが、会社の通信のため）、TO・NEXT の入力はデータベースの点（FCOM。FMSPG はアクティブな経路の点）、ATC LOG の報告の右の LSK は 12g3c の XXXXZ ATC REPORT で。
- 試験：新しい `tests/fms/atc_posrep_model_test.lua`（19 件：入力の重ね合わせ、文字、ATC と会社の文、DEVIATING・CLIMBING TO・DESCENDING TO、DELETE、ページを離れたときの SPD）、`tests/fms/atc_request_pages_test.lua` に 19 件（題、見出し、ALT・TO・NEXT、ETA・SPD・TO の入力、データベースに無い NEXT、ATC SEND の文と応答の要らないこと、受け取りで SEND> に戻る、ATC LOG の SENT、DELETE、ページを離れたときの SPD）。全体の試験はすべて通る。X-Plane：新しい `s197_atc_posreport` 13/13（RTE 1 をアクティブに、題の TBC123 POS REPORT、見出し、TO の XAC と NEXT の SPENS、COMPANY と ATC の行、NO COMM、ETA と SPD の入力、ページを離れると SPD が FMC の値。CDU の写真は FCOM p.766 の形で、度の記号も出る）、Log.txt に Lua の誤りなし

## 120. 12g3c の実装（2026-11-01：ATC REPORT・VERIFY REPORT・ARM）

- 前のコード：ATC REPORT は固定の絵（題も ATC INDEX のまま、CONFIRM ALTITUDE などの行は押しても何も無い）、VERIFY REPORT と XXXXZ ATC REPORT は無く、アップリンクのページに REPORT> と ARM> は無かった。
- 資料：
  - FCOM p.748–751：ATC REPORT（1L ATC RTE REPORT、1R FREE TEXT>、報告や確認の要求の一覧、長い文は 2 つのピリオド、arm したものは ARMED）、VERIFY REPORT（文と入力の欄、箱は入力が必要、CANNOT ACCEPT、ARM>、FREE TEXT、REPORT SEND>、6L <REPORT）。FCOM p.759–761：アップリンクのページの 6R は報告を求めるなら REPORT>、arm できる報告なら ARM>・ARMED（DELETE で外す）。
  - FMSPG p.292：アップリンクのページの ARM> は状態が OLD か ACCEPTED のとき。FMSPG p.328–337：報告の一覧（9 件まで、満ちれば REPORT LIST FULL、アップリンクが待ちでなくなってから入る、送ったものは消える、POSITION REPORT を送ると最も古い REQUEST POSITION REPORT が消える）と、要求ごとの報告の文と既定の値・入力（表 8.6-1）、入力の形（表 8.6-2）。FMSPG p.338–340：RTE REPORT（ASSIGNED ROUTE RTE X と経路）、FREE TEXT、CANNOT ACCEPT、ARM（LEVEL・REACHING・PASSING の 3 つ、条件が来たら自動で送る）。
- 作ったもの：
  - `B747.68.atc_report_model.lua`（新しい純粋なモデル）：アップリンクの文から要求を見つける（25 種）、報告の要素と行（固定の語は見出し、値は大きい字、入力が要れば箱、CLIMBING・DESCENDING TO、DEVIATING）、入力の形、DELETE、CANNOT ACCEPT、ARM と条件、送る文。
  - FMS のつなぎ：報告の既定の値（高度、MCP の高度、経路、オフセット、TO・NEXT・ETA、現在位置、最後の点と ATA、速度、磁方位、対地の針路、燃料の残り時間、時刻）、報告の一覧、送信（cpdlc、応答なし、RT はアップリンクの ID）と ATC LOG、受け取りで一覧から消す、arm した報告の条件の確かめ（毎フレーム）、POS REPORT との連携。
  - ページ：ATC REPORT・VERIFY REPORT・XXXXZ ATC REPORT を作り直した（`activepages/atc/B744.fms.pages.atcreport.lua`）。アップリンクのページに REPORT> と ARM>、ATC LOG の報告の右の LSK で XXXXZ ATC REPORT。
- 推定：アップリンクの文の形（FANS の語）、arm の条件の幅（REACHING と LEVEL は高度の ±200 ft、LEVEL は昇降率 300 fpm 未満）、行の分け方、ARM と ARMED の字の大きさ、位置の入力はアクティブな経路の点だけ（FMSPG p.336）、送ったら VERIFY REPORT の CDU は ATC REPORT へ、REPORT・CONFIRM・WHEN CAN YOU ACCEPT のアップリンクの応答の種類は 12f のまま（ROGER の後で一覧に入る）。
- 試験：新しい `tests/fms/atc_report_model_test.lua`（58 件）、`tests/fms/atc_request_pages_test.lua` に 36 件（アップリンクの REPORT>、OPEN では ARM> が無い、ACCEPTED で ARM> と ARMED、ATC REPORT の一覧と ARMED、VERIFY REPORT の行と SEND、上昇で到達して自動で送る、受け取りで一覧から消える、ATC LOG、CONFIRM SQUAWK の箱と入力、WHEN CAN YOU ACCEPT の CANNOT ACCEPT、FREE TEXT）。全体の試験はすべて通る。X-Plane：新しい `s199_atc_report` 13/13（2026-11-01、X-Plane を起動し直した後の 6 便目。RJAA の地上で ATC REPORT の題、<RTE REPORT と FREE TEXT>、空の一覧、FREE TEXT> の VERIFY REPORT（FREE TEXT の見出し、DATA LINK NO COMM）、<RTE REPORT の ASSIGNED ROUTE・RTE 1・経路の文 RJAA XAC SPENS RJBB。CDU の写真 2 枚）。Log.txt に Lua の誤りなし

## 121. 12g4 の実装（2026-11-01：EMERGENCY）

- 前のコード：EMERGENCY REPORT は FMS のデータの欄に書くだけで入力の確かめが無く、VERIFY EMERGENCY は描画のたびに共有の送信文に書いた（CDU-34）。CANCEL EMERGENCY、非常の状態、ATC キーの長押し、XXXXZ EMERGENCY は無かった。
- 資料：
  - FCOM p.728–733：EMERGENCY REPORT（<MAYDAY と PAN>、DIVERT TO はアクティブな目的地、OFFSET、DESCEND TO は MCP の高度、<ERASE EMERGENCY と送った後の CANCEL EMERGENCY、SOB、FUEL REMAINING は SOB が入ると FMC の量と時間、<INDEX、VERIFY>）。ATC COMM があれば ATC キーの長押しで EMERGENCY REPORT。VERIFY EMERGENCY（MAYDAY MAYDAY MAYDAY か PAN PAN PAN が 1 行目、/DESCENDING TO 14000FT、/ 04+25 OF FUEL REMAINING AND 395 SOULS ON BOARD、自由文、REPORT SEND で EMERGENCY REPORT へ、6L <EMERGENCY）。
  - FMSPG p.345–356：非常の状態は非常の報告がネットワークに受け取られてから、CANCEL EMERGENCY が受け取られるか ATC COMM が両方とも終わるまで。要素は 5 つまで。MAYDAY は簡略な POSITION REPORT を伴い、4L の高度より 150 ft 以上上なら DESCENDING TO も。MAYDAY と PAN は一方だけ。DIVERT TO の目的地は経路の続きを含み、入れた位置は含まない。CANCEL EMERGENCY は非常の状態で何も選んでいないとき。SENDING の間は変えられない。
- 作ったもの：
  - `B747.68.atc_emergency_model.lua`（新しい純粋なモデル）：選択と入力、DELETE（MAYDAY は POSITION REPORT と DESCENDING TO も）、5 要素の上限、要素の文と VERIFY EMERGENCY の行、自由文、送る文。
  - FMS のつなぎ：既定の値（アクティブな目的地と経路、MCP の高度、今の高度、位置、燃料の量と時間）、送信（cpdlc、応答なし）と ATC LOG、受け取りで非常の状態の入りと出、データを消す。ATC COMM の終わりで非常の状態は終わる。
  - ページ：EMERGENCY REPORT・VERIFY EMERGENCY・XXXXZ EMERGENCY を作り直した（`activepages/atc/B744.fms.pages.emergency.lua`）。ATC キーの長押し（1 秒）で EMERGENCY REPORT（B744.createfms.lua）。ATC LOG の非常の報告の右の LSK で XXXXZ EMERGENCY。
- 推定：POSITION REPORT の要素は送るが表示しない（FCOM p.731 のページに無いため）、その文（位置・高度・時刻）、要素の並び（MAYDAY・PAN、DESCENDING TO、DIVERTING TO、OFFSETTING、燃料と人数、CANCEL EMERGENCY）、フィートの高度に FT、FMC の値は小さい字で入力と選択は大きい字、長押しの 1 秒、MAYDAY の ADS の非常のモードと会社への非常の報告は 12h で。
- 試験：新しい `tests/fms/atc_emergency_model_test.lua`（35 件）、`tests/fms/atc_request_pages_test.lua` に 30 件（ATC キーの長押し、ページの形、目的地と MCP の既定、SOB と燃料の時間、MAYDAY で VERIFY EMERGENCY、FCOM p.731 の行、CONTINUED、SEND で EMERGENCY REPORT へ、受け取りで非常の状態と CANCEL EMERGENCY、CANCEL EMERGENCY を送って終わる、ATC LOG）。全体の試験はすべて通る。X-Plane：新しい `s200_atc_emergency` 15/15（2026-11-01、X-Plane を起動し直した後の 2 便目。RJAA の地上で EMERGENCY REPORT の <MAYDAY と PAN>、DIVERT TO の <RJBB、DESCEND TO の <10000、SOB 395 と燃料の時間、<MAYDAY の VERIFY EMERGENCY（MAYDAY MAYDAY MAYDAY、燃料と人数の行、CONTINUED）、DATA LINK NO COMM、ERASE EMERGENCY。CDU の写真 2 枚）、`s79_fmc_fixes` 34/34（作り直した EMERGENCY REPORT：RJTT を入れても目的地は変わらない）。Log.txt に Lua の誤りなし

## 122. 12h の分け方と 12h1 の実装（2026-11-01：会社の経路のアップリンク、SimBrief）

- 分け方（12h：会社のデータリンク CDU-40、ADS CDU-41、Hoppie CDU-38、CDU-42 の残り）：
  - 12h1：経路の要求とアップリンク（FMC COMM、RTE の REQUEST・CO ROUTE・ROUTE UPLINK の LOAD と PURGE、FLT NO）。会社はシムの運航管理で、SimBrief の .fms と OFP を読む（2026-11-01 利用者：機体フォルダの決めた場所に置けば読む）。
  - 12h2：風のアップリンク（WIND REQUEST、RTE DATA の LOAD、DESCENT FORECAST の LOAD と PURGE）。OFP の航法ログの高度別の風。
  - 12h3：OFP の ACARS の文（重量・燃料・巡航高度・ステップクライム。乗員が手で入れる：2026-11-01 利用者の (a)）。
  - 12h4：ATC の経路のアップリンクの LOAD（12f の残り）。ADS・Hoppie・CDU-42 の残りは、そのとき範囲を決める。
- 前のコード：FMC COMM は固定の文字（AutoATC が無いと OFFLINE）、2/2 の SEND は何もせず、1L は RTE 1 を開いた（CDU-42）。RTE の CO ROUTE は NOT IN DATA BASE を出すだけで残らず、REQUEST・LOAD・PURGE は無かった。受け取った経路を .fms に書く古いコード（acars/autoatcProvider.lua）は AutoATC の経路で、今回は触らない。
- 資料：
  - FCOM p.771–774：FMC COMM 1/2（UPLINK の見出しつきの <RTE 1、<DES FORECAST、有効な経路のときだけ <RTE DATA、POS REPORT>、DATA LINK の READY・NO COMM・VOICE・FAIL）、2/2（RTE REQUEST <SEND と CO ROUTE、SENDING、網の受け取りで SEND と小さい SENT、WIND REQUEST <SEND、CO ROUTE の削除で要求は SEND に戻る）。
  - FCOM p.1288–1291：RTE の REQUEST（アップリンクの読み込み待ちの間は見出しも空白、データリンクの不具合で DATA LINK と NO COMM など）、CO ROUTE（データベースに無ければ NOT IN DATABASE で入る）、FLT NO（入力かアップリンク）、ROUTE UPLINK（受信で表示、無ければダッシュ）、LOAD（読み込む。空中で有効な経路なら EXEC と ERASE、無効な経路では PURGE を消す。ROUTE 1 UPLINK LOADING）、PURGE（無効な経路のとき、捨てる）。
  - FCOM p.1310–1311：405・570 の PERF INIT は ZFW・RESERVES・COST INDEX・CRZ ALT もアップリンクできる（待ちの値は入力の横に小さい字）と書くが、受け入れの手順の記述は無い。12h3 は利用者の決めた (a) のまま。
  - FCOM p.1431–1434：FLT NUMBER UPLINK、INVALID FLT NO UPLINK、INVALID ROUTE UPLINK、PARTIAL ROUTE X UPLINK、ROUTE X UPLINK LOADING、ROUTE X UPLINK READY（FMC の警告のメッセージ）。
  - FMSPG p.367–376、p.382：要求は RTE・RTE DATA・DESCENT FORECAST・FMC COMM 2/2 から。UPLINK は経路のアップリンクか、見ていない便名のアップリンク。<RTE 1 か <RTE 2 は、アップリンクの行き先の経路。SENT は、経路のアップリンクが来るか、CO ROUTE が変わるか、もう一度要求するまで。LOAD は無効な経路を置き換える（読み込む間 ACTIVATE は空白）。有効な経路なら MOD（ERASE・EXEC）で、PURGE は無い。空中で会社の経路が入るのは無効な経路だけ。FMC COMM 2/2 の CO ROUTE は SEND で RTE のページへ移る。
- 作ったもの：
  - `B747.68.simbrief_model.lua`（新しい純粋なモデル）：X-Plane の .fms（1100 と 3）、SimBrief の OFP の XML（一般・出発地と目的地・燃料・重量・航法ログと点ごとの高度別の風）、経路のアップリンク（同じ航空路の続く点はその航空路で最後の点まで、ほかは DIRECT、SID・STAR・進入の点は FMC のもの）、風・降下予報・ACARS の文の下ごしらえ（12h2・12h3 で使う）。
  - FMS のつなぎ：要求（SENDING、ACK_S で SENT）、ANSWER_S 後の会社の答え（CO ROUTE の名前の .fms、無ければ最新の .fms、無ければ OFP の航法ログ。OFP は同じ出発地・目的地のときだけ使い、その便名を FLT NO へ）、経路を乗員が入れるのと同じ手順で組む（ORIGIN・DEST・RUNWAY・SID・航空路か DIRECT・STAR・進入。データベースに無い点は緯度経度の点にして PARTIAL）、LOAD（LOAD_S）と PURGE、メッセージ（変わったときだけ書く）。ファイルが無いと会社から ACARS の文（NO FLIGHT PLAN ON FILE）。
  - ページ：FMC COMM を作り直した（`activepages/B744.fms.pages.fmccomm.lua`）。RTE の 1 ページ目に REQUEST <SEND・SENDING・SENT、CO ROUTE の入力と削除、ROUTE UPLINK と <LOAD・PURGE>、読み込み中の ACTIVATE の空白。
  - ネイティブのプラグイン `b747_fms_bridge`：機体フォルダの simbrief の最新の .fms と .xml を 2 秒ごとに探し、その名前をフォルダの `_newest.txt`（「FMS 名前」「OFP 名前」）に、変わったときだけ書く。FMC は、X-Plane の acf の相対パス（sim/aircraft/view/acf_relative_path）から simbrief フォルダを求めて、それを読む。XTLua はフォルダを一覧できない。また、ほかのプラグインの文字の dataref は XTLua の中で古い値のまま残ることがあった（s201 の 1・2 回目：3 秒前に …02.fms に変わったのに …01.fms を使った）ので、名前は dataref でなくファイルで渡す。dataref（laminar/B747/fms/company/folder・fms_file・ofp_file：X-Plane のフォルダからの相対パス）は確かめ用に残す。Windows だけ。
  - simbrief フォルダの README.txt（置き方と使い方）。中のファイルは .gitignore で git に入れない。試験の筋書きに copy と remove の手順。
- 推定：会社はシムのもの（データリンクがあれば READY）、時間（受け取り ACK_S 4 秒、答え ANSWER_S 20 秒、読み込み LOAD_S 2 秒）、アップリンクの行き先（地上は要求した経路、空中は無効な経路、FMC COMM からは有効な経路か RTE 1）、CO ROUTE は .fms の名前（英数字 10 字まで）、FLT NO は 8 字まで・同じ便名なら FLT NUMBER UPLINK を出さない、データベースに無い点は緯度経度の点、受け入れ・拒否のダウンリンクは無し、ファイルが無いときの会社の文。
- 試験：新しい `tests/fms/simbrief_model_test.lua`（44 件：.fms の 1100 と 3、OFP の XML、経路のアップリンクの要素、高度の間の風、巡航の風、降下予報、ACARS の文）と `tests/fms/company_route_test.lua`（67 件：FMC COMM 1/2・2/2、ファイルが無いときの会社の文、SENDING と SENT、ROUTE 1 UPLINK READY と FLT NUMBER UPLINK、UPLINK、ROUTE UPLINK と LOAD・PURGE、LOADING、読み込んだ経路の SID・航空路・進入、有効な経路の MOD と ERASE、CO ROUTE の名前のファイル、PURGE、無いファイル、INVALID ROUTE UPLINK、空中は無効な経路へ）。全体は 181 本すべて通る。X-Plane：新しい `s201_company_route` 26/26（2026-11-01。RJAA の地上で、見本の .fms と OFP を simbrief に写し、プラグインが最新のファイルを見つける、FMC DATALINK ON、FMC COMM 1/2 の <RTE 1・POS REPORT>・DATA LINK READY、2/2 の RTE REQUEST と CO ROUTE、SENDING と SENT、約 20 秒後のアップリンク（RTE REQUEST の見出しが消え、1/2 に UPLINK）、RTE 1 の ROUTE UPLINK と <LOAD・PURGE>、FLT NO JAL123、LOAD の後の RJAA・RJBB・RW34L・CO ROUTE RJAARJBB01、経路 DIRECT XAC・ATMUGA で ATVID・遷移 ATVID で MIBIB・ILS06LZ（不連続なし）、ACTIVATE と EXEC。CDU の写真 6 枚。1・2 回目は XTLua がプラグインの文字の dataref の古い値を使って 12 件が落ち、名前を _newest.txt で渡す形に直した。3 回目の 1 件は筋書きの期待値の誤り：ATMUG から始まる STAR が DIRECT ATMUG に続く）。Log.txt に Lua の誤りなし

## 123. LF1：試験ラインフライト s198 の降下の減速の直し（2026-11-01）

- 見つけたこと（notes/LINE_FLIGHTS.md §1、記録の fvn_* の列）：
  - 10,000 ft を 291 kt で通過した。目標は 10,000 ft を切るまで 296 kt のままで、15 kt 遅れて A/T が SPD で推力を足し、経路の水平の減速の区間（10,150 ft 付近）は毎分約 1,840 ft で降りてくる機体には短く、乗り越えた。制限の高度を過ぎてから DRAG REQUIRED が出て、9,400 ft で水平にして減速した。
  - T/D から巡航の 333 kt のまま毎分約 2,700 ft で降り始めた（水平の減速の段が無い）。
- 資料：FCOM p.1264 の図と説明。2：T/D で FMC は降下の段に移り、ECON の降下速度を命じて、VNAV PATH で高度を保つ（水平の減速）。3：降下速度に近づいたら VNAV PATH で降下。4：速度制限の高度の手前で、FMC は目標の降下速度（制限の速度）を命じ、VNAV PTH のまま約 500 fpm で降りる。p.1263：FMC は速度の遷移の高度での減速を含めて経路を作り、遷移の速度より 10 kt 遅い目標を使う（既存の SPD TRANS の 240）。
- 直したこと：
  - `B747.68.pred_model.lua`：降下の経路の減速を、制限の高度で水平に（推定だった）から、制限の高度で終わる約 DECEL_VS（500 fpm）の降下に変えた（アイドルの抗力から降下の分を引いた減速。足りなければ水平：推定）。降下の 250 ft の刻みは、次の速度制限の高度（SPD TRANS・SPD RESTR）で止める（その高度で減速が終わる）。経路の点に区間の種類 "decel" と、その目標の CAS（c：終わりの速度）を持たせた。T/D は、巡航の速度から降下速度までの巡航高度での水平の減速の分だけ手前にし（td_decel、その間はアイドル）、R.td_decel に出す。
  - `B747.68.vnav_model.lua`：減速の区間では、目標をその区間の速度にする（FCOM p.1264 の 4）。T/D（降下の段に移る所）は経路が巡航高度に着く所と水平の減速の分（td_e）。
  - FMS のつなぎ：VNAV に渡す経路に c と td_decel を足し、B747_fms_vnav_td（T/D までの距離）も td_e で。
- 推定：DECEL_VS 500 fpm（FCOM の「約 500 fpm」）、降下で減速が足りないときの水平、T/D の水平の減速を巡航の重量・風・温度で積分。
- 見つけたことのうち直さないもの（原因の調べ）：
  - 進入で G/S を捕捉しなかった件：VNAV が MCP の高度で水平になって G/S を下から捕まえる流れは、MCP の高度（乗員）によるもの（FCTM：G/S に乗ってからミスト・アプローチの高度を入れる。それまで MCP は会合高度か許可された高度）。s198 は T/D の前に MCP を 2,000 ft にしたままで、ILS06LY の BERRY と BOLAL は CIFP で「4,000 ft 以上」（J・H）のため、経路は 4,000 ft より上の 3° の直線のまま降りた。筋書きを直した（MCP を STAR の 4,000 ft、ATVID の後に ILS06LZ の会合高度 1,300 ft、G/S の後に 3,000 ft）。VNAV の 3° の経路と X-Plane の G/S の約 0.6 ドットの差は、気圧（標準）と気温（ISA）では説明できず、まだ調べる。
  - 大きな旋回で E/D までの距離が増えた件：経路そのもの（XAC から ATMUG へ西へ行き STAR で東へ折り返す）が不自然で、2 回目の筋書きも同じ経路。距離を LNAV の経路に沿って測る直しは、次のラインフライトの結果を見てから。
- 試験：`tests/fms/pred_model_test.lua` に 7 件（減速の区間の目標 250 kt、10,000 ft で終わる、約 500 fpm、M.85 から M.84 の短い水平の減速、FL250 の M.80 から 290 kt の T/D の水平の減速とその始まりの T/D）、`tests/fms/vnav_model_test.lua` に 8 件（T/D の距離、水平の減速の間の降下の段と VNAV PTH・IDLE の水平、減速の区間の目標 240 kt と 500 fpm、その上の 290 kt）。全体は 181 本すべて通る。X-Plane：新しい `s202_vnav_decels` 23/23（2026-11-01、5 回目。T/D で FL250 のまま 335 kt から水平に減速（VNAV の縦の速さ 0、IDLE）、約 50 秒後に 292 kt で降下へ。10,700 ft で目標が 240 kt になり約 460 fpm で降りながら減速し、10,000 ft を 240.5 kt・VNAV PTH・経路の 158 ft 下で通過（s198 は 291 kt）。1〜4 回目は筋書きの不備で無効：空中開始の上昇、FLCH で FL250 へ降りる間に T/D を越えた、X-Plane を起動し直した直後に A/P が入らなかった）。Log.txt に Lua の誤りなし

## 124. 12h2 の実装（2026-11-01：会社の風のアップリンク）

- 前のコード：WIND REQUEST は表示だけで何もしなかった。RTE DATA は 570 で 6L の <LEGS だけ（データリンクの REQUEST SEND・LOAD は出さない：推定）、DESCENT FORECAST は 6R の DES> だけ（SEND・LOAD・PURGE は無し：推定）。
- 資料：
  - FCOM p.773：WIND REQUEST <SEND は経路の風と降下予報の要求。SENDING、網の受け取りで SEND と SENT。
  - FCOM p.1361、p.1363–1364：RTE DATA の 6R（405・570）は REQUEST SEND>（データリンクが使えて降下・進入の相でないとき）、風のアップリンクがあれば WIND DATA の LOAD>。LOAD は経路の風を入れて修正（MOD）にし、ERASE と SEND を出す。6L の ERASE は風を捨てて LEGS に戻る。
  - FCOM p.1395–1397：DESCENT FORECAST の 405・570 は、6L の REQUEST <SEND（降下予報の要求）か <LOAD、6R は予報のアップリンクがあれば PURGE>、無ければ DES>。LOAD は受け入れて表示し、SEND に戻り、PURGE を DES に戻す。「--- FORECAST UPLINK ----」の線。
  - FMSPG p.377–380、p.383：WIND REQUEST の SEND は降下・進入の相では出さない。RTE DATA の LOAD は MOD RTE DATA（ERASE・EXEC）、WIND DATA UPLINK READY を消す。DESCENT FORECAST の LOAD は前のデータを置き換え、DES FORECST UPLINK READY を消す。PURGE は前の予報を残す。
  - FCOM p.1431–1434：WIND DATA UPLINK READY、DES FORECST UPLINK READY、INVALID WIND DATA UPLINK、INVALID FORECAST UPLINK。
  - FMSPG p.368–369：FMC COMM 1/2 の <DES FORECAST と <RTE DATA の上に UPLINK。
- 作ったもの：
  - FMS のつなぎ（会社のデータリンクの中、状態は 1 つの局所表：メインの局所変数が Lua の 200 に近いため）：風の要求（SENDING、4 秒で SENT、20 秒で答え）。会社の答えは、プラグインの _newest.txt の OFP が有効な経路と同じ出発地・目的地のときだけ。経路の風（`S.wind_uplink`：OFP の巡航の点の、巡航高度ごとの風。経路の点に名前と位置で当てる。1 つも当たらなければ INVALID WIND DATA UPLINK）、降下予報（`S.forecast_uplink`）。OFP が無いか別の経路のものなら会社から ACARS の文（NO WIND DATA ON FILE）。LOAD は有効な経路の修正に、巡航高度を風の高度に、各点の風と気温を入れる（前の風と気温は置き換え、修正の脚には新しい表）。EXEC で有効、ERASE で捨てる。降下予報の LOAD は 4 つの高度と風を置き換えて予測をやり直す。メッセージは B744.notifications.lua の旗で（表に同じ文言があり、毎フレームの同期がその旗で条件のメッセージを消すため）。
  - ページ：FMC COMM 1/2 の UPLINK、2/2 の WIND REQUEST <SEND・SENDING・SENT（降下・進入では出さない）。RTE DATA は修正中なら MOD RTE n DATA で修正の経路を出し、データリンクがあれば 6L に <LEGS か <ERASE、6R に SEND> か LOAD>（その上に REQUEST か WIND DATA、SEND の左に SENT）、EXEC で修正を有効に。DESCENT FORECAST はデータリンクがあれば 6L に <SEND か <LOAD、6R に PURGE> か DES>、その上に REQUEST か FORECAST UPLINK の線。データリンクがある P&W（SIM CONFIG の FMC DATALINK ON）は 570 の形（RTE DATA の <LEGS、DESCENT FORECAST の DES>）。
- 推定：時間（経路の要求と同じ）、風の高度は OFP の巡航高度（最初の高度とステップクライムの高度、4 つまで）、OFP の巡航の段の点だけ、点ごとの気温は最も低い巡航高度のもの、降下予報の高度（T/D の高度から 5,000 ft まで 4 つ）、前の風と気温の置き換え、別の経路の OFP には答えない、RTE DATA の見出しと SENT の位置、DESCENT FORECAST の REQUEST の見出しの位置。
- 試験：新しい `tests/fms/company_winds_test.lua`（32 件：WIND REQUEST の SENDING と SENT、2 つのメッセージ、FMC COMM 1/2 の UPLINK、RTE DATA の LOAD と MOD・ERASE と SEND・巡航高度の風の高度・BRAVO の FL250 の 283°/59 kt・EXEC で有効、ERASE で捨てる、DESCENT FORECAST の LOAD と PURGE・4 つの高度と風、進入では SEND を出さない、OFP が無いときの会社の文）、`des_forecast` と `pred_glue` の 570 の 6 行目を SEND を出す形に（前は推定で出さなかった）。全体は 182 本すべて通る。X-Plane：新しい `s203_company_winds` 26/26（2026-11-01、X-Plane を起動し直した後の 2 便目。RJAA の地上で見本の .fms と OFP を simbrief に写し、FMC DATALINK ON、経路を受けて ACTIVATE・EXEC、会社の OFP の文で EICAS の ACARS MESSAGE と ACARS の UPLINK の一覧の OFP RJAA-RJBB、WIND REQUEST の SENDING・SENT・約 20 秒で FMC COMM 1/2 の 2 つの UPLINK、RTE DATA の LOAD> で MOD RTE 1 DATA と <ERASE・SEND>、EXEC で ATMUG に W>、DESCENT FORECAST の <LOAD で FL250・FL180・12000・5000 の風、REQUEST <SEND と DES> に戻る。CDU の写真 7 枚）。写真で ACARS のページが OFP の文の行を割っていた（「CRZ ALT FL250 CI」と「100」：古い折り返しが「@」の行の区切りの先の空白で切っていた）ので、`acars.pages.lua` の convertToFMSLines を直した（「@」で先に分け、各行を 24 文字以内の最後の空白で折る。`company_route_test` に 2 件）。Log.txt に Lua の誤りなし

## 125. 12h3 の実装（2026-11-01：OFP の ACARS の文）

- 利用者の決め（2026-11-01）：SimBrief の重量・巡航高度・ステップクライムは ACARS の文で送り、乗員が手で PERF INIT などに入れる（自動では入れない）。FCOM p.1310–1311 は 405・570 の PERF INIT の ZFW・RESERVES・COST INDEX・CRZ ALT もアップリンクで入ると書く（待ちの値は入力の横に小さい字）が、受け入れの手順の記述が無いので作らない。
- 作ったもの：会社が経路のアップリンクを答えるとき、同じ出発地・目的地の OFP があれば、その文（題「OFP 出発地-目的地」：便名、巡航高度と COST INDEX、巡航高度と違うステップクライムとその点、重量と燃料は OFP の単位の 1000 で ZFW、TOW・LDW、RAMP FUEL、TO FUEL、TRIP・RSV、ALTN、PAX）を会社の ACARS の文で送る（EICAS の ACARS MESSAGE、ACARS の UPLINK の一覧。`S.ofp_text`）。
- 推定：送る時（経路の答えといっしょ）、文の形と言葉、重量の単位の書き方。
- 試験：`tests/fms/company_route_test.lua` に 2 件（OFP の文の題と、巡航高度・ステップクライム・ZFW、未読）。X-Plane：12h2 と同じ s203。

## 126. シムの便利機能（2026-11-01：オートステップクライムと T/D 前の一時停止）

- 利用者の決め（2026-11-01）：機体フォルダのプラグインで、X-Plane の Plugins のプルダウンメニューからシムの便利機能（オートステップクライム、T/D での一時停止など）をオン・オフする。Windows だけ（Mac・Linux は使わないので作らない）。CDU には出さない。機能は実機に無いので自作する（利用者も了承）。
- 実機の機能ではない。乗員の操作をシムが代わりにする便利機能として作り、FMC と AFDS の働きは変えない。
- メニューと設定（`plugins/b747_fms_bridge`、ネイティブのプラグイン：XTLua にはメニューの関数が無い）：
  - Plugins → 747-400 に「Auto step climb」と「Pause 2 min before T/D」。選ぶたびにオン・オフし、チェックの印が付く。
  - 選んだ状態は X-Plane の `Output/preferences/B747-400_options.prf` に保存し、次に機体を読むときに戻す（無ければ両方オフ）。
  - dataref：`laminar/B747/options/auto_step_climb`、`laminar/B747/options/pause_at_td`（int、書ける。書いても保存しない：試験のため）。コマンド：`laminar/B747/options/auto_step_climb_toggle`、`laminar/B747/options/pause_at_td_toggle`（キーに割り当てられる。保存する）。
- 動き（FMC の XTLua：`B747.68.simopts_model.lua` とつなぎ、0.5 秒ごと）：
  - オートステップクライム：CRZ のページの STEP TO の AT が NOW（ステップの点に来た：FCOM p.1348–1349）で、VNAV が engage して巡航（巡航上昇・降下中でない）のとき、乗員がする巡航上昇の操作（FCOM p.649、p.1257：MCP 高度を STEP TO にして高度セレクターを押す）を代わりにする。MCP の窓と AFDS の高度を STEP TO にし、1 秒後に高度セレクターのコマンド（`laminar/B747/button_switch/press_altitude`）。押しで CRZ ALT が STEP TO になり、VNAV が巡航上昇する（これまでの FMC と AFDS の働き）。MCP 高度が CRZ ALT より下（降下の準備）のとき、T/D の 200 NM 以内（STEP TO が出ない）、STEP SIZE 0 で乗員の STEP TO も無いときはしない。押しが効かなければ 30 秒後にもう一度。
  - STEP TO と NOW は CRZ のページと同じ計算（`B747_fms_crz_step`：CRZ のページの計算を関数に出した）。
  - T/D 前の一時停止：FMC の巡航の段で、T/D まで 2 分（FMC の RESET MCP ALT が出る時：FCOM p.1433）になったら X-Plane を一時停止（`sim/operation/pause_on`）。一度止めたら、T/D が 3 分より遠くなる（CRZ ALT や経路が変わる）か着陸するまで、もう止めない。T/D を過ぎても巡航のまま（MCP 高度を下げていない）なら止める。
- 自分で決めたこと（資料が無い）：一時停止の 2 分は RESET MCP ALT に合わせた。押しまでの 1 秒（XTLua のモジュールが別のモジュールの書き込みを読むのは次のフレーム）、やり直しの 30 秒、再び止める 3 分。
- 高度セレクターの押しで CRZ ALT が変わったとき（巡航上昇・巡航降下）も、CDU で CRZ ALT を入れたときと同じく乗員の STEP TO を消す（6-1・6-2 段 8b2 の「新しい CRZ ALT まで残す」のとおり。前は残り、s204 の 1 回目でステップの後に STEP TO FL350（CRZ ALT と同じ）と出ていた）。
- 試験：新しい `tests/fms/simopts_model_test.lua`（38 件：NOW で MCP、1 秒後に押し、押しが効かなければ 30 秒後にもう一度、しない条件、新しい STEP TO、一時停止の 2 分、もう止めない、3 分で再び、着陸で再び、オフ、巡航でない、対地速度）、新しい `tests/fms/simopts_glue_test.lua`（25 件：FMS のモジュールで CRZ のページの STEP TO FL390 NOW、乗員の STEP TO FL390、オフと VNAV なしでは何もしない、VNAV で MCP の窓と AFDS の高度、1 秒後に高度セレクターのコマンド 1 回、押しで CRZ ALT FL390・乗員の STEP TO が消える・巡航上昇、MCP を下げていれば何もしない、T/D の 2 分前に X-Plane の一時停止のコマンド 1 回、3.9 分に遠のいてからもう一度、オフでは止めない）。CRZ のページの試験（vnav_pages）はそのまま通る。全体は 184 本すべて通る。X-Plane：新しい `s204_auto_step_climb` 20/20（2026-11-01、X-Plane を起動し直した後の 6 便目。FL310・310 kt で RJAA の東から空中開始、RTE RJAA→PHNL、乗員の STEP TO FL350 で AT NOW、オプションの dataref を ON で 1.1 秒後に MCP 35,000 ft、さらに 1.1 秒後に高度セレクターの押しで CRZ ALT FL350、VNAV SPD・THR REF の巡航上昇（CDU は ACT ECON CRZ CLB）、41 秒で 31,500 ft、130 秒で FL350、VNAV PTH と巡航の段階、STEP TO は空白（乗員の STEP TO が消えた）。1 回目は 15/18：空中開始の後に MCP の既定の 200 kt で減速していて、254 kt からの巡航上昇が加速で遅れ、捕捉中に確かめた筋書きの誤り）、新しい `s205_pause_at_td` 22/22（同じく 5 便目。s202 と同じ FL250 の空中開始、オプションの dataref を ON で約 40 秒後に一時停止、そのとき CRZ のページの TO T/D は 13 NM（対地 399 kt で約 2 分）、FMC は巡航の段階、解いた後 10 秒で止まらず、T/D で降下。1 回目は空中開始の後に A/P が入らず経路を入れられなかった：s202 の 1〜4 回目と同じ不安定さ）。Log.txt に Lua の誤りなし。Plugins → 747-400 のメニューの印と保存は利用者の目視

## 127. LF2 の実装（2026-11-01：旋回の道のりを VNAV の距離に）

- 試験ラインフライト 2 回目（notes/LINE_FLIGHTS.md §2）：ATMUG の左 157° の旋回（点の上を通る：path_model の MAX_FLYBY 135° を超える）で、E/D までの距離が 58.7 から 61.8 NM に増え、VNAV が経路の下最大 2,012 ft、約 30 秒水平に飛んだ。1 回目の見つけたこと 3 と同じ。旋回は 200° 回って約 16 NM 飛び、距離は 4.3 NM しか減らなかった（約 12 NM 長い）。続く 10,000 ft は、減速の始まりが計画より約 225 ft 低く 253.5 kt で通った。
- 前のコード：予測の区間の長さは点と点の大圏、E/D までの距離は機体から次の点までの大圏と残り。旋回の道のりはどこにも入っていなかった（点の上を通って回る旋回で長く、fly-by の旋回で短い）。
- 資料：FMC の経路は旋回で区間をつなぐ（ATA34_2 p.615、p.626：EFIS の地図のための計算も同じ経路）。VNAV の経路は E/D までの距離で決まる（FCOM p.1257–1262）。旋回の道のりをどう数えるかの記述は無い。
- 作ったもの：
  - `B747.68.lnav_model.lua`：transition（区間 e1 と e2 の間の旋回が、点を通る大圏よりどれだけ長いか。fly-by は path_model の旋回の円弧と、それが切る 2 本の接線の差で短い。点の上を通る旋回は、LNAV が実際に切る操舵（M.update）で点から 1 秒ずつ回り、e2 に乗る（0.1 NM・3° 以内）までに飛んだ距離と、そのときの e2 の残りの和から e2 の長さを引いたもの）、flyover（そのシミュレーション）。保持・プロシージャーターン・不連続・条件の区間の終わりは 0。
  - `B747.68.xt.fms.lua`：予測の入力の各区間に、その前の点での旋回の分を足す（`B747_fms_turns`。速さは前の予測のその点の真対気速度と今の風、無ければ今の対地速度。点・針路・10 kt ごとに覚える）。ND の予測の点は、区間の始めの旋回の分を区間の始点に置いて大圏の上に。点の上を通る旋回（TURN_MIN_NM 0.5 NM より長い）の点を LNAV が順送りしたら、VNAV の E/D までの距離をそのときの値から飛んだ距離で減らし、大圏の距離が追いつくか LNAV が区間に乗ったら（順送りから TURN_LNAV_S 2 秒の後）、差を TURN_BLEND_S 30 秒で混ぜて大圏の距離に戻す（`B747.68.vnav_model.lua` の turn_dist）。LNAV が外れたら、または TURN_MAX_S 600 秒でも終わる。
- 推定：旋回の速さ（前の予測の真対気速度と今の風）、点の上を通る旋回の操舵（LNAV の推定の操舵の則のまま、横傾き 25° に瞬時に入る）、混ぜる 30 秒、区間に乗った判定、0.5 NM、600 秒。
- 試験：新しい `tests/fms/vnav_turns_test.lua`（29 件：fly-by の 90° は 1.22 NM 短い、ATMUG の 157° は 370 kt で 10〜15 NM 長い、250 kt では短い、保持・不連続・条件の終わりは 0、turn_dist の飛んだ距離・追いつき・混ぜ、FMS のモジュールで DELTA の 180° の旋回：予測の区間が旋回の分長い、順送りで距離が落ちない、旋回の間は飛んだ距離で減る、区間に乗ると混ぜて大圏の距離に）、`pred_glue` の ND の点の検査を旋回の分に合わせた。全体は 186 本すべて通る。X-Plane：新しい `s206_vnav_turn_descent` 17/17（2026-11-01、X-Plane を起動し直した後。ATMUG の約 60 NM 東の FL250 から西へ空中開始、s198 と同じ経路で ATMUG へ DIRECT TO、MCP 4,000 ft で VNAV。T/D は ATMUG の約 17 NM 手前（2 回目の試験ラインフライトは約 30 NM 手前：旋回の約 12 NM ぶん遅い）、ATMUG の左 157° の旋回の間の経路のずれは -85〜+84 ft、T/D から 10,000 ft まで最大 336 ft（2 回目は -2,012 ft）、10,000 ft を 244.1 kt（2 回目は 253.5 kt）。MCP 4,000 ft で VNAV ALT、経路が 300 ft 下へ離れてから MCP を 1,300 ft にしても押さなければ VNAV ALT のまま、押して VNAV PTH。1 回目は空中開始の後にエンジンが止まっていて無効：実行器を直した）。Log.txt に Lua の誤りなし

## 128. V 速度の作り直し（2026-11-02：離陸の V1・VR・V2 と VREF）

- 利用者の依頼（2026-11-02）：離陸も着陸も V 速度の計算がおかしいようなので、一次資料を探し、それに基づいて作り直す。
- 資料：
  - FCOM の性能の章：最小操縦速度 VMCG・VRMIN の表と「VRMIN のときの V2」の表。PW4056 は最大推力（PI.10.10、p.236）、TO1 8 %（PI.10.19、p.245）、TO2 15 %・20 %（PI.10.33–34、p.259–260）。CF6-80C2B1F（747-400F、ポンド）は最大推力（PI.20.11、p.339）、TO1 5 %（PI.20.20、p.348）、TO2 15 %（PI.20.29、p.357）。全部を画像で読み、本文の抽出と照らした。
  - FCOM PI.18.11（p.323）：VMCG・VRMIN は空港の気圧高度と実際の外気温で引く。V1 が VMCG より小さければ V1 = VMCG、VR が VRMIN より小さければ VR = VRMIN、そのときの V2 は「VRMIN のときの V2」（V2 より大きければ）。
  - FCOM p.1319–1320（TAKEOFF REF）：「FMC calculated speeds provide VMCA and VMCG protection」。FMC は総重量・外気温・気圧高度から計算する。p.1272–1273：TO1・TO2 の推力は離陸の制限、仮定温度の推力は制限でなく乗員は全推力にできる。
  - FAA AC 25-13（1988）§5.b・c：減推力離陸の速度は、離陸推力（減格が性能の基準なら減格推力）と周囲の条件での操縦性の基準を下回らない。性能は減らした推力で。14 CFR 25.107(a)・(e)：V1 は VMCG 以上、VR は V1 以上で 1.05 VMCA 以上。
  - VREF：FCOM PI.10.2（p.228）の表（1,000 kg）と「海面上 4,000 ft ごとに 1 kt 増」。APPROACH REF の図：240.8 t で 25 が 146、30 が 140（p.1409）、570（GE）で 502.8（1,000 lb）で 142・136（p.1411）。利用者がくれた中国国際航空の QRH（PW4056、1,000 lb：PI-QRH.10.5、QRH_CA p.353）も 1 kt 以内で一致する。PI.20.2（747-400F の CF6、ポンド）は 1 kt ほど低く、570 の図とも合わない。
  - 離陸速度の表そのもの（重量・フラップ・温度と高度の区分ごとの V1・VR・V2）は手元の資料に無い（FCOM は「FMC か Takeoff Analysis から」：PI.18.1。Boeing の運航用の表は公開されていない）。利用者がくれた空港計画用資料（ACAP：D6-58326-1 Rev F）は滑走路長の図で、V 速度は無い。
- 前のコードで見つけたこと：
  1. 表（Laminar、2016）に VMCG・VRMIN の下限が無い。200 t・フラップ 20・海面で 88/102/130 kt（VMCG 121・VRMIN 124 より 30 kt 以上低い）、300 t でも V1 は VMCG に近い。LF3 で V 速度が低く見えたのはこれ。
  2. 表の転記の誤り 3 か所：フラップ 10 区分 D の VR 320〜420 t が 93〜111 kt（区分 C より 60 kt 余り低い）、フラップ 20 区分 D の VR 220 t が 97 kt、フラップ 20 区分 E の V2 380 t が 149 kt（VR より低い）。
  3. 区分 B の線の 36.84℃ の点が 26.84℃ の値（2,876 ft）の写しで、線が上り返していた（暑い日の 1,300〜2,900 ft で区分 C のところを B に取り、数 kt 低い）。
  4. 区分を機長の高度計（QNH の高度）で引いていた（表は気圧高度）。仮定温度を見ていなかった。区分の外（区分 E より高い空港、右端より暑い日、-60℃ より寒い日）では区分が決まらず、V 速度が出なかった。
  5. VREF 30 は Laminar の表を X-Plane の重量と今の高度の帯で、VREF 25 は FCOM の表を今の高度で引いていた（巡航 FL350 で VREF 25 が 8.75 kt 高い）。APPROACH REF の GROSS WT は X-Plane の重量で、入力しても表示されなかった。
- 作ったもの（6-1/6-2 段 3d）：
  - `B747.60.to_speeds_model.lua`（新しい純関数、計器のモジュールが dofile）：表の速度（区分は気圧高度と、D- なら仮定温度で引く。区分の外は端の区分：推定）、V1 の風の補正（今までの表）、FCOM の最小操縦速度（エンジン型式と減格の % で表を選ぶ。PW の 8・15・20 %、CF6 の 5・15 % のあいだの % はあいだを取り、最後の表より大きい % は最後の表：推定。RB211 は資料が無く PW4056 の表：推定）、PI.18.11 の手順。最小値は切り上げ。表の 3 か所は隣から（推定：フラップ 10 区分 D の VR は区分 C に 2 kt 足す、フラップ 20 区分 D の 220 t は C と E のあいだの 114、フラップ 20 区分 E の V2 380 t は区分 D に 1 kt 足す 179）、区分 B の点は前後の点の直線上の 1,281 ft（推定）。旧フォークの記録（PMDG の AOM を読んだもの）とも合う。
  - `B747.60.xt.fltInst02.lua`：B747_setV1VrV2 をモデルで計算する。入力は TAKEOFF REF のフラップ、FMC の総重量、TAKEOFF REF の風、外気温、気圧高度（`sim/flightmodel2/position/pressure_altitude`）、THRUST LIM の SEL（D- のときだけ：`laminar/B747/fms/thrlim/code` が 100 以上）と離陸の減格の %（`laminar/B747/fms/thrlim/to_pct`）、エンジン型式（`laminar/B747/engines/type`）。区分の計算（B747_getTempAltRegions、B747_setTempAltRegion）を外し、表は fltInst.lua からモデルへ移した。
  - `B747.68.vref_model.lua`（新しい純関数、FMC）：PI.10.2 の表を全エンジン型式で、4,000 ft ごとに 1 kt。表の外は端の傾きのまま（QRH の 900,000 lb とも合う）。
  - FMC：毎フレーム、FMC の総重量（PERF INIT の前は機体の重量：推定）と着陸高度（`laminar/B747/fms/landing_alt`、無ければ 0：推定）で VREF 25・30 を新しい dataref `laminar/B747/fms/vref25`・`vref30` に書く。計器の VREF 30（`laminar/B747/airspeed/Vref30`）と速度テープの VREF 25（Vf25）はこれを使う（PFD のフラップの機動速度は「現在の総重量の VREF 30 から」：FCOM p.1412）。Laminar の VREF 30 の表（Vref30data）と速度テープの VREF 25 の表は外した。
  - APPROACH REF：GROSS WT は FMC の総重量（無ければ □）。入力（XXX.X、PERF INIT と同じ 150〜400 t）は、その CDU がページを離れるまで表示（FCOM p.1411）。VREF 25・30 は表示の重量と着陸高度から、重量が無ければ空白。1R・2R で「25/146」の形をスクラッチパッドへ。
- 残り：離陸速度の表そのもの（資料が無い）、勾配（SLOPE）の補正、V1 の風の補正の表の 1 kt の差（旧フォークの記録に 15 か所。確かめられない）、湿った滑走路、クリアウェイ・ストップウェイ（FMC には入力が無い）。
- 試験：新しい `tests/fms/to_speeds_model_test.lua`（43 件：表の行が重量とともに増え V2 が VR 以上、3 か所の値、区分の線が頂点から下がる、区分（37℃・2,000 ft は C、区分 E の上は E、端）、FCOM の表の値と VRMIN ≥ VMCG、補間、VRMIN のときの V2、200 t の 121/124/146、300 t、風、TO 1、TO 2、CF6、仮定温度）、新しい `tests/fms/vref_model_test.lua`（9 件：表、高度、FCOM の APPROACH REF の 2 つの図、QRH の全行が 1 kt 以内）、`takeoff_speeds_test` に 11 件（CDU で 200 t の 121/124/146、TO 2 の 108/111/130、SEL 45℃ の D-TO 2、APPROACH REF の FMC の重量・VREF・入力・1R・ページを離れると戻る）、速度テープの 2 本を FMC の VREF に合わせた。全体は 191 本すべて通る。
- X-Plane：新しい `s213_vspeeds` 16/17（2026-11-02 01:08、X-Plane を起動してから 3 回目の読み込み。RJAA 34L・14.7℃・気圧高度 136 ft、ZFW 130 t で FMC の総重量 216.5 t）。フラップ 20 で 121/124/145（前の表のままなら 92/105/130 ほど）、THRUST LIM の TO 2 で 108/111、SEL 45℃ で D-TO 2 +45C・108/111/134（区分 C の V2、最小値は実際の外気温のまま）、APPROACH REF は FMC の 216.5 で 25° 138・30° 132、PFD の VREF 30 も FMC の dataref と同じ 131.95、GROSS WT に 240.8 を入れて 146/140（FCOM p.1409 の図のとおり）。落ちた 1 件は PERF INIT の GR WT を大きい字の行で見ていた筋書きの誤り（計算値は小さい字の行の 216.5 で、筋書きを直した）。1・2 回目は試験キットが機体を読み直さず、古いコードのまま走った（開始が景色の読み込みで 161 秒かかり、45 秒の規則で読み込んだと取り違えた。キットを直した：TESTING.md）。Log.txt に Lua の誤りなし。

## 129. P&W の最大 EPR と CRZ の基準（2026-11-02：CLB 推力で EPR が赤くなる）

- 利用者の指摘（2026-11-02、LF5 を見て）：CLB 推力でも EPR の数字が赤くなる。巡航の緑の CRZ の EPR がやけに高い。巡航中の基準を CRZ から CLB に変えても実機どおりか。
- 資料：
  - FCOM p.834（7.10.6）：EPR の数字は最大に達すると赤（operating limit reached）。p.833：最大 EPR の線（amber）は「maximum allowable thrust」。
  - FCOM p.876：最大推力はどの段階でもレバーを前いっぱいにした推力。
  - FCOM PI.13.1（片発の最大連続 EPR）は、PW4056 では 35,000 ft まで最大上昇の EPR（PI.10.36、p.262）より上。
  - ATA70_80 p.208（CF6 の rating）：離陸は 17,000 ft・300 kt の下、最大連続は 18,000〜22,000 ft か 293 kt の上、25,000 ft の上でレバーが 35° を超えると最大上昇。P&W の EEC の rating の資料は無い。
  - FCOM p.831：CRZ は「maximum rated cruise thrust」。FCOM の性能の章に最大巡航の表は無い（片発の章 p.320・p.410 に「Max Cruise thrust rating」の名だけ）。
  - FMSPG p.33、ATA34_2 p.536、FCOM p.1273・p.1340：巡航の推力の基準の既定は整備の設定で CLB か CRZ。THRUST LIM ページで手で選べる。
- 前の作り（段 9h1）：レバーを前いっぱいにした rating を、P&W も CF6 と同じにしていた（25,000 ft より上は最大上昇）。P&W の最大 EPR の線（`display_EPR_max`）はこの rating なので、25,000 ft より上では CLB の基準と同じ値になり、CLB 推力の上昇で EPR が赤くなった。
- 直したこと（`B747.42.eec_model.lua`）：P&W の前いっぱいの rating は、22,000 ft より上も最大連続のまま（推定：P&W の資料は無い。CF6 の 25,000 ft より上の最大上昇を P&W に当てると、CLB の上昇のたびに赤くなり、FCOM の赤の意味に合わない）。CF6 は前のまま。RR は前の作りのコード（`B747.42.xt.EEC.RR.lua`）が最大 EPR を自分で出すので、この変更は通らない。
- CRZ の基準：最大上昇の表で代用している（段 9g3 の推定）ので、実機の最大巡航より少し高い。LF5 の FL250 では基準 1.48 に対し、巡航の EPR は 1.02。PW4056 の巡航の EPR はもともと低い（FCOM の長距離巡航の表 PI.11.2、p.268：260 t・FL270 で 1.04）ので、差が大きく見える。前の作りは CRZ の基準を M.85 の巡航に要る EPR の表（`P85M_epr_PW4062`）から出していて、巡航の EPR に近かった。FCOM の EICAS の図（p.830）は TAT −14℃ で CRZ 1.38（高度は無い）。最大巡航の値の資料は見つからない（2026-11-02 にネットでも探した）。巡航で CLB を選ぶ（THRUST LIM の <CLB、または PERF FACTORS の THR/CRZ を CLB）のは実機どおりで、その値は FCOM の表そのもの。
- 利用者の決定（2026-11-02）：「最大巡航推力を正確に導き出せないのなら既定をCLBにしよう」。PERF FACTORS の THR/CRZ の既定を CLB/100 にした（`B747.68.perf_factors_model.lua` の `DEFAULTS`。FMSPG p.266–268 の入力の無い FMC と同じ。前は ATA34_2 p.681 の図の機体の CRZ/100）。T/C で CLB のまま（CLB 1・2 は外す：段 12c1）。PERF FACTORS で CRZ を入れれば前のとおり CRZ になり、CRZ の基準（最大上昇の表で代用）は残す。試験：`perf_factors_model_test`（既定 CLB/100、保存した CRZ が既定より勝つ）、`perf_factors_pages_test`（ページの CLB/100、CRZ の入力）。`s198` の巡航の確認を CLB に。X-Plane：`s139_vnav_climb_crz` 28/28（2026-11-02 04:36：VNAV で FL170 に上がり、T/C の後も推力制限は CLB）。Log.txt に Lua の誤りなし。
- 試験：`eec_model_test` 158 件（P&W は 30,000 ft でも前いっぱいが最大連続、CF6 は前のまま）、`eec_module_test` 87 件（最大 EPR の線 1.622、基準より 0.01 以上上）。
- X-Plane：新しい `s214_epr_climb`（P&W：FL240 から FLCH の CLB 推力で FL320 へ、26,000 ft の上で EPR の数字が白のまま、最大 EPR の線が基準より上）。X-Plane：`s214_epr_climb` 10/11（2026-11-02 02:51）：26,000 ft の上の CLB 推力で EPR 1.501・基準 1.500・最大の線 1.637、30,000 ft で 1.555・1.570・1.611。EPR の数字は 30,000 ft までずっと白。落ちた 1 件は筋書きの HDG HOLD のコマンド名の誤り（直した）。RR：新しい `s216_epr_climb_rr` 9/9（BA のリバリー、RB211-524H2）：RR の最大 EPR の線は前の作りの 1.90（表示の上限）で、26,000 ft の上で EPR 1.57・基準 1.58、30,000 ft で 1.60・1.60、ずっと白。RR の最大の線が実機どおりかは資料が無く分からない。Log.txt に Lua の誤りなし。


## 130. A/T の G/A の推力（2026-11-02：FCTM の着陸復行の確かめから）

- きっかけ：`aero_go_around`（RJAA 34L の自動着陸の進入、電波高度 200 ft で TO/GA を 1 回、フラップ 20、notes/AERO.md §3.15）。下がった高さは 36 ft（FCTM p.206：約 40 ft）で合うが、A/T の G/A（THR）がレバーを毎秒 0.01〜0.03 しか進めず（0.49 → 0.64 に 5 秒、0.79 に 19 秒、0.89 に 39 秒）、17 秒で 152 kt から 138 kt まで速さを失い、2,000 fpm に届いたのは 37 秒後で、その後も 2,350 fpm まで増えた。
- 資料：ATA34_2 p.674–675：G/A は THR で「2000 FPM の昇降率に制御する」、2 回目の押しで THR REF（G/A の推力制限いっぱい）。FCOM p.673・FCTM p.208：TO/GA 1 回で 1,000〜2,000 fpm の推力。
- 前の作り（FMC の段 9f2）：THR の則は 1 fpm あたり K_VS（1.2e-5、FLCH の 125 秒の昇降率のために決めた推定）のレバーの速さで、上昇の目標のときはレバーを戻さない（ATA34_2 p.646：上昇で推力を減らさない）。G/A もこれを使っていた。
- 直したこと（`B747.70.at_model.lua`）：G/A の THR は、エネルギーの率（`evs`：慣性の V/S と速さの変化の分。VNAV の THR と同じ）を 2,000 fpm に、K_VS_GA（3e-5、推定）で、超えたら戻す（p.675 の「制御する」）。FLCH の「上昇で減らさない」はそのまま。
  - 途中の試し：V/S のまま 5e-5 では、推力は 8 秒で N1 95 % に上がって速さも保ったが、昇降率が 3,300 fpm まで行き過ぎてから 200 fpm まで戻り、レバーが行き来した（エンジンの遅れ。速さが増えている間も V/S だけを見ていた）。
- 試験：`at_model_test` +3 件（G/A の 2,600 fpm で戻す、1,500 fpm でも速さが増えてエネルギーの率が 2,600 なら戻す、FLCH の上昇は戻さない）、G/A の 1,000 fpm の速さの期待を K_VS_GA に。
- X-Plane（`aero_go_around`、2026-11-02 09:37）：TO/GA から 2 秒でレバー 0.62、5 秒で 0.85、8 秒で 0.93（N1 56 → 73 → 88 %）。44 ft 下がって 4 秒で上昇に移り（FCTM 約 40 ft）、速さは 147〜159 kt、昇降率は 11 秒で 1,730、23〜29 秒で 2,040〜2,110、その後 1,800〜1,960 fpm（2,000 fpm の付近に落ち着き、行き来しない）。

## 131. SimBrief の最新の OFP を Pilot ID で取る（2026-11-02：利用者の依頼「SimBrief の Pilot ID を使って最新 OFP を取得するようにできない？」）

- 前（段 12h1、§122）：利用者がブラウザで SimBrief の OFP（XML）と X-Plane の .fms を保存して simbrief フォルダに置き、RTE REQUEST で FMC が最新のファイルを使った。シムの便利のための機能（実機の会社の運航管理の代わり）で、資料に照らすものではない。
- 作ったもの：
  - FMS ブリッジ（`plugins/b747_fms_bridge`、C、Windows のみ）：FMC が要求の番号（`laminar/B747/fms/company/simbrief_fetch`）を書くと、別のスレッド（WinHTTP）で SimBrief の `https://www.simbrief.com/api/xml.fetcher.php?userid=<Pilot ID>`（SimBrief の公開の取得口。最新の OFP の XML）を取り、`<fetch><status>` が Success なら、その `<fms_downloads>` の `<directory>` と `<xpe>`（X-Plane 11/12）の `<link>` から飛行計画を取り（SimBrief は 1 回転送する。WinHTTP がたどる）、simbrief フォルダに `<出発地><目的地>.fms` と `.xml` で置く（.fms が先。それぞれ .part に書いてから名前を変える：2 秒ごとのフォルダの見回りが書きかけを拾わない）。終わるとフォルダをすぐ見直して `_newest.txt` を書き、`simbrief_done` に要求の番号、`simbrief_status` に結果（2 取れた、3 Pilot ID なし、4 応答なし、5 SimBrief が OFP を返さない、6 OFP に X-Plane の飛行計画なし、7 保存できない）。取得の部分は X-Plane を呼ばない `simbrief_fetch.c` に分け、`simbrief_fetch_test.c`（コマンドラインの同じ取得）で X-Plane なしに試せる。ビルドは `-lwinhttp` を足した。
  - Pilot ID：`laminar/B747/options/simbrief_id`（int、0 は無し）。ブリッジが X-Plane の `Output/preferences/B747-400_options.prf` に `simbrief_id` で残す（シムの設定と同じ所。リバリーごとの simconfig ではない）。
  - CDU：SIM CONFIG の 2 ページ目の 5L に SIMBRIEF PILOT ID（数字 1〜9 桁、DELETE で消す、ほかは INVALID ENTRY。無ければダッシュ）。
  - FMC（`B747.68.xt.fms.lua`）：RTE REQUEST <SEND で、ブリッジがいて Pilot ID があり、CO ROUTE が無ければ（CO ROUTE はフォルダのファイルの名前）、要求の番号を 1 つ増やす。答え（20 秒、§122）は取り終えるまで待ち、60 秒（`FETCH_MAX_S`：推定。ブリッジの WinHTTP の待ちはそれより短い）で打ち切る。取れなかったら会社の ACARS の文（SIMBRIEF: NO ANSWER、NO OFP FOR THE PILOT ID、OFP WITHOUT X-PLANE FLIGHT PLAN、FILES NOT SAVED）を送り、フォルダの最新のファイルで答える。
- 推定：待ちの上限 60 秒、取ったファイルの名前（`<出発地><目的地>`：CO ROUTE に使える英数字 8 字）、同じ名前のファイルは上書き。
- 試験：
  - コマンドライン（`simbrief_fetch_test.exe 262051 <フォルダ>`、利用者の Pilot ID）：3.9 秒で結果 2、`RJFFPANC.fms`（2,326 バイト、curl で取ったものと同じ）と `RJFFPANC.xml`（1.85 MB）。
  - 回帰（LuaJIT）：`company_simbrief_test` 23 件（新設：5L の入力・INVALID ENTRY・DELETE、要求の番号、取り終えるまで答えない、取り終えたらすぐ答える、状態 4 で SIMBRIEF の文とフォルダのファイル、60 秒で打ち切り、CO ROUTE では取らない、ブリッジが無ければ取らない）。全 197 本。
  - X-Plane（カスタム acf、X-Plane を起動し直して新しいブリッジ、捨ての s128 のあと、2026-11-02 12:01）：`s218_simbrief_fetch` 15/15。CDU で 5L に 262051 を入れ（ブリッジの dataref と 5L の表示）、RTE REQUEST <SEND で要求の番号が 1 つ増え、ブリッジは 2.7 秒で取り終えた（状態 2、最新の .fms と .xml は RJFFPANC）。約 20 秒でアップリンクし、RTE 1 の <LOAD で ORIGIN RJFF・RUNWAY RW16R・DEST PANC・FLT NO GTI8118（OFP の便名）・CO ROUTE RJFFPANC、FLT NUMBER UPLINK（写真で確かめた）。取ったファイルは最後に消した（Pilot ID は利用者の設定として残した）。Lua の誤りなし。

## 132. ND の経路の線を自前で描く（2026-11-02：利用者の指摘「ND上のルートを示すマゼンタのラインめちゃめちゃなってるやん」と依頼「NDのルート描写も独自のプラグインで描画できないの？」）

- 指摘の場面：最初のラインフライト（s198、2026-11-02 の 02:10 ごろ）の ATMUG。XAC からの 268° の脚から STAR ATMUGA の ATMUG–SAKVA（111°）へ左に 157° の旋回で、マゼンタの線が ATMUG の横に途切れた弧で描かれた。
- 原因：ND の線は、FMC が流し込んだ X-Plane の FMS の行を、X-Plane の EFIS の地図の計器（`EFIS_map_s_HM`・`EFIS_map_t_HM`）が描いていた。FMC の経路の形（§27）は 135° を超える旋回を点の上で飛び越えてから回る（`MAX_FLYBY`）が、X-Plane は ATMUG の手前に自分の輪を描いた（`s219` の F/O の ND で、X-Plane の線は ATMUG の手前の逆 U の形）。fly-by の旋回も LNAV が飛ぶ弧（25° のバンクと LNAV の速さ）にならない（利用者の質問「LNAVがNDのマゼンタのラインを旋回時に追従しないのはなぜ？」）。
- X-Plane の線を消す方法を試した：
  - 地図の絵（`-2`・`-3` の画像）を透明にしても線は残った（`s111`、13:31 と 10-29 の写真が同じ）。
  - X-Plane の下地の地図 `EFIS_basemap_s_HM`（Laminar の 737 が使う）は、経路の線は描かないが気象レーダーの反射も描かなかった（機長側だけ替えて、チルト −5° の地面の反射が F/O 側の EFIS の地図にだけ出た）。使わない（acf は元のまま）。
  - X-Plane の地図は、X-Plane の FMS の現用点（行き先の項目）から先の脚を描く：現用点を計画の最後の行にすると線が消えた（F/O の ND で現用点 6 では脚の線、最後の 9 では無し）。これを使う。
- 作り方：
  - FMC（`B747.68.xt.fms.lua` の `B747_fmc_route_sync`）：X-Plane の FMS の現用点は、地上でも空中でも、計画の最後の行（ブリッジへは計画の前の「CURRENT n」、5 秒ごとに見直す）。AFDS・ND・FMC 自身の現用点は `fmscurrentIndex`（xtlua/fms の行）に、アクティブな経路の現用点の行（非アクティブの経路は 1）を、X-Plane が計画を持ってから毎フレーム書く。前は X-Plane の現用点を空中でアクティブな点にして、xtlua/fms の [10] から読んでいた。[10] を読んでいた所を `fmscurrentIndex` に替えた：ND の現用点の記号（マゼンタ）、ND の右上の現用点・距離・ETA（`getCurrentWayPoint`）、DATA の ETA（`B747_route_eta`）。AFDS の古い best track（X-Plane の現用点から `fmscurrentIndex` を決めていた。アクティブな経路では動いていなかった）は、アクティブな経路が無くても動かさない（X-Plane の FMS は進めない）。
  - FMC の線（`B747.68.nd_line_model.lua`、新設）：経路の形の要素から線の点を作る。脚の直線（大圏）、fly-by の旋回の弧（経路の形のモデルの `turn`。5° ごと）、点を飛び越える旋回は LNAV が操る形（LNAV のモデルの `flyover_path`：`flyover` と同じ 1 秒刻みの模擬で、5° 回るごとか 15 秒ごとの点。LNAV が次の脚に乗った所から次の脚の線）、迎えの脚（CI・VI）の終わりも fly-by の弧（LNAV は、次の脚のコースに旋回で乗れる所から回り始める：LNAV のモデルの `ended`。`s91` の (INTC) の 123° の旋回は、初めは角で描いていた）、ほかの条件の脚の終わり（高度・DME・radial）は角（LNAV はそこで順送りしてから回る）、DME・RF の弧、ホールドの周回とプロシージャーターンの形（`shape`）、条件の脚は予測した終わりまで（VECTORS は 10 NM で、次の脚へはつながない）。不連続と、点への経路の無い脚の前で線を切る。進入復行は描かない（X-Plane の計画にも入れていない：推定）。旋回の速さは LNAV と同じ（真対気速度と風）：現用点と、直前に順送りした点の旋回は今の速さ、その先の点は予測の真対気速度（`B747_fms_turns` と同じ）。順送りした点の旋回は、その旋回を飛んでいる間も線に残す（直前に順送りした要素を覚えておく：推定）。
  - 線の種類（FCOM p.1148）：現用の経路はマゼンタの実線、修正（EXEC 前）は白の短い破線、非アクティブの経路はシアンの長い破線、横のオフセットの線はマゼンタの短い破線（経路の実線はそのまま）。RTE 2 の非アクティブの経路と、ACTIVATE の後で EXEC の前の線は §135。
  - FMC のグルー（`B747_fmc_nd_line`）：1 秒ごとと経路が変わったときに点を作り直し、変わった点だけ `laminar/B747/nd/line/lat`・`lon`・`pen`（600 点）と `n` に書く（`pen` は区切りの最初の点にその線の種類、続きの点に 0）。主チャンクのローカル変数が 200 を超えたので、状態は `do` の中に置き、順送りの要素は関数で渡す（XTLua の大域の表の件）。
  - ND（`B747.61.xt.nd.lua` の `updateNDLineView`）：各 ND の地図の投影を `laminar/B747/nd/line/view`（席ごとに表示の型：0 なし・1 拡大の MAP・2 MAP CTR・3 PLAN、中心の緯度経度、上の真方位、1 NM あたりの画素）に、経路の記号と同じ計算（`nd_bearing`・`map_scale`）で毎フレーム書く。IRS が無いときと APP・VOR では描かない（FCOM p.1147：経路は MAP・MAP CTR・PLAN）。
  - PLAN は真北が上にした（FCOM p.1110）。前は記号の方位に磁気偏差を足して磁北が上（X-Plane の PLN の地図の線に合わせていた）。
  - FMS ブリッジ（`plugins/b747_fms_bridge/src/nd_line.c`、新設、C）：パネルの描画（`xplm_Phase_Gauges`、計器の後）で、点を ND の記号と同じ方位と距離（地球 3440 NM）で置き、パネルの座標に描く。原点は ND のコースの線と予測線と同じ（機長 335.25、副操縦士 1022.25、拡大は −95、MAP CTR と PLAN は 173.5 上：acf の `ND Text Center` のグループ）に、描画の座標と acf の位置の差 259 px（`NDL_PANEL_DY`：測った値）を足す。表示の位置（`flt_inst/display/<席>/nd_pos`）の移動も acf のとおり。見える所（`B747.61.nd_data.lua` の `inside`：拡大は範囲の弧の内で前方、左右 −329〜348、MAP CTR は 225、PLAN は 327 の円）で切る。長い脚の大圏は 60 px ごとに分ける。幅 3.5 px、破線は短い 12・10、長い 24・12（滑走路の中心線の破線と同じ：推定）。表示の電源（`display_has_power` の 3・2）とガラスの明るさ（rheostat の 2・3）。PLAN の機体の記号（FCOM p.1147：位置と航跡、白い飛行機の形）も描く（X-Plane の地図が描いていた。形は FCOM の図から、大きさは MAP の三角と同じくらい：推定）。
  - 調べるための dataref：`laminar/B747/nd/line/cal_dx`・`cal_dy`・`cal_scale`・`width`・`test`（bit 0 機長、bit 1 副操縦士の線を緑に）・`passes`（描くパネルの描画の回：既定 5 は 2D のパネルと 3D のパネルの光る回）・`pnl_l`・`pnl_b`（描画のときのパネルの左と下）。
- 較正（`s219`、X-Plane、2026-11-02 14:49〜15:12）：描画の座標は acf の位置より 259 px 上にずれていた（初めは線が機体の記号の下まで伸び、F/O の ND で X-Plane の線より下に描かれた）。`cal_dy` 275 で機体の記号の頂点から線が出て、259 で拡大の MAP の線が範囲の弧にちょうど収まり、MAP CTR の機体の記号と PLAN の SAKVA の星を線が通った。PLAN の 40 NM で、旋回の終わり、機体の記号、SAKVA・ATVID・MIBIB・OGABA の星を全部通り、ATVID と MIBIB の fly-by の弧が描けた。X-Plane の EFIS の地図の線は、記号より約 4〜5° 回って描かれていた（自前の線は航跡の線と記号に合う）。
- PLAN の中心：X-Plane は FMS の表示中の点（前は PLAN の中心に使っていた）を現用点より前に置けない。現用点を最後の行にしたら PLAN の中心が目的地になり（`s219`、15:26）、FMS ブリッジが計画の読み込みと現用点の書き込みの後に表示中の点を置き直しても、目的地のままだった（15:38〜15:43）。そこで FMC が PLAN の中心の行（LEGS の中心の点の行、§42 と同じ求め方）を自分の dataref `laminar/B747/fms/plan_ctr_row`（1 から）に書き、ND（`updateNDLatLong`）はそれを読む（0 のときだけ前のとおり X-Plane の表示中の点）。FMC は X-Plane の表示中の点をもう書かない（ブリッジの `laminar/B747/fms/xp/displayed` は残す）。
- PLAN の X-Plane の地図：X-Plane の地図は自分の PLN の中心（表示中の点＝計画の最後の行）から自機の記号を描くので、PLAN に目的地からの位置のもう一つの飛行機が出た（`s111`、17:05：EDDM の東 15 NM の所）。FCOM p.1039 は PLN では気象レーダーと TCAS を出さないので、PLAN では X-Plane の地図を出さない：カスタム acf のパネルで、両 ND の中心の地図（全幅・半幅）を、ND のモードの切替が PLN でないときのグループに入れた（ACF_DIFF.md §5、`docs/overhaul/tools/panel_nd_plan_xpmap.lua`）。
- 試験：
  - 回帰（LuaJIT）：新設 `nd_line_model_test` 40 件（fly-by の弧、ATMUG の飛び越える旋回、`s91` の (INTC) の弧と radial の終わりの角、不連続、VECTORS、進入復行、ホールド、順送りした点の旋回、配列）、新設 `nd_line_view_test` 12 件（表示の型、中心、上の向き、1 NM の画素、PLAN の真北、APP・VOR・IRS なしは描かない）。`route_sync_test`・`route_bridge_test`・`legs_plan_ctr_test`・`nd_data_test` は X-Plane の現用点が最後の行、AFDS の現用点が `fmscurrentIndex` の期待に直した。全 199 本。
  - X-Plane（カスタム acf）：較正の後（15:39〜16:15）、`s219_nd_route_line` 22/22（X-Plane の線は出ず気象レーダーは残る。ATMUG の飛び越える旋回の形、両 ND、PLAN）、`s89_route_sync` 26/26、`s91_lnav_sid` 27/27、`s45_wxr` 49/49。PLAN の中心を FMC の行に直し、ブリッジを作り直して X-Plane を起動し直した後（16:20〜）：`s219` 22/22、`s91` 27/27（(INTC) の 123° の旋回を弧で描く。LNAV はコースの右 3.4 NM から回り始め、行き過ぎ 0.16 NM）。`s111_legs_plan_ctr` は空中開始のエンジンと遅い開始のために 2 回落ち（TESTING.md）、開始を直した後に 51/51（17:05：PLAN の中心は FI26R、STEP で RW26R。PLAN に X-Plane の地図の自機の記号がもう一つ出ていた）。PLAN の X-Plane の地図を消す acf の後（X-Plane を起動し直して 17:12〜）：`s111` 51/51（PLAN の X-Plane の自機の記号は消えた。空中開始の後に 4 基とも止まっていたのを、ランナーの新しい確かめがやり直した）、`s219` 22/22（読み直しあり：読み直さない版は前の `s111` の経路が FMC に残り、入力が崩れた）。Lua の誤りなし。

## 133. 条件の点と飛び越える点の後の旋回（段 6d3、2026-11-02：`s91` の ND で、D337F を飛び越えた後のヘディングの脚の線と NRE001 の予測の点が、機体の飛ぶ所から約 3 NM ずれていた）

- 見つけたこと：`s91`（RJAA の SAKUR5）の ND（16:01 と 16:39 の写真）で、D337F（飛び越える点）から右へ 123° 回ってヘディング 100 で NRE の radial 001 まで、の脚の線と予測の点 NRE001 が、機体の飛ぶヘディングの線より約 3 NM 南にあった（機体は NRE の北 8.3 NM、予測の点は 4.5 NM）。経路の形のモデルは、方位とコースの脚（VA・VD・VI・VM・VR、CA・CD・CI・CR）と DF を、前の脚の終わりの点から引いていた（推定）。LNAV は、条件を満たしてから（FCOM p.1249：(1000) を越えてから 140 へ回る）、または点を飛び越えてから、25° のバンクで回るので、旋回の膨らみの分、線と予測の点がずれる。資料：ATA34_2 p.615（区間の間を曲がった遷移でつなぐ）。FCOM p.1249 の図は模式図で、旋回の形は描いていない。
- 直したこと（`B747.68.path_model.lua`）：前の点で回る遷移（条件の脚の終わり：高度・DME・radial・距離。飛び越える点。fly-by で入れない点：ヘディングの脚へは fly-by しない）の後の方位とコースの脚は、旋回の終わりから始め、終わりもそこから予測する（`turn_in`：旋回の始まり・中心・半径・向き・角度・長さ）。旋回は LNAV と同じ 25° のバンク、手続きの向き（なければ近い方）、その点から（ロールの遅れなし：推定）。旋回の中で条件を満たすとき（高度・DME・radial）は、旋回の弧の上のその所で脚を終え（LNAV はそこで順送りして次の脚へ回る）、次の旋回はそこの航跡から（`end_crs`）。初めは前のとおり点からにしたが、`s91` の速さ（約 260〜270 kt）は旋回の終わりが radial を越えるかどうかの境で、予測の点が 3 NM 飛ぶので（X-Plane の 18:00 の `s91` で NRE001 が元の所のままだった）、弧の上で終えるようにした。LNAV は、そうした脚の radial と DME の側を旋回の始まりで見る。DF は、点の方へ回って航跡が点への方位に合う所から点への線（LNAV の direct：FCOM p.1237 と同じ形）。迎えの脚（CI・VI）の終わりは前のまま（§132：fly-by の弧）。旋回の速さは FMC が渡す（`B747_fmc_turn_kt_into`：前の点の予測の真対気速度と今の風、現用の脚は前の点を順送りしたときの速さ、少なくとも 150 kt）。現用の脚は、LNAV が直前に順送りした要素から（順送り以外で現用の脚が変わったときは無し）。各要素に、前の点（`start`：CF の線は前の点の横から）も持たせた。
- ND の線（`B747.68.nd_line_model.lua`）：その旋回の弧（5° ごと）。条件の脚の終わりの後の直線とコースの脚（TF・CF など、旋回を持たない脚）への旋回は、LNAV が操る形（`flyover_path`：飛び越える点と同じ。CF の線が前の点から始まらなくても、その線に乗るまで）。現用の脚は、条件を満たした所（予測の点ではない）から。
- 予測（`B747.68.lnav_model.lua` の `transition`）：条件の脚の終わりは飛び越える点と同じに扱う。旋回を持つ脚は、旋回の弧とその後の脚の長さから、旋回の始まりから脚の終わりまでの大圏を引いた分を足す（予測の脚は固定点の間の大圏で、条件の脚の長さは 0 のまま：推定）。FMC の旋回の覚え（`B747_fms_turns`）は、次の脚の始まりと終わりでも分ける（ヘディングの脚はコースを持たない）。
- ND の高度の目印（`B747_fms_pred_point`、§50）：固定点の無い脚（条件の脚）は、旋回の余分で長さを持つようになったので、そこに当たった目印（T/C・T/D・E/D・減速の点）はその脚の始まりに置く（推定）。直す前は、無い終わりの点を読んで Lua のエラーになり、XTLua がプラグインの全モジュールを止めた（`s150`：G/A の直後、進入復行の VI の旋回に T/C が当たり、F/D・FMA・CDU が止まった。TESTING.md §4.6 の書き残しで分かった）。
- 試験：
  - 回帰（LuaJIT）：`path_model_test` 165 件（s91 の形：radial を越える点が 3.05 NM 先へ、X-Plane の航法データの D337F で 260 kt と 300 kt（旋回の中で radial を越え、弧の上で終える：予測の点は飛ばない）、旋回の円の上の始まり、VA の後の VI、fly-by の後の CA（fly-by のまま）と VA（旋回）、DF の後の左の長い旋回、旋回の中で 1,600 ft に届く：弧の上で終え、次の旋回はそこの航跡から、最初の脚）、`lnav_model_test` +2 件（弧の上で終わった脚の radial の側を旋回の始まりで見る）、`nd_line_model_test` 47 件（旋回の弧とその向き、VA の後の CF への旋回、現用の脚の条件を満たした所から）、`vnav_turns_test` 32 件（条件の脚の終わり、迎えの脚は無し、旋回の余分）、`pred_glue_test`（ZZAA の SID：(600) の後の旋回で (INTC) が手前に動き、ZZV までの CF が長くなって ZZV の fly-by の旋回 −0.03 NM が数えられる。順送りの後の残りの距離は、ZZV の旋回を含む脚の長さで出す。固定点の無い脚の中の目印はその始まり +3 件）。全 199 本。
  - X-Plane（2026-11-02、起動し直した後）：`s91` 29 項目すべて合格（D337F を飛び越えた後、NRE001 の予測の点へ 2 NM 未満まで近づき、そのときまだ現用点。18:00 の回は旋回なしの線のままで外れた）。`s150` 33 項目すべて合格（G/A の後に VNAV SPD・LNAV・THR REF、3,000 ft で VNAV PTH と水平、巡航の段階で 236 kt）。直す前の `s150`（18:24・19:07）は、上の目印の Lua エラーで XTLua が FMC・AFDS などを止め、G/A の 2 フレーム後から F/D・FMA・CDU が動かなかった。

## 134. LEGS のページの ACTIVATE は表示中の経路を ACTIVATE する（2026-11-02：`s219` の RTE 2 の確かめで見つけた不具合）

- 見つけたこと：`s219` で RTE COPY の後、RTE 2 LEGS の 6R（ACTIVATE>）を押すと INVALID ENTRY になり、ACTIVATE されなかった。LEGS のページの 6R（`legsr6`）は RTE のページの `rteactivate` を呼んでいたが、それはページの名前から経路を決めていて（RTE1・RTE2 のページだけを知る）、LEGS・LEGS2 のページではアクティブな経路（`B747_fmc_route`）を選び、アクティブなので INVALID ENTRY にしていた。経路が 2 つとも非アクティブのときは、RTE 2 LEGS の ACTIVATE が RTE 1 を ACTIVATE していた（段 7e4 からの不具合）。
- 直したこと（`B744.fms.pages.legs.lua`）：LEGS のページの 6R は、そのページが表示している経路を ACTIVATE する（FCOM p.1332：ACTIVATE は非アクティブの経路を ACTIVATE して EXEC を待つ）。
- 試験：`rte2_pages_test` +3 件（ACT RTE 2 のときの RTE 1 LEGS の ACTIVATE>：RTE 1 が ACTIVATE、INVALID ENTRY なし、EXEC の灯）。X-Plane：`s219`（段 6d4 の確かめの中で。2026-11-02 19:32 の回は 28 項目すべて合格：RTE 2 LEGS の ACTIVATE> で EXEC の灯がつき、INVALID ENTRY は出ない）。

## 135. もう一つの経路（RTE 2）と、ACTIVATE の後で EXEC の前の経路の線（段 6d4、2026-11-02）

- 資料：FCOM p.1148（非アクティブの経路はシアンの長い破線。ホールドとプロシージャーターンも同じ色）、FCOM p.1251（非アクティブの経路はシアンの破線、ACTIVATE して EXEC していない経路はシアンと白の交互の破線）、ATA34_2 p.505（非アクティブの経路はシアンの破線）、FMSPG p.50-51。いつ出すかの条件は資料に無いので、経路があればいつも出す。
- 前の作り（§132）：FMC は RTE 1 の側（`B747_fmc_route`：アクティブの経路、無ければ RTE 1）の線だけを作り、もう一つの経路は描かなかった。ACTIVATE の後で EXEC の前もシアンの長い破線。
- 直したこと：
  - FMC（`B747_fmc_nd_line`）：もう一つの経路（`B747_fmc_route2`：アクティブにはならない側）の形を毎秒作り、アクティブの経路の線の下に描く（その点を先に、残りの点の数だけ：600 点）。旋回はそのときの速さ（その経路の予測は無い：推定）。ACTIVATE して EXEC していない経路は、新しい線の種類 5（`B747.68.nd_line_model.lua` の ACTIVATING）。
  - FMS ブリッジ（`nd_line.c`）：線の種類 5 はシアンと白の破線を交互に（12 px と間 6 px：推定）。
- 試験：回帰 `rte2_pages_test` +5 件（両方非アクティブで RTE 2 の線が先、RTE COPY の後は RTE 2 が下、ACTIVATE の後で EXEC の前は 5、EXEC の後は RTE 1 が下）。X-Plane：`s219` の終わりに RTE COPY、RTE 2 の点を 1 つ消す、ACTIVATE、EXEC（写真 3 枚）。2026-11-02 19:32 の `s219` は 28 項目すべて合格：線の最初は RTE 2 の 3（シアンの長い破線、アクティブの線の下）、ACTIVATE の後で 5（写真ではシアンと白の交互の破線）、EXEC の後は RTE 1 の 3。EXEC の後の写真で SAKVA に旋回の鉤が出たのは §136。

## 136. ND の線：順送りした点の旋回は、機体がその点の近くにいるときだけ残す（2026-11-02：`s219` の RTE 2 の ACTIVATE・EXEC の後の鉤）

- 見つけたこと：`s219`（19:41 の写真）で、空中で RTE COPY した RTE 2 の 2 つ目の点を消して ACTIVATE・EXEC すると、ND のマゼンタの線が SAKVA の所で大きく回る鉤の形になり、現用点は SAKVA ではなく MIBIB だった。オフラインで同じ手順を再現すると、RTE 2 の最初の脚は出発地 RJAA から SAKVA への大圏（SAKVA で 262°、291 NM）で、機体（SAKVA の西 30 NM）はその大圏の上では SAKVA を過ぎているので、LNAV が EXEC の直後に SAKVA を順送りしていた。ND の線は「最後に順送りした点での、現用の脚への旋回」（§132）を描き続けるので、機体から 30 NM 離れた SAKVA で 262° から 105° へ回る旋回を描いていた。
- 直したこと（`B747.68.xt.fms.lua` の順送り）：順送りのとき、機体がその点から「fly-by の旋回の始まりの距離 + 2.5 NM」より遠ければ、その点の旋回を残さない（2.5 NM は LNAV が脚を捕まえる距離：FCOM p.644。推定）。ふつうの順送り（fly-by は旋回の始まり、飛び越える点はその点で順送りする）はこの内側に入る。
- 残したこと：空中で ACTIVATE した経路の最初の脚が出発地からの大圏になり、すぐ順送りされること自体は、段 7e4 の経路のモデルのまま（FCOM p.1290 は ACTIVATE と EXEC で経路がアクティブになるとだけ書く）。
- 試験：`rte2_pages_test` +2 件（RTE 1 を空中で EXEC し、最初の点の 20 NM 先：すぐ順送りし、旋回を残さない。直す前は残した）、`lnav_glue_test` +1 件（ALPHA の 1 NM 先の順送り：旋回を残す）。全 199 本。X-Plane：`s219`（2026-11-02 20:22、28 項目すべて合格。EXEC の後の写真で、マゼンタの線は SAKVA から MIBIB へまっすぐ、鉤なし）。

## 137. G/A の後の進入復行の経路を ND と X-Plane の計画に出す（段 6d5、2026-11-02）

- 資料：FCOM p.147（Go–Around and Missed Approach Procedure：PM は進入復行の経路を追っているのを確かめる。ND に経路が出ている前提）、FCOM p.1262（進入復行：TOGA で FMC は上昇へ、VNAV・LNAV で進入復行の経路を飛ぶ）、FCOM p.1148（アクティブの経路はマゼンタの実線）。
- 前の作り（§132、推定）：進入復行の脚は ND の線にも X-Plane の計画（ND の点の記号の元）にも入れない。G/A の後に LNAV が進入復行を飛んでも、ND には線も LILAC などの点も出なかった（`s150` の G/A の後：ND の線は滑走路まで）。
- 直したこと：
  - FMC（`B747.68.xt.fms.lua`）：G/A で進入復行を始めた後（`B747_fms_missed_approach`：飛んでいた進入の脚が `vnavMissed` に入る）、その進入の進入復行の脚（`B747_fms_missed_shown`）を、ND の線（アクティブの経路と変更の線）と X-Plane の計画に入れる。G/A のときは経路が変わらなくても計画・ND の線・予測を作り直す。着陸（地上）で進入復行の状態を消すときも作り直す。G/A の前と、G/A の後に入れた別の進入の進入復行は、今までどおり出さない（推定）。もう一つの経路（RTE 2）の線には出さない。
  - 経路のモデル（`B747.68.route_model.lua` の `to_fms`）：進入復行の脚を入れるかの関数を受ける（無ければ前と同じ）。
  - ND の線（`B747.68.nd_line_model.lua`）：`o.shown(e)` が真の進入復行の要素は、ほかの脚と同じに描く。
- 試験：回帰 `pred_glue_test` +4 件（G/A の前は計画も ND の線も滑走路 RW16R で終わる、G/A の後は計画に進入復行の行 ((1000)、ZZV、その待機) が入り、ND の線は ZZV の待機を回って ZZV で終わる。6d5 なしでは後の 2 件が落ちる）、`nd_line_model_test` +1 件（`o.shown` の進入復行は描く）。全 199 本。X-Plane：`s150`（2026-11-02 20:37、34 項目すべて合格。G/A の後すぐ X-Plane の計画に LILAC が入り、機長の ND の写真では進入復行のマゼンタの線が VI の左旋回の弧と (INTC) を通って LILAC の方へ続く）。

## 138. A/T の FLCH の V/S を変更の始めから保つ（2026-11-03：全シナリオの回の s07・s101）

- 資料：ATA34_2 p.670（FLCH の THR は、MCP の高度への変更を 125 秒で終える V/S を推力で保つ）、p.646（上昇では V/S が足りなければ推力を増やし、多くても減らさない）。
- 前の作り（段 9f2、§60）：THR の目標の V/S を毎フレーム「残りの高度 ÷ 125 秒」で計算し直していた。近づくほど目標の V/S が小さくなって推力を戻し、捕捉まで長く掛かった（全シナリオの回の s07：FL354 から FL350 への 400 ft が 440 秒。s101 も時間内に ALT にならなかった）。
- 直したこと（`B747.70.at_model.lua`）：FLCH の V/S は、変更の始め（FLCH に入った時と、MCP の高度が変わった時）の高度差 ÷ 125 秒に決め、その変更の終わり（ALT の捕捉）まで保つ。FLCH から出たら忘れる。G/A の 2,000 fpm と VNAV の THR は前のまま。
- 試験：回帰 `at_model_test` +4 件（400 ft の降下で 192 fpm なら推力を保つ、残り 100 ft でも保つ（前は 48 fpm を求めて推力を増やした）、MCP の高度が変われば そこから 528 fpm、FLCH に入り直すとそこから）。X-Plane（2026-11-03 の再試験）：`s07` は FLCH の 400 ft が 21 秒で ALT、`s101`・`s53`（FL350 への FLCH）・`s108` も合格。

## 139. CDU のキーを押した順に、それぞれ前のキーが出したページで受ける（2026-11-03：全シナリオの回の s110）

- 資料：FCOM p.1212–1213（CDU のキーの働き）、FMSPG p.39–43。押したキーが失われる働きは資料に無い（実機は押した順に全部受ける）。
- 前の作り：行選択キーの働き（`fmsFunctionsDefs`）は、そのページを描くとき（`getPage`）に決まる。ページを変えるキー（行選択・機能キー・NEXT・PREV・EXEC）の後、ページを描く前に次の行選択キーが来ると、前のページの働き（無いことが多い）で処理されて失われた。X-Plane が一瞬止まったり重いフレームだったりすると、その間のコマンドが 1 フレームにまとめて届く（全シナリオの回の s110：DEP ARR・R2・R4 を 0.5 秒おきに押し、R4 がまだ描いていない ARRIVALS のページで失われた）。
- 直したこと（`B744.createfms.lua`）：ページを変えるキーの後は、その CDU の次のキーを待ち行列に入れ、そのページを描いてから順に処理する（次のページを変えるキーまで）。スクラッチパッドのキーは待たせない（待ち行列があればその後ろ）。電源が無いときと FMC の再同期の間（キーが効かない）は、待っているキーを捨てる。
- 試験：回帰 `cdu_framework_test` +4 件（空中で INIT REF・R6・L3 を 1 フレームに：THRUST LIM の <CON まで届く、メッセージなし。押した後フレームの前に電源が落ちると、来たとき MENU）。X-Plane（2026-11-03 の再試験）：`s110`・`s111`・`s80`・`s81`・`s86`・`s88` 合格。

## 140. A/T の速度の則：目標から遠い減速は全部の速さで（2026-11-03：全シナリオの回の s112・s43）

- 資料：FCTM p.43（突風の中の A/T は、速度が下がると推力を速く増し、上がるとゆっくり減らす）、FCTM p.139（水平飛行でスピードブレーキなしに 340 kt から 250 kt まで約 90 秒・8 NM。その間レバーはほぼアイドル）。ゲインは資料に無い（推定）。
- 前の作り（段 9f2、§60）：レバーの速さ = K_SPD × 速度の差 − K_ACC × 加速度（0.002、0.06）で、減らす向きはいつも半分。目標へ「差 ÷ 30 秒」の加速度で近づく則で、目標から遠くてもレバーをゆっくり戻し、フラップの抗力で減速している間はレバーを止めた。
  - s112（G/S の捕捉）：MCP 170→150 kt・フラップ 30 で、レバーが 0.56〜0.63 のまま約 18 秒、174→168 kt。捕捉で浮き上がり +0.451 ドット（上限 0.3）。
  - s43：MCP 180 kt・フラップ 10 から 20 秒で 220→216 kt。500 ft で 190 kt を超え、TOO LOW GEAR でなく TOO LOW TERRAIN。
  - 簡単な模擬（エンジンの遅れ 7 秒・2.5 秒）で、FCTM p.139 の 340→250 kt に 137 秒。
- 直したこと（`B747.70.at_model.lua`）：K_SPD 0.004（差 ÷ 15 秒）。減らす向きの半分は目標から 5 kt の内だけ（突風の範囲：FCTM p.43）、15 kt から先は全部の速さ（その間は直線で）。模擬で 340→250 kt 99 秒、220→180 kt（フラップ 10）51 秒（前は 90 秒）。前に強すぎた組（0.006・0.05：s01 の 250 kt でレバーがアイドルから 0.3 まで 30 秒ごとに振れた）より、減衰の項は強いまま。
- 試験：回帰 `at_model_test`（4 kt 速いと半分、10 kt でその間、20 kt で全部、加速度の項：120 件）。新しい `s220_at_decel`（10,000 ft・340→250 kt、250 kt を 2 分、290 kt へ）。
- X-Plane（2026-11-03 の 2 回目の再試験）：
  - `s220`：MCP を 250 kt にするとレバーは約 2.5 秒でアイドル。250 kt の 2 分は 250.0〜252.0 kt、290 kt へは 37 秒で行き過ぎなし（288.0〜290.2 kt）。この回は空中開始の後の FMC の A/P の立ち上げ（`activate_inflightAP`）が MCP の速度を 305 kt へ巻き戻し、340 kt の空中開始の機首上げで約 2,000 ft 上がった所から減速したので、FCTM p.139 の時間とは比べられない（シナリオを直した）。
  - `s01`：250 kt でレバー 0.15〜0.23、速度 250.2〜251.8 kt（揺れなし）。空中開始の 289 kt からはすぐアイドルで約 0.8 kt/s。
  - `s43`：47/0（500 ft で TOO LOW GEAR）。`s112`：+0.337 ドット（まだ上限 0.3 の上。捕捉と同時にフラップ 30 にしたときの浮き上がり +230 fpm：11-02 のフラップの揚力の補正の後から。A/P は 0.05 g で機首を毎秒約 0.3° しか下げられない。ATA22 にフラップの変化をピッチの指令に入れる記述は無い：残り）。`s115`・`s07`・`s53`・`s108`・`s114`（自動着陸）は合格。
  - 残り：フラップ 20・170 kt の水平で、推力が約 20 秒周期で 59〜104 kN の間を振れた（前の則は 69〜86 kN、10-30 の則は 51〜84 kN で 55 秒で落ち着いた）。ALT の保持の上下と組になる。進入の試験で様子を見る。

## 141. VOR の自動同調に TACAN だけの局を選ばない（2026-11-03：全シナリオの回の s69）

- 資料：FCOM p.1303（A：FMC が位置の把握に良い局を選ぶ）、p.1304（手で入れられるのは VOR か ILS でない DME）、FMSPG p.206（TACAN の同調は別の機能で、ふつうは無効）。
- 見つけたこと：EDDF の近くで VOR L を手で FKS にすると、VOR R の自動同調（A）が WIB（Wiesbaden の TACAN 114.10。X-Plane の航法データでは VOR の行で、名前が「... TACAN」）になり、X-Plane の NAV ラジオは局名を出さず、ND は周波数だけで記号も無かった（10-26 は R が RID に変わった）。段 10b（§87）の A の候補は DME-DME の組の局で、TACAN の DME も入る。
- 直したこと（`B747.68.xt.fms.lua`）：VOR の A の候補から TACAN だけの局を外す（組の残りと、近い順の他の局で 2 つまで）。経路の VOR（R）と手続きの局（P）からも外す。DME-DME の位置の更新には今までどおり TACAN の DME を使う。
- 試験：回帰 `navrad_pages_test` +2（試験データの遠く（北緯 40°・東経 150°）に TACAN・VOR/DME・DME を足し、その近くで VOR は TACAN に合わない：48 件。直しなしでは 2 件落ちる。足した局はほかの試験の場所から 200 NM より遠く、FMS の試験は全部そのまま通る）。X-Plane（2026-11-03 の 2 回目の再試験）：`s69` 15/15（VOR R の局の記号が FKS の入力から約 22 秒で出た。DME-DME の局の見直しは 10 秒ごと）。

## 142. procedure turn の段階の終わりと、試験キットの watch（2026-11-04：全シナリオの回の s98）

- 見つかったこと：`s98_pturn` の最後の段階（戻りの脚、段階 4）で、LNAV の横のずれが 0.655〜0.679 NM（上限 0.5）。記録 v10（`lnav_xtk`・`lnav_dtk`・`pturn_phase` の列を足した）で見ると、戻りの脚の間は −0.13〜−0.14 NM で、入航コースへの旋回を始める所で、段階 0・DTK 230 → 275・ずれ −0.13 → 0.68 NM（入航コースからの距離）が同じフレームで変わっていた。LNAV の誤りではなく、試験キットの `watch` が値と終わりの条件を別々の要求で読み、切り替わったフレームの値（次の脚のずれ）を数えてから条件を見ていた。
- 直したこと：
  - 試験キット（`run_scenario.ps1`）：`watch` は、終わりの条件が成り立ったのを見た回の値を数えない（TESTING.md）。
  - LNAV のモデル（`B747.68.lnav_model.lua`）：procedure turn は順送りを求める所（入航コースへの旋回の始まり）で段階を「end」にする（`laminar/B747/fms/lnav/pturn_phase` 0）。前は経路が順送りされるまで「back」のままで、モデルの上では次の脚を飛び始めても段階 4 だった（オフラインの閉ループ：「back」の間に次の脚の線が先頭になっていた）。X-Plane のグルーは経路の先頭が procedure turn のときだけ段階を出すので、見える違いは小さい（推定）。
- 試験：回帰 `lnav_pturn_test`（段階の並びに「end」、「back」の間は次の脚が先頭にならず「end」でなる：18 件、直しなしでは 2 件落ちる）。X-Plane（2026-11-04）：`s98` 16/16（戻りの脚のずれ 0.127〜0.142 NM）。
- 2026-11-04 の調整（利用者の質問「フラップ 20、170 kt の水平で A/T が振動するのはどうにもならないの？」）：
  - 見つかったこと：s112 と新しい測定 `tests/flight/measure/at_hold_f20.json`（フラップ 20・脚下げ・170 kt の水平を 120 秒）で、レバーが約 21 秒周期で振れ、収まるのに約 100 秒かかった（20 秒ごとの振れ幅 0.25 → 0.20 → 0.14 → 0.08 → 0.05）。レバーは則の速さを積み上げるので、K_ACC はレバーの「速度 1 kt あたり」の利得、K_SPD はその積分の利得にあたる。この形態ではレバー 0.1 で加速度が約 0.6 kt/s 変わり、エンジンの遅れ（2〜7 秒）と加速度のならし（1 秒）に対してループが強すぎた。ALT HOLD の上下とも組になる（推力で機首が上がり、上昇で速度が落ちると A/T がさらに推力を足す）。
  - X-Plane で比べたこと（同じ測定、20 秒ごとのレバーの振れ幅、20〜40 秒と 60〜80 秒）：今の則 0.25・0.14、K_SPD 0.003 だけ 0.36・0.21、減衰にエネルギーの率（昇降率が速度に変わる分を足す）0.32・0.46（振れが続いた）、両方を半分（0.002・0.03）0.23・0.008、両方を 3/4（0.003・0.045）0.14・0.027、ならしを 0.5 秒 0.17・0.041、3/4 とならし 0.5 秒 0.091・0.006。
  - 直したこと：K_SPD 0.003・K_ACC 0.045（目標への近づき方の 15 秒は同じ）、A/T のグルーの加速度のならしを 0.5 秒（推定）。
  - X-Plane：`s220` 15/15（340→252 kt が 95.2 秒、アイドルまで 2.1 秒、250 kt の保持でレバー 0.171 のまま、290 kt へ 26.5 秒）、`s01` 250 kt でレバー 0.158〜0.228（注意 1 件は空中開始の上昇の後の高度）、`s112` の捕捉の前の水平でレバーが動かない（捕捉の浮きは +0.323 ドットで残り）。

## 143. ND の FMC の記号の残り：FIX INFO の基準点・方位線・距離の円、PRED ETA-ALT、OFFPATH DES とエネルギー管理の円（2026-11-04：利用者「作れるなら作ってね」）

- 対象（DSP-23 の残り、FCOM p.1149–1150 の表）：FIX INFO の基準点と方位・距離（緑の破線：MAP・MAP CTR・PLAN）、PRED ETA-ALT の点（緑の profile の円と入れた時刻か高度：MAP・MAP CTR）、OFFPATH DES のエネルギー管理の円（clean は青、drag は白：MAP・MAP CTR）。§39 で残した FIX INFO の交点の ETA と ALT、PRED ETA-ALT の距離（予測待ち）も。
- 資料：
  - FIX INFO（FCOM p.1358–1359；FMSPG p.166–169）：入れた FIX は ND に小さい円で囲んで出す（FMSPG p.166）。方位は FIX からの放射線、距離は FIX のまわりの円（FCOM p.1358–1359）。交点の ETA・DTG・予測の高度（FMSPG p.168；FCOM p.1358 の図：`130/24 2004z  10 12000`）。PRED ETA-ALT は経路に沿った距離と入れた値（図：`112NM 2016z`）、ND の経路の上に緑の円と入れた値、過ぎたらダッシュに戻る（FMSPG p.169）。ERASE FIX で ND からも消える。
  - OFFPATH DES（FCOM p.1398–1399；FMSPG p.190–194）：DES TO は DES のページの E/D（最後の高度制限つきの降下の点）、データベースの点を入れられ、DELETE で E/D に戻る。中央に直線の距離（DTG）。SPD/ALT は E/D か、入れた点が制限つきの現用の経路の点ならその制限、ほかは箱。E/D でない点は、その高度の 150 ft の内で E/D に戻る。ECON SPD・SPD TRANS・SPD RESTR は DES のページと同じ。CLEAN CIRCLE は速度ブレーキなしのアイドル降下、DRAG CIRCLE は速度ブレーキ全開のアイドル降下で、その点の速さと高度で通るのに要る距離の円までの距離（内側で負）。DRAG は clean の円の内側に入ってから出す。FORECAST>、<DES、DISPLAY SELECT ON>/OFF>（ON で clean の円、clean の内側に入ったら drag の円も ND に）。DES のページと（109 の）DESCENT FORECAST の 6L の <OFFPATH DES から。
- 作ったもの：
  - 予測の形（`B747.68.pred_model.lua` の `profile`・`profile_at`・`profile_alt`・`profile_time`）：予測の点（今の位置、各点、T/C は CRZ ALT、S/C はその前の点の高度、T/D は最後の巡航高度）を距離の順に直線でつなぐ（推定：点の間の上昇・降下は直線でない）。FMC のグルー（`B747_fms_pred_at`・`_alt_x`・`_time_x`・`_pos`）。
  - FIX INFO（`B744.fms.pages.fixinfo.lua`）：交点の ETA を 9〜12 桁（z は小字で 13 桁）、予測の高度を 24 桁までに右寄せ（10 ft 単位）。過ぎた交点は空白（推定）。PRED ETA-ALT は経路に沿った距離を 16 桁までに右寄せ、NM は小字。時刻は今から先の時刻（今より前は翌日のものとして経路の外：空白）。有効だった点を過ぎるとダッシュ（予測があるときだけ）。
  - ND（FMC → FMS ブリッジ・ND のモジュール）：方位は FIX から 512 NM の大円の線（推定：交点を探す範囲と同じ長さ）を ND の線の点に（形 6：緑の破線）。円は新しい `laminar/B747/nd/circle/*`（最大 8 個、中心・半径 NM・形）で FMS ブリッジ（`nd_line.c`）が 72 の大円のかけらで描く（形 6 は PLAN でも、7・8 は MAP と MAP CTR だけ）。FIX は ND のモジュールが記号の絵の 12 番（緑の小円と中の記号、元の絵にあって使っていなかったもの）と緑の名前で（その点の記号が名前を出していれば名前は出さない）、PRED の点は profile の円（8 番）と入れた値。名前と値は `laminar/B747/fms/fix/*` の文字の番号の配列で渡す（XTLua のプラグインをまたぐ文字の dataref を避けた）。
  - OFFPATH DES（新しい `B744.fms.pages.offpath.lua`）：上の資料どおりの行（FCOM p.1398 の図の桁：DTG・CLEAN・DRAG は 14 桁まで、SPD/ALT は 24 桁まで）。円の半径は予測の降下の道（`pred_model.offpath`：点の高度から上へ、DES のページの速さと、点の速さをその直上の制限にして、今の高度に達するまでの距離）。速度ブレーキ全開は抵抗を 1.58 倍（推定：FCTM p.138–139 の降下率、.83/340 kt で 2,800 → 4,300 fpm、250 kt で 1,300 → 2,100、VREF30+100 で 1,200 → 1,900）。風は予測の降下の向かい風（経路の風ではない：経路を外れた降下）、重さは今の重さ（推定）。目安：FL350 から 10,000 ft で clean 約 79 NM、drag 約 50 NM。
- 試験：
  - 回帰（LuaJIT）：`pred_model_test` 94（形、距離での高度と時刻、高度と時刻の点）、`fixinfo_pages_test` 73（ETA・ALT の桁、PRED の距離と NM、過ぎたらダッシュ、ND への出力と dataref）、新しい `nd_fixinfo_test` 9（記号 12 と名前、PRED の円、範囲、PLAN、VOR）、新しい `offpath_pages_test` 34（DES の 6L、ページの行、DES TO と箱、SPD/ALT、CLEAN・DRAG、ND の円、150 ft、DELETE、<DES、DESCENT FORECAST の 6L）。全部で 201 本。
  - X-Plane（カスタム acf、2026-11-04）：`s96_fixinfo` 33/33（予測のために COST INDEX と CRZ ALT FL250 を足した）：`360/22  0104z  21 FL176`、`029/30  0101z  4 11310`、ABEAM `007/22  0104z  18 FL165`、ND に KOUGA の記号と名前、360 の放射線、30 NM の円（写真）。新しい `s221_offpath_des` 17/17：FL359 で DES TO AKAGI（47 NM）・/5000、CLEAN −57・DRAG −19（半径 104 と 66 NM）、ND に clean の青と drag の白の破線の円（写真）、SELECT OFF で消える。Lua の誤りなし。

## 144. FMC 側の IRS・航法・同調の更新を 747 の母線で（2026-11-04：1-1 の残り）

- 見つけたこと：FMC のモジュールが、IRS の状態の写し（CDU の POS INIT・POS REF・IRS MONITOR と ND の TIME TO ALIGN の行）、航法の性能（ANP、位置の更新の行）、無線の自動同調を、X-Plane の `bus_volts[0]` が 22 V を超えるときだけ回していた（`B747.68.xt.fms.lua` の毎フレームの関数）。747 の電源のモデル（1-1）とは別の判定。
- 資料：左 FMC は機長側の transfer bus か APU standby bus、右 FMC は副操縦士側の transfer bus（FCOM p.800、p.804）。同調は FMC の選択で選んだ FMC（ATA34_2 p.496。§98・§101 で済）。
- 直したこと（`B747.68.xt.fms.lua`）：
  - IRS の状態の写しは、FMC の母線（機長側 transfer、APU standby、副操縦士側 transfer）のどれかに電源があれば回す。FMC が故障していても止めない（ND の TIME TO ALIGN は FMC の故障に依らない：推定。この機体ではこの行を FMC のモジュールが作っている）。
  - 航法の性能は、FMC が 1 台でも動いていれば回す。同調は今までどおり選んだ FMC が動いているとき。
  - 電池だけの地上（STANDBY POWER AUTO）では APU standby bus がインバーターで通電するので、今までどおり IRS の整列が見える。APU の始動中の 65 秒（APU のインバーターが止まる：1-1）は止まる。
- 試験：新しい回帰 `fms_power_test`（X-Plane の bus 0 が無くても FMC の母線で TIME TO ALIGN、母線が全部無いと更新しない、APU standby bus だけで更新、左 FMC の故障でも右の母線で更新）。
- X-Plane（カスタム acf、2026-11-04）：`s42_irs` 48/48（電池だけの整列中（APU standby bus はインバーター）と、APU の発電機で AC が来た後に、ND の TIME TO ALIGN（`laminar/B747/irs/line1`）を足した）、`s173_fmc_fail` 23/23（左 FMC の故障）。Log.txt に Lua の誤りなし。

## 145. 3 本の平行滑走路の「B」と、DEP/ARR INDEX の桁（2026-11-05：利用者の報告、別の PC のラインフライト）

- VHHH の STAR CANT3B で ILS25C を選べなかった：CIFP の CANT3B は滑走路の遷移が「RW25B」。ARINC 424 の「B」は同じ番号の平行滑走路すべてで、VHHH（2026 年のデータで 07L/25R・07C/25C・07R/25L の 3 本）では 25C も入る。FMC（`B747.68.proc_model.lua` の `rwy_matches`）は B を L と R にしか広げず、ARRIVALS で CANT3B と 25C の進入を組み合わせられなかった。C も入れた（DEPARTURES の SID も同じ）。Navigraph の AIRAC 2610 で、CANT3B が 25C・25L・25R を受け持つことを確かめた。なお X-Plane に付いてくるデータ（AIRAC 2406）の VHHH には 25C が無い。
- DEP/ARR INDEX の空港コードが少し左にずれていた：FCOM p.1299 の絵（24 桁）では、題「DEP/ARR INDEX」は 7 桁目、小さい「RTE 1」は 9 桁目と「(ACT)」は 16 桁目、出発と到着の空港コードは 10 桁目から。前は題が 6 桁目、RTE が 11 桁目、空港コードが 9 桁目だった。絵に合わせた（ARRIVALS・DEPARTURES の題は前から FCOM p.1343 と同じ 4 桁目）。
- 試験：`proc_model_test` 64（B の 3 本）、`deparr_pages_test` 40、`rte2_pages_test` 57。
- X-Plane（カスタム acf、2026-11-05）：新しい `s250_user_report_nd` の DEP/ARR INDEX の部分（RJAA→RJBB で、題が 7 桁目、RJAA と RJBB が 10 桁目。CDU の写真）。VHHH の 25C は、X-Plane に付いてくるデータに無いので試せない（Navigraph のデータで回帰試験と同じ組み合わせになることは確かめた）。

## 146. LEGS の「XXXS」：乗員の計画ステップクライム（2026-11-05：利用者の報告「LEGS の高度欄に〇〇S と入れてもステップクライムを設定できない」）

- 資料：LEGS の高度の後ろの文字の一つが「S：計画ステップクライム」（FCOM p.1332）。乗員が LEGS に入れた計画ステップは、FMC のステップクライムの予測と CRZ の STEP TO に優先する（FCOM p.1257 の Step Climb）。前は S を受け付けず INVALID ENTRY だった。
- 作ったこと：
  - `B747.68.route_model.lua` の `set_step`：経路の途中の地点（SID・STAR・進入の地点とホールドを除く）に、CRZ ALT より上で 45,100 ft 以下のステップ高度を持たせる（入れられる条件は資料に無く、推定）。地点の高度欄は 1 つなので、高度の制限（とその速度）と置き換え合う（推定）。DELETE で消える。表示は「/FL350S」（他の制限と同じ書き方）。
  - LEGS のページ：「350S」「FL350S」「/FL350S」を受け付ける。速度つき（「250/370S」）は INVALID ENTRY（推定）。ホールドの SPD/TGT ALT では S を受け付けない。予測の小さい字は速度だけ。
  - 予測（`B747.68.pred_model.lua`）：巡航中、その地点で次のステップ高度へ上がる。計画ステップが 1 つでもあれば、FMC の最適なステップは使わない（FCOM p.1257）。
  - CRZ のページ（`B744.fms.pages.vnav.lua` の `B747_fms_crz_step`）：CRZ ALT より上の最初の計画ステップを STEP TO に出し、AT はその地点までの時刻と経路沿いの距離。距離は表示のたびに機体の位置から計算する（予測は 10 秒ごとで、480 kt では 1.3 NM 進むため）。地点の 1 NM 手前から NOW、その地点が順送りされた後も（旋回では手前で順送りされる）次の地点まで NOW（推定）。計画ステップがあるあいだ、乗員の STEP TO の入力より計画ステップを出す。
  - シムの便利機能のオートステップクライム（§126）は、この STEP TO と NOW で動く。
- 試験：`route_model_test` 264、`legs_pages_test` 72、`pred_model_test` 101、`vnav_pages_test` 84。
- X-Plane（カスタム acf、2026-11-05）：新しい `s252_legs_planned_step` 23/23（FL310 で成田の東から空中開始、約 60 NM 東の緯度経度の地点へ DIRECT、LNAV・VNAV PTH）。LEGS の 1R に 290S（CRZ ALT の下）と 250/370S は INVALID ENTRY、350S で MOD、EXEC の後も `N35E141 /FL350S`（予測の .839 が小さい字で横に）、次の地点の予測は FL350（写真）。CRZ のページは STEP TO FL350、AT `0107z/ 45NM`（写真）。Auto step climb を ON にすると、地点の 0.9 NM 手前で MCP が 35,000 ft、CRZ ALT が FL350、VNAV SPD の巡航上昇で上がり始めた。1 回目は「CRZ ALT の下」のつもりの 330S が FL310 の上で受け付けられ、試験の誤りで 22/23 だった。

## 147. 上昇の高度制限を、オーバーシュートで次へ送らない（2026-11-05：利用者の報告「FAOR 03L から EXOB1C で LNAV/VNAV がめちゃめちゃ」）

- 再現：利用者の機体は GE（South African Airways ZS-SBK）だった。PW の `s251_faor_exob1c` 33/33 では崩れなかったが、GE のリバリー（Qantas VH-OEJ、CF6-80C2）の新しい `s253_faor_exob1c_ge` で、EXOB1C の OR390 の「FL090B」（以下）の手前で FL090 を越えて 15,000 ft（MCP）まで上がった（31/33）。
- 記録（`session.csv`）：GE は推力が大きく、約 3,600 fpm で上がりながら 7,900 ft で VNAV PTH の捕捉に入り、9,000 ft を越えて 9,104 ft になったところで FMA が VNAV PTH から VNAV SPD（THR REF）に変わり、上がり続けた。PW は約 60 ft の行き過ぎで 9,000 ft に留まった。
- 原因（`B747.68.xt.fms.lua`）：上昇の目標の高度制限を「機体の高度 −100 ft より上の最初のもの」で選んでいた。100 ft を越えて行き過ぎると、OR390 の手前でも FL090 を通過したものとして次の FL110 を目標にし、AFDS は FMC の目標が動いたので VNAV PTH の水平を外した。FCOM p.1255：VNAV は VNAV PTH で出発や地点の制限の内に留まる。
- 直したこと：`B747.68.vnav_model.lua` の `clb_target`。上昇の制限（AT・AT OR BELOW・ブロックの上）を地点つきで持ち、その地点を過ぎる（順送り）まで、機体の 300 ft 下までは目標のまま（`CLB_HOLD_FT`：捕捉の行き過ぎの幅。推定）。それより下に離れたら前と同じく次へ。地点の無い制限は前と同じ 100 ft。目標が動かないので、AFDS の VNAV PTH の高度保持が 9,000 ft に戻す。
- 試験：`vnav_model_test` 200（9,104 ft でも FL090、290 ft 上まで、500 ft 上は FL110、OR390 を過ぎたら FL110、地点なしは 100 ft、CRZ ALT の上は無し）。
- X-Plane（カスタム acf、2026-11-05）：`s253_faor_exob1c_ge` 33/33（直す前は 31/33）。捕捉の行き過ぎは今も最大 9,141 ft（VNAV PTH のまま）あるが、目標が FL090 のままなので 9,000 ft に戻り、旋回の後から OR390 までは 8,996〜9,023 ft、OR390 で VNAV SPD に戻って上昇し、15,000 ft（MCP）で VNAV ALT。PW の `s251_faor_exob1c` も 33/33（OR390 まで 8,995〜9,010 ft）。GE の捕捉の行き過ぎ（PW の約 2 倍）は AFDS の捕捉の則の課題として残る。

## 148. シムの便利機能：CDU の重量と CG をシムから、重量と CG の窓（2026-11-05：利用者の依頼）

- 利用者の依頼（2026-11-05）：「便利機能として PERF INIT ページの GROSS WT や ZFW、TAKEOFF ページの CG TRIM のボタンを押したら自動で現在の値が入力されるようにしてほしい」と「Failure ウインドウを出してくれるプラグインに、現在の各重量の値や各 CG を示すウインドウを追加してほしい」。どちらも実機に無いシムの便利機能（§126 と同じ扱い）。
- CDU（`B744.fms.pages.lua`、`activepages/B744.fms.pages.perfinit.lua`）：スクラッチパッドが空のまま、PERF INIT の GR WT（L1）を押すと X-Plane の総重量（`sim/flightmodel/weight/m_total`）、ZFW（L3）を押すとそれから燃料（`m_fuel_total`）を引いた値を、千 kg の 0.1 に丸めて入れる。入れた後は手で入れたのと同じ（もう一方は FUEL から、TAKEOFF SPEEDS DELETED も同じ）。TAKEOFF REF の CG（R4）は、X-Plane の今の CG（`sim/flightmodel2/misc/cg_offset_z_mac`、ペイロードと燃料込みの % MAC）を整数に丸めて入れ、トリムはそこから。0〜40 % の外なら前どおり INVALID ENTRY。スクラッチパッドに何かあれば前どおり。
- 切り替え：Plugins → 747-400 の「CDU: GR WT, ZFW and CG from the sim」（`laminar/B747/options/cdu_sim_values`、コマンド `..._toggle`）。ほかの便利機能と違い、設定ファイルに無ければ入（利用者の依頼なので）。切ると前どおり（空のスクラッチパッドは INVALID ENTRY。実機はその行の値をスクラッチパッドに写すが、ここは作っていない）。
- X-Plane の値は毎フレーム読む（`update_perf`。XTLua はときどきしか読まない dataref に前の読みの値を返し、最初の読みは 0：TESTING.md）。
- 重量と CG の窓（`plugins/b747_fms_bridge/src/wb_window.c`）：Plugins → 747-400 → Weight and balance...（コマンド `laminar/B747/wb/window_toggle`、`laminar/B747/wb/window_open`）。故障の窓と同じ X-Plane の枠の浮動ウィンドウで、X-Plane の今の値を kg と lb で：総重量、ZFW（総重量 - 燃料）、燃料、ペイロード（`m_fixed`）、空虚重量と最大重量（acf の値）、CG（% MAC）、ZFW の CG（% MAC）、タンクごとの燃料（X-Plane のタンク 0〜7：CTR、MAIN 1〜4、RES 2、RES 3、STAB）。
- ZFW の CG：X-Plane には ZFW の CG の % MAC が無い（`zfw_cg_offset_z` は m）。今の CG の % MAC に、ZFW の CG と今の CG の差（m）× 9.537 % / m を足す。9.537 は X-Plane のこの acf の MAC（10.49 m）の値で、2026-11-05 にカスタム acf で測った：安定板タンクに 8 t・3 t 入れると `cg_offset_z` が 0.857・0.257 m 後ろへ動き、`cg_offset_z_mac` が 8.17・2.45 増えた（実機の MAC は 8.33 m。X-Plane は acf の翼から計算する）。`cgz_ref_to_default` と `cg_offset_z` への Web API の書き込みは X-Plane に戻された（測るのに使えなかった）。
- 試験：`perf_init_test` 38（GR WT・ZFW、ポンド）、`takeoff_ref_test` 62（CG、範囲の外）。X-Plane：`s256_cdu_sim_values`。

## 149. A/T の SPD の速さの下限：フラップ UP は最小機動速度そのもの（2026-11-07：性能計測のフェーズ1の報告）

- 報告（PERF_SIMBRIEF のフェーズ1、2026-11-06）：307 t・FL370 で MCP を M.85 にしても、A/T は M.858（IAS 約 280 kt）を保ち、6 分たっても下げなかった（`tests/flight/perf/runs/20261106_193826_cruise/raw/crz_078_fl370_m850.csv`）。
- 原因：A/T の servo（`B747.70.at_model.lua`）の SPD は、目標を `v_min + LIMIT_MARGIN`（最小機動速度 + 5 kt）より下げなかった。この点の最小機動速度は約 276 kt で、M.85 は約 278 kt なので、目標は 281 kt（M.858）になっていた。
- 資料：FCOM p.675（4.20.17）では、失速の保護は「最小機動速度より下げない」。FMC が 5 kt の余裕を取るのは、最大運用・脚下げ・フラップの制限速度の行き過ぎと、フラップを出したときの最小の速さの下回りに対してだけ。
- 直したこと：SPD の下限は、フラップ UP では最小機動速度そのもの、フラップを出していれば + 5 kt。AFDS のピッチの速度の則（`afds_pitch_model.lua`）と同じ形。最大の側の 5 kt はそのまま。フラップ UP は、レバーが UP（`flap_ratio_control` < 0.01）で見る。ピッチの則と同じ。
- 試験：`at_model_test` に 3 件。フラップ UP で目標が v_min の 2 kt 上なら保つ、v_min より下なら v_min まで上げる、フラップを出していれば v_min + 5 kt。前のモデルでは、フラップ UP の 2 件が落ちる。
- X-Plane：新しい `s262_at_vmin_margin`（フェーズ1の点と同じ初期化：307.8 t・FL370・ISA の無風）。
  - 空中の初期化は A/T を ARM にするだけなので、SPD を押す。
  - Mach は .852〜.853（IAS 278.0 kt。窓の M.85 の CAS は 278.2 kt）に落ち着いた。前は M.858。
  - 最小機動速度は 275.5 kt。

## 150. 段 9i：VNAV の engage とサブモードの作り直し（2026-11-07：利用者の依頼、順番の入るところで）

- 前の状態（2026-11-07 の HEAD `4d8bfcca` の調べ）。どこが何を決めていたか：
  - FMC の VNAV のモデル（`B747.68.vnav_model.lua`、段 9b〜9h）：段階（CLB・CRZ・DES、cruise climb・descent、早期降下）、FMC の求めるサブモード（SPD・PTH）、A/T のモード、目標の速さと高度、降下の経路と V/S、THRUST・DRAG REQUIRED、速度の逆戻り、CHECK ALT TGT（engage の時だけ）、valid。T/D を過ぎても MCP が巡航高度なら巡航のまま（推定、RESET MCP ALT）。
  - 自動操縦のつなぎ（`B747.70.xt.autopilot.lua`）：`afds_vnav_level` が VNAV ALT（MCP 高度の捕捉）と VNAV PTH（FMC 高度の捕捉：VNAV SPD と cruise descent）の水平、その再開（MCP を 50 ft 動かして押す、経路の下なら経路が降りて来て）、`afds_old_vnav_fma` が FMA の 4・5・6、`afds_pitch_inputs` が則（SPD→FLCH の速度の則、降下と cruise descent→V/S の則、PTH→ALT の則）。ピッチの入力を作るたびに走るので 1 フレームに 2 回。
  - engage（つなぎの `vnav_engaged`）：FMC の valid と、arm からは master FMC・空中・RA 400 ft。engage の後も valid が要り、消えると AFDS のモデルが今の高度の ALT HOLD にした（ATA22 p.338 の「MCP 高度で master FMC が故障」を広げた推定）。`B747_ap_altitude` は FMC の valid が無いと arm を消した（経路が無いと VNAV が外れる：DIFFERENCES の「残り」）。VNAV スイッチは性能のデータが無いと PERF/VNAV UNAVAILABLE を出して arm しなかった。
  - MCP 高度の食い違いは「捕捉」だけ：MCP 高度に近づくときの VNAV ALT はあったが、上昇で MCP を機体の下に、降下で上にしても VNAV は離れていった。T/D で MCP が巡航高度なら VNAV PTH のまま（FMSPG p.34 (2-22) は VNAV ALT）。上昇の制限が機体の 300 ft より下（点はまだ先）なら飛ばして上がり続けた（`clb_target`）。捕捉はノブを回している途中の MCP 高度（100 ft ごと）でも起きた（V/S・FLCH は 3 秒後に写す X-Plane の高度で捕捉する：`setSimAlt`）。
  - 前の VNAV のコード：monitor の `VNAV_modeSwitch` は `vnav_state` が 2 以上でも 1 以下でも戻るので、上昇・巡航・降下（`VNAV_CLB`・`VNAV_CRZ`・`VNAV_DES`、`checkMCPAlt`）は段 9c から走らない。`vnav.lua`（`setDescentVSpeed` など）と `vnavspd.lua` の速度の状態機械も呼ばれない。生きているのは `vnavspd.lua` の状態の表（`manualVNAVspd`：速度介入、`recalcAfter`：前の LNAV）と、VNAV でない間の `B747_monitor_THR_REF_AT`（前の flightPhase）だけ。
- 資料：
  - engage（FCC）：ATA22 p.340–341（22-12 p.14–15、図：VNAV の要求と TRANS ENABLE で ARM の latch、2 回目・APP の要求・engage で消える。ARM と FMC DATA VALID で ENGAGE の latch、新しいモードで消える。表示はこの latch、則への ENGAGE の出力は latch と VNAV VALID。p.340 は VNAV valid を FMC から来るものとする）、p.279（22-10 p.105：G/S 以外のどのモードからも arm、engage には FMC の縦の profile が要る）。
  - engage（FMC）：ATA34_2 p.621（34-61 p.195、図：VNAV CONTROL＝software monitor・sensor data・PERF の入力・400 ft の上・VNAV ARM/OPERATE。VNAV SPD は上昇か段の降下、VNAV ALT は MCP 高度を横切るとき、VNAV PTH は有効な経路と巡航か降下）。FCOM p.645（4.10.7：400 ft で activate、データが足りないと PERF/VNAV NOT AVAILABLE。例は総重量と、降下で E/D が無いこと）、p.1433（11.60.5：PERF/VNAV UNAVAILABLE は総重量・CI・巡航高度）。
  - サブモード：ATA22 p.279–280（22-10 p.105–106：VNAV SPD は上昇・選んだ降下・PTH からの逆戻り、SPD から PTH で FMC 高度の捕捉、VNAV ALT は SPD か PTH の降下で MCP 高度を FMC 高度より先に捕捉したときと、FMC の目標が MCP 高度から離れさせるとき）、ATA34_2 p.615–616（4 つの制御）、p.624（34-61 p.198：profile が MCP 高度を越えるか離れるなら FMC が MCP 高度を捕捉して保つ：VNAV ALT）、ATA22 p.338（22-12 p.12：VNAV の ALT HOLD の既定は、機体が FMC と MCP の高度の間で FMC の目標が MCP から離れる向きに変わったとき、FMC の目標が MCP 高度を越えるか離れさせるとき、MCP 高度で master FMC が故障したとき）、FMSPG p.34（2-22：profile の上昇・降下の始まる所で MCP が今の高度なら VNAV ALT）、FCOM p.1256（11.31.22：FMC に無い MCP 高度で水平なら VNAV ALT）、p.643（4.10.5：降下の VNAV PTH で窓を開けると VNAV SPD、制限を intercept するまで）。
  - 食い違いの向き：FCOM p.665（4.20.7：VNAV の profile と MCP 高度の食い違いで水平になり VNAV ALT、高度を保つ）、FMSPG p.226–227（4-15、4-16：待機経路の節。上昇の段階で降下の指令を出さない、降下の段階で上昇の指令を出さない。VNAV を engage した時に MCP や制限の向こうにいれば今の高度で水平。降下では上からの MCP 高度をいつも捕捉する。AT OR BELOW は制限と経路の低い方まで、AT OR ABOVE は高い方まで降りる）、p.128（3.3-19：上昇で機体より下の上昇の制限を入れると、VNAV は水平になりその点まで保つ）、FCOM p.1261（11.31.27：on approach では MCP を 300 ft 以上上にしても降下を続ける。それ以外の降下では上の MCP で止まる、と読める）。
  - 上昇と降下の制限：FCOM p.1255（11.31.21：VNAV PTH で出発（departure）と点の制限の内に）、p.1258（11.31.24：到着・進入の手続きの点は降下の点。巡航で先の点に入れた制限は E/D を作る）、FMSPG p.114（3.3-5：上昇の制限は手続きの選択か乗員の入力）。
  - 進入の MCP 高度：FCTM p.187（5.41：最終進入の VNAV PTH で、着陸復行の高度の 300 ft 以上下になったら MCP を DA(H) からその高度へ）。
  - 再開：FCOM p.645、p.665（MCP を直して高度セレクターを押すか、ピッチのモードを変える。経路の下なら MCP を直して経路に会えば続く）、p.649（4.10.11：巡航で押すと cruise climb・descent、50 NM の内の早期降下）。
  - VNAV の終わり：FCOM p.645（TO/GA・FLCH SPD・V/S・ALT・G/S、FMC 2 台の故障）。engage の後に FMC のデータが無くなったとき：ATA22 p.341 の図では則への ENGAGE が VNAV VALID で消えるが（表示の latch は残る）、そのときのピッチは資料に無い（FCOM p.1431 の DESCENT PATH DELETED は「VNAV active」のまま）。
- 作ったもの：
  - 新しい純粋なモデル `B747.70.vnav_mode_model.lua`（`B747_vnav_mode_model`、自動操縦のモジュール）：
    - `can_engage`：FMC DATA VALID（FMC の valid、master FMC、空中で RA 400 ft の上）。
    - `unavailable`：VNAV を arm する押しで PERF/VNAV UNAVAILABLE（性能のデータが無い、か降下で FMC の valid が無い）。
    - `update`（毎フレーム 1 回）：FMC の誘導の則（SPD→速度の則、降下と cruise descent→V/S の則、ほかは ALT の則）とその向き（上昇の SPD は上、ほかの SPD と下向きの V/S は下、ALT の則は 0、ただし `td_hold` は下）に従い、次の水平を持つ：
      - "fmc"（VNAV PTH、FMC 高度）：VNAV SPD か cruise descent で FMC 高度を MCP 高度より先に捕捉（同じ高度なら MCP の捕捉でも）。FMC 高度が 50 ft より動くか `td_hold` で終わる。降下の経路（V/S の則）では FMC の制限で水平にならない（経路は制限を通って続く：LF2 のとおり VNAV ALT）。
      - "mcp"（VNAV ALT）：MCP 高度の捕捉（MCP 高度で）、または MCP 高度が FMC の向きの先に無く機体が MCP の 100 ft の内（今の高度で profile が離れる：T/D の `td_hold`、ENG OUT の driftdown の始め＝FCOM p.1268 の条件 2 もここ）。後者は MCP が向きの後ろ 20 ft の内なら MCP 高度、それより後ろならその時の高度（向きに逆らって戻らない：推定）。
      - "hold"（VNAV ALT、その時の高度）：MCP 高度が FMC の向きの後ろに 100 ft より離れている（上昇で下、降下で上）。on approach の降下で MCP が 300 ft 以上上なら食い違いにしない。
      - "far"（VNAV PTH、その時の高度）：VNAV SPD・cruise descent で FMC 高度が向きの後ろに 100 ft より離れている（上昇の制限が下：FMSPG p.128。降下の下限が上：FMSPG p.227。降下の FMC 高度は下限で、AT OR BELOW は FMC が経路との低い方にして渡す）。FMC 高度が動く（点を順送り）か向きが変われば終わる。
      - "invalid"（VNAV PTH、その時の高度）：engage 中に FMC の valid が無い。valid で終わる。ほかの水平は valid が無い間も続く。
      - VNAV ALT（"mcp"・"hold"）は、押しの時に食い違いが無ければ終わる（MCP を直してから押す。押してから直しても続かない）。経路の下で MCP を直したなら経路が降りて来て終わる（直した時に判定：LF2）。on approach の降下で MCP が 300 ft 以上上になれば押さずに終わる（FCOM p.1261）。FMC がその高度を自分で保つ（ALT の則、向き 0、高度が同じ）と VNAV PTH に。
      - 降下の経路の水平な所（FMC の V/S が 100 fpm より浅い：向き 0）では、食い違いと FMC 高度の捕捉は無いが、上からの MCP 高度は捕捉する（FMSPG p.227）。MCP が 20 ft より上なら捕捉しない。
      - 出力：FMA（4・5・6）、則と目標（`p.vnav_law`・`vnav_vs`・`vnav_alt`）、A/T のモード（水平の間は SPD：FCOM p.645）。
  - つなぎ：`afds_vnav_mode` を AFDS のモデルの後（その frame の engage の後）、ピッチの則の前に 1 回。捕捉は AFDS のピッチの則の `capture`（0.05 g の引き起こし）。MCP 高度の新しい水平（VNAV ALT と MCP 高度の捕捉）は、MCP 高度が落ち着いてから作る（`afds_vnav_mcp_settled` がモデルの `settled` に：窓の値が `VNAV_MCP_SETTLE_S`＝3 秒、実時間の SIM_PERIOD で数えて変わらないか、高度セレクターを押した後。押しは設定の終わり）。持っている水平の終わり方と FMC は窓の値をすぐ使う。`afds_vnav_level`・`afds_old_vnav_fma`・`B747_afds_vnav_lost`・`B747_ap_altitude` の arm の取り消しを外した。A/T には `vnav_at`・`vnav_level` をモデルから（A/T のモデルは変えない）。VNAV スイッチは押しで arm し、arm した押しでだけ PERF/VNAV UNAVAILABLE。
  - AFDS のモデル（`B747.70.afds_model.lua`）：VNAV は arm と `inp.vnav_valid`（前の `vnav_engaged`）で engage する latch。FMC のデータが無くなっても終わらない（前は `old_law` の ALT HOLD。推定：上の資料）。`vnav_lost` を外した。master FMC の故障（段 11d2）はそのまま（モード故障、MCP 高度なら ALT HOLD）。
  - FMC（`B747.68.vnav_model.lua`）：
    - 新しい出力 `td_hold`（T/D を過ぎて、MCP が下でないので巡航を保つ）を `laminar/B747/fms/vnav/td_hold`（FMS の init で作る）に。
    - `clb_target`：上昇の制限（`keep`）は、点のあるものを高度によらず点を過ぎるまで目標（前は機体の 300 ft より下なら飛ばした：FMSPG p.128。engage の時なら CHECK ALT TGT、後なら AFDS の "far"）。ほかは前のまま（点があれば機体の 300 ft 下まで）。
    - `clb_keep`：上昇の制限は、SID の脚のもの（FCOM p.1255）と、手続きの無い航路の脚（乗員の入力：FMSPG p.114、p.128）で T/C（短い飛行では上昇が経路に会う T/D）の前のもの。到着・進入の脚（FCOM p.1258：降下の点）、T/C の後、cruise climb の間は上昇の制限にしない（線は推定）。つなぎ（`vnav_geo_set`）が予測の脚の手続き（`B747_fms_pred_input` の脚に `proc` を足した）と予測の T/C で決める。
    - `des_target`：降下の FMC 高度は、次の制限（AT、AT OR ABOVE、窓の下限）か E/D。AT OR BELOW は、制限とその点の経路の低い方（FMSPG p.227 (4-16)：待機経路の節、ほかでも同じとしたのは推定）。つなぎが次の制限の種類（`des_kind`）とその点から E/D までの距離（`des_e`）を渡す。早期降下・速度介入・経路の降下のどれでも。CHECK ALT TGT の「間」もこの高度で見る。
- 第 2 の手直し（2026-11-07、同じ日のレビューの指摘）：最初のパッチの次を直した。
  - 降下の VNAV SPD（速度介入、速度の逆戻り）で、次の制限が AT OR BELOW で機体より上（経路はその下）だと "far" で水平になった（FCOM p.643 は VNAV SPD のまま）。→ `des_target`。
  - ノブを回している途中の MCP 高度で VNAV ALT が固まった（前から：捕捉。パッチで食い違いの 0〜299 ft も）。進入で FCTM p.187 のとおり着陸復行の高度を DA から回すと、最終進入で VNAV ALT 1,400 ft に水平（つなぎの試験の仕組みで、パッチの前後とも再現）。→ MCP 高度が落ち着くまで MCP 高度の水平を作らないことと、on approach の 300 ft で VNAV ALT を解くこと。
  - 上昇の制限を高度によらず保つ規則が、SID の無い区間の「E/D までの前半は上昇」という推定と重なり、到着の手続きの制限で上昇が止まり得た（高度セレクターを押しても解けない）。→ `clb_keep`。
  - 降下の経路の水平な所で MCP 高度を捕捉しなかった、MCP が 100 ft の内の後ろなら向きに逆らって MCP 高度へ戻った、引用と推定の書き方（ATA22 p.341、FMSPG p.226–227）。
- 第 3 の手直し（2026-11-07、レビューの指摘 4）：IAS/MACH の窓の自動の切り替え（`B747_ap_ias_mach_mode`、notes/ATA-22.md §54）を、VNAV の arm の間も働かせた（`vnav_state < 2`：MCP の速さを飛ぶ間。前は `vnav_state == 0` だけ）。段 9i では arm が FMC のデータを待って長く続きうるので、その間に上昇で M.84 を越えても窓が IAS のままだった（FCOM p.643 (4.10.4)）。試験は `vnav_mode_glue_test` の最後（V/S で arm して待つ間に M.842 で上昇：窓が Mach に）。
- 推定：
  - 400 ft は RA のまま（FCOM p.645 は「滑走路の標高の 400 ft 上」、p.1262 の進入復行は RA）。
  - 「MCP 高度にいる」100 ft（FMC の CHECK_BAND_FT と同じ）、FMC 高度が後ろの 100 ft、降下の向きの V/S 100 fpm、MCP 高度へ戻ってよい 20 ft（ピッチの則の CAPTURE_NEAR と同じ）。
  - MCP 高度が落ち着くまでの 3 秒（V/S・FLCH の捕捉の `setSimAlt` と同じ）、押しで即。落ち着くまで MCP 高度の新しい水平を作らないこと。
  - 両方を同じフレームで捕捉したら、向きの先で近い方（前は MCP が先）。
  - "far" と CHECK ALT TGT の FMA を VNAV PTH にしたこと、"hold"（MCP が後ろ）を VNAV ALT にしたこと（FCOM p.665 の「食い違い」。p.645 の VNAV ALT は MCP 高度を保つ）。
  - FMC のデータが engage の後に無くなったとき、今の高度の VNAV PTH で待つこと（前は ALT HOLD）。
  - VNAV ALT が FMC の保つ高度と同じになったら VNAV PTH に戻すこと。
  - PERF/VNAV UNAVAILABLE の条件に「降下で FMC の valid が無い」を足したこと（FCOM p.645 の E/D の例）。経路が無いだけでは出さない（ATA34_2 p.621 は上昇の VNAV SPD に有効な経路を求めない。FMC の valid は今も有効な経路を求める：前からの簡略）。
  - 上昇の制限の線（SID と、T/C の前の航路の脚。cruise climb では無し）、AT OR BELOW の経路との低い方を待機経路の外でも使うこと。
- 利用者に見える変わり（X-Plane で確かめる）：
  - T/D を過ぎても MCP が巡航高度なら VNAV ALT（前は VNAV PTH）。MCP を下げても、経路の上なので押すまで降りない（前は MCP を下げるだけで降下した）。s148 はそのように直した（押しを足した）。
  - 降下で MCP を機体より上（on approach で 300 ft 未満も）、上昇で下にすると、その時の高度で VNAV ALT（前は VNAV が離れていった）。MCP を変えてから VNAV ALT になるまで 3 秒（押せばすぐ）。
  - 進入で着陸復行の高度をノブで回しても VNAV PTH の降下が続く（前は途中の値で VNAV ALT）。VNAV ALT の間に MCP を 300 ft 以上上にすると、押さずに降下を続ける。
  - 経路と性能のデータの前に VNAV を押すと arm して待つ（前は arm しない）。PERF/VNAV UNAVAILABLE は今までどおり出る。
  - engage 中に FMC のデータが無くなっても VNAV のまま水平（前は ALT HOLD）。
  - 上昇で、まだ先の点の上昇の制限が機体より下なら水平で待つ（前は 300 ft より下なら上がり続けた）。到着・進入の制限では止まらない。
  - 降下の VNAV SPD（速度介入・早期降下）で次が AT OR BELOW の制限なら、制限とその点の経路の低い方で VNAV PTH の水平（FMSPG p.227。前は制限の高度で）。経路がその制限の下を通るなら、制限が機体より上でも VNAV SPD のまま経路の高さまで降りる（機体が制限と経路の両方より下なら、その時の高度で水平：同じ頁）。
  - ENG OUT を MCP 高度の巡航で実行すると VNAV ALT（FCOM p.1268 の条件 2。前は捕捉の 20 ft の内だけ）。
- 残り：
  - FMC 2 台の故障で VNAV を外す（FCOM p.645）。今は段 11d2 の master FMC の故障と同じモード故障（ATA22 p.382）。
  - 前の VNAV の死んだコード（`VNAV_modeSwitch` の後ろ、`vnav.lua`、`vnavspd.lua` の速度の状態機械）を消すこと。
  - 有効な経路の無い上昇の VNAV SPD（ATA34_2 p.621）、FMC の最大高度の上で VNAV を使えないこと（FCTM p.128 (4.6)）、END OF DES の高度を固定すること（今は毎フレームの今の高度）。
  - （前から、段 9i では直さない）SID の無い区間では、予測（`B747.68.pred_model.lua` の `clb_last`）とつなぎ（`vnav_geo_set`）が E/D までの距離の前半の制限を「上昇の制限」とする。巡航と降下でも同じで、前半に入った到着・進入の制限が降下の経路（`des_cons`）と降下の FMC 高度（`g.des`）から抜ける（LuaJIT で確かめた：降下の 20,000 ft で 20 NM 先の AT 15,000 が経路に入らず、そこの予測が 20,000 ft。`clb_last` を 0 にすると 15,000）。ILS の進入では G/S で VNAV が終わるので目立たない。到着・進入の手続きの脚を上昇に入れない（FCOM p.1258）のが直し方の候補。予測が変わるので、性能計測の作業と順番を合わせる。
- 試験：
  - 回帰：新しい `tests/autopilot/vnav_mode_model_test.lua` 80 件（engage と PERF/VNAV UNAVAILABLE、上昇の VNAV SPD・MCP の捕捉・押し・FMC 高度の捕捉と順送り・同時の捕捉・MCP にいる engage・MCP が下・下の制限・巡航・`td_hold`・VNAV ALT から PTH・cruise descent・driftdown の条件 2・降下の経路・MCP が上・on approach の 300 ft と VNAV ALT を解くこと・経路の水平な所の捕捉・経路の下の再開・早期降下・降下の下限と AT OR BELOW の FMC 高度・データの喪失・進入復行、MCP が後ろ 30 ft・80 ft でその時の高度、落ち着かない MCP では水平を作らない）、新しい `tests/autopilot/vnav_mode_glue_test.lua` 45 件（つなぎを通して：データの無い arm と 400 ft、上昇の MCP が下（3 秒で）、下の制限、T/D の VNAV ALT と押し、降下の MCP が上と on approach、データの喪失で VNAV のまま ALT の則、進入で着陸復行の高度をノブで回す、on approach の 250 ft から 350 ft、降下でノブを機体の下まで回して最後の値で VNAV ALT）、新しい `tests/fms/vnav_targets_test.lua` 13 件（FMS のモジュールで：予測の脚の手続き、到着の AT OR BELOW は上昇の目標にならない、T/C の前の航路の制限はなる、降下の AT OR BELOW の FMC 高度は経路との低い方）、`afds_glue_test.lua` 280 件（PERF/VNAV UNAVAILABLE でも arm、データの喪失で VNAV PTH、arm の待ち。MCP を変える所は押しで落ち着かせた。フレームの数は前と同じにした：試験の機体は答えないので、ピッチの指令は G/S の試験の前で下限の近く）、`afds_model_test.lua` 393 件（latch）、`afds_vnav_alt_test.lua` 11 件（LF2 の試験。MCP を変えた後に落ち着くのを待つ）、`vnav_model_test.lua` 224 件（`td_hold`、`clb_target` と `clb_keep`、`des_target`）、`vnav_msgs_test.lua` 30 件（FMS のモジュールで `td_hold`）。全 231 本（2026-11-08 の取り込みでは 233 本、構文 563 本）。最初のパッチでは、新しい試験のうち model 8 件・glue 5 件・vnav_targets 5 件・vnav_model 6 件が落ちる（無い関数は仮に置いて数えた）。
  - X-Plane（カスタム acf、2026-11-08 00:59〜05:43、X-Plane を起動し直して読み込ませた）：
    - 回帰の 18 本は合格：s137 13/13、s139 28/28、s140 16/16、s141 47/47、s143 15/15、s144 29/29、s145 30/30、s146 30/30、s149 27/27、s150 34/34、s156 25/25、s157 34/34、s169 15/15、s206 17/17、s251 33/33、s253 33/33、s266 23/23、s267 15/15。直した `s148_vnav_speed_reversion` も 27/27。Lua の誤りなし。
    - 最初の s264・s148 は、利用者の設定の Auto step climb（11-06 から ON）が、巡航の VNAV で MCP を FMC の AT NOW のステップ（FL350）にして高度セレクターを押し、上昇していった。ランナーが手順の前に切るようにした（TESTING.md §4.6、コミット 3e48cf29）。
    - 新しい `s265_vnav_climb_conflicts` 22/22（警告 1）。最初は、VNAV を押したときの PERF/VNAV UNAVAILABLE がスクラッチパッドに残って、経路と PERF INIT の字が入らなかった（シナリオに CLR を足した。旗 30 は FMC が一度だけのメッセージとして出したら下ろすので、スクラッチパッドで見る）。直した後は、arm から FMC DATA VALID で VNAV SPD・THR REF。上昇で MCP を機体の下にすると、3 秒でその時の高度の VNAV ALT・A/T SPD になり、3,300 fpm から 0.05 g の引き起こしで 1,380 ft 上で止まって戻った（ALT HOLD を押したときと同じ。シナリオの幅を 1,000 ft から 1,500 ft に）。MCP を戻すだけでは VNAV ALT のまま、押すと VNAV SPD で上昇を続ける。
    - 新しい `s264_vnav_alt_td_hold` 37/40。空中開始を s143 より 25 NM 西にして、T/D の前に FL300 で落ち着かせた（1 回目は T/D が揺れの終わりと重なり、MCP の 30〜140 ft 上で T/D を過ぎた）。T/D の 2 分前に RESET MCP ALT、T/D で td_hold・VNAV ALT・A/T SPD・FMC は巡航のまま、押すだけでは VNAV ALT のまま、MCP を 10,000 ft に下げても経路の上なので VNAV ALT のまま、は合格。MCP を下げてから押しても VNAV ALT が解けなかったのは、高度セレクターの押しが 2 回に 1 回失われていたため（本家からの、放しの届かない押しの扱い。次のコミットで直す）。

## 151. 上昇の脚の決め方（2026-11-08：段 9i のレビューの指摘 3）

- 前の状態（2026-11-08 の HEAD の調べ）：
  - 予測（`B747_fms_pred_input` から `B747.68.pred_model.lua` の `clb_last`）と VNAV のつなぎ（`vnav_geo_set`）は、上昇の脚を「SID の脚、SID が無ければ E/D（無ければ経路の終わり）までの道のりの前半の脚」としていた（推定、どの段階でも）。
  - 巡航と降下でも同じで、SID の無い経路では、前半に入った到着・進入の制限が上昇の制限になり、降下の経路（`des_cons`）と降下の FMC 高度（`g.des`）から抜けた。降下中の 20,000 ft で 20 NM 先の到着の AT 15,000 は経路に入らず、そこの予測は約 17,000 ft（LuaJIT）。T/D の近くから始まる経路の短い降下ほど当たる。
  - 上昇中は、SID の後の手続きの無い脚の制限（乗員の入力）が、T/C の前でも道のりの後半なら降下の制限（E/D）になった。
- 資料：FCOM p.1258（到着・進入の手続きの点は降下の点。巡航で先の点に入れた制限は E/D を作る）、FMSPG p.114 (3.3-5)・p.128 (3.3-19)（上昇の制限は、手続きの選択か、上昇中の乗員の入力）、FCOM p.1255（出発の制限）。段 9i の `clb_keep`（上昇の制限を点まで保つかの決まり：§150）と同じ。
- 直したこと：
  - `B747.68.vnav_model.lua` に `clb_last`：上昇の脚（前からひと続き）の最後の番号を返す。SID の脚と、上昇中は手続きの無い脚を、前の予測の T/C（短い飛行では上昇が経路に会う T/D）まで。予測がまだ無ければ、経路の残りの半分まで（推定、前のまま）。到着・進入の脚と、その後の脚は入れない。巡航と降下では SID の脚だけ。cruise climb の間は T/C を使わない（手続きの無い脚は上昇に入らない）。
  - `B747_fms_pred_input`：上昇の脚をその関数で出す（前は SID の脚だけを渡し、SID が無ければ予測の側が前半の脚にした）。E/D は「上昇の脚より後の最後の制限」（前は、SID が無く上昇中なら、後半にある最後の制限だけ）。段階を出す所を前に移した。
  - `vnav_geo_set`：上昇の最後の点（高度セレクターの押しで消す上昇の制限の終わり、§63）を、上昇の脚のうち点のある最後の脚の点にした。点が無ければ上昇の制限は無し。上昇の脚が点の無い脚（経路の不連続や vector）で終わると、前は点が nil になって、押しが経路の終わりまでの制限を上昇のものとして消していった（新しい決め方で SID の後の不連続が上昇の脚の最後になり、試験で見つかった）。
- 試験：
  - `vnav_model_test` 236 件：`clb_last` の 10 件（上昇・巡航・降下、T/C の前後、予測の前の半分、到着の脚で止まる、SID の無い経路）と、降下中の 20 NM 先の到着の AT 15,000 が経路に入ること（予測 15,000 ft。前の決め方では 16,946 ft）。
  - `pred_glue_test` 189 件：上昇の脚の期待を新しい決まりで出す（SID の脚と、予測の前なので経路の半分までの手続きの無い脚）。
  - `vnav_msgs_test` 30 件：DESCENT PATH DELETED の場面を巡航の FL350 で行う（上昇中の手続きの無い脚の制限は、T/C の前なら上昇のもの）。
  - 全 235 本（§152 の直しと合わせて回した）、構文。
- 推定：手続きの無い脚の線を前の予測の T/C にしたこと（予測は 10 秒ごとで、その間に動いた分は見ない）、予測の無い間の半分の線。
- X-Plane（カスタム acf、2026-11-08 15:34〜20:48、起動し直して読み込ませた。§152 の直しと同じ回：`tests/flight/runs/run_list_20261108_153955.txt`）：
  - 予測と E/D：`s185_vnav_wpts_clb` 13/13、`s186_vnav_wpts_des` 14/14、`s132_nd_profile` 10/10、`s133_nd_profile_des` 11/11、`s168_vnav_msgs` 13/13（上昇中に BOKJO に入れた 10000 は、前の予測の T/C より先なので降下の制限になって E/D になり、消すと DESCENT PATH DELETED）、`s221_offpath_des` 17/17。
  - §150 の VNAV の 21 本のうち 18 本（s137・s139・s140・s141・s143・s144・s145・s146・s149・s150・s156・s157・s169・s206・s251・s253・s266・s267）と `s147_vnav_spd_intervention` 30/30 は合格。
  - `s265_vnav_climb_conflicts` 21/22、`s264_vnav_alt_td_hold` 35/40、`s148_vnav_speed_reversion` 21/27 は、重さで落ちた。3 本とも重さを決めておらず、前のシナリオの重さを引き継いで今回は 270 t（§150 の確かめで合格した回は 310 t）。
    - s265：12,000 ft の上昇率が 3,857 fpm（310 t の回は 3,251）で、MCP を下にした後の行き過ぎが 1,832 ft（幅は 1,500 ft）。
    - s264：空中開始の機首上げで 31,160 ft まで上がり、VNAV PTH の巡航の戻りが約 −170 fpm で、FL300 に戻る前に T/D を過ぎた。T/D の時刻（VNAV の engage から約 7 分半）は 310 t の回と同じ。
    - s148：経路への捕捉の加速が遅く、354 kt を越える前に 240 kt への減速が始まって、速度の逆戻りが起きなかった。T/D を過ぎて MCP を下げた時の経路のずれ（9,675 ft）と FMC の V/S（−3,602 fpm）は、310 t の回（9,756 ft・−3,619 fpm）とほぼ同じで、経路は変わっていない（STAR と進入の制限はどれも 4,000 ft 以上で、上の降下の経路に効かない）。
    - 3 本に 310 t（ペイロード 40.0 t、燃料 86.5 t）を入れて回し直した（`tests/flight/runs/run_list_20261108_204845.txt`）：s265 22/22（警告 1 は前の回と同じ 60 秒後の昇降率。12,000 ft の上昇率 3,254 fpm、行き過ぎ 1,389 ft）、s264 39/40（不合格なし、警告 1。FL300 に 98 秒で戻った）、s148 27/27（21,861 ft・354 kt で速度の逆戻り）。
  - Lua の誤りなし（`Output/B747_xtlua_errors.txt` が出ない）。

## 152. FLCH の上昇の入りの速さの行き過ぎ：A/T の THR をエネルギーの率に（2026-11-07 に用意、2026-11-08 に入れた：利用者の「後で入れる」、性能計測のフェーズ2の後）

- 現象（`s108_afds_flch`、`tests/flight/runs/20261107_030240`）：270 t・10,000 ft・250 kt の水平（押した時は −192 fpm）から FLCH で 15,000 ft へ。A/T の THR がレバーを 0.52 から 0.90 へ 20 秒で進め（推力は 1 発 33 kN から 122 kN）、ピッチの速度の則は 0.1 g（1.09〜1.11 g）の速さの制限に 20 秒張り付いて 4.4° から 11.4° へ。速さは 23〜26 秒で最大 261.8 kt（+11.8 kt）、昇降率は 34 秒で 4,150 fpm まで行き、250 kt に戻るのは 55 秒。推力は 20 秒（昇降率が 125 秒の率 2,350 fpm に届いた時）で止まり、上昇中は戻さないので 122 kN のまま。同じ回の 15,000 ft から 9,000 ft への降下の入りは、レバーが 8 秒でアイドルに届いて HOLD、速さは 19 秒で −5 kt、50 秒で戻った。上昇中の 250→280 kt は 36 秒で 277 kt に届き、行き過ぎなし。
- 資料：
  - ATA34_2 p.646：A/T の制御は速さ・昇降率・推力の 3 つ。昇降率の制御則は FLCH の昇降率（と G/A の 2,000 fpm）に対して推力を計算し、昇降率が足りなければ推力を増し、上回っていても減らさない。
  - ATA34_2 p.670：FLCH では MCP 高度との差から 125 秒で届く昇降率を計算し、それを出す推力を指令する。推力は推力制限のモードまで。アイドルの後ろの止まりで 8° ずれると HOLD。
  - ATA34_2 p.647：FLCH は昇降率の制御部に 125 秒で MCP 高度を捕捉する昇降率を指令させる。
  - ATA22 p.284・p.344：FLCH ではスロットルが上昇・降下を作り、A/P が MCP の速さを昇降舵で保つ。速さの基準と ADC の速さの差が昇降舵への指令。
  - FCOM p.646（4.10.8）：A/T は THR、降下では HOLD。要求した高度差に比例した昇降率を保つよう推力を進める・戻す。FCTM p.65（1.35）：FLCH は小さい高度差では浅い上昇・降下をする。
  - 入りの速さの行き過ぎの目安は資料に無い。
- 分析：
  - 2,350 fpm の上昇に要る推力は、250 kt・270 t で水平の 33 kN より 1 発約 63 kN 多い約 96 kN。A/T は慣性の昇降率だけを見て、ピッチの引き起こし（0.1 g で 7.7° に 20 秒）に昇降率が遅れる間も進め続け、122 kN まで行った。余った推力がまず速さ（+12 kt）に、次に昇降率（4,150 fpm）になる。
  - 速度の則の g の制限を 0.15 に上げても（模型で +21→+13.5 kt）、推力の変化をピッチへ先回りして渡しても（+15）、レバーの速さを半分にしても（+7 だが入りが遅い）、根本は A/T が要る推力を越えること。
  - A/T の昇降率を「目標の速さでのエネルギーの率」（慣性の昇降率に、速さが得ている運動エネルギーの率を足したもの：VNAV の THR と G/A が既に使う `evs`、§60）にすると、昇降舵が余った速さを上昇に変える分を先に数えるので、推力は 125 秒の率に見合う所で止まる。模型（`tests/autopilot/flch_entry_test.lua`：A/T の THR と速度の則を、レバーに 3 秒遅れるエンジン（レバー 1 単位で 222 kN、記録から）と、指令に 2 秒・姿勢に 3 秒遅れる機体で閉じたもの）：慣性の昇降率だけでは +16〜21 kt・推力は制限まで・昇降率 3,080 fpm、エネルギーの率では +9 kt・1 発 88〜92 kN・昇降率 2,400 fpm。模型は X-Plane より遅れが大きい（今の則で +21 に対し X-Plane は +12）ので、X-Plane では +5 kt 前後と見込む。
  - ただし速さが目標より下の時（上昇中に 250→340 kt を選んだ時など）は、加速はピッチの則が望むもので、推力は制限まで進めるべき（p.670・p.646。模型で 250→340 kt は制限まで進み 340 kt に行き過ぎなし）。だからエネルギーの率は、速さが目標以上の時に全部、目標より 5 kt 下で 0（間は比例）とした。降下は慣性の昇降率のまま（アイドルへ戻して HOLD：エネルギーの率では戻しが 3 割遅い）。
- 直したこと（`B747.70.at_model.lua` の `servo`、THR の枝）：FLCH の上昇で、昇降率の誤差に使う昇降率を `vs + w·(evs − vs)`、w = clamp((IAS − 目標) ÷ 5 kt + 1, 0, 1)（`FLCH_EVS_KT`）。VNAV の THR と G/A は前のまま evs、FLCH の降下は vs。glue は変えない（`evs` は毎フレーム渡している：§60）。推定：エネルギーの率を使うこと、5 kt の幅。
  - VNAV SPD の上昇は THR REF（制限の推力）で、この枝を通らない。影響なし。
- 試験：`at_model_test` に 7 件（目標の速さで 1,000 fpm のエネルギーの余り：その率で、前の則では昇降率のまま；10 kt 遅い：昇降率だけ；2.5 kt 遅い：半分；5 kt 速くエネルギーの率が目標を超える：推力を増さない；上昇率が目標を超えていても減速中なら増す（p.646 の「減らさない」）；evs が無ければ昇降率；降下は昇降率だけ）。新しい `flch_entry_test`（19 件：上の模型。0 fpm と −192 fpm からの入りが +10 kt 以内・推力 100 kN 未満・昇降率 2,400±400 fpm・0.1 g 以内・90 秒で 250 kt；250→340 kt は制限まで進み行き過ぎ 3 kt 以内；降下は HOLD・−6/+3 kt）。前のコードでは `at_model_test` の 4 件と `flch_entry_test` の 6 件が落ちる。全 235 本（§151 の直しと合わせて）、構文 565 本が通る。
- X-Plane（カスタム acf、2026-11-08 15:34〜、起動し直して読み込ませた。§151 の直しと同じ回）：
  - `s108_afds_flch` 24/24（`20261108_155342`）：10,127 ft・250 kt（−195 fpm）から FLCH で 15,000 ft へ。推力は 20 秒で 1 発 93 kN、30 秒で 95 kN で止まった（前の 08:57 の回は 22 秒で 124 kN）。速さの行き過ぎは 20 秒で +7.1 kt（前は 24 秒で +12.5 kt）、昇降率は 30 秒で 2,637 fpm、60 秒で 2,430 fpm（前は 33 秒で 4,284 fpm）。降下の入り（15,000 ft から 9,000 ft、280 kt）は前と同じで、20 秒で −3.9 kt（前は −4.6 kt）。
  - 新しい `s268_flch_climb_accel` 13/13：10,123 ft・250 kt から MCP 340 kt・FL350 で FLCH。推力は 10 秒で 1 発 131 kN（CLB）まで進み、90 秒で 339.7 kt に行き過ぎなく届いた。速さが目標より 5 kt 以上遅い間はエネルギーの率を使わないので、推力の進め方は前と同じ。性能計測の上昇も、窓を 340 kt にしてから FLCH を押す（`tests/flight/perf/perf.ps1` の上昇）ので同じで、測り直しは要らない。上限高度の上昇（M.85 のまま MCP 45,000 ft）も、125 秒の率に届かず推力は制限のまま。
  - 新しい `s269_flch_descent_m84`：1 回目（`20261108_154538`）15/16。306 t・FL350・M.84 から FLCH で FL250 へ。10 秒でアイドルの HOLD、入りの 40 秒の Mach は M.829〜.841、その後は目標の CAS の −3〜−1 kt。31,381 ft で目標の CAS が 310 kt に届いて窓が IAS の 310 kt になり（FCOM p.643 (4.10.4)、notes/ATA-22.md §54）、その後の CAS 一定の降下で Mach が .822 まで下がって、60 秒の Mach ±.01 に入らなかった（シナリオの期待の誤り）。Mach を見るのを切り替えの前の 15 秒にし、切り替えの後は窓（306〜316 kt）と IAS 310 kt ±5 kt を見るように直した。2 回目（`20261108_204846`）18/19：入りの 40 秒は M.829〜.841、その後の 15 秒は M.835〜.839、窓が IAS になった後の 30 秒の IAS は 310.2〜312.6 kt。窓の値は、切り替えの直後（0.05 秒後）に見て 84 のままだった（窓の値は単位が変わった 0.25 秒後に入る：notes/ATA-22.md §54）ので、1 秒待ってから見るようにした。3 回目（`20261108_212807`）19/19（窓は 310 kt、その後の 30 秒の IAS は 310.2〜312.5 kt）。
  - 回帰：`s270_flch_mach_climb_descent` 16/16（上昇 M.839〜.841、降下 M.836〜.839：前と同じ）、`s107_afds_vs_alt` 20/20、`s104_afds_ga` 34/34、`s214_epr_climb` 10/10、`s10_overspeed` 22/22、`s07_cruise_ff` 7/7。VNAV の上昇・THR と G/A は §151 と同じ回で、`s139_vnav_climb_crz` 28/28、`s146_vnav_des_now` 30/30、`s157_eo_driftdown` 34/34、`s150_vnav_missed_approach` 34/34。Lua の誤りなし。
- 残り：
  - 入りの残りの行き過ぎは X-Plane で +7 kt（模型の +9 kt より小さく、見込みの +5 kt より大きい）。ピッチの速度の則の 0.1 g の制限と遅れによる。直すなら推力の変化の先回り（模型で 2 kt 分）か g の制限の見直しで、資料に目安が無いので後で決める。
  - 上昇中に高い速さを選んだ時の推力は前のまま制限まで（X-Plane で 340 kt に行き過ぎなし）。

## 153. LNAV の fly-by の旋回の出口の先読み（2026-11-09：性能計測の KSEA-KLAX の全自動の飛行で利用者が見た「旋回時の修正の逆バンク」）

- 見つかったこと（記録 `tests/flight/perf/runs/20261108_215651_autoflight`）：fly-by の旋回のたびに、逆のバンクが 5〜12° 入った。BURGL の左 17° では、25° のバンクを戻し始めたのが新しい脚に乗った所（脚から 0.03 NM）で、毎秒 3° で戻す間に針路を 6.4° 行き過ぎ、脚の内側へ 0.14 NM 出て、右 12° で戻した。
- 原因：`B747.68.lnav_model.lua` は旋回の入りを ROLL_LEAD（4 秒）早く始めるが、出口は弧の終わり（`at >= 0`）まで弧のバンクを保ち、そこで指令のバンクが一気に 0 になった。AFDS の指令の速さ（毎秒 3°：`B747.70.afds_roll_model.lua` の ROLL_RATE、推定）で戻す約 8 秒の間に 4〜6° 回り過ぎる。
- 直したこと：弧のバンクから戻すのにかかる時間の半分（|弧のバンク| ÷（2 × ROLL_RATE）、25° で約 4.2 秒）だけ弧の終わりの手前で、次の脚の誘導に移る（M.ROLL_RATE = 3）。推定：資料は旋回の形（ATA34_2 p.615、p.626）だけで、誘導の先読みは書かない。
- 試験：`lnav_model_test`（17° の旋回を 490 kt で、60° を 300 kt で：逆のバンク 2° 未満、脚の内側へ 0.05 NM 未満。4 件）。模擬（`tests/lib/lnav_sim.lua`）で、逆のバンク 10〜15° → 0.1〜0.3°、内側へのはみ出し 0.09〜0.11 → 0.007〜0.022 NM（8°・17°・30°・60°・90° の旋回、風 0・30 kt）。
- X-Plane（カスタム acf、2026-11-09）：新しい `s271_vnav_irnmn2`（§155：235 t、FL370・M.858）で、BURGL の左 17° の旋回（バンク最大 24.8°）の後に右へ戻すバンクは最大 0.66°（前の飛行は 11〜12°）。脚の外側へ最大 0.084 NM 出て、ゆっくり 0.01 NM へ戻った（前は内側へ 0.14 NM。針路の行き過ぎは約 1°）。模擬の見込み（0.007〜0.022 NM）より大きいのは、X-Plane の旋回の入りと出の遅れ（推定）。DOUIT の左 6°（バンク最大 17.4°）は 0.25° と 0.031 NM。`s91_lnav_sid` 29/29（SID の 123° の旋回は前の回と同じ −0.17 NM：コースの捕捉で、fly-by の旋回ではない）。

## 154. 手続きのコースを、その脚の推奨の航法援助施設の偏差で真方位に（2026-11-09：同じ飛行で利用者が見た「ND のマゼンタの線が点の端から出る」）

- 見つかったこと（利用者）：最終進入に入る所で、滑走路の延長の破線と進入の点に重なるはずのマゼンタの線だけが、点の端から出て次の点の真ん中に入り、またその点の端から出た。
- 原因（コードと航法データ）：KLAX の ILS24R の最終の脚（MERCE → KOBEE → RW24R）は、磁方位 251° で点に入る CF の脚（推奨の航法援助施設は IOSS）。`B747.68.path_model.lua` の true_of は、すべての磁方位を点のいちばん近い VOR の偏差（`B747_navdb.variation`：ここでは LAX VORTAC の 15° E）で真方位にした。IOSS の偏差は 11.97° E（earth_nav.dat の LOC の欄：磁 251°・真 262.97°）。CF の脚は「前の点の横から、そのコースで点に入る線」なので、線が 3° 回って前の点の脇（MERCE で 0.407 NM、KOBEE で 0.336 NM：実際のデータで）から出た。LNAV もこのコースを飛ぶ（LOC を捕まえる前）。
- 直したこと：手続きのコース（CF、コースの脚、点からのコースの脚、DME arc の始まりの radial、ホールドの入航コース、procedure turn）と radial は、その脚の推奨の航法援助施設の偏差で真方位にする：LOC は航法データの真と磁のコースの差（XP 1200 の形。古い形は真だけなので使わない）、VOR は局の偏差。無いとき（NDB など）は前のとおり、いちばん近い VOR の偏差。ヘディングは前のとおり、その場の偏差（機体の磁方位の基準）。推定：資料は REF NAV DATA の MAG VAR が航法援助施設のもの、とだけ書く（FCOM p.1304、ATA34_2 p.547）。LEGS の画面のコースは前からデータの磁方位のまま。
- 試験：`path_model_test`（LOC・VOR・無し・古い形の LOC・ヘディング：6 件）。実際の KLAX のデータ（Custom Data）で、線は 262.97°、MERCE から 0.010 NM、KOBEE から 0.000 NM。
- X-Plane（カスタム acf、2026-11-09）：新しい `s272_nd_klax_final`（KSEA-KLAX の計画に APP I24R を足した `tests/flight/data/simbrief/KLAXI24R.fms` を RTE REQUEST で受け、MERCE の手前の 4,000 ft・235 t から MERCE へ DIRECT TO、LNAV）で 15/15。機長の ND（MAP 20 NM・10 NM）の写真で、マゼンタの線は MERCE と KOBEE の記号の真ん中を通る 1 本の直線で、24R の滑走路の延長に重なる。LNAV で MERCE から KOBEE の 1.9 NM 手前まで CF の脚を飛ぶ間、LOC（IOSS 108.50、同調と電波あり）の偏位は 0.029〜0.071 ドット（前の 3° 回ったコースなら KOBEE で約 0.4 NM、2 ドット近く外れる）。`s91_lnav_sid` 29/29（SID のコースの脚と radial は、そこの VOR の偏差が前の「いちばん近い VOR」と同じ）。
