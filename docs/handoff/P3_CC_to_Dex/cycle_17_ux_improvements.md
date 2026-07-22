[C1: CC(P3) ⇒ Dex(P4)]

# Cycle 17 UX改善 CC実装完了報告

対象指示書: `docs/handoff/P2_Dex_to_CC/cycle_17_ux_improvements_instructions.md`

## 1. 実装した機能一覧

### 印刷ステータス管理
- `projects.is_printed`（デフォルトFALSE）を追加。既存活動・新規活動とも初期値は未印刷。
- `/activity`一覧に「未印刷/印刷済」の絞り込み（`printedStatus=unprinted|printed|all`）を追加。`printedStatus`未指定時（初回アクセス）は`unprinted`が既定。「未印刷のみ表示中」インジケーターを表示。
- 各行に印刷ステータスの単体トグルボタン（未印刷⇔印刷済）を追加。
- `ProjectMapper.updatePrinted(id, isPrinted)` を追加。`findFiltered`は`printedStatus`引数を追加し、全呼び出し元（`ActivityController`の一覧/年度まとめ/年度末決算、`ExportController`の年度末決算、`BudgetAllocationController`の一覧/保存）を更新。legacy・年度末・予算管理からの呼び出しは`printedStatus=null`（絞り込みなし＝従来どおり全件）を渡すよう統一。

### 一括処理（`/activity`一覧）
- 行チェックボックス＋全選択チェックボックス。
- 選択分の2-2/2-6プレビュー・ダウンロードは、既存の`/export/preview`・`/export/download`をそのまま再利用（Excel生成ロジックの重複実装なし）。
- 選択分の印刷ステータス一括変更: `POST /activity/bulk/status`
- 選択分の一括削除: `POST /activity/bulk/delete`（確認ダイアログで選択件数を表示、未選択時はサーバー側でもガードして`error=no_selection`で一覧へ戻す）
- 一括処理後は絞り込み条件（年度・月・補助区分・種別・事業名・印刷ステータス）を維持して`/activity`へリダイレクト。
- 存在しないIDが混ざっても500にならない（`projectMapper.delete`/`updatePrinted`は対象0件でも正常終了する単純なSQLのため）。

### 活動複製
- `POST /activity/{id}/duplicate`。元活動が無ければ`/activity`へ。
- `Project`基本情報・参加者（`member_id`はそのまま参照）をコピー。金額項目（交通費・宿泊費・個人雑費・事業サマリ経費・旅行雑費単価/日数）は全て0にリセット。
- 新活動名は「[コピー] 元の活動名」。`is_printed`は必ずfalse。
- 複製後は複製先の編集画面（`/activity/{newId}/edit?duplicated=1`）へ遷移し、「金額項目は未入力・印刷ステータスは未印刷」である旨のバナーを表示。
- 1参加者に複数Expenseがある活動は、複製前に検出し複製を中止（`/activity?error=duplicate_multi_expense`）。`Expense.aggregate`での丸め込みはしない。
- `ProjectService.duplicateProject`は`@Transactional`。Project/Summary/参加者/Expenseのどこかで失敗すれば全ロールバック。

### ダッシュボード
- `DashboardController`を新設。`/dashboard`で年度選択・総活動数・未印刷/印刷済件数・決算書計上額合計・予算配分ごとの使用額/予算額/残額/使用率を表示。
- `/`は`/dashboard`へリダイレクト（従来は`/activity`）。ナビに「📊 ダッシュボード」を追加（先頭）。`/activity`・`/budget-allocations`への導線は維持。legacy `/export`はナビから外していない（そのまま残置）。
- 使用額は`/activity`の決算書計上額と完全に同じ式（参加者ごとの交通費・宿泊費＋事業サマリ経費＋旅行雑費[単価×人数×日数]、個人雑費は含めない）。
- `allocated_amount=0`の組み合わせは0除算せず使用率`null`（画面は「-」表示）。予算未登録でも活動実績があれば行を表示（予算額0扱い）。

### バージョン
- `app.version` を `v2.4.8` → `v2.4.9` に更新。

## 2. Air案から変更した点

- ダッシュボードのナビ上での`/export`非表示は行わなかった（Dex指示の「非表示にする場合でも直接URLは残す」を受け、リスクの低い「ナビはそのまま維持」を選択）。
- それ以外はDex(P2)最終指示書の範囲どおり。

## 3. 実装中に発見し、指示書の記述から変更・追加対応した点（重要）

### (a) `ADD COLUMN IF NOT EXISTS` はMySQL(Oracle版)では非対応構文だった
指示書どおり `ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_printed ...` を実装し実機起動したところ、`/activity`が500エラー（`Unknown column 'is_printed'`）になりました。調査の結果、この構文はMariaDB固有であり、実機のMySQL 8.0.46では構文エラーになることを確認しました（`ADD COLUMN IF NOT EXISTS`を単体で試しても同じ構文エラー）。さらに調査したところ、**Cycle 8で追加された`accommodation_nights`等の同じ構文のALTER文も、実は起動のたびに毎回サイレントに構文エラーで失敗し続けていた**ことが判明しました（`continue-on-error=true`により起動は継続するため誰も気づいていなかった）。それらの列が実際にDBに存在するのは、過去のどこかの時点で別経路（手動ALTER等）で追加されたためと推測されます。
- 対応: `is_printed`の追加は、`INFORMATION_SCHEMA.COLUMNS`で存在確認した上で`PREPARE`/`EXECUTE`による動的SQLで冪等に追加する方式に変更しました（実機で新規追加・再実行時の冪等性の両方を確認済み）。
- 影響範囲: 今回のCycle 17分（`is_printed`）のみ修正済み。Cycle 8由来の`accommodation_nights`等の既存ALTER文も同様に無効なままである可能性が高いですが、それらは今回のスコープ外のためschema.sqlの当該箇所は変更していません。**Dexの事後レビュー・別サイクルでの棚卸しを推奨します**（`docs/proposals/`に提案として起票済み）。

### (b) 一覧テーブル全体を`<form>`で囲む実装はHTML仕様上壊れる
最初の実装では一括処理用に`<table>`全体を`<form id="bulkForm">`で囲みましたが、行内の既存export個別フォーム（様式2-4/2-5/2-6のドロップダウン、印刷ステータス単体トグル）がその中にネストされ、ブラウザがネストした`<form>`開始タグを無視して外側の`bulkForm`へ誤送信する不具合を実機検証で発見しました（印刷ステータス切替ボタンを押すと`/export/preview`へ`exportType`なしで送信され400エラー）。
- 対応: `bulkForm`によるtable全体の包囲をやめ、チェックボックス値はJSで収集し、一括処理（プレビュー/ダウンロード/ステータス変更/削除）は動的に`<form>`要素を生成して送信する方式に変更しました。既存の行内export個別フォームは元のまま非ネストに戻り、複製・削除の隠しフォームパターン（既存踏襲）と統一しています。

### (c) 複製時、距離(km)をコピーすると編集画面のJSが交通費を自動復活させる
`transportDistanceKm`を複製先にコピーしたところ、編集画面を開いた瞬間にform.html内の距離連動の自動計算JS（自家用車の距離×単価を自動算出するロジック）が働き、DBでは0にリセットしたはずの交通費入力欄に「距離×単価」の金額が再セットされることを実機検証で発見しました（保存すればそのまま二重計上に繋がる重大な安全上の問題）。
- 対応: 指示書では距離は「コピーしてよい」とされていましたが、二重計上防止を最優先し、複製時は`transportDistanceKm`をコピーしない（null）よう変更しました。交通手段・区間（テキスト）はコピーしています。実機で交通費が0のまま保たれることを確認済みです。

### (d) 受領日はコピーしない
指示書の指示どおり、誤提出防止のため複製時は`receiptDate`をコピーせずnullにしました。

## 4. Dex(P2)指示への適合確認

- **legacy `/export`を削除しなかったこと**: `ExportController`・`templates/export/*`・`/export`ルートは無変更。`findFiltered`呼び出しにのみ`printedStatus=null`引数を追加（絞り込みなし＝従来どおり全件）。実機で`/export`直接アクセス、2-2/2-4/2-5/2-6の個別preview/download、年度末`/export/year/setup`→preview→downloadが従来どおり動作することを確認。
- **印刷ステータスは手動管理**: Excel出力（`/export/preview`, `/export/download`, `exportOne`, `exportYear`, `exportAnnual`）のどこにも`is_printed`を書き換える処理を追加していません。ユーザーが明示的にボタンを押した場合のみ`updatePrinted`が呼ばれます。UI文言は「未印刷/印刷済」に統一。
- **`/activity`とダッシュボードの金額は決算書計上額基準**: 両者とも「参加者ごとの交通費+宿泊費」＋「事業サマリの借用料/需用費/駐車料/報償費/役務費」＋「旅行雑費（単価×人数×日数）」の同一式。個人雑費`miscellaneousCost`は含めていません。実機で`/activity?printedStatus=all`の合計とダッシュボードの総活動数・件数・決算書計上額合計が完全一致することを確認（4件・16名・317,568円）。
- **複製は入力ひな形目的、金額項目コピーなし、二重計上防止**: 上記3(c)のとおり実機で確認。複製直後の活動の決算書計上額が0円であり、一覧の合計（`grandTotal`）が複製前後で変化しないことを確認。
- **複数Expense活動は複製中止**: DBに1参加者2件のExpenseを持つテスト活動を作成し、複製を実行 → `error=duplicate_multi_expense`で複製されないことを実機確認。
- **一括削除の安全対策**: POSTのみ・未選択時はクライアント側(Swal警告)とサーバー側(`error=no_selection`)の両方でガード・確認ダイアログに選択件数を表示。`git reset --hard`等の破壊的git操作は使用していません。

## 5. バージョン・compile結果

```
src\main\resources\application.properties:10:app.version=v2.4.9
target\classes\application.properties:10:app.version=v2.4.9
```

- `.\mvnw.cmd -q -DskipTests compile` : 成功（複数回、最終コード確定後も成功）
- `.\mvnw.cmd -q -DskipTests clean compile` : OneDriveの同期ロックにより`target\classes\...\controller`の削除に失敗し`clean`のみ失敗（コード起因ではない）。直後の`compile`単体は正常に成功し、`target/classes`の内容（`schema.sql`・`application.properties`・`templates/dashboard/index.html`含む）が最新であることを確認済み。次回`clean compile`を試す場合は、実行中のjavaプロセスを止めた上でOneDriveの同期が落ち着いてから再試行することを推奨します。

## 6. 実機検証結果

MySQL起動確認・実データ（2026年度4件、2025年度1件）に対して以下を確認（テストに使った一時データ・印刷ステータス変更はすべて検証後に元へ戻し、最終状態は検証前と完全一致することを確認済み）。

- 既存DBに対して起動: `is_printed`未追加の状態からアプリ起動 → 動的SQLで自動追加 → 既存5件すべて残存・全件`is_printed=false`（未印刷）を確認。再起動時も冪等（エラーなし）。
- `/activity`: 初回アクセスは未印刷のみ表示（インジケーター表示）。`printedStatus=printed`/`all`切り替え、単体トグル、年度/月/補助区分/種別/事業名フィルタが従来どおり機能。全件表示で2026年度4件・16名・317,568円（個人雑費なし、旅行雑費あり）。
- 一括処理: 未選択時に一括削除・ステータス変更でエラー表示（500にならない）。複数選択での2-2/2-6プレビューが正しい合算値で表示。一括ステータス変更・一括削除が対象のみに適用され、削除後は絞り込み条件を維持して一覧へ戻ることを確認。
- 複製: 通常データの複製 → 編集画面遷移・バナー表示・参加者一致・金額0・`is_printed=false`を確認。複数Expense活動は複製中止を確認。
- ダッシュボード: `/`→`/dashboard`リダイレクト、年度切替、`/activity?printedStatus=all`との件数・金額の完全一致、予算未登録(0円)でも画面が壊れないことを確認。
- legacy/export回帰: `/export`直接アクセス、2-2/2-4/2-5/2-6個別preview、`/export/download`、`/export/year/setup`→preview→downloadが従来どおり動作。
- コンソールエラー: 検証した画面でJSエラーなし。

## 7. git状態・注意事項

**重要**: 作業ツリーには、私（CC）が触れていない以下の変更が別プロセス（共通マニュアル同期および他AI/Kazumaxによるdocs整理と推測）によりすでに存在していました。これらはルール上「作業中の他AI/ユーザー差分を勝手に戻さない」ため、**一切変更・commit対象に含めていません**。

- 変更: `.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `manuals/WORKFLOW_RULES.md`, `docs/handoff/WORKFLOW_RULES.md`
- 未追跡: `docs/handoff/STATUS_ARCHIVE.md`, `docs/proposals/P1_Air_to_Dex_Manual_Optimization.md`, `docs/proposals/P2_Dex_to_Air_Manual_Optimization_Response.md`, `manuals/STARTUP_CHECKLIST.md`

`docs/handoff/CURRENT_STATUS.md`は上記プロセスによってすでに大幅リストラクチャ済みだったため、その内容はそのまま維持し、「現在地」「次担当」節のみCycle 17完了内容に更新してcommitに含めています。

私のcommitに含めたファイル:
- Java: `ActivityController.java`, `BudgetAllocationController.java`, `ExportController.java`, `RootController.java`, `ProjectMapper.java`, `Project.java`, `ProjectService.java`, `DashboardController.java`(新規)
- リソース: `application.properties`, `mapper/ProjectMapper.xml`, `schema.sql`, `templates/activity/form.html`, `templates/activity/list.html`, `templates/layout.html`, `templates/dashboard/index.html`(新規)
- ドキュメント: `docs/handoff/CURRENT_STATUS.md`（現在地/次担当のみ更新）, `docs/handoff/P1_Air_Blueprint/cycle_17_ux_improvements.md`（既存・未コミットだったAir Blueprint。Cycle 17一式として同梱）, `docs/handoff/P2_Dex_to_CC/cycle_17_ux_improvements_instructions.md`（同・Dex指示書）, 本ファイル`docs/handoff/P3_CC_to_Dex/cycle_17_ux_improvements.md`

- commit hash: `2b84a32` (`[v2.4.9] Cycle 17: UX改善（印刷ステータス管理・一括処理・活動複製・ダッシュボード）`)
- push結果: `origin/main` へpush成功（`eedbb7b..2b84a32 HEAD -> main`）
- 最終`git status --short --untracked-files=all`（私のcommit後、上記「私が触れていない変更」のみが残存。想定どおり）:

```
 M .cursorrules
 M .gitignore
 M AGENTS.md
 M CLAUDE.md
 M docs/handoff/WORKFLOW_RULES.md
 M manuals/WORKFLOW_RULES.md
?? docs/handoff/STATUS_ARCHIVE.md
?? docs/proposals/P1_Air_to_Dex_Manual_Optimization.md
?? docs/proposals/P2_Dex_to_Air_Manual_Optimization_Response.md
?? manuals/STARTUP_CHECKLIST.md
```

これらはCycle 17実装と無関係な差分のため、私からは変更・commitしていません。Kazumaxまたは担当AIによる意図的な作業の可能性が高いですが、念のため状況確認をお願いします。

## 8. ＋α提案

`docs/proposals/CC_cycle_17_schema_alter_audit.md` に、schema.sqlの`ADD COLUMN IF NOT EXISTS`構文全体（Cycle 8由来分含む）の棚卸し提案を別途保存しています。
