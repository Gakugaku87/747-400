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
| >SNGL SOURCE ILS | 注意・beeper | 両席が同じ LOC/GS 受信機 | FCOM p.1430 (11.60.2) | 済（段 5b-1a：両席が同じ EIU） |
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
- 後に回したもの：>TRACK（席ごとの航跡の源が無い）、>SNGL SOURCE ILS と PFD の ILS の目盛の出し方（DSP-14。どちらも ILS 受信機と自動同調に絡むので、無線の同調（5-1 段 3、FMC と一緒）で）。（>SNGL SOURCE ILS は段 5b-1a で済：§23。）FLT DIR・NAV の選択で FD の指示や地図の源が変わること（FCC・FMC が 1 つずつしか無い。AFDS・FMC の作り直しで）。
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
- 残り：周波数・ID の欄は純正のまま X-Plane の局の ID だけを出すので、ID が受からない（X-Plane の localizer の故障など）と空白（実機は ID を受けるまで周波数：ATA34_1 p.466。段 5b-1a で済：§23）。周波数・コースの不一致の琥珀の線（FCOM p.986）は同調の作り直し（5-1 段 3）で。
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

## 23. 段 5b-1a の実装（2026-10-26 未明：PFD の ILS の受信機）

- 段 5b は 3 つに分けた：5b-1a（PFD の ILS の受信機を EIU に）、5b-1b（ND の APP：基準受信機、偏位、LOC・G/S の旗）、5b-2（ND の VOR と VOR・ADF の針）。
- 資料：FCOM p.1044（EIU の選択器が各席の PFD と ND の LOC・G/S の受信機を決める）、p.986（進入の基準：選んだ ILS の ID か周波数と ILS の DME、進入コース）、p.1430（>SNGL SOURCE ILS：caution・beeper、両席の表示が同じ LOC か G/S の受信機を参照）、ATA34_1 p.466（周波数は EIU が局の ID を受けるまで、受けたら ID）、p.474（ND の ILS の源は、表示器がアンテナと偏位の状態と EIU の選択から決める）、p.478（SNGL SOURCE ILS：両席の PFD と ND が同じ ILS から）、notes/ATA-34.md §2.1（ILS L は AC standby bus、C は AC bus 1、R は AC bus 2）。
- グルー（段 4e の `pfd_ils`）：
  - 受信機は使用中の EIU（`eiu/used`）の側：L は ILS L（X-Plane の NAV1）、C は ILS C、R は ILS R（NAV2）。X-Plane に 3 台目が無いので、ILS C は NAV1 のデータ（同じ周波数に同調される）で、電源は AC bus 1、X-Plane の故障は無し（推定）。EIU が無い（0：表示は消えている）ときは自席の既定（機長 L、副操縦士 R）。表示器がアンテナや偏位の状態で源を替える論理（ATA34_1 p.474）は中身が資料に無いので作らない。
  - pilot・copilot の HSI の値をやめて、`nav1_`・`nav2_` の偏位と信号を直接読む。新設 `pfd/<席>/ils_rx`（1 L、2 C、3 R）、`loc_dots`・`gs_dots`（その受信機の偏位。パネルのポインターと立ち上がる滑走路が読む）。
  - G/S の信号：X-Plane の `display_vertical` は、ILS の周波数を同調していれば局が無くても 1 のまま（NAV2 を局の無い 108.15 にして確かめた）。EFIS の G/S の旗 `flag_glideslope`（来るはずの G/S が来ない）が 0 のときだけ受けているとした。段 4e の見落としで、G/S の範囲の外でもポインターが残っていた。LOC の `display_horizontal` は局が無いと 0 になる。
  - 進入の基準の ID：新設の文字列 `pfd/<席>/ils_ref`。受信機の局の ID（X-Plane の `nav_id` は受けている間だけ入る）、受けるまでは周波数（"111.90"）。変わったときだけ書く。
  - >SNGL SOURCE ILS（caution 57。表に名前だけあった）：両席が同じ EIU を使っているとき（受信機は EIU で決まるので、>SOURCE SEL EIU と同じ条件）。
- パネル（道具 `docs/overhaul/tools/panel_pfd_ils_rx.lua`、ACF_DIFF.md §5）：4 組の PFD の LOC のポインター 3 本と立ち上がる滑走路を `loc_dots`、G/S のポインター 2 本を `gs_dots` に。進入の基準の ID を `ils_ref` に（副操縦士の組の 2 つ目の ID の部品は消した。前は両席とも NAV1 の ID で、副操縦士の ILS R の部品も NAV1 を読んでいた）。DME と進入コースは、中央の FMC master 選択器での切り替えをやめて `ils_rx` で NAV1・NAV2 を出し分ける（コースは X-Plane の LOC の向きなので両側とも同じ値）。
- 残り：周波数・コースの不一致の琥珀の線（X-Plane では 3 台が同じに同調されるので起きない。同調の作り直し 5-1 段 3 で）。DME の局が無いときの DME の欄は純正のまま「. 0」（資料に記載が見つからない）。周波数の文字は純正の字形のため「108. 15」と点の後が空く。
- 試験：表示器のモジュール 23 件（計 147）。X-Plane の新しいシナリオ `s62_pfd_ils_rx`（31 件合格：機長の EIU を R・C、副操縦士を L に回して偏位の出どころと ID、>SNGL SOURCE ILS と >SOURCE SEL EIU、NAV2 を局の無い 108.15 にして周波数とポインターの消去）。1 回目は NAV2 の局が無くなっても G/S のポインターが残り、上の G/S の信号の読み違いが分かった。

## 24. 段 5b-1b の実装（2026-10-26 未明：ND の APP）

- 資料：FCOM p.1144（APP・APP CTR：基準受信機 ILS L・C・R、周波数か ID（ID を解読するまで周波数）、DME、LOC の偏位のバーと目盛（2 1/2 ドットの内で塗り）、コースの指針と線、G/S の指針と目盛（同じく塗り））、p.1146（コースは CDU で選んだもの）、p.1033（計算値が無いと数字の代わりに「---」）、p.1034（109 の拡大表示の旗の位置：LOC は下の中央、G/S は右の中ほど、DME は右上）、ATA31 p.20–21（APP の旗：NCD はデータを消す、invalid は消して旗。全周は LOC が飛行機の記号の左、拡大は下）、ATA34_1 p.473（同調前（進入の段階でない）は周波数が「---」、滑走路の方位が選ばれていなければコースが「---」でコースの指針が消える。G/S・LOC の目盛と指針は有効なデータで出す）、p.476–477（データの故障：G/S・LOC は目盛ごと旗に、コースの故障は指針とコースが消え、周波数の故障は周波数と ID が消える）、p.358（VOR の方位の NCD は偏位のバーと目盛と TO/FROM を消す）。
- モデル（段 4e の `B747.60.pfd_ils_model.lua` に足した。受信機は PFD と同じ：FCOM p.1044）：
  - 目盛と指針は有効なデータのときだけ：invalid（受信機の故障、X-Plane の localizer・glide slope の故障）は旗、NCD（信号なし、同調前）は目盛ごと消す（ND の VOR の記述 ATA34_1 p.358 と、p.473 の「有効なデータで目盛と指針が偏位を示す」に合わせた。PFD は ATA31 p.13 の表のとおり目盛を残す）。指針は 2 1/2 ドットの内で塗り（X-Plane は外れると 2.5 で止まるので、2.49 より内を塗り）。PFD の 53° の制限は ND には無い。
  - コースと周波数：受信機の故障で消える、同調前は「---」（コースの指針も消える）、同調中はコース（CDU のコース `nav_obs_deg_mag_pilot`）と ID か周波数。同調は純正の `ils_dots`（段 4e と同じ）。
  - DME：X-Plane の DME の故障（`rel_dme`）で DME の旗、受信機に DME の距離が無いか同調前は「DME ---」、ほかは距離。FCOM p.1034 の旗は DME L・R だが、純正の旗の画像（L・R の無い「DME」）を使った。
- グルー：新設 `nd/<席>/loc_scale`・`loc_ptr`・`loc_flag`・`gs_scale`・`gs_ptr`・`gs_flag`・`crs`（0 なし、1「---」、2 表示）・`crs_deg`・`dme`（0「DME ---」、1 距離、2 旗）・`dme_nm`、文字列 `nd/<席>/ils_ref`（PFD と同じ ID か周波数。同調前は「---」、受信機の故障で空）、文字列 `nd/dashes`（パネルのコースの「---」）。
- パネル（道具 `docs/overhaul/tools/panel_nd_app.lua`、ACF_DIFF.md §5）：2 面の ND の全周と拡大の LOC の組を `pfd/<席>/ils_rx` で NAV1（L・C）か NAV2（R）に（前は NAV の源の選択器の FMC L・R：DSP-03）。バーの振れを 121.25 px に（X-Plane の `DEFLECT_SRC` は 2.5 ドットで `DEFLECT_PIX`。目盛の点は 48.5 px/ドットなので、前の 115 は 5 % 短かった。写真で 1.05 ドットのバーが 1 ドットの点に重なるのを確かめた）。G/S は自席の `pfd/<席>/gs_dots` で 48.5 px/ドット（前は 2.5 ドットで 2 ドットの印、機長の拡大は副操縦士の値）。旗：G/S は目盛の位置、LOC は全周で飛行機の記号の左、拡大で記号の下（FCOM p.1034 は記号の高さの中央、ATA31 p.21 は下の左寄り：推定）。基準受信機の欄は組み直した：ILS L・C（新設）・R の見出し、ID か周波数の文字 1 つ（前は 3 行の条件で ID も周波数も出ず、ILS R の周波数は VOR L のもの）、コースの数字か「---」、DME は緑（FCOM p.1144。前は白）の距離か「DME ---」か旗。
- 残り：DME の旗の L・R、PFD の DME の欄の「---」と旗（純正のまま）、ND の VOR（段 5b-2）、周波数・コースの不一致（同調の作り直しで）。
- 試験：ILS のモデル 77 件（30 件増）、表示器のモジュール 167 件（20 件増）。X-Plane の新しいシナリオ `s63_nd_app`（39 件合格：機長の ND は APP の拡大、副操縦士は APP CTR。同調前の「---」と目盛なし、同調して ID・コース・DME・バー・G/S の指針、LOC 1.05 ドットでバーが 1 ドットの点に重なる、X-Plane の localizer・glide slope・DME の故障で 3 つの旗、機長の EIU C で ILS C、NAV2 を局の無い 108.15 にして周波数・「DME ---」・目盛と指針の消去）。1 回目は NCD でも目盛を残す作りだったのを、VOR の記述（ATA34_1 p.358）に合わせて直した。

## 25. 段 5b-2a の実装（2026-10-26 未明：ND の VOR）

- 段 5b-2 は 2 つに分けた：5b-2a（VOR モード：基準 VOR、偏位、TO/FROM、旗）、5b-2b（VOR・ADF の方位の針と左右下の欄）。
- 資料：FCOM p.1024（109 の VOR と VOR CTR の図：右上に基準 VOR・周波数か ID・CRS・DME、右下に TO/FROM の文字、全周は飛行機の記号の近くに TO/FROM の三角）、p.1144–1146（基準受信機、周波数は ID を解読するまで、偏位のバーは ILS だけ塗り（VOR は中抜き）、コースの指針と線、TO/FROM：VOR・VOR CTR、三角は VOR CTR）、p.1034（旗：VOR モードは VORL・VORR）、p.1033（計算値が無いと「---」）、ATA34_1 p.356–357（VOR の有効な表示）、p.358（方位の NCD：バー・目盛・TO/FROM を消す）、p.360–361（方位の invalid：消して VOR の旗。拡大は飛行機の記号の下、全周は記号の上）、p.364–367（コースの NCD は指針を消して数字を「---」、invalid は消す。周波数の NCD は「---」、invalid は消す）、p.368–369（自動同調の間はバー・目盛・コースの指針・TO/FROM を消し、図ではコースが「---」）、notes/ATA-34.md §2.1（VOR L は AC standby bus、R は AC bus 2）。
- 基準 VOR：機長は VOR L（X-Plane の NAV3）、副操縦士は VOR R（NAV4）。FCOM は「選んだ受信機」とだけで、選び方の記述が無いので自席の側にした（推定。純正は NAV の源の選択器の CDU の位置で選んでいた：DSP-03）。
- モデル（`B747.60.nd_model.lua` に足した）：受信機の故障（電源なし。X-Plane に NAV3・4 の故障は無い）で VOR の旗、偏位・TO/FROM・コース・周波数を消す。自動同調（`radio/tuningmodes` の 2・3 文字目が M でない）ではコースを「---」にして、指針・偏位・TO/FROM を消す。方位の信号が無い（範囲外：NCD）と偏位と TO/FROM を消す（コースは残る）。DME は APP と同じ（距離・「DME ---」・旗）。周波数の NCD の「-----」は、X-Plane では周波数が常にあるので作らない。
- グルー：新設 `nd/<席>/vor_rx`・`vor_flag`（1 VOR L、2 VOR R の旗）・`vor_dev`・`vor_crs`・`vor_crs_deg`（CDU のコース `nav_obs_deg_mag_pilot[2]`・`[3]`）・`to_from`（X-Plane の `nav_flag_from_to_pilot`）・`vor_dme`・`vor_dme_nm`、文字列 `nd/<席>/vor_ref`。
- パネル（道具 `docs/overhaul/tools/panel_nd_vor.lua`、画像 `make_nd_vor_images.ps1`、ACF_DIFF.md §5）：2 面の ND の全周と拡大の VOR の組を `vor_rx` で、コースの指針・バー・目盛を上の dataref で（バーの振れは APP と同じ 121.25）。全周に TO/FROM の三角（コースの向きの 65 px 先、FROM は逆向き：FCOM p.1024 の比）、VOR モードの旗の組（全周は記号の上 62 px、拡大は記号の下：ATA34_1 p.361）。基準受信機の欄は APP と同じ形に組み直し、右下に TO・FROM の文字（CRS の見出しから左 90・下 542 px：FCOM p.1024 の比）。
- 残り：VOR・ADF の針と左右下の欄（段 5b-2b）、VOR の周波数の NCD、DME だけの局の小さな文字（FCOM p.1144）。
- 試験：ND のモデル 57 件（18 件増）、表示器のモジュール 186 件（19 件増）。X-Plane の新しいシナリオ `s64_nd_vor`（31 件合格：機長の ND は VOR、副操縦士は VOR CTR。自動同調（このとき既に NRE）の「CRS ---」、CDU で VOR L・R に NRE 117.90 とコース 330 を入れて手動にし、ID・コース・緑の DME・中抜きのバー（1.7 ドット）・TO の文字と全周の三角、コース 150 で FROM、BUS TIE 2 と GEN CONT 2 を切って AC bus 2 を落とし、副操縦士の ND に VORR の旗と周波数・コースの消去（DME は残る。副操縦士の表示器は F/O transfer bus が AC bus 1 に移って動いたまま））。

## 26. 段 5b-2b の実装（2026-10-26 早朝：ND の VOR・ADF の針と左右下の欄）

- 資料：FCOM p.1038–1040（EFIS 操作パネルの VOR/ADF スイッチ：VOR は VOR の針・周波数か ID・DME、ADF は ADF の針・周波数か ID を、PLAN 以外のすべてのモードで。OFF で消す）、p.1144（針：左は 1 本線、右は 2 本線、頭が局へ、尾が局から。モードは MAP・MAP CTR・VOR・VOR CTR・PLAN）、p.1145–1146（左右下の欄：VOR は緑、ADF は青、周波数は ID を解読するまで。モードは MAP・MAP CTR・VOR・VOR CTR・APP・APP CTR）、p.1034（左右下の旗：VOR か ADF の旗、DME の旗（MAP・VOR・APP））、p.1228・p.1230（ADF は青、VOR は緑）、ATA34_1 p.362（針と欄は自動同調でも手動でも出す）。
- モード：p.1144 は針に PLAN を入れて APP を入れず、p.1040（スイッチの説明）と p.1145（欄）は PLAN 以外。p.1040 に合わせて、針と欄を PLAN 以外のすべてのモードで出す。ATA31 p.24 も「VOR・ADF の表示は PLAN 以外のすべての ND のモード」とあり、これで裏付けられた（同じ頁：ADF の欄に DME は無い、ID を受けなければ周波数、全周では針の頭と尾の両方）。
- モデル（`B747.60.nd_model.lua`）：各席の左右のスイッチ（0 OFF、1 VOR、2 ADF）。欄はスイッチのとおり（PLAN は消す）、受信機が壊れていれば名前の代わりに旗、VOR の欄の DME は距離・「DME ---」・旗。針は受信機が動いていて、局の方位を受けていて（VOR は方位の信号、ADF は局の ID：X-Plane に ADF の受信の旗が無い）、ローズと方位があるとき。向きは「相対方位 + 自席の方位 − 表示の上」（MAP の航跡が上でもずれない）。受信機：VOR L・R は電源だけ（X-Plane に NAV3・4 の故障が無い）、ADF L・R は電源（AC bus 3・AC bus 2）と X-Plane の ADF の故障。
- グルー：新設 `nd/<席>/ptr_l`・`ptr_r`・`brg_l`・`brg_r`・`rad_l`・`rad_r`・`rad_l_flag`・`rad_r_flag`・`rad_l_dme`・`rad_r_dme`、両席共通の文字列 `nd/vor_l_ref`・`vor_r_ref`・`adf_l_ref`・`adf_r_ref`（ADF の周波数は整数 kHz）。
- パネル（道具 `docs/overhaul/tools/panel_nd_brg.lua`、ACF_DIFF.md §5）：針の組を `ptr_l`・`ptr_r` で、針の向きを `brg_l`・`brg_r` に（前は X-Plane の相対方位で MAP ではずれ、全周の VOR の針は NAV4・NAV5 を、ADF は `[10]` を読んでいた：DSP-35）。全周の針の組は前は APP と VOR だけ。左右下の欄は `rad_*` で、名前と旗、ID か周波数の文字 1 つ（周波数の部品は消した）、DME。APP・VOR の右上の DME の旗も DMEL・DMER に（段 5b-1b・5b-2a では純正の「DME」）。
- 残り：DME だけの局の小さな文字（FCOM p.1144）、ADF の ANT・BFO（純正に無い）、POS の VOR の radial（段 5c）。
- 試験：ND のモデル 76 件（19 件増）、表示器のモジュール 199 件（13 件増）。X-Plane の新しいシナリオ `s65_nd_brg`（23 件合格：フランクフルトの NDB FR の南で開始（東京の近くには NDB が無い）、CDU で VOR L・R に FKS・TAU、ADF L・R に 297。機長の ND は MAP で左に VOR L の針（FKS は後ろ）、右に ADF R の青い 2 本線の針（FR は正面）、左下に VOR L・FKS・DME、右下に ADF R・FR。副操縦士の VOR CTR は左 ADF・右 VOR。ADF 1 の故障で副操縦士の左の針が消えて左下に ADFL の旗、DME の故障で DMEL・DMER の旗（右上と左右下）、PLN で針と欄が消える）。

## 27. 段 5c-1 の実装（2026-10-26 朝：CDU の EFIS CONTROL・OPTIONS、EFIS 操作パネルの故障）

- 段 5c は 3 つに分けた：5c-1（CDU の代わりの操作：EFIS CONTROL・OPTIONS を席ごとに、パネルの故障のときだけ。DSP-31）、5c-2（DATA・POS の表示：DSP-16）、5c-3（STA の高・低高度、同調中の局、ARPT、EXCESS DATA：DSP-17）。
- 資料：FCOM p.1060（CDU は EFIS 操作パネルと表示選択パネルが故障したときの代わり。109 は TCAS を除く：CDU-152）、p.1061（MENU の EFIS CP・EICAS CP の SELECT は、そのパネルが故障したときに使える。CDU-161 は CTL PNL の行があり、SELECT が無いときも見出しは残る）、p.1062–1063（EFIS CONTROL（CDU-152）：BARO SET、DH SET、DH RESET、MDA SET、RANGE INCR・DECR、MAP・PLN・APP・VOR・CTR、OPTIONS。CTR は APP・VOR・MAP の全周と拡大の切り替え）、p.1065（EFIS OPTIONS（CDU-152）：WXR、POS、MTRS、FPV、WPT、STA、ARPT、DATA、VOR、ADF、CONTROL。VOR・ADF は左右の両方を選び、他方を消す）、p.1066–1067（CDU-161 の OPTIONS は TFC と ADF/VOR の切り替え、405・570 は TERR も）、p.1198（>EFIS CONTROL L・R）。
- CDU と席：左の CDU は機長の、右は副操縦士のパネルの代わり、中央はどちらでもない（推定：FCOM に CDU と席の対応の記述が無い。EFIS CONTROL の項目が席ごとなので自席側の CDU にした。純正も右の CDU だけ副操縦士側で、左と中央は機長側）。
- MENU（`B744.fms.pages.lua`）：EFIS CP SELECT はそのパネルの故障（`efis/fail[席]`）、EICAS CP SELECT は表示選択パネルの故障（`dsp/fail`）のときだけ出して押せる（前はいつも）。使えないときは SELECT を消して見出しを残す（CDU-161 の記述に合わせた：推定）。CDU-161 の CTL PNL の見出しは消した（CDU-152 には無い）。
- EFIS CONTROL：RANGE INCR・DECR はその側だけ（前は両側を同じ値に）で、X-Plane の地図の範囲（副操縦士は `map_range_copilot`）も。新しい値を変数に持って両方に書く（XTLua では同じフレームで書いた dataref を読み直すと古い値が返ることがあり、1 回目に X-Plane の範囲が付いてこなかった：X-Plane の試験で分かった）。DH RESET はその側（前は両方の CDU が機長の MINS RST を押していた）。CTR は CTR スイッチと同じく PLN では効かない。モードは段 5a からグルーが X-Plane の地図のモードを書くので、CDU で選んでも X-Plane の地図が付いてくる（DSP-31 の「MODE が map_mode を更新しない」）。
- STD と DH RESET：パネルのコマンドは故障で効かなくなるので、新設のコマンド `laminar/B747/efis/baro_std/<席>/cdu`、`laminar/B747/efis/dh/<席>/cdu_reset` でパネルの押しボタンと同じ処理を呼ぶ。XTLua ではコマンドを init スクリプトで作る（ロジックのスクリプトの `deferred_command` は処理を付けるだけ）。1 回目の X-Plane の試験で STD が効かず、init に無いことが分かった（試験のモックはどんな名前のコマンドも通す）。静的検査 `xt_bindings_created_test.lua` に、ロジックのスクリプトが使う laminar/ のコマンドが init で作られているかの検査を足した（作り直し前からの抜け 19 件は既知の一覧に）。
- EFIS OPTIONS（`activepages/B744.fms.pages.efisctl.lua`）：CDU-152 の並びに（前は TERR・TFC で CDU-161 の 405 の並び）。WXR はその側（副操縦士は `sim/instruments/EFIS_copilot_wxr`。前は機長の）、POS・DATA は新設の状態 `nd/data/<席>/pos`・`data`（前は効かなかった）、MTRS・FPV はパネルと同じ `efis/meters|fpv/<席>/selected`。<SEL> はその側の状態。
- パネル（`B747.60.xt.fltInst02.lua`）：EFIS 操作パネルの 50 個の操作（両席の EFIS・ND のコマンド）は、そのパネルが故障していると何もしない。VOR/ADF スイッチは 3D のコクピットが X-Plane のコマンド（`sim/instruments/EFIS_1|2_pilot|copilot_sel_up|dn`）を直接使うので、`replace_command` で引き取った（上で VOR、下で ADF。X-Plane と同じ動きを確かめた）。DATA・POS の押しボタンは押すたびに状態を切り替える（前はボタンが動くだけ）。X-Plane の VOR/ADF セレクターの dataref の名前が左右と席で取り違えてあった（飛行開始で全部 OFF にするだけで実害なし）のも直した。
- 残り：DATA・POS の表示（5c-2）。表示選択パネルの故障でパネルのボタンを効かなくすること（EICAS の作り直し：段 6。EICAS MODES のページは今もパネルのコマンドを呼ぶ）。CDU-161・TERR・TFC は 109（CDU-152）に無い。
- 試験：新しい `tests/displays/cdu_efis_test.lua`（49 件：MENU の SELECT、席ごとの範囲・DH RESET・STD・CTR、OPTIONS の並びと選択、中央の CDU、EICAS CP。変更前のコードでは 32 件が落ちる）。表示器のモジュール 217 件（18 件増：DATA・POS、故障したパネルの FPV・POS・範囲・STD・MINS RST・VOR/ADF スイッチが効かない、CDU のコマンドの STD と DH RESET、VOR/ADF スイッチの向きと端）。静的検査にコマンドの作成の検査。X-Plane のシナリオ `s66_cdu_efis`（41 件合格：東京の東の海上、10,000 ft。機長のパネルの故障で左の CDU の EFIS CP SELECT と >EFIS CONTROL L、故障したパネルの FPV・範囲・VOR/ADF スイッチは効かない。CDU の RANGE INCR は機長側だけで X-Plane の地図の範囲も、STD（気圧 30.12 から 29.92）、PLN・MAP で X-Plane の地図のモード 4・2、OPTIONS の FPV（PFD に FPV）・POS・DATA・WXR と <SEL>。副操縦士のパネルも故障させて右の CDU の範囲と WXR が副操縦士側に。パネルを戻すとパネルの操作が効く。CDU・PFD・ND を撮った。1 回目は 35 件中 2 件が落ちた：CDU の STD が効かない（init にコマンドが無かった）、副操縦士の X-Plane の地図の範囲が付いてこない（同じフレームの読み直し））。

## 28. 段 5c-2a の実装（2026-10-26 朝：ND の DATA）

- 段 5c-2 は 2 つに分けた：5c-2a（DATA：経路の点の高度と ETA）、5c-2b（POS：IRU・GPS の位置、VOR の radial）。
- 資料：FCOM p.1040（DATA：PLAN・MAP・MAP CTR で、FMC の ETA、各点の高度、高度の制限）、p.1148（経路データ：入力された・手順の高度と ETA、現用点はマゼンタ、ほかは白）、FMSPG p.50（同じ色の表と「KILMR / 12000 / 0835Z」の 3 行の例）。
- FMC（`B747.68.xt.fms.lua`）：各点の ETA を FMC 自身が出す（ND の右上の現用点の ETA と必ず一致させ、FMC の予測を作り直せば ND も直るように）。空中で 1 秒ごとに、現用点から先の各点について経路に沿った距離を、現用点・次の点の ETA と同じ関数 `get_ETA_for_Distance` に渡す（距離 ÷（対地速度と下限の速度の大きい方）。下限が 275×1.944＝534.6 kt なのは GAP の FMC-21 で、誤りか巡航の TAS の見込みかはコードから決められないので、FMC の作り直し 6-1 で扱う）。新設の文字列 `laminar/B747/fms/route_eta`：`xtlua/fms` の各点の UTC の分の JSON の配列（現用点より前、地上、位置の無い点は -1）。
- ND（`plugins/xtlua_nd` の `B747.61.xt.nd.lua`、新しい純粋なモジュール `B747.61.nd_data.lua`）：2 秒ごとに FMC の ETA と遷移高度（`fms/data` の `transalt`）を読む。経路の点は地図の枠の先頭に入るので、先頭の 20 枠に、その席の DATA が入っていれば 2 行を書く：高度（`xtlua/fms` の 9 番目：VNAV のページと同じ「その点の高度」。0 は無し）と ETA（`HHMMZ`）。遷移高度以上は `FL200` の形（推定：資料の例は 12000 だけ。CDU の書き方）。高度の無い点は ETA を 1 行目に上げる（推定：資料の例は両方ある点だけ）。色は現用点（3003）がマゼンタ、ほかの経路の点が白。新設 `nd/<席>/text/rdata_color`（20 枠）、`rdata1_<n>`・`rdata2_<n>`（init `B747.61.nd`）。DATA のモードは、経路の点が MAP と PLN でだけ描かれるので、そのまま PLAN・MAP・MAP CTR になる。
- XTLua の `dofile` は戻り値を返さないので、純粋なモジュールはほかのモデルと同じくグローバル（`B747_nd_data`）に入れる（試験では `dofile` の戻り値）。
- パネル（道具 `docs/overhaul/tools/panel_nd_data.lua`、ACF_DIFF.md §5）：両方の ND の先頭 20 枠の識別子の下に 26 px 間隔で 2 行（白とマゼンタの組を `rdata_color` で出し分け）。パネルの名前は 19 文字で切られる（`ND Text10 backrotat`）ので、新しい名前は短くした。
- 試験キット：X-Plane の FMS に試験の経路を入れる FlyWithLua の `tests/flight/fwl/B747_route.lua`（XPLM の FMS 関数を FFI で呼ぶ。ID は近くの空港・VOR・NDB・fix から探す）と、シナリオの手順 `route`・`route_clear`。
- 残り：POS（5c-2b）。FIX ページの予測の点（FCOM p.1149）、ステップ上昇などの FMC の予測（6-1）。
- 試験：新しい `tests/displays/nd_data_test.lua`（29 件：行の作り、FMC の各点の ETA（モックの FMS モジュール）、ND の枠（モックの ND モジュール）、席ごとの DATA、ETA の無い点）。X-Plane のシナリオ `s67_nd_data`（21 件合格：フランクフルトの南、4,000 ft。`route` で NDB FR（現用点、5000 ft）、TAU（20000 ft）、EDDF（高度なし）。FMC の各点の ETA（10:01・10:04・10:06）、機長の DATA で FR は「5000 / 1001Z」がマゼンタ（右上の現用点の ETA 1001.4z と一致）、TAU は「FL200 / 1004Z」、EDDF は「1006Z」（白）、副操縦士の ND は DATA なしで出ない、PLN でも出る、DATA を切ると消える。ND を撮った。1 回目は経路の FKS が実際は出発点の南西（機体の後ろ）で、拡大の MAP に出ないのが正しかった（経路を組み直した）。2 回目は ND が FMC の ETA を読む前（2 秒ごと）に確かめて 3 件落ちた）。

## 29. 段 5c-2b の実装（2026-10-26 朝：ND の POS）

- 資料：FCOM p.1040（POS：MAP・MAP CTR で IRU と GPS の位置、CDU の NAV RAD の VOR への raw data の radial。DME があればその距離に印、無ければ画面の端まで）、p.1145（VOR/DME raw data radial and distance（緑）：機体から CDU で同調した VOR へ、図は「R-200」の文字つき）、p.1150（GPS の位置（白：円と左右の二股）、IRU の位置（白：5 本腕の星）を FMC の位置に対して）。
- モデル（`B747.60.nd_model.lua`）：MAP（全周・拡大）で POS が入っていれば、NAV の IRU ごとの星と、どちらかの GPS が有効なら GPS の記号。位置は FMC の位置に対して描くが、ここでは IRU・GPS・FMC の位置が 3 つとも X-Plane の位置なので、いつも飛行機の記号に重なる（IRU のずれは資料に値が無いので作らない）。radial は VOR L・R（受信機が動き、方位を受けていて、自席の方位とローズがあるとき）：向きは「相対方位 + 自席の方位 − 表示の上」、radial は局から見た向き（＋180°、0 は 360）、長さは DME の距離（465 px＝選んだ範囲：地図の記号と同じ縮尺）で印つき、DME が無いか範囲の外なら画面の端まで（推定：拡大は範囲の弧の 465 px と画面の左右 329・348 px の近い方、機体の後ろは描かない（地図の記号と同じ）、全周は地図の記号の 250 単位＝182 px）。
- グルー：新設 `nd/<席>/pos_iru`（3）・`pos_gps`、radial ごとに `pos_rad_l`・`_brg`・`_len`・`_end`（最後の 24 px の線分の位置）・`_tick`・`_tbrg`・`_tside`・`_text`（`_r` も同じ）。文字は線に沿わせ、読める向きになるよう右向きの線（0〜180°）は線の右側、左向きは左側に回す（推定）。
- パネル（道具 `docs/overhaul/tools/panel_nd_pos.lua`、画像 `make_nd_pos_images.ps1`、ACF_DIFF.md §5）：地図の記号のグループ（`ND Text Center`：CTR で動く）の最後に、星 3 つと GPS の記号を機体の位置（高度の到達の弧と同じ点：画像は POS を中心に置くので地図の記号の距離 0 の点）に、radial は機体の位置を中心に回すグループの中に 24 px の線分 20 本（長さを超えた分だけ）と、長さの所で終わる最後の線分、DME の印、機体から 50 px の所の文字。X-Plane で、FKS への radial の印が FKS の記号の上に来ること（回転の中心と縮尺が地図の記号と一致）を写真で確かめた。
- 気づいたこと：MAP CTR の地図の記号（局、経路の点）は拡大と同じ 465 px/範囲で、250 単位（182 px）までしか描かれず、全周のローズ（約 230 px）と縮尺が合っていないように見える。地図の記号を扱う段 5c-3 で確かめる。
- 試験：ND のモデル 97 件（21 件増：IRU・GPS、向き、radial、DME の長さと印、画面の端（弧・左右・後ろ・全周）、DME の故障、VOR モードでは無し、R-360）、表示器のモジュール 227 件（10 件増）。X-Plane のシナリオ `s68_nd_pos`（18 件合格：FKS の 11 NM 南、20 NM の MAP。IRU の星、GPS の記号（初回測位の後）、FKS への radial は DME の距離まで印つき（R-176）、範囲の外の TAU へは範囲の弧まで印なし（R-155）、MAP CTR、POS を切ると消える。1 回目は VOR R が TAU に替わった直後で X-Plane の方位の針がまだ回っていて 2 件落ちた（試験の待ちを足した））。

## 30. 段 5c-3a の実装（2026-10-26 朝：ND の地図の記号、EXCESS DATA、GS）

- 段 5c-3 は 2 つに分けた：5c-3a（STA の高・低高度、同調中の局、STA・WPT・ARPT は MAP だけ、EXCESS DATA、109 の GS）、5c-3b（出発・到着空港と滑走路、手動同調の局のコースの線、MAP CTR の縮尺）。
- 資料：FCOM p.1040（STA：MAP・MAP CTR で、10・20・40 NM は高・低高度の局、80 NM 以上は高高度の局だけ。WPT：40 NM 以下。ARPT：すべての範囲）、p.1145（同調中の VHF の局はスイッチに関わらず緑）、p.1111・p.1030–1031（EXCESS DATA：表示できる量より多いとき。STA・WPT・ARPT・DATA などを切ると消える。図では画面の左上）、p.1141（TAS は 405・570 だけ。109 の図は GS だけ）。
- ND のモジュール（`B747.61.xt.nd.lua`）：記号の決め方を「何を出すか決める → 枠が空いているか → 書く」の順に組み直した。空港・fix・局は MAP（全周・拡大）だけ（前はどのモードでも出た）。VOR は、VOR L・R（X-Plane の NAV3・NAV4）が同調している局ならスイッチに関わらず緑（前は STA のときだけ）、ほかは STA で、40 NM 以下は全部、80 NM 以上は高高度の局だけ（前は全部）。NDB も同じ。
- 高・低高度：X-Plane が使う航法データ（Navigraph の Custom Data、無ければ default data）の earth_nav.dat の受信範囲で、100 NM 以上を高高度とした（推定：VOR は 125・130・150 が高高度、40 が低高度、25 がターミナルの値。NDB は 75 以下で、いつも低高度）。起動後に 1 フレーム 500 行ずつ読む（約 80 フレーム）。読み終わるまでは高高度の局が無いものとして扱う。行の読み方と照合は純粋なモジュール `B747.61.nd_data.lua` の `nav_line`・`nav_near`（同じ ID で 0.1° 以内）。
- EXCESS DATA：パネルの 60 枠が埋まって出せない記号があれば、新設 `nd/<席>/excess_data`。パネルは画面の左上に琥珀（推定：資料の図は灰色。ND の故障の文字の色）の文字（道具 `panel_nd_excess.lua`、画像 `make_nd_excess_image.ps1`）。
- GS：FMC のモジュールが ND の GS の行に「GS     TAS」と TAS を書いていたのを、GS だけに（109）。
- 気づいたこと：XTLua の航法施設の一覧（`xtlua/navaids`）は機体の近くのものだけらしく、640 NM の範囲で ARPT を入れると空港が機体の周りに集まる。遠くの空港・局を出すには一覧の作り方を変える必要がある（5c-3b 以降）。
- 試験：新しい `tests/displays/nd_symbols_test.lua`（25 件：行の読み方、照合、STA なしの同調中の VOR、STA の NDB と VOR、ARPT、80 NM での低高度の局、VOR モードで記号なし、70 の NDB で EXCESS DATA と STA を切って消えること）。X-Plane のシナリオ `s69_nd_sta`（15 件合格：フランクフルトの南、4,000 ft、MAP。CDU で VOR L に FKS。STA なしで FKS と VOR R の自動同調の局（RID）が緑の記号、STA で局が増える、160 NM では高高度の VOR（DOR、BAM、GMH、NVO、COL、FUL、WRB）と同調中の RID だけ（NDB と低高度の VOR は消える）、VOR モードで記号なし、640 NM で ARPT を入れると左上に EXCESS DATA、切ると消える、GS の行は GS だけ。ND を撮った。1 回目は STA なしで「2 枠目は空」と期待したのが誤りで（VOR R の自動同調の局も同調中なので緑で出る）、試験を直した）。

## 31. 段 5c-3b の実装（2026-10-26 朝：ND の出発・到着空港と滑走路）

- 資料：FCOM p.1149（空港と滑走路（白）：出発・到着に選ばれたもの。80・160・320・640 NM は空港の記号と滑走路（図は「KABC / 22L」と、円から延びる線）、10・20・40 NM は滑走路と、14.2 NM 延びる破線の中心線（図は「22L」）。どちらも MAP・MAP CTR・PLAN。空港（青）は ARPT で出るが、出発・到着空港は ARPT に関わらずいつも出る）、p.1148（経路の点は MAP・MAP CTR・PLAN）、p.1040（DATA は PLAN・MAP・MAP CTR。p.1148 の表は MAP・MAP CTR だが、操作パネルの説明の p.1040 に合わせたまま）、p.1301–1302（DEPARTURES の RWYS で出発の滑走路を選ぶ）。整備マニュアル（ATA31 p.30）には表示する項目の名前だけ。
- 出発・到着空港と滑走路の決め方：X-Plane の FMS の経路（`xtlua/fms`）から。X-Plane で確かめたこと（試験キットの経路の道具に、FMS の全項目を書き出す `FlyWithLua/B747_route/dump` を足して）：CDU の RTE で ORIGIN を入れると経路の 1 番目が出発空港（種別 1、高度は標高）、DEST で最後が到着空港。DEST だけでは FMS が受け付けない（INVALID ENTRY）。DEP ARR で出発の滑走路を選んで EXEC すると、出発空港の次に「RW25C」（種別 2048、閾値の位置と標高）が入る。進入（ILS26R）を選ぶと進入の点（FI26R など）の後に「RW26R」、その後に進入復行の点、最後に到着空港。そこで、経路の最初が空港なら出発空港、最後が空港なら到着空港とし、その空港から 6 NM 以内（推定）の「RW」と番号の項目のうち、出発は最初の、到着は最後のものを選んだ滑走路とした（純粋なモジュール `B747.61.nd_data.lua` の `route_ends`）。RTE の RUNWAY の欄（FMC のデータ `runway`）は X-Plane の経路に入らない文字だけなので使わない（FMC の作り直し 6-1 で RUNWAY と DEPARTURES を同じものにする）。
- 滑走路の形：選んだ閾値は経路の位置、反対側の端は、X-Plane が使う航法データの CIFP（`Custom Data/CIFP/<空港>.dat`、無ければ `Resources/default data/CIFP/`）の RWY の行（閾値の位置と、ずらした閾値の距離 ft）。反対の番号は 18 を足して 36 で回し、L と R を入れ替える（RW25C と RW07C、RW26R と RW08L）。両端は、ずらした閾値の分だけ外に延ばす。CIFP は、選んだ滑走路のある空港が経路に入ったときに 1 フレーム 500 行ずつ読む（1 空港 2,000 行ほどで 4 フレーム）。EDDM の RW26R は、経路の位置と CIFP の位置が一致した。
- 表示（ND のモジュール `B747.61.xt.nd.lua`）：両席それぞれ、MAP・MAP CTR・PLAN で、IRS があるとき。80 NM 以上は空港の記号（白の円：ARPT の青い円と同じ大きさ）と ID、その下に滑走路の番号（RW を外した「26R」）、円から滑走路に沿って、選んだ閾値の端の向きへ線（推定：図の線は 22L の進入側に延びて見える）。10〜40 NM は滑走路を縮尺どおり（長さ 4 px ごとの 40 コマの画像、両側の線の間は 8 px：推定）、両端から 14.2 NM の破線（12 px・間 10 px：推定）、閾値に番号。滑走路が分からない（CIFP が無い）ときは 10〜40 NM でも空港の記号（推定）。破線は 1 本ずつ地図の見える所（5c-2b の POS の線と同じモデル：拡大は 465 px の弧と左右 329・348 px、機体の後ろは無し。MAP CTR は地図の記号の 250 単位＝182 px、PLAN は 450 単位＝327 px の円）だけに出し、滑走路の輪郭は中点が、番号は閾値が見える所にあるときに出す。これで、10 NM の範囲で進入中、滑走路がまだ範囲の外でも、こちらへ延びる中心線が見える。
- 出発・到着空港と滑走路の経路の点（星と ID）と、ARPT の青い記号は出さない（推定：前は経路の点として星と ID が出ていた）。経路の点は MAP・MAP CTR・PLAN だけにした（前は VOR でも出ていた：VOR では X-Plane の地図のモードが MAP のまま）。
- 向き：地図の記号の向きを 1 つの関数 `nd_bearing` にまとめた。毎フレームの更新（`updateIcon`）が、副操縦士の ND にも機長の航跡を、VOR・APP では真方位を使っていた（0.2 秒ごとの `makeIcon` は段 5a で席ごとにしてあった）のを、席ごとの航跡・方位にそろえた。
- パネル（道具 `docs/overhaul/tools/panel_nd_airports.lua`、画像 `make_nd_apt_images.ps1`、ACF_DIFF.md §5）：地図の記号のグループの最後に、空港ごとに「空港の記号」「滑走路」「閾値の番号」の 3 組を、地図の記号と同じく機体の点から回して、出して、戻す。滑走路の中点は地図の外にあり得るので、距離の移動は 2,560 単位（範囲の 4 倍）まで。新設 `nd/<席>/apt/*`（init `B747.61.nd`、INTERFACES.tsv）。
- 残り：MAP CTR の縮尺（地図の記号は拡大と同じ 465 px/範囲で、全周のローズ（約 230 px）と合っていないように見える。資料に明記が無いので利用者に確かめる）、手動同調の局のコースの線（5c-3c）、遠くの空港・局（XTLua の一覧の作り方）、FMC の RUNWAY と DEPARTURES（6-1）。
- 試験：新しい `tests/displays/nd_airports_test.lua`（63 件：滑走路の番号と反対の番号、経路の両端と滑走路の見つけ方、CIFP の行、滑走路の中点・長さ・向き（ずらした閾値）、地図の見える所、破線の本数、ND のモジュールで 40 NM の滑走路と破線・番号、10 NM で滑走路が範囲の外でも破線、80 NM の空港の記号と線、ARPT の記号を出さないこと、MAP CTR、PLAN、VOR で出さないこと（経路の点も）、副操縦士の ND、CIFP が無いとき。架空の空港と CIFP の行で）。X-Plane のシナリオ `s70_nd_airports`（35 件合格：EDDM 26R の進入路の上、10 NM はこちらへ延びる破線だけ、40・20 NM と MAP CTR は 26R を縮尺どおりと番号・破線、80 NM は EDDM の空港記号と 26R・線、320 NM は EDDF と 25C、VOR では出さない、副操縦士の ND。ND と外観を撮った）。1 回目は経路を CDU の RTE と DEP ARR で入れようとして、読み直した直後の X-Plane の FMS（3 台の CDU が共有する CDU1）にたまったメッセージ（NO PROCEDURES、KEY NOT ACTIVE、INVALID ENTRY を CLR のたびに 1 つずつ出す）で ORIGIN の入力が弾かれ、経路が空のまま進んだ（22 件失敗）。ND の試験は CDU の道筋に頼らず、試験キットの経路の道具に、航法施設に無い ID をその名前つきの位置の点にする機能（X-Plane 12 の `XPLMSetFMSFlightPlanEntryLatLonWithId`：DEP ARR が入れる「RW26R」と同じ形）を足して入れた。

## 32. 段 5c-3c の実装（2026-10-26 朝：手動同調の VOR のコースの線）

- 資料：FCOM p.1145（VOR・DME/TACAN・VORTAC（B, G）、MAP・MAP CTR：手動で同調した局は、選んだコースとその反対を出す。図は局を通る破線と「070」「250」）、p.1304（NAV RADIO の CRS：自動同調では空白、手動で 3 桁のコースを入れる）。
- ND のモジュール（`B747.61.xt.nd.lua`、純粋なモジュール `B747.61.nd_data.lua` の `crs_line`・`crs_label`・`crs_text`）：VOR L・R（X-Plane の NAV3・NAV4）が CDU の NAV RADIO で手動同調（`laminar/B747/radio/tuningmodes` の 2・3 文字目が M）で、その局が航法施設の一覧にあるとき（同じ ID で機体に一番近いもの。1 秒ごとか ID が替わったときに探す）、MAP・MAP CTR で、局を通る CRS（受信機の OBS。機体の磁気偏差で真方位に：推定、局の偏差とは違い得る）の向きの緑の破線を地図の端まで両方向に、局から 50 px の所にコースと反対の数字を線に沿って読める向きに（POS の radial の文字と同じ）。色・破線（12 px・間 10 px）・数字の位置は推定。
- 破線は、線のうち機体に一番近い点を中心に両側 42 本（924 px：表示の対角）を置き、模様は局に合わせる（局から（m＋1/2）×22 px が破線の中央）。局が範囲の外でも、線が地図を横切れば破線が出る（数字は局の近くが地図の内にあるときだけ）。両席の ND に VOR L・R の両方（同調中の局の記号と同じ）。
- パネル（道具 `docs/overhaul/tools/panel_nd_crs.lua`、画像 `make_nd_crs_image.ps1`、ACF_DIFF.md §5）：地図の記号のグループの最後に、受信機ごとに「破線」（一番近い点で線の向きに回し、`phase` だけずらした 85 本）と「数字」（局の所で、コースと反対のそれぞれを `tbrg` で回して線の右か左に）の 2 組。新設 `nd/<席>/crs/*`（init `B747.61.nd`、INTERFACES.tsv）。
- 気づいたこと：FMC の NAV RADIO の CRS は、手動同調のあと入れる前でも X-Plane の OBS の値を出す（実機は「---」）。FMC の作り直し（6-2）で。
- 試験：新しい `tests/displays/nd_course_test.lua`（29 件：数字（360）、数字の向き、一番近い点と破線の本数・ずらし、範囲の外の線、ND のモジュールで自動同調では無し、手動の VOR L の線と 070・250、一番近い点、VOR R、範囲の外の局の線が地図を横切ること、MAP CTR、VOR で無し、副操縦士の ND、自動同調に戻すと消える）。X-Plane のシナリオ `s71_nd_vor_crs`（21 件合格：フランクフルトの南、自動同調のうちは線なし、NAV RAD で VOR L に FKS と CRS 070、MAP で FKS を通る線（表示の上で 077°）と 070・250、一番近い点の破線、MAP CTR、VOR で出さない、副操縦士の ND、VOR R（自動）は出さない、DEL で自動同調に戻すと消える。ND を撮った）。

## 33. 段 5d の実装（2026-10-26 朝：HDG REF）

- 資料：FCOM p.1046（HDG REF：TRUE は真北、NORM は磁北、ただし 82°N 以北（80°W〜130°W は 70°N 以北）と 82°S 以南（120°E〜160°E は 60°S 以南）は真北。PFD・ND・AFDS・FMC に効く。NORM のこの地域では AFDS の LNAV 以外のロールのモードに基準が無く、HDG SEL・HDG HOLD・LOC は働かない。HDG SEL のときに切り替えると HDG HOLD）、p.998（PFD：MAG、TRU は枠つき）、p.1110（ND：真北のまま 800 fpm を超えて 2,000 ft 降りると枠が琥珀になり 10 秒点滅、500 fpm を超えて 2,000 ft 上がると白に戻る）、p.1141–1142（ND の MAG／TRU。枠は PLAN 以外、TRU から MAG に戻すと MAG に 10 秒の枠。風の向きも基準に従う）、ATA34_2 p.336（IRU は真方位を求め、偏差の表で磁方位も出す）、ATA22 p.352（HDG SEL で HDG REF が変わると HDG HOLD）・p.358（方位のモードは選んだ基準の方位と MCP の方位の差）、ATA34_2 p.477・p.482（スイッチは FMC と CDU にも）。
- モデル（新しい純粋なモジュール `B747.60.hdg_ref_model.lua`）と表示のグルー（`B747.60.xt.displays.lua`）：スイッチ（`laminar/B747/toggle_switch/position[30]`、1 が TRUE）か極地域で真北。新設 `efis/hdg_ref/true`、PFD のラベル `pfd_label`（MAG／枠つきの TRU）、ND のラベル `nd_label`（MAG／白枠の TRU／琥珀の枠の TRU／枠の消えた TRU（点滅の間）／白枠の MAG）、PLN の `nd_plan_label`（枠なし）、両席の方位・航跡を基準で（`pfd/<席>/hdg_deg`・`trk_deg`：各席の AHRS の磁方位・磁航跡を、TRU では飛行モデルの真方位と磁方位の差で真方位に）。降下は「800 fpm を超える降下が続く間に 2,000 ft」（推定）、上昇も同じ考え、点滅は 2 Hz（推定）、高度は機長の ADC、V/S は X-Plane の機長の V/S（推定）。
- パネル（道具 `docs/overhaul/tools/panel_hdg_ref.lua`、画像 `make_hdg_ref_images.ps1`、ACF_DIFF.md §5）：PFD のコンパスローズ・回転グループ・航跡の印、ND の方位・航跡の数字・方位の指針・航跡の線・回転グループを、X-Plane の磁方位・磁航跡から `hdg_deg`・`trk_deg` に付け替え（44 か所）、MAG のラベルを 5 コマ（ND）・2 コマ（PFD）の画像に。ND のローズの向き（ND のモジュールの `nd/up`）、ND のモデルの風の矢印、FMC のモジュールの風の数字も基準で。地図の記号の位置は真方位の幾何（`nd_bearing`）なので変わらない。
- AFDS（`B747.70.xt.autopilot.lua`）：MCP の方位は基準の方位なので、TRU では X-Plane の方位のモード（磁方位）へ偏差の分を直して渡す（`ap_hdg_target`：つまみ、HDG SEL の開始、毎フレームの同期の 6 か所）。HDG SEL のときにスイッチが動いたら X-Plane の HDG HOLD（`ap_hdg_ref_hold`）。
- 残り：NORM の極地域で HDG SEL・HDG HOLD・LOC を働かなくすること（AFDS の作り直し 6-3）、FMC の真方位（経路のコース。FMC は 73°N と 60°S で切り替える：ATA34_2 p.577。6-1）、TRU での VOR のコースの指針（磁方位のコースのまま）、LOC を捕まえたときに MCP の方位を LOC のコースにする所（磁方位のまま）。
- 試験：新しい `tests/displays/hdg_ref_test.lua`（31 件：極地域、基準の方位、白・琥珀・点滅・MAG の枠、表示のグルーの方位・航跡・ラベル・PLN・風の矢印、AFDS の目標と HDG HOLD）、ND の向きの試験（`nd_orientation_test.lua`）を基準の値の入力に直した。X-Plane のシナリオ `s72_hdg_ref`（19 件合格：フランクフルトの南 10,000 ft、NORM の MAG（表示の方位＝磁方位）、TRUE で表示の方位が磁方位より 4.0° 大きく、ND の白枠の TRU・PFD の枠つきの TRU、HDG SEL から HDG HOLD、TRU の HDG SEL で X-Plane の目標が MCP の 087 より 4.0° 小さい 083、V/S −1,500 fpm の 2,000 ft で琥珀の点滅（64 秒後）とその後の琥珀、NORM に戻して MAG の 10 秒の枠と HDG HOLD。PFD と ND を撮った）。

## 34. 段 5e の実装（2026-10-26 朝：ND の位置のトレンドベクトル）

- 資料：FCOM p.1147（位置のトレンドベクトル（白、破線）：MAP・MAP CTR。30・60・90 秒の終わりの位置の予測で、1 区間が 30 秒、傾きと対地速度から。範囲が 20 NM より大きいと 3 区間、20 NM は 2、10 NM は 1。図は機体の記号の頂点から曲がる 3 本の破線）。
- ND のモデル（`B747.60.nd_model.lua` の `trend`）：機体の記号の頂点から航跡の向きに、対地速度で 30 秒ずつの、傾きによる旋回（半径＝対地速度²÷（g・tan 傾き）：推定。資料は「傾きと対地速度から」だけ）の弧。各区間の 7 割を破線にし（推定：図の破線と隙間）、3 本の直線の小片で近似する。傾き 0.5° 未満は直線。MAP と MAP CTR で航跡が有効なとき。各席の傾き（AHRS）と X-Plane の対地速度。
- 表示のグルー：新設 `nd/<席>/tv_show`・`tv_x`・`tv_y`・`tv_rot`・`tv_frame`（各 9 片、init `B747.60.fltInst`）。パネル（道具 `docs/overhaul/tools/panel_nd_tv.lua`、画像 `make_nd_tv_image.ps1`、ACF_DIFF.md §5）：地図の記号のグループの最後に、小片ごとに表示、左右と上下の移動、回転、長さのコマ（1.5 px ごと 40）。
- FMC の記号のうち S/C・E/D・減速点、待機・PT、エネルギー円、FIX の基準点は FMC の作り直し（6-x）で（GAP DSP-23 の残り）。
- 試験：新しい `tests/displays/nd_trend_test.lua`（17 件：直進の位置と長さ、区間と隙間、範囲ごとの区間の数、右・左の旋回の弧と向き、MAP 以外・航跡なし・停止で無し、モデルとグルー）。X-Plane のシナリオ `s73_nd_trend`（15 件合格：フランクフルトの南 4,000 ft・220 kt、40 NM で 9 片、直進は真っすぐ上（3 区間目の終わり 54 px）、右旋回（傾き 25°）で最後の片が右に 41 px・向き 131°、20 NM は 2 区間、10 NM は 1 区間、VOR では出さない。ND を撮った）。

## 35. 段 6a の実装（2026-10-26 朝：時計）

- 資料：ATA31 p.64–80（31-25。電源は main hot battery bus が時刻の元で、APU battery bus の電圧で表示・出力・秒針のモーターの電源 B を許す。SET の RUN・HLD Y・MS M・HS D、DATE、ET、CHR とグレアシールドの CLOCK スイッチ（並列）。電源の復帰後は NCD：両 LCD が 00:00 のまま、秒針は 60、SET で UTC を 1 桁進めるまで。故障と電源断は LCD が消え秒針が止まる）、FCOM p.1057–1059（操作と表示）、p.1075（APU battery bus が無いと表示だけ消え、main hot battery bus が無いと全部止まり合わせ直しが要る）。
- 時計のモデル（新しい純粋なモジュール `B747.60.clock_model.lua`）：
  - 時刻は X-Plane の UTC に時計ごとのずれを足したもの（推定：X-Plane の時刻を変えると時計もついてくる）。時刻の表示で SET を HLD にすると秒を 0 にして止まり、MS・HS で 1 秒に 1 分・1 時間進み（その間も止まったまま：推定）、RUN でそこから動く。日付の表示中は HS D・MS M・HLD Y で日・月・年が 1 秒に 1 つ進む（時刻は動いたまま：推定）。どの欄もほかの欄に繰り上がらない（推定：59 分→00、23 時→00、月末→1、新しい月に無い日はその月の末日、99 年→00）。歩みは選択器を回してから 1 秒ごと（推定）。
  - DATE：日と月、次に年を 1 秒ずつ交互（コロンなし）、もう一度で UTC（前は年から始まった）。
  - ET：RUN で前の HLD・RESET から積算、HLD で止め、RESET（ばねで HLD）で 0 と空白、99:59 で止める（推定）。CHR の表示中も裏で動き、選択器も効く（前は CHR の間は効かなかった）。
  - CHR：押すごとに開始・保持・リセット。分は下の LCD の右 2 桁、秒は秒針（3D の `clock_chr_seconds`）、99:59 で止める（推定。前は 59:99 で止まった）。開始からリセットまで ET に代わって出る。
  - 電源：APU battery bus が無いと表示が消え（中は動く）、秒針はその位置で止まる。main hot battery bus が切れて戻ると NCD（両 LCD が 00:00 のまま、秒針 60）で、SET で UTC を 1 桁進めると解ける。NCD の間の日付は 2000 年 1 月 1 日、ET・CHR は進まず DATE・CHR は効かない（推定）。機体の読み込みのときに電源が無かったときは合わせ済みとみなす（推定）。
- グルー（`B747.60.xt.fltInst03.lua` を書き直した。副操縦士の複製の `fltInst04` は畳み込んで削除）：X-Plane の UTC（`sim/time/zulu_time_sec`、`clock_timer/zulu_day`・`zulu_month`。年はコンピューターの年で、X-Plane の 12 月から 1 月で次の年）、ET・CHR は X-Plane の飛行時間（`sim/time/total_flight_time_sec`）で進める。新設 `fltInst/<席>/clock_on`・`clock_utc_hours`・`clock_utc_minutes`・`clock_day`・`clock_month`・`clock_et_show`（init `B747.60.fltInst`）。今までの dataref とコマンドの名前と意味はそのまま。ET の選択器のコマンドは文字盤の並び（RUN・HLD・RESET）どおり、上で RUN の方へ、HLD から下で RESET（前は上で HLD→RUN→RESET と RUN を通った。3D のつまみの角度もこの並び）。グレアシールドの CLOCK スイッチの動きの dataref（`glareshiled/<席>/chrono_switch_pos`、3D の綴り）を init で作った。3D の 2 つのボタンは同じコマンドなので一緒に動く。新しいフライトで時計を X-Plane の UTC に合わせ直し、ET と CHR を 0 にする。
- 気づいたこと：XTLua は一度きりのコマンド（つまみのクリック＝X-Plane の CommandOnce、Web API の duration 0）の終わり（phase 2）を始め（phase 0）より先に流すか落とす（`s74` の 1 回目で DATE・CHR のボタンが押されたまま、ET の RESET が戻らなかった）。押しボタンと RESET は始めから 0.2 秒で自分で戻す（押し続ける間の phase 1 で延ばし、あとから来た終わりではすぐ戻す）。
- fltInst02 の死んだ時計のコード（コメントアウトされた古い dataref・コマンド・タイマー、使われない X-Plane の時計の dataref 5 個と `timer_is_GMT` のコマンド。約 490 行）を消し、静的試験の既知の一覧から時計の dataref 40 個とコマンド 14 個、グレアシールドの dataref 2 個を外した。
- パネル（道具 `docs/overhaul/tools/panel_clocks.lua`、ACF_DIFF.md §5）：UTC と日付を時計自身の値に（前は X-Plane の zulu の時・分と、その地の日付）、両方の LCD の数字を `clock_on` の新しいグループに、ET の数字の SHOW を `clock_et_show` 1 つに（前は 2 つで後の `clock_et_seconds > 0` が勝ち、CHR の下に ET が重なった）。
- FMC への時刻・日付（GPS が無いとき機長の時計、その故障で副操縦士の時計：ATA31 p.77）は FMC の作り直しで（FMC は X-Plane の時刻のまま）。
- 試験：新しい `tests/displays/clock_test.lua`（68 件：暦、UTC、DATE の交互、SET の HLD・MS・HS と繰り上がらないこと、日付の HS D・MS M・HLD Y、ET、CHR、電源と NCD、グルーのコマンド、終わりが先に来る一度きりのコマンド）。X-Plane のシナリオ `s74_clock`（45 件合格：成田 34L に電源の無い状態で開始、BATTERY OFF で両席の時計の表示が消え（main hot battery bus はある）、ON で X-Plane の UTC（01:00）と UTC の日付（23 10）・年 26、DATE で日と月、1 秒後に年、ET の RUN で 00:00、CHR で ET に代わって秒針が進み、2 回目で止まり、3 回目でリセットして裏で進んでいた ET が出る、グレアシールドのボタンも動く、ET の HLD で止まり RESET で 0 と空白、ばねで HLD に戻る、SET の HLD・MS で 1 秒に 1 分、副操縦士の時計は別。時計と外観を撮った。1 回目は開始で BATTERY がすでに ON だったこと（試験の誤り）と、一度きりのコマンドで DATE・CHR のボタンと ET の RESET が戻らなかったこと（XTLua の扱い：気づいたこと）、2 回目は DATE のボタンを戻る前に確かめたこと（試験の誤り）で落ちた）。

## 36. 段 6b の計画と段 6b-1 の実装（2026-10-26 朝：EICAS の部分表示と逸脱の印）

- 下調べ：段 6 の残りのうち DSP-25（STATUS のメッセージの行とページ）と DSP-26（CAS の 10 ページ）は警報 1-3 の WARN-17・WARN-09 で済んでいた（カスタム acf。GAP は純正 acf を見ていた）。DSP-06（OVERSPEED を Vmo/Mmo だけで）は 5-1 段 1 の NAV-02 で済。残りは DSP-24（＝エンジンの ENG-22）で、空中の CUTOFF での自動表示は燃料 2-2（ENG-23）で済んでいた。DSP-19（TERR）は外部のプラグイン頼みのまま。
- 段 6b を 2 つに分ける：6b-1 は部分表示・逸脱の印・電源投入時の自動表示（Lua と小さなパネルの変更）、6b-2 は主 EICAS の compact の形（一次エンジン表示そのものの作り替えで、パネルの大きな作業）。
- 資料：FCOM p.839–840（二次エンジンの逸脱の印：水色の VVVVVV、STATUS の印と同じ欄でそれに代わる）、p.849（VIB の high band が自動表示の値）、p.852–854（部分表示：N2 は運用限界、OIL P・T・Q は注意域か運用限界か、CF6 は油量の low と differential、VIB は high band）、p.855–857（compact の形）、p.872（電源投入時と空中の CUTOFF で自動表示）、p.874–875（部分表示と compact の規則、正常域に戻るまで残る）。
- エンジン側（`B747.40.engine_display_model.lua`）：どれかのエンジンの逸脱を 3 群で出す（N2：N2 が赤線、RB211 は N3 も。油：油圧が赤線か CF6 の琥珀の帯、油温が琥珀の帯より上、油量が magenta。VIB：high band 4.0 units（CF6 は ATA70_80 p.395、P&W と RB211 は資料が無く同じ値：推定））。グルーが新設 `engines/sec_exceed[3]`（init `B747.40.engines`）に書く。
- EICAS の形式のモデル（新しい純粋なモジュール `B747.60.eicas_format_model.lua`）：
  - ENG を選んでいれば二次 EICAS に二次エンジンの全表示。選んでいないとき逸脱があれば、その群の行だけの部分表示（FF は出ない）。ENG で全表示、もう一度で部分表示（今の ENG の切り替えのままで成り立つ）。
  - 逸脱の印：逸脱がある間（全表示のときも）。
  - ほかの二次表示（STAT・FUEL など）を選んでいて逸脱があれば、部分表示は主 EICAS の compact へ（`eicas/compact` = 2）。二次 EICAS を出す表示器が無い（表示器 1 台）ときは、ENG で compact の全表示（= 1）、逸脱で compact の部分表示（= 2）。
  - 電源投入時の自動表示：主 EICAS が表示器に出てきたとき（推定：「表示器が初めて電源を得たとき」をこう読んだ）に ENG を選ぶ。前は新しいフライトのときだけ。
  - STATUS の印が出ていて部分表示が出ていないときの STAT（FCOM p.875）は、ほかの二次表示の規則で compact に出るので、別には作らない。
- グルー（`B747.60.xt.displays.lua`）：選んだ二次表示（`dsp/synoptic_display`）、`engines/sec_exceed`、表示器のモデルの主・二次 EICAS の表示器を入れ、新設 `eicas/sec_eng`・`sec_rows[4]`（N2・FF・油・VIB）・`compact`・`cmp_rows[4]`・`exceed_cue`・`exceed_cue_text`（"VVVVVV"。init `B747.60.fltInst`）を出す。電源投入時は `dsp/synoptic_display` に ENG を書く。
- パネル（道具 `docs/overhaul/tools/panel_eicas_partial.lua`、ACF_DIFF.md §5）：二次 EICAS の ENG のページを `eicas/sec_eng` で出し（前は `dsp/synoptic_display` = 1）、N2（P&W・GE・RB211）・FF・油（P・T・Q）・VIB の群をそれぞれ新しいグループ（`eicas/sec_rows[0..3]`）に入れた。主 EICAS の STATUS の印を `eicas/exceed_cue` のときは隠し、同じ場所に逸脱の印（`eicas/exceed_cue_text`）を足した。
- compact の形のパネル（主 EICAS の EPR・N1・EGT の作り替えと、二次の行の数字）は段 6b-2 で。それまで `eicas/compact` と `cmp_rows` は値だけ。
- 試験：新しい `tests/displays/eicas_format_test.lua`（27 件：電源投入時の ENG、全表示、部分表示の行、ENG の切り替え、ほかの表示での compact、表示器 1 台、グルーのコマンドと表示器の故障）、エンジンの表示モデルの試験に 7 件、グルーの試験に 1 件。X-Plane のシナリオ `s75_eicas_partial`（25 件合格：成田 34L にエンジン運転中で開始、開始で二次 EICAS に二次エンジンの全表示、ENG で消え、2 番の油ポンプの故障で油圧が赤線を割ると 0.6 秒で油の行（OIL P・T・Q）だけの部分表示と主 EICAS の水色の VVVVVV、ENG で全表示（印は残る）、もう一度で部分表示、FUEL で二次 EICAS は FUEL のページになり compact の判定（部分表示、油の行）、もう一度 FUEL で部分表示が戻り、故障を戻すと部分表示と印が消える。上下の EICAS と外観を撮った）。

## 37. 段 6b-2 の実装（2026-10-26 朝：主 EICAS の compact の形）

- 資料：FCOM p.855–857（compact の形の図：109・405 は EPR を数字とテープ、N1・EGT は数字だけ、570 は N1 を数字とテープ、EGT は数字。その下に N2・FF・OIL P・OIL T・OIL Q・VIB の数字。部分の compact はその行だけ）、p.874–875（いつ compact か）。
- パネルだけの変更（Lua は段 6b-1 の `eicas/compact`・`cmp_rows` のまま。道具 `docs/overhaul/tools/panel_eicas_compact.lua`、画像 `make_eicas_cmp_images.ps1`、ACF_DIFF.md §5）：
  - compact のとき、通常の見出し（EPR・N1・EGT の背景）、P&W と RB211 の N1 のテープ、EGT のテープを隠し、P&W と RB211 の EGT の数字と枠を N1 の数字の下へ 108 px 上げる。
  - 新しい `GROUP Compact`：見出しを箱の行に（P&W：EPR はそのまま、N1 と EGT は数字の行。CF6：N1 はそのまま、EGT は数字の行。見出しの画像は背景から切り出した）、EGT の数字の下に二次の行（N2、FF（P&W と CF6、RB211）、OIL P、OIL T、OIL Q、VIB と振動源）。二次エンジンのページの数字の部品を主 EICAS の列に写し、色の部品と条件はそのまま、見出しは二次のページの画像。CF6 は行ごとに p.855 の位置へ（EGT の数字の下。N2 は −34、FF は −37、油は −23.5、VIB は −23 px：推力の基準が N1 のとき動かすグループ）。
  - 位置は FCOM の図の行の間隔を、列の間隔の比（パネル 0.806 px／図 1 px）で写した。P&W は p.856、CF6 は p.855（推定：図の比で）。RB211 は資料が無く P&W と同じ形で、N3 は出さない（推定）。
  - 写した部品の明るさは主 EICAS のつまみ（`LIGHT_RHEOSTAT 9`）にした。二次のページのつまみ（10）のままでは、下の表示器が故障したとき（compact が要るとき）に暗くなった（`s76` の 1 回目）。
  - 写した部品のうち SHOW を 2 本持つもの（白の油圧・油温：パネルの部品は最後の SHOW しか見ない）は、前の SHOW を外側のグループに分けて、両方が成り立つときに出るようにした（同じ dataref の上限と下限は X-Plane が範囲として扱うので、そのままでもよいが同じ形にした）。元のパネルで SHOW を 2 本以上持つ部品とグループは 308 個（EICAS と PFD）で、そのうち別々の dataref の条件が 116 個（最後の 1 本しか効かない）、名前の無い dataref（`[3]` だけ）の条件を含むものが 68 個、同じ dataref の範囲が 124 個。二次エンジンのページでは、2 番の油圧が赤のとき白の数字も重なって出ていた。別の段でまとめて直す（PROGRESS.md 気づいたこと）。
- 試験：Lua の変更なし（全 89 本合格のまま）。X-Plane のシナリオ `s76_eicas_compact`・`s77_eicas_compact_ge`（`s76_eicas_compact` 18 件合格（PW）：下の表示器の故障で ENG の選択のまま主 EICAS が compact の全表示（EPR の数字とテープ、N1・EGT の枠、N2・FF・油・VIB の行と見出し）、ENG で通常の形、2 番の油ポンプの故障で compact の部分表示（油の行、2 番の油圧は赤だけ）、表示器を戻して FUEL のまま逸脱で compact の部分表示。`s77_eicas_compact_ge` 7 件合格（Saudia のリバリーで CF6）：N1 の数字とテープのまま EGT の枠の下に二次の行、部分表示も。1 回目の `s76` は写した数字の明るさが二次のページのつまみのままで表示器 1 台のとき薄く、1 回目の `s77` は読み直しで STANDBY POWER が OFF のまま主 EICAS が下の表示器に出ていて、2 回目の `s77` は CF6 の行を一律 30 px 下げたため VIB の行が気圧の欄に重なった（どれも直した）。主 EICAS と外観を撮った）。

## 38. 段 7 の実装（2026-10-26 朝：パネルの SHOW の条件の重なり）

- 背景：パネルの部品とグループは 1 つの dataref の条件しか見ない（EQUAL か、LESS と GREATER の範囲）。別々の dataref の SHOW を並べると最後の 1 本だけが効く（2026-10-25 に PFD の高度の枠で分かった）。段 6b-2 の作業で、カスタム acf に SHOW を 2 本以上持つ部品とグループが 308 個あると分かった（同じ dataref の範囲 124、別々の dataref の条件 116、名前の無い dataref（`[3]` だけ）の条件を含むもの 68。EICAS 上 108・下 114、PFD 78、ND 8）。
- 直し方（道具 `docs/overhaul/tools/panel_show_and.lua`、ACF_DIFF.md §5）：
  - 名前の無い dataref の条件 128 行を消した。何も決めていない（二つとも名前の無い STAT ページの数字が出ている、1 本だけのテープも出ている）。
  - 意味の無い条件 2 行を消した：副操縦士の PFD の作動中の FLARE の `SHOW_LESS 0 laminar/B747/CAS/caution_status`（配列の添字が無い。機長の方はピッチのモードだけ）。そのまま「かつ」にすると FLARE が出なくなる。
  - 別々の dataref の条件が残る 114 か所は、すべてが成り立つときに出るようにした（作った人の意図）：最後の dataref の条件を部品に残し、ほかはそれぞれ外側のグループに（130 グループ）。主なもの：主 EICAS の推力の基準の線（REF と magenta の REF：逆推力でないとき）と目標の数字、EGT の枠と白の数字（白・琥珀・赤の重なり）、Thrust Command、着陸高度の負号；二次エンジンのページの油圧の数字と針（赤のとき白も出ていた）、振動の音源の文字（振動があるとき）；ECS のページのパックの A・B（弁が開のとき。3-1 で私が足したもの）；PFD の NO V SPD（電波高度 10 ft 未満かつ V1 = 999。Lua は空中で V1 を 998 にして避けていた：FCOM p.972）；ND の範囲の数字（MAP で CTR でないとき）、VNAV の経路の偏位（降下点の後）。
  - 同じ dataref の範囲（124）はそのまま。うち `<= DH`（`radio_alt/display_status` の「< 0 かつ > 1」）のように範囲として成り立たないものもあるが、X-Plane の扱いが分からないので触らない。
- 試験：Lua の変更なし。X-Plane のシナリオ `s78_panel_show`（10 件合格、警告 1：銚子沖の空中で、PFD に NO V SPD は出ない（V1 は Lua の回避で 998 なので警告：見た目は前と同じ）、ND の範囲の数字は MAP で出て MAP CTR では出ない、上の EICAS は通常どおり、ECS のページのパックは弁が開で A、パック 1 を OFF にすると OFF だけ（前は A も重なった）。PFD・ND・EICAS と外観を撮った）。
