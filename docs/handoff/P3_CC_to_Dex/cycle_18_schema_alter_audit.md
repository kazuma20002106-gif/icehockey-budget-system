[C1: CC(P3) ⇒ Dex(P4)]

# Cycle 18 schema.sql MySQL互換ALTER修正 CC実装完了報告

対象指示書: `docs/handoff/P2_Dex_to_CC/cycle_18_schema_alter_audit_instructions.md`

## 1. Air Blueprintから採用した内容

- 修正範囲は`schema.sql`全体を点検した結果どおり、以下3列のみ。
  - `projects.accommodation_nights`
  - `project_summary_expenses.travel_misc_cost`
  - `project_summary_expenses.travel_misc_days`
- Cycle 17の`is_printed`で確立した「`INFORMATION_SCHEMA.COLUMNS`存在確認＋`PREPARE`/`EXECUTE`動的SQL」パターンをそのまま適用。

## 2. Dex(P2)で強化された安全ルールへの対応

- **Kazumaxの本物DB（`budget_system`）でのDROPは一切実行していません。** DROP TABLE / DROP COLUMNとも未実行。
- 修正対象を3列のみに限定し、他のDDL・mapper・Java・テンプレート・Excel出力ロジックは変更していません。
- 各列は「存在しない場合のみ追加」する条件分岐（`IF(@xxx_exists = 0, 'ALTER TABLE ...', 'SELECT 1')`）で実装。既存列がある場合は`SELECT 1`（無害な文）が実行されるだけで、型変更・値の上書き・再定義は一切発生しません。
- 変数名・PREPARE文の名前は列ごとに固有（`@accommodation_nights_exists`/`add_accommodation_nights_stmt`など）にし、Cycle17の`is_printed`分と衝突しないようにしています。

## 3. 実装内容

`src/main/resources/schema.sql`の以下3行（Cycle 8由来）を削除し、動的SQL方式に置き換えました。

```sql
ALTER TABLE projects ADD COLUMN IF NOT EXISTS accommodation_nights INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_cost INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_days INT DEFAULT 0;
```

置き換え後は、指示書に記載のパターンどおり3列それぞれに`SET`→`PREPARE`→`EXECUTE`→`DEALLOCATE`のブロックを用意しました（`schema.sql`の該当箇所を参照）。指示書の実装例とほぼ同一で、変数名のみプロジェクトの命名（`accommodation_nights_exists`など）に合わせています。

## 4. 実行DDLとしての`ADD COLUMN IF NOT EXISTS`が残っていないこと

```
rg -n "ADD COLUMN IF NOT EXISTS" src/main/resources/schema.sql
```

結果: 2件ヒットしましたが、いずれも**コメント行**（3列の修正理由コメント、およびCycle17の`is_printed`の既存コメント）のみで、実行文としては残っていません。

```
rg -n "INFORMATION_SCHEMA|PREPARE|DEALLOCATE|accommodation_nights|travel_misc_cost|travel_misc_days|is_printed" src/main/resources/schema.sql
```

3列と`is_printed`のいずれも`INFORMATION_SCHEMA`＋`PREPARE`/`EXECUTE`方式になっていることを確認済み。

## 5. 既存DB冪等確認の結果

Kazumaxの実DB（`budget_system`、3列とも既存）に対してアプリを起動しました。

- 起動ログに schema初期化のSQL構文エラーなし（`SQLSyntaxError`等の文字列で確認、ヒットなし）。
- `/activity?year=2026&printedStatus=all` で、Cycle 17終了時と同じ既存活動4件・16名・決算書計上額317,568円が変わらず表示されることを確認（データ消失なし）。
- `/activity/13/edit` を開き、`accommodationNights=2`、`travelMiscCost=40000`、`travelMiscDays=1` が従来どおり保存値のまま表示されることを確認（3列とも読み書き経路に影響なし）。

## 6. 新規DB/列欠損検証の結果

Kazumaxの本物DBには一切触れず、**同じMySQLサーバー上に本物とは別名の使い捨てDB（`cycle18_scratch_verify`）を作成**して検証しました（Docker等の隔離環境は本機に無かったため、この方式を採用）。

手順:
1. 使い捨てDB`cycle18_scratch_verify`を新規作成し、`projects`/`project_summary_expenses`を3列が存在しない最小構成で作成。
2. データ1件を投入。
3. schema.sqlに追加した3列分の動的SQLブロックをそのまま1回目実行 → 3列とも新規追加されたことを確認（`INFORMATION_SCHEMA`照会で`false`→`true`に変化）。投入済みデータ（1件）が消えていないことも確認。
4. 同じブロックを2回目実行 → エラーなく完了（冪等性確認）。
5. 検証後、使い捨てDB`cycle18_scratch_verify`を`DROP DATABASE`で削除して後片付け。本物`budget_system`は最初から最後まで一切操作していません。

結果: 列欠損状態からの新規追加、データ保持、冪等な再実行のいずれも問題なし。

## 7. compile/version確認結果

```
src\main\resources\application.properties:10:app.version=v2.5.0
target\classes\application.properties:10:app.version=v2.5.0
```

`.\mvnw.cmd -q -DskipTests compile` は成功。

## 8. git状態・commit・push結果

私が変更したのは以下の2ファイルのみです（Cycle 18本体）。

- `src/main/resources/schema.sql`
- `src/main/resources/application.properties`

作業ツリーには、Cycle 18とは無関係な既存の未コミット差分（マニュアル同期・docs整理と推測されるもの）が引き続き残っています。Cycle 17のP3/P4報告でも同様の状態が記録されており、今回も変更・commit対象に含めていません。

- 変更: `.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/WORKFLOW_RULES.md`
- 未追跡: `docs/handoff/P1_Air_Blueprint/cycle_18_schema_alter_audit.md`（Air Blueprint。今回のCycle 18一式として同梱commit対象とする）, `docs/handoff/P2_Dex_to_CC/cycle_18_schema_alter_audit_instructions.md`（Dex指示書。同）, `docs/handoff/P4_Dex_Review/cycle_17_ux_improvements.md`（Cycle 17のP4 OKレビュー。私の変更ではないため対象外）, `docs/handoff/STATUS_ARCHIVE.md`, `docs/handoff/manual_optimization_final.md`, `docs/proposals/P1_Air_to_Dex_Manual_Optimization.md`, `docs/proposals/P2_Dex_to_Air_Manual_Optimization_Response.md`, `manuals/STARTUP_CHECKLIST.md`

- commit hash: `d5d96cf` (`[v2.5.0] Cycle 18: schema.sqlのMySQL互換ALTER修正（accommodation_nights等3列）`)
- push結果: `origin/main` へpush成功（`0eb71ed..d5d96cf HEAD -> main`）
- 最終`git status --short --untracked-files=all`（私のcommit後、上記「私が触れていない変更」のみが残存。想定どおり）:

```
 M .cursorrules
 M .gitignore
 M AGENTS.md
 M CLAUDE.md
 M docs/handoff/WORKFLOW_RULES.md
 M manuals/WORKFLOW_RULES.md
?? docs/handoff/P4_Dex_Review/cycle_17_ux_improvements.md
?? docs/handoff/STATUS_ARCHIVE.md
?? docs/handoff/manual_optimization_final.md
?? docs/proposals/P1_Air_to_Dex_Manual_Optimization.md
?? docs/proposals/P2_Dex_to_Air_Manual_Optimization_Response.md
?? manuals/STARTUP_CHECKLIST.md
```

`docs/handoff/P4_Dex_Review/cycle_17_ux_improvements.md`はDexが作成したCycle 17のP4 OKレビューであり、私（CC）の担当外のためcommit対象に含めていません。それ以外はCycle 17完了報告時から引き続き存在するマニュアル同期・docs整理関連の差分です。
