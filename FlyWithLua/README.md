# B747 Auto Step Climb

747本体を変更せず、FlyWithLua NG+からStep Climbを自動実行するX-Plane 12用スクリプトです。

## 動作

1. FMCが公開する`STEP TO/STEP ALT`と`stepdistance`を監視します。
2. 将来のS/C地点を一度観測すると、その高度に対してARMします。
3. S/Cまで0.5 NMになるとMCP高度を設定します。
4. 0.35秒後、747の実際のALTセレクターコマンドを発行します。
5. 747本体側が`CRZ CLB`を開始したことを巡航高度datarefで確認します。

FMC表示だけで本体が自動上昇するように戻すものではありません。外部スクリプトが操縦者のMCP操作を代行します。

## インストール

`B747_Auto_Step_Climb.lua`を次へコピーしてください。

```text
X-Plane 12/Resources/plugins/FlyWithLua/Scripts/
```

FlyWithLua NG+が必要です。また、747側は`stepdistance`を公開するPR #3以降の版を使用してください。

## 操作

初期設定ではロード時から有効です。X-Planeのキーボードまたはジョイスティック設定で次のコマンドを割り当てられます。

```text
FlyWithLua/B747_Auto_Step_Climb/enable
FlyWithLua/B747_Auto_Step_Climb/disable
FlyWithLua/B747_Auto_Step_Climb/toggle
```

## 実行条件

- 地上ではない
- Radio Altitude 5,000 ft以上
- VNAV巡航中
- VNAV Descentではない
- AutopilotサーボがON
- 現在高度が巡航高度の±1,200 ft以内
- 目標Step高度が現在の巡航高度より500 ft以上高い
- S/C地点を0.5 NMより手前で一度観測済み

条件はLuaファイル先頭の`B747_ASC_CONFIG`で変更できます。

## 安全動作

- スクリプトをS/C通過後にロードしても、即座には上昇しません。
- MCP設定からALTノブ押下までの間に操縦者がMCPを変更した場合、処理を中止します。
- 同一Step高度は一度しか実行しません。
- FMCが`NONE`または`TO T/D`のときはARMを解除します。
- 747が5秒以内に新しい巡航高度を受理しない場合、ログへ警告を出します。

FlyWithLuaのログで`[B747 Auto S/C]`を検索すると状態を確認できます。
