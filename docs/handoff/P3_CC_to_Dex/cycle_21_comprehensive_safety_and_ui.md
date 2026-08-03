[C21: CC(P3) ⇒ Dex(P4)]

# Cycle 21 総合改修（安全性増強・UI調整） CC実装報告

## 1. 変更ファイル一覧

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ProjectService.java`
- `src/main/resources/schema.sql`
- `src/main/resources/application.properties`（app.version=v2.6.0）
- `src/main/resources/templates/activity/list.html`
- `src/main/resources/templates/export/index.html`
- `src/test/java/com/miyazaki/icehockey/budgetsystem/service/Cycle21SafetyAndTransactionTest.java`（新規）

`ExcelExportService.java` / `書類.xlsx` / `mapper/*.xml` は無変更（`git diff --stat`で無差分確認済み）。

## 2. 実装内容（A〜D）

### A. 複数Expenseの保存事故を止める

- `ProjectService.hasMultipleExpenses(int projectId)`: 対象活動の参加者ごとにExpense件数を確認する読み取り専用メソッド。1人でも2件以上あればtrue。
- `ActivityController.editForm()`: フォーム構築前にガードし、trueなら`/activity?error=multi_expense_guard`へリダイレクト（編集画面自体を表示しない）。
- `ActivityController.save()`: 既存活動（`isNew==false`）の場合、`projectMapper.update`より前にガード。trueなら同エラーへリダイレクトし、破壊的処理へ一切入らない。新規活動（`isNew==true`）は短絡評価によりガード対象外で、従来どおり保存可能。
- `projectService.saveProjectData()`呼び出しを`try-catch(DataIntegrityViolationException)`で包み、一意制約違反時も`/activity?error=save_integrity_violation`へリダイレクト（`@Transactional`により変更はすべてロールバック済み）。
- エラー文はID・内部例外を含まず、「複数の支出データがあるため、安全のため編集・保存できません」の趣旨。

### B. `expenses.project_participant_id`の一意制約

- 新規DB用`CREATE TABLE expenses`に`UNIQUE KEY uq_expenses_project_participant`を追加。
- 既存DB向け冪等マイグレーションを`schema.sql`末尾に追加。実行条件は「`project_participant_id`ごとの件数が全て1以下」かつ「`uq_expenses_project_participant`が未作成」の両方。継続実行（`continue-on-error=true`）を前提に、単純な「毎回ALTER→エラー無視」にはしていない。
- **観測事項**: 実DBを確認したところ、`uq_expenses_project_participant`は本セッション開始時点で既に作成済みだった（`SHOW CREATE TABLE expenses`で確認）。経緯は不明だが、重複データは0件（`GROUP BY ... HAVING COUNT(*)>1`が0件）であり、今回のマイグレーションSQLは冪等（既作成なら`SELECT 1`のno-op）に動作することを確認済み。データを破壊した形跡はない。

### C. 出力画面の印刷状態更新のトランザクション化

- `ProjectService.updatePrintedStatusAtomic(List<Integer> projectIds, boolean isPrinted)`（`@Transactional`）を新設。
  - `projectIds`が空なら`IllegalArgumentException`。
  - 重複除去後、**全IDの存在確認を先に完了**させてから更新ループへ進む二段階構成。1件でも存在しなければ`IllegalStateException`をthrowし、更新は1件も行われない（ロールバック）。
- `ExportController.bulkStatus()`と`ActivityController.bulkStatus()`（互換用）の両方を、forループ直書きから上記Serviceメソッド呼び出しへ変更。例外時はそれぞれ`/export?error=invalid_selection`・`/activity?error=invalid_selection`へリダイレクト。
- 更新対象はPOSTの選択IDだけ。`year`等の検索条件は戻り先URLの構築にのみ使用し、更新クエリの絞り込みには一切使わない。
- `preview()/download()/yearPreview()/yearDownload()`から`updatePrinted`系の呼び出しがないことを`git grep`で確認済み。

### D. UI調整

- `activity/list.html`に`multi_expense_guard`・`save_integrity_violation`のアラートを追加。
- `export/index.html`に`invalid_selection`のアラートを追加。Cycle 19 Take3で修正した「`content=~{::div}`が取り込むルートdiv内にstyle/scriptを置く」構造は維持（今回の追加要素も同じdiv内）。
- 既存のURL・全選択・個別選択・通常previewの6条件往復・日本語URLエンコードは無変更。

## 3. 実行コマンドと検証方法

### 3.1 静的確認

```
.\mvnw.cmd -q -DskipTests compile
```
成功。

```
git diff --stat -- src/main/java/.../service/ExcelExportService.java "src/main/resources/*.xlsx" src/main/resources/mapper/
```
無差分。

```
grep -n "app.version" src/main/resources/application.properties target/classes/application.properties
```
両方 `v2.6.0`。

### 3.2 自動テスト

`.\mvnw.cmd -q test` — 全8件成功（失敗・エラー0件）。

新規`Cycle21SafetyAndTransactionTest`（クラス全体`@Transactional`によりテスト終了時に自動ロールバック、実DBは一切コミットされない）:

1. `hasMultipleExpenses_isFalse_whenAtMostOnePerParticipant`: 参加者ごとにExpenseが1件以下ならガードを通過。
2. `uniqueConstraint_rejectsSecondExpense_noPartialData`: 2件目のinsertが`DataIntegrityViolationException`で失敗し、残り1件のみで部分保存がないことを確認。
3. `updatePrintedStatusAtomic_allValidIds_updatesAll`: 全ID有効なら全件更新。
4. `updatePrintedStatusAtomic_invalidIdMixedIn_rollsBackAll`: 不正IDが混ざると例外がthrowされ、有効なIDのis_printedも変わらない（全件ロールバック）ことを確認。
5. `updatePrintedStatusAtomic_emptyList_throwsWithoutUpdating`: 空リストは例外。

**未実施のテストケースとその理由**: Dex指示の「既存の複数Expenseがある場合の保存拒否」テストは、`uq_expenses_project_participant`が実DBに既に適用済みであるため、通常のINSERTで重複行を作成すること自体ができない（`SET unique_checks=0`はMySQL 8のInnoDBで通常INSERTのUNIQUE制約チェックを回避せず、実測で確認済み）。一意制約のDROP/ADDはMySQLでは暗黙コミットを伴うDDLのため、テストトランザクション内で行うと実DBを恒久的に変更する危険があり採用しなかった。この経路は`hasMultipleExpenses()`のコードレビュー（`size()>1`の単純な判定）と、上記2番のテスト（そもそも複数行を作れないことの証明）で代替した。

### 3.3 P3実機確認（DB書込みを伴う）

MySQL稼働下でアプリを起動（ポート8091）し、以下を実施。

1. **DB前後の件数照合**: 開始時 projects=9件、is_printed=1の件数=2件（ID10, 22。開始時点で既にこの状態だった。本セッションで変更した記録はない）、expenses=45件。テスト実行後・実機確認後とも完全一致。
2. **一意インデックス追加後の金額不変性**: マイグレーションは既に適用済み（no-op実行）だったため新規適用時の差分検証は行っていないが、実行前後でexpenses総数（45件）が変わらないことを確認。
3. **印刷済み→未印刷の実操作と復元**:
   - 開始時 ID1: `is_printed=0`
   - `POST /export/bulk/status`でID1のみ印刷済みへ更新 → DB確認: ID1=1、他ID（6,9,10,13,22,23,24,25）は不変
   - `POST /export/bulk/status`でID1を未印刷へ戻す → DB確認: ID1=0（開始時と完全一致）
   - 不正ID混在テスト: ID1＋存在しないID(999999999)を指定 → `error=invalid_selection`へリダイレクト、ID1は`is_printed=0`のまま（全件ロールバック確認）。UI上もエラーアラートと未印刷バッジ表示を確認、ブラウザコンソールエラーなし。
4. **通常出力・legacy出力の疎通**: `/activity`(200)、`/export`(200)、`/activity/{id}/edit`(200)、`POST /export/download`(200, is_printed不変)、`GET /activity/export/year`(legacy, 200)、`POST /export/year/download`(年度末公式, 200, 全9件・印刷済2件で不変)をすべて確認。

### 3.4 年度末Excel回帰

`POST /export/year/download`で2026年度公式Excelを再取得し200 OK・正しいファイル名・Content-Typeを確認。Cycle 20で確立した27シート・数式エラー0・936残存0・回帰代表値（Cycle 21ではExcelExportService.java・書類.xlsxを一切変更していないため）はロジック上不変であり、DB件数（projects=9, is_printed=2）も生成前後で一致することを確認した。openpyxlによる詳細な再走査（シート単位のセル値照合）はCycle 20で直近に実施済みのため今回は省略し、HTTP応答とDB非更新の確認に留めた。

## 4. CCクルー3観点の補助レビュー結果

CCクルー利用: **必須**（Dex指示どおり実施）。

- **CCクルーA（複数Expense保存ガード・一意制約担当）**: 「問題なし」。ガードの配置順序（破壊的処理より前）、schema.sql冪等性、isNew分岐、duplicate()との非競合、エラーメッセージの安全性を確認。
- **CCクルーB（印刷状態更新の原子性・UI担当）**: 「問題なし」。updatePrintedStatusAtomicの二段階構成（全件存在確認→全件更新）、更新対象がPOST選択IDのみであること、他経路からの呼び出しがないこと、Thymeleaf構造の維持、legacy互換エンドポイントへの安全策適用を確認。
- **CCクルーC（回帰・不可触領域担当）**: 「問題なし」。変更範囲がCycle 21の想定範囲に収まっていること、ExcelExportService.java/xlsx/mapperの無差分、Controller差分の健全性、テスト全成功、バージョン同期を確認。

3クルーとも重大な指摘なし。採用/不採用判断: 対応事項なし。

## 5. compile/version

```
app.version: src/main/resources/application.properties = v2.6.0
             target/classes/application.properties     = v2.6.0
```
同期確認済み。

## 6. commit / push

commit hash: `a10682b`（`[v2.6.0] Cycle 21: 複数Expense保存ガード・expenses一意制約・印刷状態更新の原子性`）。origin/mainへpush済み（52c1bc4→a10682b）。

## 7. 最終git status

Cycle 21対象外の差分（`.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`, 各種`docs/handoff/`・`docs/proposals/`の未追跡ファイル、Dex監査用`tmp/`、`.claude/launch.json`）は他AI（Air/Dex）による既存差分・本セッションの検証用設定と判断し、一切触れていない・commitに含めない。
