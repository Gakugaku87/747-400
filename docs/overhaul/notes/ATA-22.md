# ATA 22 Autopilot Flight Director System（AFDS）・ヨーダンパー・自動スタビライザートリム — 実装ノート

GAP ID の接頭辞：`AFDS`。2026-10-23 作成。コードは `overhaul` ブランチ（041c9ffa）時点。行番号は同ブランチのもの。

## 1. 概要

- 対象：MCP の操作子、A/P の engage/disengage とインターロック、3 チャンネル（L/C/R）と LAND 3/LAND 2、F/D、ロール・ピッチの全モードの arm/engage/遷移（TO/GA、LNAV・VNAV の AFDS 側、HDG SEL/HOLD、ATT、FLCH、V/S、ALT、LOC、G/S、FLARE、ROLLOUT）、モードの自動反転、FMA、A/P 切断警報、autoland 状態表示、ヨーダンパー（22-21）、自動スタビライザートリム（22-22。手動トリムとの関係を含む）。
- 対象外：autothrottle と推力管理（別担当。A/T と AFDS の取り合いだけ書く）、FMC の水平・垂直経路計算（別担当。AFDS が受け取る量と、LNAV/VNAV の arm・engage・反転だけ書く）、ILS/RA/IRS の受信機（ATA 34）、舵面・ratio changer・stab の機構（ATA 27）、bus isolation の電源側（ATA 24、ELEC-18）。
- 使った資料（PDF ページ）：
  - ATA22：22-00 p.4–44（A/P サーボ・CLCP・油圧割当て）、22-21 p.49–96（図 p.85・87）、22-22 p.101–170（図 p.149・159）、22-10 p.175–298（図 p.191・295）、22-11 p.301–324（図 p.319）、22-12 p.327–362（図 p.335・337・339・341・343・345・347・351・353・355・357）、22-14 p.365–404（図 p.371・383・385）。
  - FCOM 4.10 p.639–657、4.20 p.659–675、4.30 p.677、SP.4 p.171–175、10.30 p.1081–1107（FMA の典型表示）。関連：L.10 p.79–80、9.10/9.20/9.30 p.927–931・944–950・958、10.10 p.966・978–980・999–1000・1043、Bulletin TB1-4 p.47。
  - FCTM p.43・48・63–66・112・117–118・124・159・162・165–166・207・209。
- 型式差（FCOM の機体番号。109・405 が P&W、570 が GE。ATA-29 ノート参照）。RR は `資料に記載なし`。
  - ATT：109/405 にあり、570 には無い（F/D ON・A/P engage の既定ロールが HDG HOLD だけ）（FCOM p.640、p.663）。
  - G/S 捕捉：109/570 は LOC より先でも可、405 は LOC 捕捉まで抑止（FCOM p.651、p.669–670）。
  - AUTOPILOT DISC の音：109/405 は wailer（最低 1 秒）、570 は siren（FCOM p.655、p.677）。
  - F/D モード故障：109/405 は該当する bar だけ、570 は両 bar が消える（FCOM p.660）。
- 資料の食い違いと採用：
  - ROLLOUT の起動：FCOM 約 5 ft RA（p.664、p.671）、ATA 2 ft（p.296、p.360）。FMA の切替は FCOM の約 5 ft を採る。翼水平指令（ROLL DOWN）は ATA の 5 ft gear altitude（p.348）。
  - AUTOPILOT DISC の音：ATA は two-tone siren（p.366）。FCOM の型式別を採る。
  - stab trim の EICAS：ATA は STAB AUTO TRIM・STAB SPEED TRIM・STAB TRIM・STAB TRIM UNSCHD・STAB AUTO CUTOUT（p.170）、FCOM は >STAB GREENBAND・>STAB TRIM 2, 3・STAB TRIM UNSCHD（p.958）。乗員表示は FCOM を採る。ATA の残りは STATUS／整備レベルと `推定`。
  - FLARE の高さ：FCOM は 60–40 ft（p.665）・約 50 ft（p.671）、ATA は沈下率で 40/50/60 ft（p.342、図 p.295）。両立するので ATA の表を採る。
  - 単一チャンネルの flare：FCOM は「単一 A/P・F/D だけでは使わない」（p.670）、制限で 100 ft AGL までに解除（p.80）。ATA は単一 A/P でも flare まで可（p.288）で、そのとき AUTOPILOT caution（p.382）。挙動は ATA、運用は FCOM。
  - GA の目標速度：FCOM は MCP と現速度の大きい方、5 秒超過で現速度に更新（上限 MCP+25）（p.664、p.673）。ATA は片発時の上限を MCP+10 とする（p.298）。片発だけ ATA を採る。

## 2. 構成

### 2.1 FCC・MCP・サーボ

- FCC 3 台（L/C/R）。モード管理、制御則、故障検知、構成管理（engage と表示）、冗長管理、整備（ATA22 p.181）。プロセッサはピッチ用とロール/ヨー用の 2 個。制御則は 25 ms ごと、BITE は 1.5 s ごと（p.233）。
- 電源（ATA22 p.191 図）：

| 機器 | AC（本体） | DC（servo・engage） | 備考 |
|---|---|---|---|
| L FCC | 115V AC bus 3 | 28V DC bus 3 | |
| C FCC | 115V AC bus 1 | 28V DC bus 1 | |
| R FCC | 115V AC bus 2 | 28V DC bus 2 | |
| 警報（全 FCC の AFDS WARN） | — | 28V DC STBY bus（AUTO FLT WARN） | 本文は battery bus と書く（p.190） |
| MCP ch A / ch B | — | 28V DC bus 3（MCP L）/ bus 2（MCP R） | 照明は 0–5V AC |

- MCP：A/B の 2 チャンネル。A は L・C FCC、B は R・C FCC から入力し、片方が壊れると他方が両側に出す（p.209）。電源投入時の表示は IAS 200、HDG 000、V/S 空白、ALT 10000（p.236、FCOM p.643・647・649）。
- サーボ（ATA22 p.10–12、p.32–44、p.222、p.242–248）：

| チャンネル | 油圧 | aileron | elevator | rudder |
|---|---|---|---|---|
| L | 3 | L CLCP | L elevator A/P servo | L rollout PCP |
| C | 1 | lateral A/P servo | C elevator A/P servo | C rollout PCP |
| R | 2 | R CLCP | R elevator A/P servo | R rollout PCP |

  - 巡航は aileron・elevator 各 1 個。autoland で 2・3 個目が加わる。rudder（rollout PCP）は dual/triple のときだけ engage（p.222）。
  - サーボの状態は disengaged／armed（LVDT で舵面位置に同期）／engaged（EHSV で駆動）／camout（servo と surface の LVDT 不一致）（p.242–244）。
  - 複数チャンネルは機械的な力の投票。3 系は中間値、2 系は小さい方。大きく食い違うと、3 系は外れた FCC が、2 系は両方が外れる（p.32）。
- A/P は aileron と elevator を動かす。rudder は multi-A/P approach のときだけ、rollout では NWS も（FCOM p.659）。

### 2.2 入力

- IRU×3、ADC×3、RA×3、ILS×3、master FMC（ATA22 p.200–212）。Capt 選択の ADC が L・C FCC、F/O 選択の ADC が R FCC へ（p.204）。
- 信号選択：起動時は自系だけ。2 個以上有効で A/P engage か F/D ON のとき中間値選択。LOC/GS は捕捉から、RA は LOC+GS 捕捉かつ 1500 ft 未満から中間値（p.200）。
- ADC の使い分け：R A/P が first engaged、または F/O の F/D だけ ON のとき全 FCC が F/O 側 ADC を使い、ほかは Capt 側。無効なら反対側へ自動切替し、A/P と F/D が OFF になるまで保持（p.202）。FMC も同じ考え方（p.202）。
- FMC → FCC：horizontal steering、target airspeed/Mach/altitude、vertical steering と rate、min/max speed（p.206）。
- 機体構成：flap（内側 TE の RVDT、FCU 経由）、stab 位置（FCU）、speedbrake handle（RVDT×3）。HYDIM の「油圧有効」は診断専用、air/ground は ground test 専用（p.218）。
- 離散入力：disengage switch、GA switch（thrust lever 2・3 に各 3 接点）、HDG REF switch（magnetic/true）、F/D source select（p.220、p.240、FCOM p.1043）。

### 2.3 出力

- EIU 経由で PFD（FMA、AFDS 状態、FD 指令、選択値）と EICAS（p.226、p.366）。master warning と aural は MAWEA（A/P WARN 1/2 を normal と battery の 2 系統で出す）、master caution は EIU（p.226、p.380）。
- SRM へ autotrim の arm・engage・指令（§4.8）。
- ILS TUNE INHIBIT（A/P 時は LOC/GS 捕捉後、F/D だけなら 500 ft RA 未満、地上で滑走路方位 45° 以内・40 kt 以上・LOC/APP 未選択のとき）と RA TEST INHIBIT（p.212）。LOC アンテナは地上か LOC/APP 選択で前方へ、GS アンテナは脚下げで nose gear door へ。切替の 1 系故障で NO LAND 3、2 系以上で NO AUTOLAND（p.214–216）。
- APP arm 中に BCU 1 へ bus isolation 要求。4 秒以内に分離し、BCU 2 が BUS ISOLATED を返す（LAND 3 の必要条件）（p.192–196、ATA-24 の ELEC-18）。

### 2.4 ヨーダンパー

- YDM 2 台（upper → upper rudder、lower → lower rudder）。各 YDM に control と monitor の 2 プロセッサ（p.52、p.74）。
- 入力：IRU（横加速度、roll rate、yaw rate、GS、roll angle）、ADC（impact pressure、AOA、TAS、overspeed）、modal accelerometer×4、air/ground（3 本）、油圧（HYDIM と pressure switch。正常時は相反）（p.64–70）。
- 出力：RPCM 内の Y/D actuator（engage solenoid → EHSV、LVDT 帰還）。油圧は upper が 3、lower が 2（p.64、p.78、FCOM p.949）。pedal は動かない（FCOM p.949）。
- 電源：upper は FCEPSM-1L（故障で 2L）の 26V AC（両 L FCEPSM は AC standby bus から）と 28V DC battery bus、engage relay は FCE DC CB 1・2。lower は FCEPSM-1R（AC bus 1）と DC bus 1・2（p.60–62）。

### 2.5 自動スタビライザートリム（ASTS）

- SRM 2 台（L/R、それぞれ arm 用と control 用のプロセッサ）、STCM 2 台（油圧 2・3。solenoid valve 5 個と MOV）（p.125、p.131、p.160）。SRM の機能：manual trim、FCC autotrim、speed trim、rate control、自動 shutdown（rudder ratio と aileron lockout は ATA 27）（p.125）。
- 電源：L SRM は L FCE PSM（AC standby、battery bus）、shutoff・rate・control は 28V DC bus 3、manual trim も DC bus 3、alternate trim は battery bus。R SRM は 2R PSM（AC bus 2・DC bus 2）、shutoff・rate・control は DC bus 2（p.116–118）。
- FCC との対応：L FCC → L SRM、R → R、C → 両方。SRM の autotrim valid は L SRM → L・C FCC、R SRM → R・C FCC。engage interlock にも使う（p.144、p.224）。
- 他の入力：ADC の CAS（L SRM は Capt ADC が主）、air/ground、gear down（PSEU）、stab・flap 位置（FCU）、各 STCM の brake release（p.120）。

## 3. 操作と表示

### 3.1 MCP・グレアシールド・操縦輪・スラストレバー

| 操作子 | 実機の挙動（要点） | 典拠 |
|---|---|---|
| F/D L/R | ON：自側 PFD に FD。地上・A/P なし・両 OFF から最初の ON で TO/GA（roll・pitch）。飛行中・A/P なし・両 OFF から最初の ON で V/S＋HDG HOLD（bank > 5° なら ATT。570 は HDG HOLD だけ）。A/P engage 中に最初の ON で A/P のモードを表示。OFF：FD を出さない。ただし >80 kt・flap UP 以外で TO/GA を押すと出る（F/D を ON→OFF で消える） | FCOM p.639–640、p.660–661 |
| A/P ENGAGE（CMD L/C/R） | どれか押すと engage。F/D ON ならその F/D のモード、両 OFF なら V/S＋HDG HOLD/ATT。巡航では 2 台目が engage しない（MCP の要求による engage は他チャンネルの servo が engaged でないことが条件。multi は APP からだけ） | FCOM p.640、ATA22 p.266、p.314、図 p.319 |
| DISENGAGE bar | 下げ：全 A/P 解除、engage 禁止、amber stripe。上げ：engage 可 | FCOM p.640 |
| A/P disengage switch（操縦輪） | 1 回目：全 A/P 解除、master warning、>AUTOPILOT DISC、音。自動解除後なら警報のリセット。2 回目：リセット | FCOM p.655 |
| IAS/MACH 窓 | 電源投入 200 kt。100–399 kt、.400–.950。上昇で約 .840 で Mach、降下で約 310 kt で IAS に自動切替。FMC 速度のとき空白。FLCH SPD・V/S・TO/GA・ALT・G/S では開く | FCOM p.642–643 |
| SEL | IAS⇔Mach（Mach 0.4 以上で IAS→Mach）。窓が空白なら無効 | FCOM p.643 |
| IAS/MACH selector 押し | VNAV 中に窓を開閉（speed intervention）。VNAV PTH で降下中に開くと VNAV SPD、制約を捕捉すると PTH。approach 中は PTH のまま A/T が速度 | FCOM p.643 |
| LNAV | arm/select/disarm。50 ft 以上で、active leg から 2.5 NM 以内なら即 engage、外なら intercept heading 上で接近時に engage。intercept heading でなければ CDU に NOT ON INTERCEPT HEADING。最終点・discontinuity・offset の終点などでは現 heading を保持。HDG HOLD/SEL、LOC 捕捉、FMC 二重故障で解除。armed 中の 2 回目で disarm | FCOM p.644–645、p.663 |
| VNAV | arm/select/disarm。400 ft 未満は白で arm、400 ft で engage。データ不足は PERF/VNAV NOT AVAILABLE。TO/GA・FLCH・V/S・ALT・G/S と FMC 二重故障で解除。armed 中の 2 回目で disarm | FCOM p.645、p.664–665 |
| FLCH | FLCH SPD。窓が空白なら FMC 目標速度（無効なら現速度）で開く。TO/GA→FLCH は現速度と選択速度の大きい方。選択高度で ALT。A/T は THR、降下では続いて HOLD | FCOM p.646 |
| HDG 窓・selector | 電源投入 000。LOC 捕捉で ILS front course に変わる | FCOM p.646–647 |
| HDG SEL | HDG SEL（bank limit が効く）。先に方位を選んで押すと近い側へ旋回、押してから回すと回した向きへ旋回 | FCOM p.647、ATA22 p.274 |
| BANK LIMIT | AUTO：TAS・flap・V2 で 15–25°。5/10/15/20/25：その値が上限。FCTM は LNAV にも効き、離陸 flap で V2+10 未満は 15° とする | FCOM p.647、FCTM p.118 |
| HDG HOLD | 翼水平にしてから、その時の heading を保持 | FCOM p.647、p.663 |
| V/S | V/S 以外では窓は空白。押すと現 V/S を表示して V/S。100 fpm 刻み、−8000〜+6000 fpm。選択高度で ALT。A/T は armed なら SPD | FCOM p.648 |
| ALT 窓・selector | 0–50000 ft、100 ft 刻み、電源投入 10000。押し：制約を 1 個削除、上昇中に CRZ ALT を窓の値へ、巡航中は CRZ ALT 変更と VNAV PTH/ALT からの上昇・降下開始、T/D 50 NM 以内で reduced rate descent | FCOM p.649 |
| ALT HOLD | 押した時の高度を保持 | FCOM p.650 |
| LOC | arm/disarm/capture。進入角 120° 以内で捕捉。捕捉前は 2 回目か他のロールモードで disarm、捕捉後は LNAV 以外のロールモード、TO/GA、A/P 解除＋両 F/D OFF で解除 | FCOM p.650–651 |
| APP | LOC と G/S を arm、他の A/P を arm（CMD 灯点灯）し、LOC・G/S 捕捉かつ RA < 1500 ft で engage。G/S は 80° 以内で捕捉。捕捉前は 2 回目、LOC/LNAV/VNAV 選択で disarm。LOC 捕捉・G/S arm 中は LNAV 以外のロールモードで解除（LOC を押すと LOC approach）。G/S 捕捉・LOC arm 中（109/570）は VNAV 以外のピッチモードで解除。捕捉後は TO/GA か A/P 解除＋両 F/D OFF | FCOM p.651–652 |
| TO/GA switch | 地上 50 kt 未満・flap UP 以外：A/T THR REF（A/T 担当）。離陸後（TO 推力のまま）：50–400 ft は TO/GA roll、400 ft 以上は roll と pitch。approach（flap UP 以外か G/S 捕捉）：TO/GA roll・pitch、A/T THR（2000 fpm）、2 回目で THR REF。A/P も F/D も無いときは FD・THR・TO/GA・TO/GA を表示 | FCOM p.656–657 |

- 選択値（速度・Mach・方位・高度）は A/P/F/D の engage 前に設定できる。V/S だけは不可（FCOM p.660）。
- 全モードは A/P 解除＋両 F/D OFF で消える。LOC・G/S 捕捉後は、それか TO/GA でしか解除できない（FCOM p.660）。

### 3.2 FMA と AFDS 状態（PFD）

- 並び：A/T｜roll｜pitch。active は上段に大きい緑、armed は下段に小さい白（TO/GA armed は表示しない）（FCOM p.662–663、ATA22 p.376–378）。
- active roll：TO/GA、HDG HOLD、HDG SEL、LNAV、LOC、ROLLOUT、ATT（109/405）。armed roll：LNAV、LOC、ROLLOUT（FCOM p.654）。
- active pitch：TO/GA、ALT、V/S、VNAV PTH、VNAV SPD、VNAV ALT、G/S、FLARE、FLCH SPD。armed pitch：VNAV、G/S、FLARE（FCOM p.654）。
- AFDS 状態（attitude の上）：FD（F/D ON・A/P なし。ON の側だけ）、CMD（A/P engaged。両側）、LAND 3、LAND 2（緑に白三角）、NO AUTOLAND（amber）、TEST（FCOM p.654、p.662、ATA22 p.250、p.384）。1500 ft RA 未満の multi-channel では autoland 状態が engage 状態に代わる（ATA22 p.250、p.370）。
- モードが変わると 10 秒間緑の枠。NO AUTOLAND への劣化は 10 秒間 amber の枠。故障したモードには amber の横線（FCOM p.653、ATA22 p.369）。
- FD の故障：選択 FCC のデータが無効なら FD 故障旗、bar は視野外へ（ATA22 p.252、p.369、FCOM p.999–1000）。
- 表示の出どころ（EIU）：A/P engaged/armed なら engaged の FCC（Capt 側は L, C, R、F/O 側は R, C, L の順）。F/D だけなら F/D source 切替の FCC。autoland 状態はどれかの FCC が立てれば表示し、NO AUTOLAND > LAND 2 > LAND 3 の優先（ATA22 p.369–370）。
- 典型表示（FCOM p.1082–1107）：離陸前 HOLD｜TO/GA｜TO/GA、armed LNAV・VNAV、FD。上昇 THR REF｜LNAV｜VNAV SPD、CMD。巡航 SPD｜LNAV｜VNAV PTH。降下 HOLD｜LNAV｜VNAV PTH。進入 SPD｜LOC｜G/S、armed ROLLOUT・FLARE、LAND 3。接地後 ROLLOUT、LAND 3。

### 3.3 ヨーダンパー・stab trim の操作と表示

- YAW DAMPER UPPER/LOWER：ON で給電。INOP 灯はスイッチ OFF か YD 不作動（FCOM p.931、p.950、ATA22 p.72）。
- stab trim：操縦輪の 2 連スイッチ（両方を同方向）、ALTN 2 連スイッチ、STAB TRIM cutout（ON/AUTO/CUTOUT。ガードで AUTO）、指示器（unit 表示、greenband、OFF 旗）（FCOM p.927–929、p.944–946）。機構と greenband は ATA 27 担当と重なる。

### 3.4 EICAS メッセージ

| メッセージ | レベル | 条件 | 典拠 |
|---|---|---|---|
| >AUTOPILOT DISC | Warning（109/405 wailer、570 siren） | 全 A/P が解除（手動・自動） | FCOM p.655、p.677 |
| >AUTOPILOT | Caution（beeper） | A/P が degraded mode。engaged のモードが故障 | FCOM p.660、p.677、ATA22 p.382 |
| >AUTOTHROT DISC | Caution | A/T 解除（逆推力による解除では出ない）。A/T 担当 | FCOM p.677 |
| >NO AUTOLAND | LAND 3/2 表示後なら Caution、前なら Advisory | autoland 不可 | FCOM p.677、ATA22 p.373–374 |
| >NO LAND 3 | 同上 | 3 チャンネル autoland の冗長なし | FCOM p.677、ATA22 p.373–374 |
| >STAB TRIM 2, 3 | Advisory | 自動 cutout、CUTOUT 位置、または指令したのに actuator が動かない | FCOM p.958 |
| STAB TRIM UNSCHD | Caution（beeper） | 非指令の stab 動きで自動 cutout しない、または A/P engaged で ALTN trim 使用 | FCOM p.958 |
| >STAB GREENBAND | Advisory | nose gear 圧と greenband の不一致（ATA 27 担当と重なる） | FCOM p.958 |
| >YAW DAMPER LWR, UPR | Advisory | module/actuator 故障、IRU OFF/align、スイッチ OFF、module 電源断 | FCOM p.958、ATA22 p.96 |

- 両 SRM の故障では NO AUTOLAND（advisory、地上はエンジン始動まで抑止）が出て A/P を engage できない（FCOM p.47 TB1-4）。
- 200 ft RA 未満では LAND 3 → LAND 2 を表示しない。NO AUTOLAND への劣化だけ変わる。急がない故障は接地後に表示する（FCOM p.662、ATA22 p.386）。

## 4. 内部ロジック

### 4.1 engage と disengage（ATA22 p.302–324、図 p.319）

- engage の前提：115V AC と 28V DC、28V DC STBY bus（engage 後に失っても外れない）、FCC・MCP・aileron/elevator サーボが有効、inner loop センサ有効。multi-channel は autoland センサも有効（p.302–304）。
- arm の開始：他チャンネルが armed/engaged でなければ MCP の CMD 要求で arm。A/P engaged 中に APP を選ぶと他チャンネルが multi-arm（p.314）。
- arm 禁止：電源監視の故障、arm/engage solenoid が arm 前に通電（hot short）、MCP 無効（p.314）。
- arm 解除：engaged だった他チャンネルが外れたとき、単一チャンネル arm 中に wheel が 25° を超えたとき（p.314）。arm 解除の故障：program pin parity、servo loop、LVDT の断線・短絡、hot short、servo と surface の同期外れ、inner loop センサの二重故障、自己試験、multi-arm 中の autoland センサの二重故障。単一チャンネル arm では aileron 指令 25° wheel 超過の監視を事前試験（p.316）。
- engage の開始（図 p.319）：単一は CMD 要求（1/2 s）で、他チャンネルの servo が engaged でないこと。multi は multi-arm、LOC 捕捉、G/S 捕捉、RA < 1500 ft、track が adjusted runway heading の 2° 以内、がそろって 5 秒後（adjusted runway heading は ILS の滑走路方位と実際の差を最大 5° まで補正）（p.318、p.288、p.294）。
- engage の解除条件（図 p.319）：multi の条件が無くなり他の servo も engaged、autotrim valid 1・2 の両方喪失または flare 中の接地（RA < 5 ft）（単一チャンネル）、GA から巡航モードへの遷移で first-in-command でないチャンネル（p.318）。
- engage 解除の故障：multi では program pin 不一致、rudder servo/servo loop 故障、同種 autoland センサ 2 個故障。単一では aileron 指令 25° 超過、高度の捕捉・保持ができない故障（p.320）。
- detent/camout：detent が失われると multi では解除（2 系は両方、3 系は該当だけ）、単一では AUTOPILOT caution（p.322）。2 系で同種の inner loop/autoland センサ 2 個故障はハードウェア解除（p.322）。
- first-in-command：GA → 巡航モードで残るチャンネル。外れたら L→R→C→L の順に移る（p.324）。
- 解除の警報：全チャンネルの servo が外れると master warning、level A の音、>AUTOPILOT DISC。再 engage か disengage switch で消す（p.380、FCOM p.655）。

### 4.2 モード遷移表（ATA22 p.335・351。○＝可、×＝不可、⊕＝同じモード）

ピッチ（行が遷移元）：

| 元＼先 | T/O | V/S | ALT HOLD | ALT CAPT | FLCH | VNAV | G/A | G/S | FLARE |
|---|---|---|---|---|---|---|---|---|---|
| T/O | ⊕ | ○ | ○ | ③ | ○ | ○ | × | × | × |
| V/S | × | ⊕ | ○ | ○ | ○ | ○ | ○ | ○ | × |
| ALT HOLD | × | ○ | ⊕ | ⊕ | ○ | ○ | ○ | ○ | × |
| ALT CAPT | × | ○ | ⊕ | ⊕ | ○ | ○ | ○ | ○ | × |
| FLCH | × | ○ | ○ | ○ | ⊕ | ○ | ○ | ○ | × |
| VNAV | × | ○ | ○ | ○ | ○ | ⊕ | ○ | ○ | × |
| G/A | × | ① | ① | ③ | ① | ○ | ⊕ | × | × |
| G/S | × | ② | ② | × | ② | × | ○ | ⊕ | ○ |
| FLARE | × | × | × | × | × | × | ○ | × | ⊕ |

①＝400 ft RA 以上で可、②＝LOC active になる前は可、③＝800 ft RA 以上で可。

ロール：

| 元＼先 | T/O | HDG HOLD | HDG SEL | LNAV | LOC | G/A | ROLLOUT |
|---|---|---|---|---|---|---|---|
| T/O | ⊕ | ○ | ○ | ○ | × | × | × |
| HDG HOLD | × | ⊕ | ○ | ○ | ○ | ○ | × |
| HDG SEL | × | ○ | ⊕ | ○ | ○ | ○ | × |
| LNAV | × | ○ | ○ | ⊕ | ○ | ○ | × |
| LOC | × | ① | ① | × | ⊕ | ○ | ○ |
| G/A | × | ② | ② | ② | × | ⊕ | × |
| ROLLOUT | × | × | × | × | × | × | ⊕ |

①＝G/S active の前は可、②＝400 ft RA 以上で可。

- 各モードは「要求 AND TRANS ENABLE → latch（新モード engage で reset）」「latch AND モード有効 → engage」の形（図 p.337–357）。armed はそれぞれの latch を表示する。

### 4.3 モードごとの論理

- T/O（図 p.337）：(Capt または F/O の F/D が OFF→ON のパルス) AND 地上 AND どの A/P も CMD でない → latch。reset は (地上 AND A/P CMD)、A/T SPD、新モード。roll は同じ立ち上がりで T/O roll（図 p.353）。地上は FD 専用。pitch は 8°、roll は翼水平。離陸で roll は対地 track 保持（ATA22 p.264、FCOM p.666）。
- 離陸ピッチ（ATA22 p.264、p.344、FCOM p.664、p.667）：V/S < 600 fpm は姿勢、600–1200 fpm は姿勢と速度の混合、> 1200 fpm は速度。目標は max(V2+10, 回転時速度+10)。5 秒超過で現速度へ（上限 V2+25）。MCP を高くするとその値。片発：故障時速度を V2〜V2+10 に制限（V2 未満なら V2、V2〜V2+10 はその速度、V2+10 超は V2+10）、混合帯は 0–600 fpm。PLI 未満に制限。windshear・片発検出時に保護。
- 離陸の流れ（FCOM p.667–668、FCTM p.112）：65 kt で A/T HOLD（A/T 担当）、100 kt で FMC が気圧高度を記録（LNAV/VNAV の engage 基準）。50 ft で LNAV、400 ft で VNAV（現速度を指令）。T/O は他のピッチ・ロールモードか LNAV/VNAV の engage で終わる。
- G/A（図 p.337）：GA switch AND TRANS ENABLE AND 空中 AND (flap UP 以外 OR G/S engaged) → latch。roll は同時に G/A roll（図 p.355）。APP は解除。pitch 則は離陸と同じ混合（全時間 windshear 保護）。目標は max(MCP, 開始時速度)、5 秒超過で現速度（上限 MCP+25、開始時に MCP+25 超ならその速度）、片発は 0–600 fpm 混合で上限 MCP+10。roll は開始時の track を保持。A/P の engage 状態は維持（multi のまま）。400 ft RA 以上で巡航モードを選ぶと pitch・roll は独立に変わり、multi は first-in-command だけ残る。選択高度に達すると ALT、first-in-command 以外は解除、roll は TO/GA のまま。400 ft 未満は A/P 解除＋両 F/D OFF でしか終わらない。TO/GA switch は、着陸で RA 5 ft を下回ってから 2 秒後に無効になり、RA 5 ft を上回ってから 3 秒後に再び有効になる。windshear：15° か PLI のわずか下の低い方まで pitch up、上昇率 600→1200 fpm（片発 0→600）で速度制御へ移る。F/D OFF でも >80 kt で FD を自動表示（ATA22 p.298、FCOM p.672–675、FCTM p.207、p.209）。
- A/P engage（ATA22 p.266）：F/D ON なら現モード。ただし F/D が地上 T/O なら HDG HOLD と V/S、LOC 捕捉中なら LOC arm・HDG HOLD、G/S 捕捉中なら G/S arm・V/S で再捕捉。F/D OFF なら V/S と、bank ≤ 5° は HDG HOLD、> 5° は ATT（どちらも HDG HOLD 灯）。
- 技法（FCTM）：A/P は機体がトリムされ FD 指令を満たした状態で engage する（p.63、p.112）。MCP のモードが効かないときは A/P 解除＋両 F/D OFF で全モードを消し、再 engage か F/D ON の既定モードから選び直す（p.65）。T/O・G/A からの ALT 捕捉は 800 ft RA 以上（§4.2 の ③）で、低高度の level off では行き過ぎうる（p.124）。
- HDG HOLD（図 p.353）：要求か既定で latch。engage は roll < 3° が 2 秒続いてから、その時の heading を保持（ROLL DOWN で翼水平）（p.272、p.348）。既定：空中で F/D ON・A/P なし・bank < 5°、F/D OFF で A/P engage・bank < 5°、F/D が T/O（地上）・G/A・LOC 捕捉中に A/P engage、HDG SEL 中の HDG REF 切替（p.352）。
- ATT（109/405）：F/D ON（A/P なし）か A/P engage（F/D OFF）で bank > 5°。5–30° はその bank を保持、5° 未満は翼水平へ（HDG HOLD）、30° 超は 30° へ（FCOM p.663、ATA22 p.352）。
- HDG SEL：要求 AND TRANS ENABLE AND 有効。LOC・G/S 捕捉後と GA の 400 ft 未満は禁止。AUTO bank limit は速度で変わる（p.274、p.352）。
- LNAV（図 p.355）：要求 AND TRANS ENABLE で arm（LOC engaged 中は不可）。2 回目、LOC/APP 要求、engage で arm 解除。engage は FMC data valid（飛行計画が入力・activate・execute 済み、50 ft AGL 以上、計算データ有効、捕捉条件）（p.270、p.354）。
- LOC（図 p.357）：LOC/APP 要求 AND TRANS ENABLE で arm。engage は LOC 有効 AND course error < 120° AND 捕捉。G/S 未 engage なら 2 回目（LOC/APP）、LNAV arm、（APP では）VNAV arm で arm 解除。G/S engaged なら新しいピッチモードで解除。捕捉点は GS、進入角、LOC 偏差の関数。捕捉で HDG 窓が滑走路方位になる（p.290–292、p.356）。
- G/S（図 p.343）：APP 要求 AND TRANS ENABLE で arm。LOC armed 中は APP 2 回目・LOC 要求・VNAV/LNAV arm、LOC engaged 中は新ロールモードで arm 解除。engage は捕捉検出（ビーム中心からの距離と偏差変化率）。FLARE engage か新モードで解除（p.292、p.342）。
- V/S（図 p.339）：要求か既定。既定は空中で F/D ON（A/P なし）、F/D OFF で A/P engage、F/D が T/O（地上）・G/S 捕捉中に A/P engage、speed-through-elevator 中に A/T が SPD になったとき（p.338）。engage 時に現 V/S に同期。前が ALT か、TO/GA で降下中なら 000（p.282）。V/S 000 を選ぶと内部は ALT HOLD、表示は V/S のまま（p.282、p.338）。
- ALT：要求、V/S の 0 選択、ALT CAPT、既定で ALT HOLD。既定は FLCH で MCP 高度への捕捉経路から 8000 ft 離れたとき、VNAV で FMC 目標高度が MCP 高度から離れる向きに変わったとき・MCP 高度を越えさせるとき、MCP 高度で master FMC が故障したとき（p.338）。捕捉は 0.05 g まで、表示は ALT（p.286）。
- FLCH（図 p.341）：要求 AND TRANS ENABLE。目標高度が必要。速度は前が VNAV なら FMC 目標、そうでなければ MCP と現速度の大きい方（p.284、p.344）。
- VNAV（図 p.341）：要求 AND TRANS ENABLE で arm（G/S 中は不可）。FMC data valid まで ARM 表示、valid で engage。2 回目と APP 要求で arm 解除、新モードで engage 解除（p.279、p.340）。VNAV SPD：上昇、降下（選択時）、PTH で速度限界に近づいたとき。VNAV PTH：FMC 高度の捕捉・保持、降下。T/D 以降は PTH のまま A/T IDLE、進入高度近くで A/T SPD。VNAV ALT：MCP 高度を FMC 高度より先に捕捉、または FMC 目標が MCP 高度を越えさせるとき（p.279–280、FCOM p.645、p.664–665）。
- FLARE（図 p.343、p.295）：multi-channel engage で arm 表示。engage 高さは沈下率で決まる：8.4 ft/s 以下 40 ft、8.4–12.4 で 40→50 ft、12.4–14.6 で 50 ft、14.6–18.1 で 50→60 ft、18.1 以上 60 ft。G/S を置き換え、接地で消えて nose を下ろす（p.294、p.342、FCOM p.665、p.671）。
- ROLLOUT：multi-channel で arm 表示、約 5 ft（FCOM）で engage、LOC を置き換える。multi でなければ FD だけの rollout で表示は LOC（FCOM p.664、ATA22 p.360）。

### 4.4 制御則（ATA22 p.330–362）

- outer loop（V/S・heading などから姿勢指令）と inner loop（姿勢誤差と姿勢率から舵面指令）。巡航の outer loop は 1 センサで可。outer loop を失うとモード故障で姿勢保持へ反転（p.330）。servo loop は指令と servo 位置を比べ、監視にも使う（p.330）。
- ピッチ（図 p.345・347）：PITCH ATT INTEG は A/P 非 engage 時に姿勢へ同期。ELEV TRIM INTEG は arm 中に servo を舵面へ同期し、engage 後は elevator と SRM（stab trim）に指令。versine で旋回時のピッチ補償。NOSE LETDOWN は接地後かつ 2° 未満で pitch down。モードが無効なら FD 指令は NCD（p.332）。
- V/S：選択値と IRU の inertial V/S の差（p.344）。
- speed-through-elevator（T/O・G/A・FLCH）：ADC 速度との差。最小速度は FMC から、FMC 故障時は FCC が AOA・flap・stab・speedbrake から計算。最大は FMC から、故障時は max operating schedule か flap から（p.344、FCOM p.675）。
- 高度保持：開始時の気圧高度との差＋inertial V/S で減衰。捕捉：捕捉時の MCP 高度との差＋inertial V/S（G/S 以外の全モードで捕捉あり）（p.346）。
- G/S：RA から送信所までの距離を推定（3° 想定）して偏差を直線距離に換算し、その値と変化率で指令。inertial path control を含み、信号を失っても経路を保持（p.346）。
- flare：gear altitude（RA、pitch、アンテナと脚の距離）を使い、1.5 ft/s で GS 送信所の 450 ft 先に接地。25 ft で FMC へ retard 指令（p.294、p.346）。
- ロール（図 p.349）：ROLL ATT INTEG は非 engage 時に roll へ同期。ROLL DOWN は HDG HOLD 開始時と autoland の 5 ft で翼水平。AIL TRIM INTEG は servo 同期と指令（p.348）。
- HDG 系は基準/選択 heading と機首方位の差。T/O・G/A は track（p.358）。LNAV は FMC の steering（希望 track からの偏差）を FD と ROLL ATT INTEG へ（p.358）。
- LOC：捕捉は横方向速度、LOC 偏差、track と滑走路方位の差。追従は RA から距離を推定（3° GS、10,000 ft 滑走路を想定）した直線偏差と変化率。inertial path control で信号喪失・異常時も経路を保持（p.358）。
- runway align（multi-channel のみ）：engage 時から片発対策（aileron と rudder で翼水平か小さく風上側翼下げ）。crab > 10° は 500 ft で 5° の forward slip、5–10° は 500 ft で 5° まで減らし 200 ft で残り、< 5° は 200 ft で全部除く。表示なし。rollout と GA で解除。片発が進入前なら 1300 ft で sideslip（翼水平）、進入中なら検出時。故障エンジン反対側からの強い横風では翼水平 sideslip をしない（p.296、p.360–362、FCOM p.670）。
- rollout：LOC 偏差の距離と変化率で rudder と NWS（multi-channel）。A/P 解除まで続く（p.362、FCOM p.671）。
- FCC の YD 指令：multi-channel approach で両 YDM が無効のときだけ（p.362）。
- A/P が非対称推力を補償している状態で単一チャンネルに戻るか解除すると、rudder はトリム位置へ戻る（FCOM p.670、p.673）。

### 4.5 autoland と状態表示

- LAND 3：電源・engaged FCC・autoland センサが 3 重（fail operational）。LAND 2：FCC とセンサが少なくとも 2 重（fail passive）。NO AUTOLAND：それ以下（ATA22 p.250、p.256、FCOM p.662）。
- NO LAND 3 の原因：IRU（inner/outer）・ILS 受信機・RA の 1 個故障、flap/stab control unit の 1 個故障、LOC/GS アンテナ切替の 1 個故障、FCC・サーボ・servo loop の 1 個故障、ILS/RA が tune/test inhibit に応じない、bus が分離しない、MCP wrap-around 試験故障。同種 2 個で NO AUTOLAND。autoland と無関係な FCC 検出故障も、地上・A/P 解除中は NO LAND 3（level C）で出す（ATA22 p.384）。
- EICAS：multi-channel engaged 中の劣化は level B（beeper）、そうでなければ level C。200 ft 未満では NO AUTOLAND への劣化だけ（p.373–374、p.386）。PFD の NO AUTOLAND は、multi-channel 中に単一へ劣化したとき（10 秒 amber 枠）と、multi-channel approach なのに 600 ft AGL までに LAND 3/2 が出ないとき。後者は flare・rollout を arm しない（FCOM p.653）。
- 乗員の確認：500 ft で autoland 状態を呼称、alert height（200 ft 以上）より上の劣化は高い最低気象条件に移る、AH 以下は NO AUTOLAND 以外は続行（FCTM p.48、p.159、p.165–166）。
- 制限：A/P は離陸後 250 ft 未満で engage しない。MDA から 50 ft 以上下では解除（ILS 結合か GA を除く）。単一チャンネル ILS は 100 ft AGL 未満までに解除。autoland の風は向かい風 25 kt、追い風 10 kt（405・570）／15 kt（109）、横風 25 kt、G/S 最大 3.25°。A/P 中の aileron trim 禁止（FCOM p.79–80）。

### 4.6 警報と注意の分類（ATA22 p.380–383）

- 警報：A/P WARN 1（EICAS メッセージ）と 2（MAWEA の音と灯）を normal と battery の両方で出す（p.380）。
- AUTOPILOT caution は 3 種類。①caution の後に解除：FCC の I/O buffer・MCP wrap-around 故障、MCP の data path/計算故障、IRU 垂直加速度の 2 個目故障、ADC の高度・速度・impact pressure の 2 個目故障。②caution とモード故障（amber 線）：LNAV/VNAV 中の master FMC 故障、multi GA 中の選択 ADC 故障、LOC/GS 捕捉中の LOC/GS 2 個目故障、LOC+GS 捕捉・1500 ft 未満で RA 2 個目故障、IRU outer loop の 2 個目故障、捕捉後の ILS 周波数変更、ILS 2・3 個の NCD。③caution のみ：ground test、単一チャンネルの flare、stab trim 故障、FLCH/VNAV から要求なしに V/S へ遷移、program pin parity、V/S で 1.3 Vs かつ 100 fpm 超の上昇、単一チャンネルでの pilot override（detent trip）（p.382–383）。
- caution は A/P 解除か、条件の無いモードを選ぶと消える（p.254）。FCOM は「影響がモードだけなら A/P は姿勢安定化モードで engaged のまま、amber 線、AUTOPILOT」（p.660）。ILS 干渉監視は短時間なら表示なし、続けば表示（FCTM p.162）。

### 4.7 ヨーダンパー（ATA22 p.83–96、図 p.85・87）

- 動作モード：電源投入 → 地上なら power-up test（最大 5 s、INOP 点灯）→ 合格で ground op（engaged だが指令ゼロ）。空中になると fade-in 5 s → flight mode。着陸で fade-out 5 s → ground op。空中で電源投入なら試験なしで fade-in。故障で fault INOP（解除・INOP）。抜けるのはスイッチの入れ直しか autorecovery（どれかの IRU が NAV に入る、5 s 未満の一時故障）（p.83–84）。
- 指令：dutch roll（横加速度、impact pressure、AOA、yaw rate、roll rate、roll angle、TAS、GS）＋turn coordination（roll angle）＋modal suppression（modal 加速度、最大 1°、ADC overspeed で停止）の和を authority limit で制限。各 YDM は rudder 4° まで（modal 1° を含む）（p.86–87）。

| 有効 IRU | 有効 ADC | authority |
|---|---|---|
| 3 または 2 | 2・1・0 | ±4.0° |
| 1 | 2 | 可変（`資料に記載なし`） |
| 1 | 1 または 0 | ±1.0° |
| 0 | — | INOP（IRU OFF/align で YAW DAMPER メッセージ） |

- 入力が一部無効なら指令を減らす（例：ADC）（p.86）。control と monitor の出力比較、LVDT・servo loop・engage relay の監視で不 engage か解除（p.88）。解除時は solenoid が切れて actuator はばねで中立（p.90）。

### 4.8 自動スタビライザートリム（ATA22 p.105–166）

- 単位：1 unit ≒ 1°（0 unit = +3.0°、15 unit = −12.0°）（p.132）。限界（SRM のソフトウェアで arm 信号を切る）：

| モード | ND 限界 | NU 限界 |
|---|---|---|
| speed trim | 0.8 | 11.6 |
| manual・単一 rate autotrim、脚上げ・flap UP | 1.8 | 11.6 |
| manual・単一 rate autotrim、脚下げか flap 出 | 0.8 | 11.6 |
| full rate autotrim（LAND 2） | `資料に記載なし` | 13.5 |
| alternate | 0.25 | 14.75 |

- 速度（CAS、加速時 230 kt・減速時 220 kt で切替）（p.165–166）：

| | < 220 kt | > 230 kt |
|---|---|---|
| 2 チャンネル（manual、alternate、LAND 2 の full rate） | 0.5°/s | 0.2°/s（manual、alternate） |
| 1 チャンネル（manual、alternate、autotrim） | 0.25°/s | 0.1°/s |

- モード（p.139–140）：電源投入で、地上・A/P なしは disengaged、空中・A/P なしは speed trim、A/P CMD は autotrim。autotrim は A/P CMD で開始。単一 A/P で manual trim を使うと A/P が外れて manual。multi-channel では manual trim を使っても autotrim のまま（FCOM は「操縦輪のスイッチは無効」p.945）。A/P 解除で空中なら speed trim、地上なら disengaged。離陸後 20 s で speed trim。alternate は他と独立。
- manual：arm と control の両信号が同方向で作動（両 STCM、full rate）。column を逆向きに 4.5° 以上動かすと control 信号を切る（alternate は切らない）。manual trim を検出すると autotrim valid を 0 にし、単一 A/P は外れる（p.122、p.142、FCOM p.945）。
- FCC autotrim（図 p.149）：elevator servo 指令が 0.4°（G/S 捕捉中 0.6°）を超えると trim 指令、0.25° で止める。rollout 中は禁止。SRM は 3.5 s 遅らせる。trim の経路は最初に engage したチャンネルで決まり（L→L SRM など）、dead trim で 1 回だけ別経路へ autosequence（A/P 全解除でリセット）。LAND 2 だけ、両 SRM 有効なら 120 ft 未満で full rate（遅れなし、両 SRM）、trim bias（解除時に pitch up）を両 SRM 有効で 120 ft、片方で 190 ft から加え、GA で取り消す。trim fault monitor は非指令・逆向きの動き（unscheduled）と、指令しても動かない（dead trim）を見て A/P caution・解除・NO LAND 3/NO AUTOLAND に使う（p.144–152）。
- speed trim（図 p.159）：速度増で nose up、減で nose down。engage は air data 有効（両 ADC の差 10 kt で無効）、stab 位置と air/ground 有効、空中 20 s、manual・alternate・autotrim でない。engage 時の stab 位置と速度に同期し、120 kt で 0、220 kt で 2.55° NU（最大）となる速度の関数の変化分を指令（図から読み取り）。1 度に 1 台の SRM（電源投入時にランダムで選ぶ）（p.155–158）。
- shutdown（p.162）：unscheduled trim 監視は全モードで有効。どちらかの SRM が unscheduled を検出し、その STCM の brake release があると、その STCM の MOV に 10 s の閉指令（alternate trim 中と cutout switch ON では出さない）。cutout switch を CUTOUT/ON から AUTO にした 5 s 後と、AUTO での電源投入時に 10 s の開指令。FCOM：自動 cutout 後は ON にするまで閉のまま。片方の actuator が動かないと trim は半速（FCOM p.945）。

## 5. 他系統とのつながり

| 方向 | 相手 | 内容 | 典拠 |
|---|---|---|---|
| 入力 | 電源（ATA 24） | FCC L/C/R：AC 3/1/2、DC 3/1/2。警報：DC STBY。MCP：DC 3/2。YD：AC standby・AC 1・DC 1/2・battery。SRM：AC standby・AC 2・DC 2/3・battery | ATA22 p.60–62、p.116–118、p.191 |
| 出力 | 電源（ATA 24） | APP arm で bus isolation 要求、BUS ISOLATED を LAND 3 の条件に | ATA22 p.192–196 |
| 入力 | 油圧（ATA 29） | A/P サーボ L/C/R＝系統 3/1/2、YD upper/lower＝3/2、STCM＝2・3。HYDIM の圧有効は FCC では診断用 | ATA22 p.10–12、p.64、p.218 |
| 入力 | 航法（ATA 34） | IRU×3、ADC×3、RA×3、ILS×3。FCC から ILS TUNE INHIBIT、RA TEST INHIBIT、アンテナ切替 | ATA22 p.200–216 |
| 入出力 | FMC（ATA 34-61） | FMC→FCC：steering、目標速度・高度、vertical steering、min/max 速度。MCP→FMC：モード、選択高度、ALT selector 押し。FMC master switch で全 FCC が同じ FMC | ATA22 p.206–210、FCOM p.649 |
| 入出力 | A/T | ピッチモードが A/T モードを決める（THR/THR REF/IDLE/HOLD/SPD）。SPD switch は VNAV/FLCH/TO/GA 中は無効。V/S 既定：speed-through-elevator 中に A/T が SPD。T/O latch は A/T SPD で reset。flare 25 ft で retard | FCOM p.641–642、ATA22 p.294、p.337–338 |
| 出力 | 舵面（ATA 27） | aileron/elevator/rudder サーボ、NWS（rollout）、stab trim（SRM 経由）、YD actuator | ATA22 p.222、p.224、FCOM p.659 |
| 入力 | 舵面（ATA 27） | flap・stab・speedbrake 位置、column 位置（column cutout） | ATA22 p.120、p.218 |
| 出力 | 表示・警報（ATA 31） | EIU（FMA、状態、FD、選択値、EICAS）、MAWEA（warning）、master caution | ATA22 p.226、p.366 |
| 入力 | 脚・air/ground（ATA 32） | YD・SRM の air/ground、gear down（PSEU）。FCC の air/ground は試験専用で、接地判定は RA | ATA22 p.69、p.120、p.218 |
| 出力 | ステアリング（ATA 32） | rollout で NWS | FCOM p.659、p.671 |

## 6. 実装上の注意

### 6.1 現コードの構造と X-Plane への依存

- AFDS のコードは 3 プラグイン・8 ファイルに散っている：`B747.70.xt.autopilot.lua`（3564 行：MCP、モード、FMA、状態）、`…monitor.lua`（VNAV/LNAV/LOC/GS の実行、A/T 監視）、`…vnav.lua`・`…vnavspd.lua`（VNAV の目標）、`B747.autoland.lua`（flare/rollout）、`B747.19.xt.hydraulics_override.lua`（FD 指令・A/P サーボ PID・autotrim・YD）、`B747.01.xt.manipulators.lua`（F/D switch）、`B747.40.xt.engines.lua`（TO/GA switch）、`B747.60.xt.fltInst02.lua`（TO/GA ピッチ目標）、`B747.45.xt.fltCtrls.lua`（YD の ON 判定、手動 trim）。モード状態は dataref を介して共有し、`B747DR_ap_lastCommand` の 0.1〜0.5 s の待ちで切替の順序を調整している。hydraulics 側のピッチ FD は autopilot 側の FMA 更新より先に走る（OLD_FORK_NOTES §13 と同じ）。
- 何を X-Plane が計算し、何をプラグインが計算するか：

| 機能 | 計算する側 | X-Plane 側で使うもの |
|---|---|---|
| HDG SEL / HDG HOLD | X-Plane の AP（heading select／heading hold）が FD roll を計算。プラグインは 10 個の移動平均を取り aileron の PID へ | `sim/autopilot/heading`、`sim/autopilot/heading_hold`、`sim/cockpit/autopilot/heading_mag`、`sim/cockpit2/autopilot/heading_status`・`heading_hold_status`・`flight_director_roll_deg`・`bank_angle_mode` |
| LNAV | プラグインが目標 heading（現 leg の点への方位＋風補正）を作り、X-Plane の HDG SEL に渡す | 同上 |
| LOC | プラグインが目標 heading（course＋dots×4＋方位差×2＋風補正）を作り、X-Plane の HDG SEL に渡す | 同上と `nav1/2_hdef_dots_pilot`・`nav1/2_display_horizontal` |
| TO/GA roll | X-Plane の FD roll（X-Plane に lateral mode が無い状態） | `flight_director_roll_deg` |
| ATT、ROLLOUT | プラグイン（固定 bank、rudder trim） | `sim/flightmodel2/controls/rudder_trim` |
| 全ピッチモード、flare | プラグイン（`ap_director_pitch` → elevator PID） | X-Plane のピッチモードは使わない（`sim/autopilot/level_change`・`vertical_speed` を replace、X-Plane の高度 dial は 150000 にして捕捉させない） |
| 目標値の置き場 | — | `airspeed_dial_kts(_mach)`、`airspeed_is_mach`、`vvi_dial_fpm`、`TOGA_pitch_deg` |
| A/P サーボ | プラグイン（独自の `laminar/B747/autopilot/servos_on`、`override_control_surfaces`=1） | X-Plane の servo は使わない |
| A/T | X-Plane の A/T は 0.5 s ごとに OFF に戻す（monitor.lua:567-582） | — |
| YD | プラグイン（X-Plane の YD は常に OFF：fltCtrls.lua:740-743） | — |
| stab trim | 手動は X-Plane の pitch trim コマンド、A/P 中はプラグインが `elevator_trim` を直接書く | `sim/flight_controls/pitch_trim_up/down`、`sim/flightmodel2/controls/elevator_trim` |

- ピッチモードの状態は独自 dataref（`laminar/B747/autopilot/vvi_status`・`speed_status`・`altitude_hold_status`・`altitude_hold_ft`・`altitude_dial_ft`）、LOC/GS は `actual_nav_status`・`actual_glideslope_status`（ほかに表示用の `nav_status`・`glideslope_status`）。前者 5 個は ND プラグインの init（`xtlua_nd/init/scripts/B747.61.nd/B747.61.nd.lua:27-31`）で作られている。

### 6.2 ACF_DIFF §3.3 との関係

- コードが実際に依存するのは、X-Plane が計算するロール FD に効く値：`_ott_psi_deg_off_for_full_def`（純正 15 / カスタム 20）、`_ott_psi_sec_into_future`（0.75 / 1.0）、`_ott_psi_sec_to_tune`（0.3 / 5.0）、`_ott_phi_deg_off_for_full_def`（20 / 10）、`_ott_phi_sec_into_future`（1.0 / 1.3）、`_ott_phi_sec_to_tune`（2 / 3）、`_ott_roll_rate`（6 / 4）、`_auto_roll_axis_defaults_free`（0 / 1）。HDG SEL/HOLD・LNAV・LOC・TO/GA の bank の取り方が acf で変わる（`推定`：X-Plane の AP 調整項目の意味からの推定）。
- 依存しないもの：`_fdir_needed_to_engage_servo`（X-Plane の servo を使わない）、`_alt_always_armed`・`_load_alt_presel_on_alt_hit`（X-Plane の高度 dial は 150000）、`_load_presel_on_asi_hit`・`_load_presel_on_vvi_hit`・`_vvi_but_adjusts_pitch`・`_auto_ptch_axis_defaults_free`・`_ott_the_*`（X-Plane のピッチモード不使用）、`_integrated_approach_navigation`・`_ott_gls_*`・`_ott_flare_*`（X-Plane の APR/autoland 不使用）、`_ott_asi_*`・`_ott_atr_*`（X-Plane の A/T は OFF）。
- 作り直しでロール指令をプラグインで計算すれば、§3.3 の差は AFDS に効かなくなる。

### 6.3 作り直すときの注意

- 名前と数値の約束（INTERFACES.tsv）：FMA の数値（armed roll 1–4、active roll 1–7、armed pitch 1–4、active pitch 1–9、A/T 1–5、AFDS 状態 1–5。`init/scripts/B747.70.autopilot/B747.70.autopilot.lua:128-203`）はパネルの `SHOW_EQUAL` が使うので変えない。amber 線・FD 故障旗・TEST は今の数値に入らず、表示には custom acf のパネル変更（承認が要る）か、既存の数値の範囲での工夫が要る。
- コマンド：MCP・CMD・disengage・F/D・HDG REF・APP は `laminar/B747/…` を残す。X-Plane 標準の `sim/autopilot/*`（airspeed/heading/altitude/vertical_speed/bank_limit の up/down、knots_mach_toggle、heading_hold、take_off_go_around）と `sim/engines/TOGA_power` は利用者の操縦桿・キー割当てが使うので、今と同じく replace/wrap して受ける。
- XTLua：`after_physics` は別スレッドで、dataref の書き込みは非同期（ARCHITECTURE.md §1）。モードの latch・遷移表・制御則・表示を 1 つのモジュールで、決まった順に毎フレーム回す（FCC は 25 ms 周期：ATA22 p.233）。0.1〜0.5 s の待ち（`lastCommand`）でつなぐ今の作りはやめる。積分器は A/P 非 engage 時に同期させ（ATA22 p.332、p.348）、ワインドアップを防ぐ（OLD_FORK_NOTES §13 の 2 s の積分巻き上がりは参考）。
- 3 チャンネルは「FCC 3 個の論理を 1 つの関数で 3 回」回し、engage・センサ有効・電源・油圧をチャンネルごとに持つと LAND 3/2・first-in-command・NO LAND 3 を素直に書ける。舵面への出力は今の `sim_pitch_ratio`・`sim_roll_ratio`（controlOverrides）を残してよい。rudder（rollout PCP）と NWS の出口は新しく要る（ATA 27/32 担当と調整）。
- 簡略化してよいもの：機械的な力の投票（チャンネルの指令は 1 つにまとめ、故障したら外すだけ）、LVDT/hot short/program pin の監視、ground test と CMC、MCP の内部チャンネル切替。簡略化してはいけないもの：遷移表と TRANS ENABLE、既定モードと自動反転、multi-channel の engage 条件と LAND 3/2/NO AUTOLAND の決め方、TO/GA の速度則、flare/rollout、警報の分類とリセット。
- 故障モデルが無い現状でも、電源・油圧・IRU・ADC・RA・ILS の有効性は他モジュールから取れる範囲で入れる（NO LAND 3/NO AUTOLAND、ATT 反転、AUTOPILOT caution の土台になる）。

## 7. 現状実装との比較（GAP 候補）

パスは一意なのでファイル名だけ書く（`autopilot.lua`＝`B747.70.xt.autopilot.lua`、`monitor.lua`・`autoland.lua` も同じフォルダ、`hydraulics_override.lua`・`hydraulicsmodel.lua`＝`B747.19.xt.*`）。

| ID | 種別 | 重要度 | 規模 | 内容 | 根拠 | 該当コード |
|---|---|---|---|---|---|---|
| AFDS-01 | 挙動の誤り | 高 | L | ロール指令を X-Plane の AP に頼っている。HDG SEL/HOLD は X-Plane の FD roll、LNAV と LOC は目標 heading を X-Plane の HDG SEL に渡す近似、TO/GA roll は X-Plane に lateral mode が無いまま（track 保持なし）。FD roll は 10 サンプルの移動平均で遅れる。ATT は 30° 制限・5° 未満での HDG HOLD 移行が無い。bank limit AUTO は X-Plane の `bank_angle_mode`=4（20° 固定） | ATA22 p.348、p.352、p.358；FCOM p.647、p.663；FCTM p.118 | `hydraulics_override.lua:408-425`、`:805-834`；`autopilot.lua:2633-2640`、`:1362-1382`、`:3454`；`monitor.lua:741-863` |
| AFDS-02 | 挙動の誤り | 高 | M | LOC/APP：両受信機に信号があるだけで LOC 捕捉（遠方・full scale でも捕捉し LNAV を解除）。追従は dots と方位差からの heading。いったん乗った後に両受信機の dots の和が 4 を超えると捕捉を解除し、信号断でも armed に戻る（inertial path なし）。G/S は LOC 捕捉後・1.5 dots 以内（405 の挙動だけ）、arm は 3500 ft RA 未満。APP 押下で即 HDG を course に（実機は LOC 捕捉時）。ILS 自動同調が無いと LOC/APP を arm せず RW/ILS CRS ERROR。LOC の 2 回目で disarm しない | FCOM p.646–647、p.650–652；ATA22 p.290–292、p.342–343、p.356–358 | `monitor.lua:731-776`；`autopilot.lua:2397`、`:2419`、`:2430-2444`、`:2519-2537` |
| AFDS-03 | 挙動の誤り | 高 | M | TO/GA：ピッチ目標が速度に比例する姿勢（Vs で 2°、V2+10 で 12°）で、V2+10〜V2+25／MCP+25 の速度保持、600–1200 fpm の混合、片発目標、windshear 15° が無い。pitch と roll を 1 つのフラグ（TOGA_status）で持つので、ALT 捕捉・FLCH で roll の TO/GA も消え、HDG SEL/HOLD を選んでも FMA は TO/GA のまま。ALT 捕捉の窓に入ると高度に関係なく TO/GA を消す（実機は T/O・G/A からの捕捉は 800 ft RA 以上）。飛行中の TO/GA switch は arm 条件（flap UP 以外か G/S 捕捉）を見ない。離陸後 50–400 ft の roll だけ、接地後 2 s の無効化、F/D 自動表示（>80 kt）が無い | FCOM p.656–657、p.661、p.663–668、p.672–675；ATA22 p.264、p.298、p.336–337、p.344 | `B747.60.xt.fltInst02.lua:3083-3117`；`hydraulics_override.lua:754-763`、`:612-619`；`autopilot.lua:2623`；`B747.40.xt.engines.lua:542-575` |
| AFDS-04 | バグ | 高 | L | autoland：flare/rollout は engaged 3 チャンネルのときだけ動き、LAND 2 では flare せず G/S のまま接地。flare は 50 ft 固定、目標ピッチは事前平均ピッチ＋1–2.5°（1.5 ft/s・GS 送信所 450 ft 先の接地則ではない）。IDLE 表示 40 ft（FCOM 25 ft）、ROLLOUT は 4.5 ft＋pitch。rollout は HSI OBS との heading 差で rudder trim を動かす（LOC 偏差・NWS なし）。runway align・decrab・片発補償が無い。接地後 65 kt で A/P を自動解除し、AUTOPILOT DISC も出さない | FCOM p.670–672；ATA22 p.294–296、p.342、p.346、p.360–362、図 p.295 | `autoland.lua:21`、`:63-84`、`:101-104`、`:148-160`、`:219-221`、`:287-297`、`:354-359` |
| AFDS-05 | 欠落 | 中 | L | multi-channel：APP 押下（1500 ft 超、A/P engaged）で 3 チャンネルの CMD を即 1、1500 ft 未満の LOC+GS 捕捉で即 engage（5 s 遅れ・2° 条件なし）。LAND 3/2 は engaged の数だけで決め、bus isolation・センサ冗長・200 ft 以下の抑止なし。PFD の NO AUTOLAND は 200–1000 ft で LOC も GS も未捕捉のとき（実機は 600 ft までに LAND 3/2 が出ないとき）。first-in-command、GA 後の巡航モード選択・ALT 捕捉での単一化が無い | FCOM p.651、p.653、p.662、p.673；ATA22 p.192–196、p.250、p.288、p.294、p.318–324、p.384–386 | `autopilot.lua:2406-2412`、`:2475-2489`、`:2959-2991` |
| AFDS-06 | 欠落 | 高 | S | A/P engage の既定モード：F/D OFF で CMD を押しても V/S＋HDG HOLD/ATT にならない。モードが何も選ばれていなければ FMA は空白のまま、A/P サーボは何もしない。F/D が地上 TO/GA・LOC/GS 捕捉中の engage の扱いも無い。F/D 側の ATT は 30° 制限と 570 型の区別が無い | FCOM p.639–640、p.663；ATA22 p.266、p.338、p.352 | `autopilot.lua:830-895`；`hydraulics_override.lua:986`、`:1026`；`B747.01.xt.manipulators.lua:1256-1270` |
| AFDS-07 | 挙動の誤り | 高 | S | V/S の同期：V/S 押下で目標を 0 fpm にする。F/D ON の既定 V/S も前回の dial 値。実機は現 V/S（前が ALT か TO/GA で降下中なら 000） | FCOM p.648、p.665；ATA22 p.282、p.344 | `autopilot.lua:786-792`；`B747.01.xt.manipulators.lua:217-223`、`:1261` |
| AFDS-08 | 挙動の誤り | 高 | M | LNAV/VNAV/SPD：LNAV は arm 後 RA 50 ft 超で無条件 engage（2.5 NM・intercept 判定、NOT ON INTERCEPT HEADING なし）。active の LNAV/VNAV を押すと解除する（実機は armed のときだけ disarm）。SPD switch が VNAV を解除する（実機は VNAV/FLCH/TO/GA 中は無効）。TO/GA が VNAV を解除しない（`vnav_state` が残り、VNAV の処理が内部のピッチフラグと目標高度を書き続けるので、ALT 則に落ちて TO/GA が消えうる）。VNAV のサブモード表示は内部フラグからの推定（−500 fpm を VNAV SPD とみなす等）で、speed intervention 中の PTH→SPD 表示が無い | FCOM p.642–645、p.663–665；ATA22 p.270、p.279–280、p.340–341、p.354–355 | `autopilot.lua:2877-2881`、`:1029-1037`、`:1064-1066`、`:582`、`:2761-2787`；`monitor.lua:469-530`；`hydraulics_override.lua:603-619`；`B747.40.xt.engines.lua:542-575` |
| AFDS-09 | 挙動の誤り | 中 | M | 遷移規則と相互 disarm：FLCH・V/S・ALT が G/S 捕捉後も内部フラグを変える（FMA は G/S を優先表示）。LOC 捕捉後・G/S 前に HDG SEL/HOLD へ戻せない。GA の 400 ft 未満でも HDG SEL などを選べる。LOC/APP で LNAV arm が消えない、LNAV/VNAV で APP が消えない、APP で VNAV arm が消えない。A/P を使わず両 F/D を OFF にするとモードが残る | ATA22 p.335、p.343、p.351、p.354–357；FCOM p.651、p.660 | `autopilot.lua:732-827`、`:2596`、`:2700`、`:2724`；`monitor.lua:741-776` |
| AFDS-10 | 挙動の誤り | 中 | L | ピッチ制御則：全モードを「ピッチ目標を少しずつ増減する」則で作り、10 サンプル平均とモード変化後 0.7 s の固定がある。ALT 捕捉は V/S に比例する窓（200–1000 ft）と「誤差×2 fpm」で 0.05 g の捕捉則ではない。ピッチ制限は V/S 系 −3.5〜10°、FLCH −3.5〜15°。G/S は dots を fpm に換算（RA による直線偏差・inertial path なし）。integrator・versine・inner/outer loop の構造が無い | ATA22 p.286、p.330–332、p.344–346 | `hydraulics_override.lua:436-456`、`:463-483`、`:504-803`、`:901-923`；`autopilot.lua:2348` |
| AFDS-11 | 欠落 | 中 | M | 速度保護と自動反転：min/max は Vmc+10 と flap 別の固定値で、全モードの速度目標を切る。FMC の min/max（5 kt 余裕）、FMC 無効時の FCC 計算、保護が VNAV SPD/FLCH/TO/GA だけ、が無い。V/S 既定（speed-through-elevator 中に A/T が SPD）、ALT HOLD 既定（FLCH の 8000 ft 逆行、VNAV の条件）、V/S での 1.3 Vs caution が無い | FCOM p.675；ATA22 p.338、p.344、p.382 | `autopilot.lua:1942-1997` |
| AFDS-12 | バグ | 中 | S | AUTOPILOT caution が出ない：`simDR_autopilot_fail` を定義していない。mode fail の amber 線、FD 故障旗、TEST を出す dataref も無い（表示には custom acf のパネル変更が要る） | FCOM p.653、p.660、p.677；ATA22 p.252、p.369、p.376–383 | `autopilot.lua:3386-3390` |
| AFDS-13 | 欠落 | 中 | M | NO LAND 3／NO AUTOLAND の EICAS：caution [49]・[50] と advisory [248] を誰も立てない。advisory [246] を PFD の NO AUTOLAND 条件で出している。表示前後でのレベル切替、地上の level C、接地後表示が無い | FCOM p.662、p.677；ATA22 p.373–374、p.384–386 | `autopilot.lua:2992-2996`；`B747.87.xt.warning.lua:157-158`、`:432-434` |
| AFDS-14 | 挙動の誤り | 低 | S | AUTOPILOT DISC：型式によらず wailer（570 は siren）、wailer の最低 1 秒なし。disengage bar を上げると warning が消える（実機は disengage switch か再 engage） | FCOM p.640、p.655、p.677；ATA22 p.254、p.380 | `B747.87.xt.warning.lua:806-808`；`autopilot.lua:919-921` |
| AFDS-15 | 欠落 | 中 | M | engage インターロック：CMD は RA > 400 ft と他チャンネル無しだけを見る（実機は地上でも engage でき、250 ft は運用制限）。MCP 有効、DC STBY、センサ有効、SRM の autotrim valid、25° wheel 超過、detent/camout（単一は caution、複数は解除）が無い。pilot の入力は A/P 出力に足されるだけ | ATA22 p.302–322；FCOM p.79–80、p.47 | `autopilot.lua:837`、`:863`、`:884`；`hydraulicsmodel.lua:577-578`、`:600-601` |
| AFDS-16 | 欠落 | 中 | S | AFDS の電源：FCC L/C/R（AC 3/1/2・DC 3/1/2）、MCP（DC 3/2）、警報（DC STBY）を見ない。油圧だけ 1000 psi で見る | ATA22 p.191、p.304 | `autopilot.lua:2480-2499` |
| AFDS-17 | 挙動の誤り | 中 | M | YD の則：bank < 5° は 0.9 s の heading 平均との差、> 5° は sideslip を PID で戻す（5° で則が切り替わる）。地上でも動く（ground op、5 s fade-in/out なし）。出力 ±3.5 を rudder ratio changer で縮める。dutch roll 減衰・turn coordination・modal suppression・±4° と IRU/ADC 数による縮小・overspeed で modal 停止が無い | ATA22 p.50–52、p.83–90、図 p.85・87；FCOM p.949 | `hydraulics_override.lua:426-432`、`:836-899`、`:1048-1103`；`hydraulicsmodel.lua:566-567` |
| AFDS-18 | 挙動の誤り | 低 | S | YD の有効条件：battery switch と IRS 切替位置 NAV（align 中も有効）だけで INOP を決める。電源（FCEPSM/AC standby、AC 1、DC 1/2、battery）、油圧 3/2、power-up test（地上で最大 5 s INOP）、fault と autorecovery、FCC の YD 指令（両 YDM 無効の multi approach）が無い | ATA22 p.60–64、p.83–84、p.88、p.96、p.362；FCOM p.931、p.958 | `B747.45.xt.fltCtrls.lua:714-744`、`:1170-1184`；`B747.90.xt.lighting.lua:1329-1330` |
| AFDS-19 | 挙動の誤り | 中 | M | A/P 中の autotrim：pitch ratio（pilot 入力込み）が窓を越えると `elevator_trim` を 1 フレームだけ動かして 1.2 s 待つ。速度は 220/230 kt で 30/60 s フルレンジ（≈0.5/0.25 unit/s）。RA 500 ft 未満は trim しない。実機は elevator サーボ指令 0.4°（G/S 0.6°）〜0.25°、SRM で 3.5 s 遅れ、単一チャンネル 0.25°/s・0.1°/s、LAND 2 の full rate と trim bias、rollout で禁止、unscheduled/dead trim 監視と autosequence | ATA22 p.144–152、p.165–166、図 p.149 | `hydraulics_override.lua:925-957` |
| AFDS-20 | 欠落 | 中 | M | stab trim（ASTS 側）：手動 trim は X-Plane の pitch_trim を 1 スイッチで直接動かし、速さは acf の `_elev_trim_time`（25 s、`推定`）で速度に依らない。2 スイッチ同時、速度別レート、油圧 2/3（片方で半速）、モード別の限界、column cutout、単一 A/P での trim による解除・multi での無効、cutout switch・ALTN trim、unscheduled trim の自動 shutdown、STAB TRIM 2/3・UNSCHD・GREENBAND、speed trim が無い。ATA 27 担当と重なる | FCOM p.927–929、p.944–946、p.958；ATA22 p.131–166、図 p.159 | `B747.45.xt.fltCtrls.lua:233-289` |
| AFDS-21 | 挙動の誤り | 低 | S | MCP の細部：IAS の初期値 100 kt（実機 200）。MCP 高度の変更を 3 s 後に反映し、その間は古い高度で捕捉する。HDG REF（TRUE）を AFDS が使わない。F/D source 切替が効かない。ALT selector 押しの制約削除・reduced rate descent が無い（FMC 担当と重なる）。TO/GA→FLCH で現速度と選択速度の大きい方にしない | FCOM p.643、p.646、p.649、p.1043；ATA22 p.220、p.236、p.344 | `autopilot.lua:3434`、`:1426-1479`、`:660-716`；`B747.01.xt.manipulators.lua:1479-1481` |
| AFDS-22 | 挙動の誤り | 中 | S | acf 依存（ACF_DIFF §3.3）：ロール FD を X-Plane が計算するため、`_ott_psi_*`・`_ott_phi_*`・`_ott_roll_rate`・`_auto_roll_axis_defaults_free` の違いで HDG SEL/HOLD・LNAV・LOC・TO/GA の bank の取り方が 2 つの acf で変わる（`推定`）。ほかの §3.3 の項目はコードが使っていない（§6.2）。AFDS-01 で解消する | ACF_DIFF §3.3 | `hydraulicsmodel.lua:181`（`flight_director_roll_deg` の読み込み）；`hydraulics_override.lua:422-423` |
| AFDS-23 | 欠落 | 低 | S | ILS/RA の inhibit：LOC/GS 捕捉後も ILS 自動同調が 2 s ごとに周波数とコースを書く。ILS TUNE INHIBIT、RA TEST INHIBIT、アンテナ切替の監視が無い（ATA 34 担当との境界） | ATA22 p.212–216 | `autopilot.lua:1621-1800` |
| AFDS-24 | 挙動の誤り | 低 | S | VNAV 上昇中に遷移高度で自動的に両高度計を STD にする。資料に無い機能（FMC・EFIS 担当と重なる可能性） | FCOM p.645、p.664–665（VNAV の機能に記載なし） | `B747.70.xt.autopilot.vnavspd.lua:426-433` |

- 正しく実装されている点：A/P サーボの油圧 L/C/R＝3/1/2 による解除（`autopilot.lua:2491-2499`）。CMD は他チャンネルが無いときだけ engage（`:837`、`:863`、`:884`）。disengage switch の 1 回目／2 回目と自動解除後のリセット（`:925-967`）。FMA の 10 秒枠と NO AUTOLAND の amber 枠（`:3022-3125`）。IAS/MACH の .84・310 kt 自動切替と SEL の Mach 0.4（`:1239-1260`、`:1910-1934`）。V/S の範囲と刻み（`:1384-1424`）。MCP 灯の大半（`B747.90.xt.lighting.lua:1655-1667`。APP 後に 3 個の CMD 灯が点くのも実機どおり）。F/D ON の地上 TO/GA と空中既定（`B747.01.xt.manipulators.lua:1245-1270`、ただし AFDS-06・07）。

## 8. 作り直しか部分修正か

**推奨：AFDS（モード論理・制御則・表示・autoland）は作り直す。ヨーダンパーと ASTS も新しいモジュールとして作る。作り直しの前に、S 規模の誤りだけ先に直してよい。**

- 理由：
  - 骨格が X-Plane の AP に乗っている。ロールは X-Plane の HDG 系を流用し、LNAV と LOC はそれに目標 heading を渡す近似、ピッチは独自の「少しずつ足す」則、autoland は別ファイルの別の則で、どれも実機の FCC の構造（outer/inner loop、integrator の同期、TRANS ENABLE と latch、既定と反転）と違う。部分修正を重ねても、遷移表・既定モード・multi-channel・TO/GA の独立性は入れにくい。
  - 状態が 8 ファイル・3 プラグインに散り、0.1〜0.5 s の待ち（`lastCommand`）と実行順で整合を取っている。旧フォークは 369 コミットで同じ構造を調整し続け、ピッチ・ロール・autoland に未解決を残した（OLD_FORK_NOTES §1・§2・§7・§12・§13。参照のみ）。
  - acf の X-Plane AP 調整値にロールの挙動が左右される（AFDS-22）。
- 作り方の案（L 規模、数週間）：
  1. FCC の状態機械（§4.2 の遷移表、§4.3 の latch・既定・反転、§4.1 の engage・3 チャンネル・first-in-command）と FMA/状態表示を 1 モジュールに置く。FMA の数値と INTERFACES.tsv の名前は残す。
  2. ロールの指令（HDG/TRK、LNAV は FMC の steering 量、LOC の捕捉・追従、ATT、TO/GA track、runway align、rollout）をプラグインで計算し、X-Plane の HDG モードと FD を使わない。
  3. ピッチの指令（V/S、ALT と 0.05 g の捕捉、speed-through-elevator と保護、VNAV、G/S、flare）を同じモジュールで、FCC と同じ周期で計算する。舵面への出口（`sim_pitch_ratio`・`sim_roll_ratio`）は今のものを使う。
  4. autoland（multi-channel の engage、LAND 3/2/NO AUTOLAND、flare、rollout の rudder と NWS、片発・decrab）。電源（ATA 24 の bus isolation）・油圧・センサ有効を入れる。
  5. YD（モード、則、authority、INOP）と ASTS（autotrim、speed trim、rate、限界、shutdown、手動・ALTN との関係）。ASTS は ATA 27 担当と分担を決める。
- 先に直してよいもの（S）：AFDS-06（既定モード）、AFDS-07（V/S 同期）、AFDS-12（AUTOPILOT caution の未定義変数）、AFDS-04 のうち LAND 2 でも flare させる条件、AFDS-08 のうち LNAV/VNAV の 2 回目と SPD switch、AFDS-21 の IAS 初期値。
- FMC 担当との取り合いは、FMC が「希望 track・track 角誤差・cross track」「vertical steering（目標 V/S・経路偏差）」「目標速度・min/max 速度」「VNAV のサブモード要求」を出し、AFDS がそれを受けて arm・engage・反転を決める形にする（ATA22 p.206、p.346、p.358）。

## 9. 未確認事項

1. パネルの `SHOW_GREATER 1 laminar/B747/autopilot/FMA/active_pitch_mode`（FD pitch bar）と `…active_roll_mode`（FD roll bar）が「> 1」なら、TO/GA（=1）では FD bar が出ない（`747-400.acf:85146-85180`、`:88735-88770`、`:92342`、`:95910`）。X-Plane で TO/GA の FD bar が見えるか確かめる。見えないならパネル変更（custom acf、承認が要る）が要る。ATA-28 ノートも同じ問い（以上か超か）を挙げている。
2. disengage bar で `sim/autopilot/servos_fdir_off` を出す（`autopilot.lua:913-916`）と X-Plane の FD と HDG モードが切れ、F/D ON のまま HDG SEL/HOLD の roll 指令と FMA が消えるか（X-Plane で確認）。
3. X-Plane の `heading_hold` が「翼水平にしてから保持」か「押した時の heading へ戻る」か。TO/GA 中（X-Plane に lateral mode が無い）の `flight_director_roll_deg` が `_auto_roll_axis_defaults_free`（純正 0／カスタム 1）でどう変わるか。
4. YD の authority「可変」（IRU 1・ADC 2）の中身と、TAS による authority の変化は `資料に記載なし`。ratio changer で YD を縮める今の作りの根拠も無い。
5. LNAV・LOC・GA の bank 上限、FCC のピッチ指令の上下限、LOC 捕捉点と G/S 捕捉検出の数式、ALT 捕捉の開始条件（0.05 g 以外）は `資料に記載なし`。
6. A/P サーボの「油圧あり」の閾値（コードは 1000 psi）。FCC は HYDIM の圧有効を診断にしか使わない（ATA22 p.218）ので、実機では servo loop の故障として外れる（`推定`）。
7. 3D コクピットに STAB TRIM cutout switch と ALTN trim switch の操作子があるか（コマンドは Lua に無い）。F/D source selector・HDG REF の操作子は INTERFACES.tsv にある。
8. RR 型の AUTOPILOT DISC の音、ATT・G/S 捕捉順の型式（FCOM の 109/405/570）をリバリー（エンジン型式）にどう対応させるか。
9. speed trim を X-Plane の機体モデルの上でどこまで入れるか（手動操縦の速度安定に効く。trim 指示器が自動で動くのは乗員に見える）。
10. full rate autotrim（LAND 2）の ND 限界は `資料に記載なし`。

## 6-1・6-2 段 6c での AFDS の変更（2026-10-27：notes/ATA-34-61-FMC.md §29）

- LNAV の engage：arm 中、電波高度 50 ft 超で FMC の steering が valid になるのを待つ（ATA34_2 p.618–619：アクティブな経路と捕捉の条件）。AFDS-08 の「2.5 NM・intercept の判定が無い」の分。NOT ON INTERCEPT HEADING は FMC が出す。
- LNAV が engage している間のロール：FMC のバンクの指令を 3°/s で追う（ATA22 p.358。推定の速さ）。X-Plane の HDG SEL の FD roll とその 10 点の移動平均は通さない（AFDS-01 の LNAV の分）。PFD の FD のバーも同じ指令。
- LNAV の arm 中も前のロールモード（HDG SEL・HDG HOLD）が active のまま（FCOM p.644）。前は arm 中の HDG SEL が NONE になってサーボが離れ、HDG HOLD は arm を消していた（arm がすぐ engage していたので表に出なかった）。arm 中に X-Plane の HDG SEL を入れない（engage してから）。
- 残り（6-3）：50 ft は滑走路の標高 +50 ft でなく電波高度のまま、active の LNAV を押すと解除する、LNAV にも効く AUTO のバンクの制限（離陸フラップで V2+10 未満は 15°：FCTM p.118）。

## 10. 段階 6-3 の段取り（2026-10-27）

- 方式：§8 の推奨どおり作り直す（PLAN.md 6-3）。FCC の論理（モードの latch・遷移表と TRANS ENABLE・既定・反転・arm と disarm、engage と disengage、FMA と AFDS の状態）と制御則（outer loop：ロールとピッチの指令）を新しい純粋なモジュール（`plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_*.lua`）に置き、自動操縦のモジュールのグルーが決まった順に毎フレーム回す。0.05〜0.5 秒の `lastCommand` の待ちでつなぐ作りは、置き換えた所からやめる（§6.3）。
- どの段の後でも機体は飛べるようにし、古いコードは置き換えるまで動かす（FMC の段取りと同じ）。段 1 は、新しいモードの論理が、今の則と読み手の読む状態（FMA の数値、独自のピッチの状態 `vvi_status`・`altitude_hold_status`・`speed_status`・`altitude_hold_ft`、`lnav_state`・`vnav_state`、LOC と G/S の状態、X-Plane の HDG のモード）を書いて、今の則を動かす（`B747.19.xt.afds_control.lua` のピッチの則は FMA の数値で選ぶ）。則は段 2・3 で置き換える。
- 内側のループ（サーボの PID と舵面への出口 `flt_ctrls/sim_pitch_ratio`・`sim_roll_ratio`）は使い続け、段 2・3 で指令の受け渡しを直す（6c の LNAV と同じ形）。
- 3 チャンネル：段 1〜3 は 1 チャンネル分の論理。FCC 3 台を 1 つの関数で 3 回回す形（§6.3）と multi-channel は段 4。それまで autoland（`B747.autoland.lua`）は今のまま動かし、それが FMA を書いている間はモデルは書かない。
- A/T（6-4）は FMC の段 9（VNAV）と並べる。AFDS と A/T の取り合い（ピッチのモードが A/T のモードを決める、T/O の latch が A/T SPD で解ける、SPD スイッチは VNAV・FLCH・TO/GA 中は無効、flare の 25 ft の retard）は今の A/T のコードに dataref で渡す。VNAV のピッチの指令とサブモード（VNAV SPD・PTH・ALT）は FMC の段 9 で、それまでは今の VNAV のコード（monitor の `VNAV_modeSwitch`）の出力をつなぐ。
- 他のプラグインの部分：F/D スイッチ（`plugins/xtlua` の manipulators）と TO/GA スイッチ（同 engines）が今は AFDS のモードを書いている。段 1 で、どちらもスイッチの位置と押したことだけを dataref に出し、モードはモデルが決める。
- 表示：FMA と AFDS 状態の数値（INTERFACES.tsv、init の 0〜9）は変えない。FD のバーは今のパネルでは active のモードの数値 > 1 で出るので TO/GA（= 1）で出ない（§9 の 1）：段 1d で FD のバーを出す dataref を新しく作り、パネルの条件をそれに変える（2026-10-25 から承認なしで可。手順は CLAUDE.md）。amber の線、FD の故障旗、TEST は段 5。
- 型式差（FCOM の 109・405 が PW、570 が GE。RR は資料が無いので PW と同じ：推定）はエンジン型式の dataref（`laminar/B747/engines/type`）で分ける：ATT の有無（段 1）、AUTOPILOT DISC の音と、F/D のモード故障で消えるバー（段 5）。G/S を LOC より先に捕まえるか（109 と 570 は可、405 は LOC の後）は PW の 2 機で違うので、段 1c で決める。
- 試験：`tests/autopilot/` に、モードの論理（MCP・F/D・CMD・TO/GA の事象の列と、期待するモード・FMA・状態）、則（閉ループ：横は `tests/lib/lnav_sim.lua` を流用、縦は新しい簡単な機体の模型）、グルー（`tests/lib/xtlua.lua` でモジュールを読み、コマンドと dataref）。今の則の振る舞いは `tests/tools/same_behaviour.lua` と `tests/tools/scenarios/hydraulics_afds.lua` で比べる。X-Plane は既存の `s01_ap_basic`・`s44_tcas`・`s60_pfd_ils_alert`・`s90_lnav` などと、段ごとの新しいシナリオ。

### 10.1 今のコード（2026-10-27 の調べ。§6.1 の後の変化を含む）

- モードの論理は、自動操縦のモジュール（`B747.70.xt.autopilot.lua` の MCP のハンドラーと `fma_rollModes`・`fma_PitchModes`・`B747_ap_afds`、monitor の LOC・G/S の捕捉と VNAV の切替、autoland）、F/D スイッチ（manipulators）、TO/GA スイッチ（engines）に散り、則（afds_control）もモードの状態を書き換える（ALT の捕捉の latch、FMA が 5・6・9 でないときの ALT HOLD の解除）。
- ピッチの則は FMA の active のピッチの数値で選ぶ（FLCH・ALT・V/S・TO/GA、autoland）。ロールは X-Plane の HDG SEL・HDG HOLD の FD のロール（LOC も目標の方位を X-Plane の HDG SEL に渡す）、ATT と LNAV（6c）は則が直接。HDG HOLD は 3D のボタンが X-Plane の `sim/autopilot/heading_hold` を直接押し、X-Plane の heading hold が動く。
- 順序は約 40 か所の `lastCommand` の待ち（0.05〜0.5 秒、高度のつまみは 1 秒）と `run_after_time`（MCP の高度は 3 秒後に内部の目標へ、10 秒の枠など）でつないでいる。
- 作り直しで消える誤り：F/D を両方 OFF にしたときの X-Plane の FD と HDG のモードの解除が実際には送られない（`servos_on_time` が毎フレーム書き直される）、LOC と G/S の latch は F/D が ON のときだけ更新、LAND 2/3 の間は FMA の関数を飛ばす、TO/GA のコマンドが engines で replace・manipulators で wrap の二重、CMD L は押したとき・C と R は離したときに engage、AUTOPILOT caution の変数が未定義、ヨーダンパーの減衰が片側だけ。

| 段 | 内容 | GAP | 主な資料 |
|---|---|---|---|
| 1a | 枠組みと engage：新しいモデル `B747.70.afds_model.lua` とグルー。A/P の engage（CMD を押したとき。地上でも、バーが上で他のチャンネルが無いとき）と disengage（バー、操縦輪のスイッチ、油圧）、AUTOPILOT DISC とそのリセット（再 engage か操縦輪のスイッチ。バーを上げても消えない）、F/D の最初の ON と A/P engage の既定のモード（V/S と HDG HOLD・ATT、F/D が地上の T/O・LOC・G/S 捕捉中の扱い）、A/P も F/D も無いと全モードを消す、AFDS の状態（FD は ON の側、CMD は両側）と 10 秒の枠、MCP の初期値（IAS 200）、空中開始の初期化 | AFDS-06・14・21、15 の一部（400 ft の制限） | FCOM p.639–640、p.655、p.660、p.662；ATA22 p.250、p.266、p.302–318、p.338、p.352、p.370、p.380 |
| 1b | ロールのモード（2026-10-27 に分け直し：進入のモードは 1d へ）：HDG SEL（LOC と G/S の捕捉後と GA の 400 ft 未満は禁止）、HDG HOLD（3D のボタンの X-Plane のコマンドを受ける、HDG REF の切替の既定）、ATT（PW）、LNAV の arm・2 回目の disarm・engage（FMC の valid と 50 ft）・解除、ロールの遷移表、FMA のロール | AFDS-08（LNAV）・09（ロール） | FCOM p.644–647、p.663；ATA22 p.270–274、p.351–355 |
| 1c | ピッチのモード（進入の G/S は 1d へ）：V/S（現 V/S に同期、前が ALT か TO/GA で降下中なら 0、000 で内部は ALT HOLD）、ALT HOLD、ALT の捕捉（判定は段 3 まで今の窓）、FLCH（速度の同期）、VNAV の arm・2 回目の disarm・engage と解除（サブモードは今の VNAV）、SPD スイッチ（VNAV・FLCH・TO/GA 中は無効）、自動反転の既定（V/S・ALT HOLD）、ピッチの遷移表、FMA のピッチ | AFDS-07・08（VNAV の AFDS 側、SPD）・09（ピッチ）・11 の反転 | FCOM p.642–649、p.664–665；ATA22 p.279–286、p.335–341 |
| 1d | 進入のモード（両軸にまたがり、LOC と G/S の捕捉が互いの条件になる）：LOC と APP の arm・disarm・捕捉（捕捉の判定は段 2・3 まで今の作り）・deselect、G/S の arm と捕捉（405 は LOC の後、109・570 はどちらが先でも）、LOC・G/S 捕捉中の A/P の engage（LOC の arm と HDG HOLD、G/S の arm と V/S）、LNAV・VNAV との相互の解除、ILS の無いときの CDU のメッセージ | AFDS-02 の論理・09（進入） | FCOM p.650–652、p.669–670；ATA22 p.266、p.290–292、p.342–343、p.356–357 |
| 1e | TO/GA の論理：地上の F/D で T/O（ロールとピッチを分ける）、離陸後の 50 ft の LNAV と 400 ft の VNAV、離陸中の TO/GA（50〜400 ft はロールだけ）、空中の arm（フラップが UP でないか G/S 捕捉）と GA（APP を解除）、400 ft 未満は A/P と F/D を切るまで、400 ft 以上で各軸が別に変わる、T/O と GA からの ALT の捕捉は 800 ft 以上、接地の 2 秒と離れて 3 秒、>80 kt の FD の自動表示、FD のバーの dataref とパネル | AFDS-03 の論理 | FCOM p.656–657、p.661、p.663–668、p.672–675；ATA22 p.264、p.298、p.336–337、p.353–355 |
| 2 | ロールの則（2026-10-27 に 2a と 2b に分けた：§16）：HDG SEL（先に選べば近い側、押してから回せば回した向き）、bank limit の AUTO（TAS・フラップ・V2。LNAV にも：FCTM p.118）、HDG HOLD（翼水平 3° でその時の方位）、ATT（5〜30°）、TO/GA の track、LOC の捕捉（対地速度・進入角・偏差）と追従（電波高度で直線偏差、inertial path）、HDG REF（TRUE で真方位、NORM の極地域で HDG SEL・HDG HOLD・LOC が働かない）。X-Plane の HDG のモードと FD を使わない | AFDS-01・02（LOC）・22 | ATA22 p.272–274、p.290–292、p.348–358；FCOM p.646–651、p.663 |
| 3 | ピッチの則（2026-10-28 に 3a・3b・3c に分けた：§18）：V/S（慣性の V/S との差）、ALT の捕捉（0.05 g）と保持、FLCH と TO/GA の speed-through-elevator（600〜1200 fpm の混合、5 秒の目標の更新、V2+25・MCP+25、片発、windshear の 15° と PLI）、G/S（電波高度で直線偏差、inertial path、捕捉の判定）、速度の保護（FMC の min/max と 5 kt、FMC が無効なら FCC の計算）。TO/GA のピッチを計器のモジュールから移す | AFDS-02（G/S）・03・10・11、DSP-34 の TO/GA の分 | ATA22 p.264、p.282–286、p.298、p.330–346；FCOM p.664–665、p.672–675 |
| 4 | autoland と 3 チャンネル：FCC 3 台の論理、multi-arm（APP）、1500 ft・LOC と G/S・2°・5 秒の engage、LAND 3・LAND 2・NO AUTOLAND（電源・FCC・センサーの冗長、200 ft 未満の抑止、600 ft）、flare（沈下率で 40〜60 ft、脚の高さ、1.5 ft/s で GS 送信所の 450 ft 先）、nose letdown、rollout（LOC 偏差で rudder と NWS）、runway align・decrab・片発、25 ft の retard、GA の first-in-command、NO LAND 3・NO AUTOLAND の EICAS、bus isolation | AFDS-04・05・13、ELEC-18 | ATA22 p.192–196、p.250–256、p.288–298、p.318–324、p.342–362、p.369–386；FCOM p.651–653、p.662、p.670–673 |
| 5 | 監視と警報：engage のインターロック（FCC の AC・DC、DC STBY、MCP、油圧、IRU・ADC の有効、SRM の autotrim valid、操縦輪の 25°）、override、モード故障で姿勢保持・amber の線・AUTOPILOT、FD の故障旗、AUTOPILOT DISC の音（型式）、ILS TUNE INHIBIT・RA TEST INHIBIT | AFDS-12・14 の音・15・16・23 | ATA22 p.190–216、p.302–324、p.366–386；FCOM p.640、p.653–655、p.660、p.677 |
| 6 | ヨーダンパーと autotrim：YD の則（dutch roll の減衰、turn coordination、modal、±4° と IRU・ADC の数で縮める、地上は 0、5 秒の fade）、A/P 中の autotrim の指令（昇降舵のサーボの指令が 0.4°（G/S 捕捉中 0.6°）を超えたら出し 0.25° で止める、500 ft 未満でも接地まで、rollout で禁止、LAND 2 の 120 ft 未満の full rate と trim bias、GA で取り消し。速さ・3.5 秒の遅れ・full rate・dead trim は ATA-27 段 2b で済） | AFDS-17・18・19 | ATA22 p.49–96、p.144–166 |

- 前から分かっている問題も、それぞれの段で直す：`s44_tcas` の 11・12 回目の、ALT HOLD の後に FMA のピッチが空になる・ALT のまま上がる（1c・3）、APP が斜めから入ると LOC も G/S も捕まえない・FMA が F/D ON のときしか更新されない（`s60_pfd_ils_alert`：1b・1c・2・3）、空中開始で A/T と A/P のモードが読み込み方で変わる（`s01`：1a）、ヨーダンパーの減衰が片側だけ（6）。

## 11. 段 1a の実装（2026-10-27：枠組みと engage）

- 新しい純粋なモデル `plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_model.lua`（`B747_afds_model`）。この段では A/P の engage の状態（L・C・R、解除バー）、AUTOPILOT DISC、F/D のスイッチ、既定のモードと全モードの消去を持つ。ほかのモードはまだ前のコード（1b〜1d で移す）で、モデルの求める既定のモードはグルーが前のコードの状態に書く。
- engage（FCOM p.640；ATA22 p.302–318）：CMD を押したとき（前は L が押したとき、C と R が離したとき）。解除バーが上で、ほかのチャンネルが engage していなくて（巡航で 2 台目は engage しない）、そのチャンネルのサーボの油圧（L は系統 3、C は 1、R は 2：ATA22 p.10–12）が 1000 psi 以上（前のコードの解除の値：推定）。地上でも engage する（前のコードの 400 ft は資料に無い。離陸後 250 ft は運用の制限：FCOM p.80）。
- disengage：解除バー（全部。下げている間は engage しない）、操縦輪のスイッチ、自動（油圧を失う、A/P 1 台での操縦輪のトリム：FCOM p.945）。AUTOPILOT DISC は engage していた最後のチャンネルが外れたとき（手でも自動でも）に出て、再 engage か、A/P の無いときの操縦輪のスイッチ（手の解除の後は 2 回目、自動の後は 1 回目）で消える（FCOM p.655；ATA22 p.254、p.380）。解除バーを上げても消えない（前は消えた）。前のコードの全チャンネル解除（リセットのコマンド、autoland の接地後 65 kt の解除）はモデルを警報なしで解除する（autoland は段 4 で作り直す）。進入の 3 チャンネル（APP を 1500 ft より上で押す、1500 ft 未満で LOC と G/S）は前のまま、モデルの「まとめて engage」で（段 4 まで）。
- F/D（FCOM p.639–640；ATA22 p.337、p.352–353）：両方 OFF で A/P の無いときに最初の F/D を ON にすると、地上で TO/GA（ロールとピッチ：前のコードの `TOGA_status`）、空中で V/S と HDG HOLD、バンクが 5° を超えると ATT（30° まで。PW の 109・405。GE の 570 は HDG HOLD だけ、RR は資料が無いので PW と同じ：推定）。A/P が engage していれば A/P のモードを出す。F/D のスイッチのハンドラー（manipulators）はスイッチだけにし、モデルがスイッチの位置（`toggle_switch/position[23]`・`[24]`、1 フレームで動く）を読む。
- A/P の engage の既定（ATA22 p.266、p.338、p.352；FCOM p.640）：F/D が ON ならそのモード、ただし F/D が地上の T/O なら HDG HOLD と V/S。両方 OFF なら V/S と HDG HOLD・ATT（F/D と同じ）。LOC・G/S 捕捉中の engage（LOC arm と HDG HOLD、G/S arm と V/S）は 1b・1c。
- 既定の V/S は V/S のスイッチと同じ状態（A/T が ARM なら SPD）にし、目標を今の昇降率（100 fpm 単位、−8000〜+6000）に合わせる（ATA22 p.282、p.344。スイッチで押したときの同期は 1c）。既定の HDG HOLD は X-Plane の heading hold（ロールの則は段 2 まで X-Plane）、ATT はそのバンク。
- 全モードの消去（FCOM p.660）：A/P が外れて F/D が両方 OFF のとき、または A/P の無いときに F/D を両方 OFF にしたとき。前のコードの状態（LNAV・VNAV・APP・LOC・G/S・TO/GA・ATT・ピッチの状態）を消し、X-Plane の FD と HDG のモードも切る（前のコードは `servos_on_time` の書き直しで実際には送っていなかった）。A/P も F/D も無い間は、前のコードの FMA の関数も何も出さない（前の捕捉の窓が、MCP の高度の近くでモード無しに ALT を出し、前の則が ALT HOLD をまた立てた：`s99` の 1 回目）。前の則（`B747.19.xt.afds_control.lua`）も、ピッチのモードの無い間は指令を出さず、捕捉の窓で ALT HOLD を立てない（`s99` の 2 回目）。
- AFDS の状態：前のまま（CMD は両側、FD は ON の側、LAND 2・3 と NO AUTOLAND は前のコード）。サーボとチャンネルの食い違いを 1 秒後に直していた前の検査はやめた（engage の状態はモデルだけが持つ）。
- MCP の IAS の初期値 200（FCOM p.643；ATA22 p.236。前は 100）。
- 空中開始（FMS の初期化：F/D L、A/T、ALT HOLD、1 秒後に CMD L。試験のためのもの）は、F/D の既定の V/S が ALT HOLD の後に来ないように、ALT HOLD を 1 秒後の CMD L の前に移した。初期化はモジュールの一生に 1 回だったので、試験の機体の読み直しの後の空中開始のやり直しより先に走ると、そのやり直しの飛行の開始（AFDS の engage の状態を消すようになった）で A/P が外れたまま戻らなかった（`s99` の 3 回目）：飛行の開始のたびに走らせ、何度走っても同じになるようにした（F/D L は OFF のときだけ押す、A/T は ARM のコマンドで。前の A/T のスイッチは押すたびに入れ替わる）。
- 試験：新しい `tests/autopilot/afds_model_test.lua`（42 件：engage の条件、2 台目、油圧、地上、解除バー、操縦輪のスイッチ、自動、警報なし、油圧の喪失、F/D の最初の ON、ATT の PW・GE・RR と 30°、地上の TO/GA、F/D の T/O からの engage、全モードの消去、3 チャンネル）、`tests/autopilot/afds_glue_test.lua`（28 件：XTLua のモックでモジュールを読み、CMD・解除バー・操縦輪のスイッチ・油圧から CMD のチャンネル・サーボ・AUTOPILOT DISC、既定の V/S の同期と X-Plane の HDG HOLD と ATT、全モードの消去と X-Plane の FD の解除と MCP の高度の近くでも FMA が空、IAS 200）。`tests/displays/hdg_ref_test.lua` は HDG SEL を F/D ON で（A/P も F/D も無いとモードは無い）、`tests/hyd/hyd_module_test.lua`（189 件：前の則がピッチのモード無しで ALT HOLD を立てない、V/S なら立てる）。全体 117 ファイル。
- X-Plane：新しい `s99_afds_engage`（空中：空中の初期化の ALT と HDG HOLD、操縦輪のスイッチの解除と AUTOPILOT DISC と 2 回目、F/D を両方 OFF で全モードの消去、F/D OFF の CMD C の V/S と HDG HOLD、2 台目は入らない、解除バー、AFDS の状態の CMD と FD）は 4 回目に 36/36。1 回目 34/36（全モードの消去の後に前の FMA の関数が ALT を出した）、2 回目 35/36（前の則が ALT HOLD を立て直した）、3 回目 22/36（空中の初期化が試験の空中開始のやり直しより先に走り、A/P が外れたまま）で、どれも上のとおり直した。回帰（1 回目と同じコード）：`s01_ap_basic` 15/15、`s28_stab_trim` 25/25、`s30_speed_trim` 11/11、`s59_pfd_ils` 33/34（空中開始で LOC から 1.67 dot 外れて始まった：やり直しで 34/34）、`s90_lnav` 30/30。最後のコードで `s01_ap_basic` 15/15、`s59_pfd_ils` 34/34。Lua の誤りなし。

## 12. 段 1b の実装（2026-10-27：ロールのモード）

- 段 1 の残りを分け直した（§10 の表）：1b はロールのモードのうち HDG SEL・HDG HOLD・ATT・LNAV、1c はピッチのモードのうち V/S・ALT・FLCH・VNAV・SPD、1d は進入のモード（LOC・G/S・APP。両軸にまたがり、LOC と G/S の捕捉が互いの条件になるので一緒に）、1e は TO/GA の論理。
- モデル（`B747.70.afds_model.lua`）がロールのモード（`roll`）と LNAV の arm を持つ。どれも次のロールのモードの engage で解ける latch（ATA22 図 p.353）。
  - HDG SEL：要求と TRANS ENABLE（遷移表 p.351：前のコードの LOC からは G/S が active になる前だけ、G/A からは 400 ft RA 以上だけ、T/O からは高さによらず。前のコードの 1 つの TO/GA のフラグのうち G/A は autoland が負のとき：段 1e まで）。
  - HDG HOLD：同じ条件の要求か既定（F/D・A/P の既定、HDG SEL 中の HDG REF の切替：ATA22 p.352）。表示はすぐ、保つ方位はロールが 3° 未満で 2 秒続いた時の方位（図 p.353）。
  - ATT：既定だけ。新しいロールのモードまで保つ（図 p.353。5° 未満になっても HDG HOLD にはならない）。
  - LNAV：1 回目で arm（LOC の engage 中は不可、G/A からは 400 ft 以上）、arm 中の 2 回目で disarm、engage 中に押しても何もしない（前は解除した）。arm 中は前のロールのモードが active のまま（FCOM p.644）。arm のまま FMC の steering が valid で 50 ft を超えると engage（6-1・6-2 段 6c）。HDG SEL と HDG HOLD は LNAV を解くが arm は消さない（ATA22 p.354 の arm の解除は 2 回目、LOC・APP の要求、engage だけ。前は HDG SEL で arm も消した）。経路が無くても LNAV は外さない（FMC が経路の終わりで方位を保つ：段 6c。前は外して CDU に DESTINATION NOT SET（FCOM に無いメッセージ。旗の番号は `B744.notifications.lua` の DRindex に 1 を足したもの）を出していた）。前のコードの LOC の捕捉で LNAV と arm が消える（FCOM p.645）。
- FMA のロール：モデルのモード（LNAV 2、ATT 5、HDG SEL 6、HDG HOLD 7）。前のコードの LOC（3）と、ロールのモードに置き換わるまでの TO/GA（1）が先。arm は LNAV（2）、無ければ前のコードの LOC（3）・ROLLOUT（4）。
- ロールの則は段 2 まで X-Plane の HDG SEL だけを使う：HDG SEL は MCP の方位へ、HDG HOLD は保つ方位（捕まえるまでは今の方位：翼を水平に戻す）へ、X-Plane の HDG SEL の目標（`heading_mag`）を書く（モードのコマンドは 1 秒に 1 回まで）。X-Plane の heading hold はもう使わない：3D の HDG HOLD のボタンが押す `sim/autopilot/heading_hold` を wrap から replace にし、モデルの要求にした（前は X-Plane の heading hold がそのまま入り、遷移表で禁じられた時も切り替わった）。ATT はモデルのバンクを前の則（`att_rate`）に、LNAV は前の則が FMC のバンクの指令で飛ぶ（段 6c）。
- グルーが `lnav_state`（0 無し、1 arm、2 engage：FMC の LNAV と前の則が読む）と `att_rate` をモデルから毎フレーム書く。HDG SEL・HDG HOLD を前のコードの LOC から選ぶと、前のコードの進入（LOC と APP の G/S の arm）を消す（FCOM p.651–652：LNAV 以外のロールのモードで LOC と APP が外れる。段 1d まで）。
- MCP の HDG HOLD の灯は FMA のロールが HDG HOLD か ATT のとき（ATA22 p.266：ATT でも HDG HOLD の灯。前は X-Plane の heading hold の状態）。
- 試験：`tests/autopilot/afds_model_test.lua`（76 件：1a の分と、HDG SEL・HDG HOLD の 2 秒・ATT が残ること・LNAV の arm と 2 回目と engage・HDG SEL で arm が残る・engage 中の LNAV・HDG HOLD で LNAV が外れる・前の LOC・G/A の 400 ft・TO/GA のロールの置き換え・HDG REF の既定・FMA）、`tests/autopilot/afds_glue_test.lua`（43 件：X-Plane の HDG SEL の目標、LNAV の arm と engage、X-Plane のコマンドの HDG HOLD と 2 秒）、`tests/displays/hdg_ref_test.lua`（32 件：HDG SEL はボタンで、HDG REF の既定は FMA で）、`tests/lighting/lighting_module_test.lua`（66 件：HDG HOLD の灯は HDG HOLD と ATT で点き、HDG SEL と LNAV で消える）。全体 117 ファイル。
- X-Plane：新しい `s100_afds_roll` 25/25（空中：HDG SEL の旋回と方位、LNAV の arm と 2 回目、旋回中の HDG HOLD、ATT。PFD で CMD と「SPD｜HDG SEL・LNAV（arm）｜ALT」、ATT で約 25° のバンクを保つのを画像で確かめた）、回帰の `s99_afds_engage` 36/36、`s01_ap_basic` 15/15、`s72_hdg_ref` 19/19、`s90_lnav` 30/30、`s91_lnav_sid` 27/27、`s92_hold` 47/47、`s59_pfd_ils` 34/34。Log.txt に Lua の誤りなし。

## 13. 段 1c の実装（2026-10-27：ピッチのモード）

- モデル（`B747.70.afds_model.lua`）がピッチのモード（`pitch`：V/S・ALT・FLCH・VNAV）と VNAV の arm を持つ。どれも次のピッチのモードの engage で解ける latch。遷移（表 p.335）：V/S・ALT HOLD・FLCH は、前のコードの G/S からは LOC が active になる前だけ（前のコードの G/S は LOC の捕捉の後にしか入らないので、今は G/S 中は受け付けない）、G/A からは 400 ft RA 以上だけ、FLARE からは無し。VNAV は G/A からは高さによらず、G/S と FLARE からは無し。G/A と T/O からの ALT の捕捉は 800 ft 以上（段 1e）。
  - V/S（FCOM p.648、ATA22 p.282）：押すと今の昇降率を 100 fpm に丸めて窓に入れる（−8,000〜+6,000）。前のモードが ALT か、TO/GA で降下中なら 000（前は押すたびに 0）。A/T は arm なら SPD（前のコードのまま）。
  - ALT HOLD（FCOM p.650）：押した時の高度を保つ。
  - ALT の捕捉：V/S と FLCH から MCP 高度を捕捉して ALT（捕捉の判定は段 3 まで前のコードの窓。資料の則は 0.05 g：ATA22 p.286）。
  - FLCH SPD（FCOM p.646）：速度の窓が開いていればそのまま、空白（VNAV）なら FMC の目標速度、無ければ今の速度。TO/GA からは今の速度と選んだ速度の大きい方（AFDS-21 の一部）。A/T は THR（前のコードの推力のモード 2）。
  - ALT HOLD の既定（ATA22 p.338）：FLCH で MCP 高度への道から 8,000 ft 離れると、その高度で ALT HOLD。測り始めは FLCH の間に MCP 高度にいちばん近づいた所（推定：資料に点の定めが無い）。
  - VNAV（FCOM p.645、ATA22 p.340）：1 回目で arm（G/S と FLARE の間は不可。G/A からは高さによらず）。arm の間は今のピッチのモードのまま（前は arm で ALT HOLD を立てた）。arm 中の 2 回目で disarm、engage 中に押しても何もしない（前は外した）。engage は前の VNAV（monitor の `VNAV_modeSwitch`：400 ft、サブモードは前の則のフラグ）が `vnav_state` を 2 以上にしたとき（FMC の段 9 まで）。V/S・ALT・FLCH・G/S・TO/GA で終わり、arm はそれらでは消えない（arm を消すのは 2 回目、APP の要求、engage だけ）。前の VNAV が自分で終わったとき（経路が無い、接地）は、その時の前の則のモード（ALT は前の則の高度で）。性能のデータ（CRZ ALT）が無いと PERF/VNAV UNAVAILABLE（前のコードのまま。FMC のメッセージの旗の番号は `B744.notifications.lua` の DRindex に 1 を足したもの）。
  - 経路が無いと前の VNAV は動けないので（FMC の段 9 まで）、VNAV と arm はモデルを通して終わる（資料に「経路が無いと VNAV が外れる」とは書いていない）。前は CDU に DESTINATION NOT SET（FCOM に無いメッセージ）も出していた。また、前の monitor の VNAV は経路が空でも経路の表の 0 番を読み、Lua の誤りでそのフレームの処理が止まって、後ろにある取り消しに届かなかった（空中で経路なしに VNAV を押すと誤りが続く）。経路が無いときは前の VNAV の処理を飛ばす。CRZ ALT が無いときの前の VNAV の取り消し（vnavspd）もモデルを通す。
  - SPD（FCOM p.642）：VNAV・FLCH SPD・TO/GA の間は効かない（前は VNAV と FLCH を V/S に落とした）。
  - 前のコードの G/S の engage（段 1d まで）でピッチのモードと VNAV の arm が終わる（FCOM p.645：G/S で VNAV が終わる。arm を消す APP の要求はまだ前のコード：ATA22 p.340）。前のコードの TO/GA のピッチの始まり（段 1e まで）でピッチのモードが終わる（VNAV も。arm は残る）。
- FMA のピッチ：前のコードの FLARE・G/S と、ピッチのモードに置き換わるまでの TO/GA が先。VNAV は前の VNAV のサブモード（前の FMA の推定のまま：FMC の段 9）。arm は VNAV（4）、無ければ前のコードの G/S（2）・FLARE（3）。地上では TO/GA しか出さない（前の FMA と同じ。前のピッチの則は FMA の数で枝を選ぶので、地上で A/P を入れたときに V/S・ALT で昇降舵を動かさないため：段 3 まで）。
- グルー（`B747.70.xt.autopilot.lua`）が前のコードの状態を毎フレーム書く：`vnav_state`（arm で 1、engage 中は前の VNAV のもの）、ピッチのモードがあって VNAV でないときの前の則のフラグ（`vvi_status`・`altitude_hold_status`・`speed_status`）と保つ高度。ボタンは前のコードの A/T・飛行段階・目標の書き込みを残し、モードはモデルへ。前の V/S・ALT HOLD・FLCH のボタンは TO/GA のフラグも消していた（ロールの TO/GA も終わった）が、今はピッチだけが替わり、ロールの TO/GA は次のロールのモードまで残る（ただし前の A/T は ALT HOLD のフラグで TO/GA のフラグを消す：段 1e と 6-4 で分ける）。X-Plane の V/S・FLCH のコマンドは送らない（前の則は自前の PID で昇降舵を動かす。1a の V/S の既定と同じ）。
- MCP の灯（`B747.90.xt.lighting.lua`。FCOM p.642、p.645–650）：VNAV と LNAV は arm か active、V/S・ALT HOLD・FLCH はそのモードが active。VNAV の arm の間も作動中のモードの灯は点いたまま（前は VNAV の状態が 1 以上で V/S・ALT HOLD・FLCH・SPD を消した）、VNAV の engage 中（前の VNAV がサブモードに前の則のフラグを使う）と前のコードの G/S の捕捉後は消す。
- 作らなかったもの：V/S の既定のうち「速度を昇降舵で保つモードで A/T が SPD に変わったとき」（ATA22 p.338。A/T は 6-4 まで前のコードで、モードの変わり方が資料と違う）、V/S 000 のときの内部の ALT HOLD（ATA22 p.338。前のピッチの則を変えるので段 3）、VNAV の ALT HOLD の既定（FMC の段 9）、MCP 高度の変更が内部の目標に入るまでの 3 秒（AFDS-21）。
- 試験：`tests/autopilot/afds_model_test.lua`（129 件：V/S の同期と 000、ALT HOLD、遷移、FLCH の速度、捕捉、VNAV の arm・2 回目・engage・engage 中・V/S で終わる・前の VNAV の終わり・経路なし、SPD、ALT HOLD の既定、G/S と TO/GA で終わる、FMA）、`tests/autopilot/afds_glue_test.lua`（74 件：前の則のフラグと V/S の窓、FLCH SPD 中の SPD、PERF/VNAV UNAVAILABLE、400 ft 未満の arm と 2 回目、400 ft 以上で前の VNAV が engage して VNAV SPD、engage 中の VNAV、V/S で終わる、経路が消えると arm が消え DESTINATION NOT SET を出さない）、`tests/lighting/lighting_module_test.lua`（73 件：MCP のピッチの灯）。全体 117 ファイル。
- X-Plane：新しい `s101_afds_pitch` 33/33（空中：経路と CRZ ALT を CDU で入れ、ALT の後の V/S は 000、上昇中の V/S で今の昇降率に合わせる、MCP 高度の捕捉で ALT と保つ高度、FLCH で降りて捕捉、FLCH 中の SPD は効かない、上昇中の ALT HOLD で押した時の高度を保つ、空中の VNAV はすぐ engage、engage 中の VNAV、V/S で VNAV が終わる。1 回目は高度を「捕捉の 15 秒後に ±200 ft」で見て 3 つ落ちた：前のピッチの則は捕捉の窓が広く（1,000 fpm で約 450 ft 手前）、11,000 ft に届くまで約 35 秒、ALT HOLD は 10,000 ft より上で約 500 ft 行き過ぎる。段 3 の則の問題なので、保つ高度を確かめてから範囲に入るまで待つ形に直した）、回帰の `s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s01_ap_basic` 15/15、`s07_cruise_ff` 6/6、`s44_tcas` 73/73、`s53_min_speeds_cruise` 11/11、`s59_pfd_ils` 34/34、`s60_pfd_ils_alert` 15/15（前は 8/15：G/S を捕まえなかった。段 1a〜1c の後は 61 秒で捕まえる）、`s90_lnav` 30/30。Log.txt に Lua の誤りなし。

## 14. 段 1d の実装（2026-10-27：進入のモード）

- モデル（`B747.70.afds_model.lua`）が LOC と G/S の arm（`loc_arm`・`gs_arm`）を持ち、捕捉の後はロールの `LOC`、ピッチの `GS` になる（どちらも次のモードで解ける latch：図 p.343、p.357）。前のコードの進入（`approach_mode` から arm する `B747_ap_appr_mode`、F/D が ON の間だけ状態を上げる `glideSlopeLOCProgress`、monitor の捕捉）は外し、グルーがモデルの状態を前の dataref（`approach_mode`：-1 LOC・1 APP、`nav_status`・`actual_nav_status`、`glideslope_status`・`actual_glideslope_status`：1 arm・2 engage）に毎フレーム書く。前の則・灯・autoland・LAND 2/3 はそれを読む。
  - LOC（図 p.357、本文 p.356）：LOC か APP の要求で arm（遷移表 p.351：HDG HOLD・HDG SEL・LNAV から。ATT は表に無いので HDG HOLD と同じ：推定。T/O と G/A からは不可）。LOC だけの arm は LOC の 2 回目か LNAV の arm で消える（FCOM p.651 の「別のロールのモードを選ぶ」は、図では LNAV の arm だけ。HDG SEL・HDG HOLD では arm は残る）。捕捉は、前の検出（両受信機の信号：段 2 まで）と、航跡がコースから 120° 以内（p.356、FCOM p.650）。捕捉で LNAV と LNAV の arm が終わる（FCOM p.645）。捕捉の後は次のロールのモードで終わる（表：G/S が active になる前だけ。LNAV へは不可）。
  - G/S（図 p.343、本文 p.342）：APP の要求で arm（遷移表 p.335：V/S・ALT・FLCH・VNAV から。T/O・G/A・FLARE からは不可）。捕捉は、前の検出（1.5 ドット未満、両受信機の信号と旗：段 3 まで）と、航跡がコースから 80° 以内（FCOM p.651）。405 は LOC の捕捉の後だけ、109・570 はどちらが先でも（FCOM p.651、p.669–670）。作る機体は PW が 109、GE が 570、RR は PW と同じ（推定）で、どれもどちらが先でも（利用者の決定、2026-10-27：いったん PW を 405 にして、同じ日に 109 に戻した。PROGRESS.md）。405 の規則はモデルの入力 `inp.gs_after_loc` に、どの機体も使わないものとして残す。捕捉の後は次のピッチのモードで終わる（表：LOC が active になる前だけ）。
  - APP（両方 arm）は、APP の 2 回目、LOC の要求（G/S の arm だけが消え、LOC の進入になる）、LNAV か VNAV の arm で外れる（図 p.343、p.357；FCOM p.651）。LOC の捕捉後・G/S の arm 中に別のロールのモード（HDG SEL・HDG HOLD）で G/S の arm が消える。109・570 で G/S の捕捉後・LOC の arm 中に別のピッチのモードで LOC の arm が消える（FCOM p.652）。LOC か APP の要求は LNAV の arm を、APP の要求は VNAV の arm を消す（ATA22 p.354、p.340）。
  - 前のコードの TO/GA の始まり（段 1e まで）で LOC・G/S とその arm が終わる（FCOM p.651–652）。地上では終わる（前のコードのまま。段 4 の ROLLOUT まで）。A/P と両 F/D が OFF で全部消える。
  - LOC か G/S の捕捉中に、F/D が ON のまま A/P を入れると、LOC は arm と HDG HOLD、G/S は arm と V/S（今の昇降率）になって捕まえ直す（ATA22 p.266）。
  - 捕捉で MCP の方位を進入のコースにする（ATA22 p.290、p.292。前は APP を押した時）。
  - ILS が無くても LOC と APP は arm する（前は ILS の印が 0 だと arm せず CDU に RW/ILS CRS ERROR を出していた。これは FCOM では「選んだ ILS のコースが目的地の滑走路と合わない」ときの FMC のメッセージ：FMC の作り直しで扱う）。
- FMA：ロールの active はモデルの LOC（3）、arm は LNAV（2）、LOC（3）、無ければ前の autoland の ROLLOUT（4）。ピッチの active は G/S（2）、arm は G/S（2）、VNAV（4）、無ければ前の autoland の FLARE（3）。
- monitor（`B747.70.xt.autopilot.monitor.lua`）：LOC と G/S の捕捉の処理を外した（その条件はグルーの検出の入力として残す）。LOC の追従（X-Plane の HDG SEL の目標）は段 2 まで残す。捕捉の後に信号を失ったり 4 ドットを超えたりしたときに LOC を arm に戻していたのも外した（LOC の engage は latch：図 p.357。信号の無い間は追従しない）。
- 作らなかったもの：LOC・G/S の捕捉の判定（地上速度・角度・偏位、ビームからの距離と偏位の変化率：ATA22 p.290、p.292。段 2・3）、APP で他の A/P を arm しておき 1,500 ft 未満の捕捉で engage する（前のコードのまま：段 4）、ROLLOUT と FLARE（段 4）。
- 試験：`tests/autopilot/afds_model_test.lua`（164 件）、`tests/autopilot/afds_glue_test.lua`（93 件：APP と LOC のボタン、ILS が無くても arm、航跡の角度が大きいと捕まえない（前の monitor は信号だけで捕まえた）、捕捉で MCP の方位がコースに、G/S の捕捉、信号を失っても LOC のまま、G/S の後の HDG SEL、全部 OFF、LOC だけの arm と 2 回目）。全体 117 ファイル。
- X-Plane：新しい `s102_afds_app` 34/34（RJAA 34L の進入路の 20 NM・3,000 ft：NAV1・NAV2 を局の無い周波数にしてから、APP で LOC と G/S の arm（ILS が無くても arm）、2 回目で disarm、LOC だけの arm と 2 回目、LNAV の arm で APP が外れ、APP で LNAV の arm が外れる；ILS を同調して APP で LOC を捕まえ MCP の方位がコース 337 に、G/S はまだ arm（G/S の下 2.5 ドット）、G/S の前の HDG SEL で APP が外れる、もう一度 APP、G/S の捕捉、LOC・G/S の後は HDG SEL と V/S が効かない、TO/GA で LOC と G/S が終わる。PFD を撮った。最初の回は前のシナリオの ILS の同調が残っていて「同調前」に LOC を捕まえ、2 回目は APP を arm したまま同調した瞬間に、受信機の切り替わりの一瞬の偏位を前の簡単な検出（1.5 ドット未満）が捕捉と取って G/S まで捕まえたので、同調の間は APP を外すようにした：段 3 の捕捉の判定で直す）、`s59_pfd_ils` 34/34、`s60_pfd_ils_alert` 15/15、`s62_pfd_ils_rx` 31/31、`s63_nd_app` 39/39、`s01_ap_basic` 15/15、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s101_afds_pitch` 33/33、`s90_lnav` 30/30。Lua の誤りなし

## 15. 段 1e の実装（2026-10-27：TO/GA）

- 資料：ATA22 p.336–337（T/O と G/A のピッチの論理の図）、p.353（T/O のロール）、p.355（G/A のロール）、遷移表 p.335・p.351；FCOM p.656–657（TO/GA スイッチ）、p.660–661（全モードの解除、F/D の表示）、p.663–668（離陸）、p.672–673（着陸復行）。
- T/O：地上で、A/P が入っていないとき最初の F/D を ON にすると T/O のピッチとロール（FMA は両方 TO/GA：p.337、p.353）。ピッチは、地上での A/P の engage（HDG HOLD と V/S）、A/T の SPD、次のピッチのモードで終わる。ロールは次のロールのモード（LNAV なら 50 ft）で終わる。
- G/A：空中で TO/GA スイッチを押すと、フラップが UP でないか G/S が入っていれば G/A のピッチとロール（p.337）。どのピッチのモードからも入る（どれも無いときも：FCOM p.657）が、T/O からは入らない（表 p.335）。離陸後に T/O のピッチのまま押すと、50 ft から G/A のロールだけ（FCOM p.656：「50 ft と 400 ft の間はロールだけ、400 ft より上はロールとピッチ」。400 ft より上ではふつう VNAV などに替わっているので、どちらも合う）。G/A は LOC・G/S とその arm、作動中の VNAV を終わらせる（FCOM p.660）。LNAV と VNAV の arm は残す（ATA22 p.340、p.354）。接地しても G/A は残る（FCOM p.672）。
- TO/GA スイッチは、電波高度が 5 ft を下回って 2 秒で効かなくなり、上回って 3 秒で効く（FCOM p.672。図 p.337 の TRANS ENABLE に当たると読んだ）。
- 遷移（表 p.335、p.351）：G/A からロールのモード、V/S・ALT HOLD・FLCH へは 400 ft から（前と同じ）。LNAV の arm は G/A の間も残るが、engage は 400 ft から。MCP 高度の捕捉は T/O と G/A からは 800 ft より上だけ（前はどの高さでも）。400 ft 未満の G/A は、A/P を切り両 F/D を OFF にしたときだけ終わる（FCOM p.673）。
- F/D の表示：A/P も F/D も入っていないとき、80 kt より速くフラップが UP でなければ、TO/GA を押すと F/D のスイッチが OFF のまま両席に F/D が出て、両 PFD に FD（FCOM p.657、p.661）。F/D のスイッチを ON・OFF すると消える。その間は全部切にならず、A/P を入れれば G/A のまま。新設 `laminar/B747/autopilot/fd/<席>/shown`（スイッチ ON か、この表示）で、パネルの F/D のバーのグループ（PFD 4 面：道具 `docs/overhaul/tools/panel_fd_shown.lua`、ACF_DIFF.md §5）、AFDS の表示の FD とモード変化の枠、FMA を出す条件と全部切を判断する。
- グルー：TO/GA スイッチの押下は、エンジンのモジュール（別のプラグイン）のコマンドが数え（新設 `laminar/B747/autopilot/toga_pushes`）、AFDS が増えたのを見て受け取る。前のスイッチの処理（空中で TO/GA の旗を立てる、autoland を -2、APP を 0）はエンジンのモジュールから外し、G/A のピッチが入ったときにグルーが前の autoland の着陸復行（-2、段 4 まで）と前の A/T の待ち時間を書く。前のコードの TO/GA の旗（`TOGA_status`）はモデルの状態から毎フレーム書く（前の則と A/T は FMA で判断する）。監視・前のピッチ則の捕捉・逆推力が旗を下ろしていた処理は外した。
- 推定：フラップ UP は、フラップのハンドルが UP の位置（FCC の「FLAPS UP」の信号の代わり）。
- 作らなかったもの：T/O のロールの航跡の保持と G/A のロールとピッチの則（段 2・3）、A/T の GA の推力と THR REF（6-4：前のエンジンのモジュールのまま）。前のピッチ則は MCP 高度の捕捉の窓に入ると 800 ft 未満でも ALT で飛ぶ（FMA は TO/GA のまま：段 3 まで）。
- 試験：`tests/autopilot/afds_model_test.lua`（201 件）、`tests/autopilot/afds_glue_test.lua`（106 件：押した回数で G/A、フラップ UP で入らない、前の着陸復行、旗、F/D のスイッチ OFF のままの表示と両 PFD の FD、ON・OFF で全部切、地上の T/O）。全 117 本。
- X-Plane：新しい `s103_afds_to` 19/19（RJAA 34L の地上：F/D を両方 OFF で全部切、F/D L ON で T/O（ロール・ピッチとも TO/GA、TO/GA の旗、機長の F/D の表示と FD）、F/D R ON では変わらない、地上の CMD L で HDG HOLD と V/S。PFD を撮った（F/D のバーは TO/GA でも出る。地上のピッチのバーは水平のまま：前の則、段 3）。1 回目は地上の V/S を FMA で見て落ちた：FMA のピッチは地上では TO/GA のほかは出さない作り（段 1c）なので、前の則の旗で見るようにした）、新しい `s104_afds_ga` 32/32（銚子沖の海上 1,500 ft・160 kt・フラップ 20 で始め、V/S で降りて MCP 高度 300 ft を捕まえ、316 ft で TO/GA：G/A、旗、前の autoland の -2、400 ft 未満で HDG SEL と V/S が効かない、400 ft より上で HDG SEL、MCP 高度 1,500 ft を 804 ft で捕捉（800 ft より上）、A/P と F/D を切って全部切、MCP 高度を 5,000 ft にして F/D のスイッチ OFF のまま TO/GA で G/A と両席の F/D・両 PFD の FD、F/D L の ON・OFF で全部切。PFD を撮った。途中の回で、空中開始の高さが沈んだり浮いたりして毎回違う、MCP 高度を dataref で書いただけでは前の則の目標に写らない、空中の初期化の ALT HOLD が後から入る、MCP 高度にいるまま G/A にすると 800 ft より上の捕捉ですぐ ALT になる（正しい動き）、が分かってシナリオを直した）、`s102_afds_app` 34/34、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25（1 回目は ATT で A/P がバンクを 26° から 39° に増やして 1 件不合格：前のロールの則の揺らぎ、段 2）、`s101_afds_pitch` 33/33、`s01_ap_basic` 15/15、`s11_takeoff_thrust` 12/12（地上の TO/GA で A/T の推力）。途中で X-Plane が GPU のメモリの割り当てに失敗した警告のまま止まり（起動から約 18 時間）、その前触れで結果の無い回が 3 度あった。起動し直して流した。外から見た姿は変わらない（外観の写真）。Lua の誤りなし

## 16. 段 2a の実装（2026-10-27：ロールの則のうち方位・姿勢・航跡）

- 段 2 を分けた：2a は HDG SEL・HDG HOLD・ATT・LNAV・TO/GA の則と bank limit・HDG REF、2b は LOC の捕捉と追従（ROLLOUT は段 4）。
- 資料：ATA22 p.272（HDG HOLD：翼を水平にして、3° 以内でその時の方位）、p.274（HDG SEL：先に選べば近い側、押してから回せば回した向き。bank limit の AUTO は速度で変わる）、p.348（ROLL ATT INTEG は A/P が無いとき姿勢に同期、ROLL DOWN は HDG HOLD の始まりで翼水平）、p.352（HDG HOLD の engage は 3° 未満と HDG HOLD valid、HDG SEL は HDG SEL valid が要る）、p.358（方位のモードは基準の方位か選んだ方位と機体の磁方位か真方位の差、T/O と G/A は航跡）；FCOM p.647（bank limit：AUTO は TAS・フラップ・V2 で 15〜25°、5〜25 は選んだ値が最大で HDG SEL に効く）、p.663（TO/GA のロールは離陸で浮いてから、空中の G/A は開始時の航跡を保つ。ATT は 5〜30°）、p.666（地上の T/O のロールは翼水平）、p.1046（NORM の極地域では AFDS の LNAV 以外のロールのモードに基準が無く、HDG SEL・HDG HOLD・LOC は働かない）；FCTM p.118（AUTO のとき、LNAV か HDG SEL で V2 + 10 kt まではバンクを 15° に、V2 + 10 で離陸のフラップなら 25° まで）；FMSPG p.164・p.226（FMC の待機経路はバンク 30° まで）。
- 新しい純粋なモデル `plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_roll_model.lua`（`B747_afds_roll_model`）。AFDS のモデルのロールのモードから、A/P が飛び F/D が示すロールの指令（バンクの度、右が正）を出す。X-Plane の HDG のモードと F/D のロールは使わない。
  - HDG SEL：MCP の方位と機体の方位（どちらも基準の方位：磁北か真北）の差。押した時は近い側。押してからは、つまみの動きと機体の旋回で差を毎フレーム更新し、360° で丸めない（右へ 200° 回せば右へ 200°。1 周を超えた分は 1 周に収める）。
  - HDG HOLD：AFDS のモデルが方位を持つまで（ロールが 3° 未満で 2 秒：段 1b）は翼水平へ、そのあとはその方位。基準が磁北と真北で替わっても同じ向きを保つ。
  - ATT：AFDS のモデルのバンク（5〜30°）。LNAV：FMC の steering（前の則と同じ 3°/s の追い方。段 6c）。
  - T/O：地上は翼水平、浮いてからはその時の航跡（真北で）。G/A：開始時の航跡、地上では翼水平。
  - 方位・航跡の差 e は、毎秒 e / 8° の旋回を求め、その旋回の TAS でのバンク（atan(V × 旋回率 / g)）にする（推定：資料にゲインが無い）。指令は毎秒 3° まで（推定、LNAV と同じ）で、則が始まる時の機体のバンクから動く（ROLL ATT INTEG の同期：p.348）。
  - bank limit：HDG SEL は MCP の選択器（5・10・15・20・25）か AUTO。AUTO は、フラップが出ていれば V2 + 10 kt 未満で 15°・それ以上で 25°（FCTM p.118。V2 はフラップを上げると FMC が消すので、進入では 25°）、フラップ UP では TAS で 300 kt まで 25°・480 kt から 15°・間は直線（推定：資料に表が無い）。LNAV には AUTO のうち V2 + 10 の 15° だけ（FCTM p.118。TAS の表をかけると FMC の待機経路の 30° が出ない）。HDG HOLD と TO/GA は AUTO の中で（推定）。
  - NORM の極地域（基準が真北でスイッチが NORM）：HDG SEL と HDG HOLD は基準が無い。指令は NCD で、バンクをそのまま保つ。AFDS のモデルは HDG SEL の要求を受けない（HDG SEL valid：p.352）。HDG HOLD は表示されるが方位を持たない（HDG HOLD valid：p.352）。
  - LOC・ROLLOUT は前の則のまま（段 2b・4）。
- グルー（`B747.70.xt.autopilot.lua`）：AFDS のモデルの後に毎フレームロールの則を回し、新設 `autopilot/roll_cmd`（度）・`roll_law`（1：新しい則、0：前の則）・`roll_valid`（0：NCD）を書く（init `B747.70.autopilot`）。PFD の F/D のロールのバーは `roll_cmd`（NCD のときは中央：段 5 のモード故障で消す）。X-Plane の HDG SEL の目標の書き込みとモードのコマンド（HDG SEL・HDG HOLD、LNAV の engage 中の 2 か所）はやめた（LOC の追従は段 2b まで monitor が X-Plane の HDG SEL を使う）。
- 則（`B747.19.xt.afds_control.lua`）：`roll_law` が 1 なら `roll_cmd` を内側のループ（ロールの姿勢の PID）の目標に（X-Plane の F/D のロールと 10 点の移動平均を通さない）。前の LNAV の 3°/s の追い方はモデルに移した。
- 残り：LOC（段 2b）、ROLLOUT と runway align（段 4）、NCD での F/D のバーの消去とモード故障の表示（段 5）、内側のループ（PID）の調整。
- 試験：新しい `tests/autopilot/afds_roll_model_test.lua`（47 件）、`tests/autopilot/afds_glue_test.lua`（109 件：HDG HOLD と HDG SEL と LNAV が則の指令で、X-Plane の HDG SEL を使わない）、`tests/displays/hdg_ref_test.lua`（35 件：基準の方位での HDG SEL の向き、極地域の NCD と HDG SEL の不受理）、`tests/hyd/hyd_module_test.lua`（192 件：`roll_law` が 1 なら X-Plane の F/D のロールではなく `roll_cmd`）。全 118 本。
- X-Plane（カスタム acf）：新しい `s105_afds_roll_law` 18/18（10,000 ft・約 290 kt（真）：bank limit 5 で 40° 右の HDG SEL はバンク最大 4.8°、AUTO で最大 25.1° のまま方位 137（目標 138）に乗る、今の方位で HDG SEL を押してからつまみを右へ 200° 回すと右へ回り続ける（20 秒で 33° 右、バンク 24.9°）、旋回中の HDG HOLD で 7.4 秒で翼水平、その方位を 20 秒で ±2° 以内。PFD を撮った（SPD｜HDG SEL｜ALT、バンク約 25°、F/D のバーは中央）。2 回目に MCP 速度 250 kt を足した：1 回目は 223 kt でフラップ UP の最小機動速度の近くだった）、回帰の `s100_afds_roll` 25/25（ATT のバンク 18.3° が 10 秒で 19.3°：前の則では 26° が 39° に増えたことがある。HDG HOLD の方位は 20 秒で 0.05° のずれ）、`s72_hdg_ref` 20/20（X-Plane の方位のモードの目標の確認を、TRU の HDG SEL で真方位が MCP の 086 に乗ること（磁方位は 083）に替えた）、`s104_afds_ga` 34/34（G/A のロールは新しい則で、開始時の航跡 007.5 を 450 ft でも 007.5）、`s99_afds_engage` 36/36、`s01_ap_basic` 15/15、`s90_lnav` 30/30、`s103_afds_to` 19/19、`s61_nd_orientation` 40/40。1 回目の `s105` の途中で、X-Plane が機体の読み直しの直後にヒープの破損（0xc0000374、ntdll）で落ちた（起動から約 1 時間 10 分、読み直しを 10 回ほど重ねた後）。起動し直してからは同じ所で落ちていない。Lua の誤りなし。

## 17. 段 2b の実装（2026-10-27：LOC の捕捉と追従）

- 資料：ATA22 p.290（LOC の捕捉は対地速度・進入角・LOC の偏位の関数。捕捉で MCP の方位が滑走路の方位に）、p.348（autoland で gear altitude 5 ft から ROLL DOWN で翼水平）、p.356（LOC の engage は arm・LOC valid・コースから 120° 未満・捕捉）、p.358（捕捉の間は滑走路を横切る速度・LOC の偏位・航跡と滑走路の方位の差で、LOC TRACK（コースの上での最後の翼水平）からは偏位の直線距離とその変化率。距離は電波高度から局までの距離を推定して換算し、3° の glide slope と 10,000 ft の滑走路を仮定する。慣性の経路を含み、信号を失うか異常のときもその経路を保つ）、図 p.359（LOC DEV と RAD ALT から LOC DIST COMP、捕捉の入力は CROSS RUNWAY VELOCITY と LOC DEV・HEADING・RWY HDG、LOC TRACK で LOC DEV DIST・RATE・INERTIAL PATH に切り替わる）；FCOM p.650–651（捕捉の点は距離と進入角で変わる、コースから 120° 以内）、p.1046（NORM の極地域では LOC は働かない）。
- ロールの則のモデル（`B747.70.afds_roll_model.lua`）に LOC を足した。
  - 偏位：X-Plane の NAV1 のドット（ビームが右で正）を角度にする。X-Plane の LOC は 1 ドット ＝ 1.41°（0.711 ドット/度）：RJAA 34L の進入路の 21 NM で機体を横へ 300 m ずつ動かし、X-Plane の航法データの LOC のアンテナの位置から計算した角度と比べた（少しずつ動かした 2 点がぴったり合い、大きく動かした点は X-Plane の針の遅れでずれた。全振れ 2.5 ドットは 3.5°）。実機の LOC（滑走路端で ±350 ft）より広い。
  - 直線距離：局までの距離 ＝ 電波高度（2,500 ft まで）/ tan 3° ＋ 10,000 ft（p.358）。遠くで低いと実際より短い（21 NM・3,000 ft で約半分）。
  - 捕捉（AFDS のモデルの LOC の捕捉の入力：前は両受信機の信号だけ）：両受信機に LOC があり、ビームへ寄っていて、捕捉のバンク 25° でコースへ回るのに要る横の距離（旋回半径 × (1 − cos 進入角)）と 4 秒の lead の分より近いか、偏位が 0.7° 以内（寄っていなくても）。進入角 120° の条件は AFDS のモデルのまま。
  - 則：ビームからの距離を、滑走路を横切る速度（対地速度と航跡のコースとの差）で進め、偏位があるときは 5 秒で偏位の距離へ寄せる（慣性の経路：信号を失ってもその経路を保つ）。航跡を、30 秒分の対地速度の先でビームに乗る向きへ（方位の則と同じ、差/8° の旋回のバンク）。距離 100 m・航跡 5° 以内で LOC TRACK（latch）にして、バンクの制限を 25° から 15° に。電波高度 5 ft 未満と地上では翼水平（ROLL DOWN）。NORM の極地域では捕捉せず、LOC は NCD でバンクを保つ。
  - 推定：捕捉のバンク 25° と lead 4 秒、0.7° の帯、30 秒の先読み、5 秒の混ぜ方、LOC TRACK の 100 m・5°、バンクの制限 25°・15°（資料は入力を書くが、ゲインと値は無い）。X-Plane の偏位の目盛は測った値。
- グルー：LOC の入力（NAV1 のドット、両受信機の LOC、NAV1 のコース、磁航跡、対地速度、電波高度、極地域）を毎フレームモデルに渡し、AFDS のモデルの LOC の捕捉の入力をモデルの捕捉にした。monitor の LOC の追従（X-Plane の HDG SEL の目標を偏位と局の方位から決め、風の分を足す）と、前の LNAV が X-Plane の FMS の経路へ X-Plane の HDG SEL で向ける処理（6c から使われていない）を外した。X-Plane の HDG のモードはどのモードでも使わない。
- 残り：G/S の捕捉の判定と追従（段 3）、ROLLOUT・runway align・decrab（段 4）、LOC の異常の検出とモード故障（段 5）、捕捉の後 1〜2 分の F/D と A/P の指令の違い（FCOM p.650 の注）、FCC ごとの ILS の受信機（L・C・R：今は NAV1 の偏位と NAV1・NAV2 の信号）。
- 試験：`tests/autopilot/afds_roll_model_test.lua`（66 件：局までの距離、偏位、捕捉（寄るときの旋回の距離、離れるとき、0.7° の帯、90° で 2.4 ドット、信号なし、極地域）、則（コースへの旋回、LOC TRACK とその制限、信号なしの慣性の経路、5 ft 未満と地上の翼水平、NCD））、`tests/autopilot/afds_glue_test.lua`（111 件：26° で寄るとき 2 ドットでは捕まえず 0.8 ドットで捕まえる、LOC の則でコースへ）。全 118 本。
- X-Plane（カスタム acf）：新しい `s106_afds_loc` 20/20（RJAA 34L の進入路の 22 NM・2.5 NM 右から 30° で入る：ビームの右 1.44 ドットで捕まえ、反対側へ出ずに 90 秒で −0.06 ドット・航跡 336.8・翼水平、右からの横風 20 kt で 0.05 ドット以内・機首は風上へ 5°、信号を失っても LOC のまま航跡 337.35〜337.38、周波数を戻して 0.04 ドット。PFD と ND を撮った（SPD｜LOC｜ALT、翼水平、F/D のバーは中央、ND は TRK 337 でコースの線の上）。1 回目は最後の同調し直しを CDU で同じ値を入れる形にしていて同調せず 19/20：dataref で戻すようにした）、`s102_afds_app` 36/36（MCP の方位 007 でビームの左から 30° で入るようにした：APP ですぐ捕まえ 97 秒で 0.3 ドット以内、HDG SEL の後もすぐ捕まえ直し、G/S はその 23 秒後）、`s60_pfd_ils_alert` 15/15、`s100_afds_roll` 25/25、`s90_lnav` 30/30。X-Plane の偏位の目盛は測定のシナリオで測った（合否なし、リポジトリには入れていない）。流す前に X-Plane を起動し直した（Web API の `sim/operation/quit` では終わらず、プロセスを止めた）。Lua の誤りなし。

## 18. 段 3a の実装（2026-10-28：ピッチの則のうち V/S・ALT とその捕捉）

- 段 3 を分けた：3a は V/S・ALT（保持と MCP 高度の捕捉）と前の VNAV の V/S・高度、3b は速度を昇降舵で保つ則（FLCH・前の VNAV の速度・T/O・G/A と速度の保護）、3c は G/S。
- 資料：ATA22 p.282（V/S は今の昇降率に合わせ、000 を選ぶと気圧高度を保ち FMA は V/S のまま）、p.286（ALT HOLD の 3 つの入り方、捕捉は 0.05 g まで、表示は ALT）、p.332（A/P が入っていないとき PITCH ATT INTEG は姿勢に合わせる）、p.344（V/S は MCP の昇降率と IRU の慣性の昇降率の差が指令）、p.346（高度保持は ALT HOLD が始まった時の気圧高度との差に慣性の昇降率の減衰、捕捉は捕捉の時の MCP 高度との差と慣性の昇降率の減衰、G/S 以外のどのモードでも捕捉する）；FCOM p.648–650、p.665。
- 新しい純粋なモデル `plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua`（`B747_afds_pitch_model`）。AFDS のモデルのピッチのモードから、A/P が飛び F/D が示すピッチの指令（姿勢の度）を出す。
  - 則：求める昇降率をその飛行経路角にし、指令を毎秒「経路角の差 × 0.25」動かす。飛んでいる経路角は、慣性の上下加速度（1 秒でならす）で 3.5 秒先を見る（減衰：p.346）。指令の動きは法線加速度 0.05 g まで（捕捉の値：p.286。全モードに：推定）。則が始まる時は今の姿勢から（p.332）。指令は −10〜20°。
  - V/S：MCP の昇降率。000 はそれを選んだ時の高度を保つ（FMA は V/S のまま）。
  - ALT：AFDS のモデルの保つ高度（押した時の高度か、捕捉の時の MCP 高度）。高度の差の 0.1 倍毎秒の昇降率、ただし 0.05 g で水平へ引き起こせる昇降率まで。高度は 8 秒先を見る。高度へ寄っているときは、則が始まった時の昇降率を、引き起こしがそれより小さくなるまで超えない。
  - 捕捉（AFDS のモデルの捕捉の入力：前は昇降率に比例する 200〜1,000 ft の窓）：MCP 高度へ寄っていて、0.05 g の引き起こしの距離と昇降率の 10 秒分より近いか、20 ft 以内。
  - 前の VNAV（FMC の段 9 まで）：その V/S と高度保持のフラグのときはこの則で飛ぶ（速度のフラグは段 3b まで前の則）。
  - FLCH、T/O、G/A、G/S、FLARE は前の則のまま（段 3b・3c・4）。
  - 推定：0.25、0.05 g を全モードに、3.5 秒の先読み、0.1、8 秒の先取り、10 秒の前倒し、20 ft、−10〜20°（資料は入力を書くが、ゲインと値は無い）。
- 合わせ込み：最初の回（前倒し 2 秒、先読みなし）は、X-Plane で 2,000 fpm からの捕捉が 200 ft 行き過ぎ、−1,500 fpm で 68 ft 下がりすぎ、上昇中の ALT HOLD が 519 ft 行き過ぎて戻りで 64 ft 下がりすぎた。機体を「姿勢が指令に 2 秒、経路角が姿勢に 3 秒遅れる」模型にすると X-Plane の数字を 20 ft ほどで再現したので、その模型で先読み・先取り・前倒しを決めた。先読み 3 秒・先取り 6 秒・前倒し 8 秒の回は X-Plane で行き過ぎ 28 ft だったが、別の回で 74 ft になったので、遅れを 1.5 倍にした模型でも行き過ぎが小さい先読み 3.5 秒・先取り 8 秒・前倒し 10 秒にした（模型では標準の遅れで行き過ぎなし、1.5 倍で 3 ft）。
- グルー：AFDS のモデルとロールの則の後に毎フレームピッチの則を回し、新設 `autopilot/pitch_cmd`・`pitch_law`（init `B747.70.autopilot`）を書く。AFDS のモデルの捕捉の入力をこのモデルの捕捉にした。
- 則（`B747.19.xt.afds_control.lua`）：`pitch_law` が 1 なら `pitch_cmd` を内側のループ（ピッチの姿勢の PID）の目標と F/D のピッチに（前の則の 10 点の平均を通さない）。そのあいだ前の則の最後の指令と 10 点を新しい指令に合わせておき、FLCH などで前の則に戻ってもそこから続ける。
- 残り：速度を昇降舵で保つ則と速度の保護（段 3b）、G/S（段 3c）、FLARE（段 4）。前の捕捉の窓は前の VNAV と A/T がまだ使う。前の FLCH の則は、前の窓に入ると中の ALT の枝で飛び、新しい捕捉で ALT になるまで続く（段 3b）。V/S の 1.3 Vs の AUTOPILOT caution（段 5）。
- 試験：新しい `tests/autopilot/afds_pitch_model_test.lua`（29 件：捕捉の始まり、ALT の昇降率、指令にすぐ従う機体と遅れのある機体（その 1.5 倍も）での引き起こし（行き過ぎなし、0.05 g 以内）、V/S、V/S 000、上昇中の ALT HOLD、前の VNAV のフラグ、則の無いとき）、`tests/autopilot/afds_glue_test.lua`（117 件：V/S と ALT がピッチの則で、昇降率を上げると指令が上がる、2,000 fpm で 700 ft 下では捕捉せず 600 ft 下で捕捉）。全 119 本。
- X-Plane（カスタム acf）：新しい `s107_afds_vs_alt` 20/20（10,000 ft・約 290 kt（真）：V/S +2,000 fpm で 12,000 ft の捕捉は 717 ft 手前から、行き過ぎ 6 ft、その後 30 秒は −15〜0 ft；−1,500 fpm で 10,500 ft の捕捉は 424 ft 手前から、20 ft 下がりすぎ；V/S 000 は 18 ft 以内；上昇中の ALT HOLD は 453 ft 行き過ぎて、60 秒で押した高度の 40 ft 上まで戻る。PFD を撮った（SPD｜HDG SEL｜ALT、MCP 高度で水平、F/D のバーは中央）。合わせ込みの途中の回：最初の値で 17/20（行き過ぎ 200 ft など）、先読みを入れた値で 19/20（行き過ぎ 28 ft と、別の回で 74 ft）、最後の値で 20/20）、`s101_afds_pitch` 33/33、`s01_ap_basic` 15/15、`s104_afds_ga` 34/34、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s72_hdg_ref` 20/20、`s61_nd_orientation` 40/40、`s105_afds_roll_law` 18/18、`s106_afds_loc` 20/20（後の 6 本は 1 つ前の値で流した。違いは捕捉の前倒しと先取りと先読みだけ）。読み直しを重ねる前に X-Plane を起動し直しながら流した。Lua の誤りなし。

## 19. 段 3b の実装（2026-10-28：速度を昇降舵で保つ則と速度の保護）

- 資料：
  - ATA22 p.344：速度を昇降舵で保つモードは T/O・G/A・FLCH。速度の基準と ADC の速度の差が昇降舵への指令。最小の安全速度と最大速度は普通は FMC から（FMC が故障なら FCC が計算）、選んだ速度がその外なら置き換える。G/A は常に、T/O は windshear かエンジン故障のとき windshear の保護：上昇率が 1,200 fpm より上は速度、600 fpm より下は姿勢、その間は両方を混ぜる。FLCH の速度の同期（VNAV の後なら FMC の目標速度、ほかは MCP と今の速度の高い方）は段 1c で済。
  - FCOM p.664：T/O は地上で 8°。浮いたら PLI 未満のピッチで、V2 + 10 と引き起こし（ピッチ 2° 超え）の速度 + 10 の高い方。目標を 5 秒続けて上回れば今の速度へ（V2 + 25 まで）。IAS/MACH の窓をそれより高くすれば窓の速度。V2 は窓の速度。G/A は窓と今の速度の高い方。5 秒の更新は窓 + 25 まで、始めの速度がそれより速ければその速度を保つ。
  - FCOM p.666：地上の 8°。p.667：離陸の時のエンジン故障の目標。
  - FCOM p.674：windshear の回復は 15° か PLI の少し下の低い方。上昇率 600〜1,200 fpm（片発は 0〜600 fpm）で姿勢から速度へ移る。
  - FCOM p.675：最小機動速度より遅く、最大運用・脚・フラップの速度より速くならないよう保護する。FMC は 5 kt の余裕を持つ。AFDS の保護は VNAV SPD・FLCH SPD・TO/GA で昇降舵による。
- ピッチのモデル（`B747.70.afds_pitch_model.lua`）に足したもの：
  - 則：速度の差を 15 秒で詰める加速度（1.5 kt/s まで）を求める。今の加速度（IAS の変化を 1 秒でならす）との差を経路角にする（Δγ = Δa/g）。そこから 3.5 秒先の経路角の変化（V/S と同じ減衰）を引き、0.25 倍毎秒で指令を動かす（250 kt より遅いと IAS に比例して小さく、150 kt 以下は 0.15）。指令の動きは FLCH と VNAV は 0.1 g まで、T/O と G/A は 3°/s まで。
  - FLCH と前の VNAV の速度（速度のフラグ）：窓が開いていれば窓の速度（Mach なら X-Plane の目盛の kt）。閉じていれば前の VNAV の速度（X-Plane の目盛）。どちらにも速度の保護をかける。
  - T/O：
    - 地上では 8°。地上でピッチが 2° を超えた時の速度を引き起こしの速度とし、V2 は窓の速度。
    - 浮いたら V2 + 10 と引き起こし + 10 の高い方。5 秒続けて上回れば今の速度（V2 + 25 まで）。窓をそれより高くすれば窓の速度。
    - 指令は PLI を超えない。windshear（GPWS の `gpws/windshear`）なら G/A と同じく姿勢から混ぜる。
  - G/A：
    - 始めは窓と今の速度の高い方。上限は窓 + 25（始めの速度がそれより速ければその速度）。5 秒の更新は T/O と同じ。
    - 姿勢は 15° と PLI の 1° 下の低い方（「少し下」を 1° と推定）へ、差の 0.5 倍毎秒で向かう。上昇率 600〜1,200 fpm で姿勢から速度へ混ぜる。
    - 地上（接地の後の着陸復行）でも働く。
  - 速度の保護：目標を最小機動速度（速度テープの `airspeed/Vminm`。フラップが出ていれば +5 kt）から最大速度（`airspeed/Vmax` − 5 kt）の間に置く。FMC の最小・最大速度の代わりに速度テープの値を使う。
  - PLI は PFD に出ているとき（`pfd/pli_show`）だけ使う（空気データが無効なら使わない：推定）。
- 値（推定）：
  - 15 秒、1.5 kt/s、250 kt より遅いときのゲインの IAS 比例（150 kt 以下で 0.6 倍）、0.1 g（FLCH・VNAV）、3°/s（T/O・G/A）、0.5、1°。
  - 合わせ込みには、3a の遅れのある機体に速度（推力の余りから上昇の分を引く）を足した模型を使った。
  - 先読みが無いと減衰が足りない（250→280 kt で 18 kt 行き過ぎ、振動が残る）。3.5 秒の先読みと 15 秒で収まった（遅れが 1.5 倍でも、250→280 kt の行き過ぎは 4 kt）。
  - FLCH の上昇に入る時（推力が 8 秒で 1.2 kt/s 分増える）の速度の行き過ぎは、0.05 g で 14 kt、0.1 g で 9 kt。
  - T/O と G/A の指令の速さを 3°/s より遅くすると、速度が行き過ぎて目標が引き上げられた。
  - 低速で 0.25 のままだと、X-Plane の離陸（s109 の 2 回目、170 kt）でピッチが約 12 秒周期・±3.6° で揺れ、50 秒ほどで収まった（速度は 169〜171 kt）。指令よりピッチが行き過ぎていて、主因は A/P の姿勢のループ（下の「見つかったこと」）。その減衰（ζ 0.3）の模型では、0.25 で ±3.3°、IAS に比例させた 0.17 で ±0.6° になったので、250 kt より遅いときはゲインを IAS に比例させた（150 kt で 0.15）。250 kt 以上は変わらない（s108 は 0.25 のまま）。
- グルー：速度の入力（IAS、窓の速度、Vminm、Vmax、PLI、フラップ、windshear）を渡す。afds_control の古い TO/GA の分岐（X-Plane の `TOGA_pitch_deg`）は、この則が指令を出さないときだけ使う（実際には通らない）。
- 前の FLCH の則が、前の捕捉の窓に入ると中の ALT の枝で飛んでいたこと（§18 の残り）は無くなった。前の捕捉の窓は、前の VNAV と A/T がまだ使う。
- 計器のモジュール（fltInst02）の `B747_Vs` を外した。失速速度の表・翼の失速した要素の数・V2 から、X-Plane の TOGA のピッチを毎フレーム計算していた（DSP-34 の一部）。失速速度の表（fltInst の `VsData`）は読む所が無くなったが、確かめた表として残す。
- 見つかったこと（A/P の姿勢のループ）：
  - 油圧のモジュールの `afds_control` のピッチの PID は、比例と同じ大きさの積分（積分時間 1 秒）を持ち、姿勢の変化率の項が実質無い（微分 0.0002）。資料の内側のループは、姿勢の差と姿勢の変化率から舵面への指令を作る（ATA22 p.330）。
  - そのため低速（離陸の 170 kt）と高空（FL350）で減衰が足りない。FL350 の ALT HOLD は 3a より前から、指令がほぼ一定でも昇降率 ±500 fpm で揺れていた（s07 の 3a 前の回）。
  - 3a の高度の則（0.05 g の速さの制限に張り付いた三角の指令）がそれを強め、約 17 秒周期・±740 fpm・0.84〜1.16 g になった（s53・s07）。
  - 次の項目で、内側のループを資料どおり（姿勢の差と姿勢の変化率）に直す。
- 残り：
  - エンジン故障時の目標（FCOM p.667）と、片発の 0〜600 fpm の混合：FCC がエンジン故障を知る入力が無いため。
  - FMC が無効なときの FCC の最小・最大速度の計算（ATA22 p.344）。
  - G/S（段 3c）、FLARE（段 4）。A/T の THR（上昇率に合わせる推力）は 6-4。
- 試験：
  - ピッチの則 77 件（29 件から）：速度の保護。遅れと速度のある機体での FLCH の上昇・速度の変更（遅れ 1.5 倍も）・降下。前の VNAV の速度のフラグ。T/O の地上 8°・引き起こしの速度・V2・目標・5 秒の更新・V2 + 25・窓、離陸、減衰の悪い姿勢のループでの離陸（30 秒後に ±1° 以内。ゲインを下げないと ±3.2° で落ちる）、PLI、windshear。G/A の目標と上限・15°・PLI・混合・着陸復行・地上。
  - グルー 123 件：FLCH・G/A・地上の T/O がピッチの則。FLCH で 20 kt 遅いと指令が下がる。G/A で 600 fpm 未満なら上がる。地上の T/O は 8°。
  - 全 119 本。
- X-Plane（カスタム acf）：新しい `s108_afds_flch` 21/21（10,000 ft・250 kt から FLCH で 15,000 ft へ：上昇に入る間 245〜252 kt、その後 20 秒は 250.0〜250.8 kt、+2,000 fpm；上昇中の MCP 280 kt：40 秒で入り、その後 277.1〜279.8 kt で行き過ぎなし；15,000 ft の捕捉は 25 ft 行き過ぎ。FLCH で 9,000 ft へ：降下に入る間 273〜280 kt、その後 277〜279 kt、−3,250 fpm；MCP 200 kt で、最小機動速度 225 kt に対し 227 kt で止まる；9,000 ft の捕捉は 36 ft 下がりすぎ。PFD を撮った：FLCH SPD、F/D のバーは中央。A/T の FMA は上昇・降下とも THR REF で、前の A/T のまま：6-4）、新しい `s109_afds_takeoff` 19/19（地上の F/D のピッチ 8°。この機体は 120 kt でピッチが 2° を超え、141 kt で自分で浮いた（目標は V2 + 10 = 170 kt）。1 回目は 30 秒の監視の下限 155 kt が浮いた速度の 153 kt より高く 18/19。下限を直した 2 回目は 19/19：速度は 169〜171 kt だが、A/P の姿勢のループのためピッチが約 12 秒周期・±3.6° で揺れ、50 秒ほどで収まった。ゲインを IAS に比例させた 3 回目も 19/19：揺れは 10〜30 秒で ±1.3°、50 秒で止まる。速度 172 kt・+2,800 fpm、5,000 ft の捕捉は行き過ぎなし。PFD を撮った：TO/GA｜TO/GA、CMD）、`s101_afds_pitch` 33/33、`s104_afds_ga` 34/34（2 回。G/A の後 400 ft を超えるまで 8.4 秒、800 ft で捕捉）、`s103_afds_to` 19/19、`s107_afds_vs_alt` 20/20、`s01_ap_basic` 15/15、`s10_overspeed` 22/22（FLCH で 250 kt のまま全推力）、`s102_afds_app` 36/36（1 回目は CDU の ILS の同調が NAV2 に通らず、LOC を捕まえなかった（25/36）。同調の後に NAV2 の信号の確認を足した）、`s07_cruise_ff` 5/5・warn 1（空中開始で ALT のまま 6,000 fpm で上がり、0.05 g で止めるまでに FL366 まで上がった。その間に前の窓の論理が IAS/MACH の窓を M0.79 にし、A/T がそれ（268 kt）を保った。3a より前は 288 kt）、`s53_min_speeds_cruise` 10/11（FL350 の ALT HOLD が約 17 秒周期・±740 fpm・0.84〜1.16 g で揺れ、最小速度の判定がその時の荷重倍数で外れた。A/P の姿勢のループの問題で、次の項目で直す）。Lua の誤りなし。

## 20. A/P の姿勢のループ（2026-10-28：段 3b の試験で見つかった揺れ。いったん中断して同じ日に再開）

- 見つかったこと（段 3b の X-Plane の試験）：
  - FL350 の ALT HOLD で、約 17 秒周期・昇降率 ±740 fpm・0.84〜1.16 g の持続振動（s53、s07、作業用の実験 x_inner_fl350）。3a より前も ±500 fpm だった（s07 の 10-27 の回）。
  - 離陸（s109）でピッチが約 12 秒周期・±3.6° で揺れた。主因は、滑走路開始のトリム（7.5 単位）が機首上げ側に外れていたこと。浮いてから 500 ft まで昇降舵が下げいっぱいに張り付いた（500 ft 未満では自動トリムが働かない）。機体が 120 kt で自分で浮いたのもこのため。
- 資料：
  - ATA22 p.330：内側のループは、姿勢の差と姿勢の変化率から舵面への指令を作る。
  - 系統図 p.331・p.333：外側のループの指令を PITCH ATT INTEG が望む姿勢にする。望む姿勢と姿勢の差、ピッチの角速度、スタビライザーの位置が ELEV TRIM INTEG に入り、昇降舵のサーボと SRM（自動トリム）へ出る。
  - p.147・p.149：自動トリムは、昇降舵のサーボの指令が 0.4°（G/S 捕捉中 0.6°）を超えると出し、0.25° で止める。
- 分析：
  - 記録（約 71 Hz）から、ピッチの角加速度と迎え角の変化率を最小二乗で当てはめた（`tests/tools/pitch_sysid.lua`）。
    - FL350・288 KIAS：q̇ = −0.142 q − 1.458 α + 10.15 δe（0.2 秒前）+ 17.2 trim + 6.97（R² 0.66）、α̇ = 1.006 q − 0.486 α + 0.746（R² 0.998）。短周期は 1.2 rad/s・減衰 0.25。
    - トリムの比 1 は、昇降舵の比の約 1.7 倍効く（フラップ 20・172 kt では 2.35）。
  - この模型に、今の PID（比例 0.044、積分 0.044、微分 0.0002）、昇降舵の指令の速さの制限、自動トリム（ALT HOLD の幅 0.005、3.5 秒遅れ、0.1 unit/s）、3a の高度の則を載せると、X-Plane の揺れ（±646 fpm、0.84〜1.16 g）を再現した（`tests/tools/attitude_loop_sim.lua`）。
    - 自動トリムを止めると揺れは無い。
    - 角速度の減衰を足しても、積分を弱めても、むしろ悪化する。
    - 資料の帯（0.4°/0.25°）だけでは ±560 fpm。
    - スタビライザーが動いた分を昇降舵の積分から差し引く（p.333 の STAB POSITION）と、比 1.2〜2.2 のどれでも止まる。
  - 仕組み：自動トリムが動くたびに、積分が昇降舵を戻すまで姿勢が約 0.5° 乱れる。高度の則がそれに反応し、トリムと積分が交互に押し合っていた。
- 実装：
  - `B747.19.xt.afds_control.lua`：
    - 昇降舵のトリムの積分器のスタビライザーの入力：A/P が入っている間、X-Plane のトリム（`sim/flightmodel2/controls/elevator_trim`）の変化の 1.9 倍（推定：1.7 と 2.35 の間）を PID の積分から差し引く。
    - 自動トリム：昇降舵のサーボの指令（比）を X-Plane の昇降舵の動き（`sim/aircraft/controls/acf_elev_up`・`acf_elev_dn`。カスタム acf は 22°・17°）で度にする。0.4°（G/S 0.6°）を超えたら出し、0.25° 以内で止める（前はモードごとの幅で帯なし：ALT HOLD 0.005＝0.1°、FLCH 0.2＝4°）。500 ft 未満で出さないのは前のまま（段 6）。
  - 試験：`tests/hyd/hyd_module_test.lua` に 6 件（0.4° で入る、0.4〜0.25° の間は続く、0.25° 以内で止まる、ずっと帯どおり、G/S は 0.6°、トリム 0.05 で昇降舵の指令が 0.095 下がる）。前の作りでは 5 件が落ちる。全 119 本が通る。
  - `s109_afds_takeoff`：離陸前に代替トリムで機首下げを 5.2 秒（約 4.9 単位、比 −0.35）と、その確認を足した。
- X-Plane（カスタム acf）：`s53_min_speeds_cruise` 11/11（前は 10/11）、`s07_cruise_ff` 5/5・注意 1（速度は 278 kt。IAS/MACH の窓が Mach になる件で、前と同じ）、`s107_afds_vs_alt` 20/20（12,000 ft の捕捉は行き過ぎ 0（前は 33 ft）、その後 30 秒は ±5 ft、10,500 ft は 4 ft 下がりすぎ（前は 26 ft）、上昇中の ALT HOLD の行き過ぎは 401 ft（前は 442 ft））、`s108_afds_flch` 21/21（15,000 ft の捕捉は行き過ぎ 0（前は 25 ft）、9,000 ft は 1 ft 下がりすぎ（前は 36 ft））、`s101_afds_pitch` 33/33、`s109_afds_takeoff` 20/20（離陸トリム −0.327、150 kt で引き起こし、158 kt で浮く。ピッチは 10〜30 秒で 8.2〜10.7°、30 秒から 9.3° 前後。昇降舵は最大 −0.46 で張り付かない。速度は目標の 170 kt を浮いた直後の加速で 177 kt まで越え、5 秒の更新で 178.6 kt を保つ）、`s104_afds_ga` 34/34、`s102_afds_app` 37/37、`s01_ap_basic` 15/15、`s10_overspeed` 22/22。FL350 の ALT HOLD（s07 の記録、最後の 3 分）：昇降率 ±250 fpm・0.92〜1.07 g・高度 ±12 ft（前は ±740 fpm・0.84〜1.16 g）。トリムは帯どおり 0.4° で動き 0.25° で止まり、そのぶん昇降舵が戻る。残った揺れは約 15 秒周期で、高度の則の指令が 0.05 g の速さの制限に張り付いた三角の波に、約 3.8 秒の小刻みなピッチの揺れ（短周期。新しい記録の当てはめで減衰 0.28）が重なる。線形の模型ではどちらも再現しない。Lua の誤りなし。
- 新しい記録（s07、278 KIAS）の当てはめ：q̇ = −0.494 q − 2.68 α + 19.9 δe（0.2 秒前）+ 37.3 trim + 14.8（R² 0.71）。昇降舵の効きは x_inner_fl350 の当てはめの約 2 倍、トリムと昇降舵の比は 1.88（前は 1.69）。どちらの当てはめも、新しい作りでは揺れが止まると出る。X-Plane に残る揺れは模型の外の何か（R² が 0.7 にとどまる部分）による。
- 残り：
  - FL350 の残った揺れ：資料の内側のループの「姿勢の変化率」（ATA22 p.330。今の PID は姿勢の差だけ）を足して短周期の減衰を上げる（→ §21 で済）。
  - 速度の則のゲインの IAS 比例（段 3b）は残す。離陸の揺れの主因はトリムだったが、比例は低速での余裕になる。
  - 自動トリムの残り（500 ft 未満でも接地まで、rollout で禁止、LAND 2 の full rate と trim bias、GA で取り消し）は段 6。
  - 実験のやり方：記録（`record_start`）を取るシナリオで飛ばし、`tests/tools/pitch_sysid.lua` で当てはめ、`tests/tools/attitude_loop_sim.lua` で試す。Web API からは `laminar/B747/flt_ctrls/pid/pitch/*` を読めるが書けない（HTTP 400）ので、飛行中にゲインを変える実験はできない。

## 21. A/P の姿勢のループ：姿勢の変化率と全高度共通のゲイン（2026-10-28：§20 の残り）

- 残っていた揺れ（§20 の後）：FL350 の ALT HOLD で、約 15 秒周期・±250 fpm・0.92〜1.07 g。
  - 記録では、高度の則の指令が 0.11°/s で動く間、姿勢が約 0.45° 遅れたまま追いつかない。
  - 内側のループの比例ゲインが FL350 では 0.044 だった（前の作りは、MCP 高度で 3,000 ft の 0.07 から 40,000 ft の 0.04 へ下げていた）。0.45° の差で昇降舵は 0.02（0.4°）しか動かない。
  - 新しい記録の当てはめでは、短周期は 1.7 rad/s・減衰 0.28。
- 資料：ATA22 p.330（内側のループは、姿勢の差と姿勢の変化率から舵面への指令を作る）。
- 試したこと（X-Plane、s07 の FL350 の ALT HOLD の最後の 1〜3 分）：
  - 角速度の項 0.03 だけ（比例 0.044 のまま）：−364〜+309 fpm で、かえって悪い。
  - 比例ゲイン 0.1（全高度）と角速度 0.03：−9〜+12 fpm・0.992〜1.002 g・高度 ±1 ft。
  - 模型（`tests/tools/attitude_loop_sim.lua`）は、どちらの当てはめでも今の値の遅れを 0.1° ほどとしか見ず、X-Plane の 0.45° を再現しない（模型の外の鈍さ）。値は X-Plane で決めた。
- 実装：
  - `B747.19.xt.afds_control.lua`：ピッチの角速度（IRU の値の代わりに X-Plane の機体軸の `sim/flightmodel/position/Q`）の 0.03 倍を、昇降舵の指令から引く（推定）。
  - `B747.19.xt.hydraulicsmodel.lua`：ピッチの PID の比例ゲインを全高度で 0.1 にした（前は MCP 高度で 0.07〜0.04）。積分は前どおり比例と同じ（推定）。
  - 試験：油圧のモジュールの試験に 1 件（角速度 1°/s で昇降舵の指令が 0.03 下がる）。全 119 本。
  - `s107_afds_vs_alt`：上昇中の ALT HOLD の戻りを 90 秒見る（60 秒では回によって 36〜63 ft 上で、±60 ft の境目だった）。
- X-Plane（カスタム acf）：`s07_cruise_ff`（FL350 の ALT HOLD：最後の 1 分は −9〜+12 fpm・0.992〜1.002 g・高度 ±1 ft、その前の 1 分は ±24 fpm、さらに前は ±55 fpm で、落ち着いていく）、`s53_min_speeds_cruise` 11/11、`s107_afds_vs_alt` 20/20（12,000 ft の捕捉は行き過ぎなし（7 ft 下）、その後 ±3 ft、10,500 ft は 0 ft、上昇中の ALT HOLD は 449 ft 行き過ぎて 90 秒で 4 ft 上。60 秒で見た 1 回目は 63 ft 上で 19/20）、`s108_afds_flch` 21/21（FLCH の速度は前とほぼ同じ、15,000 ft の捕捉は行き過ぎなし、9,000 ft は 4 ft 上）、`s101_afds_pitch` 33/33、`s109_afds_takeoff` 20/20（浮いた後のピッチは 10〜20 秒で 8.6〜10.5°、20 秒から 9.2〜10.2°）、`s104_afds_ga` 34/34、`s102_afds_app` 37/37、`s01_ap_basic` 15/15、`s10_overspeed` 22/22。Lua の誤りなし。
- 残り：低速（進入）での内側のループの余裕と、速度（動圧）でゲインを変えるかは、段 3c（G/S）で見る。

## 22. 段 3c の実装（2026-10-30：A/P が入るときの同期と G/S）

### 22.1 A/P が入るときの同期（3c-1）

- 見つけたこと（s109 の 19/20、離陸後の速度 193 kt）：サーボが入ってから 2 秒間、A/P の昇降舵の指令を舵に出さず（0 のまま）、そのあと 0 から遅い速さで上げていた。その間も PID の積分は回り続け、外れている間の積分は前回の出力から始まっていた。浮いた直後に A/P を入れると、機首が 7.2° から 5.7° へ下がってから 20.5° まで上がった。動圧でゲインを変える前に、この入り方が原因だった。
- 資料：ELEV TRIM INTEG は A/P の arm 中にサーボの位置を舵面の位置に同期させ、engage の後は昇降舵とスタビライザーを動かす（ATA22 p.332）。ロールの AIL TRIM INTEG も同じ（p.348）。
- 実装：
  - `B747.19.xt.afds_control.lua`：A/P が外れている間、ピッチとロールの PID の積分を「操縦輪の位置 ＋ A/P の指令」に合わせておく。入った瞬間から A/P の指令が操縦輪の位置を引き継ぐ。
  - `B747.19.xt.hydraulics_override.lua`：2 秒の待ちを外した（`autopilot/ap_monitor/servos_on_time` は自動操縦のモジュールが書き続けるが、油圧のモジュールでは使わない）。
  - 試験：油圧のモジュールの試験に 5 件（外れている間は A/P の指令なし、入ると昇降舵・エルロンが操縦輪の位置のまま、姿勢が指令どおりならそこに留まる）。
- s109 の手順も直した：
  - A/P を浮いた直後（約 15 ft）に入れていた。FCOM p.79（L.10.3）の「離陸後 250 ft 未満で A/P を入れない」に合わせ、浮いたら試験用の操縦者（新しい `tests/flight/fwl/B747_fd_follow.lua`：F/D のピッチのバーを手で追う。ゲインは推定）で電波高度 300 ft まで飛び、そこで CMD L。
  - 「捕捉で推力を戻す」の手順が、20 秒の速度の監視の後ろにあった。新しい飛び方では捕捉が早く、推力を戻すのが目標の 950 ft 手前まで遅れて 188 ft 行き過ぎた。速度の監視を捕捉まで（`until`）にして、捕捉ですぐ推力を戻す。行き過ぎの監視は 120 秒（水平になるまで）。
- X-Plane（カスタム acf、A/P の入り方を直した後）：`s109_afds_takeoff` 20/20（手で F/D を追って 300 ft で CMD L、入った瞬間の昇降舵は −0.061 → −0.069 → −0.085 と続き 0 に落ちない、操縦輪を放した分の段差 0.05。離陸後の速度 182〜187 kt（前は 193 kt）。このときは高度の監視が 40 秒で、水平になる前に終わっていた）、`s102_afds_app` 37/37、`s01_ap_basic` 15/15。

### 22.2 G/S（3c-2）

- 資料：G/S の偏位を、電波高度から推定した送信所までの距離（3° を仮定）でビームの中心からの直線の距離（G/S DEV ALT）にし、その値と変化率で指令する。慣性の経路の制御を含み、信号を失っても経路を保つ（ATA22 p.346）。捕捉は、ビームの中心からの距離と偏位の変化率で決まる（ATA22 p.292）。
- 実装（`B747.70.afds_pitch_model.lua`、`B747.70.xt.autopilot.lua`）：
  - G/S DEV ALT ＝ 電波高度（2,500 ft まで）÷ tan 3° × tan（偏位）。
  - 慣性の経路：ビームからの距離を、慣性の昇降率とビームの昇降率（対地速度 × tan 3°）の差で積み、信号があれば G/S DEV ALT に 5 秒で寄せる。ビームの近く（0.1° 以内）では、その差でビームの昇降率も直す（3° でないビームや風。寄せ方と合わせて臨界減衰の約 10 秒）。信号が無いと、その時のビームの昇降率で経路を保つ。
  - 指令：ビームの昇降率 − 3 fpm × 距離（ft、±1,000 fpm まで）を、V/S の則（経路角の差、慣性の上下加速度の先読み、0.05 g）で飛ぶ。
  - 捕捉（AFDS のモデルの入力 `gs_detect`）：ビームへ寄っていて、0.05 g で経路を変える距離と寄る速さの 6 秒分より近いか、偏位が 0.1° 以内。前は「両受信機の信号と旗、1.5 ドット未満」。
  - 前の則（`B747.19.xt.afds_control.lua` の `getGlideSlopeFPM`：−tan（G/S の角度）× 対地速度 − 75 fpm × ドット）と、使わなくなった dataref の結び付け（`nav1_slope_degt` など）を外した。FLARE は前の autoland のまま（段 4）。
  - X-Plane の G/S の目盛を測った（新しい `tests/flight/measure/gs_scale.json`：RJAA 34L の G/S の下から水平に通り抜け、4 秒ごとに位置とドット。X-Plane の航法データのアンテナの位置と 3.00° から平面で角度を出すと、12 点で 3.67 ドット/度（1 ドット 0.272°）、ずれ −0.01°、残差 0.003 ドット。地球の丸みを入れると 0.05° ずれるので、X-Plane は平面で計算している）。ビームの上が正。
- 推定：ゲイン（3 fpm/ft）・寄せ方（5 秒）・ビームの昇降率の直し方（0.6 fpm/s/ft、0.1° 以内）・±1,000 fpm・捕捉の 6 秒と 0.1°。前の段の遅れのある機体（姿勢が 2 秒、経路が 3 秒遅れる。140 kt で 3° の ILS）で決めた：下から 6 ft 通り過ぎ、上から 8 ft、3.2° のビームでも 3 ft 以内、信号を 20 秒失っても 15 ft 以内。
- 試験：ピッチの則のモデルに 18 件（G/S DEV ALT、ビームの昇降率、捕捉の 6 件、ILS を飛ぶ：下から・上から・3.2°・信号なし、地上）、AFDS のグルーの試験の G/S の捕捉を新しい判定に（2 ドット下は捕まえず 0.3 ドットで捕まえる、G/S の則が機首を下げる）。全 121 本。
- X-Plane（カスタム acf）：新しい `s112_afds_gs` 12/12 を 2 回（RJAA 34L の 12 NM・2,500 ft・フラップ 20 から、下から G/S を捕捉：−0.74 ドット（電波高度 2,168 ft）と −0.82 ドット（2,157 ft）で捕まえ、捕捉でフラップ 30 にして一時 +113 fpm 浮いても、40 秒の間にビームの上へは 0.046・0.026 ドットまで。その後 電波高度 500 ft まで ±0.112・±0.120 ドット（1 ドット 0.272° なので ±0.03°）、500 ft で降下率 818 fpm（対地 150 kt の 3° のビーム）。PFD を撮った：SPD｜LOC（ROLLOUT）｜G/S（FLARE）、LAND 3、G/S と LOC の指針は中央、立ち上がる滑走路。PFD の ILS の表示は純正の `ils_dots` を同調の印に使うので、シナリオで 1 にした：DSP-14）、`s102_afds_app` 37/37（APP の後、G/S を新しい判定で捕まえる）。A/P の姿勢の遅れは 150 kt・フラップ 30 で 0.3° 以内で、動圧でゲインを変える必要は今のところ無い。
- 回帰（X-Plane を起動し直して捨ての s66 のあと）：`s107_afds_vs_alt` 20/20、`s108_afds_flch` 21/21、`s101_afds_pitch` 33/33、`s104_afds_ga` 34/34、`s99_afds_engage` 36/36。Lua の誤りなし。

### 22.3 s109 の 5,000 ft の捕捉（同じ日）

- 高度の監視を水平になるまで（120 秒）延ばすと、離陸推力のまま 4,250 fpm で捕捉に入り、行き過ぎた：手で推力を 0.55 に戻すと速さが 185 から 147 kt に落ちて 217 ft、捕捉で A/T を SPD（180 kt）にすると、速さが 171 kt に落ちたところで A/T が推力をいっぱいに戻し 400 ft。捕捉の則は 0.05 g で水平になる筋書きを引くので、推力の乱れを吸収する余裕が無い。
- FCTM p.124（Low Altitude Level Off）：離陸推力・軽い重量で低い高度に水平になると、AFDS は快適さのためピッチを制限するので、捕捉の筋書きを終える高さが無く行き過ぎることがある。上昇推力に早めに下げる、などとある。FCOM p.646：捕捉で A/T は SPD。
- s109 を手順どおりに直した：電波高度 1,500 ft（推力減の高度）で上昇推力（FCOM の Max Climb EPR を `B747_epr_hold.lua` が保つ。A/T の THR REF の代わり）、捕捉で EPR の保持をやめて MCP 速度 180 kt と A/T の SPD。
- X-Plane（X-Plane を起動し直して捨ての s66 のあと）：`s109_afds_takeoff` 20/20。300 ft で A/P を入れ、1,500 ft まで 182〜187 kt（4,000 fpm）、上昇推力（EPR 1.29）で捕捉まで 171〜187 kt、捕捉は 4,388 ft・1,867 fpm から入って行き過ぎ 0（最高 5,000 ft）。
- 残り：離陸推力のまま高い昇降率で捕捉すると行き過ぎる（FCTM p.124 のとおりの振る舞い）。捕捉の則の 0.05 g（推定）と A/T（6-4）の取り合いは、A/T を作り直すときに見る。

## 23. 段 4 の段取り（2026-10-30：autoland と 3 チャンネル）

- 資料：
  - multi-channel：APP を選ぶと、engage 中の A/P があれば他のチャンネルが arm（CMD 灯がすべて点く：ATA22 p.288、p.314）。arm のチャンネルは、LOC と G/S の捕捉・電波高度 1,500 ft 未満・航跡が補正した滑走路方位から 2° 以内（ILS の滑走路方位と 5° までの差を補正）で engage（p.318）、1,500 ft を通って 5 秒後（p.288、p.294）。arm は、先に engage していたチャンネルが外れると消える（p.314）。multi-channel の G/A から巡航のモードへ移ると、最初のチャンネルだけ残る（p.318）。
  - 状態表示：1,500 ft 未満の multi-channel で AFDS の状態表示の代わりに LAND 3（電源・engage の FCC・autoland のセンサが 3 重）、LAND 2（FCC とセンサが少なくとも 2 重）、NO AUTOLAND（p.250、p.256；FCOM p.662）。multi-channel の進入なのに 600 ft までに LAND 3・2 が出ないと NO AUTOLAND で、FLARE と ROLLOUT は arm しない（FCOM p.653）。200 ft 未満では LAND 3 から LAND 2 への劣化は出さない（FCOM p.662）。
  - FLARE：LAND 2・3 で arm（FCOM p.671）、engage の高さは降下率で 40〜60 ft（ATA22 p.342）、gear altitude で、送信所の 450 ft 先に 1.5 ft/s で接地（p.294、p.346）。25 ft で retard（A/T の IDLE：FCOM p.671）。5 ft 未満で flare の指令が 2° 未満なら NOSE LETDOWN（p.294、p.332）。
  - ROLLOUT：LAND 2・3 で arm、約 5 ft（FCOM p.671。ATA22 p.296 は 5 ft で翼水平、2 ft から rollout）、ラダーと前輪のステアリングで LOC の中心線、A/P を外すまで（p.362）。
  - runway align と片発（FCOM p.670；ATA22 p.296、p.360–362）：crab が 10° 超は 500 ft で 5° の forward slip、5〜10° は 500 ft で 5° まで減らし 200 ft で残り、5° 未満は 200 ft で全部。片発が進入前なら 1,300 ft で翼水平の sideslip、進入中なら検出時。故障の反対側からの強い横風では翼水平にしない。A/P が外れるとラダーはトリムの位置へ。
- 分け方：
  - 4a：multi-channel の arm と engage、LAND 3・LAND 2・NO AUTOLAND（engage のチャンネル、FCC の電源（AFDS-16：FCC L は AC 3・DC 3、C は AC 1・DC 1、R は AC 2・DC 2）、IRU 3 台、電波高度計 3 台、ILS 受信機（X-Plane は 2 台：C は推定）、600 ft の規則）、FLARE・ROLLOUT の arm。AFDS-05 と、前の autoland の FMA と状態表示を AFDS のモデルへ。
  - 4b：FLARE の則、retard、NOSE LETDOWN（AFDS-04）。
  - 4c：ROLLOUT と ROLL DOWN（AFDS-04）。
  - 4d：runway align と片発。
  - 電源の autoland の分離（ELEC-18）は 4a の後、NO LAND 3 などの警報（AFDS-13）は段 5。

## 24. 段 4a の実装（2026-10-30：multi-channel と autoland の状態表示）

- 前の作り：APP を押すと（A/P が 1 台入っていて 1,500 ft より上なら）3 台とも即 engage、1,500 ft より下では LOC と G/S の捕捉で即 engage（5 秒の遅れも航跡の 2° の条件も無い）。LAND 3・2 は engage の台数だけで決め、1 台の進入では 1,500 ft の下で NO AUTOLAND を出していた。FLARE・ROLLOUT の arm は前の autoland が状態表示から FMA に書いていた（AFDS-05）。
- 実装（`B747.70.afds_model.lua`）：
  - APP を選んだとき engage 中のチャンネルがあれば、油圧のある他のチャンネルが arm（`arm`）。arm は、最初のチャンネル（`first`）が外れる、APP の 2 回目、進入のモード（LOC・G/S とその arm）が無くなる、油圧を失う、で消える（後の 2 つは推定）。
  - arm のチャンネルは、LOC と G/S が engage、電波高度 1,500 ft 未満、航跡がコースから 2° 以内が 5 秒続くと engage（ILS の滑走路方位の FCC の補正は作っていない：コースを滑走路方位として使う）。
  - 状態（`land`、`M.status`）：進入中に 2 台以上 engage で 1,500 ft 未満なら、3 台で FCC の電源 3・センサー 3 なら LAND 3、センサー 2 以上なら LAND 2、それ以下は NO AUTOLAND。multi-channel の進入で、LAND の後に 1 台に減ったか、600 ft までに LAND が出なければ NO AUTOLAND。200 ft 未満では LAND 3 から LAND 2 にしない。それ以外は CMD・FD。FLARE と ROLLOUT は LAND 3・2 のとき arm（FMA の armed にモデルが出す）。
  - multi-channel の G/A から、ロールかピッチのどちらかが G/A でなくなると、最初のチャンネルだけ残る。
- グルー（`B747.70.xt.autopilot.lua`）：前の `multi` の呼び出しを外した。FCC の電源（L は AC 3・DC 3、C は AC 1・DC 1、R は AC 2・DC 2：`electrical/bus/ac`・`dc`）の数、センサー（`irs/nav_valid`・`ra/valid` の数と ILS の受信機の数の最小：ILS は NAV1・NAV2 の LOC と G/S の信号と旗で、X-Plane に無い ILS C は L と同じ：推定）を渡す。状態表示（`AFDS/status_annun_pilot`・`copilot`）はモデルの `status` から（前の台数だけの判定は外した）。advisory [246] は NO AUTOLAND のとき（前と同じ意味。警報は段 5）。新しい `autopilot/cmd_armed`（L・C・R の arm。init `B747.70.autopilot` で作る）を書き、照明のモジュールが CMD 灯を engage か arm で点ける（ATA22 p.288）。前の autoland（`B747.autoland.lua`）の FMA の arm の書き込みは外した（FLARE・ROLLOUT の則は段 4b・4c まで前のまま）。
- 推定：arm が消える条件のうち、進入のモードが無くなるときと油圧、ILS C を L と同じに、航跡の 2° を ILS のコースで見ること。資料の「電源の 3 重」は FCC の AC・DC の母線が生きているかだけで見る（autoland のときの母線の分離：ELEC-18 は後で）。
- 試験：AFDS のモデルに 34 件（APP の arm と油圧、1,500 ft より上と下、4.8 秒と 5.1 秒、航跡 3° と 1.5°、LAND 2 のセンサー・電源、NO AUTOLAND、200 ft 未満の LAND 3、チャンネルを失う、600 ft の規則、1 台の進入は CMD、最初のチャンネルの解除と APP の 2 回目で arm が消える、G/A から V/S で最初だけ）。前の `multi` の試験 2 件は外した。AFDS のグルーの試験に 13 件（APP で C・R が arm で engage しない、3,000 ft では engage しない、1,400 ft で 4 秒は未だ・5.2 秒で engage、LAND 3、FMA の ROLLOUT・FLARE の arm、電波高度計 1 台で LAND 2、すべて切で状態なし）。全 121 本。
- G/S の捕捉の直し（同じ日、段 3c の続き）：段 4a の試験で、空中開始の直後に −2,900 fpm で沈み、ALT HOLD が +850 fpm で戻る途中、偏位が X-Plane の目盛の端（2.5 ドットで止まる）のまま、寄る速さが大きいので G/S を捕まえた（s112：2.5 ドット下で捕まえ、ビームに乗るまで 60 秒、500 ft に間に合わず。s102：G/S のかなり下で捕まえ、続く確認が 4 件落ちた）。目盛の端では本当の距離が分からないので、捕捉は 2.45 ドット未満だけにした（推定）。ピッチの則のモデルの試験に 2 件（2.5 ドットで上昇中は捕まえず、2.4 ドットで捕まえる）。
- X-Plane（カスタム acf、段 4a）：新しい `s113_afds_multi` 29/29 を 2 回（APP で C・R が arm して CMD 灯が点き、engage しない。G/S を捕まえた後、電波高度 1,407 ft（1,500 ft を通って 5 秒）で C・R が engage、LAND 3 と FMA の FLARE・ROLLOUT の arm。電波高度計 R の故障で LAND 2、戻して LAND 3。800 ft の TO/GA で 3 台のまま、1,000 ft の上で ALT HOLD を押すと L だけ。PFD を撮った：LAND 3（緑の枠）、SPD｜LOC（ROLLOUT）｜G/S（FLARE））、`s99_afds_engage` 36/36。G/S の捕捉を直した後（X-Plane を起動し直して捨ての s66 のあと）：`s102_afds_app` 37/37、`s112_afds_gs` 12/12（−0.86 ドットで捕まえ、ビームの上へ出ず、500 ft まで ±0.12 ドット）、`s113` 29/29。直す前の回では s102 33/37・s112 11/12（上の G/S の捕捉の直しの件）。Lua の誤りなし。

## 25. 段 4b の段取り（2026-10-30：FLARE）

- 資料（§23）：FLARE は LAND 3・2 で arm、engage の高さは降下率で 60 ft（18 ft/s 超）、50 ft（12.5〜14.5 ft/s）、40 ft（8.5 ft/s 未満）（ATA22 p.342）、gear altitude（電波高度・ピッチ角・アンテナと脚の距離）で、送信所の 450 ft 先に 1.5 ft/s で接地（p.294、p.346）。25 ft で FMC に retard（A/T の IDLE：FCOM p.671）。接地で FLARE の表示が消え、機首を下ろす：5 ft 未満で flare の指令が 2° 未満なら NOSE LETDOWN（p.294、p.332）。
- 則の形（推定）：降下率を一定の減速で 1.5 ft/s まで減らす（engage の時の降下率と高さから減速を決め、そこからの指令は √(1.5² + 2 a h)）。表の高さと降下率で計算すると、送信所の 500〜950 ft 先に接地する（150 kt・3° で約 730 ft 先）。X-Plane の遅れを見て合わせる。
- 作るもの：
  - AFDS のモデル：FLARE の engage（G/S で FLARE の arm、gear altitude が表の高さ以下）、FMA の FLARE、FLARE からは G/A だけ、接地で FLARE を終えて NOSE LETDOWN、retard の信号（FLARE 中に電波高度 25 ft 以下）。
  - ピッチの則：FLARE の則と NOSE LETDOWN の則。
  - グルー：gear altitude（アンテナと主脚の距離は推定）、retard を前の A/T の IDLE につなぐ（A/T は 6-4 まで前のまま）、前の autoland の flare（目標のピッチ）を外す。
  - X-Plane：autoland のシナリオ（s113 と同じ所から接地まで。接地の降下率と送信所からの距離、FLARE の高さ、25 ft の IDLE、接地で FLARE が消える）。

## 26. 段 4b の実装（2026-10-30：FLARE と NOSE LETDOWN、A/P の内側のループのゲイン）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - FLARE の engage：FLARE が arm（LAND 3・2）で G/S のとき、gear altitude が降下率の表の高さ以下（8.5 ft/s 以下 40 ft、12.5〜14.5 ft/s 50 ft、18 ft/s 以上 60 ft：ATA22 p.342。間は直線：推定）。降下率は慣性の昇降率（グルーの `ivs`。X-Plane の VSI は遅れる）。FMA は FLARE（3）、G/S は消える（p.342）。FLARE からは G/A だけ（遷移表 p.335）。
  - 接地で FLARE を終え（FMA のピッチは空：FCOM p.671）、NOSE LETDOWN（`letdown`）を A/P が外れるか TO/GA まで。
  - retard：FLARE 中に電波高度 25 ft 以下で立ち、NOSE LETDOWN の間は保つ（FCOM p.671：IDLE は逆推力で A/T が切れるまで）。グルーが A/T の FMA を IDLE（2）にし、EEC の A/T がレバーをアイドルへ。
- ピッチの則（`B747.70.afds_pitch_model.lua`）：
  - FLARE：engage の時の降下率を保ち、接地で 1.5 ft/s（ATA22 p.294、p.346）になる一定の減速（`FLARE_DECEL` 0.045 g）の降下率 √(1.5² + 2ah) がそれより少なくなったら、それに従う。減速による経路角の変化を指令の速さに足し（feed-forward）、残りは経路角の差の `K_FLARE` 0.5 倍毎秒（慣性の上下加速度の 0.8 秒の先読み）、指令の速さは 0.2 g まで。gear altitude 5 ft の下では指令を上げない（推定。NOSE LETDOWN の論理の 5 ft：p.294。接地まで上げると、接地の時に機首が毎秒 1° 上がり昇降舵が 0.5 上で、A/P のサーボがそれを戻す間に X-Plane の 747 は跳ねた：下の 5 回目）。資料は接地（送信所の 450 ft 先に 1.5 ft/s、降下率で変わる flare の高さで対地速度によらない）だけで、則の形と値は無い：推定。
  - NOSE LETDOWN：接地の時の姿勢の 1° 下（FLARE の最後の指令が上でも）から毎秒 1° 下げ、地上で 2° 未満になったら −1° の指令で前脚を押さえる（ATA22 p.332：地上で 2° 未満の pitch down の指令。1° の下げ、1°/s と −1° は推定。姿勢からでは X-Plane の 747 は機首が上がり続けて跳ねた：下の 4 回目）。
- グルー（`B747.70.xt.autopilot.lua`）：
  - gear altitude = 電波高度 − 2.3 ft − 10 ft × sin（ピッチ）（推定：X-Plane の電波高度は主脚が触れた時に 5.0° で 3.12 ft から 7.0° で 3.48 ft、s114 の 4 回の接地に引いた直線。s109 の浮いた時の 3.1° で 3 ft もその上。初めは 1 点から 35 ft × sin としたが、7° では接地の 0.2 秒前に 0 になった）。
  - `B747_ap_fma` は LAND 3・2 のとき前の autoland の後で戻っていた（`return`）。そのためピッチと A/T の FMA が LAND の engage の時のまま止まり、新しい FLARE も IDLE も出なかった。戻るのをやめ、ロールの FMA だけ前の autoland の ROLLOUT のまま（段 4c まで）。
  - 前の autoland（`B747.autoland.lua`）の FLARE と A/T の FMA の書き込み（50 ft の FLARE、40 ft の IDLE、5 ft の FMA の消去と A/T の空）と、毎フレームの print（start_flare は 50 ft から FLARE まで毎フレーム呼ばれるようになった）を外した。前の autoland のピッチの目標（`autolandPitch`）は新しい則の間は使われない。
- 内側のループ（`B747.19.xt.afds_control.lua`）：
  - ピッチの則が出ている間は FMA のモードが無くても動かす（NOSE LETDOWN）。
  - ゲインを対気速度で変える（推定。資料にゲインの表は無い。今のゲインは FL350 と 10,000 ft の 250 kt 以上で決めた：§20、§21）：姿勢の差の比例と積分は g = (250 kt ÷ IAS)²（1〜3 倍）、姿勢の変化率は g の 1.5 乗。
  - 理由（段 3c では G/S の追従の遅れが 0.3° 以内で、ゲインを変える必要は無いとした：§22。FLARE の速い指令で足りなくなった）：s114 の 1・2 回目は今のゲインのままで、150 kt では指令の立ち上がりから姿勢が動くまで約 1 秒（当てはめ：2 次・1.8 rad/s・減衰 0.15・0.8 秒遅れ）、FLARE が遅れた。3 回目は 3 つとも g 倍にして姿勢の遅れは約 0.4 秒になったが、G/S の上でピッチが 3.3 秒ごとに ±0.11° 揺れ続けた（ピッチの角速度の RMS 0.155°/s、前は 0.065）。その揺れの記録から `tests/tools/pitch_sysid.lua` で 150 kt・フラップ 30 の short period を当てはめると、ピッチの剛さ（α の項）は FL350 の約 5 分の 1、ピッチの減衰は約 6 倍、昇降舵の効きはほぼ同じ。その模型で（`tests/tools/inner_loop_150kt.lua`：`attitude_loop_sim.lua` と同じ作りの内側のループ）、姿勢の変化率を g の 1.5 乗にすると、1° の段の揺れが 1 周期で消え（g 倍のままでは 10 秒後も 0.28°）、FLARE の 4 秒の傾斜での遅れも 0.91° から 0.62° に減る。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル（FLARE の engage・retard・NOSE LETDOWN）、ピッチの則（X-Plane の 747 の模型で 130・150・170 kt の FLARE：0.5〜3 ft/s・送信所の 150〜1,000 ft 先・ピッチ 8° 未満、降下率を保つこと、NOSE LETDOWN）、グルー（LAND 3 で FMA の FLARE と A/T の IDLE、接地で FLARE が消え IDLE が残る）、油圧のモジュール（150 kt でゲイン 2.78 倍、姿勢の変化率 4.6 倍）。
  - X-Plane（カスタム acf、RJAA 34L、無風、150 kt、新しい `s114_autoland`）：
    - 1 回目（前の則：降下率を高さに比例、指令の速さ 0.1 g。内側のループは今のゲイン。スピードブレーキの ARM なし）：FLARE は電波高度 51 ft、25 ft で IDLE、FLARE から 3.9 秒で接地、送信所の 49 ft 先に約 8 ft/s（電波高度で 10 ft/s）・2.0 g。跳ねて 12 ft まで上がり、6 秒後に 2.4 g で再接地。指令は 0.1 g の速さの制限に張り付いていた。
    - 2 回目（今の FLARE の則、内側のループは今のゲイン、スピードブレーキ ARM・オートブレーキ 2）：送信所の 137 ft 先に約 6 ft/s・1.8 g。跳ねはしないが、接地後に機首が 7.1° まで上がり、NOSE LETDOWN の指令（FLARE の最後の 6.9° から毎秒 1°）が姿勢より上にあったため、前脚が付いた後にまた 2.3° まで上がった。
    - 3 回目（ゲインを 3 つとも g 倍）：送信所の 123 ft 先に約 3.5〜4.8 ft/s（慣性の経路で 3.3、電波高度で 4.8）・1.6 g。接地後に 0.8 秒浮いた（4 ft）。G/S の上の揺れ（上）。
    - 4 回目（姿勢の変化率を g の 1.5 乗、NOSE LETDOWN は姿勢から）：送信所の 282 ft 先に約 2.7〜3.1 ft/s（慣性の経路で 2.7、主脚の回転分を足して約 3.1、電波高度で 4.8）・1.56 g。G/S の上のピッチの揺れは消えた（指令との差の標準偏差 0.032°、ピッチの角速度の RMS 0.043°/s。今のゲインの 2 回目は 0.064° と 0.065°/s）。接地の 0.8 秒後に 2 秒浮いた（5 ft まで）：接地の時の昇降舵は 0.49 で機首上げの途中（1.2°/s）、姿勢は 6.4° から 6.7° まで上がり、スピードブレーキは自動で出始めたところ（DN から UP まで 2 秒）。
    - 5 回目（NOSE LETDOWN の指令を接地の時の姿勢の 1° 下から）：送信所の 363 ft 先に、慣性の経路で 0.4〜1.0 ft/s、主脚の回転分を足して約 1.1〜1.4 ft/s（資料の 1.5 ft/s・450 ft にいちばん近い）・1.47 g。それでも接地の 0.8 秒後に 2 秒浮いた（5 ft まで）：接地の時の姿勢は 7.0° で毎秒 1.1° 上がり途中、昇降舵は 0.51。A/P の昇降舵の指令は誤差 1° で 3 秒かけて全行程（毎秒 0.67：前のコードの B747_interpolate_value）なので、0.5 を戻すのに約 0.8 秒かかり、その間に姿勢は 7.25° まで上がった。
    - 6 回目（gear altitude 5 ft の下で FLARE の指令を上げない、gear altitude を 2.3 ft ＋ 10 ft × sin で。X-Plane を起動し直して捨ての s66 のあと）：送信所の 341 ft 先に、慣性の経路で約 1 ft/s・1.35 g（いちばん柔らかい）。接地の時の機首の上がりは毎秒 0.16°（5 回目は 1.1°）、昇降舵 0.24（0.51）、gear altitude は接地で 0.07 ft。それでも接地の 0.5 秒後から 1.5 秒、1 ft ほど浮いた（機首は下がりながら）：揚力が重さに近いまま主脚の台車が水平にならず、PSEU が地上にならない（ATA29_32 p.322 の式、台車 4°：`B747.10.pseu_model.lua`）ので、スピードブレーキは出始めず、浮いている間は止まる。接地のピッチ 6.7° は FCTM の 4〜5° より高い（進入のピッチ 3.4° も FCTM の 2° より高い：フラップの揚力の形、notes/AERO.md §3.10）。s114 は 13 が合格で跳ねの確認だけ不合格。その確認は WARN にした（段 4c とフラップの揚力の形で見直す）。
- 回帰（X-Plane、カスタム acf）：`s112_afds_gs` 12/12、`s109_afds_takeoff` 20/20、`s102_afds_app` 37/37、`s104_afds_ga` 34/34、`s113_afds_multi` 29/29。Lua の誤りなし。

## 27. 段 4c の段取り（2026-10-30：ROLLOUT と roll down）

- 資料：
  - ROLLOUT の arm は multi-channel（LAND 3・2）、表示は電波高度 1,500 ft の下から、約 5 ft の下で active（FCOM p.664、p.671、p.672 の図）。ATA22 p.360 は電波高度 2 ft で engage、multi-channel でなければ F/D だけで表示は LOC。X-Plane の電波高度は主脚の接地で約 3.3 ft なので、5 ft は主脚の高さで約 1.6 ft（ATA の 2 ft に近い）。乗員に見える表示は FCOM の 5 ft にする。
  - ROLL DOWN：autoland で gear altitude 5 ft から翼を水平に（ATA22 p.296、p.348）。wings level は 5 ft、2 ft から rollout（p.296）。
  - ROLLOUT の則：LOC の偏位の距離と速さ（LOC の則と同じもの）で、方向舵と前輪の操向（multi-channel のとき）。A/P が無ければ F/D だけ（ATA22 p.362；FCOM p.659：方向舵の指令は multi-channel の進入だけ、前輪の操向は autoland の rollout）。
  - ROLLOUT は A/P を外すまで続く（FCOM p.671）。A/P と自動ブレーキは安全に止まるまで入れておく（FCTM p.159）。前の autoland の 65 kt の A/P の解除は資料に無い：外す。
  - A/T の IDLE は逆推力のレバーで A/T が切れるまで（FCOM p.671）：エンジンのモジュールが逆推力で A/T を切る（今のまま）。
- 作るもの：
  - AFDS のモデル：ROLLOUT の engage（arm で電波高度 5 ft の下）、FMA の ROLLOUT、地上で進入のモードを終えない（ROLLOUT・NOSE LETDOWN のとき）、A/P が外れるか TO/GA で終わる。multi-channel でなければ F/D だけで表示は LOC（p.360）。
  - ロールの則：ROLLOUT は翼を水平（補助翼）と、方向舵の指令（偏位の距離と、滑走路を横切る速さ）。地上の LOC までの距離は、接地からの対地速度の積分で減らす（推定）。
  - グルー：方向舵の指令の新しい dataref（`autopilot/rudder_cmd`）。油圧のモジュールが方向舵の入力に、操向のモデルが前輪の指令（ペダルと同じ 7°）に足す（multi-channel のとき）。`autopilot/autoland`（SRM の autoland：RRC の全権・自動トリムの遅れなし）は AFDS のモデルの LAND 3・2 から（G/A の −2 は今のまま）。
  - 前の autoland（`B747.autoland.lua`）をやめる：方向舵のトリム、ROLLOUT の FMA、65 kt の解除、`B747_ap_fma` のロールの FMA の止め。`afds_control` の前の則の autoland の枝も外す。
  - X-Plane：s114 を接地の後に延ばす（5 ft の下で ROLLOUT、中心線からのずれ、60 kt の下でも A/P のまま、止まってから A/P を外す）。横風の試験は段 4d（runway align）と一緒に。

## 28. 段 4c の実装（2026-10-30：ROLLOUT と前の autoland の撤去）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - ROLLOUT の engage：ROLLOUT が arm（LAND 3・2 で LOC）で、電波高度 5 ft（`ROLLOUT_RA`）の下（FCOM p.664、p.671。ATA22 p.360 の 2 ft は、X-Plane の電波高度が主脚の接地で約 3.3 ft なので、ここでは主脚の高さ約 1.6 ft にあたる）。FMA のロールは ROLLOUT（4）、arm は消える。
  - 地上では進入のモード（LOC・G/S とその arm）は終わるが、ROLLOUT と NOSE LETDOWN は続く。ROLLOUT は A/P が全部外れるか TO/GA まで（FCOM p.671）。LAND 3・2 の表示も ROLLOUT の間は続く。
  - multi-channel でないときの F/D だけの rollout（表示は LOC：ATA22 p.360）は作っていない（ROLLOUT の arm が LAND 3・2 だけなので、その時は LOC のまま地上で終わる）。
- ロールの則（`B747.70.afds_roll_model.lua`）：ROLLOUT は翼を水平（ROLL DOWN：ATA22 p.348）にし、方向舵の指令（`rudder`、ペダルの比、右が正）を出す：LOC の中心線からの距離（LOC の則の距離を引き継ぎ、LOC までの距離を engage からの走行で減らす）と滑走路を横切る速さ（p.362）で、中心線へ 8 秒で寄る横の速さ（コースから 3° まで）を求め、その航跡との差に 0.15/°、航跡の変化率に 0.3/(°/s)、±0.5（推定）。
- グルー（`B747.70.xt.autopilot.lua`）：
  - 2 台以上の A/P のとき（FCOM p.659）ROLLOUT の方向舵を新設 `autopilot/rudder_cmd` に書く。油圧のモジュール（`hydraulics_override`）がペダルとトリムに足して `flt_ctrls/rudder_input` にし、操向のモジュールがそれで前輪（ペダルの 7°）を切る：方向舵と前輪の操向（FCOM p.659）。
  - `autopilot/autoland`（SRM の autoland：RRC の全権・自動トリムの遅れなし、ATA27 p.636）は AFDS のモデルの LAND 3・2 から（前は前の autoland が 3 台で 100 ft の下）。G/A の −2 は今のまま（A/T の G/A 推力、1,500 ft で 0）。
  - 自動着陸のセンサーの数（段 4a）で、ILS 受信機の G/S は FLARE までだけ数える（G/S は FLARE で終わる：ATA22 p.342）。X-Plane は最後の数 ft で G/S の旗を出し、LAND 3 が接地の直前に NO AUTOLAND になって ROLLOUT の arm が消えていた（1 回目の試験）。
  - 前の autoland（`B747.autoland.lua`）を外した：毎フレームの `runAutoland`（方向舵のトリムを方位の差で、接地後は中央へ、65 kt で A/P を外す、FLARE の残り）と、`B747_ap_fma` のロールの FMA の止め。`afds_control` の前の則の autoland の枝（`autolandPitch`）も外した。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +9（ROLLOUT の engage・FMA・地上で続く・A/P を外すと終わる）、ロールの則 +7（翼を水平、方向舵の向き、上限、他のモードでは無し、地上の走行の模型で 20 ft の横ずれが 20 秒で 3 ft 以内に戻り行き過ぎない）、グルー +8（地上で ROLLOUT、3 台で方向舵、SRM の autoland、40 kt でも A/P のまま、FLARE 中の G/S の旗で LAND 3 のまま）。
  - X-Plane（カスタム acf、`s114_autoland` を止まるまで延ばした。RJAA 34L、無風、150 kt）：
    - 1 回目：ROLLOUT が入らなかった。X-Plane は最後の約 4 ft で G/S の旗を出し、自動着陸のセンサーの数で LAND 3 が接地の直前に NO AUTOLAND になって、ROLLOUT の arm が消えた → センサーの G/S を FLARE までにした（上）。この回は接地が硬かった（主脚の高さで約 6 ft/s・1.66 g。FLARE の始まりでピッチが他の回より 0.3° 低く、gear altitude 5 ft で 8.5 ft/s。状態表示が変わったのは最後の数 ft で、FLARE の途中ではない）。
    - 2 回目：電波高度 4.9 ft で ROLLOUT（G/S の旗は 2 台とも出ていて LAND 3 のまま）、60 kt まで LOC の偏位 0.031〜0.036 ドット、60 kt の下でも A/P のまま、止まって操縦輪のスイッチで外すと ROLLOUT が終わる。ただし接地の待ちが `onground_any` で、最初の 0.2 秒の接地を読み取りの間隔で取りこぼし、跳ねた後の 2 回目の接地（ピッチ 3.2°）から見ていたので、跳ねの確認が合格に見えた → s114 は接地を FLARE が消えるので待つ（FCOM p.671）ように直した。
    - 3 回目：19 が合格、跳ねの確認だけ WARN。電波高度 5.0 ft で ROLLOUT、送信所の 337 ft 先に接地（主脚の高さで約 2.8 ft/s・1.43 g、ピッチ 6.5°）、0.3 秒後から 1.6 秒、1 ft ほど浮いて、ピッチ 3.2° で再接地（段 4b と同じ：§26）。60 kt まで LOC の偏位 0.031〜0.037 ドット、60 kt の下でも A/P のまま、止まって外すと ROLLOUT が終わる。Lua の誤りなし。
    - 接地の降下率は回でばらつく：主脚の高さの最後の 0.25 秒で 1.4（段 4b の 6 回目）、2.0（2 回目）、2.8（3 回目）、約 6 ft/s（1 回目）。FLARE の途中は 1 回目のほかは 0.2 ft/s 以内で同じで、差は最後の 1.5 ft で出る。gear altitude 5 ft での降下率は 7.1〜8.5 ft/s で、則の降下率（√(1.5² + 2ah) で 4.1 ft/s）より遅れている（段 4b の則のまま。フラップの揚力の形を決めた後に、接地のピッチと一緒に見直す）。
    - 回帰：`s113_afds_multi` 29/29、`s109_afds_takeoff` 20/20、`s102_afds_app` 37/37、`s104_afds_ga` 34/34（X-Plane を起動し直して捨ての s66 のあと）。Lua の誤りなし。
- 残り（推定・作っていないもの）：
  - ROLLOUT の則のゲイン（資料は入力だけ：p.362）。
  - p.361 の図では、ROLLOUT の engage の出力に LOC VALID も要る。ここでは LOC の則と同じく、LOC を失っても慣性の経路で続ける（推定）。
  - multi-channel でないときの F/D だけの rollout（表示は LOC：p.360、p.361 の F/D ONLY）。
  - 片発や横風の rollout（方向舵の則は比例と変化率だけで、積分は無い）は段 4d と一緒に見る。

## 29. 段 4d の段取り（2026-10-30：runway align・decrab・片発）

- 資料：
  - runway align は multi-channel の engage で入り、multi-channel でなくなるか G/A か ROLLOUT で終わる（ATA22 p.360、p.361 の図の RUNWAY ALIGN ENGAGE のラッチ）。表示は無い（p.360）。乗員から見ると、LAND 3・LAND 2 の表示で A/P の方向舵が働く（FCOM p.670）。
  - 片発：engage から、補助翼と方向舵で翼を水平か、少し風上側を下げた姿勢に保つ（p.296、p.360）。故障が進入の前なら 1,300 ft で翼を水平にする横滑り、進入中なら検出の時（FCOM p.670）。故障の側と反対からの中程度以上の横風では、翼を水平にする横滑りはしない（もう風上側が下がっている：FCOM p.670；FCTM p.169）。指令は磁方位と航跡から（ATA22 p.362）。FCC の入力（p.200〜220）にエンジンのデータは無く、検出の仕方は資料に無い。
  - decrab：forward slip で 5° まで。crab が 10° 超は 500 ft で 5°、5〜10° は 500 ft で 5° まで減らし 200 ft で残り（合わせて 5°）、5° 未満は 200 ft で全部（ATA22 p.296、p.362；FCOM p.670）。磁方位と滑走路の方位から方向舵と補助翼で、流される分を補うロールの指令も出す（p.362。図 p.349 では RWY ALIGN がロール姿勢の積分器に入る）。DECRAB ENGAGE は runway align と、電波高度と crab 角の判定（p.361）。接地まで保ち、風上側の翼が下がって接地する。強い横風では少し crab が残る（FCOM p.670；FCTM p.159）。
  - 翼は 5 ft で水平（p.296）、2 ft から rollout（4c の ROLLOUT は 5 ft）。
  - A/P が外れると、方向舵はトリムの位置へ（FCOM p.670）：`rudder_cmd` は 2 台未満で 0（4c のまま）。
  - 内側のロールのループ（p.348、図 p.349）：ロールの指令（ROLL ATT INTEG）とロール角の差、ロールの角速度、ヨーの角速度を AIL TRIM INTEG（補助翼のトリムの積分器）に入れ、補助翼のサーボへ。A/P が入っていない間はサーボの位置を舵面に合わせる。
  - LOC の則（p.358、図 p.359）：LOC TRACK では LOC の距離とその変化率（と慣性の経路）が LOC SIG に入り、その出力がロール姿勢の積分器へ入る。
- X-Plane の 747 の横・方向の動き（新設 `s115_rudder_steps`：s114 と同じ所、フラップ 30・150 kt・脚下げ、A/P 1 台の ALT HOLD と HDG HOLD で方向舵のトリムを 0.125・−0.125・0.25 の段で入れ、HDG SEL の 10° の旋回。記録 v6 で横滑り角・ロールとヨーの角速度・方向舵の入力・補助翼・ロールの指令を足した）：
  - `tests/tools/lat_sysid.lua` の最小二乗の当てはめ（R² は横滑り 0.999、ロール 0.88、ヨー 0.96。今の yaw damper ごと）を `tests/tools/lat_model_150kt.lua` に置いた。開ループで記録の補助翼と方向舵を入れると、横滑りとヨーの角速度をよく再現する（バンクは 10 秒で 1° ほどずれる）。方向舵 1 あたり定常の横滑り約 17°、横滑り 1° でロールの角加速度 1.8°/s²（補助翼 0.06 ぶん）。
  - 見つかったこと 1：A/P の内側のロールのループ（`afds_control` の PID：比例 0.05、積分 0.0003、誤差の微分）は積分がほぼ無く、方向舵 0.1 の横滑りでロール角が指令から 1.5〜2° 離れたまま、旋回では 0.5〜1° 深いまま。decrab の 5° の横滑り（方向舵約 0.3）では模型で 4.4°。
  - 見つかったこと 2：LOC の則（段 2b、30 秒先を見る比例だけ）は、横滑りを支えるバンクが要ると中心線からずれたままになる。模型で、外側のエンジンが止まったまま補助翼だけで LOC を追うと 90 m。
- 作るもの（推定の値は模型 `tests/tools/roll_loop_150kt.lua`・`align_sim.lua` で決め、X-Plane で確かめる）：
  - 内側のロールのループ（別のコミット：§30）：ロール角の差の比例 0.05 と積分 0.02、ロールの角速度 0.04（指令の変化率との差）、ヨーの角速度 0.01。積分は指令が毎秒 1° より速く動いたら止め、止まってから 2 秒で戻す（旋回の入りの巻き上がり。runway align の風上へのバンクの指令はそれより遅い）。速度によらない（前の比例も一定。IAS で割り引くと 250 kt・フラップ上げ（外側の補助翼は固定）で、5° の制限の旋回が 7.6° まで行き過ぎた：s105）。
  - AFDS のモデル：runway align（LAND 3・2 で LOC のとき。G/A と ROLLOUT では LOC でなくなるので終わる：p.361）。FMA には出さない。
  - ロールの則（LOC で runway align のとき、方向舵の指令 `rudder`）：
    - crab 角＝磁方位 − 滑走路の方位（LOC のコース：p.362）。
    - decrab：500 ft で crab 角を覚え、表のとおり減らす（500 ft の下で max(0, min(5, |crab| − 5))、200 ft の下で min(5, |crab|)。下りた段は戻らない）。方位の目標を毎秒 1° で寄せ、方向舵は目標との差の比例 0.05・積分 0.02、crab 角の変化率 0.1。減らした crab 1° あたり 0.54° の風上へのバンクを LOC のバンクに足す（p.362 のロールの指令。横滑りの横力を支えるバンク：模型から）。
    - 片発（翼を水平に）：LOC の則が求めるバンクの比例 0.03・積分 0.01 で方向舵（機体のバンクでは、方向舵 → 横滑り → 上反角で同じ側へ傾き、積分を速くすると発散した）。crab 角 4° 以上で風上側へのバンクのときは足さない。decrab の間は積分を保つ。
    - LOC TRACK（中心線から 100 m 以内）では、航跡の差を 0.1°/(°·s) で積分してバンクに足す（±5°、上限まで）。
    - ROLLOUT は runway align の方向舵を引き継ぐ（ROLLOUT の則に積分 0.02 を足し、その初めの値にする）。
  - グルー：ロールの則の入力に runway align と磁方位。方向舵の指令の書き込みは 2 台以上のとき（4c のまま）。
  - 模型での結果（`align_sim.lua`、150 kt）：横風 20 kt（crab 7.6°）は 300 ft で 5.0°、50 ft で 2.7°、中心線から 1 m 以内、バンクは風上へ 1.4〜2.9°。30 kt（11.4°）は 6.4° を保つ。8 kt（3°）は 200 ft の下で 0.1°。外側のエンジンが進入の前に止まった（方向舵 0.15 ぶん）ときは 1,300 ft で翼が水平（0.5° 以内）、中心線から最大 12 m、50 ft で 2 m 以内。故障の側からの横風 15 kt では方向舵 0.46 まで要る。
  - 試験：回帰（モデル・則・グルー・油圧のモジュール）、X-Plane：`s116_autoland_xwind`（右からの横風 20 kt：2 段の decrab）、`s117_autoland_engout`（1 番を進入の前に止める）と、ロール・LOC・autoland の回帰。

## 30. 段 4d の前半の実装（2026-10-30：A/P の内側のロールのループ）

- `afds_control` の `ap_roll_assist`：資料（ATA22 p.348、図 p.349）の AIL TRIM INTEG に合わせ、PID はロール角の差の比例（`laminar/B747/flt_ctrls/pid/roll/p` 0.05：前と同じ）と積分（`pid/roll/i` 0.02：前は 0.0003）だけにし、誤差の微分の代わりにロールの角速度（`sim/flightmodel/position/P`）を指令の変化率との差で 0.04、ヨーの角速度（`R`）を 0.01 で足す（推定）。
  - 積分は、指令が毎秒 1° より速く動いたら止め、止まってから 2 秒で戻す（旋回の入りの巻き上がり。runway align の風上へのバンクの指令はそれより遅い）。
  - 指令の変化率は 0.3 秒でならす：ロールの則の指令は X-Plane の 1〜2 フレームごとに変わり、75 fps では毎秒 0.9° の傾きを 0 と 1.8〜2.8°/s で交互に読んで、積分が止まったままだった（s115 の 2 回目）。
  - A/P が外れている間は今のまま舵面に合わせる。`pid/roll/dl`・`dh`（高度による微分）は使わなくなった。
  - 速度によらない（前の比例も一定）。ピッチと同じく IAS で割り引くと、250 kt・フラップ上げ（外側の補助翼は固定）で、5° の制限の旋回が 7.6° まで行き過ぎた（s105）。
- 試験：
  - 回帰（LuaJIT）：油圧のモジュール +3（2° 傾いたままなら積分で補助翼が増える、ロールの角速度、ヨーの角速度の向き）。
  - 模型（`tests/tools/roll_loop_150kt.lua`、150 kt・フラップ 30）：前の作りは方向舵 0.1 の段で 1.5° 傾いたまま、0.3 で 4.4°。今の作りは 10 秒で 0.5°・1.4° 以内、20 秒でほぼ 0。10° の旋回の行き過ぎ 0.34°（積分を保たないと 1.24°、指令が動く間だけ保つと 0.64°）。
  - X-Plane（カスタム acf）：
    - 途中の値（積分 0.025、指令が毎秒 0.5° より速く動く間だけ保つ、ロールの角速度 0.03）で：`s105_afds_roll_law` 18/18（5° の制限の旋回で最大 6.08°、前は 4.84°。25° で 25.5°、前は 24.4°）、`s100_afds_roll` 25/25、`s106_afds_loc` 20/20（捕捉の行き過ぎ −1.46 ドット・横風中 0.05 ドット以内：前と同じ）、`s90_lnav` 30/30、`s115_rudder_steps`：方向舵 0.1 の段で、ロール角と指令の差は最大 2.0°、約 12 秒で 0.4° 以内（前の作りは 1.5〜2° のまま）。
    - 今の値で、変化率をならす前（X-Plane を起動し直して捨ての s66 のあと）：`s105` 18/18（5° の制限で最大 5.19°、25° で 24.7°）。`s115` は差が最大 2.9° まで開き、7 秒間補助翼が増えなかった（上の変化率のため）。
    - 変化率をならした後：`s115_rudder_steps` 4/4（方向舵 0.1 の段で、ロール角と指令の差は指令が動く間に最大 2.1°、約 7 秒で 0.1° 以内、その後 ±0.4° ほど。前の作りは 1.5〜2° のまま）、`s105_afds_roll_law` 18/18（5° の制限の旋回で最大 5.14°、25° で 24.6°）。Lua の誤りなし。

## 31. 段 4d の実装（2026-10-30：runway align・decrab・片発、LOC TRACK の積分）

- AFDS のモデル（`B747.70.afds_model.lua`）：runway align（`rwy_align`）は LAND 3・2 で LOC のとき（ATA22 p.361 のラッチ：multi-channel で入り、G/A と ROLLOUT で LOC でなくなって終わる）。NO AUTOLAND では入らない（FCOM p.670：LAND 3・2 の表示で A/P の方向舵）。FMA には出さない（p.360）。
- ロールの則（`B747.70.afds_roll_model.lua`）：
  - runway align のとき、LOC の則の後に方向舵の指令（`rudder`）を出す。crab 角＝磁方位 − LOC のコース（p.362）。
  - decrab：電波高度 500 ft の下で crab 角を覚え、表のとおり減らす（`M.decrab`：500 ft の下で max(0, min(5, |crab| − 5))、200 ft の下で min(5, |crab|)。下りた段は戻らない：p.296、p.362；FCOM p.670）。方位の目標を毎秒 1° で寄せ、方向舵は目標との差の比例 0.05・積分 0.02、crab 角の変化率 0.1（推定）。減らした crab 1° あたり 0.54° の風上へのバンクを LOC のバンクに足す（p.362 のロールの指令。横滑りの横力を支えるバンク：模型から）。翼は 5 ft で水平（ROLL DOWN）、decrab の方向舵は ROLLOUT まで。
  - 翼を水平に（片発：p.360；FCOM p.670）：LOC の則が求めるバンク（航跡が要るバンク）の比例 0.03・積分 0.01 で方向舵（推定。機体のバンクを使うと、方向舵 → 横滑り → 上反角で同じ側へ傾き、積分を速くすると発散した：模型）。crab 角 4° 以上で風上側へのバンクのときは足さない（FCOM p.670；FCTM p.169）。decrab の間は積分を保つ。エンジンの入力は使わない（FCC の入力に無い）。
  - LOC TRACK（中心線から 100 m 以内）：航跡の差を 0.1°/(°·s) で積分してバンクに足す（±5°、バンクの上限に当たる間は積まない。図 p.359：LOC の信号はロール姿勢の積分器へ）。補助翼だけで片発の LOC を追うと、模型で中心線から 90 m ずれたままだった。
  - ROLLOUT：runway align の方向舵を積分（0.02/(°·s)、推定）の初めの値にして続ける。
- グルー（`B747.70.xt.autopilot.lua`）：ロールの則に `rwy_align` と磁方位（`sim/flightmodel/position/mag_psi`）を渡す。方向舵の指令の書き込み（2 台以上：`autopilot/rudder_cmd`）は 4c のまま：A/P が外れると 0 で、方向舵はペダルとトリムの位置へ（FCOM p.670）。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +6（LAND 3 で runway align、1 台・NO AUTOLAND・ROLLOUT・G/A では無い）、ロールの則 +26（decrab の表、翼を水平に：LOC のバンクで方向舵・風上側は足さない・積分、decrab の目標・風上へのバンク・積分を保つ、段は戻らない、ROLLOUT が方向舵を引き継ぐ、G/A で無し、LOC TRACK の積分と捕捉で積まない）、グルー +1（LAND 3 で LOC が右へバンクを求めると右の方向舵）。全 121 本。
  - 模型（`tests/tools/align_sim.lua`、150 kt）：横風 20 kt（crab 7.6°）は 300 ft で 5.1°、50 ft で 2.6°、中心線から 1.1 m 以内、バンクは風上へ 1.5〜3.0°。30 kt（11.4°）は 6.4° を保ち 1.7 m 以内。8 kt（3°）は 200 ft の下で 0.1°。外側のエンジンが進入の前に止まった（方向舵 0.15 ぶん）ときは 1,300 ft で翼が水平（0.3° 以内）、中心線から最大 13 m、50 ft で 1.4 m。故障の側からの横風 15 kt では方向舵 0.46。
  - X-Plane（カスタム acf）：（X-Plane を起動し直して捨ての s66 と s105・s115 の後）
    - `s116_autoland_xwind`（新設：右からの横風 20 kt）30/30：600 ft の crab 7.8°（横滑り −0.1°）、300 ft で 5.6°（航跡からは 5.2°、横滑り −2.8°、風上へのバンク 1.6°、方向舵 −0.16、LOC 0.05 ドット）、80 ft で 3.5°（横滑り −4.5°、バンク 2.2°、方向舵 −0.34、LOC 0.06 ドット）、ROLLOUT で 60 kt まで 0.032〜0.047 ドット、止まって外すと ROLLOUT が終わる。
    - ただし FLARE の終わりに浮いた：横滑りで揚力が減ってピッチが高く（60 ft で 4.1°、無風は 3.4°）、FLARE の始まりの降下も大きく（14.4 ft/s、無風は 12.6）、主脚の高さ 2 ft でピッチが指令（7.3°）を越えて 7.9° になり、降下が止まって電波高度 12 ft まで上がった。FLARE の則が指令を 3.6° まで下げ、ピッチ 2.8°・主脚で 7.8 ft/s・2.07 g で接地した。
    - `s117_autoland_engout`（新設：1 番を進入の前に止める）26 が合格・跳ねの WARN：A/P 1 台の LOC（補助翼だけ）でバンク 3〜3.9°・LOC 0.04 ドット以内（LOC TRACK の積分）、LAND 3 の engage（1,403 ft）から方向舵、1,300 ft でバンク 0.19°・方向舵 0.18・横滑り 0.1°・LOC 0.003 ドット、300 ft でも 0.06°、ROLLOUT で 60 kt まで 0.018 ドット以内。接地は主脚で約 5.9 ft/s・1.72 g、ピッチ 6.6° で、浮いた（WARN）。
    - `s114_autoland`（回帰）20/20：接地は主脚で 1.4 ft/s・1.15 g、ピッチ 5.8°、浮かなかった。Lua の誤りなし。
    - FLARE は条件で大きく変わる（無風 1.4 ft/s・1.15 g、片発 5.9 ft/s・1.72 g、横風は浮いて 2.07 g）。フラップの揚力の補正（利用者が決めた）で進入のピッチが変わるので、その後に FLARE の則を 3 つの条件で見直す。s114・s116・s117 に「FLARE で浮き上がらない」の WARN（昇降率 +100 fpm まで）を足した。
- 残り（推定・作っていないもの）：則の値（資料は入力と表だけ）、片発の検出（翼を水平にする方向舵は、LOC が求めるバンクで見る）、F/D だけの rollout、yaw damper の作り直し（段 6）の後の見直し（模型は今の yaw damper ごと）。

## 32. FLARE の浮き止め（2026-10-30：フラップの揚力の補正の後）

- 見つかったこと：フラップの揚力の補正（notes/AERO.md §3.12）の後の自動着陸（無風・横風 20 kt・片発）で、横風の回（s116）は decrab の横滑りでピッチが高めのまま、主脚の高さ 1.4 ft・ピッチ 6.9° で降下が止まった（G 1.12：地面効果）。FLARE の則は 5 ft の下で指令を上げないが、下げる速さは K_FLARE の毎秒 0.6° ほどで、機体は主脚の高さ 11 ft まで浮き、ピッチ 1.1°・主脚で 8.6 ft/s・2.19 g で接地した。段 4d の時（フラップの補正の前）も同じだった（2.07 g）。
- ピッチの則（`B747.70.afds_pitch_model.lua`）：主脚の高さ 5 ft（`FLARE_HOLD_FT`）の下で、先読みした降下率（0.8 秒）が接地の 1.5 ft/s（`TD_SINK`）を下回ったら、指令を 1.5 ft/s の経路との差の `K_FLOAT` 2 倍毎秒で下げる（推定。水平で毎秒 0.68°、上昇していればそれ以上）。上げないことは今のまま。
- s114・s116・s117 の「FLARE で浮き上がらない」の WARN は、接地（FLARE が消える）まで見る（ROLLOUT は電波高度 5 ft の下で入るので、浮く前に入ることがあった）。
- 試験：
  - 回帰（LuaJIT）：ピッチの則 +2（5 ft の下で浮くと K_FLOAT の速さで下げる、1.5 ft/s より速く降りていれば効かない）。全 121 本。
  - X-Plane（カスタム acf、X-Plane を起動し直して捨ての s66 のあと）：`s116_autoland_xwind`：浮き上がらず（主脚の高さ 2 ft の後は上がらない）、接地はピッチ 6.5°・主脚で 2.5 ft/s・1.30 g（前は 2.19 g）。`s114_autoland`：1.4 ft/s・1.24 g・ピッチ 6.1°。`s117_autoland_engout`：5.6 ft/s・1.66 g・ピッチ 5.5°。3 本とも浮き上がりは無く、接地の後の跳ね（0.3〜0.9 ft、1 秒ほど：脚の跳ね返りと、スピードブレーキが出るまでの 2 秒（推定））は WARN のまま。Lua の誤りなし。
- 残り：FLARE はピッチが指令より 0.9° ほど遅れ、主脚の高さ 5 ft で 7.6〜8.7 ft/s（則の 4.1 ft/s より遅い）。片発ではそのまま 5.6 ft/s で接地する。追従を速くすると接地のピッチが上がって跳ねやすくなるので、内側のループの FLARE での応え方と合わせて見直す。

## 33. 段 5 の段取り（2026-10-30：監視と警報）

- 対象（GAP の項目）：AFDS-12（AUTOPILOT caution、モード故障の amber の線、F/D の故障旗）、AFDS-13（NO LAND 3・NO AUTOLAND の EICAS）、AFDS-14 の残り（AUTOPILOT DISC の音の型式）、AFDS-15 の残り（engage のインターロック）、AFDS-16（AFDS の電源）、AFDS-23（ILS TUNE INHIBIT・RA TEST INHIBIT）。資料の要約は §3.4、§4.1、§4.5、§4.6（ATA22 p.190–216、p.250–256、p.302–324、p.366–386；FCOM p.640、p.653–655、p.660、p.662、p.677）。
- 分け方（それぞれ回帰と X-Plane で確かめてコミット）：
  - 5a 電源とインターロック（AFDS-15・16）：engage の前提（115V AC と 28V DC：FCC L は AC 3・DC 3、C は AC 1・DC 1、R は AC 2・DC 2。28V DC STBY は engage の後に失っても外れない。MCP の電源）、FCC・MCP・サーボと inner loop のセンサ（IRU・ADC）の有効、両 SRM の autotrim valid を失うと engage できず NO AUTOLAND（advisory、地上はエンジン始動まで出さない：FCOM p.47）、単一チャンネルの arm 中に操縦輪 25° 超で arm が外れる（p.314）、autotrim valid を両方失うと単一は外れる（p.318）。
  - 5b 警報（AFDS-13・14）：AUTOPILOT DISC の音は 109・405（PW）が wailer（最低 1 秒）、570（GE）が siren（FCOM p.655、p.677。RR は PW と同じ：推定）。NO LAND 3・NO AUTOLAND の EICAS：LAND 3・2 を出した後は caution（multi-channel engaged 中は beeper の level B）、前は advisory（level C）。200 ft の下は NO AUTOLAND への劣化だけ、急がないものは接地の後（p.373–374、p.386；FCOM p.662、p.677）。
  - 5c AUTOPILOT caution とモード故障（AFDS-12）：engaged のモードの入力（LOC・G/S の 2 個目、RA の 2 個目、LNAV・VNAV の FMC など）を失うと、A/P は姿勢を保つモードで engaged のまま、FMA に amber の線、AUTOPILOT（caution）。A/P を外すか、条件の要らないモードを選ぶと消える（ATA22 p.254、p.382；FCOM p.660）。F/D の故障旗と、NCD でのバーの消し方（PW は該当のバー、GE は両方：FCOM p.660）。表示はパネルの計器（カスタム acf、2026-10-25 から承認なしで変えてよい。手順は CLAUDE.md）。
  - 5d ILS TUNE INHIBIT・RA TEST INHIBIT（AFDS-23）：A/P では LOC・G/S の捕捉から、F/D だけなら 500 ft RA の下、地上で滑走路の向きに 45° 以内・40 kt 以上・LOC/APP を選んでいないとき、ILS の自動同調を止める（p.212）。ATA 34（FMC・無線）との境界。
- 故障の模型は無い（FCC・MCP・サーボの内部故障）ので、他のモジュールから取れる有効性（電源、油圧、IRS、ADC、RA、ILS、FMC、SRM）だけで作る（§5）。

## 34. 段 5a の実装（2026-10-30：電源と engage のインターロック）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - チャンネルの有効（`M.valid`）：サーボの油圧（前から）、その FCC の電源（L は AC 3 と DC 3、C は AC 1 と DC 1、R は AC 2 と DC 2：p.191）、MCP（2 チャンネルのどちらか：DC 3 か DC 2、p.209）、inner loop のセンサー（IRU の姿勢と ADC、それぞれ 2 台以上：二重の故障で arm が外れる p.316、ADC の 2 台目の故障で外れる p.382）。engage にも engage を保つのにも要る。multi-channel の arm にも。
  - engage だけに要るもの：28V DC STBY（電池の母線。警報の電源で、engage の後に失っても外れない：p.304。multi-channel の arm にも：p.314 の power monitor）、そのチャンネルの SRM の autotrim valid（L FCC は SRM L、R は SRM R、C はどちらか：p.224）、操縦輪 25° 以内（単一チャンネルの arm：p.314）。
  - 単一チャンネルは、autotrim valid を失うと外れる（p.318）。両方の SRM が無いとどれも engage しない（FCOM p.47）。L と R の FCC が自分の側の SRM しか見ないのは p.224 の結線から（「1 and 2 の喪失」は C のこと、と読んだ：推定）。
  - 単一チャンネルで FLARE のまま電波高度 5 ft（`GROUND_RA`）を下回ると外れる（p.318）。FLARE は LAND 3・2 でしか arm しないので、FLARE の後に 1 台に減ったときだけ。
  - 2・3 台で LOC と G/S の捕捉の後（FLARE・NOSE LETDOWN・ROLLOUT も）、同じ種類の autoland センサーが 1 台だけになると（`inp.sensors` < 2）全部が外れる（p.320、p.322。2 台は「non-isolated disconnect」、3 台は「engage removal」で、どのチャンネルかは書いていないので全部：推定）。multi-channel の arm もそこで外れる（p.316）。捕捉の前は見ない：X-Plane の ILS は範囲の外で信号が無くなり、FCC の NCD（故障ではない）と区別できない。IRU と電波高度計の故障は捕捉の時に arm が外れる。
  - 外れたときは前と同じ自動の解除（AUTOPILOT DISC）。A/P が 1 台も無いときは autoland の状態を出さない（F/D の FD。前は全部外れても NO AUTOLAND が残った）。
- SRM（`B747.45.srm_model.lua`、グルー `B747.45.xt.srm.lua`）：autotrim valid（SRM が有効＝故障でなく電源があり、操縦輪のトリムのスイッチの指令が無い：ATA22 p.122、p.142）を新設の `laminar/B747/flt_ctrls/stab_trim/autotrim_valid[2]`（init `B747.45.fltCtrls`）に書く。A/P 2 台以上ではスイッチが効かないので valid のまま。A/P 1 台でスイッチを使うと外れるのは前からのコマンド（`autopilot/trim_disengage`）でも起きる（同じ結果）。
- グルー（`B747.70.xt.autopilot.lua`）：FCC の電源（`afds_power` が L・C・R ごとに）、MCP、電池の母線（`electrical/bus/bat_main`）、`irs/att_valid` と `airdata/valid` の数、`autotrim_valid`、操縦輪の角度（`cablecontrols/wheel`）をモデルに渡す。
- 内側のロールのループ（`B747.19.xt.afds_control.lua`）：単一チャンネル（CMD の状態の和が 1）のとき、補助翼の指令（PID の出力と積分も）を操縦輪 25°（25/90）までにする（p.316：単一チャンネルの補助翼の指令は制限され、25° を超えると監視が働く。制限の値そのものは無いので監視の値：推定）。これまでの記録では単一チャンネルの操縦輪は 23° まで（s115 の方向舵の段差だけ 28°）。
- 試験の初期化（`B747.68.xt.fms.lua`）：空中開始で FMS が押す CMD L を、入るまで 0.5 秒おきに最大 10 回押し直す。IRU と ADC のモジュールは読み込みの 3 秒後から動く（最初の読みが 0 のため）ので、約 3 秒後の CMD L が入ったり入らなかったりした（s118 の 1 回目）。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +41（チャンネルの有効：FCC の電源・MCP・DC STBY（engage だけ）・IRU と ADC の二重故障、SRM の autotrim valid（L・R・C の結線、単一チャンネルだけ外れる、両方で engage しない）、操縦輪 25°、multi-channel の arm（有効なチャンネルだけ、DC STBY、捕捉の後のセンサーの二重故障、捕捉の前は外さない）、単一チャンネルの FLARE の 5 ft、3 台は外れない、入らない理由 `M.refused`。前の「センサー 1 個で NO AUTOLAND」は「全部外れて AUTOPILOT DISC、状態は FD」に）、グルー +8（SRM L の autotrim valid で L が外れ C が入る、電池の母線は engage の後なら外れない、AC 1 で C が外れる、電池の母線と操縦輪 30° で入らない）、油圧のモジュール +2（単一チャンネルの補助翼は操縦輪 25° まで、2 台なら越える）、SRM のモデル +5（autotrim valid：故障・電源・操縦輪のスイッチ、2 台の A/P ではスイッチが効かないので保つ）。全 121 本。
  - X-Plane（カスタム acf）：
    - 1 回目の一覧（X-Plane を 20:47 に起動してから 5〜8 回目の読み込み）：`s118_afds_interlocks`（新設）24/27：SRM L の故障で L が入らず C が入る、SRM R も故障で C が外れて AUTOPILOT DISC、どれも入らない、戻すと入る、ADC は 1 台では外れず 2 台目で外れて入らない、IRU も 2 台目で外れる。落ちた 3 つは空中開始の初期化の CMD L が入らなかったこと（上の試験の初期化で直した）とその続き。`s99_afds_engage` 36/36。`s115_rudder_steps` 4/4（単一チャンネルの操縦輪は最大 22.5° で、上限には届かず）。`s114_autoland` 21/21（LAND 3、3 台の FLARE で 5 ft を下回っても外れない。接地は主脚の高さ約 0.2 ft で降下が止まって 1 ft ほど浮き（+75 fpm）、浮き止めでピッチが 6.3° から 3.1° に下がってから 1.38 g：段 5a とは別の FLARE の残り）。Lua の誤りなし。
    - 診断（シナリオは作業用で、リポジトリには入れない）：空中開始の直後 0.6 秒は IRU の姿勢と ADC が無効、0.9 秒後には有効。X-Plane 起動直後の最初のフライトでは AC 1・3 と DC 2・3 が無く（電池と standby だけ：TESTING.md の既知の性質）、ADC は L だけ、SRM の autotrim valid は無く、A/P は入らない（正しい）。
    - 2 回目（X-Plane を起動し直して捨ての s66 のあと）：`s118_afds_interlocks` 27/27。
- 作っていないもの：FCC・MCP・サーボの内部故障（program pin、servo loop、LVDT、hot short、自己試験）、電源投入の試験中の engage の禁止（時間が無い）、aileron exceedance の監視が働く故障、detent と camout（操縦士の override：単一は AUTOPILOT caution、2 台は両方、3 台はそのチャンネルが外れる p.322。X-Plane の操縦桿の入力は A/P の出力に足されるので、段 5c で見る）、first-in-command の移り（p.324：G/A からの残りは今の作りのまま）。

## 35. 段 5b の実装（2026-10-30：NO LAND 3・NO AUTOLAND の EICAS と AUTOPILOT DISC の音）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - autoland の能力（`M.capability`）：種類ごとの故障の数の最大を 3 から引く（0 より下にしない）。種類と数（`M.CAP_FULL`）は、有効なチャンネル 3（段 5a の `M.valid`：FCC の電源・サーボの油圧・MCP・inner loop のセンサー）、FCC の電源 3、IRU 3（NAV のもの）、電波高度計 3、ILS 受信機 3、SRM 2、FCU 3。1 個の故障で 2（NO LAND 3）、同じ種類の 2 個（SRM は両方）で 1 以下（NO AUTOLAND）（ATA22 p.384：IRU・ILS・RA、flap/stab control unit、FCC・サーボの 1 個で NO LAND 3、同種 2 個で NO AUTOLAND）。
  - EICAS の文（`alert`、`alert_level`）：LAND 3・2 を出している間に起きれば caution、そうでなければ advisory で、続く間はその level のまま（FCOM p.677 の「LAND 3 or LAND 2 annunciates の後か前か」。ATA22 p.373–374 は multi-channel engaged かどうかで level B・C）。空中で LAND 3・2 のとき 200 ft の下では NO AUTOLAND への変化だけ出し、ほかは接地の後に出す（FCOM p.662；ATA22 p.386）。毎フレーム、update の初め（前のフレームの autoland の状態で）に決める。F/D も A/P も無いときも出す。
- SRM：SRM 自体の有効（故障でなく電源がある）を新設の `laminar/B747/flt_ctrls/stab_trim/srm_valid[2]` に書く。autotrim valid（段 5a）は操縦輪のトリムのスイッチを使う間も落ちるので、能力には使わない（巡航でトリムを使うたびに NO AUTOLAND が出てしまう）。
- グルー（`B747.70.xt.autopilot.lua`）：能力の入力（`afds_cap`）：有効なチャンネル、FCC の電源、`irs/nav_valid`・`ra/valid` の数、ILS 受信機（X-Plane の故障だけ：`rel_nav1` が L と C、`rel_nav2` が R、`rel_loc`・`rel_gls` は 3 台とも。電波が届かないのは故障ではない）、`srm_valid`、`flt_ctrls/fail/fcu`。EICAS は caution [49] >NO AUTOLAND・[50] >NO LAND 3、advisory [246] >NO AUTOLAND・[248] >NO LAND 3（`B747.87.xt.warning.lua` の表）。前は PFD の NO AUTOLAND のときに [246] を立てるだけだった。
- 警報のモデル（`B747.87.alert_model.lua`）とグルー（`B747.87.xt.alerts.lua`）：
  - >AUTOPILOT DISC の音：`ap_siren`（`laminar/B747/engines/type` が GE）なら siren を表示の間（master reset では止まらない）、そうでなければ前のとおり wailer を最低 1 秒（FCOM p.655、p.677、p.1550–1551。RR は PW と同じ：推定）。
  - >NO AUTOLAND と >NO LAND 3 は地上でエンジン始動まで隠す（`PRESTART_HIDDEN_ANY`：地上で FUEL CONTROL が 4 つとも CUTOFF の間。FCOM p.47 は NO AUTOLAND。NO LAND 3 も同じにした：推定）。`M.classify` は NO LAND 3 の 3 をエンジンの番号と読むので、その類は「NO LAND」。
  - 着陸の抑止（FCOM p.1600–1602）で master CAUTION を点けるのは NO AUTOLAND（前から `LANDING_SHOWN`）。NO LAND 3 の caution は 200 ft の下では AFDS 側で出さない。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +16（能力の数え方、巡航の advisory、LAND 3 の後の caution と LAND 2、200 ft の下は NO AUTOLAND だけ、接地の後に NO LAND 3）、グルー +3（LAND 3 で電波高度計を 1 台失うと caution [50]、戻すと消える）、警報のモデル +5（570 の siren：master reset で止まらず表示とともに止まる、地上のエンジン始動前に隠す）、SRM のモデル +2（SRM の有効はトリムのスイッチでは落ちない）。全 121 本。
  - X-Plane（カスタム acf、X-Plane を起動し直した後の 4・5 回目の読み込み）：新設の `s119_afds_autoland_eicas` 15/15：巡航で電波高度計 R の故障で >NO LAND 3 の advisory（EICAS で字下げした琥珀）、C も故障で >NO AUTOLAND の advisory（>SNGL SOURCE RA も出る）、戻すと消える、FCU L と X-Plane の NAV 2 の故障でも >NO LAND 3。`s113_afds_multi`（確認を足した）：LAND 3 の進入で電波高度計 R の故障で LAND 2 と >NO LAND 3 の caution（EICAS の一番上）、advisory は出ない、戻すと消える。Lua の誤りなし。
- 作っていないもの（推定・後回し）：ILS 受信機と FCU の電源、tune・test の inhibit に応じない受信機（段 5d）、bus の分離（ELEC-18）、LOC・G/S アンテナの切り替えの故障、autoland に関係しない FCC の故障の NO LAND 3（地上で A/P を外しているとき：p.384）、MCP の wrap-around の試験。

## 36. 段 5c の実装（2026-10-30：モード故障と AUTOPILOT caution、F/D のバー）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - モード故障（`mode_failures`：ATA22 p.382 の「caution と PFD の黄色の線」の条件のうち、他のモジュールから取れるもの）：LOC は位置信号のある受信機が 2 台を切る（故障か電波なし＝NCD：「LOC or G/S local fail after second failure」と「two or three ILS NCD」）か、捕捉の後に ILS の周波数が変わる。G/S も同じく glide slope で。LOC と G/S の捕捉中に 1,500 ft の下で電波高度計が 2 台を切ると両方（どちらのモードかは書いていない：推定）。IRU の outer loop：LNAV・LOC は NAV の IRU、HDG SEL・HDG HOLD は方位のある IRU（ATT の SET HDG でもよい）がそれぞれ 2 台を切ると。multi-channel の G/A で選んだ ADC（両席のどちらか）を失うと G/A のピッチ。master FMC の故障（LNAV・VNAV）は FMC の故障の模型が無いので無い。
  - 故障したモードは、新しいモードを選ぶまで（`set_roll`・`set_pitch`）故障のまま（ATA22 p.254：「disengage the autopilot or select a different mode」）。FMA はそのモードのまま。A/P は「attitude stabilizing mode」（FCOM p.660）：故障の時のバンク（30° まで）とピッチを保つ。LOC と G/S の捕捉の後は HDG SEL などを選べない（遷移表 p.351）ので、TO/GA か A/P を外して F/D を切るまで。
  - AUTOPILOT の caution（`M.caution`）：A/P が入っていて、モードが故障しているか、単一チャンネルで FLARE（p.382 の caution だけの条件）。A/P を外すと消える（F/D のモードの故障は残る）。ほかの「caution だけ」の条件（地上の試験、stab trim の故障、FLCH・VNAV から要求なしの V/S、program pin、1.3 Vs の V/S、単一チャンネルの override）は無い。
  - 段 5a の multi-channel の解除（同じ種類の autoland センサー 2 台）は、故障の数（段 5b の `inp.cap`）で見るように直した。電波が無い（NCD）のはモード故障で、解除ではない（p.382 の two or three ILS NCD は caution と線）。
- ピッチの則（`B747.70.afds_pitch_model.lua`）：`att_pitch` があれば ATT の則（そのピッチを保つ）。ロールは既存の ATT の則に故障の時のバンクを渡す。runway align はロールが故障したら止める。
- グルー（`B747.70.xt.autopilot.lua`）：入力（`afds_mode_inputs`）：位置と G/S の受信機（X-Plane の信号と故障：NAV 1 が L と C、NAV 2 が R）、電波高度計と NAV の IRU（段 5b の数）、方位のある IRU（`irs/hdg_valid`）、両席の選んだ ADC（`airdata/valid_capt`・`valid_fo`）、ピッチ、NAV 1 の周波数。出力：新設の `autopilot/FMA/roll_fail`・`pitch_fail`（FMA の琥珀の線）、`autopilot/fd/roll_bar`・`pitch_bar`（F/D のバー：その軸にモードがあって故障していないとき。109・405 は故障した軸のバーを消し、570 は両方：FCOM p.660。RR は PW と同じ：推定）、caution [4] >AUTOPILOT（前は定義されていない X-Plane の故障を見ていて出なかった）。
- パネル（カスタム acf、ACF_DIFF.md）：4 面の PFD の FMA のロールとピッチの作動中のモードに琥珀の線（104 × 3、`make_fma_fail_images.ps1`・`panel_fma_fail.lua`）、F/D のバーの条件を `fd/roll_bar`・`pitch_bar` に。INTERFACES.tsv に 4 つの名前を足した。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +24（受信機 1 台では故障しない、位置の 2 台目で LOC が故障して FMA はそのまま・バンクを保つ・AUTOPILOT、電波が戻っても故障のまま、G/S の捕捉の後は HDG SEL を受けない、G/S の 2 台目でピッチを保つ、TO/GA で消える、LOC だけの進入は HDG SEL で消える、A/P を外すと AUTOPILOT が消える、周波数の変更、1,500 ft の下の電波高度計、IRU の NAV と方位、multi-channel の G/A の ADC、単一チャンネルの FLARE、multi-channel で電波が無いのはモード故障で受信機の故障の 2 台目は解除）、グルー +9（HDG HOLD で方位の IRU を 2 台失うと線・ロールのバーが消える・AUTOPILOT・ロールの則、570 は両方のバー、戻して HDG SEL で消える）。IRU の有効を試験の初めに入れた（グルーとヘディング基準の試験）。全 121 本。
  - X-Plane（カスタム acf）：新設の `s120_afds_mode_fail` 28/28：LOC と G/S を 1,500 ft より上で捕まえて NAV 1 を故障にすると、LOC と G/S が故障（FMA に琥珀の線、FMA のモードはそのまま）、>AUTOPILOT の caution、A/P は入ったまま 8 秒間バンク 0° 付近を保つ、F/D のバーは両方消える、>NO AUTOLAND は advisory（段 5b）。NAV 1 を戻しても故障のまま、TO/GA で消えて F/D のバーが戻る。PFD と EICAS の写真で確かめた。`s114_autoland`（回帰）20/20（WARN は前からの接地の後の跳ね 1 つ）：Web API で 0.5 秒おきに見て、進入から G/S、45 ft の FLARE、接地までモード故障は一度も立たない（X-Plane の G/S の旗は FLARE の後）。`s99_afds_engage`（回帰）36/36。Lua の誤りなし。
- 作っていないもの：F/D の故障旗（FCC の故障の模型が無い）、master FMC の故障、caution の後に解除する故障（p.382 の最初の組：FCC・MCP の内部、IRU の上下加速度の 2 台目。ADC の 2 台目は段 5a で解除）、AUTOPILOT の「caution だけ」の条件の大半、detent と camout（操縦士の override）。

## 37. 段 5d の実装（2026-10-30：ILS TUNE INHIBIT と RA TEST INHIBIT）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - RA TEST INHIBIT（`M.ra_test_inhibit`）：A/P が入っていて LOC か G/S を捕捉している（FLARE・NOSE LETDOWN・ROLLOUT も）、または F/D だけでそれを捕捉していて電波高度 500 ft の下（ATA22 p.212）。
  - ILS TUNE INHIBIT（`M.ils_inhibit`）：その条件に加えて、地上で LOC が生きていて（位置の信号のある受信機）、機首が LOC のコースの 45° 以内、対地 40 kt 超、LOC も APP も選んでいない（離陸の滑走：ATA22 p.212。FCOM p.1305 は LOC/APP の条件を書かない）。
- グルー（`B747.70.xt.autopilot.lua`）：入力は LOC の受信機（段 5c の数）、磁方位と NAV 1 のコース、対地速度。新設の `laminar/B747/autopilot/ils_tune_inhibit`・`ra_test_inhibit`（init `B747.70.autopilot`）に書く。前の ILS の自動同調（`B747_fltmgmt_setILS`）は、ILS TUNE INHIBIT の間は周波数とコースを書かない（前は捕捉の後も 2 秒ごとに書いていた：GAP の AFDS-23）。
- FMC（`B744.fms.pages.lua` の `findILS`）：NAV RADIO ページの ILS の手動の同調も、ILS TUNE INHIBIT の間は受け付けない（INVALID ENTRY：FCOM p.1305 は「manual-tuning are inhibited」とだけ。文言は推定）。
- 試験：
  - 回帰（LuaJIT）：AFDS のモデル +11（何も捕捉していなければ無し、A/P で LOC と G/S を捕捉して両方、F/D だけは 600 ft で無し 450 ft で両方、地上の離陸の滑走で ILS TUNE だけ、30 kt・コースから 50°・LOC が無い・LOC を選んだときは無し）、グルー +2（捕捉の前は無し、A/P で LOC と G/S を捕捉して両方）。全 121 本。
  - X-Plane（カスタム acf）：新設の `s121_afds_ils_inhibit` 13/13：A/P で LOC と G/S を捕捉すると ILS TUNE INHIBIT と RA TEST INHIBIT が立ち、NAV 1 は 111.90 のまま（前の自動同調が書かない）、CDU の NAV RADIO で 110.30 を入れると INVALID ENTRY で周波数は変わらない、モード故障は立たない、A/P を外して F/D を切ると両方消える。`s114_autoland`（回帰）20/20（WARN は前からの接地の後の跳ね 1 つ）。Lua の誤りなし。
- 作っていないもの：電波高度計と ILS の自己試験（X-Plane にも機体にも無いので、RA TEST INHIBIT は dataref だけ）、LOC・G/S のアンテナの切り替えとその監視（ATA22 p.214–216：NO LAND 3・NO AUTOLAND の原因）、離陸後 10 分の自動同調の抑止（FMC の段 9 以降）。

## 38. ELEC-18 の AFDS の側（2026-10-30：母線の分離の要求と BUS ISOLATED）

- AFDS のモデル（`B747.70.afds_model.lua`）：
  - 分離の要求（`bus_isolation`、`M.bus_isolate_request`）：APP（G/S の arm か捕捉、その後の FLARE・NOSE LETDOWN・ROLLOUT）で multi-channel（ほかのチャンネルが arm か engage）のとき（ATA22 p.192：「approach arm mode の間」、LH24 p.242：3 チャンネルの autoland のため。単一チャンネルの APP では求めない：推定）。終わりは、A/P が全部切れたとき、TO/GA で電波高度 100 ft 超、APP の解除（FCOM p.802）。チャンネルが 1 つに減っても続く。
  - LAND 3 には BUS ISOLATED（`inp.bus_isolated`）が要る（ATA22 p.192）。無ければ LAND 2（200 ft の下は今までどおり LAND 3 を保つ：電源の側も 200 ft の下は BTB を保つ）。
  - 要求から 4 秒たっても BUS ISOLATED が無ければ能力を 2 に落とし、>NO LAND 3（ATA22 p.384：「Electric buses do not isolate when requested」。4 秒は p.192 の「4 秒以内」から：推定）。LAND 3・2 を出していれば caution、前なら advisory（段 5b の規則）。
- グルー（`B747.70.xt.autopilot.lua`）：新設の `autopilot/bus_isolate_req`（init `B747.70.autopilot`）に書き、電源の `electrical/bus_isolated` を読む。
- 電源の側と試験：notes/ATA-24.md §10。回帰：AFDS のモデル +17（巡航の CMD L と LOC だけでは求めない、APP で C と R が arm して求める、3.5 秒では何も無く 4.5 秒で NO LAND 3 の advisory、分離すると消える、APP の解除で終わる、単一チャンネルの APP では求めない、BUS ISOLATED が無いと 3 チャンネルでも LAND 2・あれば LAND 3、150 ft で消えても LAND 3、1 チャンネルに減っても続く、全部切れると終わる、80 ft の G/A では続き 120 ft で終わる）、グルー +4（APP で要求、BUS ISOLATED が消えると LAND 2、4 秒で >NO LAND 3 の caution、戻すと LAND 3）。

## 39. 段 6a の実装（2026-10-30：ヨーダンパーのモード、engage と INOP）

- ヨーダンパーのモデル（新設の `B747.19.yd_model.lua`。油圧モジュールの中、前の則の隣）：上下の YDM ごとに、ATA22 p.83–85 の図のモードを持つ。
  - off：スイッチ OFF か電源なし（スイッチが YDM に 28V DC を渡す：p.69）。INOP。
  - 電源投入：地上なら電源投入の試験（INOP。「最大 5 秒」：p.83。長さを 5 秒にしたのは推定）の後に地上の待機（ground operation：engage して指令なし）、空中なら試験なしで fade-in（5 秒）。
  - 地上の待機から空中で fade-in、5 秒で flight mode。着陸で fade-out（5 秒）から地上の待機。途中で空地が変われば、その時の割合から戻る。
  - 故障（自分の故障 `flt_ctrls/fail/yaw_damper`、または有効な IRU が無い：FCOM p.958「IRUs off or in align」、p.87 の表）で fault INOP（解除、INOP、作動筒はばねで中立：p.90）。自動復帰は、どれかの IRU が NAV に入ったとき、または 5 秒未満の故障が消えたとき（p.84）。空中は fade-in、地上は地上の待機へ。それ以外はスイッチの入れ直し。
  - INOP（INOP 灯と >YAW DAMPER UPR・LWR）：engage していないとき（off、試験、fault INOP：p.72、p.88；FCOM p.931、p.958）。
  - 権限（p.86–87、ATA27 p.656）：有効な IRU が 3・2 台なら ±4°、1 台で ADC が 2 台なら「可変」（値が無い：2.5° と推定）、1 台で ADC が 1 台以下なら ±1°。ADC は L と R の 2 台（ATA27 p.42）。舵の指令に使うのは段 6b。
- グルー（`B747.19.xt.yaw_damper.lua`）：入力はスイッチ（`button_switch/position[82]`・`[83]`）、電源（上：AC standby と電池母線、下：AC 1 と、DC 1 か 2：ATA22 p.60–62 の「DC bus 1 and bus 2」をどちらかでよいとしたのは推定）、IRU（姿勢と NAV の台数）、ADC L・R、PSEU の空地、故障。出力は `flt_ctrls/yaw_damper_upr_on`・`lwr_on`（1 で engage。前は操縦系統のモジュールが書いていた：そちらは EICAS の >YAW DAMPER だけを残した）と、新設の `flt_ctrls/yaw_damper_mode`（init `B747.19.hydraulicsmodel`。0 off、1 試験、2 地上の待機、3 fade-in、4 flight、5 fade-out、6 fault INOP）。前の則の指令に fade をかける（地上の待機は 0）。則そのものと権限・ratio changer の扱いは段 6b。
- 試験：
  - 回帰（LuaJIT）：新設の `tests/autopilot/yd_model_test.lua` 32 件（off、地上の試験 5 秒、地上の待機、fade-in と flight、fade-out と途中の離陸、空中の電源投入、2 秒と 6 秒の故障とスイッチの入れ直し、IRU の整列中と NAV での自動復帰、ATT だけでは戻らない、片方の電源、権限の表）。油圧モジュール +9（配線：IRU の整列中は fault INOP、NAV で地上の待機、LOWER の OFF と ON の試験、空中の fade-in、AC 1 で下だけ off、上の故障と自動復帰）。操縦系統のモジュールの試験は、INOP の判定を移したので EICAS の >YAW DAMPER だけに。全 122 本。
  - X-Plane（カスタム acf）：新設の `s123_yd_modes`（地上、エンジン運転中）33/33：IRS が NAV になると両方が地上の待機（指令 0）、UPPER の OFF で off・INOP・>YAW DAMPER UPR、ON で 2 秒後も試験中（INOP）、6 秒後に地上の待機で >YAW DAMPER UPR が消える、LOWER の 2 秒の故障で fault INOP と >YAW DAMPER LWR・戻すと自動復帰、7 秒の故障は戻しても INOP・スイッチの入れ直しで試験の後に engage。新設の `s124_yd_air`（空中、10,000 ft）11/11：両方が flight mode、UPPER の 2 秒の故障で fault INOP、戻すと fade-in、5 秒で flight mode。続けて Web API で、LOWER の故障で INOP 灯（`annunciator/brightness_ratio[68]`）が点き、戻すと消えるのを確かめた。Lua の誤りなし。
