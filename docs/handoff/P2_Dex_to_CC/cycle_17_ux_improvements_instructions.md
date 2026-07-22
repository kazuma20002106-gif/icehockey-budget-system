[Cycle 17: Dex(P2) => CC(P3)]

# Cycle 17 UX改善 CC向け最終指示書

## 判定

Air(P1) Blueprint `docs/handoff/P1_Air_Blueprint/cycle_17_ux_improvements.md` は、**条件付きで実装可**。

ただし、今回の範囲は DB、一覧画面、一括削除、Excel導線、活動複製、ダッシュボードを同時に触るため、そのまま一気に実装すると事故りやすいです。CC(P3)はこの指示書を優先し、以下の安全柵を必ず守ってください。

## デクスクルー利用記録

今回のP2は高リスク監査のため、デクスクルーを使用しました。

理由:
- DBスキーマ変更と既存データ保持が絡む
- 一括削除と活動複製がデータ破壊・データ重複に直結する
- `/activity`、legacy `/export`、年度末Excel、予算管理の金額整合性に影響しうる

デクスクルーからの主要指摘と採用結果:
- legacy `/export` 削除禁止: 採用
- `is_printed` は既存DB向け `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` が必須: 採用
- 複製で金額までコピーすると決算額・ダッシュボードが二重計上される: 採用し、金額コピー禁止へ変更
- ダッシュボード使用額はCycle 15の決算書計上額ロジックと完全一致が必須: 採用
- 印刷ステータスは手動管理に限定し、Excel preview/downloadで自動変更しない: 採用
- 一括削除はPOST、件数確認、transaction、未選択ガード必須: 採用

## 最重要の安全方針

1. **legacy `/export` 導線は削除しない**

過去サイクルで、legacy「提出データ出力・集計」画面は現役導線と確認済みです。Air案には「一括出力に置き換えられるため不要」とありますが、今回のCycle 17では `ExportController`、`templates/export/*`、`/export` ルートを削除・無効化しないでください。

ナビゲーション上の見せ方を調整する場合でも、直接URL `/export` は従来どおり開けること。既存の preview/download 動作も壊さないこと。

2. **金額計算はCycle 15の方針を維持する**

`/activity` の一覧合計は「決算書計上額」です。個人雑費 `miscellaneousCost` は含めません。

含めるもの:
- 参加者ごとの交通費 `transportCost`
- 参加者ごとの宿泊費 `accommodationCost`
- 事業サマリの借用料、需用費、駐車場、報償費、役務費
- 旅行雑費 `travelMiscCost * 参加人数 * travelMiscDays`

含めないもの:
- 個人雑費 `miscellaneousCost`

ダッシュボードの使用額も、この `/activity` の「決算書計上額」と同じ計算にしてください。`miscellaneousCost` と `travelMiscCost` を混ぜないでください。

3. **Excel出力時に自動で「印刷済み」へ変更しない**

出力ボタンを押しただけでは、実際に印刷したかどうかは分かりません。今回の印刷ステータスは、ユーザーが明示的に「未印刷/印刷済」を切り替える手動管理にしてください。

UI文言は原則「未印刷 / 印刷済」に統一してください。「未出力 / 出力済」と混ぜると、Excelを出しただけで状態が変わるように誤解されます。

4. **一括削除は厳重に確認する**

一括削除は POST のみ。対象IDが空の場合は何もしないで一覧へ戻すこと。確認ダイアログには選択件数を表示し、ユーザーが明示確認した場合だけ実行してください。

`git reset --hard`、`git clean`、`git restore .`、`git add .` は禁止です。

## 実装範囲

### 1. 印刷ステータス管理

目的:
- 活動ごとに「未印刷 / 印刷済」を管理できるようにする
- 初期状態は既存・新規とも未印刷

変更対象:
- `src/main/resources/schema.sql`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/model/Project.java`
- `src/main/resources/mapper/ProjectMapper.xml`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/ProjectMapper.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/resources/templates/activity/list.html`

実装条件:
- `schema.sql` 末尾付近に以下の型で追加すること。

```sql
ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_printed BOOLEAN NOT NULL DEFAULT FALSE;
```

- `Project` に `Boolean isPrinted` または `boolean printed` 相当のフィールドを追加する。
- MyBatisの underscore-to-camel-case 設定に合わせ、DB列 `is_printed` がJava側で自然に扱えるようにする。
- `ProjectMapper.insert` では新規登録時に `is_printed` を明示的に `false` にするか、DB default に任せる。どちらでもよいが、複製では必ず false にする。
- `ProjectMapper.update` で通常編集保存時に `is_printed` が意図せず false に戻らないようにする。印刷状態は通常の活動編集では保持すること。
- 印刷状態だけを更新する mapper メソッドを追加する。

推奨:

```java
int updatePrinted(@Param("id") int id, @Param("isPrinted") boolean isPrinted);
```

### 2. ステータス絞り込み

目的:
- `/activity` で「すべて / 未印刷 / 印刷済」を絞り込めるようにする
- 初回表示は「未印刷」をデフォルトにする

実装条件:
- request param は `printedStatus` を推奨。
- 値は `unprinted`, `printed`, `all` の3択。
- param がない初回アクセスのみ `unprinted` にする。
- ユーザーが「すべて」を選んだ場合は `printedStatus=all` として、その選択を維持する。
- 初期表示で印刷済み活動が隠れていることが分かるよう、フィルタ表示や件数表示で「未印刷のみ表示中」と伝わるUIにする。
- 既存の year / month / budgetTypeId / targetCategory / projectName の絞り込み条件を壊さない。
- `findFiltered` の引数を増やす場合、呼び出し元すべてを更新すること。
  - `ActivityController`
  - `ExportController`
  - `BudgetAllocationController`
  - ほか `rg "findFiltered"` で見つかる箇所
- Excel出力や予算管理で、意図せず未印刷だけに絞られないよう注意する。印刷ステータス絞り込みは基本 `/activity` 表示用です。既存の年度末・legacy・予算管理は従来条件を維持してください。

### 3. 一括処理

目的:
- `/activity` 一覧で複数活動を選んで処理できるようにする

実装する処理:
- 選択した活動の 2-2 preview / download
- 選択した活動の 2-6 preview / download
- 選択した活動の一括削除
- 選択した活動の印刷ステータス一括変更（未印刷/印刷済）

実装条件:
- 既存の `/export/preview` と `/export/download` を再利用する。
- 新規に同じExcel生成ロジックを作らない。
- チェックボックスの name は `projectIds` を使い、既存export導線と合わせる。
- 未選択時は分かりやすくエラー表示または一覧へリダイレクトする。
- 一括削除は確認ダイアログ必須。
- 一括削除後は、現在の絞り込み条件に可能な限り戻す。
- 削除は `projectMapper.delete(id)` をIDごとに呼んでよい。ON DELETE CASCADE の既存設計を使う。
- 存在しないIDが混ざった場合でも500にしない。存在するものだけ処理し、P3報告に挙動を書く。

禁止:
- `DELETE FROM projects` のような条件ミス時に全削除しうるSQL
- GETで削除するルート
- export成功時の自動 `is_printed=true`

### 4. 活動の複製

目的:
- 既存活動をベースに、新しい活動を素早く作れるようにする
- ただし、複製直後の活動は通常の集計対象になります。金額まで丸ごとコピーすると、編集前のコピーが決算書計上額・ダッシュボード・Excel対象に入り、実績が二重計上される危険があります。

実装条件:
- 複製ボタンは `/activity` 一覧の各行に追加する。
- POST `/activity/{id}/duplicate` を推奨。
- 元活動が見つからない場合は一覧へ戻す。
- 新しい活動名は `[コピー] 元の活動名` など、元と区別できる名前にする。
- `is_printed` は必ず false。
- 複製後は新しい活動の編集画面 `/activity/{newId}/edit` に遷移する。
- `Project` 基本情報と参加者はコピーする。
- 金額項目は原則コピーしない。複製は「入力ひな形」目的とし、交通費・宿泊費・個人雑費・事業サマリ経費・旅行雑費単価など、決算書計上額に影響する金額は 0 または null にリセットする。
- 交通手段、経路、距離、日付、宿泊有無など、次の入力を楽にする非金額項目はコピーしてよい。ただし受領日をコピーするかどうかは、誤提出防止のためCCが実装時に慎重に判断し、P3へ明記すること。
- id、created_at、project_id、project_participant_id は新規採番に合わせる。元IDを使い回さない。
- `member_id` は既存メンバーを参照したままコピーしてよい。
- 複製処理は `@Transactional` にする。Project、参加者、Expenseのどこかで失敗したら全ロールバックすること。
- 画面上または完了メッセージで「コピー活動は未印刷・金額未入力」だと分かるようにする。

複数Expenseの注意:
- 現在の編集画面は「1参加者につき画面上のExpense入力1行」が基本です。
- DB上は複数Expenseを持てるため、元データに1参加者2件以上のExpenseがある場合、安易に複製すると編集保存時に見えないExpenseが失われるリスクがあります。
- そのため、今回の複製では「複数Expenseがある活動は複製を中止」してください。

- 複製前に「1参加者に複数Expenseがあるか」を検出する。
- 複数Expenseがあれば複製を中止し、一覧へエラー表示する。
- P3報告に「複数Expenseデータは安全のため複製不可」と明記する。
- `Expense.aggregate(...)` で勝手に1件へまとめて複製しない。金額や日付の意味が変わるため、今回は禁止です。

### 5. ダッシュボード

目的:
- トップで年度の状況をざっくり確認できるようにする

変更対象:
- 新規 `DashboardController` または既存Controllerへの追加
- 新規 `templates/dashboard/index.html`
- `RootController`
- `layout.html`

実装条件:
- `/dashboard` を追加する。
- `/` は `/dashboard` へ redirect する。
- ナビに「ダッシュボード」を追加する。
- `/activity` への導線は残す。
- `/budget-allocations` への導線も残す。
- legacy `/export` は削除しない。ナビから非表示にする場合でも、直接URLと処理は残す。

表示するもの:
- 年度選択
- 総活動数
- 未印刷件数 / 印刷済件数
- 決算書計上額合計
- 予算配分ごとの使用額 / 予算額 / 残額 / 使用率

予算使用額の計算:
- `budget_allocations` の `(fiscal_year, budget_type_id, target_category)` ごとに集計する。
- 使用額は `/activity` の決算書計上額と同じ式。
- `allocated_amount = 0` の場合、0除算しない。使用率は `null`、`-`、または 0% 表示でよいが、P3に仕様を書く。
- 予算登録がない組み合わせも、活動が存在するなら表示する。予算額0として扱う。

## 推奨する実装順

1. 初期状態確認
   - `git status --short --untracked-files=all`
   - `git log --oneline -5`
   - `rg "findFiltered" src/main/java src/main/resources`

2. DB/Project/Mapper
   - `is_printed` を追加
   - `findFiltered` に印刷ステータス条件を追加。ただし呼び出し元の既存挙動を壊さない
   - `updatePrinted` を追加

3. `/activity` UI
   - ステータス列
   - ステータス絞り込み
   - チェックボックス
   - 一括処理ボタン
   - 複製ボタン

4. Controller処理
   - 一括ステータス更新
   - 一括削除
   - 複製
   - エラー/成功メッセージ

5. ダッシュボード
   - `/dashboard`
   - `/` redirect変更
   - ナビ追加

6. version更新
   - `src/main/resources/application.properties`
   - 現在 `v2.4.8` なので、Cycle 17完了版は `v2.4.9` にする

7. 検証・報告

## 必須検証

### compile/version

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

期待:
- compile成功
- src/target ともに `app.version=v2.4.9`

### DB起動確認

既存DBに対して起動し、`projects.is_printed` が追加済みでも未追加でも起動できること。

確認観点:
- 既存活動が消えていない
- 既存活動は初期表示で未印刷扱い
- 新規活動も未印刷
- 複製活動も未印刷

### `/activity` 確認

確認URL例:
- `/activity`
- `/activity?printedStatus=all`
- `/activity?printedStatus=printed`
- `/activity?printedStatus=unprinted`
- `/activity?year=2026&printedStatus=all`

確認すること:
- 初回 `/activity` は未印刷だけ表示
- 「すべて」を選ぶと印刷済みも表示
- 既存2026年度データは、全件表示で 8件・30名・決算書計上額 481,179円 が崩れていないこと
- 年度/月/補助区分/種別/事業名フィルタが従来どおり効く
- 決算書計上額に個人雑費が含まれていない
- 旅行雑費は `単価 * 参加人数 * 日数` で含まれている
- ステータス変更後も活動編集内容は壊れない

### 一括処理

確認すること:
- 未選択で一括処理しても500にならない
- 複数選択で 2-2 preview が開く
- 複数選択で 2-6 preview が開く
- 一括ステータス更新で対象だけ変わる
- 一括削除は確認ダイアログあり
- 一括削除はテスト用に作った活動だけで行い、確認後に不要データを残さない

### 複製

確認すること:
- 通常データを複製できる
- 複製後、編集画面に遷移する
- 元活動と複製活動の参加者が一致する
- 複製活動の金額項目が 0 または null にリセットされ、決算書計上額が二重計上されない
- 複製活動の `is_printed` は false
- 複製活動を保存しても元活動が変わらない
- 複数Expenseデータは安全のため複製中止になること

### ダッシュボード

確認すること:
- `/` が `/dashboard` に遷移する
- `/dashboard` が開く
- 年度変更ができる
- 総活動数、未印刷/印刷済件数が `/activity?printedStatus=all` と一致する
- 決算書計上額合計が `/activity?printedStatus=all` の合計と一致する
- 予算額0でも画面が壊れない
- budget_allocations の登録済み予算が表示される

### legacy/export回帰

必ず確認:
- `/export` が直接開ける
- legacy 2-2 preview が開く
- legacy 2-6 preview が開く
- `/export/download` が従来どおり動く
- 年度末 `/export/year/setup`、preview、download が壊れていない

### git状態

最終確認:

```powershell
git status --short --untracked-files=all
```

P3報告に以下を書くこと:
- 変更ファイル一覧
- commit hash
- push結果
- `git status --short --untracked-files=all` の最終結果
- 未追跡ファイルがある場合、コミット対象/削除対象/保留対象の分類

## P3報告書

保存先:

```text
docs/handoff/P3_CC_to_Dex/cycle_17_ux_improvements.md
```

必ず含めること:
- 実装した機能一覧
- Air案から変更した点
- legacy `/export` を削除しなかったこと
- 印刷ステータスは手動管理であり、Excel出力では自動変更しないこと
- `/activity` とダッシュボードの金額計算が決算書計上額基準であること
- 個人雑費を決算書計上額に含めていないこと
- 旅行雑費を含めていること
- 複製は入力ひな形目的で、金額項目をコピーせず二重計上を防いだこと
- 複数Expense活動は安全のため複製中止にしたこと
- 一括削除の確認・安全対策
- version `v2.4.9`
- compile結果
- 画面/Excel/legacy/ダッシュボードの検証結果
- git status、commit、push結果

## CCへのトリガー文

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

CCへ：
Dex(P2)がCycle 17 UX改善（一括処理・印刷ステータス絞り込み・活動複製・ダッシュボード）の事前監査を完了し、最終実装指示書を作成しました。
docs/handoff/P2_Dex_to_CC/cycle_17_ux_improvements_instructions.md を読んで、CC(P3)として実装してください。

重要：
- legacy /export は削除しないでください。直接URLと既存preview/downloadは維持してください。
- /activity とダッシュボードの金額は「決算書計上額」基準です。個人雑費は含めず、旅行雑費は含めます。
- UI文言は「未印刷/印刷済」に統一してください。Excel出力時に自動で印刷済みにしないでください。印刷ステータスは手動管理です。
- 一括削除はPOST・未選択ガード・確認ダイアログ必須です。
- 複製は入力ひな形目的です。金額項目はコピーせず、二重計上を防いでください。1参加者に複数Expenseがある活動は安全のため複製中止にしてください。
- app.version は v2.4.9 に更新し、compile と target/classes の同期確認をしてください。

完了後は docs/handoff/P3_CC_to_Dex/cycle_17_ux_improvements.md にP3報告を保存し、Dex(P4)レビュー依頼文をチャットに出してください。
```
