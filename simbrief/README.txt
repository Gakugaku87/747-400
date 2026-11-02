SimBrief の飛行計画を FMC へ（会社のデータリンク）

SimBrief の飛行計画を、FMC の会社データリンク（FMC COMM）で、会社からの
アップリンクとして受け取れます。SimBrief から自動で取るか、このフォルダに
ファイルを置きます。

1. SimBrief から自動で取る（Pilot ID）
   - MENU → SIM CONFIG の 2 ページ目の 5L（SIMBRIEF PILOT ID）に、SimBrief
     の Pilot ID（数字）を入れます。DELETE で消せます。一度入れれば残り
     ます（X-Plane の Output/preferences/B747-400_options.prf）。
   - RTE REQUEST <SEND のたびに、SimBrief でいちばん新しく作った OFP と、
     その X-Plane 11/12 の飛行計画を取り、このフォルダに
     <出発地><目的地>.fms と .xml（例：RJAARJBB.fms）で置いてから使います。
   - CO ROUTE を入れて要求したときは取らず、このフォルダのそのファイルを
     使います。
   - 取れなかったときは、会社から ACARS のメッセージ（SIMBRIEF: NO ANSWER
     など）が届き、このフォルダのいちばん新しいファイルを使います。
   - インターネットへの接続が要ります（Windows のみ）。

2. 自分で置く（種類ごとに、いちばん新しいファイルを使います）
   - 飛行計画：SimBrief の「X-Plane 11」形式の .fms
   - OFP：SimBrief の XML。ブラウザで
       https://www.simbrief.com/api/xml.fetcher.php?username=（ユーザー名）
     を開き、拡張子 .xml で保存します。便名を FLT NO に入れるほか、
     風や、重量・燃料・巡航高度・ステップクライムの ACARS の文に使います。
     出発地か目的地が .fms と違う OFP は使いません。

3. P&W・RR の機体では、MENU → SIM CONFIG の 2 ページ目で FMC DATALINK を
   ON にします（GE の機体は AUTO のままで使えます）。

4. FMC COMM → NEXT → RTE REQUEST <SEND（または RTE ページの REQUEST
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
flight plan. With a SimBrief Pilot ID on SIM CONFIG page 2 (5L), each
request first fetches the latest OFP and its X-Plane 11/12 plan from
SimBrief into this folder (<origin><destination>.fms and .xml). Files
other than this README are not kept in git.
