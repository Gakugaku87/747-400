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
- 残り：TRANS LVL を到着の手続きから取ること（今は目的地の空港の値）、ほかのページ（LEGS の降下の予測など）の FL と ft の切り替えに TRANS LVL を使うこと（今は TRANS ALT のまま）、OFFPATH DES と DES DIR（VNAV の段 9 以降）、TAI/ON ALT を降下の経路に使うこと（8e3、資料に値があれば）。
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
