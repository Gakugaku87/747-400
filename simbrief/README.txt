SimBrief の飛行計画を FMC へ（会社のデータリンク）

このフォルダに SimBrief のファイルを置くと、FMC の会社データリンク
（FMC COMM）で、会社からのアップリンクとして経路を受け取れます。

1. 置くもの（種類ごとに、いちばん新しいファイルを使います）
   - 飛行計画：SimBrief の「X-Plane 11」形式の .fms
   - OFP：SimBrief の XML。ブラウザで
       https://www.simbrief.com/api/xml.fetcher.php?username=（ユーザー名）
     を開き、拡張子 .xml で保存します。便名を FLT NO に入れるほか、
     風や、重量・燃料・巡航高度・ステップクライムの ACARS の文に使います。
     出発地か目的地が .fms と違う OFP は使いません。

2. P&W・RR の機体では、MENU → SIM CONFIG の 2 ページ目で FMC DATALINK を
   ON にします（GE の機体は AUTO のままで使えます）。

3. FMC COMM → NEXT → RTE REQUEST <SEND（または RTE ページの REQUEST
   <SEND）。20 秒ほどで ROUTE 1 UPLINK READY が出ます。RTE ページの <LOAD
   で読み込み、中身を確かめて ACTIVATE → EXEC。いらなければ PURGE>。
   CO ROUTE に .fms のファイル名（拡張子なし、英数字 10 字まで）を入れて
   から要求すると、そのファイルを使います。
   ファイルが無いときは、会社から ACARS のメッセージ（NO FLIGHT PLAN ON
   FILE）が届きます。

※ _newest.txt は機体のプラグインが書くファイル（いちばん新しい .fms と
   .xml の名前）です。消しても次に書き直されます。

This folder holds SimBrief's X-Plane flight plan (.fms) and its OFP (XML)
for the 747-400's simulated company datalink: FMC COMM's RTE REQUEST
uplinks the newest .fms (or the one named in CO ROUTE) as the company's
flight plan. Files other than this README are not kept in git.
