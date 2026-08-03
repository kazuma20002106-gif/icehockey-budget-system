[C21: CC(P3) Take3 ⇒ Dex(P4)]

# Cycle 21 Take3 CC実装報告（P1-3 UI保存修正 + P1-4 binlog全体照合）

## 1. 対象範囲

Dex(P4)差し戻し（`docs/handoff/P4_Rollback/cycle_21_comprehensive_safety_and_ui_take2.md`）のP1-3/P1-4のみを対応。金額計算・Excel・出力URL・雑費関連は無変更（`ActivityController.java`/`ExportController.java`/`ExcelExportService.java`/`書類.xlsx`/mapper/schema.sqlに一切差分なし）。

## 2. P1-3修正: 候補外の事業名・NULL文章欄が保存で破壊される問題

### 根本原因

1. `activity/form.html`の「事業名」`<select>`は`強化練習`/`遠征試合`の固定2択のみで構成されていた。既存活動の実際の事業名がこの2択に一致しない場合（例: `【テスト出力】強化練習`のような自由記述値）、編集画面はどの選択肢も選択されない状態で表示され、無編集で保存すると空文字が送信されて実データを上書きしていた。**これが実際にactivity id=1で発生した事故の直接原因。**
2. 「事業の成果」（`project.projectOutcome`）の`<textarea>`は、DB値がNULLの場合に`th:text`で既定文言`技術力・チーム連携の向上`を**textareaの実値として**書き込んでいた。これは単なる入力ヒントの意図だったと思われるが、実装上は実値として送信されるため、無編集保存でNULLがこの文言に上書きされていた。**事故時にproject_outcomeがNULLからこの文言へ変化した原因もこれと断定できる。**

### 修正内容

- `activity/form.html`の事業名`<select>`: 固定2択に加え、既存値が候補外・非null・非空の場合はその値をそのまま「選択済みの追加option」として表示するよう変更。新規活動作成時（`project.name`が未設定）は追加optionは発火せず、従来どおり2択のみ。
- 同ファイルの`project.projectOutcome`の`<textarea>`: `th:text`の既定文言埋め込みを削除し、`placeholder`属性（未入力時のヒント表示のみ・実値には影響しない）へ変更。
- `ProjectService.saveProject()`冒頭に、`scheduleContent`/`projectOutcome`が空白のみの場合はNULLへ正規化する処理を追加。既存の複数Expenseガード・projects保存・参加者/Expense再作成ロジックより前に配置。これにより、HTMLのtextareaが「未入力」を空文字でしか表現できない制約があっても、DBのNULLが保存のたびに空文字へ変わることを防いだ。
- `schedule_content`（日程及び内容）は元々`th:text`に既定文言を埋め込んでおらず、同種のバグは存在しなかった（CCクルーAで確認済み）。

### 検証方法と結果

**自動テスト**（`Cycle21SafetyAndTransactionTest.saveProject_blankScheduleAndOutcome_normalizedToNull_notEmptyString`）: 候補外の事業名で1回目保存→実値設定→2回目保存で空文字/空白のみを送信し、事業名が変わらないこと・両文章欄がNULLに正規化されること（空文字のままではないこと）を確認。

**実機ブラウザ確認（テスト専用の新規活動のみ使用。本物活動には一切触れていない）**:

1. `POST /activity/save`でテスト専用の新規活動を作成（`project.name=強化練習`、`location_venue=CC_TEST_VENUE_TAKE3`で識別可能なマーカーを付与）。
2. 作成された行（id=90、自分で作成したことを確認済み）に対してのみ、`name`を候補外の値`【CCテスト用・候補外事業名】`へ直接更新（本物データではないテスト専用行への操作）。
3. `/activity/90/edit`をブラウザで開き、JSで事業名selectの選択状態とproject_outcome textareaの実値を確認:
   - 事業名selectの値・選択済みoptionが`【CCテスト用・候補外事業名】`と正しく一致（修正前は空文字/未選択だったはず）。
   - `project_outcome`のtextarea実値は空（`placeholder`のみ表示、実値には影響なし）。
4. フォームを**実際のsubmitボタン相当の`requestSubmit()`**（HTML5検証を経由する正規の送信経路）で送信し、活動一覧へ正常にリダイレクトされることを確認。
5. DB照合: `name`/`schedule_content`/`project_outcome`/`event_date`/`location_venue`すべて保存前と完全一致（事業名が空文字化しない、project_outcomeが既定文言に変化しない）。
6. テスト専用データ（project id=90、member「CCTestUser」）を削除し、DBを事前状態（projects=9件、expenses=46件、participants=46件、members=9件）へ完全に復元したことを確認。

## 3. P1-4調査: 事故トランザクション全体のbinlog照合

### 調査方法

MySQLの`binlog_format=ROW`が有効であることを利用し、`mysqlbinlog -vv --read-from-remote-server`で該当バイナリログ（`MSI-bin.000022`）の事故トランザクション（2026-08-03 14:51:02〜14:51:03開始、Xid=21283）を**BEGIN〜COMMITまで完全に読み取り**、`projects`・`project_participants`・`expenses`・`project_summary_expenses`・`members`のすべてのテーブルへの影響を確認した（読取専用、DBへの書込みは一切行っていない）。

### 判明した事実（トランザクション全体）

| テーブル | 変化内容 |
|---|---|
| `projects` | id=1が1行UPDATE。`name`/`schedule_content`/`project_outcome`の3列のみ変化（他9列は不変）。※本報告6章の復旧で解決済み |
| `project_participants` | project_id=1の旧2件（id=1, id=2、member_id=1と4、is_accommodated=0）がDELETE→新2件（id=167, id=168、member_id=1と4、is_accommodated=0）がINSERT。**member_id・is_accommodatedの内容は完全一致し、行IDだけが再割り当てされた** |
| `expenses` | このトランザクション内に`expenses`へのDELETE（cascade delete含む）は**一切記録されていない**。新2件（id=173, id=174）がINSERTされ、id=173は交通費/宿泊費/雑費=0・その他NULL、id=174は交通費=0・宿泊費/雑費=NULL・その他NULLという空のデフォルト値だった |
| `project_summary_expenses` | このトランザクション内にTable_mapイベント自体が存在せず、**変更なし**。現在値（project_id=1、rental_cost=15000、supplies_cost=2000、parking_cost=500等）も事故前と同一と確認 |
| `members` | このトランザクション内にTable_mapイベント自体が存在せず、**変更なし**。member id=1（長友　繁）・id=4（齋藤　豊光）の内容も不変 |

### 結論

`expenses`へのDELETEイベントが一切存在しないことから、**事故前の旧参加者（id=1, id=2）にはそもそもExpenseレコードが0件だった**と判断できる。よって、この事故トランザクション単体では実質的な金額データの損失はなく、参加者・Expenseの行IDが再割り当てされただけである。`project_summary_expenses`（借用料15,000円等の実データ）は無傷。

### Expense総数「45件→46件」の不整合について

Dex(P4)が指摘した、前回P4読取（45件）と今回P4読取（46件）の差について、binlog全体を走査したところ、**事故トランザクション以外に、CC(P3)自身が別途作成・削除したテスト専用データ**（project「CC_TEST_VENUE_TAKE3」、member「CCTestUser」、2026-08-03 15:40頃）がexpensesへ2件挿入していたことが判明した（本報告2章の実機確認で作成し、確認後に削除済み）。Dexの2回の読取タイミングの間にこのテストデータが一時的に存在していたことが、45→46の差の説明として最も可能性が高い（CCクルーBによる独立確認）。断定はできないが、「未検出の事故関連トランザクション」である可能性は低いと判断する。現時点でこのテストデータは完全に削除済みであり、DBは正しい状態（本報告2章6番で確認した件数）に復帰している。

## 4. CCクルー3観点の補助レビュー結果

CCクルー利用: **必須**（Dex指示どおり実施）。

- **CCクルーA（候補外事業名・NULL文章欄の保存修正担当）**: 「問題なし」。form.htmlの追加option条件（候補外・非null・非空のみ発火、新規活動では発火しない）、project_outcomeのplaceholder化、ProjectService.javaのNULL正規化処理の配置、schedule_contentに同種バグがないこと、追加テストの妥当性を確認。
- **CCクルーB（インシデントbinlog解析のセカンドチェック担当）**: 「同意」（一部補足）。独自に同じbinlogトランザクションを再取得し、CC(P3)の解析結果と完全一致することを確認。45→46の不整合について、CC(P3)自身のテストデータ作成が原因である可能性が高いことを特定（本報告3章に反映済み）。expenses新2件の値について「交通費/宿泊費/雑費=0」との記述は厳密には「0またはNULLの空デフォルト値」であるべきという軽微な訂正指摘があり、本報告のテーブル記述に反映した。金額データの実質損失なしという結論は妥当と判断。
- **CCクルーC（回帰・不可触領域担当）**: 「問題なし」。変更ファイルが`ProjectService.java`/`form.html`/テスト/`application.properties`に限定されていること、ExcelExportService/xlsx/mapper/schema.sql/Controller層への無差分、テスト全成功、バージョン同期を確認。

3クルーとも重大な指摘なし。採用/不採用判断: CCクルーBの軽微な訂正（expenses新2件の値の厳密な記述）を本報告書に反映済み。

## 5. compile/version

```
.\mvnw.cmd -q -DskipTests compile
.\mvnw.cmd -q test
```
コンパイル成功。テスト: `BudgetSystemApplicationTests`(1) + `Cycle21SafetyAndTransactionTest`(9) + `ExcelExportServiceTest`(2) = **12件、失敗・エラー0件**。

```
app.version: src/main/resources/application.properties = v2.6.2
             target/classes/application.properties     = v2.6.2
```
同期確認済み。

## 6. DB件数照合（テスト・実機確認の前後）

| 時点 | projects | expenses | participants | members |
|---|---|---|---|---|
| Take3作業開始時 | 9 | 46 | 46 | 9 |
| 自動テスト実行後 | 9 | 46 | 46 | 9 |
| 実機確認（テスト活動作成直後） | 10（一時） | 47（一時） | 47（一時） | 10（一時） |
| テストデータ削除後（最終） | 9 | 46 | 46 | 9 |

`is_printed`状態（id10=1, id22=1, 他=0）はTake3全体を通じて不変。

## 7. commit / push

後述（本報告書保存後にcommit・push、hashを追記）。

## 8. 最終git status

Take3対象ファイル（`src/main/resources/templates/activity/form.html`, `src/main/java/.../service/ProjectService.java`, `src/test/java/.../Cycle21SafetyAndTransactionTest.java`, `src/main/resources/application.properties`, 本報告書, `docs/handoff/CURRENT_STATUS.md`）のみをstage・commitする。Take3対象外の差分（`.cursorrules`等の共通マニュアル、他AIのhandoff/proposals、`.claude/launch.json`、`tmp/`）には一切触れていない。
