# 109 で作ってきた部分と 405 の違い（2026-10-27 の棚卸し）

2026-10-27、利用者の決定で、P&W の機体は FCOM の有効番号 405、GE は 570 として作ることになった（RR は資料が無いので P&W と同じ：推定）。それまでの作り直しは「機体は 109、405・570 の項目は `laminar/B747/freighter` が 1 のときだけ」としていた（PLAN.md、PROGRESS.md、DIFFERENCES.md）。コードで 109 と 405 を分けているのは engine_start.lua、eec_model.lua、fuel.lua、fltCtrls.lua の 4 か所で、どれも `freighter` を見ている。

このファイルは、109 で作った部分のうち 405 では違うものの一覧。ND の向き（全モードで方位が上）は 2026-10-27 に 405 にした（notes/ATA-31.md §39）。AFDS の段 1d の G/S は 405 の規則（LOC の捕捉の後：FCOM p.670）で作る。**ほかをどこまで 405 にするかは利用者に確認中。**

FCOM のページは `p.` で書く。見え方：Y は乗員に見える、v は小さい。(?) は確かでないもの。棚卸しはエージェントに任せたもので、FCOM の 405 の記述は各行で確かめてあるが、作り替えるときに改めて資料を読む。

| ATA | 今（109） | 405 では（FCOM） | 場所 | 見え方 |
|---|---|---|---|---|
| 21 | 空調：温度区画 7、PASS TEMP、再循環ファン、synoptic | 区画 6（主デッキの前・後と床下を含む）、FLT DECK FAN、主デッキと床下の温度選択（p.561, 588） | ATA-21 §3、B747.55.* | Y |
| 21/26 | 貨物室火災の ARM：パック 3 停止、パック 1・2 を高流量、ファンを全部停止 | パック 2 台停止、トリム空気の主弁を閉（p.908–909） | pack_model.lua | Y |
| 22 | 段 1d の計画：G/S は LOC の前でも捕捉 | LOC の捕捉まで G/S を待つ（p.670）。前のコードは 405 どおり | ATA-22 §10, §13 | Y |
| 22-AT | 計画：CLB 1/2 を減格の % で選び、30,000/35,000 ft までに戻す | TO 1→CLB 1、TO 2→CLB 2、15,000 ft までに戻す（p.1273, 1315）。前のコードの 15,000 ft は ATHR-05 として誤り扱いにしていた | ATA-22-AT、FCTM.md | Y |
| 限界 | 試験の計画：追い風の限界 15 kt（離陸・着陸・autoland） | 10 kt（p.77, 80） | FCTM.md | ― |
| 23（未作成） | PCP の客室インターホン、SERV INT、データリンクなし | CALL パネル、貨物インターホン、VOICE RECORDER と ANR のスイッチ、8.33 kHz、他の RTP が OFF のときも offside 灯、ATC データリンク（p.686–725） | ATA-23 §1–3 | Y |
| 24 | ELEC GEN OFF は advisory | caution で beeper（p.822） | elec_buses.lua | Y |
| 24 | standby バス 2 本（main、APU）、>STBY BUS のメッセージ、機長の PFD・ND は APU standby バス | standby バス 1 本、APU の代替電源のインバーター、ALTN EFIS の選択器、>STBY POWER OFF（p.780–786, 800, 803–806, 823） | elec_model.lua、elec_buses.lua、display_model.lua | Y |
| 24 | ギャレーのバス、カスタムの ELEC synoptic に GALLEY | utility バスだけと、主デッキの貨物の荷役のバス（p.795–802） | elec_model.lua | Y |
| 26 | 床下貨物室：ボトル A–D、A/B はすぐ・C/D は 30 分後、195 分 | ボトル 6 本：2 本はすぐ、4 本は遅れか接地で、334 分（p.909, 918） | 火災のモデル、ATA-26 §11 | Y |
| 26 | 主デッキの火災の系統なし | MAIN ARM、DEPRESS/DISCH、FIRE MAIN DECK、弁の試験（p.908, 922–924） | FIRE-19 | Y |
| 26 | >CARGO DET AIR、SMOKE DR 5 REST、>SMOKE LAVATORY を作った | 405 には無い（p.921–923） | ATA-26 §11 | Y |
| 27 | 舵面の位置は STAT のページ | ENG のページ（p.938） | ACF_DIFF.md | Y |
| 28 | 水平安定板タンク（HST）とメッセージ 3 つ（貨物機以外） | HST なし（p.1453, 1456） | fuel.lua、fuel_model.lua | Y |
| 28 | 中央タンクのスカベンジはジェットポンプ、メッセージなし | 電動ポンプ 1 台、>SCAV PUMP ON（p.1454, 1479） | fuel_model.lua | Y |
| 28 | APU の運転中：主タンク 2 AFT と 3 AFT のポンプ | 2 AFT だけ（p.867, 1465） | fuel_model.lua | v |
| 30 | 着氷検知器：>ICING、>NO ICING、>ICE DETECTORS。>ANTI-ICE は「氷なし」が要る | 検知器なし。>ANTI-ICE は防氷が入っていて TAT が 12 ℃ より上（p.631, 635） | antiice_model.lua | Y |
| 31 | OVERSPEED のサイレンを止められない（SB 前の 109） | master リセットで止まる（p.1532, 1551） | alert_model.lua | Y |
| 31 | 離陸の master CAUTION の抑止は 400 ft か 20 秒まで | 800 ft か、回転から 30 秒（p.1591） | alert_model.lua | Y |
| 31 | PILOT RESPONSE なし | ある（p.1559, 1606） | WARN-20 | Y |
| 31 | 空中の CONFIG SPOILERS は貨物機だけ | 405 はいつも（p.1558） | fltCtrls.lua | Y |
| 31 | ND の MAP と MAP CTR は航跡が上、TRK | **済（2026-10-27）**：全モードで方位が上、HDG（p.1038, 1109, 1141） | nd_model.lua、xt.nd.lua | Y |
| 31 | ND は GS だけ | GS と TAS（p.1141。570 も） | fms.lua | Y |
| 31 | ND の範囲 10–640 NM | 5–640 NM（p.1038）。3D のつまみは確かめていない | ATA-31 §3.1 | Y |
| 31 | PFD は 109 の DH/MDA | RADIO/BARO の minimums（p.981–982, 994） | DIFFERENCES.md | Y |
| 31 | CDU の EFIS CONTROL：DH SET / MDA SET | RAD/BARO SEL、MINS SET（p.1063–1064） | efisctl.lua | Y |
| 31 | PLI はフラップが出ているときだけ | フラップ上げの低速でも（p.975） | minspeed_model.lua | Y |
| 31 | 拡大の LOC の目盛はいつも | A/P の進入の間だけ（p.988） | pfd_ils_model.lua | Y |
| 31 | QFE なし | QFE/QNH（p.995, 1412） | PROGRESS.md | Y |
| 31 | 時計は時と分 | 10 分の 1 分まで（p.1058） | 時計のモデル | v |
| 32 | タイヤ圧、>TIRE PRESSURE | なし。TILT・ANTISKID・LIMITER のメッセージ（p.1507–1510, 1522） | ATA-32 §14 | Y |
| 33/35 | 乗客と治療用の酸素、PASS OXYGEN ON、THERAP OXYGEN ON | 補助席の酸素、SUPRNMRY OXY ON（p.437, 502, 547） | 酸素のモデル | Y |
| 33 | サインの memo | p.547 は 109 だけ、p.502 は 109 と 405（?） | 前のコード | Y |
| 34 | RMI は X-Plane のジャイロ | 副操縦士の IRS の選択の方位、HDG REF（p.1044, 1046, 1075） | NAV-15 | Y |
| 34 | 先読みの地形・予測ウインドシア（PWS）なし | 405 にはどちらもある（p.83, 1221） | ATA-34 §14 | Y |
| FMC | PERF INIT の GR WT | 重量重心の系統（WBS）：GR WT ADV と `<`（p.1307–1312） | FMC §13 | Y |
| FMC | TAKEOFF REF：乗員が CG を入れ、FMC がトリムを出す | WBS の CG を小さい字と caret で、トリムはグリーンバンドの中だけ（p.1320） | fms.pages.lua | Y |
| FMC | データリンクは KEY/FUNCTION INOP の計画 | データリンクと ATC MESSAGE が働く（p.725, 1211） | CDU-32 | Y |
| FMC | >FMC RUNWAY DIS なし | caution（p.1429） | EICAS-MSG | Y |
| FMC | ZFW の入力は 270 t まで、試験は 109 の重量 | 最大着陸重量 295,742 kg、最大無燃料重量 276,691 kg（p.78） | FMC §13、FCTM.md | v |
| 52（未作成） | 109 の扉と DRS の synoptic の絵 | L1/L5、側面貨物扉、F/D の天井ハッチ（p.467–468, 546） | ATA-52 §2 | Y |
| 70–80 | 貨物機以外はオートスタート（メッセージ、点火の交互、再点火） | オートスタートなし（p.861–864, 899） | engine_start.lua、engine_start_model.lua | Y |
| 70–80 | CON IGNITION で進入アイドルは GE か貨物機だけ | CON で進入アイドル（p.863, 878） | eec_model.lua | Y |
| 70–80 | 「ENG n REVERSER」（SB 前の 109 の文言） | 「>ENG n REVERSER」（p.901）（?） | xt.reverser.lua | v |
| 70–80 | >EEC TEST PWR なし | advisory（p.899） | ENG-36 | v |

405 に替えたら見直すもの：

- コードの頭の「airplane 109」：elec_model.lua、alert_model.lua、fuel_model.lua、engine_start_model.lua。
- 109 の挙動を確かめている X-Plane のシナリオ：s08、s09、s18、s20、s21、s23、s32、s40、s56、s61（済）、s65、s69、s83。

もう 405 のもの（変えなくてよい）：GPWS のコールアウトと BANK ANGLE、G/S INHIBIT 灯なし、TCAS Ver 7.0（p.1553）、HYD の synoptic の不作動の表示（405 だけの機能、p.1490）。

純正は 405 どおりだったのに 109 に変えたもの：GEN OFF の caution、ND の TAS、PERF INIT の GR WT ADV、EFIS OPTIONS の TERR/TFC（(?) FCOM は CDU-152/161 の並びを 109/405 ではなく CDU の型に結びつけている）。

どちらでもないもの：PFD の TCAS の昇降率の帯は 570 だけ（p.1537）だが、全部の型式で出している。

3D コクピット（参考）：

- 109 のもの：貨物室火災のパネルは FWD/AFT だけ、STAB TNK のポンプのスイッチが天井パネルに、ECS のパネルに PASS TEMP と UPR/LWR RECIRC（(?) 109 に無い貨物室の温度つまみもある）、客室、パネルの絵（GEAR のタイヤ圧、GALLEY、109 の扉の名前）。
- 405 か 405/570 のもの：RMI（405 だけ）、TERR OVRD と G/S INHB・GND PROX の組の GND PROX パネル、RADIO/BARO MINS と TERR スイッチの EFIS パネル、貨物機の CALL パネル、純正の HYD の不作動の絵。
- 570 のもの：気象レーダーのパネル、トランスポンダのパネル、2 位置の AIR DATA つまみ（109 と 405 は L/C/R）、オートスタートのスイッチ 1 つ（109 は 4 つ、405 は無し）。
- 見つからなかったもの（?）：ALTN EFIS の選択器（INTERFACES.tsv に無い）、5 NM の範囲の位置、スタンバイ計器か ISFD か、GND PROX の OVRD 灯。
