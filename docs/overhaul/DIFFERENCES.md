# 実機との違い（DIFFERENCES）

Sparky744（この作業ツリーの機体）が、実機の 747-400 とどこで違うかを、全分野についてまとめたもの。2026-10-23 時点（`overhaul` の 4a22c9e8）。

- 元の調査は [GAP_ANALYSIS.md](GAP_ANALYSIS.md)（作り直し前のコードと資料の読み比べ、550 件）。ここでは、その後の作り直しで直った点を反映し、残っている違いを分野ごとに短く書いた。各項目の括弧は GAP の ID で、詳しい内容と出典は GAP_ANALYSIS.md と `notes/` にある。
- 基準の機体は FCOM の 109（旅客機、PW4056）。405（PW の改造貨物機）と 570（GE の貨物機）の違いは notes に書いてある。RR には資料が無い。
- 「推定」と書いたものは、資料に値や記載が無いので決めた部分（全部の一覧は [PROGRESS.md](PROGRESS.md) の「推定で作った部分」）。
- 作り直した分野は、X-Plane での試験（Web API と FlyWithLua の記録）まで済ませている。残っている違いの多くは、まだ作り直していない分野のもの。

## 1. 全体のまとめ

| 分野 | 状態 | 残っている主な違い |
|---|---|---|
| 電源（ATA 24） | 作り直し済み（1-1） | 保護トリップと故障、autoland のバス分離、いくつかの系統がまだ X-Plane の bus 0 で電源を見る |
| 空地判定（PSEU） | 作り直し済み（1-2） | 16 モジュールがまだ X-Plane の「どれか 1 輪接地」を読む（各系統の作り直しで乗り換え） |
| 乗員への警報 | 枠組みは作り直し済み（1-3） | 形態警報・高度警報・失速警報・GPWS の master WARNING など、各系統の警報の中身 |
| 油圧（ATA 29） | 作り直し済み（1-4） | 脚・ブレーキ・ステアリング・逆推力・トリムが 4 系統の圧で動かない |
| 空圧（ATA 36） | 作り直し済み（1-5） | 故障（過熱・過圧・ダクトリーク）がつながっていない、地上空気の操作が無い |
| APU（ATA 49） | 作り直し済み（2-1） | 始動電源と回数の制限、空中の運用範囲 |
| 燃料（ATA 28） | 作り直し済み（2-2） | FMC の燃料の計算、ポンプ・弁の故障、燃料温度、給油の配分 |
| エンジン（ATA 71〜80） | 未着手（2-3） | 推力の決め方、ALTN、autostart、点火、超過表示 |
| 空調・与圧・機器冷却（ATA 21） | 未着手 | パック弁、与圧スケジュール、温度制御、CPC A/B |
| 防氷・防雨（ATA 30） | 未着手 | 主翼防氷の左右、>ANTI-ICE、弁のメッセージ、プローブ加熱 |
| 酸素（ATA 35） | 未着手 | 乗客酸素と酸素圧が無い |
| 火災防護（ATA 26） | 未着手 | 検知ループ、APU・貨物室・車輪格納部の火災、試験の手順 |
| 操縦系統（ATA 27） | 未着手 | フラップの代替系統、安定板トリム、ラダートリム、自動スピードブレーキ |
| 脚・ブレーキ・ステアリング（ATA 32） | 未着手（空地判定だけ済） | オートブレーキ・ステアリング・脚の作動が X-Plane 任せ、代替下げが無い |
| 表示（PFD・ND・EICAS） | 未着手（電源と点灯の修正だけ） | ソース選択、速度テープの帯、DH、ND の DATA/POS・TCAS |
| 航法センサーと無線（ATA 34） | 未着手 | ADC 3 台、IRS のアライン、GPWS、TCAS、無線の自動同調 |
| FMC | 未着手 | 経路モデル、ホールド、LNAV・VNAV、予測 |
| CDU | 未着手 | 3 台が 1 つを共有、MOD/EXEC、入力の検査、データリンク |
| 自動操縦・FD | 未着手 | ロールが X-Plane の AP 頼み、LOC・TO/GA・autoland の則 |
| オートスロットル・推力管理 | 未着手 | 推力制限のモード、assumed temperature、THR・HOLD、操縦者の override |
| 通信（ATA 23） | 未着手 | VHF の電源、ACP の連動、VHF C と HF が無い |
| 照明（ATA 33） | 未着手（P5 の灯の入力は各系統で移し中） | 外部灯の電源、非常灯、毎フレームの完全 GC |
| ドア（ATA 52） | 未着手 | L1 と上部デッキ L 以外のドアが無い |

## 2. 分野ごとの違い

### 電源（ATA 24）：作り直し済み（1-1）

実機に合わせた点：バス単位のモデル（AC 1〜4、同期バス、SSB、transfer bus、standby、ground service・ground handling、DC 1〜4、バッテリー母線）、電源の切替（LH24 の表と FCOM）、GCB・BTB の許可、standby 電源、ELEC GEN OFF・ELEC AC BUS・ELEC BUS ISLN、DRIVE 灯と DRIVE DISC、ELCU の load shed（簡略）、バッテリーの表示と BAT DISCH、air mode。P5 の灯、EICAS、表示器と CDU の電源もモデルから。カスタム acf の ELEC synoptic（ISLN・DRIVE の枠）と STAT のバッテリー値。

残っている違い：
- 保護トリップ、3.5 秒の break power transfer、last source on が無い（ELEC-04）。故障の仕組みがまだ無い。
- 手動の SSB スイッチ・OPEN 灯、GEN FIELD MAN RESET・FIELD OFF 灯が無い（3D にも操作子が無い。ELEC-05・22）。
- 客室側の ground service switch が無い（ELEC-13）。
- autoland のバス分離が無い（ELEC-18。AFDS の作り直しで）。
- 故障で出る status（ELEC DRIVE、BAT CHARGER、ELEC TR UNIT、ELEC IDG VALVE）が無い（ELEC-23）。
- 外部電源は XP12 では X-Plane の GPU 電圧に依る（ELEC-17）。
- まだ X-Plane の bus 0 で電源を見る系統：機器冷却、IRS と無線、表示灯の輝度、客室灯、ヨーダンパー。
- synoptic の GALLEY を別の色にできない、STAT の CHG/DIS は背景に固定の "DIS" がある（どちらも新しい画像が要る。利用者に確認中）。純正 acf の STAT は X-Plane の値のまま。
- 推定：バッテリーの負荷電流と電圧の曲線、BAT DISCH までの 60 秒など。

### 空地判定（PSEU）：作り直し済み（1-2）

実機に合わせた点：主脚のトラックの傾きで左右とも接地したときに地上（片側だけなら空中）、pri・alt の 2 系統、前脚の圧縮。電源の air mode、脚レバーのロック、逆推力のロックアウト、燃料系はこれを使う。

残っている違い：
- autopilot、fms、計器、防氷、操縦系統、EEC、エンジン、油圧、オートブレーキ、manipulators、fdr、照明など 16 モジュールが、まだ X-Plane の「どれか 1 輪接地」（`onground_any`）を読む。各系統の作り直しで乗り換える。
- 推定：トラックの傾きは X-Plane の `eagle_claw_angle_deg` が 1° を超えたとき、前脚の圧縮は前輪の接地（X-Plane に傾きセンサーと strut の縮みが無い）。

### 乗員への警報（EICAS、警報音）：枠組みは作り直し済み（1-3）

実機に合わせた点：CANC/RCL（メッセージごとの CANC 済みの印）、サイレン・ベル・beeper が警報モデルから鳴る（`.snd` の結線）、caution ごとの beeper、抑止（始動前、始動中、離陸、着陸）、メッセージ表のレベルと文言を FCOM に、ページ割り（カスタム acf は 10 ページまで）、0.1 秒ごとの更新、STATUS メッセージと STATUS cue。

残っている違い：
- 他のメッセージによる抑止と時間遅れは、系統ごとにまだ（各系統の作り直しで足す）。
- FCOM にあって表に無いメッセージが約 30 件（WARN-08。各系統で）。
- 離陸形態警報が「エンジン 2 と 3 の両方」を要求する（FCOM は 2 か 3）。着陸形態警報（CONFIG GEAR）のレバーの判定も粗い（WARN-11・12）。
- SPEEDBRAKES EXT の条件式の誤り（WARN-13）、グリーンバンドの機能が無い（WARN-14）。
- OVERSPEED を Vmo/Mmo でなくフラップ・脚の制限込みの Vmax で出す（WARN-15）。
- ALTITUDE ALERT が無い（WARN-16）。
- 失速警報が AOA でなく速度の表で出る（WARN-18）。
- GPWS の PULL UP・WINDSHEAR で master WARNING が点かない（WARN-19）。
- PILOT RESPONSE、チャイムの論理、MAWEA の電源が無い（WARN-20〜22）。
- APU・貨物室・車輪格納部の火災のベルは、火災（3-4）で。
- 純正 acf のパネルは 2 ページまでしか描けない（PG も無い）。

### 油圧（ATA 29）：作り直し済み（1-4）

実機に合わせた点：EDP は圧力補償型、demand pump の AUTO（1400/1600 psi、タイマー、CUTOFF、系統 1・4 のフラップ）、ポンプの電源と抽気、AUX、火災スイッチ（SOV 閉・EDP 減圧・demand pump 起動）、舵面の系統の組の誤り 3 か所を修正、accumulator（系統 4 だけで充圧）、X-Plane の故障を書き換えない、P5 の灯、EICAS、作動油量（乱数をやめた）、リザーバの与圧と RSVR PRESS、STATUS、スタンドパイプ。カスタム acf の HYD synoptic のポンプ状態。

残っている違い：
- 脚・逆推力・ステアリング・安定板トリム・ヨーダンパーが、4 系統の圧で止まらない（HYD-11・12。それぞれの作り直しで、モデルの負荷の表を使う）。
- ブレーキの効きが油圧源で制限されない（源の選択と >BRAKE SOURCE は済。HYD-09 の残り、脚 4-2 で）。
- 油温に燃料の熱交換が無い（HYD-17）。
- synoptic の色付きの空の記号（ON 琥珀、AUX の待機）、琥珀の AUTO の幅、複数系統の不作動の絵（新しい画像が要る。HYD-19）。
- FLT CONTROL HYD POWER（系統ごとの遮断弁）が無い（HYD-22）。
- 推定：舵面が動く圧 1000 psi、漏れ量、圧の立ち上がり、油温の上がり方など。

### 空圧（ATA 36）：作り直し済み（1-5）

実機に合わせた点：需要と供給からのダクト圧（区画ごと）、エンジンの HPSOV・PRV・PRSOV、逆流防止、始動弁の条件（クロスブリードは供給側 70 % N2）、過熱ラッチとスイッチでのリセット、ISLN 弁の移動時間と VALVE 灯・BLEED ISLN（10 秒の不一致）、APU 弁（RUNNING ＋ 2 秒、OFF で閉）、ISLN の電源、STATUS の BLEED ASCTU。

残っている違い：
- 過熱・過圧・ダクトリークの故障がつながっていない（BLEED n、BLEED HP ENG、BLD DUCT LEAK。PNEU-03。X-Plane に相当する故障が無い）。
- 地上空気（エアカート）をつなぐ操作が無い（PNEU-07）。
- スターターの回り方がダクト圧に依らない（エンジン 2-3 で。PNEU-08）。
- 主 EICAS のダクト圧の表示条件と ECS synoptic の流れ（PNEU-09・11。空調 3-1 で）。
- GE の逆推力の抽気、EEC の抽気補正（PNEU-12・13。エンジン 2-3 で）。抽気による推力の損失は X-Plane の計算のまま。
- 推定：流量（パック 1 台＝1 の単位）、ダクト圧の下がり方、弁の時間など、式と値の多く。

### APU（ATA 49）：作り直し済み（2-1）

実機に合わせた点：1 つの状態機械、START→ON で始動を保持、ドア全開で starter、60 秒の cooldown（抽気弁と発電機は無負荷）、自動停止（火災、燃料切れ、始動の失敗）と fault の保持、APU・APU DOOR・APU RUNNING を FCOM の条件で、STATUS の N2・油量。

残っている違い：
- 始動電源と始動回数の制限が無い（APU-09）。
- 空中の運用範囲（高度）が無い（APU-10。資料が自動停止を書いていない）。
- 油の消費と RF/LO が無い（APU-02）。抽気ダクト過熱の停止は入力が無い。
- エンジン始動時の増風要求が無い（APU-12）。
- 回転と EGT は X-Plane の APU のまま。
- 推定：ドアの開く時間 12 秒、APU DOOR の 20 秒、始動の打ち切り 120 秒、N2 = N1 × 0.926 など。

### 燃料（ATA 28）：作り直し済み（2-2）

実機に合わせた点：
- タンク・ポンプ・弁の表、圧力の順位（CWT ポンプ 2 台 ＞ O/J 2・3 ＞ 主ポンプ。CWT ポンプ 1 台は主ポンプ 2 台に勝てない）。
- クロスフィードのマニフォールド（開いた xfeed を通して他の主タンクからも）と吸引供給（ポンプが止まってもエンジンは止まらず、FUEL PRESS ENG）。SP.12 の均衡手順が成り立つ。
- xfeed 2・3 の自動閉（地上でフラップ 10〜20 に 40 秒、空中はフラップがその範囲を出るまで保持）、O/J 2・3 の起動条件、予備タンクの移送（主 2 か 3 が 18,200 kg で 4 弁とも、空中だけ）、CWT のスカベンジ（ジェットポンプ）、水平安定板タンクの移送（109）、shared flow。
- ジェティソン（FTR で停止、主 2・3 の均衡、主 1・4 の移送、終了後の FUEL OVRD、時間の推定と 90 秒後の更新）。
- 弁はバスごとの電源で 4 秒かけて動き、電源が無いとその位置に留まる。不一致のメッセージ（FUEL X FEED、FUEL RES XFR、>JETT NOZZLE）。
- 頭上の灯（主ポンプの PRESS は低圧ならいつでも、CTR はスイッチ ON のとき、O/J と STAB は論理が動かしているとき、X FEED と NOZZLE の VALVE 灯）。EICAS の閾値を FCOM に。
- APU の DC 燃料ポンプと APU FUEL、spar valve が火災スイッチで閉じる、タンク容量を acf から、FUEL USED はエンジンの流量だけ。

残っている違い：
- 消費は X-Plane の燃料流量で、acf の燃費（SFC）がそのまま効く。カスタム acf の SFC は巡航の測定で約 25 % 少なかったので、純正と同じ値にした（FL350・269 t で 1 発 2,134 kg/h。FCOM PI.11.2 の長距離巡航は 260 t で 2,211、280 t で 2,378 kg/h）。離陸と上昇の燃料流量はまだ資料と比べていない（エンジン 2-3 で）。
- FMC の側：TOTALIZER と CALCULATED が同じ、FUEL DISAGREE が無い、FUEL USED がエンジン始動で消えない（FUEL-13。FMC で）。
- ポンプ・弁の故障が無い（FUEL-15）。FUEL TEMP SYS、>FUEL JETT A/B は無い。
- 燃料温度は TAT への一次遅れで、根拠が無い（FUEL-20）。
- 地上で 100 t を超えて始めたときの固定の配分と給油の順序は前のコードのまま（資料で確かめられない。FUEL-21）。
- synoptic：ポンプの琥珀はタンクが 10 kg 未満のとき、主タンクの琥珀は 900 kg 未満だけ（パネルの条件）、FTR は LBS 表示でも kg（FUEL-24）。
- 貨物機の設定では水平安定板タンクの論理を止めるが、タンク 7 の燃料と synoptic の絵は残る。
- エンジン運転中の開始では CTR ポンプのスイッチが ON になるので、CWT が空だと FUEL PRESS CTR が出る（開始時のスイッチの設定は manipulators の側）。
- 地上でポンプのスイッチが OFF のときに FUEL PUMP のメッセージを出すかは、資料に記載が無い（今は低圧なので出す）。
- 推定：重力移送・安定板タンクのポンプ・ジェティソンの流量、APU の消費 150 kg/h、ポンプの AC バスの割り当て、フラップの離陸範囲の換算、安定板ポンプが低圧で止まるまで 30 秒。

### エンジン（ATA 71〜80）：未着手（2-3）

- レバーと推力指令の関係が EEC と違う（GE は N1 にレバーを直線で、PW/RR は EPR を比例で。外気・高度・rating に依らない。ENG-01）。
- 最大 N1/EPR の琥珀線が EEC の max rated thrust でなく FMC の基準値（ENG-02）。推力の上限を acf の最大推力から作り、毎フレーム足している（ENG-03）。
- ALTN モード（制御量の切替、ALTN 灯、ENG EEC MODE など）が無い（ENG-05）。
- ENG FAIL が warning（FCOM は caution）（ENG-08）。
- autostart が無い（監視、no light-off・hot・hung の検出、再試行。ENG-12）。点火の AUTO・STBY が効かない（ENG-16・17）。
- approach idle の解除、LOW IDLE・IDLE DISAGREE が無い（ENG-06・07）。
- 超過の red box と cue、partial・compact 形式、空中始動の範囲（X-BLD）が無い（ENG-21・22・24）。
- 油圧・油温の限界が型式に依らない、油量と振動は作った値（ENG-25〜29）。
- 逆推力の展開・格納は X-Plane 任せで、油圧・抽気の条件が無い（ENG-31）。
- 表示の値は推力からの回帰式と比例換算（ENG-33）。スターターはダクト圧に依らず回る（ENG-38）。
- 試験で見つけたこと：1 番エンジンだけ始動が速い（両 acf）。始動中の燃料流量が負（燃料系では 0 として扱う）。

### 空調・与圧・機器冷却（ATA 21）：未着手（3-1）

- パック弁のモデルが無い（選択器は表示と音にだけ。AIR-01）。パックの流量スケジュールと保護、PACK のメッセージが無い（AIR-11・12）。
- 自動与圧のスケジュールが実機と別物（AIR-02）。着陸高度は固定 2,000 ft で FMC と連携しない（AIR-03）。手動モードと CABIN ALT AUTO の条件が違う（AIR-04・05）。
- CPC A/B、正負圧のリリーフ弁が無い（AIR-07・08）。外流弁の計器が客室の昇降率から作られている（AIR-09）。
- 温度制御が無い（AIR-10）。機器冷却が何にも効かない（AIR-13）。後方貨物室暖房が無い（AIR-14）。
- ECS synoptic の上半分（ゾーン温度、外流弁）が無い（パネル。AIR-15）。
- 貨物室火災のときの空調の組替え、ECS の status メッセージが無い（AIR-17・22）。
- X-Plane の与圧に値を書いている（AIR-20）。

### 防氷・防雨（ATA 30）：未着手（3-2）

- 主翼防氷を X-Plane の左右共通のコマンドで渡していて、左右の弁が食い違う（ICE-01）。WAI 弁の開く条件にダクト圧が入っている（ICE-02）。
- >ANTI-ICE が出ない（ICE-03）。NAI VALVE・WAI VALVE のメッセージが無い（ICE-04）。
- プローブ加熱：AOA・TAT のヒーターを X-Plane に渡していない。ピトー加熱はエンジンの抽気圧で「運転中」を判定するので、ENGINE BLEED を全部 OFF にすると切れる（ICE-06）。
- 窓加熱・氷検知のメッセージが無い（ICE-07・08）。ワイパーの速さ、ウォッシャー・防雨剤（ICE-09・10）。
- 防氷による推力の補正（ICE-11）。

### 酸素（ATA 35）：未着手

- 乗客酸素（自動作動、手動 ON、PASS OXYGEN ON）が無い（OXY-01）。
- 乗員・乗客の酸素圧と >CREW OXY LOW が無い。STATUS の OXY PR を出せない（OXY-02・03）。
- 酸素のスイッチと乗員マスクの操作が無い（OXY-04）。

### 火災防護（ATA 26）：未着手（3-4）

- 検知のモデル（loop A/B、故障の判定）が無く、X-Plane の火災表示の素通し（FIRE-01）。エンジンの過熱（OVHT ENG NAC）が無い（FIRE-02）。
- APU 火災の FIRE APU が出ない、APU の消火ハンドルが無い（FIRE-03・04）。
- 下部貨物室の火災系統が無い（FIRE-05）。車輪格納部の火災、主翼前縁・ストラットの過熱、化粧室の煙が無い（FIRE-14〜16）。
- FIRE/OVHT TEST の手順（TEST IN PROG → PASS/FAIL）が無い（FIRE-08）。消火スイッチのロックが無い（FIRE-09）。
- 消火の効果がボトルと無関係（FIRE-10）、ボトル低圧のメッセージの誤り（FIRE-11）、>ENG SHUTDOWN の条件（FIRE-12）。
- 消火スイッチの他系統への作用：燃料の spar valve・油圧の SOV・抽気は済。ほかは火災 3-4 で（FIRE-13）。
- 貨物機の主デッキの火災（FIRE-19）。

### 操縦系統（ATA 27）：未着手（4-1）

- フラップの制御（FCU）に secondary（電動）と代替系統が無い。油圧は指令が変わった瞬間しか見ない（FCTL-01・02）。
- 安定板トリムは X-Plane のコマンドで、速さが対気速度に依らない（FCTL-03）。ラダートリムが舵面に入らない見込み（FCTL-04）。
- エルロンのロックアウトとラダー比が直線（FCTL-05・06）。
- 自動スピードブレーキの着陸展開は X-Plane 任せ（FCTL-07）。SPEEDBRAKES EXT の条件（FCTL-08）。
- 横操縦の舵角の対応、グリーンバンド、フラップ表示の拡大・代替形式（FCTL-09・10・12）。
- ヨーダンパーの INOP の条件、speed stability trim（FCTL-15・16）。電源への依存が無い（FCTL-25）。

### 脚・ブレーキ・ステアリング（ATA 32）：未着手（4-2。空地判定だけ済）

- オートブレーキは X-Plane 任せで、レベルの減速度が 747 と違う（4 が MAX と同じ）。DISARM しても X-Plane に書かない（GEAR-02〜05・20）。
- 20 kt 未満のステアリングは X-Plane の acf の値（カスタム acf は 75°/35°、純正は FCOM と同じ 70°/7°。GEAR-06・07）。
- 脚レバーのロックが効かない（GEAR-08）。
- 脚の作動が 747 の油圧と無関係（X-Plane のハンドル 1 本と X-Plane の油圧。GEAR-09）。代替下げが無い（GEAR-10）。
- GEAR DISAGREE・GEAR DOOR・GEAR TILT のメッセージが無い（GEAR-11）。ブレーキの源による制限、ブレーキ温度、タイヤ圧、アンチスキッドのメッセージ（GEAR-12〜15）。
- GEAR synoptic のドアの箱（GEAR-18）。空中で開始すると脚レバーを UP に動かす（GEAR-23）。

### 表示（PFD・ND・EICAS）：未着手（電源と点灯の修正だけ）

- PFD の方位目盛りが ND の向きで回る（DSP-01）。
- ソースの選択（FLT DIR、NAV、EIU、AIR DATA、IRS）が無い（DSP-02・03）。PFD の故障旗が少ない（DSP-04）。
- 速度テープの帯（最大・最小機動速度）が違う、OVERSPEED を Vmax で出す、Vs の表の高度区分の誤りと誤記（DSP-05〜08）。
- DH RST が minimums を書き換える、DH の警報が機長側だけ（DSP-09・10）。STD と preselect（DSP-11）。FPV・PLI など PFD の記号が無い（DSP-12）。
- ND の DATA・POS が効かない（DSP-16）、TCAS の記号（DSP-18）、TERR は外部のプラグイン頼み（DSP-19）、HDG REF（DSP-20）。
- EICAS の compact・部分表示・二次エンジンの逸脱（DSP-24）、表示器と EIU の故障と自動切替（DSP-27）、表示選択の組み合わせ（DSP-28）。
- 時計の CHR の表示（DSP-33）。
- 直した点：表示器と CDU の電源（1-1）。同じ機体のまま新しいフライトを始めると表示器と CDU が真っ暗になる不具合（作り直し前から）を直した（2026-10-23）。

### 航法センサーと無線（ATA 34）：未着手

- ADC が 3 台として無く、AIR DATA 選択器が効かない（NAV-01）。IAS・ALT DISAGREE が無い（NAV-04）。
- OVERSPEED の条件の誤り、ALTITUDE ALERT が無い（NAV-02・03）。
- IRS：ALIGN で何も進まず NAV にしてから 600 秒、fast realignment が無い、位置入力を検査しない、ATT モードと電源のモデルが無い、メッセージが少ない（NAV-16〜21）。
- 無線：VOR の音声の経路、NAV RADIO の RADIAL が 180° 違う、自動同調が単純、ILS の自動同調を経路の形から推定（NAV-32〜39）。
- 電波高度計が 1 系統（NAV-51）。MINS RST が minimums を書き換える（NAV-52）。
- GPWS の mode 1〜5 の判定が無い、GND PROX のスイッチが効かない、灯が点かない、windshear は X-Plane のまま、callout の条件（NAV-55〜61）。地形の look-ahead が無い（NAV-62）。
- TCAS の TA/RA の判定、ND の記号、PFD の RA の表示、音声が無い（NAV-69〜72）。トランスポンダのモードの対応（NAV-66）。気象レーダーの論理（NAV-79）。

### FMC（航法・性能・誘導）：未着手

- 経路モデル（レグの種類）が無く、X-Plane 標準の FMS の点列だけ（FMC-01）。ホールドが無い（FMC-02）。
- LNAV の作動条件が無い、横の誘導は方位を HDG SEL に入れるだけ、経路の終わりや discontinuity で方位を保持しない（FMC-03・04・06）。
- 高度制限の種類（AT・A・B・窓）と速度制限が無い（FMC-07・08）。上昇速度の取り違え（FMC-09）。CI は巡航 Mach の経験式にだけ（FMC-11）。
- VNAV の降下パスと PTH の則、approach 段階（FMC-12・13・16）。飛行段階を MCP のボタンで決めている（FMC-17）。
- 軌跡の予測が無い（燃料・ETA は経験式。FMC-20）。ETA の速度の下限の誤り（FMC-21）。CALCULATED の燃料が無い（FMC-22）。風の扱い、片発の VNAV（FMC-25・26）。
- FMC の位置はシムの真値（IRS のドリフトや更新が無い。FMC-28）。UNABLE RNP の条件（FMC-29）。
- メッセージは 54 件のうち 6 件だけ（FMC-32）。遷移高度で気圧を自動で STD にする（実機の FMC には無い。FMC-33）。
- 経路の管理と ND の経路線は X-Plane 標準の FMS 任せで、機体は自前の LNAV で別の経路を飛ぶ（FMC-34・35）。FMC 2 台の扱いが無い（FMC-36）。

### CDU：未着手

- CLR・DEL・+/- の動き（CDU-01）。3 台が X-Plane 標準の CDU 1 つを共有する（CDU-02）。
- 独自のページに MOD・EXEC・ERASE が無く、即時に効く（CDU-03）。題名、大字と小字（CDU-04・05）。キーで開くページが文脈で変わらない（CDU-06）。
- 入力の検査が不正確（CDU-07〜09）。
- 空中の THRUST LIM で GA・CON・CRZ を押すと離陸の derate が動く（CDU-10）。TAKEOFF REF の V speeds の選択の流れ（CDU-12）。PERF INIT・VNAV・PROGRESS・NAV RADIO のページの不足（CDU-13〜16）。
- 無いページ（RTE 2、REF NAV DATA、DESCENT FORECAST など。CDU-18）。故障・電源・メッセージの扱い（CDU-19〜21）。
- データリンク：EMERGENCY REPORT の DIVERT TO が経路の目的地を書き換える、アップリンクの処理が無い（CDU-33〜38）。

### 自動操縦・FD（ATA 22）：未着手

- ロールの指令を X-Plane の AP に頼っている（AFDS-01）。HDG HOLD のコマンドが無い。
- LOC の捕捉に条件が無い（AFDS-02）。TO/GA のピッチの則（AFDS-03）。autoland の flare・rollout（AFDS-04）。複数チャンネル（AFDS-05）。
- A/P を入れたときの既定のモード、V/S の同期、LNAV・VNAV の作動と解除、モードの遷移（AFDS-06〜09）。
- ピッチの制御則、速度の保護と自動反転（AFDS-10・11）。
- AUTOPILOT caution、NO LAND 3・NO AUTOLAND が出ない（AFDS-12・13）。作動のインターロックと電源（AFDS-15・16）。
- ヨーダンパーの則、A/P 中のトリム（AFDS-17・19・20）。
- 試験で見つけたこと：空中で開始すると A/P が入った状態で始まり、機体の読み込み方で動きが変わる。

### オートスロットル・推力管理：未着手

- 推力制限のモードが「飛行段階」の値だけから作られ、それを多くの操作が書く（ATHR-01）。
- assumed temperature が推力に効かない（ATHR-03）。CLB の基準が定格でなく固定の上昇率から（ATHR-04）。
- THR モードを出さない、HOLD・IDLE の論理、TO/GA の作動条件（ATHR-06〜08）。
- 操縦者の override が無い（A/T 作動中はレバーの入力を無視。ATHR-09）。
- サーボの動き、SPD で制限を守らない、flare の retard（ATHR-10〜12）。
- 逆推力を使った着陸のたびに >AUTOTHROT DISC が出る（ATHR-13）。解除スイッチ、インターロック、SPD スイッチ、EICAS の基準の数字（ATHR-14〜17）。

### 通信（ATA 23）：未着手

- VHF の電源が RTP の表示で決まる（COM-01）。ACP 3 枚が連動する（COM-02）。
- VHF C と HF L/R の無線機が無い（COM-03）。AM スイッチの扱い（COM-04）。
- CALL 灯とチャイム、PTT が動かない（COM-05・06）。航法受信の音声の経路（COM-07）。電源への依存が無い（COM-08）。データリンクのメッセージ（COM-09）。

### 照明（ATA 33）：未着手

- サインの memo を選択器の位置でなく点灯状態で出す（LIGHT-02）。
- 外部灯が 747 のバスに依らない（LIGHT-03）。ストロボのスイッチの向きと二重の書き込み（LIGHT-04・05）。
- 非常灯が無い（LIGHT-06）。操縦室照明の standby（AC 喪失時）が無い（LIGHT-07）。
- 毎フレーム完全な GC を走らせている（LIGHT-08）。
- 直した点：P5 の ELEC・HYD・抽気・燃料の灯は、各系統のモデルの出力を読む（LIGHT-01 も 1-1 で解消）。

### ドア（ATA 52）：未着手

- entry door は L1、upper deck door は L だけ。残りのドアに状態・メッセージ・synoptic が無い（DOOR-01）。
- 貨物室ドアと E/E ドアが無い（DOOR-02）。

## 3. X-Plane の上で作ることによる違い

- 推力・燃料流量・空力は X-Plane の計算。燃費は acf の SFC で決まる（燃料 2-2 で値を確かめる）。
- 脚・ブレーキ・オートブレーキ・逆推力は、作り直すまで X-Plane の仕組みのまま。
- 与圧は X-Plane の与圧に値を書いている（空調 3-1 まで）。
- 経路と ND の経路線は X-Plane 標準の FMS（FMC の作り直しまで）。
- X-Plane 側の制約（試験で見つけたもの）：機体を読み直さずにフライトを始めると前のフライトの状態が残る系統がある。XP12 の外部電源は X-Plane の GPU 電圧に従う。X-Plane の抽気のモードと isolation valve は連動する。Web API の長さ 0 のコマンドは離す操作が届かない。

## 4. 新しいパネル画像が要るもの（利用者に確認中）

- 油圧の synoptic：色付きの空の記号（ON 琥珀、AUX の待機・琥珀）、琥珀の AUTO の幅、複数系統の不作動の絵。
- 電源の synoptic の GALLEY の色、STAT の CHG/DIS。
- ほかの分野の表示で画像が要るものは、各分野の作り直しのときに一覧にする（GAP_ANALYSIS.md §4）。
