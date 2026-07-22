[Cycle 18: Dex(P2) => CC(P3)]

# Cycle 18 schema.sql MySQL互換ALTER修正 CC向け最終指示書

## 判定

Air(P1) Blueprint `docs/handoff/P1_Air_Blueprint/cycle_18_schema_alter_audit.md` は、**条件付きで実装可**です。

今回の目的は、MySQL 8で非対応の `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` を、既にCycle 17の `is_printed` で採用した `INFORMATION_SCHEMA` + `PREPARE`/`EXECUTE` 方式へ置き換えることです。

## デクスクルー利用記録

今回のP2はDBスキーマ変更であり、VPS新規構築にも影響するため、デクスクルーを使用しました。

デクスクルーに任せた観点:
- 修正対象が3列で足りるか
- MySQL非互換DDLが他に残っていないか
- 動的SQL方式の注意点
- 検証条件に危険な手順が混ざっていないか

採用した主な指摘:
- 修正対象3列は妥当
- `is_printed` は既に安全化済み
- **本物DBでDROP検証は禁止**
- 列欠損・新規構築検証は、使い捨てDB環境、別コンテナ、またはバックアップ済み一時環境で行う

## 最重要安全ルール

### 1. Kazumaxの本物DBでDROPしない

Air案には「対象のテーブル（または列）をDROPした状態で起動」とありますが、これは本物DBでは危険です。

**禁止:**
- Kazumaxローカルの本物 `budget_system` DBで `DROP TABLE`
- Kazumaxローカルの本物 `budget_system` DBで `DROP COLUMN`
- 既存データを消す検証
- `git reset --hard`, `git clean`, `git restore .`, `git add .`

列欠損や新規構築の検証が必要な場合は、必ず以下のどれかで行ってください。

- 使い捨てのMySQL環境
- Docker等の一時MySQLコンテナ
- バックアップ取得済みの一時検証DB
- どうしても環境が作れない場合は、静的確認と既存DBの冪等起動確認に留め、未実施理由をP3報告に明記

注意:
`schema.sql` は `CREATE DATABASE budget_system` と `USE budget_system` を含みます。単に接続先DB名を変えるだけでは検証環境の分離にならない可能性があります。

### 2. 修正範囲を広げない

今回の修正対象は、以下の3列だけです。

- `projects.accommodation_nights`
- `project_summary_expenses.travel_misc_cost`
- `project_summary_expenses.travel_misc_days`

これ以外のDDL、テーブル構造、金額計算、mapper、Java、テンプレート、Excel出力ロジックは変更しないでください。

### 3. 既存データを壊さない

各列について、必ず「列が存在しない場合のみ追加」してください。

既に列が存在する場合は何もしないこと。型変更、既存値の上書き、デフォルト値での再更新は行わないでください。

## 実装内容

`src/main/resources/schema.sql` の以下3行を削除し、同じ場所または分かりやすい場所に動的SQL方式で置き換えてください。

```sql
ALTER TABLE projects ADD COLUMN IF NOT EXISTS accommodation_nights INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_cost INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_days INT DEFAULT 0;
```

実装パターンはCycle 17の `is_printed` と同じです。

### `projects.accommodation_nights`

```sql
SET @accommodation_nights_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects' AND COLUMN_NAME = 'accommodation_nights'
);
SET @add_accommodation_nights_sql = IF(@accommodation_nights_exists = 0,
    'ALTER TABLE projects ADD COLUMN accommodation_nights INT DEFAULT 0',
    'SELECT 1');
PREPARE add_accommodation_nights_stmt FROM @add_accommodation_nights_sql;
EXECUTE add_accommodation_nights_stmt;
DEALLOCATE PREPARE add_accommodation_nights_stmt;
```

### `project_summary_expenses.travel_misc_cost`

```sql
SET @travel_misc_cost_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_summary_expenses' AND COLUMN_NAME = 'travel_misc_cost'
);
SET @add_travel_misc_cost_sql = IF(@travel_misc_cost_exists = 0,
    'ALTER TABLE project_summary_expenses ADD COLUMN travel_misc_cost INT DEFAULT 0',
    'SELECT 1');
PREPARE add_travel_misc_cost_stmt FROM @add_travel_misc_cost_sql;
EXECUTE add_travel_misc_cost_stmt;
DEALLOCATE PREPARE add_travel_misc_cost_stmt;
```

### `project_summary_expenses.travel_misc_days`

```sql
SET @travel_misc_days_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_summary_expenses' AND COLUMN_NAME = 'travel_misc_days'
);
SET @add_travel_misc_days_sql = IF(@travel_misc_days_exists = 0,
    'ALTER TABLE project_summary_expenses ADD COLUMN travel_misc_days INT DEFAULT 0',
    'SELECT 1');
PREPARE add_travel_misc_days_stmt FROM @add_travel_misc_days_sql;
EXECUTE add_travel_misc_days_stmt;
DEALLOCATE PREPARE add_travel_misc_days_stmt;
```

変数名・statement名は衝突しないよう、列ごとに固有名にしてください。

## バージョン

今回は `src/main/resources/schema.sql` を変更するためコード変更扱いです。

- `src/main/resources/application.properties` の `app.version` を `v2.4.9` から `v2.5.0` へ更新してください。
- compile後、`target/classes/application.properties` も `v2.5.0` になっていることを確認してください。
- コミットメッセージ先頭は `[v2.5.0]` にしてください。

## 必須検証

### 静的確認

```powershell
rg -n "ADD COLUMN IF NOT EXISTS" src/main/resources/schema.sql
rg -n "INFORMATION_SCHEMA|PREPARE|DEALLOCATE|accommodation_nights|travel_misc_cost|travel_misc_days|is_printed" src/main/resources/schema.sql
```

期待:
- 実行DDLとしての `ADD COLUMN IF NOT EXISTS` が残っていないこと
- 3列と `is_printed` が `INFORMATION_SCHEMA` + `PREPARE`/`EXECUTE` 方式になっていること

### compile/version

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

期待:
- compile成功
- src/target ともに `app.version=v2.5.0`

### 既存DBの冪等確認

Kazumaxの既存DBでアプリを起動し、既に3列がある状態でも起動エラーにならないことを確認してください。

確認観点:
- 既存活動データが残っている
- 活動一覧が開く
- 活動編集画面で宿泊日数、旅行雑費単価、旅行雑費日数が従来どおり表示・保存できる
- 起動ログにschema初期化の構文エラーが出ない

### 新規DB・列欠損検証

可能なら、使い捨てMySQL環境で以下を確認してください。

- 空のMySQL環境でアプリを起動し、3列が作成される
- 再起動してもエラーなくスキップされる
- 活動新規作成・保存ができる

ただし、Kazumaxの本物DBではDROP禁止です。

使い捨て環境を作れない場合:
- 実施不可としてよい
- その場合は、P3報告に「本物DB保護のため新規DB/列欠損検証は未実施。静的確認と既存DB冪等確認で代替」と明記してください。

### git状態

```powershell
git status --short --untracked-files=all
git diff --stat
```

P3報告に以下を必ず書いてください。

- 変更ファイル一覧
- commit hash
- push結果
- `git status --short --untracked-files=all` の最終結果
- 既存のマニュアル系未コミット差分が残る場合は、Cycle 18本体との差分を分けて説明

## P3報告書

保存先:

```text
docs/handoff/P3_CC_to_Dex/cycle_18_schema_alter_audit.md
```

必ず含めること:
- Air Blueprintから採用した内容
- Dex(P2)で強化した安全ルール
- 本物DBでDROPしなかったこと
- 3列の `ADD COLUMN IF NOT EXISTS` を動的SQLへ置き換えたこと
- 実行DDLとしての `ADD COLUMN IF NOT EXISTS` が残っていないこと
- 既存DB冪等確認の結果
- 新規DB/列欠損検証の結果、または未実施理由
- compile/version確認結果
- git状態、commit、push結果

## CCへのトリガー文

```text
まず AGENTS.md、docs/handoff/CURRENT_STATUS.md、manuals/STARTUP_CHECKLIST.md を読んで、現在地・次担当・今回読むべきファイルを確認して。
このプロジェクトに docs/PROJECT_RULES.md や docs/handoff/WORKFLOW_RULES.md がある場合は、それも読んで危険領域と完了時ルールを確認して。
今回指定されたhandoffファイルを読み、作業前に「読了報告」と「詳細マニュアル追加読みの有無・理由」を短く出してから作業して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

今回はDB・schema.sql・既存データに関わる危険タスクのため、manuals/AI_TEAM_WORKFLOW.md と manuals/WORKFLOW_RULES.md も追加で読んでから進めて。

CCへ：
Dex(P2)がCycle 18 schema.sql MySQL互換ALTER修正の事前監査を完了し、最終実装指示書を作成しました。
docs/handoff/P2_Dex_to_CC/cycle_18_schema_alter_audit_instructions.md を読んで、CC(P3)として実装してください。

最重要:
- Kazumaxの本物DBでDROP TABLE / DROP COLUMN は絶対にしないでください。
- 修正対象は schema.sql の3列だけです: accommodation_nights, travel_misc_cost, travel_misc_days。
- 既存データを壊さず、列がない場合だけ追加する動的SQL方式にしてください。
- app.version は v2.5.0 に更新し、compile と target/classes の同期を確認してください。

完了後は docs/handoff/P3_CC_to_Dex/cycle_18_schema_alter_audit.md にP3報告を保存し、Dex(P4)レビュー依頼文をチャットに出してください。
```
