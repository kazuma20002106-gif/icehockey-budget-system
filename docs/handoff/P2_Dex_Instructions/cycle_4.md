# [C4: Dex(P2) => CC(P3)]

Cycle 4 の実装をお願いします。対象は、過去データの交通手段マイグレーション、様式2-5/2-6の氏名列幅修正、簡易ユーザー設定とExcel自動印字、様式2-4の丸囲み座標微調整です。

現在の最新バージョンは `v1.8.7` です。実装完了時は `src/main/resources/application.properties` の `app.version` を `v1.8.8` に更新し、`.\mvnw compile` 後に `target/classes/application.properties` も `v1.8.8` になっていることを確認してください。

## ステータス

- Dex(P2) 作成完了
- CC(P3) 実装待ち

## 対象ファイル

- `src/main/resources/schema.sql`
- `src/main/resources/templates/activity/form.html`
- `src/main/resources/templates/activity/layout.html`
- `src/main/resources/templates/layout.html`
- `src/main/resources/static/css/style.css`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`

必要に応じて以下を新規作成・変更してください。

- `src/main/java/com/miyazaki/icehockey/budgetsystem/model/User.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/model/SystemSetting.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/UserMapper.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/SystemSettingMapper.java`
- `src/main/resources/mapper/UserMapper.xml`
- `src/main/resources/mapper/SystemSettingMapper.xml`
- ユーザー切替・登録・編集用の Controller / Service

## 事前注意

- 既存の活動入力、名簿連携、ルート距離取得、交通費自動計算、Excel出力仕様を壊さないでください。
- 作業ツリーには既存変更がある前提で、無関係な差分を戻さないでください。
- `schema.sql` は `spring.sql.init.mode=always` で毎回実行されるため、既存データを消す `DROP` は使わないでください。
- テーブル作成は `CREATE TABLE IF NOT EXISTS`、初期データは `INSERT IGNORE` または idempotent な `INSERT ... ON DUPLICATE KEY UPDATE` を使ってください。
- 実装後はローカルコミットで終わらせず、必ず `git push origin main` まで実行してください。
- Kazumax 向け完了報告には必ず「GitHubへプッシュしました」と明記してください。

## 実装要件

### 1. 過去データの交通手段マイグレーション

`expenses.transport_method` に残っている Cycle 3 以前の複合値を、新仕様の単体値へ更新してください。

対象変換:

- `電車・車` -> `電車`
- `航空機・バス` -> `航空機`

`schema.sql` の末尾などに、毎回実行されても安全な `UPDATE` を追加してください。

```sql
UPDATE expenses SET transport_method = '電車' WHERE transport_method = '電車・車';
UPDATE expenses SET transport_method = '航空機' WHERE transport_method = '航空機・バス';
```

注意:

- テーブル名は `expenses` です。`expense` ではありません。
- 文字化けした旧値が実DBに残っている可能性もあるため、現在のコード内の旧表示文字列と実データを確認し、必要なら同等の旧値も更新対象に含めてください。
- このマイグレーションは過去データ整合性確保が目的です。UIの選択肢は引き続き `航空機` / `バス` / `電車` / `自家用車` の4択にしてください。

### 2. 様式2-5/2-6の氏名欄の幅修正

活動日入力画面の氏名列で、長い名前が見切れないようにしてください。

対象:

- `#rosterTable` の氏名列
- `#expenseTable` の氏名列
- `.name-input`
- `.name-mirror`
- それらを含む `th` / `td`
- 行テンプレート内の同じ列

実装方針:

- `style.css` または `form.html` 内の既存 `<style>` に、氏名列専用のCSSを追加してください。
- 最低限 `min-width: 140px;` を確保してください。可能なら `160px` 程度を推奨します。
- `#expenseTable` は既に `min-width:1100px` があるため、全体幅とのバランスを崩さないようにしてください。
- readonly の `.name-mirror` も入力欄と同じ幅で表示されるようにしてください。

実装例:

```css
#rosterTable th.name-col,
#rosterTable td.name-col,
#expenseTable th.name-col,
#expenseTable td.name-col {
    min-width: 160px;
}

#rosterTable .name-input,
#expenseTable .name-mirror {
    min-width: 140px;
}
```

必要なら該当 `th` / `td` に `class="name-col"` を付与してください。

### 3. 簡易ログイン / 操作ユーザー設定

パスワードなしで、現在の操作ユーザーを切り替え・新規登録・編集できる仕組みを追加してください。ここで設定したユーザーは、様式2-4の記入責任者欄へ自動印字します。

#### DB

`schema.sql` に以下を追加してください。

`users` テーブル:

- `id INT AUTO_INCREMENT PRIMARY KEY`
- `name VARCHAR(100) NOT NULL`
- `phone_number VARCHAR(50) NOT NULL`
- 必要なら `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`

`system_settings` テーブル:

- `setting_key VARCHAR(100) PRIMARY KEY`
- `setting_value VARCHAR(255) NOT NULL`

初期データ:

- `users` に `齋藤 和明` / `090-5288-9928` を登録
- `system_settings` の `active_user_id` に、そのユーザーIDを設定

注意:

- 初期データは重複作成しないでください。
- 既存DBに既にユーザーがいる場合、現在の `active_user_id` を不用意に上書きしないでください。
- `system_settings.setting_value` は文字列でも構いませんが、Java側で安全に `Integer` へ変換してください。
- 初期ユーザーIDは固定値で決め打ちせず、登録済みの `齋藤 和明` を検索して取得してください。
- `active_user_id` は未設定の場合だけ初期ユーザーIDを入れる方針にしてください。既存値がある場合は維持してください。

#### Java / MyBatis

ユーザー取得・保存・更新・アクティブユーザー切替に必要な model / mapper / service / controller を追加してください。

最低限必要な操作:

- 全ユーザー一覧取得
- ID指定でユーザー取得
- 新規ユーザー登録
- 既存ユーザー編集
- `active_user_id` の取得
- `active_user_id` の更新
- 現在のアクティブユーザー取得

既存の MyBatis パターンに合わせ、XML mapper を使ってください。

#### UI

`layout.html` と `activity/layout.html` の両方に、現在の操作ユーザーが分かるUIを追加してください。

期待UI:

- ナビゲーションバー右側などに `現在の操作ユーザー: 齋藤 和明 ▼` のように表示
- ユーザーを選択するとアクティブユーザーが切り替わる
- 新規登録・編集ができる
- パスワード認証は不要

実装方法は、プルダウン、ボタン、Bootstrap modal のいずれでも構いません。既存のBootstrap 5に合わせてください。

注意:

- すべての画面で表示できるよう、共通 model attribute を使うのが望ましいです。
- `@ControllerAdvice` で `users` と `activeUser` を全画面へ渡す実装を推奨します。
- 登録・編集・切替後は、元の画面へ戻れるよう `Referer` または `redirect` パラメータを扱ってください。

### 4. 様式2-4への記入責任者・電話番号の自動印字

`ExcelExportService.java` の様式2-4出力で、現在のアクティブユーザーの氏名と電話番号を自動印字してください。

対象:

- 様式2-4の最下段「記入責任者氏名」
- 様式2-4の最下段「電話番号」

実装方針:

- `ExcelExportService` からアクティブユーザーを取得できるよう、ユーザー設定用の service / mapper を注入してください。
- `populate24Side()` 内で左側・右側それぞれに正しい列オフセットで印字してください。
- `colOffset == 0` と `colOffset == 17` の両方で出力されることを確認してください。
- アクティブユーザーが取得できない場合は空欄にするか、初期ユーザーへフォールバックしてください。

座標は最新の `src/main/resources/書類.xlsx` を実際に確認して決めてください。推測だけで固定しないでください。

### 5. 様式2-4の丸囲み座標微調整

`ExcelExportService.java` の `drawEllipse()` 呼び出し位置が、最新テンプレート上で正しい文字を囲めているか検証し、必要なら座標を微調整してください。

確認対象:

- 事業名: `強化練習`
- 事業名: `遠征試合`
- 種別: `成年男子`
- 種別: `成年女子`
- 種別: `少年男子`
- 種別: `少年女子`
- 左側フォームと右側フォームの両方

注意:

- 現在の座標は `populate24Side()` 内の `drawEllipse(sheet, row1, col1, row2, col2)` 呼び出しです。
- `colOffset == 17` の右側フォームでもズレないようにしてください。
- 最新テンプレートのセル位置を確認した上で変更してください。
- 可能なら、出力したExcelを開いて丸囲みが対象文字から外れていないことを確認してください。

## 検証項目

実装後、最低限以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS` になる。
- `src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` がどちらも `v1.8.8`。
- `schema.sql` を再実行しても既存データが消えない。
- `expenses.transport_method` の旧値 `電車・車` / `航空機・バス` が新値へ更新される。
- 活動日入力画面の様式2-5/2-6氏名欄で、長い氏名が見切れない。
- ナビゲーション上で現在の操作ユーザーが確認できる。
- 操作ユーザーを切り替えられる。
- 操作ユーザーを新規登録できる。
- 操作ユーザーの氏名・電話番号を編集できる。
- 様式2-4の「記入責任者氏名」「電話番号」にアクティブユーザー情報が印字される。
- 様式2-4の丸囲みが、左側・右側とも対象文字を正しく囲む。
- 既存の様式2-5/2-6出力、交通費計算、名簿連携が壊れていない。

## 完了時の必須作業

1. `app.version=v1.8.8` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.8` を確認する。
4. 変更をコミットする。
5. 必ず `git push origin main` を実行する。
6. P3 報告書を `docs/handoff/P3_CC_to_Dex/cycle_4.md` に作成する。
7. Kazumax 向けチャット報告の最後に「GitHubへプッシュしました」と明記する。

## P3 報告書に必ず書くこと

- 変更ファイル一覧
- 実装内容の要約
- DBマイグレーション内容
- 操作ユーザー設定の使い方
- 様式2-4の印字座標と丸囲み座標の確認結果
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に確認してほしい観点

## 提案

なし。

## 次の担当への合図（コピー用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_4.md を読んで、Cycle 4 の実装をお願いします。完了後は .\mvnw compile、app.version=v1.8.8 の src/target 同期確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_4.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
