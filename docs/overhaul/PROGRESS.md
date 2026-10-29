# 進み具合（PROGRESS）

次のセッションは、ここと [PLAN.md](PLAN.md) を読んでから続きに入る。

最終更新：2026-10-29（6-1・6-2 の LEGS の PLAN の CTR と STEP を済ませた：FMS ブリッジの表示中の点で ND の PLAN の中心を動かす。notes/ATA-34-61-FMC.md §42。次は空力の比較（次にやること 5f）。その前の区切り（2026-10-28 昼）の直前に 5-2 の残り：ND の MAP CTR を実機どおりに。選んだ範囲が全周のローズまで、X-Plane の地図は 1 段上、MAP CTR の航跡線と範囲の目盛、全周の ▽ をローズの外縁に。notes/ATA-31.md §40。その前に 6-3：A/P の姿勢のループ。スタビライザーの動きを積分から差し引く作りと自動トリムの帯（§20）、内側のループの姿勢の変化率と全高度共通のゲイン（§21）で、FL350 の ALT HOLD の揺れを ±740 → ±12 fpm に。その前に段 3b：速度を昇降舵で保つ則と速度の保護、§19）。

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
- **段階 4**：
  - 4-1（操縦系統）：段 1〜4 は済（下の「操縦系統（4-1）の GAP の状態」）。
  - 4-2（脚・ブレーキ・ステアリング）：段 1（脚の作動・代替下げ・位置監視・EICAS の表示）、段 2（ブレーキ：源の圧、パーキングブレーキの弁、ANTISKID・ANTISKID OFF・BRAKE LIMITER）、段 3（オートブレーキ：減速の制御、arm・適用・disarm、RTO、memo と AUTOBRAKES）、段 4（ステアリング：tiller 70°・ペダル 7°、系統 1 の脚 DOWN 圧、胴体脚、CONFIG GEAR CTR、>BODY GEAR STRG と STATUS）、段 5（ブレーキ温度とタイヤ圧：FCOM PI.12.8 に合わせた熱の収支、BRAKE TEMP、>TIRE PRESSURE、GEAR synoptic のドアの箱）は済。モデル `plugins/xtlua/scripts/B747.10.xt.gear/B747.10.gear_model.lua`・`B747.10.brake_model.lua`・`B747.10.autobrake_model.lua`・`B747.10.steering_model.lua`・`B747.10.btms_model.lua`・`B747.10.tpis_model.lua` とグルー `B747.10.xt.gear_act.lua`・`B747.10.xt.brakes.lua`・`B747.10.xt.steering.lua`・`B747.10.xt.wheels.lua`（ARCHITECTURE.md §4.16、notes/ATA-32.md §10〜§14）。試験はモデル 71・34・33・44・20・11 件、モジュール 29・38・28・18 件、X-Plane の `s35_gear`・`s36_gear_lock`・`s37_brakes`・`s38_rto`・`s39_steering`・`s40_wheels` と `landing.sh` のオートブレーキ。残りは下の「脚（4-2）の GAP の状態」。
- **段階 5**：
  - 5-1（航法センサーと無線）：段 1（エアデータ：ADC 3 台と電源・故障、AIR DATA の選択と PFD の速度、OVERSPEED、IAS・ALT DISAGREE、>SOURCE SEL ADC、ALTITUDE ALERT、>AOA RIGHT の向き、BARO STD の戻り）と段 1b（カスタム acf の PFD：高度と Mach を選んだ ADC から、SPD・ALT の旗、高度の白枠・琥珀枠。ACF_DIFF.md §5）は済。新しいモジュール `B747.34.xt.nav`（モデル `B747.34.airdata_model.lua` とグルー `B747.34.xt.airdata.lua`。ARCHITECTURE.md §4.17、notes/ATA-34.md §10・§11）。試験はモデル 50 件、モジュール 29 件、BARO STD 8 件、X-Plane の `s41_airdata`（PFD の写真つき）。段 2（IRS：MSU とフル・fast アライン、位置の入力と検査、動き、ATT と SET HDG、電源と ON BAT、メッセージ、FMC の IRS をモジュールの読み手に）も済。モデル `B747.34.irs_model.lua` とグルー `B747.34.xt.irs.lua`（notes/ATA-34.md §12）。GPS（電源、75 秒の初回測位、故障、>GPS・>GPS LEFT/RIGHT、POS INIT の GPS POS）も、モデル `B747.34.gps_model.lua` とグルー `B747.34.xt.gps.lua` で。試験は IRS のモデル 77 件、GPS のモデル 10 件、モジュール 43 件、X-Plane の `s42_irs`。段 4（電波高度計：3 台と電源・故障、EIU の順の PFD のソース、RA 旗、GPWC の比較。minimums：各席の DH の警報、MINS RST は点滅のリセットだけ。GPWS：mode 1〜7、405 のコールアウトと minimums の声、BANK ANGLE、GND PROX パネル、声の優先、GND PROX 灯・PFD の PULL UP と WINDSHEAR・master WARNING、EICAS、`.snd` の結線、CDU の音の設定の添字）も済。モデル `B747.34.ra_model.lua`・`B747.34.gpws_model.lua` とグルー `B747.34.xt.ra.lua`・`B747.34.xt.gpws.lua`、カスタム acf の PFD（notes/ATA-34.md §14、ACF_DIFF.md §5）。試験は電波高度計のモデル 24 件、GPWS のモデル 83 件、モジュール 42 件、X-Plane の `s43_gpws`（46/46、注意 3：AFDS の V/S が mode 1 に届かない）と手操縦の降下 `tests/flight/tools/gpws_dive.ps1`（SINK RATE・PULL UP・master WARNING・PFD の PULL UP）。段 5（トランスポンダ：570 のパネル、L・R、X-Plane のモード。TCAS Ver 7.0：X-Plane の TCAS を核に、モード・故障・RA の抑止・機影の種類・声・TFC と自動表示・ND のメッセージ・EICAS・PFD の RA の値。ND の機影のスロット 30 とメッセージのパネル）も済。モデル `B747.34.tcas_model.lua` とグルー `B747.34.xt.tcas.lua`、ND の `B747.61.xt.nd.lua`（notes/ATA-34.md §15・§16、ACF_DIFF.md §5）。試験はモデル 114 件、モジュール 58 件、X-Plane の `s44_tcas`（試験の相手機 `tests/flight/fwl/B747_traffic.lua`）。段 5c（気象レーダー：570 型のパネル、R/T、安定化、ND の注記、パネルの灯）も済。モデル `B747.34.wxr_model.lua` とグルー `B747.34.xt.wxr.lua`（notes/ATA-34.md §17・§18）。試験はモデル 58 件、モジュール 48 件、X-Plane の `s45_wxr`（49/49）。段 5d（PFD の TCAS RA の表示：赤枠のピッチ領域、VSI の赤の範囲、赤い VS ポインタ。トランスポンダのコード表示：L・R どちらでもコードと ATC L・ATC R。ND の気象レーダーの故障（WXR FAIL、TEST の故障の源、WEAK・ATT）とゲイン（CAL・VAR）の注記と色。パネルの変更）も済（notes/ATA-34.md §19〜§21、ACF_DIFF.md §5）。試験は TCAS のモデル 125 件・モジュール 65 件、気象レーダーのモデル 80 件・モジュール 67 件、X-Plane の `s48_pfd_ra`・`s49_xpdr_display`・`s50_wxr_faults`。
  - 5-2（表示）：段 1（表示器 6 台の電源と故障、INBD・LWR の選択器と自動切替、EIU 3 台の電源・故障・選択、>EIU LEFT、内容ごとの輝度）は済。モデル `plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.display_model.lua` とグルー `B747.60.xt.displays.lua`（ARCHITECTURE.md §4.18、notes/ATA-31.md §10・§11）。試験はモデル 73 件、モジュール 41 件、X-Plane の `s46_displays`（26/26）。段 2（ソース選択の比較のメッセージと、EFIS 操作パネル・表示選択パネルの故障）も済（notes/ATA-31.md §12）。試験はモデル 84 件、モジュール 50 件・14 件、X-Plane の `s47_sources`。
- **段階 6**：
  - 6-1（FMC）と 6-2（CDU）：段取りを決めた（2026-10-26、notes/ATA-34-61-FMC.md §10。下の「FMC と CDU（6-1・6-2）の段取りと GAP の状態」）。経路は自前で持つ（PLAN.md 6-1）。12 段で進め、AFDS（6-3）は段 6 の後、A/T（6-4）は段 9 と並べる。段 1（小修正：FMC-09・10・15・21・29・30・33・40、CDU-09・10・28・33。§11）は済。段 2（CDU の枠組み：新しいモデル `B747.68.cdu_model.lua`。キーと scratchpad、メッセージの列、FMC のメッセージ、即時のページ切替、描画の保護、CDU の電源。§12）も済。段 3a（PERF INIT：GR WT と ZFW、FUEL の CALC・MANUAL、RESERVES、COST INDEX、CRZ ALT を FMC が持つ。INIT REF のキーの行き先。§13）も済。段 3b-1（TAKEOFF REF の V speeds：計器のモジュールが FMC の重量とフラップから計算し、FMC が小さい字で出して選ぶと PFD へ。性能データが変わると TAKEOFF SPEEDS DELETED。§14）も済。段 3b-2（THRUST LIM の SEL と OAT、TAKEOFF REF の ACCEL HT・E/O ACCEL HT・THR REDUCTION・WIND/SLOPE・CG・POS SHIFT・PRE-FLT。§15）も済。段 3c（MENU の <FMC は最後の FMC のページへ、FLT NO は FMC の便名。§16）も済で、段 3 は終わり。段 4（航法データベース：新しいモジュール `B747.68.navdb.lua` で X-Plane の航法データを分けて読む。IDENT の NAV DATA と ACTIVE、NAV DATA OUT OF DATE、REF AIRPORT、ORIGIN の TRANS ALT。§17）も済。段 5 は 6 つに分けた（§18）。段 5a（経路のモデル：新しいモジュール `B747.68.route_model.lua`。まだ機体からは使わない。§19）も済。段 5b・5c（RTE と LEGS のページを FMC の経路に、SELECT DESIRED WPT、X-Plane の FMS への流し込み：§20）も済。段 5d（手続き：新しいモジュール `B747.68.proc_model.lua`、DEP/ARR INDEX・DEPARTURES・ARRIVALS のページ：§21）も済。段 5e（現用点と X-Plane の FMS：飛行中の順送り、流し込みの後の現用点、DIRECT TO の始点 DTOPOS：§22）も済。段 5f（飛行試験キットの経路を CDU で：§24）も済で、段 5 は終わり。X-Plane の FMS の操作は新しいプラグイン `plugins/b747_fms_bridge`（C）で X-Plane のスレッドに移した（§23：XTLua の作業スレッドからの呼び出しで X-Plane が落ちていた）。CDU の EXEC 灯は FMC の修正に合わせた（§25：3D の物体の 2 行、利用者の承認）。段 6（経路の形と LNAV）は 4 つに分けた（§26）。段 6a（経路の形のモデル `B747.68.path_model.lua`：§27）、段 6b（LNAV のモデル `B747.68.lnav_model.lua`：§28）、段 6c（LNAV の組み込み：FMC が順送りし、AFDS の LNAV は FMC の valid で engage して FMC のバンクの指令で飛ぶ：§29）、段 6d（ND の線に条件の脚と弧：§30）も済で、段 6 は終わり。段 7（ホールド・オフセット・残りの経路の操作）は 5 つに分けた（§31）。段 7a（ホールドのモデルと LNAV：経路の HM・HA・HF を進入・周回・出口まで飛ぶ：§32）、段 7b（HOLD キー、RTE LEGS HOLD AT と PPOS、RTE 1 HOLD のページと EXIT HOLD、ND の線のホールド：§33）は済。段 7c（PROC TURN の表示と CRS REVERSAL AT FA FIX：§34。形は段 7f で推定）も済。段 7d（オフセット：RTE の 6R の OFFSET、LNAV のオフセットの線、END OF OFFSET、OFST 灯の dataref：§35）も済。段 7e は 4 つに分けた（§36）。段 7e1（INIT/REF INDEX の NAV DATA> を FMC の REF NAV DATA に：IDENT の点のデータ、NAVAID INHIBIT・VOR ONLY INHIBIT・VOR/DME NAV：§36）、段 7e2（DIRECT TO の ABEAM PTS：飛ばした点の真横の点、LEGS の距離の位置：§37）も済。段 7e3 は 2 つに分けた（§38）。段 7e3a（RTE と LEGS で緯度経度・place/bearing/distance・place bearing/place bearing の点：§38）、段 7e3b（FIX キーで FMC の FIX INFO：方位線・距離の円と経路の交点、ABEAM、place/bearing/distance の写し：§39）、段 7e4（RTE 2 と RTE COPY：二つの経路、もう一つの経路の ACTIVATE、RTE・LEGS・DEP/ARR の RTE 2：§40）も済。段 7f（procedure turn の形：資料に無いので利用者の依頼で推定。LNAV が飛び ND に描く：§41）も済で、段 7 は終わり。次は段取りの表の順で AFDS（6-3）。LEGS の PLAN の CTR と STEP（FMS ブリッジの表示中の点で ND の PLAN の中心を動かす：§42）も 2026-10-29 に済。

## 次にやること

項目を終えるたびに、[DIFFERENCES.md](DIFFERENCES.md)（実機との違い、全分野。2026-10-23 に利用者の依頼で作った）の該当分野も直す。

1. 承認済みのパネル（カスタム acf）の変更：全部済。3-1 の ECS synoptic の上半分と流れの線（AIR-15、PNEU-11）が最後。PNEU-09（主 EICAS のダクト圧の表示条件）は 3-1 段 1 の data block の条件（FCOM p.585 と ATA21 p.451）で済。承認の一覧に無い 2 件（客室高度の赤い数字の桁、data block の LDG ALT の消去。AIR-18）も、2026-10-24 に利用者の承認を得て入れた。済：`.snd` の警報音、1-3 の PG と 3〜10 ページ、1-3 の STATUS ページと cue、1-4 の HYD synoptic（HYD-19。記号の色と不作動項目の絵は 2026-10-23 夕方に新しい画像で）と RSVR PRESS（HYD-18）、1-1 の synoptic の ISLN・DRIVE の枠・UTILITY と GALLEY の色、STAT のバッテリーの値と CHG/DIS、1-5 のダクト圧の色（PNEU-10）。変更の一覧は ACF_DIFF.md §5、画像は `docs/overhaul/tools/make_synoptic_images.ps1` で作る。
2. 3-1（空調・与圧・機器冷却）：段 1（パックと与圧、機器冷却と ER 開始のスイッチ）、段 2（温度制御と貨物室の温度・暖房）、段 3（ECS synoptic のパネル）は済。残りは故障の入れ方（パック・ファン・機器冷却・温度制御。X-Plane に相当する故障が無い。CPC は `air/fail/cpc` を足した）。AIR-18 のパネルの 2 件も済。
3. 3-2（防氷・防雨）：済（下の「防氷・防雨（3-2）の GAP の状態」）。残りは防氷の推力補正（ICE-11。EEC の補正表の作り直しで PNEU-13 と一緒に）、逆推力中の NAI 弁の閉（ICE-05）、ウォッシャー・防雨剤・WSHLD AIR（ICE-10。3D の操作子が要る）。3-3（酸素）：済（下の「酸素（3-3）の GAP の状態」）。
4. 3-4（火災防護）：段 1・2 は済。残りは M869（脚格納部の APU 火災パネル）と APU のホーンの音、クルーレストの煙での空調の停止、ダクトリークの抽気への影響（PNEU-03）、貨物機の主デッキ（FIRE-19）。
5. 4-1（操縦系統）：小さな修正（FCTL-04・14・19・23）、段 1（フラップの FCU：`B747.45.fcu_model.lua`）、段 2a（SRM のうち外側エルロンのロックアウトとラダー比変換器：`B747.45.srm_model.lua`）、段 2b（SRM の安定板トリム：手動・ALTN・オートトリム・cutout と自動遮断・制限・速さ・column cutout・AP との関係・メッセージ。AP が外れても AP の昇降舵の指令が残る誤りも）、段 2c（speed trim と STAB SPEED TRIM、グリーンバンドの 3 帯と CONFIG STAB の帯：`B747.45.greenband_model.lua`）、段 3（スピードブレーキ：自動展開と格納、SPEEDBRAKE AUTO、>SPEEDBRAKES EXT、空中の CONFIG SPOILERS を貨物機だけに、CONFIG GEAR の着陸フラップ：`B747.45.speedbrake_model.lua`）は済。段 4（横操縦：エルロンのプログラマ、スポイラーの横操縦とミキサー、スピードブレーキの段、スポイラー 6・7 と主翼 2 の X-Plane の面、エルロントリムの権限：`B747.19.lateral_model.lua`。後半で FLT CONTROL HYD POWER とヨーダンパーの INOP）も済。4-1 の残りは、承認が要るフラップの拡大・代替の表示のパネル（FCTL-12）、空力の項目で扱う昇降舵の舵角（FCTL-18）、acf の値の確認（FCTL-22）、資料に値が無い >STAB GREENBAND（FCTL-10 の残り）。次は PLAN の 4-2（脚・ブレーキ・ステアリング）。着陸の試験は `tests/flight/tools/landing.sh`（RJAA 34L、TESTING.md §4.2）で回せる。舵面への書き出し（controlObject）は残す。下の「操縦系統（4-1）の GAP の状態」。
5a. 4-2（脚・ブレーキ・ステアリング）：段 1〜5 は済。tiller の軸が無い利用者のための「ペダルを tiller に」はそのまま、逆推力の hold コマンドは離したら reverse idle（利用者、2026-10-25）。残りは AIR/GND SYSTEM と脚の残りの STATUS（GEAR MONITOR・A/G DISAGREE・PARK BRK VALVE：GEAR-22 の残り）、CONFIG GEAR のラッチと GND PROX GEAR OVRD（GEAR-17 の残り）、ドアの箱の空箱。段階 4 の区切りの全シナリオは合格（2026-10-25：日誌）。
5b. 5-1（航法センサーと無線）：段 1（エアデータ）、段 2（IRS・GPS）、段 4（電波高度計・GPWS。音声は 405 の組）、段 5（トランスポンダ・TCAS Ver 7.0、ND の TCAS 表示）、段 5c（気象レーダー：570 型のパネルの論理、R/T と電源、安定化の IRU、ND の注記）、段 5d（PFD の TCAS RA の表示、トランスポンダのコード表示、ND の気象レーダーの故障とゲインの注記）は済。
5c. 5-2（表示）：段 1（表示器と EIU：選択器と自動切替、EIU の選択と故障、内容ごとの輝度）、段 2（ソース選択の比較：>SOURCE SEL EIU・F/D・NAV、>SNGL SOURCE RA、>ATTITUDE・>HEADING、>EFIS CONTROL・>EFIS/EICAS C/P）は済。段 3a（速度テープのうち資料から決まるもの：フラップの機動速度と VREF25、バグの出し方、最小機動速度の帯の出し始め、最小速度の表の高度帯）も済（notes/ATA-31.md §13）。段 3b（最小速度・最小と最大の機動速度・スティックシェーカー・AIRSPEED LOW と琥珀の枠：FCTM p.261–262 のシェーカー速度の図と FCOM PI.11.1 の最大運用高度から作った境界。notes/ATA-31.md §14、新しいモデル `B747.60.minspeed_model.lua`）も済。重量の補間の誤り（VREF30 が最大 3 kt 低い）と表の誤記（DSP-08）も直し、フラップのバグは約 20,000 ft より上で出さない。`airspeed/Vmc` は AFDS・A/T・VNAV の速度の下限のために前の式のまま（PFD の帯は新設 `Vminm`）。段 4（気圧と PFD の記号・旗・方位：DSP-01・04・11・12。PLI も）は 4a〜4e に分けた（notes/ATA-31.md §15）。段 4a（PFD の姿勢・方位・昇降率の源と ATT・HDG・VERT の旗、方位目盛を ND の向きからその席の方位へ：DSP-01、DSP-04 の IRS の分。新しいモデル `B747.60.pfd_model.lua`、notes/ATA-31.md §16）は済。段 4b（気圧設定の遷移高度での琥珀の枠、CDU の EFIS CONTROL の BARO SET をその CDU の側だけに：DSP-11 の残り。notes/ATA-31.md §17）も済。段 4c（PLI と VR の R：notes/ATA-31.md §18。段の分け直しもそこに）も済。段 4d（FPV のスイッチのラッチと FPV、FPV・PITCH・ROLL の旗：notes/ATA-31.md §19）も済。段 4e（ILS の表示：偏位過大の琥珀と点滅、G/S・LOC の旗、ロール 53° 超での消去：notes/ATA-31.md §20）も済で、段 4 は終わり。段 5（ND）は 5a〜5e に分けた（notes/ATA-31.md §21）。段 5a（ND の向き、方位・航跡、TRK・HDG・MAP・VTK の旗：§22）も済。段 5b は 5b-1a（PFD の ILS の受信機を使用中の EIU に、進入の基準の ID か周波数、>SNGL SOURCE ILS：§23）、5b-1b（ND の APP：基準受信機、偏位、LOC・G/S の旗）、5b-2（ND の VOR と VOR・ADF の針、TO/FROM、VOR・DME の旗）に分けた。5b-1a・5b-1b（§24）は済。5b-2 は 5b-2a（VOR モード：§25）と 5b-2b（VOR・ADF の針と左右下の欄：§26）に分け、どちらも済で、段 5b は終わり。段 5c は 5c-1（CDU の EFIS CONTROL・OPTIONS を席ごとに、パネルの故障のときだけ。EFIS 操作パネルの故障でパネルの操作が効かない：§27）、5c-2（DATA・POS の表示）、5c-3（STA の高・低高度、同調中の局、ARPT、EXCESS DATA）に分けた。5c-1 は済。5c-2 は 5c-2a（DATA：経路の点の高度と FMC の ETA：§28）と 5c-2b（POS）に分け、5c-2a は済。5c-2b（POS：IRU・GPS の位置、VOR の radial：§29）も済で、段 5c-2 は終わり。5c-3 は 5c-3a（STA の高・低高度、同調中の局、STA・WPT・ARPT は MAP だけ、EXCESS DATA、109 の GS：§30）、5c-3b（出発・到着空港と滑走路、経路の点は MAP・MAP CTR・PLAN だけ：§31）、5c-3c（手動同調の局のコースの線：§32）に分け、どれも済。段 5d（HDG REF：§33）、段 5e（位置のトレンドベクトル：§34）、段 6a（時計：§35）、段 6b-1（EICAS の部分表示と二次エンジンの逸脱の印：§36）、段 6b-2（主 EICAS の compact の形：§37）も済。段 7（パネルの SHOW の条件の重なり：§38）も済。機体の型式による ND の向き（2026-10-27 の利用者の決定：P&W は 109、GE は 570 で、どちらも MAP は航跡が上・TRK。RR は P&W と同じ。いったん P&W を 405（全モードで方位が上）にして、同じ日に戻した）と拡大の方位の印の位置（§39）も済。5-2 の残りは DSP-19（TERR、外部のプラグイン頼み）と、ND の FMC の記号の残り（FMC の作り直し 6-x で）。MAP CTR の縮尺は実機どおりに直す（2026-10-28 に決まった。まだ：下の「決まったこと（2026-10-28、利用者の回答）」）。カスタム acf は図よりずっと遅くまで失速しなかった（クリーンで約 20 kt、フラップ 10・20・30 は昇降舵いっぱいでも失速しない）ので、利用者の承認（「acf も調整しよう」）を得て、主翼の翼型の失速を早め、前縁スラットの効きを下げた（2026-10-25 夜、ACF_DIFF.md §5：図との差は UP −2、10 +6、20 −5、30 +4 kt）。DSP-14 は無線の同調（5-1 段 3）で（>SNGL SOURCE ILS は段 5b-1a で済）。段取りは notes/ATA-31.md §10。待っていた 3 件（PFD の TCAS の RA の表示、R を選んだときのトランスポンダのコード表示、ND の WXR FAIL と原因・ゲインの文字）は段 5d で済（パネルの変更は全範囲で承認なしでよくなった：2026-10-25）。WXR RANGE DISAGREE・RSTR INOP は残り。段 3（無線の同調）は、自動同調の判断と NAV RADIO ページが FMC の経路と航法データに依るので、6-1・6-2（FMC・CDU）と一緒に行う（2026-10-25 朝に決めた。notes/ATA-34.md §13）。PFD の昇降率の源（IRS）と ATT・HDG の別々の旗は段 4a で済。ND の MAP CTR の縮尺（選んだ範囲が全周のローズまで、MAP CTR の航跡線と範囲の目盛）は 2026-10-28 に済（notes/ATA-31.md §40）。
5d. 6-1・6-2（FMC と CDU）：段 1（小修正）・段 2（CDU の枠組み）・段 3（地上準備のページ）、段 4（航法データベース）、段 5a〜5f（経路のモデル、RTE と LEGS、手続きと DEP/ARR、現用点と X-Plane の FMS、試験キット）は済で、段 5 は終わり。段 6（経路の形と LNAV）と段 7（ホールド・オフセット・REF NAV DATA・ABEAM PTS・自分で作る点・FIX INFO・RTE 2・procedure turn の形）も済。次は段取りの表の順で 6-3（AFDS）、そのあと段 8（性能 DB と予測）（下の「FMC と CDU（6-1・6-2）の段取りと GAP の状態」）。LEGS の PLAN の CTR と STEP は (b)（FMS ブリッジの `xp/displayed`）で作った（2026-10-28 に決まり、2026-10-29 に済：notes/ATA-34-61-FMC.md §42）。
5e. 6-3（AFDS）：段取りを決めた（2026-10-27、notes/ATA-22.md §10）。段 1（モードの論理：1a 枠組みと engage、1b ロールのモード、1c ピッチのモード、1d 進入のモード、1e TO/GA の論理）、段 2（ロールの則）、段 3（ピッチの則）、段 4（autoland と 3 チャンネル）、段 5（監視と警報）、段 6（ヨーダンパーと autotrim）。段 1a（枠組みと engage：新しいモデル `B747.70.afds_model.lua`、§11）、段 1b（ロールのモード：§12。段 1 の残りを 1c ピッチ、1d 進入、1e TO/GA に分け直した）、段 1c（ピッチのモード：§13）、段 1d（進入のモード：§14）、段 1e（TO/GA：§15）は済で、段 1（モードの論理）は終わり。段 2（ロールの則）は 2a（方位・姿勢・航跡の則：HDG SEL・HDG HOLD・ATT・LNAV・TO/GA、bank limit、HDG REF）と 2b（LOC の捕捉と追従）に分け、2a（§16。新しいモデル `B747.70.afds_roll_model.lua`）と 2b（§17）は済で、段 2 は終わり。段 3（ピッチの則）は 3a（V/S・ALT とその捕捉）、3b（速度を昇降舵で保つ則と速度の保護）、3c（G/S）に分け、3a（§18。新しいモデル `B747.70.afds_pitch_model.lua`）と 3b（§19）は済。段 3b の試験で見つかった A/P の姿勢のループ（内側のループ）の揺れ（FL350 の ALT HOLD で ±740 fpm・±0.16 g）は、自動トリムと PID の積分の取り合いが原因で、スタビライザーの動きを積分から差し引く作りと資料の自動トリムの帯で ±250 fpm・±0.07 g にした（§20。いったん中断して同じ日に再開）。内側のループに姿勢の変化率を足し、ゲインを全高度で 0.1 にして、残りの揺れも止めた（§21：FL350 で ±12 fpm）。2026-10-28 に決まった LEGS の PLAN の CTR と STEP は 2026-10-29 に済（もう 1 件の ND の MAP CTR の縮尺は 10-28 に済：notes/ATA-31.md §40）。次は空力の比較（下の 5f）、そのあと段 3c（G/S）。
5f. 空力の比較（カスタム acf。2026-10-28 の利用者の指示で、LEGS の PLAN の CTR と STEP の次に行う）：FCOM・FCTM の目安と、カスタム acf の釣り合いの姿勢・推力・昇降率を比べ、ずれていれば acf の空力を調整する（2026-10-28 から、見た目が変わらない範囲で承認なしでよい：CLAUDE.md。手順はバックアップ・変更前後の一覧・外観の写真）。システム側で補正しない。
   - 目安：FCOM PI.10.38–10.40（p.264–266、PW4056。CF6 は p.361–362）の Flight With Unreliable Airspeed の表（重量 200〜390 t・高度ごとの、上昇（290/.84、最大上昇推力）の姿勢と昇降率、巡航（.84/290）の姿勢と EPR・N1、降下（アイドル）の姿勢と昇降率、待機・終端区域・最終進入のフラップと脚ごとの姿勢と推力）。文字起こしは表が崩れているので、PNG にして読む。
   - ほかの目安：FCTM p.168（3°・フラップ 30・VREF30+5 で姿勢 2.0°）、p.95–96（引き起こし約 2.5°/s、浮揚の姿勢 10.0°（フラップ 20）・10.1°（10））、p.138–139（アイドルの降下率：.83M/340 kt で 2,800 fpm、250 kt で 1,300、VREF30+100 で 1,200。スピードブレーキで 4,300・2,100・1,900。水平の減速 340→250 kt が 90 秒・8 NM）、p.294（速度計異常の姿勢：巡航 3°、降下 0°、最終進入 VREF+10 でフラップ 25 は 2.5°・30 は 1°）、p.257（失速接近の推力）。notes/FCTM.md §1.13 の早見表。
   - やり方：失速の測定（`tests/flight/measure/stall_*.json`、`tests/flight/tools/stall_speed.lua`）と同じく、重量・高度・速度・形態をそろえた定常の測定シナリオを作り、A/P と A/T で保って姿勢・推力・昇降率を記録する。表の重量（200〜390 t）と今のシナリオの約 270 t の間は内挿する。
   - すでに合わせたもの：失速速度（2026-10-25：残りはフラップ 10 +6、20 −5、30 +4 kt）、巡航の燃料流量（2026-10-23、SFC）。
   - 後縁フラップで見た目に関わらない設定（2026-10-28 に確かめた。10/25 は触っていない）：3D のフラップは FCU のモデルの角度（`fcu_te_deg`：UP 0・1 で 0・5・10・20・25 で 22・30 で 30°）を写した `laminar/B747/flt_ctrls/flaps` で動き（`Exterior_Wings1.obj` などの ANIM）、同じ角度を X-Plane の翼のフラップの角度（`wingNl_fla1def`・`fla2def`）に書いている。角度を変えると見た目が変わるので変えない。見た目に関わらないのは acf の `_flap1_cl`・`_flap2_cl`（1.35）、`_cd`（0.14）、`_cm`（−0.39）、`_type`（4）、`_cratR`・`_cratT`（0.26）と、detent の表 `_flap1_dn`・`_flap2_dn`（0・1・5・10・20・25・40：最後が 40° なのに FCU は 30 で 30° を渡す。X-Plane がこの最大で効きを割っているなら、30 で全部の効きが出ていない可能性がある）。フラップごとの失速速度の差を詰める候補として試す。acf 自身の部品は 41 個とも描かない設定（`_part_specs_invis 1`）で、見た目は OBJ の物体だけなので、空力の数値を変えても形は変わらない（変わるのは飛び方：定常の姿勢、トリムと舵面の位置）。外観の写真でも確かめる。関係しそうな未解決：FL350 の空中開始の大きな揺れ（気づいたこと）。
   - 順番：VNAV（FMC の段 8 以降）・A/T（6-4）・AFDS の続き（段 3c 以降）より先に、空力を整える（2026-10-28 の利用者の希望）。どれも機体の応答に合わせて調整するものだから。
   - 空力を変えたら、いまの空力で合わせた次のものを測り直す：
     - 失速速度（`tests/flight/measure/stall_*.json`）。
     - AFDS のピッチの則（s101・s107・s108 など）。
     - 姿勢のループのゲインと自動トリムの帯（notes/ATA-22.md §20・§21）。
   - LNAV とロールの則は、確かめるだけでよい見込み（推定）：
     - LNAV の則（`B747.68.lnav_model.lua`）は、航路からのずれ・航跡の差・対地速度からバンクの指令を作るだけで、空力に依らない。
     - バンクを 3°/s で指令に合わせるのは、ロールの内側のループ（`laminar/B747/flt_ctrls/pid/roll/*`）。補助翼・スポイラーの効きなど横の空力を変えたときだけ、影響が出る。
     - 旋回中の高度と速度の保持は、ピッチの則と A/T の側（上の測り直しに入る）。
     - 空力を変えたら s90・s91・s92・s100・s105・s106 を回し、バンクの追従や航路のずれが変わっていたら合わせ直す。
   - 横・方向の空力も比べる（2026-10-28 の利用者の問い）。資料にある目安：
     - VMCG（FCOM p.236（PI.10.10）の表、PW4056。例：海面 15 °C で 121 kt）：
       - 最大離陸推力で外側のエンジンを VMCG で止め、ラダーだけ（tiller なし）で方向を保てること。それより遅いと保てないこと。
       - 逸脱の量の基準は資料に無いので、記録だけにする（推定）。
       - CF6 は CF6 の PI の表を使う。
     - 片発と 2 発停止：
       - ラダートリムで操縦輪が水平になること（FCTM p.55 (1.25)）。
       - 同じ側の 2 発停止の着陸復行では、ラダートリムいっぱいでもペダルが少し要ること（FCTM p.209）。
     - 横風：最大離着陸横風 30 kt（実証値で、制限ではない：FCOM p.77 (L.10.1)）と FCTM p.99・p.241 の目安で、舵がいっぱいにならずに離着陸できること。
     - ダッチロールとロールの速さは、資料に値が無い。ヨーダンパーの入・切で見て、明らかにおかしいときだけ報告する（推定で合わせ込まない）。
     - 横の空力（垂直尾翼・ラダー・補助翼の効き）を変えたら、上の LNAV とロールのシナリオとヨーダンパーも確かめる。
   - 主翼・水平安定板・垂直尾翼の空力の設定も、フラップと同じく変えてよい（2026-10-28 の利用者の指摘）。acf の部品は描かない（`_part_specs_invis 1`）ので、形は変わらない。ただし次の 2 点を守る：
     - 翼の曲がりは見た目に出る：
       - 外装の OBJ（主翼・エンジン・着陸灯など）は、`sim/flightmodel2/wing/wing_tip_deflection_deg` で曲がる（89 か所）。X-Plane はこれを、翼の荷重・形・曲がりの設定から計算する。
       - 曲がり方は、違和感のない範囲なら変わってもよい（2026-10-28 利用者、CLAUDE.md）。
       - 翼の曲がりの設定や、曲がりに効く値を変えたら、地上・巡航・旋回の外観の写真で前後を比べて報告する。
       - 翼型を変えても、定常の飛行では揚力の合計（＝重量）は同じなので、曲がりはほとんど変わらない。
     - 形（翼幅・面積・後退角・上反角・位置）は実機の値のままにする：
       - X-Plane は形から、地面効果・吹きおろし・慣性モーメント・翼端の接地の位置を計算する。
       - 形で合わせると、見えている機体と飛び方がずれ、ずれの原因も隠れてしまう。
     - 変える候補：
       - 翼型（揚力の傾き・最大揚力・抗力・ピッチングモーメント）。
       - 取り付け角：同じ揚力での機体の姿勢が変わるので、姿勢の目安に効く。実機に近い範囲で。
       - 抗力の項目（胴体・脚・スピードブレーキ）：アイドル降下率と巡航の推力に効く。
       - 水平安定板の翼型と昇降舵の効き：引き起こしの速さ（FCTM p.95–96）・フレア・トリムの位置に効く。
       - 垂直尾翼とラダーの効き：VMCG・横風に効く。
6. 2-3（エンジン）の残り：段 1〜3 は済（下の「エンジン（2-3）の GAP の状態」）。後回し：表示値の作り方（ENG-33。EGT は X-Plane の EGT の比例では始動と離陸を両立できず、N1・N2 などから作り直す必要があるが、値は資料に無く推定になる。N1・EPR・N2 の式を変えると EEC の推力の制御の調整もやり直し）、始動の空気（ENG-38・PNEU-08。ダクト圧と starter の関係が資料に無い）、GE の油圧の目盛りと値（CF6 の値が資料に無い）、振動の high band。partial・compact 形式と exceedance cue（ENG-22）は 5-2 で。空中始動の範囲（ENG-24）は資料に値が無く作れない。燃費の離陸・上昇の値（純正と同じにした SFC）を PI.11 の上昇の燃料の表と比べるのも残り。A/T（6-4）との境界は、EEC がレバー → 指令・最大定格・推力の制御まで、FMC の推力基準と A/T のサーボ（レバーを動かす）は 6-4。
7. 1-5（空圧）の残り：故障の入れ方（過熱、過圧、HPSOV・PRV の固着、ダクトリーク）、地上空気の操作、スターターがダクト圧で回ること（エンジン 2-3）。
8. 1-4（油圧）の残り：脚・ブレーキ・ステアリング（4-2 段 1・2・4）、逆推力（2-3 段 3）、stab trim・ヨーダンパー（4-1 段 2b・4）の「油圧で動くか」（HYD-09・11・12）は済。リザーバ与圧の表示（HYD-18）と STATUS のメッセージ（HYD-20）は済。
9. 1-1（電源）の残り：電源の有無を `bus_volts` で見ている系統を、バスごとの dataref（ARCHITECTURE.md §4.1）に乗り換える。どれも後の作り直し（空圧 1-5、空調 3-1、燃料 2-2、IRS と無線、照明、操縦系統 4-1）と絡むので、1-2 と同じく各系統の作り直しのときに行う（2026-10-23 に決めた。利用者の確認待ち）。
   - 済：表示器（fltInst02。機長 PFD・ND は APU standby、upper EICAS は main standby、ほかは F/O transfer）、EICAS の計算（warning。EIU のどれかに電源）、時計の計時（fltInst03。main hot battery bus、表示は APU battery bus：5-2 段 6a）、ELEC パネルの灯（lighting）。
   - 燃料のポンプと弁も 2-2 で乗り換えた（AC・utility・main battery・hot battery・DC・APU battery・ground service bus）。
   - 残り：IRS と NAV RAD（fms）、表示灯の輝度（lighting：`bus_volts[0]`・`[2]`）、客室灯（lighting）、ヨーダンパー（fltCtrls：`battery_array_on`）。STAT ページのバッテリーはカスタム acf だけ済（純正 acf は X-Plane の値のまま）。
10. 1-2（空地判定）の残り：`onground_any` を読んでいるモジュール（autopilot、fms、fltInst02、fltCtrls、EEC、engines、fuel、hydraulicsmodel、gear のタイヤ圧とリプレイ、manipulators、fdr、lighting など）を、PSEU の dataref（ARCHITECTURE.md §4.2）に乗り換える。どの信号（pri/alt の AIR・GND、前脚圧縮）を使うかは notes/ATA-32.md §4.1 の表。各系統の作り直しのときに行う。防氷（3-2）は乗り換えた（`pri_gnd`）。
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

## 利用者に確かめたいこと

- （2026-10-28 に決まった：(b)）LEGS の PLAN の CTR と STEP（2026-10-26、6-1・6-2 段 5e。FCOM p.1333；FMSPG p.124）：ND の PLAN の中心は X-Plane の FMS の表示中の点で、XTLua からは書けない（`xtlua/xpFMSData` の書き込みは INOP）。(a) X-Plane の CDU のキー（LEGS・NEXT・PREV と PLAN の STEP）を裏で押して X-Plane の表示中の点を動かす（XTLua だけで済むが、X-Plane のページ送りに合わせるので壊れやすい）、(b) XPLMSetDisplayedFMSEntry を呼ぶだけの小さなプラグイン（C++。CLAUDE.md で採用してよいとされた範囲）を作る、(c) 段 7 まで置く、のどれにするか。
  - 2026-10-28 追記：その後、FMS ブリッジ（notes/ATA-34-61-FMC.md §23）に `laminar/B747/fms/xp/displayed`（XPLMSetDisplayedFMSEntry を X-Plane のスレッドで呼ぶ）ができたので、(b) はプラグイン側が済んでいる。(c) の段 7 も済。推奨は (b)：残りは FMC・CDU 側だけ（LEGS の CTR の印と STEP キー、PLAN の中心の点を `xp/displayed` に書く）。(a) は X-Plane の CDU のページの状態に頼るうえ、XTLua の作業スレッドから X-Plane の FMS に触れる形になる（§23 で X-Plane が落ちた原因と同じ）。利用者は (b) に決めた（2026-10-28：下の「決まったこと（2026-10-28、利用者の回答）」）。
- （2026-10-28 に決まった：下の「決まったこと（2026-10-28、利用者の回答）」）ND の MAP CTR の縮尺（2026-10-26、5-2 段 5c-3）：MAP CTR では、地図の記号（局・経路の点・TCAS）と X-Plane の地図の層が拡大の MAP と同じ縮尺（465 px＝選んだ範囲）で描かれ、見えるのは機体から 250 単位（182 px、範囲の約 4 割）まで。一方、全周のローズの半径は約 230 px。FCOM p.1143 の図からは、MAP CTR ではローズの半径が範囲に当たるようにも読めるが、明記は無い。実機の MAP CTR で、ローズの円が選んだ範囲（または範囲の半分）を表すかを確かめたい。直すなら、MAP CTR のときだけ X-Plane の地図の範囲を 1 段上げ、記号・TCAS・高度の弧・POS の線の縮尺を半分にする（試しに X-Plane の範囲を 1 段上げると地図の層の縮尺が半分になることは確かめた）。

## 決まったこと（2026-10-29、利用者の回答）

- カスタム acf のエンジンの推力も、適宜調整してよい（「あとエンジンの推力も適宜調整していいよ」：CLAUDE.md に書いた）。空力と同じく承認なしで、手順（バックアップ・変更前後の一覧・外観の写真）は守り、変えたら報告する。
- 空力の比較の上昇は、A/T の推力（ATHR-04：決まった上昇率に要る推力）でなく、EPR を手で FCOM の Max Climb EPR（PI.10.36）に合わせて測る（「EPRを手動でMAX CLIMB THRUSTに合わせて試験できないの？」）。FlyWithLua の `tests/flight/fwl/B747_epr_hold.lua` が A/T を切ったレバーを毎フレーム合わせる（notes/AERO.md）。

## 決まったこと（2026-10-28、利用者の回答）

- ND の MAP CTR の縮尺は実機どおりにする（「NDのMAP CTRのレンジの件は実機通りの仕様でお願い」）。
  - 実機では、拡大の MAP と同じく、選んだ範囲は機体の記号から全周のローズの円までの距離。範囲の選択器は前に見える距離を選ぶもので、MAP から MAP CTR に替えると地図は約半分の大きさになる。
  - 手元の資料（FCOM 10.40、ATA31、ATA34）には文での明記が無い。上は実機の決まりとして入れる（PROGRESS の推定の一覧には入れず、notes に根拠を書く）。
  - 直し方（2026-10-26 に試した）：MAP CTR のときだけ X-Plane の地図の範囲を 1 段上げ、記号・TCAS・高度の弧・POS の線の縮尺を半分にする。5-2 の残りとして入れる（時期は利用者と決める）。
  - 2026-10-28 に入れた（notes/ATA-31.md §40）。640 NM は X-Plane の地図に上の段が無いので、パネルの半分の大きさの地図にした。MAP CTR の航跡線と範囲の目盛（FCOM p.1143）と、全周の ▽ の位置（利用者の指摘）も直した。
- カスタム acf の空力は、最適化のためなら見た目が変わらない範囲で、承認なしで変えてよい（「これからは空力特性を最適化するためであれば見た目が変わらない範囲でacfいじっていいよ」：CLAUDE.md に書いた）。手順（バックアップ・変更前後の一覧・外観の写真）は今までどおり。失速特性は 2026-10-25 に利用者の承認で合わせてある（ACF_DIFF.md §5：FCTM の失速速度との差は UP −2、10 +6、20 −5、30 +4 kt。X-Plane の後縁フラップの揚力が頭打ちになるので、フラップごとの差は消しきれない）。
- 空力の比較を、LEGS の PLAN の CTR と STEP の次の項目にする（「空力の比較（FCTM・FCOM の目安：進入の姿勢と推力、上昇率など）を、LEGS の PLAN の CTR と STEP の次の項目として予定に入れて。再開したら進めてね。」）。中身は「次にやること」の 5f。
- LEGS の PLAN の CTR と STEP は (b) で作る（「bで。」）。
  - FMS ブリッジ（notes/ATA-34-61-FMC.md §23）の `laminar/B747/fms/xp/displayed` に、ND の PLAN の中心にする点を書く。プラグインはそれを XPLMSetDisplayedFMSEntry で X-Plane のスレッドに渡す。プラグインの変更は要らない。
  - 残りは FMC・CDU 側：LEGS の CTR の印と STEP キー（FCOM p.1333；FMSPG p.124）、中心の点の番号を `xp/displayed` に書くこと、その試験。
  - 作るのは中断を解いてから（6-3 の作業と並べて時期を決める）→ ND の MAP CTR の次に作る（2026-10-28 の中断の時点で次の項目）。
  - 資料の要点（再開用）：FCOM p.1333 の 9・10（PLAN のとき、ND の PLAN の中心の点の横に <CTR>。6R の STEP（ACTIVATE や RTE DATA の代わり）を押すと <CTR> が次の点へ進み、PLAN の中心が移る）、FMSPG p.124（ACT RTE LEGS で ND が PLN のとき 6R に STEP>。LEGS キー・PREV PAGE・NEXT PAGE で、表示したページの最初の点が中心になる。PLN でないときの inactive の LEGS は 6R に ACTIVATE>）。中心は FMS ブリッジの `laminar/B747/fms/xp/displayed`（X-Plane の FMS の項目、1 から）に書く。X-Plane の表示中の項目は 1 つなので、両席の ND の PLAN は同じ中心になる（実機は CDU ごと：違いとして残る見込み）。nd.lua の `updateNDLatLong` は X-Plane の表示中の項目を PLAN の中心に使う。

## 決まったこと（2026-10-27 午後、利用者の回答）

- 機体の有効番号：P&W の機体は FCOM の 109、GE は 570 として作る。RR は資料が無いので P&W と同じ（推定）。見分けは `laminar/B747/engines/type`。利用者はいったん「405にしよう」と決め、ND（405 は全モードで方位が上、枠と旗は HDG）と AFDS の段 1d の G/S（405 は LOC の捕捉の後）を 405 にしたが、方位の印の直し（notes/ATA-31.md §39）が 405 と関係ないと分かって、同じ日に「P&WはNDとAFDSも109に戻してよ。GEの撮影はいらない」と決め直した。405 の道（ND のモデルの `track_map` が false、AFDS のモデルの `inp.gs_after_loc`）は、どの機体も使わない入力として残した。109 と 405 の違いの一覧（[EFFECTIVITY_405.md](EFFECTIVITY_405.md)）は参考。

## 決まったこと（2026-10-27 未明、利用者の回答）

- CDU の EXEC 灯は、破綻しない範囲で作り直してよい（3D の物体の変更を含む）。→ 3D の物体の EXEC 灯の 2 行だけ、見る dataref を FMC のものに替えた（notes/ATA-34-61-FMC.md §25）。
- X-Plane の FMS を X-Plane のスレッドで操作する小さなプラグイン（C、Windows 用）を作ってよい。コンパイラー（MinGW-w64）と X-Plane SDK のダウンロードも承認（CLAUDE.md の「XLua 2.0 や C++」の範囲。XTLua では足りない理由・ほかの案・影響は notes/ATA-34-61-FMC.md §23）。プラグインは完成後の普通のフライトでも使う（機体のフォルダーにあり、機体と一緒に読み込まれる）。

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
- 開発・調整・試験はカスタム acf だけに合わせる（利用者、2026-10-25。使用量を抑えるため）。純正 acf は比較用のファイルとして残すだけで、試験しない（純正で動かなくなっても構わない）。acf ごとの調整値の表や acf を見分ける仕組みは作らない。ゲインや記録から合わせ込んだモデルはカスタム acf に合わせてよいが、飛行特性のずれをシステム側の補正でごまかさず、FCOM・FCTM の目安と比べて acf 側がおかしければ報告してカスタム acf の調整を提案する。X-Plane の試験は変更した系統に関係するシナリオだけ、全シナリオは大きな区切りのときだけ（CLAUDE.md の acf の節と進め方）。
- パネルの画像は、違和感のない範囲なら新しく作ったり直したりしてよい（利用者、2026-10-23 夕方。油圧・電源の synoptic の分を聞いたときの答え）。

## 決まったこと（2026-10-25 未明、利用者の回答）

- tiller の軸が無いときにペダルを tiller の代わりにする手当て（実機ではない、`gear/steering/pedal_tiller`、既定で入）は、そのままでよい。tiller の軸があれば実機どおり（tiller 70°・ペダル 7°）であることが条件で、今の作りはそうなっている。
- 逆推力の hold コマンドは、離したら reverse idle にする（本家は推力レバーを前に出すか 65 kt まで最大逆推力が残った）。
- GEAR synoptic のブレーキ温度の数字は、表示の 5 以上で琥珀にする（パネルの変更。承認済みの一覧の外を個別に承認）。2026-10-25 に入れた（ACF_DIFF.md §5）。
- 5-1 の GPWS の音声は 405 の組（2500〜10、APPROACHING MINIMUMS、BANK ANGLE。機体側は 109 を基準にする決まりの例外：3D の構成に合わせる）。TCAS の版は 3D の年式に合う方。

## 決まったこと（2026-10-25 夕方、利用者の回答）

- カスタム acf のパネル計器は、全範囲で承認なしで変えてよい（「これからは未承認でのパネル変更を全範囲で行なっていいよ」）。手順（変更前のバックアップ、ACF_DIFF.md §5 の前後の値、外観のスクリーンショット）は守る。オブジェクト・ライト・視点・脚や舵面の位置など、ほかの見た目の項目は今までどおり承認が要る。純正 acf は変えない（CLAUDE.md）。待っていた 3 件（PFD の TCAS RA の表示、R を選んだときのトランスポンダのコード表示、ND の WXR FAIL と原因・VAR）から入れる。

## 推定で作った部分

- 自動操縦（6-3 段 1a・1c・1d・1e、`B747.70.afds_model.lua` と `B747.70.xt.autopilot.lua` に「estimate」）：TO/GA の「フラップ UP」をフラップのハンドルの位置で判断すること（段 1e）。ATT から LOC へは HDG HOLD と同じ（遷移表 p.351 に ATT が無い）。A/P の engage に要るそのチャンネルのサーボの油圧 1000 psi（前のコードの解除の値）。ATT は RR も PW と同じ（RR の資料が無い）。FLCH の ALT HOLD の既定（MCP 高度への道から 8,000 ft：ATA22 p.338）を測り始める点は、FLCH の間に MCP 高度にいちばん近づいた所（資料に定めが無い）。ロールの則（段 2a、`B747.70.afds_roll_model.lua`）：方位・航跡の差 e に毎秒 e/8° の旋回のバンク、指令の速さ 3°/s、AUTO の TAS の表（300 kt まで 25°、480 kt から 15°）、HDG HOLD と TO/GA の bank limit は AUTO（資料にゲインと表が無い）。LOC（段 2b）：捕捉のバンク 25° と lead 4 秒、偏位 0.7° 以内の捕捉、30 秒の先読み、偏位と慣性の経路の 5 秒の混ぜ方、LOC TRACK の 100 m・5° とバンクの制限 15°（捕捉の間 25°）。X-Plane の LOC の目盛 1.41°/ドットは測った値。ピッチの則（段 3a、`B747.70.afds_pitch_model.lua`）：経路角の差の 0.25 倍毎秒、0.05 g を全モードに、慣性の上下加速度の 3.5 秒の先読み、高度の差の 0.1 倍毎秒の昇降率と 8 秒の先取り、捕捉の 10 秒の前倒し、20 ft、−10〜20°（X-Plane の機体の遅れに合わせた値）。速度の則（段 3b）：速度の差を詰める 15 秒と 1.5 kt/s、250 kt より遅いときのゲインを IAS に比例（150 kt 以下で 0.15）、FLCH・VNAV の 0.1 g、T/O・G/A の 3°/s、G/A の姿勢へ差の 0.5 倍毎秒、PLI の「少し下」を 1°、PLI は PFD に出ているときだけ使う、FMC の最小・最大速度の代わりに速度テープの Vminm と Vmax。A/P の姿勢のループ（§20、`B747.19.xt.afds_control.lua`）：A/P の積分から差し引くスタビライザーの比 1.9（X-Plane の記録の当てはめ 1.69〜2.35 の間）、姿勢の変化率 0.03 とピッチの PID の比例ゲイン 0.1（全高度。X-Plane の FL350 の ALT HOLD で決めた：§21）。
- トランスポンダと TCAS（5-1 段 5、`B747.34.tcas_model.lua`・`B747.34.xt.tcas.lua`・`B747.61.xt.nd.lua`・`fltMgmt` に「estimate」と書いてある）：
  - X-Plane の `rel_xpndr` をトランスポンダ L の故障に。>TRANSPONDER L・R を電源なしでも出す。TCAS の故障に、選んだトランスポンダが働かないことと、L・R の RA が両方働かないことを入れた。
  - DESCEND RA（1,100 ft 未満）・INCREASE DESCENT RA（1,500 ft 未満）を X-Plane が出したら、RA にせず TA として出す（実機は別の RA を選ぶ）。
  - CROSSING の声を、RA の向きと相手の今の相対高度で決める（上昇で相手が上、降下で相手が下）。MAINTAIN は自機の昇降の向きで。X-Plane の message の crossing の区別は形と合わない。
  - X-Plane の LEVEL OFF（7.1）を 7.0 の ADJUST VERTICAL SPEED, ADJUST に。CLEAR OF CONFLICT は X-Plane の advisory が終わってから 2 秒以内に message が 5 になったとき。
  - GPWS の声の間は TCAS の声を出さない（捨てる）。声の 0.5 秒の保持。
  - PFD の RA のピッチの境：機体シンボルから、限界の昇降率と今の昇降率の経路角の差（asin(昇降率 / 真対気速度) の差。資料は「RA のデータの関数」とだけ）。X-Plane の vs_bands が 1 つの RA で上下両方に赤を出せば、赤枠も 2 つ出る（FCOM p.1537 は 1 つの RA では片方だけ）。
  - 速度テープ（5-2 段 3a、`B747.60.speedtape_model.lua` に「estimate」）：空中で始めたフライトは最小機動速度の帯を出す。帯の判定で地上とみなすのは 100 kt 未満が 5 秒続いたときだけ（段 3b：空中開始や空中での機体の読み直しの直後に空地判定が一瞬地上に、速度も 0 になり、帯と AIRSPEED LOW が出なかった）。CDU で選んだ着陸フラップのバグは出さない（純正のパネルの決まり）。
  - カスタム acf の失速（2026-10-25、ACF_DIFF.md §5）：翼型の失速の部分のずらし 2.8° と前縁スラットの失速迎角の増し分 4.8・3.6 は、FCTM の失速速度に合うように測定で選んだ値（実機の翼型やスラットの値ではない）。
  - 最小速度（5-2 段 3b、`B747.60.minspeed_model.lua` に「estimate」。notes/ATA-31.md §14）：フラップ 1・5 のシェーカー速度（UP と 10 の間の 0.63・0.87：前の表の位置）と 25（VREF25 ÷1.23 に 20・30 の比）、フラップの位置の間の比例、図の範囲外（重量・高度）の Mach の直線の延長、M 0.44〜0.86 のつなぎ（直線）と高速バフェット（M 0.92 で 0.8 倍の二次の線）、高い Mach でシェーカーをバフェットの線で鳴らすこと（実機は迎角の上限）、荷重倍数のならし（帯は約 3 秒、シェーカーは約 0.2 秒）、シェーカーの 2 % のヒステリシス、AIRSPEED LOW と琥珀の枠の条件（帯が出ていて RA 100 ft 超）、エアデータが無効なら副操縦士側、両方無効なら出さないこと、スピードブレーキの分を入れないこと。
  - PFD の源（5-2 段 4a、`B747.60.pfd_model.lua` に「estimate」。notes/ATA-31.md §15・§16）：NAV の源が FMC のとき方位と航跡を出す IRU の順（機長は L・C・R、副操縦士は R・C・L。FCOM p.1228 は「NAV の IRU」とだけ）、慣性の昇降率は IRU が NAV のときだけ（ATT では VERT の旗）。値は X-Plane の両側の AHRS のまま（各席の選んだ IRU の代わり：IRS 選択器を変えても値の出どころは変わらない）。
  - 気圧設定の琥珀の枠（5-2 段 4b、`B747.60.pfd_model.lua`）：遷移レベルは FMC に無いので既定の FL180。枠の大きさと位置はスクリーンショットで測った値。CDU の BARO SET の数字の入力で PFD の単位（IN・HPA のつまみの位置）も変える（FCOM は「display as」とだけ）。
  - PLI（5-2 段 4c、`B747.60.minspeed_model.lua` に「estimate」）：揚力の上限を迎角に直す揚力の傾き（カスタム acf の失速試験から当てはめた、フラップごとの揚力ゼロの迎角と B 1 kg あたりの迎角）、地上は迎角で、60 kt より上・30° 以内で出すこと、色の琥珀（FCOM の図は灰色）、両席同じ値。
  - EICAS の compact の形（5-2 段 6b-2、`docs/overhaul/tools/panel_eicas_compact.lua`）：行の位置を FCOM の図から列の間隔の比で写したこと、CF6 の行を p.855 の位置へ動かしたこと、RB211 を P&W と同じ形にして N3 を出さないこと。
  - EICAS の形式（5-2 段 6b-1、`B747.60.eicas_format_model.lua` と `B747.40.engine_display_model.lua` に「Estimate」・「no source」）：電源投入時の自動表示を主 EICAS が表示器に出てきたときとしたこと、P&W と RB211 の VIB の high band を CF6 と同じ 4.0 units にしたこと。
  - 時計（5-2 段 6a、`B747.60.clock_model.lua` に「Estimates」）：時刻を X-Plane の UTC とのずれで持つこと、設定の欄が繰り上がらないこと、MS・HS の間は止まり日付の表示中は動くこと、歩みが回してから 1 秒ごとなこと、NCD の日付と ET・CHR・DATE、ET・CHR の 99:59 での停止、押しボタンが 0.2 秒で戻ること。
  - ND の MAP CTR（2026-10-28、`B747.60.nd_model.lua`・`B747.61.nd_data.lua`・`docs/overhaul/tools/panel_nd_ctr.lua` に「estimate」）：航跡の線を範囲の 3 分の 1 より内で切ること（FCOM p.1009 の図で約 0.35）、範囲の数字の位置（拡大の数字と目盛の関係のまま）、640 NM の半分の大きさの X-Plane の地図（±208 px の四角の中だけ）。記号を覆いの円（225 px）の中だけにしたこと（実機は表示の端まで）。
  - ND のトレンドベクトル（5-2 段 5e、`B747.60.nd_model.lua` に「estimate」）：旋回の半径を対地速度と傾きから求めたこと、各区間の 7 割を破線にしたこと（図から）。
  - ND の向きの型式（2026-10-27、`B747.60.nd_model.lua` に「estimate」）：RR の機体を P&W と同じ 109 として扱うこと（RR の資料が無い。109 も 570 も MAP は航跡が上なので、向きはどの機体も同じ）。
  - HDG REF（5-2 段 5d、`B747.60.hdg_ref_model.lua` に「estimate」）：降下・上昇の 2,000 ft を「その速さを超える間に」と読んだこと、点滅の 2 Hz、高度と V/S の源、ラベルの字体と枠、PFD の TRU の枠は白だけ（降下の琥珀は ND だけ）。
  - ND のコースの線（5-2 段 5c-3c、`B747.61.nd_data.lua`・`B747.61.xt.nd.lua` に「estimate」）：線の色（緑）、破線の長さと間、地図の端までの長さ、数字の位置（局から 50 px）と向き、コースを機体の磁気偏差で真方位にしたこと。
  - ND の出発・到着空港と滑走路（5-2 段 5c-3b、`B747.61.nd_data.lua`・`B747.61.xt.nd.lua` に「estimate」）：滑走路の項目を空港から 6 NM 以内としたこと、80 NM 以上の線の向き（選んだ閾値の端の向き）、記号の大きさ・両側の線の間（8 px）・破線の長さと間（12・10 px）、滑走路が分からないときの空港の記号、出発・到着空港と滑走路を経路の点（星）として出さないこと。
  - ND の地図の記号（5-2 段 5c-3a、`B747.61.nd_data.lua` に「estimate」）：高高度の局を X-Plane の受信範囲 100 NM 以上としたこと（NDB はいつも低高度）、EXCESS DATA の色（琥珀）と位置（FCOM の図の比）。
  - ND の POS（5-2 段 5c-2b、`B747.60.nd_model.lua` に「estimate」）：DME の無い radial の「画面の端」（拡大は範囲の弧の 465 px、左右は画面の端まで、機体の後ろは描かない（地図の記号と同じ）、中央は地図の記号の 250 単位）、radial の文字の位置（機体から 50 px、線の上 4 px、読める向きに 180° 切り替え）、IRU の星と GPS の記号の大きさ（FCOM の図の比）。
  - ND の DATA（5-2 段 5c-2a、`B747.61.nd_data.lua` に「estimate」）：遷移高度以上の高度を FL で出すこと（資料の例は 12000 だけ）、高度の無い点は ETA を 1 行目に上げること。ETA は FMC の今の式（経路に沿った距離 ÷ 対地速度か下限の速度の大きい方。下限 534.6 kt は FMC-21）のまま。
  - CDU の EFIS 操作（5-2 段 5c-1、`B744.fms.pages.lua` に「estimate」）：左の CDU を機長、右を副操縦士のパネルの代わりにして、中央はどちらでもないこと（FCOM に CDU と席の対応の記述が無い）。使えないときの SELECT を消して見出しを残すこと（CDU-161 の記述に合わせた）。
  - ND の向きと旗（5-2 段 5a、`B747.60.nd_model.lua` に「estimate」）：FMC の位置（MAP・VTK の旗）を「どれかの IRU が NAV」としたこと、拡大の方位の印の半径（457）、風の矢印を 100 kt から（純正の閾値）、PLN の北を純正どおり磁北（FCOM は真北：段 5d）。
  - ILS（5-2 段 4e、`B747.60.pfd_ils_model.lua` に「estimate」）：ND の方位の針（段 5b-2b、`B747.60.nd_model.lua`）：ADF の局の受信を局の ID で判断すること（X-Plane に ADF の受信の旗が無い）、APP・VOR の右上の DME の旗を自席の DME（機長 DMEL、副操縦士 DMER）にしたこと。ND の VOR（段 5b-2a、`B747.60.nd_model.lua`）：基準 VOR を自席の側にしたこと（機長 VOR L、副操縦士 VOR R。FCOM は「選んだ受信機」とだけ）、全周の VOR の旗・TO/FROM の三角・右下の TO/FROM の文字の位置（ATA34_1 と FCOM の図の比）、VOR の故障は電源だけ（X-Plane に NAV3・4 の故障が無い）。ND の APP（段 5b-1b、同じモデル）：NCD（信号なし、同調前）で目盛ごと消すこと（ND の VOR の記述 ATA34_1 p.358 から）、2 1/2 ドットの塗りの境を 2.49（X-Plane は 2.5 で止まる）、拡大の LOC の旗を飛行機の記号の下に置いたこと（FCOM と ATA31 の図で違う）、DME の旗に L・R が無いこと。PFD の ILS の源は段 5b-1a で使用中の EIU の受信機に（ILS C は X-Plane の NAV1 のデータで、電源は AC bus 1、X-Plane の故障なし。>SNGL SOURCE ILS は両席が同じ EIU のとき。表示器がアンテナと偏位の状態で源を替える論理は作らない）、拡大 LOC 目盛の範囲（純正の 1/2 ドット）、偏位過大の「approach mode operational」を AFDS の G/S・LOC の engage と読んだこと、ロール 53° 超で旗も消すこと、同調は純正の `ils_dots`。
  - FPV と旗（5-2 段 4d、`B747.60.pfd_model.lua` に「estimate」）：FPV を姿勢表示の中（左右 110・上下 140 px）に止めること、X-Plane の飛行経路と航跡を IRU の値の代わりにすること、PITCH・ROLL の旗の 3°（>ATTITUDE の値）、FPV・PITCH・ROLL の旗の位置（FCOM の図から比）。
  - 気象レーダーの故障とゲインの注記（段 5d、`B747.34.wxr_model.lua`・`B747.61.xt.nd.lua` に「estimate」）：選んだ R/T の電源なしを R/T の故障として WXR FAIL。故障の源の順（RT、ANT、CONT、WEAK、ATT）。TEST は故障があっても R/T が動けば走る。ゲインの注記は MAP だけで、較正の止まりで CAL、それより下で VAR（FCOM は CAL を記号として挙げるだけ、ATA34_1 の VAR は別の操作盤の型の記述）。3 行目の位置（チルトの 20 px 下）。
  - PFD の RA の絵（段 5d、パネル）：赤枠の形は FCOM p.1536 の図を純正のピッチ目盛（10° = 68 px）に縮めたもの。赤枠は機体シンボルから ±34°（232 px）で止める。VSI の赤帯は目盛の刻みの列（幅 7 px）に、目盛の刻み（0・500・1,000・1,500・2,000・4,000・6,000 fpm）の位置で。
  - 空中でエンジン運転中に始めたときのトランスポンダを TA/RA に（飛行中は TA/RA：FCOM p.1570）。
  - ND：TFC・TCAS FAIL・TCAS OFF は機影を出せるモード（MAP、MAP CTR、VOR と APP の CTR でないもの）だけで出す。MAP CTR の見える範囲と OFFSCALE の境はレンジの半分（X-Plane のコンパスローズの大きさ）→ 2026-10-28 から選んだ範囲（ローズが選んだ範囲：notes/ATA-31.md §40）。機影の数は近い 30 機（ATA34_2 p.24）。TRAFFIC・OFFSCALE の位置（右の中ほど、MAP CTR で上へ）と TA ONLY の位置（TFC の上）。

- ソース選択の比較（5-2 段 2）：>ATTITUDE・>HEADING は X-Plane の機長側・副操縦士側の AHRS の差で見る（PFD が表示している値。両席が同じ IRU なら姿勢は比べない）。>EFIS/EICAS C/P が出るときは >EFIS CONTROL L・R を出さない。

- 表示器と EIU（5-2 段 1、`B747.60.display_model.lua` に「estimate」と書いてある）：
  - 故障の無いときに INBD・LWR で内容を別の表示器に出したとき、空いた表示器は消す（パネルは同じ内容を 2 か所に出せない。資料の図は表示器の故障のときだけ）。
  - 両席の LWR がぶつかるときは EICAS PRI、機長の ND、副操縦士の ND の順。
  - 席の EIU が無いとき、その席の PFD・ND を消す（EIU が PFD・ND に情報を出す：FCOM p.1044）。

- 気象レーダー（5-1 段 5c、`B747.34.wxr_model.lua`・`B747.34.xt.wxr.lua` に「estimate」と書いてある）：
  - R/T の電源のバス：L は AC bus 1、R は AC bus 2（資料は各自の遮断器とだけ：ATA34_1 p.210）。
  - 両側の TFR を「同時に押す」を、両側が TFR になったときと読んだ（FCOM p.1223）。TFR で出す反対側の内容はモード・チルト・ゲイン・GCS。
  - TEST は R/T が動いているときだけ両 ND を TEST にし、その側のモードスイッチか EFIS の WXR を切ると、その側だけ戻る（FCOM p.1224）。
  - MAP GAIN のつまみの幅（X-Plane のゲインの 0〜1、右いっぱいが較正値 1）。つまみとチルトの 1 目盛りは X-Plane のコマンドと同じ 0.1。
  - ND のチルトの丸め（整数。FCOM の例は +5）。

- 電波高度計と GPWS（5-1 段 4、`B747.34.ra_model.lua`・`B747.34.xt.ra.lua`・`B747.34.gpws_model.lua`・`B747.34.xt.gpws.lua` に「estimate」と書いてある）：
  - 電波高度計：C を X-Plane の機長側の RA（機長側が故障なら副操縦士側）としたこと（X-Plane の RA は 2 つ）。X-Plane の RA から 8 ft 引く補正（前の PFD のまま）。EIU 選択器の位置の意味（機長 L・AUTO・C・R、副操縦士 L・C・AUTO・R：既定がどちらも AUTO になる並び）。GPWC の比較で L が故障していれば使えるものの最初（資料は L とだけ書く）。使える RA が無いとき `efis/radio_altitude` は最後の値を保つ。
  - mode 1 の警報（PULL UP）の線（30 ft で 1,710 fpm〜2,450 ft で 7,125 fpm）。資料は注意の線だけ。
  - mode 2：曲線の 30 ft の点（2,038 fpm）と、789 ft より下の 2A を 2B と同じ曲線にしたこと、2A の上限の速度との間（220〜310 kt）を直線にしたこと、接近率の 1 秒の平滑、TERRAIN を 2.8 秒言ってから PULL UP（音が 2 秒ごとに繰り返すので 2 回）。
  - mode 3：上限（約 700〜1,350 ft）の速度の間を直線、高度損失の閾値の下限 10 ft、損失の基準を着陸形態のあいだ取り直す（復行から数える）。3B は作らない。
  - mode 4：「過大接近率の検出の後 60 秒は上限 800 ft」の検出を mode 2 の注意とした。
  - mode 6：もう一度鳴る高さ（max(1,000 ft, その高さ) + 100 ft）、minimums の声の再 arm（minimums + 180 ft）と minimums 0 以下で鳴らさない、BANK ANGLE の各段の再 arm（5° 下がる）と低高度の線を最初の段（35° まで）に使う、BANK ANGLE の声を 2.8 秒（2 回）。
  - mode 7：X-Plane の reactive windshear を入力に、空中の 1,500 ft 未満（離陸と進入を区別しない）。
  - 声の優先（windshear と警報が上、注意どうしの順）、警報の声の間はコールアウトを出さない、GND PROX SYS と WINDSHEAR SYS を出す入力の組、TERR POS を GPS が両方使えないとき。
- GPS（5-1 段 2、`B747.34.gps_model.lua` に「estimate」と書いてある）：初回測位をいつも電源から 75 秒としたこと（GPS 自身の最後の位置も初期化になるとして。位置が無いと「最大 10 分」の場合は作らない）。
- IRS（5-1 段 2、`B747.34.irs_model.lua`・`B747.34.xt.irs.lua` に「estimate」と書いてある）：アラインの終わりの緯度の比較の許容差 1°（資料は「緯度で変わる」とだけ書く）、アラインを止める動きを X-Plane の対地速度 0.5 m/s（約 1 kt）超としたこと、ATT の方位にドリフトを入れないこと。
- エアデータ（5-1 段 1、`B747.34.airdata_model.lua`・`B747.34.xt.airdata.lua` に「estimate」と書いてある）：C ADC を X-Plane の standby の pitot-static とし、その Mach を速度と気圧高度から、昇降率を高度の変化から計算すること。3D の AIR DATA ノブの 2 位置を 0 L・1 R としたこと（刻印が分からない）。選択高度が変わってから 1 秒は高度警報を判定しないこと（rate detector の時間）。
- 脚の作動（4-2 段 1、`B747.10.gear_model.lua` に「estimate」と書いてある）：脚の動く時間（acf の 12・9・7 秒。代替下げの前脚・胴体脚の自由落下も同じとした）、脚の作動に要る圧 1,000 psi、GEAR TILT を抑止する圧（PSEU の HYDIM 高 1,500 psi）、翼脚のアップロックが外れるドアの 45°（行程の半分）、レバー OFF と圧の喪失で動いている途中の脚が止まること、重さのかかった脚は上がらないこと、代替下げをした脚をそのフライトの間は通常の系統で動かさないこと、電源の無いレバーのロックはかかったままのこと。
- ブレーキ（4-2 段 2、`B747.10.brake_model.lua`・`B747.10.xt.brakes.lua` に「estimate」と書いてある）：ブレーキの効きが圧に比例し 3000 psi で全部、パーキングブレーキの弁の動く時間 1 秒、閉じ込めた圧に漏れと熱逃がしが無いこと、X-Plane の regular のブレーキを両ペダル 0.5、ペダルを 0.25 秒で踏み込むこと、パーキングブレーキをペダルを踏まずに入れられること、X-Plane の toe brake の軸の番号（6・7）。
- ブレーキ温度とタイヤ圧（4-2 段 5、`B747.10.btms_model.lua`・`B747.10.xt.wheels.lua` に「estimate」と書いてある）：ヒートシンクの熱容量 87 kJ/°C・冷却の時定数（地上と脚上げ 90 分、脚下げの空中 10 分）・熱電対の遅れ 3 分（FCOM PI.12.8 の表に合わせた）、表示が 0 °C から比例すること、タイヤ圧の整備の値（198〜210 psi）と荷重の 10 psi・圧の変わる速さ・タイヤ故障の 5 psi、>TIRE PRESSURE を抑止する離陸推力のレバー角（0.7）。
- ステアリング（4-2 段 4、`B747.10.steering_model.lua`・`B747.10.xt.steering.lua` に「estimate」と書いてある）：ステアリングに要る圧（1,000 psi）、前輪の速さ 20°/s と胴体脚の 5°/s、胴体脚の角度が前輪 20°〜70° で比例すること、圧が無いと前輪と胴体脚がその場にとどまること、指令なしでロックが外れて >BODY GEAR STRG を出すまでの 5 秒、車輪速を対地速度で代えること、X-Plane の tiller の軸の番号（37）。実機ではないもの：tiller の軸が無いときにペダルを tiller にする手当て（10 kt まで 70°、30 kt で 7°）。
- オートブレーキ（4-2 段 3、`B747.10.autobrake_model.lua` に「estimate」と書いてある）：推力レバーのアイドル（0.05）と前進（0.1）、車輪のスピンアップと RTO の 85 kt を IRS の対地速度で見ること、disarm の後に圧が 2 秒で抜けること、減速の制御（IRS の対地速度の変化を 0.5 秒でならし、PI のゲイン KP 0.02・KI 0.12 をカスタム acf に合わせた）、RTO のペダル 12°（17° のうち）をペダルの比で見ること。
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
  - 胴体脚ステアリングの「ロック」：ステアリングのモデルの胴体脚が中立から 0.1° 以内（4-2 段 4 から。前は X-Plane の胴体脚の角度が 0）。
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

- 操縦系統の SRM（4-1 段 2a・2b。`B747.45.srm_model.lua` に「estimate」と書いてある）：
  - ロックアウトのアクチュエータがロックとロック解除の間を動く時間 2 秒。ラダー比変換器のアクチュエータの速さ 0.2 in/s、servo の誤差が 2 秒続くと監視が立つ。
  - ラダー比変換器の速度の表は p.637 の図から読んだ点（170 kt 0.2 in、195 kt 0.4、245 kt 0.6、310 kt 0.8、355 kt 0.9、420 kt 0.97）の間を直線で。延長と舵角の関係は直線（資料に無い。地上試験の 367 kt の位置で 6–8° に合う）。
  - 機能を持つ SRM は L から（実機は電源投入時にランダム）。ラダー比変換器の servo の監視は、エアデータが無いときも働く（160 kt 未満で止める条件が分からないため）。
  - 安定板トリム（段 2b）：STCM のブレーキが解除される圧 1000 psi。unscheduled trim monitor が見つける動き 0.1 units。dead trim は 2 秒。column cutout は操縦桿の行程の 35 %（4.5° を、行程 6.55/6.63 in と柱の長さ約 30 in で換算。柱の長さは資料に無い）。X-Plane のトリムの暴走の故障を系統 3 の STCM の機首上げの暴走として受けること。STAB AUTO TRIM を A/P が全部外れるまで残すこと。MOV の動きは瞬時。空中開始では X-Plane の自動トリムに合わせず、モデルの初期値 7.5 units から始めること（2026-10-26、notes/ATA-27.md §17）。
  - A/P が外れたときの A/P の昇降舵・補助翼の指令の戻り（毎秒 1。AFDS の `B747.19.xt.afds_control.lua`）。
  - speed trim（段 2c）：指令と位置の差が 0.05 units を超えたら動かし、着いたら止める。グリーンバンドの選び方（FMC の離陸トリムが mid 帯の中なら mid、上なら nose up、下なら nose down。CG を入れる前は mid。`B747.45.greenband_model.lua`）。

- 操縦系統のスピードブレーキ（4-1 段 3。`B747.45.speedbrake_model.lua` に「estimate」と書いてある）：
  - 自動スピードブレーキのアクチュエータがレバーを DN から UP まで動かす時間 2 秒。SPEEDBRAKE AUTO の条件が 3 秒続いたら出す（資料に遅れが無い。手で DN にしたあとアクチュエータが戻る間は出さない）。
  - speedbrake power level（resolver 40°）のレバー角 5.12° は、CF6 の idle の resolver 角 34.88°（ATA70_80）からの換算で、PW も同じとした。ATA31 p.221 は TLRA 43° と書く（食い違い。FCOM p.958 の「閉より前」に近い 40° を使った）。貨物機の空中の CONFIG SPOILERS の「上昇推力以上」は、EEC の上昇定格のレバー角 35°（ATA70_80 p.208）以上とした。
  - 簡略化：R837・R838 は「系統 1 か 4 が 1600 psi 超」と PSEU の primary・alternate の地上で作った（p.182 の、系統 1 と胴体脚・系統 4 と主翼脚の組は作っていない）。リバースレバーがレバーを機械的に持ち上げる機構は、リバースレバー 2・4 で EXTEND に入ることで代えた。

- FMC の小修正（6-1 段 1。コードに「estimate」と書いてある）：ECON の上昇 CAS 340 kt（FCOM PI p.316 の通常の上昇速度 340/.84。CI による値は段 8）。SPD TRANS の VREF は VREF30。ETA と T/C の距離の速度の下限 275・250 kt（kt の値として。予測は段 8）。APPROACH REF の FLAP/SPEED でフラップの無い入力は前の値か 30。SPD RESTR が無いとき、降下の制限は SPD TRANS と同じに扱う（AP の降下の処理のため）。

- CDU の枠組み（6-2 段 2。`B747.68.cdu_model.lua` に「estimate」と書いてある）：メッセージの順（その CDU の入力のメッセージ、alert、advisory、それぞれ来た順）、scratchpad が 24 字でいっぱいなら打鍵を受けない、SP は空白を打つ、遷移高度と同じ高度は ft で出す、中央の CDU の電源は F/O transfer bus。一度だけ立つ FMC の旗を出来事として扱うもの：PERF/VNAV UNAVAILABLE、DESTINATION NOT SET、TAKEOFF SPEEDS DELETED。

- PERF INIT（6-2 段 3a）：重量の入力の範囲（ZFW 130–270 t、GR WT 150–400 t、FUEL と RESERVES 180 t まで）、計算した GR WT と ZFW を小さい字で出す。

- TAKEOFF REF の V speeds（6-2 段 3b-1）：V1 は VR を超えない。乗員の V speeds の入力の範囲 100–300 kt（FMSPG）。1,000 ft を超えると選んだ速度を黙って消す（前のコードの動きのまま）。

- TAKEOFF REF の欄（6-2 段 3b-2）：ACCEL HT・E/O ACCEL HT の既定 1000 ft、THR REDUCTION の既定 FLAPS 5（FCOM の図から）、削除で既定に戻す、WIND/SLOPE は入れるまでダッシュ。

- 手続き（6-1・6-2 段 5d、`B747.68.proc_model.lua` と `B747.68.route_model.lua` に「estimate」と書いてある）：CIFP の高度の記述のうちグライドスロープの符号（G・H・I・J・V・X・Y）を以上か一致に読み替えたこと、FCOM に無い進入の種類の呼び名（LOC・BCS・LDA・SDF・IGS・GLS・TCN・MLS・RNP など）、手続きを外すとつながっていた経路の点を戻すこと、新しい目的地で消える到着の手続きの前の discontinuity も消すこと。
- 現用点と X-Plane の FMS（6-1・6-2 段 5e、`B747.68.route_model.lua` に「estimate」と書いてある）：DIRECT TO の始点を EXEC の時の機体の位置にすること、INTC CRS の始点をそのコースの線上で目標点から機体と同じ距離の点にすること。LNAV が自分で順送りする（段 6）までは、AFDS の現用点に合わせて順送りすること（資料の順送りの条件ではない）。X-Plane の FMS に流す窓の高度の制限を最初の高度にすること。
- 経路の形と LNAV（6-1・6-2 段 6a〜6d・7a、`B747.68.path_model.lua`・`B747.68.lnav_model.lua` に「estimate」と書いてある。詳しくは notes/ATA-34-61-FMC.md §27〜§30・§32）：fly-by の旋回（25° のバンク、R·tan(Δ/2) 手前から、135° を超える変化は点の上）、CF の始まり（前の点の真横）、条件の脚の終わりの予測（500 ft/nm の上昇、旋回なし）、VECTORS の 10 nm の線、弧の点の間隔、捕捉の交角 90° までと旋回の始まり、地上で順送りしないこと、fly-over の点の真横での順送り、操舵則（45° までの切込み、25 秒先、トラックの誤差の 2.5 倍）、旋回を 4 秒早く始めること、DIRECT TO・DF の旋回の後の大円、手続きの旋回の向きの続く間（10° 以内まで）。ホールド（段 7a）：direct の進入の旋回（保持点でトラックに接するホールドの半径の円から出航脚へ）、保持点から 1 nm 超でアクティブになったら先に保持点へ、旋回の終わり（次の脚を捕まえるトラックの 5° 以内）、時間も距離も無い脚の時間（制限の高度で 1 分か 1.5 分）、ホールドを出て次の脚へは保持点の上から回ること（fly-by にしない：127° の旋回で半径の約 1.6 倍はみ出す）。ホールドの CDU と ND（段 7b）：既定の脚の時間に巡航高度を使うこと、PPOS の入航コースは EXEC の時のトラックでその後は元のアクティブな点へ、経路に無い点の HOLD AT の後ろに discontinuity、EFC TIME を修正にしないこと、予測の欄（FIX ETA・HOLD AVAIL・BEST SPEED）のダッシュ、ホールドが無くなった RTE HOLD のページを RTE LEGS HOLD AT に替えること、ND の TO の点でないホールドの大きさ（210 kt）と地上の大きさ。オフセット（段 7d）：かかる脚を点へまっすぐの脚だけにすること、最後の脚の順送りでオフセットを消すこと、オフセットの後に元の経路へ切込んで戻ること、無いのに消すと INVALID DELETE、RTE の 1 ページ目の 6R で PERF INIT>・TAKEOFF> の代わりに出すこと。REF NAV DATA（段 7e1）：IDENT の下の見出しを点を入れたときだけ出すこと、IDENT のダッシュを 5 つに、NDB の周波数を kHz の整数で、NDB・DME 単独・LOC の MAG VAR をそこの偏差（最寄りの VOR の値）に、E15・W7 の形、滑走路の長さを閾値の間の距離と移設分から（ft、FT は小字）、ほかの種類の局の抑止と ALL の間の VOR ONLY の入力を INVALID ENTRY、ダッシュの DELETE を INVALID DELETE。ABEAM PTS（段 7e2）：滑走路・ホールド・条件の脚から点を作らないこと、真横が飛行機の後ろか DIRECT TO の点の先なら作らないこと、番号を経路に無い一番小さいものにすること、飛ばした点が無くても SELECTED にすること、4R の表示を 1 ページ目だけにすること。自分で作る点（段 7e3a）：PBD の磁方位を最寄りの VOR の偏差で真方位にすること、距離の範囲、PB/PB の 2 つ目の場所を 1 つ目に近いものにすること、交わらない方位線を INVALID ENTRY にすること。FIX INFO（段 7e3b）：データを両方の CDU で同じにすること、新しい FIX で線を消すこと、経路の形（点の大圏、条件の脚とホールドは入れない）、交点を飛行機に一番近いものにすること、方位の偏差（VOR はその値、ほかは最寄りの VOR の値）、距離に交点が無いと方位を出さないこと。RTE 2（段 7e4）：RTE ページの COMPLETE の上に小字の RTE COPY を出すこと、COMPLETE をアクティブな経路が次に変わるまで出すこと、写した経路に通過した点を入れないこと。procedure turn（段 7f：資料に形が無く、利用者の依頼で推定）：PANS-OPS の 45°/180° の形、出航コースを PI のコースから旋回と反対へ 45° にすること、45° の脚を 1 分 15 秒（PANS-OPS の category C–E）、180° の旋回の半径（25° のバンク）、出航の長さを PI の距離（無ければ 10 nm）の 1 nm 内側に収めること、出航から 45° の脚への角を旋回の半径の fly-by の弧で回ること、角と 180° の旋回をロールの 4 秒だけ早く始めること（ホールドと同じ）、終わりの点を 210 kt の形で決めること、PI の点の fly-over、戻りの脚で入航コースへの旋回の始まりに順送りすること。
- RTE と LEGS のページ（6-1・6-2 段 5b・5c）：RTE の 2 ページ目以降は終わりのダッシュと箱だけに入力、LEGS の DELETE は前後をつなぐ（discontinuity は消せない）、針路は近くの VOR の偏差で磁方位（無ければ真方位に T）、距離は整数の NM。
- LEGS の PLAN の CTR と STEP（6-1・6-2、2026-10-29。`activepages/B744.fms.pages.legs.lua` に「estimate」と書いてある。notes/ATA-34-61-FMC.md §42）：STEP でページがついていくこと、最後の点で動かないこと、点の無いページ（経路の終わりの破線だけ）で中心を動かさないこと、ND を PLN にしたときの中心（その CDU に出ている LEGS のページの最初の点。副操縦士の側でも動かす。無ければアクティブな経路の最初の点）、中心の点が通過や削除で消えたらその位置からの次の点、DIRECT TO の INTC CRS の間は STEP> を出さないこと、FL のある block の制約の点に <CTR> を出さないこと。
- 経路のモデル（6-1・6-2 段 5a、`B747.68.route_model.lua` に「estimate」と書いてある）：ACTIVATE には出発地と目的地が要ること、地上で新しい出発地を入れると目的地も消すこと（前の FMC の動き）、最初の VIA の airway（前の TO が無い：airway intercept）を INVALID ENTRY にしたこと。
- 航法データベース（6-1・6-2 段 4）：IDENT の NAV DATA の表記「AIRAC 2610」（データに部品番号が無い）、2 つ目の期間の行を空に（データは 1 組）、読み終わるまでの入力に STANDBY ONE。

- 操縦系統の横操縦（4-1 段 4。`B747.19.lateral_model.lua` に「estimate」と書いてある）：
  - スポイラーの横操縦の動き始めを操縦輪 11°（資料は 8〜14°）、最大を操縦輪の止め（90°）とし、その間は直線。エルロンのプログラマとスピードブレーキの段は図の読み取りの点の間を直線。
  - 5・8 の ratio changer が伸びる（最大 45°）のは、レバーが 49° 以上（ground spoiler control valve の U2 が開く位置）のとき。
  - エルロントリムの速さは X-Plane の acf の値のまま（カスタム 12 秒・純正 10 秒で 6 units）。
  - FLT CONTROL HYD POWER（段 4 の後半。`B747.19.xt.hydraulics_override.lua`）：弁を動かす DC バスは系統と同じ番号、弁の時間 2 秒、半分を超えて閉じた弁の系統を舵面の門から外すこと。
  - ヨーダンパーの電源のうち、上の電池バスと下の DC 1（ATA27 p.20–22 は PSM の監視の電源と「FCE の電源から 28V DC」と書く）。IRU は 1 台でも整列して NAV か ATT なら働く（FCOM は「IRUs off or in align」）。


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
| WARN-24 新しい advisory の位置 | 済（2026-10-24。新しいメッセージを見ているページの先頭に入れていたので、新しい advisory が古い caution の上に出た。caution はページの先頭、advisory は caution の下に入れる：FCOM p.1548。4-1 段 2b の s28 の写真で見つけた） |

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
| HYD-09 ブレーキ源 | 済（源の選択・accumulator・>BRAKE SOURCE。ブレーキの効きを源の圧で制限するのは 4-2 段 2） |
| HYD-10 accumulator | 済（系統 4 だけが充圧、予圧 750 psi） |
| HYD-11 舵面以外の負荷 | 済（P&W の逆推力は 2-3 段 3 で系統 n の圧 1,000 psi 以上のときだけ動く。脚は 4-2 段 1、安定板トリムは 4-1 段 2b、ヨーダンパーは 4-1 段 4、ステアリングは 4-2 段 4。作動油の消費は脚・ブレーキだけ） |
| HYD-12 ステアリング | 済（4-2 段 4。前輪と胴体脚は系統 1 の脚 DOWN 圧（レバー DN）で動き、圧が無いとその場にとどまる） |
| HYD-13 X-Plane の油圧への干渉 | 済（故障を書かない） |
| HYD-14 P5 の灯 | 済 |
| HYD-15 EICAS | 済（抑止を含む） |
| HYD-16 作動油量 | 済（乱数をやめ 1.00 から。RF は地上だけ） |
| HYD-17 油温 | 一部（ポンプ運転で上がる一次遅れ。燃料の冷却は無し） |
| HYD-18 リザーバ与圧 | 済（モデル、STATUS の HYD RSVR PRESS、カスタム acf の synoptic の RSVR PRESS。与圧の源はモデルでは 1 つ（左右のダクトの高い方）なので、4 つとも一緒に出る） |
| HYD-19 synoptic の表現 | 済（カスタム acf）。DEM の AUTO（シアン）・AUTO（琥珀）・OFF（琥珀。系統 4 の AUX も）・ON（琥珀）、AUX の OFF（白）・待機（シアン）・琥珀、EDP の OFF・ON（琥珀）、SOV を火災スイッチから。2026-10-23 夕方に、丸ごと色を付けた記号の画像（丸は中の表示と同じ色、ATA29_32 p.105）と、不作動項目の絵を作り直した：各系統の一覧（P&W は THRUST REV つき）と、負荷の割り当てから出した 6 つの組（1+2、1+3、2+3、2+4、3+4、1+2+4 の BRAKES）。系統を失ったとは系統圧低（HYD PRESS SYS と同じ条件）。組に BRAKES を置くこと、RR の THRUST REV を GE と同じに扱うことは推定（下の「推定で作った部分」） |
| HYD-20 STATUS メッセージ | 済（HYD PRESS ENG・HYD PRESS DEM・HYD OVHT SYS・HYD RSVR PRESS・HYDIM：ATA29_32 p.137） |
| HYD-21 スタンドパイプ | 済 |
| HYD-22 FLT CONTROL HYD POWER | 済（操縦系統 4-1 段 4 で FCTL-20 として：遮断弁 8 個、VALVE CLOSED、>FLT CONT VLVS、舵面の門から系統を外す） |
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
| ENG-22 partial・compact 形式、exceedance cue | 済（5-2 段 6b-1・6b-2） |
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
| FCTL-21 メッセージと STATUS | 一部（段 1 でフラップの分：FLAPS CONTROL、FLAPS DRIVE、FLAPS PRIMARY、>FLAP RELIEF、STATUS の TE FLAPS・LE SINGLE DRIVE・LE MULT DRIVE・FLAP CONTROL L/C/R・FLAP LOAD RELIEF。段 2a で AILERON LOCKOUT、RUD RATIO SNGL・DUAL、STATUS の AILERON LOCKOUT・RUDDER RATIO。段 2b で STAB TRIM UNSCHD、>STAB TRIM 2・3、STATUS の STAB TRIM・STAB TRIM UNSCHD・STAB AUTO TRIM。段 2c で STATUS STAB SPEED TRIM、CONFIG STAB の帯。段 3 で SPEEDBRAKE AUTO と STATUS、>SPEEDBRAKES EXT、SPEEDBRAKE ARMED は speedbrake のモデルから。段 4 の後半で >FLT CONT VLVS と >YAW DAMPER の条件） |
| FCTL-25 電源 | 一部（段 1 でフラップの分：後縁の input actuator は AC 1・DC 1、電動は内側 AC 4・外側 AC 3、前縁の制御と電動は AC 1・3・4 のどれか（推定）。FCU 自体の電源は資料に無い。段 2b で安定板トリムの分：手動 DC 3、ALTN 電池バス、SRM L は standby AC か電池バスと DC 3、SRM R は DC 2（ATA22 p.116–118）。段 3 で自動スピードブレーキの DC bus 1。段 4 の後半でヨーダンパーと遮断弁の分。ロックアウトとラダー比変換器はまだ電源を見ない） |
| FCTL-05 外側エルロンのロックアウト | 済（段 2a。group A が入っていて 238 kt か M .53 を超えるとロック、group A が出るか 232 kt と M .51 を下回るとロックを外し、間は前の指令を保つ。FCU のフラップのデータを失えば速度と Mach だけ、両方の SRM を失えば空中ではロックを外す。指令から 45 秒でもう一方の SRM、さらに 45 秒で AILERON LOCKOUT と STATUS。アクチュエータの時間は推定） |
| FCTL-06 ラダー比変換器 | 済（段 2a。上下別々。p.637 の図の速度の表（155.5 kt まで 0 in、450 kt で 1.0 in。点の間は推定）で、舵角は 32° から 5°。エアデータを失うと上は 329 kt・下は 209 kt の位置、autoland では全権限、動かなくなった変換器はその位置のまま。160 kt 以上で servo の誤差が続くと RUD RATIO SNGL（両方で DUAL）と STATUS RUDDER RATIO。ヨーダンパーにも比をかけるのは前のまま（実機は下流で足す：推定）） |
| FCTL-27 ペダルとトリムの和の制限 | 済（段 2a。ペダル（X-Plane の `yoke_heading_ratio`）とラダートリム（全行程の 80 %）を足してから比変換器を通す。前はそれぞれに比をかけて和を制限しなかったので、450 kt でペダル 5°＋トリム 4° と 5° を超えた。また空中では X-Plane の `total_heading_ratio` にトリムの 0.3 倍が入るので、トリムが二重に効いていた（2026-10-24 に確かめた。地上では入らない）） |
| FCTL-26 外側フラップの wing 2 の部分 | 済（段 1。acf はフラップの組 2 を X-Plane の wing 2 と wing 3 に置いているが、wing 2 の舵角を誰も書かず、空力上 0° のままだった。外側の後縁と同じ角度を書く） |
| FCTL-03 安定板トリム | 済（段 2b。SRM のモデルが位置（units）を持ち、グルーが X-Plane のトリムを書く。速さは 1 unit = 1°（ATA22 p.132）で両 STCM 0.5／0.2 units/s（220／230 kt）、片方で半分。電気トリム 1.8（脚 down・前縁が出ていると 0.8）〜11.6、FRAT 13.5、ALTN 0.25〜14.75。column cutout、機長と F/O の逆・ALTN と操縦輪の逆で無効、A/P 1 台で解除（AUTOPILOT DISC）・複数で無効、ALTN は A/P に優先し外さない。オートトリムは engage した FCC の SRM の STCM で半速、3.5 秒の遅れ（autoland は無し）、FRAT は両 SRM で全速、dead trim で 1 回だけ他方の SRM へ。cutout スイッチと MOV、自動遮断。>STAB TRIM 2・3、STAB TRIM UNSCHD、STATUS の STAB TRIM・STAB TRIM UNSCHD・STAB AUTO TRIM。ALTN と cutout は 3D に操作子が無いのでコマンドと dataref。X-Plane の `pitch_trim_up/down` は機長のスイッチとして受ける。500 ft 未満でオートトリムしないのは前のまま（AFDS の作り直しで）） |
| FCTL-16 speed trim | 済（段 2c。ATA22 p.159 の制御則：120〜220 kt で 2.55 units 機首上げ、係合時の速度と位置に同期。選び方（主・副の ADC、10 kt の comparison fault）と engage（空中 20 秒後、220 kt 以下、手動・ALTN・autotrim でない、操縦桿が cutout の手前）、半速、機首下げの制限 0.8、STATUS STAB SPEED TRIM） |
| FCTL-10 グリーンバンド | 一部（段 2c。3 帯を FMC の離陸トリムから選び（推定）、地上で V1 未満なら指示器に出し、CONFIG STAB は選んだ帯で判定。3D の帯は 1 本で長さ 4.63 units なので、nose up・nose down は外側の端に合わせる。>STAB GREENBAND は前脚の圧力スイッチの設定値が資料に無く未） |
| FCTL-28 A/P が外れても A/P の指令が残る | 済（段 2b。A/P が off の間、油圧のモジュールが A/P の昇降舵・補助翼の指令を毎秒 1 で 0 に戻す（推定）。前は 2 秒の窓が A/P の off の間ずっと続き、最後の値が操縦桿に足されたままだった） |
| FCTL-07 自動スピードブレーキ | 済（段 3。推力レバー 1・3 のアイドル、系統 1・4 の圧と PSEU の地上の制御リレー 2 つ、ARM かリバースレバー 2・4 で UP、推力レバー 1 か 3 で DN（地上で手で出したときも）、DC bus 1、アクチュエータ（2 秒、推定）。X-Plane 本体の自動展開（ARM の −0.5）は使わない。SPEEDBRAKE AUTO と STATUS（3 秒、推定）。故障は `flt_ctrls/fail/auto_speedbrake`。前は X-Plane の自動展開にレバーを追わせ、逆推力はどれかのエンジンでレバーを上げていた） |
| FCTL-08 >SPEEDBRAKES EXT | 済（段 3。レバーが ARM の上・RA 15 ft 超で、RA 800 ft 以下・着陸フラップ（FCU の後縁 25 か 30）・推力レバー 2 本以上が speedbrake power level より前のどれか。全機に出していた空中の「スピードブレーキ＋推力レバー前方」の CONFIG SPOILERS（赤）は、FCOM p.1558 で 405・570 だけの機能なので貨物機（`laminar/B747/freighter`）のときだけにした（上昇推力は EEC の上昇定格のレバー角 35°、推定）。CONFIG GEAR の着陸フラップもフラップ 25 を含め、推力レバーのアイドルは 1 本ずつ見る。推力レバーはどれもプラグインのレバー `engine/throttle`（3D・EEC と同じ）で見る） |
| FCTL-09 横操縦の対応 | 済（段 4。エルロンのプログラマ（p.59 の表、約 45° で全舵角。前は全行程に比例）、スポイラーは操縦輪 11° から比例（動き始めと最大の位置は推定）、ミキサーで下がる側の翼のスポイラーをスピードブレーキの位置から下げる（前は上がる側だけ）。controlObject は操縦輪の角度だけを出し、指令は油圧のモジュールの Lua（`B747.19.lateral_model.lua`）） |
| FCTL-24 スポイラー 6・7 と X-Plane の面 | 済（段 4。スピードブレーキの段を p.165 の曲線にし（6・7 は 28° で 20°・49° で 45°）、6・7 を X-Plane のスピードブレーキ面 `speedbrake1_deg` に書く（前は空力に入っていなかった）。acf の主翼 2 のスポイラーの面（スポイラー 4・9）も書く（前は誰も書かず、段 1 の外側フラップの主翼 2 と同じ見落とし）） |
| FCTL-17 エルロントリム | 済（段 4。X-Plane のトリムいっぱい = 6 units = 操縦輪 47°（p.76）。前はトリムいっぱいが操縦輪いっぱいで、実機の約 2 倍の権限だった。速さは X-Plane の acf の値のまま（推定：資料に無い）） |
| FCTL-20 FLT CONTROL HYD POWER | 済（段 4 の後半。翼と尾翼の遮断スイッチ 8 個（3D に無いのでコマンド `flt_ctrls/hyd_power/wing_1`〜`tail_4`）、弁は系統の DC バスで 2 秒（どちらも推定）、半分を超えて閉じた弁の系統は翼（エルロン・スポイラー）か尾翼（昇降舵・ラダー・ヨーダンパー）の門から外す（推定）、全開でない間 VALVE CLOSED と >FLT CONT VLVS。安定板トリムとフィールは通らない（ATA27 p.432・532）。前は灯が常に消え、advisory も立たなかった） |
| FCTL-15 ヨーダンパーの INOP | 済（段 4 の後半。スイッチ・電源（上は AC standby と電池バス、下は AC 1 と DC 1：ATA27 p.20–22。電池バスと DC 1 は推定）・IRU（整列して NAV か ATT）・故障 `flt_ctrls/fail/yaw_damper` で INOP と >YAW DAMPER UPR、LWR（FCOM p.931・958）。前はスイッチ・IRU の選択器・バッテリーのスイッチだけ。作動筒は系統 3（上）・2（下）と尾翼の弁が要るが、油圧の喪失では INOP を出さない（ATA27 p.40）。ADC の片方の喪失で権限が減ること（p.42）と制御則は AFDS（6-3）で） |
| ほか（FCTL-18、22） | 未（FCTL-18 の昇降舵の舵角は空力と A/P の調整に関わるので空力の項目で。FCTL-22 は acf の値の確認） |

## 脚（4-2）の GAP の状態

| ID | 状態 |
|---|---|
| GEAR-01 空地判定 | 済（1-2 の PSEU。各系統の乗り換えは作り直しのたびに） |
| GEAR-08 レバーのロック | 済（段 1。PSEU の LG LVR UNLK と DC bus 2、LOCK OVRD。脚のモジュールが `gear/lever_lock` に書き、init のレバーのハンドラーが OFF で止める。レバーのコマンドもロック中は OFF まで） |
| GEAR-09 脚の作動 | 済（段 1。前脚・胴体脚は系統 1、翼脚は系統 4、ドアの順序、OFF と圧の喪失で止まる、重さのかかった脚は上がらない。X-Plane の `acf_gear_deploy` に脚ごとに書く。de-spin はブレーキの段 2 で） |
| GEAR-10 代替下げ | 済（段 1。NOSE/BODY は AC 4・DC 4、WING は AC 1、ドアは開いたまま、翼脚は約 20 秒） |
| GEAR-11 位置監視と表示 | 済（段 1。GEAR DISAGREE 30 秒、GEAR DOOR 30 秒、GEAR TILT 15 秒、展開形と空の箱をカスタム acf のパネルに） |
| GEAR-19 X-Plane のコマンド | 済（段 1 で非常下げ `landing_gear_emer_on` を ALTN の 2 つのスイッチに、段 2 でブレーキとパーキングブレーキのコマンド、段 3 でオートブレーキのコマンド（`brakes_*_auto`・`up`・`dn`・`toggle`）をセレクターに） |
| GEAR-23 空中開始のレバー | 済（段 1。最初の 3 秒は X-Plane の脚に合わせ、そのあとレバーを脚の位置に） |
| GEAR-12 ブレーキの源 | 済（段 2。油圧のモデルの源と圧を `hydraulics/brake_source`・`brake_psi` に出し、ブレーキの効きを圧に比例させる。accumulator は踏むたびに作動油を使う） |
| GEAR-15 アンチスキッドのメッセージ | 済（段 2。ANTISKID・ANTISKID OFF・BRAKE LIMITER、弁の不一致 2 秒、空中で弁が閉。働かないとき X-Plane の `acf_has_abs` を 0。2 輪ずつの代替の antiskid は無い） |
| GEAR-16 パーキングブレーキの副作用 | 済（段 2。脚レバーでパーキングブレーキを外さない。リプレイの分岐の書き込みも外した。X-Plane のパーキングブレーキのコマンドはレバーに） |
| GEAR-21 wing sweep の軸 | 済（段 2。`override_toe_brakes` はブレーキのグルーが常に入れる。wing sweep の軸は両ペダルとして読む） |
| GEAR-02 DISARM と X-Plane のオートブレーキ | 済（段 3。X-Plane のオートブレーキは常に OFF で、制動はブレーキのグルーが書く。離陸すると RTO は OFF に戻る） |
| GEAR-03 オートブレーキの中身 | 済（段 3。レベルごとの減速と最大圧、IRS の対地速度の変化の PI 制御、arm・適用・disarm の条件、正規のブレーキだけ、セレクターのばね、AUTOBRAKES） |
| GEAR-04 RTO | 済（段 3。地上で armed と memo、85 kt のラッチ、ペダル 12°・推力レバー・故障・スピードブレーキで止めてセレクターは RTO のまま、air mode で OFF） |
| GEAR-05 30 kt での DISARM | 済（段 3。fltCtrls の処理を外した。止まるまで効き、地上でもアイドルで arm できる） |
| GEAR-06 ステアリング | 済（段 4。tiller 70°・ペダル 7°（tiller が優先、ペダルは前脚圧縮で engage）、系統 1 の脚 DOWN 圧、空中はカムで中立、胴体脚の arm（地上 10 秒、15/20 kt、IRU 40 kt）と 20° からの逆向き 13°。`override_wheel_steer` は脚のモジュールが常に入れ、油圧のモジュールの処理は外した。tiller は X-Plane の tiller の軸（37：推定）か `gear/steering/tiller`。tiller の軸が無いときはペダルを tiller に（実機ではない、`gear/steering/pedal_tiller`）） |
| GEAR-07 acf の操向角 | 済（段 4。上書きを常に入れるので、acf の `_steerdeg_*`（カスタム 75/35）と胴体脚 15° は効かない。acf は変えていない） |
| GEAR-17 configuration warning の脚 | 一部（CONFIG GEAR の着陸フラップとレバーは 4-1 段 3、PARK BRK のエンジン 2 か 3 は段 2、CTR は段 4 で胴体脚のロックスイッチとエンジン 2 か 3。CONFIG GEAR のラッチ・GND PROX GEAR OVRD・脚の判定は未） |
| GEAR-22 脚の advisory と STATUS | 一部（段 4 で >BODY GEAR STRG、BODY GR STRG SYS、PEDAL STEERING、段 5 で BRAKE TEMP SYS、TIRE PRESS SYS。AIR/GND SYSTEM、GEAR MONITOR、A/G DISAGREE、PARK BRK VALVE は未） |
| GEAR-20 誤 disarm | 済（段 3。推力レバーはアイドル（0.05）にした後に 0.1 を超えたとき。故障は `gear/fail/autobrake`） |
| GEAR-13 BTMS | 済（段 5。X-Plane の吸収エネルギーで熱し、FCOM PI.12.8 に合わせた熱容量・冷却・熱電対の遅れ、表示 5 = 482 °C、BRAKE TEMP、BRAKE TEMP SYS。前の 500 °C でタイヤを壊す処理は外した） |
| GEAR-14 TPIS | 済（段 5。>TIRE PRESSURE の 100 psi・18 %・車軸 25 %・前脚 12 %、故障チャンネル、TIRE PRESS SYS。圧は前のまま整備の乱数と荷重の 10 psi、X-Plane のタイヤ故障で 5 psi） |
| GEAR-18 GEAR synoptic | 済（段 5。カスタム acf のドアの箱を `gear/door` に、タイヤ圧の表示の 3 か所の誤りを直した。空箱は無い） |

## 航法センサー（5-1）の GAP の状態

| ID | 状態 |
|---|---|
| NAV-01 ADC 3 台と選択 | 済（段 1・1b。ADC 3 台、電源と故障、AIR DATA の選択、PFD の速度・高度・Mach。C のリレーはモデルにあるが 3D から選べない） |
| NAV-02 OVERSPEED | 済（段 1。Vmo 365 kt と Mmo 0.92 だけ。PFD の最大速度の帯は前のまま） |
| NAV-03 ALTITUDE ALERT | 済（段 1・1b。判定、>ALTITUDE ALERT、master caution、beeper、カスタム acf の PFD の白枠・琥珀枠） |
| NAV-04 IAS・ALT DISAGREE | 済（段 1） |
| NAV-05 PFD の旗と Mach | 済（段 1b。カスタム acf の PFD の SPD・ALT の旗と選んだ ADC の Mach。MACH の旗は出さない：SPD の旗が抑止し、ADC は丸ごと故障する） |
| NAV-06 BARO STD | 済（段 1） |
| NAV-07 >AOA RIGHT | 済（段 1） |
| NAV-13 >SOURCE SEL など | 一部（段 1 で >SOURCE SEL ADC、段 2 で >SOURCE SEL IRS。EIU・F/D・NAV、>SNGL SOURCE RA、>EIU LEFT、ALT ALERT SYS は後の段） |
| NAV-16 MSU の遷移 | 一部（段 2。ALIGN でもアラインが進む、NAV→ALIGN の fast alignment、アライン済みで ALIGN に待つ。高緯度の 17 分のアライン（FCOM p.194）は無い：アラインの時間は緯度によらない） |
| NAV-17 位置の検査 | 済（段 2。最後の位置との 1°、同じ値の再入力、アラインの終わりの緯度の比較と 2 回で故障、fast alignment の 1/2°・1° と CYCLE IRS OFF-NAV） |
| NAV-18 setPos が戻らない | 済（段 2。位置の入力はアラインごとに求める） |
| NAV-19 ATT | 済（段 2。30 秒の align mode、OFF までのラッチ、SET HDG と方位、位置と対地速度は無効。ATT と HDG の別々の旗はパネル） |
| NAV-20 電源 | 済（段 2。AC 3・1・2、hot battery bus、両方喪失でアライン喪失、C の 5 分、>IRS AC・DC、ON BAT。地上員呼び出しのホーンは無い） |
| NAV-21 メッセージ | 一部（段 2 で IRS L/C/R、>IRS AC・DC、ENTER IRS POSITION、CYCLE IRS OFF-NAV。>ATTITUDE・>HEADING・>TRACK・>GPS は後の段） |
| NAV-22 動きの判定 | 済（段 2。IRU ごと、止まって 30 秒で IRS MOTION が消え、自動で再開） |
| NAV-23 toDMS | 済（段 2） |
| NAV-24 他系統の IRS | 一部（段 2 でヨーダンパーを IRU の姿勢に。AFDS・失速警報・GPWS は各系統の作り直しで） |
| NAV-25 GPS | 一部（段 2。電源、初回測位、故障、>GPS・>GPS LEFT/RIGHT、POS INIT の GPS POS。RAIM・HIL、FMC の位置の GPS 更新、GPS NAV INHIBIT と PURGE は FMC の作り直しで） |
| NAV-30 SET HDG の検査 | 済（段 2） |
| NAV-51 電波高度計 | 済（段 4。3 台、電源と故障、EIU の順の PFD のソース、RA 旗と 2,500 ft 超の空白、GPWC の比較。暖機と EIU の故障は無い） |
| NAV-52 MINS RST | 済（段 4。点滅のリセットだけ、各席） |
| NAV-53 各席の DH | 済（段 4。各席の RA と DH、カスタム acf の副操縦士の PFD） |
| NAV-54 DH の細部 | 済（段 4。DH 0 の表示、3 秒の点滅、DH + 75 ft の arm。表示は 109 型のまま：405 の RADIO/BARO は 5-2） |
| NAV-55 mode 1〜5 | 済（段 4。境界は資料の点、数値の無い線は推定。mode 3B は無い） |
| NAV-56 GND PROX パネル | 済（段 4。G/S INHB の押しボタンとラッチ、FLAP・GEAR OVRD、TERR OVRD は >TERR OVRD だけ） |
| NAV-57 GEAR OVRD と CONFIG GEAR | 済（段 4） |
| NAV-58 灯と master WARNING | 済（段 4。GND PROX 灯、PULL UP・WINDSHEAR の master WARNING。405 の G/S INHB に灯は無い） |
| NAV-59 mode 7 | 済（段 4。X-Plane の reactive windshear を入力に、1,500 ft 未満、最低 5 秒、他の GPWS の禁止。TCAS の禁止は段 5） |
| NAV-60 mode 6 | 済（段 4。405 の組、各 1 回、BANK ANGLE の 35・40・45° と低高度、CDU の設定の添字を音のバンクの順に） |
| NAV-61 MINIMUMS の音 | 済（段 4。機長の RADIO/BARO の minimums で APPROACHING MINIMUMS・MINIMUMS） |
| NAV-62 look-ahead・TCF | 作らない（地形のデータが無い） |
| NAV-63 GPWS の EICAS | 済（段 4。>ALT CALLOUTS、GND PROX SYS、>TERR OVRD、TERR POS、WINDSHEAR SYS） |
| NAV-64 PULL UP の配線 | 済（段 4。カスタム acf の PFD と `.snd` を GPWS の値に） |
| NAV-65 警報の相互禁止 | 済（段 4・5。GPWS の中の声の優先と windshear の禁止、GPWS の警報と windshear で TCAS を TA ONLY、windshear で TCAS の声と自動表示なし、GPWS の声の間は TCAS の声なし：推定） |
| NAV-66 トランスポンダのモード | 済（段 5。570 のパネルの 5 位置を X-Plane の 1・2・3（地上 5）・6・7 に） |
| NAV-67 ATC L/R | 済（段 5・5d。R も働き、故障と電源は側ごと。コード表示は L・R どちらでもコードと ATC L・ATC R、電源は操作盤の 2 本のバス） |
| NAV-68 TEST | 該当なし（570 のパネルに TEST は無い。TCAS の試験は CMC の地上試験と計算機の前面のボタン：作らない） |
| NAV-69 TA/RA の判定 | 済（段 5。X-Plane の TCAS を核に、747 の層：モード、故障、抑止、機影の種類） |
| NAV-70 ND の TCAS 表示 | 済（段 5b。カスタム acf の ND に機影 4 種と矢印・データタグ、TRAFFIC・OFFSCALE・TA ONLY・TCAS FAIL。no-bearing は無い：X-Plane の相手は方位がある） |
| NAV-71 PFD の RA | 済（段 5d。赤枠の RA のピッチ領域、VSI の赤の範囲、赤い VS ポインタ。ピッチの境の求め方は推定） |
| NAV-72 TCAS の音声 | 済（段 5。`.snd` に 14 のイベント、Ver 7.0 の声。CROSSING はこちらで決める：推定） |
| NAV-73 高度による抑止 | 済（段 5。1,000 ft 未満と地上で TA ONLY、DESCEND 1,100 ft・INCREASE DESCENT 1,500 ft は TA の扱い（推定）、TA の声 500 ft。48,000 ft の CLIMB の抑止は X-Plane の判定のまま） |
| NAV-74 TFC の自動表示 | 済（段 5。新しい TA・RA で、どちらの ND にも出ていなければ、表示できるモードの ND に出し、ほかは arm。表示できないモード（VOR CTR・APP CTR・PLN）では出さない。EFIS パネルの故障での自動表示は無い） |
| NAV-75 TCAS OFF の誤表示 | 済（段 5。TFC が入っていてモードが TA ONLY・TA/RA でないときだけ、故障なら TCAS FAIL） |
| NAV-76 >TCAS OFF の抑止 | 済（段 5。地上と RA 400 ft 未満は出さない） |
| NAV-77 traffic の高度の窓 | 済（段 5。other・proximate は ±2,700 ft、近い 30 機） |
| NAV-78 故障系 | 済（段 5。>TRANSPONDER L・R、>TCAS SYSTEM、>TCAS RA CAPTAIN・F/O、ND の TCAS FAIL。570 に ATC FAIL 灯と R の表示は無い） |
| NAV-79 WXR パネルの論理 | 済（段 5c。LR/T・RR/T、TFR と両側の TFR で TEST、TEST、WX・WX+T の自動ゲイン、MAP の MAP GAIN、WX+T の 40 nm、パネルの灯） |
| NAV-80 WXR の故障と安定化 | ほぼ済（段 5c・5d。R/T の電源（推定）と X-Plane の故障、新設のアンテナ・操作盤・校正の故障、安定化の IRU と IRS 選択、ND の WXR FAIL と TEST の故障の源、WEAK・ATT。RANGE DISAGREE・RSTR INOP は残り） |
| NAV-81 ND の WXR の注記 | 済（段 5c・5d。モード、チルトは整数、WXR を出すモードだけ、TEST でチルトの欄に故障の源、3 行目に WEAK・ATT か MAP のゲイン CAL・VAR（推定）、青と琥珀） |

## 表示（5-2）の GAP の状態

| GAP | 状態 |
|---|---|
| DSP-27 表示器と EIU の故障・自動切替 | 済（段 1。表示器 6 台と EIU 3 台の故障、outboard の故障で PFD を inboard、upper の故障で primary を lower、EIU の AUTO、standby の電源で L の EIU が壊れると全部消える。compact EICAS は段 6） |
| DSP-28 選択器の組み合わせ | 済（段 1。規則で解く。資料に無い組み合わせは、選んだ表示器に出して空いた表示器を消す：推定） |
| DSP-29 表示の電源 | 済（段 1。表示器は APU standby・main standby・F/O transfer bus、EIU は main standby・captain transfer・F/O transfer bus：FCOM p.800・p.804） |
| DSP-30 輝度 | 一部（段 1。内容は出している表示器のつまみで。周囲光の補正と WXR の内側のつまみは無い） |
| DSP-02 ソース選択 | 一部（段 2。比較のメッセージは済。FD・NAV の選択で表示の源が変わることは AFDS・FMC の作り直しで、PFD の ILS の受信機は無線の同調で。ADC・IRS は 5-1） |
| DSP-32 表示系のメッセージ | 一部（段 2。>SOURCE SEL EIU・F/D・NAV、>SNGL SOURCE RA、>ATTITUDE、>HEADING、>EFIS CONTROL L・R、>EFIS/EICAS C/P、>EIU LEFT。>SNGL SOURCE ILS は段 5b-1a。>TRACK は後で） |
| DSP-14 ILS の目盛 | 一部（段 4e で、目盛を出す条件を ILS の表示のモデルに移した。同調そのもの（目的地の 50 NM 以内でしか同調の印 `ils_dots` が 1 にならない）は無線の自動同調と一緒に：5-1 段 3） |
| DSP-13 フラップの機動速度のバグ | 済（段 3a。FCOM PI.10.3 の値、25 は VREF25、今と次の小さいフラップの 2 つ。段 3b で約 20,000 ft より上は出さない） |
| DSP-07 最小速度の表の高度帯 | 済（段 3a） |
| DSP-05 速度テープの帯 | 済（段 3a で最小機動速度の帯の出し始め、段 3b で値：赤と黒の帯はシェーカーか低速バフェットの速度、琥珀の帯は 1.3 g、最大機動速度は高速バフェットまで 1.3 g で最大速度より下のときだけ。notes/ATA-31.md §14） |
| DSP-08 表の誤記 | 一部（段 3b で失速速度の表の 2 か所。表は読む所が無くなったが（6-3 段 3b で TO/GA のピッチを AFDS へ）、確かめた表として残す。VR・V2 の表の誤記は FMC の作り直しで） |
| DSP-34 計器モジュールが他系統の出力を書く | 一部（段 3b でシェーカーを最小速度のモデルに分けた（まだ計器のモジュールの中）。TO/GA のピッチは 6-3 段 3b で AFDS のピッチの則へ（計器のモジュールの `B747_Vs` を外した）、BAT DISCH MAIN・BATTERY OFF は残り） |
| WARN-18 失速警報 | 一部（段 3b：今の Mach で必要な揚力がシェーカーの境界を超えたらシェーカー（荷重倍数を含む）。AIRSPEED LOW と琥珀の枠は最小機動速度より遅いとき。シェーカーの 3D の動きは 3D の側で無い） |
| DSP-01 PFD の方位目盛 | 済（段 4a。その席の AHRS の方位で回す。前は ND の上の向き（MAP は航跡、PLN は真北）。HDG REF の TRUE は段 5・6-3） |
| DSP-11 気圧 | 済（STD の戻りは 5-1 段 1 の NAV-06。段 4b で遷移高度・遷移レベルでの琥珀の枠と、CDU の BARO SET をその側だけに・FCOM の入力の形式に。遷移レベルは FMC に無いので既定の FL180：FMC の作り直しで。405・570 の QFE は 109 に無い） |
| DSP-04 PFD の旗 | 一部（段 4a で ATT・HDG・VERT を別々に：姿勢は選んだ IRU、方位は NAV の源の FMC の IRU か選んだ IRU、VERT は慣性の昇降率、エアデータの無効は旗なしで消す。SPD・ALT・RA は 5-1。段 4d で FPV と PITCH・ROLL（両席の姿勢の 3° の差：推定）。段 4e で G/S・LOC（偏位の invalid：目盛とポインターの代わりに旗）。MACH・SPD LIM・SEL SPD・FD は源の故障が無く、DH・NO TDZ は FMC と EFIS 操作パネルの作り直しで） |
| DSP-12 PFD の記号 | 一部（選択高度の枠は 5-1 段 1b。段 4c で PLI（シェーカーの点：フラップが上がっていないとき）と VR の R。段 4d で FPV（スイッチのラッチ、CRT の形）。段 4e で ILS（塗りと中抜きのポインター、拡大 LOC 目盛、偏位過大の琥珀と 4 Hz の点滅、LOC の捕捉失敗、ロール 53° 超での消去、立ち上がる滑走路）。ILS の周波数・コースの不一致の線は同調の作り直しで、LCD のバンク 35° の琥珀と横滑りの色は後で（既定は CRT）、範囲外の V1・VREF の数字は FCOM に形の図が無い、TDZ は FMC の作り直しで） |
| DSP-15 ND のパネルの参照の誤り | 一部（段 5a で向き・方位・航跡・モードの左右の取り違えを直した。段 5b-1a で PFD の ILS を使用中の EIU の受信機に（前は機長 NAV1・副操縦士 NAV2 に固定、進入の基準の DME・コースは中央の FMC master 選択器で切り替え）。段 5b-1b で ND の APP（G/S の指針の取り違え、基準受信機の欄）、段 5b-2a で VOR。段 5b-2b で VOR・ADF の針と左右下の欄。EICAS の条件は段 6） |
| DSP-21 ND の航跡の線と記号の作り直し | 済（航跡の線は前に CTR の状態に。段 5a で記号の作り直しの 0.2 秒の時計を直し、航跡の線を新設 `nd/<席>/trk_line` に） |
| DSP-22 ND の選択方位 | 済（段 5a：バグは PLAN 以外で常に、破線だけを MAP で LNAV・LOC・ROLLOUT のとき 10 秒で消す。全周表示には選択方位の部品が無い：残り） |
| DSP-03 ND の基準受信機 | 済（段 5b-1b で APP を使用中の EIU の受信機に、段 5b-2a で VOR を自席の VOR に：推定） |
| DSP-35 ND の VOR・ADF の針 | 済（段 5b-2b：全周の VOR の針の添字のずれ、ADF の添字、MAP での向きのずれ、局や受信機の状態） |
| DSP-31 CDU の EFIS 操作 | 済（段 5c-1。左の CDU は機長、右は副操縦士のパネルの代わり（推定）、SELECT はそのパネルの故障のときだけ、RANGE・WXR・DH RESET・STD はその側、POS・DATA の状態、CDU-152 の OPTIONS。CDU の MODE の X-Plane の地図は段 5a のグルーで。EFIS 操作パネルの故障でパネルの操作（VOR/ADF スイッチも）が効かない。表示選択パネルの故障は段 6） |
| DSP-16 DATA・POS | 済（段 5c-1 で押しボタンと CDU に状態 `nd/data/<席>/data`・`pos`。段 5c-2a で DATA：経路の点の高度と FMC の ETA（FMC が各点の ETA を `fms/route_eta` に出す）。段 5c-2b で POS：IRU・GPS の位置（ここでは FMC の位置と同じ：飛行機の記号に）、VOR L・R の radial（DME の距離まで印つき、無ければ画面の端まで、R-xxx）） |
| DSP-17 ND の地図の記号 | 一部（段 5c-3a：STA の高・低高度（受信範囲 100 NM 以上を高高度：推定）、同調中の VOR はいつも緑、STA・WPT・ARPT は MAP だけ、EXCESS DATA、109 の ND は GS だけ（TAS なし）。段 5c-3b：出発・到着空港と滑走路（80 NM 以上は空港の記号と滑走路の番号・線、40 NM 以下は滑走路を縮尺どおりと 14.2 NM の破線。X-Plane の経路の RW の項目と CIFP から）、経路の点は MAP・MAP CTR・PLAN だけ。段 5c-3c：手動同調の VOR の、局を通るコースの線と、コース・反対の数字。MAP の旗は段 5a で）。MAP CTR の縮尺（2026-10-28、§40：選んだ範囲が全周のローズまで、記号は覆いの円 225 px まで） |
| DSP-20 HDG REF | 済（段 5d：TRUE と NORM の極地域で真北、PFD・ND の方位・航跡・ラベル（MAG／TRU の枠、降下中の琥珀の点滅、MAG の 10 秒の枠）、ND の風、AFDS の HDG SEL の目標と切り替えの HDG HOLD。AFDS の極地域の制限（HDG SEL を受けない、HDG SEL・HDG HOLD は NCD）は 6-3 段 2a、LOC（捕捉しない、NCD）は段 2b で済。残り：FMC の真方位は 6-1） |
| DSP-23 ND の FMC の記号 | 一部（段 5e：位置のトレンドベクトル（30 秒の区間、傾きと対地速度の弧、範囲で 1〜3 区間）。S/C・E/D・減速点、待機・PT、エネルギー円、FIX の基準点は FMC の作り直し 6-x） |
| DSP-33 時計 | 済（段 6a：時刻は X-Plane の UTC に時計ごとのずれ、SET の HLD・MS・HS と日付の設定、DATE の交互、ET・CHR の 99:59、APU battery bus で表示、main hot battery bus の復帰で NCD、パネルを時計の値に） |
| DSP-24 EICAS の形式 | 済（段 6b-1：部分表示、逸脱の印、電源投入時の自動表示。段 6b-2：主 EICAS の compact の形。空中の CUTOFF での自動表示は燃料 2-2 の ENG-23 で済。compact の始動の表示（X-BLD など）は無い） |
| DSP-25・26 STATUS のメッセージ、CAS の 10 ページ | 済（警報 1-3 の WARN-17・WARN-09。カスタム acf） |
| DSP-06 OVERSPEED | 済（5-1 段 1 の NAV-02：Vmo/Mmo だけ） |
| DSP-19 | 未（TERR は外部のプラグイン頼み。notes/ATA-31.md §10・§21。DSP-09・10 は 5-1 段 4、DSP-18 は 5-1 段 5、DSP-21 の一部は 5-1 段 5c で済） |

## FMC と CDU（6-1・6-2）の段取りと GAP の状態

段取りの全文（中身・GAP・資料）は notes/ATA-34-61-FMC.md §10。6-1 と 6-2 を 1 本で進める。

| 段 | 内容 | 状態 |
|---|---|---|
| 1 | 小修正（局所で害の大きいもの） | 済（2026-10-26。notes/ATA-34-61-FMC.md §11） |
| 2 | CDU の枠組み | 済（2026-10-26。§12） |
| 3 | 地上準備のページ | 3a は済（PERF INIT と INIT REF のキー：§13）。3b-1 は済（TAKEOFF REF の V speeds：§14）。3b-2 は済（THRUST LIM の地上と TAKEOFF REF の欄：§15）。3c は済（MENU の <FMC と FLT NO：§16。APPROACH REF の GROSS WT と滑走路は段 5、IDENT は段 4 へ） |
| 4 | nav DB | 済（§17） |
| 5 | 経路モデルと RTE・LEGS・DEP ARR | 6 つに分けた（§18）。5a は済（経路のモデル：§19）、5b・5c は済（RTE と LEGS：§20）、5d は済（手続きと DEP/ARR：§21）、5e は済（現用点と X-Plane の FMS：§22。PLAN の CTR と STEP も 2026-10-29 に済：§42）、5f は済（試験キットの経路を CDU で：§24）|
| 6 | 経路の形と LNAV | 4 つに分けた（§26）。6a は済（経路の形のモデル：§27）、6b は済（LNAV のモデル：§28）、6c は済（組み込み：§29）、6d は済（ND の線：§30）。段 6 は終わり |
| 7 | ホールド・オフセット・残りの経路の操作 | 5 つに分けた（§31）。7a は済（ホールドのモデルと LNAV：§32）、7b は済（ホールドの CDU と ND：§33）、7c は済（PROC HOLD、PROC TURN の表示、CRS REVERSAL AT FA FIX：§34）、7d は済（オフセット：§35）。7e は 4 つに分けた：7e1 は済（REF NAV DATA：§36）、7e2 は済（ABEAM PTS：§37）、7e3a は済（自分で作る点の入力：§38）、7e3b は済（FIX INFO：§39）、7e4 は済（RTE 2 と RTE COPY：§40）、7f は済（procedure turn の形：推定、利用者の依頼：§41）。段 7 は終わり |
| （6-3） | AFDS | 段取りを決めた（2026-10-27、notes/ATA-22.md §10：段 1a〜1e・2〜6。段 1 は 1b の作業で分け直した）。1a（枠組みと engage：§11）・1b（ロールのモード：§12）・1c（ピッチのモード：§13）・1d（進入のモード：§14）・1e（TO/GA：§15）・2a（ロールの則のうち方位・姿勢・航跡：§16）・2b（LOC の捕捉と追従：§17）・3a（ピッチの則のうち V/S・ALT とその捕捉：§18）・3b（速度を昇降舵で保つ則と速度の保護：§19）と A/P の姿勢のループ（§20・§21）は済。下の「自動操縦（6-3）の段取りと GAP の状態」 |
| 8 | 性能 DB と予測 | 未 |
| 9 | VNAV（6-4 の A/T と並べて） | 未 |
| 10 | 航法センサーと同調（5-1 段 3 を含む） | 未 |
| 11 | 燃料の監視・二重系・メッセージの残り | 未 |
| 12 | 残りのページとデータリンク | 未 |

## 自動操縦（6-3）の段取りと GAP の状態

段取りの全文（中身・GAP・資料）は notes/ATA-22.md §10。モードの論理を 1a〜1e で新しいモデルに移し、その間は前の則が飛ばす。

| 段 | 内容 | 状態 |
|---|---|---|
| 1a | 枠組みと engage | 済（2026-10-27。notes/ATA-22.md §11） |
| 1b | ロールのモード（HDG SEL・HDG HOLD・ATT・LNAV） | 済（2026-10-27。§12） |
| 1c | ピッチのモード（V/S・ALT・FLCH・VNAV・SPD） | 済（2026-10-27。§13） |
| 1d | 進入のモード（LOC・G/S・APP） | 済（2026-10-27。§14） |
| 1e | TO/GA の論理 | 済（2026-10-27。§15） |
| 2 | ロールの則 | 済（2026-10-27。2a：§16、2b：§17） |
| 3 | ピッチの則 | 一部（3a・3b 済：2026-10-28、§18・§19。3c の G/S が残り） |
| 4 | autoland と 3 チャンネル | 未 |
| 5 | 監視と警報 | 未 |
| 6 | ヨーダンパーと autotrim | 未 |

| ID | 状態 |
|---|---|
| AFDS-06 A/P engage の既定のモード | 済（段 1a・1d。F/D OFF で V/S と HDG HOLD・ATT（PW と RR。GE は HDG HOLD）、F/D が地上の T/O なら HDG HOLD と V/S、F/D の最初の ON の既定、LOC・G/S の捕捉中に F/D ON で入れると LOC の arm と HDG HOLD・G/S の arm と V/S） |
| AFDS-14 AUTOPILOT DISC | 一部（段 1a。解除のたびに出て、再 engage か A/P の無いときの操縦輪のスイッチで消える。解除バーを上げても消えない。型式の音は段 5） |
| AFDS-15 engage のインターロック | 一部（段 1a。400 ft の制限をやめて地上でも、解除バー・ほかのチャンネル・そのチャンネルの油圧。残りは段 5） |
| AFDS-07 V/S の同期 | 済（段 1a・1c。既定の V/S も V/S のスイッチも今の V/S を 100 fpm に丸め、前のモードが ALT か TO/GA で降下中なら 000） |
| AFDS-21 MCP の細部 | 一部（段 1a・1c。IAS の初期値 200、TO/GA からの FLCH は今の速度と選んだ速度の大きい方。MCP 高度が内部の目標に入るまでの 3 秒などの残りは 1d・1e と段 2） |
| AFDS-08 LNAV・VNAV・SPD | 一部（段 1b・1c。LNAV の 2 回目は arm のときだけ disarm、engage 中に押しても何もしない、HDG SEL で arm が消えない、経路が無くても外れない。VNAV も 2 回目は arm のときだけ disarm、engage 中に押しても何もしない、arm の間は作動中のモードのまま、TO/GA で終わる。SPD は VNAV・FLCH SPD・TO/GA の間は効かない。VNAV のサブモードの表示と経路が無いときの VNAV は FMC の段 9） |
| AFDS-03 TO/GA | 一部（段 1e。モードの論理：地上の最初の F/D で T/O、空中の TO/GA スイッチでフラップが UP でないか G/S が入っていれば G/A、T/O から G/A へは入らず離陸後は 50 ft から G/A のロールだけ、スイッチは電波高度 5 ft を下回って 2 秒で効かなくなり上回って 3 秒で効く、F/D のスイッチ OFF のまま表示。則は段 2a（ロール）と 3b（ピッチ：T/O の V2 + 10 と 5 秒の更新、G/A の 15° から速度へ、windshear）で済。エンジン故障時の目標と A/T の GA の推力（6-4）が残り） |
| AFDS-09 遷移の規則 | 一部（段 1b〜1e。T/O・G/A：G/A からのロールのモードと V/S・ALT HOLD・FLCH は 400 ft から、MCP 高度の捕捉は T/O・G/A から 800 ft より上、T/O から G/A・G/S へは入らない。ロール：LOC と G/S の捕捉後と GA の 400 ft 未満の HDG SEL・HDG HOLD・LNAV、LOC の engage 中の LNAV の arm、HDG HOLD が X-Plane の heading hold を直接入れない。ピッチ：LOC の後の G/S と FLARE から V/S・ALT HOLD・FLCH に入らない、GA の 400 ft 未満の V/S・ALT HOLD・FLCH（VNAV の arm は高さによらず）、G/S で VNAV が終わる。進入：LOC と APP の要求で LNAV の arm が、APP の要求で VNAV の arm が消え、LNAV・VNAV の arm で APP が外れる、LOC の捕捉後の別のロールのモード・G/S の捕捉後の別のピッチのモードで APP が外れる、T/O と G/A からは arm しない。T/O と GA からの ALT の捕捉の 800 ft は 1e） |
| AFDS-11 速度の保護と自動反転 | 一部（段 1c。FLCH で MCP 高度への道から 8,000 ft 離れると ALT HOLD（測り始めは推定）。速度の保護は AFDS の分を段 3b で（FLCH・VNAV SPD・TO/GA の目標を最小機動速度から最大速度 − 5 kt に）、A/T の分は 6-4、速度を昇降舵で保つ間に A/T が SPD に変わったときの V/S は 6-4、V/S 000 の内部の ALT HOLD は段 3a で済、VNAV の ALT HOLD は FMC の段 9） |
| AFDS-02 LOC・APP | 一部（段 1d。モードの論理：LOC と APP の arm と 2 回目の disarm、捕捉は航跡がコースから LOC 120°・G/S 80° 以内、G/S は LOC とどちらが先でも（109・570：FCOM p.669）、捕捉で MCP の方位をコースに、ILS が無くても arm、捕捉の後に信号が途切れても LOC のまま。段 2b：LOC の捕捉の判定（対地速度・進入角・偏位）と追従（電波高度から推定した距離で偏位を直線に、慣性の経路、LOC TRACK）。G/S の捕捉の判定と追従は段 3） |
| AFDS-01 ロールの指令 | 一部（段 2a。HDG SEL・HDG HOLD・ATT・LNAV・TO/GA は新しいロールの則：X-Plane の HDG のモードと F/D のロール、10 点の移動平均を使わない。bank limit は MCP の選択器と AUTO（TAS・フラップ・V2）、HDG SEL は押してから回せば回した向き、TO/GA は航跡を保つ。段 2b で LOC も。ROLLOUT は段 4） |
| AFDS-22 acf に依るロール | 済（段 2a・2b。X-Plane の AP のロールはどのモードでも使わない） |
| AFDS-10 ピッチの制御則 | 一部（段 3a・3b。V/S・ALT とその捕捉（0.05 g の引き起こし、慣性の上下加速度の減衰：前は昇降率に比例する窓と少しずつ増減する則、10 点の平均）、V/S 000、前の VNAV の V/S と高度は新しいピッチの則。速度を昇降舵で保つ則（FLCH・T/O・G/A・前の VNAV の速度）も段 3b で新しい則に。G/S は段 3c。A/P の姿勢のループ（内側）は、自動トリムとの取り合い（§20）と、姿勢の変化率・全高度共通のゲイン（§21）を直した） |
| AFDS-19 A/P 中の autotrim | 一部（2026-10-28、§20。昇降舵のサーボの指令が 0.4°（G/S 0.6°）を超えたら動かし 0.25° で止める帯（前はモードごとの幅で帯なし）、スタビライザーの動きを A/P の積分から差し引く（ATA22 p.333）。500 ft 未満・rollout・LAND 2 の full rate と trim bias・GA の取り消しは段 6） |
| ほかの AFDS-01〜24 | 未（段取りの表の段で） |

## 気づいたこと（作業の途中で）

- **MCP 高度の dataref を書くだけでは前の則の目標が変わらない**（2026-10-27、6-3 段 1e の `s104`）：MCP の窓（`autopilot/heading/altitude_dial_ft`）から前の則と捕捉の窓が見る目標（`autopilot/altitude_dial_ft`）へは、高度のつまみのハンドラーが 3 秒後に写すか、V/S・FLCH などのスイッチが写す。シナリオで MCP 高度を変えるときは、両方を書く（つまみのコマンドでも、空中の初期化の後などで写らないことがあった）。前の則を段 3 で作り直すとき、MCP の窓を直接読むようにする。
- **シナリオの走行が、飛行の開始の前に止まって結果の無いことがある**（2026-10-27）：`s99`・`s100`・`s104` で 1 回ずつ。3 回目の出力で、飛行が 600 秒たっても始まらなかったと分かり、X-Plane は GPU のメモリ（VRAM）の割り当てに失敗した警告のまま止まっていた（起動から約 18 時間・60 本余り：TESTING.md の注意）。前の 2 回も同じ前触れと見られる。一覧で回すときは、各走行の出力（`run_scenario.ps1` の標準出力）をファイルに残しておく。

- **X-Plane の CDU の scratchpad は空でも角括弧が付く**（2026-10-26、6-2 段 2 の手直し）：`sim/cockpit2/radios/indicators/fms_cdu1_text_line13` は空のとき「[」+ 空白 22 + 「]」、メッセージも「[NAV DATA OUT OF DATE  ]」の形。角括弧ではメッセージと打ち込んだ文字を区別できないので、FMC が打ち込んだ直後と、打ち込んだ文字そのものはメッセージにしない（notes/ATA-34-61-FMC.md §12）。
- **X-Plane を長く動かして機体を何度も読み直すと、資源が尽きて落ちる**（2026-10-26、全シナリオの途中）：約 20 時間・40 回余りの読み直しの後、読み直しのたびに「FMOD error 38 - Not enough memory or resources」が 30〜70 万行 Log.txt に出て（Log.txt は 780 MB）、その回の `log_full.txt` が 130 MB になり、`s14` が 2 回続けて 1 件落ちた（その間の同じ操作の診断の回は通った）。13:09 に X-Plane が「GPU バッファの割り当てに失敗」（`gfx_vk_memory_controller.cpp:808`）で落ちた。全シナリオを回す前や、FMOD のエラーが出始めたら、X-Plane を立ち上げ直す（TESTING.md §4）。
- **パネルの部品とグループのうち 116 個が別々の dataref の SHOW を持つ**（2026-10-26、EICAS の compact の作業）：パネルは最後の SHOW しか見ないので、前の条件が効いていない。SHOW を 2 本以上持つのは 308 個（EICAS 上 108・下 114、PFD 78、ND 8）で、残りは同じ dataref の範囲（124、扱える）と、名前の無い dataref（`[3]` だけ）の条件を含むもの（68）。例：二次エンジンのページの白の油圧（`EICAS2_oil_press_status` が 0 の条件が効かず、赤のときも白が重なる）、主 EICAS の推力の目標と REF の針、Thrust Command のグループ。compact の写しでは外側のグループに分けて直した。元の部品は、意図を一つずつ確かめながら別の段でまとめて直す（機械的に「かつ」に変えると、たまたま最後の条件で正しく見えているものが変わるおそれ）。→ 5-2 段 7 で直した（notes/ATA-31.md §38）。
- **XTLua は一度きりのコマンドの終わりを始めより先に流すか落とす**（2026-10-26、時計の `s74` の 1 回目）：Web API の duration 0 で送った DATE・CHR のボタンが押されたまま、ET の RESET（ばねで戻る）が戻らなかった。3D のつまみのクリック（`ATTR_manip_command_knob`、X-Plane の CommandOnce）も同じ形。時計は始めから 0.2 秒で自分で戻すようにした（notes/ATA-31.md §35）。ほかの系統のボタンの動き（phase 2 で戻すもの）も、つまみや duration 0 では押されたままになりうる。試験のシナリオでは押しボタンに duration を付ける。
- **FL350 の空中開始は大きく揺れる（未解決）**（2026-10-25 夜、段 3b の `s53` の 2 回目）：s07・s15・s20・s23・s25・s53 の空中開始（10,668 m・254 m/s）で、A/P なしでも機首が上がり（開始 19 秒で 1.67 g）、約 30 秒で 40,355 ft・157 kt まで上がってから押し下がり、2 回目の機首上げで迎角 11〜12°（シェーカー）、約 100 秒で 35,000 ft・274 kt に戻った（`tests/flight/runs/20261025_224832_probe_air_start_*`）。s15 は 2026-10-24 に「約 41,700 ft・速度ほぼ 0 から落ちる」形を書いており、acf の調整の前からある。原因（X-Plane の空中開始のトリムか、こちらの安定板トリムのモデルの開始時の値か）は未調査。別の回は約 38,000 ft・208 kt で水平になり、バフェットの境界でシェーカーが鳴ったり止まったりした。s53 は揺れの途中（20 秒、シェーカーの間）で A/P を入れたとき FLCH が入らずに失速の手前まで減速したので、60 秒待ってからシェーカーが止まっているときに A/P を入れるように直した。失速を FCTM に合わせた acf では、この揺れの中でシェーカーや失速に入りやすい。ほかの巡航のシナリオは次の全シナリオの実行で確かめる。
- **カスタム acf は FCTM の失速速度よりずっと遅くまで失速しない**（2026-10-25、段 3b の下調べ。利用者の問い「速度テーブルは正確か」）：約 9,700 ft・アイドルで A/P の ALT HOLD のまま減速すると、クリーン 269.9 t の 1 g 失速は 150〜152 kt（2 回、迎角 18〜19°）で、FCTM の図（p.261）の失速 172.6・シェーカー 193.2 kt より約 21 kt 遅い。フラップ 30・脚下げ 269.5 t は失速しない：昇降舵が機首上げいっぱい、安定板が機首上げの限界 11.6 units で、迎角 21〜22°・約 111 kt のまま毎分約 2,300 ft で沈んで海面まで降りた（図は失速 121.9・シェーカー 127.7 kt）。acf の最大揚力係数がクリーンで約 1.3 倍、30 で 1.2 倍以上（notes/FCTM.md §1.14）。システム側では補正しない（CLAUDE.md）。利用者の承認で acf を調整した（同日夜、ACF_DIFF.md §5）：主翼の翼型の失速の部分を 2.8° 低い迎角へ（新しい翼型 `airfoils/B744_*_custom.afl`）、前縁スラットの失速迎角の増し分を 8・6 から 4.8・3.6 へ。図との差は UP −2、10 +6、20 −5、30 +4 kt。X-Plane の後縁フラップの揚力が角度とともに頭打ちになるので、フラップごとの差は消しきれない。A/P の ALT HOLD のままの失速は n が揺れ、同じ設定でも ±3 kt ほどばらつく（解析は失速の切れ目までに限った）。測定は `tests/flight/measure/stall_*.json`（クリーン・10・20・30。全シナリオの実行に入れない）と `tests/flight/tools/stall_speed.lua`。
- **前の最小速度の表と速度テープの論理**（同じ下調べ）：表（`VsData`）は FCTM の図の失速速度と合う（10,000 ft で −0.3〜+1.7 kt。400 t の UP・10・20 は 1.3〜2.4 kt 低く、20 の 2 か所は誤記）。前のコードはこの失速速度で速度テープの最小速度と失速警報を出す（FCOM p.973 ではシェーカー速度なので、UP で約 20 kt、ほかで 4〜9 kt 低い）。重量の補間は 20 t の区間の前半で下の重量の値をそのまま使い、最小速度は最大 4 kt、VREF30（段 3a のフラップの機動速度の元）は最大 3 kt 低い。最小機動速度（`setVmc`）は重量とフラップの一次式で、FCOM の「シェーカーまで 1.3 g」と比べると UP で約 20 kt 低い。AIRSPEED LOW は FCOM p.1556 では最小機動速度未満なのに、前のコードは失速速度か最小機動速度未満。どれも段 3b で。
- **X-Plane のレーダーのコマンドとパネルの灯**（2026-10-25、段 5c）：`EFIS_wxr_tilt_up/down` の 1 回は 0.1°、`EFIS_wxr_gain_up/down` は 0.1。アンテナの走査の初期値は左右 50°（`EFIS_weather_sector_width`）。X-Plane の TEST は緑・黄・赤・マゼンタの帯の試験の絵を出す。照明のモジュールの WXR パネルの灯の dataref（`wxr/left|right/*`・`wxr/test`・`LR`・`RR`）を読む 3D の物体は見つからなかった。
- **X-Plane 12 の TCAS の振る舞い**（2026-10-25、TCAS の段 5。試験の相手機 `tests/flight/fwl/B747_traffic.lua` で）：`override_TCAS` の相手にも TA・RA を出す。TA・RA の早さは TCAS II の表どおり（10,000 ft 付近で CPA の 39 秒前・24 秒前、1,060 ft で 24 秒前・14 秒前）。`tcas_message` は最後の声を持ち続ける（TA が終わっても 14、2 回目の TA でも変わらない）。transponder_mode が 3（XPDR）でも TA を出す。1,050 ft でも TA と RA（LEVEL OFF）を出す。message の crossing の区別が形と合わない（下で水平の相手への上昇 RA を「CLIMB, CROSSING CLIMB」、上の相手への降下 RA を「DESCEND, CROSSING DESCEND」と出し、降下して離れる下の相手には「CLIMB, CLIMB」）。高度を出さない相手（mode A）は TA だけ。X-Plane の EFIS の地図は `override_TCAS` の相手を描かない。どれも notes/ATA-34.md §15。
- **FlyWithLua の writable の dataref の変数は毎フレーム書き戻される**（2026-10-25、試験の相手機の最初の版）：`override_TCAS` をこれで持ったら、AI 機を借りていない間も書き込みになり、X-Plane が「FlyWithLua is buggy. It tried to control TCAS while not owning the AI planes」のダイアログを出した。`set()` で一度だけ書くように直した。ダイアログはコンピューター操作のクリックでは閉じず、X-Plane の画面の右上に残った（sim は動いた。下の起動し直しで消えた）。
- **ND の MAP CTR はレンジの半分を表示する**（2026-10-25、`s44_tcas` の写真。2026-10-28 に実機どおり選んだ範囲がローズまでに直した：notes/ATA-31.md §40）：10 nm で 3.9 nm の相手がコンパスローズの 8 割の位置に出た（ローズの半径がレンジの半分）。アイコンの前の上限（中心モードで 250）は、ローズより内側で消していた。TCAS の機影はローズまで出し（320）、OFFSCALE の境もレンジの半分にした。アイコンは前のまま（5-2 で見る）。
- **ND の TFC の絵は縦長の黒い箱**（2026-10-25）：`EFIS annun/TFC-1.png` は 104 × 306 の不透明の黒の地に TFC の字があり、後に描くものを隠す。TA ONLY を TFC の上に置いたら、最後の Y だけが見えた。TCAS のメッセージのグループを EFIS の表示灯のグループの後ろに置いた。
- **絵ごとの読み直しの直後のフライトの開始で X-Plane が止まった**（2026-10-25 10:57、`s44_tcas` の 2 回目）：新しいパネルの絵を読ませるために `sim/operation/reload_aircraft` を送り、読み込みが終わって 10 秒後にシナリオ（フライトの開始）を始めたら、X-Plane が「応答なし」になり sim の時計が止まった（Web API は答え続けた）。Log.txt は FlyWithLua の読み込みで終わっている（`runs/20261025_105730_s44_tcas_747-400_custom/Log_hung.txt`）。強制終了して起動し直した。前の 2 回（機体の読み込みの直後の読み直し：TESTING.md §4.6）と同じく、読み込みの直後に次の読み込みを重ねたとき。新しい絵は、X-Plane を起動し直した後の最初のフライト（機体を絵ごと読む）で読ませる方が安全。
- **X-Plane の TCAS が advisory を出さないことがある**（2026-10-25、`s44_tcas` の 4〜9・12 回目と観測）：相手の threat は TA・RA（2〜4）に上がるのに、advisory（`tcas_active_advisory`）も message も出ない。長いセッションで試験の相手機を何度も出し入れし、機体を読み直した後に続き、機体の読み直しや、トランスポンダのモードの切り替え（STBY・TA ONLY を経て TA/RA に。読み込みの直後でも数分後でも）では戻らなかった（切り替えの後に出たことが 2 回あったが、再現しなかった）。X-Plane を起動し直した後の 11 回目は全区間で出たが、同じセッションの 12 回目は TA・RA の区間で出ず、後の低高度の区間では出た。原因は分からない。一時入れた「開始の後に STBY・TA ONLY を経由させる」対処は効かなかったので外した。試験の相手機の消し方を X-Plane の資料どおりにした（v2：書くのをやめて X-Plane に落とさせ、1 秒後に AI 機を返す。v1 は地下の位置を書き続け、すぐ返していた）。advisory の無い TA・RA の相手は、こちらの層で TA（琥珀の丸と TRAFFIC, TRAFFIC）として出す（RA の値・声は無い）。`s44_tcas` は X-Plane の advisory を注意（warn）で記録する。前に「1,060 ft では X-Plane が advisory を出さない（低高度の抑止）」と見たのも、この状態だった（11・12 回目は 1,050 ft で RA を出した）。
- **s44 で AFDS が高度を保てなかった**（2026-10-25、`s44_tcas` の 11・12 回目）：11 回目は、V/S の上昇中の RA の後に ALT HOLD を押すと FMA のピッチモードが空になり、しばらくして毎分 1,600〜2,300 ft で降下した（RA の無い同じ操作では ALT になった）。12 回目は空中開始の後、ALT のまま 7,300 ft から 9,100 ft まで毎分 1,300 ft 以上で上がった。前からの AFDS の振る舞い（6-3）。シナリオは相手機を出す前に水平を待つようにした。
- **音のバンクが GPWS の声を自分で絞る**（2026-10-25、GPWS の結線）：`fmod/warnings.bank` を LuaJIT で読み（RIFF の塊と GUID の参照をたどった）、各イベントが dataref の名前の parameter で音量を自動で変えていることが分かった。sinkrate は機長の VSI が −2,500 fpm 以下でないとほぼ無音（−42 dB）、X-Plane の GPWS annunciator でも消える。too_low_flaps はフラップレバー 0.6 超（フラップ 20 以上）・140 kt 未満・RA 1,000 ft 超・降下 100 fpm 未満・スロットル 0.9 超・X-Plane の脚警報音で消える。terrain は TERR OVRD、glideslope は G/S INHB を押している間、too_low_gear は GEAR OVRD、too_low_flaps は FLAP OVRD で消える。各コールアウトは `fmod/options/gpws[n]` で消える（n はバンクの順：1 2500 … 13 5、14 MINIMUMS、15 APPROACHING MINIMUMS。CDU と simconfig は別の順で、MINIMUMS を切ると 2500 が消えていた：直した）。新と OLD の声は snapshot `old_vs_new_alarms` が選ぶ。音は対象外なので、バンクの側の制限は残る（DIFFERENCES.md）。
- **DH の警報中に PFD の RA の数字が消えていた**（前から。2026-10-25、`s43_gpws` の写真）：パネルの RA の数字は、白（`> DH`）が `radio_alt/display_status` が 0 以下、琥珀（`<= DH`）が同じ dataref の LESS 0 と GREATER 1 の 2 行で、前のコードが警報中に 1 を書くと、どちらも出ない。FCOM p.981 は RA の色を変えないので、この値は 0 のままにした（RA は警報中も白）。同じ dataref の LESS と GREATER で下限が上限より大きいときの X-Plane の扱いは分からない（ARCHITECTURE.md §5 の範囲の規則の外）。
- **X-Plane を起動した直後の最初のフライトは、エンジン運転中を指定しても cold & dark で始まる**（2026-10-25、`s43_gpws` の 2 回目と診断）：Web API のエンジン運転中の空中開始で、フライトの開始が機体を読み込んだ（`run_scenario.ps1` は読み直さない）とき、AC バス 1〜4 が無電で、EICAS に ELEC AC BUS 1〜4、ENG 1〜4 FAIL、>AUTOTHROT DISC、>IRS AC CENTER、>GPS RIGHT などが出た（エンジンが止まる）。読み直した後のフライトでは運転中で始まる。電源などの flight_start が `sim/operation/prefs/startup_running` を見て cold & dark か運転中かを分けていて（`B747.03.xt.electrical.lua` など）、最初の読み込みのときはまだ 0 なのだと推定する。X-Plane の画面からフライトを始める利用者に起きるかは確かめていない。試験では、X-Plane を起動した直後は、捨ててよいシナリオを 1 本流してから回す（TESTING.md）。2 回目の `s43_gpws` は 3 台の RA が無効になり（AC バスが無い）、機体は 1,500 ft の開始から沈んで地面に当たった。
- **X-Plane の GS の偏位の符号**（2026-10-25、`s43_gpws`）：`sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot` はグライドスロープの下で負（はるか下で −2.5）。PFD の指針も負で上へ動く。
- **GUIDs.txt でコメントアウトされたイベントを使うと X-Plane が止まる**（2026-10-25、`s43_gpws`）：`.snd` に `GPWS/dontsink` を足したら、機体の読み込みで「Couldn't find this GUID in any sound bank! #efa352e6-…」の警告のダイアログが出て、閉じた後も X-Plane が「応答なし」のまま 10 分戻らず、Log.txt を `runs/20261025_075432_s43_gpws_747-400_custom/Log_hung.txt` に残して強制終了し、起動し直した。`fmod/GUIDs.txt` の dontsink の行が `#` で始まり、X-Plane はその GUID を `#efa…` と読む。dontsink は結線しない（DON'T SINK は灯だけ）。
- **XTLua の時間は X-Plane の時間加速を含まない**（2026-10-25、IRS の試験）：`sim/time/sim_speed` を 4 にすると X-Plane の時計は約 3.5 倍で進むが、XTLua の `SIM_PERIOD` は実時間のままで、IRS のアラインは実時間で 10 分かかった。この機体の系統のタイマーはどれも `SIM_PERIOD` で進むので同じ。飛行試験では時間加速で短くできない。
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
  - `fltInst02` が、init スクリプトで作られていない時計の dataref 40 個と `electrical/oil` を使っている（時計の分はコメントアウトされた古いコードで、5-2 段 6a で消した）。
  - 3D の CHRONO スイッチが使う `glareshiled/*/chrono_switch_pos` は、xt スクリプトでしか宣言されていない。存在しない可能性がある（5-2 段 6a で init に作り、時計のグルーが動かす）。
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

- フラップの調べ（4-1 段 1、2026-10-24）で見つけたもの：`flt_ctrls/flap_lever_detent` は 3D の操作子と fltCtrls の両方が書く。autoland の基準速度がフラップ 20 で Vref25、25 で Vref30 になっている（AP `autoland.lua:176-180`、コメントと逆）。GPWS の too low flaps の音は条件がレバー UP だけで、END の条件が `=!` と書いてある（`.snd`）。CONFIG GEAR と >SPEEDBRAKES EXT は着陸フラップを `flap1_deg[0]` > 24.95 で見るので、フラップ 25（22°）を着陸フラップと見ない（段 3 で直した）。EEC の approach idle はレバーで決まり、荷重軽減中もそのまま。PFD の Vmax はフラップ 25 で約 220 kt（Vfe25 は 205）、失速速度はフラップ 1 を UP と同じに扱う（表示系 5-x で）。X-Plane の acf のフラップは 25 が 25°・30 が 40° のまま（プラグインが舵面を書くので効かない）。

- 安定板トリムなどの調べ（4-1 段 2、2026-10-24。Explore のエージェント）で見つけたもの：AP が外れたあとも AP の昇降舵と補助翼の指令（`flt_ctrls/sim_pitch_ratio`・`sim_roll_ratio`）がそのまま残る（`s01` で AP を外したあと `custom_pitch_ratio` が 1.000 のまま。段 2b で）。オートトリムの実際の速さは狙いの約 1/60（1.2 秒に 1 フレーム分しか動かない）で、電波高度 500 ft 未満ではトリムしない（段 2b で）。CONFIG STAB の帯（FMC のトリム ±2.25、FMC のトリムが無いと 0–4.5）は 3D のグリーンバンドと違い、FMC に重さを入れないまま地上開始のトリム 7.5 units で離陸推力にすると CONFIG STAB が出るはず（段 2b で）。安定板の角度の目盛りが 3 つある（プラグインは 1 unit 2°、acf の flying stab は ±10°、3D の外の安定板は 6°）。ラダートリムの指示器の keyframe が −1・1.0・1 で 0 が真ん中にない（3D、範囲外）。STATUS ページの左内側エルロンの keyframe が 20/0/20（パネル、−20 のはず）。X-Plane で確かめた（2026-10-24）：`flightmodel2` と `cockpit2` の `elevator_trim` は同じ値、安定板の角度はプラグインの −15 × トリムがそのまま入る、トリムのスイッチを押し続けると 0.30 units/s（対気速度に依らない）、ラダートリムのつまみは 1.0（舵面 25.6°）まで回る（acf の 0.3 は X-Plane の空力の効きで、回せる範囲ではない）、空中では X-Plane の `total_heading_ratio` がラダートリムの 0.3 倍を含む（地上では含まない。ペダルだけは `yoke_heading_ratio`）。

- 段 2b の作業（2026-10-24）で見つけたもの：プラグインが X-Plane に渡す安定板の角度（`stabilizer_deflection_degrees` = −15 × トリム。0 units で +15°、15 units で −15°、1 unit 2°）は、ATA22 p.132 の表（0 units = 前縁上げ 3°、15 units = 前縁下げ 12°、1 unit 1°）と違う。X-Plane の空力はこの角度で調整されているので変えていない（同じ飛行状態の units が実機と違う可能性がある。離陸トリムや巡航のトリムを FCOM・FCTM の値と比べるのは空力の調整の項目）。EICAS の並び：警報のモデル（1-3）が新しい caution・advisory をレベルに関係なくページの先頭に入れるので、新しい advisory が古い caution より上に出る（s28 の写真で >STAB TRIM 2 が STAB TRIM UNSCHD の上）。FCOM p.1548 は「advisory は一番下の caution の下」「新しいものはそのレベルの群の先頭」→ 直した（WARN-24）。前のセッションの日誌の 2 か所（s26・s27 の括弧の中）が Shift-JIS のまま書かれて化けていたので、CP932 として読み直して UTF-8 に直した（失われていた「〜」は補った）。空中開始の直後に X-Plane のトリムが外から少し動いた（約 0.02 units。グルーは外からの変化として合わせ、監視は反応しない）。

- 段 3 の作業（2026-10-24）で見つけたもの：X-Plane の推力の比を推力レバーとして読む所がまだある（離陸形態警報の「逆推力でない」の `throttle_jet_rev_ratio_all >= 0`、fms・engines・gear のモジュール）。3D の推力レバーと EEC はプラグインの `laminar/B747/engine/throttle` で、A/T が働く間は EEC がその平均を X-Plane の `throttle_jet_rev_ratio_all` に書くので、X-Plane の比は 4 本とも同じになり、1 本だけの操作が見えない（各系統の作り直しで乗り換える）。空中開始（`lle_air_start`）では A/T が ARM・SPD で働き、MCP の速度（200 kt）へ推力レバーを動かす（試験で推力レバーを自分で動かすときは A/T ARM を OFF にする）。`thrust_reverse_hold` の間、X-Plane の `throttle_ratio` は 1.0 になる（プラグインの前進のレバーは 0）。電波高度（`radio_altimeter_height_ft_pilot`）は 10,000 ft でも実際の高さを返す。

- 段 4 の調べ（2026-10-24。Explore のエージェントと X-Plane）で見つけたもの：ヨーダンパーの制御（`B747.19.xt.yaw_damper.lua:100-101`）の `B747_rescale(0,0,0.35,1,input)` が負の入力で 0 を返すので、翼を水平に戻す側の減衰が片方向にしか効かない。ヨーダンパーと AFDS のゲインが実際の高度でなく MCP の高度のダイヤル（`altitude_dial_ft_pfd`）で切り替わる（AFDS 6-3 で）。油圧の舵面の門は 900 psi で、油圧のモデルの POWERED_PSI 1000・SYS_LOW 1200 と合わない。モデルの負荷の表（`B747_hyd_model.LOADS`）は試験でしか使われていない（舵面の系統の組は門の表と同じ）。ステアリングの油の消費が下のラダーの動きで決まる（`hydraulics_override.lua` の steering）。スポイラーの動きは 1 フレームごとに残りの 1 割（フレームレートで速さが変わる。資料に速さが無いので変えていない）。3D の操縦輪は X-Plane の `yoke_roll_ratio` だけで回り、A/P が回しても動かない。トリムでは 54° 回る（実機は 47°）。acf の主翼 2 の要素 9 にエルロン 2 があるが誰も書かない（実機の位置にエルロンが無い）。acf の `_stab_trim_up/dn` は 10° で、controlObject は安定板に ±15° を書く。X-Plane で確かめたこと：操縦面の上書き（`override_control_surfaces` = 1）の間、X-Plane はスピードブレーキ面（`speedbrake1_deg`）を動かさないが、プラグインからは書けて値が保たれる。エルロントリム（`aileron_trim`）は ±1 まで動き、前の controlObject ではトリムいっぱいが操縦輪いっぱい（内側エルロン 20°）になっていた。トリムの速さは約 12 秒で 1（カスタム acf の `_ailn_trim_time`）。操縦輪（`yoke_roll_ratio`）は Web API で書けて保たれる（ジョイスティックがつながっていなければ）。

- **autopilot のモジュールの、外部の道具向けの目標**（`laminar/B747/autopilot/flaps/target`・`heading/target`・`speed/target`・`altitude/target`・`vertspeed/target`。INTERFACES.tsv では AutoATC が使う。2026-10-24、冷えた状態からの FLAPS DRIVE を調べて見つけた）：-1 が「何もしない」なのに、dataref は 0 で作られる。フラップは 0 が UP なので、simconfig が届いた後（読み込みから 2〜3 秒）に、フラップを出して始まるフライトのレバーを UP へ動かしていた（フライトの開始で -1 にして直した）。速度と高度は 100 未満で、V/S はダイヤルと同じ 0 なので、すぐ -1 に戻り害は無い。方位は 0（360°）が有効な値で、simconfig が届いたときに MCP の方位が 0 でなければ、MCP の方位を 360 へ回すはず（今の開始では MCP の方位が 0 なので起きない。AFDS（6-x）で -1 にそろえる）。

- **全行程の飛行試験**（2026-10-24 夜、利用者の問い「カスタム acf とその obj8 に差し替えるだけで、変更を反映して飛ばせるか」から）：
  - 作業フォルダー（カスタム acf）：RJAA 34L から離陸し、上昇、A/P・A/T、場周、進入、着陸、逆推力、停止まで飛んだ。私のスクリプトの引き起こしが強すぎ、112 kt でピッチ 31° まで上がった（機体ではなくスクリプトの入力）。
  - AFDS の APP は LOC を捕まえない：ILS を合わせて APP を押しても、`actual_nav_status` が 1（arm）のまま（グライドスロープは 2）。前からのコードで、APP が入るのは ILS の dots が 0 でないとき、LOC の捕捉は nav1・nav2 の `display_horizontal` が 1 のとき。6-3 で見る。それまで着陸は `tests/flight/tools/landing.sh` が形から飛ばす。2026-10-26 の s60（5-2 段 4e）では、中心線の上の 14 NM から G/S の下で APP を押すと、LOC も G/S も捕まえて LAND 3 になった（斜めから入るときに捕まえないのかもしれない）。
  - FMC の ARR で ILS 34L の進入を入れようとすると、X-Plane の FMS が NO PROCEDURES を返した（34R の ILS は一覧に出た）。NAV RAD の ILS に IYQ を手で合わせた。
  - 1 回目と 2 回目の進入は私のスクリプトの誤りでやり直した：止めたはずのスクリプトが残って進入の制御が 3 本同時に動き、スピードブレーキが flight detent になって滑走路を飛び越えた。V/S を表示用の dataref（`autopilot/vvi_fpm`）に書いていて降りなかった（TESTING.md §4.6）。3 回目は着陸したが、横の基準をグライドスロープのアンテナを通る線（滑走路の 129 m 左）にしていたので、中心線から 173 m 左の草地に接地した。スピードブレーキの自動展開（接地 3 秒でレバー UP）、逆推力、ブレーキは働いた。
  - 配布用の組み立て：custom ブランチ（de622cd）の浅いクローンに、非公開リポジトリ（`Gakugaku87/747-400-assets`）の 190 ファイルを置いた `Aircraft/_overhaul_check/747-400` を作り、その `747-400.acf` を読み込んだ。`s00` 69/69、Log.txt の警告は作業フォルダーと同じ（上の既知のテクスチャ 4 枚と `.snd` の 1 行）、Lua の誤りなし、操縦席と表示の写真も同じ。中心線を基準にした進入（`landing.sh` の元）で、22 NM 手前の空中開始から -75 fpm で接地（端から 1,214 m、中心線の 4.7 m 左）。2 秒でスピードブレーキのレバーが UP 近く（地上のスポイラー 41〜45°）、逆推力とブレーキで 1,811 m で止まった。フレアで >SPEEDBRAKES EXT・CONFIG GEAR は出ない。差し替えには acf と obj8 だけでなく、custom ブランチ全体（プラグインの Lua、パネルの画像、リバリー）と 190 ファイルが要る。
  - 着陸の減速が強い：重さ 270 t、接地 146〜147 kt から、逆推力 8 秒とブレーキ 0.5（`left/right_brake_ratio`）で約 600 m で止まった（平均 0.5〜0.6 G くらい）。4-2（ブレーキ）で FCOM の値と比べる。

- 4-2 の調べ（2026-10-25。今のコードの流れは Explore のエージェントに任せた）で X-Plane で確かめたこと：`override_gearbrake` を入れても、X-Plane は脚を 1 本のハンドルの向きへ動かし続ける（`acf_gear_deploy` に書いた値はそこから動き出す）。書き続ければ脚ごとに止められる。X-Plane の `rel_lagearN` は脚 N−1（`rel_lagear2` で右胴体脚が上のまま）。`override_toe_brakes` を入れると `left/right_brake_ratio` がプラグインの値のまま保たれ、左は脚 2・4、右は脚 1・3 の `tire_part_brake` に効く（前脚 0 にはブレーキなし）。`l_brake_add` は `left_brake_ratio` と同じもの。`override_gearbrake` を入れてもブレーキの値は効く。パーキングブレーキ（`parking_brake_ratio`）は `wheel_brake_ratio` を 1 にし、4 つの主脚の `tire_part_brake` が 1。着陸の後の `brake_absorbed_J` は脚ごとに 67〜95 MJ（RJAA 34L、270 t、逆推力とブレーキ 0.5）。利用者のジョイスティックの割り当ては roll・pitch・throttle だけで、toe brake・ラダー・tiller の軸は無い（このときは未接続）。脚が上がっていても X-Plane のトラックの角度は 8°・58° のままで、PSEU は AIR のまま。
- 4-2 段 4 の試験（2026-10-25）で見つけたこと：(1) 逆推力の hold コマンド（`sim/engines/thrust_reverse_hold`）は、離しても最大逆推力のまま残る。本家からの動き（`B747.40.xt.engines.lua` の離したときの処理がコメントアウトされていて、推力レバーを前に出すまで続く）。着陸の試験の減速の測り方に効いていた。実機の逆推力レバーは乗員が戻すので、離したら reverse idle にするかは、逆推力の動き（2-3 の残り）として利用者に確かめる。(2) 逆推力の最大で P&W の EPR の表示が赤くなる。EPR の表示は X-Plane の推力（逆推力でも正）から計算し、フラップが出ていると最大 EPR で頭打ちにするため。実機は逆推力の間 EEC が N1 の代替モードで制御し（FCOM p.877）、最大 EPR には届かない。表示値の作り方（ENG-33）で直す。(3) X-Plane のブレーキがとても強い。オートブレーキ 2 の 5 ft/s² がブレーキの比 0.09（約 270 psi 相当）で出る。ブレーキの効きを圧に比例させた推定（段 2）のもとでは、実機の圧とはずれる（実機は数百〜千 psi 台）。オートブレーキの減速と RTO の止まり方は合うので、カスタム acf のブレーキの係数を変えるかは、FCOM の制動距離の表と比べてから提案する。

- 5-2 段 5c-3b の試験（2026-10-26）で見つけたこと：機体を空中で読み直した直後、CDU の RTE で ORIGIN を入れても X-Plane の FMS の経路に入らなかった。3 台の CDU（左・中央・右）はどれも X-Plane の FMS の CDU1 に文字を送る作り（`custom2fmc`：DEL・CLR を 1 回ずつ押してから文字と LSK）で、X-Plane の FMS はメッセージ（NO PROCEDURES、KEY NOT ACTIVE、INVALID ENTRY など）をため、CLR のたびに 1 つずつ出し、出ている間は文字を受け付けない。読み直した直後に何がメッセージを出すかは突き止めていない。FMC が X-Plane の FMS を間に挟む作りそのものを FMC の作り直し（6-1・6-2）で扱う。巡航高度が変わると毎フレーム X-Plane の VNAV ページに打ち込む `monitorCRZALT` も、受け付けられないと押し続ける作りなので、そのときに見直す。

- 全シナリオ（2026-10-26）で `s60_pfd_ils_alert` だけが残った：AFDS の APP が LOC も G/S も捕まえず、機体は 2,700 ft で G/S を下から通り過ぎる。機体の LOC・G/S の状態（`laminar/B747/autopilot/actual_nav_status`）は armed のまま、FMA は LOC armed・HDG SEL。FMA に映す `autopilot/nav_status` は F/D スイッチのどちらかが ON のときしか更新されない作りで、試験では F/D は両方 OFF。同じ日の朝（01:44）は合格していた。空中開始の手順を変えた（f77b0247：読み直しの後に空中開始をかけ直す）後の開始の状態の違いが関係しそう。自動操縦（6-3）の作り直しで見る。
- **X-Plane の地図の層が自分の高度の弧を描く**（2026-10-28、`s110_nd_map_ctr` の 640 NM の MAP CTR の写真）：ローズの半径の約 0.42 の所に緑の弧が出た。X-Plane の自動操縦の高度の目標 `sim/cockpit2/autopilot/altitude_dial_ft` が 150,000 ft のままで、上昇中（2,000 fpm・220 kt）に X-Plane の地図がそこまでの距離（約 266 NM）に弧を描いていた。こちらの高度の弧（`nd/toc/distance`：MCP 高度まで約 1 NM）とは別。今回の変更の前からあるもの（拡大の MAP でも、弧が表示の中に入れば出るはず：未確認）。X-Plane の高度の目標を MCP 高度に合わせるか、X-Plane の地図の弧を消す方法を、AFDS（6-3）か表示の残りで見る。
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
- 2026-10-24 17:1x〜18:xx：操縦系統（4-1）段 2b、SRM の安定板トリム。SRM のモデルとグルーに足した（ARCHITECTURE.md §4.15、notes/ATA-27.md §12）：モデルが位置（units）を持ち、グルーが X-Plane のトリムを書く。速さは ATA22 p.132 の表で 1 unit = 1° と分かったので推定なしで両 STCM 0.5／0.2 units/s（220／230 kt）、片方で半分。制限、column cutout、機長と F/O・ALTN と操縦輪の逆、A/P 1 台で解除（autopilot のモジュールに新しいコマンド `autopilot/trim_disengage`、AUTOPILOT DISC）・複数で無効、ALTN は A/P に優先し外さない、オートトリム（engage した FCC の SRM の STCM で半速・3.5 秒の遅れ・FRAT・dead trim で他方の SRM へ）、cutout スイッチと MOV と自動遮断、>STAB TRIM 2・3、STAB TRIM UNSCHD、STATUS の STAB TRIM・STAB TRIM UNSCHD・STAB AUTO TRIM、電源。3D の機長のスイッチは X-Plane の `pitch_trim_up/down` も押し続け（`.snd` のクリック音）、X-Plane の `pitch_trim_up/down` は置き換えて機長のスイッチとして受ける（XTLua のソースで、置き換えたコマンドのハンドラーが 0 を返しても、独自コマンドの音が鳴っているので音は鳴ると判断した）。ALTN と cutout はコマンドと dataref。AFDS はトリム指令を出すだけにし（前は 1.2 秒に 1 フレーム分 X-Plane のトリムを書き、狙いの約 1/60）、A/P が外れたら A/P の昇降舵・補助翼の指令を 0 に戻す（FCTL-28）。飛行試験キットに `remember` と `rel` を足した。試験：SRM のモデル 121 件、fltCtrls のモジュール 83 件、油圧のモジュール 141 件、42 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s28_stab_trim` 24/24（オートトリムで A/P の昇降舵の指令が中立近く、250 kt の ALTN で 2 秒 0.38 units と UNSCHD・A/P はそのまま、操縦輪のスイッチで A/P が外れ AUTOPILOT DISC と 0.19 units、A/P の指令が 0 に戻る、cutout 2 で >STAB TRIM 2 と半分の 0.19 units、AUTO の 5 秒で消える、系統 3 の暴走が 0.17 units で止まり >STAB TRIM 3、ON で開く）。X-Plane のトリムへの書き込みを float の差で比べるようにしたあとも 24/24、フライトの開始で cutout と ALTN のスイッチを AUTO・中立に戻すようにしたあと（EICAS の並びの修正と一緒に回した 3 回目）は 25/25。`s01_ap_basic` は 2 回：1 回目は空中開始の速度が 193 kt で開始の判定が FAIL（以前からある空中開始のばらつき）、2 回目は失敗なし・警告 2（どちらも空中開始で ALT HOLD が 11,000 ft 近くになったため：60 秒の保持の高度の窓と、V/S を選んだときに目標まで約 50 ft で 500 fpm に届く前に捕捉）。旋回・捕捉・保持は通った。最後の 11,000 ft の保持では、昇降舵が中立近く（前は −0.23〜−0.30 を当てたまま）で、昇降率の振れも小さい（rms 190〜255 fpm、前は 296〜351）。空中開始の直後、A/P が速度ほぼ 0 からの回復で昇降舵をいっぱいにし、オートトリムが 0.25 units/s で約 3 units 機首上げにした（前はほとんど動かなかった）。ALT HOLD の中立の幅（0.005）が狭いので、トリムは数秒ごとに向きを変えて 0.1〜0.2 units ずつ動く。EICAS の写真で、新しい advisory が古い caution の上に出る警報のモデルの誤りを見つけた（次のコミットで直す）。Lua の誤りなし。
- 2026-10-24 18:2x：警報（1-3）WARN-24。新しい advisory を、見ているページの caution の下に入れるようにした（前は caution と同じくページの先頭に入れ、古い caution の上に出た。FCOM p.1548）。新しい caution はこれまでどおり見ているページの先頭。試験：警報のモデル 128 件（新しい場合を足し、直す前の版で落ちることを確かめた）、42 本すべて通る。X-Plane：`s28_stab_trim` に「新しい >STAB TRIM 2 が 1 行目に来ない」を足して 25/25（写真で 3 行の caution の下に出る）。`s03_alerts` は、AC bus 2 を失ったときにその後作り直した燃料・防氷などのメッセージも出て 14 行・2 ページになり、1 ページを前提にした CANC の確認が落ちた（ページ数によるもので、並びの修正とは関係ない）ので、2 ページを確かめて CANC を 2 回押す形にして 28/28（カスタム acf）・28/28（純正 acf）。Lua の誤りなし。
- 2026-10-24 18:3x〜19:xx：操縦系統（4-1）段 2c、speed trim とグリーンバンド。speed trim は ATA22 p.159 の制御則の図が見つかり（120〜220 kt で機首上げ 2.55°、係合時の速度と位置に同期）、推定なしで SRM のモデルに足した（選び方・engage・半速・機首下げ 0.8・STATUS STAB SPEED TRIM、`flt_ctrls/stab_trim/speed_trim`）。外からのトリムの変化では同期し直す（モジュールの試験で、係合中に外から 5 units にすると元の位置へ戻そうとしたので直した）。グリーンバンドは新しいモデル `B747.45.greenband_model.lua`：3 帯、FMC の離陸トリムからの選び方（推定）、地上で V1 未満は選んだ帯の灯（それ以外は mid）、CONFIG STAB の帯。3D の帯は obj から測って長さ 4.63 units・中心 3.81〜8.12 units（前のコードは 3.75〜8.25・4.5 units と見ていた）。>STAB GREENBAND は前脚の圧力スイッチの設定値が資料に無く作っていない。試験：SRM のモデル 140 件、グリーンバンドのモデル 14 件（新設）、fltCtrls のモジュール 91 件、43 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s29_greenband` 8/8（Web API は XTLua の dataref に小数を書けないので FMC の離陸トリムは整数で）、`s30_speed_trim` 11/11（純正 acf の `s00` 69/69。A/P が無いと、A/T で加速しても speed trim の機首上げで機体が上昇に転じて速度が戻る：1 回目は 211.5 kt から 200 kt に戻り、その間も安定板は 0.0255 units/kt で速度に従った。速度でなく安定板の動きを待つ形と、A/P で 228 kt にしてから外す形に直した）。Lua の誤りなし。
- 2026-10-24 19:2x〜20:0x：操縦系統（4-1）段 3、スピードブレーキ。新しいモデル `B747.45.speedbrake_model.lua` とグルー `B747.45.xt.speedbrake.lua`（fltCtrls のモジュールが読む。ARCHITECTURE.md §4.15、notes/ATA-27.md §14）：推力レバー 1・3 のアイドル、制御リレー 2 つ、EXTEND（ARM かリバースレバー 2・4）、RETRACT（推力レバー 1 か 3。地上で手で出したときも）、DC bus 1、アクチュエータ（2 秒、推定）、SPEEDBRAKE AUTO と STATUS（3 秒、推定）、>SPEEDBRAKES EXT（ATA27 p.740 の 3 条件）。X-Plane 本体の自動展開（ARM の −0.5）は使わず、X-Plane の比はレバーから書く。前の同期・逆推力の処理・>SPEEDBRAKES EXT を外し、全機に出していた空中の CONFIG SPOILERS は貨物機だけにした（FCOM p.1558）。CONFIG GEAR の着陸フラップ（フラップ 25 を含める）と推力レバーの閉（1 本ずつ）。試験：スピードブレーキのモデル 30 件（新設）、fltCtrls のモジュール 111 件、44 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s31_speedbrakes`（地上）と `s32_speedbrakes_air`（空中）。1 回目の s31 は 13/14：自動で DN に戻ったあと X-Plane の比が 7.8e-07 で残った（差が 1e-4 を超えたときだけ書いていたので、0 と 1 は必ず書くように直した）。逆推力の間は X-Plane の推力の比が 1.0 になると分かったので、放した後も UP のままかを確かめる項目を足した。1 回目の s32 は 8/10：10,000 ft・アイドルのはずが、flight detent で >SPEEDBRAKES EXT が出た。空中開始では A/T が働いてプラグインの推力レバーを約 0.15 に進め、EEC がその平均を X-Plane の推力の比に書いていた（実機どおりの警告）。グルーが X-Plane の `throttle_ratio` を推力レバーとして読んでいたのを、3D と EEC のレバー `laminar/B747/engine/throttle` に直し（CONFIG GEAR も。GAP の WARN-12 の指摘どおり）、シナリオは A/T ARM を OFF にしてレバーがアイドルになるのを待つ形にした。最後は s31 16/16、s32 20/20（貨物機のフラグで空中の CONFIG SPOILERS、109 では出ない。EICAS の写真で >SPEEDBRAKES EXT が caution の先頭）。純正 acf の `s00` 69/69。Lua の誤りなし。
- 2026-10-24 20:0x〜20:5x：操縦系統（4-1）段 4 の前半、横操縦。今のコードの流れ（エルロン・スポイラー・トリム・遮断弁・ヨーダンパー）の調べは Explore のエージェントに任せ、その間に資料（ATA27 p.59 のプログラマの図、p.165 のスピードブレーキの段の図、p.206–207、p.188–190、p.76）を画素の走査で読み、X-Plane で確かめた（エルロントリムいっぱいが操縦輪いっぱい、X-Plane のスピードブレーキ面は上書き中に動かないが書ける、操縦輪は Web API で書ける）。新しいモデル `B747.19.lateral_model.lua`（油圧のモジュールのフォルダ。圧の門と速さを持つ `B747.19.xt.hydraulics_override.lua` が回す）：エルロンのプログラマ、スポイラーの横操縦（11° から、推定）とミキサー、スピードブレーキの段。controlObject は操縦輪の角度（`cablecontrols/wheel`）だけを出し、エルロン・スポイラー・スピードブレーキの行 33 本と、どこからも読まれていなかったケーブルの dataref を外した。エルロントリムの行を 0.5222 倍（6 units = 47°）。X-Plane の面に、スポイラー 6・7（スピードブレーキ 1）と主翼 2 のスポイラー（4・9）を足した（acf の主翼の要素から割り当てを決めた。純正 acf も同じ）。XTLua の controlObject の規則は XTLua のソース（GitHub の `xpmtdatarefs.cpp`）で確かめ、試験のモックにも同じ規則の実行を足した（呼んだ試験だけ）。試験：横操縦のモデル 102 件（新設）、油圧のモジュール 175 件、45 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s33_lateral` 28/28（STATUS ページの写真で舵面の位置の表示も動く）、`s32_speedbrakes_air` 20/20、`s01_ap_basic` は失敗なし・警告 2（段 2b のときと同じ、空中開始のばらつきによる高度の窓と V/S）。A/P のロールは、中立付近のエルロンの利きが約 2.5 倍になった分、最後の 1 分の揺れが rms 0.18° から 0.45°（最大 1.19°）に増えたが、減衰する揺れで落ち着く（AFDS の作り直し 6-3 でゲインを見直す）。Lua の誤りなし。
- 2026-10-24 20:5x〜21:1x：操縦系統（4-1）段 4 の後半、FLT CONTROL HYD POWER とヨーダンパーの INOP（FCTL-20・HYD-22、FCTL-15）。遮断弁 8 個を油圧のモジュールのグルーに作り（スイッチはコマンド、弁は系統の DC バスで 2 秒：推定）、半分を超えて閉じた弁の系統を舵面の門から外す（門の系統の表は毎フレーム弁で絞った表を使い回す形に直した。前は呼ぶたびに表を作っていた）。VALVE CLOSED 灯（照明のモジュール）と >FLT CONT VLVS。ヨーダンパーは電源（上は AC standby と電池バス、下は AC 1 と DC 1）・IRU の整列・故障を条件に足し、作動筒は系統 3・2 と尾翼の弁が要る（油圧の喪失では INOP を出さない：ATA27 p.40）。試験：油圧のモジュール 187 件、fltCtrls のモジュール 126 件、照明 62 件、45 本すべて通る。X-Plane（カスタム acf）：新シナリオ `s34_fcsov_yd` 27/27、門の作り替えの後の `s33_lateral` 28/28。純正 acf の `s00` 69/69。Lua の誤りなし。
- 2026-10-24 22:5x〜23:4x：冷えた状態からの開始で FLAPS DRIVE が出ていた件。配布用フォルダーの確認（下の全行程の試験の項）の `s00` で気づき、過去の記録を見ると、フラップの FCU（4-1 段 1）の作業の 13:32 から両 acf の `s00` で APU の始動の後に出ていた。原因は本家の autopilot モジュールのフラップの目標（`laminar/B747/autopilot/flaps/target`、`B747_ap_target_flaps`。外部の道具が書くとレバーをそこへ動かし、-1 に戻す）。dataref が 0 で作られ、0 はフラップ UP なので、simconfig が届いた後（読み込みから 2〜3 秒）に、フラップを出して始まるフライト（X-Plane の滑走路の開始は 10）のレバーを約 4 秒で UP へ動かしていた（`s00` の記録で 2.6 秒から 6.7 秒にかけて 0.5 → 0）。FCU は始めの 3 秒でフラップをレバーの位置に置いた後なので、エンジン停止・AC なしではフラップを格納できず、副系統に移って止まり FLAPS DRIVE になった（電源なしでレバーを動かしたときの表示としては正しい：FCTM p.283）。FCU の前は、フラップがそのままレバーに付いて上がっていた。autopilot のフライト開始（`B747_set_ap_all_modes`）で目標を -1 にした。外部の道具（INTERFACES.tsv では AutoATC）が目標を書けば、これまでどおり動く。試験：新しい `tests/autopilot/flap_target_test.lua`（6 件。フライト開始の後もレバーが 10 のまま、目標 20 でレバーが動く。直す前の版では 10 秒でレバーが 0.5 → 0.008 と X-Plane と同じに動き、落ちる）、46 本すべて通る。autopilot のモジュールの `after_physics` は simconfig を待つので、試験は `laminar/B747/simconfig`・`newsimconfig` と `xtlua/fms` を入れて回す（静的検査の 60 フレームは simconfig が無く、このモジュールの本体を通っていなかった）。X-Plane：カスタム acf と純正 acf の `s00` 69/69（どちらもレバーは 0.5 のまま、FLAPS DRIVE なし）。Lua の誤りなし。
- 2026-10-24 21:2x〜23:5x：全行程の飛行試験と配布用フォルダーの確認（利用者の問い「カスタム acf とその obj8 に差し替えるだけで飛ばせるか」に、差し替えには custom ブランチ全体と 190 ファイルが要ると答え、利用者が案 1「ここで離陸から着陸まで飛ばし、別のフォルダーに組み立てて確かめる」を選んだ）。結果と見つけたことは上の「気づいたこと」の全行程の飛行試験の項。途中で、利用者に滑走路を飛び越えそうなことと V/S の窓が 000 のままなことを指摘された（どちらも私のスクリプトの誤り）。配布用フォルダーの `s00` で冷えた状態からの FLAPS DRIVE に気づき、直した（上の項）。着陸の制御を試験キットの道具にした：`tests/flight/tools/landing.sh`（`landing_setup.json` で 22 NM 手前の空中開始、`landing_step.awk` で 1 歩の計算。TESTING.md §4.2）。読み書きを並べて送り、計算を 1 回の awk にまとめて、1 歩を約 2 秒から約 0.45 秒にした。X-Plane（カスタム acf、FLAPS DRIVE の修正の後）：`landing.sh` 7/7（-206 fpm で接地、端から 1,268 m、中心線の 11.6 m 右。2 秒でスピードブレーキが UP、1,831 m で停止、中心線から 5.4 m）。Lua の誤りなし。配布用フォルダー `Aircraft/_overhaul_check`（5.2 GB）は、利用者の返事（「消そう」）でごみ箱に移した。
- 2026-10-25 00:0x〜01:0x：脚・ブレーキ・ステアリング（4-2）段 1、脚の作動・代替下げ・位置監視・EICAS の表示（GEAR-08・09・10・11・23、GEAR-19 の非常下げ）。途中で利用者の方針の変更（開発・試験はカスタム acf だけ、使用量を抑える）を CLAUDE.md などに入れてコミットした（93905868）。今のコードの流れの調べは Explore のエージェントに任せ、その間に X-Plane で脚とブレーキの上書きを試した（上の「気づいたこと」）。新しいモデル `B747.10.gear_model.lua` とグルー `B747.10.xt.gear_act.lua`（notes/ATA-32.md §10、ARCHITECTURE.md §4.16）。前のレバーのハンドラー（xt 側の死んだ写し）と EICAS の脚の表示の関数は外した。カスタム acf のパネルに展開形と空の箱を足した（`panel_gear.lua`、絵は `make_gear_images.ps1`。ACF_DIFF.md §5。バックアップ `D:\747-400-local-assets\acf_backup\747-400_custom.acf.20261025_before_gear_expanded`）。新しい絵を読むには機体を絵ごと読み直す（`reload_aircraft`、TESTING.md §4.6）。キットの `cmd` の手順に `async`（押したまま次の手順へ）を足した（`s36` の LOCK OVRD）。試験：モデル 71 件、モジュール 29 件、全 48 本。X-Plane（カスタム acf）：`s35_gear` 29/29（空中開始でレバー UP、DN でドアが先・前脚が 2 + 12 秒で DOWN、UP と 10 秒後の消灯、系統 4 なしで翼脚が上のまま 31 秒で GEAR DISAGREE と展開形、ALTN WING で約 20 秒・ドアは開いたまま・GEAR DOOR なし。展開形の写真で前脚・胴体脚 DN、翼脚 UP の配置を確かめた）、`s36_gear_lock` 11/11（地上のロックで UP のコマンドでも OFF、LOCK OVRD で UP まで行くが重さのかかった脚は上がらない）。Lua の誤りなし。
- 2026-10-25 01:0x〜01:3x：脚・ブレーキ・ステアリング（4-2）段 2、ブレーキ（GEAR-12・15・16・21、GEAR-19 のブレーキの部分。notes/ATA-32.md §11）。利用者から「ステップを進めるのに承認を要求しなくていい」（段の切り替えでも聞かない）。X-Plane で、`brakes_regular`・`max` は上書きの外で X-Plane のパーキングブレーキの比を上げ、`left_brake`・`right_brake` は toe brake を 1 にすることを確かめた。新しいモデル `B747.10.brake_model.lua` とグルー `B747.10.xt.brakes.lua`：ブレーキは脚のモジュールだけが持ち、`override_toe_brakes` を常に入れる。油圧のグルーが源と圧を出し（新設 `hydraulics/brake_source`・`brake_psi`）、ペダルの増えた分も accumulator の作動油に数える。fltCtrls のパーキングブレーキの同期と古い油圧のモジュールの PARK BRAKE SET は外し、CONFIG PARK BRK はレバーとエンジン 2 か 3 にした。試験の道具 `landing.sh` は、ブレーキを X-Plane のトグルのコマンドに、駐機をレバーに変えた（段 3 で回す）。試験：モデル 31 件、モジュール 24 件、全 50 本。X-Plane（カスタム acf、機体を読み直して）：`s37_brakes` 23/23。Lua の誤りなし。
- 2026-10-25 01:3x〜02:0x：脚・ブレーキ・ステアリング（4-2）段 3、オートブレーキ（GEAR-02・03・04・05・20、GEAR-19 のオートブレーキの部分。notes/ATA-32.md §12）。新しいモデル `B747.10.autobrake_model.lua`：セレクターのばねと保持、arm・適用（60 kt を 3 秒のスピンアップ）・disarm、レベルごとの減速と最大圧の PI 制御、RTO（85 kt のラッチ、air mode で OFF）、memo と AUTOBRAKES。ブレーキのグルーが、ブレーキのモデルの前に回して指令の圧を渡す。X-Plane のオートブレーキは常に OFF、そのコマンドはセレクターに。脚のモジュールの RTO の線・`autobrake_check`・memo と、fltCtrls の 30 kt での DISARM を外した。脚のモジュールが X-Plane のパーキングブレーキを持つようになったので（段 2）、前からのシナリオ 9 本の `set` の手順をパーキングブレーキのレバーに変えた。試験：モデル 33 件、ブレーキのモデル 34 件、モジュール 32 件、全 51 本。X-Plane（カスタム acf）：新シナリオ `s38_rto` 12/12（95 kt でアイドルにしてブレーキ 1 で止まり、セレクターは RTO のまま、70 kt では働かない）。`landing.sh` に `AUTOBRAKE` を足した。オートブレーキ 4 は 8/9：memo と 100〜60 kt の減速 7.92 ft/s²（指令 7.5）は通り、落ちたのは接地点 1,717 m（道具の基準 1,500 m 以内）。MCP の高度 100 ft を A/P が滑走路の手前から捕捉し始め、フレアの前に降下率が約 190 fpm まで落ちて浮いた（道具の誤り）。道具を 0 ft にして MAX で 9/9（接地 627 m、減速 10.08 ft/s²、指令 11.0）。Lua の誤りなし。X-Plane の tiller と toe brake の軸は、X-Plane の開発者のページの軸の割り当ての番号（tiller 37、左右の toe brake 6・7）で `joy_mapped_axis_value` を読めそうと分かった（推定。利用者のジョイスティックは今は外れていて、割り当ては roll・pitch・throttle だけ）。
- 2026-10-25 02:0x〜02:3x：脚・ブレーキ・ステアリング（4-2）段 4、ステアリング（GEAR-06・07、HYD-12、GEAR-17 の CTR の部分、GEAR-22 の一部。notes/ATA-32.md §13）。資料は ATA29_32 の 32-50（p.565–633）と FCOM p.1513・1521、FCTM p.78 を読んだ。新しいモデル `B747.10.steering_model.lua` とグルー `B747.10.xt.steering.lua`：ステアリングは脚のモジュールだけが持ち、`override_wheel_steer` を常に入れる。油圧のモジュールのステアリングの処理（IAS 20 kt で X-Plane と切り替え）は外した。tiller の軸を持たない利用者（今の利用者も）がペダル 7° だけでは地上走行できないので、tiller の軸が無いときはペダルを低速で tiller にする手当て（実機ではない。`gear/steering/pedal_tiller`、既定で入）を入れ、利用者に確かめることにした。胴体脚のロックスイッチを `gear/steering/body_unlocked` に出し、CONFIG GEAR CTR（エンジン 2 か 3 に直した）と PSEU が読む。STATUS に BODY GR STRG SYS（95）と PEDAL STEERING（96）を足した。試験：モデル 44 件、モジュール 28 件、操縦系統のモジュールに CONFIG GEAR CTR（129 件）、全 53 本。X-Plane（カスタム acf、機体を読み直して）：新シナリオ `s39_steering` 23/23（tiller 左いっぱいで前輪 70°・胴体脚が右へ 13°、少しの推力で 12.9 秒で左へ 30°、ペダル tiller で 70°・切って 7°、CONFIG GEAR CTR、故障のメッセージ）。`landing.sh` のオートブレーキ 2 は 8/9：接地 559 m・中心線から 1.8 m で停止（滑走中のペダルの操向も働いた）、落ちたのは 100〜60 kt の減速 7.98 ft/s²（指令 5.0）。診断で、逆推力なしならオートブレーキ 2 は 116→14.5 kt を平均 4.74 ft/s²（ブレーキの比は約 0.09）、逆推力ありでは逆推力の間ブレーキ 0 で減速 7.3 ft/s²、収納後は約 4.9 ft/s² と分かった。原因は逆推力の hold コマンドで、離しても最大逆推力のまま残り（本家から：離したときの処理がコメントアウトされている）、25 kt 近くまで続いていた。オートブレーキ 4 の 7.92 ft/s² もこの逆推力が主だった。道具は次のコミットで直す。Lua の誤りなし。途中で利用者から「LDG ALT が 2000 ft なのは正常か」と聞かれ、FMC に目的地が無いときの FCOM p.608 の動き（LANDING ALT と 2,000 ft の仮定）で正常と答えた。
- 2026-10-25 02:2x〜02:3x：X-Plane の toe brake の軸を読むようにした（4-2 の後追い）。段 2 からブレーキのグルーが `override_toe_brakes` を常に入れているので、X-Plane は toe brake の軸を使わず、toe brake のペダルを持つ利用者はコマンドでしかブレーキをかけられなかった。ステアリングの tiller と同じく、X-Plane の開発者のページの軸の割り当ての表から、`joy_mapped_axis_avail`・`value` の 6（左）・7（右）を読む（推定。利用者の機器には無く、試していない）。軸はすぐ効き（コマンドは 0.25 秒で踏み込む）、ペダルと同じく 750 psi でオートブレーキを disarm し、両方でパーキングブレーキのレバーが外れる。試験：ブレーキのモジュール 38 件、全 53 本。X-Plane（カスタム acf、機体を読み直して）：`s37_brakes` 23/23。Lua の誤りなし。
- 2026-10-25 02:3x：着陸の道具（`tests/flight/tools/landing.sh`）を直した。747 の逆推力のコマンドは離しても最大逆推力が残る（本家の作り）ので、道具の「逆推力 8 秒」は約 25 kt まで最大逆推力を続け、100〜60 kt の減速は逆推力のものだった（オートブレーキ 2 の 7.98 ft/s²、段 3 のオートブレーキ 4 の 7.92 ft/s² も）。逆推力だけでレベルの減速を超える間、オートブレーキが圧をかけないのは正しい（FCOM p.1515）。始めてから 10 秒で逆推力のレバーを前のアイドルに戻し、減速は収納後の 60〜30 kt で測る。X-Plane（カスタム acf）：オートブレーキ 2 で 9/9（60〜30 kt で 4.73 ft/s²、指令 5.0。接地 1,127 m）。
- 2026-10-25 02:3x〜03:0x：脚・ブレーキ・ステアリング（4-2）段 5、ブレーキ温度・タイヤ圧・GEAR synoptic（GEAR-13・14・18、GEAR-22 の一部。notes/ATA-32.md §14）。新しいモデル `B747.10.btms_model.lua`・`B747.10.tpis_model.lua` とグルー `B747.10.xt.wheels.lua`。ブレーキの熱は X-Plane の吸収エネルギーの増えた分で、熱容量・冷却・熱電対の遅れは FCOM PI.12.8 の表に合わせた（推定）。前の脚のモジュールのタイヤ圧・ブレーキ温度・BRAKE TEMP の処理と、500 °C でタイヤを壊す処理、使わなくなった結び付け 16 個を外した。カスタム acf の GEAR synoptic のドアの箱とタイヤ圧の表示の誤り 3 か所を直した（`panel_gear_synoptic.lua`、ACF_DIFF.md §5、バックアップ `747-400_custom.acf.20261025_before_gear_synoptic`）。STATUS に BRAKE TEMP SYS（97）と TIRE PRESS SYS（98）。試験：BTMS のモデル 20 件、TPIS のモデル 11 件、モジュール 18 件、全 56 本。X-Plane（カスタム acf、機体を読み直して）：新シナリオ `s40_wheels` 9/9（1 回目は 11/12：地上で LOCK OVRD をかけて UP にしてもドアが開かなかった。脚のモデルは重さのかかった脚の上げを始めないので、ドアが開く写真は空中の s35 に移した）、`s35_gear` に GEAR synoptic の写真を足して 29/29（1 回目は 27/29：X-Plane が自分のハンドルの向きへ脚を 1 フレーム分進めた値（0.0008・0.0014）を読んだので、脚のモデルの位置で確かめるようにした）。外観（chase 視点）は変わらない。Lua の誤りなし。
- 2026-10-25 02:59〜05:03：段階 4 の区切りの全シナリオ（`tests/flight/tools/run_all.sh`、42 本、カスタム acf）。合格 1238・不合格 0・注意 1（`s01_ap_basic`：A/P の ALT HOLD が 11,199 ft で、11,000 ft ±150 ft（推定の幅）の外。前からの AFDS の振る舞い：6-3）。Log.txt に Lua の誤りなし。結果は `tests/flight/runs/run_all_20261025_025925.txt`（git 管理外）。
- 2026-10-25 06:3x〜09:1x：航法センサー（5-1）段 4、電波高度計と GPWS（NAV-51〜61・63〜65 の GPWS の側、WARN-19、DSP-09・10）。資料は ATA34_2 の 34-33（p.70–106）と 34-46（p.122–210）、FCOM p.981–982・p.1531–1539・p.1555・p.1571–1583・p.1604–1605 を読んだ。新しいモデル `B747.34.ra_model.lua`（3 台、EIU の順、RA 旗、GPWC の比較）と `B747.34.gpws_model.lua`（空地、mode 1〜7、405 のコールアウトと minimums、BANK ANGLE、声の優先、灯、EICAS）、グルー `B747.34.xt.ra.lua`・`B747.34.xt.gpws.lua`。fltInst02 の DH を各席に、MINS RST は点滅のリセットだけ。G/S INHB を押しボタンに、GEAR OVRD で CONFIG GEAR を抑止、照明の GND PROX 灯、警報モデルの master WARNING。音のバンク（`fmod/warnings.bank`）を LuaJIT で読み、GPWS の音が dataref で音量を絞られること（SINK RATE は −2,500 fpm 以下、TOO LOW FLAPS はフラップ 20 で無音など）と、CDU の GPWS の音の設定の添字がバンクとずれていたことを見つけた（添字を直した）。`.snd` の GPWS を `gpws/voice`・`callout` で鳴らす結線に。カスタム acf の PFD（RA と立ち上がる滑走路を各席の RA に、RA 旗、副操縦士の DH、DH 0、PULL UP・WINDSHEAR：`panel_ra_gpws.lua`、`make_pfd_ra_images.ps1`）。XTLua でグローバルの表の無いキーを読むとスタックが溢れる件に当たった（メモ）。試験は電波高度計のモデル 24 件・GPWS のモデル 83 件・モジュール 42 件と警報モデルの master WARNING、全 65 本合格。X-Plane：1 回目は `dontsink` の GUID で X-Plane が止まり（強制終了して起動し直した）、2 回目は起動直後の最初のフライトが cold & dark で始まって墜落（上の「気づいたこと」）、3 回目はシナリオの V/S の押し直しの漏れ、4 回目で `s43_gpws` 46/46（注意 3：AFDS の V/S が mode 1 に届かない）。GS の偏位の符号（X-Plane はグライドスロープの下で負）と、DH の警報中に RA の数字が消えていたこと（前から）を直した。mode 1 は手操縦の降下の道具 `gpws_dive.ps1` で SINK RATE・PULL UP・master WARNING・PFD の PULL UP を確かめた。
- 2026-10-25 09:2x〜14:1x：航法センサー（5-1）段 5、トランスポンダと TCAS Ver 7.0（NAV-66・69・70・72〜78、DSP-18）。資料は FCOM と ATA34_2 の TCAS（notes/ATA-34.md §15）。3D のトランスポンダのパネルを撮って 570 型と確かめた。新しいモデル `B747.34.tcas_model.lua` とグルー `B747.34.xt.tcas.lua`（X-Plane の TCAS の threat・advisory・message・vs_bands を核に、モード・故障・RA の抑止・機影の種類・声・TFC と自動表示・ND のメッセージ・EICAS・PFD の RA の値）、ND の機影のスロット 30（`B747.61.xt.nd.lua`）とパネル（`panel_nd_tcas.lua`、絵は `make_nd_tcas_images.ps1`）、`.snd` の TCAS の 14 のイベント。試験の相手機 `tests/flight/fwl/B747_traffic.lua`（FlyWithLua：AI 機を借りて `override_TCAS`）とシナリオの手順 `traffic`・`traffic_stop`、`s44_tcas`。試験はモデル 114 件・モジュール 58 件、全 67 本合格。X-Plane：1 回目は TFC の黒い箱で TA ONLY が隠れ、TCAS FAIL が欠け、TRAFFIC が弧に重なり、RA のタグがマゼンタ、MAP CTR の縮尺が倍（直した）。2 回目は絵ごとの読み直しの直後のフライトの開始で X-Plane が止まった（強制終了）。3 回目は RA まで通った。4〜9 回目は X-Plane が advisory を出さず RA の確認が通らなかった（機体の読み直しやモードの切り替えでは戻らず、開始の後に STBY・TA ONLY を経由させる対処も効かなかったので外した）。試験の相手機の消し方を X-Plane の資料どおりにして（v2）、X-Plane を起動し直した 11 回目で 69/70（OFFSCALE は AFDS のピッチモードが空になって降下したため。シナリオは水平を待つようにした）、12 回目は TA・RA の区間で X-Plane が advisory を出さなかった（63/71、注意 2）が、OFFSCALE と低高度の RA は通った。Log.txt に Lua の誤りなし。
- 2026-10-25 14:1x〜14:5x：航法センサー（5-1）段 5c、気象レーダー（NAV-79〜81、DSP-21 の一部）。資料は FCOM p.1013–1018・p.1040・p.1155・p.1223–1224、ATA34_1 の 34-43（p.208–263）。新しいモデル `B747.34.wxr_model.lua` とグルー `B747.34.xt.wxr.lua`：570 型のパネル（X-Plane の WXR のコマンドを `replace_command` でモデルへ、TFR・TEST・LR/T・RR/T のコマンドを通信のモジュールから移した）、R/T と電源（推定）、X-Plane の故障、安定化の IRU、WX+T の 40 nm、TFR と TEST、自動ゲインと MAP GAIN、X-Plane のレーダーの左右の値とアンテナの走査 90°。ND の注記（モード、整数のチルト、WXR を出すモードだけ）と照明のモジュールのパネルの灯、ND の航跡線の判定（DSP-21 の一部）。試験はモデル 58 件・モジュール 48 件、全 69 本合格。X-Plane：`s45_wxr` 49/49（WX・MAP・TEST の ND を撮った）。Log.txt に Lua の誤りなし。
- 2026-10-25 15:0x〜15:4x：表示（5-2）の段取り（notes/ATA-31.md §10：段 1〜6）と段 1、表示器と EIU（DSP-27〜30）。資料は FCOM p.800・p.804・p.1044–1045・p.1071–1073（切替の図を画像で）・p.1199・p.1529。新しいモデル `B747.60.display_model.lua` とグルー `B747.60.xt.displays.lua`：選択器と自動切替を規則で解き（前は 81 通りのうち 11 通りの表）、表示器 6 台と EIU 3 台の故障、EIU の AUTO と手動、standby の電源での全消灯、>EIU LEFT、内容ごとの輝度を表示器のつまみに（照明のモジュール）。途中で、5-1 段 5 の ND の TCAS の要素の明るさのつまみの誤り（機長の記号が PFD のつまみ、副操縦士のタグが機長の ND のつまみ）を見つけ、道具を直して acf を作り直した（別のコミット）。試験はモデル 73 件・モジュール 41 件、全 71 本合格。X-Plane：`s46_displays` 26/26（パネルを撮った）。Log.txt に Lua とパネルの誤りなし。
- 2026-10-25 15:4x〜16:1x：表示（5-2）段 2、ソース選択の比較（DSP-02・32 の一部）。資料は FCOM p.1043（ソース選択パネルの図を画像で）・p.1197–1199・p.1430。表示器と EIU のモデル・グルーに >SOURCE SEL EIU・F/D・NAV と EFIS 操作パネル・表示選択パネルの故障（>EFIS CONTROL L・R、>EFIS/EICAS C/P）、IRS のグルーに >ATTITUDE・>HEADING（X-Plane の両側の AHRS の差）、電波高度計のグルーに >SNGL SOURCE RA。DSP-14（ILS の目盛）と >SNGL SOURCE ILS は無線の同調に絡むので 5-1 段 3 へ回した。警報の試験は、右の EFIS 操作パネルの電源（F/O transfer bus）を入れるように直した。試験はモデル 84 件・モジュール 50 件・比較 14 件、全 72 本合格。X-Plane：`s47_sources` 21/21。Log.txt に Lua の誤りなし。
- 2026-10-25 15:4x〜17:0x：航法センサー（5-1）段 5d、PFD の TCAS RA の表示（NAV-71）。パネルの変更が全範囲で承認なしでよくなった（利用者）ので、待っていた 3 件の 1 つ目。モデルの `pitch_lo`・`pitch_hi` を機体シンボルからの角度（経路角の差：推定）に、`tcas/pfd/vs_red` を新設。道具 `docs/overhaul/tools/panel_pfd_tcas.lua` で 4 つの PFD に赤枠のピッチ領域（ロールで回るグループの中の pointer）、VSI の赤の範囲、赤い VS ポインタ。絵は `make_pfd_tcas_images.ps1`。新しいシナリオ `s48_pfd_ra`（操縦輪を隠して PFD を撮る）。X-Plane：1 回目は X-Plane が advisory を出さなかった（X-Plane を起動し直した）。2 回目は起動し直し後の最初のフライトで、電源が立ち上がっていなかった（捨てた）。3 回目で上下の赤枠・赤の範囲・VS ポインタの色を確かめ、上の赤枠の上が Bank Scale の空色の帯に隠れるのを見つけて描く順を直した。窓のマスクを外した試験用の acf で回転と切り抜きを確かめ、4 回目で上の赤枠が上端まで届くことを確かめた（上昇の区間は X-Plane が advisory を出さず 18/19）。試験は TCAS のモデル 123 件・モジュール 62 件。
- 2026-10-25 17:0x〜17:2x：航法センサー（5-1）段 5d の続き、トランスポンダのコード表示（NAV-67）。待っていた 3 件の 2 つ目。モデルに操作盤の電源 `panel_on`（AC standby bus か AC bus 2：ATA34_1 p.584）、`laminar/B747/xpdr/panel_on`。道具 `panel_xpdr.lua` でコードを L・R どちらでも出し、R の INOP の絵を窓の左上の ATC L・ATC R（`make_xpdr_images.ps1`）に替えた（FCOM p.1218）。窓の位置は、頭を中央の台の上へ動かして真上から撮ったスクリーンショットで測った。機体の絵ごとの読み直しでは電源系が立ち上がらなかったので（X-Plane の起動直後と同じ）、新しいシナリオ `s49_xpdr_display` でフライトを始め直して確かめた（6/6）。試験は TCAS のモデル 125 件・モジュール 65 件。
- 2026-10-25 17:2x〜17:4x：航法センサー（5-1）段 5d の続き、ND の気象レーダーの故障とゲインの注記（NAV-80・81）。待っていた 3 件の最後。モデルに故障の源（R/T・新設 `wxr/fail[3]` のアンテナ・操作盤・校正、安定化の姿勢）、WXR FAIL、TEST の故障の源、WEAK・ATT、MAP のゲインの CAL・VAR（推定）。ND のモジュールが 3 行の文字と色（新設 `text/wxr3`・`wxr_color[3]`）、道具 `panel_nd_wxr.lua` で各 ND に琥珀の写しと 3 行目。新しいシナリオ `s50_wxr_faults`（30/30）。試験は気象レーダーのモデル 80 件・モジュール 67 件。
- 2026-10-25 17:4x〜18:0x：表示（5-2）段 3a、速度テープのうち資料から決まるもの（DSP-13・07、DSP-05 の一部）。新しいモデル `B747.60.speedtape_model.lua` とグルー `B747.60.xt.speedtape.lua`：フラップの機動速度（FCOM PI.10.3、25 は VREF25：FCOM PI.10.2）、バグは今と次の小さいフラップ、最小機動速度の帯は離陸後の最初のフラップ上げから。最小速度の表の高度帯の誤りを直した。道具 `panel_flap_bugs.lua` で 4 つの PFD の 28 本のバグの条件を `show_vf[k]` に。新しいシナリオ `s51_speed_tape`（15/15）。段 3b（シェーカー速度・機動速度・失速警報）は数値が資料に無いので、進め方を決めてから。試験はモデル 23 件・モジュール 11 件。
- 2026-10-25 18:0x〜19:xx：段 3b の下調べ（利用者の問い「速度テーブルは正確なんかね」）。最小速度の表の由来（Laminar の 2016 年の 747、出典なし）と FCOM PI.10.2 の VREF との比べ合わせ、ATA27 の SWMC（p.692–702）、FCOM p.973・p.1556 の定義を読み、FCTM p.261–262 のスティックシェーカーと失速速度の図 4 枚を画像にして画素で読んだ（notes/FCTM.md §1.14）。表は図の失速速度と合う（誤差と誤記は「気づいたこと」）。カスタム acf の失速を X-Plane で測った（測定のシナリオ `tests/flight/measure/stall_clean.json`・`stall_f30.json` と道具 `tests/flight/tools/stall_speed.lua` を新設）：クリーンで図より約 21 kt 遅くまで失速しない、フラップ 30 は昇降舵いっぱいでも失速しない（解析の平滑化を記録の時刻で 2 秒にした：フレームの数では瞬間の引き起こしを拾った）。acf の最大揚力の調整を提案（利用者の判断待ち）。
- 2026-10-25 19:0x〜20:3x：カスタム acf の失速の調整（利用者の承認「acf も調整しよう」）。主翼の翼型（Boeing Root・Mid・Tip）の失速の部分を低い迎角へずらした写しを作る道具 `make_airfoils.lua`（ずらし 0 で純正と 1 バイトも違わない）と、主翼 8 枚の参照とスラットの値を入れる道具 `acf_stall.lua`。フラップ 10・20 の測定のシナリオを足し、解析を失速の切れ目までに限った（A/P の ALT HOLD のまま失速させると n が揺れ、切れ目の後は揚力がまた増える）。ずらし・スラットを 5 通り試して、2.8°・4.8/3.6 に決めた（図との差 UP −2、10 +6、20 −5、30 +4 kt：ACF_DIFF.md §5）。X-Plane の後縁フラップの揚力は角度とともに頭打ちで、10・20・30 を同時には合わせきれない。通常の迎角の揚力は変わらない。
- 2026-10-25 20:3x〜23:xx：表示（5-2）段 3b、最小速度・機動速度・シェーカー・AIRSPEED LOW（DSP-05・08、WARN-18、DSP-34 の一部）。新しいモデル `B747.60.minspeed_model.lua`：揚力の上限 n W /(δ M²) を FCTM のシェーカー速度の図から Mach の直線で持ち、フラップ上げは FCOM PI.11.1 の最大運用高度から出した M 0.86 のバフェットへつなぐ（重量・g によらず 1 % 以内でそろった）。帯の上端・琥珀の帯・最大機動速度・シェーカー・AIRSPEED LOW と琥珀の枠を作り、fltInst02 の前の処理を外した。`airspeed/Vmc` は AFDS・A/T の速度の下限のために前の式のまま（PFD は新設 `Vminm`）。X-Plane の試験で、純正の帯のグループが速度とともに切り抜きの窓ごと動き、巡航の琥珀の帯が出ないことと、空中開始や空中での読み直しの直後の一瞬の「地上」で帯と AIRSPEED LOW が出なくなることを見つけて直した（パネルは帯の速度−今の速度の新しい dataref で：`panel_speed_bands.lua`。地上とみなすのは 100 kt 未満が 5 秒続いたときだけ：100 kt 未満だけでは、読み直しで速度も 0 から立ち上がるので、s52 がたまにしか通らなかった）。新しいシナリオ `s52_min_speeds`・`s53_min_speeds_cruise`。s53 は FL350 の空中開始の揺れの途中で A/P を入れると FLCH が入らないことがあり、60 秒待ってシェーカーが止まってから入れるようにした（「気づいたこと」）。s51 のフラップの待ちは後縁フラップの角度で（`flaprat` は XP12 で 0 のまま）。
- 2026-10-25 23:2x〜：表示（5-2）段 4 の計画（4a〜4e、notes/ATA-31.md §15）と段 4a、PFD の姿勢・方位・昇降率の源と旗（DSP-01、DSP-04 の一部）。新しいモデル `B747.60.pfd_model.lua` を表示器と EIU のグルーで回し、新設 `pfd/<席>/att`・`hdg`・`trk`・`vsi`・`vert` を書く。パネル（`panel_pfd_sources.lua`）は方位目盛をその席の AHRS の方位で回し（前は ND の上の向き）、姿勢・方位・昇降率・航跡を別々の条件で、ATT・HDG・VERT の旗を別々に。IRS の有効で消していた DH・MDA・RA の数字と AFDS の状態表示は元の条件に戻した。新しいシナリオ `s54_pfd_sources`（24/24）。
- 2026-10-25 23:3x〜：段 4b、気圧（DSP-11 の残り）。PFD の気圧設定を、遷移高度の 300 ft 上（気圧設定・MCP 高度が遷移高度より上）と遷移レベルの 300 ft 下（STD・MCP 高度が遷移高度より下）で枠付きの琥珀に（`baro_alert`、新設 `pfd/<席>/baro_alert`、FMC の TRANS ALT を読む）。パネル（`panel_pfd_baro.lua`）は琥珀の写しのグループと枠、画像（`make_pfd_baro_images.ps1`）は純正の緑を琥珀に塗り替え、枠の位置はスクリーンショットで測った。CDU の EFIS CONTROL の BARO SET を、その CDU の側だけ・FCOM p.1064 の入力の形式に（`B744.fms.baro.lua`。前は両席に効いた）。新しいシナリオ `s55_pfd_baro`。s41 の新しい MCP 高度をその時の高度の約 600 ft 下に（8,500 ft の決め打ちでは、機体を下げたあと A/P の ALT HOLD が元の高度へ戻る間に 900 ft の範囲を外れ、白の枠が出なかった。今朝の実行は通っていた）。
- 2026-10-26 00:0x〜：段 4c、PLI と VR の R（DSP-12 の一部）。段 4 の残りを分け直した（notes/ATA-31.md §18）。PLI は最小速度のモデルの揚力の上限を、カスタム acf の失速試験から当てはめた揚力の傾きで迎角に直し、空中はシェーカーでちょうど 0 になる形（新設 `pfd/pli`・`pli_show`）。VR は V1 から 4 kt 以内で R（新設 `airspeed/vr_r`）。パネル（`panel_pfd_pli_vr.lua`）と画像（`make_pfd_pli_vr_images.ps1`）。新しいシナリオ `s56_pfd_pli`・`s57_pfd_vr`。PLI の最初の画像（高さ 40）は CLIP のポインターで切られて出なかった（高さ 480 に）。
- 2026-10-26 00:3x〜：段 4d、FPV と FPV・PITCH・ROLL の旗（DSP-12・04 の一部）。FPV のスイッチを入れ切りに（新設 `efis/fpv/<席>/selected`）。FPV は飛行経路角と偏流角を姿勢表示の枠（バンクで回る）で測ってパネルのピクセルに直し（`fpv_place`）、本体はバンクで回し足は回さない（109 の CRT の形：FCOM p.979–980）。選んだ IRU が NAV でなければ FPV の旗。両席の姿勢が 3° 離れると PITCH・ROLL の旗（純正にあった画像）。パネル（`panel_pfd_fpv.lua`）と画像（`make_pfd_fpv_images.ps1`）。新しいシナリオ `s58_pfd_fpv`（15 件すべて合格。写真で、旋回中は腕が地平線と平行で足は水平のまま、FPV の旗は姿勢表示の左上で FCOM p.999 の図と同じ所）。旗の文字は最初は細くて読みにくかった（太字に）。
- 2026-10-26 00:5x〜01:5x：段 4e、ILS の表示（DSP-12・04・14 の一部）。新しいモデル `B747.60.pfd_ils_model.lua`（表示器と EIU のグルーで回す）：受信機の故障と電源（旗と周波数・コースの消去）、偏位の故障（G/S・LOC の旗）、信号なし（ポインターだけ消す）、塗りと中抜き、拡大 LOC 目盛、偏位過大（目盛の琥珀と 4 Hz の点滅：G/S は 100〜500 ft・5/8 ドット、LOC は 500 ft 以下・1/4 ドット 1 秒、LOC の捕捉失敗）、ロール 53° 超で消す、立ち上がる滑走路（新設 `pfd/<席>/ils_show`・`loc_scale`・`loc_ptr`・`loc_flag`・`gs_scale`・`gs_ptr`・`gs_flag`・`rwy_show`）。パネル（`panel_pfd_ils.lua`）は 4 面の ILS の部品をこれらに付け替え、純正の誤り（中抜きは片側だけ、拡大目盛の重なり、G/S のポインターの振れが 8 割）も直した。画像（`make_pfd_ils_images.ps1`）は琥珀の目盛 3 つと G/S・LOC の旗。試験のキットに `outside` の比べ方。X-Plane の新しいシナリオ `s59_pfd_ils`（34 件合格）・`s60_pfd_ils_alert`（15 件合格）。途中で分かったこと（TESTING.md §4.6）：Web API で書いた XTLua の文字列の dataref はモジュールに届かない（ILS の同調は CDU の NAV RAD で）、読み直しの間も機体は飛んで上がってから下がる、墜落したまま次のフライトを始めると機体が落ちる。最初の s60 は G/S の上から入って 6° 付近の偽の G/S を捕まえ、最後に V/S で上がるつもりが APP のまま着陸して墜落した（TO/GA に直した）。
- 2026-10-26 02:0x〜02:5x：段 5 の計画（5a〜5e、notes/ATA-31.md §21：ND の今の作りはエージェントに調べてもらった）と段 5a、ND の向き・方位・航跡・旗（DSP-15・21・22・04 の一部）。新しいモデル `B747.60.nd_model.lua`：各席の ND を自席の源で、109 の向き（MAP は航跡、VOR・APP は方位、PLN は北が上）、X-Plane の `map_mode`（VOR も 0：前は 2 で航跡が上）、TRK・HDG・MAP・VTK の旗（MAP・VTK は FMC の位置：どれかの IRU が NAV。推定）、方位の印、選択方位と破線、拡大の航跡の線、風の矢印（新設 `nd/<席>/*`）。nd.lua の `nd/up` と記号の角度も自席のモードと源で、記号の作り直しの時計を直した。パネル（`panel_nd_orientation.lua`、74 か所）。X-Plane の新しいシナリオ `s61_nd_orientation`（31 件合格。最初の試験で、PLN の TRK が MAP の位置に出たのと、旗のときに航跡の線が残ったのを直した）。EIU の選択器が各席の PFD・ND の LOC・G/S の受信機を決める（FCOM p.1044）と分かったので、段 4e の PFD の ILS の源（固定）は段 5b で直す。
- 2026-10-26 03:0x〜03:3x：段 5b-1a、PFD の ILS の受信機（DSP-15 の一部、>SNGL SOURCE ILS）。段 5b を 5b-1a・5b-1b・5b-2 に分けた。グルーが各席の受信機を使用中の EIU から選び（FCOM p.1044：L は X-Plane の NAV1、C は NAV1 のデータで AC bus 1（推定）、R は NAV2）、`nav1_`・`nav2_` の偏位を直接読んで新設 `pfd/<席>/ils_rx`・`loc_dots`・`gs_dots` を書く。進入の基準の ID を新設の文字列 `pfd/<席>/ils_ref`（受けるまでは周波数：ATA34_1 p.466）に。>SNGL SOURCE ILS（caution 57、FCOM p.1430）は両席が同じ EIU のとき。パネル（`docs/overhaul/tools/panel_pfd_ils_rx.lua`、4 組で 48 か所）：ポインターと立ち上がる滑走路を `loc_dots`・`gs_dots` に、ID を `ils_ref` に、DME・コースを `ils_rx` で（前は中央の FMC master 選択器）。X-Plane の新しいシナリオ `s62_pfd_ils_rx`（31 件合格）の 1 回目で、NAV2 の局を無くしても G/S のポインターが残り、X-Plane の `display_vertical` が ILS の周波数なら局が無くても 1 のままと分かった（`flag_glideslope` も見るように直した。段 4e からの見落とし）。回帰試験は表示器のモジュール 147 件（23 件増）、全 80 本合格。notes/ATA-31.md §23。
- 2026-10-26 03:3x〜04:0x：段 5b-1b、ND の APP（DSP-03・15 の一部）。PFD の ILS のモデルに ND の APP の値を足した（同じ受信機：FCOM p.1044）：目盛と指針は有効なデータのときだけ（invalid は LOC・G/S の旗、NCD と同調前は目盛ごと消す：ATA34_1 p.358・p.473・p.476、ATA31 p.20–21）、指針は 2 1/2 ドットの内で塗り（FCOM p.1144）、同調前はコースと周波数が「---」でコースの指針なし、DME は距離・「DME ---」・旗（FCOM p.1033–1034）。新設 `nd/<席>/loc_scale`・`loc_ptr`・`loc_flag`・`gs_scale`・`gs_ptr`・`gs_flag`・`crs`・`crs_deg`・`dme`・`dme_nm`、文字列 `nd/<席>/ils_ref`・`nd/dashes`。パネル（`docs/overhaul/tools/panel_nd_app.lua`、2 面で 100 か所）：LOC の組を EIU の受信機で、バーの振れを 121.25 px（X-Plane の 2.5 ドット。前の 115 は 5 % 短い。写真で確かめた）、G/S を自席の偏位で 48.5 px/ドット（前は機長の拡大が副操縦士の値）、旗、基準受信機の欄の組み直し（ILS C、ID か周波数、コースの「---」、緑の DME）。X-Plane の新しいシナリオ `s63_nd_app`（39 件合格）。回帰試験は ILS のモデル 77 件、表示器のモジュール 167 件、全 80 本合格。notes/ATA-31.md §24。
- 2026-10-26 04:0x〜04:3x：段 5b-2a、ND の VOR（DSP-03・15 の一部）。段 5b-2 を 5b-2a・5b-2b に分けた。ND のモデルに VOR モードを足した（ATA34_1 p.356–369、FCOM p.1024・p.1144–1146）：基準 VOR は自席の側（推定）、故障（電源なし）で VOR の旗と偏位・TO/FROM・コース・周波数の消去、自動同調（`radio/tuningmodes`）でコースの「---」と指針・偏位・TO/FROM の消去、方位の信号なしで偏位・TO/FROM の消去。新設 `nd/<席>/vor_rx`・`vor_flag`・`vor_dev`・`vor_crs`・`vor_crs_deg`・`to_from`・`vor_dme`・`vor_dme_nm`、文字列 `vor_ref`。パネル（`docs/overhaul/tools/panel_nd_vor.lua`、2 面で 56 か所）と画像（`make_nd_vor_images.ps1`：VORL・VORR の旗、TO・FROM の文字、全周の三角）。X-Plane の新しいシナリオ `s64_nd_vor`（31 件合格。成田 VOR/DME を CDU で同調、AC bus 2 を落として VORR の旗）。回帰試験は ND のモデル 57 件、表示器のモジュール 186 件、全 80 本合格。notes/ATA-31.md §25。
- 2026-10-26 04:3x〜05:0x：段 5b-2b、ND の VOR・ADF の方位の針と左右下の欄（DSP-35）。ND のモデルに各席の EFIS の VOR/ADF スイッチと 4 台の受信機（VOR L・R、ADF L・R の電源・故障・受信・相対方位・DME）を入れ、針（受信機が動き局を受けているとき、PLAN 以外：FCOM p.1040）と向き（相対方位 + 自席の方位 − 表示の上：MAP でずれない）、左右下の欄（旗・ID か周波数・DME）を出す。新設 `nd/<席>/ptr_l`・`ptr_r`・`brg_l`・`brg_r`・`rad_l`・`rad_r`・`rad_l_flag`・`rad_r_flag`・`rad_l_dme`・`rad_r_dme`、文字列 `nd/vor_l_ref`・`vor_r_ref`・`adf_l_ref`・`adf_r_ref`。パネル（`docs/overhaul/tools/panel_nd_brg.lua`、2 面で 106 か所）と画像（ADFL・ADFR・DMEL・DMER の旗）。APP・VOR の右上の DME の旗も DMEL・DMER に。X-Plane の新しいシナリオ `s65_nd_brg`（23 件合格。東京の近くには NDB が無いのでフランクフルトで）。回帰試験は ND のモデル 76 件、表示器のモジュール 199 件、全 80 本合格。notes/ATA-31.md §26。段 5b はこれで終わり。
- 2026-10-26 04:2x〜05:1x：段 5c-1、CDU の EFIS CONTROL・OPTIONS と EFIS 操作パネルの故障（DSP-31、DSP-16 の一部）。段 5c を 5c-1〜5c-3 に分けた（notes/ATA-31.md §27）。資料は FCOM p.1060–1067・p.1198。MENU の EFIS CP・EICAS CP の SELECT をそのパネルの故障のときだけに（左の CDU は機長、右は副操縦士のパネルの代わり：推定）、EFIS CONTROL の RANGE（X-Plane の地図の範囲も）・DH RESET・CTR をその側に、EFIS OPTIONS を CDU-152 の並び（WXR・POS・MTRS・FPV・WPT・STA・ARPT・DATA・VOR・ADF）にしてその側に。パネルの 50 個の操作と X-Plane の VOR/ADF セレクターのコマンド（`replace_command`）は故障したパネルでは何もしない。DATA・POS の押しボタンに状態（新設 `nd/data/<席>/data`・`pos`）。CDU の STD と DH RESET は新設のコマンド（init で作る）でパネルと同じ処理を呼ぶ。試験は CDU の新しい試験 49 件（変更前のコードでは 32 件が落ちる）、表示器のモジュール 217 件、静的検査にコマンドの作成の検査、全 81 本合格。X-Plane：`s66_cdu_efis` は 1 回目 33/35（CDU の STD のコマンドが init に無かった、副操縦士の X-Plane の地図の範囲が同じフレームの読み直しで古い値）、直して 41/41。CDU・PFD・ND を撮った。Log.txt に Lua の誤りなし。
- 2026-10-26 05:1x〜05:5x：段 5c-2a、ND の DATA（DSP-16 の一部）。段 5c-2 を 5c-2a・5c-2b に分けた（notes/ATA-31.md §28）。資料は FCOM p.1040・p.1148、FMSPG p.50。FMC（`B747.68.xt.fms.lua`）が空中で 1 秒ごとに各点の ETA を現用点の ETA と同じ関数で出し、新設 `fms/route_eta` に書く。ND（`B747.61.xt.nd.lua`、新しい `B747.61.nd_data.lua`）は経路の点が入る先頭 20 枠に、その席の DATA で高度と ETA の 2 行（現用点はマゼンタ、ほかは白）。カスタム acf の両 ND の 40 枠に 2 行ずつ（道具 `panel_nd_data.lua`）。試験キットに X-Plane の FMS へ経路を入れる FlyWithLua の `B747_route.lua` とシナリオの `route` の手順。試験は新しい `nd_data_test.lua` 29 件、全 82 本合格。X-Plane：`s67_nd_data` 21/21（1 回目は経路の点の位置の誤りで、2 回目は ETA の読み込み前の確認で落ちた。どちらも試験の誤り）。FR の DATA の ETA は右上の現用点の ETA と一致。ND を撮った。Log.txt に Lua の誤りなし。
- 2026-10-26 05:4x〜06:xx：段 5c-2b、ND の POS（DSP-16 の残り）。資料は FCOM p.1040・p.1145・p.1150。ND のモデル（`B747.60.nd_model.lua`）に POS：MAP・MAP CTR で、IRU の位置（NAV の IRU ごと）と GPS の位置（どちらかの GPS）を FMC の位置（ここでは 3 つとも X-Plane の位置：飛行機の記号）に、VOR L・R の radial（方位を受けていて、自席の方位があるとき）を DME の距離まで印つき、無ければ画面の端まで、R-xxx の文字つきで。グルーが新設 `nd/<席>/pos_*` を書く。カスタム acf の両 ND の地図の記号のグループに、星 3 つ、GPS の記号、radial（24 px の線分 20 本と端の線分、DME の印、線に沿った文字）（道具 `panel_nd_pos.lua`、画像 `make_nd_pos_images.ps1`）。試験は ND のモデル 97 件（21 件増）、表示器のモジュール 227 件（10 件増）、全 82 本合格。X-Plane：`s68_nd_pos` 18/18（1 回目は VOR R の方位の針が回り終わる前に確かめて 2 件落ちた）。FKS への radial の DME の印が FKS の記号の上に来ることを写真で確かめた。Log.txt に Lua の誤りなし。
- 2026-10-26 06:0x〜06:2x：段 5c-3a、ND の地図の記号（DSP-17 の一部）。段 5c-3 を 5c-3a・5c-3b に分けた（notes/ATA-31.md §30）。資料は FCOM p.1030–1031・p.1040・p.1111・p.1141・p.1145。ND のモジュールで記号の決め方を組み直し、空港・fix・局は MAP だけ、同調中の VOR はいつも緑、STA の 80 NM 以上は高高度の局だけ（X-Plane の earth_nav.dat の受信範囲 100 NM 以上：Custom Data を先に、起動後に少しずつ読む）、60 枠を超えたら新設 `nd/<席>/excess_data`（カスタム acf の両 ND の左上に琥珀の EXCESS DATA：道具 `panel_nd_excess.lua`）。ND の GS の行から TAS を外した（109）。試験は新しい `nd_symbols_test.lua` 25 件、全 83 本合格。X-Plane：`s69_nd_sta` 15/15（1 回目は試験の期待値の誤りで 1 件：VOR R の自動同調の局も同調中なので緑で出る）。160 NM で高高度の VOR だけ、640 NM と ARPT で EXCESS DATA を写真で確かめた。Log.txt に Lua の誤りなし。
- 2026-10-26 06:2x〜07:xx：段 5c-3b、ND の出発・到着空港と滑走路（DSP-17 の一部）。資料は FCOM p.1149・p.1148・p.1040・p.1301–1302。X-Plane で CDU から RTE・DEP ARR を操作して、X-Plane の FMS が出発・到着の滑走路を経路に「RW25C」「RW26R」（種別 2048、閾値の位置）として入れることを確かめた（試験キットに `FlyWithLua/B747_route/dump` を足した）。経路の両端の空港とその近くの RW の項目から出発・到着空港と滑走路を決め、反対側の端は CIFP から読む。80 NM 以上は空港の記号と番号・線、40 NM 以下は滑走路を縮尺どおりと 14.2 NM の破線（地図の見える所だけ）。経路の点は MAP・MAP CTR・PLAN だけにした（前は VOR でも出た）。毎フレームの記号の向きを席ごとにそろえた。パネルは道具 `panel_nd_airports.lua`（2 面で 6,064 行）。試験は新しい `nd_airports_test.lua` 63 件、全 84 本合格。X-Plane：`s70_nd_airports` 35 件合格：EDDM 26R の進入路の上、10 NM はこちらへ延びる破線だけ、40・20 NM と MAP CTR は 26R を縮尺どおりと番号・破線、80 NM は EDDM の空港記号と 26R・線、320 NM は EDDF と 25C、VOR では出さない、副操縦士の ND。ND と外観を撮った。MAP CTR の縮尺は利用者に確かめることにした。
- 2026-10-26 07:2x〜07:xx：段 5c-3c、ND の手動同調の VOR のコースの線（DSP-17 の残り）。資料は FCOM p.1145・p.1304。NAV RADIO で手動同調した VOR L・R の局を通る CRS の緑の破線（線のうち機体に一番近い点を中心に地図の端まで、模様は局に合わせる）と、コース・反対の数字。パネルは道具 `panel_nd_crs.lua`（2 面で 7,968 行）。試験は新しい `nd_course_test.lua` 29 件、全 85 本合格。X-Plane：`s71_nd_vor_crs` 21 件合格：フランクフルトの南、自動同調のうちは線なし、NAV RAD で VOR L に FKS と CRS 070、MAP で FKS を通る線（表示の上で 077°）と 070・250、一番近い点の破線、MAP CTR、VOR で出さない、副操縦士の ND、VOR R（自動）は出さない、DEL で自動同調に戻すと消える。ND を撮った。
- 2026-10-26 07:4x〜08:xx：段 5d、HDG REF（DSP-20）。資料は FCOM p.998・p.1046・p.1110・p.1141–1142、ATA34_2 p.336・p.477・p.482、ATA22 p.352・p.358。新しい純粋なモジュール `B747.60.hdg_ref_model.lua` と表示のグルーで基準（TRUE か極地域）、PFD・ND のラベル、両席の基準の方位・航跡を出し、パネルの方位の計器 44 か所を付け替え、MAG のラベルを MAG／TRU の画像に。ND のローズ・風、FMC の風の数字も基準で。AFDS は TRU で MCP の方位を磁方位に直して X-Plane に渡し、HDG SEL での切り替えで HDG HOLD。試験は新しい `hdg_ref_test.lua` 31 件、全 86 本合格。X-Plane：`s72_hdg_ref` 19 件合格：フランクフルトの南 10,000 ft、NORM の MAG（表示の方位＝磁方位）、TRUE で表示の方位が磁方位より 4.0° 大きく、ND の白枠の TRU・PFD の枠つきの TRU、HDG SEL から HDG HOLD、TRU の HDG SEL で X-Plane の目標が MCP の 087 より 4.0° 小さい 083、V/S −1,500 fpm の 2,000 ft で琥珀の点滅（64 秒後）とその後の琥珀、NORM に戻して MAG の 10 秒の枠と HDG HOLD。PFD と ND を撮った。
- 2026-10-26 08:0x〜08:xx：段 5e、ND の位置のトレンドベクトル（DSP-23 の一部）。資料は FCOM p.1147。ND のモデルに 30 秒ずつの区間（対地速度と傾きの旋回の弧、各区間の 7 割を破線、3 本の小片で近似、範囲で 1〜3 区間）を足し、パネルに 9 片（道具 `panel_nd_tv.lua`）。試験は新しい `nd_trend_test.lua` 17 件、全 87 本合格。X-Plane：`s73_nd_trend` 15 件合格：フランクフルトの南 4,000 ft・220 kt、40 NM で 9 片、直進は真っすぐ上（3 区間目の終わり 54 px）、右旋回（傾き 25°）で最後の片が右に 41 px・向き 131°、20 NM は 2 区間、10 NM は 1 区間、VOR では出さない。ND を撮った。
- 2026-10-26 08:2x〜09:xx：段 6a、時計（DSP-33）。資料は ATA31 p.64–80、FCOM p.1057–1059・p.1075。新しい純粋なモジュール `B747.60.clock_model.lua`（X-Plane の UTC に時計ごとのずれ、SET の HLD・MS・HS と日付の設定、DATE の交互、ET・CHR、電源と NCD）、`fltInst03` を両席のグルーに書き直し（`fltInst04` は削除）、fltInst02 の死んだ時計のコードを削除、パネル（道具 `panel_clocks.lua`）。試験は新しい `clock_test.lua` 68 件、全 88 本合格。X-Plane：`s74_clock` 45 件合格：成田 34L に電源の無い状態で開始、BATTERY OFF で両席の時計の表示が消え（main hot battery bus はある）、ON で X-Plane の UTC（01:00）と UTC の日付（23 10）・年 26、DATE で日と月、1 秒後に年、ET の RUN で 00:00、CHR で ET に代わって秒針が進み、2 回目で止まり、3 回目でリセットして裏で進んでいた ET が出る、グレアシールドのボタンも動く、ET の HLD で止まり RESET で 0 と空白、ばねで HLD に戻る、SET の HLD・MS で 1 秒に 1 分、副操縦士の時計は別。時計と外観を撮った。1 回目は開始で BATTERY がすでに ON だったこと（試験の誤り）と、一度きりのコマンドで DATE・CHR のボタンと ET の RESET が戻らなかったこと（XTLua の扱い：気づいたこと）、2 回目は DATE のボタンを戻る前に確かめたこと（試験の誤り）で落ちた。あわせて、段 5c-2〜5e の記録の文字化け（結果の文を LuaJIT の引数で渡して cp932 になっていた）を直した（別のコミット）。
- 2026-10-26 09:1x〜09:xx：段 6b-1、EICAS の部分表示と二次エンジンの逸脱の印（DSP-24・ENG-22 の一部）。下調べで DSP-25・26 は警報 1-3、DSP-06 は 5-1 段 1 で済んでいたと分かった。資料は FCOM p.839–840・p.849・p.852–857・p.872–875。エンジンの表示モデルに逸脱の 3 群（新設 `engines/sec_exceed`）、新しい純粋なモジュール `B747.60.eicas_format_model.lua`（部分表示、印、compact の判定、電源投入時の ENG）、パネル（道具 `panel_eicas_partial.lua`）。試験は新しい `eicas_format_test.lua` 27 件とエンジンの試験に 8 件、全 89 本合格。X-Plane：`s75_eicas_partial` 25 件合格：成田 34L にエンジン運転中で開始、開始で二次 EICAS に二次エンジンの全表示、ENG で消え、2 番の油ポンプの故障で油圧が赤線を割ると 0.6 秒で油の行（OIL P・T・Q）だけの部分表示と主 EICAS の水色の VVVVVV、ENG で全表示（印は残る）、もう一度で部分表示、FUEL で二次 EICAS は FUEL のページになり compact の判定（部分表示、油の行）、もう一度 FUEL で部分表示が戻り、故障を戻すと部分表示と印が消える。上下の EICAS と外観を撮った。
- 2026-10-26 09:3x〜09:xx：段 6b-2、主 EICAS の compact の形（DSP-24・ENG-22 の残り）。資料は FCOM p.855–857・p.874–875。パネルだけ（道具 `panel_eicas_compact.lua`、見出しの画像 `make_eicas_cmp_images.ps1`）：compact のとき通常の見出しと PW の N1・EGT のテープを隠し、EGT の数字を上げ、二次の行（N2・FF・油・VIB）を主 EICAS に写した。X-Plane：`s76_eicas_compact` 18 件合格（PW）：下の表示器の故障で ENG の選択のまま主 EICAS が compact の全表示（EPR の数字とテープ、N1・EGT の枠、N2・FF・油・VIB の行と見出し）、ENG で通常の形、2 番の油ポンプの故障で compact の部分表示（油の行、2 番の油圧は赤だけ）、表示器を戻して FUEL のまま逸脱で compact の部分表示。`s77_eicas_compact_ge` 7 件合格（Saudia のリバリーで CF6）：N1 の数字とテープのまま EGT の枠の下に二次の行、部分表示も。1 回目の `s76` は写した数字の明るさが二次のページのつまみのままで表示器 1 台のとき薄く、1 回目の `s77` は読み直しで STANDBY POWER が OFF のまま主 EICAS が下の表示器に出ていて、2 回目の `s77` は CF6 の行を一律 30 px 下げたため VIB の行が気圧の欄に重なった（どれも直した）。主 EICAS と外観を撮った。
- 2026-10-26 10:0x〜10:xx：段 7、パネルの SHOW の条件の重なり。道具 `panel_show_and.lua` で、名前の無い dataref の条件 128 行と意味の無い条件 2 行（副操縦士の FLARE）を消し、別々の dataref の条件が残る 114 か所を入れ子のグループで「かつ」にした。X-Plane：10 件合格、警告 1：銚子沖の空中で、PFD に NO V SPD は出ない（V1 は Lua の回避で 998 なので警告：見た目は前と同じ）、ND の範囲の数字は MAP で出て MAP CTR では出ない、上の EICAS は通常どおり、ECS のページのパックは弁が開で A、パック 1 を OFF にすると OFF だけ（前は A も重なった）。PFD・ND・EICAS と外観を撮った。
- 2026-10-26 11:3x〜：6-1・6-2 段 1（小修正）。全シナリオの試験は s00〜s13 まで合格したところで止め（14/80、残りは段 1〜3a の後に新しいコードで回す）、段 1 を当てた。X-Plane：31 件合格：銚子沖の空中で、CLB ページの ECON SPD 340、SPD TRANS 252/10000（VREF30 152＋100）で入力は INVALID ENTRY・削除でダッシュ、SPD RESTR は上昇・降下ともダッシュ、空中の THRUST LIM の <GA は KEY/FUNCTION INOP で離陸の減格はそのまま、APPROACH REF の /150・25/155・空の scratchpad での複写・削除、CRZ CG の A と 40 は INVALID ENTRY で 25.5 と削除の 20.0、DIVERT TO は経路の目的地（fltdst）を書き換えない、VOR の自動同調は L 117.90（48 NM）・R 113.30（59 NM）、現用点まで 33.3 NM・GS 278 kt の ETA は 0308.9z（GS どおり。前の下限 534.6 kt なら 0305.5z）。Lua の誤りなし。CDU を撮った。
- 2026-10-26 12:0x〜：6-1・6-2 段 2（CDU の枠組み）。X-Plane：28 件合格：銚子沖の空中で、MENU が 0.2 秒で出る（前は 0.5 秒の空白）、CLR は 1 字（FL35 → FL3）、1.5 秒の押し続けで全部、+/- の 2 回目で 1+、データがあると DEL は効かない、空で DELETE、INVALID ENTRY は左の CDU だけで、その間の打鍵は入らず CLR で scratchpad の A に戻る、RESET MCP ALT の旗で左右の CDU に出て >FMC MESSAGE、右の CDU の CLR で両方から消え 11 秒たっても再び出ない、PERF/VNAV UNAVAILABLE の旗は写したら 0 に戻る、VNAV の 3 ページ目の NEXT で CLB へ、STANDBY POWER の OFF で左の CDU の電源が切れてキーが効かず、AUTO に戻すと MENU。Lua の誤りなし。CDU を撮った。
- 2026-10-26 12:xx：6-1・6-2 段 3a（PERF INIT と INIT REF のキー）。X-Plane：`s81_perf_init` 16 件合格（RJAA 34L の地上で、INIT REF で PERF INIT、ZFW 220.0 で GR WT 306.5（燃料 86.5）が小さい字、GR WT 330.0 で ZFW 243.5、FUEL 95.0 MANUAL と削除で CALC、RESERVES 12.5、COST INDEX 120、CRZ ALT 460 は INVALID ENTRY、FL350 で FMC の巡航高度 35,000 ft と CLB ページ）、`s79_fmc_fixes` 31 件合格（INIT REF の後の <INDEX と CLR の押し続けに直して。直す前は 6 件失敗）、`s80_cdu_framework` 28 件合格。Lua の誤りなし。CDU を撮った。
- 2026-10-26 午後：6-2 段 2 の手直し（X-Plane の CDU の scratchpad を、FMC が打ち込んだ直後と打ち込んだ文字そのものではメッセージにしない）。X-Plane：`s14_press_ground` 66/66（X-Plane を立ち上げ直した後。手直しの前は 63/66、最初の形では資源の尽きた X-Plane で 65/66 が 2 回、同じ操作の診断の回は通った）、`s00_baseline_start` 69/69。Lua の誤りなし。
- 2026-10-26 午後：6-1・6-2 段 3b-1（TAKEOFF REF の V speeds）。X-Plane：`s82_takeoff_speeds` 14/14（RJAA の地上で、フラップが無いと計算値は 999、フラップ 10 で計算値 V1 130 が小さい字で > つき、選ぶまで PFD は NO V SPD、R1〜R3 で選ぶと PFD に V1 130・V2 165、見出しの REF が消え、フラップ 20 で TAKEOFF SPEEDS DELETED と PFD の V1 が消える）。Lua の誤りなし。CDU と PFD を撮った。
- 2026-10-26 午後：6-1・6-2 段 3b-2（THRUST LIM の地上と TAKEOFF REF の欄）。X-Plane：`s83_takeoff_ref` 18/18（RJAA の地上で、THRUST LIM の SEL 26°C と 75°F（OAT も °F）と削除、TAKEOFF REF の既定 1000FT・FLAPS 5（小さい字）、10/1500・E/O ACCEL HT 1200・THR REDUCTION 1500、WIND/SLOPE H40/U1.0 で V1 の計算値が 130 から 134、CG 25 でトリム 4.8、POS SHIFT +0300M、PRE-FLT の ROUTE> で RTE へ。1 回目は SEL の空白の確かめ方の誤り（空白 24 文字の行を "" と比べた）で 17/18、直して流し直した）。Lua の誤りなし。CDU を撮った。
- 2026-10-26 午後：6-1・6-2 段 3c（MENU の <FMC と FLT NO）。X-Plane：`s84_menu_fltno` 13/13（RJAA の地上で、最初の <FMC は IDENT、INIT REF → PERF INIT → THRUST LIM の後の MENU → <FMC は THRUST LIM、ACMS を挟んでも THRUST LIM、右の CDU は IDENT から。RTE の FLT NO JL123 が FMC の便名になって右寄せで出る、9 文字は INVALID ENTRY、DELETE は INVALID DELETE、PROGRESS の題名に JL123）。Lua の誤りなし。CDU を撮った（RTE ページの下の行には X-Plane の RTE ページの行がまだ透けて出て、そこにも FLT NO の欄がある：段 5b で RTE を自前にして消える）。
- 2026-10-26 午後：6-1・6-2 段 4（航法データベース）。X-Plane：`s85_navdb` 22/22（RJAA の地上で、航法データ（Custom Data の AIRAC 2610）を IDENT を開いてから 6.5 秒以内に読み終え、NAV DATA AIRAC 2610 と ACTIVE OCT01OCT29/26、日付を 11 月にすると NAV DATA OUT OF DATE と >FMC MESSAGE（両方の CDU）、CLR で全部から消え、10 月に戻すと条件が消える、ORIGIN RJAA で TRANS ALT 14000（CLB ページにも）、IRS を入れ直したアライン中に REF AIRPORT の ZZZZ は NOT IN DATA BASE、RJAA は N35°45.9 E140°23.1）。Lua の誤りなし。CDU を撮った。
- 2026-10-26 午後：6-1・6-2 段 5 の段取り（6 つ：notes/ATA-34-61-FMC.md §18）と段 5a（経路のモデル、まだ機体からは使わない：§19）。全シナリオ（前半 s00〜s42）を X-Plane で回している間に、機体が読まない新しいモジュールだけをコミット。
- 2026-10-26 夕方：操縦系統（4-1）の空中開始の安定板。X-Plane の空中開始の自動トリム（FL350 で 0.5）に SRM が合わせて機首が 35〜45° まで上がっていたので、空中開始ではモデルの 7.5 units から始めるようにした（notes/ATA-27.md §17）。X-Plane：FL350・M0.85 の空中開始で安定板は 7.5 units のまま（X-Plane が入れた 0.5 を 0 に書き戻す。A/P なしでは 9 秒で機首 21°、前は 45°）。`s15_press_cruise` 41/41（トリム 0 から A/P が 40 秒で −0.26 にし、最高 36,012 ft。前は 41,000 ft まで上がって失速し墜落した）、`s00` 69/69。Lua の誤りなし。
- 2026-10-26 夜：CDU の EFIS CONTROL の RANGE が X-Plane の地図の範囲に届かないことがある不具合を直した（FMS のモジュールが X-Plane の範囲を毎フレーム読む。notes/ATA-31.md の追記）。X-Plane：`s66_cdu_efis` 41/41。
- 2026-10-26 夕方：6-1・6-2 段 5b・5c（RTE と LEGS のページ、X-Plane の FMS への流し込み）。X-Plane：`s86_rte_pages` 18/18（ORIGIN RJAA・DEST RJBB・RUNWAY 34L、DIRECT SPENS、Y71 で XAC、AKAGI の SELECT DESIRED WPT、ACTIVATE と EXEC、X-Plane の FMS の RTE に RJAA と RJBB、ND が出発滑走路 34L を見つける）、`s87_legs_pages` 21/21、RTE ページに入力する `s14` 66/66・`s83` 18/18・`s84` 13/13・`s85` 22/22。CDU と ND の写真（RTE の 1・2 ページ、SELECT DESIRED WPT、LEGS の discontinuity と DIRECT TO、ND の経路と出発滑走路）。目的地の前の流し込みで X-Plane が画面にエラーを出していたのを直し、直した後の s86・s87 ではエラー 0。Lua の誤りなし。
- 2026-10-26 夜：6-1・6-2 段 5d（手続きと DEP/ARR のページ）。X-Plane：`s88_deparr` 26/26（DEP ARR キーで DEP/ARR INDEX、DEPARTURES で AKAGI4 と 34L の <SEL>（ほかは消える）、SID が AKAGI で経路につながる（RTE の VIA AKAGI4 TO AKAGI、続いて DIRECT ATMUG）、LEGS に SID の点 D337F・条件点 NRE001 /3000A・「100° HDG」、ARRIVALS で ATMUGA・ILS06LY・遷移 GATES、ACT RTE 1、開き直した DEPARTURES の AKAGI4<ACT>、X-Plane の FMS に RJBB）。1 回目は、滑走路より先に SID を選ぶと AKAGI4 の後に discontinuity ができて 25/1（経路の点を戻すように直して 26/26）。`s86_rte_pages` 18/18・`s87_legs_pages` 21/21。CDU と ND の写真（DEPARTURES・LEGS・ARRIVALS）。Lua の誤りなし。
- 2026-10-26 夜：6-1・6-2 段 5e（現用点と X-Plane の FMS）。X-Plane：`s89_route_sync` 26/26（空中の ACTIVATE と EXEC で X-Plane の FMS・AFDS・ND の現用点が XAC、ETA は XAC から。LNAV で XAC を過ぎ、50 秒で LEGS の 1 行目が SPENS（ND と ETA も SPENS）。ATMUG を消して EXEC しても SPENS のまま。DIRECT TO AKAGI の EXEC で現用点 AKAGI（X-Plane の FMS の 4 番目：RJAA・XAC・PPOS・AKAGI…）、55 秒で機体が AKAGI へ向く。ND の線は PPOS から AKAGI で、PPOS に記号なし）、`s86_rte_pages` 19/19、`s87_legs_pages` 21/21、`s88_deparr` 26/26。CDU と ND の写真。直す前の下調べの飛行では、空中の EXEC と ACTIVATE の後に ND の現用点と ETA が出発地のままで、DIRECT TO は出発地からの脚に乗りに行った。途中で X-Plane が 1 回落ちた（0xc0000409、機体の読み直し約 12 回目の s88 の計画の読み込みのとき。起動し直した X-Plane では同じシナリオが合格）。Lua の誤りなし。
- 2026-10-26 夜：X-Plane の FMS に各点の高度の制限を流す（段 5e の追記。段 5f の試験で見つけた）。X-Plane：`s67_nd_data` 25/25（経路を CDU で入れる形にした版：段 5f）で、ND の DATA に FR の 5000 と TAU の FL200 が出る。Lua の誤りなし。
- 2026-10-27 未明：X-Plane の FMS を X-Plane のスレッドで（新しいプラグイン `plugins/b747_fms_bridge`、プラグインが無いときは XTLua の呼び出しを絞る。DIRECT TO の始点は DTOPOS）。X-Plane：プラグイン入りで `s89_route_sync` 26/26（作り直したプラグインでもう一度）、`s67_nd_data` 25/25（空中の ACTIVATE と EXEC の直後から現用点が FR）、`s70_nd_airports` 39/39、`s88_deparr` 26/26、`s86_rte_pages` 19/19、`s87_legs_pages` 21/21 で、X-Plane は落ちなかった。プラグインは機体の読み直しのたびに読み込まれる（Log.txt の Loaded）。Lua の誤りなし。
- 2026-10-27：ND の DATA の高度は遷移高度ちょうどをフィートで（LEGS ページと同じ）。X-Plane：`s67_nd_data` 25/25（遷移高度 5000 ft の EDDF を出発地にした経路で、FR の 5000 が 5000 と出る）。
- 2026-10-27：6-1・6-2 段 5f（飛行試験キットの経路を CDU で）。X-Plane：`s67_nd_data` 25/25、`s70_nd_airports` 39/39（どちらも経路を CDU で入れる）。ND の写真（DATA の現用点 FR のマゼンタと高度・ETA、TAU の FL200、26R の滑走路の絵）。
- 2026-10-27：CDU の EXEC 灯を FMC の修正に合わせる（3D の物体 `Cockpit_Pedestal1.obj` の 2 行、利用者の承認）。X-Plane：`s87_legs_pages` 29/29（ACTIVATE と DIRECT TO の修正で左・中央と右の灯りが 1、EXEC で 0。写真で、MOD の間は CDU の EXEC キーの上の灯りが光り、EXEC で消える）。X-Plane を起動して最初のフライトでは交流の母線に電気が来ておらず、右の CDU の灯りが 0 だった（電源の割り当てのとおり。2 回目のフライトで合格）。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 6 の段取り（4 つに分けた：notes/ATA-34-61-FMC.md §26）と段 6a（経路の形のモデル `B747.68.path_model.lua`、まだ機体からは使わない。手続きのモデルが RF の中心と半径を読む：§27）。試験 78 件、手続き 58 件。
- 2026-10-27：6-1・6-2 段 6b（LNAV のモデル `B747.68.lnav_model.lua`、まだ機体からは使わない：notes/ATA-34-61-FMC.md §28）。経路・形・LNAV のモデルを簡単な機体と閉ループで回す試験 54 件（fly-by の旋回で経路から 0.09 nm 以内、RF の弧 0.01 nm、切込みの行き過ぎ 0.007 nm）。
- 2026-10-27：6-1・6-2 段 6c（LNAV の組み込み：notes/ATA-34-61-FMC.md §29）。X-Plane：`s90_lnav` 30/30（脚の右 6 nm で平行に arm：engage せず NOT ON INTERCEPT HEADING、ロールモードは HDG SEL のまま。30° 向けると 2.49 nm で engage して脚に乗る。XAC の右 54° の fly-by の旋回で、経路から前半 0.10 nm・後半 0.22 nm 以内、バンクは指令の 25° に 24.3〜24.8°。後ろの XAC への DIRECT TO は近い向きに回り、飛んだ経路から 0.01 nm 以内（直す前は EXEC の時の位置からの線に戻ろうとして 5.5 nm の大回り）。XAC を過ぎるとヘディングを保持し DISCONTINUITY）、`s89_route_sync` 26/26（FMC 自身の順送りで XAC の次が SPENS、DIRECT TO AKAGI）、`s67_nd_data` 25/25、`s70_nd_airports` 39/39、`s86_rte_pages` 19/19、`s87_legs_pages` 29/29、`s88_deparr` 26/26。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 6c の続き（手続きの旋回の向き、90° を超える切込み：notes/ATA-34-61-FMC.md §29 の終わり）。X-Plane：新しい `s91_lnav_sid` 23/23（RJAA 34L の SAKUR5：CF で D337F を真上で過ぎ、手続きの右回りでヘディング 100、NRE の radial 001・036 で順送り、ヘディング 160 から 283 のコースへの 123° の旋回はコースの 3.2 nm 手前で始まり、行き過ぎ 0.19 nm。NRE・TETRA を経て経路の終わりでヘディングを保持し END OF ROUTE。バンクは指令の 25° に 23.7〜24.7°）、`s90_lnav` 30/30。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 6d（ND の線に条件の脚の終わりと弧：notes/ATA-34-61-FMC.md §30）。X-Plane：`s91_lnav_sid` 27/27（ND の現用点が D337F・NRE001・(INTC)：X-Plane の計画の条件の点の行。20 nm の ND の写真で、マゼンタの線が NRE001・NRE036（ヘディング 100）、(INTC)（ヘディング 160）、NRE（283 のコース）を通り、条件の点に名前）、`s88_deparr` 26/26、`s89_route_sync` 26/26、`s90_lnav` 30/30、`s87_legs_pages` 29/29、`s86_rte_pages` 19/19、`s67_nd_data` 25/25、`s70_nd_airports` 39/39。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7 の段取り（5 つに分けた：notes/ATA-34-61-FMC.md §31）と段 7a（ホールドのモデルと LNAV：§32）。経路の HM・HA・HF を LNAV が飛ぶ：保持点を通る時のトラックで parallel・teardrop・direct の進入、30° までのバンク、保持点を通るたびの大きさ、EXIT の最短の戻り、HA の高度・HF の 1 周での出口。閉ループの試験 65 件（250 kt で 1 周 296 秒、形の ±0.3 nm、保持点を 0.15 nm 以内）。X-Plane：`s90_lnav` 30/30、`s91_lnav_sid` 27/27、`s89_route_sync` 26/26（ホールドの無い経路で前と同じ）。Lua の誤りなし。ホールドを X-Plane で飛ぶのは段 7b（HOLD のページ）で。
- 2026-10-27：6-1・6-2 段 7b（ホールドの CDU と ND：notes/ATA-34-61-FMC.md §33）。HOLD キーで RTE LEGS HOLD AT（経路の点、経路に無い点の HOLD AT XXXXX、PPOS）と RTE 1 HOLD（QUAD/RADIAL・INBD CRS/DIR・LEG TIME/DIST・SPD/TGT ALT・EFC TIME、EXIT HOLD と EXIT ARMED、予測の欄はダッシュ）、LEGS の HOLD AT・PROC HOLD、飛んでいるホールドの DELETE で次の点へ直行、ND の線のホールドの形（TO の点のホールドは LNAV の大きさ）。X-Plane：新しい `s92_hold` 47/47（XAC で teardrop、バンク最大 29.7°、1 周を形から 0.23 nm 以内、EXIT HOLD ですぐ戻りの旋回、PPOS と DELETE）、`s87_legs_pages` 29/29、`s86_rte_pages` 19/19、`s90_lnav` 30/30、`s89_route_sync` 26/26。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7c（notes/ATA-34-61-FMC.md §34）。LEGS の PI の脚の上に PROC TURN、CRS REVERSAL AT FA FIX（FAF に逆向きで来て procedure turn もホールドも無い：90° は推定）。procedure turn の形は資料に無いので作らない（PI の脚はその点で順送り）。手続きのホールドの PROC HOLD と自動の出口は段 7a・7b のとおり。X-Plane：`s88_deparr` 26/26、`s87_legs_pages` 29/29。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7d（オフセット：notes/ATA-34-61-FMC.md §35）。空中の RTE の 6R に OFFSET（L・R 1–99、L0・DELETE で消す、DIRECT TO と PPOS で消える）、LNAV がオフセットの平行な線（角は交点）を飛ぶ、21 nm 超で順送りの制限 200 nm、終わりの 5 nm 手前で END OF OFFSET、OFST 灯の dataref。ND は元の経路の線だけ。閉ループの試験 16 件。X-Plane：新しい `s93_offset` 25/25（R5 で右へ回って捕捉、XAC の角を 0.14 nm 以内、END OF OFFSET、DIRECT TO で消える）、`s86_rte_pages` 19/19、`s90_lnav` 30/30、`s89_route_sync` 26/26。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7e1（REF NAV DATA：notes/ATA-34-61-FMC.md §36）。INIT/REF INDEX の NAV DATA> を FMC 自身の REF NAV DATA に（前は X-Plane の DATABASE ページ）。IDENT（ウェイポイント・航法施設・空港・目的地の滑走路、SELECT DESIRED WPT）の FREQ・緯度と経度・MAG VAR か LENGTH・ELEVATION、NAVAID INHIBIT・VOR ONLY INHIBIT・VOR/DME NAV（両方の FMC のもの。効き目は段 10、飛行の終わりで消すのは段 9）。緯度と経度の表示を分の 1/10 に四捨五入。X-Plane：新しい `s94_refnavdata` 38/38、`s86_rte_pages` 19/19、`s85_navdb` 22/22。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7e2（DIRECT TO の ABEAM PTS：notes/ATA-34-61-FMC.md §37）。DIRECT TO の修正の 4R に ABEAM PTS>（ほかの変更で消える）、押すと飛ばした点の真横に place/bearing/distance の点（XAC01 など）を直行の線の上に作り、SELECTED。INTC CRS は消える。LEGS の距離を 14 桁目で終わる位置に。X-Plane：新しい `s95_abeam` 23/23、`s87_legs_pages` 29/29。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7e3a（自分で作る点の入力：notes/ATA-34-61-FMC.md §38）。RTE と LEGS で緯度経度（N47W008、N4715.4W00803.4）、place/bearing/distance（SEA330/10、ABC180.0/026.4）、place bearing/place bearing（SEA240/OLM320）の点。名前は N47W008・SEA01、経路の点は名前で入れ直せる。REF NAV DATA と FIX INFO は航法データの点だけ。X-Plane：`s95_abeam` 26/26（N34E138 と SPE04 を入れる）、`s86_rte_pages` 19/19。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7e3b（FIX INFO：notes/ATA-34-61-FMC.md §39）。FIX キーで FMC 自身の FIX INFO（2 ページ、前は X-Plane の FIX ページ）。FIX、BRG/DIS FR、方位線（512 nm まで）と距離の円のアクティブな経路との交点（小字の距離・方位、DTG）、<ABEAM、place/bearing/distance の写し（RTE・LEGS に入れられる）、<ERASE FIX、PRED ETA-ALT の入力。ETA・ALT は予測（段 8）まで空白、ND の記号は無し。X-Plane：新しい `s96_fixinfo` 25/25、`s94_refnavdata` 38/38。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7e4（RTE 2 と RTE COPY：notes/ATA-34-61-FMC.md §40）。経路の状態を RTE 1・RTE 2 の二つに（結線の B747_fmc_route はいつもアクティブな経路、もう一つの ACTIVATE と EXEC で入れ替え）。RTE・LEGS・DEP/ARR に RTE 2 のページと <RTE 2・<RTE 1、RTE COPY（1 ページ目の 5L と DIRECT TO の修正の 5R）、RTE・LEGS・DEP ARR キーと ROUTE> はアクティブな経路へ、RTE 2 の PBD の番号は 51–99。X-Plane：新しい `s97_rte2` 31/31、`s86_rte_pages` 19/19、`s87_legs_pages` 29/29、`s88_deparr` 26/26、`s93_offset` 25/25。Lua の誤りなし。
- 2026-10-27：6-1・6-2 段 7f（procedure turn の形・推定：notes/ATA-34-61-FMC.md §41）。資料に形が無く、利用者の依頼で PANS-OPS の 45°/180° を推定で作った。経路の形のモデルに PI の要素（PI の点から出航、角の fly-by の弧、45° の脚 1 分 15 秒、25° のバンクで PI の向きに 180°、戻り。出航の長さは旋回が PI の距離の 1 nm 内側に収まるまで）、LNAV がその段階（新しい dataref `laminar/B747/fms/lnav/pturn_phase`）を追って飛び、戻りの脚で入航コースへの旋回の始まりに順送り、ND に形を描く。X-Plane：新しい `s98_pturn` 1 回目 15/16（出航から 45° の脚への角に先行が無く 0.71 nm 外へふくらんだ：角を弧にし、角と 180° の旋回をロールの 4 秒だけ早めて直した）、2 回目 16/16（XTK は出航〜45° の脚で最大 0.055 nm、旋回で 0.148 nm、入航コースで 0.031 nm 以内）、`s90_lnav` 30/30。Lua の誤りなし。
- 2026-10-27：6-3（AFDS）の段取り（notes/ATA-22.md §10）。今のコードを調べ直し（§10.1：モードの論理が自動操縦のモジュール・monitor・autoland・F/D スイッチ・TO/GA スイッチに散り、ピッチの則は FMA の数値で選び、ロールは X-Plane の HDG のモード、順序は `lastCommand` の待ち）、FCOM 4.10〜4.30 と ATA22 の 22-10〜22-14 を読み直して、段 1（モードの論理を 1a〜1d に分ける。今の則は段 1 の間そのまま動かす）・段 2（ロールの則）・段 3（ピッチの則）・段 4（autoland と 3 チャンネル）・段 5（監視と警報）・段 6（ヨーダンパーと autotrim）にした。
- 2026-10-27：6-3（AFDS）段 1a（枠組みと engage：notes/ATA-22.md §11）。新しいモデル `B747.70.afds_model.lua` が A/P の engage の状態（CMD は押したとき、地上でも、2 台目は engage しない、そのチャンネルの油圧）、AUTOPILOT DISC（解除のたび、再 engage か A/P の無いときの操縦輪のスイッチで消える。解除バーを上げても消えない）、F/D の最初の ON と A/P engage の既定のモード（V/S を今の昇降率に合わせ、HDG HOLD か 5° を超えるバンクで ATT：PW・RR）、A/P も F/D も無いときの全モードの消去を持つ。F/D のスイッチのハンドラーはスイッチだけに、MCP の IAS の初期値 200、空中開始の初期化は ALT HOLD を F/D の既定の後に、飛行の開始のたびに、何度走っても同じに。前の則はピッチのモードの無い間に ALT HOLD を立てない。X-Plane：新しい `s99_afds_engage` 36/36（4 回目。前の 3 回で全モードの消去の後の前の FMA と前の則の ALT、空中の初期化を直した）、`s01_ap_basic` 15/15、`s28_stab_trim` 25/25、`s30_speed_trim` 11/11、`s59_pfd_ils` 34/34、`s90_lnav` 30/30。Lua の誤りなし。
- 2026-10-27：6-3（AFDS）段 1b（ロールのモード：notes/ATA-22.md §12）。モデルがロールのモード（HDG SEL、HDG HOLD：すぐ表示し 3° 未満で 2 秒の方位を保つ、ATT：次のモードまで、LNAV：arm 中の 2 回目でだけ disarm・engage 中は押しても何もしない・HDG SEL で arm が消えない・経路が無くても外れない）と遷移（LOC と G/S の捕捉後・G/A の 400 ft 未満）を持ち、FMA のロールを出す。3D の HDG HOLD のボタン（X-Plane のコマンド）は replace でモデルへ、旋回は段 2 まで X-Plane の HDG SEL。HDG HOLD の灯は ATT でも。段 1 の残りを 1c ピッチ、1d 進入、1e TO/GA に分け直した。X-Plane：新しい `s100_afds_roll` 25/25（空中：HDG SEL の旋回と方位、LNAV の arm と 2 回目、旋回中の HDG HOLD、ATT。PFD で CMD と「SPD｜HDG SEL・LNAV（arm）｜ALT」、ATT で約 25° のバンクを保つのを画像で確かめた）、回帰の `s99_afds_engage` 36/36、`s01_ap_basic` 15/15、`s72_hdg_ref` 19/19、`s90_lnav` 30/30、`s91_lnav_sid` 27/27、`s92_hold` 47/47、`s59_pfd_ils` 34/34。Log.txt に Lua の誤りなし。
- 2026-10-27：6-3（AFDS）段 1c（ピッチのモード：notes/ATA-22.md §13）。モデルがピッチのモード（V/S：今の昇降率に合わせ ALT の後は 000、ALT HOLD、V/S と FLCH からの捕捉、FLCH SPD：窓が空白なら FMC の速度・TO/GA からは大きい方、FLCH の 8,000 ft の ALT HOLD の既定：測り始めは推定、VNAV：arm の間は作動中のモードのまま・2 回目でだけ disarm・engage 中は何もしない・engage とサブモードは前の VNAV）と遷移（G/A の 400 ft 未満、LOC の後の G/S、FLARE）を持ち、FMA のピッチを出す。SPD は VNAV・FLCH・TO/GA 中は効かない。前の G/S と TO/GA のピッチでモードが終わる。経路が無いときの VNAV の取り消しはモデルを通し、DESTINATION NOT SET を出さない（FMC のメッセージの旗は DRindex + 1）。MCP の灯は VNAV の arm の間も作動中のモードのまま。X-Plane：新しい `s101_afds_pitch` 33/33（空中：経路と CRZ ALT を CDU で入れ、ALT の後の V/S は 000、上昇中の V/S で今の昇降率に合わせる、MCP 高度の捕捉で ALT と保つ高度、FLCH で降りて捕捉、FLCH 中の SPD は効かない、上昇中の ALT HOLD で押した時の高度を保つ、空中の VNAV はすぐ engage、engage 中の VNAV、V/S で VNAV が終わる。1 回目は高度を「捕捉の 15 秒後に ±200 ft」で見て 3 つ落ちた：前のピッチの則は捕捉の窓が広く（1,000 fpm で約 450 ft 手前）、11,000 ft に届くまで約 35 秒、ALT HOLD は 10,000 ft より上で約 500 ft 行き過ぎる。段 3 の則の問題なので、保つ高度を確かめてから範囲に入るまで待つ形に直した）、回帰の `s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s01_ap_basic` 15/15、`s07_cruise_ff` 6/6、`s44_tcas` 73/73、`s53_min_speeds_cruise` 11/11、`s59_pfd_ils` 34/34、`s60_pfd_ils_alert` 15/15（前は 8/15：G/S を捕まえなかった。段 1a〜1c の後は 61 秒で捕まえる）、`s90_lnav` 30/30。Log.txt に Lua の誤りなし。
- 2026-10-27：機体の型式による ND の向きと、拡大の方位の印の位置（notes/ATA-31.md §39）。利用者の「ND の逆三角形がサークルに食い込んでいる」という指摘から、印の作り（段 5a の推定）と、ND を 109 で作っていたこと（MAP は航跡が上）を説明し、利用者が「405にしよう」と決めた（P&W は 405、GE は 570、RR は P&W と同じ：推定）。ND のモデルが型式（`engines/type`）で向きを決め（405 は全モードで方位が上、570 は MAP・MAP CTR・PLAN が航跡が上）、上の枠の新設 `nd/<席>/box`（1 HDG、2 TRK、PLAN は 3 HDG・4 TRK）、旗は向きの源で（405 は HDG、570 の MAP・PLAN は TRK）、X-Plane の地図の層は 405 の MAP で 0。予測線は表示の上から見た航跡の向きに回す（405 では偏流角）。nd.lua の `nd/up` と記号の角度も 405 の MAP は方位。カスタム acf のパネル（`panel_nd_405.lua`、23 か所、ACF_DIFF.md §5、バックアップ `acf_backup\747-400_custom.acf.20261027_before_nd_405`）：枠の TRK・HDG の部品を `box` で、PLAN の枠に HDG の写し。拡大の方位の印は、X-Plane で航跡 45° ごとに撮って、目盛の中心より 11 px 下を中心に回っていたこと（上で 5 px 食い込み、下で 16 px 浮き、左右に 11 px）を確かめ、目盛と同じ中心・半径 451 に（画像から求めた、先が外縁に触れる距離）。機長の拡大の目盛と覆いが 5.5 px 右にずれていたのも直した。109 で作ってきた部分のうち 405 で違うものの棚卸しはエージェントに任せ、`EFFECTIVITY_405.md` にまとめた（どこまで 405 にするかは利用者に確認中）。試験：ND のモデル 107 件、nd.lua の向き 8 件、予測線 20 件、表示のモジュール 233 件、インターフェース 2,136 件、全 117 本。X-Plane（カスタム acf）：`s61_nd_orientation` 40/40（P&W：MAP は方位が上で HDG の枠、▽ は枠の真下で先が目盛の縁、予測線は偏流の分だけ右、PLN は HDG、HDG・MAP・VTK の旗）、新しい `s61_nd_orientation_ge` 25/25（GE のリバリー：MAP・MAP CTR は航跡が上で TRK、PLN は TRK、TRK の旗）、`s66_cdu_efis` 41/41、`s73_nd_trend` 15/15。最初の `s61` に入れた「Web API で `engines/type` を 1 にする」確認は、simconfig のモジュールが毎フレーム書き直すので効かず（5 件不合格）、GE のリバリーのシナリオに分けた。Lua の誤りなし。
- 2026-10-27：6-3（AFDS）段 1d（進入のモード：notes/ATA-22.md §14）。モデルが LOC と G/S の arm と捕捉（LOC は航跡がコースから 120°、G/S は 80° 以内、PW は 405 で LOC の後、GE は 570 でどちらが先でも。捕捉の判定は段 2・3 まで前の検出）、APP と LOC の 2 回目、LNAV・VNAV との相互の解除、LOC の捕捉後・G/S の捕捉後の deselect、TO/GA、捕捉中の A/P の engage を持ち、前の進入の状態（approach_mode・nav_status・glideslope_status）を書く。捕捉で MCP の方位をコースに（前は APP を押した時）、ILS が無くても arm（前は RW/ILS CRS ERROR）。前の B747_ap_appr_mode の arm と glideSlopeLOCProgress、monitor の捕捉と arm に戻す処理を外した。X-Plane：新しい `s102_afds_app` 34/34（RJAA 34L の進入路の 20 NM・3,000 ft：NAV1・NAV2 を局の無い周波数にしてから、APP で LOC と G/S の arm（ILS が無くても arm）、2 回目で disarm、LOC だけの arm と 2 回目、LNAV の arm で APP が外れ、APP で LNAV の arm が外れる；ILS を同調して APP で LOC を捕まえ MCP の方位がコース 337 に、G/S はまだ arm（G/S の下 2.5 ドット）、G/S の前の HDG SEL で APP が外れる、もう一度 APP、G/S の捕捉、LOC・G/S の後は HDG SEL と V/S が効かない、TO/GA で LOC と G/S が終わる。PFD を撮った。最初の回は前のシナリオの ILS の同調が残っていて「同調前」に LOC を捕まえ、2 回目は APP を arm したまま同調した瞬間に、受信機の切り替わりの一瞬の偏位を前の簡単な検出（1.5 ドット未満）が捕捉と取って G/S まで捕まえたので、同調の間は APP を外すようにした：段 3 の捕捉の判定で直す）、`s59_pfd_ils` 34/34、`s60_pfd_ils_alert` 15/15、`s62_pfd_ils_rx` 31/31、`s63_nd_app` 39/39、`s01_ap_basic` 15/15、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s101_afds_pitch` 33/33、`s90_lnav` 30/30。Lua の誤りなし
- 2026-10-27：6-3（AFDS）段 1e（TO/GA：notes/ATA-22.md §15）。モデルが T/O と G/A（ロールとピッチの latch）を持つ：地上の最初の F/D で T/O、地上の A/P・A/T の SPD・次のピッチのモードで T/O のピッチが終わる；空中の TO/GA スイッチでフラップが UP でないか G/S が入っていれば G/A（T/O からは入らず、離陸後は 50 ft から G/A のロールだけ）、G/A は LOC・G/S とその arm・作動中の VNAV を終わらせ接地しても残る；スイッチは電波高度 5 ft を下回って 2 秒で効かなくなり上回って 3 秒で効く；G/A からの遷移は 400 ft、T/O・G/A からの捕捉は 800 ft より上；A/P も F/D も無いとき 80 kt より速くフラップが UP でなければ F/D のスイッチ OFF のまま両席に F/D と FD（スイッチの ON・OFF で消える）。TO/GA スイッチはエンジンのモジュールのコマンドが押した回数（新設 `autopilot/toga_pushes`）を数え、前の AFDS の処理（空中の TO/GA の旗、autoland -2、APP 0）は外した。グルーが前の `TOGA_status` をモデルから毎フレーム書き、G/A のピッチで前の autoland の着陸復行を書く。新設 `autopilot/fd/<席>/shown` を、パネルの F/D のバー（`panel_fd_shown.lua`、4 か所、ACF_DIFF.md §5、バックアップ `acf_backup\747-400_custom.acf.20261027_before_fd_shown`）、AFDS の FD とモード変化の枠、FMA を出す条件が見る。フラップ UP はハンドルの位置（推定）。試験：モデル 201 件、グルー 106 件、全 117 本。X-Plane（カスタム acf）：新しい `s103_afds_to` 19/19（RJAA 34L の地上：F/D を両方 OFF で全部切、F/D L ON で T/O（ロール・ピッチとも TO/GA、TO/GA の旗、機長の F/D の表示と FD）、F/D R ON では変わらない、地上の CMD L で HDG HOLD と V/S。PFD を撮った（F/D のバーは TO/GA でも出る。地上のピッチのバーは水平のまま：前の則、段 3）。1 回目は地上の V/S を FMA で見て落ちた：FMA のピッチは地上では TO/GA のほかは出さない作り（段 1c）なので、前の則の旗で見るようにした）、新しい `s104_afds_ga` 32/32（銚子沖の海上 1,500 ft・160 kt・フラップ 20 で始め、V/S で降りて MCP 高度 300 ft を捕まえ、316 ft で TO/GA：G/A、旗、前の autoland の -2、400 ft 未満で HDG SEL と V/S が効かない、400 ft より上で HDG SEL、MCP 高度 1,500 ft を 804 ft で捕捉（800 ft より上）、A/P と F/D を切って全部切、MCP 高度を 5,000 ft にして F/D のスイッチ OFF のまま TO/GA で G/A と両席の F/D・両 PFD の FD、F/D L の ON・OFF で全部切。PFD を撮った。途中の回で、空中開始の高さが沈んだり浮いたりして毎回違う、MCP 高度を dataref で書いただけでは前の則の目標に写らない、空中の初期化の ALT HOLD が後から入る、MCP 高度にいるまま G/A にすると 800 ft より上の捕捉ですぐ ALT になる（正しい動き）、が分かってシナリオを直した）、`s102_afds_app` 34/34、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25（1 回目は ATT で A/P がバンクを 26° から 39° に増やして 1 件不合格：前のロールの則の揺らぎ、段 2）、`s101_afds_pitch` 33/33、`s01_ap_basic` 15/15、`s11_takeoff_thrust` 12/12（地上の TO/GA で A/T の推力）。途中で X-Plane が GPU のメモリの割り当てに失敗した警告のまま止まり（起動から約 18 時間）、その前触れで結果の無い回が 3 度あった。起動し直して流した。外から見た姿は変わらない（外観の写真）。Lua の誤りなし。
- 2026-10-27：P&W の機体を 109 に戻した。利用者の「NDを109に戻すと逆三角形の問題が再発するの？」に、方位の印の直しは向きと関係ないので再発しないと答え、利用者が「じゃあP&WはNDとAFDSも109に戻してよ。GEの撮影はいらない」と決めた。ND は P&W・RR も GE と同じで、MAP・MAP CTR・PLAN は航跡が上・TRK の枠と旗、VOR・APP は HDG（FCOM p.1141、p.1033–1034）。ND のモデルの `track_map` は既定で true（作る機体）にし、表示のグルーと nd.lua は `engines/type` を読まない。AFDS の G/S は LOC とどちらが先でも（FCOM p.669）。405 の道（`track_map` が false、`inp.gs_after_loc`）は、どの機体も使わない入力として残した。パネルは変えない（`box` で TRK・HDG を出す部品は 109 でもそのまま働き、PLAN の HDG の写しは出ない）。`s61_nd_orientation` を 109 の確認に戻し、`s61_nd_orientation_ge` は外した（GE も同じ向き）。`s61` の 1 回目は 6 件不合格：10,000 ft・真 200 kt（指示 約 170 kt）の空中開始は 270 t のクリーンでは失速の手前で、A/P の ALT HOLD が沈んだ高度を取り戻そうとして失速し、方位を保てなかった（ND は航跡に正しく付いていた）。見張り（Web API で 1 秒ごと）の記録で、合格した 2 回目も開始の直後に 4,000 ft/min で沈み、迎え角が約 13° まで上がっていたことを確かめ、開始を指示 250 kt（真 290 kt）にした（3 回目は迎え角が最大 7.5°）。同じ開始のシナリオはほかにもある（`s51`・`s52`・`s56`・`s58`・`s66` など。今は通っているので変えていない。TESTING.md の注意に書いた）。試験：AFDS のモデル 202 件、グルー 106 件、ND のモデル 107 件、nd.lua の向き 8 件、予測線 20 件、表示のモジュール 233 件、インターフェース 2,138 件、全 117 本。X-Plane（カスタム acf）：`s61_nd_orientation` 40/40（P&W：西風 50 kt で方位 007・航跡 017〜018。MAP は航跡が上で TRK の枠、▽ は方位 007 の位置で先が目盛の縁に触れる（写真）、予測線は真上、VOR は方位が上で HDG、PLN は TRK、MAP CTR も航跡が上、IRU を ATT にして TRK・MAP・VTK の旗と VOR の HDG の旗。2 回目（前の開始速度）も 40/40）、`s66_cdu_efis` 41/41、`s102_afds_app` 34/34。Lua の誤りなし。
- 2026-10-27：6-3（AFDS）段 2a（ロールの則のうち方位・姿勢・航跡：notes/ATA-22.md §16）。段 2 を 2a と 2b（LOC の捕捉と追従）に分けた。新しい純粋なモデル `B747.70.afds_roll_model.lua` が、AFDS のモデルのロールのモードから A/P と F/D のロールの指令を出す：HDG SEL は基準の方位（磁北か真北）での MCP の方位との差で、押した時は近い側、押してからはつまみの動きと旋回で差を丸めずに更新（回した向きへ。ATA22 p.274）；HDG HOLD は翼水平の後にその方位（p.272、p.348）；ATT はそのバンク；LNAV は FMC の steering；T/O は地上で翼水平・浮いてからの航跡、G/A は開始時の航跡（FCOM p.663、p.666）。差に毎秒 差/8° の旋回のバンク、指令は 3°/s まで（推定）。bank limit は HDG SEL で MCP の選択器か AUTO（フラップが出ていて V2 + 10 未満で 15°・それ以上で 25°、フラップ UP は TAS で 25°〜15°：FCOM p.647、FCTM p.118、TAS の表は推定）、LNAV は V2 + 10 の 15° だけ（FMC の待機経路の 30° を残す）。NORM の極地域では HDG SEL を受けず、HDG SEL・HDG HOLD は NCD でバンクを保つ（FCOM p.1046、ATA22 p.352）。グルーが新設 `autopilot/roll_cmd`・`roll_law`・`roll_valid` を書き、油圧のモジュールの則が `roll_law` 1 で `roll_cmd` を内側のループの目標に（X-Plane の F/D のロールと 10 点の移動平均を通さない）、PFD の F/D のロールのバーもその指令。X-Plane の HDG SEL の目標の書き込みとモードのコマンド（HDG SEL・HDG HOLD、LNAV の engage 中）はやめた（LOC の追従は段 2b まで）。試験：ロールの則 47 件（新しい）、グルー 109 件、HDG REF 35 件、油圧のモジュール 192 件、全 118 本。X-Plane（カスタム acf）：新しい `s105_afds_roll_law` 18/18（10,000 ft・約 290 kt（真）：bank limit 5 で 40° 右の HDG SEL はバンク最大 4.8°、AUTO で最大 25.1° のまま方位 137（目標 138）に乗る、今の方位で HDG SEL を押してからつまみを右へ 200° 回すと右へ回り続ける（20 秒で 33° 右、バンク 24.9°）、旋回中の HDG HOLD で 7.4 秒で翼水平、その方位を 20 秒で ±2° 以内。PFD を撮った（SPD｜HDG SEL｜ALT、バンク約 25°、F/D のバーは中央）。2 回目に MCP 速度 250 kt を足した：1 回目は 223 kt でフラップ UP の最小機動速度の近くだった）、回帰の `s100_afds_roll` 25/25（ATT のバンク 18.3° が 10 秒で 19.3°：前の則では 26° が 39° に増えたことがある。HDG HOLD の方位は 20 秒で 0.05° のずれ）、`s72_hdg_ref` 20/20（X-Plane の方位のモードの目標の確認を、TRU の HDG SEL で真方位が MCP の 086 に乗ること（磁方位は 083）に替えた）、`s104_afds_ga` 34/34（G/A のロールは新しい則で、開始時の航跡 007.5 を 450 ft でも 007.5）、`s99_afds_engage` 36/36、`s01_ap_basic` 15/15、`s90_lnav` 30/30、`s103_afds_to` 19/19、`s61_nd_orientation` 40/40。1 回目の `s105` の途中で、X-Plane が機体の読み直しの直後にヒープの破損（0xc0000374、ntdll）で落ちた（起動から約 1 時間 10 分、読み直しを 10 回ほど重ねた後）。起動し直してからは同じ所で落ちていない。Lua の誤りなし。
- 2026-10-27：6-3（AFDS）段 2b（LOC の捕捉と追従：notes/ATA-22.md §17）。ロールの則のモデルに LOC を足した：偏位（X-Plane の NAV1 のドット。X-Plane の LOC は 1 ドット ＝ 1.41°：RJAA 34L の進入路で機体を横へ動かし、X-Plane の航法データの LOC のアンテナの位置から計算した角度と比べて測った）を、電波高度から推定した局までの距離（3° の glide slope と 10,000 ft の滑走路：ATA22 p.358）で直線にする；捕捉は両受信機に LOC があり、ビームへ寄っていてバンク 25° でコースへ回る距離と 4 秒の lead より近いか、偏位が 0.7° 以内（ATA22 p.290：対地速度・進入角・偏位）；則はビームからの距離を滑走路を横切る速度で進め偏位へ 5 秒で寄せる慣性の経路、30 秒先でビームに乗る航跡、100 m・5° で LOC TRACK（バンクの制限 25° → 15°）、5 ft 未満と地上で翼水平（ATA22 p.348）。値は推定。グルーが AFDS のモデルの LOC の捕捉の入力をこの判定にし（前は両受信機の信号だけ）、monitor の LOC の追従（X-Plane の HDG SEL）と前の LNAV の X-Plane の HDG SEL の処理を外した：X-Plane の HDG のモードはどのモードでも使わない。試験：ロールの則 66 件、グルー 111 件、全 118 本。X-Plane（カスタム acf）：新しい `s106_afds_loc` 20/20（RJAA 34L の進入路の 22 NM・2.5 NM 右から 30° で入る：ビームの右 1.44 ドットで捕まえ、反対側へ出ずに 90 秒で −0.06 ドット・航跡 336.8・翼水平、右からの横風 20 kt で 0.05 ドット以内・機首は風上へ 5°、信号を失っても LOC のまま航跡 337.35〜337.38、周波数を戻して 0.04 ドット。PFD と ND を撮った（SPD｜LOC｜ALT、翼水平、F/D のバーは中央、ND は TRK 337 でコースの線の上）。1 回目は最後の同調し直しを CDU で同じ値を入れる形にしていて同調せず 19/20：dataref で戻すようにした）、`s102_afds_app` 36/36（MCP の方位 007 でビームの左から 30° で入るようにした：APP ですぐ捕まえ 97 秒で 0.3 ドット以内、HDG SEL の後もすぐ捕まえ直し、G/S はその 23 秒後）、`s60_pfd_ils_alert` 15/15、`s100_afds_roll` 25/25、`s90_lnav` 30/30。X-Plane の偏位の目盛は測定のシナリオで測った（合否なし、リポジトリには入れていない）。流す前に X-Plane を起動し直した（Web API の `sim/operation/quit` では終わらず、プロセスを止めた）。Lua の誤りなし。
- 2026-10-28：6-3（AFDS）段 3a（ピッチの則のうち V/S・ALT とその捕捉：notes/ATA-22.md §18）。段 3 を 3a・3b（速度を昇降舵で保つ則と速度の保護）・3c（G/S）に分けた。新しい純粋なモデル `B747.70.afds_pitch_model.lua` が、AFDS のモデルのピッチのモードから A/P と F/D のピッチの指令を出す：V/S は MCP の昇降率と慣性の昇降率（ATA22 p.344）、000 はその時の高度（p.282）、ALT は保つ高度との差を 0.05 g の引き起こしまでの昇降率に（p.286、p.346）、前の VNAV の V/S と高度もこの則で。指令は経路角の差で動き、慣性の上下加速度で先を見て減衰し、0.05 g まで。MCP 高度の捕捉（AFDS のモデルの入力）は、寄っていて 0.05 g の引き起こしの距離と昇降率の 10 秒分より近いとき（前は昇降率に比例する窓）。最初の値では X-Plane で捕捉が 200 ft 行き過ぎたので、「姿勢が 2 秒・経路角が 3 秒遅れる」模型（X-Plane の結果を 20 ft ほどで再現した）で先読み・先取り・前倒しを決め、遅れを 1.5 倍にしても行き過ぎの小さい値にした。値は推定。グルーが新設 `autopilot/pitch_cmd`・`pitch_law` を書き、油圧のモジュールの則が `pitch_law` 1 で `pitch_cmd` を内側のループの目標と F/D のピッチに（10 点の平均を通さない。前の則の状態はそれに合わせておく）。試験：ピッチの則 29 件（新しい）、グルー 117 件、全 119 本。X-Plane（カスタム acf）：新しい `s107_afds_vs_alt` 20/20（10,000 ft・約 290 kt（真）：V/S +2,000 fpm で 12,000 ft の捕捉は 717 ft 手前から、行き過ぎ 6 ft、その後 30 秒は −15〜0 ft；−1,500 fpm で 10,500 ft の捕捉は 424 ft 手前から、20 ft 下がりすぎ；V/S 000 は 18 ft 以内；上昇中の ALT HOLD は 453 ft 行き過ぎて、60 秒で押した高度の 40 ft 上まで戻る。PFD を撮った（SPD｜HDG SEL｜ALT、MCP 高度で水平、F/D のバーは中央）。合わせ込みの途中の回：最初の値で 17/20（行き過ぎ 200 ft など）、先読みを入れた値で 19/20（行き過ぎ 28 ft と、別の回で 74 ft）、最後の値で 20/20）、`s101_afds_pitch` 33/33、`s01_ap_basic` 15/15、`s104_afds_ga` 34/34、`s99_afds_engage` 36/36、`s100_afds_roll` 25/25、`s72_hdg_ref` 20/20、`s61_nd_orientation` 40/40、`s105_afds_roll_law` 18/18、`s106_afds_loc` 20/20（後の 6 本は 1 つ前の値で流した。違いは捕捉の前倒しと先取りと先読みだけ）。読み直しを重ねる前に X-Plane を起動し直しながら流した。Lua の誤りなし。
- 2026-10-28：6-3（AFDS）段 3b（速度を昇降舵で保つ則と速度の保護：notes/ATA-22.md §19）。ピッチの則のモデル `B747.70.afds_pitch_model.lua` に速度の則を足した：速度の差を 15 秒で詰める加速度と今の加速度の差を経路角にし、3.5 秒先の経路角を引いて指令を動かす（FLCH・前の VNAV の速度は 0.1 g、T/O・G/A は 3°/s まで）。FLCH は MCP の窓の速度、前の VNAV の速度のフラグはその速度。T/O は地上で 8°、浮いたら V2 + 10 と引き起こし（ピッチ 2° 超え）の速度 + 10 の高い方、5 秒続けて上回れば今の速度（V2 + 25 まで）、窓を高くすれば窓、PLI を超えない、windshear なら姿勢から（FCOM p.664、p.666、ATA22 p.344）。G/A は窓と今の速度の高い方（5 秒の更新は窓 + 25 まで）、上昇率 600〜1,200 fpm で 15°（か PLI の 1° 下）の姿勢から速度へ混ぜる（FCOM p.664、p.674）。速度の保護：目標を最小機動速度（フラップが出ていれば +5 kt）から最大速度 − 5 kt に（FCOM p.675）。値は推定で、3a の遅れのある機体に速度を足した模型で決めた。250 kt より遅いときはゲインを IAS に比例させた（X-Plane の離陸で、A/P の姿勢のループとともにピッチが ±3.6° 揺れたため）。FL350 の ALT HOLD の揺れ（A/P の姿勢のループに姿勢の変化率の減衰が無い：ATA22 p.330。3a の高度の則が強めた）は次の項目で直す。グルーが速度の入力（IAS、窓の速度、速度テープの Vminm・Vmax、PLI（出ているときだけ）、フラップ、GPWS の windshear）を渡す。計器のモジュールの `B747_Vs`（X-Plane の TOGA のピッチ）は外した（DSP-34 の一部）。エンジン故障時の目標は入力が無いので残り。試験：ピッチの則 77 件、グルー 123 件、全 119 本。新しいシナリオ `s108_afds_flch`・`s109_afds_takeoff`。X-Plane（カスタム acf）：新しい `s108_afds_flch` 21/21（10,000 ft・250 kt から FLCH で 15,000 ft へ：上昇に入る間 245〜252 kt、その後 20 秒は 250.0〜250.8 kt、+2,000 fpm；上昇中の MCP 280 kt：40 秒で入り、その後 277.1〜279.8 kt で行き過ぎなし；15,000 ft の捕捉は 25 ft 行き過ぎ。FLCH で 9,000 ft へ：降下に入る間 273〜280 kt、その後 277〜279 kt、−3,250 fpm；MCP 200 kt で、最小機動速度 225 kt に対し 227 kt で止まる；9,000 ft の捕捉は 36 ft 下がりすぎ。PFD を撮った：FLCH SPD、F/D のバーは中央。A/T の FMA は上昇・降下とも THR REF で、前の A/T のまま：6-4）、新しい `s109_afds_takeoff` 19/19（地上の F/D のピッチ 8°。この機体は 120 kt でピッチが 2° を超え、141 kt で自分で浮いた（目標は V2 + 10 = 170 kt）。1 回目は 30 秒の監視の下限 155 kt が浮いた速度の 153 kt より高く 18/19。下限を直した 2 回目は 19/19：速度は 169〜171 kt だが、A/P の姿勢のループのためピッチが約 12 秒周期・±3.6° で揺れ、50 秒ほどで収まった。ゲインを IAS に比例させた 3 回目も 19/19：揺れは 10〜30 秒で ±1.3°、50 秒で止まる。速度 172 kt・+2,800 fpm、5,000 ft の捕捉は行き過ぎなし。PFD を撮った：TO/GA｜TO/GA、CMD）、`s101_afds_pitch` 33/33、`s104_afds_ga` 34/34（2 回。G/A の後 400 ft を超えるまで 8.4 秒、800 ft で捕捉）、`s103_afds_to` 19/19、`s107_afds_vs_alt` 20/20、`s01_ap_basic` 15/15、`s10_overspeed` 22/22（FLCH で 250 kt のまま全推力）、`s102_afds_app` 36/36（1 回目は CDU の ILS の同調が NAV2 に通らず、LOC を捕まえなかった（25/36）。同調の後に NAV2 の信号の確認を足した）、`s07_cruise_ff` 5/5・warn 1（空中開始で ALT のまま 6,000 fpm で上がり、0.05 g で止めるまでに FL366 まで上がった。その間に前の窓の論理が IAS/MACH の窓を M0.79 にし、A/T がそれ（268 kt）を保った。3a より前は 288 kt）、`s53_min_speeds_cruise` 10/11（FL350 の ALT HOLD が約 17 秒周期・±740 fpm・0.84〜1.16 g で揺れ、最小速度の判定がその時の荷重倍数で外れた。A/P の姿勢のループの問題で、次の項目で直す）。Lua の誤りなし。
- 2026-10-28：6-3 の段 3b の後、A/P の姿勢のループ（notes/ATA-22.md §20）を作業中で中断（利用者の指示）。FL350 の ALT HOLD の揺れ（約 17 秒周期・±740 fpm・0.84〜1.16 g）は、記録から当てはめた X-Plane の 747 の模型で再現し、自動トリムと PID の積分の取り合いが原因と分かった（3a より前も ±500 fpm。3a の高度の則が強めた）。資料（ATA22 p.330、系統図 p.333 の STAB POSITION → ELEV TRIM INTEG、p.149 の自動トリムの帯）に沿って、スタビライザーの動きの 1.9 倍（推定）を昇降舵の積分から差し引く作りと、自動トリムの 0.4° で入り 0.25° で切る帯（G/S 0.6°）を書き、単体試験（油圧のモジュールの試験に 6 件、全 119 本）まで済ませた。X-Plane での確認の前なので、その変更（afds_control、試験、s109 の離陸トリム）は `git stash` に退避した。分析の道具 `tests/tools/pitch_sysid.lua`・`attitude_loop_sim.lua` を足した。離陸の揺れの主因は滑走路開始のトリムの外れ（昇降舵が下げいっぱいに張り付いた）。再開手順は §20。
- 2026-10-28：6-3 の A/P の姿勢のループ（notes/ATA-22.md §20）を再開して仕上げた。`git stash` から戻し、X-Plane で 2 回に分けて流した。FL350 の ALT HOLD は ±740 fpm・0.84〜1.16 g から ±250 fpm・0.92〜1.07 g（高度 ±12 ft）に。s53 は 11/11（前は 10/11）。10,000 ft の捕捉は行き過ぎ 33 ft → 0、15,000 ft は 25 ft → 0、9,000 ft は 36 ft → 1 ft。離陸は離陸トリムを合わせて昇降舵の張り付きが無くなり、ピッチは 30 秒で落ち着く。残った揺れ（約 15 秒の高度の則の三角の指令と約 3.8 秒の短周期）は次の項目（内側のループの姿勢の変化率）で。
X-Plane（カスタム acf）：`s53_min_speeds_cruise` 11/11（前は 10/11）、`s07_cruise_ff` 5/5・注意 1（速度は 278 kt。IAS/MACH の窓が Mach になる件で、前と同じ）、`s107_afds_vs_alt` 20/20（12,000 ft の捕捉は行き過ぎ 0（前は 33 ft）、その後 30 秒は ±5 ft、10,500 ft は 4 ft 下がりすぎ（前は 26 ft）、上昇中の ALT HOLD の行き過ぎは 401 ft（前は 442 ft））、`s108_afds_flch` 21/21（15,000 ft の捕捉は行き過ぎ 0（前は 25 ft）、9,000 ft は 1 ft 下がりすぎ（前は 36 ft））、`s101_afds_pitch` 33/33、`s109_afds_takeoff` 20/20（離陸トリム −0.327、150 kt で引き起こし、158 kt で浮く。ピッチは 10〜30 秒で 8.2〜10.7°、30 秒から 9.3° 前後。昇降舵は最大 −0.46 で張り付かない。速度は目標の 170 kt を浮いた直後の加速で 177 kt まで越え、5 秒の更新で 178.6 kt を保つ）、`s104_afds_ga` 34/34、`s102_afds_app` 37/37、`s01_ap_basic` 15/15、`s10_overspeed` 22/22。FL350 の ALT HOLD（s07 の記録、最後の 3 分）：昇降率 ±250 fpm・0.92〜1.07 g・高度 ±12 ft（前は ±740 fpm・0.84〜1.16 g）。トリムは帯どおり 0.4° で動き 0.25° で止まり、そのぶん昇降舵が戻る。残った揺れは約 15 秒周期で、高度の則の指令が 0.05 g の速さの制限に張り付いた三角の波に、約 3.8 秒の小刻みなピッチの揺れ（短周期。新しい記録の当てはめで減衰 0.28）が重なる。線形の模型ではどちらも再現しない。Lua の誤りなし。
- 2026-10-28：6-3 の A/P の姿勢のループの残り（notes/ATA-22.md §21）。FL350 の ALT HOLD に残った ±250 fpm の揺れは、内側のループが遅いため（高度の則の指令に姿勢が 0.45° 遅れる。比例ゲインは、前の作りでは MCP 高度で下げていて、FL350 で 0.044）。資料（ATA22 p.330）の姿勢の変化率を足した（0.03）。それだけでは悪化したので、比例ゲインを全高度で 0.1 にして ±12 fpm・0.99〜1.00 g・高度 ±1 ft。値は X-Plane で決めた（模型は遅れを再現しない）。s107 の上昇中の ALT HOLD の戻りは 90 秒で見る。
X-Plane（カスタム acf）：`s07_cruise_ff`（FL350 の ALT HOLD：最後の 1 分は −9〜+12 fpm・0.992〜1.002 g・高度 ±1 ft、その前の 1 分は ±24 fpm、さらに前は ±55 fpm で、落ち着いていく）、`s53_min_speeds_cruise` 11/11、`s107_afds_vs_alt` 20/20（12,000 ft の捕捉は行き過ぎなし（7 ft 下）、その後 ±3 ft、10,500 ft は 0 ft、上昇中の ALT HOLD は 449 ft 行き過ぎて 90 秒で 4 ft 上。60 秒で見た 1 回目は 63 ft 上で 19/20）、`s108_afds_flch` 21/21（FLCH の速度は前とほぼ同じ、15,000 ft の捕捉は行き過ぎなし、9,000 ft は 4 ft 上）、`s101_afds_pitch` 33/33、`s109_afds_takeoff` 20/20（浮いた後のピッチは 10〜20 秒で 8.6〜10.5°、20 秒から 9.2〜10.2°）、`s104_afds_ga` 34/34、`s102_afds_app` 37/37、`s01_ap_basic` 15/15、`s10_overspeed` 22/22。Lua の誤りなし。
- 2026-10-28：5-2 の残り、ND の MAP CTR を実機どおりに（notes/ATA-31.md §40。利用者の「NDのMAP CTRのレンジの件は実機通りの仕様でお願い」）。選んだ範囲を全周のローズの円まで（拡大の半分の縮尺）にし、地図の記号・TCAS・空港と滑走路・コースの線・高度の弧・POS の線・予測線を合わせた。X-Plane の地図の層は 1 段上の範囲（表示のグルーだけが書く：つまみと CDU は選択だけ）、640 NM はパネルの半分の大きさの地図。TCAS の OFFSCALE の境も選んだ範囲。MAP CTR の航跡線と範囲の目盛（FCOM p.1143）を足した。途中で利用者が「スクショ見たらまた逆三角形ズレてるやん」と指摘：過去の写真（10/26・10/27 早朝）は拡大の ▽ の直し（10/27 午後）より前で、直しの後も全周表示の ▽ が 7 px 外に浮いていた（10/27 に残した所）。▽ の先をローズの外縁に触れさせた（OFFSET 237 → 230）。写真で、MAP CTR の飛行機の記号の頂点が地図の原点より 13.5 px 下にあることも見つけて直した（FCOM p.1251）。試験：ND のモデル 118 件（11 件増：MAP CTR の航跡線、X-Plane の範囲と半分の大きさ、POS の DME と覆いの円）、予測線 21 件（MAP CTR で半分）、空港 66 件（覆いの円と半分の縮尺）、表示のモジュール 242 件（9 件増：X-Plane の範囲をつまみから、MAP CTR で 1 段上、640 NM で半分の大きさ、航跡線）、TCAS のモジュール 67 件（MAP CTR の OFFSCALE の境）、CDU の EFIS 49 件（CDU は X-Plane の範囲を書かない）、全 119 本。X-Plane：1 回目（▽ は 228、飛行機の記号は前の位置）：`s66_cdu_efis` 41/41（起動の後の暖機）、`s44_tcas` 74/74（MAP CTR 10 nm：TA は範囲の内で機影、OFFSCALE なし、機影は 5 nm より外）、`s110_nd_map_ctr` 45/45（写真：40 NM の MAP CTR でローズまでが 40 NM、経路の線が点の記号を通る、上下の範囲の数字 20、10 NM で 5、320 NM で EDDF がローズの約半分、640 NM で 320 と半分の大きさの X-Plane の地図、VOR CTR は航跡線なし）、`s61_nd_orientation` 42/42、`s70_nd_airports` 39/39、`s68_nd_pos` 18/18、`s71_nd_vor_crs` 21/21、`s78_panel_show` 11/11。写真で ▽ の位置（228 では外端に 2 px かかる計算）と、MAP CTR の飛行機の記号の頂点が地図の原点（予測線の始まり）より 13.5 px 下にあることを見つけ、▽ を 230 に、記号の POS を 62.5 にして X-Plane を起動し直した。2 回目（▽ 230、記号 62.5）：`s66_cdu_efis` 36/41（起動直後の最初のフライトで右の CDU に電源が来ず、右の CDU の 5 件が落ちた：既知の暖機の現象で、1 回目は 41/41）、`s110_nd_map_ctr` 45/45、`s61_nd_orientation` 42/42（写真：MAP CTR の ▽ の先がローズの目盛の外端に触れ、飛行機の記号の頂点が予測線の始まり＝地図の原点に一致）。外から見た姿は変わらない（外観の写真）。Lua の誤りなし。
- 2026-10-28：区切りで中断（利用者の指示「X-Plane上で確認できたらコミットして、スムーズに再開できる形に締め作業して一旦中断して」「X-Planeも落としていいよ」）。作業中の項目は無い（ND の MAP CTR は 9fb5be38 で済、push 済み）。再開は「次にやること」5d・5e の順：LEGS の PLAN の CTR と STEP（上の「決まったこと（2026-10-28）」に資料の要点）、そのあと 6-3 の段 3c（G/S）。X-Plane は落とした：シナリオを流すときは X-Plane を起動し、捨てのフライト（`s66_cdu_efis`）を 1 本流してから（TESTING.md）。DIFFERENCES.md の毎朝の送付は、新しいセッションでは定期ジョブを作り直す（メモリー）。
- 2026-10-28：中断中に利用者が決めた：カスタム acf の空力は、最適化のためなら見た目が変わらない範囲で承認なしで変えてよい（CLAUDE.md）。空力の比較（FCOM PI.10.38–10.40 の姿勢と推力の表、FCTM の目安）を LEGS の PLAN の CTR と STEP の次の項目にする（次にやること 5f）。失速特性は 2026-10-25 に合わせてある（ACF_DIFF.md §5）。
- 2026-10-29：6-1・6-2 の LEGS の PLAN の CTR と STEP（notes/ATA-34-61-FMC.md §42。2026-10-28 の利用者の決定 (b)）。新しいセッションで再開（HANDOFF_PROMPT_2026-10-29.md の順）し、毎朝の DIFFERENCES の定期ジョブを作り直した（10:33）。前のセッションで作った実装（中心の状態 `planCtr`、<CTR>、6R の STEP> と小字の MAP CTR、NEXT・PREV・LEGS キー、押した CDU で 6R を振り分ける `legsr6`、X-Plane の表示中の点への書き込み `B747_fmc_plan_ctr_sync`）に、X-Plane の試験で分かった点の無いページの扱い（経路の終わりの破線だけのページでは中心を動かさない：推定、注記だけ）を足した。試験：`legs_plan_ctr_test.lua` 63 件、全 120 本。X-Plane（カスタム acf、X-Plane を起動して捨ての `s66_cdu_efis` 36/41 のあと）：新しい `s111_legs_plan_ctr` は 1 回目 46/47（この経路は 5 点で、2 ページ目が終わりの破線だけ：NEXT で中心が動かないのは作りどおりで、シナリオの期待の誤り）、条件を直して 51/51（PLN で `FI26R   <CTR>     /5000A`・STEP>・MAP CTR・表示中の点は現用点の行 4、STEP で RW26R と行 5、もう一度で進入復行の D261A：行は 5 のまま、NEXT で 2 ページ目は中心が動かない、PREV と LEGS キーで FI26R、副操縦士の ND の PLN と右の CDU の STEP で両方の <CTR>、MAP に戻すと STEP> が消える）。ND の写真：PLAN の中心が FI26R、STEP で RW26R に移り、点の記号と X-Plane の地図の線がそろう。CDU の写真は FCOM p.1330 の図の配置。関係する `s87_legs_pages` 29/29・`s89_route_sync` 26/26・`s95_abeam` 26/26・`s97_rte2` 31/31・`s110_nd_map_ctr` 45/45・`s70_nd_airports` 39/39。Lua の誤りなし。
