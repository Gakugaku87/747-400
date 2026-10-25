# ATA 31 表示系（IDS：PFD・ND・EICAS 表示、表示切替、時計）— 調査ノート

対象コード：`overhaul` ブランチ（feedd8a9。plugins と acf は本家 041c9ffa のまま）。2026-10-23 調査。GAP の ID 接頭辞は `DSP`。

## 1. 概要

- 範囲：PFD（速度テープと各種バグ・限界帯、姿勢、FD、FMA の枠、高度・V/S、最低高度、気圧、ILS、故障フラグ）、ND（APP/VOR/MAP/PLN、CTR、レンジ、WXR/STA/WPT/ARPT/DATA/POS/TFC、シンボル）、EICAS の表示形式（上下、DSP、synoptic の枠組み、STAT、compact）、ソース選択（EIU・IRS・ADC・FD・NAV、CDU 代替操作）、表示器の電源・故障・輝度、時計。FDR・ACMS・W&B は概観のみ。
- 範囲外：EICAS メッセージの発生ロジック（別担当。ここでは表示系に属するメッセージの有無だけ扱う）、各 synoptic の中身、FMC のデータそのもの、FMA の中身（AFDS 担当）、スタンバイ計器（ATA 34 担当）。
- 型式の基準：他のノートと同じく **109（旅客型 PW）**。405/570 との違いは必要な所だけ書く。パネルは 109 寄り（DH/MDA、10〜640 NM、MAP は track up）だが、TERR スイッチ（405/570 のみ）、ND の TAS 表示（405/570 のみ）、2 位置の AIR DATA 選択器（570 型。3D の `Cockpit_Panel.obj:31894`）が混ざる。
- 資料：
  - FCOM 10.10（p.963-1068）全頁、10.20（p.1069-1079）、10.30（p.1081-1107、図）、10.40（p.1109-1111、p.1140-1158）、10.50（p.1197-1199）、7.10-7.12（p.829-857）、7.20 のうち表示形式（p.872-875）、15.10 の EICAS・DSP・STAT（p.1527-1530、p.1545）、15.20 の EICAS 表示・ND 自動表示・速度警報（p.1547-1549、p.1556-1557、p.1582-1585）、6.20 の負荷表（p.800、p.804）、PI.10.3（p.229）。
  - ATA31：31-62 EFIS（p.3-58。図 p.5, 15-17, 55, 57 を画像で確認）、31-25 時計（p.59-82）、31-31 FDR（p.279, 292）、31-35 ACMS（p.338）、31-41 W&B（p.412-426）。補助に ATA27 p.698-702（SWMC）、ATA34_1 p.142（ADC の VMO 曲線）。FCOM p.1072-1073 の切替図を画像で確認。
- 資料どうしの関係：ATA31 の EFIS 章は NCD/invalid の表以外ほぼ図で、内部ロジック（EIU の内部、表示器の BITE）は載っていない。乗員から見える挙動は FCOM に従う。時計の CHR 表示は ATA31 p.68 が「分:秒」、FCOM p.1058 が「分（秒は秒針）」→ FCOM を採り、上限 99 分は ATA31 から取る。

## 2. 構成

### 2.1 構成品

| 構成品 | 内容 | 根拠 |
|---|---|---|
| 表示器（DU）6 台 | 左右 outboard（PFD）、左右 inboard（ND）、upper（primary EICAS）、lower（secondary EICAS）。WXR は inboard と lower にだけ入る | FCOM p.1069-1071 (10.20.1-3) |
| EIU 3 台（L/C/R） | 全系統のデータを受けて表示を作る。EICAS は 3 台のうち 1 台が全面を制御 | FCOM p.1069, p.1547 (15.20.1) |
| EFIS control panel 2 台 | 左は左 PFD/ND、右は右 PFD/ND。故障時は同じ側の CDU で代替 | FCOM p.1035 (10.10.73) |
| Display select panel（DSP） | ENG/STAT/ELEC/FUEL/ECS/HYD/DRS/GEAR、CANC、RCL | FCOM p.1046-1047 |
| 計器ソース選択パネル ×2 | FLT DIR（L/C/R）、NAV（FMC L/FMC R/CDU L(R)/CDU C）、EIU（L/AUTO/C/R）、IRS（L/C/R）、AIR DATA（109 は L/C/R） | FCOM p.1043-1044 (10.10.81-82) |
| 中央パネル EIU 選択器 | EICAS 用の EIU（L/AUTO/C/R） | FCOM p.1529 (15.10.3) |
| INBD/LWR 表示選択器 ×2、HDG REF スイッチ | 表示の割り当て、方位基準 | FCOM p.1045-1046 |
| 輝度つまみ | outboard、inboard（外：表示、内：WXR）、upper、lower（外：表示、内：WXR）。周囲光センサーで自動補正 | FCOM p.1047-1048, p.1071 |
| SWMC（ATA 27-32） | 最小速度（stick shaker 速度）、Vmo、PLI のパラメーターを EIU 経由で供給 | ATA27 p.698, p.701-702 (27-32) |
| 時計 ×2 | UTC/日付、ET、CHR。グレアシールドの CHR スイッチと並列 | ATA31 p.60, p.66-70 (31-25) |

### 2.2 電源（109）

| 負荷 | バス | 根拠 |
|---|---|---|
| 左 PFD・左 ND（と左 FMC） | APU standby bus（通常は captain transfer bus。AC1・AC3 が無いと APU standby inverter） | FCOM p.800 (6.20.6), p.804 (6.20.10) |
| 右 PFD・右 ND、lower EICAS、右 EIU、右 EFIS CP、右 ADC、右 FMC/CDU | F/O transfer bus（AC2、無ければ AC1） | FCOM p.800 |
| upper（primary）EICAS、左 EIU、左 CDU、左 ADC、左 EFIS CP | main standby bus（AC3、無ければ main standby inverter） | FCOM p.804 |
| 中央 EIU、中央 ADC | captain transfer bus | FCOM p.800 |
| 時計 | main hot battery bus が時刻基準と電源 A/B。APU battery bus の電圧で表示（電源 B）を許可 | ATA31 p.64, p.74 (31-25) |
| DSP、輝度つまみ | 資料に記載なし | — |

- standby 電源で左 EIU が故障すると全表示器が消える（FCOM p.1529）。全 6 面が消えたら EIU L・C の CB を入れ直す（FCOM p.55、Operations Manual Bulletin）。

### 2.3 PFD のデータ源

姿勢＝IRS、ILS＝ILS と DME、速度テープ＝ADC・FMC・stall warning computer、FMA＝FCC と FMC、電波高度＝RA と EFIS CP、高度＝ADC、V/S＝IRS と ADC、方位＝FMC と IRS、選択方位＝FCC、滑走路方位＝ILS、マーカー、windshear＝GPWS（ATA31 p.6 (31-62)）。

## 3. 操作と表示

### 3.1 EFIS control panel（109）

| 操作 | 機能 | 根拠 |
|---|---|---|
| DH/MDA 選択（外）・設定つまみ（中）・RST（内） | DH＝電波高度、MDA＝気圧高度を設定。RST は点滅する amber DH を消す（値は変えない） | FCOM p.1036 (10.10.74) |
| MTRS / FPV（押しボタン） | PFD にメートル高度 / flight path vector を出す | FCOM p.1036-1037 |
| BARO：IN/HPA（外）、つまみ（中）、STD（内） | STD で 29.92/1013。STD 中は回すと preselect、もう一度 STD で preselect、preselect が無ければ STD 前の値 | FCOM p.1037 (10.10.75) |
| ND モード（外）・CTR（内） | APP/VOR/MAP/PLN。CTR は APP/VOR/MAP で拡大↔中心を交互に | FCOM p.1039 |
| レンジ（外）・TFC（内） | 109 は 10〜640 NM。TFC は VOR/APP/MAP/MAP CTR で TCAS 表示、TCAS FAIL を消す | FCOM p.1041-1042 |
| VOR/ADF L・R | VOR：針・識別符号/周波数・DME、ADF：針・識別符号/周波数（PLN 以外）、OFF で消す | FCOM p.1040; ATA31 p.24 |
| WXR/STA/WPT/ARPT/DATA/POS | 3.4 の表を参照。2 回押しで消える。多すぎると EXCESS DATA | FCOM p.1040 |

### 3.2 その他の操作

| 操作 | 機能 | 根拠 |
|---|---|---|
| ISS：EIU | L/C/R：その EIU。AUTO：機長は L→C→R、副操縦士は R→C→L の順に使える物を選ぶ。ILS 受信機もこれで決まる | FCOM p.1044 |
| ISS：IRS | 選んだ IRU の姿勢と V/S。方位・風・横滑り・航跡・偏流・GS は FMC/IRU の状態と NAV・IRS 選択器で決まる | FCOM p.1044 |
| ISS：AIR DATA / FLT DIR / NAV | ADC、FCC、FMC（CDU 位置は alternate navigation で ND の地図源） | FCOM p.1043-1044 |
| 中央 EIU SEL | AUTO：L→C→R。手動位置でその EIU が壊れると自動切替しない | FCOM p.1529 |
| INBD | EICAS：inboard に secondary（または primary）EICAS。NORM：ND（outboard 故障なら PFD）。PFD：inboard に PFD | FCOM p.1045 (10.10.83) |
| LWR | EICAS PRI：lower に primary EICAS。NORM：DSP の選択（upper 故障なら primary EICAS）。ND：lower に ND | FCOM p.1045 |
| HDG REF | NORM：磁方位（高緯度域では自動で真方位、AFDS は LNAV 以外不可）。TRUE：真方位。HDG SEL 中に切り替えると HDG HOLD | FCOM p.1046 |
| DSP | 押すと lower に表示、同じものをもう一度押すと消える。STAT は次ページ、最終ページで消える。CANC/RCL は 3.5 | FCOM p.1047, p.1530 |

### 3.3 PFD（要点）

| 要素 | 内容・条件 | 根拠 |
|---|---|---|
| 現在速度 | ADC 速度。計算値なしは 30 kt。最小機動速度未満で枠が amber。M.40 以上で Mach | FCOM p.968 (10.10.6) |
| 速度トレンド | 10 秒後の予測 | FCOM p.968 |
| 指令速度バグ・表示 | MCP の IAS/MACH、窓が空なら FMC 速度。範囲外は上下端に半分 | FCOM p.968-969 |
| 最大速度（red/black） | Vmo/Mmo、脚・フラップ placard の最小 | FCOM p.969 |
| 最大機動速度（amber） | 1.3 g で高速バフェット。高高度・高重量で出ることがある | FCOM p.969 |
| 最小機動速度（amber） | フラップ下げ：shaker まで 1.3 g。フラップ上げ 20,200 ft 未満：shaker まで 1.3 g と VREF+80 の小さい方。20,200 ft 以上：低速バフェットまで 1.3 g。離陸後最初のフラップ上げで表示開始 | FCOM p.973 (10.10.11) |
| 最小速度（red/black） | stick shaker（または低速バフェット）速度 | FCOM p.973 |
| V1・VR | CDU で選択したとき。VR が V1 から 4 kt 以内なら「R」。V1 が範囲外なら上端に数字。浮揚で消える。未選択は NO V SPD | FCOM p.972 |
| フラップ機動速度 | 現在の設定と 1 段小さい設定。約 20,000 ft 以上では出さない。値は UP=VREF30+80、1=+60、5=+40、10=+20、20=+10、25=VREF25、30=VREF30 | FCOM p.972; p.229 (PI.10.3) |
| VREF | CDU 選択値。範囲外なら下端に数字 | FCOM p.973 |
| 姿勢 | ピッチ目盛 2.5°、バンク目盛 0/10/20/30/45°。LCD はバンク 35° 以上で amber。PLI は 109 でフラップが上がっていないとき。左右の差で PITCH/ROLL フラグ | FCOM p.975 (10.10.13) |
| FD・FPV | FD バー。FPV は EFIS CP で選択 | FCOM p.980 |
| 電波高度・DH（109） | 2,500 ft 未満で表示。DH 以下で大きな点滅 amber DH。着地、DH+75 ft の復行、RST で解除。DH が 0 未満なら非表示 | FCOM p.981-982 |
| ILS | 識別符号/周波数、DME、コース（受信機間の不一致は amber の横線）。ポインターは 2⅓ dot 以内で塗りつぶし。目盛は同調後に表示。低高度で AP/FD 使用中に偏位過大なら目盛 amber・ポインター点滅（LNAV 中で LOC 未捕捉も）。expanded LOC は 1 枠 ½ dot。rising runway は 2,500 ft 未満、200 ft 未満で近づく。マーカー点滅（OM 青/MM amber/IM 白） | FCOM p.986-989 |
| 高度 | 選択高度（範囲外は端に半分）、メートル併記。到達前 900〜300 ft で枠を白強調、逸脱 300〜900 ft で amber。10,000 ft 未満は万の桁が斜線 | FCOM p.991-992 |
| MDA・TDZ（109） | MDA ポインターと数字（-100 ft 未満で非表示）。TDZ 斜線は FMC の着陸高度（出発地は 400 NM か半分の距離まで） | FCOM p.993 (10.10.31) |
| 気圧 | 設定値、STD、preselect、IN/HPA。遷移高度の上下 300 ft で設定の誤りがあれば枠付き amber | FCOM p.995 |
| V/S | ポインター、V/S モード中の選択 V/S、400 fpm 超で数字 | FCOM p.996 |
| 方位 | 方位ポインター（IRS 方位）、航跡、選択方位、MAG/TRU（TRU は枠） | FCOM p.997-998 |
| 故障フラグ | FPV、SEL SPD、SPD LIM、NO V SPD、SPD（NO V SPD・SEL SPD・SPD LIM・MACH を抑制）、ATT、FD、LOC、HDG、MACH、DH、RA、G/S、VERT、ALT、NO TDZ | FCOM p.999 (10.10.37) |

### 3.4 ND（要点）

| 要素 | 内容・条件 | 根拠 |
|---|---|---|
| モードと向き | MAP は 109 で track up、VOR・APP は heading up、PLN は真北 up で動かない（LEGS の STEP で送る）。APP CTR・VOR CTR・PLN では WXR・TCAS を出さない | FCOM p.1039, p.1109-1110 |
| 方位基準 | 磁/真。TRU で 2,000 ft を 800 fpm 超で降下すると基準の枠が amber で 10 秒点滅、2,000 ft を 500 fpm 超で上昇すると白に戻る。TRU→MAG で MAG を 10 秒枠囲み | FCOM p.1110, p.1142 |
| 選択方位 | PLN 以外。MAP で LNAV/LOC/ROLLOUT 中は、つまみを動かしてから 10 秒で破線だけ消す | FCOM p.1142 |
| 航跡線・レンジ | MAP・MAP CTR。VOR/APP では WXR か TFC がオンのとき | FCOM p.1143 |
| STA / WPT / ARPT | STA：10〜40 NM で高・低高度の施設、80 NM 以上は高高度だけ。同調中の VHF 施設はスイッチによらず緑。WPT：10〜40 NM。ARPT：全レンジ。出発・到着空港は常時 | FCOM p.1040, p.1145, p.1149 |
| DATA / POS | DATA：PLN・MAP・MAP CTR で ETA・高度・高度制限。POS：MAP・MAP CTR で IRU・GPS 位置、NAV RAD の VOR への radial（DME があれば距離に印） | FCOM p.1040 |
| 経路と諸点 | 経路（有効 magenta、変更 白破線、非有効 青長破線）、トレンドベクトル（30 秒ごと、レンジで 1〜3 区間）、高度到達弧、T/C・S/C・T/D・E/D、VNAV パスポインター（降下中のみ、±400 ft、超えたら数字）、空港・滑走路（80 NM 以上で空港、40 NM 以下で滑走路と 14.2 NM の中心線）、待機・PT、エネルギー円、FIX の基準点 | FCOM p.1147-1150 |
| 位置更新状態 | IRS(3)・DD・VD・LOC・GPS など。IRS(3) から変わると 10 秒緑枠 | FCOM p.1150 |
| GS・TAS・風 | GS は 30 kt 未満で大きい字。TAS は 405/570 のみ（100 kt 超） | FCOM p.1141-1142 |
| TCAS | RA 赤、TA amber、近接（1,200 ft・6 NM 以内）白塗り、他 白。相対高度、500 fpm 以上で矢印。OFFSCALE、TRAFFIC、no bearing 表示、TFC/TCAS TEST/TA ONLY（青）、TCAS FAIL/TCAS OFF（amber） | FCOM p.1031-1032, p.1152-1154 |
| メッセージ・フラグ | EXCESS DATA、WXR 系、RSTR INOP、MAP/WXR RANGE DISAGREE。HDG/TRK、MAP、VOR/LOC、VOR/ADF L・R、DME、VTK、G/S のフラグ。CDU が地図源なら CDU L/C/R | FCOM p.1030-1034, p.1151 |

### 3.5 EICAS の表示

- primary：EPR・N1・EGT（PW）、TAT、推力基準、メッセージ（警告→注意→勧告→メモ、1 ページ 11 行）、ページ番号、STATUS 差（cyan、新しいステータス。エンジン始動から離陸後 30 分は抑止）、二次エンジン逸脱差（cyan、STATUS 差より優先）、RECALL（離して 1 秒）（FCOM p.1527-1529, p.830）。
- secondary：二次エンジン（N2・FF・OIL P/T/Q・VIB）。電源投入時と、空中で燃料制御スイッチを CUTOFF にしたときに自動表示（FCOM p.843 (7.11.3), p.872 (7.20.2)）。109 は STAT ページに舵面位置（FCOM p.938 (9.10.12)）。
- 部分表示：二次エンジン非選択中に逸脱すると該当項目だけ出る。他の synoptic を選ぶと primary に compact で出る。表示器が 1 台なら primary に compact（FCOM p.874-875 (7.20.4-5), p.856-857）。
- STAT：ステータスメッセージ 11 行とページ番号（FCOM p.1545）。
- CANC：次ページ、最終ページで caution・advisory を消す（warning・memo は残る）、超過の赤枠を白に。RCL：1 ページ目へ全部再表示、赤枠を戻す（FCOM p.1530, p.1548-1549）。

### 3.6 CDU 代替操作（CDU-152）

MENU の EFIS CP / EICAS CP（パネル故障時に SELECT）→ EFIS CONTROL（BARO SET、DH SET、DH RESET、MDA SET、RANGE INCR/DECR、MODE、CTR、OPTIONS）、EFIS OPTIONS（WXR/POS/MTRS/FPV/WPT/STA/ARPT/DATA、VOR/ADF。TCAS は不可）、EICAS MODES/SYNOPTICS。各 CDU は自分の側の EFIS を操作する（FCOM p.1060-1068）。

### 3.7 時計

CHR（3 回で開始・停止・リセット、グレアシールドの CLOCK と同格）、秒針、ET（RUN/HLD/RESET。RESET は HLD に戻るばね）、DATE（日・月と年を 1 秒ごとに交互、もう一度で時刻）、SET（RUN/HLD Y/MS M/HS D）（FCOM p.1058-1059; ATA31 p.66-70）。

### 3.8 EICAS メッセージ（表示系）

| メッセージ | 種別 | 条件 | 根拠 | 現状 |
|---|---|---|---|---|
| >SNGL SOURCE RA | 勧告 | 両席が同じ RA | FCOM p.1197 (10.50.1) | 未実装（warning.lua:452） |
| >SOURCE SEL ADC/EIU/F/D/IRS/NAV | 勧告 | 両席が同じ ADC/EIU/FCC/IRU/FMC | FCOM p.1197 | 未実装（:453-457） |
| ALT DISAGREE | 注意・beeper | 未補正高度の差 200 ft 超が 5 秒超 | FCOM p.1197 | 未実装（:109） |
| >ATTITUDE | 注意・beeper | 選択 IRS の姿勢差 3° 以上 | FCOM p.1197 | 未実装（:111） |
| >BARO DISAGREE | 勧告 | 気圧設定の不一致が 1 分超 | FCOM p.1198 | 実装（fltInst02.lua:3184-3195） |
| >HEADING | 勧告 | 表示方位の差 4° 以上 | FCOM p.1198 | 未実装（:371） |
| IAS DISAGREE | 注意・beeper | 差 5 kt 以上が 5 秒超 | FCOM p.1198 | 未実装（:152） |
| >TRACK | 勧告 | 航跡の差 6° 以上 | FCOM p.1198 | 未実装（:477） |
| >AOA RIGHT | 勧告 | 右 AOA 故障 | FCOM p.1198 | 実装（X-Plane の rel_AOA、fltInst02.lua:3176-3182） |
| >EFIS CONTROL L, R / >EFIS/EICAS C/P | 勧告 | EFIS CP 故障 / 両 CP と DSP 故障 | FCOM p.1198-1199 | 未実装（:274-276） |
| >EIU LEFT | 勧告 | 左 EIU 故障。空中は抑止 | FCOM p.1199 | 未実装（:277） |
| >SNGL SOURCE ILS | 注意・beeper | 両席が同じ LOC/GS 受信機 | FCOM p.1430 (11.60.2) | 未実装（:165） |
| >AIRSPEED LOW | 注意・beeper | 最小機動速度未満 | FCOM p.1556, p.1605 | 実装（代用値、fltInst02.lua:3166-3174） |
| >OVERSPEED | 警告・siren | Vmo/Mmo 超過（placard は含まない） | FCOM p.1557, p.1605 | 実装だが placard でも出る（:3156-3164） |

## 4. 内部ロジック

### 4.1 表示器の割り当てと切替

- 通常：outboard＝PFD、inboard＝ND、upper＝primary EICAS、lower＝secondary EICAS（FCOM p.1071）。
- 自動切替：outboard が壊れると PFD は inboard へ（INBD NORM のとき）。upper が壊れると primary EICAS は lower へ（LWR NORM のとき）（FCOM p.1045, p.1072）。
- 手動：INBD EICAS で inboard に secondary EICAS（図では upper 故障で primary は lower）、LWR ND で lower に ND（FCOM p.1073 の図）。故障が無いときに表示が消える面がどうなるかは資料に記載なし。
- 表示器 1 台だけが EICAS に使えるとき：primary を常に出し、二次エンジンは compact（FCOM p.874）。
- 実装の考え方：表示器ごとに「電源・故障」の状態を持ち、選択器と故障から各表示器の内容を決める。結果はいまの `laminar/B747/flt_inst/display/*_pos` と `electrical/display_has_power[0..5]`（内容ごとの電源）に出す（パネルの約束）。

### 4.2 ソース選択と比較

- 通常位置（NP）：機長は FD L・NAV FMC L・EIU AUTO・IRS L・AIR DATA L、副操縦士は FD R・NAV FMC R・EIU AUTO・IRS R・AIR DATA R（FCOM p.111, p.115 (NP.21)）。
- EIU：席ごとに有効な EIU を AUTO の優先順で決める。その EIU が ILS 受信機を決める（FCOM p.1044）。EICAS は中央 EIU SEL の EIU（FCOM p.1529）。
- IRS：姿勢と V/S は選択 IRU。方位・航跡・風・GS は FMC 正常時は FMC 経由（ND の track は FMC、alternate navigation では IRU）（FCOM p.1044, p.1110）。IRS 選択は SWMC の入力も切り替える（ATA27 p.698）。
- AIR DATA：速度・高度・Mach・TAT。中央 ADC を選ぶと V/S が遅れることがある（FCOM p.1079 (10.20.11)）。
- 同じソースを両席で使うと SOURCE SEL、比較の閾値は 3.8 の表。RA は 3 台で、RA フラグは 3 台とも無効のとき（ATA31 p.16）。
- NCD と invalid（ATA31 p.15-17, p.55, p.57）：invalid はシンボルを消して黄色（amber）のフラグ、NCD はフラグなしで消す（または `---`）。例：姿勢 invalid→ATT、NCD→消去のみ。G/S・LOC invalid→目盛ごと消してフラグ、NCD→ポインターだけ消す。速度 invalid→SPD。MACH invalid→MACH、NCD か CAS invalid→消すだけ。HDG invalid→HDG、NCD→数字だけ消す。V/S invalid→VERT。DH は EFIS CP の値が invalid/NCD で DH。RA は 3 台とも invalid で RA。最大速度は SWC の Vmax と ADC の最大速度予定がともに invalid で SPD LIM、最小速度は SWC の Vmin invalid で SPD LIM。FMA invalid は文字に黄色の線。V 速度 invalid→NO V SPD。地図 invalid→MAP。

### 4.3 速度テープの値

| 値 | 求め方 | 根拠 |
|---|---|---|
| Vmo/Mmo | ADC のソフトに入った曲線（gear down dispatch で別曲線）。数値は資料に記載なし | ATA34_1 p.142 (34-12) |
| 最大速度 | Vmo/Mmo、脚 placard、フラップ placard の最小。SWMC と ADC から | FCOM p.969; ATA31 p.17 |
| 最大機動速度 | 1.3 g で高速バフェットに達する速度。高高度・高重量でだけ帯が現れる | FCOM p.969 |
| 最小機動速度 | 3.3 の 3 区分（20,200 ft 境界）。離陸後最初のフラップ上げから表示 | FCOM p.973 |
| 最小速度 | SWMC が AOA・フラップ・スポイラー・Mach から出す shaker 速度 | ATA27 p.698, p.701-702 |
| フラップ機動速度 | 3.3 の VREF30 基準。FCU が全部壊れると出ない | FCOM p.229; FCOM p.53 (bulletin) |

- 1.3 g の境界と shaker 速度の数値表は資料に記載なし。重量・高度・Mach・フラップから求める近似が要る（推定：PI の失速速度表と buffet boundary を使う）。

### 4.4 最低高度・気圧・高度・ILS

- DH（109）：電波高度 ≤ DH で amber DH 点滅。点滅時間は資料に記載なし。解除は着地、DH+75 ft までの上昇、同じ側の RST（FCOM p.981-982）。各 PFD は自分の側の DH と RA で判定する（推定：DH は EFIS CP ごとに設定し、両席が同じ RA を使うと SNGL SOURCE RA が出るため）。
- 気圧 STD の状態機械：通常→STD 押し＝STD（29.92/1013、preselect 無し）。STD 中に回す＝preselect を表示。STD 押し＝preselect があればそれ、無ければ STD 前の値（FCOM p.1037）。遷移高度の警告：気圧設定のまま MCP が遷移高度より上で、遷移高度+300 ft を越えると枠付き amber。STD のまま MCP が遷移高度より下で、遷移レベル−300 ft を下回ると同じ（FCOM p.995）。遷移高度・遷移レベルは FMC の値（推定）。
- 高度枠：選択高度の 900〜300 ft 手前で白強調、捕捉後 300〜900 ft 逸脱で amber（FCOM p.991-992）。ALTITUDE ALERT 本体は警報担当。
- ILS：スケールは同調で表示（FCOM p.987）。偏位過大の amber 化は「低い電波高度で AP/FD 使用中」としか書かれておらず、高度と dot の閾値は資料に記載なし。

### 4.5 ND

- 向き：MAP＝航跡（FMC、無効なら IRU）、VOR/APP＝方位、PLN＝真北。向きの基準は MAG/TRU に従う（FCOM p.1110）。
- レンジ表示は選択レンジの半分の弧に数字を出す（推定：FCOM p.1001 の図で 40 が 80 NM 相当の位置）。
- 自動表示（FCOM p.1583-1585 (15.20.37-39)）：immediate windshear 中は新しい TCAS（109）を自動表示しない。新しい TA/RA で、片方の ND に TFC が出ていればその ND は維持し、もう片方は抑止（後で TFC を押すと表示）。どちらにも出ていなければ両 ND で自動選択。MAP/MAP CTR/VOR/APP 以外の ND は「待機」し、そのモードになると自動選択。TA/RA が終わっても自動では消さない。TERR（405/570）・PWS→WXR も同様（WXR/TERR を先に選べば解除）。
- EXCESS DATA：表示できる量を超えたらメッセージ。上限は資料に記載なし。

### 4.6 EICAS の形式とページ

- secondary の状態：OFF / 全表示 / 部分表示。ENG 押し：OFF↔全表示、部分表示中は全表示↔部分表示。他の synoptic 選択中の逸脱は primary に compact の部分表示。逸脱が戻るまで部分表示と差は消えない。差が出ていて部分表示が無いとき STAT を押すと primary に compact（FCOM p.874-875）。
- メッセージのページ：警告が 1 ページを超えたらページ番号を出さない。新しい注意・勧告は見ているページの警告の直下に入る。RCL は 1 ページ目に戻す（FCOM p.1548-1549）。
- STAT：新しいメッセージが上。STAT の押し方は CANC/RCL と同様のページ送り（FCOM p.1549）。

### 4.7 時計

- 電源：main hot battery bus が無いと全機能停止（電源復帰後は 00:00 と秒針 60 で、SET の HLD Y で 1 桁進めるまで NCD）。APU battery bus が無いと表示だけ消え、内部は動く（ATA31 p.66, p.74, p.78, p.80; FCOM p.1075）。
- 機長時計が FMC L、副操縦士時計が FMC R へ UTC/日付。FMC は機長時計を主、故障で副へ。GPS があれば GPS が時刻源（ATA31 p.77; FCOM p.1075）。
- SET：MS は 1 分/秒、HS は 1 時間/秒で進む。HLD で停止、RUN で開始（ATA31 p.67）。ET は 99:59 まで、CHR は 99 分 59 秒まで（ATA31 p.67-68）。

### 4.8 FDR・ACMS・W&B（概観）

- FDR：空中、またはエンジン 1 発以上作動で記録。最新 25 時間。EIU からデータ、故障は EIU へ。DFDAC は standby bus と F/O transfer bus、DFDR は AC3（ATA31 p.279, p.292 (31-31)）。乗員の操作は無い。
- ACMS：DMU と QAR。報告を中央 CDU・プリンター・ACARS へ（ATA31 p.338 (31-35)）。
- W&B（オプション）：脚の荷重から GW・CG。ground service bus 給電。FMC（PERF INIT の GR WT ADV、TAKEOFF の CG）と EIU へ（ATA31 p.414, p.422, p.426 (31-41); FCOM の FMC 章）。FMC 担当。

## 5. 他系統とのつながり

| 相手 | 内容 | 根拠・現状 |
|---|---|---|
| 電源（ATA 24） | 2.2 のバス。表示・EIU・時計の通電判定 | 現状は `capt_display_power`・`fo_display_power` の 2 値（electrical.lua:546-548）。ATA-24 ノートの ELEC-01/02 が前提 |
| IRS（ATA 34） | 姿勢・方位・航跡・GS・風、整列状態（TIME TO ALIGN） | `laminar/B747/pfd/{capt,fo}/irs` は irs_system.lua:209-210 が「位置入力済み かつ 選択 IRU 整列」で 1 にする |
| ADC・RA・ILS/VOR/ADF/DME（ATA 34） | 速度・高度・Mach・TAT、RA、偏位・識別符号 | パネルは X-Plane の pilot/copilot 計器 dataref を直接読む。VOR L/R は nav 番号 2/3、ILS は 0/1（B744.fms.pages.lua:2562-2565） |
| SWMC（ATA 27） | 最小速度、Vmo、PLI | 現状は fltInst02 が表で代用し、stick shaker（`sim/flightmodel/failures/stallwarning`）と `sim/cockpit2/autopilot/TOGA_pitch_deg` まで書いている（fltInst02.lua:3083-3123） |
| AFDS（ATA 22） | FMA、FD バー、指令速度、選択方位・高度、`ils_dots` | `ils_dots` は autopilot.lua:1635-1638, 1792-1797 |
| FMC（ATA 34-61） | 経路・地図、V 速度選択、VREF、着陸高度（TDZ）、遷移高度、ND の文字列（GS/TAS/風、次 WPT） | V1/VR/V2 は fltInst02 が表から自動計算（選択操作なし）。ND 文字列は B747.68.xt.fms.lua:930-1042 |
| TCAS・GPWS・WXR | ND の交通・地形・気象、PFD の PULL UP/WINDSHEAR | 気象・地形は X-Plane の EFIS map と外部 Terrain Radar |
| EICAS メッセージ（別担当） | 表示系メッセージ（3.8）、CAS ページ、STATUS | warning.lua:895-1000 がページを作る（最大 10 ページ） |
| エンジン（ATA 77） | 一次・二次表示の値と色 | 別担当。形式（compact/部分）はここ |
| 燃料 | 燃料制御スイッチで ENG 表示 | fuel.lua:568-594 が `dsp/synoptic_display` を書く |
| 照明 | 表示器の輝度 | lighting.lua:893-918 |

## 6. 実装上の注意

- **パネルの制約**：描画は acf 末尾の generic instrument。純正 acf は変えない。カスタム acf の変更は承認が要る。各 GAP に【Lua のみ】【パネル変更要】を付けた。パネルは表示内容ごとに `display_has_power[i]` と `*_pos` で位置と電源を切り替える作り（内容 0=機長 PFD、1=副 PFD、2=副 ND、3=機長 ND、4=upper、5=lower、6〜8=CDU）。この意味は変えない。
- パネルの読み先：速度テープは Lua の `laminar/B747/gauges/indicators/airspeed_kts_*`（fltInst02.lua:3223-3234）なので Lua でソースを変えられる。高度・姿勢・方位・V/S・RA・ILS は X-Plane の `sim/cockpit2/gauges/indicators/*_pilot/_copilot` を直接読む。X-Plane 12 には ADC・AHRS を席の間で切り替える dataref が無い（`Resources/plugins/DataRefs.txt` で確認。あるのは `alternate_static_air_ratio` と HSI/RMI の航法源だけ）ので、ソース切替にはパネル変更（Lua が作る席別の値を読ませる）が要る。
- SHOW 条件の意味：`SHOW_GREATER 1 .../pfd_pos`（値は 0/1）や、存在しない `display/fo/eicas_pos` に `SHOW_GREATER 0` で EICAS が出ていることから、SHOW_GREATER/LESS は「以上/以下」と推定（ATA-28 ノートと同じ結論）。複数条件が AND か OR かは未確認（`GROUP <= DH`、747-400.acf:86915 は AND なら決して表示されない）。
- 型式の混在（1 章）：109 を基準にし、TERR と ND の TAS は設定でどちらにもできるようにするのが無難。PFD の LCD/CRT は `laminar/B747/pfd/style`（simconfig）で、現パネルの差は NO V SPD の絵だけ。
- 他系統のロジックが fltInst02 に同居している（stick shaker、TO/GA ピッチ目標、BAT DISCH MAIN・BATTERY OFF、OVERSPEED/AIRSPEED LOW）。作り直しでは所管の系統へ移し、表示系は「表示用の値を読むだけ」にする。`dsp/synoptic_display` は燃料モジュールも書く（XTLua では複数モジュールからの書き込みが非同期に競合する）。
- ND の地図記号は 1 側 60 個の文字アイコン（`nd/{capt,fo}/text/*`）と X-Plane の EFIS map（WXR・地形・経路）の重ね合わせ。アイコン位置の更新は毎フレーム、航法データの JSON 解読は 2 秒ごと、`earth_fix.dat` は前回の走査完了から 10 秒後に少しずつ走査（nd.lua:552-607, 690-768）。アイコンの作り直しは 0.2 秒ごとのつもりだが判定を誤っていて実質ほぼ毎フレーム（DSP-21）。仕組み自体は残してよい。
- 簡略化してよい：EIU の内部、表示器の BITE、色故障、周囲光センサー、ACMS、W&B、FDR（開発用ログのままでよい）。簡略化してはいけない：ソース選択が表示内容と SOURCE SEL/DISAGREE に効くこと、最低高度の警報と解除、速度テープの限界値、表示器喪失時の切替と compact EICAS、CANC/RCL/STAT のページ操作、OVERSPEED の条件。

## 7. 現状実装との比較（GAP 候補）

| ID | 種別 | 重要度 | 規模 | 内容 | 根拠 | 該当コード |
|---|---|---|---|---|---|---|
| DSP-01 | 挙動の誤り | 高 | S | PFD の方位目盛が `laminar/B747/nd/up/*` で回る。ND が MAP なら航跡、PLN なら 0（真北）が上になり、PFD の方位ポインターが IRS 方位を示さない。ND 側は同じ dataref が必要なので Lua だけでは直せない【パネル変更要：PFD を方位の dataref に】 | FCOM p.997 (10.10.35) | nd.lua:698-721; 747-400.acf:88024, 88078, 91613, 91667, 95171, 95225, 98739, 98793 |
| DSP-02 | 欠落 | 高 | L | ソース選択が無い。FLT DIR・NAV・EIU・AIR DATA の選択器と中央 EIU SEL は位置を変えるだけ。IRS 選択器は姿勢の有効判定にだけ効く。PFD/ND は常に X-Plane の pilot/copilot 側、RA は両 PFD とも機長側（`efis/radio_altitude`）。比較監視（SOURCE SEL、SNGL SOURCE）も無い【一部パネル変更要：速度テープは Lua のみ】 | FCOM p.1043-1044, p.1197; ATA31 p.16 | fltInst02.lua:520-657, 2366-2379; irs_system.lua:209-210 |
| DSP-03 | 挙動の誤り | 高 | M | パネルが NAV ソース選択器（FMC L/FMC R/CDU）を ND の基準受信機の選択に流用。機長 ND は NAV=0 で ILS L、1 で ILS R、2 で VOR L、3 で VOR R（副は 2=ILS L、3=ILS R、0/1=VOR で、要素によって 0 と 1 が入れ違い）。通常位置 FMC L では VOR モードにコース・偏位・受信機表示が出ない。PFD の ILS コースと DME は FMC master 選択器で nav1/nav2 を切り替える【パネル変更要：基準受信機用の dataref を新設】 | FCOM p.1043-1044, p.1144 | 747-400.acf:108772, 108834, 108900（機長 ND）、86769, 87735（PFD）; fltInst02.lua:3453-3454 |
| DSP-04 | 欠落 | 中 | L | PFD の故障フラグは ATT・HDG・VERT（どれも IRS 未整列で一斉）と NO V SPD だけ。SPD・ALT・MACH・FD・G/S・LOC・RA・DH・FPV・SEL SPD・SPD LIM・NO TDZ・PITCH/ROLL が無い（PITCH/ROLL は画像だけある）。NCD と invalid の区別も無い【パネル変更要】 | FCOM p.999; ATA31 p.15-17 | 747-400.acf:87107, 88117 |
| DSP-05 | 挙動の誤り | 高 | M | 速度テープの帯が違う。最大機動速度は常に Vmax−10（高高度・高重量でだけ出るはず）。最小機動速度は重量とフラップの独自式（20,200 ft の区分、1.3 g、VREF+80 が無い）。表示開始は推力基準が TO 以外になったとき（最初のフラップ上げではない）【Lua のみ】 | FCOM p.969, p.973 | fltInst02.lua:2858-2876, 2986 |
| DSP-06 | 挙動の誤り | 高 | S | OVERSPEED を Vmax（フラップ・脚 placard 込み）で出している。FCOM では Vmo/Mmo のみ【Lua のみ】 | FCOM p.1557 (15.20.11) | fltInst02.lua:3156-3164 |
| DSP-07 | バグ | 中 | S | 最小速度（Vs）の高度区分で 0 ft 以上は常に 0〜2,000 ft 帯（elseif が届かない）。2,000 ft 超の値が 2,000 ft で頭打ち【Lua のみ】 | — | fltInst02.lua:3018-3032 |
| DSP-08 | バグ | 中 | S | 表の誤記：VsData F20 10,000 ft 200 t＝133.60、F20 0 ft 360 t＝156.66、VR F10 D 領域 320〜420 t＝93〜111、VR F20 D 220 t＝97、V2 F20 E 380 t＝149（V 速度は FMC 担当と調整）【Lua のみ】 | — | fltInst.lua:116, 137, 193, 274, 277 |
| DSP-09 | バグ | 高 | S | DH RST を押すと、両席の DH を 350 ft（MDA 選択中は MDA を 1,000 ft）に書き換える。RST は点滅を消すだけ。副の RST は機長側のスイッチ位置も 1 にして離しても戻さないので、機長が RST を押し直すまで DH 警報が毎フレーム即解除される（3D のボタンも押されたまま）【Lua のみ】 | FCOM p.1036 | fltInst02.lua:778-792, 949-963 |
| DSP-10 | 挙動の誤り | 中 | M | DH 警報は機長の DH・RA だけで計算し、両 PFD が同じ `dec_height/display_status` を読む（副の PFD も機長の DH で表示が変わる）。点滅は 5 秒で止まり点灯のまま（時間は資料に記載なし）。RA の amber グループの条件が矛盾（`<= DH`）【パネル変更要：席ごとの dataref】 | FCOM p.981-982 | fltInst02.lua:2248-2311; 747-400.acf:86841, 86915 |
| DSP-11 | 挙動の誤り | 中 | S | STD を押すと preselect を 29.92 にするので、戻すと「STD 前の値」でなく 29.92 になる。遷移高度の amber 枠が無い（パネル）。CDU の BARO 入力・STD が両席に効く【一部パネル変更要】 | FCOM p.995, p.1037, p.1064 | fltInst02.lua:859-871, 1030-1042; B744.fms.pages.lua:957-984 |
| DSP-12 | 欠落 | 中 | L | PFD の記号が無い：FPV（スイッチもラッチしない）、PLI、TDZ、選択高度枠の白強調と amber、LCD のバンク 35° amber、範囲外の V1・VREF の数字、VR の「R」、ILS 偏位過大の amber・点滅、ILS 周波数・コース不一致の線【パネル変更要】 | FCOM p.972-993 | fltInst02.lua:875-881 |
| DSP-13 | 挙動の誤り | 低 | S | フラップ機動速度バグをレバー位置（flap_ratio）の重なった範囲で出す。フラップ 30 で 20 のバグが残る。25 の値が VREF30+5（FCOM は VREF25）【Lua のみで近似可】 | FCOM p.972, p.229 | fltInst02.lua:2882-2902; 747-400.acf:85859 |
| DSP-14 | 挙動の誤り | 中 | S | PFD の ILS 表示（`ils_dots`）が「目的地から 50 NM 以内」を条件にしている。FCOM は同調で目盛表示（現状では離陸時に同調しても LOC が出ない）【Lua のみ】 | FCOM p.987 | autopilot.lua:1635-1638, 1792-1797 |
| DSP-15 | バグ | 中 | S | パネルの参照誤り：機長 ND の TRK/HDG 表示が副の ND モード選択器、中心表示の方位ポインターが副の方位、拡大 APP の G/S が副の偏位、ILS R の周波数が nav3、ILS/VOR の識別符号フラグの取り違え、空の dataref 名の条件 182 か所、EICAS の表示条件が存在しない `display/fo/(pri_)eicas_pos`【パネル変更要】 | INTERFACES.tsv | 747-400.acf:109432, 109475, 109516, 108994, 110018-110045, 116618, 116632, 116915, 99470, 117804, 125278 |
| DSP-16 | 欠落 | 中 | M | DATA・POS が機能しない（スイッチが状態を持たず、CDU でもコメントアウト）。WPT の ETA・高度、IRU/GPS 位置、VOR radial が無い【一部パネル変更要】 | FCOM p.1040 | fltInst02.lua:1196-1210, 1357-1371; B744.fms.pages.lua:855, 890 |
| DSP-17 | 欠落 | 低 | M | STA に高・低高度の区別が無く、同調施設も STA オフでは出ない。出発・到着空港と滑走路を常時出さない。60 個で黙って打ち切り（EXCESS DATA なし）。MAP フラグは IRS 未整列のときだけ。109 では出ない TAS を出す【一部パネル変更要】 | FCOM p.1040, p.1111, p.1149 | nd.lua:254, 256-316; B747.68.xt.fms.lua:1032-1034 |
| DSP-18 | 欠落 | 中 | M | TCAS：TA/RA での TFC 自動選択（4.5）が無い。記号は白の菱形 1 種（相対高度 2,000 ft 以内を全部）。アイコン画像 `nd_icons-1.png` には RA 赤・TA amber・白の菱形と上下矢印があるのに使っていない。近接（白塗り）の絵と amber の相対高度文字は無い。TCAS OFF を TFC 未選択でも出す、TA ONLY が無い。X-Plane の地図の TCAS 表示は `EFIS_tcas_on_copilot` を使わず、どちらかの TFC で機長側の 1 本を立てる【一部パネル変更要（色分けと矢印は Lua のみ）】 | FCOM p.1032, p.1152-1154, p.1584 | fltInst02.lua:2566-2603; nd.lua:274-279, 496-509 |
| DSP-19 | 欠落 | 低 | M | TERR は外部 Terrain Radar 頼みで、この X-Plane には入っていない。カスタム acf には `*.terrain_radar_descr` も無い。地形・PWS 警報での自動表示も無い【Lua のみ（外部依存を除く）】 | FCOM p.1585 | fltInst02.lua:1212-1219; nd.lua:705-714 |
| DSP-20 | 欠落 | 中 | M | HDG REF スイッチが 3D の位置しか動かさない。TRU 表示、高緯度の自動 TRU、amber 点滅枠、HDG SEL→HDG HOLD が無い【パネル変更要（TRU 表示）】 | FCOM p.1046, p.1110 | manipulators.lua:1479-1481 |
| DSP-21 | バグ | 低 | S | 航跡線の判定に CTR の押しボタン位置（押している間だけ 1）を使い、副の判定に機長の WXR 状態を使う。ND のアイコン作り直しの 0.2 秒判定が `diff2` でなく `diff`（2 秒周期の基準）を見ており、ほぼ毎フレーム全アイコンを作り直す【Lua のみ】 | FCOM p.1143 | fltInst02.lua:2610-2630; nd.lua:748-752 |
| DSP-22 | 挙動の誤り | 低 | S | MAP で LNAV/LOC/ROLLOUT 中、選択方位の破線だけでなくバグごと消す（バグと破線が同じグループ）【パネル変更要】 | FCOM p.1142 | fltInst02.lua:3588-3625; 747-400.acf:109809 |
| DSP-23 | 欠落 | 低 | M | トレンドベクトル、S/C・E/D・減速点、待機・PT、エネルギー円、FIX 基準点が無い【パネル変更要】 | FCOM p.1147-1150 | nd.lua:466-495 |
| DSP-24 | 欠落 | 中 | L | EICAS の compact・部分表示・二次エンジン逸脱差が無い。ENG の自動表示を地上・RUN 方向でも出す（空中の CUTOFF のみのはず）。電源投入時の自動表示は flight start のときだけで、停電からの復帰では出さない【パネル変更要（自動表示の条件は Lua のみ）】 | FCOM p.843, p.872-875 | fuel.lua:568-594; fltInst02.lua:1386-1393, 3441 |
| DSP-25 | 欠落 | 中 | M | STAT ページにステータスメッセージの行が無い（Lua のページ送りだけある）。STATUS 差も無い【パネル変更要】 | FCOM p.1528, p.1545 | fltInst02.lua:1395-1411; 747-400.acf:129368 |
| DSP-26 | 欠落 | 低 | S | CAS の表示はパネルが 2 ページ分だけ。警報モジュールは最大 10 ページ作る【パネル変更要】 | FCOM p.1548-1549 | 747-400.acf:118045; warning.lua:898-902 |
| DSP-27 | 欠落 | 中 | L | 表示器と EIU の故障が無く、自動切替（PFD→inboard、PRI EICAS→lower）、EIU の AUTO 切替、「standby 電源で左 EIU 故障なら全消灯」が無い【Lua のみ（compact を除く）】 | FCOM p.1045, p.1072, p.1529 | fltInst02.lua:3236-3404 |
| DSP-28 | バグ | 中 | S | 選択器の組み合わせ 81 通りのうち 11 通りしか処理せず、他は直前の配置のまま。INBD EICAS で ND を lower へ、INBD PFD で secondary EICAS を outboard へ移すなど資料に無い入れ替えをする【Lua のみ】 | FCOM p.1045, p.1073 | fltInst02.lua:3239-3403 |
| DSP-29 | 挙動の誤り | 中 | M | 表示の電源が粗い：副表示の AC1 代替を STBY POWER 選択器に依存させ、upper EICAS を機長表示と同じ扱い、EIU は無い。APU 始動中に機長表示を消す処理は資料に記載なし（ATA-24 の ELEC-01/02 が前提）【Lua のみ】 | FCOM p.800, p.804 | electrical.lua:546-548, 624-626; fltInst02.lua:3245-3250 |
| DSP-30 | 欠落 | 低 | S | 輝度が表示器でなく内容に付く（PFD を inboard に移しても outboard のつまみ）。3D のつまみが操作する `instrument_brightness_ratio[1]`・`[4]`・`[11]`（WXR の内側つまみと推定）を使う計器が無い。周囲光の自動補正なし【一部パネル変更要（WXR）】 | FCOM p.1047-1048, p.1071 | lighting.lua:893-918 |
| DSP-31 | 挙動の誤り | 中 | S | CDU の EFIS 操作：RANGE が両席に効く、WXR は常に機長側、MODE が X-Plane の map_mode を更新しない、POS/DATA 不可、SELECT が常時出る（パネル故障の概念なし）【Lua のみ】 | FCOM p.1060-1068 | B744.fms.pages.lua:849-993, 45-90 |
| DSP-32 | 欠落 | 中 | M | 表示系メッセージの大半（3.8 の「未実装」）が無い。文言は表にあるが立てる処理が無い【Lua のみ（DSP-02 に依存）】 | FCOM p.1197-1199, p.1430 | warning.lua:109-111, 152, 165, 274-277, 371, 452-457, 477 |
| DSP-33 | バグ | 低 | S | 時計：CHR が 60 分で 59:99 に止まる（99:59 まで）。CHR 表示中は ET の開始・リセットが効かない。SET 選択器が何もしない。UTC・日付・ET の表示に電源条件が無く、年は OS の日付。表示消灯は `clock_utc_display=2` などパネルの値で可能【Lua のみ】 | ATA31 p.67-68, p.74; FCOM p.1075 | fltInst03.lua:127-149, 190-204, 216-225, 260-262, 318-346（fltInst04 も同じ） |
| DSP-34 | 挙動の誤り | 中 | M | 計器モジュールが他系統の出力を書く：stick shaker を「速度 < 表の Vs」で出し、`TOGA_pitch_deg` を書き、BAT DISCH MAIN・BATTERY OFF を立てる（ATA 27・22・24 へ移す）【Lua のみ】 | ATA27 p.701 | fltInst02.lua:3083-3123, 3197-3216 |
| DSP-35 | バグ | 低 | S | ACF_DIFF §2 の「ADF 方位針 2 個」は実は機長 ND 中心表示の VOR L/R 針。コードは VOR L/R を nav 番号 2/3 に同調するので純正の `[2]`・`[3]` が正しく、カスタムの `[3]`・`[4]` は誤り（VOR L 針が VOR R を指す）。ADF 針の `adf1/2_relative_bearing_deg[10]`（スカラーに添字）も要確認【パネル変更要（カスタム acf）】 | ACF_DIFF.md §2 | 747-400.acf:109044, 109062; 747-400_custom.acf:98755, 98773; 747-400.acf:99631 |

- 重要度の内訳：高 6、中 19、低 10（計 35）。

## 8. 作り直しか部分修正か

- **表示ロジック（fltInst02 のうち表示・選択器・速度テープ・最低高度・気圧・DSP・表示切替）は作り直しを勧める。** 理由：(1) 3,700 行に計器・選択器・V 速度表・他系統（stick shaker、TO/GA ピッチ、電池メッセージ）が混在し、席ごとの状態が対になっていない（DH・RST・BARO・CDU）。(2) ソース選択・表示器故障・EIU という骨格がそもそも無く、継ぎ足しでは DSP-02/27/28/32 を整合させにくい。(3) 選択器の配置は 4 つの位置の符号化 81 通りを手書きの表で持っており、規則で解く形に変えた方が安全。分け方の案：`efis_control`（EFIS CP・CDU 代替・席ごとの状態）、`source_select`（EIU/IRS/ADC/FD/NAV と比較監視の出力）、`display_manager`（表示器の電源・故障・選択器→`*_pos`・`display_has_power`）、`speed_tape`（限界値。SWMC 相当は ATA 27 担当と共有）、`minimums_baro`。INTERFACES.tsv の `laminar/B747/flt_inst/*`・`efis/*`・`nd/*`・`dsp/*`・`pfd/*`・`airspeed/*`・`dec_height`・`radio_alt`・`vsi/fpm`・`STAT/*` とコマンドは名前と値の意味を保つ。
- **ND の地図エンジン（xtlua_nd）は部分修正。** アイコン配置・更新周期は動いており性能も調整済み。DSP-16〜19・21・23 は機能追加で済む。
- **時計（fltInst03/04）は部分修正**（DSP-33）。2 ファイルは機長/副の複製なので 1 本にまとめるとよい。
- **FDR プラグインは現状維持**（実機 DFDR の模擬ではなく開発用ログ。乗員から見えない）。
- **パネル**：パネル変更が要るもの（DSP-01・03・04・10・12・15・20・22〜26・35。一部が要るのは 02・11・16〜18・30）は、カスタム acf への変更案として一覧にまとめ、利用者の承認を得てから行う。優先は DSP-01（方位）と DSP-03（基準受信機）。Lua だけで直るもの（DSP-05・06・07・09・14・27・28・31〜33 など）は先に進められる。

## 9. 未確認事項

1. パネルの SHOW 条件が複数あるときに AND か OR か、境界を含むか（`GROUP <= DH`、747-400.acf:86915 の RA amber が出るか）。
2. `adf1_relative_bearing_deg[10]` のようなスカラーへの添字を X-Plane がどう扱うか（ADF 針が動くか）。
3. X-Plane の EFIS map（`EFIS_map_t_HM` 等）が MAP で track up になっているか、プラグインの文字アイコンと向きが合うか。TCAS 記号を X-Plane 側でも描いて二重になっていないか。
4. X-Plane の pilot/copilot 計器の故障（`sim/operation/failures/*`）を、どの範囲で実機の ADC/IRU/RA の故障の代わりに使うか（パネルは X-Plane の席別の値を直接読むので、故障はそのまま表示に出る）。
5. `radio_altimeter_height_ft_pilot` が 2,500 ft を超えても値を返すか（T/D アイコンが RA>5,000 ft を条件にしている。nd.lua:470）。
6. 故障の無いときに INBD EICAS・INBD PFD を選ぶと、空いた表示器（lower・outboard）に何が出るか（資料に記載なし）。
7. DH の点滅時間と、109 で RA の数字が DH 以下で色を変えるか（資料に記載なし）。
8. 副操縦士側の NAV 選択器の位置番号と 3D の目盛の対応（パネルは副で 2=ILS L、3=ILS R、0/1=VOR を混用）。
9. 速度テープの 1.3 g 境界、shaker 速度、Vmo/Mmo の数値の出所（FCOM・ATA に表が無い。PI の失速速度表から作るか）。
10. 最小機動速度帯と最小速度帯を離陸滑走中・浮揚直後にどう出すか（「最初のフラップ上げで表示」は最小機動速度だけの記述）。
11. Terrain Radar プラグインを使う前提を残すか（カスタム acf 用の descriptor を作るか）。
12. APU 始動中に機長表示を消す処理（fltInst02.lua:3247-3250）が実機の挙動か。

## 10. 5-2 の段取りと段 1 の計画（2026-10-25）

- 5-2 は段に分ける（§8 の作り直しの分け方に沿う）：
  - 段 1：表示器と EIU（DSP-27・28・29・30）。表示器 6 台の電源と故障、INBD・LWR の選択器と自動切替、EIU 3 台の電源・故障・選択（各席の ISS と中央の EIU SEL）、内容ごとの輝度。
  - 段 2：ソース選択の残りと比較（DSP-02・14・32）。FLT DIR・NAV・EIU（ILS 受信機）、SOURCE SEL・SNGL SOURCE、ATTITUDE・HEADING・TRACK。
  - 段 3：速度テープ（DSP-05〜08・13・34）。
  - 段 4：気圧と PFD の記号・旗・方位（DSP-01・04・11・12。承認済みのパネル）。
  - 段 5：ND（DSP-03・15・16・17・20・21 の残り・22・23・31・35）。
  - 段 6：EICAS の形式（DSP-24・25・26）と時計（DSP-33）。
- 段 1 の作り方：新しいモデル `B747.60.display_model.lua` とグルー `B747.60.xt.displays.lua`（計器のモジュール `B747.60.xt.fltInst`）。前の `fltInstsetCRTs()`（選択器の 81 通りのうち 11 通りの手書きの表、資料に無い入れ替え）を置き換える。パネルとの約束（内容ごとの位置 `flt_inst/display/*_pos` と電源 `electrical/display_has_power[0..5]`）は変えない。
  - 表示器：機長の outboard・inboard は APU standby bus、upper は main standby bus、副操縦士の 2 台と lower は F/O transfer bus（FCOM p.800、p.804。いまの電源の割り当てのまま）。故障は新設 `displays/fail[6]`。
  - 選択器（FCOM p.1045）：INBD の EICAS は inboard に secondary EICAS（primary をほかに出せないときは primary）、NORM は ND（outboard が使えなければ PFD）、PFD は inboard に PFD。LWR の EICAS PRI は lower に primary、NORM は DSP の選択（upper が使えなければ primary）、ND はその席の ND。upper が使えなければ primary は lower へ（LWR が NORM のとき。FCOM p.1072）。
  - パネルは同じ内容を 2 か所に出せない。資料に無い組み合わせ（故障の無いときの INBD PFD・EICAS、LWR EICAS PRI・ND で空いた表示器、両席の選択器のぶつかり）は、選んだ表示器に内容を出し、空いた表示器は消す（推定）。両席の LWR がぶつかるときは EICAS PRI、機長の ND、副操縦士の ND の順（推定）。
  - EIU（FCOM p.1044、p.1529）：L は main standby bus、C は captain transfer bus、R は F/O transfer bus（FCOM p.800、p.804）、故障は新設 `eiu/fail[3]`。各席の ISS の EIU（AUTO は機長 L→C→R、副操縦士 R→C→L）が使えなければ、その席の PFD・ND は消える。EICAS は中央の EIU SEL（AUTO は L→C→R）。手で選んだ EIU が壊れても自動で切り替えない。standby の電源（AC が無い）で L の EIU が壊れると全部の表示器が消える。>EIU LEFT（L の故障。空中は出さない：FCOM p.1199）。
  - 輝度：内容の輝度を、出している表示器のつまみで（いまは内容に付いたつまみ：DSP-30）。照明のモジュールが、新設の `displays/content_unit[6]` を読む。

## 11. 実装（5-2 段 1、2026-10-25：表示器と EIU）

- 計器のモジュール（`B747.60.xt.fltInst`）に、表示器と EIU のモデル `B747.60.display_model.lua` とグルー `B747.60.xt.displays.lua` を足した（試験 `tests/displays/display_model_test.lua`・`display_module_test.lua`、X-Plane の `s46_displays`）。§10 の計画のとおり。前の `fltInstsetCRTs()`（81 通りのうち 11 通りの表と資料に無い入れ替え：DSP-28）は外した。
- 選択器の向き：機長の INBD は 0 EICAS・1 NORM・2 PFD、LWR は 0 EICAS PRI・1 NORM・2 ND。副操縦士のつまみは逆向き（INBD 0 PFD・2 EICAS、LWR 0 ND・2 EICAS PRI）。EIU の選択器は機長と中央が 0 L・1 AUTO・2 C・3 R、副操縦士が 0 L・1 C・2 AUTO・3 R（3D の回転から）。
- 内容の位置（パネルとの約束のまま）：機長の PFD は outboard 0・inboard 1、ND は inboard 0・lower 1、primary EICAS は upper 0・lower 1・機長の inboard 2・副操縦士の inboard 3、secondary EICAS は lower 0・副操縦士の inboard 1・機長の inboard 2（outboard・upper の値もある）。出ない内容は `display_has_power` を 0 に。
- 表示器の故障（新設 `displays/fail[6]`：機長 outboard・機長 inboard・upper・lower・副操縦士 inboard・副操縦士 outboard）で自動切替：outboard が使えなければ INBD NORM で PFD が inboard へ、upper が使えなければ LWR NORM で primary EICAS が lower へ（FCOM p.1045、p.1072）。INBD EICAS は、primary をほかに出せないとき primary、ほかは secondary（FCOM p.1045、p.1073 の図と同じ）。
- EIU（新設 `eiu/fail[3]`、使っている EIU は新設 `eiu/used[3]`：機長・副操縦士・EICAS、1 L・2 C・3 R・0 なし）：電源は L が main standby bus、C が captain transfer bus、R が F/O transfer bus。AUTO は機長 L→C→R、副操縦士 R→C→L、EICAS L→C→R。手で選んだ EIU が使えなければ、その席の PFD・ND（EICAS なら両 EICAS）は消える。AC が無い（standby の電源）で L が使えなければ全部が消える。>EIU LEFT（advisory 91。地上だけ）。
- 輝度：照明のモジュールが新設 `displays/content_unit[6]`（内容ごとの表示器）を読み、内容の rheostat に、出している表示器のつまみの値を使う（DSP-30。機長 outboard のつまみは 2、inboard は 0、upper 9、lower 10、副操縦士 inboard 3、outboard 5）。
- X-Plane での確認（カスタム acf）：`s46_displays` 26/26。通常の配置、機長の outboard と upper の故障で PFD が inboard・primary EICAS が lower（写真）、機長の INBD EICAS で inboard に secondary EICAS（写真）、副操縦士の LWR ND で lower に副操縦士の ND（写真）、副操縦士の INBD PFD、L の EIU の故障で AUTO は C（空中で >EIU LEFT なし）、機長の EIU を L にすると機長の PFD・ND が消え（写真）、戻すと戻る。Log.txt に Lua とパネルの誤りなし。

## 12. 実装（5-2 段 2、2026-10-25：ソース選択の比較）

- 表示器と EIU のモデル・グルーに、両席のソース選択の比較を足した：>SOURCE SEL EIU（両席が同じ EIU を使う）、>SOURCE SEL F/D（同じ FCC）、>SOURCE SEL NAV（同じ FMC。CDU の位置は FMC ではないので出さない）（FCOM p.1197）。選択器の向き（FCOM p.1043 の図と 3D の回転）：FLT DIR は両席とも 0 L・1 C・2 R、NAV は機長 0 FMC L・1 FMC R・2 CDU L・3 CDU C、副操縦士は逆向きで 0 CDU C・1 CDU R・2 FMC L・3 FMC R。
- EFIS 操作パネルと表示選択パネル：新設の故障 `efis/fail[2]`（L・R）・`dsp/fail`。電源は L が main standby bus、R が F/O transfer bus（FCOM p.800、p.804）。>EFIS CONTROL L・R（そのパネルが働かない）、>EFIS/EICAS C/P（両パネルと表示選択パネルが働かない。このときは L・R の代わりに：推定）（FCOM p.1198–1199）。パネルが働かないときに操作が効かなくなることと CDU の代替（DSP-31）は段 5 で。
- 航法センサーのモジュール：>ATTITUDE（caution、beeper：選んだ IRU の姿勢の差 3° 以上）と >HEADING（表示の方位の差 4° 以上）を IRS のグルーに（FCOM p.1197–1198）。PFD は X-Plane の機長側・副操縦士側の AHRS を表示するので、その差を見る（両席が同じ IRU なら姿勢は比べない：推定）。>SNGL SOURCE RA（両 PFD が同じ電波高度計）を電波高度計のグルーに（FCOM p.1197）。
- 後に回したもの：>TRACK（席ごとの航跡の源が無い）、>SNGL SOURCE ILS と PFD の ILS の目盛の出し方（DSP-14。どちらも ILS 受信機と自動同調に絡むので、無線の同調（5-1 段 3、FMC と一緒）で）。FLT DIR・NAV の選択で FD の指示や地図の源が変わること（FCC・FMC が 1 つずつしか無い。AFDS・FMC の作り直しで）。
- X-Plane での確認（カスタム acf）：`s47_sources` 21/21。両席が FCC L で >SOURCE SEL F/D、FMC R で >SOURCE SEL NAV、EIU L で >SOURCE SEL EIU（このとき副操縦士の電波高度計の順も L からになり >SNGL SOURCE RA も出た）、電波高度計 R・C の故障で >SNGL SOURCE RA、左 EFIS 操作パネルの故障で >EFIS CONTROL L、両パネルと表示選択パネルで >EFIS/EICAS C/P だけ、X-Plane の副操縦士側の姿勢計と方位の故障と右旋回で >ATTITUDE（機長のバンク 16.9°、副操縦士 0°）と >HEADING、故障を戻すと消える。EICAS の行を記録した。Log.txt に Lua の誤りなし。

## 13. 段 3 の計画と段 3a の実装（2026-10-25 夕方：速度テープ）

- 速度テープの要素（FCOM p.969–973）：最大速度（Vmo/Mmo・脚の placard・フラップの placard の最小）、最大機動速度（琥珀の帯の下端：高速バフェットまで 1.3 g。高高度・高重量でだけ）、最小機動速度（琥珀の帯の上端：フラップ下げはシェーカーまで 1.3 g、フラップ上げは 20,200 ft 未満でシェーカーまで 1.3 g か VREF+80 の小さい方、20,200 ft 以上で低速バフェットまで 1.3 g。離陸後の最初のフラップ上げから出す）、最小速度（シェーカーか低速バフェット）、フラップの機動速度のバグ（今のフラップと次の小さいフラップ。約 20,000 ft より上は出さない）。
- 段 3a（資料から決まるもの：この節で済）と段 3b（数値が資料に無いもの）に分ける。
- 段 3a：新しいモデル `B747.60.speedtape_model.lua` とグルー `B747.60.xt.speedtape.lua`（計器のモジュール `B747.60.xt.fltInst`、fltInst02 の後に dofile）。
  - フラップの機動速度（FCOM PI.10.3）：UP VREF30+80、1 +60、5 +40、10 +20、20 +10、25 VREF25、30 VREF30。VREF25 は FCOM PI.10.2 の表（重量ごと、4,000 ft ごとに 1 kt 増し）。前は 25 が VREF30+5（DSP-13）。CDU の APPROACH REF の 25/xxx も同じ値（`Vf25` を読む）で、FCOM の VREF25 になった。VREF30 は前の表のまま（海面で FCOM PI.10.2 と合う）。
  - バグ：今のフラップのレバーの位置と次の小さい位置の 2 つ（FCOM p.972）。CDU で選んだ着陸フラップのバグは出さない（REF のバグがその速度：純正のパネルの決まりのまま）。新設 `airspeed/show_vf[7]`（[0] UP〜[6] 30）。前はレバーの位置の重なった範囲で出していて、フラップ 30 で 20 のバグが残った（DSP-13）。`showVf25`・`showVf30` は同じ値を書き続ける。
  - 最小機動速度の帯（`pfd/show_mins`）：離陸後の最初のフラップ上げ（空中でレバーが地上の位置より小さくなる）から、接地まで（FCOM p.973）。空中で始めたフライトは出す（推定）。前は推力基準が TO 以外で RA 10 ft 超。最小速度の帯も同じ条件（純正のパネルが同じグループ）。
  - 最小速度の表の高度帯の誤り（DSP-07）：0 ft 以上がすべて 0〜2,000 ft の帯だった。高い帯から順に見る。
  - パネル（道具 `docs/overhaul/tools/panel_flap_bugs.lua`。ACF_DIFF.md §5）：4 つの PFD の 7 本のバグの表示条件を `show_vf[k]` の 1 つに。
- 段 3b（数値が資料に無い。推定が要る）：最小速度（シェーカー速度）、最小・最大機動速度、失速警報（WARN-18：いまは表の Vs より遅いと出す。ATA27 p.701 の SWMC は、フラップの位置から決めた alpha max を Mach・速度・前脚・スピードブレーキで補正し、AOA が超えるとシェーカー。Vss を速度テープへ）、DSP-34（fltInst02 が TO/GA のピッチを書くこと）、DSP-08（表の誤記）。資料にあるのは FCOM の定義と、PI の「LRC の最大運用高度」の表（重量ごとに、初期バフェットまで 1.2〜1.5 g の余裕の高度：PI.11.1 など）だけ。acf の失速警報は AOA 15° で固定（`_stall_warn_aoa`、`_stall_warn_is_variable 0`）。
- 試験：モデル 23 件、モジュール 11 件。X-Plane の新しいシナリオ `s51_speed_tape`（15/15、注意 1：X-Plane 12 でフラップの実際の位置の `flaprat` が動かず、待ちだけ）：空中開始で最小機動速度の帯、フラップ UP で UP、1 で 1 と UP、5 で 5 と 1、20 で 20 と 10、30 で 30 と 25（20 は消える）、VREF25 > VREF30。PFD を撮った。外から見た写真で機体の見た目が変わらないことを確かめた。

## 14. 段 3b の実装（2026-10-25 夜：最小速度・機動速度・シェーカー・AIRSPEED LOW）

- 資料：
  - FCOM の定義：最小速度（赤と黒の帯の上端）は「シェーカーか低速バフェットが起きる速度」、最小機動速度（琥珀の帯の上端）はフラップ下げでシェーカーまで 1.3 g、フラップ上げで 20,200 ft 未満はシェーカーまで 1.3 g と VREF+80 の小さい方、以上は低速バフェットまで 1.3 g（FCOM p.973）。最大機動速度（琥珀の帯の下端）は高速バフェットまで 1.3 g で、高高度・高重量でだけ出る（FCOM p.969）。AIRSPEED LOW と PFD の速度の琥珀の枠は最小機動速度未満（FCOM p.1556、p.1605）。フラップのバグは約 20,000 ft より上では出さない（FCOM p.972）。
  - 出どころ：シェーカー速度（Vss）は SWMC が出す（ATA27 p.702）。シェーカーは、フラップの位置から決めた迎角の上限（Mach・速度・前脚・スピードブレーキで補正）と、ピッチ率・速度で補正した迎角を比べて動く（ATA27 p.701）。最小機動速度と高速バフェット速度は FMC が出す（ATA34_2 p.501）。
  - 数値：FCTM p.261–262 のシェーカーと失速速度の図（10,000 ft、UP・10・20・30。画素で読んだ値は notes/FCTM.md §1.14）と、FCOM PI.11.1 の LRC の最大運用高度の表（重量ごとに初期バフェットまで 1.20〜1.50 g の高度。PI.11.2 の LRC の Mach と合わせると、どの重量・g でも n W /(δ M²) = 2.608e6 kg ± 1 % at M 0.86）。
- モデル `plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.minspeed_model.lua`（新設）：
  - 揚力の上限を B(M) = n W /(δ M²)（kg。翼面積は要らない）で持つ。各フラップ位置の B を、図のシェーカー速度（10,000 ft の 11 重量）を Mach に直して直線で当てはめる（図の速度は 0.6 kt 以内、30 は 1 kt 以内で戻る）。フラップ上げは、図の最高の Mach（約 0.44）から M 0.86 のバフェット（2.608e6）へ直線、その先は M 0.92 で 0.8 倍まで下がる二次の線（高速バフェット：推定）。図の範囲外（重量・高度）は直線の延長（推定）。
  - フラップ 25：VREF25（FCOM PI.10.2）÷1.23（VREF30 ÷1.23 は図のフラップ 30 の失速速度と 1 kt 以内）に 10,000 ft の分を足し、20 と 30 のシェーカー／失速の比の平均を掛ける（推定）。フラップ 1・5：UP と 10 のシェーカー速度の間の 0.63・0.87（前の失速速度の表の位置。推定）。フラップの位置の間は後縁の角度で比例（推定）。
  - 最小速度：今の荷重倍数（約 3 秒でならす）で M² B(M) = n W / δ になる Mach の CAS。最小機動速度：1.3 g で同じ。フラップ上げ・20,200 ft 未満は VREF30+80 で頭打ち。最大機動速度：フラップ上げで、M² B(M) の山（M 0.88）より上で 1.3 g に下がる Mach。最大速度より上なら出さない（`Vmaxm` に最大速度を書き、帯の長さが 0）。1.3 g の上限高度より上では二つの帯が山の Mach で重なる。
  - シェーカー：空中で、今の Mach で必要な揚力（荷重倍数は約 0.2 秒でならす）が B(M) を超えたら。2 % のヒステリシス（推定）。高い Mach ではバフェットの線で動く（実機は迎角の上限：推定）。
  - AIRSPEED LOW と琥珀の枠：空中・最小機動速度の帯が出ている（離陸後の最初のフラップ上げから）・RA 100 ft 超で、CAS が最小機動速度未満（帯と RA の条件は推定。帯が出る前、たとえば V2 での離陸上昇では出さない）。
  - 入力：重量、気圧高度（`sim/flightmodel2/position/pressure_altitude`）、機長のエアデータの Mach（`laminar/B747/airdata/mach_capt`）と速度、荷重倍数（`sim/flightmodel/forces/g_nrml`）、後縁フラップの角度、VREF30、最大速度、RA、PSEU の空中、最小機動速度の帯。スピードブレーキの分（ATA27 p.698 の Vmin の計算）は資料に値が無く入れていない。
- グルー：`B747.60.xt.speedtape.lua` に入れた（段 3a のモデルと一緒）。書くもの：`airspeed/Vs`（赤と黒の帯の上端：前は失速速度）、新設 `airspeed/Vminm`（最小機動速度）、`airspeed/Vmaxm`、`sim/flightmodel/failures/stallwarning`（シェーカー）、AIRSPEED LOW（`CAS/caution_status[0]`）、`airspeed_window/min`、新設 `airspeed/tape_capt[4]`・`tape_fo[4]`（帯 4 本の速度からその席の速度を引いた値：[0] 最小速度、[1] 最小機動速度、[2] 最大機動速度、[3] 最大速度）。
  - `airspeed/Vmc` は前の式（重量とフラップの一次式）のまま残す。AFDS・A/T・VNAV・EEC・FMS の速度の下限（`Vmc + 10` とフラップごとの補正）がこの値に合わせてあるので（6-3・6-4 で作り直す）。
  - パネル（道具 `docs/overhaul/tools/panel_speed_bands.lua`、ACF_DIFF.md §5）：純正の速度テープの帯は、速度で上下する 2 つのグループ（最大の側は 320 kt、最小の側は 160 kt が真ん中）にあり、切り抜きの窓もグループと一緒に動くので、その近くの速度でしか見えなかった（巡航の約 250 kt の最小機動速度は出ない）。グループを止め、帯 4 本は `tape_capt`・`tape_fo` を 4 px/kt で読む（琥珀の帯は前の `Vmc` から最小機動速度に）。
  - fltInst02：`B747_Vs` は X-Plane の TO/GA のピッチ（AFDS）のためだけに失速速度の表を引く（帯・シェーカー・`vSAOA` の帯の持ち上げは外した）。前の AIRSPEED LOW（前の `Vmc` か失速速度より遅い）と琥珀の枠（前の `Vmc` より遅い：地上でも）は外した。最大機動速度（最大速度 −10 kt）も外した。
  - 重量の補間（`bracket_weights`）：VREF30 と失速速度の表で、重量をはさむ 2 つの重量の間で比例（前は 20 t 単位に丸めた重量を上端にしたので、区間の前半は下の重量の値のままだった）。
  - 前の失速速度の表の誤記 2 か所（DSP-08）：フラップ 20 の 10,000 ft・200 t（133.60 → 113.60）、0 ft・360 t（156.66 → 153.66）。
- 段 3a のモデル：フラップのバグを約 20,000 ft（指示高度）より上で出さない（FCOM p.972）。
- 段 3a のモデル：最小機動速度の帯の判定で地上とみなすのは、PSEU の地上かつ 100 kt 未満が 5 秒続いたときだけ（どちらの値も推定）。空中開始や空中での機体の読み直しの直後に、空地判定が一瞬地上になり（読み直しでは X-Plane の指示対気速度も 0 から立ち上がる）、帯（とそれに付く AIRSPEED LOW）が出ないままになったため（X-Plane の試験で見つけた。着陸では 100 kt を切ってから 5 秒で消える）。
- 試験：モデル 43 件（最小速度）・32 件（段 3a の速度テープ）、モジュール 31 件。X-Plane の新しいシナリオ `s52_min_speeds`（10,000 ft・フラップ 20：帯の上端が FCTM のシェーカー速度、琥珀の帯がシェーカーまで 1.3 g、最大機動速度は出さない、アイドルで減速して最小機動速度を切ると AIRSPEED LOW と琥珀の枠、帯の上端を切るとシェーカー）と `s53_min_speeds_cruise`（35,000 ft・280 kt：琥珀の帯が低速バフェットまで 1.3 g で約 249 kt、最小速度が約 211 kt、最大機動速度は出さない、バグを出さない）。PFD を撮って帯の位置を確かめた。帯の上端は荷重倍数で動く（この A/P は高度を保つ間に 0.9〜1.1 g 揺れる）。

## 15. 段 4 の計画（2026-10-25 深夜：気圧と PFD の記号・旗・方位）

- 段 4 は量が多いので 5 つに分ける（どれもパネルの変更を含む。パネルは全範囲で承認なしでよい：2026-10-25）。
  - 4a：姿勢・方位・昇降率の源と旗（DSP-01、DSP-04 の IRS の分）。
  - 4b：気圧（DSP-11 の残り）：遷移高度・遷移レベルの琥珀の枠、CDU の EFIS CONTROL ページの BARO を自分の側だけに。
  - 4c：速度テープの記号と旗（DSP-04・12 の速度の分）：VR の「R」、範囲外の V1・VREF の数字、離陸で V1・VR を消す、MACH・SPD LIM の旗。
  - 4d：姿勢の記号（DSP-12）：PLI、バンク 35° 以上の琥珀、横滑りの琥珀、FPV（スイッチのラッチと記号）、PITCH・ROLL の旗。
  - 4e：ILS（DSP-12・04 の ILS の分）：偏位過大の琥珀と点滅、ロール 53° 超での消去、G/S・LOC の旗。
- 資料（どれも段 4 で読んだもの）：
  - 旗：FCOM p.999 (10.10.37)、ATA31 p.15–17（NCD/invalid の表。invalid は消して琥珀の旗、NCD は旗なしで消す）。ATT は姿勢が invalid、HDG は IRU の方位が invalid、VERT は慣性の昇降率が invalid（NCD か ADC の故障は旗なしで消す）、MACH は ADC の Mach が invalid（NCD か CAS invalid は旗なしで消す）、SPD LIM は SWC の Vmax と ADC の最大運用速度がともに invalid（最大速度の帯）か SWC の Vmin が invalid（シェーカー速度の帯）、NO V SPD は FMC の V1・VR が invalid。
  - 方位：FCOM p.997 (10.10.35)（方位ポインターは IRS の方位、航跡は FMC、FMC が無効なら選んだ IRU）、p.998（MAG・TRU。TRU は枠）、p.1046 (10.10.84)（HDG REF：NORM は磁方位、高緯度では真方位。TRUE は真方位。PFD・ND・AFDS・FMC に効く）、p.1228（PFD と ND の方位は NAV の IRU から。NAV の源に動いている FMC を選んでいれば IRS 選択器によらない）。
  - 昇降率：FCOM p.996 (10.10.34)（ADC の昇降率を IRS でならしたもの）。
  - 気圧：FCOM p.995 (10.10.33)（気圧設定で MCP 高度が遷移高度より上のとき遷移高度を 300 ft 上回る、または STD で MCP 高度が遷移レベルより下のとき遷移レベルを 300 ft 下回ると、枠で琥珀）、p.1037（BARO STD）、p.1062–1064（CDU の EFIS CONTROL：BARO SET の入力 22.00〜32.00・2200〜3200 は inHg、745〜1084 は hPa、I・H で単位、S・STD で STD）、p.1329・p.1396（TRANS ALT は航法データベース、無ければ 18,000 ft。TRANS LVL は到着の手順、無ければ FL180）。
  - 速度テープ：FCOM p.972–973（109：VR が V1 から 4 kt 以内なら R、範囲外の V1 は上に、VREF は下に数字、V1・VR は離陸で消える）。
  - 姿勢：FCOM p.975 (10.10.13)（バンク 35° 以上でバンクポインターが琥珀、横滑りの枠も琥珀。PLI はシェーカーの点、109 はフラップが上がっていないとき。PITCH・ROLL は両席の差）、ATA27 p.701（PLI は SWMC のピッチの余裕から：EIU 経由）。
  - ILS：ATA34_1 p.466–468（偏位過大：G/S は APP が動いていて RA 100〜500 ft で約 5/8 ドット超、LOC は RA 0〜500 ft で約 1/4 ドット超が 1 秒以上。LNAV で LOC を arm して RA 950 ft 以下で捕まえていなければ LOC の捕捉失敗、1,050 ft か捕捉で戻る。目盛は黄色、ポインターは 4 Hz で点滅。ロール 53° 超・周波数 NCD で目盛ごと消す）、FCOM p.986–987。
- 4a の作り方：
  - 新しいモデル `B747.60.pfd_model.lua`。表示器と EIU のグルー（`B747.60.xt.displays.lua`、NAV の源の選択器をすでに読んでいる）で回す。IRS の配列（`irs/att_valid`・`hdg_valid`・`nav_valid`）、IRS と NAV の選択器、各席のエアデータの有効を読み、席ごとに新しい dataref を書く：`pfd/<席>/att`（姿勢）、`hdg`（方位の目盛とバグ）、`trk`（航跡）、`vsi`（昇降率）、`vert`（VERT の旗）。
  - 値は今までどおり X-Plane の pilot・copilot の AHRS（機長と副操縦士の選んだ IRU の代わり。>ATTITUDE・>HEADING の比べ方と同じ：5-1 段 2）。モデルは見せるかどうかだけを決める。
  - 方位の源：NAV の源が FMC で NAV の IRU があれば、その IRU（機長は L・C・R、副操縦士は R・C・L の順：推定）。そうでなければ IRS 選択器の IRU（ATT で SET HDG を入れたものを含む）。航跡は FMC の IRU か、選んだ IRU が NAV のとき。
  - 昇降率：選んだ IRU が NAV（慣性の昇降率：ATT では出ない。推定）。慣性が無効なら VERT の旗、エアデータが無効なら旗なしで消す。
  - パネル（道具 `docs/overhaul/tools/panel_pfd_sources.lua`）：方位目盛（`Compass Rose`・`GROUP Rose Offset`）を `nd/up` からその席の AHRS の方位へ（DSP-01）。姿勢・方位・昇降率の表示条件を、それぞれの新しい dataref へ。ATT・HDG・VERT の旗と、姿勢が消えたときの固定の飛行機の記号を別々に。航跡の印は `trk` で。前は IRS の有効で消えていた DH・MDA・RA の数字と AFDS の状態表示は、その行を外して元の条件に戻す（計器は最後の条件しか見ない）。グライドスロープの目盛は段 4e、ND は段 5。`pfd/capt/irs`・`fo/irs` は FMS・ND が読むので IRS のグルーが書き続ける。
  - HDG REF の TRUE と高緯度の真方位は、ND（段 5）と AFDS（6-3）と一緒に。4a の PFD は磁方位で、MAG の表示のまま。

## 16. 段 4a の実装（2026-10-25 深夜：PFD の姿勢・方位・昇降率の源と旗）

- モデル `plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.pfd_model.lua`（新設）：席ごとに、姿勢（選んだ IRU の姿勢の有効）、方位（NAV の源が FMC なら NAV の IRU を機長は L・C・R、副操縦士は R・C・L の順で。無ければ IRS 選択器の IRU の方位の有効：ATT で SET HDG を入れたものを含む）、航跡（方位の IRU か選んだ IRU が NAV）、昇降率（選んだ IRU が NAV で、エアデータが有効）、VERT の旗（選んだ IRU が NAV でない）を決める。FMC の IRU の順と、ATT に慣性の昇降率が無いことは推定。
- グルー：表示器と EIU のグルー `B747.60.xt.displays.lua` の終わりで回す（NAV の源は表示器のモデルの入力と同じ）。読むもの：`irs/att_valid`・`hdg_valid`・`nav_valid`、`flt_inst/irs_src/capt|fo/sel_dial_pos`、`airdata/valid_capt`・`valid_fo`。書くもの：新設 `pfd/capt/att`・`hdg`・`trk`・`vsi`・`vert`（`fo` も。init スクリプトで作る）。
- 値は今までどおり X-Plane の pilot・copilot の AHRS（姿勢・方位・昇降率）。5-1 段 2 の >ATTITUDE・>HEADING と同じく、各席の選んだ IRU の代わりとみなす。IRS 選択器を変えても値の出どころは変わらず、有効かどうかだけが変わる。
- パネル（道具 `docs/overhaul/tools/panel_pfd_sources.lua`、ACF_DIFF.md §5）：
  - 方位目盛（`Compass Rose`・`GROUP Rose Offset`）の参照を `nd/up/<席>` から `heading_AHARS_deg_mag_pilot`・`_copilot` へ（DSP-01：前は MAP で航跡、PLN で真北が上になった）。航跡の印と選択方位のバグは `Rose Offset` の中なので一緒に直る。
  - 姿勢の 6〜7 項目は `att`、方位の目盛とバグは `hdg`、昇降率は `vsi`、VERT の旗は `vert`、航跡の印は `trk`（前は条件なし）。
  - `GROUP CAPT IRS OFF PFD`・`FO IRS OFF PFD` の条件を外し、中の固定の飛行機の記号と ATT の旗は `att` が 0、HDG の旗は `hdg` が 0 で出す（前は 3 つが一緒）。
  - IRS の有効が 2 行目の条件として付いていた DH・MDA・RA の数字と AFDS の状態表示は、その行を外した（計器は最後の条件しか見ないので、DH の点滅の条件などが効いていなかった）。グライドスロープの目盛（段 4e）と ND（段 5）の `pfd/<席>/irs` は残す。
- 試験：モデル 17 件（`tests/displays/pfd_model_test.lua`）、表示器のモジュールに 17 件（50 から 67 件）（`display_module_test.lua`）。X-Plane の新しいシナリオ `s54_pfd_sources`（24/24）：ND を PLN にしても PFD の方位目盛は機首方位のまま、IRS 選択器 C、IRU L の ATT（ATT と VERT の旗、方位は FMC L が IRU C から）、NAV の源を CDU L（HDG の旗）、ADC 1 の故障（昇降率が旗なしで消える）。PFD を撮って旗と消える項目を確かめた（姿勢が無効でもバンクの目盛は残る：ATA31 p.15 の消す項目に無い）。

## 17. 段 4b の実装（2026-10-25 深夜：気圧設定の琥珀の枠、CDU の BARO SET）

- 判定（`B747.60.pfd_model.lua` の `baro_alert`、FCOM p.995 (10.10.33)）：気圧設定（STD でない）で MCP 高度が遷移高度より上、機体が遷移高度より 300 ft 上なら、気圧設定が枠で琥珀。STD で MCP 高度が遷移高度より下、機体が遷移レベルより 300 ft 下なら、STD が枠で琥珀。FCOM の文は STD の側も「MCP altitude below transition altitude」と遷移高度で比べるので、そのとおりにした。機体の高度はその席の気圧高度（`airdata/alt_capt`・`alt_fo`：その席の気圧設定）。
- 遷移高度は FMC の CLB ページの TRANS ALT（`fms/data` の `transalt`、既定 18,000 ft：FCOM p.1329）を 2 秒ごとに読む。遷移レベル（FCOM p.1396：DESCENT FORECAST ページ、既定 FL180）は今の FMS に無いので既定の FL180（FMC の作り直しで）。
- グルー：表示器と EIU のグルーの `pfd_baro()`。書くもの：新設 `pfd/capt/baro_alert`・`fo/baro_alert`。
- パネル（道具 `docs/overhaul/tools/panel_pfd_baro.lua`、画像 `make_pfd_baro_images.ps1`、ACF_DIFF.md §5）：各 PFD の `GROUP Baro` の STD と気圧設定を `GROUP Baro Normal`（`baro_alert` が 0）に入れ、琥珀の同じもの（純正の琥珀の数字のフォント、色を塗り替えた STD と IN./HPA）と 2 ピクセルの枠を `GROUP Baro Alert`（1）に足した。枠の位置と大きさはスクリーンショットで測った（数字と IN. はパネル座標で x 512〜602・y 493〜510、STD は x 535〜569・y 496〜514。各組では STD の位置と数字の位置からの相対で置く）。preselect（白）はそのまま。
- CDU の EFIS CONTROL ページ（FCOM p.1062–1064）の BARO SET：前は入力が両席に効き、数字はつまみの単位のまま受けていた。新しい `B744.fms.baro.lua` で入力を解き（S・STD、I・H で単位、22.00〜32.00 と 2200〜3200 は inHg、745〜1084 は hPa、ほかは INVALID ENTRY）、その CDU の側（右の CDU は副操縦士、ほかは機長：ページのほかの項目と同じ）だけに書く。数字の入力は単位もそれに合わせ、STD を外す。STD は EFIS 操作パネルの STD のコマンドで（STD の前の値を覚える：NAV-06）。RANGE INCR・DECR が両席に効くことなど、ページのほかの項目は CDU の作り直し（6-2）か ND（段 5）で。
- 試験：モデル 11 件（`pfd_model_test.lua` で計 28）、表示器のモジュール 5 件（計 72）、CDU の入力 18 件（`tests/displays/cdu_baro_entry_test.lua`）。X-Plane の新しいシナリオ `s55_pfd_baro`。

## 18. 段 4c の実装（2026-10-26 未明：PLI と VR の R）

- 段の分け直し：4c は PLI と VR の R にした。§15 で 4c に入れていたもののうち、V1・VR を離陸で消すことは前から（RA 10 ft 未満で出す）、NO V SPD も前からある。範囲外の V1・VREF を数字で出すこと（FCOM p.972–973）は形の図が FCOM に無いので作らない。MACH・SPD LIM・SEL SPD の旗は源の故障が今は無い（エアデータは Mach と CAS が一緒に有効・無効、SWC と FCC の故障は作っていない）ので後で。バンク 35° 以上の琥珀と横滑りの印の色（FCOM p.975）は LCD の PFD だけで、既定は CRT（`pfd/style` 0：p.977 には無い）なので後で。4d は FPV と PITCH・ROLL の旗、4e は ILS。
- PLI（FCOM p.975・p.977：シェーカーが働く点、109 はフラップが上がっていないとき。ATA27 p.701：SWMC のピッチ制限のパラメーター）：最小速度のモデル（§14）に足した。揚力の上限 B(M) をカスタム acf の揚力の傾き（失速試験の記録のうち失速の切れ目より前、約 270 t：フラップ UP・10・20・30 の揚力ゼロの迎角 −4.8・−8.3・−12.5・−14.0°、B 1 kg あたりの迎角 4.41・3.92・3.82・3.88e-6°）で迎角に直す。空中は余裕 = 揚力ゼロからシェーカーまでの迎角 ×（1 − 必要な揚力 / 上限）で、シェーカーのときにちょうど 0（荷重倍数は速度テープと同じ 3 秒のならし）。地上は上限の迎角 − 今の迎角。60 kt より上、飛行機の記号から 30° 以内で出す。色は琥珀（FCOM の図は灰色：推定）。どれも推定。試算：270 t・フラップ 20・10,000 ft で 1.3 Vs のとき約 9.5° 上、フラップ 30 の進入（150 kt）で約 7.6° 上、地上の 120 kt で約 11.8° 上。
- VR の R（FCOM p.972）：VR が V1 から 4 kt 以内（どちらも選ばれているとき）で新設 `airspeed/vr_r` が 1、VR のバグの文字を R だけに。
- グルー：速度テープのグルーが迎角（`sim/flightmodel/position/alpha`）を渡し、新設 `pfd/pli`（飛行機の記号から上へ何度）・`pfd/pli_show`・`airspeed/vr_r` を書く。PLI は両席同じ値。
- パネル（道具 `docs/overhaul/tools/panel_pfd_pli_vr.lua`、画像 `make_pfd_pli_vr_images.ps1`、ACF_DIFF.md §5）：各 PFD の `GROUP TCAS RA Pitch`（バンクで回る）の後に同じ作りの `GROUP PLI`（ポインター 1 本、RA のピッチの限界と同じ 6.81 px/°、30° で止める）。VR のバグは `GROUP Vr Bugs`（RA の条件をグループへ）に入れ、`vr_r` で VR と R の画像を切り替える。PLI の画像は飛行機の記号と同じ幅で、翼の内側 38 % の上に、棒・3 本の斜めの刻み・内側の端の下向きの脚（FCOM p.974 の図の比）。高さは 480（CLIP のポインターは画像の場所の中しか描かないので、動く範囲を含める。最初の高さ 40 の絵は出なかった）。
- 試験：最小速度のモデル 9 件（計 52）、速度テープのモジュール 6 件（計 37）。X-Plane の新しいシナリオ `s56_pfd_pli`・`s57_pfd_vr`。

## 19. 段 4d の実装（2026-10-26 未明：FPV と FPV・PITCH・ROLL の旗）

- FPV のスイッチ（FCOM p.1037：押すと PFD の飛行経路ベクトル）：前は押している間だけ `efis/fpv/<席>/switch_pos` が 1 になるだけで、FPV は無かった。押すたびに新設 `efis/fpv/<席>/selected` を入れ切りする（fltInst02 のコマンドの処理）。
- FPV（FCOM p.980 (10.10.18)）：飛行経路角だけ地平線から上、偏流角だけピッチの目盛の中心線から横。どちらも姿勢表示の枠（バンクで回る）の中で測る。`B747.60.pfd_model.lua` の `fpv_place` が、その席の姿勢（X-Plane の AHRS）と、X-Plane の飛行経路角（`vpath`）・偏流（航跡 `hpath` − 方位 `psi`）から、姿勢表示の中心からのパネルのピクセル（x 右、y 上：ピッチの目盛と同じ 6.81 px/°）を出し、姿勢表示の中に止める（推定）。選んだ IRU が NAV（慣性のデータ）なら出し、そうでなければ FPV の旗（FCOM p.999）。
- 109・405 の CRT の形（FCOM p.979 の図）：丸と左右の腕、丸の下から斜めに下りて水平になる足。「腕は地平線と平行、足は飛行機の記号と平行（CRT）」なので、腕のある本体はバンクで回し（地平線と同じ針）、足は回さない。
- PITCH・ROLL の旗（FCOM p.975・p.977：両席の PFD の姿勢が食い違う）：両席の姿勢が出ていて、ピッチかロールが 3° 以上離れたとき（>ATTITUDE の比べ方と同じ値：旗の値は資料に無いので推定）。両 PFD に出す。画像は純正にあった琥珀の `Failure Flags/pitch`・`roll`（パネルで使われていなかった）。
- グルー：表示器と EIU のグルー。書くもの：新設 `pfd/<席>/fpv_show`・`fpv_flag`・`fpv_x`・`fpv_y`、`pfd/pitch_flag`・`roll_flag`。
- パネル（道具 `docs/overhaul/tools/panel_pfd_fpv.lua`、画像 `make_pfd_fpv_images.ps1`、ACF_DIFF.md §5）：各 PFD の `GROUP PLI` の後に `GROUP FPV`（`fpv_show`）。中は左右へ動く `GROUP FPV X`（`fpv_x`）の中に上下へ動く `GROUP FPV Y`（`fpv_y`）、その中に本体（地平線の針の写しで、ピッチの動き `DEFLECT_*` は外した）と足。ATT・HDG の旗のグループに、FPV の旗（ATT の旗と同じ形の新しい画像）と PITCH・ROLL の旗。旗の位置は FCOM p.999・p.974 の図から、ATT の旗と飛行機の記号の大きさで比を取った（推定）。
- 試験：PFD のモデル 9 件（計 37）、表示器のモジュール 13 件（計 85）。X-Plane の新しいシナリオ `s58_pfd_fpv`。

## 20. 段 4e の実装（2026-10-26 未明：ILS の表示、偏位過大の警告、G/S・LOC の旗）

- 資料：ATA34_1 p.466–468（PFD の ILS の表示の条件、偏位の警告）、p.470（無効のデータ：目盛とポインターが旗に置き換わる、周波数とコースの欄は空白）、ATA31 p.13（PFD の NCD・invalid の表：G/S・LOC は invalid で目盛とポインターを消して黄色の旗、NCD はポインターだけ消す）、FCOM p.987（2 1/3 ドットの内で塗り。低い電波高度で A/P か F/D が入っていると目盛が琥珀・ポインターが点滅。LNAV で LOC を arm して捕まえないときも）、p.988（拡大 LOC 目盛：中心線の近く、四角 1 つが 1/2 ドット）、p.989（立ち上がる滑走路：2,500 ft より下で LOC のポインターがあるとき）、p.999（旗の位置）。
- 新しいモデル `B747.60.pfd_ils_model.lua`（表示器と EIU のグルーで回す）：
  - 受信機：機長は ILS L（X-Plane の NAV1、pilot の HSI。AC standby bus）、副操縦士は ILS R（NAV2、copilot の HSI。AC bus 2：notes/ATA-34.md §2.1）。PFD の ILS の源を切り替える論理は資料に無い（ND の源は表示器がアンテナと偏位の状態と EIU の選択から決める、とだけ：ATA34_1 p.474）ので固定。（訂正、段 5a のとき：FCOM p.1044 に、EIU の選択器が各席の PFD と ND の LOC・G/S の受信機を決める、とあった。段 5b で EIU に合わせる。）ILS C は X-Plane に無い。
  - 同調：純正の `autopilot/ils_dots`（目的地の 50 NM 以内でしか 1 にならない：DSP-14。5-1 段 3 で作り直す）を「周波数が同調されている」に使う。
  - 何も出さない（旗も）：同調していないか、その席の IRU のロールが 53° を超える。53° 超で旗も消すのは推定（資料は目盛とポインターを消す、とだけ）。
  - invalid（旗）：受信機の故障（X-Plane の NAV1・NAV2 の故障か電源なし）で LOC と G/S の両方の旗、周波数とコースは空白。X-Plane の localizer の故障で LOC だけ、glide slope の故障で G/S だけ。
  - NCD（ポインターだけ消す）：信号なし（X-Plane の `hsi_display_horizontal`・`vertical`）。LOC はその席の航跡（段 4a の `trk`）が無いときも（ATA34_1 p.467。滑走路方位の無効は同調の作り直しで）。
  - ポインター：2 1/3 ドットの内で塗り、外で中抜き（どちらの側でも）。LOC は 1/2 ドットの内で拡大の目盛とその上のポインター（「中心線の近く」を純正の 1/2 ドットのまま：推定）。
  - 偏位過大（目盛を琥珀、ポインターを 4 Hz で点滅：周期 0.25 秒の半分ずつ消える）：G/S は G/S が engage、A/P かその席の F/D、電波高度 100〜500 ft、5/8 ドット超。LOC は LOC（か ROLLOUT）が engage、A/P か F/D、500 ft 以下、1/4 ドット超が 1 秒以上。LOC の捕捉失敗：LNAV が engage で LOC が arm、950 ft 以下で捕まえていない（1,050 ft か捕捉で戻る）。ATA34_1 の「approach mode operational」を、それぞれの AFDS のモードが engage と読んだ（推定）。
  - 立ち上がる滑走路：LOC のポインターがあり、その席の電波高度の数字が出ている（2,500 ft より下）。
- グルー：書くもの：新設 `pfd/<席>/ils_show`、`loc_scale`（0 なし、1、2 琥珀、3 拡大、4 拡大の琥珀）、`loc_ptr`（0 なしか点滅の消えた半分、1 塗り、2 中抜き、3 拡大の目盛の上）、`loc_flag`、`gs_scale`（0、1、2 琥珀）、`gs_ptr`（0、1 塗り、2 中抜き）、`gs_flag`、`rwy_show`。純正の `B747_loc_gs_vis_flags`（`localizer_ptr/visibility_flag_*` など）はパネルも 3D も使っていないが、そのまま残した。
- パネル（道具 `docs/overhaul/tools/panel_pfd_ils.lua`、画像 `make_pfd_ils_images.ps1`、ACF_DIFF.md §5）：4 面の PFD の ILS の部品を、純正の `ils_dots` と偏位の値から上の dataref に付け替えた（計器は最後の SHOW しか見ない）。純正の誤り：中抜きのポインターは片側だけ、拡大 LOC 目盛は中心線の右では普通の目盛と重なって出ていた、G/S のポインターは 2.5 ドットで 2 ドットの印（振れが目盛の 8 割。X-Plane の dots は、Laminar の 737 の PFD と同じく 2 ドットが目盛の外の点）。G/S のポインターの振れを目盛の点と同じ 48.5 px/ドットにし、土台の画像（高さ 209）で切られないように CLIP を外した。琥珀の目盛は純正の目盛の色を替えたもの。G/S・LOC の旗は、ATA34_1 p.470 のとおり置き換わる目盛の場所に（FCOM p.999 の図とも合う）、純正の ALT・ATT の旗の作りで。
- 残り：周波数・ID の欄は純正のまま X-Plane の局の ID だけを出すので、ID が受からない（X-Plane の localizer の故障など）と空白（実機は ID を受けるまで周波数：ATA34_1 p.466）。周波数・コースの不一致の琥珀の線（FCOM p.986）。どちらも同調の作り直し（5-1 段 3）で。
- 試験：ILS のモデル 47 件、表示器のモジュール 22 件（計 107）。X-Plane の新しいシナリオ `s59_pfd_ils`（12 NM の進入路で表示・ポインター・旗・ロール 53°：34 件合格）、`s60_pfd_ils_alert`（立ち上がる滑走路、G/S と LOC の偏位過大：15 件合格）。s60 は中心線の上から入ると AFDS が LOC も捕まえた（LAND 3）ので、LOC の偏位過大も X-Plane で確かめた。LOC の捕捉失敗（LNAV で LOC を arm）は FMC の経路が要るので回帰試験だけ。ILS の同調は、CDU の NAV RAD で手動にしてから `ils_dots` を書く（純正の自動の同調は経路の目的地まで 50 NM 以内でないと 2 秒ごとに 0 に戻す。Web API で書いた同調の文字列 `radio/tuningmodes` は XTLua のモジュールに届かない）。

## 21. 段 5 の計画（2026-10-26 未明：ND）

- 今の ND（調べた結果。行番号は 747-400_custom.acf と fltInst02・nd.lua）：
  - パネルの ND は各席 1 面（副操縦士 91197–103945、機長 103946–116693）。CENTER（全周）と EXPANDED の 2 組。
  - 向きは nd.lua の `nd/up/<席>`：X-Plane の `map_mode` が 2 なら航跡、4 なら北、ほかは方位。VOR モードでも `map_mode` を 2 にしているので、VOR の EXPANDED は航跡が上（FCOM は VOR・APP は方位が上：p.1110）。両席とも機長（pilot）の方位と航跡。副操縦士の CENTER の目盛は DATAREF が空で回らない。
  - 機長の ND が副操縦士のモード・方位・G/S を、副操縦士の ND が機長のモード・方位・LOC を読む所がある（DSP-15）。風の矢印は方位基準のまま航跡が上の地図に描く。EXPANDED に方位の印が無い。
  - 電波航法：NAV の源の選択器（FMC L・R、CDU）を ND の基準受信機の選択に流用（DSP-03）。VOR モードでは基準受信機が出ない。TO/FROM が無い。VOR の針の添字は機長の CENTER だけ [3]/[4]（DSP-35）。
  - 旗：IRS が無効のとき HDG（APP・VOR）、MAP・VTK・TRK（MAP）が一斉に出るだけ。LOC・G/S・VOR・DME の旗は無い。
  - EFIS 操作パネル：DATA・POS は動きだけ。CDU の EFIS CONTROL は範囲が両席、WXR は機長だけ、MODE が X-Plane の `map_mode` を変えない（DSP-31）。HDG REF は動きだけ（DSP-20）。
- 資料：FCOM p.1109–1158（ND。109 の MAP は航跡が上、VOR・APP は方位が上、PLN は真北）、p.1030–1034（ND の旗と表示：109 は TRK（MAP）・HDG（VOR・APP）・MAP・VTK・LOC/VOR・G/S・VOR/ADF L・R・DME L・R）、p.1038–1040（EFIS 操作パネルの ND）、p.1043–1044（NAV の源は FMC、EIU の選択器が各席の PFD・ND の LOC・G/S の受信機を決める）、p.1046（HDG REF）、p.1110（方位は選んだ IRU、航跡は FMC、代替航法では IRU）、ATA31 p.18–23（ND のモード、APP の旗：NCD は消すだけ、invalid は旗）、ATA34_1 p.356–368（VOR の表示：有効、方位の NCD・invalid、コースと周波数の NCD・invalid、自動同調中は偏位・コースを消す）、p.470–476（ND の ILS）。
- 段の分け方：
  - 5a：ND の方位・航跡の源と向き、TRK・HDG・MAP の旗（DSP-15 の向きの分、DSP-21・22）。各席の ND を自席の源で（段 4a の `pfd/<席>/hdg`・`trk` と同じ考え）。109 の向き（MAP・MAP CTR は航跡が上、VOR・APP は方位が上、PLN は真北）。MAP の方位の印、VOR・APP の航跡の印、MAP で LNAV・LOC・ROLLOUT のときは選択方位の破線だけを消す（バグは残す：FCOM p.1142）。風の矢印を表示の向きに。109 は TAS を出さない（FCOM p.1141）。
  - 5b：VOR・APP の電波航法（DSP-03・35、DSP-15 の残り）。基準受信機（APP は EIU の ILS L・C・R、VOR は機長 VOR L・副操縦士 VOR R：推定）、周波数か ID・DME・コース・偏位（ND は 2 1/2 ドットの内で塗り：FCOM p.1144）・G/S・TO/FROM、LOC・G/S・VOR・DME の旗（invalid は旗、NCD は消すだけ）、VOR・ADF の針（表示の向きに合わせる）。PFD の ILS の源も EIU に合わせる（段 4e の固定を直す）。
  - 5c：EFIS 操作パネルと CDU の EFIS CONTROL（DSP-16・17・31）：STA の高・低高度、ARPT、DATA・POS、EXCESS DATA、CDU の範囲・WXR・MODE を席ごとに。
  - 5d：HDG REF（DSP-20）：TRUE・NORM、高緯度の自動の真方位、TRU の枠（降下中は琥珀で点滅）、TRU から MAG に戻したときの 10 秒の枠、HDG SEL での切替で HDG HOLD。PFD と ND の両方。
  - 5e：FMC の記号（DSP-23）：トレンドベクトルなど IRS から作れるものだけ。S/C・E/D・減速点・待機・エネルギー円は FMC の作り直し（6-x）で。

## 22. 段 5a の実装（2026-10-26 未明：ND の向き、方位・航跡、旗）

- 新しいモデル `B747.60.nd_model.lua`（表示器と EIU のグルーで回す）。各席の ND を自席の源で：機長は X-Plane の pilot の AHRS（方位）と pilot の航跡、副操縦士は copilot（段 4a の PFD と同じく IRU の代わり）。有効かどうかは段 4a の PFD のモデルの方位（`hdg`）と航跡（`trk`）。
  - 向き（FCOM p.1109–1110、109）：MAP は航跡が上、VOR と APP は方位が上、PLN は北が上。前は X-Plane の `map_mode` を見ていて、VOR も `map_mode` 2 だったので航跡が上だった。両席とも機長の方位と航跡だった。PLN の北は純正どおり磁北（記号も X-Plane の地図の層も磁北で描いている。FCOM は真北：段 5d で）。
  - X-Plane の `map_mode`（X-Plane の地図の層、気象レーダーの映像などがこの向きで描かれる）を、ND のモードから毎フレーム書く：APP・VOR は 0（方位が上）、MAP は 2、PLN は 4（違うときだけ書く）。CDU の EFIS CONTROL でモードを変えたときもこれで合う。
  - 旗（FCOM p.1034、109）：TRK（MAP・PLN で航跡が無い）、HDG（VOR・APP で方位が無い）、MAP（MAP・PLN で FMC の位置が無い）、VTK（MAP で同じ）。FMC の位置は「どれかの IRU が NAV」とした（推定：FCOM p.1240 は FMC の位置に IRS が最低 1 台要る、とだけ）。前は IRS が未整列のときに 4 つが一斉に出るだけだった（IRS が無効のグループの中にあった）。
  - コンパスローズと上の数字（`rose`）：MAP は航跡、VOR・APP は方位があるとき。PLN は固定の目盛なので常に。
  - 方位の印 ▽（FCOM p.1142：MAP、MAP CTR、PLAN。VOR・APP では方位の箱の下：p.1024 の図）：方位があるとき。拡大表示には無かったので足した（全周の画像を拡大の半径 457 に置く：推定）。全周の印は他席の方位と、0 に 2 つある KEY_FRAME で動いていなかった。
  - 選択方位（FCOM p.1142）：PLAN 以外で。破線は、MAP で LNAV・LOC・ROLLOUT が入っているとき、選択方位を動かしてから 10 秒で消える（ロールモードが変わったときも 10 秒出す：純正のまま）。前はバグと破線が一緒に消えていた。
  - 風の矢印（FCOM p.1142）：表示の向きに対して（風の吹いていく向き − 上）。前は方位に対してで、航跡が上の地図では偏流角だけずれていた。その席の速度 100 kt から（純正の閾値：推定）。
  - 拡大の航跡の線（`trk_line`、FCOM p.1143）：MAP、VOR・APP は WXR か TFC が入っているとき（純正の規則）、航跡があるとき。前は航跡が無くても残った。針のグループ（全周と拡大）も `rose` が無いときは消す（前は条件が無く、旗のときも航跡の線などが残った）。
- nd.lua（`plugins/xtlua_nd`）：`nd/up/<席>` を自席のモードと源で（同じ規則の `nd_up`）。地図の記号の角度も同じ向きに（自席の方位・航跡）。記号の作り直しが 0.2 秒ごとのつもりで 2 秒の時計を見ていて、ほぼ毎フレーム全部作り直していた（DSP-21 の残り）のを直した。
- パネル（道具 `docs/overhaul/tools/panel_nd_orientation.lua`、ACF_DIFF.md §5）：2 面の ND の目盛（全周の APP・VOR と MAP、拡大）、上の数字（PLN も航跡：109 は FCOM p.1141 で MAP・MAP CTR・PLAN が TRK）、全周の針のグループ（`nd/up` で回す）、方位の印（全周・拡大・PLN）、選択方位と破線、航跡の線（副操縦士の航跡）、旗、風の矢印。副操縦士の全周の目盛は DATAREF が空で回っていなかった。全周の目盛の KEY_FRAME は拡大と同じ −1°/°に（機長は 1° ずれ、副操縦士は逆向きだった）。PLN の上の数字は、PLN の箱の位置にある元の HDG の部品を TRK（自席の航跡）に替えた（MAP の TRK の部品は位置が違う）。
- 残り：全周表示の選択方位と航跡の線（パネルに無い）、航跡の印（VOR・APP の線に横線：FCOM p.1142。WXR・TFC が入っていないときの拡大の VOR・APP）、109 で TAS を出さないこと、VOR・ADF の針を航跡が上の表示の向きに合わせること（段 5b）、PLN の真北（段 5d）。
- 試験：ND のモデル 39 件、表示器のモジュール 17 件（計 124）、nd.lua の向き 5 件（新しい `tests/displays/nd_orientation_test.lua`）。X-Plane の新しいシナリオ `s61_nd_orientation`（31 件合格。西風 50 kt で方位 007・航跡 019：MAP は航跡が上で ▽ が左に、VOR・APP は方位が上、副操縦士の VOR は副操縦士の方位、PLN は PLN の箱に TRK と北が上の ▽、旗）。最初の試験で、PLN の TRK が MAP の位置に出たのと、旗のときに航跡の線が残ったのを直した。
