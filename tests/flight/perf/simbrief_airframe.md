# SimBrief 入力シート（PERF_SIMBRIEF.md。20261109_121922_compare）

カスタム機体は B744 をベースに作る。値は SimBrief の単位（KGS）。根拠の詳細は report.md。

| SimBriefの欄 | 値 | 単位 | 根拠 |
| --- | --- | --- | --- |
| Base Type | B744 | – | 仕様（作成後は変えられない） |
| Empty Weight | 183523 | KG | acf の空虚重量（`20261109_045805_cruise_fl370` の meta.json） |
| Max Zero Fuel Weight | 244939 | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |
| Max Takeoff Weight | 394625 | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |
| Max Landing Weight | 285763 | KG | FCOM p.78（L.10.2）、機番 109（2026-11-06 利用者） |
| Max Fuel Capacity | 173069 | KG | acf のタンクの合計（`20261109_045805_cruise_fl370` の meta.json） |
| Passenger / Baggage Weight | 95 / 25 | KG | 機体の 1 人 120 kg（simconfig の std_pax_weight）を、乗客と手荷物に分けた（2026-11-06 利用者） |
| Fuel Factor | M01（-0.7 %） | P/M ％ | FMC の CI 200 の ECON の Mach で巡航したときの、3 本の Trip Fuel の誤差を距離帯の割合で重みづけた値（2026-11-08 利用者）。OFP の Mach なら M01（-1.5 %）。report.md |
| Service Ceiling | 43000 | ft | 軽い段の上限高度を 1,000 ft 単位で切り下げ。記録では 43,153 ft（buffet）。決め方は FCOM（1.30 g の高さと、上昇推力で 100 fpm を切る高さの低い方。2026-11-08 利用者）。`20261109_100640_climb` |
| Cruise Level Offset | 0 | ft（M/P表記） | 3 本の T/C と段階上昇の高さが、その重量の上限高度（FCOM の 1.30 g の高さ）に届いている。report.md |
| Default Cost Index | 200 | – | ふだんの CI（2026-11-08 利用者：SimBrief も FMC も CI 200）。機体の FMC の CI 200 は SimBrief の CI 200 より速く、その分は Fuel Factor に入れた。report.md |
| 計画時に選ぶ巡航プロファイル | CI 200 | – | 同上 |
| Engine Type | PW4056 | – | 表示だけ（B744 の既定は RB211-524H。2026-11-08 利用者） |
| T/O Thrust | 56740 | LBF | PW4056 の定格推力 252.4 kN（ICAO のエンジンの排出データ。B744 の既定は 60,600 lbf）。SimBrief の離陸の計算に使う（2026-11-08 利用者） |
