# 試験（TESTING）

作り直しの各項目は、次の 4 段で確かめる。

1. **構文チェック**：LuaJIT（`luajit -bl`）、または Lua 5.1 の `luac -p`。
2. **回帰試験**（`tests/`）：LuaJIT で X-Plane なしに回す。旧フォークの試験の仕組みを流用し、系統ごとに作る（§3）。
3. **X-Plane での試験**：飛行試験キット（§4）と Web API で回し、`Log.txt` のエラーも確認する。
4. **利用者の目視確認**：自分で確かめられなかった点だけを回す。

## 1. 旧フォークの試験（`tests_old/`、参照専用）

### 1.1 扱い

- `tests_old/` は `archive/old-master` の `tests/` と同じ中身（85 ファイル）。`ap_pitch_loop_test.lua` だけ改行コードが違う。
- `.git/info/exclude` で git の管理から外してある。旧フォークのコード向けなので、そのまま通す必要はない。
- 中身は FlyWithLua のスクリプトではなく、**LuaJIT で X-Plane なしに回す回帰試験**。本番の Lua をモックの上で読み込む。
  - 試験 76 本、閉ループのモデル 4 本（`approach_model.lua`、`climb_model.lua`、`roll_model.lua`、`mcp_alt_dial_model.lua`）、記録データ 4 本（`data/*.csv`）。
- 回し方は、リポジトリの直下から `luajit tests/<名前>_test.lua` を 1 本ずつ（1 本に 1 つのインタプリタ）。`lua5.1` でも動く（README）。

### 1.2 仕組み（4 つの手法）

| 手法 | やり方 | 例 |
|---|---|---|
| a. 純粋なモジュール | 本番のロジックを、表を返すモジュールに分けておく。試験は `dofile` で読み、入力の表を渡して出力を確かめる | `takeoff_profile_test.lua`（`B747.70.xt.autopilot.takeoff.lua` の `new` / `update`） |
| b. XTLua の名前空間の再現 | 本物の `plugins/xtlua_keysystems/init.lua` を `loadfile` と `setfenv` で読み、`create_namespace()` で XTLua と同じ名前空間を作る。本番ソースから目印（関数名など）の間を切り出し、`loadstring` と `setfenv(fn, ns)` でその中で実行する。dataref は名前空間の変数として与える（`ns.simDR_x = 値`） | `xtlua_route_constraints_test.lua` |
| c. ソースの静的検査 | 本番の Lua を文字列で読み、規則を検査する：xt スクリプトが `deferred_dataref` で使う `laminar/` の名前を init スクリプトが作っているか、名前空間で束ねていない dataref 名に書いていないか、必要な dataref を毎フレーム読んでいるか（warm read） | `hydraulics_dataref_binding_test.lua`、`xtlua_warm_reads_test.lua` |
| d. 閉ループのモデル | 点質量の 747 と、記録に合わせた X-Plane の姿勢応答のモデルで本番の制御則を回す。フレームレート（15・20・34 fps）を変えても結果が変わらないことを確かめる | `approach_model.lua`、`climb_model.lua`、`afds_speed_on_pitch_test.lua` |

- **モック**：
  - dataref は名前空間の変数、コマンドは関数の呼び出しで置き換える。
  - タイマー（`run_at_interval` など）、`print`、境界の関数（`getFMSData` など）は、試験側で差し替える。
- **判定**：`check` / `equal` / `near(実際, 期待, 許容)` で数える。失敗を集めて最後に `error` を出し、成功すれば件数を表示する。
- **XTLua の落とし穴**（旧フォークで分かったこと。新しい試験でも押さえる）：
  - スクリプトのモジュール内で、dataref の最初の読みは 0 になる → 要る dataref は毎フレーム読む。
  - xt スクリプトの `deferred_dataref` は `find_dataref` と同じ → init スクリプトで作っていないと存在しない。
  - メタテーブルの無い global テーブルの、無い添字を読むとスタックが溢れる。
  - チャンクをまたいで local は見えない。XTLua 独自の `dofile` の戻り値。1 回だけのコマンドには phase 2 が来ない。
  - Web API で XTLua の double 型 dataref に小数を書くと HTTP 400 になる。
  - X-Plane の dataref に、前に書いたのと同じ値を書いても X-Plane には渡らない。X-Plane が値を変えた後は、そのモジュールが読み直すまで直らない（XTLua の xpmtdatarefs.cpp：書くとキャッシュと比べ、違うときだけ次のフレームで 1 回渡す。読むと次のフレームで X-Plane から読み直す。2026-10-23 に、Web API で cross tie を書き換えると、毎フレーム書いている電源のグルーが元に戻さないことを確かめた）→ X-Plane の dataref は毎フレーム読んで、違うときだけ書く。X-Plane なしの試験（`tests/lib/xtlua.lua`）はこれを再現しない。

### 1.3 記録データ（`tests_old/data`）

- 旧フォークの飛行試験キットが X-Plane で記録した `session.csv` から切り出したもの。キット本体は見つからない。
- 列（意味は旧試験のコメントからの**推定**。フェーズ1で dataref と照らして確かめる）：

| ファイル | 列 |
|---|---|
| `p32-line1_gs_pitch.csv`（EHAM ILS 18R の G/S、2,300→400 ft） | `t, fd, pitch, q, alpha, trim, ias, elevator_ratio` |
| `p34-L1_speed_pitch.csv`、`p35-line1_speed_pitch.csv`、`p35-line1_takeoff.csv` | `t, alt, ias, vs, pitch, thrust, tgt, flap, fma, mcp_alt, window, weight` |

| 列 | 意味（推定） | 単位 |
|---|---|---|
| `t` | 記録開始からの時間 | s |
| `fd` | FD のピッチ指令 | deg |
| `pitch` / `q` / `alpha` | ピッチ角 / ピッチレート / 迎角 | deg / deg/s / deg |
| `trim` | 安定板トリム | 不明（要確認） |
| `elevator_ratio` | 昇降舵の比（-1〜1） | — |
| `alt` / `ias` / `vs` | 高度 / 指示対気速度 / 昇降率 | ft / kt / fpm |
| `thrust` | エンジン 1 基あたりの推力（`sim/flightmodel/engine/POINT_thrust`） | N |
| `tgt` | AFDS の目標速度 | kt |
| `flap` | フラップハンドルの比（0〜1） | — |
| `fma` | ピッチの FMA モード番号（`B747DR_ap_FMA_active_pitch_mode`。旧試験では 1 TO/GA、4 VNAV SPD、8 FLCH） | — |
| `mcp_alt` / `window` / `weight` | MCP 高度 / 高度捕捉の窓（`B747DR_alt_capture_window`） / 重量 | ft / ft / kg |

### 1.4 X-Plane での確認シナリオ（README の末尾）

- README の末尾に 16 件ある。旧フォークで作った VNAV・FMC の機能が中心。例：出発の加速高度、ステップ上昇、CRZ ALT、ECON の切り替わり、SPD REST、フラップの速度制限。
- 新しいキットのシナリオには、資料で裏付けが取れるものだけを移す（§4.5）。

## 2. 流用するもの・しないもの

- **流用する**：
  - 1 本に 1 つのインタプリタで回す形、判定の道具（`check` / `equal` / `near`、失敗を集めて最後に出す）
  - XTLua の名前空間の再現（本物の `init.lua` を読む方式）
  - 静的検査（init で作られているか、束ねていない名前への書き込み、warm read、global テーブルのメタテーブル）
  - CSV の読み込みと補間、閉ループのモデルの骨組み（フレームレートを変えて回す形）
  - README の X-Plane での確認シナリオ（§1.4）のうち、資料で裏付けが取れるもの
- **流用しない**：
  - 旧コードの関数名や目印に頼った切り出し。新しいコードでは、試したいロジックを純粋なモジュールに分け、`dofile` で読む形を基本にする。
  - 旧コードの調整値。記録に合わせただけのモデルの定数も含む。
- **期待値**：
  - 旧試験の期待値は、資料（FCOM・FCTM・整備マニュアル）で裏付けが取れたものだけを新しい試験に移す。移した値には、コメントで出典（`FCOM p.801 (6.20.7)` の形）を付ける。
  - 裏付けの無い値は移さない。どうしても要るときは「推定」と書く。

## 3. 新しい回帰試験（`tests/`、git 管理）

- 回し方（リポジトリの直下から。LuaJIT の場所は §6）：
  - `bash tests/run.sh`：`tests/**/*_test.lua` を 1 本ずつ LuaJIT で回す。
  - `bash tests/syntax_check.sh`：機体の Lua（git 管理のもの）と試験の構文チェック（`luajit -bl`）。
  - `luajit tests/tools/same_behaviour.lua <入力> [git の版]`：挙動を変えない変更の確認（下）。
  - `luajit tests/tools/panel_names.lua [acf]`：acf のパネルが使う laminar/ の名前のうち、INTERFACES.tsv に無いものを、INTERFACES.tsv の行の形で出す。カスタム acf のパネルを変えたら回して、出た行を INTERFACES.tsv に足す（名前の順）。
- 構成：

| 置き場所 | 中身 |
|---|---|
| `tests/lib/check.lua` | 判定の道具（`check`・`equal`・`near`。失敗を集めて最後に出す） |
| `tests/lib/source.lua` | 機体の Lua を文字列で読む。init と xt の区別、init で作られる名前の一覧 |
| `tests/lib/xtlua.lua` | XTLua のモジュールを X-Plane なしで動かす（下） |
| `tests/static/*_test.lua` | 全系統に共通の検査。xt スクリプトの dataref が init で作られているか、`INTERFACES.tsv` の名前が残っているか、全モジュール（26）が X-Plane なしで読み込み・`flight_start`・60 フレームを Lua の誤りなしに通るか（`modules_run_test.lua`） |
| `tests/tools/same_behaviour.lua` | 挙動を変えない変更（コードの切り出しなど）の確認。作業ツリーと git の版で同じモジュールを同じ入力・同じ乱数の種で回し、毎フレーム、書かれた dataref・実行したコマンド・print の行を比べる。20・30・45 fps で回す |
| `tests/tools/scenarios/*.lua` | `same_behaviour.lua` の入力。`hydraulics_afds.lua` は油圧モジュール（AFDS の制御則・ヨーダンパー・スラットを含む） |
| `tests/<系統>/*_test.lua` | 系統ごとの試験（作り直しと一緒に書く）。`tests/elec/`：電源モデルの単体と、XTLua で動かした電源モジュール。`tests/gear/`：空地判定（PSEU）の単体と、XTLua で動かした脚モジュール。`tests/warning/`：警報のモデルの単体と、XTLua で動かした警報モジュール（manipulators の master リセットと fltInst の CANC・RCL も一緒に読み込む）。`tests/hyd/`：油圧のモデルの単体と、XTLua で動かした油圧モジュール（B747.20 も一緒に読み込む）。`tests/bleed/`：空圧のモデルの単体と、XTLua で動かした空調モジュール（抽気のグルーを含む）。`tests/lighting/`：XTLua で動かした照明モジュール。`tests/apu/`：APU のモデルの単体とモジュール。`tests/fuel/`：燃料のモデルの単体とモジュール。`tests/engines/`：始動・点火・燃料弁、エンジンの表示（EGT・N1・N2・N3・EPR の色、オイル、振動）、超過の赤い枠、逆推力の、それぞれモデルの単体と XTLua で動かしたエンジンモジュール。`tests/eec/`：EEC のモデル（定格・レバーの指令・推力の制御・オーバースピード保護・アイドル・ALTN）の単体とモジュール。`tests/air/`：パック・与圧・機器冷却・温度のモデルの単体と、XTLua で動かした空調モジュール。`tests/antiice/`：防氷・防雨のモデルの単体と、XTLua で動かした防氷モジュール（モジュールが書く X-Plane の dataref がすべて書き込み可か（DataRefs.txt）も見る）。`tests/oxygen/`：酸素のモデルの単体と、XTLua で動かした酸素モジュール（照明のモジュールも読み込み、サインの強制点灯を見る）。`tests/safety/`：XTLua で動かした安全のモジュールのサインの memo（照明・酸素のモジュールと一緒に）。`tests/fire/`：火災防護のモデルの単体と、XTLua で動かした火災モジュール（照明のモジュールと一緒に。`tests/apu/apu_module_test.lua` も火災モジュールを読み込み、X-Plane の APU 火災から APU の停止まで） |

- `tests/lib/xtlua.lua`（XTLua の再現）：
  - 本物の `plugins/<instance>/init.lua` を新しい環境で読み、`run_module_in_namespace()` でモジュールを読み込む。`dofile` はモジュールのフォルダから読む。名前空間の動き（bare table のコピーなど）も XTLua と同じに出る。
  - init.lua が呼ぶ C の関数（`XTLuaFindDataRef`・`XTLuaGetNumber` など）は、メモリ上の dataref の表で置き換える。関数名は XTLua の本体（`64/win.xpl`）の文字列と照合した（`XlLuaReplaceCommand` の綴りも本体どおり）。
  - dataref の型：`laminar/…` は init スクリプトを実際に走らせ、作られた型を集める（`"array[" .. NUM_BTN_SW .. "]"` のように実行時に組み立てる型もとれる）。`sim/…` は X-Plane の `Resources/plugins/DataRefs.txt`（場所は環境変数 `XPLANE_ROOT` で変えられる）。どちらにも無い名前は、X-Plane と同じく読むと 0、書いても消える。試験の側から無い名前に書こうとすると誤りにする。
  - `int` の dataref は、書いた値を切り捨てる。数値の dataref に数値でないものを書くと 0 になる（同じ global を 2 回 `find_dataref` すると起きる）。
  - X-Plane との違い：読み書きはすぐ反映する（X-Plane ではフレームごとに同期し、最初の読みは 0）。dataref を動かすのは試験だけ。手元の LuaJIT は表の `__len`・`__pairs`・`__ipairs` を無視するので、名前空間がコピーした表（ARCHITECTURE.md §9a）の `#` は 0 になる（XTLua の本体でどうなるかは未確認）。
  - 1 フレームでは、時計（`sim/time/total_running_time_sec`）を進め、タイマーを回し、`before_physics`・`after_physics` を読み込んだ順に呼ぶ。コマンドは phase 0・1・2 で呼べる。
- 系統を作り直すときに、その系統の試験を一緒に書く。
- 1 件の試験は「入力（スイッチ、dataref の値、経過時間）→ 期待される出力（dataref、EICAS メッセージ、ライト）」の形にし、出典のページを付ける。
- 時間で進む処理は、dt を渡して回す。フレームレートを変えても結果が同じになることも確かめる。

## 4. 飛行試験キット（新規。PLAN の最初の項目）

旧フォークの飛行試験キット（X-Plane で飛ばして `session.csv` に記録し、判定するもの）は見つからないので、新しく作る。系統の変更より先に完成させ、純正 acf とカスタム acf の両方で動くことを確かめる。

### 4.1 方針

- **Web API が中心**。X-Plane 12.4 以降の v3 で、dataref の読み書き、コマンドの実行、フライトの開始（`POST /flight`）を使う。スクリーンショットは X-Plane のスクリーンショットのコマンドを Web API から実行し、出てきた画像を取る。
- **毎フレームの精度が要る部分だけ FlyWithLua で補う**。毎フレームの記録（`session.csv`）、FMA の変化などのイベントの時刻、最大値・最小値のような細かい判定がそれにあたる。Web API の更新は、WebSocket で約 10 Hz。
- FlyWithLua のスクリプトは `../../Resources/plugins/FlyWithLua/Scripts/` に置く（利用者の許可あり。置いたものは報告する）。正本はリポジトリに置き、コピーして使う。

### 4.2 構成

| 置き場所 | 中身 |
|---|---|
| `tests/flight/xp.ps1` | Web API クライアント。`/api/capabilities` の確認、名前→ID の解決とキャッシュ、dataref の読み書き（文字列の dataref は復号する）、コマンドの実行、フライトの開始、スクリーンショットの取得。コマンド行からも使える（`caps`・`get`・`set`・`cmd`・`flight`・`shot`・`find`） |
| `tests/flight/run_scenario.ps1` | シナリオの実行。手順を順に実行し、条件を待ち（タイムアウト付き）、判定する。結果は JSON と Markdown で書く。手順の種類はファイルの先頭に一覧がある（`switch`・`wait`・`check`・`snapshot`・`cas`・`view`・`shot` など）。`view` の型：`forward`（前）、`panel`（機長席から計器盤）、`overhead`（機長席から P5 の電源パネル）、`eicas`（機長席から upper EICAS を中央に）、`bleed`（P5 の抽気パネルを視野角 25° で拡大）。`{the, psi, fov}` で向きと視野角を直接書ける。視野角は次の `view` とシナリオの終わりで、始めの値に戻す |
| `tests/flight/scenarios/` | シナリオの定義。`s00_baseline_start`（駐機から電源投入・APU・4 発始動）、`s01_ap_basic`（空中から A/P の ALT HOLD・HDG・V/S。機体を読み直す）、`s02_elec_panel`（エンジン運転中に P5 の電源パネルを操作。機体を読み直す）、`s03_alerts`（エンジン運転中に BUS TIE 2・GEN CONT 2 で advisory と caution を出し、EICAS の並び・master CAUTION とリセット・CANC/RCL を見る。機体を読み直す）、`s04_hydraulics`（エンジン運転中に ENGINE pump 1・DEMAND 1 を切り、油圧・P5 の灯・EICAS・synoptic を見る。機体を読み直す）、`s05_bleed`（エンジン運転中に ISOLATION L・ENGINE BLEED 1・NAI 1 を操作し、弁・ダクト圧・P5 の VALVE と OFF の灯・>BLEED 1 OFF を見る。最後に AC bus 1 を切って ISLN L を動けなくし、BLEED ISLN L と beeper の合図を見る。機体を読み直す）、`s06_fuel`（エンジン運転中に CWT に燃料を入れて CWT から供給、CTR L を OFF、主 1 のポンプと X FEED 1 を OFF にして吸引供給と FUEL PRESS ENG 1、最後に FUEL CONTROL 4 を CUTOFF。頭上の灯と FUEL synoptic を画像で見る。機体を読み直す）、`s07_cruise_ff`（FL350 の空中開始から FLCH で 35,000 ft に戻して ALT・SPD で巡航し、294 kt に近づくのを待って、1 発あたりの燃料流量・Mach・総重量・外気温を記録する。FCOM PI.11.2 と比べる。機体はフライトの開始で読み込まれるときがよい）、`s08_autostart`（エンジン運転中にパックを OFF にしてエンジン 4 を止め、AUTOSTART ON で再始動：START だけでは開かない start valve、RUN で motoring、燃料と点火、50 % の cutout、idle、EGT の始動限界の線（CUTOFF と始動中に出てアイドルで消える）、油圧の表示は CUTOFF と始動中は低くても白、地上の CUTOFF で二次エンジン表示が出ない、燃料投入の印（火災スイッチを引くと消える）、地上の始動中は X-Plane のスプール時間 26 秒。次に X-Plane の igniter の故障で 2 回目に中止して ENG 4 AUTOSTART。機体を読み直す）、`s09_eec`（10,000 ft の空中開始で A/P の ALT HOLD のまま、NAI 1 の ON・OFF で approach idle と 5 秒後の minimum idle、109 では CON で approach idle にならないこと、EEC の最大定格、A/T の SPD 中に EEC MODE 2 を ALTN にして ENG 2 EEC MODE・A/T の切断・ALTN の間は A/T を使えないこと、NORM に戻せば使えること、最後に空中で FUEL CONTROL 4 を CUTOFF にして二次エンジン表示が出ることを見る。機体を読み直す）、`s10_overspeed`（10,000 ft の空中開始で海面 50 ℃ の高温にし、A/P の FLCH・A/T を切って全推力：通常モードで最大 EPR に止まること、EEC MODE を 4 基とも ALTN にした overboost で指令に合い N1・N2 が赤線を超えないこと、RPM LIM・LIM PROT。機体を読み直す）、`s11_takeoff_thrust`（RJAA 34L でエンジン運転中に全推力と TO/GA で離陸滑走し、EPR が最大定格まで行き過ぎずに上がって保たれること、EGT の色（TO/GA の後は琥珀にしない）、80 kt で離陸中止、全開で最大 EPR に届くと EPR の帯が赤になりアイドルで白に戻る。機体を読み直す）、`s12_reverser`（RJAA 34L でエンジン運転中にパーキング・ブレーキをかけ、逆推力のコマンド（全エンジン）で 4 基とも展開して REV が緑、放すと格納。次に ENGINE pump 1 と DEMAND 1 を OFF にして系統 1 の圧を抜き、逆推力 1 だけが動かず ENG 1 REVERSER が出て、放すと消えること。機体を読み直す）、`s13_oil`（RJAA 34L でエンジン運転中に、アイドルのオイルと振動の値を記録し、X-Plane の故障でオイルポンプ 1 を止めて油圧 1 が赤線を切って赤・ENG 1 OIL PRESS、戻して消える。FUEL CONTROL 1 を CUTOFF にして油圧が下がっても白、回転が下がると油量が戻る。機体を読み直す）、`s13_oil_ge`（同じ故障を GE（Saudia）で：赤線（N2 で 10〜35 psi）を切って赤、低圧スイッチ 10 psid で ENG 1 OIL PRESS、15 psid で消える。機体を読み直す）、`s14_press_ground`（RJAA 34L でエンジン運転中に、X-Plane の与圧の上書き、地上モードで外流弁が全開（計器の写真）、パック 3 基 high、着陸高度 2000 AUTO と LANDING ALT と data block。CDU の RTE で経路を入れ、出発地 RJAA の標高（135 ft）、出発地を KSFO にして 400 NM 超で目的地 RJTT の標高（21 ft）。LDG ALT の MAN とノブの 50 ft 刻み、MAN L と CLOSE で左だけ閉じ OUTFLOW VLV L、両方 MAN で CABIN ALT AUTO、パックの memo、エンジン運転中の開始の TRIM AIR・RECIRC・EQUIP COOLING と機器冷却のファン、地上の EQUIP COOLING OVRD で 55 秒後に EQUIP COOLING、離陸滑走の 65 kt で takeoff モード（ΔP 約 0.027）と中止で地上モード。機体を読み直す）、`s15_press_cruise`（FL350 の空中開始（X-Plane は約 41,700 ft・速度ほぼ 0 で始めて落とす。A/P が 35,000〜38,000 ft で水平にする）。RECIRC を ON にし、水平になったところで客室が巡航のスケジュール（ΔP 8.8）で cruise モードと cruise clamp、パックが normal flow に、下の再循環ファンも運転、外流弁ほぼ閉。パックを全部 OFF で客室が上がり CABIN ALTITUDE、戻すと下がる。巡航の温度（客室が target 付近、パックが冷やす、前方貨物室）と、EQUIP COOLING OVRD で差圧があれば 60 秒たっても EQUIP COOLING が出ないこと。X-Plane の急減圧の故障で客室の急上昇、CABIN ALTITUDE、controller B の引継ぎと STATUS CABIN ALT AUTO A。機体を読み直す）、`s16_temp_ground`（RJAA 34L でエンジン運転中に、客室が target で始まり、TRIM AIR ON でトリム空気の弁と target、TRIM AIR を切ると >TRIM AIR OFF・ZONE SYS FAULT 灯（P5 の写真）・target が消える backup、PASS TEMP を W で MASTER と target が 85°F になり客室が暖まり F/D は動かない、C で 65°F、AFT CARGO HT を入れても 40°F より暖かければ暖房しない。機体を読み直す）、`s17_ecs_synoptic`（RJAA 34L でエンジン運転中に、下の EICAS の ECS synoptic を撮る：ゾーン温度の target と actual、MASTER、FWD・AFT、TEMP °C、外流弁の針と AUTO、パック 3 基の A と HI FLOW。TRIM AIR OFF で target が消える、MAN L で琥珀の MAN と L の針が CL の方へ、PACK 1 OFF で OFF と HI FLOW が消える、ENGINE BLEED 1 OFF で 1 番の弁が OFF になり流れの線が消える。カスタム acf のパネルの確かめ。機体を読み直す）、`s18_antiice_ground`（RJAA 34L でエンジン運転中に、WINDOW HEAT ON・プローブの加熱・氷検知の初期状態、NAI 1〜4 ON で弁が開き VALVE 灯が消え X-Plane の inlet heat と主 EICAS の NAI、TAT 12°C 超で >ANTI-ICE、X-Plane の inlet heat 2 の故障で NAI 2 の弁が閉じて VALVE 灯と NAI VALVE 2、スイッチの入れ直しで戻る、地上の WAI ON で弁が開かず灯も点かない、WINDOW HEAT L OFF で INOP L と HEAT WINDOW L、右の窓の故障が 10 秒切って入れ直すまで残る、ピトー熱の故障で HEAT P/S CAPT、氷検知器の故障で >ICE DETECTORS と STATUS、ワイパーの LO・HI。機体を読み直す）、`s19_antiice_air`（10,000 ft の空中開始で、TAT の加熱、WAI ON で左右の弁が 3 秒以内に開き VALVE 灯が消え X-Plane の翼の熱と主 EICAS の WAI、TAT 12°C 以下で >ANTI-ICE が出ない、右 TAT の加熱の故障で 15 秒後に HEAT R TAT、WAI OFF で弁が閉じる。機体を読み直す）、`s20_oxygen`（FL350 の空中開始で、STATUS ページの酸素圧（写真）と X-Plane の酸素系統の上書き、選択器 OFF で PASS OXYGEN を ON にして PASS OXYGEN ON・サインの強制点灯・60 秒後の STATUS、RESET で消える、THERAPEUTIC の ON・RESET で THERAP OXYGEN ON、乗員マスクを着けて X-Plane の急減圧で客室が 14,000 ft を超えると乗客酸素と治療用酸素が自動で作動し、RESET が効かない、マスクの有無で X-Plane の pilot_felt_altitude_ft が 10,000 ft と客室高度。機体を読み直す）、`s21_sign_memos`（RJAA 34L でエンジン運転中に、サインの選択器が AUTO なら脚が下りてサインが点いても memo が出ず、NO SMOKING だけ ON で NO SMOKING ON、両方 ON で PASS SIGNS ON、SEAT BELTS だけ ON で SEATBELTS ON。機体を読み直す）、`s22_fire_engine_apu`（RJAA 34L でエンジン運転中に、FIRE/OVHT TEST を押し続けて（ボタンの dataref を 1 にする）TEST IN PROG と火災灯、5 秒で PASS、離すと消える。火災が無いと消火スイッチ 3 が引けない、X-Plane のエンジン 2 の火災で FIRE ENG 2 とベル、スイッチ 2 を引いて A に回すとボトル L A で火が消え BTL DISCH と >BTL LO L ENG A。失敗の dataref で OVHT ENG 3 NAC と >DET FIRE/OHT 4。X-Plane の APU 火災で FIRE APU と APU の停止の指令、10 秒後の自動放出で火が消え >BOTTLE LOW APU。機体を読み直す）、`s23_fire_cargo`（FL350 の空中開始で、FIRE/OVHT TEST で貨物の灯と PASS、失敗の dataref で後方貨物室の煙：FIRE CARGO AFT と灯、ARM AFT で pack 3 停止、DISCH で A・B 即時と C は待つ、DISCH の灯と空中の >CGO BTL DISCH、剤で煙が消える。車輪格納部の火災、左のダクトリーク、化粧室とクルーレストの煙。機体を読み直す） |
| シナリオの `livery` | リバリーのフォルダー名（例 `"Saudia"`）。フライトの開始で `aircraft.livery` に渡す。エンジン型式はリバリーの `B747-400_simconfig.dat` で決まるので、GE（Saudia、Metal など）や RR（British Airways など）の試験に使う |
| `tests/flight/fwl/B747_flighttest.lua` | FlyWithLua 用の記録スクリプト。毎フレームの記録、イベント、最大・最小。コマンド（`FlyWithLua/B747_flighttest/start`・`stop`・`mark`）を Web API から操作する。747 以外の機体では何もしない。X-Plane の `Resources/plugins/FlyWithLua/Scripts/` に写して使う |
| `tests/flight/runs/<日時>_<シナリオ>_<acf>/` | 出力。`session.csv`、`events.csv`、`summary.txt`、`result.json`・`result.md`、スクリーンショット、その回の `Log.txt`（全体と、誤りらしい行の抜粋）。git の管理外 |

- 使い方：`powershell -NoProfile -ExecutionPolicy Bypass -File tests\flight\run_scenario.ps1 -Scenario <シナリオ> -Acf custom|stock [-Reload]`。
  - 同じ機体のまま新しいフライトを始めても、X-Plane は機体を読み直さない（系統の状態が前のフライトから続く）。真っさらから始めるときは `-Reload`。
- `session.csv` の列（記録スクリプトの版 3。先頭 17 列は §1.3 と同じ名前・単位）：

| 列 | dataref | 単位 |
|---|---|---|
| `t` | 記録開始からの sim 時間 | s |
| `alt`・`ias`・`vs` | `sim/cockpit2/gauges/indicators/altitude_ft_pilot`・`airspeed_kts_pilot`・`vvi_fpm_pilot` | ft・kt・fpm |
| `pitch`・`q`・`alpha` | `sim/flightmodel/position/theta`・`Q`・`alpha` | deg・deg/s・deg |
| `thrust` | 4 基の `sim/flightmodel/engine/POINT_thrust` の平均 | N |
| `tgt` | `sim/cockpit2/autopilot/airspeed_dial_kts` | kt |
| `flap` | `sim/cockpit2/controls/flap_ratio` | 0〜1 |
| `fma` | `laminar/B747/autopilot/FMA/active_pitch_mode` | 番号 |
| `mcp_alt` | `laminar/B747/autopilot/heading/altitude_dial_ft` | ft |
| `window` | `laminar/B747/autopilot/ap_monitor/alt_capture_window` | ft |
| `weight` | `sim/flightmodel/weight/m_total` | kg |
| `fd` | `laminar/B747/autopilot/flight_director_pitch_deg` | deg |
| `trim` | `sim/flightmodel2/controls/elevator_trim` | -1〜1 |
| `elevator_ratio` | `laminar/B747/flt_ctrls/custom_pitch_ratio`（A/P の `sim_pitch_ratio` と操縦輪の和。旧データと同じ意味。版 1・2 では昇降舵の指令角 `cablecontrols/left_inner_elevator`（deg）を入れていた） | -1〜1 |
| `roll`・`hdg_mag`・`gs_kt` | `sim/flightmodel/position/phi`・`mag_psi`・`groundspeed`（kt に換算） | deg・deg・kt |
| `ra`・`gload` | `sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot`・`sim/flightmodel/forces/g_nrml` | ft・G |
| `n1_1`〜`egt_4` | `sim/flightmodel/engine/ENGN_N1_`・`ENGN_N2_`・`ENGN_EPR`・`ENGN_EGT_c`（4 発） | %・%・—・℃ |
| `ff_1`〜`ff_4` | `sim/cockpit2/engine/indicators/fuel_flow_kg_sec`（機体の燃料系と EICAS が使う値。版 1 は `ENGN_FF_` で、始動中に負になる） | kg/s |
| `thro_1`〜`thro_4` | `sim/flightmodel/engine/ENGN_thro_use` | 0〜1 |
| `fma_roll`・`fma_pitch_armed`・`fma_roll_armed`・`fma_at` | `laminar/B747/autopilot/FMA/active_roll_mode`・`armed_pitch_mode`・`armed_roll_mode`・`autothrottle_mode` | 番号 |
| `servos_on`・`on_ground` | `laminar/B747/autopilot/servos_on`・`sim/flightmodel/failures/onground_any` | 0/1 |
| `frame_rate`・`sim_t` | `1 / sim/operation/misc/frame_rate_period`・`sim/time/total_running_time_sec` | fps・s |
| `elev_deg` | `laminar/B747/flt_ctrls/l_elev_inner`（左内側の昇降舵。版 3 から） | deg |

- `events.csv`：FMA（4 種）、A/T、サーボ、空地、フラップの変化と、`mark`。

### 4.3 判定

- 判定の数値は FCOM・FCTM・整備マニュアルから取り、シナリオに出典を書く。
- 許容幅が資料に無いときは「推定」と書く。

### 4.4 完成の条件（PLAN 項目 1）

- 純正 acf（`747-400.acf`）とカスタム acf（`747-400_custom.acf`）の両方で、少なくとも「起動 → 電源投入 → APU → エンジン始動」のシナリオが自動で回る。
- `session.csv`、スクリーンショット、判定結果が出る。
- 作り直しの前の機体で、ベースライン（`Log.txt` のエラーと主要な値）を記録してある。

### 4.5 シナリオ

- 標準の飛ばし方は `docs/overhaul/notes/FCTM.md` の案から作る。
  - 例：cold & dark からの電源投入、エンジン始動、離陸、上昇、巡航とステップ上昇、VNAV 降下、ILS とオートランド、ゴーアラウンド、V1 後のエンジン故障、非 ILS 進入、停止。
- 旧 README の 16 件（§1.4）は、資料で裏付けが取れるものだけを加える。

### 4.6 気をつけること

- Web API は、フライトを読み込むまで dataref の一覧が空。
- X-Plane の Network 設定で「Disable Incoming Traffic」が入っていると、すべて 403 になる。
- XTLua の double 型 dataref に小数を書くと 400 になる（旧フォーク）。キットでは書き方を工夫するか、FlyWithLua 側で書く。2026-10-24 に X-Plane 12.4.4 でも確かめた（`incompatible_data`。整数と 1.0 は書ける。X-Plane 自身の float の dataref は小数も書ける）。シナリオではノブの dataref などに整数だけを書く（`s16` の PASS TEMP は W と C）。
- 機体の設定（エンジン型式、タンク数など）は、dataref から読んで判定に使う。カスタム acf の値を決め打ちしない。
- `/flight` は機体の読み込みが終わるまで応答しない（2 分以上かかることがある）。
- フライトの読み込み直後に機体の読み直し（`sim/operation/reload_aircraft_no_art`）を送ると、捨てられることがある。`-Reload` は `Log.txt` に新しい読み込みが出るのを待ち、出なければ送り直す。
- X-Plane が「応答なし」になっても、Web API は答え続ける（sim の時計だけが止まる）。2026-10-23 に 2 回起きた。どちらも、機体を読み込んだ直後に機体の読み直し（`reload_aircraft_no_art`）を送ったとき（1 回目は acf の切り替え、2 回目は X-Plane の起動直後の最初のフライト）。そこで `run_scenario.ps1` は、フライトの開始で機体が読み込まれたときは読み直さない（読み込んだばかりなので要らない）。読み直すときは sim の時計が 20 秒進んでから送る。また sim の時計が 30 秒動かなければ、残りの手順をやめて記録を残す。
- Web API でコマンドを長さ 0（`{"duration": 0}`、押してすぐ離す）で送ると、XTLua のハンドラーに phase 2（離した）が届かないことがある。押しボタン（CANC・RCL・master リセットなど）は押されたままになり、離したときの処理（RECALL を 1 秒後に消すなど）も動かない（2026-10-23、`s03_alerts`）。押しボタンは `cmd` の手順に `"duration": 0.2` を付けて押す。酸素のばね戻りのスイッチは、コマンドの最後のイベントから 0.3 秒で戻すようにしたので長さ 0 でも動く（2026-10-24、`s20_oxygen`）。
- `cas` の手順は 2 ページ分（`gen_*_msg_000`〜`021`）を読む。メッセージが 2 ページ目にかかると、warning は各ページの先頭に出るので 2 回並ぶ（FCOM p.1528、p.1548。`s15`・`s20` の CABIN ALTITUDE）。不具合ではない。
- 空中開始の `s01` は、機体の読み込み方で AFDS の初期状態が変わり、結果が変わる（PROGRESS.md「気づいたこと」）。X-Plane を起動し直した後の最初のフライト（フライトの開始で機体が読み込まれる）で回す。
- スクリーンショットは、sim が止まっているか読み込み中だと撮れない。X-Plane は撮れるようになってからまとめて保存する。
- FlyWithLua に付属の `please read the manual.lua` は、スクリーンショットの右上に吹き出しを出していた。2026-10-23 に利用者が消した。
- 超過の色と赤い枠（N1・N2・EGT）は、今の値では運転で超えない（表示の EGT が低い、N1・N2 はオーバースピード保護で赤線の手前で止まる）。X-Plane で見るときは、表示のモデルの限界（`M.RPM_RED`、`M.EGT`）を一時的に下げた版で流して、すぐ戻す（コミットしない。2026-10-24 の ENG-21 で使ったシナリオは PROGRESS.md の日誌）。X-Plane の hot start の故障でも EGT は始動限界（P&W 535 ℃）に届かない。
- シナリオは必ず 1 本ずつ流す。2026-10-24 に、待ち合わせの条件の誤りで `s08`（地上）と `s09`（空中開始）が同時に始まり、X-Plane が内部エラー（`MACIBM_alert: spin_pwr_dg v=NaN`、`fm_indi.cpp:274`）で止まった（Web API の dataref の読み書きが時間切れになる）。続けて流すときは、同じシェルの中で順に呼ぶ（別のコマンドを「前の結果の行が出たら」で待たせない。前の回の結果の行に先に当たる）。止まったときは X-Plane を起動し直した（Steam から。Web API は約 35 秒で答える）。

## 5. 1 項目ごとの流れ（フェーズ1以降）

1. 着手前に、変更方針を短く示す。
2. 実装する。
3. 構文チェック。
4. `tests/` の回帰試験（LuaJIT、X-Plane なし）。
5. 飛行試験キットと Web API で X-Plane での試験をし、`Log.txt` のエラーも確認する。区切りごとに純正 acf でも、起動・電源投入・エンジン始動まで回す。
6. 結果と、利用者が X-Plane で目視確認すべき点を報告する。
7. コミットする（1 テーマ 1 コミット、根拠の資料とページを書く）。

## 6. 環境（2026-10-23 時点）

- X-Plane 12.4.4-b5。Web API は v3 が使える（ARCHITECTURE.md §9）。
- FlyWithLua NG+ 2.8.19 は利用者が導入済み。`Scripts/` に記録スクリプト `B747_flighttest.lua` を置いた（正本は `tests/flight/fwl/`）。
- LuaJIT 2.1（`C:\Users\gakug\tools\luajit\bin\luajit.exe`。入手元は PROGRESS.md の T-1）。`tests/run.sh` は環境変数 `LUAJIT` で場所を変えられる。
- Python は使わない（CLAUDE.md）。
