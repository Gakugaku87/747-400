# 資料索引（REFERENCE_INDEX）

資料の PDF は `_ref/` にある。`_ref/` は `.git/info/exclude` で git の管理から外してあり、どのブランチにもコミットしない。

## 使い方

- このファイルのページ番号は、すべて **PDF のページ番号**（1 始まり）。資料自身のページ番号（FCOM の `6.20.3`、整備訓練マニュアルの `ATA 24-20 Page 5` など）とは別物。
- テキストは `_ref/text/` にある（xpdf の `pdftotext -layout` で抽出）。
  - `_ref/text/<ID>.txt`：全ページを1ファイルにしたもの。各ページの前に `==== [<ID> p.N] ====` の行が入る。
  - `_ref/text/<ID>/pNNNN.txt`：1ページ1ファイル（`p0123.txt` が PDF の p.123）。
  - `_ref/text/<ID>.pages.tsv`：ページ番号、空白以外の文字数、先頭行、末尾行。
  - `_ref/text/SOURCES.tsv`：ID と PDF ファイル名の対応。
- 検索するとき：`_ref/` は git の管理外なので、Grep ツールではパスを必ず明示する（例：`path: "_ref/text/FCOM"`）。
- 文字数が 400 未満のページは、図が本体であることが多い。整備訓練マニュアルは「左ページが図、右ページが本文」の見開き構成で、ページの約半分がこれにあたる。図は Read ツールで PDF を `pages` 指定して画像として読む（1回 20 ページまで）。
- 引用の書き方（notes/、GAP_ANALYSIS.md、コミットメッセージで共通）：`ID p.<PDFページ>`。資料自身の番号があれば括弧で添える。
  - 例：`FCOM p.801 (6.20.7)`、`ATA22 p.212 (22-10)`、`LH24 p.95 (24-20)`、`FCTM p.160 (5.4)`、`FMSPG p.100 (3.2-40)`

## 資料一覧

| ID | 資料 | ページ数 | 図が主のページ (<400字) | 型式・版 |
|---|---|---|---|---|
| FCOM | Boeing 747-400 Flight Crew Operations Manual（D6-30151-400） | 1606 | 240 | Rev. 23（2009-10-01）。性能（PI 章）は PW4056 と CF6-80C2B1F（747-400F）を収録 |
| FCTM | Boeing 747-400 Flight Crew Training Manual | 318 | 24 | 2006-10-31 版。エンジン型式によらない。FCOM と食い違えば FCOM を優先 |
| FMSPG | Honeywell B747-400 FANS FMS Pilot's Guide | 415 | 34 | ©1996。FMC/CDU の操作と画面 |
| LH24 | Lufthansa Technical Training B1：ATA 24 Electrical Power（B747-4 PW 24 B1 E） | 256 | 133 | PW 機、2003 年 |
| LH36 | Lufthansa Technical Training B1：ATA 36 Pneumatic（B747-4 PW 36 B1 E） | 138 | 31 | PW 機、2005 年。主翼防氷・氷検知（ATA 30）も一部含む |
| LH3460 | Lufthansa Technical Training B1：ATA 34-60 FMCS（B747-4 34-60 B1 E） | 136 | 79 | 2001〜2005 年 |
| ATA21 | E&M 整備訓練マニュアル：ATA 21 Environmental Control | 616 | 354 | Config: ALL |
| ATA22 | 同：ATA 22 Autopilot/Flight Director System | 408 | 233 | autothrottle（推力管理）は ATA 34-61（ATA34_2・LH3460）にある |
| ATA23 | 同：ATA 23 Communication | 702 | 415 | 大半は客室系（PA、IFE、PSS） |
| ATA26_28 | 同：ATA 26 Fire Protection ＋ ATA 28 Fuel | 566 | 324 | |
| ATA27 | 同：ATA 27 Flight Controls | 748 | 401 | |
| ATA29_32 | 同：ATA 29 Hydraulics ＋ ATA 32 Landing Gear | 674 | 377 | |
| ATA30_32_35_36 | 同：ATA 36 Pneumatic ＋ ATA 30 Ice and Rain ＋ ATA 35 Oxygen | 386 | 229 | ファイル名に 32 とあるが、ATA 32 の内容は無い |
| ATA31 | 同：ATA 31 Indicating/Recording | 564 | 348 | EFIS/EICAS（IDS）、aural warning、FDR、ACMS、W&B |
| ATA33 | 同：ATA 33 Lights | 362 | 206 | |
| ATA34_1 | 同：ATA 34 Navigation（1）：air data、無線航法、気象レーダー、ATC | 646 | 372 | 先頭に ATA 20-11 Digital Systems |
| ATA34_2 | 同：ATA 34 Navigation（2）：TCAS、RA、GPWS、IRS、GPS、FMCS | 736 | 410 | FMCS（34-61）が 310 ページある |
| ATA38_51_52_56 | 同：ATA 38 Water/Waste、51 Structures、52 Doors、56 Windows | 614 | 327 | |
| ATA70_80 | 同：ATA 71〜80 Powerplant | 576 | 298 | CF6-80C2 |
| QRH_CA | 中国国際航空 B747-400 QRH（2008-10-01、中国語と英語。2026-11-02 に利用者がくれた） | 444 | 180 | PW4056、重量はポンド。非常・非正規のチェックリスト、空中性能（PI-QRH 章：p.347 の目次、VREF は p.353 の PI-QRH.10.5、正常・非正規形態の着陸距離 p.355〜、一発不作動 p.363〜）。離陸速度の表は無い |
| ACAP | Boeing 747-400 Airplane Characteristics for Airport Planning（D6-58326-1 Rev F、2024-12。2026-11-02 に利用者がくれた） | 224 | 157 | 寸法、重量（MTW・MLW など）、離陸・着陸の滑走路長の図（3.3 節〜、エンジン型式ごと）、旋回半径。V 速度は無い |
| ICAO_EEDB | ICAO Aircraft Engine Emissions Databank のデータシート（`_ref/ICAO_EEDB/`、1 エンジン 1 枚、テキストは `_ref/text/ICAO_EEDB/`。2026-10-30 に利用者が置いた） | 20 枚 | — | PW4056（1PW041・1PW042）、PW4062、CF6-80C2B1F（1GE023・1GE024・2GE045 ほか）、CF6-80C2B5F、RB211-524G・H（-T を含む）。定格推力 F00・バイパス比・全体圧力比、海面静止の LTO の 4 つの推力（100・85・30・7 %）の燃料流量。引用は `ICAO_EEDB 1PW041` の形 |
| FPPM | Boeing 747-400F Flight Planning and Performance Manual（D632U002-RZ043 Rev 7、2011-03-04。2026-11-14 に利用者がくれた。PDF のファイル名は `1059530115-74F-FPPM.pdf`） | 198 | — | 747-400F/PW4056、FAA、kg、Category J ブレーキ、減推力 TO1 8 %・TO2 20 %。出発前の離陸・着陸の性能（滑走路長・上昇・障害物・タイヤ速度・ブレーキエネルギーの制限、V1・VR・V2、離陸 EPR、トリム、湿った・汚染滑走路、着陸の制限と距離）、飛行計画、巡航（LRC・.85M の表と最大巡航 EPR、上昇の表）。図は画像でなく線のデータ（座標を読める） |

2026-11-19 に利用者が置いた 27 点（PDF 26、Word 1。テキストにしたのは同じ日の夜：`extract_pdfs.sh`、Word は `docx_to_text.ps1`。中身と読んだ結果は下の「2026-11-19 の資料」）：

| ID | 資料 | ページ数 | 図が主のページ (<400字) | 型式・版 |
|---|---|---|---|---|
| TCDS_747 | FAA 型式証明データシート A20WE（Boeing 747）Revision 58（2016-10-05。`A20WE.pdf`） | 75 | 0 | 全型式。-400・-400D・-400F・-400SF（BCF）・LCF の欄。**Datum・MAC・LEMAC**、VMO/MMO、最大高度、推力の表、EICAS メッセージの種類（Note 12・13） |
| TCDS_747_R64 | 同 Revision 64（2025-08-08。`A20WE_Rev64.pdf`） | 77 | 0 | R58 より新しい。-400 の数値は同じ（違いは ESF・特別条件・機番）。テキストは欄ずれがある：R58 か絵で読む |
| TCDS_PW4000 | FAA TCDS E24NE Rev 14（2024-06-25、PW4000-94） | 6 | 0 | PW4056 の定格・回転数・温度・圧力の限界（p.3）、離陸 10 分（Note 21） |
| TCDS_CF6 | FAA TCDS E13NE Rev 27（2024-08-06、CF6-80A/-80C2） | 21 | 0 | CF6-80C2B1F の限界（p.10–11）、最小空中アイドル（p.15） |
| TCDS_CF6_EASA | EASA TCDS IM.E.240 Issue 02（2024-07-23、CF6-80） | 27 | 1 | 運用限界 p.15–17、flat rating p.20–21 |
| TCDS_RB211 | EASA TCDS E.062 Issue 03（2019-02-21、RB211-524・-22B） | 25 | 1 | **RR の初めての資料**：定格、TGT・回転数（LP・IP・HP、逆推力の LP 91 %・40 秒）・油の限界。EPR の値は無い |
| NASA_SIM | Boeing D6-30643 Vol. II「The Simulation of a Jumbo Jet Transport Aircraft, Vol. II: Modeling Data」（NASA CR-114494、Hanke・Nordwall、1970-09） | 636 | 380 | **747-100（JT9D-3）**の空力・操縦系統・推進・脚・A/P（SPZ-1）・ヨーダンパー・AFM の模型データ。-400 にそのまま使えない値は「-100 の値」と書く |
| NASA_HQ | NASA CR-2144「Aircraft Handling Qualities Data」（Heffley・Jewell、1972-12） | 351 | 233 | 10 機のうち 747（-100）は p.216–248（D6-30643 からの二次資料）。**PDF ＝本のページ＋6** |
| VT_SPECS | Virginia Tech AOE 4124 の学生の発表（2007 春、747-100 の諸元と翼型） | 19 | 17 | 信頼性は低い。参考だけ |
| APU_MTM | Airbus の整備訓練資料（A320 系 M35、2006-05）の 49 APU のうち **APS 3200** の部分 | 74 | 40 | **747 の資料ではない**（747-400 の APU は PW901A：AC_SPECS p.1）。数値は使わない |
| AC_SPECS | Aircraft Commerce Issue 51（2007 年 4・5 月）の 747-400 の仕様 | 3 | 0 | 二次資料。型式ごとの重量の選択肢、燃料、APU の型式 |
| CMCS | Scribd の Word 文書「ATA45 NEW CMCS」（`12_Scribd_ATA45_NEW_CMCS.docx`、7 ページはテキストの区切り） | 7 | — | **787 の資料**。索引だけ |
| LH_MAN | Lufthansa Technical Training「Training Manual B747-400 ATA 00 Maintenance Documents」（Book E、2008-10 / 本文 07.2003） | 120 | 76 | 整備文書の使い方と、FIM・CMCS で故障を切り分ける手順。**CDU の CMC 画面の実例**、STATUS のラッチ（NVM）。PDF ＝資料＋2 |
| OMS | 教科書の 10 章「On Board Maintenance Systems (ATA 45)」 | 17 | 1 | 機種によらない一般論（例は A330・777）。747-400 の根拠にしない |
| COMM | IAI「Supplement to 747-400 System Schematic Manual」23 章（RT633・RT634、2008-10-30） | 12 | 10 | 改造貨物機の配線図（ACARS、PA、interphone、地上員と上部デッキの呼出、AMU） |
| CPDLC | Honeywell「CPDLC Procedures」Final Report Rev.2（FAA DTFAWA-10-A-80031、2011-08-31、ROSAP） | 217 | 13 | 研究報告。本文の「B744」の画面は Mark II CMU（LINK2000+）で FANS の FMC ではない。**付録 G が 747-400 の FMS の LOAD の規則**、付録 F が応答の属性（SC-214）。PDF ＝資料＋1 |
| PW_PPM | KLM E&M「B747-400 Power Plant PW4000」訓練教材（Rev 2015-03、AMM Rev 82） | 636 | 374 | PW4056 の仕様・限界、EEC（TRA の角度、ALTN、制限保護、アイドルの選択、トリム）、燃料・油・点火・表示・始動、ATA 78 逆推力。見開き（偶数が本文）。2 段組のテキストが混ざる・画像だけの本文のページがある |
| MMEL | FAA MMEL Boeing 747（-400/-400D/-400F）Rev 32（2018-12-27） | 278 | 1 | 故障したまま出発してよい条件。系統の冗長と依存の手がかり。テキストは 4 列が行の中で混ざる |
| EICAS_WS | Atlas Air の訓練スライド「747-400 Warning Systems – Part 1」（2000-07-07） | 57 | 57 | **全ページが画像**。並び・CANC/RCL・音・抑止。747-400F 向けと見られる |
| AOM_JP | 航空機運用規程 15-18 WARNING SYSTEMS（日本語、会社・版の記載なし、旅客機、FCOM より古い版と推定） | 34 | 34 | **PDF は 34 ページ**（テキストの 38 は文字層の化け）：全ページ絵で読む。離陸形態警報は「エンジン 2・3 のスラストレバーが離陸範囲」（p.10）、メッセージ一覧 p.27–34 |
| CB_BA | British Airways の B747-400 の CB 位置表（ATP 2225 Issue 19、RR 機） | 12 | 1 | CB 名・パネル・番地だけで母線名は無い。右の段のテキストが行ずれ：絵で読む |
| HYD_SCH | 747-400 の油圧系統の略図（個人、"Tony Pike 10/05"） | 1 | 0 | 非公式。ATA-29 §2.4 と全部一致 |
| ARINC424 | ARINC Specification 424-17「Navigation System Data Base」（2004-08-31） | 409 | 102 | 航法データの書き方（手続き・滑走路のレコードの欄、path terminator）。**PDF ＝資料＋15** |
| ICAO_NDB | ENAC・ICAO の講義スライド「Navigation Database Coding」（2016 年以降） | 41 | 37 | ARINC 424 の考え方と脚の図 |
| NTSB_WBM | NTSB DCA13MA081 Structures 付属 1：Telair の WBM 25-55-66 Rev. L（2009-02-10）の抜粋（747-400SF＝BCF） | 80 | 5 | 貨物の積み付けと固縛。B.A.、下部貨物室の arm、主甲板の区画の上限。MAC・重心の範囲・トリムは無い |
| NTSB_STR | 同じ調査の Structures Group Factual Report（2015-01-30） | 72 | 28 | **B.A. の原点（機首の 90 in 前、STA と同じ値：p.9）** |
| WBM_SUP | FAA InFO 15010（2015-08-31）：747・767・777 の貨物機の WBM 追補 | 2 | 0 | WBM の文書番号（747-400BCF D043U544、747-400F D043U542） |

- APU（ATA 49）の整備資料は無い。APU は FCOM 7.14・7.30・7.40 を基準にする（2026-11-19 の APU_MTM は A320 の APS 3200 で、747 の APU（PW901A）ではない）。
- 電源（ATA 24）は LH24 だけ（PW 機）。整備訓練マニュアルには ATA 24 の巻が無い。
- 資料にない ATA 章：24（LH24 で代替）、25、45（CMC。画面と使い方は LH_MAN、系統の説明書は無い。CMCS は 787）、46、49。

## FCOM（D6-30151-400）

| 章 | 節 | 内容 | PDF p. |
|---|---|---|---|
| 0 Preface | 0.1 / 0.2 / 0.3 / 0.4 / 0.5 / 0.6 | Model Identification / Introduction / Abbreviations / Revision Record / List of Effective Pages / Bulletin Record | 5-6 / 7-14 / 15-20 / 21-34 / 35-42 / 43-74 |
| L Limitations | L.10 | Operating Limitations | 75-84 |
| NP Normal Procedures | NP.11 / NP.21 | Introduction / Amplified Procedures | 87-94 / 95-154 |
| SP Supplementary Procedures | SP.05 | Introduction | 159-160 |
| | SP.1 / SP.2 / SP.4 / SP.5 | Airplane General / Air Systems / Automatic Flight / Communications | 161-166 / 167-170 / 171-176 / 177-178 |
| | SP.6 / SP.7 / SP.8 / SP.10 | Electrical / Engines, APU / Fire Protection / Flight Instruments, Displays | 179-182 / 183-186 / 187-188 / 189-190 |
| | SP.11 / SP.12 / SP.16 | Flight Management, Navigation / Fuel / Adverse Weather | 191-198 / 199-200 / 201-220 |
| PI Performance Inflight（747-400/PW4056） | PI.10〜PI.18 | General、All Engines、Advisory、One/Two Engines Inop、Alternate Mode EEC、Gear Down、Text | 223-324 |
| PI Performance Inflight（747-400F/CF6-80C2B1F） | PI.20〜PI.27 | 同上（Alternate Mode EEC の節は無い） | 325-412 |
| 1 Airplane General, Emergency Equipment, Doors, Windows | 1.10 | Dimensions | 419-422 |
| | 1.20〜1.23 | Flight Deck Panels（overhead、forward、control stand、aisle stand） | 423-434 |
| | 1.30 | Controls and Indicators（照明、非常灯、酸素、避難、ELT、ドア） | 435-498 |
| | 1.40 / 1.45 / 1.50 | Systems Description（照明・酸素など / 非常装備 / ドア・窓） | 499-514 / 515-526 / 527-544 |
| | 1.60 | EICAS Messages | 545-548 |
| 2 Air Systems | 2.10 | Controls and Indicators | 553-586 |
| | 2.20 / 2.30 / 2.40 | Air Conditioning / Pressurization / Bleed Air System Description | 587-606 / 607-610 / 611-618 |
| | 2.50 | EICAS Messages | 619-622 |
| 3 Anti-Ice, Rain | 3.10 / 3.20 / 3.30 | Controls and Indicators / System Description / EICAS Messages | 625-630 / 631-634 / 635-636 |
| 4 Automatic Flight | 4.10 / 4.20 / 4.30 | Controls and Indicators / System Description / EICAS Messages | 639-658 / 659-676 / 677-678 |
| 5 Communications | 5.10 / 5.20 / 5.30 | Controls and Indicators / System Description / Interphone | 683-712 / 713-718 / 719-724 |
| | 5.33 / 5.34 / 5.40 | ATC Datalink / Company Datalink / EICAS Messages | 725-770 / 771-774 / 775-776 |
| 6 Electrical | 6.10 / 6.20 / 6.30 | Controls and Indicators / System Description / EICAS Messages | 779-794 / 795-820 / 821-824 |
| 7 Engines, APU | 7.10 / 7.11 / 7.12 | Primary / Secondary / Compact Engine Indications | 829-840 / 841-854 / 855-858 |
| | 7.13 / 7.14 | Engine Controls / APU Controls and Indications | 859-866 / 867-870 |
| | 7.20 / 7.30 / 7.40 | Engine System Description / APU System Description / EICAS Messages | 871-894 / 895-898 / 899-902 |
| 8 Fire Protection | 8.10 / 8.20 / 8.30 | Controls and Indicators / System Description / EICAS Messages | 905-912 / 913-920 / 921-924 |
| 9 Flight Controls | 9.10 / 9.20 / 9.30 | Controls and Indicators / System Description / EICAS Messages | 927-940 / 941-956 / 957-958 |
| 10 Flight Instruments, Displays | 10.10 | Controls and Indicators | 963-1068 |
| | 10.20 / 10.30 / 10.40 | System Description / PFD / ND | 1069-1080 / 1081-1108 / 1109-1158 |
| | 10.45 / 10.50 | EFB / EICAS Messages | 1159-1196 / 1197-1200 |
| 11 Flight Management, Navigation | 11.10 / 11.20 | Controls and Indicators / Navigation Systems Description（IRS、GPS、無線航法） | 1207-1224 / 1225-1232 |
| | 11.30 / 11.31 / 11.32 | FMS Introduction / FMS Operation / FMC（データベース、thrust management） | 1233-1234 / 1235-1270 / 1271-1276 |
| | 11.40 / 11.41 / 11.42 / 11.43 | FMC Preflight / Takeoff and Climb / Cruise / Descent and Approach | 1277-1324 / 1325-1344 / 1345-1388 / 1389-1420 |
| | 11.50 / 11.60 | FMS Alternate Navigation / EICAS Messages | 1421-1428 / 1429-1436 |
| 12 Fuel | 12.10 / 12.20 / 12.30 | Controls and Indicators / System Description / EICAS Messages | 1439-1452 / 1453-1472 / 1473-1480 |
| 13 Hydraulics | 13.10 / 13.20 / 13.30 | Controls and Indicators / System Description / EICAS Messages | 1483-1488 / 1489-1494 / 1495-1496 |
| 14 Landing Gear | 14.10 / 14.20 / 14.30 | Controls and Indicators / System Description / EICAS Messages | 1499-1510 / 1511-1520 / 1521-1522 |
| 15 Warning Systems | 15.10 / 15.20 / 15.30 | Controls and Indicators / System Description（EICAS、aural、GPWS、TCAS など） / EICAS Messages | 1527-1546 / 1547-1602 / 1603-1606 |

- 各章の先頭ページ（目次）は表の範囲の直前にある（例：6 Electrical の目次は p.777-778）。
- この FCOM には非常操作のチェックリスト（QRH / NNC）は入っていない。

## FCTM

| 章 | 内容 | PDF p. |
|---|---|---|
| 前付け | Preface、目次、改訂記録 | 1-27 |
| 1 | General Information（AFDS・FMC の使い方の原則など） | 28-71 |
| 2 | Ground Operations | 72-87 |
| 3 | Takeoff and Initial Climb | 88-120 |
| 4 | Climb, Cruise, Descent and Holding | 121-143 |
| 5 | Approach and Missed Approach | 144-211 |
| 6 | Landing | 212-247 |
| 7 | Maneuvers | 248-275 |
| 8 | Non-Normal Operations | 276-318 |

## FMSPG（Honeywell FANS FMS Pilot's Guide）

| 節 | 内容 | PDF p. |
|---|---|---|
| 前付け | 目次 | 1-11 |
| 1 | Pilot Overview | 12-14 |
| 2 | Flight Management（概要、構成、インターフェース、飛行段階、機能、データベース、MCDU） | 15-55 |
| 3.1 / 3.2 | Flight Data / Preflight（IDENT、POS INIT、RTE、PERF INIT、THRUST LIM、TAKEOFF REF など） | 57-60 / 61-109 |
| 3.3 / 3.4 | Takeoff/Climb / Cruise | 110-129 / 130-184 |
| 3.5 / 3.6 | Descent / Approach | 185-202 / 203-211 |
| 4 | Advanced Flight Planning（pilot-defined waypoints、conditional waypoints、holding、風） | 212-237 |
| 5 | Backup Functions（EFIS / EICAS control panel、standby navigation） | 238-254 |
| 6 | FMS-MCDU Messages | 255-260 |
| 7 | Additional Information（cost index、maintenance pages） | 261-269 |
| 8 | ATS Data Link（ADS、ATC index / uplink / request / report / emergency / log） | 270-366 |
| 9 | Company Data Link | 367-383 |
| App. A / B / C | Index / Abbreviations / List of Illustrations | 384-401 / 402-407 / 408-415 |

## FPPM（D632U002-RZ043、747-400F/PW4056）

| 章 | 節 | 内容 | PDF p. |
|---|---|---|---|
| 0 Preface | 0.1〜0.4 | Introduction、Revision Record、List of Effective Pages、Bulletin Record | 3-16 |
| 1 Takeoff and Landing | 1.1 | Text（離陸速度の決め方、減推力、assumed temperature、anti-skid 不作動、ブレーキ不作動、着陸の制限、ブレーキ冷却、CAT III） | 19-24 |
| | 1.2 | Takeoff：QNH と気圧高度、風、滑走路長の制限（フラップ 10・20）、上昇の制限、障害物、タイヤ速度、VMBE、improved climb、slush/standing water、slippery runway、離陸速度（p.41-42）、clearway・stopway、VMCG・VRMIN（p.43）、離陸 EPR・トリム・燃料投棄の時間（p.44）、燃料の分け方 | 25-46 |
| | 1.3 | Takeoff Derates：TO1（8 %）p.47-58、TO2（20 %）p.59-70（制限重量の換算、slush、slippery、離陸速度、VMCG・VRMIN、離陸 EPR・トリム） | 47-70 |
| | 1.4 | Landing：滑走路長と上昇の制限（フラップ 25・30、anti-skid 不作動も）p.71-74、復行の上昇勾配 p.75、quick turnaround p.76、ブレーキ冷却 p.77、着陸距離（フラップ 30・25）p.78-79 | 71-80 |
| 2 Flight Planning | 2.1〜2.3 | Text、簡易の飛行計画（最適高度、LRC・.85M の区間の燃料と時間、段階上昇、減圧時の代替、待機、酸素）p.87-98、driftdown p.99-104 | 81-104 |
| 3 Enroute | 3.1〜3.2 | 全発：LRC の最大高度 p.109、340/.84 の上昇（時間・燃料・距離）p.110-、LRC の燃料と時間 p.118-、LRC の表 p.120-127（各ページの下に最大巡航 EPR）、.85M の表 p.128-、風と高度の交換 p.131、降下 p.132、待機 p.133 | 105-134 |
| | 3.3 | 片発：LRC の高度の能力 p.135、LRC の表 p.136-、代替の燃料と時間 p.144、待機 p.145 | 135-146 |
| 4 Non-Standard Configuration | 4.1〜4.4 | 脚下げ（上昇の制限、障害物、着陸上昇、driftdown、LRC、上昇、降下、待機、片発） | 147-192 |
| | 4.5 | Alternate Mode EEC（離陸の制限重量の補正など） | 193-198 |

- 747-400F（貨物機）の資料。離陸の低速の値（VMCG・VRMIN・「VRMIN のときの V2」）は FCOM の PW4056 の表と同じ。巡航と待機の表は FCOM と少し違う（燃料流量が 0〜3.6 % 少なく、EPR が 0.01〜0.03 高い）：notes/ATA-34-61-FMC.md §168。
- 誤りと欠け：p.67（TO2・フラップ 20 の離陸速度）は A〜G の 340 t の行が無く、A〜E の 200 t などが空欄。p.47（TO1）の着陸上昇制限の 300 t は 213.5（273 前後の誤植）。p.56 の TO1 の「VRMIN のときの V2」は最後の列の見出しが 123 kt（FCOM は 120 kt）。

## Lufthansa B1（LH24・LH36・LH3460）

| ID | ATA | 内容 | PDF p. |
|---|---|---|---|
| LH24 | 24-00 | General（負荷分配、電源の構成、ELEC synoptic） | 3-49 |
| LH24 | 24-10 | Generator Drive（IDG） | 50-91 |
| LH24 | 24-20 | AC Generation（GCU、BTB、split system breaker など） | 92-161 |
| LH24 | 24-30 | DC Generation（TRU、バッテリー、充電器） | 162-213 |
| LH24 | 24-40 | External Power | 214-225 |
| LH24 | 24-50 | Electrical Load Distribution（バス、ground handling / ground service bus） | 226-256 |
| LH36 | 36-00 | General（ASCTU を含む） | 3-27 |
| LH36 | 36-10 | Distribution（エンジン抽気、PRV、HPSOV、precooler、manifold、isolation valve） | 28-93 |
| LH36 | 36-20 | Indication / Ground Test | 94-105 |
| LH36 | 30-xx | Ice Detection / Wing Thermal Anti-Ice | 106-129 |
| LH36 | — | 系統図と図の一覧 | 130-138 |
| LH3460 | 34-61 | Flight Management Computer System | 3-129 |
| LH3460 | — | 資格・図の一覧 | 130-136 |

## E&M 整備訓練マニュアル（ATA 章別）

各巻の p.1-2 は表紙。各小章の先頭ページに、その小章の目次（題目と小章内のページ番号）がある。

| ID | PDF p. | ATA | 章 / 小章 |
|---|---|---|---|
| ATA21 | 3-30 | 21-00 | ENVIRONMENTAL CONTROL SYSTEM / Airconditioning |
| ATA21 | 31-114 | 21-50 | ENVIRONMENTAL CONTROL SYSTEM / Cooling |
| ATA21 | 115-204 | 21-20 | ENVIRONMENTAL CONTROL SYSTEM / Distribution |
| ATA21 | 205-214 | 21-23 | ENVIRONMENTAL CONTROL SYSTEM / Main Deck Cargo Compartment Flapper Valves |
| ATA21 | 215-228 | 21-29 | ENVIRONMENTAL CONTROL SYSTEM / Overhead Crewrest |
| ATA21 | 229-258 | 21-40 | ENVIRONMENTAL CONTROL SYSTEM / Cargo Heating |
| ATA21 | 259-336 | 21-27 | ENVIRONMENTAL CONTROL SYSTEM / Forward Cargo Air Conditioning |
| ATA21 | 337-392 | 21-60 | ENVIRONMENTAL CONTROL SYSTEM / Temperature Control |
| ATA21 | 393-484 | 21-30 | ENVIRONMENTAL CONTROL SYSTEM / Pressurization |
| ATA21 | 485-616 | 21-58 | ENVIRONMENTAL CONTROL SYSTEM / Equipment Cooling |
| ATA22 | 3-48 | 22-00 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / General |
| ATA22 | 49-100 | 22-21 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / Yaw Damper |
| ATA22 | 101-174 | 22-22 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / Automatic Stabilizer Trim |
| ATA22 | 175-300 | 22-10 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / AFDS General |
| ATA22 | 301-326 | 22-11 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / Engage Interlocks |
| ATA22 | 327-364 | 22-12 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / Control |
| ATA22 | 365-408 | 22-14 | AUTOPILOT/FLIGHT DIRECTOR SYSTEM / Annunciations and Warnings |
| ATA23 | 3-80 | 23-51 | COMMUNICATION / Flight Interphone System |
| ATA23 | 81-100 | 23-41 | COMMUNICATION / Service Interphone System |
| ATA23 | 101-126 | 23-28 | COMMUNICATION / SELCAL |
| ATA23 | 127-164 | 23-30 | COMMUNICATION / ACESS Introduction |
| ATA23 | 165-284 | 23-42 | COMMUNICATION / Cabin Interphone System |
| ATA23 | 285-386 | 23-31 | COMMUNICATION / Passenger Address System |
| ATA23 | 387-460 | 23-34 | COMMUNICATION / Passenger Entertainment System (Audio Economy Class) |
| ATA23 | 461-542 | 23-32 | COMMUNICATION / Overhead Video System |
| ATA23 | 543-608 | 23-32 | COMMUNICATION / Passenger Entertainment System (Business Class) |
| ATA23 | 609-702 | 23-33 | COMMUNICATION / Passenger Service System |
| ATA26_28 | 3-16 | 26-00 | FIRE PROTECTION / General |
| ATA26_28 | 17-58 | 26-11 | FIRE PROTECTION / Engine Overheat and Fire Protection |
| ATA26_28 | 59-84 | 26-21 | FIRE PROTECTION / Engine Fire Extinguishing |
| ATA26_28 | 85-112 | 26-15 | FIRE PROTECTION / APU Fire Detection |
| ATA26_28 | 113-136 | 26-22 | FIRE PROTECTION / APU Fire Extinguishing |
| ATA26_28 | 137-166 | 26-16 | FIRE PROTECTION / Cargo Compartment Smoke Detection |
| ATA26_28 | 167-200 | 26-23 | FIRE PROTECTION / Cargo Fire Extinguishing |
| ATA26_28 | 201-232 | 26-14 | FIRE PROTECTION / Main Deck Cargo Compartment Smoke Detection System |
| ATA26_28 | 233-266 | 26-24 | FIRE PROTECTION / Main Deck Cargo Fire Extinguishing |
| ATA26_28 | 267-276 | 26-17 | FIRE PROTECTION / Wheel Well Fire Detection |
| ATA26_28 | 277-288 | 26-18 | FIRE PROTECTION / Wing Leading Edge Overheat Detection |
| ATA26_28 | 289-298 | 26-13 | FIRE PROTECTION / Smoke Detection |
| ATA26_28 | 299-304 | 26-27 | FIRE PROTECTION / Lavatory Fire Protection |
| ATA26_28 | 305-310 | 26-12 | FIRE PROTECTION / Crew Rest Smoke Detection |
| ATA26_28 | 311-324 | 26-14 | FIRE PROTECTION / Overhead Crew Rest Smoke Detection |
| ATA26_28 | 327-348 | 28-00 | FUEL / Introduction |
| ATA26_28 | 349-382 | 28-21 | FUEL / Fueling System |
| ATA26_28 | 383-436 | 28-41 | FUEL / Fuel Quantity Indicating System |
| ATA26_28 | 437-446 | 28-26 | FUEL / Defueling and Check Valve Assembly |
| ATA26_28 | 447-468 | 28-22 | FUEL / Engine Fuel Feed System |
| ATA26_28 | 469-482 | 28-25 | FUEL / APU Fuel Feed System |
| ATA26_28 | 483-504 | 28-16 | FUEL / Reserve and Main Tank Interconnection |
| ATA26_28 | 505-514 | 28-15 | FUEL / Center Wing Tank Scavenge System |
| ATA26_28 | 515-548 | 28-31 | FUEL / Fuel Jettison System |
| ATA26_28 | 549-566 | ? | FUEL / Summary |
| ATA27 | 3-48 | 27-00 | FLIGHT CONTROLS / Introduction |
| ATA27 | 49-136 | 27-10 | FLIGHT CONTROLS / Ailerons |
| ATA27 | 137-210 | 27-60 | FLIGHT CONTROLS / Spoilers |
| ATA27 | 211-340 | 27-50 | FLIGHT CONTROLS / Flaps |
| ATA27 | 341-414 | 27-80 | FLIGHT CONTROLS / Lift Augmenting |
| ATA27 | 415-524 | 27-40 | FLIGHT CONTROLS / Stabilizer |
| ATA27 | 525-590 | 27-30 | FLIGHT CONTROLS / Elevator |
| ATA27 | 591-688 | 27-20 | FLIGHT CONTROLS / Rudder |
| ATA27 | 689-714 | 27-32 | FLIGHT CONTROLS / Stall Warning System |
| ATA27 | 715-748 | 27-90 | FLIGHT CONTROLS / Configuration Warning System |
| ATA29_32 | 3-144 | 29 | HYDRAULICS / — |
| ATA29_32 | 147-290 | 32-00 | LANDING GEAR / Landing Gear Structures |
| ATA29_32 | 291-342 | 32-09 | LANDING GEAR / Air/Ground relay-PSEU Systems |
| ATA29_32 | 343-380 | 32-40 | LANDING GEAR / Wheels and Brakes |
| ATA29_32 | 381-442 | 32-41 | LANDING GEAR / Hydraulic Brakes |
| ATA29_32 | 443-496 | 32-42 | LANDING GEAR / Brake Control System |
| ATA29_32 | 497-564 | 32-42 | LANDING GEAR / Autobrake System |
| ATA29_32 | 565-634 | 32-50 | LANDING GEAR / Landing Gear Steering |
| ATA29_32 | 635-674 | 32-61 | LANDING GEAR / Landing Gear Position Indication & Warning |
| ATA30_32_35_36 | 3-34 | 36-00 | PNEUMATIC / Introduction |
| ATA30_32_35_36 | 35-118 | 36-10 | PNEUMATIC / Engine Bleed Air |
| ATA30_32_35_36 | 119-148 | 36-20 | PNEUMATIC / Engine Bleed Air Press Indication |
| ATA30_32_35_36 | 151-308 | 30-00 | ICE AND RAIN PROTECTION / — |
| ATA30_32_35_36 | 311-386 | 35-00 | OXYGEN / — |
| ATA31 | 3-58 | 31-62 | INDICATING/RECORDING SYSTEMS / Electronic Flight Instrument System |
| ATA31 | 59-82 | 31-25 | INDICATING/RECORDING SYSTEMS / Clocks |
| ATA31 | 83-274 | 31-51 | INDICATING/RECORDING SYSTEMS / Aural Warning System |
| ATA31 | 275-334 | 31-31 | INDICATING/RECORDING SYSTEMS / Flight Data Recorder System |
| ATA31 | 335-408 | 31-35 | INDICATING/RECORDING SYSTEMS / Airplane Condition and Monitoring System |
| ATA31 | 409-564 | 31-41 | INDICATING/RECORDING SYSTEMS / Weight & Balance System |
| ATA33 | 3-362 | 33 | LIGHTS / — |
| ATA34_1 | 3-32 | 20-11 | DIGITAL SYSTEMS / Digital Systems |
| ATA34_1 | 33-70 | 34-11 | NAVIGATION / Pitot/Static System |
| ATA34_1 | 71-82 | 34-13 | NAVIGATION / Standby Air Data Instruments |
| ATA34_1 | 83-168 | 34-12 | NAVIGATION / Air Data Computer System |
| ATA34_1 | 169-200 | 34-16 | NAVIGATION / Altitude Alert System |
| ATA34_1 | 201-274 | 34-43 | NAVIGATION / Weather Radar System |
| ATA34_1 | 275-322 | 34-57 | NAVIGATION / Automatic Direction Finder System |
| ATA34_1 | 323-386 | 34-51 | NAVIGATION / VOR Navigation System |
| ATA34_1 | 387-422 | 34-32 | NAVIGATION / Marker Beacon System |
| ATA34_1 | 423-512 | 34-31 | NAVIGATION / Instrument Landing System |
| ATA34_1 | 513-572 | 34-55 | NAVIGATION / Distance Measuring Equipment |
| ATA34_1 | 573-646 | 34-53 | NAVIGATION / Air Traffic Control |
| ATA34_2 | 3-68 | 34-45 | NAVIGATION / TCAS |
| ATA34_2 | 69-110 | 34-33 | NAVIGATION / Radio Altimeter System |
| ATA34_2 | 111-240 | 34-46 | NAVIGATION / Ground Proximity Warning System |
| ATA34_2 | 241-256 | 34-24 | NAVIGATION / Standby Attitude Reference System |
| ATA34_2 | 257-262 | 34-22 | NAVIGATION / Standby Magnetic Compass |
| ATA34_2 | 263-374 | 34-21 | NAVIGATION / Inertial Reference System |
| ATA34_2 | 375-426 | 34-58 | NAVIGATION / Global Positioning System |
| ATA34_2 | 427-736 | 34-61 | NAVIGATION / Flight Management Computer System |
| ATA38_51_52_56 | 3-134 | 38-00 | WATER AND WASTE / — |
| ATA38_51_52_56 | 137-206 | 51-00 | STRUCTURES / — |
| ATA38_51_52_56 | 209-564 | 52-00 | DOORS / — |
| ATA38_51_52_56 | 567-614 | 56-00 | WINDOWS / — |
| ATA70_80 | 3-64 | 71-00 | POWERPLANT / General |
| ATA70_80 | 65-102 | 72-00 | POWERPLANT / Engine |
| ATA70_80 | 103-248 | 73-00 | POWERPLANT / Engine fuel & control |
| ATA70_80 | 249-272 | 74-00 | POWERPLANT / Ignition |
| ATA70_80 | 273-316 | 75-00 | POWERPLANT / Air |
| ATA70_80 | 317-396 | 77-00 | POWERPLANT / Engine Indicating |
| ATA70_80 | 397-482 | 78-00 | POWERPLANT / Exhaust |
| ATA70_80 | 483-530 | 79-00 | POWERPLANT / Oil |
| ATA70_80 | 531-576 | 80-00 | POWERPLANT / Engine start system operation and interface |

## 2026-11-19 の資料（章 × PDF ページ）

読んだ結果（要点・GAP）は各系統のノートの「2026-11-19 の資料から」の節と、GAP_ANALYSIS.md の §5。

### TCDS_747（A20WE Rev 58。R64 のページは括弧）

| 章 | 内容 | PDF p. |
|---|---|---|
| 表紙 | 版、型式の一覧 | 1 (1) |
| I〜IX | -100〜-100B SUD（旧型。VMO/MMO 375/0.92 KEAS） | 1–8 (1–8) |
| 旧型の共通事項 | 推力、最大高度 45,100 ft、乗員、旅客、Datum、MAC、rigging、基準 | 8–12 (8–12) |
| X 747-400 | エンジン、VMO/MMO 365 KCAS/0.92、W&B D043U540/541、AFM D6U10001〜3、機番 | 12–13 (13–14) |
| 同 | 最大高度、乗員、旅客、**Datum（BS 0 ＝機首の 90 in 前）・MAC 327.8 in・LEMAC は datum の 1258.0 in 後ろ**、rigging（安定板トリム 251U4001）、基準、ESF（1-g 失速速度） | 14–17 (14–18) |
| XI 747-400D／XII 747-400F／XIII 747-400SF（BCF）／XIV LCF | 同じ項目 | 17–20／21–24／24–27／27–29 (18–21／22–25／25–28／28–30) |
| -400 共通 | 燃料タンクの不活性化、**推力の表（TO 5 分・MCT）** | 30 (31) |
| Notes 1〜19 | 燃料・油、混用、旅客数（Note 10）、**EICAS メッセージの 7 種類（Note 12・13）** | 30–35 (31–36) |
| XV 747-8F／XVI 747-8 | 747-8 の認証基準（AFDS の速度保護は 747-8 のもの） | 35–56／56–75 (36–57／57–77) |

### PW_PPM（KLM「B747-400 Power Plant PW4000」）

| 節（ATA） | 内容 | PDF p. |
|---|---|---|
| — | 表紙・目次 | 1–2 |
| Sec 2（71） | 概要、**PW4056 の仕様（p.7）**、カウル、逆推力の構造、排気・マウント・ドレン、危険区域、装着後の試験 | 3–73 |
| Sec 3（72） | 構造、段ごとの抽気、ギアボックス | 74–136 |
| Sec 4・5（72） | ボアスコープ、**性能の典型値（最小アイドル p.149、離陸 p.150、FL350 p.151）** | 137–152 |
| Sec 6（73） | FADEC/EEC（電源 p.167、取り合い p.170–193、**アイドル・EPR/N1 のモードと TRA p.194–199**、推力管理・定格・ALTN・**制限保護 p.204**・オーバースピード p.206–207、**飛行／地上アイドル p.208–209**、A/T・**トリム p.210–218**、**故障の補い方 p.219–225**） | 153–225 |
| Sec 7（73） | 燃料系（**運転状態ごとの EEC の部品の表 p.250**） | 226–251 |
| Sec 8〜11（75） | 2.5・2.9 ブリード・VSV（表 p.290）、TCC、TVBCA、HPC secondary flow | 252–362 |
| Sec 12（79） | 油（**系統データ p.369**、タンク・ポンプ・フィルタ・熱交換器、**油冷却・燃料加熱 p.406–408**）、IDG の油冷却 | 363–434 |
| Sec 14（74） | 点火（**選択と制御 p.444**） | 435–460 |
| Sec 16（77） | 表示（**EPR 468、N1 470、N2 472、EGT 474**、FF、フィルタ、油量、**油圧 484、油温 486**、DOT、振動） | 461–492 |
| Sec 18（80） | 地上運転と始動（**始動 498–503**、スタータ・使用時間 508、始動弁、始動空気、**始動の制御と表示・論理図 520–523**、モータリング） | 493–526 |
| Sec 20 | 故障切り分け（EICAS 整備ページ、EPCS、性能） | 527–540 |
| ATA 78 | 逆推力（作動 548–552、**制御・interlock 580–589**、**レバー角 598–599**、油圧 600–605、**位置指示・auto-restow・不一致 607–621**、不作動化） | 541–636 |

### NASA_SIM（D6-30643 Vol. II、747-100）

| 章 | 内容 | PDF p. |
|---|---|---|
| 1.0–1.3 | 機体（三面図、**寸法・MAC 27.31 ft p.22**、制限、CG の範囲、慣性 p.25–28）、操縦系統（油圧 p.35）、シミュレーション（**推力の腕 p.38**、**最大舵角と速さ p.42**） | 18–48 |
| 2.0–7.0 | 揚力（CLmax・フラップの増し分 p.55、失速警報 p.83、地面効果 p.79–80）、抗力（脚 p.101）、縦のモーメント（**安定板の効き p.127、昇降舵 p.128–129**）、ロール、ヨー、横の力 | 49–231 |
| 8.0–11.0 | 縦の操縦（**安定板のトリム p.246–247**）、横の操縦、方向の操縦（**ヨーダンパー p.279–280**）、高揚力装置 | 232–283 |
| 12.0 | 推進 JT9D-3（逆推力の空力 p.317–318） | 284–318 |
| 13.0 | 脚（オレオ、横力、**転がりとブレーキの μ p.323**、減衰、空気ばね） | 319–325 |
| 14.0 | 確認（**安定板の pilot units p.328**、**縦の釣り合いと地面効果のトリム p.337**、形態の変化 p.347、**安定板と昇降舵の交換 p.349**、ダッチロール p.351–361、ロールの速さ p.416） | 326–421 |
| 15.0 付録 A | 747-100 の AFM（手順 p.429–432、**推奨の離陸安定板 p.442**、失速速度 p.445） | 422–484 |
| 16.0–17.0 | バフェット、A/T | 485–511 |
| 18.0 付録 D | A/P・F/D（SPZ-1：ロール 表 4 p.553、ピッチ 表 7 p.567、FLARE p.582–583、自動トリム p.588）、**ヨーダンパー p.591–604**、A/T p.605–611 | 512–611 |
| 19.0 付録 E | 改訂データ（**地面効果 p.614–620**、スポイラーの program p.621–622） | 612–622 |
| 20.0 付録 F | 操縦入力への応答の飛行データ | 623–636 |

### NASA_HQ（CR-2144。PDF ＝本のページ＋6）

| 章 | 内容 | PDF p. |
|---|---|---|
| 表紙・目次・序 | Table I-1（機体 × 項目） | 1–10 |
| II〜VIII、X、XI | NT-33A、F-104A、F-4C、X-15、HL-10、JetStar、CV-880M、C-5A、XB-70A | 11–215、249–322 |
| **IX Boeing 747** | 飛行条件 218、操縦系統 220、ヨーの SAS 221、無次元微係数 222–234、寸法・質量 235、縦の次元つき 236、伝達関数 237–238・241–246、**縦の操縦性 239**、横・方向の次元つき 240、**横・方向の操縦性 247** | 216–248 |
| 付録 A〜C | 定義、軸の換算、運動方程式 | 323–351 |

### CPDLC（PDF ＝資料＋1）

| 章 | 内容 | PDF p. |
|---|---|---|
| 1・2 | 要旨、文献（旧型の画面 15–19、メッセージの集合 25–27、読み込めるメッセージ 28–33、装備 33–35） | 10–50 |
| 3・4 | 分析（ASRS 58–60、指示ごと 67–83）、提言（段階ごとの手順 92–119） | 51–142 |
| 付録 F | SC-214 の指示の一覧（**属性 p.178**、表 F-1 p.179–200） | 176–200 |
| **付録 G** | **747-400 の FMS が読み込める指示の規則** | 202–203 |
| 付録 H・I | 自動化の方針、機種ごとの分析 | 204–217 |

### ARINC424（PDF ＝資料＋15）・ICAO_NDB

| 章 | 内容 | PDF p. |
|---|---|---|
| 4.1.9・4.1.10 | **SID/STAR/Approach（PD/PE/PF）の桁**、**Runway（PG）** | 33–35 |
| 5.7・5.17 | **Route Type**、**Waypoint Description Code** | 73–74、78–80 |
| 5.20–5.30 | Turn Dir・Path Term・TDV・Recd Navaid、コース（T は真方位）、**Altitude Description** | 82–87 |
| 5.53・5.57・5.69・5.70・5.72・5.261 | **Transition Alt、Runway Length、Displaced、Vertical Angle、Speed Limit、Speed Limit Description** | 95–100、141 |
| Att.5 | **Path and Terminator**（前提 188–189、**脚の欄の表 3 p.197**、規則 198–202、SID・STAR・進入・missed の例 203–269） | 188–269 |
| ICAO_NDB | 脚の図 11–22、必要な欄 23–26、並び 27–28、Turn Direction 32、速度と高度の制限 33–35 | 1–41 |

### MMEL（Rev 32）

| ATA | PDF p. | ATA | PDF p. |
|---|---|---|---|
| 前付（版 2、改訂 3–9） | 1–10 | 30 防氷 | 179–184 |
| 21 空調 | 11–57 | 31 指示 | 185–187 |
| 22 自動飛行 | 58–62 | 32 脚 | 188–195 |
| 23 通信 | 63–82 | 33 灯火 | 196–204 |
| 24 電源 | 83–87 | 34 航法 | 205–224 |
| 25 装備 | 88–110 | 35 酸素／36 空圧 | 225–228／229–238 |
| 26 防火 | 111–136 | 38・45・46・47 | 239–243 |
| 27 操縦 | 137–141 | 49 APU／52・53・56 | 244／245–266 |
| 28 燃料 | 142–172 | 73・74・75 | 267–269・270・271–272 |
| 29 油圧 | 173–178 | 77・78・79・80 | 273・274–275・276–277・278 |

### そのほか

| ID | 章と PDF ページ |
|---|---|
| TCDS_PW4000 | p.1 定格と flat rating、p.2 重量、**p.3 Note 1–3（回転数・温度・圧力）**、p.4 Note 4・7・8、p.5 Note 19・21、p.6 排出 |
| TCDS_CF6 | p.4–7 型式、**p.10–11 Note 1–2・油**、p.15 最小空中アイドル、p.16–17 Note 15–17、p.20 Note 23 |
| TCDS_CF6_EASA | p.10–11 定格、**p.15–17 運用限界**、p.20–21 flat rating、p.22–25 型式 |
| TCDS_RB211 | p.4–5 型式、p.10 定格と 100 % 回転数、p.11 FAFC、p.15 flat rating、**p.16 TGT、p.17 油温、p.18–19 回転数、p.20 油圧、p.21 油量**、p.23 Note 9–10 |
| AC_SPECS | p.1 概要・エンジン・MTOW の経緯（APU は PW901A）、**p.2 Family Specifications の表**、p.3 -400F・ER・ERF・D |
| VT_SPECS | p.2 諸元、p.5 主翼、p.11 CG と中立点、p.13 抵抗極曲線（747-100、学生） |
| APU_MTM | （A320/APS 3200）Level 2 4–17、説明 18–37、System Management 38–45、写真 46–73 |
| LH_MAN | 文書の使い方 4–45、**切り分けと CMC の画面 46–74**、実例（IDG・外部電源・BCU）75–96、DC 発電 97–100、AMM 201 101–103、MEL・MMP 104–107、**GCU 2 の論理図 p.111** |
| COMM | p.4 ACARS、p.5 PA、p.6 service interphone、**p.7 地上員の呼出**、p.8 上部デッキの呼出、p.10–11 AMU、p.12 CVR |
| OMS／CMCS | 一般論（CMC、BITE、ACARS、データローディング）／787 の CMCF |
| EICAS_WS | 概要 3–8、EIU 9–14、音と master 15–23、caution・advisory 24–30、CANC/RCL 31–42、**離陸の抑止 43–49**、始動前 50、置き換え 51–52、memo 53–55 |
| AOM_JP | p.3–9 概要・音・**抑止**、**p.10–11 離陸・着陸形態警報**、p.12–22 失速・過速・GPWS、p.23–26 操作と表示、**p.27–34 メッセージ一覧** |
| CB_BA | p.1 パネル、p.2 配置図、p.3–12 系統ごとの CB |
| HYD_SCH | p.1 略図 |
| NTSB_WBM | 用語と重量の定義 14–20、**貨物室と主甲板の区画の上限 22–26**、**貨物室の arm p.32**、固縛 41–80 |
| NTSB_STR | **D.2–D.3 図 1（STA と B.A.）p.8–10**、D.6 積み付け（表 1）26–30 |
| WBM_SUP | p.1–2 |
